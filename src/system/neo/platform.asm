; ---------------------------------------------------------------------------
; platform.asm - Neo6502 platform
; ---------------------------------------------------------------------------
; Hardware abstraction for Neo6502: graphics, input, sound via the
; Neo6502 API messaging system.
; ---------------------------------------------------------------------------

.import main

.import gfx_x1, gfx_y1, gfx_x2, gfx_y2
.import sfx_delay

.include "api/wm_equates.inc"

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

; ---------------------------------------------------------------------------
; Neo6502 KERNAL vectors

WriteCharacter = $FFF1
ReadCharacter  = $FFEE

; ---------------------------------------------------------------------------
; Neo6502 API registers

API_COMMAND    = $FF00
API_FUNCTION   = $FF01
API_PARAMETERS = $FF04

; API groups
API_GROUP_SYSTEM     = $01
API_GROUP_CONSOLE    = $02
API_GROUP_MATH       = $04
API_GROUP_GRAPHICS   = $05
API_GROUP_CONTROLLER = $07

; System functions
API_FN_RESET          = $07

; Console functions
API_FN_READ_CHAR      = $01
API_FN_WRITE_CHAR     = $06
API_FN_SET_CURSOR_POS = $07
API_FN_CLEAR_SCREEN   = $0C
API_FN_SET_TEXT_COLOR  = $0F

; Graphics functions
API_FN_DRAW_LINE    = $02
API_FN_DRAW_RECT    = $03
API_FN_DRAW_TEXT    = $06
API_FN_SET_COLOR    = $40
API_FN_SET_SOLID    = $41
API_FN_FRAME_COUNT  = $25

; Math functions
API_FN_RND_INT      = $1C

; Controller functions
API_FN_READ_CONTROLLER = $01

; Sound functions
API_GROUP_SOUND      = $08
API_FN_PLAY_SOUND    = $05
API_FN_QUEUE_SOUND   = $04
API_FN_RESET_CHANNEL = $02

; Controller result bits
CTRL_LEFT  = $01
CTRL_RIGHT = $02
CTRL_UP    = $04
CTRL_DOWN  = $08

; Neo6502 color codes
NEO_COLOR_BLACK = $80
NEO_COLOR_GREEN = $82

; ---------------------------------------------------------------------------

.segment "STARTUP"
    jmp main

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; Helper: wait for API command to complete
; ---------------------------------------------------------------------------
wait_api:
    lda API_COMMAND
    bne wait_api
    rts

; ---------------------------------------------------------------------------

.proc platform_init
    ; Clear console
    jsr wait_api
    lda #API_FN_CLEAR_SCREEN
    sta API_FUNCTION
    lda #API_GROUP_CONSOLE
    sta API_COMMAND

    ; Set graphics color to black
    jsr wait_api
    lda #(NEO_COLOR_BLACK & $0F)
    sta API_PARAMETERS + 0
    lda #API_FN_SET_COLOR
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND

    ; Set solid fill
    jsr wait_api
    lda #1
    sta API_PARAMETERS + 0
    lda #API_FN_SET_SOLID
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND

    ; Clear screen: draw black filled rect over entire display
    jsr wait_api
    lda #0
    sta API_PARAMETERS + 0
    sta API_PARAMETERS + 1
    sta API_PARAMETERS + 2
    sta API_PARAMETERS + 3
    lda #<320
    sta API_PARAMETERS + 4
    lda #>320
    sta API_PARAMETERS + 5
    lda #<240
    sta API_PARAMETERS + 6
    lda #>240
    sta API_PARAMETERS + 7
    lda #API_FN_DRAW_RECT
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND

    ; Reset to non-solid
    jsr wait_api
    lda #0
    sta API_PARAMETERS + 0
    lda #API_FN_SET_SOLID
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND
    rts
.endproc

.proc platform_cls
    ; Clear console layer
    jsr wait_api
    lda #API_FN_CLEAR_SCREEN
    sta API_FUNCTION
    lda #API_GROUP_CONSOLE
    sta API_COMMAND

    ; Set graphics color to black
    jsr wait_api
    lda #(NEO_COLOR_BLACK & $0F)
    sta API_PARAMETERS + 0
    lda #API_FN_SET_COLOR
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND

    ; Set solid fill
    jsr wait_api
    lda #1
    sta API_PARAMETERS + 0
    lda #API_FN_SET_SOLID
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND

    ; Draw black filled rect over entire display
    jsr wait_api
    lda #0
    sta API_PARAMETERS + 0
    sta API_PARAMETERS + 1
    sta API_PARAMETERS + 2
    sta API_PARAMETERS + 3
    lda #<320
    sta API_PARAMETERS + 4
    lda #>320
    sta API_PARAMETERS + 5
    lda #<240
    sta API_PARAMETERS + 6
    lda #>240
    sta API_PARAMETERS + 7
    lda #API_FN_DRAW_RECT
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND

    ; Reset to non-solid
    jsr wait_api
    lda #0
    sta API_PARAMETERS + 0
    lda #API_FN_SET_SOLID
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND
    rts
.endproc

.proc platform_getkey
    ; Blocking key read via API
@loop:
    jsr wait_api
    lda #API_FN_READ_CHAR
    sta API_FUNCTION
    lda #API_GROUP_CONSOLE
    sta API_COMMAND
    jsr wait_api
    lda API_PARAMETERS + 0
    beq @loop
    rts
.endproc

.proc platform_check_key
    ; Non-blocking key read. Returns: A = key (0 if none)
    jsr wait_api
    lda #API_FN_READ_CHAR
    sta API_FUNCTION
    lda #API_GROUP_CONSOLE
    sta API_COMMAND
    jsr wait_api
    lda API_PARAMETERS + 0
    rts
.endproc

.proc platform_set_color
    ; A = color index (0-15)
    ; Sets graphics draw color and console text color
    pha

    ; Set graphics drawing color
    jsr wait_api
    pla
    pha
    sta API_PARAMETERS + 0
    lda #API_FN_SET_COLOR
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND

    ; Set console text color (fg = color, bg = black)
    jsr wait_api
    pla
    ora #$80                    ; convert index to Neo6502 color code
    sta API_PARAMETERS + 0      ; foreground
    lda #NEO_COLOR_BLACK
    sta API_PARAMETERS + 1      ; background
    lda #API_FN_SET_TEXT_COLOR
    sta API_FUNCTION
    lda #API_GROUP_CONSOLE
    sta API_COMMAND
    rts
.endproc

.proc platform_draw_line
    ; Draw line from gfx_x1,gfx_y1 to gfx_x2,gfx_y2
    jsr wait_api
    lda gfx_x1
    sta API_PARAMETERS + 0
    lda gfx_x1+1
    sta API_PARAMETERS + 1
    lda gfx_y1
    sta API_PARAMETERS + 2
    lda gfx_y1+1
    sta API_PARAMETERS + 3
    lda gfx_x2
    sta API_PARAMETERS + 4
    lda gfx_x2+1
    sta API_PARAMETERS + 5
    lda gfx_y2
    sta API_PARAMETERS + 6
    lda gfx_y2+1
    sta API_PARAMETERS + 7
    lda #API_FN_DRAW_LINE
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND
    rts
.endproc

.proc platform_draw_filled_rect
    ; Draw filled rect from gfx_x1,gfx_y1 to gfx_x2,gfx_y2

    ; Set solid fill
    jsr wait_api
    lda #1
    sta API_PARAMETERS + 0
    lda #API_FN_SET_SOLID
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND

    ; Draw rectangle
    jsr wait_api
    lda gfx_x1
    sta API_PARAMETERS + 0
    lda gfx_x1+1
    sta API_PARAMETERS + 1
    lda gfx_y1
    sta API_PARAMETERS + 2
    lda gfx_y1+1
    sta API_PARAMETERS + 3
    lda gfx_x2
    sta API_PARAMETERS + 4
    lda gfx_x2+1
    sta API_PARAMETERS + 5
    lda gfx_y2
    sta API_PARAMETERS + 6
    lda gfx_y2+1
    sta API_PARAMETERS + 7
    lda #API_FN_DRAW_RECT
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND

    ; Reset to non-solid
    jsr wait_api
    lda #0
    sta API_PARAMETERS + 0
    lda #API_FN_SET_SOLID
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND
    rts
.endproc

.proc platform_poll_input
    ; Non-blocking input: check keyboard for P/Q, controller for directions.
    ; Returns action/direction in A.

    ; First check keyboard (non-blocking)
    jsr wait_api
    lda #API_FN_READ_CHAR
    sta API_FUNCTION
    lda #API_GROUP_CONSOLE
    sta API_COMMAND
    jsr wait_api
    lda API_PARAMETERS + 0
    beq @check_ctrl          ; no key pressed, check controller
    cmp #'P'
    beq @pause
    cmp #'p'
    beq @pause
    cmp #'Q'
    beq @quit
    cmp #'q'
    beq @quit

    ; Not P or Q, fall through to controller check
@check_ctrl:
    jsr wait_api
    lda #API_FN_READ_CONTROLLER
    sta API_FUNCTION
    lda #API_GROUP_CONTROLLER
    sta API_COMMAND
    jsr wait_api
    lda API_PARAMETERS + 0
    beq @none
    tax                     ; save result
    and #CTRL_UP
    bne @up
    txa
    and #CTRL_DOWN
    bne @down
    txa
    and #CTRL_LEFT
    bne @left
    txa
    and #CTRL_RIGHT
    bne @right
@none:
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
    ; Wait for next frame using FRAME_COUNT API
    jsr wait_api
    lda #API_FN_FRAME_COUNT
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND
    jsr wait_api
    lda API_PARAMETERS + 0
    sta vsync_frame
@loop:
    jsr wait_api
    lda #API_FN_FRAME_COUNT
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND
    jsr wait_api
    lda API_PARAMETERS + 0
    cmp vsync_frame
    beq @loop
    rts
.endproc

.proc platform_gotoxy
    ; X = column, Y = row (in 40-column coordinate space)
    ; Neo6502 has 53 columns (6px wide font), so offset X by (53-40)/2 = 6
    ; to center the 40-column layout on the wider display
    lda #0
    sta neo_text_pixel_mode     ; clear pixel mode
    txa
    clc
    adc #6
    tax
    jsr wait_api
    stx API_PARAMETERS + 0
    sty API_PARAMETERS + 1
    lda #API_FN_SET_CURSOR_POS
    sta API_FUNCTION
    lda #API_GROUP_CONSOLE
    sta API_COMMAND
    rts
.endproc

.proc platform_gotoxy_pixel
    ; Pixel position: gfx_x1 (16-bit) = X, A = Y
    ; Neo6502 DRAW_TEXT Y is top of glyph; offset by -6 to align with X16
    sec
    sbc #6
    sta neo_text_y
    lda gfx_x1
    sta neo_text_x
    lda gfx_x1+1
    sta neo_text_x+1
    lda #1
    sta neo_text_pixel_mode
    rts
.endproc

.proc platform_putc
    ; A = character to print
    ; Preserves X, Y
    phx
    phy
    ldx neo_text_pixel_mode
    bne @pixel_mode

    ; Console mode: use WriteCharacter
    jsr WriteCharacter
    ply
    plx
    rts

@pixel_mode:
    ; Store character in 1-byte length-prefixed string
    sta neo_text_buf + 1
    lda #1
    sta neo_text_buf            ; length = 1

    ; DRAW_TEXT: Group 5, Function $06
    ; Params: X(16), Y(16), string_ptr(16)
    jsr wait_api
    lda neo_text_x
    sta API_PARAMETERS + 0      ; X low
    lda neo_text_x+1
    sta API_PARAMETERS + 1      ; X high
    lda neo_text_y
    sta API_PARAMETERS + 2      ; Y low
    lda #0
    sta API_PARAMETERS + 3      ; Y high
    lda #<neo_text_buf
    sta API_PARAMETERS + 4      ; string pointer low
    lda #>neo_text_buf
    sta API_PARAMETERS + 5      ; string pointer high
    lda #API_FN_DRAW_TEXT
    sta API_FUNCTION
    lda #API_GROUP_GRAPHICS
    sta API_COMMAND

    ; Advance X by 6 pixels (character width)
    clc
    lda neo_text_x
    adc #6
    sta neo_text_x
    lda neo_text_x+1
    adc #0
    sta neo_text_x+1

    ply
    plx
    rts
.endproc

.proc platform_exit
    ; Clear screen
    jsr wait_api
    lda #API_FN_CLEAR_SCREEN
    sta API_FUNCTION
    lda #API_GROUP_CONSOLE
    sta API_COMMAND

    ; Reset system
    jsr wait_api
    lda #API_FN_RESET
    sta API_FUNCTION
    lda #API_GROUP_SYSTEM
    sta API_COMMAND
@halt:
    jmp @halt
.endproc

.proc platform_random
    ; Returns a random byte in A (0-255)
    ; Neo6502 Math API uses indirect registers:
    ;   API_PARAMETERS+0/+1 = pointer to register data in RAM
    ;   API_PARAMETERS+2    = stride (1 = contiguous)
    ; Register format: type_byte (0=int), then 4 bytes of 32-bit LE value

    ; Set up the register buffer with max value = 256
    lda #$00
    sta math_reg            ; type = integer
    sta math_reg + 1        ; value lo = 0
    lda #$01
    sta math_reg + 2        ; value = $00000100 = 256
    lda #$00
    sta math_reg + 3
    sta math_reg + 4

    jsr wait_api
    lda #<math_reg
    sta API_PARAMETERS + 0
    lda #>math_reg
    sta API_PARAMETERS + 1
    lda #1
    sta API_PARAMETERS + 2  ; stride
    lda #API_FN_RND_INT
    sta API_FUNCTION
    lda #API_GROUP_MATH
    sta API_COMMAND
    jsr wait_api

    ; Result is written back to math_reg (low byte of 32-bit int)
    lda math_reg + 1
    rts
.endproc

; ---------------------------------------------------------------------------
; platform_play_note
;   Plays a note on Neo6502 sound channel 0.
;   X = frequency low byte, Y = frequency high byte
;   A = volume (ignored on Neo6502 - always full volume)
;   Duration is fixed at a short beep (~4 frames / 66ms)
; ---------------------------------------------------------------------------

.proc platform_play_note
    ; Drop one octave (halve frequency) to match X16 pulse wave perception
    tya                         ; freq_hi
    lsr                         ; shift high byte right, carry = bit 0
    tay                         ; Y = new freq_hi
    txa                         ; freq_lo
    ror                         ; rotate carry into bit 7, shift right
    tax                         ; X = new freq_lo

    ; Calculate duration from sfx_delay (frames * 2 centiseconds)
    lda sfx_delay
    asl                         ; frames * 2 = approx centiseconds
    sta neo_snd_duration

    jsr wait_api
    lda #0
    sta API_PARAMETERS + 0      ; channel 0
    stx API_PARAMETERS + 1      ; frequency low (Hz)
    sty API_PARAMETERS + 2      ; frequency high (Hz)
    lda neo_snd_duration
    sta API_PARAMETERS + 3      ; duration low (centiseconds)
    lda #0
    sta API_PARAMETERS + 4      ; duration high
    lda #0                      ; slide type (none)
    sta API_PARAMETERS + 5
    lda #0                      ; slide target low
    sta API_PARAMETERS + 6
    lda #0                      ; slide target high
    sta API_PARAMETERS + 7
    lda #API_FN_QUEUE_SOUND
    sta API_FUNCTION
    lda #API_GROUP_SOUND
    sta API_COMMAND
    rts
.endproc

; ---------------------------------------------------------------------------
; platform_stop_sound
;   Silences Neo6502 sound channel 0.
; ---------------------------------------------------------------------------

.proc platform_stop_sound
    jsr wait_api
    lda #0
    sta API_PARAMETERS + 0      ; channel 0
    lda #API_FN_RESET_CHANNEL
    sta API_FUNCTION
    lda #API_GROUP_SOUND
    sta API_COMMAND
    rts
.endproc

; ---------------------------------------------------------------------------

.segment "BSS"

vsync_frame:          .res 1
math_reg:             .res 5          ; type byte + 4 bytes for 32-bit value
neo_snd_duration:     .res 1          ; calculated note duration in centiseconds
neo_text_pixel_mode:  .res 1          ; 0 = console mode, 1 = pixel mode
neo_text_x:           .res 2          ; current pixel X for text drawing
neo_text_y:           .res 1          ; current pixel Y for text drawing
neo_text_buf:         .res 2          ; length-prefixed 1-char string buffer

; ---------------------------------------------------------------------------

.segment "RODATA"

; Neo6502 palette index for green
COLOR_GREEN: .byte $02

; Neo6502 palette index for red
COLOR_RED: .byte $01

; Neo6502 palette index for yellow
COLOR_YELLOW: .byte $03

; Neo6502 palette index for light grey
COLOR_LGRAY: .byte $07

; Neo6502 palette index for blue
COLOR_BLUE: .byte $04
