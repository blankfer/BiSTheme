--[[
  BiSTheme / DeckWindows.lua  --  AN APP PULLED OUT OF THE PHONE (22 Nov 2026).

  Arn, 22 Nov, the first look: "these apps i want them to open in the phone like apps"; "its only when i drag a window out that it
  becomes an app in the screen not in the phone, or if i drag a live tile it stays like a tile".

  An icon opens its app IN the phone, always. Dragged out - by its icon on home or by the OUT key of its page - the app stands on the
  screen as a window of its own: its own size, place, tab and scroll, kept per character. Its x puts it back into the phone; so does
  letting go of it over the phone. (A live card dragged out stays a card: DeckPins.lua.)

  THE SAME PAINT: a window is a surface (Deck.lua, D.On), so an app is written once. A window's keys, rows, search and wheel take
  their turn on it; an app that opens another app opens it on the phone; one that goes "home" (TURN OFF) closes its window.
  Plain frames on UIParent, nothing secure. One beat for all of them, only while one is out: a window is painted when something
  changed (D.dirtyN), when its words tick by the second, and every ten seconds. In a fight: faint, clicks go through, under the
  health bars, or gone (the switch "Pinned cards in a fight").
]]
BiSTheme = BiSTheme or {}
local T = BiSTheme
local D = T.Deck
if not D or not T.DECK_READY or not D.On then return end
local MINOR = 1
if (T.DECKWINS_MINOR or 0) >= MINOR then return end
T.DECKWINS_MINOR = MINOR

local K = D.Kit
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok and not (issecretvalue and (issecretvalue(a) or issecretvalue(b))) then return a, b end
end
D.WIN_W, D.WIN_H = 300, 420
D.winSurfs = D.winSurfs or {}

--- Which apps stand out on the screen: id -> { w, h, pos } (per character, like the pulled-out cards).
function D.Wins()
  local m = D.Mine()
  m.wins = type(m.wins) == "table" and m.wins or {}
  return m.wins
end
function D.IsOut(id) return D.Wins()[id] ~= nil end
--- May this app stand on its own? (a page of its own, and on)
function D.WinCan(id)
  local d = D.defs[id]
  return d and d.page and not d.open and not d.hidden and not d.parked and D.State(d) == "on" and d.owner ~= "BiSDeck" and d or nil
end

local function place(s)
  local f, p = s.frame, D.Wins()[s.id]
  f:SetScale(D.Store().scale or D.SCALE)
  f:ClearAllPoints()
  local pos = type(p) == "table" and p.pos
  if type(pos) == "table" and type(pos[1]) == "string" then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else f:SetPoint("CENTER", UIParent, "CENTER", -260, 40) end
end
local function keep(s)
  local p = D.Wins()[s.id]
  if type(p) ~= "table" then return end
  p.w, p.h = s.W, s.H
  local ok, a, _, rp, x, y = pcall(s.frame.GetPoint, s.frame, 1)
  if ok and type(a) == "string" and type(x) == "number" and not (issecretvalue and issecretvalue(x)) then p.pos = { a, rp or a, x, y } end
  D.Save()
end
--- A window's size, never over the screen, never under the least.
local function size(s, w, h)
  w, h = D.On(s, function()
    local L = T.DECK_L
    if w > h and (w < L.MIN_LW or h < L.MIN_LH) then h = w end
    return D.Fit(w, h)
  end)
  s.W, s.H, s.shape = w, h, T.DeckShape(w, h)
  s.frame:SetSize(w, h)
end

local function build(id)
  local s = D.winSurfs[id]
  if s then return s end
  local f = CreateFrame("Frame", nil, UIParent)
  s = { id = id, def = D.defs[id], page = id, frame = f, skip = 0 }
  s.tab = s.def.tab
  f.pieces, f.surf = {}, s
  f:SetFrameStrata(D.STRATA)
  f:SetFrameLevel(40)                                      -- (in front of the phone)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() if not D.fight then D.WinTake(id) end end)
  f:SetScript("OnDragStop", function() D.WinDrop() end)
  if f.EnableMouseWheel then f:EnableMouseWheel(true) end
  f:SetScript("OnMouseWheel", function(_, delta) if not D.fight then D.On(s, D.Scroll, -(delta or 0)) end end)
  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints(f)
  f.bg:SetColorTexture(K.rgb("ground"))
  f.bg:SetAlpha(0.97)
  -- the corner: its own frame, like the phone's
  local c = CreateFrame("Button", nil, f)
  f.corner = c
  c:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  c:SetSize(30, 30)
  c:SetScript("OnMouseDown", function(_, b) if not D.fight and (b == nil or b == "LeftButton") then D.WinGrip(id) end end)
  c:SetScript("OnMouseUp", function() D.WinGripEnd() end)
  c:SetScript("OnDoubleClick", function()
    if D.fight then return end
    D.WinGripEnd()
    size(s, D.WIN_W, D.WIN_H)
    keep(s)
    D.WinPaint(id, true)
  end)
  f:Hide()
  f:SetScript("OnHide", function() if D.OverlayClear then D.OverlayClear(s) end if D.winHeld == id then D.WinDrop() end if D.winGrip and D.winGrip.id == id then D.WinGripEnd() end end)
  D.winSurfs[id] = s
  return s
end

--- Painted when it must be (`now` = in any case). Answers whether it stands on the screen.
function D.WinPaint(id, now)
  local def = D.WinCan(id)
  local s = D.winSurfs[id]
  local gone = not def or D.Store().off or (D.fight and D.Store().sw.pinfight == false) or not T.DECK_LOGIN
  if gone then
    if s and D.winHeld ~= id and s.frame:IsShown() then s.frame:Hide() end
    return false
  end
  s = s or build(id)
  s.def = def
  local f, p = s.frame, D.Wins()[id]
  if not s.W then
    size(s, type(p.w) == "number" and p.w or D.WIN_W, type(p.h) == "number" and p.h or D.WIN_H)
    now = true
  end
  f:SetAlpha(D.fight and D.FIGHT_ALPHA or 1)
  f:SetFrameStrata(D.fight and D.FIGHT_STRATA or D.STRATA)
  f:EnableMouse(not D.fight)
  if not f:IsShown() then
    if D.winHeld ~= id then place(s) end
    f:Show()
    now = true
  end
  if now or s.seen ~= D.dirtyN or s.ticking or s.fought ~= D.fight then
    s.seen, s.fought = D.dirtyN, D.fight
    D.On(s, D.Paint)
    D.WinAfter(s)
  end
  return true
end
--- After anything that ran on a window: an app that went elsewhere does not take the window along.
function D.WinAfter(s)
  local to = s.page
  if to == s.id then return end
  s.page = s.id
  if to == "home" or to == nil then return D.WinClose(s.id) end
  if to ~= "switches" then D.Phone(D.Open, to) end
  D.WinPaint(s.id, true)
end
function D.WinsPaint(now)
  local any = false
  for id in pairs(D.Wins()) do if D.WinPaint(id, now) then any = true end end
  for id, s in pairs(D.winSurfs) do if not D.Wins()[id] and D.winHeld ~= id and s.frame:IsShown() then s.frame:Hide() end end
  D.WinsWake()
  return any
end
function D.WinsWake()
  local root = D.winRoot
  local want = (next(D.Wins()) ~= nil and not D.Store().off) or D.winHeld ~= nil
  if not root then
    if not want then return end
    root = CreateFrame("Frame")
    D.winRoot = root
  end
  if not want then root:SetScript("OnUpdate", nil) root.on = nil return end
  if root.on then return end
  root.on = true
  local acc, slow = 0, 0
  root:SetScript("OnUpdate", function(_, el)
    acc = acc + (el or 0)
    if (D.winHeld or D.winGrip) and D.Held() == false then D.WinGripEnd() D.WinDrop() end      -- (let go and never told)
    if D.winGrip then
      if acc >= 0.05 then acc = 0 D.WinGripMove() end
      return
    end
    if acc < (D.winSoon and 0.15 or D.BEAT) then return end
    acc, slow = 0, slow + 1
    D.winSoon = nil
    D.WinsPaint(slow % 10 == 0)
  end)
end

--- Out it goes: `held` = under the mouse until let go (the phone is not painted meanwhile, see D.PinOut).
function D.WinOut(id, held)
  local def = D.WinCan(id)
  if not def or D.fight then return false end
  if D.IsOut(id) then
    D.WinPaint(id, true)
    return true
  end
  D.Wins()[id] = {}
  local s = build(id)
  s.def, s.page, s.skip, s.tab = def, id, 0, def.tab
  if held then
    D.winHeld = id
    local f = s.frame
    size(s, s.W or D.WIN_W, s.H or D.WIN_H)
    f:SetScale(D.Store().scale or D.SCALE)
    local k = ask(f.GetEffectiveScale, f) or 1
    local x, y = GetCursorPosition()
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "BOTTOMLEFT", (x or 0) / k, (y or 0) / k + 14)
    D.WinPaint(id, true)
    f:StartMoving()
    f.moving = true
    D.WinsWake()
    return true
  end
  D.WinPaint(id, true)
  if D.page == id and D.surf == D.mainSurf then D.page = "home" end
  D.WinsWake()
  D.Save()
  D.Dirty(true)
  return true
end
function D.WinTake(id)
  local s = D.winSurfs[id]
  if not s or D.fight then return end
  D.winHeld = id
  s.frame:StartMoving()
  s.frame.moving = true
  if D.OverlayClear then D.OverlayClear(s) end
  D.WinsWake()
end
--- Let go: over the phone = back into it; anywhere else = it stays there.
function D.WinDrop()
  local id = D.winHeld
  if not id then return end
  D.winHeld = nil
  local s = D.winSurfs[id]
  local f = s and s.frame
  if f and f.moving then
    f.moving = nil
    pcall(f.StopMovingOrSizing, f)
  end
  local deck = D.mainSurf.frame
  if D.surf == D.mainSurf then deck = D.frame end
  if not D.fight and deck and deck:IsShown() and deck.IsMouseOver and ask(deck.IsMouseOver, deck) == true then return D.WinClose(id) end
  if s and D.Wins()[id] then
    keep(s)
    D.WinPaint(id, true)
    D.Phone(function() if D.page == id then D.page = "home" end end)
  end
  D.WinsPaint()
  D.Phone(D.Dirty, true)
end
--- Its x: back into the phone.
function D.WinClose(id)
  D.Wins()[id] = nil
  if D.winHeld == id then D.winHeld = nil end
  local s = D.winSurfs[id]
  if s then
    local f = s.frame
    if f.moving then f.moving = nil pcall(f.StopMovingOrSizing, f) end
    if f.find then f.find:ClearFocus() end
    f:Hide()
  end
  D.Save()
  D.WinsWake()
  D.Phone(D.Dirty, true)
end
-- the corner
function D.WinGrip(id)
  local s = D.winSurfs[id]
  if not s then return end
  local f = s.frame
  local l, t = ask(f.GetLeft, f), ask(f.GetTop, f)
  if type(l) == "number" and type(t) == "number" then
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
  end
  local k = ask(f.GetEffectiveScale, f) or 1
  local x, y = GetCursorPosition()
  D.winGrip = { id = id, x = x / k, y = y / k, w = s.W, h = s.H, k = k }
  D.WinsWake()
end
function D.WinGripMove()
  local g = D.winGrip
  local s = g and D.winSurfs[g.id]
  if not s then return end
  local x, y = GetCursorPosition()
  size(s, g.w + (x / g.k - g.x), g.h + (g.y - y / g.k))
  D.WinPaint(g.id, true)
end
function D.WinGripEnd()
  local g = D.winGrip
  if not g then return end
  D.winGrip = nil
  local s = D.winSurfs[g.id]
  if s then keep(s) D.WinPaint(g.id, true) end
end

-- whatever repaints the pulled-out cards (the login, a fight, a press, the theme, the switch) sees to the windows too
local pins = D.PinsPaint
D.PinsPaint = function(...)
  local any = pins and pins(...)
  if not D.winPainting then
    D.winPainting = true
    local fine, why = pcall(D.WinsPaint)
    D.winPainting = nil
    if not fine and geterrorhandler then geterrorhandler()(why) end
  end
  return any
end
