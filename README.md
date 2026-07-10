# 末日生存 (Apocalypse Survival)

Godot 4 开发的吸血鬼幸存者风格 Roguelike 动作游戏。

## 玩法
- **WASD / 方向键** 移动角色
- **自动攻击** 消灭成群僵尸
- **拾取经验宝石** 升级，选择强化技能
- **8个关卡**，层层递进，敌人越来越强

## 技术栈
- **引擎**: Godot 4.7
- **语言**: GDScript 2.0
- **渲染**: DirectX 12 (d3d12)

## 项目结构
```
├── assets/          # 纹理、着色器
├── scenes/          # 场景文件 (.tscn)
├── scripts/         # GDScript 脚本
├── resources/       # 敌人数据预设 (.tres)
├── project.godot    # 项目配置
└── main.tscn        # 游戏主场景
```

## 运行
1. 用 Godot 4.7 打开项目
2. 点击运行 (F5)
