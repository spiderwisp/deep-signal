shader_type spatial;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform int part=0;
uniform float phase=0.0;
varying vec3 local;
void vertex(){
 local=VERTEX;
 float r=length(VERTEX.xz);float arm=smoothstep(.65,3.7,r);
 float a=atan(VERTEX.z,VERTEX.x);
 VERTEX.y+=sin(TIME*.7+r*2.1+a*2.0+phase)*.17*arm;
 VERTEX.x+=sin(TIME*.45+r*1.6+phase)*.12*arm;
 VERTEX.z+=cos(TIME*.54+r*1.5+phase)*.10*arm;
 if(r<.9)VERTEX.y+=sin(TIME*1.3+phase)*.025*max(VERTEX.y,0.0);
}
void fragment(){
 float n=texture(noise_tex,local.xy*.91).r*.38+texture(noise_tex,local.yz*.87).r*.32+texture(noise_tex,local.zx*.8).r*.3;
 float pores=texture(noise_tex,local.xy*11.0).r*.5+texture(noise_tex,local.yz*9.0).r*.5;
 if(part==0){
  ALBEDO=mix(vec3(.13,.025,.025),vec3(.55,.20,.095),smoothstep(.33,.66,n));
  ALBEDO*=.8+pores*.35;ROUGHNESS=.6;
  NORMAL_MAP=vec3(.5+(pores-.5)*.32,.5+(n-.5)*.16,.98);NORMAL_MAP_DEPTH=.5;
 }else if(part==1){ALBEDO=vec3(.68,.35,.22)*(.8+pores*.2);ROUGHNESS=.55;}
 else if(part==2){ALBEDO=vec3(.67,.42,.13);ROUGHNESS=.2;METALLIC=.5;}
 else{ALBEDO=vec3(.008,.01,.012);ROUGHNESS=.12;}
}
