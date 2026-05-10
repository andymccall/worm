;----------------------------------------------------------------------------
;
; worm.asm - Worm body management
;
; Mirrors src/x16/engine/worm.asm. Owns:
;   advance_body        - shift body, optional grow, compute new head
;   check_direction     - validate direction change (block 180-degree)
;   check_collision     - head vs border (returns C=1 if hit)
;   check_self_collision - head vs body (returns C=1 if hit)
;   draw_segment        - paint one rounded green cell at (B, C)
;   draw_all_segments   - paint every body segment
;   erase_tail          - black the last segment
;
; State variables:
;   worm_dir, worm_len, frame_count, grow_flag
;   body_x[MAX_LENGTH], body_y[MAX_LENGTH]   (index 0 = head)
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; advance_body
;
; Shift body segments toward the tail (so old head -> index 1, etc.).
; If grow_flag is set, length increases by 1 (and the previous tail
; doesn't get overwritten). Then the new head at index 0 is moved one
; cell in the direction of worm_dir.
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

advance_body:
        ; --- Grow if requested -----------------------------------------
        ld      a, (grow_flag)
        or      a
        jr      z, .shift
        ld      a, (worm_len)
        cp      MAX_LENGTH
        jr      nc, .shift              ; already at cap, don't grow
        inc     a
        ld      (worm_len), a

.shift:
        ; --- Shift body[1..len-1] = body[0..len-2] ----------------------
        ;
        ; LDDR copies BC bytes from HL down to DE (both pre-decrement).
        ; To shift right by one, we want:
        ;   src end = base + len - 2  (= body[len-2])
        ;   dst end = base + len - 1  (= body[len-1])
        ;   count   = len - 1
        ld      a, (worm_len)
        dec     a                       ; A = len - 1
        ret     z                       ; len was 1 -> nothing to shift

        ld      c, a
        ld      b, 0                    ; BC = len - 1 (count)

        ; --- X array ---
        ld      hl, body_x
        add     hl, bc                  ; HL = body_x + len - 1 (dst end)
        ld      d, h
        ld      e, l                    ; DE = same
        dec     hl                      ; HL = body_x + len - 2 (src end)
        push    bc
        lddr
        pop     bc

        ; --- Y array ---
        ld      hl, body_y
        add     hl, bc                  ; HL = body_y + len - 1
        ld      d, h
        ld      e, l
        dec     hl
        lddr

        ; --- Compute new head from old head (now at index 1) -----------
        ld      a, (body_x + 1)
        ld      (body_x), a
        ld      a, (body_y + 1)
        ld      (body_y), a

        ld      a, (worm_dir)
        cp      DIR_UP
        jr      nz, .not_up
        ld      a, (body_y)
        dec     a
        ld      (body_y), a
        ret
.not_up:
        cp      DIR_DOWN
        jr      nz, .not_down
        ld      a, (body_y)
        inc     a
        ld      (body_y), a
        ret
.not_down:
        cp      DIR_LEFT
        jr      nz, .not_left
        ld      a, (body_x)
        dec     a
        ld      (body_x), a
        ret
.not_left:
        ; DIR_RIGHT (or anything else) -> +1 x.
        ld      a, (body_x)
        inc     a
        ld      (body_x), a
        ret

;----------------------------------------------------------------------------
; check_direction
;
; Apply a direction change unless it's a 180-degree reversal of the
; current direction (which would make the worm immediately collide with
; its own neck).
;
; Entry: A = candidate direction (DIR_UP..DIR_RIGHT).
; Clobbers: A, B.
;----------------------------------------------------------------------------

check_direction:
        ld      b, a                    ; B = candidate
        ld      a, (worm_dir)
        cp      DIR_UP
        jr      nz, .cur_not_up
        ld      a, b
        cp      DIR_DOWN
        ret     z                       ; reject
        jr      .accept
.cur_not_up:
        cp      DIR_DOWN
        jr      nz, .cur_not_down
        ld      a, b
        cp      DIR_UP
        ret     z
        jr      .accept
.cur_not_down:
        cp      DIR_LEFT
        jr      nz, .cur_not_left
        ld      a, b
        cp      DIR_RIGHT
        ret     z
        jr      .accept
.cur_not_left:
        ; current is RIGHT (or unset).
        ld      a, b
        cp      DIR_LEFT
        ret     z
.accept:
        ld      a, b
        ld      (worm_dir), a
        ret

;----------------------------------------------------------------------------
; check_collision
;
; Test the head against the playfield border.
;
; Exit: CF = 1 if collision, 0 otherwise.
; Clobbers: A.
;----------------------------------------------------------------------------

check_collision:
        ; X out of range? body_x is unsigned 0..255; "negative" means it
        ; wrapped from 0 to 255 via DEC, which is also detected as
        ; >= GRID_COLS. So one check suffices.
        ld      a, (body_x)
        cp      GRID_COLS
        jr      nc, .hit
        ld      a, (body_y)
        cp      GRID_ROWS
        jr      nc, .hit
        or      a                       ; CF=0
        ret
.hit:
        scf
        ret

;----------------------------------------------------------------------------
; check_self_collision
;
; Test whether the head (index 0) shares a cell with any body segment
; (indices 1..len-1).
;
; Exit: CF = 1 if collision, 0 otherwise.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

check_self_collision:
        ld      a, (worm_len)
        cp      2
        jr      c, .no_hit              ; len < 2 -> no body to hit

        ld      b, a                    ; B = len
        dec     b                       ; B = segments to compare (skip head)
        ld      hl, body_x + 1          ; src for x
        ld      de, body_y + 1          ; src for y
.loop:
        ld      a, (body_x)
        cp      (hl)
        jr      nz, .next
        ld      a, (body_y)
        ex      de, hl                  ; HL = body_y ptr
        cp      (hl)
        ex      de, hl                  ; restore HL = body_x ptr
        jr      z, .hit
.next:
        inc     hl
        inc     de
        djnz    .loop
.no_hit:
        or      a                       ; CF=0
        ret
.hit:
        scf
        ret

;----------------------------------------------------------------------------
; draw_segment
;
; Paint a rounded green segment at grid (B, C). Same shape as the title
; segment / menu-worm segment: vertical bar (1..6, 0..7) + horizontal
; bar (0..7, 1..6).
;
; Entry: B = col, C = row.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

draw_segment:
        ; Save grid coords for the second rect call.
        ld      a, b
        ld      (seg_col), a
        ld      a, c
        ld      (seg_row), a

        call    calc_cell_pixel         ; HL = px, E = py
        ld      (seg_px), hl
        ld      a, e
        ld      (seg_py), a

        ; Vertical bar at (px+1, py), w=6, h=8.
        inc     hl
        ld      bc, 6
        ld      d, 8
        ld      a, COL_GREEN
        call    platform_draw_filled_rect

        ; Horizontal bar at (px, py+1), w=8, h=6.
        ld      hl, (seg_px)
        ld      a, (seg_py)
        inc     a
        ld      e, a
        ld      bc, 8
        ld      d, 6
        ld      a, COL_GREEN
        call    platform_draw_filled_rect
        ret

;----------------------------------------------------------------------------
; draw_all_segments
;
; Paint every body segment. Used by full redraws (game_init, redraw_game,
; pause-cancel).
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

draw_all_segments:
        ld      a, (worm_len)
        or      a
        ret     z

        ld      b, a                    ; B = remaining segments
        ld      hl, body_x
        ld      de, body_y

.loop:
        push    bc
        push    de
        push    hl
        ld      b, (hl)                 ; B = body_x[i]
        ex      de, hl
        ld      c, (hl)                 ; C = body_y[i]
        ex      de, hl
        call    draw_segment            ; clobbers BC; that's why we push
        pop     hl
        pop     de
        inc     hl
        inc     de
        pop     bc
        djnz    .loop
        ret

;----------------------------------------------------------------------------
; erase_tail
;
; Black out the cell at body_x[len-1], body_y[len-1].
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

erase_tail:
        ld      a, (worm_len)
        or      a
        ret     z

        dec     a                       ; A = len - 1
        ld      c, a
        ld      b, 0                    ; BC = len - 1 (offset)

        ld      hl, body_x
        add     hl, bc
        ld      a, (hl)                 ; A = body_x[len-1]
        ld      hl, body_y
        add     hl, bc                  ; BC unchanged - we used A, not B
        ld      c, (hl)                 ; C = body_y[len-1]
        ld      b, a                    ; B = body_x[len-1]
        call    erase_cell
        ret

;----------------------------------------------------------------------------
; State
;----------------------------------------------------------------------------

worm_dir:       defb    0
worm_len:       defb    0
frame_count:    defb    0
grow_flag:      defb    0

seg_col:        defb    0
seg_row:        defb    0
seg_px:         defw    0
seg_py:         defb    0

body_x:         defs    MAX_LENGTH
body_y:         defs    MAX_LENGTH
