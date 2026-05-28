#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

STACK="${1:-}"
MODE="${2:-apply}"

if [[ -z "$STACK" ]]; then
  echo "Usage: $0 <stack> [apply|dry-run]" >&2
  echo "Stacks: graylog, mikrotik-monitoring, loki, graylog-rsyslog-arm" >&2
  exit 1
fi

run() {
  echo "+ $*"
  "$@"
}

compose_deploy() {
  local dir="$1"
  if [[ ! -f "$dir/docker-compose.yml" ]]; then
    echo "Missing docker-compose.yml in $dir" >&2
    exit 1
  fi
  run docker compose -f "$dir/docker-compose.yml" config -q
  if [[ "$MODE" == "dry-run" ]]; then
    run docker compose -f "$dir/docker-compose.yml" config
  else
    run docker compose -f "$dir/docker-compose.yml" pull
    run docker compose -f "$dir/docker-compose.yml" up -d
  fi
}

ansible_deploy() {
  local inventory="$1"
  local playbook="$2"
  pushd "$ROOT/ansible" >/dev/null
  run ansible-playbook -i "$inventory" "$playbook" --syntax-check
  if [[ "$MODE" != "dry-run" ]]; then
    run ansible-playbook -i "$inventory" "$playbook"
  fi
  popd >/dev/null
}

case "$STACK" in
  graylog)
    compose_deploy "$ROOT/monitoring/graylog"
    ;;
  mikrotik-monitoring)
    compose_deploy "$ROOT/monitoring/mikrotik"
    ;;
  loki)
    compose_deploy "$ROOT/monitoring/loki"
    ;;
  graylog-rsyslog-arm)
    ansible_deploy "inventory_arm_clvr.ini" "playbooks/graylog_rsyslog.yml"
    ;;
  *)
    echo "Unknown stack: $STACK" >&2
    exit 1
    ;;
esac
