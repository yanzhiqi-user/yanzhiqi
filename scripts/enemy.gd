extends CharacterBody2D
## 敌人 - 支持多种行为类型，由 EnemyData 资源驱动

## 敌人模板数据
@export var data: EnemyData

# 信号
signal died(pos: Vector2, xp_amount: float)

# 运行时属性（由 data 驱动或由 GameManager 覆盖）
var health: float = 20.0
var max_health: float = 20.0
var speed: float = 80.0
var damage: float = 10.0
var xp_drop: float = 5.0
var contact_cooldown: float = 1.0

var player: Node2D = null
var contact_timer: float = 0.0
var hit_flash: float = 0.0

@onready var collision: CollisionShape2D = $CollisionShape2D

# 精灵图（如有则使用，不再绘制圆形）
@onready var _sprite: Sprite2D = $Sprite2D

# 血条
@onready var health_bar: ColorRect = $HealthBar


func _ready() -> void:
	add_to_group("enemies")
	# 碰撞层：敌人用 layer 2
	collision_layer = 2
	collision_mask = 1  # 只检测玩家层

	if data != null:
		# 从 EnemyData 加载配置
		max_health = data.base_health
		health = max_health
		speed = data.base_speed
		damage = data.damage
		xp_drop = data.xp_drop
		contact_cooldown = data.contact_cooldown
		# 动态调整碰撞体大小
		_update_collision_radius(data.collision_radius)

	if health_bar:
		health_bar.visible = false


## 根据 EnemyData 调整碰撞体半径
func _update_collision_radius(radius: float) -> void:
	if collision and collision.shape is CircleShape2D:
		var shape := collision.shape as CircleShape2D
		shape.radius = radius


func _process(delta: float) -> void:
	contact_timer -= delta
	if hit_flash > 0:
		hit_flash -= delta
		# 将闪白效果应用到精灵图（通过 modulate 高亮）
		if _sprite != null and _sprite.texture != null:
			_sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)
	else:
		# 恢复正常颜色
		if _sprite != null and _sprite.texture != null:
			_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = find_player()
		if player == null:
			return

	# 根据行为类型决定移动逻辑
	if data != null:
		match data.behavior:
			EnemyData.BehaviorType.EXPLODER:
				# 爆裂者：更快冲向玩家
				_exploder_move(delta)
			_:
				# 默认追踪移动
				_chase_move(delta)
	else:
		_chase_move(delta)

	var collision_info = move_and_collide(velocity * delta)

	# 与玩家碰撞造成伤害
	if collision_info and contact_timer <= 0:
		var collider = collision_info.get_collider()
		if collider == player and player.has_method("take_damage"):
			player.take_damage(damage)
			contact_timer = contact_cooldown
			# 爆裂者碰撞后立即爆炸
			if data and data.behavior == EnemyData.BehaviorType.EXPLODER:
				_explode()


## 标准追踪移动
func _chase_move(_delta: float) -> void:
	var dir: Vector2 = global_position.direction_to(player.global_position)
	velocity = dir * speed


## 爆裂者：高速冲向玩家 + 轻微随机偏移，更不可预测
func _exploder_move(delta: float) -> void:
	var dir: Vector2 = global_position.direction_to(player.global_position)
	# 加入轻微周期性偏移，让爆裂者路线飘忽
	var perp = Vector2(-dir.y, dir.x)
	var wobble = sin(global_position.length() * 0.02 + Time.get_ticks_msec() * 0.003) * 0.3
	dir = (dir + perp * wobble).normalized()
	velocity = dir * speed


## 寻找玩家
func find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("players")
	if not players.is_empty():
		return players[0] as Node2D
	return null


## 受到伤害
func take_damage(amount: float) -> void:
	health -= amount

	# 伤害闪白效果
	hit_flash = 0.1

	# 更新血条
	if health_bar:
		health_bar.visible = true
		var bar_width: float = 32.0 * max(0, health / max_health)
		health_bar.size.x = bar_width

	if health <= 0:
		die()


func _draw() -> void:
	# 如果存在精灵图纹理，使用精灵图代替绘制圆形
	if _sprite != null and _sprite.texture != null:
		return

	var outer_color: Color
	var inner_color: Color

	if data != null:
		outer_color = data.draw_color
		inner_color = data.draw_color_inner
	else:
		outer_color = Color(0.9, 0.2, 0.2)
		inner_color = Color(0.7, 0.1, 0.1)

	# 受击闪白
	if hit_flash > 0:
		outer_color = Color(1.0, 1.0, 1.0)

	var radius: float = data.collision_radius if data != null else 14.0

	draw_circle(Vector2.ZERO, radius, outer_color)
	draw_circle(Vector2.ZERO, radius * 0.55, inner_color)

	# 爆裂者额外标记：橙色高亮内圈
	if data and data.behavior == EnemyData.BehaviorType.EXPLODER:
		var pulse: float = sin(Time.get_ticks_msec() * 0.005) * 0.3 + 0.7
		draw_circle(Vector2.ZERO, radius * 0.3, Color(1.0, 0.8, 0.0, pulse))


## 死亡
func die() -> void:
	# 爆裂者：死亡时造成范围伤害 (内部也会触发像素爆炸特效)
	if data and data.behavior == EnemyData.BehaviorType.EXPLODER:
		_explode()
	else:
		# 普通僵尸死亡时播放像素爆炸特效
		_spawn_pixel_explosion()
	
	emit_signal("died", global_position, xp_drop)
	queue_free()


## 爆裂者爆炸
func _explode() -> void:
	if not is_instance_valid(player):
		return

	var dist := global_position.distance_to(player.global_position)
	if dist <= data.explosion_radius and player.has_method("take_damage"):
		player.take_damage(data.explosion_damage)

	# 像素爆炸视觉特效
	_spawn_pixel_explosion()


## 爆炸视觉特效（像素粉碎爆破）
func _spawn_pixel_explosion() -> void:
	var explosion := PixelExplosion.new()
	explosion.particle_amount = 2048
	explosion.explosion_lifetime = 1.0
	
	# 爆裂者使用更强烈的橙红色，普通僵尸使用暗红色
	if data and data.behavior == EnemyData.BehaviorType.EXPLODER:
		explosion.tint = Color(1.0, 0.3, 0.0, 1.0)
		explosion.particle_amount = 4096   # 更多粒子更壮观
		explosion.explosion_lifetime = 1.2
	else:
		explosion.tint = Color(0.9, 0.25, 0.1, 1.0)
	
	var parent := get_parent()
	if parent:
		parent.add_child(explosion)
		explosion.global_position = global_position
	
	# 使用 explode_from_sprite: 自动提取 Sprite2D 当前动画帧
	# 爆炸粒子只包含当前帧的像素，而非整个 spritesheet
	explosion.explode_from_sprite(_sprite)


## 设置难度缩放（根据游戏时间）
func scale_difficulty(difficulty_mult: float) -> void:
	max_health *= difficulty_mult
	health = max_health
	speed *= min(1.5, 1.0 + (difficulty_mult - 1.0) * 0.3)
	damage *= difficulty_mult
	xp_drop *= difficulty_mult
