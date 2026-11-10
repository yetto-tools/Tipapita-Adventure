#!/usr/bin/env python3
"""Compila un mapa de nivel (formato de texto, F4.1) a los bytes de
nametable + atributos + mapa de colisión + punto de aparición, listos
para copiar a VRAM/usar en tiempo de ejecución.

Reemplaza a tools/build_scene.py (F2.2/F3.3/F3.4): la disposición de la
escena ya NO está escrita en este script -- viene de un archivo de mapa
externo real (assets/maps/*.txt), editable sin tocar Python.

Formato del archivo de mapa:
  - Líneas que empiezan con '#' son comentarios; se ignoran.
  - Líneas "caracter=NOMBRE_DE_METATILE" (antes de la grilla) definen la
    leyenda: qué metatile representa cada carácter. METATILES más abajo
    lista los nombres válidos.
  - Una línea en blanco separa la leyenda de la grilla.
  - La grilla: exactamente MT_ROWS líneas de MT_COLS caracteres.
  - 'S' es especial: además de usar su metatile de leyenda normalmente,
    marca esa celda como el punto de aparición del jugador (debe haber
    exactamente una 'S' en el mapa). Se calcula en píxeles como
    SPAWN_X = columna*16, SPAWN_Y = fila*16 + 8 -- alineado abajo/
    izquierda dentro de la celda de 16x16, para que el hitbox de 8x8
    del jugador (ver PLAYER_HITBOX_* en src/main.s) quede parado justo
    sobre la celda de abajo.

Metatile = (tile_tl, tile_tr, tile_bl, tile_br, paleta, colisión).
Colisión: 0=vacío, 1=sólido, 2=plataforma (un sentido), 3=peligro.

Límite de tamaño y compresión (F4.1): un mapa = una pantalla completa
de 16x15 metatiles = un nametable (32x30 tiles). Sin compresión: cada
mapa compilado pesa 960+64+240=1264 bytes de PRG-ROM. Con 128 KB de
PRG-ROM totales, caben ~100 mapas de este tamaño sin necesidad de
comprimir nada. Si el contenido completo (Fase 8) se acerca a ese
límite, la compresión run-length (RLE) es la técnica estándar de NES
para esto -- no se implementa todavía porque no hace falta. Mapas más
grandes que una pantalla (scroll entre pantallas, carga progresiva) son
trabajo de F4.2/F4.3, no de este formato todavía.
"""

import sys

T_BLANK, T_CLOUD, T_GROUND_TOP, T_GROUND_FILL, T_PLATFORM = range(5)

# Subpaletas de fondo (ver src/data/palettes.s): 0=cielo, 1=pradera,
# 2=tierra, 3=peligro.
PAL_SKY, PAL_PRADERA, PAL_TIERRA, PAL_PELIGRO = range(4)

COLLISION_EMPTY = 0
COLLISION_SOLID = 1
COLLISION_PLATFORM = 2
COLLISION_HAZARD = 3

METATILES = {
    "SKY": (T_BLANK, T_BLANK, T_BLANK, T_BLANK, PAL_SKY, COLLISION_EMPTY),
    "CLOUD": (T_CLOUD, T_CLOUD, T_CLOUD, T_CLOUD, PAL_SKY, COLLISION_EMPTY),
    "GROUND_TOP": (T_GROUND_TOP, T_GROUND_TOP, T_GROUND_FILL, T_GROUND_FILL, PAL_PRADERA, COLLISION_SOLID),
    "GROUND_FILL": (T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, PAL_PRADERA, COLLISION_SOLID),
    "PLATFORM": (T_PLATFORM, T_PLATFORM, T_BLANK, T_BLANK, PAL_SKY, COLLISION_PLATFORM),
    "WALL": (T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, PAL_TIERRA, COLLISION_SOLID),
    "HAZARD": (T_GROUND_TOP, T_GROUND_TOP, T_GROUND_FILL, T_GROUND_FILL, PAL_PELIGRO, COLLISION_HAZARD),
}

MT_COLS = 16
MT_ROWS = 15


def parse_map(path):
    with open(path, encoding="utf-8") as f:
        lines = [line.rstrip("\n") for line in f]

    legend = {}
    i = 0
    while i < len(lines):
        line = lines[i]
        i += 1
        if line.strip() == "":
            break
        if line.startswith("#"):
            continue
        if "=" not in line:
            raise ValueError(f"línea de leyenda inválida (falta '='): {line!r}")
        ch, name = line.split("=", 1)
        ch, name = ch.strip(), name.strip()
        if len(ch) != 1:
            raise ValueError(f"la leyenda debe tener un solo carácter antes de '=': {line!r}")
        if name not in METATILES:
            raise ValueError(f"metatile desconocido en la leyenda: {name!r} (válidos: {sorted(METATILES)})")
        legend[ch] = name

    grid_lines = [line for line in lines[i:] if line.strip() != "" and not line.startswith("#")]
    if len(grid_lines) != MT_ROWS:
        raise ValueError(f"se esperaban {MT_ROWS} filas de grilla, se encontraron {len(grid_lines)}")

    grid = []
    spawn = None
    for r, line in enumerate(grid_lines):
        if len(line) != MT_COLS:
            raise ValueError(f"la fila {r} de la grilla tiene {len(line)} caracteres, se esperaban {MT_COLS}: {line!r}")
        row = []
        for c, ch in enumerate(line):
            if ch not in legend:
                raise ValueError(f"carácter '{ch}' sin definir en la leyenda (fila {r}, columna {c})")
            row.append(legend[ch])
            if ch == "S":
                if spawn is not None:
                    raise ValueError("más de un punto de aparición ('S') en el mapa; debe haber exactamente uno")
                spawn = (c * 16, r * 16 + 8)
        grid.append(row)

    if spawn is None:
        raise ValueError("el mapa no tiene punto de aparición ('S'); debe haber exactamente uno")

    return grid, spawn


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


def emit_ca65(tile_bytes, attr_bytes, collision_bytes, spawn_x, spawn_y, out_path):
    def byte_rows(data, per_line=16):
        lines = []
        for i in range(0, len(data), per_line):
            chunk = data[i:i + per_line]
            lines.append("    .byte " + ", ".join(f"${b:02X}" for b in chunk))
        return lines

    lines = [
        "; Generado automáticamente por tools/map2scene.py.",
        "; No editar a mano -- los cambios se pierden en la siguiente compilación.",
        "; Editar el mapa fuente en assets/maps/ en su lugar.",
        "",
        f"SPAWN_X = {spawn_x}",
        f"SPAWN_Y = {spawn_y}",
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
        f"atributos, {len(collision_bytes)} de colisión, spawn=({spawn_x},{spawn_y}))"
    )


def main():
    if len(sys.argv) != 3:
        print("uso: map2scene.py <mapa.txt> <salida.s>", file=sys.stderr)
        sys.exit(1)

    map_path, out_path = sys.argv[1], sys.argv[2]
    try:
        grid, (spawn_x, spawn_y) = parse_map(map_path)
        tile_bytes, attr_bytes, collision_bytes = compile_scene(grid)
        assert len(tile_bytes) == 960
        assert len(attr_bytes) == 64
        assert len(collision_bytes) == MT_COLS * MT_ROWS
        emit_ca65(tile_bytes, attr_bytes, collision_bytes, spawn_x, spawn_y, out_path)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
