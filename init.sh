#!/bin/bash
# init.sh - 四足机器人项目环境初始化脚本
# 用于检查开发环境是否满足 SDK 运行要求

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "  四足机器人项目 - 环境检查"
echo "========================================"
echo ""

check_fail=0

check_cmd() {
    local name=$1
    local cmd=$2
    local expected=$3
    echo -n "[检查] $name ... "
    if command -v "$cmd" &>/dev/null; then
        local version
        version=$("$cmd" --version 2>&1 | head -1 || true)
        echo -e "${GREEN}✓${NC} $version"
    else
        echo -e "${RED}✗ 未安装${NC}"
        check_fail=1
    fi
}

check_python_pkg() {
    local name=$1
    local pkg=$2
    echo -n "[检查] Python $name ... "
    if python3 -c "import $pkg" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ 未安装 (pip install $pkg)${NC}"
    fi
}

# 1. 系统检查
echo "--- 系统 ---"
echo -n "[检查] Ubuntu 版本 ... "
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$NAME $VERSION"
else
    echo -e "${RED}✗ 无法确定${NC}"
    check_fail=1
fi

# 2. 核心工具
echo ""
echo "--- 核心工具 ---"
check_cmd "Python" python3
echo -n "[检查] Python 版本 ... "
py_ver=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "0")
if [ "$(echo "$py_ver >= 3.10" | bc -l 2>/dev/null || echo 0)" = "1" ] || [ "${py_ver%%.*}" -ge 3 -a "${py_ver#*.}" -ge 10 ] 2>/dev/null; then
    echo -e "${GREEN}✓ Python $py_ver${NC}"
else
    echo -e "${RED}✗ Python $py_ver (需要 3.10+)${NC}"
    check_fail=1
fi

check_cmd "CMake" cmake
check_cmd "GCC" gcc
check_cmd "G++" g++
check_cmd "Git" git
check_cmd "Docker" docker

# 3. SDK 关键依赖
echo ""
echo "--- SDK 关键依赖 ---"
check_python_pkg "grpc" grpc
check_python_pkg "cyclonedds" cyclonedds
check_python_pkg "opencv" cv2
check_python_pkg "numpy" numpy
check_python_pkg "protobuf" google.protobuf

# 4. CycloneDDS 环境
echo ""
echo "--- CycloneDDS 环境变量 ---"
echo -n "[检查] CYCLONEDDS_HOME ... "
if [ -n "$CYCLONEDDS_HOME" ]; then
    echo -e "${GREEN}✓ $CYCLONEDDS_HOME${NC}"
else
    echo -e "${YELLOW}⚠ 未设置 (需 export CYCLONEDDS_HOME=/usr/local/)${NC}"
fi

# 5. 网络
echo ""
echo "--- 网络接口 ---"
echo "[检查] 以太网接口(用于 DDS):"
ip -br link show 2>/dev/null | grep -E "^e(n|th)" | awk '{print "  - "$1" : "$2}' || echo "  未检测到以太网接口"
echo "[检查] WiFi 接口(用于 gRPC):"
ip -br link show 2>/dev/null | grep -E "^wl" | awk '{print "  - "$1" : "$2}' || echo "  未检测到 WiFi 接口"

# 6. ROS2 (可选)
echo ""
echo "--- ROS2 (可选) ---"
if command -v ros2 &>/dev/null; then
    echo -e "[检查] ROS2 ... ${GREEN}✓${NC}"
    ros2 --version 2>/dev/null || true
else
    echo -e "[检查] ROS2 ... ${YELLOW}⚠ 未安装 (阶段2需要)${NC}"
fi

echo ""
echo "========================================"
if [ $check_fail -eq 0 ]; then
    echo -e "${GREEN}  环境检查通过${NC}"
else
    echo -e "${RED}  部分依赖缺失，请安装后重试${NC}"
fi
echo "========================================"
