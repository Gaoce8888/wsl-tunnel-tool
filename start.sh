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

# 检查是否已有实例在运行
check_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0 # 正在运行
        else
            rm -f "$PID_FILE" # 进程不存在，删除PID文件
            return 1 # 未运行
        fi
    else
        return 1 # 未运行
    fi
}

# 停止服务
stop_service() {
    log_info "停止WSL内网穿透工具服务..."
    
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        
        if ps -p "$PID" > /dev/null 2>&1; then
            log_info "正在终止进程 (PID: $PID)..."
            kill "$PID" 2>/dev/null || true
            sleep 2
            
            # 如果进程仍在运行，强制终止
            if ps -p "$PID" > /dev/null 2>&1; then
                log_warning "正常终止失败，强制终止进程..."
                kill -9 "$PID" 2>/dev/null || true
            fi
        else
            log_warning "进程已不在运行"
        fi
        
        rm -f "$PID_FILE"
        log_success "服务已停止"
    elif [ "$PM2_AVAILABLE" = true ]; then
        pm2 delete wsl-tunnel-frontend wsl-tunnel-backend 2>/dev/null || true
        log_success "通过PM2停止的服务"
    else
        log_warning "未找到正在运行的服务实例"
    fi
}

# 构建前端
build_frontend() {
    log_info "构建前端应用..."
    cd "$SCRIPT_DIR"
    
    if [ ! -d "node_modules" ]; then
        log_info "未找到依赖，正在安装..."
        
        if [ -f "npm-fix.sh" ]; then
            log_info "使用npm-fix.sh安装依赖..."
            chmod +x npm-fix.sh
            ./npm-fix.sh .
        else
            if [ "$NODE_AVAILABLE" = true ]; then
                npm install
            else
                log_error "无法安装依赖，请确保Node.js已安装"
                exit 1
            fi
        fi
    fi
    
    # 检查dist目录是否已存在
    if [ ! -d "dist" ]; then
        log_info "正在构建前端..."
        
        if [ "$NODE_AVAILABLE" = true ]; then
            npm run build
        else
            log_error "无法构建前端，请确保Node.js已安装"
            exit 1
        fi
    else
        log_info "前端已构建，使用现有构建"
    fi
    
    log_success "前端准备就绪"
}