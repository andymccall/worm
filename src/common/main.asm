; main.asm - Common entry point

.export main

.import platform_init
.import platform_exit
.import show_start_screen
.import game_run

.segment "CODE"

.proc main
    jsr platform_init

@loop:
    jsr show_start_screen
    ; A = 1: start game, A = 0: quit
    cmp #0
    beq @quit

    jsr game_run

    ; After game over, return to start screen
    jmp @loop

@quit:
    jmp platform_exit
.endproc
