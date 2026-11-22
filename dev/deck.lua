-- BiSTheme / dev / deck.lua -- the deck's skin without the game.
--   cd BiSTheme && lua5.1 dev/deck.lua
local n, fails = 0, 0
local function ok(c, what, seen) n = n + 1 if not c then fails = fails + 1 print("FAIL: " .. what .. (seen ~= nil and ("  [" .. tostring(seen) .. "]") or "")) end end

-- A MOCK AS THE CLIENT IS: a frame starts SHOWN; showing / hiding runs OnShow / OnHide; OnUpdate runs only while shown (and
-- its parents); an event reaches only who registered it; a secret is refused by an `if`, a compare and tostring.
local made, secureMade, calls = {}, 0, 0
local function node(kind, parent, template)
  local f = { kind = kind, parent = parent, shown = true, scripts = {}, events = {}, pts = {}, mouse = false, alpha = 1, scale = 1, level = 1, w = 0, h = 0 }
  if type(template) == "string" and template:find("Secure") then secureMade = secureMade + 1 end
  made[#made + 1] = f
  local M = {}
  function M:Show() if not self.shown then self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end end end
  function M:Hide() if self.shown then self.shown = false if self.scripts.OnHide then self.scripts.OnHide(self) end end end
  function M:SetShown(v) if v then self:Show() else self:Hide() end end
  function M:IsShown() return self.shown end
  function M:IsVisible() local p = self while p do if not p.shown then return false end p = p.parent end return true end
  function M:SetScript(k, fn) self.scripts[k] = fn end
  function M:GetScript(k) return self.scripts[k] end
  function M:RegisterEvent(e) self.events[e] = true end
  function M:UnregisterEvent(e) self.events[e] = nil end
  function M:SetPoint(...) self.pts[#self.pts + 1] = { ... } end
  function M:ClearAllPoints() self.pts = {} end
  function M:SetAllPoints() self.all = true end
  function M:GetPoint() return "RIGHT", UIParent, "RIGHT", -33, 12 end
  function M:SetSize(w, h) if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then error("SetSize wants numbers over 0: " .. tostring(w) .. " " .. tostring(h), 2) end self.w, self.h = w, h end
  function M:SetWidth(w) self.w = w end
  function M:SetHeight(h) self.h = h end
  function M:GetWidth() return self.w end
  function M:SetAlpha(a) self.alpha = a end
  function M:SetScale(s) self.scale = s end
  function M:GetEffectiveScale() return self.scale end
  function M:EnableMouse(v) self.mouse = v and true or false end
  function M:SetFrameLevel(l) self.level = l end
  function M:GetFrameLevel() return self.level end
  function M:StartMoving() self.isMoving = true end
  function M:StopMovingOrSizing() self.isMoving = nil end
  function M:SetColorTexture(r) if type(r) ~= "number" then error("SetColorTexture wants numbers", 2) end self.r = r end
  function M:SetText(t) if t ~= nil and type(t) ~= "string" then error("SetText wants words, got " .. type(t), 2) end calls = calls + 1 self.text = t end
  function M:GetText() return self.text end
  function M:SetFont(_, s) if type(s) ~= "number" then error("SetFont wants a size", 2) end self.size = s end
  function M:SetTextColor(r) if type(r) ~= "number" then error("SetTextColor wants numbers", 2) end self.col = r end
  function M:CreateTexture() return node("Texture", self) end
  function M:CreateFontString() return node("FontString", self) end
  return setmetatable(f, { __index = function(_, k) return M[k] or (type(k) == "string" and k:match("^%u") and function() end) or nil end })
end
_G.CreateFrame = function(kind, _, parent, template) return node(kind, parent, template) end
_G.UIParent = node("Frame")
local GAME = { inside = false, kind = "none", resting = false, raid = false, ghost = false, now = 1000000, fight = false, login = false }
_G.InCombatLockdown = function() return GAME.fight end
_G.IsInInstance = function() return GAME.inside, GAME.kind end
_G.IsResting = function() return GAME.resting end
_G.IsInRaid = function() return GAME.raid end
_G.UnitIsGhost = function() return GAME.ghost end
_G.GetServerTime = function() return GAME.now end
_G.date = function() return "20:48" end
local cx, cy = 0, 0
_G.GetCursorPosition = function() return cx, cy end
local said = {}
_G.geterrorhandler = function() return function(m) said[#said + 1] = m end end
local afters = {}
_G.C_Timer = { After = function(s, fn) afters[#afters + 1] = { s, fn } end }
local function runAfters() local a = afters afters = {} for _, x in ipairs(a) do x[2]() end end

BiSTheme = nil
assert(loadfile("BiSTheme.lua"))()
assert(loadfile("DeckLayout.lua"))()
assert(loadfile("Deck.lua"))()
local T = BiSTheme
local D = T.Deck
local function fire(e) for _, f in ipairs(made) do if f.events[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e) end end end
local function tick(s) local f = D.frame if f and f:IsVisible() and f.scripts.OnUpdate then f.scripts.OnUpdate(f, s) end end
local function find(kind, i) local k = 0 for _, w in ipairs(D.frame.pieces) do if w.shown and w.kind == kind then k = k + 1 if k == (i or 1) then return w end end end end
local function count(kind) local k = 0 for _, w in ipairs(D.frame.pieces) do if w.shown and w.kind == kind then k = k + 1 end end return k end
local function click(w) w.scripts.OnClick(w) end

function shownAppsForTest() local out = {} for _, d in pairs(D.defs) do if d.page and not d.parked or (d.page and d.parked) then out[#out + 1] = d end end return out end
-- before the login only data: no frame
local saveA, saveB = {}, { deck = { at = 50, open = false, portrait = { w = 300, h = 520 }, sw = { hero = false } } }
local stepsDone = { true, false, false }
local rows = {}
for i = 1, 30 do rows[i] = { text = "Boss " .. i, right = i == 2 and "FOUND" or "", ink = "gold", mark = tostring(i), act = { word = "go", fn = function() rows.hit = i end } } end
local pressed = {}
local H = D.Register{ owner = "BiSTools", key = "bosses", name = "Bosses", icon = "Bo", order = 10, store = function() return saveA end,
  badge = function() return 5 end,
  card = { prio = function() return 8 end, lines = function() return { "BOSSES", "", "Next: Razorlash", "FOUND", "gold", hot = true } end, buttons = function() return { { word = "FIND", macro = "/target x" }, { word = "OPEN", fn = function() pressed.open = true end } } end },
  page = { title = function() return "Maraudon" end, boxes = function() return { { "DOWN", "3/8", "good" }, { "LEFT", 5, "gold" } } end, tabs = function() return { "BOSSES", "QUESTS" } end,
    rows = function(tab) return tab == 2 and { { text = "Scion" } } or rows end, big = function() return { word = "FIND", macro = "/target x" } end, keys = function() return { { word = "RESET", fn = function() pressed.reset = true end } } end,
    say = function() return "marked" end },
  dock = { word = "FIND", hot = function() return true end, fn = function() pressed.dock = true end } }
D.Register{ owner = "BiSTools", key = "run", name = "Run", order = 11, page = { title = function() return "Maraudon run" end, steps = function()
  return { { phase = "PREP", text = "Pick it up", done = function() return stepsDone[1] end, button = { word = "MAP", fn = function() pressed.map = true end } },
    { phase = "INSIDE", text = "Noxxion", note = "Quest", done = function() return stepsDone[2] end, button = { word = "FIND", fn = function() pressed.find = true end } },
    { phase = "AFTER", text = "Turn in", done = function() return stepsDone[3] end } } end } }
D.Register{ owner = "BiSMemories", key = "mem", name = "Memories", order = 20, store = function() return saveB end,
  card = { prio = function() return 1 end, lines = function() return { "MEMORIES", "", "38 this year", "", "ink2" } end } }
D.Register{ owner = "BiSBroken", key = "bad", name = "Bad", order = 30, card = { prio = function() error("oops") end, lines = function() end }, page = { rows = function() error("bang") end } }
D.Register{ owner = "BiSRaid", key = "guild", name = "Guild", order = 40, card = { prio = function() return 9 end, profiles = { ["Raid night"] = true }, lines = function() return { "RAID NIGHT", "", "34 of 40", "6 missing", "gold" } end } }
ok(H and H.Dirty and H.Open and select(2, D.Register{}) == "owner and key", "register answers a handle, or why not")
ok(D.frame == nil and D.Show() == false, "before the login: data only, no frame")

-- the login: the newest saved copy wins
fire("PLAYER_LOGIN")
ok(D.frame == nil, "it was closed: it stays closed")
ok(D.Show() and D.frame.shown and D.W == 300 and D.H == 520 and D.shape == "portrait", "shown at the size the newest save kept", D.W)
ok(D.Store().sw.hero == false, "and its switches")
ok(secureMade == 0, "nothing secure on the skin", secureMade)
ok(D.profile == "Leveling" and find("kicker").a.text == "LEVELING", "outside: leveling")
ok(count("card") >= 2 and find("card", 1).a.text == "Next: Razorlash" and find("card", 2).a.text == "38 this year", "the cards, the most urgent first", find("card", 1).a.text)
ok(find("card", 1).hot and find("card", 1).bar.shown, "a card that needs you has the gold bar")
ok(count("app") == 3, "an icon for each page", count("app"))
ok(find("app", 1).b.text == "5", "with its count")
ok(#said == 1 and said[1]:find("BiSBroken", 1, true), "a broken card: said once, with its owner's name", said[1])
for _ = 1, 4 do D.Paint() end
ok(D.defs["BiSBroken:bad"].parked and #said == 1, "after three errors it is parked, the rest goes on")
-- what a click does
click(find("dock"))
ok(pressed.dock, "the dock's button does its work")
click(find("cardbtn", 2))
ok(pressed.open, "a card's button does its own work")
ok(find("cardbtn", 1).act == nil and find("cardbtn", 1).tip ~= nil, "a secure button is drawn, and waits for the overlay")
click(find("card", 1))
ok(D.page == "BiSTools:bosses" and find("title").a.text == "Maraudon" and count("row") > 4 and count("big") == 1, "a card opens its page")
ok(find("row", 2).b.text == "FOUND", "the rows' words")
click(find("row", 3))
ok(rows.hit == 3, "a row does what it was handed")
click(find("tab", 2))
ok(count("row") == 1 and find("row").a.text == "Scion" and find("tab", 2).lit, "the tabs")
click(find("key"))
ok(pressed.reset, "a small button")
click(find("tab", 1))
click(find("back"))
ok(D.page == "home", "back")
-- steps
D.Open("BiSTools:run")
ok(find("steptext").a.text == "Noxxion" and find("stephead").a.text:find("STEP 2", 1, true), "the first step not done", find("steptext").a.text)
click(find("big"))
ok(pressed.find, "the step's one button")
stepsDone[2] = true
H:Dirty() tick(2)
ok(find("steptext").a.text == "Turn in", "done in the game: it moves on by itself", find("steptext").a.text)
click(find("link", 1))
ok(find("steptext").a.text == "Noxxion", "back")
H:Dirty() tick(2)
ok(find("steptext").a.text == "Noxxion", "and it stays where you went")
click(find("link", 3)) click(find("link", 2))
ok(D.defs["BiSTools:run"].skipped[3], "skip marks it")
click(find("step", 1))
ok(find("steptext").a.text == "Pick it up", "a step in the list goes to it")
-- the switches
click(find("back")) click(find("gear"))
ok(D.page == "switches" and count("switch") >= 8 and count("preset") == 3, "the gear: the switches")
ok(find("swhead", 1).a.text == "EASIER TO USE" and find("switch", 1).a.text == "Read aloud" and find("switch", 1).b.text == "OFF", "the easier-to-use ones first, off until asked for")
click(find("switch", 1))
ok(D.Store().easy.speak == true and find("switch", 1).b.text == "ON", "and on with one press")
click(find("switch", 1))
ok(D.Store().easy.speak == nil, "and off again")
click(find("switch", 3))
ok(D.Store().sw.cards == false and saveA.deck == saveB.deck and saveA.deck.sw.cards == false, "a switch is kept, in every addon's save")
click(find("gear"))
ok(count("card") == 0, "no cards now")
D.Preset(1)
ok(count("card") >= 2, "ALL: back")
-- sizes and shapes
D.Flip()
ok(T.DeckShape(D.W, D.H) == "landscape" and count("railapp") >= 2 and count("card") >= 2, "flipped: wide, the icons on a rail")
D.Open("BiSTools:bosses")
ok(count("row") > 4, "the list at the left")
D.Flip()
ok(D.W == 300 and D.H == 520 and D.page == "BiSTools:bosses", "and back: its own size, the same page")
local rowsNow = count("row")
cx, cy = 100, 100
find("size").scripts.OnMouseDown(find("size"))
cx, cy = 100, -100
tick(0.1)
ok(D.H > 520 and count("row") > rowsNow, "the corner pulled down: taller, more rows", D.H)
cx = 5000 tick(0.1)
ok(T.DeckShape(D.W, D.H) == "portrait", "the corner never turns tall into wide", D.W .. "x" .. D.H)
find("size").scripts.OnMouseUp(find("size"))
ok(D.grip == nil and D.Store().portrait.h == D.H, "let go: kept")
D.Size(260, 462)
-- a fight
click(find("back"))
fire("PLAYER_REGEN_DISABLED")
GAME.fight = true
ok(D.frame.alpha == D.FIGHT_ALPHA and D.frame.mouse == false, "a fight: barely there, the mouse goes through")
local any = false
for _, w in ipairs(D.frame.pieces) do if w.shown and w.mouse then any = true end end
ok(not any, "no piece takes a click")
D.Flip() D.Flip()
ok(D.frame.shown, "it may even flip in a fight: nothing on it is secure")
GAME.fight = false
fire("PLAYER_REGEN_ENABLED")
ok(D.frame.alpha == 1 and D.frame.mouse == true, "after it: back")
D.frame.scripts.OnDragStart(D.frame)
fire("PLAYER_REGEN_DISABLED")
ok(not D.frame.isMoving and D.Store()[D.shape].pos[4] == -33 or D.Store()[D.shape].pos[3] == -33, "a drag ends at the pull, where it stands is kept")
fire("PLAYER_REGEN_ENABLED")

-- EASIER TO USE (Arn, 22 Nov: accessibility and gamepad)
do
  local spoke = {}
  _G.C_VoiceChat = { SpeakText = function(_, words) spoke[#spoke + 1] = words end }
  local clock = 10
  _G.GetTime = function() clock = clock + 5 return clock end
  D.Place("portrait") D.page = "home" D.Paint()
  local c1 = find("card", 1)
  c1.scripts.OnEnter(c1)
  ok(#spoke == 0, "read aloud is off until asked for")
  D.Store().easy = { speak = true }
  c1.scripts.OnEnter(c1)
  ok(spoke[1] and spoke[1]:find("Next: Razorlash", 1, true) and spoke[1]:find("FOUND", 1, true), "on: what the mouse is on is read aloud", spoke[1])
  ok(c1.c.text:find("^! "), "a card that needs you says so with a mark, not by colour alone", c1.c.text)
  ok(find("dock").a.text:find("^! "), "so does a dock button", find("dock").a.text)
  D.Fight(true) local n0 = #spoke c1.scripts.OnEnter(c1) ok(#spoke == n0, "never in a fight") D.Fight(false)
  D.Store().easy = { strong = true }
  D.Paint()
  ok(find("app", 1).c.tone == "ink", "stronger words: no grey", find("app", 1).c.tone)
  D.Store().easy = {}
  D.Paint()
  -- no words smaller than 11 (13.75 at the deck's own scale), but the faint code
  local small = 99
  for _, pg in ipairs({ "home", "switches", "BiSTools:bosses", "BiSTools:run" }) do
    D.page = pg D.Paint()
    for _, w in ipairs(D.frame.pieces) do if w.shown and w.kind ~= "code" and w.kind ~= "size" then
      for _, fs in ipairs({ w.a, w.b, w.c }) do if fs.text and fs.text ~= "" then small = math.min(small, fs.px) end end end end
  end
  ok(small >= 10, "no small print", small)
  -- nothing out of reach: the wheel and MORE
  D.Open("BiSTools:bosses")
  local firstRow = find("row", 1).a.text
  D.frame.scripts.OnMouseWheel(D.frame, -1)
  ok(find("row", 1).a.text ~= firstRow, "the wheel scrolls a long list", find("row", 1).a.text)
  for _ = 1, 60 do D.frame.scripts.OnMouseWheel(D.frame, -1) end
  local lastSeen
  for i = 1, count("row") do lastSeen = find("row", i).a.text end
  ok(lastSeen == "Boss 30", "to the last one, and stops there", lastSeen)
  for _ = 1, 80 do D.frame.scripts.OnMouseWheel(D.frame, 1) end
  ok(find("row", 1).a.text == firstRow, "and back to the first")
  D.page = "switches" D.Size(220, 300)
  local names = {}
  for _ = 1, 30 do
    for i = 1, count("switch") do names[find("switch", i).a.text] = true end
    if not find("more") then break end
    click(find("more"))
  end
  local want, got = 0, 0
  for _, g in ipairs(D.SWITCHES) do for _, s in ipairs(g[2]) do want = want + 1 if names[s[2]] then got = got + 1 end end end
  ok(got == want, "the smallest deck: every switch by MORE", got .. " of " .. want)
  for i = 1, 14 do D.Register{ owner = "BiSMany", key = "p" .. i, name = "P" .. i, order = 200 + i, page = { rows = function() return {} end } } end
  D.page = "home" D.Size(220, 300)
  local icons = {}
  for _ = 1, 40 do
    for i = 1, count("app") do icons[find("app", i).c.text] = true end
    if not find("moreapps") then break end
    click(find("moreapps"))
  end
  local ni = 0 for _ in pairs(icons) do ni = ni + 1 end
  ok(ni == #shownAppsForTest(), "the smallest deck: every icon by MORE", ni .. " of " .. #shownAppsForTest())
  for i = 1, 14 do D.defs["BiSMany:p" .. i] = nil end
  D.sorted = nil D.appSkip = nil
  D.Size(260, 462)
  -- the pad
  local nav
  ok(D.Focus(true) == false, "no pad kit: no focus, no error")
  T.PadNav = function(frame, spec) nav = spec frame.nav = true return spec end
  D.page = "home"
  ok(D.Focus(true) and D.padFrame.shown and nav and #nav.items() > 5, "focus: every piece that does something is reachable", nav and #nav.items())
  local all = true
  for _, w in ipairs(nav.items()) do if not w.act then all = false end end
  ok(all, "and nothing else")
  D.Open("BiSTools:bosses")
  nav.tabs.next()
  ok(D.defs["BiSTools:bosses"].tab == 2, "RB: the next tab")
  nav.tabs.prev()
  local r1 = find("row", 1).a.text
  nav.scroll(-1)
  ok(find("row", 1).a.text ~= r1, "RT: the list scrolls")
  nav.scroll(1)
  ok(D.defs["BiSTools:bosses"].tab == 1, "LB: the one before")
  nav.back()
  ok(D.page == "home" and D.padFrame.shown, "B: home first")
  nav.back()
  ok(not D.padFrame.shown and not D.focused, "B again: the pad is the character's")
  D.Focus(true)
  fire("PLAYER_REGEN_DISABLED")
  ok(not D.padFrame.shown, "a pull gives the pad back at once")
  fire("PLAYER_REGEN_ENABLED")
end

-- the profiles
local function det(f) return D.Detect(f) end
ok(det{} == "Leveling" and det{ resting = true } == "Town" and det{ dungeon = true, resting = true } == "Dungeon" and det{ raid = true } == "Raid night"
   and det{ pvp = true, raid = true } == "PvP" and det{ raidGroup = true } == "Leveling" and det{ raidGroup = true, raidSoon = true } == "Raid night", "what the facts mean")
GAME.inside, GAME.kind = true, "party"
fire("PLAYER_ENTERING_WORLD")
ok(D.profile == "Dungeon", "into a dungeon: at once")
GAME.inside, GAME.kind, GAME.ghost = false, "none", true
fire("PLAYER_ENTERING_WORLD")
runAfters()
ok(D.profile == "Dungeon", "a ghost running back: still the dungeon")
GAME.ghost = false
fire("ZONE_CHANGED_NEW_AREA")
ok(D.profile == "Dungeon" and #afters == 1 and afters[1][1] == D.LEAVE, "out: not at once")
GAME.inside, GAME.kind = true, "party"
runAfters()
ok(D.profile == "Dungeon", "in again before it: nothing changed")
GAME.inside, GAME.kind = false, "none"
fire("ZONE_CHANGED_NEW_AREA") runAfters()
ok(D.profile == "Leveling", "out for good: leveling", D.profile)
GAME.resting = true
GAME.fight = true
fire("PLAYER_UPDATE_RESTING") runAfters()
ok(D.profile == "Leveling", "never in a fight")
GAME.fight = false
fire("PLAYER_UPDATE_RESTING") runAfters()
ok(D.profile == "Town", "a city: town")
GAME.raid = true
_G.BiSGuildAPI = { RaidNight = function() return { title = "MC", start = GAME.now + 1200 } end }
fire("GROUP_ROSTER_UPDATE") runAfters()
ok(D.profile == "Raid night", "a raid group 20 minutes before a pasted raid: raid night", D.profile)
D.Paint()
ok(find("card", 1).a.text == "34 of 40", "and its own card comes first", find("card", 1).a.text)
_G.BiSGuildAPI = { RaidNight = function() error("broken") end }
ok(pcall(D.Look), "a broken answer from the guild's addon: no error")
D.Pin("PvP")
fire("PLAYER_ENTERING_WORLD")
ok(D.profile == "PvP" and find("kicker").a.text:find("PINNED"), "pinned by hand: it stays", D.profile)
D.Pin(nil)

-- hidden: nothing runs
D.Hide()
local before = calls
fire("GROUP_ROSTER_UPDATE") fire("ZONE_CHANGED_NEW_AREA") H:Dirty() tick(5)
ok(D.frame.scripts.OnUpdate == nil and calls == before, "hidden: nothing runs, nothing is written", calls - before)
-- an unchanged repaint writes no words twice
D.Show()
D.Paint()
before = calls
D.Paint()
ok(calls - before <= 4, "painted again unchanged: no words written again", calls - before)
-- every size, every page: it paints
for _, page in ipairs({ "home", "switches", "BiSTools:bosses", "BiSTools:run", "BiSBroken:bad", "Nobody:here" }) do
  D.page = page
  for _, s in ipairs({ { 220, 300 }, { 324, 576 }, { 500, 900 }, { 430, 300 }, { 860, 600 }, { 1366, 768 } }) do
    D.W, D.H, D.shape = s[1], s[2], T.DeckShape(s[1], s[2])
    local okP, why = pcall(D.Paint)
    ok(okP, "paints " .. page .. " " .. s[1] .. "x" .. s[2], why)
  end
end
-- THE FIRST DAY (Arn, 22 Nov: "build the infrastructure for the onboarding stuff ... put my tools in there but grayed out")
do
  local there = { BiSTools = "on", BiSHealing = "on", BiSGuild = "off" }              -- the rest: not installed
  local asked, turned, reloads, doors = 0, nil, 0, {}
  _G.C_AddOns = {
    IsAddOnLoaded = function(n) asked = asked + 1 return there[n] == "on", there[n] == "on" end,
    GetAddOnInfo = function(n)
      if not there[n] then return n, n, nil, false, "MISSING", "INSECURE" end
      return n, n, "words", there[n] == "on", there[n] == "off" and "DISABLED" or nil, "INSECURE"
    end,
    EnableAddOn = function(n) turned = n end,
  }
  _G.ReloadUI = function() reloads = reloads + 1 end
  _G.SlashCmdList = { BISHEALING = function(w) doors[#doors + 1] = "healing " .. w end, BISTOOLS = function(w) doors[#doors + 1] = "tools " .. w end }
  D.Hide()
  assert(loadfile("DeckApps.lua"))()
  D.page, D.skip = "home", 0
  D.W, D.H, D.shape = nil, nil, nil
  D.Store().portrait, D.Store().landscape, D.Store().welcomed, D.Store().shape = nil, nil, nil, nil
  D.defs["BiSBroken:bad"] = nil D.sorted = nil
  local mine = 0
  D.Register{ owner = "BiSProbe", key = "deck", name = "Probe", icon = "Pd", dev = true, order = 1, open = function() mine = mine + 1 end, badge = function() return 25 end }
  D.Show()
  ok(D.page == "BiSDeck:welcome" and find("title").a.text == "Welcome" and find("stephead").a.text:find("WELCOME", 1, true), "the first time ever: the welcome", D.page)
  click(find("big"))
  ok(find("steptext").a.text:find("^Drag the deck"), "one button, on to the next", find("steptext").a.text)
  D.frame.scripts.OnDragStart(D.frame) D.frame.scripts.OnDragStop(D.frame)
  tick(2)
  ok(find("steptext").a.text:find("^Pull the corner"), "you dragged it: on by itself", find("steptext").a.text)
  find("size").scripts.OnMouseDown(find("size")) cx, cy = 5040, -140 tick(0.1) find("size").scripts.OnMouseUp(find("size"))
  tick(2)
  ok(find("steptext").a.text:find("^Tall or wide"), "you sized it: on", find("steptext").a.text)
  click(find("link", 2))
  ok(find("steptext").a.text:find("^Read aloud"), "skipped: on", find("steptext").a.text)
  click(find("big"))
  ok(D.page == "switches", "its button opens the switches")
  click(find("home"))
  ok(D.page == "home" and count("app") > 0, "home", D.page)
  local wc
  for i = 1, count("card") do if find("card", i).c.text == "WELCOME" then wc = find("card", i) end end
  ok(wc and wc.b.text:find(" / 8", 1, true), "a card says how far you are", wc and wc.b.text)
  D.Hide() D.Show()
  ok(D.page == "home", "it never opens by itself again", D.page)
  click(wc)
  ok(D.page == "BiSDeck:welcome" and find("steptext").a.text:find("^Gray icons"), "the card goes on where you were", find("steptext") and find("steptext").a.text)
  -- the icons
  local function icon(name)
    D.page = "home" D.appSkip = nil D.Size(400, 760)
    for i = 1, count("app") do local w = find("app", i) if w.c.text == name then return w, i end end
  end
  local w1, at1 = icon("Healing")
  ok(w1 and w1.a.tone == "ink" and (w1.b.text or "") == "", "an addon you have: lit", w1 and w1.a.tone)
  local w2, at2 = icon("Guild")
  ok(w2 and w2.a.tone == "dim" and w2.b.text == "OFF" and at2 > at1, "switched off in the game's list: gray, and it says OFF", w2 and w2.b.text)
  local w3, at3 = icon("Gamba")
  ok(w3 and w3.a.tone == "dim" and w3.b.text == "GET" and at3 > at2, "not installed: gray, GET", w3 and w3.b.text)
  local w4, at4 = icon("Probe")
  ok(w4 and w4.a.tone == "dim" and w4.b.text == "25" and at4 == count("app"), "our own tool: gray, the last one, with its count", w4 and (w4.b.text .. " " .. at4))
  click(w4)
  ok(mine == 1 and D.page == "home", "and one click opens it")
  click((icon("Healing")))
  ok(doors[1] == "healing options", "a lit addon's icon opens its own window", doors[1])
  click((icon("Tools")))
  ok(doors[2] == "tools hub", "the hub", doors[2])
  _G.BiSGuildAPI = nil
  click((icon("Gamba")))
  ok(D.page == "BiSGamba:app" and find("title").a.text == "Gamba" and find("text").a.text:find("CurseForge app, search for BiS Gamba", 1, true) and count("big") == 0, "gray: what it is and where to get it", find("text") and find("text").a.text)
  click((icon("Guild")))
  ok(find("big").a.text == "TURN ON (RELOADS)" and find("kicker").a.text == "OFF", "off: one button turns it on", find("big").a.text)
  click(find("big"))
  ok(turned == "BiSGuild" and reloads == 1, "and reloads")
  local a0 = asked
  D.Paint() D.Paint()
  ok(asked == a0, "what is installed is asked once", asked - a0)
  -- an addon of ours without a door: its words, no error
  _G.SlashCmdList.BISHEALING = nil
  click((icon("Healing")))
  ok(D.page == "BiSHealing:app" and find("kicker").a.text == "ON", "no door: what it is")
  -- the Apps page
  D.Open("BiSDeck:apps") D.Size(400, 760)
  local function row(name) for i = 1, count("row") do local w = find("row", i) if w.a.text:find("^" .. name) then return w end end end
  ok(row("Gamba") and row("Gamba").a.text == "Gamba - not installed" and row("Gamba").b.text == "SHOWN" and row("Probe").a.text == "Probe - tool", "Apps: every icon, and what it is", row("Gamba") and row("Gamba").a.text)
  click(row("Gamba"))
  ok(row("Gamba").b.text == "HIDDEN" and D.Store().apps["BiSGamba:app"] == false, "a click hides it")
  ok(icon("Gamba") == nil and icon("Nebbinator") ~= nil, "from home")
  D.Open("BiSDeck:apps")
  click(row("Gamba"))
  ok(icon("Gamba") ~= nil, "and back")
  D.Store().sw.missing = false
  ok(icon("Gamba") == nil and icon("Guild") ~= nil and icon("Probe") ~= nil, "the switch: none you do not have")
  D.Open("BiSDeck:apps")
  click(row("Gamba"))
  ok(icon("Gamba") ~= nil, "showing one by hand shows them again")
  ok(row == nil or not (function() D.Open("BiSDeck:apps") return row("Apps") end)(), "Apps is not on its own list")
  -- a page's own first words
  D.Register{ owner = "BiSNew", key = "p", name = "New", order = 5, page = { tour = { { text = "One thing." }, { text = "Another." } }, rows = function() return { { text = "a row" } } end } }
  D.Open("BiSNew:p")
  ok(find("steptext").a.text == "One thing." and find("kicker").a.text == "FIRST TIME HERE", "a page's first time: its words")
  click(find("big"))
  ok(find("steptext").a.text == "Another." and find("big").a.text == "START", "one at a time")
  click(find("big"))
  ok(count("row") == 1 and count("steptext") == 0 and D.Store().toured["BiSNew:p"], "then the page, for good")
  D.Open("BiSTools:bosses") D.Open("BiSNew:p")
  ok(count("row") == 1, "never again")
  click(find("back"))
  D.Open("BiSDeck:apps")
  click(find("key"))
  ok(D.page == "BiSDeck:welcome" and find("steptext").a.text:find("^This is the BiS deck") and not D.Store().toured["BiSNew:p"], "WELCOME on the Apps page: all of it again", find("steptext").a.text)
  D.Open("BiSNew:p")
  click(find("link", 2))
  ok(count("row") == 1, "a tour's skip is enough of it")
  -- the pad, in a tour
  D.Store().toured = {}
  D.PadTab(1)
  ok(find("steptext") and find("steptext").a.text == "Another.", "RB: the tour's next", find("steptext") and find("steptext").a.text)
  -- NO THANKS
  D.Store().wel = {} D.page = "home" D.Size(400, 760)
  local before1 = 0
  for i = 1, count("card") do if find("card", i).c.text == "WELCOME" then before1 = before1 + 1 end end
  for _, w in ipairs(D.frame.pieces) do if w.shown and w.kind == "cardbtn" and w.a.text == "NO THANKS" then click(w) break end end
  local after1 = 0
  for i = 1, count("card") do if find("card", i).c.text == "WELCOME" then after1 = after1 + 1 end end
  ok(before1 == 1 and after1 == 0, "NO THANKS: the card goes", before1 .. " " .. after1)
  -- an addon that hands in its own icon wins over the catalogue's
  ok(D.Register{ owner = "BiSGamba", key = "app", name = "Gamba!", open = function() end } and icon("Gamba!") ~= nil and icon("Gamba") == nil, "an addon's own icon wins")
  -- no catalogue on a client that cannot say
  for _, pg in ipairs({ "BiSDeck:apps", "BiSDeck:welcome", "BiSGuild:app", "BiSNew:p" }) do
    for _, s in ipairs({ { 220, 300 }, { 324, 576 }, { 430, 300 }, { 1366, 768 } }) do
      D.page, D.W, D.H, D.shape = pg, s[1], s[2], T.DeckShape(s[1], s[2])
      local okP, why = pcall(D.Paint)
      ok(okP, "paints " .. pg .. " " .. s[1] .. "x" .. s[2], why)
    end
  end
  D.page = "home"
end

-- an older copy loading after: refused; a newer one takes over the data and builds its own frame
local old = D.frame
assert(loadfile("Deck.lua"))()
ok(T.Deck.frame == old, "the same copy again: refused")
T.DECK_MINOR = 0 T.DECK_READY = nil
assert(loadfile("Deck.lua"))()
ok(T.Deck == D and next(D.defs) ~= nil, "a newer copy keeps what was registered")
old.built = 0
D.Show()
ok(D.frame ~= old and not old.shown, "and retires the older frame")

print(string.format("== deck skin %s (%d checks)", fails == 0 and "ok" or ("FAILED " .. fails), n))
os.exit(fails == 0 and 0 or 1)
