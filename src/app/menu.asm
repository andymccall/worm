; ---------------------------------------------------------------------------
; menu.asm - Start screen / main menu
; ---------------------------------------------------------------------------
; Draws the start screen with border, title, and menu options.
; Returns player's choice: 1=start, 2=about, 3=demo, 0=quit.
; 30-second idle timeout auto-starts demo mode.
; ---------------------------------------------------------------------------

.export show_start_screen

.import platform_cls
.import platform_putc
.import platform_gotoxy
.import platform_check_key
.import platform_wait_vsync
.import platform_set_color
.import draw_border
.import draw_status_bar
.import draw_worm_title
.import menu_worm_init
.import menu_worm_update
.import sfx_update
.import COLOR_GREEN, COLOR_BLUE, COLOR_YELLOW

; ---------------------------------------------------------------------------

; Menu key highlight colour
COLOR_MENU_KEY = COLOR_YELLOW

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; show_start_screen
;   Draws the start screen with line border, title, and menu.
;   Returns: A = 1 (start), A = 2 (about), A = 3 (demo), A = 0 (quit)
; ---------------------------------------------------------------------------

.proc show_start_screen
    jsr platform_cls

    ; Set green drawing/text color
    lda COLOR_GREEN
    jsr platform_set_color

    ; Draw line border
    jsr draw_border

    ; Draw status bar (Food count + Lives)
    jsr draw_status_bar

    ; --- Title "WORM" drawn with body segments at row 5 ---
    ldx #9
    ldy #5
    jsr draw_worm_title

    ; --- Menu options ---
@menu:
    lda COLOR_BLUE
    jsr platform_set_color

    ldx #16
    ldy #16
    jsr platform_gotoxy
    lda #<start_text
    sta menu_ptr
    lda #>start_text
    sta menu_ptr+1
    jsr print_menu_item

    ldx #16
    ldy #18
    jsr platform_gotoxy
    lda #<about_text
    sta menu_ptr
    lda #>about_text
    sta menu_ptr+1
    jsr print_menu_item

    ldx #16
    ldy #20
    jsr platform_gotoxy
    lda #<demo_text
    sta menu_ptr
    lda #>demo_text
    sta menu_ptr+1
    jsr print_menu_item

    ldx #16
    ldy #22
    jsr platform_gotoxy
    lda #<quit_text
    sta menu_ptr
    lda #>quit_text
    sta menu_ptr+1
    jsr print_menu_item

    ; --- Init menu worm ---
    jsr menu_worm_init

    ; --- Flush keyboard buffer ---
@flush:
    jsr platform_check_key
    cmp #0
    bne @flush

    ; --- Wait for S, A, D, Q or 30-second timeout ---
    ; Init timeout: 1800 frames = 30 seconds at 60 fps
    lda #<1800
    sta menu_timer
    lda #>1800
    sta menu_timer+1

@input:
    jsr platform_wait_vsync
    jsr sfx_update
    jsr menu_worm_update
    jsr platform_check_key
    cmp #0
    beq @dec_timer

    cmp #'S'
    beq @do_start
    cmp #'s'
    beq @do_start
    cmp #'A'
    beq @do_about
    cmp #'a'
    beq @do_about
    cmp #'D'
    beq @do_demo
    cmp #'d'
    beq @do_demo
    cmp #'Q'
    beq @do_quit
    cmp #'q'
    beq @do_quit

@dec_timer:
    ; Decrement 16-bit timeout counter
    lda menu_timer
    bne @dec_lo
    lda menu_timer+1
    beq @do_demo
    dec menu_timer+1
@dec_lo:
    dec menu_timer
    bra @input

@do_start:
    lda #1
    rts

@do_about:
    lda #2
    rts

@do_demo:
    lda #3
    rts

@do_quit:
    lda #0
    rts
.endproc

; ---------------------------------------------------------------------------
; print_menu_item
;   Prints a null-terminated string from menu_ptr.
;   '[' and ']' are printed in green.
;   Characters between '[' and ']' are printed in COLOR_MENU_KEY.
;   Other text is printed in the current (blue) colour.
; ---------------------------------------------------------------------------

.proc print_menu_item
    ldy #0
@loop:
    lda (menu_ptr), y
    beq @done
    cmp #'['
    beq @open_bracket
    cmp #']'
    beq @close_bracket
    phy
    jsr platform_putc
    ply
    iny
    bne @loop
    rts

@open_bracket:
    phy
    lda COLOR_GREEN
    jsr platform_set_color
    lda #'['
    jsr platform_putc
    lda COLOR_MENU_KEY
    jsr platform_set_color
    ply
    iny
    bne @loop
    rts

@close_bracket:
    phy
    lda COLOR_GREEN
    jsr platform_set_color
    lda #']'
    jsr platform_putc
    lda COLOR_BLUE
    jsr platform_set_color
    ply
    iny
    bne @loop

@done:
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "RODATA"

start_text:
    .byte "[S] START", $00

about_text:
    .byte "[A] ABOUT", $00

demo_text:
    .byte "[D] DEMO", $00

quit_text:
    .byte "[Q] QUIT", $00

; ---------------------------------------------------------------------------

.segment "BSS"

menu_timer: .res 2

; ---------------------------------------------------------------------------

.segment "ZEROPAGE"

menu_ptr: .res 2
