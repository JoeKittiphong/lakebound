shader_type canvas_item;

uniform vec2 player_uv = vec2(0.5);
uniform vec2 span_uv = vec2(0.2, 0.4);
uniform vec4 outside_color : source_color = vec4(0.10, 0.18, 0.15, 1.0);

void fragment() {
	vec2 map_uv = player_uv + (UV - vec2(0.5)) * span_uv;
	float inside_map = step(0.0, map_uv.x) * step(map_uv.x, 1.0) * step(0.0, map_uv.y) * step(map_uv.y, 1.0);
	vec4 terrain = texture(TEXTURE, clamp(map_uv, vec2(0.0), vec2(1.0)));
	COLOR = mix(outside_color, terrain, inside_map);
	float edge = max(fwidth(length(UV - vec2(0.5))), 0.001);
	COLOR.a *= 1.0 - smoothstep(0.5 - edge, 0.5, length(UV - vec2(0.5)));
}
