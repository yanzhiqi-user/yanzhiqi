# 技能图标集成 — 完成

## 做了什么

将12张技能图标导入游戏升级/奖励面板，现在选择技能时会显示对应的图标。

## 关键改动

### 1. 图片导入 (`assets/textures/`)
将12张微信图片复制到项目并按技能类型命名：
- `skill_damage.jpg` — 攻击力+
- `skill_fire_rate.jpg` — 攻速+
- `skill_speed.jpg` — 移动速度+
- `skill_max_hp.jpg` — 生命上限+
- `skill_projectile_count.jpg` — 子弹数量+
- `skill_pierce.jpg` — 穿透+
- `skill_crit_rate.jpg` — 暴击率+
- `skill_crit_dmg.jpg` — 暴击伤害+
- `skill_life_steal.jpg` — 吸血+
- `skill_speed_bullet.jpg` — 子弹速度+
- `skill_magnet.jpg` — 吸附范围+
- `skill_range.jpg` — 攻击范围+

### 2. `scripts/hud.gd`
- 添加 `SKILL_ICONS` 常量字典，用 `preload()` 预加载所有技能图标
- 添加 `_setup_skill_button()` 辅助方法，统一设置按钮的文本、图标 (`button.icon`) 和元数据
- `show_upgrade_ui()` 和 `show_level_reward_ui()` 都改用此方法

### 3. `scenes/hud.tscn`
- UpgradePanel 和 RewardPanel 高度增加 (offset_top: -180 → 220)
- 每个按钮高度从60px增加到70px，给图标留出空间

## 重要提示

**重启 Godot 编辑器**后，编辑器会自动为新图片生成 `.import` 文件，`preload()` 才能正常工作。如果不重启就运行，会报资源找不到的错误。
