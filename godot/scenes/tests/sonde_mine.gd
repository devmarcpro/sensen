extends Node
## Sonde de la mine ([[Mine sous une cellule]], designer 2026-09-02). Elle vérifie les trois promesses
## qu'on ne peut pas lire dans les fichiers :
##   1. on ne creuse QUE sous une cellule qu'on possède — sans claim, le puits refuse ;
##   2. un étage de mine est PLEIN : de la roche partout sauf la chambre d'arrivée, et personne dedans ;
##   3. plus c'est profond, plus la roche est dure — c'est la promesse du designer, et elle se mesure.
##   Godot --headless --path godot res://scenes/tests/sonde_mine.tscn

var soucis: Array = []


func _ready() -> void:
	var sim := Simulation.new(0x4D1E)
	sim.graine_monde = 4242
	sim.charger_camp()
	var j := {}
	for x in sim.vivants():
		if x.controle == "joueur":
			j = x
	if j.is_empty():
		print("SONDE MINE : ECHEC — pas de joueur au camp")
		get_tree().quit(1)
		return
	# 1. sans claim, on ne creuse pas.
	var cell: Vector2i = sim.monde.cellule_de(j.pos)
	sim.monde.claims.erase(cell)
	if sim.creuser_un_puits(j, 0):
		soucis.append("  le puits s'est ouvert sur une cellule qui n'est pas au joueur")
	# 2. avec le claim, la mine s'ouvre.
	sim.monde.claims[cell] = {"role": "base"}
	j.endurance = int(j.endurance_max)
	if not sim.creuser_un_puits(j, 0):
		print("SONDE MINE : ECHEC — le puits refuse sur une cellule revendiquee")
		get_tree().quit(1)
		return
	print("mine ouverte sous %s" % str(cell))
	var duretes: Array = []
	for etage in [1, 4, 8, 16]:
		if int(sim.donjon.etage) != etage:
			j = _joueur(sim)
			j.endurance = int(j.endurance_max)
			while int(sim.donjon.etage) < etage:
				if not sim.creuser_un_puits(j, 0):
					soucis.append("  le puits refuse a l'etage %d" % int(sim.donjon.etage))
					break
				j = _joueur(sim)
				j.endurance = int(j.endurance_max)
		# la mine est-elle pleine, et vide d'habitants ?
		var libres := 0
		var betes := 0
		for y in sim.grille.hauteur_grille:
			for x in sim.grille.largeur:
				if not sim.grille.bloque_passage(Vector2i(x, y)):
					libres += 1
		for x2 in sim.vivants():
			if x2.controle != "joueur":
				betes += 1
		var total: int = sim.grille.largeur * sim.grille.hauteur_grille
		var mat: String = sim.grille.materiau_defaut
		var d: float = float(GameData.catalogues.materials.get(mat, {}).get("stats", {}).get("durete", 0))
		duretes.append(d)
		print("  etage %2d : %s (durete %d) — %d tuiles degagees sur %d, %d creature(s)" % [etage, mat, d, libres, total, betes])
		if libres > total / 20:
			soucis.append("  etage %d : %d tuiles degagees — une mine doit etre PLEINE" % [etage, libres])
		if betes > 0:
			soucis.append("  etage %d : %d creature(s) — on n'y risque que l'effondrement et la faim" % [etage, betes])
	for k in range(1, duretes.size()):
		if duretes[k] < duretes[k - 1]:
			soucis.append("  la roche RAMOLLIT en descendant (%d puis %d) — c'est l'inverse de la promesse" % [duretes[k - 1], duretes[k]])
	# 4. la galerie reste ouverte : on creuse, on remonte au camp, on redescend, et le trou est la.
	j = _joueur(sim)
	while int(sim.donjon.etage) > 1:
		j.etage_depuis = int(sim.donjon.etage)
		sim.charger_donjon(str(sim.donjon.theme), int(sim.donjon.graine), int(sim.donjon.id), int(sim.donjon.etage) - 1, j)
		j = _joueur(sim)
	# On se poste au BORD de la chambre : au centre, les huit voisines sont deja degagees et il n'y a
	# rien a creuser — la mine commence au mur.
	var centre: Vector2i = j.pos
	var bord := centre + Vector2i(1, 0)
	sim.grille.liberer(j.pos)
	j.pos = bord
	sim.grille.placer(j.id, bord)
	var voisines: Array = []
	for d in Grille.DIRS:
		var q: Vector2i = bord + d
		if sim.grille.dans(q) and sim.grille.bloque_passage(q):
			voisines.append(q)
	var creusees := 0
	for q2 in voisines:
		j.endurance = int(j.endurance_max)
		j.compteur = 0
		if sim._creuser(j, q2, 0):
			creusees += 1
	print("  %d tuiles creusees a l'etage 1" % creusees)
	var id_mine: int = int(sim.donjon.id)
	sim._sortir(j)   # on remonte au jour
	j = _joueur(sim)
	j.endurance = int(j.endurance_max)
	sim.creuser_un_puits(j, 0)   # et on redescend dans SA mine
	var rouvertes := 0
	for q3 in voisines:
		if not sim.grille.bloque_passage(q3):
			rouvertes += 1
	print("  au retour : %d tuiles sur %d encore ouvertes" % [rouvertes, creusees])
	if creusees > 0 and rouvertes < creusees:
		soucis.append("  la galerie s'est refermee : une mine est un ouvrage, elle doit rester")
	for s in soucis:
		print(s)
	if not soucis.is_empty():
		print("SONDE MINE : ECHEC — %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("sonde mine : elle ne s'ouvre que sur sa terre, elle est pleine, et elle durcit en descendant")
	get_tree().quit()


func _joueur(sim) -> Dictionary:
	for x in sim.vivants():
		if x.controle == "joueur":
			return x
	return {}
