;----------------------------------------------------------------------------
;
; life.asm - Life pickup spawning, collision, and rendering
;
; Mirrors src/x16/engine/life.asm. Owns the heart-shaped life pickup
; that occasionally appears on the playfield.
;
; Rules (from the X16 game loop):
;   * Every 20 food eaten, attempt to spawn a life pickup.
;     - If lives < MAX_LIVES, place one and draw it.
;     - If lives are already full, set spider_vulnerable = 1 instead
;       (so the existing spiders turn yellow and become edible).
;       game.asm owns that branch; this module just provides the
;       spawn / check / draw / erase primitives.
;   * Picking up the life: +1 life (capped at MAX_LIVES), pickup erased,
;     status bar redrawn.
;   * If a life pickup is on the field when the worm eats food, the
;     pickup gets erased (game.asm: "ate food before life").
;
; The pickup is a 7x6 red heart - same shape as the status-bar hearts,
; reusing draw_heart from status_bar.asm.
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; draw_life
;
; Paint a red heart at grid (life_x, life_y).
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

draw_life:
        ld      a, (life_x)
        ld      b, a
        ld      a, (life_y)
        ld      c, a
        call    calc_cell_pixel         ; HL = px, E = py
        ld      a, COL_RED
        call    draw_heart
        ret

;----------------------------------------------------------------------------
; erase_life
;
; Clear the cell at (life_x, life_y).
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

erase_life:
        ld      a, (life_x)
        ld      b, a
        ld      a, (life_y)
        ld      c, a
        call    erase_cell
        ret

;----------------------------------------------------------------------------
; spawn_life
;
; Pick a random cell that doesn't overlap food, worm body, or any
; spider, and store it in (life_x, life_y). Caller is responsible for
; setting life_active = 1 and calling draw_life.
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

spawn_life:
.retry:
        call    platform_random
.mod_x:
        cp      GRID_COLS
        jr      c, .x_ok
        sub     GRID_COLS
        jr      .mod_x
.x_ok:
        ld      (life_x), a

        call    platform_random
.mod_y:
        cp      GRID_ROWS
        jr      c, .y_ok
        sub     GRID_ROWS
        jr      .mod_y
.y_ok:
        ld      (life_y), a

        ; --- Reject if on food -----------------------------------------
        ld      a, (life_x)
        ld      hl, food_x
        cp      (hl)
        jr      nz, .chk_worm
        ld      a, (life_y)
        ld      hl, food_y
        cp      (hl)
        jr      z, .retry

.chk_worm:
        ; --- Reject if on any worm body cell --------------------------
        ld      a, (worm_len)
        or      a
        jr      z, .chk_spiders
        ld      b, a
        ld      hl, body_x
        ld      de, body_y
.worm_loop:
        ld      a, (life_x)
        cp      (hl)
        jr      nz, .worm_next
        ld      a, (life_y)
        push    hl
        ex      de, hl
        cp      (hl)
        ex      de, hl
        pop     hl
        jr      z, .retry
.worm_next:
        inc     hl
        inc     de
        djnz    .worm_loop

.chk_spiders:
        ; --- Reject if on any spider ----------------------------------
        ld      a, (spider_count)
        or      a
        ret     z
        ld      b, a
        ld      hl, spider_x
        ld      de, spider_y
.sp_loop:
        ld      a, (life_x)
        cp      (hl)
        jr      nz, .sp_next
        ld      a, (life_y)
        push    hl
        ex      de, hl
        cp      (hl)
        ex      de, hl
        pop     hl
        jr      z, .retry
.sp_next:
        inc     hl
        inc     de
        djnz    .sp_loop
        ret

;----------------------------------------------------------------------------
; check_life
;
; Test the head against the life pickup (only if life_active).
;
; Exit: Z=1 if head is on the active life pickup, Z=0 otherwise.
; Clobbers: A.
;----------------------------------------------------------------------------

check_life:
        ld      a, (life_active)
        or      a
        jr      z, .miss
        ld      a, (body_x)
        ld      hl, life_x
        cp      (hl)
        jr      nz, .miss
        ld      a, (body_y)
        ld      hl, life_y
        cp      (hl)
        jr      nz, .miss
        xor     a                       ; Z=1 (hit)
        ret
.miss:
        ld      a, 1
        or      a                       ; Z=0
        ret

;----------------------------------------------------------------------------
; State
;----------------------------------------------------------------------------

life_active:    defb    0       ; 1 if pickup is on the field
life_x:         defb    0
life_y:         defb    0
food_since_life: defb   0       ; food eaten since last life-pickup attempt
