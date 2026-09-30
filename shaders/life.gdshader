shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(.07,.47,.54,1.0);
void vertex(){VERTEX.x+=sin(TIME*1.1+VERTEX.y*2.2+INSTANCE_CUSTOM.x*8.0)*.12*max(VERTEX.y,0.0);}
void fragment(){ALBEDO=tint.rgb*.35;EMISSION=tint.rgb*(.5+.4*sin(TIME*.8+UV.y*6.0));ROUGHNESS=.4;}
