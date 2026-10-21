shader_type canvas_item;
render_mode unshaded, blend_add;

varying vec2 local_offset;
varying vec4 wave;

void vertex() {
 local_offset = VERTEX;
 wave = INSTANCE_CUSTOM;
}

void fragment() {
 vec2 offset = local_offset * (wave.r + 1.82);
 float distance = length(offset);
 float q = (distance - wave.r) / 0.65;
 if (abs(q) > 2.8 || distance < 0.01) { discard; }
 float k = 6.28318530718 / wave.b;
 float phase = k * (distance - wave.r);
 float envelope = wave.g * exp(-0.5 * q * q);
 float height = envelope * sin(phase);
 float gradient = envelope * (k * cos(phase) - q / 0.65 * sin(phase));
 // Signed additive accumulation requires the viewport's HDR float target.
 // The background supplies the neutral bias, only once for all impulses.
 COLOR = vec4(-gradient * offset / distance * 0.5, height / 0.4, 1.0);
}
