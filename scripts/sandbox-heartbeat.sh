#!/bin/sh
# 沙盒侧心跳 —— 诊断仪，不是保活手段
#
# 它的作用只有一个：在日志里留下 SUSPENDED_GAP 记录，
# 用来区分「心跳没跑」和「心跳跑了但平台不认」。
#
# 前者是脚本问题，后者说明冻结在宿主机层面 —— 这两种情况后续动作完全不同。
#
# 安装：
#   install -m 755 sandbox-heartbeat.sh /usr/local/bin/sandbox-heartbeat.sh
#   cat > /etc/systemd/system/sandbox-heartbeat.service <<'EOF'
#   [Unit]
#   Description=Sandbox heartbeat probe
#
#   [Service]
#   Type=oneshot
#   ExecStart=/usr/local/bin/sandbox-heartbeat.sh
#   EOF
#   cat > /etc/systemd/system/sandbox-heartbeat.timer <<'EOF'
#   [Unit]
#   Description=Run heartbeat every minute
#
#   [Timer]
#   OnBootSec=30
#   OnUnitActiveSec=1min
#   AccuracySec=5s
#
#   [Install]
#   WantedBy=timers.target
#   EOF
#   systemctl daemon-reload && systemctl enable --now sandbox-heartbeat.timer
#
# 判读：
#   tail -n 20 /var/log/sandbox-heartbeat.log
#   时间戳连续 = 没被冻结
#   出现 SUSPENDED_GAP: Ns = 被冻结了 N 秒
#
# 注意：间隔不要拉到 2 分钟以上，否则断档判定会失真。

LOG=/var/log/sandbox-heartbeat.log
GAP_THRESHOLD=300

now=$(date +%s)

if [ -f "$LOG" ]; then
  last=$(tail -n 1 "$LOG" 2>/dev/null)
  lastts=$(date -d "${last%% *}" +%s 2>/dev/null || echo 0)
  if [ "$lastts" -gt 0 ] && [ $((now - lastts)) -gt "$GAP_THRESHOLD" ]; then
    echo "SUSPENDED_GAP: $((now - lastts))s" >> "$LOG"
  fi
fi

date -Is >> "$LOG"

# 下面这段是可选的 CPU 负载，仅用于测试「平台是否看 CPU」这个假设。
# 实测结论：不看。保留它只是为了复现实验，默认关闭。
# if chrt --idle 0 true 2>/dev/null; then
#   nice -n 19 chrt --idle 0 timeout 3 yes > /dev/null 2>&1
# else
#   timeout 3 yes > /dev/null 2>&1
# fi
