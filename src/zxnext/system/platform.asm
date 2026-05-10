;----------------------------------------------------------------------------
;
; platform.asm - ZX Spectrum Next hardware abstraction layer
;
; Mirrors the role of src/x16/system/platform.asm and src/pce/system/
; platform.asm. The X16/Neo HAL exposes line-drawing primitives over a
; linear bitmap; the PCE HAL exposes tile-painting primitives over a BAT.
; The Next is closer to the X16 model - Layer 2 in 320x256 mode is a
; pixel-addressable bitmap (1 byte per pixel) - so this HAL exposes line
; primitives too.
;
; All draw primitives take coordinates in the 320x240 GAME coordinate
; space; the routines apply GAME_Y_OFFSET (=8) internally so the game
; canvas sits centred in the 320x256 frame.
;
; Calling conventions (sjasmplus is single-pass and we INCLUDE everything
; into one translation unit - all labels are global, so we just document
; in/out registers per routine):
;
;   platform_init     -> -                   - one-shot Layer 2 setup
;   platform_cls      A=colour               - clear all 5 banks
;   platform_draw_hline  HL=x DE=y A=colour BC=len   - horizontal run
;   platform_draw_vline  HL=x DE=y A=colour BC=len   - vertical run
;   page_layer2_bank  A=bank                 - map 16K bank A at $0000
;
; Paging strategy:
;   Layer 2 RAM is paged into MMU slots 0+1 ($0000..$3FFF), unmapping the
;   ROM. We never call ROM routines after init, and the stack at $ff40
;   stays intact because we don't touch slot 7. IRQs stay disabled
;   throughout so the IM 1 vector at $0038 (now Layer 2 pixel data)
;   never fires.
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; platform_init
;
; Switch Layer 2 to 320x256 8bpp, point it at LAYER2_BASE_BANK, page that
; bank into MMU 0+1, and turn Layer 2 on. Leaves IRQs disabled.
;
; Clobbers: A, BC.
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; platform_exit
;
; "Quit" the program. The Next has no kernel-level exit-to-shell syscall
; that works reliably across emulators - NEXTREG $02's reset bits are
; gated on real hardware and ignored by CSpect. The pragmatic equivalent
; of the X16's "return to BASIC" is therefore: paint a goodbye message,
; turn off Layer 2 so the user sees something cleaner than our paged
; framebuffer, and halt with IRQs disabled. On real hardware the user
; hits the physical reset button; on CSpect they close the window.
;
; Does not return.
;----------------------------------------------------------------------------

platform_exit:
        ld      a, COL_BLACK
        call    platform_cls
        di
.spin:
        jr      .spin

;----------------------------------------------------------------------------
; platform_init
;
; Switch Layer 2 to 320x256 8bpp, point it at LAYER2_BASE_BANK, page that
; bank into MMU 0+1, and turn Layer 2 on. Leaves IRQs disabled.
;
; Clobbers: A, BC.
;----------------------------------------------------------------------------

platform_init:
        di

        ; Copy the 48K ROM's 8x8 ASCII font from $3D00..$3FFF into our
        ; font_buffer in RAM. This must happen BEFORE we page Layer 2
        ; into MMU 0+1, because that page-in unmaps the ROM. After this
        ; copy the font is always reachable regardless of paging - the
        ; X16 / Neo / PCE ports either use a ROM/firmware text routine
        ; or incbin a font into RAM; this is the Next equivalent of the
        ; latter (sourced from the platform's own ROM).
        ld      hl, $3D00
        ld      de, font_buffer
        ld      bc, 768                 ; 96 glyphs * 8 bytes
        ldir

        nextreg NR_LAYER2_CTRL, %00010000       ; 320x256 8bpp, palette ofs 0
        nextreg NR_LAYER2_BANK, LAYER2_BASE_BANK

        ; Open the Layer 2 clip window to the full 320x256 frame.
        ;
        ; The clip-window register $18 is a 4-write sequence (xmin, xmax,
        ; ymin, ymax) advanced by an internal index. NextOS often leaves
        ; the index mid-sequence and the default ymax at 191 (legacy
        ; 256x192 Layer 2), so the bottom 64 rows of our 320x256 frame
        ; would be clipped without an explicit reset. Bit 1 of $1C resets
        ; the L2 clip index to 0, then we write 0, 159, 0, 255:
        ; x is in pixel-pairs in 320x256 mode (320/2 = 160 -> 0..159),
        ; y is in pixels (0..255).
        nextreg NR_CLIP_INDEX, %00000010        ; reset L2 clip index
        nextreg NR_CLIP_LAYER2, 0               ; xmin = 0
        nextreg NR_CLIP_LAYER2, 159             ; xmax = 159 (in /2 units)
        nextreg NR_CLIP_LAYER2, 0               ; ymin = 0
        nextreg NR_CLIP_LAYER2, 255             ; ymax = 255

        ld      a, LAYER2_BASE_BANK
        call    page_layer2_bank

        ; Turn Layer 2 on (NR $69 bit 7), preserving the other bits.
        ld      a, NR_DISPLAY_CTRL_1
        ld      bc, NEXTREG_SELECT
        out     (c), a
        ld      bc, NEXTREG_VALUE
        in      a, (c)
        or      %10000000
        out     (c), a
        ret

;----------------------------------------------------------------------------
; page_layer2_bank
;
; Map 16K bank A into MMU slots 0+1 ($0000..$3FFF). A 16K bank N covers
; 8K banks 2N (low) and 2N+1 (high), so we write 2N to MMU0 and 2N+1 to
; MMU1.
;
; Entry: A = 16K bank (0..223 valid; we use 9..13).
; Clobbers: A, BC.
; Preserves: DE, HL, IX, IY.
;----------------------------------------------------------------------------

page_layer2_bank:
        rlca                            ; A = bank * 2 (8K low half)
        push    af

        ld      bc, NEXTREG_SELECT
        ld      a, NR_MMU0
        out     (c), a
        ld      bc, NEXTREG_VALUE
        pop     af
        out     (c), a                  ; MMU0 = 2N

        inc     a
        push    af
        ld      bc, NEXTREG_SELECT
        ld      a, NR_MMU1
        out     (c), a
        ld      bc, NEXTREG_VALUE
        pop     af
        out     (c), a                  ; MMU1 = 2N + 1
        ret

;----------------------------------------------------------------------------
; platform_cls
;
; Fill the entire 320x256 Layer 2 framebuffer with colour A. Walks all 5
; banks, LDIR-ing 16K of A into each.
;
; Entry: A = 8-bit colour.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

platform_cls:
        ld      (cls_colour), a
        ld      a, LAYER2_BASE_BANK
.bank_loop:
        push    af
        call    page_layer2_bank

        ld      a, (cls_colour)
        ld      hl, $0000
        ld      (hl), a
        ld      d, h
        ld      e, l
        inc     de
        ld      bc, $3FFF
        ldir

        pop     af
        inc     a
        cp      LAYER2_BASE_BANK + LAYER2_NUM_BANKS
        jr      c, .bank_loop
        ret

cls_colour:     defb    0

;----------------------------------------------------------------------------
; platform_draw_hline
;
; Draw a horizontal line in colour A starting at GAME-space (HL, E),
; length BC pixels. The line may span multiple Layer 2 banks; we walk
; pixel by pixel and re-page when crossing a 64-column boundary.
;
; Entry: HL = x (0..319 game), E = y (0..239 game), A = colour, BC = len.
; Clobbers: A, BC, DE, HL.
;
; Implementation notes:
;   - Layer 2 320x256 is column-major: addr_in_bank = col*256 + row.
;     Within a bank we have 64 cols (col=0..63), and bytes(col,row) =
;     col*256 + row, i.e. high byte = col, low byte = row.
;   - "Current bank" tracking: we cache the most recently paged bank in
;     hline_cur_bank to avoid re-paging on every pixel.
;----------------------------------------------------------------------------

platform_draw_hline:
        ld      (hline_colour), a
        ld      (hline_x), hl
        ld      a, e
        add     a, GAME_Y_OFFSET
        ld      (hline_y_screen), a
        ld      (hline_len), bc

        ; Force a re-page on the first pixel.
        ld      a, $FF
        ld      (hline_cur_bank), a

.next_pixel:
        ld      bc, (hline_len)
        ld      a, b
        or      c
        ret     z

        ; Compute bank = LAYER2_BASE_BANK + (x >> 6), col_in_bank = x & $3F.
        ld      hl, (hline_x)
        ld      a, h
        ld      d, l
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d                       ; D = x >> 6 (0..4)

        ld      a, d
        add     a, LAYER2_BASE_BANK
        ld      d, a                    ; D = target bank

        ; Re-page if different from cached.
        ld      a, (hline_cur_bank)
        cp      d
        jr      z, .same_bank
        ld      a, d
        ld      (hline_cur_bank), a
        call    page_layer2_bank
.same_bank:

        ; Plot at H = (x_low & $3F), L = y_screen.
        ld      hl, (hline_x)
        ld      a, l
        and     $3F
        ld      h, a
        ld      a, (hline_y_screen)
        ld      l, a
        ld      a, (hline_colour)
        ld      (hl), a

        ; Bump x, decrement length, loop.
        ld      hl, (hline_x)
        inc     hl
        ld      (hline_x), hl
        ld      bc, (hline_len)
        dec     bc
        ld      (hline_len), bc
        jr      .next_pixel

hline_colour:   defb    0
hline_y_screen: defb    0
hline_cur_bank: defb    0
hline_x:        defw    0
hline_len:      defw    0

;----------------------------------------------------------------------------
; platform_draw_vline
;
; Draw a vertical line in colour A at GAME-space (HL, E), length BC.
; A vertical line lives entirely within one column - and therefore one
; bank - so we page once and run a tight loop with INC L (which steps
; one row in column-major layout).
;
; Entry: HL = x (0..319), E = y (0..239), A = colour, BC = length.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

platform_draw_vline:
        ld      (vline_colour), a

        ; Bank = LAYER2_BASE_BANK + (HL >> 6); col_in_bank = HL & $3F.
        push    bc                      ; preserve length
        ld      a, h
        ld      d, l
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d                       ; D = HL >> 6 (0..4)

        ld      a, d
        add     a, LAYER2_BASE_BANK
        call    page_layer2_bank

        ; HL_addr = (L & $3F) * 256 + (E + GAME_Y_OFFSET)
        ld      a, l
        and     $3F
        ld      h, a
        ld      a, e
        add     a, GAME_Y_OFFSET
        ld      l, a

        pop     bc                      ; B = high (zero), C = length
        ld      a, (vline_colour)
.vline_loop:
        ld      (hl), a
        inc     l                       ; next row (column-major: L is row)
        dec     c
        jr      nz, .vline_loop
        ret

vline_colour:   defb    0

;----------------------------------------------------------------------------
; platform_draw_filled_rect
;
; Fill an axis-aligned rectangle in colour A. Implemented as a sweep of
; vertical lines (one vline per column), which on the column-major
; framebuffer is the cache-friendly direction: an entire vline lives in
; one bank with no re-paging.
;
; Entry: HL = x1 (left, 0..319), E = y1 (top, 0..239),
;        BC = width in pixels, D = height in pixels,
;        A = colour.
;
; Note the unusual signature: width comes in BC because it can exceed
; 255 (the border-fill rect is 298 wide), height in D since heights are
; always small.
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

platform_draw_filled_rect:
        ld      (rect_colour), a
        ld      (rect_x), hl
        ld      a, e
        ld      (rect_y), a
        ld      a, d
        ld      (rect_h), a
        ld      (rect_w), bc

.col_loop:
        ; Exit if width counter (rect_w) hit zero.
        ld      bc, (rect_w)
        ld      a, b
        or      c
        ret     z

        ; Draw one vline of height rect_h at (rect_x, rect_y).
        ld      a, (rect_h)
        ld      c, a
        ld      b, 0                    ; BC = height
        ld      hl, (rect_x)
        ld      a, (rect_y)
        ld      e, a
        ld      a, (rect_colour)
        call    platform_draw_vline

        ; Advance x by 1, decrement width.
        ld      hl, (rect_x)
        inc     hl
        ld      (rect_x), hl
        ld      bc, (rect_w)
        dec     bc
        ld      (rect_w), bc
        jr      .col_loop

rect_x:         defw    0
rect_y:         defb    0
rect_w:         defw    0
rect_h:         defb    0
rect_colour:    defb    0

;----------------------------------------------------------------------------
; platform_putc
;
; Blit one 8x8 ASCII glyph onto Layer 2 in colour D at GAME-space (HL, E).
;
; Each glyph in font_buffer is 8 bytes, one per row, MSB = leftmost
; pixel. We render row by row: for each row, walk the 8 source bits
; left-to-right and write D to pixels where the bit is set, leaving
; "off" pixels untouched (so text can be drawn over a coloured field).
;
; Layer 2 320x256 is column-major (col*256 + row). A glyph row writes
; 8 pixels across 8 different columns at one fixed y, so we cache the
; current paged-in bank and re-page only when the column count crosses
; a 64-column boundary.
;
; Entry: A = ASCII (0x20..0x7F),
;        HL = x (0..319),
;        E = y in GAME coords (0..239),
;        D = colour.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

platform_putc:
        ; --- Stash all args into static scratch FIRST, before clobbering --
        ld      (putc_x_in), hl
        push    af                      ; save ASCII char

        ld      a, e
        add     a, GAME_Y_OFFSET
        ld      (putc_y_screen), a

        ld      a, d
        ld      (putc_colour), a

        pop     af                      ; restore ASCII char

        ; --- Validate range: 32..127, else clamp to space ----------------
        cp      $20
        jr      nc, .range_lo_ok
        ld      a, $20
.range_lo_ok:
        cp      $80
        jr      c, .range_hi_ok
        ld      a, $20
.range_hi_ok:
        sub     $20                     ; A = glyph index 0..95

        ; --- Glyph source pointer = font_buffer + A*8 --------------------
        ld      h, 0
        ld      l, a
        add     hl, hl                  ; *2
        add     hl, hl                  ; *4
        add     hl, hl                  ; *8
        ld      bc, font_buffer
        add     hl, bc
        ld      (putc_src), hl

        ; Force re-page on the first pixel.
        ld      a, $FF
        ld      (putc_cur_bank), a

        ld      b, 8                    ; row count
.row_loop:
        push    bc                      ; save row counter
        ld      hl, (putc_src)
        ld      a, (hl)
        inc     hl
        ld      (putc_src), hl
        ld      (putc_row_bits), a

        ; Render 8 pixels at (putc_x_cur..+7, putc_y_screen).
        ld      hl, (putc_x_in)         ; reset x to the glyph's left edge
        ld      (putc_x_cur), hl

        ld      b, 8                    ; column count within row
.col_loop:
        ; If MSB of putc_row_bits is set, plot the pixel.
        ld      a, (putc_row_bits)
        rlca
        ld      (putc_row_bits), a
        jr      nc, .skip_pixel

        ; Plot at (putc_x_cur, putc_y_screen) in putc_colour.
        ld      hl, (putc_x_cur)
        ld      a, h
        ld      d, l
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d
        srl     a
        rr      d                       ; D = x >> 6 (target bank offset)

        ld      a, d
        add     a, LAYER2_BASE_BANK
        ld      d, a
        ld      a, (putc_cur_bank)
        cp      d
        jr      z, .same_bank
        ld      a, d
        ld      (putc_cur_bank), a
        push    bc                      ; preserve col counter (B); page
        call    page_layer2_bank        ; clobbers BC
        pop     bc
.same_bank:
        ld      hl, (putc_x_cur)
        ld      a, l
        and     $3F
        ld      h, a
        ld      a, (putc_y_screen)
        ld      l, a
        ld      a, (putc_colour)
        ld      (hl), a

.skip_pixel:
        ; Bump x by 1.
        ld      hl, (putc_x_cur)
        inc     hl
        ld      (putc_x_cur), hl

        djnz    .col_loop

        ; Next row: bump y_screen.
        ld      a, (putc_y_screen)
        inc     a
        ld      (putc_y_screen), a

        pop     bc                      ; restore row counter
        djnz    .row_loop
        ret

putc_src:       defw    0
putc_x_in:      defw    0
putc_x_cur:     defw    0
putc_y_screen:  defb    0
putc_colour:    defb    0
putc_cur_bank:  defb    0
putc_row_bits:  defb    0

;----------------------------------------------------------------------------
; platform_check_key
;
; Non-blocking full-keyboard scan. Returns the ASCII code of the first
; pressed key in A, or 0 if no key is pressed.
;
; The Spectrum keyboard is an 8x5 matrix: reading port $xxFE returns the
; half-row selected by the high byte (one bit clear in 8..15). Each of
; the five low bits = one key, 0 = pressed. We loop over the 8 half-rows
; and translate the (row, bit) of the first pressed key to ASCII via
; key_table.
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

platform_check_key:
        ld      hl, key_table          ; 40 ASCII bytes, row-major
        ld      d, $FE                  ; port high byte: rotate left each row
        ld      e, 8                    ; row counter

.row_loop:
        ld      b, d
        ld      c, $FE
        in      a, (c)                  ; read 5 keys for this half-row

        ; Check 5 bits low-to-high. If any is 0, return key_table[row*5+bit].
        ld      b, 5
.bit_loop:
        rra                             ; bit 0 -> carry, A >>= 1
        jr      nc, .pressed
        inc     hl
        djnz    .bit_loop

        jr      .next_row

.pressed:
        ld      a, (hl)                 ; ASCII of pressed key
        ret

.next_row:
        ; Rotate D left so the next read selects the next half-row.
        ld      a, d
        rlca
        ld      d, a
        dec     e
        jr      nz, .row_loop

        ; No key pressed.
        xor     a
        ret

;----------------------------------------------------------------------------
; key_table - 8 half-rows * 5 keys each, ASCII for the pressed key.
;
; Order matches the half-row select bits low-to-high (so port $FEFE is
; first, $7FFE last). Within a row, bit 0 first.
;
; Caps-shift, symbol-shift and ENTER have no good ASCII; we use $00 for
; caps/symbol and CR ($0D) for ENTER. SPACE is $20.
;----------------------------------------------------------------------------

key_table:
        ; $FEFE: CAPS, Z, X, C, V
        defb    $00, 'Z', 'X', 'C', 'V'
        ; $FDFE: A, S, D, F, G
        defb    'A', 'S', 'D', 'F', 'G'
        ; $FBFE: Q, W, E, R, T
        defb    'Q', 'W', 'E', 'R', 'T'
        ; $F7FE: 1, 2, 3, 4, 5
        defb    '1', '2', '3', '4', '5'
        ; $EFFE: 0, 9, 8, 7, 6
        defb    '0', '9', '8', '7', '6'
        ; $DFFE: P, O, I, U, Y
        defb    'P', 'O', 'I', 'U', 'Y'
        ; $BFFE: ENTER, L, K, J, H
        defb    $0D, 'L', 'K', 'J', 'H'
        ; $7FFE: SPACE, SYMBOL, M, N, B
        defb    ' ', $00, 'M', 'N', 'B'

;----------------------------------------------------------------------------
; platform_poll_input
;
; Non-blocking game-input scan. Returns one of:
;   DIR_UP / DIR_DOWN / DIR_LEFT / DIR_RIGHT - direction key
;   INPUT_PAUSE                              - P or SPACE
;   INPUT_QUIT                               - Q
;   DIR_NONE (= 0)                           - nothing pressed
;
; Mirrors src/x16/system/platform.asm:platform_poll_input. The X16
; supports both cursor keys and WASD; on the Next we only check the
; matrix half-rows for WASD + P + space + Q (cursor keys live in the
; enhanced-keyboard space which we don't read yet).
;
; Reads the keyboard matrix directly rather than reusing
; platform_check_key, because the menu's full-keyboard scan returns the
; first key found in a fixed order, which makes diagonal presses
; (e.g. SPACE while moving) unreliable for game input. This routine
; checks priority-ordered keys explicitly.
;
; Clobbers: A, BC.
;----------------------------------------------------------------------------

platform_poll_input:
        ; Direction keys first.
        ld      bc, $FBFE               ; Q,W,E,R,T
        in      a, (c)
        bit     1, a                    ; W
        jr      z, .up

        ld      bc, $FDFE               ; A,S,D,F,G
        in      a, (c)
        bit     1, a                    ; S
        jr      z, .down
        bit     0, a                    ; A
        jr      z, .left
        bit     2, a                    ; D
        jr      z, .right

        ; Pause: P or SPACE.
        ld      bc, $DFFE               ; P,O,I,U,Y
        in      a, (c)
        bit     0, a                    ; P
        jr      z, .pause

        ld      bc, $7FFE               ; SPACE,SYM,M,N,B
        in      a, (c)
        bit     0, a                    ; SPACE
        jr      z, .pause

        ; Quit: Q.
        ld      bc, $FBFE
        in      a, (c)
        bit     0, a                    ; Q
        jr      z, .quit

        xor     a                       ; DIR_NONE
        ret

.up:    ld      a, DIR_UP
        ret
.down:  ld      a, DIR_DOWN
        ret
.left:  ld      a, DIR_LEFT
        ret
.right: ld      a, DIR_RIGHT
        ret
.pause: ld      a, INPUT_PAUSE
        ret
.quit:  ld      a, INPUT_QUIT
        ret

;----------------------------------------------------------------------------
; platform_random
;
; Returns a pseudo-random byte in A. Uses a 16-bit Galois LFSR (poly
; $002D) seeded at boot to a non-zero value. Cheap, reasonably random
; for visual purposes (food spawn, flower placement); not for crypto.
;
; Clobbers: A, HL.
;----------------------------------------------------------------------------

platform_random:
        ld      hl, (rand_state)
        ld      a, h
        rra
        ld      a, l
        rra
        xor     h
        ld      h, a
        ld      a, l
        rra
        ld      a, h
        rra
        xor     l
        ld      l, a
        xor     h
        ld      h, a
        ld      (rand_state), hl
        ld      a, l
        ret

rand_state:     defw    $A55A           ; non-zero seed

;----------------------------------------------------------------------------
; platform_getkey
;
; Blocking: spin until a key is pressed, return ASCII in A. Used by
; "press any key" prompts.
;
; Calls platform_wait_vsync between scans to throttle to one read per
; frame (avoiding a spin that just hammers the keyboard ports).
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

platform_getkey:
        ; Drain any key currently held so we wait for a fresh press.
.drain:
        call    platform_check_key
        or      a
        jr      nz, .drain

.wait:
        call    platform_wait_vsync
        call    platform_check_key
        or      a
        jr      z, .wait
        ret

;----------------------------------------------------------------------------
; platform_wait_vsync
;
; Spin until the display's active scan line counter rolls past the bottom
; of the visible area into vsync. Equivalent to waiting for the next
; frame to start.
;
; We poll NEXTREG $1E/$1F (active video line). Line 0..255 is visible,
; lines past the visible area are vblank. The exact threshold depends on
; mode but >= 256 (i.e. NR $1E bit 0 set) is reliably in vblank.
;
; Two-phase wait: first wait for vblank (line MSB=1), then wait for
; line 0 again, so back-to-back calls don't return immediately within
; the same frame.
;
; Clobbers: A, BC.
;----------------------------------------------------------------------------

platform_wait_vsync:
.wait_vblank:
        ld      bc, NEXTREG_SELECT
        ld      a, NR_VIDEO_LINE_MSB
        out     (c), a
        ld      bc, NEXTREG_VALUE
        in      a, (c)
        bit     0, a
        jr      z, .wait_vblank         ; not in vblank yet -> spin

.wait_visible:
        ld      bc, NEXTREG_SELECT
        ld      a, NR_VIDEO_LINE_MSB
        out     (c), a
        ld      bc, NEXTREG_VALUE
        in      a, (c)
        bit     0, a
        jr      nz, .wait_visible       ; still in vblank -> spin
        ret

;----------------------------------------------------------------------------
; font_buffer
;
; 768 bytes (96 glyphs * 8 rows) populated at boot from the 48K ROM's
; ASCII font at $3D00..$3FFF. Glyph N (ASCII 32+N) starts at
; font_buffer + N*8. Each row byte is MSB-leftmost.
;----------------------------------------------------------------------------

font_buffer:    defs    768

;----------------------------------------------------------------------------
