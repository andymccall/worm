; platform.asm - Neo6502 platform

.import main

.export platform_init
.export platform_putc
.export platform_exit
.export platform_cls
.export platform_gotoxy
.export platform_setcolor
.export platform_getkey

.export CHAR_HLINE, CHAR_VLINE
.export CHAR_TL, CHAR_TR, CHAR_BL, CHAR_BR
.export COLOR_GREEN

; ---------------------------------------------------------------------------
; Neo6502 KERNAL vectors

WriteCharacter = $FFF1
ReadCharacter  = $FFEE

; ---------------------------------------------------------------------------
; Neo6502 API registers

API_COMMAND    = $FF00
API_FUNCTION   = $FF01
API_PARAMETERS = $FF04

; API groups
API_GROUP_CONSOLE = $02

; Console functions
API_FN_READ_CHAR      = $01
API_FN_WRITE_CHAR     = $06
API_FN_SET_CURSOR_POS = $07
API_FN_CLEAR_SCREEN   = $0C

; ---------------------------------------------------------------------------

.segment "STARTUP"
    jmp main

; ---------------------------------------------------------------------------

.segment "CODE"

.proc platform_init
    rts
.endproc

.proc platform_cls
@wait:
    lda API_COMMAND
    bne @wait
    lda #API_FN_CLEAR_SCREEN
    sta API_FUNCTION
    lda #API_GROUP_CONSOLE
    sta API_COMMAND
    rts
.endproc

.proc platform_putc
    ; A = character to print; preserves X, Y
    jsr WriteCharacter
    rts
.endproc

.proc platform_gotoxy
    ; Input: X = column, Y = row
    ; Preserves: X, Y
@wait:
    lda API_COMMAND
    bne @wait
    stx API_PARAMETERS + 0
    sty API_PARAMETERS + 1
    lda #API_FN_SET_CURSOR_POS
    sta API_FUNCTION
    lda #API_GROUP_CONSOLE
    sta API_COMMAND
    rts
.endproc

.proc platform_setcolor
    ; A = color control code ($80-$8F)
    jsr WriteCharacter
    rts
.endproc

.proc platform_getkey
    ; Returns: A = key pressed (blocking)
    jsr ReadCharacter
    rts
.endproc

.proc platform_exit
@halt:
    jmp @halt
.endproc

; ---------------------------------------------------------------------------

.segment "RODATA"

; ASCII box-drawing characters
CHAR_HLINE: .byte '-'
CHAR_VLINE: .byte '|'
CHAR_TL:    .byte '+'
CHAR_TR:    .byte '+'
CHAR_BL:    .byte '+'
CHAR_BR:    .byte '+'

; Neo6502 console color control code
COLOR_GREEN: .byte $82
