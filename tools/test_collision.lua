-- Prueba de humo para F3.3 (colisiones).
-- Usa joypad.set para simular input real y lee la RAM de física
-- directamente, verificando que la colisión real contra tiles bloquea
-- como se espera: techo, pared, aterrizaje en el suelo, y que el
-- peligro hace reaparecer a Chiquito.

local X_HI, Y_HI, VX_LO, VX_HI, VY_LO, VY_HI, ON_GROUND = 0x000D, 0x000F, 0x0010, 0x0011, 0x0012, 0x0013, 0x0014

local out = io.open("/tmp/fceux_test_collision.txt", "w")
local function log(line)
	out:write(line .. "\n")
end

local function signed8(v)
	if v >= 128 then return v - 256 else return v end
end

local function state()
	return {
		x = memory.readbyte(X_HI),
		y = memory.readbyte(Y_HI),
		vx = signed8(memory.readbyte(VX_HI)),
		vy = signed8(memory.readbyte(VY_HI)),
		on_ground = memory.readbyte(ON_GROUND),
	}
end

local function hold(buttons, frames)
	local s
	for _ = 1, frames do
		joypad.set(1, buttons or {})
		emu.frameadvance()
		s = state()
	end
	return s
end

-- Deja que termine el reset Y que decaiga por completo cualquier
-- residuo de velocidad de la ventana transitoria de arranque (ver
-- registro de F3.2/F3.3 en TASKS.md). frame_count >= 5 asegura que
-- mainloop ya lleva varias vueltas reales.
for i = 1, 100 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(0x0001) >= 5 and memory.readbyte(VX_HI) == 0 and memory.readbyte(VX_LO) == 0
		and memory.readbyte(VY_HI) == 0 and memory.readbyte(VY_LO) == 0 then
		break
	end
end
local s0 = state()
log(string.format("spawn: x=%d y=%d on_ground=%d (esperado x=96 y=152 on_ground=1)", s0.x, s0.y, s0.on_ground))

-- 1) Techo: saltar desde el punto de aparición (ya está justo debajo
--    del bloque de techo, columnas 6-7, fila 7 = píxeles 112-127).
local min_y = 255
for _ = 1, 20 do
	joypad.set(1, { A = true })
	emu.frameadvance()
	local y = memory.readbyte(Y_HI)
	if y < min_y then min_y = y end
end
for _ = 1, 40 do
	joypad.set(1, {})
	emu.frameadvance()
	local y = memory.readbyte(Y_HI)
	if y < min_y then min_y = y end
	if memory.readbyte(ON_GROUND) == 1 then break end
end
local s_land = state()
log(string.format("salto: y_minimo=%d (esperado >= 128) tras_aterrizar: y=%d on_ground=%d", min_y, s_land.y, s_land.on_ground))
local ceiling_ok = min_y >= 128
local land_ok = s_land.y == 152 and s_land.on_ground == 1

-- 2) Pared: sostener Left suficientes frames para llegar a la pared
--    (columna 1, borde derecho en x=32) y confirmar que se detiene ahí,
--    sin atravesarla ni dar la vuelta (wrap) a un valor absurdo. Se
--    acepta un vx residual pequeño (oscilación de sub-píxel contra el
--    borde) -- lo que importa es que no atraviese (x no baja de 32).
local s_wall = hold({ left = true }, 120)
log(string.format("tras_pared: x=%d vx=%d (esperado x=32, vx pequeño)", s_wall.x, s_wall.vx))
local wall_ok = s_wall.x == 32 and math.abs(s_wall.vx) <= 4

-- 3) Peligro: caminar a la derecha hasta la celda de peligro (columna
--    12, fila 10) y confirmar que Chiquito reaparece en (96,152).
local s_hazard
for _ = 1, 160 do
	joypad.set(1, { right = true })
	emu.frameadvance()
	s_hazard = state()
	if s_hazard.x == 96 and s_hazard.y == 152 then break end -- ya reapareció
end
log(string.format("tras_peligro: x=%d y=%d (esperado reaparecer en x=96 y=152)", s_hazard.x, s_hazard.y))
local hazard_ok = s_hazard.x == 96 and s_hazard.y == 152

gui.savescreenshotas("/tmp/fceux_test_collision.png")

log("techo_detiene=" .. tostring(ceiling_ok))
log("aterriza_en_superficie=" .. tostring(land_ok))
log("pared_detiene=" .. tostring(wall_ok))
log("peligro_hace_reaparecer=" .. tostring(hazard_ok))

local pass = ceiling_ok and land_ok and wall_ok and hazard_ok
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
