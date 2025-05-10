# WSL内网穿透工具 - WSL环境部署指南

本文档提供在WSL(Windows Subsystem for Linux)环境中部署和使用WSL内网穿透工具的详细指南。

## 什么是WSL内网穿透工具？

WSL内网穿透工具是一个用于在WSL环境中实现内网穿透的工具，它可以通过外网服务器访问本地WSL环境中的服务。通过简单的Web界面，你可以轻松管理和配置穿透服务，实现：

- 远程访问WSL中运行的开发服务器
- 将WSL环境中的应用服务临时发布到互联网
- 在任何地方安全地访问WSL中的数据库服务
- 实现IoT设备与WSL环境的连接等

## 系统要求

- WSL 1或WSL 2环境
- 支持的Linux发行版：Ubuntu, Debian, CentOS等
- 外网服务器（具有公网IP的主机，用于实现穿透）
- 基本依赖：Node.js, npm, Git（脚本会自动安装）

## 快速部署

### 方法1：一键部署（推荐）

我们提供了一键部署脚本，只需在WSL终端中运行以下命令：

```bash
# 克隆仓库并运行部署脚本
git clone https://github.com/Gaoce8888/wsl-tunnel-tool.git
cd wsl-tunnel-tool
chmod +x deploy-to-wsl.sh
./deploy-to-wsl.sh
```

脚本会自动执行以下操作：
- 检测WSL环境信息
- 安装必要的依赖
- 配置工具
- 创建快捷命令
- 提供使用指南

### 方法2：自定义部署

如果需要自定义安装参数，可以使用以下选项：

```bash
./deploy-to-wsl.sh --dir ~/my-tunnel-tool --frontend-port 9090 --backend-port 3030
```

可用选项：
- `--dir PATH`：自定义安装目录（默认：`$HOME/wsl-tunnel-tool`）
- `--repo URL`：自定义Git仓库地址
- `--frontend-port PORT`：自定义前端服务端口（默认：8080）
- `--backend-port PORT`：自定义后端API端口（默认：3000）
- `--help`：显示帮助信息

## 使用方法

### 启动服务

部署完成后，可以通过以下方式启动服务：

1. 使用快捷命令（推荐）：
   ```bash
   wsl-tunnel
   ```

2. 或者在安装目录中启动：
   ```bash
   cd ~/wsl-tunnel-tool
   ./start.sh
   ```

### 管理服务

服务启动后，可以使用以下命令管理：

```bash
# 查看服务状态
wsl-tunnel status

# 停止服务
wsl-tunnel stop

# 重启服务
wsl-tunnel restart
```

### 访问Web界面

服务启动后，在浏览器中访问：

```
http://localhost:8080
```

（如果你在部署时修改了前端端口，请使用你指定的端口）

## 配置穿透服务

1. 在Web界面中，点击"服务器配置"，配置外网服务器信息：
   - 服务器IP/域名
   - SSH端口（默认22）
   - 登录用户名和密码/密钥

2. 测试连接成功后，点击"安装组件"，自动在外网服务器上安装必要组件

3. 在"穿透配置"页面，点击"新增转发规则"创建穿透隧道：
   - 规则名称：为隧道取一个名字
   - 协议类型：选择TCP、UDP、HTTP或HTTPS
   - WSL端口：本地WSL环境中需要穿透的服务端口
   - 远程端口：外网服务器上用于访问的端口
   - 高级选项：可配置带宽限制、压缩和加密选项

4. 点击"保存"创建隧道，然后点击操作栏中的"启动"按钮启动隧道

5. 通过公网地址+远程端口访问WSL中的服务

## 常见问题解答

### 无法连接到外网服务器

- 检查服务器IP和SSH端口是否正确
- 确认服务器防火墙允许SSH连接
- 验证用户名和密码/密钥是否正确
- 检查网络连接是否稳定

### 隧道无法启动

- 检查服务器和WSL环境的网络连接
- 确认服务器上的FRP服务正在运行
- 查看日志获取详细错误信息（通常在`~/wsl-tunnel-tool/logs`目录下）
- 确保WSL端口没有被防火墙阻止

### 依赖安装失败

- 运行脚本自带的npm修复工具：`~/wsl-tunnel-tool/npm-fix.sh`
- 检查网络连接和npm源设置
- 尝试手动安装依赖：`cd ~/wsl-tunnel-tool && npm install`

### 外网无法访问穿透的服务

- 确认隧道状态显示为"运行中"
- 检查外网服务器的防火墙规则，确保远程端口已开放
- 检查穿透的服务在WSL环境中是否正常运行
- 查看logs目录下的日志文件获取详细信息

## 安全建议

1. 使用强密码或SSH密钥认证连接服务器
2. 定期更新服务器和WSL环境中的系统和软件
3. 使用加密选项传输敏感数据
4. 不要将含有敏感信息的穿透服务暴露在公网
5. 对HTTP/HTTPS服务建议配置HTTPS证书
6. 使用防火墙限制对外网服务器端口的访问

## 卸载

如果需要卸载WSL内网穿透工具，可以使用以下命令：

```bash
# 停止服务
wsl-tunnel stop

# 删除快捷命令
rm -f ~/bin/wsl-tunnel

# 删除安装目录
rm -rf ~/wsl-tunnel-tool
```

## 获取帮助

- 查看项目文档：`~/wsl-tunnel-tool/README.md`
- 查看脚本帮助：`./deploy-to-wsl.sh --help`
- 查看服务状态：`wsl-tunnel status`
- 查看日志文件：`~/wsl-tunnel-tool/logs`

---

*WSL内网穿透工具 - 让您的WSL环境无处不在*