# SimpleSkillWatch

A World of Warcraft: Forever addon (interface 16001) by Gnare: a movable frame of
weapon/Defense, profession and other skill bars, colored by thresholds the player sets.
The README describes every feature as the player sees it; read it first.

## Layout

- `SimpleSkillWatch.toc`: addon manifest (version, SavedVariables)
- `SimpleSkillWatch.lua`: everything except the settings window: defaults, profiles,
  skill scan, coloring, disarm detection, the frame, events, slash commands
- `Settings.lua`: the settings window (tabs Frame / Text / Skills / Alerts / Profile)
  and the Options → AddOns entry. Shares the addon namespace `ns` with the main file.
- `tests/`: a mock of the WoW API (`wowmock.lua`) and `test_*.lua` files
- `.pkgmeta`, `.github/workflows/`: packaging and release (see Releasing)

## Testing

There is no WoW client here. Behavior is checked against a mock API in Lua 5.1:

    pip install lupa
    python tests/run_tests.py           # all
    python tests/run_tests.py lock      # files whose name contains "lock"

Run the tests after every change and add a test for each new behavior or fix.
The mock is deliberately small: widgets record what the addon set on them, and unknown
methods are no-ops that return nil. Two traps from that:
- Any missing *field* on a mock widget reads as a function (truthy). Initialize every
  custom field the addon puts on a frame (e.g. `button.dimmed = false`) instead of
  relying on nil.
- Passing tests don't prove it works in game. Say what still needs an in-game check.

Gnare tests in game and reports back, often with screenshots. In-game diagnostics:
`/sskw events`, `/sskw disarmlog`, `/sskw debug`, `/sskw fontinfo`.

## WoW: Forever API notes (learned the hard way)

- Skills come from `C_SkillInfo` (`GetNumSkillLines`, `GetSkillLineInfo`,
  `GetSkillLineInfoByID`). Lines under a collapsed header aren't returned.
- Many values are "secret" in combat (`issecretvalue(v)`): skill ranks, durability,
  aura and loss-of-control details, `UnitAttackSpeed`, `UnitDamage`. Never compare or do
  arithmetic on a secret value; keep showing the last readable value.
- No combat log for addons.
- Loss of control: only `priority` and `displayType` are always readable. Observed
  priorities (all with `HasFullControl()` true): 1 root (Frost Nova), 2 interrupt /
  school lockout, 3 disarm. Stuns, fears and charms remove control. `displayType`
  follows the player's interface options, not the effect.
  `GetInventoryItemEquippedUnusable` stays false while disarmed.
- Rescans are triggered by `SKILL_LINES_CHANGED`, `CHAT_MSG_SKILL`, `SPELLS_CHANGED`
  (all confirmed to fire); bursts are coalesced into one redraw (0.25 s).
- Register events through `SafeRegister` (checks `C_EventUtils.IsEventValid`).
- Fonts from other addons may not be loaded at login: `SetFont` can fail or draw blank,
  and re-applying the same face is ignored, so the code switches to the default face and
  back, with timed redraws.
- Forever trainers have no level requirement for profession ranks; TRAIN depends on
  skill only (Journeyman 50, Expert 125, Artisan 200; secondary Artisan 225).
- `/reload` loads a newly installed addon; no restart needed.

## Saved data

- `SimpleSkillWatchDB` (account): `profiles[name]` holds every setting plus `ignored`
  skills; also the settings window position and tab.
- `SimpleSkillWatchCharDB` (character): `profile`, `pos`, `locked`, `known` skills.
- New characters get a profile named after their class, copied from `Default` if it
  exists. Any change to the saved layout needs a migration on load for older data, and a
  test for it.

## Conventions

- Player-facing text (chat, tooltips, settings, README) is short and plain: say what
  happens, no jargon.
- Credit is "Gnare" (shown in `#4D5FFF` in the settings window).
- Every player-visible change gets a `CHANGELOG.md` line under `## Unreleased` at the
  top (create the heading if missing); don't bump the version for each change. Merge
  lines when later work changes or reverts something from the same unreleased batch, so
  the notes describe the end result, not the iterations. Update the README when a
  feature or command changes.
- Versions are major.minor.patch. A version lives in three places that must match:
  `## Version:` in the .toc, the header comment and `ns.VERSION` in
  `SimpleSkillWatch.lua`.

## Releasing

Pushing to `main` publishes nothing; only a version tag does.

1. Bump the version (three places above) and rename `## Unreleased` in `CHANGELOG.md`
   to `## X.Y.Z`.
2. Merge to `main`.
3. Tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`.
   Or, on github.com: Releases → Draft a new release → new tag `vX.Y.Z` on `main` →
   Publish. That tag starts the same workflow, which fills in the release's notes and zip.
   (Cloud sessions can push branches but not tags, so they use this route.)

The Release workflow runs the tests, checks that the tag, .toc, `ns.VERSION` and
changelog agree, then the BigWigs packager builds `SimpleSkillWatch-vX.Y.Z-forever.zip` and
uploads it to CurseForge (project ID from `## X-Curse-Project-ID` in the .toc, key from
the `CF_API_KEY` repository secret) and to GitHub Releases, with that version's changelog
section as release notes. The packager detects Forever from `## Interface: 16001`.
Tags containing `alpha` or `beta` publish as alpha/beta files.
