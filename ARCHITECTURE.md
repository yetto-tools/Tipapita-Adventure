# ARCHITECTURE
## Arquitectura técnica de Chiquito y los Pipapitas

## 1. Plataforma

Objetivo: Nintendo Entertainment System.

Hardware de referencia:

- CPU Ricoh 2A03/2A07.
- PPU 2C02/2C07.
- Resolución de referencia: 256 × 240.
- RAM interna: 2 KB.
- OAM: 64 sprites.
- APU integrada.

## 2. Herramientas propuestas

- ca65: ensamblador.
- ld65: linker.
- Mesen: emulación y depuración.
- FCEUX: pruebas complementarias.
- Python: herramientas auxiliares para generar recursos.

Estas herramientas son propuestas iniciales, sujetas a validación al configurar el entorno.

## 3. Arquitectura lógica

Separar el proyecto en:

### Hardware
Acceso a CPU, PPU, APU, controladores e interrupciones.

### Motor
- Sistema de escenas.
- Cámara.
- Colisiones.
- Física.
- Animación.
- Gestión de sprites.
- Gestión de mapas.

### Juego
- Jugador.
- Enemigos.
- Personajes.
- Objetos.
- Misiones.
- Inventario.
- Progresión.

### Datos
- Mapas.
- Tilesets.
- Paletas.
- Diálogos.
- Configuración de niveles.

## 4. Módulos

Estructura propuesta:

```text
src/
├── main.s
├── hardware/
│   ├── ppu.s
│   ├── apu.s
│   ├── controller.s
│   └── interrupts.s
├── engine/
│   ├── scene.s
│   ├── camera.s
│   ├── physics.s
│   ├── collision.s
│   ├── sprites.s
│   └── map.s
├── game/
│   ├── player.s
│   ├── enemies.s
│   ├── items.s
│   ├── inventory.s
│   ├── missions.s
│   └── progression.s
└── data/
    ├── levels/
    ├── characters/
    ├── tilesets/
    └── dialogue/
```

## 5. Jugador

Chiquito debe utilizar:

- Coordenadas de posición.
- Velocidad horizontal.
- Velocidad vertical.
- Estado de movimiento.
- Estado de animación.
- Puntos de colisión.
- Estado de vida.
- Habilidades desbloqueadas.

Se recomienda utilizar aritmética de punto fijo para la física.

## 6. Cámara

El juego combinará:

- Desplazamiento horizontal.
- Escenarios con scrolling.
- Habitaciones independientes.
- Transiciones entre regiones.

La implementación debe respetar el mapper y la configuración de memoria seleccionados.

## 7. Sistema de objetos

Los objetos se clasifican en:

- Materiales naturales.
- Componentes mecánicos.
- Coleccionables.
- Objetos de misión.
- Mejoras.

Los materiales recolectados podrán utilizarse en el taller de Sanchopau.

## 8. Progresión tecnológica

La progresión se divide en etapas:

1. Herramientas básicas.
2. Mecanismos sencillos.
3. Vehículos terrestres.
4. Avionetas.
5. Tecnología avanzada.
6. Vehículo para llegar a tierras lejanas.

## 9. Mapper

MMC3 es una opción a evaluar por sus capacidades de bancos de memoria y soporte de IRQ.

No debe considerarse una decisión definitiva hasta evaluar:

- Tamaño de ROM.
- Cantidad de niveles.
- Organización gráfica.
- Necesidades de scrolling.
- Compatibilidad de emuladores y hardware.

## 10. Rendimiento

Prioridades:

- Mantener la lógica dentro del tiempo disponible por frame.
- Actualizar PPU durante ventanas seguras.
- Utilizar DMA para OAM cuando corresponda.
- Evitar escrituras incorrectas durante renderizado.
- Controlar la cantidad de sprites por scanline.
- Medir el rendimiento en emulador.

## 11. Pruebas

Cada módulo debe tener pruebas funcionales.

Validar:

- Movimiento.
- Colisiones.
- Cámara.
- Transiciones.
- Lectura de controles.
- Actualización de sprites.
- Recolección.
- Guardado, si se implementa.
- Compatibilidad de la ROM.