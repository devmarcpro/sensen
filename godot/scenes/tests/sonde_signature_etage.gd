extends Node
## Signature d'un étage de donjon : de quoi comparer AVANT et APRÈS un changement de génération.
##   Godot --headless --path godot res://scenes/tests/sonde_signature_etage.tscn

func _ready() -> void:
	var theme: Dictionary = GameData.entree("dungeon_themes", "ruine")
	var gen := Donjon.new(GameData.catalogues.get("dungeon_rooms", {}), GameData.catalogues.get("dungeon_connectors", {}), theme)
	for graine in [51, 7, 202]:
		for etage in [1, 3]:
			var e: Dictionary = gen.generer_etage(graine, 4, etage, 8, false)
			var sols: Array = e.sol.keys()
			sols.sort()
			var h := hash([sols, e.murs.keys(), e.entree, e.escalier, e.pieces.size(), e.coffres.size(), e.spawns.size()])
			print("graine %d etage %d : sol %d, murs %d, entree %s, escalier %s, pieces %d, coffres %d, spawns %d, hash %d" % [
				graine, etage, e.sol.size(), e.murs.size(), str(e.entree), str(e.escalier), e.pieces.size(), e.coffres.size(), e.spawns.size(), h])
	get_tree().quit()
