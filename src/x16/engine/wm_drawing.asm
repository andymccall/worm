; Worm - (c) 2026 Andy McCall
; Licensed under CC BY-NC 4.0
; https://creativecommons.org/licenses/by-nc/4.0/

; ---------------------------------------------------------------------------
; wm_drawing.asm - Reusable grid drawing utilities
; ---------------------------------------------------------------------------
; Shared drawing helpers: cell-to-pixel conversion, cell erase, and
; coordinate variables used by all drawing code.
; ---------------------------------------------------------------------------

.export calc_cell_pixel
.export erase_cell
.export cell_x, cell_y, cell_px, cell_py
.export gfx_x1, gfx_y1, gfx_x2, gfx_y2

.include "system/wm_equates.inc"

.import platform_set_color
.import platform_draw_filled_rect

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; calc_cell_pixel
;   Converts cell_x, cell_y to pixel coordinates in cell_px, cell_py.
;   cell_px = cell_x * 8 + GRID_X
;   cell_py = cell_y * 8 + GRID_Y
; ---------------------------------------------------------------------------

.proc calc_cell_pixel
    lda cell_x
    sta cell_px
    lda #0
    sta cell_px+1

    asl cell_px
    rol cell_px+1
    asl cell_px
    rol cell_px+1
    asl cell_px
    rol cell_px+1

    clc
    lda cell_px
    adc #GRID_X
    sta cell_px
    lda cell_px+1
    adc #0
    sta cell_px+1

    lda cell_y
    sta cell_py
    lda #0
    sta cell_py+1

    asl cell_py
    rol cell_py+1
    asl cell_py
    rol cell_py+1
    asl cell_py
    rol cell_py+1

    clc
    lda cell_py
    adc #GRID_Y
    sta cell_py
    lda cell_py+1
    adc #0
    sta cell_py+1
    rts
.endproc

; ---------------------------------------------------------------------------
; erase_cell
;   Erases one cell at cell_x, cell_y by drawing a black filled rect.
; ---------------------------------------------------------------------------

.proc erase_cell
    lda #COLOR_BLACK
    jsr platform_set_color

    jsr calc_cell_pixel

    lda cell_px
    sta gfx_x1
    lda cell_px+1
    sta gfx_x1+1

    lda cell_py
    sta gfx_y1
    lda cell_py+1
    sta gfx_y1+1

    clc
    lda cell_px
    adc #(CELL_SIZE - 1)
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #(CELL_SIZE - 1)
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "BSS"

cell_x:  .res 1            ; temp grid x for drawing
cell_y:  .res 1            ; temp grid y for drawing
cell_px: .res 2            ; temp pixel x (16-bit)
cell_py: .res 2            ; temp pixel y (16-bit)

gfx_x1: .res 2
gfx_y1: .res 2
gfx_x2: .res 2
gfx_y2: .res 2
