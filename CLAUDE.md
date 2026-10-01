# Yellow Paint

A 3D Godot 4.6 game satirising the "yellow paint" handholding in AAA games. The player is the
**operator** (first-person, paint can) who paints yellow splats so an AI **playtester** can
navigate a platforming level. The AI only trusts yellow. Scoring rewards using little paint
(immersion) while collecting coins (side objectives).

## Structure

| File | What it is |
|---|---|
| `level_select.tscn/.gd` | Main scene. Level list with best stars, Settings, Quit. |
| `progress.gd` | Autoload `Progress`: **auto-discovers** `levels/level_*.tscn` (file-name order, names from `level_name`), current level, best stars in `user://progress.cfg`. |
| `settings.gd` | Autoload `Settings`: mouse sensitivity, volume, fullscreen (`user://settings.cfg`). |
| `sfx.gd` | Autoload `Sfx`: `Sfx.play("name")`. Plays `audio/<name>.ogg/.wav/.mp3` if present, silent otherwise. List in `SOUNDS` and `audio/README.md`. |
| `settings_menu.gd` | Settings overlay (options + controls list read from the Input Map). Used by main menu and pause menu. |
| `pause_menu.gd` | Esc in game: Resume / Settings / Level select / Quit. Added by `game.gd`. |
| `spectator_camera.gd` | Orbit camera following the playtester (A on AZERTY = physical Q). Operator is frozen (`active = false`) while spectating. |
| `focus_group.gd` | `FocusGroup`: pun-named testers (random each run/retry) and results quotes by stars. |
| `art/paint_splat.png` | Splat image (white placeholder), tinted by `PaintManager.paint_color`. |
| `levels/_template.tscn`, `tools/new_level.gd` | Level template + EditorScript (File > Run) that creates the next `level_XX.tscn`. Guide: `docs/LEVEL_DESIGN.md`. |
| `game.tscn/.gd` | Hosts a level: loads it, spawns runner + operator, HUD, paint budget, scoring, results. |
| `level.gd` | `@tool` root script of every level: `level_name`, `intro_text`, `minimum_paint`, `death_height`; editor warnings for missing spawns/goal. F6 on a level scene launches it inside `game.tscn`. |
| `levels/` | Level scenes: world only (Geometry, Interactables/Coins, Goal, `RunnerSpawn`/`OperatorSpawn` Marker3Ds). |
| `runner.gd/.tscn` | The AI playtester (perception, trust, planning, speech). |
| `character.gd/.tscn` | The operator: FPS movement, jetpack (hold Space), fly mode (F), paint (LMB), scrape (RMB). |
| `paint_manager.gd`, `paint_mark.gd` | Splats (Decals). Each mark has a `role`: `nav` (stand here), `interact` (use this), `none`. Paint limit + refunds. |
| `breakable.gd`, `door.gd`, `wall_button.gd`, `coin.gd` | Interactables. Group `interactable` objects implement `paint_role(normal)`, `interact_point()`, `interact()`, `is_used()`, `kind`, `state_changed`. Group `resettable` implements `reset_state()`. |
| `block.gd` + `debug_block.tscn` | Static level block, resized via `size` (never scale physics bodies). Grid shader for readable distances. |
| `paint_gauge.gd` | HUD paint bar with min/optimal ticks. |

## AI rules (runner.gd), keep these intact
- Only knows paint it has **seen** (vision cone, line of sight, attention builds up; blobs are noticed faster).
- **Trust** = number of seen splats within `trust_radius`. Low trust → hesitates, walks slower, quick look-around.
- Jumps only onto paint (or toward the flag once seen: "leap of faith", deliberately inaccurate). Paint marks the **landing**; the AI walks to a take-off point itself.
- Walks freely on continuous ground; wanders a little, then gives up ("Hello? Level designer?").
- **Desperation**: once it has done a full round of wandering AND `patience` seconds (default 4, chosen by the user) have passed without progress (reaching paint/coin/button/flag, seeing new paint, a door opening), so roughly 10-15s of being lost, it jumps at any ledge it can see
  (closer to the flag if seen, else unexplored). It's a gamble: `desperate_success_chance` (0.65) that it lands,
  regardless of distance (a miss falls well short). Paint appearing during the wind-up cancels it. Won't drop more than
  `max_unpainted_drop` (2.6m) unpainted. Level minimums stay defined as what's *reliable*.
- Take-off points always keep `takeoff_margin` (0.6m) from the edge, and it can never start a jump while airborne
  (if it slips off, it just falls). `desperate_success_chance` is a probability (0-1).
- Coins are seen without paint but only walked to (`coin_detour` path cost).
- Breakables: side paint = smash, top paint = climb; more paint wins, ties are a remembered guess.
- Priorities: nearby coin > flag > painted interactable > unvisited paint > leap of faith > wander > desperate jump.

## Scoring (game.gd `score()`)
Start at 5★. Paint penalty vs optimal (= level `minimum_paint` + 5): over by 1-5 → -1, 6-10 → -2, >10 → -3.
Coins: all → 0, more than half → -1, half or fewer → -2, none → -3. Minimum 1★. Can size = optimal + 10.
Scraping refunds paint; paint destroyed with smashed/opened objects stays spent.
Scraping (and Backspace clear) is **locked during a playtest**: from Enter until R (reset). Adding paint is still allowed.

## Levels (in `Progress.LEVELS` order)
1. `level_01` Onboarding: paint landings (min 3).
2. `level_02` Breakables: planks side = smash, crate top = climb; coin on a crate (min 3).
3. `level_03` Buttons: two painted buttons/doors, side ledge needs a painted way back (min 6).
4. `level_04` The Gauntlet: everything combined (min 10, set by the user from playtesting).

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
- Input actions use **physical** keycodes (the user is on AZERTY) except menu keys (N, Tab, Esc) which use logical keycodes.
- Controls are listed in the Settings menu (`settings_menu.gd` `CONTROLS`), not on the HUD. Add new actions there too.
- Test scripts can live outside the project (e.g. a scratchpad) and be run with `--script /abs/path.gd`; don't reference
  `Level`/autoload class names at the top level of a test script (they compile before autoloads exist).
