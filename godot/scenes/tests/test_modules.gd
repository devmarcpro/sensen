extends Node
var refus: Array[String] = []
var n := 0
## « Essaye tout » (demande du designer, 2026-08-30) : chaque forme avec chaque noyau, puis chaque autre module
## ajouté à un sort de base — assemblé ET exécuté sur une esplanade, sans limite. Le verdict : le nombre de
## plans refusés (erreurs d'assemblage) et le nombre d'erreurs de script imprimées par Godot (à compter dehors).
##   Godot --headless --path godot res://scenes/tests/test_modules.tscn

func _ready() -> void:
	var s := Simulation.new(4242)
	s.charger_donjon("ruine", 4242, 9, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	for dx in range(-8, 9):
		for dy in range(-8, 9):
			var t: Vector2i = j.pos + Vector2i(dx, dy)
			if s.grille.dans(t) and t != j.pos:
				s.grille.contenu[s.grille.idx(t)] = 0
				s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	var par_type := {}
	for mid in GameData.catalogues.modules.keys():
		var t := str(GameData.catalogues.modules[mid].module_type)
		if not par_type.has(t):
			par_type[t] = []
		par_type[t].append(str(mid))
	for t in par_type.keys():
		par_type[t].sort()
	var cible: Vector2i = j.pos + Vector2i(2, 0)
	var executer := func(mods: Array) -> void:   # les compteurs sont des membres : une lambda capture par valeur
		n += 1
		var pl := s.capacites.assembler(mods, 10, "1d4", {}, j.competences_eff)
		pl["name_key"] = ""
		pl["arme"] = {}
		pl["fonct"] = {}
		if not pl.erreurs.is_empty():
			refus.append("%s → %s" % [str(mods), str(pl.erreurs)])
			return
		j.sante = 999
		j.mana = 999
		j.endurance = 999
		j.vivant = true
		s._executer_capacite(j, pl, cible)
		s.bombes.clear()
		for x in s.vivants():   # les invocations et relevés ne s'accumulent pas d'un essai à l'autre
			if x.id != j.id and x.has("maitre"):
				x.vivant = false
				s.grille.liberer(x.pos)
	for f in par_type.get("forme", []):
		for c in par_type.get("noyau", []):
			executer.call([f, c])
	for t in ["modificateur", "condition", "liaison"]:
		for m in par_type.get(t, []):
			for c in par_type.get("noyau", []):
				executer.call(["carre", c, m])
	for d in par_type.get("declencheur", []):
		for c in par_type.get("noyau", []):
			executer.call(["point", "etincelle", d, "carre", c])
	for c in par_type.get("noyau", []):   # le noyau répété et deux noyaux différents
		executer.call(["carre", c, c])
		executer.call(["point", c, "etincelle"])
	print("ESSAIS : %d plans assemblés et exécutés, %d refusés" % [n, refus.size()])
	for r in refus.slice(0, 40):
		print("  refus ", r)
	get_tree().quit()
