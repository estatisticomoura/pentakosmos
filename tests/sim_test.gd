extends SceneTree
## Teste sem interface: roda partidas IA x IA e imprime estatisticas.
## Uso: godot --headless --path . --script res://tests/sim_test.gd -- <preset> <jogadores> <ia> <partidas>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var preset := args[0] if args.size() > 0 else "house"
	var n := int(args[1]) if args.size() > 1 else 3
	var kind := args[2] if args.size() > 2 else "normal"
	var games := int(args[3]) if args.size() > 3 else 200
	var rules: RuleSet = RuleSet.house_full() if preset == "house" else RuleSet.classic()
	if preset == "house_oficial":
		rules = RuleSet.house_full()
		rules.deck = "oficial"
	var rounds: Array = []
	var nob := 0.0
	var seat := []
	seat.resize(n)
	seat.fill(0.0)
	var stalls := 0
	var t0 := Time.get_ticks_msec()
	for gi in range(games):
		var cfg: Array = []
		for i in range(n):
			cfg.append({"name": "IA %d" % (i + 1), "kind": kind})
		var g := GameState.new()
		g.setup(rules, cfg, 1000 + gi)
		var guard := 0
		while not g.finished:
			var act := AI.choose_action(g, g.current)
			g.apply_ai_action(act)
			guard += 1
			if guard > 5000:
				push_error("loop")
				break
		if g.round_no >= g.max_rounds:
			stalls += 1
		rounds.append(g.round_no)
		for p in g.players:
			nob += p.nobles.size()
		var w := g.winners()
		for i in w:
			seat[i] += 1.0 / w.size()
	var m := 0.0
	for r in rounds:
		m += r
	m /= rounds.size()
	var sd := 0.0
	for r in rounds:
		sd += (r - m) * (r - m)
	sd = sqrt(sd / (rounds.size() - 1))
	print("preset=%s n=%d ia=%s partidas=%d | rodadas %.2f (+/-%.2f) | nobres/partida %.2f | travadas %d | %.1fs" % [
		preset, n, kind, games, m, 1.96 * sd / sqrt(rounds.size()), nob / games, stalls, (Time.get_ticks_msec() - t0) / 1000.0])
	var s := ""
	for i in range(n):
		s += "%.1f%% " % (100.0 * seat[i] / games)
	print("  vitoria por assento: ", s)
	quit()
