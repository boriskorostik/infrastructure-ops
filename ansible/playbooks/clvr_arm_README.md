# CLVR Admin ARM deploy через Ansible

Файлы:

- `inventory_arm_clvr.ini` - ARM-хосты.
- `playbooks/clvr_arm_deploy.yml` - копирует установщик, читает `CLVRAdmin.conf`, ставит демон и watchdog.
- `files/clvr-admin-deploy/` - установочный комплект.
- `files/clvr-admin-image/2.4.22_CleverBuilding.AppImage` - актуальный образ CleverBuilding/CLVR Admin.

## Запуск на одном ARM

```bash
cd /home/boris/mikrotik_ansible
ansible-playbook -i inventory_arm_clvr.ini playbooks/clvr_arm_deploy.yml --limit armbereg
```

## Запуск на всех

```bash
cd /home/boris/mikrotik_ansible
ansible-playbook -i inventory_arm_clvr.ini playbooks/clvr_arm_deploy.yml
```

## Как выбираются настройки подключения

Playbook сначала копирует актуальный AppImage на ARM, распаковывает его в:

```text
/opt/A7Admin/CLVR
```

Потом ищет настройки:

```text
$HOME/.config/A7Systems/CLVRAdmin.conf
/home/*/.config/A7Systems/CLVRAdmin.conf
```

Выбирает самый заполненный `set_*`, но из конфига берёт только:

- `SB\tcp\ip`
- `SB\tcp\port`

Логин, пароль и Space постоянные:

```text
login: dispetcher
password: D876?ZG!
space: Space79
```

Если IP/порт не найдены, используются дефолты:

```text
192.168.48.20:29107
```

## Принудительно задать IP/порт

```bash
ansible-playbook -i inventory_arm_clvr.ini playbooks/clvr_arm_deploy.yml \
  --limit armbereg \
  -e clvr_server_ip=192.168.48.20 \
  -e clvr_server_port=29107
```

## Обновить AppImage

Положи новый файл сюда:

```text
/home/boris/mikrotik_ansible/files/clvr-admin-image/
```

И поменяй переменную `clvr_appimage_src` в `playbooks/clvr_arm_deploy.yml`, если имя файла изменилось.

## Важно про пароли

Сейчас SSH-пароли записаны в `inventory_arm_clvr.ini` обычным текстом, как ты прислал. Лучше потом зашифровать файл:

```bash
ansible-vault encrypt inventory_arm_clvr.ini
```

Для подключения по паролю может понадобиться:

```bash
sudo apt install sshpass
```
