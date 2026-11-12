# Instrucciones para Codex CLI

Lee los documentos de esta carpeta en el siguiente orden:

1. `README.md`
2. `CANON_Y_PERSONAJES.md`
3. `DIRECCION_ARTISTICA.md`
4. `REFERENCIAS_VISUALES.md`
5. `GUIA_TECNICA_NES.md`
6. `PLAN_ASSETS.md`

**Misión:** convertir la dirección visual de Chiquito y los Pipapitas en un pipeline de sprites para NES, sin perder identidad y sin inventar hechos narrativos.

**Antes de codificar:** inspecciona el repositorio y determina si hay ROM base, toolchain, mapper, formato CHR, emulador, sistema de animación y assets existentes. No sobrescribas archivos existentes sin justificarlo. Identifica qué está confirmado y qué está pendiente.

**Primer entregable:** propuesta técnica breve, lista de decisiones pendientes y prototipo verificable de **Chiquito** (idle, caminar, saltar) usando metasprites y tablas de animación; incluye presupuesto OAM, capturas de emulador si está disponible y comandos reproducibles para compilar. Si el repositorio no está listo, prepara primero la ROM mínima y explica los bloqueos.

**Reglas:**
- Usa la imagen `referencias/estilo/referencia_usuario_chihuahua_sombrero_turquesa.jpg` como guía principal del estilo, y `referencias/personajes/chiquito_concepto_02_turquesa.png` como diseño de Chiquito.
- No conviertas PNG conceptuales en sprites NES simplemente redimensionándolos.
- Respeta las restricciones reales de paletas, tiles, OAM y timing.
- No des por aprobado MMC3; evalúa y documenta.
- No conviertas a Mothman en villano; no sitúes a la familia de Sanchopau en otro planeta.
- No confundas al Abuelito con la Abuelita ni cambies la raza visual de Sanchopau.
- Reporta archivos modificados, pruebas ejecutadas y próximos pasos.
