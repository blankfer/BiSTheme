-- BiSTheme / dev / forever.lua -- the deck's two suites, for check.sh (it runs tests, options, theme, stress, forever):
-- where everything goes (decklayout.lua) and the skin (deck.lua). Each ends with os.exit: caught here, its code kept.
local exit, bad = os.exit, false
for _, f in ipairs({ "dev/decklayout.lua", "dev/deck.lua" }) do
  local code
  os.exit = function(c) code = c error("__done") end
  local ok, why = pcall(dofile, f)
  if not ok and not tostring(why):find("__done", 1, true) then print("FAIL " .. f .. ": " .. tostring(why)) bad = true end
  if (code or 0) ~= 0 then bad = true end
end
exit(bad and 1 or 0)
