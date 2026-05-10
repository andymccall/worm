;----------------------------------------------------------------------------
;
; main.asm
;
; Worm - ZX Spectrum Next port - entry point
;
; sjasmplus is a single-pass assembler with no separate linker, so we
; INCLUDE all the project sources here from main.asm and assemble the
; whole tree as one translation unit. Mirrors the role of the equivalent
; PCE main.asm (which is single-pass via PCEAS) more than the X16/Neo
; ones (which use ca65 + ld65 with .import/.export).
;
; Current milestone: bring up Layer 2 320x256, clear to black, and paint
; the green chrome (border + divider) at the X16-canonical coordinates.
; Mirrors the equivalent point in the PCE port's bring-up.
;
; Targets a ZX Spectrum Next, not a 48K/128K Spectrum: uses Z80N opcodes,
; the Layer 2 320x256 mode, and the Next register space. SAVENEX CORE
; declares the minimum Next core (3.0 - the version that introduced
; Layer 2 320x256).
;
;----------------------------------------------------------------------------

        DEVICE  ZXSPECTRUMNEXT

        CSPECTMAP "worm.map"

        ; Project equates (border layout, palette, NEXTREG numbers,
        ; Layer 2 banks, etc).
        include "wm_equates.inc"

        org     $8000

;----------------------------------------------------------------------------
; Entry point. Brings up the display, clears to black, paints the chrome,
; then spins forever with IRQs disabled (the IM 1 vector at $0038 lives
; in our paged-in Layer 2 RAM, so HALT-on-IRQ would crash).
;----------------------------------------------------------------------------

start:
        call    platform_init

;
; Top-level dispatcher. Mirrors src/x16/app/main.asm: call
; show_start_screen, dispatch on the returned selection. The Next has no
; software quit, so QUIT just loops back to the menu like the PCE port
; does. ABOUT and DEMO are stubs in this milestone - they fall back to
; redrawing the menu so we can still verify keyboard input end-to-end.
;
.dispatch:
        call    show_start_screen

        or      a
        jr      z, .do_quit
        cp      1
        jr      z, .do_start
        cp      2
        jr      z, .do_about
        cp      3
        jr      z, .do_demo
        jr      .dispatch

.do_start:
        call    game_reset_stats
        call    game_run
        jr      .dispatch
.do_about:
        call    show_about_screen
        jr      .dispatch
.do_demo:
        call    demo_run
        jr      .dispatch
.do_quit:
        jp      platform_exit

;----------------------------------------------------------------------------
; Platform HAL + engine sources.
;
; Order is purely organisational - sjasmplus is single-pass but resolves
; forward references in a second pass for cross-INCLUDE labels, so this
; bottom-up ordering (HAL first, then engine, then app modules) matches
; the X16/Neo/PCE convention even though it isn't strictly required.
;----------------------------------------------------------------------------

        include "platform.asm"          ; system/
        include "wm_text.asm"           ; engine/
        include "wm_drawing.asm"
        include "status_bar.asm"
        include "worm.asm"
        include "food.asm"
        include "spider.asm"
        include "life.asm"
        include "game.asm"
        include "menu.asm"              ; app/
        include "menu_worm.asm"
        include "about.asm"
        include "demo.asm"
        include "overlays.asm"

;----------------------------------------------------------------------------
; .nex packaging.
;
;   OPEN ... start, $ff40   - PC = start, SP = $ff40 on launch
;   CORE 3,0,0              - require Next core >= 3.00.00 (Layer 2
;                             320x256 was introduced in core 3.0)
;   CFG  7,0,0,0            - default border, no preserve, no MMU lock,
;                             no file handle expected
;   AUTO                    - autorun on load
;----------------------------------------------------------------------------

        SAVENEX OPEN "worm.nex", start, $ff40
        SAVENEX CORE 3,0,0
        SAVENEX CFG  7,0,0,0
        SAVENEX AUTO
