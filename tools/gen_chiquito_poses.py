# /// script
# requires-python = ">=3.11"
# ///
# ─── How to run ───
# uv run tools/gen_chiquito_poses.py
"""Consolida las 5 poses reales de Chiquito (conversión fiel del
concept art, assets/sprites/nes_referencias/chiquito*.chr+.json -- NO
un redibujo a mano) en:
  - dist/tiles_chiquito.s: los 5 .chr concatenados tal cual (sin pasar
    por PNG ni remapear color), un solo label "tiles_chiquito".
  - dist/chiquito_pose_tables.s: por cada pose, dos tablas RODATA de 16
    bytes (grilla 4x4, orden fila por fila): `chiquito_<pose>_tile`
    (índice ABSOLUTO de tile dentro de tiles_chiquito, o $FF si esa
    celda no tiene tile real -- las referencias no siempre llenan las
    16 celdas) y `chiquito_<pose>_pal` (0 o 1: qué subpaleta de
    hardware, ver más abajo).

Fusión de paleta (verificada, no asumida): las 5 poses declaran las
MISMAS 4 "palettes_nes" y las 5 usan únicamente los índices {0,1,3} --
el 2 no aparece en ningún tile de ninguna pose. 0 y 3 comparten el
mismo color intermedio ($27, naranja) y solo difieren en el tono claro
($38 crema vs $20 blanco) -- se fusionan en una sola subpaleta de
hardware ("A", el pelaje). El 1 es la única paleta en escala de grises
(el sombrero) y queda como la otra subpaleta ("B"). Este guión aborta
si alguna pose llegara a usar una combinación distinta -- ver `assert`.
"""

import json
from pathlib import Path
from typing import Final

REF: Final = Path("assets/sprites/nes_referencias")
OUT: Final = Path("dist")

# (nombre de archivo, sufijo de label)
POSES: Final = (
    ("chiquito", "idle"),
    ("chiquito_caminar_1", "walk1"),
    ("chiquito_caminar_2", "walk2"),
    ("chiquito_correr", "run"),
    ("chiquito_saltar", "jump"),
)

EXPECTED_PALETTES_NES: Final = [[15, 39, 56], [15, 0, 16], [15, 22, 39], [15, 39, 32]]
# Subpaleta real de hardware por cada índice del JSON: 0 y 3 -> "A"
# (pelaje, hardware slot usado por Chiquito superior), 1 -> "B"
# (sombrero, hardware slot usado por Chiquito inferior). 2 nunca
# aparece -- si llegara a aparecer, el assert de abajo lo detiene en
# vez de dibujar algo incorrecto en silencio.
PALETTE_BIT = {0: 0, 3: 0, 1: 1}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    chr_chunks: list[bytes] = []
    tile_base_by_pose: dict[str, int] = {}

    chars_lines = [
        "; Generado automáticamente por tools/gen_chiquito_poses.py.",
        "; No editar a mano -- los cambios se pierden en la siguiente conversión.",
        "; Las 5 poses de Chiquito (conversión fiel del concept art), concatenadas.",
        "",
        '.segment "CHARS"',
        "tiles_chiquito:",
    ]
    tables_lines = [
        "; Generado automáticamente por tools/gen_chiquito_poses.py.",
        "; No editar a mano -- los cambios se pierden en la siguiente conversión.",
        "",
        '.segment "RODATA"',
    ]

    tile_counter = 0
    for filename, suffix in POSES:
        data = (REF / f"{filename}.chr").read_bytes()
        assert len(data) % 16 == 0, f"{filename}.chr: {len(data)} bytes, no múltiplo de 16"
        num_tiles = len(data) // 16
        tile_base_by_pose[suffix] = tile_counter
        for t in range(num_tiles):
            tb = data[t * 16:t * 16 + 16]
            chars_lines.append("    .byte " + ", ".join(f"${b:02X}" for b in tb) + f"  ; {suffix} tile {t}")
        tile_counter += num_tiles

        info = json.loads((REF / f"{filename}.json").read_text(encoding="utf-8"))
        assert info["palettes_nes"] == EXPECTED_PALETTES_NES, (
            f"{filename}.json: palettes_nes distinto al esperado -- revisar la fusión de paleta a mano"
        )
        by_pos = {(t["x"] // 8, t["y"] // 8): t for t in info["tiles"]}
        tile_vals = []
        pal_vals = []
        for ty in range(4):
            for tx in range(4):
                entry = by_pos.get((tx, ty))
                if entry is None:
                    tile_vals.append(0xFF)
                    pal_vals.append(0)
                else:
                    assert entry["palette"] in PALETTE_BIT, (
                        f"{filename}.json: tile ({tx},{ty}) usa la paleta {entry['palette']}, "
                        "no contemplada en la fusión (ver PALETTE_BIT)"
                    )
                    tile_vals.append(tile_base_by_pose[suffix] + entry["tile"])
                    pal_vals.append(PALETTE_BIT[entry["palette"]])
        tables_lines.append(f"chiquito_{suffix}_tile:")
        tables_lines.append("    .byte " + ", ".join(f"${v:02X}" for v in tile_vals))
        tables_lines.append(f"chiquito_{suffix}_pal:")
        tables_lines.append("    .byte " + ", ".join(str(v) for v in pal_vals))

    (OUT / "tiles_chiquito.s").write_text("\n".join(chars_lines) + "\n", encoding="utf-8", newline="\n")
    (OUT / "chiquito_pose_tables.s").write_text("\n".join(tables_lines) + "\n", encoding="utf-8", newline="\n")
    print(f"OK: {tile_counter} tiles totales de Chiquito ({', '.join(f'{s}={tile_base_by_pose[s]}' for _, s in POSES)})")


if __name__ == "__main__":
    main()
