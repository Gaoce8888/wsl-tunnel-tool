#!/bin/bash

# WSL内网穿透配置工具 - 一键部署脚本
# 此脚本用于快速部署WSL内网穿透工具到服务器

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
REPO_URL="https://github.com/Gaoce8888/wsl-tunnel-tool.git"
INSTALL_DIR="/opt/wsl-tunnel-tool"
PORT=8080
DOMAIN=""
USE_NGINX=true
USE_PM2=true

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo)
            REPO_URL="$2"
            shift 2
            ;;
        --dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --no-nginx)
            USE_NGINX=false
            shift
            ;;
        --no-pm2)
            USE_PM2=false
            shift
            ;;
        --help)
            echo "WSL内网穿透配置工具 - 一键部署脚本"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --repo URL       Git仓库地址 (默认: $REPO_URL)"
            echo "  --dir PATH       安装目录 (默认: $INSTALL_DIR)"
            echo "  --port NUMBER    服务端口 (默认: $PORT)"
            echo "  --domain DOMAIN  域名 (如果有)"
            echo "  --no-nginx       不使用Nginx"
            echo "  --no-pm2         不使用PM2管理进程"
            echo "  --help           显示此帮助信息"
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
    
    # 检查Node.js
    if ! command -v node &> /dev/null; then
        log_warning "未检测到Node.js，正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi
    
    # 检查npm
    if ! command -v npm &> /dev/null; then
        log_warning "未检测到npm，正在安装..."
        apt-get install -y npm
    fi
    
    # 检查git
    if ! command -v git &> /dev/null; then
        log_warning "未检测到Git，正在安装..."
        apt-get install -y git
    fi
    
    # 如果使用PM2，检查并安装
    if [ "$USE_PM2" = true ]; then
        if ! command -v pm2 &> /dev/null; then
            log_warning "未检测到PM2，正在安装..."
            npm install -g pm2
        fi
    fi
    
    # 如果使用Nginx，检查并安装
    if [ "$USE_NGINX" = true ]; then
        if ! command -v nginx &> /dev/null; then
            log_warning "未检测到Nginx，正在安装..."
            apt-get install -y nginx
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
    
    log_success "代码库已设置"
}

# 安装依赖
install_dependencies() {
    log_info "安装项目依赖..."
    cd "$INSTALL_DIR"
    npm install
    log_success "依赖安装完成"
}

# 构建前端
build_frontend() {
    log_info "构建前端应用..."
    cd "$INSTALL_DIR"
    npm run build
    log_success "前端构建完成"
}

# 配置Nginx
configure_nginx() {
    if [ "$USE_NGINX" = true ]; then
        log_info "配置Nginx..."
        
        # 创建Nginx配置文件
        NGINX_CONF="/etc/nginx/sites-available/wsl-tunnel-tool"
        
        if [ -n "$DOMAIN" ]; then
            # 使用域名配置
            cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
            log_info "已为域名 $DOMAIN 创建Nginx配置"
        else
            # 使用端口配置
            cat > "$NGINX_CONF" << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
            log_info "已创建默认Nginx配置"
        fi
        
        # 启用站点配置
        ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
        
        # 测试配置并重启Nginx
        nginx -t && systemctl restart nginx
        
        log_success "Nginx配置完成"
    else
        log_info "跳过Nginx配置"
    fi
}

# 设置PM2进程
setup_pm2() {
    if [ "$USE_PM2" = true ]; then
        log_info "配置PM2进程..."
        
        cd "$INSTALL_DIR"
        
        # 创建PM2配置文件
        cat > ecosystem.config.js << EOF
module.exports = {
  apps : [{
    name: 'wsl-tunnel-tool',
    script: 'node_modules/.bin/vite',
    args: 'preview --port $PORT --host',
    env: {
      NODE_ENV: 'production',
    },
    watch: false,
    max_memory_restart: '300M'
  }]
};
EOF
        
        # 启动PM2进程
        pm2 start ecosystem.config.js
        pm2 save
        
        # 设置开机自启
        pm2 startup
        
        log_success "PM2配置完成"
    else
        log_info "跳过PM2配置"
    fi
}

# 创建直接启动脚本
create_start_script() {
    log_info "创建启动脚本..."
    
    cat > "$INSTALL_DIR/start_prod.sh" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
NODE_ENV=production node_modules/.bin/vite preview --port $PORT --host
EOF
    
    chmod +x "$INSTALL_DIR/start_prod.sh"
    
    log_success "启动脚本已创建: $INSTALL_DIR/start_prod.sh"
}

# 显示完成信息
show_completion_info() {
    echo ""
    echo "======================================================"
    echo "          WSL内网穿透工具部署完成                   "
    echo "======================================================"
    echo ""
    
    if [ "$USE_NGINX" = true ]; then
        if [ -n "$DOMAIN" ]; then
            log_success "您可以通过以下地址访问WSL内网穿透工具："
            echo "http://$DOMAIN"
        else
            log_success "您可以通过以下地址访问WSL内网穿透工具："
            echo "http://[服务器IP]"
        fi
    else
        PUBLIC_IP=$(curl -s ifconfig.me)
        log_success "您可以通过以下地址访问WSL内网穿透工具："
        echo "http://$PUBLIC_IP:$PORT"
    fi
    
    echo ""
    if [ "$USE_PM2" = true ]; then
        echo "WSL内网穿透工具已通过PM2在后台运行，并已设置开机自启"
        echo "管理命令:"
        echo "  pm2 status                  # 查看状态"
        echo "  pm2 logs wsl-tunnel-tool    # 查看日志"
        echo "  pm2 restart wsl-tunnel-tool # 重启服务"
        echo "  pm2 stop wsl-tunnel-tool    # 停止服务"
    else
        echo "要启动WSL内网穿透工具，请运行:"
        echo "$INSTALL_DIR/start_prod.sh"
    fi
    echo ""
    echo "常见问题:"
    echo "  1. 如果无法访问，请检查防火墙是否已开放80端口（Nginx）或 $PORT 端口（直接访问）"
    echo "  2. 客户端脚本位于 $INSTALL_DIR/client/wsl-tunnel.sh"
    echo "  3. 服务器安装脚本位于 $INSTALL_DIR/server/install.sh"
    echo ""
    echo "======================================================"
}

# 主函数
main() {
    log_info "开始部署WSL内网穿透工具..."
    
    # 检查并安装依赖
    check_dependencies
    
    # 设置代码库
    setup_repository
    
    # 安装项目依赖
    install_dependencies
    
    # 构建前端
    build_frontend
    
    # 配置Nginx
    configure_nginx
    
    # 设置PM2
    setup_pm2
    
    # 创建启动脚本
    create_start_script
    
    # 显示完成信息
    show_completion_info
}

# 执行主函数
main