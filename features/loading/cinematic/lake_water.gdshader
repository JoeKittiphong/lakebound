shader_type spatial;
render_mode cull_disabled;
uniform vec4 lake_color : source_color = vec4(0.13, 0.49, 0.56, 1.0);
uniform vec4 sky_color : source_color = vec4(0.58, 0.78, 0.87, 1.0);
uniform float wave_height : hint_range(0.0, 0.2) = 0.025;
varying vec3 world_position;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 VERTEX.y += sin(world_position.x * 0.65 + TIME * 0.65) * wave_height;
 VERTEX.y += cos(world_position.z * 0.9 + TIME * 0.45) * wave_height * 0.5;
}
void fragment() {
 vec2 p = world_position.xz;
 float wave_a = sin(p.x * 1.7 + p.y * 2.2 + sin(p.y * 0.35) + TIME * 0.8);
 float wave_b = sin(p.x * 3.2 - p.y * 1.5 + sin(p.x * 0.4) - TIME * 0.55);
 vec3 normal_wave = normalize(vec3(wave_a * 0.025, 1.0, wave_b * 0.018));
 NORMAL = normalize((VIEW_MATRIX * vec4(normal_wave, 0.0)).xyz);
 float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
 float ribbons = smoothstep(0.93, 1.0, sin(p.y * 4.0 + wave_a * 1.1 + TIME * 0.6));
 ALBEDO = mix(lake_color.rgb, sky_color.rgb, fresnel * 0.7) + ribbons * 0.018;
 ROUGHNESS = 0.4;
 SPECULAR = 0.35;
 METALLIC = 0.05;
}
