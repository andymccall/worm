; Worm - (c) 2026 Andy McCall
; Licensed under CC BY-NC 4.0
; https://creativecommons.org/licenses/by-nc/4.0/

; ---------------------------------------------------------------------------
; life.asm - Life pickup spawning, collision, and rendering
; ---------------------------------------------------------------------------
; Manages heart-shaped life pickups on the playfield.
; ---------------------------------------------------------------------------

.export draw_life
.export erase_life
.export spawn_life
.export check_life
.export life_active, life_x, life_y
.export food_since_life

.import platform_set_color
.import platform_random
.import platform_draw_filled_rect
.import calc_cell_pixel, erase_cell
.import draw_heart
.import cell_x, cell_y, cell_px, cell_py
.import gfx_x1, gfx_y1, gfx_x2, gfx_y2
.import body_x, body_y, worm_len
.import food_x, food_y
.import check_pos_vs_spiders_life
.import COLOR_RED

.include "system/wm_equates.inc"

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; draw_life
;   Draws a heart-shaped life pickup at (life_x, life_y).
; ---------------------------------------------------------------------------

.proc draw_life
    lda COLOR_RED
    jsr platform_set_color

    lda life_x
    sta cell_x
    lda life_y
    sta cell_y
    jsr calc_cell_pixel
    jsr draw_heart
    rts
.endproc

; ---------------------------------------------------------------------------
; erase_life
;   Erases the life pickup from the field.
; ---------------------------------------------------------------------------

.proc erase_life
    lda life_x
    sta cell_x
    lda life_y
    sta cell_y
    jsr erase_cell
    rts
.endproc

; ---------------------------------------------------------------------------
; spawn_life
;   Places a life pickup at a random location not on worm, food, or spiders.
; ---------------------------------------------------------------------------

.proc spawn_life
@retry:
    ; Random X in 0..GRID_COLS-1
    jsr platform_random
@mod_x:
    cmp #GRID_COLS
    bcc @x_ok
    sbc #GRID_COLS
    bra @mod_x
@x_ok:
    sta life_x

    ; Random Y in 0..GRID_ROWS-1
    jsr platform_random
@mod_y:
    cmp #GRID_ROWS
    bcc @y_ok
    sbc #GRID_ROWS
    bra @mod_y
@y_ok:
    sta life_y

    ; Check not on food
    lda life_x
    cmp food_x
    bne @check_worm
    lda life_y
    cmp food_y
    beq @retry

@check_worm:
    ldx #0
@check:
    cpx worm_len
    bcs @done
    lda life_x
    cmp body_x, x
    bne @next
    lda life_y
    cmp body_y, x
    beq @retry
@next:
    inx
    bra @check
@done:
    ; Also check life doesn't overlap any spider
    jsr check_pos_vs_spiders_life
    beq @retry
    rts
.endproc

; ---------------------------------------------------------------------------
; check_life
;   Checks if head is on the life pickup. Returns Z=1 if life eaten.
; ---------------------------------------------------------------------------

.proc check_life
    lda life_active
    beq @no
    lda body_x
    cmp life_x
    bne @no
    lda body_y
    cmp life_y
    rts
@no:
    lda #1                  ; clear Z
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "BSS"

life_active:     .res 1     ; 1 if life pickup is on field
life_x:          .res 1     ; life pickup grid column
life_y:          .res 1     ; life pickup grid row
food_since_life: .res 1     ; food eaten since last life spawn
