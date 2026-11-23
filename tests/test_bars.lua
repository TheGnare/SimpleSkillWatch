-- Skill bars: values, modifiers and threshold colors with default settings.
local M = dofile(TESTS_DIR .. "/wowmock.lua")
local ns = M.load(ADDON_DIR)
M.login()

assert(M.optionsCategory and M.optionsCategory.name == "SimpleSkillWatch", "Options → AddOns entry registered")
assert(M.chat[1]:find("(v" .. ns.VERSION .. ") loaded", 1, true), "login message names the version")

local b = M.bars()
local TRAIN = "|cffffd100TRAIN|r "
local expect = {
    -- weapons: red below 75% of max, green within 5 points of max, yellow between
    Swords         = { "10/40|cff40ff40(+5)|r", "red" },
    Maces          = { "33/40|cffff4040(-2)|r", "yellow" },
    Defense        = { "37/40", "green" },
    -- professions: TRAIN once the next rank's skill requirement is met
    Skinning       = { TRAIN .. "68/75", "red" },      -- Journeyman at 50
    Leatherworking = { "21/75", "blue" },
    Tailoring      = { TRAIN .. "205/225", "red" },    -- Artisan at 200
    Cooking        = { TRAIN .. "130/150", "red" },    -- Expert at 125
    ["First Aid"]  = { "210/225", "blue" },            -- secondary Artisan at 225
    Fishing        = { "300/300", "gold" },            -- at the profession skill cap
}
for name, e in pairs(expect) do
    assert(b[name], name .. " bar missing")
    M.eq(b[name].value, e[1], name .. " value")
    M.eq(b[name].color, e[2], name .. " color")
end

-- A skill-up redraws the bar.
M.skill(43).rank = 38
M.refresh()
M.eq(M.bars().Swords.color, "green", "Swords after skill-up")
