-- Prueba de humo para F1.2 (reset e inicialización).
-- Verifica, de forma automatizada:
--   1. Que el CPU termina el reset y queda en un bucle estable dentro del
--      banco fijo de PRG-ROM ($C000-$FFF9), no colgado/saltado a otro lado.
--   2. Que la pantalla muestra negro uniforme (paleta inicializada), no un
--      color indefinido de encendido ni basura visual.
-- No valida gráficos de juego ni NMI real: eso es F1.3 en adelante.

local out = io.open("/tmp/fceux_test_init.txt", "w")
local function log(line)
	out:write(line .. "\n")
end

-- Deja correr suficientes frames para que termine el reset (dos esperas de
-- VBlank + limpieza de RAM + escritura de paleta) y se estabilice en el loop.
for _ = 1, 10 do
	emu.frameadvance()
end

local pc = memory.getregister("pc")
local pc_in_fixed_bank = (pc >= 0xC000 and pc <= 0xFFF9)
log(string.format("PC=$%04X en_banco_fijo=%s", pc, tostring(pc_in_fixed_bank)))

-- Muestrea varios puntos de la pantalla (esquinas + centro) para confirmar
-- negro uniforme ($0F en la paleta -> RGB 0,0,0 en FCEUX).
local points = {
	{0, 0}, {255, 0}, {0, 223}, {255, 223}, {128, 112},
}
local all_black = true
for _, p in ipairs(points) do
	local r, g, b = gui.getpixel(p[1], p[2])
	local is_black = (r == 0 and g == 0 and b == 0)
	all_black = all_black and is_black
	log(string.format("pixel(%d,%d)=(%d,%d,%d) negro=%s", p[1], p[2], r, g, b, tostring(is_black)))
end

local pass = pc_in_fixed_bank and all_black
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
