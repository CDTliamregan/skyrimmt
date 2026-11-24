# LoreRim on a Mac with SkyrimMT

This fork of [SkyrimMT](https://github.com/HorrorPills/skyrimmt) adds a LoreRim helper and this guide. Everything
LoreRim-specific lives in this `lorerim/` folder, so updates from the original SkyrimMT merge in without conflicts
(see [Staying up to date](#staying-up-to-date)).

The target is a stable, playable LoreRim on an Apple Silicon Mac, using LoreRim's **Community Shaders** profile
instead of ENB, with Community Shaders **Upscaling off**.

## What LoreRim needs (from [LoreRim's read-me](https://lorerim.com/read-me.html), checked 2026-11-24)

- Skyrim Special Edition **with the paid Anniversary Edition upgrade**, from Steam. GOG doesn't work for this.
- LoreRim runs Skyrim **1.5.97** with the Creation Club content of **1.6.1170**. In SkyrimMT that means downloading
  Skyrim 1.6.1170 with the version switcher. The LoreRim Wabbajack file then builds the rest from it.
- About **550 GB** free: ~300 GB of downloads and ~250 GB installed. Use the internal SSD, not an external or
  spinning drive.
- A Nexus Mods account with **Premium**, so Wabbajack can download everything on its own.
- On Windows LoreRim asks for a 40 GB pagefile. A Mac manages swap on its own, so there is nothing to set. With
  128 GB of memory you are far above LoreRim's recommendation (32 GB for 1440p).

## Step by step

1. **Install SkyrimMT** from this fork's Releases (or the original's) and open it.
   The Steam app you may already have on your Mac is not the one SkyrimMT uses: SkyrimMT installs its own copy of
   Steam for Windows inside its game folder (`~/Games/skyrim`). You sign in to it once with the same Steam account.
2. **Setup → Set up everything.** Sign in to Steam when asked and let it install Skyrim.
3. **Get the Anniversary Edition content.** Make sure your Steam account owns the Anniversary Edition upgrade.
   Press Play once, wait for the main menu, and let the game download its Creation Club content. Then quit.
   Don't "verify game files" afterwards.
4. **Downgrade (the Skyrim version LoreRim uses):** Game tab → **Skyrim version** → **1.6.1170** → Download.
   It signs in to Steam with a QR code in the Steam mobile app and downloads only the files that differ. Your normal
   Steam install stays as it is.
5. **Nexus:** Mod Manager → Essentials → add your Nexus API key (Premium account).
6. **Install LoreRim:** Mod Manager → Wabbajack → LoreRim → Install. This takes many hours. The log is in
   `~/Games/skyrim/logs/wabbajack-LoreRim.log`. If it says the list needs another Skyrim version, do step 4 with
   the version it names.
7. **Pick LoreRim's Performance profile.** That is LoreRim's Community Shaders profile. The Normal and Ultra
   profiles use ENB, which doesn't run under Wine. Saves don't carry over between LoreRim's profiles.
8. **Turn off DLAA.** LoreRim's DLAA mod needs an NVIDIA RTX card. Untick the DLAA mod near the bottom of the load
   order. (LoreRim's own rule for cards without DLSS: DLAA off, TAA on. Step 9 turns TAA on.)
9. **Run the helper** (Terminal, from the folder you cloned this fork into):

   ```sh
   lorerim/lorerim.sh apply   # newest Metal renderer, Microsoft shader compiler and audio, TAA on
   lorerim/lorerim.sh check   # everything should say OK
   ```

10. **Play.** The first start compiles Community Shaders' shaders and takes several minutes. Later starts are
    faster. LoreRim's own first-start steps still apply, such as opening the inventory once to start Requiem.

SkyrimMT already leaves out Community Shaders' Upscaling feature when it deploys a profile, because Upscaling needs
Direct3D 12, which macOS doesn't have. `lorerim.sh check` confirms that it's off.

## When something goes wrong

```sh
lorerim/lorerim.sh check   # what isn't ready, with the fix for each problem
lorerim/lorerim.sh logs    # puts SkyrimMT's logs and the newest crash logs in one zip on your Desktop
```

Send the zip along when asking for help. Where to look yourself:

| Problem | Look at |
|---|---|
| Wabbajack install stops | `~/Games/skyrim/logs/wabbajack-LoreRim.log` (the last lines name the file or mod) |
| Game doesn't start | `~/Games/skyrim/logs/skyrim.log`. "SKSE is for Skyrim x, the game is y" means the wrong Skyrim version is selected (step 4) |
| Crash in game | SkyrimMT → Crash page reads the Crash Logger logs and names the likely mod |
| Black screen or shader errors | `lorerim/lorerim.sh check`: shader compiler and Metal renderer lines |

If SKSE refuses to start because of a version mismatch that you know is fine (LoreRim brings its own 1.5.97 game
files), the Mods tab has **Start SKSE anyway**. Use it only when the check above says the right version is downloaded.

## What this fork changes, and what it leaves alone

- Adds lorerim/ (this guide, lorerim.sh and the ready-to-enable daily sync). Nothing else.
- Doesn't change LoreRim's mods or balance, and doesn't try to make ENB work.

## Staying up to date

- The daily automatic sync is ready in lorerim/sync-upstream.yml.txt. To turn it on, move it to .github/workflows/sync-upstream.yml (this needs GitHub's workflow permission: gh auth refresh -h github.com -s workflow). Until then, use Sync fork → Update branch on the repository page.
- Keep LoreRim fixes inside `lorerim/` where possible. Upstream then never touches the same files.

For working from a local clone:

```sh
git remote add upstream https://github.com/HorrorPills/skyrimmt.git   # once
git fetch upstream && git merge upstream/main                         # whenever you want the latest
```
