# Ops Workflow

Ниже простой рабочий цикл, чтобы управлять инфраструктурой без хаоса: правки в Git, проверки в CI, ручной deploy через workflow и отдельные inventories под разные группы серверов.

## Базовый цикл

1. Создаёшь ветку:

```bash
git checkout -b feature/change-graylog
```

2. Вносишь правки:

- `ansible/` для серверов и агентов
- `monitoring/` для compose, Prometheus, Grafana, Graylog
- `docs/` для инструкций

3. Гоняешь локальные проверки:

```bash
bash ci/check.sh
```

4. Коммитишь и пушишь:

```bash
git add .
git commit -m "Update Graylog forwarding"
git push -u origin feature/change-graylog
```

5. Открываешь pull request / merge request.

6. После зелёного CI запускаешь ручной deploy workflow.

## Что где менять

### Graylog

- `monitoring/graylog/docker-compose.yml`
- `ansible/files/graylog/setup_graylog_streams.sh`
- `ansible/playbooks/graylog_rsyslog.yml`
- `ansible/playbooks/graylog_filelogs.yml`

### MikroTik monitoring

- `monitoring/mikrotik/docker-compose.yml`
- `monitoring/mikrotik/prometheus.yml`
- `monitoring/mikrotik/mikrotik-dashboard.json`
- `ansible/files/prometheus_current/alert.rules.yml`
- `ansible/files/prometheus_current/alertmanager.yml`

### Linux servers and VPN

- `ansible/inventory_vpn.ini`
- `ansible/playbooks/linux_maintenance.yml`

## Как управлять VPN-сервером

Из `~/.ssh/config` в репозиторий уже перенесены 2 хоста:

- `vpn1`
- `openvpn`

Файл:

- `ansible/inventory_vpn.ini`

Проверка доступности:

```bash
cd ansible
ansible -i inventory_vpn.ini vpn -m ping
```

Показать systemd-сервисы и сводку:

```bash
ansible-playbook -i inventory_vpn.ini playbooks/linux_maintenance.yml
```

Посмотреть VPN-related сервисы:

```bash
ansible-playbook -i inventory_vpn.ini playbooks/linux_maintenance.yml --tags services
```

Обновить apt cache:

```bash
ansible-playbook -i inventory_vpn.ini playbooks/linux_maintenance.yml -e maintenance_update_cache=true --tags updates
```

Безопасно обновить пакеты:

```bash
ansible-playbook -i inventory_vpn.ini playbooks/linux_maintenance.yml \
  -e maintenance_update_cache=true \
  -e maintenance_upgrade_packages=true \
  --tags updates
```

Перезапустить VPN-сервис:

```bash
ansible-playbook -i inventory_vpn.ini playbooks/linux_maintenance.yml \
  -e maintenance_restart_service=true \
  -e maintenance_service_name=openvpn \
  --tags service
```

Если у тебя там WireGuard, то вместо `openvpn` обычно будет что-то вроде:

```bash
maintenance_service_name=wg-quick@wg0
```

## Как добавить новый сервер из SSH config

1. Найти alias в `~/.ssh/config`
2. Добавить его в подходящий inventory:
   - `inventory.ini`
   - `inventory_arm_clvr.ini`
   - `inventory_vpn.ini`
3. Проверить:

```bash
ansible -i inventory_vpn.ini all -m ping
```

4. Если это лог-сервер или ARM, применить нужный playbook.

## Как устроен deploy

В GitHub Actions уже есть:

- `CI`
- `Deploy Infra`
- `Ansible Smoke`
- `Ansible Ops`

Ручной deploy идёт через:

```text
.github/workflows/deploy-infra.yml
automation/deploy/deploy_infra.sh
```

Поддерживаемые стеки:

- `graylog`
- `mikrotik-monitoring`
- `loki`
- `graylog-rsyslog-arm`
- `vpn-maintenance`

## Когда какой workflow использовать

### CI

Обычная проверка репозитория:

- YAML
- Python
- inventory parse
- базовые smoke-checks

### Ansible Smoke

Используй, когда меняешь:

- inventory
- playbooks
- роли
- ansible-конфиг

Он отдельно проверяет:

- `ansible-inventory --list`
- `ansible-playbook --syntax-check`

### Deploy Infra

Используй для известных стеков:

- Graylog
- monitoring
- Loki
- ARM rsyslog
- VPN maintenance

### Ansible Ops

Используй, когда нужно кнопкой из GitHub выполнить конкретный playbook с `limit`, `tags` и `extra vars`.

Это самый удобный путь для таких задач:

- перезапустить VPN-сервис
- проверить сервисы на одном хосте
- обновить отдельную группу серверов
- прогнать Linux maintenance не на всех, а на одном узле

## Что ещё стоит прикрутить дальше

1. Отдельный workflow для Ansible smoke:
   - syntax check
   - `ansible-inventory --list`
   - `ansible-playbook --syntax-check`

2. Отдельный workflow для dashboards:
   - JSON validation
   - optional Grafana dashboard lint

3. Отдельный deploy target для VPN:
   - `vpn-maintenance`

4. Vault для sudo/password переменных, если захочешь массово управлять Linux-хостами через пароль.
