; main.asm - Common entry point

.export main

.import platform_init
.import platform_exit
.import show_start_screen

.segment "CODE"

.proc main
    jsr platform_init
    jsr show_start_screen
    ; A = 1: start game, A = 0: quit
    cmp #0
    beq @quit
    ; TODO: game loop
    jmp platform_exit
@quit:
    jmp platform_exit
.endproc
