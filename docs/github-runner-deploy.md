# GitHub Runner and Deploy

Эта схема нужна, чтобы `GitHub` был источником правды, `GitHub Actions` проверял изменения, а `self-hosted runner` умел делать реальные deploy во внутреннюю сеть.

## Целевая схема

- `GitHub repository` хранит compose, ansible, alert rules, dashboards и docs.
- `GitHub Actions CI` проверяет YAML, Python, inventory и случайные секреты.
- `Self-hosted runner` стоит на машине, у которой есть доступ:
  - к Docker на `mikrot`, если runner установлен прямо там;
  - или к SSH-ключам/Ansible, если runner стоит на админ-хосте.
- `Ansible` настраивает хосты и форвардеры.
- `Docker Compose` управляет Graylog, Grafana, Prometheus, MKTXP и другими контейнерами.

## Где лучше ставить runner

Есть два нормальных варианта.

### Вариант 1: runner на `mikrot`

Подходит, если:

- именно на `mikrot` крутятся compose-стеки;
- ты хочешь простой deploy без прыжков через SSH;
- runner нужен только для этой инфраструктуры.

Плюсы:

- самый простой runtime;
- `docker compose up -d` работает локально;
- меньше промежуточных секретов.

Минусы:

- runner живёт на production-хосте;
- нужно аккуратно ограничить, кто может запускать deploy workflow.

### Вариант 2: runner на отдельной админ-машине

Подходит, если:

- ты хочешь не держать runner на production;
- часть deploy идёт через SSH/Ansible;
- нужно централизованно управлять несколькими хостами.

Плюсы:

- production-машины чище;
- легче отделить доступы.

Минусы:

- надо разрулить SSH-ключи, known_hosts, Ansible и сеть до целевых хостов.

## Какой вариант лучше для тебя

Сейчас разумнее ставить runner на отдельную админ-машину или на тот сервер, где у тебя уже есть рабочие SSH-ключи и Ansible.  
Если нужен самый быстрый старт, runner на `mikrot` тоже нормален, но тогда доступ к workflow надо ограничить.

## Что уже есть в репозитории

- CI:
  - `.github/workflows/ci.yml`
- Ручной deploy workflow:
  - `.github/workflows/deploy-infra.yml`
- Ansible smoke workflow:
  - `.github/workflows/ansible-smoke.yml`
- Ansible operations workflow:
  - `.github/workflows/ansible-ops.yml`
- Deploy helper:
  - `automation/deploy/deploy_infra.sh`
  - `automation/deploy/run_ansible_playbook.sh`
- Runner host prep helper:
  - `automation/runner/prepare_runner_host.sh`

Поддерживаемые deploy-цели сейчас:

- `graylog`
- `mikrotik-monitoring`
- `loki`
- `graylog-rsyslog-arm`
- `vpn-maintenance`

## Как работает deploy workflow

`Deploy Infra` запускается вручную через `workflow_dispatch`.

Режимы:

- `dry-run` - проверить compose/ansible без реального применения;
- `apply` - применить изменения.

## Как поставить self-hosted runner

Официальная документация GitHub:

- https://docs.github.com/en/actions/hosting-your-own-runners
- https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_dispatch

Порядок:

1. Открыть репозиторий на GitHub.
2. `Settings -> Actions -> Runners -> New self-hosted runner`
3. Выбрать Linux x64.
4. Выполнить команды установки на нужной машине.

После установки полезно зарегистрировать runner с понятными labels, например:

- `self-hosted`
- `linux`
- `x64`
- `mikrot`
- `infra`

Если захочешь жёстче маршрутизировать workflow, можно заменить:

```yaml
runs-on: [self-hosted, linux, infra]
```

## Что должно быть на runner-хосте

Минимум:

- `git`
- `bash`
- `python3`
- `docker` и plugin `docker compose` для compose-стеков
- `ansible` для ansible deploy
- SSH-ключи и `known_hosts`, если runner ходит по SSH

Проверка:

```bash
git --version
python3 --version
docker compose version
ansible-playbook --version
```

Быстрая подготовка Debian/Ubuntu runner-хоста:

```bash
sudo bash automation/runner/prepare_runner_host.sh
```

## Как запускать deploy

Примеры из GitHub UI:

- `stack = mikrotik-monitoring`, `mode = dry-run`
- `stack = mikrotik-monitoring`, `mode = apply`
- `stack = graylog-rsyslog-arm`, `mode = apply`
- `stack = vpn-maintenance`, `mode = dry-run`

## Как запускать Ansible кнопкой

Workflow `Ansible Ops` нужен для случаев, когда хочется не деплоить весь стек, а выполнить конкретный playbook через runner.

Примеры:

- inventory `inventory_vpn.ini`
- playbook `playbooks/linux_maintenance.yml`
- mode `dry-run`
- tags `services`

или:

- inventory `inventory_vpn.ini`
- playbook `playbooks/linux_maintenance.yml`
- mode `apply`
- tags `service`
- extra_args `-e maintenance_restart_service=true -e maintenance_service_name=openvpn`

Для ARM/Graylog:

- inventory `inventory_arm_clvr.ini`
- playbook `playbooks/graylog_rsyslog.yml`
- mode `apply`
- limit `armbereg`

## Что куда деплоится

### Docker Compose

- `graylog` -> `monitoring/graylog/docker-compose.yml`
- `mikrotik-monitoring` -> `monitoring/mikrotik/docker-compose.yml`
- `loki` -> `monitoring/loki/docker-compose.yml`

### Ansible

- `graylog-rsyslog-arm` -> `ansible/playbooks/graylog_rsyslog.yml`
- `vpn-maintenance` -> `ansible/playbooks/linux_maintenance.yml`

## Безопасность

- не хранить реальные пароли в inventory и compose;
- использовать `ansible-vault`;
- для compose использовать `.env` вне git;
- deploy workflow запускать вручную, а не на каждый push;
- для production workflow включить GitHub Environment с approve rules.

## Следующий шаг

Когда эта схема станет тесной, тогда уже имеет смысл переносить runtime в `K3s + Helm + Argo CD`. До этого момента `GitHub + Actions + runner + Ansible + Compose` будет намного проще в поддержке.
