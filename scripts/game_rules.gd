class_name WreckRules
extends RefCounted

const LEVELS: Array[Dictionary] = [
	{"name": "CIVIC CASCADE", "subtitle": "A very expensive public disturbance.", "district": "01 / OLD TOWN", "steps": 26, "rise": 0.36, "run": 1.10, "width": 11.0, "color": Color("84efbc"), "bronze": 8500, "silver": 23000, "gold": 44000, "objective": "Tip the domino lanes. Roll the drums into the taxi rank.", "tip": "The center domino lane feeds the first barrel cluster."},
	{"name": "NIGHT MARKET", "subtitle": "Fresh produce. Questionable landings.", "district": "02 / AFTER HOURS", "steps": 32, "rise": 0.39, "run": 1.12, "width": 12.0, "color": Color("fa78bd"), "bronze": 10000, "silver": 27000, "gold": 52000, "objective": "Send the market carts through the fireworks supply.", "tip": "The right cart line leads to an explosive cross-stair cascade."},
	{"name": "PORT AUTHORITY", "subtitle": "One skater. An entire supply chain.", "district": "03 / TERMINAL 9", "steps": 38, "rise": 0.42, "run": 1.16, "width": 13.0, "color": Color("ffc75a"), "bronze": 13000, "silver": 34000, "gold": 65000, "objective": "Collapse the cargo towers. Ignite the terminal drum cache.", "tip": "Aim left for cargo towers, center for the drum avalanche."}
]
var score: int = 0
var property_damage: int = 0
var rider_damage: int = 0
var destroyed: int = 0
var explosions: int = 0
var combo: int = 0
var best_combo: int = 0
var combo_left: float = 0.0
var hit_ids: Dictionary = {}
var prop_ids: Dictionary = {}
var peak_speed: float = 0.0
var flight_time: float = 0.0

func reset() -> void:
	score = 0
	property_damage = 0
	rider_damage = 0
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

func hit_rider(id: String, force: float) -> int:
	# Each limb may score again after a fresh collision; callers provide a time-bucket ID.
	if hit_ids.has(id) or force < 3.0:
		return 0
	hit_ids[id] = true
	var points: int = int(clampf(force * 28.0, 30.0, 1600.0))
	rider_damage += points
	score += points
	return points

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
