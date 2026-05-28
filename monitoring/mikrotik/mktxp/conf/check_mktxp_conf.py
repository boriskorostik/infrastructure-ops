#!/usr/bin/env python3
import configparser
import sys
from pathlib import Path

try:
    from rich.console import Console
    from rich.table import Table
    from rich import box
except ImportError:
    print("Установи rich: pip install rich")
    sys.exit(1)

console = Console()

def validate_section(section_name, section_data):
    """Проверяем обязательные поля"""
    required_fields = ["hostname", "username", "password", "enabled"]
    missing = [f for f in required_fields if f not in section_data]
    return missing


def check_mktxp_conf(conf_path="mktxp.conf"):
    conf_file = Path(conf_path)
    if not conf_file.exists():
        console.print(f"[bold red]Ошибка:[/bold red] Файл {conf_file} не найден!")
        sys.exit(1)

    parser = configparser.ConfigParser(allow_no_value=True)
    try:
        parser.read(conf_file)
    except configparser.MissingSectionHeaderError:
        console.print("[bold red]Ошибка:[/bold red] Нет заголовков секций ([section])")
        sys.exit(1)
    except Exception as e:
        console.print(f"[bold red]Ошибка при чтении файла:[/bold red] {e}")
        sys.exit(1)

    if not parser.sections():
        console.print("[bold red]Файл пуст или не содержит секций[/bold red]")
        sys.exit(1)

    table = Table(title=f"Проверка {conf_file}", box=box.SIMPLE_HEAVY)
    table.add_column("Секция", style="cyan")
    table.add_column("Статус", style="green")
    table.add_column("Отсутствующие поля", style="yellow")

    errors = 0
    for section in parser.sections():
        missing = validate_section(section, parser[section])
        if missing:
            table.add_row(section, "[red]Ошибка[/red]", ", ".join(missing))
            errors += 1
        else:
            table.add_row(section, "[green]OK[/green]", "-")

    console.print(table)

    if errors > 0:
        console.print(f"[bold red]Обнаружено ошибок: {errors}[/bold red]")
        sys.exit(1)
    else:
        console.print("[bold green]Конфигурация корректна![/bold green]")

if __name__ == "__main__":
    conf_file = sys.argv[1] if len(sys.argv) > 1 else "mktxp.conf"
    check_mktxp_conf(conf_file)
