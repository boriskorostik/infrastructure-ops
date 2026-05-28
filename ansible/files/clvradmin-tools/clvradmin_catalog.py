#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from html import escape
from pathlib import Path
import json
import re
import sys


CONFIG = Path.home() / ".config" / "A7Systems" / "CLVRAdmin.conf"
CITIES = CONFIG.with_name("CLVRAdmin.cities.json")
OUTPUT = CONFIG.with_name("CLVRAdmin.catalog.html")
CITY_ORDER = ["Офис", "Санкт-Петербург", "Москва", "Архангельск", "Без города"]


@dataclass
class Entry:
    set_id: str
    name: str
    tcp_ip: str
    tcp_port: str
    udp_ip: str
    udp_port: str
    login: str
    db: str
    user_data_id: str
    protocol: str
    city: str


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1]
    return value


def parse_qsettings(path: Path) -> dict[str, dict[str, str]]:
    sections: dict[str, dict[str, str]] = {}
    section = None
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        match = re.fullmatch(r"\[([^]]+)\]", line)
        if match:
            section = match.group(1)
            sections.setdefault(section, {})
            continue
        if section and "=" in raw:
            key, value = raw.split("=", 1)
            sections[section][key.strip()] = unquote(value)
    return sections


def load_cities(entries: list[dict[str, str]]) -> dict[str, str]:
    if CITIES.exists():
        try:
            return json.loads(CITIES.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            raise SystemExit(
                f"Ошибка в {CITIES}: строка {error.lineno}, колонка {error.colno}. "
                "Проверьте кавычки и лишнюю запятую после последнего элемента."
            ) from error

    city_map = {entry["name"]: "Без города" for entry in entries}
    CITIES.write_text(json.dumps(city_map, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return city_map


def collect_entries(sections: dict[str, dict[str, str]]) -> list[Entry]:
    raw_entries = []
    for set_id, data in sections.items():
        if not re.fullmatch(r"set_\d+", set_id):
            continue
        raw_entries.append(
            {
                "set_id": set_id,
                "name": data.get("name", set_id).strip() or set_id,
                "tcp_ip": data.get("SB\\tcp\\ip", ""),
                "tcp_port": data.get("SB\\tcp\\port", ""),
                "udp_ip": data.get("SB\\udp\\serverAddress", ""),
                "udp_port": data.get("SB\\udp\\serverPort", ""),
                "login": data.get("SB\\login", ""),
                "db": data.get("SB\\dboname", ""),
                "user_data_id": data.get("SB\\userDataId", ""),
                "protocol": data.get("SB\\connectionProtocol", ""),
            }
        )

    city_map = load_cities(raw_entries)
    entries = [
        Entry(
            set_id=item["set_id"],
            name=item["name"],
            tcp_ip=item["tcp_ip"],
            tcp_port=item["tcp_port"],
            udp_ip=item["udp_ip"],
            udp_port=item["udp_port"],
            login=item["login"],
            db=item["db"],
            user_data_id=item["user_data_id"],
            protocol=item["protocol"],
            city=city_map.get(item["name"], "Без города"),
        )
        for item in raw_entries
    ]
    return sorted(entries, key=lambda item: (city_sort_key(item.city), item.name.casefold(), item.set_id))


def city_sort_key(city: str) -> tuple[int, str]:
    if city in CITY_ORDER:
        return (CITY_ORDER.index(city), city.casefold())
    return (len(CITY_ORDER), city.casefold())


def render(entries: list[Entry]) -> str:
    rows = []
    for entry in entries:
        search_blob = " ".join(
            [
                entry.city,
                entry.name,
                entry.set_id,
                entry.tcp_ip,
                entry.tcp_port,
                entry.udp_ip,
                entry.udp_port,
                entry.login,
                entry.db,
                entry.user_data_id,
            ]
        ).casefold()
        rows.append(
            f"""
            <article class="card" data-city="{escape(entry.city)}" data-search="{escape(search_blob)}">
              <div>
                <div class="city">{escape(entry.city)}</div>
                <h2>{escape(entry.name)}</h2>
                <div class="meta">{escape(entry.set_id)} · {escape(entry.db or "без БД")} · userDataId {escape(entry.user_data_id or "-")}</div>
              </div>
              <dl>
                <dt>TCP</dt><dd>{escape(entry.tcp_ip or "-")}:{escape(entry.tcp_port or "-")}</dd>
                <dt>UDP</dt><dd>{escape(entry.udp_ip or "-")}:{escape(entry.udp_port or "-")}</dd>
                <dt>Логин</dt><dd>{escape(entry.login or "-")}</dd>
              </dl>
            </article>
            """
        )

    city_options = "\n".join(
        f'<option value="{escape(city)}">{escape(city)}</option>'
        for city in sorted({entry.city for entry in entries}, key=city_sort_key)
    )

    return f"""<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CLVRAdmin подключения</title>
  <style>
    :root {{ color-scheme: dark; font-family: Inter, system-ui, -apple-system, "Segoe UI", sans-serif; --bg:#101412; --panel:#18211d; --line:#33483f; --text:#f3f0e8; --muted:#aebbb5; --gold:#e5bd4c; }}
    * {{ box-sizing: border-box; }}
    body {{ margin: 0; background: var(--bg); color: var(--text); }}
    main {{ width: min(1180px, 100%); margin: 0 auto; padding: 22px; }}
    h1 {{ margin: 0 0 12px; font-size: clamp(2rem, 6vw, 4rem); }}
    .toolbar {{ position: sticky; top: 0; z-index: 2; display: grid; grid-template-columns: 1fr 220px; gap: 10px; padding: 12px 0; background: linear-gradient(var(--bg) 75%, transparent); }}
    input, select {{ width: 100%; min-height: 46px; border: 1px solid var(--line); border-radius: 8px; padding: 0 12px; background: #0e1512; color: var(--text); font: inherit; }}
    .summary {{ color: var(--muted); margin-bottom: 12px; }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(310px, 1fr)); gap: 10px; }}
    .card {{ border: 1px solid var(--line); border-radius: 8px; background: var(--panel); padding: 14px; display: grid; gap: 12px; }}
    .city {{ color: var(--gold); font-weight: 900; font-size: .82rem; text-transform: uppercase; }}
    h2 {{ margin: 3px 0; font-size: 1.35rem; }}
    .meta {{ color: var(--muted); font-size: .9rem; }}
    dl {{ display: grid; grid-template-columns: 58px minmax(0, 1fr); gap: 5px 10px; margin: 0; }}
    dt {{ color: var(--muted); }}
    dd {{ margin: 0; overflow-wrap: anywhere; }}
    mark {{ background: var(--gold); color: #171104; }}
    @media (max-width: 680px) {{ main {{ padding: 14px; }} .toolbar {{ grid-template-columns: 1fr; }} }}
  </style>
</head>
<body>
<main>
  <h1>CLVRAdmin подключения</h1>
  <div class="toolbar">
    <input id="search" type="search" placeholder="Поиск: объект, город, IP, логин, set_...">
    <select id="city"><option value="">Все города</option>{city_options}</select>
  </div>
  <div id="summary" class="summary"></div>
  <section id="grid" class="grid">
    {''.join(rows)}
  </section>
</main>
<script>
const search = document.querySelector("#search");
const city = document.querySelector("#city");
const cards = [...document.querySelectorAll(".card")];
const summary = document.querySelector("#summary");
function applyFilter() {{
  const q = search.value.trim().toLocaleLowerCase();
  const selectedCity = city.value;
  let visible = 0;
  for (const card of cards) {{
    const okCity = !selectedCity || card.dataset.city === selectedCity;
    const okSearch = !q || card.dataset.search.includes(q);
    const show = okCity && okSearch;
    card.hidden = !show;
    if (show) visible += 1;
  }}
  summary.textContent = `Показано ${{visible}} из ${{cards.length}}`;
}}
search.addEventListener("input", applyFilter);
city.addEventListener("change", applyFilter);
applyFilter();
</script>
</body>
</html>
"""


def main() -> int:
    config = Path(sys.argv[1]) if len(sys.argv) > 1 else CONFIG
    sections = parse_qsettings(config)
    entries = collect_entries(sections)
    OUTPUT.write_text(render(entries), encoding="utf-8")
    print(f"Каталог создан: {OUTPUT}")
    print(f"Карта городов: {CITIES}")
    print(f"Объектов: {len(entries)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
