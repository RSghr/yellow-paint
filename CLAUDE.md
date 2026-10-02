# Yellow Paint

A 3D Godot 4.6 game satirising the "yellow paint" handholding in AAA games. The player is the
**operator** (first-person, paint can) who paints yellow splats so an AI **playtester** can
navigate a platforming level. The AI only trusts yellow. Scoring rewards using little paint
(immersion) while collecting coins (side objectives).

## Structure

| File | What it is |
|---|---|
| `level_select.tscn/.gd` | Main scene = the operator's company **desktop** (built in code): icons Inlook / Level Select / Company Settings / Recycle Bin, taskbar with Start menu and clock. Quit = Start > Shut down ("...may result in your ~~contract~~ termination"). First launch opens Inlook on the welcome mail; returning from a level reopens Level Select (`Progress.open_levels_on_menu`). |
| `desk_window.gd` | Draggable desktop window (title bar, close) used by the desktop. |
| `inbox.gd` | Inlook's emails (`MAILS`, BBCode bodies). "welcome" = the story intro from Chad Bossworth (Synergex Interactive, AAAA game HYPERION LEGENDS, investors, "early build" grey boxes). Read state in `Progress.read_mails`/`seen_intro`. |
| `round_intro.gd` | Start of each round: level intro banner at the top (round 1 only) + tester card sliding in bottom-left (name, outlet, intro, stars popping in). Fades after `hold_time` (7s) or when the playtest starts. **C** (`toggle_tester_card`) brings the card back / hides it (it stays until C again). The top-right HUD shows the level name and "Focus tester: name" (StatusLabel). |
| `speech_feed.gd` | Tester speech on the HUD as a chat log under the tester name: "Name: message", oldest on top, newest at the bottom, max 3 lines, each fades `line_life` (6s) after it was said. The newest line is `newest_scale` (1.2x) bigger until the next one. Hidden while spectating. |
| `progress.gd` | Autoload `Progress`: **auto-discovers** `levels/level_*.tscn` (file-name order, names from `level_name`), current level, best stars in `user://progress.cfg`. |
| `settings.gd` | Autoload `Settings`: mouse sensitivity, volume, fullscreen (`user://settings.cfg`). |
| `sfx.gd` | Autoload `Sfx`: `Sfx.play("name")`. Plays `audio/<name>.ogg/.wav/.mp3` if present, silent otherwise. List in `SOUNDS` and `audio/README.md`. |
| `settings_menu.gd` | Settings overlay (options + controls list read from the Input Map). Used by the desktop (titled "COMPANY SETTINGS") and the pause menu. |
| `pause_menu.gd` | Esc in game: Resume / Settings / Level select / Quit. Added by `game.gd`. |
| `spectator_camera.gd` | Orbit camera following the playtester (A on AZERTY = physical Q). Operator is frozen (`active = false`) while spectating. |
| `focus_group.gd` | `FocusGroup`: the tester `ROSTER` (pun names, parody `outlet` (IBN, Polygone...), archetype `intro`, jump/trust/patience traits 0-2), star display, results quotes. |
| `art/paint_splat.png` | Splat image (white placeholder), tinted by `PaintManager.paint_color`. |
| `levels/_template.tscn`, `tools/new_level.gd` | Level template + EditorScript (File > Run) that creates the next `level_XX.tscn`. Guide: `docs/LEVEL_DESIGN.md` (also has the roster with stars and the current lineups; keep them in sync). |
| `game.tscn/.gd` | Hosts a level: loads it, spawns runner + operator, HUD, paint budget, scoring, results. |
| `level.gd` | `@tool` root script of every level: `level_name`, `intro_text`, `death_height`, 3 rounds (`tester_N` dropdown + `minimum_N`); editor warnings for missing spawns/goal/bad lineup. F6 on a level scene launches it inside `game.tscn`. |
| `levels/` | Level scenes: world only (Geometry, Interactables/Coins, Goal, `RunnerSpawn`/`OperatorSpawn` Marker3Ds). |
| `runner.gd/.tscn` | The AI playtester (perception, trust, planning, speech). |
| `character.gd/.tscn` | The operator: FPS movement, jetpack (hold Space), fly mode (F), paint (LMB), scrape (RMB). |
| `paint_manager.gd`, `paint_mark.gd` | Splats (Decals). Each mark has a `role`: `nav` (stand here), `interact` (use this), `none`. Paint limit + refunds. |
| `door.gd` | Door / moving platform (AnimatableBody3D): slides `move_distance` along `move_direction` when opened (editor shows a cyan ghost at the end position). `is_platform`: top paint = nav and rides along (`PaintMark.attach_to`), group `mover`, `moving` while sliding. |
| `breakable.gd`, `door.gd`, `wall_button.gd`, `coin.gd` | Interactables. Group `interactable` objects implement `paint_role(normal)`, `interact_point()`, `interact()`, `is_used()`, `kind`, `state_changed`. Group `resettable` implements `reset_state()`. |
| `block.gd` + `debug_block.tscn` | Static level block, resized via `size` (never scale physics bodies). Grid shader for readable distances. |
| `paint_gauge.gd` | HUD paint bar with min/optimal ticks. |

## Focus testers and rounds
- A level is played by **3 testers in a row** (`Level.rounds()`), set per level. **Paint carries over** between rounds;
  R retries the current tester; N goes to the next tester (then next level). Hotfixes are per round.
- Each round has its own `minimum_N` (that tester's reliable minimum, set by the user from playtesting), so its own
  optimal (+5) and can size (+15). Level result = sum of the 3 round scores, **out of 15** (`Progress`, `best_total`).
- Traits (0 lowest, 1 default, 2 highest), shown to the player only as 1-3 stars. A tester has at most ONE trait at 0:
  - **Jump precision**: Incapable / Hit or miss / Precise → `desperate_success_chance` 0 / 0.65 / 0.95, `leap_error`.
    Incapable still improvises but always falls short (leaps of faith too).
  - **Trust**: Needs a whole bucket / Thoughtful / Blind trust → splats needed on a landing to jump there 2/1/1,
    trust bonus 0/0/+2 (no hesitation), notice rate, scan and hesitation times.
  - **Patience**: No paint, no way / Lost fast / Explorer → improvises after never / 8s / 3s. "No paint, no way" never
    makes an unpainted jump (no desperate jumps, no leaps of faith).
  - Values live in runner.gd's "Traits" export arrays (index = trait level); `Runner.apply_profile()` applies them.

## AI rules (runner.gd), keep these intact
- Only knows paint it has **seen** (vision cone, line of sight, attention builds up; blobs are noticed faster).
- **Trust** = number of seen splats within `trust_radius`. Low trust → hesitates, walks slower, quick look-around.
- Jumps only onto paint (or toward the flag once seen: "leap of faith", deliberately inaccurate). Paint marks the **landing**; the AI walks to a take-off point itself.
- Walks freely on continuous ground; wanders a little, then gives up ("Hello? Level designer?").
- **Desperation**: once it has done a full round of wandering AND `patience` seconds (default 8, chosen by the user) have passed without progress (reaching paint/coin/button/flag, seeing new paint, a door opening), so roughly 10-15s of being lost, it jumps at any ledge it can see
  (closer to the flag if seen, else unexplored). It's a gamble: `desperate_success_chance` (0.65) that it lands,
  regardless of distance (a miss falls well short). Paint appearing during the wind-up cancels it. Won't drop more than
  `max_unpainted_drop` (2.6m) unpainted. Level minimums stay defined as what's *reliable*.
- Take-off points always keep `takeoff_margin` (0.6m) from the edge, and it can never start a jump while airborne
  (if it slips off, it just falls). `desperate_success_chance` is a probability (0-1).
- **Retrace after a fall**: landing by accident more than `setback_drop` (1.5m) below its last trusted spot = setback.
  It heads back to `_furthest` (the most recent NEW paint spot it reached) using known spots as stepping stones,
  then explores normally. If no painted way back exists, it clears `_visited` and explores anything reachable.
- **Return after a detour**: after going for a coin or using a button/breakable (`_detoured`), if it has nothing new to
  try it walks back once to `_furthest` and looks again from there. Plain wandering does NOT count as a detour.
- It only plans **straight-line walks** between points (no navmesh): it can't plan a walk around a pillar or corner.
- Coins are seen without paint but only walked to (`coin_detour` path cost).
- Breakables: side paint = smash, top paint = climb; more paint wins, ties are a remembered guess.
- **Hotfixes** (red splats painted mid-playtest) are an order: noticed instantly with line of sight in any direction
  (no view cone, no attention build-up), trusted at `hotfix_trust` (5), top priority, and the whole route to one is
  walked without hesitation or look-arounds. It replans on the spot (`_urgent`). Hotfix paint on a breakable decides it.
- **Moving platforms**: while the floor under it is moving it stands still (`RIDING`), then looks around. Spots on a
  platform that is still moving are ignored until it stops (its `state_changed` triggers a rethink).
- Priorities: unused hotfix > nearby coin > flag > painted interactable > unvisited paint > leap of faith > wander > desperate jump.

## Scoring (game.gd `score()`)
Per round: start at 5★. Paint penalty vs optimal (= round `minimum_N` + 5): over by 1-5 → -1, 6-10 → -2, >10 → -3.
Coins: all → 0, more than half → -1, half or fewer → -2, none → -3.
Hotfixes (splats painted during a playtest): 0 → 0, 1-3 → -1, 4+ → -2. They come from outside the can (no limit,
not in `splats_used`, no paint penalty) and are **removed on R**. From Enter until R the can is in **Hotfix mode**:
can, crosshair, HUD and new splats turn red (`PaintManager.hotfix_color`); hotfix splats are bigger, pop in and pulse.
Minimum 1★. Can size = optimal + 10. Hotfix quotes in `FocusGroup.HOTFIX_QUOTES`; the tester reacts when it notices one.
Scraping refunds paint; paint destroyed with smashed/opened objects stays spent.
Scraping (and Backspace clear) is **locked during a playtest**: from Enter until R (reset). Adding paint is still allowed
but each splat is a **hotfix** (`PaintMark.hotfix`, counted in `game.gd` `hotfixes`; R deletes them via `remove_hotfixes()`).

## Levels (in `Progress.LEVELS` order)
Lineups are a first pass; per-round minimums are placeholders (bucket rounds doubled) until the user playtests them.
1. `level_01` Onboarding: paint landings. Rhea Spawn (default), Polly Gonn (blind trust), Al Gorithm (bucket).
2. `level_02` Breakables: planks side = smash, crate top = climb; coin on a crate. Bea Tah, Moe Cap, Liv Elup.
   (The standard 3-splat route ends with a leap of faith to the flag: Liv Elup, "No paint, no way", needs it painted.)
3. `level_03` Buttons: two painted buttons/doors, side ledge needs a painted way back. Cass Cene, Lou Tbox, Max Levell.
4. `level_04` The Gauntlet: everything combined. Frank Rate, Dee Sync, Sven Tory.
5. `level_05` The Tower: the user's vertical spiral level. Door2 is an elevator platform (button on it, rises 10m). Hugh Dee, Mike Rotransaction, Rhea Spawn.

## Adding a level
Run `tools/new_level.gd` (Script editor > File > Run) or duplicate `levels/_template.tscn` as `levels/level_XX.tscn`.
It's picked up automatically. Full guide with the AI's numbers and a checklist: `docs/LEVEL_DESIGN.md`.

## Testing headless
Godot 4.6 Linux binary can run the game headless. Use `--fixed-fps 60` to simulate faster than real time.
Write a throwaway `extends SceneTree` script in the project root (delete it afterwards), set
`root.get_node("Progress").current`, instance `game.tscn`, paint via `PaintManager.paint(pos, normal, collider)`
using raycasts, call `game.runner.start()`, and step `physics_frame`. The AI is random, so run each scenario several times.

## Workflow
- Changes go on branches (`claude/...`) and pull requests to `master`. The user pulls with Godot closed or reloads when prompted.
- Godot's open editor can overwrite files changed on disk (script editor buffers). Never assume a write landed, verify.
- Fly down is Ctrl only (C is the tester card).
- Input actions use **physical** keycodes (the user is on AZERTY) except menu keys (N, Tab, Esc) which use logical keycodes.
- Controls are listed in the Settings menu (`settings_menu.gd` `CONTROLS`), not on the HUD. Add new actions there too.
- Test scripts can live outside the project (e.g. a scratchpad) and be run with `--script /abs/path.gd`; don't reference
  `Level`/autoload class names at the top level of a test script (they compile before autoloads exist).
