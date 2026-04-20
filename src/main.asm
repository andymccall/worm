; ---------------------------------------------------------------------------
; main.asm - Application entry point
; ---------------------------------------------------------------------------
; Top-level game flow: init, menu loop, dispatch to game/demo/about.
; ---------------------------------------------------------------------------

.export main

.import platform_init
.import platform_exit
.import sfx_stop
.import sfx_play_menu_jingle
.import show_start_screen
.import show_about_screen
.import game_run
.import game_reset_stats
.import demo_run

.segment "CODE"

.proc main
    jsr platform_init
    jsr game_reset_stats
    jsr sfx_play_menu_jingle

@loop:
    jsr game_reset_stats
    jsr show_start_screen
    ; A = 0: quit, 1: start, 2: about, 3: demo
    cmp #0
    beq @quit
    cmp #2
    beq @about
    cmp #3
    beq @demo

    ; Start game
    jsr game_run
    jsr sfx_stop
    jmp @loop

@about:
    jsr show_about_screen
    jmp @loop

@demo:
    jsr demo_run
    jsr sfx_stop
    jmp @loop

@quit:
    jmp platform_exit
.endproc
