extends ColorRect
## 背景绘制器 - 负责菜单星空背景和氛围动画

var time: float = 0.0
var star_positions: Array = []
var star_brightness: Array = []
var bg_pulse: float = 0.0


func _ready() -> void:
	# 覆盖全屏
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.TRANSPARENT

	# 生成随机星星
	for i in range(200):
		star_positions.append(Vector2(
			randf_range(0, 2560),
			randf_range(0, 1440)
		))
		star_brightness.append(randf_range(0.3, 1.0))


func _process(delta: float) -> void:
	time += delta
	bg_pulse = sin(time * 0.5) * 0.5 + 0.5
	queue_redraw()


func _draw() -> void:
	# 不再绘制纯色背景 —— 背景图由 TextureRect 承载，这里只叠加氛围元素

	# 地平线氛围光
	var glow_color = Color(0.6, 0.05, 0.05, 0.08 + bg_pulse * 0.06)
	draw_rect(Rect2(Vector2(0, 1000), Vector2(2560, 440)), glow_color)

	# 星星
	for i in range(star_positions.size()):
		var pos = star_positions[i]
		var brightness = star_brightness[i]
		var twinkle = sin(time * (0.5 + brightness * 2.0) + i) * 0.3 + 0.7
		var alpha = brightness * twinkle * 0.8
		var size = 1.0 + brightness * 1.5
		draw_circle(pos, size, Color(1, 1, 1, alpha))

	# 底部装饰线
	draw_line(Vector2(400, 1000), Vector2(2160, 1000), Color(0.8, 0.2, 0.1, 0.3 + bg_pulse * 0.2), 2.0)
	draw_line(Vector2(600, 1020), Vector2(1960, 1020), Color(0.8, 0.2, 0.1, 0.15 + bg_pulse * 0.1), 1.0)

	# 简版敌人剪影
	var enemy_y = 1050.0
	for i in range(5):
		var ex = 400.0 + i * 440.0
		var pulse_offset = sin(time * 1.5 + i * 3.0) * 10.0
		draw_circle(Vector2(ex, enemy_y + pulse_offset), 14.0, Color(0.6, 0.1, 0.05, 0.25))
		draw_circle(Vector2(ex, enemy_y + pulse_offset), 8.0, Color(0.4, 0.05, 0.02, 0.15))
