; Worm - (c) 2026 Andy McCall
; Licensed under CC BY-NC 4.0
; https://creativecommons.org/licenses/by-nc/4.0/

; ---------------------------------------------------------------------------
; game.asm - Game run loop, init, and orchestration
; ---------------------------------------------------------------------------
; Main game orchestrator: manages game_run, game_loop, game_init,
; game_reset_stats, and redraw_game.
; ---------------------------------------------------------------------------

.export game_run
.export game_reset_stats
.export game_init
.export lives

.import platform_cls
.import platform_set_color
.import platform_poll_input
.import platform_wait_vsync
.import platform_gotoxy

.import draw_border
.import draw_status_bar, draw_full_frame
.import show_get_ready, show_game_over, show_pause_screen, show_quit_confirm

.import advance_body, check_direction, check_collision, check_self_collision
.import draw_segment, draw_all_segments, erase_tail
.import worm_dir, worm_len, body_x, body_y, grow_flag, frame_count

.import spawn_food, check_food, draw_food
.import food_x, food_y, food_count

.import check_spider_collision, remove_hit_spider, spawn_spider
.import draw_all_spiders
.import spider_x, spider_y, spider_count, spider_head
.import spider_vulnerable, food_since_spider

.import draw_life, erase_life, spawn_life, check_life
.import life_active, life_x, life_y, food_since_life

.import sfx_update, sfx_play_move, sfx_play_food
.import sfx_play_spider_appear, sfx_play_spider_eat
.import sfx_play_life_lost, sfx_play_vulnerable
.import sfx_play_game_over, sfx_play_get_ready

.import erase_cell
.import cell_x, cell_y

.import COLOR_GREEN

.include "api/wm_equates.inc"

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

.segment "BSS"

lives:       .res 1          ; current lives
delay_count: .res 1          ; general delay counter
