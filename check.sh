#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID} -eq 0 ]] || { echo "请使用 sudo 运行：sudo bash check.sh" >&2; exit 1; }
SERVICE_NAME="shadowsocks-rust"
STATE_FILE="/etc/shadowsocks-rust/install.env"

[[ -x /usr/local/bin/ssserver ]] || { echo "未找到 ssserver。" >&2; exit 1; }
[[ -f "${STATE_FILE}" ]] || { echo "未找到安装状态文件。" >&2; exit 1; }
# 文件由安装程序创建，仅 root 可写。
source "${STATE_FILE}"

systemctl is-enabled --quiet "${SERVICE_NAME}.service"
systemctl is-active --quiet "${SERVICE_NAME}.service"
if command -v ss >/dev/null 2>&1; then
  ss -lnt | grep -Eq ":${SS_PORT}([[:space:]]|$)"
  ss -lnu | grep -Eq ":${SS_PORT}([[:space:]]|$)"
fi

echo "程序版本：$(/usr/local/bin/ssserver --version)"
echo "检查通过：服务已开机启动，配置端口为 TCP/UDP ${SS_PORT}。"
echo "导入信息：sudo cat /root/shadowsocks-rust-client.txt"
