; ---------------------------------------------------------------------------
; worm.asm - Worm body management
; ---------------------------------------------------------------------------
; Handles worm body array: advancing, drawing/erasing segments,
; direction validation, wall/self collision detection.
; ---------------------------------------------------------------------------

.export advance_body
.export check_direction
.export check_collision
.export check_self_collision
.export draw_segment
.export draw_all_segments
.export erase_tail
.export worm_dir, worm_len, body_x, body_y
.export grow_flag, frame_count

.import platform_set_color
.import platform_draw_filled_rect
.import calc_cell_pixel
.import erase_cell
.import cell_x, cell_y, cell_px, cell_py
.import gfx_x1, gfx_y1, gfx_x2, gfx_y2
.import COLOR_GREEN

.include "api/wm_equates.inc"

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; advance_body
;   Shifts body segments down. If grow_flag is set, length increases by 1.
;   New head position computed from direction.
; ---------------------------------------------------------------------------

.proc advance_body
    ; If growing, increase length first
    lda grow_flag
    beq @shift

    lda worm_len
    cmp #MAX_LENGTH
    bcs @shift
    inc worm_len

@shift:
    ; Shift all segments down by one (tail towards head)
    ldx worm_len
    dex
@loop:
    cpx #0
    beq @done_shift
    lda body_x - 1, x
    sta body_x, x
    lda body_y - 1, x
    sta body_y, x
    dex
    bne @loop
@done_shift:

    ; Compute new head from old head (now at index 1)
    lda body_x + 1
    sta body_x
    lda body_y + 1
    sta body_y

    lda worm_dir
    cmp #DIR_UP
    bne @not_up
    dec body_y
    rts
@not_up:
    cmp #DIR_DOWN
    bne @not_down
    inc body_y
    rts
@not_down:
    cmp #DIR_LEFT
    bne @not_left
    dec body_x
    rts
@not_left:
    inc body_x
    rts
.endproc

; ---------------------------------------------------------------------------
; check_direction
;   Validates and applies a direction change (prevents 180-degree reversal).
;   A = new direction to try.
; ---------------------------------------------------------------------------

.proc check_direction
    tax
    lda worm_dir

    cpx #DIR_UP
    bne @not_up
    cmp #DIR_DOWN
    beq @reject
    bra @accept
@not_up:
    cpx #DIR_DOWN
    bne @not_down
    cmp #DIR_UP
    beq @reject
    bra @accept
@not_down:
    cpx #DIR_LEFT
    bne @not_left
    cmp #DIR_RIGHT
    beq @reject
    bra @accept
@not_left:
    cpx #DIR_RIGHT
    bne @reject
    cmp #DIR_LEFT
    beq @reject
@accept:
    stx worm_dir
@reject:
    rts
.endproc

; ---------------------------------------------------------------------------
; check_collision
;   Checks if head has hit the border. Returns: C=1 if collision.
; ---------------------------------------------------------------------------

.proc check_collision
    lda body_x
    bmi @hit
    cmp #GRID_COLS
    bcs @hit

    lda body_y
    bmi @hit
    cmp #GRID_ROWS
    bcs @hit

    clc
    rts
@hit:
    sec
    rts
.endproc

; ---------------------------------------------------------------------------
; check_self_collision
;   Checks if head overlaps any body segment. Returns: C=1 if collision.
; ---------------------------------------------------------------------------

.proc check_self_collision
    ldx #1
@loop:
    cpx worm_len
    bcs @no_hit

    lda body_x
    cmp body_x, x
    bne @next
    lda body_y
    cmp body_y, x
    beq @hit

@next:
    inx
    bra @loop

@no_hit:
    clc
    rts
@hit:
    sec
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_all_segments
;   Draws every segment of the worm body.
; ---------------------------------------------------------------------------

.proc draw_all_segments
    ldx #0
@loop:
    cpx worm_len
    bcs @done
    phx
    lda body_x, x
    sta cell_x
    lda body_y, x
    sta cell_y
    jsr draw_segment
    plx
    inx
    bra @loop
@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_segment
;   Draws one worm segment with rounded corners at cell_x, cell_y.
; ---------------------------------------------------------------------------

.proc draw_segment
    lda COLOR_GREEN
    jsr platform_set_color

    jsr calc_cell_pixel

    ; Vertical bar: (px+1, py) to (px+6, py+7)
    clc
    lda cell_px
    adc #1
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
    adc #(CELL_SIZE - 2)
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

    ; Horizontal bar: (px, py+1) to (px+7, py+6)
    lda cell_px
    sta gfx_x1
    lda cell_px+1
    sta gfx_x1+1

    clc
    lda cell_py
    adc #1
    sta gfx_y1
    lda cell_py+1
    adc #0
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
    adc #(CELL_SIZE - 2)
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------
; erase_tail
;   Erases the last segment of the worm body.
; ---------------------------------------------------------------------------

.proc erase_tail
    ldx worm_len
    dex
    lda body_x, x
    sta cell_x
    lda body_y, x
    sta cell_y
    jsr erase_cell
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "BSS"

worm_dir:    .res 1         ; current direction
worm_len:    .res 1         ; current body length
frame_count: .res 1         ; frame counter for movement timing
grow_flag:   .res 1         ; 1 = grow on next move

body_x:      .res MAX_LENGTH ; grid x for each segment (0 = head)
body_y:      .res MAX_LENGTH ; grid y for each segment (0 = head)
