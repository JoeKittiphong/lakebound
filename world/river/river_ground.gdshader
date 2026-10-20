shader_type spatial;
render_mode diffuse_lambert;
uniform sampler2D grass_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D gravel_texture : source_color, repeat_enable, filter_linear_mipmap;
varying vec3 world_position;
varying vec3 blend_weights;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 blend_weights = COLOR.rgb;
}
void fragment() {
 vec3 grass = texture(grass_texture, world_position.xz * 0.38).rgb;
 vec3 gravel = texture(gravel_texture, world_position.xz * 0.45).rgb;
 vec3 dirt = gravel * vec3(0.76, 0.65, 0.47);
 vec3 dry = mix(gravel * 0.92, dirt, blend_weights.b * 0.65);
 ALBEDO = mix(dry, grass * vec3(0.55, 0.64, 0.46), clamp(blend_weights.r, 0.0, 1.0));
 ROUGHNESS = 0.95;
 SPECULAR = 0.12;
}


