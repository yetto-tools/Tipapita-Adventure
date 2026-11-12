-- Prueba de humo para F5.3 (armas y proyectiles).
-- Verifica, de forma automatizada, contra la ROM real:
--   1. El botón B dispara un proyectil real del jugador (entidad
--      ENTITY_TYPE_PLAYER_PROJECTILE) que viaja en la dirección hacia
--      la que mira Chiquito.
--   2. Límite de proyectiles: con uno ya activo, un segundo disparo no
--      crea una segunda entidad (PLAYER_PROJECTILE_LIMIT=1).
--   3. El proyectil tiene corto alcance real: se desactiva solo (sin
--      tocar nada) antes de viajar demasiado lejos, y libera el
--      límite para el próximo disparo.
--   4. Detección de impactos: el proyectil derrota a un enemigo real
--      al tocarlo (se desactivan ambos -- el proyectil se consume).

local X_PX_LO, X_PX_HI, Y_HI = 0x000D, 0x000E, 0x0010
local VX_LO, VX_HI, VY_LO, VY_HI = 0x0011, 0x0012, 0x0013, 0x0014
local FACING_RIGHT = 0x0016

local ENTITY_ACTIVE, ENTITY_ROOM, ENTITY_TYPE = 0x0362, 0x036A, 0x0372
local ENTITY_X_LO, ENTITY_X_HI, ENTITY_Y = 0x037A, 0x0382, 0x038A
local ENTITY_TILE, ENTITY_ATTR = 0x0392, 0x039A
local ENTITY_BEHAVIOR, ENTITY_DIR, ENTITY_TIMER = 0x03AE, 0x03B6, 0x03BE
local MAX_ENTITIES = 8

local ROOM_PRADERA = 0
local ENTITY_TYPE_ENEMY, ENTITY_TYPE_PLAYER_PROJECTILE = 0, 3

local out = io.open("/tmp/fceux_test_weapons.txt", "w")
local function log(line)
	out:write(line .. "\n")
	out:flush()
end

local function entity_x(slot)
	return memory.readbyte(ENTITY_X_LO + slot) + memory.readbyte(ENTITY_X_HI + slot) * 256
end

local function find_player_projectile()
	for i = 0, MAX_ENTITIES - 1 do
		if memory.readbyte(ENTITY_ACTIVE + i) == 1 and memory.readbyte(ENTITY_TYPE + i) == ENTITY_TYPE_PLAYER_PROJECTILE then
			return i
		end
	end
	return nil
end

local function count_player_projectiles()
	local n = 0
	for i = 0, MAX_ENTITIES - 1 do
		if memory.readbyte(ENTITY_ACTIVE + i) == 1 and memory.readbyte(ENTITY_TYPE + i) == ENTITY_TYPE_PLAYER_PROJECTILE then
			n = n + 1
		end
	end
	return n
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

local function press_b_once()
	joypad.set(1, { B = true })
	emu.frameadvance()
	joypad.set(1, {})
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

-- Aisla la prueba: desactiva todas las entidades de pradera (mismo
-- criterio que tools/test_state_machine.lua) para controlar
-- exactamente qué hay en la tabla durante cada paso.
for i = 0, MAX_ENTITIES - 1 do
	memory.writebyte(ENTITY_ACTIVE + i, 0)
end

-- Chiquito camina a la derecha un momento (para que player_facing_right
-- quede en 1 de verdad, no asumido) y se detiene en campo abierto.
teleport(300, 152)
for _ = 1, 10 do
	joypad.set(1, { right = true })
	emu.frameadvance()
end
teleport(300, 152)
for _ = 1, 3 do
	joypad.set(1, {})
	emu.frameadvance()
end
local facing_ok = memory.readbyte(FACING_RIGHT) == 1
log(string.format("mirando_a_la_derecha: %s", tostring(facing_ok)))

-- 1) Disparo real: B dispara un proyectil que viaja hacia la derecha.
press_b_once()
local slot1 = find_player_projectile()
local spawn_x = slot1 ~= nil and entity_x(slot1) or -1
local fired_ok = slot1 ~= nil and spawn_x > 300
log(string.format("disparo: slot=%s spawn_x=%d (jugador en 300) ok=%s",
	tostring(slot1), spawn_x, tostring(fired_ok)))

-- Confirma que viaja de verdad hacia la derecha (no queda fijo).
local x_before_move = spawn_x
for _ = 1, 5 do
	joypad.set(1, {})
	emu.frameadvance()
end
local x_after_move = slot1 ~= nil and entity_x(slot1) or -1
local moved_right_ok = slot1 ~= nil and x_after_move > x_before_move
log(string.format("proyectil_viaja: antes=%d despues=%d ok=%s",
	x_before_move, x_after_move, tostring(moved_right_ok)))

-- 2) Límite: con el proyectil todavía activo, un segundo disparo no
-- debe crear una segunda entidad.
press_b_once()
local count_after_second_press = count_player_projectiles()
local limit_ok = count_after_second_press == 1
log(string.format("limite_de_proyectiles: activos=%d (esperado 1) ok=%s",
	count_after_second_press, tostring(limit_ok)))

-- 3) Corto alcance: el proyectil se agota solo, sin tocar nada, y
-- libera el límite para el próximo disparo.
local disappeared_ok = false
for _ = 1, 30 do
	joypad.set(1, {})
	emu.frameadvance()
	if find_player_projectile() == nil then
		disappeared_ok = true
		break
	end
end
log(string.format("corto_alcance_desaparece_solo: %s", tostring(disappeared_ok)))

press_b_once()
local refire_ok = find_player_projectile() ~= nil
log(string.format("puede_disparar_de_nuevo_tras_agotarse: %s", tostring(refire_ok)))

-- Limpia cualquier proyectil activo y deja pasar ATTACK_DURATION
-- (14 frames) para que Chiquito vuelva a su estado normal -- B solo
-- se revisa fuera de STATE_ATTACK; sin esta espera, el disparo del
-- paso 4 se descartaba en silencio (confirmado real con logging).
for i = 0, MAX_ENTITIES - 1 do
	if memory.readbyte(ENTITY_TYPE + i) == ENTITY_TYPE_PLAYER_PROJECTILE then
		memory.writebyte(ENTITY_ACTIVE + i, 0)
	end
end
for _ = 1, 20 do
	joypad.set(1, {})
	emu.frameadvance()
end

-- 4) Impacto real: un enemigo de prueba colocado a 30px adelante del
-- jugador debe ser derrotado por el próximo disparo (y el proyectil
-- se consume). behavior=99 (no coincide con ningún ENEMY_BEHAVIOR_*)
-- lo deja quieto -- la prueba es de impacto, no de IA del enemigo.
local DUMMY_SLOT = 1
set_entity(DUMMY_SLOT, {
	active = 1, room = ROOM_PRADERA, type = ENTITY_TYPE_ENEMY,
	x = 330, y = 152, tile = 75, attr = 0, behavior = 99, dir = 0, timer = 0,
})
teleport(300, 152)
for _ = 1, 3 do
	joypad.set(1, {})
	emu.frameadvance()
end
press_b_once()

local impact_ok = false
for _ = 1, 20 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(ENTITY_ACTIVE + DUMMY_SLOT) == 0 then
		impact_ok = true
		break
	end
end
local projectile_consumed_ok = find_player_projectile() == nil
log(string.format("impacto_derrota_enemigo: %s proyectil_consumido=%s",
	tostring(impact_ok), tostring(projectile_consumed_ok)))

gui.savescreenshotas("/tmp/fceux_test_weapons.png")

log("jugador_dispara_hacia_donde_mira=" .. tostring(fired_ok and moved_right_ok and facing_ok))
log("limite_de_un_proyectil=" .. tostring(limit_ok))
log("corto_alcance_y_puede_redisparar=" .. tostring(disappeared_ok and refire_ok))
log("impacto_derrota_enemigo_y_consume_proyectil=" .. tostring(impact_ok and projectile_consumed_ok))

local pass = facing_ok and fired_ok and moved_right_ok and limit_ok
	and disappeared_ok and refire_ok and impact_ok and projectile_consumed_ok
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
