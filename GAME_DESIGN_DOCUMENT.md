# GAME DESIGN DOCUMENT
## Proyecto: Tipapita-Adventure

**Versión:** 1.2 — título confirmado para F0.3  
**Plataforma:** NES / Famicom  
**Tipo:** Plataformas, aventura y acción 2D  
**Resolución:** 256 × 240 píxeles  
**Arquitectura:** Ricoh 2A03 / 6502  
**Mapper objetivo inicial:** MMC3 (Mapper 4)  
**Compilación:** ROM `.nes`

> **Estado de F0.3 (2026-11-11):** premisa, fantasía y pilares documentados como
> propuesta de diseño. Los nombres comerciales y el alcance inicial requieren
> aprobación expresa del responsable del proyecto. Nada en esta sección debe
> interpretarse como aprobado por omisión.

---

# 1. VISIÓN DEL PROYECTO

Desarrollar un videojuego original para Nintendo Entertainment System que recupere la diversión, creatividad, exploración y personalidad de los grandes juegos de plataformas de 8 bits.

Referencias de diseño:

- Super Mario Bros. 3: exploración, mapas, mundos, secretos, power-ups y escenarios.
- Ninja Gaiden: acción, movilidad, combate y ritmo.
- Mega Man 3: armas, enemigos, jefes, patrones y variedad de niveles.

No copiar personajes, nombres, música, escenarios, sprites ni recursos protegidos de estos juegos.

Crear una identidad artística y mecánica completamente original.

## 1.1 Identidad del juego — F0.3

Esta sección concentra la identidad jugable y narrativa. Si una lista genérica de
características en otra parte de este documento entra en conflicto con el alcance
acotado de F0.3, prevalece esta sección hasta que se registre una nueva decisión.

### Estado de las decisiones

| Decisión | Estado | Fuente o acción necesaria |
|---|---|---|
| Protagonista llamado **Chiquito** | **Confirmado en el canon existente** | `pipapitas_codex_completo/CANON_Y_PERSONAJES.md` |
| Familia y criaturas llamadas **Pipapitas** o **Pipapa** | **Confirmado como concepto; grafía normalizada provisionalmente a “Pipapita”** | Confirmar la grafía definitiva antes de preparar logotipo o texto final |
| Título comercial | **Confirmado: `Tipapita-Adventure`** | Decisión expresa del responsable del proyecto, 2026-11-11 |
| Nombre del universo | **Propuesta pendiente de aprobación** | Elegir una de las rutas de nombre o solicitar otra iteración |
| Premisa, fantasía central y pilares | **Propuesta de diseño pendiente de aprobación** | Aprobar o pedir ajustes |
| Cantidad de mundos y conjunto inicial de mecánicas | **Propuesta pendiente de aprobación** | Aprobar antes de ampliar producción de niveles y assets |

### Nombres del juego, protagonista y universo

- **Juego — confirmado:** **Tipapita-Adventure**. Debe escribirse exactamente con
  guion en documentación, portada, pantalla de título y materiales públicos.
- **Protagonista — confirmado:** **Chiquito**.
- **Universo — pendiente:** se proponen **Las Tierras Pipapita** (recomendado),
  **Pipatierras** o **El Mundo de Pipapa**. Ninguno está aprobado todavía.

La confirmación del título no resuelve por sí sola la grafía interna de la familia
y las criaturas. Hasta recibir una decisión específica, el canon conserva
**Pipapita** como normalización provisional y el título conserva **Tipapita**.
El nombre técnico de la ROM y archivos puede seguir siendo `chiquito`; cambiarlo
no es necesario para reflejar el título comercial.

### Premisa narrativa breve

Chiquito, el más pequeño y valiente de una familia de chihuahuas agricultores,
explora las montañas que rodean su hogar, descubre sus secretos y reúne materiales
para que el inventor Sanchopau construya el camino hacia su familia, que vive en
tierras lejanas del mismo mundo. En el viaje comprenderá que criaturas temidas,
como Pipapita Mothman, también pueden ser guardianes y aliados.

Esta premisa respeta el canon confirmado: Mothman no es el antagonista principal,
los Pipapitas extraterrestres no son todos enemigos y la familia de Sanchopau no
vive en otro planeta.

### Fantasía central del jugador

**Ser un héroe diminuto pero extraordinario que convierte curiosidad, valentía y
ayuda a los demás en nuevas rutas para explorar un mundo mucho más grande que él.**

En términos jugables: recorrer lugares llenos de secretos con un personaje pequeño
y ágil, volver con materiales significativos, ver a Sanchopau transformarlos en
inventos y usar esos inventos para llegar cada vez más lejos.

### Pilares de experiencia

1. **Pequeño cuerpo, gran aventura.** Movimiento ágil, salto preciso, animaciones
   expresivas y obstáculos que hacen sentir valiente a Chiquito sin volverlo un
   héroe genérico.
2. **Explorar siempre recompensa.** Rutas opcionales, secretos legibles y materiales
   colocados con intención; explorar debe producir descubrimientos, no relleno.
3. **Recolectar para construir.** Los materiales alimentan avances concretos en el
   taller de Sanchopau y abren capacidades o caminos, en vez de existir solo como
   puntuación.
4. **Hogar, amistad y asombro.** La familia es el ancla emocional; ayudar y conocer
   criaturas importa tanto como combatir. El misterio se revela gradualmente y no
   toda criatura extraña es enemiga.
5. **Claridad de aventura 8-bit.** Siluetas, controles, peligros y recompensas deben
   leerse con rapidez en hardware NES real; la personalidad nace de decisiones
   simples y consistentes, no de sobrecargar la pantalla.

### Alcance inicial propuesto

#### Dirección de diseño y arte: referencia Kirby y elenco propio

**Dirección solicitada el 2026-11-12:** estudiar lo que hace memorable a
*Kirby's Adventure* de NES y aspirar a sprites vistosos basados en las imágenes de
`pipapitas_codex_completo/referencias/`. Esta dirección no aprueba por sí sola
una cantidad de mundos, habilidades o assets finales.

Propuestas para llevar esa referencia a la identidad de Chiquito:

- **Movimiento placentero y accesible:** caminar y saltar deben responder con
  claridad; introducir obstáculos de forma segura antes de combinarlos. El reto
  opcional puede recompensar a quien explore sin bloquear la ruta principal.
- **Sorpresa y variedad:** alternar exteriores, interiores y encuentros breves;
  cada tramo presenta una idea reconocible y luego juega con ella. Ocultar rutas
  y recompensas que inviten a volver sin exigir recorrer niveles vacíos.
- **Habilidades con personalidad:** estudiar cómo Kirby ofrece formas distintas
  de interactuar con el nivel y proponer capacidades propias ligadas a Chiquito y
  los inventos de Sanchopau. No se aprueba todavía un sistema de copia ni una
  cantidad adicional de habilidades; validar primero una mejora en el corte vertical.
- **Carisma audiovisual:** poses expresivas, reacciones visibles, enemigos con
  comportamientos reconocibles y música que distinga lugares y momentos. Diseñar
  encuentros memorables, incluidas pruebas de guardianes que no exijan vencerlos.
- **Mundo acogedor con misterio:** combinar humor y colores vivos con cuevas,
  leyendas y descubrimientos, manteniendo a la familia como centro emocional.

La habilidad de copiar poderes es una referencia distintiva de Kirby, documentada
por [Nintendo](https://www.nintendo.com/en-gb/Games/NES/Kirby-s-Adventure-277754.html).
La aplicación anterior es una propuesta propia, no una lista de mecánicas aprobadas.

Para los sprites, usar como guía principal `referencias/estilo/referencia_usuario_chihuahua_sombrero_turquesa.jpg`
y `referencias/personajes/chiquito_concepto_02_turquesa.png`; contrastar el elenco
con `referencias/estilo/elenco_estilo_turquesa.png` y los conceptos individuales
de Sanchopau, Mothman y los marcianitos. Traducir sus siluetas, expresiones y
rasgos distintivos a pixel art NES original; las imágenes son conceptos, no hojas
de sprites listas para importar. Probar Chiquito a tamaño nativo con poses de reposo,
caminar, salto y reacción, junto a fondo y otros personajes. Validar paletas, tiles,
memoria y límite de sprites por línea en escenas reales antes de aprobar tamaños o
densidad; la caja 16×16 actual es punto de partida, no límite artístico definitivo.

#### Corte vertical para validar identidad

- **Una región:** Montañas Pipapita.
- **Áreas:** Casa y maizal, pradera/bosque, cueva o santuario de montaña y taller de
  Sanchopau como punto de retorno.
- **Duración objetivo:** 10–15 minutos para una primera partida completa.
- **Encuentro narrativo:** una aparición o prueba de Mothman como guardián, no como
  villano final.
- **Reparto mínimo:** Chiquito, Sanchopau, un familiar o la Abuelita, Mothman, una
  familia de enemigos simples y una criatura neutral.
- **Bucle completo:** explorar → obtener materiales → regresar al taller → construir
  una mejora → abrir una ruta antes inaccesible → superar la prueba final.

#### Juego base inicial

- **Tres mundos compactos**, con tres niveles principales por mundo y el taller de
  Sanchopau como hub: 1) Hogar y Campos de la Montaña, 2) Bosque, Cuevas y Cumbres
  Antiguas, 3) Ruta hacia las Tierras Lejanas.
- Los Pipapitas marcianitos aparecen como encuentros dentro de esos mundos. Una
  región espacial completa queda fuera del alcance inicial.
- Cada mundo culmina en una prueba o encuentro propio. Mothman puede cerrar el
  segundo mundo como guardián, pero no debe presentarse como malvado.
- La reunión con la familia de Sanchopau es la meta narrativa del juego base; las
  regiones adicionales quedan reservadas para una expansión solo si el juego base
  se completa y valida.

#### Mecánicas incluidas

- Caminar/correr, salto de altura variable, caída, aterrizaje y daño con retroceso.
- Ataque básico de corto alcance, interacción contextual y lectura clara de estados.
- Exploración lateral, habitaciones, puertas, interruptores, plataformas móviles,
  puntos de control, paredes o rutas secretas y transiciones entre áreas.
- Recolección de un conjunto pequeño de materiales con propósito conocido.
- Taller de Sanchopau con **tres mejoras máximas** para el juego base; cada mejora
  abre rutas o modifica una capacidad concreta.
- Enemigos con comportamientos diferenciados, criaturas neutrales y encuentros de
  guardián que no dependan siempre del combate.
- HUD mínimo: vida, material relevante y progreso de la mejora activa.

#### Fuera del alcance inicial

- Mundo abierto continuo, generación procedural, cooperativo o multijugador.
- Sistema de fabricación libre con recetas, inventario RPG extenso o árbol de
  habilidades.
- Vehículos con física y control completos. Las avionetas o naves pueden aparecer
  como recompensa narrativa, transición o secuencia acotada antes de evaluarlas
  como mecánica jugable.
- Un planeta extraterrestre, múltiples campañas, finales ramificados o plantel
  completo de personajes jugables.

### Aprobaciones pendientes para cerrar F0.3

- [x] Aprobar el título **Tipapita-Adventure**. *(Confirmado expresamente el 2026-11-11.)*
- [ ] Aprobar un nombre para el universo o solicitar una nueva ronda de nombres.
- [ ] Confirmar que **Pipapita** es la grafía definitiva frente a **Tipapita**.
- [ ] Aprobar o ajustar la premisa, la fantasía central y los cinco pilares.
- [ ] Aprobar o ajustar el corte vertical de una región.
- [ ] Aprobar o ajustar el juego base de tres mundos y las mecánicas incluidas.

Hasta completar esta lista, F0.3 permanece **en progreso**. Sí se pueden producir
pruebas técnicas y bocetos reversibles de Chiquito, pero no logotipos finales,
mapas definitivos de todos los mundos ni un volumen de assets que presuponga que
el alcance propuesto ya fue aprobado.

# 2. DIRECCIÓN ARTÍSTICA

El juego debe transmitir alegría, aventura, curiosidad y descubrimiento.

Características visuales:

- Pixel art detallado y limpio.
- Colores alegres y contrastantes.
- Cielos azules y nubes animadas.
- Vegetación variada.
- Árboles, flores y montañas.
- Cascadas y agua animada.
- Escenarios con profundidad visual.
- Personajes expresivos.
- Animaciones reconocibles.
- Efectos visuales para poderes, impactos y recompensas.

Evitar escenarios monótonos, repetitivos o excesivamente oscuros.

## Paleta conceptual

Utilizar como referencia:

- Azul celeste.
- Verde brillante.
- Verde bosque.
- Amarillo dorado.
- Naranja cálido.
- Rojo coral.
- Rosa.
- Violeta.
- Turquesa.
- Blanco.

IMPORTANTE: los colores deben adaptarse a las restricciones de la paleta física de NES. No utilizar RGB arbitrario como si la PPU permitiera colores libres.

Diseñar paletas independientes para:
- Personajes.
- Enemigos.
- Escenarios.
- Efectos especiales.
- Interfaces.

# 3. DISEÑO DEL PERSONAJE PRINCIPAL

Crear un protagonista original, fácilmente reconocible y con personalidad.

Debe contar con:

- Animación de espera.
- Caminar.
- Correr.
- Saltar.
- Caer.
- Aterrizar.
- Atacar.
- Recibir daño.
- Morir.
- Celebrar.
- Utilizar poderes.

El personaje debe tener una silueta reconocible incluso cuando se visualiza a pequeña escala.

Implementar una máquina de estados para administrar sus comportamientos.

# 4. SISTEMA DE MOVIMIENTO

Implementar:

- Movimiento horizontal.
- Aceleración.
- Desaceleración.
- Velocidad máxima.
- Gravedad.
- Salto.
- Altura de salto variable.
- Detección de suelo.
- Detección de paredes.
- Colisiones con plataformas.
- Daño y retroceso.
- Invulnerabilidad temporal.

Utilizar aritmética de punto fijo para las posiciones y velocidades.

Separar las físicas de la lógica de animación.

El movimiento debe sentirse preciso, consistente y agradable.

# 5. SISTEMA DE NIVELES

Crear un sistema de mapas basado en tiles.

Implementar:

- Metatiles.
- Mapas de niveles.
- Colisiones independientes de los gráficos.
- Plataformas estáticas.
- Plataformas móviles.
- Obstáculos.
- Puertas.
- Interruptores.
- Secretos.
- Zonas ocultas.
- Objetos coleccionables.
- Puntos de control.

Los niveles deben diseñarse con variedad y progresión de dificultad.

# 6. CÁMARA Y SCROLLING

Implementar:

- Scrolling horizontal.
- Scrolling vertical cuando corresponda.
- Cámara que sigue al protagonista.
- Límites de cámara.
- Transiciones entre habitaciones.
- Carga de nuevos sectores del mapa.
- Gestión de nametables.
- Actualización controlada de VRAM.

No actualizar directamente la VRAM durante el renderizado normal.

Las transferencias deben organizarse mediante colas de actualización y ejecutarse dentro de los períodos seguros de VBlank.

# 7. SISTEMA DE ENEMIGOS

Crear diferentes familias de enemigos.

Comportamientos:

- Patrullaje.
- Persecución.
- Saltos.
- Ataques.
- Disparos.
- Defensa.
- Huida.
- Aparición por zonas.
- Desaparición fuera de rango.

Cada enemigo debe implementar una máquina de estados.

Evitar utilizar un único comportamiento para todos los enemigos.

# 8. JEFES

Crear jefes originales con:

- Presentación de combate.
- Barra de energía.
- Diferentes patrones de ataque.
- Ventanas de vulnerabilidad.
- Cambios de comportamiento.
- Animaciones de daño.
- Animación de derrota.
- Recompensa.

Cada jefe debe tener una mecánica propia y ser reconocible.

# 9. SISTEMA DE POWER-UPS

Implementar poderes originales que modifiquen las capacidades del protagonista.

Ejemplos:

- Aumento temporal de velocidad.
- Salto mejorado.
- Escudo.
- Proyectiles.
- Ataque especial.
- Transformación temporal.
- Habilidad para acceder a rutas secretas.

Los poderes deben estar limitados por el hardware y contar con animaciones y efectos diferenciados.

# 10. AUDIO

Utilizar los cinco canales principales del APU de NES:

- Pulse 1.
- Pulse 2.
- Triangle.
- Noise.
- DMC.

Implementar:

- Música de niveles.
- Música de jefes.
- Música de menú.
- Efectos de salto.
- Recolección de objetos.
- Impactos.
- Ataques.
- Cambios de escenario.
- Victoria y derrota.

Crear composiciones originales.

Implementar un sistema de prioridades para que los efectos de sonido no destruyan innecesariamente la música.

# 11. ARQUITECTURA DEL SOFTWARE

Organizar el proyecto por responsabilidades.

Estructura propuesta:

```text
nes-adventure/
│
├── README.md
├── GAME_DESIGN_DOCUMENT.md
├── ARCHITECTURE.md
├── TECHNICAL_CONSTRAINTS.md
├── DEVELOPMENT_LOG.md
│
├── src/
│   ├── main.s
│   ├── reset.s
│   ├── interrupts.s
│   ├── ppu.s
│   ├── controller.s
│   ├── sprites.s
│   ├── player.s
│   ├── physics.s
│   ├── collision.s
│   ├── camera.s
│   ├── scrolling.s
│   ├── enemies.s
│   ├── bosses.s
│   ├── powerups.s
│   ├── levels.s
│   ├── audio.s
│   └── memory.s
│
├── assets/
│   ├── characters/
│   ├── enemies/
│   ├── tiles/
│   ├── backgrounds/
│   ├── palettes/
│   ├── maps/
│   └── music/
│
├── tools/
│   ├── map_converter/
│   └── asset_validation/
│
├── tests/
│   ├── physics/
│   ├── collision/
│   └── memory/
│
└── build/
    └── game.nes
```

La estructura podrá ajustarse según las necesidades reales del proyecto.

# 12. HERRAMIENTAS

Utilizar:

- ca65 / ld65 para ensamblador y enlazado.
- CC65 si resulta útil para componentes escritos en C.
- Mesen para depuración.
- FCEUX como emulador complementario.
- YY-CHR para gráficos.
- Tiled para diseño de mapas.
- Herramientas de conversión de assets a formatos compatibles con NES.

El proceso de compilación debe ser reproducible mediante scripts.

# 13. RESTRICCIONES DE HARDWARE

Codex debe respetar obligatoriamente:

- 2 KB de RAM interna.
- 256 bytes de OAM.
- 64 sprites disponibles.
- Máximo de 8 sprites por scanline.
- Tiles de 8×8.
- Resolución de 256×240.
- Limitaciones de las paletas de fondo y sprites.
- Presupuesto de ciclos de CPU.
- Presupuesto de VBlank.
- Acceso controlado a la VRAM.
- Capacidad y distribución de memoria del mapper elegido.

No simular capacidades inexistentes en el hardware.

No utilizar características de consolas posteriores.

# 14. OPTIMIZACIÓN

Implementar:

- Tablas de consulta.
- Aritmética de punto fijo.
- Uso eficiente de Zero Page.
- Reducción de operaciones costosas.
- Compresión de mapas cuando sea conveniente.
- Administración de bancos.
- Actualizaciones parciales de escenarios.
- Reutilización de gráficos.
- Control de sprites por scanline.

Evitar cálculos innecesarios dentro del ciclo principal.

# 15. METODOLOGÍA DE DESARROLLO

No desarrollar todo el juego de una sola vez.

Dividir el trabajo en entregas funcionales.

FASE 1: Infraestructura
- Configuración del compilador.
- Configuración del mapper.
- ROM inicial.
- Inicialización CPU y PPU.
- Prueba de compilación y ejecución.

FASE 2: Gráficos
- Paletas.
- Tiles.
- Sprites.
- Escenario inicial.
- Animaciones.

FASE 3: Personaje
- Movimiento.
- Física.
- Salto.
- Colisiones.
- Animaciones.

FASE 4: Escenarios
- Mapas.
- Cámara.
- Scrolling.
- Plataformas.
- Objetos.

FASE 5: Enemigos
- IA.
- Ataques.
- Colisiones.
- Proyectiles.

FASE 6: Sistemas de juego
- Power-ups.
- Jefes.
- Vidas.
- Puntuación.
- Menús.

FASE 7: Audio
- Música.
- Efectos.
- Secuenciador.

FASE 8: Optimización
- Rendimiento.
- Memoria.
- Ciclos.
- Sprites.
- Compatibilidad.

FASE 9: Juego completo
- Diseño de mundos.
- Niveles.
- Dificultad.
- Pantallas finales.
- Pruebas.

# 16. CRITERIOS DE CALIDAD

El juego debe cumplir:

1. Compilar sin errores.
2. Generar una ROM válida.
3. Ejecutarse en Mesen.
4. Permitir controlar al personaje.
5. No presentar corrupción gráfica.
6. No presentar glitches de scrolling.
7. No exceder los límites de hardware.
8. Tener animaciones fluidas.
9. Tener colisiones consistentes.
10. Mantener una identidad visual coherente.
11. Contar con música y efectos originales.
12. Tener niveles terminables y jugables.

# 17. INSTRUCCIONES PARA CODEX

Actúa como ingeniero especializado en desarrollo de videojuegos para Nintendo Entertainment System.

Tu responsabilidad es construir un juego real y funcional, no solamente generar una demostración visual o un prototipo conceptual.

Antes de implementar:

- Analiza el repositorio.
- Verifica las herramientas disponibles.
- Define la arquitectura.
- Identifica las restricciones de hardware.
- Documenta las decisiones técnicas.

Durante el desarrollo:

- Implementa módulos pequeños.
- Compila después de cada etapa.
- Ejecuta pruebas en emulador.
- Comprueba las limitaciones de CPU, PPU y memoria.
- Mantén documentación actualizada.
- No inventes resultados de pruebas.
- No dejes módulos críticos como simples placeholders.
- No declares una fase terminada si no se puede verificar.

Cuando exista una decisión técnica pendiente, presenta las alternativas y sus consecuencias.

Prioriza código mantenible, modular y verificable.

El resultado final debe ser un videojuego original de NES, con identidad propia, escenarios coloridos, controles precisos, música memorable y una experiencia de aventura comparable en calidad de diseño a los grandes clásicos de 8 bits.
