; ***************************************************************************
;
; wm_equates.inc
;
; PC Engine project-wide equates for the Worm port. Mirrors src/x16/system/
; wm_equates.inc and src/neo/system/wm_equates.inc on the cc65 trees but
; adds PCE-only pieces (palette indices, tile slot allocation, BAT/VRAM
; layout).
;
; Included once from main.asm; visible to every other src/pce/ file via
; that single include.
;
; ***************************************************************************

; ---------------------------------------------------------------------------
; VRAM layout
; ---------------------------------------------------------------------------
; The PCE VDC sees 64KB of VRAM as 16-bit words. The default screen mode
; initialised by init_256x224 (in vdc.asm) gives a 64x32 BAT, which we
; place at the start of VRAM, followed by the SAT, then tile data.
;
;   $0000..$07FF   BAT  (64 columns x 32 rows = 2048 words)
;   $0800..$08FF   SAT  (256 words = 64 sprites x 4 attribute words)
;   $0900..        Tile data (graphics tiles + font + future game tiles)

BAT_LINE        =       64                  ; BAT stride in tiles per row.
BAT_SIZE        =       64 * 32             ; Total BAT cells.
SAT_ADDR        =       BAT_SIZE            ; SAT lives just past the BAT.
CHR_ZERO        =       BAT_SIZE / 16       ; First tile slot after BAT.
CHR_0x10        =       CHR_ZERO + 16       ; First slot after BAT + SAT.
CHR_0x20        =       CHR_ZERO + 32       ; ASCII space-glyph tile slot.

; ---------------------------------------------------------------------------
; Palette indices
; ---------------------------------------------------------------------------
; Each PCE palette is 16 colours; the BAT cell encodes its palette in the
; high nibble of the high byte. We use 4 of the 16 background palettes:

PAL_GREEN       =       0
PAL_BLUE        =       1
PAL_YELLOW      =       2
PAL_RED         =       3

; ---------------------------------------------------------------------------
; Tile slots in CHR space (graphics tiles before the ASCII font range).
; ---------------------------------------------------------------------------
; The border edge/corner tiles are intentionally asymmetric so the line
; sits hard against the playfield interior rather than centred in its
; cell. That gives a 2-pixel gap between border and worm cells (matching
; the X16/Neo look) instead of the 4-pixel gap a centred line gives.
;   top edge    line at cell-row 6  (pulled toward the playfield)
;   bottom edge line at cell-row 1
;   left edge   line at cell-col 6
;   right edge  line at cell-col 1

CHR_BLOCK         =     CHR_0x10 + 0    ; Worm-segment rounded block
CHR_BORDER_H_TOP  =     CHR_0x10 + 1    ; Horizontal edge, line at row 6
CHR_BORDER_H_BOT  =     CHR_0x10 + 2    ; Horizontal edge, line at row 1
CHR_BORDER_V_LEFT =     CHR_0x10 + 3    ; Vertical edge, line at col 6
CHR_BORDER_V_RIGHT=     CHR_0x10 + 4    ; Vertical edge, line at col 1
CHR_BORDER_TL     =     CHR_0x10 + 5    ; Top-left corner    (row 6 + col 6)
CHR_BORDER_TR     =     CHR_0x10 + 6    ; Top-right corner   (row 6 + col 1)
CHR_BORDER_BL     =     CHR_0x10 + 7    ; Bottom-left corner (row 1 + col 6)
CHR_BORDER_BR     =     CHR_0x10 + 8    ; Bottom-right corner(row 1 + col 1)
CHR_DIV_H         =     CHR_0x10 + 9    ; Divider horizontal
CHR_DIV_VR        =     CHR_0x10 + 10   ; Divider left T-junction
CHR_DIV_VL        =     CHR_0x10 + 11   ; Divider right T-junction
CHR_HEART         =     CHR_0x10 + 12   ; 7x6 heart for LIVES display
CHR_FOOD          =     CHR_0x10 + 13   ; 4-leaf clover food pellet

NUM_GFX_TILES     =     14              ; Tiles uploaded by upload_gfx_tiles

; ---------------------------------------------------------------------------
; Border layout
; ---------------------------------------------------------------------------
; The border encloses the whole screen with a horizontal divider crossing
; it just under the status bar.
;   row 0   top edge (TL, HORIZ x N, TR)
;   row 1   status bar text (FOOD ... LIVES) inside vertical edges
;   row 2   divider (VR, HORIZ x N, VL)  -- T-junctions on the side edges
;   rows 3-26  playfield (WORM title, menu items)
;   row 27  bottom edge (BL, HORIZ x N, BR)

BORDER_TOP_ROW    =     0
BORDER_DIV_ROW    =     2
BORDER_BOT_ROW    =     27
BORDER_LEFT_COL   =     0
BORDER_RIGHT_COL  =     31
STATUS_ROW        =     1

; ---------------------------------------------------------------------------
; Status bar layout
; ---------------------------------------------------------------------------
; FOOD label sits at column 1, the 3-char count starts right after at
; column 6 (matches the X16/Neo "FOOD %3d" formatting). LIVES label at
; column 22; up to STATUS_HEART_MAX hearts follow at STATUS_HEART_COL,
; one cell each.

STATUS_FOOD_COL       = 1
STATUS_FOOD_COUNT_COL = 6                      ; "FOOD " is 5 chars
STATUS_LIVES_COL      = 22
STATUS_HEART_COL      = 28

; Lives + heart display (matches src/x16/system/wm_equates.inc).
MAX_LIVES         =     3
STATUS_HEART_MAX  =     6

; ---------------------------------------------------------------------------
; Direction codes (matches src/x16/system/wm_equates.inc)
; ---------------------------------------------------------------------------

DIR_NONE          =     0
DIR_UP            =     1
DIR_DOWN          =     2
DIR_LEFT          =     3
DIR_RIGHT         =     4

; ---------------------------------------------------------------------------
; Playfield grid
; ---------------------------------------------------------------------------
; The X16/Neo grid is 37x25 cells of 8 pixels each, sitting inside a
; 320-wide bitmap. The PCE BAT is 32 cells wide, with the green border at
; cols 0 and 31, so the playfield interior is 30 cols x 24 rows (cells
; 1..30 x rows 3..26 in BAT coordinates). The worm's grid (0,0) is the
; top-left interior cell.

GRID_COLS         =     30                ; was 37 on X16/Neo
GRID_ROWS         =     24                ; was 25 on X16/Neo
GRID_BAT_COL      =     1                 ; BAT col of grid origin (0,0)
GRID_BAT_ROW      =     3                 ; BAT row of grid origin (0,0)

; Movement timing (frames between moves). The X16/Neo build uses 8 frames
; (~7.5 cells/sec @ 60Hz) for identical gameplay feel, but PCE cells are
; 8px on a narrower 256-wide screen so the worm reads as covering less
; ground per second visually. Set to 3 here for a noticeably faster pace.
MOVE_DELAY        =     3

; Maximum worm length (matches src/x16/system/wm_equates.inc).
MAX_LENGTH        =     255

; ---------------------------------------------------------------------------
; Playfield-clear region (interior of the green border, below the divider)
; ---------------------------------------------------------------------------

PLAYFIELD_TOP_ROW       = 3
PLAYFIELD_BOT_ROW       = 26
PLAYFIELD_LEFT_COL      = 1
PLAYFIELD_RIGHT_COL     = 30
PLAYFIELD_WIDTH         = PLAYFIELD_RIGHT_COL - PLAYFIELD_LEFT_COL + 1

; ---------------------------------------------------------------------------
; Menu
; ---------------------------------------------------------------------------
; PC Engine has no software-quit so we omit the QUIT item that the X16/Neo
; build offers; START / ABOUT / DEMO only.

NUM_MENU_ITEMS  =       3
MENU_ROW_0      =       16              ; First menu item
MENU_ROW_1      =       18
MENU_ROW_2      =       20
MENU_COL        =       12              ; Where menu text starts
CURSOR_COL      =       10              ; Where the cursor block lives

; ---------------------------------------------------------------------------
; About screen rows
; ---------------------------------------------------------------------------

ABOUT_AUTHOR_ROW        =       12
ABOUT_EMAIL_ROW         =       14
ABOUT_REPO_ROW          =       16
ABOUT_PROMPT_ROW        =       23

; ---------------------------------------------------------------------------
; Overlay placement + delays
; ---------------------------------------------------------------------------
; Empirically tuned: wait_vsync on this build runs at ~16 Hz rather than
; the expected 60 Hz (probably due to CORE's IRQ kernel only ticking
; irq_cnt on every Nth vblank under our setup). 50 iterations =~ 3 s,
; 16 =~ 1 s. If the underlying timing changes, only these constants
; need adjusting.

OVERLAY_ROW             =       14
DELAY_GET_READY         =       50      ; ~3 seconds
DELAY_LIFE_LOST         =       16      ; ~1 second pause after a death
DELAY_GAME_OVER         =       50      ; ~3 seconds on the GAME OVER screen
