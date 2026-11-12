#!/usr/bin/env python3
"""Compila un mapa de nivel (formato de texto, F4.1/F4.2) a los datos de
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
  - La grilla: exactamente MT_ROWS líneas. El ancho (número de
    caracteres por línea) debe ser múltiplo de 16 -- cada bloque de 16
    columnas es "una pantalla" (F4.2): un nametable completo de VRAM.
  - 'S' es especial: además de usar su metatile de leyenda normalmente,
    marca esa celda como el punto de aparición del jugador (debe haber
    exactamente una 'S' en el mapa). Se calcula en píxeles de MUNDO como
    SPAWN_X = columna*16, SPAWN_Y = fila*16 + 8 -- alineado abajo/
    izquierda dentro de la celda de 16x16, para que el hitbox de 8x8
    del jugador (ver PLAYER_HITBOX_* en src/main.s) quede parado justo
    sobre la celda de abajo.

Metatile = (tile_tl, tile_tr, tile_bl, tile_br, paleta, colisión).
Colisión: 0=vacío, 1=sólido, 2=plataforma (un sentido), 3=peligro, 4=puerta,
5=punto de control, 6=interruptor, 7=puerta bloqueada, 8=meta de nivel.

F4.3 (puertas/habitaciones): una celda de colisión "puerta" no bloquea
el movimiento (igual que peligro, el jugador puede pisarla) pero
`update_player` la detecta aparte y dispara una transición de
habitación (ver `load_room` en src/main.s). El mapa NO lleva el destino
de la puerta -- con solo 2 habitaciones en este milestone, cada mapa
tiene una única puerta y su destino está hardcodeado en `load_room`
(limitación documentada, no un mapa genérico de puertas->destinos).

F4.2 (múltiples pantallas / scroll): un mapa de N*16 columnas se compila
a N bloques de 1024 bytes (960 de tiles + 64 de atributos cada uno, el
layout exacto de un nametable de VRAM) más UN SOLO mapa de colisión que
cubre el nivel completo (LEVEL_COLS x MT_ROWS, sin dividir por
pantalla -- la colisión vive en ROM accesible en cualquier momento, a
diferencia de los nametables en VRAM que solo caben 2 a la vez).

Límite de tamaño y compresión: cada pantalla compilada pesa 1024 bytes
de PRG-ROM (sin comprimir) más su porción del mapa de colisión (MT_ROWS
bytes por columna). Con 128 KB de PRG-ROM, caben decenas de pantallas
de este tamaño sin necesidad de comprimir nada. Si el contenido completo
(Fase 8) se acerca a ese límite, la compresión run-length (RLE) es la
técnica estándar de NES para esto -- no se implementa todavía porque no
hace falta.
"""

import argparse
import sys

T_BLANK, T_CLOUD, T_GROUND_TOP, T_GROUND_FILL, T_PLATFORM, T_DOOR, T_CHECKPOINT, T_SWITCH = range(8)

# Subpaletas de fondo (ver src/data/palettes.s): 0=cielo, 1=pradera,
# 2=tierra, 3=peligro.
PAL_SKY, PAL_PRADERA, PAL_TIERRA, PAL_PELIGRO = range(4)

COLLISION_EMPTY = 0
COLLISION_SOLID = 1
COLLISION_PLATFORM = 2
COLLISION_HAZARD = 3
COLLISION_DOOR = 4
COLLISION_CHECKPOINT = 5
COLLISION_SWITCH = 6
COLLISION_LOCKED_DOOR = 7
# Meta/salida de nivel (cierre del "Hito obligatorio" del nivel
# vertical, ver TASKS.md) -- ver COLLISION_GOAL en src/main.s.
COLLISION_GOAL = 8

METATILES = {
    "SKY": (T_BLANK, T_BLANK, T_BLANK, T_BLANK, PAL_SKY, COLLISION_EMPTY),
    "INDOOR": (T_BLANK, T_BLANK, T_BLANK, T_BLANK, PAL_TIERRA, COLLISION_EMPTY),
    "CLOUD": (T_CLOUD, T_CLOUD, T_CLOUD, T_CLOUD, PAL_SKY, COLLISION_EMPTY),
    "GROUND_TOP": (T_GROUND_TOP, T_GROUND_TOP, T_GROUND_FILL, T_GROUND_FILL, PAL_PRADERA, COLLISION_SOLID),
    "GROUND_FILL": (T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, PAL_PRADERA, COLLISION_SOLID),
    "PLATFORM": (T_PLATFORM, T_PLATFORM, T_BLANK, T_BLANK, PAL_SKY, COLLISION_PLATFORM),
    "WALL": (T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, PAL_TIERRA, COLLISION_SOLID),
    "HAZARD": (T_GROUND_TOP, T_GROUND_TOP, T_GROUND_FILL, T_GROUND_FILL, PAL_PELIGRO, COLLISION_HAZARD),
    "DOOR": (T_DOOR, T_DOOR, T_DOOR, T_DOOR, PAL_TIERRA, COLLISION_DOOR),
    "CHECKPOINT": (T_CHECKPOINT, T_CHECKPOINT, T_CHECKPOINT, T_CHECKPOINT, PAL_PRADERA, COLLISION_CHECKPOINT),
    "SWITCH": (T_SWITCH, T_SWITCH, T_SWITCH, T_SWITCH, PAL_TIERRA, COLLISION_SWITCH),
    # Reusa el tile visual de DOOR -- una puerta bloqueada se ve como una
    # puerta normal; lo que cambia es que no se puede atravesar hasta
    # activar el interruptor correspondiente (ver COLLISION_LOCKED_DOOR
    # en get_tile_collision, src/main.s).
    "LOCKED_DOOR": (T_DOOR, T_DOOR, T_DOOR, T_DOOR, PAL_TIERRA, COLLISION_LOCKED_DOOR),
    # Mismos tiles y paleta que WALL -- se ve exactamente igual a una
    # pared sólida, pero es atravesable. Esconde una zona secreta (F4.4).
    "SECRET_WALL": (T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, T_GROUND_FILL, PAL_TIERRA, COLLISION_EMPTY),
    # Reusa el tile de CHECKPOINT con la paleta de WALL/SWITCH (no la de
    # CHECKPOINT) -- se ve distinto de ambos sin necesitar arte nuevo.
    # Limitación real: sigue siendo un placeholder compartido, no un
    # tile de "meta" dedicado (ver TASKS.md).
    "GOAL": (T_CHECKPOINT, T_CHECKPOINT, T_CHECKPOINT, T_CHECKPOINT, PAL_TIERRA, COLLISION_GOAL),
}

SCREEN_COLS = 16   # ancho de una pantalla/nametable, en metatiles -- fijo, es hardware.
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

    width = len(grid_lines[0])
    if width == 0 or width % SCREEN_COLS != 0:
        raise ValueError(f"el ancho de la grilla ({width}) debe ser múltiplo de {SCREEN_COLS}")

    grid = []
    spawn = None
    for r, line in enumerate(grid_lines):
        if len(line) != width:
            raise ValueError(f"la fila {r} de la grilla tiene {len(line)} caracteres, se esperaban {width}: {line!r}")
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

    return grid, width, spawn


def compile_screen(grid, col_offset):
    """Compila las 16 columnas de grid empezando en col_offset a los
    960 bytes de tiles + 64 de atributos de una pantalla/nametable."""
    tile_bytes = [0] * (32 * 30)
    attr_bytes = [0] * 64

    for mr in range(MT_ROWS):
        for mc in range(SCREEN_COLS):
            tl, tr, bl, br, pal, _collision = METATILES[grid[mr][col_offset + mc]]
            base_row = mr * 2
            base_col = mc * 2
            tile_bytes[(base_row + 0) * 32 + base_col + 0] = tl
            tile_bytes[(base_row + 0) * 32 + base_col + 1] = tr
            tile_bytes[(base_row + 1) * 32 + base_col + 0] = bl
            tile_bytes[(base_row + 1) * 32 + base_col + 1] = br

            ar, ac = mr // 2, mc // 2
            quadrant = (mr % 2) * 2 + (mc % 2)  # 0=TL,1=TR,2=BL,3=BR
            attr_bytes[ar * 8 + ac] |= (pal & 0b11) << (quadrant * 2)

    return tile_bytes, attr_bytes


def compile_collision(grid, width):
    """Mapa de colisión del nivel completo (width x MT_ROWS), un byte
    por metatile, índice = fila*width + columna."""
    collision_bytes = [0] * (width * MT_ROWS)
    for mr in range(MT_ROWS):
        for mc in range(width):
            _tl, _tr, _bl, _br, _pal, collision = METATILES[grid[mr][mc]]
            collision_bytes[mr * width + mc] = collision
    return collision_bytes


def emit_ca65(screens, collision_bytes, width, spawn_x, spawn_y, out_path, label):
    def byte_rows(data, per_line=16):
        lines = []
        for i in range(0, len(data), per_line):
            chunk = data[i:i + per_line]
            lines.append("    .byte " + ", ".join(f"${b:02X}" for b in chunk))
        return lines

    num_screens = len(screens)
    upper = label.upper()
    lines = [
        "; Generado automáticamente por tools/map2scene.py.",
        "; No editar a mano -- los cambios se pierden en la siguiente compilación.",
        "; Editar el mapa fuente en assets/maps/ en su lugar.",
        "",
        f"{upper}_SPAWN_X = {spawn_x}",
        f"{upper}_SPAWN_Y = {spawn_y}",
        f"{upper}_LEVEL_SCREENS = {num_screens}",
        f"{upper}_LEVEL_COLS = {width}",
        "",
        '.segment "RODATA"',
        "",
        "; Tabla de punteros a cada pantalla (1024 bytes: 960 de tiles +",
        "; 64 de atributos, el layout exacto de un nametable de VRAM).",
        f"{label}_screen_ptrs:",
        "    .addr " + ", ".join(f"{label}_screen{i}" for i in range(num_screens)),
        "",
    ]
    for i, (tile_bytes, attr_bytes) in enumerate(screens):
        lines.append(f"{label}_screen{i}:")
        lines += byte_rows(tile_bytes)
        lines += byte_rows(attr_bytes)
        lines.append("")

    row_offsets = [r * width for r in range(MT_ROWS)]
    lines += [
        f"; Offset (de 16 bits) del inicio de cada fila dentro de",
        f"; {label}_collision = fila*{upper}_LEVEL_COLS. Tabla precalculada",
        "; en vez de multiplicar en tiempo de ejecución (el ancho no es",
        "; necesariamente potencia de 2, así que no hay truco de",
        "; enmascarar bits).",
        f"{label}_row_offset_lo:",
        "    .byte " + ", ".join(f"${o & 0xFF:02X}" for o in row_offsets),
        f"{label}_row_offset_hi:",
        "    .byte " + ", ".join(f"${(o >> 8) & 0xFF:02X}" for o in row_offsets),
        "",
    ]
    lines += [
        f"; Mapa de colisión del nivel completo ({upper}_LEVEL_COLS x MT_ROWS),",
        f"; 1 byte por metatile; índice = fila*{upper}_LEVEL_COLS + columna.",
        "; 0=vacío, 1=sólido, 2=plataforma (un sentido), 3=peligro, 4=puerta,",
        "; 5=punto de control, 6=interruptor, 7=puerta bloqueada, 8=meta.",
        f"{label}_collision:",
    ] + byte_rows(collision_bytes)

    with open(out_path, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    print(
        f"OK: {out_path} ({num_screens} pantallas x 1024 bytes, "
        f"{len(collision_bytes)} bytes de colisión, spawn=({spawn_x},{spawn_y}))"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("map_path")
    parser.add_argument("out_path")
    parser.add_argument(
        "--label", required=True,
        help="prefijo ca65 para los símbolos generados (p.ej. 'scene_pradera') -- "
             "necesario para que varios mapas coexistan en el mismo binario sin "
             "colisionar nombres de símbolo.",
    )
    args = parser.parse_args()

    try:
        grid, width, (spawn_x, spawn_y) = parse_map(args.map_path)
        num_screens = width // SCREEN_COLS
        screens = [compile_screen(grid, s * SCREEN_COLS) for s in range(num_screens)]
        for tile_bytes, attr_bytes in screens:
            assert len(tile_bytes) == 960
            assert len(attr_bytes) == 64
        collision_bytes = compile_collision(grid, width)
        assert len(collision_bytes) == width * MT_ROWS
        emit_ca65(screens, collision_bytes, width, spawn_x, spawn_y, args.out_path, args.label)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
