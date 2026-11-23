-- Crafting while stuck at the trained cap: the capped alert repeats on every
-- craft that could have given a point, and only then.
local M = dofile(TESTS_DIR .. "/wowmock.lua")
local ns = M.load(ADDON_DIR)
M.login()

local CAPPED = "First Aid is stuck at 225/225 until you train the next rank."
local function last() return M.sounds[#M.sounds] or {} end

-- Below the cap a craft is silent (the skill-up itself does the alerting).
M.cast(3276)                          -- First Aid 210/225
M.eq(#M.sounds, 0, "no sound for a craft below the cap")

-- The craft that reaches the cap alerts once, through its skill-up.
M.skill(129).rank = 224; M.refresh()
M.cast(3276)
M.eq(#M.sounds, 0, "still below the cap when the cast finishes")
M.skillUp(129)                        -- 225/225
M.eq(#M.sounds, 1, "one alert on reaching the cap")
M.eq(last()[1], 8959, "the capped sound")

-- Every further craft of a recipe that isn't grey alerts again, with no gap.
M.cast(3276); M.cast(3276)
M.eq(#M.sounds, 3, "each craft at the cap alerts")
M.eq(M.chatCount(CAPPED), 3, "with its chat line")
M.eq(M.screen[#M.screen], CAPPED, "and its line on screen")

-- A grey recipe couldn't have given a point: silent.
M.cast(3275)
M.eq(#M.sounds, 3, "no sound for a grey recipe")

-- Opening the profession window is a cast too, but not a learned recipe.
M.cast(3274)
M.eq(#M.sounds, 3, "no sound for opening the profession window")

-- Other spells, other units' casts and hidden spell IDs (combat) are ignored.
M.cast(133)
M.event("UNIT_SPELLCAST_SUCCEEDED", "target", "Cast-3-2", 3276)
M.cast(M.SECRET)
M.eq(#M.sounds, 3, "no sound for unrelated casts")

-- Hidden professions, and alerts turned off, stay silent.
M.slash("ignore First Aid"); M.cast(3276)
M.eq(#M.sounds, 3, "no sound for a hidden profession")
M.slash("unignore First Aid")
M.slash("alerts"); M.cast(3276)
M.eq(#M.sounds, 3, "no sound while alerts are off")
M.slash("alerts")

-- A recipe whose difficulty the game hides still alerts (it might have given a point).
RECIPES[3276].info.relativeDifficulty = M.SECRET
M.cast(3276)
M.eq(#M.sounds, 4, "unknown difficulty still alerts")
RECIPES[3276].info.relativeDifficulty = 1

-- At the game's real cap there's nothing to train: silent.
M.slash("cap 225"); M.cast(3276)
M.eq(#M.sounds, 4, "no sound at the profession skill cap")
M.slash("cap 300")

-- Training the next rank ends it.
M.skill(129).maxRank = 300; M.refresh()
M.cast(3276)
M.eq(#M.sounds, 4, "no sound once the next rank is trained")

-- A client without the recipe lookups: nothing happens, no error.
M.skill(129).maxRank = 225; M.refresh()
C_TradeSkillUI = nil
M.cast(1234567)
M.eq(#M.sounds, 4, "no lookups, no alert")
