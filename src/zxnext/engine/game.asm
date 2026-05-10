;----------------------------------------------------------------------------
;
; game.asm - Game run loop, init, orchestration
;
; Mirrors src/x16/engine/game.asm. Handles the per-life run loop, the
; outer respawn cycle, and overlay dispatch (GET READY / GAME OVER /
; pause / quit confirm). Sound is still pending and so are scoring
; tweaks; everything else from the canonical X16 game flow is covered.
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; game_run
;
; Outer game session loop. Repaints the playfield + GET READY + worm
; + food + spiders + (any) life pickup, then runs game_loop. If
; game_loop returns 1 (died with lives remaining) we loop back and
; respawn; otherwise (return 0 = real game over, return 2 = quit
; confirmed) we return to the caller.
;
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

game_run:
.respawn:
        call    draw_full_frame

        ; GET READY overlay (text + ~3s delay) before each life.
        call    show_get_ready

        ; Init worm + food for this life.
        call    game_init

        ; Repaint the playfield: chrome was painted before show_get_ready
        ; but the GET READY text is still there; draw_full_frame again
        ; clears it before the run starts.
        call    draw_full_frame
        call    draw_all_segments
        call    draw_food
        call    draw_all_spiders
        ld      a, (life_active)
        or      a
        jr      z, .no_life_redraw
        call    draw_life
.no_life_redraw:

        call    game_loop
        cp      1
        jr      z, .respawn             ; lost a life, lives remain
        ret                             ; A = 0 (game over) or 2 (quit)

;----------------------------------------------------------------------------
; redraw_game
;
; Repaint the in-game state (chrome + worm + food + spiders + life if
; active). Used by pause-resume and quit-cancel to restore the screen
; after an overlay.
;
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

redraw_game:
        call    draw_full_frame
        call    draw_all_segments
        call    draw_food
        call    draw_all_spiders
        ld      a, (life_active)
        or      a
        ret     z
        call    draw_life
        ret

;----------------------------------------------------------------------------
; game_init
;
; Place a 3-segment worm in the middle of the grid, facing right.
; Resets frame_count and grow_flag.
;
; Clobbers: A.
;----------------------------------------------------------------------------

game_init:
        ld      a, 3
        ld      (worm_len), a

        ; Head at (cols/2, rows/2)
        ld      a, GRID_COLS / 2
        ld      (body_x + 0), a
        ld      a, GRID_ROWS / 2
        ld      (body_y + 0), a

        ; Second segment one cell left of head.
        ld      a, GRID_COLS / 2 - 1
        ld      (body_x + 1), a
        ld      a, GRID_ROWS / 2
        ld      (body_y + 1), a

        ; Third segment two cells left of head.
        ld      a, GRID_COLS / 2 - 2
        ld      (body_x + 2), a
        ld      a, GRID_ROWS / 2
        ld      (body_y + 2), a

        ld      a, DIR_RIGHT
        ld      (worm_dir), a

        xor     a
        ld      (frame_count), a
        ld      (grow_flag), a

        call    spawn_food
        ret

;----------------------------------------------------------------------------
; game_reset_stats
;
; Reset per-session stats. Currently just lives + food_count, but
; structured so adding spider/life-pickup state later is mechanical.
;
; Clobbers: A.
;----------------------------------------------------------------------------

game_reset_stats:
        ld      a, MAX_LIVES
        ld      (lives), a
        xor     a
        ld      (food_count), a
        ld      (spider_count), a
        ld      (spider_head), a
        ld      (food_since_spider), a
        ld      (spider_vulnerable), a
        ld      (life_active), a
        ld      (food_since_life), a
        ret

;----------------------------------------------------------------------------
; game_loop
;
; Per-frame: vsync, poll input, on every MOVE_DELAY frames advance the
; worm and check collisions. On collision, return to caller.
;
; Clobbers: everything.
;----------------------------------------------------------------------------

game_loop:
.loop:
        call    platform_wait_vsync
        call    platform_poll_input

        cp      INPUT_PAUSE
        jp      z, .do_pause
        cp      INPUT_QUIT
        jp      z, .do_quit

        cp      DIR_NONE
        jr      z, .no_input
        call    check_direction
.no_input:

        ; Tick movement timer.
        ld      a, (frame_count)
        inc     a
        ld      (frame_count), a
        cp      MOVE_DELAY
        jr      c, .loop

        xor     a
        ld      (frame_count), a

        ; Erase tail (unless growing - won't be in this slice but the
        ; grow_flag mechanism is wired for when food lands).
        ld      a, (grow_flag)
        or      a
        jr      nz, .skip_erase
        call    erase_tail
.skip_erase:

        call    advance_body

        ; Border collision.
        call    check_collision
        jp      c, .died

        ; Self collision.
        call    check_self_collision
        jp      c, .died

        ; Spider collision. If spiders are vulnerable, hitting one eats
        ; it (remove + redraw remaining + end vulnerability) and the
        ; worm survives. Otherwise it kills the worm.
        call    check_spider_collision
        jr      nc, .no_spider_hit
        ld      a, (spider_vulnerable)
        or      a
        jp      z, .died
        call    remove_hit_spider
        xor     a
        ld      (spider_vulnerable), a
        call    draw_all_spiders
.no_spider_hit:

        ; Food collision -> grow + score + respawn food + redraw status.
        ; Otherwise -> clear grow_flag so next move erases the tail.
        call    check_food
        jr      nz, .no_food

        ld      a, 1
        ld      (grow_flag), a
        ld      hl, food_count
        inc     (hl)

        ; If a life pickup was on the field, eating food before it
        ; clears it from play (rule borrowed from the X16 port).
        ld      a, (life_active)
        or      a
        jr      z, .no_life_clear
        call    erase_life
        xor     a
        ld      (life_active), a
.no_life_clear:

        ; If spiders were vulnerable, eating food ends vulnerability
        ; and they revert to grey.
        ld      a, (spider_vulnerable)
        or      a
        jr      z, .no_vuln_end
        xor     a
        ld      (spider_vulnerable), a
        call    draw_all_spiders
.no_vuln_end:

        call    spawn_food
        call    draw_food
        call    draw_status_bar

        ; Every 20 food eaten, attempt to spawn a life pickup. If lives
        ; are at MAX_LIVES already, make spiders vulnerable instead.
        ld      hl, food_since_life
        inc     (hl)
        ld      a, (hl)
        cp      20
        jr      c, .no_life_spawn
        xor     a
        ld      (food_since_life), a

        ld      a, (lives)
        cp      MAX_LIVES
        jr      nc, .lives_full
        call    spawn_life
        ld      a, 1
        ld      (life_active), a
        call    draw_life
        jr      .no_life_spawn

.lives_full:
        ; Already capped: turn existing spiders vulnerable. No spiders ->
        ; nothing to do.
        ld      a, (spider_count)
        or      a
        jr      z, .no_life_spawn
        ld      a, 1
        ld      (spider_vulnerable), a
        call    draw_all_spiders
.no_life_spawn:

        ; Every 10 food eaten, spawn a new spider.
        ld      hl, food_since_spider
        inc     (hl)
        ld      a, (hl)
        cp      10
        jr      c, .draw_head
        xor     a
        ld      (food_since_spider), a
        call    spawn_spider
        call    draw_all_spiders
        jr      .draw_head

.no_food:
        xor     a
        ld      (grow_flag), a

        ; Life pickup collision -> +1 life (capped) and clear from field.
        call    check_life
        jr      nz, .draw_head

        ld      a, (lives)
        cp      MAX_LIVES
        jr      nc, .skip_life_gain
        inc     a
        ld      (lives), a
.skip_life_gain:
        xor     a
        ld      (life_active), a
        call    erase_life
        call    draw_status_bar

.draw_head:
        ; Draw new head segment.
        ld      a, (body_x)
        ld      b, a
        ld      a, (body_y)
        ld      c, a
        call    draw_segment
        jp      .loop

.do_pause:
        call    show_pause_screen
        call    redraw_game
        jp      .loop

.do_quit:
        call    show_quit_confirm
        cp      1
        jr      z, .quit_yes
        call    redraw_game
        jp      .loop
.quit_yes:
        ld      a, 2                    ; return: quit confirmed
        ret

.died:
        ; Lose a life, redraw status. If lives > 0 we ask game_run to
        ; respawn (return 1); otherwise show GAME OVER + delay + return 0.
        ld      a, (lives)
        dec     a
        ld      (lives), a
        xor     a
        ld      (food_since_spider), a  ; X16 also resets this on death
        call    draw_status_bar

        ld      a, (lives)
        or      a
        jr      z, .real_game_over

        ; Lives remaining: brief delay (mirrors the "life lost" beat),
        ; then return 1 so game_run respawns.
        ld      hl, DEATH_DELAY_FRAMES
        ld      (death_delay), hl
.death_wait:
        call    platform_wait_vsync
        ld      hl, (death_delay)
        dec     hl
        ld      (death_delay), hl
        ld      a, h
        or      l
        jr      nz, .death_wait
        ld      a, 1                    ; return: respawn
        ret

.real_game_over:
        call    show_game_over

        ld      hl, GAME_OVER_FRAMES
        ld      (death_delay), hl
.go_wait:
        call    platform_wait_vsync
        ld      hl, (death_delay)
        dec     hl
        ld      (death_delay), hl
        ld      a, h
        or      l
        jr      nz, .go_wait
        xor     a                       ; return: real game over
        ret

death_delay:    defw    0
