# Manifiesto de assets NES

## Chiquito (F5.1c) — 2026-11-12

Las 5 poses reales del protagonista (conversión fiel del concept art,
no un redibujo a mano -- mismo criterio que la corrección de Sanchopau
de abajo): `assets/sprites/nes_referencias/chiquito.chr` (idle),
`chiquito_caminar_1.chr`, `chiquito_caminar_2.chr`, `chiquito_correr.chr`
y `chiquito_saltar.chr`, cada uno con su `.json` de tiles/paleta.

- Formato: 32×32 (4×4 tiles), un número de tiles DISTINTO por pose (14
  a 16 de 16 posibles -- las referencias no siempre llenan la grilla).
  Reemplaza a `assets/sprites/chiquito_v2.png` (dibujado a mano,
  `tools/gen_chiquito_sprites.py`), que se deja en el repo sin uso en
  el build real.
- Paletas: las 5 poses declaran las mismas 4 subpaletas y usan solo los
  índices 0/1/3 (el 2 no aparece en ninguna). 0 y 3 comparten el mismo
  naranja intermedio y solo difieren en el tono claro ($38 crema vs $20
  blanco) -- se fusionaron en el slot de sprite 0 (el pelaje); el 1,
  la única paleta en escala de grises, quedó en el slot 3 (el
  sombrero). Es POR TILE, no por mitad superior/inferior -- ver
  `chiquito_pose_tables.s` (generado) y `draw_player_metasprite` en
  `src/main.s`.
- Animación: WALK se reparte entre caminar (2 cuadros alternados) y
  correr según la velocidad horizontal real (`RUN_SPEED_THRESHOLD`,
  decisión confirmada con el usuario -- no un botón nuevo). JUMP/FALL
  comparten la pose de salto.
- Generado por `tools/gen_chiquito_poses.py`: concatena los 5 `.chr` y
  produce, por pose, una tabla de 16 tiles (absoluto o `$FF` si la
  celda no tiene pieza real) y una de 16 paletas (0/1), leídas directo
  del JSON -- no a mano.
- Probado: `make test` (14 pruebas FCEUX) en verde. Revisión visual
  real en FCEUX confirma las 5 poses, el reflejo al mirar a la
  izquierda y el arco completo del salto -- ver el registro de la
  tarea en `TASKS.md` (F5.1c) para el detalle de los bugs reales
  encontrados y corregidos en el camino.
- Enemigo/ítem/plataforma de prueba (F2.3/F4.4) se separaron a
  `assets/sprites/scenery_v1.png` (`tools/gen_scenery_sprites.py`) --
  siguen siendo pixel art a mano simple, sin referencia real todavía.

## Elenco (F5.1b) — 2026-11-12, corregido el mismo día

**Corrección importante (ver abajo):** el primer pase de esta sección
rediseñaba el elenco a mano (`tools/gen_cast_sprites.py`); al verlo
renderizado en FCEUX se confirmó que la calidad quedaba muy por debajo
de `assets/sprites/nes_referencias/*.png` (conversión automática real
desde el concept art, mucho más fiel). Sanchopau se reemplazó por esa
conversión fiel; el resto del pase (CHR-ROM separado, paleta por
habitación, sistema de actor) no cambió. `gen_cast_sprites.py` se deja
en el repo como herramienta, sin uso en el build real.

Sanchopau, Mothman, Abuelito, Diablito y Marcianito tienen su sprite
32×32 ya generado por `tools/convert_reference_sprites.py` en
`assets/sprites/nes_referencias/*.chr`+`.json`, a partir de las
referencias reales (`pipapitas_codex_completo/referencias/`). Solo
Sanchopau está integrado hoy.

- Formato: 32×32 (4×4 tiles = 16), **una sola pose** -- esas referencias
  no traen caminar/salto dibujados (a diferencia de Chiquito, que sí
  tiene un sprite sheet de 4 poses real). Sanchopau se desliza en Casa
  con esa única pose en vez de animar las piernas; animarlo de verdad
  necesita más poses de referencia, no inventarlas a mano (ver la
  corrección de arriba).
- Paletas: la NES solo tiene 4 subpaletas de sprite en total, y
  Chiquito (jugador) ocupa 2 en todo momento -- cualquier otro
  personaje solo puede usar las 2 que quedan. `sanchopau.json` declara
  4 subpaletas pero solo usa 3 tiles distintos de verdad: dos de ellas
  (gris oscuro/blanco con distinto tono de gris intermedio) se
  fusionaron en una sola subpaleta real (la diferencia de tono era
  imperceptible); la tercera (el parche naranja sobre un ojo, un solo
  tile) quedó como la segunda subpaleta. La asignación es **por tile**,
  no por mitad superior/inferior como Chiquito -- ver
  `sanchopau_tile_palette` en `src/data/palettes.s` y cómo la consulta
  `draw_npc_metasprite` en `src/main.s`. Esos 2 slots (hoy "enemigo"/
  "ítem" de prueba) se reparten por habitación: ver
  `sanchopau_sprite_overlay` y la nota de paleta por habitación en
  `load_room`.
- CHR-ROM: la pattern table de sprites de la PPU solo muestra 256 tiles
  a la vez ($1000-$1FFF) sin importar cuánto CHR-ROM tenga el cartucho.
  Sanchopau (16 tiles) se incluye tal cual desde su `.chr` ya convertido
  (`tools/chr2asm.py`, sin pasar por PNG ni remapeo de color) justo
  después de los 19 de Chiquito/enemigo/ítem/plataforma. El resto del
  elenco (`mothman.chr`, `abuelito.chr`, `diablito.chr`,
  `marcianito.chr`) existe pero no está mapeado todavía -- se integrará
  banco por banco (con el mismo análisis de fusión de paletas que
  Sanchopau) cuando se construya la habitación de cada uno.
- Integrado en la ROM: Sanchopau patrulla en ROOM_CASA
  (`update_npc`/`draw_npc_metasprite` en `main.s`), oculto y con la
  paleta restaurada automáticamente fuera de esa habitación. Probado
  con `tools/test_npc.lua` (`make test`): visibilidad, paleta por
  habitación y rango de patrulla, contra la ROM real en FCEUX.
  Revisión visual real en el emulador confirma la fidelidad a
  `nes_referencias/sanchopau.png`.

## Pase visual v2 — 2026-11-11

Este pase sustituye los placeholders geométricos de Chiquito y la pradera por
assets dibujados directamente sobre la cuadrícula NES. Los PNG conceptuales de
`pipapitas_codex_completo/referencias/` se usan como referencia de identidad;
no se redimensionan ni se convierten automáticamente a CHR.

### Chiquito

- Fuente técnica activa: `assets/sprites/chiquito_v2.png`.
- Vista ampliada: `assets/sprites/chiquito_v2_preview.png`.
- Generador editable: `tools/gen_chiquito_sprites.py`.
- Tamaño lógico: 16×16 px.
- Coste: 4 sprites OAM por cuadro; máximo 2 sprites en una scanline.
- Ancla física: hitbox 8×8 centrado; el dibujo se extiende 4 px a cada lado y
  8 px hacia arriba, por lo que no cambia la colisión existente.
- Paleta superior: contorno, pelaje y crema.
- Paleta inferior: contorno, pelaje y pañuelo rojo.

| Pose | Tile base | Tiles |
|---|---:|---:|
| Idle | 12 | 12–15 |
| Caminar/contacto | 16 | 16–19 |
| Caminar/paso | 20 | 20–23 |
| Salto/caída | 24 | 24–27 |

Los tiles 28 y 29 conservan temporalmente el enemigo y el coleccionable de
prueba. El tile 30 es la plataforma móvil de madera.

### Montañas Pipapita

- Fuente técnica activa: `assets/tiles/montanas_v2.png`.
- Vista ampliada con paletas aproximadas: `assets/tiles/montanas_v2_preview.png`.
- Generador editable: `tools/gen_montanas_tiles.py`.
- Formato: 8 tiles de 8×8, cuatro índices de color globales.

| Tile | Uso |
|---:|---|
| 0 | Cielo/vacío |
| 1 | Nube |
| 2 | Borde de pasto |
| 3 | Tierra |
| 4 | Plataforma de nube |
| 5 | Puerta de madera |
| 6 | Punto de control |
| 7 | Interruptor de taller |
| 8–11 | Cuadrantes de nube 2×2 reservados para la próxima ampliación del compilador de mapas |

### Referencia artística auxiliar

- `assets/concepts/chiquito_scale_reference_v2.png`: estudio de escala y claridad.
- `assets/concepts/montanas_rich_background_reference_v1.png`: objetivo de
  composición, profundidad y motivos rurales.

Estas imágenes no forman parte del CHR, exceden deliberadamente restricciones
reales de la PPU y no deben convertirse ni redimensionarse automáticamente.

### Reproducción

```text
uv run tools/gen_chiquito_sprites.py
uv run tools/gen_montanas_tiles.py
make -B rom
```

Los archivos v1 se conservan como historial. El pase v2 es técnicamente jugable
y verificable, pero sigue sujeto a revisión
visual antes de declararse arte final.
