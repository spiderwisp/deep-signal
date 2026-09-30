shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 1.0;
uniform float danger = 0.0;
uniform float sonar = 0.0;
uniform float bloom = 0.22;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){
 vec2 uv=SCREEN_UV;vec2 px=SCREEN_PIXEL_SIZE;
 vec2 warp=vec2(sin(uv.y*28.0+TIME*.35),cos(uv.x*23.0-TIME*.26))*.0006*strength;
 vec3 c=texture(screen_tex,uv+warp).rgb;
 vec3 glow=vec3(0.0);
 for(int i=0;i<8;i++){
  float a=float(i)*.785398;vec2 d=vec2(cos(a),sin(a))*px*5.0;
  glow+=max(texture(screen_tex,uv+d).rgb-vec3(.59),vec3(0.0));
 }
 c+=glow*bloom;
 float vignette=smoothstep(.95,.23,length((uv-.5)*vec2(1.2,1.0)));
 c*=mix(.54,1.03,vignette);
 c+=vec3(-.012,.010,.014)*strength;
 float grain=(hash(uv*vec2(1920,1080)+fract(TIME)*19.0)-.5)*.012;
 c+=grain;
 c=mix(c,c*vec3(1.18,.62,.58),danger*(1.0-vignette)*.65);
 float ring=1.0-smoothstep(.0,.018,abs(length((uv-.5)*vec2(1.777,1.0))-sonar*1.3));
 c+=vec3(.03,.17,.14)*ring*step(.001,sonar)*(1.0-sonar);
 COLOR=vec4(c,1.0);
}
