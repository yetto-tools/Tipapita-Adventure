#!/usr/bin/env python3
"""Genera assets/sprites/chiquito_test.png: hoja de sprites de PRIMERA
PASADA (placeholder técnico, no arte final) para validar F2.3. Mismo
convenio de 4 colores marcador que tools/gen_test_tileset.py -- ver
tools/png2chr.py. A diferencia de los tiles de fondo, en los sprites el
índice 0 SIEMPRE es transparente en el hardware (no hay quirk de celda
compartida); aquí se usa para el fondo de cada tile.

Tiles generados, en este orden:
  0: Chiquito -- idle
  1: Chiquito -- caminando (pose de pierna distinta, para animación)
  2: enemigo genérico
  3: coleccionable (gema)
"""

from PIL import Image

TILE = 8

BLACK = (0, 0, 0)        # índice 0 -- transparente en sprites
DARK = (85, 85, 85)      # índice 1
MID = (170, 170, 170)    # índice 2
WHITE = (255, 255, 255)  # índice 3

T = BLACK
D = DARK
M = MID
W = WHITE

CHIQUITO_IDLE = [
    [T, D, T, T, T, D, T, T],
    [T, D, D, T, D, D, T, T],
    [T, D, M, M, M, D, T, T],
    [D, M, M, W, M, M, D, T],
    [D, M, M, M, M, M, D, T],
    [T, D, M, M, M, D, T, T],
    [T, T, D, D, D, T, T, T],
    [T, T, D, T, D, T, T, T],
]

CHIQUITO_WALK = [
    [T, D, T, T, T, D, T, T],
    [T, D, D, T, D, D, T, T],
    [T, D, M, M, M, D, T, T],
    [D, M, M, W, M, M, D, T],
    [D, M, M, M, M, M, D, T],
    [T, D, M, M, M, D, T, T],
    [T, D, D, T, T, D, T, T],
    [T, D, T, T, T, T, D, T],
]

ENEMY = [
    [D, T, D, T, D, T, D, T],
    [T, D, D, D, D, D, T, T],
    [D, M, M, M, M, M, D, T],
    [D, M, W, M, W, M, D, T],
    [D, M, M, M, M, M, D, T],
    [T, D, M, M, M, D, T, T],
    [T, T, D, T, D, T, T, T],
    [T, D, T, T, T, D, T, T],
]

ITEM = [
    [T, T, T, D, D, T, T, T],
    [T, T, D, M, M, D, T, T],
    [T, D, M, W, W, M, D, T],
    [D, M, W, W, W, W, M, D],
    [T, D, M, W, W, M, D, T],
    [T, T, D, M, M, D, T, T],
    [T, T, T, D, D, T, T, T],
    [T, T, T, T, T, T, T, T],
]

TILES = [CHIQUITO_IDLE, CHIQUITO_WALK, ENEMY, ITEM]


def main():
    img = Image.new("RGB", (TILE * len(TILES), TILE))
    for tile_index, tile in enumerate(TILES):
        for y in range(TILE):
            for x in range(TILE):
                img.putpixel((tile_index * TILE + x, y), tile[y][x])

    out_path = "assets/sprites/chiquito_test.png"
    img.save(out_path)
    print(f"Escrito {out_path} ({len(TILES)} tiles de {TILE}x{TILE})")


if __name__ == "__main__":
    main()
