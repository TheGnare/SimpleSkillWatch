-- SimpleSkillWatch v1.0.0 for World of Warcraft: Forever (interface 16001)
-- Shows weapon/defense and profession skills as colored bars in a movable frame.

local ADDON, ns = ...
ns.VERSION = "1.0.0"
ns.NAME = "SimpleSkillWatch"

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

-- Forever's Skills tab groups lines by category; a header's skillID is its category.
local WEAPON_CATEGORY = 6          -- Weapon Skills (includes Defense)
local OTHER_CATEGORIES = { [9] = true, [11] = true }  -- Secondary Skills, Professions
local DEFENSE_SKILL_ID = 95

-- Real professions by skill line ID. These get profession coloring wherever
-- the client files them. Anything else in the Professions / Secondary Skills
-- groups (Lockpicking, Riding, ...) goes to "Other" with weapon-style coloring.
local PROFESSION_IDS = {
    [171] = true, -- Alchemy
    [164] = true, -- Blacksmithing
    [333] = true, -- Enchanting
    [202] = true, -- Engineering
    [182] = true, -- Herbalism
    [165] = true, -- Leatherworking
    [186] = true, -- Mining
    [393] = true, -- Skinning
    [197] = true, -- Tailoring
    [185] = true, -- Cooking
    [129] = true, -- First Aid
    [356] = true, -- Fishing
}

-- Trainer requirements for the next rank, keyed by the current trained cap.
-- Skill needed to train the next rank, keyed by the current trained cap.
-- Forever's trainers list only a skill requirement (seen in game: Journeyman
-- Skinning "Requires: Skinning (50)" at character level 8, Expert "(125)").
-- Not exposed by any API outside a trainer window, so it lives here.
local NEXT_RANK = {
    [75]  = 50,  -- -> Journeyman (150)
    [150] = 125, -- -> Expert (225)
    [225] = 200, -- -> Artisan (300)
}
-- Secondary professions' Artisan step (quest/book) needs 225 skill in Classic.
local SECONDARY_IDS = { [185] = true, [129] = true, [356] = true }
local SECONDARY_ARTISAN_SKILL = 225

-- Weapon item subclass (Enum.ItemWeaponSubclass) -> the skill line it uses.
-- Skill line IDs from Forever's Skills tab source; fist weapons list both the
-- Classic "Fist Weapons" line and Forever's Unarmed line, first one known wins.
local UNARMED_SKILL_ID = 162
local WEAPON_SKILL_BY_SUBCLASS = {
    [0]  = { 44 },        -- One-Handed Axes  -> Axes
    [1]  = { 172 },       -- Two-Handed Axes
    [2]  = { 45 },        -- Bows
    [3]  = { 46 },        -- Guns
    [4]  = { 54 },        -- One-Handed Maces -> Maces
    [5]  = { 160 },       -- Two-Handed Maces
    [6]  = { 229 },       -- Polearms
    [7]  = { 43 },        -- One-Handed Swords -> Swords
    [8]  = { 55 },        -- Two-Handed Swords
    [10] = { 136 },       -- Staves
    [13] = { 473, 162 },  -- Fist Weapons
    [15] = { 173 },       -- Daggers
    [16] = { 176 },       -- Thrown
    [18] = { 226 },       -- Crossbows
    [19] = { 228 },       -- Wands
}
local WEAPON_SLOTS = { 16, 17, 18 }   -- main hand, off hand, ranged
local ITEM_CLASS_WEAPON = 2
local SUBCLASS_THROWN = 16
local THROWN_SKILL_ID = 176

local SECTIONS = {
    { key = "weapon", title = "Weapons" },
    { key = "prof",   title = "Professions" },
    { key = "other",  title = "Other" },
}
ns.SECTIONS = SECTIONS

-- Settings reset by the panel's Defaults button (position and hidden skills are kept).
local DEFAULTS = {
    weaponRedPct   = 75,   -- weapons: below this % of max -> red
    weaponGreenPts = 5,    -- weapons: within this many points of max -> green (between -> yellow)
    lowSkillWarning = true, -- red border on a RED weapon skill you have equipped
    pulseWarning   = true, -- ...and pulse it (otherwise a steady border)
    onlyEquipped   = false, -- weapons: show only the equipped weapon skills (plus Defense)
    alsoUnarmed    = false, -- ...and always Unarmed too
    showThrownCharges = true, -- Thrown bar: show the equipped thrown weapon's durability (its charges)
    alertLowCharges   = true, -- ...in bright yellow when low
    lowChargesPct     = 30,   -- ...below this % of max
    useTrainerReqs = true, -- professions: TRAIN when the next rank's skill requirement is met
    profWarnPct    = 90,   -- professions (if the above is off, or rank unknown): red at this % of trained cap
    profGameCap    = 300,  -- professions: the game's real cap; never warn here, gold when reached
    profAlerts     = true, -- professions: sound + chat line when a skill-up leaves one at TRAIN or at its trained cap
    alertOnScreen  = true, -- ...and the same line in the middle of the screen
    soundTrain     = "Quest failed", -- ...sound when the next rank can be trained
    soundCap       = "Raid warning", -- ...sound when the skill is stuck at its trained cap
    scale          = 1.0,
    width          = 230,  -- frame width; never below ns.MinWidth()
    bgAlpha        = 35,   -- frame background + border opacity, 0-100
    barAlpha       = 70,   -- bar fill + track opacity, 0-100 (text stays opaque)
    font           = "Default",
    fontSize       = 10,
    showTitle      = true,
    growUp         = false, -- false: new rows extend the frame downward; true: upward
    layout         = "stacked", -- "stacked", "side" (weapons left), "flipped" (professions left)
    shown          = true,
}
ns.DEFAULTS = DEFAULTS

-- Fonts every client ships. Fonts registered with LibSharedMedia by other
-- addons are added to the list too.
local BUILTIN_FONTS = {
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow",  path = "Fonts\\ARIALN.TTF" },
    { name = "Skurri",        path = "Fonts\\skurri.ttf" },
    { name = "Morpheus",      path = "Fonts\\MORPHEUS.ttf" },
}

-- Alert sounds: the game's own, by SOUNDKIT name (id is that sound's usual
-- number, used if the client doesn't have the name). Harsher ones first.
-- Sounds registered with LibSharedMedia by other addons are added to the list.
local BUILTIN_SOUNDS = {
    { name = "Raid warning",    kit = "RAID_WARNING",             id = 8959 },
    { name = "Boss warning",    kit = "RAID_BOSS_EMOTE_WARNING",  id = 12197 },
    { name = "Alarm clock 1",   kit = "ALARM_CLOCK_WARNING_2",    id = 12867 },
    { name = "Alarm clock 2",   kit = "ALARM_CLOCK_WARNING_3",    id = 12889 },
    { name = "Ready check",     kit = "READY_CHECK",              id = 8960 },
    { name = "PvP queue",       kit = "PVP_THROUGH_QUEUE",        id = 8459 },
    { name = "Quest failed",    kit = "IG_QUEST_FAILED",          id = 847 },
    { name = "Invite declined", kit = "IG_PLAYER_INVITE_DECLINE", id = 882 },
    { name = "Map ping",        kit = "MAP_PING",                 id = 3175 },
    { name = "Whisper",         kit = "TELL_MESSAGE",             id = 3081 },
}

local COLORS = {
    red    = { 0.80, 0.15, 0.15 },
    yellow = { 0.90, 0.75, 0.10 },
    green  = { 0.20, 0.70, 0.20 },
    blue   = { 0.20, 0.45, 0.90 },
    gold   = { 1.00, 0.70, 0.00 },
    gray   = { 0.40, 0.40, 0.40 },
}

local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local ROW_GAP, PAD = 2, 8

-- Open padlock; if the client rejects the file, an orange "unlocked" label is used instead.
local UNLOCK_TEXTURES = {
    "Interface\\Buttons\\LockButton-Unlocked-Up",
}

local cfg, charDB -- set on ADDON_LOADED (also ns.cfg / ns.charDB)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33bbffSimpleSkillWatch|r: " .. tostring(msg))
end
ns.Print = Print

-- Forever inherits Midnight's "secret value" restrictions: never compare,
-- do math on, or print a secret value.
local function IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v) == true
end

local function Plain(v)
    if IsSecret(v) then return nil end
    return v
end

local function Describe(v)
    if IsSecret(v) then return "<secret>" end
    return tostring(v)
end

ns.IsSecret, ns.Describe = IsSecret, Describe

local function HasSkillAPI()
    return type(C_SkillInfo) == "table"
        and type(C_SkillInfo.GetNumSkillLines) == "function"
        and type(C_SkillInfo.GetSkillLineInfo) == "function"
        and type(C_SkillInfo.GetSkillLineInfoByID) == "function"
end

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then dst[k] = v end
    end
end

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = DeepCopy(v) end
    return c
end

---------------------------------------------------------------------------
-- Profiles (Ace3-style)
--   SimpleSkillWatchDB     = { profiles = { [name] = settings }, panelPos, panelTab }
--   SimpleSkillWatchCharDB = { profile = name, pos, known }
-- Settings, including hidden skills, live in profiles; frame position and the
-- learned-skill list stay per character. `cfg` everywhere is a fixed proxy
-- that reads and writes the active profile, so switching profiles never
-- leaves code holding the old settings table.
---------------------------------------------------------------------------

local db, activeProfile
local ApplyEverything -- assigned once the UI exists

local cfgProxy = setmetatable({}, {
    __index = function(_, k) return activeProfile and activeProfile[k] end,
    __newindex = function(_, k, v) activeProfile[k] = v end,
})

local function ClassProfileName()
    local className = UnitClass and UnitClass("player")
    if type(className) == "string" and not IsSecret(className) and className ~= "" then
        return className
    end
end
ns.ClassProfileName = ClassProfileName

-- 0.10.x and earlier kept one shared set of settings at the top level of
-- SimpleSkillWatchDB; it becomes the "Default" profile.
local function LoadDB()
    SimpleSkillWatchDB = SimpleSkillWatchDB or {}
    db = SimpleSkillWatchDB
    if not db.profiles then
        local legacy = {}
        for k, v in pairs(db) do legacy[k] = v end
        wipe(db)
        db.profiles = {}
        db.panelPos, db.panelTab = legacy.panelPos, legacy.panelTab
        legacy.panelPos, legacy.panelTab = nil, nil
        if next(legacy) then db.profiles.Default = legacy end
    end
end

-- Make sure this character is on a profile that exists. A character without
-- one gets a profile named after its class, started as a copy of "Default"
-- if that exists, otherwise from the built-in defaults.
local function ResolveProfile()
    local name = charDB.profile
    if not (name and db.profiles[name]) then
        local className = ClassProfileName()
        name = className or "Default"
        if not db.profiles[name] then
            db.profiles[name] = DeepCopy(db.profiles.Default) or {}
        end
        -- only remember it once the class is known (re-checked at login)
        if className then charDB.profile = name end
    end
    activeProfile = db.profiles[name]
    CopyDefaults(activeProfile, DEFAULTS)
    activeProfile.ignored = activeProfile.ignored or {}
end

function ns.CurrentProfile()
    return charDB and charDB.profile
end

function ns.GetProfiles()
    local list = {}
    for name in pairs(db.profiles) do list[#list + 1] = name end
    table.sort(list, function(a, b) return a:lower() < b:lower() end)
    return list
end

function ns.ProfileExists(name)
    return db and db.profiles[name] ~= nil
end

function ns.SetProfile(name)
    if not db.profiles[name] then return false end
    charDB.profile = name
    ResolveProfile()
    ApplyEverything()
    return true
end

-- Save the current settings under a new name and switch to it.
function ns.SaveProfileAs(name)
    if not db.profiles[name] then
        db.profiles[name] = DeepCopy(activeProfile)
    end
    return ns.SetProfile(name)
end

-- Replace the current profile's settings with a copy of another profile's.
function ns.CopyProfileIntoCurrent(source)
    local from = db.profiles[source]
    if not from or from == activeProfile then return false end
    local copy = DeepCopy(from)
    wipe(activeProfile)
    for k, v in pairs(copy) do activeProfile[k] = v end
    ResolveProfile()
    ApplyEverything()
    return true
end

-- The current profile can't be deleted. Characters on a deleted profile
-- fall back to their class profile at their next login.
function ns.DeleteProfile(name)
    if name == charDB.profile or not db.profiles[name] then return false end
    db.profiles[name] = nil
    return true
end

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------

-- { name, path } list: "Default" (the game's own small font) first.
function ns.GetFonts()
    local list, seen = { { name = "Default" } }, {}
    for _, f in ipairs(BUILTIN_FONTS) do
        list[#list + 1] = f
        seen[f.path:lower()] = true
    end
    local ok, LSM = pcall(function() return LibStub and LibStub("LibSharedMedia-3.0", true) end)
    if ok and LSM and LSM.List and LSM.Fetch then
        local extra = {}
        for _, n in ipairs(LSM:List("font") or {}) do
            local p = LSM:Fetch("font", n, true)
            if type(p) == "string" and not seen[p:lower()] then
                seen[p:lower()] = true
                extra[#extra + 1] = { name = n, path = p }
            end
        end
        table.sort(extra, function(a, b) return a.name < b.name end)
        for _, f in ipairs(extra) do list[#list + 1] = f end
    end
    return list
end

---------------------------------------------------------------------------
-- Sounds
---------------------------------------------------------------------------

-- { name, kit, id } or { name, file } list: "None" first, then the built-in
-- sounds, then any SharedMedia ones.
function ns.GetSounds()
    local list, seen = { { name = "None" } }, { none = true }
    for _, snd in ipairs(BUILTIN_SOUNDS) do
        list[#list + 1] = snd
        seen[snd.name:lower()] = true
    end
    local ok, LSM = pcall(function() return LibStub and LibStub("LibSharedMedia-3.0", true) end)
    if ok and LSM and LSM.List and LSM.Fetch then
        local extra = {}
        for _, n in ipairs(LSM:List("sound") or {}) do
            local file = LSM:Fetch("sound", n, true)
            if type(n) == "string" and not seen[n:lower()]
                and (type(file) == "string" or type(file) == "number") then
                seen[n:lower()] = true
                extra[#extra + 1] = { name = n, file = file }
            end
        end
        table.sort(extra, function(a, b) return a.name < b.name end)
        for _, snd in ipairs(extra) do list[#list + 1] = snd end
    end
    return list
end

-- Play a sound from the list by name, on the Master channel so it is heard
-- even with sound effects turned off. fallback: the name to use if this one
-- is gone (e.g. a SharedMedia sound whose addon was removed).
-- Returns true if the client accepted it.
function ns.PlayAlertSound(name, fallback)
    local entry, spare
    for _, snd in ipairs(ns.GetSounds()) do
        if snd.name == name then entry = snd end
        if snd.name == fallback then spare = snd end
    end
    entry = entry or spare
    if not entry then return false end
    if entry.file then
        return type(PlaySoundFile) == "function" and (pcall(PlaySoundFile, entry.file, "Master")) or false
    end
    local id = (type(SOUNDKIT) == "table" and SOUNDKIT[entry.kit]) or entry.id
    if not id then return false end -- "None"
    return type(PlaySound) == "function" and (pcall(PlaySound, id, "Master")) or false
end

local fontPath, fontFlags -- resolved by ns.ApplyFonts

-- The path a font name maps to (nil if unknown); "Default" is the game's small font.
function ns.FontPath(name)
    if name == "Default" then
        return (GameFontHighlightSmall:GetFont())
    end
    for _, f in ipairs(ns.GetFonts()) do
        if f.name == name then return f.path end
    end
end

local function ResolveFont()
    local defPath, _, defFlags = GameFontHighlightSmall:GetFont()
    local path = defPath
    if cfg.font ~= "Default" then
        local found = false
        for _, f in ipairs(ns.GetFonts()) do
            if f.name == cfg.font and f.path then path = f.path; found = true; break end
        end
        if not found then cfg.font = "Default" end -- e.g. a SharedMedia font that's gone
    end
    fontPath, fontFlags = path, defFlags or ""
end

-- Every font string whose face/size follows the settings.
local fontStrings = {}

-- SetFont that never throws: tries with the game's flags, then without.
-- Returns true on success. A false return usually means the font file isn't
-- loaded yet (common for addon fonts right after login), so callers fall back
-- to the default face and try again later; it's reported only if it never
-- succeeds (see ns.ApplyFonts).
function ns.SetFontSafe(fs, path, size, flags)
    local ok, result = pcall(fs.SetFont, fs, path, size, flags or "")
    if ok and result ~= false then return true end
    local ok2, result2 = pcall(fs.SetFont, fs, path, size)
    return ok2 and result2 ~= false
end

-- Applies the chosen face; if the client refuses it (not loaded yet), shows
-- the default face meanwhile so the text is never blank. Returns true if the
-- chosen face took.
-- force: switch to the default face first, so re-applying a face the string
-- already has counts as a real change and redraws (see ns.ApplyFonts).
local function StyleFont(fs, force)
    if not fontPath then return true end
    local text = fs:GetText()
    local defPath = GameFontHighlightSmall:GetFont()
    if force and defPath then ns.SetFontSafe(fs, defPath, cfg.fontSize, fontFlags) end
    local ok = ns.SetFontSafe(fs, fontPath, cfg.fontSize, fontFlags)
    if not ok and defPath then ns.SetFontSafe(fs, defPath, cfg.fontSize, fontFlags) end
    -- re-set the text so the new face is laid out right away
    if text then fs:SetText("") fs:SetText(text) end
    return ok
end

local function Track(fs)
    fontStrings[#fontStrings + 1] = fs
    StyleFont(fs)
    return fs
end

-- Sizes that follow the font size.
local function Metrics()
    local s = cfg and cfg.fontSize or 10
    return {
        rowH    = math.max(12, s + 4),
        headerH = s + 6,
        titleH  = s + 4,
        lock    = math.max(12, s + 4),
    }
end

---------------------------------------------------------------------------
-- Skill data
---------------------------------------------------------------------------

-- Last plain values per skill ID this session, used when the client
-- returns secret values (e.g. in combat).
local cache = {}

local function ReadSkill(info, id)
    if type(info) ~= "table" then return nil end
    local prev = cache[id] or {}
    local s = {
        id       = id,
        name     = Plain(info.name) or prev.name,
        rank     = Plain(info.rank) or prev.rank,
        maxRank  = Plain(info.maxRank) or prev.maxRank,
        modifier = Plain(info.modifier) or prev.modifier or 0,
        category = Plain(info.skillLineCategoryID) or prev.category,
    }
    cache[id] = s
    return s
end

local function Classify(id, category)
    if PROFESSION_IDS[id] then return "prof" end
    if category == WEAPON_CATEGORY then return "weapon" end
    if OTHER_CATEGORIES[category] then return "other" end
    return nil
end

-- Walk the visible Skills list and remember every trackable skill.
-- Lines under a collapsed header aren't listed, so known skills are kept
-- per character and read back by ID.
local function ScanVisibleLines()
    local n = Plain(C_SkillInfo.GetNumSkillLines())
    if type(n) ~= "number" then return end
    for i = 1, n do
        local info = C_SkillInfo.GetSkillLineInfo(i)
        if type(info) == "table" and not IsSecret(info.isHeader) and not info.isHeader then
            local id = Plain(info.skillID)
            local parent = Plain(info.parentSkillLineID) or 0
            if type(id) == "number" and parent == 0 then
                local s = ReadSkill(info, id)
                local kind = Classify(id, s.category)
                if kind and type(s.maxRank) == "number" and s.maxRank > 1 then
                    charDB.known[id] = { kind = kind, order = i, name = s.name }
                end
            end
        end
    end
end

-- Every known skill for this character, hidden ones included, for the settings panel.
function ns.GetKnownSkills()
    local list = {}
    if not charDB then return list end
    local kindOrder = { weapon = 1, prof = 2, other = 3 }
    for id, k in pairs(charDB.known) do
        list[#list + 1] = {
            id = id, kind = k.kind, order = k.order or 999,
            name = (cache[id] and cache[id].name) or k.name or ("Skill " .. id),
        }
    end
    table.sort(list, function(a, b)
        local ka, kb = kindOrder[a.kind] or 9, kindOrder[b.kind] or 9
        if ka ~= kb then return ka < kb end
        if a.order ~= b.order then return a.order < b.order end
        return a.name < b.name
    end)
    return list
end

-- With "Only show equipped weapon" on, equipment (not the Skills-tab
-- checkboxes) decides which weapon skills show; Defense always follows its
-- checkbox. Returns true for skills the equipped filter controls.
function ns.EquipFilterControls(id, kind)
    return cfg.onlyEquipped and kind == "weapon" and id ~= DEFENSE_SKILL_ID
end

-- equipped: set of skill IDs currently wielded (needed when onlyEquipped is on)
local function Visible(id, kind, equipped)
    if ns.EquipFilterControls(id, kind) then
        if id == UNARMED_SKILL_ID and cfg.alsoUnarmed then return true end
        return equipped and equipped[id] and true or false
    end
    return not cfg.ignored[id]
end

local function Collect(equipped)
    local groups = { weapon = {}, prof = {}, other = {} }
    for id, k in pairs(charDB.known) do
        if Visible(id, k.kind, equipped) then
            local info = C_SkillInfo.GetSkillLineInfoByID(id)
            if type(info) == "table" then
                local s = ReadSkill(info, id)
                s.name = s.name or k.name or ("Skill " .. id)
                s.order = k.order or 999
                if id == DEFENSE_SKILL_ID and type(UnitDefenseSkill) == "function" then
                    local _, mod = UnitDefenseSkill("player")
                    mod = Plain(mod)
                    if type(mod) == "number" then s.modifier = mod end
                end
                local list = groups[k.kind]
                if list then list[#list + 1] = s end
            end
        end
    end
    for _, list in pairs(groups) do
        table.sort(list, function(a, b)
            if a.order ~= b.order then return a.order < b.order end
            return a.name < b.name
        end)
    end
    return groups
end

---------------------------------------------------------------------------
-- Coloring
---------------------------------------------------------------------------

-- Skill line IDs of the weapons equipped right now (main hand, off hand,
-- ranged); an empty main hand means Unarmed. Last good answer is kept if the
-- client ever hides the values (e.g. in combat).
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local lastEquipped = {}

-- Disarm: the weapon stays equipped but can't be used, so no equipment
-- change happens. Blizzard's character sheet shows it red via
-- GetInventoryItemEquippedUnusable; a loss-of-control "DISARM" entry is a
-- backup source for the main hand. Unknown or hidden values count as not
-- disarmed.
-- count(), get(i) for the player's active loss-of-control effects, using the
-- per-unit functions newer clients have, else the older player-only ones.
local function LoCApi()
    local loc = C_LossOfControl
    if type(loc) ~= "table" then return nil end
    if type(loc.GetActiveLossOfControlDataCountByUnit) == "function"
        and type(loc.GetActiveLossOfControlDataByUnit) == "function" then
        return function() return loc.GetActiveLossOfControlDataCountByUnit("player") end,
               function(i) return loc.GetActiveLossOfControlDataByUnit("player", i) end,
               "ByUnit"
    end
    if type(loc.GetActiveLossOfControlDataCount) == "function"
        and type(loc.GetActiveLossOfControlData) == "function" then
        return loc.GetActiveLossOfControlDataCount, loc.GetActiveLossOfControlData, "player-only"
    end
    return nil
end
ns.LoCApi = LoCApi

-- An effect counts as a disarm by its type, or failing that by its display
-- text ("Disarmed"), whichever the client lets us read.
-- On Forever, in combat, a loss-of-control effect's type and text are hidden;
-- only priority and displayType are always readable ("NeverSecret"). A disarm
-- was observed in game as priority 3, while the player still had full
-- control (which rules out stuns, fears and charms). displayType isn't used:
-- it reflects the player's Interface display options, not the effect.
--
-- Priorities observed on Forever (all with full control):
--   1  Root (e.g. Frost Nova)
--   2  Interrupt / spell school lockout
--   3  Disarm
-- Stuns, fears and charms take control away, so HasControl() excludes them.
local DISARM_PRIORITY = 3

local function HasControl()
    if type(HasFullControl) ~= "function" then return true end
    local ok, v = pcall(HasFullControl)
    if not ok or IsSecret(v) then return true end
    return v and true or false
end

local function IsDisarmEntry(data)
    if type(data) ~= "table" then return false end
    -- readable type or text decides, when the client gives them
    local t = data.locType
    if not IsSecret(t) and type(t) == "string" then return t == "DISARM" end
    local text = data.displayText
    if not IsSecret(text) and type(text) == "string" then
        return text:lower():find("disarm", 1, true) ~= nil
    end
    -- both hidden: fall back to the always-readable priority
    local p = data.priority
    return not IsSecret(p) and p == DISARM_PRIORITY and HasControl()
end

local function LossOfControlDisarm()
    local count, get = LoCApi()
    if not count then return false end
    local ok, n = pcall(count)
    if not ok or IsSecret(n) or type(n) ~= "number" then return false end
    for i = 1, math.min(n, 10) do
        local ok2, data = pcall(get, i)
        if ok2 and IsDisarmEntry(data) then return true end
    end
    return false
end

local function SlotDisarmed(slot, locDisarm)
    if type(GetInventoryItemEquippedUnusable) == "function" then
        local ok, unusable = pcall(GetInventoryItemEquippedUnusable, "player", slot)
        if ok and not IsSecret(unusable) and unusable then return true end
    end
    return slot == 16 and locDisarm or false
end

function ns.DisarmDetectionAvailable()
    return type(GetInventoryItemEquippedUnusable) == "function" or LoCApi() ~= nil
end

local function EquippedWeaponSkills()
    if type(GetInventoryItemID) ~= "function" or type(GetItemInfoInstant) ~= "function" then
        return lastEquipped
    end
    local set = {}
    local locDisarm = LossOfControlDisarm()
    for _, slot in ipairs(WEAPON_SLOTS) do
        local itemID = GetInventoryItemID("player", slot)
        if IsSecret(itemID) then return lastEquipped end
        if itemID and SlotDisarmed(slot, locDisarm) then
            itemID = nil -- disarmed: treat the slot as empty
        end
        if itemID then
            local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(itemID)
            if IsSecret(classID) or IsSecret(subclassID) then return lastEquipped end
            local skills = classID == ITEM_CLASS_WEAPON and WEAPON_SKILL_BY_SUBCLASS[subclassID]
            if skills then
                local chosen = skills[1]
                for _, id in ipairs(skills) do
                    if charDB.known[id] then chosen = id break end
                end
                set[chosen] = true
            end
        elseif slot == 16 then
            set[UNARMED_SKILL_ID] = true
        end
    end
    lastEquipped = set
    return set
end

-- Durability (= charges) of an equipped thrown weapon, from whichever weapon
-- slot holds it: cur, max, or nil when none is equipped. If the client hides
-- the values (e.g. in combat), the last ones read are returned.
local lastCharges

local function ThrownCharges()
    if type(GetInventoryItemID) ~= "function" or type(GetItemInfoInstant) ~= "function"
        or type(GetInventoryItemDurability) ~= "function" then
        return nil
    end
    for _, slot in ipairs(WEAPON_SLOTS) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID and not IsSecret(itemID) then
            local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(itemID)
            if not IsSecret(classID) and not IsSecret(subclassID)
                and classID == ITEM_CLASS_WEAPON and subclassID == SUBCLASS_THROWN then
                local cur, max = GetInventoryItemDurability(slot)
                if IsSecret(cur) or IsSecret(max) then
                    if lastCharges then return lastCharges[1], lastCharges[2] end
                    return nil
                end
                if type(cur) == "number" and type(max) == "number" and max > 0 then
                    lastCharges = { cur, max }
                    return cur, max
                end
                return nil
            end
        end
    end
    lastCharges = nil
    return nil
end

-- Each returns color, tag (text shown before the value, or nil).
local function WeaponColor(rank, max)
    if rank >= max - cfg.weaponGreenPts then return COLORS.green end
    if rank < max * cfg.weaponRedPct / 100 then return COLORS.red end
    return COLORS.yellow
end

local TAG_TRAIN = "|cffffd100TRAIN|r"

local function ProfColor(id, rank, max)
    if max >= cfg.profGameCap then
        if rank >= max then return COLORS.gold end
        return COLORS.blue
    end
    local needSkill = cfg.useTrainerReqs and NEXT_RANK[max]
    if needSkill then
        if max == 225 and SECONDARY_IDS[id] then needSkill = SECONDARY_ARTISAN_SKILL end
        if rank >= needSkill then return COLORS.red, TAG_TRAIN end
        return COLORS.blue
    end
    -- trainer rule off, or a cap the table doesn't know: % of trained cap
    if rank >= max * cfg.profWarnPct / 100 then return COLORS.red, TAG_TRAIN end
    return COLORS.blue
end

---------------------------------------------------------------------------
-- Profession alerts: a sound, a chat line and a line on screen when a
-- skill-up leaves a profession trainable (TRAIN) or stuck at its trained cap.
-- Never at the game's real cap, and never for weapons or "Other" skills.
---------------------------------------------------------------------------

local ALERT_TRAIN, ALERT_CAP = 1, 2
local TRAIN_ALERT_GAP = 20  -- seconds between TRAIN alerts for one profession
local alertSeen = {}        -- skill ID -> last readable rank this session
local lastTrainAlert = {}   -- skill ID -> when its last TRAIN alert was given

local function ProfAlertLevel(id, rank, max)
    local _, tag = ProfColor(id, rank, max)
    if not tag then return nil end
    return rank >= max and ALERT_CAP or ALERT_TRAIN
end

local function ShowOnScreen(text, r, g, b)
    local f = UIErrorsFrame
    if not cfg.alertOnScreen or type(f) ~= "table" or type(f.AddMessage) ~= "function" then return end
    pcall(f.AddMessage, f, text, r, g, b)
end

-- Give one alert. id: the skill, for the TRAIN alert's 20 second gap (the
-- capped alert is never held back). Returns true if it was given.
function ns.ProfAlert(level, name, rank, max, id)
    if not cfg.profAlerts then return false end
    name = name or "A profession"
    if level == ALERT_CAP then
        local text = string.format("%s is stuck at %d/%d until you train the next rank.", name, rank, max)
        ns.PlayAlertSound(cfg.soundCap, DEFAULTS.soundCap)
        Print(text)
        ShowOnScreen(text, 1, 0.25, 0.25)
        return true
    end
    local now = type(GetTime) == "function" and GetTime() or 0
    if id and lastTrainAlert[id] and now - lastTrainAlert[id] < TRAIN_ALERT_GAP then return false end
    if id then lastTrainAlert[id] = now end
    local text = string.format("%s is at %d: you can train the next rank.", name, rank)
    ns.PlayAlertSound(cfg.soundTrain, DEFAULTS.soundTrain)
    Print(text)
    ShowOnScreen(text, 1, 0.82, 0)
    return true
end

-- Called after each rescan: alert for every shown profession whose skill went
-- up since the last look. The first look (login, /reload) only takes note.
local function CheckProfAlerts()
    for id, k in pairs(charDB.known) do
        if k.kind == "prof" then
            local s = ReadSkill(C_SkillInfo.GetSkillLineInfoByID(id), id)
            local rank, max = s and s.rank, s and s.maxRank
            if type(rank) == "number" and type(max) == "number" then
                local before = alertSeen[id]
                alertSeen[id] = rank -- hidden skills too, so un-hiding one never alerts late
                if before and rank > before and not cfg.ignored[id] then
                    local level = ProfAlertLevel(id, rank, max)
                    if level then ns.ProfAlert(level, s.name or k.name, rank, max, id) end
                end
            end
        end
    end
end

-- /sskw alerts test: both alerts, two seconds apart, with made-up numbers.
function ns.TestProfAlerts()
    if not cfg.profAlerts then
        Print("Profession alerts are off. Turn them on with /sskw alerts.")
        return
    end
    ns.ProfAlert(ALERT_TRAIN, "First Aid", 125, 150)
    C_Timer.After(2, function() ns.ProfAlert(ALERT_CAP, "First Aid", 150, 150) end)
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "SimpleSkillWatchFrame", UIParent, "BackdropTemplate")
frame:SetSize(DEFAULTS.width, 40)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
frame:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
frame:Hide()
ns.frame = frame

local title = Track(frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
title:SetPoint("TOPLEFT", PAD, -PAD)
title:SetText("SimpleSkillWatch")

local emptyText = Track(frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"))
emptyText:SetPoint("RIGHT", -PAD, 0)
emptyText:SetJustifyH("LEFT")
emptyText:SetText("No skills found yet. Open the Skills tab (C) once with every group expanded.")

-- Padlock: in the title bar, or on the first section header when the title is
-- hidden. Always shown; click to toggle lock. While locked the rest of the
-- frame is click-through, but this button (its own mouse target) still works.
-- It's dimmed while locked, full brightness on hover.
local LOCK_TEXTURE = "Interface\\Buttons\\LockButton-Locked-Up"
local LOCKED_ALPHA = 0.5

local lockButton = CreateFrame("Button", nil, frame)
lockButton:SetSize(14, 14)
do
    local tex = lockButton:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    local okUnlocked = tex:SetTexture(UNLOCK_TEXTURES[1])
    local okLocked = tex:SetTexture(LOCK_TEXTURE)
    lockButton.tex = tex
    lockButton.textOnly = false
    lockButton.dimmed = false
    if not (okUnlocked and okLocked) then
        -- a padlock image is missing on this client: use a text label instead
        tex:Hide()
        local fs = lockButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("RIGHT")
        lockButton.label = fs
        lockButton:SetWidth(50)
        lockButton.textOnly = true
    end
    lockButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
end

local function UpdateLockButton(locked)
    if lockButton.textOnly then
        lockButton.label:SetText(locked and "|cff999999locked|r" or "|cffff8040unlocked|r")
    else
        lockButton.tex:SetTexture(locked and LOCK_TEXTURE or UNLOCK_TEXTURES[1])
    end
    lockButton.dimmed = locked
    if not lockButton:IsMouseOver() then
        lockButton:SetAlpha(locked and LOCKED_ALPHA or 1)
    end
end

-- The frame is pinned by its top-left corner when it grows down, or its
-- bottom-left corner when it grows up, so new rows extend the chosen way.
local function GrowAnchor()
    return cfg.growUp and "BOTTOMLEFT" or "TOPLEFT"
end

local function SavePosition()
    local left = frame:GetLeft()
    local y = cfg.growUp and frame:GetBottom() or frame:GetTop()
    if left and y then
        charDB.pos = { anchor = GrowAnchor(), x = left, y = y }
    end
end

local function RestorePosition()
    frame:ClearAllPoints()
    local p = charDB.pos
    if p and p.anchor then
        frame:SetPoint(p.anchor, UIParent, "BOTTOMLEFT", p.x, p.y)
    elseif p and p[1] then
        -- position saved by an older version: { point, relPoint, x, y }
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end
end
ns.RestorePosition = RestorePosition

-- After a draw: if the saved pin doesn't match the grow direction (setting
-- just changed, another character, or an older save), re-pin the frame
-- where it currently is. Nothing moves on screen.
local function NormalizeAnchor()
    local p = charDB.pos
    if p and p.anchor == GrowAnchor() then return end
    if not frame:GetLeft() then return end
    SavePosition()
    RestorePosition()
end

function ns.SetGrowUp(up)
    cfg.growUp = up and true or false
    NormalizeAnchor()
end

-- Narrowest useful width, measured in the current font: room for the worst-case
-- value text ("TRAIN 300/300(+15)") plus a recognizable truncated name.
-- Longer names are cut with "..." because the label ends where the value starts.
local MIN_WIDTH_FALLBACK, MAX_WIDTH = 180, 500
local minWidth
local measure = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
measure:Hide()

function ns.MinWidth()
    if minWidth then return minWidth end
    StyleFont(measure)
    measure:SetText("|cffffd100TRAIN|r 300/300|cff40ff40(+15)|r")
    local valueW = measure:GetStringWidth()
    measure:SetText("Leath...")
    local nameW = measure:GetStringWidth()
    local w = MIN_WIDTH_FALLBACK
    if type(valueW) == "number" and type(nameW) == "number" and valueW > 0 and nameW > 0 then
        -- frame padding both sides + label/value insets and gap
        w = PAD * 2 + 4 + valueW + 4 + nameW + 4
        -- the Thrown row with charges: "Thr... (200/200)" + a weapon value (never TRAIN)
        if cfg and cfg.showThrownCharges then
            measure:SetText("300/300|cff40ff40(+15)|r")
            local wv = measure:GetStringWidth()
            measure:SetText("Thr... (200/200)")
            local wn = measure:GetStringWidth()
            if type(wv) == "number" and type(wn) == "number" then
                w = math.max(w, PAD * 2 + 4 + wv + 4 + wn + 4)
            end
        end
    end
    w = math.ceil(w / 5) * 5
    if w < 150 then w = 150 elseif w > MAX_WIDTH - 50 then w = MAX_WIDTH - 50 end
    minWidth = w
    return minWidth
end

-- Re-measure the minimum width next time (e.g. thrown charges toggled).
function ns.InvalidateMinWidth() minWidth = nil end
ns.MAX_WIDTH = MAX_WIDTH

-- Background/border opacity, scale, width and lock state.
-- Width is per column: cfg.width is what one column's frame would be on its
-- own (bars + padding). Side-by-side puts two such columns next to each other.
local COL_GAP = 10

local function SideBySide()
    return cfg.layout == "side" or cfg.layout == "flipped"
end

function ns.RowWidth()
    local colW = math.max(ns.MinWidth(), math.min(cfg.width or DEFAULTS.width, MAX_WIDTH))
    return colW - PAD * 2
end

local function ApplyFrameSettings()
    local rowW = ns.RowWidth()
    if SideBySide() then
        frame:SetWidth(PAD + rowW + COL_GAP + rowW + PAD)
    else
        frame:SetWidth(PAD + rowW + PAD)
    end
    local a = cfg.bgAlpha / 100
    frame:SetBackdropColor(0, 0, 0, a)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, a)
    frame:SetScale(cfg.scale)
    -- Locked = click-through: the frame takes no mouse input, except the padlock.
    local locked = ns.IsLocked()
    frame:EnableMouse(not locked)
    UpdateLockButton(locked)
    if locked and GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
end
ns.ApplyFrameSettings = ApplyFrameSettings

-- Lock state is per character, like the frame position (not in profiles), so
-- a new character always starts unlocked.
function ns.IsLocked()
    return charDB and charDB.locked and true or false
end

function ns.SetLocked(locked)
    charDB.locked = locked and true or false
    ApplyFrameSettings()
    if ns.RefreshPanel then ns.RefreshPanel() end
end

local function LockTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if ns.IsLocked() then
        GameTooltip:SetText("Locked")
        GameTooltip:AddLine("The frame is click-through. Click to unlock it so you can move it.", 1, 1, 1, true)
    else
        GameTooltip:SetText("Unlocked")
        GameTooltip:AddLine("Click to lock the frame in place and make it click-through.", 1, 1, 1, true)
    end
    GameTooltip:Show()
end

lockButton:SetScript("OnClick", function(self)
    local nowLocked = not ns.IsLocked()
    ns.SetLocked(nowLocked)
    if nowLocked then self:SetAlpha(1) end -- the cursor is still on it
    if GameTooltip:IsOwned(self) then LockTooltip(self) end
end)
lockButton:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    LockTooltip(self)
end)
lockButton:SetScript("OnLeave", function(self)
    if self.dimmed then self:SetAlpha(LOCKED_ALPHA) end
    GameTooltip:Hide()
end)

frame:SetScript("OnDragStart", function(self)
    if not ns.IsLocked() then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
end)
frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" and ns.TogglePanel then ns.TogglePanel() end
end)
frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("SimpleSkillWatch")
    GameTooltip:AddLine("Drag to move. Right-click for settings.", 1, 1, 1, true)
    GameTooltip:Show()
end)
frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Pools
local headers, rows = {}, {}

local function GetHeader(i)
    local h = headers[i]
    if not h then
        h = Track(frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
        h:SetJustifyH("LEFT")
        headers[i] = h
    end
    return h
end

local function GetRow(i)
    local r = rows[i]
    if not r then
        r = CreateFrame("StatusBar", nil, frame)
        r:SetStatusBarTexture(BAR_TEXTURE)
        r:SetMinMaxValues(0, 1)
        r.track = r:CreateTexture(nil, "BACKGROUND")
        r.track:SetAllPoints()
        r.track:SetColorTexture(0, 0, 0, 1)
        r.valueText = Track(r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
        r.valueText:SetPoint("RIGHT", -4, 0)
        r.valueText:SetJustifyH("RIGHT")
        r.labelText = Track(r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
        r.labelText:SetPoint("LEFT", 4, 0)
        r.labelText:SetPoint("RIGHT", r.valueText, "LEFT", -4, 0)
        r.labelMode = "fill"
        r.labelText:SetJustifyH("LEFT")
        -- extra text right after the name (thrown charges); never truncated
        r.extraText = Track(r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
        r.extraText:SetPoint("LEFT", r.labelText, "RIGHT", 4, 0)
        r.extraText:Hide()
        r.labelText:SetWordWrap(false) -- one line; overflow is cut with "..."
        if r.labelText.SetMaxLines then r.labelText:SetMaxLines(1) end

        -- Low-skill warning: a red border plus a red copy of the name laid over
        -- the white one, pulsed together by a looping alpha animation. The game
        -- runs the animation; nothing here is called per frame.
        local warn = CreateFrame("Frame", nil, r, "BackdropTemplate")
        warn:SetPoint("TOPLEFT", -2, 2)
        warn:SetPoint("BOTTOMRIGHT", 2, -2)
        warn:SetFrameLevel(r:GetFrameLevel() + 2)
        warn:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        warn:SetBackdropBorderColor(1, 0.15, 0.15, 1)
        warn.label = Track(warn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
        warn.label:SetPoint("TOPLEFT", r.labelText, "TOPLEFT")
        warn.label:SetPoint("BOTTOMRIGHT", r.labelText, "BOTTOMRIGHT")
        warn.label:SetJustifyH("LEFT")
        warn.label:SetWordWrap(false)
        if warn.label.SetMaxLines then warn.label:SetMaxLines(1) end
        warn.label:SetTextColor(1, 0.25, 0.25)
        local ag = warn:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local fade = ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.15)
        fade:SetToAlpha(1)
        fade:SetDuration(0.6)
        if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
        warn.anim = ag
        warn:Hide()
        r.warn = warn
        rows[i] = r
    end
    return r
end

-- "10/40", plus a green "(+5)" (or red "(-5)") when gear or racials change the skill.
local function FormatValue(rank, max, mod)
    local text = rank .. "/" .. max
    if type(mod) == "number" and mod > 0 then
        text = text .. "|cff40ff40(+" .. mod .. ")|r"
    elseif type(mod) == "number" and mod < 0 then
        text = text .. "|cffff4040(" .. mod .. ")|r"
    end
    return text
end
ns.FormatValue = FormatValue

local function SetWarning(r, on, name)
    local w = r.warn
    if on then
        w.label:SetText(name)
        if not w:IsShown() then w:Show() end
        if cfg.pulseWarning then
            if not w.anim:IsPlaying() then w.anim:Play() end
        else
            -- steady border: no animation running at all
            if w.anim:IsPlaying() then w.anim:Stop() end
            w:SetAlpha(1)
        end
    elseif w:IsShown() then
        w.anim:Stop()
        w:Hide()
    end
end

-- Name on the left. With extra text (thrown charges) the name is sized to fit
-- and the extra sits right after it, so the name is what gets cut with "...",
-- never the charges. Call after the value text is set.
local function LayoutLabel(r, name, extra)
    r.labelText:SetText(name)
    if not extra then
        r.extraText:Hide()
        if r.labelMode ~= "fill" then
            r.labelText:ClearAllPoints()
            r.labelText:SetPoint("LEFT", 4, 0)
            r.labelText:SetPoint("RIGHT", r.valueText, "LEFT", -4, 0)
            r.labelMode = "fill"
        end
        return
    end
    r.extraText:SetText(extra)
    r.extraText:Show()
    local rowW = ns.RowWidth()
    local avail = rowW - 4 - (r.valueText:GetStringWidth() or 0) - 4
        - (r.extraText:GetStringWidth() or 0) - 4 - 4
    r.labelText:ClearAllPoints()
    r.labelText:SetPoint("LEFT", 4, 0)
    -- Measure the FULL name. A label that was given a narrow width earlier
    -- reports the width of its cut-off text ("Th..."), which would keep it
    -- stuck that narrow after the frame gets wider again.
    local nameW
    if r.labelText.GetUnboundedStringWidth then
        nameW = r.labelText:GetUnboundedStringWidth()
    end
    if type(nameW) ~= "number" or nameW <= 0 then
        r.labelText:SetWidth(0)            -- 0 = unconstrained
        r.labelText:SetText("")
        r.labelText:SetText(name)
        nameW = r.labelText:GetStringWidth() or 0
    end
    r.labelText:SetWidth(math.max(10, math.min(nameW + 1, avail)))
    r.labelMode = "fixed"
end

-- "(154/200)", bright yellow when below the low-charges mark.
local function ChargesText()
    if not cfg.showThrownCharges then return nil end
    local cur, max = ThrownCharges()
    if not cur then return nil end
    local text = "(" .. cur .. "/" .. max .. ")"
    if cfg.alertLowCharges and cur < max * cfg.lowChargesPct / 100 then
        text = "|cffffff00" .. text .. "|r"
    end
    return text
end

local thrownRow, thrownSkill -- the Thrown bar, for charge-only updates

-- equipped: set of skill IDs currently wielded (for the low-skill warning)
local function FillRow(r, s, kind, equipped)
    local a = cfg.barAlpha / 100
    r.track:SetAlpha(0.5 * a)   -- dark track behind the fill
    local extra = (s.id == THROWN_SKILL_ID) and ChargesText() or nil

    local rank, max = s.rank, s.maxRank
    if type(rank) ~= "number" or type(max) ~= "number" or max <= 0 then
        r:SetValue(0)
        r:SetStatusBarColor(COLORS.gray[1], COLORS.gray[2], COLORS.gray[3], a)
        r.valueText:SetText("?")
        LayoutLabel(r, s.name, extra)
        SetWarning(r, false)
        return
    end

    local color, tag
    if kind == "prof" then
        color, tag = ProfColor(s.id, rank, max)
    else
        color, tag = WeaponColor(rank, max)
    end

    r:SetValue(math.min(rank / max, 1))
    r:SetStatusBarColor(color[1], color[2], color[3], a)

    local text = FormatValue(rank, max, s.modifier)
    if tag then
        text = tag .. " " .. text
    end
    r.valueText:SetText(text)
    LayoutLabel(r, s.name, extra)

    SetWarning(r, cfg.lowSkillWarning and kind == "weapon" and color == COLORS.red
        and equipped and equipped[s.id], s.name)
end

local function Render()
    if not cfg or not cfg.shown then
        for _, r in ipairs(rows) do SetWarning(r, false) end
        frame:Hide()
        return
    end

    local m = Metrics()
    local equipped = (cfg.lowSkillWarning or cfg.onlyEquipped) and EquippedWeaponSkills() or nil
    local groups = Collect(equipped)
    thrownRow, thrownSkill = nil, nil
    local top = -PAD
    local hIndex, rIndex = 0, 0
    local firstHeaderY

    if cfg.showTitle then
        title:Show()
        top = top - m.titleH
    else
        title:Hide()
    end

    -- Columns: stacked puts every section in one column; side by side puts
    -- Weapons in one and Professions + Other in the other (flipped swaps them).
    local rowW = ns.RowWidth()
    local colX = { PAD, PAD + rowW + COL_GAP }
    local colY = { top, top }
    local column
    if cfg.layout == "side" then
        column = { weapon = 1, prof = 2, other = 2 }
    elseif cfg.layout == "flipped" then
        column = { weapon = 2, prof = 1, other = 1 }
    else
        column = { weapon = 1, prof = 1, other = 1 }
    end

    for _, sec in ipairs(SECTIONS) do
        local list = groups[sec.key]
        if #list > 0 then
            local c = column[sec.key] or 1
            local x, y = colX[c], colY[c]
            hIndex = hIndex + 1
            local h = GetHeader(hIndex)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", x, y - 2)
            h:SetText(sec.title)
            h:Show()
            if not firstHeaderY or (y - 2) > firstHeaderY then firstHeaderY = y - 2 end
            y = y - m.headerH
            for _, s in ipairs(list) do
                rIndex = rIndex + 1
                local r = GetRow(rIndex)
                r:SetHeight(m.rowH)
                r:SetWidth(rowW)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", x, y)
                FillRow(r, s, sec.key, equipped)
                if s.id == THROWN_SKILL_ID then thrownRow, thrownSkill = r, s end
                r:Show()
                y = y - m.rowH - ROW_GAP
            end
            colY[c] = y
        end
    end
    local y = math.min(colY[1], colY[2])

    for i = hIndex + 1, #headers do headers[i]:Hide() end
    for i = rIndex + 1, #rows do
        SetWarning(rows[i], false) -- stop any pulse on a pooled row
        rows[i]:Hide()
    end

    if rIndex == 0 then
        emptyText:ClearAllPoints()
        emptyText:SetPoint("TOPLEFT", PAD, y - 2)
        emptyText:SetPoint("RIGHT", -PAD, 0)
        emptyText:Show()
        y = y - 2 * m.rowH - 4
    else
        emptyText:Hide()
    end

    -- Lock icon: title bar, or the first section header's line when the title is hidden.
    if not lockButton.textOnly then lockButton:SetSize(m.lock, m.lock) end
    lockButton:ClearAllPoints()
    if cfg.showTitle or not firstHeaderY then
        lockButton:SetPoint("TOPRIGHT", -PAD + 2, -PAD + 2)
    else
        lockButton:SetPoint("TOPRIGHT", -PAD + 2, firstHeaderY + 2)
    end

    frame:SetHeight(-y + PAD)
    frame:Show()
    if charDB.pos then NormalizeAnchor() end
end
ns.Render = Render

-- Re-apply face/size everywhere and re-measure the minimum width.
-- Returns true if the chosen face took on every font string.
local function ApplyFontsNow(force)
    ResolveFont()
    local allOk = true
    for _, fs in ipairs(fontStrings) do
        if not StyleFont(fs, force) then allOk = false end
    end
    minWidth = nil
    ApplyFrameSettings()
    Render()
    return allOk
end

-- A font file used for the first time may not be loaded yet: the client
-- either refuses it (text falls back to the default face meanwhile) or takes
-- it but draws blank, and re-applying the same face is ignored as "no change".
-- So after a font change (and at login), redraw a few times, forcing a real
-- face change each time. The early passes always run; the late ones only
-- while the font is still being refused, and only if it never loads is it
-- reported. A newer font change cancels pending passes.
local FONT_REDRAW_DELAYS = { 0.3, 1.0, 2.5 }      -- always
local FONT_LATE_DELAYS   = { 5.0, 10.0 }          -- only while still refused
local fontRedrawGen = 0

function ns.ApplyFonts()
    local okNow = ApplyFontsNow(false)
    fontRedrawGen = fontRedrawGen + 1
    local gen = fontRedrawGen
    local state = { ok = okNow }

    local function Pass(isLast)
        if gen ~= fontRedrawGen then return end
        state.ok = ApplyFontsNow(true)
        if ns.RefreshPanel then ns.RefreshPanel() end -- the Width minimum may have changed
        if isLast and not state.ok then
            Print("Font '" .. tostring(cfg.font) .. "' couldn't be loaded, so the default font is shown. Pick another with /sskw.")
        end
    end

    for _, delay in ipairs(FONT_REDRAW_DELAYS) do
        C_Timer.After(delay, function() Pass(false) end)
    end
    for i, delay in ipairs(FONT_LATE_DELAYS) do
        C_Timer.After(delay, function()
            if state.ok then return end
            Pass(i == #FONT_LATE_DELAYS)
        end)
    end
end

-- Pick a font by name (case-insensitive). Returns true if it exists.
function ns.SetFontName(name)
    local match
    for _, f in ipairs(ns.GetFonts()) do
        if f.name:lower() == tostring(name):lower() then match = f.name break end
    end
    if not match then return false end
    cfg.font = match
    ns.ApplyFonts()
    if ns.RefreshPanel then ns.RefreshPanel() end
    return true
end

-- What the font setting resolves to, and what a bar's text actually uses.
local function FontInfo()
    Print("font setting: " .. tostring(cfg.font) .. " size " .. tostring(cfg.fontSize))
    Print("resolved path: " .. tostring(fontPath) .. " flags '" .. tostring(fontFlags) .. "'")
    local r = rows[1]
    if r then
        local p, sz, fl = r.labelText:GetFont()
        Print("first bar's label uses: " .. tostring(p) .. " " .. tostring(sz) .. " '" .. tostring(fl) .. "'")
    end
end

---------------------------------------------------------------------------
-- Refresh (coalesced)
---------------------------------------------------------------------------

local pending = false
local firstDrawDone = false

local function Refresh()
    pending = false
    if not cfg then return end
    ScanVisibleLines()
    CheckProfAlerts()
    Render()
    -- first draw after login with a custom font: run the redraw sequence once,
    -- in case its file wasn't loaded yet
    if not firstDrawDone then
        firstDrawDone = true
        if cfg.font ~= "Default" then ns.ApplyFonts() end
    end
end

local function RequestRefresh(delay)
    if pending then return end
    pending = true
    C_Timer.After(delay or 0.25, Refresh)
end

function ns.Rescan()
    wipe(charDB.known)
    Refresh()
    if ns.RefreshPanel then ns.RefreshPanel() end
end

-- Resets the current profile (hidden skills are kept).
function ns.ResetDefaults()
    for k, v in pairs(DEFAULTS) do cfg[k] = v end
    ns.ApplyFonts()
end

-- After a profile switch or copy: fonts, frame settings, bars, settings window.
ApplyEverything = function()
    ns.ApplyFonts() -- also applies frame settings and redraws
    if ns.RefreshPanel then ns.RefreshPanel() end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")

-- Registering an event the client doesn't have throws on Forever, so check first.
local function SafeRegister(ev)
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(ev) then
        return false
    end
    return (pcall(events.RegisterEvent, events, ev))
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

-- Each one triggers a rescan of the Skills list (coalesced), which is how a
-- newly learned weapon skill or profession gets picked up.
local REFRESH_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "SKILL_LINES_CHANGED",  -- skill learned, raised, or cap changed
    "CHAT_MSG_SKILL",       -- "Your skill in X has increased to N."
    "SPELLS_CHANGED",       -- weapon training and profession ranks are spells
    "PLAYER_LEVEL_UP",
    "PLAYER_REGEN_ENABLED", -- values may have been secret during combat
}

-- For /sskw events: which refresh events this client accepted, and how often each fired.
local eventStatus, eventCounts = {}, {}

-- Player-only registration where the client supports it, so other units'
-- aura changes (party, nameplates) never reach the handler at all.
local function SafeRegisterUnit(ev)
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(ev) then
        return false
    end
    if events.RegisterUnitEvent and pcall(events.RegisterUnitEvent, events, ev, "player") then
        return true
    end
    return (pcall(events.RegisterEvent, events, ev))
end

-- Disarm watch. The game says THAT the player's auras changed even when it
-- hides WHAT changed, so each signal re-reads the three weapon slots and
-- redraws only if the disarmed set changed. While disarmed it also rechecks
-- once a second, so the end of a disarm is caught even if nothing announces it.
local DISARM_EVENTS = {
    UNIT_AURA = "unit", UNIT_INVENTORY_CHANGED = "unit",
    -- these carry a unit too on Forever (seen: "player", "targettarget")
    LOSS_OF_CONTROL_ADDED = "unit", LOSS_OF_CONTROL_UPDATE = "unit",
}
local DISARM_EVENT_ORDER = { "UNIT_AURA", "UNIT_INVENTORY_CHANGED", "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE" }
local disarmKey, disarmSeen, disarmRecheckPending = "", 0, false

-- /sskw disarmlog: session-only diagnostics printing what the client reports
-- around a disarm. Off by default; costs nothing while off.
local disarmLog = false
local lastSlotDesc

local SLOT_NAMES = { [16] = "MH", [17] = "OH", [18] = "Ranged" }

local function SlotFlagsDesc()
    if type(GetInventoryItemEquippedUnusable) ~= "function" then
        return "unusable check: function missing"
    end
    local parts = {}
    for _, slot in ipairs(WEAPON_SLOTS) do
        local item = GetInventoryItemID("player", slot)
        if item then
            local ok, v = pcall(GetInventoryItemEquippedUnusable, "player", slot)
            parts[#parts + 1] = SLOT_NAMES[slot] .. " unusable=" .. (ok and Describe(v) or ("error " .. tostring(v)))
        end
    end
    return #parts > 0 and table.concat(parts, ", ") or "no weapons equipped"
end

local function LogLossOfControl(event, a1, a2)
    local count, get, kind = LoCApi()
    if not count then
        Print(event .. ": no loss-of-control lookup functions on this client")
        return
    end
    local ok, n = pcall(count)
    Print(string.format("%s args=(%s, %s) lookup=%s count=%s", event, Describe(a1), Describe(a2), kind,
        ok and Describe(n) or ("error " .. tostring(n))))
    if ok and not IsSecret(n) and type(n) == "number" then
        for i = 1, math.min(n, 5) do
            local ok2, d = pcall(get, i)
            if not ok2 then
                print("   #" .. i .. " error " .. tostring(d))
            elseif type(d) ~= "table" then
                print("   #" .. i .. " " .. Describe(d))
            else
                -- every field, so we can see which ones Forever leaves readable
                local keys = {}
                for k in pairs(d) do keys[#keys + 1] = tostring(k) end
                table.sort(keys)
                local parts = {}
                for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. Describe(d[k]) end
                print("   #" .. i .. " " .. table.concat(parts, " ") .. "  -> disarm=" .. tostring(IsDisarmEntry(d)))
            end
        end
    end
end

-- Attack speed / damage / control, logged when they change while the log is
-- on: tells us whether a disarm shows up as an unarmed-speed main hand.
local function Fmt(v)
    if IsSecret(v) then return "<secret>" end
    if type(v) == "number" then return string.format("%.2f", v) end
    return tostring(v)
end

local lastSnapshot

local function CombatSnapshot()
    local parts = {}
    if type(UnitAttackSpeed) == "function" then
        local ok, mh, oh = pcall(UnitAttackSpeed, "player")
        parts[#parts + 1] = ok and ("speed MH=" .. Fmt(mh) .. " OH=" .. Fmt(oh)) or "speed error"
    end
    if type(UnitDamage) == "function" then
        local ok, lo, hi, olo, ohi = pcall(UnitDamage, "player")
        parts[#parts + 1] = ok and ("dmg MH=" .. Fmt(lo) .. "-" .. Fmt(hi) .. " OH=" .. Fmt(olo) .. "-" .. Fmt(ohi)) or "dmg error"
    end
    if type(HasFullControl) == "function" then
        local ok, v = pcall(HasFullControl)
        parts[#parts + 1] = "fullControl=" .. (ok and Fmt(v) or "error")
    end
    local inCombat = UnitAffectingCombat and UnitAffectingCombat("player")
    parts[#parts + 1] = "combat=" .. Fmt(inCombat)
    return table.concat(parts, " | ")
end

local function LogSnapshotIfChanged(reason)
    local snap = CombatSnapshot()
    if snap ~= lastSnapshot then
        lastSnapshot = snap
        Print(reason .. ": " .. snap)
    end
end

local LOG_ONLY_EVENTS = { UNIT_ATTACK_SPEED = true, UNIT_DAMAGE = true }

local function LogSlotsIfChanged(reason)
    local desc = SlotFlagsDesc()
    if desc ~= lastSlotDesc then
        lastSlotDesc = desc
        Print("weapon slots (" .. reason .. "): " .. desc)
    end
end

function ns.ToggleDisarmLog()
    disarmLog = not disarmLog
    if not disarmLog then
        -- stop watching attack speed / damage entirely
        for ev in pairs(LOG_ONLY_EVENTS) do pcall(events.UnregisterEvent, events, ev) end
        Print("Disarm log off.")
        return
    end
    for ev in pairs(LOG_ONLY_EVENTS) do
        if not (events.RegisterUnitEvent and pcall(events.RegisterUnitEvent, events, ev, "player")) then
            pcall(events.RegisterEvent, events, ev)
        end
    end
    Print("Disarm log on (this session). Get disarmed, then screenshot the chat.")
    local loc = C_LossOfControl
    if type(loc) == "table" then
        local names = {}
        for k, v in pairs(loc) do
            if type(v) == "function" then names[#names + 1] = k end
        end
        table.sort(names)
        print("  C_LossOfControl: " .. (#names > 0 and table.concat(names, ", ") or "(no functions)"))
    else
        print("  C_LossOfControl: missing")
    end
    print("  GetInventoryItemEquippedUnusable: "
        .. (type(GetInventoryItemEquippedUnusable) == "function" and "present" or "missing"))
    lastSlotDesc, lastSnapshot = nil, nil
    LogSlotsIfChanged("now")
    LogSnapshotIfChanged("now")
end

local function CheckDisarm()
    if not cfg or not (cfg.lowSkillWarning or cfg.onlyEquipped) then return end
    local locDisarm = LossOfControlDisarm()
    local key = ""
    for _, slot in ipairs(WEAPON_SLOTS) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID and not IsSecret(itemID) and SlotDisarmed(slot, locDisarm) then
            key = key .. slot .. ","
        end
    end
    if key ~= disarmKey then
        if disarmKey == "" then disarmSeen = disarmSeen + 1 end
        if disarmLog then
            Print(key ~= "" and ("DISARM DETECTED: slots " .. key) or "disarm ended")
        end
        disarmKey = key
        Render()
    end
    if key ~= "" and not disarmRecheckPending then
        disarmRecheckPending = true
        C_Timer.After(1, function()
            disarmRecheckPending = false
            CheckDisarm()
        end)
    end
end

events:SetScript("OnEvent", function(self, event, arg1, arg2)
    eventCounts[event] = (eventCounts[event] or 0) + 1
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        LoadDB()
        SimpleSkillWatchCharDB = SimpleSkillWatchCharDB or {}
        charDB = SimpleSkillWatchCharDB
        charDB.known = charDB.known or {}
        ResolveProfile()
        -- 0.13.x and earlier kept the lock in the profile. A character that
        -- has already placed its frame keeps that state; new ones start unlocked.
        if charDB.locked == nil then
            charDB.locked = (charDB.pos ~= nil and activeProfile.locked == true)
        end
        cfg = cfgProxy
        ns.cfg, ns.charDB, ns.db = cfg, charDB, db
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        if not HasSkillAPI() then
            Print("C_SkillInfo isn't available on this client; addon disabled.")
            return
        end
        ResolveProfile() -- class is surely known by now (first-time characters)
        RestorePosition()
        ResolveFont()
        for _, fs in ipairs(fontStrings) do StyleFont(fs) end
        ApplyFrameSettings()
        if ns.InitSettings then ns.InitSettings() end
        for _, ev in ipairs(REFRESH_EVENTS) do eventStatus[ev] = SafeRegister(ev) end
        eventStatus.PLAYER_EQUIPMENT_CHANGED = SafeRegister("PLAYER_EQUIPMENT_CHANGED")
        eventStatus.UPDATE_INVENTORY_DURABILITY = SafeRegister("UPDATE_INVENTORY_DURABILITY")
        for ev, kind in pairs(DISARM_EVENTS) do
            eventStatus[ev] = (kind == "unit") and SafeRegisterUnit(ev) or SafeRegister(ev)
        end
        RequestRefresh(1)
        DEFAULT_CHAT_FRAME:AddMessage("|cff33bbffSimpleSkillWatch|r (v" .. ns.VERSION .. ") loaded. /sskw for settings.")

    elseif LOG_ONLY_EVENTS[event] then
        -- only registered while /sskw disarmlog is on
        if disarmLog and (arg1 == nil or arg1 == "player") then LogSnapshotIfChanged(event) end

    elseif DISARM_EVENTS[event] then
        if DISARM_EVENTS[event] == "unit" and arg1 ~= "player" then return end
        if disarmLog then
            if event == "LOSS_OF_CONTROL_ADDED" then
                LogLossOfControl(event, arg1, arg2)
                LogSnapshotIfChanged(event)
            elseif event == "LOSS_OF_CONTROL_UPDATE" then
                LogSnapshotIfChanged(event)
            end
            LogSlotsIfChanged(event)
        end
        CheckDisarm()

    elseif event == "UPDATE_INVENTORY_DURABILITY" then
        -- fires on every throw: refresh only the Thrown bar, nothing else
        if cfg.showThrownCharges and thrownRow and thrownRow:IsShown() then
            FillRow(thrownRow, thrownSkill, "weapon", cfg.lowSkillWarning and lastEquipped or nil)
        end

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- weapon swap (also mid-combat): redraw right away, no rescan needed
        if arg1 == 16 or arg1 == 17 or arg1 == 18 or arg1 == nil then Render() end

    elseif event == "PLAYER_LEVEL_UP" then
        -- weapon caps rise a moment after the level-up event
        RequestRefresh(1)

    else
        RequestRefresh()
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function FindKnownByName(name)
    name = name:lower()
    for id, k in pairs(charDB.known) do
        local n = (cache[id] and cache[id].name) or k.name
        if n and n:lower() == name then return id, n end
    end
end

local function DebugDump()
    local n = C_SkillInfo.GetNumSkillLines()
    Print("GetNumSkillLines = " .. Describe(n))
    n = Plain(n)
    if type(n) ~= "number" then return end
    for i = 1, n do
        local s = C_SkillInfo.GetSkillLineInfo(i)
        if type(s) == "table" then
            print(string.format("%2d id=%s name=%s hdr=%s cat=%s parent=%s %s/%s mod=%s",
                i, Describe(s.skillID), Describe(s.name), Describe(s.isHeader),
                Describe(s.skillLineCategoryID), Describe(s.parentSkillLineID),
                Describe(s.rank), Describe(s.maxRank), Describe(s.modifier)))
        else
            print(i, "nil")
        end
    end
end

local function ShowSettings()
    Print("Profile: " .. tostring(ns.CurrentProfile()))
    Print(string.format("weapons: red below %d%%, green within %d pts | professions: " ..
        (cfg.useTrainerReqs and "TRAIN by trainer reqs (else " or "(") ..
        "red at %d%% of trained cap), profession cap %d | scale %.2f | width %d (min %d) | bg %d%% | bars %d%% | font %s %d | title %s | grows " .. (cfg.growUp and "up" or "down"),
        cfg.weaponRedPct, cfg.weaponGreenPts, cfg.profWarnPct, cfg.profGameCap, cfg.scale,
        cfg.width, ns.MinWidth(), cfg.bgAlpha, cfg.barAlpha, cfg.font, cfg.fontSize,
        cfg.showTitle and "shown" or "hidden"))
end

-- Slash changes also update an open settings panel.
local function Changed()
    ApplyFrameSettings()
    Render()
    if ns.RefreshPanel then ns.RefreshPanel() end
end

local HELP = {
    "/sskw   open the settings panel",
    "/sskw show | hide | toggle",
    "/sskw lock | unlock | reset",
    "/sskw title   show/hide the title",
    "/sskw grow up | down   which way new rows extend the frame",
    "/sskw layout stacked | side | flipped   weapons above, beside, or right of professions",
    "/sskw weapon <redPct> <greenPts>   (default 75 5)",
    "/sskw prof <warnPct>   (default 90)",
    "/sskw cap <n>   profession skill cap (default 300)",
    "/sskw scale <0.5-2> | width <n> | fontsize <8-18>",
    "/sskw font <name> | fontinfo",
    "/sskw trainreqs   toggle TRAIN-by-trainer-requirements",
    "/sskw warn | pulse   toggle the low weapon skill warning / its pulse",
    "/sskw equipped | unarmed   only show equipped weapon skills / still show Unarmed",
    "/sskw charges   toggle thrown charges on the Thrown bar",
    "/sskw lowcharges [5-80]   toggle the low-charges alert, or set its %",
    "/sskw alerts [test]   toggle profession alerts (sound and message), or try them",
    "/sskw bg <0-100> | bars <0-100>   opacity % (default 35 / 70)",
    "/sskw ignore <skill name> | unignore <skill name>",
    "/sskw profile [name]   show profiles, or switch to one",
    "/sskw disarmlog   log what the game reports around disarms (this session)",
    "/sskw castlog [copy | clear]   log what the game reports while you craft or gather",
    "/sskw settings | rescan | events | debug | help",
}

SLASH_SIMPLESKILLWATCH1 = "/sskw"
SLASH_SIMPLESKILLWATCH2 = "/simpleskillwatch"
SlashCmdList.SIMPLESKILLWATCH = function(msg)
    if not cfg then return end
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    local a, b = rest:match("^(%S*)%s*(%S*)$")
    local n1, n2 = tonumber(a), tonumber(b)

    if cmd == "" or cmd == "config" or cmd == "options" then
        if ns.TogglePanel then ns.TogglePanel() end
    elseif cmd == "show" then
        cfg.shown = true; Changed()
    elseif cmd == "hide" then
        cfg.shown = false; Changed()
    elseif cmd == "toggle" then
        cfg.shown = not cfg.shown; Changed()
    elseif cmd == "warn" then
        cfg.lowSkillWarning = not cfg.lowSkillWarning; Changed()
        Print("Warn when weapon skill low: " .. (cfg.lowSkillWarning and "on" or "off"))
    elseif cmd == "pulse" then
        cfg.pulseWarning = not cfg.pulseWarning; Changed()
        Print("Pulse warning: " .. (cfg.pulseWarning and "on" or "off (steady border)"))
    elseif cmd == "equipped" then
        cfg.onlyEquipped = not cfg.onlyEquipped; Changed()
        Print("Only show equipped weapon: " .. (cfg.onlyEquipped and "on" or "off"))
    elseif cmd == "unarmed" then
        cfg.alsoUnarmed = not cfg.alsoUnarmed; Changed()
        Print("Still show Unarmed: " .. (cfg.alsoUnarmed and "on" or "off") .. (cfg.onlyEquipped and "" or " (applies with /sskw equipped)"))
    elseif cmd == "charges" then
        cfg.showThrownCharges = not cfg.showThrownCharges
        ns.InvalidateMinWidth(); Changed()
        Print("Show thrown charges: " .. (cfg.showThrownCharges and "on" or "off"))
    elseif cmd == "lowcharges" and n1 and n1 >= 5 and n1 <= 80 then
        cfg.lowChargesPct = n1; Changed()
        Print("Low charges alert below " .. n1 .. "% of max.")
    elseif cmd == "lowcharges" then
        cfg.alertLowCharges = not cfg.alertLowCharges; Changed()
        Print("Alert low charges: " .. (cfg.alertLowCharges and "on" or "off"))
    elseif cmd == "alerts" and a == "test" then
        ns.TestProfAlerts()
    elseif cmd == "alerts" then
        cfg.profAlerts = not cfg.profAlerts; Changed()
        Print("Profession alerts: " .. (cfg.profAlerts and "on" or "off"))
    elseif cmd == "trainreqs" then
        cfg.useTrainerReqs = not cfg.useTrainerReqs; Changed()
        Print("TRAIN by trainer requirements: " .. (cfg.useTrainerReqs and "on" or "off (using % of cap)"))
    elseif cmd == "layout" and (a == "stacked" or a == "side" or a == "flipped") then
        cfg.layout = a; Changed()
        Print("Layout: " .. (a == "stacked" and "stacked" or a == "side" and "side by side (weapons left)" or "side by side, flipped (professions left)") .. ".")
    elseif cmd == "grow" and (a == "up" or a == "down") then
        ns.SetGrowUp(a == "up"); Changed()
        Print("Frame grows " .. (cfg.growUp and "up" or "down") .. ".")
    elseif cmd == "title" then
        cfg.showTitle = not cfg.showTitle; Changed()
    elseif cmd == "lock" then
        ns.SetLocked(true); Print("Frame locked and click-through.")
    elseif cmd == "unlock" then
        ns.SetLocked(false); Print("Frame unlocked; drag to move, right-click for settings.")
    elseif cmd == "reset" then
        charDB.pos = nil; RestorePosition(); Print("Position reset.")
    elseif cmd == "weapon" and n1 and n2 then
        cfg.weaponRedPct, cfg.weaponGreenPts = n1, n2; Changed(); ShowSettings()
    elseif cmd == "prof" and n1 then
        cfg.profWarnPct = n1; Changed(); ShowSettings()
    elseif cmd == "cap" and n1 then
        cfg.profGameCap = n1; Changed(); ShowSettings()
    elseif cmd == "scale" and n1 and n1 >= 0.5 and n1 <= 2 then
        cfg.scale = n1; Changed(); ShowSettings()
    elseif cmd == "width" and n1 then
        cfg.width = math.max(ns.MinWidth(), math.min(n1, MAX_WIDTH)); Changed(); ShowSettings()
    elseif cmd == "font" and rest ~= "" then
        if ns.SetFontName(rest) then Print("Font: " .. cfg.font)
        else Print("No font named '" .. rest .. "'. The settings panel lists them.") end
    elseif cmd == "fontinfo" then
        FontInfo()
    elseif cmd == "fontsize" and n1 and n1 >= 8 and n1 <= 18 then
        cfg.fontSize = n1; ns.ApplyFonts(); Changed(); ShowSettings()
    elseif cmd == "bg" and n1 and n1 >= 0 and n1 <= 100 then
        cfg.bgAlpha = n1; Changed(); ShowSettings()
    elseif cmd == "bars" and n1 and n1 >= 0 and n1 <= 100 then
        cfg.barAlpha = n1; Changed(); ShowSettings()
    elseif cmd == "ignore" and rest ~= "" then
        local id, name = FindKnownByName(rest)
        if id then cfg.ignored[id] = true; Changed(); Print("Hiding " .. name .. ".")
        else Print("No known skill named '" .. rest .. "'.") end
    elseif cmd == "unignore" and rest ~= "" then
        local id, name = FindKnownByName(rest)
        if id then cfg.ignored[id] = nil; Changed(); Print("Showing " .. name .. " again.")
        else Print("No known skill named '" .. rest .. "'.") end
    elseif cmd == "profile" or cmd == "profiles" then
        if rest == "" then
            Print("Profile: " .. tostring(ns.CurrentProfile()) .. "  (all: " .. table.concat(ns.GetProfiles(), ", ") .. ")")
        else
            local match
            for _, name in ipairs(ns.GetProfiles()) do
                if name:lower() == rest:lower() then match = name break end
            end
            if match and ns.SetProfile(match) then Print("Switched to profile \"" .. match .. "\".")
            else Print("No profile named '" .. rest .. "'. Create one on the Profile tab (/sskw).") end
        end
    elseif cmd == "settings" then
        ShowSettings()
    elseif cmd == "rescan" then
        ns.Rescan(); Print("Rescanned skills.")
    elseif cmd == "events" then
        Print("Rescan triggers (registered? / times fired this session):")
        local list = { unpack(REFRESH_EVENTS) }
        list[#list + 1] = "PLAYER_EQUIPMENT_CHANGED"
        list[#list + 1] = "UPDATE_INVENTORY_DURABILITY"
        for _, ev in ipairs(DISARM_EVENT_ORDER) do list[#list + 1] = ev end
        for _, ev in ipairs(list) do
            print(string.format("  %-27s %s  %d", ev,
                eventStatus[ev] and "|cff40ff40yes|r" or "|cffff4040no|r", eventCounts[ev] or 0))
        end
        print(string.format("  Disarm detection: %s, disarms seen this session: %d",
            ns.DisarmDetectionAvailable() and "|cff40ff40available|r" or "|cffff4040not available|r", disarmSeen))
    elseif cmd == "disarmlog" then
        ns.ToggleDisarmLog()
    elseif cmd == "castlog" then
        if ns.CastLog then ns.CastLog(a) end
    elseif cmd == "debug" then
        DebugDump()
    else
        Print("v" .. ns.VERSION .. " commands:")
        for _, line in ipairs(HELP) do print("  " .. line) end
    end
end
