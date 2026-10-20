shader_type spatial;
render_mode depth_draw_never, cull_back, diffuse_lambert;

// One depth read, no screen-color copy, SSR, refraction or extra viewport.
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap;
group_uniforms Water;
uniform vec4 shallow_color : source_color = vec4(0.18, 0.40, 0.36, 1.0);
uniform vec4 deep_color : source_color = vec4(0.035, 0.15, 0.23, 1.0);
uniform float absorption : hint_range(0.1, 3.0) = 0.65;
uniform float color_depth : hint_range(0.5, 12.0) = 4.0;
uniform float surface_opacity : hint_range(0.0, 0.3) = 0.025;
group_uniforms Ripples;
uniform float ripple_strength : hint_range(0.0, 0.3) = 0.12;
uniform float ripple_scale : hint_range(0.1, 3.0) = 0.8;
uniform float wind_speed : hint_range(0.0, 2.0) = 0.45;
uniform float surface_roughness : hint_range(0.1, 0.8) = 0.27;
varying vec3 world_position;

void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
 float raw_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
 #else
 vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
 #endif
 vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
 vec3 behind_view = behind.xyz / behind.w;
 // Measures to the visible fish itself, not just the bed beneath it.
 float water_path = max(0.0, length(behind_view) - length(VERTEX));
 float vertical_depth = max(0.0, world_position.y - (INV_VIEW_MATRIX * vec4(behind_view, 1.0)).y);
 vec2 p = world_position.xz * ripple_scale * 0.12;
 float t = TIME * wind_speed;
 vec2 broad = texture(ripple_normal, p + vec2(t * 0.025, t * 0.013)).rg * 2.0 - 1.0;
 vec2 fine = texture(ripple_normal, p * 2.37 + vec2(-t * 0.018, t * 0.02)).rg * 2.0 - 1.0;
 // Fade fine detail with distance to reduce horizon shimmer on small screens.
 float detail = 1.0 - smoothstep(20.0, 100.0, length(VERTEX));
 vec2 slope = (broad + fine * 0.45 * detail) * ripple_strength;
 vec3 n = normalize(vec3(slope.x, 1.0, slope.y));
 NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
 float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 5.0);
 ALBEDO = mix(shallow_color.rgb, deep_color.rgb, 1.0 - exp(-vertical_depth / color_depth));
 ALPHA = clamp(1.0 - (1.0 - surface_opacity) * exp(-water_path * absorption)
               * (1.0 - fresnel * 0.75), 0.0, 1.0);
 ROUGHNESS = surface_roughness;
 METALLIC = 0.0;
 SPECULAR = 0.25;
}
