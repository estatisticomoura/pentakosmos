extends Node
## Teste de fumaca da interface: abre o menu, joga uma partida so com IAs,
## depois joga turnos como humano. Com "shots" nos argumentos, salva capturas.
## Uso: godot --path . res://tests/ui_smoke.tscn -- [shots] [jogadores] [preset]

var main: Control
var shots := false
var out_dir := "res://tests/capturas"
var _shot_i := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args.has("shots")
	var n := 4
	var preset := "house"
	for a in args:
		if a.is_valid_int():
			n = int(a)
		elif a in ["house", "classico"]:
			preset = a
	var old_layout = Store.get_value("geral", "interface", "auto")
	Store.set_value("geral", "interface", "toque" if args.has("toque") else "pc")
	tree_exiting.connect(func(): Store.set_value("geral", "interface", old_layout))
	if shots:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(20)
	await _shot("menu")
	var rules: RuleSet = RuleSet.house_full() if preset == "house" else RuleSet.classic()
	# 1) partida so com IAs, acelerada
	Engine.time_scale = 1.0 if shots else 25.0
	var players: Array = []
	for i in range(n):
		players.append({"name": ["Caio", "Lívia", "Otávio", "Júlia", "Marco"][i], "kind": ["muito_dificil", "facil", "intermediaria", "normal", "dificil"][i]})
	main._rules = rules
	main._players = players
	main.show_game()
	await _frames(5)
	var gs: GameScreen = main._screen
	gs.ai_delay = 0.05 if not shots else 0.25
	if shots:
		await _wait(2.0)
		await _shot("inicio_ia")
		await _wait_rounds(gs, 9)
		await _shot("meio_ia")
	Engine.time_scale = 25.0
	var t0 := Time.get_ticks_msec()
	while not gs.g.finished and Time.get_ticks_msec() - t0 < 120000:
		await _frames(1)
	print("partida IA terminou: ", gs.g.finished, " rodadas ", gs.g.round_no, " pontos ", gs.g.players.map(func(p): return p.points))
	Engine.time_scale = 1.0
	await _wait(1.0)
	await _shot("fim")
	# 2) partida com humano no assento 1
	players[0]["kind"] = "humano"
	main._players = players
	main.show_game()
	await _frames(5)
	gs = main._screen
	gs.ai_delay = 0.02
	Engine.time_scale = 25.0 if not shots else 1.0
	var human_turns := 0
	var t1 := Time.get_ticks_msec()
	while not gs.g.finished and human_turns < 40 and Time.get_ticks_msec() - t1 < 120000:
		await _frames(1)
		if gs._busy or gs.g.current != 0:
			continue
		if gs.g.phase == "descarte":
			if shots and _shot_i < 8:
				await _shot("descarte")
			var p := gs.g.cur()
			for c in range(6):
				if p.tokens[c] > 0:
					gs._overlay.find_children("*", "TokenView", true, false)[c].pressed.emit(gs._overlay.find_children("*", "TokenView", true, false)[c])
					break
			continue
		if gs.g.phase == "nobre":
			gs.g.choose_noble(gs.g.noble_options[0])
			gs._close_overlay()
			gs._continue()
			continue
		if gs.g.phase != "acao":
			continue
		human_turns += 1
		# tenta comprar algo do mercado; senao pega fichas como a IA faria
		var bought := false
		for e in gs.g.market_cards():
			if gs.g.can_afford(gs.g.cur(), e[2]):
				gs._on_card_pressed(gs._market_views[e[0]][e[1]])
				if shots and human_turns == 6:
					await _wait(0.3)
					await _shot("selecao_carta")
				gs._on_buy()
				bought = true
				break
		if bought:
			continue
		var act := AI.choose_action(gs.g, 0)
		if act[0] == "take":
			for c in act[1]:
				gs._on_token_pressed(gs._token_views[c])
			if shots and human_turns == 3:
				await _wait(0.3)
				await _shot("selecao_fichas")
			gs._on_take()
		elif act[0] == "reserve":
			gs._on_card_pressed(gs._market_views[act[1]][act[2]])
			gs._on_reserve()
		elif act[0] == "buy":
			if act[1] == "r":
				gs._on_card_pressed(gs._reserve_views[act[2]])
			else:
				gs._on_card_pressed(gs._market_views[act[2]][act[3]])
			gs._on_buy()
		else:
			gs._on_pass()
	print("turnos humanos jogados: ", human_turns, " | fim: ", gs.g.finished)
	# 3) forca a fase de descarte e a escolha de nobre
	Engine.time_scale = 1.0
	players[0]["kind"] = "humano"
	main._players = players
	main.show_game()
	await _frames(5)
	gs = main._screen
	var pl: GameState.PlayerState = gs.g.players[0]
	pl.tokens = [3, 3, 2, 1, 0, 0]
	for c in range(5):
		gs.g.bank[c] -= pl.tokens[c]
	gs.refresh()
	var cols: Array = []
	for c in range(5):
		if gs.g.bank[c] > 0 and cols.size() < 3:
			cols.append(c)
	for c in cols:
		gs._on_token_pressed(gs._token_views[c])
	await _wait(0.4)
	await _shot("selecao_fichas")
	gs._on_take()
	await _wait(1.0)
	print("fase apos pegar com mao cheia: ", gs.g.phase)
	await _shot("descarte")
	while gs.g.phase == "descarte":
		var views := gs._overlay.find_children("*", "TokenView", true, false)
		for tv in views:
			if gs.g.cur().tokens[tv.color_idx] > 0:
				tv.pressed.emit(tv)
				break
		await _frames(2)
	print("descarte resolvido: ", gs.g.cur().token_count() <= gs.g.rules.hand_limit or gs.g.current != 0)
	Engine.time_scale = 1.0
	await _wait(1.0)
	await _shot("humano")
	print("SMOKE OK")
	get_tree().quit()


func _frames(k: int) -> void:
	for i in range(k):
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _wait_rounds(gs: GameScreen, r: int) -> void:
	while gs.g.round_no < r and not gs.g.finished:
		await _frames(2)


func _shot(name: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot_i += 1
	img.save_png(ProjectSettings.globalize_path("%s/%02d_%s.png" % [out_dir, _shot_i, name]))
