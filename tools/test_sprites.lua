-- Prueba de humo para F2.3 (sprites).
-- Verifica, de forma automatizada:
--   1. Que los 3 sprites (Chiquito, enemigo, coleccionable) se ven en
--      sus posiciones esperadas con colores distintos del fondo.
--   2. Que la animación de Chiquito realmente alterna entre el tile de
--      idle y el de caminar a lo largo del tiempo (no un valor fijo).
--   3. Que no se activó el flag de desborde de sprites por scanline
--      ($2002 bit 5) -- tenemos muy pocos sprites, así que esto debería
--      cumplirse siempre, pero se valida el mecanismo real, no se asume.

local out = io.open("/tmp/fceux_test_sprites.txt", "w")
local function log(line)
	out:write(line .. "\n")
end

local function sample(name, x, y)
	local r, g, b = emu.getscreenpixel(x, y, false)
	log(string.format("%s(%d,%d) = (%d,%d,%d)", name, x, y, r, g, b))
	return r, g, b
end

local function is_blue_sky(r, g, b)
	return r == 93 and g == 150 and b == 255
end
local function is_green_ground(r, g, b)
	return r == 0 and g == 150 and b == 0
end

-- frame_count tarda unos ~6 frames en empezar a avanzar (el reset ahora
-- hace bastante trabajo: limpieza de RAM, relleno de OAM, paletas,
-- escena de 960+64 bytes). bit4 de frame_count alterna cada 16 cuentas;
-- se muestrea bien adentro de una ventana "idle" (<16) y de una
-- ventana "caminar" (16-31) para no quedar justo en el borde.
for _ = 1, 14 do
	emu.frameadvance()
end
local tile_a = memory.readbyte(0x0201) -- oam_buffer+1 = byte de tile del sprite 0
local fc_a = memory.readbyte(0x0001)

for _ = 1, 21 do
	emu.frameadvance()
end
local tile_b = memory.readbyte(0x0201)
local fc_b = memory.readbyte(0x0001)
log(string.format("frame_count_a=%d frame_count_b=%d", fc_a, fc_b))

local cr, cg, cb = sample("chiquito", 104, 184)
local er, eg, eb = sample("enemigo", 184, 184)
local ir_, ig, ib = sample("item", 144, 104)

-- Puntos de "oreja/contorno" (índice de color 1, no 2): a diferencia del
-- índice 2 -- que por coincidencia vale $16 en ambas subpaletas-- el
-- índice 1 sí distingue jugador ($27, tan) de enemigo ($06, rojo
-- oscuro). Confirma que la subpaleta de sprite seleccionada por
-- atributo realmente aplica.
local cor, cog, cob = sample("chiquito_oreja", 101, 181)
local eor, eog, eob = sample("enemigo_oreja", 181, 181)
local subpalette_differs = not (cor == eor and cog == eog and cob == eob)

local sprites_distinct_from_bg = not is_blue_sky(cr, cg, cb) and not is_green_ground(cr, cg, cb)
	and not is_blue_sky(er, eg, eb) and not is_green_ground(er, eg, eb)
	and not is_blue_sky(ir_, ig, ib) and not is_green_ground(ir_, ig, ib)

local animation_toggles = tile_a ~= tile_b

local ppustatus = memory.readbyte(0x2002)
local sprite_overflow = (math.floor(ppustatus / 32) % 2) == 1

log(string.format("tile_a=%d tile_b=%d", tile_a, tile_b))
log("animacion_alterna=" .. tostring(animation_toggles))
log("sprites_distintos_del_fondo=" .. tostring(sprites_distinct_from_bg))
log("subpaleta_jugador_distinta_de_enemigo=" .. tostring(subpalette_differs))
log("sprite_overflow=" .. tostring(sprite_overflow))

gui.savescreenshotas("/tmp/fceux_test_sprites.png")

local pass = sprites_distinct_from_bg and animation_toggles and subpalette_differs and not sprite_overflow
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
