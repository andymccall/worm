;----------------------------------------------------------------------------
;
; wm_equates.inc - Shared constants for the ZX Spectrum Next port
;
; Mirrors the role of src/x16/system/wm_equates.inc and src/pce/system/
; wm_equates.inc but with the constants the Next HAL needs (NEXTREG
; numbers, Layer 2 banks, palette codes) added on the side.
;
; Game-space vs screen-space:
;   The game logic and engine code think in 320x240 GAME coordinates -
;   the same coordinate system used by the X16 / Neo / PCE ports. The
;   Next's Layer 2 canvas is 320x256, so we centre the game canvas
;   vertically with 8px of padding top and bottom (GAME_Y_OFFSET=8).
;   The platform draw primitives apply that offset internally, so the
;   engine code stays portable to the X16 coordinate space.
;
;----------------------------------------------------------------------------

        IFNDEF WM_EQUATES_INC
        DEFINE WM_EQUATES_INC

;----------------------------------------------------------------------------
; Direction constants
;----------------------------------------------------------------------------

DIR_NONE                equ     0
DIR_UP                  equ     1
DIR_DOWN                equ     2
DIR_LEFT                equ     3
DIR_RIGHT               equ     4

;----------------------------------------------------------------------------
; Action input codes
;----------------------------------------------------------------------------

INPUT_PAUSE             equ     5
INPUT_QUIT              equ     6

;----------------------------------------------------------------------------
; Screen / canvas dimensions
;
; SCREEN_W/H are the GAME canvas (matches X16/Neo/PCE). The Next's Layer 2
; in 320x256 mode adds 8px of padding above and below the game canvas;
; the platform layer applies the offset.
;----------------------------------------------------------------------------

SCREEN_W                equ     320
SCREEN_H                equ     240

L2_W                    equ     320
L2_H                    equ     256
GAME_Y_OFFSET           equ     (L2_H - SCREEN_H) / 2   ; = 8

;----------------------------------------------------------------------------
; Grid setup (game coordinates - matches X16/Neo)
;----------------------------------------------------------------------------

CELL_SIZE               equ     8
GRID_X                  equ     12
GRID_Y                  equ     26
GRID_COLS               equ     37
GRID_ROWS               equ     25

;----------------------------------------------------------------------------
; Movement timing
;----------------------------------------------------------------------------

MOVE_DELAY              equ     8

;----------------------------------------------------------------------------
; Worm length cap and lives cap
;----------------------------------------------------------------------------

MAX_LENGTH              equ     255
MAX_SPIDERS             equ     8
MAX_LIVES               equ     3

;----------------------------------------------------------------------------
; Border / status bar layout - GAME coordinates (verbatim from X16)
;----------------------------------------------------------------------------

BORDER_X1               equ     10
BORDER_Y1               equ     10
BORDER_X2               equ     309
BORDER_Y2               equ     229
DIVIDER_Y               equ     24

;----------------------------------------------------------------------------
; Status bar text positions
;
; The X16 port specifies these as KERNAL-baseline y values (20). Our Next
; HAL takes glyph-TOP y, so the constants below are X16's baseline minus
; 7. The X position is unchanged.
;----------------------------------------------------------------------------

STATUS_FOOD_X           equ     14
STATUS_FOOD_Y           equ     13      ; glyph top (X16 baseline 20 - 7)
STATUS_LIVES_X          equ     236
STATUS_LIVES_Y          equ     13

;----------------------------------------------------------------------------
; Status bar hearts
;----------------------------------------------------------------------------

STATUS_HEART_X_START    equ     278
STATUS_HEART_Y          equ     14
STATUS_HEART_SPACING    equ     10
STATUS_HEART_MAX        equ     6

;----------------------------------------------------------------------------
; Palette - Next 8-bit RRRGGGBB
;
; Layer 2 default palette is 8-bit. The full game will likely upgrade to
; the 9-bit palette via the priority bit, but the milestone is to reach
; visual parity with the X16 screenshots which use 8 fixed colours.
;----------------------------------------------------------------------------

COL_BLACK               equ     %00000000
COL_GREEN               equ     %00011100       ; bright green (border + worm)
COL_RED                 equ     %11100000       ; hearts
COL_YELLOW              equ     %11111100       ; food
COL_LGRAY               equ     %10010010       ; spider
COL_BLUE                equ     %00000010       ; menu hotkeys
COL_WHITE               equ     %11111111

;----------------------------------------------------------------------------
; ZX Spectrum Next register I/O ports + register numbers we touch.
;
; The Z80N "NEXTREG n,m" / "NEXTREG n,A" opcodes write through these ports.
;----------------------------------------------------------------------------

NEXTREG_SELECT          equ     $243B
NEXTREG_VALUE           equ     $253B

NR_RESET                equ     $02     ; bit 0 = hard reset, bit 1 = soft
NR_LAYER2_BANK          equ     $12
NR_CLIP_LAYER2          equ     $18    ; clip window: 4 writes (xmin,xmax,ymin,ymax)
NR_CLIP_INDEX           equ     $1C    ; clip-window index control (bit 1 = reset L2)
NR_VIDEO_LINE_MSB       equ     $1E    ; bit 0 = MSB of active scan line
NR_VIDEO_LINE_LSB       equ     $1F    ; LSB of active scan line (0..255)
NR_MMU0                 equ     $50
NR_MMU1                 equ     $51
NR_DISPLAY_CTRL_1       equ     $69
NR_LAYER2_CTRL          equ     $70

;----------------------------------------------------------------------------
; Keyboard
;
; The Next preserves the original Spectrum keyboard matrix. Reading port
; $xxFE returns the half-row selected by the high byte: bit clear = key
; pressed. We only care about S, A, D, Q for the menu, so the routine
; scans just those two half-rows.
;----------------------------------------------------------------------------

KEY_PORT_LO             equ     $FE

;----------------------------------------------------------------------------
; Layer 2 framebuffer banks.
;
; 320x256 mode needs 80KB (320*256). Layer 2 is contiguous starting at the
; bank pointed to by NR_LAYER2_BANK; we use bank 9 onwards (banks 9..13)
; which is the standard Layer 2 region NextOS leaves available.
;
; Each 16K bank holds 64 columns (16384 bytes / 256 rows per column). To
; touch the whole frame we page each bank into MMU 0+1 in turn.
;----------------------------------------------------------------------------

LAYER2_BASE_BANK        equ     9
LAYER2_NUM_BANKS        equ     5       ; banks 9..13
LAYER2_COLS_PER_BANK    equ     64

        ENDIF
