; ---------------------------------------------------------------------------
; spider.asm - Spider management, collision, and rendering
; ---------------------------------------------------------------------------
; Manages spider spawning (circular buffer), collision detection,
; vulnerability state, and spider shape drawing.
; ---------------------------------------------------------------------------

.export check_spider_collision
.export remove_hit_spider
.export spawn_spider
.export draw_all_spiders
.export check_pos_vs_spiders_life
.export spider_x, spider_y, spider_count, spider_head
.export spider_vulnerable, spider_hit_idx
.export food_since_spider

.import platform_set_color
.import platform_random
.import platform_draw_filled_rect
.import calc_cell_pixel, erase_cell
.import cell_x, cell_y, cell_px, cell_py
.import gfx_x1, gfx_y1, gfx_x2, gfx_y2
.import body_x, body_y, worm_len
.import food_x, food_y
.import life_active, life_x, life_y
.import COLOR_YELLOW, COLOR_LGRAY

.include "api/wm_equates.inc"

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; check_spider_collision
;   Checks if head overlaps any spider. Returns: C=1 if collision.
; ---------------------------------------------------------------------------

.proc check_spider_collision
    lda spider_count
    beq @no_hit

    ldx #0
@loop:
    cpx spider_count
    bcs @no_hit

    lda body_x
    cmp spider_x, x
    bne @next
    lda body_y
    cmp spider_y, x
    beq @hit

@next:
    inx
    bra @loop

@no_hit:
    clc
    rts
@hit:
    stx spider_hit_idx
    sec
    rts
.endproc

; ---------------------------------------------------------------------------
; remove_hit_spider
;   Removes the spider at spider_hit_idx by shifting remaining entries down.
;   Erases the spider's cell on screen.
; ---------------------------------------------------------------------------

.proc remove_hit_spider
    ldx spider_hit_idx

    ; Erase from screen
    lda spider_x, x
    sta cell_x
    lda spider_y, x
    sta cell_y
    phx
    jsr erase_cell
    plx

    ; Shift remaining spiders down to fill the gap
    dec spider_count
@shift:
    cpx spider_count
    bcs @fix_head
    lda spider_x + 1, x
    sta spider_x, x
    lda spider_y + 1, x
    sta spider_y, x
    inx
    bra @shift

@fix_head:
    ; Adjust head pointer if it was above the removed index
    lda spider_head
    beq @done
    cmp spider_hit_idx
    bcc @done               ; head < removed: no change
    beq @done               ; head == removed: it shifted down, now correct
    dec spider_head
@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; spawn_spider
;   Adds a spider to the playfield. Uses circular buffer of MAX_SPIDERS.
;   If buffer is full, the oldest spider is erased and overwritten.
; ---------------------------------------------------------------------------

.proc spawn_spider
    ; If at max capacity, erase the oldest spider first
    lda spider_count
    cmp #MAX_SPIDERS
    bcc @find_slot

    ; Erase oldest (at spider_head position)
    ldx spider_head
    lda spider_x, x
    sta cell_x
    lda spider_y, x
    sta cell_y
    jsr erase_cell
    jmp @place

@find_slot:
    ; Slot index = spider_head + spider_count (wrapped)
    lda spider_head
    clc
    adc spider_count
    and #(MAX_SPIDERS - 1)
    tax

@place:
    ; Find random position not overlapping anything
    jsr find_spider_pos

    ; Store position in the slot
    lda spider_tmp_x
    sta spider_x, x
    lda spider_tmp_y
    sta spider_y, x

    ; Update count and head
    lda spider_count
    cmp #MAX_SPIDERS
    bcs @advance_head
    inc spider_count
    rts

@advance_head:
    ; Advance head pointer (circular)
    lda spider_head
    clc
    adc #1
    and #(MAX_SPIDERS - 1)
    sta spider_head
    rts
.endproc

; ---------------------------------------------------------------------------
; find_spider_pos
;   Finds a random grid position for a spider that doesn't conflict.
;   Result stored in spider_tmp_x, spider_tmp_y. Preserves X.
; ---------------------------------------------------------------------------

.proc find_spider_pos
    phx
@retry:
    jsr platform_random
@mod_x:
    cmp #GRID_COLS
    bcc @x_ok
    sbc #GRID_COLS
    bra @mod_x
@x_ok:
    sta spider_tmp_x

    jsr platform_random
@mod_y:
    cmp #GRID_ROWS
    bcc @y_ok
    sbc #GRID_ROWS
    bra @mod_y
@y_ok:
    sta spider_tmp_y

    ; Check not on food
    lda spider_tmp_x
    cmp food_x
    bne @chk_life
    lda spider_tmp_y
    cmp food_y
    beq @retry

@chk_life:
    ; Check not on life
    lda life_active
    beq @chk_worm
    lda spider_tmp_x
    cmp life_x
    bne @chk_worm
    lda spider_tmp_y
    cmp life_y
    beq @retry

@chk_worm:
    ; Check not on worm body
    ldx #0
@worm_loop:
    cpx worm_len
    bcs @chk_spiders
    lda spider_tmp_x
    cmp body_x, x
    bne @worm_next
    lda spider_tmp_y
    cmp body_y, x
    beq @retry_pop
@worm_next:
    inx
    bra @worm_loop

@chk_spiders:
    ; Check not on existing spiders
    ldx #0
@spider_loop:
    cpx spider_count
    bcs @ok
    lda spider_tmp_x
    cmp spider_x, x
    bne @spider_next
    lda spider_tmp_y
    cmp spider_y, x
    beq @retry_pop
@spider_next:
    inx
    bra @spider_loop

@retry_pop:
    bra @retry

@ok:
    plx
    rts
.endproc

; ---------------------------------------------------------------------------
; check_pos_vs_spiders_life
;   Checks if life_x/life_y overlaps any spider. Z=1 if overlap.
; ---------------------------------------------------------------------------

.proc check_pos_vs_spiders_life
    ldx #0
@loop:
    cpx spider_count
    bcs @no_hit
    lda life_x
    cmp spider_x, x
    bne @next
    lda life_y
    cmp spider_y, x
    beq @hit
@next:
    inx
    bra @loop
@no_hit:
    lda #1              ; clear Z
    rts
@hit:
    lda #0              ; set Z
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_all_spiders
;   Draws all active spiders on the playfield.
; ---------------------------------------------------------------------------

.proc draw_all_spiders
    lda spider_count
    beq @done

    ; Choose color based on vulnerability
    lda spider_vulnerable
    beq @normal_color
    lda COLOR_YELLOW
    jmp @set_color
@normal_color:
    lda COLOR_LGRAY
@set_color:
    jsr platform_set_color

    ldx #0
@loop:
    cpx spider_count
    bcs @done
    phx
    lda spider_x, x
    sta cell_x
    lda spider_y, x
    sta cell_y
    jsr calc_cell_pixel
    jsr draw_spider_shape
    plx
    inx
    bra @loop
@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_spider_shape
;   Draws a side-on spider (facing right) at pixel position (cell_px, cell_py).
;   8x8 pixel art using filled rectangles.
;   Assumes color is already set.
; ---------------------------------------------------------------------------

.proc draw_spider_shape
    ; Head: (px+0, py+2) to (px+1, py+3)
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
    adc #1
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #3
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Body: (px+2, py+1) to (px+5, py+4)
    clc
    lda cell_px
    adc #2
    sta gfx_x1
    lda cell_px+1
    adc #0
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
    adc #5
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda cell_py
    adc #4
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Abdomen: (px+5, py+2) to (px+7, py+3)
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
    adc #3
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Front legs: (px+1, py+5) to (px+2, py+5)
    clc
    lda cell_px
    adc #1
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

    ; Front foot: (px+0, py+6)
    lda cell_px
    sta gfx_x1
    lda cell_px+1
    sta gfx_x1+1

    clc
    lda cell_py
    adc #6
    sta gfx_y1
    lda cell_py+1
    adc #0
    sta gfx_y1+1

    lda cell_px
    sta gfx_x2
    lda cell_px+1
    sta gfx_x2+1

    clc
    lda cell_py
    adc #6
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Mid legs: (px+3, py+5) to (px+4, py+5)
    clc
    lda cell_px
    adc #3
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
    adc #4
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

    ; Rear legs: (px+5, py+5) to (px+6, py+5)
    clc
    lda cell_px
    adc #5
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
    adc #6
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

    ; Rear foot: (px+7, py+6)
    clc
    lda cell_px
    adc #7
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda cell_py
    adc #6
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
    adc #6
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "BSS"

spider_x:          .res MAX_SPIDERS  ; spider grid columns (circular buffer)
spider_y:          .res MAX_SPIDERS  ; spider grid rows (circular buffer)
spider_count:      .res 1     ; number of active spiders (0..MAX_SPIDERS)
spider_head:       .res 1     ; index of oldest spider in circular buffer
food_since_spider: .res 1     ; food eaten since last spider spawn
spider_tmp_x:      .res 1     ; temp for spawn positioning
spider_tmp_y:      .res 1     ; temp for spawn positioning
spider_vulnerable: .res 1     ; 1 = spiders are yellow/edible
spider_hit_idx:    .res 1     ; index of spider that was hit
