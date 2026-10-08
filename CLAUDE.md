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
| `inbox.gd` | Inlook's starting emails (`MAILS`, BBCode bodies) + `all_mails()` (delivered ones first). "welcome" = the story intro from Chad Bossworth (Synergex Interactive, AAAA game HYPERION LEGENDS, investors, your ThinkBox 2009 only shows grey boxes). "workstation" = IT denying the graphics card. "keys" = IT's quick start guide: controls (key names filled from the Input Map by `_with_keys()`, `{action}` placeholders; a line whose action doesn't exist is dropped), subtle paint, 2 free red hotfixes per level then they cost stars, 10/15 to unlock the next playtest. Caps Lock in game = "Green paint requires ThinkBox 2009 Pro+" (`game.gd` `_caps_lock_joke`). Read state in `Progress.read_mails`/`seen_intro`. "hr_exit" = HR's exit interview: its "Schedule meeting" button opens a DocuSigh resignation letter (sign, then confirm) that wipes the save (see Progression). |
| `mail_writer.gd` | Emails written during progression: Chad's new-level announcement (opening line by score bracket 15 / 14-10 / 9-5 / 4-0), his performance review when a level scores under 10, and flavor mails (toxic-workplace parody): one about a tester of the new level chosen by their traits (`TESTER_STORIES`, e.g. Explorer leaked the level, admin123) + sometimes an office one (`OFFICE_STORIES`, sent once each). Tester stories: one matching their traits (70%) or a generic "any" one. Patch notes: `patch_notes()` lists **level changes** made because of how each tester did on that level (`LEVEL_CHANGES` per notable stat). **Story mails** (`STORY_MAILS`, `STORY_SCHEDULE`, `story_for(event)`, delivered once by `Progress._deliver_story`): unlock of the 1st main level (Gauntlet) = Darren's yogurt thread; 2nd (Tower) = Facilities moves your desk to Level -3 by the parking, investor Vivian Moneypenny's nephew wants to be playable; greenlight = "It was Chad." (Kevin, Level Design) then Chad's burnout/leakers memo; after the credits = Level Readability #3502 (never had their login revoked) asks if you're okay. Plus `ANTIVIRUS_THREAD`: Corporate Security vs IT Helpdesk, one per main level unlocked. Random office mails (`office_mail()`) now come with Chad's performance reviews (50%); unlocks with story mails skip them. Voices: Marketing = zoomer, Art Department = two guys with ever bigger plans, IT signs "Any expired license needs to be approved by Legal and Darren from Accounting", Corporate Security runs the phishing training (its [url] opens wikiHow; mail links are clickable). |
| `endings.gd` | The 3 endings (`ENDINGS`: title, critic/gamer scores and verdicts, investor quotes, tester line) + `tester_quote()` / `notable_stat()` (what a tester is remembered for, from their stats). |
| `credits.tscn/.gd` | Launch-day credits (built in code, one tween timeline, hold Space/Enter/click = x6): title card, credits roll (contractor #, roster with outlets), investor quotes, focus group quotes (from `tester_stats`), critics score then gamers score, ending name, then back to the desktop (`Progress.finish_credits()`, fade in). **Preview**: F6 on `credits.tscn` (pick `preview_ending` on the root, or keys 1/2/3 = Investors/GOTY/Mostly Fine to restart): never touches the save, shows elapsed time vs the music's length (~1:05-1:15 total). |
| `results_card.gd` | End-of-round results card (same style as the tester card): stars pop in, paint/coins/hotfix rows, review quote + byline, level total /15 after round 3 with NEW BEST / "New playtest scheduled" / "on hold" note, key chips. Also the "Focus tester lost" card. |
| `round_intro.gd` | Start of each round: level intro banner at the top (round 1 only) + tester card sliding in bottom-left (name, outlet, intro, stars popping in). Fades after `hold_time` (7s) or when the playtest starts. **C** (`toggle_tester_card`) brings the card back / hides it (it stays until C again). While it's up that way the cursor is free (`inspecting_changed` → `game.gd` `_on_card_inspecting`, recaptured on close) and hovering a trait row shows what its stars mean (`FocusGroup.TRAIT_INFO`, 2-3 lines per star level, written as the focus group's notes: keep in sync with runner.gd's trait values). The top-right HUD shows the level name and "Focus tester: name" (StatusLabel). |
| `speech_feed.gd` | Tester speech on the HUD as a chat log under the tester name: "Name: message", oldest on top, newest at the bottom, max 3 lines, each fades `line_life` (6s) after it was said. The newest line is `newest_scale` (1.2x) bigger until the next one. Hidden while spectating. |
| `progress.gd` | Autoload `Progress`: **auto-discovers** `levels/level_*.tscn` (file-name order, names from `level_name`), current level, best stars in `user://progress.cfg`. |
| `settings.gd` | Autoload `Settings`: mouse sensitivity, master / SFX / music volume (buses "Master", "SFX", "Music"; SFX and Music are created in code and send to Master), fullscreen (`user://settings.cfg`). |
| `sfx.gd` | Autoload `Sfx`: `Sfx.play("name")` on the "SFX" bus. Plays `audio/<name>.ogg/.wav/.mp3` if present, silent otherwise. The same sound twice within 60 ms plays once (30 maze walls = one door sound). List in `SOUNDS` and `audio/README.md`. |
| `music.gd` | Autoload `Music`: looping background music, crossfaded (`Music.play("desk")`). Files `audio/music_<track>`; tracks `desk` (desktop), `game` (levels, or `Level.music`), `credits` (falls back to desk), optional `credits_<ending>` per ending. "Music" bus created by `Settings` (`music_volume`). |
| `settings_menu.gd` | Settings overlay (options + controls list read from the Input Map). Used by the desktop (titled "COMPANY SETTINGS") and the pause menu. |
| `pause_menu.gd` | Esc in game: Resume / Settings / Level select / Quit. Added by `game.gd`. |
| `spectator_camera.gd` | Orbit camera following the playtester (A on AZERTY = physical Q). Operator is frozen (`active = false`) while spectating. |
| `focus_group.gd` | `FocusGroup`: the tester `ROSTER` (pun names, parody `outlet` (IBN, Polygone...), archetype `intro`, jump/greed/exploration (`patience`) traits 0-2), star display, results quotes. |
| `art/paint_splat.png` | Splat image (white placeholder), tinted by `PaintManager.paint_color`. |
| `levels/_template.tscn`, `tools/new_level.gd` | Level template + EditorScript (File > Run) that creates the next `level_XX.tscn`. Guide: `docs/LEVEL_DESIGN.md` (also has the roster with stars and the current lineups; keep them in sync). |
| `game.tscn/.gd` | Hosts a level: loads it, spawns runner + operator, HUD, paint budget, scoring, results. |
| `art/thinkbox_sky.gdshader` | The sky (used by `game.tscn`'s WorldEnvironment): the ThinkBox's untextured fallback dome (flat blue-grey, faint lat/long wireframe, `grid_strength`) with ONE blocky rectangle of the real sky streamed in (`show_patch`). **Rolled at random each time a level loads** (`game.gd` `_roll_sky()`, `sky_variant`, `SKY_NAMES`): `variant` 0 midday (blue, near-white sun, around the scene's DirectionalLight), 1 sunset (at the horizon under the sun), 2 night (pixel stars, crescent moon), about 1/3 each; 3 = missing texture, `missing_texture_chance` 0.5%: the whole dome is the magenta/black checker on a cube. `force_sky` (game.gd, -1 = random) to test one. The grey boxes are lit the same whatever the sky (the ThinkBox doesn't do time of day; fixed ambient colour). No `TIME` in the shader (it would re-render the sky every frame). Kept cool and dull so paint, hotfixes and loot stand out. |
| `level.gd` | `@tool` root script of every level: `level_name`, `intro_text`, `death_height`, `music` (track name, empty = game), 3 rounds (`tester_N` dropdown + `minimum_N`); editor warnings for missing spawns/goal/bad lineup. F6 on a level scene launches it inside `game.tscn`. |
| `levels/` | Level scenes: world only (Geometry, Interactables/Coins, Goal, `RunnerSpawn`/`OperatorSpawn` Marker3Ds). |
| `runner.gd/.tscn` | The AI playtester (perception, trust, planning, speech). **V** = debug view: vision cone, known paint, plan, plus the **reach cylinder** (`draw_reach`, called every frame by `game.gd`): ground band = jump distance, floating band = jump height, label "Jump reach". Centred on the floor the operator aims at (spectating: on the tester). Only while painting: hidden from Enter until R so the vision view stays clean. |
| `character.gd/.tscn` | The operator: FPS movement, jetpack (hold Space), fly mode (F), paint (LMB), scrape (RMB). **Bounds** (`bounds`, set by `game.gd`): an invisible wall at the far edge of the overheat zone (sides and top only; falling is `FALL_RESET_Y`'s job). |
| `paint_manager.gd`, `paint_mark.gd` | Splats (Decals). Each mark has a `role`: `nav` (stand here), `interact` (use this), `none`. Paint limit + refunds. |
| `door.gd` | Door / moving platform (AnimatableBody3D): slides `move_distance` along `move_direction` when opened (editor shows a cyan ghost at the end position). `is_platform`: top paint = nav and rides along (`PaintMark.attach_to`), group `mover`, `moving` while sliding. **Elevator** `return_after` (s, 0 = stays): once up and nobody on top for that long it slides back, emits `returned`, and the buttons targeting it re-arm (`WallButton` connects to it), so a tester who fell can call it again. Coming down onto a tester (group `playtester`) it puts them on top instead of pushing them through the floor (`_scoop_playtester`). The Tower's Door2: 4 s. |
| `breakable.gd`, `door.gd`, `wall_button.gd`, `coin.gd` | Interactables. A button opens `target` + every `extra_targets` path; a target without `open()` (e.g. a "Maze" Node3D) opens every door inside it. Blocks and doors parented under a door move with it, colliders included (nested doors turn off `sync_to_physics`). Group `interactable` objects implement `paint_role(normal)`, `interact_point()`, `interact()`, `is_used()`, `kind`, `state_changed`. Group `resettable` implements `reset_state()`. |
| `block.gd` + `debug_block.tscn` | Static level block, resized via `size` (never scale physics bodies). Grid shader for readable distances. |
| `paint_gauge.gd` | HUD paint bar with min/optimal ticks. |
| `overheat.gd` | The ThinkBox struggling when the operator strays (added by `game.gd`). **Comfort zone** = every visible thing in the level + `bounds_margin` 20 m on the sides, `bounds_headroom` 25 m above (`game.gd` `_operator_bounds()`): room for wide shots. Past it, over `strain_distance` 35 m: the screen pixelates, colours collapse and blocks glitch (canvas shader on a CanvasLayer under the HUD, follows the camera, clears when you come back) and the **fan** (`audio/fan.wav`, generated placeholder, looped) spins up and gets louder. The fan **never calms down** (`heat` only goes up) until you leave the level, then it spins down over `spin_down_time` (4 s; its player lives under the root so it outlives the level); it has its own "Fan" bus (SFX/Music sliders don't touch it, Master is compensated up to +30 dB) and keeps playing while paused. The operator's wall is at the far end of the strain zone. |

## Progression (Progress + mail_writer.gd)
- Levels 1-3 (`TUTORIAL_COUNT`) are always in Level Select. Level N (4+) is **invisible** until EVERY level before it
  has a best of `UNLOCK_STARS` (10/15) or more (`Progress.earned` / `missing_for`). There's no "next level" key: levels are started from the desktop. **Testing bypass**: Project Settings > Yellow Paint > Debug > Unlock All Levels
  (`yellow_paint/debug/unlock_all_levels`, debug builds only; turn on "Advanced Settings" to see it). It shows every
  level but doesn't send the unlock emails.
  **Show All Mails** (`yellow_paint/debug/show_all_mails`, `Progress.show_all_mails()`): Inlook lists every mail the game
  can send (`MailWriter.debug_all_mails()`: story mails in career order, every tester/office flavor, Chad by bracket,
  PS mails, greenlight, the 3 endings, patch notes and Patch 1.1 mails, plus a "Variants" mail with every random line),
  tagged "[Story: unlock_2] ...", written from the current save (0 where nothing was logged). Never saved; no buttons.
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
  kept, no more score mails (no stakes), DLC levels open (file name `level_dlc_XX.tscn` = `post_launch` in `Progress.LEVELS`, `Progress.DLC_PREFIX`; shown as "DLC 1" by `Progress.level_label()`, main levels are numbered without them), Start menu shows
  the ending. The results card of the last level says "Chad needs your greenlight" / "The launch is on hold until...".
- **Best runs** (`Progress.best_runs`, per level key then tester): the stats of the 3 rounds behind the level's saved best
  score (`game.gd` `round_runs` = each round's finishing attempt, passed to `Progress.record()`; replaced on a new best,
  filled on a tie if missing). **The patch notes and the credits quotes only use these** (`tester_totals`, `level_stats`):
  retries, resets and abandoned runs (e.g. a hotfix test you reset) are never mentioned.
- **Tester stats** (`Progress.playtest_stats`, every attempt, kept but no longer shown;
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
  3rd tester there is no N: only retry, or Esc > Level select (no Tab shortcut: a stray key press used to throw a
  level away). Hotfixes are per round.
- Each round has its own `minimum_N` (that tester's reliable minimum, set by the user from playtesting), so its own
  paint steps and can size (see Scoring). Level result = sum of the 3 round scores, **out of 15** (`Progress`, `best_total`).
- Traits (0 lowest, 1 default, 2 highest), shown to the player only as 1-3 stars. A tester has at most ONE trait at 0:
  - **Jumping**: Short legs / Average / Parkour → reach of EVERY jump, painted ones too (`reach_by_level` 4.5 / 5.5 / 7 m,
    `reach_up_by_level` 2.1 / 2.5 / 3.2 m → `max_jump_distance` / `max_jump_up`), plus `desperate_success_chance`
    0.5 / 0.65 / 0.95 (`jump_success_by_level`) and `leap_error` for improvised jumps (Short legs: leaps of faith also
    land only 50%, `short_legs`). A seen painted landing that's out of reach makes it say "Too far!" (`_say_too_far`,
    once per spot, BEFORE it improvises: out of reach = no take-off on its floor works, margin included, but 1.5 m
    more reach would; way out of range says nothing). Short legs needs gaps of ~3.3 m (The Tower needs 5 m: Mike Rotransaction can't finish it yet).
  - **Greed** (key `greed`, replaced Trust: everyone now has the old Thoughtful trust): Ascetic / Average / Loot goblin.
    - 1★ "Ascetic" (`greed_radius_by_level` 4 m): only wants loot on its own floor (|dy| < 0.6) within 4 m with a
      walkable path (`_wants_coin`, filters `known_coins()`). Anything else needs a painted way or is left behind.
    - 2★ Average: walks to loot it sees (`coin_detour_by_level` 16), never jumps for it.
    - 3★ "Loot goblin" (`loot_goblin_by_level`, `coin_detour` 80): **loot first, paint second.** Any collectible it
      sees on a platform within its jump reach (`_coin_jump` / `_gamble_ok`: a coin node only reachable by an unpainted
      jump, `_has_floor_under`), it goes for before unvisited paint and the waystone (`_pick_target`, right after
      reachable coins; not while retracing a fall). First time: walks to the take-off only (`_scouted_coins`, "Let me
      just check something first"), looks around, then improvises the jump with its Jumping odds. **No safety check**:
      a miss over a pit is a death (user's call, Oct 2026: on level 1 the pillar loot costs no paint for Polly, ~35-40%
      deaths with her 65% odds). **Marked spot**: before the jump it marks its take-off (`_loot_anchor`, "Marking this
      spot"). After grabbing the loot, if nothing painted leads on from there, it first looks around carefully for paint
      (`_try_loot_return`, `looked`), then goes back to the marked spot (same jump the other way, a gamble again; a
      miss is a fall and the usual retrace takes over). The mark is dropped once it reaches a new splat.
      Loot out of reach stays remembered (`_seen_coins`) and is gone for as soon as a known spot puts it in reach.
    - Old Trust code (`conviction_time`, `overreach`, `trust_bonus`) is kept dormant as plain exports at 0.
  - **Exploration** (key `patience` in code): No paint, no way / Curious / Explorer.
    - 1★ "No paint, no way": short look-around walks only (`wander_min_by_level`/`wander_range_by_level` 1.5-3 m),
      so each splat must be visible from near the last one. Never improvises (no desperate jumps, no leaps of faith).
    - 2★ Curious: wanders 3 times, 2-5 m, improvises after 8 s.
    - 3★ Explorer: wanders 8 times up to 9 m, improvises after 16 s, and is **curious** (`curious_by_level`): presses
      unpainted buttons and smashes unpainted breakables it has seen (`known_curios`, `_seen_things`, path kind
      "curio", tried once nothing painted is left). Anything with paint is left to the paint.
      (Jumping for unpainted loot is the Loot goblin's now, not the Explorer's.)
  - Values live in runner.gd's "Traits" export arrays (index = trait level); `Runner.apply_profile()` applies them.

## AI rules (runner.gd), keep these intact
- Only knows paint it has **seen** (vision cone, line of sight, attention builds up; blobs are noticed faster).
- **Trust** = number of seen splats within `trust_radius`. Low trust → hesitates, walks slower, quick look-around.
- Jumps only onto paint (or toward the flag once seen: "leap of faith", deliberately inaccurate). Paint marks the **landing**; the AI walks to a take-off point itself.
- Walks freely on continuous ground; wanders a little, then gives up ("Hello? Level designer?").
- **Gazes** (cosmetic, `_start_gaze`/`_update_gaze`): while lost (wander walks, look-arounds between wanders, confused;
  not while winding up a jump) it stares at its feet, up, or at a random spot every `gaze_interval` (2.5-5.5 s) for
  `gaze_duration`, sometimes saying what it sees (`GAZE_LINES` + `ADMIRE`, `gaze_line_chance`). Only the visor tilts
  (`_head_pitch`, pivots on the capsule dome); perception uses the head's yaw only. The look-around/confused timer
  pauses during a gaze and wander walks slow to 30%, so it searches as much as before, it just loses more time.
- **Look back** (`_look_back`, periodic): while lost, after every `look_back_every_by_level` [1, 2, 4] look-around walks
  (lower Exploration = more often) it walks back to the last splat it reached (`_furthest`) and looks around carefully
  there (`_careful_look`: long turning scan), then keeps searching from there. Counter `_walks_since_look`, reset on
  new paint. Going back to a splat it already knew isn't progress (patience keeps running; a NEW splat resets it in
  `_record_visit`). Fixes "missed one splat behind a corner → lost / back to the start".
  The way back uses **breadcrumbs** (`_crumbs`, `_drop_crumb`: a point every 2.5 m of ground covered since the last
  new splat, max 60, walk-only nodes added to the planner only during a look-back), so it can return to a splat it
  only reached by wandering round corners. `_wander` knows the look-back worked when `_decide()` leaves a `_path`.
- **Desperation**: once it has done a full round of wandering AND `patience` seconds (default 8, chosen by the user) have passed without progress (reaching paint/coin/button/flag, seeing new paint, a door opening), so roughly 10-15s of being lost, it jumps at any ledge it can see
  (closer to the flag if seen, else unexplored). It's a gamble: `desperate_success_chance` (0.65) that it lands,
  regardless of distance (a miss falls well short). Never back to where it has been (trail/visited), and never down
  once it has made progress (down = where it came from). Paint appearing during the wind-up cancels it. Won't drop more than
  `max_unpainted_drop` (2.6m) unpainted. Level minimums stay defined as what's *reliable*.
- Improvised landings (leaps of faith, desperate jumps) are never in the death zone (`death_height` + 0.5), and one
  that bounced it straight back to its take-off is crossed off (`_futile_leaps`, `_is_futile_leap`).
- Take-off search (`_link_within`): straight back from the landing toward the tester, else rotated up to ±60°
  (`TAKEOFF_ANGLES`), in 0.2 m steps plus the exact end of its reach (short legs' window can be narrower than a step).
- Take-off points always keep `takeoff_margin` (0.6m) from the edge, and it can never start a jump while airborne
  (if it slips off, it just falls). `desperate_success_chance` is a probability (0-1).
- **Retrace after a fall**: it keeps a **trail** (`_trail`, in order: paint spots it reached and where its unpainted jumps
  landed, with each jump's take-off in `_trail_from` / `_trail_gamble`). Every landing updates the floor it trusts
  (`_home_y`), so landing more than `setback_drop` (1.5m) below it is a fall, whatever got it up there. After a fall it
  heads for the end of the trail (`_retrace_to`, where it fell from): painted links as usual, and the jumps it once made
  can be made again the same way (`_replay_link`: same take-off, same landing; unpainted ones are gambles again). If
  the end isn't reachable it goes to the reachable trail stop furthest along (forward only, `_route_index`), and if
  none is, it explores as usual. Back where it fell, an improvised jump that failed is tried again at once
  (`_failed_jump` → `_retry_jump`, "Round two"). A landing only counts as "made it" if it's near the target in plan
  AND at its height (not 8 m under a coin). A splat on the same floor within 1.5 m counts as visited. `_shaken`: no leap of faith toward the flag until it has done its
  wanders AND `patience` on the new floor. A target within 0.8 m on the same level counts as reached (`_at`: a splat
  painted against a pillar can't be stood on exactly). Slipping off an edge while standing around or winding up a jump
  is a fall too (`_idle_physics`), a jump whose target is out of reach from where it really stands is cancelled, and
  replayed/retried jumps take off a step back from the edge (`_safe_takeoff`).
- **Return after a detour**: after going for a coin or pressing a button (`_detoured`), if it has nothing new to
  try it walks back once to `_furthest` and looks again from there. Plain wandering does NOT count as a detour, and
  neither does smashing planks (they were in the way: the way on is through them).
- **Dead-end return** (`_try_dead_end_return`, before a desperate jump): lost on a SIDE ledge it jumped onto (painted
  or not), it jumps back to where that jump took off ("Dead end. Back the way I came.", a gamble with its Jumping odds),
  once per ledge (`_dead_ends`); the take-off becomes `_furthest`. Side ledge = it got no closer to the waystone (or,
  waystone unseen, no further from the start) than the floor it jumped from (`_is_progress`, 1.5 m): on a floor that
  was progress it improvises onward as before (Parkour routes like Hanging Gardens rely on it).
- It plans **straight walks, or two straight walks around ONE corner** (`_corner_walk`: L-shaped via points, nudged,
  same floor, up to `corner_walk_range` 16 m, cached in `_corner_cache`, cleared when a door moves). No navmesh: a splat
  two corners away can't be planned, it needs a splat in between. Walks keep 0.38 m from walls (`_walkable`).
- **Corridor looks** (`_open_ways`, `corridor_looks` 3 × `corridor_look_time` 1.6 s): out of known paint (end of a
  path, end of a wander walk, careful look) it looks down the open ways one after the other (36 rays at eye height,
  longest sightlines that lead somewhere new, ≥ 2.5 m, 50° apart), turning round for the ones behind it.
  Paint within `focus_angle_deg` (20°) of where its head points is noticed `focus_bonus` (2x) faster.
- **Wander walks** stop short of walls (a wall at 3 m no longer rules out a 2 m walk), 24 directions, and prefer
  open directions (`wander_open_bias`). After a coin/button detour, the walk back to `_furthest` survives replans
  (`_heading_back`).
- Coins are seen without paint but only walked to (`coin_detour` path cost). **Nobody in the fiction calls them coins**:
  the operator's ThinkBox draws coins, the testers see loot, crafting components, collectibles, ammo (runner lines,
  quotes, mails). The patch notes admit crafting was never added. Same for the **flag**: testers see a waystone /
  save point / quest marker. Only the operator (and #3502, who sat at the same desk) calls it a flag. The HUD/results card ("Coins") is the operator's view.
- **AAAA flavor**: the game is a bit of every genre (open-world map icons, survival hunger bar, RPG loot, lore carved in
  the architecture, and some testers sulk they weren't the ones sent to read the lore). Keep it to the occasional
  `ADMIRE`/`GAZE_LINES` line and the patch notes' known issues: subtle.
- Breakables: side paint = smash, top paint = climb; more paint wins, ties are a remembered guess.
- **Hotfixes** (red splats painted mid-playtest) are an order: noticed instantly with line of sight in any direction
  (no view cone, no attention build-up), trusted at `hotfix_trust` (5), top priority, and the whole route to one is
  walked without hesitation or look-arounds. It replans on the spot (`_urgent`). Hotfix paint on a breakable decides it.
- **Moving platforms**: while the floor under it is moving it stands still (`RIDING`), then looks around. Spots on a
  platform that is still moving are ignored until it stops (its `state_changed` triggers a rethink).
- Priorities: unused hotfix > nearby coin (within `coin_detour`, Ascetic: `greed_radius`) > (Loot goblin) coin in jump
  reach > flag > painted interactable > unvisited paint > (Explorer) unpainted button/breakable > leap of faith >
  wander > desperate jump.

## Times (logged, never scored)
- `Runner.session_time` (playtest start → flag) and `time_lost` (`_is_lost()`: confused, wander walks, look-arounds
  between wanders, winding up an unpainted gamble/leap). Reset on R.
- Best session per round saved in `Progress.best_times` (`record_time`); results card shows "Time 0:52 · lost 0:09 (17%)"
  + best / NEW RECORD; level summary shows each tester's time; Level Select shows the best total time.
- Lost ≥ 50% of the session: the tester's quote comes from `FocusGroup.LOST_QUOTES` (hotfix quotes still win), and Chad
  adds a PS to his next mail (`MailWriter.lost_note`) or, if he had nothing else to send, a "time sheet" mail (once per level).

## Scoring (game.gd `score()`)
Per round: start at 5★. Paint penalty relative to the round minimum m (`paint_step_ratios` [0.2, 0.4, 0.5],
`steps_for()` / `paint_steps()`): -1 from m+20%, -2 from m+40%, -3 from m+50% (rounded up, each step at least one
splat after the previous one: m=3 → 4/5/6, m=20 → 24/28/30, m=50 → 60/70/75). Optimal = first step - 1.
The minimum is measured on a run that collects every coin. Can size = max(2 × optimal, -3 step + 1), so the bar is
half green.
Coins: all → 0, more than half → -1, half or fewer → -2, none → -3.
Hotfixes (splats painted during a playtest): each level has `free_hotfixes` (2) shared by its 3 rounds, used up in
round order by each round's finishing run (`round_hotfixes`, `free_hotfixes_left()`); the rest cost 1-3 → -1, 4+ → -2.
HUD and results card show the level's tally "Hotfixes: 3/2" (`hotfix_tally()`: used on this level / budget).
Chad's mails get a PS about them (`MailWriter.hotfix_note`: within budget = tolerated, over = noticed; over budget
with nothing else to send = a "hotfix budget" mail, once per level). Patch notes: `_hotfix_summary` (none / all
within each level's budget / N over budget; `MailWriter.HOTFIX_BUDGET`). Tester quotes: `HOTFIX_QUOTES[0]` sometimes
when only free ones were used. They come from outside the can (no limit,
not in `splats_used`, no paint penalty) and are **removed on R**. From Enter until R the can is in **Hotfix mode**:
can, crosshair, HUD and new splats turn red (`PaintManager.hotfix_color`); hotfix splats are bigger, pop in and pulse.
Minimum 1★. Hotfix quotes in `FocusGroup.HOTFIX_QUOTES`; the tester reacts when it notices one.
Scraping refunds paint. Paint on objects that break or open (planks, doors) is put aside (`PaintManager.remove_marks_on` → `_stashed`), still counted, and comes back with the object on reset (`restore_stashed()` in `_reset_run`: hold R or next tester).
Scraping (and Backspace clear) is **locked during a playtest**: from Enter until R (reset). Adding paint is still allowed
but each splat is a **hotfix** (`PaintMark.hotfix`, counted in `game.gd` `hotfixes`; R deletes them via `remove_hotfixes()`).

## Levels (in `Progress.LEVELS` order)
Lineups are a first pass; per-round minimums are set by the user from playtesting (retune after trait changes).
1. `level_01` Onboarding: paint landings. Rhea Spawn (default), Polly Gonn (loot goblin), Al Gorithm (ascetic).
2. `level_02` Breakables: planks side = smash, crate top = climb; coin on a crate. Bea Tah, Moe Cap, Liv Elup.
   (The standard 3-splat route ends with a leap of faith to the flag: Liv Elup, "No paint, no way", needs it painted.)
3. `level_03` Buttons: two painted buttons/doors, side ledge needs a painted way back. Cass Cene, Lou Tbox, Max Levell.
4. `level_04` The Gauntlet: everything combined. Frank Rate, Dee Sync, Sven Tory.
5. `level_05` The Tower: the user's vertical spiral level. Door2 is an elevator platform (button next to it, rises 10m,
   comes back down after 4 s with nobody on it: `return_after`). David Goodenough, Mike Rotransaction, Rhea Spawn.
6. `level_06` Hanging Gardens (the user's): a JUMP level, each tester takes a different path for their reach.
   Frank Rate, Al Gorithm, Mike Rotransaction.
7. `level_07` The Vault (draft by Claude, for the user to edit): a GREED level. Start → A_Long → B (up a ramp) →
   goal, 3.5 m gaps. Coin1/Coin2 on A_Long (Ascetic only takes Coin1), Coin3 on LedgeSafe (3 m off A_Long's side, a
   miss lands on SafetyTerrace at -1.5 and the Ramp leads up to B), Coin4 on LedgeDeadly (same gap, over the pit).
   The Loot goblin gambles for Coin3 and Coin4 by itself (Coin4's miss is fatal: since the Oct 2026 change it risks it). Al Gorithm (Ascetic), Rhea Spawn,
   Polly Gonn (Loot goblin): only Greed differs. Minimums are placeholders.
8. `level_08` The Secret Room (draft by Claude): an EXPLORATION level. Long platforms with walls: each next landing
   only shows from the far end, so "No paint, no way" needs a walk splat there. **TrapButton** (unpainted, next to
   R2's landing) sinks R4 (a door, `move_direction` down): the Explorer presses unpainted buttons the moment it has no
   painted spot left to go to, so leaning on its exploring ruins the run (it then jumps onto the sunk paint and dies).
   Never paint the trap (painted buttons get pressed by everyone). Breakable plank bridge to the waystone (paint its top
   for the Explorer), coin nook on R2 (walkable: no gamble). Waystone > 22 m away until R4. Cass Cene, Rhea Spawn,
   Bea Tah: only Exploration differs.

DLC 1. `level_dlc_01` Victory lap (**post-launch**, the $4.99 DLC): a straight road blocked by a wall. Its button raises the wall
   AND `Geometry/Maze` (every maze wall is a door, sunk 3.6 m into the block), so the route has to be painted blind.
   Sven Tory, David Goodenough, Bea Tah (the extremes). Gap under Door7's end (z 13.6-15) is a known shortcut.

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
  made from `art/Logo.png`), output `windows/YellowPaint.exe` (git-ignored). Excludes `docs/`, `tools/`, `*.md`.
- Boot splash = `art/boot_splash.png` (the desktop wallpaper rendered without icons, bg `#0C1528`): it fades into an
  identical desktop. Re-render it if the wallpaper or `paint_splat.png` changes.
- Before exporting: `yellow_paint/debug/unlock_all_levels` must be false (it only works in debug builds anyway).
- Web (Compatibility renderer) doesn't draw the paint Decals: a web build needs a fallback first.

## Workflow
- Changes go on branches (`claude/...`) and pull requests to `master` (Claude can open and merge PRs with `gh api`).
  - **Big features or design changes** (new mechanics, trait redesigns, new systems): Claude opens the PR and the
    **user reviews and merges** it. Always give the user the PR link when a PR needs their review.
  - **Bug fixes and small tweaks**: Claude opens the PR and **merges it itself** once its tests pass, then tells the user.
  - The user pulls with Godot closed or reloads when prompted.
- Godot's open editor can overwrite files changed on disk (script editor buffers). Never assume a write landed, verify.
- Fly down is Ctrl only (C is the tester card).
- **F10 = recording view** (debug builds only, `game.gd` `_toggle_recording_view`): hides the whole HUD and the
  tester's speech bubble; F10 again shows them. Hard-coded key, not in the Input Map or the controls list.
- **Fast-forward** (T, `fast_forward`, physical): during a playtest (Enter until the flag/death/R) cycles
  `game.gd` `fast_forward_speeds` 1x / 2x / 4x (HUD "▶▶ 4x"). Sets `Engine.time_scale` AND scales
  `physics_ticks_per_second`, so the physics step stays 1/60 and the AI plays exactly the same. Back to 1x on
  goal, death, R / next tester and leaving. The operator (`character.gd`), the R hold bar, HUD timers and the
  speech feed undo the time scale, so they stay real-time.
- Input actions use **physical** keycodes (the user is on AZERTY) except menu keys (N, Esc) which use logical keycodes.
- Controls are listed in the Settings menu (`settings_menu.gd` `CONTROLS`), not on the HUD. Add new actions there too.
- Test scripts can live outside the project (e.g. a scratchpad) and be run with `--script /abs/path.gd`; don't reference
  `Level`/autoload class names at the top level of a test script (they compile before autoloads exist).
