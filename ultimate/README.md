# Ultimate Skyrim for SkyrimMT

A ready-made, Mac-friendly **vanilla-plus** mod list for Skyrim Anniversary Edition on SkyrimMT: Skyrim should
still feel like Skyrim, just fixed, polished and with new lore-friendly places and quests (several picked from
LoreRim's list). It favours **stability under Wine/DXMT**: 75 files, ~18 GB of downloads, no ENB, no generated LODs,
no behaviour or body tools to run, and no overhauls of combat, perks or races.

- **Skyrim 1.7.104** (the current Steam build). No downgrade: every SKSE plugin below has a 1.7.104 build
  (checked on Nexus 2026-11-24).
- **Community Shaders** instead of ENB. SkyrimMT already leaves out its Upscaling feature (needs Direct3D 12).
- Installed into its **own profile, "Ultimate Skyrim"**, so the other profiles stay as they are.
- **Alternate Perspective** replaces the cart ride with a voiced, story-driven start: you choose who you are in
  Helgen before the dragon attack, and each start leads into its own short quest.
- Core gameplay stays vanilla. New content is added beside it: new lands (Bruma, Wyrmstooth), quests, spells,
  enchantments and shouts.

## Install

Needs: SkyrimMT set up, the Anniversary Edition content downloaded in-game, a **Nexus Premium** API key saved in
SkyrimMT (Mod Manager → Essentials), and the Xcode Command Line Tools. In Terminal, from this fork's folder:

```sh
ultimate/ultimate.sh check     # builds the installer, checks your key and that every file is downloadable
ultimate/ultimate.sh install   # quits SkyrimMT, downloads, installs, sorts with LOOT, deploys, reopens SkyrimMT
```

**Free Nexus account:** run `ultimate/ultimate.sh fetch` before `install`. It makes SkyrimMT the nxm:// handler, opens the pages of the missing files in Chrome ten at a time, and waits while you click "Slow download" on each (SkyrimMT downloads it). `install` then installs from the downloads folder.

**Partial install:** `ultimate/ultimate.sh install --available` installs only the files already in the downloads folder and leaves out every entry whose requirements are missing (`ultimate/deps.json`); `check --available` prints that plan. Missing plugin masters are reported after the install.

SkyrimMT.app is found automatically wherever it is installed (set `SKYRIMMT_APP` to override). With Swift 6.2, the build falls back to a patched copy of ModKit (`ultimate/cli/modkit-swift62.patch`); `app/ModKit` stays untouched.

The log is `~/Games/skyrim/logs/ultimate-install.log`. Running `install` again resumes: finished mods are reused.

The installer is SkyrimMT's own collection installer (`app/ModKit/Collections.swift`) fed with a local
`modlist.json` in Nexus collection format, so downloads, FOMOD choices, staging and deploy work exactly as for a
Nexus collection. FOMOD installers get their default choices; plugin order comes from LOOT.

## First start

1. Press Play. The first start compiles Community Shaders' shaders and takes several minutes.
2. Start a new game and follow Alternate Perspective's prompts to pick who you are in Helgen.
3. Wait a minute in game while the mods' menus (MCM) register. Settings are under System → Mod Configuration.

## The list

**Foundation (fixes, script extenders, frameworks, menus)**

- [SKSE64 (Steam, 1.7.104)](https://www.nexusmods.com/skyrimspecialedition/mods/30379) 2.3.1
- [Address Library for SKSE Plugins](https://www.nexusmods.com/skyrimspecialedition/mods/32444) 13
- [SSE Engine Fixes (1.7.99+)](https://www.nexusmods.com/skyrimspecialedition/mods/17230) 7.0.21
- [SSE Engine Fixes - SKSE64 Preloader](https://www.nexusmods.com/skyrimspecialedition/mods/17230) 7
- [Crash Logger SSE AE VR](https://www.nexusmods.com/skyrimspecialedition/mods/59818) 1.27.0
- [SSE Display Tweaks](https://www.nexusmods.com/skyrimspecialedition/mods/34705) 0.5.25
- [Bug Fixes SSE (1.7.99+)](https://www.nexusmods.com/skyrimspecialedition/mods/33261) 10
- [powerofthree's Tweaks](https://www.nexusmods.com/skyrimspecialedition/mods/51073) 1.18.0
- [PapyrusUtil AE SE](https://www.nexusmods.com/skyrimspecialedition/mods/13048) 4.8
- [powerofthree's Papyrus Extender](https://www.nexusmods.com/skyrimspecialedition/mods/22854) 6.5.2
- [Spell Perk Item Distributor](https://www.nexusmods.com/skyrimspecialedition/mods/36869) 7.3.3
- [Keyword Item Distributor](https://www.nexusmods.com/skyrimspecialedition/mods/55728) 4.1.0
- [Base Object Swapper](https://www.nexusmods.com/skyrimspecialedition/mods/60805) 3.5.0
- [SkyUI](https://www.nexusmods.com/skyrimspecialedition/mods/12604) 6.11
- [MCM Helper](https://www.nexusmods.com/skyrimspecialedition/mods/53000) 1.6.3
- [UIExtensions](https://www.nexusmods.com/skyrimspecialedition/mods/17561) 1.2.0
- [Unofficial Skyrim Special Edition Patch](https://www.nexusmods.com/skyrimspecialedition/mods/266) 4.3.9c
- [Unofficial Creation Club Content Patches](https://www.nexusmods.com/skyrimspecialedition/mods/18975) 8.5
- [JContainers SE](https://www.nexusmods.com/skyrimspecialedition/mods/16495) 4.3.4
- [Fuz Ro D'oh](https://www.nexusmods.com/skyrimspecialedition/mods/15109) 2.6

**New start, quests, lands and world content**

- [Cutting Room Floor](https://www.nexusmods.com/skyrimspecialedition/mods/276) 3.1.26
- [Interesting NPCs 3DNPC](https://www.nexusmods.com/skyrimspecialedition/mods/29194) 4.5
- [Interesting NPCs 4.54 Update](https://www.nexusmods.com/skyrimspecialedition/mods/29194) 4.54
- [Obscure's College of Winterhold](https://www.nexusmods.com/skyrimspecialedition/mods/20514) 1.6.1
- [Obscure's College of Winterhold - Script Fix](https://www.nexusmods.com/skyrimspecialedition/mods/62720) 1.0
- [Immersive Citizens - AI Overhaul AE](https://www.nexusmods.com/skyrimspecialedition/mods/173) 0.4.0.2
- [Beyond Skyrim - Bruma](https://www.nexusmods.com/skyrimspecialedition/mods/10917) 2.0.1
- [Wyrmstooth](https://www.nexusmods.com/skyrimspecialedition/mods/45565) 1.20.3
- [Wyrmstooth - Dragonborn Compatibility Patch](https://www.nexusmods.com/skyrimspecialedition/mods/45565) 1.0.1-dbp
- [Wyrmstooth - Hearthfire Compatibility Patch](https://www.nexusmods.com/skyrimspecialedition/mods/45565) 1.0.0-hfp
- [The Forgotten City](https://www.nexusmods.com/skyrimspecialedition/mods/1179) 1.8
- [Clockwork](https://www.nexusmods.com/skyrimspecialedition/mods/4155) 1.0
- [The Gray Cowl of Nocturnal](https://www.nexusmods.com/skyrimspecialedition/mods/4509) 1.3
- [Moon and Star](https://www.nexusmods.com/skyrimspecialedition/mods/4301) 3.2
- [The Brotherhood of Old](https://www.nexusmods.com/skyrimspecialedition/mods/15322) 2.0.0
- [Missives](https://www.nexusmods.com/skyrimspecialedition/mods/17576) 2.03
- [Run For Your Lives](https://www.nexusmods.com/skyrimspecialedition/mods/2272) 4.0.8
- [Alternate Perspective - Alternate Start](https://www.nexusmods.com/skyrimspecialedition/mods/50307) 4.1.0
- [Alternate Perspective - Anniversary Edition Bone Wolf Patch](https://www.nexusmods.com/skyrimspecialedition/mods/50307) 2.6
- [Alternate Perspective - Voiced Addon](https://www.nexusmods.com/skyrimspecialedition/mods/96865) 1.20

**Cities**

- [JK's Skyrim](https://www.nexusmods.com/skyrimspecialedition/mods/6289) 1.7
- [Dawn of Skyrim (Director's Cut)](https://www.nexusmods.com/skyrimspecialedition/mods/9074) 1.5
- [JK's Skyrim - Dawn of Skyrim - Patch](https://www.nexusmods.com/skyrimspecialedition/mods/16852) 1.6

**New spells, enchantments and shouts (added, nothing replaced)**

- [Apocalypse - Magic of Skyrim](https://www.nexusmods.com/skyrimspecialedition/mods/1090) 10.3.0
- [Summermyst - Enchantments of Skyrim](https://www.nexusmods.com/skyrimspecialedition/mods/6285) 4.2.0
- [Thunderchild - Epic Shouts and Immersion](https://www.nexusmods.com/skyrimspecialedition/mods/1460) 4.11SSE

**Gameplay (added Nov 26, 2026)**

- [Ordinator - Perks of Skyrim](https://www.nexusmods.com/skyrimspecialedition/mods/1137) 9.35.0
- [Odin - Skyrim Magic Overhaul](https://www.nexusmods.com/skyrimspecialedition/mods/46000) 3.2.0 (+ Odin - Ordinator Compatibility Patch)
- [True Directional Movement](https://www.nexusmods.com/skyrimspecialedition/mods/51614) 2.3.1
- [Precision](https://www.nexusmods.com/skyrimspecialedition/mods/72347) 2.0.6
- [Open Animation Replacer](https://www.nexusmods.com/skyrimspecialedition/mods/92109) 3.2.1
- [Valhalla Combat - 1.7.104 update](https://www.nexusmods.com/skyrimspecialedition/mods/191704) 1.1 (unofficial update of dTry's Valhalla Combat)
- [Better Jumping NG](https://www.nexusmods.com/skyrimspecialedition/mods/18967) 1.9.5
- [Mortal Enemies SE](https://www.nexusmods.com/skyrimspecialedition/mods/4881) 1.05
- [Pristine Vanilla Movement](https://www.nexusmods.com/skyrimspecialedition/mods/66635) 1.1 (OAR)

MCO was left out: its required Animation Motion Revolution has only unofficial 1.7.104 ports.

**Visuals**

- [Static Mesh Improvement Mod - SMIM](https://www.nexusmods.com/skyrimspecialedition/mods/659) 2.08
- [SMIM - Farming Creation Club Patch](https://www.nexusmods.com/skyrimspecialedition/mods/659) 1.0
- [Skyland AIO](https://www.nexusmods.com/skyrimspecialedition/mods/34179) 4.32
- [Embers XD](https://www.nexusmods.com/skyrimspecialedition/mods/37085) 3.3.0
- [Cathedral Weathers and Seasons](https://www.nexusmods.com/skyrimspecialedition/mods/24791) 2.23c
- [A Quality World Map](https://www.nexusmods.com/skyrimspecialedition/mods/5804) 9.0.1
- [Unique Uniques](https://www.nexusmods.com/skyrimspecialedition/mods/3334) 1.1
- [Book Covers Skyrim (Original)](https://www.nexusmods.com/skyrimspecialedition/mods/901) 4.2
- [Lanterns of Skyrim II](https://www.nexusmods.com/skyrimspecialedition/mods/30817) v4.3

**Sound, HUD and quality of life**

- [Audio Overhaul for Skyrim](https://www.nexusmods.com/skyrimspecialedition/mods/12466) 4.1.3
- [Better Dialogue Controls](https://www.nexusmods.com/skyrimspecialedition/mods/1429) 1.2
- [Better MessageBox Controls](https://www.nexusmods.com/skyrimspecialedition/mods/1428) 1.2
- [moreHUD](https://www.nexusmods.com/skyrimspecialedition/mods/12688) 5.4.7.0
- [TrueHUD](https://www.nexusmods.com/skyrimspecialedition/mods/62775) 1.1.10
- [QuickLoot IE](https://www.nexusmods.com/skyrimspecialedition/mods/120075) 4.1.3
- [Simple Activate SKSE](https://www.nexusmods.com/skyrimspecialedition/mods/56767) 1.5.0

**Renderer**

- [Community Shaders](https://www.nexusmods.com/skyrimspecialedition/mods/86492) 1.9.1
- [Terrain Shadows - Heightmaps](https://www.nexusmods.com/skyrimspecialedition/mods/135817) 1.0.0 (installed disabled)
- [Wetness Effects - Community Shaders](https://www.nexusmods.com/skyrimspecialedition/mods/112739) 3.1.0 (installed disabled)

Entries with `"enabled": false` are installed but left off, to be enabled and tested one at a time. Grass Lighting,
Cloud Shadows and Terrain Shadows are built into Community Shaders 1.9.1; Tree LOD Lighting has no build for it.

## Left out on purpose

ENB and ENB-only effects (don't run under Wine), DynDOLOD/xLODGen output and grass caches (long Windows tool runs),
animation frameworks that need Pandora/Nemesis runs, body/BodySlide mods, mods without a 1.7.104 build
(RaceMenu, Scrambled Bugs, Quick Loot RE), and overhauls that change how core Skyrim plays (combat, perk, race,
standing-stone and vampire overhauls, heavy parallax textures), and Helgen Reborn (it clashes with Alternate
Perspective's Helgen).

## Changing the list

Edit `modlist.json`: each entry is a Nexus mod id and file id. `phase` sets which mods win file conflicts (higher
wins). Run `check` after a change.
