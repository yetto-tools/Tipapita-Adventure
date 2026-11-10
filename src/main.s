; Chiquito y los Pipapitas — punto de entrada mínimo (F1.1: toolchain y build)
;
; Alcance deliberado de este archivo en esta fase: lo mínimo que produce una
; ROM .nes válida y enlazable para Mapper 4 (MMC3). NO incluye todavía:
;   - secuencia real de inicialización de pila/PPU/APU (F1.2),
;   - manejo de NMI/IRQ, cola de PPU u OAM DMA (F1.3).
; Esas fases reemplazarán el cuerpo de `reset`/`nmi`/`irq` más adelante.

.segment "HEADER"
    .byte "NES", $1A       ; firma iNES
    .byte 8                 ; PRG-ROM: 8 bancos de 16 KB = 128 KB (ver ARCHITECTURE.md §9)
    .byte 16                ; CHR-ROM: 16 bancos de 8 KB = 128 KB
    ; Flags 6: nibble bajo del mapper (4 = MMC3) en bits 4-7, bit 0 = mirroring.
    ; El bit de mirroring aquí es PROVISIONAL: este milestone no toca VRAM/
    ; nametables, así que no tiene efecto todavía. Además, en MMC3 el registro
    ; de mirroring del propio mapper ($A000) manda en tiempo de ejecución una
    ; vez que el código lo programe. No tratar este bit como decisión final;
    ; confirmar con la documentación de NESdev al implementar scrolling (Fase 4).
    .byte $40
    .byte $00               ; Flags 7: nibble alto del mapper = 0, iNES 1.0 (no NES 2.0)
    .byte $00               ; PRG-RAM: no se usa todavía
    .byte $00               ; TV system: 0 = NTSC (ver decisión F0.2)
    .byte $00               ; reservado
    .byte $00, $00, $00, $00, $00 ; relleno obligatorio iNES (bytes 11-15)

.segment "VECTORS"
    .addr nmi
    .addr reset
    .addr irq

.segment "STARTUP"

.proc reset
    sei                     ; sin manejo real de interrupciones todavía
    cld                     ; el 2A03 no tiene modo decimal, pero se limpia por convención
forever:
    jmp forever             ; placeholder explícito: la inicialización real llega en F1.2
.endproc

.proc nmi
    rti                     ; placeholder explícito: el manejo real llega en F1.3
.endproc

.proc irq
    rti                     ; placeholder explícito: no se usa IRQ todavía (sin mapper IRQ programado)
.endproc
