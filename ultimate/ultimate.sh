#!/bin/bash
# Ultimate Skyrim for SkyrimMT: builds the installer from SkyrimMT's own ModKit and installs ultimate/modlist.json
# into its own profile ("Ultimate Skyrim"). Needs: SkyrimMT set up, a Nexus API key saved in SkyrimMT,
# Xcode Command Line Tools (swiftc).
#   ultimate/ultimate.sh check     # builds the installer and checks the files (nothing changes)
#   ultimate/ultimate.sh fetch     # free Nexus accounts: opens missing files' Nexus pages in Chrome, 10 at a time; you click
#                                  # "Slow download" on each and SkyrimMT downloads it (nxm:// link)
#   ultimate/ultimate.sh install [--available]   # --available: only what is already downloaded (see deps.json);
#                                  # downloads (~18 GB; Premium) or uses the fetched files, installs, sorts with LOOT, deploys
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
GAME="${SKYRIMMT_HOME:-$HOME/Games/skyrim}"
BIN="$ROOT/build/ultimate-install"
LOG="$GAME/logs/ultimate-install.log"
cmd="${1:-install}"; shift || true   # remaining args (e.g. --available) go to the installer
# SkyrimMT.app: $SKYRIMMT_APP, else wherever Spotlight finds it, else /Applications
APP="${SKYRIMMT_APP:-}"
if [ -z "$APP" ]; then
  while IFS= read -r a; do [ -x "$a/Contents/Helpers/skyrimmt-keyhelper" ] && { APP="$a"; break; }; done \
    < <(mdfind "kMDItemCFBundleIdentifier == 'local.skyrimmt.launcher'" 2>/dev/null)
fi
APP="${APP:-/Applications/SkyrimMT.app}"

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
  check) exec "$BIN" "$HERE/modlist.json" --dry-run "$@" ;;
  install)
    # SkyrimMT and the game must be closed while the installer changes the mod folders
    if pgrep -x SkyrimSE.exe >/dev/null || pgrep -f "SkyrimSE.exe" >/dev/null; then echo "Quit Skyrim first."; exit 1; fi
    osascript -e 'tell application "SkyrimMT" to quit' >/dev/null 2>&1 || true
    sleep 2
    free_gb=$(df -g "$GAME" | awk 'NR==2 {print $4}')
    [ "${free_gb:-0}" -ge 40 ] || { echo "Need at least 40 GB free on the disk with $GAME (have ${free_gb} GB)."; exit 1; }
    echo "Installing Ultimate Skyrim (log: $LOG)"
    set +e
    "$BIN" "$HERE/modlist.json" "$@" 2>&1 | tee "$LOG"
    rc=${PIPESTATUS[0]}
    set -e
    [ $rc -eq 0 ] && open "$APP" 2>/dev/null || true
    exit $rc ;;
  fetch)
    # Free Nexus accounts can't download through the API: each file needs a "Slow download" click on its Nexus page,
    # which hands an nxm:// link to SkyrimMT, which downloads it into the downloads folder. Nothing is clicked for you.
    # Opens FETCH_BATCH (default 10) missing files' pages at a time, in list order, and opens the next batch as soon as
    # every file of the current one has arrived. A file still missing 5 min after its batch opened is reported
    # ("STALLED"); its page is reopened once after 15 min. Machine-readable lines: "BATCH n ready, x tabs", "STALLED ...".
    [ -d "$APP" ] || { echo "SkyrimMT.app not found (set SKYRIMMT_APP=/path/to/SkyrimMT.app)."; exit 1; }
    /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$APP/Contents/Info.plist" 2>/dev/null | grep -qE '^[[:space:]]*nxm$' \
      || { echo "$APP doesn't declare the nxm:// scheme; it can't take Nexus downloads."; exit 1; }
    NXM="$ROOT/build/nxm-handler"
    if [ ! -x "$NXM" ] || [ "$HERE/cli/nxm-handler.swift" -nt "$NXM" ]; then swiftc -O "$HERE/cli/nxm-handler.swift" -o "$NXM"; fi
    handler="$("$NXM" get 2>/dev/null || true)"
    if [ "$handler" != "$APP" ]; then
      echo "nxm:// links open in ${handler:-no app}; making SkyrimMT their handler (macOS may ask you to confirm)…"
      "$NXM" set "$APP" || { echo "Couldn't make SkyrimMT the nxm:// handler."; exit 1; }
      handler="$("$NXM" get 2>/dev/null || true)"
      [ "$handler" = "$APP" ] || { echo "nxm:// links still open in ${handler:-no app}, not SkyrimMT."; exit 1; }
    fi
    open "$APP"; sleep 3
    size="${FETCH_BATCH:-10}"
    total=$(plutil -extract mods raw -o - "$HERE/modlist.json")
    browse() { open -a "Google Chrome" "$1" 2>/dev/null || open "$1"; }   # Chrome if installed, else default browser
    page() { echo "https://www.nexusmods.com/skyrimspecialedition/mods/$1?tab=files&file_id=$2&nmm=1"; }
    missing_now() { "$BIN" "$HERE/modlist.json" --missing; }
    n=0
    while :; do
      missing="$(missing_now)"
      left=$(printf '%s' "$missing" | grep -c . || true)
      echo "$((total - left))/$total downloaded"
      [ "$left" -gt 0 ] || break
      batch="$(printf '%s\n' "$missing" | grep . | head -n "$size")"
      n=$((n + 1))
      printf '%s\n' "$batch" | while read -r m f _; do browse "$(page "$m" "$f")"; done
      echo "BATCH $n ready, $(printf '%s\n' "$batch" | grep -c .) tabs:"; printf '%s\n' "$batch" | sed 's/^/  /'
      start=$(date +%s); stalled=0; reopened=0
      while :; do
        sleep 10
        now="$(missing_now)"
        still="$(printf '%s\n' "$batch" | while read -r m f _; do printf '%s\n' "$now" | grep "^$m $f " || true; done)"
        echo "$((total - $(printf '%s' "$now" | grep -c . || true)))/$total downloaded"
        [ -n "$still" ] || break
        age=$(( $(date +%s) - start ))
        if [ $stalled -eq 0 ] && [ $age -ge 300 ]; then
          printf '%s\n' "$still" | sed 's/^/STALLED (5 min, batch '"$n"'): /'; stalled=1
        fi
        if [ $reopened -eq 0 ] && [ $age -ge 900 ]; then
          echo "Reopening the pages still missing after 15 min:"
          printf '%s\n' "$still" | while read -r m f _; do echo "  $m $f"; browse "$(page "$m" "$f")"; done; reopened=1
        fi
      done
    done
    echo "All $total files downloaded. Next: ultimate/ultimate.sh install" ;;
  *) sed -n 2,8p "$0"; exit 2 ;;
esac
