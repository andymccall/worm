; ***************************************************************************
;
; menu_worm.asm - Decorative worm circling the main menu
;
; A small worm loops clockwise around the START / ABOUT / DEMO menu
; options. A yellow flower appears on the path; when eaten the worm
; grows. Mirrors src/x16/app/menu_worm.asm but adapted for PCE tile
; drawing (single BAT writes per cell instead of two filled rects).
;
; The X16/Neo build relied on the 30-second idle timeout kicking the
; menu worm out into attract mode before the worm could overgrow. We
; don't have demo mode yet, so the worm's length is capped at
; MW_MAX_LEN = PATH_LEN / 2 - it grows naturally until that cap is
; reached, then plateaus while still circling and respawning the
; flower.
;
; ***************************************************************************

; ---------------------------------------------------------------------------
; Path geometry (grid coordinates, 0..GRID_COLS-1, 0..GRID_ROWS-1)
; ---------------------------------------------------------------------------
; The PCE menu has 3 items at BAT rows 16, 18, 20, with the cursor at
; BAT col 10 and text at BAT cols 12..16. Subtracting GRID_BAT_ROW (3)
; / GRID_BAT_COL (1) puts the menu in grid rows 13..17, grid cols 9..15.
; The path encloses that region with a 2-cell margin on top/bottom and
; 1-cell-on-cursor + 2-cell-right gap.
;
; Top edge (rightward):  grid cols  8..17, row 11   = 10 cells
; Right edge (down):     col  17, rows 12..19      =  8 cells
; Bottom edge (left):    cols 16..8, row 19        =  9 cells
; Left edge (up):        col  8, rows 18..12       =  7 cells
;                                                 -----------
;                                                  34 cells

PATH_LEN        =       34
MW_MOVE_DELAY   =       3       ; PCE wait_vsync runs ~16Hz, so 3 frames
                                ; = ~190ms/cell (X16/Neo's 10 frames at
                                ; 60Hz = 167ms/cell). Close enough.
MW_MIN_OFFSET   =       PATH_LEN / 2    ; flower spawns at least this far
                                        ; ahead of the head.
MW_MAX_LEN      =       PATH_LEN / 2    ; cap length once attract mode
                                        ; isn't kicking in to reset us.


        .code

; ===========================================================================
;
; menu_worm_init - Reset to a 1-segment worm at path[0]; spawn + draw the
; first flower. Mirrors src/x16/app/menu_worm.asm:menu_worm_init.
;
; ===========================================================================

menu_worm_init:
        stz     mw_head_idx
        stz     mw_frame
        stz     mw_grow

        lda     #1
        sta     mw_len

        ; Draw initial head segment at path[0].
        ldx     #0
        jsr     draw_mw_segment

        ; Spawn + draw the first flower.
        jmp     spawn_flower


; ===========================================================================
;
; menu_worm_update - Called each frame from the menu input loop. Handles
; movement timing, eating the flower, and segment drawing.
; Mirrors src/x16/app/menu_worm.asm:menu_worm_update.
;
; ===========================================================================

menu_worm_update:
        inc     mw_frame
        lda     mw_frame
        cmp     #MW_MOVE_DELAY
        bcc     .done

        ; Time to step.
        stz     mw_frame

        ; --- Erase tail (unless growing) ---
        lda     mw_grow
        bne     .skip_erase

        ; tail_idx = (head_idx - len + 1 + PATH_LEN) % PATH_LEN
        lda     mw_head_idx
        sec
        sbc     mw_len
        clc
        adc     #1
        clc
        adc     #PATH_LEN
.mod_tail:
        cmp     #PATH_LEN
        bcc     .do_erase
        sec
        sbc     #PATH_LEN
        bra     .mod_tail
.do_erase:
        tax
        jsr     erase_mw_cell
        bra     .advance

.skip_erase:
        ; Growing: increase length, clear flag.
        inc     mw_len
        stz     mw_grow

.advance:
        ; Move head forward.
        lda     mw_head_idx
        inc     a
        cmp     #PATH_LEN
        bcc     .store_head
        lda     #0
.store_head:
        sta     mw_head_idx

        ; Draw new head.
        tax
        jsr     draw_mw_segment

        ; Did the head land on the flower?
        lda     mw_head_idx
        cmp     mw_flower_idx
        bne     .done

        ; Ate the flower. Set the grow flag (unless we're at the cap),
        ; then spawn a fresh flower.
        lda     mw_len
        cmp     #MW_MAX_LEN
        bcs     .no_grow
        lda     #1
        sta     mw_grow
.no_grow:
        jmp     spawn_flower

.done:
        rts


; ===========================================================================
;
; spawn_flower - Place the flower at least MW_MIN_OFFSET cells ahead of
; the head. Retries if it lands on a body segment. Mirrors
; src/x16/app/menu_worm.asm:spawn_flower.
;
; ===========================================================================

spawn_flower:
.retry:
        jsr     platform_random
        and     #$0F                    ; 0..15 random
        clc
        adc     #MW_MIN_OFFSET
        clc
        adc     mw_head_idx
.mod:
        cmp     #PATH_LEN
        bcc     .check_body
        sec
        sbc     #PATH_LEN
        bra     .mod

.check_body:
        sta     mw_flower_idx

        ; Walk the body cells (tail to head) and reject if any matches
        ; the flower index.
        lda     mw_head_idx
        sec
        sbc     mw_len
        clc
        adc     #1
        clc
        adc     #PATH_LEN
.mod_tail:
        cmp     #PATH_LEN
        bcc     .got_tail
        sec
        sbc     #PATH_LEN
        bra     .mod_tail
.got_tail:
        tax                             ; X = current path idx (tail)
        lda     mw_len
        sta     mw_save_x               ; iteration counter

.body_loop:
        txa
        cmp     mw_flower_idx
        beq     .retry                  ; on body, retry

        inx
        cpx     #PATH_LEN
        bcc     .no_wrap
        ldx     #0
.no_wrap:
        dec     mw_save_x
        bne     .body_loop

        ; No collision - draw the flower.
        ldx     mw_flower_idx
        jmp     draw_mw_flower


; ===========================================================================
;
; draw_mw_segment - Plant the green worm-segment tile (CHR_BLOCK +
; PAL_GREEN) at path index X. The path tables are in grid coordinates,
; so we feed cell_x/cell_y into bat_addr_for_cell and write the tile.
;
; ===========================================================================

draw_mw_segment:
        lda     path_x, x
        sta     <cell_x
        lda     path_y, x
        sta     <cell_y
        jsr     bat_addr_for_cell

        lda     #<CHR_BLOCK
        sta     VDC_DL
        lda     #>CHR_BLOCK
        ora     #(PAL_GREEN << 4)
        sta     VDC_DH
        rts


; ===========================================================================
;
; draw_mw_flower - Plant the yellow food-clover tile (CHR_FOOD +
; PAL_YELLOW) at path index X.
;
; ===========================================================================

draw_mw_flower:
        lda     path_x, x
        sta     <cell_x
        lda     path_y, x
        sta     <cell_y
        jsr     bat_addr_for_cell

        lda     #<CHR_FOOD
        sta     VDC_DL
        lda     #>CHR_FOOD
        ora     #(PAL_YELLOW << 4)
        sta     VDC_DH
        rts


; ===========================================================================
;
; erase_mw_cell - Wipe the BAT cell at path index X (writes a blank
; space tile).
;
; ===========================================================================

erase_mw_cell:
        lda     path_x, x
        sta     <cell_x
        lda     path_y, x
        sta     <cell_y
        jmp     erase_cell


; ===========================================================================
; Path data (grid coordinates) + state
; ===========================================================================

        .data

; The four edges of the rectangle, walked clockwise starting from the
; top-left corner. All values are GRID coordinates (subtract GRID_BAT_*
; from BAT coordinates - rows 14..22 / cols 9..18 in BAT terms).
;
; Top edge (rightward):  cols 8..17, row 11   = 10 cells
; Right edge (down):     col 17, rows 12..19  =  8 cells
; Bottom edge (left):    cols 16..8, row 19   =  9 cells
; Left edge (up):        col 8, rows 18..12   =  7 cells

path_x:
        ; Top edge (right): cols 8..17
        db      8, 9, 10, 11, 12, 13, 14, 15, 16, 17
        ; Right edge (down): col 17
        db      17, 17, 17, 17, 17, 17, 17, 17
        ; Bottom edge (left): cols 16..8
        db      16, 15, 14, 13, 12, 11, 10, 9, 8
        ; Left edge (up): col 8
        db      8, 8, 8, 8, 8, 8, 8

path_y:
        ; Top edge (right): row 11
        db      11, 11, 11, 11, 11, 11, 11, 11, 11, 11
        ; Right edge (down): rows 12..19
        db      12, 13, 14, 15, 16, 17, 18, 19
        ; Bottom edge (left): row 19
        db      19, 19, 19, 19, 19, 19, 19, 19, 19
        ; Left edge (up): rows 18..12
        db      18, 17, 16, 15, 14, 13, 12


        .bss

mw_head_idx:      ds 1     ; current head position on path (0..PATH_LEN-1)
mw_len:           ds 1     ; current worm length
mw_flower_idx:    ds 1     ; path index of the flower
mw_frame:         ds 1     ; frame counter for move timing
mw_grow:          ds 1     ; grow flag (1 = grow on next move)
mw_save_x:        ds 1     ; temp: saved iteration counter
