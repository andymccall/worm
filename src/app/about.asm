; ---------------------------------------------------------------------------
; about.asm - About screen
; ---------------------------------------------------------------------------
; Displays author info, contact details, and repo URL.
; Blocks until any key is pressed, then returns.
; ---------------------------------------------------------------------------

.export show_about_screen

.import platform_cls
.import platform_putc
.import platform_gotoxy
.import platform_getkey
.import platform_set_color
.import draw_border
.import draw_worm_title
.import COLOR_GREEN, COLOR_RED, COLOR_BLUE

; ---------------------------------------------------------------------------

; About screen text positions (character column, row)
ABOUT_AUTHOR_X   = 15
ABOUT_AUTHOR_Y   = 12
ABOUT_EMAIL_X    = 11
ABOUT_EMAIL_Y    = 14
ABOUT_REPO_X     = 7
ABOUT_REPO_Y     = 16
ABOUT_PROMPT_X   = 15
ABOUT_PROMPT_Y   = 23

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; show_about_screen
;   Displays the about screen. Press any key to return.
; ---------------------------------------------------------------------------

.proc show_about_screen
    jsr platform_cls

    lda COLOR_GREEN
    jsr platform_set_color

    jsr draw_border

    ; Title using worm body segments
    ldx #9
    ldy #4
    jsr draw_worm_title

@author:
    lda COLOR_GREEN
    jsr platform_set_color

    ldx #ABOUT_AUTHOR_X
    ldy #ABOUT_AUTHOR_Y
    jsr platform_gotoxy
    ldx #0
@a1:
    lda about_author, x
    beq @email
    jsr platform_putc
    inx
    bne @a1

@email:
    ldx #ABOUT_EMAIL_X
    ldy #ABOUT_EMAIL_Y
    jsr platform_gotoxy
    ldx #0
@e1:
    lda about_email, x
    beq @repo
    jsr platform_putc
    inx
    bne @e1

@repo:
    ldx #ABOUT_REPO_X
    ldy #ABOUT_REPO_Y
    jsr platform_gotoxy
    ldx #0
@r1:
    lda about_repo, x
    beq @prompt
    jsr platform_putc
    inx
    bne @r1

@prompt:
    lda COLOR_BLUE
    jsr platform_set_color

    ldx #ABOUT_PROMPT_X
    ldy #ABOUT_PROMPT_Y
    jsr platform_gotoxy
    ldx #0
@p1:
    lda about_prompt, x
    beq @wait
    jsr platform_putc
    inx
    bne @p1

@wait:
    jsr platform_getkey
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "RODATA"

about_author:
    .byte "ANDY MCCALL", $00

about_email:
    .byte "MAILME@ANDYMCCALL.CO.UK", $00

about_repo:
    .byte "HTTPS://GITHUB.COM/ANDYMCCALL/WORM", $00

about_prompt:
    .byte "PRESS ANY KEY", $00
