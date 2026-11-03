#!/usr/bin/env bash
# Build LUMEN for the Canon EOS 550D (firmware 1.0.9).
#
# What it does:
#   1. Fetches the exact Magic Lantern source this project is based on
#   2. Applies the LUMEN patches from lumen/patches/ and adds lumen/scripts/
#   3. Builds the 550D.109 platform and adds lumen/card/ (autorun flags)
#   4. Writes dist/LUMEN-550D.109-<version>.zip (+ .sha256)
#
# Requirements: git, make, python3 (with docutils), zip,
#               arm-none-eabi-gcc + newlib (e.g. apt install gcc-arm-none-eabi libnewlib-arm-none-eabi)
set -euo pipefail

ML_REPO="https://github.com/reticulatedpines/magiclantern_simplified"
ML_COMMIT="ed3e7c0dfacfdeaf3349dee73edf9e3621217462"   # 2025_release_01, the build installed on the camera
LUMEN_VERSION="$(cat "$(dirname "$0")/lumen/VERSION")"

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$ROOT/work}"
SRC="$WORK/magiclantern"
DIST="$ROOT/dist"

ARM_GCC="$(command -v arm-none-eabi-gcc || true)"
if [ -z "$ARM_GCC" ]; then
    echo "error: arm-none-eabi-gcc not found. Install the ARM cross-compiler first." >&2
    exit 1
fi
ARM_BINPATH="$(dirname "$ARM_GCC")"

echo "==> Magic Lantern source @ ${ML_COMMIT:0:10}"
if [ ! -d "$SRC/.git" ]; then
    mkdir -p "$WORK"
    git clone --filter=blob:none --no-checkout "$ML_REPO" "$SRC"
fi
git -C "$SRC" fetch --quiet origin "$ML_COMMIT" || true
git -C "$SRC" checkout --quiet --force "$ML_COMMIT"
git -C "$SRC" clean -fdxq      # only touches the scratch checkout in work/

echo "==> Applying LUMEN patches"
for p in "$ROOT"/lumen/patches/*.patch; do
    echo "    $(basename "$p")"
    git -C "$SRC" apply --whitespace=nowarn "$p"
done

echo "==> Adding LUMEN scripts"
cp "$ROOT"/lumen/scripts/*.lua "$SRC/scripts/"

echo "==> Building 550D.109"
JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
make -C "$SRC/platform/550D.109" -j"$JOBS" ARM_BINPATH="$ARM_BINPATH"

OUT="$SRC/platform/550D.109/build/magiclantern.zip"
[ -f "$OUT" ] || { echo "error: build finished but $OUT is missing" >&2; exit 1; }

mkdir -p "$DIST"
ZIP="$DIST/LUMEN-550D.109-$LUMEN_VERSION.zip"
cp "$OUT" "$ZIP"

# card extras: flag files that load the Lua module and autorun LUMEN scripts
( cd "$ROOT/lumen/card" && zip -q -r "$ZIP" . )
( cd "$DIST" && sha256sum "$(basename "$ZIP")" > "$(basename "$ZIP").sha256" )

echo
echo "==> Done: $ZIP"
cat "$ZIP.sha256"
