-- Disarm detection from loss-of-control data, with Forever's hidden fields.
local M = dofile(TESTS_DIR .. "/wowmock.lua")
local ns = M.load(ADDON_DIR)
M.login()

M.addSkill(162, "Unarmed", 1, 40)   -- red: the warning target while disarmed
M.addSkill(173, "Daggers", 40, 40)  -- equipped and fine, so it never warns
EQUIP = { [16] = 1002 }             -- dagger in the main hand
M.refresh()

local S = M.SECRET
local function hidden(priority)
    return { locType = S, displayText = S, spellID = S, duration = S, lockoutSchool = S,
             priority = priority, displayType = 2 }
end
local function unarmedWarned(entry, control)
    FULLCONTROL = control
    LOC = entry
    M.event("LOSS_OF_CONTROL_ADDED", "player", 1)
    local warned = M.bars().Unarmed.warn
    LOC = nil; FULLCONTROL = true
    M.runTimers()
    return warned
end

-- Priorities seen on Forever: 1 root, 2 interrupt, 3 disarm.
M.eq(unarmedWarned(hidden(3), true), true, "hidden priority 3 = disarm")
M.eq(unarmedWarned(hidden(1), true), false, "root (priority 1)")
M.eq(unarmedWarned(hidden(2), true), false, "interrupt (priority 2)")
M.eq(unarmedWarned(hidden(3), false), false, "priority 3 without control (stun-like)")
M.eq(unarmedWarned({ locType = "ROOT", priority = 3, displayType = 2 }, true), false, "readable ROOT")
M.eq(unarmedWarned({ locType = "DISARM", priority = 7, displayType = 2 }, true), true, "readable DISARM")
