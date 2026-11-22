--[[
  BiSTheme / Deck.lua  --  ONE DECK FOR EVERY BiS ADDON (21 Nov 2026, v0: the skin).

  Arn, 21 Nov: "unifed ui", "this makes api our apps way easier", "we can put a bis memoris live cardd", "from the start
  rezisable and toggles", "in raid nights it changes profiles to raid bis guild and other stuff", "landscape can scale things to
  fulll screen and portrait can be our minimized mode". The plan: BiSTools/dev/DECK.md; where everything goes: DeckLayout.lua
  (pure, swept by dev/decklayout.lua); the research: BiSTools/dev/DECK-RESEARCH-KIT.md.

  AN ADDON HANDS IN DATA, NEVER A FRAME - that is its API:
    local H = BiSTheme.Deck.Register{
      owner = "BiSTools", key = "bosses", name = "Bosses", icon = "Bo", order = 10,
      card = { prio = fn -> number | nil (nil = no card now), lines = fn -> { title, note, value, right, ink, hot = true, list = { { left, right }, ... } (a large card's own lines, three at most) },
               buttons = fn -> { { word, fn }, ... }, profiles = { Dungeon = true } },
      page = { title = fn, kicker = fn, boxes = fn -> { { word, value, ink } }, tabs = fn -> { "BOSSES", "QUESTS" },
               rows = fn(tab) -> { { text, right, mark, ink, done, act = button } }, big = fn -> button, keys = fn -> { button },
               text = fn -> string, say = fn -> string, tick = true (its words change by the second while it is open),
               hero = fn -> { art = "radio", big, small, left, right, frac 0-1, ticks, at (the needle), on, fn } (ours only: the picture on top),
               steps = fn -> { { phase, text, note, button, done } } },
      dock = { word = "FIND", fn = fn, hot = fn }, badge = fn -> number, store = fn -> table (its own saved table),
      card.when = "news" (default: it comes by itself when prio answers) | "use" (only after you did something in the app - opening
        it and leaving is a peek), card.alive = fn -> is there still something to show?, card.tick = true (its words change by
        the second); prio / lines are handed `true` when the card is pulled out; a button with peek = true is not "use"
      state = fn -> "on" | "off" | "missing" (default on), about = words, turnOn = button,   -- not on: gray, opens what it is
      open = fn (the icon runs this instead of a page), dev = true (a tool of ours: gray, last), hidden = true (no icon),
      page.tour = { { text, note }, ... }                  -- shown once, the first time the page is opened
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
D.STRATA, D.FIGHT_STRATA = "HIGH", "LOW"                   -- over the bars and cards (22 Nov: the healing bars drew through it); in a fight under them
local HOMES = { portrait = { 260, 462 }, landscape = { 600, 420 } }
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
-- THE THEMES (Arn, 22 Nov: "Let's make Ryan gosling mode a mode you have to turn on theme , I like the clean style that you did
-- first , we like dark mode other people can change the theme"). Dark = the family's own colours, the default. Every theme is the
-- same names in other colours, so nothing on the deck knows which is on; dev/deck.lua measures each one's contrast.
-- A theme may have a `sky`: bands behind the head of the home screen, top to bottom (never behind a list).
D.THEMES = {
  { key = "dark", name = "Dark", hex = {} },
  { key = "drive", name = "Night drive", hex = { ground = "0b0814", card = "140e22", sunken = "211836", line = "33224f", line2 = "4a2f6b", ink = "f4ecfa", ink2 = "d6c8e6", dim = "a294b8",
      accent = "ff85c0", accentSoft = "3d1a44", warn = "ff9d7d" },
    sky = { "0b0814", "120b20", "1a1033", "241238", "2e1445", "3a1553", "6a2060", "a8446a" } },
  { key = "light", name = "Light", hex = { ground = "f6f4fa", card = "ffffff", sunken = "ebe7f3", line = "d8d0e8", line2 = "bdb1d6", ink = "191527", ink2 = "453d5e", dim = "5f5775",
      accent = "7a2fc4", accentSoft = "e6d6f8", good = "0b6b6d", gold = "765800", warn = "96305c" } },
  { key = "contrast", name = "High contrast", hex = { ground = "000000", card = "0d0d0d", sunken = "1c1c1c", line = "8a8a8a", line2 = "b4b4b4", ink = "ffffff", ink2 = "ffffff", dim = "e2e2e2",
      accent = "d3b0ff", accentSoft = "3a2a55", good = "5ff0e8", gold = "ffe14d", warn = "ffa6c6" } },
}
function D.Theme()
  local key = D.Store().theme
  for _, t in ipairs(D.THEMES) do if t.key == key then return t end end
  return D.THEMES[1]
end
function D.SetTheme(key)
  for _, t in ipairs(D.THEMES) do
    if t.key == key then
      D.Store().theme = key ~= "dark" and key or nil
      D.Save()
      D.Skin()
      D.Dirty(true)
      return true
    end
  end
  return false
end
local skin                                                -- the colours of the theme that is on (nil = the family's own)
local function rgb(name)
  local over = skin and skin[name]
  if T.rgb and not over then return T.rgb(name) end
  local h = over or T.hex[name] or T.hex.ink
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

--- "on", "off" or "missing": may it do its work? An icon that is not on is gray, says so in a word, and opens what it is.
function D.State(def)
  local s = def.state and D.Call(def, "state", def.state) or "on"
  return (s == "off" or s == "missing") and s or "on"
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

-- WHO IS LIVE (Arn, 22 Nov: "they open farm app they click around in it it'll show up as a live card if it makes sense if they
-- just looks at it and exit they just took a peek"): an app whose card is "use" gets its card when you press something that DOES
-- something in it, and keeps it until x, until the app says there is nothing left, or a long time. Per character.
D.LIVE_KEEP = 12 * 3600
function D.Mine()
  local st = D.Store()
  st.mine = type(st.mine) == "table" and st.mine or {}
  local who = ask(UnitGUID, "player")
  who = type(who) == "string" and who or "all"
  st.mine[who] = type(st.mine[who]) == "table" and st.mine[who] or {}
  local m = st.mine[who]
  m.live = type(m.live) == "table" and m.live or {}
  return m
end
D.WHENS = { "use", "news", "off" }
--- When this card may show: your own pick (the Apps page), else what the app asked for.
function D.When(def)
  local st = D.Store()
  local mine = type(st.cardWhen) == "table" and st.cardWhen[def.id]
  return mine or (def.card and def.card.when) or "news"
end
function D.SetWhen(def, when)
  local st = D.Store()
  st.cardWhen = type(st.cardWhen) == "table" and st.cardWhen or {}
  st.cardWhen[def.id] = when ~= ((def.card and def.card.when) or "news") and when or nil
  D.Save()
end
function D.IsLive(def)
  if not def.card or (def.guest and not (D.Added and D.Added(def))) then return false end
  local when = D.When(def)
  if when ~= "use" then return when == "news" end
  local live = D.Mine().live
  local at = live[def.id]
  if not at then return false end
  local now = ask(GetServerTime) or 0
  if (def.card.alive and not D.Call(def, "alive", def.card.alive)) or (type(at) == "number" and now - at > D.LIVE_KEEP) then
    live[def.id] = nil
    if D.PinBack and D.IsPinned(def.id) then D.Pins()[def.id] = nil end
    return false
  end
  return true
end
--- Something was DONE in this app: from now on it has a card, if it has anything to show.
function D.Used(def)
  if not (def and def.card and D.defs[def.id] == def) or D.When(def) ~= "use" then return false end
  if def.card.alive and not D.Call(def, "alive", def.card.alive) then return false end
  D.Mine().live[def.id] = ask(GetServerTime) or 0
  D.Save()
  return true
end
function D.EndLive(def) D.Mine().live[def.id] = nil D.Save() D.Dirty(true) end

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

--- Every icon there could be, in its place: what is on, then what is off, what you do not have, and our own tools last.
function D.Icons()
  local ranks = { on = {}, off = {}, missing = {}, dev = {} }
  for _, d in ipairs(sorted()) do
    if not d.hidden and (d.page or d.open or d.about) and not (d.guest and not (D.Added and D.Added(d))) then
      local s = d.dev and "dev" or D.State(d)
      table.insert(ranks[s], { d, s })
    end
  end
  local out = {}
  for _, k in ipairs({ "on", "off", "missing", "dev" }) do for _, x in ipairs(ranks[k]) do out[#out + 1] = x end end
  return out
end
--- Is this icon on the home screen? (hidden by hand, or the switch for what you do not have)
function D.Shown(def, state)
  local st = D.Store()
  if def.guest and not (D.Added and D.Added(def)) then return false end              -- (another addon's app: when you pressed ADD)
  if def.quietOff and state == "off" then return st.apps[def.id] == true end        -- (a tool that is off: the Apps page has it)
  if st.apps[def.id] == false then return false end
  return not (state == "missing" and st.sw.missing == false)
end
local function shownApps()
  local out = {}
  for _, x in ipairs(D.Icons()) do if D.Shown(x[1], x[2]) then out[#out + 1] = x[1] end end
  return out
end
--- The cards that have something to say now, the most urgent first (a tie keeps its order).
function D.Cards()
  local st, out = D.Store(), {}
  for i, d in ipairs(sorted()) do
    local c = d.card
    if c and d.card and D.IsPinned and D.IsPinned(d.id) and not d.parked then
      out[#out + 1] = { def = d, p = -0.5, i = i, slot = true, lines = { (d.name or d.key):upper(), "", "On your screen", "", "dim" }, buttons = {} }
    elseif c and st.apps[d.id] ~= false and D.IsLive(d) and not (c.profiles and not c.profiles[D.profile or ""]) then
      local p = D.Call(d, "prio", c.prio or 1)
      local l = type(p) == "number" and D.Call(d, "lines", c.lines) or nil
      if d.parked then out[#out + 1] = { def = d, p = -1, i = i, lines = { d.name or d.key, "", "stopped after errors", "", "dim" } }
      elseif type(l) == "table" then out[#out + 1] = { def = d, p = p, i = i, lines = l, buttons = D.Call(d, "buttons", c.buttons) or {} } end
    end
  end
  table.sort(out, function(a, b) if a.p ~= b.p then return a.p > b.p end return a.i < b.i end)
  return out
end
-- HOW BIG (DeckLayout's T.DeckCards decides; here: what it is told). A card keeps the size it has for D.SIZE_HOLD seconds, so the
-- deck does not breathe; your own pick (Apps > CARDS) is kept for good.
D.SIZES = { "auto", "S", "M", "L" }
D.SIZE_HOLD = 10
function D.SizePick(id)
  local st = D.Store()
  local s = type(st.cardSize) == "table" and st.cardSize[id]
  return (s == "S" or s == "M" or s == "L") and s or "auto"
end
function D.SetSize(id, size)
  local st = D.Store()
  st.cardSize = type(st.cardSize) == "table" and st.cardSize or {}
  st.cardSize[id] = size ~= "auto" and size or nil
  D.sizeHeld = nil
  D.Save()
  D.Dirty(true)
end
function D.CardSizes(cards)
  local out, t = {}, GetTime and ask(GetTime) or 0
  for i, c in ipairs(cards) do
    local pick = D.SizePick(c.def.id)
    local held = D.sizeHeld and D.sizeHeld[c.def.id]
    local size = pick ~= "auto" and pick or nil
    if c.slot then size = "M"
    elseif not size and held and held.at + D.SIZE_HOLD > t and held.n == #cards then size = held.size end
    local list = c.lines and c.lines.list
    out[i] = { p = c.p, lines = type(list) == "table" and #list or 0, btn = not c.slot and #(c.buttons or {}) > 0, size = size }
  end
  return out
end
local function dockList()
  local st, out = D.Store(), {}
  for _, d in ipairs(sorted()) do if d.dock and st.apps[d.id] ~= false then out[#out + 1] = d end end
  return out
end

D.SWITCHES = {
  -- EASIER TO USE (Arn, 22 Nov: "let's make it easy for people with accessibility and gamepad support"): off until asked for
  { "EASIER TO USE", { { "speak", "Read aloud", easy = true }, { "strong", "Stronger words", easy = true } } },
  { "THEME", { { "dark", "Dark", theme = true }, { "drive", "Night drive", theme = true }, { "light", "Light", theme = true }, { "contrast", "High contrast", theme = true } } },
  { "HOME", { { "cards", "Live cards" }, { "apps", "App icons" }, { "dock", "Dock" }, { "missing", "Addons you do not have" }, { "pinfight", "Pinned cards in a fight" } } },
  { "PAGES", { { "hero", "Pictures" }, { "boxes", "Number boxes" }, { "tabs", "Tabs" }, { "strip", "Progress strip" }, { "say", "Last action line" }, { "keys", "Small buttons" } } },
  { "STEPS", { { "list", "Step list" } } },
  { "EVERYWHERE", { { "signs", "Signal, WiFi, battery" }, { "code", "Faint code line" } } },
}

--- The data of the open page, asked once a paint.
function D.Model()
  local m = { page = D.page or "home" }
  m.status = D.Status and D.Status() or nil
  m.apps = shownApps()
  if m.page == "home" then
    m.cards, m.dock = D.Cards(), dockList()
    for _, c in ipairs(m.cards) do if c.def.card.tick and not c.slot then D.ticking = true end end
    if (D.cardSkip or 0) >= #m.cards then D.cardSkip = nil end
    m.view = { kind = "home", cards = D.CardSizes(m.cards), apps = #m.apps, dock = #m.dock, appSkip = D.appSkip, cardSkip = D.cardSkip }
    m.title, m.kicker = "BiS>", (D.profile or "") .. (D.Store().pin and " - pinned" or "")
  elseif m.page == "switches" then
    local groups = {}
    for i, g in ipairs(D.SWITCHES) do groups[i] = #g[2] end
    m.view = { kind = "switches", groups = groups, skip = D.skip or 0 }
    m.title, m.kicker = "Switches", "PER CHARACTER"
  else
    local d = D.defs[m.page]
    local p = d and d.page
    local state = d and not d.parked and D.State(d) or "on"
    if d and not d.parked and d.about and (state ~= "on" or not p) then
      -- what it is, and one button to have it: a gray icon's page
      m.def, m.about = d, state
      m.title, m.kicker = d.name or d.key, state == "missing" and "not installed" or state == "off" and "off" or "on"
      m.text = tostring(D.Call(d, "about", d.about) or "")
      m.big = state == "off" and d.turnOn or nil
      if state == "missing" then m.text = m.text .. " Get it: in the CurseForge app, search for " .. (d.find or d.owner) .. "." end
      m.boxes, m.tabs, m.rows, m.keys, m.tab = {}, {}, {}, {}, 1
      m.view = { kind = "page", boxes = 0, tabs = 0, rows = 0, keys = 0, big = m.big and true or nil, textLines = math.ceil(#m.text / D.Letters()), apps = #m.apps, appSkip = D.appSkip }
      return m
    end
    if not p or d.parked then D.page = "home" if d and d.parked then d.parkedSaid = true end return D.Model() end
    m.def = d
    m.title, m.kicker = D.Call(d, "title", p.title) or d.name, D.Call(d, "kicker", p.kicker) or (d.name or ""):upper()
    if d.card and D.When(d) == "use" and D.IsLive(d) then m.kicker = tostring(m.kicker) .. " - live" end
    m.steps = p.steps and D.Call(d, "steps", p.steps) or nil
    local tour = D.Tour(d)
    if tour then m.def, m.steps, m.kicker = tour, tour.steps, "first time here" end
    m.big = p.big and D.Call(d, "big", p.big) or nil
    m.keys = p.keys and D.Call(d, "keys", p.keys) or {}
    if type(m.steps) == "table" and #m.steps > 0 then
      m.cur = D.StepAt(m.def, m.steps)
      local s = m.steps[m.cur]
      m.big = s.button
      m.view = { kind = "steps", steps = #m.steps, textLines = math.min(4, math.ceil(#tostring(s.text or "") / 34)), note = s.note and true or nil, keys = 0,
        skip = math.max(0, m.cur - 3 + (D.skip or 0)) }                 -- (the step you are on stays in sight)
    else
      m.tabs = p.tabs and D.Call(d, "tabs", p.tabs) or {}
      m.tab = math.max(1, math.min(#m.tabs, d.tab or 1))
      m.boxes = p.boxes and D.Call(d, "boxes", p.boxes) or {}
      m.rows = p.rows and D.Call(d, "rows", p.rows, m.tab) or {}
      m.text = p.text and D.Call(d, "text", p.text) or nil
      m.hero = p.hero and D.Call(d, "hero", p.hero) or nil
      if p.tick then D.ticking = true end
      m.say = p.say and D.Call(d, "say", p.say) or nil
      m.view = { kind = "page", boxes = #m.boxes, tabs = #m.tabs, rows = #m.rows, keys = #m.keys, big = m.big and true or nil,
        say = m.say and true or nil, hero = m.hero and true or nil, textLines = m.text and math.max(1, math.ceil(#m.text / D.Letters())) or 0, apps = #m.apps, appSkip = D.appSkip, skip = D.skip or 0 }
    end
  end
  return m
end

--- A page's first visit: its own words, one at a time, GOT IT; then never again (the Apps page has them all back).
function D.Tour(def)
  local list = def.page and def.page.tour
  local st = D.Store()
  st.toured = type(st.toured) == "table" and st.toured or {}
  if type(list) ~= "table" or #list == 0 or st.toured[def.id] then return nil end
  local t = def.tourDef
  if not t then
    t = { id = def.id .. ":tour", owner = def.owner, key = def.key, name = def.name, at = 0, skipped = {}, steps = {} }
    def.tourDef = t
    function t.over() D.Store().toured[def.id] = true def.tourDef = nil D.Save() end
    for i, s in ipairs(list) do
      t.steps[i] = { phase = "HELLO", text = s.text, note = s.note, done = function() return t.at >= i end,
        button = { word = i < #list and "GOT IT" or "START", fn = function() t.at = math.max(t.at, i) t.stepAt, t.stepHeld = nil, nil if i == #list then t.over() end end } }
    end
  end
  return t
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
  if how == "skip" and def.over then def.over()              -- (a tour's skip = enough of it)
  elseif how == "skip" then def.skipped[at] = true def.stepAt, def.stepHeld = nil, nil
  else def.stepAt, def.stepHeld = math.max(1, math.min(#steps, at + (how == "back" and -1 or 1))), true end
  D.Dirty(true)
end

-- THE SKIN ----------------------------------------------------------------------------------------------------------

local CLICK = { close = 1, shape = 1, gear = 1, status = 1, back = 1, home = 1, hero = 1, card = 1, app = 1, railapp = 1, dock = 1, tab = 1, row = 1, big = 1, key = 1,
  link = 1, step = 1, preset = 1, switch = 1, cardbtn = 1, more = 1, moreapps = 1, cardout = 1, cardend = 1, less = 1, plus = 1, side = 1, morecards = 1 }
local LOOK = {                                            -- kind -> ground colour, alpha
  card = { "card", 1 }, dockbar = { "card", 0.7 }, dock = { "sunken", 0.8 }, box = { "card", 1 }, tab = { "card", 1 }, row = { "sunken", 0.55 },
  step = { "sunken", 0.55 }, switch = { "sunken", 0.55 }, big = { "gold", 0.22 }, key = { "sunken", 0.8 }, preset = { "sunken", 0.8 }, more = { "sunken", 0.8 },
  hero = { "card", 1 }, text = { "card", 1 }, progress = { "sunken", 1 }, stepcard = { "card", 1 }, strip = { "line", 1 },
  cardbtn = { "sunken", 1 }, cardout = { "sunken", 1 }, cardend = { "sunken", 1 }, less = { "sunken", 1 }, plus = { "sunken", 1 }, side = { "sunken", 1 }, morecards = { "sunken", 0.8 }, grip = { "line", 0 }, app = { "card", 1 }, railapp = { "card", 1 },
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
    local tip = self.tip
    for _, fs in ipairs({ self.a, self.c, self.b }) do             -- (cut off: said in full under the mouse)
      if fs.IsTruncated and ask(fs.IsTruncated, fs) == true and type(fs.said) == "string" and fs.said ~= tip then tip = fs.said .. (tip and "\n" .. tip or "") end
    end
    if tip and GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  w:SetScript("OnLeave", function(self) self.wash:Hide() if GameTooltip then GameTooltip:Hide() end end)
  w:RegisterForDrag("LeftButton")                          -- (a card is pulled out by dragging it: DeckPins.lua)
  w:SetScript("OnDragStart", function(self) if self.dragId and not D.fight and D.PinOut then D.PinOut(self.dragId, true) end end)
  w:SetScript("OnDragStop", function() if D.PinDrop then D.PinDrop() end end)
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

-- Words that wrap (Arn, 22 Nov: "dont like how stuff is cutoff" - "Your usual group: invite them all, or disband, i..." on one line
-- of a box two lines high): the wrap used to go off and on at every paint with the words never set again after it, and the client
-- lays words out when they are SET. So: touched only when it changes, and the words are set again.
local WRAPS = { text = 1, steptext = 1 }
local function wrap(fs, on)
  if fs.wraps == on then return end
  fs.wraps = on
  fs.said = nil
  fs:SetWordWrap(on)
end

--- Read aloud what the mouse or the pad is on (the PC's own voice; a switch, off until asked for; never in a fight).
function D.Speak(w)
  if D.fight or not (D.Store().easy or {}).speak then return false end
  if not (C_VoiceChat and C_VoiceChat.SpeakText) then return false end
  local out = { w.aloud }
  for _, fs in ipairs(w.aloud and {} or { w.c, w.a, w.b }) do
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
  if type(b.fn) == "function" then
    return function()
      D.Call(def, "button", b.fn)
      if not b.peek then D.Used(def) end
      if D.PinsPaint then D.PinsPaint() end
      D.Dirty(true)
    end
  end
  return nil
end
D.Press = press
function D.IsSecure(b) return type(b) == "table" and (b.macro or b.item or b.spell) and true or false end

--- What each kind says and does. `w` = the piece, `o` = its box, `m` = the model.
local PAINT = {}
function PAINT.clock(w, o, m)
  say(w.a, date and date("%H:%M") or "", 11, "ink")
  if m.status and m.status.resting and D.Store().sw.signs ~= false then D.DrawBed(w, 31, math.floor(o.h / 2) - 5) end
end
function PAINT.status(w, o, m)
  local s = m.status
  if not s then return end
  D.DrawStatus(w, s, o.h)
  local words = D.StatusWords(s)
  w.act = function() D.page = D.page == "BiSDeck:status" and "home" or "BiSDeck:status" D.Dirty(true) end
  w.tip = table.concat(words, "\n")
  w.aloud = table.concat(words, ", ")
end
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
  if o.size == "S" then
    local short = l[4] ~= nil and l[4] ~= "" and l[4] or l[3] or ""
    say(w.a, short, 15, l[4] ~= nil and l[4] ~= "" and l[5] or "ink")
    w.tip = l[3] ~= nil and l[3] ~= "" and tostring(l[1] or "") .. ": " .. tostring(l[3]) or nil
  else
    say(w.a, l[3] or "", 16, "ink")
    say(w.b, l[4] or "", 15, l[5] or "ink2", "RIGHT")
  end
  w.hot = l.hot
  if c and not c.slot and D.PinOut then w.dragId = c.def.id end
  if c and (c.def.page or c.def.open) then w.act = function() D.Open(c.def.id) end end
end
function PAINT.app(w, o, m)
  local d = m.apps[o.i]
  if not d then return end
  local state = d.dev and "dev" or D.State(d)
  local gray = state ~= "on"
  local art = d.art or (D.ART and D.ART[d.id])
  if art then
    if not w.pic then
      w.pic = w:CreateTexture(nil, "ARTWORK")
      w.pic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if w.pic.art ~= art then w.pic.art = art w.pic:SetTexture(art) end
    local s = o.wide and 26 or o.kind == "app" and math.floor(math.min(34 * (o.k or 1), o.h - 24)) or 34
    w.pic:ClearAllPoints()
    if o.wide then w.pic:SetPoint("LEFT", w, "LEFT", 5, 0)
    elseif o.kind == "app" then w.pic:SetPoint("TOP", w, "TOP", 0, -5)
    else w.pic:SetPoint("CENTER", w, "CENTER", 0, 0) end
    w.pic:SetSize(s, s)
    if w.pic.SetDesaturated then w.pic:SetDesaturated(gray) end
    w.pic:SetAlpha(gray and 0.55 or 1)
    w.pic:Show()
  end
  say(w.a, art and "" or d.icon or (d.name or "?"):sub(1, 2), math.floor(15 * (o.k or 1)), gray and "dim" or "ink", "CENTER")
  say(w.c, (o.kind == "app" or o.wide) and (d.name or "") or "", o.k and o.k > 1.3 and 13 or 11, gray and "dim" or "ink2", o.wide and "LEFT" or "CENTER")
  local n = (state == "on" or state == "dev") and d.badge and D.Call(d, "badge", d.badge)
  if type(n) == "number" and n > 0 then say(w.b, tostring(n), 11, gray and "dim" or "gold", "RIGHT")
  else say(w.b, o.kind == "app" and ({ off = "OFF", missing = "GET", dev = "DEV" })[state] or "", 10, "dim", "RIGHT") end   -- (a word, never the gray alone)
  w.act = function() D.Open(d.id) end
  w.tip = (d.name or d.key) .. (({ off = " - off: what it is, and a button to turn it on", missing = " - you do not have it: what it is", dev = " - a tool of ours" })[state] or "")
end
PAINT.railapp = PAINT.app
function PAINT.morecards(w, o, m)
  local n = o.i or 0
  say(w.a, n > 0 and (n .. " MORE CARDS") or "BACK TO THE FIRST", 11, "accent", "CENTER")
  w.act = function()
    local at = (D.cardSkip or 0) + math.max(1, o.n or 1)
    D.cardSkip = n > 0 and at < #m.cards and at or nil
    D.Dirty(true)
  end
end
function PAINT.cardline(w, o)
  say(w.a, o.left or "", 12, "ink2")
  say(w.b, o.right or "", 12, "ink2", "RIGHT")
end
function PAINT.moreapps(w, o, m)
  say(w.a, "MORE", 11, "accent", "CENTER")
  w.act = function()
    local at = (D.appSkip or 0) + math.max(1, o.i)
    D.appSkip = at < #m.apps and at or 0
    D.Dirty(true)
  end
  w.tip = "More icons"
end
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
  w.keys = (r.less or r.more or r.side) and true or nil
end
local function button(w, b, def, size)
  local sec = D.IsSecure(b)
  say(w.a, b and b.word or "", size, sec and "dim" or "ink", "CENTER")
  w.act = press(def, b)
  w.tip = sec and "This button comes with the next step of the deck" or (b and b.tip)
end
function PAINT.big(w, o, m) button(w, m.big, m.def, 16) end
function PAINT.key(w, o, m) button(w, m.keys[o.i], m.def, 12) end
--- The picture on top of a page. One kind so far: a RADIO - the song big, the dial with its needle, the time, bars that step once
--- a second while it plays (never faster, none in a fight: the deck is not painted then).
D.HERO = {}
function D.HERO.radio(w, o, h)
  local bar, rgbx = D.Bits and D.Bits.bar, rgb
  say(w.c, h.small or "", 11, "accent")
  say(w.a, h.big or "", 18, "ink")
  say(w.b, (h.left or "") .. ((h.left and h.right) and "  /  " or "") .. (h.right or ""), 11, "ink2", "RIGHT")
  if not bar then return end
  local W, H, pad = o.w, o.h, 10
  -- how far: a thin line under the words
  local y = math.floor(H * 0.62)
  bar(w, 1, pad, y, W - 2 * pad, 2, "line2")
  if (h.frac or 0) > 0 then bar(w, 2, pad, y, math.max(2, (W - 2 * pad) * math.min(1, h.frac)), 2, "accent") end
  -- the dial: a tick a station, the needle on ours
  local n, base = math.max(2, math.min(60, h.ticks or 12)), H - 9
  for i = 1, n do
    local long = (i - 1) % 5 == 0
    bar(w, 10 + i, pad + (W - 2 * pad - 1) * (i - 1) / (n - 1), base - (long and 10 or 6), 1, long and 10 or 6, long and "ink2" or "line2")
  end
  bar(w, 3, pad + (W - 2 * pad - 2) * ((math.max(1, math.min(n, h.at or 1)) - 1) / (n - 1)), base - 15, 2, 17, "gold")
  -- the bars, top right
  local t = math.floor(GetTime and ask(GetTime) or 0)
  for i = 1, 9 do
    local high = h.on and 3 + ((t * 7 + i * i * 5 + (t % 3) * i) % 13) or 2
    bar(w, 80 + i, W - pad - 9 * 5 + (i - 1) * 5, 10 + 16 - high, 3, high, h.on and (high > 11 and "gold" or "accent") or "line2")
  end
end
function PAINT.hero(w, o, m)
  local h = m.hero
  if type(h) ~= "table" or not D.HERO[h.art or "radio"] then return end
  D.HERO[h.art or "radio"](w, o, h)
  w.act = h.fn and press(m.def, { fn = h.fn, peek = h.peek }) or nil
  w.tip = h.tip
end
function PAINT.say(w, o, m) say(w.a, m.say or "", 11, "ink2") end
function PAINT.text(w, o, m) say(w.a, m.text or "", 12, "ink2") end
function PAINT.stephead(w, o, m) local s = m.steps[m.cur] say(w.a, "STEP " .. m.cur .. " - " .. tostring(s.phase or ""), 11, "accent") say(w.b, s.isDone and "done" or "watching", 11, "dim", "RIGHT") end
function PAINT.steptext(w, o, m) say(w.a, tostring(m.steps[m.cur].text or ""), 15, "ink") end
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
function PAINT.more(w, o) say(w.a, "MORE ...", 12, "accent", "CENTER") w.act = function() D.Scroll(math.max(1, o.i)) end end
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
  if s.theme then
    isOn = D.Theme().key == s[1]
    say(w.a, s[2], 13, isOn and "ink" or "ink2")
    say(w.b, isOn and "ON" or "", 12, "good", "RIGHT")
    w.lit = isOn
    w.act = function() D.SetTheme(s[1]) end
    return
  end
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

D.Kit = { piece = piece, say = say, rgb = rgb }            -- (DeckPins.lua draws with the same)

--- Where a piece's words stand, by what it is.
local function words(w, o)
  w.a:ClearAllPoints() w.b:ClearAllPoints() w.c:ClearAllPoints()
  w.a:SetJustifyV("MIDDLE")
  if o.kind == "card" and o.size == "S" then
    w.c:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -5) w.c:SetPoint("TOPRIGHT", w, "TOPRIGHT", -28, -5)
    w.a:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 8, 5) w.a:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -6, 5)
  elseif o.kind == "card" then
    -- (from the top: the kicker, the words and the number; its lines and its buttons come under them)
    w.c:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -5) w.c:SetPoint("TOPRIGHT", w, "TOPRIGHT", -64, -5)
    w.b:SetPoint("TOPRIGHT", w, "TOPRIGHT", -8, -24)
    w.a:SetPoint("TOPLEFT", w, "TOPLEFT", 8, -23) w.a:SetPoint("TOPRIGHT", w, "TOPRIGHT", -o.w * 0.38, -23)
  elseif o.kind == "cardline" then
    w.a:SetPoint("LEFT", w, "LEFT", 0, 0) w.b:SetPoint("RIGHT", w, "RIGHT", 0, 0) w.a:SetPoint("RIGHT", w.b, "LEFT", -6, 0)
  elseif o.kind == "box" then
    w.c:SetPoint("TOPLEFT", w, "TOPLEFT", 6, -3) w.a:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 6, 2)
  elseif o.kind == "app" then
    w.a:SetPoint("TOP", w, "TOP", 0, -math.floor(o.h * 0.2)) w.c:SetPoint("BOTTOM", w, "BOTTOM", 0, 3) w.b:SetPoint("TOPRIGHT", w, "TOPRIGHT", -6, -3)
  elseif o.kind == "railapp" and o.wide then
    w.a:SetPoint("LEFT", w, "LEFT", 4, 0) w.a:SetPoint("RIGHT", w, "LEFT", 34, 0) w.b:SetPoint("RIGHT", w, "RIGHT", -6, 0)
    w.c:SetPoint("LEFT", w, "LEFT", 40, 0) w.c:SetPoint("RIGHT", w, "RIGHT", -26, 0)
  elseif o.kind == "railapp" then
    w.a:SetPoint("CENTER", w, "CENTER", 0, 0) w.b:SetPoint("TOPRIGHT", w, "TOPRIGHT", -4, -3) w.c:SetPoint("BOTTOM", w, "BOTTOM", 0, 0)
  elseif o.kind == "row" or o.kind == "step" then
    w.c:SetPoint("LEFT", w, "LEFT", 7, 0) w.b:SetPoint("RIGHT", w, "RIGHT", w.keys and -58 or -6, 0)
    w.a:SetPoint("LEFT", w, "LEFT", 24, 0) w.a:SetPoint("RIGHT", w.b, "LEFT", -6, 0)
  elseif o.kind == "text" or o.kind == "steptext" then
    w.a:SetJustifyV("TOP")
    w.a:SetPoint("TOPLEFT", w, "TOPLEFT", o.kind == "text" and 8 or 0, o.kind == "text" and -5 or 0) w.a:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", o.kind == "text" and -8 or 0, 0)
  elseif o.kind == "switch" or o.kind == "slider" or o.kind == "stephead" then
    w.a:SetPoint("LEFT", w, "LEFT", o.kind == "stephead" and 0 or 8, 0) w.b:SetPoint("RIGHT", w, "RIGHT", o.kind == "stephead" and 0 or -8, 0)
  elseif o.kind == "hero" then
    w.c:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -8) w.c:SetPoint("TOPRIGHT", w, "TOPRIGHT", -62, -8)
    w.a:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -24) w.a:SetPoint("TOPRIGHT", w, "TOPRIGHT", -10, -24)
    w.b:SetPoint("TOPRIGHT", w, "TOPRIGHT", -10, -math.floor(o.h * 0.62) - 4)
  elseif o.kind == "status" then
    -- (the battery's number is placed where the battery is drawn)
    w.a:SetPoint("TOPLEFT", w, "TOPLEFT", 38, -(math.floor(o.h / 2) - 6)) w.a:SetPoint("BOTTOMRIGHT", w, "TOPLEFT", 63, -(math.floor(o.h / 2) + 7))
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
  f:SetFrameStrata(D.STRATA)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not D.fight then self:StartMoving() self.moving = true end end)
  f:SetScript("OnDragStop", function() D.DragEnd() end)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints(f)
  if f.EnableMouseWheel then f:EnableMouseWheel(true) end
  f:SetScript("OnMouseWheel", function(_, delta) if not D.fight then D.Scroll(-(delta or 0)) end end)
  f:SetScript("OnHide", function() D.DragEnd() D.Sleep() end)
  -- THE CORNER IS ITS OWN FRAME, NEVER ONE OF THE PIECES (Arn, 22 Nov, the first look: "when i drag to resize i cant let go" -
  -- 2466 wide): a piece is another box after the next paint, hidden or deaf, and the client tells the letting go to the frame
  -- that was pressed. It also never takes a drag (a Button with RegisterForDrag may get OnDragStop in place of OnMouseUp).
  local c = CreateFrame("Button", nil, f)
  f.corner = c
  c:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  c:SetSize(30, 30)
  c.wash = c:CreateTexture(nil, "ARTWORK")
  c.wash:SetAllPoints(c)
  c.wash:Hide()
  c:SetScript("OnEnter", function(self)
    local r, g, b = rgb("accent")
    self.wash:SetColorTexture(r, g, b, 0.3)
    self.wash:Show()
    if GameTooltip then GameTooltip:SetOwner(self, "ANCHOR_LEFT") GameTooltip:SetText("Pull: the size. Double-click: its normal size.") GameTooltip:Show() end
  end)
  c:SetScript("OnLeave", function(self) self.wash:Hide() if GameTooltip then GameTooltip:Hide() end end)
  c:SetScript("OnMouseDown", function(_, b) if not D.fight and (b == nil or b == "LeftButton") then D.GripStart() end end)
  c:SetScript("OnMouseUp", function() D.GripEnd() end)
  c:SetScript("OnDoubleClick", function() if not D.fight then D.GripEnd() D.Normal() end end)
  f:Hide()
  D.frame = f
  D.Skin()
  return f
end
function D.DragEnd()
  local f = D.frame
  if not (f and f.moving) then return end
  f.moving = nil
  pcall(f.StopMovingOrSizing, f)
  D.KeepPlace()
end
function D.KeepPlace()
  local f = D.frame
  local ok, p, _, rp, x, y = pcall(f.GetPoint, f, 1)
  if ok and type(plain(p)) == "string" and type(plain(x)) == "number" then
    local st = D.Store()
    st[T.DeckShape(D.W, D.H)] = st[T.DeckShape(D.W, D.H)] or {}
    st[T.DeckShape(D.W, D.H)].pos = { p, plain(rp) or p, x, y }
    D.Save()
    D.Dirty()
  end
end

--- As big as the screen lets it be (nil = the client does not say).
function D.Room()
  local f = D.frame
  local u = UIParent or {}
  local w, h = ask(u.GetWidth, u), ask(u.GetHeight, u)
  local s = f and ask(f.GetScale, f)
  if type(w) ~= "number" or type(h) ~= "number" or w < 400 or h < 300 then return nil end
  if type(s) ~= "number" or s <= 0 then s = D.SCALE end
  return w / s * 0.9, h / s * 0.94
end
function D.Fit(w, h)
  local rw, rh = D.Room()
  if rw then
    local tall = h >= w
    w, h = math.min(w, rw), math.min(h, rh)
    if tall then w = math.min(w, h) elseif w <= h then h = w - 1 end
  end
  return T.DeckClamp(w, h)
end
function D.Normal() D.Size(HOMES[D.shape][1], HOMES[D.shape][2]) D.Save() end
--- The size and place kept for this shape (each shape has its own).
function D.Place(shape)
  local st, f = D.Store(), D.frame
  st[shape] = type(st[shape]) == "table" and st[shape] or {}
  local s = st[shape]
  f:SetScale(st.scale or D.SCALE)
  D.W, D.H = D.Fit(s.w or HOMES[shape][1], s.h or HOMES[shape][2])
  D.shape = shape
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
--- How many letters of a 12 px line fit the words' box (a wide deck has them beside its list).
function D.Letters()
  local W = (D.W or 260) - 20
  if D.shape == "landscape" then W = (W - (W >= 560 and (W >= T.DECK_L.RAIL_NAMES and 140 or 60) or 0)) * 0.55 end
  return math.max(24, math.floor((W - 16) / 5.6))
end
--- A new size (the corner, the sliders): kept for the shape it has. Pulled wider than tall it IS the wide deck, and back (Arn,
--- 22 Nov: "left bar stayed to same did not reframe" - it used to stop at a square). Too small to be wide: it stays tall.
function D.Size(w, h)
  local L = T.DECK_L
  if w > h and (w < L.MIN_LW or h < L.MIN_LH) then h = w end
  w, h = D.Fit(w, h)
  local shape = T.DeckShape(w, h)
  local st = D.Store()
  if shape ~= D.shape then
    local g, was = D.grip, st[D.shape]
    if g and g.shape == D.shape and was then was.w, was.h = g.w, g.h end           -- (the shape it left keeps the size it had)
    D.shape, st.shape = shape, shape
    if not g then D.KeepPlace() end
  end
  st[shape] = type(st[shape]) == "table" and st[shape] or {}
  local s = st[shape]
  s.w, s.h, D.W, D.H = w, h, w, h
  D.frame:SetSize(w, h)
  D.Dirty(true)
end
function D.Preset(i)
  local st = D.Store()
  st.sw = {}
  local off = i == 2 and { "hero", "strip", "say", "keys", "missing" } or i == 3 and { "hero", "strip", "say", "keys", "cards", "boxes", "dock", "code", "missing", "signs" } or {}
  for _, k in ipairs(off) do st.sw[k] = false end
  D.Save()
  D.Dirty(true)
end

--- The theme's colours on what is not drawn afresh each paint: the ground, the hover wash, the words, the sky.
function D.Skin()
  local f, th = D.frame, D.Theme()
  skin = next(th.hex) and th.hex or nil
  if not f then return end
  f.bg:SetColorTexture(rgb("ground"))
  f.bg:SetAlpha(0.97)
  local function wear(list)
    for _, w in ipairs(list) do
      w.a.tone, w.b.tone, w.c.tone = nil, nil, nil
      local r, g, b = rgb("accent")
      w.wash:SetColorTexture(r, g, b, 0.22)
    end
  end
  wear(f.pieces)
  for _, p in pairs(D.pinFrames or {}) do wear(p.pieces) end
  if D.PinsPaint then D.PinsPaint() end
  D.Sky()
end
D.SKY_BAND = 8
local ROOFS = { 5, 9, 3, 7, 11, 4, 8, 3, 10, 6, 4, 9, 5, 12, 3, 7 }       -- a skyline: heights, over and over
--- The sky behind the head of the home screen, when the theme has one: bands, and roofs on the last of them. Never moves.
function D.Sky()
  local f, th = D.frame, D.Theme()
  if not f then return end
  f.sky = f.sky or {}
  local want = th.sky and (D.page or "home") == "home" and th.key .. ":" .. math.floor(D.W or 0) or ""
  if f.skyIs == want then return end
  f.skyIs = want
  local n = 0
  local function bar(x, y, w, h, hex, layer)
    n = n + 1
    local t = f.sky[n]
    if not t then t = f:CreateTexture(nil, "BORDER") f.sky[n] = t end
    if t.SetDrawLayer then t:SetDrawLayer("BORDER", layer) end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
    t:SetSize(w, h)
    t:SetColorTexture(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, 1)
    t:Show()
  end
  if want ~= "" then
    for i, hex in ipairs(th.sky) do bar(0, (i - 1) * D.SKY_BAND, D.W, D.SKY_BAND, hex, 0) end
    local foot, x, i = #th.sky * D.SKY_BAND, 0, 0
    while x < D.W do
      i = i + 1
      local h, w = ROOFS[(i - 1) % #ROOFS + 1], 6 + (i * 5) % 9
      w = math.min(w, D.W - x)
      bar(x, foot - h, w, h, th.hex.ground, 1)
      x = x + w + (i % 3)
    end
  end
  for i = n + 1, #f.sky do f.sky[i]:Hide() end
end

--- A row's - and + (an option with steps): two keys at its right end, the value left of them.
function D.RowKeys(put, o, m, f)
  local r = m.rows[o.i]
  if r and r.side then
    local w = put({ kind = "side", x = o.x + o.w - 50, y = o.y, w = 48, h = o.h })
    w:SetFrameLevel((f:GetFrameLevel() or 1) + 4)
    say(w.a, r.side.word or "", 11, "accent", "CENTER")
    w.act, w.tip = press(m.def, r.side), r.side.tip
    w:EnableMouse((w.act or w.tip) and not D.fight and true or false)
    return
  end
  if not (r and (r.less or r.more)) then return end
  for k, b in ipairs({ r.less, r.more }) do
    local w = put({ kind = k == 1 and "less" or "plus", x = o.x + o.w - (k == 1 and 52 or 26), y = o.y, w = 24, h = o.h })
    w:SetFrameLevel((f:GetFrameLevel() or 1) + 4)
    say(w.a, k == 1 and "-" or "+", 14, "accent", "CENTER")
    w.act = press(m.def, b)
    w.tip = b.tip
    w:EnableMouse((w.act or w.tip) and not D.fight and true or false)
  end
end
--- A card's own keys, at its top right: OUT (onto the screen; the same as dragging it), BACK for one that is out, x for one
--- that is live because you used its app.
function D.CardKeys(put, o, m, f)
  local c = m.cards[o.i]
  if not c or not D.PinOut then return end
  local x = o.x + o.w - 3
  local function key(kind, words, wide, fn, tip)
    x = x - wide
    local w = put({ kind = kind, x = x, y = o.y + 2, w = wide, h = 22 })
    x = x - 3
    w:SetFrameLevel((f:GetFrameLevel() or 1) + 4)
    say(w.a, words, 11, "ink2", "CENTER")
    w.act, w.tip = fn, tip
    w:EnableMouse(not D.fight)
  end
  if o.size == "S" then
    -- (half a row: only x, and only where x means something; a drag still pulls it out, a click opens it)
    if not c.slot and D.When(c.def) == "use" then key("cardend", "x", 24, function() D.EndLive(c.def) end, "Done with it") end
    return
  end
  if c.slot then return key("cardout", "BACK", 40, function() D.PinBack(c.def.id) end, "Back into the deck") end
  if D.When(c.def) == "use" then key("cardend", "x", 24, function() D.EndLive(c.def) end, "Done with it") end
  key("cardout", "OUT", 30, function() D.PinOut(c.def.id) end, "Onto your screen (or drag the card there)")
end

--- Draw the deck: the model, its layout, a piece for each box.
function D.Paint()
  local f = D.frame
  if not (f and f:IsShown()) or D.pinHeld then return 0 end
  D.ticking = nil
  local at = (D.page or "home") .. ":" .. tostring((D.defs[D.page or ""] or {}).tab)
  if D.skipAt ~= at then D.skipAt, D.skip = at, 0 end
  local m = D.Model()
  D.strong = (D.Store().easy or {}).strong and true or false
  D.Sky()
  local boxes = T.DeckLayout(m.view, D.W, D.H, D.Store().sw)
  local n = 0
  local function put(o)
    n = n + 1
    local w = f.pieces[n]
    if not w then w = piece(f) f.pieces[n] = w end
    w.act, w.tip, w.hot, w.lit, w.dragId, w.keys, w.aloud = nil, nil, nil, nil, nil, nil, nil
    if (w.bits or w.lines) and D.NoSigns then D.NoSigns(w) end
    if w.fill then w.fill:Hide() end
    if w.fill2 then w.fill2:Hide() end
    wrap(w.a, WRAPS[o.kind] and true or false)
    if w.pic then w.pic:Hide() end
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
    if o.kind == "row" then D.RowKeys(put, o, m, f) end
    if o.kind == "card" then
      D.CardKeys(put, o, m, f)
      local c = m.cards[o.i]
      if c and not c.slot then
        D.sizeHeld = D.sizeHeld or {}
        local was = D.sizeHeld[c.def.id]
        if not was or was.size ~= o.size or was.n ~= #m.cards then D.sizeHeld[c.def.id] = { size = o.size, n = #m.cards, at = GetTime and ask(GetTime) or 0 } end
      end
      local list = c and c.lines and type(c.lines.list) == "table" and c.lines.list or {}
      for i = 1, math.min(o.lines or 0, #list) do
        local x = type(list[i]) == "table" and list[i] or { list[i] }
        local w = put({ kind = "cardline", x = o.x + 8, y = o.y + 46 + (i - 1) * 17, w = o.w - 16, h = 16, left = x[1], right = x[2] })
        w:SetFrameLevel((f:GetFrameLevel() or 1) + 3)
      end
    end
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
      w:EnableMouse(false)                                 -- (drawn here; pressed on f.corner, D.Build)
    end
  end
  for i = n + 1, #f.pieces do f.pieces[i]:Hide() end
  f.corner:SetFrameLevel((f:GetFrameLevel() or 1) + 8)
  f.corner:EnableMouse(not D.fight)
  D.dirty = nil
  return n
end

-- the corner: the mouse's own travel over the deck's scale (the client's StartSizing cannot hold a shape, and sticks to the
-- mouse when a fight starts)
-- (pinned by its top left first: held in the middle it would grow both ways, away from the mouse)
function D.GripStart()
  local f = D.frame
  D.DragEnd()
  local l, t = ask(f.GetLeft, f), ask(f.GetTop, f)
  if type(l) == "number" and type(t) == "number" then
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
  end
  local s = f:GetEffectiveScale()
  local x, y = GetCursorPosition()
  D.grip = { x = x / s, y = y / s, w = D.W, h = D.H, shape = D.shape, s = s, at = 0, pinned = l and t and true }
end
--- Is the button still down? (false = let go; nil = the client does not say)
function D.Held() return ask(IsMouseButtonDown, "LeftButton") end
function D.GripMove()
  local g = D.grip
  if not g then return end
  local x, y = GetCursorPosition()
  D.Size(g.w + (x / g.s - g.x), g.h + (g.y - y / g.s))
end
function D.GripEnd()
  local g = D.grip
  if not g then return end
  D.grip = nil
  if g.pinned or g.shape ~= D.shape then D.KeepPlace() end
  D.Save()
  D.Dirty()
end

--- Something changed: painted at the next beat (`now` = at once), only while shown.
function D.Dirty(now)
  D.dirty = true
  if D.pinHeld then return end                             -- (a card is under the mouse: see DeckPins.lua)
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
  local m = D.Model()
  local def = m.def
  if not def then return false end
  if m.view.kind == "steps" then D.Step(def, m.steps, by < 0 and "back" or "next") return true end
  local tabs = m.tabs or {}
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
    T.PadNav(p, { items = D.PadItems, back = D.PadBack, tabs = { prev = function() D.PadTab(-1) end, next = function() D.PadTab(1) end },
      scroll = function(delta) D.Scroll(-(delta or 0)) end })
    D.padFrame = p
  end
  if not p then return false end
  if want then p:Show() else p:Hide() end
  D.focused = want and true or false
  return true
end

--- Scroll what is listed: the wheel, the pad's triggers, MORE. Another page or tab starts at its top.
function D.Scroll(by)
  local at = (D.page or "home") .. ":" .. tostring((D.defs[D.page or ""] or {}).tab)
  if D.skipAt ~= at then D.skipAt, D.skip = at, 0 end
  local was = D.skip or 0
  D.skip = was + by
  local least, most = 0, 0
  local f = D.frame
  if f and f:IsShown() then
    local m = D.Model()
    if m.view.kind == "steps" then least = -999 end
    local n = m.view.kind == "steps" and (m.view.steps or 0) or m.view.kind == "page" and (m.view.rows or 0) or 0
    if m.view.kind == "switches" then for _, k in ipairs(m.view.groups) do n = n + k + 1 end end
    most = n
  end
  D.skip = math.max(least, math.min(D.skip, math.max(0, most - 1)))
  D.Dirty(true)
end

--- An icon, a card, a handle: its page, or what `open` runs, or (not on) what it is.
function D.Open(id)
  local d = D.defs[id]
  if not d then return false end
  if d.open and D.State(d) == "on" then
    if D.fight then return false end
    D.Call(d, "open", d.open)
    return true
  end
  if not (d.page or d.about) then return false end
  D.page = id
  D.Show()
  D.Dirty(true)
  return true
end
function D.Show()
  if not T.DECK_LOGIN then return false end
  D.Build()
  local st = D.Store()
  if not D.W then D.Place(st.shape == "landscape" and "landscape" or "portrait") end
  if D.Apps then D.Apps() end                               -- (DeckApps.lua: the other addons' icons, the welcome)
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
  local f, acc, slow = D.frame, 0, 0
  f:SetScript("OnUpdate", function(_, el)
    acc = acc + (el or 0)
    -- (let go and never told: the button itself says so. A hold may not outlive the press.)
    if (D.grip or f.moving) and D.Held() == false then D.GripEnd() D.DragEnd() end
    if D.grip then
      if acc >= 0.05 then acc = 0 D.GripMove() end
      return
    end
    if acc < D.BEAT then return end
    acc = 0
    slow = slow + 1
    if slow >= 10 then slow = 0 D.dirty = true end         -- (the clock and the signs)
    if D.dirty or D.ticking then D.Paint() end
  end)
end
function D.Sleep() D.GripEnd() if D.frame then D.frame:SetScript("OnUpdate", nil) end end

--- A fight: barely there and the mouse goes through - legal at any moment, the skin is plain.
function D.Fight(on)
  if on and D.PinDrop then D.PinDrop() end                 -- (a held card stays where it is)
  D.fight = on and true or false
  if D.PinsPaint then D.PinsPaint() end
  local f = D.frame
  if not f then return end
  if on then D.DragEnd() D.GripEnd() D.Focus(false) end
  f:SetAlpha(on and D.FIGHT_ALPHA or 1)
  f:SetFrameStrata(on and D.FIGHT_STRATA or D.STRATA)      -- (a fight: under the health bars)
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
    if D.PinsPaint and not D.Store().off then D.PinsPaint() end
  elseif event == "PLAYER_REGEN_DISABLED" then D.Fight(true)
  elseif event == "PLAYER_REGEN_ENABLED" then D.Fight(false) D.Look() D.Dirty()
  elseif event == "PLAYER_LOGOUT" then if D.store then D.Save() end
  elseif D.frame and D.frame:IsShown() then D.Look() D.Dirty() end
end
ev:SetScript("OnEvent", function(_, event) T.Deck.OnEvent(event) end)
if IsLoggedIn and ask(IsLoggedIn) then T.DECK_LOGIN = true end

T.DECK_READY = MINOR
