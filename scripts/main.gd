extends Node2D
## 主游戏场景 - 入口点，负责创建玩家和游戏世界

# 预加载场景
@export var player_scene: PackedScene
@export var hud_scene: PackedScene

# 游戏管理器引用
var game_manager: Node
var player: Node2D
var hud: CanvasLayer
var _bg_rect: TextureRect = null


func _ready() -> void:
	# 加载场景
	if not player_scene:
		player_scene = load("res://scenes/player.tscn")
	if not hud_scene:
		hud_scene = load("res://scenes/hud.tscn")

	# 获取游戏管理器
	game_manager = get_node("/root/GameManager")
	if game_manager:
		if not game_manager.game_over.is_connected(_on_game_over):
			game_manager.game_over.connect(_on_game_over)
		# 连接关卡切换信号 → 动态换背景
		if not game_manager.level_changed.is_connected(_on_level_changed):
			game_manager.level_changed.connect(_on_level_changed)

	# 先创建HUD（让HUD的_ready()先连接好所有信号）
	hud = hud_scene.instantiate() as CanvasLayer
	add_child(hud)

	# 在 HUD 上创建退出按钮（代码创建，不依赖 hud.tscn 场景文件）
	_create_exit_button_on_hud()

	# 创建玩家
	spawn_player()

	# 设置初始背景
	_set_background_for_current_level()

	# 将引用传递给管理器（HUD和玩家都已就绪）
	if game_manager:
		game_manager.player = player
		game_manager.hud = hud
		game_manager.screen_size = get_viewport_rect().size
		# 最后再启动游戏——此时HUD已连好所有信号，不会丢失游戏开始事件
		game_manager.start_game()


## 生成玩家
func spawn_player() -> void:
	if not player_scene:
		return

	player = player_scene.instantiate()
	add_child(player)
	player.add_to_group("players")

	# 将玩家放在屏幕中央
	var screen_center = get_viewport_rect().size / 2.0
	player.global_position = screen_center

	# 连接玩家信号
	if player.has_signal("leveled_up"):
		player.leveled_up.connect(_on_player_leveled_up)
	if player.has_signal("died"):
		player.died.connect(_on_player_died)


## 根据当前关卡切换背景图（响应 level_changed 信号）
func _on_level_changed(_level: int, _level_name: String) -> void:
	_set_background_for_current_level()


## 加载当前关卡配置的背景纹理并替换显示
func _set_background_for_current_level() -> void:
	var bg_path: String = ""
	if game_manager and game_manager.has_method("get_current_background_path"):
		bg_path = game_manager.get_current_background_path() as String

	if bg_path.is_empty():
		bg_path = "res://assets/textures/desert_background.jpg"

	var screen_size := get_viewport_rect().size
	var bg_texture := load(bg_path) as Texture2D

	if bg_texture == null:
		# 兜底：纯色背景
		if not _bg_rect:
			_bg_rect = TextureRect.new()
			_bg_rect.z_index = -10
			add_child(_bg_rect)
		_bg_rect.texture = null
		# 用 ColorRect 作为后备
		_ensure_fallback_bg(screen_size)
		return

	# 首次创建 / 复用已有节点
	if not _bg_rect:
		_bg_rect = TextureRect.new()
		_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_bg_rect.z_index = -10
		add_child(_bg_rect)

	_bg_rect.texture = bg_texture
	_bg_rect.size = screen_size
	_bg_rect.position = Vector2.ZERO


## 纯色兜底背景（纹理加载失败时）
func _ensure_fallback_bg(screen_size: Vector2) -> void:
	for child in get_children():
		if child is ColorRect and child.z_index == -10:
			return
	var fallback := ColorRect.new()
	fallback.color = Color(0.05, 0.05, 0.1)
	fallback.size = screen_size
	fallback.position = Vector2.ZERO
	fallback.z_index = -10
	add_child(fallback)


## 玩家升级
func _on_player_leveled_up(level: int) -> void:
	if game_manager:
		game_manager.on_player_leveled_up(level)


## 玩家死亡
func _on_player_died() -> void:
	if game_manager:
		game_manager.end_game()


func _on_game_over() -> void:
	pass


## 退出游戏（Escape 键 + 退出按钮共用）
func _exit_to_menu() -> void:
	print("[Main] 退出游戏，切换回主菜单...")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


## 统一输入处理：Escape 键 + 退出按钮区域鼠标点击
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_exit_to_menu()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp_size := get_viewport_rect().size
		# 退出按钮区域：右上角，x=vp.x-120 到 vp.x-16，y=64 到 96
		if event.position.x >= vp_size.x - 120.0 and event.position.x <= vp_size.x - 16.0 \
		   and event.position.y >= 64.0 and event.position.y <= 96.0:
			_exit_to_menu()


## 在 HUD CanvasLayer 上创建退出按钮（纯视觉 Label，点击由 _input 处理）
func _create_exit_button_on_hud() -> void:
	if not hud:
		return
	var lbl := Label.new()
	lbl.name = "ExitButton"
	hud.add_child(lbl)
	lbl.anchor_left = 1.0
	lbl.anchor_right = 1.0
	lbl.anchor_top = 0.0
	lbl.anchor_bottom = 0.0
	lbl.offset_left = -120.0
	lbl.offset_top = 64.0
	lbl.offset_right = -16.0
	lbl.offset_bottom = 96.0
	lbl.text = "退出游戏"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3, 1.0))
	print("[Main] 退出按钮已创建: ", lbl)
