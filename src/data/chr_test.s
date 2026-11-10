; Datos CHR de prueba — NO es arte final del juego (eso es F2.2/F2.3).
; Sirve únicamente para validar en pantalla real que las paletas de F2.1
; son legibles: el color índice 0 de una subpaleta de fondo es, en
; hardware, la misma celda física para las 4 subpaletas ($3F00 se
; comparte), así que una prueba de contraste necesita al menos un píxel
; con índice 1/2/3, que sí son independientes por subpaleta.

.segment "CHARS"
    ; Tile 0: en blanco (ambos planos en 0 -> índice de color 0 en todos los píxeles)
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    ; Tile 1: bloque sólido de índice de color 1 (plano bajo = $FF, plano alto = $00)
    .byte $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $00, $00, $00, $00, $00, $00, $00, $00
