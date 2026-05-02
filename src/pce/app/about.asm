; ***************************************************************************
;
; about.asm - About / credits screen
;
; Mirrors src/x16/app/about.asm:show_about_screen. Author + email + repo
; URL in green, "PRESS ANY BUTTON" prompt in blue. Wait for any button
; press, then return.
;
; The PC Engine BAT is 32 columns wide; the X16/Neo build's HTTPS URL is
; 34 chars and won't fit, so we drop the "HTTPS://" prefix here.
;
; ***************************************************************************

        .code

show_about_screen:
        ; Wipe the playfield, then repaint the WORM title (lives in rows
        ; 4..8 which clear_playfield wipes).
        call    clear_playfield
        call    paint_worm_title

        ; --- Author / email / repo in green --------------------------------
        lda     #(PAL_GREEN << 4)
        sta     <bat_palette_hi

        ; ANDY MCCALL is 11 chars, centred at col (32-11)/2 = 10.
        lda     #<(ABOUT_AUTHOR_ROW * BAT_LINE + 10)
        sta     <_di + 0
        lda     #>(ABOUT_AUTHOR_ROW * BAT_LINE + 10)
        sta     <_di + 1
        call    vdc_di_to_mawr
        lda     #<about_author
        sta     <_bp + 0
        lda     #>about_author
        sta     <_bp + 1
        call    paint_string

        ; MAILME@ANDYMCCALL.CO.UK is 23 chars, centred at col (32-23)/2 = 4.
        lda     #<(ABOUT_EMAIL_ROW * BAT_LINE + 4)
        sta     <_di + 0
        lda     #>(ABOUT_EMAIL_ROW * BAT_LINE + 4)
        sta     <_di + 1
        call    vdc_di_to_mawr
        lda     #<about_email
        sta     <_bp + 0
        lda     #>about_email
        sta     <_bp + 1
        call    paint_string

        ; GITHUB.COM/ANDYMCCALL/WORM is 26 chars, centred at col (32-26)/2 = 3.
        lda     #<(ABOUT_REPO_ROW * BAT_LINE + 3)
        sta     <_di + 0
        lda     #>(ABOUT_REPO_ROW * BAT_LINE + 3)
        sta     <_di + 1
        call    vdc_di_to_mawr
        lda     #<about_repo
        sta     <_bp + 0
        lda     #>about_repo
        sta     <_bp + 1
        call    paint_string

        ; --- Prompt in blue ------------------------------------------------
        lda     #(PAL_BLUE << 4)
        sta     <bat_palette_hi

        ; PRESS ANY BUTTON is 16 chars, centred at col (32-16)/2 = 8.
        lda     #<(ABOUT_PROMPT_ROW * BAT_LINE + 8)
        sta     <_di + 0
        lda     #>(ABOUT_PROMPT_ROW * BAT_LINE + 8)
        sta     <_di + 1
        call    vdc_di_to_mawr
        lda     #<about_prompt
        sta     <_bp + 0
        lda     #>about_prompt
        sta     <_bp + 1
        call    paint_string

        ; --- Wait for any button press -------------------------------------
.wait:
        call    wait_vsync
        lda     joytrg
        and     #(JOY_B1 | JOY_B2 | JOY_RUN | JOY_SEL)
        beq     .wait

        ; Wipe the about content + repaint the WORM title before returning,
        ; so the menu painter only has to lay down the menu items + cursor.
        call    clear_playfield
        call    paint_worm_title
        rts


; ===========================================================================
; About screen strings (matches src/x16/app/about.asm content)
; ===========================================================================

        .data

; HTTPS:// prefix is dropped on PCE because the BAT is only 32 cols wide
; and the full URL would overflow.
about_author:           db      "ANDY MCCALL", 0
about_email:            db      "MAILME@ANDYMCCALL.CO.UK", 0
about_repo:             db      "GITHUB.COM/ANDYMCCALL/WORM", 0
about_prompt:           db      "PRESS ANY BUTTON", 0
