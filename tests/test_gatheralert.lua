-- Gathering while stuck at the trained cap: the capped alert repeats on every
-- gather unless the node's tooltip shows it as grey.
local M = dofile(TESTS_DIR .. "/wowmock.lua")
local ns = M.load(ADDON_DIR)
M.login()
M.addSkill(182, "Herbalism", 149, 150)
M.refresh()

local HERB = 2368
local GREY   = { { "Silverleaf", 1, 1, 1 }, { "Herbalism", 0.5, 0.5, 0.5 } }
local GREEN  = { { "Earthroot", 1, 1, 1 }, { "Herbalism", 0.25, 0.75, 0.25 } }
local YELLOW = { { "Mageroyal", 1, 1, 1 }, { "Herbalism", 1, 1, 0 } }

-- Below the cap gathering is silent; the gather that reaches the cap alerts
-- once, through its skill-up, even though the skill has already changed when
-- the cast is looked at.
M.tooltip(YELLOW)
M.gather(HERB)
M.eq(#M.sounds, 0, "no sound for a gather below the cap")
M.skill(182).rank = 150               -- the skill-up lands with the cast...
M.gather(HERB)
M.eq(#M.sounds, 0, "the cast that reaches the cap doesn't alert by itself")
M.refresh()                           -- ...and is seen on the rescan
M.eq(#M.sounds, 1, "one alert on reaching the cap")
M.eq(M.sounds[1][1], 12867, "the capped sound")

-- At the cap: yellow and green nodes alert, a grey one doesn't.
M.gather(HERB)
M.eq(#M.sounds, 2, "yellow node alerts")
M.tooltip(GREEN); M.gather(HERB)
M.eq(#M.sounds, 3, "green node alerts")
M.eq(M.chatCount("Herbalism is stuck at 150/150 until you train the next rank."), 3, "with its chat line")
M.tooltip(GREY); M.gather(HERB)
M.eq(#M.sounds, 3, "grey node is silent")

-- Another addon's color codes around the profession's name don't hide the line.
M.tooltip({ { "|cff808080Silverleaf (150/1)|r", 1, 1, 1 }, { "|cff808080Herbalism|r", 0.5, 0.5, 0.5 } })
M.gather(HERB)
M.eq(#M.sounds, 3, "grey node with color codes in its text is silent")

-- No tooltip, or one without the profession's line: can't tell, so it alerts.
M.tooltip(nil); M.gather(HERB)
M.eq(#M.sounds, 4, "no tooltip: alerts")
M.tooltip({ { "Some item", 1, 1, 1 }, { "Binds when picked up", 1, 1, 1 } }); M.gather(HERB)
M.eq(#M.sounds, 5, "unrelated tooltip: alerts")
M.tooltip({ { "Earthroot", 1, 1, 1 }, { "Herbalism", M.SECRET, M.SECRET, M.SECRET } }); M.gather(HERB)
M.eq(#M.sounds, 6, "hidden color: alerts")

-- The gathering spell finishing without a matching cast start (so not a
-- timed cast of ours) is ignored, and a grey reading doesn't carry over.
M.tooltip(GREY)
M.cast(HERB)
M.eq(#M.sounds, 6, "no alert without a cast start")
M.event("UNIT_SPELLCAST_START", "player", "Cast-3-900", HERB)   -- started on a grey node...
M.tooltip(YELLOW)
M.event("UNIT_SPELLCAST_START", "player", "Cast-3-901", HERB)   -- ...then a new cast on a yellow one
M.cast(HERB, "Cast-3-901")
M.eq(#M.sounds, 7, "each cast uses its own node's color")

-- Skinning: the corpse's "Skinnable" line carries the color.
UNIT_SKINNABLE_LEATHER = "Skinnable"
M.skill(393).rank = 75; M.refresh()   -- Skinning 75/75, reached by the edit: alerts once
local n = #M.sounds
M.tooltip({ { "Plainstrider", 1, 1, 1 }, { "Level 5 Beast", 1, 1, 1 }, { "Skinnable", 0.5, 0.5, 0.5 } })
M.gather(8613)
M.eq(#M.sounds, n, "grey skinnable corpse is silent")
M.tooltip({ { "Plainstrider", 1, 1, 1 }, { "Level 5 Beast", 1, 1, 1 }, { "Skinnable", 1, 0.5, 0.25 } })
M.gather(8613)
M.eq(#M.sounds, n + 1, "orange skinnable corpse alerts")

-- Hidden profession, alerts off, the game's real cap, and other casts: silent.
M.tooltip(YELLOW)
M.slash("ignore Herbalism"); M.gather(HERB)
M.slash("unignore Herbalism")
M.slash("alerts"); M.gather(HERB); M.slash("alerts")
M.slash("cap 150"); M.gather(HERB); M.slash("cap 300")
M.gather(133)
M.eq(#M.sounds, n + 1, "no sound when hidden, off, at the real cap, or for other spells")
