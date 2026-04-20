; Worm - (c) 2026 Andy McCall
; Licensed under CC BY-NC 4.0
; https://creativecommons.org/licenses/by-nc/4.0/

; ---------------------------------------------------------------------------
; food.asm - Food spawning, collision, and rendering
; ---------------------------------------------------------------------------
; Manages food placement, checks head collision with food, and draws
; the clover-leaf food shape.
; ---------------------------------------------------------------------------

.export spawn_food
.export check_food
.export draw_food
.export food_x, food_y, food_count

.import platform_set_color
.import platform_random
.import platform_draw_filled_rect
.import calc_cell_pixel
.import cell_x, cell_y, cell_px, cell_py
.import gfx_x1, gfx_y1, gfx_x2, gfx_y2
.import body_x, body_y, worm_len
.import life_active, life_x, life_y
.import spider_x, spider_y, spider_count
.import COLOR_YELLOW

.include "api/wm_equates.inc"

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; check_food
;   Checks if head is on the food. Returns: Z=1 if food eaten.
; ---------------------------------------------------------------------------

.proc check_food
    lda body_x
    cmp food_x
    bne @no
    lda body_y
    cmp food_y
    rts
@no:
    lda #1
    rts
.endproc

; ---------------------------------------------------------------------------
; spawn_food
;   Places food at a random location not occupied by worm, life, or spiders.
; ---------------------------------------------------------------------------

.proc spawn_food
@retry:
    jsr platform_random
@mod_x:
    cmp #GRID_COLS
    bcc @x_ok
    sbc #GRID_COLS
    bra @mod_x
@x_ok:
    sta food_x

    jsr platform_random
@mod_y:
    cmp #GRID_ROWS
    bcc @y_ok
    sbc #GRID_ROWS
    bra @mod_y
@y_ok:
    sta food_y

    ; Check food doesn't overlap worm body
    ldx #0
@check:
    cpx worm_len
    bcs @done
    lda food_x
    cmp body_x, x
    bne @next
    lda food_y
    cmp body_y, x
    beq @retry
@next:
    inx
    bra @check
@done:
    ; Check food doesn't overlap life
    lda life_active
    beq @ok
    lda food_x
    cmp life_x
    bne @ok
    lda food_y
    cmp life_y
    beq @retry
@ok:
    ; Check food doesn't overlap any spider
    jsr check_pos_vs_spiders
    beq @retry
    rts
.endproc

; ---------------------------------------------------------------------------
; check_pos_vs_spiders
;   Checks if food_x/food_y overlaps any spider. Z=1 if overlap.
; ---------------------------------------------------------------------------

.proc check_pos_vs_spiders
    ldx #0
@loop:
    cpx spider_count
    bcs @no_hit
    lda food_x
    cmp spider_x, x
    bne @next
    lda food_y
    cmp spider_y, x
    beq @hit
@next:
    inx
    bra @loop
@no_hit:
    lda #1
    rts
@hit:
    lda #0
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_food
;   Draws a clover-leaf shape at the food position in yellow.
; ---------------------------------------------------------------------------

.proc draw_food
    lda COLOR_YELLOW
    jsr platform_set_color

    lda food_x
    sta cell_x
    lda food_y
    sta cell_y
    jsr calc_cell_pixel

    ; Top leaf: (px+2, py) to (px+5, py+2)
    clc
    lda cell_px
    adc #2
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    lda cell_py
    sta gfx_y1
    lda cell_py+1
    sta gfx_y1+1

    clc
    lda cell_px
    adc #5
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #2
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Bottom leaf: (px+2, py+5) to (px+5, py+7)
    clc
    lda cell_px
    adc #2
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda cell_py
    adc #5
    sta gfx_y1
    lda cell_py+1
    adc #0
    sta gfx_y1+1

    clc
    lda cell_px
    adc #5
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #7
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Left leaf: (px, py+2) to (px+2, py+5)
    lda cell_px
    sta gfx_x1
    lda cell_px+1
    sta gfx_x1+1

    clc
    lda cell_py
    adc #2
    sta gfx_y1
    lda cell_py+1
    adc #0
    sta gfx_y1+1

    clc
    lda cell_px
    adc #2
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #5
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Right leaf: (px+5, py+2) to (px+7, py+5)
    clc
    lda cell_px
    adc #5
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda cell_py
    adc #2
    sta gfx_y1
    lda cell_py+1
    adc #0
    sta gfx_y1+1

    clc
    lda cell_px
    adc #7
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #5
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "BSS"

food_x:     .res 1          ; food grid column
food_y:     .res 1          ; food grid row
food_count: .res 1          ; total food eaten this game
