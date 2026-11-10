; Tipapita Adventure — punto de entrada.
;
; F1.3 (NMI/IRQ): el NMI real tiene responsabilidades fijas, en este
; orden, documentado aquí porque es la única fuente de verdad sobre qué
; hace el NMI cada frame:
;   1) OAM DMA: copia el buffer de sombra de sprites ($0200-$02FF) al OAM
;      real de la PPU. Va primero porque es lo más urgente en VBlank.
;   2) Vacía la cola de actualizaciones de PPU (si hay algo encolado).
;   3) Marca `frame_ready` y avanza `frame_count`, para sincronizar al
;      main loop con la tasa real de refresco (60 Hz NTSC).
; Todavía NO se escriben registros de scroll (no hay cámara, Fase 4) ni se
; implementa IRQ de mapper (no hay HUD con split-screen todavía).
;
; F2.1 (paletas): el reset ahora carga paletas reales de pradera
; (cielo/pradera/tierra) y de sprite (jugador/enemigo/ítem) desde
; src/data/palettes.s, limpia el nametable 0 y pinta su tabla de
; atributos en 3 bandas para hacer visibles esas subpaletas sin
; necesitar tiles de arte todavía (el CHR-ROM sigue en blanco — eso es
; F2.2/F2.3). El renderizado de fondo se enciende por primera vez; los
; sprites siguen apagados (sin contenido de OAM real todavía).

.include "data/palettes.s"
.include "data/chr_test.s"

.segment "RODATA"
; R0,R1: ventanas CHR de 2KB -> banco 0. R2-R5: ventanas CHR de 1KB -> banco 0.
; Así $0000-$1FFF completo apunta al principio de CHR-ROM, donde está
; chr_test.s. R6,R7: ventanas PRG swappeables de 8KB ($8000-$9FFF y
; $A000-$BFFF) -> bancos 0 y 1. Todavía no hay código ni datos ahí
; (nuestro código vive en el banco fijo $E000-$FFFF), son solo valores
; conocidos para no dejar el mapper en un estado indefinido.
mmc3_init_values:
    .byte $00, $00, $00, $00, $00, $00, $00, $01

PPU_QUEUE_CAPACITY = 32
; Presupuesto de VBlank (estimado, NTSC ~2273 ciclos de CPU disponibles):
;   OAM DMA:            ~514 ciclos (fijo, impuesto por el hardware)
;   guardar/restaurar:  ~30 ciclos
;   flush de la cola:   ~31 ciclos/entrada x 32 = ~992 ciclos (peor caso)
;   contador+bandera:   ~15 ciclos
;   total peor caso:    ~1551 ciclos, dentro del presupuesto con margen.
; Esta es una estimación por cálculo de ciclos documentados del 6502/NES,
; no una medición real con el profiler de Mesen2 — pendiente de verificar
; ahí cuando haya contenido real que llene la cola (ver TASKS.md F1.3).

.segment "ZEROPAGE"
frame_ready: .res 1   ; 1 cuando el NMI ya corrió este frame (handshake con el main loop)
frame_count: .res 1   ; contador de frames, para timing futuro
pq_addr_hi:  .res 1   ; argumento de ppu_queue_push: byte alto de la dirección PPU
pq_addr_lo:  .res 1   ; argumento de ppu_queue_push: byte bajo de la dirección PPU
pq_data:     .res 1   ; argumento de ppu_queue_push: byte a escribir

.segment "BSS"
ppu_queue_len:       .res 1
ppu_queue_overflow:  .res 1                      ; contador de escrituras descartadas por cola llena
ppu_queue_addr_hi:   .res PPU_QUEUE_CAPACITY
ppu_queue_addr_lo:   .res PPU_QUEUE_CAPACITY
ppu_queue_data:      .res PPU_QUEUE_CAPACITY

.segment "OAM"
oam_buffer: .res 256  ; página $0200-$02FF, fuente de la OAM DMA ($4014)

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

    ; Inicializa el mapper MMC3: fija las 6 ventanas de CHR (R0-R5) al
    ; banco físico 0 y las 2 ventanas swappeables de PRG (R6-R7) a bancos
    ; conocidos. A diferencia de $E000-$FFFF (fijo por hardware), TODO el
    ; espacio de CHR depende de estos registros, que NO tienen un valor
    ; por defecto garantizado al encender. Se detectó este hueco al
    ; validar F2.1 en FCEUX: sin este paso, lo que la PPU mostraba no
    ; coincidía con los bytes de CHR-ROM realmente escritos en el
    ; archivo — ver registro de la tarea en TASKS.md.
@mmc3_init:
    stx $8000               ; selecciona registro R0..R7 (X = 0..7)
    lda mmc3_init_values,x
    sta $8001                ; banco físico para ese registro
    inx
    cpx #$08
    bne @mmc3_init

    ; Primer VBlank: garantiza que la PPU ya terminó su encendido antes de
    ; tocarla (secuencia estándar de arranque de NES).
@vblankwait1:
    bit $2002
    bpl @vblankwait1

    ; Limpia las 2 KB de RAM interna ($0000-$07FF) a cero, incluyendo el
    ; buffer de sombra de OAM ($0200-$02FF) y la cola de PPU.
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

    ; Carga las 32 paletas reales (fondo + sprites) desde palette_table.
    ; Se escribe de forma directa (no por la cola) porque el renderizado
    ; sigue desactivado: mientras $2001 tenga fondo y sprites apagados,
    ; escribir VRAM fuera de VBlank es seguro.
    bit $2002               ; reinicia el latch de dirección de $2006/$2007
    lda #$3F
    sta $2006
    lda #$00
    sta $2006
    ldx #$00
@copypalette:
    lda palette_table,x
    sta $2007
    inx
    cpx #32
    bne @copypalette

    ; Llena el nametable 0 completo (1024 bytes: 960 de tiles + 64 de
    ; atributos, estos últimos se sobrescriben abajo) con el tile 1 (el
    ; bloque sólido de chr_test.s). Así cada subpaleta de fondo muestra su
    ; índice de color 1, que sí es independiente por subpaleta (ver nota
    ; en palettes.s sobre por qué el índice 0 no sirve para esta prueba).
    bit $2002
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    lda #$01
    ldy #$04                ; 4 páginas de 256 bytes = 1024 bytes
@nt_clear_outer:
    ldx #$00
@nt_clear_inner:
    sta $2007
    inx
    bne @nt_clear_inner
    dey
    bne @nt_clear_outer

    ; Sobrescribe la tabla de atributos ($23C0-$23FF, 64 bytes) con las 3
    ; bandas de attr_table_pradera, para hacer visibles las subpaletas de
    ; fondo 0/1/2 (cielo/pradera/tierra) sin necesitar tiles reales.
    bit $2002
    lda #$23
    sta $2006
    lda #$C0
    sta $2006
    ldx #$00
@copyattr:
    lda attr_table_pradera,x
    sta $2007
    inx
    cpx #64
    bne @copyattr

    ; Reinicia el latch de scroll/dirección para dejar la PPU en un estado
    ; conocido.
    bit $2002
    lda #$00
    sta $2005
    sta $2005

    ; Habilita generación de NMI y el renderizado de fondo (F2.1: ya hay
    ; paleta y atributos reales que mostrar). Los sprites siguen apagados
    ; a propósito: no hay contenido de OAM real todavía (F2.3).
    lda #%10000000
    sta $2000
    lda #%00001010           ; PPUMASK: bit1 (fondo en los 8px izquierdos) + bit3 (mostrar fondo)
    sta $2001

mainloop:
    lda frame_ready
    beq mainloop            ; espera a que el NMI marque el frame como listo
    lda #$00
    sta frame_ready
    ; Aquí entrará la lógica de juego una vez por frame (Fase 3 en
    ; adelante). Todavía no hay ninguna.
    jmp mainloop
.endproc

.proc nmi
    pha
    txa
    pha
    tya
    pha

    ; 1) OAM DMA: copia oam_buffer ($0200-$02FF) al OAM real de la PPU.
    lda #$00
    sta $2003               ; OAMADDR = 0 antes de la DMA (práctica estándar)
    lda #$02
    sta $4014               ; dispara la DMA (pausa la CPU ~513-514 ciclos)

    ; 2) Vacía la cola de actualizaciones de PPU, si hay algo pendiente.
    jsr ppu_queue_flush

    ; 3) Marca el frame como listo y avanza el contador.
    inc frame_count
    lda #$01
    sta frame_ready

    pla
    tay
    pla
    tax
    pla
    rti
.endproc

.proc irq
    rti                     ; placeholder: sin IRQ de mapper programado todavía
.endproc

; Escribe un byte en VRAM durante el próximo VBlank en vez de hacerlo ahora.
; Entrada: pq_addr_hi/pq_addr_lo (dirección PPU destino), pq_data (byte).
; Si la cola está llena, descarta la escritura y cuenta el overflow en
; ppu_queue_overflow (no hay forma segura de bloquear aquí: esto se llama
; fuera de VBlank, donde no se puede esperar).
.proc ppu_queue_push
    ldx ppu_queue_len
    cpx #PPU_QUEUE_CAPACITY
    bcc @room
    inc ppu_queue_overflow
    rts
@room:
    lda pq_addr_hi
    sta ppu_queue_addr_hi,x
    lda pq_addr_lo
    sta ppu_queue_addr_lo,x
    lda pq_data
    sta ppu_queue_data,x
    inx
    stx ppu_queue_len
    rts
.endproc

; Aplica todas las escrituras encoladas a VRAM y vacía la cola.
; Solo debe llamarse durante VBlank (se llama desde nmi).
.proc ppu_queue_flush
    ldx ppu_queue_len
    beq @done

    ldy #$00
@loop:
    lda ppu_queue_addr_hi,y
    sta $2006
    lda ppu_queue_addr_lo,y
    sta $2006
    lda ppu_queue_data,y
    sta $2007
    iny
    dex
    bne @loop

    lda #$00
    sta ppu_queue_len
@done:
    rts
.endproc
