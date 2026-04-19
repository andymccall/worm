# Worm

A cross-platform worm game written in 6502 assembly language.

## Supported Platforms

| Platform | CPU | Output |
|----------|-----|--------|
| Commander X16 | 65C02 | `WORM.PRG` |
| Neo6502 | 65C02 | `worm.neo` |

## Prerequisites

- [cc65](https://cc65.github.io/) toolchain (`ca65`, `ld65`)
- [x16emu](https://www.commanderx16.com/) — Commander X16 emulator
- [Neo6502 emulator](https://www.olimex.com/Products/Retro-Computers/Neo6502/) (`neo`) and `exec.zip` conversion tool

## Building

```sh
make build-x16    # Build Commander X16 binary
make build-neo    # Build Neo6502 binary
make all          # Build all platforms
```

## Running

```sh
make run-x16      # Build and launch in x16emu
make run-neo      # Build and launch in Neo6502 emulator
```

## Cleaning

```sh
make clean        # Remove all build artifacts
```

## Project Structure

```
worm/
├── cfg/                    # Linker configurations
│   ├── x16.cfg             #   Commander X16 memory map
│   └── neo.cfg             #   Neo6502 memory map
├── src/
│   ├── main.asm            # Entry point
│   ├── api/                # Shared low-level utilities
│   │   ├── wm_equates.inc  #   Constants (grid sizes, colors, inputs)
│   │   ├── wm_drawing.asm  #   Grid-to-pixel math, cell erase
│   │   └── wm_text.asm     #   Text helpers, border drawing
│   ├── app/                # Game logic modules
│   │   ├── game.asm        #   Main game loop and state machine
│   │   ├── worm.asm        #   Worm movement and body management
│   │   ├── food.asm        #   Food spawning and collection
│   │   ├── spider.asm      #   Spider enemy behaviour
│   │   ├── life.asm        #   Lives and respawn logic
│   │   ├── sound.asm       #   Sound effect sequencer
│   │   ├── menu.asm        #   Start screen and menu
│   │   ├── about.asm       #   About/credits screen
│   │   ├── demo.asm        #   Attract-mode demo
│   │   ├── overlays.asm    #   In-game overlays (pause, quit, etc.)
│   │   └── status_bar.asm  #   HUD: food count, lives
│   └── system/             # Platform abstraction layer
│       ├── x16/
│       │   └── platform.asm  # Commander X16 (VERA, KERNAL)
│       └── neo/
│           └── platform.asm  # Neo6502 (API calls)
├── build/                  # Build output (generated)
├── Makefile
└── README.md
```

## Architecture

The codebase is organised into three tiers:

- **`api/`** — Shared low-level utilities and constants used across the game.
- **`app/`** — Game logic modules. Each file owns a single responsibility (worm, food, sound, etc.).
- **`system/`** — Platform abstraction layer. Each platform implements a common HAL interface.

Each platform's `platform.asm` exports the following interface:

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
| `platform_random` | Return a random byte |
| `platform_wait_vsync` | Wait for vertical blank |
| `platform_play_note` | Play a note at given frequency/volume |
| `platform_stop_sound` | Silence audio output |

Platform-specific colour constants (`COLOR_GREEN`, `COLOR_RED`, `COLOR_YELLOW`, `COLOR_LGRAY`, `COLOR_BLUE`) are also exported from each platform.

Adding a new platform means creating a new `src/system/<platform>/platform.asm` that exports this interface, plus a corresponding linker config in `cfg/`.
