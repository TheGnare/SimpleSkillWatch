-- Lock: per character, new characters start unlocked, padlock always clickable.
local function scenario(db, charDB)
    local M = dofile(TESTS_DIR .. "/wowmock.lua")
    M.savedVars(db, charDB)
    local ns = M.load(ADDON_DIR)
    M.login()
    return M, ns
end

local UNLOCKED_TEX = "Interface\\Buttons\\LockButton-Unlocked-Up"
local LOCKED_TEX = "Interface\\Buttons\\LockButton-Locked-Up"

local function check(M, ns, locked, what)
    local lock, frame = M.lockButton(), M.mainFrame()
    M.eq(ns.IsLocked(), locked, what .. ": locked")
    M.eq(frame.mouse, not locked, what .. ": frame takes mouse")
    M.eq(lock.shown, true, what .. ": padlock shown")
    M.eq(lock.tex.texPath, locked and LOCKED_TEX or UNLOCKED_TEX, what .. ": padlock texture")
    M.eq(SimpleSkillWatchCharDB.locked, locked, what .. ": saved per character")
end

-- New character, even when the Default profile it copies was saved locked by 0.13.x.
local M, ns = scenario({ profiles = { Default = { locked = true } } }, nil)
check(M, ns, false, "new character")

-- Padlock click toggles both ways; dimmed only while locked and not hovered.
local lock = M.lockButton()
lock.scripts.OnClick(lock); check(M, ns, true, "after click")
M.eq(lock.alphaV, 1, "still bright under the cursor")
lock.scripts.OnLeave(lock); M.eq(lock.alphaV, 0.5, "dimmed after the cursor leaves")
lock.scripts.OnEnter(lock); M.eq(lock.alphaV, 1, "bright on hover")
lock.scripts.OnLeave(lock)
lock.scripts.OnClick(lock); check(M, ns, false, "after second click")
lock.scripts.OnLeave(lock); M.eq(lock.alphaV, 1, "not dimmed while unlocked")

-- Slash commands do the same.
M.slash("lock"); check(M, ns, true, "/sskw lock")
M.slash("unlock"); check(M, ns, false, "/sskw unlock")

-- Upgrade from 0.13.x: a character that placed its frame keeps its lock.
M, ns = scenario({ profiles = { Warrior = { locked = true } } },
    { profile = "Warrior", pos = { anchor = "TOPLEFT", x = 10, y = 500 }, known = {} })
check(M, ns, true, "upgraded, placed and locked")

-- Upgrade from 0.13.x: never placed its frame, so it starts unlocked.
M, ns = scenario({ profiles = { Warrior = { locked = true } } }, { profile = "Warrior", known = {} })
check(M, ns, false, "upgraded, never placed")
