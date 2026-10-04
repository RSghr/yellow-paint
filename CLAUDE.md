# Yellow Paint

A 3D Godot 4.6 game satirising the "yellow paint" handholding in AAA games. The player is the
**operator** (first-person, paint can) who paints yellow splats so an AI **playtester** can
navigate a platforming level. The AI only trusts yellow. Scoring rewards using little paint
(immersion) while collecting coins (side objectives).

**Story premise:** the grey boxes are NOT the game's art. The operator's cheap work computer (the "ThinkBox 2009")
can only render HYPERION LEGENDS as grey boxes; the testers play the real thing (12K textures, hand-sculpted moss,
ray tracing) and say so (`Runner.ADMIRE`, `admire_chance`). Mails, patch notes and credits all follow this.

## Structure

| File | What it is |
|---|---|
| `level_select.tscn/.gd` | Main scene = the operator's company **desktop** (built in code): icons Inlook / Level Select / Company Settings / Recycle Bin, taskbar with Start menu and clock. Quit = Start > Shut down ("...may result in your ~~contract~~ termination"). First launch = a clean desktop (the unread badge on Inlook does the talking, the player opens the mails themselves); returning from a level reopens Level Select (`Progress.open_levels_on_menu`). |
| `desk_window.gd` | Draggable desktop window (title bar, close) used by the desktop. |
| `inbox.gd` | Inlook's starting emails (`MAILS`, BBCode bodies) + `all_mails()` (delivered ones first). "welcome" = the story intro from Chad Bossworth (Synergex Interactive, AAAA game HYPERION LEGENDS, investors, your ThinkBox 2009 only shows grey boxes). "workstation" = IT denying the graphics card. Read state in `Progress.read_mails`/`seen_intro`. "hr_exit" = HR's exit interview: its "Schedule meeting" button opens a DocuSigh resignation letter (sign, then confirm) that wipes the save (see Progression). |
| `mail_writer.gd` | Emails written during progression: Chad's new-level announcement (opening line by score bracket 15 / 14-10 / 9-5 / 4-0), his performance review when a level scores under 10, and flavor mails (toxic-workplace parody): one about a tester of the new level chosen by their traits (`TESTER_STORIES`, e.g. Explorer leaked the level, admin123) + sometimes an office one (`OFFICE_STORIES`, sent once each). Tester stories: one matching their traits (70%) or a generic "any" one. Patch notes: `patch_notes()` lists **level changes** made because of how each tester did on that level (`LEVEL_CHANGES` per notable stat). |
| `endings.gd` | The 3 endings (`ENDINGS`: title, critic/gamer scores and verdicts, investor quotes, tester line) + `tester_quote()` / `notable_stat()` (what a tester is remembered for, from their stats). |
| `credits.tscn/.gd` | Launch-day credits (built in code, one tween timeline, hold Space/Enter/click = x6): title card, credits roll (contractor #, roster with outlets), investor quotes, focus group quotes (from `tester_stats`), critics score then gamers score, ending name, then back to the desktop (`Progress.finish_credits()`, fade in). **Preview**: F6 on `credits.tscn` (pick `preview_ending` on the root, or keys 1/2/3 = Investors/GOTY/Mostly Fine to restart): never touches the save, shows elapsed time vs the music's length (~1:05-1:15 total). |
| `results_card.gd` | End-of-round results card (same style as the tester card): stars pop in, paint/coins/hotfix rows, review quote + byline, level total /15 after round 3 with NEW BEST / "New playtest scheduled" / "on hold" note, key chips. Also the "Focus tester lost" card. |
| `round_intro.gd` | Start of each round: level intro banner at the top (round 1 only) + tester card sliding in bottom-left (name, outlet, intro, stars popping in). Fades after `hold_time` (7s) or when the playtest starts. **C** (`toggle_tester_card`) brings the card back / hides it (it stays until C again). The top-right HUD shows the level name and "Focus tester: name" (StatusLabel). |
| `speech_feed.gd` | Tester speech on the HUD as a chat log under the tester name: "Name: message", oldest on top, newest at the bottom, max 3 lines, each fades `line_life` (6s) after it was said. The newest line is `newest_scale` (1.2x) bigger until the next one. Hidden while spectating. |
| `progress.gd` | Autoload `Progress`: **auto-discovers** `levels/level_*.tscn` (file-name order, names from `level_name`), current level, best stars in `user://progress.cfg`. |
| `settings.gd` | Autoload `Settings`: mouse sensitivity, master / SFX / music volume (buses "Master", "SFX", "Music"; SFX and Music are created in code and send to Master), fullscreen (`user://settings.cfg`). |
| `sfx.gd` | Autoload `Sfx`: `Sfx.play("name")` on the "SFX" bus. Plays `audio/<name>.ogg/.wav/.mp3` if present, silent otherwise. The same sound twice within 60 ms plays once (30 maze walls = one door sound). List in `SOUNDS` and `audio/README.md`. |
| `music.gd` | Autoload `Music`: looping background music, crossfaded (`Music.play("desk")`). Files `audio/music_<track>`; tracks `desk` (desktop), `game` (levels, or `Level.music`), `credits` (falls back to desk), optional `credits_<ending>` per ending. "Music" bus created by `Settings` (`music_volume`). |
| `settings_menu.gd` | Settings overlay (options + controls list read from the Input Map). Used by the desktop (titled "COMPANY SETTINGS") and the pause menu. |
| `pause_menu.gd` | Esc in game: Resume / Settings / Level select / Quit. Added by `game.gd`. |
| `spectator_camera.gd` | Orbit camera following the playtester (A on AZERTY = physical Q). Operator is frozen (`active = false`) while spectating. |
| `focus_group.gd` | `FocusGroup`: the tester `ROSTER` (pun names, parody `outlet` (IBN, Polygone...), archetype `intro`, jump/trust/exploration (`patience`) traits 0-2), star display, results quotes. |
| `art/paint_splat.png` | Splat image (white placeholder), tinted by `PaintManager.paint_color`. |
| `levels/_template.tscn`, `tools/new_level.gd` | Level template + EditorScript (File > Run) that creates the next `level_XX.tscn`. Guide: `docs/LEVEL_DESIGN.md` (also has the roster with stars and the current lineups; keep them in sync). |
| `game.tscn/.gd` | Hosts a level: loads it, spawns runner + operator, HUD, paint budget, scoring, results. |
| `level.gd` | `@tool` root script of every level: `level_name`, `intro_text`, `death_height`, `post_launch`, `music` (track name, empty = game), 3 rounds (`tester_N` dropdown + `minimum_N`); editor warnings for missing spawns/goal/bad lineup. F6 on a level scene launches it inside `game.tscn`. |
| `levels/` | Level scenes: world only (Geometry, Interactables/Coins, Goal, `RunnerSpawn`/`OperatorSpawn` Marker3Ds). |
| `runner.gd/.tscn` | The AI playtester (perception, trust, planning, speech). **V** = debug view: vision cone, known paint, plan, plus the **reach cylinder** (`draw_reach`, called every frame by `game.gd`): ground band = jump distance, floating band = jump height, label "Jump reach". Centred on the floor the operator aims at (spectating: on the tester). Only while painting: hidden from Enter until R so the vision view stays clean. |
| `character.gd/.tscn` | The operator: FPS movement, jetpack (hold Space), fly mode (F), paint (LMB), scrape (RMB). |
| `paint_manager.gd`, `paint_mark.gd` | Splats (Decals). Each mark has a `role`: `nav` (stand here), `interact` (use this), `none`. Paint limit + refunds. |
| `door.gd` | Door / moving platform (AnimatableBody3D): slides `move_distance` along `move_direction` when opened (editor shows a cyan ghost at the end position). `is_platform`: top paint = nav and rides along (`PaintMark.attach_to`), group `mover`, `moving` while sliding. |
| `breakable.gd`, `door.gd`, `wall_button.gd`, `coin.gd` | Interactables. A button opens `target` + every `extra_targets` path; a target without `open()` (e.g. a "Maze" Node3D) opens every door inside it. Blocks and doors parented under a door move with it, colliders included (nested doors turn off `sync_to_physics`). Group `interactable` objects implement `paint_role(normal)`, `interact_point()`, `interact()`, `is_used()`, `kind`, `state_changed`. Group `resettable` implements `reset_state()`. |
| `block.gd` + `debug_block.tscn` | Static level block, resized via `size` (never scale physics bodies). Grid shader for readable distances. |
| `paint_gauge.gd` | HUD paint bar with min/optimal ticks. |

## Progression (Progress + mail_writer.gd)
- Levels 1-3 (`TUTORIAL_COUNT`) are always in Level Select. Level N (4+) is **invisible** until EVERY level before it
  has a best of `UNLOCK_STARS` (10/15) or more (`Progress.earned` / `missing_for`). There's no "next level" key: levels are started from the desktop. **Testing bypass**: Project Settings > Yellow Paint > Debug > Unlock All Levels
  (`yellow_paint/debug/unlock_all_levels`, debug builds only; turn on "Advanced Settings" to see it). It shows every
  level but doesn't send the unlock emails.
- `Progress.level_finished(total)` (called by game.gd after round 3): if the next level just became available, Chad's
  announcement + 1-2 flavor mails are delivered (once, id `unlock_<level>`); if this level's best is still under 10,
  Chad's review (once per level and score bracket). Mails persist in `Progress.delivered_mails`; the desktop shows a "new email" toast
  (sound `mail`) and the red unread badge on Inlook.
- **Release** (`Progress.ship_state` "" → "credits" → "shipped", `ending`): when every non-post-launch level has 10+
  (`ready_to_ship()`), `level_finished` sends Chad's **greenlight** mail (before anything else, once). Its button opens a
  "Release approval" dialog listing the scores of levels 4+ (`ending_levels()`); "Greenlight & ship it" calls
  `Progress.greenlight()`: `compute_ending()` (15 on all = `investors`, exactly 10 on all = `goty`, else `decent`),
  Chad's ending mail + the **day-one patch notes** (`MailWriter.patch_notes`, from `tester_stats`), Inlook opens on them.
  Closing Inlook once the patch notes were read (or their "Publish patch notes & launch" button) fades to `credits.tscn`.
  After the credits: Patch 1.1 (`shipped()`): Chad's early access mail (names the post-launch level, $4.99), scores
  kept, no more score mails (no stakes), `post_launch` levels open (`Level.post_launch`, tagged DLC), Start menu shows
  the ending. The results card of the last level says "Chad needs your greenlight" / "The launch is on hold until...".
- **Tester stats** (`Progress.playtest_stats`, per level key then tester name, across all their tests, never scored;
  `tester_totals(keys)` adds levels up per tester, `level_stats()` lists levels 4+ in order; old saves land under key ""). The patch notes only cover levels 4+ (`patch_note_keys()`: no tutorials, no post-launch, no old unattributed stats); the credits quotes use every level: tests, finishes,
  deaths, retries (hold R after starting), failed_jumps (`Runner.failed_jumps`: landed off target or died mid-jump),
  lost/played seconds, hotfixes_seen (`Runner.hotfixes_seen`), hotfixes painted. Logged by `game.gd` `_close_attempt`
  when an attempt ends (flag, fall, retry, leaving). F6 runs aren't logged. Used by the patch notes and the credits.
- **Resigning** (HR mail `hr_exit` > Schedule meeting > sign > Confirm): the screen switches off like a CRT (sound `power_off`),
  then `Progress.resign()` wipes stars, times, mails, read state, tester stats and the release (the only way to get another ending) and the desktop reloads clean. Settings are kept.
  `Progress.resignations` survives the reset: `contractor_id()` = 4471 + resignations (Start menu, Inlook), the welcome
  mail gets a P.S. about the predecessor, the HR mail counts the resignations.

## Focus testers and rounds
- A level is played by **3 testers in a row** (`Level.rounds()`), set per level. **Paint carries over** between rounds;
  **Hold R** (`retry_hold_time`, 2s, bar at the bottom) retries the current tester; N goes to the next tester. After the
  3rd tester there is no N: only retry or Tab back to the desktop. Hotfixes are per round.
- Each round has its own `minimum_N` (that tester's reliable minimum, set by the user from playtesting), so its own
  optimal (+5) and can size (+15). Level result = sum of the 3 round scores, **out of 15** (`Progress`, `best_total`).
- Traits (0 lowest, 1 default, 2 highest), shown to the player only as 1-3 stars. A tester has at most ONE trait at 0:
  - **Jumping**: Short legs / Average / Parkour → reach of EVERY jump, painted ones too (`reach_by_level` 4.5 / 5.5 / 7 m,
    `reach_up_by_level` 2.1 / 2.5 / 3.2 m → `max_jump_distance` / `max_jump_up`), plus `desperate_success_chance`
    0 / 0.65 / 0.95 and `leap_error` for improvised jumps (Short legs always falls short). A seen painted landing that's out
    of reach makes it say "Too far!" (`_say_too_far`, once per spot). Average = the old default, so levels built for it
    still work for 2-3★. Short legs needs gaps of ~3.3 m (The Tower needs 5 m: Mike Rotransaction can't finish it yet).
  - **Trust**: Needs a trail / Thoughtful / Blind trust (+ trust bonus 0/0/+2 = no hesitation, notice rate, scan and
    hesitation times; one splat is enough to jump for everyone, `min_jump_splats_by_level` 1/1/1).
    - 1★ "Needs a trail" (`trail_gap_by_level` 5 m): won't walk more than 5 m of unpainted floor between known spots
      (corridors, the walk to a take-off point, the walk to the flag): long walks need breadcrumbs. Says "I need a
      trail" (`_say_no_trail`, also for the flag) before improvising.
    - 3★ "Blind trust" (`overreach_by_level` 1.5 m): picks the NEAREST unvisited yellow (dead ends included) instead of
      the one toward the flag, and when there's no proper way it jumps at paint up to 1.5 m beyond its reach
      (`_link` fallback, step `overreach`): it gets as far as its legs allow and usually falls. Leftover paint from
      the previous tester becomes a trap: scrape it.
  - **Exploration** (key `patience` in code): No paint, no way / Curious / Explorer.
    - 1★ "No paint, no way": never walks off to explore (`wander_walks_by_level` false): it moves splat to splat and,
      when it sees nothing, turns around on the spot (3 look-arounds), so each splat must be visible from where it
      stands (or after turning). Never improvises (no desperate jumps, no leaps of faith).
    - 2★ Curious: wanders 3 times up to 5 m, improvises after 8 s.
    - 3★ Explorer: wanders 6 times up to 8 m, improvises after 16 s, and is **curious** (`curious_by_level`): presses
      unpainted buttons and smashes unpainted breakables it has seen (`known_curios`, `_seen_things`, path kind
      "curio", tried once nothing painted is left), and jumps for a coin it sees without paint (`coin_gamble`: a
      desperate jump with its Jumping odds, so Short legs always falls). Anything with paint is left to the paint.
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
- Priorities: unused hotfix > nearby coin (Explorer: may gamble a jump) > flag > painted interactable > unvisited paint >
  (Explorer) unpainted button/breakable > leap of faith > wander (1★: turn on the spot) > desperate jump.

## Times (logged, never scored)
- `Runner.session_time` (playtest start → flag) and `time_lost` (`_is_lost()`: confused, wander walks, look-arounds
  between wanders, winding up an unpainted gamble/leap). Reset on R.
- Best session per round saved in `Progress.best_times` (`record_time`); results card shows "Time 0:52 · lost 0:09 (17%)"
  + best / NEW RECORD; level summary shows each tester's time; Level Select shows the best total time.
- Lost ≥ 50% of the session: the tester's quote comes from `FocusGroup.LOST_QUOTES` (hotfix quotes still win), and Chad
  adds a PS to his next mail (`MailWriter.lost_note`) or, if he had nothing else to send, a "time sheet" mail (once per level).

## Scoring (game.gd `score()`)
Per round: start at 5★. Paint penalty vs optimal (= round `minimum_N` + 5): over by 1-5 → -1, 6-10 → -2, >10 → -3.
Coins: all → 0, more than half → -1, half or fewer → -2, none → -3.
Hotfixes (splats painted during a playtest): 0 → 0, 1-3 → -1, 4+ → -2. They come from outside the can (no limit,
not in `splats_used`, no paint penalty) and are **removed on R**. From Enter until R the can is in **Hotfix mode**:
can, crosshair, HUD and new splats turn red (`PaintManager.hotfix_color`); hotfix splats are bigger, pop in and pulse.
Minimum 1★. Can size = optimal + 10. Hotfix quotes in `FocusGroup.HOTFIX_QUOTES`; the tester reacts when it notices one.
Scraping refunds paint. Paint on objects that break or open (planks, doors) is put aside (`PaintManager.remove_marks_on` → `_stashed`), still counted, and comes back with the object on reset (`restore_stashed()` in `_reset_run`: hold R or next tester).
Scraping (and Backspace clear) is **locked during a playtest**: from Enter until R (reset). Adding paint is still allowed
but each splat is a **hotfix** (`PaintMark.hotfix`, counted in `game.gd` `hotfixes`; R deletes them via `remove_hotfixes()`).

## Levels (in `Progress.LEVELS` order)
Lineups are a first pass; per-round minimums are placeholders (bucket rounds doubled) until the user playtests them.
1. `level_01` Onboarding: paint landings. Rhea Spawn (default), Polly Gonn (blind trust), Al Gorithm (bucket).
2. `level_02` Breakables: planks side = smash, crate top = climb; coin on a crate. Bea Tah, Moe Cap, Liv Elup.
   (The standard 3-splat route ends with a leap of faith to the flag: Liv Elup, "No paint, no way", needs it painted.)
3. `level_03` Buttons: two painted buttons/doors, side ledge needs a painted way back. Cass Cene, Lou Tbox, Max Levell.
4. `level_04` The Gauntlet: everything combined. Frank Rate, Dee Sync, Sven Tory.
5. `level_05` The Tower: the user's vertical spiral level. Door2 is an elevator platform (button on it, rises 10m). David Goodenough, Mike Rotransaction, Rhea Spawn.
6. `level_06` Victory lap (**post-launch**, the $4.99 DLC): a straight road blocked by a wall. Its button raises the wall
   AND `Geometry/Maze` (every maze wall is a door, sunk 3.6 m into the block), so the route has to be painted blind.
   Liv Elup, Lou Tbox, Sven Tory.

## Adding a level
Run `tools/new_level.gd` (Script editor > File > Run) or duplicate `levels/_template.tscn` as `levels/level_XX.tscn`.
It's picked up automatically. Full guide with the AI's numbers and a checklist: `docs/LEVEL_DESIGN.md`.

## Testing headless
Godot 4.6 Linux binary can run the game headless. Use `--fixed-fps 60` to simulate faster than real time.
Write a throwaway `extends SceneTree` script in the project root (delete it afterwards), set
`root.get_node("Progress").current`, instance `game.tscn`, paint via `PaintManager.paint(pos, normal, collider)`
using raycasts, call `game.runner.start()`, and step `physics_frame`. The AI is random, so run each scenario several times.

## Release (Windows)
- `export_presets.cfg`: "Windows Desktop", single .exe (PCK embedded, no console), icon `art/Logo.ico` (multi-size,
  made from `art/Logo.png`), output `build/windows/YellowPaint.exe` (`/build/` is git-ignored). Excludes `docs/`, `tools/`, `*.md`.
- Boot splash = `art/boot_splash.png` (the desktop wallpaper rendered without icons, bg `#0C1528`): it fades into an
  identical desktop. Re-render it if the wallpaper or `paint_splat.png` changes.
- Before exporting: `yellow_paint/debug/unlock_all_levels` must be false (it only works in debug builds anyway).
- Web (Compatibility renderer) doesn't draw the paint Decals: a web build needs a fallback first.

## Workflow
- Changes go on branches (`claude/...`) and pull requests to `master` (Claude can open and merge PRs with `gh api`).
  - **Big features or design changes** (new mechanics, trait redesigns, new systems): Claude opens the PR and the
    **user reviews and merges** it.
  - **Bug fixes and small tweaks**: Claude opens the PR and **merges it itself** once its tests pass, then tells the user.
  - The user pulls with Godot closed or reloads when prompted.
- Godot's open editor can overwrite files changed on disk (script editor buffers). Never assume a write landed, verify.
- Fly down is Ctrl only (C is the tester card).
- Input actions use **physical** keycodes (the user is on AZERTY) except menu keys (N, Tab, Esc) which use logical keycodes.
- Controls are listed in the Settings menu (`settings_menu.gd` `CONTROLS`), not on the HUD. Add new actions there too.
- Test scripts can live outside the project (e.g. a scratchpad) and be run with `--script /abs/path.gd`; don't reference
  `Level`/autoload class names at the top level of a test script (they compile before autoloads exist).
