-- Minimal mock of the WoW: Forever API, enough to load SimpleSkillWatch and
-- drive it with events. Not a full UI emulator: widgets record what the addon
-- set on them (text, color, shown, mouse, alpha, texture, points) so tests can
-- assert on it. Unknown widget methods are accepted and do nothing.
--
-- Usage (from a test file run by tests/run_tests.py):
--   local M = dofile(TESTS_DIR .. "/wowmock.lua")
--   M.savedVars(db, charDB)   -- optional: SavedVariables before loading
--   local ns = M.load(ADDON_DIR)
--   M.login()
--   ... M.event("SKILL_LINES_CHANGED") ... M.bars() ...

local M = {}

---------------------------------------------------------------- game state
-- Tests change these between events.
DURA = {}         -- inventory slot -> { cur, max }
EQUIP = {}        -- inventory slot -> itemID
DISARMED = {}     -- inventory slot -> true (GetInventoryItemEquippedUnusable)
FULLCONTROL = true
LOC = nil         -- active loss-of-control entry for "player", or nil
PLAYER_CLASS = "Warrior"

-- itemID -> { classID, subclassID }: axe, dagger, thrown, shield
ITEMS = { [1001] = { 2, 0 }, [1002] = { 2, 15 }, [1003] = { 2, 16 }, [1004] = { 4, 6 } }

-- A secret value, as Forever returns for hidden fields in combat.
M.SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
function issecretvalue(v) return v == M.SECRET end

function GetInventoryItemDurability(slot) local d = DURA[slot]; if d then return d[1], d[2] end end
function GetInventoryItemID(_, slot) return EQUIP[slot] end
function GetInventoryItemEquippedUnusable(_, slot) return DISARMED[slot] end
function UnitAttackSpeed() return 1.7, 1.4 end
function UnitDamage() return 10, 15, 5, 8 end
function HasFullControl() return FULLCONTROL end
function UnitAffectingCombat() return true end
function UnitClass() return PLAYER_CLASS, string.upper(PLAYER_CLASS) end
function UnitLevel() return 12 end
function UnitDefenseSkill() return 37, 0 end

C_LossOfControl = {
    GetActiveLossOfControlDataCountByUnit = function(u) return (u == "player" and LOC) and 1 or 0 end,
    GetActiveLossOfControlDataByUnit = function() return LOC end,
}
C_Item = {
    GetItemInfoInstant = function(id)
        local i = ITEMS[id]
        return id, nil, nil, nil, nil, i[1], i[2]
    end,
}

---------------------------------------------------------------- skills
-- Skill lines as C_SkillInfo returns them. Tests may edit ranks or add lines
-- with M.addSkill, then fire SKILL_LINES_CHANGED.
LINES = {
    { skillID = 6, name = "Weapon Skills", isHeader = true },
    { skillID = 43, name = "Swords", rank = 10, maxRank = 40, modifier = 5, skillLineCategoryID = 6, parentSkillLineID = 0 },
    { skillID = 54, name = "Maces", rank = 33, maxRank = 40, modifier = -2, skillLineCategoryID = 6, parentSkillLineID = 0 },
    { skillID = 95, name = "Defense", rank = 37, maxRank = 40, modifier = 0, skillLineCategoryID = 6, parentSkillLineID = 0 },
    { skillID = 11, name = "Professions", isHeader = true },
    { skillID = 393, name = "Skinning", rank = 68, maxRank = 75, skillLineCategoryID = 11, parentSkillLineID = 0 },
    { skillID = 165, name = "Leatherworking", rank = 21, maxRank = 75, skillLineCategoryID = 11, parentSkillLineID = 0 },
    { skillID = 197, name = "Tailoring", rank = 205, maxRank = 225, skillLineCategoryID = 11, parentSkillLineID = 0 },
    { skillID = 9, name = "Secondary Skills", isHeader = true },
    { skillID = 185, name = "Cooking", rank = 130, maxRank = 150, skillLineCategoryID = 9, parentSkillLineID = 0 },
    { skillID = 129, name = "First Aid", rank = 210, maxRank = 225, skillLineCategoryID = 9, parentSkillLineID = 0 },
    { skillID = 356, name = "Fishing", rank = 300, maxRank = 300, skillLineCategoryID = 9, parentSkillLineID = 0 },
}
local byID = {}
local function index()
    for k in pairs(byID) do byID[k] = nil end
    for _, l in ipairs(LINES) do if not l.isHeader then byID[l.skillID] = l end end
end
index()
C_SkillInfo = {
    GetNumSkillLines = function() return #LINES end,
    GetSkillLineInfo = function(i) return LINES[i] end,
    GetSkillLineInfoByID = function(id) return byID[id] end,
}

-- Add a weapon skill right after the "Weapon Skills" header.
function M.addSkill(id, name, rank, maxRank)
    table.insert(LINES, 2, { skillID = id, name = name, rank = rank, maxRank = maxRank,
        skillLineCategoryID = 6, parentSkillLineID = 0 })
    index()
end

function M.skill(id) return byID[id] end

---------------------------------------------------------------- widgets
local frames = {}
M.frames = frames

local function newObj(kind)
    local o = { kind = kind, shown = true, scripts = {}, events = {}, mouse = true }
    setmetatable(o, { __index = function(_, k)
        return function(self, ...)
            local a = { ... }
            if k == "SetText" then self.text = a[1]
            elseif k == "GetText" then return self.text
            elseif k == "SetStatusBarColor" then self.color = { a[1], a[2], a[3] }; self.alpha = a[4]
            elseif k == "SetBackdropColor" then self.bgAlpha = a[4]
            elseif k == "SetValue" then
                self.value = a[1]
                if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, a[1]) end
            elseif k == "GetValue" then return self.value or 0
            elseif k == "SetChecked" then self.checked = a[1]
            elseif k == "GetChecked" then return self.checked
            elseif k == "Show" then self.shown = true
            elseif k == "Hide" then self.shown = false
            elseif k == "SetShown" then self.shown = a[1] and true or false
            elseif k == "IsShown" then return self.shown
            elseif k == "EnableMouse" then self.mouse = a[1]
            elseif k == "SetScale" then self.scale = a[1]
            elseif k == "SetAlpha" then self.alphaV = a[1]
            elseif k == "SetEnabled" then self.enabledV = a[1]
            elseif k == "SetTexture" then self.texPath = a[1]; return true
            elseif k == "SetScript" then self.scripts[a[1]] = a[2]
            elseif k == "RegisterEvent" then self.events[a[1]] = true
            elseif k == "RegisterUnitEvent" then self.events[a[1]] = "unit:" .. tostring(a[2])
            elseif k == "UnregisterEvent" then self.events[a[1]] = nil
            elseif k == "CreateFontString" or k == "CreateTexture" then return newObj(k)
            elseif k == "CreateAnimationGroup" then
                local g = newObj("AnimGroup"); g.playing = false
                g.Play = function(s) s.playing = true end
                g.Stop = function(s) s.playing = false end
                g.IsPlaying = function(s) return s.playing end
                g.CreateAnimation = function() return newObj("Anim") end
                return g
            elseif k == "GetFrameLevel" then return 1
            elseif k == "GetPoint" then return "TOPLEFT", nil, "BOTTOMLEFT", 100, 200
            elseif k == "SetPoint" then self.lastPoint = a
            elseif k == "ClearAllPoints" then self.lastPoint = nil
            elseif k == "SetFont" then self.font = a[1]; self.fontSize = a[2]
            elseif k == "GetFont" then return "Fonts\\FRIZQT__.TTF", 10, ""
            elseif k == "SetWidth" then self.width = a[1]
            elseif k == "GetWidth" then return rawget(self, "width") or 200
            elseif k == "SetHeight" then self.height = a[1]
            elseif k == "GetStringWidth" then
                local t = (self.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                return #t * 0.6 * (self.fontSize or 10)
            end
        end
    end })
    return o
end

function CreateFrame(kind, name)
    local f = newObj(kind); frames[#frames + 1] = f
    if name then _G[name] = f; f.name = name end
    return f
end

UIParent = newObj("Frame")
GameTooltip = newObj("GameTooltip")
GameFontHighlightSmall = newObj("Font")
GameFontHighlight = newObj("Font")
UISpecialFrames = {}
SlashCmdList = {}
C_EventUtils = { IsEventValid = function() return true end }

function wipe(t) for k in pairs(t) do t[k] = nil end return t end

M.chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) M.chat[#M.chat + 1] = m end }

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
-- Run every pending C_Timer callback (one generation).
function M.runTimers()
    local t = timers; timers = {}
    for _, fn in ipairs(t) do fn() end
end

M.optionsCategory = nil
Settings = {
    RegisterCanvasLayoutCategory = function(f, n) return { frame = f, name = n } end,
    RegisterAddOnCategory = function(c) M.optionsCategory = c end,
}

---------------------------------------------------------------- driving the addon
local eventFrame

function M.savedVars(db, charDB)
    SimpleSkillWatchDB = db
    SimpleSkillWatchCharDB = charDB
end

function M.load(addonDir)
    local ns = {}
    for _, file in ipairs({ "SimpleSkillWatch.lua", "Settings.lua" }) do
        assert(loadfile(addonDir .. "/" .. file))("SimpleSkillWatch", ns)
    end
    for _, f in ipairs(frames) do if f.events.ADDON_LOADED then eventFrame = f end end
    assert(eventFrame, "no frame registered ADDON_LOADED")
    M.event("ADDON_LOADED", "SimpleSkillWatch")
    M.ns = ns
    return ns
end

function M.event(name, ...)
    eventFrame.scripts.OnEvent(eventFrame, name, ...)
end

function M.login()
    M.event("PLAYER_LOGIN")
    M.runTimers()
end

function M.refresh()
    M.event("SKILL_LINES_CHANGED")
    M.runTimers()
end

function M.slash(msg)
    SlashCmdList.SIMPLESKILLWATCH(msg)
    M.runTimers()
end

---------------------------------------------------------------- inspection
local COLOR_NAMES = {
    ["0.8,0.15,0.15"] = "red", ["0.9,0.75,0.1"] = "yellow", ["0.2,0.7,0.2"] = "green",
    ["0.2,0.45,0.9"] = "blue", ["1,0.7,0"] = "gold", ["0.4,0.4,0.4"] = "gray",
}

-- Visible skill bars: name -> { value = "10/40(+5)", color = "red", warn = bool, frame = f }
function M.bars()
    local out = {}
    for _, f in ipairs(frames) do
        if f.kind == "StatusBar" and f.shown and rawget(f, "labelText") then
            local warn = rawget(f, "warn")
            out[f.labelText.text] = {
                value = f.valueText.text,
                color = COLOR_NAMES[table.concat(f.color or {}, ",")] or table.concat(f.color or {}, ","),
                warn = warn and warn.shown or false,
                frame = f,
            }
        end
    end
    return out
end

-- Sorted list of visible bar names, optionally limited to a set of names.
function M.barNames(only)
    local t = {}
    for name in pairs(M.bars()) do
        if not only or only[name] then t[#t + 1] = name end
    end
    table.sort(t)
    return table.concat(t, ",")
end

function M.mainFrame() return SimpleSkillWatchFrame end

-- The padlock button (the only Button that tracks a dimmed state).
function M.lockButton()
    for _, f in ipairs(frames) do
        if f.kind == "Button" and rawget(f, "dimmed") ~= nil then return f end
    end
end

---------------------------------------------------------------- asserts
function M.eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
    end
end

return M
