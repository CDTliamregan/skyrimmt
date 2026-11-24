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
    pgrep -f "$APP/Contents/MacOS" >/dev/null || { open -gj "$APP"; sleep 3; }   # running already: leave it be
    # SkyrimMT's "Install it now?" after each download is answered "Later" and SkyrimMT kept hidden by the poll below
    # (needs Accessibility access for the app running this script), so "Slow download" is the only click
    bounds="${FETCH_BOUNDS:-80,60,1480,1060}"
    total=$(plutil -extract mods raw -o - "$HERE/modlist.json")
    page() { echo "https://www.nexusmods.com/skyrimspecialedition/mods/$1?tab=files&file_id=$2&nmm=1"; }
    missing_now() { "$BIN" "$HERE/modlist.json" --missing; }
    DL="$GAME/downloads"
    TABS="$HERE/cli/fetch-tabs.applescript"
    ms() { perl -MTime::HiRes=time -e 'printf "%d", time*1000'; }
    # the .part of mod $1 (Nexus file names carry the mod id: "Name 12345 1.0 …", "Name-12345-…"), if one exists
    partof() { local p b; for p in "$DL"/*.part; do [ -e "$p" ] || continue; b="$(basename "$p")"
      [[ "$b" =~ (^|[^0-9])$1([^0-9]|$) ]] && { echo "$p"; return 0; }; done; return 1; }
    growing() { local p; p="$(partof "$1")" && [ $(( $(date +%s) - $(stat -f %m "$p") )) -lt "${2:-60}" ]; }   # written in the last $2 s
    ismissing() { printf '%s\n' "$missing" | grep "^$1 $2 " >/dev/null; }
    sizes=" $(plutil -convert json -o - "$HERE/modlist.json" | python3 -I -c 'import json,sys
print(" ".join("%d:%d:%d" % (m["source"]["modId"], m["source"]["fileId"], m["source"].get("fileSize", 0)) for m in json.load(sys.stdin)["mods"]))') "
    sizeof() { local e="${sizes#* $1:$2:}"; [ "$e" = "$sizes" ] && echo 0 || echo "${e%% *}"; }
    # Batches of PRELOAD (default 5) pages as tabs of one window at a fixed place: the first is shown; when a click
    # hands its nxm link to SkyrimMT (SkyrimMT comes forward) or its download starts or lands, that tab closes and
    # the next shows in the same spot (signals ignored for 1 s after a switch). When the whole batch has started,
    # 3 s pause, then the next batch, held while 3+ big (>500 MB) downloads are running so the connection stays usable.
    # Light touch: checks every 2 s, SkyrimMT's "Install it now?" answered at most every 4 s, Chrome only touched on a
    # switch. A clicked file whose download doesn't start within 30 s, or stops growing for 2 min, is queued again.
    K="${PRELOAD:-5}"
    q=()          # "modID fileID name" per tab, q[0] shown
    pending=" "   # " modID:fileID " running downloads; " modID:fileID@ms " just clicked, not yet confirmed
    inuse() { local e; for e in "${q[@]:-}"; do [ "$(echo "$e" | cut -d' ' -f1-2)" = "$1 $2" ] && return 0; done
      [[ "$pending" == *" $1:$2@"* || "$pending" == *" $1:$2 "* ]]; }
    nextfile() { local m f rest; while read -r m f rest; do [ -n "$m" ] || continue; inuse "$m" "$f" || { echo "$m $f $rest"; return; }; done <<<"$missing"; }
    bigrunning() { local c=0 p key; for p in $pending; do key="${p%@*}"; [ "$(sizeof "${key%%:*}" "${key##*:}")" -gt 524288000 ] && growing "${key%%:*}" && c=$((c + 1)); done; echo $c; }
    newbatch() {
      q=(); local urls=() e k
      for ((k = 0; k < K; k++)); do e="$(nextfile)"; [ -n "$e" ] || break; q+=("$e"); urls+=("$(page $(echo "$e" | cut -d' ' -f1-2))"); done
      [ ${#q[@]} -gt 0 ] || return 1
      [ -n "${WIN:-}" ] && osascript "$TABS" close "$WIN" >/dev/null 2>&1
      WIN="$(osascript "$TABS" init "$bounds" "${urls[@]}")"; shownAt=$(ms); lastSwitch=$shownAt; stalled=0; reloads=0; n=$((n + 1))
      echo "BATCH $n ready, ${#q[@]} tabs ($((total - left))/$total downloaded); showing: ${q[0]}"
    }
    missing="$(missing_now)"; left=$(printf '%s' "$missing" | grep -c . || true)
    echo "$((total - left))/$total downloaded"
    # downloads SkyrimMT is still writing count as under way; stopped .part files need their page clicked again
    while read -r m f rest; do [ -n "$m" ] && growing "$m" && pending="$pending$m:$f " && echo "Already downloading: $rest"; done <<<"$missing"
    osascript "$TABS" poll >/dev/null 2>&1 || true   # opening SkyrimMT above brought it forward: not a click
    n=0; WIN=""; tick=0; held=0
    while :; do
      sleep 2; tick=$((tick + 1)); r=""
      [ $((tick % 2)) -eq 0 ] && r="$(osascript "$TABS" poll 2>/dev/null || true)"
      missing="$(missing_now)"; left=$(printf '%s' "$missing" | grep -c . || true)
      np=" "; for p in $pending; do key="${p%@*}"; m="${key%%:*}"; f="${key##*:}"
        ismissing "$m" "$f" || continue
        if [[ "$p" == *@* ]]; then t="${p##*@}"
          if partof "$m" >/dev/null && growing "$m" 30; then np="$np$key "
          elif [ $(( $(ms) - t )) -lt 30000 ]; then np="$np$p "
          else echo "No download started for $m/$f after the click; queued again"; fi
        elif growing "$m" 120; then np="$np$key "
        else echo "Download of $m/$f stopped; queued again"; fi
      done; pending="$np"
      if [ "$left" -eq 0 ]; then break; fi
      if [ ${#q[@]} -eq 0 ]; then
        [ -n "$(nextfile)" ] || continue
        if [ "$(bigrunning)" -ge 3 ]; then [ $held -eq 0 ] && echo "Holding the next batch: 3+ big downloads running"; held=1; continue; fi
        held=0; sleep 3; newbatch; continue
      fi
      [ $(( $(ms) - lastSwitch )) -lt 1000 ] && continue
      read -r m f name <<<"${q[0]}"
      why=""
      if [ "$r" = "click" ]; then why="click"
      elif p="$(partof "$m")" && [ "$(stat -f %B "$p")" -ge $((shownAt / 1000)) ]; then why="download started"
      elif ! ismissing "$m" "$f"; then why="arrived"; fi
      if [ -n "$why" ]; then
        t0=$(ms); [ "$why" = "arrived" ] || pending="$pending$m:$f@$t0 "
        q=("${q[@]:1}")
        if [ ${#q[@]} -gt 0 ]; then osascript "$TABS" advance "$WIN" "" >/dev/null; echo "$name: $why → next page in $(( $(ms) - t0 )) ms; showing: ${q[0]}"
        else echo "$name: $why (batch done)"; fi
        shownAt=$(ms); lastSwitch=$shownAt; stalled=0; reloads=0
      else
        age=$(( $(ms) - shownAt ))
        if [ $age -ge $(( 60000 + 120000 * reloads )) ]; then osascript "$TABS" refresh "$WIN" >/dev/null 2>&1 || true; reloads=$((reloads + 1)); echo "Watchdog: reloaded $name's page"; fi
        if [ $stalled -eq 0 ] && [ $age -ge 300000 ]; then echo "STALLED (5 min): $m $f $name"; stalled=1; fi
      fi
    done
    [ -n "$WIN" ] && osascript "$TABS" close "$WIN" >/dev/null 2>&1 || true
    echo "All $total files downloaded. Next: ultimate/ultimate.sh install" ;;
  *) sed -n 2,8p "$0"; exit 2 ;;
esac
