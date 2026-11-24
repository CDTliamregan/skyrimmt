#!/bin/bash
# LoreRim helper for this fork of SkyrimMT. Lives in its own folder (lorerim/) and only calls SkyrimMT's own scripts,
# so upstream updates merge without conflicts. Plain-English guide: lorerim/README.md.
#   lorerim/lorerim.sh check    read-only: is this Mac and this game folder ready for LoreRim? (OK / WARN / FAIL lines)
#   lorerim/lorerim.sh apply    the LoreRim settings: newest Metal renderer, Microsoft's shader compiler and audio,
#                               TAA on (LoreRim's rule for GPUs without DLSS). Quit Skyrim and Steam first.
#   lorerim/lorerim.sh logs     collect SkyrimMT's logs and the newest crash logs into one zip on the Desktop
# LoreRim facts used here (lorerim.com/read-me.html, checked 2026-11-24): the list runs Skyrim 1.5.97 with the
# Creation Club content of 1.6.1170, needs the paid Anniversary Edition upgrade, ~550 GB (download + install),
# its "Performance" profile uses Community Shaders instead of ENB, and DLAA must be off without an NVIDIA RTX card.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../scripts/_env.sh"
. "$SKYRIMMT_ROOT/scripts/ini.sh"
. "$SKYRIMMT_ROOT/config/release.conf" 2>/dev/null || true

LORERIM_GAME_VERSION="1.6.1170"   # what the list's Wabbajack file asks for (it brings its own 1.5.97 game files)
NEED_GB=550                       # LoreRim: ~300 GB downloads + ~250 GB install
PREFS="$MYGAMES_DIR/SkyrimPrefs.ini"

ok=0; warn=0; bad=0
say()  { printf '%-5s %s\n' "$1" "$2"; case $1 in OK) ok=$((ok + 1)) ;; WARN) warn=$((warn + 1)) ;; FAIL) bad=$((bad + 1)) ;; esac; }
free_gb() { local d=$1; while [ ! -d "$d" ]; do d=$(dirname "$d"); done; df -Pk "$d" | awk 'NR == 2 { printf "%d", $4 / 1048576 }'; }

check() {
  # --- the Mac
  [ "$(uname -m)" = arm64 ] && say OK "Apple Silicon" || say FAIL "not an Apple Silicon Mac ($(uname -m))"
  local mac; mac=$(sw_vers -productVersion 2>/dev/null)
  if [ -n "$mac" ] && [ "${mac%%.*}" -ge 15 ]; then say OK "macOS $mac"; else say FAIL "macOS ${mac:-?}: SkyrimMT needs macOS 15 or newer"; fi
  local ram; ram=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824 ))
  if [ "$ram" -ge 32 ]; then say OK "${ram} GB memory (LoreRim asks for 16-32 GB plus a 40 GB Windows pagefile; macOS swaps on its own)"
  else say WARN "${ram} GB memory: LoreRim asks for at least 16 GB, 32 GB for 1440p"; fi
  local gb; gb=$(free_gb "$SKYRIM_HOME")
  if [ "${gb:-0}" -ge "$NEED_GB" ]; then say OK "${gb} GB free for $SKYRIM_HOME"
  else say WARN "${gb:-?} GB free for $SKYRIM_HOME: LoreRim needs about $NEED_GB GB (downloads can be deleted after the install)"; fi

  # --- SkyrimMT's game folder
  [ -x "$WINE" ] && say OK "Wine runtime installed" || { say FAIL "SkyrimMT isn't set up yet: open SkyrimMT → Setup → Set up everything"; summary; return; }
  is_gog && say FAIL "this is the GOG version: LoreRim's Skyrim version comes from Steam (Setup → Skyrim from: Steam)" || say OK "Skyrim from Steam"
  local base_v; base_v=$(GAMEDIR="$BASE_GAMEDIR" "$SKYRIMMT_ROOT/scripts/settings.sh" status 2>/dev/null | sed -n 's/^game_version=//p')
  [ -n "$base_v" ] && say OK "Steam's Skyrim is ${base_v%.0}" || say FAIL "Skyrim is not installed in Steam yet"
  local cc; cc=$(ls "$BASE_GAMEDIR/Data" 2>/dev/null | grep -ciE '^cc.*\.es[lm]$')
  if [ "${cc:-0}" -ge 70 ] && [ -f "$BASE_GAMEDIR/Data/_ResourcePack.esl" ]; then say OK "Anniversary Edition content downloaded ($cc Creation Club files)"
  else say FAIL "Anniversary Edition content missing (${cc:-0} Creation Club files): own the AE upgrade, start the game once to the main menu and let it download"; fi
  if [ -f "$SKYRIM_HOME/versions/$LORERIM_GAME_VERSION/.skyrimmt-version" ]; then say OK "Skyrim $LORERIM_GAME_VERSION downloaded (the downgrade LoreRim needs)"
  else say FAIL "Skyrim $LORERIM_GAME_VERSION not downloaded: Game tab → Skyrim version → $LORERIM_GAME_VERSION → Download"; fi

  # --- renderer and shaders
  local dx; dx=$("$SKYRIMMT_ROOT/scripts/dxmt.sh" status 2>/dev/null)
  [ "$dx" = up-to-date ] && say OK "Metal renderer (DXMT ${DXMT_VERSION:-runtime}) up to date" || say WARN "Metal renderer: $dx (run: lorerim/lorerim.sh apply)"
  [ "$(cat "$SKYRIM_HOME/config/d3dcompiler" 2>/dev/null || echo native)" = native ] && say OK "Microsoft shader compiler (Community Shaders needs it)" \
    || say FAIL "Wine's own shader compiler is selected: Community Shaders fails to compile (run: lorerim/lorerim.sh apply)"
  [ "$(audio_mode)" = native ] && say OK "Microsoft XAudio2 (correct sound distances)" || say WARN "Wine's own audio: voices sound far away (run: lorerim/lorerim.sh apply)"

  # --- the deployed game folder (what Play starts)
  if [ -f "$GAMEDIR/Data/Shaders/Features/Upscaling.ini" ]; then say FAIL "Community Shaders Upscaling is deployed: it needs Direct3D 12 and crashes on macOS (deploy the profile again)"
  else say OK "Community Shaders Upscaling off"; fi
  if ls "$GAMEDIR" 2>/dev/null | grep -qiE '^(enbseries|enblocal\.ini|d3d11\.dll|dxgi\.dll)$' && [ ! -f "$SKYRIM_HOME/run/placed-d3d11.dll" ] && [ ! -f "$SKYRIM_HOME/run/placed-dxgi.dll" ]; then
    say FAIL "ENB files in the game folder: pick LoreRim's Performance profile (Community Shaders), ENB doesn't run under Wine"
  else say OK "no ENB in the game folder"; fi
  if ls "$GAMEDIR" "$GAMEDIR/Data/SKSE/Plugins" 2>/dev/null | grep -qiE 'dlaa|nvngx_dlss'; then
    say FAIL "DLAA is on: it needs an NVIDIA RTX card. Turn the DLAA mod off near the bottom of the load order, then run lorerim/lorerim.sh apply (TAA)"
  else say OK "no DLAA"; fi
  if [ -f "$PREFS" ]; then
    [ "$(ini_get "$PREFS" Display bUseTAA)" = 1 ] && say OK "TAA on" || say WARN "TAA off: LoreRim says to turn it on when DLAA is off (run: lorerim/lorerim.sh apply)"
  fi
  summary
}

summary() {
  echo
  echo "$ok OK, $warn warning(s), $bad problem(s)"
  [ "$bad" = 0 ]
}

apply() {
  game_running && { echo "Quit Skyrim first."; exit 1; }
  [ -x "$WINE" ] || { echo "SkyrimMT isn't set up yet: open SkyrimMT → Setup → Set up everything"; exit 1; }
  echo "== Metal renderer"
  "$SKYRIMMT_ROOT/scripts/dxmt.sh" install || echo "   (quit Steam in SkyrimMT and run this again to update the renderer)"
  echo "== Shader compiler and audio"
  "$SKYRIMMT_ROOT/scripts/settings.sh" shaders native
  "$SKYRIMMT_ROOT/scripts/settings.sh" audio native
  echo "== TAA (LoreRim: on when DLAA is off, which is always the case on a Mac)"
  if [ -f "$PREFS" ]; then
    cp -p "$PREFS" "$SKYRIM_HOME/backups/SkyrimPrefs.ini.before-lorerim" 2>/dev/null
    ini_set "$PREFS" Display bUseTAA 1 && echo "TAA on (saved with the current profile when you switch profiles)"
  else echo "no SkyrimPrefs.ini yet: install LoreRim and select its profile first, then run this again"; fi
  echo
  echo "Done. Run lorerim/lorerim.sh check to see where things stand."
}

logs() {
  local out="$HOME/Desktop/lorerim-logs-$(date +%Y%m%d-%H%M%S).zip" tmp
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/lorerim-logs.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
  mkdir -p "$tmp/skyrimmt" "$tmp/crash" "$tmp/skse"
  cp -p "$SKYRIM_HOME"/logs/*.log "$tmp/skyrimmt/" 2>/dev/null
  # the five newest Crash Logger logs, and SKSE's own logs
  ls -t "$MYGAMES_DIR"/SKSE/crash-*.log 2>/dev/null | head -5 | while IFS= read -r f; do cp -p "$f" "$tmp/crash/"; done
  ls "$MYGAMES_DIR"/SKSE/*.log 2>/dev/null | grep -v '/crash-' | while IFS= read -r f; do cp -p "$f" "$tmp/skse/"; done
  "$0" check > "$tmp/check.txt" 2>&1
  { "$SKYRIMMT_ROOT/scripts/settings.sh" status; "$SKYRIMMT_ROOT/scripts/versions.sh" status; } > "$tmp/status.txt" 2>&1
  (cd "$tmp" && zip -qr "$out" .) && echo "Saved $out" || { echo "could not write $out"; exit 1; }
}

case "${1:-check}" in
  check) check ;;
  apply) apply ;;
  logs)  logs ;;
  *) echo "usage: lorerim/lorerim.sh check|apply|logs"; exit 2 ;;
esac
