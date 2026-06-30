extends CanvasLayer

@onready var tokens_label: Label = $Root/TopBar/TokensLabel
@onready var title_label: Label = $Root/TopBar/Title
@onready var back_btn: Button = $Root/TopBar/BackButton
@onready var tree_view: Control = $Root/Body/Tree
@onready var detail_panel: Panel = $Root/Body/Detail
@onready var d_name: Label = $Root/Body/Detail/V/Name
@onready var d_desc: Label = $Root/Body/Detail/V/Desc
@onready var d_cost: Label = $Root/Body/Detail/V/Cost
@onready var d_status: Label = $Root/Body/Detail/V/Status
@onready var d_buy: Button = $Root/Body/Detail/V/BuyButton
@onready var d_branch: Label = $Root/Body/Detail/V/Branch
@onready var legend: HBoxContainer = $Root/Legend

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	d_buy.pressed.connect(_on_buy)
	tree_view.skill_selected.connect(_on_skill_selected)
	UITheme.apply_current(self)
	_build_legend()
	_refresh()
	# Select root by default so the detail panel isn't empty.
	tree_view.set_selected(SkillsDB.ROOT_ID)
	_on_skill_selected(SkillsDB.ROOT_ID)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
		_on_back()

func _build_legend() -> void:
	for c in legend.get_children(): c.queue_free()
	for branch in SkillsDB.BRANCH_NAMES.keys():
		var item = HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		var swatch = ColorRect.new()
		swatch.color = SkillsDB.get_branch_color(branch)
		swatch.custom_minimum_size = Vector2(18, 18)
		item.add_child(swatch)
		var lab = Label.new()
		lab.text = SkillsDB.BRANCH_NAMES[branch]
		lab.add_theme_font_size_override("font_size", 16)
		item.add_child(lab)
		legend.add_child(item)
	UITheme.apply_current(legend)

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
		return
	var d = SkillsDB.SKILLS[sid]
	d_name.text = d["name"]
	d_desc.text = d["desc"]
	d_cost.text = "Cost: %d ★" % int(d["cost"])
	d_branch.text = "Branch: " + SkillsDB.BRANCH_NAMES.get(d["branch"], d["branch"])

	var purchased := SkillsDB.is_purchased(sid)
	var prereq := SkillsDB.prereqs_met(sid)
	var affordable := SkillsDB.can_afford(sid)

	if purchased:
		d_status.text = "OWNED"
		d_status.modulate = Color(0.30, 0.70, 0.30)
		d_buy.text = "Owned"
		d_buy.disabled = true
	elif not prereq:
		var missing := []
		for r in d.get("requires", []):
			if not SkillsDB.is_purchased(r):
				missing.append(SkillsDB.SKILLS[r]["name"])
		d_status.text = "Locked\nNeeds: " + ", ".join(missing)
		d_status.modulate = Color(0.65, 0.30, 0.25)
		d_buy.text = "Locked"
		d_buy.disabled = true
	elif not affordable:
		d_status.text = "Not enough tokens"
		d_status.modulate = Color(0.65, 0.45, 0.20)
		d_buy.text = "Need %d ★" % int(d["cost"])
		d_buy.disabled = true
	else:
		d_status.text = "Available"
		d_status.modulate = Color(0.18, 0.14, 0.10)
		d_buy.text = "Buy (%d ★)" % int(d["cost"])
		d_buy.disabled = false

func _on_skill_selected(sid: String) -> void:
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
