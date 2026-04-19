; ---------------------------------------------------------------------------
; wm_text.asm - Reusable text printing utilities
; ---------------------------------------------------------------------------
; Shared text helpers: decimal byte printing and the border drawing routine.
; These are generic and not tied to specific game entities.
; ---------------------------------------------------------------------------

.export print_byte_decimal
.export draw_border

.import platform_putc
.import platform_draw_line
.import gfx_x1, gfx_y1, gfx_x2, gfx_y2

.include "api/wm_equates.inc"

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
