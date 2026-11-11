#!/usr/bin/env python3
"""Genera assets/tiles/pradera.png: una hoja de tiles 8x8 de PRIMERA PASADA
(placeholder técnico, no arte final) para validar el pipeline PNG->CHR de
F2.2. Cada tile usa como máximo 4 tonos de gris (negro/gris oscuro/gris
claro/blanco), que png2chr.py mapea a índices de color 0-3 por orden
ascendente de valor RGB -- ver tools/png2chr.py.

Tiles generados, en este orden (cada uno ocupa una columna de 8px):
  0: blanco (cielo/vacío -- todo índice 0)
  1: nube (decoración)
  2: suelo con borde de pasto (superficie)
  3: relleno de tierra (bajo la superficie)
  4: plataforma flotante
  5: puerta (marco + picaporte -- F4.3, transición a habitación fija)

Este script es una herramienta de un solo uso para producir el asset de
prueba; el pipeline real (png2chr.py) no depende de él -- consume
cualquier PNG con tiles de 8x8 y <=4 colores por tile.
"""

from PIL import Image

TILE = 8
NUM_TILES = 6

# Tonos en escala de grises; png2chr.py los ordena por valor ascendente al
# asignar índices 0-3, así que el orden aquí es solo para legibilidad.
BLACK = (0, 0, 0)        # índice 0
DARK = (85, 85, 85)      # índice 1
MID = (170, 170, 170)    # índice 2
WHITE = (255, 255, 255)  # índice 3

TILE_BLANK = [
    # Índice 1 (no 0): el color 0 de fondo es la misma celda física para
    # las 4 subpaletas (ver nota en palettes.s), así que un tile "vacío"
    # con índice 0 siempre saldría negro sin importar la subpaleta. Con
    # índice 1 sí se ve el azul cielo real de la subpaleta 0.
    [DARK] * 8 for _ in range(8)
]

TILE_CLOUD = [
    [BLACK, BLACK, DARK, DARK, DARK, BLACK, BLACK, BLACK],
    [BLACK, DARK, MID, MID, MID, DARK, BLACK, BLACK],
    [DARK, MID, MID, MID, MID, MID, DARK, BLACK],
    [DARK, MID, MID, MID, MID, MID, MID, DARK],
    [BLACK, DARK, MID, MID, MID, MID, DARK, BLACK],
    [BLACK, BLACK, DARK, DARK, DARK, DARK, BLACK, BLACK],
    [BLACK] * 8,
    [BLACK] * 8,
]

TILE_GROUND_TOP = [
    [DARK] * 8,
    [DARK, MID, DARK, MID, DARK, MID, DARK, MID],
    [MID] * 8,
    [MID, WHITE, MID, MID, WHITE, MID, MID, WHITE],
    [MID] * 8,
    [MID, MID, WHITE, MID, MID, MID, WHITE, MID],
    [MID] * 8,
    [MID] * 8,
]

TILE_GROUND_FILL = [
    [MID, MID, WHITE, MID, MID, MID, WHITE, MID],
    [MID] * 8,
    [MID, WHITE, MID, MID, WHITE, MID, MID, WHITE],
    [MID] * 8,
    [MID] * 8,
    [MID, MID, WHITE, MID, MID, MID, WHITE, MID],
    [MID] * 8,
    [MID, WHITE, MID, MID, MID, WHITE, MID, MID],
]

TILE_PLATFORM = [
    [DARK] * 8,
    [MID] * 8,
    [MID, WHITE, MID, MID, MID, WHITE, MID, MID],
    [MID] * 8,
    [BLACK] * 8,
    [BLACK] * 8,
    [BLACK] * 8,
    [BLACK] * 8,
]

TILE_DOOR = [
    [MID] * 8,
    [MID, DARK, DARK, DARK, DARK, DARK, DARK, MID],
    [MID, DARK, DARK, DARK, DARK, DARK, DARK, MID],
    [MID, DARK, DARK, DARK, DARK, DARK, DARK, MID],
    [MID, DARK, DARK, DARK, WHITE, DARK, DARK, MID],
    [MID, DARK, DARK, DARK, DARK, DARK, DARK, MID],
    [MID, DARK, DARK, DARK, DARK, DARK, DARK, MID],
    [MID] * 8,
]

TILES = [TILE_BLANK, TILE_CLOUD, TILE_GROUND_TOP, TILE_GROUND_FILL, TILE_PLATFORM, TILE_DOOR]


def main():
    img = Image.new("RGB", (TILE * NUM_TILES, TILE))
    for tile_index, tile in enumerate(TILES):
        for y in range(TILE):
            for x in range(TILE):
                img.putpixel((tile_index * TILE + x, y), tile[y][x])

    out_path = "assets/tiles/pradera.png"
    img.save(out_path)
    print(f"Escrito {out_path} ({NUM_TILES} tiles de {TILE}x{TILE})")


if __name__ == "__main__":
    main()
