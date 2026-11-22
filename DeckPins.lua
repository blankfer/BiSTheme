--[[
  BiSTheme / DeckPins.lua  --  A LIVE CARD PULLED OUT OF THE DECK (22 Nov 2026).

  Arn, 22 Nov: "BiS rides if someone wants to drag that out of the phone and pin [it to] their screen even when they close tools,
  it'll drag it out and pin in their screen where ever they place it when they close it it goes back to the tools". And: "they
  open farm app they click around in it it'll show up as a live card if it makes sense if they just looks at it and exit they
  just took a peek, but if they like the live card cause they can click stuff on it and drag it out and pin it to their screen,
  they don't end up likening it they close it and goes back to the phone, if they want to see more it opens the app on the phone".

  WHO IS LIVE is Deck.lua's (D.Used / D.IsLive). Here: the pulled-out card itself.
  ITS OWN PLAIN FRAME on UIParent, never a child of the deck (the deck may close, flip, dim) and nothing secure on it. It shows
  what its card says (D.Call, the same errors road), its plain buttons, OPEN (the app on the deck) and x (back into the deck).
  Where it stands is kept per character. One beat a second for all of them, only while one is out. A card with nothing to say
  hides and comes back to its place. In a fight: clicks go through it, or it is gone (the switch "Pinned cards in a fight").
]]
BiSTheme = BiSTheme or {}
local T = BiSTheme
local D = T.Deck
if not D or not T.DECK_READY then return end
local MINOR = 1
if (T.DECKPINS_MINOR or 0) >= MINOR then return end
T.DECKPINS_MINOR = MINOR

local K = D.Kit
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a = pcall(fn, ...)
  if ok and not (issecretvalue and issecretvalue(a)) then return a end
end
D.PIN_W, D.PIN_H, D.PIN_BTN, D.PIN_LINE = 230, 56, 24, 16  -- the card, its row of buttons, one of its own lines
D.PIN_BEAT, D.PIN_FIGHT = 1, 0.6
D.pinFrames = D.pinFrames or {}

function D.Pins()
  local m = D.Mine()
  m.pins = type(m.pins) == "table" and m.pins or {}
  return m.pins
end
function D.IsPinned(id) return D.Pins()[id] ~= nil end
local function canPin(id)
  local d = D.defs[id]
  return d and d.card and not d.parked and d or nil
end

--- One pulled-out card's frame: the piece kit's own pieces, so it wears the deck's look and theme.
local function build(id)
  local f = D.pinFrames[id]
  if f then return f end
  f = CreateFrame("Frame", nil, UIParent)
  f.id, f.pieces = id, {}
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not D.fight then D.PinTake(self.id) end end)
  f:SetScript("OnDragStop", function() D.PinDrop() end)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints(f)
  for i, key in ipairs({ "body", "open", "x", "b1", "b2", "b3", "l1", "l2", "l3" }) do
    local w = K.piece(f)
    f[key], f.pieces[i] = w, w
    w:SetFrameLevel((f:GetFrameLevel() or 1) + (key == "body" and 1 or 3))
    -- held anywhere on it, the card goes with the mouse
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", function() if not D.fight then D.PinTake(id) end end)
    w:SetScript("OnDragStop", function() D.PinDrop() end)
  end
  f:Hide()
  f:SetScript("OnHide", function(self) if D.OverlayClear then D.OverlayClear(self) end if D.pinHeld == self.id then D.PinDrop() end end)   -- (after the first Hide: it is no drag's end)
  D.pinFrames[id] = f
  return f
end
local function put(f, w, x, y, wide, high)
  w:ClearAllPoints()
  w:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
  w:SetSize(wide, high)
end
local function place(f)
  local p = D.Pins()[f.id]
  f:SetScale(D.Store().scale or D.SCALE)
  f:ClearAllPoints()
  if type(p) == "table" and type(p[1]) == "string" then f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else f:SetPoint("CENTER", UIParent, "CENTER", 0, 120) end
end

--- What a pulled-out card shows: its lines, or nil (nothing to say now: hidden, its place kept).
function D.PinLines(def)
  if D.When(def) == "use" and not D.IsLive(def) then return nil end        -- (over: IsLive takes the pin back too)
  local p = D.Call(def, "prio", def.card.prio or 1, true)
  if type(p) ~= "number" then return nil end
  local l = D.Call(def, "lines", def.card.lines, true)
  return type(l) == "table" and l or nil
end
function D.PinPaint(id)
  local def = canPin(id)
  local f = build(id)
  local l = def and not (D.fight and D.Store().sw.pinfight == false) and not D.Store().off and D.PinLines(def) or nil
  if not l then
    if D.pinHeld ~= id then f:Hide() end
    return false
  end
  local say, rgb = K.say, K.rgb
  f.bg:SetColorTexture(rgb("card"))
  local bs = {}
  for _, b in ipairs(D.Call(def, "buttons", def.card.buttons) or {}) do if type(b) == "table" and (type(b.fn) == "function" or D.IsSecure(b) and D.OverlayOn and D.OverlayOn()) and #bs < 3 then bs[#bs + 1] = b end end
  -- (its own lines too - who timed the ride, what comes next: Arn, 22 Nov "these card still want the info of who its syncing from")
  local list = type(l.list) == "table" and l.list or {}
  local nl = math.min(3, #list)
  local btnY = D.PIN_H + nl * D.PIN_LINE + (nl > 0 and 4 or 0)
  local W, H = D.PIN_W, btnY + (#bs > 0 and D.PIN_BTN + 4 or 0)
  f:SetSize(W, H)
  for _, w in ipairs(f.pieces) do w.act, w.tip, w.sec, w.secDef = nil, nil, nil, nil w.bg:SetColorTexture(0, 0, 0, 0) end
  local w = f.body
  put(f, w, 0, 0, W, H)
  K.fit(w.c, (l.hot and "! " or "") .. tostring(l[1] or ""), { 11, 10, 9 }, "accent", nil, W - 90)
  say(w.b, l[4] or "", 15, l[5] or "ink2", "RIGHT")
  K.fit(w.a, l[3] or "", { 16, 14, 12, 11 }, "ink", nil, W - 26 - (K.wide(w.b) or 0))
  w.a:ClearAllPoints() w.b:ClearAllPoints() w.c:ClearAllPoints()
  w.c:SetPoint("TOPLEFT", w, "TOPLEFT", 9, -6) w.c:SetPoint("TOPRIGHT", w, "TOPRIGHT", -78, -6)
  w.b:SetPoint("TOPRIGHT", w, "TOPRIGHT", -9, -32)
  w.a:SetPoint("TOPLEFT", w, "TOPLEFT", 9, -31) w.a:SetPoint("TOPRIGHT", w.b, "TOPLEFT", -6, 1)
  w.act = (def.page or def.open) and function() D.Open(id) end or nil
  local r, g, b = rgb(l.hot and "gold" or "line")
  w.bar:SetColorTexture(r, g, b, 1) w.bar:Show()
  for i = 1, 3 do
    local p, x = f["l" .. i], i <= nl and list[i]
    if x then
      x = type(x) == "table" and x or { x }
      put(f, p, 9, D.PIN_H - 2 + (i - 1) * D.PIN_LINE, W - 18, D.PIN_LINE)
      p.a:ClearAllPoints() p.b:ClearAllPoints()
      p.b:SetPoint("RIGHT", p, "RIGHT", 0, 0)
      p.a:SetPoint("LEFT", p, "LEFT", 0, 0) p.a:SetPoint("RIGHT", p.b, "LEFT", -6, 0)
      say(p.b, x[2] or "", 12, "ink2", "RIGHT") say(p.c, "", 10)
      K.fit(p.a, x[1] or "", { 12, 11, 10, 9 }, "ink2", nil, W - 26 - (K.wide(p.b) or 0))
      p.bar:Hide()
      p:EnableMouse(false)
      p:Show()
    else p:Hide() end
  end
  local function key(p, words, x, y, wide, high, fn, tip)
    put(f, p, x, y, wide, high)
    p.a:ClearAllPoints() p.a:SetPoint("LEFT", p, "LEFT", 2, 0) p.a:SetPoint("RIGHT", p, "RIGHT", -2, 0)
    local r1, g1, b1 = rgb("sunken")
    p.bg:SetColorTexture(r1, g1, b1, 1)
    say(p.a, words, 11, "ink2", "CENTER") say(p.b, "", 11) say(p.c, "", 11)
    p.bar:Hide()
    p.act, p.tip = fn, tip
    p:EnableMouse(not D.fight)
    p:Show()
  end
  if def.page or def.open then key(f.open, "OPEN", W - 74, 3, 44, 24, function() D.Open(id) end, "Open it on the deck") else f.open:Hide() end
  key(f.x, "x", W - 27, 3, 24, 24, function() D.PinBack(id) end, "Back into the deck")
  local each = #bs > 0 and (W - 18 - (#bs - 1) * 4) / #bs or 0
  for i = 1, 3 do
    local p = f["b" .. i]
    if bs[i] then key(p, bs[i].word or "", 9 + (i - 1) * (each + 4), btnY, each, D.PIN_BTN, D.Press(def, bs[i]), bs[i].tip) if D.IsSecure(bs[i]) then p.sec, p.secDef = bs[i], def end else p:Hide() end
  end
  w:EnableMouse(not D.fight)
  f:EnableMouse(not D.fight)
  f:SetAlpha(D.fight and D.PIN_FIGHT or 1)
  if not f:IsShown() then
    if D.pinHeld ~= id then place(f) end
    f:Show()
  end
  if D.OverlayPaint then D.OverlayPaint(f, f) end
  return true
end
function D.PinsPaint()
  local any = false
  for id in pairs(D.Pins()) do if D.PinPaint(id) then any = true end end
  for id, f in pairs(D.pinFrames) do if not D.Pins()[id] and D.pinHeld ~= id and f:IsShown() then f:Hide() end end
  D.PinsWake()
  return any
end
--- The beat: only while a card is out (hidden ones cost a look a second, nothing more); a held one is watched for a lost button.
function D.PinsWake()
  local root = D.pinRoot
  local want = (next(D.Pins()) ~= nil and not D.Store().off) or D.pinHeld ~= nil
  if not root then
    if not want then return end
    root = CreateFrame("Frame")
    D.pinRoot = root
  end
  if not want then root:SetScript("OnUpdate", nil) root.on = nil return end
  if root.on then return end
  root.on = true
  local acc = 0
  root:SetScript("OnUpdate", function(_, el)
    acc = acc + (el or 0)
    if D.pinHeld and IsMouseButtonDown and ask(IsMouseButtonDown, "LeftButton") == false then D.PinDrop() end
    if acc < D.PIN_BEAT then return end
    acc = 0
    D.PinsPaint()
  end)
end

--- Pull a card out: `held` = under the mouse, let go where it should stand (the deck is not painted meanwhile: the client
--- tells the piece that is dragged when the drag ends, and a hidden piece is told nothing).
function D.PinOut(id, held)
  local def = canPin(id)
  if not def or D.fight then return false end
  if D.IsPinned(id) then return true end
  D.Pins()[id] = {}
  if held then
    D.pinHeld = id
    local f = build(id)
    local s = f.GetEffectiveScale and f:GetEffectiveScale() or 1
    f:SetScale(D.Store().scale or D.SCALE)
    s = f.GetEffectiveScale and f:GetEffectiveScale() or s
    local x, y = GetCursorPosition()
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (x or 0) / s, (y or 0) / s)
    D.PinPaint(id)
    f:Show()
    f:StartMoving()
    f.moving = true
    D.PinsWake()
    return true
  end
  D.Save()
  D.PinsPaint()
  D.Dirty(true)
  return true
end
function D.PinTake(id)
  local f = D.pinFrames[id]
  if not f or D.fight then return end
  D.pinHeld = id
  f:StartMoving()
  f.moving = true
  if D.OverlayClear then D.OverlayClear(f) end
  D.PinsWake()
end
--- Let go: over the deck = back into it; anywhere else = it stays there.
function D.PinDrop()
  local id = D.pinHeld
  if not id then return end
  D.pinHeld = nil
  local f = D.pinFrames[id]
  if f and f.moving then
    f.moving = nil
    pcall(f.StopMovingOrSizing, f)
  end
  local deck = D.frame
  if not D.fight and deck and deck:IsShown() and deck.IsMouseOver and ask(deck.IsMouseOver, deck) == true then return D.PinBack(id) end
  if f and D.Pins()[id] then
    local ok, p, _, rp, x, y = pcall(f.GetPoint, f, 1)
    if ok and type(p) == "string" and type(x) == "number" and not (issecretvalue and issecretvalue(x)) then D.Pins()[id] = { p, rp or p, x, y } end
  end
  D.Save()
  D.PinsPaint()
  D.Dirty(true)
end
--- Closed: back into the deck, where it is a live card again.
function D.PinBack(id)
  D.Pins()[id] = nil
  if D.pinHeld == id then D.pinHeld = nil end
  local f = D.pinFrames[id]
  if f then
    if f.moving then f.moving = nil pcall(f.StopMovingOrSizing, f) end
    f:Hide()
  end
  D.Save()
  D.PinsWake()
  D.Dirty(true)
end
--- The deck's own tool switched off: nothing of it stays on the screen (the places are kept).
function D.Off(off)
  D.Store().off = off and true or nil
  D.Save()
  D.PinsPaint()
end
