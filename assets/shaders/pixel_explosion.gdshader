// ============================================================
// Pixel Explosion Shader — 僵尸爆炸像素粒子效果
// ============================================================
// Renderer Target: Forward+ / Mobile / Compatibility (all OK)
// Based on: PlayWithFurcifer's Sprite Explosion (ported by Mopifish)
// Adapted for zombie death VFX
//
// 用法:
//   1. 将 GPUParticles2D 的 texture 设为 1×1 白色像素
//   2. 将本 shader 设为 ProcessMaterial 的自定义着色器
//   3. 设置 Sprite 参数为僵尸精灵图
//   4. 调整 Box Extents 匹配精灵图尺寸
// ============================================================

shader_type particles;
render_mode disable_velocity;

// ---- 爆炸色彩着色 ----
uniform bool use_tint = true;
uniform vec4 tint_color : source_color = vec4(1.0, 0.35, 0.08, 1.0);

// ---- 发射/扩散 ----
uniform float spread = 180.0;
uniform float inherit_emitter_velocity_ratio = 0.0;
uniform float initial_linear_velocity_min : hint_range(0.0, 500.0) = 80.0;
uniform float initial_linear_velocity_max : hint_range(0.0, 500.0) = 200.0;
uniform float orbit_velocity_min : hint_range(-200.0, 200.0) = 0.0;
uniform float orbit_velocity_max : hint_range(-200.0, 200.0) = 0.0;

// ---- 径向速度 ----
uniform float radial_velocity_min : hint_range(-500.0, 500.0) = 50.0;
uniform float radial_velocity_max : hint_range(-500.0, 500.0) = 150.0;

// ---- 加速度 ----
uniform float linear_accel_min : hint_range(-200.0, 200.0) = -30.0;
uniform float linear_accel_max : hint_range(-200.0, 200.0) = 0.0;
uniform float radial_accel_min : hint_range(-200.0, 200.0) = -10.0;
uniform float radial_accel_max : hint_range(-200.0, 200.0) = 10.0;
uniform float tangent_accel_min : hint_range(-200.0, 200.0) = -20.0;
uniform float tangent_accel_max : hint_range(-200.0, 200.0) = 20.0;
uniform float damping_min : hint_range(0.0, 100.0) = 5.0;
uniform float damping_max : hint_range(0.0, 100.0) = 15.0;

// ---- 缩放 ----
uniform float scale_min : hint_range(0.1, 10.0) = 1.5;
uniform float scale_max : hint_range(0.1, 10.0) = 2.5;

// ---- 生命周期 ----
uniform float lifetime_randomness : hint_range(0.0, 1.0) = 0.3;

// ---- 发射形状 ----
uniform vec3 emission_shape_offset = vec3(0.0);
uniform vec3 emission_shape_scale = vec3(1.0);
uniform vec3 emission_box_extents = vec3(100.0, 100.0, 0.0);

// ---- 精灵图 ----
uniform sampler2D sprite : repeat_disable;


// ============================================================
// 随机数生成器
// ============================================================
float rand_from_seed(inout uint seed) {
    int k;
    int s = int(seed);
    if (s == 0)
        s = 305420679;
    k = s / 127773;
    s = 16807 * (s - k * 127773) - 2836 * k;
    if (s < 0)
        s += 2147483647;
    seed = uint(s);
    return float(seed % uint(65536)) / 65535.0;
}

float rand_from_seed_m1_p1(inout uint seed) {
    return rand_from_seed(seed) * 2.0 - 1.0;
}

uint hash(uint x) {
    x = ((x >> uint(16)) ^ x) * uint(73244475);
    x = ((x >> uint(16)) ^ x) * uint(73244475);
    x = (x >> uint(16)) ^ x;
    return x;
}

// ============================================================
// 参数结构体
// ============================================================
struct DisplayParameters {
    vec3 scale;
    float lifetime;
};

struct DynamicsParameters {
    float initial_velocity_multiplier;
    float radial_velocity;
    float orbit_velocity;
};

struct PhysicalParameters {
    float linear_accel;
    float radial_accel;
    float tangent_accel;
    float damping;
};

// ============================================================
// 初始化函数
// ============================================================
void calculate_initial_physical_params(inout PhysicalParameters params, inout uint alt_seed) {
    params.linear_accel = mix(linear_accel_min, linear_accel_max, rand_from_seed(alt_seed));
    params.radial_accel = mix(radial_accel_min, radial_accel_max, rand_from_seed(alt_seed));
    params.tangent_accel = mix(tangent_accel_min, tangent_accel_max, rand_from_seed(alt_seed));
    params.damping = mix(damping_min, damping_max, rand_from_seed(alt_seed));
}

void calculate_initial_dynamics_params(inout DynamicsParameters params, inout uint alt_seed) {
    params.initial_velocity_multiplier = mix(initial_linear_velocity_min, initial_linear_velocity_max, rand_from_seed(alt_seed));
    params.radial_velocity = mix(radial_velocity_min, radial_velocity_max, rand_from_seed(alt_seed));
    params.orbit_velocity = mix(orbit_velocity_min, orbit_velocity_max, rand_from_seed(alt_seed));
}

void calculate_initial_display_params(inout DisplayParameters params, inout uint alt_seed) {
    params.scale = vec3(mix(scale_min, scale_max, rand_from_seed(alt_seed)));
    params.scale = sign(params.scale) * max(abs(params.scale), 0.001);
    params.lifetime = (1.0 - lifetime_randomness * rand_from_seed(alt_seed));
}

vec3 calculate_initial_position(inout uint alt_seed) {
    vec3 pos = vec3(rand_from_seed(alt_seed) * 2.0 - 1.0,
                     rand_from_seed(alt_seed) * 2.0 - 1.0,
                     rand_from_seed(alt_seed) * 2.0 - 1.0) * emission_box_extents;
    return pos * emission_shape_scale + emission_shape_offset;
}

vec3 get_random_direction_from_spread(inout uint alt_seed, float spread_angle) {
    float pi = 3.14159;
    float degree_to_rad = pi / 180.0;
    float spread_rad = spread_angle * degree_to_rad;
    float angle1_rad = rand_from_seed_m1_p1(alt_seed) * spread_rad;
    float angle2_rad = rand_from_seed_m1_p1(alt_seed) * spread_rad;

    vec3 direction_xz = vec3(sin(angle1_rad), 0.0, cos(angle1_rad));
    vec3 direction_yz = vec3(0.0, sin(angle2_rad), cos(angle2_rad));
    direction_yz.z = direction_yz.z / max(0.0001, sqrt(abs(direction_yz.z)));

    vec3 spread_direction = vec3(direction_xz.x * direction_yz.z,
                                  direction_yz.y,
                                  direction_xz.z * direction_yz.z);
    vec3 direction_nrm = vec3(0.0, 0.0, 1.0);

    vec3 binormal = cross(vec3(0.0, 1.0, 0.0), direction_nrm);
    if (length(binormal) < 0.0001) {
        binormal = vec3(0.0, 0.0, 1.0);
    }
    binormal = normalize(binormal);
    vec3 normal = cross(binormal, direction_nrm);
    spread_direction = binormal * spread_direction.x + normal * spread_direction.y + direction_nrm * spread_direction.z;
    return spread_direction;
}

vec3 process_orbit_displacement(DynamicsParameters param, float lifetime, inout uint alt_seed,
                                 mat4 transform, mat4 emission_transform, float delta, float total_lifetime) {
    if (abs(param.orbit_velocity) < 0.01 || delta < 0.001) {
        return vec3(0.0);
    }
    float pi = 3.14159;
    float orbit_amount = param.orbit_velocity;
    if (orbit_amount != 0.0) {
        vec3 pos = transform[3].xyz;
        vec3 org = emission_transform[3].xyz;
        vec3 diff = pos - org;
        float ang = orbit_amount * pi * 2.0 * delta;
        mat2 rot = mat2(vec2(cos(ang), -sin(ang)), vec2(sin(ang), cos(ang)));
        vec3 displacement = vec3(0.0);
        displacement.xy -= diff.xy;
        displacement.xy += rot * diff.xy;
        return (emission_transform * vec4(displacement / delta, 0.0)).xyz;
    }
    return vec3(0.0);
}

vec3 process_radial_displacement(DynamicsParameters param, float lifetime, inout uint alt_seed,
                                  mat4 transform, mat4 emission_transform, float delta) {
    vec3 radial_displacement = vec3(0.0);
    if (delta < 0.001) {
        return radial_displacement;
    }
    if (length(transform[3].xyz) > 0.01) {
        radial_displacement = normalize(transform[3].xyz) * param.radial_velocity;
    } else {
        radial_displacement = get_random_direction_from_spread(alt_seed, 360.0) * param.radial_velocity;
    }
    if (param.radial_velocity < 0.0) {
        if (length(radial_displacement) > 0.01) {
            radial_displacement = normalize(radial_displacement)
                * min(abs(param.radial_velocity), length(transform[3].xyz) / delta);
        }
    }
    return radial_displacement;
}


// ============================================================
// start() — 粒子生成时调用
// ============================================================
void start() {
    uint base_number = NUMBER;
    uint alt_seed = hash(base_number + uint(1) + RANDOM_SEED);

    DisplayParameters params;
    calculate_initial_display_params(params, alt_seed);
    DynamicsParameters dynamic_params;
    calculate_initial_dynamics_params(dynamic_params, alt_seed);
    PhysicalParameters physics_params;
    calculate_initial_physical_params(physics_params, alt_seed);

    if (rand_from_seed(alt_seed) > AMOUNT_RATIO) {
        ACTIVE = false;
    }

    if (RESTART_CUSTOM) {
        CUSTOM = vec4(0.0);
        CUSTOM.w = params.lifetime;
    }

    if (RESTART_ROT_SCALE) {
        TRANSFORM[0].xyz = vec3(1.0, 0.0, 0.0);
        TRANSFORM[1].xyz = vec3(0.0, 1.0, 0.0);
        TRANSFORM[2].xyz = vec3(0.0, 0.0, 1.0);
    }

    if (RESTART_POSITION) {
        TRANSFORM[3].xyz = calculate_initial_position(alt_seed);

        // ---- 在应用 EMISSION_TRANSFORM 之前采样颜色 ----
        // 这样 UV 计算基于局部坐标，不受粒子节点世界位置影响
        vec2 particle_position = TRANSFORM[3].xy;
        vec2 tex_size = vec2(textureSize(sprite, 0));
        vec4 sprite_color = texture(sprite, particle_position / tex_size + vec2(0.5, 0.5));

        // ---- 应用爆炸色彩（火红/橙色） ----
        if (use_tint && sprite_color.a > 0.01) {
            // 使用亮度混合: 精灵暗色部分变为深红，亮色部分变为橙黄
            float luminance = dot(sprite_color.rgb, vec3(0.299, 0.587, 0.114));
            vec3 tinted = mix(tint_color.rgb * 0.4, tint_color.rgb, luminance);
            // 保留原始颜色的一部分，使效果更自然
            COLOR = vec4(mix(sprite_color.rgb, tinted, 0.7), sprite_color.a);
        } else {
            COLOR = sprite_color;
        }

        // 禁用透明像素
        if (sprite_color.a == 0.0) {
            ACTIVE = false;
        }

        // 现在将局部坐标转换为世界坐标
        TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
    }

    if (RESTART_VELOCITY) {
        VELOCITY = get_random_direction_from_spread(alt_seed, spread) * dynamic_params.initial_velocity_multiplier;
    }

    VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
    VELOCITY += EMITTER_VELOCITY * inherit_emitter_velocity_ratio;
    VELOCITY.z = 0.0;
    TRANSFORM[3].z = 0.0;
}


// ============================================================
// process() — 粒子每帧更新
// ============================================================
void process() {
    uint base_number = NUMBER;
    uint alt_seed = hash(base_number + uint(1) + RANDOM_SEED);

    DisplayParameters params;
    calculate_initial_display_params(params, alt_seed);
    DynamicsParameters dynamic_params;
    calculate_initial_dynamics_params(dynamic_params, alt_seed);
    PhysicalParameters physics_params;
    calculate_initial_physical_params(physics_params, alt_seed);

    CUSTOM.y += DELTA / LIFETIME;
    CUSTOM.y = mix(CUSTOM.y, 1.0, INTERPOLATE_TO_END);
    float lifetime_percent = CUSTOM.y / params.lifetime;

    if (CUSTOM.y > CUSTOM.w) {
        ACTIVE = false;
    }

    vec3 starting_position = TRANSFORM[3].xyz;
    vec3 controlled_displacement = vec3(0.0);

    controlled_displacement += process_orbit_displacement(dynamic_params, lifetime_percent, alt_seed,
                                                           TRANSFORM, EMISSION_TRANSFORM, DELTA,
                                                           params.lifetime * LIFETIME);
    controlled_displacement += process_radial_displacement(dynamic_params, lifetime_percent, alt_seed,
                                                            TRANSFORM, EMISSION_TRANSFORM, DELTA);

    // 计算力
    vec3 force = vec3(0.0);
    {
        vec3 pos = TRANSFORM[3].xyz;
        // 线性加速度
        force += length(VELOCITY) > 0.0 ? normalize(VELOCITY) * physics_params.linear_accel : vec3(0.0);
        // 径向加速度
        vec3 org = EMISSION_TRANSFORM[3].xyz;
        vec3 diff = pos - org;
        force += length(diff) > 0.0 ? normalize(diff) * physics_params.radial_accel : vec3(0.0);
        // 切向加速度
        float tangent_accel_val = physics_params.tangent_accel;
        force += length(diff.yx) > 0.0
            ? vec3(normalize(diff.yx * vec2(-1.0, 1.0)), 0.0) * tangent_accel_val
            : vec3(0.0);
        force += ATTRACTOR_FORCE;
        force.z = 0.0;
        VELOCITY += force * DELTA;
    }

    // 阻尼
    {
        if (physics_params.damping > 0.0) {
            float v = length(VELOCITY);
            v -= physics_params.damping * DELTA;
            if (v < 0.0) {
                VELOCITY = vec3(0.0);
            } else {
                VELOCITY = normalize(VELOCITY) * v;
            }
        }
    }

    vec3 final_velocity = controlled_displacement + VELOCITY;
    final_velocity.z = 0.0;
    TRANSFORM[3].xyz += final_velocity * DELTA;

    // 旋转
    TRANSFORM[0] = vec4(cos(CUSTOM.x), -sin(CUSTOM.x), 0.0, 0.0);
    TRANSFORM[1] = vec4(sin(CUSTOM.x), cos(CUSTOM.x), 0.0, 0.0);
    TRANSFORM[2] = vec4(0.0, 0.0, 1.0, 0.0);
    TRANSFORM[3].z = 0.0;

    // 缩放
    TRANSFORM[0].xyz *= sign(params.scale.x) * max(abs(params.scale.x), 0.001);
    TRANSFORM[1].xyz *= sign(params.scale.y) * max(abs(params.scale.y), 0.001);
    TRANSFORM[2].xyz *= sign(params.scale.z) * max(abs(params.scale.z), 0.001);

    if (CUSTOM.y > CUSTOM.w) {
        ACTIVE = false;
    }

    // 渐变淡出：让粒子随时间消失
    if (COLOR.a > 0.0) {
        COLOR.a -= 1.0 / LIFETIME * DELTA;
    }
}
