# Graylog

## Где лежит

```text
monitoring/graylog/docker-compose.yml
monitoring/graylog/generated/docker-compose.yml
ansible/files/graylog/
```

Скрипты:

```text
ansible/files/graylog/graylog_tail_forwarder.py
ansible/files/graylog/graylog_ssh_tail_forwarder.py
ansible/files/graylog/setup_graylog_streams.sh
```

## Что править

Потоки Graylog:

```bash
ansible/files/graylog/setup_graylog_streams.sh
```

Добавить объект:

```bash
make_source_stream "Object new-server" "source-name-in-graylog"
```

Сбор файлов локальным user-service:

```text
graylog_tail_forwarder.py
```

Сбор логов с закрытого сервера через SSH:

```text
graylog_ssh_tail_forwarder.py
```

## Порты

```text
9000/tcp   Web UI
1514/tcp   Syslog TCP
1514/udp   Syslog UDP
12201/tcp  GELF TCP
12201/udp  GELF UDP
```

## Проверка

```bash
logger -t graylog-test "hello from $(hostname)"
```

В Graylog искать:

```text
graylog-test
source:firewall-support
source:microt
source:sandboxinhome
"UFW BLOCK"
fail2ban
```
