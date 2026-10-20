shader_type canvas_item;
render_mode unshaded;

void fragment() {
 COLOR = vec4(vec3(0.015, 0.025, 0.035), texture(TEXTURE, UV).a);
}
