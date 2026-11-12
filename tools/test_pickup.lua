-- Prueba de humo para el cierre del "Hito obligatorio" (coleccionable
-- real + efecto de sonido, ver TASKS.md).
-- Verifica, de forma automatizada, contra la ROM real:
--   1. Tocar un ítem activo lo desactiva y suma items_collected.
--   2. El efecto de sonido se dispara de verdad (canal pulse 1 de la
--      APU, $4015 bit0 refleja el contador de longitud activo -- no
--      se puede leer $4000-$4003 directamente, son de solo escritura).
--   3. Un enemigo en la misma posición NO se recoge como ítem (el
--      chequeo filtra por tipo).

local X_PX_LO, X_PX_HI, Y_HI = 0x000D, 0x000E, 0x0010
local VX_LO, VX_HI, VY_LO, VY_HI = 0x0011, 0x0012, 0x0013, 0x0014
local ITEMS_COLLECTED = 0x03C6
local APU_STATUS = 0x4015

local ENTITY_ACTIVE, ENTITY_ROOM, ENTITY_TYPE = 0x0362, 0x036A, 0x0372
local ENTITY_X_LO, ENTITY_X_HI, ENTITY_Y = 0x037A, 0x0382, 0x038A
local ENTITY_TILE, ENTITY_ATTR = 0x0392, 0x039A
local ENTITY_BEHAVIOR, ENTITY_DIR, ENTITY_TIMER = 0x03AE, 0x03B6, 0x03BE
local MAX_ENTITIES = 8

local ROOM_PRADERA = 0
local ENTITY_TYPE_ENEMY, ENTITY_TYPE_ITEM = 0, 1

local out = io.open("/tmp/fceux_test_pickup.txt", "w")
local function log(line)
	out:write(line .. "\n")
	out:flush()
end

local function set_entity(slot, fields)
	memory.writebyte(ENTITY_ACTIVE + slot, fields.active or 0)
	memory.writebyte(ENTITY_ROOM + slot, fields.room or 0)
	memory.writebyte(ENTITY_TYPE + slot, fields.type or 0)
	memory.writebyte(ENTITY_X_LO + slot, (fields.x or 0) % 256)
	memory.writebyte(ENTITY_X_HI + slot, math.floor((fields.x or 0) / 256))
	memory.writebyte(ENTITY_Y + slot, fields.y or 0)
	memory.writebyte(ENTITY_TILE + slot, fields.tile or 0)
	memory.writebyte(ENTITY_ATTR + slot, fields.attr or 0)
	memory.writebyte(ENTITY_BEHAVIOR + slot, fields.behavior or 0)
	memory.writebyte(ENTITY_DIR + slot, fields.dir or 0)
	memory.writebyte(ENTITY_TIMER + slot, fields.timer or 0)
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

-- Aisla la prueba: desactiva todas las entidades de pradera.
for i = 0, MAX_ENTITIES - 1 do
	memory.writebyte(ENTITY_ACTIVE + i, 0)
end

local items_before = memory.readbyte(ITEMS_COLLECTED)

-- 1) Un enemigo en la posición del jugador NO se recoge (filtra por tipo).
set_entity(0, {
	active = 1, room = ROOM_PRADERA, type = ENTITY_TYPE_ENEMY,
	x = 200, y = 152, tile = 75, attr = 0, behavior = 99, dir = 0, timer = 0,
})
teleport(200, 152)
for _ = 1, 3 do
	joypad.set(1, {})
	emu.frameadvance()
end
local enemy_untouched_ok = memory.readbyte(ENTITY_ACTIVE + 0) == 1
	and memory.readbyte(ITEMS_COLLECTED) == items_before
log(string.format("enemigo_no_se_recoge: activo=%d items=%d (antes %d) ok=%s",
	memory.readbyte(ENTITY_ACTIVE + 0), memory.readbyte(ITEMS_COLLECTED), items_before, tostring(enemy_untouched_ok)))
memory.writebyte(ENTITY_ACTIVE + 0, 0)

-- 2) Un ítem real en la posición del jugador SÍ se recoge: se
-- desactiva, suma items_collected y dispara el efecto de sonido
-- (longitud del canal pulse 1 activa en $4015 bit0).
set_entity(1, {
	active = 1, room = ROOM_PRADERA, type = ENTITY_TYPE_ITEM,
	x = 200, y = 152, tile = 76, attr = 0, behavior = 0, dir = 0, timer = 0,
})
teleport(200, 152)
for _ = 1, 3 do
	joypad.set(1, {})
	emu.frameadvance()
end
local item_consumed_ok = memory.readbyte(ENTITY_ACTIVE + 1) == 0
local items_after = memory.readbyte(ITEMS_COLLECTED)
local count_ok = items_after == ((items_before + 1) % 256)
local pulse1_active = (memory.readbyte(APU_STATUS) % 2) == 1
log(string.format("item_recogido: activo=%d items=%d (esperado %d) pulse1_activo=%s",
	memory.readbyte(ENTITY_ACTIVE + 1), items_after, (items_before + 1) % 256, tostring(pulse1_active)))

gui.savescreenshotas("/tmp/fceux_test_pickup.png")

log("enemigo_no_se_recoge_como_item=" .. tostring(enemy_untouched_ok))
log("item_se_recoge_y_suma_contador=" .. tostring(item_consumed_ok and count_ok))
log("efecto_de_sonido_real_disparado=" .. tostring(pulse1_active))

local pass = enemy_untouched_ok and item_consumed_ok and count_ok and pulse1_active
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
