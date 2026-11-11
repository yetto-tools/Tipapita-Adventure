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
;
; F4.2 (scrolling horizontal): el nivel ahora puede ser más ancho que
; una pantalla (`assets/maps/pradera.txt` tiene 3 = `LEVEL_SCREENS`,
; `LEVEL_COLS` metatiles de ancho). Esto cambia varias cosas de raíz:
;   - La posición X de Chiquito pasa a ser de MUNDO, no de pantalla:
;     `player_x_frac` (fracción, 8.8) + `player_x_px_lo`/`player_x_px_hi`
;     (píxel entero, 16 bits -- un solo byte ya no alcanza para 768px).
;     La suma de velocidad ahora propaga el signo de `player_vx_hi` al
;     byte alto nuevo (ver `@apply_x`).
;   - La colisión (`get_tile_collision`) ya no puede usar el truco de
;     enmascarar el nibble alto de Y para obtener fila*16 -- con
;     `LEVEL_COLS` no potencia de 2, usa una tabla de offsets por fila
;     (`scene_pradera_row_offset_*`) y un puntero indirecto de 16 bits.
;   - Mirroring vertical (registro de MMC3 en $A000, no el bit del
;     header iNES, que MMC3 ignora en tiempo de ejecución): necesario
;     para que $2000/$2400 sean físicamente distintos y el scroll
;     horizontal revele contenido nuevo en vez de repetir la pantalla.
;   - `update_camera_and_streaming` (llamada desde el main loop después
;     de `update_player`) calcula `camera_x` (sigue a Chiquito con un
;     offset fijo, con límites en los bordes del nivel), escribe
;     PPUSCROLL/el bit de selección de nametable en `nmi`, y transmite
;     ("streaming") la pantalla que haga falta hacia el nametable físico
;     que ya quedó fuera de vista, usando `ppu_queue_push` repartido en
;     varios frames (la cola de F1.3, sin uso real hasta ahora).

.include "data/palettes.s"
.include "../dist/tiles_pradera.s"
.include "../dist/scene_pradera.s"
.include "../dist/scene_casa.s"
.include "../dist/tiles_sprites.s"

; Índices de tile de sprite (dentro de tiles_sprites, offset +6 porque
; van después de los 6 tiles de fondo en el mismo CHR-ROM -- 5 de la
; pradera + la puerta agregada en F4.3).
TILE_CHIQUITO_IDLE = 6
TILE_CHIQUITO_WALK = 7
TILE_ENEMY         = 8
TILE_ITEM          = 9

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
COLLISION_DOOR     = 4

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

; F4.2 (cámara/scroll). CAMERA_OFFSET centra a Chiquito a 120px del
; borde izquierdo de la pantalla visible (256px de ancho); camera_x se
; recalcula entero cada frame (sin suavizado) y se recorta a
; [0, room_max_camera] para no mostrar nada fuera del nivel.
; F4.3: el límite superior de la cámara (antes MAX_CAMERA_X, una sola
; constante de compilación porque solo existía un nivel) ahora varía
; por habitación -- cada habitación tiene su propio ancho, así que es
; un valor de RUNTIME (room_max_camera_lo/hi) que `load_room` carga
; desde `room_descriptors`, no una constante fija.
CAMERA_OFFSET   = 120

; F4.3 (habitaciones). Con solo 2 habitaciones en este milestone, el
; ID de habitación es simplemente 0/1 y el destino de cada puerta está
; hardcodeado como "la otra habitación" (ver @door_hit en update_player)
; -- no hay todavía un mapa genérico de puertas->destinos.
ROOM_PRADERA   = 0
ROOM_CASA      = 1
; Tamaño en bytes de cada registro de room_descriptors (ver la tabla
; más abajo): 2 (colisión) + 2 (puntero fila lo) + 2 (puntero fila hi)
; + 2 (puntero a pantallas) + 1 (cantidad de pantallas) + 2 (cámara
; máxima) + 2 (spawn X) + 1 (spawn Y) = 14.
ROOM_DESC_SIZE = 14

; Presupuesto de bytes transmitidos por frame hacia el nametable físico
; que está fuera de vista (streaming de pantallas, ver
; update_camera_and_streaming). 16 bytes/frame tarda 1024/16=64 frames
; (~1.07s) en completar una pantalla -- de sobra: a MOVE_MAX_SPEED
; (1.5px/frame) cruzar una pantalla completa (256px) tarda ~170 frames.
STREAM_BUDGET = 16

; PPUCTRL fijo (bit7 NMI, bit3 sprites en pattern table 1) que se
; combina cada frame con el bit de selección de nametable (bit0 =
; camera_x_hi AND 1) en nmi -- ver nota F4.2 arriba del archivo.
PPUCTRL_BASE = %10001000

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
; OAM inicial (3 sprites de prueba): Y, tile, atributos, X. Posición de
; Chiquito es solo un valor placeholder -- load_room (llamado desde
; reset antes del primer frame) la pisa con la posición real de la
; habitación inicial, y @animate la mantiene correcta todos los frames
; después de eso.
oam_init_data:
    .byte SCENE_PRADERA_SPAWN_Y, TILE_CHIQUITO_IDLE, %00000000, SCENE_PRADERA_SPAWN_X
    .byte 179,     TILE_ENEMY,         %00000001, 180       ; enemigo
    .byte 99,      TILE_ITEM,          %00000010, 140       ; coleccionable

; Descriptor de cada habitación (F4.3): un registro de ROOM_DESC_SIZE
; bytes por habitación, indexado por ROOM_PRADERA/ROOM_CASA*ROOM_DESC_SIZE
; -- ver load_room, que lo lee campo por campo. "cámara máxima" se
; calcula una sola vez aquí, en tiempo de compilación, a partir del
; ancho real de cada mapa (antes era una sola constante MAX_CAMERA_X
; porque solo existía un nivel).
room_descriptors:
    ; ROOM_PRADERA
    .addr scene_pradera_collision
    .addr scene_pradera_row_offset_lo
    .addr scene_pradera_row_offset_hi
    .addr scene_pradera_screen_ptrs
    .byte SCENE_PRADERA_LEVEL_SCREENS
    .word (SCENE_PRADERA_LEVEL_COLS * 16 - 256)
    .word SCENE_PRADERA_SPAWN_X
    .byte SCENE_PRADERA_SPAWN_Y
    ; ROOM_CASA
    .addr scene_casa_collision
    .addr scene_casa_row_offset_lo
    .addr scene_casa_row_offset_hi
    .addr scene_casa_screen_ptrs
    .byte SCENE_CASA_LEVEL_SCREENS
    .word (SCENE_CASA_LEVEL_COLS * 16 - 256)
    .word SCENE_CASA_SPAWN_X
    .byte SCENE_CASA_SPAWN_Y

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
; F4.2: la X pasa a ser de MUNDO (hasta LEVEL_WIDTH_PX, no solo 256px de
; una pantalla), por eso el píxel entero de X ahora son 2 bytes
; (player_x_px_lo/hi) en vez de 1. La Y sigue en 1 byte: el nivel no
; scrollea verticalmente todavía, 15 filas*16px=240px entra en un byte.
player_x_frac:  .res 1   ; fracción de X (antes player_x_lo)
player_x_px_lo: .res 1   ; píxel entero de X, byte bajo (antes player_x_hi)
player_x_px_hi: .res 1   ; píxel entero de X, byte alto (nuevo en F4.2)
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

; Argumentos/escratch de get_tile_collision (F3.3/F4.2): no deben usarse
; para nada más mientras se está resolviendo una consulta de colisión.
; col_x pasa a 16 bits (mundo, hasta LEVEL_WIDTH_PX); col_y sigue en 1
; byte (sin scroll vertical). col_ptr_lo/hi es el puntero indirecto
; hacia scene_pradera_collision que arma get_tile_collision.
col_x_lo: .res 1
col_x_hi: .res 1
col_y:    .res 1
col_tmp:  .res 1
col_ptr_lo: .res 1
col_ptr_hi: .res 1

; Cámara horizontal (F4.2): posición en MUNDO del borde izquierdo de la
; pantalla visible. Se recalcula entera cada frame en
; update_camera_and_streaming (sin suavizado); nmi la usa para
; PPUSCROLL y el bit de nametable de PPUCTRL.
camera_x_lo: .res 1
camera_x_hi: .res 1
cam_scratch: .res 1   ; escratch de update_camera_and_streaming, no usar en otro lado

; Streaming de pantallas (F4.2): qué pantalla lógica vive en cada
; nametable físico ahora mismo (índice 0 = $2000, 1 = $2400; ver
; update_camera_and_streaming para la regla de asignación fija
; pantalla&1 = slot), y el estado de una transmisión en curso repartida
; en varios frames vía ppu_queue_push.
nt_slot_screens: .res 2
stream_active:   .res 1
stream_screen:   .res 1
stream_slot:     .res 1
stream_src_lo:   .res 1
stream_src_hi:   .res 1
stream_dst_lo:   .res 1
stream_dst_hi:   .res 1
stream_remaining_lo: .res 1
stream_remaining_hi: .res 1

; Descriptor de la habitación ACTUAL (F4.3), cargado desde
; room_descriptors por load_room cada vez que se cambia de habitación.
; get_tile_collision/start_stream/update_camera_and_streaming leen
; estas variables en vez de símbolos fijos de compilación, porque ahora
; hay más de un mapa en el mismo binario.
room_current:      .res 1   ; ROOM_PRADERA o ROOM_CASA -- usado por respawn_player y por el destino de puertas
room_collision_lo: .res 1
room_collision_hi: .res 1
room_row_lo_ptr:   .res 2   ; puntero (zp),y hacia scene_X_row_offset_lo de la habitación actual
room_row_hi_ptr:   .res 2   ; puntero (zp),y hacia scene_X_row_offset_hi de la habitación actual
room_screen_ptrs:  .res 2   ; puntero (zp),y hacia scene_X_screen_ptrs de la habitación actual
room_screens:      .res 1   ; cantidad de pantallas de la habitación actual (antes LEVEL_SCREENS)
room_max_camera_lo: .res 1  ; cámara máxima de la habitación actual (antes MAX_CAMERA_X)
room_max_camera_hi: .res 1

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
    ; F4.2: bit0=1 = mirroring vertical (en términos de iNES), que es lo
    ; que necesita el scroll horizontal para que $2000/$2400 sean VRAM
    ; física distinta (ver nota F4.2 arriba del archivo). En MMC3 este
    ; bit del header es solo el estado inicial -- el registro propio del
    ; mapper en $A000 manda en tiempo de ejecución una vez que `reset` lo
    ; programa (con el mismo valor, $00 = vertical, por consistencia).
    .byte $41
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

    ; F4.2: mirroring vertical vía el registro propio de MMC3 ($A000,
    ; bit0: 0=vertical, 1=horizontal -- confirmar en NESdev, la
    ; nomenclatura es confusa). Vertical es lo que separa $2000/$2400 en
    ; VRAM física distinta, necesario para que el scroll horizontal
    ; revele contenido nuevo en vez de repetir la misma pantalla.
    lda #$00
    sta $A000

    ; Primer VBlank: garantiza que la PPU ya terminó su encendido antes de
    ; tocarla (secuencia estándar de arranque de NES).
@vblankwait1:
    bit $2002
    bpl @vblankwait1

    ; Limpia las 2 KB de RAM interna ($0000-$07FF) a cero, incluyendo el
    ; buffer de sombra de OAM ($0200-$02FF) y la cola de PPU.
    ;
    ; F4.2: bug real encontrado al probar scrolling (ver TASKS.md) --
    ; X sale del loop @mmc3_init en 8, no en 0 (el loop corre X de 0 a
    ; 8 exactamente). Antes de este fix, "txa" ponía A=8 (no 0) y el
    ; bucle de abajo arrancaba en X=8, así que escribía 8 (no 0) en los
    ; offsets 8-255 de cada página y NUNCA tocaba los offsets 0-7 --
    ; latente desde F1.3 porque toda variable en offset<8 o reinicializada
    ; explícitamente después (posición/velocidad del jugador, OAM, pad1
    ; recalculado cada frame) enmascaraba el error. Las variables nuevas
    ; de cámara/streaming de F4.2 cayeron en offset>=8 y nunca se
    ; reinicializan explícitamente, así que el bug se volvió visible.
    ; Fix: forzar A y X a 0 explícitamente, sin depender del valor que
    ; haya quedado en X.
    lda #$00
    ldx #$00
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

    ; Re-cero defensivo de posición fraccional y velocidad: ya deberían
    ; estar en 0 por la limpieza de RAM de arriba, pero se deja explícito
    ; aquí (inmediatamente antes de que arranque el main loop) para no
    ; depender de esa limpieza si el código de más arriba cambia alguna
    ; vez de orden. La posición/estado real de Chiquito (F3.2/F3.3) la
    ; pone `load_room` más abajo, igual que la carga de nametables
    ; (F4.3: ahora es una habitación entre varias, no un paso fijo
    ; de `reset`).
    lda #0
    sta player_x_frac
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

    ; F4.3: load_room hace todo lo que antes hacía `reset` directamente
    ; (cargar nametable(s), reiniciar cámara/streaming, posicionar a
    ; Chiquito) -- ahora generalizado para poder repetirse cada vez que
    ; se cruza una puerta, no solo al arrancar. Deja fondo+sprites
    ; habilitados al volver (PPUMASK), así que no hace falta nada más
    ; después de esta llamada.
    lda #ROOM_PRADERA
    jsr load_room

mainloop:
    lda frame_ready
    beq mainloop            ; espera a que el NMI marque el frame como listo
    lda #$00
    sta frame_ready

    jsr read_controller1     ; F3.1: actualiza pad1/pad1_prev/pad1_pressed
    jsr update_player        ; F3.2: física + escribe posición/tile/flip al OAM
    jsr update_camera_and_streaming ; F4.2: cámara + streaming de pantallas

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

    ; F4.2: escribe PPUSCROLL y el bit de nametable de PPUCTRL cada
    ; frame. Tiene que ir DESPUÉS de ppu_queue_flush: $2005 y $2006
    ; comparten el mismo latch interno de "primer/segundo byte", y cada
    ; entrada de la cola escribe $2006 dos veces (par) -- el latch
    ; siempre vuelve al mismo estado con el que entró a este NMI, así
    ; que es seguro escribir $2005 (X, luego Y) justo después, sin
    ; necesidad de leer $2002 para resetear el latch.
    lda camera_x_hi
    and #1
    ora #PPUCTRL_BASE
    sta $2000
    lda camera_x_lo
    sta $2005
    lda #$00
    sta $2005               ; Y scroll = 0: todavía no hay scroll vertical

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
; contiene el punto de píxel de MUNDO (col_x_hi:col_x_lo, col_y), DENTRO
; DE LA HABITACIÓN ACTUAL (room_current). Metatiles de 16x16px; índice
; = fila*ancho_de_la_habitación + columna.
;
; F4.2: a diferencia de F3.3 (una sola pantalla de 16 columnas, donde
; fila*16 era literalmente "el nibble alto de col_y"), un ancho de nivel
; que no es potencia de 2 no permite el truco de enmascarar bits para
; la fila. En vez de multiplicar en tiempo de ejecución, se usa una
; tabla precalculada por mapa (tools/map2scene.py genera
; scene_X_row_offset_lo/hi) y un puntero indirecto de 16 bits.
; F4.3: con más de un mapa en el mismo binario, ya no se puede indexar
; directo contra `scene_pradera_row_offset_*`/`scene_pradera_collision`
; (símbolos fijos de compilación) -- `load_room` carga en
; room_row_lo_ptr/room_row_hi_ptr/room_collision_lo/hi los de la
; habitación actual, y aquí se leen esos indirectamente.
.proc get_tile_collision
    ; fila = col_y >> 4 (0-14; cabe en 1 byte, no hay scroll vertical).
    lda col_y
    lsr a
    lsr a
    lsr a
    lsr a
    tay

    ; col_ptr = room_collision + row_offset[fila] (de la habitación actual)
    lda (room_row_lo_ptr),y
    clc
    adc room_collision_lo
    sta col_ptr_lo
    lda (room_row_hi_ptr),y
    adc room_collision_hi
    sta col_ptr_hi

    ; columna = col_x (16 bits) >> 4 (0-47 como mucho; tras desplazar 4
    ; veces el valor de 16 bits, el byte alto queda en 0 porque ningún
    ; mapa de este proyecto llega a 4096px de ancho -- el resultado
    ; cabe entero en el byte bajo). Técnica estándar: LSR del byte alto
    ; seguido de ROR del bajo, 4 veces, propaga el acarreo entre ambos
    ; bytes como una sola división.
    lda col_x_hi
    sta col_tmp
    lda col_x_lo
    lsr col_tmp
    ror a
    lsr col_tmp
    ror a
    lsr col_tmp
    ror a
    lsr col_tmp
    ror a

    ; col_ptr += columna (suma de 8 bits sobre el puntero de 16 bits)
    clc
    adc col_ptr_lo
    sta col_ptr_lo
    bcc @no_carry
    inc col_ptr_hi
@no_carry:

    ldy #$00
    lda (col_ptr_lo),y
    rts
.endproc

; Prepara una consulta de colisión para una esquina del hitbox del
; jugador: col_x (16 bits) = player_x_px (16 bits, de mundo) + A, donde
; A es un offset chico (0, PLAYER_HITBOX_W o PLAYER_HITBOX_W-1 en todo
; este archivo). No toca col_y -- el llamador lo fija por separado
; (offset_y, de 1 byte, sin scroll vertical).
.proc set_col_x
    clc
    adc player_x_px_lo
    sta col_x_lo
    lda player_x_px_hi
    adc #0
    sta col_x_hi
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
    jmp @animate             ; refresca el OAM ya en la nueva habitación este mismo frame
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
    ; F4.2: posición de mundo de 16 bits (frac + px_lo + px_hi). vx sigue
    ; siendo 16 bits con signo (frac + entero con signo); su byte alto
    ; se extiende de signo ($00 o $FF) hacia el tercer byte de la suma
    ; -- ver nota F4.2 arriba del archivo.
    clc
    lda player_x_frac
    adc player_vx_lo
    sta player_x_frac
    lda player_x_px_lo
    adc player_vx_hi
    sta player_x_px_lo
    lda player_vx_hi
    bmi @apply_x_ext_neg
    lda #$00
    jmp @apply_x_ext
@apply_x_ext_neg:
    lda #$FF
@apply_x_ext:
    adc player_x_px_hi       ; usa el acarreo de la suma anterior (carry preservado por bmi/jmp)
    sta player_x_px_hi

    ; --- Colisión horizontal (F3.3): solo sólido bloquea; plataformas y
    ; peligros no detienen el movimiento lateral. ---
    lda player_vx_lo
    ora player_vx_hi
    beq @hcol_done           ; vx == 0: no se movió, nada que resolver
    lda player_vx_hi
    bmi @hcol_left

@hcol_right:
    lda #PLAYER_HITBOX_W
    jsr set_col_x
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
    ; borde izquierdo del tile golpeado (de mundo, 16 bits) menos el
    ; ancho del hitbox -- floor-a-16 de un valor de 16 bits es igual a
    ; enmascarar solo el byte bajo, porque 16 divide exacto a 256.
    lda col_x_lo
    and #$F0
    sec
    sbc #PLAYER_HITBOX_W
    sta player_x_px_lo
    lda col_x_hi
    sbc #0
    sta player_x_px_hi
    lda #0
    sta player_vx_lo
    sta player_vx_hi
    jmp @hcol_done

@hcol_left:
    lda #0
    jsr set_col_x
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
    ; borde derecho del tile golpeado (de mundo, 16 bits).
    lda col_x_lo
    and #$F0
    clc
    adc #16
    sta player_x_px_lo
    lda col_x_hi
    adc #0
    sta player_x_px_hi
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
    lda #0
    jsr set_col_x
    lda player_y_hi
    clc
    adc #PLAYER_HITBOX_H
    sta col_y
    jsr get_tile_collision
    cmp #COLLISION_SOLID
    beq @vcol_floor_hit
    cmp #COLLISION_PLATFORM
    beq @vcol_floor_hit
    lda #(PLAYER_HITBOX_W-1)
    jsr set_col_x
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
    lda #0
    jsr set_col_x
    lda player_y_hi
    sta col_y
    jsr get_tile_collision
    cmp #COLLISION_SOLID
    beq @vcol_ceiling_hit
    lda #(PLAYER_HITBOX_W-1)
    jsr set_col_x
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

    lda #0
    jsr set_col_x
    lda player_y_hi
    sta col_y
    jsr get_tile_collision
    cmp #COLLISION_HAZARD
    beq @hazard_hit

    lda #(PLAYER_HITBOX_W-1)
    jsr set_col_x
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

    lda #0
    jsr set_col_x
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
    ; --- Puerta (F4.3): si alguna de las dos esquinas de abajo del
    ; hitbox toca una celda de puerta, cambia de habitación. Solo 2
    ; esquinas (no las 4 del chequeo de peligro) porque las puertas de
    ; este milestone están pensadas para entrarse de frente, parado
    ; sobre el piso -- no hace falta cubrir las esquinas de arriba.
    ; No se revisa durante HURT/DEAD (igual que el peligro) para no
    ; interrumpir esos estados con temporizador propio. Con solo 2
    ; habitaciones, el destino es simplemente "la otra" (room_current
    ; EOR 1) -- no hay todavía un mapa de puertas->destinos.
    lda player_state
    cmp #STATE_HURT
    beq @door_skip
    cmp #STATE_DEAD
    beq @door_skip

    lda #0
    jsr set_col_x
    lda player_y_hi
    clc
    adc #(PLAYER_HITBOX_H-1)
    sta col_y
    jsr get_tile_collision
    cmp #COLLISION_DOOR
    beq @door_hit

    lda #(PLAYER_HITBOX_W-1)
    jsr set_col_x
    jsr get_tile_collision   ; col_y sigue siendo el borde inferior
    cmp #COLLISION_DOOR
    bne @door_skip

@door_hit:
    lda room_current
    eor #1
    jsr load_room
    jmp @animate
@door_skip:

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

    ; Posición real -> OAM. Y no cambia (sin scroll vertical). X es de
    ; MUNDO (F4.2); el OAM necesita X de PANTALLA, así que se resta la
    ; cámara -- una resta de 8 bits alcanza porque ambos valores están
    ; dentro de la misma pantalla visible de 256px (si camera_x está bien
    ; recortado, player_x_px_lo - camera_x_lo siempre cae en 0-255).
    lda player_y_hi
    sta oam_buffer+0
    lda player_x_px_lo
    sec
    sbc camera_x_lo
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

; Reaparece a Chiquito en el punto de aparición de la habitación ACTUAL
; (no siempre la pradera -- F4.3), limpio de velocidad, y vuelve a
; STATE_IDLE. Usado al expirar STATE_DEAD. Recargar toda la habitación
; (en vez de solo reposicionar) es más trabajo del necesario para este
; caso, pero reutiliza `load_room` entero sin duplicar su lógica -- y
; como solo pasa tras DEAD_DURATION frames, el costo extra no importa.
.proc respawn_player
    lda room_current
    jsr load_room
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

; Cambia de habitación (F4.3): A = ROOM_PRADERA/ROOM_CASA. Usado por
; `reset` (habitación inicial), por el chequeo de puertas en
; update_player, y por respawn_player (recarga la habitación actual).
; Hace todo lo que antes hacía `reset` directamente para una sola
; escena fija: lee el descriptor de la habitación (room_descriptors),
; apaga el renderizado, recarga el/los nametable(s) físicos completos
; de una sola vez (no por la cola de VBlank -- esto es un cambio
; discreto, no scroll cuadro a cuadro; un parpadeo de un frame es
; normal y esperado en una transición de habitación, igual que en
; cualquier juego de NES de la época), reposiciona a Chiquito en el
; punto de aparición de la nueva habitación, reinicia la cámara y
; cualquier streaming en curso, y vuelve a encender el renderizado.
.proc load_room
    sta room_current

    ; X = room_id * ROOM_DESC_SIZE. Con solo 2 habitaciones (ver nota de
    ; ROOM_DESC_SIZE arriba) alcanza con una rama en vez de multiplicar
    ; de verdad. Se vuelve a leer room_current (STA no toca las
    ; banderas, así que no se puede ramificar directo sobre el valor
    ; que se acaba de guardar).
    lda room_current
    bne @desc_room1
    ldx #0
    jmp @desc_ready
@desc_room1:
    ldx #ROOM_DESC_SIZE
@desc_ready:

    lda room_descriptors+0,x
    sta room_collision_lo
    lda room_descriptors+1,x
    sta room_collision_hi
    lda room_descriptors+2,x
    sta room_row_lo_ptr
    lda room_descriptors+3,x
    sta room_row_lo_ptr+1
    lda room_descriptors+4,x
    sta room_row_hi_ptr
    lda room_descriptors+5,x
    sta room_row_hi_ptr+1
    lda room_descriptors+6,x
    sta room_screen_ptrs
    lda room_descriptors+7,x
    sta room_screen_ptrs+1
    lda room_descriptors+8,x
    sta room_screens
    lda room_descriptors+9,x
    sta room_max_camera_lo
    lda room_descriptors+10,x
    sta room_max_camera_hi

    ; Reposiciona a Chiquito en el punto de aparición de la habitación.
    lda room_descriptors+11,x
    sta player_x_px_lo
    lda room_descriptors+12,x
    sta player_x_px_hi
    lda room_descriptors+13,x
    sta player_y_hi
    lda #0
    sta player_x_frac
    sta player_y_lo
    sta player_vx_lo
    sta player_vx_hi
    sta player_vy_lo
    sta player_vy_hi
    sta camera_x_lo
    sta camera_x_hi
    sta state_timer
    sta stream_active        ; cancela cualquier streaming en curso de la habitación anterior
    lda #1
    sta player_on_ground
    sta player_facing_right
    lda #STATE_IDLE
    sta player_state

    ; Apaga el renderizado mientras se recarga VRAM -- un cambio de
    ; habitación es un corte discreto, no algo que tenga que repartirse
    ; en VBlanks sucesivos como el streaming de F4.2.
    lda #$00
    sta $2001

    bit $2002
    lda #$20
    sta $2006
    lda #$00
    sta $2006
    ldy #$00
    lda (room_screen_ptrs),y
    sta pbulk_src
    iny
    lda (room_screen_ptrs),y
    sta pbulk_src+1
    lda #<1024
    sta pbulk_len
    lda #>1024
    sta pbulk_len+1
    jsr ppu_copy_bulk
    lda #0
    sta nt_slot_screens+0

    ; Si la habitación tiene una segunda pantalla, se precarga también
    ; (igual que hacía `reset` para el nivel inicial) -- si no, el otro
    ; nametable físico queda con lo que haya quedado de la habitación
    ; anterior, pero nunca se vuelve visible: con una sola pantalla la
    ; cámara queda siempre en 0 (room_max_camera=0), así que PPUSCROLL
    ; nunca revela el nametable contiguo.
    lda room_screens
    cmp #2
    bcc @skip_screen1
    bit $2002
    lda #$24
    sta $2006
    lda #$00
    sta $2006
    ldy #2
    lda (room_screen_ptrs),y
    sta pbulk_src
    iny
    lda (room_screen_ptrs),y
    sta pbulk_src+1
    lda #<1024
    sta pbulk_len
    lda #>1024
    sta pbulk_len+1
    jsr ppu_copy_bulk
    lda #1
    sta nt_slot_screens+1
@skip_screen1:

    bit $2002
    lda #$00
    sta $2005
    sta $2005
    lda #PPUCTRL_BASE        ; camera_x_hi ya es 0 aquí, no hace falta ajustar el bit de nametable
    sta $2000
    lda #%00011110           ; PPUMASK: fondo+sprites, incluyendo los 8px izquierdos
    sta $2001

    rts
.endproc

; Cámara horizontal + streaming de pantallas (F4.2). Llamada una vez por
; frame desde el main loop, después de update_player. Dos trabajos:
;   1) Recalcula camera_x (entera, sin suavizado) = clamp(player_x_px -
;      CAMERA_OFFSET, 0, room_max_camera). nmi la usa para PPUSCROLL y el
;      bit de nametable de PPUCTRL.
;   2) Si la pantalla lógica que debería verse (la actual o la
;      siguiente, según hacia dónde mira la cámara) no es la que ya está
;      cargada en su nametable físico correspondiente
;      (nt_slot_screens[pantalla AND 1]), arranca una transmisión hacia
;      ese nametable repartida en varios frames (ver @advance_stream),
;      reutilizando ppu_queue_push -- nunca se escribe VRAM directo
;      aquí, esto corre fuera de VBlank.
; Regla de asignación de slot (fija, no cambia en tiempo de ejecución):
; slot = pantalla_lógica AND 1 (pantalla 0,2,4.. -> $2000; 1,3,5.. ->
; $2400). Como dos pantallas consecutivas siempre tienen paridad
; distinta, "la actual" y "la siguiente" nunca compiten por el mismo
; slot en el mismo frame.
.proc update_camera_and_streaming
    ; target = player_x_px (16 bits) - CAMERA_OFFSET, con signo.
    sec
    lda player_x_px_lo
    sbc #CAMERA_OFFSET
    sta camera_x_lo
    lda player_x_px_hi
    sbc #0
    sta camera_x_hi

    ; clamp inferior: si camera_x < 0 (con signo), camera_x = 0.
    lda camera_x_hi
    bpl @clamp_high_check
    lda #0
    sta camera_x_lo
    sta camera_x_hi
    jmp @after_clamp
@clamp_high_check:
    ; clamp superior: si camera_x > room_max_camera, camera_x = room_max_camera.
    lda camera_x_lo
    sta cmp_a_lo
    lda camera_x_hi
    sta cmp_a_hi
    lda room_max_camera_lo
    sta cmp_b_lo
    lda room_max_camera_hi
    sta cmp_b_hi
    jsr cmp16_signed         ; N=1 si camera_x < room_max_camera
    bmi @after_clamp
    lda room_max_camera_lo
    sta camera_x_lo
    lda room_max_camera_hi
    sta camera_x_hi
@after_clamp:

    ; --- Streaming: si ya hay una transmisión en curso, solo avanzarla
    ; (presupuesto de STREAM_BUDGET bytes/frame); si no, revisar si hace
    ; falta arrancar una nueva. ---
    lda stream_active
    bne @advance_stream

    ; ¿La pantalla actual (camera_x_hi) está en el slot que le toca?
    lda camera_x_hi
    sta cam_scratch
    and #1
    tax
    lda cam_scratch
    cmp nt_slot_screens,x
    beq @check_next
    sta stream_screen
    stx stream_slot
    jsr start_stream
    rts

@check_next:
    ; ¿La pantalla siguiente está en el slot que le toca? (recortada al
    ; final de la habitación actual -- no hay pantalla room_screens que
    ; transmitir).
    lda cam_scratch
    clc
    adc #1
    cmp room_screens
    bcc @next_in_range
    lda room_screens
    sec
    sbc #1
@next_in_range:
    sta cam_scratch
    and #1
    tax
    lda cam_scratch
    cmp nt_slot_screens,x
    beq @nothing_to_stream
    sta stream_screen
    stx stream_slot
    jsr start_stream
@nothing_to_stream:
    rts

@advance_stream:
    ; Presupuesto en cam_scratch, no en X: ppu_queue_push usa X
    ; internamente (ver su proc más abajo) y lo dejaría en un valor
    ; distinto al que necesitamos para contar este bucle.
    ldy #$00                 ; índice fijo en 0: se avanza el puntero mismo
    lda #STREAM_BUDGET
    sta cam_scratch
@push_loop:
    lda stream_remaining_lo
    ora stream_remaining_hi
    beq @stream_finished

    lda (stream_src_lo),y
    sta pq_data
    lda stream_dst_hi
    sta pq_addr_hi
    lda stream_dst_lo
    sta pq_addr_lo
    jsr ppu_queue_push

    inc stream_src_lo
    bne @src_no_carry
    inc stream_src_hi
@src_no_carry:
    inc stream_dst_lo
    bne @dst_no_carry
    inc stream_dst_hi
@dst_no_carry:

    lda stream_remaining_lo
    bne @rem_dec_lo
    dec stream_remaining_hi
@rem_dec_lo:
    dec stream_remaining_lo

    dec cam_scratch
    beq @budget_done
    jmp @push_loop
@budget_done:
    rts

@stream_finished:
    lda stream_slot
    tax
    lda stream_screen
    sta nt_slot_screens,x
    lda #0
    sta stream_active
    rts
.endproc

; Arranca una transmisión de la pantalla lógica stream_screen hacia el
; nametable físico stream_slot (0=$2000, 1=$2400). Llamado solo desde
; update_camera_and_streaming, nunca cuando stream_active ya está en 1.
; F4.3: room_screen_ptrs (cargado por load_room) apunta a la tabla de
; punteros de pantalla de la habitación actual -- ya no hay un único
; scene_pradera_screen_ptrs fijo de compilación.
.proc start_stream
    lda stream_screen
    asl a                     ; *2: cada entrada de la tabla de punteros son 2 bytes
    tay
    lda (room_screen_ptrs),y
    sta stream_src_lo
    iny
    lda (room_screen_ptrs),y
    sta stream_src_hi

    lda #<1024
    sta stream_remaining_lo
    lda #>1024
    sta stream_remaining_hi

    lda stream_slot
    beq @slot0
    lda #$24
    jmp @slot_set
@slot0:
    lda #$20
@slot_set:
    sta stream_dst_hi
    lda #$00
    sta stream_dst_lo

    lda #1
    sta stream_active
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
