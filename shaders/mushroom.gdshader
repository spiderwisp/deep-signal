shader_type spatial;
render_mode cull_disabled;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform int part = 0;
uniform float glow_floor = .12;
varying vec3 local;
varying float seed;
void vertex(){
 local=VERTEX;seed=INSTANCE_CUSTOM.x;
 VERTEX.x+=sin(TIME*.45+seed*15.0+VERTEX.y)*.025*max(VERTEX.y,0.0);
}
void fragment(){
 float n=texture(noise_tex,local.xz*1.8+vec2(seed)).r;
 vec3 tint=mix(vec3(.025,.64,.50),vec3(.09,.27,.9),smoothstep(.2,.9,seed));
 float pulse=.92+.08*sin(TIME*.6+seed*14.0);
 if(part==0){
  float vein=pow(max(0.0,sin(atan(local.z,local.x-.12)*34.0+n*6.0)),16.0);
  float pores=smoothstep(.67,.79,n);
  ALBEDO=mix(vec3(.018,.075,.085),tint*.30,n);ROUGHNESS=.36;METALLIC=.08;
  EMISSION=tint*(glow_floor+vein*.32+pores*1.1)*pulse;
  NORMAL_MAP=vec3(.5+(n-.5)*.2,.5,.98);NORMAL_MAP_DEPTH=.4;
 }else if(part==1){
  float rib=.55+.45*pow(abs(sin(UV.x*201.06)),3.0);
  ALBEDO=tint*.5;ROUGHNESS=.48;EMISSION=tint*(1.2+rib*1.6)*pulse;
 }else{
  ALBEDO=mix(vec3(.04,.10,.10),vec3(.12,.25,.23),n);ROUGHNESS=.78;
  EMISSION=tint*.035*max(local.y,0.0);
 }
}
