; Chiquito y los Pipapitas — punto de entrada.
;
; F1.2 (reset e inicialización): secuencia estándar de arranque seguro de
; NES — pila, APU/PPU en estado conocido, limpieza de RAM, dos esperas de
; VBlank, paleta inicializada a negro. El renderizado y el NMI quedan
; deliberadamente desactivados: todavía no hay nametables ni manejador de
; NMI real (eso es F1.3). nmi/irq siguen siendo placeholders explícitos.

.segment "HEADER"
    .byte "NES", $1A       ; firma iNES
    .byte 8                 ; PRG-ROM: 8 bancos de 16 KB = 128 KB (ver ARCHITECTURE.md §9)
    .byte 16                ; CHR-ROM: 16 bancos de 8 KB = 128 KB
    ; Flags 6: nibble bajo del mapper (4 = MMC3) en bits 4-7, bit 0 = mirroring.
    ; El bit de mirroring aquí es PROVISIONAL: este milestone no toca
    ; nametables, así que no tiene efecto todavía. Además, en MMC3 el
    ; registro de mirroring del propio mapper ($A000) manda en tiempo de
    ; ejecución una vez que el código lo programe. No tratar este bit como
    ; decisión final; confirmar con la documentación de NESdev al
    ; implementar scrolling (Fase 4).
    .byte $40
    .byte $00               ; Flags 7: nibble alto del mapper = 0, iNES 1.0 (no NES 2.0)
    .byte $00               ; PRG-RAM: no se usa todavía
    .byte $00               ; TV system: 0 = NTSC (ver decisión F0.2)
    .byte $00               ; reservado
    .byte $00, $00, $00, $00, $00 ; relleno obligatorio iNES (bytes 11-15)

.segment "VECTORS"
    .addr nmi
    .addr reset
    .addr irq

.segment "STARTUP"

.proc reset
    sei                     ; ignorar IRQs mientras se inicializa
    cld                     ; el 2A03 no tiene modo decimal; se limpia por convención

    ldx #$40
    stx $4017               ; desactiva el IRQ de frame de la APU

    ldx #$ff
    txs                     ; inicializa el puntero de pila en $01FF

    inx                     ; x = 0 (desbordó de $FF a $00)
    stx $2000               ; PPUCTRL=0: NMI desactivado
    stx $2001               ; PPUMASK=0: fondo y sprites desactivados
    stx $4010               ; desactiva el IRQ del canal DMC

    ; Primer VBlank: garantiza que la PPU ya terminó su encendido antes de
    ; tocarla (secuencia estándar de arranque de NES).
@vblankwait1:
    bit $2002
    bpl @vblankwait1

    ; Limpia las 2 KB de RAM interna ($0000-$07FF) a cero.
    txa                     ; a = 0
@clearmem:
    sta $0000,x
    sta $0100,x
    sta $0200,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne @clearmem

    ; Segundo VBlank: la PPU ya está estable para recibir escrituras seguras.
@vblankwait2:
    bit $2002
    bpl @vblankwait2

    ; Inicializa toda la paleta (32 bytes: fondo + sprites) a negro ($0F),
    ; para que el color mostrado no sea un valor indefinido de encendido.
    ; Se escribe de forma directa (todavía no hay cola de PPU) porque el
    ; renderizado sigue desactivado: mientras $2001 tenga fondo y sprites
    ; apagados, escribir VRAM fuera de VBlank es seguro — la PPU no está
    ; leyendo esa memoria para dibujar.
    bit $2002               ; reinicia el latch de dirección de $2006/$2007
    lda #$3F
    sta $2006
    lda #$00
    sta $2006
    ldx #$20                ; 32 bytes de paleta
@clearpalette:
    lda #$0F                ; negro
    sta $2007
    dex
    bne @clearpalette

    ; Reinicia el latch de scroll/dirección para dejar la PPU en un estado
    ; conocido. El renderizado y el NMI permanecen desactivados a propósito:
    ; todavía no hay nametables ni manejador de NMI real (eso es F1.3).
    bit $2002
    lda #$00
    sta $2005
    sta $2005

mainloop:
    jmp mainloop
.endproc

.proc nmi
    rti                     ; placeholder: NMI sigue desactivado en $2000 (F1.3)
.endproc

.proc irq
    rti                     ; placeholder: sin IRQ de mapper programado todavía
.endproc
