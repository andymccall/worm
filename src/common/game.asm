; game.asm - Game logic

.export game_run
.export game_reset_stats
.export draw_status_bar
.export demo_run

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
.import platform_check_key
.import gfx_x1, gfx_y1, gfx_x2, gfx_y2
.import COLOR_GREEN
.import COLOR_RED
.import COLOR_YELLOW
.import COLOR_LGRAY
.import draw_border
.import sfx_update
.import sfx_play_move
.import sfx_play_food
.import sfx_play_spider_appear
.import sfx_play_spider_eat
.import sfx_play_life_lost
.import sfx_play_vulnerable
.import sfx_play_game_over
.import sfx_play_get_ready

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
GRID_Y     = 26        ; pixel offset of first cell row (below status bar)
GRID_COLS  = 37
GRID_ROWS  = 25

; Movement timing (frames between moves)
MOVE_DELAY = 8

; Color indices
COLOR_BLACK = 0

; Maximum worm length
MAX_LENGTH = 255

; Border / status bar layout (must match screen.asm)
BORDER_X1  = 10
BORDER_Y1  = 10
BORDER_X2  = 309
BORDER_Y2  = 229
DIVIDER_Y  = 24

; Status bar hearts
STATUS_HEART_X_START = 244
STATUS_HEART_Y       = 14
STATUS_HEART_SPACING = 10
STATUS_HEART_MAX     = 6

; Spider constants
MAX_SPIDERS = 8

; Lives cap
MAX_LIVES = 3

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; game_run
; ---------------------------------------------------------------------------

.proc game_run
@start:
    ; Draw frame: border + status bar
    jsr draw_full_frame

    ; Show GET READY message
    jsr show_get_ready

    ; Init game state for this life
    jsr game_init

    ; Redraw frame for game play
    jsr draw_full_frame
    jsr draw_all_segments
    jsr draw_food
    jsr draw_all_spiders
    lda life_active
    beq @no_life
    jsr draw_life
@no_life:

    ; Run game loop
    jsr game_loop

    cmp #1
    beq @start          ; died with lives remaining - respawn
    rts                 ; game over or quit - return to main
.endproc

; ---------------------------------------------------------------------------
; show_get_ready
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
    sta life_active

    jsr spawn_food
    rts
.endproc

; ---------------------------------------------------------------------------
; game_loop
; ---------------------------------------------------------------------------

.proc game_loop

@loop:
    jsr platform_wait_vsync
    jsr sfx_update

    jsr platform_poll_input

    cmp #INPUT_PAUSE
    bne @not_pause
    jmp @do_pause
@not_pause:
    cmp #INPUT_QUIT
    bne @not_quit
    jmp @do_quit
@not_quit:

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

    ; Play move sound
    jsr sfx_play_move

    ; Erase tail (unless growing)
    lda grow_flag
    bne @skip_erase
    jsr erase_tail
@skip_erase:

    ; Advance body: shift all segments down, insert new head
    jsr advance_body

    ; Check border collision
    jsr check_collision
    bcc @no_border_hit
    jmp @collision
@no_border_hit:

    ; Check self collision
    jsr check_self_collision
    bcc @no_self_hit
    jmp @collision
@no_self_hit:

    ; Check spider collision
    jsr check_spider_collision
    bcc @no_spider_hit

    ; Spider hit - check if vulnerable
    lda spider_vulnerable
    beq @spider_kills
    ; Vulnerable: remove this spider instead of dying
    jsr remove_hit_spider
    lda #0
    sta spider_vulnerable
    jsr draw_all_spiders
    jsr sfx_play_spider_eat
    jmp @no_spider_hit
@spider_kills:
    jmp @collision
@no_spider_hit:

    ; Check food collision
    jsr check_food
    bne @no_food
    ; Ate food - grow, update count, handle life logic
    lda #1
    sta grow_flag
    inc food_count
    jsr sfx_play_food

    ; If life was active, remove it (ate food before life)
    lda life_active
    beq @no_life_remove
    jsr erase_life
    lda #0
    sta life_active
@no_life_remove:

    ; End spider vulnerability on food collection
    lda spider_vulnerable
    beq @no_vuln_end
    lda #0
    sta spider_vulnerable
    jsr draw_all_spiders
@no_vuln_end:

    ; Check if a life pickup should spawn (every 20 food)
    inc food_since_life
    lda food_since_life
    cmp #20
    bcc @no_life_spawn
    lda #0
    sta food_since_life

    ; Only spawn life if lives < MAX_LIVES
    lda lives
    cmp #MAX_LIVES
    bcs @lives_full
    jsr spawn_life
    lda #1
    sta life_active
    jsr draw_life
    jmp @no_life_spawn

@lives_full:
    ; Already at max lives - make spiders vulnerable instead
    lda spider_count
    beq @no_life_spawn
    lda #1
    sta spider_vulnerable
    jsr draw_all_spiders
    jsr sfx_play_vulnerable
@no_life_spawn:

    ; Check if a spider should spawn (every 10 food)
    inc food_since_spider
    lda food_since_spider
    cmp #10
    bcc @no_spider_spawn
    lda #0
    sta food_since_spider
    jsr spawn_spider
    jsr draw_all_spiders
    jsr sfx_play_spider_appear
@no_spider_spawn:

    jsr spawn_food
    jsr draw_food
    jsr draw_status_bar
    jmp @draw_head

@no_food:
    lda #0
    sta grow_flag

    ; Check life collision
    jsr check_life
    bne @draw_head

    ; Ate life - gain a life (capped at MAX_LIVES)
    lda lives
    cmp #MAX_LIVES
    bcs @skip_life_gain
    inc lives
@skip_life_gain:
    lda #0
    sta life_active
    lda life_x
    sta cell_x
    lda life_y
    sta cell_y
    jsr erase_cell
    jsr draw_status_bar

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
    lda #2              ; return code: quit
    rts

@collision:
    dec lives
    lda #0
    sta food_since_spider
    jsr draw_status_bar
    lda lives
    beq @real_game_over

    jsr sfx_play_life_lost
    ; Lives remaining - brief delay then respawn
    lda #60
    sta delay_count
@death_delay:
    jsr platform_wait_vsync
    jsr sfx_update
    dec delay_count
    bne @death_delay
    lda #1              ; return code: respawn
    rts

@real_game_over:
    jsr sfx_play_game_over
    jsr show_game_over
    lda #180
    sta delay_count
@go_delay:
    jsr platform_wait_vsync
    jsr sfx_update
    dec delay_count
    bne @go_delay
    lda #0              ; return code: game over
    rts
.endproc

; ---------------------------------------------------------------------------
; redraw_game
;   Redraws the full game screen after pause/quit-cancel.
; ---------------------------------------------------------------------------

.proc redraw_game
    jsr draw_full_frame
    jsr draw_all_segments
    jsr draw_food
    jsr draw_all_spiders
    lda life_active
    beq @no_life
    jsr draw_life
@no_life:
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
    ; Also check food doesn't overlap life
    lda life_active
    beq @ok
    lda food_x
    cmp life_x
    bne @ok
    lda food_y
    cmp life_y
    beq @retry
@ok:
    ; Also check food doesn't overlap any spider
    jsr check_pos_vs_spiders_food
    beq @retry
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_food
;   Draws a clover-leaf shape at the food position in red.
;   Four small filled rects arranged as a cross/clover.
; ---------------------------------------------------------------------------

.proc draw_food
    lda COLOR_YELLOW
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
; game_reset_stats
;   Initializes game stats to defaults.
; ---------------------------------------------------------------------------

.proc game_reset_stats
    lda #3
    sta lives
    lda #0
    sta food_count
    sta food_since_life
    sta life_active
    sta spider_count
    sta spider_head
    sta food_since_spider
    sta spider_vulnerable
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_full_frame
;   Full screen redraw: clear + border + status bar.
; ---------------------------------------------------------------------------

.proc draw_full_frame
    jsr platform_cls
    lda COLOR_GREEN
    jsr platform_set_color
    jsr draw_border
    jsr draw_status_bar
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_status_bar
;   Draws the status bar with food count and lives hearts.
; ---------------------------------------------------------------------------

.proc draw_status_bar
    ; Clear status area: black rect from (11,11) to (308,23)
    lda #COLOR_BLACK
    jsr platform_set_color

    lda #11
    sta gfx_x1
    lda #0
    sta gfx_x1+1
    lda #11
    sta gfx_y1
    lda #0
    sta gfx_y1+1
    lda #<308
    sta gfx_x2
    lda #>308
    sta gfx_x2+1
    lda #23
    sta gfx_y2
    lda #0
    sta gfx_y2+1
    jsr platform_draw_filled_rect

    ; Print "FOOD " in green
    lda COLOR_GREEN
    jsr platform_set_color
    ldx #2
    ldy #2
    jsr platform_gotoxy
    ldx #0
@food_text:
    lda food_label, x
    beq @print_count
    jsr platform_putc
    inx
    bne @food_text

@print_count:
    lda food_count
    jsr print_byte_decimal

    ; Print "LIVES " label
    ldx #24
    ldy #2
    jsr platform_gotoxy
    ldx #0
@lives_text:
    lda lives_label, x
    beq @draw_hearts
    jsr platform_putc
    inx
    bne @lives_text

@draw_hearts:
    ; Draw red hearts for each life
    lda COLOR_RED
    jsr platform_set_color

    ldx #0
    lda #<STATUS_HEART_X_START
    sta cell_px
    lda #>STATUS_HEART_X_START
    sta cell_px+1
    lda #STATUS_HEART_Y
    sta cell_py
    lda #0
    sta cell_py+1

@heart_loop:
    cpx lives
    bcs @done
    cpx #STATUS_HEART_MAX
    bcs @done

    phx
    jsr draw_heart
    plx

    ; Advance pixel X by spacing
    clc
    lda cell_px
    adc #STATUS_HEART_SPACING
    sta cell_px
    lda cell_px+1
    adc #0
    sta cell_px+1

    inx
    bra @heart_loop

@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; print_byte_decimal
;   Prints A as a 3-char right-justified decimal number (space-padded).
; ---------------------------------------------------------------------------

.proc print_byte_decimal
    cmp #100
    bcs @three_digits
    cmp #10
    bcs @two_digits

    ; One digit: "  N"
    pha
    lda #' '
    jsr platform_putc
    lda #' '
    jsr platform_putc
    pla
    clc
    adc #'0'
    jsr platform_putc
    rts

@two_digits:
    ; Two digits: " NN"
    pha
    lda #' '
    jsr platform_putc
    pla
    ldx #0
@t2_loop:
    cmp #10
    bcc @t2_done
    sbc #10
    inx
    bra @t2_loop
@t2_done:
    pha
    txa
    clc
    adc #'0'
    jsr platform_putc
    pla
    clc
    adc #'0'
    jsr platform_putc
    rts

@three_digits:
    ldx #0
@h_loop:
    cmp #100
    bcc @h_done
    sbc #100
    inx
    bra @h_loop
@h_done:
    pha
    txa
    clc
    adc #'0'
    jsr platform_putc
    pla
    ldx #0
@t3_loop:
    cmp #10
    bcc @t3_done
    sbc #10
    inx
    bra @t3_loop
@t3_done:
    pha
    txa
    clc
    adc #'0'
    jsr platform_putc
    pla
    clc
    adc #'0'
    jsr platform_putc
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_heart
;   Draws a heart shape at pixel position (cell_px, cell_py).
;   Heart is 7 pixels wide, 6 pixels tall.
;   Assumes color is already set.
; ---------------------------------------------------------------------------

.proc draw_heart
    ; Left bump: (px+1, py) to (px+2, py)
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
    adc #2
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    lda cell_py
    sta gfx_y2
    lda cell_py+1
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Right bump: (px+4, py) to (px+5, py)
    clc
    lda cell_px
    adc #4
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

    lda cell_py
    sta gfx_y2
    lda cell_py+1
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Wide body: (px, py+1) to (px+6, py+2)
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
    adc #6
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

    ; Taper 1: (px+1, py+3) to (px+5, py+3)
    clc
    lda cell_px
    adc #1
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda cell_py
    adc #3
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
    adc #3
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Taper 2: (px+2, py+4) to (px+4, py+4)
    clc
    lda cell_px
    adc #2
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda cell_py
    adc #4
    sta gfx_y1
    lda cell_py+1
    adc #0
    sta gfx_y1+1

    clc
    lda cell_px
    adc #4
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #4
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Point: (px+3, py+5) to (px+3, py+5)
    clc
    lda cell_px
    adc #3
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
    adc #3
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
; draw_life
;   Draws a heart-shaped life pickup at (life_x, life_y).
; ---------------------------------------------------------------------------

.proc draw_life
    lda COLOR_RED
    jsr platform_set_color

    lda life_x
    sta cell_x
    lda life_y
    sta cell_y
    jsr calc_cell_pixel
    jsr draw_heart
    rts
.endproc

; ---------------------------------------------------------------------------
; erase_life
;   Erases the life pickup from the field.
; ---------------------------------------------------------------------------

.proc erase_life
    lda life_x
    sta cell_x
    lda life_y
    sta cell_y
    jsr erase_cell
    rts
.endproc

; ---------------------------------------------------------------------------
; spawn_life
;   Places a life pickup at a random location not on worm or food.
; ---------------------------------------------------------------------------

.proc spawn_life
@retry:
    ; Random X in 0..GRID_COLS-1
    jsr platform_random
@mod_x:
    cmp #GRID_COLS
    bcc @x_ok
    sbc #GRID_COLS
    bra @mod_x
@x_ok:
    sta life_x

    ; Random Y in 0..GRID_ROWS-1
    jsr platform_random
@mod_y:
    cmp #GRID_ROWS
    bcc @y_ok
    sbc #GRID_ROWS
    bra @mod_y
@y_ok:
    sta life_y

    ; Check not on food
    lda life_x
    cmp food_x
    bne @check_worm
    lda life_y
    cmp food_y
    beq @retry

@check_worm:
    ldx #0
@check:
    cpx worm_len
    bcs @done
    lda life_x
    cmp body_x, x
    bne @next
    lda life_y
    cmp body_y, x
    beq @retry
@next:
    inx
    bra @check
@done:
    ; Also check life doesn't overlap any spider
    jsr check_pos_vs_spiders_life
    beq @retry
    rts
.endproc

; ---------------------------------------------------------------------------
; check_life
;   Checks if head is on the life pickup. Returns Z=1 if life eaten.
; ---------------------------------------------------------------------------

.proc check_life
    lda life_active
    beq @no
    lda body_x
    cmp life_x
    bne @no
    lda body_y
    cmp life_y
    rts
@no:
    lda #1                  ; clear Z
    rts
.endproc

; ---------------------------------------------------------------------------
; check_spider_collision
;   Checks if head overlaps any spider. Returns: C=1 if collision.
; ---------------------------------------------------------------------------

.proc check_spider_collision
    lda spider_count
    beq @no_hit

    ldx #0
@loop:
    cpx spider_count
    bcs @no_hit

    lda body_x
    cmp spider_x, x
    bne @next
    lda body_y
    cmp spider_y, x
    beq @hit

@next:
    inx
    bra @loop

@no_hit:
    clc
    rts
@hit:
    stx spider_hit_idx
    sec
    rts
.endproc

; ---------------------------------------------------------------------------
; remove_hit_spider
;   Removes the spider at spider_hit_idx by shifting remaining entries down.
;   Erases the spider's cell on screen.
; ---------------------------------------------------------------------------

.proc remove_hit_spider
    ldx spider_hit_idx

    ; Erase from screen
    lda spider_x, x
    sta cell_x
    lda spider_y, x
    sta cell_y
    jsr erase_cell

    ; Shift remaining spiders down to fill the gap
    dec spider_count
@shift:
    cpx spider_count
    bcs @fix_head
    lda spider_x + 1, x
    sta spider_x, x
    lda spider_y + 1, x
    sta spider_y, x
    inx
    bra @shift

@fix_head:
    ; Adjust head pointer if it was above the removed index
    lda spider_head
    beq @done
    cmp spider_hit_idx
    bcc @done               ; head < removed: no change
    beq @done               ; head == removed: it shifted down, now correct
    dec spider_head
@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; spawn_spider
;   Adds a spider to the playfield. Uses circular buffer of MAX_SPIDERS.
;   If buffer is full, the oldest spider is erased and overwritten.
; ---------------------------------------------------------------------------

.proc spawn_spider
    ; If at max capacity, erase the oldest spider first
    lda spider_count
    cmp #MAX_SPIDERS
    bcc @find_slot

    ; Erase oldest (at spider_head position)
    ldx spider_head
    lda spider_x, x
    sta cell_x
    lda spider_y, x
    sta cell_y
    jsr erase_cell
    jmp @place

@find_slot:
    ; Slot index = spider_head + spider_count (wrapped)
    lda spider_head
    clc
    adc spider_count
    and #(MAX_SPIDERS - 1)
    tax

@place:
    ; Find random position not overlapping anything
    jsr find_spider_pos

    ; Store position in the slot
    lda spider_tmp_x
    sta spider_x, x
    lda spider_tmp_y
    sta spider_y, x

    ; Update count and head
    lda spider_count
    cmp #MAX_SPIDERS
    bcs @advance_head
    inc spider_count
    rts

@advance_head:
    ; Advance head pointer (circular)
    lda spider_head
    clc
    adc #1
    and #(MAX_SPIDERS - 1)
    sta spider_head
    rts
.endproc

; ---------------------------------------------------------------------------
; find_spider_pos
;   Finds a random grid position for a spider that doesn't conflict.
;   Result stored in spider_tmp_x, spider_tmp_y. Preserves X.
; ---------------------------------------------------------------------------

.proc find_spider_pos
    phx
@retry:
    jsr platform_random
@mod_x:
    cmp #GRID_COLS
    bcc @x_ok
    sbc #GRID_COLS
    bra @mod_x
@x_ok:
    sta spider_tmp_x

    jsr platform_random
@mod_y:
    cmp #GRID_ROWS
    bcc @y_ok
    sbc #GRID_ROWS
    bra @mod_y
@y_ok:
    sta spider_tmp_y

    ; Check not on food
    lda spider_tmp_x
    cmp food_x
    bne @chk_life
    lda spider_tmp_y
    cmp food_y
    beq @retry

@chk_life:
    ; Check not on life
    lda life_active
    beq @chk_worm
    lda spider_tmp_x
    cmp life_x
    bne @chk_worm
    lda spider_tmp_y
    cmp life_y
    beq @retry

@chk_worm:
    ; Check not on worm body
    ldx #0
@worm_loop:
    cpx worm_len
    bcs @chk_spiders
    lda spider_tmp_x
    cmp body_x, x
    bne @worm_next
    lda spider_tmp_y
    cmp body_y, x
    beq @retry_pop
@worm_next:
    inx
    bra @worm_loop

@chk_spiders:
    ; Check not on existing spiders
    ldx #0
@spider_loop:
    cpx spider_count
    bcs @ok
    lda spider_tmp_x
    cmp spider_x, x
    bne @spider_next
    lda spider_tmp_y
    cmp spider_y, x
    beq @retry_pop
@spider_next:
    inx
    bra @spider_loop

@retry_pop:
    bra @retry

@ok:
    plx
    rts
.endproc

; ---------------------------------------------------------------------------
; check_pos_vs_spiders_food
;   Checks if food_x/food_y overlaps any spider. Z=1 if overlap.
; ---------------------------------------------------------------------------

.proc check_pos_vs_spiders_food
    ldx #0
@loop:
    cpx spider_count
    bcs @no_hit
    lda food_x
    cmp spider_x, x
    bne @next
    lda food_y
    cmp spider_y, x
    beq @hit
@next:
    inx
    bra @loop
@no_hit:
    lda #1              ; clear Z
    rts
@hit:
    lda #0              ; set Z
    rts
.endproc

; ---------------------------------------------------------------------------
; check_pos_vs_spiders_life
;   Checks if life_x/life_y overlaps any spider. Z=1 if overlap.
; ---------------------------------------------------------------------------

.proc check_pos_vs_spiders_life
    ldx #0
@loop:
    cpx spider_count
    bcs @no_hit
    lda life_x
    cmp spider_x, x
    bne @next
    lda life_y
    cmp spider_y, x
    beq @hit
@next:
    inx
    bra @loop
@no_hit:
    lda #1              ; clear Z
    rts
@hit:
    lda #0              ; set Z
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_all_spiders
;   Draws all active spiders on the playfield.
; ---------------------------------------------------------------------------

.proc draw_all_spiders
    lda spider_count
    beq @done

    ; Choose color based on vulnerability
    lda spider_vulnerable
    beq @normal_color
    lda COLOR_YELLOW
    jmp @set_color
@normal_color:
    lda COLOR_LGRAY
@set_color:
    jsr platform_set_color

    ldx #0
@loop:
    cpx spider_count
    bcs @done
    phx
    lda spider_x, x
    sta cell_x
    lda spider_y, x
    sta cell_y
    jsr calc_cell_pixel
    jsr draw_spider_shape
    plx
    inx
    bra @loop
@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_spider_shape
;   Draws a spider at pixel position (cell_px, cell_py).
;   8x8 pixel art: body blob with legs.
;   Assumes color is already set.
; ---------------------------------------------------------------------------

.proc draw_spider_shape
    ; Body center: (px+2, py+2) to (px+5, py+5)
    clc
    lda cell_px
    adc #2
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
    adc #5
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

    ; Head: (px+3, py+1) to (px+4, py+1)
    clc
    lda cell_px
    adc #3
    sta gfx_x1
    lda cell_px+1
    adc #0
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
    adc #4
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #1
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Left legs top: (px, py+2) to (px+1, py+3)
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
    adc #1
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #3
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Right legs top: (px+6, py+2) to (px+7, py+3)
    clc
    lda cell_px
    adc #6
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
    adc #3
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Left legs bottom: (px, py+4) to (px+1, py+5)
    lda cell_px
    sta gfx_x1
    lda cell_px+1
    sta gfx_x1+1

    clc
    lda cell_py
    adc #4
    sta gfx_y1
    lda cell_py+1
    adc #0
    sta gfx_y1+1

    clc
    lda cell_px
    adc #1
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

    ; Right legs bottom: (px+6, py+4) to (px+7, py+5)
    clc
    lda cell_px
    adc #6
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda cell_py
    adc #4
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

    ; Tail: (px+3, py+6) to (px+4, py+6)
    clc
    lda cell_px
    adc #3
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda cell_py
    adc #6
    sta gfx_y1
    lda cell_py+1
    adc #0
    sta gfx_y1+1

    clc
    lda cell_px
    adc #4
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #6
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------
; demo_run
;   Attract mode: AI-controlled worm. Any key returns to menu.
; ---------------------------------------------------------------------------

.proc demo_run
    jsr game_reset_stats
    jsr game_init
    jsr draw_full_frame
    jsr draw_all_segments
    jsr draw_food

    ; Flush keyboard buffer before starting demo loop
@flush:
    jsr platform_check_key
    cmp #0
    bne @flush

@loop:
    jsr platform_wait_vsync
    jsr sfx_update

    ; Check for any key to exit
    jsr platform_check_key
    cmp #0
    beq @no_key
    jmp @exit
@no_key:

    inc frame_count
    lda frame_count
    cmp #MOVE_DELAY
    bcc @loop

    lda #0
    sta frame_count

    ; Play move sound
    jsr sfx_play_move

    ; AI: choose direction
    jsr demo_ai

    ; Erase tail (unless growing)
    lda grow_flag
    bne @skip_erase
    jsr erase_tail
@skip_erase:

    ; Advance body
    jsr advance_body

    ; Check border collision
    jsr check_collision
    bcc @no_wall
    jmp @die
@no_wall:
    ; Check self collision
    jsr check_self_collision
    bcc @no_self
    jmp @die
@no_self:
    ; Check spider collision
    jsr check_spider_collision
    bcc @no_spider_hit

    ; Spider hit - check if vulnerable
    lda spider_vulnerable
    beq @spider_kills
    ; Vulnerable: eat the spider
    jsr remove_hit_spider
    lda #0
    sta spider_vulnerable
    jsr draw_all_spiders
    jsr sfx_play_spider_eat
    jmp @no_spider_hit
@spider_kills:
    jmp @die
@no_spider_hit:

    ; Check food
    jsr check_food
    beq @got_food
    jmp @no_food
@got_food:
    lda #1
    sta grow_flag
    inc food_count
    jsr sfx_play_food

    ; Check if 100 food eaten -> return to menu
    lda food_count
    cmp #100
    bcc @no_100
    jmp @exit
@no_100:

    ; If life was active, remove it (ate food before life)
    lda life_active
    beq @no_life_remove
    jsr erase_life
    lda #0
    sta life_active
@no_life_remove:

    ; End spider vulnerability on food collection
    lda spider_vulnerable
    beq @no_vuln_end
    lda #0
    sta spider_vulnerable
    jsr draw_all_spiders
@no_vuln_end:

    ; Check if a life pickup should spawn (every 20 food)
    inc food_since_life
    lda food_since_life
    cmp #20
    bcc @no_life_spawn
    lda #0
    sta food_since_life

    ; Only spawn life if lives < MAX_LIVES
    lda lives
    cmp #MAX_LIVES
    bcs @lives_full
    jsr spawn_life
    lda #1
    sta life_active
    jsr draw_life
    jmp @no_life_spawn

@lives_full:
    ; Already at max lives - make spiders vulnerable
    lda spider_count
    beq @no_life_spawn
    lda #1
    sta spider_vulnerable
    jsr draw_all_spiders
    jsr sfx_play_vulnerable
@no_life_spawn:

    ; Spider spawn (every 10 food)
    inc food_since_spider
    lda food_since_spider
    cmp #10
    bcc @no_demo_spider
    lda #0
    sta food_since_spider
    jsr spawn_spider
    jsr draw_all_spiders
    jsr sfx_play_spider_appear
@no_demo_spider:

    jsr spawn_food
    jsr draw_food
    jsr draw_status_bar
    jmp @draw_head

@no_food:
    lda #0
    sta grow_flag

    ; Check life collision
    jsr check_life
    bne @draw_head

    ; Ate life - gain a life (capped at MAX_LIVES)
    lda lives
    cmp #MAX_LIVES
    bcs @skip_life_gain
    inc lives
@skip_life_gain:
    lda #0
    sta life_active
    lda life_x
    sta cell_x
    lda life_y
    sta cell_y
    jsr erase_cell
    jsr draw_status_bar

@draw_head:
    lda body_x
    sta cell_x
    lda body_y
    sta cell_y
    jsr draw_segment

    jmp @loop

@die:
    ; Lose a life
    dec lives
    lda #0
    sta food_since_spider
    jsr draw_status_bar
    jsr sfx_play_life_lost

    lda lives
    beq @exit               ; all lives lost -> return to menu

    ; Brief pause, check for key
    lda #60
    sta delay_count
@die_wait:
    jsr platform_wait_vsync
    jsr sfx_update
    jsr platform_check_key
    cmp #0
    bne @exit
    dec delay_count
    bne @die_wait

    ; Reinit worm only (spiders persist)
    jsr game_init
    jsr draw_full_frame
    jsr draw_all_segments
    jsr draw_food
    jsr draw_all_spiders
    lda life_active
    beq @no_life_draw
    jsr draw_life
@no_life_draw:
    jmp @loop

@exit:
    rts
.endproc

; ---------------------------------------------------------------------------
; demo_ai
;   Simple AI: move toward target, avoid walls and self.
;   Priority: 1) heart if on field, 2) vulnerable spider, 3) food.
; ---------------------------------------------------------------------------

.proc demo_ai
    ; Determine target coordinates -> demo_target_x, demo_target_y

    ; Priority 1: heart on field
    lda life_active
    beq @check_spider
    lda life_x
    sta demo_target_x
    lda life_y
    sta demo_target_y
    jmp @navigate

@check_spider:
    ; Priority 2: vulnerable spider (target nearest)
    lda spider_vulnerable
    beq @target_food
    lda spider_count
    beq @target_food

    ; Find closest spider by Manhattan distance
    ldx #0
    lda #$FF
    sta demo_best_dist      ; best distance so far
@spider_loop:
    cpx spider_count
    bcs @use_best_spider

    ; |spider_x[x] - body_x|
    lda spider_x, x
    sec
    sbc body_x
    bpl @pos_dx
    eor #$FF
    clc
    adc #1
@pos_dx:
    sta demo_try_dir        ; reuse as temp

    ; |spider_y[x] - body_y|
    lda spider_y, x
    sec
    sbc body_y
    bpl @pos_dy
    eor #$FF
    clc
    adc #1
@pos_dy:
    clc
    adc demo_try_dir        ; total Manhattan distance

    cmp demo_best_dist
    bcs @not_closer
    sta demo_best_dist
    lda spider_x, x
    sta demo_target_x
    lda spider_y, x
    sta demo_target_y
@not_closer:
    inx
    bra @spider_loop

@use_best_spider:
    jmp @navigate

@target_food:
    lda food_x
    sta demo_target_x
    lda food_y
    sta demo_target_y

@navigate:
    ; Try horizontal direction toward target
    lda demo_target_x
    cmp body_x
    beq @try_y
    bcc @want_left

    ; Target is right
    lda #DIR_RIGHT
    jsr demo_is_safe
    beq @set_right
    bra @try_y

@want_left:
    lda #DIR_LEFT
    jsr demo_is_safe
    beq @set_left

@try_y:
    ; Try vertical direction toward target
    lda demo_target_y
    cmp body_y
    beq @try_current
    bcc @want_up

    ; Target is below
    lda #DIR_DOWN
    jsr demo_is_safe
    beq @set_down
    bra @try_current

@want_up:
    lda #DIR_UP
    jsr demo_is_safe
    beq @set_up

@try_current:
    ; Keep current direction if safe
    lda worm_dir
    jsr demo_is_safe
    beq @done

    ; Fallback: try all directions
    lda #DIR_UP
    jsr demo_is_safe
    beq @set_up
    lda #DIR_DOWN
    jsr demo_is_safe
    beq @set_down
    lda #DIR_LEFT
    jsr demo_is_safe
    beq @set_left
    lda #DIR_RIGHT
    jsr demo_is_safe
    beq @set_right
    ; No safe direction - will die
@done:
    rts

@set_up:
    lda #DIR_UP
    sta worm_dir
    rts
@set_down:
    lda #DIR_DOWN
    sta worm_dir
    rts
@set_left:
    lda #DIR_LEFT
    sta worm_dir
    rts
@set_right:
    lda #DIR_RIGHT
    sta worm_dir
    rts
.endproc

; ---------------------------------------------------------------------------
; demo_is_safe
;   Check if moving in direction A is safe (no wall, no self, no reversal).
;   Returns: Z=1 safe, Z=0 unsafe.
; ---------------------------------------------------------------------------

.proc demo_is_safe
    sta demo_try_dir

    ; Reject reversals
    lda worm_dir
    cmp #DIR_UP
    bne @nr1
    lda demo_try_dir
    cmp #DIR_DOWN
    beq @to_unsafe
    bra @calc
@nr1:
    cmp #DIR_DOWN
    bne @nr2
    lda demo_try_dir
    cmp #DIR_UP
    beq @to_unsafe
    bra @calc
@nr2:
    cmp #DIR_LEFT
    bne @nr3
    lda demo_try_dir
    cmp #DIR_RIGHT
    beq @to_unsafe
    bra @calc
@nr3:
    lda demo_try_dir
    cmp #DIR_LEFT
    bne @calc

@to_unsafe:
    jmp @unsafe

@calc:
    ; Compute hypothetical next position
    lda body_x
    sta demo_next_x
    lda body_y
    sta demo_next_y

    lda demo_try_dir
    cmp #DIR_UP
    bne @not_up
    dec demo_next_y
    jmp @bounds
@not_up:
    cmp #DIR_DOWN
    bne @not_down
    inc demo_next_y
    jmp @bounds
@not_down:
    cmp #DIR_LEFT
    bne @not_left
    dec demo_next_x
    jmp @bounds
@not_left:
    inc demo_next_x

@bounds:
    lda demo_next_x
    bmi @unsafe
    cmp #GRID_COLS
    bcs @unsafe
    lda demo_next_y
    bmi @unsafe
    cmp #GRID_ROWS
    bcs @unsafe

    ; Check self collision
    ldx #0
@self:
    cpx worm_len
    bcs @safe
    lda demo_next_x
    cmp body_x, x
    bne @next
    lda demo_next_y
    cmp body_y, x
    beq @unsafe
@next:
    inx
    bra @self

@safe:
    lda #0              ; Z=1
    rts
@unsafe:
    lda #1              ; Z=0
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

food_label:
    .byte "FOOD ", $00

lives_label:
    .byte "LIVES ", $00

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

food_count:      .res 1     ; total food eaten this game
food_since_life: .res 1     ; food eaten since last life spawn
lives:           .res 1     ; current lives
life_active:     .res 1     ; 1 if life pickup is on field
life_x:          .res 1     ; life pickup grid column
life_y:          .res 1     ; life pickup grid row

spider_x:        .res MAX_SPIDERS  ; spider grid columns (circular buffer)
spider_y:        .res MAX_SPIDERS  ; spider grid rows (circular buffer)
spider_count:    .res 1     ; number of active spiders (0..MAX_SPIDERS)
spider_head:     .res 1     ; index of oldest spider in circular buffer
food_since_spider: .res 1   ; food eaten since last spider spawn
spider_tmp_x:    .res 1     ; temp for spawn positioning
spider_tmp_y:    .res 1     ; temp for spawn positioning
spider_vulnerable: .res 1   ; 1 = spiders are yellow/edible
spider_hit_idx:  .res 1     ; index of spider that was hit

demo_try_dir:    .res 1     ; demo AI: candidate direction
demo_next_x:     .res 1     ; demo AI: hypothetical next X
demo_next_y:     .res 1     ; demo AI: hypothetical next Y
demo_target_x:   .res 1     ; demo AI: current target X
demo_target_y:   .res 1     ; demo AI: current target Y
demo_best_dist:  .res 1     ; demo AI: closest spider distance
