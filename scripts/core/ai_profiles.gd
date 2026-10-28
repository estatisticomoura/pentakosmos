class_name AIProfiles
extends RefCounted
## Perfis de IA. Cada perfil = politica + parametros + recursos extras.
##
## Niveis do menu -> perfil:
##   facil         -> "gulosa"
##   normal        -> "estrategista"
##   intermediaria -> definido em res://data/niveis.json (gravado pelo torneio)
##   dificil       -> definido em res://data/niveis.json
##   muito_dificil -> definido em res://data/niveis.json
## Candidatas aos niveis altos:
##   "tatica"  = estrategista + negacao cirurgica + busca no fim de jogo (caminho 1)
##   "evoluida" = estrategista com parametros otimizados por algoritmo genetico
##                (res://data/ia_evoluida.json, gravado por tools/evoluir.py) (caminho 2)
##   "mista"   = tatica usando os parametros da evoluida
## Treinos especializados: com as regras exatas do Classico ou da House completa,
## o jogo usa data/ia_evoluida_<modo>.json e data/niveis_<modo>.json, se existirem.
## Em qualquer outra combinacao de regras, usa o treino geral.

const LEVELS := ["facil", "normal", "intermediaria", "dificil", "muito_dificil"]
const LEVEL_NAMES := {"facil": "IA fácil", "normal": "IA normal", "intermediaria": "IA intermediária",
	"dificil": "IA difícil", "muito_dificil": "IA muito difícil"}
const LEVEL_DEFAULTS := {"intermediaria": "evoluida", "dificil": "tatica", "muito_dificil": "mista"}

# Parametros da heuristica (valores da IA estrategista original).
const DEFAULTS := {
	"noise": 0.10,             # ruido nas avaliacoes (variedade)
	"engine_w": 1.2,           # peso do valor de "motor" de um bonus
	"buy_ratio": 0.75,         # compra a melhor carta acessivel se vale >= isso do melhor alvo
	"demand_base": 0.5,        # (gulosa) valor de motor minimo
	"noble_rest": 0.3,         # (gulosa) peso dos nobres secundarios
	"scarcity_pen": 2.0,       # penalidade por ficha que falta no banco
	"demand_pts": 0.3,         # peso dos pontos na demanda por cor
	"demand_res": 2.0,         # peso das cartas reservadas na demanda
	"tok_w2": 0.5,             # peso do 2o alvo na coleta de fichas
	"tok_w3": 0.25,            # peso do 3o alvo
	"hoard": 0.05,             # valor de guardar fichas
	"gold_gain": 1.0,          # reserva para pegar ouro se a coleta render menos que isso
	"plan_every": 3,           # reavalia o plano a cada N turnos
	"plan_switch": 1.25,       # so troca de plano se o novo for X vezes melhor
	"plan_reserve_turns": 4,   # turnos iniciais em que reserva o alvo principal
	"plan_color_w": 1.5,       # quanto o plano amplifica o valor de uma cor
	"plan_goal_bonus": 0.6,    # valor extra do alvo principal do plano
	"plan_base_engine": 0.5,   # valor de motor independente do plano
	"plan_demand_w": 1.0,      # peso da demanda geral do mercado
	"goal_pts_off": 0.5,       # pontuacao de alvo: (pts + X) / (esforco + Y)
	"goal_effort_off": 4.0,
	"goal_reserved": 1.3,      # bonus para alvos ja reservados
	"plan_noble_w": 0.5,       # peso do nobre-alvo nas cores do plano
	"plan_noble_other": 0.25,  # peso dos outros nobres
	"color_w": 1.0,            # (vitoria por especializacao) valor extra de pontos na cor mais avancada
}

# Faixas usadas pelo algoritmo genetico (min, max).
const RANGES := {
	"noise": [0.0, 0.2], "engine_w": [0.4, 2.5], "buy_ratio": [0.5, 1.0],
	"demand_base": [0.0, 1.5], "noble_rest": [0.0, 1.0], "scarcity_pen": [0.5, 4.0],
	"demand_pts": [0.0, 1.0], "demand_res": [0.5, 4.0], "tok_w2": [0.1, 1.0], "tok_w3": [0.0, 0.8],
	"hoard": [0.0, 0.3], "gold_gain": [0.3, 2.0], "plan_every": [1, 6], "plan_switch": [1.0, 2.0],
	"plan_reserve_turns": [0, 8], "plan_color_w": [0.3, 4.0], "plan_goal_bonus": [0.0, 2.5],
	"plan_base_engine": [0.0, 1.5], "plan_demand_w": [0.0, 2.0], "goal_pts_off": [0.0, 2.0],
	"goal_effort_off": [1.0, 8.0], "goal_reserved": [1.0, 2.0], "plan_noble_w": [0.0, 1.5],
	"plan_noble_other": [0.0, 1.0], "color_w": [0.0, 4.0],
}
const INT_PARAMS := ["plan_every", "plan_reserve_turns"]

static var _evolved := {}
static var _levels := {}


static func rules_mode(rules: RuleSet) -> String:
	## "classico" ou "house" quando as regras sao exatamente as de uma predefinicao
	## com treino especializado; "geral" para qualquer outra combinacao.
	if rules == null:
		return "geral"
	if rules.same_game(RuleSet.classic()):
		return "classico"
	if rules.same_game(RuleSet.house_full()):
		return "house"
	return "geral"


# reserva defensiva nos perfis tatico e misto (Teeteto e Timeu): ganhou no torneio com as regras
# Pentakosmos (43,6% contra 36,1% sem ela) e nao mudou nada no modo Arcaico; so vale no Pentakosmos.
static func defend_for(mode: String) -> bool:
	return mode == "house"


static func profile(name: String, rules: RuleSet = null) -> Dictionary:
	## {"policy": "guloso"|"plano", "params": {...}, "denial": tol (-1 = nao), "endgame": bool}
	var mode := rules_mode(rules)
	match name:
		"facil", "gulosa":
			return {"policy": "guloso", "params": DEFAULTS, "denial": -1.0, "endgame": false}
		"normal", "estrategista":
			return {"policy": "plano", "params": DEFAULTS, "denial": -1.0, "endgame": false}
		"tatica":
			return {"policy": "plano", "params": DEFAULTS, "denial": 1.0, "endgame": true, "defend": defend_for(mode)}
		"evoluida":
			return {"policy": "plano", "params": evolved_params(mode), "denial": -1.0, "endgame": false}
		"mista":
			return {"policy": "plano", "params": evolved_params(mode), "denial": 1.0, "endgame": true, "defend": defend_for(mode)}
		"intermediaria", "dificil", "muito_dificil":
			var target: String = level_map(mode).get(name, LEVEL_DEFAULTS[name])
			if target in LEVEL_DEFAULTS:
				target = LEVEL_DEFAULTS[name]  # evita referencia circular
			return profile(target, rules)
	if name.begins_with("{"):
		# perfil passado como JSON (usado pelo algoritmo genetico e pelo torneio)
		var d = JSON.parse_string(name)
		if d is Dictionary and d.has("base"):
			# um perfil existente com alguns campos trocados (para comparar variantes no torneio)
			var b: Dictionary = profile(str(d["base"]), rules).duplicate()
			for k in ["denial", "endgame", "defend"]:
				if d.has(k):
					b[k] = d[k]
			return b
		if d is Dictionary:
			var params := DEFAULTS.duplicate()
			params.merge(d.get("params", {}), true)
			return {"policy": d.get("policy", "plano"), "params": params,
				"denial": float(d.get("denial", -1.0)), "endgame": bool(d.get("endgame", false))}
	return profile("normal", rules)


static func evolved_params(mode: String = "geral") -> Dictionary:
	## Parametros evoluidos: usa o treino especializado do modo, se existir;
	## senao, o treino geral; senao, os padroes.
	if not _evolved.has(mode):
		var out := DEFAULTS.duplicate()
		var d = null
		if mode != "geral":
			d = _read_json("res://data/ia_evoluida_%s.json" % mode)
		if not (d is Dictionary and d.get("params") is Dictionary and not d["params"].is_empty()):
			d = _read_json("res://data/ia_evoluida.json")
		if d is Dictionary and d.get("params") is Dictionary:
			out.merge(d["params"], true)
		_evolved[mode] = out
	return _evolved[mode]


static func level_map(mode: String = "geral") -> Dictionary:
	if not _levels.has(mode):
		var out := LEVEL_DEFAULTS.duplicate()
		var d = _read_json("res://data/niveis.json")
		if d is Dictionary:
			out.merge(d, true)
		if mode != "geral":
			var dm = _read_json("res://data/niveis_%s.json" % mode)
			if dm is Dictionary:
				out.merge(dm, true)
		_levels[mode] = out
	return _levels[mode]


static func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else null
