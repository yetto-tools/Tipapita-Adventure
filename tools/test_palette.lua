-- Prueba de humo para F2.1 (paletas).
-- Verifica, de forma automatizada, que las 3 bandas de fondo (cielo,
-- pradera, tierra) se ven en pantalla como 3 colores distintos y que
-- ninguno es negro (lo que confirmaría que la paleta real sí se cargó y
-- que el banco de CHR correcto está seleccionado en el mapper). Usa
-- emu.getscreenpixel, que lee el framebuffer real — gui.getpixel lee una
-- capa de overlay separada y no sirve para esto (se comprobó
-- empíricamente durante el desarrollo de esta prueba).

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
local gr, gg, gb = sample("pradera", 128, 140)
local dr, dg, db = sample("tierra", 128, 205)

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
