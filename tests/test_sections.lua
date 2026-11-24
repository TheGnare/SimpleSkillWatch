-- Whole groups (Weapons, Professions, Other) hidden with their heading's
-- checkbox on the Skills tab, and side by side shrinking to one column when
-- one side has nothing to show.
local M = dofile(TESTS_DIR .. "/wowmock.lua")
-- an older profile, saved before groups could be hidden
M.savedVars({ profiles = { Warrior = { bgAlpha = 50 } }, panelTab = "Skills" },
    { profile = "Warrior", known = {} })
-- Riding: filed under Secondary Skills, shown under "Other"
M.addSkill(762, "Riding", 75, 75)
M.skill(762).skillLineCategoryID = 9
local ns = M.load(ADDON_DIR)
M.login()

local p = SimpleSkillWatchDB.profiles.Warrior
assert(type(p.hiddenSections) == "table" and next(p.hiddenSections) == nil,
    "older profile gets an empty hidden-groups list")

local WEAPONS = { Swords = true, Maces = true, Defense = true }
local function has(name) return M.bars()[name] ~= nil end
local function width() return M.mainFrame().width end
assert(has("Swords") and has("Defense") and has("Riding") and has("Cooking"), "everything shown at first")
local oneCol = width()

-- Side by side: two columns while both sides have something.
M.slash("layout side")
local twoCol = width()
assert(twoCol > oneCol, "side by side is wider")

-- Settings window, Skills tab: the headings are checkboxes, checked.
M.slash("")
local weaponsBox = M.findByText("CheckButton", "Weapons")
local profBox = M.findByText("CheckButton", "Professions")
local otherBox = M.findByText("CheckButton", "Other")
assert(weaponsBox and profBox and otherBox, "a checkbox on each heading")
M.eq(weaponsBox.checked, true, "Weapons heading checked")
local swordsBox = M.findByText("CheckButton", "Swords")
M.eq(swordsBox.enabledV, true, "skill checkbox usable")

-- Uncheck Weapons: the whole group goes, the frame becomes one column wide.
weaponsBox.checked = false; weaponsBox.scripts.OnClick(weaponsBox)
M.eq(p.hiddenSections.weapon, true, "saved in the profile")
M.eq(M.barNames(WEAPONS), "", "no weapon bars")
assert(has("Cooking") and has("Riding"), "professions and other still shown")
M.eq(width(), oneCol, "side by side with no weapons: one column wide")
M.eq(swordsBox.enabledV, false, "skill checkboxes greyed out under a hidden group")
M.eq(swordsBox.checked, true, "...but they keep their state")
M.eq(p.ignored[43], nil, "the skill itself isn't marked hidden")
-- flipped too
M.slash("layout flipped")
M.eq(width(), oneCol, "flipped with no weapons: one column wide")

-- A weapon skill learned later stays hidden.
M.addSkill(173, "Daggers", 1, 60)
M.refresh()
M.eq(has("Daggers"), false, "new weapon skill hidden with its group")

-- "Only show equipped weapon" doesn't bring weapons (or Defense) back.
M.slash("equipped")
M.eq(M.barNames(WEAPONS), "", "equipped filter doesn't override a hidden group")
M.slash("equipped")

-- Check it again: weapons and the earlier choices come back, two columns again.
weaponsBox = M.findByText("CheckButton", "Weapons")
weaponsBox.checked = true; weaponsBox.scripts.OnClick(weaponsBox)
M.eq(p.hiddenSections.weapon, nil, "shown again")
M.eq(M.barNames(WEAPONS), "Defense,Maces,Swords", "weapon bars back")
M.eq(width(), twoCol, "two columns again")

-- Hide Professions and Other: weapons only, one column.
profBox = M.findByText("CheckButton", "Professions")
profBox.checked = false; profBox.scripts.OnClick(profBox)
otherBox = M.findByText("CheckButton", "Other")
otherBox.checked = false; otherBox.scripts.OnClick(otherBox)
M.eq(has("Cooking") or has("Riding"), false, "professions and other hidden")
M.eq(width(), oneCol, "weapons only: one column wide")

-- A hidden Professions group gives no alerts, and showing it again doesn't alert late.
M.sounds = {}
M.skillUp(393)                       -- Skinning at TRAIN
M.eq(#M.sounds, 0, "no alert for a profession in a hidden group")
M.gather(8613)
M.eq(#M.sounds, 0, "no reminder after a gather either")
profBox = M.findByText("CheckButton", "Professions")
profBox.checked = true; profBox.scripts.OnClick(profBox)
M.refresh()
M.eq(#M.sounds, 0, "showing the group again doesn't alert late")

-- Everything hidden: the frame says so instead of "no skills found".
weaponsBox = M.findByText("CheckButton", "Weapons")
weaponsBox.checked = false; weaponsBox.scripts.OnClick(weaponsBox)
profBox = M.findByText("CheckButton", "Professions")
profBox.checked = false; profBox.scripts.OnClick(profBox)
M.eq(M.barNames(), "", "nothing shown")
assert(M.findByText("CreateFontString", "Every skill is hidden. Show some on the Skills tab (/sskw)."),
    "frame explains that everything is hidden")

-- With the title hidden, the padlock is in that corner: the text starts below it.
local function textTop()
    for _, f in ipairs(M.frames) do
        if f.kind == "CreateFontString" and f.text and f.text:find("^Every skill is hidden") then
            return f.points.TOPLEFT[3]
        end
    end
end
M.slash("title")
M.eq(ns.cfg.showTitle, false, "title hidden")
local lockTop = M.lockButton().points.TOPRIGHT[3]
local LOCK_SIZE = 14                -- at the default font size
assert(textTop() <= lockTop - LOCK_SIZE, "text starts below the padlock")
M.slash("title")

-- Defaults keeps hidden groups, like hidden skills.
ns.ResetDefaults()
M.eq(p.hiddenSections.weapon, true, "Defaults keeps hidden groups")

-- Stacked was never affected: no empty space, just the sections that show.
M.slash("layout stacked")
M.eq(width(), oneCol, "stacked: one column")
