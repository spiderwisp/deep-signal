extends Node3D

var game
var seabed_material: ShaderMaterial
var environment: Environment
var creatures: Array = []
var beacons: Array = []
var hazards: Array = []
var rock_scenes: Array = []
var particles: CPUParticles3D
var core: Node3D
var cliff_material: StandardMaterial3D
var station_lights: Array=[]
var collapse_cloud: CPUParticles3D
var rng = RandomNumberGenerator.new()
var biome: Node3D

func floor_height(x: float, z: float) -> float:
	return -2.8 + sin(x*.11)*.85 + cos(z*.075)*.65 + sin(x*.21+z*.12)*.35 + sin(x*.72+sin(z*.21))*.18 + sin(x*2.3+z*.36)*cos(z*1.6)*.06

func build(owner_game):
	game = owner_game
	rng.seed = 19221
	make_environment()
	make_floor()
	for i in range(5):
		rock_scenes.append(load("res://assets/models/basalt_%d.glb" % i))
	cliff_material=StandardMaterial3D.new()
	cliff_material.albedo_texture=load("res://assets/textures/cliff.jpg")
	cliff_material.normal_enabled=true
	cliff_material.normal_texture=load("res://assets/textures/cliff_normal.jpg")
	cliff_material.normal_scale=1.1
	cliff_material.roughness_texture=load("res://assets/textures/cliff_rough.jpg")
	cliff_material.roughness=1
	cliff_material.uv1_triplanar=true
	cliff_material.uv1_world_triplanar=true
	cliff_material.uv1_scale=Vector3(.27,.27,.27)
	cliff_material.albedo_color=Color(.56,.63,.61)
	make_cliffs()
	make_station()
	make_life()
	biome=load("res://scripts/biome.gd").new();add_child(biome);biome.build(self)
	make_particles()
	for child in find_children("*","MeshInstance3D",true,false):
		if "rock" in child.name.to_lower():child.material_override=cliff_material

func material(color: Color, emission: float = 0.0, metallic: float = 0.0):
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = .55
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

func model(path: String, pos: Vector3, size: Vector3 = Vector3.ONE):
	var node = load("res://assets/models/" + path + ".glb").instantiate()
	add_child(node)
	node.position = pos
	node.scale = size
	return node

func make_environment():
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.004, .013, .023)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.23, .49, .56)
	environment.ambient_light_energy = .20
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(.022, .085, .115)
	environment.fog_light_energy = .48
	environment.fog_density = .020
	environment.fog_sky_affect = 1.0
	var e = WorldEnvironment.new()
	e.environment = environment
	add_child(e)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, -24, 0)
	sun.light_color = Color(.33, .67, .70)
	sun.light_energy = .43
	add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(24, 165, 0)
	fill.light_color = Color(.07, .3, .39)
	fill.light_energy = .17
	add_child(fill)

func make_floor():
	seabed_material = ShaderMaterial.new()
	seabed_material.shader = load("res://shaders/seabed.gdshader")
	seabed_material.set_shader_parameter("albedo_tex", load("res://assets/textures/sand.jpg"))
	seabed_material.set_shader_parameter("normal_tex", load("res://assets/textures/sand_normal.png"))
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-60, 60, 2):
		for z in range(-155, 51, 2):
			var a = Vector3(x, floor_height(x,z), z)
			var b = Vector3(x+2, floor_height(x+2,z), z)
			var c = Vector3(x, floor_height(x,z+2), z+2)
			var d = Vector3(x+2, floor_height(x+2,z+2), z+2)
			for v in [a,b,c,b,d,c]:
				surface.set_uv(Vector2(v.x,v.z)*.1)
				surface.add_vertex(v)
	surface.index();surface.generate_normals()
	surface.generate_tangents()
	var mesh = MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = seabed_material
	add_child(mesh)

func collision_sphere(pos: Vector3, radius: float):
	var b = StaticBody3D.new()
	var c = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = radius
	c.shape = shape
	b.add_child(c)
	b.position = pos
	add_child(b)

func make_cliffs():
	for side in [-1,1]:
		for i in range(29):
			var z = 37 - i * 6.1
			var x = side * (23 + sin(z*.049)*5 + rng.randf_range(-3,3))
			var rock = rock_scenes[i%5].instantiate()
			add_child(rock)
			rock.position = Vector3(x, rng.randf_range(1,6), z)
			rock.scale = Vector3(rng.randf_range(5,9),rng.randf_range(8,18),rng.randf_range(5,9))
			rock.rotation = Vector3(rng.randf_range(-.4,.4),rng.randf()*TAU,rng.randf_range(-.3,.3))
			for child in rock.find_children("*","MeshInstance3D",true,false):child.material_override=cliff_material
			collision_sphere(rock.position, 4.5)
	for i in range(85):
		var x = rng.randf_range(-23,23)
		var z = rng.randf_range(-141,38)
		if abs(x)<7 and z>-122: x += 11 * sign(x+.001)
		var rock = rock_scenes[i%5].instantiate()
		add_child(rock)
		rock.position = Vector3(x,floor_height(x,z)-.2,z)
		var s = rng.randf_range(.35,2.1)
		rock.scale = Vector3(s*1.7,s,s*1.2)
		rock.rotation.y = rng.randf()*TAU
		for child in rock.find_children("*","MeshInstance3D",true,false):child.material_override=cliff_material
		var near_goal=false
		for target in game.targets:
			if Vector2(x-target.position.x,z-target.position.z).length()<8:near_goal=true
		if s>1.3 and not near_goal:collision_sphere(rock.position,s*.85)
	# Basalt arch frames the approach to the habitat.
	for i in range(8):
		var angle = float(i)/7.0*PI
		var p = Vector3(cos(angle)*18, sin(angle)*17-1,-76)
		var rock = rock_scenes[i%5].instantiate()
		add_child(rock)
		rock.position = p
		rock.scale = Vector3(4.8,4.2,5.0)
		rock.rotation.z = angle
		for child in rock.find_children("*","MeshInstance3D",true,false):child.material_override=cliff_material

func add_light(pos: Vector3, color: Color, energy: float, radius: float):
	var l = OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.omni_attenuation = 1.4
	add_child(l)
	return l

func make_station():
	var habitat = model("habitat",Vector3(0,-.8,-106))
	for child in habitat.find_children("*","MeshInstance3D",true,false):
		child.create_trimesh_collision()
	for z in [-95,-103,-111]:
		station_lights.append(add_light(Vector3(0,4,z),Color(.09,.7,.66),2.2,9))
	for target in game.targets:
		var relay = model("relay", target.position - Vector3(0,2,0))
		beacons.append(relay)
		add_light(target.position+Vector3(0,1,0),Color(.07,.65,.72),2.0,8)
	core = model("core",Vector3(0,4.8,-110))
	add_light(Vector3(0,5.3,-110),Color(.15,.85,.72),3.4,9)
	for i in range(21):
		var p = Vector3(rng.randf_range(-17,17),0,rng.randf_range(-126,-82))
		p.y = floor_height(p.x,p.z)+.2
		var crate = model("crate",p)
		crate.rotation = Vector3(rng.randf_range(-.2,.2),rng.randf()*TAU,rng.randf_range(-.3,.3))
		collision_sphere(p+Vector3(0,.55,0),.55)
	# Surface tether, landing cradle, and recovery beacon.
	var cable = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = .035;cm.bottom_radius=.035;cm.height=52;cm.radial_segments=6
	cable.mesh=cm;cable.position=Vector3(-8,28,19);cable.material_override=material(Color(.34,.4,.33),0,.5);add_child(cable)
	var cradle = model("relay",Vector3(-8,1.0,20),Vector3(1.6,1.6,1.6))
	add_light(Vector3(-8,7,20),Color(.6,.74,.38),2,14)
	for p in [Vector3(-6,0,-44),Vector3(16,0,-79),Vector3(-13,0,-117),Vector3(9,0,-21)]:
		p.y=floor_height(p.x,p.z)
		var vent = model("rock_1",p,Vector3(1.1,3.1,1.1))
		hazards.append(p+Vector3(0,3,0))
		var smoke = CPUParticles3D.new()
		smoke.amount=45;smoke.lifetime=5;smoke.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE;smoke.emission_sphere_radius=.35
		smoke.direction=Vector3.UP;smoke.spread=18;smoke.initial_velocity_min=.9;smoke.initial_velocity_max=1.8;smoke.gravity=Vector3(0,.2,0)
		smoke.scale_amount_min=.3;smoke.scale_amount_max=1.1;smoke.color=Color(.10,.16,.15,.3)
		var smoke_mesh = SphereMesh.new();smoke_mesh.radius=.35;smoke_mesh.height=.7;smoke_mesh.radial_segments=8;smoke_mesh.rings=4
		var sm=StandardMaterial3D.new();sm.albedo_color=Color(.025,.065,.068,.25);sm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;sm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke_mesh.material=sm;smoke.mesh=smoke_mesh;smoke.position=p+Vector3(0,3.1,0);add_child(smoke)
	collapse_cloud=CPUParticles3D.new();collapse_cloud.emitting=false;collapse_cloud.amount=160;collapse_cloud.lifetime=8;collapse_cloud.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;collapse_cloud.emission_box_extents=Vector3(7,4,16)
	collapse_cloud.direction=Vector3.UP;collapse_cloud.spread=170;collapse_cloud.initial_velocity_min=.15;collapse_cloud.initial_velocity_max=.8;collapse_cloud.gravity=Vector3(0,-.07,0)
	collapse_cloud.scale_amount_min=.025;collapse_cloud.scale_amount_max=.14
	var debris=SphereMesh.new();debris.radius=.5;debris.height=1;debris.radial_segments=5;debris.rings=3;debris.material=material(Color(.17,.23,.20));collapse_cloud.mesh=debris;collapse_cloud.position=Vector3(0,7,-105);add_child(collapse_cloud)

func make_life():
	var life = ShaderMaterial.new();life.shader=load("res://shaders/life.gdshader")
	var stalk_mesh = CylinderMesh.new();stalk_mesh.top_radius=.02;stalk_mesh.bottom_radius=.065;stalk_mesh.height=1.2;stalk_mesh.radial_segments=5
	var bulbs = SphereMesh.new();bulbs.radius=.10;bulbs.height=.23;bulbs.radial_segments=8;bulbs.rings=4
	for mesh in [stalk_mesh,bulbs]:
		var mm = MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=330
		rng.seed=456
		for i in range(330):
			var x=rng.randf_range(-25,25);var z=rng.randf_range(-136,35);var h=rng.randf_range(.45,1.6)
			var p=Vector3(x,floor_height(x,z)+(h if mesh==bulbs else h*.45),z)
			var b=Basis.from_euler(Vector3(rng.randf_range(-.2,.2),0,rng.randf_range(-.25,.25))).scaled(Vector3(1,h,1))
			mm.set_instance_transform(i,Transform3D(b,p));mm.set_instance_custom_data(i,Color(rng.randf(),0,0,1))
		var instance=MultiMeshInstance3D.new();instance.multimesh=mm;instance.material_override=life;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(instance)
	var jelly_mat=material(Color(.09,.53,.66),1.5,.15)
	for i in range(14):
		var root=Node3D.new();add_child(root);root.position=Vector3(rng.randf_range(-16,16),rng.randf_range(9,17),rng.randf_range(-125,16))
		var bell=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.43;mesh.height=.48;mesh.radial_segments=16;mesh.rings=8;bell.mesh=mesh;bell.material_override=jelly_mat;root.add_child(bell)
		for k in range(5):
			var tendril=MeshInstance3D.new();var m=CylinderMesh.new();m.top_radius=.014;m.bottom_radius=.006;m.height=1.2; m.radial_segments=4;tendril.mesh=m;tendril.material_override=life;tendril.position=Vector3(cos(k*TAU/5)*.25,-.66,sin(k*TAU/5)*.25);root.add_child(tendril)
		creatures.append({"node":root,"origin":root.position,"phase":rng.randf()*TAU})

func make_particles():
	particles=CPUParticles3D.new();particles.amount=600;particles.lifetime=20;particles.preprocess=20
	particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;particles.emission_box_extents=Vector3(19,11,23)
	particles.direction=Vector3(.3,.1,.2);particles.spread=110;particles.initial_velocity_min=.04;particles.initial_velocity_max=.2;particles.gravity=Vector3.ZERO
	particles.scale_amount_min=.012;particles.scale_amount_max=.065;particles.local_coords=false
	var mesh=QuadMesh.new();mesh.size=Vector2.ONE
	var image=Image.create(32,32,false,Image.FORMAT_RGBA8)
	for x in range(32):
		for y in range(32):
			var a=pow(maxf(0,1.0-Vector2(x-15.5,y-15.5).length()/16),2)*.55
			image.set_pixel(x,y,Color(.35,.61,.60,a))
	var mat=StandardMaterial3D.new();mat.albedo_texture=ImageTexture.create_from_image(image);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.roughness=1.0;mat.emission_enabled=true;mat.emission=Color(.004,.009,.012);mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mat.billboard_keep_scale=true;mesh.material=mat;particles.mesh=mesh
	add_child(particles)

func _process(delta):
	var time=Time.get_ticks_msec()*.001
	for c in creatures:
		c.node.position.y=c.origin.y+sin(time*.35+c.phase)*1.1
		c.node.scale=Vector3.ONE*(1+sin(time*1.2+c.phase)*.05)
	if is_instance_valid(core):core.rotation.y+=delta*.45
	if game.stage==3:
		collapse_cloud.emitting=true
		for l in station_lights:
			l.light_color=Color(1,.23,.045)
			l.light_energy=2.0+sin(time*4)*1.3
	elif collapse_cloud:
		collapse_cloud.emitting=false
		for l in station_lights:l.light_color=Color(.09,.7,.66);l.light_energy=2.2
	if particles and game.player:particles.position=game.player.position+Vector3(0,3,-4)
