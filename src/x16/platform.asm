; platform.asm - Commander X16 platform

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
; KERNAL routines

CHROUT      = $FFD2
PLOT        = $FFF0
GETIN       = $FFE4
SCREEN_MODE = $FF5F

; Screen mode: 40 columns, 30 rows, PETSCII
; Bit 7 = 40 cols, Bit 1 = 30 rows

SCRMODE_40x30 = $82

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
    lda #SCRMODE_40x30
    clc
    jsr SCREEN_MODE
    rts
.endproc

.proc platform_cls
    lda #$93            ; PETSCII clear screen
    jsr CHROUT
    rts
.endproc

.proc platform_putc
    ; A = character to print; preserves X, Y
    jsr CHROUT
    rts
.endproc

.proc platform_gotoxy
    ; Input: X = column, Y = row
    ; Preserves: X, Y
    stx save_col
    sty save_row
    tya                 ; A = row
    tax                 ; X = row (for PLOT)
    ldy save_col        ; Y = column (for PLOT)
    clc
    jsr PLOT
    ldx save_col
    ldy save_row
    rts
.endproc

.proc platform_setcolor
    ; A = PETSCII color control code
    jsr CHROUT
    rts
.endproc

.proc platform_getkey
    ; Returns: A = key pressed (blocking)
@wait:
    jsr GETIN
    cmp #0
    beq @wait
    rts
.endproc

.proc platform_exit
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "BSS"

save_col: .res 1
save_row: .res 1

; ---------------------------------------------------------------------------

.segment "RODATA"

; PETSCII box-drawing characters (for CHROUT in uppercase mode)
CHAR_HLINE: .byte $C0
CHAR_VLINE: .byte $DD
CHAR_TL:    .byte $B0
CHAR_TR:    .byte $AE
CHAR_BL:    .byte $AD
CHAR_BR:    .byte $BD

; PETSCII color control code
COLOR_GREEN: .byte $1E
