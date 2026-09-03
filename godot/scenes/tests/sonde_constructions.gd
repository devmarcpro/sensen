extends Node
## Sonde des constructions d'armure (designer 2026-09-03 : « donner des bonus de stats par type
## d'armure »). Elle verifie LA condition sans laquelle l'idee se retourne : le bonus doit aller
## CONTRE LE GRAIN. Si la construction qui protege le mieux donnait aussi le plus gros bonus, elle
## serait strictement superieure et le choix d'armure disparaitrait.
##   Godot --headless --path godot res://scenes/tests/sonde_constructions.tscn

var soucis: Array = []


func _ready() -> void:
	var ar: Dictionary = GameData.config("combat_rules").armure
	var matrice: Dictionary = ar.matrice
	var bonus: Dictionary = ar.get("bonus_construction", {})
	var lignes: Array = []
	for c in matrice.keys():
		var m: Dictionary = matrice[c]
		# La protection REELLE : armure = durete / 4 x matrice. Ma premiere version classait sur la
		# matrice seule et concluait que la plaque protege moins que le cuir — faux : la matrice penalise
		# la plaque contre le tranchant, mais l'acier a une durete de 39 quand le cuir en a 4. La matiere
		# representative est declaree en donnee (`matiere_type`), pour que le classement soit relisible.
		var b0: Dictionary = bonus.get(c, {})
		var dur := float(GameData.catalogues.materials.get(str(b0.get("matiere_type", "")), {}).get("stats", {}).get("durete", 1.0))
		var moy_m := (float(m.get("tranchant", 1.0)) + float(m.get("perforant", 1.0)) + float(m.get("contondant", 1.0))) / 3.0
		var prot := dur / 4.0 / maxf(0.01, moy_m)
		var b: Dictionary = b0
		lignes.append({"c": str(c), "prot": prot, "stat": str(b.get("stat", "—")), "val": int(b.get("valeur", 0))})
	lignes.sort_custom(func(a, b): return float(a.prot) > float(b.prot))
	print("%-12s %10s %-12s %s" % ["construction", "protection", "stat", "bonus par piece"])
	for l in lignes:
		print("%-12s %10.2f %-12s +%d" % [l.c, l.prot, l.stat, l.val])
	# 1. chaque construction donne quelque chose
	for l in lignes:
		if int(l.val) <= 0:
			soucis.append("  la construction « %s » ne donne aucune stat : elle n'a pas d'identite" % l.c)
	# 2. LE POINT CRITIQUE : le bonus va contre le grain
	for i in lignes.size():
		for k in range(i + 1, lignes.size()):
			var mieux: Dictionary = lignes[i]   # protege plus
			var moins: Dictionary = lignes[k]
			if float(mieux.prot) > float(moins.prot) + 0.01 and int(mieux.val) > int(moins.val):
				soucis.append("  « %s » protege PLUS que « %s » et donne PLUS (+%d contre +%d) : elle est strictement superieure" % [mieux.c, moins.c, int(mieux.val), int(moins.val)])
	# 3. et chaque stat n'est pas monopolisee : au moins quatre stats servies
	var stats := {}
	for l in lignes:
		stats[str(l.stat)] = true
	print("stats servies : %d (%s)" % [stats.size(), str(stats.keys())])
	if stats.size() < 4:
		soucis.append("  seulement %d stats servies : les constructions se ressemblent trop" % stats.size())
	for x in soucis:
		print(x)
	if not soucis.is_empty():
		print("SONDE CONSTRUCTIONS : ECHEC — %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("sonde constructions : chacune donne une stat, et le bonus va contre le grain")
	get_tree().quit()
