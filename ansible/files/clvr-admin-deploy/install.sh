#!/usr/bin/env bash
set -euo pipefail

INSTALL_USER="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$INSTALL_USER" | cut -d: -f6)"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

CLVR_LOGIN="${CLVR_LOGIN:-dispetcher}"
CLVR_PASSWORD="${CLVR_PASSWORD:-}"
CLVR_IP="${CLVR_IP:-192.168.48.20}"
CLVR_PORT="${CLVR_PORT:-29107}"
CLVR_SPACE="${CLVR_SPACE:-Space79}"
CPU_LIMIT="${CLVR_CPU_LIMIT:-90}"
CPU_TIME="${CLVR_CPU_TIME:-120}"
IP_PROVIDED=0
PORT_PROVIDED=0
LOGIN_PROVIDED=0
SPACE_PROVIDED=0
INSTALL_USER_PROVIDED=0
APPIMAGE_PATH=""

usage() {
    cat <<EOF
Usage:
  sudo -E ./install.sh [options]

Options:
  --login USER        CLVR login, default: ${CLVR_LOGIN}
  --password PASS     CLVR password. If omitted, installer asks interactively.
  --ip ADDRESS        Server IP. If omitted, installer asks interactively.
  --port PORT         Server port. If omitted, installer asks interactively.
  --space NAME        Database/space, default: ${CLVR_SPACE}
  --install-user USER Linux user whose systemd --user service should run.
  --appimage PATH     Install/update CLVR Admin from this AppImage before starting service.
  --cpu-limit N       CPU percent threshold, default: ${CPU_LIMIT}
  --cpu-time SEC      How long CPU must be high before restart, default: ${CPU_TIME}

Example:
  sudo ./install.sh --login dispetcher --ip 192.168.48.20 --port 29107 --space Space79
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --login) CLVR_LOGIN="$2"; LOGIN_PROVIDED=1; shift 2 ;;
        --password) CLVR_PASSWORD="$2"; shift 2 ;;
        --ip) CLVR_IP="$2"; IP_PROVIDED=1; shift 2 ;;
        --port) CLVR_PORT="$2"; PORT_PROVIDED=1; shift 2 ;;
        --space) CLVR_SPACE="$2"; SPACE_PROVIDED=1; shift 2 ;;
        --install-user) INSTALL_USER="$2"; INSTALL_USER_PROVIDED=1; shift 2 ;;
        --appimage) APPIMAGE_PATH="$2"; shift 2 ;;
        --cpu-limit) CPU_LIMIT="$2"; shift 2 ;;
        --cpu-time) CPU_TIME="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo ./install.sh" >&2
    exit 1
fi

if [[ "$INSTALL_USER_PROVIDED" -eq 1 ]]; then
    USER_HOME="$(getent passwd "$INSTALL_USER" | cut -d: -f6)"
    if [[ -z "$USER_HOME" ]]; then
        echo "Linux user not found: ${INSTALL_USER}" >&2
        exit 1
    fi
fi

run_user_systemctl() {
    local uid
    uid="$(id -u "$INSTALL_USER")"
    sudo -u "$INSTALL_USER" \
        XDG_RUNTIME_DIR="/run/user/${uid}" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
        systemctl --user "$@" >/dev/null 2>&1 || true
}

run_any_user_systemctl() {
    local target_user="$1"
    shift
    local uid
    uid="$(id -u "$target_user" 2>/dev/null || true)"
    if [[ -n "$uid" ]]; then
        sudo -u "$target_user" \
            XDG_RUNTIME_DIR="/run/user/${uid}" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
            systemctl --user "$@" >/dev/null 2>&1 || true
    fi
}

cleanup_old_units() {
    local unit user home
    while IFS=: read -r user _ uid _ _ home _; do
        [[ "$uid" =~ ^[0-9]+$ ]] || continue
        (( uid >= 1000 )) || continue
        [[ -d "$home" ]] || continue
        for unit in \
            clvr-admin.service \
            clvr-cpu-watchdog.service \
            clvr-cpu-watchdog.timer \
            clvr-watchdog.service \
            clvr-watchdog.timer \
            clvr.service \
            CLVR-admin.service; do
            run_any_user_systemctl "$user" stop "$unit"
            run_any_user_systemctl "$user" disable "$unit"
            rm -f "${home}/.config/systemd/user/${unit}"
            rm -f "${home}/.config/systemd/user/default.target.wants/${unit}"
            rm -f "${home}/.config/systemd/user/timers.target.wants/${unit}"
        done
        run_any_user_systemctl "$user" daemon-reload
        run_any_user_systemctl "$user" reset-failed
    done < /etc/passwd

    for unit in \
        clvr-admin.service \
        clvr-admin.service.bak \
        clvr-cpu-watchdog.service \
        clvr-cpu-watchdog.timer \
        clvr-watchdog.service \
        clvr-watchdog.timer \
        clvr.service \
        CLVR-admin.service; do
        rm -f "${USER_HOME}/.config/systemd/user/${unit}"
        rm -f "/etc/systemd/user/${unit}"
        rm -f "/etc/xdg/systemd/user/${unit}"
    done
}

ask_value() {
    local prompt="$1"
    local current="$2"
    local result
    read -rp "${prompt} [${current}]: " result
    printf '%s' "${result:-$current}"
}

if [[ "$LOGIN_PROVIDED" -eq 0 ]]; then
    CLVR_LOGIN="$(ask_value "CLVR login" "$CLVR_LOGIN")"
fi

if [[ "$IP_PROVIDED" -eq 0 ]]; then
    CLVR_IP="$(ask_value "IP сервера диспетчеризации" "$CLVR_IP")"
fi

if [[ "$PORT_PROVIDED" -eq 0 ]]; then
    CLVR_PORT="$(ask_value "Порт подключения" "$CLVR_PORT")"
fi

if [[ "$SPACE_PROVIDED" -eq 0 ]]; then
    CLVR_SPACE="$(ask_value "Space / база" "$CLVR_SPACE")"
fi

if ! [[ "$CLVR_PORT" =~ ^[0-9]+$ ]] || (( CLVR_PORT < 1 || CLVR_PORT > 65535 )); then
    echo "Bad port: ${CLVR_PORT}" >&2
    exit 1
fi

if [[ -z "$CLVR_PASSWORD" ]]; then
    read -rsp "CLVR password for ${CLVR_LOGIN}: " CLVR_PASSWORD
    echo
fi

echo "==> 1/6 Очистка старых сервисов и зависших процессов"
run_user_systemctl stop clvr-cpu-watchdog.timer
run_user_systemctl stop clvr-cpu-watchdog.service
run_user_systemctl stop clvr-admin.service
run_user_systemctl stop clvr-watchdog.timer
run_user_systemctl stop clvr-watchdog.service
run_user_systemctl stop clvr.service
run_user_systemctl disable clvr-cpu-watchdog.timer
run_user_systemctl disable clvr-admin.service
run_user_systemctl disable clvr-watchdog.timer
run_user_systemctl disable clvr.service
python3 - <<'PY'
import os
import signal

def ancestors():
    result = {os.getpid(), os.getppid()}
    pid = os.getppid()
    while pid and pid != 1:
        try:
            with open(f"/proc/{pid}/stat", "r", encoding="utf-8", errors="ignore") as handle:
                ppid = int(handle.read().split()[3])
        except Exception:
            break
        result.add(ppid)
        pid = ppid
    return result

skip = ancestors()
for name in os.listdir("/proc"):
    if not name.isdigit():
        continue
    pid = int(name)
    if pid in skip:
        continue
    try:
        raw = open(f"/proc/{pid}/cmdline", "rb").read().replace(b"\x00", b" ").decode("utf-8", "ignore")
    except Exception:
        continue
    if "/opt/A7Admin/" not in raw:
        continue
    if "CLVR" not in raw:
        continue
    if "admin" not in raw.lower() and "appimage" not in raw.lower():
        continue
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
PY
cleanup_old_units
run_user_systemctl daemon-reload
run_user_systemctl reset-failed

echo "==> 2/6 Подготовка конфигурации и логов"
install -d -o "$INSTALL_USER" -g "$INSTALL_USER" -m 0750 /var/log/clvr
install -o "$INSTALL_USER" -g "$INSTALL_USER" -m 0640 /dev/null /var/log/clvr/clvr-start.log
install -o "$INSTALL_USER" -g "$INSTALL_USER" -m 0640 /dev/null /var/log/clvr/clvr-watchdog.log

install -d -o "$INSTALL_USER" -g "$INSTALL_USER" -m 0700 "$USER_HOME/.config/clvr-admin"
cat > "$USER_HOME/.config/clvr-admin/clvr-admin.env" <<EOF
CLVR_LOGIN=${CLVR_LOGIN}
CLVR_PASSWORD=${CLVR_PASSWORD}
CLVR_IP=${CLVR_IP}
CLVR_PORT=${CLVR_PORT}
CLVR_SPACE=${CLVR_SPACE}
CLVR_CPU_LIMIT=${CPU_LIMIT}
CLVR_CPU_TIME=${CPU_TIME}
CLVR_WINDOW_CHECK=1
CLVR_WINDOW_TIME=60
CLVR_WINDOW_PATTERN=CLVR|Clever|Building|Admin|Дисп|Клевер
CLVR_PROC=/opt/A7Admin/CLVR/usr/bin/CLVR-admin
CLVR_WATCHDOG_LOG=/var/log/clvr/clvr-watchdog.log
EOF
chown "$INSTALL_USER:$INSTALL_USER" "$USER_HOME/.config/clvr-admin/clvr-admin.env"
chmod 0600 "$USER_HOME/.config/clvr-admin/clvr-admin.env"

install -m 0755 "$SCRIPT_DIR/clvr-cpu-watchdog.sh" /usr/local/bin/clvr-cpu-watchdog.sh

echo "==> 3/6 Установка актуального AppImage"
if [[ -n "$APPIMAGE_PATH" ]]; then
    if [[ ! -f "$APPIMAGE_PATH" ]]; then
        echo "AppImage not found: ${APPIMAGE_PATH}" >&2
        exit 1
    fi
    install -d -m 0755 /opt/A7Admin
    install -m 0755 "$APPIMAGE_PATH" "/opt/A7Admin/$(basename "$APPIMAGE_PATH")"
    tmp_extract="$(mktemp -d)"
    (
        cd "$tmp_extract"
        chmod +x "$APPIMAGE_PATH"
        "$APPIMAGE_PATH" --appimage-extract >/tmp/clvr-appimage-extract.log 2>&1
    )
    if [[ ! -x "$tmp_extract/squashfs-root/usr/bin/CLVR-admin" ]]; then
        cat /tmp/clvr-appimage-extract.log >&2 || true
        rm -rf "$tmp_extract"
        echo "AppImage extracted, but usr/bin/CLVR-admin was not found." >&2
        exit 1
    fi
    rm -rf /opt/A7Admin/CLVR.previous
    if [[ -d /opt/A7Admin/CLVR ]]; then
        mv /opt/A7Admin/CLVR /opt/A7Admin/CLVR.previous
    fi
    mv "$tmp_extract/squashfs-root" /opt/A7Admin/CLVR
    rm -rf "$tmp_extract"
    chown -R root:root /opt/A7Admin/CLVR
    chmod +x /opt/A7Admin/CLVR/usr/bin/CLVR-admin
else
    echo "AppImage не передан, оставляю текущий /opt/A7Admin/CLVR"
fi

if [[ ! -x /opt/A7Admin/CLVR/usr/bin/CLVR-admin ]]; then
    echo "WARNING: /opt/A7Admin/CLVR/usr/bin/CLVR-admin not found or not executable." >&2
fi

echo "==> 4/6 Установка демона CLVR Admin"
install -d -m 0755 /etc/systemd/user
cat > /etc/systemd/user/clvr-admin.service <<'EOF'
[Unit]
Description=CLVR Admin dispatch client
After=graphical-session.target
Wants=graphical-session.target
StartLimitIntervalSec=60
StartLimitBurst=10

[Service]
Type=simple
WorkingDirectory=/opt/A7Admin
EnvironmentFile=%h/.config/clvr-admin/clvr-admin.env

ExecStartPre=-/usr/bin/pkill -9 -f /opt/A7Admin/CLVR/usr/bin/[C]LVR-admin
ExecStartPre=-/usr/bin/pkill -9 -x CLVR-admin
ExecStartPre=/usr/bin/sleep 1
ExecStart=/opt/A7Admin/CLVR/usr/bin/CLVR-admin -l ${CLVR_LOGIN} -p ${CLVR_PASSWORD} --ip ${CLVR_IP} --ipp ${CLVR_PORT} -s ${CLVR_SPACE}

Restart=always
RestartSec=3
TimeoutStartSec=15
TimeoutStopSec=15

KillMode=control-group
KillSignal=SIGTERM
FinalKillSignal=SIGKILL
SendSIGKILL=yes

MemoryHigh=500M
MemoryMax=700M
CPUQuota=80%
TasksMax=50
OOMPolicy=stop

LogRateLimitIntervalSec=10s
LogRateLimitBurst=200
StandardOutput=append:/var/log/clvr/clvr-start.log
StandardError=append:/var/log/clvr/clvr-start.log

[Install]
WantedBy=default.target
EOF

echo "==> 5/6 Установка watchdog"
cat > /etc/systemd/user/clvr-cpu-watchdog.service <<'EOF'
[Unit]
Description=CLVR CPU and duplicate process watchdog

[Service]
Type=oneshot
EnvironmentFile=%h/.config/clvr-admin/clvr-admin.env
ExecStart=/usr/local/bin/clvr-cpu-watchdog.sh
EOF

cat > /etc/systemd/user/clvr-cpu-watchdog.timer <<'EOF'
[Unit]
Description=Run CLVR watchdog every 10 seconds

[Timer]
OnBootSec=20s
OnUnitActiveSec=10s
AccuracySec=2s
Unit=clvr-cpu-watchdog.service

[Install]
WantedBy=timers.target
EOF

echo "==> 6/6 Настройка logrotate и journald"
cat > /etc/logrotate.d/clvr <<EOF
/var/log/clvr/*.log {
    su ${INSTALL_USER} ${INSTALL_USER}
    size 20M
    rotate 5
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    create 0640 ${INSTALL_USER} ${INSTALL_USER}
}
EOF

install -d -m 0755 /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/90-clvr-limits.conf <<'EOF'
[Journal]
SystemMaxUse=500M
RuntimeMaxUse=200M
RateLimitIntervalSec=10s
RateLimitBurst=200
EOF

USER_UID="$(id -u "$INSTALL_USER")"
loginctl enable-linger "$INSTALL_USER" || true
systemctl start "user@${USER_UID}.service" || true
systemctl daemon-reload
systemctl restart systemd-journald

run_user_systemctl daemon-reload
sudo -u "$INSTALL_USER" XDG_RUNTIME_DIR="/run/user/${USER_UID}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${USER_UID}/bus" systemctl --user enable --now clvr-admin.service
sudo -u "$INSTALL_USER" XDG_RUNTIME_DIR="/run/user/${USER_UID}" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${USER_UID}/bus" systemctl --user enable --now clvr-cpu-watchdog.timer

cat <<EOF
Installed for user: ${INSTALL_USER}

Check:
  systemctl --user status clvr-admin.service
  systemctl --user status clvr-cpu-watchdog.timer
  pgrep -fa CLVR-admin
  tail -f /var/log/clvr/clvr-start.log /var/log/clvr/clvr-watchdog.log

Config:
  ${USER_HOME}/.config/clvr-admin/clvr-admin.env
EOF
