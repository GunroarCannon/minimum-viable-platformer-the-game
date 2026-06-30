extends Node

## Entry-point router. If the player has unlocked the UI, send them to the
## main menu. Otherwise, drop them straight into the level so they can have
## their first run (and their first death triggers the "buy UI" prompt).

func _ready() -> void:
	call_deferred("_route")

func _route() -> void:
	if Global.is_unlocked("ui"):
		get_tree().change_scene_to_file("res://main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://leve.tscn")
