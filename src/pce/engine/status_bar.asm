; ***************************************************************************
;
; status_bar.asm - Status bar (FOOD count + LIVES hearts)
;
; Mirrors src/x16/engine/status_bar.asm:draw_status_bar. The PCE writes
; tiles into the BAT row 1 rather than drawing onto a bitmap, so the
; per-pixel layout differs but the contents and meaning are identical.
;
; ***************************************************************************

        .code

; ===========================================================================
;
; draw_status_bar - Paint the FOOD label + count, the LIVES label, and
; the row of red hearts representing the player's remaining lives.
; Labels and count in green, hearts in red. Reads food_count and lives.
;
; ===========================================================================

draw_status_bar:
        ; --- "FOOD " label in green ----------------------------------------
        lda     #(PAL_GREEN << 4)
        sta     <bat_palette_hi

        lda     #<(STATUS_ROW * BAT_LINE + STATUS_FOOD_COL)
        sta     <_di + 0
        lda     #>(STATUS_ROW * BAT_LINE + STATUS_FOOD_COL)
        sta     <_di + 1
        call    vdc_di_to_mawr
        lda     #<food_label
        sta     <_bp + 0
        lda     #>food_label
        sta     <_bp + 1
        call    paint_string

        ; --- 3-digit food count (space-padded) -----------------------------
        ; MAWR is at the cell after the label thanks to auto-increment, so
        ; we don't need to reposition. print_byte_decimal writes 3 chars.
        lda     food_count
        jsr     print_byte_decimal

        ; --- "LIVES " label in green ---------------------------------------
        lda     #<(STATUS_ROW * BAT_LINE + STATUS_LIVES_COL)
        sta     <_di + 0
        lda     #>(STATUS_ROW * BAT_LINE + STATUS_LIVES_COL)
        sta     <_di + 1
        call    vdc_di_to_mawr
        lda     #<lives_label
        sta     <_bp + 0
        lda     #>lives_label
        sta     <_bp + 1
        call    paint_string

        ; --- Red hearts: one per life, capped at STATUS_HEART_MAX ---------
        ; Step pixel-style by 1 BAT cell; the hearts already have built-in
        ; horizontal padding (col 7 of the tile is blank).
        lda     #<(STATUS_ROW * BAT_LINE + STATUS_HEART_COL)
        sta     <_di + 0
        lda     #>(STATUS_ROW * BAT_LINE + STATUS_HEART_COL)
        sta     <_di + 1
        call    vdc_di_to_mawr

        ldx     #0
.heart_loop:
        cpx     lives
        bcs     .hearts_done
        cpx     #STATUS_HEART_MAX
        bcs     .hearts_done

        ; Plant a CHR_HEART tile in palette PAL_RED.
        lda     #<CHR_HEART
        sta     VDC_DL
        lda     #>CHR_HEART
        ora     #(PAL_RED << 4)
        sta     VDC_DH
        inx
        bra     .heart_loop
.hearts_done:
        rts


; ===========================================================================
; Status bar strings + game state BSS
; ===========================================================================

        .data

; Status bar labels - same names + content as src/x16/engine/status_bar.asm.
food_label:             db      "FOOD ",  0
lives_label:            db      "LIVES ", 0


        .bss

food_count:       ds 1     ; pellets eaten this run (status bar HUD)
lives:            ds 1     ; remaining lives (status bar hearts)
