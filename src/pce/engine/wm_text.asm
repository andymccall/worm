; ***************************************************************************
;
; wm_text.asm - Text rendering helpers + WORM bitmap title
;
; Mirrors src/x16/engine/wm_text.asm. The PCE writes tiles into the BAT
; rather than printing characters into a bitmap framebuffer, so the
; primitives are different but the names and roles are the same:
;   paint_char         - one ASCII glyph at the current MAWR
;   paint_string       - null-terminated string at the current MAWR
;   print_byte_decimal - 3-digit space-padded number
;   paint_worm_title   - the chunky bitmap "WORM" header
;
; ***************************************************************************

        .code

; ===========================================================================
;
; paint_string - Paint a null-terminated ASCII string into the BAT at the
; address currently programmed into MAWR. Each byte is converted to the
; corresponding font tile and combined with the palette nibble in
; <bat_palette_hi> (which the caller must set: pal << 4).
;
; In:    _bp = ptr to string
;        <bat_palette_hi = (palette_index << 4)
; Out:   Trashes A, Y
;
; ===========================================================================

paint_string:
        cly
.loop:
        lda     [_bp], y
        beq     .done
        jsr     paint_char
        iny
        bne     .loop
.done:
        rts


; ===========================================================================
;
; paint_char - Plant a single ASCII byte into the BAT cell currently at
; MAWR (which auto-increments). Combines the font tile index with the
; palette nibble in <bat_palette_hi>.
;
; In:    A = ASCII character
;        <bat_palette_hi = (palette_index << 4)
; Out:   Trashes A
;
; ===========================================================================

paint_char:
        clc
        adc     #<CHR_ZERO              ; tile lo = ASCII + CHR_ZERO lo
        sta     VDC_DL
        lda     #>CHR_ZERO              ; tile hi (always 0 for ASCII range)
        adc     #0                      ; pick up carry from above
        ora     <bat_palette_hi         ; merge palette into high nibble
        sta     VDC_DH
        rts


; ===========================================================================
;
; print_byte_decimal - Paint A as a 3-char right-justified decimal number
; (space-padded) into the BAT at the current MAWR. Mirrors the algorithm
; in src/x16/engine/wm_text.asm so the on-screen formatting is identical.
;
; In:    A = byte value
;        <bat_palette_hi = palette nibble for the digits
; Out:   Trashes A, X, Y
;
; ===========================================================================

print_byte_decimal:
        cmp     #100
        bcs     .three_digits
        cmp     #10
        bcs     .two_digits

        ; One digit: "  N"
        pha
        lda     #' '
        jsr     paint_char
        lda     #' '
        jsr     paint_char
        pla
        clc
        adc     #'0'
        jmp     paint_char

.two_digits:
        ; Two digits: " NN"
        pha
        lda     #' '
        jsr     paint_char
        pla
        ldx     #0
.t2_loop:
        cmp     #10
        bcc     .t2_done
        sbc     #10
        inx
        bra     .t2_loop
.t2_done:
        pha
        txa
        clc
        adc     #'0'
        jsr     paint_char
        pla
        clc
        adc     #'0'
        jmp     paint_char

.three_digits:
        ldx     #0
.h_loop:
        cmp     #100
        bcc     .h_done
        sbc     #100
        inx
        bra     .h_loop
.h_done:
        pha
        txa
        clc
        adc     #'0'
        jsr     paint_char
        pla
        ldx     #0
.t3_loop:
        cmp     #10
        bcc     .t3_done
        sbc     #10
        inx
        bra     .t3_loop
.t3_done:
        pha
        txa
        clc
        adc     #'0'
        jsr     paint_char
        pla
        clc
        adc     #'0'
        jmp     paint_char


; ===========================================================================
;
; paint_worm_title - Paint the chunky bitmap "WORM" title at row 4. Title
; is 4 letters x 5 cells + 3 gaps x 1 cell = 23 cells wide; left margin
; (32 - 23) / 2 = 4 puts the W at column 4. Mirrors the bitmap-driven
; renderer in src/x16/engine/wm_text.asm:draw_worm_title but plants
; CHR_BLOCK tiles into BAT cells instead of drawing rect pairs.
;
; ===========================================================================

paint_worm_title:
        lda     #4
        sta     <title_row
        lda     #4
        sta     <title_col0

        cly                             ; letter index 0..3
.next_letter:
        sty     <title_letter

        ; idx = letter * 5  (5 bytes per letter in title_bitmaps)
        tya
        asl     a                       ; *2
        asl     a                       ; *4
        clc
        adc     <title_letter           ; *5
        sta     <title_idx

        ; current letter origin column = title_col0 + letter*6
        tya
        asl     a                       ; *2
        clc
        adc     <title_letter           ; *3
        asl     a                       ; *6
        clc
        adc     <title_col0
        sta     <title_letter_col

        cly                             ; row 0..4 within letter
.next_row:
        sty     <title_row_idx

        ; bits = title_bitmaps[idx + row]
        clc
        lda     <title_idx
        adc     <title_row_idx
        tax
        lda     title_bitmaps, x
        sta     <title_bits

        ; di = (title_row + row_idx) * BAT_LINE + title_letter_col
        ; BAT_LINE = 64, so we need a left-shift by 6.
        lda     <title_row
        clc
        adc     <title_row_idx
        sta     <_di + 0
        stz     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1

        clc
        lda     <_di + 0
        adc     <title_letter_col
        sta     <_di + 0
        lda     <_di + 1
        adc     #0
        sta     <_di + 1

        call    vdc_di_to_mawr

        ; Walk 5 columns, leftmost bit first (bit 7 = leftmost). Bit lit
        ; -> emit the solid-block tile we uploaded. Otherwise emit blank
        ; (CHR_0x20 + 0 is the font's space glyph).
        ldx     #5
.next_col:
        lda     <title_bits
        bpl     .blank

        lda     #<CHR_BLOCK
        sta     VDC_DL
        lda     #>CHR_BLOCK
        sta     VDC_DH
        bra     .col_done

.blank:
        lda     #<CHR_0x20
        sta     VDC_DL
        lda     #>CHR_0x20
        sta     VDC_DH

.col_done:
        asl     <title_bits
        dex
        bne     .next_col

        ldy     <title_row_idx
        iny
        cpy     #5
        bcc     .next_row

        ldy     <title_letter
        iny
        cpy     #4
        bcs     .done
        jmp     .next_letter
.done:
        rts


; ===========================================================================
; Title bitmap data
; ===========================================================================

        .data

; Letter bitmaps for WORM title (5 bytes per letter, 5 rows x 5 cols).
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
        db      %10001000
        db      %10001000
        db      %10101000
        db      %11011000
        db      %10001000
        ; O
        db      %01110000
        db      %10001000
        db      %10001000
        db      %10001000
        db      %01110000
        ; R
        db      %11110000
        db      %10001000
        db      %11110000
        db      %10100000
        db      %10010000
        ; M
        db      %10001000
        db      %11011000
        db      %10101000
        db      %10001000
        db      %10001000


; ===========================================================================
; Title painter ZP scratch
; ===========================================================================

        .zp

title_row:        ds 1     ; BAT row of title top
title_col0:       ds 1     ; BAT col of first letter
title_letter:     ds 1     ; current letter index 0..3
title_letter_col: ds 1     ; BAT col of current letter origin
title_idx:        ds 1     ; offset into title_bitmaps for current letter
title_row_idx:    ds 1     ; row within letter 0..4
title_bits:       ds 1     ; bitmap byte being shifted out
