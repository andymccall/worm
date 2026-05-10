;----------------------------------------------------------------------------
;
; overlays.asm - In-game overlay screens
;
; Mirrors src/x16/app/overlays.asm:
;   show_get_ready    - "GET READY!" text + ~3s delay
;   show_game_over    - "GAME OVER!" text (caller handles delay)
;   show_pause_screen - full-frame redraw + "GAME PAUSED", waits for any key
;   show_quit_confirm - full-frame redraw + Y/N prompt, returns 0/1
;
; Frame counts assume the Next runs at 50Hz (PAL): 150 frames = 3s,
; 50 frames = 1s. The X16 numbers (180/60) are 60Hz; our equivalents
; are scaled for matching wall-clock time.
;
;----------------------------------------------------------------------------

GET_READY_FRAMES        equ     150     ; ~3s at 50Hz (X16 uses 180 at 60Hz)
GAME_OVER_FRAMES        equ     150
DEATH_DELAY_FRAMES      equ     50      ; ~1s at 50Hz (X16 uses 60 at 60Hz)

;----------------------------------------------------------------------------
; show_get_ready
;
; Paint "GET READY!" centred at row 14 in green, then spin for ~3s.
;
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

show_get_ready:
        ld      ix, get_ready_text
        ld      hl, (320 - 10 * 8) / 2  ; "GET READY!" = 10 chars
        ld      e, 14 * 8               ; row 14 (matches X16)
        ld      d, COL_GREEN
        call    paint_string

        ld      hl, GET_READY_FRAMES
        ld      (delay_counter), hl
.delay:
        call    platform_wait_vsync
        ld      hl, (delay_counter)
        dec     hl
        ld      (delay_counter), hl
        ld      a, h
        or      l
        jr      nz, .delay
        ret

;----------------------------------------------------------------------------
; show_game_over
;
; Paint "GAME OVER!" centred at row 14 in green. Caller is responsible
; for any post-display delay before returning to the menu.
;
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

show_game_over:
        ld      ix, game_over_text
        ld      hl, (320 - 10 * 8) / 2  ; "GAME OVER!" = 10 chars
        ld      e, 14 * 8
        ld      d, COL_GREEN
        call    paint_string
        ret

;----------------------------------------------------------------------------
; show_pause_screen
;
; Repaint the chrome (cls + border + status bar) so the playfield is
; cleared, paint "GAME PAUSED" centred at row 14, then block on any key.
; The caller redraws the in-game state afterward via redraw_game.
;
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

show_pause_screen:
        call    draw_full_frame

        ld      ix, paused_text
        ld      hl, (320 - 11 * 8) / 2  ; "GAME PAUSED" = 11 chars
        ld      e, 14 * 8
        ld      d, COL_GREEN
        call    paint_string

        call    platform_getkey
        ret

;----------------------------------------------------------------------------
; show_quit_confirm
;
; Repaint chrome, ask for confirmation. Block on Y or N.
;
; Returns: A = 1 if Y (quit), A = 0 if N (resume).
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

show_quit_confirm:
        call    draw_full_frame

        ld      ix, quit_line1_text
        ld      hl, (320 - 16 * 8) / 2  ; "ARE YOU SURE YOU" = 16 chars
        ld      e, 12 * 8
        ld      d, COL_GREEN
        call    paint_string

        ld      ix, quit_line2_text
        ld      hl, (320 - 13 * 8) / 2  ; "WANT TO QUIT?" = 13 chars
        ld      e, 14 * 8
        ld      d, COL_GREEN
        call    paint_string

        ; "[Y] / [N]" with mixed colours (brackets green, letters yellow,
        ; slash green). 9 chars wide, centred.
        ld      ix, quit_yn_text
        ld      hl, (320 - 9 * 8) / 2
        ld      e, 18 * 8
        call    paint_yn_prompt

.input:
        call    platform_getkey
        cp      'Y'
        jr      z, .yes
        cp      'N'
        jr      z, .no
        jr      .input
.yes:
        ld      a, 1
        ret
.no:
        xor     a
        ret

;----------------------------------------------------------------------------
; paint_yn_prompt
;
; Walk the "[Y] / [N]" string painting brackets in green, letters in
; yellow, the slash and spaces in green. Mirrors print_menu_item but
; the "key" colour stays yellow inside any [...] pair.
;
; Entry: IX = string ptr (null-terminated), HL = x, E = y.
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

paint_yn_prompt:
        ld      (yn_x), hl
        ld      a, e
        ld      (yn_y), a
        ld      a, COL_GREEN
        ld      (yn_colour), a

.next:
        ld      a, (ix+0)
        or      a
        ret     z

        cp      '['
        jr      z, .open
        cp      ']'
        jr      z, .close

        ; Emit current char in current colour.
        call    yn_emit
        jr      .advance

.open:
        push    af
        ld      a, COL_GREEN
        ld      (yn_colour), a
        ld      a, '['
        call    yn_emit
        ld      a, COL_YELLOW
        ld      (yn_colour), a
        pop     af
        jr      .advance

.close:
        push    af
        ld      a, COL_GREEN
        ld      (yn_colour), a
        ld      a, ']'
        call    yn_emit
        ; After ']' the rest is in green (matches X16: " / [N]" reads
        ; with green slash, yellow N, green ']').
        pop     af
        jr      .advance

.advance:
        inc     ix
        jr      .next

yn_emit:
        push    ix
        push    af
        ld      hl, (yn_x)
        ld      a, (yn_y)
        ld      e, a
        ld      a, (yn_colour)
        ld      d, a
        pop     af
        call    platform_putc
        pop     ix

        ld      hl, (yn_x)
        ld      bc, 8
        add     hl, bc
        ld      (yn_x), hl
        ret

;----------------------------------------------------------------------------
; Strings + state.
;----------------------------------------------------------------------------

get_ready_text:         defb    "GET READY!", 0
game_over_text:         defb    "GAME OVER!", 0
paused_text:            defb    "GAME PAUSED", 0
quit_line1_text:        defb    "ARE YOU SURE YOU", 0
quit_line2_text:        defb    "WANT TO QUIT?", 0
quit_yn_text:           defb    "[Y] / [N]", 0

delay_counter:          defw    0

yn_x:                   defw    0
yn_y:                   defb    0
yn_colour:              defb    0
