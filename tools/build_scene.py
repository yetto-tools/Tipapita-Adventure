#!/usr/bin/env python3
"""Compila una escena de metatiles a los bytes de nametable + tabla de
atributos listos para copiar a VRAM. Es la pieza "defina metatiles" de
F2.2: un metatile = 4 índices de tile (TL,TR,BL,BR, de 16x16px) + 1
índice de subpaleta de fondo (0-3).

Esto NO es un sistema de mapas general (eso es F4.1): la disposición de
la escena está fija en este script, para una sola pantalla de prueba de
16x15 metatiles (= 32x30 tiles = un nametable completo). Un sistema real
de carga de niveles, con formato de mapa propio y herramienta de
conversión, es trabajo de Fase 4.

Salida: un .s de ca65 con dos tablas de 960 y 64 bytes respectivamente,
listas para copiarse a $2000 y $23C0 con un simple bucle de copia (ver
ppu_copy_bulk en src/main.s).
"""

import sys

# Tiles (ver tools/gen_test_tileset.py / assets/tiles/pradera.png):
T_BLANK, T_CLOUD, T_GROUND_TOP, T_GROUND_FILL, T_PLATFORM = range(5)

# Subpaletas de fondo (ver src/data/palettes.s): 0=cielo, 1=pradera, 2=tierra.
PAL_SKY, PAL_PRADERA, PAL_TIERRA = range(3)

# Metatile = (tile_tl, tile_tr, tile_bl, tile_br, paleta)
METATILES = {
    "SKY": (T_BLANK, T_BLANK, T_BLANK, T_BLANK, PAL_SKY),
    "CLOUD": (T_CLOUD, T_CLOUD, T_CLOUD, T_CLOUD, PAL_SKY),
    "GROUND_TOP": (T_GROUND_TOP, T_GROUND_TOP, T_GROUND_FILL, T_GROUND_FILL, PAL_PRADERA),
    "GROUND_FILL": (T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, PAL_PRADERA),
    "PLATFORM": (T_PLATFORM, T_PLATFORM, T_BLANK, T_BLANK, PAL_SKY),
}

MT_COLS = 16
MT_ROWS = 15


def build_scene_grid():
    """Devuelve una grilla de MT_ROWS x MT_COLS con nombres de metatile."""
    grid = [["SKY"] * MT_COLS for _ in range(MT_ROWS)]

    # Superficie de pradera: fila de metatiles 10, y relleno de tierra
    # en las filas 11-14 (hasta el fondo del nametable).
    for col in range(MT_COLS):
        grid[10][col] = "GROUND_TOP"
    for row in range(11, MT_ROWS):
        for col in range(MT_COLS):
            grid[row][col] = "GROUND_FILL"

    # Decoración y plataforma de prueba, en el área de cielo.
    grid[2][5] = "CLOUD"
    grid[6][10] = "PLATFORM"

    return grid


def compile_scene(grid):
    tile_bytes = [0] * (32 * 30)
    attr_bytes = [0] * 64

    for mr in range(MT_ROWS):
        for mc in range(MT_COLS):
            tl, tr, bl, br, pal = METATILES[grid[mr][mc]]
            base_row = mr * 2
            base_col = mc * 2
            tile_bytes[(base_row + 0) * 32 + base_col + 0] = tl
            tile_bytes[(base_row + 0) * 32 + base_col + 1] = tr
            tile_bytes[(base_row + 1) * 32 + base_col + 0] = bl
            tile_bytes[(base_row + 1) * 32 + base_col + 1] = br

            # Cada byte de atributo cubre un bloque de 2x2 metatiles.
            ar, ac = mr // 2, mc // 2
            quadrant = (mr % 2) * 2 + (mc % 2)  # 0=TL,1=TR,2=BL,3=BR
            attr_bytes[ar * 8 + ac] |= (pal & 0b11) << (quadrant * 2)

    return tile_bytes, attr_bytes


def emit_ca65(tile_bytes, attr_bytes, out_path):
    def byte_rows(data, per_line=16):
        lines = []
        for i in range(0, len(data), per_line):
            chunk = data[i:i + per_line]
            lines.append("    .byte " + ", ".join(f"${b:02X}" for b in chunk))
        return lines

    lines = [
        "; Generado automáticamente por tools/build_scene.py.",
        "; No editar a mano -- los cambios se pierden en la siguiente compilación.",
        "; Escena de prueba de F2.2: 16x15 metatiles (32x30 tiles, un nametable completo).",
        "",
        '.segment "RODATA"',
        "",
        "scene_pradera_tiles:",
    ] + byte_rows(tile_bytes) + [
        "",
        "scene_pradera_attrs:",
    ] + byte_rows(attr_bytes)

    with open(out_path, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    print(f"OK: {out_path} ({len(tile_bytes)} bytes de tiles, {len(attr_bytes)} de atributos)")


def main():
    if len(sys.argv) != 2:
        print("uso: build_scene.py <salida.s>", file=sys.stderr)
        sys.exit(1)

    grid = build_scene_grid()
    tile_bytes, attr_bytes = compile_scene(grid)
    assert len(tile_bytes) == 960
    assert len(attr_bytes) == 64
    emit_ca65(tile_bytes, attr_bytes, sys.argv[1])


if __name__ == "__main__":
    main()
