extends Control

func _ready() -> void:
	$Menu/RetryButton.pressed.connect(_on_retry_pressed)
	$Menu/MenuButton.pressed.connect(_on_menu_pressed)

func _on_retry_pressed() -> void:
	GameManager.restart_level()

func _on_menu_pressed() -> void:
	GameManager.go_to_menu()
