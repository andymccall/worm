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

        ; Clear any leftover life pickup from a previous life. (Spiders
        ; persist across lives; life pickups don't, per X16/Neo.)
        stz     life_active

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

        ; Spider state (matches src/x16/engine/game.asm:game_reset_stats).
        stz     spider_count
        stz     spider_head
        stz     food_since_spider
        stz     spider_vulnerable

        ; Life-pickup state.
        stz     food_since_life
        stz     life_active
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

        ; Wipe the GET READY message, draw the worm + food + any spiders
        ; that survived from a previous life. (game_init clears life_active
        ; so we never re-draw a stale life pickup across lives.)
        call    clear_playfield
        call    draw_all_segments
        call    draw_food
        call    draw_all_spiders
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
; Mirrors src/x16/engine/game.asm:game_loop without the life, pause, or
; quit-confirm branches (those don't exist on PCE yet). Spider spawning,
; collision, and vulnerability are wired in here.
;
; ===========================================================================

game_loop:
.loop:
        call    wait_vsync
        jsr     sfx_update

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

        ; Tick: a fresh worm move. Play the move blip.
        jsr     sfx_play_move

        ; --- Erase tail (skip if growing) ---------------------------------
        lda     grow_flag
        bne     .skip_erase
        jsr     erase_tail
.skip_erase:

        ; --- Shift body, place new head ------------------------------------
        jsr     advance_body

        ; --- Border collision = die ----------------------------------------
        ; Loop body grew large enough that .died is past relative-branch
        ; range; bcc-around-jmp gets us there.
        jsr     check_collision
        bcc     .border_ok
        jmp     .died
.border_ok:

        ; --- Self collision = die ------------------------------------------
        jsr     check_self_collision
        bcc     .self_ok
        jmp     .died
.self_ok:

        ; --- Spider collision ----------------------------------------------
        ; Hit a spider: die, unless vulnerability mode is active in which
        ; case we eat the spider and end the window.
        jsr     check_spider_collision
        bcc     .no_spider_hit
        lda     spider_vulnerable
        bne     .eat_spider
        jmp     .died
.eat_spider:
        jsr     remove_hit_spider
        stz     spider_vulnerable
        jsr     draw_all_spiders
        jsr     sfx_play_spider_eat
.no_spider_hit:

        ; --- Did the head land on the food? --------------------------------
        jsr     check_food
        bne     .no_food

        ; --- Ate food ------------------------------------------------------
        lda     #1
        sta     grow_flag
        inc     food_count
        jsr     sfx_play_food
        jsr     spawn_food
        jsr     draw_food

        ; If a life pickup was on the field, the act of eating food
        ; consumes it (matches X16/Neo: life pickups expire when food is
        ; eaten). Erase the heart and clear the flag.
        lda     life_active
        beq     .no_life_remove
        jsr     erase_life
        stz     life_active
.no_life_remove:

        ; End vulnerability on food collection.
        lda     spider_vulnerable
        beq     .no_vuln_end
        stz     spider_vulnerable
        jsr     draw_all_spiders
.no_vuln_end:

        ; --- Life-pickup cadence (every LIFE_SPAWN_FOOD pellets) -----------
        ; If lives < MAX_LIVES: spawn a life pickup.
        ; Else if there's at least one spider on screen: trigger
        ; vulnerability mode (matches the X16/Neo "lives full" branch).
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
        ; Already at max lives - make spiders vulnerable instead.
        lda     spider_count
        beq     .no_life_spawn
        lda     #1
        sta     spider_vulnerable
        jsr     draw_all_spiders
        jsr     sfx_play_vulnerable

.no_life_spawn:

        ; --- Spider-spawn cadence (every SPIDER_SPAWN_FOOD pellets) -------
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

        ; --- Did the head land on the life pickup? ------------------------
        jsr     check_life
        bne     .draw_head

        ; Ate the life pickup: +1 life (capped at MAX_LIVES), wipe the
        ; cell, refresh the HUD.
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
        ; --- Draw new head -------------------------------------------------
        lda     body_x
        sta     <cell_x
        lda     body_y
        sta     <cell_y
        jsr     draw_segment
        jmp     .loop                   ; long branch back to top of loop

.died:
        ; --- Lose a life ---------------------------------------------------
        dec     lives
        ; Reset spider-spawn counter so dying mid-cycle doesn't carry
        ; partial progress into the next life (matches X16/Neo).
        stz     food_since_spider
        jsr     draw_status_bar

        lda     lives
        beq     .real_game_over

        ; Lives remaining: play the life-lost jingle, brief pause,
        ; return code 1 (respawn). sfx_update runs each frame so the
        ; jingle plays out cleanly during the pause.
        jsr     sfx_play_life_lost
        lda     #DELAY_LIFE_LOST
        sta     delay_count
.life_delay:
        call    wait_vsync
        jsr     sfx_update
        dec     delay_count
        bne     .life_delay
        lda     #1
        rts

.real_game_over:
        ; No lives left: GAME OVER message + jingle, hold for ~3 seconds,
        ; return code 0.
        jsr     show_game_over
        jsr     sfx_play_game_over
        lda     #DELAY_GAME_OVER
        sta     delay_count
.go_delay:
        call    wait_vsync
        jsr     sfx_update
        dec     delay_count
        bne     .go_delay
        lda     #0
        rts
