; ***************************************************************************
;
; game.asm - Game run loop, init, and orchestration
;
; Mirrors src/x16/engine/game.asm. Owns game_run (the per-life outer
; loop) and game_loop (the inner per-life movement / collision / food
; loop), plus game_init and game_reset_stats. Spider, life, pause, and
; quit-confirm branches in the X16/Neo build aren't ported yet so the
; PCE game_loop is shorter.
;
; poll_direction (the D-pad reader) lives here too - mirrors X16/Neo's
; platform_poll_input but only handles direction (no PAUSE/QUIT keys).
;
; ***************************************************************************

        .code

; ===========================================================================
;
; game_init - Set up worm: 3 segments centred on the grid, moving right.
; Mirrors src/x16/engine/game.asm:game_init (without the food/spider/life
; spawning, since spider/life don't exist on PCE yet - food is set up).
;
; ===========================================================================

game_init:
        lda     #3
        sta     worm_len

        lda     #(GRID_COLS / 2)
        sta     body_x + 0
        lda     #(GRID_ROWS / 2)
        sta     body_y + 0

        lda     #(GRID_COLS / 2 - 1)
        sta     body_x + 1
        lda     #(GRID_ROWS / 2)
        sta     body_y + 1

        lda     #(GRID_COLS / 2 - 2)
        sta     body_x + 2
        lda     #(GRID_ROWS / 2)
        sta     body_y + 2

        lda     #DIR_RIGHT
        sta     worm_dir

        stz     frame_count
        stz     grow_flag

        ; Seed the LFSR. We bias the seed off the user's menu interaction
        ; time (frame_count was incrementing during the game_loop's last
        ; iteration, plus joynow at this moment) so picking START at
        ; slightly different times yields different food layouts.
        lda     joynow
        eor     frame_count
        ora     #1                      ; LFSR must never be zero
        sta     rng_seed

        ; Pick the first food cell for this life.
        jsr     spawn_food
        rts


; ===========================================================================
;
; game_reset_stats - Clear the run-wide counters that persist across
; lives but reset between game sessions: food_count and lives.
; Mirrors src/x16/engine/game.asm:game_reset_stats.
;
; ===========================================================================

game_reset_stats:
        stz     food_count
        lda     #MAX_LIVES
        sta     lives
        rts


; ===========================================================================
;
; poll_direction - Read the joypad's currently-held buttons, return a
; direction code in A (DIR_NONE if no D-pad direction is held). On PCE
; we sample joynow rather than joytrg so steady direction holds keep
; the worm moving without per-frame button taps.
;
; Roughly equivalent to X16/Neo's platform_poll_input but only handles
; the four D-pad directions (no pause / quit yet).
;
; ===========================================================================

poll_direction:
        lda     joynow
        and     #JOY_U
        bne     .up
        lda     joynow
        and     #JOY_D
        bne     .down
        lda     joynow
        and     #JOY_L
        bne     .left
        lda     joynow
        and     #JOY_R
        bne     .right
        lda     #DIR_NONE
        rts
.up:
        lda     #DIR_UP
        rts
.down:
        lda     #DIR_DOWN
        rts
.left:
        lda     #DIR_LEFT
        rts
.right:
        lda     #DIR_RIGHT
        rts


; ===========================================================================
;
; game_run - Outer game session loop. Mirrors src/x16/engine/game.asm:
; game_run. Per life:
;   1. Wipe the playfield, show GET READY for 3 seconds.
;   2. Init the worm + spawn first food.
;   3. Wipe again (removes the GET READY message), draw worm + food.
;   4. Run game_loop; on respawn return-code (1) loop, on game over (0)
;      restore the menu chrome and return.
;
; Caller is expected to have already done game_reset_stats so food_count
; and lives start fresh.
;
; ===========================================================================

game_run:
.start:
        call    clear_playfield
        call    show_get_ready

        call    game_init

        ; Wipe the GET READY message, draw the worm + food.
        call    clear_playfield
        call    draw_all_segments
        call    draw_food
        call    draw_status_bar

        call    game_loop

        cmp     #1
        beq     .start                  ; respawn

        ; Game over - clear the playfield and put the menu chrome back.
        call    clear_playfield
        call    paint_worm_title
        rts


; ===========================================================================
;
; game_loop - Inner per-life loop. Returns:
;   A = 1 - died with lives remaining (caller should respawn)
;   A = 0 - game over (last life lost)
;
; Mirrors src/x16/engine/game.asm:game_loop without the spider, life,
; pause, or quit-confirm branches (those don't exist on PCE yet).
;
; ===========================================================================

game_loop:
.loop:
        call    wait_vsync

        ; --- Read the D-pad for a direction change -------------------------
        jsr     poll_direction
        cmp     #DIR_NONE
        beq     .no_input
        jsr     check_direction
.no_input:

        ; --- Wait for MOVE_DELAY frames before stepping --------------------
        inc     frame_count
        lda     frame_count
        cmp     #MOVE_DELAY
        bcc     .loop

        stz     frame_count

        ; --- Erase tail (skip if growing) ---------------------------------
        lda     grow_flag
        bne     .skip_erase
        jsr     erase_tail
.skip_erase:

        ; --- Shift body, place new head ------------------------------------
        jsr     advance_body

        ; --- Border collision = die ----------------------------------------
        jsr     check_collision
        bcs     .died

        ; --- Self collision = die ------------------------------------------
        jsr     check_self_collision
        bcs     .died

        ; --- Did the head land on the food? --------------------------------
        jsr     check_food
        bne     .no_food

        ; Ate food: grow next move, bump score, spawn + draw a fresh pellet,
        ; refresh the HUD.
        lda     #1
        sta     grow_flag
        inc     food_count
        jsr     spawn_food
        jsr     draw_food
        jsr     draw_status_bar
        bra     .draw_head

.no_food:
        stz     grow_flag

.draw_head:
        ; --- Draw new head -------------------------------------------------
        lda     body_x
        sta     <cell_x
        lda     body_y
        sta     <cell_y
        jsr     draw_segment
        bra     .loop

.died:
        ; --- Lose a life ---------------------------------------------------
        dec     lives
        jsr     draw_status_bar

        lda     lives
        beq     .real_game_over

        ; Lives remaining: brief pause, return code 1 (respawn).
        lda     #DELAY_LIFE_LOST
        sta     delay_count
.life_delay:
        call    wait_vsync
        dec     delay_count
        bne     .life_delay
        lda     #1
        rts

.real_game_over:
        ; No lives left: show GAME OVER, hold for ~3 seconds, return code 0.
        jsr     show_game_over
        lda     #DELAY_GAME_OVER
        sta     delay_count
.go_delay:
        call    wait_vsync
        dec     delay_count
        bne     .go_delay
        lda     #0
        rts
