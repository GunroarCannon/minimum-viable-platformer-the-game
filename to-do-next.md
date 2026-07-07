# to-do-next

Follow-ups from the last review pass. Everything below is fresh scope, not a
rehash of what shipped in the earlier clusters.

## 1. Combo popups — non-blocking, off-center

- `combo_system.gd::_spawn_popup` puts labels in the middle of the screen and
  they can steal input from the pause / touch controls beneath them.
- Fix:
  - `label.mouse_filter = Control.MOUSE_FILTER_IGNORE` on both the popup and
    (if introduced) any wrapping Control.
  - Set `ComboSystem`'s CanvasLayer `mouse_filter` to IGNORE too so the layer
    itself never eats clicks.
  - Offset target position: for stomps, pin above the player head (world_pos +
    `Vector2(0, -180)` before the canvas transform). For air summaries, pin to
    the top-right corner (screen-space, e.g. `Vector2(viewport.x - 320, 120)`)
    instead of `player.global_position - (0,120)`.
- Verify: die while a combo popup is on screen; retry button must still be
  clickable. On mobile, jump button under the popup must still respond.

## 2. Font select — immediate randomization on purchase

- Currently the player has to open Settings and pick a font. Requested: buying
  the `font_select` upgrade should immediately change the default UI font to a
  random file from `assets/fonts/`.
- Approach: in `skills_db.gd::purchase` (or wherever purchases finalize), after
  `Global.grant(fkey)` for `font_select`, do:
  ```gdscript
  var fonts = _list_fonts_static()  # duplicate of settings.gd::_list_fonts
  if fonts.size() > 0:
      var pick = fonts[randi() % fonts.size()].get_file()
      Global.settings_cfg["font_choice"] = pick
      Global.save_state()
  ```
- Consider extracting the font enumeration into a shared helper (e.g.
  `FontRegistry.list()` autoload or a static in `ui_theme.gd`) so both
  Settings' dropdown and this purchase hook share one code path.
- Verify: fresh save → buy Font Select → back to main menu → title label uses
  a randomly chosen font.

## 3. Shop detail panel — owned toggle overflows

- When a skill is purchased the `_d_toggle` CheckBox with its long label
  ("Feature active (uncheck to disable without losing progress)") pushes the
  detail panel out of bounds. The Scroll wrap from cluster 4 helps vertically
  but the label text still clips horizontally.
- Fix:
  - `_d_toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` and
    `size_flags_horizontal = SIZE_EXPAND_FILL`.
  - Consider shortening label to "Feature active" and moving the parenthetical
    into a small Label below it.
  - Verify all four detail label rows (`Name`, `Desc`, `Status`) fit at the
    narrowest panel width the layout allows.
- Also check that the polished CheckBox switch-icon renders inside the scroll
  content area (not clipped by the panel bounds).

## 4. Skill costs — depth-based exponential formula

- Costs are currently hardcoded per-skill (2/3/4/5). User wants one central
  formula that makes deeper nodes cost exponentially more.
- Suggested implementation in `skills_db.gd`:
  ```gdscript
  const COST_BASE := 1.0
  const COST_MULT := 1.6
  const COST_ROUND := 1  # round to nearest N

  static func compute_cost(skill_id: String) -> int:
      var depth = _depth_from_root(skill_id)
      var raw = COST_BASE * pow(COST_MULT, depth)
      return max(1, int(round(raw / COST_ROUND) * COST_ROUND))

  static func _depth_from_root(skill_id: String) -> int:
      # BFS shortest path over `requires` back to ROOT_ID.
      ...
  ```
- Rewire `can_afford`, the shop UI cost badge, the tree-view badge, and
  `SkillsDB.purchase` to call `compute_cost(sid)` instead of reading
  `d["cost"]`.
- Leave the `cost` dict entries in place as fallback for skills that need
  bespoke pricing (e.g. UI = 1), or delete them and always compute.
- Verify: a leaf like `home_polish` (5 hops from root) costs meaningfully more
  than a first-tier like `hud` (1 hop).

## 5. Lose screen — buttons overflow when everything is unlocked

- `ui.tscn` `Box` (Buy UI, Retry, Shop, Menu, Exit) plus dynamically appended
  Replay / Highscore label / Seed label / Favourite button doesn't fit at
  1280×720 once every unlock is bought.
- Fix:
  - Wrap `Center/Box` in a `ScrollContainer` with `custom_minimum_size = (560,
    600)` and `size_flags_vertical = SHRINK_CENTER`; ScrollContainer clamps to
    the viewport but scrolls beyond.
  - Tighten `Box` `theme_override_constants/separation` from 12 → 8.
  - Reduce dynamic label font sizes (18 → 16) for the seed / highscore rows.
- Alternative: split Retry / Replay-same into a compact HBox pair instead of
  two full-width stacked buttons.

## 6. Main menu — buttons overflow when everything is unlocked

- Buttons visible when fully unlocked:
  Daily · Play · Library · Shop · Stats · Settings · Exit (7 rows @ 64 px +
  separation = ~500 px). Squeezes with the polished title + subtitle above.
- Preferred fix (user's suggestion): once `stats_menu` is unlocked, move
  `Settings` into the TopBar as a gear icon next to `BestLabel`. Same could be
  done for Exit → small "×" corner button.
- Implementation notes:
  - Load a settings glyph (or use unicode "⚙") in a small `Button` sized
    `(48, 48)` with `flat = true`.
  - Hide the full-width Settings button from the main VBox when the icon is
    present, or remove `settings_btn` entirely and rebind on the icon.
  - Add a corresponding shortcut in `_input` so ui_cancel from menu still
    reaches Settings during dev.
- Verify at every unlock milestone: no button gets clipped, TopBar still
  readable, keyboard focus order still makes sense.

## Nice-to-have (deferred)

- Palette live-preview in Settings dropdown (currently only applies after
  reload for some scenes).
- Combo popup uses the currently selected UI font as a fallback when none of
  the funky trio is available (should already work, but add an assert).
- Adaptive-sky curve: currently linear stepping — could ease with `sin(t)` so
  the "midday" phase lingers longer than the transitions.
- Stats menu: paginate deaths_by_cause once it grows past ~10 entries.
