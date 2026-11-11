-- Prueba de humo para F4.4 (elementos de escenario).
-- Verifica, de forma automatizada, contra el mapa/ROM real, cada
-- mecánica con su propio ejemplo (no un sistema general -- eso es
-- F5.1):
--   1. Plataforma móvil: se mueve de verdad dentro de sus límites,
--      Chiquito puede pararse arriba sin atravesarla, y lo arrastra.
--   2. Interruptor + puerta bloqueada: bloquea antes de activarse,
--      tocar el interruptor cambia su tile real en VRAM (no solo la
--      bandera) y abre el paso de verdad.
--   3. Punto de control: tocarlo y luego "morir" reaparece ahí, no en
--      el punto de aparición original de la habitación.
--   4. Pared secreta: se ve como pared pero es atravesable de verdad.

local X_PX_LO, X_PX_HI, Y_HI = 0x000D, 0x000E, 0x0010
local VX_LO, VX_HI, VY_LO, VY_HI = 0x0011, 0x0012, 0x0013, 0x0014
local ON_GROUND, STATE = 0x0015, 0x0017
local ROOM_CURRENT = 0x0031
local CHECKPOINT_ACTIVE, CHECKPOINT_X_LO, CHECKPOINT_X_HI, CHECKPOINT_Y = 0x003D, 0x003F, 0x0040, 0x0041
local SWITCH_CASA_OPEN = 0x0042
local PLATFORM_X_LO, PLATFORM_X_HI, PLATFORM_DIR = 0x0043, 0x0044, 0x0045

local ROOM_PRADERA, ROOM_CASA = 0, 1
local STATE_FALL, STATE_DEAD = 3, 6
local PLATFORM_Y, PLATFORM_MIN_X, PLATFORM_MAX_X = 80, 280, 340
local SWITCH_NT_TL, TILE_SWITCH_PRESSED = 0x224C, 3

local out = io.open("/tmp/fceux_test_scenery.txt", "w")
local function log(line)
	out:write(line .. "\n")
	out:flush()
end

local function x16()
	return memory.readbyte(X_PX_HI) * 256 + memory.readbyte(X_PX_LO)
end
local function platform_x16()
	return memory.readbyte(PLATFORM_X_HI) * 256 + memory.readbyte(PLATFORM_X_LO)
end

local function set16(hi_addr, lo_addr, v)
	memory.writebyte(lo_addr, v % 256)
	memory.writebyte(hi_addr, math.floor(v / 256))
end

local function teleport(x, y, state)
	set16(X_PX_HI, X_PX_LO, x)
	memory.writebyte(Y_HI, y)
	memory.writebyte(VX_LO, 0)
	memory.writebyte(VX_HI, 0)
	memory.writebyte(VY_LO, 0)
	memory.writebyte(VY_HI, 0)
	memory.writebyte(ON_GROUND, 0)
	memory.writebyte(STATE, state or STATE_FALL)
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

-- 1) Plataforma móvil: primero confirma que se mueve sola dentro de
--    [PLATFORM_MIN_X, PLATFORM_MAX_X]. Después la fija en x=300 (un
--    valor conocido dentro de su rango, sin depender de en qué punto
--    de su vaivén esté) y suelta a Chiquito encima desde el aire.
local px_before = platform_x16()
for _ = 1, 20 do
	joypad.set(1, {})
	emu.frameadvance()
end
local px_after = platform_x16()
local platform_moves = px_after ~= px_before
local platform_in_range = px_after >= PLATFORM_MIN_X and px_after <= PLATFORM_MAX_X
log(string.format(
	"plataforma_se_mueve: antes=%d despues=%d en_rango=%s (esperado distinto, dentro de [%d,%d])",
	px_before, px_after, tostring(platform_in_range), PLATFORM_MIN_X, PLATFORM_MAX_X
))

-- Fija la plataforma en x=300 DURANTE la caída (si se la dejara
-- mover sola, en los ~13 frames que tarda Chiquito en caer 10px con
-- gravedad, se alejaría lo suficiente como para que el solape
-- horizontal deje de darse -- ya se confirmó que se mueve sola en el
-- chequeo anterior, esto solo aísla el aterrizaje en sí).
set16(PLATFORM_X_HI, PLATFORM_X_LO, 300)
memory.writebyte(PLATFORM_DIR, 0) -- moviéndose a la derecha
teleport(300, PLATFORM_Y - 8 - 10, STATE_FALL) -- 10px arriba de la plataforma, cayendo
local landed = false
for _ = 1, 30 do
	set16(PLATFORM_X_HI, PLATFORM_X_LO, 300)
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(ON_GROUND) == 1 then
		landed = true
		break
	end
end
local y_landed = memory.readbyte(Y_HI)
local platform_landing_ok = landed and y_landed == (PLATFORM_Y - 8)
log(string.format(
	"plataforma_aterrizaje: landed=%s y=%d (esperado y=%d)",
	tostring(landed), y_landed, PLATFORM_Y - 8
))

local x_riding_before = x16()
for _ = 1, 15 do
	joypad.set(1, {})
	emu.frameadvance()
end
local x_riding_after = x16()
local still_on_ground = memory.readbyte(ON_GROUND) == 1
local platform_carries = x_riding_after > x_riding_before and still_on_ground
log(string.format(
	"plataforma_arrastra: x_antes=%d x_despues=%d sigue_parado=%s (esperado x_despues>x_antes)",
	x_riding_before, x_riding_after, tostring(still_on_ground)
))

local platform_ok = platform_moves and platform_in_range and platform_landing_ok and platform_carries

-- 2) Interruptor + puerta bloqueada: primero entra a la Casa Pipapita
--    por la puerta real de pradera (teletransportado encima, igual
--    que test_rooms.lua), después confirma que la puerta bloqueada
--    (columna 10, mundo x=160-175) detiene el paso, activa el
--    interruptor (columna 6, x=96-111) y confirma que después sí se
--    puede cruzar.
teleport(740, 152)
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local entered_casa = memory.readbyte(ROOM_CURRENT) == ROOM_CASA

teleport(150, 152)
for _ = 1, 60 do
	joypad.set(1, { right = true })
	emu.frameadvance()
end
local x_blocked = x16()
local door_blocks_before = x_blocked <= 159

teleport(100, 152)
for _ = 1, 20 do
	joypad.set(1, {})
	emu.frameadvance()
end
local switch_opened = memory.readbyte(SWITCH_CASA_OPEN) == 1
local switch_tile_after = ppu.readbyte(SWITCH_NT_TL)
local switch_visual_ok = switch_tile_after == TILE_SWITCH_PRESSED

teleport(150, 152)
for _ = 1, 60 do
	joypad.set(1, { right = true })
	emu.frameadvance()
end
local x_after_switch = x16()
local door_opens_after = x_after_switch > 160

log(string.format(
	"interruptor_puerta: entro_casa=%s bloqueaba_antes=%s(x=%d) switch_activado=%s tile_vram=%d abre_despues=%s(x=%d)",
	tostring(entered_casa), tostring(door_blocks_before), x_blocked, tostring(switch_opened),
	switch_tile_after, tostring(door_opens_after), x_after_switch
))
local switch_ok = entered_casa and door_blocks_before and switch_opened and switch_visual_ok and door_opens_after

-- 3) Punto de control: vuelve a pradera, toca el checkpoint (pantalla
--    1, columna 20 = mundo x=320-335), después "muere" (Y por encima
--    del umbral de caída) y confirma que reaparece en el checkpoint,
--    no en el spawn original (96,152).
teleport(244, 152) -- puerta de la casa -> vuelve a pradera
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local back_in_pradera = memory.readbyte(ROOM_CURRENT) == ROOM_PRADERA

teleport(325, 152)
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local checkpoint_set = memory.readbyte(CHECKPOINT_ACTIVE) == 1
local checkpoint_x = memory.readbyte(CHECKPOINT_X_HI) * 256 + memory.readbyte(CHECKPOINT_X_LO)
local checkpoint_y = memory.readbyte(CHECKPOINT_Y)

-- Columnas 13-14 de pradera son el hueco original (F3.3/F3.4): sin
-- piso, cae libre hasta pasar el umbral de muerte. x=96 fijo
-- (teletransportar directo a Y>DEATH_Y_THRESHOLD ahí caería ENCIMA
-- de suelo sólido, que lo empujaría de vuelta a Y<umbral antes de que
-- corriera el chequeo de muerte -- por eso el hueco, no una Y grande
-- en cualquier columna).
teleport(210, 152, STATE_FALL)
local saw_dead = false
local final_x, final_state
for _ = 1, 150 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(STATE) == STATE_DEAD then saw_dead = true end
	final_x, final_state = x16(), memory.readbyte(STATE)
	if saw_dead and final_state ~= STATE_DEAD then break end
end
local checkpoint_respawn_ok = saw_dead and final_x == checkpoint_x and final_state ~= STATE_DEAD

log(string.format(
	"punto_de_control: volvio_pradera=%s checkpoint_set=%s pos=(%d,%d) vio_dead=%s reaparicion_x=%d (esperado %d)",
	tostring(back_in_pradera), tostring(checkpoint_set), checkpoint_x, checkpoint_y,
	tostring(saw_dead), final_x, checkpoint_x
))
local checkpoint_ok = back_in_pradera and checkpoint_set and checkpoint_respawn_ok

-- 4) Pared secreta: columna 33 de pradera (mundo x=528-543) se ve
--    como pared pero es atravesable -- camina de verdad a través,
--    sin quedar atascado antes de la columna.
teleport(520, 152)
for _ = 1, 90 do
	joypad.set(1, { right = true })
	emu.frameadvance()
end
local x_past_secret = x16()
local secret_wall_ok = x_past_secret > 544

log(string.format(
	"pared_secreta: x_final=%d (esperado > 544, atraveso la columna 33)",
	x_past_secret
))

gui.savescreenshotas("/tmp/fceux_test_scenery.png")

log("plataforma_movil=" .. tostring(platform_ok))
log("interruptor_puerta_bloqueada=" .. tostring(switch_ok))
log("punto_de_control=" .. tostring(checkpoint_ok))
log("pared_secreta=" .. tostring(secret_wall_ok))

local pass = platform_ok and switch_ok and checkpoint_ok and secret_wall_ok
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
