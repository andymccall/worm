; ***************************************************************************
;
; wm_drawing.asm - Reusable grid drawing utilities
;
; Mirrors src/x16/api/wm_drawing.asm but speaks tiles (BAT writes) instead
; of pixels (filled rectangles). Each grid cell maps to one BAT cell via
; bat_addr_for_cell (in system/platform.asm); the helpers here plant a
; segment, blank a cell, redraw the whole worm body, or wipe the playfield
; interior.
;
; ***************************************************************************

        .code

; ===========================================================================
;
; draw_segment - Plant a green worm-segment tile at (cell_x, cell_y).
; Mirrors src/x16/engine/worm.asm:draw_segment but writes a single tile
; instead of two filled rects (the rounded-block tile already has the
; corners chopped off, matching the X16/Neo segment shape).
;
; ===========================================================================

draw_segment:
        jsr     bat_addr_for_cell
        lda     #<CHR_BLOCK
        sta     VDC_DL
        lda     #>CHR_BLOCK
        ora     #(PAL_GREEN << 4)
        sta     VDC_DH
        rts


; ===========================================================================
;
; erase_cell - Wipe the BAT cell at (cell_x, cell_y) by writing a blank
; space tile. Mirrors src/x16/api/wm_drawing.asm:erase_cell which paints
; a black filled rect.
;
; ===========================================================================

erase_cell:
        jsr     bat_addr_for_cell
        lda     #<CHR_0x20
        sta     VDC_DL
        lda     #>CHR_0x20
        sta     VDC_DH
        rts


; ===========================================================================
;
; clear_playfield - Wipe the playfield interior (the area inside the green
; border, below the divider) by writing CHR_0x20 (ASCII space) into every
; BAT cell from row PLAYFIELD_TOP_ROW col PLAYFIELD_LEFT_COL to row
; PLAYFIELD_BOT_ROW col PLAYFIELD_RIGHT_COL.
;
; Used by show_about_screen and gameplay screen transitions to reset the
; area after the WORM title + menu items / dead worm.
;
; ===========================================================================

clear_playfield:
        lda     #PLAYFIELD_TOP_ROW
        sta     <pf_clear_row
.row_loop:
        ; di = pf_clear_row * 64 + PLAYFIELD_LEFT_COL
        lda     <pf_clear_row
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
        adc     #PLAYFIELD_LEFT_COL
        sta     <_di + 0
        lda     <_di + 1
        adc     #0
        sta     <_di + 1
        call    vdc_di_to_mawr

        ldx     #PLAYFIELD_WIDTH
.col_loop:
        lda     #<CHR_0x20
        sta     VDC_DL
        lda     #>CHR_0x20
        sta     VDC_DH
        dex
        bne     .col_loop

        inc     <pf_clear_row
        lda     <pf_clear_row
        cmp     #(PLAYFIELD_BOT_ROW + 1)
        bcc     .row_loop
        rts


; ===========================================================================
; ZP scratch
; ===========================================================================

        .zp

pf_clear_row:     ds 1     ; row counter inside clear_playfield

; Grid cell scratch. cell_x / cell_y are set by callers, then drawing
; helpers (draw_segment, erase_cell) read them. Mirrors the X16/Neo
; api/wm_drawing.asm interface.
cell_x:           ds 1     ; grid column (0..GRID_COLS-1)
cell_y:           ds 1     ; grid row    (0..GRID_ROWS-1)
