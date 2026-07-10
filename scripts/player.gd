extends CharacterBody2D
## 玩家角色 - 支持移动、生命值、经验值升级系统

# 信号
signal died()
signal leveled_up(new_level)
signal experience_changed(current_xp, xp_to_next)

# 移动参数
@export var speed: float = 300.0
@export var acceleration: float = 1200.0
@export var friction: float = 800.0

# 生命参数
@export var max_health: float = 100.0
@export var health: float = 100.0

# 经验参数
@export var level: int = 1
@export var experience: float = 0.0
@export var experience_to_next: float = 20.0

# 无敌帧
var invulnerable: bool = false
var invulnerable_timer: float = 0.0
var invulnerable_duration: float = 0.5

# 移动输入
var input_dir: Vector2 = Vector2.ZERO

# 升级奖励
var bonus_damage: float = 0.0
var bonus_speed: float = 0.0
var bonus_max_hp: float = 0.0

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound
@onready var weapon: Node2D = $Weapon
@onready var sprite: Sprite2D = $Sprite2D

var invulnerable_visual_timer: float = 0.0


func _ready() -> void:
	health = max_health
	update_experience_bar()
	_setup_input_actions()


## 动态注册输入映射（不依赖 project.godot）
func _setup_input_actions() -> void:
	var actions = [
		{"name": "move_left",  "key_a": KEY_A, "key_b": KEY_LEFT},
		{"name": "move_right", "key_a": KEY_D, "key_b": KEY_RIGHT},
		{"name": "move_up",    "key_a": KEY_W, "key_b": KEY_UP},
		{"name": "move_down",  "key_a": KEY_S, "key_b": KEY_DOWN},
	]
	for action in actions:
		if not InputMap.has_action(action.name):
			InputMap.add_action(action.name)
			var event_a = InputEventKey.new()
			event_a.keycode = action.key_a
			InputMap.action_add_event(action.name, event_a)
			var event_b = InputEventKey.new()
			event_b.keycode = action.key_b
			InputMap.action_add_event(action.name, event_b)


func _process(delta: float) -> void:
	# 无敌帧计时
	if invulnerable:
		invulnerable_visual_timer += delta * 20.0
		invulnerable_timer -= delta
		if invulnerable_timer <= 0:
			invulnerable = false
			if sprite:
				sprite.modulate = Color.WHITE
		elif sprite:
			var alpha: float = 0.5 + sin(invulnerable_visual_timer) * 0.3
			sprite.modulate = Color(1.0, 1.0, 1.0, alpha)


func _physics_process(delta: float) -> void:
	# 获取输入
	input_dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()

	# 移动
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * (speed + bonus_speed), acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_collide(velocity * delta)

	# 限制在屏幕内
	var screen_size: Vector2 = get_viewport_rect().size
	global_position = global_position.clamp(Vector2(16, 16), screen_size - Vector2(16, 16))


## 受到伤害
func take_damage(amount: float) -> void:
	if invulnerable:
		return

	health -= amount

	if hurt_sound:
		hurt_sound.play()

	# 进入无敌帧
	invulnerable = true
	invulnerable_timer = invulnerable_duration

	if health <= 0:
		health = 0
		die()


## 角色死亡
func die() -> void:
	emit_signal("died")
	queue_free()


## 恢复生命
func heal(amount: float) -> void:
	health = min(health + amount, max_health + bonus_max_hp)


## 增加经验
func gain_experience(amount: float) -> void:
	experience += amount
	while experience >= experience_to_next:
		experience -= experience_to_next
		level_up()
	experience_changed.emit(experience, experience_to_next)


## 升级
func level_up() -> void:
	level += 1
	experience_to_next = 30.0 * pow(1.25, level - 1)
	emit_signal("leveled_up", level)


## 更新经验UI
func update_experience_bar() -> void:
	experience_changed.emit(experience, experience_to_next)


## 获取总伤害加成
func get_damage_bonus() -> float:
	return bonus_damage


## 获取最大生命值
func get_max_health() -> float:
	return max_health + bonus_max_hp
