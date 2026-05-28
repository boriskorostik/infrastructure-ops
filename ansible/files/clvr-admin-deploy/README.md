# CLVR Admin deploy для Ubuntu

Комплект ставит CLVR Admin как пользовательский `systemd`-сервис, включает watchdog от зависаний и дублей процессов, а также ограничивает рост логов.

## Быстрая установка

```bash
cd "/home/boris/длЯ диспы/clvr-admin-deploy"
sudo ./install.sh
```

Установщик интерактивно спросит:

- логин;
- IP сервера диспетчеризации;
- порт подключения;
- Space / базу;
- пароль.

По умолчанию он предложит:

```text
IP сервера диспетчеризации: 192.168.48.20
Порт подключения: 29107
Space / база: Space79
```

Можно передать параметры сразу, если нужно без вопросов:

```bash
sudo ./install.sh --login dispetcher --password 'PASSWORD' --ip 192.168.48.20 --port 29107 --space Space79
```

## Порядок установки

`install.sh` делает всё одним проходом:

1. Останавливает старый демон/watchdog и убирает старые unit-файлы.
2. Создаёт конфиг подключения и папку логов.
3. Ставит `clvr-admin.service` как демон.
4. Ставит watchdog `clvr-cpu-watchdog.timer`.
5. Включает ротацию логов и лимиты journald.

## Что ставится

- `/etc/systemd/user/clvr-admin.service` - основной демон CLVR Admin.
- `/etc/systemd/user/clvr-cpu-watchdog.service` - разовая проверка watchdog.
- `/etc/systemd/user/clvr-cpu-watchdog.timer` - запуск watchdog каждые 10 секунд.
- `/usr/local/bin/clvr-cpu-watchdog.sh` - логика watchdog.
- `~/.config/clvr-admin/clvr-admin.env` - настройки подключения и пороги watchdog.
- `/etc/logrotate.d/clvr` - ротация логов по 20 МБ, 5 архивов.
- `/etc/systemd/journald.conf.d/90-clvr-limits.conf` - лимиты journald.

## Проверка

```bash
systemctl --user status clvr-admin.service
systemctl --user status clvr-cpu-watchdog.timer
pgrep -fa CLVR-admin
tail -f /var/log/clvr/clvr-start.log /var/log/clvr/clvr-watchdog.log
```

Должен быть один процесс `CLVR-admin`.

## Watchdog

По умолчанию watchdog перезапускает сервис, если основной процесс держит CPU выше `90%` дольше `120` секунд.

Пороги меняются в:

```bash
nano ~/.config/clvr-admin/clvr-admin.env
systemctl --user restart clvr-cpu-watchdog.timer
```

## Логи

Логи лежат в:

```text
/var/log/clvr/clvr-start.log
/var/log/clvr/clvr-watchdog.log
```

`logrotate` держит максимум 5 архивов по 20 МБ. `journald` ограничен отдельным drop-in файлом, без ручного редактирования основного `/etc/systemd/journald.conf`.

## Обновить настройки подключения

```bash
nano ~/.config/clvr-admin/clvr-admin.env
systemctl --user restart clvr-admin.service
```

## Удаление

```bash
systemctl --user disable --now clvr-admin.service
systemctl --user disable --now clvr-cpu-watchdog.timer
sudo rm -f /etc/systemd/user/clvr-admin.service
sudo rm -f /etc/systemd/user/clvr-cpu-watchdog.service
sudo rm -f /etc/systemd/user/clvr-cpu-watchdog.timer
sudo rm -f /usr/local/bin/clvr-cpu-watchdog.sh
sudo rm -f /etc/logrotate.d/clvr
sudo rm -f /etc/systemd/journald.conf.d/90-clvr-limits.conf
systemctl --user daemon-reload
```
