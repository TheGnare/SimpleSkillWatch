-- SimpleSkillWatch cast log (/sskw castlog): a diagnostic that records what
-- the game reports while you craft or gather, to find out what an addon can
-- see around profession skill-ups: which events fire and with what, how a cast
-- maps to a profession, and whether a recipe's difficulty can be read.
--
-- Costs nothing while off (its events are only registered while it's on).
-- Lines go to chat (short ones) and to SimpleSkillWatchDB.castlog, so they
-- survive /reload; "/sskw castlog copy" opens them in a window to copy from.
--
-- Only functions known to just read data are ever called here. Everything
-- else in the profession namespaces is listed by name, never called.

local ADDON, ns = ...

local MAX_LINES = 900
local LIST_LIMIT = 60        -- recipes written per recipe list
local on = false
local full = false
local startTime = 0
local watcher                -- event frame, created on first use
local registered = {}        -- event -> true while on
local seenSpell = {}         -- spell ID -> true once its details are logged
local lastLine, repeats = nil, 0
local lastSkills, lastTrade
local listPending = false    -- a profession window opened; its recipe list isn't logged yet
local copyWindow

local IsSecret, Describe = ns.IsSecret, ns.Describe

local function Now() return type(GetTime) == "function" and GetTime() or 0 end

local function Lines()
    ns.db.castlog = ns.db.castlog or {}
    return ns.db.castlog
end

local function Chat(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33bbffcastlog|r " .. text)
end

-- Store a line; quiet lines (long lists) stay out of chat.
local function Store(text, quiet)
    local lines = Lines()
    if #lines >= MAX_LINES then
        if not full then
            full = true
            lines[#lines + 1] = "(log full)"
            Chat("log full (" .. MAX_LINES .. " lines). Copy it with /sskw castlog copy.")
        end
        return
    end
    lines[#lines + 1] = string.format("%7.2f  %s", Now() - startTime, text)
    if not quiet then Chat(text) end
end

local function FlushRepeats()
    if repeats > 0 then
        Store("   (same line " .. repeats .. " more time" .. (repeats == 1 and "" or "s") .. ")")
    end
    repeats = 0
end

-- Identical lines in a row (some events fire in bursts) are counted, not repeated.
local function Add(text, quiet)
    if text == lastLine then
        repeats = repeats + 1
        return
    end
    FlushRepeats()
    lastLine = text
    Store(text, quiet)
end

-- Any value as text. Secret values are named, never read; "|" is doubled so
-- links and colors show as plain text.
local function Flat(v, depth)
    if IsSecret(v) then return "<secret>" end
    local t = type(v)
    if t == "string" then
        return '"' .. v:gsub("|", "||") .. '"'
    elseif t == "table" then
        depth = depth or 0
        if depth >= 2 then return "{...}" end
        local keys = {}
        for k in pairs(v) do
            if not IsSecret(k) then keys[#keys + 1] = k end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for i, k in ipairs(keys) do
            if i > 40 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. Flat(v[k], depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function FlatList(n, ...)
    local parts = {}
    for i = 1, math.min(n, 12) do
        parts[i] = Flat((select(i, ...)))
    end
    return table.concat(parts, ", ")
end

local function Packed(ok, ...)
    return ok, select("#", ...), ...
end

-- "label = results" for a read-only function, or nil if the client lacks it.
local function Call(label, fn, ...)
    if type(fn) ~= "function" then return nil end
    local function Result(ok, n, ...)
        if not ok then return label .. " -> error: " .. tostring((...)) end
        if n == 0 then return label .. " -> (nothing)" end
        return label .. " -> " .. FlatList(n, ...)
    end
    return Result(Packed(pcall(fn, ...)))
end

local function Field(tbl, name)
    return type(tbl) == "table" and tbl[name] or nil
end

---------------------------------------------------------------------------
-- What this client offers
---------------------------------------------------------------------------

local NAMESPACE_WORDS = { "skill", "trade", "craft", "profession", "recipe" }
local GLOBAL_WORDS = { "tradeskill", "craft", "profession" }

local function HasWord(name, words)
    local lower = name:lower()
    for _, w in ipairs(words) do
        if lower:find(w, 1, true) then return true end
    end
    return false
end

local function FunctionNames(tbl, words)
    local names = {}
    for k, v in pairs(tbl) do
        if type(k) == "string" and type(v) == "function" and (not words or HasWord(k, words)) then
            names[#names + 1] = k
        end
    end
    table.sort(names)
    return names
end

-- Written in chunks so no single line is enormous.
local function AddNames(title, names)
    if #names == 0 then
        Add(title .. ": (none)", true)
        return
    end
    for i = 1, math.min(#names, 240), 12 do
        local chunk = {}
        for j = i, math.min(i + 11, #names) do chunk[#chunk + 1] = names[j] end
        Add(title .. ": " .. table.concat(chunk, ", "), true)
    end
    if #names > 240 then Add(title .. ": ... and " .. (#names - 240) .. " more", true) end
end

local function Survey()
    if type(GetBuildInfo) == "function" then
        Add(Call("GetBuildInfo()", GetBuildInfo), true)
    end
    local spaces, globals = {}, {}
    for k, v in pairs(_G) do
        if type(k) == "string" then
            if type(v) == "table" and k:sub(1, 2) == "C_" and HasWord(k, NAMESPACE_WORDS) then
                spaces[#spaces + 1] = k
            elseif type(v) == "function" and HasWord(k, GLOBAL_WORDS) then
                globals[#globals + 1] = k
            end
        end
    end
    table.sort(spaces)
    table.sort(globals)
    for _, name in ipairs(spaces) do
        AddNames(name, FunctionNames(_G[name]))
    end
    if type(C_Spell) == "table" then
        AddNames("C_Spell (skill/trade/recipe)", FunctionNames(C_Spell, NAMESPACE_WORDS))
    end
    AddNames("global functions", globals)
    local have = {}
    for _, name in ipairs({ "GetSpellInfo", "UnitCastingInfo", "UnitChannelInfo", "CastingInfo",
        "ChannelInfo", "IsFishingLoot", "GetNumLootItems", "PlaySound", "PlaySoundFile" }) do
        have[#have + 1] = name .. "=" .. (type(_G[name]) == "function" and "yes" or "no")
    end
    Add("other functions: " .. table.concat(have, " "), true)
    Chat(#spaces .. " profession namespaces and " .. #globals .. " global functions listed in the log.")
end

---------------------------------------------------------------------------
-- Skills, spells, the profession window
---------------------------------------------------------------------------

-- "First Aid 150/150, Mining 73/75": what the skill API says right now.
local function SkillsLine()
    local parts = {}
    for _, s in ipairs(ns.GetKnownSkills()) do
        if s.kind == "prof" then
            local info = C_SkillInfo.GetSkillLineInfoByID(s.id)
            if type(info) == "table" then
                parts[#parts + 1] = string.format("%s[%d] %s/%s", s.name, s.id,
                    Describe(info.rank), Describe(info.maxRank))
            end
        end
    end
    return #parts > 0 and table.concat(parts, ", ") or "(no professions known)"
end

local function LogSkills(always)
    local line = "skills: " .. SkillsLine()
    if always or line ~= lastSkills then
        lastSkills = line
        Add(line)
    end
end

local function SpellName(id)
    local name
    if type(Field(C_Spell, "GetSpellName")) == "function" then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok then name = n end
    end
    if name == nil and type(GetSpellInfo) == "function" then
        local ok, n = pcall(GetSpellInfo, id)
        if ok then name = n end
    end
    return Flat(name)
end

-- First time a spell is seen: everything that might tie it to a profession
-- or tell how hard its recipe is.
local function LogSpellDetails(id)
    if seenSpell[id] then return end
    seenSpell[id] = true
    local found = 0
    local function Try(label, fn)
        local line = Call(label .. "(" .. id .. ")", fn, id)
        if line then
            found = found + 1
            Add("   " .. line, true)
        end
    end
    Try("C_TradeSkillUI.GetTradeSkillLineForRecipe", Field(C_TradeSkillUI, "GetTradeSkillLineForRecipe"))
    Try("C_TradeSkillUI.GetRecipeInfo", Field(C_TradeSkillUI, "GetRecipeInfo"))
    Try("C_Spell.GetSpellInfo", Field(C_Spell, "GetSpellInfo"))
    Try("C_Spell.GetSpellSkillLineAbilityRank", Field(C_Spell, "GetSpellSkillLineAbilityRank"))
    Try("C_Spell.GetSpellTradeSkillLink", Field(C_Spell, "GetSpellTradeSkillLink"))
    Try("GetSpellInfo", GetSpellInfo)
    Try("GetSpellTradeSkillLink", GetSpellTradeSkillLink)
    Try("IsPlayerSpell", IsPlayerSpell)
    Chat("   spell " .. id .. " = " .. SpellName(id) .. " (" .. found .. " lookups saved to the log)")
end

-- The profession window's own state: which profession, which recipe is
-- selected and how hard the game says it is. Old-style global functions and
-- the newer C_TradeSkillUI ones are both tried.
local function TradeLines()
    local out = {}
    local function Put(line) if line then out[#out + 1] = line end end

    Put(Call("GetTradeSkillLine()", GetTradeSkillLine))
    Put(Call("GetNumTradeSkills()", GetNumTradeSkills))
    if type(GetTradeSkillSelectionIndex) == "function" then
        local ok, index = pcall(GetTradeSkillSelectionIndex)
        Put("GetTradeSkillSelectionIndex() -> " .. (ok and Flat(index) or "error"))
        if ok and not IsSecret(index) and type(index) == "number" and index > 0 then
            Put(Call("GetTradeSkillInfo(" .. index .. ")", GetTradeSkillInfo, index))
            Put(Call("GetTradeSkillRecipeLink(" .. index .. ")", GetTradeSkillRecipeLink, index))
        end
    end
    Put(Call("GetCraftDisplaySkillLine()", GetCraftDisplaySkillLine))
    Put(Call("GetNumCrafts()", GetNumCrafts))
    if type(GetCraftSelectionIndex) == "function" then
        local ok, index = pcall(GetCraftSelectionIndex)
        Put("GetCraftSelectionIndex() -> " .. (ok and Flat(index) or "error"))
        if ok and not IsSecret(index) and type(index) == "number" and index > 0 then
            Put(Call("GetCraftInfo(" .. index .. ")", GetCraftInfo, index))
        end
    end
    for _, name in ipairs({ "IsTradeSkillReady", "GetTradeSkillLine", "GetBaseProfessionInfo",
        "GetChildProfessionInfo", "GetProfessionChildSkillLineID" }) do
        Put(Call("C_TradeSkillUI." .. name .. "()", Field(C_TradeSkillUI, name)))
    end
    return out
end

local function LogTrade()
    local lines = TradeLines()
    local key = table.concat(lines, "\n")
    if key == lastTrade then return end
    lastTrade = key
    if #lines == 0 then
        Add("profession window: no functions for it on this client")
        return
    end
    for _, line in ipairs(lines) do Add("   window: " .. line) end
end

-- The open profession's recipes with whatever difficulty the game gives.
-- Returns how many recipes it found.
local function LogRecipeList()
    local count = 0
    if type(GetNumTradeSkills) == "function" and type(GetTradeSkillInfo) == "function" then
        local ok, n = pcall(GetNumTradeSkills)
        if ok and not IsSecret(n) and type(n) == "number" then
            for i = 1, math.min(n, LIST_LIMIT) do
                Add("   recipe " .. Call("GetTradeSkillInfo(" .. i .. ")", GetTradeSkillInfo, i), true)
            end
            count = count + n
        end
    end
    if type(GetNumCrafts) == "function" and type(GetCraftInfo) == "function" then
        local ok, n = pcall(GetNumCrafts)
        if ok and not IsSecret(n) and type(n) == "number" then
            for i = 1, math.min(n, LIST_LIMIT) do
                Add("   craft " .. Call("GetCraftInfo(" .. i .. ")", GetCraftInfo, i), true)
            end
            count = count + n
        end
    end
    local getAll, getInfo = Field(C_TradeSkillUI, "GetAllRecipeIDs"), Field(C_TradeSkillUI, "GetRecipeInfo")
    if type(getAll) == "function" and type(getInfo) == "function" then
        local ok, ids = pcall(getAll)
        if ok and type(ids) == "table" and not IsSecret(ids) then
            local written = 0
            for _, id in ipairs(ids) do
                if written >= LIST_LIMIT then break end
                local ok2, info = pcall(getInfo, id)
                if ok2 and type(info) == "table" and not IsSecret(info) then
                    local learned = info.learned
                    if IsSecret(learned) or learned ~= false then
                        written = written + 1
                        if written <= 2 then
                            -- every field of the first two, to see what exists
                            Add("   recipe " .. Flat(id) .. " " .. Flat(info), true)
                        else
                            local parts = {}
                            for k, v in pairs(info) do
                                if type(k) == "string" and (k == "name" or HasWord(k, { "diffic", "skill" })) then
                                    parts[#parts + 1] = k .. "=" .. Flat(v)
                                end
                            end
                            table.sort(parts)
                            Add("   recipe " .. Flat(id) .. " " .. table.concat(parts, " "), true)
                        end
                    end
                end
            end
            count = count + written
        end
    end
    if count > 0 then
        Chat("   " .. count .. " recipes found; their details are in the log.")
    end
    return count
end

-- What the cursor is over when a cast starts (a node's name and its
-- "Requires ..." line, with the line's color).
local function LogTooltip()
    if type(GameTooltip) ~= "table" or not GameTooltip:IsShown() then return end
    local parts = {}
    for i = 1, 5 do
        local fs = _G["GameTooltipTextLeft" .. i]
        if type(fs) ~= "table" then break end
        local text = fs:GetText()
        if not IsSecret(text) and text == nil then break end
        local r, g, b = fs:GetTextColor()
        local color = ""
        if type(r) == "number" and not IsSecret(r) and not IsSecret(g) and not IsSecret(b)
            and type(g) == "number" and type(b) == "number" then
            color = string.format(" (%.2f %.2f %.2f)", r, g, b)
        end
        parts[#parts + 1] = Flat(text) .. color
    end
    if #parts > 0 then Add("   tooltip: " .. table.concat(parts, " / ")) end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- Cast events carry a unit; only the player's are wanted. Value: which
-- argument is the spell ID.
local UNIT_EVENTS = {
    UNIT_SPELLCAST_SENT = 4,
    UNIT_SPELLCAST_START = 3,
    UNIT_SPELLCAST_STOP = 3,
    UNIT_SPELLCAST_SUCCEEDED = 3,
    UNIT_SPELLCAST_FAILED = 3,
    UNIT_SPELLCAST_FAILED_QUIET = 3,
    UNIT_SPELLCAST_INTERRUPTED = 3,
    UNIT_SPELLCAST_CHANNEL_START = 3,
    UNIT_SPELLCAST_CHANNEL_STOP = 3,
}
local OTHER_EVENTS = {
    -- profession windows and crafting
    "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_NAME_UPDATE", "TRADE_SKILL_CRAFT_BEGIN",
    "TRADE_SKILL_ITEM_CRAFTED_RESULT", "UPDATE_TRADESKILL_RECAST", "UPDATE_TRADESKILL_CAST_COMPLETE",
    "UPDATE_TRADESKILL_CAST_STOPPED", "CRAFT_SHOW", "CRAFT_CLOSE", "CRAFT_UPDATE",
    "NEW_RECIPE_LEARNED",
    -- skill changes and anything the game says about them
    "CHAT_MSG_SKILL", "SKILL_LINES_CHANGED", "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE",
    "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT",
    -- gathering
    "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED",
}
local EVENT_ORDER = {}
for ev in pairs(UNIT_EVENTS) do EVENT_ORDER[#EVENT_ORDER + 1] = ev end
table.sort(EVENT_ORDER)
for _, ev in ipairs(OTHER_EVENTS) do EVENT_ORDER[#EVENT_ORDER + 1] = ev end

local WINDOW_EVENTS = {
    TRADE_SKILL_SHOW = true, TRADE_SKILL_UPDATE = true, TRADE_SKILL_LIST_UPDATE = true,
    TRADE_SKILL_DATA_SOURCE_CHANGED = true, CRAFT_SHOW = true, CRAFT_UPDATE = true,
}

local function OnEvent(_, event, ...)
    if not on then return end
    local spellArg = UNIT_EVENTS[event]
    if spellArg then
        local unit = ...
        if not IsSecret(unit) and unit ~= "player" then return end
    end
    local n = select("#", ...)
    Add(event .. "(" .. FlatList(n, ...) .. ")")

    if spellArg then
        local id = select(spellArg, ...)
        if not IsSecret(id) and type(id) == "number" then
            LogSpellDetails(id)
        end
        if event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_START" then
            LogTooltip()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            LogTrade()
            LogSkills(true)
            -- and once more shortly after, in case the skill-up lands late
            C_Timer.After(1, function() if on then LogSkills(false) end end)
        end
    elseif WINDOW_EVENTS[event] then
        if event == "TRADE_SKILL_SHOW" or event == "CRAFT_SHOW" then listPending = true end
        LogTrade()
        if listPending and LogRecipeList() > 0 then listPending = false end
    elseif event == "CHAT_MSG_SKILL" or event == "SKILL_LINES_CHANGED" then
        LogSkills(false)
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        local line = Call("IsFishingLoot()", IsFishingLoot)
        if line then Add("   " .. line) end
    end
end

local function Register()
    watcher = watcher or CreateFrame("Frame")
    watcher:SetScript("OnEvent", OnEvent)
    local yes, no = {}, {}
    for _, ev in ipairs(EVENT_ORDER) do
        local valid = not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(ev)
        local ok = false
        if valid then
            if UNIT_EVENTS[ev] and watcher.RegisterUnitEvent then
                ok = (pcall(watcher.RegisterUnitEvent, watcher, ev, "player"))
            end
            if not ok then ok = (pcall(watcher.RegisterEvent, watcher, ev)) end
        end
        if ok then
            registered[ev] = true
            yes[#yes + 1] = ev
        else
            no[#no + 1] = ev
        end
    end
    Add("events this client has: " .. (#yes > 0 and table.concat(yes, ", ") or "(none)"), true)
    Add("events it doesn't have: " .. (#no > 0 and table.concat(no, ", ") or "(none)"), true)
    Chat("watching " .. #yes .. " events (" .. #no .. " don't exist on this client).")
end

local function Unregister()
    if not watcher then return end
    for ev in pairs(registered) do
        pcall(watcher.UnregisterEvent, watcher, ev)
        registered[ev] = nil
    end
end

---------------------------------------------------------------------------
-- Copy window: the log in an edit box, to select and copy
---------------------------------------------------------------------------

local function ShowCopyWindow()
    local lines = Lines()
    if #lines == 0 then
        ns.Print("The cast log is empty. Start it with /sskw castlog.")
        return
    end
    if not copyWindow then
        local f = CreateFrame("Frame", "SimpleSkillWatchCastLog", UIParent, "BackdropTemplate")
        f:SetSize(640, 420)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0, 0, 0, 0.95)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText("Cast log: click in the text, then Ctrl+A and Ctrl+C")

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)

        local scroll = CreateFrame("ScrollFrame", nil, f)
        scroll:SetPoint("TOPLEFT", 12, -34)
        scroll:SetPoint("BOTTOMRIGHT", -12, 12)
        scroll:EnableMouseWheel(true)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
        edit:SetWidth(610)
        edit:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            f:Hide()
        end)
        scroll:SetScrollChild(edit)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local range = self:GetVerticalScrollRange() or 0
            local to = (self:GetVerticalScroll() or 0) - delta * 60
            if to < 0 then to = 0 elseif to > range then to = range end
            self:SetVerticalScroll(to)
        end)
        -- clicking the empty area below the text still puts the cursor in it
        scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)

        if type(UISpecialFrames) == "table" then
            table.insert(UISpecialFrames, "SimpleSkillWatchCastLog")
        end
        f.edit = edit
        copyWindow = f
    end
    FlushRepeats()
    copyWindow.edit:SetText(table.concat(lines, "\n"))
    copyWindow.edit:SetCursorPosition(0)
    copyWindow:Show()
    copyWindow.edit:SetFocus()
    copyWindow.edit:HighlightText()
end

---------------------------------------------------------------------------
-- /sskw castlog [copy | clear]
---------------------------------------------------------------------------

local function Start()
    on, full = true, false
    startTime = Now()
    lastLine, repeats, lastSkills, lastTrade, listPending = nil, 0, nil, nil, false
    wipe(seenSpell)
    wipe(Lines())
    ns.Print("Cast log on. Craft something and gather something, then type /sskw castlog again.")
    Add("SimpleSkillWatch " .. tostring(ns.VERSION) .. " cast log", true)
    Survey()
    Register()
    LogSkills(true)
    LogTrade()
end

local function Stop()
    FlushRepeats()
    on = false
    Unregister()
    ns.Print("Cast log off, " .. #Lines() .. " lines kept. /sskw castlog copy opens them to copy.")
end

function ns.CastLog(arg)
    if not ns.db then return end
    if arg == "copy" or arg == "show" then
        ShowCopyWindow()
    elseif arg == "clear" then
        wipe(Lines())
        full = false
        ns.Print("Cast log cleared.")
    elseif on then
        Stop()
    else
        Start()
    end
end

function ns.CastLogOn() return on end
