class_name WreckHUD
extends CanvasLayer

signal play_requested
signal route_requested(index: int)
signal retry_requested
signal next_requested
signal menu_requested
signal resume_requested
signal replay_requested
signal mute_requested
signal quit_requested
signal help_closed
signal pose_requested(index: int)

const INK := Color("10212d")
const MINT := Color("84efbc")
const PAPER := Color("eff5ec")
const MUTED := Color("9cb0b7")
const ORANGE := Color("ff724a")
const GOLD := Color("f4cb7b")
const LIMB_NAMES: Array[String] = ["head", "torso", "pelvis", "arm_l", "arm_r", "fore_l", "fore_r", "thigh_l", "thigh_r", "shin_l", "shin_r"]
const LIMB_TITLES: Array[String] = ["HEAD", "TORSO", "PELVIS", "LEFT ARM", "RIGHT ARM", "LEFT FOREARM", "RIGHT FOREARM", "LEFT THIGH", "RIGHT THIGH", "LEFT SHIN", "RIGHT SHIN"]
var root: Control
var menu: Control
var hud: Control
var results: Control
var pause_panel: Control
var help_panel: Control
var score_label: Label
var combo_label: Label
var speed_label: Label
var phase_label: Label
var hint_label: Label
var charge_bar: ProgressBar
var charge_label: Label
var boost_label: Label
var timer_label: Label
var toast_label: Label
var toast_timer: float = 0
var route_title: Label
var route_desc: Label
var route_info: Label
var best_label: Label
var route_buttons: Array[Button] = []
var power_panel: Control
var result_title: Label
var result_score: Label
var result_stats: Label
var result_tip: Label
var next_button: Button
var replay_banner: Label
var screen_flash: ColorRect
var test_mode: bool = false
var menu_fund_label: Label
var menu_note_label: Label
var fund_bar: ProgressBar
var run_fund_label: Label
var claim_panel: Control
var claim_lines: Array[Label] = []
var claim_entries: Array[Dictionary] = []
var injury_panel: Control
var limb_labels: Dictionary = {}
var limb_bars: Dictionary = {}
var anatomy_parts: Dictionary = {}
var anatomy_stage: Dictionary = {}
var anatomy_styles: Dictionary = {}
var anatomy_region_label: Label
var anatomy_diagnosis_label: Label
var anatomy_payout_label: Label
var pose_panel: Control
var pose_buttons: Array[Button] = []
var pose_note: Label
var hat_note: Label
var aim_label: Label
var result_fund: Label
var result_note: Label
var new_money: int = 0
var result_target: int = 0
var result_reveal_time: float = 0.0
var result_reveal_active: bool = false
var displayed_pose_index: int = -1
var displayed_hat_index: int = -1
var current_state: String = "MENU"

func _ready() -> void:
	root=Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root)
	build_menu(); build_hud(); build_results(); build_pause(); build_help()
	screen_flash=ColorRect.new(); screen_flash.color=Color(1,.75,.4,0); screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); screen_flash.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(screen_flash)
	show_menu()

func section() -> Control:
	var c:=Control.new(); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); c.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(c); return c

func panel(parent: Control, at: Vector2, dimensions: Vector2, color: Color = INK, border: Color = Color.TRANSPARENT) -> Panel:
	var p:=Panel.new(); parent.add_child(p); p.position=at; p.size=dimensions; p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new(); style.bg_color=color; style.border_color=border; style.set_border_width_all(1); style.set_corner_radius_all(12); p.add_theme_stylebox_override("panel",style); return p

func label(parent: Control, text: String, at: Vector2, dimensions: Vector2, font_size: int = 20, color: Color = PAPER) -> Label:
	var l:=Label.new(); parent.add_child(l); l.position=at; l.size=dimensions; l.text=text; l.add_theme_font_size_override("font_size",font_size); l.add_theme_color_override("font_color",color); l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l

func button(parent: Control, text: String, at: Vector2, dimensions: Vector2, action: Callable, primary: bool = false) -> Button:
	var b:=Button.new(); parent.add_child(b); b.position=at; b.size=dimensions; b.text=text; b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND; b.add_theme_font_size_override("font_size",19)
	var normal:=StyleBoxFlat.new(); normal.bg_color=MINT if primary else Color("213845"); normal.set_corner_radius_all(8); normal.content_margin_left=18; normal.content_margin_right=18
	var hover: StyleBoxFlat=normal.duplicate(); hover.bg_color=Color("b1ffd5") if primary else Color("335162")
	var pressed: StyleBoxFlat=normal.duplicate(); pressed.bg_color=Color("6ed8ab") if primary else Color("426276")
	var focus: StyleBoxFlat=normal.duplicate(); focus.bg_color=Color.TRANSPARENT; focus.border_color=PAPER; focus.set_border_width_all(2)
	b.add_theme_stylebox_override("normal",normal); b.add_theme_stylebox_override("hover",hover); b.add_theme_stylebox_override("pressed",pressed); b.add_theme_stylebox_override("focus",focus)
	b.add_theme_color_override("font_color",INK if primary else PAPER); b.add_theme_color_override("font_hover_color",INK if primary else PAPER); b.add_theme_color_override("font_pressed_color",INK if primary else PAPER)
	b.pressed.connect(action); return b

func build_menu() -> void:
	menu=section()
	panel(menu,Vector2(22,22),Vector2(470,856),Color(.045,.10,.14,.97),Color("38515b"))
	label(menu,"FILE 001  /  THE TREATMENT FUND",Vector2(54,53),Vector2(400,30),15,MINT)
	label(menu,"STAIR",Vector2(48,85),Vector2(410,99),83)
	label(menu,"// WRECK",Vector2(48,173),Vector2(420,93),72,MINT)
	label(menu,"Mom needs cancer treatment.\nYour stunt policy is your last shot.",Vector2(54,285),Vector2(390,65),20,PAPER)
	label(menu,"CHOOSE A ROUTE TO FILE",Vector2(54,372),Vector2(360,30),13,MUTED)
	for i in range(3):
		var l:Dictionary=WreckRules.LEVELS[i]
		var b:Button=button(menu,"0%d    %s" % [i+1,l.name],Vector2(54,412+i*70),Vector2(406,58),func(): route_requested.emit(i))
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		route_buttons.append(b)
	best_label=label(menu,"BEST CLAIM  —",Vector2(54,638),Vector2(406,28),15,MUTED)
	button(menu,"FILE A CLAIM     →",Vector2(54,687),Vector2(406,60),func(): play_requested.emit(),true)
	button(menu,"HOW TO WRECK",Vector2(54,764),Vector2(245,49),func(): help_panel.visible=true)
	button(menu,"SOUND",Vector2(311,764),Vector2(149,49),func(): mute_requested.emit())
	label(menu,"MOM SAYS: COME HOME FOR DINNER.",Vector2(54,840),Vector2(410,22),11,MUTED)
	panel(menu,Vector2(1044,32),Vector2(364,50),Color(.04,.10,.14,.85))
	label(menu,"●  ALL ROUTES OPEN   /   LOCAL SAVE",Vector2(1063,44),Vector2(335,28),14,MINT)
	panel(menu,Vector2(754,128),Vector2(654,190),Color(.04,.10,.14,.92),Color("38515b"))
	label(menu,"MOM'S CANCER TREATMENT FUND",Vector2(782,151),Vector2(590,29),15,GOLD)
	menu_fund_label=label(menu,"",Vector2(780,183),Vector2(590,55),33,PAPER)
	fund_bar=ProgressBar.new(); menu.add_child(fund_bar); fund_bar.position=Vector2(782,238); fund_bar.size=Vector2(588,13); fund_bar.show_percentage=false; fund_bar.max_value=WreckRules.TREATMENT_GOAL
	var fund_fill:=StyleBoxFlat.new(); fund_fill.bg_color=MINT; fund_fill.set_corner_radius_all(5)
	var fund_bg:=StyleBoxFlat.new(); fund_bg.bg_color=Color("2b4551"); fund_bg.set_corner_radius_all(5)
	fund_bar.add_theme_stylebox_override("fill",fund_fill); fund_bar.add_theme_stylebox_override("background",fund_bg)
	menu_note_label=label(menu,"",Vector2(782,268),Vector2(590,37),16,MUTED)
	panel(menu,Vector2(754,660),Vector2(654,218),Color(.04,.10,.14,.92),Color("38515b"))
	route_title=label(menu,"",Vector2(782,710),Vector2(604,50),36)
	route_info=label(menu,"",Vector2(784,680),Vector2(580,28),13,MINT)
	route_desc=label(menu,"",Vector2(784,763),Vector2(580,77),17,MUTED)
	label(menu,"ONE CLAIM PER ROUTE  /  BETTER RUNS RAISE THE FUND",Vector2(784,846),Vector2(600,22),12,MINT)

func build_hud() -> void:
	hud=section()
	panel(hud,Vector2(26,26),Vector2(345,133),Color(.04,.10,.14,.92),Color("38515b"))
	label(hud,"INSURANCE PAYOUT",Vector2(48,42),Vector2(280,28),13,GOLD)
	score_label=label(hud,"$0",Vector2(45,67),Vector2(310,59),43,PAPER)
	combo_label=label(hud,"",Vector2(48,132),Vector2(320,24),16,MINT)
	panel(hud,Vector2(405,27),Vector2(602,68),Color(.04,.10,.14,.86))
	label(hud,"FOR MOM'S TREATMENT",Vector2(426,39),Vector2(250,20),12,GOLD)
	run_fund_label=label(hud,"",Vector2(426,61),Vector2(556,28),20,PAPER)
	panel(hud,Vector2(1058,26),Vector2(356,86),Color(.04,.10,.14,.92))
	phase_label=label(hud,"",Vector2(1080,40),Vector2(310,28),20,MINT)
	timer_label=label(hud,"",Vector2(1080,73),Vector2(310,25),14,MUTED)
	panel(hud,Vector2(1058,185),Vector2(356,74),Color(.04,.10,.14,.86),Color("38515b"))
	aim_label=label(hud,"",Vector2(1077,199),Vector2(320,48),16,GOLD)
	panel(hud,Vector2(26,722),Vector2(248,150),Color(.04,.10,.14,.92))
	speed_label=label(hud,"00",Vector2(44,735),Vector2(140,79),62)
	label(hud,"KM/H",Vector2(185,780),Vector2(70,30),14,MUTED)
	label(hud,"GROUND SPEED",Vector2(47,833),Vector2(210,24),12,MINT)
	panel(hud,Vector2(1040,734),Vector2(374,138),Color(.04,.10,.14,.92))
	boost_label=label(hud,"CRASHBREAKER  ● ● ●",Vector2(1060,749),Vector2(340,28),20,MINT)
	hint_label=label(hud,"",Vector2(1060,788),Vector2(334,75),16,MUTED)
	power_panel=panel(hud,Vector2(448,708),Vector2(544,164),Color(.04,.10,.14,.94),Color("42606a"))
	charge_label=label(power_panel,"HOLD SPACE TO BUILD POWER",Vector2(24,16),Vector2(496,30),20,MINT)
	charge_bar=ProgressBar.new(); power_panel.add_child(charge_bar); charge_bar.position=Vector2(24,59); charge_bar.size=Vector2(496,19); charge_bar.show_percentage=false; charge_bar.max_value=1.0
	var fill:=StyleBoxFlat.new(); fill.bg_color=MINT; fill.set_corner_radius_all(5)
	var bg:=StyleBoxFlat.new(); bg.bg_color=Color("2b4551"); bg.set_corner_radius_all(5)
	charge_bar.add_theme_stylebox_override("fill",fill); charge_bar.add_theme_stylebox_override("background",bg)
	label(power_panel,"Release to launch  •  A / D choose your starting lane\nW push  •  SPACE bail  •  SHIFT crashbreaker",Vector2(24,90),Vector2(505,54),16,MUTED)
	toast_label=label(hud,"",Vector2(425,107),Vector2(590,54),27,MINT); toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button(hud,"II",Vector2(1352,130),Vector2(62,44),func(): get_parent().toggle_pause())
	replay_banner=label(hud,"REPLAY  /  THE CLAIM IN MOTION",Vector2(438,117),Vector2(575,45),22,MINT); replay_banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; replay_banner.visible=false
	build_injury_file()
	build_claim_feed()
	build_pose_selector()

func build_injury_file() -> void:
	injury_panel=panel(hud,Vector2(26,177),Vector2(345,523),Color(.04,.10,.14,.9),Color("38515b"))
	label(injury_panel,"INJURY CLAIM FILE",Vector2(21,15),Vector2(300,27),15,GOLD)
	label(injury_panel,"IMPACT-VERIFIED  /  11 REGIONS",Vector2(21,43),Vector2(300,22),11,MUTED)
	for stage in ["OK", "BRUISED", "STRAINED", "FRACTURED"]:
		var shape_style:=StyleBoxFlat.new()
		shape_style.bg_color={"OK":Color("43606b"),"BRUISED":GOLD,"STRAINED":Color("ed9b6c"),"FRACTURED":ORANGE}[stage]
		shape_style.border_color=PAPER if stage!="OK" else Color("819da4")
		shape_style.set_border_width_all(1)
		shape_style.set_corner_radius_all(6)
		anatomy_styles[stage]=shape_style
	var shapes:Dictionary={
		"head":Rect2(85,75,26,24),
		"torso":Rect2(79,103,38,39),
		"pelvis":Rect2(83,145,30,20),
		"arm_l":Rect2(64,105,13,35),
		"arm_r":Rect2(119,105,13,35),
		"fore_l":Rect2(53,143,11,32),
		"fore_r":Rect2(132,143,11,32),
		"thigh_l":Rect2(80,168,14,25),
		"thigh_r":Rect2(102,168,14,25),
		"shin_l":Rect2(78,196,14,29),
		"shin_r":Rect2(104,196,14,29)
	}
	for key in LIMB_NAMES:
		var shape_rect:Rect2=shapes[key]
		var piece:Panel=panel(injury_panel,shape_rect.position,shape_rect.size)
		piece.add_theme_stylebox_override("panel",anatomy_styles["OK"])
		anatomy_parts[key]=piece
		anatomy_stage[key]="OK"
	label(injury_panel,"L",Vector2(37,107),Vector2(16,17),11,MUTED)
	label(injury_panel,"R",Vector2(147,107),Vector2(16,17),11,MUTED)
	label(injury_panel,"REGION IN FOCUS",Vector2(174,80),Vector2(150,20),11,GOLD)
	anatomy_region_label=label(injury_panel,"NO IMPACT YET",Vector2(174,107),Vector2(150,29),14,PAPER)
	anatomy_diagnosis_label=label(injury_panel,"ALL CLEAR",Vector2(174,142),Vector2(150,24),13,MUTED)
	anatomy_payout_label=label(injury_panel,"CLAIM  $0",Vector2(174,177),Vector2(150,25),13,GOLD)
	panel(injury_panel,Vector2(20,230),Vector2(303,2),Color("38515b"))
	for i in LIMB_NAMES.size():
		var key: String=LIMB_NAMES[i]
		var y: float=238+i*22
		var entry:Label=label(injury_panel,LIMB_TITLES[i]+"  OK",Vector2(21,y),Vector2(225,21),13,MUTED)
		limb_labels[key]=entry
		var bar:=ProgressBar.new(); injury_panel.add_child(bar); bar.add_theme_font_size_override("font_size",1); bar.position=Vector2(254,y+6); bar.size=Vector2(67,9); bar.show_percentage=false; bar.max_value=100.0
		var bg:=StyleBoxFlat.new(); bg.bg_color=Color("29404a"); bg.set_corner_radius_all(4)
		var fill:=StyleBoxFlat.new(); fill.bg_color=ORANGE; fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background",bg); bar.add_theme_stylebox_override("fill",fill)
		limb_bars[key]=bar
	label(injury_panel,"Only verified impacts mark this file.",Vector2(21,495),Vector2(310,20),12,MUTED)
	injury_panel.visible=false

func build_claim_feed() -> void:
	claim_panel=panel(hud,Vector2(405,171),Vector2(470,119),Color(.04,.10,.14,.88),Color("38515b"))
	label(claim_panel,"CLAIM RECEIPTS",Vector2(18,10),Vector2(300,23),12,GOLD)
	for i in 3:
		claim_lines.append(label(claim_panel,"",Vector2(18,34+i*25),Vector2(440,24),16,PAPER))
	claim_panel.visible=false

func build_pose_selector() -> void:
	pose_panel=panel(hud,Vector2(26,177),Vector2(345,420),Color(.04,.10,.14,.92),Color("42606a"))
	label(pose_panel,"CHOOSE A BAIL POSE",Vector2(22,17),Vector2(301,28),16,GOLD)
	for i in WreckRules.POSES.size():
		var pose:Dictionary=WreckRules.POSES[i]
		var b:Button=button(pose_panel,str(pose.get("name","POSE "+str(i+1))).to_upper(),Vector2(22,55+i*57),Vector2(301,49),func(): pose_requested.emit(i))
		b.add_theme_font_size_override("font_size",15)
		pose_buttons.append(b)
	pose_note=label(pose_panel,"",Vector2(22,241),Vector2(301,79),15,MUTED)
	pose_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(pose_panel,"1 / 2 / 3 SELECT   /   SPACE LAUNCH",Vector2(22,325),Vector2(301,22),11,MUTED)
	hat_note=label(pose_panel,"",Vector2(22,367),Vector2(301,25),12,GOLD)
	pose_panel.visible=false
	

func build_results() -> void:
	results=section()
	panel(results,Vector2(365,63),Vector2(710,783),Color(.035,.085,.12,.98),Color("506770"))
	label(results,"CLAIM FILED  /  RUN REPORT",Vector2(407,96),Vector2(625,27),14,GOLD)
	result_title=label(results,"",Vector2(405,132),Vector2(625,43),31,MINT)
	label(results,"TOTAL INSURANCE PAYOUT",Vector2(407,204),Vector2(625,25),14,MUTED)
	result_score=label(results,"",Vector2(402,235),Vector2(630,73),59,PAPER)
	panel(results,Vector2(402,327),Vector2(636,3),Color("506770"))
	result_stats=label(results,"",Vector2(408,351),Vector2(620,132),19,MUTED)
	panel(results,Vector2(402,495),Vector2(636,103),Color("172d36"),Color("45616a"))
	result_fund=label(results,"",Vector2(424,510),Vector2(592,32),20,GOLD)
	result_note=label(results,"",Vector2(424,550),Vector2(592,34),15,PAPER)
	result_tip=label(results,"",Vector2(408,612),Vector2(620,38),15,MINT)
	result_tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(results,"RUN IT BACK",Vector2(407,665),Vector2(300,55),func(): retry_requested.emit(),true)
	next_button=button(results,"NEXT ROUTE →",Vector2(726,665),Vector2(308,55),func(): next_requested.emit())
	button(results,"WATCH REPLAY",Vector2(407,738),Vector2(300,48),func(): replay_requested.emit())
	button(results,"ROUTE SELECT",Vector2(726,738),Vector2(308,48),func(): menu_requested.emit())
	label(results,"R  RETRY    •    V  REPLAY    •    ESC  ROUTES",Vector2(408,806),Vector2(620,20),11,MUTED)

func build_pause() -> void:
	pause_panel=section(); pause_panel.visible=false
	var backdrop:Panel=panel(pause_panel,Vector2.ZERO,Vector2(1440,900),Color(.015,.035,.05,.68))
	backdrop.mouse_filter=Control.MOUSE_FILTER_STOP
	panel(pause_panel,Vector2(500,192),Vector2(440,518),Color(.035,.085,.12,.99),Color("38515b"))
	label(pause_panel,"TAKE A BREATHER",Vector2(534,226),Vector2(382,53),30,MINT)
	button(pause_panel,"KEEP WRECKING",Vector2(534,310),Vector2(372,55),func(): resume_requested.emit(),true)
	button(pause_panel,"RESTART RUN",Vector2(534,383),Vector2(372,53),func(): retry_requested.emit())
	button(pause_panel,"ROUTE SELECT",Vector2(534,452),Vector2(372,53),func(): menu_requested.emit())
	button(pause_panel,"TOGGLE SOUND",Vector2(534,521),Vector2(372,53),func(): mute_requested.emit())
	button(pause_panel,"QUIT GAME",Vector2(534,590),Vector2(372,53),func(): quit_requested.emit())

func build_help() -> void:
	help_panel=section(); help_panel.visible=false
	var backdrop:Panel=panel(help_panel,Vector2.ZERO,Vector2(1440,900),Color(.015,.035,.05,.78))
	backdrop.mouse_filter=Control.MOUSE_FILTER_STOP
	panel(help_panel,Vector2(322,125),Vector2(796,658),Color(.035,.085,.12,.99),Color("38515b"))
	label(help_panel,"HOW TO FILE A BIG CLAIM",Vector2(360,163),Vector2(722,54),33,MINT)
	label(help_panel,"01   BUILD YOUR LINE",Vector2(360,244),Vector2(700,30),21)
	label(help_panel,"1 / 2 / 3 choose pose; F cycles hats. A / D steer.\nHold SPACE to charge, release to launch; W pushes. C cycles cameras.",Vector2(360,283),Vector2(714,65),19,MUTED)
	label(help_panel,"02   COMMIT TO THE CRASH",Vector2(360,369),Vector2(700,30),21)
	label(help_panel,"Choose a pose before launch. SPACE bails into a ragdoll.\nAim for dominoes, carts, cargo towers, and orange drums.",Vector2(360,408),Vector2(714,65),19,MUTED)
	label(help_panel,"03   KEEP THE CASCADE ALIVE",Vector2(360,494),Vector2(700,30),21)
	label(help_panel,"A / D aftertouch; SHIFT spends an aimed crashbreaker.\nTAB holds slow motion. ENTER files the current claim.\nR retries; ESC pauses. Actual hits pay the fictional stunt policy.",Vector2(360,533),Vector2(714,100),19,MUTED)
	button(help_panel,"LET'S FILE IT  →",Vector2(360,677),Vector2(716,61),func(): close_help(),true)

func set_route(index: int, best: int) -> void:
	var l:Dictionary=WreckRules.LEVELS[index]
	route_title.text=l.name
	route_info.text="%s     /     %d STEPS     /     %d WRECKABLES" % [l.district,l.steps,get_parent().world.props.size()]
	route_info.add_theme_color_override("font_color",l.color)
	route_desc.text=l.subtitle+"\n"+l.objective+"\nGOLD CLAIM  $"+WreckRules.money(l.gold)
	best_label.text="BEST CLAIM   $"+WreckRules.money(best)
	for i in range(3):
		route_buttons[i].add_theme_color_override("font_color",MINT if i==index else MUTED)
	update_campaign()

func show_menu() -> void:
	menu.visible=true; hud.visible=false; results.visible=false; pause_panel.visible=false
	current_state="MENU"
	update_campaign()

func show_game() -> void:
	menu.visible=false; hud.visible=true; results.visible=false; pause_panel.visible=false; help_panel.visible=false
	current_state="READY"
	replay_banner.visible=false
	claim_entries.clear()
	claim_panel.visible=false
	injury_panel.visible=false
	update_campaign()

func update_campaign(money_added: int = 0) -> void:
	new_money=maxi(0,money_added)
	var fund:int=get_parent().fund_total()
	var goal:int=WreckRules.TREATMENT_GOAL
	menu_fund_label.text="$%s  /  $%s" % [WreckRules.money(fund),WreckRules.money(goal)]
	fund_bar.value=mini(fund,goal)
	var notes: Array[String]=["Mom: I used to carry you up these stairs.","Mom: Tea's waiting. Tell me about your day.","Mom: I'll still embarrass you at graduation."]
	menu_note_label.text=notes[clampi(get_parent().level_index,0,2)] if fund<goal else "Mom: Treatment starts tomorrow. Come home."
	run_fund_label.text="SECURED  $%s  /  $%s" % [WreckRules.money(fund),WreckRules.money(goal)]

func show_results(rules: WreckRules, index: int, is_best: bool) -> void:
	results.visible=true; power_panel.visible=false; pose_panel.visible=false; injury_panel.visible=true; claim_panel.visible=false
	current_state="RESULTS"
	update_injury_file(rules)
	var medal:String=rules.medal(index)
	var fund:int=get_parent().fund_total()
	var newly_funded:bool=new_money>0 and fund>=WreckRules.TREATMENT_GOAL and fund-new_money<WreckRules.TREATMENT_GOAL
	result_title.text="TREATMENT FUNDED" if newly_funded else "%s CLAIM  /  %s" % [medal,"NEW BEST" if is_best else "FILED"]
	result_target=rules.score
	result_reveal_time=0.0
	result_reveal_active=true
	result_score.text="$0"
	result_stats.text="PROPERTY CLAIM                     $%s\nINJURY CLAIM                            $%s\n%d objects wrecked    /    %d explosions\n%d-hit cascade    /    %d km/h peak" % [WreckRules.money(rules.property_damage),WreckRules.money(rules.rider_damage),rules.destroyed,rules.explosions,rules.best_combo,int(rules.peak_speed*3.6)]
	result_fund.text="TREATMENT FUND     $%s / $%s" % [WreckRules.money(fund),WreckRules.money(WreckRules.TREATMENT_GOAL)]
	if fund>=WreckRules.TREATMENT_GOAL:
		result_note.text="Mom: Treatment starts tomorrow. Come home."
	elif new_money>0:
		result_note.text="+$%s secured. Mom saved you a seat at dinner." % WreckRules.money(new_money)
	else:
		result_note.text="Claim filed. Mom saved you a seat at dinner."
	result_tip.text="NEXT LINE  /  "+WreckRules.LEVELS[index].tip
	next_button.text="NEXT ROUTE →" if index<2 else "CIVIC ROUTE →"

func update_game(rules: WreckRules, state: String, speed: float, charge: float, boosts: int, remaining: float, slow: bool) -> void:
	current_state=state
	score_label.text="$"+WreckRules.money(rules.score)
	if state=="RESULTS": combo_label.text="CLAIM SETTLED"
	elif state=="REPLAY": combo_label.text="RECORDED CASCADE  /  %d HITS" % rules.best_combo
	else: combo_label.text="%d OBJECT CASCADE  /  ×%d" % [rules.combo,rules.multiplier()] if rules.combo>0 else "MAKE SOMETHING HAPPEN"
	phase_label.text={"READY":"CHOOSE YOUR LINE","RUN":"BUILD THE CLAIM","CRASH":"CLAIM IN MOTION","RESULTS":"CLAIM FILED","REPLAY":"ACTION REPLAY"}.get(state,state)
	var rate:float=get_parent().time_rate
	if state=="RESULTS": timer_label.text="C CAMERA / ESC ROUTES"
	elif state=="REPLAY": timer_label.text="REPLAY / ESC PAUSE"
	elif state=="CRASH": timer_label.text=("MANUAL SLOW" if slow else ("IMPACT PULSE" if rate<.3 else "AUTO SLOW"))+"  /  %02d SEC" % int(ceil(remaining))
	else: timer_label.text="C CAMERA  /  ESC PAUSE"
	speed_label.text="%02d" % int(speed*3.6)
	if state=="RESULTS":
		boost_label.text="CLAIM LOCKED"
		hint_label.text="R retry / V replay\nESC route select"
	elif state=="REPLAY":
		boost_label.text="RECORDED CRASH"
		hint_label.text="R retry / C camera\nESC pause"
	else:
		boost_label.text="CRASHBREAKER  "+"● ".repeat(boosts)+"○ ".repeat(3-boosts)
		hint_label.text="A D aim / S uphill / SHIFT fire\nENTER file / TAB slow / R retry" if state=="CRASH" else "W push  /  A D steer\nSPACE bail  /  C camera"
	boost_label.add_theme_color_override("font_color",MUTED if state in ["RESULTS","REPLAY"] or boosts<=0 else MINT)
	power_panel.visible=state=="READY"
	pose_panel.visible=state=="READY"
	injury_panel.visible=state in ["CRASH","REPLAY","RESULTS"]
	claim_panel.visible=state=="CRASH" and not claim_entries.is_empty()
	charge_bar.value=charge
	charge_label.text="RELEASE TO LAUNCH   %d%% POWER" % int(charge*100) if charge>0 else "HOLD SPACE TO BUILD POWER"
	if state=="READY": update_pose_selector()
	if state in ["CRASH","REPLAY","RESULTS"]:
		update_injury_file(rules,state=="REPLAY")
	if state=="CRASH":
		var aim:Vector3=get_parent().boost_direction()
		var direction:String="FORWARD"
		if aim.x<-.35: direction="LEFT"
		elif aim.x>.35: direction="RIGHT"
		elif aim.z<0: direction="UPHILL"
		else: direction="DOWNSTAIRS"
		var cooldown:float=get_parent().boost_cooldown
		aim_label.text="SHIFT  /  %s\n%s" % [direction,"READY" if cooldown<=0 and boosts>0 else ("RECHARGING" if boosts>0 else "NO BOOSTS LEFT")]
	elif state=="RESULTS":
		aim_label.text="CLAIM SETTLED\nV REPLAY / R RETRY"
	elif state=="REPLAY":
		aim_label.text="REPLAYING CLAIM\nNO NEW PAYOUT"
	else:
		aim_label.text="SHIFT  /  AIMED CRASHBREAKER\nTHREE BOOSTS PER RUN"
	var secured:int=get_parent().fund_total()
	var preview:int=maxi(0,rules.score-get_parent().best_scores[get_parent().level_index]) if state in ["RUN","CRASH"] else 0
	if state=="REPLAY": run_fund_label.text="RECORDED PAYOUT $%s  /  NO NEW CLAIM" % WreckRules.money(rules.score)
	elif state=="RESULTS": run_fund_label.text="CLAIM FILED $%s  /  FUND $%s" % [WreckRules.money(rules.score),WreckRules.money(secured)]
	else: run_fund_label.text="SECURED $%s  /  THIS CLAIM +$%s" % [WreckRules.money(secured),WreckRules.money(preview)]

func update_pose_selector() -> void:
	var index:int=clampi(get_parent().pose_index,0,WreckRules.POSES.size()-1)
	var hat_index:int=clampi(get_parent().selected_hat,0,2)
	if index==displayed_pose_index and hat_index==displayed_hat_index: return
	displayed_pose_index=index
	displayed_hat_index=hat_index
	var pose:Dictionary=WreckRules.POSES[index]
	pose_note.text=str(pose.get("tip","Choose how to leave the board."))
	hat_note.text="F  CHANGE HAT  /  "+["CLOCKWORK TOP", "PAPER CRANE", "TRAFFIC CONE"][hat_index]
	for i in pose_buttons.size():
		pose_buttons[i].add_theme_color_override("font_color",INK if i==index else PAPER)
		pose_buttons[i].add_theme_stylebox_override("normal",selected_pose_style() if i==index else unselected_pose_style())

func selected_pose_style() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new(); style.bg_color=MINT; style.set_corner_radius_all(8); style.content_margin_left=10; style.content_margin_right=10
	return style

func unselected_pose_style() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new(); style.bg_color=Color("213845"); style.set_corner_radius_all(8); style.content_margin_left=10; style.content_margin_right=10
	return style

func update_injury_file(rules: WreckRules, replay_snapshot: bool = false) -> void:
	var severities:Dictionary=get_parent().skater.damage_states if replay_snapshot else rules.limb_damage
	var focus:String=""
	var maximum:float=0.0
	for key in LIMB_NAMES:
		var severity:float=clampf(float(severities.get(key,0.0)),0.0,100.0)
		var state:String=WreckRules.injury_stage(severity)
		var i:int=LIMB_NAMES.find(key)
		var entry:Label=limb_labels[key]
		entry.text="%s  %s" % [LIMB_TITLES[i],state]
		entry.add_theme_color_override("font_color",ORANGE if severity>=60 else (GOLD if severity>0 else MUTED))
		limb_bars[key].value=severity
		if anatomy_stage[key]!=state:
			anatomy_parts[key].add_theme_stylebox_override("panel",anatomy_styles[state])
			anatomy_stage[key]=state
		if severity>maximum:
			maximum=severity
			focus=key
	if focus.is_empty():
		anatomy_region_label.text="NO IMPACT YET"
		anatomy_diagnosis_label.text="ALL CLEAR"
		anatomy_payout_label.text="CLAIM  $0"
	else:
		anatomy_region_label.text=LIMB_TITLES[LIMB_NAMES.find(focus)]
		anatomy_diagnosis_label.text=WreckRules.injury_stage(maximum)
		anatomy_payout_label.text="REPLAY SNAPSHOT" if replay_snapshot else "CLAIM  $"+WreckRules.money(int(rules.limb_payout.get(focus,0)))

func claim_event(name: String, amount: int, injury: bool = false) -> void:
	if amount<=0: return
	var cleaned:String=name.replace("_"," ").to_upper()
	if not injury:
		for i in claim_entries.size():
			var older:Dictionary=claim_entries[i]
			if not bool(older.injury) and str(older.name)==cleaned and float(older.left)>2.7:
				amount+=int(older.amount)
				claim_entries.remove_at(i)
				break
	claim_entries.push_front({"name":cleaned,"amount":amount,"injury":injury,"left":3.0})
	while claim_entries.size()>32: claim_entries.pop_back()
	refresh_claim_feed()

func refresh_claim_feed() -> void:
	claim_panel.visible=not claim_entries.is_empty() and hud.visible and not results.visible and current_state in ["RUN","CRASH"]
	var shown:Array[Dictionary]=[]
	var priority:int=-1
	for i in claim_entries.size():
		if bool(claim_entries[i].injury):
			priority=i
			shown.append(claim_entries[i])
			break
	for i in claim_entries.size():
		if i==priority: continue
		shown.append(claim_entries[i])
		if shown.size()==3: break
	for i in claim_lines.size():
		if i<shown.size():
			var event:Dictionary=shown[i]
			claim_lines[i].text="%s  /  %s    +$%s" % ["INJURY" if bool(event.injury) else "PROPERTY",event.name,WreckRules.money(int(event.amount))]
			claim_lines[i].add_theme_color_override("font_color",GOLD if bool(event.injury) else PAPER)
		else:
			claim_lines[i].text=""

func toast(message: String, color: Color = MINT) -> void:
	if replay_banner.visible:
		toast_label.text=""
		toast_timer=0.0
		return
	toast_label.text=message; toast_label.add_theme_color_override("font_color",color); toast_label.modulate=Color.WHITE; toast_timer=1.9

func flash() -> void:
	screen_flash.color.a=.22

func _process(delta: float) -> void:
	var real_delta:float=delta/maxf(Engine.time_scale,0.05)
	if result_reveal_active:
		result_reveal_time=minf(1.0,result_reveal_time+real_delta/.95)
		var fraction:float=1.0-pow(1.0-result_reveal_time,3.0)
		result_score.text="$"+WreckRules.money(int(round(result_target*fraction)))
		if result_reveal_time>=1.0: result_reveal_active=false
	toast_timer=maxf(0,toast_timer-real_delta)
	toast_label.modulate.a=minf(1.0,toast_timer*3.0)
	screen_flash.color.a=move_toward(screen_flash.color.a,0,real_delta*.85)
	for i in range(claim_entries.size()-1,-1,-1):
		claim_entries[i].left-=real_delta
		if claim_entries[i].left<=0: claim_entries.remove_at(i)
	if is_instance_valid(claim_panel): refresh_claim_feed()

func close_help() -> void:
	help_panel.visible=false
	help_closed.emit()
