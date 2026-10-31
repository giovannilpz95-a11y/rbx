# Game audio

The sound system for the farm and Crop Pop: one shared module that plays named sounds, four volume groups, music that changes with where you are, and hooks that turn farm and Crop Pop events into sounds. The style follows the vault note *Design/26 Audio Style Guide* (Township's feel, with our own sounds).

## Layout

| Folder | Goes to | What's in it |
|---|---|---|
| `src/shared` | `ReplicatedStorage.GameAudio` (a ModuleScript from `init.luau`, the other files are its children) | `GameAudio` (the player), `Sounds` (the named list), `Mixer`, `FarmCues`, `CropPopCues` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.GameAudioClient` (Folder) | `Main` (LocalScript), `UiTaps`, `FarmHooks`, `FactoryHum`, `WorldMusic` |
| `sfx/` | not in the place | our original sound files, to upload to Roblox |
| `tools/make_sfx.py` | not in the place | the script that makes every file in `sfx/` |

`default.project.json` is a Rojo project for the two mapped folders. It sits next to the farm's and Crop Pop's projects; load all three into the same place.

## How it works

- **Named sounds.** Code calls `GameAudio.play("Coin")`. `Sounds.luau` says what each name is: its volume group, volume, cooldown, how many copies can overlap, and which asset plays. Nothing else in the code knows an asset id.
- **Volume groups.** `SoundService.GameAudio` is a SoundGroup with four children: **Music** (0.35), **Ambience** (0.2), **Effects** (0.75) and **Ui** (0.6). `GameAudio.setVolume(group, v)` and `GameAudio.setMuted(group, on)` are what a settings screen calls.
- **Limits.** At most 12 sounds at once (the budget in *12 Art & Audio Direction*), a cooldown per sound, and a few voices each, so a row of harvests or a long Crop Pop cascade never turns into noise.
- **Music for where you are.** `WorldMusic` reads the player's `OnPlot` attribute (set by the farm's SocialService) and calls `GameAudio.setWorld`: the farm tunes at home and in the Town Square, the Visit tune on someone else's farm. While Crop Pop is open its music stays on, and closing it returns to wherever the player now is.
- **Music.** `GameAudio.setMusic("Farm" | "Puzzle" | "Visit")` crossfades to that context. Each context brings its ambience bed (`Sounds.contextAmbience`; the farm's birds fade out under Crop Pop), and coming back to a context picks its music up where it left off. Farm takes turns between two tracks with a short gap; Puzzle and Visit loop one. Fanfares and jingles (`duck = true`) dip the music while they play.
- **Farm hooks, no farm edits.** `FarmHooks` listens to the farm's own remotes. Each state snapshot is compared with the last (`FarmCues.diff`): planting, harvesting (a quick rising run for several beds), building, queueing, collecting, selling, placing, turning and selling decorations, Coins and Gems. `Reward_Popup` plays the order and level-up jingles, tool drops, Prize Crop finds (a bigger flourish for Heirloom), the Prize Shelf (from the snapshot), shop purchases and the Town Crier's bell, `Toast` a soft error blip, and a 0.5 s timer catches factory jobs and buildings finishing. Ripe crops stay quiet; their ready bubbles show them.
- **Busy factories hum.** `FactoryHum` looks at every plot twice a second for factory models with the attribute `Busy = true` (the flag the farm server sets while a job runs, the same one that turns the wheels in `FactoryMotion`). The three nearest the camera, within 80 studs, play the `FactoryHum` loop from the building itself through `GameAudio.attachLoop`, so it fades with distance (full volume inside 12 studs, silent past 70). Each factory gets its own small pitch so a row of mills doesn't sound like one machine.
- **Newer farm features.** The Quarry (a dig, a higher clink when a Stone block takes a hit, a low shimmer when ore turns up), Airship Freight (a horn when it docks and leaves, a collect per crate loaded), the Market stall (setting goods out, a sale, taking them back), moving a building, Tinker's Guild upgrades, the Quarry and airship mast finishing their repairs, and the popups for quests, Town Record medals, the daily gift, the Welcome Boost, visitors, help and the away summary. A test reads every popup kind in `farm/src/server`, so a new kind without a sound fails it.
- **Crop Pop hooks.** `croppop/src/client/Sfx.luau` forwards each board phase as it starts animating, plus Open, Close, Win, Lose and MoreMoves. Frost cracking, weeds being pulled and weeds spreading come from the board phases (and can also be fired as FrostBreak and WeedSpread). Every cascade pops two semitones higher, up to an octave, and the 3rd, 5th and 7th pop of one move add a combo fanfare (`PopCombo`), each a little higher. Swapping two power-ups together charges up, the bonus round plays the big Coin sound, and goo, fences, clover, statues and pumpkins each have a sound. It does nothing if `GameAudio` isn't in the place.
- **Tap sounds.** `UiTaps` gives every button in PlayerGui a soft tap. Invisible hit areas (like the Crop Pop board cells) stay quiet, and so does anything with the attribute `SilentTap = true` on it or a parent.

## What plays now, and what's a placeholder

| Kind | Now | Later |
|---|---|---|
| 48 sound effects | Our originals in `sfx/`, uploaded to Giovanni's account on 2026-10-30 (ids in `UPLOADED` in `Sounds.luau`) | Done. A new original stays silent, and Studio prints its name once, until its id is added |
| 4 more (2026-10-31): `factory_loop`, `quarry_dig`, `airship_horn`, `pop_combo` | Silent until uploaded | Upload them the same way and add their ids to `UPLOADED` |
| Music (Farm, Puzzle, Visit) | **APM Music** tracks from Roblox's library, free in experiences | Our own theme (open question in *12 Art & Audio Direction*) |
| Farm ambience | A **Pro Sound Effects** countryside loop | Our own bed |

Every library pick is a first guess from the track's name and description; they need a listen in Studio. Only APM Music and Pro Sound Effects (Roblox's licensed partners) are used from the library, since many community uploads are ripped from other games. Nothing is taken from Township.

## Uploading the originals

1. In Studio, open **Window > Asset Manager**, click **Bulk Import** and pick every `.ogg` in `sfx/` (or upload them on the Creator Hub under Creations > Audio). Audio uploads are free (100 a month unverified, 2,000 ID-verified).
2. Add each new asset id to the `UPLOADED` table in `src/shared/Sounds.luau`, keyed by file name. Roblox may hide words in asset names (the two weed sounds came back as `#####`); match those by the file list.

To change a sound, edit its function in `tools/make_sfx.py` and run `python3 tools/make_sfx.py` from this folder (needs numpy and ffmpeg), or `python3 tools/make_sfx.py name1 name2` to build only those. The script is deterministic, so only the sounds you touched change (building just the ones you touched also keeps a different ffmpeg version from rewriting the rest). Loops (`LOOPS` in the script) skip the fade in and out so their ends meet.

## Adding a sound

Add an entry to `Sounds.luau` (an `original(...)` with a new file, or a library id as `fallback`), then call `GameAudio.play("Name")` from client code. The tests check that every name the code asks for exists.

## Tests

From this folder, using Crop Pop's Luau host:

```sh
cargo build --release --manifest-path ../croppop/tools/luaurun/Cargo.toml
../croppop/tools/luaurun/target/release/luaurun tests/run.luau
```

They check the sound list (groups, volumes, files on disk, asset id format, every name the code uses), the mixer's limits, the farm cues against example snapshots, the Crop Pop cues for every phase, and `GameAudio` itself against a small fake of the Roblox API (pools, pitch, muting, music crossfade and playlist, ducking). CI runs them on every push that touches `audio/` or Crop Pop's client.
