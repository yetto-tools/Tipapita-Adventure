-- Prueba de humo para F2.1 (paletas).
-- Verifica, de forma automatizada, que 3 subpaletas de fondo distintas
-- (cielo, pradera, tierra) se ven en pantalla como 3 colores distintos y
-- que ninguno es negro (lo que confirmaría que la paleta real sí se
-- cargó y que el banco de CHR correcto está seleccionado en el mapper).
-- Usa emu.getscreenpixel, que lee el framebuffer real — gui.getpixel lee
-- una capa de overlay separada y no sirve para esto (se comprobó
-- empíricamente durante el desarrollo de esta prueba).
--
-- Actualizado en F3.3: los puntos originales de "pradera" (128,140) y
-- "tierra" (128,205) muestreaban cielo/pradera respectivamente desde que
-- F2.2 reemplazó las 3 bandas planas por la escena real (el cielo ahora
-- ocupa casi toda la pantalla, el suelo solo empieza en la fila de
-- metatiles 10). La subpaleta de tierra solo se usa de verdad desde
-- F3.3, en la pared de prueba (columna 1, filas 7-9).

local out = io.open("/tmp/fceux_test_palette.txt", "w")
local function log(line)
	out:write(line .. "\n")
end

for _ = 1, 15 do
	emu.frameadvance()
end

local function sample(name, x, y)
	local r, g, b = emu.getscreenpixel(x, y, false)
	log(string.format("%s(%d,%d) = (%d,%d,%d)", name, x, y, r, g, b))
	return r, g, b
end

local sr, sg, sb = sample("cielo", 128, 40)
local gr, gg, gb = sample("pradera", 64, 165)
local dr, dg, db = sample("tierra", 24, 150)

local function is_black(r, g, b)
	return r == 0 and g == 0 and b == 0
end

local function eq(a1, a2, a3, b1, b2, b3)
	return a1 == b1 and a2 == b2 and a3 == b3
end

local none_black = not is_black(sr, sg, sb) and not is_black(gr, gg, gb) and not is_black(dr, dg, db)
local all_distinct = not eq(sr, sg, sb, gr, gg, gb) and not eq(sr, sg, sb, dr, dg, db) and not eq(gr, gg, gb, dr, dg, db)

log("ninguno_es_negro=" .. tostring(none_black))
log("las_3_son_distintas=" .. tostring(all_distinct))

gui.savescreenshotas("/tmp/fceux_test_palette.png")

local pass = none_black and all_distinct
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
