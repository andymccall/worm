; ***************************************************************************
;
; demo.asm - Attract mode / demo AI
;
; AI-controlled worm that plays automatically. Any button press exits
; back to the menu, and the demo also exits naturally after eating
; DEMO_FOOD_LIMIT pellets. Mirrors src/x16/app/demo.asm closely.
;
; The AI in demo_ai picks a target each move:
;   1. The active life pickup, if any.
;   2. The nearest spider, if any spider is currently vulnerable.
;   3. Otherwise, the food pellet.
; demo_is_safe filters out moves that would hit the wall, the body, or
; reverse direction. If no safe move exists the worm dies, lives
; decrement, and demo continues until lives run out.
;
; ***************************************************************************

        .code

; ===========================================================================
;
; demo_run - Attract mode entry point. Resets stats, draws the playfield,
; runs the AI loop until any button is pressed, all lives are lost, or
; DEMO_FOOD_LIMIT pellets have been eaten.
;
; Mirrors src/x16/app/demo.asm:demo_run.
;
; ===========================================================================

demo_run:
        jsr     game_reset_stats
        jsr     game_init

        ; Wipe the menu chrome + paint the playfield. game_init has set up
        ; food and the worm.
        call    clear_playfield
        call    draw_all_segments
        call    draw_food
        call    draw_status_bar

        ; Drain any in-flight joypad-trigger bits so a button press from
        ; the menu's "select demo" doesn't immediately bounce us out.
        lda     joytrg                  ; reading clears for next frame

.loop:
        call    wait_vsync
        jsr     sfx_update

        ; Any button press exits back to the menu.
        lda     joytrg
        and     #(JOY_B1 | JOY_B2 | JOY_RUN | JOY_SEL | JOY_U | JOY_D | JOY_L | JOY_R)
        beq     .no_input
        jmp     .exit
.no_input:

        inc     frame_count
        lda     frame_count
        cmp     #MOVE_DELAY
        bcc     .loop

        stz     frame_count

        ; Tick: a fresh AI move.
        jsr     sfx_play_move

        ; AI picks the next direction.
        jsr     demo_ai

        ; Erase tail unless growing.
        lda     grow_flag
        bne     .skip_erase
        jsr     erase_tail
.skip_erase:

        ; Advance + collisions.
        jsr     advance_body

        jsr     check_collision
        bcc     .border_ok
        jmp     .die
.border_ok:
        jsr     check_self_collision
        bcc     .self_ok
        jmp     .die
.self_ok:

        ; Spider collision: die unless vulnerable.
        jsr     check_spider_collision
        bcc     .no_spider_hit
        lda     spider_vulnerable
        bne     .eat_spider
        jmp     .die
.eat_spider:
        jsr     remove_hit_spider
        stz     spider_vulnerable
        jsr     draw_all_spiders
        jsr     sfx_play_spider_eat
.no_spider_hit:

        ; Food collision.
        jsr     check_food
        bne     .no_food

        ; --- Ate food ------------------------------------------------------
        lda     #1
        sta     grow_flag
        inc     food_count
        jsr     sfx_play_food

        ; Demo exits after DEMO_FOOD_LIMIT food eaten.
        lda     food_count
        cmp     #DEMO_FOOD_LIMIT
        bcc     .no_demo_done
        jmp     .exit
.no_demo_done:

        jsr     spawn_food
        jsr     draw_food

        ; Consume any active life pickup (food was eaten near it).
        lda     life_active
        beq     .no_life_remove
        jsr     erase_life
        stz     life_active
.no_life_remove:

        ; End vulnerability on food.
        lda     spider_vulnerable
        beq     .no_vuln_end
        stz     spider_vulnerable
        jsr     draw_all_spiders
.no_vuln_end:

        ; Life-pickup cadence (every LIFE_SPAWN_FOOD pellets).
        inc     food_since_life
        lda     food_since_life
        cmp     #LIFE_SPAWN_FOOD
        bcc     .no_life_spawn

        stz     food_since_life

        lda     lives
        cmp     #MAX_LIVES
        bcs     .lives_full
        jsr     spawn_life
        lda     #1
        sta     life_active
        jsr     draw_life
        bra     .no_life_spawn

.lives_full:
        ; At max lives - flip vulnerability if spiders exist.
        lda     spider_count
        beq     .no_life_spawn
        lda     #1
        sta     spider_vulnerable
        jsr     draw_all_spiders
        jsr     sfx_play_vulnerable

.no_life_spawn:

        ; Spider-spawn cadence (every SPIDER_SPAWN_FOOD pellets).
        inc     food_since_spider
        lda     food_since_spider
        cmp     #SPIDER_SPAWN_FOOD
        bcc     .no_spider_spawn

        stz     food_since_spider
        jsr     spawn_spider
        jsr     draw_all_spiders
        jsr     sfx_play_spider_appear

.no_spider_spawn:
        jsr     draw_status_bar
        jmp     .draw_head

.no_food:
        stz     grow_flag

        ; Life pickup collision: +1 life (capped), erase the cell.
        jsr     check_life
        bne     .draw_head

        lda     lives
        cmp     #MAX_LIVES
        bcs     .skip_life_gain
        inc     lives
.skip_life_gain:
        stz     life_active
        lda     life_x
        sta     <cell_x
        lda     life_y
        sta     <cell_y
        jsr     erase_cell
        jsr     draw_status_bar

.draw_head:
        lda     body_x
        sta     <cell_x
        lda     body_y
        sta     <cell_y
        jsr     draw_segment
        jmp     .loop

.die:
        ; --- Lose a life ---------------------------------------------------
        dec     lives
        stz     food_since_spider
        jsr     draw_status_bar
        jsr     sfx_play_life_lost

        lda     lives
        beq     .exit                   ; out of lives -> back to menu

        ; Brief pause; allow any-button to bail out early.
        lda     #DELAY_LIFE_LOST
        sta     delay_count
.die_wait:
        call    wait_vsync
        jsr     sfx_update
        lda     joytrg
        and     #(JOY_B1 | JOY_B2 | JOY_RUN | JOY_SEL | JOY_U | JOY_D | JOY_L | JOY_R)
        bne     .exit
        dec     delay_count
        bne     .die_wait

        ; Reinit worm (spiders persist).
        jsr     game_init
        call    clear_playfield
        call    draw_all_segments
        call    draw_food
        call    draw_all_spiders
        lda     life_active
        beq     .no_life_draw
        jsr     draw_life
.no_life_draw:
        jmp     .loop

.exit:
        jsr     sfx_stop
        ; Restore the menu chrome before returning, mirroring game_run.
        call    clear_playfield
        call    paint_worm_title
        rts


; ===========================================================================
;
; demo_ai - Pick the next worm direction. Targeting priority:
;   1. The life pickup if active.
;   2. The nearest spider if vulnerability mode is on.
;   3. The food pellet.
;
; The chosen target's grid coordinates land in demo_target_x/y, and the
; worm tries horizontal-toward then vertical-toward, falling back to
; "keep going" or "any safe direction".
;
; Mirrors src/x16/app/demo.asm:demo_ai.
;
; ===========================================================================

demo_ai:
        ; Priority 1: life pickup.
        lda     life_active
        beq     .check_spider
        lda     life_x
        sta     demo_target_x
        lda     life_y
        sta     demo_target_y
        jmp     .navigate

.check_spider:
        ; Priority 2: vulnerable spider, target the nearest by Manhattan.
        lda     spider_vulnerable
        beq     .target_food
        lda     spider_count
        beq     .target_food

        ldx     #0
        lda     #$FF
        sta     demo_best_dist
.spider_loop:
        cpx     spider_count
        bcs     .use_best_spider

        ; |spider_x[x] - body_x|
        lda     spider_x, x
        sec
        sbc     body_x
        bpl     .pos_dx
        eor     #$FF
        clc
        adc     #1
.pos_dx:
        sta     demo_try_dir            ; reuse as scratch

        ; |spider_y[x] - body_y|
        lda     spider_y, x
        sec
        sbc     body_y
        bpl     .pos_dy
        eor     #$FF
        clc
        adc     #1
.pos_dy:
        clc
        adc     demo_try_dir            ; total Manhattan distance

        cmp     demo_best_dist
        bcs     .not_closer
        sta     demo_best_dist
        lda     spider_x, x
        sta     demo_target_x
        lda     spider_y, x
        sta     demo_target_y
.not_closer:
        inx
        bra     .spider_loop

.use_best_spider:
        jmp     .navigate

.target_food:
        lda     food_x
        sta     demo_target_x
        lda     food_y
        sta     demo_target_y

.navigate:
        ; Try horizontal direction toward target.
        lda     demo_target_x
        cmp     body_x
        beq     .try_y
        bcc     .want_left

        ; Target is right.
        lda     #DIR_RIGHT
        jsr     demo_is_safe
        beq     .set_right
        bra     .try_y

.want_left:
        lda     #DIR_LEFT
        jsr     demo_is_safe
        beq     .set_left

.try_y:
        ; Try vertical direction toward target.
        lda     demo_target_y
        cmp     body_y
        beq     .try_current
        bcc     .want_up

        ; Target is below.
        lda     #DIR_DOWN
        jsr     demo_is_safe
        beq     .set_down
        bra     .try_current

.want_up:
        lda     #DIR_UP
        jsr     demo_is_safe
        beq     .set_up

.try_current:
        ; Keep current direction if safe.
        lda     worm_dir
        jsr     demo_is_safe
        beq     .done

        ; Last resort: try every direction.
        lda     #DIR_UP
        jsr     demo_is_safe
        beq     .set_up
        lda     #DIR_DOWN
        jsr     demo_is_safe
        beq     .set_down
        lda     #DIR_LEFT
        jsr     demo_is_safe
        beq     .set_left
        lda     #DIR_RIGHT
        jsr     demo_is_safe
        beq     .set_right
        ; No safe direction - the worm will die this move.
.done:
        rts

.set_up:
        lda     #DIR_UP
        sta     worm_dir
        rts
.set_down:
        lda     #DIR_DOWN
        sta     worm_dir
        rts
.set_left:
        lda     #DIR_LEFT
        sta     worm_dir
        rts
.set_right:
        lda     #DIR_RIGHT
        sta     worm_dir
        rts


; ===========================================================================
;
; demo_is_safe - Test whether moving in direction A is safe (no wall,
; no self collision, no 180-degree reversal). Returns Z=1 if safe,
; Z=0 if not. Mirrors src/x16/app/demo.asm:demo_is_safe.
;
; ===========================================================================

demo_is_safe:
        sta     demo_try_dir

        ; Reject reversals.
        lda     worm_dir
        cmp     #DIR_UP
        bne     .nr1
        lda     demo_try_dir
        cmp     #DIR_DOWN
        beq     .to_unsafe
        bra     .calc
.nr1:
        cmp     #DIR_DOWN
        bne     .nr2
        lda     demo_try_dir
        cmp     #DIR_UP
        beq     .to_unsafe
        bra     .calc
.nr2:
        cmp     #DIR_LEFT
        bne     .nr3
        lda     demo_try_dir
        cmp     #DIR_RIGHT
        beq     .to_unsafe
        bra     .calc
.nr3:
        lda     demo_try_dir
        cmp     #DIR_LEFT
        bne     .calc

.to_unsafe:
        jmp     .unsafe

.calc:
        ; Compute the hypothetical next head position.
        lda     body_x
        sta     demo_next_x
        lda     body_y
        sta     demo_next_y

        lda     demo_try_dir
        cmp     #DIR_UP
        bne     .not_up
        dec     demo_next_y
        jmp     .bounds
.not_up:
        cmp     #DIR_DOWN
        bne     .not_down
        inc     demo_next_y
        jmp     .bounds
.not_down:
        cmp     #DIR_LEFT
        bne     .not_left
        dec     demo_next_x
        jmp     .bounds
.not_left:
        inc     demo_next_x

.bounds:
        lda     demo_next_x
        bmi     .unsafe
        cmp     #GRID_COLS
        bcs     .unsafe
        lda     demo_next_y
        bmi     .unsafe
        cmp     #GRID_ROWS
        bcs     .unsafe

        ; Self collision.
        ldx     #0
.self:
        cpx     worm_len
        bcs     .safe
        lda     demo_next_x
        cmp     body_x, x
        bne     .next
        lda     demo_next_y
        cmp     body_y, x
        beq     .unsafe
.next:
        inx
        bra     .self

.safe:
        lda     #0                      ; Z=1
        rts
.unsafe:
        lda     #1                      ; Z=0
        rts


; ===========================================================================
; Demo AI scratch (matches src/x16/app/demo.asm BSS layout)
; ===========================================================================

        .bss

demo_try_dir:     ds 1     ; candidate direction under test
demo_next_x:     ds 1      ; hypothetical next head X
demo_next_y:     ds 1      ; hypothetical next head Y
demo_target_x:    ds 1     ; AI's current target column
demo_target_y:    ds 1     ; AI's current target row
demo_best_dist:   ds 1     ; closest-spider Manhattan distance
