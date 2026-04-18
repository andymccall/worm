; main.asm - Common entry point

.export main

.import platform_init
.import platform_putc
.import platform_exit

.segment "CODE"

.proc main
    jsr platform_init
    ldx #0
@loop:
    lda message, x
    beq @done
    jsr platform_putc
    inx
    bne @loop
@done:
    jmp platform_exit
.endproc

.segment "RODATA"

message:
    .byte "HELLO, WORLD!", $0D, $00
