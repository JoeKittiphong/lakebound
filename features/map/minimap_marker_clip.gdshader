shader_type canvas_item;
varying vec2 local_point;
uniform vec2 view_size = vec2(168.0);

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	float radius = min(view_size.x, view_size.y) * 0.5;
	float d = length(local_point - view_size * 0.5);
	COLOR.a *= 1.0 - smoothstep(radius - 0.7, radius, d);
}
