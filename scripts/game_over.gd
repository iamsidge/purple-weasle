extends Control

func _ready() -> void:
	$VBox/RetryButton.pressed.connect(_on_retry_pressed)
	$VBox/MenuButton.pressed.connect(_on_menu_pressed)

func _on_retry_pressed() -> void:
	GameManager.restart_level()

func _on_menu_pressed() -> void:
	GameManager.go_to_menu()
