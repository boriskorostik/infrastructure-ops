#!/usr/bin/env bash
set -euo pipefail

SERVICE="${CLVR_SERVICE:-clvr-admin.service}"
PROC="${CLVR_PROC:-/opt/A7Admin/CLVR/usr/bin/CLVR-admin}"
CPU_LIMIT="${CLVR_CPU_LIMIT:-90}"
CPU_TIME="${CLVR_CPU_TIME:-120}"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE="${STATE_DIR}/clvr_cpu_state"
WINDOW_STATE="${STATE_DIR}/clvr_window_state"
LOG="${CLVR_WATCHDOG_LOG:-/var/log/clvr/clvr-watchdog.log}"
WINDOW_CHECK="${CLVR_WINDOW_CHECK:-1}"
WINDOW_TIME="${CLVR_WINDOW_TIME:-60}"
WINDOW_PATTERN="${CLVR_WINDOW_PATTERN:-CLVR|Clever|Building|Admin|Дисп|Клевер}"

log() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"
}

restart_service() {
    local reason="$1"
    log "$reason -> restart"
    systemctl --user stop "$SERVICE" >/dev/null 2>&1 || true
    sleep 2
    pkill -9 -x CLVR-admin >/dev/null 2>&1 || true
    sleep 1
    systemctl --user start "$SERVICE"
    rm -f "$STATE"
    rm -f "$WINDOW_STATE"
}

main_pid="$(systemctl --user show "$SERVICE" -p MainPID --value 2>/dev/null || true)"

if [[ -z "$main_pid" || "$main_pid" == "0" ]]; then
    rm -f "$STATE"
    rm -f "$WINDOW_STATE"
    exit 0
fi

cpu="$(ps -p "$main_pid" -o %cpu= 2>/dev/null | awk '{print int($1)}')"
cpu="${cpu:-0}"
now="$(date +%s)"

if (( cpu >= CPU_LIMIT )); then
    if [[ -f "$STATE" ]]; then
        start="$(cat "$STATE" 2>/dev/null || echo "$now")"
        diff=$((now - start))
        if (( diff >= CPU_TIME )); then
            restart_service "CPU ${cpu}% for ${diff} sec"
            exit 0
        fi
    else
        echo "$now" > "$STATE"
    fi
else
    rm -f "$STATE"
fi

count="$(pgrep -x CLVR-admin | wc -l | awk '{print $1}')"
if (( count > 1 )); then
    restart_service "DUPLICATES detected (${count})"
fi

if [[ "$WINDOW_CHECK" == "1" ]] && command -v xwininfo >/dev/null 2>&1; then
    proc_env="$(tr '\0' '\n' < "/proc/${main_pid}/environ" 2>/dev/null || true)"
    proc_display="$(printf '%s\n' "$proc_env" | awk -F= '$1=="DISPLAY"{print $2; exit}')"
    proc_xauthority="$(printf '%s\n' "$proc_env" | awk -F= '$1=="XAUTHORITY"{print $2; exit}')"
    if [[ -n "$proc_display" ]]; then
        export DISPLAY="$proc_display"
        if [[ -n "$proc_xauthority" ]]; then
            export XAUTHORITY="$proc_xauthority"
        fi
        if xwininfo -root -tree 2>/dev/null | grep -Eiq "$WINDOW_PATTERN"; then
            rm -f "$WINDOW_STATE"
        else
            if [[ -f "$WINDOW_STATE" ]]; then
                start="$(cat "$WINDOW_STATE" 2>/dev/null || echo "$now")"
                diff=$((now - start))
                if (( diff >= WINDOW_TIME )); then
                    restart_service "No visible CLVR window for ${diff} sec"
                    exit 0
                fi
            else
                echo "$now" > "$WINDOW_STATE"
            fi
        fi
    fi
fi
