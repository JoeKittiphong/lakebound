shader_type spatial;
render_mode depth_draw_never, cull_back, diffuse_lambert;

// One depth read, no screen-color copy, SSR, refraction or extra viewport.
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D ripple_normal : hint_normal, repeat_enable, filter_linear_mipmap;
group_uniforms Interaction;
uniform sampler2D interaction_field : repeat_disable, filter_linear;
uniform bool interaction_enabled = false;
uniform bool interaction_field_active = false;
uniform float interaction_neutral = 0.5019607843137255;
uniform vec4 interaction_uv_bounds = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 interaction_rect = vec4(-24.0, -24.0, 48.0, 48.0);
uniform float interaction_strength : hint_range(0.0, 2.0) = 1.0;
uniform bool detail_patch_enabled = false;
uniform bool is_detail_patch = false;
uniform vec2 detail_patch_center = vec2(0.0);
uniform float detail_patch_half_size = 8.0;
group_uniforms Water;
uniform vec4 shallow_color : source_color = vec4(0.18, 0.40, 0.36, 1.0);
uniform vec4 deep_color : source_color = vec4(0.035, 0.15, 0.23, 1.0);
uniform float absorption : hint_range(0.1, 3.0) = 0.65;
uniform float color_depth : hint_range(0.5, 12.0) = 4.0;
uniform float surface_opacity : hint_range(0.0, 0.3) = 0.025;
uniform vec4 reflection_horizon : source_color = vec4(0.72, 0.88, 0.86, 1.0);
uniform vec4 reflection_zenith : source_color = vec4(0.27, 0.61, 0.77, 1.0);
group_uniforms Ripples;
uniform float ripple_strength : hint_range(0.0, 0.3) = 0.23;
uniform float ripple_scale : hint_range(0.1, 3.0) = 0.8;
uniform float wind_speed : hint_range(0.0, 2.0) = 0.45;
uniform float surface_roughness : hint_range(0.1, 0.8) = 0.23;
group_uniforms Shore;
uniform float shore_wave_strength : hint_range(0.0, 0.5) = 0.18;
uniform float shore_wave_depth : hint_range(0.1, 1.5) = 0.65;
uniform float shore_wave_speed : hint_range(0.0, 2.0) = 0.7;
uniform vec4 shore_color : source_color = vec4(0.66, 0.79, 0.72, 1.0);
varying vec3 world_position;

void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 if (is_detail_patch && interaction_enabled) {
  vec2 field_uv = (world_position.xz - interaction_rect.xy) / interaction_rect.zw;
  float height = 0.0;
  if (interaction_field_active && all(greaterThanEqual(field_uv, interaction_uv_bounds.xy)) && all(lessThanEqual(field_uv, interaction_uv_bounds.zw))) {
   height = (clamp(textureLod(interaction_field, field_uv, 0.0).b, 0.0, 1.0) - interaction_neutral) * 0.4;
  }
  height += sin(dot(world_position.xz, vec2(0.72, 0.31)) - TIME * wind_speed * 1.3) * 0.018;
  float edge = max(abs(world_position.x - detail_patch_center.x), abs(world_position.z - detail_patch_center.y));
  float blend = 1.0 - smoothstep(detail_patch_half_size - 1.5, detail_patch_half_size, edge);
  VERTEX.y += height * blend * interaction_strength;
  world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 }
}

void fragment() {
 // Near mesh replaces this square of the large plane; there are no overlays.
 vec2 patch_offset = abs(world_position.xz - detail_patch_center);
 if (detail_patch_enabled && !is_detail_patch && max(patch_offset.x, patch_offset.y) < detail_patch_half_size) {
  discard;
 }
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
 // Fade fine detail with distance to reduce horizon shimmer on small screens.
 float detail = 1.0 - smoothstep(20.0, 100.0, length(VERTEX));
 vec2 fine = vec2(0.0);
 if (detail > 0.0 || vertical_depth < shore_wave_depth) {
  fine = texture(ripple_normal, p * 2.37 + vec2(-t * 0.018, t * 0.02)).rg * 2.0 - 1.0;
 }
 vec2 slope = (broad + fine * 0.45 * detail) * ripple_strength;
 // Long, quiet swells give the small normal-map ripples a readable direction.
 float swell_slope = cos(dot(world_position.xz, vec2(0.72, 0.31)) - t * 1.3);
 slope -= vec2(0.72, 0.31) * swell_slope * 0.018 * detail;
 if (interaction_enabled && interaction_field_active) {
  vec2 field_uv = (world_position.xz - interaction_rect.xy) / interaction_rect.zw;
  if (all(greaterThanEqual(field_uv, interaction_uv_bounds.xy)) && all(lessThanEqual(field_uv, interaction_uv_bounds.zw))) {
   vec2 response = (clamp(texture(interaction_field, field_uv).rg, vec2(0.0), vec2(1.0)) - vec2(interaction_neutral)) * 2.0;
   slope += response * interaction_strength;
  }
 }
 vec3 n = normalize(vec3(slope.x, 1.0, slope.y));
 NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
 float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 5.0);
 ALBEDO = mix(shallow_color.rgb, deep_color.rgb, 1.0 - exp(-vertical_depth / color_depth));
 ALPHA = clamp(1.0 - (1.0 - surface_opacity) * exp(-water_path * absorption)
               * (1.0 - fresnel * 0.75), 0.0, 1.0);
 // Positive time moves the wash toward decreasing depth (toward the bank).
 // Reuses the existing depth sample; also provides soft contact wash at rocks.
 float foam = 0.0;
 if (vertical_depth < shore_wave_depth && shore_wave_strength > 0.0) {
  float shallow = (1.0 - smoothstep(0.04, shore_wave_depth, vertical_depth))
                  * smoothstep(0.0, 0.035, vertical_depth);
  float wash = smoothstep(0.55, 0.95, sin(vertical_depth * 15.0
                + TIME * shore_wave_speed * 2.0 + broad.x * 1.3));
  foam = shallow * wash * shore_wave_strength * (0.65 + 0.35 * fine.x);
 }
 ALBEDO = mix(ALBEDO, shore_color.rgb, foam);
 ALPHA = max(ALPHA, foam * 0.65);
 // Preserve a little reflected sky when shallow-water alpha is low. Normal
 // changes bend this reflection instead of drawing colored circles on top.
 vec3 reflected = reflect(-VIEW, NORMAL);
 vec3 reflected_world = (INV_VIEW_MATRIX * vec4(reflected, 0.0)).xyz;
 vec3 sky_reflection = mix(reflection_horizon.rgb, reflection_zenith.rgb,
                            smoothstep(0.0, 0.85, reflected_world.y));
 EMISSION = sky_reflection * fresnel * 0.45 / max(ALPHA, 0.05);
 ROUGHNESS = surface_roughness;
 METALLIC = 0.0;
 SPECULAR = 0.25;
}
