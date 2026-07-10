extends CanvasLayer
## 主菜单 - 末日生存游戏开始界面

@onready var start_button: Button = $StartButton
@onready var title_label: Label = $TitleLabel


func _ready() -> void:
	# 设置为 1920x1080 窗口
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# 按钮连接
	start_button.pressed.connect(_on_start_pressed)

	# 标题入场动画
	title_label.modulate.a = 0.0
	var title_tween = create_tween()
	title_tween.tween_property(title_label, "modulate:a", 1.0, 1.5)

	# 按钮入场动画
	start_button.modulate.a = 0.0
	var btn_tween = create_tween()
	btn_tween.tween_interval(1.0)
	btn_tween.tween_property(start_button, "modulate:a", 1.0, 0.8)


func _on_start_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(start_button, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_callback(_start_game)


func _start_game() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
