; ---------------------------------------------------------------------------
; demo.asm - Attract mode / demo AI
; ---------------------------------------------------------------------------
; AI-controlled worm that plays automatically. Any key exits to menu.
; ---------------------------------------------------------------------------

.export demo_run

.import platform_wait_vsync
.import platform_check_key

.import draw_status_bar, draw_full_frame
.import draw_life, erase_life

.import advance_body, check_collision, check_self_collision
.import draw_segment, draw_all_segments, erase_tail
.import worm_dir, worm_len, body_x, body_y, grow_flag, frame_count

.import spawn_food, check_food, draw_food
.import food_x, food_y, food_count

.import check_spider_collision, remove_hit_spider, spawn_spider
.import draw_all_spiders
.import spider_x, spider_y, spider_count
.import spider_vulnerable, food_since_spider

.import check_life
.import life_active, life_x, life_y, food_since_life
.import spawn_life

.import erase_cell
.import cell_x, cell_y

.import game_reset_stats, lives

.import sfx_update, sfx_play_move, sfx_play_food
.import sfx_play_spider_appear, sfx_play_spider_eat
.import sfx_play_life_lost, sfx_play_vulnerable

.include "api/wm_equates.inc"

; Reuse game_init from game.asm
.import game_init

; ---------------------------------------------------------------------------

.segment "CODE"

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

.segment "BSS"

delay_count:     .res 1     ; delay for death pause
demo_try_dir:    .res 1     ; demo AI: candidate direction
demo_next_x:     .res 1     ; demo AI: hypothetical next X
demo_next_y:     .res 1     ; demo AI: hypothetical next Y
demo_target_x:   .res 1     ; demo AI: current target X
demo_target_y:   .res 1     ; demo AI: current target Y
demo_best_dist:  .res 1     ; demo AI: closest spider distance
