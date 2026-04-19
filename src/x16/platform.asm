; platform.asm - Commander X16 platform

.import main

.import gfx_x1, gfx_y1, gfx_x2, gfx_y2

.export platform_init
.export platform_exit
.export platform_cls
.export platform_getkey
.export platform_set_color
.export platform_draw_line
.export platform_draw_filled_rect
.export platform_poll_input
.export platform_wait_vsync
.export platform_gotoxy
.export platform_putc
.export platform_random
.export COLOR_GREEN
.export COLOR_RED

; Direction constants (must match across all files)
DIR_NONE  = 0
DIR_UP    = 1
DIR_DOWN  = 2
DIR_LEFT  = 3
DIR_RIGHT = 4

; PETSCII cursor key codes
KEY_UP    = $91
KEY_DOWN  = $11
KEY_LEFT  = $9D
KEY_RIGHT = $1D

; Action input codes (returned by platform_poll_input)
INPUT_PAUSE = 5
INPUT_QUIT  = 6

; ---------------------------------------------------------------------------
; KERNAL routines

CHROUT       = $FFD2
GETIN        = $FFE4
SCREEN_MODE  = $FF5F
MOUSE_CONFIG = $FF68
ENTROPY_GET  = $FECF

; Graphics KERNAL routines
GRAPH_init       = $FF20
GRAPH_clear      = $FF23
GRAPH_set_colors = $FF29
GRAPH_draw_line  = $FF2C
GRAPH_draw_rect  = $FF2F
GRAPH_put_char   = $FF41
enter_basic      = $FF47

; KERNAL pseudo-registers (zero page)
r0  = $02
r0L = r0
r0H = r0+1
r1  = $04
r1L = r1
r1H = r1+1
r2  = $06
r2L = r2
r2H = r2+1
r3  = $08
r3L = r3
r3H = r3+1

; Screen modes
SCREEN_MODE_80X60        = $00
SCREEN_MODE_320X240_256C = $80

; VERA interrupt status register
VERA_ISR = $9F27

; ---------------------------------------------------------------------------
; PRG load address

.segment "LOADADDR"
    .word $0801

; ---------------------------------------------------------------------------
; BASIC stub: 10 SYS2061

.segment "STARTUP"

basic_stub:
    .word basic_stub_end    ; pointer to next BASIC line
    .word 10                ; line number
    .byte $9E               ; SYS token
    .byte "2061"            ; entry address as decimal string
    .byte $00               ; end of BASIC line
basic_stub_end:
    .word $0000             ; end of BASIC program
    jmp main

; ---------------------------------------------------------------------------

.segment "CODE"

.proc platform_init
    ; Hide mouse
    lda #0
    jsr MOUSE_CONFIG

    ; Init graphics
    jsr GRAPH_init

    ; Set 320x240 bitmap mode
    lda #SCREEN_MODE_320X240_256C
    clc
    jsr SCREEN_MODE

    ; Set all colors to black
    lda #$00
    ldx #$00
    ldy #$00
    jsr GRAPH_set_colors

    ; Clear screen to black
    jsr GRAPH_clear
    rts
.endproc

.proc platform_cls
    lda #$00
    ldx #$00
    ldy #$00
    jsr GRAPH_set_colors
    jsr GRAPH_clear
    rts
.endproc

.proc platform_getkey
    ; Returns: A = key pressed (blocking)
@wait:
    jsr GETIN
    cmp #0
    beq @wait
    rts
.endproc

.proc platform_set_color
    ; A = color index (palette 0-15)
    ; Sets stroke and fill to same color; bg stays black
    tax                 ; fill = same as stroke
    ldy #$00            ; bg = black
    jsr GRAPH_set_colors
    rts
.endproc

.proc platform_draw_line
    ; Draw line from gfx_x1,gfx_y1 to gfx_x2,gfx_y2
    lda gfx_x1
    sta r0L
    lda gfx_x1+1
    sta r0H
    lda gfx_y1
    sta r1L
    lda gfx_y1+1
    sta r1H
    lda gfx_x2
    sta r2L
    lda gfx_x2+1
    sta r2H
    lda gfx_y2
    sta r3L
    lda gfx_y2+1
    sta r3H
    jsr GRAPH_draw_line
    rts
.endproc

.proc platform_draw_filled_rect
    ; Draw filled rect from gfx_x1,gfx_y1 to gfx_x2,gfx_y2
    ; GRAPH_draw_rect takes: r0=x, r1=y, r2=width, r3=height

    ; r0 = x1
    lda gfx_x1
    sta r0L
    lda gfx_x1+1
    sta r0H

    ; r1 = y1
    lda gfx_y1
    sta r1L
    lda gfx_y1+1
    sta r1H

    ; r2 = width = x2 - x1 + 1
    sec
    lda gfx_x2
    sbc gfx_x1
    sta r2L
    lda gfx_x2+1
    sbc gfx_x1+1
    sta r2H
    inc r2L
    bne :+
    inc r2H
:

    ; r3 = height = y2 - y1 + 1
    sec
    lda gfx_y2
    sbc gfx_y1
    sta r3L
    lda gfx_y2+1
    sbc gfx_y1+1
    sta r3H
    inc r3L
    bne :+
    inc r3H
:

    sec                     ; filled
    jsr GRAPH_draw_rect
    rts
.endproc

.proc platform_poll_input
    ; Non-blocking key read. Returns direction or action in A.
    jsr GETIN
    cmp #KEY_UP
    beq @up
    cmp #KEY_DOWN
    beq @down
    cmp #KEY_LEFT
    beq @left
    cmp #KEY_RIGHT
    beq @right
    cmp #'P'
    beq @pause
    cmp #'p'
    beq @pause
    cmp #'Q'
    beq @quit
    cmp #'q'
    beq @quit
    lda #DIR_NONE
    rts
@up:
    lda #DIR_UP
    rts
@down:
    lda #DIR_DOWN
    rts
@left:
    lda #DIR_LEFT
    rts
@right:
    lda #DIR_RIGHT
    rts
@pause:
    lda #INPUT_PAUSE
    rts
@quit:
    lda #INPUT_QUIT
    rts
.endproc

.proc platform_wait_vsync
    ; Wait for VERA VSYNC using ISR register polling
    sei                 ; block IRQs so KERNAL handler can't clear flag
    lda #$01
    sta VERA_ISR        ; clear VSYNC flag
@wait:
    bit VERA_ISR        ; test bit 0 (A still $01)
    beq @wait           ; loop until VSYNC flag is set
    cli                 ; re-enable IRQs (KERNAL handler runs)
    rts
.endproc

.proc platform_gotoxy
    ; X = column, Y = row (character cells)
    ; Convert to pixel position and store in r0/r1 for GRAPH_put_char

    ; r0 = col * 8 (16-bit)
    txa
    sta r0L
    lda #0
    sta r0H
    asl r0L
    rol r0H
    asl r0L
    rol r0H
    asl r0L
    rol r0H

    ; r1 = row * 8 (16-bit)
    tya
    sta r1L
    lda #0
    sta r1H
    asl r1L
    rol r1H
    asl r1L
    rol r1H
    asl r1L
    rol r1H
    rts
.endproc

.proc platform_putc
    ; A = character to print at current r0/r1 position
    ; r0 auto-advances after call
    ; Preserves X, Y
    phx
    phy
    jsr GRAPH_put_char
    ply
    plx
    rts
.endproc

.proc platform_exit
    ; Restore 80x60 text mode
    lda #SCREEN_MODE_80X60
    clc
    jsr SCREEN_MODE

    ; Clear screen
    lda #$93
    jsr CHROUT

    ; Return to BASIC
    clc
    jsr enter_basic
    rts
.endproc

.proc platform_random
    ; Returns a random byte in A (0-255)
    jsr ENTROPY_GET
    ; A already has a random byte
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "RODATA"

; X16 palette index for green
COLOR_GREEN: .byte $05

; X16 palette index for red
COLOR_RED: .byte $02
