extends Node2D
## 武器系统 - 支持多种武器类型（短刀/长剑/弓弩）

enum WeaponType { KNIFE, SWORD, CROSSBOW }

# 当前武器类型
@export var weapon_type: int = WeaponType.KNIFE

# 武器预设数据
const WEAPON_DATA: Dictionary = {
	WeaponType.KNIFE: {
		"name": "短刀",
		"damage": 8.0,
		"fire_rate": 0.35,
		"speed": 700.0,
		"pierce": 2,
		"range": 1.5,      # 弹幕存活时间（秒）
		"count": 1,
		"spread": 10.0,
		"anim": "knife"
	},
	WeaponType.SWORD: {
		"name": "长剑",
		"damage": 18.0,
		"fire_rate": 0.55,
		"speed": 0.0,
		"pierce": 999,
		"range": 75.0,     # 弧斩半径
		"count": 1,
		"arc_angle": 120.0,
		"anim": "sword"
	},
	WeaponType.CROSSBOW: {
		"name": "弓弩",
		"damage": 30.0,
		"fire_rate": 1.0,
		"speed": 900.0,
		"pierce": 3,
		"range": 3.0,
		"count": 1,
		"spread": 5.0,
		"anim": "crossbow"
	}
}

# 当前武器属性（受升级影响）
var current_data: Dictionary = {}
var bonus_fire_rate: float = 0.0
var bonus_damage: float = 0.0
var bonus_projectile_count: int = 0
var bonus_pierce: int = 0
var bonus_speed: float = 0.0
var bonus_range: float = 0.0
var crit_chance: float = 0.0
var crit_multiplier: float = 1.5
var life_steal: float = 0.0

var fire_timer: float = 0.0
var player: CharacterBody2D

# 弹幕场景
var projectile_scene: PackedScene
var melee_attack_scene: PackedScene


func _ready() -> void:
	player = get_parent() as CharacterBody2D
	projectile_scene = load("res://scenes/projectile.tscn")
	_apply_weapon_data()


## 应用当前武器数据
func _apply_weapon_data() -> void:
	current_data = WEAPON_DATA[weapon_type].duplicate()


## 切换武器
func switch_weapon(type: int) -> void:
	weapon_type = type
	_apply_weapon_data()
	fire_timer = 0.0


## 获取武器显示名称
func get_weapon_name() -> String:
	return current_data.get("name", "未知")


func _process(delta: float) -> void:
	# 武器发射
	fire_timer -= delta
	if fire_timer <= 0:
		fire()
		var rate = max(0.05, current_data.fire_rate - bonus_fire_rate)
		fire_timer = rate

	# 近战视觉更新
	if melee_visual_timer > 0:
		melee_visual_timer -= delta
		queue_redraw()


## 发射攻击
func fire() -> void:
	match weapon_type:
		WeaponType.SWORD:
			fire_melee()
		WeaponType.KNIFE, WeaponType.CROSSBOW:
			fire_projectile()


## 获取伤害（含暴击计算）
func get_final_damage(base_damage: float) -> float:
	var dmg = base_damage + bonus_damage + (player.get_damage_bonus() if player else 0)
	# 暴击
	if crit_chance > 0 and randf() < crit_chance:
		dmg *= crit_multiplier
	return dmg


## 远程武器 - 发射弹幕
func fire_projectile() -> void:
	if not projectile_scene or not player:
		return
	var target = find_nearest_enemy()
	if target == null:
		return

	var total_count = current_data.count + bonus_projectile_count
	var damage = get_final_damage(current_data.damage)
	var total_pierce = current_data.pierce + bonus_pierce

	if total_count == 1:
		var dir = global_position.direction_to(target.global_position)
		_spawn_projectile(global_position, dir, damage, total_pierce)
	else:
		var dir = global_position.direction_to(target.global_position)
		var base_angle = dir.angle()
		var total_spread = deg_to_rad(current_data.get("spread", 10.0))
		var step = total_spread / max(1, total_count - 1)
		for i in range(total_count):
			var angle = base_angle - total_spread / 2.0 + step * i
			var d = Vector2(cos(angle), sin(angle))
			_spawn_projectile(global_position, d, damage, total_pierce)


## 生成一颗弹幕
func _spawn_projectile(pos: Vector2, dir: Vector2, damage: float, pierce: int) -> void:
	var proj = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = pos
	var spd = current_data.speed + bonus_speed
	var lifetime = current_data.range + bonus_range * 0.1
	proj.setup(dir, spd, damage, pierce, lifetime, life_steal)


## 近战武器 - 弧斩攻击
func fire_melee() -> void:
	if not player:
		return

	# 获取最近的敌人
	var target = find_nearest_enemy()
	if target == null:
		return

	var damage = get_final_damage(current_data.damage)
	var range_radius = current_data.range + bonus_range
	var arc_angle = deg_to_rad(current_data.get("arc_angle", 120.0))

	# 向目标方向进行弧斩检测
	var dir = global_position.direction_to(target.global_position)
	var base_angle = dir.angle()

	# 获取所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var to_enemy = enemy.global_position - global_position
		var dist = to_enemy.length()
		if dist > range_radius:
			continue
		var angle_diff = abs(to_enemy.angle() - base_angle)
		# 归一化角度差
		while angle_diff > PI:
			angle_diff -= 2 * PI
		while angle_diff < -PI:
			angle_diff += 2 * PI
		if abs(angle_diff) <= arc_angle / 2.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			# 吸血
			if life_steal > 0 and player and player.has_method("heal"):
				player.heal(damage * life_steal)

	# 弧斩视觉提示 - 用 _draw 方式
	queue_melee_visual(dir, range_radius, arc_angle)


## 弧斩视觉提示
var melee_visual_timer: float = 0.0
var melee_visual_dir: Vector2 = Vector2.RIGHT
var melee_visual_radius: float = 75.0
var melee_visual_angle: float = 2.0  # rad

func queue_melee_visual(dir: Vector2, radius: float, angle: float) -> void:
	melee_visual_timer = 0.15
	melee_visual_dir = dir
	melee_visual_radius = radius
	melee_visual_angle = angle


func _process_melee_visual(delta: float) -> bool:
	if melee_visual_timer > 0:
		melee_visual_timer -= delta
		queue_redraw()
		return true
	return false


func _draw() -> void:
	# 绘制弧斩视觉效果
	if melee_visual_timer > 0:
		var alpha = melee_visual_timer / 0.15
		var color = Color(1.0, 0.8, 0.2, alpha * 0.6)
		var base_angle = melee_visual_dir.angle()
		# 绘制扇形弧斩
		var points_count = 20
		var points = PackedVector2Array()
		points.append(Vector2.ZERO)
		for i in range(points_count + 1):
			var t = float(i) / points_count
			var angle = base_angle - melee_visual_angle / 2.0 + melee_visual_angle * t
			var p = Vector2(cos(angle), sin(angle)) * melee_visual_radius
			points.append(p)
		draw_colored_polygon(points, color)
	else:
		# 武器图标小标记
		match weapon_type:
			WeaponType.KNIFE:
				draw_line(Vector2.ZERO, Vector2(12, 0), Color(0.8, 0.8, 0.9), 2.0)
			WeaponType.SWORD:
				draw_line(Vector2.ZERO, Vector2(16, 0), Color(0.9, 0.9, 1.0), 3.0)
			WeaponType.CROSSBOW:
				draw_line(Vector2.ZERO, Vector2(14, 0), Color(0.6, 0.6, 0.8), 2.0)
				draw_line(Vector2(8, -3), Vector2(8, 3), Color(0.8, 0.6, 0.3), 2.0)


## 寻找最近的敌人
func find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	var nearest: Node2D = enemies[0]
	var nearest_dist: float = global_position.distance_squared_to(nearest.global_position)
	for enemy in enemies:
		var dist = global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist
	return nearest
