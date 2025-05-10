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

# 启动前端服务
start_frontend() {
    log_info "启动前端服务(端口: $FRONTEND_PORT)..."
    
    if [ "$PM2_AVAILABLE" = true ] && [ "$NO_DAEMON" = false ]; then
        # 使用PM2启动
        cd "$SCRIPT_DIR"
        pm2 start --name wsl-tunnel-frontend npm -- run preview -- --port $FRONTEND_PORT
        log_success "前端服务已通过PM2启动"
    elif [ "$NODE_AVAILABLE" = true ]; then
        # 使用Node直接启动
        cd "$SCRIPT_DIR"
        
        if [ "$NO_DAEMON" = true ]; then
            log_info "在前台启动前端服务..."
            npm run preview -- --port $FRONTEND_PORT
        else
            log_info "在后台启动前端服务..."
            nohup npm run preview -- --port $FRONTEND_PORT > "$LOG_DIR/frontend.log" 2>&1 &
            echo $! > "$PID_FILE"
            log_success "前端服务已启动，日志位于: $LOG_DIR/frontend.log"
        fi
    else
        log_error "无法启动前端服务，请确保Node.js已安装"
        exit 1
    fi
}

# 启动后端服务
start_backend() {
    log_info "启动后端服务(端口: $BACKEND_PORT)..."
    
    if [ ! -d "$SCRIPT_DIR/server/node_modules" ] && [ -f "$SCRIPT_DIR/server/package.json" ]; then
        log_info "安装后端依赖..."
        cd "$SCRIPT_DIR/server"
        npm install
    fi
    
    if [ "$PM2_AVAILABLE" = true ] && [ "$NO_DAEMON" = false ]; then
        # 使用PM2启动
        cd "$SCRIPT_DIR/server"
        PORT=$BACKEND_PORT DB_PATH=$DB_PATH pm2 start --name wsl-tunnel-backend index.js
        log_success "后端服务已通过PM2启动"
    elif [ "$NODE_AVAILABLE" = true ]; then
        # 使用Node直接启动
        cd "$SCRIPT_DIR/server"
        
        if [ "$NO_DAEMON" = true ]; then
            log_info "在前台启动后端服务..."
            PORT=$BACKEND_PORT DB_PATH=$DB_PATH node index.js
        else
            log_info "在后台启动后端服务..."
            PORT=$BACKEND_PORT DB_PATH=$DB_PATH nohup node index.js > "$LOG_DIR/backend.log" 2>&1 &
            echo $! >> "$PID_FILE"
            log_success "后端服务已启动，日志位于: $LOG_DIR/backend.log"
        fi
    else
        log_error "无法启动后端服务，请确保Node.js已安装"
        exit 1
    fi
}

# 主函数
main() {
    log_info "启动WSL内网穿透工具..."
    
    # 检查是否已在运行
    if check_running; then
        log_warning "WSL内网穿透工具已在运行"
        read -p "是否重启服务? (y/n): " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            stop_service
        else
            log_info "退出，服务保持运行状态"
            exit 0
        fi
    fi
    
    # 构建前端
    build_frontend
    
    # 启动服务
    if [ "$NO_DAEMON" = true ]; then
        log_info "在前台启动服务..."
        # 在前台启动前端服务，后端服务将在单独的终端中启动
        
        # 启动后端服务在新的终端窗口
        if command -v gnome-terminal &> /dev/null; then
            gnome-terminal -- bash -c "cd '$SCRIPT_DIR' && ./start.sh --backend-port=$BACKEND_PORT --no-daemon"
        elif command -v xterm &> /dev/null; then
            xterm -e "cd '$SCRIPT_DIR' && ./start.sh --backend-port=$BACKEND_PORT --no-daemon" &
        elif command -v wt &> /dev/null; then
            # Windows Terminal
            wt -w 0 new-tab "cd '$SCRIPT_DIR' && ./start.sh --backend-port=$BACKEND_PORT --no-daemon"
        else
            # 如果找不到合适的终端，在后台启动后端
            log_warning "未找到适合的终端，后端将在后台启动"
            cd "$SCRIPT_DIR"
            start_backend
        fi
        
        # 在当前终端启动前端
        start_frontend
    else
        # 正常后台启动
        start_backend
        start_frontend
        
        # 显示访问信息
        log_success "WSL内网穿透工具已启动!"
        log_info "前端地址: http://localhost:$FRONTEND_PORT"
        log_info "API地址: http://localhost:$BACKEND_PORT/api"
        log_info "日志位置: $LOG_DIR"
        
        echo ""
        echo "===== 使用指南 ====="
        echo "1. 打开浏览器访问: http://localhost:$FRONTEND_PORT"
        echo "2. 在服务器配置页面配置外网服务器信息"
        echo "3. 使用穿透配置页面创建端口转发规则"
        echo "4. 查看日志页面监控穿透状态"
        echo ""
        echo "停止服务: $0 stop"
        echo "===================="
    fi
}

# 处理命令
case "$1" in
    stop)
        stop_service
        ;;
    restart)
        stop_service
        sleep 2
        main
        ;;
    status)
        if check_running; then
            PID=$(cat "$PID_FILE")
            log_success "WSL内网穿透工具正在运行，PID: $PID"
            log_info "前端地址: http://localhost:$FRONTEND_PORT"
            log_info "API地址: http://localhost:$BACKEND_PORT/api"
        else
            log_warning "WSL内网穿透工具未运行"
        fi
        ;;
    *)
        main
        ;;
esac

exit 0