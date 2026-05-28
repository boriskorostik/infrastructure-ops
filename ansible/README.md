# MikroTik Ansible

Набор плейбуков для управления MikroTik через Ansible по SSH:

- снимать резервную копию текущей конфигурации;
- применять конфиг из `files/config.rsc`;
- проверять и устанавливать обновления RouterOS;
- при необходимости обновлять RouterBOARD firmware после обновления RouterOS.

Рабочий конфиг для применения сейчас привязан к файлу `files/config.rsc`.

## Структура

```text
.
├── ansible.cfg
├── collections/requirements.yml
├── group_vars/mikrotik.yml
├── inventory.ini
├── files/config.rsc
├── playbooks/
│   ├── backup.yml
│   ├── config.yml
│   ├── site.yml
│   └── update.yml
└── roles/
    ├── mikrotik_backup/
    ├── mikrotik_config/
    └── mikrotik_update/
```

## Подготовка

Убедись, что в `inventory.ini` указан правильный IP, логин и SSH-порт MikroTik.

Если нужно подтянуть коллекции:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

## Основные команды

Снять бэкап текущей конфигурации:

```bash
ansible-playbook playbooks/backup.yml
```

Применить `files/config.rsc` на MikroTik:

```bash
ansible-playbook playbooks/config.yml
```

Проверить обновления и показать их состояние:

```bash
ansible-playbook playbooks/site.yml --tags update
```

Установить обновления RouterOS:

```bash
ansible-playbook playbooks/update.yml
```

Запустить общий сценарий: бэкап, опционально конфиг, затем проверка обновлений:

```bash
ansible-playbook playbooks/site.yml
```

Если хочешь в общем сценарии ещё и пушить конфиг:

```bash
ansible-playbook playbooks/site.yml -e mikrotik_apply_config=true
```

Если хочешь в общем сценарии ещё и сразу ставить обновления:

```bash
ansible-playbook playbooks/site.yml -e mikrotik_update_apply=true
```

## Где лежат бэкапы

Все экспортированные конфиги и статусные снапшоты складываются в каталог `backups/<host>/`.

## Автозапуск по cron

Пример ночного запуска проверки и установки обновлений:

```cron
30 3 * * * cd /home/boris/mikrotik_ansible && /usr/bin/ansible-playbook playbooks/site.yml -e mikrotik_update_apply=true >> /var/log/mikrotik-ansible.log 2>&1
```

Пример отдельного применения конфига по требованию:

```bash
cd /home/boris/mikrotik_ansible
ansible-playbook playbooks/config.yml
```

## Важное замечание по `config.rsc`

Файл `files/config.rsc` применяется как RouterOS CLI script. Это удобно для централизованного управления, но такой подход не всегда строго идемпотентен для команд вида `add`. Для автоматического ежедневного запуска лучше использовать `site.yml` в режиме обновлений, а `config.yml` запускать осознанно после правок конфига.
