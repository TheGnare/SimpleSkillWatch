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
