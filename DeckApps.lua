--[[
  BiSTheme / DeckApps.lua  --  every BiS addon's icon and the Apps page (22 Nov 2026).

  Arn, 22 Nov: "Put my tools in there but grayed out that way when I need the probe deck I can just click it since I have it
  installed stuff like that".

  TWO THINGS, all data for Deck.lua (no frame here):
   - THE CATALOGUE: one icon for each public BiS addon. Installed = its own window opens. Switched off in the AddOns list, or
     not installed = gray, with OFF / GET on it, and a page that says what it is. An addon that hands in its own "app" wins.
   - THE APPS PAGE: every icon there is, shown or hidden, by a click.
  The welcome walk-through is gone (25 Nov 2026, MINOR 3: no onboarding anywhere).
  Our own tools (BiSProbe ...) are not here: they hand themselves in with `dev = true`, so only who has them sees them.
]]
BiSTheme = BiSTheme or {}
local T = BiSTheme
local D = T.Deck
if not D or not T.DECK_READY then return end
local MINOR = 3                       -- 2 (24 Nov 2026): no welcome by itself; 3 (25 Nov): no welcome at all
if (T.DECKAPPS_MINOR or 0) >= MINOR then return end
T.DECKAPPS_MINOR = MINOR

local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if not ok then return nil end
  return a, b, c, d, e
end

-- THE CATALOGUE ------------------------------------------------------------------------------------------------------

--- Run an addon's own door: its API's Open, else its slash word.
function D.Door(api, slash, word)
  local a = api and rawget(_G, api)
  if type(a) == "table" and type(a.Open) == "function" then a.Open() return true end
  local s = slash and SlashCmdList and SlashCmdList[slash]
  if type(s) == "function" then s(word or "") return true end
  return false
end

D.CATALOG = {
  { "BiSTools", "Tools", "Tl", "Small helpers: bosses and quests of where you stand, rides, buffs, death recap, rivals. Every one has its own switch.", slash = "BISTOOLS", word = "hub", find = "BiS Tools" },
  { "BiSHealing", "Healing", "He", "Click a health bar to heal it. Binds, shields, heals on the way and cues for every healer.", slash = "BISHEALING", word = "options", find = "BiS Healing" },
  { "BiSMemories", "Memories", "Me", "Takes a picture when something worth remembering happens, and keeps the album.", slash = "BISMEMORIES", word = "book", find = "BiS Memories" },
  { "BiSGuild", "Guild", "Gu", "Raid nights from your own logs: who was there, what they used, what comes next.", api = "BiSGuildAPI", slash = "BISGUILD", find = "BiS Guild" },
  { "BiSGamba", "Gamba", "Ga", "Rolls for gold on raid nights: the table, who owes whom, the board.", api = "BiSGambaAPI", slash = "BISGAMBA", find = "BiS Gamba" },
  { "Nebbinator", "Nebbinator", "Ne", "Recruiting for the whole guild: the ad, one list of recruits, the party scout.", api = "NebbinatorAPI", slash = "NEBBINATOR", find = "Nebbinator" },
  { "BiSShell", "Shell", "Sh", "A computer inside the game: what your addons cost, and the games hidden on floppy disks.", api = "BiSShellAPI", slash = "BISSHELL", find = "BiS Shell" },
}

-- THE ICONS: the game's own pictures, by the app's id (an app's own `art` wins; none = its letters). All of them are icons the
-- first game had, so every client has them.
local function I(name) return "Interface\\Icons\\" .. name end
D.ART = D.ART or {}
for id, name in pairs({
  ["BiSTools:bosses"] = "INV_Misc_Bone_HumanSkull_01", ["BiSTools:run"] = "INV_Misc_Note_01", ["BiSTools:farm"] = "Ability_Hunter_SniperShot",
  ["BiSTools:rides"] = "Ability_Mount_Raptor", ["BiSTools:tool-recap"] = "Ability_Creature_Cursed_02", ["BiSTools:tool-rivals"] = "Ability_DualWield",
  ["BiSTools:tool-social"] = "INV_Letter_15", ["BiSTools:tool-bg"] = "INV_BannerPVP_01", ["BiSTools:tool-map"] = "INV_Misc_Map_01",
  ["BiSTools:tool-party"] = "Spell_Holy_PrayerOfHealing", ["BiSTools:tool-summon"] = "Spell_Holy_PrayerOfHealing", ["BiSTools:tool-sounds"] = "INV_Misc_Bell_01", ["BiSTools:tool-xp"] = "INV_Misc_Rune_01",
  ["BiSTools:tool-disenchant"] = "INV_Enchant_Disenchant", ["BiSTools:tool-processing"] = "INV_Misc_Gear_01", ["BiSTools:tool-codex"] = "INV_Misc_Book_11",
  ["BiSTools:tool-alts"] = "INV_Misc_GroupLooking", ["BiSTools:tool-combo"] = "Spell_Nature_LightningShield", ["BiSTools:tool-innervate"] = "Spell_Nature_Lightning", ["BiSTools:tool-windfury"] = "Spell_Nature_Cyclone",
  ["BiSShell:fm"] = "INV_Misc_Drum_01", ["BiSShell:play"] = "Ability_Warrior_Challange", ["BiSShell:games"] = "INV_Misc_Dice_01",
  ["BiSTools:app"] = "INV_Misc_Wrench_01", ["BiSHealing:app"] = "Spell_Nature_HealingWaveGreater", ["BiSMemories:app"] = "INV_Misc_Spyglass_03",
  ["BiSGuild:app"] = "INV_Shirt_GuildTabard_01", ["BiSGamba:app"] = "INV_Misc_Coin_02", ["Nebbinator:app"] = "INV_Misc_GroupNeedMore", ["BiSShell:app"] = "Spell_Holy_PowerWordShield",
  ["BiSProbe:deck"] = "INV_Misc_EngGizmos_27", ["BiSProbe:reload"] = "Spell_Nature_TimeStop", ["BiSProbe:errors"] = "Ability_Spy",
}) do D.ART[id] = I(name) end

--- Is this addon loaded, there but off, or not there? Asked once: it cannot change before a reload.
D.states = D.states or {}
function D.AddonState(name)
  if D.states[name] then return D.states[name] end
  local A = C_AddOns
  if not (A and A.IsAddOnLoaded and A.GetAddOnInfo) then return "on" end
  local s
  if ask(A.IsAddOnLoaded, name) then s = "on"
  else
    local got, _, _, _, reason = ask(A.GetAddOnInfo, name)
    s = (not got or reason == "MISSING") and "missing" or "off"
  end
  D.states[name] = s
  return s
end

-- THE APPS PAGE ------------------------------------------------------------------------------------------------------

local WORD = { off = "off", missing = "not installed", dev = "tool" }
function D.AppRows()
  local out = {}
  for i, x in ipairs(D.Icons()) do
    local d, s = x[1], x[2]
    if d.id ~= "BiSDeck:apps" and s == "off" and d.quietOff then
      -- a tool that is off: what it is, and TURN ON
      out[#out + 1] = { mark = "-", text = d.name or d.key, right = "OFF", ink = "dim", done = true, tip = "Click: what it is, and a button to turn it on", act = { word = "look", peek = true, fn = function() D.Open(d.id) end } }
    elseif d.id ~= "BiSDeck:apps" then
      local is = D.Shown(d, s)
      out[#out + 1] = { mark = is and "v" or "-", text = (d.name or d.key) .. (WORD[s] and (" - " .. WORD[s]) or ""), right = is and "SHOWN" or "HIDDEN", ink = is and "good" or "dim",
        done = not is, tip = is and "Click: take it off the home screen" or "Click: put it on the home screen",
        act = { word = "switch", fn = function()
          local st = D.Store()
          if is then st.apps[d.id] = false else
            st.apps[d.id] = nil
            if s == "missing" then st.sw.missing = nil end
          end
          D.Save()
        end } }
    end
  end
  return out
end

local WHEN = { use = "AFTER USE", news = "BY ITSELF", off = "NEVER" }
local WHEN_TIP = { use = "Comes when you did something in its app. Click: when it has news", news = "Comes by itself when it has something to say. Click: never", off = "No live card. Click: after you used its app" }
--- Every card there is, and when it may come.
function D.CardRows()
  local out = {}
  for _, x in ipairs(D.Icons()) do
    local d = x[1]
    if d.card and x[2] ~= "off" and x[2] ~= "missing" then
      local w = D.When(d)
      out[#out + 1] = { mark = w == "off" and "-" or "v", text = d.name or d.key, right = D.Hushes()[d.id] and "HIDDEN NOW" or WHEN[w], ink = w == "off" and "dim" or D.Hushes()[d.id] and "gold" or "good", done = w == "off",
        tip = D.Hushes()[d.id] and "You hid it with a right-click: it comes back when it has something new. Click: now" or WHEN_TIP[w],
        act = { word = "next", fn = function()
          if D.Hushes()[d.id] then D.HushEnd(d.id) return end D.SetWhen(d, w == "use" and "news" or w == "news" and "off" or "use") end },
        side = { word = D.SizePick(d.id):upper(), tip = "Its size: auto, small, medium, large", fn = function()
          local at = 1
          for i, s in ipairs(D.SIZES) do if s == D.SizePick(d.id) then at = i end end
          D.SetSize(d.id, D.SIZES[at % #D.SIZES + 1])
        end } }
    end
  end
  return out
end

--- Hand all of it in (at the first Show after the login, so every addon has had its turn).
function D.Apps()
  if not D.appsIn then
    D.appsIn = true
    if C_AddOns and C_AddOns.GetAddOnInfo then
      for i, c in ipairs(D.CATALOG) do
        local name = c[1]
        if not D.defs[name .. ":app"] then
          D.Register{ owner = name, key = "app", name = c[2], icon = c[3], about = c[4], find = c.find, order = 60 + i,
            state = function() return D.AddonState(name) end,
            open = function() if not D.Door(c.api, c.slash, c.word) then D.page = name .. ":app" D.Dirty(true) end end,
            turnOn = { word = "TURN ON (RELOADS)", fn = function()
              if C_AddOns.EnableAddOn then C_AddOns.EnableAddOn(name) end
              D.Save()
              ReloadUI()
            end } }
        end
      end
    end
    D.Register{ owner = "BiSDeck", key = "apps", name = "Apps", icon = "+", order = 99,
      page = { title = function() return "Apps" end, kicker = function() return "shown on home" end, tabs = function() return { "ICONS", "CARDS", "STORE" } end, rows = function(tab) return tab == 3 and D.StoreRows and D.StoreRows() or tab == 2 and D.CardRows() or D.AppRows() end } }
    -- NO WELCOME AT ALL (MINOR 3, 25 Nov 2026, Arn: "only leave the try deck, no more onboarding per app" - "remove the
    -- button"): the walk-through, its page and the typed way back to it are gone. MINOR 2 (24 Nov) had taken it off the
    -- first opening ("best thing we can do it just have a easy to read ui").
  end
end
