@tool
extends CanvasLayer
class_name GameOverUI

@onready var retry_random_button: Button = $CenterContainer/VBoxContainer/RetryRandomButton
@onready var retry_seed_button: Button = $CenterContainer/VBoxContainer/RetrySeedButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

func _ready() -> void:
	if not Engine.is_editor_hint():
		# Hide during normal gameplay
		visible = false
		if retry_random_button:
			retry_random_button.pressed.connect(_on_retry_random_button_pressed)
		if retry_seed_button:
			retry_seed_button.pressed.connect(_on_retry_seed_button_pressed)
		if exit_button:
			exit_button.pressed.connect(_on_exit_button_pressed)

func show_game_over() -> void:
	visible = true

func _on_retry_random_button_pressed() -> void:
	# Reset the static seed to 0 so the generator rolls a new one
	var level_gen = load("res://level_generator.gd")
	if level_gen:
		level_gen.current_seed = 0
	get_tree().reload_current_scene()

func _on_retry_seed_button_pressed() -> void:
	# Leaves current_seed intact, reloads the exact same layout
	get_tree().reload_current_scene()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
