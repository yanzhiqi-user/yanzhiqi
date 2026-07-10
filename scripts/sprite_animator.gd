class_name SpriteAnimator
extends Sprite2D

## 序列图动画播放器。
## 支持两种模式：
## 1. 按行播放（use_full_sheet = false）：静止时播放 [member idle_row]，移动时播放 [member walk_row]。
## 2. 连续播放（use_full_sheet = true）：移动时顺序播放 [member full_sheet_start] 到 [member full_sheet_end] 的所有帧；
##    静止时回退到 [member idle_row]。

## 是否把整张序列图当作一段连续动画播放。
@export var use_full_sheet: bool = false
## 静止动画所在行（从 0 开始）。
@export var idle_row: int = 0
## 移动动画所在行（从 0 开始，仅在 use_full_sheet=false 时生效）。
@export var walk_row: int = 1
## 连续动画的起始帧（仅在 use_full_sheet=true 时生效）。
@export var full_sheet_start: int = 0
## 连续动画的结束帧（仅在 use_full_sheet=true 时生效，-1 表示最后一帧）。
@export var full_sheet_end: int = -1
## 动画播放速度（帧/秒）。
@export var animation_speed: float = 12.0
## 判定为"静止"的速度阈值。
@export var idle_threshold: float = 10.0
## 是否反转朝向逻辑。当素材默认朝向与代码假设相反时，启用此选项。
@export var invert_direction: bool = false

var _time: float = 0.0

@onready var _body: CharacterBody2D = owner as CharacterBody2D


func _ready() -> void:
	if _body == null:
		push_error("SpriteAnimator: owner must be a CharacterBody2D.")
		set_process(false)
		return

	if hframes <= 0 or vframes <= 0:
		push_error("SpriteAnimator: hframes and vframes must be > 0.")
		set_process(false)


func _process(delta: float) -> void:
	_time += delta * animation_speed

	var total_frames: int = hframes * vframes
	var is_moving: bool = _body.velocity.length() > idle_threshold

	# 根据水平速度翻转朝向
	if _body.velocity.x > idle_threshold:
		flip_h = invert_direction
	elif _body.velocity.x < -idle_threshold:
		flip_h = not invert_direction

	if use_full_sheet and is_moving:
		var start_frame: int = clampi(full_sheet_start, 0, total_frames - 1)
		var end_frame: int = full_sheet_end if full_sheet_end >= 0 else total_frames - 1
		end_frame = clampi(end_frame, start_frame, total_frames - 1)
		var frame_count: int = end_frame - start_frame + 1
		frame = start_frame + (int(_time) % frame_count)
	elif is_moving:
		# 按行播放：移动时播放 walk_row
		var column: int = int(_time) % hframes
		frame = clampi(walk_row * hframes + column, 0, total_frames - 1)
	else:
		# 静止：停在 idle_row 的第一帧，不播放动画
		frame = clampi(idle_row * hframes, 0, total_frames - 1)
