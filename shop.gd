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

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	d_buy.pressed.connect(_on_buy)
	tree_view.skill_selected.connect(_on_skill_selected)
	UITheme.apply_current(self)
	legend.visible = false

	# Create the active-toggle checkbox and append it to the detail VBox.
	var detail_vbox = $Root/Body/Detail/Scroll/V
	_d_toggle = CheckBox.new()
	_d_toggle.text = "Feature active"
	_d_toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_toggle.visible = false
	detail_vbox.add_child(_d_toggle)
	_d_toggle.toggled.connect(_on_toggle_active)

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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
		_on_back()

func _refresh() -> void:
	tokens_label.text = "★  %d tokens" % Global.tokens
	title_label.text  = "Skill Tree"
	tree_view.queue_redraw()
	_refresh_detail()

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

	var purchased := SkillsDB.is_purchased(sid)
	var prereq := SkillsDB.prereqs_met(sid)
	var affordable := SkillsDB.can_afford(sid)

	if purchased:
		d_status.text = "OWNED"
		d_status.modulate = Color(0.30, 0.70, 0.30)
		d_buy.text = "Owned"
		d_buy.disabled = true
		# Show active toggle + hint for purchased skills.
		if _d_toggle:
			var fkey = SkillsDB.get_feature_key(sid)
			_d_toggle.visible = true
			_d_toggle.set_block_signals(true)
			_d_toggle.button_pressed = bool(Global.feature_overrides.get(fkey, true))
			_d_toggle.set_block_signals(false)
		if _d_toggle_hint:
			_d_toggle_hint.visible = true
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

func _on_toggle_active(pressed: bool) -> void:
	var sid: String = tree_view.selected_id()
	if sid == "" or not SkillsDB.is_purchased(sid): return
	var fkey = SkillsDB.get_feature_key(sid)
	Global.set_feature_override(fkey, pressed)
	tree_view.queue_redraw()

func _on_skill_selected(_sid: String) -> void:
	_refresh_detail()

func _on_buy() -> void:
	var sid: String = tree_view.selected_id()
	if sid == "": return
	if SkillsDB.purchase(sid):
		# small celebration tween on token label
		var tw = create_tween()
		tw.tween_property(tokens_label, "scale", Vector2(1.25, 1.25), 0.10).set_trans(Tween.TRANS_BACK)
		tw.tween_property(tokens_label, "scale", Vector2.ONE, 0.18)
	_refresh()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
