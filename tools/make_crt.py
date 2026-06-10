#!/usr/bin/env python3
# Wrap a 16K cartridge bank image in an x16emu CRT header.
#
# The header is 480 bytes (NOT 512 as some docs claim) and the bank-type
# flags start at offset 256 (one byte per bank 32..255). x16emu reads the
# bank-32 flag at offset 256; if that byte isn't 0x01 the cart is treated
# as Not Present and the KERNAL never sees the "CX16" autoboot signature.
# This layout was verified against the official `makecart` tool.

import sys
import os

HEADER_SIZE = 480
BANK_SIZE = 16384
BANK_FLAGS_OFFSET = 256


def create_crt_header(name="WORM", developer="", copyright="", version="1.0"):
    header = bytearray(HEADER_SIZE)

    # 0-15: magic
    header[0:16] = b"CX16 CARTRIDGE\r\n"

    # 16-31: format version (5 chars + 11 spaces)
    header[16:32] = b"01.00           "

    # 32-63 name, 64-95 developer, 96-127 copyright, 128-159 program version
    # All 32-byte ASCII fields, space-padded.
    for offset, text in (
        (32, name),
        (64, developer),
        (96, copyright),
        (128, version),
    ):
        b = text.encode("utf-8")[:32]
        header[offset : offset + len(b)] = b
        for i in range(offset + len(b), offset + 32):
            header[i] = 0x20

    # 160-255: reserved, leave as 0x00.

    # 256-479: bank type flags for banks 32..255. 0x01 = ROM.
    header[BANK_FLAGS_OFFSET] = 0x01

    return bytes(header)


def make_crt(input_file, output_file, name="WORM", developer="", copyright="", version="1.0"):
    if not os.path.exists(input_file):
        print(f"Input not found: {input_file}", file=sys.stderr)
        sys.exit(1)
    with open(input_file, "rb") as f:
        data = f.read()
    if len(data) < BANK_SIZE:
        data = data + bytes(BANK_SIZE - len(data))
    elif len(data) > BANK_SIZE:
        print(
            f"Input is {len(data)} bytes; expected at most {BANK_SIZE}",
            file=sys.stderr,
        )
        sys.exit(1)
    header = create_crt_header(name, developer, copyright, version)
    with open(output_file, "wb") as f:
        f.write(header)
        f.write(data)
    print(f"Created cartridge: {output_file}")


if __name__ == "__main__":
    make_crt(sys.argv[1], sys.argv[2])
