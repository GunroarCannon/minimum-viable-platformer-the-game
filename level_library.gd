extends CanvasLayer

## Level Library screen — tabbed browser of saved seeds.

const TAB_RECENT := 0
const TAB_FAV := 1
const TAB_COMMUNITY := 2

var _tabs: TabContainer = null
var _recent_vbox: VBoxContainer = null
var _fav_vbox: VBoxContainer = null
var _community_vbox: VBoxContainer = null
var _toast: Label = null

func _ready() -> void:
	layer = 50
	_build_ui()
	_refresh()
	UITheme.apply_current(self)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.08, 0.06, 0.97)
	root.add_child(bg)

	var topbar := HBoxContainer.new()
	topbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	topbar.custom_minimum_size = Vector2(0, 72)
	topbar.add_theme_constant_override("separation", 24)
	topbar.offset_left  = 24
	topbar.offset_right = -24
	root.add_child(topbar)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.custom_minimum_size = Vector2(120, 0)
	back_btn.pressed.connect(_on_back)
	topbar.add_child(back_btn)

	var title := Label.new()
	title.text = "Level Library"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	topbar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(120, 0)
	topbar.add_child(spacer)

	# Seed entry row — persistent above the tabs.
	var entry_panel := PanelContainer.new()
	entry_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	entry_panel.offset_top    = 88
	entry_panel.offset_left   = 32
	entry_panel.offset_right  = -32
	entry_panel.custom_minimum_size = Vector2(0, 60)
	root.add_child(entry_panel)
	var entry_hbox := HBoxContainer.new()
	entry_hbox.add_theme_constant_override("separation", 12)
	entry_panel.add_child(entry_hbox)
	var entry_label := Label.new()
	entry_label.text = "Enter seed:"
	entry_label.add_theme_font_size_override("font_size", 20)
	entry_hbox.add_child(entry_label)
	var line_edit := LineEdit.new()
	line_edit.placeholder_text = "e.g. K7QB"
	line_edit.max_length = Global.SEED_CODE_LEN
	line_edit.custom_minimum_size = Vector2(160, 44)
	line_edit.name = "SeedEntry"
	entry_hbox.add_child(line_edit)
	var go_btn := Button.new()
	go_btn.text = "► Play"
	go_btn.custom_minimum_size = Vector2(120, 44)
	go_btn.pressed.connect(func():
		var code: String = line_edit.text
		var s: int = Global.code_to_seed(code)
		if s > 0:
			_on_replay(s))
	entry_hbox.add_child(go_btn)
	var copy_current_btn := Button.new()
	copy_current_btn.text = "Copy Entered"
	copy_current_btn.custom_minimum_size = Vector2(140, 44)
	copy_current_btn.pressed.connect(func():
		if line_edit.text.length() > 0:
			DisplayServer.clipboard_set(line_edit.text)
			_show_toast("Copied!"))
	entry_hbox.add_child(copy_current_btn)

	# Tab container fills the rest.
	_tabs = TabContainer.new()
	_tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tabs.offset_top    = 156
	_tabs.offset_left   = 32
	_tabs.offset_right  = -32
	_tabs.offset_bottom = -16
	root.add_child(_tabs)

	_recent_vbox = _make_tab("Recent Plays")
	_fav_vbox = _make_tab("Favourites")
	_community_vbox = _make_tab("Community")

	# Community placeholder content.
	var placeholder := Label.new()
	placeholder.text = "Community favourites coming soon."
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.add_theme_font_size_override("font_size", 22)
	_community_vbox.add_child(placeholder)

	# Toast label (bottom-centre).
	_toast = Label.new()
	_toast.text = ""
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
	_toast.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 40
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast)

func _make_tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	_tabs.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	return vbox

func _refresh() -> void:
	for vb in [_recent_vbox, _fav_vbox]:
		for c in vb.get_children():
			c.queue_free()

	var entries: Array = Global.level_library.duplicate(true)

	# Recent = sorted by insertion (last-added first).
	var recent = entries.duplicate(true)
	recent.reverse()

	# Favourites subset.
	var favs = entries.filter(func(e): return bool(e.get("favorite", false)))
	favs.sort_custom(func(a, b) -> bool:
		return int(a.get("distance", 0)) > int(b.get("distance", 0)))

	if recent.is_empty():
		_recent_vbox.add_child(_empty_label("No levels played yet.\nJump in!"))
	else:
		for e in recent:
			_add_row(_recent_vbox, e)

	if favs.is_empty():
		_fav_vbox.add_child(_empty_label("No favourites yet.\nTap ☆ on a level to save it."))
	else:
		for e in favs:
			_add_row(_fav_vbox, e)

func _empty_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _add_row(vbox: VBoxContainer, entry: Dictionary) -> void:
	var seed_val := int(entry.get("seed", 0))
	var dist     := int(entry.get("distance", 0))
	var score    := int(entry.get("best_score", 0))
	var fav      := bool(entry.get("favorite", false))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	panel.add_child(hbox)

	var fav_btn := Button.new()
	fav_btn.text = "★" if fav else "☆"
	fav_btn.custom_minimum_size = Vector2(52, 52)
	fav_btn.flat = true
	fav_btn.add_theme_font_size_override("font_size", 26)
	fav_btn.pressed.connect(_on_favorite.bind(seed_val))
	hbox.add_child(fav_btn)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var seed_lbl := Label.new()
	seed_lbl.text = "Seed:  %s" % Global.seed_to_code(seed_val)
	seed_lbl.add_theme_font_size_override("font_size", 20)
	info.add_child(seed_lbl)

	var stat_lbl := Label.new()
	if score > 0:
		stat_lbl.text = "Best:  %d m  ·  Score:  %d" % [dist, score]
	else:
		stat_lbl.text = "Best:  %d m" % dist
	stat_lbl.add_theme_font_size_override("font_size", 16)
	info.add_child(stat_lbl)

	var copy_btn := Button.new()
	copy_btn.text = "Copy"
	copy_btn.custom_minimum_size = Vector2(90, 52)
	copy_btn.pressed.connect(func():
		DisplayServer.clipboard_set(Global.seed_to_code(seed_val))
		_show_toast("Copied!"))
	hbox.add_child(copy_btn)

	var replay_btn := Button.new()
	replay_btn.text = "► Replay"
	replay_btn.custom_minimum_size = Vector2(120, 52)
	replay_btn.pressed.connect(_on_replay.bind(seed_val))
	hbox.add_child(replay_btn)

	if Global.is_unlocked("leaderboard"):
		var lb_btn := Button.new()
		lb_btn.text = "Leaderboard"
		lb_btn.custom_minimum_size = Vector2(170, 52)
		lb_btn.pressed.connect(func():
			LeaderboardService.current_view_seed = Global.seed_to_code(seed_val)
			get_tree().change_scene_to_file("res://leaderboard_view.tscn")
		)
		hbox.add_child(lb_btn)

func _show_toast(text: String) -> void:
	if _toast == null: return
	_toast.text = text
	_toast.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.9)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.35)

func _on_favorite(seed_val: int) -> void:
	for entry in Global.level_library:
		if int(entry.get("seed", 0)) == seed_val:
			entry["favorite"] = not bool(entry.get("favorite", false))
			break
	Global.save_state()
	_refresh()

func _on_replay(seed_val: int) -> void:
	var gen = load("res://level_generator.gd")
	if gen:
		gen.current_seed = seed_val
	get_tree().change_scene_to_file("res://leve.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
		_on_back()
