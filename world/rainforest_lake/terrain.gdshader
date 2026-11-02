shader_type spatial;
render_mode diffuse_lambert;
uniform sampler2D grass_texture:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D gravel_texture:source_color,repeat_enable,filter_linear_mipmap;
varying vec3 world_position;
varying vec3 weights;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;weights=COLOR.rgb;}
void fragment(){
 vec3 grass=texture(grass_texture,world_position.xz*.22).rgb*vec3(.52,.65,.46);
 vec3 gravel=texture(gravel_texture,world_position.xz*.30).rgb;
 vec3 sand=gravel*vec3(1.12,1.03,.78);
 vec3 soil=gravel*vec3(.60,.51,.38);
 vec3 ground=mix(sand,soil,weights.b);
 ALBEDO=mix(ground,grass,weights.r);
 ROUGHNESS=.96;SPECULAR=.10;
}
