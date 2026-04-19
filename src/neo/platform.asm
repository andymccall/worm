; platform.asm - Neo6502 platform

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

; Action input codes (returned by platform_poll_input)
INPUT_PAUSE = 5
INPUT_QUIT  = 6

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
API_FN_SET_COLOR    = $40
API_FN_SET_SOLID    = $41
API_FN_FRAME_COUNT  = $25

; Math functions
API_FN_RND_INT      = $1C

; Controller functions
API_FN_READ_CONTROLLER = $01

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

.proc platform_putc
    ; A = character to print
    ; Preserves X, Y
    phx
    phy
    jsr WriteCharacter
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

.segment "BSS"

vsync_frame: .res 1
math_reg:    .res 5          ; type byte + 4 bytes for 32-bit value

; ---------------------------------------------------------------------------

.segment "RODATA"

; Neo6502 palette index for green
COLOR_GREEN: .byte $02

; Neo6502 palette index for red
COLOR_RED: .byte $01
