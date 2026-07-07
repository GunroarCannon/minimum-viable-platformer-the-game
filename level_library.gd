extends CanvasLayer

## Level Library screen — shows all saved run seeds so the player can
## replay favourites, view best distances, or jump into a fresh run.

var _vbox: VBoxContainer = null

func _ready() -> void:
	layer = 50
	_build_ui()
	_refresh()
	UITheme.apply_current(self)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Background fill
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.08, 0.06, 0.97)
	root.add_child(bg)

	# Top bar
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

	# Scroll container for entries
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top    = 84
	scroll.offset_left   = 32
	scroll.offset_right  = -32
	scroll.offset_bottom = -16
	root.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_vbox)

	# Seed entry row so players can jump into a code shared by a friend.
	var entry_panel := PanelContainer.new()
	entry_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(entry_panel)
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

func _refresh() -> void:
	for c in _vbox.get_children():
		c.queue_free()

	var entries: Array = Global.level_library.duplicate(true)
	if entries.is_empty():
		var lbl := Label.new()
		lbl.text = "No levels saved yet.\nPlay some runs to build your library!"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_vbox.add_child(lbl)
		return

	# Favourites first, then sort by distance descending.
	entries.sort_custom(func(a, b) -> bool:
		var af: bool = a.get("favorite", false)
		var bf: bool = b.get("favorite", false)
		if af != bf: return af
		return int(a.get("distance", 0)) > int(b.get("distance", 0))
	)

	for entry in entries:
		_add_row(entry)

func _add_row(entry: Dictionary) -> void:
	var seed_val := int(entry.get("seed", 0))
	var dist     := int(entry.get("distance", 0))
	var fav      := bool(entry.get("favorite", false))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	panel.add_child(hbox)

	# Favourite toggle
	var fav_btn := Button.new()
	fav_btn.text = "★" if fav else "☆"
	fav_btn.custom_minimum_size = Vector2(52, 52)
	fav_btn.flat = true
	fav_btn.add_theme_font_size_override("font_size", 26)
	fav_btn.pressed.connect(_on_favorite.bind(seed_val))
	hbox.add_child(fav_btn)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var seed_lbl := Label.new()
	seed_lbl.text = "Seed:  %s" % Global.seed_to_code(seed_val)
	seed_lbl.add_theme_font_size_override("font_size", 20)
	info.add_child(seed_lbl)

	var dist_lbl := Label.new()
	dist_lbl.text = "Best:  %d m" % dist
	dist_lbl.add_theme_font_size_override("font_size", 16)
	info.add_child(dist_lbl)

	# Replay button
	var replay_btn := Button.new()
	replay_btn.text = "► Replay"
	replay_btn.custom_minimum_size = Vector2(120, 52)
	replay_btn.pressed.connect(_on_replay.bind(seed_val))
	hbox.add_child(replay_btn)

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
