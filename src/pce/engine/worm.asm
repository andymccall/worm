; ***************************************************************************
;
; worm.asm - Worm body management
;
; Mirrors src/x16/engine/worm.asm. Owns the worm body array, advancement
; logic, direction validation, and wall/self collision tests. Drawing
; helpers (draw_segment, erase_cell) live in wm_drawing.asm; they're
; called from here for the per-segment paint passes.
;
; ***************************************************************************

        .code

; ===========================================================================
;
; draw_all_segments - Walk body_x/body_y for worm_len entries and draw
; each segment. Mirrors src/x16/engine/worm.asm:draw_all_segments.
;
; ===========================================================================

draw_all_segments:
        ldx     #0
.loop:
        cpx     worm_len
        bcs     .done
        phx
        lda     body_x, x
        sta     <cell_x
        lda     body_y, x
        sta     <cell_y
        jsr     draw_segment
        plx
        inx
        bra     .loop
.done:
        rts


; ===========================================================================
;
; erase_tail - Erase the cell at the tail (body_x[worm_len-1],
; body_y[worm_len-1]). Mirrors src/x16/engine/worm.asm:erase_tail.
;
; ===========================================================================

erase_tail:
        ldx     worm_len
        dex
        lda     body_x, x
        sta     <cell_x
        lda     body_y, x
        sta     <cell_y
        jmp     erase_cell


; ===========================================================================
;
; advance_body - Shift the body array down by one (tail toward head),
; insert a new head computed from worm_dir. Honours grow_flag (extends
; length up to MAX_LENGTH). Mirrors src/x16/engine/worm.asm:advance_body.
;
; ===========================================================================

advance_body:
        ; If growing, extend length first (cap at MAX_LENGTH).
        lda     grow_flag
        beq     .shift
        lda     worm_len
        cmp     #MAX_LENGTH
        bcs     .shift
        inc     worm_len

.shift:
        ; Shift segments back: body_x[i] = body_x[i-1] for i = len-1..1.
        ldx     worm_len
        dex
.shift_loop:
        cpx     #0
        beq     .shift_done
        lda     body_x - 1, x
        sta     body_x, x
        lda     body_y - 1, x
        sta     body_y, x
        dex
        bne     .shift_loop
.shift_done:

        ; New head = old head (now at index 1) + direction step.
        lda     body_x + 1
        sta     body_x
        lda     body_y + 1
        sta     body_y

        lda     worm_dir
        cmp     #DIR_UP
        bne     .not_up
        dec     body_y
        rts
.not_up:
        cmp     #DIR_DOWN
        bne     .not_down
        inc     body_y
        rts
.not_down:
        cmp     #DIR_LEFT
        bne     .not_left
        dec     body_x
        rts
.not_left:
        inc     body_x
        rts


; ===========================================================================
;
; check_direction - Validate and apply a direction change. Rejects
; 180-degree reversals (e.g. UP -> DOWN). A = candidate direction.
; Mirrors src/x16/engine/worm.asm:check_direction.
;
; ===========================================================================

check_direction:
        tax
        lda     worm_dir

        cpx     #DIR_UP
        bne     .not_up
        cmp     #DIR_DOWN
        beq     .reject
        bra     .accept
.not_up:
        cpx     #DIR_DOWN
        bne     .not_down
        cmp     #DIR_UP
        beq     .reject
        bra     .accept
.not_down:
        cpx     #DIR_LEFT
        bne     .not_left
        cmp     #DIR_RIGHT
        beq     .reject
        bra     .accept
.not_left:
        cpx     #DIR_RIGHT
        bne     .reject
        cmp     #DIR_LEFT
        beq     .reject
.accept:
        stx     worm_dir
.reject:
        rts


; ===========================================================================
;
; check_collision - Test whether the head has left the playing field.
; Returns C=1 if the head is outside the GRID_COLS x GRID_ROWS grid.
; Mirrors src/x16/engine/worm.asm:check_collision.
;
; ===========================================================================

check_collision:
        lda     body_x
        bmi     .hit
        cmp     #GRID_COLS
        bcs     .hit
        lda     body_y
        bmi     .hit
        cmp     #GRID_ROWS
        bcs     .hit
        clc
        rts
.hit:
        sec
        rts


; ===========================================================================
;
; check_self_collision - Test whether the head occupies the same cell
; as any body segment (index 1..worm_len-1). Returns C=1 if so.
; Mirrors src/x16/engine/worm.asm:check_self_collision.
;
; ===========================================================================

check_self_collision:
        ldx     #1
.loop:
        cpx     worm_len
        bcs     .no_hit
        lda     body_x
        cmp     body_x, x
        bne     .next
        lda     body_y
        cmp     body_y, x
        beq     .hit
.next:
        inx
        bra     .loop
.no_hit:
        clc
        rts
.hit:
        sec
        rts


; ===========================================================================
; Worm body BSS (matches src/x16/engine/worm.asm BSS layout)
; ===========================================================================

        .bss

worm_dir:         ds 1     ; current direction (DIR_*)
worm_len:         ds 1     ; current body length (1..MAX_LENGTH)
frame_count:      ds 1     ; frame counter for movement timing
grow_flag:        ds 1     ; 1 = grow on next move

body_x:           ds MAX_LENGTH  ; grid x for each segment (0 = head)
body_y:           ds MAX_LENGTH  ; grid y for each segment (0 = head)
