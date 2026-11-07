# The BiS header — `BiS> _` prompt (`BiSTheme/Console.lua`, CONSOLE_MINOR 6)

The title of every BiS window is a command prompt. It shows `BiS> ` in accent, then words
that rotate through what the addon is doing, then a cursor blinking at 2 Hz. Words fade out
and in — never a hard cut. Nothing the addon says about itself goes to chat any more; chat is
for `/slash` answers only.

    BiS> Summon_          →  BiS> 2 at stone_          →  BiS> Druid asks_

Arn, 8 Sep 2026: *"prompt `BiS> _` blinking should be in the header and cycle relevant
messages, addon name, summoners at the stone, receiving summon, requesting summon, etc."*
Innervate's rotating `▼2 online` title was the ancestor.

## Two kinds of text

| | what | how long | example |
|---|---|---|---|
| **slot** | state that lasts | rotates every `cycle` (3 s) while it has text | `Summon` · `2 at stone` · `requesting...` · `preview - nothing sends` |
| **say** | an event | jumps the queue, holds `hold` (3 s), then slots resume; several queue up | `Druid asks` · `X accepted` · `request now` · `stone learned` |

Slot 1 is always the addon's name in `accent`. Clear a slot with `nil` the moment the state
ends. Colour by meaning, palette names only: `good` counts/yes, `gold` asks/"mine", `warn`
declines, `muted` going quiet, `ink2` plain.

## API

```lua
local con = BiSTheme.Console(titleFontString, { width = 106 })   -- opts: width, size, cycle, hold, fade
con:Set("name",  "Summon", "accent")        -- slot; nil or "" clears it
con:Set("stone", "2 at stone", "good")
con:Say("Druid asks", "gold")               -- event line
con:Paint()                                 -- from a ~0.2 s ticker: blink, rotate, fade, expire
con:Clear()                                 -- drops the QUEUE, not the line showing
con.line                                    -- { text, colour } on screen right now
con:Text()  con:Width()                     -- prompt + words + cursor, for asserts
BiSTheme.Fit(fs, text, width)               -- trim with "..." until GetStringWidth fits
BiSTheme.CONSOLE = { cycle = 3, hold = 3, fade = 0.25, size = 8, prompt = "BiS> " }
```

The console makes **one extra FontString** for the words, anchored `LEFT` of the title's
`RIGHT`, so the words fade on their own while `BiS> ` stands still. `Fit` trims the plain
words only, then wraps prompt, colour and cursor around what survived — it never cuts inside
a colour escape.

## Adopting it in a window — five steps

1. Copy `BiSTheme/Console.lua` → `<Addon>/Libs/BiSTheme/Console.lua` **byte-identical**
   (md5 `9af6af04…` today). First TOC line. `_bisdev/sync.ps1` keeps it in step; never edit
   the copy — change canon, sync out.
2. Header layout: `4 + prompt … | buttons at −3 / −17 / −38` (12×12 boxes). No logo, no pin.
   Prompt width = `W − strip − 8`. **Write the arithmetic as a comment where the number is
   set** — `486 − 316 = 158 clear, held 148` is checkable a year later; `width = 148` is not.
3. Code:
   ```lua
   local title = K.fs(head, "", 8, "ink")  title:SetPoint("LEFT", head, "LEFT", 4, 0)
   NS.con = BiSTheme.Console(title, { width = W - 56 - 8 })
   NS.con:Set("name", "Nebbinator", "accent")
   -- state → con:Set(key, text|nil, colour)   events → con:Say(text, colour)
   -- ticker 0.1–0.2 s while shown → NS.con:Paint()
   ```
   Route every window-side print through `Say`; keep `NS.Print` for slash replies. A toggle
   with two callers: **the function does the work and says it in the prompt; the slash
   handler adds the chat line** — else every click announces twice.
4. Resolve the theme **per call, per colour name** (`_G.BiSTheme` at call time), never at
   file load — addons sorting before `BiSTheme` alphabetically capture nil and run on the
   inline fallback forever, invisibly.
5. Harness asserts (below). Mutation-test each one before believing it.

## Testing a console without a screen (four traps, all paid for)

- **Step the clock in 0.05 s slices, never whole seconds.** One 3 s jump expires a `Say`
  before it is ever drawn; the test reads "event never showed" when the console is fine.
- **Assert the fade as ≥3 frames strictly between 0 and 1.** "Lowest alpha was 0" also passes
  a hard cut. Set `fade = 0.0001` and the test must go red.
- **Mock FontString** needs `GetParent`, `SetAlpha`, `SetFont` that records the size, and
  `GetStringWidth` that strips colour escapes and scales by that size — or the budget assert
  measures `|cffb980ff` and lies.
- **Load Console.lua the TOC way**, not the fallback branch. With BiSTheme absent the file
  installs its own palette into `_G.BiSTheme`, so "no theme installed" must gate on how the
  run was launched, not on whether the global exists. Run the whole suite a second time with
  a wrong-on-purpose accent (`dev/theme.lua`, `#ff0000`) — only a wrong palette proves the real
  one is read.
- Plus: **count frames parented to the header** (one button, one frame; move the number in the
  same commit as the button) and **a slot that reads a moving value must read an accessor**,
  not a copy taken at load (BiSHealing's shield slot pinned to whoever was shielded at login).

## The order quirk — fixed in minor 3 (11 Sep 2026, debt #4)

Was: `Con:Set(key, nil)` cleared the slot but left the key in `order`; the next
`Set(key, value)` saw `slots[key] == nil` and appended the key **again**, so a slot that
toggles (Nebbinator's `N new`, Tools' `asking`) ended up in `order` five or six times and
hogged the rotation. Now `Set` checks `order` for the key before appending — a key keeps its
place for good; `Current` already skips cleared keys. Test: toggle a slot five times,
`#order` stays 2 and the rotation alternates (the old code reads `TTTT`). Synced to every
embedder with `sync.ps1`; the section below says which.

## The cursor shift — fixed in minor 4 (11 Sep 2026, debt #18)

Was: the cursor was a `"_"`/`" "` swapped into the words FontString every half second, and
on the client that swap moved the words a hair each blink (Arn, on the Healing plate:
"every time it adds the _ it does a micro shift of the text"). Now the cursor is a
FontString of its own, hung off the words' right edge, blinked by **alpha**; the words text
never carries it and never changes between phases. `Text()` still reads `…_` / `… ` so
every existing assert holds. Test: paint two phases, `words:GetText()` identical and free of
`_`, `cur:GetAlpha()` alternating 1/0. Synced to every embedder the same day.

## The per-frame cost — fixed in minor 5 (7 Oct 2026, the cost pass)

Was: every `Paint` set the words and measured them, and an overflowing line was trimmed a
character at a time with a `SetText` and a `GetStringWidth` for each - and three windows
(BiSGamba, BiSGuild, the minimap menu) paint every frame. A second of frames on one long line
was 2,640 sets and 2,580 measures. Now `Paint` keeps the drawn line's key (room, colour as
drawn, text) in `self.painted` and returns before touching the words when it has not changed;
the fade alpha and the cursor blink still run every paint. Test: sixty frames, same words, zero
sets and zero measures, and a `Cost.Count` budget of one client call a frame.

## Who wears it (verified on disk 11 Sep 2026)

BiSTools (first, 8 Sep) · Nebbinator 3.1.0 · BiSHealing rc49 · BiSGamba 1.1.0 · BiSJC v4 ·
BiSInnervate 3.3.6 — all six at md5 `9af6af04` (minor 2) until 11 Sep pm; minor 3 `9e7767eb`, then **minor 4 `07f3cb04`**, both synced the same day.

---

## Source — `BiSTheme/Console.lua` as on disk

```lua
--[[
  BiSTheme / Console.lua  --  the "BiS> _" prompt every BiS window carries in its header.

  Arn, 8 Sep 2026: "prompt `BiS> _` blinking should be in the header and cycle
  relevant messages: addon name, summoners at the stone, receiving summon,
  requesting summon, etc." Chat stays clean: what the addon is doing is said
  here, not in the chat frame. Chat is for /slash answers only.

  The title FontString of the window IS the console. It shows

      BiS> <text>_            cursor blinking at 2 Hz

  The words fade out and the next ones fade in (Arn: "fade in and out animations,
  not hard cuts"); the `BiS> ` prompt itself never moves. The console makes one
  extra FontString for the words, anchored to the right of the title.

  where <text> is either a standing SLOT (the addon's name, "2 at stone",
  "requesting...") - the slots rotate every `cycle` seconds - or a transient
  line pushed with Say ("Druid asks", "Druid accepted"), which jumps the queue,
  holds for `hold` seconds, then the rotation resumes.

  Usage from any addon:

      local con = BiSTheme.Console(titleFontString, { width = 110, size = 8 })
      con:Set("name", "Summon")                 -- slot 1: always the addon's name
      con:Set("stone", "2 at stone", "good")    -- a state slot; nil text clears it
      con:Say("Druid asks", "gold")             -- an event line, shown once
      con:Paint()                               -- from a ~0.2 s ticker: blink, rotate, expire

  Slots rotate in the order they were first Set. Pick words that fit the box:
  T.Fit trims with an ellipsis as the net, not the plan.

  Self-guarded like LibBiSComm: an addon may ship a copy under Libs\BiSTheme\ so
  the prompt works without BiSTheme installed. Newest CONSOLE_MINOR wins; the
  canonical file lives in the BiSTheme addon and is copied out, never edited in
  place. If BiSTheme itself is absent the palette falls back inline.
]]

BiSTheme = BiSTheme or {}
local T = BiSTheme
if (T.CONSOLE_MINOR or 0) >= 6 then return end
T.CONSOLE_MINOR = 6      -- 6: T.Stamp, the faint version in a window's corner (6 Nov 2026)
                         -- 5: Paint sets and measures the words only when they change (7 Oct 2026, the cost pass)
                         -- 4: the cursor is its own FontString, blinked by alpha -- the words never move (11 Sep 2026)
                         -- 3: a toggled slot no longer re-appends itself to the rotation

-- palette fallback: only when this file is embedded and BiSTheme.lua never ran
if not T.rgb then
  local FALLBACK = {
    bg = "121020", surface = "1a1730", sunken = "221d3c", line = "2a2446",
    line2 = "3a3260", ink = "ece8f6", ink2 = "c6bedd", muted = "968ead",
    accent = "b980ff", accentSoft = "2c2148", good = "4fd0cf", warn = "f08cb0",
    gold = "e5c04a", slate = "8fb4d6", dim = "8e86a6",
  }
  T.hex = T.hex or FALLBACK
  local cache = {}
  function T.rgb(name)
    local hex = T.hex[name] or T.hex.ink
    local c = cache[hex]
    if c then return c[1], c[2], c[3] end
    c = { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
    cache[hex] = c
    return c[1], c[2], c[3]
  end
  function T.rgba(name, a) local r, g, b = T.rgb(name) return r, g, b, a or 1 end
  function T.text(name, s) return "|cff" .. (T.hex[name] or T.hex.ink) .. tostring(s) .. "|r" end
end

-- defaults; an addon may override per console through opts
T.CONSOLE = {
  cycle  = 3,       -- seconds a standing slot shows before the next one
  hold   = 3,       -- seconds a Say line holds before the rotation resumes
  fade   = 0.25,    -- seconds to fade the words out, and again to fade the next in
  size   = 8,       -- font size of the words (the title's own size is the caller's)
  prompt = "BiS> ",
}

--- A label must fit its box: shrink with an ellipsis until GetStringWidth says so.
--- (Arn, 8 Sep: "summon requested - click to cancel" ran into the "all" button.)
--- Pick text that fits outright; the ellipsis is the net, not the plan.
function T.Fit(fs, text, width)
  fs:SetText(text)
  if not width or not fs.GetStringWidth then return text end
  local t = text
  while fs:GetStringWidth() > width and #t > 1 do
    t = t:sub(1, -2)
    fs:SetText(t .. "...")
  end
  return fs:GetText()
end

local Con = {}
Con.__index = Con

--- Wrap a FontString (the window's title) as the prompt. The title keeps "BiS> ";
--- the words live in a second FontString to its right so they can fade on their own.
function T.Console(fs, opts)
  opts = opts or {}
  local D = T.CONSOLE
  local c = setmetatable({}, Con)
  c.fs, c.width = fs, opts.width
  c.cycle, c.hold, c.fadeT = opts.cycle or D.cycle, opts.hold or D.hold, opts.fade or D.fade
  c.slots, c.order, c.queue = {}, {}, {}
  c.idx, c.since = 1, GetTime()
  fs:SetText(T.text("accent", D.prompt))
  local w = fs:GetParent():CreateFontString(nil, "OVERLAY")
  -- THE USER'S FONT WHEN ONE IS LENT. T.SetFont is BiSTheme's, and falls back to the client's own
  -- when there is no lender or the path is refused - a FontString whose SetFont failed draws
  -- nothing at all, which is an invisible label rather than an ugly one.
  if T.SetFont then T.SetFont(w, opts.size or D.size) else w:SetFont(STANDARD_TEXT_FONT, opts.size or D.size, "") end
  w:SetPoint("LEFT", fs, "RIGHT", 0, 0)
  w:SetText("")
  c.words = w
  -- minor 4: the cursor is a FontString of its own, hung off the words' right
  -- edge and blinked by ALPHA. Up to minor 3 it was a "_"/" " swapped into the
  -- words text, and on the client that swap moved the words a hair every half
  -- second (Arn, on the Healing plate: "Heal_ moves like one space forward").
  local cur = fs:GetParent():CreateFontString(nil, "OVERLAY")
  if T.SetFont then T.SetFont(cur, opts.size or D.size) else cur:SetFont(STANDARD_TEXT_FONT, opts.size or D.size, "") end
  cur:SetPoint("LEFT", w, "RIGHT", 0, 0)
  cur:SetText(T.text("ink2", "_"))
  c.cur = cur
  if fs.GetStringWidth then
    c.promptW = fs:GetStringWidth()
    c.curW = cur:GetStringWidth()
  end
  c.alpha = 1
  c:Paint()
  return c
end

--- The whole line as text (prompt + words + cursor) and its width, for checks.
--- The cursor reads as "_" when lit and " " when blinked off, as it always did.
function Con:Text()
  return (self.fs:GetText() or "") .. (self.words:GetText() or "") .. (self.curOn and "_" or " ")
end
function Con:Width()
  if not self.fs.GetStringWidth then return 0 end
  return self.fs:GetStringWidth() + self.words:GetStringWidth() + (self.curW or 0)
end

--- A standing slot: shown in rotation while it has text. nil clears it.
function Con:Set(key, text, colour)
  if text == nil or text == "" then
    self.slots[key] = nil
  else
    -- minor 3: a key keeps its place in the rotation for good. Clearing a slot and
    -- setting it again used to append the key a second time (the slot was nil, so it
    -- looked new), and a slot that toggles - Nebbinator's `N new`, Tools' `asking` -
    -- ended up in `order` five or six times and hogged the rotation.
    local known = false
    for _, k in ipairs(self.order) do if k == key then known = true break end end
    if not known then self.order[#self.order + 1] = key end
    self.slots[key] = { text = tostring(text), colour = colour or "ink" }
  end
  self:Paint()
end

--- An event line: jumps the rotation, holds `hold` seconds, then the slots resume.
--- Several in a row queue up and show one after the other.
function Con:Say(text, colour)
  local q = self.queue
  q[#q + 1] = { text = tostring(text), colour = colour or "ink2" }
  self:Paint()
end

function Con:Clear()
  self.queue = {}
  self:Paint()
end

-- the slot in rotation right now, skipping cleared keys
function Con:Current(now)
  local live = {}
  for _, k in ipairs(self.order) do if self.slots[k] then live[#live + 1] = self.slots[k] end end
  if #live == 0 then return nil end
  if now - self.since >= self.cycle then
    self.idx = self.idx + 1
    self.since = now
  end
  if self.idx > #live then self.idx = 1 end
  return live[self.idx]
end

--- Blink the cursor, rotate the slots, expire the said line. Call from a ticker.
function Con:Paint()
  local now = GetTime()
  local line
  if self.saying then
    if now - self.saidAt >= self.hold then
      self.saying = nil
      self.since = now   -- the slot after a Say gets its full cycle
    else
      line = self.saying
    end
  end
  if not line and #self.queue > 0 then
    self.saying = table.remove(self.queue, 1)
    self.saidAt = now
    line = self.saying
  end
  if not line then line = self:Current(now) end
  -- fade: the words on screen go to 0 over fadeT, the new words come up from 0
  local same = (line == nil and self.line == nil) or
    (line and self.line and line.text == self.line.text and line.colour == self.line.colour)
  if not same and self.fading ~= "out" then
    self.fading, self.fadeAt = "out", now
  end
  local a = 1
  if self.fadeAt and self.fadeAt > now then self.fadeAt = now end   -- a clock that moved back
  if self.fading == "out" then
    a = 1 - (now - self.fadeAt) / self.fadeT
    if a <= 0 then
      a = 0
      self.line = line
      self.fading, self.fadeAt = "in", now
    end
  elseif self.fading == "in" then
    a = (now - self.fadeAt) / self.fadeT
    if a >= 1 then a = 1 self.fading = nil end
  end
  self.alpha = a
  self.words:SetAlpha(a)
  local shown = self.line
  local blink = math.floor(now * 2) % 2 == 0
  self.curOn = blink
  self.cur:SetAlpha(blink and 1 or 0)     -- the cursor blinks; the words stay put
  -- ONLY WHEN IT CHANGED (7 Oct 2026, the cost pass). Three windows paint this every frame, and
  -- each paint set the text, measured it, and - when it overflowed - trimmed a character at a
  -- time with a SetText and a measure for each. The words change every few seconds; the alpha
  -- above is all a frame needs. The key holds the colour as drawn, so a theme change repaints.
  local room = self.width and (self.width - (self.curW or 0) - (self.promptW or 0)) or 0
  local key = shown and (room .. "\1" .. T.text(shown.colour, shown.text)) or ""
  if key == self.painted then return end
  self.painted = key
  local words = shown and shown.text or ""
  if self.width and shown then
    -- trim the plain words only (never inside a colour escape); prompt and
    -- cursor keep their own width outside the trim
    words = T.Fit(self.words, words, room)
  end
  self.words:SetText(shown and T.text(shown.colour, words) or "")
end

--------------------------------------------------------------------
-- THE STAMP (minor 6; Arn, 6 Nov 2026: "we did it on one addon but we should do it for all the windows on all addons
-- faint out of the way only you can see"). Which copy of an addon a window belongs to, read from its own TOC: the
-- version, and on a copy _bisdev/deploy.sh put in the game its X-BiS-Build stamp ("branch@sha[+] MMDD-HHMM") as
-- "1.9.2  9e52109+ 1106-1841". A released zip has no stamp: the version alone. Here because every addon embeds this
-- file (Options.lua is not in all of them).
--------------------------------------------------------------------
T.STAMP = { size = 7, alpha = 0.55, colour = "dim" }

local function meta(addon, key)
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  if not (get and type(addon) == "string") then return nil end
  local ok, v = pcall(get, addon, key)
  if not ok or type(v) ~= "string" or v == "" then return nil end
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

--- "1.9.2  9e52109+ 1106-1841", "1.9.2", or nil for an addon the client does not know.
function T.StampText(addon)
  local v = meta(addon, "Version")
  if not v then return nil end
  local b = meta(addon, "X-BiS-Build")
  local sha = b and b:match("@(%S+)")
  local when = b and b:match("(%S+)$")
  return sha and (v .. "  " .. sha .. " " .. (when or "")) or v
end

--- Put it in a window, faint: T.Stamp(frame, "BiSGamba"[, point, x, y]) - the bottom right corner unless told.
--- One label per window: asked again, the same one moves and reads the text again. Answers it, or nil.
function T.Stamp(frame, addon, point, x, y)
  if not (frame and frame.CreateFontString) then return nil end
  local text = T.StampText(addon)
  if not text then return nil end
  local s = frame.bisStamp
  if not s then
    s = frame:CreateFontString(nil, "OVERLAY")
    if T.SetFont then T.SetFont(s, T.STAMP.size) else s:SetFont(STANDARD_TEXT_FONT, T.STAMP.size, "") end
    frame.bisStamp = s
  end
  local r, g, b = T.rgb(T.STAMP.colour)
  s:SetTextColor(r, g, b, 1)
  s:SetAlpha(T.STAMP.alpha)
  point = point or "BOTTOMRIGHT"
  if s.SetJustifyH then s:SetJustifyH(point:find("RIGHT") and "RIGHT" or "LEFT") end
  s:ClearAllPoints()
  s:SetPoint(point, frame, point, x or (point:find("RIGHT") and -4 or 4), y or (point:find("TOP") and -3 or 3))
  s:SetText(text)
  return s
end
```
