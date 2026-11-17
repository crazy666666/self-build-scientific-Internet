#!/usr/bin/env bash
set -Eeuo pipefail

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SERVICE_NAME="shadowsocks-rust"
CONFIG_DIR="/etc/shadowsocks-rust"
CONFIG_FILE="${CONFIG_DIR}/config.json"
PASSWORD_FILE="${CONFIG_DIR}/password"
STATE_FILE="${CONFIG_DIR}/install.env"
CLIENT_FILE="/root/shadowsocks-rust-client.txt"
SS_PORT="${SS_PORT:-443}"
SS_METHOD="${SS_METHOD:-aes-256-gcm}"
SERVER_IP="${SERVER_IP:-}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

fail() { echo "错误：$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "系统缺少基础命令：$1"; }

[[ ${EUID} -eq 0 ]] || fail "请使用 sudo 运行，例如：sudo SERVER_IP=1.2.3.4 bash install.sh"
[[ "$(uname -s)" == "Linux" ]] || fail "本离线包只支持 Linux。"
need systemctl
need sha256sum
need install
need useradd
need base64
need tr
need od

case "$(uname -m)" in
  x86_64|amd64)
    BINARY="${SCRIPT_DIR}/bin/x86_64/ssserver"
    EXPECTED_SHA256="d63836978a3d2534f0ea1206ca12502b77b965fcfed2958d327353071b6bbf91"
    ;;
  aarch64|arm64)
    BINARY="${SCRIPT_DIR}/bin/aarch64/ssserver"
    EXPECTED_SHA256="9a836be84d6dbacfe727dd22ea6b3e169b633568bb9e27171e1eba625ae1655f"
    ;;
  *) fail "不支持此 CPU：$(uname -m)。仅支持 x86_64 和 ARM64。" ;;
esac
[[ -f "${BINARY}" ]] || fail "离线程序缺失：${BINARY}"
read -r ACTUAL_SHA256 _ < <(sha256sum "${BINARY}")
[[ "${ACTUAL_SHA256}" == "${EXPECTED_SHA256}" ]] || fail "ssserver 校验失败，文件可能损坏，请重新下载离线包。"

[[ "${SS_PORT}" =~ ^[0-9]+$ ]] && (( SS_PORT >= 1 && SS_PORT <= 65535 )) || fail "SS_PORT 必须是 1-65535。"
[[ "${SS_METHOD}" =~ ^[a-z0-9-]+$ ]] || fail "SS_METHOD 格式不正确。"
if [[ -n "${SS_PASSWORD:-}" ]]; then
  [[ "${SS_PASSWORD}" =~ ^[A-Za-z0-9._~-]{8,128}$ ]] || fail "SS_PASSWORD 只能包含字母、数字和 . _ ~ -，长度 8-128。"
fi

if [[ -z "${SERVER_IP}" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "请输入这台服务器的公网 IPv4 地址：" SERVER_IP
  else
    fail "请指定公网 IP，例如：sudo SERVER_IP=1.2.3.4 bash install.sh"
  fi
fi
[[ "${SERVER_IP}" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || fail "SERVER_IP 必须是 IPv4 地址。"
IFS=. read -r IP1 IP2 IP3 IP4 <<<"${SERVER_IP}"
for OCTET in "${IP1}" "${IP2}" "${IP3}" "${IP4}"; do
  (( 10#${OCTET} <= 255 )) || fail "SERVER_IP 不是有效的 IPv4 地址。"
done

if ! id -u shadowsocks-rust >/dev/null 2>&1; then
  useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin shadowsocks-rust
fi
install -m 0755 "${BINARY}" /usr/local/bin/ssserver
install -d -m 0750 -o root -g shadowsocks-rust "${CONFIG_DIR}"

if [[ -z "${SS_PASSWORD:-}" && -s "${PASSWORD_FILE}" ]]; then
  IFS= read -r SS_PASSWORD <"${PASSWORD_FILE}"
fi
[[ -n "${SS_PASSWORD:-}" ]] || SS_PASSWORD="$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')"
printf '%s\n' "${SS_PASSWORD}" >"${PASSWORD_FILE}"
chown root:root "${PASSWORD_FILE}"
chmod 0600 "${PASSWORD_FILE}"

umask 077
cat >"${CONFIG_FILE}" <<EOF
{
  "server": "0.0.0.0",
  "server_port": ${SS_PORT},
  "password": "${SS_PASSWORD}",
  "method": "${SS_METHOD}",
  "mode": "tcp_and_udp"
}
EOF
chown root:shadowsocks-rust "${CONFIG_FILE}"
chmod 0640 "${CONFIG_FILE}"

cat >"${STATE_FILE}" <<EOF
SS_PORT=${SS_PORT}
SS_METHOD=${SS_METHOD}
SERVER_IP=${SERVER_IP}
EOF
chown root:root "${STATE_FILE}"
chmod 0600 "${STATE_FILE}"

cat >/etc/systemd/system/${SERVICE_NAME}.service <<'UNIT'
[Unit]
Description=Shadowsocks Rust Server (Offline Package)
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=shadowsocks-rust
Group=shadowsocks-rust
ExecStart=/usr/local/bin/ssserver -c /etc/shadowsocks-rust/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service" >/dev/null
if ! systemctl restart "${SERVICE_NAME}.service"; then
  systemctl status "${SERVICE_NAME}.service" --no-pager || true
  fail "服务启动失败。最常见原因是端口 ${SS_PORT} 已被其他程序占用。"
fi

USERINFO="$(printf '%s' "${SS_METHOD}:${SS_PASSWORD}" | base64 | tr -d '\n=' | tr '+/' '-_')"
SS_URI="ss://${USERINFO}@${SERVER_IP}:${SS_PORT}#My-SS-Rust"
cat >"${CLIENT_FILE}" <<EOF
服务器: ${SERVER_IP}
端口: ${SS_PORT}
密码: ${SS_PASSWORD}
加密方式: ${SS_METHOD}
模式: TCP+UDP

v2rayN 导入链接:
${SS_URI}
EOF
chmod 0600 "${CLIENT_FILE}"

sleep 1
systemctl is-active --quiet "${SERVICE_NAME}.service" || fail "服务没有正常运行。"
if command -v ss >/dev/null 2>&1; then
  ss -lnt | grep -Eq ":${SS_PORT}([[:space:]]|$)" || fail "没有检测到 TCP ${SS_PORT} 监听。"
  ss -lnu | grep -Eq ":${SS_PORT}([[:space:]]|$)" || fail "没有检测到 UDP ${SS_PORT} 监听。"
fi

echo
echo "离线安装完成：$(/usr/local/bin/ssserver --version)"
echo "查看 v2rayN 导入链接：sudo cat ${CLIENT_FILE}"
echo "还要在云服务器控制面板放行 TCP 和 UDP ${SS_PORT}。"
