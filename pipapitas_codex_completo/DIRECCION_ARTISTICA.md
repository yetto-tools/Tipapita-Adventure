# Dirección artística

## Referencia principal elegida por el usuario

La imagen `referencias/estilo/referencia_usuario_chihuahua_sombrero_turquesa.jpg` define la dirección preferida: **pixel art limpio, grandes píxeles claramente definidos, contornos negros sólidos, cara expresiva con ojos grandes, silueta simple, colores vivos y fondo turquesa liso para presentación**. El usuario pidió explícitamente acercar las ilustraciones a esta imagen, y las hojas posteriores siguen ese lenguaje.

## Reglas visuales

- Priorizar la silueta reconocible sobre microdetalles.
- Cabezas relativamente grandes, ojos expresivos y orejas distintivas.
- Mantener el mismo grosor visual de contorno y escala aparente de píxel entre personajes.
- Diseñar versiones de **retrato**, **sprite jugable** y **retrato de diálogo** por separado.
- Los fondos turquesa de las hojas son fondos de presentación, **no color transparente ni color obligatorio del juego**.
- No copiar elementos protegidos de Kirby, Mario, Mega Man ni personajes existentes; inspirarse solo en técnicas generales de claridad, expresividad y animación.
- No extraer una paleta NES directamente de los colores RGB de las imágenes; remapear y validar.
- Usar *Kirby's Adventure* (NES) como referencia técnica de escala, claridad,
  animación y riqueza de fondos, nunca como fuente de personajes, tiles,
  escenarios, layouts o elementos copiables.
- Para Chiquito, priorizar una caja lógica 16×16 bien ocupada antes de aumentar
  tamaño; personajes mayores requieren presupuesto OAM y prueba por scanline.
- La imagen de Pebble no está incluida: la apariencia de Sanchopau se define mediante el canon textual y sus conceptos originales.

## Diferencias de iteración

Las primeras hojas tienen fondo negro, más gradientes y detalle tipo arte promocional. Las más recientes tienen fondo turquesa y sprites compactos; **estas últimas prevalecen como dirección estilística**. El diseño final de Chiquito es el de `chiquito_concepto_02_turquesa.png` para el look de presentación (sombrero oscuro y pañuelo rojo), sujeto a simplificación para NES.

## Entregables por personaje

- `portrait`: ilustración de referencia de alta resolución.
- `gameplay`: metasprite en 3 vistas útiles (frontal, lateral, espalda solo si hace falta).
- `animations`: cuadros de idle, caminar, correr, saltar y acciones propias.
- `palette`: tabla de colores NES y subpaletas asignadas.
- `tilemap`: CHR real de 8x8 (o 8x16 en modo sprite elegido).
- `metadata`: offsets, duración de cuadros, hitbox, eventos y uso de OAM.

Ninguno de estos assets técnicos está listo solo por disponer de los PNG de concepto.
