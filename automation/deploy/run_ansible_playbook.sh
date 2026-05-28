#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANSIBLE_DIR="$ROOT/ansible"

INVENTORY="${1:-}"
PLAYBOOK="${2:-}"
MODE="${3:-dry-run}"
LIMIT="${4:-}"
TAGS="${5:-}"
EXTRA_ARGS="${6:-}"

if [[ -z "$INVENTORY" || -z "$PLAYBOOK" ]]; then
  echo "Usage: $0 <inventory> <playbook> [dry-run|apply] [limit] [tags] [extra_args]" >&2
  exit 1
fi

if [[ ! -f "$ANSIBLE_DIR/$INVENTORY" ]]; then
  echo "Inventory not found: $ANSIBLE_DIR/$INVENTORY" >&2
  exit 1
fi

if [[ ! -f "$ANSIBLE_DIR/$PLAYBOOK" ]]; then
  echo "Playbook not found: $ANSIBLE_DIR/$PLAYBOOK" >&2
  exit 1
fi

cmd=(ansible-playbook -i "$INVENTORY" "$PLAYBOOK")

if [[ -n "$LIMIT" ]]; then
  cmd+=(--limit "$LIMIT")
fi

if [[ -n "$TAGS" ]]; then
  cmd+=(--tags "$TAGS")
fi

if [[ "$MODE" == "dry-run" ]]; then
  cmd+=(--check)
fi

if [[ -n "$EXTRA_ARGS" ]]; then
  # Intentionally split shell-style extra args to keep manual workflow flexible.
  # shellcheck disable=SC2206
  extra=( $EXTRA_ARGS )
  cmd+=("${extra[@]}")
fi

pushd "$ANSIBLE_DIR" >/dev/null
echo "+ ansible-playbook -i $INVENTORY $PLAYBOOK"
ansible-inventory -i "$INVENTORY" --list >/dev/null
ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --syntax-check
"${cmd[@]}"
popd >/dev/null
