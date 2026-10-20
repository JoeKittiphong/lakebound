shader_type spatial;
render_mode diffuse_lambert;

uniform vec4 sand_color : source_color = vec4(0.34, 0.31, 0.22, 1.0);
uniform vec4 silt_color : source_color = vec4(0.16, 0.20, 0.15, 1.0);
uniform vec4 grass_color : source_color = vec4(0.24, 0.32, 0.18, 1.0);
uniform float water_height = -0.18;
uniform float caustic_strength : hint_range(0.0, 0.2) = 0.06;
varying vec3 world_position;

void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
 vec2 p = world_position.xz;
 float grain = sin(p.x * 3.1 + sin(p.y * 1.7)) * sin(p.y * 4.3 + p.x);
 float depth = max(water_height - world_position.y, 0.0);
 vec3 bed = mix(sand_color.rgb, silt_color.rgb, smoothstep(0.5, 6.0, depth));
 bed *= 0.94 + grain * 0.06;
 ALBEDO = mix(bed, grass_color.rgb, smoothstep(water_height, 0.8, world_position.y));
 float lines = pow(1.0 - abs(sin(p.x * 1.8 + sin(p.y * 2.0 + TIME * 0.35))
                      * cos(p.y * 1.5 - TIME * 0.25)), 12.0);
 float shallow = (1.0 - smoothstep(0.3, 2.5, depth)) * step(0.02, depth);
 EMISSION = bed * lines * shallow * caustic_strength;
 ROUGHNESS = 0.95;
}
