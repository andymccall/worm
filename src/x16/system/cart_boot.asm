; Worm - (c) 2026 Andy McCall
; Licensed under CC BY-NC 4.0
; https://creativecommons.org/licenses/by-nc/4.0/

; ---------------------------------------------------------------------------
; cart_boot.asm - X16 cartridge self-extracting loader
; ---------------------------------------------------------------------------
; The cart occupies ROM bank 32, mapped at $C000-$FFFF. While that bank is
; paged in, the entire ROM window is cart data - the KERNAL at $E000-$FFFF
; is gone, so JSR $FFD2 etc. would execute random cart bytes. To keep the
; existing PRG codebase (platform.asm + the rest) reusable, this stub
; copies the PRG payload back to its normal load address in low RAM, then
; pages ROM bank 0 (KERNAL) back into the window before jumping in.
;
; 16K bank layout:
;   $C000-$C003   "CX16" autoboot signature (KERNAL boot_cartridge checks)
;   $C004-$C0FF   this boot stub
;   $C100-$FFFF   PRG payload, load-address word stripped, zero-padded
; ---------------------------------------------------------------------------

ROM_BANK   = $01            ; ROM bank register (zero-page mapped)
SRC        = $FA            ; copy source pointer  (zp, 2 bytes)
DST        = $FC            ; copy dest pointer    (zp, 2 bytes)
TRAMPOLINE = $0400          ; finalize sequence lives here once copied
PRG_ENTRY  = $080D          ; PRG entry (jmp main, just past the BASIC stub)

.segment "BOOT"

; $C000: KERNAL boot_cartridge looks for "CX16" here in bank 32. Without it
; the cart is ignored and the system boots to BASIC.
    .byte $43, $58, $31, $36          ; "CX16"

; $C004: KERNAL JMPs here with bank 32 active and IRQs masked (SEI).
cart_start:
    ldx #$FF
    txs
    cld

    ; ---- Copy payload $C100..$FFFF -> $0801.. ----
    ; A full 16128 bytes are copied. The PRG is shorter; the tail is just
    ; zero-padding from the cart image and lands harmlessly in BSS space.
    lda #$00
    sta SRC
    lda #$C1
    sta SRC+1                         ; SRC = $C100
    lda #$01
    sta DST
    lda #$08
    sta DST+1                         ; DST = $0801

    ldy #$00
@copy:
    lda (SRC),y
    sta (DST),y
    inc SRC
    bne @inc_dst
    inc SRC+1
    beq @copy_done                    ; SRC wrapped past $FFFF
@inc_dst:
    inc DST
    bne @copy
    inc DST+1
    bra @copy
@copy_done:

    ; ---- Stage the bank-switch + jump in RAM ----
    ; STZ ROM_BANK pages the cart out, so the bytes that follow it must
    ; come from somewhere that survives that switch. RAM does.
    ldx #(trampoline_end - trampoline_src)
@cpy_tramp:
    lda trampoline_src - 1, x
    sta TRAMPOLINE - 1, x
    dex
    bne @cpy_tramp

    jmp TRAMPOLINE

trampoline_src:
    stz ROM_BANK                      ; ROM bank 0: KERNAL back in window
    cli                               ; KERNAL IRQ handler is safe again
    jmp PRG_ENTRY
trampoline_end:
