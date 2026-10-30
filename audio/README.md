# Game audio

The sound system for the farm and Crop Pop: one shared module that plays named sounds, four volume groups, music that changes with where you are, and hooks that turn farm and Crop Pop events into sounds. The style follows the vault note *Design/26 Audio Style Guide* (Township's feel, with our own sounds).

## Layout

| Folder | Goes to | What's in it |
|---|---|---|
| `src/shared` | `ReplicatedStorage.GameAudio` (a ModuleScript from `init.luau`, the other files are its children) | `GameAudio` (the player), `Sounds` (the named list), `Mixer`, `FarmCues`, `CropPopCues` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.GameAudioClient` (Folder) | `Main` (LocalScript), `UiTaps`, `FarmHooks` |
| `sfx/` | not in the place | our original sound files, to upload to Roblox |
| `tools/make_sfx.py` | not in the place | the script that makes every file in `sfx/` |

`default.project.json` is a Rojo project for the two mapped folders. It sits next to the farm's and Crop Pop's projects; load all three into the same place.

## How it works

- **Named sounds.** Code calls `GameAudio.play("Coin")`. `Sounds.luau` says what each name is: its volume group, volume, cooldown, how many copies can overlap, and which asset plays. Nothing else in the code knows an asset id.
- **Volume groups.** `SoundService.GameAudio` is a SoundGroup with four children: **Music** (0.35), **Ambience** (0.2), **Effects** (0.75) and **Ui** (0.6). `GameAudio.setVolume(group, v)` and `GameAudio.setMuted(group, on)` are what a settings screen calls.
- **Limits.** At most 12 sounds at once (the budget in *12 Art & Audio Direction*), a cooldown per sound, and a few voices each, so a row of harvests or a long Crop Pop cascade never turns into noise.
- **Music.** `GameAudio.setMusic("Farm" | "Puzzle" | "Visit")` crossfades to that context. Each context brings its ambience bed (`Sounds.contextAmbience`; the farm's birds fade out under Crop Pop), and coming back to a context picks its music up where it left off. Farm takes turns between two tracks with a short gap; Puzzle and Visit loop one. Fanfares and jingles (`duck = true`) dip the music while they play.
- **Farm hooks, no farm edits.** `FarmHooks` listens to the farm's own remotes. Each state snapshot is compared with the last (`FarmCues.diff`): planting, harvesting (a quick rising run for several beds), building, queueing, collecting, selling, Coins and Gems. `Reward_Popup` plays the order and level-up jingles, `Toast` a soft error blip, and a 0.5 s timer catches factory jobs and buildings finishing. Ripe crops stay quiet; their ready bubbles show them.
- **Crop Pop hooks.** `croppop/src/client/Sfx.luau` forwards each board phase as it starts animating, plus Open, Close, Win, Lose and MoreMoves. Every cascade pops two semitones higher, up to an octave. It does nothing if `GameAudio` isn't in the place.
- **Tap sounds.** `UiTaps` gives every button in PlayerGui a soft tap. Invisible hit areas (like the Crop Pop board cells) stay quiet, and so does anything with the attribute `SilentTap = true` on it or a parent.

## What plays now, and what's a placeholder

| Kind | Now | Later |
|---|---|---|
| 37 sound effects | Our originals in `sfx/`, **not uploaded yet**, so silent. Studio prints each name once the first time it's asked for, so hooks can be checked. | Upload, then put each asset id in the sound's `id` |
| Level up, Crop Pop win and lose, match pop | A free **APM Music** / **Pro Sound Effects** sound from Roblox's library (the `fallback` field), until our original has an `id` | Our original |
| Music (Farm, Puzzle, Visit) | **APM Music** tracks from Roblox's library, free in experiences | Our own theme (open question in *12 Art & Audio Direction*) |
| Farm ambience | A **Pro Sound Effects** countryside loop | Our own bed |

Every library pick is a first guess from the track's name and description; they need a listen in Studio. Only APM Music and Pro Sound Effects (Roblox's licensed partners) are used from the library, since many community uploads are ripped from other games. Nothing is taken from Township.

## Uploading the originals

1. In Studio, open **Window > Asset Manager**, click **Bulk Import** and pick every `.ogg` in `sfx/` (or upload them on the Creator Hub under Creations > Audio). Audio uploads are free (100 a month unverified, 2,000 ID-verified).
2. Copy each new asset id into the matching entry in `src/shared/Sounds.luau` as `id = "rbxassetid://..."`. The `fallback` can stay or go; `id` wins.

To change a sound, edit its function in `tools/make_sfx.py` and run `python3 tools/make_sfx.py` from this folder (needs numpy and ffmpeg). The script is deterministic, so only the sounds you touched change.

## Adding a sound

Add an entry to `Sounds.luau` (an `original(...)` with a new file, or a library id as `fallback`), then call `GameAudio.play("Name")` from client code. The tests check that every name the code asks for exists.

## Tests

From this folder, using Crop Pop's Luau host:

```sh
cargo build --release --manifest-path ../croppop/tools/luaurun/Cargo.toml
../croppop/tools/luaurun/target/release/luaurun tests/run.luau
```

They check the sound list (groups, volumes, files on disk, asset id format, every name the code uses), the mixer's limits, the farm cues against example snapshots, the Crop Pop cues for every phase, and `GameAudio` itself against a small fake of the Roblox API (pools, pitch, muting, music crossfade and playlist, ducking). CI runs them on every push that touches `audio/` or Crop Pop's client.
