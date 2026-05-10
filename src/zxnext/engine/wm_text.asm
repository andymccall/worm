;----------------------------------------------------------------------------
;
; wm_text.asm - Reusable text and chrome drawing utilities
;
; Mirrors the role of src/x16/engine/wm_text.asm and src/pce/engine/
; wm_text.asm (when it lands). The X16 file owns print_byte_decimal,
; draw_border, and draw_worm_title; this Next port will gain the same
; trio over time. For the current milestone only draw_border is needed.
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; draw_border
;
; Draws the green chrome around the playfield: four edges plus the
; horizontal divider that separates the status bar from the game area.
; Coordinates are in 320x240 GAME space (verbatim from X16); the
; platform layer applies the +8 vertical offset for the 320x256 canvas.
;
; Five lines:
;   top      from (BORDER_X1, BORDER_Y1) to (BORDER_X2, BORDER_Y1)
;   bottom   from (BORDER_X1, BORDER_Y2) to (BORDER_X2, BORDER_Y2)
;   left     from (BORDER_X1, BORDER_Y1) to (BORDER_X1, BORDER_Y2)
;   right    from (BORDER_X2, BORDER_Y1) to (BORDER_X2, BORDER_Y2)
;   divider  from (BORDER_X1, DIVIDER_Y) to (BORDER_X2, DIVIDER_Y)
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; paint_string
;
; Paint a null-terminated ASCII string at GAME-space (HL, E) in colour D.
; Each glyph is 8px wide; we advance x by 8 between calls.
;
; Entry: IX = string ptr, HL = x, E = y, D = colour.
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

paint_string:
        ld      (ps_x), hl
        ld      a, e
        ld      (ps_y), a
        ld      a, d
        ld      (ps_colour), a

.next:
        ld      a, (ix+0)
        or      a
        ret     z

        ; Set up putc args.
        push    ix
        ld      hl, (ps_x)
        ld      a, (ps_y)
        ld      e, a
        ld      a, (ps_colour)
        ld      d, a
        ld      a, (ix+0)
        call    platform_putc
        pop     ix

        ; Advance ix by 1, x by 8.
        inc     ix
        ld      hl, (ps_x)
        ld      bc, 8
        add     hl, bc
        ld      (ps_x), hl
        jr      .next

ps_x:           defw    0
ps_y:           defb    0
ps_colour:      defb    0

;----------------------------------------------------------------------------
; print_byte_decimal
;
; Paint A as a 3-char right-justified decimal number (space-padded) at
; GAME-space (HL, E) in colour D. Mirrors the algorithm in
; src/x16/engine/wm_text.asm and src/pce/engine/wm_text.asm so the
; on-screen formatting is identical across ports.
;
; Entry: A = byte value, HL = x, E = y, D = colour.
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

print_byte_decimal:
        ld      (pbd_value), a
        ld      (pbd_x), hl
        ld      a, e
        ld      (pbd_y), a
        ld      a, d
        ld      (pbd_colour), a

        ld      a, (pbd_value)
        cp      100
        jr      nc, .three_digits
        cp      10
        jr      nc, .two_digits

        ; One digit: "  N"
        ld      a, ' '
        call    pbd_emit
        ld      a, ' '
        call    pbd_emit
        ld      a, (pbd_value)
        add     a, '0'
        jp      pbd_emit

.two_digits:
        ld      a, ' '
        call    pbd_emit

        ld      a, (pbd_value)
        ld      b, 0
.t2_loop:
        cp      10
        jr      c, .t2_done
        sub     10
        inc     b
        jr      .t2_loop
.t2_done:
        ld      (pbd_value), a          ; remainder = ones digit
        ld      a, b
        add     a, '0'
        call    pbd_emit
        ld      a, (pbd_value)
        add     a, '0'
        jp      pbd_emit

.three_digits:
        ld      a, (pbd_value)
        ld      b, 0
.h_loop:
        cp      100
        jr      c, .h_done
        sub     100
        inc     b
        jr      .h_loop
.h_done:
        ld      (pbd_value), a
        ld      a, b
        add     a, '0'
        call    pbd_emit

        ld      a, (pbd_value)
        ld      b, 0
.t3_loop:
        cp      10
        jr      c, .t3_done
        sub     10
        inc     b
        jr      .t3_loop
.t3_done:
        ld      (pbd_value), a
        ld      a, b
        add     a, '0'
        call    pbd_emit
        ld      a, (pbd_value)
        add     a, '0'
        jp      pbd_emit

;
; pbd_emit - render the ASCII char in A at the current pbd_x/pbd_y in
; pbd_colour, then advance pbd_x by 8. Internal helper for
; print_byte_decimal only.
;
pbd_emit:
        push    af
        ld      hl, (pbd_x)
        ld      a, (pbd_y)
        ld      e, a
        ld      a, (pbd_colour)
        ld      d, a
        pop     af
        call    platform_putc

        ld      hl, (pbd_x)
        ld      bc, 8
        add     hl, bc
        ld      (pbd_x), hl
        ret

pbd_value:      defb    0
pbd_x:          defw    0
pbd_y:          defb    0
pbd_colour:     defb    0

;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; draw_worm_title
;
; Draws the chunky "WORM" header from worm-body segments. Each letter is
; a 5x5 grid of cells; each cell is 8x8 pixels. Letters are 1 cell apart,
; so the whole title is 23 cells wide (4*5 + 3*1) by 5 cells tall.
;
; Mirrors src/x16/engine/wm_text.asm:draw_worm_title (and the X16 menu
; calls this with cell (9, 5), so we use the same).
;
; Entry: B = base cell column, C = base cell row.
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

draw_worm_title:
        ld      a, b
        ld      (wt_base_col), a
        ld      a, c
        ld      (wt_base_row), a

        ; cur_col tracks the leftmost cell column of the current letter.
        ld      a, b
        ld      (wt_cur_col), a

        xor     a
        ld      (wt_letter), a

.next_letter:
        ; bitmap_ptr = title_bitmaps + letter*5
        ld      a, (wt_letter)
        ld      h, 0
        ld      l, a
        add     hl, hl
        add     hl, hl                  ; *4
        ld      bc, 0
        ld      c, a
        add     hl, bc                  ; *5 (= *4 + *1)
        ld      bc, title_bitmaps
        add     hl, bc
        ld      (wt_bitmap_ptr), hl

        xor     a
        ld      (wt_row_idx), a

.next_row:
        ld      hl, (wt_bitmap_ptr)
        ld      a, (hl)
        ld      (wt_bits), a
        inc     hl
        ld      (wt_bitmap_ptr), hl

        xor     a
        ld      (wt_col_idx), a

.next_col:
        ; If MSB of wt_bits is set, plot a segment at this cell.
        ld      a, (wt_bits)
        rlca
        ld      (wt_bits), a
        jr      nc, .skip_cell

        ; cell_col = cur_col + col_idx; cell_row = base_row + row_idx
        ld      a, (wt_cur_col)
        ld      hl, wt_col_idx
        add     a, (hl)
        ld      (wt_cell_col), a

        ld      a, (wt_base_row)
        ld      hl, wt_row_idx
        add     a, (hl)
        ld      (wt_cell_row), a

        call    draw_title_segment

.skip_cell:
        ld      a, (wt_col_idx)
        inc     a
        ld      (wt_col_idx), a
        cp      5
        jr      c, .next_col

        ; End of row. Advance to next row of this letter.
        ld      a, (wt_row_idx)
        inc     a
        ld      (wt_row_idx), a
        cp      5
        jr      c, .next_row

        ; End of letter. Advance cur_col by 6 (5 wide + 1 gap), bump letter.
        ld      a, (wt_cur_col)
        add     a, 6
        ld      (wt_cur_col), a

        ld      a, (wt_letter)
        inc     a
        ld      (wt_letter), a
        cp      4
        jr      c, .next_letter

        ret

;----------------------------------------------------------------------------
; draw_title_segment
;
; Paints one rounded 8x8 worm-body segment at cell (wt_cell_col,
; wt_cell_row). The shape is a square with the four corner pixels left
; blank: a vertical bar at columns 1..6 (full height) plus a horizontal
; bar at rows 1..6 (full width).
;
; Pixel coordinates: cell_col * 8, cell_row * 8.
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

draw_title_segment:
        ; px = cell_col * 8 (16-bit since cell_col can be 0..38, px up to 304)
        ld      a, (wt_cell_col)
        ld      h, 0
        ld      l, a
        add     hl, hl
        add     hl, hl
        add     hl, hl                  ; HL = px
        ld      (wt_px), hl

        ; py = cell_row * 8 (8-bit fits, max cell_row*8 = 232)
        ld      a, (wt_cell_row)
        add     a, a
        add     a, a
        add     a, a
        ld      (wt_py), a

        ; --- Vertical bar: rect at (px+1, py), width 6, height 8 ---------
        ld      hl, (wt_px)
        inc     hl
        ld      a, (wt_py)
        ld      e, a
        ld      bc, 6                   ; width
        ld      d, 8                    ; height
        ld      a, COL_GREEN
        call    platform_draw_filled_rect

        ; --- Horizontal bar: rect at (px, py+1), width 8, height 6 -------
        ld      hl, (wt_px)
        ld      a, (wt_py)
        inc     a
        ld      e, a
        ld      bc, 8                   ; width
        ld      d, 6                    ; height
        ld      a, COL_GREEN
        call    platform_draw_filled_rect
        ret

;----------------------------------------------------------------------------
; title_bitmaps - 4 letters, 5 rows each, MSB-leftmost in top 5 bits.
;
; Verbatim from src/x16/engine/wm_text.asm:title_bitmaps so the title
; reads identically across ports.
;----------------------------------------------------------------------------

title_bitmaps:
        ; W
        defb    %10001000
        defb    %10001000
        defb    %10101000
        defb    %11011000
        defb    %10001000
        ; O
        defb    %01110000
        defb    %10001000
        defb    %10001000
        defb    %10001000
        defb    %01110000
        ; R
        defb    %11110000
        defb    %10001000
        defb    %11110000
        defb    %10100000
        defb    %10010000
        ; M
        defb    %10001000
        defb    %11011000
        defb    %10101000
        defb    %10001000
        defb    %10001000

;----------------------------------------------------------------------------
; State variables for draw_worm_title.
;----------------------------------------------------------------------------

wt_base_col:    defb    0
wt_base_row:    defb    0
wt_cur_col:     defb    0
wt_letter:      defb    0
wt_row_idx:     defb    0
wt_col_idx:     defb    0
wt_bits:        defb    0
wt_cell_col:    defb    0
wt_cell_row:    defb    0
wt_px:          defw    0
wt_py:          defb    0
wt_bitmap_ptr:  defw    0

;----------------------------------------------------------------------------

draw_border:
        ; Top edge.
        ld      hl, BORDER_X1
        ld      e, BORDER_Y1
        ld      bc, BORDER_X2 - BORDER_X1 + 1
        ld      a, COL_GREEN
        call    platform_draw_hline

        ; Bottom edge.
        ld      hl, BORDER_X1
        ld      e, BORDER_Y2
        ld      bc, BORDER_X2 - BORDER_X1 + 1
        ld      a, COL_GREEN
        call    platform_draw_hline

        ; Left edge.
        ld      hl, BORDER_X1
        ld      e, BORDER_Y1
        ld      bc, BORDER_Y2 - BORDER_Y1 + 1
        ld      a, COL_GREEN
        call    platform_draw_vline

        ; Right edge.
        ld      hl, BORDER_X2
        ld      e, BORDER_Y1
        ld      bc, BORDER_Y2 - BORDER_Y1 + 1
        ld      a, COL_GREEN
        call    platform_draw_vline

        ; Divider line (separates status bar from game area).
        ld      hl, BORDER_X1
        ld      e, DIVIDER_Y
        ld      bc, BORDER_X2 - BORDER_X1 + 1
        ld      a, COL_GREEN
        call    platform_draw_hline

        ret
