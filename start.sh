#!/bin/bash

# WSL内网穿透工具 - 启动脚本
# 此脚本用于启动WSL内网穿透工具前端和后端服务

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 重置颜色

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_PORT=8080
BACKEND_PORT=3000
DB_PATH="$SCRIPT_DIR/data/db.json"
LOG_DIR="$SCRIPT_DIR/logs"
PID_FILE="$SCRIPT_DIR/.tunnel-tool.pid"
PM2_AVAILABLE=false
NODE_AVAILABLE=false
NO_DAEMON=false