-- Prueba de humo para F2.3 (sprites), actualizada en F3.4 para seguir
-- la posición real de Chiquito en vez de una coordenada fija (desde
-- F3.2 el punto de aparición cambió, y desde F3.4 la animación depende
-- del estado real -- caminar de verdad -- no de un parpadeo por tiempo
-- fijo).
-- Verifica, de forma automatizada:
--   1. Que los 3 sprites (Chiquito, enemigo, coleccionable) se ven con
--      colores distintos del fondo.
--   2. Que la animación de Chiquito alterna entre el tile de idle y el
--      de caminar cuando realmente camina (sosteniendo Right).
--   3. Que no se activó el flag de desborde de sprites por scanline
--      ($2002 bit 5) -- tenemos muy pocos sprites, así que esto debería
--      cumplirse siempre, pero se valida el mecanismo real, no se asume.

local X_HI, Y_HI, VX_HI, VX_LO, VY_HI, VY_LO = 0x000D, 0x0010, 0x0012, 0x0011, 0x0014, 0x0013  -- F4.2: direcciones +1 desde player_y_lo (player_x_px_hi nuevo)

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

-- Deja que termine el reset y decaiga cualquier residuo de velocidad
-- (ver F3.2/F3.3 en TASKS.md). frame_count >= 5 confirma mainloop
-- corriendo de verdad.
for i = 1, 100 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(0x0001) >= 5 and memory.readbyte(VX_HI) == 0 and memory.readbyte(VX_LO) == 0
		and memory.readbyte(VY_HI) == 0 and memory.readbyte(VY_LO) == 0 then
		break
	end
end

local tile_idle = memory.readbyte(0x0201) -- oam_buffer+1, en reposo

-- Camina a la derecha: la animación debe alternar idle/caminar.
local saw_walk_tile = false
local tile_walking
for _ = 1, 30 do
	joypad.set(1, { right = true })
	emu.frameadvance()
	tile_walking = memory.readbyte(0x0201)
	if tile_walking ~= tile_idle then saw_walk_tile = true end
end

-- F4.2: X_HI es de MUNDO (player_x_px_lo), no de pantalla. Tras caminar
-- a la derecha la cámara ya se movió (ver update_camera_and_streaming
-- en src/main.s), así que hay que restar camera_x_lo -- la misma resta
-- de 8 bits que hace @animate para escribir el X real al OAM -- antes
-- de usar la posición para samplear el framebuffer.
-- F5.1: el enemigo/ítem de prueba ya no son sprites estáticos escritos
-- una sola vez en oam_init_data (F2.3) -- son entidades reales
-- (update_entities), y por lo tanto TAMBIÉN relativas a cámara, igual
-- que Chiquito. Sus posiciones de MUNDO (180,179)/(140,99) son las
-- mismas de siempre (ver spawn_entity en load_room, src/main.s); lo
-- que cambia es que hay que restar camera_x_lo para samplear la
-- posición de PANTALLA real, no la de mundo.
local CAMERA_X_LO = 0x0023
local camera_lo = memory.readbyte(CAMERA_X_LO)
local px_world, py = memory.readbyte(X_HI), memory.readbyte(Y_HI)
local px = (px_world - camera_lo) % 256
local enemy_px = (180 - camera_lo) % 256
local item_px = (140 - camera_lo) % 256
local cr, cg, cb = sample("chiquito", px + 4, py + 4)
local er, eg, eb = sample("enemigo", enemy_px + 4, 184)
local ir_, ig, ib = sample("item", item_px + 4, 104)

-- Puntos de "oreja/contorno" (índice de color 1, no 2): a diferencia del
-- índice 2 -- que por coincidencia vale $16 en ambas subpaletas-- el
-- índice 1 sí distingue jugador ($27, tan) de enemigo ($06, rojo
-- oscuro). Confirma que la subpaleta de sprite seleccionada por
-- atributo realmente aplica.
local cor, cog, cob = sample("chiquito_oreja", px + 1, py + 1)
local eor, eog, eob = sample("enemigo_oreja", enemy_px + 1, 181)
local subpalette_differs = not (cor == eor and cog == eog and cob == eob)

local sprites_distinct_from_bg = not is_blue_sky(cr, cg, cb) and not is_green_ground(cr, cg, cb)
	and not is_blue_sky(er, eg, eb) and not is_green_ground(er, eg, eb)
	and not is_blue_sky(ir_, ig, ib) and not is_green_ground(ir_, ig, ib)

local ppustatus = memory.readbyte(0x2002)
local sprite_overflow = (math.floor(ppustatus / 32) % 2) == 1

log(string.format("tile_idle=%d tile_walking(ultimo)=%d", tile_idle, tile_walking))
log("animacion_alterna_al_caminar=" .. tostring(saw_walk_tile))
log("sprites_distintos_del_fondo=" .. tostring(sprites_distinct_from_bg))
log("subpaleta_jugador_distinta_de_enemigo=" .. tostring(subpalette_differs))
log("sprite_overflow=" .. tostring(sprite_overflow))

gui.savescreenshotas("/tmp/fceux_test_sprites.png")

local pass = sprites_distinct_from_bg and saw_walk_tile and subpalette_differs and not sprite_overflow
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
