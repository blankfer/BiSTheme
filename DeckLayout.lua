--[[
  BiSTheme / DeckLayout.lua  --  WHERE EVERYTHING GOES ON THE DECK (21 Nov 2026).

  Arn, 21 Nov: "our next big project is making bis tools a deck, this time we are going 9:16"; "from the start rezisable and
  toggles"; "unifed ui"; "i like some landcape imax 70mm and others make more sense 9:16"; "maybe landscape can scale things
  to fulll screen and portrait can be our minimized mode. everyhting smartly resizable".

  This file knows no frame and no game: T.DeckLayout(view, w, h, sw) answers a list of BOXES, each { kind, x, y, w, h, i, ... }
  in the deck's own units (x right, y DOWN from the top left). Deck.lua draws that list and nothing else, so the test can ask
  for every size, both shapes and every switch, and prove that nothing touches, nothing leaves the deck and the one big button
  is always there - without the client. (The probe deck's first phone was 9:16 and its list ran through its buttons; the
  test of the day only asked for the shape.)

  THE SHAPE IS THE SIZE: wider than tall = LANDSCAPE (1.43:1, IMAX's; it grows to full screen), else PORTRAIT (9:16, the
  minimized mode). The words keep their size; more room = more rows, more columns, more cards. Less room = the least
  important part goes (L.DROP, in order), never a smaller letter and never an overlap.

  THE VIEW is data a page handed in (Deck.lua asks it), counts only:
    { kind = "home",  cards = n or { { p = urgency, lines = n, size = "S"|"M"|"L"|nil (auto), btn = bool }, ... most urgent first }, apps = n, dock = n }
    { kind = "page",  find = true, boxes = n, tabs = n, rows = n, keys = n, big = true, hero = true, say = true, strip = true, textLines = n }
    { kind = "steps", steps = n, textLines = n, note = true, keys = n, hero = true }
    { kind = "switches", groups = { n, n, ... } }           `skip` = how far a list is scrolled (all kinds)
  SWITCHES (sw[key] == false hides): cards, apps, dock, hero, boxes, tabs, strip, say, keys, list, code.
]]
BiSTheme = BiSTheme or {}
local T = BiSTheme
if (T.DECKLAYOUT_MINOR or 0) >= 1 then return end
T.DECKLAYOUT_MINOR = 1

local L = {
  PORTRAIT = 9 / 16, LANDSCAPE = 1.43,
  MIN_W = 220, MIN_H = 300, MIN_LW = 420, MIN_LH = 294,
  PAD = 10, GAP = 4,
  STATUS = 22, CLOCK = 44, SIGNS = 66, TITLE = 24, KICK = 13,            -- the top: clock and x, the name, what it belongs to
  CARD = 48, CARD_BTN = 28, CARD_MIN_W = 210,    -- a live card; its buttons
  APP_W = 62, APP_H = 60, DOCK_H = 42, DOCK_W = 46,
  BOX_H = 36, TAB_H = 24, STRIP = 4, ROW = 24, ROW_MIN_W = 170, SAY = 14,
  BIG = 36, KEY = 24, LINK = 24,
  LINE = 18, NOTE = 15, PROG = 5,
  FOOT = 24, RAIL = 60, OUT = 32,
  RAIL_WIDE = 132, RAIL_WIDE_H = 34, RAIL_NAMES = 380, RAIL_PAGE = 640,   -- the rail says the names from this width on (home; beside a page)
  ROW2 = 38, LETTER = 6, TITLE_LETTER = 9.2, KICK_LETTER = 7,      -- a row of two lines; how wide a letter is (a row's, the title's, the kicker's)
  GRID_ROWS = 2,                                 -- a wide home is a home screen (icons with names) when this many rows of them fit under its cards
  APP_K = { 1.7, 1.4, 1.2 },                     -- the icons grow to the largest of these with which all of them still fit
  HERO_MIN = 70, HERO_SHARE = 0.28,
  MAX_CARDS = 6,
  HIT = 24,                                      -- nothing to click is smaller than this (Arn, 22 Nov: "easy for people with accessibility")
}
T.DECK_L = L

local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil

--- "portrait" or "landscape", by the size itself.
function T.DeckShape(w, h) return w > h and "landscape" or "portrait" end

--- A size the deck may have: never under the least, portrait or landscape.
function T.DeckClamp(w, h)
  if w > h then return max(w, L.MIN_LW), max(h, L.MIN_LH) end
  return max(w, L.MIN_W), max(h, L.MIN_H)
end

local function on(sw, key) return not sw or sw[key] ~= false end

--- A column being filled from both ends: `top` takes the next piece down, `bottom` the next one up; `left()` is what is free.
local function column(out, x, y, w, h)
  local c = { x = x, w = w, y0 = y, y1 = y + h, out = out }
  function c:left() return self.y1 - self.y0 end
  function c:top(kind, ph, extra)
    local b = { kind = kind, x = self.x, y = self.y0, w = self.w, h = ph }
    if extra then for k, v in pairs(extra) do b[k] = v end end
    out[#out + 1] = b
    self.y0 = self.y0 + ph + L.GAP
    return b
  end
  function c:bottom(kind, ph, extra)
    self.y1 = self.y1 - ph
    local b = { kind = kind, x = self.x, y = self.y1, w = self.w, h = ph }
    if extra then for k, v in pairs(extra) do b[k] = v end end
    out[#out + 1] = b
    self.y1 = self.y1 - L.GAP
    return b
  end
  return c
end

--- n boxes of one kind side by side inside a band.
local function spread(out, kind, n, x, y, w, h)
  if n <= 0 then return end
  local each = (w - (n - 1) * L.GAP) / n
  for i = 1, n do out[#out + 1] = { kind = kind, i = i, x = x + (i - 1) * (each + L.GAP), y = y, w = each, h = h } end
end

--- How many side-by-side pieces of at least `least` fit in w (never 0).
local function fit(n, w, least)
  return max(1, min(n, floor((w + L.GAP) / (least + L.GAP))))
end

--- The top of every view: clock left, x right; the kicker and the title. Answers the y under it.
local function head(out, x, y, w, back, sw, v)
  -- how wide the kicker is; both do not fit on one line: it goes under the title
  local function parts(room)
    if not (v and v.titleN) then return min(110, w * 0.36), false end
    local kw = min(room * 0.7, (v.kickN or 0) * L.KICK_LETTER + 4)
    return kw, v.titleN * L.TITLE_LETTER + kw + 8 > room and (v.kickN or 0) > 0
  end
  if v and v.win then                                        -- an app out on the screen: its name, whose it is, x
    local room = w - L.HIT - L.GAP
    local kw, under = parts(room)
    if under then
      out[#out + 1] = { kind = "close", x = x + w - L.HIT, y = y, w = L.HIT, h = L.TITLE }
      out[#out + 1] = { kind = "title", x = x, y = y, w = room, h = L.TITLE }
      out[#out + 1] = { kind = "kicker", x = x, y = y + L.TITLE, w = room, h = L.KICK, left = true }
      return y + L.TITLE + L.KICK + L.GAP
    end
    out[#out + 1] = { kind = "close", x = x + w - L.HIT, y = y, w = L.HIT, h = L.TITLE }
    out[#out + 1] = { kind = "kicker", x = x + w - L.HIT - L.GAP - kw, y = y + (L.TITLE - L.KICK) / 2, w = kw, h = L.KICK }
    out[#out + 1] = { kind = "title", x = x, y = y, w = w - kw - L.HIT - 3 * L.GAP, h = L.TITLE }
    return y + L.TITLE + L.GAP
  end
  -- (the signs - signal, WiFi, battery - between the grip and the two keys: DeckStatus.lua)
  local signs = on(sw, "signs") and L.SIGNS + L.GAP or 0
  local ow = v and v.out and L.OUT + L.GAP or 0              -- OUT: this app as a window of its own
  if ow > 0 and w < 236 then signs = 0 end
  out[#out + 1] = { kind = "clock", x = x, y = y, w = L.CLOCK, h = L.STATUS }
  out[#out + 1] = { kind = "grip", x = x + L.CLOCK + L.GAP, y = y, w = max(20, w - L.CLOCK - 2 * L.HIT - 4 * L.GAP - signs - ow), h = L.STATUS }
  if ow > 0 then out[#out + 1] = { kind = "out", x = x + w - 2 * L.HIT - 2 * L.GAP - signs - L.OUT, y = y, w = L.OUT, h = L.STATUS } end
  if signs > 0 then out[#out + 1] = { kind = "status", x = x + w - 2 * L.HIT - 2 * L.GAP - L.SIGNS, y = y, w = L.SIGNS, h = L.STATUS } end
  out[#out + 1] = { kind = "close", x = x + w - L.HIT, y = y, w = L.HIT, h = L.STATUS }
  out[#out + 1] = { kind = "shape", x = x + w - 2 * L.HIT - L.GAP, y = y, w = L.HIT, h = L.STATUS }
  y = y + L.STATUS + 2
  local bw = back and L.HIT + 2 or 0
  if back then out[#out + 1] = { kind = "back", x = x, y = y, w = L.HIT, h = L.TITLE } end
  local kw, under = parts(w - bw)
  if under then
    out[#out + 1] = { kind = "title", x = x + bw, y = y, w = w - bw, h = L.TITLE }
    out[#out + 1] = { kind = "kicker", x = x + bw + 2, y = y + L.TITLE, w = w - bw - 2, h = L.KICK, left = true }
    return y + L.TITLE + L.KICK + L.GAP
  end
  out[#out + 1] = { kind = "title", x = x + bw, y = y, w = w - bw - kw - 4, h = L.TITLE }
  out[#out + 1] = { kind = "kicker", x = x + w - kw, y = y + (L.TITLE - L.KICK) / 2, w = kw, h = L.KICK }
  return y + L.TITLE + L.GAP
end

--- The foot: the switches key left, the home bar middle, the faint code right. Answers the y of its top.
local function foot(out, x, bottom, w, sw, v)
  local y = bottom - L.FOOT
  if v and v.win then
    local cw = min(120, w * 0.5)
    if on(sw, "code") then out[#out + 1] = { kind = "code", x = x + w - cw - L.HIT - 4, y = y, w = cw, h = L.FOOT } end
    out[#out + 1] = { kind = "size", x = x + w - L.HIT, y = y, w = L.HIT, h = L.FOOT }
    return y - L.GAP
  end
  out[#out + 1] = { kind = "gear", x = x, y = y, w = L.HIT, h = L.FOOT }
  local cw = min(120, w * 0.36)
  out[#out + 1] = { kind = "home", x = x + L.HIT + 4, y = y, w = max(20, w - L.HIT - cw - L.HIT - 12), h = L.FOOT }
  if on(sw, "code") then out[#out + 1] = { kind = "code", x = x + w - cw - L.HIT - 4, y = y, w = cw, h = L.FOOT } end
  out[#out + 1] = { kind = "size", x = x + w - L.HIT, y = y, w = L.HIT, h = L.FOOT }
  return y - L.GAP
end

--- The apps as a grid in a band: `per` across; more than fit = pages (`more`).
-- (more icons than fit: the last place is MORE, and the next press starts where this page ended - none is out of reach)
local function pageOf(n, room, skip)
  if n <= room then return 0, n, false end
  local show = max(1, room - 1)
  local at = skip or 0
  if at >= n or at < 0 then at = 0 end
  return at, min(show, n - at), room > 1
end
local function appGrid(out, n, x, y, w, h, skip)
  if n <= 0 or h < L.APP_H then return 0 end
  local k, per, rows = 1, fit(99, w, L.APP_W), max(1, floor((h + L.GAP) / (L.APP_H + L.GAP)))
  -- (bigger icons when every one of them still fits: a bigger deck is a bigger home screen - Arn, 22 Nov: "did not reframe")
  for _, kk in ipairs(L.APP_K) do
    local pp, rr = fit(99, w, L.APP_W * kk), floor((h + L.GAP) / (floor(L.APP_H * kk) + L.GAP))
    if rr >= 1 and pp * rr >= n then k, per, rows = kk, pp, rr break end
  end
  local ah = floor(L.APP_H * k)
  local room = per * rows
  local at, show, more = pageOf(n, room, skip)
  local each = (w - (per - 1) * L.GAP) / per
  for i = 1, show + (more and 1 or 0) do
    local cx, cy = (i - 1) % per, floor((i - 1) / per)
    out[#out + 1] = { kind = i > show and "moreapps" or "app", i = i > show and show or at + i, x = x + cx * (each + L.GAP), y = y + cy * (ah + L.GAP), w = each, h = ah, k = k }
  end
  return ceil((show + (more and 1 or 0)) / per) * (ah + L.GAP)
end

--- The dock, centred.
local function dock(out, n, x, y, w)
  local show = min(n, fit(99, w - 8, L.DOCK_W))
  local each = min(L.DOCK_W + 20, (w - 8 - (show - 1) * L.GAP) / show)
  local all = show * each + (show - 1) * L.GAP
  out[#out + 1] = { kind = "dockbar", x = x, y = y, w = w, h = L.DOCK_H, under = true }
  for i = 1, show do out[#out + 1] = { kind = "dock", i = i, x = x + (w - all) / 2 + (i - 1) * (each + L.GAP), y = y + 4, w = each, h = L.DOCK_H - 8 } end
end

--- The rail of apps down the left side (landscape). Answers the x after it.
local function rail(out, n, x, y, h, skip, wide)
  local rw, rh = wide and L.RAIL_WIDE or L.RAIL - 8, wide and L.RAIL_WIDE_H or L.RAIL - 8
  local room = max(1, floor((h + L.GAP) / (rh + L.GAP)))
  local at, show, more = pageOf(n, room, skip)
  for i = 1, show + (more and 1 or 0) do
    out[#out + 1] = { kind = i > show and "moreapps" or "railapp", i = i > show and show or at + i, x = x, y = y + (i - 1) * (rh + L.GAP), w = rw, h = rh, wide = wide or nil }
  end
  return x + rw + 8
end

--- Rows filling a band from the `skip`th on (the wheel, the pad's triggers): never past the end, so the last row is always
--- reachable and the band is never half empty. Answers how many; a row knows how many there are over and under what shows.
-- A ROW WHOSE WORDS DO NOT FIT IS TWO LINES HIGH (Arn, 22 Nov: "dont like how stuff is cutoff"): `lens(i)` = how many letters it
-- says, and how much of its width its right side takes (nil = not asked, every row is one line).
local function rowList(out, kind, n, x, y, w, h, first, skip, lens)
  local function high(i)
    if not lens then return L.ROW end
    local letters, right = lens(i)
    return (letters or 0) * L.LETTER > w - 32 - (right or 0) and L.ROW2 or L.ROW
  end
  local function lies(a) local k, used = 0, 0 while a + k <= n and used + high(a + k) <= h do used = used + high(a + k) + 2 k = k + 1 end return k end
  -- never past the end: the last page starts as early as it can
  local last, used = n + 1, 0
  while last > 1 and used + high(last - 1) <= h do last = last - 1 used = used + high(last) + 2 end
  skip = max(0, min(skip or 0, last - 1))
  local show = lies(skip + 1)
  local at = y
  for i = 1, show do
    local hh = high(skip + i)
    out[#out + 1] = { kind = kind, i = (first or 0) + skip + i, x = x, y = at, w = w, h = hh, two = hh > L.ROW or nil, over = skip, under_ = n - show - skip }
    at = at + hh + 2
  end
  return show
end

-- THE VIEWS ----------------------------------------------------------------------------------------------------------

--- HOW BIG EACH CARD IS (Arn, 22 Nov: "we need to make all the tools into apps and smarty size them for live cards"): every card
--- starts S (half a row: a word and a number); the most urgent one grows to L (with its own lines) first, then everything that
--- says something now (p >= 3) to M (a row, with its buttons), then a second L - always only while the rest still fits. A size
--- asked for (`size`) is kept. Too many, or no room: the least urgent wait behind MORE. Answers the list, how many are left.
L.CARD_S, L.CARD_M, L.CARD_LINE, L.CARD_L, L.CARD_LINES, L.CARD_BIG = 44, 76, 17, 82, 3, 2
local function tall(c) return c.s == "S" and L.CARD_S or c.s == "L" and L.CARD_L + L.CARD_LINE * min(c.lines, L.CARD_LINES) - (c.btn and 0 or L.CARD_BTN) or L.CARD_M - (c.btn and 0 or L.CARD_BTN) end
local function cardsHigh(list, per)
  local y, small = 0, 0
  for _, c in ipairs(list) do if c.s == "S" then small = small + 1 else y = y + tall(c) + L.GAP end end
  return y + ceil(small / per) * (L.CARD_S + L.GAP)
end
function T.DeckCards(cards, w, room, skip)
  local list, per = {}, max(1, floor((w + L.GAP) / (106 + L.GAP)))
  for i, c in ipairs(cards) do
    if i > (skip or 0) then list[#list + 1] = { i = i, p = c.p or 5, lines = c.lines or 0, btn = c.btn ~= false, held = c.size, s = c.size or "S" } end
  end
  local rest = 0
  while #list > 0 and (#list > L.MAX_CARDS or cardsHigh(list, per) > room) do
    -- the least urgent goes; one whose size you hold only when nothing else is left to go
    local out
    for i = #list, 1, -1 do if not list[i].held then out = i break end end
    table.remove(list, out or #list)
    rest = rest + 1
  end
  local function grow(c, s)
    local was = c.s
    c.s = s
    if cardsHigh(list, per) > room then c.s = was return false end
    return true
  end
  local big = 0
  for _, c in ipairs(list) do if c.s == "L" then big = big + 1 end end
  local first = list[1]
  if first and not first.held and first.lines > 0 and first.p >= 5 and big < L.CARD_BIG and grow(first, "L") then big = big + 1 end
  for _, c in ipairs(list) do if not c.held and c.s == "S" and c.p >= 3 then grow(c, "M") end end
  for _, c in ipairs(list) do if not c.held and c.s == "M" and c.p >= 5 and c.lines > 0 and big < L.CARD_BIG and grow(c, "L") then big = big + 1 end end
  -- (nothing urgent at all: the first still gets its buttons when there is room)
  if first and not first.held and first.s == "S" then grow(first, "M") end
  return list, rest, per
end

local function home(out, v, w, h, sw)
  local x, W = L.PAD, w - 2 * L.PAD
  local y = head(out, x, 6, W, false, sw, v)
  local bottom = foot(out, x, h - 5, W, sw)
  local cards = v.cards
  if type(cards) ~= "table" then
    cards = {}
    for i = 1, v.cards or 0 do cards[i] = { p = 6 - min(i, 5), lines = 2 } end
  end
  if not on(sw, "cards") then cards = {} end
  local nCards = min(#cards, L.MAX_CARDS)
  local nApps = on(sw, "apps") and (v.apps or 0) or 0
  local nDock = on(sw, "dock") and (v.dock or 0) or 0
  if nDock > 0 and bottom - y >= L.DOCK_H + L.CARD then
    dock(out, nDock, x, bottom - L.DOCK_H, W)
    bottom = bottom - L.DOCK_H - L.GAP
  end
  if T.DeckShape(w, h) == "landscape" then
    -- A HOME SCREEN when it is tall enough (cards on top, the icons with their names under them), else cards beside a rail
    -- (Arn, 22 Nov, at 879 wide: "i gotta go this far for the shelf to open on the side to see the names plenty of room")
    local cardRows = nCards > 0 and ceil(nCards / fit(nCards, W, L.CARD_MIN_W)) or 0
    local spare = bottom - y - cardRows * (L.CARD + L.CARD_BTN + 2 * L.GAP)
    local cols, gridRows = fit(99, W, L.APP_W), floor(spare / (L.APP_H + L.GAP))
    local grid = nApps > 0 and gridRows >= 1 and (gridRows >= L.GRID_ROWS or cols * gridRows >= nApps)
    if nApps > 0 and W >= 360 and not grid then
      local nx = rail(out, nApps, x, y, bottom - y, v.appSkip, W >= L.RAIL_NAMES)
      W, x = W - (nx - x), nx
    end
    local floorY = bottom
    if grid then
      -- (what the icons need, at least two rows of them, never more than two thirds)
      local need = ceil(nApps / fit(99, W, L.APP_W)) * (L.APP_H + L.GAP)
      floorY = bottom - min(max(need, L.GRID_ROWS * (L.APP_H + L.GAP)), spare)
    end
    if nCards > 0 then
      local per = fit(nCards, W, L.CARD_MIN_W)
      local ch = L.CARD + L.CARD_BTN + L.GAP
      local rows = max(1, floor((floorY - y + L.GAP) / (ch + L.GAP)))
      local show = min(nCards, per * rows)
      local each = (W - (per - 1) * L.GAP) / per
      -- room to spare: the cards grow taller, evenly - as far as one of them has lines to show
      local used = ceil(show / per)
      local lines = 0
      for i = 1, show do lines = max(lines, cards[i].size == "M" and 0 or min(cards[i].lines or 0, L.CARD_LINES)) end
      local tall = min(L.CARD_L + L.CARD_LINE * lines, (floorY - y - (used - 1) * L.GAP) / used)
      if lines > 0 then ch = max(ch, floor(tall)) end
      for i = 1, show do
        local c = cards[i]
        local lines = c.size == "M" and 0 or min(c.lines or 0, L.CARD_LINES, max(0, floor((ch - L.CARD_L + 4) / L.CARD_LINE)))
        out[#out + 1] = { kind = "card", i = i, x = x + ((i - 1) % per) * (each + L.GAP), y = y + floor((i - 1) / per) * (ch + L.GAP), w = each, h = ch, btn = c.btn ~= false, size = lines > 0 and "L" or "M", lines = lines }
      end
      y = y + used * (ch + L.GAP)
    end
    if grid then appGrid(out, nApps, x, y + L.GAP, W, bottom - y - L.GAP, v.appSkip) end
    return
  end
  -- portrait: cards on top, then the icons: they get up to three rows, never less than one
  local appsNeed = nApps > 0 and (L.APP_H + L.GAP) or 0
  local per = fit(99, W, L.APP_W)
  local appRows = nApps > 0 and ceil(nApps / per) or 0
  local room = bottom - y - min(appRows, 3) * (L.APP_H + L.GAP)
  -- (the cards may take a row or two of icons when they need it: the icons have MORE)
  if #cards > 0 and cardsHigh((T.DeckCards(cards, W, 9999)), max(1, floor((W + L.GAP) / (106 + L.GAP)))) > room then room = bottom - y - appsNeed end
  local skip = v.cardSkip or 0
  if skip >= #cards then skip = 0 end
  local list, rest, perRow = T.DeckCards(cards, W, room, skip)
  if (rest > 0 or skip > 0) and #cards > 0 then list, rest, perRow = T.DeckCards(cards, W, room - L.ROW - L.GAP, skip) end
  local small = {}
  for _, c in ipairs(list) do
    if c.s == "S" then small[#small + 1] = c
    else
      local ch = tall(c)
      out[#out + 1] = { kind = "card", i = c.i, x = x, y = y, w = W, h = ch, btn = c.btn, size = c.s, lines = c.s == "L" and min(c.lines, L.CARD_LINES) or 0 }
      y = y + ch + L.GAP
    end
  end
  for k, c in ipairs(small) do
    local col, row = (k - 1) % perRow, floor((k - 1) / perRow)
    local inRow = min(perRow, #small - row * perRow)
    local each = (W - (inRow - 1) * L.GAP) / inRow
    out[#out + 1] = { kind = "card", i = c.i, x = x + col * (each + L.GAP), y = y + row * (L.CARD_S + L.GAP), w = each, h = L.CARD_S, btn = false, size = "S", lines = 0 }
  end
  y = y + ceil(#small / perRow) * (L.CARD_S + L.GAP)
  if (rest > 0 or skip > 0) and bottom - y >= L.ROW + L.GAP + (appsNeed > 0 and appsNeed or 0) then
    out[#out + 1] = { kind = "morecards", i = rest, n = #list, x = x, y = y, w = W, h = L.ROW }
    y = y + L.ROW + L.GAP
  end
  appGrid(out, nApps, x, y, W, bottom - y, v.appSkip)
end

--- The right side of a page (or the bottom of a tall one): the big button over its keys, from the bottom up.
local function actions(c, v, sw)
  local nk = on(sw, "keys") and (v.keys or 0) or 0
  if nk > 0 and c:left() >= L.KEY + L.BIG + 2 * L.GAP then
    local per = fit(nk, c.w, 64)
    local y = c.y1 - L.KEY
    c.y1 = y - L.GAP
    spread(c.out, "key", min(nk, per), c.x, y, c.w, L.KEY)
  end
  if v.big then c:bottom("big", L.BIG) end
end

local function page(out, v, w, h, sw)
  local x, W = L.PAD, w - 2 * L.PAD
  local y = head(out, x, 6, W, true, sw, v)
  local bottom = foot(out, x, h - 5, W, sw, v)
  local nb = on(sw, "boxes") and (v.boxes or 0) or 0
  local nt = on(sw, "tabs") and (v.tabs or 0) or 0
  local hero = v.hero and on(sw, "hero")
  if T.DeckShape(w, h) == "landscape" then
    if (v.apps or 0) > 0 and W >= 560 then
      local nx = rail(out, v.apps, x, y, bottom - y, v.appSkip, W >= L.RAIL_PAGE)
      W, x = W - (nx - x), nx
    end
    -- the list left, the detail right
    local lw = (v.rows or 0) > 0 and max(L.ROW_MIN_W, floor(W * (W >= 620 and 0.40 or 0.46))) or 0
    if lw > 0 then
      local c = column(out, x, y, lw, bottom - y)
      if nt > 0 then local ty = c.y0 c.y0 = ty + L.TAB_H + L.GAP spread(out, "tab", nt, x, ty, lw, L.TAB_H) end
      if v.find then c:top("find", L.TAB_H) end
      if v.strip and on(sw, "strip") then c:top("strip", L.STRIP) end
      if v.say and on(sw, "say") then c:bottom("say", L.SAY) end
      rowList(out, "row", v.rows, x, c.y0, lw, c:left(), 0, v.skip, v.lens)
      x, W = x + lw + L.GAP * 2, W - lw - L.GAP * 2
    end
    local c = column(out, x, y, W, bottom - y)
    actions(c, v, sw)
    if lw == 0 then                                          -- (no list: its tabs and its search stand over the words)
      if nt > 0 and c:left() >= L.TAB_H then local ty = c.y0 c.y0 = ty + L.TAB_H + L.GAP spread(out, "tab", nt, x, ty, W, L.TAB_H) end
      if v.find and c:left() >= L.TAB_H then c:top("find", L.TAB_H) end
    end
    if nb > 0 and c:left() >= L.BOX_H then
      local per = fit(nb, W, 62)
      local by = c.y0
      c.y0 = by + L.BOX_H + L.GAP
      spread(out, "box", min(nb, per), x, by, W, L.BOX_H)
    end
    if (v.textLines or 0) > 0 and c:left() >= L.LINE + 8 then c:top("text", min(v.textLines * L.LINE + 8, c:left() - (hero and L.HERO_MIN or 0) > L.LINE + 8 and c:left() - (hero and L.HERO_MIN or 0) or c:left())) end
    if hero and c:left() >= L.HERO_MIN then c:top("hero", c:left()) end
    return
  end
  local c = column(out, x, y, W, bottom - y)
  actions(c, v, sw)
  if v.say and on(sw, "say") and c:left() >= L.SAY + 4 * (L.ROW + 2) then c:bottom("say", L.SAY) end
  -- what the list needs to be worth having; the picture takes what is over
  local need = (v.rows or 0) > 0 and 4 * (L.ROW + 2) or 0
  local mids = (nb > 0 and L.BOX_H + L.GAP or 0) + (nt > 0 and L.TAB_H + L.GAP or 0) + (v.find and L.TAB_H + L.GAP or 0) + ((v.strip and on(sw, "strip")) and L.STRIP + L.GAP or 0)
  if hero then
    local room = c:left() - need - mids
    if room >= L.HERO_MIN then c:top("hero", min(floor(h * L.HERO_SHARE), room - L.GAP)) end
  end
  if nb > 0 and c:left() >= L.BOX_H + need then
    local by = c.y0
    c.y0 = by + L.BOX_H + L.GAP
    spread(out, "box", min(nb, fit(nb, W, 56)), x, by, W, L.BOX_H)
  end
  if nt > 0 then
    local ty = c.y0
    c.y0 = ty + L.TAB_H + L.GAP
    spread(out, "tab", nt, x, ty, W, L.TAB_H)
  end
  if v.find and c:left() >= L.TAB_H then c:top("find", L.TAB_H) end
  if v.strip and on(sw, "strip") then c:top("strip", L.STRIP) end
  if (v.textLines or 0) > 0 and c:left() >= L.LINE + 8 then c:top("text", min(v.textLines * L.LINE + 8, c:left())) end
  if (v.rows or 0) > 0 and c:left() >= L.ROW then
    -- a wide portrait deck lists in two columns
    if W >= 2 * L.ROW_MIN_W + 160 then
      local half = (W - L.GAP) / 2
      local room = max(1, floor((c:left() + 2) / (L.ROW + 2)))
      local skip = max(0, min(v.skip or 0, v.rows - 2 * room))
      rowList(out, "row", min(v.rows - skip, room), x, c.y0, half, c:left(), skip)
      if v.rows - skip > room then rowList(out, "row", min(v.rows - skip - room, room), x + half + L.GAP, c.y0, half, c:left(), skip + room) end
    else
      rowList(out, "row", v.rows, x, c.y0, W, c:left(), 0, v.skip, v.lens)
    end
  end
end

--- One step at a time (the probe deck's flow): the progress, the card (its words, its button, back / skip / next), the list.
local function stepCard(out, c, v, sw)
  local inner = 8
  local lines = max(1, min(v.textLines or 2, 5))
  local noteH = v.note and L.NOTE + 2 or 0
  local nk = min(v.keys or 0, 3)
  local need = inner + L.NOTE + 4 + lines * L.LINE + noteH + L.BIG + L.GAP + (nk > 0 and L.KEY + L.GAP or 0) + L.LINK + inner
  while need > c:left() and lines > 1 do lines, need = lines - 1, need - L.LINE end
  if need > c:left() and noteH > 0 then need, noteH = need - noteH, 0 end
  if need > c:left() and nk > 0 then need, nk = need - L.KEY - L.GAP, 0 end
  local x, w = c.x + inner, c.w - 2 * inner
  local y = c.y0 + inner
  out[#out + 1] = { kind = "stepcard", x = c.x, y = c.y0, w = c.w, h = need, under = true }
  out[#out + 1] = { kind = "stephead", x = x, y = y, w = w, h = L.NOTE }
  y = y + L.NOTE + 4
  out[#out + 1] = { kind = "steptext", x = x, y = y, w = w, h = lines * L.LINE, lines = lines }
  y = y + lines * L.LINE
  if noteH > 0 then out[#out + 1] = { kind = "stepnote", x = x, y = y, w = w, h = L.NOTE } y = y + noteH end
  out[#out + 1] = { kind = "big", x = x, y = y, w = w, h = L.BIG }
  y = y + L.BIG + L.GAP
  if nk > 0 then spread(out, "key", nk, x, y, w, L.KEY) y = y + L.KEY + L.GAP end
  spread(out, "link", 3, x, y, w, L.LINK)
  c.y0 = c.y0 + need + L.GAP
end

local function steps(out, v, w, h, sw)
  local x, W = L.PAD, w - 2 * L.PAD
  local y = head(out, x, 6, W, true, sw, v)
  local bottom = foot(out, x, h - 5, W, sw, v)
  local list = on(sw, "list")
  if T.DeckShape(w, h) == "landscape" then
    local lw = list and max(L.ROW_MIN_W, floor(W * 0.40)) or 0
    out[#out + 1] = { kind = "progress", x = x, y = y, w = W, h = L.PROG }
    y = y + L.PROG + L.GAP
    if list then
      rowList(out, "step", v.steps or 0, x, y, lw, bottom - y, 0, v.skip, v.lens)
      x, W = x + lw + 2 * L.GAP, W - lw - 2 * L.GAP
    end
    local c = column(out, x, y, W, bottom - y)
    stepCard(out, c, v, sw)
    if v.hero and on(sw, "hero") and c:left() >= L.HERO_MIN then c:top("hero", c:left()) end
    return
  end
  local c = column(out, x, y, W, bottom - y)
  c:top("progress", L.PROG)
  local lineCard = 8 + L.NOTE + 4 + min(v.textLines or 2, 5) * L.LINE + (v.note and L.NOTE + 2 or 0) + L.BIG + L.GAP + L.LINK + 8 + ((v.keys or 0) > 0 and L.KEY + L.GAP or 0)
  if v.hero and on(sw, "hero") then
    local room = c:left() - lineCard - L.GAP - (list and 3 * (L.ROW + 2) or 0)
    if room >= L.HERO_MIN then c:top("hero", min(floor(h * L.HERO_SHARE), room - L.GAP)) end
  end
  stepCard(out, c, v, sw)
  if list and c:left() >= L.ROW then rowList(out, "step", v.steps or 0, x, c.y0, W, c:left(), 0, v.skip, v.lens) end
end

--- The switches: presets, a group head and its rows, the size sliders at the bottom.
local function switches(out, v, w, h, sw)
  local x, W = L.PAD, w - 2 * L.PAD
  local y = head(out, x, 6, W, true, sw, v)
  local bottom = foot(out, x, h - 5, W, sw, v)
  local c = column(out, x, y, W, bottom - y)
  local py = c.y0
  c.y0 = py + L.KEY + L.GAP
  spread(out, "preset", 3, x, py, W, L.KEY)
  c:bottom("slider", L.ROW, { i = 2 })
  c:bottom("slider", L.ROW, { i = 1 })
  -- the rows flow down, then into the next column
  local all = {}
  for g, n in ipairs(v.groups or {}) do
    all[#all + 1] = { head = g }
    for i = 1, n do all[#all + 1] = { group = g, i = i } end
  end
  local cols = fit(4, W, 200)
  local each = (W - (cols - 1) * L.GAP) / cols
  local col, yy = 0, c.y0
  -- what does not fit is one press away: the last place says MORE (the wheel and the pad's triggers do the same)
  local skip = max(0, min(v.skip or 0, #all - 1))
  for k = skip + 1, #all do
    local a = all[k]
    local ph = a.head and L.NOTE or L.ROW
    if yy + ph > c.y1 then col, yy = col + 1, c.y0 end
    local lastCol = col == cols - 1
    local rest = #all - k
    if col >= cols or yy + ph > c.y1 or (lastCol and rest > 0 and yy + ph + 2 + L.ROW > c.y1) then
      col = min(col, cols - 1)
      local ry = min(yy, c.y1 - L.ROW)
      if col < cols and ry >= c.y0 then out[#out + 1] = { kind = "more", i = k - skip - 1, x = x + col * (each + L.GAP), y = ry, w = each, h = L.ROW } end
      break
    end
    out[#out + 1] = { kind = a.head and "swhead" or "switch", group = a.head or a.group, i = a.i, x = x + col * (each + L.GAP), y = yy, w = each, h = ph }
    yy = yy + ph + 2
  end
end

local VIEWS = { home = home, page = page, steps = steps, switches = switches }

--- The boxes of a view at a size. The size is clamped first; the second and third answers say what it became.
function T.DeckLayout(view, w, h, sw)
  w, h = T.DeckClamp(w, h)
  local out = {}
  local fn = VIEWS[view and view.kind or "home"] or home
  fn(out, view or {}, w, h, sw)
  return out, w, h
end
