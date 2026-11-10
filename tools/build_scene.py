#!/usr/bin/env python3
"""Compila una escena de metatiles a los bytes de nametable + tabla de
atributos + mapa de colisión, listos para copiar a VRAM/usar en tiempo
de ejecución. Es la pieza "defina metatiles" de F2.2, extendida en F3.3
con un tipo de colisión por metatile.

Un metatile = 4 índices de tile (TL,TR,BL,BR, de 16x16px) + 1 índice de
subpaleta de fondo (0-3) + 1 tipo de colisión:
  0 = vacío (se puede atravesar)
  1 = sólido (bloquea en las 4 direcciones -- suelo, pared o techo según
      desde qué lado se le pegue; la lógica de qué lado es del código de
      colisión, no del tile)
  2 = plataforma de un solo sentido (bloquea solo cayendo desde arriba;
      se puede saltar a través desde abajo o los lados)
  3 = peligro (no bloquea el movimiento, pero tocarlo hace que Chiquito
      reaparezca en el punto de inicio -- placeholder de "daño" hasta que
      exista un sistema de vida real, Fase 5/6)

Esto NO es un sistema de mapas general (eso es F4.1): la disposición de
la escena está fija en este script, para una sola pantalla de prueba de
16x15 metatiles (= 32x30 tiles = un nametable completo). Un sistema real
de carga de niveles, con formato de mapa propio y herramienta de
conversión, es trabajo de Fase 4.

Salida: un .s de ca65 con tres tablas: 960 bytes de tiles, 64 de
atributos, y 240 (16x15) de colisión por metatile.
"""

import sys

# Tiles (ver tools/gen_test_tileset.py / assets/tiles/pradera.png):
T_BLANK, T_CLOUD, T_GROUND_TOP, T_GROUND_FILL, T_PLATFORM = range(5)

# Subpaletas de fondo (ver src/data/palettes.s): 0=cielo, 1=pradera,
# 2=tierra, 3=peligro (antes "sin usar").
PAL_SKY, PAL_PRADERA, PAL_TIERRA, PAL_PELIGRO = range(4)

COLLISION_EMPTY = 0
COLLISION_SOLID = 1
COLLISION_PLATFORM = 2
COLLISION_HAZARD = 3

# Metatile = (tile_tl, tile_tr, tile_bl, tile_br, paleta, colision)
METATILES = {
    "SKY": (T_BLANK, T_BLANK, T_BLANK, T_BLANK, PAL_SKY, COLLISION_EMPTY),
    "CLOUD": (T_CLOUD, T_CLOUD, T_CLOUD, T_CLOUD, PAL_SKY, COLLISION_EMPTY),
    "GROUND_TOP": (T_GROUND_TOP, T_GROUND_TOP, T_GROUND_FILL, T_GROUND_FILL, PAL_PRADERA, COLLISION_SOLID),
    "GROUND_FILL": (T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, PAL_PRADERA, COLLISION_SOLID),
    "PLATFORM": (T_PLATFORM, T_PLATFORM, T_BLANK, T_BLANK, PAL_SKY, COLLISION_PLATFORM),
    # Pared/techo: reutiliza el tile de relleno de tierra (mismo pipeline,
    # sin arte nuevo), con la paleta de tierra para distinguirse visualmente
    # de la superficie de pradera.
    "WALL": (T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, PAL_TIERRA, COLLISION_SOLID),
    # Peligro: reutiliza el tile de superficie (forma reconocible) con la
    # paleta de peligro (rojo), para que se distinga a simple vista sin
    # necesitar un tile de arte nuevo todavía.
    "HAZARD": (T_GROUND_TOP, T_GROUND_TOP, T_GROUND_FILL, T_GROUND_FILL, PAL_PELIGRO, COLLISION_HAZARD),
}

MT_COLS = 16
MT_ROWS = 15

# Punto de reaparición (en píxeles): parado exactamente sobre la
# superficie de GROUND_TOP en la fila de metatiles 10 (empieza en el
# píxel 160). Ver PLAYER_HITBOX_H en src/main.s (8px): 160 - 8 = 152.
# X=96 queda lejos de la pared de prueba (columna 1 = píxeles 16-31) en
# ambos ejes, para no aparecer encimado con ella.
SPAWN_X = 96
SPAWN_Y = 152


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

    # Pared de prueba (F3.3): columna sólida de 3 metatiles de alto,
    # apoyada sobre el suelo, cerca del borde izquierdo -- para probar
    # colisión horizontal caminando hacia la izquierda.
    grid[7][1] = "WALL"
    grid[8][1] = "WALL"
    grid[9][1] = "WALL"

    # Techo de prueba (F3.3): bloque sólido flotando sobre el punto de
    # aparición, lo bastante bajo para que un salto largo lo alcance --
    # para probar colisión vertical saltando hacia arriba.
    grid[7][6] = "WALL"
    grid[7][7] = "WALL"

    # Peligro de prueba (F3.3): una celda en la superficie, alcanzable
    # caminando hacia la derecha -- para probar la reaparición.
    grid[10][12] = "HAZARD"

    return grid


def compile_scene(grid):
    tile_bytes = [0] * (32 * 30)
    attr_bytes = [0] * 64
    collision_bytes = [0] * (MT_COLS * MT_ROWS)

    for mr in range(MT_ROWS):
        for mc in range(MT_COLS):
            tl, tr, bl, br, pal, collision = METATILES[grid[mr][mc]]
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

            collision_bytes[mr * MT_COLS + mc] = collision

    return tile_bytes, attr_bytes, collision_bytes


def emit_ca65(tile_bytes, attr_bytes, collision_bytes, out_path):
    def byte_rows(data, per_line=16):
        lines = []
        for i in range(0, len(data), per_line):
            chunk = data[i:i + per_line]
            lines.append("    .byte " + ", ".join(f"${b:02X}" for b in chunk))
        return lines

    lines = [
        "; Generado automáticamente por tools/build_scene.py.",
        "; No editar a mano -- los cambios se pierden en la siguiente compilación.",
        "; Escena de prueba de F2.2/F3.3: 16x15 metatiles (32x30 tiles, un",
        "; nametable completo) + mapa de colisión (1 byte por metatile).",
        "",
        f"SPAWN_X = {SPAWN_X}",
        f"SPAWN_Y = {SPAWN_Y}",
        "",
        '.segment "RODATA"',
        "",
        "scene_pradera_tiles:",
    ] + byte_rows(tile_bytes) + [
        "",
        "scene_pradera_attrs:",
    ] + byte_rows(attr_bytes) + [
        "",
        "; 1 byte por metatile (16 columnas x 15 filas); índice = fila*16 + columna.",
        "; 0=vacío, 1=sólido, 2=plataforma (un sentido), 3=peligro.",
        "scene_pradera_collision:",
    ] + byte_rows(collision_bytes)

    with open(out_path, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    print(
        f"OK: {out_path} ({len(tile_bytes)} bytes de tiles, {len(attr_bytes)} de "
        f"atributos, {len(collision_bytes)} de colisión)"
    )


def main():
    if len(sys.argv) != 2:
        print("uso: build_scene.py <salida.s>", file=sys.stderr)
        sys.exit(1)

    grid = build_scene_grid()
    tile_bytes, attr_bytes, collision_bytes = compile_scene(grid)
    assert len(tile_bytes) == 960
    assert len(attr_bytes) == 64
    assert len(collision_bytes) == MT_COLS * MT_ROWS
    emit_ca65(tile_bytes, attr_bytes, collision_bytes, sys.argv[1])


if __name__ == "__main__":
    main()
