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
- [x] Proponer nombres originales para juego, protagonista y universo. *(tres rutas documentadas; elección pendiente de aprobación)*
- [x] Definir premisa narrativa breve. *(propuesta documentada; pendiente de aprobación)*
- [x] Definir fantasía central del jugador. *(propuesta documentada; pendiente de aprobación)*
- [x] Definir pilares de experiencia. *(cinco pilares propuestos; pendientes de aprobación)*
- [ ] Aprobar alcance inicial de mundos y mecánicas.

**Aceptación:** decisiones documentadas en `GAME_DESIGN_DOCUMENT.md`; no inventar aprobaciones.

**Estado (2026-11-11): En progreso.** `GAME_DESIGN_DOCUMENT.md` contiene las propuestas,
el alcance recomendado y una lista explícita de aprobaciones pendientes. F0.3 no se
considera cerrada hasta registrar la decisión del responsable del proyecto sobre
nombres, grafía `Pipapita`/`Tipapita`, premisa, pilares y alcance.

**Decisión registrada (2026-11-11):** título definitivo **Tipapita-Adventure**.
Continúan pendientes el nombre del universo, la grafía interna de la familia y la
aprobación de premisa, pilares y alcance.

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

### Pase de assets v2 (2026-11-11)

- Chiquito sustituye el placeholder 8×8 por un metasprite 16×16 de cuatro piezas
  con idle, dos cuadros de caminar y salto/caída.
- El metasprite usa cuatro sprites OAM por cuadro y como máximo dos por scanline;
  conserva el hitbox 8×8 existente para no alterar físicas ni colisiones.
- Chiquito mantiene la clase 16×16 de los protagonistas compactos de NES, pero
  ahora ocupa casi toda la caja lógica para mejorar silueta y lectura.
- La pradera usa `assets/tiles/montanas_v2.png`: 12 tiles con nubes 2×2,
  pasto, tierra, plataforma, puerta, checkpoint e interruptor redibujados.
- Fuentes, índices y comandos reproducibles: `assets/ASSET_MANIFEST.md`.
- Estado: **jugable y probado en emulador; pendiente de aprobación visual**, por
  lo que todavía no se declara arte final.

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

## F3.4 Máquina de estados [P1] — Implementada, compilada, probada en emulador (2026-11-10)
- [x] Idle. (`STATE_IDLE`: en el piso, sin velocidad horizontal)
- [x] Walk/run. (`STATE_WALK`: en el piso, con velocidad horizontal — un solo nivel de velocidad, no hay "run" distinto todavía)
- [x] Jump/fall/land. (`STATE_JUMP` subiendo, `STATE_FALL` cayendo; "land" es la transición instantánea de vuelta a IDLE/WALK al tocar el suelo, no un estado propio con animación)
- [x] Attack. (`STATE_ATTACK`: botón B, `ATTACK_DURATION` frames, enraíza el movimiento horizontal — sin arma/hitbox real todavía, eso es F5.3)
- [x] Hurt/knockback. (`STATE_HURT`: al tocar un peligro, `HURT_DURATION` frames de knockback real + parpadeo de invulnerabilidad, reemplaza el respawn instantáneo de F3.3)
- [x] Dead. (`STATE_DEAD`: al caer de la pantalla visible, `DEAD_DURATION` frames congelado, luego `respawn_player` reaparece en el punto de inicio)
- [x] Conectar estados con animaciones. (tabla de tiles por estado en `@animate`; IDLE/JUMP/FALL/HURT/DEAD reutilizan el tile idle, WALK alterna con el de caminar, ATTACK reutiliza el de caminar como diferenciador — sin arte dedicado todavía para salto/caída/ataque/daño/muerte)

**Aceptación:** transiciones deterministas y sin estados bloqueados.

**Registro de la tarea:**
- Archivos: `src/main.s` (constantes `STATE_*`/`*_DURATION`/`KNOCKBACK_*`/`DEATH_Y_THRESHOLD`, variables `player_state`/`state_timer`, `update_player` reestructurado con gating de input por estado, `respawn_player`, `recompute_normal_state`), `tools/build_scene.py` (hueco de prueba de 2 columnas para la condición de muerte por caída), `tools/test_state_machine.lua` (nuevo). Se actualizaron `tools/test_sprites.lua` y `tools/test_palette.lua`, que asumían cosas ya obsoletas (posición estática de Chiquito, animación por tiempo fijo, un punto de muestreo de "tierra"/"pradera" que en realidad caía en cielo desde F2.2) — ver "Limpieza de pruebas" abajo.
- Comando de build: `make clean && make rom`.
- Resultado de compilación: éxito, mismo header/tamaño de ROM.
- Prueba ejecutada: `fceux --loadlua tools/test_state_machine.lua dist/chiquito.nes`.
- Resultado observado (6 casos, todos `true`): aparece en `STATE_IDLE`; sostener Right pasa a `STATE_WALK`; saltar pasa por `STATE_JUMP` y `STATE_FALL` y aterriza de vuelta en IDLE/WALK; presionar B entra en `STATE_ATTACK` y de verdad enraíza el movimiento horizontal (sostener Right durante el ataque no mueve a Chiquito; sí lo mueve apenas termina); tocar el peligro entra en `STATE_HURT` con parpadeo visible (`oam_buffer+0=$FF` en algunos frames); caer en el hueco de prueba entra en `STATE_DEAD` y, tras expirar el temporizador, reaparece exactamente en `(96,152)` con `STATE_IDLE`. `RESULT=PASS`.
- **Bug real encontrado y corregido:** el chequeo de "recalcular estado normal" (al final de `update_player`) excluía `STATE_HURT`/`STATE_ATTACK` pero **olvidaba excluir `STATE_DEAD`** — `recompute_normal_state` sobrescribía el estado DEAD de vuelta a FALL/JUMP en el mismo frame en que se activaba, así que Chiquito nunca quedaba realmente congelado ni reaparecía (quedaba cayendo para siempre). Encontrado con una traza frame a frame automatizada (no a simple vista); corregido agregando la exclusión de `STATE_DEAD` al guard.
- **Ajuste de balance real:** el *knockback* inicial (`KNOCKBACK_VX=2.0px/frame`) no alcanzaba a sacar a Chiquito del ancho de un metatile de peligro (16px) antes de que `HURT_DURATION` expirara, así que sosteniendo Right sin soltar quedaba rebotando contra el mismo peligro indefinidamente (confirmado con prueba automatizada). Subido a `4.0px/frame`, suficiente para despejar el tile.
- **Limpieza de pruebas (regresión):** `tools/test_sprites.lua` asumía la posición estática de Chiquito de F2.3 (antes de F3.2) y una animación que alternaba sola por tiempo — corregido para leer la posición real de `player_x/y_hi` y simular caminar de verdad con `joypad.set`. `tools/test_palette.lua` muestreaba "pradera"/"tierra" en puntos que en realidad caían en cielo desde que F2.2 reemplazó las 3 bandas de color planas por la escena real — corregido para muestrear el suelo real y la pared de prueba de F3.3 (única superficie que usa la subpaleta de tierra). Las 7 pruebas automatizadas del proyecto (`test_palette`, `test_tiles`, `test_sprites`, `test_controller`, `test_movement`, `test_collision`, `test_state_machine`) pasan juntas tras estos ajustes.
- Limitaciones pendientes: sin arma/hitbox de ataque real (F5.3); sin sistema de vida real, el peligro/caída solo dan knockback/respawn (Fase 5/6); sin tiles de arte dedicados para salto/caída/ataque/daño/muerte (reutilizan idle/caminar). No probado en hardware real.

---

# Fase 4 — Cámara, mapas y escenarios

## F4.1 Sistema de mapas [P1] — Implementada, compilada, probada en emulador (2026-11-10)
- [x] Definir formato de mapa. (texto plano: leyenda `carácter=METATILE` + grilla de 16x15 caracteres; ver `assets/maps/pradera.txt`)
- [x] Definir metatiles y propiedades de colisión. (ya existían desde F2.2/F3.3 — `METATILES` en `tools/map2scene.py` —, ahora consumidos desde un mapa externo en vez de estar hardcodeados en Python)
- [x] Crear un mapa de prueba. (`assets/maps/pradera.txt`, migración exacta de la escena de F2.2-F3.4)
- [x] Crear herramienta de conversión. (`tools/map2scene.py`, reemplaza a `tools/build_scene.py`)
- [x] Documentar límites de tamaño y compresión. (ver docstring de `map2scene.py` y registro abajo)

**Aceptación:** mapa de fuente externa integrado correctamente en ROM.

**Registro de la tarea:**
- Archivos: `assets/maps/pradera.txt` (nuevo, asset fuente real), `tools/map2scene.py` (nuevo, reemplaza `tools/build_scene.py` que se elimina), `tools/test_map2scene.py` (nuevo), `Makefile` (regla actualizada para `map2scene.py` + el mapa de texto como dependencia).
- Comando de build: `make clean && make rom`.
- Resultado de compilación: éxito. **El ROM resultante es byte-por-byte idéntico al de antes de esta tarea** (mismo SHA-256) — confirma que migrar de escena-hardcodeada-en-Python a mapa-de-archivo-externo no cambió ningún comportamiento, solo la fuente de los datos.
- Prueba ejecutada: `python3 tools/test_map2scene.py` (prueba de la herramienta de conversión en sí, no de la ROM — es una herramienta de tiempo de build, igual que `png2chr.py`), más el barrido completo de las 7 pruebas de FCEUX existentes sobre la ROM ya migrada.
- Resultado observado: 15/15 verificaciones de `test_map2scene.py` (spawn y colisión del mapa real; un **mapa distinto** creado en la prueba, con otra disposición y otro punto de aparición, se convierte correctamente — confirma que el conversor es genérico y no solo "funciona con el mapa que ya teníamos"; 4 casos de error — columnas de menos, sin punto de aparición, dos puntos de aparición, carácter sin definir — fallan con un mensaje claro). Las 7 pruebas de FCEUX (`test_palette`, `test_tiles`, `test_sprites`, `test_controller`, `test_movement`, `test_collision`, `test_state_machine`) siguen pasando sobre la ROM migrada. `RESULT=PASS` en ambas.
- **Límites de tamaño y compresión (documentado):** un mapa = una pantalla completa de 16x15 metatiles = un nametable (32x30 tiles) = 1264 bytes de PRG-ROM sin comprimir (960 tiles + 64 atributos + 240 colisión). Con 128 KB de PRG-ROM, caben ~100 mapas de este tamaño sin necesitar comprimir nada. Si el contenido completo (Fase 8) se acerca a ese límite, RLE es la técnica estándar de NES para esto — no se implementa todavía porque no hace falta. Mapas más grandes que una pantalla (scroll, carga progresiva) son trabajo de F4.2/F4.3, no de este formato.
- Limitaciones pendientes: el formato de mapa sigue siendo "una pantalla = un nametable completo", sin soporte para mapas más grandes ni carga progresiva (F4.2/F4.3). Solo hay un mapa de prueba real (`pradera.txt`); el mapa alterno de la prueba es sintético, generado en memoria, no un asset del juego. No probado en hardware real.

## F4.2 Scrolling [P1]
- [x] Implementar coordenadas de mundo.
- [x] Implementar coordenadas de pantalla.
- [x] Implementar cámara horizontal.
- [x] Implementar límites de cámara.
- [x] Actualizar nametables por sectores.
- [x] Probar límites y wrap de scroll.

**Aceptación:** desplazamiento continuo sin corrupción gráfica.

**Registro de la tarea:**
- Archivos: `assets/maps/pradera.txt` (ampliado de 1 a 3 pantallas, 48x15 metatiles = 768x240px), `tools/map2scene.py` (reescrito para multi-pantalla: `compile_screen`/`compile_collision` separados, tabla de punteros `scene_pradera_screen_ptrs`, pantallas `scene_pradera_screen0/1/2` de 1024 bytes cada una, tabla de offsets por fila `scene_pradera_row_offset_lo/hi`, mapa de colisión del nivel completo `scene_pradera_collision` de 720 bytes), `tools/test_map2scene.py` (reescrito para el nuevo formato, 28 verificaciones), `src/main.s` (cambios de fondo, ver abajo), `tools/test_nmi.lua` y `tools/test_scrolling.lua` (nuevo) ajustados/creados para el nuevo layout de ZEROPAGE y el comportamiento real de scroll.
- Cambios de fondo en `src/main.s`:
  - Mirroring vertical real: bit del header iNES (`$41`) + registro propio de MMC3 en `$A000` (programado en `reset`) — necesario para que `$2000`/`$2400` sean VRAM física distinta y el scroll horizontal revele contenido nuevo en vez de repetir la misma pantalla.
  - Posición X de Chiquito pasa a ser de mundo y de 16 bits (`player_x_frac`/`player_x_px_lo`/`player_x_px_hi`, hasta `LEVEL_WIDTH_PX`=768), con suma de velocidad extendida de signo al tercer byte (`@apply_x`). Y sigue en 8 bits (sin scroll vertical).
  - `get_tile_collision` reescrito: ya no puede usar el truco de enmascarar bits (fila*16) de F3.3 porque `LEVEL_COLS`=48 no es potencia de 2 — usa la tabla de offsets por fila más un puntero indirecto de 16 bits hacia `scene_pradera_collision`. Nuevo helper `set_col_x` para armar el offset de 16 bits en cada esquina del hitbox consultada.
  - `update_camera_and_streaming` (nuevo proc, llamado desde el main loop tras `update_player`): recalcula `camera_x` entera cada frame (`clamp(player_x - 120, 0, 512)`, sin suavizado) y gestiona streaming de pantallas hacia el nametable físico que quedó fuera de vista, repartido en `STREAM_BUDGET`=16 bytes/frame vía `ppu_queue_push` (la cola de F1.3, sin uso real hasta ahora). Regla de asignación de slot fija: `pantalla AND 1` (pantalla par -> `$2000`, impar -> `$2400`).
  - `nmi` escribe PPUSCROLL (`camera_x_lo`) y el bit de nametable de PPUCTRL (`camera_x_hi AND 1`) cada frame, después de `ppu_queue_flush` (orden obligatorio: `$2005`/`$2006` comparten el mismo latch interno).
  - `reset` ahora carga 2 pantallas lógicas (0 y 1) a los 2 nametables físicos en vez de 1 pantalla a 1 nametable.
  - `@animate` escribe la X de OAM como `player_x_px_lo - camera_x_lo` (relativa a pantalla, no de mundo).
- **Bug real encontrado y corregido** (no estaba relacionado con el diseño de scroll en sí, pero se volvió visible al agregar variables persistentes nuevas): en `reset`, el bucle `@clearmem` asumía que X llegaba en 0 desde el bucle anterior de inicialización de MMC3 (`txa ; a = 0`), pero ese bucle deja X en 8 (corre de 0 a 8 exactamente). Esto hacía que `@clearmem` escribiera el valor 8 (no 0) en los offsets 8-255 de cada página de RAM, y nunca tocara los offsets 0-7. Era un bug **latente desde F1.3**, invisible hasta ahora porque toda variable afectada en offset>=8 o bien se reinicializaba explícitamente después (posición/velocidad del jugador) o se recalculaba cada frame desde cero (`pad1`). Las variables nuevas de cámara/streaming (offset 0x23-0x30) nunca se reinicializan explícitamente y cayeron todas en el rango roto, arrancando en 8 en vez de 0. Encontrado con `test_scrolling.lua` (streaming arrancaba con `stream_screen=8`, `stream_slot=8`, valores sin sentido) y confirmado leyendo bytes de RAM frame por frame en FCEUX. Corregido reemplazando `txa` por `lda #$00` + `ldx #$00` explícitos antes del bucle — ya no depende del valor que deje el código anterior.
- Comando de build: `make rom`.
- Resultado de compilación: éxito (`ca65`/`ld65`/`validate_rom.py` sin errores, ROM 262160 bytes, mapper 4, PRG 128KB, CHR 128KB).
- Pruebas ejecutadas: las 9 pruebas de FCEUX existentes (`test_boot`, `test_init`, `test_nmi`, `test_palette`, `test_tiles`, `test_sprites`, `test_controller`, `test_movement`, `test_collision`, `test_state_machine`) + la nueva `tools/test_scrolling.lua` + `tools/test_map2scene.py`.
- Resultados observados: `RESULT=PASS` en las 10 pruebas de FCEUX y en `test_map2scene.py` (28/28 verificaciones). `test_scrolling.lua` verifica, contra el mapa real de 3 pantallas: la cámara arranca en 0 y sigue a Chiquito caminando de verdad dentro de la pantalla 0 con la fórmula exacta; moverse dentro de las pantallas 0/1 (precargadas al arrancar) NO dispara streaming; teletransportarse bien adentro de la pantalla 2 SÍ dispara streaming real hacia el nametable que le toca (confirmado leyendo un byte de VRAM real con `ppu.readbyte`, no solo la bandera `nt_slot_screens`, completado en 66 frames, ~1024/16 esperado); y la colisión contra el peligro de la columna 40 (`col_x_hi=2`, más allá de los primeros 256px de mundo) sigue funcionando — ejercita el camino de 16 bits de `get_tile_collision` que F3.3 nunca probó.
- Bugs encontrados y corregidos durante la tarea (además del de `@clearmem` arriba): `map2scene.py` generaba `.addr X, .addr Y, .addr Z` (sintaxis ca65 inválida, directiva repetida) en vez de `.addr X, Y, Z` al emitir la tabla de punteros de pantalla; `tools/test_nmi.lua` asumía que `reset` terminaba en 5 frames reales (válido antes de F4.2) — ahora tarda ~7 frames porque copia 2 pantallas de nametable en vez de 1, así que el test se cambió para esperar la señal real (`frame_count > 0`) en vez de un número fijo de frames; `tools/test_sprites.lua` sampleaba el framebuffer con la X de mundo del jugador en vez de la X de pantalla (world X - camera_x) tras caminar — funcionaba antes de F4.2 porque mundo y pantalla coincidían siempre (cámara fija en 0 sin esta tarea).
- Limitaciones pendientes: solo hay scroll horizontal (no vertical — no hace falta todavía, el nivel de prueba no lo requiere). El streaming nunca transmite más de 1 pantalla a la vez (suficiente para este nivel de 3 pantallas, pero una ráfaga de velocidad muy alta combinada con un nivel con MUCHAS pantallas podría, en teoría, necesitar adelantarse más de 1 pantalla por delante de la cámara — no ejercitado, `MOVE_MAX_SPEED` actual tarda ~170 frames en cruzar una pantalla completa, de sobra frente a los 64 frames que tarda transmitir una). No probado en hardware real.

## F4.3 Pantallas y habitaciones [P1]
- [x] Definir formato de habitación.
- [x] Implementar carga de habitación fija.
- [x] Implementar puertas/salidas.
- [x] Implementar transición y spawn.
- [x] Definir persistencia de objetos y enemigos.

**Aceptación:** transición entre una zona de scrolling y una habitación fija sin pérdida de estado no deseada.

**Registro de la tarea:**
- Archivos: `assets/maps/casa_pipapita.txt` (nuevo, habitación fija de 1 pantalla), `assets/maps/pradera.txt` (agrega una puerta en pantalla 2, columna 46, fila 9), `tools/gen_test_tileset.py` (agrega un 6to tile de puerta), `assets/tiles/pradera.png` (regenerado, 6 tiles), `tools/map2scene.py` (metatile `DOOR`/`COLLISION_DOOR=4`, metatile `INDOOR` para el fondo de interiores, `--label` para que varios mapas coexistan sin colisionar símbolos), `Makefile` (regla para `dist/scene_casa.s`), `src/main.s` (room descriptors + `load_room`, ver abajo).
- **Formato de habitación (decidido):** una habitación es exactamente el mismo formato de mapa de F4.1/F4.2 (metatiles 16x16, leyenda + grilla), sin un formato nuevo. Lo único que distingue una "habitación fija" de una "zona de scroll" es su ANCHO: una habitación de 1 pantalla (16 columnas) tiene `room_max_camera=0` (ver abajo), así que la cámara queda matemáticamente clavada en `(0,0)` sin necesitar ninguna rama especial en `update_camera_and_streaming` -- el motor de cámara/streaming de F4.2 ya se degrada correctamente al caso "sin scroll" cuando el nivel es de 1 pantalla.
- **Multi-mapa en el mismo binario:** `map2scene.py` ahora requiere `--label <prefijo>` y usa ese prefijo para TODOS los símbolos generados (`{label}_screen_ptrs`, `{label}_collision`, `{label}_row_offset_lo/hi`, y las constantes `{LABEL}_SPAWN_X/Y`, `{LABEL}_LEVEL_SCREENS/COLS`) -- antes estaban fijos a `scene_pradera_*`, lo que impedía tener un segundo mapa en el mismo binario sin colisión de nombres.
- **Descriptor de habitación en tiempo de ejecución:** `room_descriptors` (RODATA, 1 registro de 14 bytes por habitación: puntero a colisión, puntero a tabla de offsets de fila (lo/hi), puntero a tabla de pantallas, cantidad de pantallas, cámara máxima ya calculada, spawn X/Y) + `load_room` (nuevo proc, `A`=ID de habitación): apaga el renderizado, recarga el/los nametable(s) físicos de una sola vez (no por la cola de VBlank de F1.3 -- un cambio de habitación es un corte discreto, un parpadeo de 1 frame es normal y esperado, igual que en cualquier juego de NES de la época), reposiciona a Chiquito en el spawn de la nueva habitación, reinicia cámara/streaming, y vuelve a encender el renderizado. `get_tile_collision`/`start_stream`/`update_camera_and_streaming` leen las variables de runtime que `load_room` carga (`room_collision_*`, `room_row_*_ptr`, `room_screen_ptrs`, `room_screens`, `room_max_camera_*`) en vez de los símbolos fijos `scene_pradera_*`/`LEVEL_SCREENS`/`MAX_CAMERA_X` de antes de esta tarea.
- **Puertas:** nuevo tipo de colisión `COLLISION_DOOR` (no bloquea el movimiento, igual que peligro). `update_player` revisa las 2 esquinas de abajo del hitbox (no las 4 -- las puertas de este milestone se piensan para entrar de frente, parado sobre el piso) y, si toca una, llama a `load_room`. **Limitación documentada:** con solo 2 habitaciones en este milestone, el destino de cualquier puerta es simplemente "la otra habitación" (`room_current EOR 1`) -- no hay todavía un mapa genérico de puertas->destinos ni soporte para más de una puerta por mapa con destinos distintos. El mapa de origen tampoco importa dónde se tocó la puerta: `load_room` siempre reaparece en el punto de aparición fijo (`S`) de la habitación destino, no en una posición asociada a la puerta específica.
- **`respawn_player` reutiliza `load_room`:** en vez de reposicionar a mano (como antes de F4.3), llama a `jsr load_room` con la habitación ACTUAL -- corrige un bug de diseño que habría existido si no se tocaba (antes de esta tarea, "respawn" siempre volvía a la pradera por una constante fija, lo que habría sido incorrecto si Chiquito muriera por caída dentro de una habitación distinta; la Casa Pipapita no tiene cómo caerse del mapa, pero el fix es correcto en general, no solo para este caso).
- **Persistencia de objetos y enemigos (DEFINIDA, no implementada todavía):** con el sistema de entidades real todavía sin empezar (Fase 5), no hay nada real que persistir hoy -- el enemigo/ítem de cada habitación son sprites de prueba fijos, sin lógica de "derrotado"/"recolectado". Mecanismo decidido para cuando exista ese sistema: un byte de banderas por habitación (`room_flags`, bits = "ítem N recolectado"/"enemigo N derrotado"), en RAM (no persiste entre apagados, solo entre transiciones dentro de la misma partida), indexado igual que `room_descriptors`. Documentado aquí como decisión de arquitectura; implementarlo real es tarea de Fase 5/6 cuando haya entidades reales que lean/escriban esas banderas.
- Comando de build: `make rom`.
- Resultado de compilación: éxito (`ca65`/`ld65`/`validate_rom.py` sin errores).
- **Bug real encontrado y corregido durante la tarea:** al agregar el 6to tile (la puerta) a `assets/tiles/pradera.png`, los índices `TILE_CHIQUITO_IDLE/WALK/ENEMY/ITEM` (hardcodeados como 5/6/7/8, asumiendo 5 tiles de fondo antes de los de sprite en el mismo CHR-ROM) quedaron desalineados un lugar -- los sprites se veían con colores/formas incorrectas (confirmado con `test_sprites.lua`, que pasaba igual porque solo compara contra el fondo, no contra un color esperado específico -- el bug solo se notó revisando los valores de color loggeados). Corregido actualizando los índices a 6/7/8/9.
- Pruebas ejecutadas: las 10 pruebas de FCEUX existentes + la nueva `tools/test_rooms.lua` + `tools/test_map2scene.py`.
- Resultados observados: `RESULT=PASS` en las 11 pruebas de FCEUX y en `test_map2scene.py`. `test_rooms.lua` verifica, contra el mapa real: Chiquito arranca en pradera (room=0); teletransportado sobre la puerta de pradera (columna 46, fila 9), pasa a la Casa Pipapita (room=1), reapareciendo en su spawn (208,152) con cámara en (0,0) y el nametable físico cambiado de verdad (tile fila0-col0 pasa de 0 a 3, leído con `ppu.readbyte`, no solo la bandera `room_current`); caminando de verdad dentro de la casa (60 frames izquierda + 90 derecha), la cámara nunca se mueve de (0,0); teletransportado sobre la puerta de la casa, vuelve a pradera (room=0) en su spawn (96,152) con el nametable de pradera de nuevo en VRAM; y tras las 2 transiciones, `frame_count` sigue avanzando y el mando sigue respondiendo (nada quedó roto/congelado).
- Limitaciones pendientes: solo 2 habitaciones, 1 puerta por mapa, destino de puerta hardcodeado como "la otra habitación" (ver arriba). La persistencia de objetos/enemigos está definida pero no implementada (no hay nada real que persistir todavía). El cambio de habitación causa un parpadeo de ~1 frame (renderizado apagado mientras se recarga VRAM) -- aceptable y esperado para esta técnica, no un bug. No probado en hardware real.

## F4.4 Elementos de escenario [P2]
- [x] Plataformas móviles.
- [x] Interruptores.
- [x] Puertas.
- [x] Obstáculos.
- [x] Zonas secretas.
- [x] Puntos de control.

**Aceptación:** cada elemento tiene comportamiento y pruebas documentadas.

**Registro de la tarea:**
- Alcance decidido con el usuario antes de implementar: UN ejemplo real por mecánica (no un sistema general de N plataformas/interruptores -- eso es trabajo de F5.1, el sistema de entidades), para no construir algo que Fase 5 tendría que rehacer.
- Archivos: `src/main.s` (toda la lógica nueva, ver abajo), `tools/map2scene.py` (metatiles `CHECKPOINT`/`SWITCH`/`LOCKED_DOOR`/`SECRET_WALL`, tipos de colisión 5/6/7), `tools/gen_test_tileset.py` (2 tiles nuevos: bandera de punto de control, panel de interruptor; 8 tiles en total), `assets/tiles/pradera.png` (regenerado), `assets/maps/pradera.txt` (agrega punto de control en pantalla 1 columna 20, y pared secreta en pantalla 2 columna 33), `assets/maps/casa_pipapita.txt` (rediseñada: interruptor + puerta bloqueada dividen la habitación), `tools/test_scenery.lua` (nuevo).
- **Plataforma móvil**: un solo ejemplo hardcodeado (`platform_x_lo/hi`/`platform_dir`, proc `update_platform`), vive solo en pradera (zona abierta sin nada más, x=280-340, y=80), reutiliza el tile de fondo `T_PLATFORM` como sprite (ver nota de `TILE_PLATFORM_SPRITE` -- funciona porque los 6 registros de banco CHR de MMC3 siguen apuntando todos al mismo banco físico, pattern table 0 y 1 muestran los mismos bytes). `update_player` tiene un chequeo de aterrizaje/arrastre con tolerancia de 4px (`PLATFORM_LANDING_TOLERANCE`, igual al entero de `MAX_FALL_SPEED`) en vez de exigir que el pie caiga en el píxel EXACTO de la plataforma -- a velocidad de caída máxima, un chequeo de igualdad estricta deja pasar al jugador de largo un frame de cada varios.
- **Interruptor + puerta bloqueada**: un solo par hardcodeado (`switch_casa_open`), viven en la Casa Pipapita, que se rediseñó para que la puerta bloqueada (columna 10) sea el ÚNICO camino hacia la puerta de salida (columna 15) -- sin activar el interruptor (columna 6) no se puede salir. `COLLISION_LOCKED_DOOR` no es un valor de colisión fijo: `get_tile_collision` lo traduce a SOLID o EMPTY según `switch_casa_open` en tiempo de ejecución, porque el mapa de colisión en ROM no puede cambiar. Activar el interruptor también transmite un cambio visual real a VRAM (4 `ppu_queue_push`, el interruptor pasa a verse "presionado") -- no es solo una bandera invisible.
- **Punto de control**: `COLLISION_CHECKPOINT`, un solo "slot" de checkpoint (no una tabla por habitación). Tocarlo guarda posición + ID de habitación (`checkpoint_active/room/x_lo/x_hi/y`); `load_room` lo usa en vez del punto de aparición por defecto de la habitación cuando `checkpoint_room` coincide con la que se está cargando. Esto también corrige un caso que `respawn_player` (generalizado en F4.3 a `load_room(room_current)`) no cubría: morir y reaparecer ahora puede ser en un punto distinto al spawn fijo del mapa.
- **Zona secreta**: `SECRET_WALL`, mismos tiles/paleta que `WALL` (visualmente idéntica) pero colisión vacía -- ningún código nuevo en `main.s`, es puramente una combinación de metatile en el mapa.
- **Obstáculos**: decidido que ya están cubiertos por los tipos de colisión existentes (pared sólida, peligro, plataforma de un sentido) -- no se agregó un tipo de colisión nuevo porque no hay todavía una habilidad del jugador (romper, empujar) que justifique un obstáculo con comportamiento distinto a esos tres.
- Comando de build: `make rom`.
- Resultado de compilación: éxito, con 2 errores reales encontrados y corregidos en el camino (ver abajo).
- **Bugs reales encontrados y corregidos durante la tarea:**
  - Dos "Range error" de ensamblado (`ca65`): el bloque de chequeo de la plataforma móvil en `update_player` quedó demasiado largo para que un branch relativo (`bne`/`bmi`) alcanzara su destino (`@platform_done`, límite de ±127 bytes en 6502). Corregido con el patrón estándar "branch corto + `jmp`" (invertir la condición, branch corto a una etiqueta cercana que hace `jmp` sin límite de rango).
  - Al agregar 2 tiles nuevos (checkpoint, interruptor) al tileset de fondo (ahora 8), los índices `TILE_CHIQUITO_IDLE/WALK/ENEMY/ITEM` quedaron desalineados otra vez (mismo patrón de bug que F4.3) -- corregido actualizándolos de 6/7/8/9 a 8/9/10/11 ANTES de compilar, ya no después de notar sprites con el tile equivocado.
  - `tools/test_scenery.lua` (de la prueba, no del motor): el primer intento de probar "aterrizar en la plataforma" dejaba que la plataforma siguiera moviéndose sola mientras Chiquito caía, así que para cuando llegaba a la altura de aterrizaje la plataforma ya se había alejado lo suficiente para que el solape horizontal no se diera -- corregido fijando la posición de la plataforma durante esa ventana de la prueba (ya se había confirmado el movimiento real por separado). El primer intento de probar "morir y reaparecer en el checkpoint" teletransportaba a Chiquito a una Y mayor al umbral de muerte pero en una columna con suelo sólido ahí mismo, así que la colisión vertical lo empujaba de vuelta a una Y menor al umbral ANTES de que corriera el chequeo de muerte -- corregido usando el hueco real del mapa (columnas 13-14) para una caída libre genuina, igual que ya hacía `test_state_machine.lua`.
- Pruebas ejecutadas: las 11 pruebas de FCEUX existentes + la nueva `tools/test_scenery.lua` + `tools/test_map2scene.py`.
- Resultados observados: `RESULT=PASS` en las 12 pruebas de FCEUX y en `test_map2scene.py`. `test_scenery.lua` verifica, contra el mapa/ROM real: la plataforma se mueve sola dentro de sus límites, Chiquito puede aterrizar en ella sin atravesarla y lo arrastra mientras está arriba; la puerta bloqueada de la casa detiene el paso antes de activar el interruptor, activarlo cambia su tile real en VRAM (leído con `ppu.readbyte`, no solo la bandera) y después sí se puede cruzar; tocar el punto de control y luego morir por caída (en el hueco real) reaparece en la posición del checkpoint, no en el spawn original de pradera; y la pared secreta se atraviesa de verdad caminando (no se asume por el tipo de colisión, se confirma que Chiquito termina del otro lado).
- Limitaciones pendientes: cada mecánica tiene un solo ejemplo hardcodeado, no un sistema general (N plataformas, N interruptores con N puertas, checkpoints por habitación) -- eso es trabajo de F5.1 (sistema de entidades) cuando haga falta escalar. El checkpoint es un solo slot global, no una tabla por habitación (alcanza para esta demo de 2 habitaciones). No probado en hardware real.

---

# Fase 5 — Enemigos y combate

## F5.1 Sistema de entidades [P1]
- [x] Definir estructura compacta de entidad.
- [x] Definir número máximo simultáneo.
- [x] Implementar creación y destrucción.
- [x] Implementar actualización por prioridad o zona.

**Aceptación:** entidades no corrompen memoria ni exceden límites definidos.

**Registro de la tarea:**
- Archivos: `src/main.s` (toda la lógica nueva, ver abajo), `tools/test_entities.lua` (nuevo), `tools/test_sprites.lua` (ajustado, ver bug real abajo).
- **Estructura de entidad (decidido):** estructura-de-arrays (SoA), no array-de-estructuras -- 8 tablas paralelas (`entity_active/room/type/x_lo/x_hi/y/tile/attr`) indexadas por el mismo slot, en vez de un registro de N bytes por entidad. Es el patrón natural en 6502: direccionamiento `tabla,x` por campo es directo; calcular `base + slot*N` para acceder a un campo dentro de un registro compacto no lo es tanto. Las tablas viven en BSS (RAM $0300+), no en zeropage -- no necesitan direccionamiento indirecto, así que no hace falta gastar zeropage (cada vez más escaso) en ellas.
- **MAX_ENTITIES = 8 (decidido):** coincide exactamente con el límite real de 8 sprites por scanline del hardware NES. Con entidades de 1 sprite cada una, nunca puede saturarse una sola línea por tener demasiadas activas -- el límite de la estructura de datos y el límite físico del hardware son el mismo número a propósito.
- **Creación/destrucción:** `spawn_entity` (argumentos en escratch de ZEROPAGE, mismo patrón que `ppu_queue_push`) busca el primer slot libre; si las 8 ya están ocupadas, no hace nada y vuelve -- nunca escribe fuera de la tabla, nunca pisa una entidad existente. `destroy_entities_in_room(room)` desactiva las entidades activas de esa habitación específica; las de otras habitaciones no se tocan.
- **Actualización por zona (decidido):** una entidad solo se dibuja/actualiza cuando `entity_room == room_current` (si no, su sprite de OAM se oculta con Y=$FF) -- la misma técnica que ya usaba la plataforma móvil de F4.4 para no existir fuera de pradera. No hay "prioridad" explícita todavía (no hace falta con 8 entidades como máximo); queda como posible extensión si Fase 6+ necesita ordenar actualización por distancia a la cámara.
- **Migración de los placeholders de F2.3:** el "enemigo" y "coleccionable" de prueba (sprites estáticos escritos una sola vez en `oam_init_data`, sin comportamiento real desde que se crearon) ahora son 2 entidades reales, generadas por `load_room` cada vez que se entra a pradera (con `destroy_entities_in_room` primero, para no duplicar en cada visita). Mismo tile/posición/paleta que siempre tuvieron -- F5.1 es la infraestructura, no la IA (eso es F5.2); `entity_type` (`ENTITY_TYPE_ENEMY`/`ITEM`) es el gancho para cuando F5.2 le dé comportamiento real a cada tipo.
- **Reorganización de OAM:** sprite 0 = Chiquito (sin cambios); sprites 1-8 (offsets 4-35) = entidades; sprites 9-10 (offsets 36-43) = plataforma móvil (se corrió desde el offset 12 de F4.4 para hacerle lugar a las entidades). `update_platform` ahora escribe también tile/atributo cada frame (antes dependía de `oam_init_data`) para no depender de ninguna entrada estática.
- Comando de build: `make rom`.
- Resultado de compilación: éxito, sin errores.
- **Bug real encontrado y corregido (no en el motor, en la prueba):** `test_sprites.lua` sampleaba el framebuffer para el enemigo/ítem en posiciones de pantalla FIJAS (184,184)/(144,104), asumiendo que esos sprites nunca se movían con la cámara -- cierto mientras fueron estáticos (F2.3-F4.4, nunca ningún código los tocaba después del boot), pero ya NO es cierto con F5.1: ahora son entidades reales, relativas a cámara igual que Chiquito, así que su posición de pantalla cambia al caminar (correcto -- existen en una posición de MUNDO fija, como corresponde). La prueba fallaba con colores de fondo en vez de los del sprite. Corregido restando `camera_x_lo` a sus posiciones de mundo conocidas (180,179)/(140,99), igual que ya hacía la prueba para Chiquito desde F4.2. Esto además revela que la inconsistencia (entidades estáticas no relativas a cámara) existía silenciosamente desde F4.2 y nadie la había notado -- la prueba nunca caminaba lo suficiente para que la diferencia importara visualmente.
- Pruebas ejecutadas: las 12 pruebas de FCEUX existentes (con el ajuste de `test_sprites.lua`) + la nueva `tools/test_entities.lua` + `tools/test_map2scene.py`.
- Resultados observados: `RESULT=PASS` en las 13 pruebas de FCEUX y en `test_map2scene.py`. `test_entities.lua` verifica, contra el motor real: pradera genera exactamente 2 entidades con los campos correctos (habitación/tipo/posición/tile); al cambiar de habitación siguen activas en la tabla pero su OAM se oculta (confirmado leyendo el byte de OAM real, no solo la bandera); al volver a pradera no se duplican (sigue habiendo exactamente 2, no 4); y con la tabla llena de 8 centinelas de una habitación que no existe (para que ninguna transición real los toque), un intento de generar una entidad nueva falla sin tocar ninguno de los 8 centinelas -- ni desborde ni corrupción.
- Limitaciones pendientes: sin comportamiento real todavía (patrulla, persecución, daño -- eso es F5.2); sin prioridad explícita de actualización, solo filtro por zona (alcanza con 8 entidades); solo pradera genera entidades por ahora (la Casa Pipapita no tiene ninguna). No probado en hardware real.

## F5.1b Elenco de personajes (NPC) [fuera de secuencia, a pedido del usuario]
- [x] Separar CHR-ROM de fondo y sprites (antes compartían banco físico 0, límite de 64 tiles combinados).
- [x] Pixel art 32x32 (4 poses) para Sanchopau, Mothman, Abuelito, Diablito, Marcianito.
- [x] Paleta de sprite por habitación (los 4 slots del hardware no alcanzan para Chiquito + un elenco con paletas propias).
- [x] Sistema de "actor" animado de 16 tiles (distinto del sistema de entidades de 1 tile de F5.1) y cableado de Sanchopau como NPC real en la Casa Pipapita.

**Nota:** esta sub-fase no estaba en el plan original -- se adelantó a pedido explícito del usuario en la misma conversación donde se compartieron las referencias de arte. No reemplaza F5.2 (comportamiento de enemigos); es infraestructura de personajes NO jugables/de historia.

**Registro de la tarea:**
- Archivos: `src/main.s` (reparto de CHR-ROM, `TILE_SANCHOPAU_*`, `update_npc`/`draw_npc_metasprite`, paleta por habitación en `load_room`), `src/data/palettes.s` (`sanchopau_sprite_overlay`), `tools/gen_cast_sprites.py` (nuevo), `tools/test_npc.lua` (nuevo), `tools/test_entities.lua` (ajustado, ver abajo), `Makefile` (`tiles_cast.s`), `assets/sprites/{sanchopau,mothman,abuelito,diablito,marcianito}_v1.png` + `cast_v1.png`/`_preview.png`.
- **CHR-ROM (decidido):** R0/R1 (bancos 2KB) fijan el fondo en los primeros 4KB físicos; R2-R5 (bancos 1KB) fijan los sprites en los siguientes 4KB (`.align $1000` antes de `tiles_sprites.s`) -- cada pattern table de la PPU (256 tiles) deja de compartir bytes con la otra. Antes de esto los índices de sprite llevaban un `+12` artificial para no pisar los tiles de fondo; ya no hace falta (`TILE_CHIQUITO_IDLE` pasó de 12 a 0).
- **Tamaño del elenco (decidido con el usuario, con idas y vueltas reales):** se evaluaron 16x16 (4 tiles, el formato de Chiquito), 24x24 (9 tiles) y 32x32 (16 tiles, el de `nes_referencias/`) -- el usuario eligió 32x32 priorizando detalle de pixel art explícitamente sobre el costo de sprites por scanline. El límite de **4 subpaletas de sprite en todo el hardware** (no 4 por personaje) no cambia con el tamaño -- se resolvió reutilizando los slots 1/2 (enemigo/ítem, solo usados en pradera) por habitación, no dándole paletas propias al elenco.
- **Pixel art:** cabeza nueva por personaje (16 filas x32 columnas, simétrica vía `_mirror`), cuerpo/piernas = escalado 2x del rig de Chiquito (`gen_chiquito_sprites.py`, ya probado) + una pasada de textura (`_BODY_TEXTURE`) para no dejarlo como un escalado sin más detalle. Dos iteraciones visuales reales sobre Abuelito y Diablito (sus primeras cabezas no se leían como "sombrero de ala ancha" ni "cuernos") hasta que `cast_v1_preview.png` las mostró reconocibles.
- **Presupuesto de pattern table (real, no solo teórico):** 5 personajes x 4 poses x16 tiles = 320 tiles no caben junto a los 19 que ya usan Chiquito/enemigo/ítem/plataforma (límite de 256 tiles de la pattern table de sprites, no de espacio en el cartucho). Por eso cada personaje también se guarda en su propio PNG (`<nombre>_v1.png`); solo `sanchopau_v1.png` está incluido en el build hoy. El resto queda listo para integrarse cuando exista su habitación.
- **Sistema de actor (nuevo, distinto de `entity_*` de F5.1):** Sanchopau usa su propio bloque de OAM (`NPC_OAM_BASE`, 16 sprites) y su propio dibujo (`draw_npc_metasprite`, con bucle fila/columna en vez de desenrollado como Chiquito -- 16 piezas hacían el código desenrollado demasiado largo). Patrulla simple entre `NPC_MIN_X`/`NPC_MAX_X` en `ROOM_CASA`; oculto (Y=$FF en sus 16 sprites) y la paleta de los slots 1/2 restaurada fuera de esa habitación.
- Comando de build: `make rom` (WSL Ubuntu, toolchain de F0.1).
- Resultado de compilación: éxito. `ld65`/`ca65` emiten una advertencia ("Combined alignment is suspiciously large (4096)") por el `.align $1000` -- revisada contra el `.map` real (`CHARS Offs=000000 Size=001130`, confirma que `tiles_sprites` empieza exactamente en el byte 4096 del segmento); no es un error, es ld65 siendo conservador con alineaciones grandes.
- **Bugs reales encontrados y corregidos durante la tarea:**
  - `update_npc` solo escribía `$FF` en 4 de los 16 sprites al ocultar a Sanchopau fuera de Casa (las 3 filas restantes de la grilla 4x4 quedaban con su última posición visible) -- encontrado con `tools/test_npc.lua` (`oculto_fuera_de_casa` fallaba tras la primera visita a Casa), corregido con un bucle que cubre los 16 offsets.
  - `tools/test_entities.lua` tenía hardcodeado `TILE_ENEMY, TILE_ITEM = 28, 29` (los índices viejos, con el `+12` compartido) -- corregido a `16, 17` tras el reparto de CHR-ROM.
- Pruebas ejecutadas: las 13 pruebas de FCEUX existentes + la nueva `tools/test_npc.lua` + `tools/test_map2scene.py`.
- Resultados observados: `RESULT=PASS` en las 14 pruebas de FCEUX y en `test_map2scene.py`. `test_npc.lua` verifica contra la ROM real: Sanchopau oculto en pradera con la paleta de enemigo/ítem intacta; al entrar a Casa, visible con la paleta de Sanchopau en los slots 1/2; patrulla real (muestreada cada 40 frames, con cambio de X confirmado); al volver a pradera, oculto de nuevo y paleta restaurada. Revisión visual real en FCEUX (captura tomada con el emulador corriendo, no justo antes de `emu.exit()` -- ver nota en el propio test sobre una captura tardía que salía en negro en este entorno xvfb+GL, aparentemente un problema del mecanismo de captura al cerrar, no del juego) confirma a Sanchopau dibujado correctamente junto a Chiquito en la Casa Pipapita.
- Limitaciones pendientes: solo Sanchopau está integrado; Mothman/Abuelito/Diablito/Marcianito tienen su CHR generado pero no están mapeados ni colocados en ninguna habitación (no existen todavía esas habitaciones -- taller/montañas/cuevas/regiones extraterrestres). El patrullaje de Sanchopau puede desbordar 1px el rango declarado antes de girar (decrementa/incrementa y recién después compara contra el límite); cosmético, no corrompe memoria ni rompe la cámara. Sin diálogo ni interacción real con el jugador todavía (es un actor decorativo). No probado en hardware real.

**Corrección real, mismo día (2026-11-12):** el usuario vio esta primera versión corriendo en FCEUX y la calidad del redibujo a mano no era aceptable comparada con `assets/sprites/nes_referencias/sanchopau.png` (conversión automática real desde el concept art). Se reemplazó:
- Fuente de CHR: de `assets/sprites/sanchopau_v1.png` (mi dibujo a mano) a `assets/sprites/nes_referencias/sanchopau.chr` (conversión fiel ya existente), vía `tools/chr2asm.py` (nuevo -- envuelve un `.chr` binario crudo en `.s`, sin pasar por PNG ni remapear color).
- Paleta: de valores inventados a los reales de `sanchopau.json` (`palettes_nes`), con las 2 subpaletas de gris/blanco casi idénticas fusionadas en una sola y el parche naranja (1 solo tile) como la segunda. Esto requirió cambiar `draw_npc_metasprite` de "paleta por mitad" (como Chiquito) a "paleta por tile" (`sanchopau_tile_palette`, 16 bytes, copiados directo del campo `palette` del JSON), porque el tile del parche no cae ordenadamente en la mitad superior o inferior.
- Consecuencia aceptada con el usuario: como esa fuente solo tiene una pose, Sanchopau perdió la animación de caminar/salto que sí tenía el rediseño a mano -- se desliza con una sola pose fija. Recuperar la animación necesita más poses de referencia (como las que se compartieron para Chiquito), no redibujarlas a mano.
- `tools/gen_cast_sprites.py` se deja en el repo (no se usa en el build real) -- documenta el intento y por qué se descartó, por si sirve de referencia para decidir el redibujo manual de otro personaje en el futuro.
- Reverificado: `make test` (14 pruebas FCEUX + `test_map2scene.py`) en verde con los nuevos valores de paleta; `tools/test_npc.lua` actualizado con los bytes reales. Revisión visual real en FCEUX confirma la fidelidad a `nes_referencias/sanchopau.png`.

## F5.1c Chiquito con sus 5 poses reales [fuera de secuencia, a pedido del usuario]
- [x] Consolidar las 5 poses reales (idle/caminar_1/caminar_2/correr/saltar, conversión fiel del concept art) en CHR + tablas de tile/paleta por celda.
- [x] Reorganizar el bloque de OAM de Chiquito (4 piezas desenrolladas -> 16 en bucle, mismo patrón que Sanchopau).
- [x] Reescribir `draw_player_metasprite` con paleta por tile y huecos (no todas las poses llenan las 16 celdas).
- [x] Repartir WALK en caminar/correr según la velocidad horizontal real.
- [x] Fusionar las paletas reales de Chiquito (0+3 del JSON -> pelaje, 1 -> sombrero) y reemplazar los valores inventados en `palette_table`.

**Registro de la tarea:**
- Archivos: `src/main.s` (reparto de OAM, `draw_player_metasprite`, `@animate`, `oam_init_data`, paleta), `src/data/palettes.s` (slots 0/3 reales), `tools/gen_chiquito_poses.py` (nuevo), `tools/gen_scenery_sprites.py` (nuevo), `tools/chr2asm.py` (reusado), `Makefile` (`tiles_chiquito.s`+`chiquito_pose_tables.s`+`tiles_scenery.s`), `tools/test_sprites.lua`/`test_entities.lua`/`test_npc.lua` (direcciones y tiles actualizados), `assets/sprites/nes_referencias/chiquito*.chr/.json` (las 5 poses, provistas por el usuario).
- **Por qué (contexto):** después de corregir Sanchopau (ver arriba), el usuario compartió 5 archivos `.chr`+`.json` reales para Chiquito (idle, caminar_1, caminar_2, correr, saltar) y pidió integrarlos. A diferencia de Sanchopau, aquí SÍ hay poses de movimiento reales -- la oportunidad de reemplazar el `chiquito_v2.png` dibujado a mano (F2.3) por la misma conversión fiel que ya funcionó para el elenco.
- **Decisión de producto confirmada con el usuario:** `chiquito_correr.chr` no tenía dónde encajar en la máquina de estados existente (solo IDLE/WALK/JUMP/FALL/ATTACK/HURT/DEAD, sin "correr"). Se preguntó explícitamente y el usuario eligió activarlo por velocidad real (no un botón nuevo): `RUN_SPEED_THRESHOLD` en `@animate` compara `player_vx_hi` sin signo contra 1 -- cualquier byte alto distinto de cero (sea +N o el complemento a dos de un negativo) sale `>=1` en una comparación sin signo, así que un solo `CMP`/`BCS` detecta "velocidad horizontal real distinta de cero" sin calcular el valor absoluto con signo aparte.
- **Formato de datos (nuevo, no existía para Chiquito):** cada pose tiene un número de tiles DISTINTO (14 a 16 de 16 posibles -- las referencias no siempre llenan la grilla 4x4) y una paleta por tile, no por mitad. `tools/gen_chiquito_poses.py` concatena los 5 `.chr` y genera, por pose, dos tablas de 16 bytes (`chiquito_<pose>_tile`: índice absoluto o `$FF` si la celda no tiene pieza real; `chiquito_<pose>_pal`: 0/1) leídas directamente del JSON -- verificado con `assert` que las 5 poses declaran las mismas 4 `palettes_nes` y usan solo los índices {0,1,3} antes de fusionar (0+3 -> pelaje, 1 -> sombrero), no asumido a ciegas.
- **Reparto de OAM:** Chiquito pasó de "sprite 0 + 3 extra" (resabio de cuando eran 4 piezas) a un bloque propio de 16 sprites (`PLAYER_OAM_BASE`), igual patrón que ya usa Sanchopau desde F5.1b. `draw_player_metasprite` ahora usa punteros indirectos en zero page (`chiquito_tile_ptr`/`chiquito_pal_ptr`, indexados por pose vía una tabla de 5 punteros) en vez de un tile base único -- es la única forma del 6502 de leer una tabla cuya dirección se decide en tiempo de ejecución.
- Comando de build: `make rom` (WSL Ubuntu).
- Resultado de compilación: éxito tras 2 iteraciones de errores reales de ensamblado (ver abajo).
- **Bugs reales encontrados y corregidos durante la tarea:**
  - `ca65`: "Range error (-133 not in [-128..127])" en el `bne` de cierre del bucle de filas de `draw_player_metasprite` -- el cuerpo del bucle (con el manejo extra de "sin tile real" que no tiene `draw_npc_metasprite`) quedó más largo que el rango de un branch relativo. Corregido con el patrón ya usado en `update_player`: branch corto invertido + `jmp` sin límite de rango.
  - Insertar `chiquito_tile_ptr`/`chiquito_pal_ptr` en medio del segmento `ZEROPAGE` corrió 4 bytes TODAS las variables declaradas después (posición/velocidad del jugador, etc.), rompiendo las direcciones absolutas hardcodeadas en varios `tools/test_*.lua` -- síntoma: `tile_idle=255`, sampleos de píxel en coordenadas sin sentido (ver `chiquito(113,185)` muestreando el piso en vez del sprite). Corregido moviendo ambas variables al FINAL del segmento en vez de insertarlas donde "lógicamente" correspondían -- regla general ahora documentada ahí mismo para no repetir el error.
  - `tools/test_sprites.lua` tenía hardcodeado el offset OAM viejo de Chiquito (`oam_buffer+1` = sprite 0) y coordenadas de muestreo de píxel calibradas para el metasprite 16x16 -- corregido al nuevo `PLAYER_OAM_BASE` y recalibrado contra capturas reales de FCEUX (no a ciegas) para el nuevo tamaño 32x32.
  - `tools/test_entities.lua`/`test_npc.lua` tenían hardcodeados `TILE_ENEMY`/`TILE_ITEM` (16,17) y `NPC_OAM` (`$0238`) del reparto anterior -- corregidos a los nuevos valores (75,76 y `$026C`) tras correr a Chiquito con 75 tiles en vez de 16.
- Pruebas ejecutadas: las 14 pruebas de FCEUX existentes (con los 3 tests corregidos arriba) + `tools/test_map2scene.py`.
- Resultados observados: `RESULT=PASS` en las 14 pruebas de FCEUX y en `test_map2scene.py`. Revisión visual real en FCEUX (capturas tomadas con el emulador corriendo) confirma las 5 poses reales, el reflejo al mirar a la izquierda, y el salto completo (arco en el aire, patas hacia atrás) -- todo contra la ROM compilada, no simulado.
- Limitaciones pendientes: los otros 3 tiles de escenario (enemigo/ítem/plataforma) siguen siendo pixel art a mano sin referencia real (`tools/gen_scenery_sprites.py`), no tocados en esta tarea. El patrullaje/animación del resto del elenco (Mothman/Abuelito/Diablito/Marcianito) sigue pendiente de habitación propia. No probado en hardware real.

## F5.2 Enemigos básicos [P1] — Implementada, compilada, probada en emulador (2026-11-12)
- [x] Enemigo patrullero.
- [x] Enemigo perseguidor o saltador.
- [x] Enemigo de ataque a distancia.
- [x] Daño y colisiones.
- [x] Desaparición/reaparición según reglas.

**Aceptación:** comportamientos distintos y reproducibles.

**Registro de la tarea:**
- Archivos: `src/main.s` (constantes `ENEMY_*`/`PROJECTILE_*`, `ENTITY_TYPE_PROJECTILE`, campos `entity_behavior`/`entity_dir`/`entity_timer` en BSS, `entity_arg_behavior`/`dir`/`timer` + escratch `enemy_dx_lo`/`hi`/`enemy_hop_tmp`/`enemy_save_x` en ZEROPAGE -- todos al final de sus segmentos, mismo criterio que `chiquito_tile_ptr`, para no correr las direcciones que ya tienen hardcodeadas varios `tools/test_*.lua`; `spawn_entity` extendido; 3 spawns nuevos/ajustados en `load_room`; `compute_entity_dx`, `enter_hurt_state` -factorizado de `update_player`-, `check_enemy_contact`, `update_enemies`, `enemy_patrol_step`, `enemy_chaser_step`, `enemy_ranged_step`, `projectile_step`; tabla `enemy_hop_offset`; 2 líneas nuevas en `mainloop`), `tools/test_entities.lua` (conteo/Y ajustados), `tools/test_state_machine.lua` (aísla la prueba de muerte de los enemigos nuevos), `tools/test_enemies.lua` (nuevo), `Makefile` (`enemies` agregado a `FCEUX_TESTS`).
- **Diseño (reusa F5.1, no un sistema aparte):** los 3 comportamientos son sub-tipos de `entity_type=ENEMY` (`entity_behavior`: patrullero/perseguidor/atacante), y el proyectil del atacante a distancia es simplemente una ENTIDAD más (`ENTITY_TYPE_PROJECTILE`) -- reusa el límite de 8, el spawn/destroy por zona y el dibujado genérico de `update_entities` ya existentes, sin una tabla ni un límite aparte. `update_enemies` (nuevo, corre ANTES de `update_entities` en el main loop) es la única rutina que mueve/anima: `update_entities` sigue siendo puramente "dibuja lo que hay en la tabla".
- **3 ejemplos hardcodeados, no un editor genérico de enemigos** -- mismo criterio que `PLATFORM_MIN_X/MAX_X` o `NPC_MIN_X/MAX_X`: patrullero (pantalla 0, rebota 160-200px), perseguidor/saltador y atacante a distancia (pantalla 1, piso corrido sin huecos ni peligros). Todos reusan `TILE_ENEMY` (el mismo placeholder geométrico de F2.3) -- **sin arte real distinto por comportamiento todavía**, ver limitaciones.
- **Perseguidor/saltador:** persigue a Chiquito en X de verdad (1px/frame hacia la posición real del jugador, no un rango fijo) y se detiene a `ENEMY_CHASER_STOP_DISTANCE` (12px) de distancia; agrega un salto VISUAL (offset de Y leído de `enemy_hop_offset`, una tabla de 16 bytes) en vez de deslizarse, para que sea un comportamiento realmente distinto del patrullero -- no hay gravedad/colisión de entidad real por detrás del salto.
- **Atacante a distancia:** dispara un proyectil horizontal (`ENTITY_TYPE_PROJECTILE`) hacia el lado donde esté Chiquito en el instante del disparo (no vuelve a apuntar después) cada 90 frames; el proyectil viaja a 2px/frame y se desactiva solo a los 60 frames (no por salir de pantalla) -- la regla de aparición/desaparición pedida explícitamente por esta fase. El atacante dispara otro al terminar su cooldown; no es el MISMO proyectil reapareciendo, pero cumple la regla igual que hace `destroy_entities_in_room`/`spawn_entity` con las entidades por habitación desde F5.1.
- **Daño y colisiones (un solo sentido):** `check_enemy_contact` (nuevo, corre después de `update_enemies`) hace un AABB simple de 8x8 entre Chiquito y cada enemigo/proyectil activo de la habitación actual; al primer contacte, entra en HURT con el mismo knockback que un peligro de tile -- se factorizó ese bloque de `update_player` a `enter_hurt_state` para no duplicarlo. El jugador NO puede dañar a los enemigos todavía (no hay arma real, eso es F5.3) -- un proyectil sí se consume (se desactiva) al pegarle a Chiquito.
- **Bug real encontrado y corregido (geometría, no solo código):** el enemigo/ítem de prueba de F2.3 usaba Y=179 como posición puramente decorativa (sin colisión real contra nada hasta ahora); al darle contacto real con el jugador en esta fase, 179 resultó estar 27px más abajo de donde el jugador puede pararse de pie en esta misma fila de piso (152 = 160 del tope del suelo - 8 del hitbox, igual que `SCENE_PRADERA_SPAWN_Y`) -- un enemigo "parado en el piso" nunca llegaba a tocarse con el jugador en juego normal. Corregido a 152 en los 3 enemigos nuevos/existente (el ítem, sin colisión, se deja en 99 sin cambios). Encontrado con `tools/test_enemies.lua` (el contacto solo se disparaba transportando al jugador DENTRO del piso sólido, nunca caminando).
- **Bug real encontrado y corregido (umbral compartido):** el perseguidor originalmente dejaba de acercarse a la misma distancia (`ENTITY_HITBOX_W`=8) que usa `check_enemy_contact` para considerar "contacto" -- quedaba parado justo en el borde del hitbox del jugador, y en cuanto terminaba la invulnerabilidad de HURT el contacto se disparaba de nuevo de inmediato. Corregido con `ENEMY_CHASER_STOP_DISTANCE`=12 (>8), para que el perseguidor quede parado claramente afuera del rango de daño real.
- **Bug real encontrado y corregido (branch fuera de rango):** `ca65` rechazó `bne @no_entities` en `load_room` ("Range error") tras agregar los 2 spawns nuevos -- el bloque de spawns de pradera ya es más largo que 127 bytes. Corregido con el mismo patrón que ya usa el archivo (branch corto invertido + `jmp` sin límite de rango).
- **Bug real encontrado y corregido (interacción entre pruebas):** con el perseguidor y el atacante activos desde que carga pradera, `tools/test_state_machine.lua` empezó a fallar en su prueba de muerte por caída -- el perseguidor alcanzaba a Chiquito mientras caía por el hueco y el knockback lo sacaba antes de llegar a DEAD. Esa prueba es de la máquina de estados (F3.4), no de combate; se corrigió desactivando todas las entidades al principio (mismo criterio que ya usaba esa prueba para aislar la muerte del peligro de tile).
- Comando de build: `make rom` (WSL Ubuntu, toolchain de F0.1).
- Resultado de compilación: éxito (mismos 3 warnings de alineación de `CHARS` ya documentados y esperados desde F5.1b).
- Pruebas ejecutadas: las 14 pruebas de FCEUX existentes (con `test_entities.lua`/`test_state_machine.lua` corregidos arriba) + la nueva `tools/test_enemies.lua` + `tools/test_map2scene.py`.
- Resultados observados: `RESULT=PASS` en las 15 pruebas de FCEUX y en `test_map2scene.py`. `test_enemies.lua` verifica, contra la ROM real: el patrullero se mueve y se mantiene dentro de 160-200px (mínimo/máximo sobre 90 muestras, no 2 puntos sueltos -- un primer intento con solo 2 muestras separadas por 60 frames dio un falso negativo real, por una coincidencia aritmética del rebote, ver el bug de umbral compartido arriba para el patrón de depuración); el perseguidor cierra una distancia real (de 75px a 11px) y su Y cambia de verdad (salto visual); el atacante dispara un proyectil real (nueva entidad `PROYECTIL` activa) y ese proyectil se desactiva solo sin que el jugador lo toque; tocar al patrullero (con el resto de entidades desactivadas para aislar la prueba) pone a Chiquito en HURT. No se hizo revisión visual en FCEUX con ventana (ver restricción del usuario sobre no abrir ventanas de FCEUX durante uso de laptop) -- toda la evidencia es de `make test` (xvfb, sin ventana) más las aserciones de memoria de los Lua.
- Limitaciones pendientes: los 3 comportamientos reusan el mismo tile placeholder geométrico de F2.3 (`TILE_ENEMY`) -- visualmente indistinguibles entre sí hasta que exista arte real por tipo de enemigo (ver la tarea en curso delegada a Codex sobre animación/arte de enemigos). El perseguidor y el atacante solo existen en pradera, pantalla 1; ningún enemigo usa colisión contra tiles para su propio movimiento (el patrullero usa un rango fijo, no detección de pared/borde); el proyectil del atacante no colisiona contra tiles sólidos (atraviesa paredes) ni contra el jugador más de una vez (se consume al primer contacto, pero tampoco hay forma de que el jugador lo destruya). El jugador no puede dañar a ningún enemigo todavía (F5.3). No probado en hardware real.

## F5.3 Armas y proyectiles [P2] — Implementada, compilada, probada en emulador (2026-11-12)
- [x] Definir sistema de ataque.
- [x] Crear proyectiles.
- [x] Detectar impactos.
- [x] Definir daño, alcance y tiempo de vida.
- [x] Administrar límite de proyectiles.

**Aceptación:** ataques no generan entidades infinitas ni exceden recursos.

**Registro de la tarea:**
- Archivos: `src/main.s` (`ENTITY_TYPE_PLAYER_PROJECTILE`, `PLAYER_PROJECTILE_LIFETIME`/`LIMIT`; disparo agregado al bloque de B en `update_player`; `player_has_active_projectile`, `check_player_attacks` -nuevos-; `update_enemies` extendido para mover el proyectil del jugador con el mismo `projectile_step` genérico de F5.2; 1 línea nueva en `mainloop`), `tools/test_weapons.lua` (nuevo), `Makefile` (`weapons` agregado a `FCEUX_TESTS`).
- **Decisión de diseño (no inventada, derivada de documentos existentes):** `GAME_DESIGN_DOCUMENT.md` describe el ataque básico de Chiquito como "de corto alcance"; `TASKS.md` titula esta fase "Armas y PROYECTILES" y pide explícitamente crear proyectiles -- se implementó como un proyectil real de alcance corto (20 frames de vida a la misma velocidad que el proyectil enemigo de F5.2 = 40px, un tercio de los 120px del enemigo), no como un swing de melé con hitbox fija. Reusa toda la infraestructura de proyectiles de F5.2 (misma entidad, mismo `projectile_step`) -- `entity_type` distingue proyectil enemigo de proyectil del jugador porque `check_enemy_contact` (daña al jugador) y `check_player_attacks` (daña enemigos, nuevo) necesitan tratarlos distinto.
- **Disparo:** se dispara en el mismo instante en que ya se detectaba B (flanco de `pad1_pressed`, no sostenido) que activa `STATE_ATTACK` desde F3.4 -- el ataque sigue enraizando el movimiento horizontal igual que antes, dispare o no. Sale desde el borde del hitbox del jugador (`player_x_px ± PLAYER_HITBOX_W`) en la dirección de `player_facing_right`.
- **Límite de proyectiles (un solo sentido, no un sistema genérico):** `PLAYER_PROJECTILE_LIMIT=1` -- con el límite en 1 alcanza con comprobar "¿hay alguno activo ya?" (`player_has_active_projectile`) en vez de contar. Un ataque que no logra disparar por el límite igual enraíza el movimiento (ningún cambio de comportamiento ya probado desde F3.4).
- **Impactos (un solo sentido, lo inverso de F5.2):** `check_player_attacks` hace el mismo AABB de 8x8 que `check_enemy_contact`, pero en la otra dirección -- recorre proyectiles del jugador (X) contra enemigos (Y) de la habitación actual. Al primer impacto desactiva AMBOS: el proyectil se consume y el enemigo queda derrotado. Sin sistema de vida/puntos todavía -- un enemigo derrotado simplemente deja de existir hasta que se recargue la habitación.
- **Bug real encontrado y corregido (ya en el propio diseño, no solo en la prueba):** `player_has_active_projectile` originalmente iba a recorrer la tabla de entidades SIN filtrar por habitación (parecía innecesario, F5.2 no lo necesitaba para esto). Se corrigió a tiempo, antes de que fuera un bug real: `update_enemies` (quien mueve/consume la vida de un proyectil vía `projectile_step`) solo procesa entidades de `room_current` -- un proyectil disparado justo antes de cruzar una puerta quedaría "congelado" en la habitación abandonada, nunca llegando a desactivarse, y `player_has_active_projectile` sin el filtro lo vería como "activo para siempre", bloqueando disparar de nuevo en cualquier otra habitación. Se agregó el mismo filtro de zona que ya usa el resto del sistema de entidades.
- **Bug real encontrado y corregido (en la prueba, no en el motor):** `tools/test_weapons.lua` usaba `joypad.set(1, { b = true })` (minúscula) -- FCEUX espera `B` mayúscula (confirmado comparando con el patrón ya usado en `tools/test_state_machine.lua`); con la minúscula el botón nunca se presionaba de verdad y ningún proyectil se creaba. Corregido a `B = true`.
- **Bug real encontrado y corregido (en la prueba, no en el motor):** el paso de impacto intentaba disparar de nuevo solo 3 frames después del disparo anterior, pero ese disparo anterior dejaba a Chiquito en `STATE_ATTACK` (`ATTACK_DURATION`=14 frames) -- el chequeo de B solo corre fuera de ese estado, así que el segundo disparo se descartaba en silencio. Corregido esperando los 14 frames completos antes de intentar el disparo de la prueba de impacto.
- Comando de build: `make rom` (WSL Ubuntu, toolchain de F0.1).
- Resultado de compilación: éxito (mismos 3 warnings de alineación de `CHARS` ya documentados y esperados desde F5.1b).
- Pruebas ejecutadas: las 16 pruebas de FCEUX existentes + la nueva `tools/test_weapons.lua` + `tools/test_map2scene.py`.
- Resultados observados: `RESULT=PASS` en las 17 pruebas de FCEUX y en `test_map2scene.py`. `test_weapons.lua` verifica, contra la ROM real: el disparo sale hacia donde mira Chiquito y viaja de verdad (no queda fijo); un segundo disparo con uno ya activo no crea una segunda entidad; el proyectil se agota solo dentro de su alcance corto y libera el límite para el próximo disparo; un enemigo de prueba colocado en su trayectoria es derrotado (desactivado) y el proyectil se consume en el impacto.
- Limitaciones pendientes: el proyectil del jugador reusa el mismo tile placeholder (`TILE_ITEM`) que ya usaba el proyectil enemigo de F5.2 -- visualmente indistinguibles. No colisiona contra tiles sólidos (atraviesa paredes, igual que el proyectil enemigo). Derrotar a un enemigo no da puntos, ítems ni ningún otro feedback -- simplemente deja de existir hasta la próxima carga de la habitación (no hay sistema de vida/puntuación todavía). Sin arma secundaria ni variantes de ataque (una sola, fija). No probado en hardware real.

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

### Registro de arte del taller (2026-11-12)

Se generaron 12 tiles originales de interior y su preview con
`tools/gen_taller_tiles.py`; `png2chr.py` los convirtió correctamente en Python
local. WSL devolvió `Wsl/Service/CreateInstance/E_ACCESSDENIED` en este entorno.
Sin integración de habitación ni pruebas de ROM para este asset. El ensayo de
conversión nativa de las cinco poses de Chiquito no produjo los mismos bytes;
el pipeline existente y los sprites permanecen sin cambios. Detalle, paleta y
comandos en `assets/ASSET_MANIFEST.md`, sección de tiles del taller.
