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
| Root (`level.gd`) | Settings in the Inspector: `level_name` (menu/HUD), `intro_text` (shown at start), `death_height`, and **Round 1-3**: a tester (dropdown) and that round's `minimum`. |
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
- **Coin** (`coin.tscn`): visible to the playtester without paint. Count them: all coins = no star penalty.

Everything resets when the player presses R (doors close, crates come back, coins return).

## 6. Test it

- **F6** on the level scene launches it inside the game.
- Press **V** in game to see what the AI knows: vision cone (cyan), noticed paint (green posts, taller = more trusted),
  planned route (white walk / orange jump), interactables it plans to use (magenta), coins it has seen (gold).
- Press **A** (AZERTY; the key left of Z) to follow the playtester with the spectator camera.

## 7. Pick the 3 testers

Every level is played by 3 focus testers in a row; the player's paint carries over from one to the next.
Pick them in the root's **Round 1/2/3** groups (dropdown of `FocusGroup.ROSTER`). Each tester has three traits,
shown to the player only as stars (★☆☆ / ★★☆ / ★★★):

| Trait | ★☆☆ | ★★☆ (default) | ★★★ |
|---|---|---|---|
| Jump precision (unpainted jumps) | Incapable: tries, always falls short | Hit or miss: ~65% | Precise: ~95% |
| Trust | Needs a whole bucket: **2 splats** on a landing before jumping there, slow to decide | Thoughtful | Blind trust: one splat = full confidence, fast |
| Patience (before improvising) | No paint, no way: **never** jumps unpainted (no leaps of faith either) | Lost fast: ~8 s | Explorer: ~3 s |

A tester has at most one ★☆☆ trait. Ideas for a lineup: start with someone easy-going, end with the one whose
weak trait the level punishes (a "bucket" tester on a level of long jumps, a "no paint, no way" one where the
default tester would leap to the flag). The numbers behind the stars are in runner.gd, "Traits" export group.

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
