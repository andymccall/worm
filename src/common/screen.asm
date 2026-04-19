; screen.asm - Start screen

.export show_start_screen
.export draw_border

.export gfx_x1, gfx_y1, gfx_x2, gfx_y2

.import platform_cls
.import platform_putc
.import platform_gotoxy
.import platform_getkey
.import platform_set_color
.import platform_draw_line

.import COLOR_GREEN

; Screen dimensions (pixels)
SCREEN_W = 320
SCREEN_H = 240

; Border margin (pixels)
BORDER_MARGIN = 10

; Border coordinates (pixels)
BORDER_X1 = BORDER_MARGIN
BORDER_Y1 = BORDER_MARGIN
BORDER_X2 = SCREEN_W - BORDER_MARGIN - 1
BORDER_Y2 = SCREEN_H - BORDER_MARGIN - 1

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; show_start_screen
;   Draws the start screen with line border, title, and menu.
;   Returns: A = 1 (start game) or A = 0 (quit)
; ---------------------------------------------------------------------------

.proc show_start_screen
    jsr platform_cls

    ; Set green drawing/text color
    lda COLOR_GREEN
    jsr platform_set_color

    ; Draw line border
    jsr draw_border

    ; --- Title "W O R M" centered at row 10 ---
    ldx #17             ; col (40 - 7) / 2 rounded up
    ldy #10             ; row
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
    ldx #14             ; col
    ldy #18             ; row
    jsr platform_gotoxy
    ldx #0
@start_msg:
    lda start_text, x
    beq @quit_msg
    jsr platform_putc
    inx
    bne @start_msg

@quit_msg:
    ldx #15
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
; draw_border
;   Draws the green line border. Assumes color is already set.
; ---------------------------------------------------------------------------

.proc draw_border
    ; Top line
    lda #<BORDER_X1
    sta gfx_x1
    lda #>BORDER_X1
    sta gfx_x1+1
    lda #<BORDER_Y1
    sta gfx_y1
    lda #>BORDER_Y1
    sta gfx_y1+1
    lda #<BORDER_X2
    sta gfx_x2
    lda #>BORDER_X2
    sta gfx_x2+1
    lda #<BORDER_Y1
    sta gfx_y2
    lda #>BORDER_Y1
    sta gfx_y2+1
    jsr platform_draw_line

    ; Bottom line
    lda #<BORDER_X1
    sta gfx_x1
    lda #>BORDER_X1
    sta gfx_x1+1
    lda #<BORDER_Y2
    sta gfx_y1
    lda #>BORDER_Y2
    sta gfx_y1+1
    lda #<BORDER_X2
    sta gfx_x2
    lda #>BORDER_X2
    sta gfx_x2+1
    lda #<BORDER_Y2
    sta gfx_y2
    lda #>BORDER_Y2
    sta gfx_y2+1
    jsr platform_draw_line

    ; Left line
    lda #<BORDER_X1
    sta gfx_x1
    lda #>BORDER_X1
    sta gfx_x1+1
    lda #<BORDER_Y1
    sta gfx_y1
    lda #>BORDER_Y1
    sta gfx_y1+1
    lda #<BORDER_X1
    sta gfx_x2
    lda #>BORDER_X1
    sta gfx_x2+1
    lda #<BORDER_Y2
    sta gfx_y2
    lda #>BORDER_Y2
    sta gfx_y2+1
    jsr platform_draw_line

    ; Right line
    lda #<BORDER_X2
    sta gfx_x1
    lda #>BORDER_X2
    sta gfx_x1+1
    lda #<BORDER_Y1
    sta gfx_y1
    lda #>BORDER_Y1
    sta gfx_y1+1
    lda #<BORDER_X2
    sta gfx_x2
    lda #>BORDER_X2
    sta gfx_x2+1
    lda #<BORDER_Y2
    sta gfx_y2
    lda #>BORDER_Y2
    sta gfx_y2+1
    jsr platform_draw_line
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

; ---------------------------------------------------------------------------

.segment "BSS"

gfx_x1: .res 2
gfx_y1: .res 2
gfx_x2: .res 2
gfx_y2: .res 2
