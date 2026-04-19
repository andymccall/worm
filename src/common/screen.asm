; screen.asm - Start screen

.export show_start_screen
.export show_about_screen
.export draw_border

.export gfx_x1, gfx_y1, gfx_x2, gfx_y2

.import platform_cls
.import platform_putc
.import platform_gotoxy
.import platform_getkey
.import platform_check_key
.import platform_wait_vsync
.import platform_set_color
.import platform_draw_line

.import COLOR_GREEN
.import COLOR_BLUE
.import draw_status_bar

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

; Divider line between status bar and game area
DIVIDER_Y = 24

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; show_start_screen
;   Draws the start screen with line border, title, and menu.
;   Returns: A = 1 (start), A = 2 (about), A = 3 (demo), A = 0 (quit)
; ---------------------------------------------------------------------------

.proc show_start_screen
    jsr platform_cls

    ; Set green drawing/text color
    lda COLOR_GREEN
    jsr platform_set_color

    ; Draw line border
    jsr draw_border

    ; Draw status bar (Food count + Lives)
    jsr draw_status_bar

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

    ; --- Menu options in blue ---
@menu:
    lda COLOR_BLUE
    jsr platform_set_color

    ldx #16             ; col
    ldy #16             ; row
    jsr platform_gotoxy
    ldx #0
@start_msg:
    lda start_text, x
    beq @about_msg_setup
    jsr platform_putc
    inx
    bne @start_msg

@about_msg_setup:
    ldx #16
    ldy #18
    jsr platform_gotoxy
    ldx #0
@about_msg:
    lda about_text, x
    beq @demo_msg_setup
    jsr platform_putc
    inx
    bne @about_msg

@demo_msg_setup:
    ldx #16
    ldy #20
    jsr platform_gotoxy
    ldx #0
@demo_msg:
    lda demo_text, x
    beq @quit_msg_setup
    jsr platform_putc
    inx
    bne @demo_msg

@quit_msg_setup:
    ldx #16
    ldy #22
    jsr platform_gotoxy
    ldx #0
@quit_loop:
    lda quit_text, x
    beq @flush
    jsr platform_putc
    inx
    bne @quit_loop

    ; --- Flush keyboard buffer ---
@flush:
    jsr platform_check_key
    cmp #0
    bne @flush

    ; --- Wait for S, A, D, Q or 30-second timeout ---
    ; Init timeout: 1800 frames = 30 seconds at 60 fps
    lda #<1800
    sta menu_timer
    lda #>1800
    sta menu_timer+1

@input:
    jsr platform_wait_vsync
    jsr platform_check_key
    cmp #0
    beq @dec_timer

    cmp #'S'
    beq @do_start
    cmp #'s'
    beq @do_start
    cmp #'A'
    beq @do_about
    cmp #'a'
    beq @do_about
    cmp #'D'
    beq @do_demo
    cmp #'d'
    beq @do_demo
    cmp #'Q'
    beq @do_quit
    cmp #'q'
    beq @do_quit

@dec_timer:
    ; Decrement 16-bit timeout counter
    lda menu_timer
    bne @dec_lo
    lda menu_timer+1
    beq @do_demo            ; timer expired -> demo
    dec menu_timer+1
@dec_lo:
    dec menu_timer
    bra @input

@do_start:
    lda #1
    rts

@do_about:
    lda #2
    rts

@do_demo:
    lda #3
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

    ; Divider line (separates status bar from game area)
    lda #<BORDER_X1
    sta gfx_x1
    lda #>BORDER_X1
    sta gfx_x1+1
    lda #<DIVIDER_Y
    sta gfx_y1
    lda #>DIVIDER_Y
    sta gfx_y1+1
    lda #<BORDER_X2
    sta gfx_x2
    lda #>BORDER_X2
    sta gfx_x2+1
    lda #<DIVIDER_Y
    sta gfx_y2
    lda #>DIVIDER_Y
    sta gfx_y2+1
    jsr platform_draw_line
    rts
.endproc

; ---------------------------------------------------------------------------
; show_about_screen
;   Displays the about screen. Border stays. Press any key to return.
; ---------------------------------------------------------------------------

.proc show_about_screen
    jsr platform_cls

    lda COLOR_GREEN
    jsr platform_set_color

    jsr draw_border

    ; Title
    ldx #17
    ldy #5
    jsr platform_gotoxy
    ldx #0
@title:
    lda title_text, x
    beq @written
    jsr platform_putc
    inx
    bne @title

@written:
    ldx #13
    ldy #8
    jsr platform_gotoxy
    ldx #0
@w1:
    lda about_written, x
    beq @author
    jsr platform_putc
    inx
    bne @w1

@author:
    ldx #15
    ldy #10
    jsr platform_gotoxy
    ldx #0
@a1:
    lda about_author, x
    beq @email
    jsr platform_putc
    inx
    bne @a1

@email:
    ldx #11
    ldy #12
    jsr platform_gotoxy
    ldx #0
@e1:
    lda about_email, x
    beq @repo
    jsr platform_putc
    inx
    bne @e1

@repo:
    ldx #7
    ldy #14
    jsr platform_gotoxy
    ldx #0
@r1:
    lda about_repo, x
    beq @avail1
    jsr platform_putc
    inx
    bne @r1

@avail1:
    ldx #9
    ldy #17
    jsr platform_gotoxy
    ldx #0
@av1:
    lda about_avail1, x
    beq @avail2
    jsr platform_putc
    inx
    bne @av1

@avail2:
    ldx #10
    ldy #19
    jsr platform_gotoxy
    ldx #0
@av2:
    lda about_avail2, x
    beq @avail3
    jsr platform_putc
    inx
    bne @av2

@avail3:
    ldx #15
    ldy #21
    jsr platform_gotoxy
    ldx #0
@av3:
    lda about_avail3, x
    beq @prompt
    jsr platform_putc
    inx
    bne @av3

@prompt:
    ldx #11
    ldy #23
    jsr platform_gotoxy
    ldx #0
@p1:
    lda about_prompt, x
    beq @wait
    jsr platform_putc
    inx
    bne @p1

@wait:
    jsr platform_getkey
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "RODATA"

title_text:
    .byte "W O R M", $00

start_text:
    .byte "[S] START", $00

about_text:
    .byte "[A] ABOUT", $00

demo_text:
    .byte "[D] DEMO", $00

quit_text:
    .byte "[Q] QUIT", $00

about_written:
    .byte "WRITTEN BY", $00

about_author:
    .byte "ANDY MCCALL", $00

about_email:
    .byte "MAILME@ANDYMCCALL.CO.UK", $00

about_repo:
    .byte "GITHUB.COM/ANDYMCCALL/WORM", $00

about_avail1:
    .byte "AVAILABLE FOR THE", $00

about_avail2:
    .byte "COMMANDER X16 AND", $00

about_avail3:
    .byte "THE NEO6502", $00

about_prompt:
    .byte "PRESS ANY KEY", $00

; ---------------------------------------------------------------------------

.segment "BSS"

gfx_x1: .res 2
gfx_y1: .res 2
gfx_x2: .res 2
gfx_y2: .res 2

menu_timer: .res 2         ; 16-bit frame counter for menu timeout
