extends Node
## Sonde du journal : les lignes qui reviennent tique après tique doivent se CUMULER, pas s'empiler.
## Née du parcours robot du 2026-09-02, où un seul poison écrivait sept lignes d'affilée et noyait
## tout le reste du combat. La suite de tests ne charge pas les scripts d'écran : on ouvre donc la
## scène du jeu et on parle directement à son journal.
##   Godot --headless --path godot res://scenes/tests/sonde_journal.tscn


func _ready() -> void:
	var scene: Node = load("res://scenes/demo/main.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	scene.journal.clear()
	for k in 5:
		scene._sur_journal("journal.statut_degats", {"nom": "Aventurier", "statut": "Poison", "degats": 2})
	var lignes: Array = scene.journal.duplicate()
	var ok := lignes.size() == 1 and str(lignes[0]).contains("10") and str(lignes[0]).contains("5")
	print("cinq tics de poison -> %d ligne(s) : %s" % [lignes.size(), str(lignes[0]) if not lignes.is_empty() else "(vide)"])
	# Un autre statut, ou une autre cible, ouvre une NOUVELLE ligne : on ne cumule que l'identique.
	scene._sur_journal("journal.statut_degats", {"nom": "Aventurier", "statut": "Saignement", "degats": 3})
	scene._sur_journal("journal.statut_degats", {"nom": "Bandit", "statut": "Saignement", "degats": 3})
	var ok2: bool = scene.journal.size() == 3
	print("un autre statut, une autre cible -> %d lignes" % scene.journal.size())
	if not (ok and ok2):
		print("SONDE JOURNAL : ECHEC")
		get_tree().quit(1)
		return
	print("sonde journal : le cumul tient")
	get_tree().quit()
