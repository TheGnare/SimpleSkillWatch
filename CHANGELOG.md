# Changelog

All notable changes to SimpleSkillWatch. Versions follow major.minor.patch.

## Unreleased
- **Profession alerts**: a sound, a chat line and a line near the top of the screen when a skill-up leaves a profession at TRAIN (at most once every 20 seconds per profession), and a harsher sound when it's stuck at its trained cap. While it's stuck, every craft or gather that could have given a point alerts again (grey recipes and grey nodes don't). Never at the profession skill cap, and never for weapons or hidden skills. On by default; turn it off on the Alerts tab or with `/sskw alerts`. `/sskw alerts test` tries both. The on-screen line stays for 6 seconds, then fades; change that on the Alerts tab or with `/sskw alerttime <1-30>`.
- Both alert sounds are picked from a list on the Alerts tab: ten of the game's own sounds, plus any shared by other addons through LibSharedMedia. Click one to hear it and choose it. They play even with sound effects turned off.
- Alerts tab: thrown weapon settings moved to the left column, under the weapon settings.
- **Minimap button**: left-click opens the settings, right-click shows or hides the frame, drag it around the minimap's edge (each character keeps its own spot). On by default; turn it off on the Frame tab or with `/sskw minimap`.
- SimpleSkillWatch now has its icon in the game's AddOns list.
- `/sskw castlog` (diagnostic): records what the game reports while you craft or gather. `/sskw castlog copy` opens the record in a window to copy from.

## 1.0.0
- First public release, on GitHub and CurseForge. Same features as 0.14.0.

## 0.14.0
- The padlock stays on the frame: open when unlocked, closed when locked. Click it to toggle. While locked the rest of the frame stays click-through and the padlock is dimmed (full brightness on hover).
- Lock is now saved per character instead of in the profile, so new characters start unlocked. Characters that already placed their frame keep their current lock state.
- Known loss-of-control priorities (1 root, 2 interrupt, 3 disarm) noted in the code and README.

## 0.13.4
- Disarm detection works on Forever: when an effect's type and text are hidden, a loss-of-control effect with priority 3 while you still have control counts as a disarm of the main hand (priority 3 observed for disarms in game).

## 0.13.3
- `/sskw disarmlog` now prints every field of a loss-of-control effect, and your attack speed, weapon damage and control state when they change (watched only while the log is on).
- Loss-of-control signals for other units (e.g. "targettarget") are ignored.

## 0.13.2
- Disarm detection also uses the newer per-unit loss-of-control lookup, and recognizes a disarm by its display text when its type is hidden.
- `/sskw disarmlog` (diagnostic, this session only): prints what the game reports when you're disarmed.

## 0.13.1
- Disarms are now detected: a disarmed main hand counts as Unarmed (for the low skill warning and "Only show equipped weapon"), and a disarmed off-hand or ranged weapon drops out. Checked when your own buffs/debuffs or gear state change, with a once-a-second recheck only while disarmed.
- `/sskw events` lists the disarm signals and reports whether disarm detection is available and how many disarms it has seen.

## 0.13.0
- **Only show equipped weapon** (Skills tab): shows only the weapon skills you have equipped (main hand, off hand, ranged), plus Defense; an empty main hand counts as Unarmed. Updates as you swap weapons. Nested **Still show Unarmed** keeps Unarmed visible too. While on, the weapon checkboxes are greyed out, and your choices return when it's turned off.
- `/sskw equipped` and `/sskw unarmed`.

## 0.12.0
- **Layout** (Frame tab): **Stacked** (Weapons above Professions, as before), **Side by side** (Weapons left, Professions and Other right), or **Flipped** (Professions left). Width applies to each column; height follows the taller column.
- `/sskw layout stacked | side | flipped`.

## 0.11.2
- Confirmation dialogs (Defaults, Copy, Delete) now dim and block the whole settings window behind them, as intended; before, only the dialog itself caught clicks.

## 0.11.1
- Fixed the Thrown name staying cut short ("Th... (200/200)") after resizing, rescaling or changing the font: the name's full width is now measured every time, not its previously cut-off width.

## 0.11.0
- **Profiles** (Ace3-style), on a new **Profile** tab: switch this character's profile, save the current settings as a new profile, copy another profile into the current one, or delete one (copy and delete ask first).
- Each profile holds every setting plus hidden skills; frame position and learned skills stay per character.
- New characters get a profile named after their class, started as a copy of **Default** if it exists.
- Existing settings migrate into a **Default** profile automatically.
- **Defaults** now resets the current profile and names it in the confirmation.
- `/sskw profile [name]` lists profiles or switches to one.

## 0.10.7
- New defaults: weapon "red below" 75% (was 80%), background opacity 35% (was 75%), bar opacity 70% (was 100%). Settings you've already changed are kept; the new defaults apply to fresh installs, the revert arrows, and Defaults.
- README: install works with `/reload`; generic version in the login line.

## 0.10.6
- Added README and CHANGELOG.
- `/sskw help` now calls `cap` the profession skill cap, matching the settings window.

## 0.10.5
- A font that isn't loaded yet no longer leaves the bars blank: the default font shows until it's ready.
- No more false "Couldn't set font" message at login. A message appears only if a font never loads (e.g. its addon was removed).

## 0.10.4
- Fixed font list entries (and bars) staying blank on a fresh game launch until scrolled: entries are now redrawn a few times after the list opens or scrolls, forcing a real redraw each time.

## 0.10.3
- **Defaults** now asks for confirmation. Frame position and hidden skills are kept.

## 0.10.2
- Blizzard UI sounds on tab switches, checkboxes and radio buttons, and opening/closing the settings window.

## 0.10.1
- The button in Options → AddOns now closes Blizzard's Options window and pops the settings window out, so closing Blizzard's window can't take it along.

## 0.10.0
- **Grow direction** (Frame tab): the frame extends downward (top edge fixed) or upward (bottom edge fixed). Switching doesn't move the frame.
- Larger "by Gnare" credit (14pt).

## 0.9.0
- Settings window split into **Frame**, **Text**, **Skills** and **Alerts** tabs.
- Skills tab uses two columns: weapons on the left, professions and Other on the right.
- "Game cap" renamed **Profession skill cap**.
- The settings window resizes to the active tab, keeps its top edge in place, and remembers the last tab.

## 0.8.0
- **Thrown charges**: the Thrown bar shows an equipped thrown weapon's durability, e.g. `Thrown (154/200)`, in bright yellow below a threshold (default 30%, adjustable 5–80%). Updates on every throw, touching only the Thrown bar.

## 0.7.2
- "Gnare" credit color changed to `#4D5FFF`.

## 0.7.1
- Separate toggles: **Warn when weapon skill low** and **Pulse warning** (steady border when off).
- "by Gnare" credit in the settings window.

## 0.7.0
- **Low weapon skill warning**: pulsing red border on the bar of a red weapon skill you have equipped (or Unarmed with an empty main hand). Updates instantly on weapon swaps, including in combat.

## 0.6.3
- Login message: `SimpleSkillWatch (vX) loaded. /sskw for settings.`
- Also rescans when spells change (weapon training and profession ranks are learned as spells).
- `/sskw events` shows which game signals the addon listens to and how often each fired.

## 0.6.2
- First attempt at fixing blank font list entries on first use (superseded by 0.10.4).

## 0.6.1
- TRAIN depends on skill only. Forever's trainers have no level requirement for rank training.

## 0.6.0
- **TRAIN** now follows trainer requirements (next rank's required skill) instead of a percentage of the trained cap. The percentage remains as an option.
- Font picker rebuilt as SimpleSkillWatch's own scrolling list, with each font shown in its own face.
- `/sskw font <name>` and `/sskw fontinfo`.

## 0.5.0
- Renamed to **SimpleSkillWatch**, with `/sskw` as the command. Settings reset once because of the rename.
- Revert arrow on every slider.
- Font picker (game fonts plus LibSharedMedia fonts) and font size; layout and minimum width follow the font.
- **Show title** option; with the title hidden, the lock icon moves to the first section header.

## 0.4.0
- **Width** slider, with a minimum measured from the actual font so `TRAIN 300/300(+15)` always fits. Long names are cut with "…".

## 0.3.0
- Settings window with sliders and checkboxes, plus an entry in Options → AddOns.
- Lock icon in the title bar: click to lock the frame and make it click-through.
- Skill modifiers shown as a green `(+N)` after the value.
- Professions turn gold at the profession skill cap.

## 0.2.0
- Background and bar opacity settings.

## 0.1.0
- First version (as SkillWatch): movable frame with weapon/defense, profession and other skill bars; threshold colors; slash commands; handling for values the game hides in combat.
