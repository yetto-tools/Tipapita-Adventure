#!/usr/bin/env python3
"""Valida que una ROM .nes tenga el header y tamaño esperados para este proyecto.

Uso: validate_rom.py <archivo.nes>
"""

import sys

EXPECTED_PRG_16KB_UNITS = 8   # 128 KB (decidido en F0.2)
EXPECTED_CHR_8KB_UNITS = 16   # 128 KB (decidido en F0.2)
EXPECTED_MAPPER = 4            # MMC3 (decidido en F0.2)
EXPECTED_SIZE = 16 + EXPECTED_PRG_16KB_UNITS * 16384 + EXPECTED_CHR_8KB_UNITS * 8192


def validate(path):
    with open(path, "rb") as f:
        data = f.read()

    if data[0:4] != b"NES\x1a":
        raise AssertionError(f"firma iNES inválida: {data[0:4]!r}")

    prg_units = data[4]
    chr_units = data[5]
    mapper = (data[6] >> 4) | (data[7] & 0xF0)

    if prg_units != EXPECTED_PRG_16KB_UNITS:
        raise AssertionError(
            f"PRG-ROM esperado {EXPECTED_PRG_16KB_UNITS} bancos de 16KB, encontrado {prg_units}"
        )
    if chr_units != EXPECTED_CHR_8KB_UNITS:
        raise AssertionError(
            f"CHR-ROM esperado {EXPECTED_CHR_8KB_UNITS} bancos de 8KB, encontrado {chr_units}"
        )
    if mapper != EXPECTED_MAPPER:
        raise AssertionError(f"mapper esperado {EXPECTED_MAPPER} (MMC3), encontrado {mapper}")
    if len(data) != EXPECTED_SIZE:
        raise AssertionError(f"tamaño de archivo esperado {EXPECTED_SIZE} bytes, encontrado {len(data)}")

    print(
        f"OK: {path} - iNES valido, mapper {mapper}, "
        f"PRG {prg_units * 16}KB, CHR {chr_units * 8}KB, tamano {len(data)} bytes"
    )


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("uso: validate_rom.py <archivo.nes>", file=sys.stderr)
        sys.exit(1)
    try:
        validate(sys.argv[1])
    except AssertionError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
