#!/bin/bash

# WSL内网穿透工具 - WSL环境部署脚本
# 此脚本用于在WSL环境中部署和配置WSL内网穿透工具

set -e

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

# 默认配置
INSTALL_DIR="$HOME/wsl-tunnel-tool"
REPO_URL="https://github.com/Gaoce8888/wsl-tunnel-tool.git"
FRONTEND_PORT=8080
BACKEND_PORT=3000

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --repo)
            REPO_URL="$2"
            shift 2
            ;;
        --frontend-port)
            FRONTEND_PORT="$2"
            shift 2
            ;;
        --backend-port)
            BACKEND_PORT="$2"
            shift 2
            ;;
        --help)
            echo "WSL内网穿透工具 - WSL环境部署脚本"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --dir PATH           安装目录 (默认: $HOME/wsl-tunnel-tool)"
            echo "  --repo URL           Git仓库地址 (默认: $REPO_URL)"
            echo "  --frontend-port PORT 前端服务端口 (默认: 8080)"
            echo "  --backend-port PORT  后端API端口 (默认: 3000)"
            echo "  --help               显示此帮助信息"
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 检查系统依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    # 检查 Node.js
    if ! command -v node &> /dev/null; then
        log_warning "未检测到 Node.js，正在安装..."
        
        # 首先检查是否已安装nvm
        if [ -f "$HOME/.nvm/nvm.sh" ]; then
            log_info "检测到NVM，使用NVM安装Node.js..."
            source "$HOME/.nvm/nvm.sh"
            nvm install --lts
            nvm use --lts
        else
            # 尝试通过包管理器安装
            if command -v apt-get &> /dev/null; then
                log_info "使用APT安装Node.js..."
                curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
                sudo apt-get install -y nodejs
            elif command -v yum &> /dev/null; then
                log_info "使用YUM安装Node.js..."
                curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo -E bash -
                sudo yum install -y nodejs
            else
                log_error "无法安装Node.js，请手动安装后重试"
                echo "建议使用NVM安装: https://github.com/nvm-sh/nvm"
                exit 1
            fi
        fi
    fi
    
    # 检查npm
    if ! command -v npm &> /dev/null; then
        log_warning "未检测到npm，可能需要修复Node.js安装"
        exit 1
    fi
    
    # 检查Git
    if ! command -v git &> /dev/null; then
        log_warning "未检测到Git，正在安装..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y git
        elif command -v yum &> /dev/null; then
            sudo yum install -y git
        else
            log_error "无法安装Git，请手动安装后重试"
            exit 1
        fi
    fi
    
    log_success "所有依赖已就绪"
}

# 克隆或更新代码库
setup_repository() {
    log_info "设置代码库..."
    
    if [ -d "$INSTALL_DIR" ]; then
        log_info "目录已存在，正在更新代码..."
        cd "$INSTALL_DIR"
        git pull
    else
        log_info "正在克隆代码库..."
        git clone "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi
    
    # 设置文件权限
    chmod +x "$INSTALL_DIR/start.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/client/wsl-tunnel.sh" 2>/dev/null || true
    
    log_success "代码库已设置"
}

# 安装项目依赖
install_dependencies() {
    log_info "安装项目依赖..."
    cd "$INSTALL_DIR"
    
    if [ -f "npm-fix.sh" ]; then
        log_info "使用npm-fix.sh安装依赖..."
        chmod +x npm-fix.sh
        ./npm-fix.sh
    else
        npm install
    fi
    
    # 检查服务器目录是否存在
    if [ -d "server" ]; then
        log_info "安装服务器依赖..."
        cd "$INSTALL_DIR/server"
        npm install
    fi
    
    log_success "项目依赖安装完成"
}

# 配置工具设置 
configure_tool() {
    log_info "配置WSL内网穿透工具..."
    
    # 创建数据和日志目录
    mkdir -p "$INSTALL_DIR/data"
    mkdir -p "$INSTALL_DIR/logs"
    
    # 创建基本配置文件
    cat > "$INSTALL_DIR/wsl-tunnel-config.json" << EOF
{
  "frontendPort": $FRONTEND_PORT,
  "backendPort": $BACKEND_PORT,
  "dataPath": "$INSTALL_DIR/data/db.json",
  "logsPath": "$INSTALL_DIR/logs"
}
EOF
    
    log_success "配置完成"
}

# 创建快捷方式
create_shortcuts() {
    log_info "创建快捷方式..."
    
    # 创建启动快捷命令
    cat > "$HOME/bin/wsl-tunnel" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
./start.sh \$@
EOF
    
    # 确保目录存在
    mkdir -p "$HOME/bin"
    chmod +x "$HOME/bin/wsl-tunnel"
    
    # 检查PATH中是否包含bin目录
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        log_warning "$HOME/bin 不在PATH环境变量中"
        echo "建议将以下行添加到你的 ~/.bashrc 文件:"
        echo "export PATH=\$PATH:\$HOME/bin"
        
        # 询问是否自动添加
        read -p "是否自动添加到 ~/.bashrc? (y/n): " add_to_bashrc
        if [[ "$add_to_bashrc" == "y" || "$add_to_bashrc" == "Y" ]]; then
            echo 'export PATH=$PATH:$HOME/bin' >> "$HOME/.bashrc"
            log_success "已添加到 ~/.bashrc"
            
            # 应用新设置
            export PATH=$PATH:$HOME/bin
        fi
    fi
    
    log_success "快捷方式创建完成，你可以使用 'wsl-tunnel' 命令启动服务"
}

# 自动检测WSL环境信息
detect_wsl_info() {
    log_info "检测WSL环境信息..."
    
    # 检查是否在WSL环境中
    if grep -q Microsoft /proc/version 2>/dev/null || grep -q microsoft /proc/version 2>/dev/null; then
        log_success "检测到WSL环境"
        
        # 尝试获取WSL版本
        if [ -f /proc/sys/kernel/osrelease ]; then
            WSL_VERSION=$(grep -q "WSL2" /proc/sys/kernel/osrelease 2>/dev/null && echo "WSL2" || echo "WSL1")
            log_info "WSL版本: $WSL_VERSION"
        else
            log_warning "无法确定WSL版本"
        fi
        
        # 获取WSL IP地址
        WSL_IP=$(ip addr show eth0 2>/dev/null | grep -oP "(?<=inet )([0-9]{1,3}\.){3}[0-9]{1,3}" | head -1)
        if [ -n "$WSL_IP" ]; then
            log_info "WSL IP地址: $WSL_IP"
        else
            log_warning "无法获取WSL IP地址"
        fi
        
        # 获取Windows主机名
        WINDOWS_HOST=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{ print $2 }' | head -1)
        if [ -n "$WINDOWS_HOST" ]; then
            log_info "Windows主机IP: $WINDOWS_HOST"
        fi
    else
        log_warning "未检测到WSL环境"
    fi
}

# 完成安装
finish_installation() {
    log_info "安装过程已完成"
    
    echo ""
    echo "======================================================"
    echo "    WSL内网穿透工具已在WSL环境中成功部署"
    echo "======================================================"
    echo ""
    echo "安装目录: $INSTALL_DIR"
    echo ""
    echo "启动方法:"
    echo "1. 使用快捷命令: wsl-tunnel"
    echo "2. 或进入安装目录: cd $INSTALL_DIR && ./start.sh"
    echo ""
    echo "访问地址: http://localhost:$FRONTEND_PORT"
    echo ""
    echo "其他命令:"
    echo "- 查看状态: wsl-tunnel status"
    echo "- 停止服务: wsl-tunnel stop"
    echo "- 重启服务: wsl-tunnel restart"
    echo ""
    echo "查看更多文档: $INSTALL_DIR/README.md"
    echo "======================================================"
    echo ""
    
    # 询问是否立即启动
    read -p "是否立即启动WSL内网穿透工具? (y/n): " start_now
    if [[ "$start_now" == "y" || "$start_now" == "Y" ]]; then
        cd "$INSTALL_DIR"
        ./start.sh
    else
        log_info "你可以稍后使用 'wsl-tunnel' 命令启动服务"
    fi
}

# 主函数
main() {
    log_info "开始在WSL环境中部署WSL内网穿透工具..."
    
    # 检测WSL环境
    detect_wsl_info
    
    # 检查系统依赖
    check_dependencies
    
    # 设置代码库
    setup_repository
    
    # 安装项目依赖
    install_dependencies
    
    # 配置工具设置
    configure_tool
    
    # 创建快捷方式
    create_shortcuts
    
    # 完成安装
    finish_installation
}

# 执行主函数
main