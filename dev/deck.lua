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
  function M:GetScale() return self.scale end
  function M:SetFrameStrata(s) self.strata = s end
  function M:GetEffectiveScale() return self.scale end
  function M:EnableMouse(v) self.mouse = v and true or false end
  function M:SetFrameLevel(l) self.level = l end
  function M:GetFrameLevel() return self.level end
  function M:StartMoving() self.isMoving = true end
  function M:StopMovingOrSizing() self.isMoving = nil end
  function M:SetColorTexture(r) if type(r) ~= "number" then error("SetColorTexture wants numbers", 2) end self.r = r end
  function M:SetWordWrap(v) self.wrap = v end
  function M:IsTruncated() return self.cut or false end
  function M:SetText(t) self.laid = self.wrap if t ~= nil and type(t) ~= "string" then error("SetText wants words, got " .. type(t), 2) end calls = calls + 1 self.text = t end
  function M:GetText() return self.text end
  function M:SetFont(_, s) if type(s) ~= "number" then error("SetFont wants a size", 2) end self.size = s end
  function M:SetTextColor(r) if type(r) ~= "number" then error("SetTextColor wants numbers", 2) end self.col = r end
  function M:CreateTexture() return node("Texture", self) end
  function M:CreateFontString() return node("FontString", self) end
  function M:CreateLine() return node("Line", self) end
  function M:SetTexture(t) if type(t) == "string" and t:find("Interface", 1, true) and not t:find("^Interface[\\/]") then error("no such texture: " .. t, 2) end self.tex = t end
  function M:SetThickness(v) if type(v) ~= "number" or v <= 0 then error("SetThickness", 2) end self.thick = v end
  function M:SetStartPoint(p, rel, x, y) if type(p) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then error("SetStartPoint", 2) end self.from = { x, y } end
  function M:SetEndPoint(p, rel, x, y) if type(p) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then error("SetEndPoint", 2) end self.to = { x, y } end
  if type(template) == "string" and template:find("Secure") then       -- (the client refuses these in a fight)
    f.attr, f.secure = {}, true
    for _, k in ipairs({ "Show", "Hide", "SetPoint", "ClearAllPoints", "SetSize", "SetFrameLevel", "SetFrameStrata" }) do
      local was = M[k]
      M[k] = function(self, ...) if InCombatLockdown() then error("ADDON_ACTION_BLOCKED " .. k, 2) end return was(self, ...) end
    end
    function M:SetAttribute(k, v) if InCombatLockdown() then error("ADDON_ACTION_BLOCKED SetAttribute", 2) end self.attr[k] = v end
    function M:GetAttribute(k) return self.attr[k] end
  end
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
click((function() for i = 1, count("switch") do if find("switch", i).a.text == "Live cards" then return find("switch", i) end end end)())
ok(D.Store().sw.cards == false and saveA.deck == saveB.deck and saveA.deck.sw.cards == false, "a switch is kept, in every addon's save")
click(find("gear"))
ok(count("card") == 0, "no cards now")
D.Preset(1)
ok(count("card") >= 2, "ALL: back")
-- sizes and shapes
D.Flip()
ok(T.DeckShape(D.W, D.H) == "landscape" and count("railapp") + count("app") >= 2 and count("card") >= 2, "flipped: wide, its icons and its cards")
D.Open("BiSTools:bosses")
ok(count("row") > 4, "the list at the left")
D.Flip()
ok(D.W == 300 and D.H == 520 and D.page == "BiSTools:bosses", "and back: its own size, the same page")
local rowsNow = count("row")
cx, cy = 100, 100
local corner = D.frame.corner
corner.scripts.OnMouseDown(corner, "LeftButton")
cx, cy = 100, -100
tick(0.1)
ok(D.H > 520 and count("row") > rowsNow, "the corner pulled down: taller, more rows", D.H)
cx = 5000 tick(0.1)
ok(T.DeckShape(D.W, D.H) == "landscape" and D.shape == "landscape" and D.Store().shape == "landscape", "pulled wider than tall: it IS the wide deck", D.W .. "x" .. D.H)
ok(D.Store().portrait.w == 300 and D.Store().portrait.h == 520, "and the tall one keeps the size it had", D.Store().portrait.w)
cx = 130 tick(0.1)
ok(D.shape == "portrait" and D.W < D.H, "back again: tall", D.W .. "x" .. D.H)
D.Size(400, 250) ok(D.shape == "portrait" and D.H >= D.W, "too small to be wide: it stays tall", D.W .. "x" .. D.H)
cx = 100 tick(0.1)
corner.scripts.OnMouseUp(corner, "LeftButton")
ok(D.grip == nil and D.Store().portrait.h == D.H, "let go: kept")
do  -- Arn's first look, 22 Nov: "when i drag to resize i cant let go"
  for _, w in ipairs(D.frame.pieces) do if w.scripts.OnMouseDown then ok(false, "a piece never takes the press (it is another box after the paint)", w.kind) end end
  ok(corner.mouse and corner.level > D.frame.level + 6 and not corner.scripts.OnDragStart, "the corner: its own frame, over the pieces")
  local down, keepB = true, _G.IsMouseButtonDown
  _G.IsMouseButtonDown = function() return down end
  cx, cy = 100, 100
  corner.scripts.OnMouseDown(corner, "LeftButton")
  local h0 = D.H
  cy = 40 tick(0.06)
  ok(D.grip and D.H ~= h0, "held: it follows")
  down = false
  tick(0.06)
  ok(D.grip == nil, "let go and never told: it ends by itself")
  local h1 = D.H
  cy = -400 tick(0.2)
  ok(D.H == h1, "and the mouse moves on alone")
  corner.scripts.OnMouseDown(corner, "RightButton") ok(D.grip == nil, "the other button: nothing")
  -- the deck dragged, the stop never told
  down = true
  D.frame.scripts.OnDragStart(D.frame)
  tick(0.06) ok(D.frame.moving, "dragged")
  down = false
  tick(0.06) ok(not D.frame.moving and not D.frame.isMoving, "let go and never told: it stays")
  _G.IsMouseButtonDown = keepB
  -- never over the screen, whatever the save says
  UIParent.GetWidth = function() return 1720 end
  UIParent.GetHeight = function() return 720 end
  local keepW, keepH = D.W, D.H
  D.Size(900, 5000) ok(D.H <= 720 / (D.frame.scale or 1) and D.H >= D.W, "tall: never over the screen", D.W .. "x" .. D.H)
  D.Flip("landscape") D.Size(9000, 386) ok(D.W <= 1720 / D.frame.scale and D.W > 1000, "wide: never over the screen", D.W)
  D.Store().landscape.w = 2466 D.Place("landscape") ok(D.W <= 1720 / D.frame.scale, "a save that is: cut down", D.W)
  corner.scripts.OnDoubleClick(corner) ok(D.W == 600 and D.H == 420, "a double-click: its normal size")
  D.Flip("portrait") corner.scripts.OnDoubleClick(corner) ok(D.W == 260 and D.H == 462, "the same standing up")
  UIParent.GetWidth, UIParent.GetHeight = nil, nil
  D.Size(keepW, keepH)
  -- it grows from its top left
  D.frame.GetLeft, D.frame.GetTop = function() return 300 end, function() return 800 end
  cx, cy = 100, 100
  corner.scripts.OnMouseDown(corner, "LeftButton")
  local p = D.frame.pts[1]
  ok(#D.frame.pts == 1 and p[1] == "TOPLEFT" and p[4] == 300 and p[5] == 800, "held by its top left: the corner stays under the mouse")
  corner.scripts.OnMouseUp(corner, "LeftButton")
  D.frame.GetLeft, D.frame.GetTop = nil, nil
  D.Place("portrait")
end
D.Size(260, 462)
-- a fight
click(find("back"))
fire("PLAYER_REGEN_DISABLED")
GAME.fight = true
ok(D.frame.alpha == D.FIGHT_ALPHA and D.frame.mouse == false, "a fight: barely there, the mouse goes through")
local any = false
for _, w in ipairs(D.frame.pieces) do if w.shown and w.mouse then any = true end end
ok(not any and not D.frame.corner.mouse and D.frame.strata == D.FIGHT_STRATA, "no piece takes a click, under the bars")
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
    for i = 1, count("app") do icons[find("app", i).tip:match("^[^%-]+")] = true end
    if not (find("appnext") and find("appnext").act) then break end
    click(find("appnext"))
  end
  local back = 0
  while find("appprev") and find("appprev").act and back < 60 do click(find("appprev")) back = back + 1 end
  ok(back >= 1 and (D.appSkip or 0) == 0 and not find("appprev").act, "and back again by <, to the first page", back)
  D.frame.scripts.OnMouseWheel(D.frame, -1) ok((D.appSkip or 0) > 0, "the wheel turns a page")
  D.frame.scripts.OnMouseWheel(D.frame, 1) ok((D.appSkip or 0) == 0, "and back")
  D.Store().sw.small = false D.Size(220, 400) D.page = "home" D.Paint()
  ok(find("find") and D.frame.find.shown and find("appinfo") and find("appinfo").a.text:find("^1 / %d"), "home: the search line on top, the page under the icons", find("appinfo") and find("appinfo").a.text)
  ok(find("find").pts[1][5] > find("card").pts[1][5], "over the cards")
  local e = D.frame.find
  e.text = "p1" e.scripts.OnTextChanged(e, true) D.Paint()
  local only = true
  for i = 1, count("app") do if not find("app", i).tip:lower():find("p1", 1, true) and i <= 6 then only = find("app", i).tip end end
  ok(only == true and count("app") >= 6 and find("app").tip:find("^P1") and count("card") == 0, "typed: what is called that, no cards in its way", tostring(only))
  e.text = "zzzz" e.scripts.OnTextChanged(e, true) D.Paint() ok(count("app") == 0, "nothing is called that")
  e.text = "p3" e.scripts.OnTextChanged(e, true) e.scripts.OnEnterPressed(e)
  ok(D.page == "BiSMany:p3" and D.appFind == nil, "Enter opens the first", D.page)
  click(find("back")) ok(D.frame.find.text == "" and count("app") > 1, "home again: whole") D.Store().sw.small = nil
  D.Size(220, 300)
  local ni = 0 for _ in pairs(icons) do ni = ni + 1 end
  ok(ni == #shownAppsForTest(), "the smallest deck: every icon by >", ni .. " of " .. #shownAppsForTest())
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
-- words that wrap are laid out as wrapping words (22 Nov: "dont like how stuff is cutoff")
do
  D.Register{ owner = "BiSWords", key = "p", name = "Words", page = { title = function() return "Words" end, text = function() return ("invite them all, or disband, "):rep(4) end, rows = function() return { { text = "a row" } } end } }
  D.W, D.H, D.shape = 260, 462, "portrait"
  for i = 1, 3 do
    D.page = "BiSWords:p" D.Paint()
    local w = find("text")
    ok(w and w.a.wrap == true and w.a.laid == true, "the words wrap, and are set while they do", i)
    ok(w.h >= 3 * 18, "the box is as high as its words", w.h)
    D.page = "home" D.Paint() D.page = "BiSTools:bosses" D.Paint()
    for _, p in ipairs(D.frame.pieces) do if p.shown and p.kind == "row" then ok(not p.a.wrap and not p.a.laid, "a row never wraps") break end end
  end
  D.page = "BiSWords:p" D.Paint()
  local w, said = find("row"), nil
  w.a.cut = true
  local keepT = _G.GameTooltip
  _G.GameTooltip = { SetOwner = function() end, SetText = function(_, t2) said = t2 end, Show = function() end, Hide = function() end }
  w.scripts.OnEnter(w)
  ok(said == "a row", "cut off: in full under the mouse", said)
  w.a.cut = nil said = nil w.scripts.OnEnter(w) ok(said == nil, "not cut off: no tip")
  w.scripts.OnLeave(w)
  _G.GameTooltip = keepT
  D.page = "home"
  -- an icon is a picture when there is one
  D.ART = D.ART or {}
  local first = D.Icons()[1][1]
  local keepA = D.ART[first.id]
  D.ART[first.id] = "Interface\\Icons\\INV_Misc_Map_01"
  D.Paint()
  local tile
  for _, p in ipairs(D.frame.pieces) do if p.shown and p.kind == "app" then tile = p break end end
  ok(tile and tile.pic and tile.pic.shown and tile.pic.tex == D.ART[first.id] and tile.a.text == "", "an icon is the game's picture")
  D.ART[first.id] = keepA
  D.Paint()
  ok(keepA or not tile.pic.shown, "none: its letters")
end
-- a search line, a row with a picture, and what every part of a page is told: the tab
do
  local words, entered, tabs = "", nil, {}
  local function seen(k) return function(tab) tabs[k] = tab return nil end end
  D.Register{ owner = "BiSFind", key = "p", name = "Find", page = {
    tabs = function() return { "ONE", "TWO" } end, big = seen("big"), keys = seen("keys"), text = seen("text"), hero = seen("hero"), say = seen("say"), boxes = seen("boxes"),
    find = function(tab) return tab == 1 and { hint = "a sound", get = function() return words end, set = function(v) words = v end, enter = function(v) entered = v end } or nil end,
    rows = function(tab) return { { text = "row " .. tab .. words, pic = "Interface\\Icons\\INV_Misc_Map_01" }, { text = "b", mark = "2" } } end } }
  local def = D.defs["BiSFind:p"]
  for _, s in ipairs({ { 260, 462 }, { 700, 460 } }) do
    D.W, D.H, D.shape, D.page, def.tab, words, entered = s[1], s[2], T.DeckShape(s[1], s[2]), "BiSFind:p", 1, "", nil
    D.Paint()
    local e = D.frame.find
    ok(find("find") and e and e.shown and e.hint.text == "a sound" and e.hint.shown, "the search line, with its hint", s[1])
    ok(find("row").pic.shown and find("row").pic.tex:find("Map") and find("row").c.text == "" and find("row", 2).c.text == "2", "a row's picture stands where its mark would")
    e.text = "bell" e.scripts.OnTextChanged(e, true)
    ok(words == "bell" and not e.hint.shown, "typed: said to the page at once")
    tick(2)
    ok(find("row").a.text == "row 1bell", "and painted at the next beat", find("row").a.text)
    e.scripts.OnEnterPressed(e) ok(entered == "bell", "Enter")
    words = "" D.Paint() ok(e.text == "", "emptied by the page: empty")
    def.tab = 2 D.Paint()
    ok(not e.shown and not find("find") and find("row").a.text == "row 2", "a tab without one: gone")
    ok(tabs.big == 2 and tabs.keys == 2 and tabs.text == 2 and tabs.hero == 2 and tabs.say == 2 and tabs.boxes == 2, "every part is told the tab")
    def.tab = 1 D.Paint() ok(e.shown, "and back")
    D.fight = true D.Paint() ok(not e.shown, "a fight: gone") D.fight = false
    D.page = "home" D.Paint() ok(e.shown and e.hint.text == "search your apps" and e.text == "", "home: its own")
  end
end
-- nothing is cut off: the title a size down when the game says it is too wide, a long row in two lines
do
  D.Register{ owner = "BiSLong", key = "p", name = "Long", page = { title = function() return "A very long title indeed" end, kicker = function() return "first time here" end,
    rows = function() return { { text = ("word "):rep(12) }, { text = "short" } } end } }
  D.W, D.H, D.shape, D.page = 260, 462, "portrait", "BiSLong:p"
  D.Paint()
  D.defs["BiSLong:p"].page.say = function() return ("gold, you are told "):rep(4) end
  D.defs["BiSLong:p"].page.boxes = function() return { { "KILLED YOU", -0 } } end
  D.Paint()
  ok(find("say").a.wrap and find("say").h == 2 * T.DECK_L.SAY, "the line under a list: as many lines as it says", find("say").h)
  ok(find("box").a.text == "0", "nothing is 0, not -0", find("box").a.text)
  ok(find("row").a.wrap and find("row").h == T.DECK_L.ROW2 and find("row", 2).h == T.DECK_L.ROW and not find("row", 2).a.wrap, "a long row: two lines")
  -- a row with a line of its own under its name: two high, the name in its own ink and never wrapped, the picture bigger
  do
    local keep = D.defs["BiSLong:p"].page.rows
    D.defs["BiSLong:p"].page.rows = function() return { { pic = 5, text = "Relentless Chain", sub = "level 46, waist", right = "DMg", tint = "epic" }, { mark = "-", text = "plain" } } end
    D.Paint()
    local r, r2 = find("row"), find("row", 2)
    ok(r.h == T.DECK_L.ROW2 and r2.h == T.DECK_L.ROW and r.a.text == "Relentless Chain" and r.c.text == "level 46, waist" and r.b.text == "DMg", "its line, and what stands at its right", r.h)
    ok(not r.a.wrap and r.a.tone == "epic" and r.pic.w == 28 and r2.c.text == "-" and r2.a.tone == "ink", "in its own ink, the next row as ever", r.pic.w)
    D.defs["BiSLong:p"].page.rows = keep
    D.Paint()
    ok(find("row").a.wrap and find("row").a.tone == "ink", "and the piece is a long row again")
  end
  -- a first-time page wide: its list as high as its words, the word they all share not said at every one
  do
    D.Register{ owner = "BiSTour", key = "p", name = "Tour", page = { rows = function() return { { text = "x" } } end,
      steps = function() return { { phase = "HELLO", text = ("word "):rep(19) }, { phase = "HELLO", text = "short" } } end } }
    local W0, H0, S0 = D.W, D.H, D.shape
    D.W, D.H, D.shape, D.page = 443, 314, "landscape", "BiSTour:p"
    D.Paint()
    local a, b = find("step"), find("step", 2)
    ok(a and b and a.h >= T.DECK_L.ROW + 3 * T.DECK_L.LINE2 and b.h == T.DECK_L.ROW and a.b.text == "" and a.a.wrap, "as high as its words", a and a.h)
    ok(a.most == nil or a.most >= 4, "and no more lines than it is high", a.most)
    D.W, D.H, D.shape, D.page = W0, H0, S0, "BiSLong:p"
    D.Paint()
  end
  -- one huge number with its breakdown on hover, and lines of icons under it
  do
    local pressed
    D.Register{ owner = "BiSNum", key = "p", name = "Num", page = { tour = nil, rows = function() return { { text = "TRY", sub = "new", icons = { { pic = 7, word = "SoE", act = { word = "x", spell = "Totem" } }, { pic = 8, word = "GoA", act = { word = "x", peek = true, fn = function() pressed = "row" end } } } }, { text = "a" } } end, tabs = function() return { "A", "B" } end,
      hero = function() return { art = "number", big = "77", small = "WF + FT", right = "last 74", under = "5 fights", tip = "The breakdown", lines = { { "Windfury", "12%" }, { "Best", "90" } }, peek = true, fn = function() pressed = "hero" end } end,
      icons = function() return { { { pic = 1, word = "Flametongue", act = { word = "x", peek = true, fn = function() pressed = "fire" end } }, { word = "Water" } }, { { pic = 2, word = "ELEMENTS", lit = true, act = { word = "x", spell = "Call" } } } } end } }
    local W0, H0, S0 = D.W, D.H, D.shape
    D.W, D.H, D.shape, D.page = 260, 462, "portrait", "BiSNum:p"
    D.Paint()
    local hw, i1, i2 = find("hero"), find("icon"), find("icon", 3)
    ok(hw.a.text == "77" and hw.a.size >= 40 and hw.b.text == "last 74" and hw.e1.text == "5 fights" and hw.h >= 72, "a huge number", hw.a.size)
    ok(i1.c.text == "Flametongue" and i1.pic.w == i1.h - 16 and find("icon", 2).a.text == "-" and i2.lit and i2.sec and i2.sec.spell == "Call", "its icons, with their names; one that casts is secure")
    local tip, dbl = nil, {}
    local GT = _G.GameTooltip
    _G.GameTooltip = setmetatable({ SetOwner = function() end, SetText = function(_, s) tip = s end, AddDoubleLine = function(_, a, b) dbl[#dbl + 1] = a .. " " .. b end, Show = function() end, Hide = function() end }, { __index = GT })
    hw:GetScript("OnEnter")(hw)
    ok(tip == "The breakdown" and dbl[1] == "Windfury 12%" and #dbl == 2, "hover: the breakdown", dbl[1])
    _G.GameTooltip = GT
    i1.act() ok(pressed == "fire", "an icon's press")
    local rr, n = find("row"), 0
    ok(rr.h >= 30 and rr.h <= 40 and rr.a.text == "TRY" and rr.c.text == "new" and find("row", 2).h == T.DECK_L.ROW and find("row", 2).a.text == "a", "a row that is a line of icons", rr.h)
    for _, w in ipairs(D.frame.pieces) do if w:IsShown() and w.kind == "icon" and w.c.text == "GoA" then n = n + 1 w.act() end if w:IsShown() and w.kind == "icon" and w.c.text == "SoE" then ok(w.sec and w.sec.spell == "Totem", "one of them casts") end end
    ok(n == 1 and pressed == "row", "each its own press")
    hw.act() ok(pressed == "hero", "and the number's")
    D.Store().sw.hero = false D.Paint() ok(find("hero") and find("hero").a.text == "77", "pictures off: the number stays") D.Store().sw.hero = nil
    D.page = "BiSLong:p" D.W, D.H, D.shape = W0, H0, S0
    D.Paint()
    for _, w in ipairs(D.frame.pieces) do if w.e1 and w:IsShown() then ok(not w.e1:IsShown(), "its extra words gone with it") end end
  end
  -- the smallest icons say their names too, very small (Arn, 22 Nov: "small names on the new small icons")
  do
    local W0, H0, S0 = D.W, D.H, D.shape
    for i = 1, 30 do D.Register{ owner = "BiSMany", key = "a" .. i, name = "Many " .. i, page = { text = function() return "x" end } } end
    D.W, D.H, D.shape, D.page, D.appSkip = 260, 400, "portrait", "home", nil
    D.Paint()
    local a = find("app")
    ok(a and a.h == 42 and a.c.text ~= "" and a.c.size <= 9, "a small icon has its name", a and a.c.text .. " " .. tostring(a.c.size) .. " " .. a.h)
    for i = 1, 30 do D.defs["BiSMany:a" .. i] = nil end
    D.W, D.H, D.shape, D.page = W0, H0, S0, "BiSLong:p"
    D.Paint()
  end
  local ti = find("title")
  ti.a.GetUnboundedStringWidth = function(self) return #self.text * self.size * 0.5 end
  D.Paint()
  ok(find("title").a.size == 17, "a long title: a size down", find("title").a.size)
  ti.a.GetUnboundedStringWidth = nil
  -- a live card's words have all the room the number leaves, and a size down before they are cut ("Boat to the Rivergl...")
  do
    D.Register{ owner = "BiSLong", key = "c", name = "Boat", order = 0.1, card = { prio = function() return 9 end, lines = function() return { "RIDES", "", "Boat to the Riverglades", "2:56", "gold" } end } }
    D.page = "home" D.Paint()
    local function card() for k = 1, count("card") do local w = find("card", k) if w.a.text == "Boat to the Riverglades" then return w end end end
    local w = card()
    ok(w and w.a.size == 16, "nothing said about widths: the everyday size", w and w.a.size)
    local at
    for _, q in ipairs(w.a.pts) do if q[1] == "TOPRIGHT" then at = q end end
    ok(at and at[2] == w.b and at[3] == "TOPLEFT", "the words end where the number begins")
    w.a.GetUnboundedStringWidth = function(self) return #self.text * self.size * 0.62 end
    w.b.GetUnboundedStringWidth = function() return 34 end
    D.Paint()
    ok(card().a.size < 16, "too wide: a size down", card().a.size)
    w.a.GetUnboundedStringWidth, w.b.GetUnboundedStringWidth = nil, nil
    D.defs["BiSLong:c"] = nil
  end
  D.page = "home" D.Paint()
end
-- A RIGHT-CLICK HIDES A LIVE TILE (Arn, 22 Nov: "hides it until next time it needs to say something")
do
  local p, words, ticks, opened = 7, "Time to eat", 0, 0
  local cancelled, tick
  local keepC = _G.C_Timer
  _G.C_Timer = { NewTicker = function(_, fn) tick = fn return { Cancel = function() cancelled = true end } end, After = keepC and keepC.After }
  D.Register{ owner = "BiSHush", key = "c", name = "Hush", order = 0.1, open = function() opened = opened + 1 end,
    card = { prio = function() return p end, lines = function() ticks = ticks + 1 return { "XP", "", words, ticks .. " s", "gold" } end, buttons = function() return { { word = "DO", fn = function() end } } end } }
  D.W, D.H, D.shape, D.page = 300, 700, "portrait", "home"
  local function tile() D.Paint() for k = 1, count("card") do local w = find("card", k) if w.a.text == words or w.c.text and w.c.text:find("XP", 1, true) then return w end end end
  local w = tile()
  ok(w and w.hush and w.tip:find("Right%-click"), "a tile says what a right-click does")
  w.scripts.OnClick(w, "RightButton")
  ok(opened == 0 and not tile(), "right-clicked: hidden, and not opened")
  ok(not tile() and D.Mine().hush["BiSHush:c"], "its number ticks on: still hidden, kept for the next login")
  words = "Time to rest" ok(tile(), "other words: back")
  w = tile() w.scripts.OnClick(w, "RightButton") ok(not tile(), "hidden again")
  p = 9 ok(tile(), "more urgent: back") p = 7
  w = tile() w.scripts.OnClick(w, "RightButton") ok(not tile(), "hidden again")
  p = nil tick() p = 7 ok(tile(), "nothing to say, then the same again (with the phone shut): back")
  w = tile()
  for k = 1, count("cardbtn") do local b = find("cardbtn", k) if b.a.text == "DO" then b.scripts.OnClick(b, "RightButton") end end
  ok(not tile(), "a right-click on its button: the same")
  tick() ok(not tile(), "it still says the same: still hidden")
  D.HushEnd("BiSHush:c") ok(tile(), "called back")
  tick() ok(cancelled, "none hidden: no look")
  D.hushTick = nil
  for k = 1, count("app") do local x = find("app", k) if x then x.scripts.OnClick(x, "RightButton") break end end
  ok(D.page == "home", "a right-click on an icon does nothing")
  D.defs["BiSHush:c"] = nil
  _G.C_Timer = keepC
end
-- what can be pressed looks like it (Arn, 22 Nov: "this is clickable or this is just information"), and boxes in two lines
do
  local hits = 0
  D.Register{ owner = "BiSChip", key = "p", name = "Chip", page = {
    boxes = function() local o = {} for i = 1, 8 do o[i] = { "BOX " .. i, i } end return o end,
    rows = function() return { { text = "Frostbrand Weapon", verb = "IMBUE", act = { word = "CAST", spell = "Frostbrand Weapon" } }, { text = "Magma Totem", act = { word = "CAST", spell = "Magma Totem" } },
      { text = "Procs", right = "5 WF" }, { text = "Open it", right = "12", act = { word = "open", fn = function() hits = hits + 1 end } },
      { text = "A switch", right = "ON", ink = "good", act = { word = "switch", chip = true, fn = function() end } }, { text = "TRY NEXT", head = true }, { text = "Gone", side = { word = "X", fn = function() end } } } end } }
  D.W, D.H, D.shape, D.page = 260, 520, "portrait", "BiSChip:p"
  D.Paint()
  local function row(i) return find("row", i) end
  ok(row(1).v.shown and row(1).v.text == "IMBUE" and row(2).v.text == "CAST", "what it does stands on its chip")
  ok(not (row(3).v and row(3).v.shown) and row(3).b.text == "5 WF" and not row(3).act, "just information: no chip")
  ok(row(4).v.text == ">" and row(4).b.text == "12", "pressed for more: >, its number beside it")
  ok(row(5).v.text == "ON" and row(5).b.text == "", "a switch: its value is the chip")
  ok(row(6).a.col ~= row(1).a.col or row(6).a.size == 11, "a heading")
  ok(not (row(7).v and row(7).v.shown) and count("side") == 1, "a key of its own: no chip")
  click(row(4)) ok(hits == 1, "pressed")
  ok(count("box") == 8 and find("box", 8).a.text == "8" and find("box", 5).pts[1][5] < find("box", 1).pts[1][5], "eight boxes: two lines")
  D.page = "home" D.Paint() D.page = "BiSTools:bosses" D.Paint()
  for _, p in ipairs(D.frame.pieces) do if p.shown and p.v and p.v.shown and p.kind ~= "row" then ok(false, "a chip left behind on a " .. p.kind) end end
  D.page = "home"
end
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
  local grip = D.frame.corner
  grip.scripts.OnMouseDown(grip) cx, cy = 5040, -140 tick(0.1) grip.scripts.OnMouseUp(grip)
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
  ok(wc and wc.b.text:find(" / 10", 1, true), "a card says how far you are", wc and wc.b.text)
  D.Hide() D.Show()
  ok(D.page == "home", "it never opens by itself again", D.page)
  click(wc)
  ok(D.page == "BiSDeck:welcome" and find("steptext").a.text:find("^Dark is the clean"), "the card goes on where you were", find("steptext") and find("steptext").a.text)
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

-- LIVE CARDS AND PULLING THEM OUT (Arn, 22 Nov: "they open farm app they click around in it it'll show up as a live card if it makes
-- sense if they just looks at it and exit they just took a peek ... drag it out and pin it to their screen ... they close it and
-- goes back to the phone, if they want to see more it opens the app on the phone")
do
  local over, down, guid, fired = false, true, "Player-1", {}
  _G.UnitGUID = function() return guid end
  _G.IsMouseButtonDown = function() return down end
  assert(loadfile("DeckPins.lua"))()
  local mob, stopped, n = nil, 0, 3
  local farm = D.Register{ owner = "BiSFarm", key = "farm", name = "Farm", icon = "Fa", order = 2,
    card = { when = "use", tick = true, alive = function() return mob ~= nil end, prio = function() return 6 end,
      lines = function() return { "FARM", "", mob, n .. " up", "good" } end,
      buttons = function() return { { word = "STOP", fn = function() mob = nil stopped = stopped + 1 end }, { word = "SPOTS", peek = true, fn = function() fired.spots = true end }, { word = "TARGET", macro = "/target x" } } end },
    page = { tabs = function() return { "MOBS", "SPOTS" } end,
      rows = function() return { { text = "Magra", act = { word = "farm", fn = function() mob = "Magra" end } }, { text = "Look", act = { word = "look", peek = true, fn = function() fired.look = true end } } } end,
      keys = function() return { { word = "NOTHING", fn = function() end } } end } }
  local def = D.defs["BiSFarm:farm"]
  D.Store().apps = {} D.SetTheme("dark") D.page = "home" D.Show() D.Flip("portrait") D.Size(300, 700)
  local function card(title) for i = 1, count("card") do local w = find("card", i) if w.c.text and w.c.text:find(title, 1, true) then return w end end end
  ok(not card("FARM"), "never opened: no card")
  D.Open("BiSFarm:farm") click(find("tab", 2)) click(find("tab", 1)) click(find("row", 2))
  click(find("back"))
  ok(fired.look and not card("FARM"), "opened, looked at, left: a peek, no card")
  mob = "Magra"                                             -- (farmed already, from the old window)
  D.Open("BiSFarm:farm") click(find("tab", 2)) click(find("row", 2)) click(find("back"))
  ok(not card("FARM"), "a peek while it runs: still no card")
  mob = nil
  D.Open("BiSFarm:farm") click(find("key")) click(find("back"))
  ok(not card("FARM"), "pressed something, but there is nothing to show: still none")
  D.Open("BiSFarm:farm") click(find("row", 1))
  ok(find("kicker").a.text:find("LIVE", 1, true), "used: the page says it is live", find("kicker").a.text)
  click(find("back"))
  ok(card("FARM") and card("FARM").a.text == "Magra" and card("FARM").b.text == "3 up", "used: it has a live card", card("FARM") and card("FARM").a.text)
  n = 2 tick(2)
  ok(card("FARM").b.text == "2 up", "its words follow the clock", card("FARM").b.text)
  guid = "Player-2" D.Paint()
  ok(not card("FARM"), "another character: not theirs")
  guid = "Player-1" D.Paint()
  ok(card("FARM"), "back: still live")
  -- nothing of a card covers another piece of it
  local function keysOf(kind) local out = {} for _, w in ipairs(D.frame.pieces) do if w.shown and w.kind == kind then out[#out + 1] = w end end return out end
  ok(#keysOf("cardout") >= 1 and #keysOf("cardend") == 1, "OUT on every card, x on the one you made live", #keysOf("cardout") .. " " .. #keysOf("cardend"))
  for _, kind in ipairs({ "cardout", "cardend" }) do for _, w in ipairs(keysOf(kind)) do ok(w.w >= 24 and w.h >= 22, "big enough to hit", w.w .. "x" .. w.h) end end
  -- x ends it
  click(keysOf("cardend")[1])
  ok(not card("FARM") and mob == "Magra", "x: the card goes, the farming does not")
  D.Open("BiSFarm:farm") click(find("row", 1)) click(find("back"))
  ok(card("FARM"), "used again: there again")
  -- dragged out
  local w = card("FARM")
  cx, cy = 500, 400
  w.scripts.OnDragStart(w)
  local pf = D.pinFrames["BiSFarm:farm"]
  ok(pf and pf.shown and pf.isMoving and D.IsPinned("BiSFarm:farm"), "dragged: it comes out under the mouse")
  do  -- its own lines, under its words
    local keepL = def.card.lines
    local h0 = pf.h
    def.card.lines = function() return { "FARM", "", mob, "3 up", "good", list = { { "timed by Frankadank Sithlord", "0% sure" }, { "Spot 2", "0:40" } } } end
    D.PinPaint("BiSFarm:farm")
    ok(pf.l1.shown and pf.l1.a.text == "timed by Frankadank Sithlord" and pf.l1.b.text == "0% sure" and pf.l2.shown and not pf.l3.shown and pf.h == h0 + 2 * D.PIN_LINE + 4 and pf.b1.shown, "pulled out: its own lines too", pf.h)
    def.card.lines = keepL
    D.PinPaint("BiSFarm:farm")
    ok(not pf.l1.shown and pf.h == h0, "none: as small as before")
  end
  ok(pf.parent == UIParent, "its own frame, not the deck's")
  ok(w.shown and w.kind == "card", "the deck is not painted under the drag (the dragged piece must hear its end)")
  w.scripts.OnDragStop(w)
  ok(not pf.isMoving and D.Pins()["BiSFarm:farm"][4] == 12 and D.pinHeld == nil, "let go: it stays there, kept")
  ok(card("FARM") and card("FARM").a.text == "On your screen" and #keysOf("cardout") >= 1, "the deck: a slot that says so, never twice", card("FARM") and card("FARM").a.text)
  ok(pf.body.a.text == "Magra" and pf.b1.shown and pf.b1.a.text == "STOP" and pf.b2.a.text == "SPOTS" and not pf.b3.shown, "it shows the card and its plain buttons, not the secure one", pf.body.a.text)
  click(pf.b2)
  ok(fired.spots and mob == "Magra", "its buttons work")
  n = 5 D.pinRoot.scripts.OnUpdate(D.pinRoot, 1.1)
  ok(pf.body.b.text == "5 up", "it lives on its own beat", pf.body.b.text)
  D.Hide()
  ok(pf.shown, "the deck closed: it stays")
  n = 4 D.pinRoot.scripts.OnUpdate(D.pinRoot, 1.1)
  ok(pf.body.b.text == "4 up", "and lives on")
  click(pf.open)
  ok(D.frame.shown and D.page == "BiSFarm:farm", "OPEN: the app, on the deck")
  D.page = "home" D.Hide()
  click(pf.body)
  ok(D.frame.shown and D.page == "BiSFarm:farm", "a click on it: the same")
  -- a fight
  GAME.fight = true fire("PLAYER_REGEN_DISABLED")
  ok(pf.shown and pf.alpha == D.PIN_FIGHT and pf.mouse == false and pf.body.mouse == false and pf.x.mouse == false, "a fight: readable, clicks go through")
  pf.scripts.OnDragStart(pf)
  ok(not pf.isMoving, "and it does not move")
  D.Store().sw.pinfight = false D.PinsPaint()
  ok(not pf.shown, "the switch: gone in a fight")
  GAME.fight = false fire("PLAYER_REGEN_ENABLED")
  ok(pf.shown and pf.alpha == 1 and pf.mouse == true, "after it: back")
  D.Store().sw.pinfight = nil
  pf.scripts.OnDragStart(pf) ok(pf.isMoving, "dragged again")
  GAME.fight = true fire("PLAYER_REGEN_DISABLED")
  ok(not pf.isMoving and D.pinHeld == nil, "a pull ends the drag")
  GAME.fight = false fire("PLAYER_REGEN_ENABLED")
  pf.scripts.OnDragStart(pf) down = false D.pinRoot.scripts.OnUpdate(D.pinRoot, 0.1)
  ok(not pf.isMoving and D.pinHeld == nil, "a button let go that nobody told us about: the drag ends") down = true
  -- themes
  D.SetTheme("light")
  ok(pf.bg.r > 0.9 and pf.body.a.col < 0.2, "it wears the theme", pf.bg.r)
  D.SetTheme("dark")
  -- closed: back
  D.page = "home" D.Show()
  click(pf.x)
  ok(not pf.shown and not D.IsPinned("BiSFarm:farm") and card("FARM") and card("FARM").a.text == "Magra", "x: back in the deck, still live")
  -- OUT without dragging (the pad, the keyboard); dropped on the deck = back
  click(keysOf("cardout")[1])
  local any for id in pairs(D.Pins()) do any = id end
  ok(any, "OUT does what the drag does", any)
  D.PinBack(any)
  w = card("FARM") w.scripts.OnDragStart(w)
  over = true
  D.frame.IsMouseOver = function() return over end
  w.scripts.OnDragStop(w)
  ok(not D.IsPinned("BiSFarm:farm") and not pf.shown, "dropped on the deck: back in it")
  over = false
  -- nothing left: the card and the pin go by themselves
  D.PinOut("BiSFarm:farm")
  ok(pf.shown, "out again")
  click(pf.b1)
  ok(stopped == 1 and not pf.shown and not D.IsPinned("BiSFarm:farm"), "STOP: nothing to show any more, the pin goes")
  D.page = "home" D.Paint()
  ok(not card("FARM"), "and the card")
  -- nothing to say for now: hidden, its place kept
  local rideUp = true
  D.Register{ owner = "BiSRide", key = "ride", name = "Ride", order = 3, card = { prio = function() return rideUp and 5 or nil end, lines = function() return { "RIDES", "", "Boat", "0:58", "gold" } end }, page = { rows = function() return {} end } }
  D.PinOut("BiSRide:ride")
  local rf = D.pinFrames["BiSRide:ride"]
  ok(rf.shown and not rf.b1.shown, "a card with no buttons")
  rideUp = false D.pinRoot.scripts.OnUpdate(D.pinRoot, 1.1)
  ok(not rf.shown and D.IsPinned("BiSRide:ride"), "nothing to say: it steps aside, its place is kept")
  rideUp = true D.pinRoot.scripts.OnUpdate(D.pinRoot, 1.1)
  ok(rf.shown, "and comes back")
  -- switched off, and the next login
  D.Off(true)
  ok(not rf.shown and D.pinRoot.scripts.OnUpdate == nil, "the deck's tool off: nothing on the screen, nothing runs")
  D.Off(false)
  ok(rf.shown and D.pinRoot.scripts.OnUpdate ~= nil, "on: back")
  rf:Hide() D.Hide()
  fire("PLAYER_LOGIN")
  ok(rf.shown and not D.frame.shown, "the next login: the pin is back, the deck stays closed")
  D.PinBack("BiSRide:ride")
  ok(D.pinRoot.scripts.OnUpdate == nil, "no pins: no beat")
  ok(secureMade == 0, "still nothing secure", secureMade)
  -- when a card may come: the Apps page
  D.Show() D.Open("BiSDeck:apps") D.Size(400, 760)
  click(find("tab", 2))
  local function row(name) for i = 1, count("row") do local x = find("row", i) if x.a.text == name then return x end end end
  ok(row("Farm") and row("Farm").b.text == "AFTER USE" and row("Ride").b.text == "BY ITSELF", "LIVE CARDS: when each may come", row("Farm") and row("Farm").b.text)
  click(row("Ride")) ok(row("Ride").b.text == "NEVER", "a click: never")
  D.page = "home" D.Paint() ok(not card("RIDES"), "and it is gone")
  D.Open("BiSDeck:apps") click(row("Ride")) ok(row("Ride").b.text == "AFTER USE", "again: after use") click(row("Ride")) ok(row("Ride").b.text == "BY ITSELF" and D.Store().cardWhen["BiSRide:ride"] == nil, "and by itself again")
  -- a long time
  mob = "Magra" D.Used(def) ok(D.IsLive(def), "live")
  GAME.now = GAME.now + D.LIVE_KEEP + 10
  ok(not D.IsLive(def), "half a day later: not any more")
  -- - and + on a row
  local val = 5
  D.Register{ owner = "BiSStep", key = "s", name = "Step", page = { rows = function() return { { text = "radius", right = tostring(val), less = { word = "-", fn = function() val = val - 1 end }, more = { word = "+", fn = function() val = val + 1 end } } } end } }
  D.Open("BiSStep:s")
  click(find("plus")) click(find("plus")) click(find("less"))
  ok(val == 6 and find("row").b.text == "6", "- and +", val)
  ok(find("less").w >= 24 and find("plus").w >= 24, "big enough")
  -- a tool that is off is in the Apps page, not on home
  local toolOn = false
  D.Register{ owner = "BiSQuiet", key = "q", name = "Quiet", order = 1, quietOff = true, about = "It is quiet.", state = function() return toolOn and "on" or "off" end, turnOn = { word = "TURN ON", fn = function() toolOn = true end }, page = { rows = function() return {} end } }
  D.page = "home" D.Paint()
  local function icon(name) for i = 1, count("app") do if find("app", i).c.text == name then return true end end end
  ok(not icon("Quiet"), "off: not on home")
  D.Open("BiSDeck:apps") click(find("tab", 1))
  ok(row("Quiet") and row("Quiet").b.text == "OFF", "but in the Apps page")
  click(row("Quiet"))
  ok(D.page == "BiSQuiet:q" and find("big").a.text == "TURN ON", "a click: what it is, TURN ON")
  click(find("big")) D.page = "home" D.Paint()
  ok(icon("Quiet"), "on: on home")
  for _, id in ipairs({ "BiSFarm:farm", "BiSRide:ride", "BiSStep:s", "BiSQuiet:q" }) do D.defs[id] = nil end
  D.sorted = nil D.page = "home"
end

-- THE SIGNS (Arn, 22 Nov: "the signal strength does something WiFi guild communication battery something n else")
do
  local net = { 10, 20, 35, 42 }
  local lib = { enabled = true, peers = {}, vers = {} }
  function lib:Enabled() return self.enabled end
  local locked, rest, xpMax, xpRest, level, worn = false, false, 10000, 7500, 31, { [1] = { 80, 100 }, [5] = { 45, 50 } }
  local gearAsks = 0
  _G.GetNetStats = function() return net[1], net[2], net[3], net[4] end
  _G.GetFramerate = function() return 59.6 end
  _G.C_ChatInfo = { InChatMessagingLockdown = function() return locked end }
  _G.UnitXPMax = function() return xpMax end
  _G.GetXPExhaustion = function() return xpRest end
  _G.UnitLevel = function() return level end
  _G.GetMaxPlayerLevel = function() return 60 end
  _G.GetInventoryItemDurability = function(slot) gearAsks = gearAsks + 1 local g = worn[slot] if g then return g[1], g[2] end end
  _G.C_Container = { GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end, GetContainerNumFreeSlots = function(b) return b == 0 and 4 or 0, 0 end }
  _G.IsResting = function() return rest end
  assert(loadfile("DeckStatus.lua"))()
  _G.LibBiSComm = lib
  ok(D.Bars(30) == 4 and D.Bars(120) == 3 and D.Bars(250) == 2 and D.Bars(900) == 1 and D.Bars(nil) == 0, "signal: fewer bars, slower")
  ok(D.Ping() == 42, "the worse of home and world", D.Ping())
  ok(D.Arcs(D.Net()) == 1, "WiFi: on, nobody heard: one arc")
  lib.peers["Moo"] = {} lib.vers["Moo"] = {} lib.vers["Sue"] = {}
  ok(D.Net().n == 2 and D.Arcs(D.Net()) == 2, "two heard, nobody counted twice", D.Net().n)
  lib.vers["A"], lib.vers["B"] = {}, {}
  ok(D.Arcs(D.Net()) == 3, "four: all of it")
  locked = true ok(D.Net().state == "paused", "a chat lockdown: paused") locked = false
  lib.enabled = false ok(D.Net().state == "off" and D.Arcs(D.Net()) == 0, "switched off") lib.enabled = true
  _G.LibBiSComm = nil ok(D.Net().state == "none", "no library") _G.LibBiSComm = lib
  local b = D.Battery(false)
  ok(b.kind == "rested" and b.pct == 50 and not b.low and not b.charging, "battery while leveling: rested XP, 100 = a level and a half", b.kind .. " " .. tostring(b.pct))
  ok(D.Battery(true).charging, "resting: it charges")
  xpRest = nil ok(D.Battery(false).pct == 0 and not D.Battery(false).low, "no rested XP: empty, and that is no alarm") xpRest = 7500
  level = 60 ok(D.Battery(false).kind == "gear" and D.Battery(false).pct == 80, "top level: the worst piece of gear", D.Battery(false).pct) level = 31
  worn[5] = { 5, 50 } ok(D.Battery(false).kind == "rested", "(gear is asked again only when the game says it changed)")
  fire("UPDATE_INVENTORY_DURABILITY")
  ok(D.Battery(false).kind == "gear" and D.Battery(false).pct == 10 and D.Battery(false).low, "gear about to break always wins, low", D.Battery(false).pct)
  worn[5] = { 45, 50 } fire("UPDATE_INVENTORY_DURABILITY")
  local asks = gearAsks D.Status() local once = gearAsks - asks D.Status() ok(gearAsks - asks == once, "then not asked again", gearAsks - asks)
  -- hidden answers are no answers
  local keepNet = _G.GetNetStats
  local sec = {}
  _G.issecretvalue = function(v) return v == sec end
  _G.GetNetStats = function() return sec, sec, sec, sec end
  ok(D.Ping() == nil and D.Bars(D.Ping()) == 0, "a hidden ping: no bars, no error")
  _G.GetNetStats = keepNet _G.issecretvalue = nil
  -- drawn
  D.SetTheme("dark") D.Store().sw = {} D.page = "home" D.Show() D.Flip("portrait") D.Size(260, 462)
  local w = find("status")
  ok(w and w.act and w.tip:find("Connection 42 ms", 1, true) and w.tip:find("4 heard", 1, true) and w.tip:find("Rested XP 50%", 1, true), "the signs, and their words", w and w.tip)
  ok(w.a.text == "50", "the battery's number", w.a.text)
  local function lit(i) return w.bits[i].r > 0.8 end
  ok(lit(1) and lit(4), "four bars lit")
  net[4] = 250 D.Paint() ok(lit(2) and not lit(3), "slower: two")
  net[4] = 42
  for _, t in pairs(w.bits) do if t.shown then ok(t.pts[1][4] >= 0 and t.pts[1][4] + t.w <= w.w and -t.pts[1][5] >= 0 and -t.pts[1][5] + t.h <= w.h, "a sign stays inside its place", t.pts[1][4] .. " " .. t.w) end end
  for _, t in pairs(w.lines) do if t.shown then ok(t.from[1] >= 0 and t.to[1] <= w.w and -t.from[2] >= 0 and -t.from[2] <= w.h, "an arc too") end end
  local struck = w.lines[13]
  ok(not (struck and struck.shown), "WiFi on: no stroke")
  lib.enabled = false D.Paint() ok(w.lines[13].shown, "off: a stroke through it") lib.enabled = true D.Paint() ok(not w.lines[13].shown, "and gone again")
  local ck = find("clock")
  ok(not (ck.bits and ck.bits[21] and ck.bits[21].shown), "not resting: no bed")
  rest = true D.Paint() ok(find("clock").bits[21].shown and find("status").tip:find("Resting", 1, true), "resting: the bed, and it says so") rest = false
  -- the page
  click(find("status"))
  ok(D.page == "BiSDeck:status" and find("title").a.text == "Status" and find("box", 1).a.text == "42", "a click: the Status page", D.page)
  D.Size(300, 700)
  local function row(name) for i = 1, count("row") do local x = find("row", i) if x.a.text == name then return x end end end
  ok(row("Connection").b.text == "42 ms" and row("Frames a second").b.text == "60" and row("Free bag slots").b.text == "4 (25%)" and row("BiS network").b.text == "4 heard" and row("Moo").b.text == "in your group" and row("Sue").b.text == "heard", "in words and numbers", row("Free bag slots").b.text)
  click(row("Battery shows")) ok(D.BatteryPick() == "rested") click(row("Battery shows")) ok(D.BatteryPick() == "gear" and find("status").a.text == "80", "Battery shows: your pick", find("status").a.text)
  click(row("Battery shows")) ok(D.BatteryPick() == "bags" and find("status").a.text == "25", "bags") click(row("Battery shows")) ok(D.BatteryPick() == "auto" and D.Store().battery == nil, "auto again")
  click(find("status")) ok(D.page == "home", "again: home")
  for i = 1, count("app") do ok(find("app", i).c.text ~= "Status", "no icon of its own") end
  -- a piece used for something else keeps no sign
  D.Store().sw.signs = false D.Paint()
  local left = 0
  for _, p in ipairs(D.frame.pieces) do if p.kind ~= "status" and p.kind ~= "clock" then for _, t in pairs(p.bits or {}) do if t.shown and p.shown then left = left + 1 end end for _, t in pairs(p.lines or {}) do if t.shown and p.shown then left = left + 1 end end end end
  ok(not find("status") and left == 0, "switched off: gone, nothing left behind", left)
  D.Store().sw.signs = nil D.Paint()
  local made0 = #made D.Paint() ok(#made == made0, "painted again: nothing new is made", #made - made0)
  -- read aloud
  local spoke
  _G.C_VoiceChat = { SpeakText = function(_, words) spoke = words end }
  D.Store().easy = { speak = true } D.spoken = nil
  w = find("status") w.scripts.OnEnter(w)
  ok(spoke and spoke:find("Connection 42 ms", 1, true), "read aloud: what they mean", spoke)
  D.Store().easy = {}
  -- the clock and the signs move on by themselves
  net[4] = 130 for _ = 1, 11 do tick(1.01) end
  ok(find("status").tip:find("130 ms", 1, true), "looked at again every ten seconds", find("status").tip)
  _G.LibBiSComm = nil
  _G.IsResting = function() return GAME.resting end
end

-- THE PUBLIC DOOR (Arn, 22 Nov: "We make the api public if people want to put their own information into their phone. It's like
-- curseforge inside wow forever")
do
  local here = { MyAddon = true, Other = true, Greedy = true }
  _G.C_AddOns = { IsAddOnLoaded = function(n) return here[n] or n == "BiSTools" end, GetAddOnInfo = function(n) return n, n, "", here[n] and true or false, not here[n] and "MISSING" or nil end, EnableAddOn = function() end }
  assert(loadfile("DeckAPI.lua"))()
  local A = BiSDeckAPI
  ok(A.major == 1 and A.version == 1, "BiSDeckAPI major 1")
  local pressed2 = 0
  local theirs = { key = "main", name = "My |cffff0000Addon|r", icon = "Mya", about = "It counts.", dev = true, hidden = true, order = 1, store = function() error("no") end, state = function() return "off" end,
    card = { when = "news", prio = function() return 99 end, lines = function() return { "MINE", "", "Forty two", "42", "gold" } end, buttons = function() return { { word = "GO", fn = function() end }, { word = "CAST", spell = "Fireball" } } end },
    page = { tabs = function() return { "A", "B" } end, rows = function(tab) return { { text = "row " .. tab, right = "x", act = { word = "go", fn = function() pressed2 = pressed2 + 1 end } }, { text = "m", act = { word = "m", macro = "/say hi" } }, "junk", 5 } end,
      boxes = function() return { { "N", 42, "gold" }, { "B", 1, "hotpink" } } end, big = function() return { word = "CAST", macro = "/cast x" } end, text = function() return "Hello\nthere |TInterface\\Icons\\x:0|t" end } }
  local app, why = A.Register("MyAddon", theirs)
  ok(app and app.Dirty and app:Added() == false, "another addon's app, handed in", tostring(why))
  local def = D.defs["MyAddon:main"]
  ok(def.guest and def.name == "My Addon" and def.icon == "My" and not def.dev and not def.hidden and not def.store and not def.state and def.order == 500, "only the fields we know, cut and plain", def.name .. "/" .. tostring(def.icon))
  local function why2(...) return select(2, A.Register(...)) end
  ok(why2("NotHere", theirs) == "addon" and why2("BiSTools", theirs) == "ours" and why2("BiSEvil", theirs) == "addon", "not a loaded addon, or one of ours: refused")
  here.BiSEvil = true ok(why2("BiSEvil", theirs) == "ours", "nor anything that calls itself BiS")
  ok(why2("MyAddon", { key = "a b", name = "x", page = {} }) == "key" and why2("MyAddon", { key = "ok", page = {} }) == "name" and why2("MyAddon", { key = "ok", name = "x" }) == "page" and why2("MyAddon", nil) == "key", "wrong: why")
  ok(A.Register("Greedy", { key = "a", name = "A", page = {} }) and A.Register("Greedy", { key = "b", name = "B", page = {} }) and why2("Greedy", { key = "c", name = "C", page = {} }) == "too many", "two apps at most")
  ok(A.Register("Greedy", { key = "a", name = "A2", page = {} }), "one again: in its place")
  -- not on the deck until ADD
  D.SetTheme("dark") D.Store().sw = {} D.Store().apps = {} D.page = "home" D.Show() D.Flip("portrait") D.Size(400, 760)
  local function icon(name) for i = 1, count("app") do local w = find("app", i) if w.c.text == name then return w end end end
  local function card(title) for i = 1, count("card") do local w = find("card", i) if w.c.text and w.c.text:find(title, 1, true) then return w end end end
  ok(not icon("My Addon") and not card("MINE") and app:Open() == false, "not on home until ADD, no card, and it cannot open itself")
  D.Open("BiSDeck:apps") click(find("tab", 3))
  local function row(s) for i = 1, count("row") do local x = find("row", i) if x.a.text:find(s, 1, true) then return x end end end
  ok(row("My Addon, from MyAddon") and row("My Addon").b.text == "ADD" and row("BiS Tools").b.text == "YOU HAVE IT" and row("BiS Gamba").b.text == "GET", "the STORE: whose it is, ADD; what of ours you have", row("My Addon") and row("My Addon").b.text)
  _G.LibBiSComm = { vers = { Moo = { addons = { BiSGamba = "1" } }, Sue = { addons = { BiSGamba = "1" } } } } D.Paint()
  ok(row("BiS Gamba").b.text == "2 have it", "and how many you heard have it", row("BiS Gamba").b.text) _G.LibBiSComm = nil
  click(row("My Addon"))
  ok(row("My Addon").b.text == "ADDED" and app:Added(), "a click adds it")
  D.page = "home" D.Paint()
  ok(icon("My Addon") and card("MINE"), "on home, with its card")
  local rank = {} for i = 1, count("card") do rank[find("card", i).c.text] = i end
  for _, c in ipairs(D.Cards()) do if c.def.guest then ok(c.p == A.PRIO, "its card never outranks: prio 5 at most", c.p) end end
  ok(app:Open() and find("title").a.text == "My Addon" and find("kicker").a.text == "FROM MYADDON", "its page says whose it is", find("kicker").a.text)
  ok(count("row") == 2 and find("row", 2).act == nil and find("big") == nil and find("box", 2).a.tone == "ink", "no macro, no big cast, no colour of its own, no junk", count("row"))
  ok(find("text").a.text == "Hello there ", "words: one line, no pictures in them", "[" .. tostring(find("text").a.text) .. "]")
  click(find("row", 1)) ok(pressed2 == 1, "its own button works")
  for _, b in ipairs(def.card.buttons()) do ok(b.word == "GO", "a spell is not a button here", b.word) end
  theirs.name = "Changed" theirs.page.rows = nil D.Paint() ok(count("row") == 2 and def.name == "My Addon", "changing their table later changes nothing")
  -- it breaks: parked, said with its own name, the rest goes on
  A.Register("Other", { key = "x", name = "Broken", page = { rows = function() error("theirs") end }, card = { when = "news", lines = function() error("theirs too") end } })
  D.SetAdded(D.defs["Other:x"], true)
  local before2 = #said
  D.page = "home" for _ = 1, 5 do D.Paint() end
  ok(D.defs["Other:x"].parked and said[before2 + 1] and said[before2 + 1]:find("Other", 1, true), "it breaks: parked, named", said[before2 + 1])
  D.Open("BiSDeck:apps") ok(row("Broken").b.text == "STOPPED", "the STORE says so")
  -- removed
  click(row("My Addon")) D.page = "home" D.Paint()
  ok(not icon("My Addon") and not card("MINE") and not app:Added(), "a click removes it")
  for _, id in ipairs({ "MyAddon:main", "Greedy:a", "Greedy:b", "Other:x" }) do D.defs[id] = nil end
  D.sorted = nil D.page = "home"
end

-- CARD SIZES, DRAWN (Arn, 22 Nov: "smarty size them for live cards")
do
  local t0 = 5000
  _G.GetTime = function() return t0 end
  local pA, pB = 9, 1
  local function mk(key, prio, list, btn) D.Register{ owner = "BiSSize", key = key, name = key:upper(), order = 1, card = { prio = prio, lines = function() return { key:upper(), "", "words of " .. key, "42", "gold", list = list } end, buttons = btn and function() return { { word = "GO", fn = function() end } } end }, page = { rows = function() return {} end } } end
  for id in pairs(D.defs) do D.Store().apps[id] = false end
  mk("a", function() return pA end, { { "one", "1" }, { "two", "2" }, { "three" }, { "four" } }, true)
  mk("b", function() return pB end, { { "x", "y" } }, true)
  for i = 1, 3 do mk("q" .. i, function() return 0.5 end) end
  D.sizeHeld, D.cardSkip = nil, nil
  D.page = "home" D.Show() D.Flip("portrait") D.Size(280, 620)
  local function card(title) for i = 1, count("card") do local w = find("card", i) if w.c.text and w.c.text:find(title, 1, true) then return w end end end
  ok(card("A") and card("A").h > 100 and count("cardline") == 3 and find("cardline", 2).a.text == "two" and find("cardline", 2).b.text == "2", "the urgent one is large, with three of its lines", count("cardline"))
  ok(card("Q1").w < 150 and card("Q1").a.text == "42" and card("Q1").b.text == "", "a quiet one: half a row, its number", card("Q1").a.text)
  -- every piece of a card is inside it and nothing covers another's words
  for _, p in ipairs(D.frame.pieces) do
    if p.shown and (p.kind == "cardline" or p.kind == "cardbtn") then
      local inside = false
      for i = 1, count("card") do local c = find("card", i) local px, py, cx2, cy2 = p.pts[1][4], -p.pts[1][5], c.pts[1][4], -c.pts[1][5] if px >= cx2 and py >= cy2 and px + p.w <= cx2 + c.w + 0.01 and py + p.h <= cy2 + c.h + 0.01 then inside = true end end
      ok(inside, p.kind .. " stays inside its card")
    end
  end
  local lastLine, firstBtn = 0, 9999
  for _, p in ipairs(D.frame.pieces) do if p.shown and p.kind == "cardline" then lastLine = math.max(lastLine, -p.pts[1][5] + p.h) end if p.shown and p.kind == "cardbtn" then firstBtn = math.min(firstBtn, -p.pts[1][5]) end end
  ok(lastLine <= firstBtn, "its lines end above its buttons", lastLine .. " " .. firstBtn)
  -- it does not breathe
  pA, pB = 1, 9 D.Paint()
  ok(card("A").h > 100, "the sizes hold for ten seconds", card("A").h)
  t0 = t0 + 11 D.Paint() t0 = t0 + 11 D.Paint()
  ok(card("B").h > card("A").h, "then the urgent one is the large one", card("B").h .. " " .. card("A").h)
  -- your own pick
  D.Open("BiSDeck:apps") click(find("tab", 2)) D.Size(320, 760)
  local rowB
  for i = 1, count("row") do if find("row", i).a.text == "B" then rowB = i end end
  local side
  for _, p in ipairs(D.frame.pieces) do if p.shown and p.kind == "side" and rowB and p.pts[1][5] == find("row", rowB).pts[1][5] then side = p end end
  ok(side and side.a.text == "AUTO", "Apps > CARDS: its size", side and side.a.text)
  click(side) ok(D.SizePick("BiSSize:b") == "S", "a click: small")
  D.page = "home" D.Size(280, 620)
  ok(card("B").w < 150, "and it is", card("B").w)
  for _ = 1, 3 do D.SetSize("BiSSize:b", "auto") end
  ok(D.Store().cardSize["BiSSize:b"] == nil, "auto again")
  -- more than fit
  for i = 4, 9 do mk("q" .. i, function() return 4 end) end
  D.sizeHeld = nil D.Paint()
  ok(count("card") <= 6 and count("morecards") == 1 and find("morecards").a.text:find("MORE CARDS", 1, true), "six at most, the rest behind MORE", count("card"))
  local seen = {}
  for _ = 1, 8 do for i = 1, count("card") do seen[find("card", i).c.text] = true end if not find("morecards") or find("morecards").a.text == "BACK TO THE FIRST" then break end click(find("morecards")) end
  local ns = 0 for _ in pairs(seen) do ns = ns + 1 end
  ok(ns == 11, "and all of them can be reached", ns)
  if find("morecards") then click(find("morecards")) end
  ok(D.cardSkip == nil, "BACK TO THE FIRST")
  for _, shape in ipairs({ "landscape", "portrait" }) do D.Flip(shape) for _, s in ipairs({ { 220, 300 }, { 300, 700 }, { 430, 300 }, { 900, 620 } }) do D.W, D.H, D.shape = s[1], s[2], T.DeckShape(s[1], s[2]) local okP, why = pcall(D.Paint) ok(okP, "draws " .. s[1] .. "x" .. s[2], why) end end
  D.shape = "portrait" D.Flip("portrait")
  for id in pairs(D.defs) do if id:find("^BiSSize:") then D.defs[id] = nil end end
  D.sorted, D.sizeHeld, D.cardSkip = nil, nil, nil
  D.Store().apps, D.Store().cardSize = {}, nil
  local clock = 90000
  _G.GetTime = function() clock = clock + 5 return clock end
end

-- THE RADIO (Arn, 22 Nov: "this is going to be fun for fm a radio on the phone ... Make it dope")
do
  local now2, pressed3 = 700, 0
  _G.GetTime = function() return now2 end
  local h = { art = "radio", big = "Ironforge Intro", small = "IRONFORGE", left = "0:20", right = "1:26", frac = 0.25, ticks = 30, at = 12, on = true, fn = function() pressed3 = pressed3 + 1 end, peek = true }
  D.Register{ owner = "BiSRadio", key = "fm", name = "FM", page = { tick = true, hero = function() return h end, rows = function() return { { text = "a song" } } end, big = function() return { word = "STOP", fn = function() end } end } }
  D.Open("BiSRadio:fm") D.Flip("portrait") D.Size(280, 520)
  local w = find("hero")
  ok(w and w.a.text == "Ironforge Intro" and w.c.text == "IRONFORGE" and w.b.text == "0:20  /  1:26", "the radio: the song, where from, the time", w and w.b.text)
  for _, t in pairs(w.bits) do if t.shown then ok(t.pts[1][4] >= 0 and t.pts[1][4] + t.w <= w.w + 0.01 and -t.pts[1][5] >= 0 and -t.pts[1][5] + t.h <= w.h + 0.01, "it stays inside its place", t.pts[1][4] .. " " .. t.pts[1][5]) end end
  local needle = w.bits[3].pts[1][4]
  local eq = {} for i = 1, 9 do eq[i] = w.bits[80 + i].h end
  h.at = 25 now2 = now2 + 1 tick(1.2)
  ok(find("hero").bits[3].pts[1][4] > needle, "another station: the needle moves")
  local moved = 0 for i = 1, 9 do if w.bits[80 + i].h ~= eq[i] then moved = moved + 1 end end
  ok(moved > 3, "it plays: the bars step with the seconds", moved)
  local made0 = #made now2 = now2 + 1 D.Paint() ok(#made == made0, "nothing new is made", #made - made0)
  h.on = false now2 = now2 + 1 D.Paint() local flat = true for i = 1, 9 do if w.bits[80 + i].h ~= 2 then flat = false end end ok(flat, "silent: flat")
  click(find("hero")) ok(pressed3 == 1, "a click on it plays / stops")
  h.ticks, h.at, h.frac, h.big = 1, 99, 7, nil ok(pcall(D.Paint), "odd numbers: no error")
  for _, sz in ipairs({ { 220, 300 }, { 300, 700 }, { 430, 300 }, { 1200, 760 } }) do D.W, D.H, D.shape = sz[1], sz[2], T.DeckShape(sz[1], sz[2]) ok(pcall(D.Paint), "draws " .. sz[1]) end
  D.Flip("portrait")
  D.page = "home" D.Paint()
  local left = 0 for _, p in ipairs(D.frame.pieces) do if p.kind ~= "status" and p.kind ~= "clock" and p.shown then for _, t in pairs(p.bits or {}) do if t.shown then left = left + 1 end end end end
  ok(left == 0, "another page: none of it is left", left)
  D.defs["BiSRadio:fm"] = nil D.sorted = nil
  local clock = 190000
  _G.GetTime = function() clock = clock + 5 return clock end
end

-- THE THEMES (Arn, 22 Nov: the clean dark one first; Ryan-Gosling-mode is one you turn on; "other people can change the theme")
do
  local function hexOf(th, name) return th.hex[name] or T.hex[name] end
  local function lum(h)
    local function c(i) local v = tonumber(h:sub(i, i + 1), 16) / 255 return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * c(1) + 0.7152 * c(3) + 0.0722 * c(5)
  end
  local function ratio(a, b) local x, y = lum(a), lum(b) if x < y then x, y = y, x end return (x + 0.05) / (y + 0.05) end
  for _, th in ipairs(D.THEMES) do
    for _, on in ipairs({ "ground", "card", "sunken" }) do
      for name, least in pairs({ ink = 7, ink2 = 4.5, dim = 4.5, accent = 4.5, good = 4.5, gold = 4.5, warn = 4.5 }) do
        local got = ratio(hexOf(th, name), hexOf(th, on))
        ok(got >= least, th.name .. ": " .. name .. " on " .. on .. " can be read", string.format("%.2f", got))
      end
    end
    ok(ratio(hexOf(th, "ink"), hexOf(th, "accentSoft")) >= 7, th.name .. ": the picked row can be read")
    -- the head's words stand on the sky's bands (the title and the profile, 30 to 54 down)
    for i, hex in ipairs(th.sky or {}) do
      local y = (i - 1) * D.SKY_BAND
      if y < 54 then ok(ratio(hexOf(th, "ink"), hex) >= 7 and (y >= 49 or ratio(hexOf(th, "accent"), hex) >= 4.5), th.name .. ": the words on sky band " .. i .. " can be read", string.format("%.2f", ratio(hexOf(th, "accent"), hex))) end
    end
  end
  ok(T.hex.accent == "b980ff" and T.hex.ground == "08060d", "a theme never changes the family's own colours")
  D.Store().theme = nil D.page = "home" D.Show() D.Flip("portrait") D.Size(260, 462)
  ok(D.Theme().key == "dark" and #(D.frame.sky or {}) == 0, "dark until you change it: no sky")
  D.page = "switches" D.Size(400, 760)
  local function sw(name) for i = 1, count("switch") do local w = find("switch", i) if w.a.text == name then return w end end end
  ok(sw("Dark") and sw("Dark").b.text == "ON" and sw("Dark").lit and sw("Night drive").b.text == "", "the switches: one theme is on, and it says so")
  local ground = D.frame.bg.r
  click(sw("Light"))
  ok(D.Store().theme == "light" and sw("Light").b.text == "ON" and sw("Dark").b.text == "" and D.frame.bg.r > 0.9 and ground < 0.1, "light: at once, the ground too", D.frame.bg.r)
  ok(sw("Light").a.col < 0.2, "and its words are dark", sw("Light").a.col)
  click(sw("Night drive"))
  D.page = "home" D.Paint()
  local shown = 0 for _, t in ipairs(D.frame.sky) do if t.shown then shown = shown + 1 end end
  ok(shown > 8 + 10, "night drive: a sky and roofs on home", shown)
  local same = calls
  local made0 = #made
  D.Paint()
  ok(#made == made0, "painted again: nothing new is made", #made - made0)
  D.Size(400, 700)
  D.Open("BiSTools:bosses")
  shown = 0 for _, t in ipairs(D.frame.sky) do if t.shown then shown = shown + 1 end end
  ok(shown == 0, "never behind a list", shown)
  D.page = "home" D.Flip("landscape")
  for _, t in ipairs(D.frame.sky) do if t.shown then ok(t.pts[1][4] + t.w <= D.W + 0.01, "the sky stays inside", t.pts[1][4] + t.w) end end
  D.Flip("portrait")
  ok(D.SetTheme("nothing") == false and D.Theme().key == "drive", "a name it does not know: no change")
  D.Store().theme = "gone" ok(D.Theme().key == "dark", "a saved theme that is gone: dark")
  D.SetTheme("dark")
  ok(D.Store().theme == nil, "back to dark")
end

-- AN APP PULLED OUT (Arn, 22 Nov: "i want them to open in the phone like apps ... its only when i drag a window out that it becomes an
-- app in the screen not in the phone, or if i drag a live tile it stays like a tile")
do
  local down, over = true, false
  local keepB = _G.IsMouseButtonDown
  _G.IsMouseButtonDown = function() return down end
  assert(loadfile("DeckWindows.lua"))()
  local words, heard, off = "", 0, false
  D.Register{ owner = "BiSWin", key = "a", name = "Wind", icon = "Wi", order = 0.1, page = { tabs = function() return { "ONE", "TWO" } end,
    find = function() return { get = function() return words end, set = function(v) words = v end } end,
    rows = function(tab) local o = { { text = "T" .. tab .. words, act = { word = "hear", fn = function() heard = heard + 1 end } }, { text = "Go", act = { word = "go", fn = function() D.Open("BiSWin:b") end } },
      { text = "Away", act = { word = "x", fn = function() D.page = "home" end } } } for k = 4, 40 do o[k] = { text = "r" .. k } end return o end,
    hero = function() return { art = "model", creature = 1234, big = "Magra" } end } }
  D.Register{ owner = "BiSWin", key = "b", name = "Other", icon = "Ot", order = 0.2, state = function() return off and "off" or "on" end, page = { text = function() return "other" end } }
  D.Register{ owner = "BiSWin", key = "c", name = "Opens", icon = "Op", order = 0.3, open = function() end }
  D.frame.IsMouseOver = function() return over end
  D.Store().sw, D.Store().off = {}, nil
  D.page = "home" D.Show() D.Flip("portrait") D.Size(300, 620)
  local function icon2(name) for k = 1, count("app") do local w = find("app", k) if w.c.text == name then return w end end end
  local function wfind(s, kind, k) local c = 0 for _, w in ipairs(s.frame.pieces) do if w.shown and w.kind == kind then c = c + 1 if c == (k or 1) then return w end end end end
  ok(icon2("Wind").dragApp == "BiSWin:a" and not icon2("Opens").dragApp, "an app with a page can be dragged out; one that opens its own window can not")
  click(icon2("Wind"))
  ok(D.page == "BiSWin:a" and find("out") and find("model") == nil and D.frame.model and D.frame.model.shown, "an icon opens it IN the phone, with the creature's model")
  do  -- a creature never met: asked again, not for ever
    local mo, asks, clock, file, keepT = D.frame.model, 0, 1000, 0, _G.GetTime
    mo.SetCreature = function() asks = asks + 1 end
    mo.GetModelFileID = function() return file end
    _G.GetTime = function() return clock end
    D.frame.modelKey = nil
    for _ = 1, 12 do clock = clock + 1 D.Paint() end
    ok(asks == 6, "a model that does not come is asked six times, then left", asks)
    D.frame.modelKey, asks, file = nil, 0, 77
    for _ = 1, 5 do clock = clock + 1 D.Paint() end
    ok(asks == 1, "one that came is not asked again", asks)
    mo.SetCreature, mo.GetModelFileID, _G.GetTime = nil, nil, keepT
  end
  click(find("back"))
  ok(not D.frame.model.shown, "home: no model left standing")
  -- dragged out by its icon
  local tile = icon2("Wind")
  cx, cy = 900, 600
  tile.scripts.OnDragStart(tile)
  local s = D.winSurfs["BiSWin:a"]
  ok(s and s.frame.shown and s.frame.isMoving and D.IsOut("BiSWin:a") and D.page == "home" and D.surf == D.mainSurf, "dragged out: under the mouse, the phone stays where it was")
  ok(tile.shown, "and the piece that is dragged is not painted away")
  s.frame.GetPoint = function() return "TOP", UIParent, "BOTTOMLEFT", 900, 614 end
  tile.scripts.OnDragStop(tile)
  ok(not s.frame.isMoving and s.frame.shown and D.Wins()["BiSWin:a"].pos[3] == 900 and D.Wins()["BiSWin:a"].w == D.WIN_W, "let go: it stands there, kept")
  ok(not wfind(s, "clock") and not wfind(s, "home") and not wfind(s, "railapp") and not wfind(s, "back") and wfind(s, "close") and wfind(s, "size") and wfind(s, "code") and wfind(s, "title").a.text == "Wind", "a window: its name, x, the corner, the faint code")
  ok(s.frame.corner.mouse, "its corner")
  -- its own tab, search, scroll; the phone's own beside it
  click(wfind(s, "tab", 2))
  ok(wfind(s, "row").a.text == "T2" and D.defs["BiSWin:a"].tab ~= 2, "its own tab")
  D.Open("BiSWin:a") ok(find("row").a.text == "T1" and D.frame ~= s.frame, "the phone has its own")
  click(find("back"))
  local e = s.frame.find
  e.text = "bell" e.scripts.OnTextChanged(e, true)
  ok(words == "bell" and D.surf == D.mainSurf, "its own search line")
  D.winRoot.scripts.OnUpdate(D.winRoot, 0.2)
  ok(wfind(s, "row").a.text == "T2bell", "painted at once while typing", wfind(s, "row").a.text)
  words = "" D.WinPaint("BiSWin:a", true)
  local first = wfind(s, "row").a.text
  s.frame.scripts.OnMouseWheel(s.frame, -1)
  ok((s.skip or 0) > 0 and (D.skip or 0) == 0, "its own wheel", tostring(s.skip))
  s.frame.scripts.OnMouseWheel(s.frame, 1)
  heard = 0 click(wfind(s, "row")) ok(heard == 1, "a row does what it does in the phone")
  -- it opens another app: on the phone
  click(wfind(s, "row", 2))
  ok(D.page == "BiSWin:b" and s.frame.shown and s.page == "BiSWin:a", "another app opens on the phone, the window stays")
  click(find("back"))
  -- resized
  cx, cy, down = 500, 500, true
  s.frame.corner.scripts.OnMouseDown(s.frame.corner, "LeftButton")
  cx, cy = 560, 440
  D.winRoot.scripts.OnUpdate(D.winRoot, 0.06)
  ok(s.W > D.WIN_W and s.H > D.WIN_H and D.W == 300, "the corner: this window, not the phone", s.W)
  down = false
  D.winRoot.scripts.OnUpdate(D.winRoot, 0.06)
  ok(D.winGrip == nil and D.Wins()["BiSWin:a"].w == s.W, "let go and never told: kept")
  s.frame.corner.scripts.OnDoubleClick(s.frame.corner) ok(s.W == D.WIN_W and s.H == D.WIN_H, "double-click: its normal size")
  -- a beat with nothing new paints nothing
  D.winRoot.scripts.OnUpdate(D.winRoot, 1.1)
  local was = D.paints
  D.winRoot.scripts.OnUpdate(D.winRoot, 1.1) ok(D.paints == was, "nothing new: not painted")
  D.Phone(D.Dirty) D.winRoot.scripts.OnUpdate(D.winRoot, 1.1) ok(D.paints == was + 1, "something new: once")
  -- a fight
  fire("PLAYER_REGEN_DISABLED")
  ok(s.frame.alpha == D.FIGHT_ALPHA and s.frame.mouse == false and s.frame.strata == D.FIGHT_STRATA and not s.frame.corner.mouse, "a fight: faint, clicks go through, under the bars")
  local any
  for _, w in ipairs(s.frame.pieces) do if w.shown and w.mouse then any = w.kind end end
  ok(not any and not e.shown, "nothing on it takes a click", any)
  fire("PLAYER_REGEN_ENABLED") ok(s.frame.alpha == 1 and s.frame.mouse, "after it: back")
  D.Store().sw.pinfight = false fire("PLAYER_REGEN_DISABLED") ok(not s.frame.shown, "or gone, with the switch") fire("PLAYER_REGEN_ENABLED") ok(s.frame.shown, "and back")
  D.Store().sw.pinfight = nil
  -- the phone shut: it stays
  D.Hide() ok(s.frame.shown and not D.frame.shown, "the phone shut: the window stays")
  click(wfind(s, "row", 2)) ok(D.frame.shown and D.page == "BiSWin:b", "what it opens opens the phone") click(find("back"))
  -- x, over the phone, home
  click(wfind(s, "close")) ok(not s.frame.shown and not D.IsOut("BiSWin:a"), "x: back into the phone")
  D.Open("BiSWin:a") click(find("out")) ok(s.frame.shown and D.page == "home", "OUT: out, the phone goes home")
  down, over = true, true
  s.frame.scripts.OnDragStart(s.frame) s.frame.scripts.OnDragStop(s.frame)
  ok(not s.frame.shown and not D.IsOut("BiSWin:a"), "dropped on the phone: back into it")
  over = false
  D.WinOut("BiSWin:a") click(wfind(s, "row", 3)) ok(not D.IsOut("BiSWin:a") and not s.frame.shown, "it goes home: the window closes")
  -- its tool is switched off: gone, its place kept
  D.WinOut("BiSWin:b") local sb = D.winSurfs["BiSWin:b"]
  ok(sb.frame.shown, "another one out")
  off = true D.Phone(D.Dirty) D.winRoot.scripts.OnUpdate(D.winRoot, 1.1) ok(not sb.frame.shown and D.IsOut("BiSWin:b"), "switched off: gone, its place kept")
  off = false D.Phone(D.Dirty) D.winRoot.scripts.OnUpdate(D.winRoot, 1.1) ok(sb.frame.shown, "on again: back")
  D.Off(true) ok(not sb.frame.shown, "the deck off: nothing of it left") D.Off(false) ok(sb.frame.shown, "on: back")
  D.SetTheme("light") D.SetTheme("dark")
  -- an error in a window's app never leaves the phone on the wrong surface
  D.Register{ owner = "BiSWin", key = "e", name = "Err", order = 0.4, page = { rows = function() error("boom") end } }
  D.WinOut("BiSWin:e") ok(D.surf == D.mainSurf and D.frame ~= D.winSurfs["BiSWin:e"].frame, "an error: the phone is the phone")
  D.WinClose("BiSWin:e") D.WinClose("BiSWin:b")
  D.winRoot.scripts.OnUpdate = D.winRoot.scripts.OnUpdate
  ok(next(D.Wins()) == nil and D.winRoot.scripts.OnUpdate == nil, "none out: no beat")
  for k = #made, 1, -1 do if made[k].secureTemplate then ok(false, "nothing secure") end end
  D.defs["BiSWin:a"], D.defs["BiSWin:b"], D.defs["BiSWin:c"], D.defs["BiSWin:e"] = nil, nil, nil, nil
  _G.IsMouseButtonDown = keepB
  D.page = "home" D.Paint()
end
-- an older copy loading after: refused; a newer one takes over the data and builds its own frame
-- THE BUTTONS THAT CAST (probed by Arn, 22 Nov): on their own root, laid over the drawn ones by numbers, never in a fight
do
  ok(secureMade == 0, "nothing secure so far", secureMade)
  local drivers = {}
  _G.RegisterStateDriver = function(fr, what, cond) drivers[fr] = what .. " " .. cond end
  assert(loadfile("DeckOverlay.lua"))()
  local go, said, bagOk, used = { word = "CAST", spell = "Windfury Weapon" }, nil, true, 0
  D.Register{ owner = "BiSCast", key = "a", name = "Cast", order = 0.1,
    card = { prio = function() return 9 end, lines = function() return { "CAST", "", "x", "" } end, buttons = function() return { { word = "TARGET", macro = "/target party1" } } end },
    page = { big = function() return go end, keys = function() return { { word = "EAT", item = 1234 }, { word = "PLAIN", fn = function() used = used + 1 end } } end,
      rows = function() return { { text = "Totem", act = { word = "cast", spell = "Magma Totem" } }, { text = "no" } } end } }
  local def = D.defs["BiSCast:a"]
  -- every piece knows where it stands: its own numbers on the deck's corner
  local function rect(fr, l, t2)
    fr.GetLeft, fr.GetTop = function() return l end, function() return t2 end
    fr.GetHeight = function(self) return self.h end
    fr.IsMouseOver = function() return false end
  end
  local function lay(fr) rect(fr, 100, 900) for _, w in ipairs(fr.pieces) do local p = w.pts[1] if p then rect(w, 100 + (p[4] or 0), 900 + (p[5] or 0)) end end end
  D.Store().sw = {}
  D.Show() D.Flip("portrait") D.Size(300, 620)
  D.Open("BiSCast:a")
  lay(D.frame) D.Paint() lay(D.frame) D.Paint()
  local list = D.overOf[D.mainSurf]
  ok(list and #list == 3 and D.overRoot and drivers[D.overRoot] == "visibility [combat] hide; show", "big, a key and a row: three, on a root a fight hides", list and #list)
  local big
  for _, b in ipairs(list) do if b.piece.kind == "big" then big = b end end
  ok(big and big.attr.type1 == "spell" and big.attr.spell1 == "Windfury Weapon" and big.parent == D.overRoot and big.pts[1][2] == UIParent, "it casts; it stands on UIParent, not on the deck")
  ok(big.w == find("big").w * (find("big").scale or 1) and find("big").a.text == "CAST" and not find("big").tip, "as big as the drawn one, which is not dim")
  for _, b in ipairs(list) do if b.piece.kind == "key" then ok(b.attr.type1 == "item" and b.attr.item1 == "item:1234", "an item") elseif b.piece.kind == "row" then ok(b.attr.spell1 == "Magma Totem", "a row") end end
  D.Paint() ok(D.overOf[D.mainSurf][1] == list[1] and D.overN == 3, "painted again: the same ones")
  -- a click: the last word, then used
  big.scripts.PreClick(big) big.scripts.PostClick(big)
  ok(big.attr.type1 == "spell" and D.Mine().live ~= nil, "pressed: it casts")
  local after = 0
  go = { word = "FIND", macro = "/targetexact Sneed", after = function() after = after + 1 end }
  D.Paint() big.scripts.PostClick(big, "LeftButton", true) big.scripts.PostClick(big, "LeftButton", false)
  ok(after == 1, "what comes after it: once a click", after)
  go = { word = "GIVE", spell = "Innervate", unit = "party2" }
  D.Paint() ok(big.attr.spell1 == "Innervate" and big.attr.unit == "party2", "a spell on a groupmate")
  go = { word = "NEXT", spell = "Disenchant", bag = 0, slot = 4, ok = function() return bagOk end }
  D.Paint() ok(big.attr.unit == nil and big.attr["target-bag"] == 0 and big.attr["target-slot"] == 4 and big.attr.spell1 == "Disenchant", "a spell on an item in your bags")
  big.scripts.PreClick(big) ok(big.attr.type1 == "spell", "still that item: it goes")
  bagOk = false big.scripts.PreClick(big) ok(big.attr.type1 == nil, "the item moved: the click does nothing")
  D.Paint() ok(big.attr.type1 == "spell", "and the next paint aims again") bagOk = true
  -- under the mouse: put away, and back
  D.frame.scripts.OnDragStart(D.frame) ok(D.overN == 0, "the deck is dragged: put away")
  D.frame.scripts.OnDragStop(D.frame) lay(D.frame) D.Paint() ok(D.overN == 3, "let go: back", D.overN)
  D.Hide() ok(D.overN == 0, "the phone shut: none") D.Show() lay(D.frame) D.Paint() ok(D.overN == 3, "open: back")
  -- a fight: nothing secure is touched
  GAME.fight = true
  fire("PLAYER_REGEN_DISABLED")
  local fine, why = pcall(function() D.Paint() D.Hide() D.Show() D.Flip() D.Flip() D.page = "home" D.Paint() end)
  ok(fine, "a fight: the deck does all it does, no secure button is touched", why)
  D.Hide()
  GAME.fight = false
  fire("PLAYER_REGEN_ENABLED")
  for _, m2 in ipairs(made) do if m2.scripts.OnEvent and m2.events.PLAYER_REGEN_ENABLED then m2.scripts.OnEvent(m2, "PLAYER_REGEN_ENABLED") end end
  ok(D.overN == 0, "shut in the fight: nothing left behind after it", D.overN)
  -- the card's button, pulled out
  D.Show() D.Flip("portrait") D.page = "home" lay(D.frame) D.Paint() lay(D.frame) D.Paint()
  local tgt for _, b in ipairs(D.overOf[D.mainSurf] or {}) do if b.attr.macrotext1 == "/target party1" then tgt = b end end
  ok(tgt and tgt.piece.kind == "cardbtn", "a live card's secure button", D.overN)
  D.PinOut("BiSCast:a") local pf = D.pinFrames["BiSCast:a"] lay(pf) D.PinPaint("BiSCast:a")
  ok(D.overOf[pf] and #D.overOf[pf] == 1 and pf.b1.shown, "and on the pulled-out card")
  D.PinBack("BiSCast:a") ok(not D.overOf[pf], "back: gone from there")
  -- a window, and what it covers
  D.Open("BiSCast:a") lay(D.frame) D.Paint() lay(D.frame) D.Paint()
  D.WinOut("BiSCast:a") local s = D.winSurfs["BiSCast:a"] D.Open("BiSCast:a") lay(s.frame) D.WinPaint("BiSCast:a", true) lay(s.frame) D.WinPaint("BiSCast:a", true)
  ok(D.overOf[s] and #D.overOf[s] == 3, "a window has its own")
  lay(D.frame) D.Paint() ok(not D.overOf[D.mainSurf] or #D.overOf[D.mainSurf] < 3, "the phone's under it are put away")
  D.WinClose("BiSCast:a") ok(not D.overOf[s], "closed: gone")
  -- the switch
  D.Store().sw.casts = false D.Paint() ok(D.overN == 0 and find("big").tip:find("Switched off"), "the switch: none, and it says why") D.Store().sw.casts = nil
  D.OverlayClear(D.mainSurf)
  D.defs["BiSCast:a"] = nil
  for _, w in ipairs(D.frame.pieces) do w.GetLeft, w.GetTop = nil, nil end
  D.frame.GetLeft, D.frame.GetTop = nil, nil
  D.page = "home" D.Show()
end
local old = D.frame
assert(loadfile("Deck.lua"))()
ok(T.Deck.frame == old, "the same copy again: refused")
T.DECK_MINOR = 0 T.DECK_READY = nil
assert(loadfile("Deck.lua"))()
ok(T.Deck == D and next(D.defs) ~= nil, "a newer copy keeps what was registered")
old.built = 0
D.Show()
ok(D.frame ~= old and not old.shown, "and retires the older frame")
-- a login with each theme kept from last time: the frame is built before it has a size
for _, th in ipairs({ "drive", "light", "contrast", "dark" }) do
  D.SetTheme(th)
  D.frame.built, D.W, D.H, D.page = 0, nil, nil, "home"
  local fine, why = pcall(D.OnEvent, "PLAYER_LOGIN")
  if fine then fine, why = pcall(D.Show) end
  ok(fine and D.W and D.frame.shown, "a login with the theme " .. th, why)
end

print(string.format("== deck skin %s (%d checks)", fails == 0 and "ok" or ("FAILED " .. fails), n))
os.exit(fails == 0 and 0 or 1)
