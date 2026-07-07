extends CanvasLayer
class_name GameOverUI

# Two modes:
#   PRE-UI       (no "ui" feature unlocked yet) — bare prompt to buy UI.
#   POST-UI      (ui unlocked) — proper game-over screen with shop/menu links.

@onready var dim: ColorRect      = $Dim
@onready var center: CenterContainer = $Center
@onready var box: VBoxContainer  = $Center/ScrollWrap/Box
@onready var title_label: Label  = $Center/ScrollWrap/Box/Title
@onready var tokens_earned_label: Label = $Center/ScrollWrap/Box/Earned
@onready var hint_label: Label   = $Center/ScrollWrap/Box/Hint

@onready var btn_buy_ui: Button   = $Center/ScrollWrap/Box/Buttons/BuyUIButton
@onready var btn_retry: Button    = $Center/ScrollWrap/Box/Buttons/RetryButton
@onready var btn_shop: Button     = $Center/ScrollWrap/Box/Buttons/ShopButton
@onready var btn_menu: Button     = $Center/ScrollWrap/Box/Buttons/MenuButton
@onready var btn_exit: Button     = $Center/ScrollWrap/Box/Buttons/ExitButton
@onready var buttons_box: VBoxContainer = $Center/ScrollWrap/Box/Buttons

## Dynamically created seed label + save button (only when library is unlocked).
var _seed_label: Label = null
var _save_btn: Button = null
var _replay_btn: Button = null
var _highscore_lbl: Label = null

## Dynamically created "Killed by …" label under the title.
var _cause_label: Label = null

func _ready() -> void:
	visible = false
	btn_buy_ui.pressed.connect(_on_buy_ui)
	btn_retry.pressed.connect(_on_retry)
	btn_shop.pressed.connect(_on_shop)
	btn_menu.pressed.connect(_on_menu)
	btn_exit.pressed.connect(_on_exit)

func show_game_over(tokens_awarded: int = 0, distance_m: int = 0) -> void:
	visible = true
	var has_ui := Global.is_unlocked("ui")
	if has_ui:
		_configure_post_ui(tokens_awarded, distance_m)
	else:
		_configure_pre_ui(tokens_awarded)

	# Bump the smaller labels so they stay readable on tight/mobile viewports.
	# The .tscn defaults are low (~14-18px); force overrides here.
	tokens_earned_label.add_theme_font_size_override("font_size", 32)
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_update_cause_label()

	# Show seed info when library is unlocked.
	_update_library_widgets()

	UITheme.apply_current(self)
	_play_in_tween()

func _update_cause_label() -> void:
	var cause: String = Global.last_death_cause
	if cause == "":
		if _cause_label:
			_cause_label.visible = false
		return
	if _cause_label == null:
		_cause_label = Label.new()
		_cause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cause_label.add_theme_font_size_override("font_size", 24)
		box.add_child(_cause_label)
		# Sit just under the title (index 0).
		box.move_child(_cause_label, 1)
	_cause_label.visible = true
	_cause_label.text = "Killed by %s" % cause

func _update_library_widgets() -> void:
	if not Global.is_unlocked("level_library"):
		if _seed_label: _seed_label.queue_free(); _seed_label = null
		if _save_btn:   _save_btn.queue_free();   _save_btn = null
		if _replay_btn: _replay_btn.queue_free(); _replay_btn = null
		if _highscore_lbl: _highscore_lbl.queue_free(); _highscore_lbl = null
		return

	if _seed_label == null:
		_seed_label = Label.new()
		_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_seed_label.add_theme_font_size_override("font_size", 22)
		box.add_child(_seed_label)
		box.move_child(_seed_label, box.get_child_count() - 2)  # before Buttons

	_seed_label.text = "Seed:  %s" % Global.seed_to_code(Global.current_run_seed)

	# Replay-same-level button — sits at the TOP of the buttons stack.
	if _replay_btn == null:
		_replay_btn = Button.new()
		_replay_btn.text = "↻  Replay this level"
		_replay_btn.custom_minimum_size = Vector2(360, 60)
		_replay_btn.pressed.connect(_on_replay_same)
		buttons_box.add_child(_replay_btn)
		buttons_box.move_child(_replay_btn, 0)

	# Highscore label — sits directly under replay.
	if _highscore_lbl == null:
		_highscore_lbl = Label.new()
		_highscore_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_highscore_lbl.add_theme_font_size_override("font_size", 22)
		buttons_box.add_child(_highscore_lbl)
		buttons_box.move_child(_highscore_lbl, 1)
	var best := _best_for_current_seed()
	_highscore_lbl.text = "Best on this seed:  %d m" % best

	# Favourite button — moved to the BOTTOM of the box, not the top.
	if _save_btn == null:
		_save_btn = Button.new()
		_save_btn.pressed.connect(_on_favourite_level)
		box.add_child(_save_btn)  # ends up as last child by default
	box.move_child(_save_btn, box.get_child_count() - 1)

	var already_fav := false
	for entry in Global.level_library:
		if int(entry.get("seed", 0)) == Global.current_run_seed:
			if bool(entry.get("favorite", false)):
				already_fav = true
			break
	_save_btn.text = "★  Favourited!" if already_fav else "★  Favourite this level"
	_save_btn.disabled = already_fav

func _best_for_current_seed() -> int:
	for entry in Global.level_library:
		if int(entry.get("seed", 0)) == Global.current_run_seed:
			return int(entry.get("distance", 0))
	return Global.last_run_distance

func _on_replay_same() -> void:
	var level_gen = load("res://level_generator.gd")
	if level_gen:
		level_gen.current_seed = Global.current_run_seed
	get_tree().reload_current_scene()

func _configure_pre_ui(tokens_awarded: int) -> void:
	title_label.text = "you died."
	tokens_earned_label.text = "+%d ★ token" % tokens_awarded
	hint_label.text = "Buy UI to unlock the menus, shop and more."
	btn_buy_ui.visible = true
	btn_buy_ui.text = "Buy UI (1 ★)"
	btn_buy_ui.disabled = Global.tokens < 1
	btn_retry.visible = true
	btn_retry.text = "New Level" if Global.is_unlocked("level_library") else "Run again"
	btn_shop.visible = false
	btn_menu.visible = false
	btn_exit.visible = true

func _configure_post_ui(tokens_awarded: int, distance_m: int) -> void:
	title_label.text = "you died."
	tokens_earned_label.text = "+%d ★   |   %d m" % [tokens_awarded, distance_m]
	hint_label.text = "Spend tokens in the shop to unlock more."
	btn_buy_ui.visible = false
	btn_retry.visible = true
	btn_retry.text = "New Level" if Global.is_unlocked("level_library") else "Run again"
	btn_shop.visible = true
	btn_shop.text = "Shop (%d ★)" % Global.tokens
	btn_menu.visible = true
	btn_exit.visible = true

func _play_in_tween() -> void:
	box.modulate.a = 0.0
	box.scale = Vector2(0.85, 0.85)
	box.pivot_offset = box.size * 0.5
	dim.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 0.30)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ─── BUTTON HANDLERS ──────────────────────────────────────────────────

func _on_buy_ui() -> void:
	if Global.tokens < 1: return
	if Global.spend(1):
		Global.grant("ui")
		get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_retry() -> void:
	var level_gen = load("res://level_generator.gd")
	if level_gen and not Global.debug_toggles.get("keep_seed", false):
		level_gen.current_seed = 0
	get_tree().reload_current_scene()

func _on_shop() -> void:
	get_tree().change_scene_to_file("res://shop.tscn")

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_exit() -> void:
	get_tree().quit()

func _on_favourite_level() -> void:
	for entry in Global.level_library:
		if int(entry.get("seed", 0)) == Global.current_run_seed:
			entry["favorite"] = true
			Global.save_state()
			if _save_btn:
				_save_btn.text = "★  Favourited!"
				_save_btn.disabled = true
			return
	# Not in library yet — add it now.
	Global.level_library.append({
		"seed": Global.current_run_seed,
		"distance": Global.last_run_distance,
		"favorite": true,
	})
	Global.save_state()
	if _save_btn:
		_save_btn.text = "★  Favourited!"
		_save_btn.disabled = true
