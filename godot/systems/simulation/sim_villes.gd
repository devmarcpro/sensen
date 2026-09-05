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

## Le bâtiment de la ville dont l'escalier est à cette tuile ({} sinon) : sa fiche de génération et son préfab.
static func batiment_a_escalier(sim: Simulation, pos: Vector2i) -> Dictionary:
	if sim.monde == null or sim.lieu != "camp":
		return {}
	var cell: Vector2i = SimCamp._cell_de(sim, pos)
	var v: Dictionary = sim.monde.cellule(cell).get("village", {})
	for bat in v.get("batiments", []):
		if bat.has("escalier") and sim.monde.pos_monde(cell, bat.escalier) == pos:
			var pref: Dictionary = GameData.catalogues.village_buildings.get(str(bat.id), {})
			if not pref.get("etages", []).is_empty():
				return {"bat": bat, "prefab": pref, "cell": cell}
	return {}


## Monter l'escalier d'un bâtiment : le camp est mis de côté, le premier étage se charge comme un étage de donjon.
static func _entrer_interieur(sim: Simulation, e: Dictionary, pos: Vector2i) -> bool:
	var b := batiment_a_escalier(sim, pos)
	if b.is_empty() or e.controle != "joueur":
		return false
	e["retour"] = pos
	SimLieux._sauver_camp(sim, e)
	sim.expedition = {}
	sim.etages_visites.clear()
	var palette: Dictionary = GameData.catalogues.biomes.get(str(sim.monde.cellule(b.cell).get("biome", "")), {}).get("village_palette", {"mur": "chene", "sol": "calcaire"})
	sim.donjon = {"interieur": true, "batiment": str(b.bat.id), "cellule": b.cell, "plans": b.prefab.etages, "etages": b.prefab.etages.size(), "palette": palette, "theme": "interieur", "graine": sim.graine, "id": 0}
	charger_interieur(sim, 1, e)
	return true


## Un étage d'intérieur bâti sur son plan : un petit étage de donjon dont les murs, les meubles et les deux escaliers
## viennent des lettres du plan ('v' : l'entrée, qui redescend ; '^' : l'escalier qui monte).
static func _etage_interieur(sim: Simulation, plan: Array, palette: Dictionary, meubles: Dictionary) -> Dictionary:
	var w := 0
	for ligne in plan:
		w = maxi(w, str(ligne).length())
	var h: int = plan.size()
	var et := {"largeur": w, "hauteur": h, "hauteurs": PackedByteArray(), "sol": {}, "bord": {}, "sols": {}, "meubles": {}, "portes": {}, "escalier": null, "entree": Vector2i(1, 1), "spawns": [], "coffres": [], "boss": null, "filons": {}, "lave": {}}
	et.hauteurs.resize(w * h)
	et.hauteurs.fill(Donjon.H_BASE)
	for y in h:
		var ligne: String = str(plan[y])
		for x in w:
			var c := ligne[x] if x < ligne.length() else "#"
			var i := y * w + x
			if c == "#" or c == " ":
				continue
			et.sol[i] = true
			et.sols[i] = str(palette.get("sol", "calcaire"))
			if c == "v":
				et.entree = Vector2i(x, y)
			elif c == "^":
				et.escalier = Vector2i(x, y)
			elif meubles.has(c) and c != "P":
				et.meubles[i] = str(meubles[c])
	return et


## Charger l'étage `etage` (dès 1) de l'intérieur courant ; les étages déjà visités reviennent tels quels.
static func charger_interieur(sim: Simulation, etage: int, joueur: Dictionary) -> void:
	var escorte: Array = SimPnj._escorte_qui_suit(sim, joueur)
	if sim.lieu == "donjon" and not sim.donjon.is_empty() and bool(sim.donjon.get("interieur", false)) and int(sim.donjon.get("etage", 0)) > 0:
		SimSauvegarde._sauver_etage(sim, joueur)
	sim.lieu = "donjon"
	sim.arene_id = "donjon"
	var plans: Array = sim.donjon.plans
	var pref: Dictionary = GameData.catalogues.village_buildings.get(str(sim.donjon.batiment), {})
	var meubles: Dictionary = pref.get("meubles", {})
	if sim.etages_visites.has(etage):
		var sauve: Dictionary = sim.etages_visites[etage]
		sim.donjon = sauve.donjon
		sim.grille = sauve.grille
		SimLieux._reinitialiser(sim)
		for id in sauve.ordre:
			sim.entites[id] = sauve.entites[id]
			sim.ordre.append(id)
			if sim.entites[id].vivant:
				sim.grille.placer(id, sim.entites[id].pos)
		sim.contenants = sauve.contenants
		var ou: Vector2i = sauve.donjon.escalier if (int(joueur.get("etage_depuis", 0)) > etage and sauve.donjon.escalier != null) else sauve.donjon.entree
		SimLieux._reprendre(sim, joueur, ou)
		SimPnj._placer_escorte(sim, joueur, escorte)
		return
	var et := _etage_interieur(sim, plans[etage - 1], sim.donjon.palette, meubles)
	if etage >= plans.size():
		et.escalier = null   # le dernier étage n'a rien au-dessus
	sim.donjon = sim.donjon.duplicate()
	sim.donjon["etage"] = etage
	sim.donjon["escalier"] = et.escalier
	sim.donjon["entree"] = et.entree
	sim.donjon["salles"] = 1
	sim.donjon["boss"] = null
	sim.donjon["corruption"] = 0.0
	sim.donjon["corruption_etage"] = 0.0
	sim.donjon["profondeur"] = 0
	sim.grille = Grille.depuis_etage(et, GameData.config("tile_contents"), sim.regles.r.deplacement, int(sim.regles.r.vision.hauteur_oeil))
	sim.grille.materiau_defaut = str(sim.donjon.palette.get("mur", "chene"))
	SimLieux._reinitialiser(sim)
	var ou: Vector2i = Vector2i(et.entree) if int(joueur.get("etage_depuis", 0)) <= etage or et.escalier == null else Vector2i(et.escalier)
	SimLieux._reprendre(sim, joueur, ou)
	SimPnj._placer_escorte(sim, joueur, escorte)
	sim.maj_vision()
	EventBus.emettre(&"journal", [&"journal.monte_etage", {"nom": joueur.name_key, "etage": etage, "batiment": "batiment.%s.name" % str(sim.donjon.batiment)}])


## Ressortir d'un bâtiment : le camp revient, le joueur devant l'escalier.
static func _sortir_interieur(sim: Simulation, e: Dictionary) -> bool:
	sim.etages_visites.clear()
	sim.expedition = {}
	if sim.camp_sauve.is_empty():
		return false
	SimLieux.charger_camp(sim, e)
	SimCamp._tiquer_territoire(sim, sim.horloge_monde.ticks)
	EventBus.emettre(&"journal", [&"journal.sort_batiment", {"nom": e.name_key}])
	return true


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
		for q in champ.tuiles:
			var p: Vector2i = sim.monde.pos_monde(cell, q)
			if not sim.grille.dans(p) or not sim.grille.contenu_de(p).is_empty() or sim.grille.meubles.has(sim.grille.idx(p)) or not sim.grille.occupant(p).is_empty() or sim.territoire.cultures.has(SimCamp._pm(sim, p)):
				continue
			_semer_tuile(sim, p, str(champ.plante), sim.horloge_monde.ticks, rng.randf_range(0.0, 0.9))


## Semer une tuile du territoire courant : la parcelle, son échéance (déjà avancée de `avancement`), le contenu.
static func _semer_tuile(sim: Simulation, vers: Vector2i, base: String, tick: int, avancement: float = 0.0) -> void:
	var pl: Dictionary = GameData.catalogues.plants[base]
	var duree := float(pl.duree_jours) * float(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
	sim.territoire.cultures[SimCamp._pm(sim, vers)] = {"plante": base, "semis": tick - int(duree * avancement), "echeance": tick + int(duree * (1.0 - avancement)), "mure": false}
	sim.grille.poser_contenu(vers, "culture")
	sim.grille.marquer(vers)


## Le rendement hebdomadaire abstrait d'une parcelle mûre : base × rendement du biome × fertilité, × canicule.
static func _rendement_parcelle(sim: Simulation, pm: Vector2i) -> int:
	var c: Dictionary = sim.territoire.cultures.get(pm, {})
	var cell: Vector2i = SimCamp._cell_de(sim, pm)
	var fy := float(GameData.catalogues.biomes.get(str(sim.monde.cellule(cell).get("biome", "")), {}).get("farming_yield", 1.0))
	var pl: Dictionary = GameData.catalogues.plants[str(c.plante)]
	var q := float(pl.recolte_base) * fy * (0.5 + float(SimCamp.fertilite_a(sim, pm, pm)) / 100.0)
	if SimTerrain.meteo(sim, cell) == "canicule":
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
	for pm in sim.territoire.cultures.keys():
		if quota <= 0:
			break
		var c: Dictionary = sim.territoire.cultures[pm]
		if not bool(c.get("mure", false)) or not sim.grille.dans(pm):
			continue
		var n := _rendement_parcelle(sim, pm)
		var cle := str(c.plante)
		sim.territoire.stocks[cle] = int(sim.territoire.stocks.get(cle, 0)) + n
		recoltes[cle] = int(recoltes.get(cle, 0)) + n
		total += n
		_semer_tuile(sim, pm, str(c.plante), tick)
		quota -= 1
	if total > 0:
		var noms: Array[String] = []
		for cle in recoltes.keys():
			noms.append("%s ×%d" % [TranslationServer.translate(str(GameData.catalogues.plants.get(str(cle), {}).get("name_key", str(cle)))), int(recoltes[cle])])
		EventBus.emettre(&"journal", [&"journal.recolte_champs", {"n": total, "plantes": " · ".join(noms)}])


## Le bétail du territoire produit chaque semaine (Villes B2) : la laine, le lait — une matière brute par espèce.
static func _semaine_betail(sim: Simulation) -> void:
	var produits: Dictionary = GameData.config("villes").get("enclos", {}).get("produits", {})
	var tid := str(sim.territoire.get("id", "joueur"))
	var prod := {}
	var total := 0
	for x in sim.vivants():
		if str(x.get("betail", "")) != tid:
			continue
		var p: Dictionary = produits.get(str(x.get("def", "")), {})
		if p.is_empty():
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


## Les périmètres d'un quartier, dans le contexte de sa ville : le résidentiel, les stockages des entrepôts, les
## zones de récolte ; chaque zone prend le premier stockage du quartier. Retourne les identifiants, dans l'ordre du plan.
static func _creer_perimetres_ville(sim: Simulation, cell: Vector2i, v: Dictionary) -> Array:
	var pids: Array = []
	var plan: Array = v.get("territoire", {}).get("perimetres", [])
	for per in plan:
		pids.append(SimPerimetres.creer_perimetre(sim, cell, str(per.type), per.tuiles, true))
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
