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
    # SkyrimMT's "Install it now?" after each download is answered "Later" and SkyrimMT kept hidden by the poll below
    # (needs Accessibility access for the app running this script), so "Slow download" is the only click
    bounds="${FETCH_BOUNDS:-80,60,1480,1060}"
    total=$(plutil -extract mods raw -o - "$HERE/modlist.json")
    page() { echo "https://www.nexusmods.com/skyrimspecialedition/mods/$1?tab=files&file_id=$2&nmm=1"; }
    missing_now() { "$BIN" "$HERE/modlist.json" --missing; }
    DL="$GAME/downloads"
    TABS="$HERE/cli/fetch-tabs.applescript"
    ms() { perl -MTime::HiRes=time -e 'printf "%d", time*1000'; }
    # a .part for mod $1 begun at or after time $2 (Nexus file names carry the mod id: "Name 12345 1.0 …", "Name-12345-…")
    partfor() { local p b; for p in "$DL"/*.part; do [ -e "$p" ] || continue; b="$(basename "$p")"
      [[ "$b" =~ (^|[^0-9])$1([^0-9]|$) ]] && [ "$(stat -f %B "$p")" -ge "$2" ] && return 0; done; return 1; }
    ismissing() { printf '%s\n' "$missing" | grep "^$1 $2 " >/dev/null; }
    # Batches of PRELOAD (default 5) pages as tabs of one window at a fixed place: the first is shown; the moment a
    # click hands its nxm link to SkyrimMT (SkyrimMT comes forward), or its download starts or lands, that tab closes
    # and the next shows in the same spot (signals are ignored for 1 s after a switch). When the whole batch has
    # started, 3 s pause, then the next batch. A switched-away file with no download within 30 s is queued again.
    K="${PRELOAD:-5}"
    q=()          # "modID fileID name" per tab, q[0] shown
    pending=" "   # " modID:fileID " downloads under way (or just clicked: modID:fileID@ms)
    inuse() { local e; for e in "${q[@]:-}"; do [ "${e%% *}" = "$1" ] && set -- "$1" "$2" && [ "$(echo "$e" | cut -d' ' -f2)" = "$2" ] && return 0; done
      [[ "$pending" == *" $1:$2@"* || "$pending" == *" $1:$2 "* ]]; }
    nextfile() { local m f rest; while read -r m f rest; do [ -n "$m" ] || continue; inuse "$m" "$f" || { echo "$m $f $rest"; return; }; done <<<"$missing"; }
    missing="$(missing_now)"; left=$(printf '%s' "$missing" | grep -c . || true)
    echo "$((total - left))/$total downloaded"
    # downloads already running (a .part carrying the mod id) count as under way
    while read -r m f rest; do [ -n "$m" ] && partfor "$m" 0 && pending="$pending$m:$f " && echo "Already downloading: $rest"; done <<<"$missing"
    urls=(); for ((k = 0; k < K; k++)); do e="$(nextfile)"; [ -n "$e" ] || break; q+=("$e"); urls+=("$(page $(echo "$e" | cut -d' ' -f1-2))"); done
    [ ${#q[@]} -gt 0 ] || { echo "All $total files downloaded. Next: ultimate/ultimate.sh install"; exit 0; }
    osascript "$TABS" poll >/dev/null 2>&1 || true   # opening SkyrimMT above brought it forward: not a click
    WIN="$(osascript "$TABS" init "$bounds" "${urls[@]}")"
    shownAt=$(ms); lastSwitch=$shownAt; stalled=0; tick=0; n=1
    echo "BATCH 1 ready, ${#q[@]} tabs preloaded; showing: ${q[0]}"
    while :; do
      sleep 0.25; tick=$((tick + 1))
      r="$(osascript "$TABS" poll 2>/dev/null || true)"
      if [ $((tick % 8)) -eq 0 ] || [ "$r" = "done" ]; then
        missing="$(missing_now)"; left=$(printf '%s' "$missing" | grep -c . || true)
        # clicked files: confirmed once a .part shows up or the file lands; back in the queue after 30 s without either
        np=" "; for p in $pending; do key="${p%@*}"; m="${key%%:*}"; f="${key##*:}"
          ismissing "$m" "$f" || continue
          if [[ "$p" == *@* ]]; then t="${p##*@}"
            if partfor "$m" $((t / 1000 - 2)); then np="$np$key "
            elif [ $(( $(ms) - t )) -lt 30000 ]; then np="$np$p "
            else echo "No download started for $m/$f after the click; queued again"; fi
          else np="$np$key "; fi
        done; pending="$np"
        [ "$left" -gt 0 ] || break
      fi
      if [ ${#q[@]} -eq 0 ]; then   # batch done: 3 s pause, then the next batch of K in a fresh window at the same place
        [ -z "$(nextfile)" ] && { [ "$left" -eq 0 ] && break; continue; }
        sleep 3; osascript "$TABS" close "$WIN" >/dev/null 2>&1 || true
        urls=(); for ((k = 0; k < K; k++)); do e="$(nextfile)"; [ -n "$e" ] || break; q+=("$e"); urls+=("$(page $(echo "$e" | cut -d' ' -f1-2))"); done
        WIN="$(osascript "$TABS" init "$bounds" "${urls[@]}")"; shownAt=$(ms); lastSwitch=$shownAt; stalled=0; reloads=0; n=$((n + 1))
        echo "BATCH $n ready, ${#q[@]} tabs ($((total - left))/$total downloaded); showing: ${q[0]}"; continue
      fi
      read -r m f name <<<"${q[0]}"
      why=""
      [ $(( $(ms) - ${lastSwitch:-0} )) -lt 1000 ] && continue   # 1 s after a switch: ignore (no double click onto the next page)
      if [ "$r" = "click" ]; then why="click"
      elif partfor "$m" $((shownAt / 1000)); then why="download started"
      elif ! ismissing "$m" "$f"; then why="arrived"; fi
      if [ -n "$why" ]; then
        t0=$(ms)
        [ "$why" = "arrived" ] || pending="$pending$m:$f@$t0 "
        q=("${q[@]:1}")
        if [ ${#q[@]} -gt 0 ]; then loading="$(osascript "$TABS" advance "$WIN" "")"; else loading=""; fi
        t1=$(ms); lastSwitch=$t1
        echo "$name: $why → next page in $((t1 - t0)) ms (+ up to 250 ms poll)$([ "$loading" = "true" ] && echo ", page still loading")"
        [ ${#q[@]} -gt 0 ] && { echo "Showing: ${q[0]}"; shownAt=$t1; stalled=0; reloads=0; }
      else
        age=$(( $(ms) - shownAt ))
        # watchdog: nothing happened for 20 s (then every 60 s): reload the shown page and bring the window forward
        if [ $age -ge $(( 20000 + 60000 * ${reloads:-0} )) ]; then osascript "$TABS" refresh "$WIN" >/dev/null 2>&1 || true; reloads=$(( ${reloads:-0} + 1 )); echo "Watchdog: reloaded $name's page"; fi
        if [ $stalled -eq 0 ] && [ $age -ge 300000 ]; then echo "STALLED (5 min): $m $f $name"; stalled=1; fi
      fi
    done
    osascript "$TABS" close "$WIN" >/dev/null 2>&1 || true
    echo "All $total files downloaded. Next: ultimate/ultimate.sh install" ;;
  *) sed -n 2,8p "$0"; exit 2 ;;
esac
