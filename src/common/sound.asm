; sound.asm - Non-blocking sound sequencer and sound effect triggers

.export sfx_play_move
.export sfx_play_food
.export sfx_play_spider_appear
.export sfx_play_spider_eat
.export sfx_play_life_lost
.export sfx_play_vulnerable
.export sfx_play_game_over
.export sfx_play_get_ready
.export sfx_update
.export sfx_delay

.import platform_play_note
.import platform_stop_sound
.import platform_wait_vsync

; ---------------------------------------------------------------------------

.segment "CODE"

; ---------------------------------------------------------------------------
; sfx_update
;   Called once per frame. Advances the sound sequencer.
;   If a sequence is playing, steps through notes with timing.
; ---------------------------------------------------------------------------

.proc sfx_update
    lda sfx_active
    beq @done

    ; Decrement delay counter
    lda sfx_delay
    beq @next_note
    dec sfx_delay
    rts

@next_note:
    ; Read next entry from sequence pointer
    ldy #0
    lda (sfx_ptr), y        ; frequency low (or $FF = end, $FE = silence)
    cmp #$FF
    beq @stop
    cmp #$FE
    beq @rest

    ; It's a note: freq_lo, freq_hi, duration(frames)
    sta sfx_freq_lo
    iny
    lda (sfx_ptr), y        ; frequency high
    sta sfx_freq_hi
    iny
    lda (sfx_ptr), y        ; duration in frames
    sta sfx_delay

    ; Advance pointer by 3
    lda sfx_ptr
    clc
    adc #3
    sta sfx_ptr
    lda sfx_ptr+1
    adc #0
    sta sfx_ptr+1

    ; Play the note
    ldx sfx_freq_lo
    ldy sfx_freq_hi
    lda #$3F                ; volume (full)
    jsr platform_play_note
    rts

@rest:
    ; Rest: silence for N frames
    jsr platform_stop_sound
    iny
    lda (sfx_ptr), y        ; duration
    sta sfx_delay

    ; Advance pointer by 2
    lda sfx_ptr
    clc
    adc #2
    sta sfx_ptr
    lda sfx_ptr+1
    adc #0
    sta sfx_ptr+1
    rts

@stop:
    ; End of sequence
    jsr platform_stop_sound
    lda #0
    sta sfx_active

@done:
    rts
.endproc

; ---------------------------------------------------------------------------
; sfx_start
;   Internal: starts playing a sound sequence.
;   A/X = pointer to sequence data (A=low, X=high)
; ---------------------------------------------------------------------------

.proc sfx_start
    pha
    txa
    pha
    jsr platform_stop_sound  ; reset channel / clear queue before new SFX
    pla
    tax
    pla
    sta sfx_ptr
    stx sfx_ptr+1
    lda #1
    sta sfx_active
    lda #0
    sta sfx_delay
    rts
.endproc

; ---------------------------------------------------------------------------
; Sound effect triggers
; ---------------------------------------------------------------------------

.proc sfx_play_move
    lda #<snd_move
    ldx #>snd_move
    jmp sfx_start
.endproc

.proc sfx_play_food
    lda #<snd_food
    ldx #>snd_food
    jmp sfx_start
.endproc

.proc sfx_play_spider_appear
    lda #<snd_spider_appear
    ldx #>snd_spider_appear
    jmp sfx_start
.endproc

.proc sfx_play_spider_eat
    lda #<snd_spider_eat
    ldx #>snd_spider_eat
    jmp sfx_start
.endproc

.proc sfx_play_life_lost
    lda #<snd_life_lost
    ldx #>snd_life_lost
    jmp sfx_start
.endproc

.proc sfx_play_vulnerable
    lda #<snd_vulnerable
    ldx #>snd_vulnerable
    jmp sfx_start
.endproc

.proc sfx_play_game_over
    lda #<snd_game_over
    ldx #>snd_game_over
    jmp sfx_start
.endproc

.proc sfx_play_get_ready
    lda #<snd_get_ready
    ldx #>snd_get_ready
    jmp sfx_start
.endproc

; ---------------------------------------------------------------------------

.segment "RODATA"

; Sound sequence format:
;   freq_lo, freq_hi, duration_frames   = play note
;   $FE, duration_frames                = rest (silence)
;   $FF                                 = end of sequence
;
; Note frequencies are in Hz (16-bit).
; X16 platform_play_note converts Hz -> VERA PSG register.
; Neo6502 platform_play_note passes Hz directly to sound API.

; Note frequency constants in Hz (16-bit, little-endian)
; Octave 3
NOTE_C3_LO  = <131
NOTE_C3_HI  = >131
NOTE_E3_LO  = <165
NOTE_E3_HI  = >165
NOTE_G3_LO  = <196
NOTE_G3_HI  = >196

; Octave 4
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

; Octave 5
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
    .byte NOTE_C4_LO, NOTE_C4_HI, 2
    .byte NOTE_G4_LO, NOTE_G4_HI, 2
    .byte $FF

; Food eaten: ascending arpeggio
snd_food:
    .byte NOTE_E4_LO, NOTE_E4_HI, 2
    .byte NOTE_G4_LO, NOTE_G4_HI, 2
    .byte NOTE_C5_LO, NOTE_C5_HI, 3
    .byte $FF

; Spider appearing: descending buzz
snd_spider_appear:
    .byte NOTE_E5_LO, NOTE_E5_HI, 2
    .byte NOTE_C5_LO, NOTE_C5_HI, 2
    .byte NOTE_G4_LO, NOTE_G4_HI, 2
    .byte NOTE_E4_LO, NOTE_E4_HI, 3
    .byte $FF

; Spider eaten: quick ascending blast
snd_spider_eat:
    .byte NOTE_C4_LO, NOTE_C4_HI, 2
    .byte NOTE_E4_LO, NOTE_E4_HI, 2
    .byte NOTE_G4_LO, NOTE_G4_HI, 2
    .byte NOTE_C5_LO, NOTE_C5_HI, 2
    .byte NOTE_E5_LO, NOTE_E5_HI, 3
    .byte $FF

; Life lost: descending sad notes
snd_life_lost:
    .byte NOTE_G4_LO, NOTE_G4_HI, 4
    .byte NOTE_E4_LO, NOTE_E4_HI, 4
    .byte NOTE_C4_LO, NOTE_C4_HI, 6
    .byte $FE, 2
    .byte NOTE_C3_LO, NOTE_C3_HI, 8
    .byte $FF

; Spiders vulnerable: quick jingle
snd_vulnerable:
    .byte NOTE_C5_LO, NOTE_C5_HI, 2
    .byte NOTE_E5_LO, NOTE_E5_HI, 2
    .byte NOTE_G5_LO, NOTE_G5_HI, 2
    .byte NOTE_E5_LO, NOTE_E5_HI, 2
    .byte NOTE_C5_LO, NOTE_C5_HI, 3
    .byte $FF

; Game over: slow descending tune
snd_game_over:
    .byte NOTE_G4_LO, NOTE_G4_HI, 6
    .byte $FE, 2
    .byte NOTE_E4_LO, NOTE_E4_HI, 6
    .byte $FE, 2
    .byte NOTE_C4_LO, NOTE_C4_HI, 6
    .byte $FE, 4
    .byte NOTE_G3_LO, NOTE_G3_HI, 8
    .byte $FE, 2
    .byte NOTE_E3_LO, NOTE_E3_HI, 8
    .byte $FE, 2
    .byte NOTE_C3_LO, NOTE_C3_HI, 12
    .byte $FF

; Get ready: upbeat start tune
snd_get_ready:
    .byte NOTE_C4_LO, NOTE_C4_HI, 3
    .byte NOTE_E4_LO, NOTE_E4_HI, 3
    .byte NOTE_G4_LO, NOTE_G4_HI, 3
    .byte $FE, 2
    .byte NOTE_C5_LO, NOTE_C5_HI, 4
    .byte NOTE_G4_LO, NOTE_G4_HI, 3
    .byte NOTE_C5_LO, NOTE_C5_HI, 6
    .byte $FF

; ---------------------------------------------------------------------------

.segment "BSS"

sfx_active:   .res 1       ; 1 = sequence playing
sfx_delay:    .res 1       ; frames remaining before next note
sfx_freq_lo:  .res 1       ; temp: current note freq low
sfx_freq_hi:  .res 1       ; temp: current note freq high

.segment "ZEROPAGE"

sfx_ptr:      .res 2       ; pointer to current position in sequence
