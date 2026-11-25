--[[
  BiSTheme / DeckOverlay.lua  --  THE BUTTONS THAT CAST (22 Nov 2026).

  A key, a row or the big button that says { word, macro = } / { word, spell = [, bag, slot | , unit] } / { word, item = } is SECURE: only a
  secure button may do it. The deck itself is plain (it resizes, flips and dims in a fight), so the secure buttons stand on their
  own root on UIParent, laid over the drawn ones BY NUMBERS - never anchored to the deck, never a child of it (a secure button
  anchored to our frame protects it: BiS Tools 1.7.0). The root is hidden by the client itself in a fight ([combat] hide) and
  comes back after it.

  PROBED by Arn, 22 Nov (bisdev plans/deckkit.lua, Tanaris): out of a fight both squares show and the skin is not protected; in one
  the overlay is gone, the skin grows, shrinks and moves; after it the overlay is back by itself.

  OUT OF A FIGHT ONLY: where they stand and what they do is set at a paint, and only when it changed. A button whose words cover
  nothing (its surface is hidden, under the mouse, being sized, or a window stands over it) is put away. `ok` on a button = the
  last word before the click (is the item still in that slot?): false = nothing happens.
]]
BiSTheme = BiSTheme or {}
local T = BiSTheme
local D = T.Deck
if not D or not T.DECK_READY or not D.On then return end
local MINOR = 3                                           -- 2 (23 Nov): "*type1", so a Shift-click casts too; 3 (25 Nov): none under the pop-out, a refused click stays refused
if (T.DECKOVER_MINOR or 0) >= MINOR then return end
T.DECKOVER_MINOR = MINOR

local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok and not (issecretvalue and (issecretvalue(a) or issecretvalue(b))) then return a, b end
end
local function fighting() return D.fight or ask(InCombatLockdown) and true or false end

D.overFree = D.overFree or {}
D.overOf = D.overOf or {}                                 -- owner (a surface, a pulled-out card) -> its buttons
D.overN = D.overN or 0

--- May there be any? (the client has the templates, the switch is on)
function D.OverlayOn()
  return not D.overNo and type(RegisterStateDriver) == "function" and T.DECK_LOGIN and D.Store().sw.casts ~= false and true or false
end
local function root()
  if D.overRoot then return D.overRoot end
  if fighting() or D.overNo then return nil end
  local fine, r = pcall(CreateFrame, "Frame", "BiSDeckOverlay", UIParent, "SecureHandlerStateTemplate")
  if not (fine and r) then D.overNo = true return nil end
  r:SetSize(1, 1)
  r:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
  r:SetFrameStrata("HIGH")
  RegisterStateDriver(r, "visibility", "[combat] hide; show")
  D.overRoot = r
  return r
end

-- what a button does, as attributes; the same words = the same button
-- "*type1", not "type1" (Arn, 23 Nov: "shift clicking does not disenchant"): with a modifier held the client asks "shift-type1",
-- then "*type1", then "type" - never "type1" - so a plain "type1" button did nothing on a Shift-click. "*" = any modifier.
local ATTR = { "*type1", "*macrotext1", "*spell1", "*item1", "target-bag", "target-slot", "unit" }
local function what(sec)
  local a = {}
  if sec.macro then a["*type1"], a["*macrotext1"] = "macro", tostring(sec.macro)
  elseif sec.spell then
    a["*type1"], a["*spell1"] = "spell", sec.spell
    if sec.bag and sec.slot then a["target-bag"], a["target-slot"] = sec.bag, sec.slot end
    if sec.unit then a.unit = sec.unit end
  elseif sec.item then a["*type1"], a["*item1"] = "item", type(sec.item) == "number" and "item:" .. sec.item or tostring(sec.item) end
  local key = ""
  for _, k in ipairs(ATTR) do key = key .. "|" .. tostring(a[k]) end
  return a, key
end

D.LATCH = 2                                                -- s a refused press keeps its release refused (make)
local function make(r)
  local b = CreateFrame("Button", nil, r, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")                  -- (the client's template takes the one its own setting says)
  b:SetScript("PreClick", function(self, button)
    if button == "RightButton" then return end
    local sec = self.sec
    if not sec or fighting() then return end
    -- A REFUSED CLICK STAYS REFUSED (25 Nov 2026, the release bug hunt): the button hears the press AND the release. A
    -- check refused on the press (the item moved) and repainted the deck; a repaint before the release aimed this catcher
    -- at the row now under the mouse, and the release - whose check passed - disenchanted THAT item. Now the release of a
    -- refused press is refused too (the latch lasts D.LATCH s at most, so a release never heard cannot hold it).
    local now = GetTime and GetTime() or 0
    if self.latch and now - self.latch < D.LATCH then
      self:SetAttribute("*type1", nil)
      self.key = nil
      return
    end
    self.latch = nil
    if type(sec.ok) == "function" then
      local fine, yes = pcall(sec.ok)
      if not (fine and yes) then
        self:SetAttribute("*type1", nil)                    -- cancelled, and not aimed again in this click
        self.key = nil
        self.latch = now
        D.Phone(D.Dirty)
      end
    end
  end)
  b:SetScript("PostClick", function(self, button, down)
    if button == "RightButton" then                         -- (on a live tile: the tile is hidden, nothing is cast)
      if not down and self.piece and self.piece.hush and not fighting() then D.Phone(self.piece.hush) end
      return
    end
    if not down then self.latch = nil end                   -- (the release came: the next press is judged afresh)
    if self.sec and self.def and self.key and not self.sec.peek then D.Used(self.def) end
    -- (what the addon does after it, once a click: the way up)
    if self.sec and self.key and not down and type(self.sec.after) == "function" then D.Call(self.def or D.homeDef, "after", self.sec.after) end
    D.Phone(D.Dirty)
  end)
  b:SetScript("OnEnter", function(self)
    local fn = self.piece and self.piece:GetScript("OnEnter")
    if fn then fn(self.piece) end
    if self.piece and self.piece.wash then self.piece.wash:Show() end
  end)
  b:SetScript("OnLeave", function(self)
    local fn = self.piece and self.piece:GetScript("OnLeave")
    if fn then fn(self.piece) end
  end)
  return b
end

local function away(b)
  b:Hide()
  b:SetAttribute("*type1", nil)
  b.key, b.sec, b.def, b.piece, b.at = nil, nil, nil, nil, nil
  D.overFree[#D.overFree + 1] = b
  D.overN = D.overN - 1
end
--- Put this owner's buttons away (out of a fight; in one the root is hidden, and the next paint after it does).
function D.OverlayClear(owner)
  local list = D.overOf[owner]
  if not list or fighting() then return end
  D.overOf[owner] = nil
  for _, b in ipairs(list) do away(b) end
end

-- a window stands over this spot of the phone (windows are in front of it)
local function covered(owner, x, y)
  if owner ~= D.mainSurf then return false end
  for _, s in pairs(D.winSurfs or {}) do
    local f = s.frame
    if f:IsShown() then
      local k = ask(f.GetEffectiveScale, f) or 1
      local l, t = ask(f.GetLeft, f), ask(f.GetTop, f)
      if type(l) == "number" and type(t) == "number" and x >= l * k and x <= (l + s.W) * k and y <= t * k and y >= (t - s.H) * k then return true end
    end
  end
  return false
end

--- UNDER THE OPEN POP-OUT (25 Nov 2026, the release bug hunt): the secure catchers sit 10 levels over their piece, so a row-2
--- piece's catcher (f+12) rose OVER the pop-out's plain totem choices (f+7 / f+8) - a click on "Searing" dropped the Call or
--- cast the Recall under it. A piece whose middle lies under the plate, and that is not itself one of the pop-out's own
--- entries (they stand over the plate), gets no catcher while the pop-out is open.
function D.UnderFly(w, k)
  local p = D.flyPlate
  if not (p and p.IsShown and p:IsShown()) then return false end
  if (ask(w.GetFrameLevel, w) or 0) > (ask(p.GetFrameLevel, p) or 0) then return false end
  local pk = ask(p.GetEffectiveScale, p) or 1
  local pl, pt, pw, ph = ask(p.GetLeft, p), ask(p.GetTop, p), ask(p.GetWidth, p), ask(p.GetHeight, p)
  local l, t, ww, hh = ask(w.GetLeft, w), ask(w.GetTop, w), ask(w.GetWidth, w), ask(w.GetHeight, w)
  if not (type(pl) == "number" and type(pt) == "number" and type(pw) == "number" and type(ph) == "number"
          and type(l) == "number" and type(t) == "number" and type(ww) == "number" and type(hh) == "number") then return false end
  local x, y = (l + ww / 2) * k, (t - hh / 2) * k
  return x >= pl * pk and x <= (pl + pw) * pk and y <= pt * pk and y >= (pt - ph) * pk
end

--- Lay the secure buttons over what `f` (owner's frame) just drew: every shown piece that carries `sec`.
function D.OverlayPaint(owner, f)
  if fighting() then return 0 end
  local held = f.moving or (owner == D.mainSurf and (D.grip or D.pinHeld or D.winHeld)) or (D.winGrip and D.winGrip.id == owner.id and owner.id)
  if not f:IsShown() or held or not D.OverlayOn() then D.OverlayClear(owner) return 0 end
  local r, list, n = nil, D.overOf[owner] or {}, 0
  local us = ask(UIParent.GetEffectiveScale, UIParent) or 1
  for _, w in ipairs(f.pieces) do
    if w.sec and w:IsShown() then
      local k = ask(w.GetEffectiveScale, w) or 1
      local l, t = ask(w.GetLeft, w), ask(w.GetTop, w)
      local ww, hh = ask(w.GetWidth, w), ask(w.GetHeight, w)
      if type(ww) == "number" and w.secRight then ww = ww - w.secRight end   -- (the row's own keys at its right stay clickable)
      if type(l) == "number" and type(t) == "number" and type(ww) == "number" and type(hh) == "number" and ww > 0 and hh > 0
        and not covered(owner, (l + ww / 2) * k, (t - hh / 2) * k) and not (owner == D.mainSurf and D.UnderFly(w, k)) then
        r = r or root()
        if not r then break end
        n = n + 1
        local b = list[n]
        if not b then
          b = table.remove(D.overFree) or make(r)
          list[n] = b
          D.overN = D.overN + 1
        end
        b.sec, b.def, b.piece = w.sec, w.secDef, w
        local at = ("%.1f %.1f %.1f %.1f"):format(l * k / us, t * k / us, ww * k / us, hh * k / us)
        if b.at ~= at then
          b.at = at
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * k / us, t * k / us)
          b:SetSize(ww * k / us, hh * k / us)
        end
        local a, key = what(w.sec)
        if b.key ~= key then
          b.key = key
          for _, name in ipairs(ATTR) do b:SetAttribute(name, a[name]) end
        end
        b:SetFrameLevel((ask(w.GetFrameLevel, w) or 1) + 10)
        b:Show()
      end
    end
  end
  for i = #list, n + 1, -1 do away(table.remove(list, i)) end
  D.overOf[owner] = n > 0 and list or nil
  return n
end

-- after a fight: what was hidden or closed in it leaves nothing behind
local ev = D.overEvents or CreateFrame("Frame")
D.overEvents = ev
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
  if fighting() then return end
  for owner in pairs(D.overOf) do
    local f = owner.frame or (owner.pieces and owner) or (owner == D.mainSurf and D.frame) or nil
    if not f or not f:IsShown() then D.OverlayClear(owner) end
  end
end)
