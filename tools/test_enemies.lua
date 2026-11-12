-- Prueba de humo para F5.2 (enemigos básicos).
-- Verifica, de forma automatizada, contra la ROM real:
--   1. Patrullero: se mueve solo y se mantiene dentro de su rango
--      (ENEMY_PATROL_MIN_X/MAX_X en src/main.s).
--   2. Perseguidor/saltador: se acerca de verdad a Chiquito en X (no
--      es un rango fijo) y su Y cambia (salto visual), a diferencia
--      del patrullero.
--   3. Atacante a distancia: dispara un proyectil real (aparece una
--      nueva entidad activa de tipo PROYECTIL) al terminar su
--      cooldown, y ese proyectil desaparece solo al agotar su vida --
--      la regla de aparición/desaparición que pide F5.2.
--   4. Daño por contacto: tocar un enemigo pone a Chiquito en HURT,
--      igual que un peligro de tile (reusa enter_hurt_state).

local X_PX_LO, X_PX_HI, Y_HI = 0x000D, 0x000E, 0x0010
local VX_LO, VX_HI, VY_LO, VY_HI = 0x0011, 0x0012, 0x0013, 0x0014
local STATE = 0x0017
local STATE_HURT = 5

local ENTITY_ACTIVE, ENTITY_ROOM, ENTITY_TYPE = 0x0362, 0x036A, 0x0372
local ENTITY_X_LO, ENTITY_X_HI, ENTITY_Y = 0x037A, 0x0382, 0x038A
local ENTITY_BEHAVIOR = 0x03AE
local MAX_ENTITIES = 8

local ROOM_PRADERA = 0
local ENTITY_TYPE_ENEMY, ENTITY_TYPE_PROJECTILE = 0, 2
local ENEMY_BEHAVIOR_PATROL, ENEMY_BEHAVIOR_CHASER, ENEMY_BEHAVIOR_RANGED = 0, 1, 2
local ENEMY_PATROL_MIN_X, ENEMY_PATROL_MAX_X = 160, 200
local ENEMY_CHASER_SPAWN_X = 380

local out = io.open("/tmp/fceux_test_enemies.txt", "w")
local function log(line)
	out:write(line .. "\n")
	out:flush()
end

local function entity_x(slot)
	return memory.readbyte(ENTITY_X_LO + slot) + memory.readbyte(ENTITY_X_HI + slot) * 256
end

local function find_by_behavior(behavior)
	for i = 0, MAX_ENTITIES - 1 do
		if memory.readbyte(ENTITY_ACTIVE + i) == 1
			and memory.readbyte(ENTITY_TYPE + i) == ENTITY_TYPE_ENEMY
			and memory.readbyte(ENTITY_BEHAVIOR + i) == behavior then
			return i
		end
	end
	return nil
end

local function count_active_of_type(t)
	local n = 0
	for i = 0, MAX_ENTITIES - 1 do
		if memory.readbyte(ENTITY_ACTIVE + i) == 1 and memory.readbyte(ENTITY_TYPE + i) == t then
			n = n + 1
		end
	end
	return n
end

local function find_projectile_slot()
	for i = 0, MAX_ENTITIES - 1 do
		if memory.readbyte(ENTITY_ACTIVE + i) == 1 and memory.readbyte(ENTITY_TYPE + i) == ENTITY_TYPE_PROJECTILE then
			return i
		end
	end
	return nil
end

local function set_entity_x(slot, x)
	memory.writebyte(ENTITY_X_LO + slot, x % 256)
	memory.writebyte(ENTITY_X_HI + slot, math.floor(x / 256))
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

local patrol_slot = find_by_behavior(ENEMY_BEHAVIOR_PATROL)
local chaser_slot = find_by_behavior(ENEMY_BEHAVIOR_CHASER)
local ranged_slot = find_by_behavior(ENEMY_BEHAVIOR_RANGED)
log(string.format("slots: patrullero=%s perseguidor=%s atacante=%s",
	tostring(patrol_slot), tostring(chaser_slot), tostring(ranged_slot)))

-- Aleja a Chiquito de todos los enemigos mientras se prueba el
-- patrullero en aislamiento (si estuviera cerca del perseguidor, su
-- knockback al tocarlo interferiría con esta medición, igual que pasó
-- en tools/test_state_machine.lua).
teleport(20, 152)
for _ = 1, 5 do
	joypad.set(1, {})
	emu.frameadvance()
end

-- 1) Patrullero: se mueve solo y se queda dentro de su rango. Rebota
-- cada 40px (160-200) a ~0.5px/frame -- dos muestras sueltas pueden
-- coincidir por casualidad si el intervalo es un múltiplo exacto del
-- ciclo de ida y vuelta (pasó de verdad probando esto con 60 frames
-- exactos). Se registra el mínimo/máximo visto en 90 muestras (una
-- por frame) en vez de solo 2 puntos, para que el resultado no
-- dependa de la aritmética exacta del rebote.
local patrol_min, patrol_max
if patrol_slot ~= nil then
	patrol_min, patrol_max = entity_x(patrol_slot), entity_x(patrol_slot)
end
for _ = 1, 90 do
	joypad.set(1, {})
	emu.frameadvance()
	if patrol_slot ~= nil then
		local x = entity_x(patrol_slot)
		if x < patrol_min then patrol_min = x end
		if x > patrol_max then patrol_max = x end
	end
end
local patrol_in_range = patrol_slot ~= nil
	and patrol_min >= ENEMY_PATROL_MIN_X and patrol_max <= ENEMY_PATROL_MAX_X
local patrol_moved = patrol_slot ~= nil and (patrol_max - patrol_min) >= 10
local patrol_ok = patrol_slot ~= nil and patrol_in_range and patrol_moved
log(string.format("patrullero: min=%s max=%s en_rango=%s se_movio=%s",
	tostring(patrol_min), tostring(patrol_max), tostring(patrol_in_range), tostring(patrol_moved)))

-- 2) Perseguidor/saltador: se acerca de verdad a Chiquito en X y su Y
-- cambia con el tiempo (salto visual, a diferencia del patrullero).
-- El paso 1 ya lo dejó persiguiendo hacia x=20 durante 95 frames --
-- se lo repone en su spawn real (ENEMY_CHASER_SPAWN_X) para medir un
-- acercamiento fresco con una distancia inicial conocida, en vez de
-- heredar lo que haya avanzado mientras se probaba el patrullero.
if chaser_slot ~= nil then
	set_entity_x(chaser_slot, ENEMY_CHASER_SPAWN_X)
end
teleport(300, 152)
for _ = 1, 5 do
	joypad.set(1, {})
	emu.frameadvance()
end
local chaser_dist1 = chaser_slot ~= nil and math.abs(entity_x(chaser_slot) - 300) or -1
local chaser_y1 = chaser_slot ~= nil and memory.readbyte(ENTITY_Y + chaser_slot) or -1
local saw_hop = false
for _ = 1, 80 do
	joypad.set(1, {})
	emu.frameadvance()
	if chaser_slot ~= nil and memory.readbyte(ENTITY_Y + chaser_slot) ~= chaser_y1 then
		saw_hop = true
	end
end
local player_x_after = memory.readbyte(X_PX_LO) + memory.readbyte(X_PX_HI) * 256
local chaser_dist2 = chaser_slot ~= nil and math.abs(entity_x(chaser_slot) - player_x_after) or -1
local chaser_approached = chaser_dist1 >= 0 and chaser_dist2 >= 0 and chaser_dist2 < chaser_dist1
local chaser_ok = chaser_slot ~= nil and chaser_approached and saw_hop
log(string.format("perseguidor: dist1=%d dist2=%d se_acerco=%s salto_visual=%s",
	chaser_dist1, chaser_dist2, tostring(chaser_approached), tostring(saw_hop)))

-- 3) Atacante a distancia: dispara un proyectil real al terminar su
-- cooldown (90 frames), y ese proyectil desaparece solo más tarde.
-- Chiquito se coloca cerca pero FUERA del hitbox de contacto (8px) del
-- atacante, para observar el disparo sin interrumpirlo con un HURT.
local ranged_x = ranged_slot ~= nil and entity_x(ranged_slot) or 460
teleport(ranged_x - 40, 152)
local projectile_count_before = count_active_of_type(ENTITY_TYPE_PROJECTILE)
local saw_projectile = false
local projectile_slot = nil
for _ = 1, 100 do
	joypad.set(1, {})
	emu.frameadvance()
	local slot = find_projectile_slot()
	if slot ~= nil then
		saw_projectile = true
		projectile_slot = slot
		break
	end
end
local fired_ok = ranged_slot ~= nil and saw_projectile
log(string.format("atacante_dispara: antes=%d disparo_visto=%s slot=%s",
	projectile_count_before, tostring(saw_projectile), tostring(projectile_slot)))

-- El proyectil debe desaparecer solo (PROJECTILE_LIFETIME=60 frames
-- desde que se disparó), no porque Chiquito lo haya tocado (eso
-- también lo desactiva, ver check_enemy_contact, pero probaría otra
-- cosa) -- se lo saca de en medio antes de esperar.
if projectile_slot ~= nil then
	teleport(20, 152)
end
local disappeared_ok = false
if projectile_slot ~= nil then
	for _ = 1, 70 do
		joypad.set(1, {})
		emu.frameadvance()
		if memory.readbyte(ENTITY_ACTIVE + projectile_slot) == 0 then
			disappeared_ok = true
			break
		end
	end
end
log(string.format("proyectil_desaparece_solo: %s", tostring(disappeared_ok)))

-- 4) Daño por contacto: Chiquito se para encima del patrullero y debe
-- entrar en HURT, igual que un peligro de tile. Se desactivan el
-- perseguidor/atacante y cualquier proyectil (pueden haber quedado
-- cerca tras los pasos anteriores) y se fuerza player_state a IDLE,
-- para que el único contacto posible sea con el patrullero -- mismo
-- criterio de aislamiento que ya usa tools/test_state_machine.lua.
local contact_hurt_ok = false
if patrol_slot ~= nil then
	if chaser_slot ~= nil then memory.writebyte(ENTITY_ACTIVE + chaser_slot, 0) end
	if ranged_slot ~= nil then memory.writebyte(ENTITY_ACTIVE + ranged_slot, 0) end
	for i = 0, MAX_ENTITIES - 1 do
		if memory.readbyte(ENTITY_TYPE + i) == ENTITY_TYPE_PROJECTILE then
			memory.writebyte(ENTITY_ACTIVE + i, 0)
		end
	end
	memory.writebyte(STATE, 0) -- STATE_IDLE

	local px = entity_x(patrol_slot)
	local py = memory.readbyte(ENTITY_Y + patrol_slot)
	teleport(px, py)
	for _ = 1, 5 do
		joypad.set(1, {})
		emu.frameadvance()
		if memory.readbyte(STATE) == STATE_HURT then
			contact_hurt_ok = true
			break
		end
	end
end
log(string.format("contacto_causa_hurt: %s", tostring(contact_hurt_ok)))

gui.savescreenshotas("/tmp/fceux_test_enemies.png")

log("patrullero_dentro_de_rango_y_en_movimiento=" .. tostring(patrol_ok))
log("perseguidor_se_acerca_y_salta=" .. tostring(chaser_ok))
log("atacante_dispara_proyectil=" .. tostring(fired_ok))
log("proyectil_desaparece_solo=" .. tostring(disappeared_ok))
log("contacto_con_enemigo_causa_hurt=" .. tostring(contact_hurt_ok))

local pass = patrol_ok and chaser_ok and fired_ok and disappeared_ok and contact_hurt_ok
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
