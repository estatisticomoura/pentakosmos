class_name Expansion
extends RefCounted
## Jogo base x expansao.
##
## O jogo base traz os decks Pentakosmos e Arcaico, os filosofos classicos, 2 escritores e
## 3 governantes, sem personalizacao. A expansao acrescenta os outros escritores e governantes
## e a personalizacao (criar, duplicar, editar, importar e exportar decks, conjuntos e
## predefinicoes). Os dados da expansao ficam na pasta res://expansao/, que nao faz parte do
## repositorio publico; quando ela esta presente no build, a expansao esta disponivel.

const DIR := "res://expansao/"
const MARK := "res://expansao/expansao.txt"
const GOVERNORS_FILE := "res://expansao/governantes.csv"
const WRITERS_FILE := "res://expansao/escritores.csv"


static func owned() -> bool:
	## Por enquanto: a pasta da expansao esta no build. (Depois: tambem a compra na loja.)
	return FileAccess.file_exists(MARK) or ResourceLoader.exists(MARK)


static func read(path: String) -> String:
	if not owned() or not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


static func lang_file(code: String) -> String:
	return DIR + "lang/" + code + ".json"
