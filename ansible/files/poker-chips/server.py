#!/usr/bin/env python3
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse
import errno
import json
import os
import threading
import time


BASE_DIR = Path(__file__).resolve().parent
PUBLIC_DIR = BASE_DIR / "public"
DATA_FILE = BASE_DIR / "data" / "chips.json"
PORT = int(os.environ.get("PORT", "8080"))
STATE_LOCK = threading.Lock()
ALLOWED_PLAYERS = {"александр", "борис", "даня", "елена", "леонид"}
PLAYER_ALIASES = {"даниил": "Даня"}
PLAYER_NAMES = ["Александр", "Борис", "Даня", "Елена", "Леонид"]


def now_ms():
    return int(time.time() * 1000)


def default_state():
    return {"players": [], "knockouts": {}, "updatedAt": now_ms()}


def load_state():
    if not DATA_FILE.exists():
        return default_state()
    try:
        with DATA_FILE.open("r", encoding="utf-8") as file:
            state = json.load(file)
    except (json.JSONDecodeError, OSError):
        return default_state()
    if not isinstance(state, dict) or not isinstance(state.get("players"), list):
        return default_state()
    if not isinstance(state.get("knockouts"), dict):
        state["knockouts"] = {}
    for player in state["players"]:
        canonical = canonical_name(player.get("name", ""))
        if canonical:
            player["name"] = canonical
    normalized_knockouts = {}
    for name, value in state.get("knockouts", {}).items():
        canonical = canonical_name(name)
        if canonical:
            normalized_knockouts[canonical] = normalize_count(value)
    state["knockouts"] = normalized_knockouts
    return state


def save_state(state):
    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    state["updatedAt"] = now_ms()
    temp_file = DATA_FILE.with_suffix(".tmp")
    with temp_file.open("w", encoding="utf-8") as file:
        json.dump(state, file, ensure_ascii=False, indent=2)
    temp_file.replace(DATA_FILE)


def public_state(state):
    knockouts = state.get("knockouts", {})
    return {
        "players": [
            {
                "name": player.get("name", ""),
                "chips": normalize_chips(player.get("chips", 0)),
                "updatedAt": player.get("updatedAt", state.get("updatedAt", 0)),
            }
            for player in state.get("players", [])
        ],
        "knockouts": {name: normalize_count(knockouts.get(name, 0)) for name in PLAYER_NAMES},
        "entryChips": 1500,
        "placePoints": [12, 8, 5, 3, 1],
        "updatedAt": state.get("updatedAt", now_ms()),
    }


def normalize_name(value):
    return " ".join(str(value or "").strip().split())[:40]


def canonical_name(value):
    name = normalize_name(value)
    return PLAYER_ALIASES.get(name.lower(), name)


def normalize_chips(value):
    try:
        chips = int(value)
    except (TypeError, ValueError):
        chips = 0
    return max(0, min(chips, 999_999_999))


def normalize_count(value):
    try:
        count = int(value)
    except (TypeError, ValueError):
        count = 0
    return max(0, min(count, 9999))


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(PUBLIC_DIR), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_json_body(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)
        if not raw:
            return {}
        return json.loads(raw.decode("utf-8"))

    def do_GET(self):
        if urlparse(self.path).path == "/api/state":
            self.send_json(200, public_state(load_state()))
            return
        super().do_GET()

    def do_POST(self):
        path = urlparse(self.path).path
        if path not in {"/api/player", "/api/reset-my", "/api/delete-player", "/api/knockout"}:
            self.send_error(404)
            return

        try:
            payload = self.read_json_body()
        except (json.JSONDecodeError, UnicodeDecodeError):
            self.send_json(400, {"error": "Некорректные данные"})
            return

        name = canonical_name(payload.get("name"))
        if not name:
            self.send_json(400, {"error": "Введите имя"})
            return

        if path == "/api/delete-player":
            with STATE_LOCK:
                state = load_state()
                players = state["players"]
                state["players"] = [
                    player for player in players if player.get("name", "").lower() != name.lower()
                ]
                if len(state["players"]) == len(players):
                    self.send_json(404, {"error": "Игрок с таким именем не найден"})
                    return
                save_state(state)
                self.send_json(200, public_state(state))
                return

        if name.lower() not in ALLOWED_PLAYERS:
            self.send_json(400, {"error": "Выберите игрока из списка"})
            return

        with STATE_LOCK:
            state = load_state()
            players = state["players"]
            existing = next((player for player in players if player["name"].lower() == name.lower()), None)

            if path == "/api/knockout":
                delta = normalize_count(payload.get("delta"))
                if str(payload.get("delta", "")).startswith("-"):
                    delta = -normalize_count(str(payload.get("delta"))[1:])
                state["knockouts"][name] = max(0, normalize_count(state["knockouts"].get(name, 0)) + delta)
                save_state(state)
                self.send_json(200, public_state(state))
                return

            if path == "/api/reset-my":
                if not existing:
                    self.send_json(404, {"error": "Игрок с таким именем не найден"})
                    return
                existing["chips"] = 0
                existing["updatedAt"] = now_ms()
                players.sort(key=lambda player: (-player["chips"], player["name"].lower()))
                save_state(state)
                self.send_json(200, public_state(state))
                return

            chips = normalize_chips(payload.get("chips"))
            if existing:
                existing.pop("passwordSalt", None)
                existing.pop("passwordHash", None)
                existing["name"] = name
                existing["chips"] = chips
                existing["updatedAt"] = now_ms()
            else:
                players.append({
                    "name": name,
                    "chips": chips,
                    "updatedAt": now_ms(),
                })
            players.sort(key=lambda player: (-player["chips"], player["name"].lower()))
            save_state(state)
            self.send_json(200, public_state(state))


if __name__ == "__main__":
    port = PORT
    while True:
        try:
            server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
            break
        except OSError as error:
            if error.errno != errno.EADDRINUSE:
                raise
            port += 1

    print(f"Poker chips tracker: http://0.0.0.0:{port}")
    print("Для других игроков в этой сети откройте адрес компьютера с этим портом.")
    server.serve_forever()
