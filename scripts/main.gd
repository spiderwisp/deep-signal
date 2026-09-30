extends Node3D

const Ocean = preload("res://scripts/ocean.gd")
const Interface = preload("res://scripts/interface.gd")
var mode = "boot"
var boot_time = 0.0
var elapsed = 0.0
var game_time = 0.0
var stage = 0
var hull = 100.0
var charge = 100.0
var speed = 0.0
var yaw = 0.0
var target_depth = 5.0
var sonar_time = 0.0
var sonar_cooldown = 0.0
var impact_cooldown = 0.0
var escape_time = 150.0
var quality = 1
var quality_names = ["PERFORMANCE", "FGC", "ULTRA"]
var pending_quality = 1
var fullscreen = false
var vsync = true
var frame_limit = 60
var graphics_return = "menu"
var graphics_notice = ""
var renderer_starting = false
var restart_session: Dictionary = {}
var console_session_path = ""
var console_tick = 0.0
var guided = false
var guided_entered = false
var guided_exited = false
var targets = [
	{"position":Vector3(-10,3.5,-28),"name":"WEST RELAY","action":"RESTORE WEST RELAY"},
	{"position":Vector3(12,3.5,-61),"name":"EAST RELAY","action":"RESTORE EAST RELAY"},
	{"position":Vector3(0,4.8,-110),"name":"PELAGIC / CORE","action":"RECOVER THE CORE"},
	{"position":Vector3(-8,6,18),"name":"RECOVERY TETHER","action":"DOCK / FINISH DIVE"}
]
var messages = [
	"PELAGIC went silent 19 days ago. Follow its last signal. Restore both relays to locate the core.",
	"West relay online. A second carrier signal is coming from deeper in the trench.",
	"The habitat is ahead. Enter through the illuminated ring. The core is still transmitting.",
	"Core secured. Structural failure detected. Return to the surface tether before the station collapses."
]
var message = ""
var message_time = 0.0
var checkpoint = Vector3(0,5,12)
var checkpoint_yaw = 0.0
var player: CharacterBody3D
var sub: Node3D
var camera: Camera3D
var ocean: Node3D
var hud: Control
var headlights: Array = []
var beam_meshes: Array=[]
var lens: ShaderMaterial
var ambience: AudioStreamPlayer
var score_audio: AudioStreamPlayer
var engine_audio: AudioStreamPlayer
var muted = false
var photo = false
var remap_index = -1
var controller_bindings = [0,1,6]
var fps_average = 60.0
var interact_hold = 0.0
var interaction_range = 7.0

func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fgc-session="):console_session_path=arg.trim_prefix("--fgc-session=")
	console_status("running")
	setup_input()
	load_settings()
	if not console_session_path.is_empty() and "--graphics-restarted" not in OS.get_cmdline_user_args():fullscreen=true
	if prepare_renderer():return
	apply_display()
	var ui = CanvasLayer.new();ui.layer=5;add_child(ui)
	hud = Interface.new();hud.game=self;ui.add_child(hud)
	await get_tree().process_frame
	ocean=Ocean.new();add_child(ocean);ocean.build(self)
	make_player()
	make_lens()
	make_audio()
	apply_quality()
	get_viewport().size_changed.connect(apply_quality)
	play_sound("boot",-8)
	hud.build_menu()

func setup_input():
	var key_actions={"forward":[KEY_W,KEY_UP],"reverse":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"rise":[KEY_E],"dive":[KEY_Q],"sonar":[KEY_SPACE,KEY_F],"boost":[KEY_SHIFT],"pause_dive":[KEY_ESCAPE,KEY_P]}
	for action in key_actions:
		if not InputMap.has_action(action):InputMap.add_action(action)
		for key in key_actions[action]:
			var event=InputEventKey.new();event.physical_keycode=key;InputMap.action_add_event(action,event)
			var logical=InputEventKey.new();logical.keycode=key;InputMap.action_add_event(action,logical)
	bind_controller()

func bind_controller():
	for i in range(3):
		var action=["sonar","boost","pause_dive"][i]
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:InputMap.action_erase_event(action,event)
		var e=InputEventJoypadButton.new();e.button_index=controller_bindings[i];InputMap.action_add_event(action,e)

func make_player():
	player=CharacterBody3D.new();player.name="Submersible";player.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING;add_child(player);player.position=checkpoint
	var shape=CollisionShape3D.new();var s=SphereShape3D.new();s.radius=.74;shape.shape=s;shape.position.y=.1;player.add_child(shape)
	sub=load("res://assets/models/submersible.glb").instantiate();player.add_child(sub)
	for x in [-.74,.74]:
		var light=SpotLight3D.new();light.position=Vector3(x,-.07,-1.62);light.rotation_degrees.x=-7;light.light_color=Color(.79,.92,1.0);light.light_energy=24.0;light.light_volumetric_fog_energy=7.0;light.spot_range=60;light.spot_angle=13;light.spot_attenuation=1.0;light.spot_angle_attenuation=1.0;light.shadow_bias=.035;light.shadow_normal_bias=.65;player.add_child(light);headlights.append(light)
		var spill=SpotLight3D.new();spill.position=light.position;spill.rotation_degrees.x=-8;spill.light_color=Color(.40,.67,.72);spill.light_energy=2.4;spill.light_volumetric_fog_energy=.12;spill.spot_range=29;spill.spot_angle=42;spill.spot_angle_attenuation=1.4;player.add_child(spill)
		var beam=MeshInstance3D.new();var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in range(2):
			var a=Vector3(-.12,0,0);var b=Vector3(.12,0,0);var c=Vector3(-11,0,-43);var d=Vector3(11,0,-43)
			for v in [[a,Vector2(0,0)],[b,Vector2(1,0)],[c,Vector2(0,1)],[b,Vector2(1,0)],[d,Vector2(1,1)],[c,Vector2(0,1)]]:
				var p=v[0]
				if k==1:p=Vector3(p.y,p.x,p.z)
				surface.set_uv(v[1]);surface.add_vertex(p)
		beam.mesh=surface.commit();var mat=ShaderMaterial.new();mat.shader=load("res://shaders/beam.gdshader");beam.material_override=mat;beam.position=light.position;beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;player.add_child(beam)
		beam.rotation_degrees.x=-5;beam_meshes.append(beam)
	var fill=OmniLight3D.new();fill.position=Vector3(0,2,1);fill.omni_range=6;fill.light_color=Color(.14,.46,.49);fill.light_energy=1.5;fill.light_volumetric_fog_energy=0;player.add_child(fill)
	camera=Camera3D.new();camera.fov=64;camera.near=.15;camera.far=170;add_child(camera);camera.position=Vector3(3,8,20);camera.current=true

func make_lens():
	var c=CanvasLayer.new();c.layer=2;add_child(c)
	var rect=ColorRect.new();rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	lens=ShaderMaterial.new();lens.shader=load("res://shaders/water_lens.gdshader");rect.material=lens;c.add_child(rect)

func make_audio():
	for name in ["abyss","undertow"]:
		var a=AudioStreamPlayer.new();var stream=load("res://assets/audio/"+name+".wav").duplicate();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=stream.data.size()/4;a.stream=stream;a.volume_db=-7 if name=="abyss" else -10;add_child(a);a.play()
		if name=="abyss":ambience=a
		else:score_audio=a

func play_sound(name: String, volume: float = -4.0):
	var a=AudioStreamPlayer.new();a.stream=load("res://assets/audio/"+name+".wav");a.volume_db=volume;add_child(a);a.finished.connect(a.queue_free);a.play()

func load_settings():
	var cfg=ConfigFile.new()
	if cfg.load("user://settings.cfg")==OK:
		quality=clampi(cfg.get_value("video","quality",1),0,2)
		fullscreen=cfg.get_value("video","fullscreen",false)
		vsync=cfg.get_value("video","vsync",true)
		frame_limit=cfg.get_value("video","frame_limit",60)
		if frame_limit not in [0,30,60,120]:frame_limit=60
		renderer_starting=cfg.get_value("video","renderer_starting",false)
		restart_session=cfg.get_value("session","restart",{})
		muted=cfg.get_value("audio","muted",false)
		controller_bindings=cfg.get_value("input","buttons",[0,1,6])
		bind_controller()
	AudioServer.set_bus_mute(0,muted)

func save_settings():
	var cfg=ConfigFile.new()
	for entry in {"quality":quality,"fullscreen":fullscreen,"vsync":vsync,"frame_limit":frame_limit,"renderer_starting":renderer_starting}:
		cfg.set_value("video",entry,get(entry))
	cfg.set_value("session","restart",restart_session)
	cfg.set_value("audio","muted",muted);cfg.set_value("input","buttons",controller_bindings);cfg.save("user://settings.cfg")

func desired_renderer(preset: int) -> String:
	return "forward_plus" if preset==2 and not OS.has_feature("web") else "gl_compatibility"

func needs_graphics_restart() -> bool:
	return not OS.has_feature("web") and desired_renderer(pending_quality)!=RenderingServer.get_current_rendering_method()

func prepare_renderer() -> bool:
	if OS.has_feature("web") or DisplayServer.get_name()=="headless":return false
	var restarted="--graphics-restarted" in OS.get_cmdline_user_args()
	if renderer_starting and not restarted:
		quality=1;renderer_starting=false
		graphics_notice="The previous graphics change did not finish. FGC settings have been restored."
	if desired_renderer(quality)!=RenderingServer.get_current_rendering_method():
		if restarted:
			quality=1;renderer_starting=false
			graphics_notice="Ultra is unavailable on this device. FGC settings have been restored."
		else:
			restart_renderer();return true
	return false

func restart_renderer():
	renderer_starting=true;save_settings()
	var args=PackedStringArray(["--rendering-method",desired_renderer(quality)])
	if OS.has_feature("editor"):
		args.append_array(["--path",ProjectSettings.globalize_path("res://")])
	args.append_array(["--","--graphics-restarted"])
	if not console_session_path.is_empty():args.append("--fgc-session="+console_session_path)
	console_status("restarting")
	OS.set_restart_on_exit(true,args)
	get_tree().quit()

func apply_display():
	Engine.max_fps=frame_limit
	if DisplayServer.get_name()=="headless":return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	# Browsers require a direct gesture for fullscreen.
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func show_graphics():
	graphics_return=mode;pending_quality=quality;mode="graphics";hud.build_menu()

func select_quality(preset: int):
	pending_quality=preset;graphics_notice="";hud.build_menu()
	if hud.buttons.size()>preset:hud.buttons[preset].grab_focus()

func close_graphics():
	mode=graphics_return;hud.build_menu()

func apply_graphics():
	quality=pending_quality
	if needs_graphics_restart():
		restart_session={"return":graphics_return,"dive":graphics_return=="pause"}
		if graphics_return=="pause":
			for property in ["elapsed","game_time","stage","hull","charge","speed","yaw","target_depth","escape_time","checkpoint","checkpoint_yaw","guided","guided_entered","guided_exited"]:
				restart_session[property]=get(property)
			restart_session["position"]=player.position
			restart_session["velocity"]=player.velocity
		restart_renderer();return
	apply_quality();graphics_notice="Graphics settings saved.";hud.build_menu()
	hud.buttons[-2].grab_focus()

func restore_graphics_session():
	if not restart_session.is_empty():
		graphics_return=restart_session.get("return","menu")
		if restart_session.get("dive",false):
			for property in ["elapsed","game_time","stage","hull","charge","speed","yaw","target_depth","escape_time","checkpoint","checkpoint_yaw","guided","guided_entered","guided_exited"]:
				if restart_session.has(property):set(property,restart_session[property])
			player.position=restart_session.get("position",checkpoint)
			player.velocity=restart_session.get("velocity",Vector3.ZERO);player.rotation.y=yaw
			ocean.core.visible=stage<3
		mode="graphics";pending_quality=quality
		if graphics_notice.is_empty():graphics_notice="Graphics settings saved. Your dive is ready to resume." if graphics_return=="pause" else "Graphics settings saved."
		restart_session={}
	elif not graphics_notice.is_empty():
		mode="graphics";pending_quality=quality
	renderer_starting=false;save_settings()

func toggle_fullscreen():
	fullscreen=DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings();hud.build_menu()
	if mode=="graphics":hud.buttons[3].grab_focus()

func toggle_vsync():
	vsync=not vsync;apply_display();save_settings();hud.build_menu();hud.buttons[4].grab_focus()

func cycle_frame_limit():
	var limits=[30,60,120,0]
	frame_limit=limits[(limits.find(frame_limit)+1)%limits.size()]
	apply_display();save_settings();hud.build_menu();hud.buttons[5].grab_focus()

func apply_quality():
	var vp=get_viewport()
	var height=maxf(vp.get_visible_rect().size.y,1)
	vp.scaling_3d_scale=clampf((540.0 if quality==0 else 720.0 if quality==1 else 1080.0)/height,.25,1.5)
	vp.msaa_3d=Viewport.MSAA_DISABLED if quality==0 else Viewport.MSAA_2X if quality==1 else Viewport.MSAA_4X
	if ocean and ocean.particles:ocean.particles.amount=[300,750,1600][quality]
	if ocean and ocean.biome:ocean.biome.set_quality(quality)
	vp.positional_shadow_atlas_size=4096 if quality==2 else 2048
	if ocean and ocean.environment:
		ocean.environment.glow_enabled=quality>0
		ocean.environment.glow_intensity=.65
		ocean.environment.glow_bloom=0.0
		ocean.environment.ssao_enabled=quality==2
		ocean.environment.ssao_radius=1.4
		ocean.environment.ssao_intensity=1.1
		ocean.environment.ambient_light_energy=.15 if quality==2 else .23
		if RenderingServer.get_current_rendering_method()=="forward_plus":
			ocean.environment.volumetric_fog_enabled=quality==2
			ocean.environment.volumetric_fog_density=.009
			ocean.environment.fog_density=.005 if quality==2 else .020
			ocean.environment.volumetric_fog_albedo=Color(.34,.50,.58)
			ocean.environment.volumetric_fog_emission=Color(.001,.004,.007)
			ocean.environment.volumetric_fog_anisotropy=.12
			ocean.environment.volumetric_fog_length=80
			ocean.environment.volumetric_fog_temporal_reprojection_amount=.65
			ocean.environment.ssil_enabled=quality==2
			ocean.environment.ssil_intensity=.45
	for light in headlights:light.shadow_enabled=quality==2
	for beam in beam_meshes:beam.visible=RenderingServer.get_current_rendering_method()!="forward_plus"
	if lens:lens.set_shader_parameter("bloom",[.08,.16,.12][quality])
	save_settings()

func toggle_audio():
	muted=not muted;AudioServer.set_bus_mute(0,muted);save_settings();hud.build_menu()

func start_dive():
	guided=false
	guided_entered=false;guided_exited=false
	mode="play";elapsed=0;game_time=0;stage=0;hull=100;charge=100;escape_time=150;yaw=0;speed=0;target_depth=5;checkpoint=Vector3(0,5,12);checkpoint_yaw=0;player.position=checkpoint;player.velocity=Vector3.ZERO;player.rotation.y=yaw
	if ocean.core:ocean.core.visible=true
	message=messages[0];message_time=13;hud.build_menu();play_sound("confirm")

func start_guided():
	start_dive();guided=true

func resume_dive():
	mode="play";hud.build_menu()

func retry_checkpoint():
	player.position=checkpoint;player.velocity=Vector3.ZERO;yaw=checkpoint_yaw;speed=0;hull=100;charge=100;target_depth=checkpoint.y
	if stage==3:escape_time=150
	guided_entered=false;guided_exited=false
	mode="play";hud.build_menu()

func show_controls():
	mode="controls";hud.build_menu()

func remap_controller():
	remap_index=0;mode="mapping";hud.build_menu()

func _input(event):
	if event is InputEventJoypadButton and event.pressed and remap_index>=0:
		controller_bindings[remap_index]=event.button_index;remap_index+=1
		if remap_index>=3:remap_index=-1;bind_controller();save_settings();mode="controls";hud.build_menu()
		get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F11:
			toggle_fullscreen()
		if event.physical_keycode==KEY_F2:photo=not photo
		if event.physical_keycode==KEY_F12:take_photo()
		if event.physical_keycode==KEY_C and mode=="play":guided=not guided
	if event.is_action_pressed("pause_dive"):
		if mode=="play":mode="pause";hud.build_menu()
		elif mode=="pause":resume_dive()
		elif mode=="graphics":close_graphics()
		elif mode in ["controls","mapping"]:remap_index=-1;mode="menu" if elapsed==0 else "pause";hud.build_menu()
		get_viewport().set_input_as_handled()
	if mode=="menu" and event is InputEventJoypadButton and event.pressed and event.button_index==controller_bindings[2]:start_dive()

func _unhandled_input(event):
	if mode=="play" and event.is_action_pressed("sonar"):
		ping_or_interact()

func ping_or_interact():
	var dist=player.position.distance_to(targets[stage].position)
	if dist<interaction_range:
		advance_mission();return
	if sonar_cooldown>0:return
	sonar_time=.001;sonar_cooldown=3.5;play_sound("sonar",-2)
	message="SIGNAL RETURN  /  %s  /  %d METERS" % [targets[stage].name,dist];message_time=3.5

func advance_mission():
	if stage==3:
		mode="complete";speed=0;play_sound("core",-1);hud.build_menu();return
	stage+=1;hull=minf(hull+25,100);charge=100
	checkpoint=player.position;checkpoint_yaw=yaw
	if stage==3:
		ocean.core.visible=false;escape_time=150;play_sound("core",-1);sonar_time=.001
	else:play_sound("confirm",-1)
	message=messages[stage];message_time=12

func _physics_process(dt):
	if not player or mode!="play":return
	elapsed+=dt;game_time+=dt
	var steering=Input.get_axis("left","right")
	var thrust=Input.get_axis("reverse","forward")
	var vertical=Input.get_axis("dive","rise")
	var joys=Input.get_connected_joypads()
	if joys.size()>0:
		var j=joys[0];var ax=Input.get_joy_axis(j,JOY_AXIS_LEFT_X);var ay=Input.get_joy_axis(j,JOY_AXIS_LEFT_Y)
		if absf(ax)>.18:steering=ax
		if absf(ay)>.18:thrust=-ay
		if Input.is_joy_button_pressed(j,JOY_BUTTON_DPAD_LEFT):steering=-1
		if Input.is_joy_button_pressed(j,JOY_BUTTON_DPAD_RIGHT):steering=1
		if Input.is_joy_button_pressed(j,JOY_BUTTON_DPAD_UP):thrust=1
		if Input.is_joy_button_pressed(j,JOY_BUTTON_DPAD_DOWN):thrust=-1
		if Input.is_joy_button_pressed(j,JOY_BUTTON_LEFT_SHOULDER):vertical=-1
		if Input.is_joy_button_pressed(j,JOY_BUTTON_RIGHT_SHOULDER):vertical=1
	if guided:
		var goal=targets[stage].position
		if stage==2 and not guided_entered:
			goal=Vector3(0,4.8,-90)
			if player.position.distance_to(goal)<2.0:guided_entered=true
		if stage==3 and not guided_exited:
			goal=Vector3(0,4.8,-87)
			if player.position.distance_to(goal)<2.0:guided_exited=true
		var offset=goal-player.position
		var heading=atan2(-offset.x,-offset.z)
		var angle=wrapf(heading-yaw,-PI,PI)
		steering=clampf(-angle*2.0,-1,1)
		thrust=clampf(1.0-absf(angle)*1.1,0,1)*.8
		target_depth=maxf(goal.y,4.8)
		if player.position.distance_to(targets[stage].position)<interaction_range-1 and (stage!=2 or guided_entered) and (stage!=3 or guided_exited):advance_mission()
	yaw-=steering*dt*1.20
	var boosting=Input.is_action_pressed("boost") and charge>1 and thrust>.1
	var max_speed=9.4 if boosting else 5.3
	charge=clampf(charge+dt*(-17 if boosting else 10),0,100)
	speed=move_toward(speed,thrust*max_speed,dt*3.1)
	if absf(vertical)>.1:target_depth=clampf(target_depth+vertical*dt*3,2.5,17)
	var floor_level=ocean.floor_height(player.position.x,player.position.z)
	var desired_depth=maxf(target_depth,floor_level+2.1)
	var forward=Vector3(-sin(yaw),0,-cos(yaw))
	player.velocity=forward*speed
	player.velocity.y=clampf((desired_depth-player.position.y)*2.4,-3,3)
	player.rotation.y=yaw
	sub.rotation.z=lerpf(sub.rotation.z,-steering*.11,dt*3)
	sub.rotation.x=lerpf(sub.rotation.x,-player.velocity.y*.035,dt*3)
	player.move_and_slide()
	player.position.y=maxf(player.position.y,floor_level+1.0)
	player.position.x=clampf(player.position.x,-31,31);player.position.z=clampf(player.position.z,-138,32)
	if player.get_slide_collision_count()>0 and impact_cooldown<=0 and absf(speed)>2.3:
		damage(absf(speed)*1.2);speed*=.38;impact_cooldown=1.7
	for vent in ocean.hazards:
		if player.position.distance_to(vent)<2.8 and impact_cooldown<=0:damage(12);impact_cooldown=2;message="THERMAL PLUME  /  MOVE CLEAR";message_time=3
	if stage==3:
		escape_time=maxf(escape_time-dt,0)
		if escape_time==0:mode="failed";hud.build_menu()
		if int(escape_time)%20==0 and escape_time-floor(escape_time)<dt:play_sound("alarm",-9)

func damage(amount: float):
	hull=maxf(hull-amount,0);play_sound("impact",-3)
	if hull<=0:mode="failed";hud.build_menu()

func _process(dt):
	console_tick+=dt
	if console_tick>=1.0:
		console_tick=0.0;console_status("running")
	boot_time+=dt
	if not camera:return
	fps_average=lerpf(fps_average,Engine.get_frames_per_second(),minf(dt*.8,1))
	sonar_cooldown=maxf(sonar_cooldown-dt,0);impact_cooldown=maxf(impact_cooldown-dt,0);message_time=maxf(message_time-dt,0)
	if sonar_time>0:
		sonar_time+=dt*.5
		if sonar_time>=1:sonar_time=0
	if mode=="boot" and boot_time>3.8:
		mode="menu";restore_graphics_session();hud.build_menu()
		if "--guided" in OS.get_cmdline_user_args():start_guided()
	var desired: Vector3
	var look: Vector3
	if mode in ["menu","boot","controls","mapping","graphics"] and elapsed==0:
		var t=boot_time*.065
		desired=Vector3(-8+sin(t)*2,7.7,18+cos(t)*2)
		look=Vector3(0,4.6,-9)
		player.position=Vector3(-.4,4.8+sin(boot_time*.4)*.1,9)
		player.rotation.y=-.16
	else:
		var backward=Vector3(sin(yaw),0,cos(yaw))
		desired=player.position+backward*7.6+Vector3(0,3.2,0)
		look=player.position-backward*4+Vector3(0,.8,0)
		var query=PhysicsRayQueryParameters3D.create(player.position+Vector3(0,.6,0),desired)
		query.exclude=[player.get_rid()]
		var hit=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():desired=hit.position+(player.position-hit.position).normalized()*.45
	camera.position=camera.position.lerp(desired,1-exp(-dt*3.0))
	if camera.position.distance_to(look)>.1:camera.look_at(look)
	camera.fov=lerpf(camera.fov,68 if Input.is_action_pressed("boost") and mode=="play" else 62,dt*2)
	lens.set_shader_parameter("sonar",sonar_time)
	lens.set_shader_parameter("danger",clampf((45-hull)/45.0,0,1)+(0.2 if stage==3 else 0.0))
	hud.queue_redraw()

func take_photo():
	var old=photo;photo=true;hud.queue_redraw()
	await RenderingServer.frame_post_draw
	var path="user://DeepSignal_%s.png" % Time.get_datetime_string_from_system().replace(":","-")
	get_viewport().get_texture().get_image().save_png(path)
	photo=old;message="PHOTO SAVED  /  "+ProjectSettings.globalize_path(path);message_time=6

func quit_game():
	if OS.has_feature("web"):
		mode="menu";elapsed=0;hud.build_menu();return
	console_status("exited");get_tree().quit()

func console_status(state: String):
	if console_session_path.is_empty():return
	var f=FileAccess.open(console_session_path,FileAccess.WRITE)
	if f:f.store_string(JSON.stringify({"pid":OS.get_process_id(),"state":state,"time":Time.get_unix_time_from_system()}))

func _notification(what):
	if what==NOTIFICATION_WM_CLOSE_REQUEST and not OS.is_restart_on_exit_set():console_status("exited")
