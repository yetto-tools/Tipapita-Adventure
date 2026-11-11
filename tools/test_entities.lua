-- Prueba de humo para F5.1 (sistema de entidades).
-- Verifica, de forma automatizada, contra el mapa/ROM real:
--   1. La habitación inicial (pradera) genera exactamente 2 entidades
--      reales (el enemigo/ítem de prueba de F2.3, migrados), con los
--      campos correctos.
--   2. Zona: al cambiar de habitación, esas entidades siguen activas
--      en la tabla (no se destruyen) pero quedan ocultas en VRAM
--      (fuera de la habitación actual no se dibujan).
--   3. Al volver a la habitación, no se duplican (destroy-antes-de-
--      generar evita ir gastando slots en cada visita).
--   4. Límite/seguridad de memoria: con las 8 entidades ya llenas (de
--      otra habitación, para que no las toque el paso 3), un intento
--      de generar una nueva falla sin tocar ninguna de las existentes
--      -- no hay desborde ni corrupción.

local X_PX_LO, X_PX_HI, Y_HI = 0x000D, 0x000E, 0x0010
local VX_LO, VX_HI, VY_LO, VY_HI = 0x0011, 0x0012, 0x0013, 0x0014
local ROOM_CURRENT = 0x0031

local ENTITY_ACTIVE, ENTITY_ROOM, ENTITY_TYPE = 0x0362, 0x036A, 0x0372
local ENTITY_X_LO, ENTITY_X_HI, ENTITY_Y = 0x037A, 0x0382, 0x038A
local ENTITY_TILE, ENTITY_ATTR = 0x0392, 0x039A
local MAX_ENTITIES = 8
local ENTITY_OAM_BASE = 4

local ROOM_PRADERA, ROOM_CASA = 0, 1
local ENTITY_TYPE_ENEMY, ENTITY_TYPE_ITEM = 0, 1
local TILE_ENEMY, TILE_ITEM = 10, 11

local out = io.open("/tmp/fceux_test_entities.txt", "w")
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

local function count_active()
	local n = 0
	for i = 0, MAX_ENTITIES - 1 do
		if memory.readbyte(ENTITY_ACTIVE + i) == 1 then n = n + 1 end
	end
	return n
end

local function find_by_type(t)
	for i = 0, MAX_ENTITIES - 1 do
		if memory.readbyte(ENTITY_ACTIVE + i) == 1 and memory.readbyte(ENTITY_TYPE + i) == t then
			return i
		end
	end
	return nil
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

-- 1) Pradera genera exactamente 2 entidades, con los campos correctos.
local active_count = count_active()
local enemy_slot = find_by_type(ENTITY_TYPE_ENEMY)
local item_slot = find_by_type(ENTITY_TYPE_ITEM)
local enemy_ok = enemy_slot ~= nil
	and memory.readbyte(ENTITY_ROOM + enemy_slot) == ROOM_PRADERA
	and memory.readbyte(ENTITY_X_LO + enemy_slot) == 180
	and memory.readbyte(ENTITY_Y + enemy_slot) == 179
	and memory.readbyte(ENTITY_TILE + enemy_slot) == TILE_ENEMY
local item_ok = item_slot ~= nil
	and memory.readbyte(ENTITY_ROOM + item_slot) == ROOM_PRADERA
	and memory.readbyte(ENTITY_X_LO + item_slot) == 140
	and memory.readbyte(ENTITY_Y + item_slot) == 99
	and memory.readbyte(ENTITY_TILE + item_slot) == TILE_ITEM
local spawn_ok = active_count == 2 and enemy_ok and item_ok
log(string.format(
	"spawn_pradera: activas=%d enemigo_slot=%s item_slot=%s enemigo_ok=%s item_ok=%s",
	active_count, tostring(enemy_slot), tostring(item_slot), tostring(enemy_ok), tostring(item_ok)
))

-- OAM del enemigo (slot*4 + ENTITY_OAM_BASE), con cámara en 0 al arrancar.
local enemy_oam_y = memory.readbyte(0x0200 + ENTITY_OAM_BASE + enemy_slot * 4)
local oam_visible_ok = enemy_oam_y == 179
log(string.format("oam_enemigo_visible: y=%d (esperado 179)", enemy_oam_y))

-- 2) Cambia de habitación: las entidades de pradera siguen activas
--    pero su OAM queda oculto (Y=$FF) por zona.
teleport(740, 152) -- puerta de pradera -> Casa Pipapita
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local in_casa = memory.readbyte(ROOM_CURRENT) == ROOM_CASA
local still_active_in_casa = memory.readbyte(ENTITY_ACTIVE + enemy_slot) == 1
	and memory.readbyte(ENTITY_ACTIVE + item_slot) == 1
local enemy_oam_y_hidden = memory.readbyte(0x0200 + ENTITY_OAM_BASE + enemy_slot * 4)
local hidden_ok = enemy_oam_y_hidden == 0xFF
log(string.format(
	"zona_oculta_en_casa: en_casa=%s siguen_activas=%s oam_y=%d (esperado 255)",
	tostring(in_casa), tostring(still_active_in_casa), enemy_oam_y_hidden
))

-- 3) Vuelve a pradera: no se duplican.
teleport(244, 152) -- puerta de la casa -> pradera
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local back_in_pradera = memory.readbyte(ROOM_CURRENT) == ROOM_PRADERA
local active_after_return = count_active()
local no_duplicate_ok = back_in_pradera and active_after_return == 2
log(string.format(
	"sin_duplicar_al_volver: en_pradera=%s activas=%d (esperado 2)",
	tostring(back_in_pradera), active_after_return
))

-- 4) Límite/seguridad: llena las 8 entidades con centinelas de una
--    habitación que NO existe (99) -- ni destroy_entities_in_room(
--    PRADERA) ni el de CASA las toca nunca, sin importar qué
--    transición se dispare. Si se usara ROOM_CASA, entrar a la casa
--    las borraría antes de poder probar el límite (load_room siempre
--    limpia las entidades de SU propia habitación antes de generar
--    las nuevas -- por diseño, para no duplicar en cada visita).
--    Después fuerza otra carga de pradera (que SÍ intenta generar 2
--    entidades nuevas) y confirma que no entraron -- la tabla sigue
--    llena de los centinelas, intacta.
local SENTINEL_TILE = 77
local SENTINEL_ROOM = 99
for i = 0, MAX_ENTITIES - 1 do
	memory.writebyte(ENTITY_ACTIVE + i, 1)
	memory.writebyte(ENTITY_ROOM + i, SENTINEL_ROOM)
	memory.writebyte(ENTITY_TYPE + i, 99)
	memory.writebyte(ENTITY_X_LO + i, 0)
	memory.writebyte(ENTITY_X_HI + i, 0)
	memory.writebyte(ENTITY_Y + i, 0)
	memory.writebyte(ENTITY_TILE + i, SENTINEL_TILE)
	memory.writebyte(ENTITY_ATTR + i, 0)
end

teleport(740, 152) -- pradera -> casa (no toca los centinelas, son de la habitación 99)
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
teleport(244, 152) -- casa -> pradera: intenta generar 2 entidades, tabla llena
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end

local sentinels_intact = true
for i = 0, MAX_ENTITIES - 1 do
	if memory.readbyte(ENTITY_ACTIVE + i) ~= 1 or memory.readbyte(ENTITY_TILE + i) ~= SENTINEL_TILE then
		sentinels_intact = false
	end
end
local no_enemy_spawned = find_by_type(ENTITY_TYPE_ENEMY) == nil
local cap_safety_ok = sentinels_intact and no_enemy_spawned
log(string.format(
	"limite_no_corrompe: centinelas_intactos=%s no_se_genero_nuevo=%s",
	tostring(sentinels_intact), tostring(no_enemy_spawned)
))

-- Nada quedó roto: frame_count sigue avanzando y el mando responde.
local fc_before = memory.readbyte(0x0001)
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local fc_after = memory.readbyte(0x0001)
local frames_advancing = ((fc_after - fc_before) % 256) == 10
joypad.set(1, { right = true })
emu.frameadvance()
local controller_ok = memory.readbyte(0x0009) ~= 0
log(string.format("nada_roto: frames_avanzan=%s mando_responde=%s", tostring(frames_advancing), tostring(controller_ok)))

gui.savescreenshotas("/tmp/fceux_test_entities.png")

log("spawn_pradera_correcto=" .. tostring(spawn_ok))
log("oam_visible_al_arrancar=" .. tostring(oam_visible_ok))
log("zona_oculta_fuera_de_la_habitacion=" .. tostring(hidden_ok))
log("sin_duplicar_al_revisitar=" .. tostring(no_duplicate_ok))
log("limite_no_corrompe_memoria=" .. tostring(cap_safety_ok))
log("nada_roto=" .. tostring(frames_advancing and controller_ok))

local pass = spawn_ok and oam_visible_ok and hidden_ok and no_duplicate_ok and cap_safety_ok
	and frames_advancing and controller_ok
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
