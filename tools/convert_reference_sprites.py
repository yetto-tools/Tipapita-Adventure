# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11,<13"]
# ///
# Run: uv run tools/convert_reference_sprites.py
"""Convert selected concept poses to independently usable NES metasprites."""

import json
from pathlib import Path
from typing import Final

from PIL import Image, ImageDraw

ROOT: Final = Path(__file__).resolve().parent.parent
REF: Final = ROOT / "pipapitas_codex_completo" / "referencias"
OUT: Final = ROOT / "assets" / "sprites" / "nes_referencias"
SIZE: Final = 32
# Approximate 2C02 RGB values, indexed by their actual NES palette numbers.
COLORS: Final = {
    0x0F: (0, 0, 0), 0x00: (84, 84, 84), 0x10: (152, 150, 152),
    0x20: (236, 238, 236), 0x16: (152, 34, 32), 0x26: (236, 106, 100),
    0x27: (212, 136, 32), 0x28: (160, 170, 0), 0x29: (116, 196, 0),
    0x18: (80, 114, 0), 0x17: (120, 60, 0), 0x37: (236, 180, 176),
    0x30: (236, 238, 236), 0x38: (228, 196, 144), 0x19: (0, 118, 40),
    0x11: (8, 76, 196), 0x21: (76, 154, 236), 0x14: (68, 40, 188),
    0x24: (148, 104, 236), 0x28 + 16: (228, 196, 144),
}
# Four palettes per character; each tile uses one palette with three opaque colors.
SPECS: Final = (
    ("chiquito", "personajes/chiquito_concepto_02_turquesa.png", (303, 286, 449, 450), ((0x0F,0x27,0x38),(0x0F,0x00,0x10),(0x0F,0x16,0x27),(0x0F,0x27,0x20))),
    ("chiquito_caminar_1", "personajes/chiquito_concepto_02_turquesa.png", (303, 492, 449, 645), ((0x0F,0x27,0x38),(0x0F,0x00,0x10),(0x0F,0x16,0x27),(0x0F,0x27,0x20))),
    ("chiquito_caminar_2", "personajes/chiquito_concepto_02_turquesa.png", (546, 492, 692, 645), ((0x0F,0x27,0x38),(0x0F,0x00,0x10),(0x0F,0x16,0x27),(0x0F,0x27,0x20))),
    ("chiquito_correr", "personajes/chiquito_concepto_02_turquesa.png", (303, 680, 449, 835), ((0x0F,0x27,0x38),(0x0F,0x00,0x10),(0x0F,0x16,0x27),(0x0F,0x27,0x20))),
    ("chiquito_saltar", "personajes/chiquito_concepto_02_turquesa.png", (546, 866, 692, 1024), ((0x0F,0x27,0x38),(0x0F,0x00,0x10),(0x0F,0x16,0x27),(0x0F,0x27,0x20))),
    ("sanchopau", "estilo/elenco_estilo_turquesa.png", (245, 640, 375, 790), ((0x0F,0x10,0x20),(0x0F,0x27,0x20),(0x0F,0x16,0x27),(0x0F,0x00,0x20))),
    ("mothman", "estilo/elenco_estilo_turquesa.png", (242, 823, 389, 988), ((0x0F,0x14,0x24),(0x0F,0x16,0x27),(0x0F,0x00,0x20),(0x0F,0x27,0x20))),
    ("marcianito", "estilo/elenco_estilo_turquesa.png", (250, 1020, 389, 1185), ((0x0F,0x29,0x20),(0x0F,0x11,0x21),(0x0F,0x14,0x24),(0x0F,0x27,0x20))),
    ("abuelito", "personajes/pipapita_abuelito_concepto_01.png", (284, 230, 447, 405), ((0x0F,0x27,0x38),(0x0F,0x16,0x27),(0x0F,0x18,0x29),(0x0F,0x10,0x20))),
    ("diablito", "personajes/pipapita_diablito_concepto_01.png", (282, 236, 455, 405), ((0x0F,0x16,0x26),(0x0F,0x27,0x38),(0x0F,0x14,0x24),(0x0F,0x00,0x20))),
    ("enemigo_roedor", "../../assets/concepts/objetos_criaturas_montana_v1.png", (38, 322, 230, 475), ((0x0F,0x17,0x27),(0x0F,0x27,0x38),(0x0F,0x10,0x20),(0x0F,0x16,0x26))),
    ("enemigo_carnero", "../../assets/concepts/objetos_criaturas_montana_v1.png", (277, 320, 465, 475), ((0x0F,0x27,0x38),(0x0F,0x10,0x20),(0x0F,0x17,0x27),(0x0F,0x14,0x24))),
    ("enemigo_erizo", "../../assets/concepts/objetos_criaturas_montana_v1.png", (500, 320, 716, 475), ((0x0F,0x14,0x24),(0x0F,0x27,0x38),(0x0F,0x00,0x20),(0x0F,0x17,0x27))),
    ("enemigo_ave", "../../assets/concepts/objetos_criaturas_montana_v1.png", (760, 318, 923, 475), ((0x0F,0x11,0x21),(0x0F,0x27,0x20),(0x0F,0x10,0x20),(0x0F,0x16,0x27))),
    ("enemigo_roca", "../../assets/concepts/objetos_criaturas_montana_v1.png", (970, 320, 1217, 475), ((0x0F,0x10,0x20),(0x0F,0x18,0x29),(0x0F,0x17,0x27),(0x0F,0x14,0x24))),
    ("item_maiz", "../../assets/concepts/objetos_criaturas_montana_v1.png", (60, 95, 205, 240), ((0x0F,0x27,0x38),(0x0F,0x18,0x29),(0x0F,0x27,0x20),(0x0F,0x17,0x27))),
    ("item_metal", "../../assets/concepts/objetos_criaturas_montana_v1.png", (245, 112, 405, 238), ((0x0F,0x10,0x20),(0x0F,0x11,0x21),(0x0F,0x00,0x10),(0x0F,0x27,0x20))),
    ("item_comida", "../../assets/concepts/objetos_criaturas_montana_v1.png", (450, 128, 610, 242), ((0x0F,0x16,0x26),(0x0F,0x17,0x27),(0x0F,0x10,0x20),(0x0F,0x27,0x38))),
    ("power_frasco", "../../assets/concepts/objetos_criaturas_montana_v1.png", (700, 100, 806, 233), ((0x0F,0x27,0x38),(0x0F,0x10,0x20),(0x0F,0x11,0x21),(0x0F,0x17,0x27))),
    ("herramienta_llave", "../../assets/concepts/objetos_criaturas_montana_v1.png", (878, 85, 1009, 241), ((0x0F,0x10,0x20),(0x0F,0x17,0x27),(0x0F,0x11,0x21),(0x0F,0x27,0x38))),
    ("herramienta_resorte", "../../assets/concepts/objetos_criaturas_montana_v1.png", (1060, 107, 1191, 241), ((0x0F,0x27,0x38),(0x0F,0x10,0x20),(0x0F,0x17,0x27),(0x0F,0x11,0x21))),
)


def distance(a: tuple[int, ...], b: tuple[int, ...]) -> int:
    return sum((a[i] - b[i]) ** 2 for i in range(3))


def score_palette(tile: list[tuple[int, ...]], palette: tuple[int, ...]) -> int:
    return sum(min(distance(pixel, COLORS[c]) for c in palette) for pixel in tile if pixel[3] >= 128)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    overview = Image.new("RGB", (SIZE * 6 * len(SPECS), SIZE * 6 + 36), (45, 105, 150))
    draw = ImageDraw.Draw(overview)
    for number, (name, path, crop, palettes) in enumerate(SPECS):
        with Image.open(REF / path) as source:
            source = source.convert("RGBA").crop(crop)
        # Concepts have a flat turquoise presentation background, not alpha.
        pixels = source.load()
        for y in range(source.height):
            for x in range(source.width):
                r, g, b, _ = pixels[x, y]
                if g > 160 and b > 150 and r < 90 and g > r * 1.7:
                    pixels[x, y] = (0, 0, 0, 0)
        source.thumbnail((SIZE, SIZE), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (SIZE, SIZE))
        canvas.alpha_composite(source, ((SIZE - source.width) // 2, SIZE - source.height))
        preview = Image.new("RGBA", (SIZE, SIZE))
        tile_data = bytearray()
        entries = []
        for ty in range(4):
            for tx in range(4):
                tile = [canvas.getpixel((tx * 8 + x, ty * 8 + y)) for y in range(8) for x in range(8)]
                palette_id = min(range(4), key=lambda i: score_palette(tile, palettes[i]))
                palette = palettes[palette_id]
                indices = [0 if pixel[3] < 128 else 1 + min(range(3), key=lambda i: distance(pixel, COLORS[palette[i]])) for pixel in tile]
                if not any(indices):
                    continue
                tile_id = len(tile_data) // 16
                for plane in range(2):
                    for y in range(8):
                        tile_data.append(sum(((indices[y * 8 + x] >> plane) & 1) << (7 - x) for x in range(8)))
                entries.append({"x": tx * 8, "y": ty * 8, "tile": tile_id, "palette": palette_id})
                for i, index in enumerate(indices):
                    if index:
                        preview.putpixel((tx * 8 + i % 8, ty * 8 + i // 8), (*COLORS[palette[index - 1]], 255))
        (OUT / f"{name}.chr").write_bytes(tile_data)
        (OUT / f"{name}.json").write_text(json.dumps({"size": [SIZE, SIZE], "palettes_nes": palettes, "tiles": entries}, indent=2) + "\n", encoding="utf-8")
        preview.save(OUT / f"{name}.png")
        overview.paste(preview.resize((SIZE * 6, SIZE * 6), Image.Resampling.NEAREST), (number * SIZE * 6, 0), preview.resize((SIZE * 6, SIZE * 6), Image.Resampling.NEAREST))
        draw.text((number * SIZE * 6 + 4, SIZE * 6 + 8), name, fill="white")
    overview.save(OUT / "vista_general.png")


if __name__ == "__main__":
    main()
