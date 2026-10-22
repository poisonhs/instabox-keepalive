# systemd 单元参考
#
# 这些文件由 scripts/ 下的安装脚本自动生成，这里存档供查阅和手工部署。
# 实际安装直接跑脚本，不要手动复制粘贴，容易漏掉 `systemctl daemon-reload`。

## 沙盒侧：常驻监听（ka-http.service）

```ini
[Unit]
Description=Keepalive listener on port 3000
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/var/www/ka
ExecStart=/usr/bin/python3 -m http.server 3000 --bind 0.0.0.0
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## 外部侧：定时敲门（sandbox-poke.service + .timer）

```ini
# sandbox-poke.service
[Unit]
Description=Poke cloud sandbox to reset idle timer

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sandbox-poke.sh
```

```ini
# sandbox-poke.timer
[Unit]
Description=Poke cloud sandbox every 5 minutes

[Timer]
OnBootSec=30
OnUnitActiveSec=5min
AccuracySec=20s

[Install]
WantedBy=timers.target
```

## 外部侧：长连接（sandbox-hold.service）

```ini
[Unit]
Description=Hold HTTPS keep-alive session to cloud sandbox
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/sandbox-hold.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## 沙盒侧：诊断心跳（sandbox-heartbeat.service + .timer）

```ini
# sandbox-heartbeat.service
[Unit]
Description=Sandbox heartbeat probe

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sandbox-heartbeat.sh
```

```ini
# sandbox-heartbeat.timer
[Unit]
Description=Run heartbeat every minute
# AccuracySec 不要放大，间隔不要超过 1 分钟，否则断档判定失真
[Timer]
OnBootSec=30
OnUnitActiveSec=1min
AccuracySec=5s

[Install]
WantedBy=timers.target
```

## 关键字段说明

| 字段 | 作用 | 漏了会怎样 |
|---|---|---|
| `Restart=always` | 进程退出即重启 | 断线后不再自愈 |
| `RestartSec` | 重启间隔 | 太短会刷日志，10 秒合适 |
| `StartLimitIntervalSec=0` | 取消启动频率限制 | 反复失败后 systemd 放弃重启 |
| `After=network-online.target` | 等网络就绪 | 开机时抢跑，连接失败 |
