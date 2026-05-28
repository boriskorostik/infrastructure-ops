# Graylog Forwarders

Как подключать серверы и чем отличаются варианты.

## Вариант 1: rsyslog

Лучший вариант для системных логов Linux.

Пример:

```bash
sudo tee /etc/rsyslog.d/60-graylog-forward.conf >/dev/null <<'EOF'
*.* @@84.204.178.210:1514;RSYSLOG_SyslogProtocol23Format
EOF
sudo systemctl restart rsyslog
```

Плюсы:

- штатно
- стабильно
- удобно для `/var/log/syslog`, `auth.log`, `kern.log`

Минусы:

- для файлов приложений часто нужно отдельно настраивать `imfile`

## Вариант 2: Graylog Sidecar + Filebeat

Лучший вариант для приложений и масштабируемой инфраструктуры.

Использовать, когда:

- много серверов
- нужно читать произвольные файлы логов
- хочется централизованно управлять коллекторами

Официальные docs:

- https://go2docs.graylog.org/current/getting_in_log_data/graylog_sidecar.html
- https://go2docs.graylog.org/current/getting_in_log_data/set_up_sidecar_collectors.htm

## Вариант 3: Python tail forwarder

Наш кастомный вариант:

```text
ansible/files/graylog/graylog_tail_forwarder.py
```

Поддерживает:

- `--graylog-host`
- `--graylog-port`
- `--hostname`
- `--pattern`

Пример:

```bash
/usr/local/bin/graylog_tail_forwarder.py \
  --graylog-host 172.16.0.5 \
  --graylog-port 1514 \
  --hostname promenad \
  --pattern /var/log/syslog \
  --pattern /var/log/auth.log \
  --pattern /opt/A7SmartBuilding/Logs/serverlogs/*.txt
```

Значение `--hostname` в Graylog потом удобно использовать как `source`.

## Вариант 4: SSH pull forwarder

Наш вариант для firewall и труднодоступных узлов:

```text
ansible/files/graylog/graylog_ssh_tail_forwarder.py
```

Используется, когда:

- сервер не может сам отправить логи в Graylog
- доступен SSH с промежуточного хоста

## Systemd service

Для системного сервиса лучше использовать `/etc/systemd/system`.

Пример:

```ini
[Unit]
Description=Forward local logs to Graylog
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/graylog_tail_forwarder.py --graylog-host 172.16.0.5 --graylog-port 1514 --hostname promenad --pattern /var/log/auth.log --pattern /var/log/syslog --pattern /var/log/fail2ban.log --pattern /opt/A7SmartBuilding/Logs/serverlogs/*.txt
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Команды:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now graylog-tail-forwarder.service
sudo systemctl status graylog-tail-forwarder.service
journalctl -u graylog-tail-forwarder.service -f
```
