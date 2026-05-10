;----------------------------------------------------------------------------
;
; about.asm - About screen
;
; Mirrors src/x16/app/about.asm. Shows author, email, repo URL, then
; blocks until a key is pressed. The text content is identical to the
; X16/Neo/PCE versions; only the rendering layer is platform-specific.
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; About screen text positions.
;
; The X16 specifies these as character cells; we don't reuse those values
; verbatim because the longest string (the GitHub URL, 34 chars * 8 =
; 272 px) overflows our 320-pixel canvas if it starts at the X16's
; cell-7 position. Instead we centre each string horizontally on the
; 320-wide canvas: x = (320 - chars*8) / 2.
;
; Vertical positions follow the X16 row convention (row * 8) so the
; relative spacing is unchanged.
;----------------------------------------------------------------------------

ABOUT_AUTHOR_X          equ     (320 - 11 * 8) / 2      ; "ANDY MCCALL" = 116
ABOUT_AUTHOR_Y          equ     12 * 8                  ; = 96
ABOUT_EMAIL_X           equ     (320 - 23 * 8) / 2      ; 23-char email = 68
ABOUT_EMAIL_Y           equ     14 * 8                  ; = 112
ABOUT_REPO_X            equ     (320 - 34 * 8) / 2      ; 34-char URL = 24
ABOUT_REPO_Y            equ     16 * 8                  ; = 128
ABOUT_PROMPT_X          equ     (320 - 13 * 8) / 2      ; "PRESS ANY KEY" = 108
ABOUT_PROMPT_Y          equ     23 * 8                  ; = 184

;----------------------------------------------------------------------------
; show_about_screen
;
; Paint the about screen, block until any key is pressed, return.
;
; Clobbers: A, BC, DE, HL, IX.
;----------------------------------------------------------------------------

show_about_screen:
        ld      a, COL_BLACK
        call    platform_cls
        call    draw_border

        ; WORM title at cell (9, 4) - same as X16 about screen.
        ld      b, 9
        ld      c, 4
        call    draw_worm_title

        ; Author, email, repo: green.
        ld      ix, about_author
        ld      hl, ABOUT_AUTHOR_X
        ld      e, ABOUT_AUTHOR_Y
        ld      d, COL_GREEN
        call    paint_string

        ld      ix, about_email
        ld      hl, ABOUT_EMAIL_X
        ld      e, ABOUT_EMAIL_Y
        ld      d, COL_GREEN
        call    paint_string

        ld      ix, about_repo
        ld      hl, ABOUT_REPO_X
        ld      e, ABOUT_REPO_Y
        ld      d, COL_GREEN
        call    paint_string

        ; "PRESS ANY KEY" prompt: blue.
        ld      ix, about_prompt
        ld      hl, ABOUT_PROMPT_X
        ld      e, ABOUT_PROMPT_Y
        ld      d, COL_BLUE
        call    paint_string

        ; Block until any key is pressed.
        call    platform_getkey
        ret

;----------------------------------------------------------------------------
; About screen strings. Verbatim from src/x16/app/about.asm.
;----------------------------------------------------------------------------

about_author:   defb    "ANDY MCCALL", 0
about_email:    defb    "MAILME@ANDYMCCALL.CO.UK", 0
about_repo:     defb    "HTTPS://GITHUB.COM/ANDYMCCALL/WORM", 0
about_prompt:   defb    "PRESS ANY KEY", 0
