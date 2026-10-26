class_name L
extends RefCounted
## Idiomas. Os textos ficam em ingles no codigo; cada traducao e um arquivo
## res://data/lang/<codigo>.json no formato {"texto em ingles": "traducao"}.
## Texto sem traducao aparece em ingles.
## Uso: L.t("Play")  ou  L.f("{name} wins!", {"name": nome})
## Para conferir o que falta traduzir: python3 tools/idiomas.py

# [codigo, nome no proprio idioma]. Ordem do seletor: ingles, portugues e o resto em ordem alfabetica do codigo.
const LANGS := [
	["en", "English"], ["pt", "Português"],
	["be", "Беларуская"], ["bg", "Български"], ["bs", "Bosanski"], ["ca", "Català"],
	["cnr", "Crnogorski"], ["cs", "Čeština"], ["da", "Dansk"], ["de", "Deutsch"],
	["el", "Ελληνικά"], ["es", "Español"], ["et", "Eesti"], ["fi", "Suomi"],
	["fr", "Français"], ["ga", "Gaeilge"], ["hr", "Hrvatski"], ["hu", "Magyar"],
	["is", "Íslenska"], ["it", "Italiano"], ["lb", "Lëtzebuergesch"], ["lt", "Lietuvių"],
	["lv", "Latviešu"], ["mk", "Македонски"], ["mt", "Malti"], ["nb", "Norsk"],
	["nl", "Nederlands"], ["pl", "Polski"], ["rm", "Rumantsch"], ["ro", "Română"],
	["ru", "Русский"], ["sk", "Slovenčina"], ["sl", "Slovenščina"], ["sq", "Shqip"],
	["sr", "Српски"], ["sv", "Svenska"], ["tr", "Türkçe"], ["uk", "Українська"],
]

const COLOR_WORDS := {
	"poligonal": ["white", "blue", "green", "red", "black", "gold"],  # tr
	"solidos": ["air", "water", "aether", "fire", "earth", "sphere"],  # tr
}

static var code := "en"
static var _d := {}


static func set_lang(c: String) -> void:
	code = "en"
	_d = {}
	for l in LANGS:
		if l[0] == c:
			code = c
	if code == "en":
		return
	var path := "res://data/lang/%s.json" % code
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		_d = data


static func index() -> int:
	for i in range(LANGS.size()):
		if LANGS[i][0] == code:
			return i
	return 0


static func names() -> Array:
	return LANGS.map(func(l): return l[1])


static func t(s: String) -> String:
	var v = _d.get(s, "")
	return v if v is String and v != "" else s


static func f(s: String, args: Dictionary) -> String:
	return t(s).format(args)


static func color(c: int) -> String:
	## Nome da cor (ou do elemento, no visual dos solidos), em minusculas.
	return t(COLOR_WORDS["solidos" if Defs.visual == "solidos" else "poligonal"][c])


static func colors(cs: Array) -> String:
	return ", ".join(cs.map(func(c): return color(c)))
