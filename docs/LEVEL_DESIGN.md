# Level design guide

How to make a Yellow Paint level, from an empty file to a tuned, playable level.

## 1. Create the level

**Easiest: the New Level tool**
1. In Godot, open `tools/new_level.gd` in the Script editor.
2. **File > Run** (Ctrl+Shift+X).
3. It creates the next free `levels/level_XX.tscn` from `levels/_template.tscn` and opens it.

**By hand:** duplicate `levels/_template.tscn` (or any existing level) in the FileSystem dock and
name it `level_XX.tscn`.

Levels appear in the level select **automatically**, in file-name order (`level_01`, `level_02`...).
The template starts with `_`, so it's ignored. To reorder levels, rename the files.

## 2. What a level contains

| Node | What it is |
|---|---|
| Root (`level.gd`) | Settings in the Inspector: `level_name` (menu/HUD), `intro_text` (shown at start), `death_height`, `post_launch` (Patch 1.1 bonus level, see 7), and **Round 1-3**: a tester (dropdown) and that round's `minimum`. |
| `RunnerSpawn` (Marker3D) | Where the playtester starts. Put it **0.9 above the floor** (its origin is at its middle). |
| `OperatorSpawn` (Marker3D) | Where you start. **1.05 above the floor**. Rotate it to choose the starting view. |
| `Geometry` | Static blocks: instances of `debug_block.tscn`. |
| `Interactables` | `breakable.tscn`, `door.tscn`, `wall_button.tscn` instances. |
| `Coins` | `coin.tscn` instances. A coin's origin sits **on the floor**. |
| `Goal` | `goal.tscn`: the flag. Its origin sits **on the floor**. |

If something required is missing, the root node shows a ⚠ warning in the Scene dock. Hover it for details.

## 3. Building blocks

- Add a block: instance `debug_block.tscn` under `Geometry`, then set **`size`** and **`color`** in the Inspector.
- **Never scale blocks** with the scale gizmo. Physics and the grid texture break; change `size` instead.
- The grid on blocks is **1 m**, so you can count distances by eye. Turn on snapping (Transform > Configure Snap) at 0.5 or 1.
- A block's position is its **center**. For a platform whose top is at `y = 0` with height 4, the center is at `y = -2`.
- Add a pit floor (dark red in the template) below everything. Its top should be below `death_height` (default -2.5),
  so falling there means the playtester is lost. The operator can fly back up (F) or jetpack (hold Space).

## 4. What the playtester can and can't do

Design around these numbers (they're exports on the Runner, in `runner.tscn`):

| Ability | Value | Notes |
|---|---|---|
| Jump distance | **5.5 m** horizontal | From take-off to landing. It takes off 0.6 m back from an edge. A gap of **~4 m** is the comfortable maximum. |
| Jump height | **2.5 m** up | Higher ledges need a step (a crate, a lower ledge). |
| Drop onto paint | up to **8 m** | It trusts paint, even paint in a pit. |
| Unpainted drop | up to **2.6 m** | Without paint it won't jump down further than that. |
| Steps it walks up | **~0.45 m** | Anything higher counts as a ledge (needs a painted jump). Ramps up to ~25° are walkable. |
| Vision | **22 m**, 100° cone | It must *see* paint (line of sight) for a moment before it knows about it. Single splats can be missed. |
| Coin detour | path cost **16** | It walks to coins it sees. A coin past a gap needs paint to get there and **paint to get back**. |

Behaviour that matters for layout:
- **Paint marks the landing.** One splat on the far side of a gap is enough; it walks to a take-off spot itself.
- **It sees the flag** from up to 22 m. Once seen, it may try an unpainted "leap of faith" toward it.
  If you want players to paint the last jumps, keep the flag out of sight until late (distance, walls, doors).
- **When lost** for a few seconds (no reachable paint, nothing to do), it gambles on an unpainted jump: a
  ~65% chance to land. Short safe hops make levels easier than you think; long gaps over pits stay dangerous.
- **Dead ends need a way back.** A side ledge with a coin or button needs a painted splat back on the main path.
- **Falls aren't the end.** If it falls (by accident) to a lower floor it survives, it retraces its painted route
  back to the furthest point it reached. That only works if the paint it already used is reachable from where it
  landed: on a tower, a splat at the bottom of each climb lets a fallen tester find the way back up.
- **It walks in straight lines.** It plans straight walks between points and can't route around a pillar or corner.
  On winding paths, put a splat at each turn (or accept that it will explore/improvise there).

## 5. Interactables

- **Breakable** (`breakable.tscn`): set `size` and `color` like a block. Paint on a **side** = smash it. Paint on
  the **top** = stand on it. Use it as a wall to smash (planks) or a step to climb (crate). If both are painted, more paint wins.
- **Door + Button**: place `door.tscn` (default 0.5 x 3.5 x 6, slides up 3.6 m) and `wall_button.tscn`.
  Set the button's **`target`** to the door (`../Door`). The button's face points along its **-Z**, i.e. opposite
  the blue Z gizmo arrow. The playtester stands 0.9 m in front of the face. Only **painted** buttons get pressed.
  Painting a door does nothing (that's the joke).
- **One button, many doors**: fill the button's **`extra_targets`** with more doors; one press opens them all.
  A target can also be a plain Node3D: every door inside it opens (level 6: `extra_targets = ../Maze`, ~35 walls).
  Each door still moves by its own `move_direction`/`move_distance`, and the cyan ghosts show where they end up.
  To hide a group underground, lower the group node (level 6's `Maze` sits at Y -3.6) and set it back to 0 to edit.
- **Things that move together**: blocks or doors parented **under a door** ride along with it, colliders
  included. Never scale the door or a parent of blocks: resize with `size`.
  - **`move_direction`** / **`move_distance`**: which way and how far it slides (any axis, e.g. `(0, 0, 1)` to slide
	sideways). **`open_time`**: how long it takes. The editor shows a **cyan ghost** where it ends up.
- **Moving platform**: a `door.tscn` with **`is_platform`** on. Paint on its **top** is a landing like any other,
  and the paint **rides along** when it moves. The playtester stands still while the floor moves under it, and
  won't jump onto a platform that's still moving (it waits for it to stop). Two setups that work:
  - **Elevator**: platform flush with the floor, button standing on it (the tester stands on the platform to press
	it), and paint on the platform top. The tester walks on, presses, rides up, then looks around from the top.
  - **Bridge**: platform off to the side, slides into a gap when the button is pressed. Paint its top where it rests;
	the paint comes along, and the tester jumps onto it once it has arrived.
  - Make the platform's top a hair **higher** than any block around it (e.g. +0.01), otherwise your paint can land on
    the block instead and stay behind when the platform leaves.
  - It moves once (when the button is pressed) and stays there. R puts it back.
- **Coin** (`coin.tscn`): visible to the playtester without paint. Count them: all coins = no star penalty.

Everything resets when the player holds R (retry) (doors close, crates come back, coins return).

## 6. Test it

- **F6** on the level scene launches it inside the game.
- Press **V** in game to see what the AI knows: vision cone (cyan), noticed paint (green posts, taller = more trusted),
  planned route (white walk / orange jump), interactables it plans to use (magenta), coins it has seen (gold).
- Press **A** (AZERTY; the key left of Z) to follow the playtester with the spectator camera.

## 7. Where the level appears

Levels 1-3 are the tutorials and are always in Level Select. Every level after that is **hidden** until **every**
level before it has scored at least **10/15**.

**Testing:** turn on Project > Project Settings > (Advanced Settings) > **Yellow Paint > Debug > Unlock All Levels** to
see every level in Level Select. It only works in the editor / debug builds, and it doesn't send the unlock emails. Then Chad emails the player that a new playtest was scheduled (with the new
level's testers), plus one or two flavor emails, one of them about one of your testers. So the file order is also the
unlock order: make sure each level is beatable at 10/15 by someone who just finished the previous one.

**The last level ends the game.** Once the last level (that isn't post-launch) has 10/15 or more, along with every
level before it, Chad sends the greenlight mail and the player can ship. The ending depends on the best scores of
every level **after the tutorials** (levels 4+): 15 on all of them = Investors, exactly 10 on all of them = GOTY,
anything else = Decent. Adding a level 6 later changes what each ending asks for, and the new level becomes the
one that triggers the greenlight.

**Post-launch level (the $4.99 "secret area")**: tick **Post Launch** on the level root. It stays hidden until the
game has shipped (Patch 1.1), never holds other levels back, doesn't count for the ending, and Chad's Patch 1.1
mail names it. Give it a file name after the main levels (e.g. `level_06.tscn`).

## 7b. Pick the 3 testers

Every level is played by 3 focus testers in a row; the player's paint carries over from one to the next.

**To set a level's testers:** select the level's root node, and in the Inspector open **Round 1**, **Round 2** and
**Round 3**. Each has:
- `Tester N`: a dropdown of everyone in the roster below.
- `Minimum N`: the fewest splats that reliably get **that tester** to the flag (see section 8). Optimal = minimum + 5.

The root shows a ⚠ if a tester is used twice in the level, isn't in the roster, has more than one ★☆☆ trait,
or a minimum is 0.

### What the stars mean

Each tester has three traits, shown to the player only as stars (never the names below):

| Trait | ★☆☆ | ★★☆ (default) | ★★★ |
|---|---|---|---|
| Jump precision (unpainted jumps) | Incapable: tries, always falls short | Hit or miss: ~65% | Precise: ~95% |
| Trust | Needs a whole bucket: **2 splats** on a landing before jumping there, slow to decide | Thoughtful | Blind trust: one splat = full confidence, fast |
| Exploration (when lost) | No paint, no way: looks around, but **never** jumps unpainted (no leaps of faith either) | Curious: a few look-arounds, improvises after ~8 s | Explorer: wanders further and twice as long, improvises late (~16 s) |

The numbers behind the stars are in `runner.gd`, export group "Traits" (one value per star level).

### The roster

| Tester | Outlet | Jump precision | Trust | Exploration |
|---|---|---|---|---|
| Rhea Spawn | IBN | ★★☆ Hit or miss | ★★☆ Thoughtful | ★★☆ Curious |
| Polly Gonn | Polygone | ★★☆ Hit or miss | ★★★ Blind trust | ★★☆ Curious |
| Al Gorithm | GameFAKs | ★★☆ Hit or miss | ★☆☆ Needs a whole bucket | ★★☆ Curious |
| Bea Tah | Early Axess Weekly | ★★☆ Hit or miss | ★★☆ Thoughtful | ★★★ Explorer |
| Moe Cap | Game Misinformer | ★☆☆ Incapable | ★★☆ Thoughtful | ★★☆ Curious |
| Liv Elup | Rock Paper Shortcut | ★★★ Precise | ★★☆ Thoughtful | ★☆☆ No paint, no way |
| Cass Cene | Cinematic Universe Digest | ★★☆ Hit or miss | ★★☆ Thoughtful | ★☆☆ No paint, no way |
| Lou Tbox | Kotakoo | ★★★ Precise | ★★☆ Thoughtful | ★★★ Explorer |
| Max Levell | Eurogamble | ★★★ Precise | ★☆☆ Needs a whole bucket | ★★☆ Curious |
| Frank Rate | PC Gamerish: 240 FPS Edition | ★★★ Precise | ★★★ Blind trust | ★★★ Explorer |
| Dee Sync | Twitchy (streamer, 14 viewers) | ★☆☆ Incapable | ★★★ Blind trust | ★★☆ Curious |
| Sven Tory | Destructoad | ★★☆ Hit or miss | ★☆☆ Needs a whole bucket | ★★★ Explorer |
| David Goodenough | The Casual Observer | ★★☆ Hit or miss | ★★★ Blind trust | ★☆☆ No paint, no way |
| Mike Rotransaction | Freemium Times | ★☆☆ Incapable | ★★☆ Thoughtful | ★★★ Explorer |

### Current lineups

The minimums are placeholders until measured in playtesting.

| Level | Round 1 | Round 2 | Round 3 |
|---|---|---|---|
| `level_01` Onboarding | Rhea Spawn (min 3) | Polly Gonn (min 3) | Al Gorithm (min 6) |
| `level_02` Breakables | Bea Tah (min 3) | Moe Cap (min 3) | Liv Elup (min 3) |
| `level_03` Buttons | Cass Cene (min 6) | Lou Tbox (min 6) | Max Levell (min 12) |
| `level_04` The Gauntlet | Frank Rate (min 10) | Dee Sync (min 10) | Sven Tory (min 20) |
| `level_05` The Tower | David Goodenough (min 20) | Mike Rotransaction (min 20) | Rhea Spawn (min 20) |

### Add a new tester

Open `focus_group.gd` and add a line to `ROSTER`:

```gdscript
"Jen Erik": {jump = 1, trust = 2, patience = 0,
	outlet = "Gamespotty",
	intro = "A line hinting at how they play, shown on the round card."},
```

Traits go from 0 (★☆☆) to 2 (★★★), 1 is the default. **Rule: at most one trait at 0.**
`outlet` is the (parody) games site or magazine they write for; `intro` is shown on the round card and should hint
at their archetype without giving numbers.
Save, and the name appears in every level's tester dropdown (click another node and back if the Inspector doesn't
refresh). Add the tester to the roster table above too.

### Picking a lineup

Ideas: start with someone easy-going, end with the one whose weak trait the level punishes:
- **Needs a whole bucket** on a level of long jumps: every landing needs 2 splats.
- **No paint, no way** where the default tester would leap to the flag or gamble on a short hop: those need paint now.
- **Incapable** combined with **Explorer**: it improvises fast and always fails, so the paint has to be there before it gets bored.
- **Blind trust** or **Precise + Explorer**: generous rounds, where a low minimum rewards a player who paints little.

## 8. Set each round's `minimum`

A round's `minimum` is the fewest splats that **reliably** get **that tester** to the flag, ignoring coins.
Optimal (5★ territory) is `minimum + 5`, and the can holds `minimum + 15`. The level score is the 3 rounds added up (out of 15).

1. Play the round painting only what's strictly needed. Count the splats.
2. Try it a few times: the AI is a bit random. If it only works sometimes, it's not the minimum yet.
3. Make sure **all coins plus the minimum** fit within optimal (+5). If coins need more than 5 extra
   splats, a 5★ run is impossible; move coins or raise the minimum.
4. Remember the paint carries over: the round-2 minimum counts all the paint on the level, including what was
   left from round 1 (a "bucket" round usually means doubling the landings that matter).

## 9. Checklist

- [ ] `level_name` and `intro_text` set; no ⚠ on the root
- [ ] RunnerSpawn 0.9 above floor, OperatorSpawn 1.05 above floor
- [ ] Pit floor below `death_height` everywhere the playtester can fall
- [ ] Every gap ≤ ~4 m (or deliberately impossible); every rise ≤ 2.5 m (or has a step)
- [ ] Side ledges have room for a painted way back
- [ ] Buttons have their `target` set and face where the playtester will stand
- [ ] Flag visibility is intentional (leaps of faith)
- [ ] 3 different testers picked; each round's `minimum` measured; all coins reachable within optimal
- [ ] Lineup table in this guide updated
