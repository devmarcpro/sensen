extends Node
## Banc des combinaisons de sorts (designer 2026-08-31, point 38) : chaque forme avec chaque noyau
## (simple et répété), exécutée sur un mannequin — hostile plein pour les dégâts, allié blessé pour
## les soins. Le score d'un plan : ce qu'il change en PV par tick de lancer. Les meilleures lignes
## sortent en JSON (préfixe RECO) pour nourrir les « sorts recommandés » de l'écran de création.
##   Godot --headless --path godot res://scenes/tests/banc_sorts.tscn

var essais := 0


func _ready() -> void:
	var s := Simulation.new(4242)
	s.charger_donjon("ruine", 4242, 9, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	for dx in range(-8, 9):   # l'esplanade nue du banc des modules
		for dy in range(-8, 9):
			var t: Vector2i = j.pos + Vector2i(dx, dy)
			if s.grille.dans(t) and t != j.pos:
				s.grille.contenu[s.grille.idx(t)] = 0
				s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	for x in s.entites.values():   # personne d'autre sur le banc
		if x.id != j.id:
			x.vivant = false
			s.grille.liberer(x.pos)
	var par_type := {}
	for mid in GameData.catalogues.modules.keys():
		var t := str(GameData.catalogues.modules[mid].module_type)
		if not par_type.has(t):
			par_type[t] = []
		par_type[t].append(str(mid))
	for t in par_type.keys():
		par_type[t].sort()
	var origine: Vector2i = j.pos
	var cible: Vector2i = j.pos + Vector2i(2, 0)
	var resultats: Array = []
	var sequences: Array = []
	for f in par_type.get("forme", []):
		for c in par_type.get("noyau", []):
			sequences.append([f, c])
			sequences.append([f, c, c])   # le noyau répété double ses dés — plus cher en ticks et en charges
	for seq in sequences:
		var pl := s.plan_sequence(j, seq)
		if not pl.erreurs.is_empty() or int(pl.get("ticks", 0)) <= 0:
			continue
		var off := _essai(s, j, seq, origine, cible, false)
		var soin := _essai(s, j, seq, origine, cible, true)
		if off <= 0 and soin <= 0:
			continue
		var type_s := "degats" if off >= soin else "soin"
		var delta: int = maxi(off, soin)
		var score := float(delta) / float(maxi(1, int(pl.ticks)))
		resultats.append({"sequence": seq, "score": snappedf(score, 0.01), "ticks": int(pl.ticks), "mana": int(pl.get("ressource", 0)), "type": type_s, "delta": delta})
	resultats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	for k in mini(15, resultats.size()):
		print("RECO ", JSON.stringify(resultats[k]))
	var soins := resultats.filter(func(r: Dictionary) -> bool: return str(r.type) == "soin")
	for k in mini(4, soins.size()):
		print("RECO_SOIN ", JSON.stringify(soins[k]))
	var familles := {}   # le meilleur plan par famille de noyau : de la variété, pas seulement la tête du classement
	for r in resultats:
		var noyau := str(r.sequence[1])
		var fam := str(GameData.catalogues.modules[noyau].get("famille", GameData.catalogues.modules[noyau].get("module_type", "")))
		if not familles.has(fam) or float(familles[fam].score) < float(r.score):
			familles[fam] = r
	for fam in familles.keys():
		print("RECO_FAMILLE ", fam, " ", JSON.stringify(familles[fam]))
	print("BANC : %d essais, %d plans qui changent quelque chose" % [essais, resultats.size()])
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
	j.vigueur = 999
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
