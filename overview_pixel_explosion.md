# 僵尸像素爆炸着色器效果 — 完成

## 做了什么

为 Godot 4 末日生存项目实现了基于 GPU Particles 的僵尸死亡像素粉碎爆炸特效。
该效果改编自 [PlayWithFurcifer 的 Sprite Pixel Explosion Shader](https://godotshaders.com/shader/playwithfurcifers-sprite-pixel-explosion-shader/)，
并针对僵尸爆破场景做了颜色和参数优化。

## 关键改动

### 1. 新增着色器 `assets/shaders/pixel_explosion.gdshader`

- `shader_type particles; render_mode disable_velocity;`
- 将精灵图拆分为像素粒子，每个粒子携带对应位置的颜色向外爆开
- 新增 `tint_color` / `use_tint` 参数：默认火红/橙色着色，让僵尸死亡更像血/火爆炸
- 修复原 shader 的世界坐标采样问题：在应用 `EMISSION_TRANSFORM` **之前**采样精灵图颜色，
  使爆炸效果能正确跟随僵尸的实际世界位置
- 透明像素粒子自动 `ACTIVE = false`，只让僵尸实体部分参与爆炸
- 所有 uniform 都加了 `hint_range` / `source_color` 等 Inspector 提示

### 2. 新增控制器 `scripts/pixel_explosion.gd`

- `class_name PixelExplosion`
- 运行时动态创建 `GPUParticles2D`，生成 1×1 白色像素作为粒子形状
- 根据精灵图尺寸自动设置 `emission_box_extents`
- 根据纹理分辨率自动计算粒子数量（带上下限 clamp）
- `explode(texture)` 触发单次爆发，`finished` 信号后自动 `queue_free()`

### 3. 修改 `scripts/enemy.gd`

- 普通僵尸死亡时调用 `_spawn_pixel_explosion()`
- 爆裂者 (`EXPLODER`) 在 `_explode()` 中调用 `_spawn_pixel_explosion()`，保留原有范围伤害逻辑
- 移除了原来用 `ColorRect` + Tween 的简单爆炸动画

## 使用方式

僵尸死亡时会自动触发，无需手动调用。如需在其他地方使用：

```gdscript
var fx := PixelExplosion.new()
get_parent().add_child(fx)
fx.global_position = enemy.global_position
fx.explode(enemy.get_node("Sprite2D").texture)
```

## 可调参数（在 PixelExplosion 脚本中）

- `particle_amount` — 粒子数上限（默认 2048，爆裂者自动用 4096）
- `explosion_lifetime` — 爆炸持续时间（默认 1.0 秒）
- `tint` — 爆炸主色调
- `use_tint` — 是否启用着色

## 渲染器兼容性

- Forward+ / Mobile / Compatibility 均可用
- 不使用 `SCREEN_TEXTURE` / `DEPTH_TEXTURE`，无 framebuffer 拷贝开销
- 主要成本为 fragment 中的纹理采样，建议移动设备上保持 `particle_amount` ≤ 2048

## 注意事项

- 需要先在 Godot 编辑器中打开一次项目，让新 `.gdshader` 和 `.gd` 文件生成 `.uid`/`.import` 文件
- 僵尸精灵图是整个 spritesheet，爆炸会同时包含所有帧的颜色；如想要只炸当前帧，
  可将 `sprite` 参数改为单帧子纹理
