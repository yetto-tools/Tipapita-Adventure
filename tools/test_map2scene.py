#!/usr/bin/env python3
"""Prueba de humo para F4.1/F4.2 (sistema de mapas + multi-pantalla) --
a nivel de herramienta de conversión, no de ROM (map2scene.py es una
herramienta de tiempo de build, no algo que corra en el NES; se prueba
con Python directo, igual que png2chr.py se probó generando y
convirtiendo un PNG de prueba).

Verifica:
  1. El mapa real (assets/maps/pradera.txt, ahora 3 pantallas de ancho
     desde F4.2) se parsea con el spawn y celdas de colisión esperadas
     en cada una de las 3 pantallas.
  2. Un mapa DISTINTO (generado aquí, de una sola pantalla, con otra
     disposición y otro punto de aparición) se convierte correctamente
     -- prueba que el conversor es genérico, no que solo "funciona con
     el mapa que ya teníamos".
  3. Casos de error (columnas de más/menos, ancho no múltiplo de 16, sin
     punto de aparición, dos puntos de aparición, carácter sin definir)
     fallan con un mensaje claro, no silenciosamente ni con una
     excepción genérica.
"""

import sys
import tempfile
import os

sys.path.insert(0, os.path.dirname(__file__))
import map2scene as m2s  # noqa: E402

FAILURES = []


def check(name, condition):
    status = "OK" if condition else "FALLO"
    print(f"[{status}] {name}")
    if not condition:
        FAILURES.append(name)


def expect_error(name, path):
    try:
        m2s.parse_map(path)
        check(name, False)
    except ValueError:
        check(name, True)


def write_map(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def main():
    # 1) Mapa real del proyecto: 3 pantallas (48 columnas).
    grid, width, (spawn_x, spawn_y) = m2s.parse_map("assets/maps/pradera.txt")
    check("pradera.txt: ancho = 48 (3 pantallas)", width == 48)
    check("pradera.txt: spawn = (96,152)", (spawn_x, spawn_y) == (96, 152))
    check("pradera.txt: grid[9][1] == WALL (pantalla 0)", grid[9][1] == "WALL")
    check("pradera.txt: grid[10][12] == HAZARD (pantalla 0)", grid[10][12] == "HAZARD")
    check("pradera.txt: grid[7][24] == WALL (pantalla 1, nueva)", grid[7][24] == "WALL")
    check("pradera.txt: grid[6][28] == PLATFORM (pantalla 1, nueva)", grid[6][28] == "PLATFORM")
    check("pradera.txt: grid[10][40] == HAZARD (pantalla 2, nueva)", grid[10][40] == "HAZARD")
    check("pradera.txt: grid[2][44] == CLOUD (pantalla 2, nueva)", grid[2][44] == "CLOUD")

    num_screens = width // m2s.SCREEN_COLS
    check("pradera.txt: 3 pantallas calculadas", num_screens == 3)
    screens = [m2s.compile_screen(grid, s * m2s.SCREEN_COLS) for s in range(num_screens)]
    for i, (tile_bytes, attr_bytes) in enumerate(screens):
        check(f"pantalla {i}: 960 bytes de tiles", len(tile_bytes) == 960)
        check(f"pantalla {i}: 64 bytes de atributos", len(attr_bytes) == 64)

    collision_bytes = m2s.compile_collision(grid, width)
    check("pradera.txt: 720 bytes de colisión (48x15)", len(collision_bytes) == 720)
    check(
        "pradera.txt: colisión[10*48+12] == HAZARD (pantalla 0)",
        collision_bytes[10 * width + 12] == m2s.COLLISION_HAZARD,
    )
    check(
        "pradera.txt: colisión[9*48+1] == SOLID (pared pantalla 0)",
        collision_bytes[9 * width + 1] == m2s.COLLISION_SOLID,
    )
    check(
        "pradera.txt: colisión[7*48+24] == SOLID (pared nueva, pantalla 1)",
        collision_bytes[7 * width + 24] == m2s.COLLISION_SOLID,
    )
    check(
        "pradera.txt: colisión[10*48+40] == HAZARD (peligro nuevo, pantalla 2)",
        collision_bytes[10 * width + 40] == m2s.COLLISION_HAZARD,
    )

    with tempfile.TemporaryDirectory() as tmp:
        # 2) Mapa DISTINTO: una sola pantalla, todo sólido abajo, un
        #    peligro a la izquierda en vez de a la derecha, y el spawn
        #    en una esquina distinta.
        alt_path = os.path.join(tmp, "alt.txt")
        alt_rows = ["." * m2s.SCREEN_COLS for _ in range(m2s.MT_ROWS)]
        alt_rows[0] = "S" + "." * (m2s.SCREEN_COLS - 1)
        alt_rows[m2s.MT_ROWS - 1] = "H" + "F" * (m2s.SCREEN_COLS - 1)
        write_map(
            alt_path,
            ".=SKY\nS=SKY\nF=GROUND_FILL\nH=HAZARD\n\n" + "\n".join(alt_rows) + "\n",
        )
        alt_grid, alt_width, (alt_sx, alt_sy) = m2s.parse_map(alt_path)
        check("mapa alterno: ancho = 16 (1 pantalla)", alt_width == 16)
        check("mapa alterno: spawn = (0,8) (fila 0, columna 0)", (alt_sx, alt_sy) == (0, 8))
        alt_collision = m2s.compile_collision(alt_grid, alt_width)
        check(
            "mapa alterno: colisión[14*16+0] == HAZARD (distinto del mapa real)",
            alt_collision[(m2s.MT_ROWS - 1) * alt_width + 0] == m2s.COLLISION_HAZARD,
        )
        check(
            "mapa alterno: colisión[14*16+1] == SOLID",
            alt_collision[(m2s.MT_ROWS - 1) * alt_width + 1] == m2s.COLLISION_SOLID,
        )

        # 3) Casos de error.
        bad_cols = os.path.join(tmp, "bad_cols.txt")
        rows = ["." * m2s.SCREEN_COLS for _ in range(m2s.MT_ROWS)]
        rows[0] = "S" + "." * (m2s.SCREEN_COLS - 1)
        rows[5] = "." * (m2s.SCREEN_COLS - 1)  # una columna de menos
        write_map(bad_cols, ".=SKY\nS=SKY\n\n" + "\n".join(rows) + "\n")
        expect_error("error: fila con columnas de menos", bad_cols)

        bad_width = os.path.join(tmp, "bad_width.txt")
        rows = ["." * 20 for _ in range(m2s.MT_ROWS)]  # 20 no es múltiplo de 16
        rows[0] = "S" + "." * 19
        write_map(bad_width, ".=SKY\nS=SKY\n\n" + "\n".join(rows) + "\n")
        expect_error("error: ancho no múltiplo de 16", bad_width)

        no_spawn = os.path.join(tmp, "no_spawn.txt")
        rows = ["." * m2s.SCREEN_COLS for _ in range(m2s.MT_ROWS)]
        write_map(no_spawn, ".=SKY\n\n" + "\n".join(rows) + "\n")
        expect_error("error: mapa sin punto de aparición", no_spawn)

        two_spawn = os.path.join(tmp, "two_spawn.txt")
        rows = ["." * m2s.SCREEN_COLS for _ in range(m2s.MT_ROWS)]
        rows[0] = "S" + "." * (m2s.SCREEN_COLS - 1)
        rows[1] = "S" + "." * (m2s.SCREEN_COLS - 1)
        write_map(two_spawn, ".=SKY\nS=SKY\n\n" + "\n".join(rows) + "\n")
        expect_error("error: dos puntos de aparición", two_spawn)

        bad_char = os.path.join(tmp, "bad_char.txt")
        rows = ["." * m2s.SCREEN_COLS for _ in range(m2s.MT_ROWS)]
        rows[0] = "S" + "X" * (m2s.SCREEN_COLS - 1)  # 'X' no está en la leyenda
        write_map(bad_char, ".=SKY\nS=SKY\n\n" + "\n".join(rows) + "\n")
        expect_error("error: carácter sin definir en la leyenda", bad_char)

    print()
    if FAILURES:
        print(f"RESULT=FAIL ({len(FAILURES)} fallos: {FAILURES})")
        sys.exit(1)
    print("RESULT=PASS")


if __name__ == "__main__":
    main()
