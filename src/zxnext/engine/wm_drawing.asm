;----------------------------------------------------------------------------
;
; wm_drawing.asm - Cell-grid drawing helpers
;
; Mirrors src/x16/engine/wm_drawing.asm. Owns:
;   calc_cell_pixel  - convert grid (col, row) -> pixel (x, y)
;   erase_cell       - black out one 8x8 grid cell
;   draw_full_frame  - cls + border + status bar (used after screen
;                      transitions like pause/death/get-ready)
;
; Pixel coordinates are in GAME space (320x240). The platform layer
; applies the +8 vertical offset for the 320x256 Layer 2 canvas.
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; calc_cell_pixel
;
; Convert a grid cell (col, row) to its top-left pixel coordinate.
;
;   pixel_x = col * CELL_SIZE + GRID_X
;   pixel_y = row * CELL_SIZE + GRID_Y
;
; CELL_SIZE = 8, so we shift left 3.
;
; Entry: B = cell col (0..GRID_COLS-1), C = cell row (0..GRID_ROWS-1).
; Exit:  HL = pixel x, E = pixel y.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

calc_cell_pixel:
        ; HL = col * 8 + GRID_X. col can be 0..36, *8 = 0..288, +12 = 0..300.
        ; That overflows 8 bits, so do it 16-bit.
        ld      h, 0
        ld      l, b
        add     hl, hl
        add     hl, hl
        add     hl, hl                  ; HL = col * 8
        ld      de, GRID_X
        add     hl, de                  ; HL = pixel x

        ; py = row * 8 + GRID_Y. row 0..24, *8 = 0..192, +26 = 0..218 (8-bit).
        ld      a, c
        add     a, a
        add     a, a
        add     a, a                    ; A = row * 8
        add     a, GRID_Y
        ld      e, a
        ret

;----------------------------------------------------------------------------
; erase_cell
;
; Black out one 8x8 grid cell at (B, C).
;
; Entry: B = cell col, C = cell row.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

erase_cell:
        call    calc_cell_pixel         ; HL=px, E=py
        ld      bc, CELL_SIZE
        ld      d, CELL_SIZE
        ld      a, COL_BLACK
        call    platform_draw_filled_rect
        ret

;----------------------------------------------------------------------------
; draw_full_frame
;
; Repaint the playfield chrome: cls + border + status bar. Used after
; pause/quit-cancel and as part of game_run's startup sequence.
;
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

draw_full_frame:
        ld      a, COL_BLACK
        call    platform_cls
        call    draw_border
        call    draw_status_bar
        ret
