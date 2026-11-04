#!/usr/bin/env python3
"""Compara las capturas de la interfaz de antes y de ahora (ver tools/ci/screenshots.gd).

Uso: compare_screens.py <antes> <ahora> <salida>

Para cada captura de <ahora> dice si quedó igual a la de <antes> o cuántos píxeles cambiaron y
dónde (el rectángulo que los encierra; en la primera que cambió, también un mapa en texto de la
pantalla, # donde hay cambios), unos píxeles de muestra (el color de antes y el de ahora) y si lo de
ahora es lo de antes corrido unos píxeles. Deja en <salida> una imagen diff_<nombre>.png con lo que
cambió en magenta. También dice el brillo promedio de cada una (una captura negra es que no se
dibujó nada). No falla por diferencias: a veces son a propósito; es para mirarlo.
Necesita Pillow.
"""

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

GRID = (48, 18)   # Columnas y filas del mapa en texto
SHIFT = 6         # Hasta cuántos píxeles busca si lo de ahora es lo de antes corrido
SAMPLES = 4       # Píxeles de muestra de cada captura que cambió


def changed_mask(a: Image.Image, b: Image.Image) -> Image.Image:
    """Blanco donde algún canal es distinto."""
    r, g, bl = ImageChops.difference(a, b).split()
    diff = ImageChops.lighter(r, ImageChops.lighter(g, bl))
    return diff.point(lambda v: 255 if v > 0 else 0)


def text_map(mask: Image.Image) -> list[str]:
    w, h = mask.size
    cols, rows = GRID
    lines = []
    for y in range(rows):
        line = ""
        for x in range(cols):
            box = (x * w // cols, y * h // rows, (x + 1) * w // cols, (y + 1) * h // rows)
            line += "#" if mask.crop(box).getbbox() else "."
        lines.append("    " + line)
    return lines


def samples(mask: Image.Image, prev: Image.Image, now: Image.Image) -> list[str]:
    """Unos píxeles que cambiaron, repartidos: dónde, el color de antes y el de ahora."""
    w = mask.size[0]
    spots = [i for i, v in enumerate(mask.tobytes()) if v]
    out = []
    for k in range(SAMPLES):
        i = spots[k * (len(spots) - 1) // max(1, SAMPLES - 1)]
        xy = (i % w, i // w)
        out.append(f"{xy}: {prev.getpixel(xy)} -> {now.getpixel(xy)}")
    return out


def best_shift(box: tuple, prev: Image.Image, now: Image.Image) -> str:
    """Si lo de ahora, en el rectángulo que cambió, es lo de antes corrido (dx, dy): cuánto."""
    pad = SHIFT
    x0, y0, x1, y1 = box
    area = (max(0, x0 - pad), max(0, y0 - pad), min(now.size[0], x1 + pad), min(now.size[1], y1 + pad))
    a = now.crop(area)
    still = changed_mask(prev.crop(area), a).histogram()[255]
    best = None
    for dy in range(-SHIFT, SHIFT + 1):
        for dx in range(-SHIFT, SHIFT + 1):
            moved = (area[0] - dx, area[1] - dy, area[2] - dx, area[3] - dy)
            if moved[0] < 0 or moved[1] < 0 or moved[2] > prev.size[0] or moved[3] > prev.size[1]:
                continue
            count = changed_mask(prev.crop(moved), a).histogram()[255]
            if best is None or count < best[0]:
                best = (count, dx, dy)
    if best is None or best[0] > still // 10:   # Corrido no mejora casi nada: no es eso
        return "no es lo de antes corrido"
    return f"lo más parecido: lo de antes corrido ({best[1]}, {best[2]}), con {best[0]} píxeles distintos"


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    before, after, out = (Path(p) for p in sys.argv[1:])
    out.mkdir(parents=True, exist_ok=True)
    shots = sorted(p for p in after.glob("*.png") if not p.name.startswith("diff_"))
    if not shots:
        print("No hay capturas de ahora.")
        return 0
    if not before.is_dir() or not any(before.glob("*.png")):
        print("No hay capturas de antes para comparar.")
    same = 0
    mapped = False
    for shot in shots:
        now = Image.open(shot).convert("RGB")
        light = ImageStat.Stat(now.convert("L")).mean[0]
        prev_path = before / shot.name
        if not prev_path.exists():
            print(f"{shot.stem:16} nueva (brillo {light:.0f})")
            continue
        prev = Image.open(prev_path).convert("RGB")
        if prev.size != now.size:
            print(f"{shot.stem:16} cambió de tamaño: {prev.size} -> {now.size}")
            continue
        mask = changed_mask(prev, now)
        box = mask.getbbox()
        if box is None:
            same += 1
            print(f"{shot.stem:16} igual (brillo {light:.0f})")
            continue
        count = mask.histogram()[255]
        print(f"{shot.stem:16} {count} píxeles distintos, en {box} (brillo {light:.0f})")
        if not mapped:
            print("\n".join(text_map(mask)))
            mapped = True
        for line in samples(mask, prev, now):
            print("    " + line)
        print("    " + best_shift(box, prev, now))
        shown = Image.blend(now, Image.new("RGB", now.size), 0.6)
        shown.paste((255, 0, 255), mask=mask)
        shown.save(out / f"diff_{shot.name}")
    print(f"Iguales: {same} de {len(shots)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
