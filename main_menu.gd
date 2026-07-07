extends CanvasLayer

@onready var title_label: Label = $Root/TitleBox/Title
@onready var subtitle_label: Label = $Root/TitleBox/Subtitle
@onready var tokens_label: Label = $Root/TopBar/TokensLabel
@onready var best_label: Label = $Root/TopBar/BestLabel
@onready var play_btn: Button = $Root/Buttons/PlayButton
@onready var shop_btn: Button = $Root/Buttons/ShopButton
@onready var settings_btn: Button = $Root/Buttons/SettingsButton
@onready var exit_btn: Button = $Root/Buttons/ExitButton

var _library_btn: Button = null
var _stats_btn: Button = null
var _daily_btn: Button = null
var _bg_offset: float = 0.0


func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	shop_btn.pressed.connect(_on_shop)
	settings_btn.pressed.connect(_on_settings)
	exit_btn.pressed.connect(_on_exit)

	var buttons = $Root/Buttons

	# Daily level — inserted at the very top when unlocked.
	if Global.is_unlocked("daily_level"):
		_daily_btn = Button.new()
		_daily_btn.text = "☀ Daily Level"
		_daily_btn.custom_minimum_size = Vector2(360, 64)
		_daily_btn.pressed.connect(_on_daily)
		buttons.add_child(_daily_btn)
		buttons.move_child(_daily_btn, 1)

	# Level Library button — inserted before Settings when library is unlocked.
	if Global.is_unlocked("level_library"):
		_library_btn = Button.new()
		_library_btn.text = "Level Library"
		_library_btn.custom_minimum_size = Vector2(360, 64)
		_library_btn.pressed.connect(_on_library)
		buttons.add_child(_library_btn)
		buttons.move_child(_library_btn, 2)

	# Stats — inserted before Settings. When unlocked, Settings + Exit also
	# migrate to the top bar as compact icon buttons so the main VBox stays
	# short enough to fit at 720p.
	if Global.is_unlocked("stats_menu"):
		_stats_btn = Button.new()
		_stats_btn.text = "Stats"
		_stats_btn.custom_minimum_size = Vector2(360, 64)
		_stats_btn.pressed.connect(_on_stats)
		buttons.add_child(_stats_btn)
		buttons.move_child(_stats_btn, buttons.get_child_count() - 3)
		_promote_to_topbar()

	_refresh_labels()
	UITheme.apply_current(self)

	if Global.is_unlocked("main_menu_extras"):
		_play_title_intro_tween()

	if Global.is_unlocked("home_polish"):
		_apply_home_polish()

	for b in [play_btn, shop_btn, settings_btn, exit_btn]:
		b.focus_mode = Control.FOCUS_ALL


func _refresh_labels() -> void:
	title_label.text = "gunroar's MVP"
	subtitle_label.text = "(Minimal Viable Platformer)"
	tokens_label.text = "★  %d  tokens" % Global.tokens
	best_label.text = "best:  %d m" % Global.best_distance


func _promote_to_topbar() -> void:
	# Replace the big Settings row with a small ⚙ icon-button in the top bar,
	# and Exit with a × icon. Frees up ~130 px in the button stack.
	var topbar := $Root/TopBar

	var gear := Button.new()
	gear.text = "⚙"
	gear.tooltip_text = "Settings"
	gear.custom_minimum_size = Vector2(52, 52)
	gear.flat = true
	gear.add_theme_font_size_override("font_size", 28)
	gear.pressed.connect(_on_settings)
	topbar.add_child(gear)

	var quit_btn := Button.new()
	quit_btn.text = "×"
	quit_btn.tooltip_text = "Quit"
	quit_btn.custom_minimum_size = Vector2(52, 52)
	quit_btn.flat = true
	quit_btn.add_theme_font_size_override("font_size", 32)
	quit_btn.pressed.connect(_on_exit)
	topbar.add_child(quit_btn)

	settings_btn.visible = false
	exit_btn.visible = false

func _apply_home_polish() -> void:
	title_label.add_theme_font_size_override("font_size", 96)
	title_label.add_theme_color_override("font_color", Color(1.00, 0.74, 0.32))
	title_label.add_theme_color_override("font_outline_color", Color(0.18, 0.14, 0.10))
	title_label.add_theme_constant_override("outline_size", 12)
	subtitle_label.add_theme_font_size_override("font_size", 26)
	subtitle_label.add_theme_color_override("font_color", Color(0.99, 0.86, 0.72))

	# Gentle looping bob on the title.
	var tw := create_tween().set_loops()
	tw.tween_property(title_label, "position:y", title_label.position.y + 6.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title_label, "position:y", title_label.position.y, 1.4).set_trans(Tween.TRANS_SINE)

	# Beefier buttons — bigger, more space.
	for b in $Root/Buttons.get_children():
		if b is Button:
			b.custom_minimum_size = Vector2(420, 72)
			b.add_theme_font_size_override("font_size", 30)
	$Root/Buttons.add_theme_constant_override("separation", 18)

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
	pass


func _on_shop() -> void:
	get_tree().change_scene_to_file("res://shop.tscn")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://settings.tscn")


func _on_library() -> void:
	get_tree().change_scene_to_file("res://level_library.tscn")


func _on_stats() -> void:
	get_tree().change_scene_to_file("res://stats_view.tscn")


func _on_daily() -> void:
	var gen = load("res://level_generator.gd")
	if gen:
		gen.current_seed = _daily_seed()
	Global.is_daily_run = true
	get_tree().change_scene_to_file("res://leve.tscn")


func _on_play() -> void:
	Global.is_daily_run = false
	get_tree().change_scene_to_file("res://leve.tscn")


func _daily_seed() -> int:
	var d: Dictionary = Time.get_date_dict_from_system()
	# Combine YYYYMMDD into a deterministic seed then clamp to 4-char code range.
	var raw := int(d.year) * 10000 + int(d.month) * 100 + int(d.day)
	return raw % 923521


func _on_exit() -> void:
	get_tree().quit()
