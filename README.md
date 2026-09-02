Ubuntu Bootstrap

🚀 Bootstrap a fresh Ubuntu machine into a ready-to-use development environment.

ubuntu-bootstrap 是一个用于 Ubuntu 新机初始化与开发环境配置 的自动化脚本。

适用于新安装的 Ubuntu Desktop / Server，以及云服务器、虚拟机等环境。

通过一个脚本完成基础系统配置、常用工具安装、Python 环境、Git、SSH、防火墙和时区等初始化工作。

✨ Features
🐧 Ubuntu system initialization
📦 Install common development tools
🐍 Install and configure Python
🔧 Install and configure pyenv
🌱 Configure Git username and email
🔐 Generate SSH keys
🛡️ Configure UFW firewall
🕐 Configure system timezone
🧹 Basic system cleanup
⚡ One-command bootstrap
📋 Requirements
Ubuntu 22.04 / 24.04+
sudo privileges
Internet connection

建议在一台全新的 Ubuntu 环境中运行。

🚀 Quick Start

Clone the repository:

git clone https://github.com/2366504649/HandBook.git
cd HandBook/SDK/Linux


或者直接下载初始化脚本：

curl -o init_ubuntu.sh \
https://raw.githubusercontent.com/2366504649/HandBook/main/SDK/Linux/init_ubuntu.sh


赋予执行权限：

chmod +x init_ubuntu.sh


运行：

./init_ubuntu.sh

⚙️ Configuration

可以通过环境变量自定义初始化参数：

PYTHON_VERSION=3.14.7 \
PYENV_VERSION=v2.8.1 \
GIT_USER_NAME="Your Name" \
GIT_USER_EMAIL="you@example.com" \
SSH_KEY_EMAIL="you@example.com" \
TIMEZONE=Asia/Shanghai \
ENABLE_UFW=1 \
./init_ubuntu.sh

Configuration Options
Variable	Example	Description
PYTHON_VERSION	3.14.7	Python version to install
PYENV_VERSION	v2.8.1	pyenv version
GIT_USER_NAME	Your Name	Git username
GIT_USER_EMAIL	you@example.com	Git email
SSH_KEY_EMAIL	you@example.com	Email associated with SSH key
TIMEZONE	Asia/Shanghai	System timezone
ENABLE_UFW	1	Enable UFW firewall
🔐 SSH Key

如果启用了 SSH Key 配置，脚本会根据：

SSH_KEY_EMAIL="you@example.com"


生成 SSH Key。

生成后可以查看：

cat ~/.ssh/id_ed25519.pub


然后将公钥添加到 GitHub / GitLab 等代码托管平台。

测试 GitHub SSH：

ssh -T git@github.com

🛡️ Firewall

如果：

ENABLE_UFW=1


脚本会启用 UFW。

建议在远程服务器上运行脚本前确认 SSH 端口已经放行，避免因为防火墙配置错误导致 SSH 连接中断。

例如：

sudo ufw allow OpenSSH
sudo ufw enable


查看状态：

sudo ufw status

🐍 Python Environment

项目支持通过环境变量指定 Python 版本：

PYTHON_VERSION=3.14.7


例如：

PYTHON_VERSION=3.14.7 ./init_ubuntu.sh


如果使用 pyenv，可以查看当前 Python：

python --version
pyenv version

📁 Project Structure
ubuntu-bootstrap/
├── init_ubuntu.sh
├── README.md
├── scripts/
├── config/
└── ...


项目结构会随着功能增加持续调整。

⚠️ Notes

这个脚本会修改系统环境，因此：

建议在新安装的 Ubuntu 上运行
运行前检查脚本内容
不建议在生产服务器上直接运行未经测试的版本
如果启用了 UFW，请确保 SSH 已经放行
某些操作可能需要 sudo 权限

执行脚本前，可以先查看：

less init_ubuntu.sh

🧪 Tested On

目前主要针对：

Ubuntu 22.04 LTS
Ubuntu 24.04 LTS


其他 Ubuntu 版本理论上也可以使用，但未经充分测试。

🗺️ Roadmap
 Zsh / Oh My Zsh
 Docker
 Node.js
 Rust
 Go
 Neovim
 tmux
 Terminal screensaver
 Server security hardening
 Interactive configuration
 Modular installation
 Ubuntu Desktop support
🤝 Contributing

欢迎提交 Issue、Pull Request 或改进建议。

如果你发现脚本在某个 Ubuntu 版本上存在问题，也欢迎提交相关信息。

📄 License

MIT License
