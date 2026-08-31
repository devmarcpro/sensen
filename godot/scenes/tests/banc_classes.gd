extends Node
## Banc des sorts de classe (designer 2026-08-31, point 47) : chaque forme avec chaque noyau
## (simple et répété), exécutée sur un mannequin — hostile plein pour les dégâts, allié blessé pour
## les soins. Le score d'un plan : ce qu'il change en PV par tick de lancer. Les meilleures lignes
## sortent en JSON (préfixe RECO) pour nourrir les « sorts recommandés » de l'écran de création.
##   Godot --headless --path godot res://scenes/tests/banc_sorts.tscn

var essais := 0


func _ready() -> void:
	var s := Simulation.new(4242)
	s.charger_donjon("ruine", 4242, 9, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	for dx in range(-8, 9):   # l'esplanade nue du banc
		for dy in range(-8, 9):
			var t: Vector2i = j.pos + Vector2i(dx, dy)
			if s.grille.dans(t) and t != j.pos:
				s.grille.contenu[s.grille.idx(t)] = 0
				s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	for x in s.entites.values():
		if x.id != j.id:
			x.vivant = false
			s.grille.liberer(x.pos)
	var origine: Vector2i = j.pos
	var cible: Vector2i = j.pos + Vector2i(2, 0)
	var formes: Array = []
	var noyaux: Array = []
	for mid in GameData.catalogues.modules.keys():
		var t2 := str(GameData.catalogues.modules[mid].module_type)
		if t2 == "forme":
			formes.append(str(mid))
		elif t2 == "noyau":
			noyaux.append(str(mid))
	formes.sort()
	noyaux.sort()
	# Pour chaque noyau : sa meilleure forme, et le score de la paire. Un sort « viable » change
	# vraiment quelque chose sur le mannequin (dégâts ou soins) — sinon il ne mérite pas une case de hotbar.
	var meilleur := {}
	for n in noyaux:
		for f in formes:
			var pl := s.plan_sequence(j, [f, n])
			if not pl.erreurs.is_empty() or int(pl.get("ticks", 0)) <= 0:
				continue
			var off := _essai(s, j, [f, n], origine, cible, false)
			var soin := _essai(s, j, [f, n], origine, cible, true)
			var delta: int = maxi(off, soin)
			if delta <= 0:
				continue
			var sc := float(delta) / float(maxi(1, int(pl.ticks)))
			if not meilleur.has(n) or float(meilleur[n].score) < sc:
				meilleur[n] = {"forme": f, "score": snappedf(sc, 0.01), "delta": delta, "type": "degats" if off >= soin else "soin"}
	for n in meilleur.keys():
		print("VIABLE ", n, " ", JSON.stringify(meilleur[n]))
	print("BANC : %d essais, %d noyaux viables sur %d" % [essais, meilleur.size(), noyaux.size()])
	get_tree().quit()


## Un essai : le mannequin est recréé, le plan exécuté, le delta de PV mesuré (perdus si hostile, rendus si allié).
func _essai(s: Simulation, j: Dictionary, seq: Array, origine: Vector2i, cible: Vector2i, allie: bool) -> int:
	essais += 1
	for x in s.entites.values():   # le banc repart à nu : morts, invocations et relevés dehors
		if x.id != j.id:
			x.vivant = false
			s.grille.liberer(x.pos)
	s.bombes.clear()
	s.affuts.clear()
	s.zones.clear()
	s.grille.liberer(j.pos)
	j.pos = origine
	s.grille.placer(j.id, j.pos)
	j.vivant = true
	j.sante = 999
	j.sante_max = 999
	j.mana = 999
	j.endurance = 999
	j.orientation = Vector2i(1, 0)
	j.declencheurs_armes = []
	if not s.grille.occupant(cible).is_empty():
		s.grille.liberer(cible)
	var m: Dictionary = s.ajouter("loup", cible, "ia")
	m.declencheurs_armes = []
	m.sante_max = 200
	m.sante = 100 if allie else 200
	if allie:
		m.camp = j.camp
	var pl := s.plan_sequence(j, seq)
	if not pl.erreurs.is_empty():
		return 0
	pl["name_key"] = str(pl.get("noyau", {}).get("name_key", ""))   # l'exécuteur journalise le nom du plan
	var avant: int = int(m.sante)
	s._executer_capacite(j, pl, cible)
	if not m.vivant:
		return avant if not allie else 0   # tué net : tout le reste de PV compte comme dégâts
	return (avant - int(m.sante)) if not allie else (int(m.sante) - avant)
