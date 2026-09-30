extends Node3D

var ocean
var rng=RandomNumberGenerator.new()
var mushroom_batches: Array=[]
var fish_groups: Array=[]
var detail_batches: Array=[]
var octopuses: Array=[]
var pools: Array=[]

func build(world):
	ocean=world;rng.seed=83271
	make_mushrooms();make_fish();make_octopuses();make_sediment()
	set_quality(ocean.game.quality)

func parts(path: String) -> Array:
	var scene=load("res://assets/models/"+path+".glb").instantiate()
	var result=[]
	for child in scene.find_children("*","MeshInstance3D",true,false):
		var mat=child.mesh.surface_get_material(0)
		result.append({"mesh":child.mesh,"name":mat.resource_name if mat else child.name,"transform":child.transform})
	scene.free();return result

func shader(path: String, part: int) -> ShaderMaterial:
	var mat=ShaderMaterial.new();mat.shader=load("res://shaders/"+path+".gdshader")
	mat.set_shader_parameter("part",part)
	if path!="fish":mat.set_shader_parameter("noise_tex",load("res://assets/textures/noise.png"))
	if path=="mushroom":mat.set_shader_parameter("glow_floor",.42 if RenderingServer.get_current_rendering_method()=="gl_compatibility" else .12)
	return mat

func batch(parent: Node3D, mesh: Mesh, transforms: Array, seeds: Array, mat: Material) -> MultiMeshInstance3D:
	var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true
	mm.mesh=mesh;mm.instance_count=transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i,transforms[i]);mm.set_instance_custom_data(i,Color(seeds[i],0,0,1))
	var instance=MultiMeshInstance3D.new();instance.multimesh=mm;instance.material_override=mat
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin=2.0;parent.add_child(instance);return instance

func make_mushrooms():
	var meshes=parts("glow_mushroom")
	var anchors=[Vector2(7,3),Vector2(-6,-5),Vector2(13,-23),Vector2(-15,-22),Vector2(5,-31),Vector2(17,-39),Vector2(-14,-48),Vector2(7,-55),Vector2(-17,-58),Vector2(16,-75),Vector2(-15,-86),Vector2(11,-91),Vector2(-10,-117),Vector2(14,-126),Vector2(-16,15)]
	for index in range(anchors.size()):
		var a=anchors[index];var transforms=[];var seeds=[]
		for i in range(13):
			var angle=rng.randf()*TAU;var radius=sqrt(rng.randf())*3.7
			var x=a.x+cos(angle)*radius;var z=a.y+sin(angle)*radius
			var size=rng.randf_range(.30,1.10) if i>2 else rng.randf_range(1.15,1.75)
			var b=Basis.from_euler(Vector3(rng.randf_range(-.14,.14),rng.randf()*TAU,rng.randf_range(-.12,.12))).scaled(Vector3(size,size*rng.randf_range(.85,1.20),size))
			transforms.append(Transform3D(b,Vector3(x,ocean.floor_height(x,z)-.04,z)));seeds.append(fmod(index*.17+i*.029,1.0))
		for mesh in meshes:
			var kind=0 if "Cap" in mesh.name else 1 if "Gills" in mesh.name else 2
			var instance=batch(self,mesh.mesh,transforms,seeds,shader("mushroom",kind));instance.name="MushroomGarden";mushroom_batches.append(instance)
		if index%3==0 or index==1:
			var light=ocean.add_light(Vector3(a.x,ocean.floor_height(a.x,a.y)+1.8,a.y),Color(.08,.62,.53) if index%2==0 else Color(.12,.29,.8),2.1,8.0)
			light.light_volumetric_fog_energy=.08;pools.append(light)

func make_fish():
	var names=["lanternfish","surgeonfish","bannerfish","manta_ray"]
	var anchors=[
		[Vector3(-7,5,1),Vector3(9,6,-24),Vector3(-8,4,-47),Vector3(8,5,-81),Vector3(-9,6,-120)],
		[Vector3(7,3,-5),Vector3(-9,3,-36),Vector3(10,4,-95)],
		[Vector3(-5,3,-12),Vector3(7,3,-60)],
		[Vector3(0,9,-14),Vector3(-3,8,-89)]
	]
	for species in range(4):
		var meshes=parts(names[species]);var materials=[]
		for kind in range(4):
			var mat=shader("fish",kind);mat.set_shader_parameter("species",species);materials.append(mat)
		for origin in anchors[species]:
			var root=Node3D.new();root.name=names[species];add_child(root)
			var transforms=[];var seeds=[];var instances=[];var fish=[]
			var heading=rng.randf()*TAU
			for i in range([12,8,7,1][species]):
				var size=rng.randf_range(.46,.75) if species==0 else rng.randf_range(.60,1.0)
				if species==3:size=rng.randf_range(.75,.95)
				var scale2=Vector3(size,size*rng.randf_range(.88,1.12),size*rng.randf_range(.90,1.10))
				var pos=origin+Vector3(rng.randf_range(-3,3),rng.randf_range(-.8,.8),rng.randf_range(-3,3))
				var direction=Vector3(sin(heading),rng.randf_range(-.08,.08),cos(heading)).normalized()
				var speed2=[1.5,.95,.65,1.15][species]*rng.randf_range(.82,1.15)
				var rotation2=Basis.looking_at(direction).get_rotation_quaternion()
				var seed=rng.randf()
				fish.append({"pos":pos,"velocity":direction*speed2,"rotation":rotation2,"scale":scale2,"seed":seed,"cruise":speed2,"phase":rng.randf()*TAU,"cycle":rng.randf()*TAU,"period":rng.randf_range(2.4,5.7),"bank":0.0,"effort":.4})
				transforms.append(Transform3D(Basis(rotation2).scaled(scale2),pos));seeds.append(seed)
			for mesh in meshes:
				var kind=0 if "FishSkin" in mesh.name else 1 if "FishFin" in mesh.name else 2 if "Iris" in mesh.name else 3
				instances.append(batch(root,mesh.mesh,transforms,seeds,materials[kind]))
			fish_groups.append({"root":root,"origin":origin,"phase":rng.randf()*TAU,"instances":instances,"species":species,"fish":fish,"active":fish.size()})

func make_octopuses():
	var meshes=parts("octopus")
	for i in range(2):
		var root=Node3D.new();add_child(root)
		var position2=Vector2(10,-13) if i==0 else Vector2(-12,-69)
		root.position=Vector3(position2.x,ocean.floor_height(position2.x,position2.y)+1.0,position2.y)
		root.rotation.y=-.4 if i==0 else 1.1;root.scale=Vector3.ONE*(1.02 if i==0 else 1.25)
		var ledge=ocean.model("basalt_3",root.position-Vector3(0,.9,0),Vector3(3.8,1.0,3.4))
		for child in ledge.find_children("*","MeshInstance3D",true,false):child.material_override=ocean.cliff_material
		for part in meshes:
			var node=MeshInstance3D.new();node.mesh=part.mesh;node.transform=part.transform
			var kind=0 if "OctopusSkin" in part.name else 1 if "Suckers" in part.name else 2 if "Iris" in part.name else 3
			node.material_override=shader("octopus",kind);node.material_override.set_shader_parameter("phase",i*2.6)
			node.extra_cull_margin=.6;root.add_child(node)
		octopuses.append(root)
		var light=ocean.add_light(root.position+Vector3(0,2.4,-1),Color(.16,.48,.63),2.5,9)
		light.light_volumetric_fog_energy=.04;pools.append(light)

func make_sediment():
	var pebble=SphereMesh.new();pebble.radius=1;pebble.height=2;pebble.radial_segments=8;pebble.rings=4
	var transforms=[];var seeds=[]
	for i in range(1500):
		var x=rng.randf_range(-24,24);var z=rng.randf_range(-136,28)
		var scale2=rng.randf_range(.035,.19)
		var b=Basis.from_euler(Vector3(rng.randf(),rng.randf()*TAU,rng.randf())).scaled(Vector3(scale2*1.6,scale2*.55,scale2))
		transforms.append(Transform3D(b,Vector3(x,ocean.floor_height(x,z)+scale2*.2,z)));seeds.append(rng.randf())
	detail_batches.append(batch(self,pebble,transforms,seeds,ocean.cliff_material))
	var shells=parts("seashell")
	transforms=[];seeds=[]
	for i in range(240):
		var x=rng.randf_range(-21,21);var z=rng.randf_range(-133,25)
		var s=rng.randf_range(.35,1.25)
		transforms.append(Transform3D(Basis.from_euler(Vector3(0,rng.randf()*TAU,0)).scaled(Vector3.ONE*s),Vector3(x,ocean.floor_height(x,z)+.05,z)));seeds.append(rng.randf())
	for part in shells:detail_batches.append(batch(self,part.mesh,transforms,seeds,part.mesh.surface_get_material(0)))

func set_quality(quality: int):
	for node in mushroom_batches:node.multimesh.visible_instance_count=[5,9,13][quality]
	for school in fish_groups:
		school.active=maxi(1,int(school.fish.size()*[.25,.55,1.0][quality]))
		for node in school.instances:node.multimesh.visible_instance_count=school.active
	for node in detail_batches:node.multimesh.visible_instance_count=int(node.multimesh.instance_count*[.28,.6,1.0][quality])
	for root in octopuses:
		for node in root.get_children():node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality==2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for light in pools:light.visible=quality>0

func _process(delta):
	var time=Time.get_ticks_msec()*.001
	var dt=minf(delta,.05)
	for school in fish_groups:
		swim(school,dt,time)

func swim(school: Dictionary, dt: float, time: float):
	var species=school.species
	var a=time*[.095,.065,.05,.065][species]+school.phase
	var goal=school.origin+Vector3(sin(a)*6.0,sin(a*.61)*1.0,cos(a*.83)*5.0)
	var velocities=[]
	for i in range(school.active):
		var fish=school.fish[i];var pos: Vector3=fish.pos
		var separation=Vector3.ZERO;var center=Vector3.ZERO;var alignment=Vector3.ZERO;var neighbors=0
		for j in range(school.active):
			if i==j:continue
			var other=school.fish[j];var offset: Vector3=pos-other.pos
			var distance=offset.length()
			if distance<5.0:
				center+=other.pos;alignment+=other.velocity;neighbors+=1
			if distance<1.35 and distance>.001:separation+=offset/distance*(1.35-distance)*2.6
		var steering=(goal-pos)*.16+separation
		if neighbors>0:steering+=(center/neighbors-pos)*.13+(alignment/neighbors-fish.velocity)*.42
		var wander=time*.5+fish.seed*TAU*5
		steering+=Vector3(sin(wander),sin(wander*.71)*.32,cos(wander*.83))*.35
		steering.y+=maxf(0.0,2.0-pos.y)*1.3-maxf(0.0,pos.y-10.0)*1.3
		steering.x-=signf(pos.x)*maxf(0.0,absf(pos.x)-15.0)*1.8
		var alarm=0.0
		if is_instance_valid(ocean.game.player):
			var away=pos-ocean.game.player.position;var distance=away.length()
			if distance<6.0:
				alarm=1.0-distance/6.0;steering+=away/maxf(distance,.1)*alarm*4.8
		if is_instance_valid(ocean.game.camera):
			var away=pos-ocean.game.camera.position;var distance=away.length()
			if distance<2.3:steering+=away/maxf(distance,.1)*(2.3-distance)*2.0
		fish.cycle+=dt*TAU/float(fish.period)
		var burst=pow(maxf(0.0,sin(fish.cycle)),4.0)
		var desired_speed=fish.cruise*(.75+burst*.65+alarm*.8)
		var velocity: Vector3=fish.velocity
		var direction=(velocity+steering*dt).normalized()
		direction.y=clampf(direction.y,-.3,.3);direction=direction.normalized()
		var new_speed=lerpf(velocity.length(),desired_speed,1.0-exp(-dt*1.6))
		velocities.append(direction*new_speed)
		fish.effort=lerpf(fish.effort,clampf(burst+alarm,.08,1.0),1.0-exp(-dt*4.0))
	for i in range(school.active):
		var fish=school.fish[i];var velocity: Vector3=velocities[i]
		var direction=velocity.normalized();var previous: Vector3=fish.velocity.normalized()
		var turn=previous.cross(direction).y/maxf(dt,.001)
		fish.bank=lerpf(fish.bank,clampf(-turn*.6,-.35,.35),1.0-exp(-dt*3.5))
		var target=Basis.looking_at(direction)*Basis(Vector3.FORWARD,fish.bank)
		fish.rotation=fish.rotation.slerp(target.get_rotation_quaternion(),1.0-exp(-dt*5.0))
		fish.pos+=velocity*dt;fish.velocity=velocity
		var frequency=[5.5,3.5,2.8,1.3][species]
		fish.phase=fmod(fish.phase+dt*frequency*(.55+fish.effort*1.35),TAU)
		var transform2=Transform3D(Basis(fish.rotation).scaled(fish.scale),fish.pos)
		var custom=Color(fish.phase,fish.effort,fish.seed,1)
		for node in school.instances:
			node.multimesh.set_instance_transform(i,transform2)
			node.multimesh.set_instance_custom_data(i,custom)
