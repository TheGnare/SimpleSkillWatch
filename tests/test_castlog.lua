-- /sskw castlog: logs crafting and gathering events while on, nothing while off.
local M = dofile(TESTS_DIR .. "/wowmock.lua")
local ns = M.load(ADDON_DIR)
M.login()

local function watcher()
    for _, f in ipairs(M.frames) do
        if f.events.UNIT_SPELLCAST_SUCCEEDED then return f end
    end
end
local function log() return table.concat(SimpleSkillWatchDB.castlog or {}, "\n") end
local function has(text) return log():find(text, 1, true) ~= nil end

M.eq(watcher(), nil, "nothing watched before the log is turned on")

-- What the client offers: one event missing, some old-style profession functions.
local realValid = C_EventUtils.IsEventValid
C_EventUtils.IsEventValid = function(ev) return ev ~= "CRAFT_SHOW" end
function GetTradeSkillLine() return "First Aid", 150, 150 end
function GetNumTradeSkills() return 2 end
function GetTradeSkillSelectionIndex() return 2 end
function GetTradeSkillInfo(i)
    if i == 1 then return "Heavy Linen Bandage", "easy", 3 end
    return "Linen Bandage", "trivial", 7
end
function GetSpellInfo(id) return id == 3275 and "Linen Bandage" or nil end
C_TradeSkillUI = {
    GetTradeSkillLineForRecipe = function() return 129, "First Aid" end,
    CraftRecipe = function() error("the log must never call this") end,
}

M.slash("castlog")
local w = watcher()
assert(w, "cast events watched while on")
M.eq(w.events.UNIT_SPELLCAST_SUCCEEDED, "unit:player", "cast events are player-only")
M.eq(w.events.CRAFT_SHOW, nil, "an event the client lacks isn't registered")
assert(has("events it doesn't have: CRAFT_SHOW"), "missing events are listed")
assert(has("C_TradeSkillUI: CraftRecipe, GetTradeSkillLineForRecipe"), "namespace functions listed by name")
assert(has("GetTradeSkillLine"), "global profession functions listed")
assert(has("skills: "), "profession ranks logged at the start")
assert(has('First Aid[129] 210/225'), "rank and cap per profession")

local fire = w.scripts.OnEvent

-- Other units' casts are ignored.
fire(w, "UNIT_SPELLCAST_SUCCEEDED", "target", "guid", 999)
assert(not has("999"), "another unit's cast isn't logged")

-- Opening the window logs the profession and its recipes with their difficulty.
fire(w, "TRADE_SKILL_SHOW")
assert(has('GetTradeSkillLine() -> "First Aid", 150, 150'), "window's profession logged")
assert(has('GetTradeSkillInfo(1) -> "Heavy Linen Bandage", "easy", 3'), "recipe difficulty logged")

-- A craft: the event with its arguments, the spell's name and profession,
-- the selected recipe's difficulty, and the ranks.
fire(w, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1", 3275)
assert(has('UNIT_SPELLCAST_SUCCEEDED("player", "Cast-3-1", 3275)'), "event and arguments logged")
assert(has('C_TradeSkillUI.GetTradeSkillLineForRecipe(3275) -> 129, "First Aid"'), "spell tied to its profession")
assert(has('GetSpellInfo(3275) -> "Linen Bandage"'), "spell name logged")
assert(has('GetTradeSkillInfo(2) -> "Linen Bandage", "trivial", 7'), "selected recipe logged")
M.runTimers()

-- Secret arguments are named, never read; links come out as plain text.
fire(w, "UNIT_SPELLCAST_START", M.SECRET, "Cast-3-2", M.SECRET)
assert(has('UNIT_SPELLCAST_START(<secret>, "Cast-3-2", <secret>)'), "secret arguments shown as <secret>")
fire(w, "CHAT_MSG_LOOT", "You create: |cffffffff|Hitem:1251|h[Linen Bandage]|h|r.")
assert(has("||Hitem:1251||h[Linen Bandage]"), "links are written as text")

-- A burst of the same event is counted, not repeated.
for _ = 1, 4 do fire(w, "TRADE_SKILL_UPDATE") end
fire(w, "LOOT_CLOSED")
assert(has("(same line 3 more times)"), "repeats are counted")

-- Off: nothing watched, the lines are kept.
local kept = #SimpleSkillWatchDB.castlog
M.slash("castlog")
M.eq(watcher(), nil, "nothing watched after turning it off")
M.eq(#SimpleSkillWatchDB.castlog, kept, "lines kept after turning it off")
assert(M.chatCount("lines kept") == 1, "says how many lines were kept")

-- The copy window holds the whole log.
M.slash("castlog copy")
local win = SimpleSkillWatchCastLog
assert(win and win.shown, "copy window opens")
M.eq(win.edit.text, log(), "copy window holds the log")

-- Clear empties it; turning it on again starts a fresh log.
M.slash("castlog clear")
M.eq(#SimpleSkillWatchDB.castlog, 0, "clear empties the log")
M.slash("castlog")
assert(#SimpleSkillWatchDB.castlog > 0 and not has("3275"), "a new log starts empty of old lines")
C_EventUtils.IsEventValid = realValid
