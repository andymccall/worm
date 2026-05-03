; ***************************************************************************
;
; sound.asm - Non-blocking sound sequencer + sound effect triggers
;
; Mirrors src/x16/engine/sound.asm. The sequencer logic is portable:
; sfx_update is called once per frame, advances the active sequence,
; calls platform_play_note / platform_stop_sound as notes start/end.
; The sequence data format is identical to X16/Neo:
;
;   freq_lo, freq_hi, duration_frames   = play note
;   $FE, duration_frames                = rest (silence)
;   $FF                                 = end of sequence
;
; The hardware-facing platform_play_note + platform_stop_sound live in
; system/platform.asm (PSG channel 0).
;
; ***************************************************************************

        .code

; ===========================================================================
;
; sfx_update - Called once per frame. Advances the sound sequencer.
; Mirrors src/x16/engine/sound.asm:sfx_update in semantics, but on PCE we
; tick the sequencer SFX_TICKS_PER_FRAME (4) times per call: this build's
; wait_vsync runs at ~16 Hz rather than 60 Hz, so we'd otherwise stretch
; every jingle by ~3.75x. The inner sfx_tick body is the X16/Neo-style
; one-step advance.
;
; ===========================================================================

SFX_TICKS_PER_FRAME = 4

sfx_update:
        ldx     #SFX_TICKS_PER_FRAME
.tick_loop:
        phx
        jsr     sfx_tick
        plx
        dex
        bne     .tick_loop
        rts


sfx_tick:
        lda     sfx_active
        beq     .done

        ; Decrement delay counter.
        lda     sfx_delay
        beq     .next_note
        dec     sfx_delay
        rts

.next_note:
        ; Read next entry from sequence pointer.
        cly
        lda     [sfx_ptr], y            ; freq lo, or $FF (end), or $FE (rest)
        cmp     #$FF
        beq     .stop
        cmp     #$FE
        beq     .rest

        ; It's a note: freq_lo, freq_hi, duration.
        sta     sfx_freq_lo
        iny
        lda     [sfx_ptr], y
        sta     sfx_freq_hi
        iny
        lda     [sfx_ptr], y
        sta     sfx_delay

        ; Advance sequence pointer by 3.
        clc
        lda     <sfx_ptr + 0
        adc     #3
        sta     <sfx_ptr + 0
        lda     <sfx_ptr + 1
        adc     #0
        sta     <sfx_ptr + 1

        ; Play the note.
        ldx     sfx_freq_lo
        ldy     sfx_freq_hi
        lda     #$3F                    ; volume (full; PCE will mask to 5 bits)
        jsr     platform_play_note
        rts

.rest:
        ; Rest: silence for N frames.
        jsr     platform_stop_sound
        iny
        lda     [sfx_ptr], y            ; duration
        sta     sfx_delay

        ; Advance pointer by 2.
        clc
        lda     <sfx_ptr + 0
        adc     #2
        sta     <sfx_ptr + 0
        lda     <sfx_ptr + 1
        adc     #0
        sta     <sfx_ptr + 1
        rts

.stop:
        ; End of sequence.
        jsr     platform_stop_sound
        stz     sfx_active
.done:
        rts


; ===========================================================================
;
; sfx_start - Internal: kick off a sound sequence pointed at by A/X.
; A = pointer low, X = pointer high.
;
; ===========================================================================

sfx_start:
        pha
        phx
        jsr     platform_stop_sound     ; clear any in-flight note first
        plx
        pla
        sta     <sfx_ptr + 0
        stx     <sfx_ptr + 1
        lda     #1
        sta     sfx_active
        stz     sfx_delay
        rts


; ===========================================================================
;
; sfx_stop - Stop any playing sound and reset the sequencer.
;
; ===========================================================================

sfx_stop:
        jsr     platform_stop_sound
        stz     sfx_active
        rts


; ===========================================================================
; Sound effect triggers - one per game event.
; ===========================================================================

sfx_play_move:
        lda     #<snd_move
        ldx     #>snd_move
        jmp     sfx_start

sfx_play_food:
        lda     #<snd_food
        ldx     #>snd_food
        jmp     sfx_start

sfx_play_spider_appear:
        lda     #<snd_spider_appear
        ldx     #>snd_spider_appear
        jmp     sfx_start

sfx_play_spider_eat:
        lda     #<snd_spider_eat
        ldx     #>snd_spider_eat
        jmp     sfx_start

sfx_play_life_lost:
        lda     #<snd_life_lost
        ldx     #>snd_life_lost
        jmp     sfx_start

sfx_play_vulnerable:
        lda     #<snd_vulnerable
        ldx     #>snd_vulnerable
        jmp     sfx_start

sfx_play_game_over:
        lda     #<snd_game_over
        ldx     #>snd_game_over
        jmp     sfx_start

sfx_play_get_ready:
        lda     #<snd_get_ready
        ldx     #>snd_get_ready
        jmp     sfx_start

sfx_play_menu_jingle:
        lda     #<snd_menu_jingle
        ldx     #>snd_menu_jingle
        jmp     sfx_start


; ===========================================================================
; Sound sequence data
; ===========================================================================

        .data

; Note frequency constants in Hz (16-bit, little-endian). Same set as the
; X16/Neo build.

NOTE_C3_LO  = <131
NOTE_C3_HI  = >131
NOTE_E3_LO  = <165
NOTE_E3_HI  = >165
NOTE_G3_LO  = <196
NOTE_G3_HI  = >196

NOTE_C4_LO  = <262
NOTE_C4_HI  = >262
NOTE_D4_LO  = <294
NOTE_D4_HI  = >294
NOTE_E4_LO  = <330
NOTE_E4_HI  = >330
NOTE_F4_LO  = <349
NOTE_F4_HI  = >349
NOTE_G4_LO  = <392
NOTE_G4_HI  = >392
NOTE_A4_LO  = <440
NOTE_A4_HI  = >440
NOTE_B4_LO  = <494
NOTE_B4_HI  = >494

NOTE_C5_LO  = <523
NOTE_C5_HI  = >523
NOTE_D5_LO  = <587
NOTE_D5_HI  = >587
NOTE_E5_LO  = <659
NOTE_E5_HI  = >659
NOTE_F5_LO  = <698
NOTE_F5_HI  = >698
NOTE_G5_LO  = <784
NOTE_G5_HI  = >784
NOTE_A5_LO  = <880
NOTE_A5_HI  = >880

; Worm move: low then high blip
snd_move:
        db      NOTE_C4_LO, NOTE_C4_HI, 2
        db      NOTE_G4_LO, NOTE_G4_HI, 2
        db      $FF

; Food eaten: ascending arpeggio
snd_food:
        db      NOTE_E4_LO, NOTE_E4_HI, 2
        db      NOTE_G4_LO, NOTE_G4_HI, 2
        db      NOTE_C5_LO, NOTE_C5_HI, 3
        db      $FF

; Spider appearing: descending buzz
snd_spider_appear:
        db      NOTE_E5_LO, NOTE_E5_HI, 2
        db      NOTE_C5_LO, NOTE_C5_HI, 2
        db      NOTE_G4_LO, NOTE_G4_HI, 2
        db      NOTE_E4_LO, NOTE_E4_HI, 3
        db      $FF

; Spider eaten: quick ascending blast
snd_spider_eat:
        db      NOTE_C4_LO, NOTE_C4_HI, 2
        db      NOTE_E4_LO, NOTE_E4_HI, 2
        db      NOTE_G4_LO, NOTE_G4_HI, 2
        db      NOTE_C5_LO, NOTE_C5_HI, 2
        db      NOTE_E5_LO, NOTE_E5_HI, 3
        db      $FF

; Life lost: descending sad notes
snd_life_lost:
        db      NOTE_G4_LO, NOTE_G4_HI, 4
        db      NOTE_E4_LO, NOTE_E4_HI, 4
        db      NOTE_C4_LO, NOTE_C4_HI, 6
        db      $FE, 2
        db      NOTE_C3_LO, NOTE_C3_HI, 8
        db      $FF

; Spiders vulnerable: quick jingle
snd_vulnerable:
        db      NOTE_C5_LO, NOTE_C5_HI, 2
        db      NOTE_E5_LO, NOTE_E5_HI, 2
        db      NOTE_G5_LO, NOTE_G5_HI, 2
        db      NOTE_E5_LO, NOTE_E5_HI, 2
        db      NOTE_C5_LO, NOTE_C5_HI, 3
        db      $FF

; Game over: slow descending tune
snd_game_over:
        db      NOTE_G4_LO, NOTE_G4_HI, 6
        db      $FE, 2
        db      NOTE_E4_LO, NOTE_E4_HI, 6
        db      $FE, 2
        db      NOTE_C4_LO, NOTE_C4_HI, 6
        db      $FE, 4
        db      NOTE_G3_LO, NOTE_G3_HI, 8
        db      $FE, 2
        db      NOTE_E3_LO, NOTE_E3_HI, 8
        db      $FE, 2
        db      NOTE_C3_LO, NOTE_C3_HI, 12
        db      $FF

; Get ready: upbeat start tune
snd_get_ready:
        db      NOTE_C4_LO, NOTE_C4_HI, 3
        db      NOTE_E4_LO, NOTE_E4_HI, 3
        db      NOTE_G4_LO, NOTE_G4_HI, 3
        db      $FE, 2
        db      NOTE_C5_LO, NOTE_C5_HI, 4
        db      NOTE_G4_LO, NOTE_G4_HI, 3
        db      NOTE_C5_LO, NOTE_C5_HI, 6
        db      $FF

; Menu jingle: bright welcoming fanfare
snd_menu_jingle:
        db      NOTE_C4_LO, NOTE_C4_HI, 3
        db      NOTE_E4_LO, NOTE_E4_HI, 3
        db      NOTE_G4_LO, NOTE_G4_HI, 3
        db      NOTE_C5_LO, NOTE_C5_HI, 4
        db      $FE, 2
        db      NOTE_G4_LO, NOTE_G4_HI, 3
        db      NOTE_A4_LO, NOTE_A4_HI, 3
        db      NOTE_B4_LO, NOTE_B4_HI, 3
        db      NOTE_C5_LO, NOTE_C5_HI, 6
        db      $FE, 3
        db      NOTE_E5_LO, NOTE_E5_HI, 4
        db      NOTE_C5_LO, NOTE_C5_HI, 6
        db      $FF


; ===========================================================================
; Sound state BSS + ZP (matches src/x16/engine/sound.asm naming)
; ===========================================================================

        .bss

sfx_active:        ds 1     ; 1 = sequence currently playing
sfx_delay:         ds 1     ; frames remaining before next note
sfx_freq_lo:       ds 1     ; temp: current note freq low byte
sfx_freq_hi:       ds 1     ; temp: current note freq high byte


        .zp

sfx_ptr:           ds 2     ; pointer to current position in sequence
