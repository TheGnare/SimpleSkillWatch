-- "Only show equipped weapon" and "Still show Unarmed".
local M = dofile(TESTS_DIR .. "/wowmock.lua")
local ns = M.load(ADDON_DIR)
M.login()

M.addSkill(176, "Thrown", 38, 40)
M.addSkill(44, "Axes", 1, 40)
M.addSkill(162, "Unarmed", 1, 40)
M.addSkill(173, "Daggers", 1, 40)
EQUIP = { [16] = 1002, [18] = 1003 }   -- dagger main hand, thrown ranged
DURA[18] = { 200, 200 }
M.refresh()

local WEAPONS = { Axes = 1, Unarmed = 1, Daggers = 1, Thrown = 1, Swords = 1, Maces = 1, Defense = 1 }
local function weapons() return M.barNames(WEAPONS) end

M.eq(weapons(), "Axes,Daggers,Defense,Maces,Swords,Thrown,Unarmed", "all weapon skills by default")

M.slash("equipped")
M.eq(weapons(), "Daggers,Defense,Thrown", "only equipped")

EQUIP[16] = 1001; M.event("PLAYER_EQUIPMENT_CHANGED", 16); M.runTimers()
M.eq(weapons(), "Axes,Defense,Thrown", "after swapping to an axe")

EQUIP[16] = nil; M.event("PLAYER_EQUIPMENT_CHANGED", 16); M.runTimers()
M.eq(weapons(), "Defense,Thrown,Unarmed", "empty main hand counts as Unarmed")
M.eq(M.bars().Unarmed.warn, true, "red Unarmed with empty main hand warns")

EQUIP[16] = 1002; M.event("PLAYER_EQUIPMENT_CHANGED", 16); M.runTimers()
M.slash("unarmed")
M.eq(weapons(), "Daggers,Defense,Thrown,Unarmed", "still show Unarmed")

M.slash("equipped")
M.eq(weapons(), "Axes,Daggers,Defense,Maces,Swords,Thrown,Unarmed", "turned off again")

-- "Only show ranged": of the equipped weapons, only the ranged one (plus Defense).
M.slash("unarmed")                                  -- "Still show Unarmed" off again
local rangedBox
M.slash("")                                         -- settings window
rangedBox = M.findByText("CheckButton", "Only show ranged")
assert(rangedBox, "checkbox on the Skills tab")
M.eq(rangedBox.enabledV, false, "greyed out while Only show equipped weapon is off")
M.slash("ranged")
M.eq(ns.cfg.onlyRanged, true, "/sskw ranged turns it on")
M.eq(weapons(), "Axes,Daggers,Defense,Maces,Swords,Thrown,Unarmed", "does nothing without Only show equipped weapon")
M.slash("equipped")
M.eq(rangedBox.enabledV, true, "usable once Only show equipped weapon is on")
M.eq(weapons(), "Defense,Thrown", "only the ranged weapon, plus Defense")

EQUIP[16] = nil; M.event("PLAYER_EQUIPMENT_CHANGED", 16); M.runTimers()
M.eq(weapons(), "Defense,Thrown", "empty main hand doesn't bring Unarmed in")
M.slash("unarmed")
M.eq(weapons(), "Defense,Thrown,Unarmed", "unless Still show Unarmed is on")
M.slash("unarmed")

EQUIP[18] = nil; DURA[18] = nil; M.event("PLAYER_EQUIPMENT_CHANGED", 18); M.runTimers()
M.eq(weapons(), "Defense", "no ranged weapon: just Defense")

EQUIP[18] = 1003; DURA[18] = { 200, 200 }; M.event("PLAYER_EQUIPMENT_CHANGED", 18); M.runTimers()
rangedBox.checked = false; rangedBox.scripts.OnClick(rangedBox)
M.eq(ns.cfg.onlyRanged, false, "checkbox turns it off")
M.eq(weapons(), "Defense,Thrown,Unarmed", "back to every equipped weapon")
