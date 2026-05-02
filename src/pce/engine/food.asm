; ***************************************************************************
;
; food.asm - Food spawning, collision, and rendering
;
; Mirrors src/x16/engine/food.asm. Manages food placement, head-vs-food
; collision, and drawing the clover-leaf food shape (which on PCE is a
; pre-rendered tile rather than four overlapping rects).
;
; Also hosts platform_random (the LFSR RNG used for spawn placement) -
; on the X16/Neo this lives behind the platform layer (ENTROPY_GET on
; X16, an API call on Neo); on PCE it's a CPU-side LFSR.
;
; ***************************************************************************

        .code

; ===========================================================================
;
; platform_random - Galois 8-bit LFSR. Returns a pseudo-random byte in A.
; Polynomial $1D gives a period-255 sequence. Mirrors the X16/Neo
; platform_random in interface (same name, returns one byte in A).
;
; ===========================================================================

platform_random:
        lda     rng_seed
        asl     a
        bcc     .no_xor
        eor     #$1D
.no_xor:
        sta     rng_seed
        rts


; ===========================================================================
;
; spawn_food - Pick a random grid cell for food that doesn't overlap the
; worm body. Mirrors src/x16/engine/food.asm:spawn_food. The X16/Neo
; version also avoids overlapping life and spider, but those don't exist
; on PCE yet.
;
; ===========================================================================

spawn_food:
.retry:
        jsr     platform_random
.mod_x:
        cmp     #GRID_COLS
        bcc     .x_ok
        sbc     #GRID_COLS
        bra     .mod_x
.x_ok:
        sta     food_x

        jsr     platform_random
.mod_y:
        cmp     #GRID_ROWS
        bcc     .y_ok
        sbc     #GRID_ROWS
        bra     .mod_y
.y_ok:
        sta     food_y

        ; Reject if food overlaps any worm body segment.
        ldx     #0
.check:
        cpx     worm_len
        bcs     .done
        lda     food_x
        cmp     body_x, x
        bne     .next
        lda     food_y
        cmp     body_y, x
        beq     .retry
.next:
        inx
        bra     .check
.done:
        rts


; ===========================================================================
;
; check_food - Test whether the worm's head shares a cell with the food.
; Returns Z=1 if eaten, Z=0 if not. Mirrors src/x16/engine/food.asm:
; check_food return convention.
;
; ===========================================================================

check_food:
        lda     body_x
        cmp     food_x
        bne     .no
        lda     body_y
        cmp     food_y
        rts
.no:
        lda     #1
        rts


; ===========================================================================
;
; draw_food - Paint the food tile at (food_x, food_y) in yellow.
; Mirrors src/x16/engine/food.asm:draw_food.
;
; ===========================================================================

draw_food:
        lda     food_x
        sta     <cell_x
        lda     food_y
        sta     <cell_y
        jsr     bat_addr_for_cell

        lda     #<CHR_FOOD
        sta     VDC_DL
        lda     #>CHR_FOOD
        ora     #(PAL_YELLOW << 4)
        sta     VDC_DH
        rts


; ===========================================================================
; Food + RNG BSS (matches src/x16/engine/food.asm BSS layout)
; ===========================================================================

        .bss

food_x:           ds 1     ; food grid column
food_y:           ds 1     ; food grid row

; RNG state. PCE has no built-in entropy source so we run our own LFSR
; (Galois 8-bit, polynomial $1D, period 255). Seeded at game start.
rng_seed:         ds 1
