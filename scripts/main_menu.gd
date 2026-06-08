extends Control

func _ready() -> void:
	$VBox/PlayButton.pressed.connect(_on_play_pressed)
	$VBox/QuitButton.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	GameManager.start_game()

func _on_quit_pressed() -> void:
	get_tree().quit()
