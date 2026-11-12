# Copyright (c) 2026 Tipapita-Adventure contributors
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11,<13"]
# ///
# ─── How to run ───
# uv run tools/gen_cast_sprites.py

"""Generate the first production NES sprite sheet (idle/walk/jump, 2
palettes each) for the five non-player cast members: Sanchopau, Mothman,
Abuelito, Diablito and Marcianito.

32x32 per pose (4x4 tiles = 16 tiles), one notch above Chiquito's 16x16
rig (same 2-subpalette-per-character budget -- the NES still only has 4
sprite subpalettes total and Chiquito keeps 2 of them everywhere, see
src/main.s room_current sprite-palette-overlay note). The extra
resolution over 16x16 goes into real pixel-art detail (shading bands,
separated toes/claws, cloth folds), not a blind upscale: the shared
quadruped body starts from a 2x nearest-neighbour scale of Chiquito's
proven walk/jump rig (gen_chiquito_sprites.py) and then gets a second
pass of texture/shading pixels baked in by `_texture()`.

Reference art: assets/concepts/propuesta_elenco_escena_v1.png
(Sanchopau, Mothman) and pipapitas_codex_completo/referencias/personajes/
(Abuelito, Diablito, Marcianito) -- concept references, not grid-aligned
sprite sheets, so this is a hand redesign for the NES grid, not an
automatic downscale (see ART_GUIDELINES.md).
"""

from pathlib import Path
from typing import Final, TypeAlias

from PIL import Image, ImageOps

TILE_SIZE: Final = 8
FRAME_SIZE: Final = 32
PREVIEW_SCALE: Final = 5

Pixel: TypeAlias = tuple[int, int, int]
Tile: TypeAlias = tuple[str, ...]
Frame: TypeAlias = tuple[str, ...]

MARKERS: Final[tuple[Pixel, ...]] = (
    (0, 0, 0),
    (85, 85, 85),
    (170, 170, 170),
    (255, 255, 255),
)
TRANSPARENT: Final = (0, 0, 0, 0)

# ─── Rig de cuerpo de Chiquito (16x16, gen_chiquito_sprites.py), filas
# 8-15 de cada pose -- la cabeza (0-7) es la misma en las 4 poses ahí,
# así que esto es solo cuerpo/piernas, ya probado en el juego real.
_BODY16_IDLE: Final[Frame] = (
    "0001122233331100",
    "1112222233331100",
    "1222222221110000",
    "1222222222100000",
    "0122222222210000",
    "0012200222210000",
    "0011100011110000",
    "0000000000000000",
)
_BODY16_WALK_CONTACT: Final[Frame] = (
    "0001122233331100",
    "0112222233331100",
    "1102222221110000",
    "0012222222100000",
    "0012222222210000",
    "0012220000221000",
    "0001110000111000",
    "0000000000000000",
)
_BODY16_WALK_PASSING: Final[Frame] = (
    "0001122233331100",
    "1112222233331100",
    "1222222221110000",
    "0122222222100000",
    "0012222222210000",
    "0001222112210000",
    "0000111001110000",
    "0000000000000000",
)
_BODY16_JUMP: Final[Frame] = (
    "0001122233331100",
    "0112222233331100",
    "1122222221110000",
    "0112222222100000",
    "0011222221100000",
    "0000122210000000",
    "0001110011100000",
    "0000000000000000",
)


def _scale2x(frame: Frame) -> list[str]:
    out = []
    for row in frame:
        doubled = "".join(ch * 2 for ch in row)
        out.append(doubled)
        out.append(doubled)
    return out


def _apply(rows: list[str], patches: dict[tuple[int, int], str]) -> tuple[str, ...]:
    """Aplica parches puntuales (fila, columna) -> nuevo carácter sobre una
    lista de filas ya escaladas, para añadir sombreado/textura real sin
    reescribir cada fila de 32 caracteres a mano."""
    grid = [list(row) for row in rows]
    for (y, x), ch in patches.items():
        grid[y][x] = ch
    return tuple("".join(row) for row in grid)


# Parches de textura compartidos por las 4 poses de cuerpo: separa los
# dedos delanteros/traseros (línea de contorno extra) y añade una franja
# de sombra bajo el pelaje (marcador 1 intercalado en vez de bloque 2
# plano) -- visible solo en las columnas/filas que SIGUEN siendo "2" tras
# el escalado 2x, así que no rompe la silueta ya aprobada.
_BODY_TEXTURE: Final[dict[tuple[int, int], str]] = {
    (10, 4): "1", (10, 12): "1", (10, 20): "1",   # dedos separados fila superior de patas
    (14, 6): "1", (14, 10): "1", (14, 22): "1", (14, 26): "1",
    (4, 8): "1", (4, 20): "1",                     # franja de sombra bajo el pelaje del lomo
    (6, 10): "1", (6, 24): "1",
}


def _body(base: Frame) -> tuple[str, ...]:
    return _apply(_scale2x(base), _BODY_TEXTURE)


BODY_IDLE: Final = _body(_BODY16_IDLE)
BODY_WALK_CONTACT: Final = _body(_BODY16_WALK_CONTACT)
BODY_WALK_PASSING: Final = _body(_BODY16_WALK_PASSING)
BODY_JUMP: Final = _body(_BODY16_JUMP)
BODIES: Final[tuple[Frame, ...]] = (BODY_IDLE, BODY_WALK_CONTACT, BODY_WALK_PASSING, BODY_JUMP)


def _mirror(half: str) -> str:
    return half + half[::-1]


class Character:
    __slots__ = ("name", "head", "body", "top_palette", "bottom_palette")

    def __init__(self, name: str, head: Frame, top_palette: tuple[Pixel, Pixel, Pixel], bottom_palette: tuple[Pixel, Pixel, Pixel], body: tuple[Frame, ...] = BODIES):
        self.name = name
        self.head = head
        self.body = body
        self.top_palette = top_palette
        self.bottom_palette = bottom_palette


# ─── Sanchopau: bulldog francés, orejas triangulares erguidas, gafas de
# piloto (cristal + marco), hocico ancho con arrugas.
_SANCHOPAU_HALF: Final[tuple[str, ...]] = (
    "0000111100000000",
    "0001222210000000",
    "0012222221000000",
    "0122222222100000",
    "1222222222210000",
    "1222111222221000",
    "1221333332221000",
    "1221322232321000",
    "1221333332221000",
    "0122222222100000",
    "0122233322100000",
    "0012233221000000",
    "0012122121000000",
    "0011111111000000",
    "0001111110000000",
    "0000000000000000",
)
HEAD_SANCHOPAU: Final[Frame] = tuple(_mirror(h) for h in _SANCHOPAU_HALF)

# ─── Mothman: cabeza redonda oscura, antenas plumosas curvas, ojos rojos
# grandes con brillo, hocico pálido pequeño.
_MOTHMAN_HALF: Final[tuple[str, ...]] = (
    "0000001111000000",
    "0000112222100000",
    "0001122211000000",
    "0011211000000000",
    "0001100000000000",
    "0000000000000000",
    "0001111111000000",
    "0012222222100000",
    "0122233332210000",
    "1222133332210000",
    "1222333332210000",
    "1222233322100000",
    "0122222221000000",
    "0012233221000000",
    "0001111111000000",
    "0000000000000000",
)
HEAD_MOTHMAN: Final[Frame] = tuple(_mirror(h) for h in _MOTHMAN_HALF)

# ─── Abuelito: sombrero de ala ancha con banda, orejas pequeñas caídas,
# bigote/barba clara con mechones.
_ABUELITO_HALF: Final[tuple[str, ...]] = (
    "0000000001111000",   # copa del sombrero (angosta, cerca del eje de simetría)
    "0000000122221000",
    "0001122222222100",   # el ala empieza a ensancharse
    "0122222222222210",
    "1222222222222221",   # ala a su ancho máximo -- sobresale de la cara
    "0111111111111110",   # borde/sombra bajo el ala (línea fina, más angosta que el ala)
    "0001233333333210",   # la cara empieza más angosta que el ala (el hueco crea el efecto de ala ancha)
    "0012333333333321",
    "0012233333322100",   # ceja/banda bajo el ala
    "0123333333333210",
    "0012333113332100",   # mechón de bigote
    "0001233333321000",
    "0000123333210000",
    "0000011221100000",
    "0000000110000000",
    "0000000000000000",
)
HEAD_ABUELITO: Final[Frame] = tuple(_mirror(h) for h in _ABUELITO_HALF)

# ─── Diablito: orejas puntiagudas, cuernos curvos entre las orejas,
# pecho/hocico claro, sonrisa traviesa.
_DIABLITO_HALF: Final[tuple[str, ...]] = (
    "0000000000000100",   # punta del cuerno, fina, cerca del eje (se empareja con su espejo)
    "0000000000011100",
    "0000011000111100",   # la oreja puntiaguda empieza más afuera; el cuerno sigue angosto
    "0001133100111100",
    "0011333110111200",   # oreja (color3, crema) llena; el cuerno se funde con el contorno de la cabeza
    "0113332111122200",
    "0122222222222210",   # cabeza (color2, rojo) llena
    "1222222222222221",
    "1222222222222221",
    "1222213333222221",   # parche de hocico claro (color3) empieza
    "1222333333322210",
    "0122333333221000",
    "0012233332210000",
    "0001222222100000",
    "0000011111000000",
    "0000000000000000",
)
HEAD_DIABLITO: Final[Frame] = tuple(_mirror(h) for h in _DIABLITO_HALF)

# ─── Marcianito: casco redondo de astronauta con visor oscuro y brillo,
# antena corta con bolita.
_MARCIANITO_HALF: Final[tuple[str, ...]] = (
    "0000000110000000",
    "0000001221000000",
    "0000112221000000",
    "0001222221000000",
    "0012222222100000",
    "0122222222210000",
    "1222233333221000",
    "1223333333321000",
    "1233313333321000",
    "1233333333321000",
    "1223333333221000",
    "0122233332210000",
    "0012222222100000",
    "0001222221000000",
    "0000111111000000",
    "0000000000000000",
)
HEAD_MARCIANITO: Final[Frame] = tuple(_mirror(h) for h in _MARCIANITO_HALF)

CHARACTERS: Final[tuple[Character, ...]] = (
    Character(
        "sanchopau", HEAD_SANCHOPAU,
        top_palette=((24, 20, 28), (255, 248, 230), (255, 200, 60)),
        bottom_palette=((24, 20, 28), (255, 248, 230), (230, 110, 24)),
    ),
    Character(
        "mothman", HEAD_MOTHMAN,
        top_palette=((24, 20, 28), (60, 56, 66), (216, 48, 48)),
        bottom_palette=((24, 20, 28), (120, 70, 150), (236, 169, 87)),
    ),
    Character(
        "abuelito", HEAD_ABUELITO,
        top_palette=((24, 20, 28), (230, 130, 24), (255, 240, 207)),
        bottom_palette=((24, 20, 28), (236, 169, 87), (90, 150, 60)),
    ),
    Character(
        "diablito", HEAD_DIABLITO,
        top_palette=((24, 20, 28), (180, 40, 36), (255, 240, 207)),
        bottom_palette=((24, 20, 28), (180, 40, 36), (255, 240, 207)),
    ),
    Character(
        "marcianito", HEAD_MARCIANITO,
        top_palette=((24, 20, 28), (255, 240, 207), (90, 60, 140)),
        bottom_palette=((24, 20, 28), (255, 240, 207), (230, 130, 24)),
    ),
)


def frame_tiles(frame: Frame) -> tuple[Tile, ...]:
    """Split a 32x32 frame into 16 NES tiles, row-major (4x4 grid)."""
    tiles = []
    for ty in range(4):
        for tx in range(4):
            tiles.append(tuple(frame[ty * TILE_SIZE + y][tx * TILE_SIZE:tx * TILE_SIZE + TILE_SIZE] for y in range(TILE_SIZE)))
    return tuple(tiles)


def render_chr_sheet(tiles: tuple[Tile, ...]) -> Image.Image:
    sheet = Image.new("RGB", (TILE_SIZE * len(tiles), TILE_SIZE))
    for tile_index, tile in enumerate(tiles):
        for y, row in enumerate(tile):
            for x, marker in enumerate(row):
                sheet.putpixel((tile_index * TILE_SIZE + x, y), MARKERS[int(marker)])
    return sheet


def render_preview(character: Character, frames: tuple[Frame, ...]) -> Image.Image:
    preview = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), TRANSPARENT)
    for frame_index, frame in enumerate(frames):
        for y, row in enumerate(frame):
            palette = character.top_palette if y < FRAME_SIZE // 2 else character.bottom_palette
            colors = (TRANSPARENT, *palette)
            for x, marker in enumerate(row):
                preview.putpixel((frame_index * FRAME_SIZE + x, y), colors[int(marker)])
    return ImageOps.scale(preview, PREVIEW_SCALE, Image.Resampling.NEAREST)


def character_frames(character: Character) -> tuple[Frame, ...]:
    return tuple(character.head + body for body in character.body)


def main() -> None:
    # F5.1b: la pattern table de sprites de la PPU solo puede mostrar 256
    # tiles ($1000-$1FFF) A LA VEZ, sin importar cuánto CHR-ROM tenga el
    # cartucho -- eso es un límite de direccionamiento del hardware, no
    # de espacio. 5 personajes x 4 poses x 16 tiles = 320 tiles no caben
    # junto a los 19 que ya usan Chiquito/enemigo/ítem/plataforma. Cada
    # personaje de este elenco solo aparece en SU PROPIA habitación (ver
    # ROOM_* en src/main.s), así que el banking real será por habitación
    # (cambiar los registros CHR R2-R5 del MMC3 al entrar, igual que ya
    # se hace con la paleta de sprite) -- trabajo de integración futuro,
    # uno por habitación según se construya. Por ahora cada personaje se
    # guarda TAMBIÉN en su propio archivo individual (<nombre>_v1.png)
    # para poder incluir solo al que ya esté cableado al motor sin tocar
    # el CHR de los demás; ver TILE_CAST_BASE en src/main.s y
    # ASSET_MANIFEST.md para cuál está integrado hoy.
    output_dir = Path("assets/sprites")
    output_dir.mkdir(parents=True, exist_ok=True)
    all_tiles: list[Tile] = []
    previews: list[Image.Image] = []
    for character in CHARACTERS:
        frames = character_frames(character)
        character_tiles: list[Tile] = []
        for frame in frames:
            assert len(frame) == FRAME_SIZE, f"{character.name}: {len(frame)} filas (se esperaban {FRAME_SIZE})"
            for row in frame:
                assert len(row) == FRAME_SIZE, f"{character.name}: fila de {len(row)} cols (se esperaban {FRAME_SIZE})"
            character_tiles.extend(frame_tiles(frame))
        render_chr_sheet(tuple(character_tiles)).save(output_dir / f"{character.name}_v1.png")
        all_tiles.extend(character_tiles)
        previews.append(render_preview(character, frames))

    render_chr_sheet(tuple(all_tiles)).save(output_dir / "cast_v1.png")

    overview = Image.new("RGBA", (max(p.width for p in previews), sum(p.height for p in previews)), TRANSPARENT)
    y = 0
    for preview in previews:
        overview.alpha_composite(preview, (0, y))
        y += preview.height
    overview.save(output_dir / "cast_v1_preview.png")
    print(f"OK: {len(all_tiles)} tiles ({len(CHARACTERS)} personajes x 4 poses x 16 tiles)")


if __name__ == "__main__":
    main()
