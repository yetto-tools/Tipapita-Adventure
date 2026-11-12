CA65    := ca65
LD65    := ld65
PYTHON  := python3

SRC_DIR    := src
BUILD_DIR  := dist
LINKER_CFG := linker/chiquito.cfg

ROM := $(BUILD_DIR)/chiquito.nes
OBJ := $(BUILD_DIR)/main.o
MAP := $(BUILD_DIR)/chiquito.map
LST := $(BUILD_DIR)/main.lst

# Datos generados a partir de assets fuente: tiles desde PNG (F2.2), y las
# escenas compiladas desde mapas de texto externos (F4.1,
# assets/maps/*.txt) + la definición de metatiles. main.s los incluye
# desde $(BUILD_DIR), así que deben existir antes de ensamblar.
# F4.3: dos mapas (el nivel de scroll "pradera" y la habitación fija
# "casa_pipapita"), cada uno con su propio prefijo de símbolo (--label)
# para que coexistan en el mismo binario sin colisionar nombres.
TILES_PRADERA := $(BUILD_DIR)/tiles_pradera.s
SCENE_PRADERA := $(BUILD_DIR)/scene_pradera.s
MAP_PRADERA   := assets/maps/pradera.txt
SCENE_CASA    := $(BUILD_DIR)/scene_casa.s
MAP_CASA      := assets/maps/casa_pipapita.txt
TILES_SCENERY := $(BUILD_DIR)/tiles_scenery.s
TILES_CHIQUITO       := $(BUILD_DIR)/tiles_chiquito.s
CHIQUITO_POSE_TABLES := $(BUILD_DIR)/chiquito_pose_tables.s
CHIQUITO_POSES := chiquito chiquito_caminar_1 chiquito_caminar_2 chiquito_correr chiquito_saltar
CHIQUITO_POSE_FILES := $(foreach p,$(CHIQUITO_POSES),assets/sprites/nes_referencias/$(p).chr assets/sprites/nes_referencias/$(p).json)
TILES_CAST    := $(BUILD_DIR)/tiles_cast.s
FCEUX_TEST := xvfb-run -a -s "-screen 0 256x240x24" env SDL_AUDIODRIVER=dummy fceux
FCEUX_TESTS := init nmi palette tiles sprites controller movement collision state_machine scrolling rooms scenery entities npc enemies

.PHONY: all rom check test clean run

all: rom

rom: $(ROM)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(TILES_PRADERA): assets/tiles/montanas_v2.png tools/png2chr.py | $(BUILD_DIR)
	$(PYTHON) tools/png2chr.py assets/tiles/montanas_v2.png $(TILES_PRADERA) --label tiles_pradera

$(SCENE_PRADERA): $(MAP_PRADERA) tools/map2scene.py | $(BUILD_DIR)
	$(PYTHON) tools/map2scene.py $(MAP_PRADERA) $(SCENE_PRADERA) --label scene_pradera

$(SCENE_CASA): $(MAP_CASA) tools/map2scene.py | $(BUILD_DIR)
	$(PYTHON) tools/map2scene.py $(MAP_CASA) $(SCENE_CASA) --label scene_casa

# F5.1c: Chiquito (protagonista) con sus 5 poses reales (conversión
# fiel del concept art, no un redibujo a mano -- ver TASKS.md sobre por
# qué chiquito_v2.png/gen_chiquito_sprites.py se abandonaron). Una sola
# invocación produce los 2 archivos (tiles + tablas de pose/paleta por
# tile); el patrón de "targets agrupados" es necesario porque Make no
# sabe de otra forma que ambos salen de la misma receta.
$(TILES_CHIQUITO) $(CHIQUITO_POSE_TABLES): $(CHIQUITO_POSE_FILES) tools/gen_chiquito_poses.py | $(BUILD_DIR)
	$(PYTHON) tools/gen_chiquito_poses.py

# F2.3/F4.4: enemigo/ítem/plataforma de prueba, separados de Chiquito
# (antes compartían PNG con las 4 poses dibujadas a mano de Chiquito).
$(TILES_SCENERY): assets/sprites/scenery_v1.png tools/png2chr.py | $(BUILD_DIR)
	$(PYTHON) tools/png2chr.py assets/sprites/scenery_v1.png $(TILES_SCENERY) --label tiles_scenery

# F5.1b: solo Sanchopau por ahora (ver la nota junto al .include de
# tiles_cast.s en src/main.s sobre por qué el resto del elenco no se
# incluye todavía). CHR fiel desde la conversión real del concept art
# (tools/convert_reference_sprites.py), NO desde un redibujo a mano --
# ver el registro de la tarea en TASKS.md sobre por qué se abandonó el
# redibujo manual (gen_cast_sprites.py queda como herramienta, sin uso
# en el build real por ahora).
$(TILES_CAST): assets/sprites/nes_referencias/sanchopau.chr tools/chr2asm.py | $(BUILD_DIR)
	$(PYTHON) tools/chr2asm.py assets/sprites/nes_referencias/sanchopau.chr $(TILES_CAST) --label tiles_cast

$(OBJ): $(SRC_DIR)/main.s $(TILES_PRADERA) $(SCENE_PRADERA) $(SCENE_CASA) $(TILES_CHIQUITO) $(CHIQUITO_POSE_TABLES) $(TILES_SCENERY) $(TILES_CAST) | $(BUILD_DIR)
	$(CA65) -g -l $(LST) -o $(OBJ) $(SRC_DIR)/main.s

$(ROM): $(OBJ) $(LINKER_CFG)
	$(LD65) -C $(LINKER_CFG) -m $(MAP) -o $(ROM) $(OBJ)
	$(PYTHON) tools/validate_rom.py $(ROM)

check: $(ROM)
	$(PYTHON) tools/validate_rom.py $(ROM)

# Pruebas automatizadas sin ventana visible: Xvfb provee una pantalla virtual
# y SDL_AUDIODRIVER=dummy evita requerir un dispositivo de audio en WSL.
test: $(ROM)
	@set -e; for test_name in $(FCEUX_TESTS); do \
		echo "== FCEUX: $$test_name =="; \
		$(FCEUX_TEST) --loadlua tools/test_$$test_name.lua $(ROM) > /tmp/fceux_$$test_name.log 2>&1 || { cat /tmp/fceux_$$test_name.log; exit 1; }; \
		grep -q '^RESULT=PASS$$' /tmp/fceux_test_$$test_name.txt || { cat /tmp/fceux_test_$$test_name.txt; exit 1; }; \
	done
	$(PYTHON) tools/test_map2scene.py

run: $(ROM)
	fceux $(ROM)

clean:
	rm -rf $(BUILD_DIR)
