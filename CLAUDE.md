# Yellow Paint

A 3D Godot 4.6 game satirising the "yellow paint" handholding in AAA games. The player is the
**operator** (first-person, paint can) who paints yellow splats so an AI **playtester** can
navigate a platforming level. The AI only trusts yellow. Scoring rewards using little paint
(immersion) while collecting coins (side objectives).

## Structure

| File | What it is |
|---|---|
| `level_select.tscn/.gd` | Main scene. Menu built from `Progress.LEVELS`, shows best stars. |
| `progress.gd` | Autoload `Progress`: level list, current level, best stars saved to `user://progress.cfg`. |
| `game.tscn/.gd` | Hosts a level: loads it, spawns runner + operator, HUD, paint budget, scoring, results. |
| `level.gd` | Root script of every `levels/level_XX.tscn`: `level_name`, `intro_text`, `minimum_paint`, `death_height`. F6 on a level scene launches it inside `game.tscn`. |
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
- Coins are seen without paint but only walked to (`coin_detour` path cost).
- Breakables: side paint = smash, top paint = climb; more paint wins, ties are a remembered guess.
- Priorities: nearby coin > flag > painted interactable > unvisited paint > leap of faith > wander.

## Scoring (game.gd `score()`)
Start at 5★. Paint penalty vs optimal (= level `minimum_paint` + 5): over by 1-5 → -1, 6-10 → -2, >10 → -3.
Coins: all → 0, more than half → -1, half or fewer → -2, none → -3. Minimum 1★. Can size = optimal + 10.
Scraping refunds paint; paint destroyed with smashed/opened objects stays spent.

## Adding a level
1. Duplicate a file in `levels/`, edit geometry with `debug_block.tscn` instances (set `size`/`color`), add interactables, coins, Goal, spawns.
2. Set `level_name`, `intro_text`, `minimum_paint` on the root (from playtesting).
3. Add a line to `Progress.LEVELS`.

## Testing headless
Godot 4.6 Linux binary can run the game headless. Use `--fixed-fps 60` to simulate faster than real time.
Write a throwaway `extends SceneTree` script in the project root (delete it afterwards), set
`root.get_node("Progress").current`, instance `game.tscn`, paint via `PaintManager.paint(pos, normal, collider)`
using raycasts, call `game.runner.start()`, and step `physics_frame`. The AI is random, so run each scenario several times.

## Workflow
- Changes go on branches (`claude/...`) and pull requests to `master`. The user pulls with Godot closed or reloads when prompted.
- Godot's open editor can overwrite files changed on disk (script editor buffers). Never assume a write landed, verify.
- Input actions use **physical** keycodes (the user is on AZERTY) except menu keys (N, Tab) which use logical keycodes.
