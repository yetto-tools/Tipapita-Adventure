# Tipapita-Adventure

## Descripción

Videojuego de aventuras para Nintendo Entertainment System (NES), protagonizado por Chiquito, un pequeño chihuahua que vive con su familia en las montañas.

El juego combina exploración, plataformas, combate, recolección de recursos, agricultura, construcción de tecnología y descubrimiento de misterios.

## Identidad del juego

- Protagonista: Chiquito.
- Familia: Los Pipapitas o Pipapa.
- Compañero: Sanchopau.
- Mentora: Abuelita Pipapita.
- Guardián de las montañas: Pipapita Mothman.
- Ambientación: Fantasía, naturaleza y ciencia ficción.
- Estilo visual: Pixel art colorido, alegre y detallado.
- Plataforma objetivo: NES.

## Documentación

| Archivo | Contenido |
|---|---|
| CLAUDE.md | Reglas e instrucciones de trabajo para el asistente |
| GAME_DESIGN_DOCUMENT.md | Visión, identidad y diseño del juego completo |
| LOREBOOK.md | Universo y personajes |
| HISTORIA_COMPLETA.md | Historia y capítulos |
| ART_GUIDELINES.md | Dirección artística |
| assets/ASSET_MANIFEST.md | Fuentes, tiles, sprites, paletas y presupuesto OAM del pase visual actual |
| ARCHITECTURE.md | Arquitectura técnica |
| TASKS.md | Plan de desarrollo |

## Build

Requiere el toolchain de CC65 (`ca65`, `ld65`) y `python3`, instalados vía `apt` en WSL/Ubuntu (`sudo apt install cc65 cc65-doc`).

```sh
make rom     # compila y enlaza dist/chiquito.nes, valida header/tamaño
make check   # solo valida la ROM ya compilada
make test    # ejecuta pruebas FCEUX invisibles dentro de Xvfb
make run     # abre la ROM en FCEUX (requiere fceux instalado: sudo apt install fceux)
make clean   # borra dist/
```

`make test` usa `xvfb-run` y `SDL_AUDIODRIVER=dummy`, por lo que no muestra una
ventana de FCEUX ni requiere audio. `make run` se conserva visible para revisión
manual de gráficos y controles.

La ROM se genera en `dist/chiquito.nes` (iNES, mapper 4 / MMC3, PRG-ROM 128 KB, CHR-ROM 128 KB — ver decisiones en `ARCHITECTURE.md`). `dist/` no se versiona (ver `.gitignore`).

Estado actual: ROM mínima que enlaza y carga en FCEUX/Mesen2 sin errores de mapper/tamaño. Todavía no tiene inicialización real de PPU/APU, NMI ni gráficos — eso corresponde a las siguientes tareas de `TASKS.md` (F1.2, F1.3).

## Principios del proyecto

1. Chiquito es siempre el protagonista.
2. La historia debe conservar coherencia entre capítulos.
3. La tecnología debe respetar las capacidades reales de NES.
4. Los recursos recolectados deben tener utilidad.
5. La exploración debe recompensar la curiosidad.
6. El mundo debe sentirse alegre, misterioso y vivo.
7. No copiar personajes, escenarios, música ni recursos protegidos de otros videojuegos.

## Objetivo

Construir una aventura completa y original, desarrollada progresivamente, con una historia memorable y una identidad visual propia.
