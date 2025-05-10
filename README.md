# WSL内网穿透工具

一个用于Windows WSL环境的内网穿透工具，支持通过外网服务器访问本地WSL环境中的服务。

## 功能特性

- 🚀 **一键穿透**: 简单几步配置，快速建立穿透隧道
- 🔧 **多协议支持**: 支持TCP、UDP、HTTP、HTTPS等多种协议
- 🔒 **安全可靠**: 支持SSH密钥认证，数据传输加密
- 📊 **可视化管理**: 直观的Web界面管理所有穿透配置
- 🔄 **自动安装**: 自动在远程服务器安装所需组件
- 📝 **实时日志**: 查看穿透状态和连接日志
- 🌐 **多隧道管理**: 支持创建和管理多个穿透隧道

## 系统要求

- **WSL环境**: 
  - 支持WSL1和WSL2
  - Ubuntu, Debian, CentOS等Linux发行版
- **外网服务器**:
  - 具有公网IP地址
  - 支持SSH连接
  - 推荐Ubuntu 18.04+/Debian 10+
- **开发环境**:
  - Node.js 14+ (前端开发)
  - npm 6+ (依赖管理)

## 快速开始

### 安装

1. 克隆项目仓库:

```bash
git clone https://github.com/Gaoce8888/wsl-tunnel-tool.git
cd wsl-tunnel-tool
```

2. 启动工具:

```bash
./start.sh
```

3. 打开浏览器访问:

```
http://localhost:8080
```