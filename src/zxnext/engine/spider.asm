;----------------------------------------------------------------------------
;
; spider.asm - Spider management, collision, and rendering
;
; Mirrors src/x16/engine/spider.asm. Owns:
;   spawn_spider          - add a spider via circular buffer (overwrites
;                           oldest when full)
;   check_spider_collision - head vs spider list, sets spider_hit_idx
;   remove_hit_spider     - erase + remove the spider at hit_idx
;   draw_all_spiders      - paint all active spiders (grey, or yellow when
;                           spider_vulnerable is set)
;
; State:
;   spider_x[MAX_SPIDERS], spider_y[MAX_SPIDERS]  circular buffer
;   spider_count        - number active (0..MAX_SPIDERS)
;   spider_head         - index of oldest entry
;   food_since_spider   - food eaten since last spawn (game.asm increments)
;   spider_vulnerable   - 1 = spiders are edible. Set externally when a
;                         life-pickup would spawn but lives are capped.
;                         The life-pickup module isn't in this slice yet,
;                         so vulnerability stays 0 for now; the field is
;                         declared so the draw/collision logic can read it.
;
; Spider sprite: an 8x8 side-on cartoon spider, drawn as 8 small filled
; rects (head + body + abdomen + 3 leg pairs + 2 feet). Same shape as the
; X16 sprite, just with our (x,y,w,h) rect convention.
;
;----------------------------------------------------------------------------

;----------------------------------------------------------------------------
; check_spider_collision
;
; Test the head against every active spider.
;
; Exit: CF=1 if head matches a spider (and spider_hit_idx = index),
;       CF=0 otherwise.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

check_spider_collision:
        ld      a, (spider_count)
        or      a
        jr      z, .no_hit

        ld      b, a                    ; B = remaining
        ld      c, 0                    ; C = current index
        ld      hl, spider_x
        ld      de, spider_y
.loop:
        ld      a, (body_x)
        cp      (hl)
        jr      nz, .next
        ld      a, (body_y)
        push    hl
        ex      de, hl
        cp      (hl)
        ex      de, hl
        pop     hl
        jr      z, .hit
.next:
        inc     hl
        inc     de
        inc     c
        djnz    .loop
.no_hit:
        or      a                       ; CF=0
        ret
.hit:
        ld      a, c
        ld      (spider_hit_idx), a
        scf
        ret

;----------------------------------------------------------------------------
; remove_hit_spider
;
; Erase the spider at spider_hit_idx and remove it from the buffer by
; shifting later entries down. Adjust spider_head if it pointed past the
; removed entry.
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

remove_hit_spider:
        ld      a, (spider_hit_idx)
        ld      c, a
        ld      b, 0                    ; BC = idx (offset)

        ; Erase the cell on screen.
        ld      hl, spider_x
        add     hl, bc
        ld      a, (hl)
        push    af                      ; col
        ld      hl, spider_y
        add     hl, bc
        ld      c, (hl)                 ; row
        pop     af
        ld      b, a                    ; (B=col, C=row)
        push    bc
        call    erase_cell
        pop     bc

        ; spider_count--
        ld      a, (spider_count)
        dec     a
        ld      (spider_count), a

        ; Shift spider_x/y down: for i = hit_idx; i < new_count; i++
        ;   spider_x[i] = spider_x[i+1]
        ;   spider_y[i] = spider_y[i+1]
        ld      a, (spider_hit_idx)
        ld      c, a                    ; C = i
.shift:
        ld      a, (spider_count)
        cp      c
        jr      z, .fix_head            ; i == new_count -> stop
        jr      c, .fix_head

        ld      b, 0                    ; BC = i
        ld      hl, spider_x + 1
        add     hl, bc
        ld      a, (hl)
        ld      hl, spider_x
        add     hl, bc
        ld      (hl), a

        ld      hl, spider_y + 1
        add     hl, bc
        ld      a, (hl)
        ld      hl, spider_y
        add     hl, bc
        ld      (hl), a

        inc     c
        jr      .shift

.fix_head:
        ; If spider_head was above the removed index, decrement it.
        ld      a, (spider_head)
        or      a
        ret     z
        ld      hl, spider_hit_idx
        cp      (hl)
        ret     c                       ; head < removed -> no change
        ret     z                       ; head == removed -> already correct
        dec     a
        ld      (spider_head), a
        ret

;----------------------------------------------------------------------------
; spawn_spider
;
; Place a new spider. If the buffer is full, the oldest entry is erased
; and overwritten in place; otherwise we append at slot
; (spider_head + spider_count) mod MAX_SPIDERS.
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

spawn_spider:
        ld      a, (spider_count)
        cp      MAX_SPIDERS
        jr      c, .find_slot

        ; --- Buffer full: erase the oldest spider's cell on screen, then
        ; reuse its slot.
        ld      a, (spider_head)
        ld      c, a
        ld      b, 0
        ld      hl, spider_x
        add     hl, bc
        ld      a, (hl)
        push    af
        ld      hl, spider_y
        add     hl, bc
        ld      c, (hl)
        pop     af
        ld      b, a
        push    bc                      ; col, row to erase
        call    erase_cell
        pop     bc                      ; (not used further; slot index re-derived)
        ld      a, (spider_head)
        ld      (spider_slot), a
        jr      .place

.find_slot:
        ; slot = (head + count) mod MAX_SPIDERS
        ld      a, (spider_head)
        ld      hl, spider_count
        add     a, (hl)
        and     MAX_SPIDERS - 1
        ld      (spider_slot), a

.place:
        call    find_spider_pos         ; -> spider_tmp_x/_y

        ; Store position into the chosen slot.
        ld      a, (spider_slot)
        ld      c, a
        ld      b, 0
        ld      hl, spider_x
        add     hl, bc
        ld      a, (spider_tmp_x)
        ld      (hl), a
        ld      hl, spider_y
        add     hl, bc
        ld      a, (spider_tmp_y)
        ld      (hl), a

        ; Update count or advance head.
        ld      a, (spider_count)
        cp      MAX_SPIDERS
        jr      nc, .advance_head
        inc     a
        ld      (spider_count), a
        ret

.advance_head:
        ld      a, (spider_head)
        inc     a
        and     MAX_SPIDERS - 1
        ld      (spider_head), a
        ret

;----------------------------------------------------------------------------
; find_spider_pos
;
; Pick a random (col, row) that doesn't overlap food, worm body, or any
; existing spider. (Life pickup not in this slice.)
;
; Result: spider_tmp_x, spider_tmp_y.
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

find_spider_pos:
.retry:
        call    platform_random
.mod_x:
        cp      GRID_COLS
        jr      c, .x_ok
        sub     GRID_COLS
        jr      .mod_x
.x_ok:
        ld      (spider_tmp_x), a

        call    platform_random
.mod_y:
        cp      GRID_ROWS
        jr      c, .y_ok
        sub     GRID_ROWS
        jr      .mod_y
.y_ok:
        ld      (spider_tmp_y), a

        ; --- Reject if on food ----------------------------------------
        ld      a, (spider_tmp_x)
        ld      hl, food_x
        cp      (hl)
        jr      nz, .chk_life
        ld      a, (spider_tmp_y)
        ld      hl, food_y
        cp      (hl)
        jr      z, .retry

.chk_life:
        ; --- Reject if on the active life pickup ----------------------
        ld      a, (life_active)
        or      a
        jr      z, .chk_worm
        ld      a, (spider_tmp_x)
        ld      hl, life_x
        cp      (hl)
        jr      nz, .chk_worm
        ld      a, (spider_tmp_y)
        ld      hl, life_y
        cp      (hl)
        jr      z, .retry

.chk_worm:
        ; --- Reject if on any worm body cell --------------------------
        ld      a, (worm_len)
        or      a
        jr      z, .chk_spiders
        ld      b, a
        ld      hl, body_x
        ld      de, body_y
.worm_loop:
        ld      a, (spider_tmp_x)
        cp      (hl)
        jr      nz, .worm_next
        ld      a, (spider_tmp_y)
        push    hl
        ex      de, hl
        cp      (hl)
        ex      de, hl
        pop     hl
        jr      z, .retry
.worm_next:
        inc     hl
        inc     de
        djnz    .worm_loop

.chk_spiders:
        ; --- Reject if on an existing spider --------------------------
        ld      a, (spider_count)
        or      a
        ret     z
        ld      b, a
        ld      hl, spider_x
        ld      de, spider_y
.sp_loop:
        ld      a, (spider_tmp_x)
        cp      (hl)
        jr      nz, .sp_next
        ld      a, (spider_tmp_y)
        push    hl
        ex      de, hl
        cp      (hl)
        ex      de, hl
        pop     hl
        jp      z, .retry
.sp_next:
        inc     hl
        inc     de
        djnz    .sp_loop
        ret

;----------------------------------------------------------------------------
; draw_all_spiders
;
; Paint every active spider. Colour depends on spider_vulnerable: 0 ->
; light grey (normal), 1 -> yellow (edible).
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

draw_all_spiders:
        ld      a, (spider_count)
        or      a
        ret     z

        ld      b, a                    ; remaining
        xor     a
        ld      (spider_iter), a

.loop:
        ld      a, (spider_iter)
        ld      c, a
        push    bc
        ld      b, 0
        ld      hl, spider_x
        add     hl, bc
        ld      a, (hl)
        ld      (spider_draw_col), a
        ld      hl, spider_y
        add     hl, bc
        ld      a, (hl)
        ld      (spider_draw_row), a

        ld      a, (spider_draw_col)
        ld      b, a
        ld      a, (spider_draw_row)
        ld      c, a
        call    draw_spider_shape

        pop     bc
        ld      a, (spider_iter)
        inc     a
        ld      (spider_iter), a
        djnz    .loop
        ret

;----------------------------------------------------------------------------
; draw_spider_shape
;
; Paint one 8x8 spider centred on grid cell (B, C). Colour from
; spider_vulnerable (yellow if set, light grey otherwise).
;
; Pixel anatomy (px, py = top-left of cell):
;   head      (px+0, py+2) w=2 h=2
;   body      (px+2, py+1) w=4 h=4
;   abdomen   (px+5, py+2) w=3 h=2
;   front legs (px+1, py+5) w=2 h=1
;   front foot (px+0, py+6) w=1 h=1
;   mid legs   (px+3, py+5) w=2 h=1
;   rear legs  (px+5, py+5) w=2 h=1
;   rear foot  (px+7, py+6) w=1 h=1
;
; Clobbers: A, BC, DE, HL.
;----------------------------------------------------------------------------

draw_spider_shape:
        call    calc_cell_pixel
        ld      (spider_px), hl
        ld      a, e
        ld      (spider_py), a

        ; Pick colour.
        ld      a, (spider_vulnerable)
        or      a
        ld      a, COL_LGRAY
        jr      z, .colour_set
        ld      a, COL_YELLOW
.colour_set:
        ld      (spider_col), a

        ; --- head: (px+0, py+2) w=2 h=2 ---
        ld      hl, (spider_px)
        ld      a, (spider_py)
        add     a, 2
        ld      e, a
        ld      bc, 2
        ld      d, 2
        ld      a, (spider_col)
        call    platform_draw_filled_rect

        ; --- body: (px+2, py+1) w=4 h=4 ---
        ld      hl, (spider_px)
        ld      bc, 2
        add     hl, bc
        ld      a, (spider_py)
        inc     a
        ld      e, a
        ld      bc, 4
        ld      d, 4
        ld      a, (spider_col)
        call    platform_draw_filled_rect

        ; --- abdomen: (px+5, py+2) w=3 h=2 ---
        ld      hl, (spider_px)
        ld      bc, 5
        add     hl, bc
        ld      a, (spider_py)
        add     a, 2
        ld      e, a
        ld      bc, 3
        ld      d, 2
        ld      a, (spider_col)
        call    platform_draw_filled_rect

        ; --- front legs: (px+1, py+5) w=2 h=1 ---
        ld      hl, (spider_px)
        inc     hl
        ld      a, (spider_py)
        add     a, 5
        ld      e, a
        ld      bc, 2
        ld      d, 1
        ld      a, (spider_col)
        call    platform_draw_filled_rect

        ; --- front foot: (px+0, py+6) w=1 h=1 ---
        ld      hl, (spider_px)
        ld      a, (spider_py)
        add     a, 6
        ld      e, a
        ld      bc, 1
        ld      d, 1
        ld      a, (spider_col)
        call    platform_draw_filled_rect

        ; --- mid legs: (px+3, py+5) w=2 h=1 ---
        ld      hl, (spider_px)
        ld      bc, 3
        add     hl, bc
        ld      a, (spider_py)
        add     a, 5
        ld      e, a
        ld      bc, 2
        ld      d, 1
        ld      a, (spider_col)
        call    platform_draw_filled_rect

        ; --- rear legs: (px+5, py+5) w=2 h=1 ---
        ld      hl, (spider_px)
        ld      bc, 5
        add     hl, bc
        ld      a, (spider_py)
        add     a, 5
        ld      e, a
        ld      bc, 2
        ld      d, 1
        ld      a, (spider_col)
        call    platform_draw_filled_rect

        ; --- rear foot: (px+7, py+6) w=1 h=1 ---
        ld      hl, (spider_px)
        ld      bc, 7
        add     hl, bc
        ld      a, (spider_py)
        add     a, 6
        ld      e, a
        ld      bc, 1
        ld      d, 1
        ld      a, (spider_col)
        call    platform_draw_filled_rect
        ret

;----------------------------------------------------------------------------
; State
;----------------------------------------------------------------------------

spider_x:           defs    MAX_SPIDERS
spider_y:           defs    MAX_SPIDERS
spider_count:       defb    0
spider_head:        defb    0
food_since_spider:  defb    0
spider_vulnerable:  defb    0
spider_hit_idx:     defb    0

spider_tmp_x:       defb    0
spider_tmp_y:       defb    0
spider_slot:        defb    0
spider_iter:        defb    0
spider_draw_col:    defb    0
spider_draw_row:    defb    0
spider_px:          defw    0
spider_py:          defb    0
spider_col:         defb    0
