-- Prueba de humo para F4.2 (scrolling horizontal).
-- Verifica, de forma automatizada, contra el mapa real de 3 pantallas
-- (assets/maps/pradera.txt, 768px de ancho):
--   1. Que la cámara arranca en 0 y sigue a Chiquito con la fórmula real
--      (camera_x = clamp(player_x - 120, 0, 512)) mientras camina de
--      verdad (joypad), dentro de la pantalla 0.
--   2. Que moverse dentro de las pantallas 0/1 (ya precargadas al
--      arrancar) NO dispara streaming -- no tiene sentido transmitir
--      algo que ya está en VRAM.
--   3. Que al entrar en la pantalla 2 (teletransportado, para no
--      depender de resolver el hueco/salto -- igual que ya hace
--      test_state_machine.lua con la muerte por caída) SÍ dispara una
--      transmisión real: nt_slot_screens[0] pasa de 0 a 2, y el byte
--      de VRAM de un tile distintivo de la pantalla 2 (la nube en
--      fila 2, columna 44) cambia de verdad en $2000 -- leído con
--      ppu.readbyte, no asumido a partir de una bandera.
--   4. Que la colisión against el mapa de colisión de 720 bytes sigue
--      funcionando más allá de los primeros 256px de mundo (el peligro
--      de la columna 40, píxeles 640-655, está en col_x_hi=2 -- el
--      camino de código de 16 bits que F3.3 nunca ejercitó).

local X_PX_LO, X_PX_HI, Y_HI = 0x000D, 0x000E, 0x0010
local VX_LO, VX_HI, VY_LO, VY_HI = 0x0011, 0x0012, 0x0013, 0x0014
local ON_GROUND, STATE, TIMER = 0x0015, 0x0017, 0x0018
local CAMERA_LO, CAMERA_HI = 0x0023, 0x0024
local NT_SLOT0, NT_SLOT1 = 0x0026, 0x0027
local STREAM_ACTIVE = 0x0028

local STATE_FALL, STATE_HURT = 3, 5

local out = io.open("/tmp/fceux_test_scrolling.txt", "w")
local function log(line)
	out:write(line .. "\n")
	out:flush()
end

local function camera16()
	return memory.readbyte(CAMERA_HI) * 256 + memory.readbyte(CAMERA_LO)
end
local function x16()
	return memory.readbyte(X_PX_HI) * 256 + memory.readbyte(X_PX_LO)
end
local function expected_camera(x)
	local c = x - 120
	if c < 0 then c = 0 end
	if c > 512 then c = 512 end
	return c
end

local function teleport(x, y)
	memory.writebyte(X_PX_LO, x % 256)
	memory.writebyte(X_PX_HI, math.floor(x / 256))
	memory.writebyte(Y_HI, y)
	memory.writebyte(VX_LO, 0)
	memory.writebyte(VX_HI, 0)
	memory.writebyte(VY_LO, 0)
	memory.writebyte(VY_HI, 0)
	memory.writebyte(ON_GROUND, 1)
	memory.writebyte(STATE, STATE_FALL) -- recompute_normal_state lo deja en IDLE/WALK al primer frame estable
end

-- Deja que termine el reset (F4.2: tarda ~7 frames reales, ver fix en
-- test_nmi.lua) y decaiga cualquier residuo de velocidad.
for i = 1, 100 do
	joypad.set(1, {})
	emu.frameadvance()
	if memory.readbyte(0x0001) >= 5 and memory.readbyte(VX_HI) == 0 and memory.readbyte(VX_LO) == 0
		and memory.readbyte(VY_HI) == 0 and memory.readbyte(VY_LO) == 0 then
		break
	end
end

local spawn_x, spawn_cam = x16(), camera16()
local spawn_slot0, spawn_slot1 = memory.readbyte(NT_SLOT0), memory.readbyte(NT_SLOT1)
log(string.format(
	"spawn: x=%d camera=%d slot0=%d slot1=%d (esperado x=96 camera=0 slot0=0 slot1=1)",
	spawn_x, spawn_cam, spawn_slot0, spawn_slot1
))
local spawn_ok = spawn_x == 96 and spawn_cam == 0 and spawn_slot0 == 0 and spawn_slot1 == 1

-- 1) Caminar de verdad (joypad) dentro de la pantalla 0, sin llegar al
--    hueco (columnas 13-14 = píxeles 208-239) -- streaming no debería
--    dispararse todavía (slot0/slot1 ya tienen lo que la cámara necesita).
for _ = 1, 90 do
	joypad.set(1, { right = true })
	emu.frameadvance()
	if x16() >= 195 then break end
end
joypad.set(1, {})
emu.frameadvance()
local walk_x, walk_cam = x16(), camera16()
local walk_cam_ok = walk_cam == expected_camera(walk_x)
local walk_no_stream = memory.readbyte(NT_SLOT0) == 0 and memory.readbyte(NT_SLOT1) == 1
log(string.format(
	"camina_pantalla0: x=%d camera=%d esperado_camera=%d sin_streaming=%s",
	walk_x, walk_cam, expected_camera(walk_x), tostring(walk_no_stream)
))

-- 2) Teletransporta a la pantalla 1 (x=300, más allá del hueco -- no es
--    cómo juega una persona real, igual que la muerte por caída de
--    test_state_machine.lua). Pantallas 0 y 1 ya están en VRAM desde el
--    arranque: NO debería hacer falta streaming.
teleport(300, 152)
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local mid_x, mid_cam = x16(), camera16()
local mid_cam_ok = mid_cam == expected_camera(mid_x) -- 300-120=180
local mid_no_stream = memory.readbyte(NT_SLOT0) == 0 and memory.readbyte(NT_SLOT1) == 1
	and memory.readbyte(STREAM_ACTIVE) == 0
log(string.format(
	"pantalla1_sin_streaming: x=%d camera=%d (esperado 180) sin_streaming=%s slot0=%d slot1=%d stream_active=%d",
	mid_x, mid_cam, tostring(mid_no_stream),
	memory.readbyte(NT_SLOT0), memory.readbyte(NT_SLOT1), memory.readbyte(STREAM_ACTIVE)
))

-- 3) Teletransporta bien adentro de la pantalla 2 (x=700, zona segura
--    después del peligro de la columna 40). camera debe recortarse al
--    máximo (512, LEVEL_WIDTH_PX-256) y la pantalla lógica 2 debe
--    transmitirse al nametable físico que le toca (slot = 2 AND 1 = 0,
--    el mismo que hoy tiene la pantalla 0). Offset $98 en el nametable
--    es el tile superior-izquierdo de la nube en fila 2, columna 44 de
--    la pantalla 2 (fila local 2, columna local 12: (2*2)*32+(12*2)=152=$98)
--    -- 0 (T_BLANK) antes de transmitir, 1 (T_CLOUD) después.
local cloud_tile_before = ppu.readbyte(0x2098)
teleport(700, 152)

local stream_completed = false
local frames_waited = 0
for i = 1, 160 do
	joypad.set(1, {})
	emu.frameadvance()
	frames_waited = i
	if memory.readbyte(NT_SLOT0) == 2 and memory.readbyte(STREAM_ACTIVE) == 0 then
		stream_completed = true
		break
	end
end
local far_x, far_cam = x16(), camera16()
local far_cam_ok = far_cam == 512
local cloud_tile_after = ppu.readbyte(0x2098)
log(string.format(
	"pantalla2_streaming: x=%d camera=%d (esperado 512) slot0=%d completo=%s frames=%d tile_nube_antes=%d tile_nube_despues=%d",
	far_x, far_cam, memory.readbyte(NT_SLOT0), tostring(stream_completed), frames_waited,
	cloud_tile_before, cloud_tile_after
))
local streaming_ok = far_cam_ok and stream_completed and cloud_tile_before ~= 1 and cloud_tile_after == 1

-- 4) Colisión más allá de los primeros 256px de mundo: desde una
--    posición segura justo antes del peligro de la columna 40
--    (píxeles 640-655), camina a la derecha de verdad y confirma que
--    SÍ entra en HURT -- ejercita get_tile_collision con col_x_hi=2,
--    el camino de 16 bits que no existía antes de F4.2.
teleport(620, 152)
for _ = 1, 10 do
	joypad.set(1, {})
	emu.frameadvance()
end
local saw_hurt_far = false
for _ = 1, 60 do
	joypad.set(1, { right = true })
	emu.frameadvance()
	if memory.readbyte(STATE) == STATE_HURT then
		saw_hurt_far = true
		break
	end
end
log(string.format("peligro_pantalla2: vio_hurt=%s (col_x_hi=2, x=%d)", tostring(saw_hurt_far), x16()))

gui.savescreenshotas("/tmp/fceux_test_scrolling.png")

log("aparece_con_camara_en_0=" .. tostring(spawn_ok))
log("camara_sigue_al_caminar=" .. tostring(walk_cam_ok))
log("sin_streaming_en_pantalla0=" .. tostring(walk_no_stream))
log("sin_streaming_en_pantalla1=" .. tostring(mid_cam_ok and mid_no_stream))
log("streaming_real_hacia_pantalla2=" .. tostring(streaming_ok))
log("colision_funciona_mas_alla_de_256px=" .. tostring(saw_hurt_far))

local pass = spawn_ok and walk_cam_ok and walk_no_stream and mid_cam_ok and mid_no_stream
	and streaming_ok and saw_hurt_far
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
