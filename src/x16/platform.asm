; platform.s - Commander X16 platform

.import main

.export platform_init
.export platform_putc
.export platform_exit

CHROUT = $FFD2

; ---------------------------------------------------------------------------
; PRG load address

.segment "LOADADDR"
    .word $0801

; ---------------------------------------------------------------------------
; BASIC stub: 10 SYS2061

.segment "STARTUP"

basic_stub:
    .word basic_stub_end    ; pointer to next BASIC line
    .word 10                ; line number
    .byte $9E               ; SYS token
    .byte "2061"            ; entry address as decimal string
    .byte $00               ; end of BASIC line
basic_stub_end:
    .word $0000             ; end of BASIC program
    jmp main

; ---------------------------------------------------------------------------

.segment "CODE"

.proc platform_init
    rts
.endproc

.proc platform_putc
    jsr CHROUT
    rts
.endproc

.proc platform_exit
    rts
.endproc
