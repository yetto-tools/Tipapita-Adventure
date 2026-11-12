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
    ;
    ; F5.1c: slots 0/3 con los valores REALES de
    ; assets/sprites/nes_referencias/chiquito*.json (palettes_nes), no
    ; inventados. Las 5 poses declaran las mismas 4 subpaletas y usan
    ; solo los índices 0/1/3 (el 2 no aparece en ninguna); 0 y 3
    ; comparten el mismo naranja intermedio y solo difieren en el tono
    ; claro ($38 crema vs $20 blanco) -- se fusionan en el slot 0 (el
    ; pelaje). El 1, la única paleta en escala de grises (el sombrero),
    ; queda en el slot 3. Qué tile usa cuál es POR TILE, no por mitad
    ; superior/inferior -- ver chiquito_pose_tables.s (generado por
    ; tools/gen_chiquito_poses.py) y draw_player_metasprite en main.s.
    .byte $0F, $0F, $27, $38   ; 0: Chiquito pelaje — contorno, contorno, naranja, crema
    .byte $0F, $06, $16, $26   ; 1: enemigo genérico (rojo oscuro, marrón-rojo, rosado)
    .byte $0F, $08, $18, $28   ; 2: objeto/ítem (oliva, amarillo, amarillo claro)
    .byte $0F, $0F, $00, $10   ; 3: Chiquito sombrero — contorno, contorno, gris oscuro, gris medio

; F5.1b: paleta de sprite para Sanchopau, superpuesta sobre los slots
; 1/2 (enemigo/ítem) mientras room_current es ROOM_CASA. Ahí el
; enemigo/ítem de prueba nunca se dibujan (solo existen en
; ROOM_PRADERA, ver load_room), así que esos dos slots quedan libres;
; se restauran a los valores de palette_table+21.. / +25.. de arriba al
; volver a pradera. Ver la escritura real en load_room (main.s).
;
; Valores tomados DIRECTO de assets/sprites/nes_referencias/sanchopau.json
; (palettes_nes), no inventados: ese archivo declara 4 subpaletas pero
; solo usa 3 de verdad (15 de los 16 tiles son variantes de gris/blanco
; -- paletas "0" [15,16,32] y "3" [15,0,32] del JSON, fusionadas aquí en
; una sola porque solo difieren en el tono de gris intermedio; el tile
; 14 -- el parche sobre un ojo -- usa la paleta "1" [15,39,32], con
; naranja, y es el único que va a la segunda subpaleta real. Ver
; sanchopau_tile_palette en main.s para qué tile usa cuál.
sanchopau_sprite_overlay:
    .byte $0F, $00, $20   ; superior (paletas 0+3 del JSON fusionadas): contorno, gris oscuro, blanco
    .byte $0F, $27, $20   ; inferior (paleta 1 del JSON, solo el tile del parche): contorno, naranja, blanco

; Qué subpaleta (0=superior, 1=inferior) usa cada uno de los 16 tiles de
; Sanchopau, tile por tile (igual criterio que Chiquito desde F5.1c, ver
; chiquito_pose_tables.s), porque el parche naranja (tile 14) cae en la
; misma fila que otros tiles grises. Copiado directo del campo
; "palette" de sanchopau.json (0 y 3 -> 0,
; 1 -> 1; la paleta "2" del JSON no se usa en ningún tile real). Ver
; draw_npc_metasprite en main.s, que indexa esto con el mismo índice de
; tile (ty*4+columna) que usa para elegir el gráfico.
sanchopau_tile_palette:
    .byte 0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 1, 0
