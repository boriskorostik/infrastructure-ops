# Graylog Streams and Inputs

Где что настраивать в Graylog и как этим пользоваться.

## Inputs

Inputs принимают данные.

У нас обычно используются:

- Syslog TCP `1514`
- Syslog UDP `1514`
- GELF TCP `12201`
- GELF UDP `12201`

Официальная документация:

- https://go2docs.graylog.org/current/getting_in_log_data/inputs.htm

## Streams

Streams раскладывают сообщения по категориям.

Например:

- `Object armbereg`
- `Object pes4kainhome`
- `Object firewall`
- `A7 SmartBuilding`
- `CLVR Watchdog`
- `Security Auth Fail2ban`

Официальная документация:

- https://go2docs.graylog.org/current/making_sense_of_your_log_data/streams.html

## Где Streams у нас

Streams не лежат простым yaml-файлом.
Они хранятся в базе Graylog/MongoDB.

Воспроизводим мы их через скрипт:

```text
ansible/files/graylog/setup_graylog_streams.sh
```

На сервере:

```text
/home/microt/setup_graylog_streams.sh
```

## Как менять Streams

Запуск:

```bash
ssh mikrot
GRAYLOG_AUTH="admin:PASSWORD" /home/microt/setup_graylog_streams.sh
```

Добавить поток по `source`:

```bash
make_source_stream "Object promenad" "promenad"
```

Добавить поток по слову в сообщении:

```bash
sid=$(ensure_stream "CLVR Watchdog" "CLVR watchdog and systemd watchdog events")
ensure_rule "$sid" message "watchdog" 0 "message contains watchdog"
```

## Как искать

По объекту:

```text
source:promenad
source:sandboxinhome
source:firewall-support
```

По типу события:

```text
"UFW BLOCK"
fail2ban
watchdog
DispatchingPlugin
```

## Recommended naming

Чтобы потом было просто строить streams и dashboards, лучше сразу задавать source как имя объекта:

- `promenad`
- `armbereg`
- `sky`
- `pes4kainhome`
- `firewall`

Тогда stream настраивается очень просто:

- field: `source`
- value: `promenad`
