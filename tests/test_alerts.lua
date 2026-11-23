-- Profession alerts: sound, chat line and on-screen line at TRAIN and at the trained cap.
local M = dofile(TESTS_DIR .. "/wowmock.lua")
-- an older profile without the alert settings gets them from the defaults
M.savedVars({ profiles = { Warrior = { bgAlpha = 50 } } }, { profile = "Warrior", known = {} })
local ns = M.load(ADDON_DIR)
M.login()

local p = SimpleSkillWatchDB.profiles.Warrior
M.eq(p.profAlerts, true, "alerts on for an older profile")
M.eq(p.soundTrain, "Quest failed", "default TRAIN sound")
M.eq(p.soundCap, "Alarm clock 1", "default capped sound")
M.eq(p.alertScreenTime, 6, "default time on screen")

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
M.eq(M.onScreen(), "Skinning is at 69: you can train the next rank.", "TRAIN line on screen")
local line = SimpleSkillWatchAlertText
M.eq(line.hold.startDelay, 6, "stays for 6 seconds by default")
M.eq(table.concat(line.text.textColor, ","), "1,0.82,0", "TRAIN line is yellow")
M.eq(line.fade.playing, true, "its time is running")
M.screenTimeUp()
M.eq(M.onScreen(), nil, "gone when its time is up")

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
M.eq(last()[1], 12867, "capped sound is Alarm clock 1")
M.eq(M.chatCount("Skinning is stuck at 75/75 until you train the next rank."), 1, "capped chat line")
M.eq(M.onScreen(), "Skinning is stuck at 75/75 until you train the next rank.", "capped line replaces the TRAIN one")
M.eq(table.concat(line.text.textColor, ","), "1,0.25,0.25", "capped line is red")

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
M.screenTimeUp()
M.skillUp(197)
M.eq(#M.sounds, 6, "None is silent")
assert(M.onScreen(), "the message still shows")
NOW = NOW + 21
ns.cfg.soundTrain = "A SharedMedia sound that is gone"
M.skillUp(197)
M.eq(last()[1], 847, "a missing sound falls back to the default")

-- "Also show it on screen" off: chat only.
ns.cfg.alertOnScreen = false
M.screenTimeUp()
local chatLines = #M.chat
NOW = NOW + 21
M.skillUp(197)
M.eq(M.onScreen(), nil, "nothing on screen when that's off")
M.eq(#M.chat, chatLines + 1, "the chat line still prints")
ns.cfg.alertOnScreen = true

-- How long it stays is a setting.
M.slash("alerttime 12")
M.eq(ns.cfg.alertScreenTime, 12, "/sskw alerttime sets the seconds")
NOW = NOW + 21
M.skillUp(197)
M.eq(line.hold.startDelay, 12, "the next alert stays that long")
M.slash("alerttime 0")
M.eq(ns.cfg.alertScreenTime, 12, "out-of-range values are refused")

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
M.eq(last()[1], 12867, "test: then capped")

-- The sound list: None, then the game's sounds under a heading, alphabetical.
local function listed()
    local names = {}
    for _, s in ipairs(ns.GetSounds()) do names[#names + 1] = s.name or ("[" .. s.header .. "]") end
    return table.concat(names, ",")
end
local GAME = "None,[SimpleSkillWatch],Two notes,Three notes,Three notes (bell),Three notes (low),"
    .. "[Game sounds],Alarm clock 1,Alarm clock 2,Boss warning,Invite declined,Map ping,"
    .. "PvP queue,Quest failed,Raid warning,Ready check,Whisper"
M.eq(listed(), GAME, "own sounds, then game sounds alphabetical; no last heading without other addons' sounds")

-- The addon's own sounds play as files from its Sounds folder, and each file
-- named in the list is there and is an Ogg file.
ns.PlayAlertSound("Three notes")
M.eq(last()[1], "Interface\\AddOns\\SimpleSkillWatch\\Sounds\\ThreeNotes.ogg", "own sound plays its file")
M.eq(last()[2], "Master", "on the Master channel")
local own = 0
for _, s in ipairs(ns.GetSounds()) do
    local file = type(s.file) == "string" and s.file:match("\\Sounds\\(.+)$")
    if file then
        own = own + 1
        local f = assert(io.open(ADDON_DIR .. "/Sounds/" .. file, "rb"), file .. " is missing")
        M.eq(f:read(4), "OggS", file .. " is an Ogg file")
        f:close()
    end
end
M.eq(own, 4, "four own sounds")

-- SharedMedia sounds follow under their own heading, alphabetical whatever
-- their case, without a second None; they play as files.
LibStub = function() return {
    List = function() return { "Zap", "None", "popup", "Air Horn" } end,
    Fetch = function(_, _, name) return "Interface\\AddOns\\Media\\" .. name .. ".ogg" end,
} end
M.eq(listed(), GAME .. ",[From other addons],Air Horn,popup,Zap", "other addons' sounds under their own heading")
ns.PlayAlertSound("Zap")
M.eq(last()[1], "Interface\\AddOns\\Media\\Zap.ogg", "SharedMedia sound plays its file")
before = #M.sounds
M.eq(ns.PlayAlertSound(nil), false, "a heading is never mistaken for a sound")
M.eq(#M.sounds, before, "and nothing plays")
LibStub = nil

-- Settings window: the pickers show the chosen sounds; clicking a row in the
-- list plays it and chooses it; the list stays open.
M.slash("")
local trainBtn = M.findByText("Button", "Quest failed")
local capBtn = M.findByText("Button", "Alarm clock 1")
assert(trainBtn and capBtn, "both sound pickers show their sound")
capBtn.scripts.OnClick(capBtn)
local list = SimpleSkillWatchSoundList
M.eq(list.shown, true, "sound list opens")
-- it opens scrolled to the current sound; wheel up to the top of the list
list.scripts.OnMouseWheel(list, 1)
M.eq(list.buttons[1].text.text, "None", "wheel scrolls to the top")
-- the heading row is dimmed and can't be clicked or chosen
local heading = list.buttons[2]
M.eq(heading.text.text, "SimpleSkillWatch", "heading row in the list")
M.eq(heading.mouse, false, "heading takes no clicks")
M.eq(heading.rule.shown, true, "heading has its line")
M.eq(heading.check.shown, false, "heading is never ticked")
heading.scripts.OnClick(heading)
M.eq(ns.cfg.soundCap, "Alarm clock 1", "clicking a heading changes nothing")
M.eq(list.buttons[3].mouse, true, "sound rows take clicks")
M.eq(list.buttons[3].rule.shown, false, "sound rows have no line")
list.scripts.OnMouseWheel(list, -2)   -- wheel down to the end of the list
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

-- The speaker beside each picker plays that picker's sound without opening the list.
local speaker = capBtn.play
assert(speaker, "each picker has a speaker button")
before = #M.sounds
speaker.scripts.OnClick(speaker)
M.eq(#M.sounds, before + 1, "speaker plays a sound")
M.eq(last()[1], 8960, "the picker's own sound (Ready check)")
M.eq(list.shown, false, "without opening the list")
trainBtn.play.scripts.OnClick(trainBtn.play)
M.eq(last()[1], 847, "the other speaker plays the other sound")
M.eq(speaker.enabledV, true, "speaker usable while alerts are on")
-- nothing to play for "None", or while alerts are off
ns.cfg.soundCap = "None"; ns.RefreshPanel()
M.eq(speaker.enabledV, false, "speaker greyed out for None")
ns.cfg.soundCap = "Ready check"; ns.cfg.profAlerts = false; ns.RefreshPanel()
M.eq(speaker.enabledV, false, "speaker greyed out while alerts are off")
ns.cfg.profAlerts = true; ns.RefreshPanel()
M.eq(speaker.enabledV, true, "and usable again")

-- Defaults puts both sounds back.
ns.ResetDefaults()
M.eq(ns.cfg.soundCap, "Alarm clock 1", "Defaults restores the capped sound")
