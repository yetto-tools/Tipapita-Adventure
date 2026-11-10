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
;
; F3.1 (controlador): `read_controller1`, llamada una vez por frame
; desde el main loop, lee el mando 1 vía $4016 y normaliza 3 estados:
; `pad1` (botones sostenidos ahora), `pad1_prev` (sostenidos el frame
; anterior) y `pad1_pressed` (bits que pasaron de 0 a 1 este frame — para
; detectar flancos, no solo "está sostenido").
;
; F3.2 (movimiento): posición y velocidad de Chiquito en punto fijo 8.8
; (byte alto = píxeles enteros, byte bajo = fracción; 256 = 1 píxel).
; `update_player` aplica aceleración/fricción horizontal, gravedad y
; salto (con corte de salto variable: soltar A temprano reduce la
; altura). La animación idle/caminar depende de la velocidad real.
;
; F3.3 (colisiones): reemplaza el piso temporal fijo de F3.2 por
; colisión real contra el mapa de metatiles de la escena
; (`scene_pradera_collision`, generado por tools/build_scene.py). Cada
; metatile tiene un tipo (vacío/sólido/plataforma de un sentido/peligro);
; `get_tile_collision` resuelve qué tipo hay en un punto dado, y
; `update_player` revisa las esquinas del hitbox del jugador por eje
; (horizontal primero, luego vertical) después de aplicar la velocidad.
; Las plataformas solo bloquean cayendo (vy>=0).
;
; F3.4 (máquina de estados): `player_state` (STATE_*) formaliza lo que
; antes era implícito. IDLE/WALK/JUMP/FALL se recalculan cada frame
; desde la física (`recompute_normal_state`); ATTACK/HURT/DEAD duran
; exactamente *_DURATION frames y salen solos al expirar su temporizador
; -- ningún estado queda trabado. Tocar un peligro ya no reaparece de
; inmediato: entra en HURT con knockback real y parpadeo de
; invulnerabilidad; caerse de la pantalla visible entra en DEAD
; (congelado) y, al expirar, `respawn_player` reaparece a Chiquito en
; (SPAWN_X,SPAWN_Y). ATTACK (botón B) "enraíza" el movimiento horizontal
; -- todavía no hay arma/hitbox de ataque real (eso es F5.3).

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

; Hitbox del jugador (definida en F2.3, usada desde F3.3). Un sprite de
; 8x8 completo, sin margen todavía.
PLAYER_HITBOX_W = 8
PLAYER_HITBOX_H = 8

; Física del jugador (F3.2), en punto fijo 8.8 (ver nota arriba sobre el
; formato). Valores elegidos para que el movimiento se sienta ágil pero
; controlable; se ajustan por parámetro, sin tocar la lógica.
MOVE_ACCEL          = $0020   ; ~0.125 px/frame² al sostener izquierda/derecha
MOVE_FRICTION       = $0030   ; ~0.19 px/frame² de frenado sin input
MOVE_MAX_SPEED      = $0180   ; 1.5 px/frame, tope horizontal
NEG_MOVE_MAX_SPEED  = $FE80   ; -1.5 px/frame en complemento a 2 de 16 bits
GRAVITY             = $0020   ; ~0.125 px/frame² hacia abajo
MAX_FALL_SPEED      = $0400   ; 4.0 px/frame, velocidad terminal de caída
JUMP_VELOCITY       = $FC00   ; -4.0 px/frame (impulso inicial del salto)
JUMP_CUT_SPEED_NEG  = $FE00   ; -2.0 px/frame: tope al soltar A mientras sube

; Tipos de colisión por metatile (F3.3; ver tools/build_scene.py, que
; genera scene_pradera_collision con estos mismos valores).
COLLISION_EMPTY    = 0
COLLISION_SOLID    = 1
COLLISION_PLATFORM = 2
COLLISION_HAZARD   = 3

; Estados del jugador (F3.4). IDLE/WALK/JUMP/FALL se recalculan cada
; frame a partir de la física (on_ground, vx, vy) cuando no hay un
; estado con temporizador propio en curso; ATTACK/HURT/DEAD duran
; exactamente *_DURATION frames y luego salen solos -- ningún estado
; puede quedarse trabado indefinidamente.
STATE_IDLE   = 0
STATE_WALK   = 1
STATE_JUMP   = 2
STATE_FALL   = 3
STATE_ATTACK = 4
STATE_HURT   = 5
STATE_DEAD   = 6

ATTACK_DURATION = 14   ; ~0.23s: sin arma/hitbox real todavía (F5.3) -- solo "enraíza" el movimiento
HURT_DURATION   = 30   ; ~0.5s de invulnerabilidad con parpadeo tras tocar un peligro
DEAD_DURATION   = 40   ; ~0.67s congelado antes de reaparecer

; 4.0 px/frame: con MOVE_FRICTION decayendo a este ritmo, el empuje debe
; alejar a Chiquito más allá del ancho de un metatile (16px) para que no
; quede rebotando contra el mismo peligro apenas termina HURT_DURATION
; (con 2.0 px/frame no alcanzaba a salir del tile -- confirmado con
; prueba automatizada antes de subir este valor).
KNOCKBACK_VX     = $0400
NEG_KNOCKBACK_VX = $FC00   ; -4.0 px/frame en complemento a 2 de 16 bits
KNOCKBACK_VY     = $FC00   ; -4.0 px/frame, empuje vertical (mismo valor que JUMP_VELOCITY)

; Si Y pasa de esto, Chiquito se cayó de la pantalla visible (256x224) --
; "muerte por caída" sin necesitar un sistema de vida real todavía.
DEATH_Y_THRESHOLD = 224

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
    .byte SPAWN_Y, TILE_CHIQUITO_IDLE, %00000000, SPAWN_X   ; Chiquito
    .byte 179,     TILE_ENEMY,         %00000001, 180       ; enemigo
    .byte 99,      TILE_ITEM,          %00000010, 140       ; coleccionable

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

; Posición y velocidad de Chiquito, en punto fijo 8.8 (ver nota F3.2).
player_x_lo: .res 1
player_x_hi: .res 1
player_y_lo: .res 1
player_y_hi: .res 1
player_vx_lo: .res 1
player_vx_hi: .res 1
player_vy_lo: .res 1
player_vy_hi: .res 1
player_on_ground:    .res 1   ; 1 = parado sobre suelo/plataforma sólida
player_facing_right: .res 1   ; 1 = mirando a la derecha (para el flip del sprite)
player_state: .res 1          ; STATE_* (F3.4)
state_timer:  .res 1          ; frames restantes del estado actual (solo ATTACK/HURT/DEAD lo usan)

; Escratch para cmp16_signed: no deben usarse para nada más.
cmp_a_lo: .res 1
cmp_a_hi: .res 1
cmp_b_lo: .res 1
cmp_b_hi: .res 1

; Argumentos/escratch de get_tile_collision (F3.3): no deben usarse para
; nada más mientras se está resolviendo una consulta de colisión.
col_x:   .res 1
col_y:   .res 1
col_tmp: .res 1

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

    ; F3.2/F3.3: posición/estado inicial de Chiquito, en punto fijo 8.8.
    ; Coincide con la posición estática que se acaba de copiar al OAM
    ; (SPAWN_Y/SPAWN_X, el punto de reaparición definido en la escena),
    ; para que el primer frame no "salte".
    lda #SPAWN_X
    sta player_x_hi
    lda #SPAWN_Y
    sta player_y_hi
    lda #1
    sta player_on_ground
    sta player_facing_right
    ; Re-cero defensivo de posición fraccional y velocidad: ya deberían
    ; estar en 0 por la limpieza de RAM de arriba, pero se deja explícito
    ; aquí (inmediatamente antes de que arranque el main loop) para no
    ; depender de esa limpieza si el código de más arriba cambia alguna
    ; vez de orden.
    lda #0
    sta player_x_lo
    sta player_y_lo
    sta player_vx_lo
    sta player_vx_hi
    sta player_vy_lo
    sta player_vy_hi
    sta state_timer
    sta player_state         ; STATE_IDLE = 0

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
    jsr update_player        ; F3.2: física + escribe posición/tile/flip al OAM

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

; Compara (cmp_a_hi:cmp_a_lo) con (cmp_b_hi:cmp_b_lo) como enteros de 16
; bits CON signo. Al volver, el flag N queda en el estado correcto para
; un `bmi` inmediatamente después: N=1 significa A < B. RTS no toca las
; banderas, así que esto funciona igual que comparar en línea.
.proc cmp16_signed
    sec
    lda cmp_a_lo
    sbc cmp_b_lo
    lda cmp_a_hi
    sbc cmp_b_hi
    bvc @noflip
    eor #$80                ; corrige el signo si la resta desbordó (overflow con signo)
@noflip:
    rts
.endproc

; Devuelve en A el tipo de colisión (COLLISION_*) del metatile que
; contiene el punto de píxel (col_x, col_y). Metatiles de 16x16px en una
; grilla de 16 columnas; índice = fila*16 + columna. Como fila*16 es
; exactamente "quedarse con el nibble alto de col_y" (enmascarar con
; $F0), no hace falta desplazar col_y y luego multiplicar por separado.
.proc get_tile_collision
    lda col_y
    and #$F0                 ; = fila * 16
    sta col_tmp
    lda col_x
    lsr a
    lsr a
    lsr a
    lsr a                    ; = columna (0-15)
    clc
    adc col_tmp
    tax
    lda scene_pradera_collision,x
    rts
.endproc

; Física, colisión y animación de Chiquito (F3.2/F3.3). Llamada una vez
; por frame desde el main loop, después de read_controller1. Orden:
;   1) Horizontal: acelera con input, frena con fricción si no hay input.
;   2) Aplica velocidad horizontal a la posición.
;   3) Colisión horizontal: si una esquina del hitbox cae sobre un
;      metatile sólido en la dirección de movimiento, encajar contra esa
;      pared y poner vx en 0.
;   4) Vertical: gravedad, inicio de salto, corte de salto variable.
;   5) Aplica velocidad vertical a la posición.
;   6) Colisión vertical: suelo/plataforma si cae (vy>=0, las
;      plataformas solo bloquean en este caso -- de un solo sentido),
;      techo si sube (vy<0, solo tiles sólidos). Si no hay nada debajo,
;      limpia player_on_ground (caerse de un borde).
;   7) Peligro: si alguna esquina del hitbox toca un metatile de
;      peligro, reaparece en (SPAWN_X, SPAWN_Y) -- placeholder de daño
;      hasta que exista un sistema de vida real (Fase 5/6).
;   8) Anima (idle/caminar según velocidad real) y actualiza el OAM.
.proc update_player
    ; --- F3.4: estados con temporizador propio (DEAD/HURT/ATTACK) ---
    ; Tienen prioridad: cuentan su propio reloj y SIEMPRE salen solos al
    ; llegar a 0 (ver recompute_normal_state) -- ningún estado puede
    ; quedar trabado indefinidamente.
    lda player_state
    cmp #STATE_DEAD
    bne @not_dead
    dec state_timer
    bne @still_dead
    jsr respawn_player
@still_dead:
    rts                      ; congelado: nada más corre mientras está muerto
@not_dead:

    cmp #STATE_HURT
    bne @not_hurt
    dec state_timer
    bne @movement_start
    jsr recompute_normal_state
    jmp @movement_start
@not_hurt:

    cmp #STATE_ATTACK
    bne @not_attack
    dec state_timer
    bne @movement_start
    jsr recompute_normal_state
    jmp @movement_start
@not_attack:

    ; Estado normal (IDLE/WALK/JUMP/FALL): ¿se presiona B para atacar?
    ; Sin arma/hitbox real todavía (eso es F5.3) -- por ahora ATTACK solo
    ; "enraíza" el movimiento horizontal, un comportamiento real y
    ; verificable aunque no haga daño todavía.
    lda pad1_pressed
    and #PAD_B
    beq @movement_start
    lda #STATE_ATTACK
    sta player_state
    lda #ATTACK_DURATION
    sta state_timer

@movement_start:
    ; HURT y ATTACK bloquean el input horizontal/de salto (fricción y
    ; gravedad/colisión siguen corriendo normal, para que el knockback de
    ; HURT se vea de verdad).
    lda player_state
    cmp #STATE_HURT
    beq @input_blocked
    cmp #STATE_ATTACK
    bne @input_allowed
@input_blocked:
    jmp @friction
@input_allowed:
    lda pad1
    and #PAD_RIGHT
    bne @accel_right
    lda pad1
    and #PAD_LEFT
    bne @accel_left
    jmp @friction

@accel_right:
    clc
    lda player_vx_lo
    adc #<MOVE_ACCEL
    sta player_vx_lo
    lda player_vx_hi
    adc #>MOVE_ACCEL
    sta player_vx_hi
    ; clamp: si vx > MOVE_MAX_SPEED, vx = MOVE_MAX_SPEED
    lda player_vx_lo
    sta cmp_a_lo
    lda player_vx_hi
    sta cmp_a_hi
    lda #<MOVE_MAX_SPEED
    sta cmp_b_lo
    lda #>MOVE_MAX_SPEED
    sta cmp_b_hi
    jsr cmp16_signed         ; N=1 si vx < MOVE_MAX_SPEED (A=vx,B=MAX)
    bmi @right_done
    lda #<MOVE_MAX_SPEED
    sta player_vx_lo
    lda #>MOVE_MAX_SPEED
    sta player_vx_hi
@right_done:
    lda #1
    sta player_facing_right
    jmp @apply_x

@accel_left:
    sec
    lda player_vx_lo
    sbc #<MOVE_ACCEL
    sta player_vx_lo
    lda player_vx_hi
    sbc #>MOVE_ACCEL
    sta player_vx_hi
    ; clamp: si vx < -MOVE_MAX_SPEED, vx = -MOVE_MAX_SPEED
    lda player_vx_lo
    sta cmp_a_lo
    lda player_vx_hi
    sta cmp_a_hi
    lda #<NEG_MOVE_MAX_SPEED
    sta cmp_b_lo
    lda #>NEG_MOVE_MAX_SPEED
    sta cmp_b_hi
    jsr cmp16_signed         ; N=1 si vx < -MAX (ya pasado el límite)
    bpl @left_done
    lda #<NEG_MOVE_MAX_SPEED
    sta player_vx_lo
    lda #>NEG_MOVE_MAX_SPEED
    sta player_vx_hi
@left_done:
    lda #0
    sta player_facing_right
    jmp @apply_x

@friction:
    ; Empuja vx hacia 0 en MOVE_FRICTION, sin pasarse de 0 (si se pasa,
    ; se fija en 0 exactamente en vez de oscilar alrededor de cero).
    lda player_vx_hi
    bmi @friction_negative
    lda player_vx_lo
    sec
    sbc #<MOVE_FRICTION
    sta player_vx_lo
    lda player_vx_hi
    sbc #>MOVE_FRICTION
    sta player_vx_hi
    bpl @apply_x
    lda #0
    sta player_vx_lo
    sta player_vx_hi
    jmp @apply_x
@friction_negative:
    lda player_vx_lo
    clc
    adc #<MOVE_FRICTION
    sta player_vx_lo
    lda player_vx_hi
    adc #>MOVE_FRICTION
    sta player_vx_hi
    bmi @apply_x
    lda #0
    sta player_vx_lo
    sta player_vx_hi

@apply_x:
    clc
    lda player_x_lo
    adc player_vx_lo
    sta player_x_lo
    lda player_x_hi
    adc player_vx_hi
    sta player_x_hi

    ; --- Colisión horizontal (F3.3): solo sólido bloquea; plataformas y
    ; peligros no detienen el movimiento lateral. ---
    lda player_vx_lo
    ora player_vx_hi
    beq @hcol_done           ; vx == 0: no se movió, nada que resolver
    lda player_vx_hi
    bmi @hcol_left

@hcol_right:
    lda player_x_hi
    clc
    adc #PLAYER_HITBOX_W
    sta col_x
    lda player_y_hi
    sta col_y
    jsr get_tile_collision
    cmp #COLLISION_SOLID
    beq @hcol_right_hit
    lda player_y_hi
    clc
    adc #(PLAYER_HITBOX_H-1)
    sta col_y
    jsr get_tile_collision   ; col_x sigue siendo el borde derecho de arriba
    cmp #COLLISION_SOLID
    bne @hcol_done
@hcol_right_hit:
    lda col_x
    and #$F0                 ; borde izquierdo del tile golpeado
    sec
    sbc #PLAYER_HITBOX_W
    sta player_x_hi
    lda #0
    sta player_vx_lo
    sta player_vx_hi
    jmp @hcol_done

@hcol_left:
    lda player_x_hi
    sta col_x
    lda player_y_hi
    sta col_y
    jsr get_tile_collision
    cmp #COLLISION_SOLID
    beq @hcol_left_hit
    lda player_y_hi
    clc
    adc #(PLAYER_HITBOX_H-1)
    sta col_y
    jsr get_tile_collision   ; col_x sigue siendo el borde izquierdo de arriba
    cmp #COLLISION_SOLID
    bne @hcol_done
@hcol_left_hit:
    lda col_x
    and #$F0
    clc
    adc #16                  ; borde derecho del tile golpeado
    sta player_x_hi
    lda #0
    sta player_vx_lo
    sta player_vx_hi
@hcol_done:

    ; --- Vertical: gravedad ---
    clc
    lda player_vy_lo
    adc #<GRAVITY
    sta player_vy_lo
    lda player_vy_hi
    adc #>GRAVITY
    sta player_vy_hi
    ; clamp: si vy > MAX_FALL_SPEED, vy = MAX_FALL_SPEED
    lda player_vy_lo
    sta cmp_a_lo
    lda player_vy_hi
    sta cmp_a_hi
    lda #<MAX_FALL_SPEED
    sta cmp_b_lo
    lda #>MAX_FALL_SPEED
    sta cmp_b_hi
    jsr cmp16_signed
    bmi @gravity_done
    lda #<MAX_FALL_SPEED
    sta player_vy_lo
    lda #>MAX_FALL_SPEED
    sta player_vy_hi
@gravity_done:

    ; Inicio de salto: A recién presionado Y parado en el piso. No se
    ; puede saltar durante HURT (el knockback debe sentirse como tal, sin
    ; poder cancelarlo saltando); ATTACK sí puede saltar (jump-cancel).
    lda player_state
    cmp #STATE_HURT
    beq @no_jump_start
    lda pad1_pressed
    and #PAD_A
    beq @no_jump_start
    lda player_on_ground
    beq @no_jump_start
    lda #<JUMP_VELOCITY
    sta player_vy_lo
    lda #>JUMP_VELOCITY
    sta player_vy_hi
    lda #0
    sta player_on_ground
@no_jump_start:

    ; Corte de salto variable: si A ya NO está sostenido y Chiquito sigue
    ; subiendo (vy negativo) más rápido que JUMP_CUT_SPEED_NEG, recorta vy
    ; a ese valor -- soltar A antes hace un salto más corto.
    lda pad1
    and #PAD_A
    bne @apply_y
    lda player_vy_hi
    bpl @apply_y             ; vy >= 0: ya no sube, nada que recortar
    ; Ambos valores son negativos aquí: comparar solo el byte alto sin
    ; signo da el mismo orden que compararlos con signo (ver nota).
    cmp #>JUMP_CUT_SPEED_NEG
    bcs @apply_y             ; vy_hi >= byte alto del recorte: ya es más lento
    lda #<JUMP_CUT_SPEED_NEG
    sta player_vy_lo
    lda #>JUMP_CUT_SPEED_NEG
    sta player_vy_hi

@apply_y:
    clc
    lda player_y_lo
    adc player_vy_lo
    sta player_y_lo
    lda player_y_hi
    adc player_vy_hi
    sta player_y_hi

    ; --- Colisión vertical (F3.3) ---
    lda player_vy_hi
    bmi @vcol_ceiling

@vcol_floor:
    ; Cayendo (vy>=0): sólido o plataforma bloquean por abajo. Las
    ; plataformas son de un solo sentido -- solo cuentan aquí porque ya
    ; se sabe que se está cayendo, no subiendo.
    lda player_x_hi
    sta col_x
    lda player_y_hi
    clc
    adc #PLAYER_HITBOX_H
    sta col_y
    jsr get_tile_collision
    cmp #COLLISION_SOLID
    beq @vcol_floor_hit
    cmp #COLLISION_PLATFORM
    beq @vcol_floor_hit
    lda player_x_hi
    clc
    adc #(PLAYER_HITBOX_W-1)
    sta col_x
    jsr get_tile_collision   ; col_y sigue siendo el borde inferior
    cmp #COLLISION_SOLID
    beq @vcol_floor_hit
    cmp #COLLISION_PLATFORM
    beq @vcol_floor_hit
    ; ninguna esquina tocó suelo/plataforma: cayendo en el aire (incluye
    ; el caso de caminar fuera de un borde).
    lda #0
    sta player_on_ground
    jmp @vcol_done
@vcol_floor_hit:
    lda col_y
    and #$F0
    sec
    sbc #PLAYER_HITBOX_H
    sta player_y_hi
    lda #0
    sta player_y_lo
    sta player_vy_lo
    sta player_vy_hi
    lda #1
    sta player_on_ground
    jmp @vcol_done

@vcol_ceiling:
    ; Subiendo (vy<0): solo sólido bloquea por arriba (las plataformas no
    ; detienen desde abajo -- se puede saltar a través de ellas).
    lda player_x_hi
    sta col_x
    lda player_y_hi
    sta col_y
    jsr get_tile_collision
    cmp #COLLISION_SOLID
    beq @vcol_ceiling_hit
    lda player_x_hi
    clc
    adc #(PLAYER_HITBOX_W-1)
    sta col_x
    jsr get_tile_collision   ; col_y sigue siendo el borde superior
    cmp #COLLISION_SOLID
    bne @vcol_done
@vcol_ceiling_hit:
    lda col_y
    and #$F0
    clc
    adc #16
    sta player_y_hi
    lda #0
    sta player_y_lo
    sta player_vy_lo
    sta player_vy_hi

@vcol_done:
    ; --- Peligro (F3.4): si no está ya en HURT/DEAD, revisa las 4
    ; esquinas del hitbox. No bloquea el movimiento; si toca, entra en
    ; HURT con knockback -- placeholder de "daño" hasta que exista un
    ; sistema de vida real (Fase 5/6); la reaparición real pasa en DEAD.
    lda player_state
    cmp #STATE_HURT
    beq @hazard_skip
    cmp #STATE_DEAD
    beq @hazard_skip

    lda player_x_hi
    sta col_x
    lda player_y_hi
    sta col_y
    jsr get_tile_collision
    cmp #COLLISION_HAZARD
    beq @hazard_hit

    lda player_x_hi
    clc
    adc #(PLAYER_HITBOX_W-1)
    sta col_x
    jsr get_tile_collision   ; col_y sigue siendo el borde superior
    cmp #COLLISION_HAZARD
    beq @hazard_hit

    lda player_y_hi
    clc
    adc #(PLAYER_HITBOX_H-1)
    sta col_y
    jsr get_tile_collision   ; col_x sigue siendo el borde derecho
    cmp #COLLISION_HAZARD
    beq @hazard_hit

    lda player_x_hi
    sta col_x
    jsr get_tile_collision   ; col_y sigue siendo el borde inferior
    cmp #COLLISION_HAZARD
    bne @hazard_skip

@hazard_hit:
    lda #STATE_HURT
    sta player_state
    lda #HURT_DURATION
    sta state_timer
    lda #0
    sta player_on_ground
    lda player_facing_right
    bne @knockback_left
    lda #<KNOCKBACK_VX
    sta player_vx_lo
    lda #>KNOCKBACK_VX
    sta player_vx_hi
    jmp @knockback_vy
@knockback_left:
    lda #<NEG_KNOCKBACK_VX
    sta player_vx_lo
    lda #>NEG_KNOCKBACK_VX
    sta player_vx_hi
@knockback_vy:
    lda #<KNOCKBACK_VY
    sta player_vy_lo
    lda #>KNOCKBACK_VY
    sta player_vy_hi

@hazard_skip:
    ; --- Muerte por caída (F3.4): si Y pasa el umbral y no está ya en
    ; DEAD, congela a Chiquito hasta que expire el temporizador --
    ; respawn_player lo reaparece (ver el chequeo de STATE_DEAD al
    ; principio de este proc). ---
    lda player_state
    cmp #STATE_DEAD
    beq @death_skip
    lda player_y_hi
    cmp #DEATH_Y_THRESHOLD
    bcc @death_skip
    lda #STATE_DEAD
    sta player_state
    lda #DEAD_DURATION
    sta state_timer
    lda #0
    sta player_vx_lo
    sta player_vx_hi
    sta player_vy_lo
    sta player_vy_hi
@death_skip:

    ; Si no está en un estado con temporizador propio, recalcula
    ; IDLE/WALK/JUMP/FALL a partir de la física que se acaba de resolver.
    lda player_state
    cmp #STATE_HURT
    beq @skip_recompute
    cmp #STATE_ATTACK
    beq @skip_recompute
    cmp #STATE_DEAD
    beq @skip_recompute
    jsr recompute_normal_state
@skip_recompute:

@animate:
    ; Tile según el estado. IDLE/JUMP/FALL/HURT/DEAD reutilizan el tile
    ; idle (sin arte dedicado todavía para salto/caída/daño/muerte);
    ; WALK alterna con caminar según frame_count (ciclo de caminata);
    ; ATTACK reutiliza el tile de caminar como diferenciador visual.
    lda player_state
    cmp #STATE_WALK
    beq @anim_walk
    cmp #STATE_ATTACK
    beq @anim_attack
    lda #TILE_CHIQUITO_IDLE
    jmp @set_tile
@anim_walk:
    lda frame_count
    and #%00001000
    beq @anim_use_idle
    lda #TILE_CHIQUITO_WALK
    jmp @set_tile
@anim_use_idle:
    lda #TILE_CHIQUITO_IDLE
    jmp @set_tile
@anim_attack:
    lda #TILE_CHIQUITO_WALK
@set_tile:
    sta oam_buffer+1

    ; Flip horizontal según hacia dónde mira (subpaleta 0 = jugador, sin
    ; otros bits que preservar).
    lda player_facing_right
    bne @facing_right
    lda #%01000000           ; bit6 = flip horizontal
    jmp @set_attr
@facing_right:
    lda #%00000000
@set_attr:
    sta oam_buffer+2

    ; Posición real -> OAM (byte alto de cada coordenada en punto fijo).
    lda player_y_hi
    sta oam_buffer+0
    lda player_x_hi
    sta oam_buffer+3

    ; Parpadeo durante HURT (invulnerabilidad visual): oculta el sprite
    ; la mitad de los frames, técnica estándar de NES. Sin esto no habría
    ; forma de distinguir cuándo sigue invulnerable.
    lda player_state
    cmp #STATE_HURT
    bne @no_blink
    lda state_timer
    and #%00000100
    bne @no_blink
    lda #$FF
    sta oam_buffer+0         ; Y=$FF: oculta el sprite este frame
@no_blink:

    rts
.endproc

; Reaparece a Chiquito en (SPAWN_X, SPAWN_Y), limpio de velocidad, y
; vuelve a STATE_IDLE. Usado al expirar STATE_DEAD.
.proc respawn_player
    lda #SPAWN_X
    sta player_x_hi
    lda #SPAWN_Y
    sta player_y_hi
    lda #0
    sta player_x_lo
    sta player_y_lo
    sta player_vx_lo
    sta player_vx_hi
    sta player_vy_lo
    sta player_vy_hi
    lda #STATE_IDLE
    sta player_state
    lda #1
    sta player_on_ground
    rts
.endproc

; Recalcula player_state a IDLE/WALK/JUMP/FALL según player_on_ground y
; la velocidad actual. Solo debe llamarse cuando el estado actual NO es
; ATTACK/HURT/DEAD (esos administran su propia salida por temporizador).
.proc recompute_normal_state
    lda player_on_ground
    beq @airborne
    lda player_vx_lo
    ora player_vx_hi
    beq @set_idle
    lda #STATE_WALK
    sta player_state
    rts
@set_idle:
    lda #STATE_IDLE
    sta player_state
    rts
@airborne:
    lda player_vy_hi
    bmi @set_jump
    lda #STATE_FALL
    sta player_state
    rts
@set_jump:
    lda #STATE_JUMP
    sta player_state
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
