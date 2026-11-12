# /// script
# requires-python = ">=3.11"
# ///
# ─── How to run ───
# uv run tools/chr2asm.py <entrada.chr> <salida.s> --label <nombre>
"""Envuelve un archivo .chr binario crudo (2bpp planar, 16 bytes por
tile, ya en el formato final de NES) en un .s de ca65 -- sin volver a
pasar por PNG ni por ningún remapeo de color. Usado para los sprites de
assets/sprites/nes_referencias/*.chr (conversión fiel desde el concept
art real, vía tools/convert_reference_sprites.py), que no deben
redibujarse a mano para integrarse al motor.
"""

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("chr_path", type=Path)
    parser.add_argument("out_path", type=Path)
    parser.add_argument("--label", required=True)
    args = parser.parse_args()

    data = args.chr_path.read_bytes()
    if len(data) % 16 != 0:
        raise SystemExit(f"ERROR: {args.chr_path} tiene {len(data)} bytes, no múltiplo de 16 (1 tile = 16 bytes)")
    num_tiles = len(data) // 16

    lines = [
        f"; Generado automáticamente por tools/chr2asm.py a partir de {args.chr_path}.",
        "; No editar a mano -- los cambios se pierden en la siguiente conversión.",
        f"; {num_tiles} tiles de 8x8, formato CHR planar (2bpp) de NES, copiados tal cual.",
        "",
        '.segment "CHARS"',
        f"{args.label}:",
    ]
    for tile in range(num_tiles):
        tile_bytes = data[tile * 16:tile * 16 + 16]
        byte_str = ", ".join(f"${b:02X}" for b in tile_bytes)
        lines.append(f"    .byte {byte_str}  ; tile {tile}")

    args.out_path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"OK: {args.out_path} ({num_tiles} tiles desde {args.chr_path})")


if __name__ == "__main__":
    main()
