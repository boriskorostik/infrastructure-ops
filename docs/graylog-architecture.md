# Graylog Architecture

Практическая схема для нашей инфраструктуры.

## Компоненты

- Graylog server
- MongoDB
- OpenSearch
- Inputs в Graylog
- Forwarders на серверах
- Streams для маршрутизации логов
- Events/Alerts для уведомлений

## Как это устроено у нас

Graylog-сервер работает на `mikrot`.

Основные файлы:

```text
/home/microt/graylog-docker/docker-compose.yml
/home/microt/setup_graylog_streams.sh
/home/microt/graylog_tail_forwarder.py
/home/microt/graylog_ssh_tail_forwarder.py
```

Локальные исходники и шаблоны в репозитории:

```text
monitoring/graylog/
ansible/files/graylog/
```

## Поток данных

1. Сервер или ARM отправляет лог в Graylog.
2. Graylog принимает сообщение через `Syslog` или `GELF` input.
3. Graylog определяет `source`, `message`, `app`, timestamp и другие поля.
4. Streams раскладывают сообщения по объектам и типам.
5. Search/Dashboard/Event уже работают поверх этих потоков.

## Что лучше использовать

Для системных логов:

- `rsyslog`

Для логов приложений:

- `Graylog Sidecar + Filebeat`

Для временной или нестандартной схемы:

- кастомный Python tail forwarder

Для закрытых узлов без прямой отправки:

- pull по SSH с промежуточного сервера

## Почему не всё делать через Python

Python forwarder удобен, когда:

- нет sudo/root для `rsyslog imfile`
- нужно быстро читать набор файлов
- нужно обойти сетевые ограничения

Но для постоянной инфраструктуры лучше:

- `rsyslog` для syslog
- `Sidecar + Filebeat` для файлов приложений

## Рекомендуемая целевая схема

- Linux system logs -> `rsyslog` -> Graylog
- Application logs -> `Filebeat/Sidecar` -> Graylog
- Firewall or isolated node -> SSH pull bridge -> Graylog
- Graylog Streams -> object streams + service streams
- Graylog Events -> alerting
