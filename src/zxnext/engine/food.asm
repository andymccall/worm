;----------------------------------------------------------------------------
;
; food.asm - Food spawning, collision, and rendering
;
; Mirrors src/x16/engine/food.asm. Owns:
;   spawn_food   - place a clover-leaf at a random unoccupied cell
;   check_food   - test head against food, returns Z=1 if eaten
;   draw_food    - paint the 4-leaf yellow clover at (food_x, food_y)
;
; Life pickups and spiders aren't part of this slice, so spawn_food only
; checks the worm body for overlap. The full version on the X16 also
; checks life_active, life_x/y, and the spider list - those will plug in
; the same way when they land.
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; check_food
;
; Compare the head to the food cell.
;
; Exit: Z=1 if head is on food, Z=0 otherwise. (Mirrors X16: returns A=0
;       on hit, A=1 on miss.)
; Clobbers: A.
;----------------------------------------------------------------------------

check_food:
        ld      a, (body_x)
        ld      hl, food_x
        cp      (hl)
        jr      nz, .miss
        ld      a, (body_y)
        ld      hl, food_y
        cp      (hl)
        jr      nz, .miss
        xor     a                       ; Z=1 (hit)
        ret
.miss:
        ld      a, 1                    ; Z=0 (miss)
        or      a
        ret

;----------------------------------------------------------------------------
; spawn_food
;
; Place the food at a random (col, row) that doesn't overlap any worm
; body segment. Retry until clear.
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

spawn_food:
.retry:
        ; --- Random col 0..GRID_COLS-1 ---------------------------------
        call    platform_random
.mod_x:
        cp      GRID_COLS
        jr      c, .x_ok
        sub     GRID_COLS
        jr      .mod_x
.x_ok:
        ld      (food_x), a

        ; --- Random row 0..GRID_ROWS-1 ---------------------------------
        call    platform_random
.mod_y:
        cp      GRID_ROWS
        jr      c, .y_ok
        sub     GRID_ROWS
        jr      .mod_y
.y_ok:
        ld      (food_y), a

        ; --- Reject if it overlaps any worm body cell ------------------
        ld      a, (worm_len)
        or      a
        jr      z, .chk_spiders

        ld      b, a
        ld      hl, body_x
        ld      de, body_y
.check:
        ld      a, (food_x)
        cp      (hl)
        jr      nz, .next
        ld      a, (food_y)
        push    hl
        ex      de, hl
        cp      (hl)
        ex      de, hl
        pop     hl
        jr      z, .retry
.next:
        inc     hl
        inc     de
        djnz    .check

.chk_spiders:
        ; --- Reject if it overlaps any spider --------------------------
        ld      a, (spider_count)
        or      a
        jr      z, .chk_life

        ld      b, a
        ld      hl, spider_x
        ld      de, spider_y
.sp_check:
        ld      a, (food_x)
        cp      (hl)
        jr      nz, .sp_next
        ld      a, (food_y)
        push    hl
        ex      de, hl
        cp      (hl)
        ex      de, hl
        pop     hl
        jr      z, .retry
.sp_next:
        inc     hl
        inc     de
        djnz    .sp_check

.chk_life:
        ; --- Reject if it overlaps the active life pickup -------------
        ld      a, (life_active)
        or      a
        ret     z
        ld      a, (food_x)
        ld      hl, life_x
        cp      (hl)
        ret     nz
        ld      a, (food_y)
        ld      hl, life_y
        cp      (hl)
        ret     nz
        jr      .retry

;----------------------------------------------------------------------------
; draw_food
;
; Paint a yellow 4-leaf clover at (food_x, food_y). Same shape as the
; menu-worm flower:
;
;   top    leaf: (px+2, py)   w=4 h=3
;   bottom leaf: (px+2, py+5) w=4 h=3
;   left   leaf: (px,   py+2) w=3 h=4
;   right  leaf: (px+5, py+2) w=3 h=4
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

draw_food:
        ld      a, (food_x)
        ld      b, a
        ld      a, (food_y)
        ld      c, a
        call    calc_cell_pixel         ; HL=px, E=py
        ld      (food_px), hl
        ld      a, e
        ld      (food_py), a

        ; Top leaf: (px+2, py) w=4 h=3
        ld      hl, (food_px)
        ld      bc, 2
        add     hl, bc
        ld      a, (food_py)
        ld      e, a
        ld      bc, 4
        ld      d, 3
        ld      a, COL_YELLOW
        call    platform_draw_filled_rect

        ; Bottom leaf: (px+2, py+5) w=4 h=3
        ld      hl, (food_px)
        ld      bc, 2
        add     hl, bc
        ld      a, (food_py)
        add     a, 5
        ld      e, a
        ld      bc, 4
        ld      d, 3
        ld      a, COL_YELLOW
        call    platform_draw_filled_rect

        ; Left leaf: (px, py+2) w=3 h=4
        ld      hl, (food_px)
        ld      a, (food_py)
        add     a, 2
        ld      e, a
        ld      bc, 3
        ld      d, 4
        ld      a, COL_YELLOW
        call    platform_draw_filled_rect

        ; Right leaf: (px+5, py+2) w=3 h=4
        ld      hl, (food_px)
        ld      bc, 5
        add     hl, bc
        ld      a, (food_py)
        add     a, 2
        ld      e, a
        ld      bc, 3
        ld      d, 4
        ld      a, COL_YELLOW
        call    platform_draw_filled_rect
        ret

;----------------------------------------------------------------------------
; State
;----------------------------------------------------------------------------

food_x:         defb    0
food_y:         defb    0

food_px:        defw    0
food_py:        defb    0
