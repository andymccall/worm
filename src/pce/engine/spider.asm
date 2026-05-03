; ***************************************************************************
;
; spider.asm - Spider management, collision, and rendering
;
; Mirrors src/x16/engine/spider.asm. Manages spider spawning (circular
; buffer of MAX_SPIDERS), collision detection against the worm head,
; vulnerability state, and tile rendering for active spiders. Spiders
; don't move once placed - they accumulate over time, gradually
; shrinking the safe playfield.
;
; Vulnerability mode is triggered by game.asm when the player eats food
; while at MAX_LIVES. Spiders turn yellow and become edible; eating any
; food (including no spider) ends the window. Eating a vulnerable spider
; removes it from the buffer.
;
; ***************************************************************************

        .code

; ===========================================================================
;
; check_spider_collision - Test whether the worm's head shares a cell
; with any active spider. Sets spider_hit_idx to the index of the
; offender on hit. Returns C=1 if collision, C=0 otherwise. Mirrors
; src/x16/engine/spider.asm:check_spider_collision.
;
; ===========================================================================

check_spider_collision:
        lda     spider_count
        beq     .no_hit

        ldx     #0
.loop:
        cpx     spider_count
        bcs     .no_hit
        lda     body_x
        cmp     spider_x, x
        bne     .next
        lda     body_y
        cmp     spider_y, x
        beq     .hit
.next:
        inx
        bra     .loop

.no_hit:
        clc
        rts
.hit:
        stx     spider_hit_idx
        sec
        rts


; ===========================================================================
;
; remove_hit_spider - Remove the spider at spider_hit_idx by shifting
; remaining entries down. Erases the spider's BAT cell on screen and
; adjusts the circular buffer's head pointer if needed. Mirrors
; src/x16/engine/spider.asm:remove_hit_spider.
;
; ===========================================================================

remove_hit_spider:
        ldx     spider_hit_idx

        ; Erase the spider's BAT cell.
        lda     spider_x, x
        sta     <cell_x
        lda     spider_y, x
        sta     <cell_y
        phx
        jsr     erase_cell
        plx

        ; Shift remaining spiders down to fill the gap.
        dec     spider_count
.shift:
        cpx     spider_count
        bcs     .fix_head
        lda     spider_x + 1, x
        sta     spider_x, x
        lda     spider_y + 1, x
        sta     spider_y, x
        inx
        bra     .shift

.fix_head:
        ; Adjust head pointer if the removed index was at or above it.
        ; Matches the X16/Neo logic exactly.
        lda     spider_head
        beq     .done
        cmp     spider_hit_idx
        bcc     .done                   ; head < removed: no change
        beq     .done                   ; head == removed: shifted into place
        dec     spider_head
.done:
        rts


; ===========================================================================
;
; spawn_spider - Add a spider to the playfield. Uses a circular buffer
; of MAX_SPIDERS. If full, the oldest spider is erased and overwritten
; (head advances). Mirrors src/x16/engine/spider.asm:spawn_spider.
;
; ===========================================================================

spawn_spider:
        ; If at max capacity, erase the oldest spider first.
        lda     spider_count
        cmp     #MAX_SPIDERS
        bcc     .find_slot

        ; Erase oldest at spider_head.
        ldx     spider_head
        lda     spider_x, x
        sta     <cell_x
        lda     spider_y, x
        sta     <cell_y
        jsr     erase_cell
        bra     .place

.find_slot:
        ; Slot index = (spider_head + spider_count) wrapped to MAX_SPIDERS.
        lda     spider_head
        clc
        adc     spider_count
        and     #(MAX_SPIDERS - 1)
        tax

.place:
        ; Find a random position not overlapping anything; result in
        ; spider_tmp_x / spider_tmp_y, X preserved.
        jsr     find_spider_pos

        ; Store position in slot X.
        lda     spider_tmp_x
        sta     spider_x, x
        lda     spider_tmp_y
        sta     spider_y, x

        ; Update count + head.
        lda     spider_count
        cmp     #MAX_SPIDERS
        bcs     .advance_head
        inc     spider_count
        rts

.advance_head:
        ; Advance head (circular).
        lda     spider_head
        inc     a
        and     #(MAX_SPIDERS - 1)
        sta     spider_head
        rts


; ===========================================================================
;
; find_spider_pos - Pick a random grid cell that doesn't overlap food,
; the worm body, or any existing spider. Result stored in spider_tmp_x /
; spider_tmp_y. Preserves X. Mirrors src/x16/engine/spider.asm:
; find_spider_pos but skips the life-pickup check (life isn't ported on
; PCE yet).
;
; ===========================================================================

find_spider_pos:
        phx
.retry:
        jsr     platform_random
.mod_x:
        cmp     #GRID_COLS
        bcc     .x_ok
        sbc     #GRID_COLS
        bra     .mod_x
.x_ok:
        sta     spider_tmp_x

        jsr     platform_random
.mod_y:
        cmp     #GRID_ROWS
        bcc     .y_ok
        sbc     #GRID_ROWS
        bra     .mod_y
.y_ok:
        sta     spider_tmp_y

        ; Reject if on food.
        lda     spider_tmp_x
        cmp     food_x
        bne     .chk_life
        lda     spider_tmp_y
        cmp     food_y
        beq     .retry

.chk_life:
        ; Reject if on the active life pickup.
        lda     life_active
        beq     .chk_worm
        lda     spider_tmp_x
        cmp     life_x
        bne     .chk_worm
        lda     spider_tmp_y
        cmp     life_y
        beq     .retry

.chk_worm:
        ; Reject if on the worm body.
        ldx     #0
.worm_loop:
        cpx     worm_len
        bcs     .chk_spiders
        lda     spider_tmp_x
        cmp     body_x, x
        bne     .worm_next
        lda     spider_tmp_y
        cmp     body_y, x
        beq     .retry
.worm_next:
        inx
        bra     .worm_loop

.chk_spiders:
        ; Reject if on an existing spider.
        ldx     #0
.spider_loop:
        cpx     spider_count
        bcs     .ok
        lda     spider_tmp_x
        cmp     spider_x, x
        bne     .spider_next
        lda     spider_tmp_y
        cmp     spider_y, x
        beq     .retry
.spider_next:
        inx
        bra     .spider_loop

.ok:
        plx
        rts


; ===========================================================================
;
; check_pos_vs_spiders - Test whether the cell in (cell_x, cell_y)
; overlaps any active spider. Returns Z=1 if overlap, Z=0 if not.
; Public so food spawning can call it (mirrors check_pos_vs_spiders in
; src/x16/engine/food.asm). Trashes A, X.
;
; ===========================================================================

check_pos_vs_spiders:
        ldx     #0
.loop:
        cpx     spider_count
        bcs     .no_hit
        lda     <cell_x
        cmp     spider_x, x
        bne     .next
        lda     <cell_y
        cmp     spider_y, x
        beq     .hit
.next:
        inx
        bra     .loop
.no_hit:
        lda     #1
        rts
.hit:
        lda     #0
        rts


; ===========================================================================
;
; draw_all_spiders - Paint every active spider's BAT cell. Picks the
; palette based on spider_vulnerable: PAL_YELLOW when set, PAL_GRAY
; otherwise. Mirrors src/x16/engine/spider.asm:draw_all_spiders.
;
; ===========================================================================

draw_all_spiders:
        lda     spider_count
        beq     .done

        ; Pick palette nibble for the BAT cells.
        lda     spider_vulnerable
        beq     .normal_pal
        lda     #(PAL_YELLOW << 4)
        bra     .have_pal
.normal_pal:
        lda     #(PAL_GRAY << 4)
.have_pal:
        sta     <spider_pal_hi

        ldx     #0
.loop:
        cpx     spider_count
        bcs     .done
        phx
        lda     spider_x, x
        sta     <cell_x
        lda     spider_y, x
        sta     <cell_y
        jsr     bat_addr_for_cell
        lda     #<CHR_SPIDER
        sta     VDC_DL
        lda     #>CHR_SPIDER
        ora     <spider_pal_hi
        sta     VDC_DH
        plx
        inx
        bra     .loop
.done:
        rts


; ===========================================================================
; Spider state BSS (matches src/x16/engine/spider.asm BSS layout)
; ===========================================================================

        .bss

spider_x:          ds MAX_SPIDERS    ; spider grid columns (circular buffer)
spider_y:          ds MAX_SPIDERS    ; spider grid rows
spider_count:      ds 1     ; number of active spiders (0..MAX_SPIDERS)
spider_head:       ds 1     ; index of oldest spider in circular buffer
food_since_spider: ds 1     ; food eaten since last spider spawn
spider_tmp_x:      ds 1     ; temp for spawn positioning
spider_tmp_y:      ds 1     ; temp for spawn positioning
spider_vulnerable: ds 1     ; 1 = spiders are yellow / edible
spider_hit_idx:    ds 1     ; index of spider that was hit


; ===========================================================================
; ZP scratch
; ===========================================================================

        .zp

spider_pal_hi:     ds 1     ; palette nibble used by draw_all_spiders
