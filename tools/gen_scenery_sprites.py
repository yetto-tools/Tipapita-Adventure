# Copyright (c) 2026 Tipapita-Adventure contributors
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11,<13"]
# ///
# ─── How to run ───
# uv run tools/gen_scenery_sprites.py

"""Enemigo/ítem/plataforma de prueba (F2.3/F4.4), separados de Chiquito.

Antes vivían en el mismo PNG que las 4 poses de Chiquito dibujadas a
mano (gen_chiquito_sprites.py); ahora que Chiquito usa la conversión
fiel de assets/sprites/nes_referencias/chiquito*.chr (ver
tools/gen_chiquito_poses.py), estos 3 tiles -- que siguen siendo
pixel art simple a mano, sin referencia real todavía -- se generan
aparte. gen_chiquito_sprites.py se deja en el repo sin uso en el build
real (documenta el intento de redibujar a Chiquito a mano, descartado
por calidad -- ver TASKS.md).
"""

from pathlib import Path
from typing import Final, TypeAlias

from PIL import Image

Pixel: TypeAlias = tuple[int, int, int]
Tile: TypeAlias = tuple[str, ...]

TILE_SIZE: Final = 8

MARKERS: Final[tuple[Pixel, ...]] = (
    (0, 0, 0),
    (85, 85, 85),
    (170, 170, 170),
    (255, 255, 255),
)

ENEMY: Final[Tile] = (
    "10101010",
    "01111100",
    "12222210",
    "12323210",
    "12222210",
    "01222200",
    "00101000",
    "01000100",
)

ITEM: Final[Tile] = (
    "00011000",
    "00122100",
    "01233210",
    "12333321",
    "01233210",
    "00122100",
    "00011000",
    "00000000",
)

WOOD_PLATFORM: Final[Tile] = (
    "00000000",
    "11111111",
    "12222221",
    "12322321",
    "12233221",
    "11111111",
    "00000000",
    "00000000",
)

TILES: Final[tuple[Tile, ...]] = (ENEMY, ITEM, WOOD_PLATFORM)


def render_chr_sheet(tiles: tuple[Tile, ...]) -> Image.Image:
    sheet = Image.new("RGB", (TILE_SIZE * len(tiles), TILE_SIZE))
    for tile_index, tile in enumerate(tiles):
        for y, row in enumerate(tile):
            for x, marker in enumerate(row):
                sheet.putpixel((tile_index * TILE_SIZE + x, y), MARKERS[int(marker)])
    return sheet


def main() -> None:
    output_dir = Path("assets/sprites")
    output_dir.mkdir(parents=True, exist_ok=True)
    render_chr_sheet(TILES).save(output_dir / "scenery_v1.png")


if __name__ == "__main__":
    main()
