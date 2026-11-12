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
; segmento CHARS, justo después de los tiles de fondo.
;
; F5.1b (CHR-ROM de fondo y sprites separados): lo anterior era cierto
; solo mientras R0-R5 del MMC3 apuntaban los 6 al banco físico 0 (pattern
; table de fondo y de sprites mostraban los mismos bytes, de ahí el +12
; artificial en los índices TILE_CHIQUITO_*). Ahora R0/R1 fijan el fondo
; en los primeros 4KB físicos y R2-R5 fijan los sprites en los
; siguientes 4KB (align explícito antes de incluir los sprites) --
; cada pattern table tiene sus 256 tiles propios, sin compartir bytes.
; Ver la nota completa junto a mmc3_init_values y a los TILE_*.
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

; F5.1b (reparto de CHR-ROM entre fondo y sprites): antes de esto, R0-R5
; apuntaban los 6 al mismo banco físico 0, así que pattern table de fondo
; ($0000-$0FFF) y de sprites ($1000-$1FFF) mostraban los mismos bytes
; físicos y los tiles de sprite debían numerarse con un +12 artificial
; para no pisar los 12 tiles de fondo. Con R0=$00/R1=$01 (banco 0/1, de
; 2KB cada uno) el fondo tiene sus 4KB propios (256 tiles, de los cuales
; solo 0-11 están en uso), y R2-R5=$04-$07 (bancos de 1KB) le dan a los
; sprites otros 4KB propios, también 256 tiles, SIN compartir bytes con
; el fondo. El `.align $1000` de abajo rellena con relleno ($00, sin
; impacto visual porque nada referencia esos tiles) justo hasta ese
; límite de 4KB para que los sprites empiecen exactamente donde R2-R5
; esperan verlos. Ver mmc3_init_values. Confirmado sin regresión visual
; corriendo tools/test_tiles.lua y tools/test_sprites.lua tras el cambio
; (ver TASKS.md).
.segment "CHARS"
.align $1000
; F5.1c: las 5 poses reales de Chiquito (conversión fiel del concept
; art -- ver tools/gen_chiquito_poses.py), 75 tiles (0-74).
.include "../dist/tiles_chiquito.s"
; F2.3/F4.4: enemigo/ítem/plataforma de prueba, justo después (75-77).
.include "../dist/tiles_scenery.s"
; F5.1b: Sanchopau a continuación (78-93), dentro del mismo banco de 4KB
; de sprites (94 de los 256 tiles disponibles ahí usados -- de sobra).
; El resto del elenco (Mothman/Abuelito/Diablito/Marcianito, generados
; por tools/gen_cast_sprites.py) no se incluye todavía: no tienen
; habitación propia donde aparecer, así que mapearlos ahora solo
; gastaría presupuesto de pattern table sin ningún uso real.
.include "../dist/tiles_cast.s"

; F5.1c: por pose, qué tile ABSOLUTO (dentro de la pattern table de
; sprites de arriba) y qué subpaleta de hardware (0 o 1) usa cada una de
; las 16 celdas de la grilla 4x4 -- $FF en la tabla de tile significa
; "sin tile real ahí, ocultar ese sprite" (las poses no siempre llenan
; las 16 celdas). Generadas por tools/gen_chiquito_poses.py directo
; desde el JSON de cada pose, no a mano.
.include "../dist/chiquito_pose_tables.s"

; Tiles de escenario (F2.3/F4.4), justo después de las 75 de Chiquito.
TILE_ENEMY                 = 75
TILE_ITEM                  = 76
TILE_PLATFORM_SPRITE       = 77
; Primer tile libre después de Chiquito/enemigo/ítem/plataforma,
; disponible para el elenco nuevo (F5.1b).
TILE_CAST_BASE             = 78

; Sanchopau: 32x32 (4x4 tiles = 16), orden TL..BR por filas (mismo orden
; que el JSON de nes_referencias: tile = (y/8)*4 + (x/8)). Pose única --
; esa conversión fiel del concept art no trae caminar/salto dibujados
; (a diferencia de Chiquito), así que Sanchopau se desliza con esta
; misma pose en vez de animar piernas (ver update_npc). Rediseñar esas
; poses a mano quedó peor que esta conversión directa -- ver el
; registro de la tarea en TASKS.md.
TILE_SANCHOPAU_BASE = TILE_CAST_BASE

; F5.1c: identificadores de pose de Chiquito, para elegir qué par de
; tablas (chiquito_<pose>_tile / _pal) usar en draw_player_metasprite.
; No son los STATE_* de la máquina de estados: STATE_WALK se reparte
; entre POSE_WALK1/WALK2/RUN según la velocidad real (ver @animate en
; update_player), y STATE_JUMP/STATE_FALL comparten POSE_JUMP.
POSE_IDLE  = 0
POSE_WALK1 = 1
POSE_WALK2 = 2
POSE_RUN   = 3
POSE_JUMP  = 4
; Umbral de velocidad horizontal (valor absoluto, byte alto de punto
; fijo 8.8) a partir del cual caminar pasa a correr. MOVE_MAX_SPEED es
; $0180 (1.5px/frame); 1 de byte alto = 1px/frame entero, así que este
; umbral son ~1.0px/frame -- con MOVE_ACCEL=$0020 tarda unos 0.5s en
; alcanzarlo sosteniendo una dirección, suficiente para que se note la
; transición caminar->correr en vez de ser instantánea.
RUN_SPEED_THRESHOLD = 1

; Punteros (lo/hi por separado, indexados por POSE_*) a las tablas
; chiquito_<pose>_tile/_pal de dist/chiquito_pose_tables.s --
; draw_player_metasprite los usa para cargar chiquito_tile_ptr/
; chiquito_pal_ptr sin una cadena de 5 CMP/BEQ.
.segment "RODATA"
chiquito_pose_tile_lo:
    .byte <chiquito_idle_tile, <chiquito_walk1_tile, <chiquito_walk2_tile, <chiquito_run_tile, <chiquito_jump_tile
chiquito_pose_tile_hi:
    .byte >chiquito_idle_tile, >chiquito_walk1_tile, >chiquito_walk2_tile, >chiquito_run_tile, >chiquito_jump_tile
chiquito_pose_pal_lo:
    .byte <chiquito_idle_pal, <chiquito_walk1_pal, <chiquito_walk2_pal, <chiquito_run_pal, <chiquito_jump_pal
chiquito_pose_pal_hi:
    .byte >chiquito_idle_pal, >chiquito_walk1_pal, >chiquito_walk2_pal, >chiquito_run_pal, >chiquito_jump_pal

; F5.2: desplazamiento de Y hacia arriba, por frame, durante los
; primeros 16 frames del ciclo de salto del perseguidor
; (ENEMY_CHASER_HOP_PERIOD); los 16 frames restantes del ciclo no usan
; la tabla (reposa en el piso, offset 0). Pico de 8px a mitad del arco.
enemy_hop_offset:
    .byte 0,1,3,5,6,7,8,8,8,8,7,6,5,3,1,0

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
COLLISION_CHECKPOINT = 5
COLLISION_SWITCH     = 6
COLLISION_LOCKED_DOOR = 7

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

; F4.4 (elementos de escenario).
;
; Plataforma móvil: un solo ejemplo hardcodeado (no un sistema general
; de N plataformas -- eso es trabajo de F5.1, el sistema de entidades).
; Vive solo en pradera, oscila horizontalmente entre PLATFORM_MIN_X y
; PLATFORM_MAX_X a PLATFORM_Y fijo, 1px/frame. Ver update_platform.
PLATFORM_Y     = 80
PLATFORM_MIN_X = 280
PLATFORM_MAX_X = 340
PLATFORM_WIDTH = 16     ; 2 sprites de 8px uno al lado del otro
PLATFORM_SPEED = 1
; Tolerancia de aterrizaje (en píxeles): si el pie de Chiquito cae
; dentro de [PLATFORM_Y, PLATFORM_Y+4] este frame (en vez de exigir una
; igualdad exacta), cuenta como aterrizaje -- a MAX_FALL_SPEED (4px/
; frame) el pie puede "saltarse" el píxel exacto de la plataforma en
; un solo frame si se exigiera igualdad estricta.
PLATFORM_LANDING_TOLERANCE = 4

; Interruptor + puerta bloqueada: un solo par hardcodeado (switch_casa_open
; es la única bandera), viven en la Casa Pipapita. Al tocar el
; interruptor, además de abrir la puerta bloqueada (ver
; COLLISION_LOCKED_DOOR en get_tile_collision), se transmite un cambio
; visual real a VRAM (el interruptor pasa a verse "presionado") en las
; direcciones de nametable fijas de abajo -- conocidas en tiempo de
; compilación porque hay un solo interruptor en un mapa de 1 sola
; pantalla, siempre cargada en el nametable físico $2000.
SWITCH_NT_TL = $224C
SWITCH_NT_TR = $224D
SWITCH_NT_BL = $226C
SWITCH_NT_BR = $226D
TILE_SWITCH_PRESSED = 3   ; T_GROUND_FILL de tiles_pradera (ver tools/map2scene.py)

; F5.1 (sistema de entidades). Ver la nota junto a las tablas en el
; segmento BSS para el porqué de MAX_ENTITIES=8.
MAX_ENTITIES = 8
ENTITY_TYPE_ENEMY = 0
ENTITY_TYPE_ITEM  = 1
; F5.2: una entidad más, para los proyectiles del enemigo de ataque a
; distancia -- reusa toda la infraestructura de F5.1 (SoA, límite de 8,
; dibujado genérico en update_entities) en vez de un sistema aparte.
ENTITY_TYPE_PROJECTILE = 2

; F5.2 (enemigos básicos). entity_behavior solo se lee cuando
; entity_type=ENTITY_TYPE_ENEMY (un ítem/proyectil no tiene IA). Mismo
; hitbox 8x8 que el jugador para el chequeo de contacto (nombre propio
; en vez de reusar PLAYER_HITBOX_* porque conceptualmente son cosas
; distintas, aunque el valor coincida).
ENEMY_BEHAVIOR_PATROL = 0
ENEMY_BEHAVIOR_CHASER = 1
ENEMY_BEHAVIOR_RANGED = 2
ENTITY_HITBOX_W = 8
ENTITY_HITBOX_H = 8

; Enemigo patrullero: un solo ejemplo hardcodeado (mismo patrón que
; PLATFORM_MIN_X/MAX_X), rebota 1px cada 2 frames dentro del tramo de
; piso sólido de la pantalla 0, antes del hueco en columnas 13-14
; (208-224px) -- MAX_X=200 deja margen para que el sprite de 8px no se
; dibuje nunca sobre el hueco.
ENEMY_PATROL_MIN_X = 160
ENEMY_PATROL_MAX_X = 200
ENEMY_PATROL_SPEED_DIVISOR = %00000001

; Enemigo perseguidor/saltador: vive en la pantalla 1 (piso sólido
; corrido, sin huecos ni peligros -- ver assets/maps/pradera.txt),
; persigue a Chiquito en X de verdad (no un rango fijo) hasta quedar a
; ENTITY_HITBOX_W de distancia, y agrega un salto visual periódico
; (offset de Y, ver enemy_hop_offset) para que sea un comportamiento
; realmente distinto del patrullero y no solo otra posición.
ENEMY_CHASER_SPAWN_X = 380
; 152 = altura real de "parado sobre el piso" en pradera (160 de tope
; del suelo - 8 del hitbox -- mismo valor que SCENE_PRADERA_SPAWN_Y).
; F2.3 había dejado el enemigo/ítem de prueba con Y arbitrarios (179,
; 99) porque eran puramente decorativos, sin colisión real contra
; nada; con el contacto jugador-enemigo real de F5.2 (check_enemy_
; contact), un enemigo "parado en el piso" tiene que usar la MISMA
; convención de Y que el jugador (tope del hitbox) para que tocarlo
; de verdad funcione -- confirmado real: con 179 (27px más abajo que
; donde el jugador puede pararse) el contacto nunca se disparaba en
; juego normal, solo se podía provocar tele transportando al jugador
; dentro del piso sólido.
ENEMY_CHASER_BASE_Y  = 152
ENEMY_CHASER_HOP_PERIOD = 32   ; 16 frames de salto (tabla) + 16 de reposo en el piso
; Distancia a la que el perseguidor deja de acercarse -- A PROPÓSITO
; más grande que ENTITY_HITBOX_W (el umbral de contacto/daño real de
; check_enemy_contact). Si fueran el mismo valor, el perseguidor
; quedaría parado justo en el borde del hitbox del jugador: en cuanto
; termina la invulnerabilidad de HURT, el contacto se dispara de nuevo
; de inmediato (confirmado real con tools/test_enemies.lua antes de
; este margen). Con 12 > 8 queda parado claramente afuera del rango de
; daño -- hace falta que el jugador avance para que lo toque.
ENEMY_CHASER_STOP_DISTANCE = 12

; Enemigo de ataque a distancia: fijo en X, también en la pantalla 1.
; Cada ENEMY_RANGED_FIRE_COOLDOWN frames dispara un proyectil horizontal
; hacia el lado donde esté Chiquito en ese instante -- el proyectil NO
; vuelve a apuntar después de salir (ver projectile_step). El
; proyectil desaparece solo (temporizador, no por salir de pantalla) y
; el atacante puede disparar otro al terminar el cooldown -- la regla
; de aparición/desaparición que pide F5.2.
ENEMY_RANGED_SPAWN_X = 460
ENEMY_RANGED_Y = 152   ; misma altura real de piso que ENEMY_CHASER_BASE_Y, ver la nota ahí
ENEMY_RANGED_FIRE_COOLDOWN = 90
PROJECTILE_SPEED = 2
PROJECTILE_LIFETIME = 60

; F5.3 (armas y proyectiles). El GAME_DESIGN_DOCUMENT.md describe el
; ataque básico de Chiquito como "de corto alcance"; en vez de un swing
; de melé (hitbox fija pegada al jugador) se implementa como un
; proyectil de verdad -- TASKS.md titula esta fase "Armas y
; PROYECTILES" y pide explícitamente "crear proyectiles"/"administrar
; límite de proyectiles" como entregables. Reusa toda la
; infraestructura de proyectiles de F5.2 (misma entidad, mismo
; projectile_step, misma PROJECTILE_SPEED) -- entity_type distingue
; "proyectil enemigo" de "proyectil del jugador" porque check_enemy_
; contact (daña al jugador) y check_player_attacks (daña enemigos,
; nuevo) necesitan tratarlos distinto. El "corto alcance" del diseño se
; logra con una vida más corta (ENEMY_RANGED usa 60 frames = 120px;
; esto usa 20 frames = 40px, un tercio), no con una velocidad distinta
; -- mantiene projectile_step 100% genérico, sin un campo de velocidad
; por entidad que nada más necesita todavía.
ENTITY_TYPE_PLAYER_PROJECTILE = 3
PLAYER_PROJECTILE_LIFETIME = 20
; Límite de proyectiles del jugador simultáneos (F5.3: "administrar
; límite de proyectiles"). Con el límite en 1, basta con comprobar "no
; hay ninguno activo todavía" (player_has_active_projectile) en vez de
; contar -- mismo resultado, menos código. Un ataque que no logra
; disparar (límite alcanzado) igual enraíza el movimiento del jugador,
; mismo comportamiento ya probado desde F3.4.
PLAYER_PROJECTILE_LIMIT = 1

; Distribución del buffer de OAM: sprites 0-7 = entidades; sprites 8-9 =
; plataforma móvil; sprites 10-25 = Chiquito (F5.1c: 16 piezas, grilla
; 4x4, ya no 4 -- ver PLAYER_OAM_BASE). Se mantiene ENTITY_OAM_BASE=4
; para no alterar el contrato del sistema de entidades.
ENTITY_OAM_BASE   = 4
PLATFORM_OAM_BASE = ENTITY_OAM_BASE + MAX_ENTITIES * 4

; F5.1c: Chiquito pasó de 4 piezas (16x16) a 16 (32x32, conversión fiel
; del concept art) -- ya no tiene sentido mantener "sprite 0 aparte +
; 3 extra" como quedó de cuando solo eran 4; ahora es un bloque propio
; de 16 sprites (64 bytes), igual patrón que ya usa Sanchopau.
PLAYER_OAM_BASE = PLATFORM_OAM_BASE + 8

; F5.1b (elenco): Sanchopau, primer personaje del elenco cableado al
; motor real (Mothman/Abuelito/Diablito/Marcianito ya tienen su CHR
; generado -- ver tools/gen_cast_sprites.py -- pero no están en ninguna
; habitación todavía). Metasprite de 32x32 (4x4 tiles, 16 sprites de
; OAM), ancla física igual que Chiquito: un punto de 8x8 (npc_x/NPC_Y)
; centrado dentro del arte, que se extiende 12px a cada lado y 24px
; hacia arriba. Solo aparece en ROOM_CASA (ver update_npc) -- por eso
; puede usar las subpaletas de sprite 1/2 (enemigo/ítem) sin chocar con
; ellas: esas solo se usan en ROOM_PRADERA (ver la nota de paleta por
; habitación en load_room).
NPC_OAM_BASE = PLAYER_OAM_BASE + 64
NPC_Y        = 152   ; misma banda de piso que SCENE_CASA_SPAWN_Y (fila 9 del mapa)
NPC_MIN_X    = 120   ; columnas 7-9 del mapa de casa_pipapita.txt: piso libre,
NPC_MAX_X    = 150   ; lejos del interruptor (columna 6) y de la puerta bloqueada (columna 10)
NPC_SPEED_DIVISOR = %00000011   ; se mueve 1px cada 4 frames -- paso tranquilo, no el del jugador

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
; OAM inicial: Y, tile, atributos, X -- solo Chiquito. Posición es un
; valor placeholder -- load_room (llamado desde reset antes del primer
; frame) la pisa con la posición real de la habitación inicial, y
; @animate la mantiene correcta todos los frames después de eso.
;
; F5.1: los sprites de "enemigo"/"coleccionable" de prueba (F2.3) ya NO
; se inicializan acá -- eran placeholders estáticos sin comportamiento
; real. Ahora viven como entidades de verdad (ver spawn_entity en
; load_room), con la misma posición/tile/atributo de antes para no
; cambiar nada visual, pero generadas y gestionadas por el sistema de
; entidades real. La plataforma móvil (F4.4) tampoco tiene entrada acá
; -- update_platform escribe Y/tile/atributo/X completos desde el
; primer frame, no necesita un valor inicial estático.
; F5.1c: este único sprite inicial (tile 0 = la celda TL de la pose
; idle, ver chiquito_idle_tile) ahora es solo 1 de las 16 piezas de
; Chiquito -- las otras 15 quedan ocultas (ya en $FF por el fill de
; arriba) hasta que @animate corra en el primer ciclo del main loop y
; dibuje el metasprite completo. Mismo criterio que antes (cuando era
; 1 de 4 piezas): un placeholder de un solo frame, no una pose real.
oam_init_data:
    .byte SCENE_PRADERA_SPAWN_Y, 0, %00000000, SCENE_PRADERA_SPAWN_X

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
; F5.1b: R0=banco 0, R1=banco 1 (ventanas CHR de 2KB) cubren $0000-$0FFF
; con los primeros 4KB físicos de CHR-ROM -- ahí vive tiles_pradera.s
; (fondo). R2-R5=bancos 4-7 (ventanas CHR de 1KB, consecutivos) cubren
; $1000-$1FFF con los SIGUIENTES 4KB físicos (offset 4096, ver el
; `.align $1000` antes de tiles_chiquito.s) -- ahí viven los sprites
; (Chiquito/enemigo/ítem/plataforma/elenco). Antes R0-R5 apuntaban los 6
; al banco 0, así que fondo y sprites mostraban los mismos bytes físicos
; y los tiles de sprite necesitaban un +12 artificial para no pisar los
; de fondo; con esta separación cada pattern table tiene sus propios 256
; tiles reales. R6,R7: ventanas PRG swappeables de 8KB ($8000-$9FFF y
; $A000-$BFFF) -> bancos 0 y 1. Todavía no hay código ni datos ahí
; (nuestro código vive en el banco fijo $E000-$FFFF), son solo valores
; conocidos para no dejar el mapper en un estado indefinido.
mmc3_init_values:
    .byte $00, $01, $04, $05, $06, $07, $00, $01

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

; Punto de control (F4.4): si checkpoint_active=1 y checkpoint_room
; coincide con la habitación que se está cargando, load_room reaparece
; ahí en vez del punto de aparición por defecto de la habitación. Un
; solo "slot" de checkpoint (no uno por habitación simultáneamente) --
; alcanza con este milestone, ver TASKS.md F4.4.
checkpoint_active: .res 1
checkpoint_room:   .res 1
checkpoint_x_lo:   .res 1
checkpoint_x_hi:   .res 1
checkpoint_y:      .res 1

; Interruptor de la Casa Pipapita (F4.4): 0=bloqueado, 1=abierto. Un
; solo interruptor en todo el juego por ahora -- RAM lo deja en 0 al
; encender, y se queda en 1 el resto de la partida una vez activado
; (no se vuelve a bloquear al salir/volver a entrar a la habitación).
switch_casa_open: .res 1

; Plataforma móvil de pradera (F4.4): posición de mundo (16 bits,
; mismo formato que player_x_px) y dirección actual (0=derecha,
; distinto de 0=izquierda). Ver update_platform.
platform_x_lo: .res 1
platform_x_hi: .res 1
platform_dir:  .res 1

; Argumentos de spawn_entity (F5.1): no deben usarse para nada más
; mientras se está armando un spawn. Mismo patrón que pq_addr_hi/lo/
; data para ppu_queue_push.
entity_arg_room: .res 1
entity_arg_type: .res 1
entity_arg_x_lo: .res 1
entity_arg_x_hi: .res 1
entity_arg_y:    .res 1
entity_arg_tile: .res 1
entity_arg_attr: .res 1

; F5.1c: punteros a las tablas de tile/paleta de la pose actual de
; Chiquito (ver draw_player_metasprite). TIENEN que vivir en zero page:
; es el único modo de direccionamiento del 6502 que permite leer una
; tabla cuya dirección se decide en tiempo de ejecución ((ptr),y). Van
; al FINAL del segmento, no en medio: varios tools/test_*.lua tienen
; hardcodeadas las direcciones absolutas de las variables de más
; arriba (posición/velocidad del jugador) -- insertar algo antes las
; habría corrido todas, rompiendo esos tests (pasó una vez, se corrigió
; moviendo esto acá).
chiquito_tile_ptr: .res 2
chiquito_pal_ptr:  .res 2

; F5.2: argumentos extra de spawn_entity (comportamiento/dirección/
; temporizador inicial, ver la nota junto a entity_arg_room) y
; escratch de las rutinas de IA de enemigos (compute_entity_dx,
; enemy_chaser_step, enemy_ranged_step). Al final del segmento por la
; misma razón documentada arriba de chiquito_tile_ptr: no correr las
; direcciones de las variables anteriores, que varios tools/test_*.lua
; ya tienen hardcodeadas.
entity_arg_behavior: .res 1
entity_arg_dir:      .res 1
entity_arg_timer:    .res 1
enemy_dx_lo:   .res 1   ; salida de compute_entity_dx (dx = entity_x - player_x, 16 bits con signo)
enemy_dx_hi:   .res 1
enemy_hop_tmp: .res 1   ; escratch de enemy_chaser_step, no usar en otro lado
enemy_save_x:  .res 1   ; guarda el índice de entidad (X) mientras enemy_ranged_step llama a spawn_entity (que usa X desde 0)

.segment "BSS"
ppu_queue_len:       .res 1
ppu_queue_overflow:  .res 1                      ; contador de escrituras descartadas por cola llena
ppu_queue_addr_hi:   .res PPU_QUEUE_CAPACITY
ppu_queue_addr_lo:   .res PPU_QUEUE_CAPACITY
ppu_queue_data:      .res PPU_QUEUE_CAPACITY

; Sistema de entidades (F5.1): estructura-de-arrays (SoA), no array-de-
; estructuras -- cada campo es su propia tabla indexada por X, el
; patrón natural en 6502 (direccionamiento "tabla,x" por campo, en vez
; de calcular el offset de un registro de N bytes cada vez). MAX_ENTITIES
; = 8 porque es exactamente el límite real de sprites por scanline del
; hardware (NESDEV) -- ninguna combinación de entidades de 1 sprite
; puede saturar una sola línea si nunca hay más de 8 activas a la vez.
; `entity_room` es la "zona" de actualización/renderizado (F5.1 pide
; "por prioridad o zona"): una entidad solo se actualiza/dibuja cuando
; `entity_room == room_current`, igual que ya hace la plataforma móvil
; con ROOM_PRADERA. `entity_type` no tiene comportamiento todavía --
; es el gancho para que F5.2 distinga IA de enemigo vs. ítem.
entity_active: .res MAX_ENTITIES
entity_room:   .res MAX_ENTITIES
entity_type:   .res MAX_ENTITIES
entity_x_lo:   .res MAX_ENTITIES
entity_x_hi:   .res MAX_ENTITIES
entity_y:      .res MAX_ENTITIES
entity_tile:   .res MAX_ENTITIES
entity_attr:   .res MAX_ENTITIES
; F5.1c: Chiquito pasó de 4 piezas desenrolladas a 16 (grilla 4x4,
; bucle fila/columna, igual patrón que Sanchopau) -- player_frame_tile
; (un solo tile base) ya no alcanza, reemplazado por player_row/col/
; row4, que recorren las tablas de pose por índice.
player_draw_x: .res 1         ; origen X de pantalla del metasprite (hitbox centrado)
player_draw_y: .res 1         ; origen Y de pantalla del metasprite (24px sobre el hitbox)
player_row:    .res 1         ; fila 0-3 dentro de la grilla 4x4 (bucle de dibujo)
player_col:    .res 1         ; columna 0-3 dentro de la grilla 4x4 (bucle de dibujo)
player_row4:   .res 1         ; player_row*4, recalculado una vez por fila

; F5.1b (NPC Sanchopau). npc_x es posición de PANTALLA, no de mundo --
; Casa es una sola pantalla fija (room_max_camera=0 ahí), así que no
; hace falta el par lo/hi de 16 bits que usa el jugador para el nivel
; con scroll. npc_facing: 0=mirando a la izquierda, 1=a la derecha
; (mismo criterio que player_facing_right).
npc_x:          .res 1
npc_facing:     .res 1
npc_draw_x:     .res 1   ; origen X de pantalla del metasprite (hitbox centrado)
npc_draw_y:     .res 1   ; origen Y de pantalla del metasprite (24px sobre el hitbox)
npc_row:        .res 1   ; fila 0-3 dentro de la grilla 4x4 del metasprite (bucle de dibujo)
npc_col:        .res 1   ; columna 0-3 dentro de la grilla 4x4 (bucle de dibujo)
npc_row4:       .res 1   ; npc_row*4, recalculado una vez por fila

; F5.2: sub-comportamiento de IA (ENEMY_BEHAVIOR_*, solo se lee cuando
; entity_type=ENTITY_TYPE_ENEMY), dirección actual (0=derecha,
; 1=izquierda -- mismo criterio que platform_dir/npc_facing; para un
; proyectil es la dirección de vuelo, fija desde que se dispara) y un
; temporizador genérico cuyo significado depende del comportamiento:
; fase del ciclo de salto (perseguidor, cuenta HACIA ARRIBA y da la
; vuelta), cooldown de disparo (atacante a distancia, cuenta hacia
; abajo) o vida restante (proyectil, cuenta hacia abajo). Al final del
; segmento BSS por la misma razón que chiquito_tile_ptr en ZEROPAGE:
; no correr las direcciones de entity_active..entity_attr ni de
; player_row/npc_* que tools/test_entities.lua y otros ya tienen
; hardcodeadas.
entity_behavior: .res MAX_ENTITIES
entity_dir:      .res MAX_ENTITIES
entity_timer:    .res MAX_ENTITIES

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

    ; Copia el primer sprite de Chiquito a su bloque de OAM (F5.1c:
    ; PLAYER_OAM_BASE, ya no el offset 0 -- F5.1: el resto -- entidades
    ; y plataforma -- ya no tienen datos iniciales estáticos, ver nota
    ; de oam_init_data).
    ldx #$00
@oam_copy:
    lda oam_init_data,x
    sta oam_buffer+PLAYER_OAM_BASE,x
    inx
    cpx #4
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

    ; F4.4: posición/dirección inicial de la plataforma móvil. No
    ; alcanza con la limpieza de RAM (dejaría platform_x en 0, fuera de
    ; [PLATFORM_MIN_X, PLATFORM_MAX_X], visible en el lugar equivocado
    ; hasta que el bucle de movimiento la arrastrara de vuelta al rango
    ; -- se deja explícito para que arranque ya dentro del rango.
    lda #<PLATFORM_MIN_X
    sta platform_x_lo
    lda #>PLATFORM_MIN_X
    sta platform_x_hi
    lda #0
    sta platform_dir         ; arranca moviéndose a la derecha

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
    jsr update_platform      ; F4.4: mueve la plataforma y escribe su OAM
    jsr update_enemies       ; F5.2: IA de enemigos + movimiento/vida de proyectiles
    jsr check_enemy_contact  ; F5.2: daño por contacto con enemigo/proyectil (HURT, igual que un peligro de tile)
    jsr check_player_attacks ; F5.3: impactos del proyectil del jugador contra enemigos
    jsr update_entities      ; F5.1: escribe el OAM de las entidades activas de la habitación actual
    jsr update_npc           ; F5.1b: patrulla y OAM de Sanchopau (solo visible en Casa)

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

    ; F4.4: una puerta bloqueada no es un tipo de colisión fijo -- su
    ; valor efectivo depende de switch_casa_open. El dato en ROM siempre
    ; dice COLLISION_LOCKED_DOOR; aquí se traduce a SOLID o EMPTY según
    ; el interruptor. Único par interruptor/puerta en este milestone,
    ; así que una sola bandera alcanza (no una tabla de N interruptores).
    cmp #COLLISION_LOCKED_DOOR
    bne @not_locked
    lda switch_casa_open
    bne @door_open
    lda #COLLISION_SOLID
    rts
@door_open:
    lda #COLLISION_EMPTY
@not_locked:
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
    ; F5.3: ahora dispara un proyectil real (ver la nota junto a
    ; ENTITY_TYPE_PLAYER_PROJECTILE) además de enraizar el movimiento.
    lda pad1_pressed
    and #PAD_B
    beq @movement_start
    lda #STATE_ATTACK
    sta player_state
    lda #ATTACK_DURATION
    sta state_timer

    ; F5.3: no dispara si ya hay un proyectil del jugador activo
    ; (PLAYER_PROJECTILE_LIMIT=1) -- el ataque igual enraíza el
    ; movimiento arriba, dispare o no.
    jsr player_has_active_projectile
    bne @movement_start

    lda player_facing_right
    bne @attack_spawn_right
@attack_spawn_left:
    lda player_x_px_lo
    sec
    sbc #PLAYER_HITBOX_W
    sta entity_arg_x_lo
    lda player_x_px_hi
    sbc #0
    sta entity_arg_x_hi
    lda #1
    sta entity_arg_dir
    jmp @attack_spawn_y
@attack_spawn_right:
    lda player_x_px_lo
    clc
    adc #PLAYER_HITBOX_W
    sta entity_arg_x_lo
    lda player_x_px_hi
    adc #0
    sta entity_arg_x_hi
    lda #0
    sta entity_arg_dir
@attack_spawn_y:
    lda player_y_hi
    sta entity_arg_y
    lda room_current
    sta entity_arg_room
    lda #ENTITY_TYPE_PLAYER_PROJECTILE
    sta entity_arg_type
    lda #TILE_ITEM            ; sin arte dedicado todavía -- ver limitaciones en TASKS.md/ASSET_MANIFEST.md
    sta entity_arg_tile
    lda #%00000001
    sta entity_arg_attr
    lda #0
    sta entity_arg_behavior
    lda #PLAYER_PROJECTILE_LIFETIME
    sta entity_arg_timer
    jsr spawn_entity

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
    ; --- Plataforma móvil (F4.4): un solo ejemplo hardcodeado, solo en
    ; pradera. No bloquea desde abajo como un tile normal -- es un
    ; sprite, así que esto corre SIEMPRE después de la colisión de
    ; tiles de arriba (que ya habrá puesto on_ground=0 si no hay nada
    ; debajo en el tilemap) y la puede sobrescribir si corresponde.
    ; bne/bmi de acá a @platform_done no entran en el rango de un
    ; branch relativo (el bloque es largo) -- se arma el salto en 2
    ; pasos (branch corto + jmp, que no tiene límite de rango).
    lda room_current
    cmp #ROOM_PRADERA
    beq @platform_room_ok
    jmp @platform_done
@platform_room_ok:
    lda player_vy_hi
    bpl @platform_landing_check
    jmp @platform_done       ; subiendo: no se puede "aterrizar" en la plataforma
@platform_landing_check:

    ; Tolerancia de aterrizaje: foot_y - PLATFORM_Y debe estar en
    ; [0, PLATFORM_LANDING_TOLERANCE] -- ver la constante para el por qué.
    lda player_y_hi
    clc
    adc #PLAYER_HITBOX_H
    sec
    sbc #PLATFORM_Y
    bpl @platform_tolerance_check
    jmp @platform_done       ; negativo: el pie todavía está arriba de la plataforma
@platform_tolerance_check:
    cmp #(PLATFORM_LANDING_TOLERANCE + 1)
    bcs @platform_done       ; muy por debajo: no es un aterrizaje válido

    ; Solape horizontal: [player_x, player_x+7] vs [platform_x, platform_x+15].
    ; player_right/platform_right en col_x_lo/hi y col_ptr_lo/hi --
    ; escratch libre aquí, get_tile_collision no corre en este chequeo.
    clc
    lda player_x_px_lo
    adc #(PLAYER_HITBOX_W-1)
    sta col_x_lo
    lda player_x_px_hi
    adc #0
    sta col_x_hi
    clc
    lda platform_x_lo
    adc #(PLATFORM_WIDTH-1)
    sta col_ptr_lo
    lda platform_x_hi
    adc #0
    sta col_ptr_hi

    ; ¿platform_right >= player_left?
    lda col_ptr_lo
    sta cmp_a_lo
    lda col_ptr_hi
    sta cmp_a_hi
    lda player_x_px_lo
    sta cmp_b_lo
    lda player_x_px_hi
    sta cmp_b_hi
    jsr cmp16_signed         ; N=1 si platform_right < player_left
    bmi @platform_done

    ; ¿player_right >= platform_left?
    lda col_x_lo
    sta cmp_a_lo
    lda col_x_hi
    sta cmp_a_hi
    lda platform_x_lo
    sta cmp_b_lo
    lda platform_x_hi
    sta cmp_b_hi
    jsr cmp16_signed         ; N=1 si player_right < platform_left
    bmi @platform_done

    ; Aterriza/viaja: encaja a Chiquito exactamente sobre la plataforma.
    lda #PLATFORM_Y
    sec
    sbc #PLAYER_HITBOX_H
    sta player_y_hi
    lda #0
    sta player_y_lo
    sta player_vy_lo
    sta player_vy_hi
    lda #1
    sta player_on_ground

    ; Lo arrastra con el movimiento de este frame de la plataforma
    ; (ver update_platform -- misma dirección, mismo PLATFORM_SPEED).
    lda platform_dir
    bne @platform_carry_left
    clc
    lda player_x_px_lo
    adc #PLATFORM_SPEED
    sta player_x_px_lo
    lda player_x_px_hi
    adc #0
    sta player_x_px_hi
    jmp @platform_done
@platform_carry_left:
    sec
    lda player_x_px_lo
    sbc #PLATFORM_SPEED
    sta player_x_px_lo
    lda player_x_px_hi
    sbc #0
    sta player_x_px_hi
@platform_done:

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
    jsr enter_hurt_state

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

    ; --- Interruptor (F4.4): mismo chequeo de 2 esquinas que puerta.
    ; Solo importa la primera vez (switch_casa_open pasa de 0 a 1);
    ; después de eso, queda abierto el resto de la partida -- no hace
    ; falta seguir revisando cada frame una vez activado.
    lda switch_casa_open
    bne @switch_skip

    lda #0
    jsr set_col_x
    lda player_y_hi
    clc
    adc #(PLAYER_HITBOX_H-1)
    sta col_y
    jsr get_tile_collision
    cmp #COLLISION_SWITCH
    beq @switch_hit

    lda #(PLAYER_HITBOX_W-1)
    jsr set_col_x
    jsr get_tile_collision   ; col_y sigue siendo el borde inferior
    cmp #COLLISION_SWITCH
    bne @switch_skip

@switch_hit:
    lda #1
    sta switch_casa_open
    ; Cambia el interruptor a su apariencia "presionado" en VRAM de
    ; verdad (4 tiles, 1 solo interruptor en el juego así que las
    ; direcciones son constantes de compilación -- ver nota de
    ; SWITCH_NT_* arriba del archivo). Vía la cola de F1.3: esto corre
    ; fuera de VBlank.
    lda #>SWITCH_NT_TL
    sta pq_addr_hi
    lda #<SWITCH_NT_TL
    sta pq_addr_lo
    lda #TILE_SWITCH_PRESSED
    sta pq_data
    jsr ppu_queue_push
    lda #>SWITCH_NT_TR
    sta pq_addr_hi
    lda #<SWITCH_NT_TR
    sta pq_addr_lo
    lda #TILE_SWITCH_PRESSED
    sta pq_data
    jsr ppu_queue_push
    lda #>SWITCH_NT_BL
    sta pq_addr_hi
    lda #<SWITCH_NT_BL
    sta pq_addr_lo
    lda #TILE_SWITCH_PRESSED
    sta pq_data
    jsr ppu_queue_push
    lda #>SWITCH_NT_BR
    sta pq_addr_hi
    lda #<SWITCH_NT_BR
    sta pq_addr_lo
    lda #TILE_SWITCH_PRESSED
    sta pq_data
    jsr ppu_queue_push
@switch_skip:

    ; --- Punto de control (F4.4): mismo chequeo de 2 esquinas. Guarda
    ; la posición y la habitación actual -- load_room reaparece ahí en
    ; vez del punto de aparición por defecto mientras coincida la
    ; habitación (ver load_room).
    lda #0
    jsr set_col_x
    lda player_y_hi
    clc
    adc #(PLAYER_HITBOX_H-1)
    sta col_y
    jsr get_tile_collision
    cmp #COLLISION_CHECKPOINT
    beq @checkpoint_hit

    lda #(PLAYER_HITBOX_W-1)
    jsr set_col_x
    jsr get_tile_collision
    cmp #COLLISION_CHECKPOINT
    bne @checkpoint_skip

@checkpoint_hit:
    lda #1
    sta checkpoint_active
    lda room_current
    sta checkpoint_room
    lda player_x_px_lo
    sta checkpoint_x_lo
    lda player_x_px_hi
    sta checkpoint_x_hi
    lda player_y_hi
    sta checkpoint_y
@checkpoint_skip:

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
    ; Pose según el estado Y la velocidad real (F5.1c): WALK reparte
    ; entre caminar (2 cuadros alternados) y correr según
    ; RUN_SPEED_THRESHOLD -- antes solo había 2 cuadros de caminar, sin
    ; distinción de velocidad. JUMP y FALL comparten la pose aérea.
    ; ATTACK conserva temporalmente la pose de contacto hasta que tenga
    ; su animación dedicada.
    lda player_state
    cmp #STATE_WALK
    beq @anim_walk
    cmp #STATE_JUMP
    beq @anim_jump
    cmp #STATE_FALL
    beq @anim_jump
    cmp #STATE_ATTACK
    beq @anim_attack
    lda #POSE_IDLE
    jmp @draw_pose
@anim_walk:
    ; CMP es sin signo: cualquier byte alto no-cero (sea +N o el
    ; complemento a dos de un negativo) sale >= 1 sin signo, así que
    ; esto detecta "velocidad horizontal real distinta de cero" sin
    ; tener que calcular el valor absoluto con signo aparte.
    lda player_vx_hi
    cmp #RUN_SPEED_THRESHOLD
    bcc @anim_walk_slow
    lda #POSE_RUN
    jmp @draw_pose
@anim_walk_slow:
    lda frame_count
    and #%00001000
    beq @anim_walk_contact
    lda #POSE_WALK2
    jmp @draw_pose
@anim_walk_contact:
    lda #POSE_WALK1
    jmp @draw_pose
@anim_jump:
    lda #POSE_JUMP
    jmp @draw_pose
@anim_attack:
    lda #POSE_WALK1
@draw_pose:
    jsr draw_player_metasprite

    ; Parpadeo durante HURT (invulnerabilidad visual): oculta las 16
    ; piezas la mitad de los frames, técnica estándar de NES.
    lda player_state
    cmp #STATE_HURT
    bne @no_blink
    lda state_timer
    and #%00000100
    bne @no_blink
    ldx #0
@blink_hide_loop:
    lda #$FF
    sta oam_buffer+PLAYER_OAM_BASE,x
    inx
    inx
    inx
    inx
    cpx #64
    bne @blink_hide_loop
@no_blink:

    rts
.endproc

; Entra en HURT con knockback real (F3.4, factorizado de update_player
; en F5.2 para que check_enemy_contact pueda disparar el mismo estado
; sin duplicar código -- el knockback de un peligro de tile y el de un
; enemigo/proyectil son indistinguibles para el jugador). El knockback
; sigue basado en player_facing_right, no en la posición relativa de lo
; que golpeó -- mismo criterio que ya usaba el peligro de tile.
.proc enter_hurt_state
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
    rts
.endproc

; Dibuja la pose 32x32 (grilla 4x4 de tiles 8x8, F5.1c) identificada por
; POSE_* en A, en la posición real de Chiquito. El punto físico sigue
; siendo el hitbox 8x8 original: el arte se centra 12px a cada lado y se
; extiende 24px hacia arriba, por lo que no cambia ninguna colisión ni
; posición de aparición existente -- mismo criterio que draw_npc_metasprite,
; con el que comparte estructura (bucle fila/columna en vez de 16
; bloques desenrollados).
;
; A diferencia de Sanchopau (una sola pose, tabla de paleta fija), aquí
; hay 5 poses con su propio par de tablas (tile absoluto o $FF si la
; celda no tiene pieza real, y qué subpaleta 0/1 -- ver
; tools/gen_chiquito_poses.py); por eso el primer paso es cargar los
; punteros de la pose actual en zero page para poder usar direccionamiento
; indirecto indexado ((ptr),y), el único modo que da el 6502 para leer
; una tabla cuya dirección no se conoce hasta tiempo de ejecución.
.proc draw_player_metasprite
    tax
    lda chiquito_pose_tile_lo,x
    sta chiquito_tile_ptr
    lda chiquito_pose_tile_hi,x
    sta chiquito_tile_ptr+1
    lda chiquito_pose_pal_lo,x
    sta chiquito_pal_ptr
    lda chiquito_pose_pal_hi,x
    sta chiquito_pal_ptr+1

    lda player_x_px_lo
    sec
    sbc camera_x_lo
    sec
    sbc #12
    sta player_draw_x

    lda player_y_hi
    sec
    sbc #24
    sta player_draw_y

    lda #0
    sta player_row
@row_loop:
    lda player_row
    asl a
    asl a
    sta player_row4

    lda player_row
    asl a
    asl a
    asl a                    ; ty*8
    clc
    adc player_draw_y
    pha                       ; Y de esta fila, igual para las 4 columnas

    lda #0
    sta player_col
@col_loop:
    lda player_row
    asl a
    asl a
    clc
    adc player_col
    asl a
    asl a
    tax                       ; X = offset relativo dentro de PLAYER_OAM_BASE

    pla
    pha
    sta oam_buffer+PLAYER_OAM_BASE+0,x

    lda player_col
    asl a
    asl a
    asl a                     ; tx*8 -- posición de pantalla, fija pase lo que pase facing
    clc
    adc player_draw_x
    sta oam_buffer+PLAYER_OAM_BASE+3,x

    ; Columna de tile real (facing) -> índice 0-15 en las tablas.
    lda player_facing_right
    bne @col_right
    lda #3
    sec
    sbc player_col
    jmp @have_col
@col_right:
    lda player_col
@have_col:
    clc
    adc player_row4
    tay                       ; Y = índice 0-15, para leer las tablas indirectas

    lda (chiquito_tile_ptr),y
    cmp #$FF
    bne @tile_real
    ; Sin pieza real en esta celda (las poses no siempre llenan las 16):
    ; oculta solo este sprite, pisando la Y que ya se había escrito.
    lda #$FF
    sta oam_buffer+PLAYER_OAM_BASE+0,x
    jmp @next_col
@tile_real:
    sta oam_buffer+PLAYER_OAM_BASE+1,x

    lda (chiquito_pal_ptr),y
    beq @attr_a
    lda #%00000011
    jmp @attr_have
@attr_a:
    lda #%00000000
@attr_have:
    ldy player_facing_right
    bne @attr_store
    ora #%01000000
@attr_store:
    sta oam_buffer+PLAYER_OAM_BASE+2,x

@next_col:
    inc player_col
    lda player_col
    cmp #4
    bne @col_loop
    pla                        ; descarta la Y de fila que quedó en la pila
    inc player_row
    lda player_row
    cmp #4
    beq @done                  ; bucle más largo que 127 bytes: branch corto + jmp (patrón ya usado en update_player)
    jmp @row_loop
@done:
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

    ; Reposiciona a Chiquito en el punto de aparición de la habitación
    ; -- o en el punto de control (F4.4), si hay uno activo para ESTA
    ; habitación (room_current ya tiene el ID que se está cargando).
    lda room_descriptors+11,x
    sta player_x_px_lo
    lda room_descriptors+12,x
    sta player_x_px_hi
    lda room_descriptors+13,x
    sta player_y_hi
    lda checkpoint_active
    beq @no_checkpoint
    lda checkpoint_room
    cmp room_current
    bne @no_checkpoint
    lda checkpoint_x_lo
    sta player_x_px_lo
    lda checkpoint_x_hi
    sta player_x_px_hi
    lda checkpoint_y
    sta player_y_hi
@no_checkpoint:
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

    ; F5.1: limpia las entidades de una visita anterior a ESTA
    ; habitación (si las hay) y genera las de esta visita. Las
    ; entidades de otras habitaciones no se tocan -- update_entities ya
    ; las mantiene ocultas por zona mientras no sea la habitación
    ; actual.
    lda room_current
    jsr destroy_entities_in_room

    lda room_current
    cmp #ROOM_PRADERA
    beq @has_entities
    jmp @no_entities            ; bucle de spawns más largo que 127 bytes: branch corto + jmp (patrón ya usado en update_player)
@has_entities:
    ; Enemigo patrullero (F2.3 lo creó estático; F5.2 le da IA real --
    ; ver enemy_patrol_step). Misma X de siempre; Y corregida de 179 a
    ; 152 (altura real de piso, ver la nota junto a ENEMY_CHASER_BASE_Y)
    ; para que check_enemy_contact pueda tocarlo de verdad caminando.
    lda #ROOM_PRADERA
    sta entity_arg_room
    lda #ENTITY_TYPE_ENEMY
    sta entity_arg_type
    lda #<180
    sta entity_arg_x_lo
    lda #>180
    sta entity_arg_x_hi
    lda #152
    sta entity_arg_y
    lda #TILE_ENEMY
    sta entity_arg_tile
    lda #%00000001
    sta entity_arg_attr
    lda #ENEMY_BEHAVIOR_PATROL
    sta entity_arg_behavior
    lda #0
    sta entity_arg_dir
    sta entity_arg_timer
    jsr spawn_entity
    ; Coleccionable de prueba (F2.3, idem). Sin comportamiento --
    ; entity_arg_behavior/dir/timer quedan en 0 sin que nada los lea.
    lda #ROOM_PRADERA
    sta entity_arg_room
    lda #ENTITY_TYPE_ITEM
    sta entity_arg_type
    lda #<140
    sta entity_arg_x_lo
    lda #>140
    sta entity_arg_x_hi
    lda #99
    sta entity_arg_y
    lda #TILE_ITEM
    sta entity_arg_tile
    lda #%00000010
    sta entity_arg_attr
    lda #0
    sta entity_arg_behavior
    sta entity_arg_dir
    sta entity_arg_timer
    jsr spawn_entity
    ; Enemigo perseguidor/saltador (F5.2): pantalla 1, piso sólido
    ; corrido. Arranca mirando/moviendo a la derecha (dir=0); el primer
    ; frame real de IA (enemy_chaser_step) corrige la dirección según
    ; dónde esté Chiquito.
    lda #ROOM_PRADERA
    sta entity_arg_room
    lda #ENTITY_TYPE_ENEMY
    sta entity_arg_type
    lda #<ENEMY_CHASER_SPAWN_X
    sta entity_arg_x_lo
    lda #>ENEMY_CHASER_SPAWN_X
    sta entity_arg_x_hi
    lda #ENEMY_CHASER_BASE_Y
    sta entity_arg_y
    lda #TILE_ENEMY
    sta entity_arg_tile
    lda #%00000001
    sta entity_arg_attr
    lda #ENEMY_BEHAVIOR_CHASER
    sta entity_arg_behavior
    lda #0
    sta entity_arg_dir
    sta entity_arg_timer
    jsr spawn_entity
    ; Enemigo de ataque a distancia (F5.2): pantalla 1, fijo en X.
    ; entity_timer arranca en ENEMY_RANGED_FIRE_COOLDOWN (no en 0) para
    ; que no dispare en el primer frame tras cargar la habitación.
    lda #ROOM_PRADERA
    sta entity_arg_room
    lda #ENTITY_TYPE_ENEMY
    sta entity_arg_type
    lda #<ENEMY_RANGED_SPAWN_X
    sta entity_arg_x_lo
    lda #>ENEMY_RANGED_SPAWN_X
    sta entity_arg_x_hi
    lda #ENEMY_RANGED_Y
    sta entity_arg_y
    lda #TILE_ENEMY
    sta entity_arg_tile
    lda #%00000001
    sta entity_arg_attr
    lda #ENEMY_BEHAVIOR_RANGED
    sta entity_arg_behavior
    lda #0
    sta entity_arg_dir
    lda #ENEMY_RANGED_FIRE_COOLDOWN
    sta entity_arg_timer
    jsr spawn_entity
@no_entities:

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

    ; F5.1b: paleta de sprite por habitación, escritura directa (el
    ; renderizado sigue apagado en este tramo de load_room, igual que
    ; los bulk copy de arriba). Los slots 1/2 (enemigo/ítem) solo hacen
    ; falta en ROOM_PRADERA -- en cualquier otra habitación se prestan a
    ; Sanchopau. Ver sanchopau_sprite_overlay en src/data/palettes.s.
    lda room_current
    cmp #ROOM_CASA
    beq @sprite_overlay_casa
    bit $2002
    lda #$3F
    sta $2006
    lda #$15
    sta $2006
    lda palette_table+21
    sta $2007
    lda palette_table+22
    sta $2007
    lda palette_table+23
    sta $2007
    bit $2002
    lda #$3F
    sta $2006
    lda #$19
    sta $2006
    lda palette_table+25
    sta $2007
    lda palette_table+26
    sta $2007
    lda palette_table+27
    sta $2007
    jmp @sprite_overlay_done
@sprite_overlay_casa:
    bit $2002
    lda #$3F
    sta $2006
    lda #$15
    sta $2006
    lda sanchopau_sprite_overlay+0
    sta $2007
    lda sanchopau_sprite_overlay+1
    sta $2007
    lda sanchopau_sprite_overlay+2
    sta $2007
    bit $2002
    lda #$3F
    sta $2006
    lda #$19
    sta $2006
    lda sanchopau_sprite_overlay+3
    sta $2007
    lda sanchopau_sprite_overlay+4
    sta $2007
    lda sanchopau_sprite_overlay+5
    sta $2007
    ; Reaparece a Sanchopau en su punto de partida cada vez que se
    ; (re)entra a Casa -- igual criterio que el resto de load_room, que
    ; siempre deja la habitación en un estado inicial predecible.
    lda #NPC_MIN_X
    sta npc_x
    lda #1
    sta npc_facing
@sprite_overlay_done:

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

; Mueve la plataforma móvil (F4.4, un solo ejemplo hardcodeado -- ver
; nota de PLATFORM_* arriba del archivo) y escribe sus 2 sprites al
; OAM. Llamada una vez por frame desde el main loop. Cuando la
; habitación actual no es pradera, la plataforma no existe ahí --
; se oculta (Y=$FF) en vez de dejarla en una posición de pantalla que
; no le corresponde.
.proc update_platform
    lda platform_dir
    bne @move_left

@move_right:
    inc platform_x_lo
    bne @check_max
    inc platform_x_hi
@check_max:
    lda platform_x_lo
    sta cmp_a_lo
    lda platform_x_hi
    sta cmp_a_hi
    lda #<PLATFORM_MAX_X
    sta cmp_b_lo
    lda #>PLATFORM_MAX_X
    sta cmp_b_hi
    jsr cmp16_signed          ; N=1 si platform_x < PLATFORM_MAX_X
    bmi @oam_write
    lda #1
    sta platform_dir
    jmp @oam_write

@move_left:
    lda platform_x_lo
    bne @no_borrow
    dec platform_x_hi
@no_borrow:
    dec platform_x_lo
    lda platform_x_lo
    sta cmp_a_lo
    lda platform_x_hi
    sta cmp_a_hi
    lda #<PLATFORM_MIN_X
    sta cmp_b_lo
    lda #>PLATFORM_MIN_X
    sta cmp_b_hi
    jsr cmp16_signed          ; N=1 si platform_x < PLATFORM_MIN_X (se pasó)
    bpl @oam_write
    lda #0
    sta platform_dir

@oam_write:
    lda room_current
    cmp #ROOM_PRADERA
    beq @visible
    lda #$FF
    sta oam_buffer+PLATFORM_OAM_BASE+0     ; Y de ambos sprites: fuera de pantalla
    sta oam_buffer+PLATFORM_OAM_BASE+4
    rts

@visible:
    ; F5.1: las entidades le hicieron lugar a la plataforma más abajo
    ; en el buffer (PLATFORM_OAM_BASE, antes offset fijo 12). Tile y
    ; atributo se escriben acá en vez de en oam_init_data -- ya no hay
    ; ninguna entrada estática para la plataforma, solo para Chiquito.
    lda #PLATFORM_Y
    sta oam_buffer+PLATFORM_OAM_BASE+0
    sta oam_buffer+PLATFORM_OAM_BASE+4
    lda #TILE_PLATFORM_SPRITE
    sta oam_buffer+PLATFORM_OAM_BASE+1
    sta oam_buffer+PLATFORM_OAM_BASE+5
    lda #%00000000
    sta oam_buffer+PLATFORM_OAM_BASE+2
    sta oam_buffer+PLATFORM_OAM_BASE+6
    lda platform_x_lo
    sec
    sbc camera_x_lo           ; X relativa a pantalla (igual que @animate con el jugador)
    sta oam_buffer+PLATFORM_OAM_BASE+3
    clc
    adc #8
    sta oam_buffer+PLATFORM_OAM_BASE+7
    rts
.endproc

; Busca el primer slot de entidad libre y lo ocupa con los argumentos
; entity_arg_* (ver nota de ZEROPAGE). Si las MAX_ENTITIES ya están
; activas, no hace nada y vuelve -- ninguna entidad existente se toca,
; no hay desborde ni corrupción posible por diseño (el límite de la
; tabla nunca se excede porque el índice nunca pasa de MAX_ENTITIES).
.proc spawn_entity
    ldx #0
@find_free:
    lda entity_active,x
    beq @found
    inx
    cpx #MAX_ENTITIES
    bne @find_free
    rts                       ; tabla llena: no se puede, no se corrompe nada
@found:
    lda #1
    sta entity_active,x
    lda entity_arg_room
    sta entity_room,x
    lda entity_arg_type
    sta entity_type,x
    lda entity_arg_x_lo
    sta entity_x_lo,x
    lda entity_arg_x_hi
    sta entity_x_hi,x
    lda entity_arg_y
    sta entity_y,x
    lda entity_arg_tile
    sta entity_tile,x
    lda entity_arg_attr
    sta entity_attr,x
    lda entity_arg_behavior
    sta entity_behavior,x
    lda entity_arg_dir
    sta entity_dir,x
    lda entity_arg_timer
    sta entity_timer,x
    rts
.endproc

; Desactiva todas las entidades activas cuya habitación (A, al entrar)
; coincida. Usado por load_room para limpiar las entidades de una
; visita anterior a la MISMA habitación antes de generar las nuevas --
; así visitar una habitación varias veces no agota los slots de a poco.
; Las entidades de OTRAS habitaciones no se tocan (quedan inactivas
; para el renderizado por la zona de update_entities, sin necesitar
; destruirlas hasta que se vuelva a visitar esa habitación).
.proc destroy_entities_in_room
    sta entity_arg_room       ; reusa el escratch de spawn como parámetro
    ldx #0
@loop:
    lda entity_active,x
    beq @next
    lda entity_room,x
    cmp entity_arg_room
    bne @next
    lda #0
    sta entity_active,x
@next:
    inx
    cpx #MAX_ENTITIES
    bne @loop
    rts
.endproc

; Escribe el OAM de cada entidad activa cuya habitación coincida con
; room_current (la "zona" de actualización que pide F5.1 -- una
; entidad de otra habitación no se dibuja ni gasta presupuesto de
; sprites). Llamada una vez por frame desde el main loop.
.proc update_entities
    ldx #0
@loop:
    txa
    asl a
    asl a                     ; *4: cada sprite de OAM son 4 bytes
    clc
    adc #ENTITY_OAM_BASE
    tay                       ; Y = offset en oam_buffer para esta entidad

    lda entity_active,x
    beq @hide
    lda entity_room,x
    cmp room_current
    bne @hide

    lda entity_y,x
    sta oam_buffer,y
    lda entity_tile,x
    sta oam_buffer+1,y
    lda entity_attr,x
    sta oam_buffer+2,y
    lda entity_x_lo,x
    sec
    sbc camera_x_lo           ; X relativa a pantalla (igual que @animate/update_platform)
    sta oam_buffer+3,y
    jmp @next
@hide:
    lda #$FF
    sta oam_buffer,y
@next:
    inx
    cpx #MAX_ENTITIES
    bne @loop
    rts
.endproc

; F5.2: dx = entity_x(X) - player_x_px, 16 bits con signo, en
; enemy_dx_lo/hi. X = índice de entidad al entrar (no se modifica).
; Primitiva compartida por enemy_chaser_step, enemy_ranged_step y
; check_enemy_contact -- el signo (bit 7 de enemy_dx_hi) da la
; dirección hacia el jugador sin importar la distancia; la magnitud
; solo es exacta para comparaciones de umbral chico (ver cada llamador).
.proc compute_entity_dx
    lda entity_x_lo,x
    sec
    sbc player_x_px_lo
    sta enemy_dx_lo
    lda entity_x_hi,x
    sbc player_x_px_hi
    sta enemy_dx_hi
    rts
.endproc

; F5.2: colisión jugador-enemigo/proyectil. AABB simple entre el
; hitbox de Chiquito (8x8, player_x_px/player_y_hi) y cada entidad
; ACTIVA de tipo ENEMY o PROJECTILE en la habitación actual. En el
; primer contacto que encuentra entra en HURT (enter_hurt_state, mismo
; knockback que un peligro de tile) y sale -- no hace falta seguir
; revisando el resto de entidades ese mismo frame, el jugador ya queda
; invulnerable. Si el contacto fue con un proyectil, además lo
; desactiva (una "bala" se consume al pegar). El jugador NO puede
; dañar a los enemigos todavía -- no hay arma/hitbox de ataque real
; (eso es F5.3); este chequeo es de un solo sentido.
.proc check_enemy_contact
    lda player_state
    cmp #STATE_HURT
    beq @done
    cmp #STATE_DEAD
    beq @done

    ldx #0
@loop:
    lda entity_active,x
    beq @next
    lda entity_room,x
    cmp room_current
    bne @next
    lda entity_type,x
    cmp #ENTITY_TYPE_ENEMY
    beq @check
    cmp #ENTITY_TYPE_PROJECTILE
    bne @next
@check:
    jsr compute_entity_dx
    lda enemy_dx_hi
    beq @dx_check_pos
    cmp #$FF
    bne @next
    lda enemy_dx_lo
    cmp #(256-ENTITY_HITBOX_W)
    bcc @next
    jmp @dx_ok
@dx_check_pos:
    lda enemy_dx_lo
    cmp #ENTITY_HITBOX_W
    bcs @next
@dx_ok:
    ; dy = entity_y(X) - player_y_hi, 8 bits con signo; abs(dy) < ENTITY_HITBOX_H.
    lda entity_y,x
    sec
    sbc player_y_hi
    bpl @dy_check
    eor #$FF
    clc
    adc #1
@dy_check:
    cmp #ENTITY_HITBOX_H
    bcs @next
    ; Contacto real.
    lda entity_type,x
    cmp #ENTITY_TYPE_PROJECTILE
    bne @hit
    lda #0
    sta entity_active,x
@hit:
    jsr enter_hurt_state
    rts
@next:
    inx
    cpx #MAX_ENTITIES
    bne @loop
@done:
    rts
.endproc

; F5.2: IA de enemigos (patrullero/perseguidor-saltador/ataque a
; distancia) y movimiento/vida de proyectiles. Llamado una vez por
; frame desde el main loop, ANTES de update_entities, para que los
; cambios de posición/atributo de este frame ya estén en la tabla
; cuando update_entities escriba el OAM. Solo procesa entidades
; ACTIVAS de la habitación actual -- las de otras habitaciones ni se
; tocan (igual que el resto del sistema de entidades, por zona).
.proc update_enemies
    ldx #0
@loop:
    lda entity_active,x
    beq @next
    lda entity_room,x
    cmp room_current
    bne @next
    lda entity_type,x
    cmp #ENTITY_TYPE_ENEMY
    beq @is_enemy
    cmp #ENTITY_TYPE_PROJECTILE
    beq @do_projectile
    cmp #ENTITY_TYPE_PLAYER_PROJECTILE    ; F5.3: mismo movimiento/vida que el proyectil enemigo (projectile_step es genérico)
    beq @do_projectile
    jmp @next
@is_enemy:
    lda entity_behavior,x
    cmp #ENEMY_BEHAVIOR_PATROL
    beq @do_patrol
    cmp #ENEMY_BEHAVIOR_CHASER
    beq @do_chaser
    cmp #ENEMY_BEHAVIOR_RANGED
    beq @do_ranged
    jmp @next
@do_patrol:
    jsr enemy_patrol_step
    jmp @next
@do_chaser:
    jsr enemy_chaser_step
    jmp @next
@do_ranged:
    jsr enemy_ranged_step
    jmp @next
@do_projectile:
    jsr projectile_step
@next:
    inx
    cpx #MAX_ENTITIES
    bne @loop
    rts
.endproc

; Patrullero (F5.2): rebota 1px cada 2 frames entre ENEMY_PATROL_MIN_X/
; MAX_X -- mismo patrón que update_platform, pero por entidad (el rango
; cabe en 8 bits, a diferencia del perseguidor/atacante que viven más
; lejos en el nivel). X = índice de entidad al entrar.
.proc enemy_patrol_step
    lda frame_count
    and #ENEMY_PATROL_SPEED_DIVISOR
    bne @flip_only
    lda entity_dir,x
    bne @move_left
@move_right:
    inc entity_x_lo,x
    lda entity_x_lo,x
    cmp #ENEMY_PATROL_MAX_X
    bcc @flip_only
    lda #1
    sta entity_dir,x
    jmp @flip_only
@move_left:
    dec entity_x_lo,x
    lda entity_x_lo,x
    cmp #ENEMY_PATROL_MIN_X
    bcs @flip_only
    lda #0
    sta entity_dir,x
@flip_only:
    lda #%00000001            ; subpaleta de enemigo, igual que en el spawn
    ldy entity_dir,x
    beq @attr_store
    ora #%01000000            ; dir=1 (izquierda) -> flip horizontal
@attr_store:
    sta entity_attr,x
    rts
.endproc

; Perseguidor/saltador (F5.2): se mueve 1px/frame en X hacia Chiquito
; (persecución real, no un rango fijo) hasta quedar a ENTITY_HITBOX_W
; de distancia -- el mismo umbral que usa check_enemy_contact para el
; contacto, no hace falta superponerse para "llegar". Agrega un salto
; visual (offset de Y vía enemy_hop_offset) en vez de deslizarse, para
; que sea un comportamiento realmente distinto del patrullero. Sin
; física de salto real por entidad (gravedad/colisión) -- es un offset
; de dibujo sobre ENEMY_CHASER_BASE_Y, ver limitaciones en TASKS.md.
.proc enemy_chaser_step
    jsr compute_entity_dx

    ; Dirección real hacia el jugador (válida a cualquier distancia):
    ; bit 7 de enemy_dx_hi. dx<0 (entidad a la izquierda) -> dir=0
    ; (derecha); dx>=0 -> dir=1 (izquierda). Mismo criterio que
    ; platform_dir/entity_dir del patrullero (0=derecha).
    lda enemy_dx_hi
    bmi @face_right
    lda #1
    sta entity_dir,x
    jmp @dir_done
@face_right:
    lda #0
    sta entity_dir,x
@dir_done:

    ; ¿Ya está a menos de ENEMY_CHASER_STOP_DISTANCE de distancia? Esta
    ; aproximación (comparar solo el byte bajo cuando el alto es 0 o
    ; $FF) solo es exacta para |dx| chico, que es justo el caso que
    ; importa: si el alto es otro valor, está lejos de verdad y debe
    ; seguir acercándose sin entrar en ninguna de las dos ramas de abajo.
    lda enemy_dx_hi
    beq @maybe_close_pos
    cmp #$FF
    bne @do_move
    lda enemy_dx_lo
    cmp #(256-ENEMY_CHASER_STOP_DISTANCE)
    bcs @skip_move
    jmp @do_move
@maybe_close_pos:
    lda enemy_dx_lo
    cmp #ENEMY_CHASER_STOP_DISTANCE
    bcc @skip_move
@do_move:
    lda entity_dir,x
    bne @move_left
@move_right:
    inc entity_x_lo,x
    bne @skip_move
    inc entity_x_hi,x
    jmp @skip_move
@move_left:
    lda entity_x_lo,x
    bne @dec_lo
    dec entity_x_hi,x
@dec_lo:
    dec entity_x_lo,x
@skip_move:

    ; Ciclo de salto (F5.2): independiente de si se movió este frame.
    ; entity_timer cuenta HACIA ARRIBA de 0 a ENEMY_CHASER_HOP_PERIOD-1
    ; y vuelve a 0 -- distinto del uso como cooldown del atacante a
    ; distancia (cuenta hacia abajo), mismo campo, significado por
    ; comportamiento (ver la nota junto a entity_timer en BSS).
    inc entity_timer,x
    lda entity_timer,x
    cmp #ENEMY_CHASER_HOP_PERIOD
    bcc @hop_check
    lda #0
    sta entity_timer,x
@hop_check:
    lda entity_timer,x
    cmp #16
    bcs @on_ground
    tay
    lda enemy_hop_offset,y
    jmp @apply_y
@on_ground:
    lda #0
@apply_y:
    sta enemy_hop_tmp
    lda #ENEMY_CHASER_BASE_Y
    sec
    sbc enemy_hop_tmp
    sta entity_y,x

    lda #%00000001
    ldy entity_dir,x
    beq @attr_store
    ora #%01000000
@attr_store:
    sta entity_attr,x
    rts
.endproc

; Atacante a distancia (F5.2): fijo en X. entity_timer es el cooldown
; (cuenta hacia abajo desde ENEMY_RANGED_FIRE_COOLDOWN); al llegar a 0
; dispara un proyectil horizontal hacia el lado donde esté Chiquito en
; ESE instante (no vuelve a apuntar después, ver projectile_step) y
; reinicia el cooldown. X = índice de entidad al entrar -- se guarda en
; enemy_save_x porque spawn_entity recorre la tabla de entidades desde
; X=0 (lo pisa).
.proc enemy_ranged_step
    lda entity_timer,x
    beq @fire
    dec entity_timer,x
    rts
@fire:
    jsr compute_entity_dx
    lda enemy_dx_hi
    bmi @dir_right              ; dx<0: jugador a la derecha -> bala a la derecha (dir=0)
    lda #1                      ; dx>=0: jugador a la izquierda (o igual) -> bala a la izquierda (dir=1)
    jmp @dir_have
@dir_right:
    lda #0
@dir_have:
    sta entity_arg_dir

    stx enemy_save_x
    lda room_current
    sta entity_arg_room
    lda #ENTITY_TYPE_PROJECTILE
    sta entity_arg_type
    lda entity_x_lo,x
    sta entity_arg_x_lo
    lda entity_x_hi,x
    sta entity_arg_x_hi
    lda entity_y,x
    sta entity_arg_y
    lda #TILE_ITEM               ; sin arte dedicado todavía -- ver limitaciones en TASKS.md/ASSET_MANIFEST.md
    sta entity_arg_tile
    lda #%00000001
    sta entity_arg_attr
    lda #0
    sta entity_arg_behavior
    lda #PROJECTILE_LIFETIME
    sta entity_arg_timer
    jsr spawn_entity
    ldx enemy_save_x

    lda #ENEMY_RANGED_FIRE_COOLDOWN
    sta entity_timer,x
    rts
.endproc

; Movimiento y ciclo de vida de un proyectil (F5.2): viaja en línea
; recta (PROJECTILE_SPEED px/frame) en la dirección fijada al
; disparar (entity_dir, no vuelve a apuntar); entity_timer cuenta
; PROJECTILE_LIFETIME frames hacia abajo y lo desactiva al llegar a 0
; -- desaparición real, no solo salir de pantalla. El atacante a
; distancia dispara uno nuevo al terminar su propio cooldown (ver
; enemy_ranged_step) -- no es el MISMO proyectil reapareciendo, pero
; cumple la regla de aparición/desaparición que pide F5.2.
.proc projectile_step
    dec entity_timer,x
    bne @move
    lda #0
    sta entity_active,x
    rts
@move:
    lda entity_dir,x
    bne @move_left
@move_right:
    lda entity_x_lo,x
    clc
    adc #PROJECTILE_SPEED
    sta entity_x_lo,x
    bcc @rts
    inc entity_x_hi,x
    jmp @rts
@move_left:
    lda entity_x_lo,x
    sec
    sbc #PROJECTILE_SPEED
    sta entity_x_lo,x
    bcs @rts
    dec entity_x_hi,x
@rts:
    rts
.endproc

; F5.3: devuelve en A (y en Z, para branch directo con beq/bne) si hay
; algún proyectil del jugador activo en la habitación ACTUAL. Filtrado
; por habitación a propósito: update_enemies (que mueve/consume la
; vida de los proyectiles vía projectile_step) solo procesa entidades
; de room_current -- un proyectil disparado justo antes de cruzar una
; puerta se queda "congelado" (nunca se decrementa) en la habitación
; que se abandonó. Sin este filtro, ese proyectil abandonado se vería
; como "activo para siempre" y bloquearía disparar de nuevo en
; cualquier otra habitación. Usado para el límite de 1 proyectil
; simultáneo (PLAYER_PROJECTILE_LIMIT).
.proc player_has_active_projectile
    ldx #0
@loop:
    lda entity_active,x
    beq @next
    lda entity_room,x
    cmp room_current
    bne @next
    lda entity_type,x
    cmp #ENTITY_TYPE_PLAYER_PROJECTILE
    beq @found
@next:
    inx
    cpx #MAX_ENTITIES
    bne @loop
    lda #0
    rts
@found:
    lda #1
    rts
.endproc

; F5.3: detecta impactos del proyectil del jugador contra enemigos
; (lo inverso de check_enemy_contact). X recorre proyectiles del
; jugador activos de la habitación actual; Y recorre enemigos activos
; de la misma habitación -- mismo AABB de 8x8 que check_enemy_contact,
; reusando enemy_dx_lo/hi como escratch (no hay conflicto: un solo
; hilo, nada más lo usa a la vez). Al primer impacto desactiva AMBOS:
; el proyectil se consume y el enemigo queda derrotado. Sin sistema de
; vida/puntos todavía -- un enemigo derrotado simplemente deja de
; existir hasta que se vuelva a cargar la habitación (load_room lo
; regenera de cero, igual que cualquier revisita).
.proc check_player_attacks
    ldx #0
@outer:
    lda entity_active,x
    beq @outer_next
    lda entity_type,x
    cmp #ENTITY_TYPE_PLAYER_PROJECTILE
    bne @outer_next
    lda entity_room,x
    cmp room_current
    bne @outer_next

    ldy #0
@inner:
    cpy #MAX_ENTITIES
    beq @outer_next
    lda entity_active,y
    beq @inner_next
    lda entity_type,y
    cmp #ENTITY_TYPE_ENEMY
    bne @inner_next
    lda entity_room,y
    cmp room_current
    bne @inner_next

    lda entity_x_lo,y
    sec
    sbc entity_x_lo,x
    sta enemy_dx_lo
    lda entity_x_hi,y
    sbc entity_x_hi,x
    sta enemy_dx_hi

    lda enemy_dx_hi
    beq @dx_check_pos
    cmp #$FF
    bne @inner_next
    lda enemy_dx_lo
    cmp #(256-ENTITY_HITBOX_W)
    bcc @inner_next
    jmp @dx_ok
@dx_check_pos:
    lda enemy_dx_lo
    cmp #ENTITY_HITBOX_W
    bcs @inner_next
@dx_ok:
    lda entity_y,y
    sec
    sbc entity_y,x
    bpl @dy_check
    eor #$FF
    clc
    adc #1
@dy_check:
    cmp #ENTITY_HITBOX_H
    bcs @inner_next

    ; Impacto real: se consume el proyectil y se derrota al enemigo.
    lda #0
    sta entity_active,x
    sta entity_active,y
    jmp @outer_next

@inner_next:
    iny
    jmp @inner

@outer_next:
    inx
    cpx #MAX_ENTITIES
    bne @outer
    rts
.endproc

; F5.1b: patrulla de Sanchopau (NPC, no jugador -- sin física real, solo
; rebota entre NPC_MIN_X/NPC_MAX_X) y pose según si se está moviendo.
; Llamado una vez por frame desde el main loop, después de
; update_entities. Solo visible en ROOM_CASA; en cualquier otra
; habitación solo oculta su OAM y sale.
.proc update_npc
    lda room_current
    cmp #ROOM_CASA
    beq @active
    ; Oculta los 16 sprites (4x4), no solo los 4 de la primera fila --
    ; el Y de cada uno vive en el primer byte de su bloque de 4
    ; (offsets 0,4,8,...,60 dentro de NPC_OAM_BASE).
    ldx #0
@hide_loop:
    lda #$FF
    sta oam_buffer+NPC_OAM_BASE,x
    inx
    inx
    inx
    inx
    cpx #64
    bne @hide_loop
    rts

@active:
    lda frame_count
    and #NPC_SPEED_DIVISOR
    bne @skip_move
    lda npc_facing
    bne @move_right
@move_left:
    dec npc_x
    lda npc_x
    cmp #NPC_MIN_X
    bcs @skip_move
    lda #1
    sta npc_facing
    jmp @skip_move
@move_right:
    inc npc_x
    lda npc_x
    cmp #NPC_MAX_X
    bcc @skip_move
    lda #0
    sta npc_facing
@skip_move:

    ; Pose única (ver nota de TILE_SANCHOPAU_BASE): se desliza sin
    ; animar las piernas, no hay caminar/salto dibujados todavía.
    jsr draw_npc_metasprite
    rts
.endproc

; Dibuja a Sanchopau (grilla 4x4 de tiles 8x8, TILE_SANCHOPAU_BASE) en
; npc_x/NPC_Y. Recorre las 16 piezas con un bucle (fila/columna) en vez
; de 16 bloques de código desenrollados: a diferencia de Chiquito (4
; piezas, sí desenrollado en draw_player_metasprite), aquí el código
; desenrollado sería demasiado largo para el beneficio.
; Paleta por TILE, no por mitad (a diferencia de Chiquito): el parche
; naranja de Sanchopau no cae ordenadamente en una mitad superior/
; inferior, así que cada uno de los 16 tiles consulta
; sanchopau_tile_palette (ver palettes.s) con su propio índice. Igual
; que con Chiquito, la posición de cada columna en PANTALLA no cambia
; con la dirección; lo que cambia es qué columna de tile (y qué
; subpaleta, ya que viaja con el tile) se dibuja ahí, para que el
; metasprite completo se vea reflejado en vez de desplazado.
.proc draw_npc_metasprite

    lda npc_x
    sec
    sbc camera_x_lo
    sec
    sbc #12
    sta npc_draw_x

    lda #NPC_Y
    sec
    sbc #24
    sta npc_draw_y

    lda #0
    sta npc_row
@row_loop:
    lda npc_row
    asl a
    asl a
    sta npc_row4

    lda npc_row
    asl a
    asl a
    asl a                   ; ty*8
    clc
    adc npc_draw_y
    pha                      ; Y de esta fila, igual para las 4 columnas

    lda #0
    sta npc_col
@col_loop:
    lda npc_row
    asl a
    asl a
    clc
    adc npc_col
    asl a
    asl a
    tax                      ; X = offset relativo dentro del bloque NPC_OAM_BASE

    pla
    pha
    sta oam_buffer+NPC_OAM_BASE+0,x

    lda npc_col
    asl a
    asl a
    asl a                    ; tx*8 -- posición de pantalla, fija pase lo que pase facing
    clc
    adc npc_draw_x
    sta oam_buffer+NPC_OAM_BASE+3,x

    lda npc_facing
    bne @col_right
    lda #3
    sec
    sbc npc_col
    jmp @have_col
@col_right:
    lda npc_col
@have_col:
    clc
    adc npc_row4             ; A = índice de tile 0-15 (ty*4+columna de tile)
    tay                      ; Y = ese índice, para leer sanchopau_tile_palette más abajo
    clc
    adc #TILE_SANCHOPAU_BASE
    sta oam_buffer+NPC_OAM_BASE+1,x

    lda sanchopau_tile_palette,y
    beq @attr_top
    lda #%00000010
    jmp @attr_have
@attr_top:
    lda #%00000001
@attr_have:
    ldy npc_facing
    bne @attr_store
    ora #%01000000
@attr_store:
    sta oam_buffer+NPC_OAM_BASE+2,x

    inc npc_col
    lda npc_col
    cmp #4
    bne @col_loop
    pla                       ; descarta la Y de fila que quedó en la pila
    inc npc_row
    lda npc_row
    cmp #4
    bne @row_loop
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
