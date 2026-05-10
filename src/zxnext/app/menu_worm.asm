;----------------------------------------------------------------------------
;
; menu_worm.asm - Decorative worm circling the main menu
;
; Mirrors src/x16/app/menu_worm.asm. A small worm walks clockwise around
; a 40-cell rectangular path enclosing the SADQ menu options. A flower
; sits ahead of the worm; eating it grows the worm by one segment.
;
; Path layout matches the X16: cols 14..23, rows 13..24 = 40 cells.
;
; The X16/Neo HALs draw rects with (gfx_x1,gfx_y1)..(gfx_x2,gfx_y2)
; (inclusive corners). Our Next HAL takes (x, y, w, h), so the segment
; / flower / erase routines below convert as they go (w = x2-x1+1,
; h = y2-y1+1).
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; Constants
;----------------------------------------------------------------------------

MW_PATH_LEN             equ     44              ; cols 14..26, rows 14..24
MW_MOVE_DELAY           equ     10              ; frames between steps
MW_MIN_OFFSET           equ     MW_PATH_LEN / 2

;----------------------------------------------------------------------------
; menu_worm_init
;
; Reset state and draw the initial head segment + flower. Call once when
; the menu screen is painted, before entering the input loop.
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

menu_worm_init:
        xor     a
        ld      (mw_head_idx), a
        ld      (mw_frame), a
        ld      (mw_grow), a

        ld      a, 1
        ld      (mw_len), a

        ; Draw initial head at path[0].
        ld      a, 0
        call    draw_mw_segment

        call    spawn_flower
        ret

;----------------------------------------------------------------------------
; menu_worm_update
;
; One frame's worth of menu-worm logic. Call from the menu input loop
; after platform_wait_vsync.
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

menu_worm_update:
        ld      a, (mw_frame)
        inc     a
        ld      (mw_frame), a
        cp      MW_MOVE_DELAY
        ret     c                       ; not yet time to move

        xor     a
        ld      (mw_frame), a

        ; --- Erase tail (unless growing) -------------------------------
        ld      a, (mw_grow)
        or      a
        jr      nz, .skip_erase

        ; tail_idx = (head_idx - len + 1 + PATH_LEN) % PATH_LEN
        ld      a, (mw_head_idx)
        ld      hl, mw_len
        sub     (hl)
        inc     a
        add     a, MW_PATH_LEN
.tail_mod:
        cp      MW_PATH_LEN
        jr      c, .do_erase
        sub     MW_PATH_LEN
        jr      .tail_mod

.do_erase:
        call    erase_mw_cell
        jr      .advance_head

.skip_erase:
        ; Growing this step: increase length, clear flag.
        ld      hl, mw_len
        inc     (hl)
        xor     a
        ld      (mw_grow), a

.advance_head:
        ; head_idx = (head_idx + 1) % PATH_LEN
        ld      a, (mw_head_idx)
        inc     a
        cp      MW_PATH_LEN
        jr      c, .store_head
        xor     a
.store_head:
        ld      (mw_head_idx), a

        ; Draw new head segment.
        call    draw_mw_segment

        ; Did we land on the flower? draw_mw_segment clobbers A, so
        ; reload head_idx before the compare.
        ld      a, (mw_head_idx)
        ld      hl, mw_flower_idx
        cp      (hl)
        ret     nz

        ; Eat: set grow flag and respawn the flower.
        ld      a, 1
        ld      (mw_grow), a
        call    spawn_flower
        ret

;----------------------------------------------------------------------------
; spawn_flower
;
; Place the flower at least MW_MIN_OFFSET cells ahead of the head, with a
; small (0..15) random extra offset. Retry if it lands on a body segment.
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

spawn_flower:
.retry:
        call    platform_random
        and     $0F                     ; 0..15
        ld      hl, mw_head_idx
        add     a, (hl)
        add     a, MW_MIN_OFFSET
.mod:
        cp      MW_PATH_LEN
        jr      c, .check_body
        sub     MW_PATH_LEN
        jr      .mod

.check_body:
        ld      (mw_flower_idx), a

        ; Walk the body from tail to head, retrying if any cell matches
        ; the flower index.
        ld      a, (mw_head_idx)
        ld      hl, mw_len
        sub     (hl)
        inc     a
        add     a, MW_PATH_LEN
.tail_mod:
        cp      MW_PATH_LEN
        jr      c, .got_tail
        sub     MW_PATH_LEN
        jr      .tail_mod
.got_tail:
        ld      b, a                    ; B = path index iterator
        ld      a, (mw_len)
        ld      c, a                    ; C = remaining segments

.body_loop:
        ld      a, b
        ld      hl, mw_flower_idx
        cp      (hl)
        jr      z, .retry               ; flower on body, retry

        inc     b
        ld      a, b
        cp      MW_PATH_LEN
        jr      c, .no_wrap
        ld      b, 0
.no_wrap:
        dec     c
        jr      nz, .body_loop

        ; No collision - draw the flower at mw_flower_idx.
        ld      a, (mw_flower_idx)
        call    draw_mw_flower
        ret

;----------------------------------------------------------------------------
; draw_mw_segment
;
; Paint a rounded green segment at path[A]. Same shape as draw_title_segment
; (vertical bar w=6 h=8 at +1,+0; horizontal bar w=8 h=6 at +0,+1).
;
; Entry: A = path index.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

draw_mw_segment:
        call    calc_mw_pixel           ; -> mw_px (16), mw_py (8)

        ; Vertical bar at (px+1, py), 6 wide, 8 tall.
        ld      hl, (mw_px)
        inc     hl
        ld      a, (mw_py)
        ld      e, a
        ld      bc, 6
        ld      d, 8
        ld      a, COL_GREEN
        call    platform_draw_filled_rect

        ; Horizontal bar at (px, py+1), 8 wide, 6 tall.
        ld      hl, (mw_px)
        ld      a, (mw_py)
        inc     a
        ld      e, a
        ld      bc, 8
        ld      d, 6
        ld      a, COL_GREEN
        call    platform_draw_filled_rect
        ret

;----------------------------------------------------------------------------
; draw_mw_flower
;
; Paint a yellow 4-leaf clover at path[A]: top, bottom, left, right
; rectangles forming a cross/flower. Same shape as src/x16 game food.
;
; Entry: A = path index.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

draw_mw_flower:
        call    calc_mw_pixel

        ; Top leaf: (px+2, py) w=4 h=3
        ld      hl, (mw_px)
        ld      bc, 2
        add     hl, bc
        ld      a, (mw_py)
        ld      e, a
        ld      bc, 4
        ld      d, 3
        ld      a, COL_YELLOW
        call    platform_draw_filled_rect

        ; Bottom leaf: (px+2, py+5) w=4 h=3
        ld      hl, (mw_px)
        ld      bc, 2
        add     hl, bc
        ld      a, (mw_py)
        add     a, 5
        ld      e, a
        ld      bc, 4
        ld      d, 3
        ld      a, COL_YELLOW
        call    platform_draw_filled_rect

        ; Left leaf: (px, py+2) w=3 h=4
        ld      hl, (mw_px)
        ld      a, (mw_py)
        add     a, 2
        ld      e, a
        ld      bc, 3
        ld      d, 4
        ld      a, COL_YELLOW
        call    platform_draw_filled_rect

        ; Right leaf: (px+5, py+2) w=3 h=4
        ld      hl, (mw_px)
        ld      bc, 5
        add     hl, bc
        ld      a, (mw_py)
        add     a, 2
        ld      e, a
        ld      bc, 3
        ld      d, 4
        ld      a, COL_YELLOW
        call    platform_draw_filled_rect
        ret

;----------------------------------------------------------------------------
; erase_mw_cell
;
; Black out the 8x8 cell at path[A].
;
; Entry: A = path index.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

erase_mw_cell:
        call    calc_mw_pixel

        ld      hl, (mw_px)
        ld      a, (mw_py)
        ld      e, a
        ld      bc, 8
        ld      d, 8
        ld      a, COL_BLACK
        call    platform_draw_filled_rect
        ret

;----------------------------------------------------------------------------
; calc_mw_pixel
;
; Convert path index in A to pixel coords:
;   mw_px (16-bit) = path_x[A] * 8
;   mw_py (8-bit)  = path_y[A] * 8
;
; Entry: A = path index. Preserves A on exit.
; Clobbers: BC, DE, HL.
;----------------------------------------------------------------------------

calc_mw_pixel:
        ld      (mw_save_idx), a

        ; px = path_x[idx] * 8
        ld      hl, path_x
        ld      d, 0
        ld      e, a
        add     hl, de
        ld      a, (hl)
        ld      h, 0
        ld      l, a
        add     hl, hl
        add     hl, hl
        add     hl, hl
        ld      (mw_px), hl

        ; py = path_y[idx] * 8
        ld      a, (mw_save_idx)
        ld      hl, path_y
        ld      d, 0
        ld      e, a
        add     hl, de
        ld      a, (hl)
        add     a, a
        add     a, a
        add     a, a
        ld      (mw_py), a

        ld      a, (mw_save_idx)
        ret

;----------------------------------------------------------------------------
; Path around the menu items (44 cells, clockwise rectangle).
;
; Diverges from the X16 path: shifted down 1 row (top edge at row 14
; instead of 13) and extended 3 cells further right (right edge at
; col 26 instead of 23) so the rectangle frames the menu items more
; tightly on the Next, where text rendering is slightly wider.
;
; Top edge (right):    (14,14)..(26,14) = 13 cells
; Right edge (down):   (26,15)..(26,24) = 10 cells
; Bottom edge (left):  (25,24)..(14,24) = 12 cells
; Left edge (up):      (14,23)..(14,15) =  9 cells
; Total = 44 cells
;----------------------------------------------------------------------------

path_x:
        defb    14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26
        defb    26, 26, 26, 26, 26, 26, 26, 26, 26, 26
        defb    25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14
        defb    14, 14, 14, 14, 14, 14, 14, 14, 14

path_y:
        defb    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
        defb    15, 16, 17, 18, 19, 20, 21, 22, 23, 24
        defb    24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24
        defb    23, 22, 21, 20, 19, 18, 17, 16, 15

;----------------------------------------------------------------------------
; State
;----------------------------------------------------------------------------

mw_head_idx:    defb    0
mw_len:         defb    0
mw_flower_idx:  defb    0
mw_frame:       defb    0
mw_grow:        defb    0
mw_save_idx:    defb    0
mw_px:          defw    0
mw_py:          defb    0
