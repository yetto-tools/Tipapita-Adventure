# ART GUIDELINES
## Tipapita-Adventure

## 1. Dirección artística

El juego debe utilizar pixel art colorido, alegre, detallado y reconocible.

La identidad visual debe transmitir:

- Naturaleza.
- Fantasía.
- Aventura.
- Humor.
- Misterio.
- Calidez familiar.

### Referencia técnica confirmada: Kirby's Adventure (NES)

Usar *Kirby's Adventure* únicamente como referencia de nivel de oficio en NES:
personajes que llenan su caja lógica, contornos legibles, animación expresiva,
paletas claras, fondos con sensación de profundidad y variación visual entre
regiones. No copiar personajes, enemigos, habilidades, tiles, composiciones,
interfaces, escenarios ni layouts del juego de referencia.

- Chiquito usa una caja lógica base de **16×16 px**, formada por 4 tiles de 8×8.
- La silueta debe ocupar aproximadamente 14–16 px de la caja; evitar que el
  personaje se perciba como un sprite de 8×8 rodeado de espacio vacío.
- Personajes especiales, jefes y efectos pueden superar 16×16 si el presupuesto
  OAM y el límite de 8 sprites por scanline se miden en escenas reales.
- Los fondos deben organizarse en tres bandas visuales: silueta distante,
  decoración media y primer plano con colisión claramente legible.
- La profundidad se simula con contraste, densidad de línea, paletas y scrolling;
  NES no dispone de capas modernas libres ni transparencia alfa.

Las referencias a juegos clásicos sirven únicamente como inspiración de ritmo, exploración y calidad artística. No copiar personajes, sprites, escenarios, interfaces ni recursos protegidos.

## 2. Personajes

### Chiquito
- Chihuahua pequeño.
- Silueta reconocible.
- Expresiones claras.
- Animaciones expresivas.
- Movimiento ágil.
- Apariencia adorable y valiente.

### Abuelita
- Chihuahua anciana.
- Rasgos que comuniquen edad.
- Expresiones cálidas.
- Animaciones tranquilas.

### Sanchopau
- Perrito inventor.
- Accesorios relacionados con mecánica.
- Apariencia amigable.
- Animaciones de construcción y experimentación.

### Pipapita Mothman
- Criatura alada.
- Silueta misteriosa.
- Apariencia de guardián.
- Movimientos suaves e imponentes.

## 3. Escenarios

Los escenarios deben combinar:

- Montañas.
- Campos de maíz.
- Árboles.
- Ríos.
- Cuevas.
- Talleres.
- Construcciones rurales.
- Lugares misteriosos.

Cada región debe tener una identidad visual propia.

## 4. Color

Se busca una paleta alegre con:

- Verdes naturales.
- Amarillos cálidos.
- Azules de cielo.
- Marrones de tierra.
- Tonos de flores.
- Colores especiales para tecnología y criaturas.

Los colores conceptuales no representan colores RGB directamente disponibles en NES.

## 5. Restricciones de NES

Respetar las limitaciones reales de la PPU:

- Paletas de fondo y sprites.
- Restricciones de colores por subpaleta.
- Atributos de paleta por bloques.
- Tiles de 8 × 8 píxeles.
- OAM con 64 sprites.
- Límite de 8 sprites por scanline.

Los diseños deben ser legibles a la resolución nativa.

## 6. Animaciones

Priorizar:

- Idle.
- Caminar.
- Correr.
- Saltar.
- Caer.
- Recibir daño.
- Interactuar.
- Celebrar.
- Usar habilidades.

Las animaciones deben ser expresivas sin desperdiciar memoria.

## 7. Interfaz

La interfaz debe ser sencilla, legible y coherente con el universo.

Debe incluir:

- Vida.
- Objetos recolectados.
- Recursos.
- Habilidades.
- Estado de misiones.
- Progreso tecnológico.

## 8. Entregables artísticos

Cada recurso debe incluir:

- Nombre.
- Propósito.
- Dimensiones.
- Paleta utilizada.
- Número de tiles.
- Animaciones.
- Restricciones técnicas.
- Escenario donde se utiliza.
