extends CanvasLayer

@onready var title_label: Label = $Root/TitleBox/Title
@onready var subtitle_label: Label = $Root/TitleBox/Subtitle
@onready var tokens_label: Label = $Root/TopBar/TokensLabel
@onready var best_label: Label = $Root/TopBar/BestLabel
@onready var play_btn: Button = $Root/Buttons/PlayButton
@onready var shop_btn: Button = $Root/Buttons/ShopButton
@onready var settings_btn: Button = $Root/Buttons/SettingsButton
@onready var exit_btn: Button = $Root/Buttons/ExitButton

var _bg_offset: float = 0.0


func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	shop_btn.pressed.connect(_on_shop)
	settings_btn.pressed.connect(_on_settings)
	exit_btn.pressed.connect(_on_exit)

	_refresh_labels()
	UITheme.apply_current(self)

	if Global.is_unlocked("main_menu_extras"):
		_play_title_intro_tween()

	# Hide focus rings on the buttons so the keyboard ones look clean.
	for b in [play_btn, shop_btn, settings_btn, exit_btn]:
		b.focus_mode = Control.FOCUS_ALL


func _refresh_labels() -> void:
	title_label.text = "gunroar's MVP"
	subtitle_label.text = "(Minimal Viable Platformer)"
	tokens_label.text = "★  %d  tokens" % Global.tokens
	best_label.text = "best:  %d m" % Global.best_distance


func _play_title_intro_tween() -> void:
	title_label.modulate.a = 0.0
	title_label.scale = Vector2(0.6, 0.6)
	title_label.pivot_offset = title_label.size * 0.5
	var tw = create_tween()
	tw.tween_property(title_label, "modulate:a", 1.0, 0.45)
	tw.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if Global.is_unlocked("main_menu_extras"):
		_bg_offset += delta * 12.0
		$Root.queue_redraw()


func _draw() -> void:
	# We're a CanvasLayer; drawing happens via the Root control's _draw.
	pass


func _on_play() -> void:
	get_tree().change_scene_to_file("res://leve.tscn")


func _on_shop() -> void:
	get_tree().change_scene_to_file("res://shop.tscn")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://settings.tscn")


func _on_exit() -> void:
	get_tree().quit()
