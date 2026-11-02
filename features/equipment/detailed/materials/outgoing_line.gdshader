shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D line_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 line_color : source_color = vec4(0.7, 0.9, 0.6, 1.0);
void fragment() {
	vec4 ink = texture(line_texture, UV);
	ALBEDO = line_color.rgb * ink.rgb;
	ALPHA = ink.a * line_color.a;
}
