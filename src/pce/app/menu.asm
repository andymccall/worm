; ***************************************************************************
;
; menu.asm - Start screen / main menu
;
; Mirrors src/x16/app/menu.asm:show_start_screen. Paints the three menu
; items, runs the input loop, and returns the player's choice in A:
;   1 = START
;   2 = ABOUT
;   3 = DEMO
; PCE has no software-quit so the QUIT item is omitted.
;
; The cursor is a yellow worm-segment block at column CURSOR_COL; it
; lives in this file along with the menu item painter.
;
; ***************************************************************************

        .code

; ===========================================================================
;
; show_start_screen - Paint the menu items + cursor, run the input loop.
; Mirrors src/x16/app/menu.asm:show_start_screen's return convention so a
; future port of main.asm can dispatch identically.
;
; ===========================================================================

show_start_screen:
        ; --- Paint the three menu items in blue (palette 1) ----------------
        lda     #(PAL_BLUE << 4)
        sta     <bat_palette_hi

        lda     #<(MENU_ROW_0 * BAT_LINE + MENU_COL)
        sta     <_di + 0
        lda     #>(MENU_ROW_0 * BAT_LINE + MENU_COL)
        sta     <_di + 1
        call    vdc_di_to_mawr
        lda     #<menu_text_start
        sta     <_bp + 0
        lda     #>menu_text_start
        sta     <_bp + 1
        call    paint_string

        lda     #<(MENU_ROW_1 * BAT_LINE + MENU_COL)
        sta     <_di + 0
        lda     #>(MENU_ROW_1 * BAT_LINE + MENU_COL)
        sta     <_di + 1
        call    vdc_di_to_mawr
        lda     #<menu_text_about
        sta     <_bp + 0
        lda     #>menu_text_about
        sta     <_bp + 1
        call    paint_string

        lda     #<(MENU_ROW_2 * BAT_LINE + MENU_COL)
        sta     <_di + 0
        lda     #>(MENU_ROW_2 * BAT_LINE + MENU_COL)
        sta     <_di + 1
        call    vdc_di_to_mawr
        lda     #<menu_text_demo
        sta     <_bp + 0
        lda     #>menu_text_demo
        sta     <_bp + 1
        call    paint_string

        ; --- Paint the cursor at item 0 -----------------------------------
        stz     <cursor_idx
        stz     <cursor_prev_idx
        call    paint_cursor

        ; --- Input loop ---------------------------------------------------
        ;
        ; CORE's joypad reader fires every vsync and exposes:
        ;   joynow, x  - currently held buttons (x = 0 for player 1)
        ;   joytrg, x  - newly pressed this frame (auto-clears next frame)
        ; Up/Down moves the cursor; B1/B2/RUN selects.

.loop:
        call    wait_vsync

        lda     joytrg
        and     #JOY_U
        beq     .check_down
        lda     <cursor_idx
        bne     .up_no_wrap
        lda     #NUM_MENU_ITEMS         ; wrap: 0 -> NUM -> dec to NUM-1
.up_no_wrap:
        dec     a
        sta     <cursor_idx
        call    repaint_cursor
        bra     .loop

.check_down:
        lda     joytrg
        and     #JOY_D
        beq     .check_select
        lda     <cursor_idx
        inc     a
        cmp     #NUM_MENU_ITEMS
        bcc     .down_store
        lda     #0
.down_store:
        sta     <cursor_idx
        call    repaint_cursor
        bra     .loop

.check_select:
        lda     joytrg
        and     #(JOY_B1 | JOY_B2 | JOY_RUN)
        beq     .loop

        ; Convert cursor_idx (0..2) -> X16/Neo selection code (1..3).
        lda     <cursor_idx
        inc     a
        rts


; ===========================================================================
;
; paint_cursor - Plant the yellow worm-segment cursor at the BAT cell to
; the left of the menu item indexed by <cursor_idx>. CHR_BLOCK is the worm
; tile we uploaded earlier; combined with palette PAL_YELLOW in the BAT
; high nibble, it renders as a yellow block.
;
; ===========================================================================

paint_cursor:
        ; Compute cursor BAT row from cursor_idx (0..2 -> MENU_ROW_0..2).
        ; Items are 2 rows apart so row = MENU_ROW_0 + idx*2.
        ; di = row * 64 + CURSOR_COL.
        lda     <cursor_idx
        asl     a                       ; idx * 2
        clc
        adc     #MENU_ROW_0
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
        adc     #CURSOR_COL
        sta     <_di + 0
        lda     <_di + 1
        adc     #0
        sta     <_di + 1
        call    vdc_di_to_mawr

        lda     #<CHR_BLOCK
        sta     VDC_DL
        lda     #>CHR_BLOCK
        ora     #(PAL_YELLOW << 4)
        sta     VDC_DH
        rts


; ===========================================================================
;
; repaint_cursor - Erase the cursor at its previous position (by writing a
; blank space tile) and paint it at the new <cursor_idx>. The previous
; index is read from <cursor_prev_idx>; we update it after erasing.
;
; ===========================================================================

repaint_cursor:
        ; Recompute the previous BAT address using cursor_prev_idx.
        lda     <cursor_prev_idx
        asl     a
        clc
        adc     #MENU_ROW_0
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
        adc     #CURSOR_COL
        sta     <_di + 0
        lda     <_di + 1
        adc     #0
        sta     <_di + 1
        call    vdc_di_to_mawr

        lda     #<CHR_0x20              ; ASCII ' ' = blank
        sta     VDC_DL
        lda     #>CHR_0x20
        sta     VDC_DH

        ; Update prev = current, then plant the new cursor.
        lda     <cursor_idx
        sta     <cursor_prev_idx
        jmp     paint_cursor


; ===========================================================================
; Menu strings + ZP scratch
; ===========================================================================

        .data

menu_text_start:        db      "START", 0
menu_text_about:        db      "ABOUT", 0
menu_text_demo:         db      "DEMO",  0


        .zp

cursor_idx:       ds 1     ; current selection 0..NUM_MENU_ITEMS-1
cursor_prev_idx:  ds 1     ; previous selection (for cursor erase)
menu_result:      ds 1     ; final selection on B1 press
