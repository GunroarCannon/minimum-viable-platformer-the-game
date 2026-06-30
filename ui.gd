extends CanvasLayer
class_name GameOverUI

# Two modes:
#   PRE-UI       (no "ui" feature unlocked yet) — bare prompt to buy UI.
#   POST-UI      (ui unlocked) — proper game-over screen with shop/menu links.

@onready var dim: ColorRect      = $Dim
@onready var center: CenterContainer = $Center
@onready var box: VBoxContainer  = $Center/Box
@onready var title_label: Label  = $Center/Box/Title
@onready var tokens_earned_label: Label = $Center/Box/Earned
@onready var hint_label: Label   = $Center/Box/Hint

@onready var btn_buy_ui: Button   = $Center/Box/Buttons/BuyUIButton
@onready var btn_retry: Button    = $Center/Box/Buttons/RetryButton
@onready var btn_shop: Button     = $Center/Box/Buttons/ShopButton
@onready var btn_menu: Button     = $Center/Box/Buttons/MenuButton
@onready var btn_exit: Button     = $Center/Box/Buttons/ExitButton

func _ready() -> void:
	visible = false
	btn_buy_ui.pressed.connect(_on_buy_ui)
	btn_retry.pressed.connect(_on_retry)
	btn_shop.pressed.connect(_on_shop)
	btn_menu.pressed.connect(_on_menu)
	btn_exit.pressed.connect(_on_exit)

func show_game_over(tokens_awarded: int = 0, distance_m: int = 0) -> void:
	visible = true
	# Configure depending on UI unlock state.
	var has_ui := Global.is_unlocked("ui")
	if has_ui:
		_configure_post_ui(tokens_awarded, distance_m)
	else:
		_configure_pre_ui(tokens_awarded)
	# Apply theme last so disabled-button visuals look right.
	UITheme.apply_current(self)
	_play_in_tween()

func _configure_pre_ui(tokens_awarded: int) -> void:
	title_label.text = "you died."
	tokens_earned_label.text = "+%d ★ token" % tokens_awarded
	hint_label.text = "Buy UI to unlock the menus, shop and more."
	btn_buy_ui.visible = true
	btn_buy_ui.text = "Buy UI (1 ★)"
	btn_buy_ui.disabled = Global.tokens < 1
	btn_retry.visible = true
	btn_retry.text = "Run again"
	btn_shop.visible = false
	btn_menu.visible = false
	btn_exit.visible = true

func _configure_post_ui(tokens_awarded: int, distance_m: int) -> void:
	title_label.text = "you died."
	tokens_earned_label.text = "+%d ★   |   %d m" % [tokens_awarded, distance_m]
	hint_label.text = "Spend tokens in the shop to unlock more."
	btn_buy_ui.visible = false
	btn_retry.visible = true
	btn_retry.text = "Run again"
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
		# Bounce into the main menu now that we own it.
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
