extends CanvasLayer

@onready var tokens_label: Label = $Root/TopBar/TokensLabel
@onready var title_label: Label = $Root/TopBar/Title
@onready var back_btn: Button = $Root/TopBar/BackButton
@onready var tree_view: Control = $Root/Body/Tree
@onready var detail_panel: Panel = $Root/Body/Detail
@onready var d_name: Label = $Root/Body/Detail/Scroll/V/Name
@onready var d_desc: Label = $Root/Body/Detail/Scroll/V/Desc
@onready var d_cost: Label = $Root/Body/Detail/Scroll/V/Cost
@onready var d_status: Label = $Root/Body/Detail/Scroll/V/Status
@onready var d_buy: Button = $Root/Body/Detail/Scroll/V/BuyButton
@onready var d_branch: Label = $Root/Body/Detail/Scroll/V/Branch
@onready var legend: HBoxContainer = $Root/Legend

## Dynamically created toggle checkbox; shown only for purchased skills.
var _d_toggle: CheckBox = null
var _d_toggle_hint: Label = null

## Recommend button — cycles the tree camera through purchasable skills in
## priority order. Only visible while there's something left to buy.
var _recommend_btn: Button = null
## Snapshot of the current cycle so successive clicks step through the same
## ordered list until it's exhausted or state changes (buy/spend). Rebuilt
## lazily by _current_recommendations() when stale.
var _recommend_cycle: Array = []
var _recommend_idx: int = -1
var _recommend_state_sig: String = ""

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	d_buy.pressed.connect(_on_buy)
	tree_view.skill_selected.connect(_on_skill_selected)
	UITheme.apply_current(self)
	legend.visible = false

	# Recommend button — inserted before the tokens label so it sits right of
	# the title. Hidden by _refresh when nothing is purchasable.
	_recommend_btn = Button.new()
	_recommend_btn.text = "Recommend"
	_recommend_btn.custom_minimum_size = Vector2(180, 0)
	_recommend_btn.add_theme_font_size_override("font_size", 22)
	_recommend_btn.pressed.connect(_on_recommend)
	var top_bar := $Root/TopBar
	top_bar.add_child(_recommend_btn)
	top_bar.move_child(_recommend_btn, tokens_label.get_index())
	UITheme.apply_current(_recommend_btn)

	# Create the active-toggle checkbox and append it to the detail VBox.
	var detail_vbox = $Root/Body/Detail/Scroll/V
	_d_toggle = CheckBox.new()
	_d_toggle.text = "Feature active"
	_d_toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_toggle.visible = false
	detail_vbox.add_child(_d_toggle)
	_d_toggle.toggled.connect(func(p: bool):
		AudioManager.play("switch_on" if p else "switch_off", 0.0, 0.04)
		_on_toggle_active(p)
	)

	_d_toggle_hint = Label.new()
	_d_toggle_hint.text = "Uncheck to disable without losing progress."
	_d_toggle_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_toggle_hint.add_theme_font_size_override("font_size", 14)
	_d_toggle_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_toggle_hint.visible = false
	detail_vbox.add_child(_d_toggle_hint)

	# The toggle & hint were created after UITheme.apply_current ran above, so
	# re-apply so the switch icons + polished label colors reach them.
	UITheme.apply_current(_d_toggle)
	UITheme.apply_current(_d_toggle_hint)

	# Description label needs to wrap inside the narrow detail panel.
	d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Force dark ink on all detail-panel labels so the description never renders
	# with a light theme fallback (the placeholder theme paints Labels white).
	var ink := Color(0.15, 0.10, 0.06)
	for lbl in [d_name, d_desc, d_cost, d_status, d_branch]:
		lbl.add_theme_color_override("font_color", ink)
		lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.95, 0.82))
		lbl.add_theme_constant_override("outline_size", 3)
	# Bump descriptor/status size a touch so it isn't a footnote.
	d_desc.add_theme_font_size_override("font_size", 20)
	d_status.add_theme_font_size_override("font_size", 20)
	d_cost.add_theme_font_size_override("font_size", 20)
	d_branch.add_theme_font_size_override("font_size", 18)

	_refresh()
	# Select root by default so the detail panel isn't empty.
	tree_view.set_selected(SkillsDB.ROOT_ID)
	_on_skill_selected(SkillsDB.ROOT_ID)
	AudioManager.play_music("shop", 1.2)
	AudioManager.connect_ui_clicks(self)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
		_on_back()

func _refresh() -> void:
	tokens_label.text = "★  %d tokens" % Global.tokens
	title_label.text  = "Skill Tree"
	tree_view.queue_redraw()
	_refresh_detail()
	_refresh_recommend_btn()

## Snapshot signature of the "purchasable now" set. When it changes (buy,
## afford, prereq newly met), we invalidate the cycle so the button steps
## through a fresh list.
func _recommend_signature() -> String:
	var ids := SkillsDB.SKILLS.keys()
	ids.sort()
	var parts := PackedStringArray()
	for sid in ids:
		if SkillsDB.purchasable_now(sid):
			parts.append(sid)
	parts.append("$T=%d" % Global.tokens)
	return "|".join(parts)

## Build the ordered recommendation list. Priority DESC breaks by depth ASC
## (shallower nodes first — they unlock more branches) then id ASC for stable
## order. Only returns skills the player can buy right now.
func _build_recommend_cycle() -> Array:
	var items: Array = []
	for sid in SkillsDB.SKILLS.keys():
		if not SkillsDB.purchasable_now(sid): continue
		var pr: int = SkillsDB.get_priority(sid)
		var depth: int = SkillsDB.depth_from_root(sid)
		items.append({"sid": sid, "priority": pr, "depth": depth})
	items.sort_custom(func(a, b):
		if a.priority != b.priority: return a.priority > b.priority
		if a.depth != b.depth: return a.depth < b.depth
		return a.sid < b.sid)
	var out: Array = []
	for it in items:
		out.append(it.sid)
	return out

## Current cycle, rebuilt if the purchasable set has changed since last time.
func _current_recommendations() -> Array:
	var sig := _recommend_signature()
	if sig != _recommend_state_sig:
		_recommend_state_sig = sig
		_recommend_cycle = _build_recommend_cycle()
		_recommend_idx = -1
	return _recommend_cycle

func _refresh_recommend_btn() -> void:
	if _recommend_btn == null: return
	var recs := _current_recommendations()
	if recs.is_empty():
		_recommend_btn.visible = false
	else:
		_recommend_btn.visible = true
		_recommend_btn.text = "★ Recommend (%d)" % recs.size()

func _on_recommend() -> void:
	var recs := _current_recommendations()
	if recs.is_empty(): return
	_recommend_idx = (_recommend_idx + 1) % recs.size()
	var sid: String = recs[_recommend_idx]
	if tree_view.has_method("focus_on"):
		tree_view.focus_on(sid)
	# _on_skill_selected fires from focus_on's signal, updating the detail panel.

func _refresh_detail() -> void:
	var sid: String = tree_view.selected_id()
	if sid == "" or not SkillsDB.SKILLS.has(sid):
		d_name.text = "—"; d_desc.text = ""; d_cost.text = ""; d_status.text = ""
		d_buy.disabled = true
		if _d_toggle: _d_toggle.visible = false
		if _d_toggle_hint: _d_toggle_hint.visible = false
		return
	var d = SkillsDB.SKILLS[sid]
	var cost := SkillsDB.compute_cost(sid)
	d_name.text = d["name"]
	d_desc.text = d["desc"]
	d_cost.text = "Cost: %d ★" % cost
	d_branch.text = "Branch: " + SkillsDB.BRANCH_NAMES.get(d["branch"], d["branch"])

	var unlock_all: bool = Global.debug_toggles.get("unlock_all", false)
	var purchased := SkillsDB.is_purchased(sid) or unlock_all
	var prereq := SkillsDB.prereqs_met(sid) or unlock_all
	var affordable := SkillsDB.can_afford(sid) or unlock_all

	if purchased:
		d_status.text = "OWNED"
		d_status.modulate = Color(0.30, 0.70, 0.30)
		d_buy.text = "Owned"
		d_buy.disabled = true
		# Show active toggle for purchased skills — but not for load-bearing
		# ones like basic UI, HUD, procgen and basic enemies. Disabling those
		# leaves the game visibly broken, so we hide the toggle entirely.
		var toggleable := SkillsDB.is_toggleable(sid)
		if _d_toggle:
			var fkey = SkillsDB.get_feature_key(sid)
			_d_toggle.visible = toggleable
			_d_toggle.set_block_signals(true)
			_d_toggle.button_pressed = bool(Global.feature_overrides.get(fkey, true))
			_d_toggle.set_block_signals(false)
		if _d_toggle_hint:
			_d_toggle_hint.visible = toggleable
			if not toggleable:
				# Explain WHY the toggle is missing so it doesn't feel like a bug.
				pass
	elif not prereq:
		var missing := []
		for r in d.get("requires", []):
			if not SkillsDB.is_purchased(r):
				missing.append(SkillsDB.SKILLS[r]["name"])
		d_status.text = "Locked\nNeeds: " + ", ".join(missing)
		d_status.modulate = Color(0.65, 0.30, 0.25)
		d_buy.text = "Locked"
		d_buy.disabled = true
		if _d_toggle: _d_toggle.visible = false
		if _d_toggle_hint: _d_toggle_hint.visible = false
	elif not affordable:
		d_status.text = "Not enough tokens"
		d_status.modulate = Color(0.65, 0.45, 0.20)
		d_buy.text = "Need %d ★" % cost
		d_buy.disabled = true
		if _d_toggle: _d_toggle.visible = false
		if _d_toggle_hint: _d_toggle_hint.visible = false
	else:
		d_status.text = "Available"
		d_status.modulate = Color(0.18, 0.14, 0.10)
		d_buy.text = "Buy (%d ★)" % cost
		d_buy.disabled = false
		if _d_toggle: _d_toggle.visible = false
		if _d_toggle_hint: _d_toggle_hint.visible = false
		
		# Jiggle tween to draw attention
		d_buy.pivot_offset = d_buy.size * 0.5
		var tw = create_tween()
		tw.tween_property(d_buy, "rotation", 0.1, 0.05)
		tw.tween_property(d_buy, "rotation", -0.1, 0.05)
		tw.tween_property(d_buy, "rotation", 0.05, 0.05)
		tw.tween_property(d_buy, "rotation", -0.05, 0.05)
		tw.tween_property(d_buy, "rotation", 0.0, 0.05)

func _on_toggle_active(pressed: bool) -> void:
	var sid: String = tree_view.selected_id()
	if sid == "": return
	var unlock_all: bool = Global.debug_toggles.get("unlock_all", false)
	if not SkillsDB.is_purchased(sid) and not unlock_all: return
	var fkey = SkillsDB.get_feature_key(sid)
	Global.set_feature_override(fkey, pressed)
	tree_view.queue_redraw()

func _on_skill_selected(_sid: String) -> void:
	_refresh_detail()

func _on_buy() -> void:
	var sid: String = tree_view.selected_id()
	if sid == "": return
	if SkillsDB.purchase(sid):
		AudioManager.play("ui_buy", 0.0, 0.04)
		# small celebration tween on token label
		var tw = create_tween()
		tw.tween_property(tokens_label, "scale", Vector2(1.25, 1.25), 0.10).set_trans(Tween.TRANS_BACK)
		tw.tween_property(tokens_label, "scale", Vector2.ONE, 0.18)
		# Enemy-unlock reward fanfare.
		var d = SkillsDB.SKILLS.get(sid, null)
		if d and d.get("branch", "") == "enemies":
			_show_enemy_unlock_fanfare(sid, d)
	else:
		AudioManager.play("ui_glass", -4.0, 0.05)
	_refresh()

var _ENEMY_UNLOCK_MESSAGES := {
	"enemies_basic":    ["Frogs & Kobolds\nhave entered the level!", "You now earn tokens faster!"],
	"enemy_sprites":    ["Enemies now have\nproper sprite art!", "They look scarier now."],
	"enemies_more":     ["Bats & Big Frogs\nare now gaurd the sky!", "You now earn tokens even faster!"],
	"enemies_advanced": ["Bombs, Drills &\nShooters arrive!", "You gain tokens at the best rate."],
	"smashers":         ["SMASHERS deployed!", "You have fully optimized token gain rate!"],
	#"sprite_explosion": ["Bombs explode\nin glorious animation!", "Boom."],
}

func _show_enemy_unlock_fanfare(sid: String, d: Dictionary) -> void:
	var msgs: Array = _ENEMY_UNLOCK_MESSAGES.get(sid, [d.get("name", sid) + "\nunlocked!"])
	var headline: String = msgs[0] if msgs.size() > 0 else "Unlocked!"
	var sub: String = msgs[1] if msgs.size() > 1 else ""

	var overlay := PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay.custom_minimum_size = Vector2(360, 0)
	overlay.z_index = 200
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.06, 0.16, 0.95)
	sb.border_color = Color(0.95, 0.45, 0.55, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 24; sb.content_margin_right = 24
	sb.content_margin_top = 20; sb.content_margin_bottom = 20
	overlay.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vbox)

	var icon_lbl := Label.new()
	icon_lbl.text = d.get("icon", "!!")
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 52)
	icon_lbl.add_theme_color_override("font_color", Color(0.95, 0.45, 0.55))
	vbox.add_child(icon_lbl)

	var title_lbl := Label.new()
	title_lbl.text = headline
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.88))
	vbox.add_child(title_lbl)

	if sub != "":
		var sub_lbl := Label.new()
		sub_lbl.text = sub
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_size_override("font_size", 18)
		sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.80))
		vbox.add_child(sub_lbl)

	add_child(overlay)
	overlay.modulate.a = 0.0
	overlay.scale = Vector2(0.6, 0.6)
	overlay.pivot_offset = overlay.size * 0.5

	var tw2 := create_tween()
	tw2.tween_property(overlay, "modulate:a", 1.0, 0.18)
	tw2.parallel().tween_property(overlay, "scale", Vector2(1.08, 1.08), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(overlay, "scale", Vector2.ONE, 0.10)
	tw2.tween_interval(1.6)
	tw2.tween_property(overlay, "modulate:a", 0.0, 0.28)
	tw2.tween_callback(overlay.queue_free)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
