; ---------------------------------------------------------------------------
; overlays.asm - In-game overlay screens
; ---------------------------------------------------------------------------
; Get ready, game over, pause, and quit confirmation screens.
; These are drawn over the game area during play.
; ---------------------------------------------------------------------------

.export show_get_ready
.export show_game_over
.export show_pause_screen
.export show_quit_confirm

.import platform_putc
.import platform_gotoxy
.import platform_getkey
.import platform_set_color
.import platform_wait_vsync
.import draw_full_frame
.import sfx_update
.import sfx_play_get_ready
.import COLOR_GREEN

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; show_get_ready
;   Displays "GET READY!" and plays the get ready jingle.
;   Blocks for ~3 seconds, then returns.
; ---------------------------------------------------------------------------

.proc show_get_ready
    lda COLOR_GREEN
    jsr platform_set_color

    ldx #15
    ldy #14
    jsr platform_gotoxy

    ldx #0
@loop:
    lda get_ready_text, x
    beq @wait
    jsr platform_putc
    inx
    bne @loop

@wait:
    jsr sfx_play_get_ready
    lda #180
    sta delay_count
@delay:
    jsr platform_wait_vsync
    jsr sfx_update
    dec delay_count
    bne @delay
    rts
.endproc

; ---------------------------------------------------------------------------
; show_game_over
;   Displays "GAME OVER!" text on screen.
; ---------------------------------------------------------------------------

.proc show_game_over
    lda COLOR_GREEN
    jsr platform_set_color

    ldx #15
    ldy #14
    jsr platform_gotoxy

    ldx #0
@loop:
    lda game_over_text, x
    beq @done
    jsr platform_putc
    inx
    bne @loop
@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; show_pause_screen
;   Displays "GAME PAUSED" and waits for any key to resume.
; ---------------------------------------------------------------------------

.proc show_pause_screen
    jsr draw_full_frame

    lda COLOR_GREEN
    jsr platform_set_color

    ldx #15
    ldy #14
    jsr platform_gotoxy

    ldx #0
@loop:
    lda paused_text, x
    beq @wait
    jsr platform_putc
    inx
    bne @loop

@wait:
    jsr platform_getkey
    rts
.endproc

; ---------------------------------------------------------------------------
; show_quit_confirm
;   Displays "ARE YOU SURE?" and waits for Y/N.
;   Returns: A = 1 (yes, quit), A = 0 (no, continue)
; ---------------------------------------------------------------------------

.proc show_quit_confirm
    jsr draw_full_frame

    lda COLOR_GREEN
    jsr platform_set_color

    ldx #12
    ldy #12
    jsr platform_gotoxy
    ldx #0
@line1:
    lda quit_line1_text, x
    beq @line2_setup
    jsr platform_putc
    inx
    bne @line1

@line2_setup:
    ldx #14
    ldy #14
    jsr platform_gotoxy
    ldx #0
@line2:
    lda quit_line2_text, x
    beq @options
    jsr platform_putc
    inx
    bne @line2

@options:
    ldx #12
    ldy #18
    jsr platform_gotoxy
    ldx #0
@yes_msg:
    lda quit_yes_text, x
    beq @no_setup
    jsr platform_putc
    inx
    bne @yes_msg

@no_setup:
    ldx #13
    ldy #20
    jsr platform_gotoxy
    ldx #0
@no_msg:
    lda quit_no_text, x
    beq @input
    jsr platform_putc
    inx
    bne @no_msg

@input:
    jsr platform_getkey
    cmp #'Y'
    beq @do_yes
    cmp #'y'
    beq @do_yes
    cmp #'N'
    beq @do_no
    cmp #'n'
    beq @do_no
    bra @input

@do_yes:
    lda #1
    rts

@do_no:
    lda #0
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "RODATA"

get_ready_text:
    .byte "GET READY!", $00

game_over_text:
    .byte "GAME OVER!", $00

paused_text:
    .byte "GAME PAUSED", $00

quit_line1_text:
    .byte "ARE YOU SURE YOU", $00

quit_line2_text:
    .byte "WANT TO QUIT?", $00

quit_yes_text:
    .byte "PRESS Y FOR YES", $00

quit_no_text:
    .byte "PRESS N FOR NO", $00

; ---------------------------------------------------------------------------

.segment "BSS"

delay_count: .res 1
