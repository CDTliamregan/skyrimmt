#!/bin/bash
# Ultimate Skyrim for SkyrimMT: builds the installer from SkyrimMT's own ModKit and installs ultimate/modlist.json
# into its own profile ("Ultimate Skyrim"). Needs: SkyrimMT set up, a Nexus API key saved in SkyrimMT,
# Xcode Command Line Tools (swiftc).
#   ultimate/ultimate.sh check     # builds the installer and checks the files (nothing changes)
#   ultimate/ultimate.sh fetch     # free Nexus accounts: shows missing files' Nexus pages one at a time in Chrome; you click
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
    # One Chrome window at a fixed size and place shows ONE file page at a time, so the "Slow download" button stays
    # in the same spot: click it, and as soon as the file lands in the downloads folder the window moves on to the
    # next file. Progress lines: "BATCH n ready, x tabs" every 10 files, "STALLED ..." when a file hasn't arrived
    # 5 min after its page opened (the page is reloaded once after 15 min). FETCH_BOUNDS="x1,y1,x2,y2" moves the window.
    [ -d "$APP" ] || { echo "SkyrimMT.app not found (set SKYRIMMT_APP=/path/to/SkyrimMT.app)."; exit 1; }
    /usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" "$APP/Contents/Info.plist" 2>/dev/null | grep -qE '^[[:space:]]*nxm$' \
      || { echo "$APP doesn't declare the nxm:// scheme; it can't take Nexus downloads."; exit 1; }
    [ -d "/Applications/Google Chrome.app" ] || { echo "fetch needs Google Chrome."; exit 1; }
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
    # SkyrimMT asks "Install it now?" after every nxm download: answer "Later" automatically, so the click on
    # "Slow download" is the only thing to do (needs Accessibility access for the app running this script)
    ( while :; do osascript "$HERE/cli/dismiss-install-prompt.applescript" >/dev/null 2>&1; sleep 1; done ) &
    DISMISS=$!; trap 'kill $DISMISS 2>/dev/null' EXIT
    bounds="${FETCH_BOUNDS:-80,60,1480,1060}"
    total=$(plutil -extract mods raw -o - "$HERE/modlist.json")
    page() { echo "https://www.nexusmods.com/skyrimspecialedition/mods/$1?tab=files&file_id=$2&nmm=1"; }
    missing_now() { "$BIN" "$HERE/modlist.json" --missing; }
    WIN=""
    show() {   # load $1 in the fetch window (created on first use), at fixed bounds, in front
      WIN="$(osascript "$HERE/cli/fetch-window.applescript" "$1" "$bounds" "$WIN")"
    }
    count=0; n=0
    while :; do
      missing="$(missing_now)"
      left=$(printf '%s' "$missing" | grep -c . || true)
      echo "$((total - left))/$total downloaded"
      [ "$left" -gt 0 ] || break
      if [ $((count % 10)) -eq 0 ]; then
        n=$((n + 1)); batch="$(printf '%s\n' "$missing" | grep . | head -n 10)"
        echo "BATCH $n ready, $(printf '%s\n' "$batch" | grep -c .) tabs (one at a time):"; printf '%s\n' "$batch" | sed 's/^/  /'
      fi
      read -r m f name <<<"$(printf '%s\n' "$missing" | head -n 1)"
      echo "Showing: $name ($m/$f)"
      show "$(page "$m" "$f")"
      start=$(date +%s); stalled=0; reloaded=0
      while missing_now | grep "^$m $f " >/dev/null; do   # (no grep -q: with pipefail its early exit reads as "arrived")
        sleep 3
        age=$(( $(date +%s) - start ))
        if [ $stalled -eq 0 ] && [ $age -ge 300 ]; then echo "STALLED (5 min): $m $f $name"; stalled=1; fi
        if [ $reloaded -eq 0 ] && [ $age -ge 900 ]; then echo "Reloading $name's page after 15 min"; show "$(page "$m" "$f")"; reloaded=1; fi
      done
      echo "Arrived: $name"
      count=$((count + 1))
    done
    [ -n "$WIN" ] && osascript -e "tell application \"Google Chrome\" to close window id $WIN" >/dev/null 2>&1 || true
    echo "All $total files downloaded. Next: ultimate/ultimate.sh install" ;;
  *) sed -n 2,8p "$0"; exit 2 ;;
esac
