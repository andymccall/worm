; Worm - (c) 2026 Andy McCall
; Licensed under CC BY-NC 4.0
; https://creativecommons.org/licenses/by-nc/4.0/

; ---------------------------------------------------------------------------
; platform.asm - Commander X16 platform
; ---------------------------------------------------------------------------
; Hardware abstraction for Commander X16: graphics, input, sound via
; VERA PSG, KERNAL routines.
; ---------------------------------------------------------------------------

.import main

.import gfx_x1, gfx_y1, gfx_x2, gfx_y2

.include "system/wm_equates.inc"

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
.export platform_gotoxy_pixel
.export platform_putc
.export platform_random
.export platform_check_key
.export platform_play_note
.export platform_stop_sound
.export COLOR_GREEN
.export COLOR_RED
.export COLOR_YELLOW
.export COLOR_LGRAY
.export COLOR_BLUE

; PETSCII cursor key codes
KEY_UP    = $91
KEY_DOWN  = $11
KEY_LEFT  = $9D
KEY_RIGHT = $1D

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

; VERA I/O registers for PSG access
VERA_ADDR_L  = $9F20
VERA_ADDR_M  = $9F21
VERA_ADDR_H  = $9F22
VERA_DATA0   = $9F23

; VERA PSG voice 0 base address in VRAM: $1F9C0
; VERA_ADDR_H = $11 (bank 1 + auto-increment 1)
PSG_VOICE0_ADDR_L = $C0
PSG_VOICE0_ADDR_M = $F9
PSG_VOICE0_ADDR_H = $11      ; bank 1, auto-increment +1

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

.proc platform_check_key
    ; Non-blocking key read. Returns: A = key (0 if none)
    jsr GETIN
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
    cmp #'W'
    beq @up
    cmp #'w'
    beq @up
    cmp #KEY_DOWN
    beq @down
    cmp #'S'
    beq @down
    cmp #'s'
    beq @down
    cmp #KEY_LEFT
    beq @left
    cmp #'A'
    beq @left
    cmp #'a'
    beq @left
    cmp #KEY_RIGHT
    beq @right
    cmp #'D'
    beq @right
    cmp #'d'
    beq @right
    cmp #'P'
    beq @pause
    cmp #'p'
    beq @pause
    cmp #$20              ; Space
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

.proc platform_gotoxy_pixel
    ; Pixel position: gfx_x1 (16-bit) = X, A = Y
    ; Set r0 = X, r1 = Y for GRAPH_put_char
    ldx gfx_x1
    stx r0L
    ldx gfx_x1+1
    stx r0H
    sta r1L
    lda #0
    sta r1H
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
; platform_play_note
;   Plays a note on VERA PSG voice 0.
;   X = frequency low byte, Y = frequency high byte
;   A = volume (0-63, upper 2 bits = LR: $C0 = both channels)
; ---------------------------------------------------------------------------

.proc platform_play_note
    pha                     ; save volume

    ; Convert Hz (in X/Y) to VERA PSG register value
    ; Formula: reg = hz + (hz>>2) + (hz>>4) + (hz>>5)
    ; This approximates hz * 65536/48828 (≈ hz * 1.34375)
    stx r2L                 ; r2 = original hz
    sty r2H
    stx r3L                 ; r3 = result (starts as hz)
    sty r3H

    ; hz >> 2
    lsr r2H
    ror r2L
    lsr r2H
    ror r2L
    ; result += hz>>2
    clc
    lda r3L
    adc r2L
    sta r3L
    lda r3H
    adc r2H
    sta r3H

    ; hz >> 4 (shift r2 right 2 more)
    lsr r2H
    ror r2L
    lsr r2H
    ror r2L
    ; result += hz>>4
    clc
    lda r3L
    adc r2L
    sta r3L
    lda r3H
    adc r2H
    sta r3H

    ; hz >> 5 (shift r2 right 1 more)
    lsr r2H
    ror r2L
    ; result += hz>>5
    clc
    lda r3L
    adc r2L
    sta r3L
    lda r3H
    adc r2H
    sta r3H

    ; Set VERA address to PSG voice 0 ($1F9C0)
    lda #PSG_VOICE0_ADDR_L
    sta VERA_ADDR_L
    lda #PSG_VOICE0_ADDR_M
    sta VERA_ADDR_M
    lda #PSG_VOICE0_ADDR_H
    sta VERA_ADDR_H

    ; Write converted freq
    lda r3L
    sta VERA_DATA0
    lda r3H
    sta VERA_DATA0
    ; Write volume + LR (both channels)
    pla
    ora #$C0                ; LR bits = both channels
    sta VERA_DATA0
    ; Write waveform: pulse, width=63
    lda #$3F
    sta VERA_DATA0
    rts
.endproc

; ---------------------------------------------------------------------------
; platform_stop_sound
;   Silences VERA PSG voice 0.
; ---------------------------------------------------------------------------

.proc platform_stop_sound
    lda #PSG_VOICE0_ADDR_L
    sta VERA_ADDR_L
    lda #PSG_VOICE0_ADDR_M
    sta VERA_ADDR_M
    lda #PSG_VOICE0_ADDR_H
    sta VERA_ADDR_H

    ; freq = 0
    lda #0
    sta VERA_DATA0
    sta VERA_DATA0
    ; volume = 0
    sta VERA_DATA0
    ; waveform = 0
    sta VERA_DATA0
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "RODATA"

; X16 palette index for green
COLOR_GREEN: .byte $05

; X16 palette index for red
COLOR_RED: .byte $02

; X16 palette index for yellow
COLOR_YELLOW: .byte $07

; X16 palette index for light grey
COLOR_LGRAY: .byte $0F

; X16 palette index for blue
COLOR_BLUE: .byte $06
