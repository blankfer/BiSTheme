--[[
  BiSTheme / Pad.lua  --  a BiS window you can drive with an Xbox pad.

  Arn, 15 Nov 2026: someone with only a controller can open, close, move around in and press every
  BiS window. The spec is _bisdev/docs/gamepad-audit.md, "The shared piece: BiSTheme/Pad.lua".

  WHAT THE LIVE PROBES PROVED ON FOREVER (15 Nov 2026) - this file is built to them, never against:
    - an addon frame gets the pad: frame:EnableGamePadButton(true), then OnGamePadButtonDown(self, button)
      fires with PAD1 (A) PAD2 (B) PAD3 (X) PAD4 (Y), PADLSHOULDER/PADRSHOULDER, PADLTRIGGER/PADRTRIGGER,
      PADDUP/PADDDOWN/PADDLEFT/PADDRIGHT, PADFORWARD (Start), PADBACK (View), PADLSTICK/PADRSTICK.
    - the STICKS stay the game's: the character keeps walking while our frame holds a stick, and there is no
      SetPropagateGamePadInput on Forever. So this file never touches the sticks - D-pad, face buttons,
      shoulders and triggers only. The game binds nothing on them.
    - the game's own pad cursor draws nothing (Forever stays in keyboard/mouse style), so the focus is OURS:
      the widget's own hover look plus a thin accent bracket.
    - "pad in use" = C_GamePad.IsEnabled through pcall (on both censuses; C_InputInterfaceStyle is on neither).
    - Forever answers "blocked" to (Un)RegisterEvent from a C_Timer while the gamepad UI is on, and the
      gamepad UI walks UISpecialFrames and blames whoever is in it. So: one event, registered once at file
      load and never again; and T.EscapeCloses keeps our windows off that list while a pad is in use.

  Usage from any addon:

      BiSTheme.EscapeCloses("BiSToolsCodex")              -- instead of table.insert(UISpecialFrames, ...)
      BiSTheme.PadNav(frame, {
        items = function() return frame.rows end,          -- the clickable widgets, any order
        back  = function() frame:Hide() end,               -- B (the default: frame:Hide())
        tabs  = { prev = fn, next = fn },                  -- LB / RB (optional)
        alt   = function(item) end,                        -- X = the right-click meaning (optional)
        extra = function(item) end,                        -- Y = the shift-click meaning (optional)
        scroll = function(delta) end,                      -- LT +1 / RT -1 (optional)
      })

  The D-pad picks the nearest item in that direction by GetCenter(), asked only on a press - nothing runs
  per frame and nothing runs at rest. A clicks the focused item (item:Click("LeftButton")). Secure /
  protected widgets (IsProtected() true) are never focused: they need the game's pad cursor or a binding.
  The first press in a window shows where you are (focuses its first item) instead of clicking blind.

  THE STACK. Only the top-most shown nav window holds the pad (EnableGamePadButton true on it alone); when
  it hides, the one under it takes over; when none shows, no BiS frame holds the pad and the character plays
  as normal. Changing who holds is never done in a fight (InCombatLockdown) unless a live probe says it is
  safe (T.PAD.COMBAT_SAFE): it waits for PLAYER_REGEN_ENABLED.

  Self-guarded like the other kit files: an addon may ship a copy under Libs\BiSTheme\. Newest PAD_MINOR
  wins; the state (T.padNavs, T.padStack) is kept on the shared table so a newer copy takes it over, and
  every hook calls T.PadX by name so the newest code runs.
]]

BiSTheme = BiSTheme or {}
local T = BiSTheme
if (T.PAD_MINOR or 0) >= 1 then return end
T.PAD_MINOR = 1          -- 1: PadOn, EscapeCloses, PadNav + the stack (15 Nov 2026, the gamepad audit)

T.PAD = T.PAD or {}
local P = T.PAD
P.COMBAT_SAFE = P.COMBAT_SAFE or false   -- EnableGamePadButton in a fight: UNPROBED, so never until a probe says
P.SLANT = P.SLANT or 2       -- how much a step sideways costs against a step the way you pressed
P.ARM = P.ARM or 6           -- bracket arm length, px
P.THICK = P.THICK or 2       -- bracket line width, px
P.GAP = P.GAP or 3           -- bracket distance outside the widget, px

-- the accent, from the palette when one ran; the same BiS purple when this file is embedded alone
local function accent()
  if T.rgb then return T.rgb("accent") end
  return 0xb9 / 255, 0x80 / 255, 0xff / 255
end
local function accentKey() return (T.hex and T.hex.accent) or "b980ff" end

-- ---------------------------------------------------------------------------------------------------------
-- the one question
-- ---------------------------------------------------------------------------------------------------------

--- Is a pad in use? C_GamePad.IsEnabled through pcall (BiSMemories' ns.Gamepad, 13 Nov). False on a client
--- without it, and false when it throws.
function T.PadOn()
  local G = _G.C_GamePad
  if not (G and G.IsEnabled) then return false end
  local ok, on = pcall(G.IsEnabled)
  return ok and on == true
end

--- The one road onto UISpecialFrames (Escape's list). Skipped while a pad is in use - the gamepad UI walks
--- that list from Blizzard's own code and blames the addon (FojjiCore skips it the same way, solved.md).
--- Answers whether the name is on the list now; never lists a name twice.
function T.EscapeCloses(name)
  if not name or type(UISpecialFrames) ~= "table" or T.PadOn() then return false end
  for _, n in ipairs(UISpecialFrames) do if n == name then return true end end
  table.insert(UISpecialFrames, name)
  return true
end

-- ---------------------------------------------------------------------------------------------------------
-- the stack
-- ---------------------------------------------------------------------------------------------------------

T.padNavs = T.padNavs or {}      -- frame -> rec { frame, spec, focus, held, bracket }
T.padStack = T.padStack or {}    -- recs of the shown nav windows, newest last

local function visible(w)
  if w.IsVisible then return w:IsVisible() and true or false end
  return w.IsShown and w:IsShown() and true or false
end

local function top()
  local s = T.padStack
  for i = #s, 1, -1 do
    if visible(s[i].frame) then return s[i] end
  end
end

local function remove(rec)
  local s = T.padStack
  for i = #s, 1, -1 do if s[i] == rec then table.remove(s, i) end end
end

--- Hand the pad to the top-most shown nav window, take it from every other. Runs on a show, a hide, a new
--- PadNav and (when a fight held it back) PLAYER_REGEN_ENABLED - never per frame, never from a timer of ours.
function T.PadSync()
  local want = T.PadOn() and top() or nil
  T.padTop = want
  local change = false
  for _, rec in pairs(T.padNavs) do
    if (rec.held or false) ~= (rec == want) then change = true break end
  end
  if not change then T.padPending = nil return end
  if not P.COMBAT_SAFE and InCombatLockdown and InCombatLockdown() then
    T.padPending = true              -- after the fight: the event frame below runs this again
    return
  end
  T.padPending = nil
  for frame, rec in pairs(T.padNavs) do
    local hold = rec == want
    if (rec.held or false) ~= hold then
      if frame.EnableGamePadButton then frame:EnableGamePadButton(hold) end
      rec.held = hold
    end
  end
end

-- ---------------------------------------------------------------------------------------------------------
-- the focus: the widget's own hover look, and a thin accent bracket for widgets that have none
-- ---------------------------------------------------------------------------------------------------------

local function usable(w)
  if type(w) ~= "table" or not visible(w) then return false end
  if w.IsProtected and w:IsProtected() then return false end      -- secure: the game's cursor or a binding
  if w.IsEnabled and w:IsEnabled() == false then return false end
  return true
end

local function items(rec)
  local ok, list = pcall(rec.spec.items)
  local out = {}
  if not ok or type(list) ~= "table" then return out end
  for _, w in ipairs(list) do if usable(w) then out[#out + 1] = w end end
  return out
end

local CORNERS = { { "TOPLEFT" }, { "TOPRIGHT" }, { "BOTTOMLEFT" }, { "BOTTOMRIGHT" } }

local function bracket(rec)
  local b = rec.bracket
  if not b then
    b = CreateFrame("Frame", nil, rec.frame)
    b.lines = {}
    for _, c in ipairs(CORNERS) do
      local h = b:CreateTexture(nil, "OVERLAY")
      h:SetSize(P.ARM, P.THICK) h:SetPoint(c[1])
      local v = b:CreateTexture(nil, "OVERLAY")
      v:SetSize(P.THICK, P.ARM) v:SetPoint(c[1])
      b.lines[#b.lines + 1] = h
      b.lines[#b.lines + 1] = v
    end
    b:Hide()
    rec.bracket = b
  end
  local key = accentKey()
  if b.hex ~= key then                     -- painted once, again only when the accent itself changed
    local r, g, bl = accent()
    for _, t in ipairs(b.lines) do t:SetColorTexture(r, g, bl, 1) end
    b.hex = key
  end
  return b
end

local function script(w, name)
  local fn = w.GetScript and w:GetScript(name)
  if fn then pcall(fn, w, true) end         -- a row whose hover throws must not take the pad with it
end

local function unfocus(rec)
  local w = rec.focus
  rec.focus = nil
  if rec.bracket then rec.bracket:Hide() end
  if w then script(w, "OnLeave") end
end

local function focus(rec, w)
  if rec.focus == w then return end
  unfocus(rec)
  rec.focus = w
  script(w, "OnEnter")
  local b = bracket(rec)
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", w, "TOPLEFT", -P.GAP, P.GAP)
  b:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", P.GAP, -P.GAP)
  if w.GetFrameLevel then b:SetFrameLevel(w:GetFrameLevel() + 5) end
  b:Show()
end

-- the nearest item the way you pressed: distance that way, plus SLANT x the distance sideways
local DIRS = { PADDUP = { 0, 1 }, PADDDOWN = { 0, -1 }, PADDLEFT = { -1, 0 }, PADDRIGHT = { 1, 0 } }
local function nearest(list, from, dx, dy)
  local x, y = from:GetCenter()
  if not x then return nil end
  local best, bestScore
  for _, w in ipairs(list) do
    if w ~= from then
      local cx, cy = w:GetCenter()
      if cx then
        local along = (cx - x) * dx + (cy - y) * dy
        if along > 0.5 then
          local score = along + P.SLANT * (math.abs((cx - x) * dy) + math.abs((cy - y) * dx))
          if not bestScore or score < bestScore then best, bestScore = w, score end
        end
      end
    end
  end
  return best
end

-- ---------------------------------------------------------------------------------------------------------
-- a press
-- ---------------------------------------------------------------------------------------------------------

--- One pad button on a nav window. Answers true when it was ours to handle.
function T.PadPress(frame, button)
  local rec = T.padNavs[frame]
  if not rec or rec ~= T.padTop then return false end   -- held over from before a fight: not the top any more
  local spec, cur = rec.spec, rec.focus
  local d = DIRS[button]
  if d then
    local list = items(rec)
    local still = false
    if cur then for _, w in ipairs(list) do if w == cur then still = true break end end end
    if not still then
      unfocus(rec)
      if list[1] then focus(rec, list[1]) end              -- the first press shows where you are
    else
      local nxt = nearest(list, cur, d[1], d[2])
      if nxt then focus(rec, nxt) end                      -- nothing that way: stay
    end
    return true
  elseif button == "PAD1" then
    if cur and usable(cur) then
      if cur.Click then cur:Click("LeftButton") end
    else
      unfocus(rec)
      local first = items(rec)[1]
      if first then focus(rec, first) end                  -- never click blind
    end
    return true
  elseif button == "PAD2" then
    if spec.back then spec.back() else frame:Hide() end
    return true
  elseif button == "PAD3" then
    if spec.alt and cur and usable(cur) then spec.alt(cur) return true end
  elseif button == "PAD4" then
    if spec.extra and cur and usable(cur) then spec.extra(cur) return true end
  elseif button == "PADLSHOULDER" or button == "PADRSHOULDER" then
    local fn = spec.tabs and spec.tabs[button == "PADLSHOULDER" and "prev" or "next"]
    if fn then unfocus(rec) fn() return true end           -- a new page: the next press finds its first item
  elseif button == "PADLTRIGGER" or button == "PADRTRIGGER" then
    if spec.scroll then spec.scroll(button == "PADLTRIGGER" and 1 or -1) return true end
  end
  return false
end

function T.PadRaise(frame)
  local rec = T.padNavs[frame]
  if not rec then return end
  remove(rec)
  T.padStack[#T.padStack + 1] = rec
  T.PadSync()
end

function T.PadDrop(frame)
  local rec = T.padNavs[frame]
  if not rec then return end
  unfocus(rec)
  remove(rec)
  T.PadSync()
end

--- Make a window drivable with the pad. Hooks its OnShow / OnHide / OnGamePadButtonDown once (HookScript, so
--- the window's own scripts stay); asked again for the same frame, it only takes the new spec.
function T.PadNav(frame, spec)
  if type(frame) ~= "table" or type(spec) ~= "table" or type(spec.items) ~= "function" then
    error("BiSTheme.PadNav(frame, { items = function() ... end })", 2)
  end
  local rec = T.padNavs[frame]
  if rec then rec.spec = spec return rec end
  rec = { frame = frame, spec = spec }
  T.padNavs[frame] = rec
  frame:HookScript("OnShow", function(f) T.PadRaise(f) end)
  frame:HookScript("OnHide", function(f) T.PadDrop(f) end)
  if frame.EnableGamePadButton then             -- a client with no pad input has no such script either
    frame:HookScript("OnGamePadButtonDown", function(f, button) T.PadPress(f, button) end)
  end
  if visible(frame) then T.PadRaise(frame) else T.PadSync() end
  return rec
end

-- AFTER A FIGHT. Registered once, here, at file load - never (un)registered later, never from a timer.
do
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function()
    if T.padPending and T.PadSync then T.PadSync() end
  end)
  T.padEvents = ev
end
