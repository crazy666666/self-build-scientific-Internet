#!/usr/bin/env bash
set -Eeuo pipefail

[[ ${EUID} -eq 0 ]] || { echo "请使用 sudo 运行：sudo bash uninstall.sh" >&2; exit 1; }

systemctl disable --now shadowsocks-rust.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/shadowsocks-rust.service
rm -f /usr/local/bin/ssserver
systemctl daemon-reload

if [[ "${PURGE:-0}" == "1" ]]; then
  rm -rf /etc/shadowsocks-rust
  rm -f /root/shadowsocks-rust-client.txt
  userdel shadowsocks-rust >/dev/null 2>&1 || true
  echo "已卸载程序，并删除配置和密码。"
else
  echo "已卸载程序；配置和密码仍保留。"
  echo "如需彻底删除：sudo PURGE=1 bash uninstall.sh"
fi
