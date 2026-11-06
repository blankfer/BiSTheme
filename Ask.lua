--[[
  BiSTheme / Ask.lua  --  BiS> in's buttons: ask for Innervate, Power Infusion, Mana Tide - and answer.

  Arn, 22 Oct 2026 (the plan: _bisdev/docs/bisin.md): "a mage can ask for an innervate ... the druid sees all the people
  that opt in and who ever he clicks the druid cast innervate on them ... all this is api so ideally we dont have to make
  them install bishealing". The messages are LibBiSComm's (minor 17, MOD IN); this file only draws, and every BiS addon
  carries it, so /bisin works with any of them.

    THE ASKER   one button per spell somebody in the group can answer: "Innervate - 2 ready", or, with every giver on
                cooldown, "Innervate - all on cooldown 1:40". Click: ask; click again: take it back. "Arn is coming"
                once a giver claims it. It casts nothing, so it is a plain button and updates any time.
    THE GIVER   a FACE per mana user who opted in, for a spell cast on someone (Innervate, Power Infusion), never
                yourself - a secure spell button pre-aimed at that person. It lights up when they ask; one click casts
                on them (and claims it, so the other givers' light goes out). A class filter keeps a druid's row to
                the classes he wants ("only the mages"). A druid in cat or bear form has no mana: his face dims.
                Mana Tide is cast on nobody: ONE button that lights with "2 asked", and only his own party's asks.

  THE CLIENT'S RULE: a secure button cannot be re-aimed, moved, shown or hidden in a fight. So everything that changes
  the LAYOUT waits for the fight's end (A.Layout); in a fight only light and dim change (alpha is never guarded). A
  roster change mid-fight can leave a face aimed at a slot somebody else now holds: that face greys out and stops
  lighting until the fight ends.

  SELF-GUARDED like Console.lua and Minimap.lua: newest ASK_MINOR wins. The canonical file lives here and is copied out
  by _bisdev/sync.ps1, never edited in place.

  Storage: the BiSTheme files have no saved variables; each BiS addon hands one table (A.Store) - the settings are the
  newest-saved of them, and every change is written to all, so any one addon remembers.
]]

BiSTheme = BiSTheme or {}
local T = BiSTheme
if (T.ASK_MINOR or 0) >= 1 then return end
T.ASK_MINOR = 1

local A = T.Ask or {}
T.Ask = A

A.WORD = { innervate = "Innervate", pi = "Power Infusion", tide = "Mana Tide" }
-- the class filter's choices (Arn: "only show these classes as targets Mages warlocks druids hunters, healers never
-- warriors or rogues")
A.FILTER = {
  { key = "mage", label = "Mages", classes = { "MAGE" } },
  { key = "warlock", label = "Warlocks", classes = { "WARLOCK" } },
  { key = "druid", label = "Druids", classes = { "DRUID" } },
  { key = "hunter", label = "Hunters", classes = { "HUNTER" } },
  { key = "healer", label = "Healers", classes = { "PRIEST", "SHAMAN", "PALADIN" } },
}
A.FACE, A.GAP, A.BTN_W, A.BTN_H = 34, 4, 190, 22
A.LIT, A.DIM, A.STALE = 1, 0.35, 0.15

local function Secret(v) return issecretvalue ~= nil and issecretvalue(v) == true end
local function plain(v) if v == nil or Secret(v) then return nil end return v end

function A.Lib()
  local L = _G.LibBiSComm
  if L and L.BisInSet then return L end
  return nil
end

local function locked()
  return InCombatLockdown and InCombatLockdown() == true
end

--------------------------------------------------------------------
-- settings: the newest-saved of the tables the addons hand over
--------------------------------------------------------------------
A.stores = A.stores or {}
function A.Store(t)
  if type(t) ~= "table" then return end
  for _, s in ipairs(A.stores) do if s == t then return end end
  A.stores[#A.stores + 1] = t
end

function A.Settings()
  local best
  for _, s in ipairs(A.stores) do
    if not best or (tonumber(s.at) or 0) > (tonumber(best.at) or 0) then best = s end
  end
  return best or A.session or {}
end

function A.Save(k, v)
  local now = (GetServerTime and plain(GetServerTime())) or 0
  if #A.stores == 0 then A.session = A.session or {} A.session[k] = v return end
  local cur = A.Settings()
  for _, s in ipairs(A.stores) do
    for kk, vv in pairs(cur) do if s ~= cur then s[kk] = vv end end
    s[k] = v
    s.at = now
  end
end

--- Does the class filter want this class? (no filter set: every class with mana)
function A.Wanted(class)
  local f = A.Settings().filter
  if type(f) ~= "table" then return true end
  for _, g in ipairs(A.FILTER) do
    for _, c in ipairs(g.classes) do if c == class then return f[g.key] ~= false end end
  end
  return true
end

--------------------------------------------------------------------
-- the model: what should be on screen now (pure - read off the lib)
--------------------------------------------------------------------
function A.Model()
  local L = A.Lib()
  if not (L and L.bisin and L.bisin.on) then return nil end
  local me = L:BisInMe()
  local m = { asks = {}, faces = {}, tides = {} }
  if me.ask then
    for _, k in ipairs(L.BISIN_ORDER) do
      local ready, soonest, givers = L:BisInReady(k)
      if #givers > 0 then
        local mine = L:BisInMine(k)
        m.asks[#m.asks + 1] = { spell = k, ready = ready, soonest = soonest, givers = givers, mine = mine }
      end
    end
  end
  for _, k in ipairs(L.BISIN_ORDER) do
    if me.give[k] then
      local sp = L.BISIN[k]
      local open = L:BisInRequests(k)
      if sp.target then
        local byOwner = {}
        for _, r in ipairs(open) do byOwner[r.owner] = r end
        for _, a in ipairs(L:BisInAskers()) do
          if A.Wanted(a.class) then
            m.faces[#m.faces + 1] = { spell = k, name = a.name, class = a.class, unit = L.UnitOf(a.name),
                                      req = byOwner[a.name] }
          end
        end
      else
        m.tides[#m.tides + 1] = { spell = k, reqs = open }
      end
    end
  end
  return m
end

--- An ask button's words.
function A.AskWord(a)
  local word = A.WORD[a.spell] or a.spell
  if a.mine then
    if a.mine.claim then return ("%s - %s is coming"):format(word, tostring(a.mine.claim.by):match("^(%S+)") or "?") end
    return word .. " - asked"
  end
  if a.ready > 0 then return ("%s - %d ready"):format(word, a.ready) end
  if a.soonest then
    local now = (GetServerTime and plain(GetServerTime())) or 0
    local left = math.max(0, a.soonest - now)
    return ("%s - all on cooldown %d:%02d"):format(word, math.floor(left / 60), left % 60)
  end
  return word
end

--- Is this group member on mana now? (a druid in cat or bear form is not)
function A.OnMana(unit)
  if not (unit and UnitPowerType) then return true end
  local ok, p = pcall(UnitPowerType, unit)
  p = ok and plain(p) or nil
  return p == nil or p == 0
end

--------------------------------------------------------------------
-- drawing
--------------------------------------------------------------------
local function tex(parent, layer, r, g, b, a)
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture("Interface\\Buttons\\WHITE8x8")
  t:SetVertexColor(r, g, b, a or 1)
  return t
end
local function words(parent, size)
  local s = parent:CreateFontString(nil, "OVERLAY")
  s:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 11, "OUTLINE")
  return s
end

function A.Bar()
  if A.bar then return A.bar end
  local f = CreateFrame("Frame", "BiSAskBar", UIParent)
  A.bar = f
  f:SetSize(A.BTN_W, 20)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  -- its secure faces make it one of the client's own while you fight: it moves only out of combat
  f:SetScript("OnDragStart", function(self) if not locked() then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    A.Save("pos", { p, rp, x, y })
  end)
  f.title = words(f, 10)
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 2, 0)
  f.title:SetText("BiS> in")
  f.asks, f.faces, f.tides = {}, {}, {}
  f:Hide()
  return f
end

function A.Place(f)
  local pos = A.Settings().pos
  if type(pos) ~= "table" or type(pos[1]) ~= "string" then pos = { "BOTTOM", "BOTTOM", 0, 220 } end
  f:ClearAllPoints()
  f:SetPoint(pos[1], UIParent, pos[2] or pos[1], tonumber(pos[3]) or 0, tonumber(pos[4]) or 0)
end

local function askButton(f, i)
  local b = f.asks[i]
  if b then return b end
  b = CreateFrame("Button", nil, f)
  b:SetSize(A.BTN_W, A.BTN_H)
  b.back = tex(b, "BACKGROUND", 0.08, 0.06, 0.12, 0.85)
  b.back:SetAllPoints(b)
  b.lit = tex(b, "BORDER", 0.72, 0.5, 1, 0.35)
  b.lit:SetAllPoints(b)
  b.word = words(b, 11)
  b.word:SetPoint("LEFT", b, "LEFT", 6, 0)
  b:SetScript("OnClick", function(self)
    local L, a = A.Lib(), self.ask
    if not (L and a) then return end
    if a.mine then L:BisInCancel(a.mine.id) else L:BisInAsk(a.spell) end
    A.Refresh()
  end)
  f.asks[i] = b
  return b
end

-- a giver's face: a secure spell button, aimed out of combat; PreClick claims the ask it answers
local function faceButton(f, i)
  local b = f.faces[i]
  if b then return b end
  b = CreateFrame("Button", "BiSAskFace" .. i, f, "SecureActionButtonTemplate")
  b:SetSize(A.FACE, A.FACE)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b.back = tex(b, "BACKGROUND", 0, 0, 0, 0.8)
  b.back:SetAllPoints(b)
  b.portrait = b:CreateTexture(nil, "ARTWORK")
  b.portrait:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  b.portrait:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  b.glow = tex(b, "OVERLAY", 1, 0.82, 0.25, 0.55)
  b.glow:SetAllPoints(b)
  b.name = words(b, 9)
  b.name:SetPoint("TOP", b, "BOTTOM", 0, -1)
  b:SetScript("PreClick", function(self)
    local L, face = A.Lib(), self.face
    if L and face and face.req then L:BisInClaim(face.req.id) end
  end)
  f.faces[i] = b
  return b
end

-- Mana Tide: one secure button, cast on nobody; PreClick claims every ask it answers
local function tideButton(f, i)
  local b = f.tides[i]
  if b then return b end
  b = CreateFrame("Button", "BiSAskTide" .. i, f, "SecureActionButtonTemplate")
  b:SetSize(A.BTN_W, A.BTN_H)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b.back = tex(b, "BACKGROUND", 0.05, 0.1, 0.12, 0.85)
  b.back:SetAllPoints(b)
  b.glow = tex(b, "BORDER", 0.3, 0.75, 1, 0.5)
  b.glow:SetAllPoints(b)
  b.word = words(b, 11)
  b.word:SetPoint("LEFT", b, "LEFT", 6, 0)
  b:SetScript("PreClick", function(self)
    local L = A.Lib()
    for _, r in ipairs(self.reqs or {}) do if L then L:BisInClaim(r.id) end end
  end)
  f.tides[i] = b
  return b
end

--- THE LAYOUT: which buttons, which faces, aimed where. Out of combat only - in a fight it waits (A.dirty).
function A.Layout()
  local f = A.Bar()
  if locked() then A.dirty = true return false end
  A.dirty = nil
  local m = A.Model()
  if not m or (#m.asks == 0 and #m.faces == 0 and #m.tides == 0) then
    f:Hide()
    for _, b in ipairs(f.faces) do b:Hide() end
    for _, b in ipairs(f.tides) do b:Hide() end
    A.model = m
    return true
  end
  A.Place(f)
  local y = -14
  for i, a in ipairs(m.asks) do
    local b = askButton(f, i)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
    b:Show()
    y = y - A.BTN_H - A.GAP
  end
  for i = #m.asks + 1, #f.asks do f.asks[i]:Hide() end
  for i, t in ipairs(m.tides) do
    local b = tideButton(f, i)
    local L = A.Lib()
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", (C_Spell and C_Spell.GetSpellName and plain(C_Spell.GetSpellName(L.BISIN[t.spell].id))) or A.WORD[t.spell])
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
    b:Show()
    y = y - A.BTN_H - A.GAP
  end
  for i = #m.tides + 1, #f.tides do f.tides[i]:Hide() end
  local x = 0
  for i, face in ipairs(m.faces) do
    local b = faceButton(f, i)
    local L = A.Lib()
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", (C_Spell and C_Spell.GetSpellName and plain(C_Spell.GetSpellName(L.BISIN[face.spell].id))) or A.WORD[face.spell])
    b:SetAttribute("unit", face.unit)
    b.aimedAt = face.name
    if face.unit and SetPortraitTexture then pcall(SetPortraitTexture, b.portrait, face.unit) end
    b.name:SetText((tostring(face.name):match("^(%S+)")))
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    b:Show()
    x = x + A.FACE + A.GAP
  end
  for i = #m.faces + 1, #f.faces do f.faces[i]:Hide() end
  local tall = -y + ((#m.faces > 0) and (A.FACE + 14) or 0)
  f:SetSize(math.max(A.BTN_W, x), tall)
  f:Show()
  A.model = m
  A.Paint()
  return true
end

--- LIGHT AND DIM (any time, a fight too): the words, the lit faces, the dimmed ones.
function A.Paint()
  local f, m = A.bar, A.model
  if not (f and m) then return end
  local fresh = A.Model() or m
  for i, a in ipairs(m.asks) do
    local b = f.asks[i]
    local now = fresh.asks[i] and fresh.asks[i].spell == a.spell and fresh.asks[i] or a
    b.ask = now
    b.word:SetText(A.AskWord(now))
    b.lit:SetAlpha(now.mine and 1 or 0)
  end
  for i, t in ipairs(m.tides) do
    local b = f.tides[i]
    local now = fresh.tides[i] or t
    b.reqs = now.reqs
    b.word:SetText(#now.reqs > 0 and ("Mana Tide - %d asked"):format(#now.reqs) or "Mana Tide")
    b.glow:SetAlpha(#now.reqs > 0 and 1 or 0)
  end
  local reqBy = {}
  for _, face in ipairs(fresh.faces) do reqBy[face.spell .. "|" .. face.name] = face.req end
  for i, face in ipairs(m.faces) do
    local b = f.faces[i]
    local L = A.Lib()
    -- STILL AIMED AT THEM? a roster change mid-fight can hand the slot to somebody else: grey, never lit
    local stillThem = true
    if face.unit and L then
      local who = L.FullName and L.FullName(face.unit)
      stillThem = who == nil or who == face.name
    end
    local req = reqBy[face.spell .. "|" .. face.name]
    b.face = stillThem and { req = req, name = face.name } or nil
    if not stillThem then
      b:SetAlpha(A.STALE) b.glow:SetAlpha(0)
    else
      b:SetAlpha(A.OnMana(face.unit) and 1 or A.DIM)
      b.glow:SetAlpha(req and A.LIT or 0)
    end
  end
end

--- Something changed: the layout if we may, else just the light.
function A.Refresh()
  if locked() then A.dirty = true A.Paint() return end
  local m = A.Model()
  local same = A.model and m and #m.asks == #A.model.asks and #m.faces == #A.model.faces and #m.tides == #A.model.tides
  if same then
    for i, a in ipairs(m.asks) do if A.model.asks[i].spell ~= a.spell then same = false end end
    for i, face in ipairs(m.faces) do
      local o = A.model.faces[i]
      if o.name ~= face.name or o.spell ~= face.spell or o.unit ~= face.unit then same = false end
    end
  end
  if same then A.model.asks = m.asks A.Paint() else A.Layout() end
end

--------------------------------------------------------------------
-- /bisin and the events
--------------------------------------------------------------------
--- /bisin on|off; the filter: /bisin show mages healers (or "all").
function A.Command(msg)
  local L = A.Lib()
  msg = tostring(msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local say = function(s) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffb980ffBiS> in|r " .. s) end end
  if not L then say("needs a BiS addon's shared channel - none loaded") return end
  local verb, rest = msg:match("^(%S*)%s*(.-)$")
  if verb == "on" or verb == "off" then
    L:BisInSet(verb == "on")
    A.Save("on", verb == "on")
    A.Refresh()
    local me = L:BisInMe()
    if me.on then
      local g = {}
      for _, k in ipairs(L.BISIN_ORDER) do if me.give[k] then g[#g + 1] = A.WORD[k] end end
      say(("on - %s%s"):format(#g > 0 and ("you give " .. table.concat(g, ", ")) or "you give nothing",
        me.ask and "; you can ask for what your group gives" or ""))
    else
      say("off")
    end
    return
  end
  if verb == "show" then
    local f = {}
    if rest == "" or rest == "all" then
      f = nil
    else
      for _, g in ipairs(A.FILTER) do f[g.key] = false end
      for word in rest:gmatch("[%a]+") do
        for _, g in ipairs(A.FILTER) do
          if word == g.key or word == g.key .. "s" or word == g.label:lower() then f[g.key] = true end
        end
      end
    end
    A.Save("filter", f)
    A.Refresh()
    local shown = {}
    for _, g in ipairs(A.FILTER) do if not f or f[g.key] then shown[#shown + 1] = g.label end end
    say("faces for: " .. table.concat(shown, ", "))
    return
  end
  local me = L:BisInMe()
  say(me.on and "on" or "off")
  say("/bisin on | off  -  /bisin show mages healers (or all)")
end

if SlashCmdList then
  _G.SLASH_BISIN1 = "/bisin"
  SlashCmdList.BISIN = function(msg) A.Command(msg) end
end

do
  local ev = A.events or CreateFrame("Frame")
  A.events = ev
  for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "UNIT_DISPLAYPOWER" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event)
    local L = A.Lib()
    if not L then return end
    if event == "PLAYER_LOGIN" then
      if A.Settings().on then L:BisInSet(true) end
      if not A.hooked and L.RegisterCallback then
        A.hooked = true
        L:RegisterCallback("BISIN", function() A.Refresh() end)
      end
      A.Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
      if A.dirty then A.Layout() end
    else
      A.Refresh()
    end
  end)
end

return A
