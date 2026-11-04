#!/usr/bin/env python3
"""Arma la tabla de teclas del README (sección Controles) desde ui/controls.gd.

Una fila por acción de Controls.KEYS, en el mismo orden: sus teclas (y las de Controls.PHYSICAL) y
lo que dice el comentario de su línea. La tabla va en el README entre <!-- teclas --> y
<!-- /teclas -->; no se edita a mano.

Uso (desde cualquier carpeta):
  python3 tools/controls_doc.py           la escribe en el README
  python3 tools/controls_doc.py --check   sale con 1 si el README no está al día (lo corre la CI)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTROLS = ROOT / "ui" / "controls.gd"
README = ROOT / "README.md"
START, END = "<!-- teclas -->", "<!-- /teclas -->"

## Cómo se nombra cada tecla en la tabla (las letras, los números y F1..F12, como son)
NAMES = {
    "KEY_ESCAPE": "Esc", "KEY_EQUAL": "=", "KEY_PLUS": "+", "KEY_KP_ADD": "el + del teclado numérico",
    "KEY_MINUS": "-", "KEY_KP_SUBTRACT": "el - del teclado numérico", "KEY_KP_0": "el 0 del teclado numérico",
    "KEY_LEFT": "←", "KEY_RIGHT": "→", "KEY_UP": "↑", "KEY_DOWN": "↓",
    "KEY_QUOTELEFT": "la de la izquierda del 1",
}
ENTRY = re.compile(r'^\s*&"(\w+)":\s*\[([^\]]*)\],?\s*(?:#\s*(.*))?$')


def block(text: str, name: str) -> list:
    """Las entradas de un diccionario const de controls.gd: (acción, [teclas], comentario)."""
    m = re.search(r"^const " + name + r" := \{\n(.*?)^\}", text, re.S | re.M)
    if not m:
        sys.exit(f"No encontré const {name} en {CONTROLS}")
    out = []
    for line in m.group(1).splitlines():
        e = ENTRY.match(line)
        if e:
            keys = [k.strip() for k in e.group(2).split(",") if k.strip()]
            out.append((e.group(1), keys, (e.group(3) or "").strip()))
        elif line.strip() and not line.strip().startswith("#"):
            sys.exit(f"No entiendo esta línea de {name}: {line.strip()!r} (va una acción por línea)")
    return out


def key_name(key: str) -> str:
    if key in NAMES:
        return NAMES[key]
    if re.fullmatch(r"KEY_([A-Z0-9]|F\d+)", key):
        return key[4:]
    sys.exit(f"No sé cómo nombrar {key}: agregalo a NAMES en {Path(__file__).name}")


def table() -> str:
    text = CONTROLS.read_text(encoding="utf-8")
    physical = {a: keys for a, keys, _ in block(text, "PHYSICAL")}
    rows = ["| Tecla | Qué hace |", "|---|---|"]
    for action, keys, what in block(text, "KEYS"):
        if not what:
            sys.exit(f"A {action} le falta el comentario con lo que hace (va a la tabla del README)")
        names = [key_name(k) for k in keys + physical.get(action, [])]
        shown = [n if " " in n else f"`{n}`" for n in names]
        cell = shown[0] if len(shown) == 1 else ", ".join(shown[:-1]) + " o " + shown[-1]
        rows.append(f"| {cell} | {what} |")
    return "\n".join(rows)


def main() -> int:
    readme = README.read_text(encoding="utf-8")
    if START not in readme or END not in readme:
        print(f"El README no tiene la tabla de teclas ({START} ... {END})")
        return 1
    before, rest = readme.split(START, 1)
    _old, after = rest.split(END, 1)
    new = before + START + "\n" + table() + "\n" + END + after
    if "--check" in sys.argv:
        if new != readme:
            print("La tabla de teclas del README no está al día con ui/controls.gd: corré "
                  "python3 tools/controls_doc.py")
            return 1
        print("La tabla de teclas del README está al día.")
        return 0
    README.write_text(new, encoding="utf-8")
    print("Tabla de teclas del README actualizada.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
