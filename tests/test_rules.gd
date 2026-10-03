extends SceneTree

var checks: int=0
var failures: int=0
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1; printerr("FAIL: ",message)

func _initialize() -> void:
	var rules:=WreckRules.new()
	check(rules.score==0 and rules.multiplier()==1,"clean score starts at x1")
	check(rules.hit_prop(1,600)==600,"first domino has its advertised value")
	check(rules.hit_prop(1,600)==0 and rules.destroyed==1,"duplicate prop cannot inflate score")
	check(rules.hit_prop(2,-200)==0,"invalid value cannot affect score")
	for i in range(2,5): rules.hit_prop(i,600)
	check(rules.combo==4 and rules.multiplier()==2,"four fresh objects unlock x2")
	check(rules.score==3000,"multiplier applies to the triggering wreck")
	rules.tick(3.49)
	check(rules.combo==4,"combo survives inside its real time window")
	rules.tick(.02)
	check(rules.combo==0 and rules.multiplier()==1,"combo expires after 3.5 seconds")
	check(rules.best_combo==4,"expiry preserves longest cascade")
	check(rules.hit_prop(5,1800,true)==1800 and rules.explosions==1,"explosions count and score once")
	rules.hit_prop(5,1800,true)
	check(rules.explosions==1,"same explosion cannot be counted twice")
	check(rules.hit_rider("head:1",2.99)==0,"incidental contact is below rider threshold")
	check(rules.hit_rider("head:1",10)==280,"rider points scale with measured impact")
	check(rules.hit_rider("head:1",20)==0,"same rider collision bucket cannot double score")
	check(rules.hit_rider("head:2",1000)==1600,"rider impact has a finite cap")
	check(rules.score==rules.property_damage+rules.rider_damage,"score ledger balances")
	rules.reset()
	check(rules.score==0 and rules.destroyed==0 and rules.explosions==0 and rules.hit_ids.is_empty() and rules.prop_ids.is_empty(),"retry resets all scoring ledgers")
	for i in range(40): rules.hit_prop(i,1)
	check(rules.multiplier()==8,"combo multiplier caps at x8")
	for i in range(3):
		var level:Dictionary=WreckRules.LEVELS[i]
		rules.score=level.bronze-1; check(rules.medal(i)=="ROOKIE","below bronze level "+str(i))
		rules.score=level.bronze; check(rules.medal(i)=="BRONZE","bronze boundary level "+str(i))
		rules.score=level.silver; check(rules.medal(i)=="SILVER","silver boundary level "+str(i))
		rules.score=level.gold; check(rules.medal(i)=="GOLD","gold boundary level "+str(i))
		check(is_equal_approx(WreckRules.surface_y(level,-1),level.steps*level.rise),"runup height level "+str(i))
		check(is_equal_approx(WreckRules.surface_y(level,0),(level.steps-1)*level.rise),"first riser height level "+str(i))
		check(is_zero_approx(WreckRules.surface_y(level,level.steps*level.run)),"bottom of stairs level "+str(i))
		var prior:float=WreckRules.surface_y(level,-1)
		for step in level.steps:
			var height:float=WreckRules.surface_y(level,(step+.5)*level.run)
			check(height<=prior and height>=-.001,"stair surface is monotonic level %d step %d" % [i,step]);prior=height
	check(WreckRules.money(0)=="0","zero score formatting")
	check(WreckRules.money(123)=="123","small score formatting")
	check(WreckRules.money(1234567)=="1,234,567","million score formatting")
	print("RULES: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
