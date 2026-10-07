#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 generate_data.py
mkdir -p release
(cd src && x86_64-w64-mingw32-windres app.rc -o ../release/resources.o)
x86_64-w64-mingw32-g++ src/main.cpp release/resources.o -o release/GroveCodes.exe -std=c++17 -O2 -Wall -Wextra -municode -mwindows -static -static-libgcc -static-libstdc++ -luser32 -lgdi32 -Wl,--no-insert-timestamp
sha256sum release/GroveCodes.exe > release/SHA256SUMS.txt
