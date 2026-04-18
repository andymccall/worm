; platform.s - Neo6502 platform

.import main

.export platform_init
.export platform_putc
.export platform_exit

; ---------------------------------------------------------------------------
; Neo6502 API registers

API_COMMAND   = $FF00
API_FUNCTION  = $FF01
API_ERROR     = $FF02
API_STATUS    = $FF03
API_PARAM0    = $FF04

; API groups
API_GROUP_CONSOLE = 2

; Console functions
API_FN_WRITE_CHAR = 6

; ---------------------------------------------------------------------------

.segment "STARTUP"
    jmp main

; ---------------------------------------------------------------------------

.segment "CODE"

.proc platform_init
    rts
.endproc

.proc platform_putc
    sta API_PARAM0
    lda #API_FN_WRITE_CHAR
    sta API_FUNCTION
    lda #API_GROUP_CONSOLE
    sta API_COMMAND
    rts
.endproc

.proc platform_exit
@halt:
    jmp @halt
.endproc
