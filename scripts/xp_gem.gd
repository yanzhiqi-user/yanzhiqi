extends Area2D
## 经验宝石 - 击杀敌人后掉落，玩家拾取获得经验值

# 参数
@export var xp_amount: float = 5.0
@export var magnet_range: float = 120.0   # 自动吸附范围
@export var pickup_range: float = 20.0    # 拾取范围
@export var lifetime: float = 15.0        # 存在时间（秒）

var player: Node2D = null
var is_magnetized: bool = false
var magnet_speed: float = 400.0


func _ready() -> void:
	add_to_group("xp_gems")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# 逐渐消失动画
	var tween = create_tween()
	tween.tween_interval(lifetime)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 1.0)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = find_player()
		return

	var dist = global_position.distance_to(player.global_position)

	# 进入吸附范围
	if not is_magnetized and dist < magnet_range:
		is_magnetized = true

	# 吸附移动
	if is_magnetized:
		var dir = global_position.direction_to(player.global_position)
		global_position += dir * magnet_speed * delta

		# 如果已在拾取范围内，直接由 _on_body_entered 处理
		# 但这里作为备用
		if dist < pickup_range:
			collect()


## 寻找玩家
func find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("players")
	if not players.is_empty():
		return players[0] as Node2D
	return null


## 玩家接触拾取
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		collect()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("players"):
		collect()


## 被拾取
func collect() -> void:
	if not is_instance_valid(player):
		player = find_player()

	if player and player.has_method("gain_experience"):
		player.gain_experience(xp_amount)

	queue_free()
