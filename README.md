# SimpleSkillWatch

A small, movable frame for **World of Warcraft: Forever** that shows your weapon, defense and profession skills as colored bars, so you can see at a glance what needs leveling, what needs training, and when you've equipped a weapon you're bad with.

*by Gnare*

## Features

- **Skill bars** for weapons and Defense, professions (primary and secondary), and other ranked skills (Riding, Lockpicking and the like). Each bar shows `rank/max`, plus a green `(+N)` (or red `(-N)`) when gear or racials modify the skill.
- **Weapon colors**: red below a percentage of max (default 75%), yellow in between, green within a few points of max (default 5).
- **Profession training reminders**: the bar turns red with a **TRAIN** tag as soon as you have the skill for the next rank (Journeyman 50, Expert 125, Artisan 200; Artisan Cooking, First Aid and Fishing 225). Blue otherwise, and **gold** at the profession skill cap.
- **Profession alerts**: a sound, a chat line and a line near the top of the screen (for 6 seconds, or as long as you set) when a skill-up leaves a profession at TRAIN, and a harsher sound when it's stuck at its trained cap (e.g. 150/150) and can't go up until you train. While it's stuck, every craft or gather that could have given a point alerts again (grey recipes and grey nodes don't). You pick both sounds from a list (the game's own, plus any that other addons share through LibSharedMedia). At TRAIN it sounds at most once every 20 seconds per profession. Never at the profession skill cap, and never for weapons or hidden skills.
- **Low weapon skill warning**: a red border (optionally pulsing) on the bar of a red weapon skill you have equipped, or on Unarmed with an empty main hand or while you're disarmed. Updates instantly on weapon swaps and disarms, including in combat.
- **Thrown charges**: with a thrown weapon equipped, the Thrown bar shows its durability (its charges), e.g. `Thrown (154/200)`, turning bright yellow below a threshold (default 30%).
- **Picks up new skills automatically**: learning a weapon skill, profession or rank, or gaining skill points, updates the frame right away.
- **Customizable look**: scale, width, background and bar opacity, font (including fonts other addons share through LibSharedMedia) and font size, title on or off, and whether the frame grows up or down as it gets taller (it's always kept on screen).
- **Only show equipped weapon**: optionally hide weapon skills you aren't using, so the frame shows just your equipped weapons plus Defense (and Unarmed if you like). Updates as you swap.
- **Stacked or side by side**: Weapons above Professions, or next to each other (either way round).
- **Lock** the frame in place to make it click-through. The padlock in the corner stays clickable either way: open when unlocked, closed (and dimmed) when locked. Each character has its own lock, and new characters start unlocked.
- **Minimap button**: left-click opens the settings, right-click shows or hides the frame, and you can drag it around the minimap's edge (each character keeps its own spot). Turn it off on the Frame tab if you don't want it.
- **Profiles**: save your settings under a name and use them on other characters. Each character uses one profile, named after its class by default.
- **Light on resources**: no polling or per-frame updates. The frame redraws only when the game signals a skill, equipment or durability change, and bursts of signals are combined into one redraw.

## Installation

**With an addon manager** (CurseForge app, WoWUp): search for SimpleSkillWatch under WoW: Forever.

**By hand:**

1. Download the latest zip from CurseForge or from this project's GitHub Releases, and extract it.
2. Put the `SimpleSkillWatch` folder in your WoW: Forever `Interface\AddOns` folder. (In the Battle.net app, use the gear next to Play → *Show in Explorer* to find your game folder.)
3. Type `/reload` in game, or restart the game.

On login you'll see `SimpleSkillWatch (VERSION) loaded. /sskw for settings.`

The addon learns your skills from the game's Skills list. Skills under a **collapsed** group in the Skills tab (C) aren't listed by the game, so expand each group once if something is missing.

## Settings

Open the settings window with `/sskw`, by right-clicking the frame while it's unlocked, or from **Options → AddOns → SimpleSkillWatch** (that button closes Blizzard's Options window and opens SimpleSkillWatch's settings). The window is movable and remembers its position and last tab.

| Tab | What's there |
|---|---|
| **Frame** | Show frame, show title, lock (click-through, this character only), minimap button, grow direction, layout (stacked, side by side, flipped), scale, width (per column), background and bar opacity |
| **Text** | Font and font size |
| **Skills** | Only show equipped weapon (plus Defense, optionally Unarmed), and checkboxes to hide or show individual skills |
| **Alerts** | Weapon thresholds and the low weapon skill warning; thrown charges and the low-charges alert; profession training rules and skill cap; profession alerts, their two sounds, whether the message also shows on screen and for how long |
| **Profile** | Switch this character's profile, save the current settings as a new profile, copy another profile into this one, or delete one |

Every slider, the font and both sounds have a revert arrow that restores the default. Click a sound in its list to hear it and choose it; the list stays open so you can try several. **Defaults** (with a confirmation) resets the current profile, except the frame position and hidden skills.

### Profiles

A profile holds every setting plus your hidden skills. Frame position, lock, the minimap button's spot and the list of learned skills always stay per character.

- **New characters** get a profile named after their class (e.g. "Warrior"). If a profile named **Default** exists, the new profile starts as a copy of it; otherwise it starts from the built-in defaults.
- **Same settings on every character**: pick one profile (e.g. "Main") on each of them. Changes made on one show up on all characters using it.
- **Per-class setups**: pick your main profile, adjust it, then use **Save as new profile** to keep the result under its own name.
- **Upgrading from 0.10.x or earlier**: your existing settings become the **Default** profile, and each character starts on a copy of it under its class name.

## Slash commands

| Command | Does |
|---|---|
| `/sskw` | Open or close the settings window |
| `/sskw show` · `hide` · `toggle` | Show or hide the frame |
| `/sskw lock` · `unlock` | Lock (click-through) or unlock the frame (same as clicking the padlock) |
| `/sskw reset` | Move the frame back to its default position |
| `/sskw title` | Show or hide the title |
| `/sskw minimap` | Show or hide the minimap button |
| `/sskw grow up` · `down` | Which way the frame extends as it grows |
| `/sskw layout stacked` · `side` · `flipped` | Weapons above, left of, or right of Professions |
| `/sskw weapon <redPct> <greenPts>` | Weapon thresholds (default `75 5`) |
| `/sskw prof <pct>` | Fallback TRAIN threshold when trainer rules are off (default 90) |
| `/sskw cap <n>` | Profession skill cap (default 300) |
| `/sskw trainreqs` | Toggle TRAIN by trainer requirements |
| `/sskw warn` · `pulse` | Toggle the low weapon skill warning, or its pulse |
| `/sskw equipped` · `unarmed` | Only show equipped weapon skills, or also keep Unarmed |
| `/sskw charges` | Toggle thrown charges on the Thrown bar |
| `/sskw lowcharges [5-80]` | Toggle the low-charges alert, or set its threshold |
| `/sskw alerts` · `alerts test` | Toggle profession alerts, or try both of them now |
| `/sskw alerttime <1-30>` | Seconds the alert stays on screen (default 6) |
| `/sskw scale <0.5-2>` · `width <n>` · `fontsize <8-18>` | Size settings |
| `/sskw bg <0-100>` · `bars <0-100>` | Background and bar opacity, in percent (default 35 and 70) |
| `/sskw font <name>` | Pick a font by name |
| `/sskw ignore <skill>` · `unignore <skill>` | Hide or show a skill by name |
| `/sskw profile [name]` | List profiles, or switch this character to one |
| `/sskw settings` | Print the current profile and settings |
| `/sskw rescan` | Rebuild the skill list |
| `/sskw events` · `disarmlog` · `debug` · `fontinfo` | Diagnostics |
| `/sskw castlog` · `castlog copy` · `castlog clear` | Diagnostic: record what the game reports while you craft or gather (type it again to stop), open the record in a window to copy, or empty it |

`/simpleskillwatch` works as an alternative to `/sskw`.

## Notes and limitations

- **Training requirements** aren't available to addons outside a trainer window, so they're built in. They match what Forever's trainers show (skill only, no level requirement). The Artisan values for Cooking, First Aid and Fishing come from Classic and haven't been confirmed on Forever.
- **In combat**, Forever can hide skill and durability values from addons. SimpleSkillWatch keeps showing the last values it read until combat ends.
- **Disarms**: in combat, Forever hides what kind of control effect you're under. SimpleSkillWatch treats a loss-of-control effect with priority 3 (the one value always readable) as a disarm, as long as you still have control of your character. Priorities seen in game so far: 1 root (e.g. Frost Nova), 2 interrupt / school lockout, 3 disarm; stuns, fears and charms take control away and are ignored. If another effect turns out to share priority 3, Unarmed may light up briefly. `/sskw disarmlog` shows what the game reports.
- **Fist weapons**: the warning tries Classic's "Fist Weapons" skill first, then Unarmed. Which one Forever uses hasn't been confirmed.
- **Profession alerts**: the game doesn't tell addons about a skill-up you missed at the trained cap, so SimpleSkillWatch alerts again whenever you finish a craft whose recipe isn't grey, or gather from a node that isn't grey. A node's color is read from its tooltip as you start gathering; if the tooltip isn't showing, the alert plays anyway. Tested with herbs; mining and skinning should work the same way but haven't been confirmed, and fishing doesn't repeat the alert. Alert sounds play on the Master channel, so they're heard with sound effects turned off (not with all sound off). Some built-in sounds may be silent on Forever; pick another if one is.
- **Fonts** from other addons may take a moment to load right after login. The default font is shown until they do.

## Compatibility

Built for World of Warcraft: Forever (interface 16001). Optional: LibSharedMedia-3.0 (usually bundled with other addons) for extra fonts and alert sounds.

## Development

Changes are tested against a small mock of the WoW API, no game client needed:

```
pip install lupa
python tests/run_tests.py
```

Releases are published by pushing a version tag (e.g. `v1.0.1`); GitHub Actions runs the tests and uploads the build to CurseForge and GitHub Releases. See `CLAUDE.md` for details.

## License

MIT, see `LICENSE`.
