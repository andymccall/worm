; screen.asm - Start screen

.export show_start_screen

.import platform_cls
.import platform_putc
.import platform_gotoxy
.import platform_setcolor
.import platform_getkey

.import CHAR_HLINE, CHAR_VLINE
.import CHAR_TL, CHAR_TR, CHAR_BL, CHAR_BR
.import COLOR_GREEN

SCREEN_COLS  = 40
SCREEN_ROWS  = 30
BORDER_WIDTH = SCREEN_COLS - 2

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; show_start_screen
;   Draws the start screen with border, title, and menu.
;   Returns: A = 1 (start game) or A = 0 (quit)
; ---------------------------------------------------------------------------

.proc show_start_screen
    jsr platform_cls

    ; Set green text color
    lda COLOR_GREEN
    jsr platform_setcolor

    ; --- Top border (row 0) ---
    ldx #0
    ldy #0
    jsr platform_gotoxy
    lda CHAR_TL
    jsr platform_putc
    ldx #0
@top:
    lda CHAR_HLINE
    jsr platform_putc
    inx
    cpx #BORDER_WIDTH
    bne @top
    lda CHAR_TR
    jsr platform_putc

    ; --- Side borders (rows 1 to 28) ---
    ldy #1
@sides:
    ldx #0
    jsr platform_gotoxy
    lda CHAR_VLINE
    jsr platform_putc
    ldx #(SCREEN_COLS - 1)
    jsr platform_gotoxy
    lda CHAR_VLINE
    jsr platform_putc
    iny
    cpy #(SCREEN_ROWS - 1)
    bne @sides

    ; --- Bottom border (row 29) ---
    ldx #0
    ldy #(SCREEN_ROWS - 1)
    jsr platform_gotoxy
    lda CHAR_BL
    jsr platform_putc
    ldx #0
@bottom:
    lda CHAR_HLINE
    jsr platform_putc
    inx
    cpx #BORDER_WIDTH
    bne @bottom
    lda CHAR_BR
    jsr platform_putc

    ; --- Title "W O R M" centered at row 10 ---
    ldx #16             ; (40 - 7) / 2
    ldy #10
    jsr platform_gotoxy
    ldx #0
@title:
    lda title_text, x
    beq @menu
    jsr platform_putc
    inx
    bne @title

    ; --- Menu options ---
@menu:
    ldx #12             ; (40 - 16) / 2
    ldy #18
    jsr platform_gotoxy
    ldx #0
@start_msg:
    lda start_text, x
    beq @quit_msg
    jsr platform_putc
    inx
    bne @start_msg

@quit_msg:
    ldx #12
    ldy #20
    jsr platform_gotoxy
    ldx #0
@quit_loop:
    lda quit_text, x
    beq @input
    jsr platform_putc
    inx
    bne @quit_loop

    ; --- Wait for S or Q ---
@input:
    jsr platform_getkey
    cmp #'S'
    beq @do_start
    cmp #'s'
    beq @do_start
    cmp #'Q'
    beq @do_quit
    cmp #'q'
    beq @do_quit
    bra @input

@do_start:
    lda #1
    rts

@do_quit:
    lda #0
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "RODATA"

title_text:
    .byte "W O R M", $00

start_text:
    .byte "PRESS S TO START", $00

quit_text:
    .byte "PRESS Q TO QUIT", $00
