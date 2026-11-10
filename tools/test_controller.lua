-- Prueba de humo para F3.1 (controlador).
-- Simula entradas de mando con joypad.set de FCEUX y verifica, leyendo
-- la RAM real (no asumiendo), que read_controller1 normaliza:
--   $0009 pad1         -- botones sostenidos este frame
--   $000A pad1_prev    -- botones sostenidos el frame anterior
--   $000B pad1_pressed -- bits que pasaron de 0 a 1 este frame
--
-- Caso probado: sostener A+Right varios frames (pad1_pressed solo debe
-- encenderse en el primer frame), soltar, y presionar Down (un botón
-- distinto) para confirmar que se detecta como una pulsación nueva.

local PAD1, PAD1_PREV, PAD1_PRESSED = 0x0009, 0x000A, 0x000B
local BIT_A, BIT_RIGHT, BIT_DOWN = 0x80, 0x01, 0x04

local out = io.open("/tmp/fceux_test_controller.txt", "w")
local function log(line)
	out:write(line .. "\n")
end

local function has_bit(value, bit)
	return (math.floor(value / bit) % 2) == 1
end

local function hold(buttons, frames)
	local last_pad1, last_pressed
	for _ = 1, frames do
		joypad.set(1, buttons)
		emu.frameadvance()
		last_pad1 = memory.readbyte(PAD1)
		last_pressed = memory.readbyte(PAD1_PRESSED)
	end
	return last_pad1, last_pressed
end

-- Deja que termine el reset antes de empezar a simular input.
for _ = 1, 14 do
	emu.frameadvance()
end

-- Primer frame sosteniendo A+Right: debe verse como pulsación nueva.
local pad1_f1, pressed_f1 = hold({ A = true, right = true }, 1)
-- Frames siguientes sosteniendo lo mismo: ya NO debe ser "recién presionado".
local pad1_f2, pressed_f2 = hold({ A = true, right = true }, 5)

-- Soltar todo un frame.
local pad1_release, pressed_release = hold({}, 1)

-- Presionar un botón distinto (Down): debe verse como pulsación nueva otra vez.
local pad1_down, pressed_down = hold({ down = true }, 1)

log(string.format("f1:  pad1=%02X pressed=%02X", pad1_f1, pressed_f1))
log(string.format("f2+: pad1=%02X pressed=%02X", pad1_f2, pressed_f2))
log(string.format("release: pad1=%02X pressed=%02X", pad1_release, pressed_release))
log(string.format("down: pad1=%02X pressed=%02X", pad1_down, pressed_down))

local ok_f1 = has_bit(pad1_f1, BIT_A) and has_bit(pad1_f1, BIT_RIGHT)
	and has_bit(pressed_f1, BIT_A) and has_bit(pressed_f1, BIT_RIGHT)
local ok_f2_held_not_pressed = has_bit(pad1_f2, BIT_A) and has_bit(pad1_f2, BIT_RIGHT) and pressed_f2 == 0
local ok_release = pad1_release == 0 and pressed_release == 0
local ok_down = has_bit(pad1_down, BIT_DOWN) and has_bit(pressed_down, BIT_DOWN)

log("f1_detecta_pulsacion_nueva=" .. tostring(ok_f1))
log("f2_sostenido_sin_pulsacion_nueva=" .. tostring(ok_f2_held_not_pressed))
log("soltar_limpia_estado=" .. tostring(ok_release))
log("boton_distinto_es_pulsacion_nueva=" .. tostring(ok_down))

local pass = ok_f1 and ok_f2_held_not_pressed and ok_release and ok_down
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
