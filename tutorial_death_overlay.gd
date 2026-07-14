extends CanvasLayer

const FONT_KA1 := preload("res://assets/fonts/ka1.ttf")
const FONT_PRIMITIVE := preload("res://assets/fonts/Terminus.ttf")
const BG_COLOR    := Color(0.02, 0.01, 0.03)
const PURPLE_TEXT := Color(0.60, 0.15, 0.90)
const PLAIN_TEXT  := Color(0.85, 0.85, 0.85)

var _step: int = 0
var _bg: ColorRect
var _comfort_label: Label
var _purple_label: Label
var _plain_label: Label
var _unlock_label: Label
var _typing: bool = false
var _typewriter_tw: Tween = null
var _glitching: bool = false
var _transitioning: bool = false
var _last_input_frame: int = -1
var _can_advance: bool = false  # FIX: was referenced in _start_glitch() but never declared

var game_over_ui: Node = null
var awarded: int = 0
var distance: int = 0

func _ready() -> void:
	layer = 200

	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = BG_COLOR
	_bg.modulate.a = 0.0
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_comfort_label = Label.new()
	_comfort_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_comfort_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_comfort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_comfort_label.add_theme_font_override("font", preload("res://assets/fonts/Nervous.ttf"))
	_comfort_label.add_theme_font_size_override("font_size", 32)
	_comfort_label.add_theme_color_override("font_color", PLAIN_TEXT)
	_comfort_label.text = "Oh dear. You died.\nDo not worry. This is a safe space.\nTake your time..."
	_comfort_label.visible_characters = 0
	_comfort_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_comfort_label)

	_purple_label = Label.new()
	_purple_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_purple_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_purple_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_purple_label.add_theme_font_override("font", FONT_KA1)
	_purple_label.add_theme_font_size_override("font_size", 48)
	_purple_label.add_theme_color_override("font_color", PURPLE_TEXT)
	_purple_label.text = "I'LL TAKE IT ALL NOW."
	_purple_label.modulate.a = 0.0
	_purple_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_purple_label)

	_plain_label = Label.new()
	_plain_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plain_label.add_theme_font_override("font", FONT_PRIMITIVE)
	_plain_label.add_theme_font_size_override("font_size", 28)
	_plain_label.add_theme_color_override("font_color", PLAIN_TEXT)
	_plain_label.text = "The game has been lost.\nOh no! Anyway...\nYou have to gain it back and build the MVP."
	_plain_label.modulate.a = 0.0
	_plain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plain_label)

	_unlock_label = Label.new()
	_unlock_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_unlock_label.add_theme_font_override("font", FONT_PRIMITIVE)
	_unlock_label.add_theme_font_size_override("font_size", 28)
	_unlock_label.add_theme_color_override("font_color", PLAIN_TEXT)
	_unlock_label.text = "TAP TO UNLOCK SHAPES:\nThe world will now at least have some squares and circles.\nSpend tokens in the Skill Tree to reveal more."
	_unlock_label.modulate.a = 0.0
	_unlock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_unlock_label)

	var tw := create_tween()
	tw.tween_property(_bg, "modulate:a", 1.0, 1.0)
	tw.tween_callback(func(): _start_typing())

func _start_typing() -> void:
	_typing = true
	_typewriter_tw = create_tween()
	var char_count = _comfort_label.text.length()
	var char_interval := 0.05
	for ci in char_count:
		_typewriter_tw.tween_callback(func():
			_comfort_label.visible_characters = ci + 1
			AudioManager.play("tick", -10.0, 0.06)
		)
		_typewriter_tw.tween_interval(char_interval)
	_typewriter_tw.tween_callback(func():
		_comfort_label.visible_characters = char_count
		_typing = false
		_start_glitch()
	)

func _start_glitch() -> void:
	if _step > 0: return
	_step = 1
	_typing = false
	_glitching = true
	_can_advance = false  # Lock input during glitch sequence
	if _typewriter_tw:
		_typewriter_tw.kill()
		_typewriter_tw = null
	_comfort_label.visible_characters = -1

	# Glitch SFX + glitch music — music plays through purple text, stops when
	# "unlock shapes" screen appears (music was taken, then returns for a moment).
	AudioManager.play_glitch_sequence(false)
	# Chromatic spike.
	if Global.is_unlocked("chromatic_aberration") and ScreenFX.has_method("kick_chromatic"):
		ScreenFX.kick_chromatic(0.04, 0.4)

	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("shake_camera"):
		player.shake_camera(20.0, 0.5)

	# Glitch out for a moment then show purple text
	var tw = create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func():
		_glitching = false
		_comfort_label.visible = false
		_purple_label.modulate.a = 1.0
		_bg.color = Color(0.2, 0.05, 0.3)
		var bg_tw = create_tween()
		bg_tw.tween_property(_bg, "color", BG_COLOR, 0.5)
	)
	tw.tween_interval(1.5)
	tw.tween_callback(func(): _can_advance = true)  # Unlock input after purple text settles

func _process(_delta: float) -> void:
	if _glitching:
		_comfort_label.position = Vector2(randf_range(-15.0, 15.0), randf_range(-10.0, 10.0))
		_comfort_label.modulate = Color(randf(), randf(), randf(), 1.0)

	if _step == 1 and not _glitching and _purple_label.modulate.a > 0.1:
		_purple_label.position = Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))

func _input(event: InputEvent) -> void:
	print("tap! step:", _step, " can_advance:", _can_advance, " transitioning:", _transitioning)
	var is_tap := false
	if event is InputEventScreenTouch and event.pressed:
		is_tap = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_tap = true
	elif event is InputEventKey and event.pressed and not event.echo:
		is_tap = true
	if not is_tap:
		return
	# One action per frame — deduplicate touch+mouse firing together.
	var frame := Engine.get_process_frames()
	if frame == _last_input_frame:
		return
	_last_input_frame = frame
	get_viewport().set_input_as_handled()
	if _typing:
		_start_glitch()
	elif _glitching or _transitioning:
		pass
	elif _can_advance and _step >= 1:  # FIX: guard with _can_advance so tap during glitch entry is ignored
		_advance()

func _advance() -> void:
	if _transitioning: return
	var advancing_step := _step
	_step += 1
	_can_advance = false  # Lock while transition plays; re-enabled at tween end
	if advancing_step == 1:
		_purple_label.position = Vector2.ZERO
		_transitioning = true
		var tw := create_tween()
		tw.tween_property(_purple_label, "modulate:a", 0.0, 0.4)
		tw.tween_interval(0.2)
		tw.tween_property(_plain_label, "modulate:a", 1.0, 0.6)
		tw.tween_callback(func():
			_transitioning = false
			_can_advance = true
		)
	elif advancing_step == 2:
		AudioManager.stop_music(0.6)
		_transitioning = true
		var tw := create_tween()
		tw.tween_property(_plain_label, "modulate:a", 0.0, 0.4)
		tw.tween_interval(0.2)
		tw.tween_property(_unlock_label, "modulate:a", 1.0, 0.6)
		tw.tween_callback(func():
			_transitioning = false
			_can_advance = true
		)
	elif advancing_step == 3:
		Global.tutorial_seen = true
		Global.save_state()
		queue_free()
		print("current reloadin")
		get_tree().change_scene_to_file("res://leve.tscn")
		#get_tree().reload_current_scene()
