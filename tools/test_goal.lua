-- Prueba de humo para el cierre del "Hito obligatorio" (meta de nivel
-- real, ver TASKS.md: assets/maps/pradera.txt columna 43, fila 9).
-- Verifica, de forma automatizada, contra la ROM real:
--   1. Tocar la meta entra en STATE_WIN (congelado, sin HURT/DEAD de
--      por medio) y dispara el efecto de sonido.
--   2. Tras WIN_DURATION frames, el jugador reaparece en el punto de
--      aparición de pradera (96,152) en STATE_IDLE -- "reiniciar el
--      nivel", el cierre honesto sin HUD/pantalla de victoria real.

local X_PX_LO, X_PX_HI, Y_HI = 0x000D, 0x000E, 0x0010
local VX_LO, VX_HI, VY_LO, VY_HI = 0x0011, 0x0012, 0x0013, 0x0014
local STATE = 0x0017
local ROOM_CURRENT = 0x0031
local APU_STATUS = 0x4015

local STATE_IDLE, STATE_WIN = 0, 7
local ROOM_PRADERA = 0
local PRADERA_SPAWN_X, PRADERA_SPAWN_Y = 96, 152
local GOAL_X, GOAL_Y = 696, 152   -- columna 43, fila 9 (ver assets/maps/pradera.txt)

local out = io.open("/tmp/fceux_test_goal.txt", "w")
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
end

-- Deja que termine el reset y decaiga cualquier residuo de velocidad.
for _ = 1, 100 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(0x0001) >= 5 and memory.readbyte(VX_HI) == 0 and memory.readbyte(VX_LO) == 0
		and memory.readbyte(VY_HI) == 0 and memory.readbyte(VY_LO) == 0 then
		break
	end
end

-- 1) Tocar la meta entra en STATE_WIN y dispara el efecto de sonido.
teleport(GOAL_X, GOAL_Y)
local win_seen = false
for _ = 1, 5 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(STATE) == STATE_WIN then
		win_seen = true
		break
	end
end
local pulse1_active = (memory.readbyte(APU_STATUS) % 2) == 1
log(string.format("meta_entra_en_win: %s sonido_disparado=%s", tostring(win_seen), tostring(pulse1_active)))

-- Confirma que queda congelado (ni la física ni un segundo toque de la
-- meta reinician el temporizador): la posición no cambia sosteniendo
-- una dirección.
local x_frozen_before = memory.readbyte(X_PX_LO) + memory.readbyte(X_PX_HI) * 256
for _ = 1, 10 do
	joypad.set(1, { right = true })
	emu.frameadvance()
end
local x_frozen_after = memory.readbyte(X_PX_LO) + memory.readbyte(X_PX_HI) * 256
local frozen_ok = x_frozen_before == x_frozen_after and memory.readbyte(STATE) == STATE_WIN

-- 2) Tras el resto de WIN_DURATION (90 frames en total), reaparece en
-- el punto de aparición de pradera, en IDLE.
local reappeared_ok = false
for _ = 1, 90 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(STATE) == STATE_IDLE then
		reappeared_ok = true
		break
	end
end
local final_x = memory.readbyte(X_PX_LO) + memory.readbyte(X_PX_HI) * 256
local final_y = memory.readbyte(Y_HI)
local final_room = memory.readbyte(ROOM_CURRENT)
local respawn_ok = reappeared_ok and final_x == PRADERA_SPAWN_X and final_y == PRADERA_SPAWN_Y
	and final_room == ROOM_PRADERA
log(string.format(
	"reinicia_el_nivel: aparecio_idle=%s x=%d y=%d room=%d (esperado %d,%d,%d) ok=%s",
	tostring(reappeared_ok), final_x, final_y, final_room,
	PRADERA_SPAWN_X, PRADERA_SPAWN_Y, ROOM_PRADERA, tostring(respawn_ok)
))

gui.savescreenshotas("/tmp/fceux_test_goal.png")

log("meta_entra_en_win_y_suena=" .. tostring(win_seen and pulse1_active))
log("congelado_mientras_dura_win=" .. tostring(frozen_ok))
log("reaparece_en_spawn_tras_win_duration=" .. tostring(respawn_ok))

local pass = win_seen and pulse1_active and frozen_ok and respawn_ok
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
