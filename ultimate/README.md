# Ultimate Skyrim for SkyrimMT

A ready-made, Mac-friendly mod list for Skyrim Anniversary Edition on SkyrimMT. It favours **stability under
Wine/DXMT** over sheer size: about 50 well-maintained mods, ~12 GB of downloads, no ENB, no generated LODs, no
behaviour or body tools to run.

- **Skyrim 1.7.104** (the current Steam build). No downgrade: every SKSE plugin below has a 1.7.104 build
  (checked on Nexus 2026-11-24).
- **Community Shaders** instead of ENB. SkyrimMT already leaves out its Upscaling feature (needs Direct3D 12).
- Installed into its **own profile, "Ultimate Skyrim"**, so the other profiles stay as they are.
- Gameplay is built around Enai Siaion's mods (Adamant, Mysticism, Apocalypse, Summermyst, Thunderchild, Wildcat,
  Sacrosanct, Imperious, Andromeda), which are designed to work together and are light on scripts.

## Install

Needs: SkyrimMT set up, the Anniversary Edition content downloaded in-game, a **Nexus Premium** API key saved in
SkyrimMT (Mod Manager → Essentials), and the Xcode Command Line Tools. In Terminal, from this fork's folder:

```sh
ultimate/ultimate.sh check     # builds the installer, checks your key and that every file is downloadable
ultimate/ultimate.sh install   # quits SkyrimMT, downloads, installs, sorts with LOOT, deploys, reopens SkyrimMT
```

The log is `~/Games/skyrim/logs/ultimate-install.log`. Running `install` again resumes: finished mods are reused.

The installer is SkyrimMT's own collection installer (`app/ModKit/Collections.swift`) fed with a local
`modlist.json` in Nexus collection format, so downloads, FOMOD choices, staging and deploy work exactly as for a
Nexus collection. FOMOD installers get their default choices; plugin order comes from LOOT.

## First start

1. Press Play. The first start compiles Community Shaders' shaders and takes several minutes.
2. Alternate Start puts you in a cell: talk to the statue to pick a start.
3. Wait a minute in game while the mods' menus (MCM) register. Settings are under System → Mod Configuration.

## The list

**Foundation (engine fixes, script extenders, frameworks, menus)**

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

**Content**

- [Cutting Room Floor](https://www.nexusmods.com/skyrimspecialedition/mods/276) 3.1.26
- [Alternate Start - Live Another Life](https://www.nexusmods.com/skyrimspecialedition/mods/272) 4.2.6a
- [Interesting NPCs 3DNPC](https://www.nexusmods.com/skyrimspecialedition/mods/29194) 4.5
- [Interesting NPCs 4.54 Update](https://www.nexusmods.com/skyrimspecialedition/mods/29194) 4.54
- [Obscure's College of Winterhold](https://www.nexusmods.com/skyrimspecialedition/mods/20514) 1.6.1
- [Obscure's College of Winterhold - Script Fix](https://www.nexusmods.com/skyrimspecialedition/mods/62720) 1.0
- [Immersive Citizens - AI Overhaul AE](https://www.nexusmods.com/skyrimspecialedition/mods/173) 0.4.0.2

**Gameplay**

- [Adamant - A Perk Overhaul](https://www.nexusmods.com/skyrimspecialedition/mods/30191) 6.0.4
- [Mysticism - A Magic Overhaul](https://www.nexusmods.com/skyrimspecialedition/mods/27839) 2.5.0
- [Apocalypse - Magic of Skyrim](https://www.nexusmods.com/skyrimspecialedition/mods/1090) 10.3.0
- [Summermyst - Enchantments of Skyrim](https://www.nexusmods.com/skyrimspecialedition/mods/6285) 4.2.0
- [Thunderchild - Epic Shouts and Immersion](https://www.nexusmods.com/skyrimspecialedition/mods/1460) 4.11SSE
- [Wildcat - Combat of Skyrim](https://www.nexusmods.com/skyrimspecialedition/mods/1368) 7.1.0
- [Sacrosanct - Vampires of Skyrim](https://www.nexusmods.com/skyrimspecialedition/mods/3928) 6.0.0
- [Imperious - Races of Skyrim](https://www.nexusmods.com/skyrimspecialedition/mods/1315) 7.28.0
- [Andromeda - Unique Standing Stones](https://www.nexusmods.com/skyrimspecialedition/mods/14910) 1.1.2
- [Precision - Accurate Melee Collisions](https://www.nexusmods.com/skyrimspecialedition/mods/72347) 2.0.6

**Visuals**

- [Static Mesh Improvement Mod - SMIM](https://www.nexusmods.com/skyrimspecialedition/mods/659) 2.08
- [SMIM - Farming Creation Club Patch](https://www.nexusmods.com/skyrimspecialedition/mods/659) 1.0
- [Skyland AIO](https://www.nexusmods.com/skyrimspecialedition/mods/34179) 4.32
- [Skyland AIO - Complex Parallax](https://www.nexusmods.com/skyrimspecialedition/mods/34179) 4
- [Embers XD](https://www.nexusmods.com/skyrimspecialedition/mods/37085) 3.3.0
- [Cathedral Weathers and Seasons](https://www.nexusmods.com/skyrimspecialedition/mods/24791) 2.23c
- [A Quality World Map](https://www.nexusmods.com/skyrimspecialedition/mods/5804) 9.0.1

**Sound, HUD and quality of life**

- [Audio Overhaul for Skyrim](https://www.nexusmods.com/skyrimspecialedition/mods/12466) 4.1.3
- [Better Dialogue Controls](https://www.nexusmods.com/skyrimspecialedition/mods/1429) 1.2
- [Better MessageBox Controls](https://www.nexusmods.com/skyrimspecialedition/mods/1428) 1.2
- [moreHUD](https://www.nexusmods.com/skyrimspecialedition/mods/12688) 5.4.7.0
- [TrueHUD](https://www.nexusmods.com/skyrimspecialedition/mods/62775) 1.1.10
- [QuickLoot IE](https://www.nexusmods.com/skyrimspecialedition/mods/120075) 4.1.3
- [Simple Activate SKSE](https://www.nexusmods.com/skyrimspecialedition/mods/56767) 1.5.0
- [Better Jumping NG](https://www.nexusmods.com/skyrimspecialedition/mods/18967) 1.9.5

**Renderer**

- [Community Shaders](https://www.nexusmods.com/skyrimspecialedition/mods/86492) 1.9.1

## Left out on purpose

ENB and ENB-only effects (don't run under Wine), DynDOLOD/xLODGen output and grass caches (long Windows tool runs),
animation frameworks that need Pandora/Nemesis runs, body/BodySlide mods, and mods without a 1.7.104 build
(RaceMenu, Scrambled Bugs, Quick Loot RE).

## Changing the list

Edit `modlist.json`: each entry is a Nexus mod id and file id. `phase` sets which mods win file conflicts (higher
wins). Run `check` after a change.
