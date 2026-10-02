# Sound effects

Drop a file here named after the sound and it plays automatically. No code changes needed.
Any of `.ogg` (recommended), `.wav` or `.mp3` works, e.g. `spray.ogg`.
Missing files are silent, so you can add them one at a time.

| File name | When it plays |
|---|---|
| `spray` | Every paint splat (repeats quickly while holding the button, so keep it short) |
| `scrape` | Paint scraped off |
| `out_of_paint` | Painting with an empty can, or scraping during a playtest |
| `jump` | Playtester jumps |
| `land` | Playtester lands |
| `fall` | Playtester falls to its doom |
| `voice` | Playtester says something (a short blip; pitch is randomised so it sounds like babble) |
| `desperate` | Playtester winds up a desperate unpainted jump |
| `coin` | Coin collected |
| `button` | Button pressed |
| `smash` | Breakable smashed |
| `door` | Door opens |
| `goal` | Level complete |
| `ui_click` | Menu button clicked |
| `mail` | New email in Inlook (desktop notification) |

The list lives in `sfx.gd` (`SOUNDS`). To add a new sound, add a line there and call
`Sfx.play("name")` where it should play. Volume is controlled by the Master volume in Settings.

Tips: free sounds at freesound.org, kenney.nl (CC0 packs) or opengameart.org. Check the license.
