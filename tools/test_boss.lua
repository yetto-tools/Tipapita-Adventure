-- Prueba de humo para F5.4 (jefe: guardián de roca).
-- Verifica, de forma automatizada, contra la ROM real:
--   1. Arranca en fase GUARD, vida completa.
--   2. Tocarlo en GUARD hace daño real al jugador (HURT); tocarlo en
--      EXPOSED no hace nada.
--   3. En fase 2 (vida <= BOSS_PHASE2_HEALTH) el ciclo GUARD se acorta
--      y dispara un proyectil real -- un cambio de comportamiento, no
--      solo un número que baja.
--   4. El proyectil del jugador le hace daño real en EXPOSED (resta
--      vida, se consume) y, al llegar a 0, lo derrota (BOSS_STATE_
--      DEFEATED) y dispara STATE_WIN del jugador -- derrota y
--      recompensa.

local X_PX_LO, X_PX_HI, Y_HI = 0x000D, 0x000E, 0x0010
local VX_LO, VX_HI, VY_LO, VY_HI = 0x0011, 0x0012, 0x0013, 0x0014
local FACING_RIGHT = 0x0016
local STATE = 0x0017
local STATE_IDLE, STATE_HURT, STATE_WIN = 0, 5, 7

local BOSS_STATE, BOSS_HEALTH, BOSS_TIMER = 0x03C7, 0x03C8, 0x03C9
local BOSS_STATE_GUARD, BOSS_STATE_EXPOSED, BOSS_STATE_DEFEATED = 0, 1, 2
local BOSS_X, BOSS_Y = 592, 152
local BOSS_HEALTH_MAX = 5
local BOSS_PHASE2_HEALTH = 2
local BOSS_GUARD_DURATION_P2 = 60

local ENTITY_ACTIVE, ENTITY_ROOM, ENTITY_TYPE = 0x0362, 0x036A, 0x0372
local MAX_ENTITIES = 8
local ENTITY_TYPE_PROJECTILE, ENTITY_TYPE_PLAYER_PROJECTILE = 2, 3

local out = io.open("/tmp/fceux_test_boss.txt", "w")
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

local function reset_player_state()
	memory.writebyte(STATE, STATE_IDLE)
end

local function press_b_once()
	joypad.set(1, { B = true })
	emu.frameadvance()
	joypad.set(1, {})
end

local function find_enemy_projectile()
	for i = 0, MAX_ENTITIES - 1 do
		if memory.readbyte(ENTITY_ACTIVE + i) == 1 and memory.readbyte(ENTITY_TYPE + i) == ENTITY_TYPE_PROJECTILE then
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

-- Aisla la prueba: desactiva todas las entidades normales de pradera.
for i = 0, MAX_ENTITIES - 1 do
	memory.writebyte(ENTITY_ACTIVE + i, 0)
end

-- 1) Estado inicial.
local initial_state = memory.readbyte(BOSS_STATE)
local initial_health = memory.readbyte(BOSS_HEALTH)
local initial_ok = initial_state == BOSS_STATE_GUARD and initial_health == BOSS_HEALTH_MAX
log(string.format("estado_inicial: fase=%d vida=%d ok=%s", initial_state, initial_health, tostring(initial_ok)))

-- 2a) Contacto en GUARD hace daño real.
teleport(BOSS_X, BOSS_Y)
reset_player_state()
local guard_hurt_ok = false
for _ = 1, 5 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(STATE) == STATE_HURT then
		guard_hurt_ok = true
		break
	end
end
log(string.format("contacto_en_guard_hace_dano: %s", tostring(guard_hurt_ok)))

-- Se aleja y espera a que el jefe pase a EXPOSED.
teleport(300, 152)
local exposed_seen = false
for _ = 1, 140 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(BOSS_STATE) == BOSS_STATE_EXPOSED then
		exposed_seen = true
		break
	end
end
log(string.format("llega_a_exposed: %s", tostring(exposed_seen)))

-- 2b) Contacto en EXPOSED NO hace daño.
teleport(BOSS_X, BOSS_Y)
reset_player_state()
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local exposed_no_hurt_ok = memory.readbyte(STATE) ~= STATE_HURT
log(string.format("contacto_en_exposed_no_hace_dano: estado=%d ok=%s", memory.readbyte(STATE), tostring(exposed_no_hurt_ok)))

-- 3) Fase 2: fuerza la vida al umbral y el estado a EXPOSED con el
-- temporizador a punto de vencer -- el próximo ciclo entra a GUARD
-- (EXPOSED->GUARD alterna con el mismo EOR #1, ver update_boss) y
-- ahí es donde se decide la duración corta (P2) según la vida.
teleport(300, 152)
reset_player_state()
memory.writebyte(BOSS_HEALTH, BOSS_PHASE2_HEALTH)
memory.writebyte(BOSS_STATE, BOSS_STATE_EXPOSED)
memory.writebyte(BOSS_TIMER, 1)   -- un solo frame para forzar el cambio de fase ya mismo
for _ = 1, 3 do
	joypad.set(1, {})
	emu.frameadvance()
end
local phase2_duration_ok = memory.readbyte(BOSS_STATE) == BOSS_STATE_GUARD
	and memory.readbyte(BOSS_TIMER) <= BOSS_GUARD_DURATION_P2
log(string.format("fase2_guard_corto: fase=%d timer=%d ok=%s",
	memory.readbyte(BOSS_STATE), memory.readbyte(BOSS_TIMER), tostring(phase2_duration_ok)))

local phase2_fires_ok = false
for _ = 1, 65 do
	joypad.set(1, {})
	emu.frameadvance()
	if find_enemy_projectile() ~= nil then
		phase2_fires_ok = true
		break
	end
end
log(string.format("fase2_dispara_proyectil: %s", tostring(phase2_fires_ok)))

-- 4) El proyectil del jugador le hace daño real en EXPOSED. Vuelve a
-- dejarlo en EXPOSED con vida completa para medir un impacto limpio.
memory.writebyte(BOSS_HEALTH, BOSS_HEALTH_MAX)
memory.writebyte(BOSS_STATE, BOSS_STATE_EXPOSED)
memory.writebyte(BOSS_TIMER, 60)
for i = 0, MAX_ENTITIES - 1 do
	if memory.readbyte(ENTITY_TYPE + i) == ENTITY_TYPE_PROJECTILE or memory.readbyte(ENTITY_TYPE + i) == ENTITY_TYPE_PLAYER_PROJECTILE then
		memory.writebyte(ENTITY_ACTIVE + i, 0)
	end
end
teleport(BOSS_X - 40, BOSS_Y)
for _ = 1, 10 do
	joypad.set(1, { right = true })
	emu.frameadvance()
end
teleport(BOSS_X - 40, BOSS_Y)
for _ = 1, 3 do
	joypad.set(1, {})
	emu.frameadvance()
end
local health_before_hit = memory.readbyte(BOSS_HEALTH)
press_b_once()
local hit_ok = false
for _ = 1, 20 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(BOSS_HEALTH) == health_before_hit - 1 then
		hit_ok = true
		break
	end
end
log(string.format("proyectil_le_hace_dano: antes=%d despues=%d ok=%s",
	health_before_hit, memory.readbyte(BOSS_HEALTH), tostring(hit_ok)))

-- 5) Derrota y recompensa: fuerza vida=1 (todavía en EXPOSED) y
-- confirma que el próximo impacto lo derrota y gana el nivel.
memory.writebyte(BOSS_HEALTH, 1)
memory.writebyte(BOSS_STATE, BOSS_STATE_EXPOSED)
memory.writebyte(BOSS_TIMER, 60)
for _ = 1, 20 do
	joypad.set(1, {})
	emu.frameadvance()
end
press_b_once()
local defeated_ok = false
local win_ok = false
for _ = 1, 20 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(BOSS_STATE) == BOSS_STATE_DEFEATED then defeated_ok = true end
	if memory.readbyte(STATE) == STATE_WIN then win_ok = true end
	if defeated_ok and win_ok then break end
end
log(string.format("derrota_y_recompensa: derrotado=%s jugador_gana=%s", tostring(defeated_ok), tostring(win_ok)))

gui.savescreenshotas("/tmp/fceux_test_boss.png")

log("estado_inicial_correcto=" .. tostring(initial_ok))
log("vulnerabilidad_por_fase=" .. tostring(guard_hurt_ok and exposed_seen and exposed_no_hurt_ok))
log("fase_2_real=" .. tostring(phase2_duration_ok and phase2_fires_ok))
log("dano_real_al_jefe=" .. tostring(hit_ok))
log("derrota_y_recompensa=" .. tostring(defeated_ok and win_ok))

local pass = initial_ok and guard_hurt_ok and exposed_seen and exposed_no_hurt_ok
	and phase2_duration_ok and phase2_fires_ok and hit_ok and defeated_ok and win_ok
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
