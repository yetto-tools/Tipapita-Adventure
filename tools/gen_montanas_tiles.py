# Copyright (c) 2026 Tipapita-Adventure contributors
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11,<13"]
# ///
# ─── How to run ───
# uv run tools/gen_montanas_tiles.py

"""Generate the first production tile set for the Pipapita mountains."""

from pathlib import Path
from typing import Final, TypeAlias

from PIL import Image, ImageOps

Pixel: TypeAlias = tuple[int, int, int]
Tile: TypeAlias = tuple[str, ...]

TILE_SIZE: Final = 8
PREVIEW_SCALE: Final = 8
MARKERS: Final[tuple[Pixel, ...]] = (
    (0, 0, 0),
    (85, 85, 85),
    (170, 170, 170),
    (255, 255, 255),
)

SKY_COLORS: Final[tuple[Pixel, ...]] = (
    (0, 0, 0),
    (93, 150, 255),
    (255, 255, 255),
    (0, 0, 0),
)
GRASS_COLORS: Final[tuple[Pixel, ...]] = (
    (0, 0, 0),
    (0, 150, 0),
    (130, 211, 16),
    (203, 77, 12),
)
EARTH_COLORS: Final[tuple[Pixel, ...]] = (
    (0, 0, 0),
    (203, 77, 12),
    (114, 34, 0),
    (65, 44, 0),
)

SKY: Final[Tile] = (
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
)

CLOUD: Final[Tile] = (
    "11111111",
    "11122111",
    "11222211",
    "12222221",
    "22222222",
    "12222221",
    "11111111",
    "11111111",
)

GRASS_EDGE: Final[Tile] = (
    "12212212",
    "22122221",
    "11211211",
    "33133133",
    "33333333",
    "33323333",
    "33222333",
    "33323333",
)

SOIL: Final[Tile] = (
    "33323333",
    "33222333",
    "32322233",
    "33222333",
    "33323333",
    "23333332",
    "22333322",
    "23333332",
)

CLOUD_PLATFORM: Final[Tile] = (
    "00000000",
    "00333300",
    "03322330",
    "32222223",
    "33333333",
    "00000000",
    "00000000",
    "00000000",
)

WOOD_DOOR: Final[Tile] = (
    "31111113",
    "31222213",
    "31212113",
    "31222213",
    "31223113",
    "31222213",
    "31212113",
    "31111113",
)

CHECKPOINT: Final[Tile] = (
    "13333311",
    "13222311",
    "13333311",
    "11131111",
    "11131111",
    "11131111",
    "11131111",
    "22232222",
)

WORKSHOP_SWITCH: Final[Tile] = (
    "31111113",
    "31222213",
    "31233213",
    "31233213",
    "31222213",
    "31111113",
    "33333333",
    "32333323",
)

BIG_CLOUD_TL: Final[Tile] = (
    "11111111",
    "11111222",
    "11122222",
    "11222222",
    "12222222",
    "22222222",
    "22222222",
    "12222222",
)

BIG_CLOUD_TR: Final[Tile] = (
    "11111111",
    "22211111",
    "22222111",
    "22222211",
    "22222221",
    "22222222",
    "22222222",
    "22222221",
)

BIG_CLOUD_BL: Final[Tile] = (
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
)

BIG_CLOUD_BR: Final[Tile] = (
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
)

TILES: Final[tuple[Tile, ...]] = (
    SKY,
    CLOUD,
    GRASS_EDGE,
    SOIL,
    CLOUD_PLATFORM,
    WOOD_DOOR,
    CHECKPOINT,
    WORKSHOP_SWITCH,
    BIG_CLOUD_TL,
    BIG_CLOUD_TR,
    BIG_CLOUD_BL,
    BIG_CLOUD_BR,
)

TILE_PALETTES: Final[tuple[tuple[Pixel, ...], ...]] = (
    SKY_COLORS,
    SKY_COLORS,
    GRASS_COLORS,
    GRASS_COLORS,
    SKY_COLORS,
    EARTH_COLORS,
    GRASS_COLORS,
    EARTH_COLORS,
    SKY_COLORS,
    SKY_COLORS,
    SKY_COLORS,
    SKY_COLORS,
)


def render_sheet() -> Image.Image:
    """Render marker-color tiles in png2chr's single-row format."""
    sheet = Image.new("RGB", (TILE_SIZE * len(TILES), TILE_SIZE))
    for tile_index, tile in enumerate(TILES):
        for y, row in enumerate(tile):
            for x, marker in enumerate(row):
                sheet.putpixel((tile_index * TILE_SIZE + x, y), MARKERS[int(marker)])
    return sheet


def render_preview() -> Image.Image:
    """Render every tile with the subpalette used by its metatile."""
    preview = Image.new("RGB", (TILE_SIZE * len(TILES), TILE_SIZE))
    for tile_index, tile in enumerate(TILES):
        colors = TILE_PALETTES[tile_index]
        for y, row in enumerate(tile):
            for x, marker in enumerate(row):
                preview.putpixel((tile_index * TILE_SIZE + x, y), colors[int(marker)])
    return ImageOps.scale(preview, PREVIEW_SCALE, Image.Resampling.NEAREST)


def main() -> None:
    """Write the tile sheet and a nearest-neighbor inspection preview."""
    output_dir = Path("assets/tiles")
    output_dir.mkdir(parents=True, exist_ok=True)
    sheet = render_sheet()
    sheet.save(output_dir / "montanas_v2.png")
    render_preview().save(output_dir / "montanas_v2_preview.png")


if __name__ == "__main__":
    main()
