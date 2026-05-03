; ***************************************************************************
;
; life.asm - Life pickup spawning, collision, and rendering
;
; Mirrors src/x16/engine/life.asm. Manages a single optional life pickup
; on the playfield: spawned every LIFE_SPAWN_FOOD pellets eaten (only
; when lives < MAX_LIVES), eaten by ramming the worm's head into it,
; and consumed if the player eats a food pellet while one is active.
;
; The pickup uses CHR_HEART in palette PAL_RED - the same tile/palette
; pair as the LIVES status counter, just plotted into the playfield
; instead of the status bar.
;
; ***************************************************************************

        .code

; ===========================================================================
;
; draw_life - Paint the life pickup tile at (life_x, life_y) in red.
; Mirrors src/x16/engine/life.asm:draw_life.
;
; ===========================================================================

draw_life:
        lda     life_x
        sta     <cell_x
        lda     life_y
        sta     <cell_y
        jsr     bat_addr_for_cell

        lda     #<CHR_HEART
        sta     VDC_DL
        lda     #>CHR_HEART
        ora     #(PAL_RED << 4)
        sta     VDC_DH
        rts


; ===========================================================================
;
; erase_life - Wipe the life pickup's BAT cell. Mirrors
; src/x16/engine/life.asm:erase_life.
;
; ===========================================================================

erase_life:
        lda     life_x
        sta     <cell_x
        lda     life_y
        sta     <cell_y
        jmp     erase_cell


; ===========================================================================
;
; spawn_life - Pick a random grid cell that doesn't overlap food, the
; worm body, or any active spider. Mirrors src/x16/engine/life.asm:
; spawn_life. Caller is expected to set life_active = 1 after spawning.
;
; ===========================================================================

spawn_life:
.retry:
        ; Random X in 0..GRID_COLS-1
        jsr     platform_random
.mod_x:
        cmp     #GRID_COLS
        bcc     .x_ok
        sbc     #GRID_COLS
        bra     .mod_x
.x_ok:
        sta     life_x

        ; Random Y in 0..GRID_ROWS-1
        jsr     platform_random
.mod_y:
        cmp     #GRID_ROWS
        bcc     .y_ok
        sbc     #GRID_ROWS
        bra     .mod_y
.y_ok:
        sta     life_y

        ; Reject if on food.
        lda     life_x
        cmp     food_x
        bne     .check_worm
        lda     life_y
        cmp     food_y
        beq     .retry

.check_worm:
        ; Reject if on the worm body.
        ldx     #0
.worm_loop:
        cpx     worm_len
        bcs     .check_spiders
        lda     life_x
        cmp     body_x, x
        bne     .worm_next
        lda     life_y
        cmp     body_y, x
        beq     .retry
.worm_next:
        inx
        bra     .worm_loop

.check_spiders:
        ; Reject if on an existing spider. Reuse spider.asm's helper which
        ; reads cell_x / cell_y, so populate those first.
        lda     life_x
        sta     <cell_x
        lda     life_y
        sta     <cell_y
        jsr     check_pos_vs_spiders
        beq     .retry
        rts


; ===========================================================================
;
; check_life - Test whether the worm's head shares a cell with the
; active life pickup. Returns Z=1 if eaten, Z=0 otherwise. Always
; returns Z=0 if life_active is 0. Mirrors src/x16/engine/life.asm:
; check_life return convention.
;
; ===========================================================================

check_life:
        lda     life_active
        beq     .no
        lda     body_x
        cmp     life_x
        bne     .no
        lda     body_y
        cmp     life_y
        rts
.no:
        lda     #1
        rts


; ===========================================================================
; Life pickup BSS (matches src/x16/engine/life.asm BSS layout)
; ===========================================================================

        .bss

life_active:      ds 1     ; 1 if life pickup is on field
life_x:           ds 1     ; life pickup grid column
life_y:           ds 1     ; life pickup grid row
food_since_life:  ds 1     ; food eaten since last life spawn
