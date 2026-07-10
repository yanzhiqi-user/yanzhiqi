class_name EnemyData
extends Resource

## 敌人行为类型枚举
enum BehaviorType {
	CHASER,    # 标准追踪，接触伤害
	TANK,      # 高血量，慢速，大体积，高经验
	RUSHER,    # 快速，低血量，小体积
	EXPLODER,  # 快速，低血量，死亡时爆炸
}

## 显示名称
@export var display_name: String = ""
## 行为类型
@export var behavior: BehaviorType = BehaviorType.CHASER
## 基础生命
@export var base_health: float = 20.0
## 基础速度
@export var base_speed: float = 80.0
## 接触伤害
@export var damage: float = 10.0
## 经验掉落
@export var xp_drop: float = 5.0
## 接触伤害冷却（秒）
@export var contact_cooldown: float = 1.0
## 碰撞半径
@export var collision_radius: float = 14.0
## 绘制颜色（外圈）
@export var draw_color: Color = Color(0.9, 0.2, 0.2)
## 绘制颜色（内圈）
@export var draw_color_inner: Color = Color(0.7, 0.1, 0.1)
## 爆炸范围（仅 EXPLODER）
@export var explosion_radius: float = 80.0
## 爆炸伤害（仅 EXPLODER）
@export var explosion_damage: float = 30.0
