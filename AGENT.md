# AGENT.md

## Scope
Work only inside `/home/boris/infrastructure-ops` unless the user explicitly asks to leave it.

## Goals
- Keep this repo as the clean GitHub-ready infrastructure workspace.
- Prefer small, targeted edits.
- Avoid rescanning `/home/boris` when the task is clearly inside this repo.

## Layout
- `ansible/` - inventories, playbooks, roles, deploy files
- `monitoring/` - Prometheus, Grafana, Graylog, Loki configs
- `automation/` - safe utility scripts and manifests
- `docs/` - operator instructions
- `ci/` - validation scripts and CI helpers

## Working Rules
- Read only the files needed for the current task.
- Prefer concise summaries instead of long repo walkthroughs.
- Do not commit secrets, real passwords, vault files, or private keys.
- Prefer example files and placeholders such as `CHANGE_ME`.

## Validation
- Run `bash ci/check.sh` after meaningful changes.
- Keep YAML parseable and Python files compilable.

## Git Workflow
- Prefer feature branches over direct work on `main`.
- Keep commits small and descriptive.
- Do not rewrite history unless the user explicitly asks.
