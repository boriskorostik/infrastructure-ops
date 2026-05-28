#!/usr/bin/env python3
"""Tail remote files over SSH and forward lines to local Graylog Syslog TCP."""

from __future__ import annotations

import argparse
import shlex
import socket
import subprocess
import time
from datetime import datetime, timezone


def now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def send(host: str, port: int, source: str, app: str, message: str) -> None:
    payload = f"<14>1 {now()} {source} {app} - - - {message.rstrip()}\n"
    with socket.create_connection((host, port), timeout=5) as sock:
        sock.sendall(payload.encode("utf-8", "replace"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ssh-host", required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--graylog-host", default="127.0.0.1")
    parser.add_argument("--graylog-port", type=int, default=1514)
    parser.add_argument("--path", action="append", required=True)
    parser.add_argument("--remote-command")
    args = parser.parse_args()

    ssh_base = ["ssh", "-o", "BatchMode=yes", "-o", "RemoteCommand=none", "-o", "RequestTTY=no", args.ssh_host]
    ssh_cmd = ssh_base + (shlex.split(args.remote_command) if args.remote_command else ["tail", "-n0", "-F", *args.path])

    while True:
        proc = subprocess.Popen(ssh_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
        assert proc.stdout is not None
        for line in proc.stdout:
            if not line.strip():
                continue
            app = "remote-tail"
            if "==> " in line and " <==" in line:
                app = line.strip().strip("=").strip().replace("/", "_")[:48]
                continue
            try:
                send(args.graylog_host, args.graylog_port, args.source, app, line)
            except OSError:
                time.sleep(5)
        proc.wait()
        time.sleep(10)


if __name__ == "__main__":
    raise SystemExit(main())
