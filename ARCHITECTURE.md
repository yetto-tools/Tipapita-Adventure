# ARCHITECTURE
## Arquitectura técnica de Tipapita Adventure

## 1. Plataforma

Objetivo: Nintendo Entertainment System.

Hardware de referencia:

- CPU Ricoh 2A03/2A07.
- PPU 2C02/2C07.
- Resolución de referencia: 256 × 240.
- RAM interna: 2 KB.
- OAM: 64 sprites.
- APU integrada.

## 2. Herramientas propuestas

- ca65: ensamblador.
- ld65: linker.
- Mesen: emulación y depuración.
- FCEUX: pruebas complementarias.
- Python: herramientas auxiliares para generar recursos.

Estas herramientas son propuestas iniciales, sujetas a validación al configurar el entorno.

## 3. Arquitectura lógica

Separar el proyecto en:

### Hardware
Acceso a CPU, PPU, APU, controladores e interrupciones.

### Motor
- Sistema de escenas.
- Cámara.
- Colisiones.
- Física.
- Animación.
- Gestión de sprites.
- Gestión de mapas.

### Juego
- Jugador.
- Enemigos.
- Personajes.
- Objetos.
- Misiones.
- Inventario.
- Progresión.

### Datos
- Mapas.
- Tilesets.
- Paletas.
- Diálogos.
- Configuración de niveles.

## 4. Módulos

Estructura real a la fecha (F1.1). Los módulos de `hardware/`, `engine/`, `game/` y `data/` siguen siendo la organización prevista a medida que crezca el código; todavía no existen porque `src/main.s` es, deliberadamente, el único archivo fuente de este milestone.

```text
nes-advance/
├── Makefile              ; build reproducible (make rom|check|run|clean)
├── linker/
│   └── chiquito.cfg      ; linker config de ld65 para Mapper 4 (MMC3)
├── tools/
│   ├── validate_rom.py   ; valida header/tamaño de la ROM generada
│   └── test_boot.lua     ; prueba de humo automatizada en FCEUX
├── dist/                 ; artefactos de build (.nes, .o, .map) — no versionado
└── src/
    ├── main.s            ; header iNES, vectores, reset/nmi/irq mínimos
    ├── hardware/         ; (propuesto, aún no creado) ppu.s, apu.s, controller.s, interrupts.s
    ├── engine/           ; (propuesto) scene.s, camera.s, physics.s, collision.s, sprites.s, map.s
    ├── game/             ; (propuesto) player.s, enemies.s, items.s, inventory.s, missions.s, progression.s
    └── data/             ; (propuesto) levels/, characters/, tilesets/, dialogue/
```

### Layout de memoria RAM (decidido — F1.1, 2026-11-10)

Convención estándar NES para las 2 KB de RAM interna:

| Rango | Uso |
|---|---|
| `$0000-$00FF` | Zero Page (variables de acceso rápido) |
| `$0100-$01FF` | Pila del 6502 (uso de hardware, no variables) |
| `$0200-$02FF` | `oam_buffer` — buffer de sombra de OAM, fuente de la OAM DMA (`$4014`). Implementado en F1.3 como segmento dedicado `OAM` en `linker/chiquito.cfg` |
| `$0300-$07FF` | RAM general: cola de actualización de PPU (`ppu_queue_*`, F1.3) y variables de juego futuras |

Estado real (F1.3): `frame_ready`, `frame_count` y los argumentos de `ppu_queue_push` viven en Zero Page (`$0000-$0004`); la cola de PPU (`ppu_queue_len`, `ppu_queue_overflow` y sus 3 arrays de 32 bytes) vive en `$0300-$0361`. Todavía no hay variables de jugador/enemigos/mapa — eso llega con el motor (Fase 2+).

## 5. Jugador

Chiquito debe utilizar:

- Coordenadas de posición.
- Velocidad horizontal.
- Velocidad vertical.
- Estado de movimiento.
- Estado de animación.
- Puntos de colisión.
- Estado de vida.
- Habilidades desbloqueadas.

Se recomienda utilizar aritmética de punto fijo para la física.

## 6. Cámara

El juego combinará:

- Desplazamiento horizontal.
- Escenarios con scrolling.
- Habitaciones independientes.
- Transiciones entre regiones.

La implementación debe respetar el mapper y la configuración de memoria seleccionados.

## 7. Sistema de objetos

Los objetos se clasifican en:

- Materiales naturales.
- Componentes mecánicos.
- Coleccionables.
- Objetos de misión.
- Mejoras.

Los materiales recolectados podrán utilizarse en el taller de Sanchopau.

## 8. Progresión tecnológica

La progresión se divide en etapas:

1. Herramientas básicas.
2. Mecanismos sencillos.
3. Vehículos terrestres.
4. Avionetas.
5. Tecnología avanzada.
6. Vehículo para llegar a tierras lejanas.

## 9. Plataforma, mapper y header (decidido — F0.2, 2026-11-10)

- **Región:** NTSC únicamente por ahora (60 Hz, CPU ~1.79 MHz, 262 scanlines/frame). PAL queda fuera de alcance hasta que se justifique explícitamente.
- **Mapper:** MMC3 (Mapper 4). Razón principal: su IRQ de scanline permite una barra de interfaz fija mientras el resto de la pantalla hace scroll (necesidad ya descrita en la sección 6 de este documento), además de banking fino de PRG (8/16 KB) y CHR (1/2 KB).
  - Alternativas evaluadas y descartadas: NROM (Mapper 0, sin bank switching, insuficiente para varios mundos); MMC1 (Mapper 1, banking grueso, sin IRQ de scanline).
- **Header:** iNES 1.0 (no NES 2.0). Es suficiente para mapper 4 con los tamaños de ROM previstos. Se reevaluará NES 2.0 si se necesita declarar región explícita, submapper, o superar los límites prácticos de iNES.
- **Tamaño inicial de ROM (para el nivel vertical de demostración, no el juego completo):** PRG-ROM 128 KB (8 bancos de 16 KB), CHR-ROM 128 KB (no CHR-RAM, por banking nativo en MMC3 sin coste de VBlank). Crecer estos tamaños más adelante no requiere cambiar de mapper (MMC3 soporta hasta 512 KB PRG / 256 KB CHR).
- **Compatibilidad esperada (no probada todavía):** Mesen2 y FCEUX en WSL/Windows soportan mapper 4 completo, incluyendo IRQ. No se ha probado en hardware real ni se debe declarar compatibilidad real hasta hacerlo.
- **Pendiente para Fase 1:** escribir el linker config (`.cfg`) de cc65 que coincida con estos bancos y el header iNES, y validarlo con una ROM mínima que arranque.

### Inicialización del mapper MMC3 (descubierto en F2.1, 2026-11-10)

Los registros de banco del MMC3 (R0-R7, escritos vía `$8000`/`$8001`) **no tienen un valor por defecto garantizado al encender**. A diferencia de `$E000-$FFFF` (fijo por hardware sin importar el mapper), todo el espacio de CHR (`$0000-$1FFF`) y las ventanas swappeables de PRG (`$8000-$BFFF`) dependen de estos registros. `reset` los inicializa explícitamente (R0-R5 = banco CHR 0, R6/R7 = bancos PRG 0/1) antes de habilitar el renderizado — ver `mmc3_init_values` en `src/main.s`. Sin este paso, se comprobó en FCEUX que la PPU mostraba contenido que no correspondía a los bytes de CHR-ROM realmente escritos en el archivo.

### Quirk de paleta: color índice 0 compartido entre subpaletas de fondo

El color índice 0 de las 4 subpaletas de fondo (`$3F00`, `$3F04`, `$3F08`, `$3F0C`) es, en hardware real, la **misma celda física** — no existe un "color 0" independiente por subpaleta; solo los índices 1/2/3 varían de verdad entre subpaletas. Confirmado leyendo la VRAM directamente con `ppu.readbyte` en FCEUX (ver registro de F2.1 en `TASKS.md`). Cualquier tile pensado para mostrar color de una subpaleta específica debe usar índices 1/2/3, nunca depender del índice 0 para distinguirse de otra subpaleta.

### Formato de CHR, metatiles y pipeline de assets (decidido — F2.2, 2026-11-10)

- **Formato de tile:** 8x8 píxeles, 2 bits por píxel, planar (16 bytes: 8 del plano bajo + 8 del plano alto) — formato estándar de NES, sin variación propia.
- **Organización de pattern tables:** pattern table 0 (`$0000-$0FFF`) para tiles de fondo; pattern table 1 (`$1000-$1FFF`) reservada para sprites (F2.3). Dentro de pattern table 0, los tiles usados hoy ocupan los índices 0-4 (ver abajo); el resto queda libre para crecer.
- **Metatile:** bloque de 16x16px = 2x2 tiles. Formato: 4 índices de tile (orden TL, TR, BL, BR) + 1 índice de subpaleta de fondo (0-3). Definidos como datos en `tools/build_scene.py` (función `METATILES`), no en el ensamblador — son datos de diseño, no lógica de motor.
- **Pipeline de assets (real, no solo documentado):**
  1. `assets/tiles/pradera.png` — asset fuente: una hoja de tiles de 8px de alto, cada tile con como máximo 4 colores "marcador" fijos (ver `tools/png2chr.py` para la convención de colores → índice).
  2. `tools/png2chr.py` — convierte el PNG a CHR planar, emitido como `.s` de ca65. Regla clave: el mapeo color→índice es **global para todo el archivo**, no por tile (un mapeo por tile rompería la consistencia de qué índice significa qué color entre tiles distintos — error real encontrado y corregido durante esta tarea).
  3. `tools/build_scene.py` — expande una grilla de metatiles (16x15, una pantalla completa) a los 960 bytes de tiles + 64 bytes de atributos del nametable, respetando la agrupación de atributos en bloques de 2x2 metatiles.
  4. El `Makefile` regenera ambos `.s` (en `dist/`) desde los assets fuente antes de ensamblar — **no se edita a mano** ningún dato de tile o escena.
  5. `src/main.s` solo copia los bytes ya compilados a VRAM con `ppu_copy_bulk` (rutina genérica de copia ROM→`$2007`, reutilizable para futuros niveles).
- **Límites de patrones/bancos (F2.2):** 5 tiles usados de 256 posibles en pattern table 0; CHR-ROM total 128 KB, prácticamente todo libre. No hace falta bank-switching de CHR todavía — se revisará cuando haya más de un tileset/mundo (Fase 8).
- **Estado del arte actual:** los 5 tiles de `pradera.png` son una **prueba técnica de primera pasada** (formas geométricas simples), no arte final. El arte real del juego pasa por el mismo pipeline cuando esté listo, siguiendo `ART_GUIDELINES.md`.

### Sprites y OAM (decidido — F2.3, 2026-11-10)

- Los tiles de sprite (`assets/sprites/chiquito_test.png`, mismo pipeline que los de fondo) se agregan al segmento CHARS justo después de los de fondo, por lo que **hoy pattern table 0 y pattern table 1 exponen los mismos bytes físicos de CHR-ROM** (ningún registro de banco del MMC3 los separa todavía — ver R0-R5 en `mmc3_init_values`). Los índices de tile de sprite (5-8) simplemente caen después de los índices de fondo (0-4) en ese mismo CHR físico. Esto cambiará cuando haya bank-switching real de CHR (Fase 8, múltiples tilesets).
- `oam_buffer` ($0200-$02FF) se rellena con `$FF` en el reset antes de escribir sprites reales — es la técnica estándar de NES para ocultar sprites sin usar (Y=$FF los deja fuera de la pantalla visible). Sin esto, los sprites no usados se ven como basura en la esquina superior izquierda (Y=0 tras la limpieza de RAM).
- Hitbox del jugador: definida como constante (8x8, sin margen) en `src/main.s`, pero sin consumir todavía — el sistema de colisión real es F3.3.
- Límite de sprites por scanline (hardware): 8 máximo. Con 3 sprites totales, muy por debajo; se revisará activamente cuando haya más entidades simultáneas (Fase 5+).

### Física del jugador y punto fijo (decidido — F3.2, 2026-11-10)

- **Formato de punto fijo: 8.8.** Cada valor de posición/velocidad es de 16 bits: byte alto = píxeles enteros, byte bajo = fracción de píxel (256 = 1 píxel). Se usa tanto para posición (`player_x`, `player_y`) como para velocidad (`player_vx`, `player_vy`), con velocidad en complemento a 2 (con signo).
- **Comparación de 16 bits con signo:** `cmp16_signed` implementa el idiom estándar de resta + corrección por overflow (XOR con `$80` si V=1) para clamps de velocidad donde el signo del operando varía (ej. velocidad horizontal, que puede ser positiva o negativa según la dirección). Para comparaciones donde YA se sabe que ambos operandos son negativos (ej. el corte de salto variable), comparar solo el byte alto sin signo es válido y más simple — el orden se preserva cuando ambos valores están en el mismo "lado" del rango.
- **Piso temporal:** `GROUND_Y` es una constante fija (no colisión real contra tiles) hasta que F3.3 implemente colisión real contra `scene_pradera`. Documentado explícitamente en el código para que no se confunda con un sistema de colisión terminado.
- **Parámetros de física** (ajustables sin tocar lógica): `MOVE_ACCEL`, `MOVE_FRICTION`, `MOVE_MAX_SPEED`, `GRAVITY`, `MAX_FALL_SPEED`, `JUMP_VELOCITY`, `JUMP_CUT_SPEED_NEG` — todos en `src/main.s`, documentados con su valor en px/frame o px/frame².
- **Salto variable:** soltar A mientras `vy` es más negativo que `JUMP_CUT_SPEED_NEG` lo recorta a ese valor — confirmado por prueba automatizada que un salto corto alcanza menos altura que uno largo.

### Colisión contra tiles (decidido — F3.3, 2026-11-10)

- **Tipo de colisión por metatile**, no por tile individual: cada metatile de `scene_pradera` (16x16px) tiene un byte de tipo en `scene_pradera_collision` (generado por `tools/build_scene.py`): `0`=vacío, `1`=sólido (bloquea en cualquier dirección), `2`=plataforma de un solo sentido (bloquea solo cayendo, `vy>=0`), `3`=peligro (no bloquea; hace reaparecer en `SPAWN_X`/`SPAWN_Y`).
- **Consulta:** `get_tile_collision` resuelve el metatile que contiene un punto de píxel dado. Como cada metatile mide 16px, `índice = (y AND $F0) + (x >> 4)` — enmascarar el nibble alto de `y` da directamente `fila*16`, sin necesitar desplazar y volver a multiplicar.
- **Resolución por eje:** `update_player` mueve primero en X y resuelve colisión horizontal (solo `COLLISION_SOLID` bloquea), luego mueve en Y y resuelve verticalmente (suelo/plataforma si `vy>=0`, techo —solo sólido— si `vy<0`). Revisar un eje a la vez, después de aplicar su propia velocidad, es el patrón estándar para hitboxes pequeños relativos al tamaño de tile (evita necesitar barrido continuo/swept collision).
- **Esquinas revisadas:** con hitbox de 8x8 y metatiles de 16x16, revisar las 2 esquinas relevantes por eje (o las 4 para peligro) es suficiente — el hitbox nunca puede abarcar más de 2 metatiles por eje.
- **Peligro = placeholder de daño:** no hay sistema de vida todavía (Fase 5/6); tocar un metatile de peligro simplemente reaparece a Chiquito en el punto de inicio de la escena.
- **Hallazgo real corregido:** la velocidad residual transitoria documentada como "sin impacto" en F3.2 sí tenía impacto real combinada con colisión (desplazaba a Chiquito una distancia significativa antes de asentarse). Corregido re-inicializando `player_vx`/`player_vy` a 0 explícitamente en `reset`, justo antes del main loop.

### Máquina de estados del jugador (decidido — F3.4, 2026-11-10)

- **Estados:** `STATE_IDLE`/`WALK`/`JUMP`/`FALL` se recalculan cada frame desde la física resuelta (`recompute_normal_state`, basada en `player_on_ground` y la velocidad). `STATE_ATTACK`/`HURT`/`DEAD` tienen un temporizador propio (`state_timer`) y SIEMPRE salen solos al llegar a 0 — ningún estado puede quedar trabado indefinidamente (ver bug real corregido abajo, que sí violaba esto).
- **Gating de input por estado:** `HURT` y `ATTACK` bloquean el input horizontal/de salto (se fuerza el camino de fricción), pero gravedad y colisión siguen corriendo normal — así el knockback de `HURT` se ve como un knockback real, no como un teletransporte.
- **Peligro → HURT, no respawn instantáneo:** tocar un metatile de peligro aplica knockback real (velocidad, no cambio de posición) y entra en `HURT` con parpadeo de invulnerabilidad. La reaparición real (`respawn_player`) solo pasa al expirar `STATE_DEAD`.
- **Muerte por caída:** si `player_y_hi >= DEATH_Y_THRESHOLD` (más allá de la pantalla visible de 224px), entra en `STATE_DEAD` (congelado) sin necesitar un sistema de vida — placeholder hasta Fase 5/6, igual que el peligro.
- **Bug real corregido:** el guard de "recalcular estado normal" olvidaba excluir `STATE_DEAD`, así que `recompute_normal_state` sobrescribía DEAD de vuelta a FALL en el mismo frame — Chiquito nunca llegaba a reaparecer. Encontrado con traza frame a frame, no a simple vista.
- **Animaciones sin arte dedicado:** sin tiles propios para salto/caída/ataque/daño/muerte todavía; `@animate` reutiliza idle/caminar como diferenciadores visuales mínimos. Arte real pasa por el mismo pipeline de F2.2/F2.3 cuando esté listo.

### Sistema de mapas (decidido — F4.1, 2026-11-10)

- **Formato de mapa:** texto plano, editable sin tocar Python. Una leyenda (`carácter=NOMBRE_DE_METATILE`) seguida de una línea en blanco y una grilla de 16x15 caracteres (una pantalla completa = un nametable). El carácter `S` es especial: además de su metatile de leyenda, marca el punto de aparición del jugador (exactamente uno por mapa), calculado como `SPAWN_X=columna*16, SPAWN_Y=fila*16+8` (alineado abajo-izquierda dentro de la celda de 16x16, para que el hitbox de 8x8 quede parado justo sobre la celda de abajo).
- **`tools/map2scene.py`** reemplaza a `tools/build_scene.py` (F2.2/F3.3/F3.4): la definición de metatiles (tiles+paleta+colisión) se mantiene igual, pero la DISPOSICIÓN de la escena ahora viene de un archivo externo (`assets/maps/*.txt`), no de código Python. Migración verificada sin pérdida: el ROM compilado desde el mapa externo es byte-por-byte idéntico al que generaba la escena hardcodeada.
- **Límite de tamaño:** 1264 bytes de PRG-ROM por mapa sin comprimir (960 tiles + 64 atributos + 240 colisión). ~100 mapas de este tamaño caben en los 128 KB de PRG-ROM sin necesitar compresión. RLE es la técnica estándar de NES para esto si alguna vez hace falta (Fase 8) — no implementada porque no hace falta todavía.
- **Todavía no es scroll/multi-pantalla:** un mapa sigue siendo una sola pantalla fija (16x15 metatiles). Soporte para niveles más grandes que una pantalla es F4.2 (scrolling) y F4.3 (pantallas y habitaciones).

### Scrolling horizontal (decidido — F4.2, 2026-11-11)

- **Coordenadas de mundo:** la X del jugador pasa de 1 byte (0-255, una pantalla) a 16 bits de mundo (`player_x_frac`/`player_x_px_lo`/`player_x_px_hi`, hasta `LEVEL_WIDTH_PX` = `LEVEL_COLS*16`). La Y sigue en 1 byte — no hay scroll vertical todavía, y 15 filas*16px=240px entra sin problema en un byte. La suma de velocidad (16 bits con signo) al tercer byte de posición necesita extensión de signo explícita (`$00`/`$FF` según `player_vx_hi` sea positivo/negativo) — patrón estándar de 6502 para sumas de ancho mixto.
- **Colisión de 16 bits:** `LEVEL_COLS` (48, no potencia de 2) rompe el truco de F3.3 de enmascarar el nibble alto de Y para obtener fila*16. `get_tile_collision` ahora usa una tabla precalculada de offsets por fila (`scene_pradera_row_offset_lo/hi`, generada por `map2scene.py`) más un puntero indirecto de 16 bits (`col_ptr_lo/hi`) hacia `scene_pradera_collision` — técnica estándar de NES para tablas >256 bytes (el mapa de colisión del nivel de prueba ya pesa 720 bytes).
- **Mirroring vertical real:** el bit de mirroring del header iNES era provisional desde F0.2 (nunca importaba porque no había scroll). Ahora se fija a vertical (bit0=1 en el header, valor `$00` en el registro propio de MMC3 en `$A000`, programado en `reset`) — necesario para que `$2000`/`$2400` sean nametables físicamente distintos; sin esto, el scroll horizontal repetiría la misma pantalla en vez de revelar contenido nuevo.
- **Cámara sin suavizado:** `camera_x` se recalcula entera cada frame (`clamp(player_x - CAMERA_OFFSET, 0, MAX_CAMERA_X)`), no hay interpolación/lerp. Es la decisión más simple que cumple el criterio de aceptación (desplazamiento continuo sin corrupción); un seguimiento con suavizado (deadzone, easing) queda abierto para cuando el diseño de nivel lo pida explícitamente.
- **Streaming de pantallas (técnica de 2 nametables en "round-robin"):** con solo 2 nametables físicos y niveles de más de 2 pantallas, cada nametable alterna qué pantalla lógica contiene según una regla FIJA: `slot = pantalla_lógica AND 1` (pares -> `$2000`, impares -> `$2400`) — como dos pantallas consecutivas siempre tienen paridad distinta, "la pantalla actual" y "la siguiente" nunca compiten por el mismo slot en el mismo frame. Cuando la cámara necesita una pantalla que no coincide con lo que ya hay en su slot, se arranca una transmisión de 1024 bytes repartida en `STREAM_BUDGET`=16 bytes/frame (64 frames para completarse) reutilizando `ppu_queue_push` (la cola de F1.3, sin uso real hasta esta tarea) — nunca se escribe VRAM fuera de VBlank. 16 bytes/frame se eligió por margen amplio: a `MOVE_MAX_SPEED` cruzar una pantalla completa (256px) tarda ~170 frames, muy por encima de los 64 que tarda transmitir una.
- **`$2005`/`$2006` comparten latch:** PPUSCROLL y el bit de nametable de PPUCTRL se escriben en `nmi` DESPUÉS de `ppu_queue_flush` — cada entrada de la cola escribe `$2006` dos veces (par), así que el latch interno de "primer/segundo byte" siempre vuelve al mismo estado con el que entró al NMI, dejando seguro escribir `$2005` (X, luego Y) justo después sin necesitar leer `$2002` para resetearlo.
- **Bug real encontrado y corregido (preexistente desde F1.3, no introducido por esta tarea):** `reset` limpia la RAM asumiendo que X llega en 0 al bucle de limpieza (`txa`), pero el bucle de inicialización de MMC3 deja X en 8. Esto hacía que el bucle de limpieza escribiera 8 (no 0) en los offsets 8-255 de cada página de RAM, dejando los offsets 0-7 sin tocar. Era invisible porque toda variable afectada en offset>=8 se reinicializaba explícitamente después o se recalculaba cada frame desde cero; las variables nuevas de cámara/streaming de esta tarea cayeron en ese rango roto y nunca se reinicializan explícitamente, así que arrancaban en 8. Corregido forzando `lda #$00`/`ldx #$00` antes del bucle de limpieza, sin depender del valor que deje el código anterior. Ver registro completo en `TASKS.md` F4.2.
- **Todavía no hay scroll vertical** ni carga/streaming de más de 1 pantalla adelantada a la vez (suficiente para el nivel de prueba de 3 pantallas).

### Habitaciones fijas y puertas (decidido — F4.3, 2026-11-11)

- **Una habitación NO es un formato nuevo:** es el mismo mapa de metatiles de F4.1/F4.2. Lo que la hace "fija" (sin scroll) es simplemente tener 1 sola pantalla (16 columnas) -- con eso, `room_max_camera` (ver abajo) sale en 0 por aritmética, así que `clamp(player_x-120, 0, 0)` siempre da 0. El motor de cámara/streaming de F4.2 no necesita ninguna rama especial para "modo habitación fija": se degrada correctamente solo.
- **Multi-mapa en un mismo binario:** antes de esta tarea, `tools/map2scene.py` generaba símbolos fijos (`scene_pradera_*`, `SPAWN_X`, `LEVEL_SCREENS`...), válido mientras solo existiera un mapa. Ahora requiere `--label <prefijo>` y todos los símbolos (incluyendo las constantes `{LABEL}_SPAWN_X/Y`, `{LABEL}_LEVEL_SCREENS/COLS`) llevan ese prefijo, para que 2+ mapas convivan en el mismo `main.s` sin colisión de nombres.
- **`room_descriptors` + `load_room`:** en vez de que `get_tile_collision`/`update_camera_and_streaming`/`start_stream` referencien símbolos fijos de compilación (válido con 1 solo mapa), ahora leen variables de RUNTIME (`room_collision_lo/hi`, `room_row_lo_ptr`/`room_row_hi_ptr`, `room_screen_ptrs`, `room_screens`, `room_max_camera_lo/hi`) que `load_room` carga desde una tabla `room_descriptors` (RODATA, un registro de 14 bytes por habitación) cada vez que se cambia de habitación. `reset` ahora solo llama a `load_room(ROOM_PRADERA)` en vez de tener su propio código de carga de nametable/posición inicial -- esa lógica se generalizó una sola vez.
- **Transición instantánea, no repartida en VBlanks:** a diferencia del streaming de F4.2 (que reparte 1024 bytes en 64 frames porque es invisible, por delante de la cámara), un cambio de habitación es un corte discreto que el jugador SÍ nota -- `load_room` apaga el renderizado, recarga el/los nametable(s) completos de una sola vez vía `$2006`/`$2007` directo, y lo vuelve a encender. Un parpadeo de ~1 frame es la técnica estándar de NES para esto, no un defecto a corregir.
- **Puertas sin mapa de destinos (limitación deliberada):** `COLLISION_DOOR` es un tipo de colisión más (no bloquea, como peligro), pero el mapa no lleva A DÓNDE lleva cada puerta -- con solo 2 habitaciones, el destino es literalmente "la otra" (`room_current EOR 1`). Un mapa real de puertas->(habitación, spawn) es trabajo futuro si se agregan más de 2 habitaciones o más de una puerta por mapa.
- **`respawn_player` generalizado:** ahora es `load_room(room_current)` en vez de reaparecer en una posición fija de pradera -- corrige lo que habría sido un bug real si "morir por caída" ocurriera fuera de pradera (no pasa hoy porque la Casa Pipapita no tiene cómo caerse del mapa, pero la corrección es general, no un parche puntual).
- **Persistencia de objetos/enemigos: DEFINIDA, no implementada.** No hay sistema de entidades real todavía (Fase 5) -- nada que persistir hoy. Mecanismo decidido para cuando exista: un byte de banderas por habitación en RAM (bits = ítem recolectado / enemigo derrotado), indexado igual que `room_descriptors`, válido solo dentro de la misma partida (no sobrevive un apagado). Implementarlo de verdad es tarea de Fase 5/6.
- **Bug real encontrado y corregido:** agregar el 6to tile (puerta) a `assets/tiles/pradera.png` desalineó los índices `TILE_CHIQUITO_IDLE/WALK/ENEMY/ITEM` (hardcodeados asumiendo 5 tiles de fondo antes de los de sprite en el mismo CHR-ROM) -- los sprites se veían con el tile/color equivocado. Corregido actualizando los índices de 5/6/7/8 a 6/7/8/9. Ver registro completo en `TASKS.md` F4.3.

### Elementos de escenario (decidido — F4.4, 2026-11-11)

- **Un ejemplo real por mecánica, no un sistema general:** decidido con el usuario antes de implementar. Plataforma móvil, interruptor+puerta bloqueada y punto de control son variables/lógica hardcodeadas para UNA instancia cada una, no una tabla de N instancias. Construir el sistema general ahora duplicaría trabajo de F5.1 (sistema de entidades), que es exactamente donde corresponde esa generalización.
- **La plataforma móvil reusa un tile de FONDO como sprite:** en vez de agregar un tile de sprite nuevo, `TILE_PLATFORM_SPRITE` referencia el mismo índice que `T_PLATFORM` (tile de fondo). Funciona hoy porque los 6 registros de banco CHR de MMC3 (R0-R5) siguen apuntando todos al banco físico 0 (ver nota de `mmc3_init_values`, F1.3): pattern table 0 (fondo) y pattern table 1 (sprites) muestran los mismos bytes de CHR-ROM. El día que haya bank-switching de CHR real, este acoplamiento se rompe y la plataforma necesitará su propio tile de sprite -- documentado explícitamente en el código para que no sea una sorpresa.
- **Colisión con estado dinámico:** hasta F4.3, un valor de `COLLISION_*` era un hecho fijo de ROM (el mapa de colisión no cambia en tiempo de ejecución). `COLLISION_LOCKED_DOOR` rompe eso a propósito: el dato en ROM siempre dice "puerta bloqueada", y `get_tile_collision` lo traduce a SOLID/EMPTY leyendo `switch_casa_open` cada vez. Es la primera vez que la colisión depende de algo que no es el mapa -- un precedente a tener en cuenta si Fase 5/6 agrega más estado que afecte colisión (ej. bloques rompibles).
- **Tolerancia de aterrizaje, no igualdad exacta:** el chequeo de "¿Chiquito aterrizó en la plataforma?" acepta un rango de píxeles (`PLATFORM_LANDING_TOLERANCE`=4, igual al entero de `MAX_FALL_SPEED`) en vez de exigir que el pie caiga exactamente en `PLATFORM_Y`. A velocidad de caída máxima el jugador puede saltarse ese píxel exacto en un solo frame; un chequeo de igualdad estricta lo deja caer a través la mayoría de las veces. Mismo principio que ya se aplicó en otros chequeos de colisión del proyecto (revisar un rango/ventana, no un valor puntual).
- **Checkpoint como "slot" único, no tabla por habitación:** `checkpoint_room` + comparación contra `room_current` en `load_room` alcanza para 2 habitaciones. Generalizar a "un checkpoint por habitación simultáneamente" es una tabla indexada igual que `room_descriptors` -- no se construyó porque nada la necesita todavía.
- **"Obstáculos" no agregó mecánica nueva:** decidido que los tipos de colisión ya existentes (sólido, peligro, plataforma de un sentido) ya cubren el concepto. Inventar un tipo de obstáculo nuevo sin una habilidad del jugador que interactúe distinto con él (romper, empujar) habría sido una mecánica sin propósito real.
- **Bugs reales encontrados y corregidos:** 2 errores de rango de branch en ensamblado (el bloque de la plataforma móvil quedó demasiado largo para un `bne`/`bmi` relativo -- resuelto con branch-corto + `jmp`, patrón estándar de 6502); el mismo bug de desalineación de índices de sprite que F4.3 (ahora con 8 tiles de fondo, no 6). Ver registro completo en `TASKS.md` F4.4.

## 10. Rendimiento

Prioridades:

- Mantener la lógica dentro del tiempo disponible por frame.
- Actualizar PPU durante ventanas seguras.
- Utilizar DMA para OAM cuando corresponda.
- Evitar escrituras incorrectas durante renderizado.
- Controlar la cantidad de sprites por scanline.
- Medir el rendimiento en emulador.

## 11. Pruebas

Cada módulo debe tener pruebas funcionales.

Validar:

- Movimiento.
- Colisiones.
- Cámara.
- Transiciones.
- Lectura de controles.
- Actualización de sprites.
- Recolección.
- Guardado, si se implementa.
- Compatibilidad de la ROM.