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

# 解析命令行参数
for arg in "$@"; do
  case $arg in
    --frontend-port=*)
      FRONTEND_PORT="${arg#*=}"
      shift
      ;;
    --backend-port=*)
      BACKEND_PORT="${arg#*=}"
      shift
      ;;
    --no-daemon)
      NO_DAEMON=true
      shift
      ;;
    --help)
      echo "WSL内网穿透工具 - 启动脚本"
      echo ""
      echo "用法: $0 [选项]"
      echo ""
      echo "选项:"
      echo "  --frontend-port=PORT  设置前端服务端口 (默认: 8080)"
      echo "  --backend-port=PORT   设置后端API端口 (默认: 3000)"
      echo "  --no-daemon           在前台运行，不作为后台服务"
      echo "  --help                显示此帮助信息"
      exit 0
      ;;
    *)
      # 未知参数
      ;;
  esac
done

# 检查必要的目录
mkdir -p "$LOG_DIR"
mkdir -p "$(dirname "$DB_PATH")"

# 检查Node.js是否可用
if command -v node &> /dev/null && command -v npm &> /dev/null; then
    NODE_VERSION=$(node -v)
    log_info "检测到Node.js: $NODE_VERSION"
    NODE_AVAILABLE=true
else
    log_warning "未检测到Node.js，将尝试使用Docker"
    if ! command -v docker &> /dev/null; then
        log_error "未检测到Node.js或Docker，无法启动服务"
        log_info "请安装Node.js或Docker后重试"
        exit 1
    fi
fi

# 检查PM2是否可用
if command -v pm2 &> /dev/null; then
    PM2_AVAILABLE=true
    log_info "检测到PM2，将使用PM2管理服务"
else
    log_info "未检测到PM2，将使用标准方式启动服务"
fi