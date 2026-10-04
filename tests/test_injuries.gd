extends SceneTree

class InjuryArena extends Node3D:
	var hits: Array[Dictionary] = []
	var rules := WreckRules.new()
	func is_live() -> bool: return true
	func rider_hit(limb: String, force: float, at: Vector3, source: String = "") -> void:
		hits.append({"limb":limb,"force":force,"at":at,"source":source})
		rules.hit_rider("%s:%d" % [limb,hits.size()],force,limb)

var checks: int = 0
var failures: int = 0
var arena: InjuryArena

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)

func frames(count: int) -> void:
	for frame in count: await physics_frame

func make_limb(part: String, x: float, tilt: float) -> RagdollLimb:
	var body := RagdollLimb.new()
	body.game = arena
	body.limb_name = part
	body.mass = 2
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.4,.4,.4)
	collision.shape = box
	body.add_child(collision)
	arena.add_child(body)
	body.position = Vector3(x,5,0)
	body.rotation.z = tilt
	return body

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	arena = InjuryArena.new()
	root.add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.name = "InjuryTestFloor"
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100,1,100)
	collision.shape = box
	floor_body.add_child(collision)
	arena.add_child(floor_body)
	floor_body.position.y = -.5
	var head := make_limb("head",-6,0)
	var shin := make_limb("shin_l",0,.7)
	var board := make_limb("board",6,.7)
	await frames(300)
	check(arena.rules.limb_damage.head > 0,"actual flat head drop records floor impact severity")
	check(arena.rules.limb_damage.shin_l > 0,"actual rotated shin drop records floor impact severity")
	check(arena.rules.rider_damage > 0,"physical floor collisions produce an injury settlement")
	for hit in arena.hits:
		check(hit.limb != "board","actual skateboard floor impacts never report injury")
		check(is_finite(hit.force) and hit.force >= 3,"reported physical impact is finite and substantial")
		check(hit.source == "InjuryTestFloor","impact source identifies the actual floor collider")
	var settled_hits: int = arena.hits.size()
	var settled_claim: int = arena.rules.rider_damage
	await frames(300)
	check(arena.hits.size() == settled_hits and arena.rules.rider_damage == settled_claim,"resting floor contacts cannot generate additional injury or payout")
	head.queue_free()
	shin.queue_free()
	board.queue_free()
	await frames(2)
	var widths: Array[float] = []
	var spins: Array[float] = []
	var maximum_separation: float = 0.0
	for pose_id in range(3):
		var group := Node3D.new()
		arena.add_child(group)
		var rider := Skater.new()
		rider.game = arena
		group.add_child(rider)
		rider.position = Vector3(0,3,0)
		rider.set_pose(pose_id)
		widths.append(rider.visuals.fore_r.position.x-rider.visuals.fore_l.position.x)
		rider.bail(Vector3(0,-2,8),2.3)
		spins.append(rider.torso.angular_velocity.x)
		check(rider.limbs.size() == 12 and rider.joints.size() == 10,"pose has eleven connected parts and loose board")
		rider.set_limb_damage("shin_l",75)
		check(rider.damage_patches.shin_l.visible and not rider.damage_patches.shin_r.visible,"injury marker is local to its body region")
		check(rider.damage_materials.shin_l.albedo_color.a > .4,"substantial injury retains a visible bruise overlay")
		rider.apply_damage_states({"head":40.0})
		check(not rider.damage_patches.shin_l.visible and rider.damage_patches.head.visible,"older replay snapshot replaces rather than accumulates injury appearance")
		rider.apply_damage_states({})
		check(not rider.damage_patches.head.visible and rider.damage_materials.head.albedo_color.a == 0,"healthy replay snapshot restores uninjured appearance")
		var board_velocity: Vector3 = rider.body_parts.board.linear_velocity
		rider.launch_impulse(Vector3(1,0,1))
		check(rider.body_parts.board.linear_velocity == board_velocity,"aimed rider launch leaves the loose skateboard momentum unchanged")
		var finite: bool = true
		var separation: float = 0.0
		for frame in range(300):
			await physics_frame
			for limb in rider.limbs:
				finite = finite and limb.global_position.is_finite() and limb.linear_velocity.is_finite() and limb.angular_velocity.is_finite()
			for joint in rider.joints:
				var body_a: Node3D = joint.get_node(joint.node_a)
				var body_b: Node3D = joint.get_node(joint.node_b)
				separation = maxf(separation,body_a.global_position.distance_to(body_b.global_position))
		check(finite,"all pose %d physical parts retain finite motion through landing" % pose_id)
		check(separation < 2.0,"connected joint bodies remain less than two meters apart for pose %d: %.3f" % [pose_id,separation])
		maximum_separation = maxf(maximum_separation,separation)
		group.queue_free()
		await frames(2)
	check(widths[1] > widths[0]+.5 and widths[1] > widths[2]+.5,"starfish has a substantially wider physical launch silhouette")
	check(spins[0] > spins[1] and spins[1] > spins[2],"three poses impart different initial angular momentum")
	arena.queue_free()
	await frames(2)
	print("INJURIES: ",checks," checks, ",failures," failures; max joint separation ",maximum_separation)
	quit(1 if failures else 0)
