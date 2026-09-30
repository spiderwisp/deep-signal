shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform vec4 tint : source_color = vec4(.62,.82,.94,.12);
void fragment(){
 float along=UV.y;
 float edge=pow(max(0.0,1.0-abs(UV.x-.5)*2.0),1.8);
 float dust=.92+.08*sin(UV.y*220.0+UV.x*90.0-TIME*.75);
 ALBEDO=tint.rgb;ALPHA=tint.a*edge*pow(1.0-along,1.35)*smoothstep(0.0,.025,along)*dust;
}
