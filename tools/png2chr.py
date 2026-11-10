#!/usr/bin/env python3
"""Convierte una hoja de tiles PNG a datos CHR de NES (formato planar de
2 bits por píxel) y los emite como una fuente de ca65.

Formato esperado del PNG de entrada:
  - Una fila de tiles de 8x8 píxeles (ancho = 8 * N, alto = 8).
  - Cada píxel debe usar uno de, como máximo, 4 colores "marcador" fijos,
    los MISMOS para todo el PNG (no por tile). Esos 4 colores se mapean,
    en el orden dado, a los índices de color 0,1,2,3.
  - Por defecto los marcadores son una escala de grises (negro, gris
    oscuro, gris claro, blanco) -- ver --palette para usar otros.

    IMPORTANTE: el mapeo es GLOBAL, no por tile. Si se ordenara por color
    dentro de cada tile de forma independiente, un mismo color marcador
    (p. ej. "gris claro") podría terminar en índices distintos en tiles
    distintos, según qué otros colores tenga cada uno -- eso rompería
    cualquier convención de "índice 1 = tal color" entre tiles. Por ese
    motivo el mapeo se fija una sola vez para todo el archivo.

Salida: un archivo .s de ca65 con un `.segment "CHARS"` y, por cada tile,
16 bytes (8 del plano bajo + 8 del plano alto), en el orden de las
columnas del PNG de entrada.

Uso:
    png2chr.py <entrada.png> <salida.s> --label <nombre>
    png2chr.py <entrada.png> <salida.s> --label <nombre> --palette 000000,555555,aaaaaa,ffffff
"""

import argparse
import sys

from PIL import Image

TILE_SIZE = 8

DEFAULT_PALETTE = [(0, 0, 0), (85, 85, 85), (170, 170, 170), (255, 255, 255)]


def parse_palette(spec):
    colors = []
    for part in spec.split(","):
        part = part.strip().lstrip("#")
        if len(part) != 6:
            raise ValueError(f"color de paleta inválido: '{part}' (se espera RRGGBB en hex)")
        colors.append(tuple(int(part[i:i + 2], 16) for i in (0, 2, 4)))
    if not 1 <= len(colors) <= 4:
        raise ValueError(f"--palette debe tener entre 1 y 4 colores, llegaron {len(colors)}")
    return colors


def tile_to_chr_bytes(pixels, tile_x0, color_to_index):
    """Convierte un tile de 8x8 (en pixels, offset de columna tile_x0) a
    16 bytes CHR (plano bajo, luego plano alto), usando el mapeo fijo
    color_to_index (el mismo para todos los tiles del archivo)."""
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            c = pixels[tile_x0 + x, y]
            if c not in color_to_index:
                raise ValueError(
                    f"el tile en la columna {tile_x0 // TILE_SIZE}, píxel ({x},{y}) "
                    f"usa el color {c}, que no está en la paleta de marcadores {list(color_to_index)}"
                )

    low_plane = []
    high_plane = []
    for y in range(TILE_SIZE):
        low_byte = 0
        high_byte = 0
        for x in range(TILE_SIZE):
            c = pixels[tile_x0 + x, y]
            index = color_to_index[c]
            bit_pos = 7 - x
            if index & 0b01:
                low_byte |= 1 << bit_pos
            if index & 0b10:
                high_byte |= 1 << bit_pos
        low_plane.append(low_byte)
        high_plane.append(high_byte)

    return low_plane + high_plane


def convert(png_path, out_path, label, palette):
    img = Image.open(png_path).convert("RGB")
    width, height = img.size

    if height != TILE_SIZE:
        raise ValueError(f"se esperaba una imagen de {TILE_SIZE}px de alto, llegó {height}px")
    if width % TILE_SIZE != 0:
        raise ValueError(f"el ancho ({width}px) debe ser múltiplo de {TILE_SIZE}")

    num_tiles = width // TILE_SIZE
    pixels = img.load()
    color_to_index = {c: i for i, c in enumerate(palette)}

    lines = [
        f"; Generado automáticamente por tools/png2chr.py a partir de {png_path}.",
        "; No editar a mano -- los cambios se pierden en la siguiente conversión.",
        f"; {num_tiles} tiles de {TILE_SIZE}x{TILE_SIZE}, formato CHR planar (2bpp) de NES.",
        "; Mapeo de color -> índice (global, igual para todos los tiles):",
    ] + [
        f";   índice {i}: #{c[0]:02x}{c[1]:02x}{c[2]:02x}" for i, c in enumerate(palette)
    ] + [
        "",
        '.segment "CHARS"',
        f"{label}:",
    ]
    for i in range(num_tiles):
        tile_bytes = tile_to_chr_bytes(pixels, i * TILE_SIZE, color_to_index)
        byte_str = ", ".join(f"${b:02X}" for b in tile_bytes)
        lines.append(f"    .byte {byte_str}  ; tile {i}")

    with open(out_path, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    print(f"OK: {out_path} ({num_tiles} tiles desde {png_path})")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("png_path")
    parser.add_argument("out_path")
    parser.add_argument("--label", required=True, help="nombre del símbolo ca65 para el bloque de tiles")
    parser.add_argument(
        "--palette",
        default=None,
        help="hasta 4 colores RRGGBB separados por coma, en orden de índice 0-3 "
        "(por defecto: escala de grises negro,gris oscuro,gris claro,blanco)",
    )
    args = parser.parse_args()

    palette = parse_palette(args.palette) if args.palette else DEFAULT_PALETTE

    try:
        convert(args.png_path, args.out_path, args.label, palette)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
