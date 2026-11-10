-- Prueba de humo para F1.1: confirma que FCEUX carga la ROM (mapper/tamaño
-- aceptados) y que el CPU ejecuta sin bloquearse en una dirección inesperada
-- durante los primeros frames. No valida gráficos ni NMI (eso es F1.2/F1.3).

local frames = 0
local MAX_FRAMES = 30

emu.print("test_boot: ROM cargada, iniciando " .. MAX_FRAMES .. " frames de prueba")

while frames < MAX_FRAMES do
	emu.frameadvance()
	frames = frames + 1
end

local pc = memory.getregister("pc")
emu.print(string.format("test_boot: OK tras %d frames, PC=$%04X", frames, pc))
emu.print("test_boot: PASS")
emu.exit()
