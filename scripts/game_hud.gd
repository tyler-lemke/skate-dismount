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

const INK := Color("10212d")
const MINT := Color("84efbc")
const PAPER := Color("eff5ec")
const MUTED := Color("9cb0b7")
const ORANGE := Color("ff724a")
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
	label(menu,"AN ARCADE CRASH SPORT",Vector2(54,53),Vector2(390,30),15,MINT)
	label(menu,"STAIR",Vector2(48,85),Vector2(410,99),83)
	label(menu,"// WRECK",Vector2(48,173),Vector2(420,93),72,MINT)
	label(menu,"Build speed. Bail hard.\nMake the whole city fall with you.",Vector2(54,285),Vector2(370,65),20,MUTED)
	label(menu,"CHOOSE YOUR CASCADE",Vector2(54,372),Vector2(360,30),13,MUTED)
	for i in range(3):
		var l:Dictionary=WreckRules.LEVELS[i]
		var b:Button=button(menu,"0%d    %s" % [i+1,l.name],Vector2(54,412+i*70),Vector2(406,58),func(): route_requested.emit(i))
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		route_buttons.append(b)
	best_label=label(menu,"PERSONAL BEST  —",Vector2(54,638),Vector2(406,28),15,MUTED)
	button(menu,"DROP IN     →",Vector2(54,687),Vector2(406,60),func(): play_requested.emit(),true)
	button(menu,"HOW TO WRECK",Vector2(54,764),Vector2(245,49),func(): help_panel.visible=true)
	button(menu,"SOUND",Vector2(311,764),Vector2(149,49),func(): mute_requested.emit())
	label(menu,"PHYSICS. POOR DECISIONS. GOOD TIMES.",Vector2(54,840),Vector2(410,22),11,MUTED)
	panel(menu,Vector2(1044,32),Vector2(364,50),Color(.04,.10,.14,.85))
	label(menu,"●  CRASH LAB   /   ALL ROUTES OPEN",Vector2(1063,44),Vector2(335,28),14,MINT)
	panel(menu,Vector2(754,660),Vector2(654,218),Color(.04,.10,.14,.92),Color("38515b"))
	route_title=label(menu,"",Vector2(782,710),Vector2(604,50),36)
	route_info=label(menu,"",Vector2(784,680),Vector2(580,28),13,MINT)
	route_desc=label(menu,"",Vector2(784,763),Vector2(580,77),17,MUTED)
	label(menu,"RAGDOLL RIDER    ×    DOMINO DESTRUCTION",Vector2(784,846),Vector2(580,22),12,MINT)

func build_hud() -> void:
	hud=section()
	panel(hud,Vector2(26,26),Vector2(345,133),Color(.04,.10,.14,.92))
	label(hud,"TOTAL DAMAGE",Vector2(48,42),Vector2(230,28),13,MUTED)
	score_label=label(hud,"0",Vector2(45,65),Vector2(304,66),51,PAPER)
	combo_label=label(hud,"",Vector2(48,132),Vector2(320,24),16,MINT)
	panel(hud,Vector2(1058,26),Vector2(356,86),Color(.04,.10,.14,.92))
	phase_label=label(hud,"",Vector2(1080,40),Vector2(310,28),20,MINT)
	timer_label=label(hud,"",Vector2(1080,73),Vector2(310,25),14,MUTED)
	panel(hud,Vector2(26,722),Vector2(248,150),Color(.04,.10,.14,.92))
	speed_label=label(hud,"00",Vector2(44,735),Vector2(140,79),62)
	label(hud,"KM/H",Vector2(185,780),Vector2(70,30),14,MUTED)
	label(hud,"GROUND SPEED",Vector2(47,833),Vector2(210,24),12,MINT)
	panel(hud,Vector2(1040,734),Vector2(374,138),Color(.04,.10,.14,.92))
	boost_label=label(hud,"AFTERTOUCH  ● ● ●",Vector2(1060,749),Vector2(340,28),20,MINT)
	hint_label=label(hud,"",Vector2(1060,788),Vector2(334,75),16,MUTED)
	power_panel=panel(hud,Vector2(448,708),Vector2(544,164),Color(.04,.10,.14,.94),Color("42606a"))
	charge_label=label(power_panel,"HOLD SPACE TO BUILD POWER",Vector2(24,16),Vector2(496,30),20,MINT)
	charge_bar=ProgressBar.new(); power_panel.add_child(charge_bar); charge_bar.position=Vector2(24,59); charge_bar.size=Vector2(496,19); charge_bar.show_percentage=false; charge_bar.max_value=1.0
	var fill:=StyleBoxFlat.new(); fill.bg_color=MINT; fill.set_corner_radius_all(5)
	var bg:=StyleBoxFlat.new(); bg.bg_color=Color("2b4551"); bg.set_corner_radius_all(5)
	charge_bar.add_theme_stylebox_override("fill",fill); charge_bar.add_theme_stylebox_override("background",bg)
	label(power_panel,"Release to launch  •  A / D choose your starting lane\nW push  •  SPACE bail  •  SHIFT crashbreaker",Vector2(24,90),Vector2(505,54),16,MUTED)
	toast_label=label(hud,"",Vector2(425,104),Vector2(590,70),31,MINT); toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button(hud,"Ⅱ",Vector2(1352,130),Vector2(62,44),func(): get_parent().toggle_pause())
	replay_banner=label(hud,"REPLAY  /  YOUR LAST BAD IDEA",Vector2(438,39),Vector2(575,45),23,MINT); replay_banner.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; replay_banner.visible=false

func build_results() -> void:
	results=section()
	panel(results,Vector2(390,124),Vector2(660,680),Color(.035,.085,.12,.98),Color("506770"))
	label(results,"THE DAMAGE REPORT",Vector2(430,158),Vector2(580,30),14,MUTED)
	result_title=label(results,"",Vector2(426,198),Vector2(580,61),43,MINT)
	result_score=label(results,"",Vector2(423,272),Vector2(580,80),66)
	result_stats=label(results,"",Vector2(432,376),Vector2(570,145),20,MUTED)
	result_tip=label(results,"",Vector2(432,535),Vector2(576,53),16,MINT)
	button(results,"RUN IT BACK",Vector2(430,612),Vector2(277,58),func(): retry_requested.emit(),true)
	next_button=button(results,"NEXT CASCADE →",Vector2(727,612),Vector2(283,58),func(): next_requested.emit())
	button(results,"WATCH REPLAY",Vector2(430,690),Vector2(277,48),func(): replay_requested.emit())
	button(results,"ROUTE SELECT",Vector2(727,690),Vector2(283,48),func(): menu_requested.emit())
	label(results,"R  RETRY     •     V  REPLAY     •     ESC  ROUTES",Vector2(430,762),Vector2(580,24),12,MUTED)

func build_pause() -> void:
	pause_panel=section(); pause_panel.visible=false
	panel(pause_panel,Vector2.ZERO,Vector2(1440,900),Color(.015,.035,.05,.68))
	panel(pause_panel,Vector2(500,192),Vector2(440,518),Color(.035,.085,.12,.99),Color("38515b"))
	label(pause_panel,"TAKE A BREATHER",Vector2(534,226),Vector2(382,53),30,MINT)
	button(pause_panel,"KEEP WRECKING",Vector2(534,310),Vector2(372,55),func(): resume_requested.emit(),true)
	button(pause_panel,"RESTART RUN",Vector2(534,383),Vector2(372,53),func(): retry_requested.emit())
	button(pause_panel,"ROUTE SELECT",Vector2(534,452),Vector2(372,53),func(): menu_requested.emit())
	button(pause_panel,"TOGGLE SOUND",Vector2(534,521),Vector2(372,53),func(): mute_requested.emit())
	button(pause_panel,"QUIT GAME",Vector2(534,590),Vector2(372,53),func(): quit_requested.emit())

func build_help() -> void:
	help_panel=section(); help_panel.visible=false
	panel(help_panel,Vector2.ZERO,Vector2(1440,900),Color(.015,.035,.05,.78))
	panel(help_panel,Vector2(322,125),Vector2(796,658),Color(.035,.085,.12,.99),Color("38515b"))
	label(help_panel,"THE ART OF A BAD LANDING",Vector2(360,163),Vector2(722,54),33,MINT)
	label(help_panel,"01   BUILD YOUR LINE",Vector2(360,244),Vector2(700,30),21)
	label(help_panel,"A / D or ← / → steer. Hold SPACE to charge your launch, then release.\nHold W or ↑ to push. Speed keeps building as you ride the stairs.",Vector2(360,283),Vector2(714,65),19,MUTED)
	label(help_panel,"02   COMMIT TO THE CRASH",Vector2(360,369),Vector2(700,30),21)
	label(help_panel,"SPACE bails into a full ragdoll. Hitting an obstacle also throws you off.\nAim for dominoes, carts, cargo towers, and the orange explosive drums.",Vector2(360,408),Vector2(714,65),19,MUTED)
	label(help_panel,"03   KEEP THE CASCADE ALIVE",Vector2(360,494),Vector2(700,30),21)
	label(help_panel,"A / D applies aftertouch in the air. SHIFT spends one of three\ncrashbreaker boosts. Fresh wrecks build a multiplier up to ×8.\nC changes camera. TAB uses slow motion. R retries. ESC pauses.",Vector2(360,533),Vector2(714,100),19,MUTED)
	button(help_panel,"LET'S MAKE A MESS  →",Vector2(360,677),Vector2(716,61),func(): close_help(),true)

func set_route(index: int, best: int) -> void:
	var l:Dictionary=WreckRules.LEVELS[index]
	route_title.text=l.name
	route_info.text="%s     /     %d STEPS     /     %d WRECKABLES" % [l.district,l.steps,get_parent().world.props.size()]
	route_info.add_theme_color_override("font_color",l.color)
	route_desc.text=l.subtitle+"\n"+l.objective+"\nGOLD TARGET  "+WreckRules.money(l.gold)
	best_label.text="PERSONAL BEST   "+WreckRules.money(best)
	for i in range(3):
		route_buttons[i].add_theme_color_override("font_color",MINT if i==index else MUTED)

func show_menu() -> void:
	menu.visible=true; hud.visible=false; results.visible=false; pause_panel.visible=false

func show_game() -> void:
	menu.visible=false; hud.visible=true; results.visible=false; pause_panel.visible=false; help_panel.visible=false
	replay_banner.visible=false

func show_results(rules: WreckRules, index: int, is_best: bool) -> void:
	results.visible=true; power_panel.visible=false
	var medal:String=rules.medal(index)
	result_title.text=medal+" / "+["NICE TRY","NICE MESS","SERIOUS COLLATERAL","TOTAL CATASTROPHE"][["ROOKIE","BRONZE","SILVER","GOLD"].find(medal)]
	result_title.add_theme_font_size_override("font_size",31)
	result_score.text=WreckRules.money(rules.score)
	result_stats.text="Property damage        %s\nRider impacts              %s\nWrecked objects          %d     /     %d explosions\nLongest cascade         %d hits     /     %d km/h peak" % [WreckRules.money(rules.property_damage),WreckRules.money(rules.rider_damage),rules.destroyed,rules.explosions,rules.best_combo,int(rules.peak_speed*3.6)]
	result_tip.text=("NEW PERSONAL BEST!   " if is_best else "NEXT TIME:   ")+WreckRules.LEVELS[index].tip
	result_tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	next_button.text="NEXT CASCADE →" if index<2 else "BACK TO CIVIC →"

func update_game(rules: WreckRules, state: String, speed: float, charge: float, boosts: int, remaining: float, slow: bool) -> void:
	score_label.text=WreckRules.money(rules.score)
	combo_label.text="%d OBJECT CASCADE  /  ×%d" % [rules.combo,rules.multiplier()] if rules.combo>0 else "MAKE SOMETHING HAPPEN"
	phase_label.text={"READY":"SET YOUR LINE","RUN":"BUILD SPEED","CRASH":"CASCADE IN PROGRESS","RESULTS":"RUN COMPLETE","REPLAY":"ACTION REPLAY"}.get(state,state)
	timer_label.text="SLOW MOTION  /  TAB" if slow else ("%02d SEC  /  ESC PAUSE" % int(ceil(remaining)) if state=="CRASH" else "C CAMERA  /  ESC PAUSE")
	speed_label.text="%02d" % int(speed*3.6)
	boost_label.text="CRASHBREAKER  "+"● ".repeat(boosts)+"○ ".repeat(3-boosts)
	boost_label.add_theme_color_override("font_color",MINT if boosts>0 else MUTED)
	hint_label.text="SHIFT boost  /  A D aftertouch\nTAB slow motion  /  R restart" if state=="CRASH" else "W push  /  A D steer\nSPACE bail  /  C camera"
	power_panel.visible=state=="READY"
	charge_bar.value=charge
	charge_label.text="RELEASE TO LAUNCH   %d%% POWER" % int(charge*100) if charge>0 else "HOLD SPACE TO BUILD POWER"

func toast(message: String, color: Color = MINT) -> void:
	toast_label.text=message; toast_label.add_theme_color_override("font_color",color); toast_label.modulate=Color.WHITE; toast_timer=1.9

func flash() -> void:
	screen_flash.color.a=.22

func _process(delta: float) -> void:
	toast_timer=maxf(0,toast_timer-delta)
	toast_label.modulate.a=minf(1.0,toast_timer*3.0)
	screen_flash.color.a=move_toward(screen_flash.color.a,0,delta*.85)

func close_help() -> void:
	help_panel.visible=false
	help_closed.emit()
