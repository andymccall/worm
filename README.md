# Worm

[![License: CC BY-NC 4.0](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc/4.0/)

A cross-platform snake-style game written in 6502 assembly language for the Commander X16 and Neo6502 retro computers.

**Play it on itch.io:** [andymccall.itch.io/worm](https://andymccall.itch.io/worm)

## Screenshots

| Commander X16 | Neo6502 |
|:---:|:---:|
| ![Commander X16 Menu](docs/images/commanderx16-menu.png) | ![Neo6502 Menu](docs/images/neo6502-menu.png) |
| ![Commander X16 Gameplay](docs/images/commanderx16-game.png) | ![Neo6502 Gameplay](docs/images/neo6502-game.png) |

## Supported Platforms

| Platform | CPU | Assembler | Output |
|----------|-----|-----------|--------|
| Commander X16 | 65C02 | `ca65` / `ld65` | `WORM.PRG` |
| Neo6502 | 65C02 | `ca65` / `ld65` | `worm.neo` |
| PC Engine / TurboGrafx-16 | HuC6280 | `pceas` | `worm.pce` (stub — title screen only) |

Each platform has its own independent ASM source tree under `src/<platform>/`. No code is shared between platforms — the assemblers don't share syntax (cc65/ca65 vs PCEAS), and the hardware abstractions diverge enough (linear bitmap on X16/Neo vs tile-grid VDC on PCE) that a common layer would be more friction than value.

## Prerequisites

- [cc65](https://cc65.github.io/) toolchain (`ca65`, `ld65`) — X16 + Neo builds
- [HuC](https://github.com/pce-devel/huc) — provides `pceas` for the PCE build
- [x16emu](https://www.commanderx16.com/) — Commander X16 emulator
- [Neo6502 emulator](https://www.olimex.com/Products/Retro-Computers/Neo6502/) (`neo`) and `exec.zip` conversion tool
- [Geargrafx](https://github.com/drhelius/Geargrafx) — PC Engine emulator with PCEAS-symbol-aware debugging

## Building

```sh
make build-x16    # Build Commander X16 binary
make build-neo    # Build Neo6502 binary
make build-pce    # Build PC Engine ROM (stub)
make all          # Build all platforms
```

Each 6502 platform is assembled with its own define (`-D __X16__` or `-D __NEO__`), but because the source trees are now independent the defines are increasingly cosmetic — left in place for the few `.ifdef` blocks that remain in the menu worm path coordinates.

## Running

```sh
make run-x16      # Build and launch in x16emu
make run-neo      # Build and launch in Neo6502 emulator
make run-pce      # Build and launch in Geargrafx (loads .sym for source-level debug)
```

## Release Packaging

```sh
make release-x16  # Create release/worm-x16.zip
make release-neo  # Create release/worm-neo.zip
make release-pce  # Create release/worm-pce.zip
make release-all  # Create all three release zip files
```

Each zip contains the game binary, MANUAL.TXT, and LICENSE.TXT.

## Cleaning

```sh
make clean        # Remove all build artifacts and release files
```

## Game Manual

See [docs/MANUAL.md](docs/MANUAL.md) for the player-facing game manual, including controls, rules, and gameplay tips.

## Project Structure

```
worm/
├── cfg/                       # Linker configurations (cc65)
│   ├── x16.cfg                #   Commander X16 memory map
│   └── neo.cfg                #   Neo6502 memory map
├── docs/                      # Documentation
│   ├── MANUAL.md              #   Game instruction manual (Markdown)
│   ├── MANUAL.TXT             #   Game instruction manual (plain text)
│   └── images/                #   Screenshots
├── src/
│   ├── x16/                   # Commander X16 (ca65, 65C02)
│   │   ├── app/               #   main, menu, menu_worm, demo, about, overlays
│   │   ├── engine/            #   game, worm, food, spider, life, sound,
│   │   │                      #   status_bar, wm_drawing, wm_text
│   │   └── system/            #   platform.asm (VERA + KERNAL HAL),
│   │                          #   wm_equates.inc
│   ├── neo/                   # Neo6502 (ca65, 65C02) - same sub-tree as x16,
│   │                          #   neo HAL swapped in
│   └── pce/                   # PC Engine / TG-16 (PCEAS, HuC6280)
│       ├── app/               #   boot.asm (currently a stub: WORM title +
│       │                      #   "work in progress" message)
│       └── system/            #   platform.inc (VRAM layout)
├── build/                     # Build output (generated)
├── release/                   # Release zip files (generated)
├── Makefile
├── README.md
└── LICENSE.txt
```

## Architecture

Each platform's source tree follows a three-tier layout:

- **`app/`** — Top-level entry point + per-screen modules (title/menu, demo, about, pause/quit/game-over overlays).
- **`engine/`** — Portable game systems within a platform: game loop, worm movement, food/spider/life management, sound sequencing, status bar, and shared drawing helpers (`wm_drawing`, `wm_text`).
- **`system/`** — Hardware-facing HAL + project equates. Each platform's `platform.asm` implements the same logical interface (see below); `wm_equates.inc` holds the cross-module constants (grid layout, direction codes, etc).

The X16 and Neo trees are duplicates by design — the cc65/ca65 toolchain can build either, but the hardware code under `system/` is platform-specific and the engine code occasionally branches on `.ifdef __X16__` / `.ifdef __NEO__`. The PCE tree is independent because PCEAS doesn't share syntax with ca65.

### Platform HAL Interface

Each platform's `platform.asm` exports the following routines:

| Routine | Purpose |
|---------|---------|
| `platform_init` | One-time hardware/system initialisation |
| `platform_exit` | Return to OS or halt |
| `platform_cls` | Clear the screen |
| `platform_getkey` | Wait for and return a keypress |
| `platform_poll_input` | Non-blocking input poll (returns direction) |
| `platform_check_key` | Check for a specific key without blocking |
| `platform_set_color` | Set current drawing/text colour |
| `platform_putc` | Print character at current cursor position |
| `platform_gotoxy` | Position cursor by character column/row |
| `platform_gotoxy_pixel` | Position cursor by pixel coordinates |
| `platform_draw_line` | Draw a line between two points |
| `platform_draw_filled_rect` | Draw a filled rectangle |
| `platform_random` | Return a random byte in A |
| `platform_wait_vsync` | Wait for vertical blank |
| `platform_play_note` | Play a note at given frequency/volume |
| `platform_stop_sound` | Silence audio output |

Adding a new platform means creating a new `src/<platform>/` tree (mirroring `src/x16/`'s `app/` + `engine/` + `system/` layout), with `system/platform.asm` exporting this interface, plus a corresponding linker config in `cfg/` if the toolchain needs one.

### Conditional Assembly

Platform-specific code paths use `.ifdef __X16__` / `.ifdef __NEO__` guards. The Makefile passes the appropriate `-D` flag for each build target. This is currently used for:

- Menu worm path coordinates (slightly different grid alignment per platform)
- Platform-specific colour constants (`COLOR_GREEN`, `COLOR_RED`, `COLOR_YELLOW`, `COLOR_LGRAY`, `COLOR_BLUE`) exported from each platform

### Key Design Decisions

- **No wrapping.** The worm dies on hitting the border, keeping gameplay tense as the body grows.
- **Static spiders.** Spiders don't move but accumulate over time, gradually shrinking the safe playfield.
- **Vulnerability windows.** When at max lives, eating food makes spiders temporarily edible — a risk/reward mechanic that rewards aggressive play.
- **Non-blocking sound.** The frame-based sequencer ticks alongside gameplay, so sound effects never stall the game loop.
- **Circular spider buffer.** Up to 8 spiders are managed in a circular buffer; when full, the oldest is recycled.

## Licence

This work is licensed under the [Creative Commons Attribution-NonCommercial 4.0 International License](https://creativecommons.org/licenses/by-nc/4.0/).

Copyright (c) 2026 Andy McCall