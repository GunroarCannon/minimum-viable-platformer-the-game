extends CanvasLayer

@onready var root: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var panel: Panel = $Root/Center/Panel
@onready var btn_resume: Button = $Root/Center/Panel/V/Resume
@onready var btn_shop: Button = $Root/Center/Panel/V/Shop
@onready var btn_menu: Button = $Root/Center/Panel/V/Menu
@onready var btn_exit: Button = $Root/Center/Panel/V/Exit

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	btn_resume.pressed.connect(_resume)
	btn_shop.pressed.connect(_to_shop)
	btn_menu.pressed.connect(_to_menu)
	btn_exit.pressed.connect(func(): get_tree().quit())
	UITheme.apply_current(self)
	AudioManager.connect_ui_clicks(self)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_back") or event.is_action_pressed("ui_cancel"):
		if Global.is_unlocked("pause_menu"):
			if visible: _resume()
			else: _show()
			get_viewport().set_input_as_handled()
		else:
			if Global.is_unlocked("ui"):
				get_tree().change_scene_to_file("res://main_menu.tscn")
			else:
				get_tree().quit()
			get_viewport().set_input_as_handled()

func _show() -> void:
	visible = true
	get_tree().paused = true
	dim.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = panel.size * 0.5
	var tw = create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _resume() -> void:
	get_tree().paused = false
	visible = false

func _to_shop() -> void:
	get_tree().paused = false
	ComboSystem.reset()
	get_tree().change_scene_to_file("res://shop.tscn")

func _to_menu() -> void:
	get_tree().paused = false
	ComboSystem.reset()
	get_tree().change_scene_to_file("res://main_menu.tscn")
