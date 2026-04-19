; ---------------------------------------------------------------------------
; status_bar.asm - Status bar and full frame drawing
; ---------------------------------------------------------------------------
; Draws the HUD (food count, lives hearts) and provides the full-frame
; redraw used after screen transitions.
; ---------------------------------------------------------------------------

.export draw_status_bar
.export draw_full_frame
.export draw_heart

.import platform_cls
.import platform_set_color
.import platform_gotoxy_pixel
.import platform_putc
.import platform_draw_filled_rect
.import draw_border
.import print_byte_decimal
.import gfx_x1, gfx_y1, gfx_x2, gfx_y2
.import cell_px, cell_py
.import food_count, lives
.import COLOR_GREEN, COLOR_RED

.include "api/wm_equates.inc"

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; draw_full_frame
;   Full screen redraw: clear + border + status bar.
; ---------------------------------------------------------------------------

.proc draw_full_frame
    jsr platform_cls
    lda COLOR_GREEN
    jsr platform_set_color
    jsr draw_border
    jsr draw_status_bar
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_status_bar
;   Draws the status bar with food count and lives hearts.
; ---------------------------------------------------------------------------

.proc draw_status_bar
    ; Clear status area: black rect from (11,11) to (308,23)
    lda #COLOR_BLACK
    jsr platform_set_color

    lda #11
    sta gfx_x1
    lda #0
    sta gfx_x1+1
    lda #11
    sta gfx_y1
    lda #0
    sta gfx_y1+1
    lda #<308
    sta gfx_x2
    lda #>308
    sta gfx_x2+1
    lda #23
    sta gfx_y2
    lda #0
    sta gfx_y2+1
    jsr platform_draw_filled_rect

    ; Print "FOOD " in green
    lda COLOR_GREEN
    jsr platform_set_color
    lda #<STATUS_FOOD_X
    sta gfx_x1
    lda #>STATUS_FOOD_X
    sta gfx_x1+1
    lda #STATUS_FOOD_Y
    jsr platform_gotoxy_pixel
    ldx #0
@food_text:
    lda food_label, x
    beq @print_count
    jsr platform_putc
    inx
    bne @food_text

@print_count:
    lda food_count
    jsr print_byte_decimal

    ; Print "LIVES " label
    lda #<STATUS_LIVES_X
    sta gfx_x1
    lda #>STATUS_LIVES_X
    sta gfx_x1+1
    lda #STATUS_LIVES_Y
    jsr platform_gotoxy_pixel
    ldx #0
@lives_text:
    lda lives_label, x
    beq @draw_hearts
    jsr platform_putc
    inx
    bne @lives_text

@draw_hearts:
    ; Draw red hearts for each life
    lda COLOR_RED
    jsr platform_set_color

    ldx #0
    lda #<STATUS_HEART_X_START
    sta cell_px
    lda #>STATUS_HEART_X_START
    sta cell_px+1
    lda #STATUS_HEART_Y
    sta cell_py
    lda #0
    sta cell_py+1

@heart_loop:
    cpx lives
    bcs @done
    cpx #STATUS_HEART_MAX
    bcs @done

    phx
    jsr draw_heart
    plx

    ; Advance pixel X by spacing
    clc
    lda cell_px
    adc #STATUS_HEART_SPACING
    sta cell_px
    lda cell_px+1
    adc #0
    sta cell_px+1

    inx
    bra @heart_loop

@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; draw_heart
;   Draws a heart shape at pixel position (cell_px, cell_py).
;   Heart is 7 pixels wide, 6 pixels tall.
;   Assumes color is already set.
; ---------------------------------------------------------------------------

.proc draw_heart
    ; Left bump: (px+1, py) to (px+2, py)
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
    adc #2
    sta gfx_x2
    lda cell_px+1
    adc #0
    sta gfx_x2+1

    lda cell_py
    sta gfx_y2
    lda cell_py+1
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Right bump: (px+4, py) to (px+5, py)
    clc
    lda cell_px
    adc #4
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

    lda cell_py
    sta gfx_y2
    lda cell_py+1
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Wide body: (px, py+1) to (px+6, py+2)
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
    adc #6
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

    ; Taper 1: (px+1, py+3) to (px+5, py+3)
    clc
    lda cell_px
    adc #1
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda cell_py
    adc #3
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
    adc #3
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Taper 2: (px+2, py+4) to (px+4, py+4)
    clc
    lda cell_px
    adc #2
    sta gfx_x1
    lda cell_px+1
    adc #0
    sta gfx_x1+1

    clc
    lda cell_py
    adc #4
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
    adc #4
    sta gfx_y2
    lda cell_py+1
    adc #0
    sta gfx_y2+1

    jsr platform_draw_filled_rect

    ; Point: (px+3, py+5) to (px+3, py+5)
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
    adc #3
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

.segment "RODATA"

food_label:
    .byte "FOOD ", $00

lives_label:
    .byte "LIVES ", $00
