#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="${0##*/}"
readonly SUPPORTED_LTS_REGEX='^(22\.04|24\.04|26\.04)$'

PYTHON_VERSION="${PYTHON_VERSION:-latest}"
PYENV_VERSION="${PYENV_VERSION:-latest}"
PYENV_ROOT="${PYENV_ROOT:-${HOME}/.pyenv}"
USE_GIT_PPA="${USE_GIT_PPA:-1}"
INSTALL_SSH_SERVER="${INSTALL_SSH_SERVER:-1}"
ENABLE_UFW="${ENABLE_UFW:-0}"
GIT_USER_NAME="${GIT_USER_NAME:-}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"
SSH_KEY_EMAIL="${SSH_KEY_EMAIL:-}"
TIMEZONE="${TIMEZONE:-}"
SKIP_SYSTEM_UPGRADE="${SKIP_SYSTEM_UPGRADE:-0}"

log() { printf '\n\033[1;34m[%s]\033[0m %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '\n\033[1;33m[%s] WARNING:\033[0m %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { printf '\n\033[1;31m[%s] ERROR:\033[0m %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

on_error() {
  local exit_code=$?
  printf '\n\033[1;31m[%s] failed at line %s (exit %s).\033[0m\n' \
    "$SCRIPT_NAME" "${BASH_LINENO[0]}" "$exit_code" >&2
  exit "$exit_code"
}
trap on_error ERR

is_enabled() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    0|false|no|off) return 1 ;;
    *) die "布尔参数只能是 1/0、true/false、yes/no 或 on/off，收到：$1" ;;
  esac
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少必要命令：$1"
}

check_platform() {
  [[ "${EUID}" -ne 0 ]] || die "请使用普通用户运行；脚本会在需要时调用 sudo。"
  [[ -r /etc/os-release ]] || die "无法读取 /etc/os-release。"

  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || die "仅支持 Ubuntu，检测到：${ID:-unknown}"
  [[ "${VERSION_ID:-}" =~ $SUPPORTED_LTS_REGEX ]] || \
    die "仅支持 Ubuntu 22.04/24.04/26.04 LTS，检测到：${VERSION_ID:-unknown}"

  require_command sudo
  sudo -v
  log "检测到 Ubuntu ${VERSION_ID} (${VERSION_CODENAME:-unknown})，架构 $(uname -m)。"
}

install_apt_packages() {
  local -a packages=(
    apt-transport-https bash-completion build-essential ca-certificates curl
    fd-find git gnupg htop jq libbz2-dev libffi-dev libgdbm-dev liblzma-dev
    libncursesw5-dev libnss3-dev libreadline-dev libsqlite3-dev libssl-dev
    libxml2-dev libxmlsec1-dev lsb-release make nano openssh-client
    pkg-config ripgrep rsync software-properties-common tar tk-dev tree tmux
    unattended-upgrades unzip uuid-dev vim wget xz-utils zip zlib1g-dev
  )

  if is_enabled "$INSTALL_SSH_SERVER"; then
    packages+=(openssh-server)
  fi

  log "更新 APT 索引并安装系统依赖。"
  sudo env DEBIAN_FRONTEND=noninteractive apt-get update
  if ! is_enabled "$SKIP_SYSTEM_UPGRADE"; then
    sudo env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  fi
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
}

install_recent_git() {
  if ! is_enabled "$USE_GIT_PPA"; then
    log "已跳过 Git PPA，使用 Ubuntu 仓库版本。"
    return
  fi

  log "尝试启用 Git 官方推荐的 Ubuntu PPA。"
  if sudo env DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:git-core/ppa \
      && sudo env DEBIAN_FRONTEND=noninteractive apt-get update \
      && sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y git; then
    log "Git PPA 已启用。"
  else
    warn "Git PPA 对当前发行版不可用；继续使用 Ubuntu 仓库中的 Git。"
  fi
}

latest_pyenv_tag() {
  git ls-remote --tags --refs https://github.com/pyenv/pyenv.git 'v*' \
    | awk -F/ '{print $3}' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -n 1
}

install_pyenv() {
  local selected_pyenv="$PYENV_VERSION"
  if [[ "$selected_pyenv" == "latest" ]]; then
    selected_pyenv="$(latest_pyenv_tag)"
    [[ -n "$selected_pyenv" ]] || die "无法解析最新 pyenv 版本。"
  fi
  [[ "$selected_pyenv" == v* ]] || selected_pyenv="v${selected_pyenv}"

  log "安装 pyenv ${selected_pyenv} 到 ${PYENV_ROOT}。"
  if [[ -d "${PYENV_ROOT}/.git" ]]; then
    git -C "$PYENV_ROOT" remote set-url origin https://github.com/pyenv/pyenv.git
    git -C "$PYENV_ROOT" fetch --tags --prune origin
    git -C "$PYENV_ROOT" checkout --detach "$selected_pyenv"
  elif [[ -e "$PYENV_ROOT" ]]; then
    die "${PYENV_ROOT} 已存在但不是 Git 仓库，请先检查或设置其他 PYENV_ROOT。"
  else
    git clone --branch "$selected_pyenv" --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
  fi

  export PYENV_ROOT
  export PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"
  eval "$(pyenv init - bash)"
}

ensure_pyenv_shell_config() {
  local target_file="$1"
  local shell_name="$2"
  local marker='# >>> pyenv managed by init_ubuntu.sh >>>'

  touch "$target_file"
  if grep -Fq "$marker" "$target_file"; then
    return
  fi

  cat >>"$target_file" <<EOF

$marker
export PYENV_ROOT="\$HOME/.pyenv"
[[ -d "\$PYENV_ROOT/bin" ]] && export PATH="\$PYENV_ROOT/bin:\$PATH"
eval "\$(pyenv init - ${shell_name})"
# <<< pyenv managed by init_ubuntu.sh <<<
EOF
}

configure_shells() {
  if [[ "$PYENV_ROOT" != "${HOME}/.pyenv" ]]; then
    warn "使用了自定义 PYENV_ROOT；请自行将 ${PYENV_ROOT}/bin 加入 shell PATH。"
    return
  fi

  log "写入 pyenv Shell 初始化配置。"
  ensure_pyenv_shell_config "${HOME}/.bashrc" bash
  ensure_pyenv_shell_config "${HOME}/.profile" bash
  if [[ -f "${HOME}/.zshrc" ]] || command -v zsh >/dev/null 2>&1; then
    ensure_pyenv_shell_config "${HOME}/.zshrc" zsh
  fi
}

latest_stable_python() {
  pyenv install --list \
    | sed 's/^[[:space:]]*//' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -n 1
}

install_python() {
  local selected_python="$PYTHON_VERSION"
  if [[ "$selected_python" == "latest" ]]; then
    selected_python="$(latest_stable_python)"
    [[ -n "$selected_python" ]] || die "无法解析最新稳定 CPython 版本。"
  fi

  log "安装 CPython ${selected_python}；源码编译可能需要数分钟。"
  pyenv install --skip-existing "$selected_python"
  pyenv global "$selected_python"
  pyenv rehash
  python -m pip install --upgrade pip setuptools wheel
}

configure_git() {
  log "配置 Git 默认选项。"
  git config --global init.defaultBranch main
  git config --global fetch.prune true
  git config --global pull.ff only
  [[ -z "$GIT_USER_NAME" ]] || git config --global user.name "$GIT_USER_NAME"
  [[ -z "$GIT_USER_EMAIL" ]] || git config --global user.email "$GIT_USER_EMAIL"
}

configure_ssh() {
  if is_enabled "$INSTALL_SSH_SERVER"; then
    log "启用 OpenSSH Server。"
    sudo systemctl enable --now ssh
    sudo sshd -t
  fi

  if [[ -n "$SSH_KEY_EMAIL" ]]; then
    install -d -m 700 "${HOME}/.ssh"
    if [[ -e "${HOME}/.ssh/id_ed25519" ]] || [[ -e "${HOME}/.ssh/id_ed25519.pub" ]]; then
      warn "~/.ssh/id_ed25519 已存在，跳过密钥生成。"
    else
      log "生成 Ed25519 SSH 密钥。"
      ssh-keygen -q -t ed25519 -a 100 -C "$SSH_KEY_EMAIL" -f "${HOME}/.ssh/id_ed25519" -N ""
    fi
  fi
}

configure_optional_system_settings() {
  if [[ -n "$TIMEZONE" ]]; then
    log "设置时区为 ${TIMEZONE}。"
    timedatectl list-timezones | grep -Fxq "$TIMEZONE" || die "无效时区：${TIMEZONE}"
    sudo timedatectl set-timezone "$TIMEZONE"
  fi

  if is_enabled "$ENABLE_UFW"; then
    log "先放行 OpenSSH，再启用 UFW。"
    sudo apt-get install -y ufw
    sudo ufw allow OpenSSH
    sudo ufw --force enable
  fi
}

print_summary() {
  log "初始化完成。"
  printf '%-12s %s\n' \
    'OS:' "$(. /etc/os-release; printf '%s' "$PRETTY_NAME")" \
    'Git:' "$(git --version)" \
    'SSH:' "$(ssh -V 2>&1)" \
    'pyenv:' "$(pyenv --version)" \
    'Python:' "$(python --version 2>&1)" \
    'pip:' "$(python -m pip --version)"

  if is_enabled "$INSTALL_SSH_SERVER"; then
    printf '%-12s %s\n' 'sshd:' "$(systemctl is-active ssh)"
  fi
  if is_enabled "$ENABLE_UFW"; then
    sudo ufw status
  fi
  if [[ -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
    printf '\nSSH public key:\n'
    cat "${HOME}/.ssh/id_ed25519.pub"
  fi
  printf '\n请重新登录，或执行：exec "$SHELL" -l\n'
}

main() {
  check_platform
  install_apt_packages
  install_recent_git
  install_pyenv
  configure_shells
  install_python
  configure_git
  configure_ssh
  configure_optional_system_settings
  print_summary
}

main "$@"

