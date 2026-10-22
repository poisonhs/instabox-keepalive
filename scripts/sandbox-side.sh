#!/bin/sh
# 云沙盒保活 —— 沙盒侧安装
#
# 在沙盒内以 root 执行：
#   sh sandbox-side.sh [端口，默认 3000]
#
# 作用：装一个常驻监听，供外部定时访问，证明"有人在用这个沙盒"。
set -e

PORT="${1:-3000}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "需要 python3，请先安装：apt-get update && apt-get install -y python3" >&2
  exit 1
fi

echo "[1/3] 准备静态页"
mkdir -p /var/www/ka
echo "keepalive $(date -Is)" > /var/www/ka/index.html

echo "[2/3] 写入 ka-http.service（监听 ${PORT}）"
cat > /etc/systemd/system/ka-http.service <<EOF
[Unit]
Description=Keepalive listener on port ${PORT}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/var/www/ka
ExecStart=/usr/bin/python3 -m http.server ${PORT} --bind 0.0.0.0
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[3/3] 启动并验证"
systemctl daemon-reload
systemctl enable --now ka-http.service
sleep 2
systemctl is-active ka-http.service
ss -tlnp | grep ":${PORT}" || { echo "端口 ${PORT} 没起来" >&2; exit 1; }

echo ""
echo "完成。接下来在另一台机器上执行 outside-side.sh，域名拼法："
echo "  https://${PORT}-<MACHINE_ID>.<DOMAIN>"
echo "机器 ID 取自：cat /etc/instabox/identity | sed 's/^m_//'"
