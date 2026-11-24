#!/bin/bash
# Ultimate Skyrim for SkyrimMT: builds the installer from SkyrimMT's own ModKit and installs ultimate/modlist.json
# into its own profile ("Ultimate Skyrim"). Needs: SkyrimMT set up, a Nexus Premium API key saved in SkyrimMT,
# Xcode Command Line Tools (swiftc).
#   ultimate/ultimate.sh check     # builds the installer and checks every file is downloadable (nothing changes)
#   ultimate/ultimate.sh install   # downloads (~12 GB), installs, sorts with LOOT, deploys
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
GAME="${SKYRIMMT_HOME:-$HOME/Games/skyrim}"
BIN="$ROOT/build/ultimate-install"
LOG="$GAME/logs/ultimate-install.log"
cmd="${1:-install}"

command -v swiftc >/dev/null || { echo "Xcode Command Line Tools are missing: run  xcode-select --install  and try again."; exit 1; }
[ -d "$GAME/prefix" ] || { echo "SkyrimMT isn't set up yet ($GAME): open SkyrimMT → Setup → Set up everything."; exit 1; }

mkdir -p "$ROOT/build" "$GAME/logs"
if [ ! -x "$BIN" ] || [ -n "$(find "$ROOT/app/ModKit" "$HERE/cli" -newer "$BIN" -name '*.swift' 2>/dev/null | head -1)" ]; then
  echo "Building the installer…"
  if ! swiftc -O "$ROOT"/app/ModKit/*.swift "$HERE/cli/main.swift" -o "$BIN" 2>"$ROOT/build/ultimate-build.log"; then
    # Swift 6.2's type checker gives up on one expression in ModKit/Collections.swift ("unable to type-check this
    # expression in reasonable time"). Build from a copy with that expression split up; app/ModKit stays untouched.
    echo "Stock ModKit didn't compile with this Swift (see build/ultimate-build.log); building from a patched copy…"
    MK="$ROOT/build/ultimate-modkit"
    rm -rf "$MK"; mkdir -p "$MK"; cp "$ROOT"/app/ModKit/*.swift "$MK/"
    patch -s -d "$MK" -p1 < "$HERE/cli/modkit-swift62.patch"
    swiftc -O "$MK"/*.swift "$HERE/cli/main.swift" -o "$BIN"
  fi
fi

case "$cmd" in
  check) exec "$BIN" "$HERE/modlist.json" --dry-run ;;
  install)
    # SkyrimMT and the game must be closed while the installer changes the mod folders
    if pgrep -x SkyrimSE.exe >/dev/null || pgrep -f "SkyrimSE.exe" >/dev/null; then echo "Quit Skyrim first."; exit 1; fi
    osascript -e 'tell application "SkyrimMT" to quit' >/dev/null 2>&1 || true
    sleep 2
    free_gb=$(df -g "$GAME" | awk 'NR==2 {print $4}')
    [ "${free_gb:-0}" -ge 40 ] || { echo "Need at least 40 GB free on the disk with $GAME (have ${free_gb} GB)."; exit 1; }
    echo "Installing Ultimate Skyrim (log: $LOG)"
    set +e
    "$BIN" "$HERE/modlist.json" 2>&1 | tee "$LOG"
    rc=${PIPESTATUS[0]}
    set -e
    [ $rc -eq 0 ] && open -a SkyrimMT 2>/dev/null || true
    exit $rc ;;
  *) sed -n 2,6p "$0"; exit 2 ;;
esac
