extends Node
## 游戏管理器 - 关卡制闯关，控制生成、难度、升级系统（自动加载）

# 信号
signal game_started()
signal game_over()
signal level_changed(level: int, level_name: String)
signal wave_changed(current_wave: int, total_waves: int)
signal level_complete()

# 关卡数据: name/waves/enemies_per_wave/speed_mult/hp_mult/dmg_mult/background
const LEVELS: Array = [
	{"name": "训练场",     "waves": 3, "enemies_per_wave": 5,  "speed_mult": 1.0, "hp_mult": 1.0, "dmg_mult": 0.8, "background": "res://assets/textures/desert_background.jpg"},
	{"name": "幽暗森林",   "waves": 3, "enemies_per_wave": 7,  "speed_mult": 1.1, "hp_mult": 1.2, "dmg_mult": 1.0, "background": "res://assets/textures/desert_background.jpg"},
	{"name": "血腥矿洞",   "waves": 4, "enemies_per_wave": 8,  "speed_mult": 1.2, "hp_mult": 1.4, "dmg_mult": 1.1, "background": "res://assets/textures/desert_background.jpg"},
	{"name": "亡灵墓地",   "waves": 4, "enemies_per_wave": 10, "speed_mult": 1.3, "hp_mult": 1.6, "dmg_mult": 1.2, "background": "res://assets/textures/desert_background.jpg"},
	{"name": "烈焰火山",   "waves": 5, "enemies_per_wave": 10, "speed_mult": 1.4, "hp_mult": 1.8, "dmg_mult": 1.3, "background": "res://assets/textures/desert_background.jpg"},
	{"name": "冰封王座",   "waves": 5, "enemies_per_wave": 12, "speed_mult": 1.5, "hp_mult": 2.0, "dmg_mult": 1.4, "background": "res://assets/textures/desert_background.jpg"},
	{"name": "虚空深渊",   "waves": 6, "enemies_per_wave": 12, "speed_mult": 1.6, "hp_mult": 2.5, "dmg_mult": 1.5, "background": "res://assets/textures/desert_background.jpg"},
	{"name": "最终试炼",   "waves": 8, "enemies_per_wave": 15, "speed_mult": 1.8, "hp_mult": 3.0, "dmg_mult": 1.8, "background": "res://assets/textures/desert_background.jpg"},
]

# 敌人场景
var enemy_scene: PackedScene
var xp_gem_scene: PackedScene

# 已加载的敌人数据资源
var _enemy_data_cache: Dictionary = {}  # key: EnemyData.BehaviorType -> EnemyData

# 关卡状态
var current_level: int = 0
var current_wave: int = 1
var total_waves: int = 3
var wave_enemies_spawned: int = 0
var wave_enemies_total: int = 5
var wave_enemies_alive: int = 0
var is_level_transition: bool = false
var spawn_wave_paused: bool = false

# 游戏状态
var game_time: float = 0.0
var is_game_over: bool = false
var enemies_killed: int = 0

# 生成参数
var spawn_timer: float = 0.0
var spawn_interval: float = 0.8
var wave_transition_timer: float = 0.0

# 难度参数
var speed_mult: float = 1.0
var hp_mult: float = 1.0
var dmg_mult: float = 1.0

# 玩家引用
var player: Node2D = null
# 屏幕尺寸（由 main.gd 设置）
var screen_size: Vector2 = Vector2(2560, 1440)

@onready var hud: CanvasLayer


func _ready() -> void:
	enemy_scene = load("res://scenes/enemy.tscn")
	xp_gem_scene = load("res://scenes/xp_gem.tscn")
	# 预加载所有敌人数据
	_load_enemy_data()


## 预加载敌人预设数据
func _load_enemy_data() -> void:
	_enemy_data_cache[EnemyData.BehaviorType.CHASER]   = load("res://resources/enemy_chaser.tres")
	_enemy_data_cache[EnemyData.BehaviorType.TANK]     = load("res://resources/enemy_tank.tres")
	_enemy_data_cache[EnemyData.BehaviorType.RUSHER]   = load("res://resources/enemy_rusher.tres")
	_enemy_data_cache[EnemyData.BehaviorType.EXPLODER] = load("res://resources/enemy_exploder.tres")


func start_game() -> void:
	# 清理上一局的敌人、宝石、弹幕
	for group in ["enemies", "xp_gems", "projectiles"]:
		var nodes = get_tree().get_nodes_in_group(group)
		for node in nodes:
			if is_instance_valid(node):
				node.queue_free()

	current_level = 0
	current_wave = 1
	is_game_over = false
	enemies_killed = 0
	game_time = 0.0
	is_level_transition = false
	spawn_wave_paused = false

	emit_signal("game_started")
	start_level(current_level)


## 获取当前关卡配置的背景图路径，未配置则返回空字符串
func get_current_background_path() -> String:
	if current_level < LEVELS.size():
		return LEVELS[current_level].get("background", "")
	return ""


## 开始新关卡
func start_level(level_idx: int) -> void:
	if level_idx >= LEVELS.size():
		# 通关！
		end_game()
		return

	var level_data = LEVELS[level_idx]
	current_level = level_idx
	current_wave = 1
	total_waves = level_data.waves
	speed_mult = level_data.speed_mult
	hp_mult = level_data.hp_mult
	dmg_mult = level_data.dmg_mult
	spawn_interval = 0.8
	is_level_transition = false

	emit_signal("level_changed", level_idx + 1, level_data.name)
	start_wave()


## 开始一波
func start_wave() -> void:
	if current_wave > total_waves:
		# 关卡完成
		on_level_complete()
		return

	var level_data = LEVELS[current_level]
	wave_enemies_total = level_data.enemies_per_wave
	wave_enemies_spawned = 0
	wave_enemies_alive = 0
	spawn_timer = 0.0
	spawn_wave_paused = false

	emit_signal("wave_changed", current_wave, total_waves)


## 关卡完成
func on_level_complete() -> void:
	is_level_transition = true
	emit_signal("level_complete")
	# 暂停游戏，显示奖励选择
	get_tree().paused = true
	if hud and hud.has_method("show_level_reward_ui"):
		hud.show_level_reward_ui(generate_reward_options())


## 选择奖励后进入下一关
func advance_to_next_level() -> void:
	if is_game_over:
		return
	get_tree().paused = false
	current_level += 1
	current_wave = 1
	start_level(current_level)


func _process(delta: float) -> void:
	if is_game_over or is_level_transition:
		return

	game_time += delta

	# 检查波次过渡计时器
	if spawn_wave_paused:
		wave_transition_timer -= delta
		if wave_transition_timer <= 0:
			current_wave += 1
			start_wave()

	# 生成敌人
	if not spawn_wave_paused and wave_enemies_spawned < wave_enemies_total:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_enemy()
			wave_enemies_spawned += 1
			wave_enemies_alive += 1
			spawn_timer = spawn_interval

	# 检查波次完成
	_check_wave_complete()

	# 更新HUD
	if hud and hud.has_method("update_hud"):
		hud.update_hud()


## 检查波次是否完成
func _check_wave_complete() -> void:
	if not spawn_wave_paused and wave_enemies_spawned >= wave_enemies_total and wave_enemies_alive <= 0:
		spawn_wave_paused = true
		wave_transition_timer = 1.5


## 生成一个敌人
func spawn_enemy() -> void:
	if not enemy_scene or not player:
		return

	var new_enemy = enemy_scene.instantiate()

	# 根据波次和关卡选择敌人类型
	var enemy_data := _pick_enemy_data()
	new_enemy.data = enemy_data

	var spawn_parent = get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = self
	spawn_parent.add_child(new_enemy)

	# 随机边缘生成
	var side = randi() % 4
	var spawn_pos: Vector2
	match side:
		0: spawn_pos = Vector2(randf_range(0, screen_size.x), -40)
		1: spawn_pos = Vector2(randf_range(0, screen_size.x), screen_size.y + 40)
		2: spawn_pos = Vector2(-40, randf_range(0, screen_size.y))
		3: spawn_pos = Vector2(screen_size.x + 40, randf_range(0, screen_size.y))
	new_enemy.global_position = spawn_pos

	# 连接死亡信号
	if new_enemy.has_signal("died"):
		new_enemy.died.connect(_on_enemy_died)

	# 应用关卡难度缩放（_ready() 已从 data 读取基础值，这里叠乘）
	new_enemy.max_health *= hp_mult
	new_enemy.health = new_enemy.max_health
	new_enemy.speed *= speed_mult
	new_enemy.damage *= dmg_mult
	new_enemy.xp_drop *= (1.0 + current_level * 0.15)


## 根据当前波次/关卡智能选择敌人类型
func _pick_enemy_data() -> EnemyData:
	var available_types: Array[EnemyData.BehaviorType] = []

	# 第一关（训练场）只出追猎者
	if current_level == 0 and current_wave <= 2:
		available_types = [EnemyData.BehaviorType.CHASER]
	else:
		# 根据关卡解锁更多敌人类型
		available_types.append(EnemyData.BehaviorType.CHASER)
		if current_level >= 1:
			available_types.append(EnemyData.BehaviorType.RUSHER)
		if current_level >= 2:
			available_types.append(EnemyData.BehaviorType.TANK)
		if current_level >= 4:
			available_types.append(EnemyData.BehaviorType.EXPLODER)

	var chosen_type := available_types[randi() % available_types.size()]
	var cached := _enemy_data_cache.get(chosen_type) as EnemyData
	if cached == null:
		# 后备：用默认数据
		return _enemy_data_cache.get(EnemyData.BehaviorType.CHASER) as EnemyData
	return cached


## 敌人死亡
func _on_enemy_died(pos: Vector2, xp_amount: float) -> void:
	enemies_killed += 1
	wave_enemies_alive -= 1

	# 第一关（训练场）不掉落经验，强迫玩家用初始属性通关
	if current_level == 0:
		return

	if xp_gem_scene:
		var spawn_parent = get_tree().current_scene
		if spawn_parent == null:
			spawn_parent = self
		var gem = xp_gem_scene.instantiate()
		spawn_parent.add_child(gem)
		gem.global_position = pos
		gem.xp_amount = xp_amount


## 玩家升级（经验满时触发）
func on_player_leveled_up(_level: int) -> void:
	get_tree().paused = true
	if hud and hud.has_method("show_upgrade_ui"):
		hud.show_upgrade_ui(generate_upgrade_options())


## 生成升级选项（通关奖励/升级通用）
func generate_upgrade_options() -> Array:
	var options = [
		{"name": "攻击力+", "desc": "伤害 +20%", "type": "damage"},
		{"name": "攻速+",   "desc": "攻速 +15%", "type": "fire_rate"},
		{"name": "移动速度+", "desc": "移速 +15%", "type": "speed"},
		{"name": "生命上限+", "desc": "最大生命 +20", "type": "max_hp"},
		{"name": "子弹数量+", "desc": "子弹 +1", "type": "projectile_count"},
		{"name": "穿透+",   "desc": "穿透 +1", "type": "pierce"},
		{"name": "暴击率+", "desc": "暴击率 +10%", "type": "crit_rate"},
		{"name": "暴击伤害+", "desc": "暴击伤害 x1.5", "type": "crit_dmg"},
		{"name": "吸血+",   "desc": "吸血 +5%", "type": "life_steal"},
		{"name": "子弹速度+", "desc": "子弹速度 +15%", "type": "speed_bullet"},
		{"name": "吸附范围+", "desc": "宝石吸附范围 +30%", "type": "magnet"},
		{"name": "攻击范围+", "desc": "近战/子弹范围 +10%", "type": "range"},
	]
	options.shuffle()
	return options.slice(0, 3)


## 生成通关奖励（与升级选项相同）
func generate_reward_options() -> Array:
	return generate_upgrade_options()


## 应用升级/奖励
func apply_upgrade(type: String) -> void:
	if not player:
		player = find_player()
	if not player:
		return

	match type:
		"damage":
			player.bonus_damage += 0.2
			if player.weapon:
				player.weapon.bonus_damage += 5.0
		"fire_rate":
			if player.weapon:
				player.weapon.bonus_fire_rate += 0.08
		"speed":
			player.bonus_speed += 40.0
		"max_hp":
			player.bonus_max_hp += 20.0
			player.health = min(player.health + 20.0, player.get_max_health())
		"projectile_count":
			if player.weapon:
				player.weapon.bonus_projectile_count += 1
		"pierce":
			if player.weapon:
				player.weapon.bonus_pierce += 1
		"crit_rate":
			if player.weapon:
				player.weapon.crit_chance = min(1.0, player.weapon.crit_chance + 0.1)
		"crit_dmg":
			if player.weapon:
				player.weapon.crit_multiplier += 0.5
		"life_steal":
			if player.weapon:
				player.weapon.life_steal = min(0.5, player.weapon.life_steal + 0.05)
		"speed_bullet":
			if player.weapon:
				player.weapon.bonus_speed += 100.0
		"magnet":
			# 所有经验宝石的吸附范围会被 player 的 bonus 影响
			pass
		"range":
			if player.weapon:
				player.weapon.bonus_range += 10.0

	get_tree().paused = false


## 应用通关奖励
func apply_reward(type: String) -> void:
	if type == "next_level":
		advance_to_next_level()
	else:
		apply_upgrade(type)


## 寻找玩家
func find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("players")
	if not players.is_empty():
		return players[0] as Node2D
	return null


## 游戏结束
func end_game() -> void:
	is_game_over = true
	emit_signal("game_over")
	get_tree().paused = true
