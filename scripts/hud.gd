extends CanvasLayer
## HUD界面 - 关卡、波次、血条、升级/奖励选择、退出按钮

var player: Node2D = null
var game_manager: Node = null

# 技能图标映射 (type -> preloaded Texture2D)
const SKILL_ICONS: Dictionary = {
	"damage":            preload("res://assets/textures/skill_damage.jpg"),
	"fire_rate":         preload("res://assets/textures/skill_fire_rate.jpg"),
	"speed":             preload("res://assets/textures/skill_speed.jpg"),
	"max_hp":            preload("res://assets/textures/skill_max_hp.jpg"),
	"projectile_count":  preload("res://assets/textures/skill_projectile_count.jpg"),
	"pierce":            preload("res://assets/textures/skill_pierce.jpg"),
	"crit_rate":         preload("res://assets/textures/skill_crit_rate.jpg"),
	"crit_dmg":          preload("res://assets/textures/skill_crit_dmg.jpg"),
	"life_steal":        preload("res://assets/textures/skill_life_steal.jpg"),
	"speed_bullet":      preload("res://assets/textures/skill_speed_bullet.jpg"),
	"magnet":            preload("res://assets/textures/skill_magnet.jpg"),
	"range":             preload("res://assets/textures/skill_range.jpg"),
}

# UI元素引用
@onready var health_label: Label = $HealthLabel
@onready var health_bar: TextureProgressBar = $HealthBar
@onready var xp_label: Label = $XPLabel
@onready var xp_bar: TextureProgressBar = $XPBar
@onready var top_center_xp_bar: TextureProgressBar = $TopCenterXPBar
@onready var top_center_xp_label: Label = $TopCenterXPLabel
@onready var level_label: Label = $LevelLabel
@onready var weapon_label: Label = $WeaponLabel
@onready var timer_label: Label = $TimerLabel
@onready var kill_label: Label = $KillLabel

# 关卡信息
@onready var level_title: Label = $LevelTitle
@onready var wave_label: Label = $WaveLabel
@onready var wave_progress: TextureProgressBar = $WaveProgress

# 升级面板
@onready var upgrade_panel: Panel = $UpgradePanel
@onready var upgrade_option_1: Button = $UpgradePanel/Option1
@onready var upgrade_option_2: Button = $UpgradePanel/Option2
@onready var upgrade_option_3: Button = $UpgradePanel/Option3

# 通关奖励面板
@onready var reward_panel: Panel = $RewardPanel
@onready var reward_option_1: Button = $RewardPanel/Reward1
@onready var reward_option_2: Button = $RewardPanel/Reward2
@onready var reward_option_3: Button = $RewardPanel/Reward3
@onready var reward_title_label: Label = $RewardPanel/Title

# 游戏结束
@onready var game_over_label: Label = $GameOverLabel
@onready var restart_button: Button = $RestartButton
@onready var final_stats_label: Label = $FinalStats


func _ready() -> void:
	game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.game_started.connect(_on_game_started)
		game_manager.game_over.connect(_on_game_over)
		game_manager.level_changed.connect(_on_level_changed)
		game_manager.wave_changed.connect(_on_wave_changed)
		game_manager.level_complete.connect(_on_level_complete)

	# HUD 暂停时仍可交互（升级/奖励/游戏结束面板可见时不会被忽略）
	process_mode = PROCESS_MODE_WHEN_PAUSED

	upgrade_panel.hide()
	reward_panel.hide()
	game_over_label.hide()
	restart_button.hide()
	level_title.hide()
	final_stats_label.hide()

	upgrade_option_1.pressed.connect(_on_upgrade_option_1)
	upgrade_option_2.pressed.connect(_on_upgrade_option_2)
	upgrade_option_3.pressed.connect(_on_upgrade_option_3)
	reward_option_1.pressed.connect(_on_reward_option_1)
	reward_option_2.pressed.connect(_on_reward_option_2)
	reward_option_3.pressed.connect(_on_reward_option_3)
	restart_button.pressed.connect(_on_restart_pressed)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = find_player()
		if player == null:
			return
	update_hud()


## 寻找玩家
func find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("players")
	if not players.is_empty():
		return players[0] as Node2D
	return null


## 更新HUD
func update_hud() -> void:
	if not player or not is_instance_valid(player):
		return

	var max_hp = player.get_max_health()
	var hp_percent = (player.health / max_hp) * 100.0
	health_label.text = "HP: %d/%d" % [player.health, max_hp]
	health_bar.value = hp_percent

	var xp_percent = (player.experience / player.experience_to_next) * 100.0
	xp_label.text = "EXP: %d/%d" % [player.experience, player.experience_to_next]
	xp_bar.value = xp_percent
	top_center_xp_bar.value = xp_percent
	top_center_xp_label.text = "Lv.%d" % player.level

	level_label.text = "Lv.%d" % player.level

	# 武器名
	if player.weapon and player.weapon.has_method("get_weapon_name"):
		weapon_label.text = player.weapon.get_weapon_name()

	if game_manager:
		var time_seconds = int(game_manager.game_time)
		var mins = time_seconds / 60
		var secs = time_seconds % 60
		timer_label.text = "%02d:%02d" % [mins, secs]
		kill_label.text = "击杀: %d" % game_manager.enemies_killed

		# 波次进度
		var wave_progress_val = 0.0
		if game_manager.wave_enemies_total > 0:
			wave_progress_val = float(game_manager.wave_enemies_spawned) / float(game_manager.wave_enemies_total) * 100.0
		wave_progress.value = wave_progress_val


## 关卡变更
func _on_level_changed(level_num: int, level_name: String) -> void:
	level_title.text = "第 %d 关 - %s" % [level_num, level_name]
	level_title.show()
	# 3秒后淡出
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(level_title, "modulate:a", 0.0, 1.0)
	tween.tween_callback(level_title.hide)
	tween.tween_callback(func(): level_title.modulate.a = 1.0)


## 波次变更
func _on_wave_changed(current_wave: int, total_waves: int) -> void:
	wave_label.text = "波次 %d / %d" % [current_wave, total_waves]


## 为按钮设置技能图标和文本
func _setup_skill_button(button: Button, option: Dictionary) -> void:
	button.text = option.name + "\n" + option.desc
	button.disabled = false
	button.visible = true
	button.set_meta("upgrade_type", option.type)

	# 设置技能图标
	var icon: Texture2D = SKILL_ICONS.get(option.type) as Texture2D
	if icon:
		button.icon = icon
		button.expand_icon = true


## 显示升级面板
func show_upgrade_ui(options: Array) -> void:
	upgrade_panel.show()
	var buttons: Array[Button] = [upgrade_option_1, upgrade_option_2, upgrade_option_3]
	for i: int in range(3):
		if i < options.size():
			_setup_skill_button(buttons[i], options[i])
		else:
			buttons[i].visible = false


## 显示通关奖励面板
func show_level_reward_ui(options: Array) -> void:
	reward_panel.show()
	reward_title_label.text = "通关奖励！选择一个强化："

	var buttons: Array[Button] = [reward_option_1, reward_option_2, reward_option_3]
	for i: int in range(3):
		if i < options.size():
			_setup_skill_button(buttons[i], options[i])
		else:
			buttons[i].visible = false


## 按钮通用处理
func _handle_option_pressed(button: Button, panel: Panel) -> void:
	if not button.has_meta("upgrade_type"):
		return
	var type = button.get_meta("upgrade_type")
	panel.hide()

	if panel == reward_panel:
		# 通关奖励
		if game_manager and game_manager.has_method("apply_upgrade"):
			game_manager.apply_upgrade(type)
			# 延迟进入下一关
			game_manager.advance_to_next_level.call_deferred()
	else:
		# 常规升级
		if game_manager and game_manager.has_method("apply_upgrade"):
			game_manager.apply_upgrade(type)


func _on_upgrade_option_1() -> void: _handle_option_pressed(upgrade_option_1, upgrade_panel)
func _on_upgrade_option_2() -> void: _handle_option_pressed(upgrade_option_2, upgrade_panel)
func _on_upgrade_option_3() -> void: _handle_option_pressed(upgrade_option_3, upgrade_panel)
func _on_reward_option_1() -> void: _handle_option_pressed(reward_option_1, reward_panel)
func _on_reward_option_2() -> void: _handle_option_pressed(reward_option_2, reward_panel)
func _on_reward_option_3() -> void: _handle_option_pressed(reward_option_3, reward_panel)


func _on_game_started() -> void:
	game_over_label.hide()
	restart_button.hide()
	upgrade_panel.hide()
	reward_panel.hide()
	final_stats_label.hide()
	wave_label.text = "波次 1 / 3"


func _on_game_over() -> void:
	game_over_label.show()
	restart_button.show()
	if game_manager:
		final_stats_label.text = "击杀敌人: %d\n到达关卡: 第 %d 关" % [game_manager.enemies_killed, game_manager.current_level + 1]
		final_stats_label.show()


func _on_level_complete() -> void:
	pass  # 由 show_level_reward_ui 处理


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
