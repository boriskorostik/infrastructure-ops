# Poker Chips

Локальный сайт для учета фишек во время покера.

Игрок выбирает себя из списка и вводит количество фишек. Кнопка `Мои фишки в 0` сбрасывает только счет выбранного игрока.

## Запуск

```bash
cd /home/boris/mikrotik_ansible/files/poker-chips
python3 server.py
```

Откройте на этом компьютере:

```text
http://localhost:8080
```

Если `8080` уже занят, сервер автоматически возьмет следующий свободный порт и напишет его в терминале.

Другие игроки в той же сети могут открыть:

```text
http://IP_ЭТОГО_КОМПЬЮТЕРА:8080
```

Например, если IP компьютера `172.16.0.205`, адрес будет:

```text
http://172.16.0.205:8080
```

Данные сохраняются в `data/chips.json`.

## Docker

Собрать образ:

```bash
docker build -t poker-chips:latest .
```

Запустить контейнер:

```bash
docker run -d \
  --name poker-chips \
  -p 8080:8080 \
  -v poker-chips-data:/app/data \
  --restart unless-stopped \
  poker-chips:latest
```

Открыть:

```text
http://IP_СЕРВЕРА:8080
```

Данные внутри Docker сохраняются в volume `poker-chips-data`.

Перенести образ на другой компьютер:

```bash
docker save poker-chips:latest -o poker-chips.tar
```

На другом компьютере:

```bash
docker load -i poker-chips.tar
docker run -d --name poker-chips -p 8080:8080 -v poker-chips-data:/app/data --restart unless-stopped poker-chips:latest
```
