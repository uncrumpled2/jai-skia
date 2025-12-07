#!/usr/bin/env python3
"""Extract exported symbols from skia.dll and save to a file"""

import sys

try:
    import pefile
except ImportError:
    print("Installing pefile...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pefile"])
    import pefile

def get_dll_exports(dll_path):
    """Get all exported symbol names from a DLL"""
    pe = pefile.PE(dll_path)
    exports = []

    if hasattr(pe, 'DIRECTORY_ENTRY_EXPORT'):
        for exp in pe.DIRECTORY_ENTRY_EXPORT.symbols:
            if exp.name:
                exports.append(exp.name.decode('utf-8', errors='ignore'))
            else:
                exports.append(f"ordinal_{exp.ordinal}")

    return exports

if __name__ == "__main__":
    dll_path = r"C:\programming\jai-skia\skia.dll"
    output_path = r"C:\programming\jai-skia\skia_dll_symbols.txt"

    print(f"Reading exports from {dll_path}...")
    exports = get_dll_exports(dll_path)

    print(f"Found {len(exports)} exported symbols")

    with open(output_path, 'w') as f:
        for exp in sorted(exports):
            f.write(exp + '\n')

    print(f"Saved to {output_path}")

    # Print first 50 symbols
    print("\nFirst 50 symbols:")
    for exp in exports[:50]:
        print(f"  {exp}")
