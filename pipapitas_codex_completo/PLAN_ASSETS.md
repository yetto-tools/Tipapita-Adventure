# Plan de producción de assets

## Fase A — Auditoría
- [ ] Verificar cada imagen del índice.
- [ ] Extraer una guía de silueta y color por personaje sin tratar PNG como CHR.
- [ ] Acordar si el sombrero de Chiquito se usa siempre o como accesorio.
- [ ] Confirmar rol de Diablito y parentesco de Abuelito.

## Fase B — Prototipo de Chiquito
- [ ] Crear sprite jugable a tamaño lógico objetivo de 24×24.
- [ ] Crear 4 frames de caminar, 2 idle, salto y caída.
- [ ] Construir tiles 8×8 y tabla de metasprites.
- [ ] Verificar paleta NES y OAM por scanline.
- [ ] Probar en ROM real y capturar evidencia.

## Fase C — Personajes
- [ ] Sanchopau: idle, caminar, construir.
- [ ] Mothman: idle, aletear, vuelo, proteger.
- [ ] Marcianitos: variante base, caminar, interactuar.
- [ ] Diablito: idle, caminar, salto, fuego (si se confirma habilidad).
- [ ] Abuelito: idle, caminar, cosechar, machete.
- [ ] Abuelita y hermanos: crear concepto inicial pendiente.

## Fase D — Pipeline
- [ ] Definir formatos de fuentes editables y exportación.
- [ ] Automatizar empaquetado de CHR y tablas, con validaciones.
- [ ] Documentar memoria y presupuesto de sprites.
- [ ] Crear pruebas de regresión de animación.

## Definición de terminado

Un asset se considera listo cuando existe en fuente editable, exporta correctamente a formato NES, se renderiza en la ROM y pasa las pruebas visuales y de presupuesto OAM. Una ilustración de concepto por sí sola **no cumple** esta definición.
