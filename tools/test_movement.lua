-- Prueba de humo para F3.2 (movimiento).
-- Usa joypad.set para simular input real y lee la RAM de física del
-- jugador directamente (no asume, verifica). Direcciones desde F4.2
-- (ver player_x_px_hi, nuevo, corrió 1 byte todo lo que venía después
-- de la X en el layout de ZEROPAGE de src/main.s):
--   $000D player_x_px_lo, $0010 player_y_hi, $0012 player_vx_hi,
--   $0014 player_vy_hi, $0015 player_on_ground

local X_HI, Y_HI, VX_HI, VY_HI, ON_GROUND = 0x000D, 0x0010, 0x0012, 0x0014, 0x0015
local GROUND_Y = 179

local out = io.open("/tmp/fceux_test_movement.txt", "w")
local function log(line)
	out:write(line .. "\n")
end

local function signed8(v)
	if v >= 128 then return v - 256 else return v end
end

local function step(buttons, frames)
	local last = {}
	for _ = 1, frames do
		joypad.set(1, buttons or {})
		emu.frameadvance()
	end
	last.x = memory.readbyte(X_HI)
	last.y = memory.readbyte(Y_HI)
	last.vx = signed8(memory.readbyte(VX_HI))
	last.vy = signed8(memory.readbyte(VY_HI))
	last.on_ground = memory.readbyte(ON_GROUND)
	return last
end

-- Deja que termine el reset, forzando explícitamente "nada presionado"
-- (sin esto, FCEUX puede alimentar un estado de mando sin inicializar).
for _ = 1, 14 do
	joypad.set(1, {})
	emu.frameadvance()
end
local x0 = memory.readbyte(X_HI)
local vx0 = signed8(memory.readbyte(VX_HI))
local pad1_0 = memory.readbyte(0x0009)
log(string.format("x_inicial=%d vx_inicial=%d pad1_inicial=%02X (esperado x=100 vx=0 pad1=00)", x0, vx0, pad1_0))

-- 1) Sostener Right 40 frames: debe avanzar.
local after_right = step({ right = true }, 40)
log(string.format("tras_right: x=%d vx=%d", after_right.x, after_right.vx))

-- 2) Soltar 60 frames: la fricción debe devolver vx a 0.
local after_release = step({}, 60)
log(string.format("tras_soltar: x=%d vx=%d", after_release.x, after_release.vx))

-- 3) Sostener Left 40 frames: debe retroceder (vx negativo).
local after_left = step({ left = true }, 40)
log(string.format("tras_left: x=%d vx=%d", after_left.x, after_left.vx))
local after_release2 = step({}, 60)
log(string.format("tras_soltar2: x=%d vx=%d", after_release2.x, after_release2.vx))

-- 4) Salto corto: A un solo frame, luego soltar; registrar la altura
--    mínima (y_hi más chico = más arriba) hasta volver al piso.
local min_y_short = GROUND_Y
joypad.set(1, { A = true })
emu.frameadvance()
for _ = 1, 60 do
	joypad.set(1, {})
	emu.frameadvance()
	local y = memory.readbyte(Y_HI)
	if y < min_y_short then min_y_short = y end
	if memory.readbyte(ON_GROUND) == 1 and y == GROUND_Y then break end
end
log(string.format("salto_corto: altura_minima_y=%d (menor y = mas alto)", min_y_short))

-- 5) Salto largo: sostener A varios frames antes de soltar.
local min_y_long = GROUND_Y
for _ = 1, 20 do
	joypad.set(1, { A = true })
	emu.frameadvance()
	local y = memory.readbyte(Y_HI)
	if y < min_y_long then min_y_long = y end
end
for _ = 1, 60 do
	joypad.set(1, {})
	emu.frameadvance()
	local y = memory.readbyte(Y_HI)
	if y < min_y_long then min_y_long = y end
	if memory.readbyte(ON_GROUND) == 1 and y == GROUND_Y then break end
end
log(string.format("salto_largo: altura_minima_y=%d", min_y_long))

local moved_right = after_right.x > x0 and after_right.vx > 0
local friction_stopped = after_release.vx == 0
local moved_left = after_left.x < after_release.x and after_left.vx < 0
local friction_stopped2 = after_release2.vx == 0
local jump_cut_works = min_y_short > min_y_long -- el salto corto sube menos (y mas grande)

log("mueve_a_la_derecha=" .. tostring(moved_right))
log("friccion_detiene=" .. tostring(friction_stopped))
log("mueve_a_la_izquierda=" .. tostring(moved_left))
log("friccion_detiene2=" .. tostring(friction_stopped2))
log("salto_variable_funciona=" .. tostring(jump_cut_works))

gui.savescreenshotas("/tmp/fceux_test_movement.png")

local pass = moved_right and friction_stopped and moved_left and friction_stopped2 and jump_cut_works
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
