-- Prueba de humo para F1.3 (NMI/IRQ).
-- Verifica, de forma automatizada:
--   1. Que frame_count ($0000 ZP + 1 = $0001) avanza en sincronía con los
--      frames reales (una vez por NMI, ni más ni menos) — confirma que el
--      NMI se dispara de forma estable, no se duplica ni se pierde.
--   2. Que la OAM DMA no cuelga ni corrompe la ejecución (el CPU sigue
--      estable en el banco fijo después de varias docenas de NMIs).
--   3. Que no hubo overflow en la cola de PPU (ppu_queue_overflow == 0),
--      esperado porque todavía nada la usa.
-- No valida contenido gráfico nuevo (sigue sin haber nametables/CHR reales).

local FRAME_COUNT_ADDR = 0x0001
local PPU_QUEUE_OVERFLOW_ADDR = 0x0301 -- ppu_queue_len($0300) + 1

local out = io.open("/tmp/fceux_test_nmi.txt", "w")
local function log(line)
	out:write(line .. "\n")
end

-- Deja que termine el reset. F4.2: `reset` ahora copia 2 pantallas de
-- nametable en vez de 1 (ver src/main.s), así que tarda más frames
-- reales en terminar que antes (~7, no ~5) -- en vez de asumir un
-- número fijo de frames, se espera a la señal real de que el main loop
-- ya corrió al menos una vez (frame_count > 0), con un tope de
-- seguridad para no colgarse si algo realmente se rompe.
local booted = false
for _ = 1, 60 do
	emu.frameadvance()
	if memory.readbyte(FRAME_COUNT_ADDR) > 0 then
		booted = true
		break
	end
end

local count_before = memory.readbyte(FRAME_COUNT_ADDR)
local N = 20
for _ = 1, N do
	emu.frameadvance()
end
local count_after = memory.readbyte(FRAME_COUNT_ADDR)

-- frame_count es un byte de 8 bits: puede dar la vuelta (wrap) si count_before
-- está cerca de 255, por eso se compara con aritmética módulo 256.
local delta = (count_after - count_before) % 256

local pc = memory.getregister("pc")
local pc_in_fixed_bank = (pc >= 0xC000 and pc <= 0xFFF9)

local overflow = memory.readbyte(PPU_QUEUE_OVERFLOW_ADDR)

log(string.format("reset_termino=%s", tostring(booted)))
log(string.format("frame_count antes=%d despues=%d delta=%d (esperado=%d)", count_before, count_after, delta, N))
log(string.format("PC=$%04X en_banco_fijo=%s", pc, tostring(pc_in_fixed_bank)))
log(string.format("ppu_queue_overflow=%d", overflow))

local pass = booted and (delta == N) and pc_in_fixed_bank and (overflow == 0)
log("RESULT=" .. (pass and "PASS" or "FAIL"))
out:close()
emu.exit()
