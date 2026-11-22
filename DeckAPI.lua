--[[
  BiSTheme / DeckAPI.lua  --  THE PUBLIC DOOR: ANY ADDON'S APP ON THE DECK (22 Nov 2026).

  Arn, 22 Nov: "We make the api public if people want to put their own information into their phone. It's like curseforge inside
  wow forever".

  FOR ANOTHER ADDON'S AUTHOR, all of it:
    if BiSDeckAPI and BiSDeckAPI.major == 1 then
      local app, why = BiSDeckAPI.Register("MyAddon", {
        key = "main", name = "My Addon", icon = "My", about = "What it does, in one line.",
        page = { title = fn, kicker = fn, text = fn, boxes = fn -> { { "WORD", value } }, tabs = fn -> { "ONE", "TWO" },
                 rows = fn(tab) -> { { text, right, mark, tip, done, act = { word, fn } } }, big = fn -> { word, fn }, keys = fn -> { { word, fn } } },
        card = { when = "use" | "news", prio = fn -> 1..5 or nil, lines = fn -> { "TITLE", "", "the words", "the value" }, buttons = fn -> { { word, fn } } },
        badge = fn -> number,
      })
      app:Dirty()                                        -- something changed: painted at the next beat, only while shown
      app:Added()                                        -- did the player put it on their deck?
    end
  Call it at PLAYER_LOGIN. `MyAddon` is your addon's folder name. Two apps an addon at most.

  WHAT A GUEST GETS AND DOES NOT GET
   - It is on nobody's home screen until the player presses ADD in Apps > STORE ("from <addon>" stands on it, always).
   - DATA ONLY: words, numbers, plain functions behind buttons. No frames, no colours, no macros, spells or items, no place in the
     order, no look of ours. Only the fields above are read, copied and cut to length.
   - Every function is called protected; three errors and the app is parked, with its own addon's name in the error.
   - Its card never outranks ours (prio 5 at most) and can be pulled out, switched to AFTER USE / BY ITSELF / NEVER, or removed.
   - It can not take an app of ours, or of another addon.
  ANSWERS: nil and why = "addon" (not a loaded addon's name) | "ours" | "key" | "name" | "page" | "too many" | "not ready".
]]
BiSTheme = BiSTheme or {}
local T = BiSTheme
local D = T.Deck
if not D or not T.DECK_READY then return end
local MINOR = 1
if (T.DECKAPI_MINOR or 0) >= MINOR then return end
T.DECKAPI_MINOR = MINOR

local API = _G.BiSDeckAPI or {}
_G.BiSDeckAPI = API
API.major, API.version = 1, MINOR
API.MOST = 2                                              -- apps an addon
API.PRIO = 5                                              -- a guest's card, at most

local OURS = { BiSDeck = true, BiSProbe = true, BiSGuides = true, BiSTheme = true }
for _, c in ipairs(D.CATALOG or {}) do OURS[c[1]] = true end
local function loaded(name)
  local A = C_AddOns
  if not (A and A.IsAddOnLoaded) then return true end
  local ok, is = pcall(A.IsAddOnLoaded, name)
  return ok and is and true or false
end
--- Words on the deck: plain, one line, cut; a colour code or a texture in them is taken out.
local function words(v, most)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  if type(v) ~= "string" and type(v) ~= "number" then return nil end
  local s = tostring(v):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|[TAHhtnK].-|[tah]", ""):gsub("[|%c]", " ")
  return s:sub(1, most)
end
local function button(b)
  if type(b) ~= "table" or type(b.fn) ~= "function" then return nil end
  return { word = words(b.word, 16) or "OK", fn = b.fn, peek = b.peek == true, tip = words(b.tip, 120) }
end
local function list(v, most, each)
  local out = {}
  for i, x in ipairs(type(v) == "table" and v or {}) do
    if #out >= most then break end
    local y = each(x, i)
    if y ~= nil then out[#out + 1] = y end
  end
  return out
end
local INK = { ink = true, ink2 = true, dim = true, good = true, gold = true, warn = true, accent = true }
local function ink(v) return INK[v] and v or nil end
local function fn(v) return type(v) == "function" and v or nil end

--- A shallow copy: their table may change later, ours does not.
local function keep(t)
  local out = {}
  for k, v in pairs(type(t) == "table" and t or {}) do out[k] = v end
  return out
end
--- The guest's own table is never kept: a new one, of the fields we know, each answer cut to what may stand there.
local function copy(addon, def)
  def = keep(def)
  local p, c = type(def.page) == "table" and keep(def.page) or nil, type(def.card) == "table" and keep(def.card) or nil
  local out = { owner = addon, guest = true, key = def.key, name = words(def.name, 16), icon = words(def.icon, 2) or words(def.name, 2), about = words(def.about, 200) or "", order = 500,
    badge = fn(def.badge) and function() local n = def.badge() return type(n) == "number" and n or nil end }
  if type(p) == "table" then
    local function text(f, most) return fn(f) and function() return words(f(), most) end or nil end
    out.page = { title = text(p.title, 24), text = text(p.text, 400), say = text(p.say, 60),
      kicker = function() return words(fn(p.kicker) and p.kicker() or nil, 20) or ("from " .. addon) end,
      boxes = fn(p.boxes) and function() return list(p.boxes(), 6, function(b) return type(b) == "table" and { words(b[1], 10) or "", words(b[2], 10) or "", ink(b[3]) } or nil end) end,
      tabs = fn(p.tabs) and function() return list(p.tabs(), 4, function(t) return words(t, 14) or "" end) end,
      rows = fn(p.rows) and function(tab)
        return list(p.rows(tab), 200, function(r)
          if type(r) ~= "table" then return nil end
          return { text = words(r.text, 60) or "", right = words(r.right, 24), mark = words(r.mark, 3), tip = words(r.tip, 200), done = r.done and true or nil, ink = ink(r.ink), act = button(r.act) }
        end)
      end,
      big = fn(p.big) and function() return button(p.big()) end,
      keys = fn(p.keys) and function() return list(p.keys(), 3, button) end }
  end
  if type(c) == "table" and fn(c.lines) then
    out.card = { when = c.when == "news" and "news" or "use", tick = c.tick == true, alive = fn(c.alive) and function() return c.alive() and true or false end,
      prio = function(pulled)
        local v = 1
        if fn(c.prio) then v = c.prio(pulled) end
        return type(v) == "number" and v == v and math.max(0, math.min(API.PRIO, v)) or nil
      end,
      lines = function(pulled)
        local l = c.lines(pulled)
        if type(l) ~= "table" then return nil end
        return { words(l[1], 24) or out.name:upper(), "", words(l[3], 40) or "", words(l[4], 16) or "", ink(l[5]) or "ink2", hot = l.hot and true or nil }
      end,
      buttons = fn(c.buttons) and function() return list(c.buttons(), 3, button) end or nil }
  end
  return out
end

--- Is this guest on the player's deck?
function D.Added(def)
  local st = D.Store()
  return type(st.added) == "table" and st.added[def.id] == true
end
function D.SetAdded(def, on)
  local st = D.Store()
  st.added = type(st.added) == "table" and st.added or {}
  st.added[def.id] = on and true or nil
  if not on then
    if D.Pins then D.Pins()[def.id] = nil if D.PinsPaint then D.PinsPaint() end end
    D.Mine().live[def.id] = nil
  end
  D.Save()
  D.Dirty(true)
end

function API.Register(addon, def)
  if type(addon) ~= "string" or addon == "" or not loaded(addon) then return nil, "addon" end
  if OURS[addon] or addon:find("^BiS") then return nil, "ours" end
  if type(def) ~= "table" or type(def.key) ~= "string" or not def.key:find("^[%w_]+$") or #def.key > 16 then return nil, "key" end
  if not words(def.name, 16) or words(def.name, 16):find("^%s*$") then return nil, "name" end
  if type(def.page) ~= "table" and not (type(def.card) == "table" and fn(def.card.lines)) then return nil, "page" end
  local id = addon .. ":" .. def.key
  local n = 0
  for oid, d in pairs(D.defs) do if d.owner == addon and oid ~= id then n = n + 1 end end
  if n >= API.MOST then return nil, "too many" end
  local mine = copy(addon, def)
  local h = D.Register(mine)
  if not h then return nil, "not ready" end
  local app = {}
  function app:Dirty() D.Dirty() end
  function app:Added() return D.Added(mine) end
  function app:Open() if not D.fight and D.Added(mine) and mine.page then return D.Open(id) end return false end
  return app
end
--- Is the deck here and switched on (shown or not)?
function API.Ready() return T.DECK_LOGIN and not D.Store().off and true or false end

-- THE STORE (Apps > STORE): what you could have ----------------------------------------------------------------------------

--- How many people you heard run this BiS addon (LibBiSComm's versions).
local function runs(name)
  local lib = rawget(_G, "LibBiSComm")
  local n = 0
  for _, r in pairs(type(lib) == "table" and type(lib.vers) == "table" and lib.vers or {}) do if type(r) == "table" and type(r.addons) == "table" and r.addons[name] then n = n + 1 end end
  return n
end
function D.StoreRows()
  local out = {}
  local guests = {}
  for _, d in pairs(D.defs) do if d.guest then guests[#guests + 1] = d end end
  table.sort(guests, function(a, b) return a.id < b.id end)
  for _, d in ipairs(guests) do
    local on = D.Added(d)
    out[#out + 1] = { mark = on and "v" or "+", text = d.name .. ", from " .. d.owner, right = d.parked and "STOPPED" or on and "ADDED" or "ADD", ink = d.parked and "warn" or on and "good" or "accent",
      tip = d.about ~= "" and d.about or nil, act = { word = "add", fn = function() D.SetAdded(d, not on) end } }
  end
  for _, c in ipairs(D.CATALOG or {}) do
    local s = D.AddonState and D.AddonState(c[1]) or "on"
    local n = runs(c[1])
    out[#out + 1] = { mark = s == "on" and "v" or "-", text = "BiS " .. c[2], right = s == "on" and "YOU HAVE IT" or s == "off" and "OFF" or n > 0 and (n .. " have it") or "GET", ink = s == "on" and "good" or "accent",
      tip = c[4], done = s == "on", act = D.defs[c[1] .. ":app"] and { word = "look", peek = true, fn = function() local d = D.defs[c[1] .. ":app"] if d.about then D.page = d.id D.Dirty(true) end end } or nil }
  end
  return out
end
