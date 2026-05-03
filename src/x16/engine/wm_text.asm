; Worm - (c) 2026 Andy McCall
; Licensed under CC BY-NC 4.0
; https://creativecommons.org/licenses/by-nc/4.0/

; ---------------------------------------------------------------------------
; wm_text.asm - Reusable text printing utilities
; ---------------------------------------------------------------------------
; Shared text helpers: decimal byte printing and the border drawing routine.
; These are generic and not tied to specific game entities.
; ---------------------------------------------------------------------------

.export print_byte_decimal
.export draw_border
.export draw_worm_title

.import platform_putc
.import platform_draw_line
.import platform_draw_filled_rect
.import platform_set_color
.import gfx_x1, gfx_y1, gfx_x2, gfx_y2
.import COLOR_GREEN

.include "system/wm_equates.inc"

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; print_byte_decimal
;   Prints A as a 3-char right-justified decimal number (space-padded).
; ---------------------------------------------------------------------------

.proc print_byte_decimal
    cmp #100
    bcs @three_digits
    cmp #10
    bcs @two_digits

    ; One digit: "  N"
    pha
    lda #' '
    jsr platform_putc
    lda #' '
    jsr platform_putc
    pla
    clc
    adc #'0'
    jsr platform_putc
    rts

@two_digits:
    ; Two digits: " NN"
    pha
    lda #' '
    jsr platform_putc
    pla
    ldx #0
@t2_loop:
    cmp #10
    bcc @t2_done
    sbc #10
    inx
    bra @t2_loop
@t2_done:
    pha
    txa
    clc
    adc #'0'
    jsr platform_putc
    pla
    clc
    adc #'0'
    jsr platform_putc
    rts

@three_digits:
    ldx #0
@h_loop:
    cmp #100
    bcc @h_done
    sbc #100
    inx
    bra @h_loop
@h_done:
    pha
    txa
    clc
    adc #'0'
    jsr platform_putc
    pla
    ldx #0
@t3_loop:
    cmp #10
    bcc @t3_done
    sbc #10
    inx
    bra @t3_loop
@t3_done:
    pha
    txa
    clc
    adc #'0'
    jsr platform_putc
    pla
    clc
    adc #'0'
    jsr platform_putc
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_border
;   Draws the green line border. Assumes color is already set.
;   Five lines: top, bottom, left, right, and horizontal divider.
; ---------------------------------------------------------------------------

.proc draw_border
    ; Top line
    lda #<BORDER_X1
    sta gfx_x1
    lda #>BORDER_X1
    sta gfx_x1+1
    lda #<BORDER_Y1
    sta gfx_y1
    lda #>BORDER_Y1
    sta gfx_y1+1
    lda #<BORDER_X2
    sta gfx_x2
    lda #>BORDER_X2
    sta gfx_x2+1
    lda #<BORDER_Y1
    sta gfx_y2
    lda #>BORDER_Y1
    sta gfx_y2+1
    jsr platform_draw_line

    ; Bottom line
    lda #<BORDER_X1
    sta gfx_x1
    lda #>BORDER_X1
    sta gfx_x1+1
    lda #<BORDER_Y2
    sta gfx_y1
    lda #>BORDER_Y2
    sta gfx_y1+1
    lda #<BORDER_X2
    sta gfx_x2
    lda #>BORDER_X2
    sta gfx_x2+1
    lda #<BORDER_Y2
    sta gfx_y2
    lda #>BORDER_Y2
    sta gfx_y2+1
    jsr platform_draw_line

    ; Left line
    lda #<BORDER_X1
    sta gfx_x1
    lda #>BORDER_X1
    sta gfx_x1+1
    lda #<BORDER_Y1
    sta gfx_y1
    lda #>BORDER_Y1
    sta gfx_y1+1
    lda #<BORDER_X1
    sta gfx_x2
    lda #>BORDER_X1
    sta gfx_x2+1
    lda #<BORDER_Y2
    sta gfx_y2
    lda #>BORDER_Y2
    sta gfx_y2+1
    jsr platform_draw_line

    ; Right line
    lda #<BORDER_X2
    sta gfx_x1
    lda #>BORDER_X2
    sta gfx_x1+1
    lda #<BORDER_Y1
    sta gfx_y1
    lda #>BORDER_Y1
    sta gfx_y1+1
    lda #<BORDER_X2
    sta gfx_x2
    lda #>BORDER_X2
    sta gfx_x2+1
    lda #<BORDER_Y2
    sta gfx_y2
    lda #>BORDER_Y2
    sta gfx_y2+1
    jsr platform_draw_line

    ; Divider line (separates status bar from game area)
    lda #<BORDER_X1
    sta gfx_x1
    lda #>BORDER_X1
    sta gfx_x1+1
    lda #<DIVIDER_Y
    sta gfx_y1
    lda #>DIVIDER_Y
    sta gfx_y1+1
    lda #<BORDER_X2
    sta gfx_x2
    lda #>BORDER_X2
    sta gfx_x2+1
    lda #<DIVIDER_Y
    sta gfx_y2
    lda #>DIVIDER_Y
    sta gfx_y2+1
    jsr platform_draw_line
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_worm_title
;   Draws "WORM" using worm body segments at character position X, Y.
;   Each letter is 5 cells wide, 5 cells tall, with 1-cell gaps.
;   Total width = 23 cells (4 letters × 5 + 3 gaps × 1).
; ---------------------------------------------------------------------------

.proc draw_worm_title
    stx wt_base_col
    sty wt_base_row

    lda COLOR_GREEN
    jsr platform_set_color

    ; Draw each of the 4 letters
    lda #0
    sta wt_letter           ; letter index (0..3)
    lda wt_base_col
    sta wt_cur_col          ; current column offset

@next_letter:
    lda wt_letter
    asl a                   ; ×2
    asl a                   ; ×4
    clc
    adc wt_letter           ; ×5 (5 bytes per letter)
    tax                     ; X = offset into bitmap table

    lda #0
    sta wt_row_idx          ; row 0..4

@next_row:
    lda title_bitmaps, x
    sta wt_bits
    stx wt_save_x

    lda #0
    sta wt_col_idx          ; col 0..4

@next_col:
    ; Check if bit 7 is set (leftmost bit = leftmost column)
    lda wt_bits
    bpl @skip_cell

    ; Draw a worm segment at (wt_cur_col + wt_col_idx, wt_base_row + wt_row_idx)
    lda wt_cur_col
    clc
    adc wt_col_idx
    sta wt_cell_col

    lda wt_base_row
    clc
    adc wt_row_idx
    sta wt_cell_row

    jsr draw_title_segment

@skip_cell:
    asl wt_bits             ; shift to next bit
    inc wt_col_idx
    lda wt_col_idx
    cmp #5
    bcc @next_col

    ; Next row of this letter
    ldx wt_save_x
    inx
    inc wt_row_idx
    lda wt_row_idx
    cmp #5
    bcc @next_row

    ; Next letter: advance column by 6 (5 wide + 1 gap)
    lda wt_cur_col
    clc
    adc #6
    sta wt_cur_col

    inc wt_letter
    lda wt_letter
    cmp #4
    bcc @next_letter

    rts
.endproc

; ---------------------------------------------------------------------------
; draw_title_segment
;   Draws a single rounded worm segment at character cell
;   (wt_cell_col, wt_cell_row). pixel = cell * 8.
; ---------------------------------------------------------------------------

.proc draw_title_segment
    ; Calculate pixel X = wt_cell_col * 8 (16-bit)
    lda wt_cell_col
    sta wt_px
    lda #0
    sta wt_px+1
    asl wt_px
    rol wt_px+1
    asl wt_px
    rol wt_px+1
    asl wt_px
    rol wt_px+1

    ; Calculate pixel Y = wt_cell_row * 8
    lda wt_cell_row
    asl a
    asl a
    asl a
    sta wt_py

    ; Vertical bar: (px+1, py) to (px+6, py+7)
    clc
    lda wt_px
    adc #1
    sta gfx_x1
    lda wt_px+1
    adc #0
    sta gfx_x1+1

    lda wt_py
    sta gfx_y1
    lda #0
    sta gfx_y1+1

    clc
    lda wt_px
    adc #6
    sta gfx_x2
    lda wt_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda wt_py
    adc #7
    sta gfx_y2
    lda #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Horizontal bar: (px, py+1) to (px+7, py+6)
    lda wt_px
    sta gfx_x1
    lda wt_px+1
    sta gfx_x1+1

    clc
    lda wt_py
    adc #1
    sta gfx_y1
    lda #0
    sta gfx_y1+1

    clc
    lda wt_px
    adc #7
    sta gfx_x2
    lda wt_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda wt_py
    adc #6
    sta gfx_y2
    lda #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "RODATA"

; Letter bitmaps for WORM title (5 bytes per letter, 5 rows × 5 cols)
; Bits 7..3 represent columns left-to-right. Bits 2..0 unused.
;
; W:              O:              R:              M:
; 1 . . . 1      . 1 1 1 .      1 1 1 1 .      1 . . . 1
; 1 . . . 1      1 . . . 1      1 . . . 1      1 1 . 1 1
; 1 . 1 . 1      1 . . . 1      1 1 1 1 .      1 . 1 . 1
; 1 1 . 1 1      1 . . . 1      1 . 1 . .      1 . . . 1
; 1 . . . 1      . 1 1 1 .      1 . . 1 .      1 . . . 1

title_bitmaps:
    ; W
    .byte %10001000
    .byte %10001000
    .byte %10101000
    .byte %11011000
    .byte %10001000
    ; O
    .byte %01110000
    .byte %10001000
    .byte %10001000
    .byte %10001000
    .byte %01110000
    ; R
    .byte %11110000
    .byte %10001000
    .byte %11110000
    .byte %10100000
    .byte %10010000
    ; M
    .byte %10001000
    .byte %11011000
    .byte %10101000
    .byte %10001000
    .byte %10001000

; ---------------------------------------------------------------------------

.segment "BSS"

wt_base_col:  .res 1       ; starting column
wt_base_row:  .res 1       ; starting row
wt_cur_col:   .res 1       ; current letter's starting column
wt_letter:    .res 1       ; current letter index (0..3)
wt_row_idx:   .res 1       ; current row within letter (0..4)
wt_col_idx:   .res 1       ; current column within letter (0..4)
wt_bits:      .res 1       ; current row bitmap
wt_save_x:    .res 1       ; saved X register
wt_cell_col:  .res 1       ; cell column to draw
wt_cell_row:  .res 1       ; cell row to draw
wt_px:        .res 2       ; pixel x (16-bit)
wt_py:        .res 1       ; pixel y
