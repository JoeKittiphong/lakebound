shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 ring_color:source_color=vec4(.4,.78,1,.8);
uniform float radius_m=4.5;
uniform float committed=0.0;
uniform float scan_period=2.4;
float scan_wave(float radius,float progress,float width,float aa){
 float edge=1.0-smoothstep(width,width+aa,abs(radius-progress));
 return edge*smoothstep(0.0,.08,progress)*(1.0-smoothstep(.72,1.0,progress));
}
void fragment(){
 float radius=length(UV*2.0-1.0)*1.04;
 float width=.035/max(radius_m,.1);
 float aa=max(fwidth(radius),.0005);
 float progress=fract(TIME/max(scan_period,.1));
 float mask=max(scan_wave(radius,progress,width,aa),scan_wave(radius,fract(progress+.5),width,aa));
 float pulse=mix(1.0,.8+.2*sin(TIME*7.0),committed);
 ALBEDO=ring_color.rgb*pulse;
 ALPHA=ring_color.a*mask;
}
