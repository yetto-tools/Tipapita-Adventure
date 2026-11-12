# Copyright (c) 2026 Tipapita-Adventure contributors
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11,<13"]
# ///
# Run: uv run tools/gen_taller_tiles.py
"""Generate original 8x8 workshop background tiles and a color preview."""

from pathlib import Path
from typing import Final, TypeAlias

from PIL import Image, ImageOps

Pixel: TypeAlias = tuple[int, int, int]
Tile: TypeAlias = tuple[str, ...]
MARKERS: Final[tuple[Pixel, ...]] = ((0, 0, 0), (85, 85, 85), (170, 170, 170), (255, 255, 255))
# Approximate 2C02 RGB for NES indices $0F, $17, $27, $38.
COLORS: Final[tuple[Pixel, ...]] = ((0, 0, 0), (120, 60, 0), (212, 136, 32), (228, 196, 144))
# Distant wall/beam; midground tool board, wrench, gear and shelf;
# foreground bench top/body/leg and floor edge/body.
TILES: Final[tuple[Tile, ...]] = (
    ("11111111", "11111111", "11121111", "11111111", "11111111", "11111121", "11111111", "11111111"),
    ("00111100", "00222200", "00111100", "00111100", "00121100", "00111100", "00222200", "00111100"),
    ("00000000", "02222220", "02111120", "02111120", "02111120", "02111120", "02222220", "00000000"),
    ("11111111", "11311311", "11331311", "11133111", "11131111", "11331111", "11311111", "11111111"),
    ("11122111", "11333311", "12311321", "23311332", "23311332", "12333321", "11333311", "11122111"),
    ("11111111", "11133111", "11122111", "11322311", "11322311", "11133111", "00000000", "22222222"),
    ("33333333", "22222222", "00000000", "12222221", "12111121", "12111121", "12222221", "10000001"),
    ("33333333", "22222222", "00000000", "22222222", "11111111", "11311111", "11111131", "00000000"),
    ("10000001", "10222201", "10200201", "10200201", "10200201", "10200201", "10200201", "10000001"),
    ("33333333", "00000000", "22222222", "22122222", "22222212", "00000000", "11111111", "11111111"),
    ("11111111", "11211111", "11111121", "11111111", "00000000", "11111111", "11121111", "11111111"),
    ("00000000", "03333330", "03222230", "03200230", "03222230", "03333330", "00000000", "11111111"),
)


def render_sheet(colors: tuple[Pixel, ...]) -> Image.Image:
    """Render the shared tile indices using markers or the preview palette."""
    sheet = Image.new("RGB", (8 * len(TILES), 8))
    for tile_index, tile in enumerate(TILES):
        for y, row in enumerate(tile):
            for x, marker in enumerate(row):
                sheet.putpixel((tile_index * 8 + x, y), colors[int(marker)])
    return sheet


def main() -> None:
    """Write the png2chr input and nearest-neighbor color preview."""
    output = Path("assets/tiles")
    output.mkdir(parents=True, exist_ok=True)
    render_sheet(MARKERS).save(output / "taller_v1.png")
    ImageOps.scale(render_sheet(COLORS), 8, Image.Resampling.NEAREST).save(output / "taller_v1_preview.png")


if __name__ == "__main__":
    main()
