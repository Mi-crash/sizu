# PROJECT.md - 四足机器人环卫巡检项目

## 项目概述

基于 DOBOT ROVER X1 四足机器人 SDK 进行二次开发，实现环卫场景的自主巡检 Demo。

- **机器人**: DOBOT ROVER X1 (越疆科技)
- **SDK**: [dobot_quad_sdk-main](code/dobot_quad_sdk-main/) (CycloneDDS + gRPC 双通道)
- **目标**: 场地 SLAM 建图 → 自主导航巡检 → 循环测试验收

---

## 技术栈

| 类别 | 技术 | 版本/说明 |
|------|------|-----------|
| 操作系统 | Ubuntu | 22.04 |
| 容器 | Docker | SDK 提供 Dockerfile |
| 语言 | Python | 3.10+（主逻辑） |
| 语言 | C++ | GCC 9+（性能关键节点） |
| 通信-底层 | CycloneDDS | 有线以太网，IMU/电机/图像数据 |
| 通信-高层 | gRPC | WiFi，状态机/速度控制 |
| 机器人框架 | ROS2 | Humble |
| SLAM | RTAB-Map | RGB-D 输入 |
| 导航 | Nav2 | ROS2 Navigation Stack |
| 构建 | CMake | 3.16+ |
| 视觉 | OpenCV | 4.5.4 |

## 目录结构

```
sizu-master/
├── CLAUDE.md              # AI 工作流程规范
├── PROJECT.md             # 本文件 - 项目技术信息
├── 需求.md                # 需求文档
├── 开发计划/              # 阶段规划与里程碑
├── 产品资料/              # 供应商资料、内部梳理
├── 学习笔记/              # 学习参考资料
├── code/                  # SDK 与二次开发代码
│   └── dobot_quad_sdk-main/  # 官方 SDK
└── claude-progress.txt    # AI 工作进度记录
```

## 网络拓扑

```
PC (192.168.5.xxx/24)  ←→  机器人 (192.168.5.2)  [有线 - DDS底层]
PC (DHCP)              ←→  机器人 (192.168.1.6:50051) [WiFi - gRPC高层]
```

## 编码规范

### Python
- 格式化: yapf (google style), 行宽 100
- 导入排序: isort (black profile)
- 类型检查: pyright (basic mode)
- Python 版本: 3.11

### C++
- 格式化: clang-format (文件在 SDK 根目录)
- 构建: CMake 3.16+

### Commit 规范
- 格式: `type(scope): description`
- 类型: feat / fix / docs / refactor / test / chore / wip

---

## 关键依赖

- CycloneDDS 中间件 (deb 包在 `code/dobot_quad_sdk-main/dist/`)
- DDS Python 绑定 (whl 包同上)
- gRPC + protobuf
- ROS2 Humble + Nav2 + RTAB-Map
- OpenCV 4.5.4
