-- Prueba de humo para F4.3 (pantallas y habitaciones).
-- Verifica, de forma automatizada, la transición real entre la zona de
-- scroll (pradera) y la habitación fija (Casa Pipapita):
--   1. La puerta de pradera (pantalla 2, columna 46, fila 9) lleva a
--      la Casa Pipapita: room_current cambia, Chiquito aparece en el
--      punto de aparición de la nueva habitación (no donde tocó la
--      puerta), y el nametable físico cambia de verdad (confirmado con
--      ppu.readbyte, no solo la bandera room_current).
--   2. Dentro de una habitación fija (1 pantalla), la cámara queda
--      SIEMPRE en (0,0) aunque Chiquito camine -- sin scroll.
--   3. La puerta de la Casa Pipapita (columna 15, fila 9) vuelve a
--      pradera, con el nametable real de pradera de nuevo en $2000.
--   4. Nada queda roto tras las 2 transiciones: frame_count sigue
--      avanzando y el mando sigue respondiendo.

local X_PX_LO, X_PX_HI, Y_HI = 0x000D, 0x000E, 0x0010
local VX_LO, VX_HI, VY_LO, VY_HI = 0x0011, 0x0012, 0x0013, 0x0014
local ON_GROUND, STATE = 0x0015, 0x0017
local CAMERA_LO, CAMERA_HI = 0x0023, 0x0024
local ROOM_CURRENT = 0x0031

local ROOM_PRADERA, ROOM_CASA = 0, 1
local STATE_FALL = 3

local out = io.open("/tmp/fceux_test_rooms.txt", "w")
local function log(line)
	out:write(line .. "\n")
	out:flush()
end

local function x16()
	return memory.readbyte(X_PX_HI) * 256 + memory.readbyte(X_PX_LO)
end
local function camera16()
	return memory.readbyte(CAMERA_HI) * 256 + memory.readbyte(CAMERA_LO)
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

-- Deja que termine el reset y decaiga cualquier residuo de velocidad.
for _ = 1, 100 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(0x0001) >= 5 and memory.readbyte(VX_HI) == 0 and memory.readbyte(VX_LO) == 0
		and memory.readbyte(VY_HI) == 0 and memory.readbyte(VY_LO) == 0 then
		break
	end
end

local spawn_room = memory.readbyte(ROOM_CURRENT)
local nametable_tile_pradera = ppu.readbyte(0x2000) -- fila0,col0: SKY = T_BLANK = 0 en pradera
log(string.format(
	"arranque: room=%d x=%d tile(0,0)=%d (esperado room=0 x=96 tile=0)",
	spawn_room, x16(), nametable_tile_pradera
))
local boot_ok = spawn_room == ROOM_PRADERA and x16() == 96 and nametable_tile_pradera == 0

-- 1) Teletransporta sobre la puerta de pradera (columna 46, fila 9 ->
--    mundo x=736-751, y=152 parado sobre el piso -- no es cómo juega
--    una persona real, igual que otros teletransportes de este
--    proyecto para aislar un comportamiento puntual sin depender de
--    resolver la plataforma completa).
teleport(740, 152)
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local room_after_door1 = memory.readbyte(ROOM_CURRENT)
local x_in_casa, y_in_casa = x16(), memory.readbyte(Y_HI)
local cam_in_casa = camera16()
local nametable_tile_casa = ppu.readbyte(0x2000) -- fila0,col0: WALL (techo) = T_GROUND_FILL = 3 en la casa
log(string.format(
	"puerta_pradera_a_casa: room=%d x=%d y=%d camera=%d tile(0,0)=%d (esperado room=1 x=208 y=152 camera=0 tile=3)",
	room_after_door1, x_in_casa, y_in_casa, cam_in_casa, nametable_tile_casa
))
local door1_ok = room_after_door1 == ROOM_CASA and x_in_casa == 208 and y_in_casa == 152
	and cam_in_casa == 0 and nametable_tile_casa == 3

-- 2) Habitación fija: camina de verdad dentro de la casa y confirma
--    que la cámara nunca se mueve de (0,0) -- a diferencia de pradera,
--    una habitación de 1 pantalla no tiene a dónde hacer scroll
--    (room_max_camera=0).
local camera_moved = false
for _ = 1, 60 do
	joypad.set(1, { left = true })
	emu.frameadvance()
	if camera16() ~= 0 then camera_moved = true end
end
for _ = 1, 90 do
	joypad.set(1, { right = true })
	emu.frameadvance()
	if camera16() ~= 0 then camera_moved = true end
end
log(string.format("camara_fija_en_casa: se_movio=%s (esperado false)", tostring(camera_moved)))
local fixed_camera_ok = not camera_moved

-- 3) Teletransporta sobre la puerta de la casa (columna 15, fila 9 ->
--    mundo x=240-255, y=152) y confirma que vuelve a pradera, en el
--    punto de aparición de pradera (no donde se tocó la puerta de la
--    casa) -- load_room siempre reaparece en el spawn de la habitación
--    destino, limitación documentada en TASKS.md/ARCHITECTURE.md.
teleport(244, 152)
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local room_after_door2 = memory.readbyte(ROOM_CURRENT)
local x_back, y_back = x16(), memory.readbyte(Y_HI)
local nametable_tile_back = ppu.readbyte(0x2000)
log(string.format(
	"puerta_casa_a_pradera: room=%d x=%d y=%d tile(0,0)=%d (esperado room=0 x=96 y=152 tile=0)",
	room_after_door2, x_back, y_back, nametable_tile_back
))
local door2_ok = room_after_door2 == ROOM_PRADERA and x_back == 96 and y_back == 152
	and nametable_tile_back == 0

-- 4) Nada quedó roto: frame_count sigue avanzando y el mando responde.
local fc_before = memory.readbyte(0x0001)
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local fc_after = memory.readbyte(0x0001)
local frames_advancing = ((fc_after - fc_before) % 256) == 10

joypad.set(1, { right = true })
emu.frameadvance()
local pad1_after = memory.readbyte(0x0009)
local controller_ok = pad1_after ~= 0

log(string.format("nada_roto: frames_avanzan=%s mando_responde=%s", tostring(frames_advancing), tostring(controller_ok)))

gui.savescreenshotas("/tmp/fceux_test_rooms.png")

log("arranque_en_pradera=" .. tostring(boot_ok))
log("puerta_pradera_a_casa=" .. tostring(door1_ok))
log("camara_fija_en_habitacion=" .. tostring(fixed_camera_ok))
log("puerta_casa_a_pradera=" .. tostring(door2_ok))
log("nada_roto_tras_transiciones=" .. tostring(frames_advancing and controller_ok))

local pass = boot_ok and door1_ok and fixed_camera_ok and door2_ok and frames_advancing and controller_ok
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
