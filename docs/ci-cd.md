# CI/CD

В репозитории настроен GitLab CI:

```text
.gitlab-ci.yml
ci/check.sh
```

CI делает:

- быстрый поиск случайно закоммиченных секретов;
- проверку YAML;
- компиляцию Python-файлов;
- базовую проверку Ansible inventory, если установлен Ansible.

Локально:

```bash
bash ci/check.sh
```

Работа с ветками:

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
3. В GitLab создаётся merge request.
4. После зелёного pipeline ветка вливается в `main`.

Для деплоя на сервер пока оставляем ручной запуск Ansible/playbooks. Автодеплой лучше включать отдельным этапом, когда будут заведены GitLab CI variables для SSH-ключей и vault-пароля.
