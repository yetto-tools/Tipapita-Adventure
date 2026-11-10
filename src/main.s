; Tipapita Adventure — punto de entrada.
;
; F1.3 (NMI/IRQ): implementa el NMI real con responsabilidades fijas, en
; este orden, documentado aquí porque es la única fuente de verdad sobre
; qué hace el NMI cada frame:
;   1) OAM DMA: copia el buffer de sombra de sprites ($0200-$02FF) al OAM
;      real de la PPU. Va primero porque es lo más urgente en VBlank.
;   2) Vacía la cola de actualizaciones de PPU (si hay algo encolado).
;   3) Marca `frame_ready` y avanza `frame_count`, para sincronizar al
;      main loop con la tasa real de refresco (60 Hz NTSC).
; Todavía NO se escriben registros de scroll (no hay cámara, Fase 4) ni se
; implementa IRQ de mapper (no hay HUD con split-screen todavía). El
; renderizado de fondo/sprites sigue desactivado a propósito: no hay
; nametables ni CHR reales, solo paleta en negro (F1.2).

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

    ; Inicializa toda la paleta (32 bytes: fondo + sprites) a negro ($0F),
    ; para que el color mostrado no sea un valor indefinido de encendido.
    ; Se escribe de forma directa (no por la cola) porque el renderizado
    ; sigue desactivado: mientras $2001 tenga fondo y sprites apagados,
    ; escribir VRAM fuera de VBlank es seguro.
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
    ; conocido.
    bit $2002
    lda #$00
    sta $2005
    sta $2005

    ; Habilita generación de NMI. El renderizado (fondo/sprites) sigue
    ; desactivado a propósito: todavía no hay nametables ni CHR reales
    ; (Fase 2), así que encenderlo ahora mostraría contenido indefinido.
    lda #%10000000
    sta $2000

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
