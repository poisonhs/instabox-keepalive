#!/usr/bin/env python3
"""云沙盒保活 —— 外部侧长连接版（可选加固）

与批量敲门的区别：
  - 敲门脚本每次新建连接，请求完就断
  - 本脚本一次 TLS 握手后把连接一直挂着，每 60 秒在同一个 TCP 会话上再打一次

网关看到的是持续会话，而不是零散的独立请求。

用法：
  1. 把 HOST 改成沙盒的端口映射域名
  2. systemd 单元见文件末尾注释

节奏：
  60 秒。15 秒一次会吃 429（网关限流），不要调短。

验证连接是否复用：
  ss -tnp | grep <网关IP>     # 本地端口不变即复用
"""
import datetime
import http.client
import ssl
import time

# ==== 改这里 ====
HOST = "3000-<MACHINE_ID>.<DOMAIN>"
# ================

LOG = "/var/log/sandbox-hold.log"
UA = "sandbox-hold/1.0"
INTERVAL = 60
PINGS_PER_CONN = 60


def log(msg: str) -> None:
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(f"{datetime.datetime.now().isoformat(timespec='seconds')} {msg}\n")


def main() -> None:
    ctx = ssl.create_default_context()
    while True:
        try:
            conn = http.client.HTTPSConnection(HOST, 443, timeout=25, context=ctx)
            conn.connect()
            log("CONNECTED")
            for _ in range(PINGS_PER_CONN):
                conn.request(
                    "GET", "/", headers={"Connection": "keep-alive", "User-Agent": UA}
                )
                resp = conn.getresponse()
                body = resp.read()
                log(f"{resp.status} {len(body)}B")
                time.sleep(INTERVAL)
            conn.close()
        except Exception as exc:
            log(f"ERR {type(exc).__name__}: {exc}")
            time.sleep(20)


if __name__ == "__main__":
    main()


# 安装（外部常开机器，root）：
#
# cat > /etc/systemd/system/sandbox-hold.service <<'EOF'
# [Unit]
# Description=Hold HTTPS keep-alive session to cloud sandbox
# After=network-online.target
# Wants=network-online.target
# StartLimitIntervalSec=0
#
# [Service]
# Type=simple
# ExecStart=/usr/bin/python3 /usr/local/bin/sandbox-hold.py
# Restart=always
# RestartSec=10
#
# [Install]
# WantedBy=multi-user.target
# EOF
# systemctl daemon-reload && systemctl enable --now sandbox-hold.service
