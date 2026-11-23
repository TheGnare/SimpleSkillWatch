-- Profession alerts: sound, chat line and on-screen line at TRAIN and at the trained cap.
local M = dofile(TESTS_DIR .. "/wowmock.lua")
-- an older profile without the alert settings gets them from the defaults
M.savedVars({ profiles = { Warrior = { bgAlpha = 50 } } }, { profile = "Warrior", known = {} })
local ns = M.load(ADDON_DIR)
M.login()

local p = SimpleSkillWatchDB.profiles.Warrior
M.eq(p.profAlerts, true, "alerts on for an older profile")
M.eq(p.soundTrain, "Quest failed", "default TRAIN sound")
M.eq(p.soundCap, "Raid warning", "default capped sound")

local function last() return M.sounds[#M.sounds] or {} end

-- Login alone is silent, even with professions already at TRAIN.
M.eq(#M.sounds, 0, "no sound at login")
M.refresh()
M.eq(#M.sounds, 0, "no sound on a rescan without a skill-up")

-- Below TRAIN: nothing.
M.skillUp(165)                       -- Leatherworking 21 -> 22 of 75
M.eq(#M.sounds, 0, "no sound below TRAIN")

-- A skill-up while at TRAIN: the milder sound, by SOUNDKIT name, on Master.
M.skillUp(393)                       -- Skinning 68 -> 69 of 75 (Journeyman at 50)
M.eq(#M.sounds, 1, "TRAIN sound played")
M.eq(last()[1], 847, "TRAIN sound is Quest failed")
M.eq(last()[2], "Master", "plays on the Master channel")
M.eq(M.chatCount("Skinning is at 69: you can train the next rank."), 1, "TRAIN chat line")
M.eq(M.screen[#M.screen], "Skinning is at 69: you can train the next rank.", "TRAIN line on screen")

-- More skill-ups within 20 seconds stay quiet; after that it alerts again.
M.skillUp(393)
M.eq(#M.sounds, 1, "TRAIN held back within 20 s")
NOW = NOW + 21
M.skillUp(393)                       -- 71
M.eq(#M.sounds, 2, "TRAIN again after 20 s")

-- The gap is per profession.
M.skillUp(185)                       -- Cooking 131 of 150 (Expert at 125)
M.eq(#M.sounds, 3, "another profession isn't held back")

-- Reaching the trained cap: the harsher sound, right away.
M.skillUp(393, 4)                    -- Skinning 75/75
M.eq(#M.sounds, 4, "capped sound played inside the TRAIN gap")
M.eq(last()[1], 8959, "capped sound is Raid warning")
M.eq(M.chatCount("Skinning is stuck at 75/75 until you train the next rank."), 1, "capped chat line")

-- The game's real cap never alerts.
M.skill(356).rank = 299; M.refresh()
M.skillUp(356)                       -- Fishing 300/300
M.eq(#M.sounds, 4, "no sound at the profession skill cap")

-- Weapons never alert.
M.skillUp(95, 3)                     -- Defense 40/40
M.eq(#M.sounds, 4, "no sound for weapon skills")

-- Hidden professions never alert.
M.slash("ignore Tailoring")
M.skillUp(197)
M.eq(#M.sounds, 4, "no sound for a hidden profession")
M.slash("unignore Tailoring")

-- Secret values (combat): nothing until the rank is readable again.
local tail = M.skill(197)
local real = tail.rank + 1
tail.rank = M.SECRET; M.refresh()
M.eq(#M.sounds, 4, "no sound while the rank is hidden")
tail.rank = real; M.refresh()
M.eq(#M.sounds, 5, "alert once the rank is readable")

-- A sound picked by its usual number when the client has no SOUNDKIT name for it,
-- "None" is silent but the message still shows, and a missing sound falls back.
NOW = NOW + 21
ns.cfg.soundTrain = "Ready check"
M.skillUp(197)
M.eq(last()[1], 8960, "sound without a SOUNDKIT name uses its number")
NOW = NOW + 21
ns.cfg.soundTrain = "None"
local lines = #M.screen
M.skillUp(197)
M.eq(#M.sounds, 6, "None is silent")
M.eq(#M.screen, lines + 1, "the message still shows")
NOW = NOW + 21
ns.cfg.soundTrain = "A SharedMedia sound that is gone"
M.skillUp(197)
M.eq(last()[1], 847, "a missing sound falls back to the default")

-- "Also show it on screen" off: chat only.
ns.cfg.alertOnScreen = false
lines = #M.screen
NOW = NOW + 21
M.skillUp(197)
M.eq(#M.screen, lines, "nothing on screen when that's off")
ns.cfg.alertOnScreen = true

-- /sskw alerts turns everything off; /sskw alerts test tries both.
M.slash("alerts")
M.eq(ns.cfg.profAlerts, false, "/sskw alerts toggles")
local before = #M.sounds
NOW = NOW + 21
M.skillUp(197)
M.eq(#M.sounds, before, "no sound while alerts are off")
M.slash("alerts")
ns.cfg.soundTrain = "Quest failed"
M.slash("alerts test")               -- M.slash runs the 2 s timer too
M.eq(#M.sounds, before + 2, "test plays both sounds")
M.eq(M.sounds[#M.sounds - 1][1], 847, "test: TRAIN first")
M.eq(last()[1], 8959, "test: then capped")

-- SharedMedia sounds are listed after the built-in ones and play as files.
LibStub = function() return {
    List = function() return { "Zap", "None", "Air Horn" } end,
    Fetch = function(_, _, name) return "Interface\\AddOns\\Media\\" .. name .. ".ogg" end,
} end
local names = {}
for _, s in ipairs(ns.GetSounds()) do names[#names + 1] = s.name end
M.eq(names[1], "None", "None first")
M.eq(names[2], "Raid warning", "built-in sounds next")
M.eq(names[#names - 1] .. "," .. names[#names], "Air Horn,Zap", "SharedMedia sounds last, sorted, no second None")
ns.PlayAlertSound("Zap")
M.eq(last()[1], "Interface\\AddOns\\Media\\Zap.ogg", "SharedMedia sound plays its file")
LibStub = nil

-- Settings window: the pickers show the chosen sounds; clicking a row in the
-- list plays it and chooses it; the list stays open.
M.slash("")
local trainBtn = M.findByText("Button", "Quest failed")
local capBtn = M.findByText("Button", "Raid warning")
assert(trainBtn and capBtn, "both sound pickers show their sound")
capBtn.scripts.OnClick(capBtn)
local list = SimpleSkillWatchSoundList
M.eq(list.shown, true, "sound list opens")
local row
for _, b in ipairs(list.buttons) do
    if b.shown and b.text.text == "Ready check" then row = b end
end
assert(row, "Ready check is in the list")
before = #M.sounds
row.scripts.OnClick(row)
M.eq(ns.cfg.soundCap, "Ready check", "clicking a row chooses the sound")
M.eq(#M.sounds, before + 1, "and plays it")
M.eq(capBtn.text, "Ready check", "picker shows the new sound")
M.eq(row.check.shown, true, "row is ticked")
M.eq(list.shown, true, "list stays open")
capBtn.scripts.OnClick(capBtn)
M.eq(list.shown, false, "picker button closes the list")

-- Defaults puts both sounds back.
ns.ResetDefaults()
M.eq(ns.cfg.soundCap, "Raid warning", "Defaults restores the capped sound")
