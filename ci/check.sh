#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== Secret smoke check =="
if rg -n -i \
  'Das\?worD|tmvpubtmicwqoagm|R2fQLP|fassad2209|Lerw|Klerk|BOT_TOKEN=|ansible_password=|AKUVOX_PASSWORD|BEGIN (RSA|OPENSSH|PRIVATE) KEY' \
  "$ROOT" \
  --glob '!**/.git/**' \
  --glob '!automation/scripts/manifests/**' \
  --glob '!ci/check.sh' \
  --glob '!**/*.md'; then
  echo "Potential secret found. Replace it with vault/env/example value before commit." >&2
  exit 1
fi

echo "== YAML syntax check =="
python3 - <<'PY' "$ROOT"
import pathlib
import sys

try:
    import yaml
except Exception as exc:
    print(f"PyYAML is required for YAML checks: {exc}", file=sys.stderr)
    raise SystemExit(1)

root = pathlib.Path(sys.argv[1])
for path in sorted(root.rglob("*")):
    if ".git" in path.parts:
        continue
    if not path.is_file() or path.suffix.lower() not in {".yml", ".yaml"}:
        continue
    with path.open("r", encoding="utf-8", errors="ignore") as fh:
        yaml.safe_load(fh)
    print(path.relative_to(root))
PY

echo "== Python compile check =="
python3 - <<'PY' "$ROOT"
import pathlib
import py_compile
import sys

root = pathlib.Path(sys.argv[1])
skip = {".git", ".venv", "venv", "__pycache__", "node_modules", "dist", "build"}
for path in sorted(root.rglob("*.py")):
    if any(part in skip for part in path.parts):
        continue
    py_compile.compile(str(path), doraise=True)
    print(path.relative_to(root))
PY

echo "== Optional Ansible inventory parse =="
if command -v ansible-inventory >/dev/null 2>&1; then
  (cd "$ROOT/ansible" && ansible-inventory -i inventory.ini --list >/dev/null)
  (cd "$ROOT/ansible" && ansible-inventory -i inventory_arm_clvr.ini --list >/dev/null || true)
  (cd "$ROOT/ansible" && ansible-inventory -i inventory_vpn.ini --list >/dev/null)
else
  echo "ansible-inventory not installed; skipped"
fi

echo "All checks passed."
