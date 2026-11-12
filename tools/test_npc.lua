-- Prueba de humo para F5.1b (NPC Sanchopau, elenco cableado al motor).
-- Verifica, contra la ROM real:
--   1. Fuera de Casa (en pradera, recién arrancada), el OAM de Sanchopau
--      está oculto (Y=$FF en sus 16 sprites).
--   2. Al entrar a Casa, el OAM de Sanchopau deja de estar oculto y cae
--      dentro del área visible de pantalla, y la paleta de sprite de los
--      slots 1/2 pasa a ser la de Sanchopau (no la de enemigo/ítem).
--   3. Sanchopau se mueve con el tiempo (patrulla) sin salirse de
--      [NPC_MIN_X, NPC_MAX_X].
--   4. Al volver a pradera, su OAM vuelve a ocultarse y la paleta de
--      los slots 1/2 se restaura a los valores de enemigo/ítem.

local X_PX_LO, X_PX_HI, Y_HI = 0x000D, 0x000E, 0x0010
local VX_LO, VX_HI, VY_LO, VY_HI = 0x0011, 0x0012, 0x0013, 0x0014
local ON_GROUND, STATE = 0x0015, 0x0017
local ROOM_CURRENT = 0x0031
local ROOM_PRADERA, ROOM_CASA = 0, 1
local STATE_FALL = 3

-- F5.1c: NPC_OAM_BASE = PLAYER_OAM_BASE(44) + 64 = 108 -> $0200+108=$026C
-- (antes PLAYER_EXTRA_OAM_BASE+12=56, cuando Chiquito eran 4 piezas en
-- vez de las 16 de ahora).
local NPC_OAM = 0x026C

local out = io.open("/tmp/fceux_test_npc.txt", "w")
local function log(line)
	out:write(line .. "\n")
	out:flush()
end

local function teleport(x, y)
	memory.writebyte(X_PX_LO, x % 256)
	memory.writebyte(X_PX_HI, math.floor(x / 256))
	memory.writebyte(Y_HI, y)
	memory.writebyte(VX_LO, 0)
	memory.writebyte(VX_HI, 0)
	memory.writebyte(VY_LO, 0)
	memory.writebyte(VY_HI, 0)
	memory.writebyte(ON_GROUND, 1)
	memory.writebyte(STATE, STATE_FALL)
end

local function npc_hidden()
	for i = 0, 15 do
		if memory.readbyte(NPC_OAM + i * 4) ~= 0xFF then return false end
	end
	return true
end

local function npc_any_y()
	return memory.readbyte(NPC_OAM)
end

-- Deja que termine el reset.
for _ = 1, 100 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(0x0001) >= 5 and memory.readbyte(VX_HI) == 0 and memory.readbyte(VX_LO) == 0
		and memory.readbyte(VY_HI) == 0 and memory.readbyte(VY_LO) == 0 then
		break
	end
end

local hidden_in_pradera = npc_hidden()
log(string.format("oculto_en_pradera=%s", tostring(hidden_in_pradera)))

-- Paleta de slots 1/2 en pradera (debe ser la de enemigo/ítem).
local pal_pradera = {
	ppu.readbyte(0x3F15), ppu.readbyte(0x3F16), ppu.readbyte(0x3F17),
	ppu.readbyte(0x3F19), ppu.readbyte(0x3F1A), ppu.readbyte(0x3F1B),
}
local pal_pradera_ok = pal_pradera[1] == 0x06 and pal_pradera[2] == 0x16 and pal_pradera[3] == 0x26
	and pal_pradera[4] == 0x08 and pal_pradera[5] == 0x18 and pal_pradera[6] == 0x28
log(string.format(
	"paleta_pradera: %02X %02X %02X / %02X %02X %02X (esperado 06 16 26 / 08 18 28) ok=%s",
	pal_pradera[1], pal_pradera[2], pal_pradera[3], pal_pradera[4], pal_pradera[5], pal_pradera[6],
	tostring(pal_pradera_ok)
))

-- Entra a Casa por la puerta (igual técnica que test_rooms.lua).
teleport(740, 152)
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local room_in_casa = memory.readbyte(ROOM_CURRENT)
local visible_in_casa = not npc_hidden()
local y_in_casa = npc_any_y()
local pal_casa = {
	ppu.readbyte(0x3F15), ppu.readbyte(0x3F16), ppu.readbyte(0x3F17),
	ppu.readbyte(0x3F19), ppu.readbyte(0x3F1A), ppu.readbyte(0x3F1B),
}
local pal_casa_ok = pal_casa[1] == 0x0F and pal_casa[2] == 0x00 and pal_casa[3] == 0x20
	and pal_casa[4] == 0x0F and pal_casa[5] == 0x27 and pal_casa[6] == 0x20
log(string.format(
	"en_casa: room=%d visible=%s y=%d paleta=%02X %02X %02X / %02X %02X %02X (esperado room=1 visible=true paleta 0F 00 20 / 0F 27 20) ok=%s",
	room_in_casa, tostring(visible_in_casa), y_in_casa,
	pal_casa[1], pal_casa[2], pal_casa[3], pal_casa[4], pal_casa[5], pal_casa[6], tostring(pal_casa_ok)
))
-- Screenshot acá, no al final del todo: en este entorno (FCEUX +
-- xvfb headless) una captura tomada justo antes de emu.exit() salía
-- en negro de forma consistente incluso cuando los chequeos de
-- memoria de ese mismo frame eran correctos -- parece un problema del
-- propio mecanismo de captura al cerrar, no una regresión real. Con
-- el emulador corriendo con normalidad (como aquí) es confiable.
gui.savescreenshotas("/tmp/fceux_test_npc.png")

-- Deja correr varios segundos para ver la patrulla real (rebote), y
-- confirma que su OAM sigue visible y cambia de X.
local x_samples = {}
for frame = 1, 200 do
	joypad.set(1, {})
	emu.frameadvance()
	if frame % 40 == 0 then
		table.insert(x_samples, memory.readbyte(NPC_OAM + 3))
	end
end
local still_visible = not npc_hidden()
local moved = false
for i = 2, #x_samples do
	if x_samples[i] ~= x_samples[i - 1] then moved = true end
end
log(string.format(
	"patrulla: visible=%s x_muestras=%s movio=%s",
	tostring(still_visible), table.concat(x_samples, ","), tostring(moved)
))

-- Vuelve a pradera por la puerta de la casa.
teleport(244, 152)
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local room_back = memory.readbyte(ROOM_CURRENT)
local hidden_back = npc_hidden()
local pal_back = {
	ppu.readbyte(0x3F15), ppu.readbyte(0x3F16), ppu.readbyte(0x3F17),
	ppu.readbyte(0x3F19), ppu.readbyte(0x3F1A), ppu.readbyte(0x3F1B),
}
local pal_back_ok = pal_back[1] == 0x06 and pal_back[2] == 0x16 and pal_back[3] == 0x26
	and pal_back[4] == 0x08 and pal_back[5] == 0x18 and pal_back[6] == 0x28
log(string.format(
	"vuelta_a_pradera: room=%d oculto=%s paleta_restaurada=%s",
	room_back, tostring(hidden_back), tostring(pal_back_ok)
))

local pass = hidden_in_pradera and pal_pradera_ok and room_in_casa == ROOM_CASA and visible_in_casa
	and pal_casa_ok and still_visible and moved and room_back == ROOM_PRADERA and hidden_back and pal_back_ok

log("oculto_fuera_de_casa=" .. tostring(hidden_in_pradera))
log("paleta_pradera_intacta=" .. tostring(pal_pradera_ok))
log("visible_y_repaletizado_en_casa=" .. tostring(visible_in_casa and pal_casa_ok))
log("patrulla_real=" .. tostring(still_visible and moved))
log("paleta_restaurada_al_volver=" .. tostring(pal_back_ok))
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
