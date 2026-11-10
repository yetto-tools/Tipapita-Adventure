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
; F2.1 (paletas): paletas reales de pradera (cielo/pradera/tierra) y de
; sprite (jugador/enemigo/ítem) en src/data/palettes.s.
;
; F2.2 (tiles y metatiles): los tiles de prueba (suelo, cielo,
; plataforma, decoración) y la escena de pradera ya NO se escriben a
; mano: se generan desde un asset fuente real (assets/tiles/pradera.png)
; vía tools/png2chr.py, y la disposición en pantalla se compila desde una
; definición de metatiles vía tools/build_scene.py — ver el Makefile
; (dist/tiles_pradera.s, dist/scene_pradera.s). `reset` solo copia esos
; bytes ya compilados a VRAM con ppu_copy_bulk.
;
; F2.3 (sprites): Chiquito (con animación idle/caminar), un enemigo y un
; coleccionable, generados con el mismo pipeline.
;
; F3.1 (controlador): `read_controller1`, llamada una vez por frame
; desde el main loop, lee el mando 1 vía $4016 y normaliza 3 estados:
; `pad1` (botones sostenidos ahora), `pad1_prev` (sostenidos el frame
; anterior) y `pad1_pressed` (bits que pasaron de 0 a 1 este frame — para
; detectar flancos, no solo "está sostenido"). Todavía no hay nada que
; reaccione a estos botones (eso es F3.2 en adelante).

; F2.3 (sprites): protagonista (Chiquito, con 2 frames de animación),
; enemigo inicial y coleccionable, también generados vía
; tools/png2chr.py (assets/sprites/chiquito_test.png — igual de
; placeholder técnico que los tiles de pradera). Se agregan al mismo
; segmento CHARS, justo después de los tiles de fondo, por lo que
; terminan físicamente en los mismos bancos que R0-R5 ya exponen (ver
; nota de mmc3_init_values): hoy pattern table 0 y pattern table 1
; muestran los mismos bytes físicos de CHR-ROM porque ningún registro de
; banco cambia todavía. Por eso los tiles de sprite, índices 5-8, caen
; justo después de los 5 tiles de fondo (índices 0-4).

.include "data/palettes.s"
.include "../dist/tiles_pradera.s"
.include "../dist/scene_pradera.s"
.include "../dist/tiles_sprites.s"

; Índices de tile de sprite (dentro de tiles_sprites, offset +5 porque
; van después de los 5 tiles de fondo en el mismo CHR-ROM).
TILE_CHIQUITO_IDLE = 5
TILE_CHIQUITO_WALK = 6
TILE_ENEMY         = 7
TILE_ITEM          = 8

; Hitbox del jugador (F2.3: solo definida, todavía sin usar -- la
; colisión real es F3.3). Un sprite de 8x8 completo, sin margen todavía;
; se ajustará cuando haya colisiones reales que probar.
PLAYER_HITBOX_W = 8
PLAYER_HITBOX_H = 8

; Bits del byte normalizado de mando (orden estándar de NES: el primer
; botón leído -- A -- termina en el bit más alto, por cómo se arma el
; byte con ROL en read_controller1).
PAD_A      = %10000000
PAD_B      = %01000000
PAD_SELECT = %00100000
PAD_START  = %00010000
PAD_UP     = %00001000
PAD_DOWN   = %00000100
PAD_LEFT   = %00000010
PAD_RIGHT  = %00000001

.segment "RODATA"
; OAM inicial (3 sprites de prueba): Y, tile, atributos, X.
; Atributos bits0-1 = subpaleta de sprite (0=jugador,1=enemigo,2=ítem).
oam_init_data:
    .byte 179, TILE_CHIQUITO_IDLE, %00000000, 100   ; Chiquito
    .byte 179, TILE_ENEMY,         %00000001, 180   ; enemigo
    .byte  99, TILE_ITEM,          %00000010, 140   ; coleccionable

.segment "RODATA"
; R0,R1: ventanas CHR de 2KB -> banco 0. R2-R5: ventanas CHR de 1KB -> banco 0.
; Así $0000-$1FFF completo apunta al principio de CHR-ROM, donde está
; tiles_pradera.s. R6,R7: ventanas PRG swappeables de 8KB ($8000-$9FFF y
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
pbulk_src:   .res 2   ; argumento de ppu_copy_bulk: puntero fuente en ROM (low, high)
pbulk_len:   .res 2   ; argumento de ppu_copy_bulk: cantidad de bytes a copiar (low, high)

pad1:         .res 1   ; botones del mando 1 sostenidos en este frame
pad1_prev:    .res 1   ; botones sostenidos en el frame anterior
pad1_pressed: .res 1   ; botones que pasaron de 0 a 1 este frame (flanco de bajada a presionado)

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

    ; Llena el buffer de sombra de OAM con $FF (Y=$FF deja cualquier
    ; sprite fuera de la pantalla visible) antes de escribir los sprites
    ; reales. Sin esto, los sprites 3-63 (sin usar) quedarían en Y=0 tras
    ; la limpieza de RAM de arriba, lo que los mostraría como basura
    ; visual cerca de la esquina superior izquierda.
    lda #$FF
@oam_fill:
    sta oam_buffer,x
    inx
    bne @oam_fill

    ; Copia los 3 sprites de prueba (Chiquito, enemigo, coleccionable)
    ; al principio del buffer de OAM.
    ldx #$00
@oam_copy:
    lda oam_init_data,x
    sta oam_buffer,x
    inx
    cpx #12
    bne @oam_copy

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

    ; Copia los 960 bytes de tiles de la escena de pradera a los tiles
    ; del nametable 0 ($2000-$23BF).
    bit $2002
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    lda #<scene_pradera_tiles
    sta pbulk_src
    lda #>scene_pradera_tiles
    sta pbulk_src+1
    lda #<960
    sta pbulk_len
    lda #>960
    sta pbulk_len+1
    jsr ppu_copy_bulk

    ; Copia los 64 bytes de atributos de la escena a la tabla de
    ; atributos del nametable 0 ($23C0-$23FF), para que cada metatile
    ; muestre la subpaleta de fondo que le corresponde.
    bit $2002
    lda #$23
    sta $2006
    lda #$C0
    sta $2006
    lda #<scene_pradera_attrs
    sta pbulk_src
    lda #>scene_pradera_attrs
    sta pbulk_src+1
    lda #<64
    sta pbulk_len
    lda #>64
    sta pbulk_len+1
    jsr ppu_copy_bulk

    ; Reinicia el latch de scroll/dirección para dejar la PPU en un estado
    ; conocido.
    bit $2002
    lda #$00
    sta $2005
    sta $2005

    ; Habilita generación de NMI, patrón de sprites en pattern table 1
    ; (bit3) y renderizado de fondo + sprites (F2.3: ya hay sprites
    ; reales en el OAM).
    lda #%10001000           ; PPUCTRL: bit7 NMI, bit3 sprites usan pattern table 1
    sta $2000
    lda #%00011110           ; PPUMASK: fondo+sprites, incluyendo los 8px izquierdos
    sta $2001

mainloop:
    lda frame_ready
    beq mainloop            ; espera a que el NMI marque el frame como listo
    lda #$00
    sta frame_ready

    jsr read_controller1     ; F3.1: actualiza pad1/pad1_prev/pad1_pressed

    ; Animación mínima de Chiquito (F2.3): alterna idle/caminar cada 16
    ; frames usando el bit 4 de frame_count. Es la única "lógica de
    ; juego" de este milestone; el resto llega en Fase 3.
    lda frame_count
    and #%00010000
    beq @idle
    lda #TILE_CHIQUITO_WALK
    jmp @set_tile
@idle:
    lda #TILE_CHIQUITO_IDLE
@set_tile:
    sta oam_buffer+1         ; byte de tile del primer sprite (Chiquito)

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

; Lee el mando 1 y normaliza su estado. Debe llamarse una vez por frame
; (desde el main loop, nunca desde nmi). Orden de lectura estándar de
; NES: A, B, Select, Start, Up, Down, Left, Right -- cada lectura entrega
; el bit en bit0 de $4016; el primer bit leído (A) termina en el bit más
; alto del byte final porque cada ROL subsiguiente lo desplaza un lugar
; más a la izquierda (ver constantes PAD_* arriba).
.proc read_controller1
    lda pad1
    sta pad1_prev

    lda #$01
    sta $4016               ; strobe alto: el mando recarga su registro de botones
    lda #$00
    sta $4016               ; strobe bajo: empieza a entregar un bit por lectura

    ldx #$08
@loop:
    lda $4016
    lsr a                   ; bit0 del mando -> acarreo
    rol pad1                ; mete el acarreo en pad1 y desplaza el resto a la izquierda
    dex
    bne @loop

    ; pad1_pressed = bits que están en 1 ahora pero NO estaban en el frame anterior.
    lda pad1
    eor pad1_prev
    and pad1
    sta pad1_pressed
    rts
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

; Copia pbulk_len bytes desde ROM (pbulk_src) a $2007, es decir, a la
; dirección de VRAM que el llamador ya haya fijado con $2006. No toca
; $2006 por sí misma: solo copia bytes, uno tras otro (la PPU
; autoincrementa la dirección). Usada para volcar datos ya generados en
; tiempo de build (tiles, escenas) sin escribirlos a mano en ensamblador.
; pbulk_len debe ser >= 1 (es un bucle do-while; con 0 daría la vuelta).
.proc ppu_copy_bulk
    ldy #$00
@loop:
    lda (pbulk_src),y
    sta $2007

    inc pbulk_src
    bne @no_carry
    inc pbulk_src+1
@no_carry:

    lda pbulk_len
    bne @dec_lo
    dec pbulk_len+1
@dec_lo:
    dec pbulk_len

    lda pbulk_len
    ora pbulk_len+1
    bne @loop
    rts
.endproc
