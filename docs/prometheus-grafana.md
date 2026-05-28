# Prometheus и Grafana

## Где лежит

```text
monitoring/mikrotik/docker-compose.yml
monitoring/mikrotik/prometheus.yml
monitoring/mikrotik/generated/
ansible/files/prometheus_current/
```

Текущие правила алертов:

```text
ansible/files/prometheus_current/alert.rules.yml
```

Маршрутизация писем Alertmanager:

```text
ansible/files/prometheus_current/alertmanager.yml
```

## Как менять алерты

Отключить почту, но оставить алерт видимым:

```yaml
labels:
  severity: info
  notify: none
```

Сделать важным:

```yaml
labels:
  severity: critical
```

Сделать обычным предупреждением:

```yaml
labels:
  severity: warning
```

## Частота писем

В `alertmanager.yml`:

```yaml
group_wait: 5m
group_interval: 1h
repeat_interval: 12h
```

## Проверка на сервере

```bash
curl -X POST http://127.0.0.1:9090/-/reload
curl -X POST http://127.0.0.1:9093/-/reload
curl -s http://127.0.0.1:9090/api/v1/alerts | jq
```

## Важно

Реальные SMTP-пароли в git не кладём. В репозитории только шаблоны или placeholder-значения.
