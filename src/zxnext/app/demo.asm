;----------------------------------------------------------------------------
;
; demo.asm - Attract mode / demo AI
;
; Mirrors src/x16/app/demo.asm in role: invoked when the user picks
; "[D] DEMO" or when the menu's idle timer expires. The full X16
; version runs an AI-controlled worm against the same playfield as the
; real game; that requires the gameplay code, which the Next port
; doesn't have yet.
;
; STUB: this implementation just returns. The menu's dispatch loop will
; redraw the menu (which calls menu_worm_init -> mw_len = 1, mw_grow = 0,
; head_idx = 0, frame = 0) so the user-visible effect is "tail resets",
; which is what the user asked for as a placeholder until the real
; demo lands.
;
;----------------------------------------------------------------------------

demo_run:
        ret
