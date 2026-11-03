#!/usr/bin/env python3
"""
extract-images.py

A standalone binary carver that extracts all embedded PNG images
from GuitarPro.exe (or any other compiled executable / binary).

How it works:
1. PNG File Structure:
   - Header Signature: Every valid PNG begins with an 8-byte magic number:
     \x89 P N G \r \n \x1a \n  (hex: 89 50 4e 47 0d 0a 1a 0a)
   - IHDR Chunk: Follows immediately after the signature. The first 8 bytes of
     the IHDR chunk payload contain the image width and height as two 32-bit
     big-endian integers.
   - IEND Chunk: Marks the end of a PNG stream. It consists of the 4-byte chunk
     type 'IEND' followed by a 4-byte CRC checksum (\xae\x42\x60\x82).

2. Binary Carving:
   - The script scans the executable bytes linearly to find each PNG signature.
   - For every signature found, it searches forward for the corresponding IEND marker.
   - The exact slice of bytes from signature to IEND is extracted and saved to disk.
"""

import os
import sys
import struct

# Default path to GuitarPro.exe in the Bottles Flatpak wine prefix
DEFAULT_EXE_PATH = os.path.expanduser(
    "~/.var/app/com.usebottles.bottles/data/bottles/bottles/Guitar-Pro/drive_c/Program Files/Arobas Music/Guitar Pro 8/GuitarPro.exe"
)
DEFAULT_OUTPUT_DIR = "gp8_images"

# PNG format markers
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
PNG_IEND = b"IEND\xaeB`\x82"  # 'IEND' + 4-byte CRC


def extract_pngs(exe_path: str, output_dir: str):
    if not os.path.isfile(exe_path):
        print(f"Error: File not found at '{exe_path}'", file=sys.stderr)
        sys.exit(1)

    print(f"Reading '{exe_path}'...")
    with open(exe_path, "rb") as f:
        data = f.read()

    os.makedirs(output_dir, exist_ok=True)

    idx = 0
    count = 0
    total_bytes = len(data)

    print(f"Scanning {total_bytes / (1024 * 1024):.2f} MB for embedded PNG images...\n")

    while True:
        # Search for the next PNG signature starting from current index
        pos = data.find(PNG_SIGNATURE, idx)
        if pos == -1:
            break

        # Search for the end-of-image (IEND) marker after this signature
        iend_pos = data.find(PNG_IEND, pos)
        if iend_pos != -1:
            # Full PNG size includes the 8-byte IEND marker ('IEND' + 4-byte CRC)
            png_size = (iend_pos + len(PNG_IEND)) - pos

            # Parse the IHDR chunk (starts 12 bytes after the PNG signature)
            # Offset +12: 4 bytes length, 4 bytes 'IHDR', 4 bytes width, 4 bytes height
            ihdr_chunk = pos + 12
            width, height = 0, 0
            if data[ihdr_chunk:ihdr_chunk + 4] == b"IHDR":
                width, height = struct.unpack(">II", data[ihdr_chunk + 4:ihdr_chunk + 12])

            count += 1
            filename = f"image_{count:02d}_{width}x{height}.png"
            dest_path = os.path.join(output_dir, filename)

            # Write the raw PNG byte slice to disk
            with open(dest_path, "wb") as out_file:
                out_file.write(data[pos:pos + png_size])

            print(f"[{count:02d}] Extracted {filename:<25} ({png_size:>7,} bytes) at offset 0x{pos:08x}")

            # Advance index past this PNG image
            idx = pos + png_size
        else:
            # If no IEND found, advance past the signature to keep searching
            idx = pos + len(PNG_SIGNATURE)

    print(f"\nDone! Extracted {count} PNG images to '{output_dir}/'.")


if __name__ == "__main__":
    target_exe = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_EXE_PATH
    out_directory = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUTPUT_DIR

    extract_pngs(target_exe, out_directory)
