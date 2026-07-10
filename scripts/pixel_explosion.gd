extends Node2D
class_name PixelExplosion

## 僵尸像素爆炸效果控制器
## 使用 GPU 粒子着色器将精灵图当前帧粉碎为彩色像素碎片
##
## 用法:
##   var fx := PixelExplosion.new()
##   get_parent().add_child(fx)
##   fx.global_position = enemy.global_position
##   fx.explode_from_sprite($Sprite2D)    # 自动提取当前帧

## 粒子数量上限 (越大越精细，但也更消耗性能)
@export var particle_amount: int = 2048

## 爆炸粒子总生命周期 (秒)
@export var explosion_lifetime: float = 1.0

## 爆炸色调 (默认火红/橙色，适合僵尸爆破)
@export var tint: Color = Color(1.0, 0.35, 0.08, 1.0)

## 是否启用爆炸着色 (关闭则保留原精灵颜色)
@export var use_tint: bool = true

## 粒子缩放倍率 (覆盖着色器默认的 1.5~2.5)
@export var particle_scale_min: float = 3.0
@export var particle_scale_max: float = 6.0


## 从 Sprite2D 节点提取当前动画帧并触发爆炸。
## 确保爆炸粒子只使用当前显示的帧，而不是整个 spritesheet。
func explode_from_sprite(sprite: Sprite2D, extra_amount: float = 1.0) -> void:
	if sprite == null or sprite.texture == null:
		push_warning("PixelExplosion: sprite 或 sprite.texture 为 null")
		queue_free()
		return

	var frame_tex := _extract_frame_texture(sprite)
	if frame_tex == null:
		push_warning("PixelExplosion: 无法提取当前帧纹理")
		queue_free()
		return

	# 用提取的单帧纹理触发爆炸
	_explode_internal(frame_tex, extra_amount)


## 直接传入纹理触发爆炸（如果你已经有单帧纹理）
func _explode_internal(texture: Texture2D, extra_amount: float = 1.0) -> void:
	if texture == null:
		queue_free()
		return

	# -- 生成 1x1 白色像素纹理作为粒子形状 --
	var white_img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white_img.fill(Color.WHITE)
	var particle_tex := ImageTexture.create_from_image(white_img)

	# -- 加载像素爆炸着色器 --
	var shader := load("res://assets/shaders/pixel_explosion.gdshader") as Shader
	if shader == null:
		push_error("PixelExplosion: 着色器 pixel_explosion.gdshader 未找到或未编译")
		queue_free()
		return

	# === 关键 ===
	# Godot 4：自定义粒子着色器必须挂到 ShaderMaterial 上，
	# 然后赋值给 GPUParticles2D.process_material。
	# ParticleProcessMaterial 没有 .shader 属性，不能替换内置着色器。
	var proc_mat := ShaderMaterial.new()
	proc_mat.shader = shader

	var tex_size := texture.get_size()

	# -- 传入自定义 uniform --
	proc_mat.set_shader_parameter("sprite", texture)
	proc_mat.set_shader_parameter("emission_box_extents",
		Vector3(tex_size.x / 2.0, tex_size.y / 2.0, 0.0))
	proc_mat.set_shader_parameter("tint_color", tint)
	proc_mat.set_shader_parameter("use_tint", use_tint)
	proc_mat.set_shader_parameter("scale_min", particle_scale_min)
	proc_mat.set_shader_parameter("scale_max", particle_scale_max)

	# 根据纹理分辨率动态计算粒子数
	var raw_amount := int(tex_size.x * tex_size.y * 0.3 * extra_amount)
	var amount := clampi(raw_amount, 64, particle_amount)

	# -- 创建 GPUParticles2D --
	var particles := GPUParticles2D.new()
	particles.texture = particle_tex
	particles.process_material = proc_mat
	particles.amount = amount
	particles.lifetime = explosion_lifetime
	particles.explosiveness = 1.0          # 一次性爆发
	particles.one_shot = true               # 不循环
	particles.emitting = true               # 立即发射
	particles.z_index = 100                 # 渲染在最上层
	particles.finished.connect(_on_particles_finished, CONNECT_ONE_SHOT)

	add_child(particles)


## 从 spritesheet 中裁剪出当前帧
func _extract_frame_texture(sprite: Sprite2D) -> Texture2D:
	var tex := sprite.texture
	if tex == null:
		return null

	# hframes/vframes == 0 意味着没有 spritesheet 分割
	if sprite.hframes <= 1 and sprite.vframes <= 1:
		return tex

	var image := tex.get_image()
	if image.is_empty():
		return null

	var hframes := sprite.hframes
	var vframes := sprite.vframes
	var frame := sprite.frame

	var frame_w := image.get_width() / hframes
	var frame_h := image.get_height() / vframes
	var col := frame % hframes
	var row := frame / hframes

	var rect := Rect2i(col * frame_w, row * frame_h, frame_w, frame_h)
	var frame_img := image.get_region(rect)

	return ImageTexture.create_from_image(frame_img)


func _on_particles_finished() -> void:
	queue_free()
