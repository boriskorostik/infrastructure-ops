# Infrastructure Ops

Единый рабочий каталог для Ansible, Docker, мониторинга, Graylog, Prometheus/Grafana и безопасно отобранных вспомогательных скриптов.

Старые рабочие директории не переносились и не ломались. Здесь лежат копии, шаблоны и документация для работы через git.

## Структура

```text
ansible/                     # playbooks, inventory, roles, deploy-файлы
monitoring/mikrotik/         # Prometheus/Grafana/MKTXP конфиги и dashboards
monitoring/graylog/          # Docker compose Graylog
monitoring/loki/             # Grafana Loki/Promtail черновики
automation/scripts/safe/     # выбранные скрипты без найденных секретов
automation/scripts/manifests # индекс старых скриптов в /home/boris/script
docs/                        # инструкции
ci/                          # локальные проверки
tests/                       # место под автотесты
```

## Быстрый старт

```bash
cd /home/boris/infrastructure-ops
bash ci/check.sh
```

## Git workflow

```bash
git checkout -b feature/my-change
# правки
bash ci/check.sh
git add .
git commit -m "Describe change"
git push -u origin feature/my-change
```

В `main` лучше вливать через merge request, чтобы CI проверял YAML, Python и случайные секреты.

## Секреты

Реальные пароли не коммитим. Используем:

- Ansible Vault: `ansible/group_vars/*.vault.yml`
- `.env` файлы рядом с compose, но сами `.env` в git не добавляем
- шаблоны `*.example.yml`, `.env.example`

Пример:

```bash
cp ansible/group_vars/arm_clvr.vault.example.yml ansible/group_vars/arm_clvr.vault.yml
ansible-vault encrypt ansible/group_vars/arm_clvr.vault.yml
```

## Основные инструкции

- [Graylog](docs/graylog.md)
- [Graylog Architecture](docs/graylog-architecture.md)
- [Graylog Forwarders](docs/graylog-forwarders.md)
- [Graylog Streams and Inputs](docs/graylog-streams-inputs.md)
- [Prometheus и Grafana](docs/prometheus-grafana.md)
- [Добавление сервера](docs/add-server.md)
- [CI/CD](docs/ci-cd.md)
- [GitHub Runner and Deploy](docs/github-runner-deploy.md)
- [GitLab Runner and Manual Ops](docs/gitlab-runner-deploy.md)
- [Ops Workflow](docs/ops-workflow.md)
- [Что откуда собрано](docs/source-map.md)
