--[[
  BiSTheme / Deck.lua  --  ONE DECK FOR EVERY BiS ADDON (21 Nov 2026, v0: the skin).

  Arn, 21 Nov: "unifed ui", "this makes api our apps way easier", "we can put a bis memoris live cardd", "from the start
  rezisable and toggles", "in raid nights it changes profiles to raid bis guild and other stuff", "landscape can scale things to
  fulll screen and portrait can be our minimized mode". The plan: BiSTools/dev/DECK.md; where everything goes: DeckLayout.lua
  (pure, swept by dev/decklayout.lua); the research: BiSTools/dev/DECK-RESEARCH-KIT.md.

  AN ADDON HANDS IN DATA, NEVER A FRAME - that is its API:
    local H = BiSTheme.Deck.Register{
      owner = "BiSTools", key = "bosses", name = "Bosses", icon = "Bo", order = 10,
      card = { prio = fn -> number | nil (nil = no card now), lines = fn -> { title, note, value, right, ink, hot = true },
               buttons = fn -> { { word, fn }, ... }, profiles = { Dungeon = true } },
      page = { title = fn, kicker = fn, boxes = fn -> { { word, value, ink } }, tabs = fn -> { "BOSSES", "QUESTS" },
               rows = fn(tab) -> { { text, right, mark, ink, done, act = button } }, big = fn -> button, keys = fn -> { button },
               text = fn -> string, say = fn -> string, steps = fn -> { { phase, text, note, button, done } } },
      dock = { word = "FIND", fn = fn, hot = fn }, badge = fn -> number, store = fn -> table (its own saved table),
    }
    H:Dirty()                                            -- something changed: painted at the next beat, only while shown
  A button = { word, fn = function } - or macro / item / spell: those are SECURE and wait for the overlay (below).

  THE SKIN IS PLAIN. Nothing secure stands on it or hangs from it, so it may resize, flip, dim and hide in a fight - the boss
  phone holds its secure rows itself and freezes at every pull. The macro / item / spell buttons will stand on their own
  root on UIParent, laid over the skin by numbers, hidden by the client in a fight (research: "the one decision that shapes
  the rest"). Until the probe says so (bisdev plans/deckkit.lua, T.DECK_OVERLAY), such a button is drawn but dim.

  WHOEVER LOADS FIRST ONLY REGISTERS. The frame is built at the first Show after PLAYER_LOGIN, by the newest copy (a frame an
  older copy built is retired). Every callback of an addon is pcalled: an error is counted, said once to the error handler
  with the owner's name, and after three the card or page says so - it never takes the deck down. Hidden, nothing runs.
]]
BiSTheme = BiSTheme or {}
local T = BiSTheme
local MINOR = 1
if (T.DECK_MINOR or 0) >= MINOR and T.DECK_READY then return end
if not T.DeckLayout then return end                       -- the layout file goes first
T.DECK_MINOR, T.DECK_READY = MINOR, nil

local D = T.Deck or {}
T.Deck = D
D.defs = D.defs or {}                                     -- owner:key -> def (kept across copies)
D.MINOR = MINOR
D.PROFILES = { "Leveling", "Dungeon", "Raid night", "Town", "PvP" }
D.BEAT = 1                                                -- seconds between paints of a dirty, shown deck
D.FIGHT_ALPHA = 0.12
D.LEAVE, D.TOWN_WAIT, D.RAID_KEEP = 10, 5, 600            -- seconds: before an instance's profile is dropped; into town; after a raid
D.ERRORS = 3
D.SCALE = 1.25
D.FONT = "Fonts\\ARIALN.TTF"

-- the deck's black and its card, and any name an older palette lacks (a name T.rgb does not know would come out as ink)
T.hex = T.hex or {}
for k, v in pairs({ ground = "08060d", card = "151020", sunken = "221d3c", line = "2a2446", line2 = "3a3260", ink = "ece8f6", ink2 = "c6bedd",
  dim = "8e86a6", accent = "b980ff", accentSoft = "2c2148", good = "4fd0cf", gold = "e5c04a", warn = "f08cb0" }) do
  if not T.hex[k] then T.hex[k] = v end
end
local function rgb(name)
  if T.rgb then return T.rgb(name) end
  local h = T.hex[name] or T.hex.ink
  return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

local function plain(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if not ok then return nil end
  return plain(a), plain(b)
end
local function fighting() return ask(InCombatLockdown) and true or false end

-- WHAT THE ADDONS HANDED IN -----------------------------------------------------------------------------------------

--- An addon's answer, caught: nil when it broke (counted; said once; parked after D.ERRORS).
function D.Call(def, part, fn, ...)
  if type(fn) ~= "function" then return fn end
  if def.parked then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
  def.errors = (def.errors or 0) + 1
  if def.errors == 1 and geterrorhandler then pcall(geterrorhandler(), "BiS> Deck, " .. tostring(def.owner) .. " " .. tostring(def.key) .. " " .. part .. ": " .. tostring(a)) end
  if def.errors >= D.ERRORS then def.parked = true end
  return nil
end

--- Hand a page / card / dock button in. Answers a handle, or nil + why.
function D.Register(def)
  if type(def) ~= "table" or type(def.owner) ~= "string" or type(def.key) ~= "string" then return nil, "owner and key" end
  local id = def.owner .. ":" .. def.key
  def.id = id
  D.defs[id] = def
  D.sorted = nil
  local H = {}
  function H:Dirty() D.Dirty() end
  function H:Open() D.Open(id) end
  if D.frame and D.frame:IsShown() then D.Dirty() end
  return H
end

local function sorted()
  if D.sorted then return D.sorted end
  local out = {}
  for _, d in pairs(D.defs) do out[#out + 1] = d end
  table.sort(out, function(a, b)
    local x, y = a.order or 100, b.order or 100
    if x ~= y then return x < y end
    return a.id < b.id
  end)
  D.sorted = out
  return out
end

-- SAVED: each addon lends a table; the newest stamp wins at the first read, and every one is written --------------------

function D.Store()
  if D.store then return D.store end
  local best
  for _, d in ipairs(sorted()) do
    local s = type(d.store) == "function" and D.Call(d, "store", d.store) or nil
    if type(s) == "table" then
      s.deck = type(s.deck) == "table" and s.deck or {}
      if not best or (s.deck.at or 0) > (best.at or 0) then best = s.deck end
    end
  end
  D.store = best or {}
  local st = D.store
  st.sw = type(st.sw) == "table" and st.sw or {}
  st.apps = type(st.apps) == "table" and st.apps or {}
  return st
end
function D.Save()
  local st = D.Store()
  st.at = ask(GetServerTime) or ask(time) or 0
  for _, d in ipairs(sorted()) do
    local s = type(d.store) == "function" and D.Call(d, "store", d.store) or nil
    if type(s) == "table" then s.deck = st end
  end
end

-- THE PROFILE -------------------------------------------------------------------------------------------------------

--- Which profile these facts mean. Pure: the test asks it everything.
function D.Detect(f)
  if f.pvp then return "PvP" end
  if f.raid then return "Raid night" end
  if f.dungeon then return "Dungeon" end
  if f.raidGroup and f.raidSoon then return "Raid night" end
  if f.resting then return "Town" end
  return "Leveling"
end

--- The facts, asked of the game; a hidden answer is no answer.
function D.Facts()
  local f = {}
  local inside, kind = ask(IsInInstance)
  if inside == true then
    f.pvp = kind == "pvp" or kind == "arena"
    f.raid = kind == "raid"
    f.dungeon = kind == "party" or kind == "scenario"
  end
  f.resting = ask(IsResting) == true
  f.raidGroup = ask(IsInRaid) == true
  local api = rawget(_G, "BiSGuildAPI")
  if f.raidGroup and type(api) == "table" and type(api.RaidNight) == "function" then
    local ok, n = pcall(api.RaidNight)
    local start = ok and type(n) == "table" and plain(n.start) or nil
    local now = ask(GetServerTime)
    if type(start) == "number" and type(now) == "number" then f.raidSoon = now > start - 3600 and now < start + 4 * 3600 end
  end
  f.ghost = ask(UnitIsGhost, "player") == true
  return f
end

--- Look again: into an instance at once; out of one after D.LEAVE, into town after D.TOWN_WAIT; as a ghost never; in a fight
--- never; pinned never. Answers the profile now.
function D.Look()
  local st = D.Store()
  if st.pin then D.profile = st.pin return D.profile end
  local f = D.Facts()
  local want = D.Detect(f)
  if not D.profile then D.profile = want return want end
  if want == D.profile then D.want = nil return want end
  if fighting() or f.ghost then return D.profile end
  local into = f.pvp or f.raid or f.dungeon
  if into then D.profile, D.want = want, nil D.Dirty() return want end
  local wait = (want == "Town" and D.profile == "Leveling") and D.TOWN_WAIT or (D.profile == "Raid night" and D.RAID_KEEP or D.LEAVE)
  if D.want ~= want then
    D.want = want
    if C_Timer and C_Timer.After then
      C_Timer.After(wait, function()
        if D.want ~= want then return end
        D.want = nil                                        -- (a fight, a ghost, back inside: the next look asks afresh)
        if fighting() then return end
        local g = D.Facts()
        if g.ghost or D.Detect(g) ~= want then return end
        D.profile, D.want = want, nil
        D.Dirty()
      end)
    end
  end
  return D.profile
end
function D.Pin(name) local st = D.Store() st.pin = name or nil D.profile = nil D.Look() D.Save() D.Dirty(true) end

-- THE VIEW: what the layout needs to know (counts), and what the boxes say ---------------------------------------------

local function shownApps()
  local st, out = D.Store(), {}
  for _, d in ipairs(sorted()) do if d.page and st.apps[d.id] ~= false then out[#out + 1] = d end end
  return out
end
--- The cards that have something to say now, the most urgent first (a tie keeps its order).
function D.Cards()
  local st, out = D.Store(), {}
  for i, d in ipairs(sorted()) do
    local c = d.card
    if c and st.apps[d.id] ~= false and not (c.profiles and not c.profiles[D.profile or ""]) then
      local p = D.Call(d, "prio", c.prio or 1)
      local l = type(p) == "number" and D.Call(d, "lines", c.lines) or nil
      if d.parked then out[#out + 1] = { def = d, p = -1, i = i, lines = { d.name or d.key, "", "stopped after errors", "", "dim" } }
      elseif type(l) == "table" then out[#out + 1] = { def = d, p = p, i = i, lines = l, buttons = D.Call(d, "buttons", c.buttons) or {} } end
    end
  end
  table.sort(out, function(a, b) if a.p ~= b.p then return a.p > b.p end return a.i < b.i end)
  return out
end
local function dockList()
  local st, out = D.Store(), {}
  for _, d in ipairs(sorted()) do if d.dock and st.apps[d.id] ~= false then out[#out + 1] = d end end
  return out
end

D.SWITCHES = {
  { "HOME", { { "cards", "Live cards" }, { "apps", "App icons" }, { "dock", "Dock" } } },
  { "PAGES", { { "hero", "Pictures" }, { "boxes", "Number boxes" }, { "tabs", "Tabs" }, { "strip", "Progress strip" }, { "say", "Last action line" }, { "keys", "Small buttons" } } },
  { "STEPS", { { "list", "Step list" } } },
  { "EVERYWHERE", { { "code", "Faint code line" } } },
  -- EASIER TO USE (Arn, 22 Nov: "let's make it easy for people with accessibility and gamepad support"): off until asked for
  { "EASIER TO USE", { { "speak", "Read aloud", easy = true }, { "strong", "Stronger words", easy = true } } },
}

--- The data of the open page, asked once a paint.
function D.Model()
  local m = { page = D.page or "home" }
  m.apps = shownApps()
  if m.page == "home" then
    m.cards, m.dock = D.Cards(), dockList()
    m.view = { kind = "home", cards = #m.cards, apps = #m.apps, dock = #m.dock }
    m.title, m.kicker = "BiS>", (D.profile or "") .. (D.Store().pin and " - pinned" or "")
  elseif m.page == "switches" then
    local groups = {}
    for i, g in ipairs(D.SWITCHES) do groups[i] = #g[2] end
    m.view = { kind = "switches", groups = groups }
    m.title, m.kicker = "Switches", "PER CHARACTER"
  else
    local d = D.defs[m.page]
    local p = d and d.page
    if not p or d.parked then D.page = "home" if d and d.parked then d.parkedSaid = true end return D.Model() end
    m.def = d
    m.title, m.kicker = D.Call(d, "title", p.title) or d.name, D.Call(d, "kicker", p.kicker) or (d.name or ""):upper()
    m.steps = p.steps and D.Call(d, "steps", p.steps) or nil
    m.big = p.big and D.Call(d, "big", p.big) or nil
    m.keys = p.keys and D.Call(d, "keys", p.keys) or {}
    if type(m.steps) == "table" and #m.steps > 0 then
      m.cur = D.StepAt(d, m.steps)
      local s = m.steps[m.cur]
      m.big = s.button
      m.view = { kind = "steps", steps = #m.steps, textLines = math.min(4, math.ceil(#tostring(s.text or "") / 34)), note = s.note and true or nil, keys = 0 }
    else
      m.tabs = p.tabs and D.Call(d, "tabs", p.tabs) or {}
      m.tab = math.max(1, math.min(#m.tabs, d.tab or 1))
      m.boxes = p.boxes and D.Call(d, "boxes", p.boxes) or {}
      m.rows = p.rows and D.Call(d, "rows", p.rows, m.tab) or {}
      m.text = p.text and D.Call(d, "text", p.text) or nil
      m.say = p.say and D.Call(d, "say", p.say) or nil
      m.view = { kind = "page", boxes = #m.boxes, tabs = #m.tabs, rows = #m.rows, keys = #m.keys, big = m.big and true or nil,
        say = m.say and true or nil, textLines = m.text and math.max(1, math.ceil(#m.text / 46)) or 0, apps = #m.apps }
    end
  end
  return m
end

--- The step shown: the one picked by hand, else the first not done and not skipped.
function D.StepAt(def, steps)
  def.skipped = def.skipped or {}
  for i, s in ipairs(steps) do
    if type(s.done) == "function" then s.isDone = D.Call(def, "done", s.done) and true or false else s.isDone = s.done and true or false end
  end
  local at = def.stepAt
  -- moved on by itself: the one you were on is done now
  if at and steps[at] and steps[at].isDone and not def.stepHeld then at = nil end
  if not at or not steps[at] then
    at = #steps
    for i, s in ipairs(steps) do if not s.isDone and not def.skipped[i] then at = i break end end
  end
  def.stepAt = at
  return at
end
function D.Step(def, steps, how)
  local at = def.stepAt or 1
  if how == "skip" then def.skipped[at] = true def.stepAt, def.stepHeld = nil, nil
  else def.stepAt, def.stepHeld = math.max(1, math.min(#steps, at + (how == "back" and -1 or 1))), true end
  D.Dirty(true)
end

-- THE SKIN ----------------------------------------------------------------------------------------------------------

local CLICK = { close = 1, shape = 1, gear = 1, back = 1, home = 1, card = 1, app = 1, railapp = 1, dock = 1, tab = 1, row = 1, big = 1, key = 1,
  link = 1, step = 1, preset = 1, switch = 1, cardbtn = 1 }
local LOOK = {                                            -- kind -> ground colour, alpha
  card = { "card", 1 }, dockbar = { "card", 0.7 }, dock = { "sunken", 0.8 }, box = { "card", 1 }, tab = { "card", 1 }, row = { "sunken", 0.55 },
  step = { "sunken", 0.55 }, switch = { "sunken", 0.55 }, big = { "gold", 0.22 }, key = { "sunken", 0.8 }, preset = { "sunken", 0.8 },
  hero = { "card", 1 }, text = { "card", 1 }, progress = { "sunken", 1 }, stepcard = { "card", 1 }, strip = { "line", 1 },
  cardbtn = { "sunken", 1 }, grip = { "line", 0 }, app = { "line", 0 }, railapp = { "line", 0 },
}

local function text(parent, size, colour)
  local s = parent:CreateFontString(nil, "OVERLAY")
  s:SetFont(D.FONT, size, "")
  local r, g, b = rgb(colour or "ink")
  s:SetTextColor(r, g, b, 1)
  s:SetWordWrap(false)
  return s
end

--- One drawn piece, used again for whatever the next paint needs there. All plain: a Button with a ground, a left bar, three
--- words (a: main, b: right, c: small over it).
local function piece(parent)
  local w = CreateFrame("Button", nil, parent)
  w.bg = w:CreateTexture(nil, "BACKGROUND")
  w.bg:SetAllPoints(w)
  w.bar = w:CreateTexture(nil, "BORDER")
  w.bar:SetPoint("TOPLEFT", w, "TOPLEFT", 0, 0)
  w.bar:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 0, 0)
  w.bar:SetWidth(2)
  w.wash = w:CreateTexture(nil, "ARTWORK")
  w.wash:SetAllPoints(w)
  local r, g, b = rgb("accent")
  w.wash:SetColorTexture(r, g, b, 0.22)
  w.wash:Hide()
  w.a, w.b, w.c = text(w, 13), text(w, 12), text(w, 10, "dim")
  w:SetScript("OnEnter", function(self)
    if self.act then self.wash:Show() end
    D.Speak(self)
    if self.tip and GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.tip)
      GameTooltip:Show()
    end
  end)
  w:SetScript("OnLeave", function(self) self.wash:Hide() if GameTooltip then GameTooltip:Hide() end end)
  w:SetScript("OnClick", function(self) if self.act and not D.fight then self.act() end end)
  return w
end

local function say(fs, words, size, colour, justify)
  fs.hit = true
  colour, justify = colour or "ink", justify or "LEFT"
  if D.strong and (colour == "dim" or colour == "ink2") then colour = "ink" end
  if fs.px ~= size then fs.px = size fs:SetFont(D.FONT, size, "") end
  if fs.tone ~= colour then
    fs.tone = colour
    local r, g, b = rgb(colour)
    fs:SetTextColor(r, g, b, 1)
  end
  if fs.just ~= justify then fs.just = justify fs:SetJustifyH(justify) end
  words = plain(words) ~= nil and tostring(words) or ""
  if fs.said ~= words then fs.said = words fs:SetText(words) end
end

--- Read aloud what the mouse or the pad is on (the PC's own voice; a switch, off until asked for; never in a fight).
function D.Speak(w)
  if D.fight or not (D.Store().easy or {}).speak then return false end
  if not (C_VoiceChat and C_VoiceChat.SpeakText) then return false end
  local out = {}
  for _, fs in ipairs({ w.c, w.a, w.b }) do
    local s = fs.said
    if type(s) == "string" and s ~= "" and #s > 1 then out[#out + 1] = s end
  end
  if #out == 0 then return false end
  local line = table.concat(out, ", ")
  if line == D.spoken and D.spokenAt and GetTime and GetTime() - D.spokenAt < 2 then return false end
  D.spoken, D.spokenAt = line, GetTime and GetTime() or nil
  return (pcall(C_VoiceChat.SpeakText, 0, line, 0, 100))
end

--- A button an addon handed in: what a click does, and whether it may (a secure one waits for the overlay).
local function press(def, b)
  if type(b) ~= "table" then return nil end
  if type(b.fn) == "function" then return function() D.Call(def, "button", b.fn) D.Dirty(true) end end
  return nil
end
D.Press = press
function D.IsSecure(b) return type(b) == "table" and (b.macro or b.item or b.spell) and true or false end

--- What each kind says and does. `w` = the piece, `o` = its box, `m` = the model.
local PAINT = {}
function PAINT.clock(w) say(w.a, date and date("%H:%M") or "", 11, "ink") end
function PAINT.close(w) say(w.a, "x", 12, "ink2", "CENTER") w.act = function() D.Hide() end w.tip = "Close" end
function PAINT.shape(w) say(w.a, T.DeckShape(D.W, D.H) == "portrait" and "[ ]" or "|", 11, "ink2", "CENTER") w.act = function() D.Flip() end w.tip = "Tall / wide" end
function PAINT.gear(w) say(w.a, "*", 14, "ink2", "CENTER") w.act = function() D.page = (D.page == "switches") and "home" or "switches" D.Dirty(true) end w.tip = "Switches and size" end
function PAINT.back(w) say(w.a, "<", 15, "accent", "CENTER") w.act = function() D.page = "home" D.Dirty(true) end end
--- A thin drawn bar on a piece whose click area is bigger than it looks (the home bar, the corner, the progress).
local function stripe(w, key, point, x, y, wide, high, colour, a)
  local t = w[key]
  if not t then t = w:CreateTexture(nil, "OVERLAY") w[key] = t end
  t:ClearAllPoints()
  t:SetPoint(point, w, point, x, y)
  t:SetSize(wide, high)
  local r, g, b = rgb(colour)
  t:SetColorTexture(r, g, b, a or 1)
  t:Show()
end
function PAINT.home(w, o) stripe(w, "fill", "CENTER", 0, 0, o.w, 4, "dim", 0.6) w.act = function() D.page = "home" D.Dirty(true) end w.tip = "Home" end
function PAINT.title(w, o, m) say(w.a, m.title or "", 20, "ink") end
function PAINT.kicker(w, o, m) say(w.a, (m.kicker or ""):upper(), 11, "accent", "RIGHT") end
function PAINT.code(w) say(w.a, "deck " .. MINOR .. " " .. (D.profile or "?"):sub(1, 2):lower() .. " " .. math.floor(D.W) .. "x" .. math.floor(D.H), 9, "dim", "RIGHT") end
function PAINT.size(w) stripe(w, "fill", "BOTTOMRIGHT", -2, 2, 14, 3, "accent") stripe(w, "fill2", "BOTTOMRIGHT", -2, 2, 3, 14, "accent") end
function PAINT.card(w, o, m)
  local c = m.cards[o.i]
  local l = c and c.lines or {}
  say(w.c, (l.hot and "! " or "") .. (l[1] or ""), 11, "accent")        -- (never by colour alone: the gold bar and a mark)
  say(w.a, l[3] or "", 16, "ink")
  say(w.b, l[4] or "", 15, l[5] or "ink2", "RIGHT")
  w.hot = l.hot
  if c and c.def.page then w.act = function() D.Open(c.def.id) end end
end
function PAINT.app(w, o, m)
  local d = m.apps[o.i]
  if not d then return end
  say(w.a, d.icon or (d.name or "?"):sub(1, 2), 15, "ink", "CENTER")
  say(w.c, o.kind == "app" and (d.name or "") or "", 11, "ink2", "CENTER")
  local n = d.badge and D.Call(d, "badge", d.badge)
  say(w.b, (type(n) == "number" and n > 0) and tostring(n) or "", 11, "gold", "RIGHT")
  w.act = function() D.Open(d.id) end
  w.tip = d.name
end
PAINT.railapp = PAINT.app
function PAINT.dock(w, o, m)
  local d = m.dock[o.i]
  if not d then return end
  local hot = D.Call(d, "dock", d.dock.hot)
  say(w.a, (hot and "! " or "") .. (d.dock.word or ""), 11, hot and "gold" or "ink2", "CENTER")
  w.act = press(d, d.dock)
end
function PAINT.box(w, o, m)
  local b = m.boxes[o.i] or {}
  say(w.c, b[1] or "", 11, "dim")
  say(w.a, tostring(b[2] or ""), 17, b[3] or "ink")
end
function PAINT.tab(w, o, m)
  local onTab = m.tab == o.i
  say(w.a, m.tabs[o.i] or "", 12, onTab and "ink" or "dim", "CENTER")
  w.lit = onTab
  w.act = function() m.def.tab = o.i D.Dirty(true) end
end
function PAINT.row(w, o, m)
  local r = m.rows[o.i] or {}
  say(w.c, r.mark or "", 11, "dim")
  say(w.a, r.text or "", 13, r.done and "dim" or "ink")
  say(w.b, r.right or "", 11, r.ink or "ink2", "RIGHT")
  w.act = press(m.def, r.act)
  w.tip = r.tip
end
local function button(w, b, def, size)
  local sec = D.IsSecure(b)
  say(w.a, b and b.word or "", size, sec and "dim" or "ink", "CENTER")
  w.act = press(def, b)
  w.tip = sec and "This button comes with the next step of the deck" or (b and b.tip)
end
function PAINT.big(w, o, m) button(w, m.big, m.def, 16) end
function PAINT.key(w, o, m) button(w, m.keys[o.i], m.def, 12) end
function PAINT.say(w, o, m) say(w.a, m.say or "", 11, "ink2") end
function PAINT.text(w, o, m) w.a:SetWordWrap(true) say(w.a, m.text or "", 12, "ink2") end
function PAINT.stephead(w, o, m) local s = m.steps[m.cur] say(w.a, "STEP " .. m.cur .. " - " .. tostring(s.phase or ""), 11, "accent") say(w.b, s.isDone and "done" or "watching", 11, "dim", "RIGHT") end
function PAINT.steptext(w, o, m) w.a:SetWordWrap(true) say(w.a, tostring(m.steps[m.cur].text or ""), 15, "ink") end
function PAINT.stepnote(w, o, m) say(w.a, tostring(m.steps[m.cur].note or ""), 11, "ink2") end
function PAINT.link(w, o, m)
  say(w.a, ({ "< back", "skip", "next >" })[o.i], 12, "accent", "CENTER")
  local how = ({ "back", "skip", "next" })[o.i]
  w.act = function() D.Step(m.def, m.steps, how) end
end
function PAINT.step(w, o, m)
  local s = m.steps[o.i]
  if not s then return end
  local sk = m.def.skipped[o.i]
  say(w.c, s.isDone and "v" or sk and "-" or tostring(o.i), 11, s.isDone and "good" or "dim")
  say(w.a, tostring(s.text or ""), 13, (s.isDone or sk) and "dim" or "ink")
  say(w.b, tostring(s.phase or ""), 10, "dim", "RIGHT")
  w.lit = m.cur == o.i
  w.act = function() m.def.stepAt, m.def.stepHeld = o.i, true D.Dirty(true) end
end
function PAINT.progress(w, o, m)
  local n = 0
  for i, s in ipairs(m.steps) do if s.isDone or m.def.skipped[i] then n = n + 1 end end
  stripe(w, "fill", "TOPLEFT", 0, 0, math.max(1, o.w * n / math.max(1, #m.steps)), o.h, "good")
end
function PAINT.preset(w, o)
  say(w.a, ({ "ALL", "LEAN", "BARE" })[o.i], 12, "ink2", "CENTER")
  w.act = function() D.Preset(o.i) end
end
function PAINT.swhead(w, o) say(w.a, D.SWITCHES[o.group][1], 11, "gold") end
function PAINT.switch(w, o)
  local s = D.SWITCHES[o.group][2][o.i]
  local st0 = D.Store()
  st0.easy = type(st0.easy) == "table" and st0.easy or {}
  local isOn
  if s.easy then isOn = st0.easy[s[1]] == true else isOn = st0.sw[s[1]] ~= false end
  say(w.a, s[2], 13, isOn and "ink" or "dim")
  say(w.b, isOn and "ON" or "OFF", 12, isOn and "good" or "dim", "RIGHT")
  w.act = function()
    local st = D.Store()
    if s.easy then st.easy[s[1]] = not isOn or nil
    elseif isOn then st.sw[s[1]] = false
    else st.sw[s[1]] = nil end
    D.Save()
    D.Dirty(true)
  end
end
function PAINT.slider(w, o)
  local st = D.Store()
  say(w.a, o.i == 1 and "SIZE" or "HEIGHT", 12, "ink2")
  say(w.b, o.i == 1 and (math.floor((st.scale or D.SCALE) * 100 + 0.5) .. "%") or math.floor(D.H), 12, "ink", "RIGHT")
end

--- Where a piece's words stand, by what it is.
local function words(w, o)
  w.a:ClearAllPoints() w.b:ClearAllPoints() w.c:ClearAllPoints()
  w.a:SetJustifyV("MIDDLE")
  if o.kind == "card" then
    local top = o.btn and 22 or 0
    w.c:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -5) w.c:SetPoint("TOPRIGHT", w, "TOPRIGHT", -8, -5)
    w.b:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -8, 5 + top)
    w.a:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 8, 5 + top) w.a:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -o.w * 0.38, 5 + top)
  elseif o.kind == "box" then
    w.c:SetPoint("TOPLEFT", w, "TOPLEFT", 6, -3) w.a:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 6, 2)
  elseif o.kind == "app" then
    w.a:SetPoint("TOP", w, "TOP", 0, -12) w.c:SetPoint("BOTTOM", w, "BOTTOM", 0, 3) w.b:SetPoint("TOPRIGHT", w, "TOPRIGHT", -6, -3)
  elseif o.kind == "railapp" then
    w.a:SetPoint("CENTER", w, "CENTER", 0, 0) w.b:SetPoint("TOPRIGHT", w, "TOPRIGHT", -4, -3) w.c:SetPoint("BOTTOM", w, "BOTTOM", 0, 0)
  elseif o.kind == "row" or o.kind == "step" then
    w.c:SetPoint("LEFT", w, "LEFT", 7, 0) w.b:SetPoint("RIGHT", w, "RIGHT", -6, 0)
    w.a:SetPoint("LEFT", w, "LEFT", 24, 0) w.a:SetPoint("RIGHT", w.b, "LEFT", -6, 0)
  elseif o.kind == "text" or o.kind == "steptext" then
    w.a:SetJustifyV("TOP")
    w.a:SetPoint("TOPLEFT", w, "TOPLEFT", o.kind == "text" and 8 or 0, o.kind == "text" and -5 or 0) w.a:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", o.kind == "text" and -8 or 0, 0)
  elseif o.kind == "switch" or o.kind == "slider" or o.kind == "stephead" then
    w.a:SetPoint("LEFT", w, "LEFT", o.kind == "stephead" and 0 or 8, 0) w.b:SetPoint("RIGHT", w, "RIGHT", o.kind == "stephead" and 0 or -8, 0)
  else
    w.a:SetPoint("LEFT", w, "LEFT", 2, 0) w.a:SetPoint("RIGHT", w, "RIGHT", -2, 0)
  end
end

--- Build the plain frame (the newest copy's, at the first Show).
function D.Build()
  if D.frame and D.frame.built == MINOR then return D.frame end
  if D.frame then D.frame:Hide() end
  local f = CreateFrame("Frame", "BiSDeck", UIParent)
  f.built = MINOR
  f.pieces = {}
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not D.fight then self:StartMoving() self.moving = true end end)
  f:SetScript("OnDragStop", function() D.DragEnd() end)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints(f)
  local r, g, b = rgb("ground")
  f.bg:SetColorTexture(r, g, b, 0.97)
  f:SetScript("OnHide", function() D.DragEnd() D.Sleep() end)
  f:Hide()
  D.frame = f
  return f
end
function D.DragEnd()
  local f = D.frame
  if not (f and f.moving) then return end
  f.moving = nil
  pcall(f.StopMovingOrSizing, f)
  local ok, p, _, rp, x, y = pcall(f.GetPoint, f, 1)
  if ok and type(plain(p)) == "string" and type(plain(x)) == "number" then
    local st = D.Store()
    st[T.DeckShape(D.W, D.H)] = st[T.DeckShape(D.W, D.H)] or {}
    st[T.DeckShape(D.W, D.H)].pos = { p, plain(rp) or p, x, y }
    D.Save()
  end
end

local HOMES = { portrait = { 260, 462 }, landscape = { 600, 420 } }
--- The size and place kept for this shape (each shape has its own).
function D.Place(shape)
  local st, f = D.Store(), D.frame
  st[shape] = type(st[shape]) == "table" and st[shape] or {}
  local s = st[shape]
  D.W, D.H = T.DeckClamp(s.w or HOMES[shape][1], s.h or HOMES[shape][2])
  D.shape = shape
  f:SetScale(st.scale or D.SCALE)
  f:SetSize(D.W, D.H)
  f:ClearAllPoints()
  if type(s.pos) == "table" then f:SetPoint(s.pos[1], UIParent, s.pos[2], s.pos[3], s.pos[4])
  else f:SetPoint("RIGHT", UIParent, "RIGHT", shape == "portrait" and -180 or -60, 10) end
end
function D.Flip(shape)
  shape = shape or (T.DeckShape(D.W, D.H) == "portrait" and "landscape" or "portrait")
  D.Place(shape)
  D.Store().shape = shape
  D.Save()
  D.Dirty(true)
end
--- A new size (the corner, the sliders): kept for this shape; the corner never turns one shape into the other.
function D.Size(w, h)
  if D.shape == "portrait" then w = math.min(w, h - 1) else w = math.max(w, h + 1) end
  w, h = T.DeckClamp(w, h)
  local s = D.Store()[D.shape]
  s.w, s.h, D.W, D.H = w, h, w, h
  D.frame:SetSize(w, h)
  D.Dirty(true)
end
function D.Preset(i)
  local st = D.Store()
  st.sw = {}
  local off = i == 2 and { "hero", "strip", "say", "keys" } or i == 3 and { "hero", "strip", "say", "keys", "cards", "boxes", "dock", "code" } or {}
  for _, k in ipairs(off) do st.sw[k] = false end
  D.Save()
  D.Dirty(true)
end

--- Draw the deck: the model, its layout, a piece for each box.
function D.Paint()
  local f = D.frame
  if not (f and f:IsShown()) then return 0 end
  local m = D.Model()
  D.strong = (D.Store().easy or {}).strong and true or false
  local boxes = T.DeckLayout(m.view, D.W, D.H, D.Store().sw)
  local n = 0
  local function put(o)
    n = n + 1
    local w = f.pieces[n]
    if not w then w = piece(f) f.pieces[n] = w end
    w.act, w.tip, w.hot, w.lit = nil, nil, nil, nil
    if w.fill then w.fill:Hide() end
    if w.fill2 then w.fill2:Hide() end
    w.a:SetWordWrap(false)
    w:ClearAllPoints()
    w:SetPoint("TOPLEFT", f, "TOPLEFT", o.x, -o.y)
    w:SetSize(o.w, o.h)
    if w.SetFrameLevel and f.GetFrameLevel then w:SetFrameLevel((f:GetFrameLevel() or 1) + (o.under and 1 or 2)) end
    w.a.hit, w.b.hit, w.c.hit = nil, nil, nil
    w.kind = o.kind
    local look = LOOK[o.kind]
    if look then local r, g, b = rgb(look[1]) w.bg:SetColorTexture(r, g, b, look[2]) else w.bg:SetColorTexture(0, 0, 0, 0) end
    local fn = PAINT[o.kind]
    if fn then fn(w, o, m) end
    for _, fs in ipairs({ w.a, w.b, w.c }) do if not fs.hit then say(fs, "", 12) end end      -- (what it said for another box)
    words(w, o)
    local bar = w.hot and "gold" or (w.lit and "accent") or nil
    if bar then w.bar:SetColorTexture(rgb(bar)) w.bar:Show() else w.bar:Hide() end
    if w.lit then local r, g, b = rgb("accentSoft") w.bg:SetColorTexture(r, g, b, 1) end
    w:EnableMouse((CLICK[o.kind] and (w.act or w.tip) and not D.fight) and true or false)
    w.wash:Hide()
    w:Show()
    return w
  end
  for _, o in ipairs(boxes) do
    put(o)
    if o.kind == "card" and o.btn then
      local c = m.cards[o.i]
      local bs = c and c.buttons or {}
      local k = math.min(#bs, 3)
      for i = 1, k do
        local each = (o.w - 16 - (k - 1) * 4) / k
        local w = put({ kind = "cardbtn", x = o.x + 8 + (i - 1) * (each + 4), y = o.y + o.h - 24, w = each, h = 20 })
        if w.SetFrameLevel and f.GetFrameLevel then w:SetFrameLevel((f:GetFrameLevel() or 1) + 4) end
        button(w, bs[i], c.def, 12)
        w:EnableMouse((w.act or w.tip) and not D.fight and true or false)
      end
    elseif o.kind == "size" then
      local w = f.pieces[n]
      w:EnableMouse(not D.fight)
      if not w.gripped then
        w.gripped = true
        w:SetScript("OnMouseDown", function(self) if self.kind == "size" and not D.fight then D.GripStart() end end)
        w:SetScript("OnMouseUp", function() D.GripEnd() end)
      end
    end
  end
  for i = n + 1, #f.pieces do f.pieces[i]:Hide() end
  D.dirty = nil
  return n
end

-- the corner: the mouse's own travel over the deck's scale (the client's StartSizing cannot hold a shape, and sticks to the
-- mouse when a fight starts)
function D.GripStart()
  local f = D.frame
  local s = f:GetEffectiveScale()
  local x, y = GetCursorPosition()
  D.grip = { x = x / s, y = y / s, w = D.W, h = D.H, s = s, at = 0 }
end
function D.GripMove()
  local g = D.grip
  if not g then return end
  local x, y = GetCursorPosition()
  D.Size(g.w + (x / g.s - g.x), g.h + (g.y - y / g.s))
end
function D.GripEnd() if D.grip then D.grip = nil D.Save() end end

--- Something changed: painted at the next beat (`now` = at once), only while shown.
function D.Dirty(now)
  D.dirty = true
  if now and D.frame and D.frame:IsShown() then D.Paint() end
end

-- THE PAD (Arn, 22 Nov; BiSTheme Pad.lua): the deck stands open all evening, so it must not hold the pad all evening - the
-- character would lose its D-pad. FOCUS is asked for (`/bist deck pad`, a key), shows a tiny frame PadNav holds, and B gives the
-- pad back (first to home, then out). D-pad = nearest piece, A = its click, LB / RB = the tabs, or back / next on a step run.
function D.PadItems()
  local out = {}
  for _, w in ipairs(D.frame and D.frame.pieces or {}) do if w:IsShown() and w.act then out[#out + 1] = w end end
  return out
end
function D.PadBack() if (D.page or "home") ~= "home" then D.page = "home" D.Dirty(true) else D.Focus(false) end end
function D.PadTab(by)
  local def = D.defs[D.page or ""]
  if not def or not def.page then return false end
  if def.page.steps then
    local steps = D.Call(def, "steps", def.page.steps)
    if type(steps) == "table" and #steps > 0 then D.Step(def, steps, by < 0 and "back" or "next") return true end
  end
  local tabs = def.page.tabs and D.Call(def, "tabs", def.page.tabs) or {}
  if #tabs == 0 then return false end
  def.tab = ((def.tab or 1) - 1 + by) % #tabs + 1
  D.Dirty(true)
  return true
end
function D.Focus(want)
  if want and (D.fight or not T.PadNav or not D.Show()) then return false end
  local p = D.padFrame
  if not p and want then
    p = CreateFrame("Frame", nil, D.frame)
    p:Hide()
    p:SetSize(1, 1)
    p:SetPoint("TOPLEFT", D.frame, "TOPLEFT", 0, 0)
    T.PadNav(p, { items = D.PadItems, back = D.PadBack, tabs = { prev = function() D.PadTab(-1) end, next = function() D.PadTab(1) end } })
    D.padFrame = p
  end
  if not p then return false end
  if want then p:Show() else p:Hide() end
  D.focused = want and true or false
  return true
end

function D.Open(id) if D.defs[id] and D.defs[id].page then D.page = id D.Show() D.Dirty(true) end end
function D.Show()
  if not T.DECK_LOGIN then return false end
  D.Build()
  local st = D.Store()
  if not D.W then D.Place(st.shape == "landscape" and "landscape" or "portrait") end
  D.Look()
  D.frame:Show()
  D.Wake()
  D.Paint()
  st.open = true
  return true
end
function D.Hide() if D.frame then D.Store().open = false D.frame:Hide() D.Save() end end
function D.Toggle() if D.frame and D.frame:IsShown() then D.Hide() else D.Show() end end

-- one beat, only while shown: a dirty deck paints, a held corner sizes
function D.Wake()
  local f, acc = D.frame, 0
  f:SetScript("OnUpdate", function(_, el)
    acc = acc + (el or 0)
    if D.grip then
      if acc >= 0.05 then acc = 0 D.GripMove() end
      return
    end
    if acc < D.BEAT then return end
    acc = 0
    if D.dirty then D.Paint() end
  end)
end
function D.Sleep() D.GripEnd() if D.frame then D.frame:SetScript("OnUpdate", nil) end end

--- A fight: barely there and the mouse goes through - legal at any moment, the skin is plain.
function D.Fight(on)
  D.fight = on and true or false
  local f = D.frame
  if not f then return end
  if on then D.DragEnd() D.GripEnd() D.Focus(false) end
  f:SetAlpha(on and D.FIGHT_ALPHA or 1)
  f:EnableMouse(not on)
  if f:IsShown() then D.Paint() end
end

-- heard always, all rare: the login, a fight, a zone, a group, resting
local ev = D.events or CreateFrame("Frame")
D.events = ev
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
  "PLAYER_UPDATE_RESTING", "GROUP_ROSTER_UPDATE", "PLAYER_LOGOUT" }) do pcall(ev.RegisterEvent, ev, e) end
function D.OnEvent(event)
  if event == "PLAYER_LOGIN" then
    T.DECK_LOGIN = true
    if D.Store().open then D.Show() end
  elseif event == "PLAYER_REGEN_DISABLED" then D.Fight(true)
  elseif event == "PLAYER_REGEN_ENABLED" then D.Fight(false) D.Look() D.Dirty()
  elseif event == "PLAYER_LOGOUT" then if D.store then D.Save() end
  elseif D.frame and D.frame:IsShown() then D.Look() D.Dirty() end
end
ev:SetScript("OnEvent", function(_, event) T.Deck.OnEvent(event) end)
if IsLoggedIn and ask(IsLoggedIn) then T.DECK_LOGIN = true end

T.DECK_READY = MINOR
