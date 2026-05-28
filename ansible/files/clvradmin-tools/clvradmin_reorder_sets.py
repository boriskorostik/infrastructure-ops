#!/usr/bin/env python3
from __future__ import annotations

from datetime import datetime
from pathlib import Path
import json
import re
import shutil


CONFIG = Path.home() / ".config" / "A7Systems" / "CLVRAdmin.conf"
CITIES = CONFIG.with_name("CLVRAdmin.cities.json")
CITY_ORDER = ["Офис", "Санкт-Петербург", "Москва", "Архангельск", "Без города"]


def city_sort_key(city: str) -> tuple[int, str]:
    if city in CITY_ORDER:
        return (CITY_ORDER.index(city), city.casefold())
    return (len(CITY_ORDER), city.casefold())


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        return value[1:-1]
    return value


def parse_sections(lines: list[str]) -> dict[str, dict[str, str]]:
    sections: dict[str, dict[str, str]] = {}
    current = None
    for raw in lines:
        match = re.fullmatch(r"\[([^]]+)\]\n?", raw.strip())
        if match:
            current = match.group(1)
            sections.setdefault(current, {})
            continue
        if current and "=" in raw:
            key, value = raw.split("=", 1)
            sections[current][key.strip()] = unquote(value)
    return sections


def main() -> int:
    if not CITIES.exists():
        raise SystemExit(f"Сначала создайте карту городов: {CITIES}")

    lines = CONFIG.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    sections = parse_sections(lines)
    try:
        city_map = json.loads(CITIES.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(
            f"Ошибка в {CITIES}: строка {error.lineno}, колонка {error.colno}. "
            "Проверьте кавычки и лишнюю запятую после последнего элемента."
        ) from error

    sets = []
    for set_id, data in sections.items():
        if not re.fullmatch(r"set_\d+", set_id):
            continue
        name = data.get("name", set_id).strip() or set_id
        city = city_map.get(name, "Без города")
        sets.append((city_sort_key(city), name.casefold(), set_id))

    ordered_set_ids = [item[2] for item in sorted(sets)]
    new_sets_line = f'SETS="{";".join(ordered_set_ids)}"\n'

    changed = False
    for index, line in enumerate(lines):
        if line.startswith("SETS="):
            lines[index] = new_sets_line
            changed = True
            break

    if not changed:
        raise SystemExit("Не нашел строку SETS= в конфиге")

    backup = CONFIG.with_name(f"{CONFIG.name}.bak.reorder.{datetime.now():%Y%m%d-%H%M%S}")
    shutil.copy2(CONFIG, backup)
    CONFIG.write_text("".join(lines), encoding="utf-8")
    print(f"Порядок SETS обновлен: {CONFIG}")
    print(f"Бэкап: {backup}")
    print(f"Объектов в SETS: {len(ordered_set_ids)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
