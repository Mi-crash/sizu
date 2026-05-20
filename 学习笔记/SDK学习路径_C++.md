# Dobot Quad SDK 学习路径（C++）

> 目标：从零配置环境到跑通所有 C++ 例程，理解每一步在做什么、为什么这样做。
> 所有例程基于 `high_level/cpp/` 和 `low_level/cpp/`，不涉及 Python。

---

## 第一阶段：环境搭建

### 1.1 系统准备

- 安装 **Ubuntu 22.04**（实体机或虚拟机）
- 确认工具链：

```bash
gcc --version    # 需要 GCC 9+
cmake --version  # 需要 CMake 3.16+
python3 --version  # 需要 3.10+（构建工具依赖，不写 Python 代码）
```

如版本不足：

```bash
sudo apt update
sudo apt install -y build-essential cmake g++
```

### 1.2 高层控制依赖（gRPC）

gRPC 是高层控制（状态切换、运动指令）的通信方式。

```bash
sudo apt-get install -y libgrpc++-dev protobuf-compiler-grpc libprotobuf-dev pkg-config
```

验证安装：

```bash
pkg-config --modversion grpc++  # 应输出版本号
protoc --version                # 应输出版本号
```

### 1.3 编译高层 C++ 例程

```bash
cd high_level/cpp
mkdir -p build && cd build
cmake ..
make -j
```

编译成功后 `build/` 目录下应生成以下可执行文件：

```
e1_get_available_motions
e2_get_current_state
e3_auto_state_switch
e4_velocity_sequence
e5_robot_state
e6_balance_motions
e7_line_walk
e8_rotation
e9_combo_sequence
e10_config_demo
kill_robot
```

> **编译过程发生了什么：**
> CMake 调用 `protoc` 将 `proto/grpc_service.proto` 编译为 C++ 的 `.pb.cc/.pb.h`（消息类）和 `.grpc.pb.cc/.grpc.pb.h`（gRPC Stub 类）。你的代码通过 `robot_client.h` 封装了这些 Stub，每个例程链接到 `proto_lib` 静态库。

### 1.4 底层控制依赖（DDS）

DDS 是底层传感器数据（相机、IMU、电机）的通信方式，需要**有线网络**连接。

```bash
# 安装 DDS 中间件
cd dist
sudo dpkg -i dds-middleware-with-thirdparty*.deb
export CYCLONEDDS_HOME="/usr/local/"
```

```bash
# 编译底层 C++ 例程
sudo apt install -y libboost-dev libopencv-dev libyaml-cpp-dev
cd low_level/cpp
mkdir -p build && cd build
cmake ..
make -j
```

### 1.5 网络连接

| 连接方式 | 机器人 IP | PC 端配置 | 能做什么 |
|---------|----------|----------|---------|
| **网线** | 192.168.5.2 | 设为 192.168.5.xxx/24 | gRPC + DDS（全功能） |
| **WiFi**（Rover-*，密码 12345678） | 192.168.1.6 | 自动连接 | 仅 gRPC（高层控制） |

**测试连通性：**

```bash
# 有线连接测试（gRPC 端口）
ping 192.168.5.2

# WiFi 连接测试
ping 192.168.1.6
```

### 1.6 DDS 网络配置（有线连接后）

编辑 `cyclonedds.xml`，将 `<USER_PORT_INTERFACE>` 替换为你的网卡名：

```bash
# 查看网卡名
ip link show
# 常见：enp2s0、eth0、enx...（USB 网卡）
```

```xml
<!-- cyclonedds.xml -->
<NetworkInterfaces>"enp2s0"</NetworkInterfaces>
```

设置环境变量并验证：

```bash
export CYCLONEDDS_URI=file://$(pwd)/cyclonedds.xml
cyclonedds ps  # 应能看到 DDS 参与者
```

---

## 第二阶段：高层例程（gRPC）— 从查询到运动

> 以下例程均可通过 WiFi 或有线运行。连接机器人后从 e1 开始逐步执行。

### E1: 获取可用动作

```bash
cd high_level/cpp/build
./e1_get_available_motions
# 或指定地址：./e1_get_available_motions 192.168.1.6:50051
```

**你学到什么：**
- gRPC 连接的建立（`Client` 构造函数 → `CreateChannel` → `NewStub`）
- 请求-响应模式：客户端发送 `GetMotionsRequest`，服务端返回所有可用动作列表
- 每个动作有 `motion_id` 和参数（float/int/string/bool）

**预期输出：** 打印所有动作 ID 及其参数，如 `balance_stand`、`walk`、`dance0` 等。

---

### E2: 获取当前状态

```bash
./e2_get_current_state
```

**你学到什么：**
- 查询机器人的 FSM（有限状态机）当前处于哪个状态
- 返回值如 `passive`、`ready`、`balance_stand`、`walk` 等
- 这是所有状态切换操作的前提——先看当前在什么状态

---

### E3: 状态切换

```bash
./e3_auto_state_switch
```

**你学到什么：**
- FSM 状态机的流转规则：`passive → ready → stand_down → balance_stand → walk → ...`
- 每次状态切换都是一个 gRPC 调用（`ExecuteSequence`），服务端以流式进度返回
- `Ctrl+C` 可取消当前动作（SDK 内部注册了 SIGINT 处理器）
- 程序会自动检测机器人类型（点足/轮足），显示对应的状态列表

**关键状态说明：**

| 状态 | 含义 | 触发方法 |
|------|------|---------|
| `passive` | 电机断电，最安全 | `client.passive()` |
| `ready` | 缓慢趴下，安全停止 | `client.ready()` |
| `stand_down` | 趴下 | `client.stand_down()` |
| `balance_stand` | 平衡站立 | `client.balance_stand()` |
| `walk` | 行走模式 | `client.walk()` |
| `flying_trot` | 奔跑模式 | `client.flying_trot()` |

> **注意：** 确保机器人有足够空间，E3 会实际切换状态并让机器人动起来。

---

### E4: 速度序列控制

```bash
./e4_velocity_sequence
```

**你学到什么：**
- 速度指令格式：`vx,vy,vyaw,duration`（前向速度、横移速度、转向角速度、持续时间）
- 这是自主巡航中最关键的接口——Nav2 规划出的路径最终需要转化为这种速度指令
- 支持不同步态：`walk`（行走）、`flying_trot`（奔跑）、`wheel_loco`（轮式）

**C++ 速度序列写法：**

```cpp
std::vector<robot::VelocityStep> steps = {
    {0.8f, 0, 0, 2},   // 前进 0.8m/s，持续 2s
    {0, 0, 0, 1},      // 停止 1s
    {-0.8f, 0, 0, 2},  // 后退 0.8m/s，持续 2s
    {0, 0, 0, 1},      // 停止 1s
};
client.velocity_sequence(steps, "walk", 60);  // 步态=walk，速度比=60
```

**参数范围：**
- `speed_ratio`：[10, 100]
- 序列结束后默认自动 `stand_down`

---

### E5: 机器人遥测

```bash
./e5_robot_state
```

**你学到什么：**
- 获取完整的机器人遥测快照：关节位置/速度/力矩、机体位置/速度/加速度/姿态、地面接触力
- `get_state()` 是一次性查询（不是流式），返回 `GetRobotStateResponse`
- 做自主导航时，你需要高频调用这个接口获取实时状态

**遥测字段：**

| 字段 | 含义 | 单位 |
|------|------|------|
| `jpos_leg` | 腿部关节位置 | rad |
| `jtau_leg` | 腿部关节力矩 | Nm |
| `pos_body` | 机体位置 [x, y, z] | m |
| `vel_body` | 机体线速度 | m/s |
| `ori_body` | 机体姿态 [roll, pitch, yaw] | rad |

---

### E6: 平衡动作（仅点足）

```bash
./e6_balance_motions
```

**你学到什么：**
- 平衡站立状态下的姿态控制：俯仰、偏航、横滚、高度
- 两种模式：`dynamic`（正弦扫描到目标）vs `static`（斜坡到目标→保持→回中）
- 复合姿势：`dynamic_pose` / `static_pose` 同时控制多个轴
- `balance_sequence` 批量执行多个平衡动作

**参数范围：**

| 轴 | 值范围 | 单位 |
|----|-------|------|
| pitch | [-15, 15] | 度 |
| yaw | [-20, 20] | 度 |
| roll | [-30, 30] | 度 |
| height | [-0.12, 0] | 米 |
| duration | [0.5, 5] | 秒 |

> **注意：** 轮足机器人不支持平衡动作，程序会自动检测并退出。

---

### E7: 直线行走

```bash
./e7_line_walk
```

**你学到什么：**
- 指定方向和距离的受控行走
- 方向：0=前进、1=后退、2=左移、3=右移
- 距离上限 3m，可临时指定速度比

```cpp
client.walk_forward(2.0);    // 前进 2m
client.walk_backward(1.5);   // 后退 1.5m
client.move_left(1.0);       // 左移 1m
client.move_right(1.0);      // 右移 1m
client.walk_forward(2.0, 100);  // 前进 2m，临时用速度比 100
```

---

### E8: 旋转

```bash
./e8_rotation
```

**你学到什么：**
- 原地旋转：`rotate("left", 90)` 左转 90°
- 多圈旋转：`circle("left", 3)` 左转 3 圈（最多 10 圈）
- 方向性行走：`rotate_walk(-45, 2.0)` 先左转 45° 再前进 2m

```cpp
client.rotate("left", 90);       // 左转 90°
client.rotate_right(45);         // 右转 45°
client.circle("left", 3);        // 左转 3 圈
client.rotate_walk(-45.0f, 2.0f); // 先左转 45° 再前进 2m
```

---

### E9: 组合序列

```bash
./e9_combo_sequence
```

**你学到什么：**
- Arduino 风格的顺序阻塞调用——每个函数阻塞到动作完成
- 一个程序跑遍所有功能：状态切换 → 行走 → 旋转 → 平衡 → 跳舞 → 趴下
- 这是 E1-E8 的综合，验证你对整套 API 的理解

> **注意：** 这个例程会让机器人做很多动作，确保有 3m×3m 以上空旷空间。

---

### E10: 配置演示

```bash
./e10_config_demo
```

**你学到什么：**
- `set_speed_ratio(ratio)` 设置基础速度比 [10, 100]
- 运动接口的 `speed_ratio` 参数是临时覆盖，执行后自动恢复基础值
- `set_obstacle_avoidance(true/false)` 开关避障

```cpp
client.set_speed_ratio(30);       // 基础速度比设为 30
client.walk_forward(2.0);         // 用速度比 30 走
client.walk_forward(2.0, 100);    // 临时用速度比 100 走，走完恢复 30
client.set_obstacle_avoidance("off");  // 关闭避障
```

---

## 第三阶段：底层例程（DDS）— 传感器与执行器

> 以下例程需要**有线连接**并配置好 DDS 环境（见 1.5、1.6）。

```bash
export CYCLONEDDS_URI=file://$(pwd)/cyclonedds.xml
```

### 底层 E1: RGB 图像订阅

订阅压缩 RGB 图像，OpenCV 解码后保存为 PNG。

**理解要点：**
- DDS 订阅者模式：创建 Subscriber → 绑定 Topic → 回调接收数据
- 传感器数据是持续流，不是请求-响应
- 这就是建图时获取视觉数据的通道

### 底层 E2: 深度图像订阅

订阅原始深度图像，归一化后用 Jet 色图可视化。

**理解要点：**
- 深度图 + RGB 图 = RGB-D 数据，SLAM 的核心输入
- 深度值表示每个像素到相机的距离

### 底层 E3: LED 灯光控制

控制 6 个 LED 灯实现呼吸灯效果。

**理解要点：**
- DDS 发布者模式：创建 Publisher → 绑定 Topic → 发布指令
- **必须先停止主控程序**（见 kill_robot）

### 底层 E4: IMU 数据订阅

订阅 IMU 原始数据（四元数、陀螺仪、加速度计、欧拉角）。

**理解要点：**
- IMU 是 SLAM 前端的重要传感器，提供运动约束
- 输出频率高（~200Hz），是高频数据流的典型代表

### 底层 E5: 电机状态订阅

订阅 16 个电机的位置、速度、力矩、温度。

**理解要点：**
- 点足有效 12 个电机，轮足 16 个
- 电机编码器可推算轮式里程计（如果做 SLAM 融合）

### 底层 E6: 电池状态订阅

订阅电池管理系统（BMS）状态。

### 底层 E7: 语音播放

通过 DDS 播放音频，支持文件模式和流模式（WAV/FLAC/MP3）。

### 底层 E8: 语音采集

订阅机器人麦克风的 24kHz/16bit/mono 音频流。

### 底层 E9: 电机指令发布

**直接控制电机**，实现正弦波位置控制。

> **警告：** 运行前必须先停止主控程序！确保机器人处于安全位置。
> ```bash
> ./kill_robot 192.168.5.2:50051
> ```

**理解要点：**
- 这是绕过主控程序直接控制电机的唯一方式
- 理解 DDS 的 QoS：电机控制需要 reliable，传感器数据用 best_effort

---

## 第四阶段：理解 SDK 架构

跑通例程后，回头看代码结构：

### robot_client.h — 封装的艺术

```
robot::Client
├── 构造函数：创建 gRPC Channel + Stub
├── 查询接口：get_state()、get_motions()、get_robot_type()
├── 配置接口：set_speed_ratio()、set_obstacle_avoidance()
├── 状态切换：passive()、ready()、balance_stand()、walk() ...
├── 运动控制：velocity_sequence()、line_walk()、rotate() ...
├── 平衡动作：balance_pitch/yaw/roll/height()、dynamic_pose()、static_pose()
└── 安全机制：enable_safety_ready() — Ctrl+C 自动回到 ready 状态
```

所有接口最终都是对一个 gRPC Stub 的调用，传输的是 Protobuf 序列化的消息。

### Protobuf 消息定义

查看 `high_level/cpp/proto/grpc_service.proto`，理解：
- `ExecuteSequenceRequest` — 动作序列请求
- `SequenceProgress` — 流式进度响应
- `GetRobotStateRequest/Response` — 状态查询
- `SetSpeedRatioRequest/Response` — 速度设置

### DDS vs gRPC 的分工

```
你的程序
  │
  ├── 高层（gRPC）→ 机器人主控程序 → 步态控制器 → 电机
  │   "站起来"、"走 2 米"、"左转 90°"
  │
  └── 底层（DDS）→ 直接访问硬件
      相机图像、IMU 数据、电机状态、LED/语音控制
```

---

## 第五阶段：向自主巡航迈进

跑通 SDK 例程是第一步。后续方向：

1. **数据获取验证** — 用底层 DDS 拿到 RGB-D 图像流和 IMU 数据，确认数据质量
2. **引入 ROS2** — 写 DDS → ROS2 的桥接节点，将传感器数据发布为 ROS2 Topic
3. **SLAM 建图** — 在 ROS2 中运行 RTAB-Map 或 Cartographer，建出 2D 栅格地图
4. **Nav2 导航** — 配置 Nav2 栈，在地图上实现路径规划
5. **桥接控制** — 写 ROS2 → gRPC 的桥接节点，将 Nav2 的 `cmd_vel` 转为 SDK 的 `velocity_sequence()`

---

## 例程速查表

| 例程 | 命令 | 功能 | 需要网络 |
|------|------|------|---------|
| E1 | `./e1_get_available_motions` | 查询可用动作列表 | WiFi/有线 |
| E2 | `./e2_get_current_state` | 查询当前 FSM 状态 | WiFi/有线 |
| E3 | `./e3_auto_state_switch` | 自动状态切换演示 | WiFi/有线 |
| E4 | `./e4_velocity_sequence` | 速度序列控制 | WiFi/有线 |
| E5 | `./e5_robot_state` | 机器人遥测数据 | WiFi/有线 |
| E6 | `./e6_balance_motions` | 平衡动作（仅点足） | WiFi/有线 |
| E7 | `./e7_line_walk` | 直线行走 | WiFi/有线 |
| E8 | `./e8_rotation` | 旋转控制 | WiFi/有线 |
| E9 | `./e9_combo_sequence` | 组合序列（全功能） | WiFi/有线 |
| E10 | `./e10_config_demo` | 速度比/避障配置 | WiFi/有线 |
| kill | `./kill_robot 192.168.5.2:50051` | 停止主控程序 | 有线 |

| 底层例程 | 功能 | 需要 DDS |
|---------|------|---------|
| 底层 E1 | RGB 图像订阅 | 有线 |
| 底层 E2 | 深度图像订阅 | 有线 |
| 底层 E3 | LED 灯光控制 | 有线 |
| 底层 E4 | IMU 数据订阅 | 有线 |
| 底层 E5 | 电机状态订阅 | 有线 |
| 底层 E6 | 电池状态订阅 | 有线 |
| 底层 E7 | 语音播放 | 有线 |
| 底层 E8 | 语音采集 | 有线 |
| 底层 E9 | 电机指令发布 | 有线 + 停主控 |
