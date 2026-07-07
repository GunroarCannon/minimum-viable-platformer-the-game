extends CanvasLayer

## Stats screen — unlocked by the "stats_menu" skill. Reads from Global.stats.

func _ready() -> void:
	layer = 50
	_build_ui()
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
	topbar.offset_left  = 24
	topbar.offset_right = -24
	root.add_child(topbar)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.custom_minimum_size = Vector2(120, 0)
	back_btn.pressed.connect(_on_back)
	topbar.add_child(back_btn)

	var title := Label.new()
	title.text = "Stats"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	topbar.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(120, 0)
	topbar.add_child(spacer)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top    = 84
	scroll.offset_left   = 32
	scroll.offset_right  = -32
	scroll.offset_bottom = -16
	root.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var s: Dictionary = Global.stats
	_add_row(vbox, "Playtime",           _fmt_time(float(s.get("playtime_sec", 0.0))))
	_add_row(vbox, "Sessions",           str(int(s.get("sessions", 0))))
	_add_row(vbox, "Days played",        str(int((s.get("days_played", {}) as Dictionary).size())))
	_add_row(vbox, "Deaths",             str(int(s.get("deaths", 0))))
	_add_row(vbox, "Total distance",     "%d m" % int(s.get("total_distance_m", 0)))
	_add_row(vbox, "Longest run",        "%d m" % int(s.get("longest_run_m", 0)))
	_add_row(vbox, "Jumps",              str(int(s.get("jumps", 0))))
	_add_row(vbox, "Highest jump",       "%d px" % int(s.get("highest_jump_px", 0)))
	_add_row(vbox, "Longest combo",      str(int(s.get("longest_combo", 0))))
	_add_row(vbox, "Enemies stomped",    str(int(s.get("enemies_stomped", 0))))
	_add_row(vbox, "Bullets fired",      str(int(s.get("bullets_fired", 0))))
	_add_row(vbox, "Points earned",      str(int(s.get("total_points_earned", 0))))
	_add_row(vbox, "Points spent",       str(int(s.get("total_points_spent", 0))))
	_add_row(vbox, "Upgrades bought",    str(int(s.get("upgrades_bought", 0))))
	_add_row(vbox, "Seeds visited",      str(int((s.get("seeds_visited", {}) as Dictionary).size())))
	_add_row(vbox, "Daily levels done",  str(int(s.get("daily_completed", 0))))

	# Deaths-by-cause breakdown.
	var causes: Dictionary = s.get("deaths_by_cause", {})
	if not causes.is_empty():
		var sep := HSeparator.new()
		vbox.add_child(sep)
		var head := Label.new()
		head.text = "Deaths by cause"
		head.add_theme_font_size_override("font_size", 22)
		vbox.add_child(head)
		var keys: Array = causes.keys()
		keys.sort_custom(func(a, b): return int(causes[a]) > int(causes[b]))
		for k in keys:
			_add_row(vbox, str(k).capitalize(), str(int(causes[k])))

func _add_row(vbox: VBoxContainer, label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)
	var l := Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 20)
	hbox.add_child(l)
	var v := Label.new()
	v.text = value_text
	v.add_theme_font_size_override("font_size", 20)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(v)

func _fmt_time(sec: float) -> String:
	var s := int(sec)
	var h := s / 3600
	var m := (s % 3600) / 60
	var ss := s % 60
	if h > 0:
		return "%dh %dm %ds" % [h, m, ss]
	return "%dm %ds" % [m, ss]

func _on_back() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
		_on_back()
