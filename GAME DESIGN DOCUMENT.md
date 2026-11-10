# GAME DESIGN DOCUMENT
## Proyecto: Aventura clásica para Nintendo Entertainment System

**Versión:** 1.0  
**Plataforma:** NES / Famicom  
**Tipo:** Plataformas, aventura y acción 2D  
**Resolución:** 256 × 240 píxeles  
**Arquitectura:** Ricoh 2A03 / 6502  
**Mapper objetivo inicial:** MMC3 (Mapper 4)  
**Compilación:** ROM `.nes`

---

# 1. VISIÓN DEL PROYECTO

Desarrollar un videojuego original para Nintendo Entertainment System que recupere la diversión, creatividad, exploración y personalidad de los grandes juegos de plataformas de 8 bits.

Referencias de diseño:

- Super Mario Bros. 3: exploración, mapas, mundos, secretos, power-ups y escenarios.
- Ninja Gaiden: acción, movilidad, combate y ritmo.
- Mega Man 3: armas, enemigos, jefes, patrones y variedad de niveles.

No copiar personajes, nombres, música, escenarios, sprites ni recursos protegidos de estos juegos.

Crear una identidad artística y mecánica completamente original.

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
