#!/usr/bin/env python3
"""Prueba de humo para F4.1 (sistema de mapas) -- a nivel de herramienta
de conversión, no de ROM (map2scene.py es una herramienta de tiempo de
build, no algo que corra en el NES; se prueba con Python directo, igual
que png2chr.py se probó generando y convirtiendo un PNG de prueba).

Verifica:
  1. El mapa real (assets/maps/pradera.txt) se parsea con el spawn y
     algunas celdas de colisión esperadas.
  2. Un mapa DISTINTO (generado aquí, con otra disposición y otro punto
     de aparición) se convierte correctamente -- prueba que el
     conversor es genérico, no que solo "funciona con el mapa que ya
     teníamos".
  3. Casos de error (columnas de más/menos, sin punto de aparición, dos
     puntos de aparición, carácter sin definir) fallan con un mensaje
     claro, no silenciosamente ni con una excepción genérica.
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
    # 1) Mapa real del proyecto.
    grid, (spawn_x, spawn_y) = m2s.parse_map("assets/maps/pradera.txt")
    check("pradera.txt: spawn = (96,152)", (spawn_x, spawn_y) == (96, 152))
    check("pradera.txt: grid[9][1] == WALL", grid[9][1] == "WALL")
    check("pradera.txt: grid[10][12] == HAZARD", grid[10][12] == "HAZARD")
    tile_bytes, attr_bytes, collision_bytes = m2s.compile_scene(grid)
    check("pradera.txt: 960 bytes de tiles", len(tile_bytes) == 960)
    check("pradera.txt: 64 bytes de atributos", len(attr_bytes) == 64)
    check("pradera.txt: 240 bytes de colisión", len(collision_bytes) == 240)
    check(
        "pradera.txt: colisión[10*16+12] == HAZARD (3)",
        collision_bytes[10 * 16 + 12] == m2s.COLLISION_HAZARD,
    )
    check(
        "pradera.txt: colisión[9*16+1] == SOLID (1) (la pared, no la celda de spawn)",
        collision_bytes[9 * 16 + 1] == m2s.COLLISION_SOLID,
    )

    with tempfile.TemporaryDirectory() as tmp:
        # 2) Mapa DISTINTO: todo sólido abajo, un peligro a la izquierda
        #    en vez de a la derecha, y el spawn en una esquina distinta.
        alt_path = os.path.join(tmp, "alt.txt")
        alt_rows = ["." * m2s.MT_COLS for _ in range(m2s.MT_ROWS)]
        alt_rows[0] = "S" + "." * (m2s.MT_COLS - 1)
        alt_rows[m2s.MT_ROWS - 1] = "H" + "F" * (m2s.MT_COLS - 1)
        write_map(
            alt_path,
            ".=SKY\nS=SKY\nF=GROUND_FILL\nH=HAZARD\n\n" + "\n".join(alt_rows) + "\n",
        )
        alt_grid, (alt_sx, alt_sy) = m2s.parse_map(alt_path)
        check("mapa alterno: spawn = (0,8) (fila 0, columna 0)", (alt_sx, alt_sy) == (0, 8))
        _, _, alt_collision = m2s.compile_scene(alt_grid)
        check(
            "mapa alterno: colisión[14*16+0] == HAZARD (distinto del mapa real)",
            alt_collision[(m2s.MT_ROWS - 1) * m2s.MT_COLS + 0] == m2s.COLLISION_HAZARD,
        )
        check(
            "mapa alterno: colisión[14*16+1] == SOLID",
            alt_collision[(m2s.MT_ROWS - 1) * m2s.MT_COLS + 1] == m2s.COLLISION_SOLID,
        )

        # 3) Casos de error.
        bad_cols = os.path.join(tmp, "bad_cols.txt")
        rows = ["." * m2s.MT_COLS for _ in range(m2s.MT_ROWS)]
        rows[0] = "S" + "." * (m2s.MT_COLS - 1)
        rows[5] = "." * (m2s.MT_COLS - 1)  # una columna de menos
        write_map(bad_cols, ".=SKY\nS=SKY\n\n" + "\n".join(rows) + "\n")
        expect_error("error: fila con columnas de menos", bad_cols)

        no_spawn = os.path.join(tmp, "no_spawn.txt")
        rows = ["." * m2s.MT_COLS for _ in range(m2s.MT_ROWS)]
        write_map(no_spawn, ".=SKY\n\n" + "\n".join(rows) + "\n")
        expect_error("error: mapa sin punto de aparición", no_spawn)

        two_spawn = os.path.join(tmp, "two_spawn.txt")
        rows = ["." * m2s.MT_COLS for _ in range(m2s.MT_ROWS)]
        rows[0] = "S" + "." * (m2s.MT_COLS - 1)
        rows[1] = "S" + "." * (m2s.MT_COLS - 1)
        write_map(two_spawn, ".=SKY\nS=SKY\n\n" + "\n".join(rows) + "\n")
        expect_error("error: dos puntos de aparición", two_spawn)

        bad_char = os.path.join(tmp, "bad_char.txt")
        rows = ["." * m2s.MT_COLS for _ in range(m2s.MT_ROWS)]
        rows[0] = "S" + "X" * (m2s.MT_COLS - 1)  # 'X' no está en la leyenda
        write_map(bad_char, ".=SKY\nS=SKY\n\n" + "\n".join(rows) + "\n")
        expect_error("error: carácter sin definir en la leyenda", bad_char)

    print()
    if FAILURES:
        print(f"RESULT=FAIL ({len(FAILURES)} fallos: {FAILURES})")
        sys.exit(1)
    print("RESULT=PASS")


if __name__ == "__main__":
    main()
