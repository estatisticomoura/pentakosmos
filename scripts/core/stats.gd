class_name Stats
extends RefCounted
## Estatisticas das partidas: um registro por partida em user://estatisticas.json.
## Cada registro guarda as regras completas, o deck (com uma "impressao digital" do conteudo),
## a duracao e, para cada jogador, pontos, colocacao, cartas compradas por grupo e cor,
## pontos por cor, filosofos, escritores e o tempo medio por acao (humanos).

const PATH := "user://estatisticas.json"
const VERSION := 1
const ELEMS := ["ar", "agua", "eter", "fogo", "terra"]
static var _games: Array = []
static var _loaded := false


static func games() -> Array:
	if not _loaded:
		_loaded = true
		_games = []
		if FileAccess.file_exists(PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if d is Dictionary and d.get("games") is Array:
				_games = d["games"]
	return _games


static func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"app": "Pentakosmos", "version": VERSION, "games": _games}))
		f.close()


static func deck_fingerprint(cards: Array) -> String:
	var parts: Array = []
	for c in cards:
		parts.append("%d/%d/%d/%s" % [c.level, c.bonus, c.points, ",".join(c.cost.map(func(x): return str(x)))])
	parts.sort()
	return ";".join(parts).md5_text().substr(0, 12)


static func rules_name(r: RuleSet) -> String:
	## Nome do preset que tem exatamente estas regras de jogo; senao "Custom".
	for p in RuleSet.builtin_presets():
		if (p[1] as RuleSet).same_game(r):
			return p[0]
	var custom := Store.custom_presets()
	for nm in custom:
		if RuleSet.from_dict(custom[nm]).same_game(r):
			return nm
	return "Custom"


static func record_game(g: GameState, secs: float, act_times: Dictionary) -> void:
	var rank: Array = g.ranking()
	var winners: Array = g.winners()
	var players: Array = []
	for i in range(g.n):
		var p: GameState.PlayerState = g.players[i]
		var bought := {}
		for lv in [1, 2, 3]:
			bought[str(lv)] = [0, 0, 0, 0, 0]
		for cid in p.owned:
			var sc := g.spec_color_for(p, cid, int(p.joker.get(cid, -1)))
			if sc >= 0:
				bought[str(g.cards[cid].level)][sc] += 1
		var phil_pts := 0
		var wri_pts := 0
		var nphil := 0
		var nwri := 0
		for id in p.nobles:
			if Defs.is_writer(id):
				nwri += 1
				wri_pts += int(p.patron_pts.get(id, 0))
			else:
				nphil += 1
				phil_pts += int(p.patron_pts.get(id, 0))
		var at: Array = act_times.get(i, [0.0, 0])
		players.append({
			"name": p.name, "kind": p.kind, "human": not p.is_ai(),
			"points": p.points, "cards": p.cards, "place": rank.find(i) + 1, "winner": winners.has(i),
			"win_type": ("especializacao" if g.meets_color(p) else "pontos") if winners.has(i) else "",
			"governor": g.governors[p.governor]["name"] if p.governor >= 0 else "",
			"target": g.target_of(p),
			"bought": bought, "color_pts": p.color_pts.duplicate(),
			"philosophers": nphil, "philosopher_pts": phil_pts, "writers": nwri, "writer_pts": wri_pts,
			"actions": int(at[1]), "action_secs": snappedf(float(at[0]), 0.1),
		})
	var rec := {
		"id": "%d-%06d" % [int(Time.get_unix_time_from_system()), randi() % 1000000],
		"date": int(Time.get_unix_time_from_system()),
		"secs": int(secs), "rounds": g.round_no,
		"rules": g.rules.to_dict(), "rules_name": rules_name(g.rules),
		"deck": g.rules.deck, "deck_fp": deck_fingerprint(g.cards),
		"players": players,
	}
	games().append(rec)
	_save()


static func human_names() -> Array:
	var seen := {}
	var out: Array = []
	for gm in games():
		for p in gm["players"]:
			if p.get("human", false) and not seen.has(p["name"]):
				seen[p["name"]] = true
				out.append(p["name"])
	return out


static func filtered(player: String, days: int, rules_filter: String) -> Array:
	## Partidas em que `player` (humano) jogou, nos ultimos `days` dias (0 = todas),
	## e com as regras de nome `rules_filter` ("" = todas). Mais recentes primeiro.
	var now := int(Time.get_unix_time_from_system())
	var out: Array = []
	for gm in games():
		if days > 0 and now - int(gm["date"]) > days * 86400:
			continue
		if rules_filter != "" and gm.get("rules_name", "") != rules_filter:
			continue
		for p in gm["players"]:
			if p.get("human", false) and p["name"] == player:
				out.append(gm)
				break
	out.sort_custom(func(a, b): return int(a["date"]) > int(b["date"]))
	return out


static func me(gm: Dictionary, player: String) -> Dictionary:
	for p in gm["players"]:
		if p.get("human", false) and p["name"] == player:
			return p
	return {}


static func summary(gms: Array, player: String) -> Dictionary:
	var n := gms.size()
	var wins := 0
	var spec := 0
	var secs := 0
	var win_pts := 0
	var act_s := 0.0
	var act_n := 0
	for gm in gms:
		var p := me(gm, player)
		secs += int(gm["secs"])
		act_s += float(p.get("action_secs", 0.0))
		act_n += int(p.get("actions", 0))
		if p.get("winner", false):
			wins += 1
			win_pts += int(p["points"])
			if p.get("win_type", "") == "especializacao":
				spec += 1
	return {"games": n, "wins": wins, "win_pct": (100.0 * wins / n) if n > 0 else 0.0, "secs": secs,
		"avg_win_pts": (float(win_pts) / wins) if wins > 0 else 0.0, "spec_wins": spec,
		"avg_action": (act_s / act_n) if act_n > 0 else 0.0}


# --- exportar / importar --------------------------------------------------------
static func export_json() -> String:
	return JSON.stringify({"app": "Pentakosmos", "version": VERSION, "games": games()}, "  ")


static func export_csv() -> String:
	## Uma linha por partida e por jogador humano; colunas prontas para planilha.
	var head: Array = ["id", "data", "jogador", "regras", "deck", "deck_fp", "jogadores", "adversarios", "colocacao",
		"venceu", "tipo_vitoria", "pontos", "cartas", "rodadas", "duracao_s", "acoes", "tempo_medio_acao_s",
		"filosofos", "pontos_filosofos", "escritores", "pontos_escritores"]
	for lv in ["basicas", "intermediarias", "avancadas"]:
		for e in ELEMS:
			head.append("%s_%s" % [lv, e])
	for e in ELEMS:
		head.append("pontos_" + e)
	for k in RuleSet.KEYS:
		head.append("regra_" + k)
	var lines: Array = [",".join(head)]
	for gm in games():
		var opp: Array = []
		for p in gm["players"]:
			if not p.get("human", false):
				opp.append(p["name"])
		for p in gm["players"]:
			if not p.get("human", false):
				continue
			var row: Array = [gm["id"], Time.get_datetime_string_from_unix_time(int(gm["date"]), true), p["name"],
				gm.get("rules_name", ""), gm.get("deck", ""), gm.get("deck_fp", ""), gm["players"].size(),
				" / ".join(opp), p["place"], 1 if p["winner"] else 0, p.get("win_type", ""), p["points"], p["cards"],
				gm["rounds"], gm["secs"], p.get("actions", 0),
				snappedf(float(p.get("action_secs", 0.0)) / maxf(1.0, float(p.get("actions", 0))), 0.1),
				p.get("philosophers", 0), p.get("philosopher_pts", 0), p.get("writers", 0), p.get("writer_pts", 0)]
			for lv in ["1", "2", "3"]:
				for c in range(5):
					row.append(p["bought"][lv][c])
			for c in range(5):
				row.append(p["color_pts"][c])
			for k in RuleSet.KEYS:
				row.append(gm["rules"].get(k, ""))
			lines.append(",".join(row.map(func(x): return _csv(str(x)))))
	return "\n".join(lines) + "\n"


static func _csv(v: String) -> String:
	if v.contains(",") or v.contains("\"") or v.contains("\n"):
		return "\"" + v.replace("\"", "\"\"") + "\""
	return v


static func import_json(text: String) -> int:
	## Junta as partidas do arquivo as daqui, sem duplicar (pelo id). Devolve quantas entraram;
	## -1 se o arquivo nao for de estatisticas do Pentakosmos.
	var d = JSON.parse_string(text)
	if not (d is Dictionary and d.get("games") is Array):
		return -1
	var have := {}
	for gm in games():
		have[gm["id"]] = true
	var added := 0
	for gm in d["games"]:
		if gm is Dictionary and gm.has("id") and gm.has("players") and not have.has(gm["id"]):
			_games.append(gm)
			have[gm["id"]] = true
			added += 1
	if added > 0:
		_save()
	return added
