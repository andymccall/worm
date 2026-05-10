;----------------------------------------------------------------------------
;
; menu.asm - Start screen / main menu
;
; Mirrors src/x16/app/menu.asm. Draws the start screen (border + status
; + WORM title + four menu options) and polls the keyboard until S, A,
; D, or Q is pressed. Returns the user's selection in A:
;
;   1 = START
;   2 = ABOUT
;   3 = DEMO
;   0 = QUIT
;
; Scope (A) milestone: no animated menu worm, no sound, no idle timeout
; to demo. The full version (mirroring X16) will pull those in next.
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; Menu layout (pixel coordinates, GAME space)
;
; The X16 places menu items at character cells (16, 16..22) - 16 pixels
; from the left, 16 pixels apart vertically. We use the same pixel
; positions so the layout reads the same.
;----------------------------------------------------------------------------

MENU_X                  equ     128
MENU_Y_START            equ     128
MENU_Y_ABOUT            equ     144
MENU_Y_DEMO             equ     160
MENU_Y_QUIT             equ     176

COLOR_MENU_KEY          equ     COL_YELLOW

;----------------------------------------------------------------------------
; show_start_screen
;
; Paint the menu screen, poll input, return the user's choice.
;
; Returns: A = 0..3 (see file header).
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

show_start_screen:
        ; Repaint chrome.
        ld      a, COL_BLACK
        call    platform_cls
        call    draw_border
        call    draw_status_bar

        ld      b, 9
        ld      c, 5
        call    draw_worm_title

        ; Menu items.
        ld      ix, start_text
        ld      hl, MENU_X
        ld      e, MENU_Y_START
        call    print_menu_item

        ld      ix, about_text
        ld      hl, MENU_X
        ld      e, MENU_Y_ABOUT
        call    print_menu_item

        ld      ix, demo_text
        ld      hl, MENU_X
        ld      e, MENU_Y_DEMO
        call    print_menu_item

        ld      ix, quit_text
        ld      hl, MENU_X
        ld      e, MENU_Y_QUIT
        call    print_menu_item

        ; Initialise the decorative menu worm.
        call    menu_worm_init

        ; Drain any key still held from a previous screen.
.flush:
        call    platform_check_key
        or      a
        jr      nz, .flush

        ; Idle timeout: 30 seconds at 50Hz = 1500 frames. When it
        ; underflows the menu auto-launches demo mode (mirrors X16's
        ; 1800-frame / 60Hz timeout).
        ld      hl, 1500
        ld      (menu_timer), hl

.input:
        call    platform_wait_vsync
        call    menu_worm_update
        call    platform_check_key

        cp      'S'
        jr      z, .do_start
        cp      'A'
        jr      z, .do_about
        cp      'D'
        jr      z, .do_demo
        cp      'Q'
        jr      z, .do_quit

        ; No menu key: tick the idle timer.
        ld      hl, (menu_timer)
        ld      a, h
        or      l
        jr      z, .do_demo             ; reached zero -> auto demo
        dec     hl
        ld      (menu_timer), hl
        jr      .input

.do_start:
        ld      a, 1
        ret
.do_about:
        ld      a, 2
        ret
.do_demo:
        ld      a, 3
        ret
.do_quit:
        xor     a
        ret

;----------------------------------------------------------------------------
; print_menu_item
;
; Paint a menu line with mixed colours: '[' and ']' in green, the
; character(s) between them (the hotkey) in yellow, and the rest in blue.
;
; Entry: IX = string ptr (null-terminated),
;        HL = x (game space),
;        E = y (glyph-top, game space).
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

print_menu_item:
        ld      (pmi_x), hl
        ld      a, e
        ld      (pmi_y), a

        ld      a, COL_BLUE
        ld      (pmi_colour), a

.next:
        ld      a, (ix+0)
        or      a
        ret     z

        cp      '['
        jr      z, .open_bracket
        cp      ']'
        jr      z, .close_bracket

        ; Plain char in current colour.
        call    pmi_emit
        jr      .advance

.open_bracket:
        ; '[' in green; switch following chars to yellow.
        push    af
        ld      a, COL_GREEN
        ld      (pmi_colour), a
        ld      a, '['
        call    pmi_emit
        ld      a, COLOR_MENU_KEY
        ld      (pmi_colour), a
        pop     af
        jr      .advance

.close_bracket:
        ; ']' in green; switch following chars to blue.
        push    af
        ld      a, COL_GREEN
        ld      (pmi_colour), a
        ld      a, ']'
        call    pmi_emit
        ld      a, COL_BLUE
        ld      (pmi_colour), a
        pop     af
        jr      .advance

.advance:
        inc     ix
        jr      .next

;
; pmi_emit - render the ASCII char in A at the current pmi_x/pmi_y in
; pmi_colour, then advance pmi_x by 8.
;
pmi_emit:
        push    ix
        push    af
        ld      hl, (pmi_x)
        ld      a, (pmi_y)
        ld      e, a
        ld      a, (pmi_colour)
        ld      d, a
        pop     af
        call    platform_putc
        pop     ix

        ld      hl, (pmi_x)
        ld      bc, 8
        add     hl, bc
        ld      (pmi_x), hl
        ret

;----------------------------------------------------------------------------
; Strings + state.
;----------------------------------------------------------------------------

start_text:     defb    "[S] START", 0
about_text:     defb    "[A] ABOUT", 0
demo_text:      defb    "[D] DEMO", 0
quit_text:      defb    "[Q] QUIT", 0

pmi_x:          defw    0
pmi_y:          defb    0
pmi_colour:     defb    0

menu_timer:     defw    0
