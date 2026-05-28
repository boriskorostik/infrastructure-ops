#!/usr/bin/env python3
"""Small user-level file tailer that forwards lines to Graylog Syslog TCP."""

from __future__ import annotations

import argparse
import glob
import os
import socket
import time
from datetime import datetime, timezone
from pathlib import Path


def rfc3339_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def iter_files(patterns: list[str]) -> list[Path]:
    result: list[Path] = []
    for pattern in patterns:
        result.extend(Path(path) for path in glob.glob(pattern))
    return sorted({path for path in result if path.is_file()})


def open_at_end(path: Path):
    handle = path.open("r", encoding="utf-8", errors="replace")
    handle.seek(0, os.SEEK_END)
    return handle


def send_syslog(host: str, port: int, hostname: str, app: str, message: str) -> None:
    line = f"<14>1 {rfc3339_now()} {hostname} {app} - - - {message.rstrip()}\n"
    with socket.create_connection((host, port), timeout=5) as sock:
        sock.sendall(line.encode("utf-8", "replace"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--graylog-host", default="172.16.0.5")
    parser.add_argument("--graylog-port", type=int, default=1514)
    parser.add_argument("--hostname", default=socket.gethostname())
    parser.add_argument("--pattern", action="append", required=True)
    parser.add_argument("--scan-interval", type=float, default=10)
    args = parser.parse_args()

    handles: dict[Path, object] = {}
    while True:
        for path in iter_files(args.pattern):
            if path not in handles:
                try:
                    handles[path] = open_at_end(path)
                except OSError:
                    continue
            handle = handles[path]
            while True:
                where = handle.tell()
                line = handle.readline()
                if not line:
                    handle.seek(where)
                    break
                app = path.name.replace(" ", "_")[:48]
                try:
                    send_syslog(args.graylog_host, args.graylog_port, args.hostname, app, line)
                except OSError:
                    handle.seek(where)
                    time.sleep(args.scan_interval)
                    break
        time.sleep(args.scan_interval)


if __name__ == "__main__":
    raise SystemExit(main())
