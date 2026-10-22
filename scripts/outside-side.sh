#!/bin/sh
# 云沙盒保活 —— 外部侧安装
#
# 在任意常开的公网机器上以 root 执行：
#   sh outside-side.sh <沙盒的端口映射域名>
#
# 例：
#   sh outside-side.sh 3000-abc123def456.instabox.tech
#
# 必须是另一台机器。沙盒自己访问自己不算外部流量，等于没做。
set -e

HOST="${1:?用法: sh outside-side.sh <域名，不含 https://>}"
POKE=/usr/local/bin/sandbox-poke.sh
LOG=/var/log/sandbox-poke.log

if ! command -v curl >/dev/null 2>&1; then
  echo "需要 curl，请先安装" >&2
  exit 1
fi

echo "[1/3] 写入敲门脚本 $POKE"
cat > "$POKE" <<EOF
#!/bin/sh
URL="https://${HOST}"
LOG=${LOG}
code=\$(curl -s -o /dev/null -w '%{http_code}' -m 20 "\$URL" 2>/dev/null || echo 000)
echo "\$(date -Is) \$code" >> "\$LOG"
EOF
chmod +x "$POKE"

echo "[2/3] 写入 systemd 单元"
cat > /etc/systemd/system/sandbox-poke.service <<'EOF'
[Unit]
Description=Poke cloud sandbox to reset idle timer

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sandbox-poke.sh
EOF

cat > /etc/systemd/system/sandbox-poke.timer <<'EOF'
[Unit]
Description=Poke cloud sandbox every 5 minutes

[Timer]
OnBootSec=30
OnUnitActiveSec=5min
AccuracySec=20s

[Install]
WantedBy=timers.target
EOF

echo "[3/3] 启用并立即试一次"
systemctl daemon-reload
systemctl enable --now sandbox-poke.timer
"$POKE"
sleep 1

LAST=$(tail -n 1 "$LOG" 2>/dev/null || echo "(无记录)")
echo ""
echo "首次结果: $LAST"
case "$LAST" in
  *" 200") echo "OK: 链路通，保活已生效" ;;
  *" 502") echo "警告: 502 说明沙盒里没服务监听，先跑沙盒侧脚本" ;;
  *" 429") echo "警告: 429 被限流，说明请求太密，检查是否有其他任务在打" ;;
  *" 000") echo "警告: 000 表示 DNS 或网络问题，检查域名拼写" ;;
  *)       echo "警告: 返回 $LAST，检查域名和网络" ;;
esac

echo ""
echo "验收要等过平台的空闲窗口再看，三条同时成立才算成功："
echo "  1) uptime 连续不少于 2 天"
echo "  2) 沙盒心跳日志 SUSPENDED_GAP 为 0"
echo "  3) 本日志里没有 502"
