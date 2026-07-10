extends Area2D
## 弹幕 - 沿方向飞行，碰到敌人造成伤害

# 弹幕参数
var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var damage: float = 10.0
var pierce_count: int = 1      # 还能穿透几次
var lifetime: float = 3.0      # 生存时间
var life_steal: float = 0.0    # 吸血比例

@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# 添加到"弹幕"组
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	# 移动
	position += direction * speed * delta

	# 生命周期 - 超时自动销毁
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

	# 移出屏幕销毁
	var screen_size: Vector2 = get_viewport_rect().size
	if global_position.x < -50 or global_position.x > screen_size.x + 50 \
		or global_position.y < -50 or global_position.y > screen_size.y + 50:
		queue_free()


## 初始化设置
func setup(dir: Vector2, spd: float, dmg: float, pierce: int, life: float = 3.0, steal: float = 0.0) -> void:
	direction = dir
	speed = spd
	damage = dmg
	pierce_count = pierce
	lifetime = life
	life_steal = steal
	
	rotation = dir.angle()


## 碰到敌人
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		hit_enemy(body)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		hit_enemy(area)


## 命中敌人
func hit_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return

	var enemy_node: Node = enemy
	if enemy_node.has_method("take_damage"):
		enemy_node.take_damage(damage)

	# 吸血：按伤害百分比回复玩家生命
	if life_steal > 0:
		var players: Array[Node] = get_tree().get_nodes_in_group("players")
		if not players.is_empty():
			var p: Node = players[0]
			if p.has_method("heal"):
				p.heal(damage * life_steal)

	pierce_count -= 1
	if pierce_count < 0:
		queue_free()
