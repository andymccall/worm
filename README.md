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
├── cfg/                  # Linker configurations
│   ├── x16.cfg           #   Commander X16 memory map
│   └── neo.cfg           #   Neo6502 memory map
├── src/
│   ├── common/           # Shared code (all platforms)
│   │   └── main.asm      #   Entry point and game loop
│   ├── x16/              # Commander X16
│   │   └── platform.asm  #   Startup, KERNAL I/O
│   └── neo/              # Neo6502
│       └── platform.asm  #   Startup, API I/O
├── build/                # Build output (generated)
├── Makefile
└── README.md
```

## Architecture

Each platform implements a common interface exported from its `platform.asm`:

| Routine | Purpose |
|---------|---------|
| `platform_init` | One-time hardware/system initialisation |
| `platform_putc` | Print character in A to screen |
| `platform_exit` | Return to OS or halt |

Shared game logic in `src/common/` calls these routines, keeping platform-specific code isolated. Adding a new platform means creating a new `src/<platform>/platform.asm` and a corresponding linker config in `cfg/`.
