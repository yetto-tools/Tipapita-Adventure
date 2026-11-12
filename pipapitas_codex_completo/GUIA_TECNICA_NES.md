# Guía técnica NES: de concepto a sprite jugable

## Hardware y tamaños

- NES: tiles gráficos de **8×8 píxeles**; sprites de hardware en modo **8×8 o 8×16**.
- OAM: **64 sprites** totales; máximo **8 sprites evaluados por scanline** (los siguientes pueden no aparecer).
- Paletas: 4 subpaletas de sprites; cada sprite usa **3 colores visibles más transparencia**.
- Metasprites lógicos propuestos: **Chiquito 24×24; Sanchopau 24×24; Diablito 24×24; Abuelito 24×24; Marcianitos 24×24; Mothman 32×32**. Son objetivos artísticos, no tamaños de hardware ni dimensiones cerradas.
- Un metasprite de 24×24 totalmente relleno con 8×8 puede requerir 9 sprites; en una misma línea horizontal podría necesitar 3, pero varios personajes o elementos juntos pueden superar el límite de 8. El coste real depende de silueta, posición y solapamientos.

## Animaciones con tablas

Usar un sistema de estados + clips + cuadros + piezas OAM, por ejemplo:

```text
state = WALK
clip = [frame_0:6 ticks, frame_1:6 ticks, frame_2:6 ticks, frame_3:6 ticks]
frame_0 = [(dx,dy,tile_id,attributes), ...]
```

Cada cuadro debe almacenar offsets relativos al ancla del personaje; las colisiones y físicas deben permanecer separadas del dibujo.

## Flujo de producción

1. Analizar una hoja de referencia y definir silueta jugable a resolución nativa.
2. Dibujar manualmente frames consistentes en una grilla de píxeles.
3. Elegir paleta NES real y verificar subpaletas.
4. Convertir frames en tiles CHR, eliminando duplicados cuando sea posible.
5. Generar tablas de metasprites, clips y duraciones.
6. Medir sprites por scanline en escenas reales con varios personajes.
7. Integrar en ROM y probar en Mesen u otro emulador apropiado.
8. Comparar captura a 256×240 contra referencia y ajustar.

## MMC3

MMC3 es **candidato**, no mapper confirmado. Si se elige, aprovechar bank switching de CHR para variantes y animaciones, cuidando granularidad de bancos y asignación de tiles. Las IRQ del mapper requieren planificación y pruebas. No asumir CHR-RAM, tamaño de PRG/CHR o capacidad de guardado hasta definir cartucho/mapper.

## Prioridad de implementación

Primero: Chiquito idle/caminar/saltar, una escena, un enemigo y medición de OAM. Luego: Sanchopau y NPC; después Mothman y personajes con alas, que tienen mayor coste visual.
