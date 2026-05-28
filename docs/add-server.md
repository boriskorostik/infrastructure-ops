# Добавление сервера в сбор логов

## Вариант 1: обычный Linux через rsyslog

На сервере:

```bash
sudo tee /etc/rsyslog.d/60-graylog-forward.conf >/dev/null <<'EOF'
*.* @@84.204.178.210:1514;RSYSLOG_SyslogProtocol23Format
EOF
sudo systemctl restart rsyslog
logger -t graylog-test "hello from $(hostname)"
```

В Graylog искать:

```text
graylog-test
source:<hostname>
```

## Вариант 2: группа серверов через Ansible

Inventory:

```text
ansible/inventory_arm_clvr.ini
```

Playbook:

```text
ansible/playbooks/graylog_rsyslog.yml
```

Запуск:

```bash
cd ansible
ansible-playbook -i inventory_arm_clvr.ini playbooks/graylog_rsyslog.yml -e graylog_host=84.204.178.210
```

## Вариант 3: отдельные файлы приложения

Если нужен tail файлов вроде `/opt/app/logs/*.log`, варианты такие:

- rsyslog `imfile`, если есть root/sudo
- Graylog Sidecar + Filebeat, если нужна нормальная агентская схема
- `graylog_tail_forwarder.py`, если нужно быстро и без root

## Добавить поток в Graylog

Править:

```text
ansible/files/graylog/setup_graylog_streams.sh
```

Пример:

```bash
make_source_stream "Object new-server" "new-server-hostname"
```
