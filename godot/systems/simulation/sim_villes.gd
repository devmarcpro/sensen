class_name SimVilles
extends RefCounted
## Les villes : le jour du calendrier (marché, fêtes), les transports (B4), les étages des bâtiments (99), le peuplement d'une agglomération, ses champs et ses bêtes.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


## Le jour de jeu écoulé (les donjons de corruption s'y accrochent — designer, point 51).
static func jour_courant(sim: Simulation) -> int:
	return int(sim.horloge_monde.ticks / maxi(1, int(SimTerrain._cycle(sim).ticks_par_jour)))


## La date du calendrier (Un monde réel — A) : une lecture du jour courant.
static func date_courante(sim: Simulation) -> Dictionary:
	return Calendrier.date(jour_courant(sim))


static func annee_courante(sim: Simulation) -> int:
	return int(date_courante(sim).annee)


## Est-ce le jour de marché de l'agglomération d'un PNJ ? (Calendrier : un jour de la semaine tiré du nom du village)
static func jour_de_marche_de(sim: Simulation, pnj: Dictionary) -> bool:
	var nom := str(pnj.get("village", ""))
	return sim.monde != null and sim.lieu == "camp" and not nom.is_empty() and Calendrier.jour_de_marche(nom) == str(date_courante(sim).jour_semaine)


## Une fête aujourd'hui pour ce PNJ (sa culture de nommage) ?
static func fete_de(sim: Simulation, pnj: Dictionary) -> Array:
	if sim.monde == null or sim.lieu != "camp":
		return []
	return Calendrier.fetes_du_jour(date_courante(sim), str(pnj.get("social", {}).get("culture", "")))


## Le client qui vide son journal au chargement redemande la date du jour : le prochain tick du monde la redit
## (l'humeur des fêtes et le regarnissage des marchés sont gardés par leurs propres marques, rien n'est redonné).
static func annoncer_jour(sim: Simulation) -> void:
	sim._jour_annonce = -1


## Un nouveau jour du calendrier (Un monde réel — A) : le journal dit la date, les fêtes du jour donnent leur
## humeur aux civils de la culture, les marchés du jour regarnissent leurs étals.
static func _nouveau_jour(sim: Simulation, jour: int) -> void:
	sim._jour_annonce = jour
	var d := Calendrier.date(jour)
	EventBus.emettre(&"journal", [&"journal.date", {"date": Calendrier.texte(d)}])
	var fc: Dictionary = GameData.config("calendrier").fetes
	var dites := {}
	for f in Calendrier.fetes_du_jour(d, ""):   # une fête commune se dit même sans personne autour
		dites[str(f.id)] = true
		EventBus.emettre(&"journal", [&"journal.fete", {"fete": "calendrier.fete." + str(f.id)}])
	for x in sim.vivants():
		if x.camp != "civil" or x.controle != "ia" or int(x.get("fete_jour", -1)) == jour:
			continue
		for f in Calendrier.fetes_du_jour(d, str(x.get("social", {}).get("culture", ""))):
			x["fete_jour"] = jour
			x["humeur"] = clampi(int(x.get("humeur", SimTerritoire._ry(sim).humeur_base)) + int(fc.humeur), 0, 100)
			if not dites.has(str(f.id)):
				dites[str(f.id)] = true
				EventBus.emettre(&"journal", [&"journal.fete", {"fete": "calendrier.fete." + str(f.id)}])
	if sim.lieu == "camp":
		SimTerritoire._caravanes_du_jour(sim, jour)   # les marchands itinérants des villes reliées (Villes B3)
	for nom in sim.monde.villages.keys():
		var info: Dictionary = sim.monde.villages[nom]
		if Calendrier.jour_de_marche(str(nom)) != str(d.jour_semaine) or not sim.monde.peuplees.has(info.cellule) or bool(info.get("abandonne", false)):
			continue
		var marchands := 0
		for x in SimRoyaumes.population_village(sim, str(nom)):
			if _garnir_marche(sim, x):
				marchands += 1
		if marchands > 0:
			EventBus.emettre(&"journal", [&"journal.marche", {"village": nom}])


## Le jour de marché, un marchand regarnit son étal jusqu'à `marche.stock_mult` fois son garnissage (Calendrier).
static func _garnir_marche(sim: Simulation, x: Dictionary) -> bool:
	var selection: Array = []
	if not str(x.get("boutique", "")).is_empty():
		selection = GameData.entree("shop_types", str(x.boutique)).selection
	else:
		selection = GameData.entree("creatures", str(x.get("def", ""))).get("stock_marchand", [])
	if selection.is_empty():
		return false
	var plafond := int(ceil(float(GameData.config("calendrier").marche.stock_mult) * float(x.get("stock_garni", 0))))
	if x.get("stock", []).size() < plafond:
		SimObjets._garnir_stock(sim, x, selection)
	return true


static func _transports(sim: Simulation) -> Dictionary:
	return GameData.config("villes").get("transports", {})


## Les trains aux heures du calendrier et la calèche du jour, pour chaque ville chargée qui a de quoi.
static func _tiquer_transports(sim: Simulation, tick: int) -> void:
	if sim.monde == null or sim.lieu != "camp":
		return
	var tcfg := _transports(sim)
	if tcfg.is_empty():
		return
	var jour := jour_courant(sim)
	var h := int(SimTerrain.heure(sim, tick))
	for nom in sim.territoires.keys():
		var t: Dictionary = sim.territoires[nom]
		if str(nom) == "joueur" or not t.has("agglomeration") or not SimTerritoire._territoire_charge(sim, str(nom)):
			continue
		var centre: Vector2i = t.agglomeration.get("centre", Vector2i(-99999, -99999))
		if absi(centre.x - sim.monde.centre.x) > sim.monde.rayon or absi(centre.y - sim.monde.centre.y) > sim.monde.rayon:
			continue
		var v: Dictionary = sim.monde.cellule(centre).get("village", {})
		var tr_c: Dictionary = tcfg.get("trains", {})
		if v.has("quai") and v.has("entrees_rail") and (h in tr_c.get("horaires", [])) and str(t.get("train_cle", "")) != "%d_%d" % [jour, h]:
			t["train_cle"] = "%d_%d" % [jour, h]
			_faire_venir_train(sim, str(nom), centre, v)
		var ca: Dictionary = tcfg.get("caleches", {})
		if str(t.agglomeration.get("palier", "")) in ca.get("paliers", []) and int(t.get("caleche_jour", -1)) != jour and h >= int(ca.get("heure_debut", 7)) and h < int(ca.get("heure_fin", 21)):
			t["caleche_jour"] = jour
			_faire_venir_caleche(sim, str(nom), t)


## Le train entre par le rail du bord, roule jusqu'au quai, attend, repart.
static func _faire_venir_train(sim: Simulation, nom: String, centre: Vector2i, v: Dictionary) -> Dictionary:
	var tr_c: Dictionary = _transports(sim).trains
	var entree: Vector2i = sim.monde.pos_monde(centre, v.entrees_rail[0])
	var quai: Vector2i = sim.monde.pos_monde(centre, v.quai)
	var pos := entree if sim.grille.dans(entree) and sim.grille.occupant(entree).is_empty() and not sim.grille.bloque_passage(entree) else sim._tuile_libre_autour(entree)
	if not sim.grille.dans(pos) or not sim.grille.occupant(pos).is_empty():
		return {}
	var x: Dictionary = SimObjets.ajouter(sim, str(tr_c.creature), pos, "ia")
	if x.is_empty():
		return {}
	x.camp = "civil"
	x["village"] = nom
	x.ancre = quai
	x["vehicule_etat"] = {"type": "train", "ville": nom, "quai": quai, "entree": entree, "etat": "arrive", "attente_jusqua": 0}
	EventBus.emettre(&"journal", [&"journal.train_arrive", {"ville": nom}])
	return x


## La calèche du jour : le tour des places des quartiers chargés, une attente à chacune.
static func _faire_venir_caleche(sim: Simulation, nom: String, t: Dictionary) -> Dictionary:
	var ca: Dictionary = _transports(sim).caleches
	var places: Array = []
	var quartiers: Array = []
	for cell in t.cellules.keys():
		if absi(cell.x - sim.monde.centre.x) > sim.monde.rayon or absi(cell.y - sim.monde.centre.y) > sim.monde.rayon:
			continue
		var v: Dictionary = sim.monde.cellule(cell).get("village", {})
		if v.has("centre"):
			places.append(sim.monde.pos_monde(cell, v.centre))
			quartiers.append(str(v.get("quartier", "centre")))
	if places.size() < 2:
		return {}
	var pos: Vector2i = sim._tuile_libre_autour(places[0] + Vector2i(2, 2))
	if not sim.grille.dans(pos) or not sim.grille.occupant(pos).is_empty():
		return {}
	var x: Dictionary = SimObjets.ajouter(sim, str(ca.creature), pos, "ia")
	if x.is_empty():
		return {}
	x.camp = "civil"
	x["village"] = nom
	x.ancre = pos
	x["vehicule_etat"] = {"type": "caleche", "ville": nom, "places": places, "quartiers": quartiers, "index": 1, "etat": "vers", "attente_jusqua": 0}
	EventBus.emettre(&"journal", [&"journal.caleche_arrive", {"ville": nom}])
	return x


## L'itinéraire d'un véhicule : le train va au quai, attend, retourne au bord et disparaît ; la calèche boucle
## sur les places jusqu'au soir.
static func _ia_vehicule(sim: Simulation, e: Dictionary, tick: int) -> void:
	var v: Dictionary = e.vehicule_etat
	var tcfg := _transports(sim)
	if str(v.type) == "train":
		match str(v.etat):
			"arrive":
				if e.pos == v.quai or (Grille.distance(e.pos, v.quai) <= 1 and (not sim.grille.occupant(v.quai).is_empty() or sim.grille.bloque_passage(v.quai))):
					v.etat = "attend"
					v.attente_jusqua = tick + int(tcfg.trains.attente_ticks)
					sim._attendre(e, tick)
				else:
					sim._ia_pas_routine(e, v.quai, tick)
			"attend":
				if tick >= int(v.attente_jusqua):
					v.etat = "repart"
					EventBus.emettre(&"journal", [&"journal.train_part", {"ville": str(v.ville)}])
				sim._attendre(e, tick)
			_:
				if e.pos == v.entree or (Grille.distance(e.pos, v.entree) <= 1 and (not sim.grille.occupant(v.entree).is_empty() or sim.grille.bloque_passage(v.entree))):
					_retirer_vehicule(sim, e)
				else:
					sim._ia_pas_routine(e, v.entree, tick)
		return
	# La calèche.
	var ca: Dictionary = tcfg.caleches
	if int(SimTerrain.heure(sim, tick)) >= int(ca.get("heure_fin", 21)):
		_retirer_vehicule(sim, e)
		return
	var cible: Vector2i = v.places[int(v.index) % v.places.size()]
	if str(v.etat) == "attend":
		if tick >= int(v.attente_jusqua):
			v.etat = "vers"
			v.index = (int(v.index) + 1) % v.places.size()
		sim._attendre(e, tick)
		return
	if Grille.distance(e.pos, cible) <= 2:
		v.etat = "attend"
		v.attente_jusqua = tick + int(ca.attente_ticks)
		sim._attendre(e, tick)
	else:
		sim._ia_pas_routine(e, cible, tick)


static func _retirer_vehicule(sim: Simulation, e: Dictionary) -> void:
	if sim.entites.has(e.id):
		sim.grille.liberer(e.pos)
		sim.ordre.erase(e.id)
		sim.entites.erase(e.id)
	e.vivant = false


## Monter : dans un train à quai (vers une gare, `cellule`), dans une calèche (vers une place, `vers`), ou sur sa
## monture (un compagnon bête dont la fiche dit `monture`).
static func _monter(sim: Simulation, e: Dictionary, id: String, i: Dictionary, tick: int) -> bool:
	var v: Dictionary = sim.entites.get(id, {})
	if v.is_empty() or not v.vivant or Grille.distance(e.pos, v.pos) > 2:
		return false
	var tcfg := _transports(sim)
	if v.has("vehicule_etat"):
		var ve: Dictionary = v.vehicule_etat
		if str(ve.type) == "train":
			if str(ve.etat) != "attend" or not i.has("cellule"):
				return false
			var dest: Vector2i = i.cellule
			var d := Grille.distance(sim.monde.cellule_de(e.pos), dest)
			var prix := d * int(tcfg.trains.prix_par_cellule)
			if int(e.or) < prix:
				EventBus.emettre(&"journal", [&"journal.transport_or", {"prix": prix}])
				return false
			e.or = int(e.or) - prix
			var nom_dest := str(sim.monde.surface.fiche_agglomeration(dest).get("nom", ""))
			EventBus.emettre(&"journal", [&"journal.train_voyage", {"nom": e.name_key, "ville": nom_dest, "prix": prix}])
			if not SimCamp.voyager(sim, e, dest, d * int(tcfg.trains.ticks_par_cellule)):
				return false
			var vd: Dictionary = sim.monde.cellule(dest).get("village", {})
			if vd.has("quai"):   # on descend sur le quai
				var q: Vector2i = sim._tuile_libre_autour(sim.monde.pos_monde(dest, vd.quai))
				if sim.grille.dans(q) and sim.grille.occupant(q).is_empty():
					sim.grille.liberer(e.pos)
					e.pos = q
					sim.grille.placer(e.id, q)
					sim.maj_vision()
			return true
		if str(ve.type) == "caleche":
			if not i.has("vers"):
				return false
			var prix_c := int(tcfg.caleches.prix_par_quartier)
			if int(e.or) < prix_c:
				EventBus.emettre(&"journal", [&"journal.transport_or", {"prix": prix_c}])
				return false
			var q2: Vector2i = sim._tuile_libre_autour(Vector2i(i.vers))
			if not sim.grille.dans(q2) or not sim.grille.occupant(q2).is_empty():
				return false
			e.or = int(e.or) - prix_c
			sim.grille.liberer(e.pos)
			e.pos = q2
			sim.grille.placer(e.id, q2)
			e.compteur = tick + int(tcfg.caleches.get("ticks_trajet", 120))
			sim.maj_vision()
			EventBus.emettre(&"journal", [&"journal.caleche_voyage", {"nom": e.name_key, "prix": prix_c}])
			return true
		return false
	# Une monture.
	if str(v.get("maitre", "")) != e.id or not bool(GameData.catalogues.creatures.get(str(v.def), {}).get("monture", false)) or e.has("monture"):
		return false
	sim.grille.liberer(v.pos)
	sim.ordre.erase(v.id)
	sim.entites.erase(v.id)
	e["monture"] = {"id": v.id, "etre": v, "nom": v.name_key}
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.monte", {"nom": e.name_key, "monture": v.name_key}])
	return true


## Descendre de sa monture : elle reprend sa place à côté.
static func _descendre_monture(sim: Simulation, e: Dictionary, tick: int) -> bool:
	if not e.has("monture"):
		return false
	var v: Dictionary = e.monture.etre
	var q: Vector2i = sim._tuile_libre_autour(e.pos)
	if not sim.grille.dans(q) or not sim.grille.occupant(q).is_empty():
		return false
	v.pos = q
	v.ancre = q
	v.compteur = tick
	v.horloge = e.horloge
	v.vivant = true
	sim.entites[v.id] = v
	if not (v.id in sim.ordre):
		sim.ordre.append(v.id)
	sim.grille.placer(v.id, q)
	e.erase("monture")
	EventBus.emettre(&"journal", [&"journal.descend", {"nom": e.name_key, "monture": v.name_key}])
	return true


## Acheter une monture au maquignon de l'écurie : un cheval apprivoisé, compagnon.
static func _acheter_monture(sim: Simulation, e: Dictionary, id: String, tick: int) -> bool:
	var pnj: Dictionary = sim.entites.get(id, {})
	if pnj.is_empty() or not ("maquignon" in pnj.get("tags", [])) or Grille.distance(e.pos, pnj.pos) > 2:
		return false
	var mo: Dictionary = _transports(sim).montures
	var prix := int(mo.prix_monture)
	if int(e.or) < prix:
		EventBus.emettre(&"journal", [&"journal.transport_or", {"prix": prix}])
		return false
	if SimPnj.compagnons_de(sim, e).size() >= SimPnj.places_escorte(sim, e):
		EventBus.emettre(&"journal", [&"journal.pas_de_place", {}])
		return false
	var q: Vector2i = sim._tuile_libre_autour(e.pos)
	if not sim.grille.dans(q) or not sim.grille.occupant(q).is_empty():
		return false
	var x: Dictionary = SimObjets.ajouter(sim, str(mo.creature_vendue), q, "ia")
	if x.is_empty():
		return false
	e.or = int(e.or) - prix
	pnj.or = int(pnj.or) + prix
	SimPnj._devenir_compagnon(sim, e, x)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.monture_achetee", {"nom": e.name_key, "monture": x.name_key, "prix": prix}])
	return true


# ---------------------------------------------------------------- l'économie des villes (Villes — B3, 2026-09-05)

# Les étages des bâtiments ne sont plus un intérieur chargé à part (décision du 2026-09-05, annulée le 2026-09-06, 16 h :
# « changer d'étage change juste la dimension Z du monde ») : ils sont les couches Z de la fenêtre (Monde._poser_etages),
# l'escalier un lien entre deux tuiles (Grille.poser_lien), monter un pas (Simulation._deplacer).


## Peuple les cellules d'agglomération de la fenêtre à leur première visite (Villes B1) : les gens, puis le
## territoire de la ville — ses cellules à rôle, ses périmètres, ses stockages — dans son contexte. « Un camp et
## une ville sont identiques » : chaque habitant est un résident assigné, logé, à son poste.
static func _peupler_fenetre(sim: Simulation) -> void:
	if sim.monde == null:
		return
	var cfg: Dictionary = GameData.config("villes")
	for dy in range(-sim.monde.rayon, sim.monde.rayon + 1):
		for dx in range(-sim.monde.rayon, sim.monde.rayon + 1):
			var cell: Vector2i = sim.monde.centre + Vector2i(dx, dy)
			if sim.monde.peuplees.has(cell):
				continue
			var e := sim.monde.cellule(cell)
			var v: Dictionary = e.get("village", {})
			if v.is_empty():
				continue
			sim.monde.peuplees[cell] = true
			var nom := str(v.nom)
			var palier := str(v.get("palier", "hameau"))
			var t: Dictionary = SimTerritoire.creer_territoire(sim, nom, str(v.get("royaume", "")), int(cfg.tresor_depart.get(palier, 0)))
			if not t.has("agglomeration"):
				t["agglomeration"] = {"palier": palier, "population": int(v.get("population", v.pnj.size())), "centre": v.get("cellule_centre", cell), "culture": str(v.get("culture", "")), "gouvernance": str(v.get("gouvernance", ""))}
			t.cellules[cell] = {"role": str(v.get("territoire", {}).get("role", "habitation"))}
			var pids: Array = SimTerritoire._dans_territoire(sim, nom, func() -> Array: return _creer_perimetres_ville(sim, cell, v))
			var pid_res := ""
			for k in pids.size():
				if str(v.territoire.perimetres[k].type) == "residentiel" and not str(pids[k]).is_empty():
					pid_res = str(pids[k])
					break
			for pj in v.pnj:
				var pos: Vector2i = sim.monde.pos_monde(cell, pj.pos)
				if not sim.grille.occupant(pos).is_empty() or sim.grille.bloque_passage(pos):
					pos = sim._tuile_libre_autour(pos)
				if str(pj.get("batiment", "")) == "ecurie":
					pass
				if not sim.grille.dans(pos) or not sim.grille.occupant(pos).is_empty():
					continue
				var x: Dictionary = SimObjets.ajouter(sim, str(pj.creature), pos, "ia")
				if x.is_empty():
					continue
				if pj.has("fonction"):
					x.fonction = str(pj.fonction)
				SimObjets._habiller_pnj(sim, x, GameData.entree("creatures", str(pj.creature)), str(v.culture))
				if not str(pj.get("boutique", "")).is_empty():   # une boutique typée : les catégories du type
					x["boutique"] = str(pj.boutique)
					x.stock = []
					SimObjets._garnir_stock(sim, x, GameData.entree("shop_types", str(pj.boutique)).selection)
				if not str(pj.get("guilde", "")).is_empty():
					x["guilde"] = str(pj.guilde)
				x["lit"] = sim.monde.pos_monde(cell, pj.lit)
				x["poste"] = sim.monde.pos_monde(cell, pj.get("poste", pj.pos))
				x["place"] = sim.monde.pos_monde(cell, v.centre)
				x["village"] = nom
				x["royaume"] = str(v.get("royaume", ""))
				x.ancre = x.poste
				if str(pj.get("batiment", "")) == "ecurie" and not ("maquignon" in x.tags):
					x.tags.append("maquignon")   # il vend des montures (Villes B4)
				if x.ai_profile == "garde" and not str(v.get("royaume", "")).is_empty():
					var etat_r: Dictionary = SimRoyaumes.etat_royaume(sim, str(v.royaume))
					if not etat_r.is_empty():
						x["blason"] = str(etat_r.blason.couleurs[0])   # le garde porte la couleur de son royaume (D)
				# Le résident du territoire (Villes B0/B1) : assigné à sa fonction, logé au résidentiel, ouvrier d'une zone.
				var fonction := str(x.get("fonction", "oisif"))
				if not GameData.catalogues.functions.has(fonction):
					fonction = "oisif"
				x["fonction"] = fonction
				x["role"] = "resident"
				x["assignation"] = {"fonction": fonction, "cellule": cell, "territoire": nom}
				if not pid_res.is_empty():
					x.assignation["residence"] = pid_res
				if pj.has("perimetre") and int(pj.perimetre) < pids.size() and not str(pids[int(pj.perimetre)]).is_empty():
					var pid_z := str(pids[int(pj.perimetre)])
					x.assignation["perimetre"] = pid_z
					var poste_p: Vector2i = SimTerritoire._dans_territoire(sim, nom, func() -> Vector2i: return SimPerimetres._poste_de_perimetre(sim, pid_z, x.pos))
					if poste_p != Vector2i(-1, -1):
						x.poste = poste_p
						x.ancre = poste_p
			# Les champs semés et les bêtes de l'enclos (Villes B2).
			SimTerritoire._dans_territoire(sim, nom, func() -> void: _semer_champs_ville(sim, cell, v))
			var en: Dictionary = cfg.get("enclos", {})
			for bt in v.get("betes", []):
				var pos_b: Vector2i = sim.monde.pos_monde(cell, bt.pos)
				if not sim.grille.dans(pos_b) or sim.grille.bloque_passage(pos_b) or not sim.grille.occupant(pos_b).is_empty() or not GameData.catalogues.creatures.has(str(bt.espece)):
					continue
				var bete: Dictionary = SimObjets.ajouter(sim, str(bt.espece), pos_b, "ia")
				if bete.is_empty():
					continue
				bete.camp = "civil"
				bete.ai_profile = str(en.get("profil", "proie"))
				bete["statut_habitat"] = "betail"
				bete["betail"] = nom
				bete["village"] = nom
				bete.ancre = pos_b
			if not sim.monde.villages.has(nom):
				sim.monde.villages[nom] = {"cellule": v.get("cellule_centre", cell), "royaume": str(v.get("royaume", "")), "conquis_par": "", "defense_jusqua": 0, "abandonne": false, "capacite": int(v.get("population", v.pnj.size()))}
			SimRoyaumes._former_familles(sim, cell, v)
			EventBus.emettre(&"journal", [&"journal.ville", {"palier": "palier." + palier, "nom": nom, "quartier": "quartier." + str(v.get("quartier", "centre")), "population": int(v.get("population", v.pnj.size()))}])


## Les champs d'un quartier, semés dans le territoire de sa ville à des stades de pousse divers (Villes B2).
static func _semer_champs_ville(sim: Simulation, cell: Vector2i, v: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "champs", cell])
	for champ in v.get("champs", []):
		var de_saison := plante_a_semer(sim, champ, sim.horloge_monde.ticks)   # ce qui se sème en cette saison (rotation)
		for q in champ.tuiles:
			var p: Vector2i = sim.monde.pos_monde(cell, q)
			if not sim.grille.dans(p) or not sim.grille.contenu_de(p).is_empty() or sim.grille.meubles.has(sim.grille.idx(p)) or not sim.grille.occupant(p).is_empty() or sim.territoire.cultures.has(SimCamp._pm(sim, p)):
				continue
			if de_saison.is_empty():
				continue   # l'hiver : les champs de la ville sont nus
			var contenus_c := {"contenu": str(GameData.config("villes").get("vergers", {}).get("contenu", "verger")), "contenu_mur": str(GameData.config("villes").get("vergers", {}).get("contenu_mur", "verger_mur"))} if bool(champ.get("verger", false)) else {}
			_semer_tuile(sim, p, de_saison, sim.horloge_monde.ticks, rng.randf_range(0.0, 0.9), contenus_c)


## Semer une tuile du territoire courant : la parcelle, son échéance (déjà avancée de `avancement`), le contenu.
## Hors de ses saisons (Agriculture et élevage, 2026-09-06), une culture met `hors_saison.duree` fois plus longtemps :
## la parcelle garde `hors_saison` et son rendement en pâtira.
static func _semer_tuile(sim: Simulation, vers: Vector2i, base: String, tick: int, avancement: float = 0.0, champ: Dictionary = {}) -> void:
	var pl: Dictionary = GameData.catalogues.plants[base]
	var hs: Dictionary = GameData.config("villes").get("champs", {}).get("hors_saison", {})
	var dans_saison := est_de_saison(sim, base, tick)
	var duree := float(pl.duree_jours) * float(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
	if not dans_saison:
		duree *= float(hs.get("duree", 1.8))
	var jeune := str(champ.get("contenu", "culture"))
	sim.territoire.cultures[SimCamp._pm(sim, vers)] = {"plante": base, "semis": tick - int(duree * avancement), "echeance": tick + int(duree * (1.0 - avancement)), "mure": false, "hors_saison": not dans_saison, "mur_id": str(champ.get("contenu_mur", "culture_mure"))}
	sim.grille.poser_contenu(vers, jeune)
	sim.grille.marquer(vers)


## Une culture est-elle de saison ? (sa fiche `saisons` ; une plante sans saisons pousse toute l'année sauf l'hiver)
static func est_de_saison(sim: Simulation, base: String, tick: int = -1) -> bool:
	var saison := SimTerrain.saison(sim, tick)
	var hs: Dictionary = GameData.config("villes").get("champs", {}).get("hors_saison", {})
	if saison in hs.get("saisons_sans_semis", ["hiver"]):
		return false
	var sa: Array = GameData.catalogues.plants.get(base, {}).get("saisons", [])
	return sa.is_empty() or (saison in sa)


## La culture à semer dans un champ : de saison d'abord, différente de la précédente (rotation), parmi celles du champ.
static func plante_a_semer(sim: Simulation, champ: Dictionary, tick: int = -1) -> String:
	if bool(champ.get("verger", false)):
		return str(champ.get("plante", champ.get("derniere_plante", "")))   # un verger ne tourne pas : on replante le même buisson
	var liste: Array = champ.get("cultures", [str(champ.get("plante", ""))])
	if liste.is_empty():
		return str(champ.get("plante", ""))
	var derniere := str(champ.get("derniere_plante", ""))
	var de_saison: Array[String] = []
	for c in liste:
		if est_de_saison(sim, str(c), tick):
			de_saison.append(str(c))
	if de_saison.is_empty():
		return ""   # rien de cette liste ne se sème maintenant (l'hiver) : le champ attend
	var autres: Array[String] = []
	for c in de_saison:
		if c != derniere:
			autres.append(c)
	var final: Array[String] = autres
	if final.is_empty():
		final = de_saison
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "rotation", champ.get("rect", Rect2i()), int(champ.get("recoltes", 0))])
	return final[rng.randi_range(0, final.size() - 1)]


## Un champ est-il irrigué : une tuile d'eau à `irrigation.distance` de son rectangle (Agriculture et élevage, 2026-09-06).
static func champ_irrigue(sim: Simulation, tuiles: Array) -> bool:
	var d := int(GameData.config("villes").get("champs", {}).get("irrigation", {}).get("distance", 3))
	var g: Grille = sim.grille
	for q in tuiles:
		var p: Vector2i = q if q is Vector2i else Vector2i(q)
		for dy in range(-d, d + 1):
			for dx in range(-d, d + 1):
				var t := p + Vector2i(dx, dy)
				if g.dans(t) and ("liquide" in g.contenu_de(t).get("tags", []) or g.niveau_liquide(t) > 0):
					return true
	return false


## Le rendement hebdomadaire abstrait d'une parcelle mûre : base × rendement du biome × fertilité, × saison, × rotation,
## × irrigation, × canicule (une parcelle irriguée tient la canicule — Agriculture et élevage, 2026-09-06).
static func _rendement_parcelle(sim: Simulation, pm: Vector2i, champ: Dictionary = {}) -> int:
	var c: Dictionary = sim.territoire.cultures.get(pm, {})
	var cell: Vector2i = SimCamp._cell_de(sim, pm)
	var fy := float(GameData.catalogues.biomes.get(str(sim.monde.cellule(cell).get("biome", "")), {}).get("farming_yield", 1.0))
	var pl: Dictionary = GameData.catalogues.plants[str(c.plante)]
	var cfg: Dictionary = GameData.config("villes").get("champs", {})
	var q := float(pl.recolte_base) * fy * (0.5 + float(SimCamp.fertilite_a(sim, pm, pm)) / 100.0)
	if bool(c.get("hors_saison", false)):
		q *= float(cfg.get("hors_saison", {}).get("rendement", 0.45))
	if not champ.is_empty() and str(champ.get("derniere_plante", "")) != "" and str(champ.derniere_plante) != str(c.plante):
		q *= 1.0 + float(cfg.get("rotation_bonus", 0.2))   # la rotation : une autre culture que la précédente
	var irrigue := bool(champ.get("irrigue", false))
	if irrigue:
		q *= 1.0 + float(cfg.get("irrigation", {}).get("bonus", 0.35)) * float(pl.get("besoin_eau", 0.5))
	if SimTerrain.meteo(sim, cell) == "canicule" and not irrigue:
		q *= float(SimTerritoire._ry(sim).agriculture.canicule_facteur)
	return maxi(1, roundi(q))


## Les fermiers des périmètres de champs récoltent les parcelles mûres du territoire et les ressèment (Villes B2) —
## pour le camp comme pour la ville, à concurrence d'un quota par fermier.
static func _recolter_champs(sim: Simulation) -> void:
	var cfg: Dictionary = GameData.config("villes").get("champs", {})
	var types: Dictionary = SimTerritoire._ry(sim).get("perimetres", {}).get("types", {})
	var quota := 0
	for x in SimTerritoire.residents(sim):
		var per: Dictionary = SimPerimetres.perimetres(sim).get(str(x.assignation.get("perimetre", "")), {})
		if not per.is_empty() and bool(types.get(str(per.type), {}).get("champs", false)):
			quota += int(cfg.get("tuiles_par_fermier_semaine", 30))
	if quota <= 0:
		return
	var recoltes := {}
	var total := 0
	var tick := sim.horloge_monde.ticks
	# Le champ de chaque parcelle (son périmètre) : sa rotation, sa jachère et son irrigation valent pour toutes ses tuiles.
	var champ_de := {}   # position monde → le périmètre de champs qui la couvre
	for pid in SimPerimetres.perimetres(sim).keys():
		var pr: Dictionary = SimPerimetres.perimetres(sim)[pid]
		if not bool(types.get(str(pr.type), {}).get("champs", false)):
			continue
		for pos in SimPerimetres.tuiles_de_perimetre(sim, str(pid)):   # les tuiles d'un périmètre sont LOCALES : la fonction les rend en monde
			champ_de[pos] = pr
	for pm in sim.territoire.cultures.keys():
		if quota <= 0:
			break
		var c: Dictionary = sim.territoire.cultures[pm]
		var champ: Dictionary = champ_de.get(pm, {})
		if not champ.is_empty() and int(champ.get("jachere_jusqua", 0)) > tick:
			continue   # la terre se repose
		if not sim.grille.dans(pm):   # hors fenêtre (anneau moyen, 2026-09-06) : la parcelle rend au forfait, sans pousser à l'heure
			var am: Dictionary = GameData.config("villes").get("anneau_moyen", {})
			c["semaines_hors"] = int(c.get("semaines_hors", 0)) + 1
			if int(c.semaines_hors) < int(am.get("semaines_par_recolte", 3)):
				continue
			c.semaines_hors = 0
			var n_h := int(am.get("rendement_par_parcelle", 4))
			var cle_h := str(c.plante)
			sim.territoire.stocks[cle_h] = int(sim.territoire.stocks.get(cle_h, 0)) + n_h
			recoltes[cle_h] = int(recoltes.get(cle_h, 0)) + n_h
			total += n_h
			quota -= 1
			continue
		if not bool(c.get("mure", false)):
			continue
		var n := _rendement_parcelle(sim, pm, champ)
		var cle := str(c.plante)
		sim.territoire.stocks[cle] = int(sim.territoire.stocks.get(cle, 0)) + n
		recoltes[cle] = int(recoltes.get(cle, 0)) + n
		total += n
		quota -= 1
		if champ.is_empty():   # une parcelle du joueur, hors champ : on ressème la même chose
			_semer_tuile(sim, pm, str(c.plante), tick)
			continue
		# La terre s'épuise à chaque récolte (Agriculture et élevage, 2026-09-06) ; la jachère la rendra.
		var ja: Dictionary = cfg.get("jachere", {})
		sim.territoire.fertilite[pm] = clampi(SimCamp.fertilite_a(sim, pm, pm) - int(ja.get("fertilite_par_recolte", 3)), int(ja.get("fertilite_min", 15)), int(ja.get("fertilite_max", 95)))
		champ["derniere_plante"] = str(c.plante)
		var suivante := plante_a_semer(sim, champ, tick)
		if suivante.is_empty():   # rien ne se sème en cette saison : la parcelle reste nue jusqu'au printemps
			sim.territoire.cultures.erase(pm)
			if sim.grille.dans(pm):
				sim.grille.poser_contenu(pm, "")
				sim.grille.marquer(pm)
			continue
		_semer_tuile(sim, pm, suivante, tick, 0.0, champ)
	_jacheres(sim, types, tick)
	if total > 0:
		var noms: Array[String] = []
		for cle in recoltes.keys():
			noms.append("%s ×%d" % [TranslationServer.translate(str(GameData.catalogues.plants.get(str(cle), {}).get("name_key", str(cle)))), int(recoltes[cle])])
		EventBus.emettre(&"journal", [&"journal.recolte_champs", {"n": total, "plantes": " · ".join(noms)}])


## La jachère (Agriculture et élevage, 2026-09-06) : un champ qui a donné `recoltes_avant_jachere` fois se repose
## `jours_jachere` jours — ses parcelles redeviennent de la terre nue et sa fertilité remonte ; au bout du repos, il se
## ressème de lui-même, de saison, en changeant de culture.
static func _jacheres(sim: Simulation, types: Dictionary, tick: int) -> void:
	var cfg: Dictionary = GameData.config("villes").get("champs", {})
	var ja: Dictionary = cfg.get("jachere", {})
	var jour := int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
	for pid in SimPerimetres.perimetres(sim).keys():
		var pr: Dictionary = SimPerimetres.perimetres(sim)[pid]
		if not bool(types.get(str(pr.type), {}).get("champs", false)) or not pr.has("tuiles"):
			continue
		if bool(pr.get("verger", false)):
			continue   # un verger ne se repose pas : on ne laboure pas un framboisier
		var fin := int(pr.get("jachere_jusqua", 0))
		if fin > tick:
			continue
		if fin > 0:   # le repos s'achève : la terre a repris des forces, on ressème
			pr["jachere_jusqua"] = 0
			pr["recoltes"] = 0
			var suivante := plante_a_semer(sim, pr, tick)
			for pm in SimPerimetres.tuiles_de_perimetre(sim, str(pid)):
				sim.territoire.fertilite[pm] = clampi(SimCamp.fertilite_a(sim, pm, pm) + int(ja.get("fertilite_rendue", 12)), int(ja.get("fertilite_min", 15)), int(ja.get("fertilite_max", 95)))
				if not suivante.is_empty() and sim.grille.dans(pm) and sim.grille.contenu_de(pm).is_empty() and not sim.territoire.cultures.has(pm):
					_semer_tuile(sim, pm, suivante, tick, 0.0, pr)
			continue
		pr["recoltes"] = int(pr.get("recoltes", 0)) + 1
		if int(pr.recoltes) < int(ja.get("recoltes_avant_jachere", 4)):
			continue
		pr["jachere_jusqua"] = tick + int(ja.get("jours_jachere", 30)) * jour   # la terre se repose
		for pm2 in SimPerimetres.tuiles_de_perimetre(sim, str(pid)):
			sim.territoire.cultures.erase(pm2)
			if sim.grille.dans(pm2) and "culture" in sim.grille.contenu_de(pm2).get("tags", []):
				sim.grille.poser_contenu(pm2, "")
				sim.grille.marquer(pm2)


## Le troupeau du territoire, chaque semaine (Villes B2 ; le troupeau qui vit, 2026-09-06) : il mange le fourrage des
## stocks, il produit (à sa saison), il naît, il meurt de faim, et son surplus part à la boucherie.
static func _semaine_betail(sim: Simulation) -> void:
	var cfg: Dictionary = GameData.config("villes").get("enclos", {})
	var produits: Dictionary = cfg.get("produits", {})
	var tr: Dictionary = cfg.get("troupeau", {})
	var tid := str(sim.territoire.get("id", "joueur"))
	var troupeaux := {}   # cellule → [bêtes] : un enclos par cellule, la capacité s'y applique
	var dormants_de := {}
	for x in sim.vivants():
		if x.vivant and str(x.get("betail", "")) == tid:
			var c: Vector2i = SimCamp._cell_de(sim, x.pos)
			troupeaux.get_or_add(c, []).append(x)
	if sim.monde != null:   # les bêtes endormies hors fenêtre vivent aussi (anneau moyen, 2026-09-06)
		for cell in sim.territoire.get("cellules", {}).keys():
			for x in sim.monde.dormants.get(cell, []):
				if x.vivant and str(x.get("betail", "")) == tid:
					troupeaux.get_or_add(cell, []).append(x)
					dormants_de[x.id] = cell
	var n_betes := 0
	for c in troupeaux:
		n_betes += (troupeaux[c] as Array).size()
	if n_betes == 0:
		return
	# 1. Le fourrage : le troupeau mange les cultures des stocks (le plus gros tas d'abord).
	var besoin := n_betes * int(tr.get("fourrage_par_bete", 1))
	var mange := 0
	var cles: Array = sim.territoire.stocks.keys().filter(func(k: Variant) -> bool: return GameData.catalogues.plants.has(str(k)))
	cles.sort_custom(func(a: Variant, b: Variant) -> bool: return int(sim.territoire.stocks[a]) > int(sim.territoire.stocks[b]))
	for cle in cles:
		if mange >= besoin:
			break
		var pris: int = mini(int(sim.territoire.stocks[cle]), besoin - mange)
		sim.territoire.stocks[cle] = int(sim.territoire.stocks[cle]) - pris
		if int(sim.territoire.stocks[cle]) <= 0:
			sim.territoire.stocks.erase(cle)
		mange += pris
	var rassasie := float(mange) / float(maxi(1, besoin))
	# 2. Les produits, à leur saison.
	var saison := SimTerrain.saison(sim)
	var prod := {}
	var total := 0
	for c in troupeaux:
		for x in troupeaux[c]:
			var p: Dictionary = produits.get(str(x.get("def", "")), {})
			if p.is_empty() or (p.has("saison") and str(p.saison) != saison):
				continue
			var cle := str(p.materiau) + "|brut"
			sim.territoire.stocks[cle] = int(sim.territoire.stocks.get(cle, 0)) + int(p.n)
			prod[str(p.materiau)] = int(prod.get(str(p.materiau), 0)) + int(p.n)
			total += int(p.n)
	if total > 0:
		var noms: Array[String] = []
		for m in prod.keys():
			noms.append("%s ×%d" % [TranslationServer.translate(str(GameData.catalogues.materials.get(str(m), {}).get("name_key", str(m)))), int(prod[m])])
		EventBus.emettre(&"journal", [&"journal.betail_produit", {"n": total, "produits": " · ".join(noms)}])
	# 3. La faim, les naissances, l'abattage du surplus — enclos par enclos.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "troupeau", sim.horloge_monde.ticks / 1000])
	var capacite := int(tr.get("capacite", 8))
	var naissances := 0
	var abattues := 0
	var mortes := 0
	for cell in troupeaux.keys():
		var betes: Array = troupeaux[cell]
		if rassasie < float(tr.get("famine_seuil", 0.5)) and not betes.is_empty():   # le troupeau a faim : une bête y reste
			var perdue: Dictionary = betes[rng.randi_range(0, betes.size() - 1)]
			_oter_bete(sim, perdue, dormants_de.get(perdue.id, Vector2i(-9999, -9999)))
			betes.erase(perdue)
			mortes += 1
			continue
		if rassasie < 1.0:
			continue   # nourri à moitié : ni naissance ni abattage, le troupeau se maintient
		var place := capacite - betes.size()
		if place > 0:
			var n_max: int = mini(place, int(tr.get("naissances_max_semaine", 2)))
			for x in betes:
				if naissances >= n_max:
					break
				if rng.randf() >= float(tr.get("naissance_chance", 0.12)):
					continue
				if _naitre_bete(sim, x, cell, dormants_de.has(x.id)):
					naissances += 1
		elif betes.size() > capacite:   # le surplus part à la boucherie : viande, cuir, suif
			for k in betes.size() - capacite:
				var b: Dictionary = betes[k]
				for cle_a in tr.get("abattage", {}).keys():
					var cle_s := str(cle_a) if GameData.catalogues.items.has(str(cle_a)) else str(cle_a) + "|brut"
					sim.territoire.stocks[cle_s] = int(sim.territoire.stocks.get(cle_s, 0)) + int(tr.abattage[cle_a])
				_oter_bete(sim, b, dormants_de.get(b.id, Vector2i(-9999, -9999)))
				abattues += 1
	if naissances > 0:
		EventBus.emettre(&"journal", [&"journal.betail_naissance", {"n": naissances}])
	if abattues > 0:
		EventBus.emettre(&"journal", [&"journal.betail_abattu", {"n": abattues}])
	if mortes > 0:
		EventBus.emettre(&"journal", [&"journal.betail_famine", {"n": mortes}])


## Une bête naît dans l'enclos de sa mère : dans la fenêtre, un être de plus ; hors fenêtre, un dormant de la cellule.
static func _naitre_bete(sim: Simulation, mere: Dictionary, cell: Vector2i, endormie: bool) -> bool:
	var espece := str(mere.get("def", ""))
	if espece.is_empty() or not GameData.catalogues.creatures.has(espece):
		return false
	var petit: Dictionary = {}
	if endormie or sim.monde == null:
		petit = SimObjets.instancier_endormi(sim, espece, mere.pos)
		if petit.is_empty():
			return false
		petit["dormant_depuis"] = sim.horloge_monde.ticks
		if sim.monde != null:
			sim.monde.dormants.get_or_add(cell, []).append(petit)
	else:
		var ou: Vector2i = sim._tuile_libre_autour(mere.pos)
		if ou == Vector2i(-1, -1) or not sim.grille.dans(ou):
			return false
		petit = SimObjets.ajouter(sim, espece, ou, "ia")
		if petit.is_empty():
			return false
	petit["ai_profile"] = str(mere.get("ai_profile", GameData.config("villes").get("enclos", {}).get("profil", "proie")))
	petit["statut_habitat"] = "betail"
	petit["betail"] = str(mere.get("betail", ""))
	petit["camp"] = str(mere.get("camp", "civil"))
	return true


## Une bête quitte le troupeau (abattue, morte de faim) : de la fenêtre ou des dormants de sa cellule.
static func _oter_bete(sim: Simulation, b: Dictionary, cell_dormante: Vector2i) -> void:
	if sim.monde != null and sim.monde.dormants.has(cell_dormante):
		(sim.monde.dormants[cell_dormante] as Array).erase(b)
		return
	b["vivant"] = false
	if sim.grille.dans(b.pos) and sim.grille.occupant(b.pos) == str(b.id):
		sim.grille.liberer(b.pos)


## Les périmètres d'un quartier, dans le contexte de sa ville : le résidentiel, les stockages des entrepôts, les
## zones de récolte ; chaque zone prend le premier stockage du quartier. Retourne les identifiants, dans l'ordre du plan.
static func _creer_perimetres_ville(sim: Simulation, cell: Vector2i, v: Dictionary) -> Array:
	var pids: Array = []
	var plan: Array = v.get("territoire", {}).get("perimetres", [])
	for per in plan:
		var pid := str(SimPerimetres.creer_perimetre(sim, cell, str(per.type), per.tuiles, true))
		pids.append(pid)
		if str(per.type) == "champs" and not pid.is_empty():   # la mémoire du champ : ses cultures, sa rotation, sa jachère, son eau
			var pr: Dictionary = SimPerimetres.perimetres(sim)[pid]
			pr["cultures"] = per.get("cultures", [str(per.get("plante", ""))]).duplicate()
			pr["derniere_plante"] = str(per.get("plante", ""))
			pr["recoltes"] = 0
			pr["jachere_jusqua"] = 0
			pr["irrigue"] = champ_irrigue(sim, per.tuiles.map(func(q: Variant) -> Vector2i: return sim.monde.pos_monde(cell, q)))
			if bool(per.get("verger", false)):   # un verger : ni rotation ni jachère, et ses tuiles à lui
				pr["verger"] = true
				pr["contenu"] = str(per.get("contenu", "verger"))
				pr["contenu_mur"] = str(per.get("contenu_mur", "verger_mur"))
	var pid_stock := ""
	for k in pids.size():
		if str(plan[k].type) == "stockage" and not str(pids[k]).is_empty():
			pid_stock = str(pids[k])
			break
	if not pid_stock.is_empty():
		for k in pids.size():
			if str(plan[k].type) in ["bois", "minerai", "plantes"] and not str(pids[k]).is_empty():
				SimPerimetres.perimetres(sim)[str(pids[k])]["stockage"] = pid_stock
	return pids


## Enterrer un habitant chez lui (Villes — les repères, 2026-09-07) : une tombe libre du cimetière de SA ville reçoit
## son nom, son métier et l'année, où qu'il soit tombé. Rend true si une tombe l'a reçu (le cimetière peut être plein,
## la ville hors fenêtre, ou le mort n'être de nulle part).
static func enterrer(sim: Simulation, mort: Dictionary) -> bool:
	var cfg: Dictionary = GameData.config("villes").get("reperes", {}).get("cimetiere", {})
	if not bool(cfg.get("enterrement", true)) or sim.monde == null:
		return false
	var village := str(mort.get("village", ""))
	if village.is_empty() or not ("civil" in mort.get("tags", [])):
		return false
	for cell in sim.monde.cellules.keys():
		var e: Dictionary = sim.monde.cellules[cell]
		var v: Dictionary = e.get("village", {})
		if v.is_empty() or str(v.get("nom", "")) != village or not v.has("cimetiere"):
			continue
		var taille: int = int(e.largeur)
		var r: Rect2i = v.cimetiere
		# Les tombes vivent dans le MONDE, pas dans la cellule (2026-09-07) : une cellule se régénère de sa graine à
		# chaque chargement, et n'en garderait rien. `monde.tombes` est sauvegardé, et la tuile est inscrite aux
		# modifications de la cellule — c'est ce que le rechargement rejoue.
		var tombes: Array = sim.monde.tombes.get(cell, [])
		var prises := {}
		for t_p in tombes:
			prises[Vector2i(t_p.tuile)] = true
		var nom_m := Noms.afficher(mort.get("nom", {})) if mort.has("nom") else str(mort.get("name_key", ""))
		for y in range(1, r.size.y - 1):   # l'intérieur seul : la clôture reste
			for x in range(1, r.size.x - 1):
				var q := r.position + Vector2i(x, y)
				var i := q.y * taille + q.x
				if e.meubles.has(i) or prises.has(q):
					continue
				e.meubles[i] = "tombe"
				tombes.append({"tuile": q, "nom": nom_m, "fonction": str(mort.get("fonction", "")), "an": int(sim.date_courante().get("annee", 0))})
				sim.monde.tombes[cell] = tombes
				if not sim.monde.modifications.has(cell):
					sim.monde.modifications[cell] = {}
				sim.monde.modifications[cell][i] = {"h": int(e.hauteurs[i]), "contenu": "", "materiau": "", "meuble": "tombe",
					"station": "", "sol": str(e.sols.get(i, "")), "eau": 0}
				var pm: Vector2i = sim.monde.pos_monde(cell, q)
				if sim.grille != null and sim.grille.dans(pm):   # la ville est sous les yeux : la tombe s'y voit tout de suite
					sim.grille.meubles[sim.grille.idx(pm)] = "tombe"
					sim.grille.marquer(pm)
					EventBus.emettre(&"tile_changed", [pm])
				return true
		return false   # le cimetière de sa ville est plein
	return false


## L'épitaphe d'une tuile, s'il y a une tombe nommée (le client la lit au survol) : {"nom", "fonction", "an"}.
static func epitaphe(sim: Simulation, pos: Vector2i) -> Dictionary:
	if sim.monde == null:
		return {}
	var cell: Vector2i = sim.monde.cellule_de(pos)
	var e: Dictionary = sim.monde.cellules.get(cell, {})
	var v: Dictionary = e.get("village", {})
	if v.is_empty():
		return {}
	var locale: Vector2i = pos - cell * int(GameData.config("planete").taille_cellule)
	for t in sim.monde.tombes.get(cell, []):   # la mémoire du monde, pas celle d'une cellule qui se régénère
		if Vector2i(t.tuile) == locale:
			return t
	return {}


# ---------------------------------------------------------------- la population des villes (anneau moyen v2, 2026-09-06)

## Chaque semaine, dans le contexte d'une ville (chargée ou non) : les naissances dans les couples, la majorité qui
## prend un métier, les migrations des malheureux vers la ville connue qui a de la place. Les chiffres :
## villes.json → anneau_moyen.population. On l'apprend au journal quand on est dans la ville.
static func _semaine_population(sim: Simulation) -> void:
	var cfg: Dictionary = GameData.config("villes").get("anneau_moyen", {}).get("population", {})
	if cfg.is_empty() or sim.monde == null or not sim.territoire.has("agglomeration"):
		return
	var tid := str(sim.territoire.get("id", ""))
	var ici := SimTerritoire._territoire_charge(sim, tid)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "population", tid, sim.horloge_monde.ticks])
	var ag: Dictionary = sim.regles.r.age
	var res: Array = SimTerritoire.residents(sim)
	var par_id := {}
	for x in res:
		par_id[str(x.id)] = x
	# 1. Les naissances : un couple, une fois (le plus petit id tire).
	var nes := 0
	for x in res:
		var fam: Dictionary = x.get("family", {})
		var cid := str(fam.get("spouse", ""))
		if cid.is_empty() or not par_id.has(cid) or cid < str(x.id):
			continue
		var c: Dictionary = par_id[cid]
		if float(x.get("age", 30.0)) < float(ag.adulte) or float(c.get("age", 30.0)) < float(ag.adulte):
			continue
		if minf(float(x.get("age", 30.0)), float(c.get("age", 30.0))) > float(cfg.age_max_parent):
			continue
		if fam.get("parent_of", []).size() >= int(cfg.enfants_max_par_couple):
			continue
		if rng.randf() >= float(cfg.naissance_par_couple_semaine):
			continue
		var enfant := _naitre(sim, x, c, tid)
		if enfant.is_empty():
			continue
		nes += 1
		if ici:
			EventBus.emettre(&"journal", [&"journal.naissance", {"village": str(sim.territoire.agglomeration.get("nom", tid)), "nom": x.name_key}])   # la même ligne que le repeuplement (10.5)
	# 2. La majorité : un enfant né dans le jeu prend le métier d'un de ses parents, et son poste.
	if bool(cfg.get("majorite_metier_herite", true)):
		for x in res:
			if not bool(x.get("ne_ici", false)) or float(x.get("age", 0.0)) < float(ag.adulte) or str(x.get("fonction", "oisif")) != "oisif":
				continue
			for pid in x.get("family", {}).get("child_of", []):
				var parent: Dictionary = par_id.get(str(pid), {})
				var metier := str(parent.get("fonction", "oisif"))
				if parent.is_empty() or metier == "oisif" or not GameData.catalogues.functions.has(metier):
					continue
				x.fonction = metier
				x.assignation["fonction"] = metier
				if parent.has("poste"):
					x["poste"] = parent.poste
					x.ancre = parent.poste
				if ici:
					EventBus.emettre(&"journal", [&"journal.majorite", {"nom": x.name_key, "metier": GameData.catalogues.functions[metier].name_key}])
				break
	# 2 bis. On quitte le lit de ses parents (Villes, 2026-09-07) : un enfant y dort, un adulte non. Si la ville a
	# dépassé ce que son bâti loge, le nouvel adulte n'a plus de lit — son humeur baissera, et c'est elle qui décidera
	# s'il reste ou s'il part. C'est indépendant du métier hérité : on devient adulte même quand ses parents sont oisifs.
	if bool(cfg.get("majorite_quitte_le_lit", true)) and res.size() > int(sim.territoire.agglomeration.get("population", 0)):
		for x in res:
			if not bool(x.get("ne_ici", false)) or float(x.get("age", 0.0)) < float(ag.adulte) or not x.has("lit"):
				continue
			for pid in x.get("family", {}).get("child_of", []):
				var parent_l: Dictionary = par_id.get(str(pid), {})
				if not parent_l.is_empty() and parent_l.has("lit") and Vector2i(parent_l.lit) == Vector2i(x.lit):
					x.erase("lit")
					break
	# 3. Les migrations : vers la ville connue qui a le plus de place, celle du même royaume d'abord.
	var cibles: Array = []
	for id in sim.territoires.keys():
		if str(id) == tid or str(id) == "joueur" or not sim.territoires[id].has("agglomeration"):
			continue
		var t2: Dictionary = sim.territoires[id]
		var n2: int = SimTerritoire._dans_territoire(sim, str(id), func() -> int: return SimTerritoire.residents(sim).size())
		var libre := int(t2.agglomeration.get("population", 0)) - n2
		if libre > 0:
			cibles.append({"id": str(id), "libre": libre, "royaume": str(t2.get("proprietaire", ""))})
	if cibles.is_empty():
		return
	var tps := int(GameData.config("planete").corruption.ticks_par_semaine)
	for x in res:
		if cibles.is_empty():
			break
		if str(x.get("fonction", "")) in ["dirigeant", "maitre_de_guilde"] or str(x.get("ai_profile", "")) == "garde":
			continue
		if sim.horloge_monde.ticks < int(x.get("migre_avant", 0)) or int(x.get("humeur", 60)) >= int(cfg.migration_humeur_seuil):
			continue
		if rng.randf() >= float(cfg.migration_chance_semaine):
			continue
		var roy := str(x.get("royaume", ""))
		cibles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if (str(a.royaume) == roy) != (str(b.royaume) == roy):
				return str(a.royaume) == roy
			return int(a.libre) > int(b.libre))
		var cible: Dictionary = cibles[0]
		var de := str(sim.territoire.agglomeration.get("nom", tid))
		_migrer(sim, x, str(cible.id))
		x["migre_avant"] = sim.horloge_monde.ticks + int(cfg.semaines_entre_migrations) * tps
		cible.libre = int(cible.libre) - 1
		if int(cible.libre) <= 0:
			cibles.erase(cible)
		if ici:
			EventBus.emettre(&"journal", [&"journal.migration", {"nom": x.name_key, "de": de, "vers": str(sim.territoires[cible.id].agglomeration.get("nom", cible.id))}])


## Un enfant naît : de la race de son parent, nommé dans la culture de la ville, oisif, logé au lit de ses parents ;
## à côté d'eux s'ils sont chargés, dans `Monde.dormants` sinon.
static func _naitre(sim: Simulation, parent: Dictionary, conjoint: Dictionary, tid: String) -> Dictionary:
	var def_id := str(parent.get("def", "villageois"))
	if not GameData.catalogues.creatures.has(def_id):
		def_id = "villageois"
	var cell: Vector2i = parent.get("assignation", {}).get("cellule", SimCamp._cell_de(sim, parent.pos))
	var e: Dictionary = {}
	if sim.entites.has(parent.id):
		var pos := sim._tuile_libre_autour(parent.pos)
		if pos == Vector2i(-1, -1):
			return {}
		e = SimObjets.ajouter(sim, def_id, pos, "ia")
	else:
		e = SimObjets.instancier_endormi(sim, def_id, parent.pos)
		if not sim.monde.dormants.has(cell):
			sim.monde.dormants[cell] = []
		sim.monde.dormants[cell].append(e)
	if e.is_empty():
		return {}
	SimObjets._habiller_pnj(sim, e, GameData.entree("creatures", def_id), str(sim.territoire.agglomeration.get("culture", "")))
	e.age = 0.0
	e["ne_ici"] = true
	e["fonction"] = "oisif"
	e["role"] = "resident"
	e["assignation"] = {"fonction": "oisif", "cellule": cell, "territoire": tid}
	if parent.get("assignation", {}).has("residence"):
		e.assignation["residence"] = parent.assignation.residence
	for cle in ["lit", "poste", "place", "village", "royaume", "camp"]:
		if parent.has(cle):
			e[cle] = parent[cle]
	e.ancre = e.get("poste", e.pos)
	if not e.has("family"):
		e["family"] = {}
	e.family["spouse"] = ""
	e.family["parent_of"] = []
	e.family["child_of"] = [parent.id, conjoint.id]
	for pa in [parent, conjoint]:
		if not pa.has("family"):
			pa["family"] = {}
		if not pa.family.has("parent_of"):
			pa.family["parent_of"] = []
		pa.family.parent_of.append(e.id)
	return e


## Un résident part pour une autre ville connue : il en devient résident, sans lit, au centre ; chargé si elle est
## dans la fenêtre, endormi sinon. Son humeur repart de la base.
static func _migrer(sim: Simulation, x: Dictionary, vers: String) -> void:
	var t2: Dictionary = sim.territoires[vers]
	var centre: Vector2i = t2.agglomeration.get("centre", Vector2i.ZERO)
	var pos_c: Vector2i = sim.monde.pos_monde(centre, Vector2i(sim.monde.taille / 2, sim.monde.taille / 2))
	var cell_ici: Vector2i = SimCamp._cell_de(sim, x.pos)
	if sim.entites.has(x.id):
		sim.grille.liberer(x.pos)
		sim.ordre.erase(x.id)
		sim.entites.erase(x.id)
	elif sim.monde.dormants.has(cell_ici):
		sim.monde.dormants[cell_ici].erase(x)
	x["assignation"] = {"fonction": str(x.get("fonction", "oisif")), "cellule": centre, "territoire": vers}
	x["village"] = vers
	if str(t2.get("proprietaire", "")) != "joueur":
		x["royaume"] = str(t2.get("proprietaire", ""))
	x["lit"] = Vector2i(-1, -1)
	x["poste"] = pos_c
	x["place"] = pos_c
	x.ancre = pos_c
	x.pos = pos_c
	x.humeur = int(SimTerritoire._ry(sim).humeur_base)
	x.erase("chemin_routine")
	var charge := absi(centre.x - sim.monde.centre.x) <= sim.monde.rayon and absi(centre.y - sim.monde.centre.y) <= sim.monde.rayon and sim.grille.dans(pos_c)
	if charge:
		var p := sim._tuile_libre_autour(pos_c)
		if p != Vector2i(-1, -1):
			x.pos = p
			sim.entites[x.id] = x
			sim.ordre.append(x.id)
			sim.grille.placer(x.id, p)
			return
	if not sim.monde.dormants.has(centre):
		sim.monde.dormants[centre] = []
	x["dormant_depuis"] = sim.horloge_monde.ticks
	sim.monde.dormants[centre].append(x)
