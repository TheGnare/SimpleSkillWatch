-- Minimap button and the addon list icon.
local M = dofile(TESTS_DIR .. "/wowmock.lua")
local ns = M.load(ADDON_DIR)
M.login()

-- The icon: named in the .toc, and a 64x64 32-bit uncompressed TGA on disk.
local toc = assert(io.open(ADDON_DIR .. "/SimpleSkillWatch.toc")):read("*a")
assert(toc:find("## IconTexture: Interface\\AddOns\\SimpleSkillWatch\\icon.tga", 1, true), ".toc names the icon")
local head = assert(io.open(ADDON_DIR .. "/icon.tga", "rb"), "icon.tga exists"):read(18)
M.eq(head:byte(3), 2, "icon is an uncompressed true-color TGA")
M.eq(head:byte(13) + head:byte(14) * 256, 64, "icon width")
M.eq(head:byte(15) + head:byte(16) * 256, 64, "icon height")
M.eq(head:byte(17), 32, "icon has an alpha channel")

-- Shown by default, with the addon's icon, at its default place on the edge.
local b = SimpleSkillWatchMinimapButton
assert(b and b.shown, "minimap button shown by default")
M.eq(b.icon.texPath, "Interface\\AddOns\\SimpleSkillWatch\\icon", "uses the addon's icon")
local function place() return math.floor(b.lastPoint[4] + 0.5), math.floor(b.lastPoint[5] + 0.5) end
local x, y = place()
M.eq(x .. "," .. y, "-61,-43", "default place: lower left of the minimap's edge")
M.eq(b.lastPoint[2], Minimap, "anchored to the minimap")

-- Left-click opens and closes the settings window.
b.scripts.OnClick(b, "LeftButton")
M.eq(SimpleSkillWatchSettings.shown, true, "left-click opens the settings")
b.scripts.OnClick(b, "LeftButton")
M.eq(SimpleSkillWatchSettings.shown, false, "left-click again closes them")

-- Right-click hides and shows the frame.
b.scripts.OnClick(b, "RightButton")
M.eq(ns.cfg.shown, false, "right-click hides the frame")
M.eq(M.mainFrame().shown, false, "frame hidden")
b.scripts.OnClick(b, "RightButton")
M.eq(M.mainFrame().shown, true, "right-click again shows it")

-- Dragging follows the cursor around the edge, only while dragging.
M.eq(b.scripts.OnUpdate, nil, "no per-frame work when not dragging")
b.scripts.OnDragStart(b)
CURSOR = { 600, 500 }; b.scripts.OnUpdate(b)
x, y = place(); M.eq(x .. "," .. y, "75,0", "cursor to the right: button on the right edge")
CURSOR = { 500, 900 }; b.scripts.OnUpdate(b)
x, y = place(); M.eq(x .. "," .. y, "0,75", "cursor above: button on the top edge")
b.scripts.OnDragStop(b)
M.eq(b.scripts.OnUpdate, nil, "per-frame work stops with the drag")
M.eq(SimpleSkillWatchCharDB.minimapAngle, 90, "its place is saved for this character")

-- Minimap shape: an addon that reshapes the minimap says so through
-- GetMinimapShape(). On a square edge the button follows the straight sides
-- and can go out into the corner; round corners stay round.
local function at(angle)
    SimpleSkillWatchCharDB.minimapAngle = angle
    M.slash("title"); M.slash("title")   -- any settings change re-places the button
    local px, py = place()
    return px .. "," .. py
end
M.eq(at(20), "70,26", "round: on the circle")
GetMinimapShape = function() return "SQUARE" end
M.eq(at(20), "75,33", "square: on the right edge")
M.eq(at(45), "68,68", "square: out in the corner")
M.eq(at(180), "-75,0", "square: middle of the left edge")
GetMinimapShape = function() return "CORNER-TOPLEFT" end   -- only the top-left corner is round
M.eq(at(135), "-53,53", "round corner: on the circle")
M.eq(at(45), "68,68", "its square corners: out in the corner")
GetMinimapShape = function() return "SOMETHING-NEW" end
M.eq(at(20), "70,26", "unknown shape: treated as round")
GetMinimapShape = function() error("broken") end
M.eq(at(20), "70,26", "a failing shape function: treated as round")
GetMinimapShape = nil
M.eq(at(90), "0,75", "no shape function: round")

-- /sskw minimap and the settings checkbox hide and show it, keeping its place.
M.slash("minimap")
M.eq(ns.cfg.minimapButton, false, "/sskw minimap turns it off")
M.eq(b.shown, false, "button hidden")
M.slash("")
local check = M.findByText("CheckButton", "Show minimap button")
assert(check, "checkbox on the Frame tab")
M.eq(check.checked, false, "checkbox follows the setting")
check.checked = true; check.scripts.OnClick(check)
M.eq(b.shown, true, "checkbox shows it again")
x, y = place(); M.eq(x .. "," .. y, "0,75", "at the place it was dragged to")

-- Saved as hidden: the button isn't even built. Its saved place is used once shown.
SimpleSkillWatchMinimapButton = nil
M = dofile(TESTS_DIR .. "/wowmock.lua")
M.savedVars({ profiles = { Warrior = { minimapButton = false } } },
    { profile = "Warrior", known = {}, minimapAngle = 0 })
ns = M.load(ADDON_DIR); M.login()
M.eq(SimpleSkillWatchMinimapButton, nil, "not built while turned off")
M.slash("minimap")
b = SimpleSkillWatchMinimapButton
assert(b and b.shown, "built when turned on")
x, y = place(); M.eq(x .. "," .. y, "75,0", "at this character's saved place")

-- An older profile without the setting gets the button.
SimpleSkillWatchMinimapButton = nil
M = dofile(TESTS_DIR .. "/wowmock.lua")
M.savedVars({ profiles = { Warrior = { bgAlpha = 50 } } }, { profile = "Warrior", known = {} })
M.load(ADDON_DIR); M.login()
M.eq(SimpleSkillWatchDB.profiles.Warrior.minimapButton, true, "older profiles get the button")
assert(SimpleSkillWatchMinimapButton and SimpleSkillWatchMinimapButton.shown, "and it shows")
