extends SceneTree
## Executor de partidas IA x IA para as ferramentas de evolucao e torneio.
## Uso: godot --headless --path . --script res://tests/partidas.gd -- entrada.json saida.json
## entrada: {"matches": [{"rules": "house"|"classico"|"house_arcaico"|"classico_caio"|{dicionario de regras},
##                        "seats": ["normal", "tatica", "{...json...}"], "seed": 123}, ...]}
## saida:   {"results": [{"win": [0, 1, 0], "points": [..], "rounds": n}, ...]}

func _rules(spec) -> RuleSet:
	if spec is Dictionary:
		return RuleSet.from_dict(spec)
	var name: String = spec
	match name:
		"house":
			return RuleSet.house_full()
		"house_arcaico":
			var r := RuleSet.house_full()
			r.deck = "arcaico"
			return r
		"classico_caio":
			var r2 := RuleSet.classic()
			r2.deck = "caio"
			return r2
	return RuleSet.classic()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var job = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var results: Array = []
	for m in job["matches"]:
		var cfg: Array = []
		for i in range(m["seats"].size()):
			cfg.append({"name": "J%d" % (i + 1), "kind": m["seats"][i]})
		var g := GameState.new()
		g.setup(_rules(m.get("rules", "house")), cfg, int(m["seed"]))
		var guard := 0
		while not g.finished and guard < 3000:
			g.apply_ai_action(AI.choose_action(g, g.current))
			guard += 1
		var win: Array = []
		var w := g.winners()
		for i in range(g.n):
			win.append(1.0 / w.size() if w.has(i) else 0.0)
		var pts: Array = []
		for p in g.players:
			pts.append(p.points)
		results.append({"win": win, "points": pts, "rounds": g.round_no})
	var f := FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify({"results": results}))
	f.close()
	quit()
