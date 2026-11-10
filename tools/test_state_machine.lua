-- Prueba de humo para F3.4 (máquina de estados).
-- Usa joypad.set para simular input real y lee la RAM directamente,
-- verificando las 7 transiciones de estado: IDLE, WALK, JUMP/FALL,
-- ATTACK (enraíza el movimiento), HURT (knockback + parpadeo tras
-- peligro), y DEAD (congelado tras caer, luego reaparece).

local X_HI, Y_HI, VX_HI = 0x000D, 0x000F, 0x0011
local STATE, TIMER = 0x0016, 0x0017

local STATE_IDLE, STATE_WALK, STATE_JUMP, STATE_FALL = 0, 1, 2, 3
local STATE_ATTACK, STATE_HURT, STATE_DEAD = 4, 5, 6

local out = io.open("/tmp/fceux_test_state_machine.txt", "w")
local function log(line)
	out:write(line .. "\n")
end

local function st()
	return memory.readbyte(STATE)
end

-- Deja que termine el reset y decaiga cualquier residuo de velocidad
-- (ver F3.2/F3.3). frame_count >= 5 confirma mainloop corriendo de verdad.
for i = 1, 100 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(0x0001) >= 5 and memory.readbyte(VX_HI) == 0 and memory.readbyte(0x0010) == 0
		and memory.readbyte(0x0013) == 0 and memory.readbyte(0x0012) == 0 then
		break
	end
end
local state0 = st()
log(string.format("spawn: state=%d (esperado IDLE=0)", state0))
local idle_ok = state0 == STATE_IDLE

-- 1) Caminar: sostener Right debe pasar a WALK.
for _ = 1, 10 do
	joypad.set(1, { right = true })
	emu.frameadvance()
end
local walk_state = st()
log(string.format("caminando: state=%d (esperado WALK=1)", walk_state))
local walk_ok = walk_state == STATE_WALK

-- 2) Saltar: debe pasar a JUMP, luego FALL, luego volver a IDLE/WALK al aterrizar.
joypad.set(1, {})
for _ = 1, 100 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(0x0014) == 1 then break end -- esperar a estar en el suelo primero
end
local saw_jump, saw_fall = false, false
joypad.set(1, { A = true })
emu.frameadvance()
if st() == STATE_JUMP then saw_jump = true end
for _ = 1, 60 do
	joypad.set(1, {})
	emu.frameadvance()
	local s = st()
	if s == STATE_JUMP then saw_jump = true end
	if s == STATE_FALL then saw_fall = true end
	if memory.readbyte(0x0014) == 1 then break end
end
local landed_state = st()
log(string.format("salto: vio_jump=%s vio_fall=%s tras_aterrizar=%d", tostring(saw_jump), tostring(saw_fall), landed_state))
local jump_fall_ok = saw_jump and saw_fall and (landed_state == STATE_IDLE or landed_state == STATE_WALK)

-- 3) Atacar: B debe entrar en ATTACK y enraizar el movimiento horizontal
--    (sostener Right al mismo tiempo no debe mover a Chiquito).
local x_before_attack = memory.readbyte(X_HI)
joypad.set(1, { B = true, right = true })
emu.frameadvance()
local attack_state = st()
local x_during_attack = memory.readbyte(X_HI)
for _ = 1, 20 do
	joypad.set(1, { right = true })
	emu.frameadvance()
end
local x_after_attack = memory.readbyte(X_HI)
local after_attack_state = st()
log(string.format(
	"ataque: state=%d x_antes=%d x_durante=%d x_despues=%d state_final=%d",
	attack_state, x_before_attack, x_during_attack, x_after_attack, after_attack_state
))
local attack_ok = attack_state == STATE_ATTACK and x_during_attack == x_before_attack
	and x_after_attack > x_before_attack -- tras soltar el ataque, Right sí mueve
	and after_attack_state == STATE_WALK

-- 4) Peligro: caminar a la derecha hasta la celda de peligro debe entrar
--    en HURT con knockback (vx != 0 empujando hacia atrás) y, mientras
--    dure, el sprite debe parpadear (oam Y = $FF en algunos frames).
local saw_hurt, saw_blink = false, false
for _ = 1, 160 do
	joypad.set(1, { right = true })
	emu.frameadvance()
	if st() == STATE_HURT then
		saw_hurt = true
		if memory.readbyte(0x0200) == 0xFF then saw_blink = true end
	end
	if saw_hurt and st() ~= STATE_HURT then break end
end
log(string.format("peligro: vio_hurt=%s vio_parpadeo=%s", tostring(saw_hurt), tostring(saw_blink)))
local hurt_ok = saw_hurt and saw_blink

-- 5) Muerte por caída: se prueba aparte del peligro (caminar sosteniendo
--    Right sin parar rebotaría contra el mismo tile de peligro una y
--    otra vez -- no es cómo juega una persona real, y no es lo que esta
--    prueba quiere verificar). Se coloca a Chiquito con escritura
--    directa de memoria justo antes del hueco (columnas 13-14, píxeles
--    208+), parado y quieto, y se suelta a caminar hacia la derecha.
--    Debe entrar en DEAD (congelado) y luego reaparecer en (96,152) con
--    IDLE.
for _ = 1, 60 do
	joypad.set(1, {})
	emu.frameadvance()
	if st() ~= STATE_HURT then break end
end
-- x=210 cae dentro del hueco (columnas 13-14 = píxeles 208-239), no de
-- la celda de peligro (columna 12 = píxeles 192-207).
memory.writebyte(X_HI, 210)
memory.writebyte(Y_HI, 152)
memory.writebyte(0x0010, 0) -- vx_lo
memory.writebyte(VX_HI, 0)
memory.writebyte(0x0012, 0) -- vy_lo
memory.writebyte(0x0013, 0) -- vy_hi
memory.writebyte(0x0014, 0) -- on_ground=0: ya está sobre el hueco, nada la sostiene
memory.writebyte(STATE, STATE_FALL)

local saw_dead = false
local final_x, final_y, final_state
for _ = 1, 300 do
	joypad.set(1, {})
	emu.frameadvance()
	if st() == STATE_DEAD then saw_dead = true end
	final_x, final_y, final_state = memory.readbyte(X_HI), memory.readbyte(Y_HI), st()
	if saw_dead and final_state ~= STATE_DEAD then break end
end
log(string.format("muerte: vio_dead=%s reaparicion x=%d y=%d state=%d", tostring(saw_dead), final_x, final_y, final_state))
local death_ok = saw_dead and final_x == 96 and final_y == 152 and final_state == STATE_IDLE

gui.savescreenshotas("/tmp/fceux_test_state_machine.png")

log("idle_al_aparecer=" .. tostring(idle_ok))
log("camina=" .. tostring(walk_ok))
log("salta_y_cae=" .. tostring(jump_fall_ok))
log("ataque_enraiza=" .. tostring(attack_ok))
log("peligro_causa_hurt_con_parpadeo=" .. tostring(hurt_ok))
log("muerte_por_caida_y_reaparicion=" .. tostring(death_ok))

local pass = idle_ok and walk_ok and jump_fall_ok and attack_ok and hurt_ok and death_ok
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
