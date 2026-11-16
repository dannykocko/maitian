#!/bin/bash
# 把麦田装成 Linux 开机自启服务（systemd --user）：守护进程 + 可选的远程访问隧道。
#   scripts/install-systemd.sh            安装守护进程
#   scripts/install-systemd.sh --tunnel   顺带安装 cloudflared 隧道
#   scripts/install-systemd.sh --uninstall
# 单元名前缀默认 maitian，可用环境变量 MAITIAN_UNIT_PREFIX 改。
# 注意：用户级服务默认只在你登录时跑；想让它注销后也一直跑，执行一次：loginctl enable-linger $USER
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
NODE=$(command -v node)
PREFIX=${MAITIAN_UNIT_PREFIX:-maitian}
UNITS=$HOME/.config/systemd/user
mkdir -p "$ROOT/data" "$UNITS"
command -v systemctl >/dev/null || { echo "没找到 systemctl：这台机器不是 systemd 系统"; exit 1; }

unit() {   # $1 单元名  $2 脚本  $3 参数  $4 描述
  cat > "$UNITS/$1.service" <<EOF
[Unit]
Description=$4
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$NODE $ROOT/$2${3:+ $3}
WorkingDirectory=$ROOT
Environment=PATH=$(dirname "$NODE"):/usr/local/bin:/usr/bin:/bin
Restart=on-failure
RestartSec=60

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now "$1.service"
  echo "已安装 $1（日志：journalctl --user -u $1 -f）"
}

if [[ "$1" == "--uninstall" ]]; then
  for u in "$PREFIX-daemon" "$PREFIX-tunnel"; do systemctl --user disable --now "$u.service" 2>/dev/null && echo "已卸载 $u"; rm -f "$UNITS/$u.service"; done
  systemctl --user daemon-reload
  exit 0
fi
[[ -f "$ROOT/config.json" ]] || { echo "先复制 config.example.json 为 config.json 并填好"; exit 1; }
unit "$PREFIX-daemon" src/hub.mjs daemon "麦田守护进程"
[[ "$1" == "--tunnel" ]] && unit "$PREFIX-tunnel" src/tunnel.mjs "" "麦田远程访问隧道"
if [[ "$(loginctl show-user "$USER" -p Linger 2>/dev/null)" != "Linger=yes" ]]; then
  echo "提示：想让服务在注销后也一直跑，执行一次：loginctl enable-linger $USER"
fi
echo "看状态：systemctl --user status $PREFIX-daemon"
