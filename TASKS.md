# TASKS.md — Plan maestro de trabajo para el videojuego NES

## Estado general

- [x] Proyecto validado en repositorio Git (local, `main`, autor `yetto-tools`).
- [x] Toolchain y entorno inspeccionado e instalado (ver F0.1): CC65 y FCEUX en WSL, Mesen2/FCEUX en Windows.
- [x] Mapper y layout de memoria confirmados (F0.2, F1.1): MMC3, iNES 1.0, PRG 128KB/CHR 128KB, RAM layout documentado.
- [ ] Nivel vertical de demostración por construir. (ROM mínima que enlaza y carga ya existe — F1.1 — falta inicialización real, gráficos, jugador, etc.)
- [ ] Producción completa pendiente.

**Regla:** actualizar este archivo en cada sesión de desarrollo. Una tarea solo se marca como completada cuando se cumplen sus criterios de aceptación y se registran pruebas reales.

## Prioridad y estados

- `P0`: bloquea el resto del proyecto.
- `P1`: necesaria para el primer nivel jugable.
- `P2`: necesaria para completar el juego.
- `P3`: mejora opcional.
- Estados: `Pendiente`, `En progreso`, `Bloqueada`, `Implementada`, `Compilada`, `Probada`.

---

# Fase 0 — Inspección y definición técnica

## F0.1 Inspeccionar repositorio [P0]
- [x] Revisar estructura, archivos y estado Git.
- [x] Detectar código existente y evitar sobrescrituras.
- [x] Identificar sistema operativo y herramientas disponibles.
- [x] Registrar versiones de compilador, linker y emuladores.
- [x] Confirmar cómo se ejecuta el build actual, si existe.

**Aceptación:** informe de estado con archivos relevantes, herramientas detectadas y bloqueos.

### Informe de estado (2026-11-10)

**Estructura y Git:**
- No existe código fuente (`src/`, assets, ROM). Repositorio es solo documentación de diseño.
- `C:\Users\erashon\umg\nes-advance` no es un repositorio Git todavía (no hay `.git/`).

**Decisión de toolchain:** build en WSL (Ubuntu), emuladores tanto en WSL (GUI vía WSLg) como en Windows nativo, por disponibilidad real de paquetes.

**Entorno Windows (host):**
- Git 2.56.0 — instalado.
- Python 3.14.7 — instalado.
- Node.js v24.21.0 — instalado.
- `ca65`/`ld65`/`cl65` (CC65) — no instalado, no disponible vía winget/choco.
- Mesen2 (`SourMesen.Mesen2` 2.1.1) — **instalado** vía winget.
- FCEUX (`FCEUX.FCEUX` 2.6.6) — **instalado** vía winget.

**Entorno WSL (Ubuntu 26.04 "resolute"):**
- Bloqueo encontrado y resuelto: `/home/erashon` tenía permisos `0600` en vez de `0755` (faltaba el bit de ejecución), lo que rompía el login shell (`.bash_profile: Permission denied`) y cualquier operación en el home. Corregido con `chmod 755 /home/erashon`.
- `cc65`/`cc65-doc` — **instalado** (`sudo apt install cc65 cc65-doc fceux`, ejecutado por el usuario el 2026-11-10). Verificado: `ca65` V2.18, `ld65` V2.18, `cl65` V2.18 (Ubuntu 2.19-2build1).
- `fceux` — **instalado** en la misma corrida. Verificado: versión 2.6.5.
- Mesen2 Linux x64 — descargado y probado manualmente en `~/tools/mesen2/Mesen` (build standalone, sin dependencias de sistema faltantes según `ldd`). Corre correctamente vía WSLg (confirmado: proceso estable, sin errores en log).
- WSLg (soporte GUI en WSL) — confirmado funcionando (`DISPLAY`, `WAYLAND_DISPLAY` y `/mnt/wslg` presentes).

**Bloqueos pendientes:** ninguno.

**F0.1 cerrado:** toolchain completo (build + 2 emuladores) disponible y verificado en WSL. Sin bloqueos restantes para empezar Fase 1 (infraestructura de ROM).

## F0.2 Definir plataforma y mapper [P0]
- [x] Elegir objetivo inicial NTSC, PAL o compatibilidad dual.
- [x] Evaluar MMC3 frente a alternativas según alcance.
- [x] Definir iNES o NES 2.0.
- [x] Definir PRG-ROM, CHR-ROM/CHR-RAM y bancos.
- [ ] Definir linker config y layout de memoria. *(pendiente — se escribe en F1.1 junto con la ROM mínima)*
- [x] Documentar compatibilidad esperada.

**Aceptación:** configuración consistente entre header, linker y código de mapper; ROM mínima validada.

### Decisiones (2026-11-10) — ver detalle y justificación en `ARCHITECTURE.md` sección 9

- Región: **NTSC** únicamente.
- Mapper: **MMC3 (Mapper 4)** — necesario por su IRQ de scanline para el HUD fijo.
- Header: **iNES 1.0**.
- Tamaño inicial de ROM: **PRG-ROM 128 KB / CHR-ROM 128 KB** (no CHR-RAM).
- Compatibilidad esperada: Mesen2 y FCEUX (no probado en hardware real todavía).

**F0.2 funcionalmente cerrado.** Solo falta el linker config real, que se produce junto con la ROM mínima en F1.1 — ahí se valida la aceptación completa de esta tarea.

## F0.3 Definir identidad del juego [P1]
- [ ] Proponer nombres originales para juego, protagonista y universo.
- [ ] Definir premisa narrativa breve.
- [ ] Definir fantasía central del jugador.
- [ ] Definir pilares de experiencia.
- [ ] Aprobar alcance inicial de mundos y mecánicas.

**Aceptación:** decisiones documentadas en `GAME_DESIGN_DOCUMENT.md`; no inventar aprobaciones.

---

# Fase 1 — Infraestructura de ROM

## F1.1 Toolchain y build [P0] — Implementada, compilada, probada en emulador (2026-11-10)
- [x] Configurar ca65/ld65. (WSL/Ubuntu, `cc65` v2.19-2build1 — ver F0.1)
- [x] Crear linker config. (`linker/chiquito.cfg`, Mapper 4/MMC3, PRG-ROM 128KB / CHR-ROM 128KB)
- [x] Crear script de build reproducible. (`Makefile`: `make rom|check|run|clean`)
- [x] Añadir validación de encabezado y tamaño de ROM. (`tools/validate_rom.py`, corre automáticamente tras `make rom`)
- [x] Añadir limpieza de artefactos generados. (`make clean` borra `dist/`)
- [x] Documentar comandos en README. (sección "Build" en `README.md`)

**Aceptación:** configuración consistente verificada.

**Registro de la tarea:**
- Archivos: `src/main.s`, `linker/chiquito.cfg`, `Makefile`, `tools/validate_rom.py`, `tools/test_boot.lua`, `.gitignore`.
- Comando de build: `make clean && make rom` (en WSL/Ubuntu).
- Resultado de compilación: éxito. `dist/chiquito.nes`, 262160 bytes, header iNES válido (mapper 4, PRG 128KB, CHR 128KB). Build repetido dos veces produce el mismo SHA-256 (reproducible).
- Prueba ejecutada: `fceux --loadlua tools/test_boot.lua dist/chiquito.nes`.
- Resultado observado: FCEUX reconoce "Mapper #: 4 / Mapper name: MMC3", carga la ROM, corre 30 frames vía el script Lua y sale limpiamente (`Emulator Start` → `Emulator Exit`, sin errores).
- Limitaciones pendientes: `main.s` es intencionalmente mínimo (`reset` es un bucle infinito, `nmi`/`irq` son `rti`). No hay inicialización real de pila/PPU/APU, no hay gráficos, no se ha probado en hardware real. Eso corresponde a F1.2 y F1.3.

## F1.2 Reset e inicialización [P0] — Implementada, compilada, probada en emulador (2026-11-10)
- [x] Implementar reset.
- [x] Inicializar stack. (`ldx #$ff` / `txs`)
- [x] Configurar interrupciones. (IRQ de frame de APU y DMC desactivados; NMI/IRQ de CPU dejados desactivados a propósito — se habilitan en F1.3)
- [x] Inicializar PPU y APU de forma segura. (dos esperas de VBlank antes de escribir VRAM; paleta completa inicializada a negro `$0F`)
- [x] Limpiar buffers y estado de RAM. (`$0000-$07FF` a cero)
- [x] Esperar sincronización de PPU cuando sea necesario. (esperas de VBlank antes de cada acceso a VRAM)

**Aceptación:** ROM arranca de forma estable y no muestra corrupción inicial.

**Registro de la tarea:**
- Archivos: `src/main.s` (rutina `reset` reemplazada por la secuencia real), `tools/test_init.lua` (nuevo).
- Comando de build: `make clean && make rom`.
- Resultado de compilación: éxito, `dist/chiquito.nes` válido (mismo header/tamaño que F1.1).
- Prueba ejecutada: `fceux --loadlua tools/test_init.lua dist/chiquito.nes`, automatizada (escribe resultado a archivo, no requiere inspección manual).
- Resultado observado: tras 10 frames, `PC` queda dentro del banco fijo (`$C05B`, rango `$C000-$FFF9`) — confirma que el reset terminó y quedó en el bucle estable, no colgado ni saltado fuera de rango. Los 5 píxeles muestreados (esquinas + centro) son negro puro `(0,0,0)` — confirma paleta inicializada, sin colores de encendido indefinidos ni basura visual. `RESULT=PASS`.
- Verificación adicional: la ROM también carga y corre sin errores en Mesen2 (proceso estable, sin mensajes de error).
- Limitaciones pendientes: NMI real, cola de PPU y OAM DMA no implementados todavía (`nmi`/`irq` siguen siendo `rti`); no hay renderizado de fondo/sprites (deliberado, sin nametables ni CHR todavía); no probado en hardware real.

## F1.3 NMI/IRQ [P0] — Implementada, compilada, probada en emulador (2026-11-10)
- [x] Implementar NMI.
- [x] Definir responsabilidades de NMI. (orden fijo documentado en el encabezado de `src/main.s`: 1. OAM DMA, 2. flush de cola de PPU, 3. contador/bandera de frame)
- [x] Implementar cola PPU inicial. (`ppu_queue_push`/`ppu_queue_flush`, capacidad 32 entradas; todavía sin llamadores — mecanismo probado, no usado por contenido real aún)
- [x] Implementar OAM DMA. (buffer de sombra `oam_buffer` alineado en página `$0200` vía nuevo segmento `OAM` del linker; DMA disparada cada NMI)
- [ ] Añadir IRQ solo si el mapper y una característica aprobada lo requieren. (no aplica todavía: sin HUD con split-screen ni otra necesidad de IRQ de mapper)
- [x] Medir presupuesto de rutinas. (estimado por cálculo de ciclos, no medido con profiler — ver limitación abajo)

**Aceptación:** sincronización estable y rutinas documentadas; no exceder presupuesto sin detección.

**Registro de la tarea:**
- Archivos: `src/main.s` (NMI real, `ppu_queue_push`/`ppu_queue_flush`, main loop con handshake `frame_ready`), `linker/chiquito.cfg` (nuevo segmento `OAM` en `$0200-$02FF`), `tools/test_nmi.lua` (nuevo).
- Comando de build: `make clean && make rom`.
- Resultado de compilación: éxito. Mapa de segmentos verificado: `OAM` en `$0200-$02FF`, `ZEROPAGE` `$0000-$0004`, `BSS` desde `$0300` (98 bytes: cola de PPU), `STARTUP` dentro de `$C000-$FFF9`.
- Prueba ejecutada: `fceux --loadlua tools/test_nmi.lua dist/chiquito.nes`.
- Resultado observado: `frame_count` avanzó exactamente 20 en 20 frames (delta=20) — el NMI se dispara una vez por frame, sin duplicarse ni perderse. PC estable en el banco fijo tras la OAM DMA. `ppu_queue_overflow=0`. `RESULT=PASS`.
- Presupuesto de VBlank (estimado por cálculo de ciclos, documentado en `src/main.s`): OAM DMA ~514 ciclos + flush de cola en el peor caso (32 entradas) ~992 ciclos + overhead ~45 ciclos ≈ 1551 ciclos, dentro de los ~2273 ciclos disponibles en VBlank NTSC. **No es una medición real con el profiler de Mesen2** — pendiente de verificar ahí cuando exista contenido real que llene la cola.
- Limitaciones pendientes: la cola de PPU no tiene todavía ningún llamador real (nada encola escrituras aún); no hay IRQ de mapper (no hace falta todavía); no hay registros de scroll (sin cámara, Fase 4); no probado en hardware real.

---

# Fase 2 — Gráficos y pipeline de assets

## F2.1 Paletas [P1] — Implementada, compilada, probada en emulador (2026-11-10)
- [x] Seleccionar paletas reales de NES para pradera. (cielo/pradera/tierra, `src/data/palettes.s`)
- [x] Crear paletas para jugador, enemigos y objetos. (3 subpaletas de sprite definidas; sin usar todavía — sprites apagados hasta F2.3)
- [x] Crear paletas de fondo. (3 subpaletas de fondo + 1 sin usar)
- [x] Validar atributos de fondo. (tabla de atributos de 3 bandas horizontales, verificada byte a byte con `ppu.readbyte` en FCEUX)
- [x] Probar contraste en pantalla real. (captura real de FCEUX, 3 colores distintos confirmados por píxel)

**Aceptación:** paletas válidas y legibles en ROM, no solo en editor.

**Registro de la tarea:**
- Archivos: `src/data/palettes.s` (nuevo), `src/data/chr_test.s` (nuevo — tile de prueba sólido, NO arte final, ver nota abajo), `src/main.s` (carga de paleta real, llenado de nametable/atributos, inicialización de mapper MMC3, habilitación de renderizado de fondo), `tools/test_palette.lua` (nuevo).
- Comando de build: `make clean && make rom`.
- Resultado de compilación: éxito, mismo header/tamaño que fases anteriores.
- Prueba ejecutada: `fceux --loadlua tools/test_palette.lua dist/chiquito.nes`, automatizada (usa `emu.getscreenpixel`, que lee el framebuffer real).
- Resultado observado: 3 píxeles muestreados (uno por banda) dan colores distintos y ninguno negro — cielo `(93,150,255)`, pradera `(130,211,16)`, tierra `(203,77,12)`. `RESULT=PASS`. También confirmado visualmente con una captura real (3 bandas horizontales correctas) y verificado sin errores en Mesen2.
- **Dos hallazgos reales de hardware descubiertos y corregidos durante esta tarea** (documentados en comentarios del código, no solo aquí):
  1. El color índice 0 de las 4 subpaletas de fondo ($3F00/$3F04/$3F08/$3F0C) es la MISMA celda física en el PPU — no puede haber un "color 0" independiente por subpaleta. Se confirmó leyendo la VRAM directamente con `ppu.readbyte` en FCEUX tras observar que la pantalla salía negra con una paleta aparentemente correcta. Por eso la prueba usa un tile sólido de índice 1 (`chr_test.s`) en vez de depender del índice 0.
  2. Los registros de banco del mapper MMC3 (R0-R7) no tienen un valor por defecto garantizado al encender — a diferencia de $E000-$FFFF (fijo por hardware), TODO el espacio de CHR depende de ellos. Sin inicializarlos explícitamente, la PPU mostraba contenido que no correspondía a los bytes de CHR-ROM realmente escritos. Se agregó una inicialización explícita de R0-R7 en `reset` (ver `mmc3_init_values` en `src/main.s`).
- Limitaciones pendientes: `chr_test.s` es un tile de prueba técnico, no arte del juego (eso es F2.2/F2.3). Las paletas de sprite están definidas pero no usadas (sprites siguen apagados). No probado en hardware real.

## F2.2 Tiles y metatiles [P1] — Implementada, compilada, probada en emulador (2026-11-10)
- [x] Definir formato y organización CHR. (8x8, 2bpp planar estándar de NES; pattern table 0 = fondo, pattern table 1 reservada para sprites en F2.3)
- [x] Crear tiles iniciales de suelo, cielo, plataformas y decoración. (`assets/tiles/pradera.png`: 5 tiles — cielo, nube, suelo con pasto, relleno de tierra, plataforma)
- [x] Definir metatiles. (formato: 4 índices de tile de 16x16px + 1 índice de subpaleta; definidos en `tools/build_scene.py`)
- [x] Crear conversor o pipeline de importación. (`tools/png2chr.py`: PNG → CHR; `tools/build_scene.py`: metatiles → nametable/atributos)
- [x] Validar límites de patrones y bancos. (ver detalle abajo)

**Aceptación:** escenario inicial reproducible desde assets fuente.

**Registro de la tarea:**
- Archivos: `tools/gen_test_tileset.py` (genera el asset de prueba — NO es arte final), `assets/tiles/pradera.png` (asset fuente real, nuevo), `tools/png2chr.py` (conversor PNG→CHR, nuevo), `tools/build_scene.py` (compilador de metatiles→escena, nuevo), `src/main.s` (nueva rutina genérica `ppu_copy_bulk`, reemplaza el llenado manual de F2.1), `Makefile` (reglas para regenerar `dist/tiles_pradera.s` y `dist/scene_pradera.s` desde los assets fuente), `tools/test_tiles.lua` (nuevo). Se eliminó `src/data/chr_test.s` (superado; era el swatch técnico de F2.1) y `attr_table_pradera` de `palettes.s` (reemplazado por la escena compilada).
- Comando de build: `make clean && make rom` — regenera los `.s` desde los PNG/definiciones antes de ensamblar, sin pasos manuales.
- Resultado de compilación: éxito, mismo header/tamaño de ROM.
- Prueba ejecutada: `fceux --loadlua tools/test_tiles.lua dist/chiquito.nes`.
- Resultado observado: cielo azul `(93,150,255)` y suelo verde `(0,150,0)` confirmados por píxel en puntos alejados de la nube/plataforma; ninguno es negro. `PC` estable en el banco fijo. `RESULT=PASS`. Confirmado visualmente con captura real (cielo, nube, plataforma flotante y suelo con textura, ver conversación) y sin errores en Mesen2.
- **Límites de patrones y bancos (validado):** se usan 5 de los 128 tiles disponibles en la ventana CHR de 2KB mapeada por R0/R1 (banco físico 0); de los 256 tiles posibles en pattern table 0 completa (ambas ventanas de 1KB más las de 2KB), hay amplio margen para crecer antes de necesitar bank-switching de CHR. El CHR-ROM total es 128 KB; con 5 tiles (80 bytes) usados, queda prácticamente todo el espacio libre para contenido futuro.
- Limitaciones pendientes: los 5 tiles son una **prueba técnica de primera pasada** (formas geométricas simples en escala de grises), no arte final — el arte real del juego, con la identidad visual de `ART_GUIDELINES.md`, se produce después con el mismo pipeline. La disposición de la escena está fija en `build_scene.py` (no es un sistema de mapas general; eso es F4.1). No probado en hardware real.

## F2.3 Sprites [P1] — Implementada, compilada, probada en emulador (2026-11-10)
- [x] Diseñar protagonista original. (Chiquito — prueba técnica de primera pasada, no arte final; ver limitaciones)
- [x] Crear hoja de sprites. (`assets/sprites/chiquito_test.png`, vía el mismo pipeline `png2chr.py` de F2.2)
- [x] Definir animaciones y hitboxes. (2 frames: idle/caminar, alternan cada 16 frames vía `frame_count`; hitbox 8x8 definida como constante, sin usar todavía — colisión real es F3.3)
- [x] Crear enemigo inicial. (tile estático, subpaleta propia)
- [x] Crear coleccionable. (tile estático tipo gema, subpaleta propia)
- [x] Validar sprites por scanline. (ver detalle abajo — mecanismo real verificado, no asumido)

**Aceptación:** sprites se muestran y animan sin corrupción; límites documentados.

**Registro de la tarea:**
- Archivos: `tools/gen_test_spritesheet.py` (genera el asset de prueba), `assets/sprites/chiquito_test.png` (nuevo), `src/main.s` (constantes de tile/hitbox, datos iniciales de OAM, relleno de sprites sin usar con Y=$FF, animación en `mainloop`, `PPUCTRL`/`PPUMASK` actualizados para sprites en pattern table 1), `Makefile` (regla para `dist/tiles_sprites.s`), `tools/test_sprites.lua` (nuevo).
- Comando de build: `make clean && make rom`.
- Resultado de compilación: éxito, mismo header/tamaño de ROM.
- Prueba ejecutada: `fceux --loadlua tools/test_sprites.lua dist/chiquito.nes`.
- Resultado observado: los 3 sprites (Chiquito, enemigo, coleccionable) se ven en sus posiciones con colores distintos del fondo; la animación de Chiquito alterna correctamente entre tile idle (en frame_count=8) y tile caminar (en frame_count=29); la subpaleta de sprite seleccionada por atributo realmente distingue jugador (tan, `(255,154,56)`) de enemigo (rojo oscuro, `(166,0,0)`) en un píxel de contorno — confirma que la selección de subpaleta por atributo funciona, no solo que hay color. `$2002` bit 5 (desborde de sprites por scanline) no se activó. `RESULT=PASS`.
- **Sprites sin usar ocultos correctamente:** se detectó que, tras la limpieza de RAM, los 61 sprites sin usar quedaban en Y=0 (visibles como basura en la esquina superior izquierda al activar el renderizado de sprites). Corregido rellenando `oam_buffer` con `$FF` antes de escribir los 3 sprites reales — técnica estándar de NES para ocultar sprites no usados.
- **Límite de sprites por scanline (documentado, no solo asumido):** máximo real de hardware es 8 sprites por scanline; usamos 3 sprites en total, ninguno comparte scanline con otro en esta escena — muy por debajo del límite. El flag de desborde (`$2002` bit 5) se verificó leyéndolo directamente, no se asumió que "no debería activarse".
- **Incidente de entorno (no relacionado con la ROM):** Mesen2 empezó a fallar con `std::bad_cast` / señal 6 (abort) incluso sin cargar ninguna ROM, confirmado con `dmesg`. Se investigó: no es un lockfile ni un `settings.json` corrupto (se limpiaron ambos y el fallo persiste). Es una regresión del entorno/instalación de Mesen2 en WSL, no de este proyecto. FCEUX siguió funcionando normalmente durante toda la tarea y es la evidencia real detrás de este registro. Pendiente: reinstalar o diagnosticar Mesen2 cuando se necesite de nuevo.
- Limitaciones pendientes: los 4 tiles de sprite son una prueba técnica (formas geométricas simples), no arte final del juego — el arte real de Chiquito pasa por el mismo pipeline cuando esté listo. La hitbox está definida pero no consumida por ningún código de colisión todavía (F3.3). No probado en hardware real. Mesen2 no disponible temporalmente (ver incidente arriba).

---

# Fase 3 — Control, jugador y físicas

## F3.1 Controlador [P1] — Implementada, compilada, probada en emulador (2026-11-10)
- [x] Leer D-pad y botones A/B/Start/Select. (`read_controller1`, estrobe + 8 lecturas de `$4016`, orden estándar A/B/Select/Start/Up/Down/Left/Right)
- [x] Normalizar estado actual y anterior para detectar pulsaciones. (`pad1`, `pad1_prev`, `pad1_pressed` en Zero Page; `pad1_pressed` = flanco 0→1)
- [x] Probar combinaciones de botones. (A+Right simultáneos, ver registro abajo)

**Aceptación:** entradas consistentes y sin lecturas erráticas.

**Registro de la tarea:**
- Archivos: `src/main.s` (constantes `PAD_*`, variables `pad1`/`pad1_prev`/`pad1_pressed`, rutina `read_controller1`, llamada desde `mainloop`), `tools/test_controller.lua` (nuevo).
- Comando de build: `make clean && make rom`.
- Resultado de compilación: éxito, mismo header/tamaño de ROM.
- Prueba ejecutada: `fceux --loadlua tools/test_controller.lua dist/chiquito.nes`, usando `joypad.set` de FCEUX para simular entradas reales (no solo revisar que el código "se ve bien").
- Resultado observado (4 casos, todos `true`): (1) sostener A+Right por primera vez se detecta como pulsación nueva (`pad1=$81`, `pad1_pressed=$81`); (2) sostenerlos 5 frames más ya NO se marca como pulsación nueva (`pad1=$81`, `pad1_pressed=$00`) — confirma que distingue "sostenido" de "recién presionado"; (3) soltar todo limpia ambos a `$00`; (4) presionar un botón distinto (Down) después de soltar se detecta como pulsación nueva (`pad1=$04`, `pad1_pressed=$04`). `RESULT=PASS`.
- Limitaciones pendientes: solo mando 1 (no se implementó el 2, no hace falta para un juego de un jugador). Nada reacciona todavía a estos botones — eso es F3.2 (movimiento). No probado en hardware real ni con un mando físico (solo input simulado por script).

## F3.2 Movimiento [P1] — Implementada, compilada, probada en emulador (2026-11-10)
- [x] Definir formato de punto fijo. (8.8: byte alto = píxeles enteros, byte bajo = fracción; 256 = 1 píxel)
- [x] Implementar movimiento horizontal. (`update_player`, aceleración con Left/Right)
- [x] Implementar aceleración y desaceleración. (`MOVE_ACCEL` al sostener, `MOVE_FRICTION` al soltar, con clamp exacto en 0 para no oscilar)
- [x] Implementar gravedad. (`GRAVITY` acumulada cada frame, con velocidad terminal `MAX_FALL_SPEED`)
- [x] Implementar salto. (impulso `JUMP_VELOCITY` al presionar A estando en el piso)
- [x] Evaluar salto variable. (soltar A mientras sube recorta `vy` a `JUMP_CUT_SPEED_NEG` — confirmado que acorta el salto)
- [x] Definir velocidad máxima y control en el aire. (`MOVE_MAX_SPEED`/`NEG_MOVE_MAX_SPEED` para horizontal; no hay distinción aire/suelo para el control horizontal todavía — ver limitaciones)

**Aceptación:** movimiento repetible, estable y ajustable mediante parámetros documentados.

**Registro de la tarea:**
- Archivos: `src/main.s` (constantes de física `MOVE_*`/`GRAVITY`/`JUMP_*`/`GROUND_Y`, variables `player_x/y/vx/vy`, `player_on_ground`, `player_facing_right`, rutinas `cmp16_signed` y `update_player`, inicialización de posición en `reset`), `tools/test_movement.lua` (nuevo).
- Comando de build: `make clean && make rom`.
- Resultado de compilación: éxito, mismo header/tamaño de ROM.
- Prueba ejecutada: `fceux --loadlua tools/test_movement.lua dist/chiquito.nes`, usando `joypad.set` para simular Right/Left/A reales y leyendo la RAM de física directamente.
- Resultado observado (5 casos, todos `true`): sostener Right mueve a la derecha con `vx>0`; soltar hace que la fricción detenga `vx` en exactamente `0` (no oscila); sostener Left mueve a la izquierda con `vx<0`; soltar vuelve a detener `vx` en `0`; un salto corto (A un solo frame) alcanza una altura menor que uno largo (A sostenido), confirmando que el corte de salto variable funciona. `RESULT=PASS`. Confirmado también visualmente con captura real.
- **Piso temporal (`GROUND_Y`):** F3.2 usa una constante fija (Y=179, la misma donde ya estaba parado Chiquito) en vez de colisión real contra los tiles de `scene_pradera`. Esto es intencional y está documentado en el código — la colisión real contra el suelo/plataformas de la escena es F3.3.
- **Hallazgo de entorno (sin impacto funcional):** durante la instrumentación por Lua se observó que, en la ventana transitoria de 2-3 frames reales que tarda `reset` en terminar (antes de que `update_player` corra por primera vez, confirmado con `frame_count=0` y el PC todavía dentro de `reset`), algunas variables de física muestran un valor residual uniforme no explicado con certeza (posiblemente un artefacto de cómo FCEUX rellena RAM "sin inicializar" combinado con el punto exacto donde `frameadvance()` de Lua corta la ejecución). No tiene efecto visible ni funcional: el OAM del sprite todavía muestra la posición estática inicial durante esa ventana (nada copia `player_x/y` al OAM hasta que `update_player` corre por primera vez), y desde ese primer frame real en adelante la física es matemáticamente exacta (fricción decae en pasos de exactamente `MOVE_FRICTION`, confirmado byte a byte). `tools/test_movement.lua` espera a que termine el reset antes de medir, por lo que no se ve afectado.
- Limitaciones pendientes: no hay distinción entre control horizontal en el aire vs. en el piso (mismo `MOVE_ACCEL`/`MOVE_FRICTION` siempre); no hay tile de sprite dedicado para salto/caída (usa idle/caminar); no probado en hardware real.

## F3.3 Colisiones [P1] — Implementada, compilada, probada en emulador (2026-11-10)
- [x] Separar hitbox de sprite. (ya estaba definida en F2.3 — `PLAYER_HITBOX_W/H` —, ahora realmente usada)
- [x] Implementar suelo y paredes. (`get_tile_collision` + resolución por eje en `update_player`; suelo y paredes son metatiles tipo `COLLISION_SOLID`)
- [x] Implementar techos. (mismo tipo `COLLISION_SOLID`, revisado en el borde superior del hitbox cuando `vy<0`)
- [x] Implementar plataformas. (`COLLISION_PLATFORM`: bloquea solo cayendo — `vy>=0` —, se puede saltar a través desde abajo/los lados)
- [x] Implementar objetos dañinos. (`COLLISION_HAZARD`: no bloquea el movimiento; tocarlo hace reaparecer a Chiquito en `SPAWN_X`/`SPAWN_Y` — placeholder de "daño" hasta que exista un sistema de vida real, Fase 5/6)
- [x] Probar esquinas y velocidades máximas. (ver registro abajo: techo, pared, aterrizaje y peligro probados con input real)

**Aceptación:** no atraviesa superficies en casos límite probados.

**Registro de la tarea:**
- Archivos: `tools/build_scene.py` (extendido: campo de colisión por metatile, mapa de 240 bytes `scene_pradera_collision`, metatiles nuevos `WALL`/`HAZARD`, elementos de prueba agregados a la escena — pared, techo, peligro —, constantes `SPAWN_X`/`SPAWN_Y`), `src/data/palettes.s` (subpaleta de fondo 3 ahora tiene colores reales de "peligro"), `src/main.s` (`get_tile_collision`, colisión horizontal y vertical integradas en `update_player`, reaparición por peligro, re-cero defensivo de velocidad en `reset`), `tools/test_collision.lua` (nuevo).
- Comando de build: `make clean && make rom`.
- Resultado de compilación: éxito, mismo header/tamaño de ROM.
- Prueba ejecutada: `fceux --loadlua tools/test_collision.lua dist/chiquito.nes`.
- Resultado observado (4 casos, todos `true`): saltando desde el punto de aparición (ya debajo de un bloque de techo), la cabeza no pasa de `y=128` (el techo ocupa 112-127) — el salto se detiene contra el techo real; al caer, aterriza exactamente en `y=152` con `on_ground=1`; sosteniendo Left hasta la pared de prueba, se detiene exactamente en `x=32` (el borde de la pared) sin atravesarla; caminando a la derecha hasta la celda de peligro, Chiquito reaparece exactamente en `(96,152)`. `RESULT=PASS`.
- **Bug real encontrado y corregido durante esta tarea (resuelve también la nota de F3.2):** el "hallazgo de entorno sin impacto funcional" documentado en el registro de F3.2 (una ventana transitoria de ~45 frames con velocidad residual tras el arranque) SÍ tenía impacto real una vez que la colisión podía reaccionar a esos valores — se confirmó que no era un artefacto cosmético sino velocidad real (decayendo exactamente a razón de `MOVE_FRICTION` por frame) que desplazaba a Chiquito una distancia significativa antes de asentarse. Corregido re-inicializando explícitamente `player_vx`/`player_vy` a 0 en `reset`, inmediatamente antes de caer en el main loop (redundante con la limpieza de RAM anterior, pero cierra la ventana de forma defensiva). Confirmado con prueba automatizada: tras el fix, `vx`/`vy` leen exactamente 0 desde el primer frame real.
- Limitaciones pendientes: la pared/techo/peligro de prueba son parte de la escena de prueba técnica (`build_scene.py`), no diseño de nivel real. La colisión revisa solo las esquinas del hitbox (suficiente para un hitbox de 8x8 contra metatiles de 16x16, pero no generaliza a hitboxes más grandes sin revisarlo de nuevo). No hay sistema de vida real todavía (el peligro solo reaparece, no resta HP). No probado en hardware real.

## F3.4 Máquina de estados [P1]
- [ ] Idle.
- [ ] Walk/run.
- [ ] Jump/fall/land.
- [ ] Attack.
- [ ] Hurt/knockback.
- [ ] Dead.
- [ ] Conectar estados con animaciones.

**Aceptación:** transiciones deterministas y sin estados bloqueados.

---

# Fase 4 — Cámara, mapas y escenarios

## F4.1 Sistema de mapas [P1]
- [ ] Definir formato de mapa.
- [ ] Definir metatiles y propiedades de colisión.
- [ ] Crear un mapa de prueba.
- [ ] Crear herramienta de conversión.
- [ ] Documentar límites de tamaño y compresión.

**Aceptación:** mapa de fuente externa integrado correctamente en ROM.

## F4.2 Scrolling [P1]
- [ ] Implementar coordenadas de mundo.
- [ ] Implementar coordenadas de pantalla.
- [ ] Implementar cámara horizontal.
- [ ] Implementar límites de cámara.
- [ ] Actualizar nametables por sectores.
- [ ] Probar límites y wrap de scroll.

**Aceptación:** desplazamiento continuo sin corrupción gráfica.

## F4.3 Pantallas y habitaciones [P1]
- [ ] Definir formato de habitación.
- [ ] Implementar carga de habitación fija.
- [ ] Implementar puertas/salidas.
- [ ] Implementar transición y spawn.
- [ ] Definir persistencia de objetos y enemigos.

**Aceptación:** transición entre una zona de scrolling y una habitación fija sin pérdida de estado no deseada.

## F4.4 Elementos de escenario [P2]
- [ ] Plataformas móviles.
- [ ] Interruptores.
- [ ] Puertas.
- [ ] Obstáculos.
- [ ] Zonas secretas.
- [ ] Puntos de control.

**Aceptación:** cada elemento tiene comportamiento y pruebas documentadas.

---

# Fase 5 — Enemigos y combate

## F5.1 Sistema de entidades [P1]
- [ ] Definir estructura compacta de entidad.
- [ ] Definir número máximo simultáneo.
- [ ] Implementar creación y destrucción.
- [ ] Implementar actualización por prioridad o zona.

**Aceptación:** entidades no corrompen memoria ni exceden límites definidos.

## F5.2 Enemigos básicos [P1]
- [ ] Enemigo patrullero.
- [ ] Enemigo perseguidor o saltador.
- [ ] Enemigo de ataque a distancia.
- [ ] Daño y colisiones.
- [ ] Desaparición/reaparición según reglas.

**Aceptación:** comportamientos distintos y reproducibles.

## F5.3 Armas y proyectiles [P2]
- [ ] Definir sistema de ataque.
- [ ] Crear proyectiles.
- [ ] Detectar impactos.
- [ ] Definir daño, alcance y tiempo de vida.
- [ ] Administrar límite de proyectiles.

**Aceptación:** ataques no generan entidades infinitas ni exceden recursos.

## F5.4 Jefes [P2]
- [ ] Definir formato de patrón.
- [ ] Crear primer jefe original.
- [ ] Implementar fases y vulnerabilidad.
- [ ] Añadir indicador de energía.
- [ ] Añadir derrota y recompensa.

**Aceptación:** combate completo, ganable y repetible.

---

# Fase 6 — Power-ups y progresión

- [ ] Definir habilidades originales.
- [ ] Implementar obtención y activación.
- [ ] Implementar duración/energía/cooldown según diseño.
- [ ] Definir inventario o selección si aplica.
- [ ] Implementar coleccionables.
- [ ] Implementar vidas/energía y puntos de control.
- [ ] Definir progreso entre niveles.

**Aceptación:** las habilidades modifican el juego de forma comprobable y equilibrada.

---

# Fase 7 — Audio

- [ ] Elegir o desarrollar driver APU.
- [ ] Definir formato de secuencias musicales.
- [ ] Crear música original de menú.
- [ ] Crear música original de nivel.
- [ ] Crear música de jefe.
- [ ] Crear efectos de salto, ataque, daño y recompensa.
- [ ] Definir prioridades y asignación de canales.
- [ ] Medir coste de CPU.

**Aceptación:** audio estable, música y efectos coordinados y sin bloqueos.

---

# Fase 8 — Contenido completo

- [ ] Aprobar mapa de mundos y progresión.
- [ ] Definir cantidad y estructura de niveles.
- [ ] Diseñar rutas principales y opcionales.
- [ ] Crear sets gráficos por ambiente.
- [ ] Crear enemigos específicos por mundo.
- [ ] Crear jefes y recompensas.
- [ ] Crear secretos y coleccionables.
- [ ] Crear menús y pantallas de transición.
- [ ] Crear final y créditos originales.

**Aceptación:** todo el contenido previsto existe, se puede completar y está integrado en ROM.

---

# Fase 9 — Optimización y compatibilidad

- [ ] Auditar RAM y Zero Page.
- [ ] Auditar stack.
- [ ] Auditar PRG/CHR y bancos.
- [ ] Medir ciclos de rutinas críticas.
- [ ] Medir presupuesto de VBlank.
- [ ] Probar saturación de sprites.
- [ ] Probar carga máxima de entidades.
- [ ] Probar transiciones repetidas.
- [ ] Probar reinicio, pausa y muerte.
- [ ] Probar en Mesen.
- [ ] Probar en FCEUX.
- [ ] Probar en hardware real si está disponible.
- [ ] Documentar incompatibilidades conocidas.

**Aceptación:** informe de pruebas reproducible y sin defectos críticos conocidos.

---

# Fase 10 — Entrega

- [ ] Generar build release.
- [ ] Validar encabezado y mapper.
- [ ] Validar tamaño y checksum.
- [ ] Incluir instrucciones de ejecución.
- [ ] Incluir documentación técnica.
- [ ] Incluir créditos y licencias de assets/herramientas.
- [ ] Archivar fuentes y assets necesarios para reproducir la ROM.
- [ ] Etiquetar versión final.

**Aceptación:** entrega reproducible con ROM, fuentes, assets, herramientas/instrucciones y documentación.

---

## Hito obligatorio: primer nivel vertical

Antes de producir todos los mundos, completar un nivel corto que contenga:

- protagonista original provisional;
- controles;
- movimiento y salto;
- colisiones;
- escenario colorido;
- scrolling horizontal;
- al menos una habitación fija;
- transición entre ambos modos;
- un enemigo;
- un coleccionable;
- música o efecto original;
- meta/salida;
- ROM ejecutable y pruebas.

Este hito valida arquitectura, arte, físicas y pipeline. No sustituye el objetivo de crear el juego completo.

## Registro por tarea

Para cada tarea completada añadir:
- fecha;
- commit o referencia de cambio;
- archivos modificados;
- comando de build;
- resultado;
- emulador/hardware utilizado;
- pruebas ejecutadas;
- problemas pendientes.
