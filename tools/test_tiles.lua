-- Prueba de humo para F2.2 (tiles y metatiles).
-- Verifica, de forma automatizada, que la escena de pradera compilada
-- desde assets fuente (tools/png2chr.py + tools/build_scene.py) se ve
-- como se espera: cielo azul arriba, borde de pasto verde y tierra cálida
-- debajo; ninguno debe ser negro (lo que indicaría el quirk de índice 0 sin
-- corregir -- ver nota en tools/gen_test_tileset.py). También confirma
-- que el CPU sigue estable (mismo chequeo que F1.2/F1.3).

local out = io.open("/tmp/fceux_test_tiles.txt", "w")
local function log(line)
	out:write(line .. "\n")
end

for _ = 1, 20 do
	emu.frameadvance()
end

local function sample(name, x, y)
	local r, g, b = emu.getscreenpixel(x, y, false)
	log(string.format("%s(%d,%d) = (%d,%d,%d)", name, x, y, r, g, b))
	return r, g, b
end

-- Puntos lejos de la nube/plataforma de prueba. La superficie empieza
-- en y=160; la muestra y=161 cae en el borde verde y y=210 en la tierra.
local sr, sg, sb = sample("cielo", 220, 20)
local gr, gg, gb = sample("pasto", 50, 161)
local dr, dg, db = sample("tierra", 50, 210)

local function is_black(r, g, b)
	return r == 0 and g == 0 and b == 0
end

local sky_ok = not is_black(sr, sg, sb) and sb > sr and sb > sg       -- predominancia azul
local ground_ok = not is_black(gr, gg, gb) and gg > gr and gg > gb    -- predominancia verde
local soil_ok = not is_black(dr, dg, db) and dr > dg and dr > db      -- predominancia marrón

local pc = memory.getregister("pc")
local pc_in_fixed_bank = (pc >= 0xC000 and pc <= 0xFFF9)

log("cielo_es_azulado=" .. tostring(sky_ok))
log("pasto_es_verdoso=" .. tostring(ground_ok))
log("tierra_es_marron=" .. tostring(soil_ok))
log(string.format("PC=$%04X en_banco_fijo=%s", pc, tostring(pc_in_fixed_bank)))

gui.savescreenshotas("/tmp/fceux_test_tiles.png")

local pass = sky_ok and ground_ok and soil_ok and pc_in_fixed_bank
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
