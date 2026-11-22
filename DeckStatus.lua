--[[
  BiSTheme / DeckStatus.lua  --  THE SIGNS AT THE TOP OF THE DECK, AND WHAT THEY MEAN (22 Nov 2026).

  Arn, 22 Nov, with his phone's status bar (clock, the sleeping bed, signal, WiFi, battery 91): "They should have a function in
  game maybe the signal strength does something WiFi guild communication battery something n else".

   - SIGNAL, four bars = your connection: the worse of home and world, in ms.
   - WIFI, three arcs = the BiS network: how many people with a BiS addon you have heard (group and guild, LibBiSComm). Nobody =
     one arc, off or no library = a stroke through it, a chat lockdown (raid fights) = paused.
   - BATTERY = AUTO: rested XP while you level (100 = the most the game stores), your worst piece of gear at the top level, and
     gear under 20 % always wins. Or always rested / gear / bags: your pick. Teal = charging (you rest, and it is rested XP).
   - THE BED by the clock = you are resting (inn or city).
  A click on any of them = the Status page with the words and numbers. Never by colour or shape alone: the page, the tooltip and
  Read aloud say it. Asked when the deck paints, at most every 10 s otherwise; gear is asked again only when the game says so.
]]
BiSTheme = BiSTheme or {}
local T = BiSTheme
local D = T.Deck
if not D or not T.DECK_READY then return end
local MINOR = 1
if (T.DECKSTATUS_MINOR or 0) >= MINOR then return end
T.DECKSTATUS_MINOR = MINOR

local K = D.Kit
local function plain(v) if v == nil or (issecretvalue and issecretvalue(v)) then return nil end return v end
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return plain(a), plain(b), plain(c), plain(d) end
end
local function num(v) return type(v) == "number" and v or nil end

D.BATTERIES = { "auto", "rested", "gear", "bags" }
D.LOW = 20                                                -- under this the battery is low, whatever it shows
local TOP = 60

--- Home and world, the worse of the two; nil = the game does not say.
function D.Ping()
  local _, _, home, world = ask(GetNetStats)
  home, world = num(home), num(world)
  if not (home or world) then return nil end
  return math.max(home or 0, world or 0)
end
function D.Bars(ms) return not ms and 0 or ms <= 80 and 4 or ms <= 150 and 3 or ms <= 300 and 2 or 1 end

--- The BiS network: { state = "none" | "off" | "paused" | "on", n = people heard, names = { name = words } }.
function D.Net()
  local lib = rawget(_G, "LibBiSComm")
  local out = { state = "none", n = 0, names = {} }
  if type(lib) ~= "table" or type(lib.Enabled) ~= "function" then return out end
  if ask(lib.Enabled, lib) ~= true then out.state = "off" return out end
  out.state = ask(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) == true and "paused" or "on"
  local function add(name, words)
    if type(plain(name)) ~= "string" then return end
    if not out.names[name] then out.n = out.n + 1 end
    out.names[name] = words or out.names[name] or ""
  end
  for name in pairs(type(lib.peers) == "table" and lib.peers or {}) do add(name, "in your group") end
  for name in pairs(type(lib.vers) == "table" and lib.vers or {}) do if not out.names[name] then add(name, "heard") end end
  return out
end
function D.Arcs(net) return (net.state == "none" or net.state == "off") and 0 or net.n == 0 and 1 or net.n < 4 and 2 or 3 end

--- Your worst piece of gear, 0-100 (nil = nothing that wears).
function D.Gear()
  if D.gearAsked then return D.gear end
  D.gearAsked = true
  local worst
  for slot = 1, 18 do
    local have, most = ask(GetInventoryItemDurability, slot)
    have, most = num(have), num(most)
    if have and most and most > 0 then
      local p = math.floor(have / most * 100 + 0.5)
      if not worst or p < worst then worst = p end
    end
  end
  D.gear = worst
  return worst
end
--- Rested XP, 0-100: 100 = a level and a half, the most the game stores.
function D.Rested()
  local most = num(ask(UnitXPMax, "player"))
  if not most or most <= 0 then return nil end
  return math.min(100, math.floor((num(ask(GetXPExhaustion)) or 0) / (most * 1.5) * 100 + 0.5))
end
function D.Bags()
  local free, all = 0, 0
  local C = C_Container
  if not (C and C.GetContainerNumSlots and C.GetContainerNumFreeSlots) then return nil end
  for bag = 0, 4 do
    all = all + (num(ask(C.GetContainerNumSlots, bag)) or 0)
    free = free + (num(ask(C.GetContainerNumFreeSlots, bag)) or 0)
  end
  if all == 0 then return nil end
  return math.floor(free / all * 100 + 0.5), free, all
end
function D.BatteryPick()
  local st = D.Store()
  for _, k in ipairs(D.BATTERIES) do if st.battery == k then return k end end
  return "auto"
end
--- What the battery shows now: { kind, pct (nil = nothing to show), low, charging }.
function D.Battery(resting)
  local pick = D.BatteryPick()
  local kind = pick
  if pick == "auto" then
    local level = num(ask(UnitLevel, "player")) or TOP
    local top = num(ask(GetMaxPlayerLevel)) or TOP
    kind = level < top and D.Rested() and "rested" or "gear"
    local g = D.Gear()
    if g and g < D.LOW then kind = "gear" end
  end
  local pct
  if kind == "rested" then pct = D.Rested() elseif kind == "bags" then pct = D.Bags() else pct = D.Gear() end
  return { kind = kind, pct = pct, low = (pct and pct < D.LOW and kind ~= "rested") and true or false, charging = kind == "rested" and resting and (pct or 0) < 100 or false }
end
--- All of it, asked once a paint.
function D.Status()
  local s = { ms = D.Ping(), net = D.Net(), resting = ask(IsResting) == true }
  s.bars, s.arcs = D.Bars(s.ms), D.Arcs(s.net)
  s.bat = D.Battery(s.resting)
  return s
end
local KIND = { rested = "Rested XP", gear = "Worst gear", bags = "Bag space" }
local NET = { none = "no BiS network here", off = "the BiS network is off", paused = "paused by the game for now", on = "" }
--- The signs in words (the tooltip, Read aloud).
function D.StatusWords(s)
  local out = { s.ms and ("Connection " .. s.ms .. " ms") or "Connection unknown" }
  out[#out + 1] = s.net.state == "on" and ("BiS network: " .. s.net.n .. " heard") or ("BiS network: " .. NET[s.net.state])
  out[#out + 1] = s.bat.pct and (KIND[s.bat.kind] .. " " .. s.bat.pct .. "%" .. (s.bat.low and ", low" or "") .. (s.bat.charging and ", filling" or "")) or (KIND[s.bat.kind] .. ": nothing to show")
  if s.resting then out[#out + 1] = "Resting" end
  return out
end

-- THE DRAWING: plain textures and lines on the piece, kept and moved, never made twice -----------------------------------

local function bar(w, i, x, y, wide, high, colour, a)
  w.bits = w.bits or {}
  local t = w.bits[i]
  if not t then t = w:CreateTexture(nil, "OVERLAY") w.bits[i] = t end
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", w, "TOPLEFT", x, -y)
  t:SetSize(wide, high)
  local r, g, b = K.rgb(colour)
  t:SetColorTexture(r, g, b, a or 1)
  t:Show()
end
local function line(w, i, x1, y1, x2, y2, thick, colour)
  w.lines = w.lines or {}
  local l = w.lines[i]
  if not l then l = w:CreateLine(nil, "OVERLAY") w.lines[i] = l end
  if not l then return end
  l:SetThickness(thick)
  l:SetStartPoint("TOPLEFT", w, x1, -y1)
  l:SetEndPoint("TOPLEFT", w, x2, -y2)
  local r, g, b = K.rgb(colour)
  l:SetTexture("Interface\\Buttons\\WHITE8X8")         -- (a Line takes its colour as a tint, not as a colour texture)
  l:SetVertexColor(r, g, b, 1)
  l:Show()
end
--- A piece is used again for something else: its signs go.
function D.NoSigns(w)
  for _, t in pairs(w.bits or {}) do t:Hide() end
  for _, t in pairs(w.lines or {}) do t:Hide() end
end
D.ARC_FROM, D.ARC_TO, D.ARC_STEPS = 48, 132, 4            -- degrees; straight pieces an arc
--- The bed, 13 x 9, from x, y.
function D.DrawBed(w, x, y)
  bar(w, 21, x, y, 1.5, 9, "ink")                          -- headboard
  bar(w, 22, x, y + 4.5, 13, 2.5, "ink")                   -- mattress
  bar(w, 23, x + 2.5, y + 2, 3.5, 2, "ink")                -- pillow
  bar(w, 24, x + 11.5, y + 4.5, 1.5, 4.5, "ink")           -- foot
end
--- Signal, WiFi, battery in a piece `h` high: 66 wide.
function D.DrawStatus(w, s, h)
  local y = math.floor(h / 2) + 5
  for i = 1, 4 do
    local high = 2 + i * 2
    bar(w, i, (i - 1) * 3, y - high, 2, high, i <= s.bars and "ink" or "line2")
  end
  local cx, n = 25, 0
  for a = 1, 3 do
    local r = 1 + a * 3
    local lit = a <= s.arcs and s.net.state == "on"
    for k = 1, D.ARC_STEPS do
      n = n + 1
      local t1 = math.rad(D.ARC_FROM + (D.ARC_TO - D.ARC_FROM) * (k - 1) / D.ARC_STEPS)
      local t2 = math.rad(D.ARC_FROM + (D.ARC_TO - D.ARC_FROM) * k / D.ARC_STEPS)
      line(w, n, cx + r * math.cos(t1), y - r * math.sin(t1), cx + r * math.cos(t2), y - r * math.sin(t2), 1.5, lit and "ink" or "line2")
    end
  end
  bar(w, 5, cx - 1, y - 2, 2, 2, s.net.state == "on" and "ink" or "line2")
  if s.net.state == "none" or s.net.state == "off" then line(w, n + 1, cx - 6, y - 10, cx + 6, y, 1.5, "warn") else if w.lines and w.lines[n + 1] then w.lines[n + 1]:Hide() end end
  -- the battery: an outline, what is left, its nub, the number on it
  local x, wide, high, by = 38, 25, 13, y - 11
  local tone = s.bat.low and "warn" or s.bat.charging and "good" or "ink2"
  bar(w, 6, x, by, wide, 1, tone) bar(w, 7, x, by + high - 1, wide, 1, tone)
  bar(w, 8, x, by, 1, high, tone) bar(w, 9, x + wide - 1, by, 1, high, tone)
  bar(w, 10, x + wide, by + 4, 2, 5, tone)
  local pct = s.bat.pct
  if pct and pct > 0 then bar(w, 11, x + 1, by + 1, math.max(1, (wide - 2) * pct / 100), high - 2, tone, 0.35) elseif w.bits and w.bits[11] then w.bits[11]:Hide() end
  K.say(w.a, pct and ((s.bat.low and "!" or "") .. pct) or "-", 10, "ink", "CENTER")
  w.a:ClearAllPoints()
  w.a:SetPoint("TOPLEFT", w, "TOPLEFT", x, -by)
  w.a:SetPoint("BOTTOMRIGHT", w, "TOPLEFT", x + wide, -(by + high))
end

-- THE STATUS PAGE ----------------------------------------------------------------------------------------------------------

function D.StatusRows()
  local s = D.Status()
  local out = {}
  local function row(mark, text, right, ink, more) local r = { mark = mark, text = text, right = right, ink = ink or "ink2" } for k, v in pairs(more or {}) do r[k] = v end out[#out + 1] = r end
  row("", "Connection", s.ms and (s.ms .. " ms") or "unknown", s.ms and (s.ms > 300 and "warn" or s.ms > 150 and "gold" or "good") or "dim", { tip = "The worse of home and world" })
  local fps = num(ask(GetFramerate))
  row("", "Frames a second", fps and tostring(math.floor(fps + 0.5)) or "-")
  row("", "Battery shows", D.BatteryPick():upper(), "accent", { tip = "Click: auto, rested, gear, bags", act = { word = "next", fn = function()
    local at = 1
    for i, k in ipairs(D.BATTERIES) do if k == D.BatteryPick() then at = i end end
    local want = D.BATTERIES[at % #D.BATTERIES + 1]
    D.Store().battery = want ~= "auto" and want or nil
    D.Save()
  end } })
  local rested, gear, bags, free = D.Rested(), D.Gear(), D.Bags(), nil
  bags, free = D.Bags()
  row("", "Rested XP", rested and (rested .. "%" .. (s.resting and ", filling" or "")) or "-", s.resting and "good" or "ink2")
  row("", "Worst piece of gear", gear and (gear .. "%") or "-", gear and gear < D.LOW and "warn" or "ink2")
  row("", "Free bag slots", free and (free .. " (" .. bags .. "%)") or "-", bags and bags < D.LOW and "warn" or "ink2")
  row("", "BiS network", s.net.state == "on" and (s.net.n .. " heard") or s.net.state, s.net.state == "on" and "good" or "dim", { tip = NET[s.net.state] ~= "" and NET[s.net.state] or "People with a BiS addon you have heard" })
  local names = {}
  for name, words in pairs(s.net.names) do names[#names + 1] = { name, words } end
  table.sort(names, function(a, b) return a[1] < b[1] end)
  for _, x in ipairs(names) do row("-", x[1], x[2], "dim") end
  return out
end
D.Register{ owner = "BiSDeck", key = "status", name = "Status", hidden = true, order = 97,
  page = { title = function() return "Status" end, kicker = function() local s = D.Status() return s.resting and "resting" or "" end,
    boxes = function()
      local s = D.Status()
      return { { "PING", s.ms or "-", s.bars >= 3 and "good" or "gold" }, { "BIS", s.net.state == "on" and s.net.n or "-", "accent" }, { (s.bat.kind):upper(), s.bat.pct and (s.bat.pct .. "%") or "-", s.bat.low and "warn" or "ink" } }
    end,
    rows = D.StatusRows } }

-- what changes a sign, all rare; only a shown deck hears of it
local ev = D.statusEvents or CreateFrame("Frame")
D.statusEvents = ev
for _, e in ipairs({ "UPDATE_INVENTORY_DURABILITY", "UPDATE_EXHAUSTION", "PLAYER_EQUIPMENT_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
  if event ~= "UPDATE_EXHAUSTION" then D.gearAsked = nil end
  if D.frame and D.frame:IsShown() then D.Dirty() end
end)
