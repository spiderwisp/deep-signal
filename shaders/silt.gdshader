shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,shadows_disabled;
uniform vec4 tint : source_color = vec4(.25,.66,.66,.55);
void vertex(){
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
}
void fragment(){float r=length(UV-.5)*2.0;ALBEDO=tint.rgb;ALPHA=pow(max(0.0,1.0-r),2.0)*tint.a;}
