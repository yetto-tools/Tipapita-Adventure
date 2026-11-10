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

.PHONY: all rom check clean run

all: rom

rom: $(ROM)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OBJ): $(SRC_DIR)/main.s | $(BUILD_DIR)
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
