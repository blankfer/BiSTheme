-- BiSTheme / dev / decklayout.lua -- the deck at every size, both shapes, every switch: nothing touches, nothing leaves.
--   cd BiSTheme && lua5.1 dev/decklayout.lua
BiSTheme = nil
assert(loadfile("DeckLayout.lua"))()
local T = BiSTheme
local L = T.DECK_L
local n, fails, said = 0, 0, {}
local function ok(c, what, seen)
  n = n + 1
  if c then return end
  fails = fails + 1
  if not said[what] then said[what] = true print("FAIL: " .. what .. "  " .. tostring(seen)) end
end

local VIEWS = {
  home = { kind = "home", cards = 5, apps = 12, dock = 5 },
  homeSized = { kind = "home", cards = { { p = 9, lines = 3 }, { p = 6, lines = 2, size = "L" }, { p = 4, size = "S" }, { p = 4, lines = 9, btn = false }, { p = 2 }, { p = 1, size = "M" }, { p = 1 }, { p = 0.5 } }, apps = 22, dock = 5 },
  homeBare = { kind = "home", cards = 0, apps = 3, dock = 0 },
  homeMany = { kind = "home", cards = 12, apps = 40, dock = 9 },
  bosses = { kind = "page", boxes = 3, tabs = 2, rows = 21, keys = 2, big = true, hero = true, say = true, strip = true, apps = 12 },
  sounds = { kind = "page", find = true, boxes = 2, tabs = 3, rows = 60, keys = 2, big = true, apps = 12 },
  long = { kind = "page", say = true, sayN = 130, rows = 30, keys = 2, big = true, apps = 12, titleN = 14, kickN = 18, lens = function(i) return i % 3 == 0 and 60 or 8, 40 end },
  tour = { kind = "steps", steps = 2, textLines = 3, note = true, titleN = 9, kickN = 15, lens = function() return 95, 8 end },
  huge = { kind = "page", say = true, rows = 9, keys = 2, apps = 12, lens = function(i) return 400, 40 end },
  number = { kind = "page", number = true, hero = true, icons = { 4, 3 }, rows = 8, tabs = 4, keys = 3, big = true, say = true, apps = 12 },
  numberOpen = { kind = "page", number = true, hero = true, icons = { 4, 4 }, boxes = 8, rows = 8, tabs = 4, keys = 3, big = true, say = true, apps = 12 },
  subs = { kind = "page", say = true, rows = 30, boxes = 4, tabs = 4, keys = 2, apps = 12, lens = function(i) return 8, 40, i % 4 > 0 or nil end },
  longSteps = { kind = "steps", steps = 9, textLines = 2, titleN = 30, kickN = 18, lens = function(i) return i % 2 == 0 and 70 or 8, 40 end },
  outLong = { kind = "page", win = true, rows = 12, titleN = 14, kickN = 18, lens = function() return 70, 0 end },
  many = { kind = "page", boxes = 8, tabs = 4, rows = 12, keys = 3, big = true, apps = 12 },
  alone = { kind = "page", find = true, boxes = 0, tabs = 2, rows = 0, keys = 0, textLines = 2, apps = 12 },
  short = { kind = "page", boxes = 0, tabs = 0, rows = 2, keys = 0, big = true, apps = 12 },
  text = { kind = "page", boxes = 4, tabs = 0, rows = 0, keys = 3, big = true, textLines = 9, hero = true, apps = 12 },
  full = { kind = "page", boxes = 6, tabs = 4, rows = 60, keys = 5, big = true, hero = true, say = true, strip = true, textLines = 3, apps = 30 },
  steps = { kind = "steps", steps = 24, textLines = 4, note = true, keys = 3, hero = true },
  stepsBare = { kind = "steps", steps = 1, textLines = 1 },
  switches = { kind = "switches", groups = { 12, 4, 9, 6 } },
}
local SW = { "cards", "apps", "dock", "hero", "boxes", "tabs", "strip", "say", "keys", "list", "code" }

local SIZES = {}
for w = L.MIN_W, 560, 34 do for _, k in ipairs({ 1.2, 16 / 9, 2.1 }) do SIZES[#SIZES + 1] = { w, math.floor(w * k) } end end
for h = L.MIN_LH, 1000, 58 do for _, k in ipairs({ 1.05, 1.43, 16 / 9, 21 / 9 }) do SIZES[#SIZES + 1] = { math.floor(h * k) + 1, h } end end
SIZES[#SIZES + 1] = { 100, 100 }        -- smaller than the least: clamped
SIZES[#SIZES + 1] = { 300, 120 }

local function sets()
  local out = { {} }                                     -- all on
  for _, k in ipairs(SW) do out[#out + 1] = { [k] = false } end     -- one off
  local none = {} for _, k in ipairs(SW) do none[k] = false end
  out[#out + 1] = none                                   -- all off
  for a = 1, 6 do local s = {} for i, k in ipairs(SW) do if (i * a) % 3 == 0 then s[k] = false end end out[#out + 1] = s end
  return out
end
local SETS = sets()

local function hit(a, b)
  local e = 0.01
  return a.x + a.w > b.x + e and b.x + b.w > a.x + e and a.y + a.h > b.y + e and b.y + b.h > a.y + e
end

local laid = 0
local CLICKS = { status = 1, morecards = 1, close = 1, shape = 1, gear = 1, back = 1, home = 1, card = 1, app = 1, railapp = 1, dock = 1, tab = 1, row = 1, big = 1, key = 1, link = 1, step = 1, preset = 1, switch = 1, size = 1, more = 1, appprev = 1, appnext = 1 }
for name, v in pairs(VIEWS) do
  for _, size in ipairs(SIZES) do
    for _, sw in ipairs(SETS) do
      local boxes, w, h = T.DeckLayout(v, size[1], size[2], sw)
      laid = laid + 1
      local where = name .. " " .. w .. "x" .. h
      local big, heads = 0, 0
      for i, b in ipairs(boxes) do
        if b.w <= 0 or b.h <= 0 then ok(false, "a box has a size: " .. b.kind, where) end
        if b.x < 0 or b.y < 0 or b.x + b.w > w + 0.01 or b.y + b.h > h + 0.01 then ok(false, "inside the deck: " .. b.kind, where .. " " .. b.x .. "," .. b.y .. " " .. b.w .. "x" .. b.h) end
        if not b.under then
          for j = i + 1, #boxes do
            local o = boxes[j]
            if not o.under and hit(b, o) then ok(false, "nothing touches: " .. b.kind .. " and " .. o.kind, where) end
          end
        end
        if b.kind == "big" then big = big + 1 ok(b.w >= 120, "the big button is big", where .. " " .. b.w) end
        if b.kind == "title" then heads = heads + 1 end
        -- EASY TO HIT (Arn, 22 Nov): 22 high and 24 wide at least, before the deck's own 1.25
        if CLICKS[b.kind] then ok(b.w >= 20 and b.h >= 22, "easy to hit: " .. b.kind, where .. " " .. b.w .. "x" .. b.h) end
        if b.kind == "row" or b.kind == "step" then ok(b.w >= 160 and (b.h == L.ROW or b.two and b.lines <= L.ROW_LINES and b.h == L.ROW + (b.lines - 1) * L.LINE2), "a row can be read", where .. " " .. b.w) end
        if b.kind == "app" or b.kind == "railapp" then ok(b.w >= (b.bare and 34 or 44) and b.h >= (b.bare and 34 or b.wide and 32 or 46), "an app can be clicked", where .. " " .. b.w) end
        if b.kind == "key" or b.kind == "tab" then ok(b.w >= 40, "a key can be clicked: " .. b.kind, where .. " " .. b.w) end
        if b.kind == "box" then ok(b.w >= 40, "a number box can be read", where .. " " .. b.w) end
      end
      ok(heads == 1, "every view has its title", where)
      if v.kind == "steps" or (v.kind == "page" and v.big) then ok(big == 1, "the one big button is always there", where .. " " .. big) end
      ok(#boxes > 4, "something is drawn", where)
    end
  end
end

-- HOW BIG A CARD IS (22 Nov: "smarty size them for live cards")
do
  local function sizes(cards, wide, room)
    local list, rest = T.DeckCards(cards, wide, room)
    local s = ""
    for _, c in ipairs(list) do s = s .. c.s end
    return s, rest, list
  end
  local quiet = { { p = 1 }, { p = 1 } }
  ok(sizes(quiet, 260, 600) == "MS", "nothing urgent: small, the first keeps its buttons", (sizes(quiet, 260, 600)))
  local busy = { { p = 9, lines = 3 }, { p = 6, lines = 2 }, { p = 5, lines = 2 }, { p = 4 }, { p = 2 }, { p = 1 } }
  ok(sizes(busy, 260, 900) == "LLMMSS", "room for all: two large, the ones that say something medium, the quiet ones small", (sizes(busy, 260, 900)))
  ok(sizes(busy, 260, 300):sub(1, 1) == "L", "little room: the most urgent is large first", (sizes(busy, 260, 300)))
  for room = 60, 700, 10 do
    for _, wide in ipairs({ 200, 260, 380 }) do
      local s, rest, list = sizes(busy, wide, room)
      local per = math.max(1, math.floor((wide + 4) / 110))
      local y, small, big = 0, 0, 0
      for _, c in ipairs(list) do if c.s == "S" then small = small + 1 else if c.s == "L" then big = big + 1 end y = y + (c.s == "L" and 82 + 17 * math.min(3, c.lines) or 76) + 4 end end
      ok(y + math.ceil(small / per) * 48 <= room and big <= 2 and #list + rest == 6, "never more than fits, never more than two large, none lost", s .. " " .. room .. " " .. rest)
      for i = 2, #list do ok(list[i].i > list[i - 1].i, "in their order", s) end
      if #list > 0 then ok(list[1].i == 1, "the most urgent is always there", s) end
    end
  end
  ok(sizes({ { p = 9, lines = 3, size = "S" }, { p = 1, size = "L", lines = 2 } }, 260, 900) == "SL", "a size you hold is kept")
  local many = {}
  for i = 1, 11 do many[i] = { p = 5, lines = 1 } end
  local s, rest = sizes(many, 260, 2000)
  ok(#s == 6 and rest == 5, "six at most", #s .. " " .. rest)
  -- MORE reaches every one
  for _, size in ipairs({ { 220, 391 }, { 280, 498 }, { 300, 700 }, { 220, 300 } }) do
    local got, at = {}, 0
    for _ = 1, 30 do
      local more
      for _, b in ipairs((T.DeckLayout({ kind = "home", cards = many, apps = 12, dock = 5, cardSkip = at }, size[1], size[2]))) do
        if b.kind == "card" then got[b.i] = true elseif b.kind == "morecards" then more = b end
      end
      if not more then break end
      at = at + math.max(1, more.n)
      if at >= 11 then break end
    end
    local gone = 0 for i = 1, 11 do if not got[i] then gone = gone + 1 end end
    ok(gone == 0 or size[2] == 300, "every card can be reached by MORE", size[1] .. "x" .. size[2] .. " missing " .. gone)
  end
end

-- portrait and landscape, by the size
ok(T.DeckShape(324, 576) == "portrait" and T.DeckShape(858, 600) == "landscape", "the shape is the size")
-- more room = more rows; the words never change size
local function count(v, w, h, kind) local c = 0 for _, b in ipairs((T.DeckLayout(v, w, h))) do if b.kind == kind then c = c + 1 end end return c end
ok(count(VIEWS.bosses, 324, 700, "row") > count(VIEWS.bosses, 324, 500, "row"), "taller: more rows")
ok(count(VIEWS.home, 324, 800, "card") >= count(VIEWS.home, 324, 480, "card"), "taller: no fewer cards")
ok(count(VIEWS.homeMany, 900, 630, "card") >= count(VIEWS.homeMany, 324, 576, "card") , "landscape: no fewer cards", count(VIEWS.homeMany, 900, 630, "card") .. " " .. count(VIEWS.homeMany, 324, 576, "card"))
ok(count(VIEWS.bosses, 858, 600, "row") > 0 and count(VIEWS.bosses, 858, 600, "hero") == 1, "landscape: the list and the big picture, side by side")
ok(count(VIEWS.bosses, 324, 576, "hero") == 1 and count(VIEWS.bosses, 300, 330, "hero") == 0, "portrait: the picture goes first when there is no room")
-- IT REFRAMES (Arn, 22 Nov, his 637 x 636: one card, eight letters down the side, the rest empty)
do
  local v = { kind = "home", cards = { { p = 4, lines = 0, btn = true } }, apps = 24, dock = 0 }
  local function kinds(w, h) local c, far, boxes = {}, 0, T.DeckLayout(v, w, h) for _, b in ipairs(boxes) do c[b.kind] = (c[b.kind] or 0) + 1 if b.kind == "app" or b.kind == "railapp" then far = math.max(far, b.y + b.h) c.k, c.hh = b.k, b.h end if b.kind == "card" then c.cardH = b.h end end return c, far end
  local c, far = kinds(637, 636)
  ok(c.app == 24 and not c.railapp and not c.appnext, "637 x 636: every icon with its name, no rail", tostring(c.app))
  ok(c.k and c.k > 1 and far > 636 * 0.6, "and they fill it: bigger icons", tostring(c.k) .. " to " .. far)
  ok(c.cardH <= 84, "a card with nothing more to say does not grow", c.cardH)
  c = kinds(879, 411) ok(c.app == 24 and not c.railapp and not c.appnext, "879 x 411: every icon with its name", tostring(c.app))
  c = kinds(600, 420) ok(c.app == 24, "600 x 420: the same", tostring(c.app))
  -- crowded: the rail, with the names even at the smallest
  v.cards = {} for i = 1, 6 do v.cards[i] = { p = 5, lines = 0, btn = true } end
  for _, z in ipairs({ { 420, 294 }, { 600, 380 } }) do
    local names, icons = 0, 0
    for _, b in ipairs((T.DeckLayout(v, z[1], z[2]))) do if b.kind == "railapp" then icons = icons + 1 if b.wide then names = names + 1 end end end
    ok(icons > 3 and names == icons, "crowded: the rail says the names at " .. z[1], names .. "/" .. icons)
  end
  v.cards = { { p = 4, lines = 0, btn = true } }
  -- (Arn's 260 x 462 with three cards: "there is room for a lot more apps there")
  v.apps, v.cards = 29, { { p = 8, lines = 3, btn = true }, { p = 5, lines = 2, btn = true }, { p = 4, lines = 0, btn = true } }
  local all = kinds(260, 462)
  ok(all.app == 29 and not all.appnext, "260 x 462, three cards: all 29 on one page", tostring(all.app))
  local some = T.DeckLayout(v, 260, 462, { small = false })
  local named, bare = 0, 0
  for _, b in ipairs(some) do if b.kind == "app" then if b.bare then bare = bare + 1 else named = named + 1 end end end
  ok(bare == 0 and named >= 5, "small icons off: with their names, and pages", named)
  v.cards = {} for _, b in ipairs((T.DeckLayout(v, 300, 620))) do if b.kind == "app" then ok(not b.bare, "room enough: with their names") break end end
end
-- NOTHING IS CUT OFF (Arn, 22 Nov, "more stuff cut off": "Ragefire Cha..." and "FIRST TIME HE..." side by side at 260)
do
  local function at(v, w, h, kind) for _, b in ipairs((T.DeckLayout(v, w, h))) do if b.kind == kind then return b end end end
  local ti, ki = at(VIEWS.long, 260, 462, "title"), at(VIEWS.long, 260, 462, "kicker")
  ok(ti.w >= 14 * L.TITLE_LETTER and ki.w >= 18 * L.KICK_LETTER and ki.y >= ti.y + ti.h, "both do not fit: the kicker stands under the title, whole", ti.w .. " " .. ki.w)
  local short = { kind = "page", rows = 2, titleN = 5, kickN = 9 }
  ti, ki = at(short, 260, 462, "title"), at(short, 260, 462, "kicker")
  ok(ki.y < ti.y + ti.h and ki.w >= 9 * L.KICK_LETTER, "both fit: one line")
  local two, one = 0, 0
  for _, b in ipairs((T.DeckLayout(VIEWS.long, 260, 462))) do if b.kind == "row" then if b.two then two = two + 1 else one = one + 1 end end end
  ok(two >= 2 and one >= 4, "a long row: two lines; a short one: one", two .. " " .. one)
end
-- NOTHING IS OUT OF REACH (22 Nov: the accessibility switches did not fit, and nothing led to them): every row, step and
-- switch comes up at some scroll, at the smallest size and the everyday one
for _, size in ipairs({ { L.MIN_W, L.MIN_H }, { 300, 533 }, { L.MIN_LW, L.MIN_LH }, { 600, 420 }, { 560, 900 } }) do
  for name, v in pairs({ bosses = VIEWS.bosses, full = VIEWS.full, steps = VIEWS.steps, long = VIEWS.long, longSteps = VIEWS.longSteps }) do
    local seen, kind, n2 = {}, v.kind == "steps" and "step" or "row", v.kind == "steps" and v.steps or v.rows
    local any = false
    for skip = 0, n2 do
      local view = {} for k, x in pairs(v) do view[k] = x end
      view.skip = skip
      for _, b in ipairs((T.DeckLayout(view, size[1], size[2]))) do if b.kind == kind then seen[b.i] = true any = true ok(b.i >= 1 and b.i <= n2, "a row that is there", b.i) end end
    end
    local miss = 0
    for i = 1, n2 do if not seen[i] then miss = miss + 1 end end
    ok(not any or miss == 0, "every row can be reached: " .. name, size[1] .. "x" .. size[2] .. " missing " .. miss)
  end
  for _, n2 in ipairs({ 1, 12, 40 }) do
    local got, at = {}, 0
    for _ = 1, 60 do
      local more
      for _, b in ipairs((T.DeckLayout({ kind = "home", find = true, cards = 5, apps = n2, dock = 5, appSkip = at }, size[1], size[2]))) do
        if b.kind == "app" or b.kind == "railapp" then got[b.i] = true ok(b.i >= 1 and b.i <= n2, "an icon that is there", b.i) elseif b.kind == "appnext" and b.i < b.n then more = b.room end
      end
      if not more then break end
      at = at + more
      if at >= n2 then break end
    end
    local gone = 0
    for i = 1, n2 do if not got[i] then gone = gone + 1 end end
    ok(gone == 0, "every icon can be reached by >", size[1] .. "x" .. size[2] .. " of " .. n2 .. " missing " .. gone)
  end
  local groups, seen, skip = { 2, 12, 4, 9, 6 }, {}, 0
  for _ = 1, 60 do
    local more
    for _, b in ipairs((T.DeckLayout({ kind = "switches", groups = groups, skip = skip }, size[1], size[2]))) do
      if b.kind == "switch" then seen[b.group .. ":" .. b.i] = true elseif b.kind == "more" then more = b.i end
    end
    if not more or more <= 0 then break end
    skip = skip + more
  end
  local miss = 0
  for g, k in ipairs(groups) do for i = 1, k do if not seen[g .. ":" .. i] then miss = miss + 1 end end end
  ok(miss == 0, "every switch can be reached by MORE", size[1] .. "x" .. size[2] .. " missing " .. miss)
end

-- a layout is cheap: no more boxes than a screen can hold
local most = 0
for _, v in pairs(VIEWS) do for _, s in ipairs(SIZES) do most = math.max(most, #(T.DeckLayout(v, s[1], s[2]))) end end
ok(most <= 220, "never a crowd of boxes", most)

print(string.format("== deck layout %s (%d layouts, %d checks, most %d boxes)", fails == 0 and "ok" or ("FAILED " .. fails), laid, n, most))
os.exit(fails == 0 and 0 or 1)
