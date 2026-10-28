class_name Content
extends RefCounted
## Conteudo do jogo em arquivos: decks, conjuntos de filosofos, de escritores e de governantes,
## e as predefinicoes de regras.
##
## Os conteudos de fabrica (deck Pentakosmos, deck Arcaico, filosofos e escritores classicos e os
## governantes da expansao) sao fixos: para muda-los, duplica-se. Os do jogador ficam em
## user://conteudo/<tipo>/<nome>.csv - o nome do arquivo e o nome do conteudo, e cada arquivo e
## uma planilha simples, que se abre e edita no LibreOffice ou em qualquer editor de planilhas.

const ROOT := "user://conteudo/"
const KINDS := ["decks", "philosophers", "writers", "governors", "presets"]
const USER := "user:"            # prefixo dos ids de conteudo do jogador

# Colunas (em ingles; os nomes em portugues tambem sao aceitos na leitura)
const ELEMS := ["air", "water", "aether", "fire", "earth"]
const ELEM_ALIASES := {
	"air": 0, "ar": 0, "white": 0, "water": 1, "agua": 1, "água": 1, "blue": 1,
	"aether": 2, "ether": 2, "eter": 2, "éter": 2, "green": 2, "fire": 3, "fogo": 3, "red": 3,
	"earth": 4, "terra": 4, "black": 4, "sphere": 5, "esfera": 5, "gold": 5,
}
const DECK_HEADER := ["group", "points", "bonus", "air", "water", "aether", "fire", "earth", "sphere", "effect"]
const PHIL_HEADER := ["name", "air", "water", "aether", "fire", "earth"]
const WRITER_HEADER := ["name", "air", "water", "aether", "fire", "earth", "points"]
const GOV_HEADER := ["name", "group", "condition", "condition_value", "cost", "cost_value",
	"advantage", "advantage_value", "target_change", "title"]
const HEADER_ALIASES := {
	"grupo": "group", "pontos": "points", "bonus": "bonus", "bônus": "bonus", "efeito": "effect",
	"nome": "name", "condicao": "condition", "condição": "condition", "valor_condicao": "condition_value",
	"custo": "cost", "valor_custo": "cost_value", "vantagem": "advantage", "valor_vantagem": "advantage_value",
	"meta": "target_change", "mudanca_meta": "target_change", "titulo": "title", "título": "title",
	"chave": "key", "valor": "value",
}
const EFFECTS := ["", "token", "two_tokens", "sphere", "extra_turn"]
const MIN_PER_GROUP := 5
const MAX_PER_GROUP := 100
const MAX_COST := 12
const MIN_POINTS := -10
const MAX_POINTS := 10


# ---------------------------------------------------------------------------
# CSV
# ---------------------------------------------------------------------------
static func parse_csv(text: String) -> Array:
	## Linhas da planilha (cada uma, um Array de textos). Aceita virgula ou ponto e virgula
	## como separador (o LibreOffice e o Excel em portugues costumam usar ";").
	text = text.trim_prefix("﻿").replace("\r\n", "\n").replace("\r", "\n")
	var first := text.get_slice("\n", 0)
	var delim := ";" if first.count(";") > first.count(",") else ","
	var rows: Array = []
	var row: Array = []
	var cell := ""
	var quoted := false
	var i := 0
	while i < text.length():
		var ch := text[i]
		if quoted:
			if ch == "\"":
				if i + 1 < text.length() and text[i + 1] == "\"":
					cell += "\""
					i += 1
				else:
					quoted = false
			else:
				cell += ch
		elif ch == "\"":
			quoted = true
		elif ch == delim:
			row.append(cell.strip_edges())
			cell = ""
		elif ch == "\n":
			row.append(cell.strip_edges())
			cell = ""
			if not (row.size() == 1 and row[0] == ""):
				rows.append(row)
			row = []
		else:
			cell += ch
		i += 1
	if cell != "" or not row.is_empty():
		row.append(cell.strip_edges())
		rows.append(row)
	return rows


static func to_csv(header: Array, rows: Array) -> String:
	var lines: Array = [",".join(header.map(_q))]
	for r in rows:
		lines.append(",".join(r.map(_q)))
	return "\n".join(lines) + "\n"


static func _q(v) -> String:
	var s := str(v)
	if s.contains(",") or s.contains("\"") or s.contains("\n") or s.contains(";"):
		return "\"" + s.replace("\"", "\"\"") + "\""
	return s


static func _records(text: String) -> Array:
	## Linhas como dicionarios {coluna: texto}, pela primeira linha (cabecalho).
	var rows := parse_csv(text)
	if rows.is_empty():
		return []
	var head: Array = []
	for h in rows[0]:
		var k: String = str(h).to_lower().strip_edges().replace(" ", "_")
		k = HEADER_ALIASES.get(k, k)
		if ELEM_ALIASES.has(k):
			k = (ELEMS + ["sphere"])[ELEM_ALIASES[k]]
		head.append(k)
	var out: Array = []
	for i in range(1, rows.size()):
		var d := {}
		for j in range(head.size()):
			d[head[j]] = rows[i][j] if j < rows[i].size() else ""
		out.append(d)
	return out


static func _int(s, lo: int, hi: int, default := 0) -> int:
	var t := str(s).strip_edges().replace(",", ".")
	if t == "" or not t.is_valid_float():
		return default
	return clampi(int(round(float(t))), lo, hi)


static func elem_index(s: String) -> int:
	return ELEM_ALIASES.get(s.strip_edges().to_lower(), -1)


# ---------------------------------------------------------------------------
# Listas
# ---------------------------------------------------------------------------
static func builtin(kind: String) -> Array:
	## [[id, nome para exibir (traduzivel)], ...]
	match kind:
		"decks":
			return [["caio", "Pentakosmos deck"], ["arcaico", "Archaic deck"]]  # tr
		"philosophers":
			return [["classico", "Classical philosophers"]]  # tr
		"writers":
			return [["classico", "Classical writers"]]  # tr
		"governors":
			return [["classico", "Governors of Greece"]]  # tr
	return []


static func can_customize() -> bool:
	## Criar, duplicar, editar, importar e exportar conteudo e coisa da expansao.
	return Expansion.owned()


static func is_builtin(kind: String, id: String) -> bool:
	for b in builtin(kind):
		if b[0] == id:
			return true
	return false


static func dir(kind: String) -> String:
	return ROOT + kind + "/"


static func path_of(kind: String, id: String) -> String:
	return dir(kind) + id.trim_prefix(USER) + ".csv"


static func list(kind: String) -> Array:
	## [{"id", "name", "builtin"}], de fabrica primeiro, depois os do jogador em ordem alfabetica.
	var out: Array = []
	for b in builtin(kind):
		out.append({"id": b[0], "name": L.t(b[1]), "builtin": true})
	var names: Array = []
	var d := DirAccess.open(dir(kind)) if (can_customize() or kind == "presets") else null
	if d != null:
		for f in d.get_files():
			if f.get_extension().to_lower() == "csv":
				names.append(f.get_basename())
	names.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	for nm in names:
		out.append({"id": USER + nm, "name": nm, "builtin": false})
	return out


static func exists(kind: String, id: String) -> bool:
	return is_builtin(kind, id) or ((can_customize() or kind == "presets") and id.begins_with(USER) \
		and FileAccess.file_exists(path_of(kind, id)))


static func name_of(kind: String, id: String) -> String:
	for b in builtin(kind):
		if b[0] == id:
			return L.t(b[1])
	return id.trim_prefix(USER)


static func clean_name(nm: String) -> String:
	## Nome valido para arquivo (sem / \ : * ? " < > |), sem espacos nas pontas.
	var out := ""
	for ch in nm.strip_edges():
		out += "_" if "/\\:*?\"<>|".contains(ch) else ch
	return out.substr(0, 60).strip_edges()


static func free_name(kind: String, base: String) -> String:
	## Um nome que ainda nao existe: "Base", "Base 2", "Base 3"...
	base = clean_name(base)
	if base == "":
		base = "Custom"
	var nm := base
	var k := 2
	while FileAccess.file_exists(dir(kind) + nm + ".csv") or _builtin_name_taken(kind, nm):
		nm = "%s %d" % [base, k]
		k += 1
	return nm


static func _builtin_name_taken(kind: String, nm: String) -> bool:
	for b in builtin(kind):
		if L.t(b[1]).to_lower() == nm.to_lower() or b[0] == nm:
			return true
	return false


# ---------------------------------------------------------------------------
# Texto (CSV) de cada conteudo
# ---------------------------------------------------------------------------
static func text_of(kind: String, id: String) -> String:
	if id.begins_with(USER):
		return FileAccess.get_file_as_string(path_of(kind, id)) if FileAccess.file_exists(path_of(kind, id)) else ""
	match kind:
		"decks":
			return deck_csv_from_cards(Defs.build_deck(id))
		"philosophers":
			var rows: Array = []
			for it in load_patrons(kind, id):
				rows.append([L.t(it["name"])] + it["req"])
			return to_csv(PHIL_HEADER, rows)
		"writers":
			var rows2: Array = []
			for it in load_patrons(kind, id):
				rows2.append([L.t(it["name"])] + it["req"] + [it["pts"]])
			return to_csv(WRITER_HEADER, rows2)
		"governors":
			var items: Array = []
			for gv in load_governors(id):
				var c: Dictionary = gv.duplicate()
				c["name"] = L.t(c["name"])
				c["title"] = L.t(c["title"])
				items.append(c)
			return governors_csv(items)
	return ""


static func save_text(kind: String, nm: String, text: String) -> String:
	## Grava (ou substitui) um conteudo do jogador. Devolve o id.
	DirAccess.make_dir_recursive_absolute(dir(kind))
	nm = clean_name(nm)
	var f := FileAccess.open(dir(kind) + nm + ".csv", FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return USER + nm


static func duplicate_item(kind: String, id: String, new_name := "") -> String:
	var nm := free_name(kind, new_name if new_name != "" else L.f("Copy of {name}", {"name": name_of(kind, id)}))
	return save_text(kind, nm, text_of(kind, id))


static func rename_item(kind: String, id: String, new_name: String) -> String:
	## Renomeia um conteudo do jogador; as predefinicoes que o usam sao atualizadas.
	if not id.begins_with(USER):
		return id
	new_name = clean_name(new_name)
	if new_name == "" or new_name == id.trim_prefix(USER):
		return id
	new_name = free_name(kind, new_name)
	var nid := USER + new_name
	DirAccess.rename_absolute(path_of(kind, id), path_of(kind, nid))
	if kind != "presets":
		for p in list("presets"):
			var d := load_preset(p["id"])
			var changed := false
			for k in RuleSet.CONTENT_KEYS:
				if RuleSet.CONTENT_KEYS[k] == kind and d.get(k, "") == id:
					d[k] = nid
					changed = true
			if changed:
				save_preset(p["name"], RuleSet.from_dict(d))
	return nid


static func delete_item(kind: String, id: String) -> void:
	if id.begins_with(USER):
		DirAccess.remove_absolute(path_of(kind, id))


static func import_text(kind: String, nm: String, text: String) -> Dictionary:
	## Importa uma planilha. {"id": ..., "errors": [...]}; com erros, nada e gravado.
	var errs := validate(kind, text)
	if not errs.is_empty():
		return {"id": "", "errors": errs}
	return {"id": save_text(kind, free_name(kind, nm), text), "errors": []}


static func validate(kind: String, text: String) -> Array:
	match kind:
		"decks":
			return parse_deck(text)["errors"]
		"philosophers", "writers":
			return parse_patrons(kind, text)["errors"]
		"governors":
			return parse_governors(text)["errors"]
		"presets":
			return [] if not _records(text).is_empty() else [L.t("The file is empty.")]
	return []


# ---------------------------------------------------------------------------
# Decks
# ---------------------------------------------------------------------------
static func load_deck(id: String) -> Array:
	## Cartas do deck (Array de Defs.CardDef). Deck inexistente ou com erro: deck Pentakosmos.
	if is_builtin("decks", id):
		return Defs.build_deck(id)
	var r := parse_deck(text_of("decks", id))
	if not r["errors"].is_empty() or r["cards"].is_empty():
		return Defs.build_deck("caio")
	return r["cards"]


static func bonus_text(cd: Defs.CardDef) -> String:
	match cd.kind:
		"none":
			return "none"
		"joker":
			return "joker"
		"multi":
			var parts: Array = []
			for c in range(5):
				if cd.bonus_vec[c] > 0:
					parts.append(("%d %s" % [cd.bonus_vec[c], ELEMS[c]]) if cd.bonus_vec[c] > 1 else ELEMS[c])
			return " + ".join(parts)
	return ELEMS[cd.bonus]


static func deck_csv_from_cards(cards: Array) -> String:
	var rows: Array = []
	for cd in cards:
		rows.append([cd.level, cd.points, bonus_text(cd)] + cd.cost.slice(0, 5) + [cd.cost[5], cd.effect])
	return to_csv(DECK_HEADER, rows)


static func parse_bonus(s: String) -> Array:
	## [kind, cor (ou -1), vetor de 5]; kind "" = invalido.
	var t := s.strip_edges().to_lower()
	if t in ["none", "nenhum", "-", "", "0"]:
		return ["none", -1, [0, 0, 0, 0, 0]]
	if t in ["joker", "coringa", "*"]:
		return ["joker", -1, [0, 0, 0, 0, 0]]
	var vec := [0, 0, 0, 0, 0]
	for part in t.split("+"):
		var p: String = part.strip_edges()
		if p == "":
			continue
		var k := 1
		var bits := p.split(" ", false)
		if bits.size() == 2 and bits[0].is_valid_int():
			k = int(bits[0])
			p = bits[1]
		var c := elem_index(p)
		if c < 0 or c > 4:
			return ["", -1, vec]
		vec[c] += clampi(k, 1, 5)
	var tot: int = vec.reduce(func(a, b): return a + b, 0)
	if tot == 0:
		return ["none", -1, vec]
	if tot == 1:
		return ["single", vec.find(1), vec]
	if tot > 5:
		return ["", -1, vec]
	return ["multi", -1, vec]


static func parse_deck(text: String) -> Dictionary:
	var errs: Array = []
	var cards: Array = []
	var per_group := [0, 0, 0, 0]
	var recs := _records(text)
	if recs.is_empty():
		return {"cards": [], "errors": [L.t("The file is empty.")]}
	if not recs[0].has("group") or not recs[0].has("bonus"):
		return {"cards": [], "errors": [L.t("Columns missing: group, points, bonus, air, water, aether, fire, earth.")]}
	var counters := {}
	for i in range(recs.size()):
		var r: Dictionary = recs[i]
		var line := i + 2
		var gtxt: String = str(r.get("group", "")).to_lower()
		var lv: int = {"basic": 1, "basica": 1, "básica": 1, "intermediate": 2, "intermediaria": 2,
			"intermediária": 2, "advanced": 3, "avancada": 3, "avançada": 3}.get(gtxt, _int(gtxt, 0, 9, 0))
		if lv < 1 or lv > 3:
			errs.append(L.f("Line {n}: the group must be 1, 2 or 3.", {"n": line}))
			continue
		var b := parse_bonus(str(r.get("bonus", "")))
		if b[0] == "":
			errs.append(L.f("Line {n}: bonus not understood.", {"n": line}))
			continue
		var cost := [0, 0, 0, 0, 0, 0]
		for c in range(5):
			cost[c] = _int(r.get(ELEMS[c], "0"), 0, MAX_COST)
		cost[5] = _int(r.get("sphere", "0"), 0, MAX_COST)
		var eff: String = str(r.get("effect", "")).strip_edges().to_lower()
		eff = {"ficha": "token", "duas_fichas": "two_tokens", "esfera": "sphere", "turno_extra": "extra_turn"}.get(eff, eff)
		if not EFFECTS.has(eff):
			errs.append(L.f("Line {n}: effect not understood.", {"n": line}))
			eff = ""
		var pts := _int(r.get("points", "0"), MIN_POINTS, MAX_POINTS)
		var cd := Defs.CardDef.new(cards.size(), lv, b[1] if b[0] == "single" else -1, pts, cost)
		cd.kind = b[0]
		cd.bonus_vec = b[2]
		cd.effect = eff
		var ck := "%d_%s" % [lv, bonus_text(cd)]
		counters[ck] = counters.get(ck, 0) + 1
		cd.key = "l%d_%s_%02d" % [lv, (Defs.COLOR_NAMES[cd.bonus] if cd.kind == "single" else cd.kind), counters[ck]]
		cards.append(cd)
		per_group[lv] += 1
	for lv in [1, 2, 3]:
		if per_group[lv] < MIN_PER_GROUP or per_group[lv] > MAX_PER_GROUP:
			errs.append(L.f("{group}: {n} cards (it must have {a} to {b}).", {"group": L.t(Defs.LEVEL_NAMES[lv]),
				"n": per_group[lv], "a": MIN_PER_GROUP, "b": MAX_PER_GROUP}))
	return {"cards": cards, "errors": errs}


# ---------------------------------------------------------------------------
# Filosofos e escritores: [{"name", "req": [5], "pts"}]
# ---------------------------------------------------------------------------
static func load_patrons(kind: String, id: String) -> Array:
	if is_builtin(kind, id):
		var out: Array = []
		if kind == "philosophers":
			for i in range(Defs.NOBLES.size()):
				out.append({"name": Defs.PHILOSOPHERS[i], "req": Defs.NOBLES[i].duplicate(), "pts": 3, "art": i + 1})
		else:
			for i in range(Defs.WRITERS.size()):
				out.append({"name": Defs.WRITER_NAMES[i], "req": Defs.WRITERS[i].duplicate(), "pts": Defs.WRITER_PTS,
					"art": Defs.WRITER_ART[i]})
			# escritores da expansao
			var ex := parse_patrons("writers_extra", Expansion.read(Expansion.WRITERS_FILE))
			for it in ex["items"]:
				out.append(it)
		return out
	var r := parse_patrons(kind, text_of(kind, id))
	if not r["errors"].is_empty() or r["items"].is_empty():
		return load_patrons(kind, "classico")
	return r["items"]


static func parse_patrons(kind: String, text: String) -> Dictionary:
	var errs: Array = []
	var items: Array = []
	var recs := _records(text)
	if recs.is_empty():
		return {"items": [], "errors": [L.t("The file is empty.")]}
	for i in range(recs.size()):
		var r: Dictionary = recs[i]
		var nm := str(r.get("name", "")).strip_edges()
		if nm == "":
			errs.append(L.f("Line {n}: the name is empty.", {"n": i + 2}))
			continue
		var req := [0, 0, 0, 0, 0]
		var tot := 0
		for c in range(5):
			req[c] = _int(r.get(ELEMS[c], "0"), 0, 20)
			tot += req[c]
		if tot == 0:
			errs.append(L.f("Line {n}: the requirement is empty.", {"n": i + 2}))
			continue
		items.append({"name": nm, "req": req, "pts": _int(r.get("points", "1"), -10, 10, 1),
			"art": _int(r.get("art", "0"), 0, 99)})
	var need: int = {"philosophers": 6, "writers": 2}.get(kind, 0)
	if items.size() < need:
		errs.append(L.f("It must have at least {n}.", {"n": need}))
	return {"items": items, "errors": errs}


# ---------------------------------------------------------------------------
# Governantes: [{"name", "group", "cond", "cond_v", "cost", "cost_v", "adv", "adv_v", "target", "title"}]
# ---------------------------------------------------------------------------
static func load_governors(id: String) -> Array:
	if is_builtin("governors", id):
		var out: Array = []
		for gv in Governors.BASE:
			out.append(gv.duplicate())
		var ex := parse_governors(Expansion.read(Expansion.GOVERNORS_FILE), 0)
		for gv in ex["items"]:
			out.append(gv)
		return out
	var r := parse_governors(text_of("governors", id))
	return r["items"] if r["errors"].is_empty() else load_governors("classico")


static func parse_governors(text: String, min_items := 3) -> Dictionary:
	var errs: Array = []
	var items: Array = []
	var recs := _records(text)
	if recs.is_empty():
		return {"items": [], "errors": [L.t("The file is empty.")]}
	for i in range(recs.size()):
		var r: Dictionary = recs[i]
		var g := {
			"name": str(r.get("name", "")).strip_edges(),
			"group": str(r.get("group", "")).strip_edges().to_lower(),
			"cond": str(r.get("condition", "")).strip_edges().to_lower(),
			"cond_v": _int(r.get("condition_value", "0"), 0, 100),
			"cost": str(r.get("cost", "")).strip_edges().to_lower(),
			"cost_v": _int(r.get("cost_value", "0"), 0, 100),
			"adv": str(r.get("advantage", "")).strip_edges().to_lower(),
			"adv_v": _int(r.get("advantage_value", "0"), 0, 100),
			"target": _int(r.get("target_change", "0"), -50, 50),
			"title": str(r.get("title", "")).strip_edges(),
		}
		if g["name"] == "":
			errs.append(L.f("Line {n}: the name is empty.", {"n": i + 2}))
			continue
		if not Governors.CONDITIONS.has(g["cond"]):
			errs.append(L.f("Line {n}: condition not understood.", {"n": i + 2}))
			continue
		if g["cost"] in ["", "-"]:
			g["cost"] = "none"
		if g["adv"] in ["", "-"]:
			g["adv"] = "none"
		if not Governors.COSTS.has(g["cost"]) or not Governors.ADVANTAGES.has(g["adv"]):
			errs.append(L.f("Line {n}: cost or advantage not understood.", {"n": i + 2}))
			continue
		if not Governors.GROUPS.has(g["group"]):
			g["group"] = "composition"
		items.append(g)
	if items.size() < min_items:
		errs.append(L.f("It must have at least {n}.", {"n": min_items}))
	return {"items": items, "errors": errs}


static func governors_csv(items: Array) -> String:
	var rows: Array = []
	for g in items:
		rows.append([g["name"], g["group"], g["cond"], g["cond_v"], g["cost"], g["cost_v"], g["adv"], g["adv_v"],
			g["target"], g["title"]])
	return to_csv(GOV_HEADER, rows)


# ---------------------------------------------------------------------------
# Predefinicoes de regras: planilha de duas colunas (key, value)
# ---------------------------------------------------------------------------
static func load_preset(id: String) -> Dictionary:
	var d := {}
	for r in _records(text_of("presets", id)):
		var k := str(r.get("key", "")).strip_edges()
		if k == "":
			continue
		var v: String = str(r.get("value", ""))
		d[k] = int(v) if v.is_valid_int() else (v == "true" if v in ["true", "false"] else v)
	return d


static func preset_csv(rules: RuleSet) -> String:
	var rows: Array = []
	var d := rules.to_dict()
	for k in RuleSet.KEYS:
		rows.append([k, str(d[k]).to_lower() if d[k] is bool else d[k]])
	return to_csv(["key", "value"], rows)


static func save_preset(nm: String, rules: RuleSet) -> String:
	return save_text("presets", nm, preset_csv(rules))


static func migrate_presets() -> void:
	## Predefinicoes da versao 1.3 (guardadas nas configuracoes) viram arquivos.
	var old := Store.custom_presets()
	if old.is_empty():
		return
	for nm in old:
		if not FileAccess.file_exists(dir("presets") + clean_name(nm) + ".csv"):
			save_preset(nm, RuleSet.from_dict(old[nm]))
		Store.delete_custom_preset(nm)


# ---------------------------------------------------------------------------
# Pacote para compartilhar uma predefinicao com tudo o que ela usa (.zip)
# ---------------------------------------------------------------------------
static func export_package(preset_name: String, rules: RuleSet, path: String) -> bool:
	var z := ZIPPacker.new()
	if z.open(path) != OK:
		return false
	z.start_file("presets/" + clean_name(preset_name) + ".csv")
	z.write_file(preset_csv(rules).to_utf8_buffer())
	z.close_file()
	var d := rules.to_dict()
	for k in RuleSet.CONTENT_KEYS:
		var id: String = d[k]
		if id.begins_with(USER):
			var kind: String = RuleSet.CONTENT_KEYS[k]
			z.start_file(kind + "/" + id.trim_prefix(USER) + ".csv")
			z.write_file(text_of(kind, id).to_utf8_buffer())
			z.close_file()
	z.close()
	return true


static func import_package(path: String) -> Dictionary:
	## Importa um .zip (ou uma planilha solta de predefinicao). Conteudos com o mesmo nome de
	## um ja existente recebem outro nome, e a predefinicao passa a apontar para eles.
	## {"preset": id, "errors": [...]}
	var z := ZIPReader.new()
	if z.open(path) != OK:
		return {"preset": "", "errors": [L.t("This file could not be read.")]}
	var renamed := {}
	var preset_file := ""
	var errs: Array = []
	for f in z.get_files():
		var kind: String = f.get_base_dir()
		if not KINDS.has(kind) or f.get_extension().to_lower() != "csv":
			continue
		if kind == "presets":
			preset_file = f
			continue
		var text := z.read_file(f).get_string_from_utf8()
		var nm := f.get_file().get_basename()
		var r := import_text(kind, nm, text)
		if r["errors"].is_empty():
			renamed[kind + ":" + USER + nm] = r["id"]
		else:
			errs.append(nm + ": " + str(r["errors"][0]))
	var pid := ""
	if preset_file != "":
		var tmp := save_text("presets", "__tmp__", z.read_file(preset_file).get_string_from_utf8())
		var d := load_preset(tmp)
		delete_item("presets", tmp)
		for k in RuleSet.CONTENT_KEYS:
			var key: String = RuleSet.CONTENT_KEYS[k] + ":" + str(d.get(k, ""))
			if renamed.has(key):
				d[k] = renamed[key]
		pid = save_preset(free_name("presets", preset_file.get_file().get_basename()), RuleSet.from_dict(d))
	z.close()
	return {"preset": pid, "errors": errs}
