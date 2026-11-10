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

# Datos generados a partir de assets fuente (F2.2): tiles desde PNG, y la
# escena de prueba compilada desde la definición de metatiles. main.s los
# incluye desde $(BUILD_DIR), así que deben existir antes de ensamblar.
TILES_PRADERA := $(BUILD_DIR)/tiles_pradera.s
SCENE_PRADERA := $(BUILD_DIR)/scene_pradera.s
TILES_SPRITES := $(BUILD_DIR)/tiles_sprites.s

.PHONY: all rom check clean run

all: rom

rom: $(ROM)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(TILES_PRADERA): assets/tiles/pradera.png tools/png2chr.py | $(BUILD_DIR)
	$(PYTHON) tools/png2chr.py assets/tiles/pradera.png $(TILES_PRADERA) --label tiles_pradera

$(SCENE_PRADERA): tools/build_scene.py | $(BUILD_DIR)
	$(PYTHON) tools/build_scene.py $(SCENE_PRADERA)

$(TILES_SPRITES): assets/sprites/chiquito_test.png tools/png2chr.py | $(BUILD_DIR)
	$(PYTHON) tools/png2chr.py assets/sprites/chiquito_test.png $(TILES_SPRITES) --label tiles_sprites

$(OBJ): $(SRC_DIR)/main.s $(TILES_PRADERA) $(SCENE_PRADERA) $(TILES_SPRITES) | $(BUILD_DIR)
	$(CA65) -g -l $(LST) -o $(OBJ) $(SRC_DIR)/main.s

$(ROM): $(OBJ) $(LINKER_CFG)
	$(LD65) -C $(LINKER_CFG) -m $(MAP) -o $(ROM) $(OBJ)
	$(PYTHON) tools/validate_rom.py $(ROM)

check: $(ROM)
	$(PYTHON) tools/validate_rom.py $(ROM)

run: $(ROM)
	fceux $(ROM)

clean:
	rm -rf $(BUILD_DIR)
