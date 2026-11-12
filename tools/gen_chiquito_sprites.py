# Copyright (c) 2026 Tipapita-Adventure contributors
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11,<13"]
# ///
# ─── How to run ───
# uv run tools/gen_chiquito_sprites.py

"""Generate Chiquito's first production NES sprite sheet and preview."""

from pathlib import Path
from typing import Final, TypeAlias

from PIL import Image, ImageOps

Pixel: TypeAlias = tuple[int, int, int]
Tile: TypeAlias = tuple[str, ...]
Frame: TypeAlias = tuple[str, ...]

TILE_SIZE: Final = 8
FRAME_SIZE: Final = 16
PREVIEW_SCALE: Final = 8

MARKERS: Final[tuple[Pixel, ...]] = (
    (0, 0, 0),
    (85, 85, 85),
    (170, 170, 170),
    (255, 255, 255),
)

TRANSPARENT: Final = (0, 0, 0, 0)
OUTLINE: Final = (24, 20, 28, 255)
FUR: Final = (236, 169, 87, 255)
CREAM: Final = (255, 240, 207, 255)
SCARF: Final = (216, 48, 48, 255)

IDLE: Final[Frame] = (
    "0110001110001100",
    "0121001110012100",
    "0121111111122100",
    "0121222222222100",
    "0112222222333310",
    "0012221223333311",
    "0012222223331110",
    "0001111111111100",
    "0001122233331100",
    "1112222233331100",
    "1222222221110000",
    "1222222222100000",
    "0122222222210000",
    "0012200222210000",
    "0011100011110000",
    "0000000000000000",
)

WALK_CONTACT: Final[Frame] = (
    "0110001110001100",
    "0121001110012100",
    "0121111111122100",
    "0121222222222100",
    "0112222222333310",
    "0012221223333311",
    "0012222223331110",
    "0001111111111100",
    "0001122233331100",
    "0112222233331100",
    "1102222221110000",
    "0012222222100000",
    "0012222222210000",
    "0012220000221000",
    "0001110000111000",
    "0000000000000000",
)

WALK_PASSING: Final[Frame] = (
    "0110001110001100",
    "0121001110012100",
    "0121111111122100",
    "0121222222222100",
    "0112222222333310",
    "0012221223333311",
    "0012222223331110",
    "0001111111111100",
    "0001122233331100",
    "1112222233331100",
    "1222222221110000",
    "0122222222100000",
    "0012222222210000",
    "0001222112210000",
    "0000111001110000",
    "0000000000000000",
)

JUMP: Final[Frame] = (
    "0110001110001100",
    "0121001110012100",
    "0121111111122100",
    "0121222222222100",
    "0112222222333310",
    "0012221223333311",
    "0012222223331110",
    "0001111111111100",
    "0001122233331100",
    "0112222233331100",
    "1122222221110000",
    "0112222222100000",
    "0011222221100000",
    "0000122210000000",
    "0001110011100000",
    "0000000000000000",
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

FRAMES: Final[tuple[Frame, ...]] = (IDLE, WALK_CONTACT, WALK_PASSING, JUMP)


def frame_tiles(frame: Frame) -> tuple[Tile, Tile, Tile, Tile]:
    """Split a 16x16 frame into NES tiles in row-major order."""
    return (
        tuple(row[:TILE_SIZE] for row in frame[:TILE_SIZE]),
        tuple(row[TILE_SIZE:] for row in frame[:TILE_SIZE]),
        tuple(row[:TILE_SIZE] for row in frame[TILE_SIZE:]),
        tuple(row[TILE_SIZE:] for row in frame[TILE_SIZE:]),
    )


def render_chr_sheet(tiles: tuple[Tile, ...]) -> Image.Image:
    """Render marker-color tiles in the one-row format consumed by png2chr."""
    sheet = Image.new("RGB", (TILE_SIZE * len(tiles), TILE_SIZE))
    for tile_index, tile in enumerate(tiles):
        for y, row in enumerate(tile):
            for x, marker in enumerate(row):
                sheet.putpixel((tile_index * TILE_SIZE + x, y), MARKERS[int(marker)])
    return sheet


def render_preview() -> Image.Image:
    """Render the four frames with their intended player subpalettes."""
    preview = Image.new("RGBA", (FRAME_SIZE * len(FRAMES), FRAME_SIZE), TRANSPARENT)
    for frame_index, frame in enumerate(FRAMES):
        for y, row in enumerate(frame):
            colors = (TRANSPARENT, OUTLINE, FUR, CREAM if y < TILE_SIZE else SCARF)
            for x, marker in enumerate(row):
                preview.putpixel((frame_index * FRAME_SIZE + x, y), colors[int(marker)])
    return ImageOps.scale(preview, PREVIEW_SCALE, Image.Resampling.NEAREST)


def main() -> None:
    """Write the CHR source strip and a scaled transparent preview."""
    output_dir = Path("assets/sprites")
    output_dir.mkdir(parents=True, exist_ok=True)
    chiquito_tiles = tuple(tile for frame in FRAMES for tile in frame_tiles(frame))
    render_chr_sheet((*chiquito_tiles, ENEMY, ITEM, WOOD_PLATFORM)).save(
        output_dir / "chiquito_v2.png",
    )
    render_preview().save(output_dir / "chiquito_v2_preview.png")


if __name__ == "__main__":
    main()
