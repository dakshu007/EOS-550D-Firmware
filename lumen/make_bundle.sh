#!/usr/bin/env bash
# Join lumen/src/*.lua (in file-name order) into one Magic Lantern script.
# Each part is wrapped in do ... end so its local variables stay private.
# Full-line comments and blank lines are removed (the source in lumen/src/
# keeps them); this saves Lua memory on the camera.
# Usage: lumen/make_bundle.sh <output.lua>
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)/src"
OUT="$1"
{
    first=1
    for f in "$SRC"/*.lua; do
        if [ $first -eq 1 ]; then
            # the core goes first, unwrapped: its first comment line names the
            # script in ML's Scripts menu ("LUMEN")
            cat "$f"
            first=0
        else
            printf '\n-------- %s --------\ndo\n' "$(basename "$f")"
            cat "$f"
            printf '\nend\n'
        fi
    done
} | awk '
    # keep the first two lines (ML shows them as the script name/description);
    # after that drop full-line comments and blank lines to save camera memory
    NR <= 2 { print; next }
    /^[ \t]*--/ { next }
    /^[ \t]*$/ { next }
    { print }
' > "$OUT"
