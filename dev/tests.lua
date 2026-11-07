-- BiSTheme / dev / tests.lua -- headless checks for the palette and the BiS> prompt
--   cd BiSTheme && lua5.1 dev/tests.lua
local now = 1000
_G.GetTime = function() return now end
_G.STANDARD_TEXT_FONT = "font"
_G.RAID_CLASS_COLORS = { SHAMAN = { r = 0, g = 0.44, b = 0.87 } }

local parent
local function FontString()
  local s = { alpha = 1 }
  function s:GetParent() return parent end
  function s:SetPoint(...) self.point = { ... } end
  function s:SetAlpha(a) self.alpha = a end
  function s:GetAlpha() return self.alpha or 1 end
  function s:SetFont(_, size) self.size = size end
  function s:SetText(x) self.text = x end
  function s:GetText() return self.text end
  function s:SetTextColor(r, g, b, a) self.color = { r, g, b, a } end
  function s:GetStringWidth()
    local t, tex = tostring(self.text or ""), 0
    t = t:gsub("|T[^|]-:(%d+):%d+[^|]*|t", function(w) tex = tex + tonumber(w) return "" end)
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return #t * (self.size or 9) * 0.6 + tex
  end
  return s
end
parent = { CreateFontString = function() return FontString() end }
-- A FRAME LISTENS. The stub had three backdrop methods and nothing else, so a library that wants
-- to hear PLAYER_LOGIN - which is the only moment EllesmereUI can be asked for anything - could
-- not be written without the file failing to load. It records what it was asked to listen for,
-- and dev/tests can fire it.
local LOADED_FRAMES = {}
_G.CreateFrame = function()
  local f = {
    SetBackdrop = function() end, SetBackdropColor = function() end,
    SetBackdropBorderColor = function() end,
    _events = {}, _scripts = {},
  }
  function f:RegisterEvent(e) self._events[e] = true end
  function f:UnregisterEvent(e) self._events[e] = nil end
  function f:SetScript(k, fn) self._scripts[k] = fn end
  function f:GetScript(k) return self._scripts[k] end
  LOADED_FRAMES[#LOADED_FRAMES + 1] = f
  return f
end
local function fireEvent(event, ...)
  for _, f in ipairs(LOADED_FRAMES) do
    if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
  end
end

local n, fails = 0, 0
local function ok(c, msg, ...)
  n = n + 1
  if c then return end
  fails = fails + 1
  print("FAIL: " .. msg, ...)
end
local function plain(c) return (tostring(c:Text()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- move the clock and let a fade finish: dt, then the two fade legs
local function adv(c, dt) now = now + dt c:Paint() now = now + 0.3 c:Paint() now = now + 0.3 c:Paint() end

-- 1. embedded copy alone: the palette fallback stands in
assert(loadfile("Console.lua"))()
local T = BiSTheme
ok(T.CONSOLE_MINOR == 5 and T.rgb and T.text, "Console.lua alone brings a palette fallback (minor 5)")
local r, g, b = T.rgb("accent")
ok(math.abs(r - 0xb9 / 255) < 1e-6, "fallback accent is the BiS purple")

-- 2. the real BiSTheme.lua after it: same palette, its own helpers win
BiSTheme = nil
assert(loadfile("BiSTheme.lua"))()
assert(loadfile("Console.lua"))()
T = BiSTheme
ok(T.skin and T.pctColor and T.classRGB, "BiSTheme.lua helpers present")
ok(T.CONSOLE and T.Console and T.Fit, "console API present")
local minor = T.CONSOLE_MINOR
T.CONSOLE.cycle = 99
assert(loadfile("Console.lua"))()
ok(T.CONSOLE_MINOR == minor and T.CONSOLE.cycle == 99, "loading the same minor again is a no-op (guard)")
T.CONSOLE.cycle = 3
ok(select(1, T.classRGB("SHAMAN")) == 0, "classRGB reads Blizzard's table")

-- 3. Fit
local fs = FontString() fs:SetFont(nil, 8)
ok(T.Fit(fs, "short", 100) == "short", "Fit leaves a fitting label alone")
local t = T.Fit(fs, "a label far too long for its little box", 40)
ok(t:find("%.%.%.$") and fs:GetStringWidth() <= 40, "Fit trims with an ellipsis until it fits", t)

-- 3b. A FRAME'S PAINT IS NEARLY FREE (7 Oct 2026, the cost pass). Three windows paint the prompt
-- every frame; each paint set the words and measured them, and an overflowing line was trimmed a
-- character at a time - a SetText and a measure each. A second of frames with nothing new to say
-- must not touch the words at all.
do
  local hd = FontString() hd:SetFont(nil, 8)
  local c = T.Console(hd, { width = 60 })
  c:Set("k", "a line much too long for a sixty pixel prompt", "ink")
  for _ = 1, 10 do now = now + 0.1 c:Paint() end         -- faded in, trimmed once
  local sets, measures = 0, 0
  local realSet, realW = c.words.SetText, c.words.GetStringWidth
  c.words.SetText = function(s, x) sets = sets + 1 return realSet(s, x) end
  c.words.GetStringWidth = function(s) measures = measures + 1 return realW(s) end
  -- the family's counter (_bisdev/dev/cost.lua) holds the client side of the same second: the
  -- clock, once a paint, and nothing else
  local Cost = dofile("../_bisdev/dev/cost.lua")
  local asked, by = Cost.Count(function()
    for _ = 1, 60 do now = now + 1 / 60 c:Paint() end
  end)
  ok(asked <= 60, "a second of prompt paints asks the client one thing a frame at most: " .. asked,
     Cost.Top(by, 3))
  c.words.SetText, c.words.GetStringWidth = realSet, realW
  ok(sets == 0 and measures == 0, "sixty frames with the same words set and measure nothing",
     sets .. " sets, " .. measures .. " measures")
  c:Set("k", "short", "good")
  for _ = 1, 10 do now = now + 0.1 c:Paint() end
  ok(plain(c):find("short", 1, true), "and new words still arrive", plain(c))
end

-- 4. the prompt: slots rotate, events jump in and hold, cursor blinks, width kept,
--    words fade out and in (Arn: "fade in and out animations, not hard cuts")
local title = FontString() title:SetFont(nil, 8)
local con = T.Console(title, { width = 106 })
ok(con.words and con.words.point[2] == title, "the words are their own FontString, anchored to the title")
ok(plain(con):find("^BiS> [_ ]$"), "empty prompt is BiS> and the cursor", plain(con))
con:Set("name", "Summon", "accent")
ok(con.fading == "out" and not plain(con):find("Summon", 1, true), "new words: the old ones fade out first, no hard cut")
now = now + 0.1 con:Paint()
ok(con.words.alpha > 0 and con.words.alpha < 1, "alpha on the way down", con.words.alpha)
now = now + 0.2 con:Paint()
ok(con.words.alpha == 0 and con.fading == "in" and plain(con):find("Summon", 1, true), "at zero the words swap and start coming up")
now = now + 0.1 con:Paint()
ok(con.words.alpha > 0 and con.words.alpha < 1, "alpha on the way up", con.words.alpha)
now = now + 0.2 con:Paint()
ok(con.words.alpha == 1 and not con.fading, "solid")
ok(plain(con):find("^BiS> Summon[_ ]$"), "one slot shows at once", plain(con))
ok(title:GetText() == T.text("accent", "BiS> "), "the prompt itself never changes")
con:Set("stone", "2 at stone", "good")
now = now + 0.6 con:Paint()
ok(plain(con):find("Summon", 1, true), "a new slot waits its turn")
adv(con, 3)
ok(plain(con):find("2 at stone", 1, true), "after a cycle the next slot", plain(con))
adv(con, 3)
ok(plain(con):find("Summon", 1, true), "round again", plain(con))
con:Set("stone", nil)
adv(con, 3)
ok(plain(con):find("Summon", 1, true), "a cleared slot leaves the rotation", plain(con))
-- the order quirk (minor 3): clear + set again must not append the key twice. With two
-- live slots the rotation is exactly Summon, stone, Summon, stone - a duplicate key would
-- show stone twice in a row and stretch #order every toggle.
for _ = 1, 5 do con:Set("stone", nil) con:Set("stone", "2 at stone", "good") end
ok(#con.order == 2, "toggling a slot five times leaves order at 2 keys", #con.order)
local seen = {}
for _ = 1, 4 do adv(con, 3) seen[#seen + 1] = plain(con):find("Summon", 1, true) and "S" or "T" end
ok(table.concat(seen) == "STST" or table.concat(seen) == "TSTS", "and the rotation alternates, no slot hogs it", table.concat(seen))
con:Set("stone", nil)
adv(con, 3)
con:Say("Druid asks", "gold")
adv(con, 0)
ok(plain(con):find("Druid asks", 1, true) and con.line.colour == "gold", "Say jumps in, keeps its colour")
con:Say("Druid accepted", "good")
ok(plain(con):find("Druid asks", 1, true) and #con.queue == 1, "a second Say queues")
adv(con, 3)
ok(plain(con):find("Druid accepted", 1, true), "shows after the hold")
adv(con, 3)
ok(plain(con):find("Summon", 1, true), "then the slots resume")
now = now + 0.5 con:Paint() local c1 = plain(con):sub(-1)
now = now + 0.5 con:Paint() local c2 = plain(con):sub(-1)
ok((c1 == "_" and c2 == " ") or (c1 == " " and c2 == "_"), "cursor blinks at 2 Hz", c1, c2)
-- minor 4: the blink is the cursor's OWN FontString going to alpha 0; the words
-- text is identical in both phases and never carries the "_" -- a swap inside
-- the words moved them a hair on the client every half second
now = now + 0.5 con:Paint() local w1, a1 = con.words:GetText(), con.cur:GetAlpha()
now = now + 0.5 con:Paint() local w2, a2 = con.words:GetText(), con.cur:GetAlpha()
ok(w1 == w2 and not w1:find("_", 1, true), "the words never change between blink phases", w1, w2)
ok((a1 == 0 and a2 == 1) or (a1 == 1 and a2 == 0), "the cursor FontString blinks by alpha", a1, a2)
ok(con.cur:GetText():find("_", 1, true) ~= nil, "the cursor FontString holds the underscore")
con:Say("Averyveryverylongname accepted the summon")
adv(con, 0)
ok(con:Width() <= 106 and plain(con):find("%.%.%.[_ ]$"), "a long line is trimmed and the cursor survives", plain(con))
ok(con.words:GetText():find("|cff", 1, true) and select(2, con.words:GetText():gsub("|r", "")) == 1, "colour escapes stay whole after the trim")
con:Clear() adv(con, 3)
ok(#con.queue == 0 and plain(con):find("Summon", 1, true), "Clear drops the queue")

-- 5. the minimap button, and the menu that replaced twenty-five slash commands.
--    A suite cannot see a button. It CAN see where the button put itself, which rows a click
--    would show, and whether picking one ran the right function - which is every bug this kind
--    of code has.
do
  local function auto(t)
    return setmetatable(t, { __index = function(_, k)
      if type(k) == "string" and k:match("^%u") then return function() end end
      return nil
    end })
  end
  local function Texture()
    return auto({ shown = true,
      SetColorTexture = function(s, r, g, b, a) s.colour = { r, g, b, a } end,
      SetTexture = function(s, t) s.file = t end,
      Show = function(s) s.shown = true end, Hide = function(s) s.shown = false end,
      IsShown = function(s) return s.shown end })
  end
  local function Frame(kind, name, par)
    local f
    f = auto({ __kind = kind, __name = name, parent = par, points = {}, scripts = {},
               shown = false, enabled = true, w = 0, h = 0,
      CreateTexture = function() return Texture() end,
      CreateFontString = function()
        local s = FontString()
        s.shown = true
        s.Show = function(x) x.shown = true end
        s.Hide = function(x) x.shown = false end
        s.IsShown = function(x) return x.shown end
        return s
      end,
      SetScript = function(s, k, fn) s.scripts[k] = fn end,
      GetScript = function(s, k) return s.scripts[k] end,
      SetPoint = function(s, ...) s.points[#s.points + 1] = { ... } end,
      ClearAllPoints = function(s) s.points = {} end,
      SetSize = function(s, w, h) s.w, s.h = w, h end,
      GetWidth = function(s) return s.w end,
      SetHeight = function(s, h) s.h = h end,
      GetCenter = function(s) return 200, 200 end,
      GetFrameLevel = function() return 2 end,
      Show = function(s) s.shown = true end,
      Hide = function(s)
        s.shown = false
        if s.scripts.OnHide then s.scripts.OnHide(s) end
      end,
      IsShown = function(s) return s.shown end,
      Enable = function(s) s.enabled = true end,
      Disable = function(s) s.enabled = false end,
      Click = function(s, button)
        if s.scripts.OnClick then s.scripts.OnClick(s, button or "LeftButton") end
      end })
    return f
  end
  _G.CreateFrame = function(kind, name, par) return Frame(kind, name, par) end
  _G.Minimap = Frame("Frame", "Minimap")
  _G.Minimap.w = 192            -- NOT the 140 px every minimap button assumes (see Radius)
  _G.UIParent = Frame("Frame", "UIParent")
  _G.UIParent.w = 1024
  _G.UIParent.GetEffectiveScale = function() return 1 end
  _G.GetCursorPosition = function() return 240, 240 end

  assert(loadfile("Minimap.lua"))()
  ok(T.MINIMAP_MINOR == 4 and T.Minimap and T.MinimapItems, "Minimap.lua loads and exports")

  -- the rows: a note and a tick that are FUNCTIONS are asked when the menu opens, not when the
  -- addon loaded - the whole reason a menu can replace a command that printed the answer
  local locked, ran = false, {}
  local spec = function() return {
    { text = "options",     func = function() ran.options = true end },
    { sep = true },
    { text = "lock frames", checked = function() return locked end,
      note = function() return locked and "on" or "off" end,
      func = function() locked = not locked end },
    { text = "not yet", disabled = true },
  } end
  local rows = T.MinimapItems(spec)
  ok(#rows == 4 and rows[2].sep, "the spec resolves to rows, separators and all")
  ok(rows[3].checked == false and rows[3].note == "off", "a live note is asked now, and says off")
  locked = true
  ok(T.MinimapItems(spec)[3].note == "on", "and says on the next time the menu opens")
  locked = false
  ok(#T.MinimapItems(nil) == 0 and #T.MinimapItems(function() error("nope") end) == 0,
     "a missing or throwing menu is an empty menu, not an error at the minimap")

  -- the button
  local db = {}
  local b = T.Minimap("Test", { label = "Healing", db = db, menu = spec,
                                onRight = function() ran.options2 = true end })
  ok(b ~= nil, "the button is built")
  local pt = b.points[#b.points]
  -- The ring is MEASURED off this minimap, not assumed to be the usual 80: a client with a wider
  -- minimap put the button inside the map, where every other addon's button sat on the edge.
  local radius = 192 / 2 + T.MINIMAP.OVER
  ok(b:Radius() == radius, "the ring is measured off the minimap, not hard-coded", b:Radius())
  ok(radius > T.MINIMAP.RADIUS, "which on a wide minimap is further out than the old 80")
  local want = radius * math.cos(math.rad(T.MINIMAP.ANGLE))
  ok(pt and pt[1] == "CENTER" and math.abs(pt[4] - want) < 0.01,
     "a fresh install puts it at the default angle on the minimap's edge")
  _G.Minimap.w = 0
  ok(b:Radius() == T.MINIMAP.RADIUS, "and a minimap that cannot say how wide it is falls back")
  _G.Minimap.w = 192

  -- dragging writes the angle into the addon's db, so a reload finds it again
  b.Follow(b)
  ok(type(db.angle) == "number" and math.abs(db.angle - 45) < 0.01,
     "dragging it writes the angle to the db", tostring(db.angle))
  ok(b:Refresh() == true, "and it is shown by default")
  b:SetHidden(true)
  ok(db.hide == true and b:IsShown() == false, "SetHidden hides it AND remembers")
  b:SetHidden(false)

  -- HOVERING IT. Two lines of script nothing had ever run: going round dropped the square face's
  -- border and both of them still reached for it, so the button threw twice a second under the
  -- cursor. A frame's scripts are code, and code a suite never calls is code nobody has read.
  ok(pcall(b.scripts.OnEnter, b), "hovering the button does not throw")
  ok(pcall(b.scripts.OnLeave, b), "and neither does leaving it")
  ok(b.ring ~= nil and b.icon ~= nil, "it wears the ring and an icon")

  -- the menu
  local menu = b:OpenMenu()
  ok(menu:IsShown() and menu.count == 4, "left-clicking opens a menu with every row")
  ok(menu.width >= T.MINIMAP.MIN_W and menu.width <= T.MINIMAP.MAX_W,
     "sized to its longest row, within the clamp", menu.width)
  ok(menu.rows[2].enabled == false and menu.rows[4].enabled == false,
     "a separator and a disabled row cannot be clicked")
  menu.rows[3]:Click()
  ok(locked == true, "clicking a row runs what the slash command ran")
  ok(menu:IsShown() == false, "and the menu closes behind it")
  ok(menu.catcher:IsShown() == false, "with the click-catcher going away too")

  -- reopened, the same row now says what changed
  b:OpenMenu()
  ok(menu.rows[3].note:GetText() == "on" and menu.rows[3].tick:IsShown(),
     "reopening shows the new state, ticked")
  ok(b:ToggleMenu() == false and menu:IsShown() == false, "clicking the button again shuts it")

  -- a row that throws must not take the client down with it
  b.opts.menu = { { text = "boom", func = function() error("kaboom") end } }
  local m2 = b:OpenMenu()
  ok(pcall(function() m2.rows[1]:Click() end), "a row that throws is caught, not raised")
  b.opts.menu = spec

  -- A COLLECTOR'S BACKING LIFTED OVER THE ICON goes back under it after a click (EllesmereUI:
  -- its click hook raises every child of the button to DIALOG; Arn, 14 Oct: "the minimap icon
  -- still go dim when i click them")
  local backing = { level = 99, strata = "DIALOG" }
  function backing:SetFrameLevel(n) self.level = n end
  function backing:SetFrameStrata(s) self.strata = s end
  local keepTimer = _G.C_Timer
  _G.C_Timer = { After = function(_, fn) fn() end }
  b.GetChildren = function() return backing end
  b.GetFrameLevel = function() return 8 end
  b.GetFrameStrata = function() return "MEDIUM" end
  b:Click("LeftButton")
  ok(backing.level == 7 and backing.strata == "MEDIUM", "after a click, a backing lifted over the icon goes back below the button")
  b:ToggleMenu()
  b.GetChildren, b.GetFrameLevel, b.GetFrameStrata, _G.C_Timer = nil, nil, nil, keepTimer

  -- right-click is the options window, without going through the menu
  b:Click("RightButton")
  ok(ran.options2 == true, "right-clicking runs the options window directly")
  ok(menu:IsShown() == false, "and does not leave the menu open behind it")

  -- ONE STANDARD (minor 4; Arn, 7 Nov: "sometimes left click does one thing, sometimes right click does another"):
  -- left = the main window when the addon has one, right = its page under BiS> in the game's options
  b.opts.onLeft, b.opts.leftLabel = function() ran.window = true end, "the frames"
  b:Click("LeftButton")
  ok(ran.window == true and menu:IsShown() == false, "left-click opens the addon's main window, not the menu")
  local keepPages, keepOpen = T.settingsPages, T.OpenSettings
  local openedFor
  T.settingsPages = { Test = { category = {} } }
  T.OpenSettings = function(a) openedFor = a return true end
  ran.options2 = nil
  b:Click("RightButton")
  ok(openedFor == "Test" and ran.options2 == nil, "right-click opens its page in the game's options when it has one")
  T.OpenSettings = function() return false end
  b:Click("RightButton")
  ok(ran.options2 == true, "and its own options window when the game's panel will not open")
  T.settingsPages, T.OpenSettings = keepPages, keepOpen
  b.opts.onLeft, b.opts.leftLabel = nil, nil
end

-- ------------------------------------------------------------------------------------------
-- HARMONISING WITH EllesmereUI. Arn installed it (28 Sep 2026) and asked what it takes to match.
-- We take two things through their documented getters - the accent the user chose, and the UI
-- font - and hand over no frames at all, because S.Shell would alpha out this window's own
-- background and borders and leave its rows untouched.
--
-- THE FAKE IS SHAPED LIKE THEIRS: RegisterSkin takes a name and a callback, refuses a second
-- registration under the same name, hands the callback a facade, and dispatches at PLAYER_LOGIN.
do
  local ownAccent = T.hex.accent
  local registered, fired, listeners = {}, 0, {}
  local accent = { 0.2, 0.8, 0.4 }                       -- a green user, deliberately not ours
  _G.EllesmereUI = {
    RegisterSkin = function(name, fn)
      if registered[name] then return end                 -- first registration wins, as theirs does
      registered[name] = fn
      return true
    end,
  }
  local function dispatch()
    for _, fn in pairs(registered) do
      fired = fired + 1
      fn({
        apiVersion = 1,
        GetAccentColor = function() return accent[1], accent[2], accent[3] end,
        GetFont = function() return "Interface\AddOns\EllesmereUI\media\font.ttf", "" end,
        OnLooksChanged = function(fn2) listeners[#listeners + 1] = fn2 end,
        IsEnabled = function() return true end,
      })
    end
  end

  ok(T.AdoptEllesmereUI() == true, "BiSTheme registers with EllesmereUI when it is there")
  ok(T.hex.accent == ownAccent, "and changes nothing until the callback runs")
  dispatch()
  ok(fired == 1, "the callback runs once")
  -- PURPLE BY DEFAULT, EllesmereUI's ON REQUEST (Arn, 16 Oct 2026): a white EUI accent had turned
  -- every BiS edge white. "/bistheme eui on" is for people who tune their whole UI in EUI.
  ok(not T.FollowEUI(), "nobody follows EllesmereUI's accent until they ask")
  ok(T.hex.accent == ownAccent, "so the accent stays BiS purple, whatever EllesmereUI's is", T.hex.accent)
  ok(T.FONT and T.FONT:find("EllesmereUI", 1, true), "the font is theirs", tostring(T.FONT))

  local repainted = 0
  T.RegisterLooks(function() repainted = repainted + 1 end)
  local on, line = T.Slash("eui on")
  ok(on and T.FollowEUI(), "/bistheme eui on: follow it")
  ok(type(BiSThemeDB) == "table" and BiSThemeDB.followEUI == true, "remembered across sessions")
  ok(T.hex.accent == "33cc66", "the accent becomes the user's own at once", T.hex.accent)
  local r, g = T.rgb("accent")
  ok(math.abs(r - 0.2) < 0.01 and math.abs(g - 0.8) < 0.01, "and every colour lookup follows it")
  ok(repainted >= 1, "and windows drawn in the old colour are told to redraw")
  ok(line:find("EllesmereUI's", 1, true), "it says which", line)

  -- LIVE. Their guidelines say not to cache the getters: the user moves a slider mid-session.
  accent = { 1, 0.5, 0 }
  for _, fn in ipairs(listeners) do fn() end
  ok(T.hex.accent == "ff8000", "following: moving their accent slider moves ours", T.hex.accent)

  T.Slash("eui off")
  ok(not T.FollowEUI() and T.hex.accent == ownAccent, "/bistheme eui off: BiS purple again", T.hex.accent)
  accent = { 0.1, 0.1, 0.9 }
  for _, fn in ipairs(listeners) do fn() end
  ok(T.hex.accent == ownAccent, "not following: their slider leaves ours alone", T.hex.accent)
  BiSThemeDB = nil

  -- A FONT THE CLIENT WILL NOT TAKE is worse than an ugly one: a FontString whose SetFont failed
  -- draws nothing at all. So the path is tried, and the client's own is the fallback.
  local fs = { SetFont = function(_, path) if path ~= STANDARD_TEXT_FONT then error("no such font", 2) end end }
  ok(T.SetFont(fs, 9) == STANDARD_TEXT_FONT,
     "a font path the client refuses falls back rather than leaving a blank label")

  -- and with EllesmereUI absent, nothing about any of this runs
  _G.EllesmereUI = nil
  ok(T.AdoptEllesmereUI() == false, "with EllesmereUI gone, BiSTheme keeps its own look")
end

-- 7. windows that do not open on top of each other (Arn, 14 Oct: "if a window is open it does not
--    open right on top of another one"). The placement is a pure function; the frames only feed it.
do
  local okL, why = pcall(function() assert(loadfile("Options.lua"))() end)
  ok(okL and T.OPTIONS_MINOR == 4 and T.DodgeRect and T.OPEN, "Options.lua minor 4 loads, with the dodge", why)
  ok(T.OPTIONS and T.OPTIONS.RATIO == 1.43, "the BiSTheme standard window shape is 1.43:1 (Arn, 14 Oct)")
  -- SECTIONS MOVED AROUND, NOT PADDED (Arn: "it added empty space ... but did not move sections
  -- around"): BiS Tools' options - tools 4 rows, farm 6, recap 8, social 3, threat 3, bg 4
  if T.PourColumns then
    local function blk(n) local b = {} for i = 1, n do b[i] = i end return b end
    local bl = { blk(4), blk(6), blk(8), blk(3), blk(3), blk(4) }
    local cols = T.PourColumns(bl, 2, 1)
    local a, b = cols[1].h, cols[2].h
    ok(#cols == 2 and math.max(a, b) == 14, "28 rows in two columns: 14 and 14, not 18 and 10", a .. "/" .. b)
    ok(cols[1][1] == bl[1], "the column with the first section comes first")
    local seen = 0
    for _, c in ipairs(cols) do for _ = 1, #c do seen = seen + 1 end end
    ok(seen == #bl, "every section placed once")
  end
  if T.DodgeRect then
    local W, H = 1920, 1080
    local open = { { 800, 400, 1100, 700 } }                                   -- a window in the middle
    ok(T.DodgeRect({ 100, 400, 400, 700 }, open, W, H) == nil, "covering nothing: stays where it is")
    local l, t = T.DodgeRect({ 850, 450, 1150, 750 }, open, W, H)
    ok(l == 1100 + T.DODGE_GAP and t == 750, "on top of one: moved to its right, the same height", l, t)
    l, t = T.DodgeRect({ 1700, 400, 1900, 700 }, { { 1650, 400, 1920, 700 } }, W, H)
    ok(l == 1650 - T.DODGE_GAP - 200 and t == 700, "no room on the right: to its left", l, t)
    l, t = T.DodgeRect({ 0, 500, 1920, 700 }, { { 0, 500, 1920, 700 } }, W, H)
    ok(l == 0 and t == 500 - T.DODGE_GAP, "no room either side: below it", l, t)
    l = T.DodgeRect({ 0, 0, 1920, 1080 }, { { 0, 0, 1920, 1080 } }, W, H)
    ok(l == nil, "nowhere fits: left where it was, never off the screen")
    l, t = T.DodgeRect({ 850, 450, 1150, 750 }, { { 800, 400, 1100, 700 }, { 1108, 400, 1408, 700 } }, W, H)
    ok(l and not (l < 1408 and l + 300 > 800 and t > 400 and t - 300 < 700), "two open: covers neither", l, t)
  end
end

-- 8. the fingerprint (minor 4; Arn, 6 Nov: "a finger print thing only you can see so you know what version i am on"):
--    the window's addon from its own name, its version, and the deploy stamp when the copy has one
do
  local META = { BiSGamba = { Version = "1.9.2", ["X-BiS-Build"] = "beta/live@9e52109+ 1106-1841" },
                 Nebbinator = { Version = "4.0.4" } }
  local keep = rawget(_G, "C_AddOns")
  _G.C_AddOns = { GetAddOnMetadata = function(a, k)
    if not META[a] then error("Invalid AddOn " .. tostring(a)) end   -- the client's way for a name it does not know
    return META[a][k]
  end }
  ok(T.AddonOf("BiSGambaOptions") == "BiSGamba", "BiSGambaOptions belongs to BiSGamba", T.AddonOf("BiSGambaOptions"))
  ok(T.AddonOf("NebbinatorOptions") == "Nebbinator", "NebbinatorOptions belongs to Nebbinator")
  ok(T.AddonOf("SomethingElse") == nil and T.AddonOf(nil) == nil, "an unknown window: nobody's")
  ok(T.Fingerprint("BiSGamba") == "BiSGamba 1.9.2  9e52109+ 1106-1841", "a deployed test build: version, commit, time",
     T.Fingerprint("BiSGamba"))
  ok(T.Fingerprint("Nebbinator") == "Nebbinator 4.0.4", "a released build: just the version", T.Fingerprint("Nebbinator"))
  ok(T.OPTIONS.SCALE == 1.2 and T.OPTIONS.GLOW >= 0.3, "kit windows at 1.2; the hover wash clearly seen")
  _G.C_AddOns = keep
end

-- 10. THE "BiS>" HOME IN THE GAME'S OPTIONS (Settings.lua minor 1; Arn, 7 Nov: "when they open the options, they go
--     to add-ons ... they'll just see BiS> they click into that add-on and then they can see all our add-ons").
--     The game's panel stands in as Forever's does where it matters: a subcategory needs a REGISTERED parent, an
--     unknown id opens nothing, categories answer GetID.
do
  local keepCF, keepS, keepLib = _G.CreateFrame, rawget(_G, "Settings"), rawget(_G, "LibBiSComm")
  local function Region()
    local r = { shown = true, alpha = 1 }
    function r:SetPoint(...) self.points = self.points or {} self.points[#self.points + 1] = { ... } end
    function r:ClearAllPoints() self.points = {} end
    function r:SetAllPoints() end
    function r:SetHeight(h) self.h = h end
    function r:SetWidth(w) self.w = w end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:SetColorTexture(...) self.color = { ... } end
    function r:SetAlpha(a) self.alpha = a end
    function r:SetFont(_, s) self.size = s end
    function r:SetTextColor(...) self.tc = { ... } end
    function r:SetJustifyH(j) self.just = j end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    return r
  end
  local function Frame(parent)
    local f = Region()
    f.parent, f.scripts, f.scale, f.strata = parent, {}, 1, "MEDIUM"
    function f:CreateFontString() return Region() end
    function f:CreateTexture() return Region() end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:SetParent(p) self.parent = p end
    function f:GetParent() return self.parent end
    function f:SetScale(s) self.scale = s end
    function f:GetScale() return self.scale end
    function f:SetFrameStrata(s) self.strata = s end
    function f:GetFrameStrata() return self.strata end
    function f:GetNumPoints() return #(self.points or {}) end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:Show() self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown = false if self.scripts.OnHide then self.scripts.OnHide(self) end end
    return f
  end
  _G.UIParent = _G.UIParent or Frame(nil)
  _G.CreateFrame = function(_, _, parent) return Frame(parent) end
  local reg, opened, nextId = {}, {}, 0
  local function Category(name)
    nextId = nextId + 1
    local c = { name = name, id = nextId }
    function c:GetID() return self.id end
    reg[c.id] = c
    return c
  end
  local addons = {}
  _G.Settings = {
    RegisterCanvasLayoutCategory = function(frame, name) local c = Category(name) c.frame = frame return c, {} end,
    RegisterAddOnCategory = function(c) c.addon = true addons[#addons + 1] = c end,
    RegisterCanvasLayoutSubcategory = function(parent, frame, name)
      if not (parent and parent.addon) then error("parent category is not registered") end
      local c = Category(name) c.frame, c.parentCat = frame, parent
      return c, {}
    end,
    OpenToCategory = function(id) if not reg[id] then return false end opened[#opened + 1] = reg[id].name return true end,
  }
  _G.LibBiSComm = { on = true }
  function LibBiSComm:Enabled() return self.on end
  function LibBiSComm:SetEnabled(v) self.on = v end
  T.settingsRoot, T.settingsPages, T.settingsOrder = nil, {}, {}
  local okL, why = pcall(function() assert(loadfile("Settings.lua"))() end)
  ok(okL and T.SETTINGS_MINOR == 1 and T.SettingsPage and T.OpenSettings, "Settings.lua minor 1 loads", why)

  local win = Frame(UIParent)                 -- an addon's own options window, out on the screen
  win:SetScale(1.2) win:SetFrameStrata("MEDIUM") win:SetPoint("CENTER", UIParent, "CENTER", 40, 10)
  local page = T.SettingsPage("BiSHealing", { title = "Healing", about = "Click-to-heal frames.",
    status = function() return "frames on  -  target off" end, window = function() return win end,
    api = { name = "BiSHealingAPI", about = "the grid, read-only" },
    open = { label = "mouse binds", func = function() end } })
  T.SettingsPage("BiSGuild", { title = "Guild", about = "Officers' terminal.", build = function(body) body.drawn = true end })
  ok(#addons == 1 and addons[1].name == "BiS>", "ONE entry in the game's AddOns list: BiS>")
  ok(page and page.category and page.category.parentCat == addons[1] and page.category.name == "BiS> Healing",
     "each addon a page under it, named BiS> <addon>")
  ok(T.settingsOrder[1] == "BiSGuild" and T.settingsOrder[2] == "BiSHealing", "kept in name order")
  T.SettingsPage("BiSHealing", { title = "Healing", about = "again", window = function() return win end,
    api = { name = "BiSHealingAPI", about = "the grid, read-only" }, open = { label = "mouse binds", func = function() end } })
  ok(#T.settingsOrder == 2 and #addons == 1, "asked again: the same page, no second entry")

  -- the front page: a row per addon, what is on, the channel and the API
  T.settingsRoot.frame:Show()
  local root = T.settingsRoot.frame
  ok(root.rows[1].name.text == "BiS> Guild" and root.rows[2].name.text == "BiS> Healing", "the front page lists them")
  ok(root.commBtn and root.commBtn.label.text:find("ON", 1, true), "the shared channel: said ON, a switch")
  root.commBtn.scripts.OnClick(root.commBtn)
  ok(LibBiSComm.on == false and root.commBtn.label.text:find("OFF", 1, true), "one click turns it off, and it says so")
  root.commBtn.scripts.OnEnter(root.commBtn)
  ok(root.commBtn.wash.alpha == 1, "its button pops under the mouse")
  ok(root.api.text:find("BiSHealingAPI", 1, true), "the API notes name each addon's table")

  -- an addon's page holds its own options window, then gives it back as it was
  page.frame:Show()
  ok(win.parent == page.frame.body and win.scale == 1 and win.shown, "its options window sits inside the page, unscaled")
  ok(page.frame.openBtn and page.frame.openBtn.label.text == "mouse binds", "and a big button to the main window")
  page.frame:Hide()
  ok(win.parent == UIParent and win.scale == 1.2 and not win.shown and win.points[1][1] == "CENTER" and win.points[1][4] == 40,
     "leaving the page: back on the screen where it was, scale and all, hidden")
  T.settingsPages.BiSGuild.frame:Show()
  ok(T.settingsPages.BiSGuild.frame.body.drawn, "an addon without an options window draws its page itself")

  ok(T.OpenSettings("BiSHealing") and opened[#opened] == "BiS> Healing", "the minimap's right-click opens its page")
  ok(T.OpenSettings() and opened[#opened] == "BiS>", "and the front page")
  ok(T.OpenSettings("Nobody") and opened[#opened] == "BiS>", "an addon with no page: the front page")

  -- an older client without the panel: nothing, no error
  _G.Settings = nil
  T.settingsRoot, T.settingsPages, T.settingsOrder = nil, {}, {}
  ok(T.SettingsPage("BiSTools", { title = "Tools" }) == nil and T.OpenSettings("BiSTools") == false,
     "no game options panel: no page, no error - the addon's own window still works")
  _G.CreateFrame, _G.Settings, _G.LibBiSComm = keepCF, keepS, keepLib
  T.settingsRoot, T.settingsPages, T.settingsOrder = nil, {}, {}
end

if fails > 0 then error(fails .. " failed of " .. n) end
print("ALL OK (" .. n .. " checks)")
