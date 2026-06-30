extends CanvasLayer

@onready var back_btn: Button = $Root/TopBar/BackButton
@onready var title_label: Label = $Root/TopBar/Title

@onready var master_slider: HSlider = $Root/Panel/V/MasterRow/Slider
@onready var sfx_slider: HSlider = $Root/Panel/V/SFXRow/Slider
@onready var theme_option: OptionButton = $Root/Panel/V/ThemeRow/Option
@onready var debug_cb: CheckBox = $Root/Panel/V/DebugRow/CheckBox
@onready var primitives_cb: CheckBox = $Root/Panel/V/PrimitivesRow/CheckBox
@onready var unlock_all_cb: CheckBox = $Root/Panel/V/UnlockAllRow/CheckBox
@onready var reset_btn: Button = $Root/Panel/V/ResetButton

func _ready() -> void:
	back_btn.pressed.connect(_on_back)

	master_slider.value = Global.settings_cfg.get("master_volume", 0.8)
	sfx_slider.value = Global.settings_cfg.get("sfx_volume", 0.8)
	master_slider.value_changed.connect(func(v):
		Global.settings_cfg["master_volume"] = v
		Global.save_state()
		_apply_audio()
	)
	sfx_slider.value_changed.connect(func(v):
		Global.settings_cfg["sfx_volume"] = v
		Global.save_state()
		_apply_audio()
	)

	theme_option.add_item("Placeholder", 0)
	theme_option.add_item("Polished", 1)
	var cur := String(Global.settings_cfg.get("theme", "polished"))
	theme_option.selected = 1 if cur == "polished" else 0
	if not Global.is_unlocked("ui_polished"):
		theme_option.set_item_disabled(1, true)
		theme_option.selected = 0
	theme_option.item_selected.connect(func(i):
		Global.settings_cfg["theme"] = "polished" if i == 1 else "placeholder"
		Global.save_state()
		UITheme.apply_current(self)
	)

	debug_cb.button_pressed = Global.debug_toggles.get("show_overlay", true)
	debug_cb.toggled.connect(func(p):
		Global.debug_toggles["show_overlay"] = p
	)

	primitives_cb.button_pressed = Global.use_primitives
	primitives_cb.toggled.connect(func(p):
		Global.use_primitives = p
	)

	unlock_all_cb.button_pressed = Global.debug_toggles.get("unlock_all", false)
	unlock_all_cb.toggled.connect(func(p):
		Global.debug_toggles["unlock_all"] = p
	)

	reset_btn.pressed.connect(func():
		Global.reset_progress()
		title_label.text = "Settings (progress reset)"
	)
	title_label.text = "Settings"
	UITheme.apply_current(self)
	_apply_audio()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
		_on_back()

func _apply_audio() -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var v = float(Global.settings_cfg.get("master_volume", 0.8))
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(max(0.0001, v)))

func _on_back() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
