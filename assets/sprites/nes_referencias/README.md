# Poses NES derivadas de referencias

Primera conversión automática de una pose de cada personaje: Chiquito,
Sanchopau, Mothman, Marcianito, Abuelito y Diablito. Son borradores para
retoque de pixel art; no son animaciones terminadas ni están integrados en la ROM.
También se incluyen borradores de cinco criaturas de montaña (roedor, carnero,
erizo, ave y roca), generados desde la hoja de conceptos. Las referencias
originales permanecen intactas. Sus poses requieren retoque, animación y prueba
en escena antes de considerarse terminadas.

Cada personaje tiene un PNG transparente de 32×32, un archivo `.chr` con tiles
8×8 NES de 2 bits por píxel y un JSON con desplazamientos, índice de tile y
subpaleta de cada pieza. Los índices de color en `palettes_nes` son valores PPU;
el índice 0 del tile es transparente y los índices 1–3 corresponden a los tres
valores de la subpaleta. Los tiles vacíos se omiten. Los valores RGB del PNG son
aproximaciones para previsualización, no colores medidos en una consola.

Cada personaje usa como máximo cuatro piezas por línea cuando se muestra solo.
La NES permite ocho sprites por línea para toda la escena y cuatro subpaletas de
sprites compartidas por todos los personajes; estas paletas se escogieron por
personaje y **no se pueden cargar todas simultáneamente** sin armonizarlas o
separar escenas. Tampoco se ha probado flicker ni memoria en la ROM.

Para regenerar: `uv run tools/convert_reference_sprites.py`. La imagen
`vista_general.png` amplía los PNG con vecino más cercano. Las poses restantes
de caminar, saltar y acciones necesitan dibujo y alineación manual; las imágenes
de entrada no son hojas de sprites con cuadrícula validada.
