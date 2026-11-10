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