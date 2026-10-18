Read ../_bisdev/CLAUDE.md first.

## Layout (BiSTheme only)

- `BiSTheme.toc`: `## Interface: 20506`, `## Version: 1.3.1`, `## X-Category: Library`. It has no SavedVariables, no dependencies and no slash commands. Load order: `BiSTheme.lua`, `Console.lua`, `Options.lua`. The TOC notes say it should load first and that other addons list it under OptionalDeps.
- This addon holds the master copies. `Console.lua` and `Options.lua` are what `../_bisdev/sync.ps1` copies byte for byte into every other addon's `Libs\BiSTheme\`. Change them here and sync out, never the other way. There is no `Libs/` folder in this addon.
- `BiSTheme.lua` (118 lines): the palette, in the global `BiSTheme` (usually `local T`).
  - `T.hex` (dark, the default) and `T.hexLight`: named colours stored as hex. The ground colours are `bg`, `surface`, `sunken`, `line`, `line2`. The text colours are `ink`, `ink2`, `muted`. The accent is `accent`/`accentSoft`. The meaning colours are `good`, `warn`, `gold`, `slate`, `dim`. Item quality colours are `epic`, `rare` and so on.
  - Helpers: `T.rgb`, `T.rgba`, `T.text` (wraps text in a `|cff…|r` colour code), `T.classRGB`, `T.pctColor`, `T.skin(frame)`. An unknown colour name falls back to `ink`.
- `Console.lua` (230 lines): the `BiS> _` prompt shown in window headers. It skips loading if an equal or newer copy already ran (`CONSOLE_MINOR`, currently 4).
  - Its own palette fallback, used only when `BiSTheme.lua` never ran, i.e. when the file ships embedded in another addon.
  - `T.CONSOLE` defaults (`cycle`, `hold`, `fade`, `size`, `prompt`) and `T.Fit(fs, text, width)` (shortens text with an ellipsis until it fits).
  - `T.Console(fs, opts)` returns an object with `Set` (slots that rotate), `Say` (queued one-off lines), `Clear`, `Paint` (call it from a ticker), and `Text`/`Width` for tests. The words and the cursor are each their own FontString, and the cursor blinks by alpha.
- `Options.lua` (464 lines): the options window every BiS addon shares. It uses the same load guard (`OPTIONS_MINOR`, currently 3: Escape closes the window; windows dodge each other, are 1.43:1, and carry a help strip). It must load after `Console.lua`. It uses the prompt if `T.Console` exists and falls back to a plain title if not. It carries its own copies of the palette fallback and `T.Fit`. Sections are split by `----` banners:
  - `T.OPTIONS`: the size constants (`W` 230, `ROW`, `HEADER`, `CTL` and others). A local `SHADE` table holds the window's own dark shades.
  - primitives: `tex`, `fs`, `border`, `flat`, `box`, exported as `T.OptionsPrimitives`.
  - the four control kinds `toggle`, `seg`, `step`, `button` (`T.OptionKinds`). Anything else must be a slash command, and an unknown kind throws an error. The stepper itself keeps values within `min`/`max`, so setters don't have to.
  - the window: `T.Options(name, w, title)` returns a frame with `Section`, `Row`, `AddRow`, `Fit`, `Paint`, `Toggle`, `Recenter`, `Say` and an `onChange` hook. The frame starts hidden.
- `README-Console.md`: the console's rules, API, the five steps to add it to a window, and the traps in headless testing. It ends with a pasted copy of `Console.lua`'s source, which has to be refreshed whenever `Console.lua` changes.
- `dev/tests.lua` (134 lines): the only suite. There is no options, theme, stress, harness or release file. It does not read the TOC: it `loadfile`s a hard-coded list. First it loads `Console.lua` alone to test the fallback, then `BiSTheme.lua` followed by `Console.lua`. It covers the palette, `Fit`, the load guard, slot rotation, `Say`, fades and cursor blink. It never loads or tests `Options.lua`. It must run from the addon folder, with a mock clock and mock FontStrings.
- There is no `dev/release.ps1` and no CurseForge project id anywhere in this folder.
- `.github/workflows/check.yml`: calls the shared CI workflow in `blankfer/bisdev` with `addon: BiSTheme`.
- `.gitattributes` forces LF line endings, except `*.ps1` which get CRLF. `.gitignore` excludes `*.zip` and `release/`.
