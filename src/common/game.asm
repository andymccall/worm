; game.asm - Game logic

.export game_run

.import platform_cls
.import platform_set_color
.import platform_draw_line
.import platform_draw_filled_rect
.import platform_poll_input
.import platform_wait_vsync
.import platform_gotoxy
.import platform_putc
.import platform_getkey
.import platform_random
.import gfx_x1, gfx_y1, gfx_x2, gfx_y2
.import COLOR_GREEN
.import COLOR_RED
.import draw_border

; Direction constants (must match across all files)
DIR_NONE  = 0
DIR_UP    = 1
DIR_DOWN  = 2
DIR_LEFT  = 3
DIR_RIGHT = 4

; Action input codes (must match platform)
INPUT_PAUSE = 5
INPUT_QUIT  = 6

; Grid setup
CELL_SIZE  = 8
GRID_X     = 12        ; pixel offset of first cell column
GRID_Y     = 12        ; pixel offset of first cell row
GRID_COLS  = 37
GRID_ROWS  = 27

; Movement timing (frames between moves)
MOVE_DELAY = 8

; Color indices
COLOR_BLACK = 0

; Maximum worm length
MAX_LENGTH = 255

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; game_run
; ---------------------------------------------------------------------------

.proc game_run
    jsr show_get_ready
    jsr game_init
    jsr game_loop
    rts
.endproc

; ---------------------------------------------------------------------------
; show_get_ready
; ---------------------------------------------------------------------------

.proc show_get_ready
    jsr platform_cls

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
    lda #180
    sta delay_count
@delay:
    jsr platform_wait_vsync
    dec delay_count
    bne @delay
    rts
.endproc

; ---------------------------------------------------------------------------
; game_init
;   Initialises worm body (3 segments), direction, and first food.
; ---------------------------------------------------------------------------

.proc game_init
    ; Worm starts as 3 segments in the centre, moving right
    lda #3
    sta worm_len

    ; Head at centre
    lda #(GRID_COLS / 2)
    sta body_x + 0
    lda #(GRID_ROWS / 2)
    sta body_y + 0

    ; Second segment (one left of head)
    lda #(GRID_COLS / 2 - 1)
    sta body_x + 1
    lda #(GRID_ROWS / 2)
    sta body_y + 1

    ; Third segment (two left of head)
    lda #(GRID_COLS / 2 - 2)
    sta body_x + 2
    lda #(GRID_ROWS / 2)
    sta body_y + 2

    lda #DIR_RIGHT
    sta worm_dir

    lda #0
    sta frame_count
    sta grow_flag

    jsr spawn_food
    rts
.endproc

; ---------------------------------------------------------------------------
; game_loop
; ---------------------------------------------------------------------------

.proc game_loop
    jsr platform_cls
    lda COLOR_GREEN
    jsr platform_set_color
    jsr draw_border

    ; Draw initial worm and food
    jsr draw_all_segments
    jsr draw_food

@loop:
    jsr platform_wait_vsync

    jsr platform_poll_input

    cmp #INPUT_PAUSE
    beq @do_pause
    cmp #INPUT_QUIT
    beq @do_quit

    cmp #DIR_NONE
    beq @no_input
    jsr check_direction
@no_input:

    inc frame_count
    lda frame_count
    cmp #MOVE_DELAY
    bcc @loop

    lda #0
    sta frame_count

    ; Erase tail (unless growing)
    lda grow_flag
    bne @skip_erase
    jsr erase_tail
@skip_erase:

    ; Advance body: shift all segments down, insert new head
    jsr advance_body

    ; Check border collision
    jsr check_collision
    bcs @game_over

    ; Check self collision
    jsr check_self_collision
    bcs @game_over

    ; Check food collision
    jsr check_food
    bne @no_food
    ; Ate food — set grow flag for next move and spawn new food
    lda #1
    sta grow_flag
    jsr spawn_food
    jsr draw_food
    jmp @draw_head
@no_food:
    lda #0
    sta grow_flag

@draw_head:
    ; Draw the new head segment
    lda body_x
    sta cell_x
    lda body_y
    sta cell_y
    jsr draw_segment

    jmp @loop

@do_pause:
    jsr show_pause_screen
    jsr redraw_game
    jmp @loop

@do_quit:
    jsr show_quit_confirm
    cmp #1
    beq @quit_yes
    jsr redraw_game
    jmp @loop
@quit_yes:
    rts

@game_over:
    jsr show_game_over
    lda #180
    sta delay_count
@delay:
    jsr platform_wait_vsync
    dec delay_count
    bne @delay
    rts
.endproc

; ---------------------------------------------------------------------------
; redraw_game
;   Redraws the full game screen after pause/quit-cancel.
; ---------------------------------------------------------------------------

.proc redraw_game
    jsr platform_cls
    lda COLOR_GREEN
    jsr platform_set_color
    jsr draw_border
    jsr draw_all_segments
    jsr draw_food
    rts
.endproc

; ---------------------------------------------------------------------------
; advance_body
;   Shifts body segments down. If grow_flag is set, length increases by 1.
;   New head position computed from direction.
; ---------------------------------------------------------------------------

.proc advance_body
    ; If growing, increase length first
    lda grow_flag
    beq @shift

    lda worm_len
    cmp #MAX_LENGTH
    bcs @shift              ; can't grow beyond max
    inc worm_len

@shift:
    ; Shift all segments down by one (tail towards head)
    ldx worm_len
    dex                     ; X = last valid index
@loop:
    cpx #0
    beq @done_shift
    lda body_x - 1, x
    sta body_x, x
    lda body_y - 1, x
    sta body_y, x
    dex
    bne @loop
@done_shift:

    ; Compute new head from old head (now at index 1)
    lda body_x + 1
    sta body_x
    lda body_y + 1
    sta body_y

    lda worm_dir
    cmp #DIR_UP
    bne @not_up
    dec body_y
    rts
@not_up:
    cmp #DIR_DOWN
    bne @not_down
    inc body_y
    rts
@not_down:
    cmp #DIR_LEFT
    bne @not_left
    dec body_x
    rts
@not_left:
    inc body_x
    rts
.endproc

; ---------------------------------------------------------------------------
; check_direction
; ---------------------------------------------------------------------------

.proc check_direction
    tax
    lda worm_dir

    cpx #DIR_UP
    bne @not_up
    cmp #DIR_DOWN
    beq @reject
    bra @accept
@not_up:
    cpx #DIR_DOWN
    bne @not_down
    cmp #DIR_UP
    beq @reject
    bra @accept
@not_down:
    cpx #DIR_LEFT
    bne @not_left
    cmp #DIR_RIGHT
    beq @reject
    bra @accept
@not_left:
    cpx #DIR_RIGHT
    bne @reject
    cmp #DIR_LEFT
    beq @reject
@accept:
    stx worm_dir
@reject:
    rts
.endproc

; ---------------------------------------------------------------------------
; check_collision
;   Checks if head has hit the border. Returns: C=1 if collision.
; ---------------------------------------------------------------------------

.proc check_collision
    lda body_x
    bmi @hit
    cmp #GRID_COLS
    bcs @hit

    lda body_y
    bmi @hit
    cmp #GRID_ROWS
    bcs @hit

    clc
    rts
@hit:
    sec
    rts
.endproc

; ---------------------------------------------------------------------------
; check_self_collision
;   Checks if head overlaps any body segment. Returns: C=1 if collision.
; ---------------------------------------------------------------------------

.proc check_self_collision
    ldx #1
@loop:
    cpx worm_len
    bcs @no_hit

    lda body_x
    cmp body_x, x
    bne @next
    lda body_y
    cmp body_y, x
    beq @hit

@next:
    inx
    bra @loop

@no_hit:
    clc
    rts
@hit:
    sec
    rts
.endproc

; ---------------------------------------------------------------------------
; check_food
;   Checks if head is on the food. Returns: Z=1 if food eaten.
; ---------------------------------------------------------------------------

.proc check_food
    lda body_x
    cmp food_x
    bne @no
    lda body_y
    cmp food_y
    rts
@no:
    lda #1                  ; clear Z
    rts
.endproc

; ---------------------------------------------------------------------------
; spawn_food
;   Places food at a random location not occupied by the worm.
; ---------------------------------------------------------------------------

.proc spawn_food
@retry:
    ; Random X in 0..GRID_COLS-1
    jsr platform_random
@mod_x:
    cmp #GRID_COLS
    bcc @x_ok
    sbc #GRID_COLS
    bra @mod_x
@x_ok:
    sta food_x

    ; Random Y in 0..GRID_ROWS-1
    jsr platform_random
@mod_y:
    cmp #GRID_ROWS
    bcc @y_ok
    sbc #GRID_ROWS
    bra @mod_y
@y_ok:
    sta food_y

    ; Check food doesn't overlap worm body
    ldx #0
@check:
    cpx worm_len
    bcs @done
    lda food_x
    cmp body_x, x
    bne @next
    lda food_y
    cmp body_y, x
    beq @retry
@next:
    inx
    bra @check
@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_food
;   Draws a clover-leaf shape at the food position in red.
;   Four small filled rects arranged as a cross/clover.
; ---------------------------------------------------------------------------

.proc draw_food
    lda COLOR_RED
    jsr platform_set_color

    lda food_x
    sta cell_x
    lda food_y
    sta cell_y
    jsr calc_cell_pixel

    ; Top leaf: (px+2, py) to (px+5, py+2)
    clc
    lda cell_px
    adc #2
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    lda cell_py
    sta gfx_y1
    lda cell_py+1
    sta gfx_y1+1

    clc
    lda cell_px
    adc #5
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #2
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Bottom leaf: (px+2, py+5) to (px+5, py+7)
    clc
    lda cell_px
    adc #2
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda cell_py
    adc #5
    sta gfx_y1
    lda cell_py+1
    adc #0
    sta gfx_y1+1

    clc
    lda cell_px
    adc #5
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #7
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Left leaf: (px, py+2) to (px+2, py+5)
    lda cell_px
    sta gfx_x1
    lda cell_px+1
    sta gfx_x1+1

    clc
    lda cell_py
    adc #2
    sta gfx_y1
    lda cell_py+1
    adc #0
    sta gfx_y1+1

    clc
    lda cell_px
    adc #2
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #5
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Right leaf: (px+5, py+2) to (px+7, py+5)
    clc
    lda cell_px
    adc #5
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda cell_py
    adc #2
    sta gfx_y1
    lda cell_py+1
    adc #0
    sta gfx_y1+1

    clc
    lda cell_px
    adc #7
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #5
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_all_segments
;   Draws every segment of the worm body.
; ---------------------------------------------------------------------------

.proc draw_all_segments
    ldx #0
@loop:
    cpx worm_len
    bcs @done
    phx
    lda body_x, x
    sta cell_x
    lda body_y, x
    sta cell_y
    jsr draw_segment
    plx
    inx
    bra @loop
@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_segment
;   Draws one worm segment with rounded corners at cell_x, cell_y.
; ---------------------------------------------------------------------------

.proc draw_segment
    lda COLOR_GREEN
    jsr platform_set_color

    jsr calc_cell_pixel

    ; Vertical bar: (px+1, py) to (px+6, py+7)
    clc
    lda cell_px
    adc #1
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    lda cell_py
    sta gfx_y1
    lda cell_py+1
    sta gfx_y1+1

    clc
    lda cell_px
    adc #(CELL_SIZE - 2)
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #(CELL_SIZE - 1)
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Horizontal bar: (px, py+1) to (px+7, py+6)
    lda cell_px
    sta gfx_x1
    lda cell_px+1
    sta gfx_x1+1

    clc
    lda cell_py
    adc #1
    sta gfx_y1
    lda cell_py+1
    adc #0
    sta gfx_y1+1

    clc
    lda cell_px
    adc #(CELL_SIZE - 1)
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #(CELL_SIZE - 2)
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------
; erase_tail
;   Erases the last segment of the worm body.
; ---------------------------------------------------------------------------

.proc erase_tail
    ldx worm_len
    dex
    lda body_x, x
    sta cell_x
    lda body_y, x
    sta cell_y
    jsr erase_cell
    rts
.endproc

; ---------------------------------------------------------------------------
; erase_cell
;   Erases one cell at cell_x, cell_y by drawing a black filled rect.
; ---------------------------------------------------------------------------

.proc erase_cell
    lda #COLOR_BLACK
    jsr platform_set_color

    jsr calc_cell_pixel

    lda cell_px
    sta gfx_x1
    lda cell_px+1
    sta gfx_x1+1

    lda cell_py
    sta gfx_y1
    lda cell_py+1
    sta gfx_y1+1

    clc
    lda cell_px
    adc #(CELL_SIZE - 1)
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #(CELL_SIZE - 1)
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------
; calc_cell_pixel
;   Converts cell_x, cell_y to pixel coordinates in cell_px, cell_py.
; ---------------------------------------------------------------------------

.proc calc_cell_pixel
    lda cell_x
    sta cell_px
    lda #0
    sta cell_px+1

    asl cell_px
    rol cell_px+1
    asl cell_px
    rol cell_px+1
    asl cell_px
    rol cell_px+1

    clc
    lda cell_px
    adc #GRID_X
    sta cell_px
    lda cell_px+1
    adc #0
    sta cell_px+1

    lda cell_y
    sta cell_py
    lda #0
    sta cell_py+1

    asl cell_py
    rol cell_py+1
    asl cell_py
    rol cell_py+1
    asl cell_py
    rol cell_py+1

    clc
    lda cell_py
    adc #GRID_Y
    sta cell_py
    lda cell_py+1
    adc #0
    sta cell_py+1
    rts
.endproc

; ---------------------------------------------------------------------------
; show_game_over
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
; ---------------------------------------------------------------------------

.proc show_pause_screen
    jsr platform_cls

    lda COLOR_GREEN
    jsr platform_set_color
    jsr draw_border

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
; ---------------------------------------------------------------------------

.proc show_quit_confirm
    jsr platform_cls

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

worm_dir:    .res 1          ; current direction
worm_len:    .res 1          ; current body length
frame_count: .res 1          ; frame counter for movement timing
delay_count: .res 1          ; general delay counter
grow_flag:   .res 1          ; 1 = grow on next move

food_x:      .res 1          ; food grid column
food_y:      .res 1          ; food grid row

cell_x:      .res 1          ; temp grid x for drawing
cell_y:      .res 1          ; temp grid y for drawing
cell_px:     .res 2          ; temp pixel x (16-bit)
cell_py:     .res 2          ; temp pixel y (16-bit)

body_x:      .res MAX_LENGTH ; grid x for each segment (0 = head)
body_y:      .res MAX_LENGTH ; grid y for each segment (0 = head)
