# GitLab Runner and Manual Ops

Если хочешь запускать deploy и Ansible не только из GitHub, но и из своего GitLab, то в GitLab нужен не `self-hosted runner` GitHub, а отдельный `GitLab Runner`.

## Главное различие

- `GitHub Actions` использует `self-hosted runner`
- `GitLab CI` использует `GitLab Runner`

Это два разных агента. Один и тот же Linux-хост может держать оба, но это будут две разные службы.

## Что уже настроено в репозитории

Файл:

- `.gitlab-ci.yml`

Там теперь есть:

- `validate` - базовый CI
- `ansible_smoke` - inventory parse и syntax-check playbook'ов
- `deploy_infra_manual` - ручной deploy известных стеков
- `ansible_ops_manual` - ручной запуск конкретного playbook

## Какой runner лучше для GitLab

Для этой инфраструктуры лучше всего `GitLab Runner` с `shell executor` на админ-хосте или на отдельной машине с доступом к:

- `docker compose`
- `ansible`
- SSH-ключам
- внутренней сети

Почему `shell executor`:

- проще всего запускать `docker compose` и `ansible-playbook`
- не нужно отдельно прокидывать docker socket в контейнер runner'а
- проще работать с локальными SSH-ключами и known_hosts

## Как поставить GitLab Runner

Официальные документы:

- Install GitLab Runner: https://docs.gitlab.com/runner/install/
- Linux repository install: https://docs.gitlab.com/runner/install/linux-repository/
- GitLab Runner commands: https://docs.gitlab.com/runner/commands/
- Manual jobs: https://docs.gitlab.com/ci/jobs/job_control/

На Debian/Ubuntu runner-хосте сначала можно поставить общие зависимости:

```bash
sudo bash automation/runner/prepare_runner_host.sh
```

Потом установить GitLab Runner по официальному репозиторию GitLab.

## Как зарегистрировать runner

В GitLab:

1. Открыть проект `department/boris`
2. `Settings -> CI/CD -> Runners`
3. Нажать создание нового runner
4. Выбрать Linux
5. Дать ему tag:

```text
infra
```

6. На хосте выполнить команды регистрации, которые покажет GitLab

Для этого проекта тебе нужен runner, который умеет исполнять jobs с тегом:

```text
infra
```

## Где этим управлять в GitLab

Есть 2 основных сценария.

### 1. Просто прогнать pipeline

Раздел:

```text
Build -> Pipelines
```

Там можно:

- открыть pipeline из push
- посмотреть `validate`
- посмотреть `ansible_smoke`

### 2. Запустить ручные операции

Тоже в:

```text
Build -> Pipelines
```

Дальше:

1. Нажать `Run pipeline`
2. Выбрать ветку, обычно `main`
3. При желании задать variables
4. Запустить pipeline
5. В pipeline нажать кнопку manual job:
   - `deploy_infra_manual`
   - `ansible_ops_manual`

Это и есть ответ на вопрос "откуда это делать в GitLab":  
из `Build -> Pipelines`, через `Run pipeline`, а потом запускать manual jobs.

## Какие переменные использовать в GitLab

### Для deploy_infra_manual

- `DEPLOY_STACK`
- `DEPLOY_MODE`

Примеры:

```text
DEPLOY_STACK=mikrotik-monitoring
DEPLOY_MODE=dry-run
```

или:

```text
DEPLOY_STACK=graylog
DEPLOY_MODE=apply
```

Поддерживаемые stack:

- `graylog`
- `mikrotik-monitoring`
- `loki`
- `graylog-rsyslog-arm`
- `vpn-maintenance`

### Для ansible_ops_manual

- `ANSIBLE_INVENTORY`
- `ANSIBLE_PLAYBOOK`
- `ANSIBLE_MODE`
- `ANSIBLE_LIMIT`
- `ANSIBLE_TAGS`
- `ANSIBLE_EXTRA_ARGS`

Пример: посмотреть VPN сервисы

```text
ANSIBLE_INVENTORY=inventory_vpn.ini
ANSIBLE_PLAYBOOK=playbooks/linux_maintenance.yml
ANSIBLE_MODE=dry-run
ANSIBLE_TAGS=services
```

Пример: перезапустить WireGuard на `vpn1`

```text
ANSIBLE_INVENTORY=inventory_vpn.ini
ANSIBLE_PLAYBOOK=playbooks/linux_maintenance.yml
ANSIBLE_MODE=apply
ANSIBLE_LIMIT=vpn1
ANSIBLE_TAGS=service
ANSIBLE_EXTRA_ARGS=-e maintenance_restart_service=true -e maintenance_service_name=wg-quick@wg0
```

## Что лучше использовать: GitHub или GitLab

Для тебя рабочая схема может быть такой:

- `GitHub` - удобно для Actions, внешнего кода и привычного git workflow
- `GitLab` - удобно как внутренняя панель управления и ручной CI/CD

Если хочешь меньше дублирования, выбери одну основную control plane:

- либо `GitHub Actions`
- либо `GitLab Pipelines`

Но держать обе опции тоже нормально, если:

- CI в обеих системах остаётся простым
- deploy-скрипты общие
- логика не размазывается по двум разным местам

У тебя сейчас как раз так и сделано: обе платформы используют одни и те же локальные скрипты из репозитория.
