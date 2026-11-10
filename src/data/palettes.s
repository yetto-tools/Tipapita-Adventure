; Datos de paleta y de atributos para la prueba de pradera (F2.1).
;
; Índices de color elegidos por referencia a la paleta estándar del PPU
; 2C02 (documentada en NESdev), siguiendo convenciones muy usadas en la
; comunidad homebrew (p. ej. $0F como negro seguro, $22 como azul cielo).
; No se asumen como correctas solo por estar escritas aquí: se verifican
; renderizando esta ROM y leyendo los píxeles resultantes (ver
; tools/test_palette.lua y el registro de la tarea en TASKS.md).

.segment "RODATA"

palette_table:
    ; Fondo (4 subpaletas x 4 bytes). IMPORTANTE (confirmado leyendo VRAM
    ; en FCEUX, no solo por documentación): en hardware real, el color
    ; índice 0 de TODAS las subpaletas de fondo ($3F00/$3F04/$3F08/$3F0C)
    ; es la MISMA celda física — no existe un "color 0" independiente por
    ; subpaleta. Por eso las 4 entradas de índice 0 valen lo mismo aquí;
    ; lo que de verdad distingue cada subpaleta son los índices 1/2/3.
    .byte $0F, $22, $20, $0F   ; 0: cielo — índice 1 = azul cielo, índice 2 = blanco
    .byte $0F, $29, $19, $17   ; 1: pradera — índice 1 = verde, índice 2 = verde claro, índice 3 = marrón
    .byte $0F, $17, $07, $09   ; 2: tierra/cueva — índice 1 = marrón, índice 2 = marrón oscuro, índice 3 = oliva
    .byte $0F, $16, $06, $26   ; 3: peligro (F3.3) — índice 1 = rojo-marrón, índice 2 = rojo oscuro, índice 3 = rosado

    ; Sprites (4 subpaletas x 4 bytes). El color 0 de cada subpaleta de
    ; sprite es transparente en el hardware sin importar su valor; se deja
    ; en $0F por convención.
    .byte $0F, $27, $16, $0F   ; 0: jugador (tan, marrón, negro) — provisional
    .byte $0F, $06, $16, $26   ; 1: enemigo genérico (rojo oscuro, marrón-rojo, rosado)
    .byte $0F, $08, $18, $28   ; 2: objeto/ítem (oliva, amarillo, amarillo claro)
    .byte $0F, $0F, $0F, $0F   ; 3: sin usar todavía
