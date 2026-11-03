#!/usr/bin/env python3
"""Chequea que las traducciones (ui/i18n.gd) estén al día con el código.

El juego está escrito en español y cada texto es su propia clave de traducción (ver I18n). Este
script lee todos los .gd y avisa:
- los textos que no están en I18n.EN (les falta la traducción al inglés);
- las claves de I18n.EN que ya no aparecen en el código (sobran: el texto cambió o se fue).

Cuenta como texto un literal entre comillas que tenga letras y además un espacio, una tilde, una
ñ o ¡¿; o cualquier literal con letras que vaya a tr(), popup_text(), .text, .tooltip_text,
make_label() o make_button(), o que sea el valor de "name", "tip", "hint"... en un diccionario.
No mira los comentarios ni lo que va a print(), push_error() o push_warning().

Uso: python3 tools/check_i18n.py (desde cualquier carpeta). Sale con 1 si encuentra algo.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
I18N = ROOT / "ui" / "i18n.gd"

## Textos que no se traducen, a propósito
NO_TRANSLATE = {
    "%d FPS",                      # Iguales en los dos idiomas
    " · %d h %02d min",
    " · %d min",
    "Español",                     # Cada idioma se nombra en su idioma (ver Settings.LOCALES)
    "devoción", "días", "años",    # Lo que se puede escribir en la consola de trucos
    "coño",                        # Lo que no puede salir en un nombre (ver Names.BANNED)
}
## Comandos de la consola de trucos ("ayuda / help", "fe / faith [n]"): ya van en los dos idiomas
COMMAND = re.compile(r"^\S+ / \S+( \[n\])?$")

STR = r'"((?:[^"\\]|\\.)*)"'
LETTERS = re.compile(r"[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]")
## Lo que no es texto: los %d / %s / %.1f / %% y las etiquetas BBCode ([b], [color=#fff]...)
NOT_TEXT = re.compile(r"%[-+ 0#]*\d*(\.\d+)?[sdifxXc%]|\[/?[a-z_]+(=[^\]]*)?\]")
SPANISH = re.compile(r"[ÁÉÍÓÚÑáéíóúñ¡¿]")
## Lo que viene justo antes de un literal que seguro se muestra
SINK = re.compile(r"(\btr|\bpopup_text|\bmake_label|\bmake_button)\(\s*$"
                  r"|\.(text|tooltip_text|placeholder_text)\s*\+?=\s*$"
                  r'|"(name|tip|hint|shop|unlocked|locked_tip|title|desc)"\s*:\s*$')
DEV_ONLY = re.compile(r"\b(print|printerr|push_error|push_warning|assert)\(")


def literals(line: str):
    """Los literales "..." de una línea de GDScript (sin el comentario), con su posición."""
    out = []
    i = 0
    while i < len(line):
        c = line[i]
        if c == "#":
            break
        if c == '"':
            j = i + 1
            while j < len(line) and line[j] != '"':
                j += 2 if line[j] == "\\" else 1
            out.append((i, line[i + 1:j]))
            i = j + 1
            continue
        i += 1
    return out


def en_keys() -> dict:
    keys = {}
    for n, line in enumerate(I18N.read_text(encoding="utf-8").splitlines(), 1):
        m = re.match(r"^\s*" + STR + r"\s*:\s*" + STR, line)
        if m:
            keys[m.group(1)] = n
    return keys


def main() -> int:
    keys = en_keys()
    missing = {}   # texto -> [archivo:línea]
    seen = set()   # todos los literales del código
    for f in sorted(ROOT.rglob("*.gd")):
        if f == I18N or ".godot" in f.parts:
            continue
        rel = f.relative_to(ROOT).as_posix()
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if DEV_ONLY.search(line):
                continue
            for pos, text in literals(line):
                seen.add(text)
                if text in keys or text in NO_TRANSLATE or COMMAND.match(text):
                    continue
                # Lo que seguro se muestra, con que tenga letras; lo demás, si tiene pinta de texto
                # (así no cuentan los nombres internos: grupos, claves del guardado, rutas...)
                words = NOT_TEXT.sub("", text)
                letters = len(LETTERS.findall(words))
                shown = SINK.search(line[:pos]) is not None and letters >= 2
                looks = letters >= 3 and (" " in words.strip() or SPANISH.search(words) is not None)
                if shown or looks:
                    missing.setdefault(text, []).append(f"{rel}:{n}")

    unused = sorted((n, k) for k, n in keys.items() if k not in seen)

    if missing:
        print(f"Textos sin traducción en ui/i18n.gd ({len(missing)}): agregalos a I18n.EN")
        for text, where in sorted(missing.items(), key=lambda kv: kv[1][0]):
            more = f" (y {len(where) - 1} más)" if len(where) > 1 else ""
            print(f"  {where[0]}{more}: {text!r}")
    if unused:
        print(f"Claves de I18n.EN que ya no están en el código ({len(unused)}): sacalas")
        for n, k in unused:
            print(f"  ui/i18n.gd:{n}: {k!r}")
    if missing or unused:
        return 1
    print(f"Traducciones al día: {len(keys)} claves.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
