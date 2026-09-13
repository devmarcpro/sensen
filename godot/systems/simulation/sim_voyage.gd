class_name SimVoyage
extends RefCounted
## LE VOYAGE À LA FALLOUT 1 (ordre de travail 39 ter, pas E — 2026-09-13 ; designer : « rajouter le déplacement carte du
## monde à la Fallout 1 », et le monde reste marchable). Le voyage était un téléport : le temps payé d'un coup, et rien
## entre le départ et l'arrivée. Un TRAJET se fait maintenant cellule par cellule, et chaque segment est une occasion :
## l'horloge avance (la faim, la soif, la fatigue et la nuit suivent seules, elles se lisent sur l'heure), et une RENCONTRE
## peut l'interrompre. Elle ne se joue pas dans une arène à part : le joueur est POSÉ DANS LE MONDE, à l'endroit où elle a
## lieu — ce qu'il y trouve est le vrai terrain, le vrai climat, et il peut s'y promener avant de reprendre la route.

static func _cfg() -> Dictionary:
	return GameData.config("voyage")


static func en_cours(sim: Simulation) -> bool:
	return not sim.trajet.is_empty() and not bool(sim.trajet.get("en_pause", false))


## Commencer un trajet vers une cellule : le chemin est la ligne de cellules de la case du joueur à la destination.
static func commencer(sim: Simulation, e: Dictionary, dest: Vector2i) -> bool:
	if sim.lieu != "camp" or sim.monde == null or e.controle != "joueur":
		return false
	if not sim.monde.surface.terre_a(dest):
		EventBus.emettre(&"journal", [&"journal.voyage_impossible", {}])
		return false
	var c := sim.monde.cellule_de(e.pos)
	var chemin: Array = []
	while c != dest and chemin.size() < 4096:
		c += Vector2i(signi(dest.x - c.x), signi(dest.y - c.y))
		chemin.append(c)
	if chemin.is_empty():
		return false
	if sim.en_combat(e):
		sim._quitter_combat(e)
	sim.trajet = {"joueur": str(e.id), "chemin": chemin, "i": 0, "dest": dest}
	EventBus.emettre(&"journal", [&"journal.voyage_depart", {"nom": e.name_key, "n": chemin.size()}])
	return true


## Ce que coûte un segment : la marche d'une cellule, la charge, la route.
static func cout_segment(sim: Simulation, e: Dictionary, cell: Vector2i) -> int:
	var tuiles := int(GameData.config("planete").taille_cellule)
	var pas := sim.regles.ticks_deplacement(int(sim.regles.r.deplacement.cout_base), e.get("competences_eff", e.get("competences", {})), false)
	var cout := float(tuiles) * float(pas) * float(sim.poids_de(e).facteur)
	if not sim.monde.surface.route_de(cell).is_empty():
		cout *= float(GameData.config("planete").voyage.get("route_mult", 1.0))
	return maxi(1, roundi(cout))


## Un segment du trajet. Rend "" (on continue), "arrive", "rencontre" ou "bloque".
static func avancer(sim: Simulation) -> String:
	if not en_cours(sim):
		return ""
	var e: Dictionary = sim.entites.get(str(sim.trajet.joueur), {})
	if e.is_empty() or not e.vivant or sim.lieu != "camp":
		sim.trajet = {}
		return "bloque"
	var chemin: Array = sim.trajet.chemin
	var i := int(sim.trajet.i)
	var cell: Vector2i = chemin[i]
	if not sim.monde.surface.terre_a(cell):   # la mer barre la route : on s'arrête sur la dernière terre
		var avant: Vector2i = chemin[i - 1] if i > 0 else sim.monde.cellule_de(e.pos)
		if avant != sim.monde.cellule_de(e.pos):
			SimCamp.voyager(sim, e, avant, 0)
		sim.trajet = {}
		EventBus.emettre(&"journal", [&"journal.voyage_bloque", {}])
		return "bloque"
	var cout := cout_segment(sim, e, cell)
	sim.horloge_monde.avancer(cout)
	e.compteur = sim.horloge_monde.ticks
	sim.trajet.i = i + 1
	if i + 1 < chemin.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.graine, "rencontre", cell, sim.horloge_monde.ticks / maxi(1, int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000)))])
		if rng.randf() < chance_rencontre(sim, cell):
			SimCamp.voyager(sim, e, cell, 0)   # posé dans le monde, là où la rencontre a lieu
			poser_rencontre(sim, e, cell, rng)
			sim.trajet.en_pause = true
			return "rencontre"
		return ""
	SimCamp.voyager(sim, e, cell, 0)
	sim.trajet = {}
	EventBus.emettre(&"journal", [&"journal.voyage_arrive", {"nom": e.name_key}])
	return "arrive"


## La chance qu'un segment porte une rencontre : le danger de la cellule, la route, la nuit.
static func chance_rencontre(sim: Simulation, cell: Vector2i) -> float:
	var c := _cfg()
	var dm: Array = c.get("danger_mult", [1.0, 1.0, 1.0])
	var p := float(c.get("chance_base", 0.06)) * float(dm[clampi(sim.monde.surface.danger_de(cell), 0, dm.size() - 1)])
	if not sim.monde.surface.route_de(cell).is_empty():
		p *= float(c.get("route_mult", 0.5))
	if SimTerrain.est_nuit(sim):
		p *= float(c.get("nuit_mult", 1.5))
	return p


## Reprendre la route après une rencontre : le chemin repart d'où l'on est.
static func reprendre(sim: Simulation, e: Dictionary) -> bool:
	if sim.trajet.is_empty() or str(sim.trajet.get("joueur", "")) != str(e.id):
		return false
	var dest: Vector2i = sim.trajet.dest
	sim.trajet = {}
	return commencer(sim, e, dest)


## LA RENCONTRE : son type tiré au poids parmi ceux que le danger permet, et ce qui apparaît autour du joueur.
static func poser_rencontre(sim: Simulation, e: Dictionary, cell: Vector2i, rng: RandomNumberGenerator) -> String:
	var c := _cfg()
	var danger := sim.monde.surface.danger_de(cell)
	var types: Dictionary = c.get("rencontres", {})
	var ids: Array = types.keys()
	ids.sort()
	var total := 0.0
	for id in ids:
		if danger >= int(types[id].get("danger_min", 0)):
			total += float(types[id].get("poids", 1))
	var r := rng.randf() * total
	var choisi := ""
	for id in ids:
		if danger < int(types[id].get("danger_min", 0)):
			continue
		r -= float(types[id].get("poids", 1))
		if r <= 0.0:
			choisi = str(id)
			break
	if choisi.is_empty():
		choisi = "voyageur"
	var t: Dictionary = types.get(choisi, {})
	var d := int(c.get("distance_apparition", 6))
	var autour: Vector2i = e.pos + Vector2i(rng.randi_range(-d, d), rng.randi_range(-d, d))
	var n_etres := 0
	for spec in t.get("etres", []):
		for k in rng.randi_range(int(spec[1]), int(spec[2])):
			var ou: Vector2i = sim._tuile_libre_autour(autour)
			if sim.grille.dans(ou):
				SimObjets.ajouter(sim, str(spec[0]), ou, "ia")
				n_etres += 1
	if t.has("betes"):
		var biome := str(sim.monde.surface.resume_cellule(cell).get("biome", ""))
		var liste: Array = (c.get("betes_par_biome", {}) as Dictionary).get(biome, c.get("betes_par_biome", {}).get("_defaut", ["loup"]))
		var bete := str(liste[rng.randi_range(0, liste.size() - 1)])
		for k in rng.randi_range(int(t.betes[0]), int(t.betes[1])):
			var ou2: Vector2i = sim._tuile_libre_autour(autour)
			if sim.grille.dans(ou2) and GameData.catalogues.creatures.has(bete):
				SimObjets.ajouter(sim, bete, ou2, "ia")
				n_etres += 1
	var params := {"nom": e.name_key, "n": n_etres}
	if choisi == "lieu":
		var tc := int(sim.monde.taille)
		var proche := {}
		var dmin := 999999
		var s0 := Lieux.secteur_de_tuile(e.pos, tc)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				for l in sim.monde.surface.lieux().secteur(s0 + Vector2i(dx, dy)):
					if sim.monde.lieux_connus.has(str(l.id)):
						continue
					var dl: int = Grille.distance(e.pos, l.centre)
					if dl < dmin:
						dmin = dl
						proche = l
		if not proche.is_empty():
			sim.monde.lieux_connus[str(proche.id)] = true
			var cl := Vector2i(floori(float(proche.centre.x) / tc), floori(float(proche.centre.y) / tc))
			params["lieu"] = "lieu.sous_type." + str(proche.sous_type)
			params["x"] = cl.x
			params["y"] = cl.y
	EventBus.emettre(&"journal", [StringName("journal.rencontre_" + choisi), params])
	return choisi
