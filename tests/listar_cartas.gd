extends SceneTree
## Generates assets/cards/CARD_LIST.csv with the art file name of every card.
## Usage: godot --headless --path . --script res://tests/listar_cartas.gd
func _init() -> void:
	var f := FileAccess.open("res://assets/cards/CARD_LIST.csv", FileAccess.WRITE)
	f.store_line("deck,file,level,bonus,points,cost")
	for deck in ["caio", "oficial"]:
		var dir: String = Defs.DECK_DIRS[deck]
		for c in Defs.build_deck(deck):
			var parts: Array = []
			for i in range(5):
				if c.cost[i] > 0:
					parts.append("%d %s" % [c.cost[i], Defs.COLOR_NAMES[i]])
			f.store_line("%s,%s/%s.png,%d,%s,%d,%s" % [dir, dir, c.key, c.level, Defs.COLOR_NAMES[c.bonus], c.points, " + ".join(parts)])
	f.close()
	quit()
