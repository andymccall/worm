; ***************************************************************************
;
; platform.asm - PC Engine hardware abstraction layer
;
; Mirrors the role of src/x16/system/platform.asm and src/neo/system/
; platform.asm but the PCE has different drawing primitives (tile-based
; BAT instead of linear bitmap), so the HAL routines look very different.
; What's shared is the *contract*: the engine and app layers don't touch
; the hardware directly, only the helpers in this file do.
;
; This file owns:
;   * Tile uploads (upload_gfx_tiles, build_shifted_font + the font drop)
;   * The green border painter
;   * The grid->BAT address helper used by every drawing call
;   * All graphics tile bitmaps (tile_gfx)
;   * All 4 palettes (my_palette)
;   * The ASCII font binary (incbin'd from HuC's elmer/font directory)
;   * BSS for the shifted-font staging buffer + ZP scratch the HAL uses
;
; ***************************************************************************

        .code

; ===========================================================================
;
; upload_gfx_tiles - Walk tile_gfx (8 bytes per tile, NUM_GFX_TILES tiles)
; and program each into VRAM at slot CHR_0x10 + n. Each source byte is the
; bp1/bp2 mask for one row; bp0 and bp3 are always zero (every tile is
; pure ink-on-transparent in palette slot 6).
;
; PCE tile = 32 bytes total: 8x bp0/bp1 paired writes, then 8x bp2/bp3.
;
; ===========================================================================

upload_gfx_tiles:
        ; di = CHR_0x10 * 16  (VRAM address of first tile)
        stz     <_di + 0
        lda     #>(CHR_0x10 * 16)
        sta     <_di + 1
        call    vdc_di_to_mawr

        ; Walk the tile_gfx table. Y indexes the byte within the table
        ; (0..NUM_GFX_TILES*8-1). Each tile gets two passes:
        ;   pass A: 8x writes of (bp0=$00, bp1=mask)  -> VDC_DL/VDC_DH
        ;   pass B: 8x writes of (bp2=mask, bp3=$00)  -> VDC_DL/VDC_DH
        ; We save the per-tile starting Y so we can restart for pass B.
        cly
        stz     <gfx_tile_idx
.next_tile:
        sty     <gfx_tile_y0            ; save Y for pass B

        ; Pass A: bp0/bp1 -> 8 paired writes.
        ldx     #8
.pass_a:
        stz     VDC_DL                  ; bp0 = 0
        lda     tile_gfx, y
        sta     VDC_DH                  ; bp1 = mask
        iny
        dex
        bne     .pass_a

        ; Pass B: bp2/bp3 -> 8 paired writes, restarting from saved Y.
        ldy     <gfx_tile_y0
        ldx     #8
.pass_b:
        lda     tile_gfx, y
        sta     VDC_DL                  ; bp2 = mask
        stz     VDC_DH                  ; bp3 = 0
        iny
        dex
        bne     .pass_b

        ; Advance to next tile if any remain.
        inc     <gfx_tile_idx
        lda     <gfx_tile_idx
        cmp     #NUM_GFX_TILES
        bcc     .next_tile
        rts


; ===========================================================================
;
; paint_border - Draw the green border tiles around the playfield. Top
; edge sits at row BORDER_TOP_ROW (just under the status bar), bottom at
; BORDER_BOT_ROW, with vertical edges at BORDER_LEFT_COL / BORDER_RIGHT_COL.
;
; ===========================================================================

paint_border:
        lda     #(PAL_GREEN << 4)
        sta     <bat_palette_hi

        ; --- Top edge: TL corner, then HORIZ across, then TR corner -------
        lda     #<(BORDER_TOP_ROW * BAT_LINE + BORDER_LEFT_COL)
        sta     <_di + 0
        lda     #>(BORDER_TOP_ROW * BAT_LINE + BORDER_LEFT_COL)
        sta     <_di + 1
        call    vdc_di_to_mawr

        lda     #<CHR_BORDER_TL
        sta     VDC_DL
        lda     #(PAL_GREEN << 4)
        sta     VDC_DH

        ldx     #(BORDER_RIGHT_COL - BORDER_LEFT_COL - 1)  ; cells between corners
.top_loop:
        lda     #<CHR_BORDER_H_TOP
        sta     VDC_DL
        lda     #(PAL_GREEN << 4)
        sta     VDC_DH
        dex
        bne     .top_loop

        lda     #<CHR_BORDER_TR
        sta     VDC_DL
        lda     #(PAL_GREEN << 4)
        sta     VDC_DH

        ; --- Bottom edge: BL corner, HORIZ_BOT across, BR corner ----------
        lda     #<(BORDER_BOT_ROW * BAT_LINE + BORDER_LEFT_COL)
        sta     <_di + 0
        lda     #>(BORDER_BOT_ROW * BAT_LINE + BORDER_LEFT_COL)
        sta     <_di + 1
        call    vdc_di_to_mawr

        lda     #<CHR_BORDER_BL
        sta     VDC_DL
        lda     #(PAL_GREEN << 4)
        sta     VDC_DH

        ldx     #(BORDER_RIGHT_COL - BORDER_LEFT_COL - 1)
.bot_loop:
        lda     #<CHR_BORDER_H_BOT
        sta     VDC_DL
        lda     #(PAL_GREEN << 4)
        sta     VDC_DH
        dex
        bne     .bot_loop

        lda     #<CHR_BORDER_BR
        sta     VDC_DL
        lda     #(PAL_GREEN << 4)
        sta     VDC_DH

        ; --- Vertical edges: walk the rows between top and bottom ---------
        ;
        ; The MAWR auto-increments by 1 (next BAT cell to the right), but
        ; we want to step down a column. Re-set MAWR for each row, write a
        ; VERT tile on the left and another on the right.
        ldx     #(BORDER_TOP_ROW + 1)
.vert_loop:
        ; Left edge cell at (row=X, col=BORDER_LEFT_COL).
        ; di = X * BAT_LINE + BORDER_LEFT_COL  =  X << 6 + 0
        stx     <_di + 0
        stz     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        ; (BORDER_LEFT_COL is 0, so no add needed)
        phx
        call    vdc_di_to_mawr
        plx
        lda     #<CHR_BORDER_V_LEFT
        sta     VDC_DL
        lda     #(PAL_GREEN << 4)
        sta     VDC_DH

        ; Right edge cell at (row=X, col=BORDER_RIGHT_COL).
        stx     <_di + 0
        stz     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        clc
        lda     <_di + 0
        adc     #BORDER_RIGHT_COL
        sta     <_di + 0
        lda     <_di + 1
        adc     #0
        sta     <_di + 1
        phx
        call    vdc_di_to_mawr
        plx
        lda     #<CHR_BORDER_V_RIGHT
        sta     VDC_DL
        lda     #(PAL_GREEN << 4)
        sta     VDC_DH

        inx
        cpx     #BORDER_BOT_ROW
        bcc     .vert_loop

        ; --- Divider at BORDER_DIV_ROW: VR, HORIZ across, VL --------------
        lda     #<(BORDER_DIV_ROW * BAT_LINE + BORDER_LEFT_COL)
        sta     <_di + 0
        lda     #>(BORDER_DIV_ROW * BAT_LINE + BORDER_LEFT_COL)
        sta     <_di + 1
        call    vdc_di_to_mawr

        lda     #<CHR_DIV_VR
        sta     VDC_DL
        lda     #(PAL_GREEN << 4)
        sta     VDC_DH

        ldx     #(BORDER_RIGHT_COL - BORDER_LEFT_COL - 1)
.div_loop:
        lda     #<CHR_DIV_H
        sta     VDC_DL
        lda     #(PAL_GREEN << 4)
        sta     VDC_DH
        dex
        bne     .div_loop

        lda     #<CHR_DIV_VL
        sta     VDC_DL
        lda     #(PAL_GREEN << 4)
        sta     VDC_DH
        rts


; ===========================================================================
;
; build_shifted_font - One-shot at boot. Reads the original ASCII font
; (my_font + 128, skipping the 16 graphics-tile glyphs) and writes a
; 768-byte buffer where each glyph has its rows shifted down 2 pixels:
;   out[0..1] = 0
;   out[2..7] = in[0..5]
; Rows 6 and 7 of the source are dropped. Row 7 is universally blank;
; row 6 holds descender/underscore content for 21 glyphs which gets
; clipped, but the trade-off is good visual centring of all the regular
; glyphs in their cells.
;
; ===========================================================================

build_shifted_font:
        ; Source pointer = my_font + 128 (after the 16 graphics tiles).
        lda     #<(my_font + 128)
        sta     <font_src + 0
        lda     #>(my_font + 128)
        sta     <font_src + 1

        ; Destination pointer = shifted_font.
        lda     #<shifted_font
        sta     <font_dst + 0
        lda     #>shifted_font
        sta     <font_dst + 1

        lda     #96
        sta     <font_glyph_count

.glyph_loop:
        ; Write the two leading zero rows.
        cly
        lda     #0
        sta     [font_dst], y
        iny
        sta     [font_dst], y

        ; Copy 6 source rows to output rows 2..7.
        ldx     #0
.row_loop:
        iny                             ; advance dst index (2..7)
        phy
        txa
        tay                             ; src index (0..5)
        lda     [font_src], y
        ply
        sta     [font_dst], y
        inx
        cpx     #6
        bcc     .row_loop

        ; Advance src by 8.
        clc
        lda     <font_src + 0
        adc     #8
        sta     <font_src + 0
        lda     <font_src + 1
        adc     #0
        sta     <font_src + 1

        ; Advance dst by 8.
        clc
        lda     <font_dst + 0
        adc     #8
        sta     <font_dst + 0
        lda     <font_dst + 1
        adc     #0
        sta     <font_dst + 1

        dec     <font_glyph_count
        bne     .glyph_loop
        rts


; ===========================================================================
;
; bat_addr_for_cell - Program MAWR for the BAT cell that maps to grid
; position (cell_x, cell_y). The grid (0,0) is at BAT (GRID_BAT_COL,
; GRID_BAT_ROW); each grid step is 1 BAT cell.
;
; In:    <cell_x, <cell_y
; Out:   MAWR programmed; trashes A
;
; ===========================================================================

bat_addr_for_cell:
        ; bat_row = GRID_BAT_ROW + cell_y
        ; di = bat_row * 64 + (GRID_BAT_COL + cell_x)
        clc
        lda     <cell_y
        adc     #GRID_BAT_ROW
        sta     <_di + 0
        stz     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1
        asl     <_di + 0
        rol     <_di + 1

        clc
        lda     <_di + 0
        adc     <cell_x
        sta     <_di + 0
        lda     <_di + 1
        adc     #0
        sta     <_di + 1

        clc
        lda     <_di + 0
        adc     #GRID_BAT_COL
        sta     <_di + 0
        lda     <_di + 1
        adc     #0
        sta     <_di + 1

        jmp     vdc_di_to_mawr


; ===========================================================================
; PC Engine PSG sound
; ===========================================================================
;
; The HuC6280's built-in PSG has 6 channels. We use channel 0 for SFX -
; programmed once at boot to play a square-ish waveform, then driven by
; sound.asm's frame sequencer which queues notes via platform_play_note.
;
; PSG register summary (selected via $0800):
;   $0800  channel select (0..5)
;   $0801  master balance (LR nibbles)
;   $0802  fine freq (low 8 bits of 12-bit divider)
;   $0803  rough freq (high 4 bits of divider)
;   $0804  enable + DDA + 5-bit volume (bit 7 = channel on)
;   $0805  channel balance (LR nibbles)
;   $0806  waveform sample / DDA data
;
; Frequency: divider = 3580000 / (32 * Hz) = 111875 / Hz, fits in 12 bits
; for the worm's note range (C3..A5).

PSG_CH_SEL      = $0800
PSG_MASTER_BAL  = $0801
PSG_FREQ_LO     = $0802
PSG_FREQ_HI     = $0803
PSG_CTRL        = $0804
PSG_BAL         = $0805
PSG_DATA        = $0806


; ===========================================================================
;
; psg_init - One-shot at boot. Selects channel 0, loads a 32-sample
; square waveform into its buffer, sets master + channel balances. The
; channel is left disabled - platform_play_note enables it on demand.
;
; ===========================================================================

psg_init:
        ; Master volume: full both channels.
        lda     #$FF
        sta     PSG_MASTER_BAL

        ; Select channel 0.
        stz     PSG_CH_SEL

        ; Reset waveform write index: ch off + DDA on briefly, then DDA off
        ; so writes to PSG_DATA go to the waveform buffer.
        lda     #%01000000              ; ch off, DDA on -> resets index
        sta     PSG_CTRL
        stz     PSG_CTRL                ; ch off, DDA off -> waveform write

        ; Per-channel balance: full both.
        lda     #$FF
        sta     PSG_BAL

        ; Write 32 samples of the waveform.
        ldx     #0
.wave_loop:
        lda     psg_waveform, x
        sta     PSG_DATA
        inx
        cpx     #32
        bcc     .wave_loop
        rts


; ===========================================================================
;
; platform_play_note - Start a note on PSG channel 0.
;
; In:    X = freq lo, Y = freq hi (Hz, 16-bit)
;        A = volume 0..63 (we mask down to 5 bits = PCE volume range)
;
; The note plays until platform_stop_sound is called or another
; platform_play_note overrides it. The 12-bit PSG divider is computed
; on-the-fly via repeated subtraction: divider = 111875 / freq.
; Approximately 1024 iterations max, ~30 cycles each = ~3.6ms at 7.16MHz.
; Acceptable since we only call it on note transitions (a handful per
; second) and not from inside vblank handlers.
;
; ===========================================================================

platform_play_note:
        ; Save volume.
        sta     <psg_vol

        ; Stash freq into psg_freq.
        stx     <psg_freq + 0
        sty     <psg_freq + 1

        ; Initialise 24-bit accumulator to 111875 = $01B543.
        lda     #<111875
        sta     <psg_acc + 0
        lda     #>111875
        sta     <psg_acc + 1
        lda     #(111875 >> 16)         ; high byte = 1
        sta     <psg_acc + 2

        ; Initialise divider to 0.
        stz     <psg_div + 0
        stz     <psg_div + 1

.div_loop:
        ; If acc < freq, we're done. acc is 24-bit; check high byte first
        ; (any non-zero high byte means definitely >= 16-bit freq).
        lda     <psg_acc + 2
        bne     .can_subtract
        lda     <psg_acc + 1
        cmp     <psg_freq + 1
        bcc     .div_done
        bne     .can_subtract
        lda     <psg_acc + 0
        cmp     <psg_freq + 0
        bcc     .div_done

.can_subtract:
        ; acc -= freq (16-bit), borrow into high byte of acc.
        sec
        lda     <psg_acc + 0
        sbc     <psg_freq + 0
        sta     <psg_acc + 0
        lda     <psg_acc + 1
        sbc     <psg_freq + 1
        sta     <psg_acc + 1
        lda     <psg_acc + 2
        sbc     #0
        sta     <psg_acc + 2

        ; divider++
        inc     <psg_div + 0
        bne     .div_loop
        inc     <psg_div + 1
        bra     .div_loop

.div_done:
        ; Program PSG channel 0.
        stz     PSG_CH_SEL              ; select channel 0
        lda     <psg_div + 0
        sta     PSG_FREQ_LO
        lda     <psg_div + 1
        and     #$0F                    ; high byte is 4 bits in PSG
        sta     PSG_FREQ_HI
        lda     #$FF
        sta     PSG_BAL                 ; both channels full

        ; Channel on (bit 7) + 5-bit volume. The X16 sequencer passes
        ; a 6-bit "VERA PSG" volume; we just take the low 5 bits.
        lda     <psg_vol
        and     #$1F
        ora     #$80
        sta     PSG_CTRL
        rts


; ===========================================================================
;
; platform_stop_sound - Silence PSG channel 0 (turns the channel off).
;
; ===========================================================================

platform_stop_sound:
        stz     PSG_CH_SEL              ; select channel 0
        stz     PSG_CTRL                ; ch off, DDA off, vol 0
        rts


; ===========================================================================
; Graphics tile bitmaps + palettes + font binary
; ===========================================================================

        .data

; --- Graphics tile bitmaps -----------------------------------------------
;
; 8 bytes per tile = 1 byte per row of the 8x8 cell. Each byte is the bp1
; (and identical bp2) mask: bit 7 = leftmost pixel, bit 0 = rightmost.
; Pixel set => colour 6 (ink); pixel clear => colour 0 (transparent).

tile_gfx:
        ; +0  CHR_BLOCK - rounded worm-segment, 8x8 with 4 corner pixels
        ; chopped off so adjacent blocks read as soft-edged segments.
        db      $7E, $FF, $FF, $FF, $FF, $FF, $FF, $7E

        ; +1  CHR_BORDER_H_TOP - top horizontal edge, line at cell-row 6.
        db      $00, $00, $00, $00, $00, $00, $FF, $00

        ; +2  CHR_BORDER_H_BOT - bottom horizontal edge, line at cell-row 1.
        db      $00, $FF, $00, $00, $00, $00, $00, $00

        ; +3  CHR_BORDER_V_LEFT - left vertical edge, line at cell-col 6
        ; (so the gap to the playfield interior is just 2 pixels).
        ; col 6 = bit 1 = $02.
        db      $02, $02, $02, $02, $02, $02, $02, $02

        ; +4  CHR_BORDER_V_RIGHT - right vertical edge, line at cell-col 1
        ; (mirror of V_LEFT). col 1 = bit 6 = $40.
        db      $40, $40, $40, $40, $40, $40, $40, $40

        ; +5  CHR_BORDER_TL - top-left corner: top edge (row 6) meets left
        ; edge (col 6) at (row 6, col 6). Horiz line goes RIGHT from the
        ; corner (cols 6..7 on row 6); vert line goes DOWN (col 6 on rows
        ; 6..7).
        ;   row 6:  . . . . . . X X     $03
        ;   row 7:  . . . . . . X .     $02
        db      $00, $00, $00, $00, $00, $00, $03, $02

        ; +6  CHR_BORDER_TR - top-right corner: top edge (row 6) meets
        ; right edge (col 1) at (row 6, col 1). Horiz line LEFT (cols 0..1
        ; on row 6); vert line DOWN (col 1 on rows 6..7).
        ;   row 6:  X X . . . . . .     $C0
        ;   row 7:  . X . . . . . .     $40
        db      $00, $00, $00, $00, $00, $00, $C0, $40

        ; +7  CHR_BORDER_BL - bottom-left corner: bottom edge (row 1) meets
        ; left edge (col 6). Vert line UP (col 6 on rows 0..1); horiz line
        ; RIGHT (cols 6..7 on row 1).
        ;   row 0:  . . . . . . X .     $02
        ;   row 1:  . . . . . . X X     $03
        db      $02, $03, $00, $00, $00, $00, $00, $00

        ; +8  CHR_BORDER_BR - bottom-right corner: bottom edge (row 1) meets
        ; right edge (col 1). Vert line UP (col 1 on rows 0..1); horiz line
        ; LEFT (cols 0..1 on row 1).
        ;   row 0:  . X . . . . . .     $40
        ;   row 1:  X X . . . . . .     $C0
        db      $40, $C0, $00, $00, $00, $00, $00, $00

        ; +9  CHR_DIV_H - horizontal divider line at cell-row 6. Pulled
        ; down to the bottom of its BAT row so the gap between divider
        ; and playfield matches the 2-px inset on the other three sides.
        ; The trade-off: FOOD/LIVES now has more breathing room below it
        ; than above, but that's preferable to a wide black band between
        ; divider and worm.
        db      $00, $00, $00, $00, $00, $00, $FF, $00

        ; +10 CHR_DIV_VR - divider's left T-junction. Vert line at col 6
        ; (matches V_LEFT) full height; horiz at row 6 going right (cols
        ; 6..7). row 6 = bits 0,1 plus bit 1 of vertical = $03.
        ;   row 0..5: . . . . . . X .   $02
        ;   row 6:    . . . . . . X X   $03
        ;   row 7:    . . . . . . X .   $02
        db      $02, $02, $02, $02, $02, $02, $03, $02

        ; +11 CHR_DIV_VL - divider's right T-junction. Vert line at col 1
        ; full height; horiz at row 6 going left (cols 0..1) = $C0.
        ;   row 0..5: . X . . . . . .   $40
        ;   row 6:    X X . . . . . .   $C0
        ;   row 7:    . X . . . . . .   $40
        db      $40, $40, $40, $40, $40, $40, $C0, $40

        ; +12 CHR_HEART - 7x6 heart, vertically centred in the 8x8 cell.
        ; Built from the X16/Neo draw_heart layout (rect-by-rect):
        ;   row 1:  . X X . X X .   bumps                 $66
        ;   row 2:  X X X X X X X   wide body              $FE
        ;   row 3:  X X X X X X X   wide body              $FE
        ;   row 4:  . X X X X X .   taper 1                $7C
        ;   row 5:  . . X X X . .   taper 2                $38
        ;   row 6:  . . . X . . .   point                  $10
        db      $00, $66, $FE, $FE, $7C, $38, $10, $00

        ; +13 CHR_FOOD - 4-leaf clover. Built from src/x16/engine/food.asm
        ; draw_food: top + bottom + left + right rectangles overlapping at
        ; the centre band (rows 2 and 5).
        ;   row 0:  . . X X X X . .  top-leaf only          $3C
        ;   row 1:  . . X X X X . .                         $3C
        ;   row 2:  X X X X X X X X  top + left + right     $FF
        ;   row 3:  X X X . . X X X  left + right           $E7
        ;   row 4:  X X X . . X X X  left + right           $E7
        ;   row 5:  X X X X X X X X  bot + left + right     $FF
        ;   row 6:  . . X X X X . .  bot-leaf only          $3C
        ;   row 7:  . . X X X X . .                         $3C
        db      $3C, $3C, $FF, $E7, $E7, $FF, $3C, $3C

        ; +14 CHR_SPIDER - side-view spider (head facing right). Built
        ; from src/x16/engine/spider.asm draw_spider_shape (head + body +
        ; abdomen + 6 legs + 2 feet). Painted in PAL_GRAY normally, in
        ; PAL_YELLOW when spider_vulnerable is set.
        ;   row 0:  . . . . . . . .                         $00
        ;   row 1:  . . X X X X . .  body                   $3C
        ;   row 2:  X X X X X X X X  head + body + abdomen  $FF
        ;   row 3:  X X X X X X X X  head + body + abdomen  $FF
        ;   row 4:  . . X X X X . .  body                   $3C
        ;   row 5:  . X X X X X X .  6 legs                 $7E
        ;   row 6:  X . . . . . . X  front + rear feet      $81
        ;   row 7:  . . . . . . . .                         $00
        db      $00, $3C, $FF, $FF, $3C, $7E, $81, $00


        align   2
my_palette:
        ; PCE colour format is %gggrrrbbb (9-bit GRB).
        ;
        ; dropfnt8x8_vdc with _al=$FF / _ah=$00 puts the font on bitplane 2,
        ; so glyph pixels fall in slots:
        ;   4 = background inside glyph cell
        ;   5 = drop-shadow ink
        ;   6 = glyph ink (the visible letter colour)
        ;   7 = unused
        ; The bitmap title painter uses our solid-block tile in slot 6 and
        ; "transparent" corner pixels in slot 0; slot 0 is also the screen
        ; clear colour so it must be black across all palettes for a clean
        ; field. Slot 4 is also black so glyph cells blend with the field.
        ;
        ; Palette 0 - GREEN (WORM title, font as green text, status bar).
        dw      $0000,$0000,$0000,$0000,$0000,$0040,$00C0,$0000
        dw      $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

        ; Palette 1 - BLUE (menu item text). Format is %gggrrrbbb.
        ;   $0003  dim blue shadow  (slot 5)  g=0, r=0, b=3
        ;   $0007  bright blue ink  (slot 6)  g=0, r=0, b=7
        dw      $0000,$0000,$0000,$0000,$0000,$0003,$0007,$0000
        dw      $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

        ; Palette 2 - YELLOW (cursor block + accent). Format is %gggrrrbbb.
        ;   $00C8  dark amber shadow (slot 5) g=6, r=1, b=0
        ;   $01F8  bright yellow     (slot 6) g=7, r=7, b=0
        dw      $0000,$0000,$0000,$0000,$0000,$00C8,$01F8,$0000
        dw      $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

        ; Palette 3 - RED (LIVES hearts). Format is %gggrrrbbb.
        ;   $0010  dark red shadow   (slot 5) g=0, r=2, b=0
        ;   $0038  bright red ink    (slot 6) g=0, r=7, b=0
        dw      $0000,$0000,$0000,$0000,$0000,$0010,$0038,$0000
        dw      $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000

        ; Palette 4 - GRAY (normal/non-vulnerable spiders).
        ;   $0092  dim grey shadow   (slot 5) g=4, r=4, b=2
        ;   $0124  light grey ink    (slot 6) g=5, r=5, b=4
        dw      $0000,$0000,$0000,$0000,$0000,$0092,$0124,$0000
        dw      $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000


my_font:
        incbin  "font8x8-ascii-bold-short.dat"


; PSG waveform: 32 5-bit samples for a square wave (16 zero, 16 max).
; Loaded into channel 0's wave buffer once at boot. Gives the blippy beep
; that the X16/Neo's pulse-wave VERA PSG produces - simple but matches
; the sound style of the originals.
psg_waveform:
        db      $00, $00, $00, $00, $00, $00, $00, $00
        db      $00, $00, $00, $00, $00, $00, $00, $00
        db      $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F
        db      $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F


; ===========================================================================
; Zero-page scratch + palette nibble cache
; ===========================================================================

        .zp

bat_palette_hi:   ds 1     ; palette nibble (palette<<4) for paint_string

gfx_tile_idx:     ds 1     ; tile counter inside upload_gfx_tiles
gfx_tile_y0:      ds 1     ; saved Y for pass B inside upload_gfx_tiles

; build_shifted_font scratch.
font_src:         ds 2     ; pointer into my_font (advances 8 bytes/glyph)
font_dst:         ds 2     ; pointer into shifted_font
font_glyph_count: ds 1     ; remaining glyphs to process

; platform_play_note scratch. The 24-bit accumulator holds 111875
; initially; we subtract psg_freq from it and count the iterations.
psg_freq:         ds 2     ; current note frequency in Hz
psg_acc:          ds 3     ; 24-bit running accumulator for the divide
psg_div:          ds 2     ; result: 12-bit PSG divider (low byte + high nybble)
psg_vol:          ds 1     ; latched volume to apply to PSG_CTRL


; ===========================================================================
; BSS: shifted-font staging buffer
; ===========================================================================

        .bss

; The "bold-short" 8x8 font uses rows 0..5 for most glyphs; a handful
; (descenders, underscore, brackets, $) extend into row 6 too. We rebuild
; the font at boot with each glyph shifted down 2 pixels (rows 0..1 =
; blank, rows 2..7 = original rows 0..5) so text sits properly centred
; in the band between top edge and divider. Row 6 is dropped, which
; clips the descender bottoms / underscore on 21 glyphs - acceptable
; trade for the tighter visual.
;
; 96 glyphs * 8 bytes = 768 bytes. Used once at boot then idle.
shifted_font:     ds 96 * 8
