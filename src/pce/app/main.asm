; ***************************************************************************
;
; main.asm
;
; Worm - PC Engine / TurboGrafx-16 port - entry point
;
; PCEAS has no linker, so the whole project gets assembled as one
; translation unit. main.asm is the entry: it pulls in CORE library
; helpers, project equates, the HAL, the engine, the screens, then
; defines bare_main (the post-CORE entry called once IRQs and the kernel
; are running) and the top-level dispatcher loop. Mirrors the role of
; src/x16/app/main.asm and src/neo/app/main.asm.
;
; The split mirrors the X16/Neo trees:
;   src/pce/system/   platform-specific HAL + project equates
;   src/pce/engine/   portable game systems
;   src/pce/app/      top-level entry + per-screen modules
;
; PCE rendering is fundamentally different from X16/Neo (tile-based BAT
; instead of a linear bitmap), so the routines look different inside
; even when the names match - but the names, ownership, and call
; conventions are identical for ease of cross-reference.
;
; Built on John Brandwood's CORE(not TM) library which ships with HuC's
; PCEAS examples (Boost-licensed).
;
; ***************************************************************************

        ; Project equates (VRAM layout, palettes, tile slots, grid, menu
        ; layout, overlay timings, etc).
        include "wm_equates.inc"

        ; CORE startup. Hands control to bare_main once IRQs and the IRQ
        ; kernel are ready.
        include "bare-startup.asm"

        .list
        .mlist

        ; CORE helpers we use.
        include "common.asm"            ; Common helpers + zp pseudo-regs.
        include "vdc.asm"               ; VDC init, MAWR/VWR helpers.
        include "font.asm"              ; dropfnt8x8_vdc.
        include "joypad.asm"            ; Reads pad state every vsync.

        ; Worm sources. Order is purely organisational (PCEAS is multi-pass
        ; so forward references work either way), but it matches the X16/Neo
        ; bottom-up convention: HAL first, then engine, then app. PCE_INCLUDE
        ; (set by the Makefile) covers src/pce/{app,engine,system}.
        include "platform.asm"          ; system/

        include "wm_text.asm"           ; engine/
        include "wm_drawing.asm"
        include "worm.asm"
        include "food.asm"
        include "status_bar.asm"
        include "game.asm"

        include "menu.asm"              ; app/
        include "about.asm"
        include "overlays.asm"


; ***************************************************************************
;
; bare_main - Entry point. Called by CORE startup once IRQs and the IRQ
; kernel are running. Sets up VRAM (font + tiles + palettes), draws the
; static chrome (status bar + WORM title + border), brings the display
; online, and enters the dispatcher loop.
;
; Mirrors src/x16/app/main.asm:main: call show_start_screen, dispatch on
; the returned selection (1=START, 2=ABOUT, 3=DEMO), come back. PC Engine
; has no software quit so there's no exit path.
;
; ***************************************************************************

        .code

bare_main:
        call    init_256x224

        ; --- Build the shifted ASCII font + upload to VRAM -----------------
        ;
        ; The hello-world template uploads 16 graphics tiles + 96 ASCII
        ; glyphs starting at CHR_0x10. We don't want the graphics tiles
        ; (we have our own at CHR_0x10..) and we want the ASCII glyphs
        ; shifted down 2 pixels in their cells so they read as centred
        ; rather than top-aligned. Build the shifted version into the
        ; shifted_font BSS buffer then upload it directly into the ASCII
        ; tile range starting at CHR_0x20.

        call    build_shifted_font

        ; di = CHR_0x20 * 16  (VRAM address of the ASCII glyph range)
        lda     #<(CHR_0x20 * 16)
        sta     <_di + 0
        lda     #>(CHR_0x20 * 16)
        sta     <_di + 1

        lda     #$FF
        sta     <_al
        stz     <_ah

        lda     #96
        sta     <_bl

        lda     #<shifted_font
        sta     <_bp + 0
        lda     #>shifted_font
        sta     <_bp + 1
        ldy     #0                      ; bank ignored - _bp is in MPR1

        call    dropfnt8x8_vdc

        ; --- Upload our 14 graphics tiles to slots CHR_0x10..CHR_0x1D ------

        call    upload_gfx_tiles

        ; --- Upload palettes (4: green, blue, yellow, red) -----------------

        stz     <_al                    ; Start at palette 0.
        lda     #4                      ; Four palettes.
        sta     <_ah
        lda     #<my_palette
        sta     <_bp + 0
        lda     #>my_palette
        sta     <_bp + 1
        ldy     #^my_palette
        call    load_palettes
        call    xfer_palettes

        ; --- Initialise game state, draw the status bar --------------------
        ;
        ; food_count starts at 0; lives starts at MAX_LIVES (matches the
        ; X16/Neo behaviour set up by game_reset_stats via main.asm).

        stz     food_count
        lda     #MAX_LIVES
        sta     lives

        call    draw_status_bar

        ; --- Static chrome: WORM title + green border ----------------------
        ; The status bar, WORM title, and border are all repainted on
        ; demand by show_about_screen / game_run, but we lay them down once
        ; here so the first menu render after boot has them in place.

        call    paint_worm_title
        call    paint_border

        ; --- Bring the display online --------------------------------------

        call    set_dspon

        ; --- Top-level screen dispatcher -----------------------------------
        ;
        ; Mirrors src/x16/app/main.asm: call show_start_screen, dispatch
        ; on the returned selection (1=START, 2=ABOUT, 3=DEMO), come back.
        ; PC Engine has no software quit so there's no exit path - the
        ; loop runs forever.

.dispatch:
        call    show_start_screen

        cmp     #2
        beq     .do_about
        cmp     #3
        beq     .do_demo

        ; START selected -> reset stats, run a game session. After game
        ; over we come back here and the loop repaints the menu via
        ; show_start_screen.
        call    game_reset_stats
        call    game_run
        bra     .dispatch

.do_about:
        call    show_about_screen
        bra     .dispatch

.do_demo:
        ; Demo isn't scripted yet, run the same game session as START
        ; (just human-controlled). Future demo_run will replace this.
        call    game_reset_stats
        call    game_run
        bra     .dispatch
