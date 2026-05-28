# Что откуда собрано

Новый каталог: `/home/boris/infrastructure-ops`.

Исходные рабочие каталоги оставлены на месте:

```text
/home/boris/mikrotik_ansible      -> ansible/
/home/boris/mikrotik-monitoring   -> monitoring/mikrotik/
/home/boris/graylog               -> monitoring/graylog/
/home/boris/grafana-loki          -> monitoring/loki/
/home/boris/script                -> automation/scripts/manifests + safe/
```

Разрозненные legacy-скрипты полностью в git не переносились, потому что в них найдены реальные пароли и токены. Их индекс лежит здесь:

```text
automation/scripts/manifests/home-boris-script-files.txt
```

Безопасно скопированные скрипты:

```text
automation/scripts/safe/iptables_gui.py
automation/scripts/safe/mbus_scaner.py
automation/scripts/safe/ssh2mc.py
automation/scripts/safe/ssh2mc.sh
automation/scripts/safe/traffic_analysis.py
```

Если нужен ещё один старый скрипт, сначала проверь его:

```bash
rg -n -i 'password|token|secret|api[_-]?key|private key' /path/to/script.py
```

Потом копируй в `automation/scripts/safe/` и запускай:

```bash
bash ci/check.sh
```
