# CI/CD

В репозитории настроен `GitHub Actions`.

Файлы:

```text
.github/workflows/ci.yml
.github/workflows/deploy-infra.yml
ci/check.sh
automation/deploy/deploy_infra.sh
```

## Что делает CI

`CI` workflow запускается на `push` и `pull_request` для `main` и `develop`.

Он делает:

- быстрый поиск случайно закоммиченных секретов;
- проверку YAML;
- компиляцию Python-файлов;
- базовую проверку Ansible inventory.

Локально:

```bash
bash ci/check.sh
```

## Работа с ветками

```bash
git checkout -b feature/change-alerts
bash ci/check.sh
git add .
git commit -m "Update monitoring alerts"
git push -u origin feature/change-alerts
```

Рекомендуемый порядок:

1. Любая новая настройка делается в отдельной ветке.
2. Перед push запускается `bash ci/check.sh`.
3. На GitHub создаётся pull request.
4. После зелёного pipeline ветка вливается в `main`.

## Deploy

Для деплоя добавлен отдельный workflow `Deploy Infra`.

Он:

- запускается вручную через `workflow_dispatch`;
- рассчитан на `self-hosted runner`;
- умеет делать `dry-run` и `apply`.

Поддерживаемые цели сейчас:

- `graylog`
- `mikrotik-monitoring`
- `loki`
- `graylog-rsyslog-arm`

Подробно:

- [GitHub Runner and Deploy](github-runner-deploy.md)

## Почему так

Это хороший промежуточный этап между ручным администрированием и полноценным `K3s + Helm + Argo CD`.

Сейчас схема такая:

- `GitHub` - source of truth
- `GitHub Actions` - CI
- `self-hosted runner` - deploy
- `Ansible + Docker Compose` - runtime управление инфраструктурой
