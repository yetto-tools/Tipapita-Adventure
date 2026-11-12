# Chiquito y los Pipapitas — paquete de contexto para Codex CLI

Este paquete reúne el canon narrativo confirmado, fichas visuales y nueve imágenes de referencia disponibles en la conversación (ocho ilustraciones conceptuales generadas y una imagen aportada por el usuario).

## Cómo usarlo

1. Copiar el contenido de esta carpeta a `docs/contexto-pipapitas/` dentro del repositorio del juego, o mantenerlo en la raíz del proyecto.
2. Abrir Codex CLI desde la raíz del repositorio.
3. Pedir a Codex que lea `CODEX_START_HERE.md`, `CANON_Y_PERSONAJES.md`, `DIRECCION_ARTISTICA.md`, `REFERENCIAS_VISUALES.md` y `GUIA_TECNICA_NES.md` antes de diseñar assets o escribir código.
4. Utilizar las imágenes como *referencias*, nunca como assets NES finales.

## Contenido

- `CODEX_START_HERE.md`: prompt de arranque y prioridades.
- `CANON_Y_PERSONAJES.md`: personajes, historia y hechos confirmados.
- `DIRECCION_ARTISTICA.md`: guía estética y consistencia.
- `REFERENCIAS_VISUALES.md`: catálogo de archivos de imagen y sus diferencias.
- `GUIA_TECNICA_NES.md`: restricciones de sprites, tiles, animaciones y MMC3.
- `PLAN_ASSETS.md`: plan de implementación verificable.
- `referencias/personajes/`: ocho conceptos individuales o de grupo (incluido un concepto de elenco en `estilo/`).
- `referencias/estilo/`: referencia original del usuario y hoja de elenco.

## Estado

La historia es un universo en construcción. Los hechos marcados como **confirmados** son canon; propuestas de vestuario, colores, habilidades y tamaño son modificables con aprobación. No afirmar que una imagen generada es un sprite sheet extraíble o válido para NES sin un proceso técnico de conversión y validación.
