extends Control

var game
var font=preload("res://assets/fonts/Rajdhani-Medium.ttf")
var ink=Color(.77,.91,.88)
var muted=Color(.37,.60,.61)
var cyan=Color(.28,.84,.82)
var amber=Color(.96,.65,.32)
var buttons: Array = []

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func word(text: String, pos: Vector2, size: int=20, color: Color=Color(.77,.91,.88)):
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func center(text: String, y: float, size: int, color: Color):
	var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	word(text,Vector2((get_viewport_rect().size.x-width)*.5,y),size,color)

func paragraph(text: String, pos: Vector2, width: float, size: int=21, color: Color=Color(.77,.91,.88)):
	var line="";var y=pos.y
	for w in text.split(" "):
		if font.get_string_size(line+w,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			word(line,Vector2(pos.x,y),size,color);line="";y+=size+6
		line+=w+" "
	word(line,Vector2(pos.x,y),size,color)

func button(title: String, pos: Vector2, callback: Callable, width: float=310):
	var b=Button.new();b.text=title;b.position=pos;b.size=Vector2(width,42)
	b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",21)
	b.add_theme_color_override("font_color",ink);b.add_theme_color_override("font_hover_color",Color.WHITE)
	for state in ["normal","hover","pressed","focus"]:
		var style=StyleBoxFlat.new();style.bg_color=Color(.025,.09,.11,.8 if state=="normal" else .96);style.border_color=cyan if state!="normal" else Color(.17,.32,.34);style.border_width_bottom=1;style.border_width_left=3 if state!="normal" else 1;style.content_margin_left=16
		b.add_theme_stylebox_override(state,style)
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.pressed.connect(callback);add_child(b);buttons.append(b)
	return b

func back():
	game.mode="menu" if game.elapsed==0 else "pause";build_menu()

func build_menu():
	for b in buttons:b.queue_free()
	buttons.clear()
	var h=get_viewport_rect().size.y
	if game.mode=="menu":
		button("BEGIN DESCENT",Vector2(72,h-258),game.start_dive)
		button("GUIDED DIVE",Vector2(72,h-206),game.start_guided)
		button("GRAPHICS",Vector2(72,h-154),game.show_graphics)
		button("CONTROLS",Vector2(72,h-102),game.show_controls)
		button("QUIT",Vector2(396,h-102),game.quit_game,126)
	elif game.mode=="pause":
		button("RESUME DIVE",Vector2(72,265),game.resume_dive)
		button("GRAPHICS",Vector2(72,317),game.show_graphics)
		button("SOUND  /  "+("OFF" if game.muted else "ON"),Vector2(72,369),game.toggle_audio)
		button("CONTROLS",Vector2(72,421),game.show_controls)
		button("RESTART DIVE",Vector2(72,473),game.start_dive)
		button("QUIT",Vector2(72,525),game.quit_game)
	elif game.mode=="graphics":
		for i in range(3):
			var title=game.quality_names[i]+("  /  WEB" if i==2 and OS.has_feature("web") else "")
			button((">  " if i==game.pending_quality else "    ")+title,Vector2(72,229+i*52),game.select_quality.bind(i),390)
		button("DISPLAY  /  "+("FULLSCREEN" if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else "WINDOWED"),Vector2(72,395),game.toggle_fullscreen,390)
		button("V-SYNC  /  "+("ON" if game.vsync else "OFF"),Vector2(72,447),game.toggle_vsync,390)
		button("FRAME LIMIT  /  "+("UNLIMITED" if game.frame_limit==0 else str(game.frame_limit)+" FPS"),Vector2(72,499),game.cycle_frame_limit,390)
		button("APPLY & RESTART" if game.needs_graphics_restart() else "APPLY PRESET",Vector2(72,579),game.apply_graphics,260)
		button("BACK",Vector2(346,579),game.close_graphics,116)
	elif game.mode=="controls":
		button("MAP CONTROLLER BUTTONS",Vector2(72,h-146),game.remap_controller,360)
		button("BACK",Vector2(72,h-94),back)
	elif game.mode=="complete":
		button("DIVE AGAIN",Vector2(72,500),game.start_dive)
		button("QUIT",Vector2(72,552),game.quit_game)
	elif game.mode=="failed":
		button("RETRY FROM CHECKPOINT",Vector2(72,430),game.retry_checkpoint,360)
		button("RESTART DIVE",Vector2(72,482),game.start_dive)
	if buttons.size()>0:buttons[0].grab_focus()
	queue_redraw()

func _draw():
	var size=get_viewport_rect().size;var w=size.x;var h=size.y
	if game.mode=="boot":
		draw_rect(Rect2(Vector2.ZERO,size),Color(.004,.012,.019))
		var a=minf(game.boot_time*.9,1)
		var origin=Vector2(w*.5-62,h*.5-125)
		var p=PackedVector2Array([origin,origin+Vector2(88,0),origin+Vector2(118,28),origin+Vector2(30,28),origin+Vector2(30,47),origin+Vector2(81,47),origin+Vector2(57,70),origin+Vector2(30,70),origin+Vector2(30,99),origin+Vector2(0,124)])
		draw_colored_polygon(p,Color(.27,.84,.82,a))
		center("F G C",h*.5+64,52,Color(.81,.92,.9,a))
		center("FRAMEWORK GAMING CONSOLE",h*.5+102,19,Color(.36,.59,.6,a))
		draw_line(Vector2(w*.5-120,h*.5+140),Vector2(w*.5+120,h*.5+140),Color(.08,.2,.24),2)
		var ptime=fmod(game.boot_time*.5,1.0)
		draw_line(Vector2(w*.5-120+ptime*180,h*.5+140),Vector2(w*.5-60+ptime*180,h*.5+140),cyan,2)
		center("DEEP SIGNAL",h-64,17,muted)
		return
	if game.photo:return
	if game.mode!="play":
		for i in range(40):
			draw_rect(Rect2(i*w/40,0,w/40,h),Color(.006,.018,.027,.88*pow(1-float(i)/40,1.4)))
		word("F G C   /   FIELD EXPEDITIONS",Vector2(74,64),17,cyan)
		draw_line(Vector2(72,84),Vector2(392,84),Color(.22,.45,.46,.6),1)
		if game.mode=="menu":
			word("DEEP",Vector2(67,228),116,ink)
			word("SIGNAL",Vector2(67,323),116,ink)
			word("B E L O W   T H E   S I L E N C E",Vector2(76,365),19,amber)
			paragraph("One lost station. One signal still alive.",Vector2(76,401),420,23,muted)
			word("01  /  THE PELAGIC DESCENT",Vector2(w-313,h-43),17,muted)
		elif game.mode=="pause":
			word("DIVE PAUSED",Vector2(68,195),65,ink)
			word("TAKE A BREATH.",Vector2(74,229),20,muted)
		elif game.mode=="graphics":
			word("GRAPHICS",Vector2(68,170),62,ink)
			word("ACTIVE  /  "+game.quality_names[game.quality],Vector2(74,203),18,muted)
			word(game.quality_names[game.pending_quality],Vector2(552,259),34,cyan)
			var descriptions=["540p internal resolution. Smaller fish schools, sparse seabed detail and fewer particles.","720p internal resolution. Glowing mushroom gardens, animated wildlife and 2x antialiasing. Balanced for FGC.","1080p internal resolution. Dense wildlife, detailed seabed, 4x antialiasing, twin shadowed searchlights and volumetric lighting."]
			if OS.has_feature("web"):descriptions[2]="1080p internal resolution. Dense wildlife, detailed seabed, 4x antialiasing and searchlight shadows. Volumetric lighting is available in the desktop version."
			paragraph(descriptions[game.pending_quality],Vector2(554,309),570,25,ink)
			if game.needs_graphics_restart():
				paragraph("Applying this preset restarts the game automatically. Your current dive is preserved.",Vector2(554,430),560,23,amber)
			else:
				paragraph("This preset applies immediately. Display, V-sync and frame limit changes are saved as you select them.",Vector2(554,430),560,23,muted)
			if not game.graphics_notice.is_empty():paragraph(game.graphics_notice,Vector2(554,542),560,22,cyan)
			word("ARROWS / D-PAD  SELECT     ENTER / A  CONFIRM     ESC / START  BACK",Vector2(74,h-46),17,muted)
		elif game.mode=="controls":
			word("PILOT BRIEFING",Vector2(68,170),57,ink)
			var lines=["W / S  or  D-PAD UP / DOWN     THRUST / REVERSE","A / D  or  D-PAD LEFT / RIGHT     STEER","SPACE / F  or  A     SONAR / INTERACT","SHIFT  or  B     BOOST","Q / E  or  SHOULDER BUTTONS     DESCEND / ASCEND","ESC / P  or  START     PAUSE","F11  FULLSCREEN     F2  HIDE HUD     F12  PHOTO"]
			for i in range(lines.size()):word(lines[i],Vector2(74,231+i*35),22,ink)
			paragraph("Depth assistance holds a safe altitude. Approach a marked objective, then press sonar to interact. Boost recharges automatically. Restore both relays, recover the core, and return to the tether.",Vector2(700,239),440,24,muted)
			paragraph("Using a classic USB gamepad? Map its A, B, and Start buttons below. Left stick and D-pad are both supported.",Vector2(700,418),440,23,cyan)
		elif game.mode=="mapping":
			word("CONTROLLER SETUP",Vector2(68,195),54,ink)
			word("PRESS "+["A  /  SONAR","B  /  BOOST","START  /  PAUSE"][maxi(game.remap_index,0)],Vector2(74,308),40,cyan)
			word("ESC TO CANCEL",Vector2(74,389),20,muted)
		elif game.mode=="complete":
			word("SIGNAL RECOVERED",Vector2(68,206),62,ink)
			paragraph("The station is gone. Its last transmission is coming home with you.",Vector2(74,270),520,27,muted)
			word("DIVE TIME    %02d:%02d" % [int(game.elapsed)/60,int(game.elapsed)%60],Vector2(74,372),30,cyan)
			word("HULL INTEGRITY    %d%%" % game.hull,Vector2(74,413),25,ink)
		elif game.mode=="failed":
			word("SIGNAL LOST",Vector2(68,220),72,ink)
			paragraph("The recovery tether has your last position. Resume from the latest relay.",Vector2(74,291),460,25,muted)
		word("DEEP SIGNAL  /  0.2.0",Vector2(74,h-25),14,muted)
		return
	# Dive instruments.
	word("F G C   /   DS-01",Vector2(35,39),17,muted)
	if game.guided:word("GUIDED DIVE  /  PRESS C TO TAKE CONTROL",Vector2(w*.5-180,39),17,cyan)
	word("PELAGIC TRENCH",Vector2(35,73),26,ink)
	word("%04d M" % int(824-game.player.position.y),Vector2(w-155,48),29,ink)
	word("DEPTH ASSIST",Vector2(w-155,69),14,muted)
	draw_line(Vector2(35,91),Vector2(229,91),Color(.23,.47,.49,.5),1)
	word("0%d  /  %s" % [game.stage+1,game.targets[game.stage].name],Vector2(35,122),22,cyan)
	if game.stage==3:word("COLLAPSE  %02d:%02d" % [int(game.escape_time)/60,int(game.escape_time)%60],Vector2(35,153),24,amber)
	if game.message_time>0:
		draw_rect(Rect2(35,h-224,530,88),Color(.008,.035,.043,.73))
		draw_line(Vector2(35,h-224),Vector2(35,h-136),cyan,2)
		paragraph(game.message,Vector2(50,h-198),491,21,ink)
	word("HULL",Vector2(35,h-97),15,muted)
	draw_rect(Rect2(35,h-84,170,3),Color(.12,.25,.27))
	draw_rect(Rect2(35,h-84,170*game.hull/100,3),cyan if game.hull>30 else amber)
	word("%03d" % game.hull,Vector2(218,h-80),21,ink)
	word("BOOST",Vector2(35,h-51),15,muted)
	draw_rect(Rect2(35,h-38,170,3),Color(.12,.25,.27))
	draw_rect(Rect2(35,h-38,170*game.charge/100,3),amber)
	word("%.1f M/S" % absf(game.speed),Vector2(283,h-41),25,ink)
	var rc=Vector2(w-113,h-112)
	draw_circle(rc,75,Color(.008,.04,.05,.66))
	for radius in [25,50,75]:draw_arc(rc,radius,0,TAU,64,Color(.14,.36,.36,.7),1,true)
	draw_line(rc+Vector2(-75,0),rc+Vector2(75,0),Color(.14,.36,.36,.5),1)
	draw_line(rc+Vector2(0,-75),rc+Vector2(0,75),Color(.14,.36,.36,.5),1)
	var angle=Time.get_ticks_msec()*.0004
	draw_line(rc,rc+Vector2(cos(angle),sin(angle))*73,Color(.21,.61,.56,.35),1)
	draw_colored_polygon(PackedVector2Array([rc+Vector2(0,-6),rc+Vector2(-4,5),rc+Vector2(4,5)]),ink)
	for i in range(game.targets.size()):
		var dp=game.targets[i].position-game.player.position
		var v=Vector2(dp.x,dp.z).rotated(-game.yaw)*.8
		if v.length()>68:v=v.normalized()*68
		draw_circle(rc+v,3.5 if i==game.stage else 2,cyan if i==game.stage else muted)
	word("PASSIVE SONAR",rc+Vector2(-47,97),13,muted)
	var target=game.targets[game.stage].position
	var distance=game.player.position.distance_to(target)
	if not game.camera.is_position_behind(target):
		var screen=game.camera.unproject_position(target+Vector3(0,2,0));screen.x=clampf(screen.x,70,w-70);screen.y=clampf(screen.y,160,h-180)
		draw_arc(screen,9,0,TAU,24,cyan,1.5,true)
		word("%d M" % distance,screen+Vector2(16,6),17,cyan)
	if distance<game.interaction_range:
		center("[ A / SPACE ]   "+game.targets[game.stage].action,h-98,25,cyan)
	elif game.elapsed<20:
		center("WASD / D-PAD  STEER     A / SPACE  SONAR     B / SHIFT  BOOST",h-20,17,muted)
