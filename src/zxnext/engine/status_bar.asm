;----------------------------------------------------------------------------
;
; status_bar.asm - Status bar drawing
;
; Mirrors src/x16/engine/status_bar.asm and (eventually) the equivalent
; PCE module. Owns:
;   draw_status_bar - "FOOD nnn"  "LIVES" + N hearts
;   draw_heart      - one 7x6 heart pixel pattern at (HL, E) in colour A
;
; State variables food_count and lives live here too. The full game will
; mutate them from engine/game.asm; for the current bring-up they default
; to 0 and MAX_LIVES.
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; draw_status_bar
;
; Repaint the entire status strip: black-fill, "FOOD ", count, "LIVES ",
; and N hearts. Mirrors X16 draw_status_bar verbatim layout-wise.
;
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

draw_status_bar:
        ; Clear the status strip to black: rect from (BORDER_X1+1, BORDER_Y1+1)
        ; to one row above the divider, full inner width and height.
        ld      hl, BORDER_X1 + 1
        ld      e, BORDER_Y1 + 1
        ld      bc, BORDER_X2 - BORDER_X1 - 1   ; inner width
        ld      d, DIVIDER_Y - BORDER_Y1 - 1    ; inner height
        ld      a, COL_BLACK
        call    platform_draw_filled_rect

        ; "FOOD " label.
        ld      ix, food_label
        ld      hl, STATUS_FOOD_X
        ld      e, STATUS_FOOD_Y
        ld      d, COL_GREEN
        call    paint_string

        ; Food count, three-char right-justified, immediately after label.
        ld      a, (food_count)
        ld      hl, STATUS_FOOD_X + 5 * 8       ; "FOOD " is 5 chars
        ld      e, STATUS_FOOD_Y
        ld      d, COL_GREEN
        call    print_byte_decimal

        ; "LIVES " label.
        ld      ix, lives_label
        ld      hl, STATUS_LIVES_X
        ld      e, STATUS_LIVES_Y
        ld      d, COL_GREEN
        call    paint_string

        ; Hearts: draw min(lives, STATUS_HEART_MAX) red hearts.
        ld      a, (lives)
        cp      STATUS_HEART_MAX + 1
        jr      c, .heart_count_ok
        ld      a, STATUS_HEART_MAX
.heart_count_ok:
        or      a
        ret     z                       ; no lives -> no hearts

        ld      b, a                    ; heart count
        ld      hl, STATUS_HEART_X_START
.heart_loop:
        push    bc
        push    hl
        ; Draw one heart at (HL, STATUS_HEART_Y) in red.
        ld      e, STATUS_HEART_Y
        ld      a, COL_RED
        call    draw_heart
        pop     hl
        ld      bc, STATUS_HEART_SPACING
        add     hl, bc
        pop     bc
        djnz    .heart_loop
        ret

;----------------------------------------------------------------------------
; draw_heart
;
; Paint a 7x6 heart at GAME-space (HL, E) in colour A. The shape matches
; the X16 / Neo / PCE hearts:
;
;   .##.##.   row 0  - two bumps
;   #######   row 1  - body wide
;   #######   row 2  - body wide
;   .#####.   row 3  - taper 1
;   ..###..   row 4  - taper 2
;   ...#...   row 5  - point
;
; Implemented as a series of horizontal runs; each row is one
; platform_draw_hline call (or two for row 0 which has a gap).
;
; Entry: HL = x, E = y, A = colour.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

draw_heart:
        ld      (heart_x), hl
        ld      (heart_colour), a
        ld      a, e
        ld      (heart_y), a

        ; Row 0: hline (x+1, y) len 2, then hline (x+4, y) len 2
        ld      a, (heart_colour)
        ld      hl, (heart_x)
        ld      bc, 1
        add     hl, bc
        ld      a, (heart_y)
        ld      e, a
        ld      bc, 2
        ld      a, (heart_colour)
        call    platform_draw_hline

        ld      hl, (heart_x)
        ld      bc, 4
        add     hl, bc
        ld      a, (heart_y)
        ld      e, a
        ld      bc, 2
        ld      a, (heart_colour)
        call    platform_draw_hline

        ; Row 1: hline (x, y+1) len 7
        ld      hl, (heart_x)
        ld      a, (heart_y)
        inc     a
        ld      e, a
        ld      bc, 7
        ld      a, (heart_colour)
        call    platform_draw_hline

        ; Row 2: hline (x, y+2) len 7
        ld      hl, (heart_x)
        ld      a, (heart_y)
        add     a, 2
        ld      e, a
        ld      bc, 7
        ld      a, (heart_colour)
        call    platform_draw_hline

        ; Row 3: hline (x+1, y+3) len 5
        ld      hl, (heart_x)
        ld      bc, 1
        add     hl, bc
        ld      a, (heart_y)
        add     a, 3
        ld      e, a
        ld      bc, 5
        ld      a, (heart_colour)
        call    platform_draw_hline

        ; Row 4: hline (x+2, y+4) len 3
        ld      hl, (heart_x)
        ld      bc, 2
        add     hl, bc
        ld      a, (heart_y)
        add     a, 4
        ld      e, a
        ld      bc, 3
        ld      a, (heart_colour)
        call    platform_draw_hline

        ; Row 5: hline (x+3, y+5) len 1
        ld      hl, (heart_x)
        ld      bc, 3
        add     hl, bc
        ld      a, (heart_y)
        add     a, 5
        ld      e, a
        ld      bc, 1
        ld      a, (heart_colour)
        call    platform_draw_hline
        ret

heart_x:        defw    0
heart_y:        defb    0
heart_colour:   defb    0

;----------------------------------------------------------------------------
; State variables and string literals.
;----------------------------------------------------------------------------

food_count:     defb    0
lives:          defb    MAX_LIVES

food_label:     defb    "FOOD ", 0
lives_label:    defb    "LIVES ", 0
