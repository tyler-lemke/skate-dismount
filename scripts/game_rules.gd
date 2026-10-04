class_name WreckRules
extends RefCounted

const TREATMENT_GOAL: int = 600000
const POSES: Array[Dictionary] = [
	{"name": "TUCK", "tip": "Compact tumble. Stay close to the stairs and strike the next bridge."},
	{"name": "STARFISH", "tip": "Spread out. Catch more stair edges and expose more limbs."},
	{"name": "TORPEDO", "tip": "Stretch forward. Reach premium targets with a narrow landing."}
]
const LIMB_WEIGHTS: Dictionary = {
	"head": 1.4, "torso": 1.2, "pelvis": 1.1,
	"arm_l": 1.0, "arm_r": 1.0, "fore_l": 1.0, "fore_r": 1.0,
	"thigh_l": 1.05, "thigh_r": 1.05, "shin_l": 1.1, "shin_r": 1.1
}
const LIMB_TITLES: Dictionary = {
	"head": "Head", "torso": "Torso", "pelvis": "Pelvis",
	"arm_l": "Left upper arm", "arm_r": "Right upper arm",
	"fore_l": "Left forearm", "fore_r": "Right forearm",
	"thigh_l": "Left thigh", "thigh_r": "Right thigh",
	"shin_l": "Left shin", "shin_r": "Right shin"
}

const LEVELS: Array[Dictionary] = [
	{"name": "CIVIC CASCADE", "subtitle": "A very expensive public disturbance.", "district": "01 / OLD TOWN", "steps": 26, "rise": 0.36, "run": 1.10, "width": 11.0, "color": Color("84efbc"), "bronze": 40000, "silver": 160000, "gold": 340000, "objective": "Tip the domino lanes. Roll the drums into the taxi rank.", "tip": "Left: domino chain. Center: stair injuries. Right: premium taxi targets."},
	{"name": "NIGHT MARKET", "subtitle": "Fresh produce. Questionable landings.", "district": "02 / AFTER HOURS", "steps": 32, "rise": 0.39, "run": 1.12, "width": 12.0, "color": Color("fa78bd"), "bronze": 40000, "silver": 140000, "gold": 325000, "objective": "Send the market carts through the fireworks supply.", "tip": "Left: cart slalom. Center: cargo drop. Right: domino fuse run."},
	{"name": "PORT AUTHORITY", "subtitle": "One skater. An entire supply chain.", "district": "03 / TERMINAL 9", "steps": 38, "rise": 0.42, "run": 1.16, "width": 13.0, "color": Color("ffc75a"), "bronze": 60000, "silver": 240000, "gold": 550000, "objective": "Collapse the cargo towers. Ignite the terminal drum cache.", "tip": "Left: cargo towers. Center: drum avalanche. Right: heavy taxi."}
]
var score: int = 0
var property_damage: int = 0
var rider_damage: int = 0
var limb_damage: Dictionary = {}
var limb_payout: Dictionary = {}
var last_limb: String = ""
var destroyed: int = 0
var explosions: int = 0
var combo: int = 0
var best_combo: int = 0
var combo_left: float = 0.0
var hit_ids: Dictionary = {}
var prop_ids: Dictionary = {}
var peak_speed: float = 0.0
var flight_time: float = 0.0

func _init() -> void:
	reset()

func reset() -> void:
	score = 0
	property_damage = 0
	rider_damage = 0
	limb_damage.clear()
	limb_payout.clear()
	for limb in LIMB_WEIGHTS:
		limb_damage[limb] = 0.0
		limb_payout[limb] = 0
	last_limb = ""
	destroyed = 0
	explosions = 0
	combo = 0
	best_combo = 0
	combo_left = 0.0
	hit_ids.clear()
	prop_ids.clear()
	peak_speed = 0.0
	flight_time = 0.0

func tick(delta: float) -> void:
	combo_left = maxf(0.0, combo_left - delta)
	if combo_left == 0.0:
		combo = 0

func multiplier() -> int:
	return mini(8, 1 + combo / 4)

func hit_prop(id: int, value: int, explosive: bool = false) -> int:
	if prop_ids.has(id) or value <= 0:
		return 0
	prop_ids[id] = true
	combo += 1
	combo_left = 3.5
	best_combo = maxi(best_combo, combo)
	destroyed += 1
	if explosive:
		explosions += 1
	var points: int = value * multiplier()
	property_damage += points
	score += points
	return points

func hit_rider(id: String, force: float, limb: String = "") -> int:
	if limb.is_empty():
		var parts := id.split(":")
		if parts.size() >= 2:
			limb = parts[parts.size() - 2]
	if hit_ids.has(id) or not is_finite(force) or force < 3.0 or not LIMB_WEIGHTS.has(limb):
		return 0
	hit_ids[id] = true
	var previous: float = float(limb_damage[limb])
	var severity: float = minf(100.0, previous + force * 1.8)
	if severity <= previous:
		return 0
	limb_damage[limb] = severity
	last_limb = limb
	# Value cumulative severity, so subdividing an impact cannot exploit rounding.
	var total: int = int(round(severity * 70.0 * float(LIMB_WEIGHTS[limb])))
	var points: int = total - int(limb_payout[limb])
	limb_payout[limb] = total
	rider_damage += points
	score += points
	return points

static func limb_title(key: String) -> String:
	return str(LIMB_TITLES.get(key, "Unknown limb"))

static func injury_stage(severity: float) -> String:
	if not is_finite(severity) or severity <= 0.0: return "OK"
	if severity >= 60.0: return "FRACTURED"
	if severity >= 30.0: return "STRAINED"
	return "BRUISED"

func medal(level_index: int) -> String:
	var l: Dictionary = LEVELS[level_index]
	if score >= l.gold: return "GOLD"
	if score >= l.silver: return "SILVER"
	if score >= l.bronze: return "BRONZE"
	return "ROOKIE"

static func surface_y(level: Dictionary, z: float) -> float:
	var height: float = level.steps * level.rise
	if z < 0.0: return height
	if z >= level.steps * level.run: return 0.0
	return height - (floorf(z / level.run) + 1.0) * level.rise

static func money(value: int) -> String:
	var s: String = str(value)
	var out: String = ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0: out += ","
		out += s[i]
	return out
