-- SimpleSkillWatch settings panel: its own movable window, so it can sit
-- wherever it's out of the way of the bars. Opened with /sskw, by
-- right-clicking the unlocked frame, or from Options > AddOns.

local ADDON, ns = ...

local PANEL_W = 580
local COL1_X, COL2_X = 16, 300
local SLIDER_W = 240     -- slider + revert button
local REVERT_W = 18

local panel          -- created on first open
local controls = {}  -- every control with a :Refresh()
local skillChecks = {}
local skillHeaders = {}
local refreshing = false

-- Blizzard's own UI sounds, by SOUNDKIT name (skipped if a name doesn't exist).
local function Sound(name)
    local kit = SOUNDKIT and SOUNDKIT[name]
    if kit and type(PlaySound) == "function" then PlaySound(kit) end
end

local function CheckSound(checked)
    Sound(checked and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
end

---------------------------------------------------------------------------
-- Widget builders (no Blizzard option templates, which vary between clients)
---------------------------------------------------------------------------

local function Header(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function NewCheck(parent)
    local c = CreateFrame("CheckButton", nil, parent)
    c:SetSize(22, 22)
    c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.label:SetPoint("LEFT", c, "RIGHT", 2, 1)
    return c
end

-- enabled(): optional; when it returns false the checkbox is greyed out and inert.
local function Check(parent, label, x, y, get, set, enabled)
    local c = NewCheck(parent)
    c:SetPoint("TOPLEFT", x, y)
    c.label:SetText(label)
    c:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        CheckSound(v)
        set(v)
    end)
    function c:Refresh()
        self:SetChecked(get() and true or false)
        if enabled then
            local on = enabled() and true or false
            self:SetEnabled(on)
            self:SetAlpha(on and 1 or 0.4)
        end
    end
    controls[#controls + 1] = c
    return c
end

-- Radio button: checked when isOn() is true; clicking calls choose().
-- Several radios with complementary isOn()s form one group.
local function Radio(parent, label, x, y, isOn, choose)
    local r = CreateFrame("CheckButton", nil, parent)
    r:SetSize(16, 16)
    r:SetPoint("TOPLEFT", x, y)
    -- UI-RadioButton is a strip of states: empty | dot | highlight | ...
    local RADIO = "Interface\\Buttons\\UI-RadioButton"
    local normal = r:CreateTexture(nil, "ARTWORK")
    normal:SetTexture(RADIO)
    normal:SetTexCoord(0, 0.25, 0, 1)
    r:SetNormalTexture(normal)
    local checked = r:CreateTexture(nil, "OVERLAY")
    checked:SetTexture(RADIO)
    checked:SetTexCoord(0.25, 0.5, 0, 1)
    r:SetCheckedTexture(checked)
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(RADIO)
    hl:SetTexCoord(0.5, 0.75, 0, 1)
    hl:SetBlendMode("ADD")
    r:SetHighlightTexture(hl)
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.label:SetPoint("LEFT", r, "RIGHT", 4, 0)
    r.label:SetText(label)
    r:SetScript("OnClick", function(self)
        self:SetChecked(true) -- a radio can't be unchecked by clicking it
        CheckSound(true)
        choose()
    end)
    function r:Refresh() self:SetChecked(isOn() and true or false) end
    controls[#controls + 1] = r
    return r
end

-- Counterclockwise "revert" arrow: a client atlas if one exists, else the
-- old equipment-manager undo icon.
local function SetRevertIcon(tex)
    if C_Texture and C_Texture.GetAtlasInfo then
        for _, atlas in ipairs({ "common-icon-undo", "transmog-icon-revert" }) do
            if C_Texture.GetAtlasInfo(atlas) then
                tex:SetAtlas(atlas)
                return
            end
        end
    end
    tex:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-Undo")
end

-- minV may be a number or a function (e.g. the measured minimum width).
-- default(): the slider value Defaults would give. fmt(value) -> display text.
-- enabled(): optional; when it returns false the slider is dimmed and inert.
local function Slider(parent, label, x, y, minV, maxV, step, get, set, fmt, default, enabled)
    local function MinV() return type(minV) == "function" and minV() or minV end

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", x, y)
    title:SetText(label)

    local trackW = SLIDER_W - REVERT_W - 6
    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + trackW, y)

    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(trackW, 16)
    s:SetPoint("TOPLEFT", x, y - 14)
    s:SetBackdrop({
        bgFile   = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(MinV(), maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouseWheel(true)

    local revert = CreateFrame("Button", nil, parent)
    revert:SetSize(REVERT_W, REVERT_W)
    revert:SetPoint("LEFT", s, "RIGHT", 6, 0)
    local icon = revert:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    SetRevertIcon(icon)
    revert:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    local function Snap(v)
        local lo = MinV()
        v = math.floor((v - lo) / step + 0.5) * step + lo
        if v < lo then v = lo elseif v > maxV then v = maxV end
        return v
    end

    local function DefaultValue()
        local d = default()
        local lo = MinV()
        if d < lo then d = lo elseif d > maxV then d = maxV end
        return d
    end

    local function UpdateRevert(v)
        local atDefault = (v == DefaultValue())
        revert:SetAlpha(atDefault and 0.3 or 1)
        revert:SetEnabled(not atDefault)
    end

    s:SetScript("OnValueChanged", function(self, v)
        v = Snap(v)
        valueText:SetText(fmt(v))
        UpdateRevert(v)
        if not refreshing then set(v) end
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(Snap(self:GetValue() + delta * step))
    end)

    revert:SetScript("OnClick", function() s:SetValue(DefaultValue()) end)
    revert:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset to default (" .. fmt(DefaultValue()) .. ")")
        GameTooltip:Show()
    end)
    revert:SetScript("OnLeave", function() GameTooltip:Hide() end)

    function s:Refresh()
        self:SetMinMaxValues(MinV(), maxV)
        local v = Snap(get())
        self:SetValue(v)
        valueText:SetText(fmt(v))
        UpdateRevert(v)
        if enabled then
            local on = enabled() and true or false
            local a = on and 1 or 0.35
            self:EnableMouse(on)
            self:EnableMouseWheel(on)
            self:SetAlpha(a)
            title:SetAlpha(a)
            valueText:SetAlpha(a)
            if not on then revert:SetAlpha(0.15); revert:SetEnabled(false) end
        end
    end
    controls[#controls + 1] = s
    return s
end

local function Button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function pct(v) return string.format("%d%%", v) end

---------------------------------------------------------------------------
-- Font list: our own scrolling list (Blizzard's menu ran the selection in a
-- protected call that swallowed errors). Each entry is drawn in its own font.
---------------------------------------------------------------------------

local FONT_ROWS, FONT_ROW_H, FONT_PREVIEW_SIZE = 14, 20, 13
local fontList

local function ChooseFont(name)
    if ns.SetFontName(name) then
        ns.Print("Font: " .. ns.cfg.font)
    end
end

-- A font file the client hasn't loaded yet draws blank on first use, and
-- re-applying the same font later is treated as "no change", so the row stays
-- blank (scrolling fixed it only because each row got a different font).
-- So after the list opens or scrolls, redraw the visible rows a few times,
-- each time switching the row to the default face and back to force a real
-- redraw. A new open/scroll cancels pending redraws (generation counter);
-- nothing runs while the list is closed.
local FONT_REDRAW_DELAYS = { 0.1, 0.3, 0.7, 1.5, 3.0 }
local UpdateFontList

local function ScheduleFontRedraws()
    fontList.redrawGen = (fontList.redrawGen or 0) + 1
    local gen = fontList.redrawGen
    for _, delay in ipairs(FONT_REDRAW_DELAYS) do
        C_Timer.After(delay, function()
            if fontList.redrawGen == gen and fontList:IsShown() then
                UpdateFontList(true)
            end
        end)
    end
end

function UpdateFontList(isRedraw)
    if not isRedraw then ScheduleFontRedraws() end
    local fonts = fontList.fonts
    local maxOffset = math.max(0, #fonts - FONT_ROWS)
    if fontList.offset > maxOffset then fontList.offset = maxOffset end
    if fontList.offset < 0 then fontList.offset = 0 end
    local defPath = (GameFontHighlight:GetFont())

    for i, b in ipairs(fontList.buttons) do
        local f = fonts[i + fontList.offset]
        if f then
            b.fontName = f.name
            -- default face first, so setting the row's own face is a real change
            ns.SetFontSafe(b.text, defPath, FONT_PREVIEW_SIZE, "")
            -- preview in its own face; fall back to the default face if it won't load
            if not ns.SetFontSafe(b.text, f.path or defPath, FONT_PREVIEW_SIZE, "") then
                ns.SetFontSafe(b.text, defPath, FONT_PREVIEW_SIZE, "")
            end
            b.text:SetText("") -- force a fresh layout in the new face
            b.text:SetText(f.name)
            b.check:SetShown(f.name == ns.cfg.font)
            b:Show()
        else
            b:Hide()
        end
    end

    local bar = fontList.scrollBar
    if maxOffset > 0 then
        fontList.updatingBar = true
        bar:SetMinMaxValues(0, maxOffset)
        bar:SetValue(fontList.offset)
        fontList.updatingBar = false
        bar:Show()
    else
        bar:Hide()
    end
end

local function BuildFontList(owner)
    fontList = CreateFrame("Frame", "SimpleSkillWatchFontList", panel, "BackdropTemplate")
    fontList:SetFrameStrata("FULLSCREEN_DIALOG")
    fontList:SetToplevel(true)
    fontList:SetClampedToScreen(true)
    fontList:SetSize(owner:GetWidth() + 24, FONT_ROWS * FONT_ROW_H + 12)
    fontList:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    fontList:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    fontList:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
    fontList:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
    fontList:EnableMouse(true)
    fontList:EnableMouseWheel(true)
    fontList.offset = 0
    fontList.redrawGen = 0
    fontList.buttons = {}

    for i = 1, FONT_ROWS do
        local b = CreateFrame("Button", nil, fontList)
        b:SetHeight(FONT_ROW_H)
        b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * FONT_ROW_H)
        b:SetPoint("RIGHT", -20, 0)
        b.check = b:CreateTexture(nil, "ARTWORK")
        b.check:SetSize(14, 14)
        b.check:SetPoint("LEFT", 2, 0)
        b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", 20, 0)
        b.text:SetPoint("RIGHT", -2, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b:SetScript("OnClick", function(self)
            ChooseFont(self.fontName)
            fontList:Hide()
        end)
        fontList.buttons[i] = b
    end

    local bar = CreateFrame("Slider", nil, fontList, "BackdropTemplate")
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(12)
    bar:SetPoint("TOPRIGHT", -5, -6)
    bar:SetPoint("BOTTOMRIGHT", -5, 6)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    bar:SetScript("OnValueChanged", function(_, v)
        if fontList.updatingBar then return end
        fontList.offset = math.floor(v + 0.5)
        UpdateFontList()
    end)
    fontList.scrollBar = bar

    fontList:SetScript("OnMouseWheel", function(_, delta)
        fontList.offset = fontList.offset - delta * 3
        UpdateFontList()
    end)

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "SimpleSkillWatchFontList")
    end
    panel:HookScript("OnHide", function() fontList:Hide() end)
    fontList:Hide()
end

local function ToggleFontList(owner)
    if not fontList then BuildFontList(owner) end
    if fontList:IsShown() then fontList:Hide() return end
    fontList.fonts = ns.GetFonts()
    -- start scrolled so the current font is visible
    for i, f in ipairs(fontList.fonts) do
        if f.name == ns.cfg.font then fontList.offset = i - math.floor(FONT_ROWS / 2) break end
    end
    fontList:Show()
    UpdateFontList()
end

---------------------------------------------------------------------------
-- Sound list: one list shared by the sound pickers on the Alerts tab.
-- Clicking a row plays the sound and chooses it; the list stays open so
-- several can be tried in a row (the picker button or Esc closes it).
---------------------------------------------------------------------------

local SOUND_ROWS, SOUND_ROW_H = 12, 18
local soundList

local function UpdateSoundList()
    local sounds = soundList.sounds
    local maxOffset = math.max(0, #sounds - SOUND_ROWS)
    if soundList.offset > maxOffset then soundList.offset = maxOffset end
    if soundList.offset < 0 then soundList.offset = 0 end
    local current = ns.cfg[soundList.key]

    for i, b in ipairs(soundList.buttons) do
        local snd = sounds[i + soundList.offset]
        if snd then
            b.soundName = snd.name
            b.text:SetText(snd.name)
            b.check:SetShown(snd.name == current)
            b:Show()
        else
            b:Hide()
        end
    end

    local bar = soundList.scrollBar
    if maxOffset > 0 then
        soundList.updatingBar = true
        bar:SetMinMaxValues(0, maxOffset)
        bar:SetValue(soundList.offset)
        soundList.updatingBar = false
        bar:Show()
    else
        bar:Hide()
    end
end

local function ChooseSound(key, name)
    ns.cfg[key] = name
    ns.PlayAlertSound(name)
    ns.RefreshPanel()
    if soundList and soundList:IsShown() then UpdateSoundList() end
end

local function BuildSoundList()
    soundList = CreateFrame("Frame", "SimpleSkillWatchSoundList", panel, "BackdropTemplate")
    soundList:SetFrameStrata("FULLSCREEN_DIALOG")
    soundList:SetToplevel(true)
    soundList:SetClampedToScreen(true)
    soundList:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    soundList:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
    soundList:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
    soundList:EnableMouse(true)
    soundList:EnableMouseWheel(true)
    soundList.key = ""
    soundList.offset = 0
    soundList.updatingBar = false
    soundList.sounds = {}
    soundList.buttons = {}

    for i = 1, SOUND_ROWS do
        local b = CreateFrame("Button", nil, soundList)
        b:SetHeight(SOUND_ROW_H)
        b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * SOUND_ROW_H)
        b:SetPoint("RIGHT", -20, 0)
        b.soundName = ""
        b.check = b:CreateTexture(nil, "ARTWORK")
        b.check:SetSize(14, 14)
        b.check:SetPoint("LEFT", 2, 0)
        b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", 20, 0)
        b.text:SetPoint("RIGHT", -2, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b:SetScript("OnClick", function(self) ChooseSound(soundList.key, self.soundName) end)
        soundList.buttons[i] = b
    end

    local bar = CreateFrame("Slider", nil, soundList, "BackdropTemplate")
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(12)
    bar:SetPoint("TOPRIGHT", -5, -6)
    bar:SetPoint("BOTTOMRIGHT", -5, 6)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
    bar:SetScript("OnValueChanged", function(_, v)
        if soundList.updatingBar then return end
        soundList.offset = math.floor(v + 0.5)
        UpdateSoundList()
    end)
    soundList.scrollBar = bar

    soundList:SetScript("OnMouseWheel", function(_, delta)
        soundList.offset = soundList.offset - delta * 3
        UpdateSoundList()
    end)

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "SimpleSkillWatchSoundList")
    end
    panel:HookScript("OnHide", function() soundList:Hide() end)
    soundList:Hide()
end

-- key: the setting this picker changes ("soundTrain" or "soundCap").
local function ToggleSoundList(owner, key)
    if not soundList then BuildSoundList() end
    if soundList:IsShown() and soundList.key == key then soundList:Hide() return end
    soundList.key = key
    soundList.sounds = ns.GetSounds()
    soundList.offset = 0
    -- start scrolled so the current sound is visible
    for i, snd in ipairs(soundList.sounds) do
        if snd.name == ns.cfg[key] then soundList.offset = i - math.floor(SOUND_ROWS / 2) break end
    end
    soundList:ClearAllPoints()
    soundList:SetSize(owner:GetWidth() + 24, SOUND_ROWS * SOUND_ROW_H + 12)
    soundList:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    soundList:Show()
    UpdateSoundList()
end

local function HideSoundList()
    if soundList then soundList:Hide() end
end

---------------------------------------------------------------------------
-- Panel: title, a row of tabs, the active tab's page, and a bottom row
-- (Reset position, Rescan, credit, Defaults) shared by every tab.
---------------------------------------------------------------------------

local TABS = { "Frame", "Text", "Skills", "Alerts", "Profile" }
local TAB_W, TAB_H, TAB_GAP = 100, 24, 4
local PAGE_TOP = -72          -- pages start below the title and tabs
local BOTTOM_ROW_H = 22 + 14  -- buttons + bottom margin

local pages, tabButtons = {}, {}
local pageBottom = {}         -- static pages' lowest y (Skills is measured live)

local function Changed()
    ns.ApplyFrameSettings()
    ns.Render()
end

-- Saved as the top-left corner, so switching to a taller or shorter tab
-- grows/shrinks the panel downward instead of shifting it.
local function SavePanelPosition()
    local left, top = panel:GetLeft(), panel:GetTop()
    if left and top then
        ns.db.panelPos = { "TOPLEFT", "BOTTOMLEFT", left, top }
    end
end

local function NewPage()
    local p = CreateFrame("Frame", nil, panel)
    p:SetPoint("TOPLEFT", 0, PAGE_TOP)
    p:SetPoint("RIGHT")
    p:SetHeight(1)
    p:Hide()
    return p
end

local function StyleTab(b, selected)
    if selected then
        b:SetBackdropColor(0.25, 0.2, 0.05, 0.95)
        b:SetBackdropBorderColor(1, 0.82, 0, 1)
        b.text:SetTextColor(1, 0.82, 0)
    else
        b:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        b:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
        b.text:SetTextColor(0.85, 0.85, 0.85)
    end
end

local SelectTab -- defined after the pages

local function BuildTabs()
    for i, name in ipairs(TABS) do
        local b = CreateFrame("Button", nil, panel, "BackdropTemplate")
        b:SetSize(TAB_W, TAB_H)
        b:SetPoint("TOPLEFT", 16 + (i - 1) * (TAB_W + TAB_GAP), -40)
        b:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.text:SetPoint("CENTER")
        b.text:SetText(name)
        b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
        b:SetScript("OnClick", function()
            if ns.db.panelTab ~= name then Sound("IG_CHARACTER_INFO_TAB") end
            SelectTab(name)
        end)
        tabButtons[name] = b
        StyleTab(b, false)
    end
end

-- Frame tab ---------------------------------------------------------------
local function BuildFramePage(cfg, D)
    local p = NewPage()
    local x, y = COL1_X, 0
    Check(p, "Show frame", x, y,
        function() return cfg.shown end,
        function(v) cfg.shown = v; Changed() end)
    y = y - 22
    Check(p, "Show title", x, y,
        function() return cfg.showTitle end,
        function(v) cfg.showTitle = v; Changed() end)
    y = y - 22
    Check(p, "Lock frame (click-through)", x, y,
        function() return ns.IsLocked() end,
        function(v) ns.SetLocked(v) end)
    y = y - 32

    -- Grow direction: two mutually exclusive radio buttons
    local growLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    growLabel:SetPoint("TOPLEFT", x, y)
    growLabel:SetText("Window grow direction")
    y = y - 16
    local function SetGrow(up)
        ns.SetGrowUp(up)
        Changed()
        ns.RefreshPanel()
    end
    local down = Radio(p, "Down", x + 4, y,
        function() return not cfg.growUp end, function() SetGrow(false) end)
    Radio(p, "Up", x + 4 + 90, y,
        function() return cfg.growUp end, function() SetGrow(true) end)
    down:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Window grow direction")
        GameTooltip:AddLine("Which way the frame extends when a new skill is learned or a section appears. Down keeps the top edge in place; Up keeps the bottom edge in place. Either way, the frame is pushed back on screen rather than running off an edge.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    down:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y = y - 30

    -- Layout: stacked, or Weapons and Professions side by side (either way round)
    local layoutLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    layoutLabel:SetPoint("TOPLEFT", x, y)
    layoutLabel:SetText("Layout")
    y = y - 16
    local function SetLayout(v)
        cfg.layout = v
        Changed()
        ns.RefreshPanel()
    end
    local stacked = Radio(p, "Stacked", x + 4, y,
        function() return cfg.layout ~= "side" and cfg.layout ~= "flipped" end,
        function() SetLayout("stacked") end)
    Radio(p, "Side by side", x + 4 + 80, y,
        function() return cfg.layout == "side" end,
        function() SetLayout("side") end)
    Radio(p, "Flipped", x + 4 + 186, y,
        function() return cfg.layout == "flipped" end,
        function() SetLayout("flipped") end)
    stacked:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Layout")
        GameTooltip:AddLine("Stacked: Weapons above Professions.", 1, 1, 1, true)
        GameTooltip:AddLine("Side by side: Weapons on the left, Professions (and Other) on the right.", 1, 1, 1, true)
        GameTooltip:AddLine("Flipped: the same, with Professions on the left.", 1, 1, 1, true)
        GameTooltip:AddLine("Width applies to each column.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    stacked:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y = y - 4

    local x2, y2 = COL2_X, 0
    Slider(p, "Scale", x2, y2, 50, 200, 5,
        function() return math.floor(cfg.scale * 100 + 0.5) end,
        function(v) cfg.scale = v / 100; Changed() end, pct,
        function() return math.floor(D.scale * 100 + 0.5) end)
    y2 = y2 - 40
    Slider(p, "Width", x2, y2, ns.MinWidth, ns.MAX_WIDTH, 5,
        function() return cfg.width end,
        function(v) cfg.width = v; Changed() end, tostring,
        function() return D.width end)
    y2 = y2 - 40
    Slider(p, "Background opacity", x2, y2, 0, 100, 5,
        function() return cfg.bgAlpha end,
        function(v) cfg.bgAlpha = v; Changed() end, pct,
        function() return D.bgAlpha end)
    y2 = y2 - 40
    Slider(p, "Bar opacity", x2, y2, 0, 100, 5,
        function() return cfg.barAlpha end,
        function(v) cfg.barAlpha = v; Changed() end, pct,
        function() return D.barAlpha end)
    y2 = y2 - 36

    pages.Frame = p
    pageBottom.Frame = math.min(y - 24, y2)
end

-- Text tab ----------------------------------------------------------------
local function BuildTextPage(cfg, D)
    local p = NewPage()
    local x, y = COL1_X, 0

    local fontLabel = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontLabel:SetPoint("TOPLEFT", x, y)
    fontLabel:SetText("Font")
    local fontBtn = Button(p, "", SLIDER_W - REVERT_W - 6, function(self) ToggleFontList(self) end)
    fontBtn:SetPoint("TOPLEFT", x, y - 14)
    function fontBtn:Refresh() self:SetText(cfg.font) end
    controls[#controls + 1] = fontBtn

    local fontRevert = CreateFrame("Button", nil, p)
    fontRevert:SetSize(REVERT_W, REVERT_W)
    fontRevert:SetPoint("LEFT", fontBtn, "RIGHT", 6, 0)
    local fri = fontRevert:CreateTexture(nil, "ARTWORK")
    fri:SetAllPoints()
    SetRevertIcon(fri)
    fontRevert:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    fontRevert:SetScript("OnClick", function() ChooseFont(D.font) end)
    fontRevert:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset to default (" .. D.font .. ")")
        GameTooltip:Show()
    end)
    fontRevert:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function fontRevert:Refresh()
        local atDefault = cfg.font == D.font
        self:SetAlpha(atDefault and 0.3 or 1)
        self:SetEnabled(not atDefault)
    end
    controls[#controls + 1] = fontRevert

    Slider(p, "Font size", COL2_X, y, 8, 18, 1,
        function() return cfg.fontSize end,
        function(v) cfg.fontSize = v; ns.ApplyFonts(); ns.RefreshPanel() end,
        tostring,
        function() return D.fontSize end)

    -- (the font list floats over everything, so no room is reserved for it)
    pages.Text = p
    pageBottom.Text = y - 44
end

-- Alerts tab --------------------------------------------------------------

-- A labelled button showing the chosen sound (opens the sound list), with a
-- revert arrow. key: the setting it changes. enabled(): as for Check.
local function SoundPicker(parent, label, x, y, key, enabled)
    local cfg, D = ns.cfg, ns.DEFAULTS
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", x, y)
    title:SetText(label)

    local btn = Button(parent, "", SLIDER_W - REVERT_W - 6 - 20, function(self) ToggleSoundList(self, key) end)
    btn:SetPoint("TOPLEFT", x, y - 14)
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label)
        GameTooltip:AddLine("Click a sound in the list to hear it and choose it. Click here again to close the list.", 1, 1, 1, true)
        GameTooltip:AddLine("Plays even with sound effects turned off.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local revert = CreateFrame("Button", nil, parent)
    revert:SetSize(REVERT_W, REVERT_W)
    revert:SetPoint("LEFT", btn, "RIGHT", 6, 0)
    local icon = revert:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    SetRevertIcon(icon)
    revert:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    revert:SetScript("OnClick", function() ChooseSound(key, D[key]) end)
    revert:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reset to default (" .. D[key] .. ")")
        GameTooltip:Show()
    end)
    revert:SetScript("OnLeave", function() GameTooltip:Hide() end)

    function btn:Refresh()
        self:SetText(cfg[key])
        local on = not enabled or (enabled() and true or false)
        local atDefault = cfg[key] == D[key]
        self:SetEnabled(on)
        self:SetAlpha(on and 1 or 0.4)
        title:SetAlpha(on and 1 or 0.4)
        revert:SetAlpha((not on) and 0.15 or atDefault and 0.3 or 1)
        revert:SetEnabled(on and not atDefault)
        if not on and soundList and soundList.key == key then soundList:Hide() end
    end
    controls[#controls + 1] = btn
    return btn
end

local function BuildAlertsPage(cfg, D)
    local p = NewPage()

    -- left column: weapons
    local x, y = COL1_X, 0
    Header(p, "Weapons, Defense & Other", x, y); y = y - 20
    local warnCheck = Check(p, "Warn when weapon skill low", x, y,
        function() return cfg.lowSkillWarning end,
        function(v) cfg.lowSkillWarning = v; Changed(); ns.RefreshPanel() end)
    warnCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Warn when weapon skill low")
        GameTooltip:AddLine("Red border on a weapon skill that's in the red while you have that weapon equipped (or Unarmed with nothing in your main hand).", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    warnCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y = y - 22
    Check(p, "Pulse warning", x + 20, y,
        function() return cfg.pulseWarning end,
        function(v) cfg.pulseWarning = v; Changed() end,
        function() return cfg.lowSkillWarning end)
    y = y - 28
    Slider(p, "Red below (% of max)", x, y, 50, 100, 1,
        function() return cfg.weaponRedPct end,
        function(v) cfg.weaponRedPct = v; Changed() end, pct,
        function() return D.weaponRedPct end)
    y = y - 40
    Slider(p, "Green within (points of max)", x, y, 0, 25, 1,
        function() return cfg.weaponGreenPts end,
        function(v) cfg.weaponGreenPts = v; Changed() end,
        function(v) return v .. " pts" end,
        function() return D.weaponGreenPts end)
    y = y - 46

    Header(p, "Thrown weapons", x, y); y = y - 20
    local chargesCheck = Check(p, "Show thrown charges/durability", x, y,
        function() return cfg.showThrownCharges end,
        function(v)
            cfg.showThrownCharges = v
            ns.InvalidateMinWidth()
            Changed()
            ns.RefreshPanel()
        end)
    chargesCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Thrown charges")
        GameTooltip:AddLine("Thrown weapons use durability as charges. With one equipped, the Thrown bar shows it after the name, e.g. \"Thrown (154/200)\".", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    chargesCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y = y - 22
    Check(p, "Alert low charges", x + 20, y,
        function() return cfg.alertLowCharges end,
        function(v) cfg.alertLowCharges = v; Changed(); ns.RefreshPanel() end,
        function() return cfg.showThrownCharges end)
    y = y - 30
    Slider(p, "Low charges below (% of max)", x + 20, y, 5, 80, 5,
        function() return cfg.lowChargesPct end,
        function(v) cfg.lowChargesPct = v; Changed() end, pct,
        function() return D.lowChargesPct end,
        function() return cfg.showThrownCharges and cfg.alertLowCharges end)
    y = y - 36

    -- right column: professions and their alerts
    local x2, y2 = COL2_X, 0
    Header(p, "Professions", x2, y2); y2 = y2 - 20
    local trainCheck = Check(p, "TRAIN when the next rank is trainable", x2, y2,
        function() return cfg.useTrainerReqs end,
        function(v) cfg.useTrainerReqs = v; Changed(); ns.RefreshPanel() end)
    trainCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Trainer requirements (skill only)")
        GameTooltip:AddLine("Journeyman: skill 50", 1, 1, 1)
        GameTooltip:AddLine("Expert: skill 125", 1, 1, 1)
        GameTooltip:AddLine("Artisan: skill 200 (Cooking, First Aid, Fishing: 225)", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    trainCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y2 = y2 - 28
    Slider(p, "Otherwise TRAIN at (% of trained cap)", x2, y2, 50, 100, 1,
        function() return cfg.profWarnPct end,
        function(v) cfg.profWarnPct = v; Changed() end, pct,
        function() return D.profWarnPct end,
        function() return not cfg.useTrainerReqs end)
    y2 = y2 - 40
    Slider(p, "Profession skill cap", x2, y2, 75, 450, 5,
        function() return cfg.profGameCap end,
        function(v) cfg.profGameCap = v; Changed() end, tostring,
        function() return D.profGameCap end)
    y2 = y2 - 40

    local alertCheck = Check(p, "Alert when a profession needs training", x2, y2,
        function() return cfg.profAlerts end,
        function(v) cfg.profAlerts = v; ns.RefreshPanel() end)
    alertCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Profession alerts")
        GameTooltip:AddLine("Plays a sound and prints a line in chat when a skill-up leaves a profession at TRAIN, and again when it is stuck at its trained cap. While it's stuck, every craft or gather that could have given a point alerts again.", 1, 1, 1, true)
        GameTooltip:AddLine("At TRAIN, at most once every 20 seconds per profession. Never at the profession skill cap, and never for hidden skills.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    alertCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    y2 = y2 - 26
    local function AlertsOn() return cfg.profAlerts end
    SoundPicker(p, "Sound at TRAIN", x2 + 20, y2, "soundTrain", AlertsOn)
    y2 = y2 - 42
    SoundPicker(p, "Sound when stuck at the trained cap", x2 + 20, y2, "soundCap", AlertsOn)
    y2 = y2 - 40
    Check(p, "Also show it on screen", x2 + 20, y2,
        function() return cfg.alertOnScreen end,
        function(v) cfg.alertOnScreen = v; ns.RefreshPanel() end,
        AlertsOn)
    y2 = y2 - 28
    Slider(p, "Stays on screen for", x2 + 20, y2, 1, 30, 1,
        function() return cfg.alertScreenTime end,
        function(v) cfg.alertScreenTime = v end,
        function(v) return v .. " sec" end,
        function() return D.alertScreenTime end,
        function() return cfg.profAlerts and cfg.alertOnScreen end)
    y2 = y2 - 36

    pages.Alerts = p
    pageBottom.Alerts = math.min(y, y2)
end

-- Skills tab: weapons in the left column, professions and other on the right.
local SKILLS_LIST_TOP = -70 -- the skill columns start below the two options

local function BuildSkillsPage()
    local cfg = ns.cfg
    local p = NewPage()
    p.hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.hint:SetPoint("TOPLEFT", COL1_X, 0)
    p.hint:SetPoint("RIGHT", -16, 0)
    p.hint:SetJustifyH("LEFT")

    local onlyCheck = Check(p, "Only show equipped weapon", COL1_X, -18,
        function() return cfg.onlyEquipped end,
        function(v) cfg.onlyEquipped = v; ns.Render(); ns.RefreshPanel() end)
    onlyCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Only show equipped weapon")
        GameTooltip:AddLine("Shows only the weapon skills you have equipped (main hand, off hand, ranged), plus Defense. An empty main hand counts as Unarmed. Updates as you swap weapons.", 1, 1, 1, true)
        GameTooltip:AddLine("While this is on, the weapon checkboxes below don't apply; your choices come back when you turn it off.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    onlyCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Check(p, "Still show Unarmed", COL1_X + 20, -40,
        function() return cfg.alsoUnarmed end,
        function(v) cfg.alsoUnarmed = v; ns.Render(); ns.RefreshPanel() end,
        function() return cfg.onlyEquipped end)

    pages.Skills = p
end

local KIND_TITLES = { weapon = "Weapons", prof = "Professions", other = "Other" }
local KIND_COLUMN = { weapon = 1, prof = 2, other = 2 }

local function LayoutSkills()
    local cfg, p = ns.cfg, pages.Skills
    local list = ns.GetKnownSkills()
    local colX = { COL1_X, COL2_X }
    local colY = { SKILLS_LIST_TOP, SKILLS_LIST_TOP }
    local ci, hi = 0, 0
    local lastKind

    for _, s in ipairs(list) do
        local col = KIND_COLUMN[s.kind] or 2
        if s.kind ~= lastKind then
            lastKind = s.kind
            hi = hi + 1
            local h = skillHeaders[hi]
            if not h then
                h = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                skillHeaders[hi] = h
            end
            -- a second group in the same column gets a little space above it
            if colY[col] < SKILLS_LIST_TOP then colY[col] = colY[col] - 8 end
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", colX[col], colY[col] - 4)
            h:SetText(KIND_TITLES[s.kind] or s.kind)
            h:Show()
            colY[col] = colY[col] - 22
        end
        ci = ci + 1
        local c = skillChecks[ci]
        if not c then
            c = NewCheck(p)
            c:SetScript("OnClick", function(self)
                CheckSound(self:GetChecked())
                if self:GetChecked() then cfg.ignored[self.skillID] = nil
                else cfg.ignored[self.skillID] = true end
                ns.Render()
            end)
            skillChecks[ci] = c
        end
        c.skillID = s.id
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", colX[col] + 4, colY[col])
        c.label:SetText(s.name)
        c:SetChecked(not cfg.ignored[s.id])
        -- greyed out while "Only show equipped weapon" decides this skill
        local controlled = ns.EquipFilterControls(s.id, s.kind)
        c:SetEnabled(not controlled)
        c:SetAlpha(controlled and 0.4 or 1)
        c:Show()
        colY[col] = colY[col] - 20
    end
    for i = ci + 1, #skillChecks do skillChecks[i]:Hide() end
    for i = hi + 1, #skillHeaders do skillHeaders[i]:Hide() end

    if ci == 0 then
        p.hint:SetText("No skills seen yet. Open the Skills tab (C) with every group expanded.")
    else
        p.hint:SetText("Uncheck a skill to hide it from the frame.")
    end
    return math.min(colY[1], colY[2]) - 4
end

-- Size the panel to the active page and park the bottom row under it.
local LayoutProfiles -- Profile tab, defined with its page below

local function LayoutPanel()
    local tab = ns.db.panelTab
    local bottom
    if tab == "Skills" then
        bottom = LayoutSkills()
    elseif tab == "Profile" and LayoutProfiles then
        bottom = LayoutProfiles()
    else
        bottom = pageBottom[tab] or -200
    end
    local y = PAGE_TOP + bottom - 10

    panel.resetPos:ClearAllPoints()
    panel.resetPos:SetPoint("TOPLEFT", COL1_X, y)
    panel.rescan:ClearAllPoints()
    panel.rescan:SetPoint("LEFT", panel.resetPos, "RIGHT", 8, 0)
    panel.defaults:ClearAllPoints()
    panel.defaults:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, y)

    panel:SetHeight(-y + BOTTOM_ROW_H)
end

function SelectTab(name)
    if not pages[name] then name = TABS[1] end
    ns.db.panelTab = name
    if fontList then fontList:Hide() end
    HideSoundList()
    for tabName, page in pairs(pages) do
        page:SetShown(tabName == name)
        StyleTab(tabButtons[tabName], tabName == name)
    end
    ns.RefreshPanel()
end

-- Small yes/no dialog centered on the settings window. Built here rather
-- than with Blizzard's StaticPopup, which is shared with protected game
-- dialogs that addon popups can upset.
local confirm

local function ShowConfirm(question, detail, okText, onOK)
    if not confirm then
        confirm = CreateFrame("Frame", "SimpleSkillWatchConfirm", panel, "BackdropTemplate")
        confirm:SetSize(320, 110)
        confirm:SetPoint("CENTER", panel, "CENTER")
        confirm:SetFrameStrata("FULLSCREEN_DIALOG")
        confirm:SetToplevel(true)
        confirm:EnableMouse(true) -- swallow clicks so the panel behind can't be used
        confirm:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        confirm:SetBackdropColor(0, 0, 0, 0.97)
        confirm:SetBackdropBorderColor(1, 0.82, 0, 1)

        confirm.question = confirm:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        confirm.question:SetPoint("TOP", 0, -16)
        confirm.question:SetWidth(290)
        confirm.detail = confirm:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        confirm.detail:SetPoint("TOP", confirm.question, "BOTTOM", 0, -6)
        confirm.detail:SetWidth(290)

        confirm.ok = Button(confirm, "", 100, function()
            local fn = confirm.onOK
            confirm:Hide()
            if fn then fn() end
        end)
        confirm.ok:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 14)
        confirm.cancel = Button(confirm, "Cancel", 100, function() confirm:Hide() end)
        confirm.cancel:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 6, 14)

        -- Esc cancels; closing the settings window cancels too
        if type(UISpecialFrames) == "table" then
            table.insert(UISpecialFrames, "SimpleSkillWatchConfirm")
        end
        panel:HookScript("OnHide", function() confirm:Hide() end)

        -- Dimmed cover over the whole settings window while the dialog is up:
        -- swallows clicks, drags and the mouse wheel so only the dialog works.
        local cover = CreateFrame("Frame", nil, panel)
        cover:SetAllPoints(panel)
        cover:SetFrameStrata("DIALOG")
        cover:SetFrameLevel(panel:GetFrameLevel() + 100)
        cover:EnableMouse(true)
        cover:EnableMouseWheel(true)
        cover:SetScript("OnMouseWheel", function() end)
        local shade = cover:CreateTexture(nil, "BACKGROUND")
        shade:SetAllPoints()
        shade:SetColorTexture(0, 0, 0, 0.5)
        cover:Hide()
        confirm.cover = cover

        confirm:Hide()
        confirm:SetScript("OnShow", function() Sound("IG_MAINMENU_OPEN") end)
        confirm:SetScript("OnHide", function()
            cover:Hide()
            Sound("IG_MAINMENU_CLOSE")
        end)
    end
    if fontList then fontList:Hide() end
    HideSoundList()
    confirm.question:SetText(question)
    confirm.detail:SetText(detail or "")
    confirm.ok:SetText(okText or "OK")
    confirm.onOK = onOK
    confirm.cover:Show()
    confirm:Show()
end

-- Profile tab ---------------------------------------------------------------
-- A radio list of profiles (click one to switch this character to it), with
-- Copy and Delete on every other row, then "Save as new profile".
local profileRows = {}

local function SuggestProfileName()
    local className = ns.ClassProfileName()
    if className and not ns.ProfileExists(className) then return className end
    local charName = UnitName and UnitName("player")
    if type(charName) == "string" and not ns.ProfileExists(charName) then return charName end
    return ""
end

local function SaveNewProfile()
    local p = pages.Profile
    local name = (p.nameBox:GetText() or ""):match("^%s*(.-)%s*$")
    if name == "" then
        ns.Print("Type a name for the new profile first.")
        return
    end
    if ns.ProfileExists(name) then
        ns.Print("A profile named \"" .. name .. "\" already exists. Click it in the list to switch to it.")
        return
    end
    p.nameBox:ClearFocus()
    p.nameBox.userEdited = false
    ns.SaveProfileAs(name)
    ns.Print("Saved the current settings as profile \"" .. name .. "\" and switched to it.")
end

local function BuildProfilePage()
    local p = NewPage()

    local intro = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", COL1_X, 0)
    intro:SetPoint("RIGHT", -16, 0)
    intro:SetJustifyH("LEFT")
    intro:SetText("Click a profile to use it on this character. Profiles hold every setting and the hidden skills; frame position and learned skills stay per character.")

    p.listHeader = Header(p, "Profiles", COL1_X, -34)

    -- Save as new profile
    p.saveHeader = Header(p, "Save as new profile", COL1_X, 0)
    local box = CreateFrame("EditBox", nil, p, "BackdropTemplate")
    box:SetSize(230, 22)
    box:SetAutoFocus(false)
    box:SetMaxLetters(32)
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", SaveNewProfile)
    box.userEdited = false -- true once the player types; until then we suggest a name
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self.userEdited = true end
    end)
    p.nameBox = box
    p.saveButton = Button(p, "Save", 80, SaveNewProfile)
    p.saveHint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.saveHint:SetText("Saves a copy of the current settings under this name and switches to it.")

    pages.Profile = p
end

local function ProfileRow(i)
    local row = profileRows[i]
    if row then return row end
    local p = pages.Profile
    row = {}
    row.radio = Radio(p, "", COL1_X + 4, 0,
        function() return row.name == ns.CurrentProfile() end,
        function()
            if row.name ~= ns.CurrentProfile() then
                ns.SetProfile(row.name)
                ns.Print("Switched to profile \"" .. row.name .. "\".")
            end
        end)
    row.copy = Button(p, "Copy into current", 130, function()
        local current = tostring(ns.CurrentProfile())
        ShowConfirm(
            "Copy \"" .. row.name .. "\" into \"" .. current .. "\"?",
            "This replaces \"" .. current .. "\"'s settings and hidden skills.",
            "Copy",
            function()
                ns.CopyProfileIntoCurrent(row.name)
                ns.Print("Copied \"" .. row.name .. "\" into \"" .. current .. "\".")
            end)
    end)
    row.delete = Button(p, "Delete", 80, function()
        ShowConfirm(
            "Delete profile \"" .. row.name .. "\"?",
            "This can't be undone. Characters using it switch to their class profile at their next login.",
            "Delete",
            function()
                if ns.DeleteProfile(row.name) then
                    ns.Print("Deleted profile \"" .. row.name .. "\".")
                    ns.RefreshPanel()
                end
            end)
    end)
    profileRows[i] = row
    return row
end

LayoutProfiles = function()
    local p = pages.Profile
    local current = ns.CurrentProfile()
    local y = -56
    local names = ns.GetProfiles()

    for i, name in ipairs(names) do
        local row = ProfileRow(i)
        row.name = name
        local isCurrent = (name == current)
        row.radio:ClearAllPoints()
        row.radio:SetPoint("TOPLEFT", COL1_X + 4, y - 3)
        row.radio.label:SetText(isCurrent and (name .. "  |cff999999(this character)|r") or name)
        row.radio:SetChecked(isCurrent)
        row.radio:Show()
        row.copy:ClearAllPoints()
        row.copy:SetPoint("TOPLEFT", COL2_X + 40, y)
        row.delete:ClearAllPoints()
        row.delete:SetPoint("LEFT", row.copy, "RIGHT", 8, 0)
        row.copy:SetShown(not isCurrent)
        row.delete:SetShown(not isCurrent)
        y = y - 26
    end
    for i = #names + 1, #profileRows do
        local row = profileRows[i]
        row.radio:Hide(); row.copy:Hide(); row.delete:Hide()
    end

    y = y - 12
    p.saveHeader:ClearAllPoints()
    p.saveHeader:SetPoint("TOPLEFT", COL1_X, y)
    y = y - 22
    p.nameBox:ClearAllPoints()
    p.nameBox:SetPoint("TOPLEFT", COL1_X, y)
    p.saveButton:ClearAllPoints()
    p.saveButton:SetPoint("LEFT", p.nameBox, "RIGHT", 8, 0)
    if not p.nameBox:HasFocus() and not p.nameBox.userEdited then
        p.nameBox:SetText(SuggestProfileName())
    end
    y = y - 28
    p.saveHint:ClearAllPoints()
    p.saveHint:SetPoint("TOPLEFT", COL1_X, y)
    return y - 14
end

local function BuildPanel()
    local cfg, D = ns.cfg, ns.DEFAULTS

    panel = CreateFrame("Frame", "SimpleSkillWatchSettings", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, 400)
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    if panel.SetDontSavePosition then panel:SetDontSavePosition(true) end
    panel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.92)
    panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePanelPosition()
    end)
    panel:Hide()
    -- sounds hooked after the initial Hide so building the panel is silent
    panel:SetScript("OnShow", function() Sound("IG_MAINMENU_OPEN") end)
    panel:SetScript("OnHide", function() Sound("IG_MAINMENU_CLOSE") end)

    -- Esc closes it
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "SimpleSkillWatchSettings")
    end

    panel:ClearAllPoints()
    local p = ns.db.panelPos
    if p and p[1] == "TOPLEFT" then
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[3], p[4])
    else
        -- first open (or a position saved by an older version): centered, top-anchored
        panel:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("SimpleSkillWatch")
    local ver = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 6, -1)
    ver:SetText("v" .. ns.VERSION .. "  (drag to move)")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    BuildTabs()
    BuildFramePage(cfg, D)
    BuildTextPage(cfg, D)
    BuildSkillsPage()
    BuildAlertsPage(cfg, D)
    BuildProfilePage()

    -- Bottom row, shared by every tab --------------------------------------
    panel.resetPos = Button(panel, "Reset position", 120, function()
        ns.charDB.pos = nil
        ns.RestorePosition()
    end)
    panel.rescan = Button(panel, "Rescan skills", 120, function()
        ns.Rescan()
    end)
    panel.defaults = Button(panel, "Defaults", 100, function()
        local profile = tostring(ns.CurrentProfile())
        ShowConfirm(
            "Reset profile \"" .. profile .. "\" to defaults?",
            "Your frame position and hidden skills are kept.",
            "Reset",
            function()
                ns.ResetDefaults()
                ns.RefreshPanel()
                ns.Print("Profile \"" .. profile .. "\" reset to defaults (position and hidden skills kept).")
            end)
    end)

    -- Credit, centered between Rescan and Defaults (anchors follow the buttons).
    -- 14pt: between the section headers (~12) and the panel title (~16).
    local credit = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local cPath, cSize, cFlags
    if GameFontNormal and GameFontNormal.GetFont then cPath, cSize, cFlags = GameFontNormal:GetFont() end
    if cPath then ns.SetFontSafe(credit, cPath, math.floor((cSize or 12) + 2.5), cFlags) end
    credit:SetTextColor(0.6, 0.6, 0.6)
    credit:SetPoint("LEFT", panel.rescan, "RIGHT", 4, 0)
    credit:SetPoint("RIGHT", panel.defaults, "LEFT", -4, 0)
    credit:SetJustifyH("CENTER")
    credit:SetText("by |cff4d5fffGnare|r")
end

function ns.RefreshPanel()
    if not panel or not panel:IsShown() then return end
    refreshing = true
    for _, c in ipairs(controls) do c:Refresh() end
    refreshing = false
    LayoutPanel()
end

function ns.OpenPanel()
    if not ns.cfg then return end
    if not panel then BuildPanel() end
    panel:Show()
    SelectTab(ns.db.panelTab or TABS[1])
end

function ns.TogglePanel()
    if panel and panel:IsShown() then
        panel:Hide()
    else
        ns.OpenPanel()
    end
end

---------------------------------------------------------------------------
-- Options > AddOns > SimpleSkillWatch: a page with a button that opens the panel
---------------------------------------------------------------------------

function ns.InitSettings()
    if type(Settings) ~= "table"
        or type(Settings.RegisterCanvasLayoutCategory) ~= "function"
        or type(Settings.RegisterAddOnCategory) ~= "function" then
        return
    end

    local canvas = CreateFrame("Frame")
    canvas:Hide() -- must start hidden or the page draws empty the first time

    local t = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("SimpleSkillWatch")

    local d = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    d:SetWidth(500)
    d:SetJustifyH("LEFT")
    d:SetText("SimpleSkillWatch's settings live in their own movable window, so you can park it next to your bars while you adjust them. The button below closes this Options window and opens it. You can also open it with /sskw, or by right-clicking the frame while it's unlocked.")

    local b = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    b:SetSize(240, 24)
    b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
    b:SetText("Open SimpleSkillWatch Settings")
    -- Pop out: close Blizzard's Options window first (so it's not in the way,
    -- and closing it later can't take ours with it), then open ours a frame
    -- later, once that close has finished. In combat, just open ours on top.
    b:SetScript("OnClick", function()
        local inCombat = InCombatLockdown and InCombatLockdown()
        if not inCombat and SettingsPanel and SettingsPanel:IsShown() then
            if type(HideUIPanel) == "function" then
                HideUIPanel(SettingsPanel)
            else
                SettingsPanel:Hide()
            end
        end
        C_Timer.After(0, ns.OpenPanel)
    end)

    pcall(function()
        local category = Settings.RegisterCanvasLayoutCategory(canvas, "SimpleSkillWatch")
        Settings.RegisterAddOnCategory(category)
    end)
end
