# TASKS.md — Plan maestro de trabajo para el videojuego NES

## Estado general

- [ ] Proyecto aún no validado en repositorio.
- [x] Toolchain y entorno inspeccionado (ver informe en F0.1). Emuladores instalados; CC65/FCEUX en WSL pendientes de `sudo apt install` por el usuario.
- [ ] Mapper y layout de memoria por confirmar.
- [ ] Nivel vertical de demostración por construir.
- [ ] Producción completa pendiente.

**Regla:** actualizar este archivo en cada sesión de desarrollo. Una tarea solo se marca como completada cuando se cumplen sus criterios de aceptación y se registran pruebas reales.

## Prioridad y estados

- `P0`: bloquea el resto del proyecto.
- `P1`: necesaria para el primer nivel jugable.
- `P2`: necesaria para completar el juego.
- `P3`: mejora opcional.
- Estados: `Pendiente`, `En progreso`, `Bloqueada`, `Implementada`, `Compilada`, `Probada`.

---

# Fase 0 — Inspección y definición técnica

## F0.1 Inspeccionar repositorio [P0]
- [x] Revisar estructura, archivos y estado Git.
- [x] Detectar código existente y evitar sobrescrituras.
- [x] Identificar sistema operativo y herramientas disponibles.
- [x] Registrar versiones de compilador, linker y emuladores.
- [x] Confirmar cómo se ejecuta el build actual, si existe.

**Aceptación:** informe de estado con archivos relevantes, herramientas detectadas y bloqueos.

### Informe de estado (2026-11-10)

**Estructura y Git:**
- No existe código fuente (`src/`, assets, ROM). Repositorio es solo documentación de diseño.
- `C:\Users\erashon\umg\nes-advance` no es un repositorio Git todavía (no hay `.git/`).

**Decisión de toolchain:** build en WSL (Ubuntu), emuladores tanto en WSL (GUI vía WSLg) como en Windows nativo, por disponibilidad real de paquetes.

**Entorno Windows (host):**
- Git 2.56.0 — instalado.
- Python 3.14.7 — instalado.
- Node.js v24.21.0 — instalado.
- `ca65`/`ld65`/`cl65` (CC65) — no instalado, no disponible vía winget/choco.
- Mesen2 (`SourMesen.Mesen2` 2.1.1) — **instalado** vía winget.
- FCEUX (`FCEUX.FCEUX` 2.6.6) — **instalado** vía winget.

**Entorno WSL (Ubuntu 26.04 "resolute"):**
- Bloqueo encontrado y resuelto: `/home/erashon` tenía permisos `0600` en vez de `0755` (faltaba el bit de ejecución), lo que rompía el login shell (`.bash_profile: Permission denied`) y cualquier operación en el home. Corregido con `chmod 755 /home/erashon`.
- `cc65`/`cc65-doc` — **instalado** (`sudo apt install cc65 cc65-doc fceux`, ejecutado por el usuario el 2026-11-10). Verificado: `ca65` V2.18, `ld65` V2.18, `cl65` V2.18 (Ubuntu 2.19-2build1).
- `fceux` — **instalado** en la misma corrida. Verificado: versión 2.6.5.
- Mesen2 Linux x64 — descargado y probado manualmente en `~/tools/mesen2/Mesen` (build standalone, sin dependencias de sistema faltantes según `ldd`). Corre correctamente vía WSLg (confirmado: proceso estable, sin errores en log).
- WSLg (soporte GUI en WSL) — confirmado funcionando (`DISPLAY`, `WAYLAND_DISPLAY` y `/mnt/wslg` presentes).

**Bloqueos pendientes:**
- Mapper, header iNES/NES 2.0 y layout de memoria siguen sin confirmar (ver F0.2).

**F0.1 cerrado:** toolchain completo (build + 2 emuladores) disponible y verificado en WSL. Sin bloqueos restantes para empezar Fase 1 (infraestructura de ROM).

## F0.2 Definir plataforma y mapper [P0]
- [ ] Elegir objetivo inicial NTSC, PAL o compatibilidad dual.
- [ ] Evaluar MMC3 frente a alternativas según alcance.
- [ ] Definir iNES o NES 2.0.
- [ ] Definir PRG-ROM, CHR-ROM/CHR-RAM y bancos.
- [ ] Definir linker config y layout de memoria.
- [ ] Documentar compatibilidad esperada.

**Aceptación:** configuración consistente entre header, linker y código de mapper; ROM mínima validada.

## F0.3 Definir identidad del juego [P1]
- [ ] Proponer nombres originales para juego, protagonista y universo.
- [ ] Definir premisa narrativa breve.
- [ ] Definir fantasía central del jugador.
- [ ] Definir pilares de experiencia.
- [ ] Aprobar alcance inicial de mundos y mecánicas.

**Aceptación:** decisiones documentadas en `GAME_DESIGN_DOCUMENT.md`; no inventar aprobaciones.

---

# Fase 1 — Infraestructura de ROM

## F1.1 Toolchain y build [P0]
- [ ] Configurar ca65/ld65.
- [ ] Crear linker config.
- [ ] Crear script de build reproducible.
- [ ] Añadir validación de encabezado y tamaño de ROM.
- [ ] Añadir limpieza de artefactos generados.
- [ ] Documentar comandos en README.

**Aceptación:** desde un entorno limpio se genera una ROM válida sin pasos manuales ocultos.

## F1.2 Reset e inicialización [P0]
- [ ] Implementar reset.
- [ ] Inicializar stack.
- [ ] Configurar interrupciones.
- [ ] Inicializar PPU y APU de forma segura.
- [ ] Limpiar buffers y estado de RAM.
- [ ] Esperar sincronización de PPU cuando sea necesario.

**Aceptación:** ROM arranca de forma estable y no muestra corrupción inicial.

## F1.3 NMI/IRQ [P0]
- [ ] Implementar NMI.
- [ ] Definir responsabilidades de NMI.
- [ ] Implementar cola PPU inicial.
- [ ] Implementar OAM DMA.
- [ ] Añadir IRQ solo si el mapper y una característica aprobada lo requieren.
- [ ] Medir presupuesto de rutinas.

**Aceptación:** sincronización estable y rutinas documentadas; no exceder presupuesto sin detección.

---

# Fase 2 — Gráficos y pipeline de assets

## F2.1 Paletas [P1]
- [ ] Seleccionar paletas reales de NES para pradera.
- [ ] Crear paletas para jugador, enemigos y objetos.
- [ ] Crear paletas de fondo.
- [ ] Validar atributos de fondo.
- [ ] Probar contraste en pantalla real.

**Aceptación:** paletas válidas y legibles en ROM, no solo en editor.

## F2.2 Tiles y metatiles [P1]
- [ ] Definir formato y organización CHR.
- [ ] Crear tiles iniciales de suelo, cielo, plataformas y decoración.
- [ ] Definir metatiles.
- [ ] Crear conversor o pipeline de importación.
- [ ] Validar límites de patrones y bancos.

**Aceptación:** escenario inicial reproducible desde assets fuente.

## F2.3 Sprites [P1]
- [ ] Diseñar protagonista original.
- [ ] Crear hoja de sprites.
- [ ] Definir animaciones y hitboxes.
- [ ] Crear enemigo inicial.
- [ ] Crear coleccionable.
- [ ] Validar sprites por scanline.

**Aceptación:** sprites se muestran y animan sin corrupción; límites documentados.

---

# Fase 3 — Control, jugador y físicas

## F3.1 Controlador [P1]
- [ ] Leer D-pad y botones A/B/Start/Select.
- [ ] Normalizar estado actual y anterior para detectar pulsaciones.
- [ ] Probar combinaciones de botones.

**Aceptación:** entradas consistentes y sin lecturas erráticas.

## F3.2 Movimiento [P1]
- [ ] Definir formato de punto fijo.
- [ ] Implementar movimiento horizontal.
- [ ] Implementar aceleración y desaceleración.
- [ ] Implementar gravedad.
- [ ] Implementar salto.
- [ ] Evaluar salto variable.
- [ ] Definir velocidad máxima y control en el aire.

**Aceptación:** movimiento repetible, estable y ajustable mediante parámetros documentados.

## F3.3 Colisiones [P1]
- [ ] Separar hitbox de sprite.
- [ ] Implementar suelo y paredes.
- [ ] Implementar techos.
- [ ] Implementar plataformas.
- [ ] Implementar objetos dañinos.
- [ ] Probar esquinas y velocidades máximas.

**Aceptación:** no atraviesa superficies en casos límite probados.

## F3.4 Máquina de estados [P1]
- [ ] Idle.
- [ ] Walk/run.
- [ ] Jump/fall/land.
- [ ] Attack.
- [ ] Hurt/knockback.
- [ ] Dead.
- [ ] Conectar estados con animaciones.

**Aceptación:** transiciones deterministas y sin estados bloqueados.

---

# Fase 4 — Cámara, mapas y escenarios

## F4.1 Sistema de mapas [P1]
- [ ] Definir formato de mapa.
- [ ] Definir metatiles y propiedades de colisión.
- [ ] Crear un mapa de prueba.
- [ ] Crear herramienta de conversión.
- [ ] Documentar límites de tamaño y compresión.

**Aceptación:** mapa de fuente externa integrado correctamente en ROM.

## F4.2 Scrolling [P1]
- [ ] Implementar coordenadas de mundo.
- [ ] Implementar coordenadas de pantalla.
- [ ] Implementar cámara horizontal.
- [ ] Implementar límites de cámara.
- [ ] Actualizar nametables por sectores.
- [ ] Probar límites y wrap de scroll.

**Aceptación:** desplazamiento continuo sin corrupción gráfica.

## F4.3 Pantallas y habitaciones [P1]
- [ ] Definir formato de habitación.
- [ ] Implementar carga de habitación fija.
- [ ] Implementar puertas/salidas.
- [ ] Implementar transición y spawn.
- [ ] Definir persistencia de objetos y enemigos.

**Aceptación:** transición entre una zona de scrolling y una habitación fija sin pérdida de estado no deseada.

## F4.4 Elementos de escenario [P2]
- [ ] Plataformas móviles.
- [ ] Interruptores.
- [ ] Puertas.
- [ ] Obstáculos.
- [ ] Zonas secretas.
- [ ] Puntos de control.

**Aceptación:** cada elemento tiene comportamiento y pruebas documentadas.

---

# Fase 5 — Enemigos y combate

## F5.1 Sistema de entidades [P1]
- [ ] Definir estructura compacta de entidad.
- [ ] Definir número máximo simultáneo.
- [ ] Implementar creación y destrucción.
- [ ] Implementar actualización por prioridad o zona.

**Aceptación:** entidades no corrompen memoria ni exceden límites definidos.

## F5.2 Enemigos básicos [P1]
- [ ] Enemigo patrullero.
- [ ] Enemigo perseguidor o saltador.
- [ ] Enemigo de ataque a distancia.
- [ ] Daño y colisiones.
- [ ] Desaparición/reaparición según reglas.

**Aceptación:** comportamientos distintos y reproducibles.

## F5.3 Armas y proyectiles [P2]
- [ ] Definir sistema de ataque.
- [ ] Crear proyectiles.
- [ ] Detectar impactos.
- [ ] Definir daño, alcance y tiempo de vida.
- [ ] Administrar límite de proyectiles.

**Aceptación:** ataques no generan entidades infinitas ni exceden recursos.

## F5.4 Jefes [P2]
- [ ] Definir formato de patrón.
- [ ] Crear primer jefe original.
- [ ] Implementar fases y vulnerabilidad.
- [ ] Añadir indicador de energía.
- [ ] Añadir derrota y recompensa.

**Aceptación:** combate completo, ganable y repetible.

---

# Fase 6 — Power-ups y progresión

- [ ] Definir habilidades originales.
- [ ] Implementar obtención y activación.
- [ ] Implementar duración/energía/cooldown según diseño.
- [ ] Definir inventario o selección si aplica.
- [ ] Implementar coleccionables.
- [ ] Implementar vidas/energía y puntos de control.
- [ ] Definir progreso entre niveles.

**Aceptación:** las habilidades modifican el juego de forma comprobable y equilibrada.

---

# Fase 7 — Audio

- [ ] Elegir o desarrollar driver APU.
- [ ] Definir formato de secuencias musicales.
- [ ] Crear música original de menú.
- [ ] Crear música original de nivel.
- [ ] Crear música de jefe.
- [ ] Crear efectos de salto, ataque, daño y recompensa.
- [ ] Definir prioridades y asignación de canales.
- [ ] Medir coste de CPU.

**Aceptación:** audio estable, música y efectos coordinados y sin bloqueos.

---

# Fase 8 — Contenido completo

- [ ] Aprobar mapa de mundos y progresión.
- [ ] Definir cantidad y estructura de niveles.
- [ ] Diseñar rutas principales y opcionales.
- [ ] Crear sets gráficos por ambiente.
- [ ] Crear enemigos específicos por mundo.
- [ ] Crear jefes y recompensas.
- [ ] Crear secretos y coleccionables.
- [ ] Crear menús y pantallas de transición.
- [ ] Crear final y créditos originales.

**Aceptación:** todo el contenido previsto existe, se puede completar y está integrado en ROM.

---

# Fase 9 — Optimización y compatibilidad

- [ ] Auditar RAM y Zero Page.
- [ ] Auditar stack.
- [ ] Auditar PRG/CHR y bancos.
- [ ] Medir ciclos de rutinas críticas.
- [ ] Medir presupuesto de VBlank.
- [ ] Probar saturación de sprites.
- [ ] Probar carga máxima de entidades.
- [ ] Probar transiciones repetidas.
- [ ] Probar reinicio, pausa y muerte.
- [ ] Probar en Mesen.
- [ ] Probar en FCEUX.
- [ ] Probar en hardware real si está disponible.
- [ ] Documentar incompatibilidades conocidas.

**Aceptación:** informe de pruebas reproducible y sin defectos críticos conocidos.

---

# Fase 10 — Entrega

- [ ] Generar build release.
- [ ] Validar encabezado y mapper.
- [ ] Validar tamaño y checksum.
- [ ] Incluir instrucciones de ejecución.
- [ ] Incluir documentación técnica.
- [ ] Incluir créditos y licencias de assets/herramientas.
- [ ] Archivar fuentes y assets necesarios para reproducir la ROM.
- [ ] Etiquetar versión final.

**Aceptación:** entrega reproducible con ROM, fuentes, assets, herramientas/instrucciones y documentación.

---

## Hito obligatorio: primer nivel vertical

Antes de producir todos los mundos, completar un nivel corto que contenga:

- protagonista original provisional;
- controles;
- movimiento y salto;
- colisiones;
- escenario colorido;
- scrolling horizontal;
- al menos una habitación fija;
- transición entre ambos modos;
- un enemigo;
- un coleccionable;
- música o efecto original;
- meta/salida;
- ROM ejecutable y pruebas.

Este hito valida arquitectura, arte, físicas y pipeline. No sustituye el objetivo de crear el juego completo.

## Registro por tarea

Para cada tarea completada añadir:
- fecha;
- commit o referencia de cambio;
- archivos modificados;
- comando de build;
- resultado;
- emulador/hardware utilizado;
- pruebas ejecutadas;
- problemas pendientes.
