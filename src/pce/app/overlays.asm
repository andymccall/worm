; ***************************************************************************
;
; overlays.asm - In-game overlay screens
;
; Mirrors src/x16/app/overlays.asm. Currently holds GET READY and GAME
; OVER. Pause and quit-confirm exist on X16/Neo but we don't need quit
; on PCE (no software exit) and pause hasn't been ported yet.
;
; ***************************************************************************

        .code

; ===========================================================================
;
; show_get_ready - Paint "GET READY!" centred in the playfield, hold for
; ~3 seconds, return. Mirrors src/x16/app/overlays.asm:show_get_ready
; (without the sfx call, since sound isn't ported yet).
;
; ===========================================================================

show_get_ready:
        lda     #(PAL_GREEN << 4)
        sta     <bat_palette_hi

        ; "GET READY!" is 10 chars, centred at col (32-10)/2 = 11.
        lda     #<(OVERLAY_ROW * BAT_LINE + 11)
        sta     <_di + 0
        lda     #>(OVERLAY_ROW * BAT_LINE + 11)
        sta     <_di + 1
        call    vdc_di_to_mawr
        lda     #<get_ready_text
        sta     <_bp + 0
        lda     #>get_ready_text
        sta     <_bp + 1
        call    paint_string

        ; Hold for DELAY_GET_READY frames.
        lda     #DELAY_GET_READY
        sta     delay_count
.delay:
        call    wait_vsync
        dec     delay_count
        bne     .delay
        rts


; ===========================================================================
;
; show_game_over - Paint "GAME OVER!" centred. Caller is responsible for
; the post-message delay (matches src/x16/app/overlays.asm:show_game_over).
;
; ===========================================================================

show_game_over:
        lda     #(PAL_GREEN << 4)
        sta     <bat_palette_hi

        ; "GAME OVER!" is 10 chars, centred at col 11.
        lda     #<(OVERLAY_ROW * BAT_LINE + 11)
        sta     <_di + 0
        lda     #>(OVERLAY_ROW * BAT_LINE + 11)
        sta     <_di + 1
        call    vdc_di_to_mawr
        lda     #<game_over_text
        sta     <_bp + 0
        lda     #>game_over_text
        sta     <_bp + 1
        call    paint_string
        rts


; ===========================================================================
; Overlay strings + delay BSS
; ===========================================================================

        .data

; Same names + content as src/x16/app/overlays.asm.
get_ready_text:         db      "GET READY!", 0
game_over_text:         db      "GAME OVER!", 0


        .bss

; General-purpose 1-byte delay counter used by overlays + death pauses.
; Mirrors src/x16/app/overlays.asm and src/x16/engine/game.asm naming.
delay_count:      ds 1
