shader_type spatial;
render_mode cull_disabled;
uniform int part = 0;
uniform int species = 0;
varying vec3 local;
varying float seed;
void vertex(){
 local=VERTEX;seed=INSTANCE_CUSTOM.z;
 float phase=INSTANCE_CUSTOM.x;
 float effort=INSTANCE_CUSTOM.y;
 if(species==3){
  float wing=pow(clamp(abs(VERTEX.x)/2.4,0.0,1.0),1.45);
  VERTEX.y+=sin(phase-abs(VERTEX.x)*1.15)*wing*(.32+effort*.22);
  VERTEX.x+=sin(phase-VERTEX.z*1.8)*smoothstep(.8,2.8,VERTEX.z)*.10;
 }else{
  float tail=smoothstep(-.3,1.2,VERTEX.z);
  float amplitude=(species==0?.14:.11)*(.35+effort*.9);
  float bend=sin(phase-VERTEX.z*3.5+seed*6.28)*amplitude;
  VERTEX.x+=bend*tail*tail;
  if(part==1){
   float flutter=sin(phase*1.7+VERTEX.z*9.0);
   VERTEX.z+=flutter*abs(VERTEX.x)*.09;
   VERTEX.x+=flutter*smoothstep(.3,.9,abs(VERTEX.y))*.028;
  }
 }
}
void fragment(){
 float belly=1.0-smoothstep(-.14,.15,local.y);
 vec3 pigment=vec3(.12,.30,.40);
 float metal=.36;
 float rough=.32;
 float stripe=exp(-pow((local.y+.015)*35.0,2.0));
 if(species==0){
  pigment=mix(vec3(.025,.105,.17),vec3(.50,.68,.73),belly);
  pigment=mix(pigment,vec3(.07,.30,.40),stripe*.65);
  pigment*=.88+seed*.28;
  metal=.65;
 }else if(species==1){
  pigment=mix(vec3(.025,.08,.22),vec3(.075,.29,.44),belly);
  float caudal=smoothstep(.52,.69,local.z);
  float mask=1.0-smoothstep(.055,.09,abs(local.y-.10*sin(local.z*7.0)));
  pigment=mix(pigment,vec3(.008,.018,.04),mask*.55);
  pigment=mix(pigment,vec3(.91,.60,.055),caudal);
  pigment=mix(pigment,pigment*vec3(.8,1.3,1.12),seed*.6);
  metal=.23;
 }else if(species==2){
  float bands=.5+.5*sin((local.z+local.y*.43)*11.5+.4);
  pigment=mix(vec3(.012,.025,.04),vec3(.85,.87,.70),smoothstep(.38,.54,bands));
  float yellow=smoothstep(.31,.49,local.z)*(1.0-smoothstep(.38,.65,local.y));
  pigment=mix(pigment,vec3(.96,.66,.075),yellow);
  if(local.y>.63)pigment=vec3(.90,.92,.78);
  metal=.13;
 }else{
  float spots=sin(local.x*31.0+sin(local.z*17.0))*sin(local.z*38.0+cos(local.x*13.0));
  float underside=1.0-smoothstep(-.07,.015,local.y);
  pigment=mix(vec3(.055,.12,.16),vec3(.55,.63,.59),underside);
  pigment+=smoothstep(.65,.93,spots)*.055;
  metal=.09;rough=.48;
 }
 if(part==0){
  vec2 tile=vec2(UV.x*31.0,UV.y*25.0);tile.x+=mod(floor(tile.y),2.0)*.5;
  vec2 cell=fract(tile)-.5;
  float scale_edge=species==3?0.0:smoothstep(.37,.5,length(cell*vec2(1.0,.85)));
  ALBEDO=pigment*(1.0-scale_edge*.10);METALLIC=metal;ROUGHNESS=rough+scale_edge*.12;SPECULAR=.6;
  if(species!=3){NORMAL_MAP=normalize(vec3(cell.x*.10,cell.y*.10,1.0))*.5+.5;NORMAL_MAP_DEPTH=.18;}
  if(species==0){
   float dots=pow(max(0.0,cos(local.z*58.0)),12.0)*exp(-pow((local.y+.10)*90.0,2.0));
   EMISSION=vec3(.12,.48,.52)*dots*.5;
  }
 }else if(part==1){
  float rays=.85+.15*sin(local.z*95.0+local.y*64.0);
  ALBEDO=pigment*rays;ROUGHNESS=.40;METALLIC=.13;
 }else if(part==2){ALBEDO=species==0?vec3(.43,.56,.61):vec3(.55,.40,.18);ROUGHNESS=.23;METALLIC=.38;}
 else{ALBEDO=vec3(.001,.004,.007);ROUGHNESS=.09;SPECULAR=.9;}
}
