-- Profiles: class-named profile for new characters, copied from Default.
local M = dofile(TESTS_DIR .. "/wowmock.lua")
M.savedVars({ profiles = { Default = { bgAlpha = 50, ignored = { [54] = true } } } }, nil)
PLAYER_CLASS = "Hunter"
local ns = M.load(ADDON_DIR)
M.login()

M.eq(SimpleSkillWatchCharDB.profile, "Hunter", "new character's profile")
local p = SimpleSkillWatchDB.profiles.Hunter
assert(p, "Hunter profile created")
M.eq(p.bgAlpha, 50, "copied from Default")
M.eq(p.barAlpha, 70, "missing settings filled from defaults")
M.eq(M.bars().Maces, nil, "skill hidden in Default stays hidden")

-- Changing a setting affects only the active profile.
M.slash("bg 20")
M.eq(p.bgAlpha, 20, "Hunter changed")
M.eq(SimpleSkillWatchDB.profiles.Default.bgAlpha, 50, "Default untouched")

-- Upgrade from 0.10.x: top-level settings become the Default profile.
M = dofile(TESTS_DIR .. "/wowmock.lua")
M.savedVars({ bgAlpha = 40, panelTab = 2 }, nil)
M.load(ADDON_DIR); M.login()
M.eq(SimpleSkillWatchDB.profiles.Default.bgAlpha, 40, "legacy settings migrated")
M.eq(SimpleSkillWatchDB.panelTab, 2, "window state stays top-level")
