shader_type spatial;
uniform sampler2D albedo_tex : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D normal_tex : hint_normal,filter_linear_mipmap,repeat_enable;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world.xz*.34;
 vec3 col=texture(albedo_tex,p).rgb;
 vec3 broad=texture(albedo_tex,world.xz*.045).rgb;
 float dune=sin(world.x*9.0+sin(world.z*.53)*2.7+sin(world.z*1.6)*.24);
 float grain=texture(albedo_tex,world.xz*2.4).r;
 float ripple=sin(world.x*.58+sin(world.z*.36+TIME*.2))*sin(world.z*.61-TIME*.12);
 float caustic=pow(max(0.0,ripple),18.0)*.075;
 ALBEDO=mix(col,broad,.3)*vec3(.61,.74,.68)*(.91+.09*dune)*(.92+.16*grain);ROUGHNESS=.91;
 vec3 sand_normal=texture(normal_tex,p).rgb;
 sand_normal.xy+=(vec2(dune,cos(world.z*7.0+world.x)))*.075;
 NORMAL_MAP=sand_normal;NORMAL_MAP_DEPTH=.85;
 EMISSION=vec3(.025,.13,.12)*caustic;
}
