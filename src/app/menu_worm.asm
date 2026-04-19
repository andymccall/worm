; ---------------------------------------------------------------------------
; menu_worm.asm - Decorative worm circling the main menu
; ---------------------------------------------------------------------------
; A small worm loops clockwise around the SADQ menu options.
; A flower appears on the path; when eaten the worm grows.
; The flower spawns at least half the path ahead of the head.
; ---------------------------------------------------------------------------

.export menu_worm_init
.export menu_worm_update

.import platform_set_color
.import platform_draw_filled_rect
.import platform_random
.import gfx_x1, gfx_y1, gfx_x2, gfx_y2
.import COLOR_GREEN, COLOR_YELLOW

; ---------------------------------------------------------------------------
; Constants
; ---------------------------------------------------------------------------

PATH_LEN      = 40          ; total cells in the loop
MW_MOVE_DELAY = 10          ; frames between steps
MW_MIN_OFFSET = 20          ; minimum flower distance (half path)

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; menu_worm_init
;   Resets the menu worm to starting state and draws initial segment
;   and flower.
; ---------------------------------------------------------------------------

.proc menu_worm_init
    lda #0
    sta mw_head_idx
    sta mw_frame
    sta mw_grow

    lda #1
    sta mw_len

    ; Draw initial head segment at path[0]
    ldx #0
    jsr draw_mw_segment

    ; Spawn and draw initial flower
    jsr spawn_flower
    rts
.endproc

; ---------------------------------------------------------------------------
; menu_worm_update
;   Called each frame from the menu input loop.
;   Handles timing, movement, eating, and drawing.
; ---------------------------------------------------------------------------

.proc menu_worm_update
    ; Tick frame counter
    inc mw_frame
    lda mw_frame
    cmp #MW_MOVE_DELAY
    bcc @done

    ; Time to move
    lda #0
    sta mw_frame

    ; --- Erase tail (unless growing) ---
    lda mw_grow
    bne @skip_erase

    ; tail_idx = (head_idx - len + 1 + PATH_LEN) % PATH_LEN
    lda mw_head_idx
    sec
    sbc mw_len
    clc
    adc #1
    clc
    adc #PATH_LEN
@mod_tail:
    cmp #PATH_LEN
    bcc @do_erase
    sec
    sbc #PATH_LEN
    bra @mod_tail

@do_erase:
    tax
    jsr erase_mw_cell
    bra @advance

@skip_erase:
    ; Growing: increase length, clear flag
    inc mw_len
    lda #0
    sta mw_grow

@advance:
    ; Move head forward
    lda mw_head_idx
    clc
    adc #1
    cmp #PATH_LEN
    bcc @store_head
    lda #0
@store_head:
    sta mw_head_idx

    ; Draw new head
    tax
    jsr draw_mw_segment

    ; --- Check if head hit flower ---
    lda mw_head_idx
    cmp mw_flower_idx
    bne @done

    ; Ate the flower: set grow flag, spawn new one
    lda #1
    sta mw_grow
    jsr spawn_flower

@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; spawn_flower
;   Places flower at least MW_MIN_OFFSET positions ahead of head.
;   offset = 18 + (random & 15) → range 18..33
; ---------------------------------------------------------------------------

.proc spawn_flower
    jsr platform_random
    and #$0F                ; 0..15
    clc
    adc #MW_MIN_OFFSET      ; 18..33
    clc
    adc mw_head_idx
@mod:
    cmp #PATH_LEN
    bcc @store
    sec
    sbc #PATH_LEN
    bra @mod
@store:
    sta mw_flower_idx
    tax
    jsr draw_mw_flower
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_mw_segment
;   Draws a rounded worm segment at path index X (same style as game worm).
; ---------------------------------------------------------------------------

.proc draw_mw_segment
    stx mw_save_x
    lda COLOR_GREEN
    jsr platform_set_color
    ldx mw_save_x

    ; Get pixel coords into mw_px (16-bit x), mw_py (y fits in 8 bits)
    jsr calc_mw_pixel

    ; Vertical bar: (px+1, py) to (px+6, py+7)
    clc
    lda mw_px
    adc #1
    sta gfx_x1
    lda mw_px+1
    adc #0
    sta gfx_x1+1

    lda mw_py
    sta gfx_y1
    lda #0
    sta gfx_y1+1

    clc
    lda mw_px
    adc #6
    sta gfx_x2
    lda mw_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda mw_py
    adc #7
    sta gfx_y2
    lda #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Horizontal bar: (px, py+1) to (px+7, py+6)
    lda mw_px
    sta gfx_x1
    lda mw_px+1
    sta gfx_x1+1

    clc
    lda mw_py
    adc #1
    sta gfx_y1
    lda #0
    sta gfx_y1+1

    clc
    lda mw_px
    adc #7
    sta gfx_x2
    lda mw_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda mw_py
    adc #6
    sta gfx_y2
    lda #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_mw_flower
;   Draws a clover-leaf flower at path index X (same style as game food).
; ---------------------------------------------------------------------------

.proc draw_mw_flower
    stx mw_save_x
    lda COLOR_YELLOW
    jsr platform_set_color
    ldx mw_save_x

    jsr calc_mw_pixel

    ; Top leaf: (px+2, py) to (px+5, py+2)
    clc
    lda mw_px
    adc #2
    sta gfx_x1
    lda mw_px+1
    adc #0
    sta gfx_x1+1

    lda mw_py
    sta gfx_y1
    lda #0
    sta gfx_y1+1

    clc
    lda mw_px
    adc #5
    sta gfx_x2
    lda mw_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda mw_py
    adc #2
    sta gfx_y2
    lda #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Bottom leaf: (px+2, py+5) to (px+5, py+7)
    clc
    lda mw_px
    adc #2
    sta gfx_x1
    lda mw_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda mw_py
    adc #5
    sta gfx_y1
    lda #0
    sta gfx_y1+1

    clc
    lda mw_px
    adc #5
    sta gfx_x2
    lda mw_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda mw_py
    adc #7
    sta gfx_y2
    lda #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Left leaf: (px, py+2) to (px+2, py+5)
    lda mw_px
    sta gfx_x1
    lda mw_px+1
    sta gfx_x1+1

    clc
    lda mw_py
    adc #2
    sta gfx_y1
    lda #0
    sta gfx_y1+1

    clc
    lda mw_px
    adc #2
    sta gfx_x2
    lda mw_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda mw_py
    adc #5
    sta gfx_y2
    lda #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Right leaf: (px+5, py+2) to (px+7, py+5)
    clc
    lda mw_px
    adc #5
    sta gfx_x1
    lda mw_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda mw_py
    adc #2
    sta gfx_y1
    lda #0
    sta gfx_y1+1

    clc
    lda mw_px
    adc #7
    sta gfx_x2
    lda mw_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda mw_py
    adc #5
    sta gfx_y2
    lda #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------
; erase_mw_cell
;   Erases one cell at path index X (draws black filled rect).
; ---------------------------------------------------------------------------

.proc erase_mw_cell
    stx mw_save_x
    lda #0              ; COLOR_BLACK
    jsr platform_set_color
    ldx mw_save_x

    jsr calc_mw_pixel

    lda mw_px
    sta gfx_x1
    lda mw_px+1
    sta gfx_x1+1

    lda mw_py
    sta gfx_y1
    lda #0
    sta gfx_y1+1

    clc
    lda mw_px
    adc #7
    sta gfx_x2
    lda mw_px+1
    adc #0
    sta gfx_x2+1

    clc
    lda mw_py
    adc #7
    sta gfx_y2
    lda #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect
    rts
.endproc

; ---------------------------------------------------------------------------
; calc_mw_pixel
;   Converts path index in X to pixel coords in mw_px (16-bit), mw_py (8-bit).
;   pixel_x = path_x[X] * 8, pixel_y = path_y[X] * 8
; ---------------------------------------------------------------------------

.proc calc_mw_pixel
    ; px = path_x[X] * 8
    lda path_x, x
    sta mw_px
    lda #0
    sta mw_px+1
    asl mw_px
    rol mw_px+1
    asl mw_px
    rol mw_px+1
    asl mw_px
    rol mw_px+1

    ; py = path_y[X] * 8
    lda path_y, x
    asl a
    asl a
    asl a
    sta mw_py
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "RODATA"

; Path around menu items (clockwise rectangle)
; Menu text occupies cols 16-24, rows 16-22
; Path: cols 14-23, rows 13-24 (gap on all sides)
;
; Top edge (right):  (14,13)..(23,13) = 10 cells
; Right edge (down): (23,14)..(23,24) = 11 cells
; Bottom edge (left): (22,24)..(14,24) =  9 cells
; Left edge (up):    (14,23)..(14,14) = 10 cells
; Total = 40 cells

path_x:
    ; Top edge (right): cols 14..23
    .byte 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
    ; Right edge (down): col 23
    .byte 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23
    ; Bottom edge (left): cols 22..14
    .byte 22, 21, 20, 19, 18, 17, 16, 15, 14
    ; Left edge (up): col 14
    .byte 14, 14, 14, 14, 14, 14, 14, 14, 14, 14

path_y:
    ; Top edge (right): row 13
    .byte 13, 13, 13, 13, 13, 13, 13, 13, 13, 13
    ; Right edge (down): rows 14..24
    .byte 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24
    ; Bottom edge (left): row 24
    .byte 24, 24, 24, 24, 24, 24, 24, 24, 24
    ; Left edge (up): rows 23..14
    .byte 23, 22, 21, 20, 19, 18, 17, 16, 15, 14

; ---------------------------------------------------------------------------

.segment "BSS"

mw_head_idx:   .res 1      ; current head position on path (0..39)
mw_len:        .res 1      ; current worm length
mw_flower_idx: .res 1      ; path index of the flower
mw_frame:      .res 1      ; frame counter for move timing
mw_grow:       .res 1      ; grow flag (1 = grow on next move)
mw_save_x:     .res 1      ; temp: saved X register
mw_px:         .res 2      ; temp: pixel x (16-bit)
mw_py:         .res 1      ; temp: pixel y (8-bit)
