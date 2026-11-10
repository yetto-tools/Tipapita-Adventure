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