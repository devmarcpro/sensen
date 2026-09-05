class_name SimTerritoire
extends RefCounted
## Le territoire : claims, rôles, résidents, assignations, pièces et strates, recettes uniques ; abris, humeurs, nourriture, production ; le contexte d'un territoire (Villes B0) ; l'économie des villes (B3) et la semaine du territoire.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


static func _ry(sim: Simulation) -> Dictionary:
	return sim.regles.r.royaume


## Revendiquer une cellule contiguë explorée (Expansion territoriale) : 50 or × cellules possédées.
static func revendiquer(sim: Simulation, e: Dictionary, cell: Vector2i) -> bool:
	if sim.monde == null or e.controle != "joueur":
		return false
	var tid := territoire_de_cellule(sim, cell)
	if not tid.is_empty() and tid != str(sim.territoire.get("id", "joueur")):   # la cellule d'une ville ne se revendique pas (Villes B0)
		EventBus.emettre(&"journal", [&"journal.claim_refuse", {}])
		return false
	if not sim.monde.revendicable(cell, sim.horloge_monde.ticks):
		EventBus.emettre(&"journal", [&"journal.claim_refuse", {}])
		return false
	var cout := int(_ry(sim).claim_cout_par_cellule) * sim.monde.claims.size()
	if int(e.or) < cout:
		EventBus.emettre(&"journal", [&"journal.claim_or", {"or": cout}])
		return false
	e.or = int(e.or) - cout
	sim.monde.claims[cell] = {"role": "base"}
	if not sim.monde.decouvert.has(cell):
		sim.monde.decouvert[cell] = {}
	EventBus.emettre(&"cell_claimed", [cell])
	EventBus.emettre(&"journal", [&"journal.claim", {"x": cell.x, "y": cell.y, "or": cout, "n": sim.monde.claims.size()}])
	_verifier_royaume(sim, e)
	return true


static func changer_role(sim: Simulation, cell: Vector2i, role: String) -> bool:
	if sim.monde == null or not sim.monde.claims.has(cell) or not (role in _ry(sim).roles):
		return false
	sim.monde.claims[cell].role = role
	EventBus.emettre(&"cell_role_changed", [cell, role])
	EventBus.emettre(&"journal", [&"journal.role", {"x": cell.x, "y": cell.y, "role": "role." + role}])
	return true


static func residents(sim: Simulation) -> Array:
	var res: Array = []
	var tid := str(sim.territoire.get("id", "joueur"))   # ceux du territoire courant (Villes B0) ; « joueur » par défaut : les anciennes sauvegardes
	for x in sim.entites.values():
		if x.vivant and x.has("assignation") and str(x.assignation.get("territoire", "joueur")) == tid:
			res.append(x)
	return res


## Un résident quitte le territoire (palier de dette, Entretien et taxes) : il sort de la fenêtre et de la simulation,
## son lit se libère. Pas un civil planté là : la grande base en comptait vingt et un debout dans le résidentiel.
static func _quitter_le_territoire(sim: Simulation, x: Dictionary) -> void:
	x.erase("assignation")
	x.erase("lit")
	x.camp = "civil"
	if sim.entites.has(x.id):
		sim.grille.liberer(x.pos)
		sim.ordre.erase(x.id)
		sim.entites.erase(x.id)
	EventBus.emettre(&"journal", [&"journal.quitte_territoire", {"nom": x.name_key}])


## Le facteur d'humeur d'un résident (Population et exploitation) : humeur/100 × 1,5, borné [0,4 ; 1,2].
static func facteur_humeur(sim: Simulation, x: Dictionary) -> float:
	var b: Array = _ry(sim).facteur_humeur_bornes
	return clampf(float(x.get("humeur", _ry(sim).humeur_base)) / 100.0 * float(_ry(sim).facteur_humeur_mult), float(b[0]), float(b[1]))


## Assigner un compagnon ou un PNJ ami à une fonction, sur la cellule où il se trouve.
static func _assigner(sim: Simulation, e: Dictionary, pnj_id: String, fonction: String, tick: int, perimetre: String = "") -> bool:
	var x: Dictionary = sim.entites.get(pnj_id, {})
	if x.is_empty() or sim.monde == null or not GameData.catalogues.functions.has(fonction):
		return false
	var cell: Vector2i = SimCamp._cell_de(sim, x.pos)
	var conquis: bool = str(sim.monde.villages.get(str(x.get("village", "")), {}).get("conquis_par", "")) == e.id
	if not sim.monde.claims.has(cell) or (str(x.get("maitre", "")) != e.id and x.camp != "joueur" and not conquis):
		return false
	if str(x.get("maitre", "")) == e.id:
		x["ancien_compagnon"] = true   # renvoyé un jour, il redeviendra compagnon, pas villageois (Gestion de base, étape 2)
	x.erase("maitre")
	if not conquis:
		x.camp = "joueur"
	# Un poste ET un logement (Décision — Gestion de base, 2026-09-04, 14 h) : assigner un périmètre de production
	# garde la résidence ; assigner un résidentiel ne change que le logement et garde la fonction et le poste.
	var avant: Dictionary = x.get("assignation", {})
	var vers_residentiel := false
	if not perimetre.is_empty() and SimPerimetres.perimetres(sim).has(perimetre):
		var tp_a: Dictionary = _ry(sim).get("perimetres", {}).get("types", {}).get(str(SimPerimetres.perimetres(sim)[perimetre].type), {})
		vers_residentiel = bool(tp_a.get("residentiel", false))
	if vers_residentiel and avant.has("fonction") and str(avant.get("cellule", "")) != "":
		fonction = str(avant.fonction)   # il garde son métier : on ne lui donne qu'un toit
	x.ai_profile = "civil" if fonction != "garde" else "garde"
	x["fonction"] = fonction
	x["role"] = "resident"
	x["assignation"] = {"fonction": fonction, "cellule": cell, "territoire": str(sim.territoire.get("id", "joueur"))}
	if vers_residentiel:
		x.assignation["residence"] = perimetre   # il y habite : une maison s'y bâtira (Population et exploitation)
		if avant.has("perimetre") and SimPerimetres.perimetres(sim).has(str(avant.perimetre)):
			x.assignation["perimetre"] = str(avant.perimetre)
	elif not perimetre.is_empty() and SimPerimetres.perimetres(sim).has(perimetre):   # assigné sur un périmètre de récolte (2026-09-04)
		x.assignation["perimetre"] = perimetre
	if not vers_residentiel and avant.has("residence") and SimPerimetres.perimetres(sim).has(str(avant.residence)):
		x.assignation["residence"] = str(avant.residence)
	x["poste"] = x.pos
	x.ancre = x.pos
	x["place"] = x.pos
	if x.assignation.has("perimetre"):   # il travaille dedans : son poste est une tuile au bord de la ressource
		var poste_p: Vector2i = SimPerimetres._poste_de_perimetre(sim, str(x.assignation.perimetre), x.pos)
		if poste_p != Vector2i(-1, -1):
			x["poste"] = poste_p
			x.ancre = poste_p
	x["humeur"] = int(_ry(sim).humeur_base)
	# Logement : un lit libre de la cellule.
	x.erase("lit")
	for gi in sim.grille.meubles.keys():
		var p := sim.grille.pos_de(int(gi))
		if SimCamp._cell_de(sim, p) == cell and bool(GameData.entree("meubles", str(sim.grille.meubles[gi])).dormir):
			var pris := false
			for autre in residents(sim):
				if autre.get("lit", Vector2i(-1, -1)) == p:
					pris = true
			if not pris:
				x["lit"] = p
				break
	if not x.has("lit"):
		x.humeur = int(x.humeur) + int(_ry(sim).sans_logement)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.assigne", {"nom": x.name_key, "fonction": GameData.entree("functions", fonction).name_key}])
	_verifier_royaume(sim, e)
	return true


## La guilde où le joueur a le rang le plus haut, si ce rang atteint le minimum d'un hall (Halls de guilde).
static func _meilleure_guilde(sim: Simulation, e: Dictionary) -> String:
	var meilleure := ""
	var rang_max := -1
	for gid in e.get("guildes", {}).keys():
		var rang := int(e.guildes[gid].get("rang", 0))
		if rang > rang_max:
			rang_max = rang
			meilleure = str(gid)
	return meilleure if rang_max >= int(_ry(sim).villes.hall_rang_min) else ""


## Retirer son affectation à un résident : il redevient compagnon — ou, avec `renvoyer`, un villageois libre
## (Décision — Gestion de base, étape 2 : un engagé ou un migrant renvoyé ne prend pas une place d'escorte).
static func desassigner(sim: Simulation, e: Dictionary, pnj_id: String, renvoyer: bool = false) -> bool:
	var x: Dictionary = sim.entites.get(pnj_id, {})
	if x.is_empty() or not x.has("assignation"):
		return false
	x.erase("assignation")
	if renvoyer and not bool(x.get("ancien_compagnon", false)):
		x.erase("maitre")
		x.camp = "civil"
		x.ai_profile = "civil"
		x["fonction"] = str(x.get("fonction", "oisif"))
		EventBus.emettre(&"journal", [&"journal.renvoye", {"nom": x.name_key}])
		return true
	SimPnj._devenir_compagnon(sim, e, x)
	EventBus.emettre(&"journal", [&"journal.desassigne", {"nom": x.name_key}])
	return true


static func _verifier_royaume(sim: Simulation, e: Dictionary) -> void:
	var seuil: Dictionary = _ry(sim).seuil_royaume
	if not bool(sim.territoire.royaume) and sim.monde != null and sim.monde.claims.size() >= int(seuil.cellules) and residents(sim).size() >= int(seuil.pnj):
		sim.territoire.royaume = true
		sim.territoire.gouvernance = str(_ry(sim).gouvernance.defaut)
		EventBus.emettre(&"journal", [&"journal.royaume", {}])
		EventBus.emettre(&"journal", [&"journal.royaume_fonde", {"gouv": GameData.entree("governments", sim.territoire.gouvernance).name_key}])


## Les pièces valides d'une cellule (Détection de pièces, Décision — Pièces en 2D) : flood fill depuis chaque porte.
static func pieces_de_cellule(sim: Simulation, cell: Vector2i) -> Array:
	var res: Array = []
	if sim.monde == null or sim.lieu != "camp":
		return res
	var pc: Dictionary = _ry(sim).pieces
	var vues: Dictionary = {}
	for i in sim.grille.contenu.size():
		if sim.grille.contenu[i] <= 0 or not (str(sim.grille.contenu_ids[sim.grille.contenu[i]]) in ["porte", "porte_fermee"]):
			continue   # une porte fermée (celles des villes, que les PNJ ouvrent) ferme une pièce aussi (Villes B1)
		var porte := sim.grille.pos_de(i)
		if SimCamp._cell_de(sim, porte) != cell:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var depart: Vector2i = porte + d
			if not sim.grille.dans(depart) or vues.has(depart) or sim.grille.bloque_passage(depart):
				continue
			var region: Dictionary = {}
			var pile: Array = [depart]
			var ouvert := false
			while not pile.is_empty() and region.size() <= int(pc.fill_max):
				var q: Vector2i = pile.pop_back()
				if region.has(q):
					continue
				if not sim.grille.dans(q) or SimCamp._cell_de(sim, q) != cell:
					ouvert = true
					break
				var tags: Array = sim.grille.contenu_de(q).get("tags", [])
				if "mur" in tags or "porte" in tags:
					continue
				if sim.grille.bloque_passage(q) and not sim.grille.meubles.has(sim.grille.idx(q)):
					continue
				region[q] = true
				for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					pile.append(q + d2)
			for q in region.keys():
				vues[q] = true
			if ouvert or region.size() > int(pc.fill_max) or region.size() < int(pc.surface_min):
				continue
			var types: Dictionary = {}
			for q in region.keys():
				if sim.grille.meubles.has(sim.grille.idx(q)):
					types[str(sim.grille.meubles[sim.grille.idx(q)])] = true
			if types.is_empty():
				continue
			res.append({"tuiles": region.keys(), "meubles": types.keys(), "porte": porte})
	return res


## Les poches locales (Stratification verticale) : un bruit dédié déplace le mur d'une strate, ±1, par taches.
static func _poches_de_strates(sim: Simulation, theme: Dictionary, etage: int, graine: int, id_donjon: int) -> void:
	var pal: Dictionary = GameData.config("minerais_par_etage").get("palette_mur", {})
	var pc: Dictionary = pal.get("poches", {})
	if pc.is_empty() or etage < int(pal.get("etage_min", 3)):
		return
	var bruit := FastNoiseLite.new()
	bruit.seed = hash([graine, "poches", id_donjon, etage])
	bruit.frequency = float(pc.get("frequence", 0.08))
	var dur := materiau_mur_etage(sim, theme, etage + int(pc.get("saut", 2)))
	var tendre := materiau_mur_etage(sim, theme, maxi(int(pal.get("etage_min", 3)), etage - int(pc.get("saut", 2))))
	var defaut := sim.grille.materiau_defaut
	for y in sim.grille.hauteur_grille:
		for x in sim.grille.largeur:
			var t := Vector2i(x, y)
			if not ("destructible" in sim.grille.contenu_de(t).get("tags", [])):
				continue
			var v := (bruit.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			if v > float(pc.get("seuil_dur", 0.7)) and dur != defaut:
				sim.grille.materiaux[sim.grille.idx(t)] = dur
			elif v < float(pc.get("seuil_tendre", 0.3)) and tendre != defaut:
				sim.grille.materiaux[sim.grille.idx(t)] = tendre


## Le matériau des murs d'un étage (Stratification verticale) : le thème en surface, la palette en profondeur.
static func materiau_mur_etage(sim: Simulation, theme: Dictionary, etage: int) -> String:
	var pal: Dictionary = GameData.config("minerais_par_etage").get("palette_mur", {})
	if pal.is_empty() or etage < int(pal.get("etage_min", 3)):
		return str(theme.get("materiau_mur", ""))
	for b in pal.get("bandes", []):
		if etage >= int(b.etages[0]) and etage <= int(b.etages[1]):
			return str(b.materiau)
	return str(theme.get("materiau_mur", ""))


## Les trésors détectés (Effets d'équipement : detection_tresors) : les contenants à portée, vus ou non.
static func tresors_detectes(sim: Simulation, e: Dictionary) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	if not ("detection_tresors" in e.get("tags_acquis", [])):
		return res
	var r := int(sim.regles.r.effets_equipement.tresors_rayon)
	for gi in sim.contenants.keys():
		if sim.contenants[gi].is_empty():
			continue
		var t := sim.grille.pos_de(int(gi))
		if Grille.distance(e.pos, t) <= r:
			res.append(t)
	return res


## Le niveau d'une recette pour un être (Axe des niveaux de recette) : 1 par défaut, jusqu'à 5.
static func niveau_recette(sim: Simulation, e: Dictionary, rid: String) -> int:
	return int(e.get("niveaux_recettes", {}).get(rid, 1))


## Un doublon de plan : il compte, et quand les doublons atteignent le niveau, la recette monte.
static func _doublon_recette(sim: Simulation, e: Dictionary, rid: String) -> void:
	if not e.has("niveaux_recettes"):
		e["niveaux_recettes"] = {}
	if not e.has("doublons_recettes"):
		e["doublons_recettes"] = {}
	var n := niveau_recette(sim, e, rid)
	var maxi_n := int(sim.regles.r.craft.qualite.get("niveau_recette_max", 5))
	var nom: String = GameData.catalogues.recipes.get(rid, GameData.catalogues.component_recipes.get(rid, {})).get("name_key", rid)
	if n >= maxi_n:
		EventBus.emettre(&"journal", [&"journal.plan_deja", {}])
		return
	var d := int(e.doublons_recettes.get(rid, 0)) + 1
	if d >= n:
		e.niveaux_recettes[rid] = n + 1
		e.doublons_recettes[rid] = 0
		EventBus.emettre(&"journal", [&"journal.recette_niveau", {"recette": nom, "n": n + 1}])
	else:
		e.doublons_recettes[rid] = d
		EventBus.emettre(&"journal", [&"journal.recette_doublon", {"k": n - d, "n": n + 1}])


## Un effet unique d'artefact porté ? (Trésors et artefacts)
static func a_unique(sim: Simulation, e: Dictionary, mecanique: String) -> bool:
	return not a_unique_ax(sim, e, mecanique).is_empty()


static func a_unique_ax(sim: Simulation, e: Dictionary, mecanique: String) -> Dictionary:
	for ax in Etres.affixes_equipes(e, sim.items, sim.affixes_defs, "unique"):
		if str(sim.affixes_defs.get(ax.id, {}).get("effet", {}).get("mecanique", "")) == mecanique:
			return ax
	return {}


## Un abri pour le bétail (Habitat des PNJ) : un enclos à portée.
static func _abri_a(sim: Simulation, pos: Vector2i) -> bool:
	var r := int(_ry(sim).betail.abri_rayon)
	for gi in sim.grille.meubles.keys():
		if str(GameData.entree("meubles", str(sim.grille.meubles[gi])).type_meuble) == "enclos" and Grille.distance(pos, sim.grille.pos_de(int(gi))) <= r:
			return true
	return false


## Changer le statut d'habitat d'un compagnon ou d'un résident (Habitat des PNJ) : bétail ou normal.
static func _statut_habitat(sim: Simulation, e: Dictionary, pnj_id: String, statut: String, tick: int) -> bool:
	var x: Dictionary = sim.entites.get(pnj_id, {})
	if x.is_empty() or Grille.distance(e.pos, x.pos) > 2 or not (str(x.get("maitre", "")) == e.id or x.has("assignation")):
		return false
	if str(x.get("statut_habitat", "normal")) == statut:
		return false
	x["statut_habitat"] = statut
	e.compteur = tick + int(sim.regles.r.actions.objet)
	if statut == "betail":
		EventBus.emettre(&"journal", [&"journal.statut_betail", {"nom": x.name_key}])
		if not ("bete" in x.get("tags", [])) and x.has("social"):   # un ancien corps de joueur n'a pas de bloc social
			x.social.relations[e.id] = int(x.social.relations.get(e.id, 0)) + int(_ry(sim).betail.retrogradation_relation)
			EventBus.emettre(&"journal", [&"journal.retrogradation", {"nom": x.name_key}])
	else:
		EventBus.emettre(&"journal", [&"journal.statut_resident", {"nom": x.name_key}])
	return true


## La pièce d'un lit (ou vide).
static func _piece_du_lit(sim: Simulation, lit: Vector2i, pieces: Array) -> Dictionary:
	for pi in pieces:
		if lit in pi.tuiles:
			return pi
	return {}


## Les humeurs recalculées au passage de semaine (Habitat des PNJ, Faim des PNJ) : logement, chambre, co-occupants, faim.
static func _recalculer_humeurs(sim: Simulation) -> void:
	var ry := _ry(sim)
	var pc: Dictionary = ry.pieces
	var pieces_par_cell: Dictionary = {}
	var res := residents(sim)
	for x in res:
		var h := int(ry.humeur_base)
		var lit: Vector2i = x.get("lit", Vector2i(-1, -1))
		var cell: Vector2i = SimCamp._cell_de(sim, lit) if lit != Vector2i(-1, -1) else Vector2i(-9999, -9999)
		if not pieces_par_cell.has(cell):
			pieces_par_cell[cell] = pieces_de_cellule(sim, cell) if cell != Vector2i(-9999, -9999) else []
		var piece := _piece_du_lit(sim, lit, pieces_par_cell[cell]) if lit != Vector2i(-1, -1) else {}
		if str(x.get("statut_habitat", "normal")) == "betail":   # bétail (Habitat des PNJ) : un abri suffit, il broute
			if not _abri_a(sim, x.pos) and piece.is_empty():
				h += int(ry.sans_logement)
			if not ("bete" in x.get("tags", [])):
				h += int(ry.betail.retrogradation_humeur)
			x.humeur = h
			continue
		if piece.is_empty():
			h += int(ry.sans_logement)
		else:
			h += mini(int(pc.bonus_meubles_max), int(pc.bonus_par_meuble) * piece.meubles.size())
			if piece.tuiles.size() >= int(pc.surface_bonus):
				h += int(pc.bonus_taille)
			var co := 0
			for autre in res:
				if autre.id != x.id and autre.get("lit", Vector2i(-2, -2)) in piece.tuiles:
					co += 1
			h += int(pc.co_occupant) * co
		if bool(x.get("affame", false)):   # le repas de la semaine a manqué (_nourrir_residents)
			h += int(ry.get("faim_pnj", -10))
		x.humeur = h


## Le repas hebdomadaire des résidents (Faim des PNJ, 2026-09-04) : une unité par résident, au garde-manger d'abord,
## puis au stock du territoire — tout consommable à nutrition > 0, là où tombe la récolte des fermiers. Une seule
## fois par semaine, avant le bilan ; laisse `affame` sur chacun, que `_recalculer_humeurs` lit.
static func _nourrir_residents(sim: Simulation) -> void:
	var affames := 0   # une ligne de journal pour tous, pas une par personne (grande base, 2026-09-04)
	var garde_manger: Array = []
	for gi in sim.grille.meubles.keys():
		if str(GameData.entree("meubles", str(sim.grille.meubles[gi])).type_meuble) == "garde_manger" and sim.monde.claims.has(SimCamp._cell_de(sim, sim.grille.pos_de(int(gi)))):
			garde_manger.append(int(gi))
	for x in residents(sim):
		var mange := false
		for gi in garde_manger:
			for uid in sim.contenants.get(gi, []):
				var it: Dictionary = sim.items.get(uid, {})
				if it.get("type", "") == "consommable" and float(it.get("nutrition", 0)) > 0.0:
					it.quantite = int(it.get("quantite", 1)) - 1
					if int(it.quantite) <= 0:
						sim.contenants[gi].erase(uid)
						sim.items.erase(uid)
					mange = true
					break
			if mange:
				break
		if not mange:   # le stock du territoire est un garde-manger de fait
			for cle in sim.territoire.stocks.keys():
				var def: Dictionary = GameData.catalogues.items.get(str(cle).split("|")[0], {})
				if str(def.get("type", "")) == "consommable" and float(def.get("nutrition", 0)) > 0.0 and int(sim.territoire.stocks[cle]) > 0:
					sim.territoire.stocks[cle] = int(sim.territoire.stocks[cle]) - 1
					if int(sim.territoire.stocks[cle]) <= 0:
						sim.territoire.stocks.erase(cle)
					mange = true
					break
		x["affame"] = not mange
		if not mange:
			affames += 1
	if affames > 0:
		EventBus.emettre(&"journal", [&"journal.pnj_affame", {"n": affames}])


## La production hebdomadaire d'un résident (Abstraction hors-site) : rendement × heures × humeur.
static func production_de(sim: Simulation, x: Dictionary) -> Dictionary:
	# Un périmètre de récolte (Population et exploitation, 2026-09-04) : c'est ce qu'il y a sur les tuiles qui produit.
	var per: Dictionary = SimPerimetres.perimetres(sim).get(str(x.assignation.get("perimetre", "")), {})
	if not per.is_empty():
		var pcfg: Dictionary = _ry(sim).get("perimetres", {})
		var tp: Dictionary = pcfg.get("types", {}).get(str(per.type), {})
		if bool(tp.get("champs", false)):
			return {}   # un fermier de champs : sa production est la récolte hebdomadaire des parcelles (Villes B2)
		var niv := sim.regles.niveau(x.competences_eff, str(tp.get("skill", "")))
		var qp := float(tp.get("par_tuile_semaine", 0.5)) * minf(float(per.get("richesse", 0)), float(pcfg.get("tuiles_max_par_resident", 20))) \
			* sim.regles.skill_factor(niv) * facteur_humeur(sim, x) * float(sim.territoire.get("productivite", 1.0))
		var np := mini(int(floor(qp)), int(floor(float(per.get("reserve", 0.0)))))
		var stock: Dictionary = SimPerimetres.perimetres(sim).get(str(per.get("stockage", "")), {})
		if stock.is_empty():   # un stockage par poste (designer 2026-09-04) : sans stockage, rien ne se récolte
			return {"sans_stockage": true, "perimetre": str(per.id)}
		np = mini(np, SimPerimetres.place_stockage(sim, str(stock.id)))
		if np <= 0 or str(per.get("dominant", "")).is_empty():
			return {}
		return {"base": str(per.dominant), "forme": "brut", "n": np, "perimetre": str(per.id), "stockage": str(stock.id)}
	var f: Dictionary = GameData.catalogues.functions.get(str(x.assignation.fonction), {})
	var prod = f.get("produit")
	if prod == null:
		return {}
	var niveau := sim.regles.niveau(x.competences_eff, str(f.get("skill", ""))) if not str(f.get("skill", "")).is_empty() else 0
	var rendement := float(f.get("rendement_base", 0.02)) * (1.0 + float(niveau) / 10.0)
	var mult := float(sim.territoire.get("productivite", 1.0)) * SimPnj.facteur_trait(sim, x, "productivite")   # l'ambitieux produit plus, le paresseux moins (traits)
	var q := rendement * float(_ry(sim).heures_semaine) * facteur_humeur(sim, x) * mult
	if prod.has("or"):
		return {"or": int(round(q * float(prod.or)))}
	return {"base": str(prod.get("item", prod.get("materiau", ""))), "forme": str(prod.get("forme", "")), "n": int(floor(q * float(prod.get("par_unite", 1.0))))}


# ---------------------------------------------------------------- les territoires (Villes — B0, 2026-09-05)

## Le contexte d'un territoire : le temps d'un appel, `territoire` et `monde.claims` sont ceux de `id` — tout ce qui lit
## le territoire du joueur tourne tel quel pour une ville (« la gestion de camp et les villes sont exactement pareils »).
static func _dans_territoire(sim: Simulation, id: String, f: Callable) -> Variant:
	if not sim.territoires.has(id) or id == str(sim.territoire.get("id", "joueur")):
		return f.call()
	var avant := str(sim.territoire.get("id", "joueur"))
	_entrer_contexte(sim, id)
	var res: Variant = f.call()
	_entrer_contexte(sim, avant)
	return res


static func _entrer_contexte(sim: Simulation, id: String) -> void:
	if not sim.territoires.has(id):
		return
	sim.territoire = sim.territoires[id]
	if not sim.territoire.has("cellules"):
		sim.territoire["cellules"] = {}
	if sim.monde != null:
		sim.monde.claims = sim.territoire.cellules


## Le territoire auquel une cellule appartient ("" si aucun) : les claims du joueur, ou les cellules d'une ville.
static func territoire_de_cellule(sim: Simulation, cell: Vector2i) -> String:
	for id in sim.territoires.keys():
		if sim.territoires[id].get("cellules", {}).has(cell):
			return str(id)
	return ""


## Le territoire courant du joueur : celui de la cellule où il se tient s'il le possède, sinon sa base.
static func territoire_courant(sim: Simulation) -> Dictionary:
	var j := _joueur(sim)
	if not j.is_empty() and sim.monde != null and sim.lieu == "camp":
		var id := territoire_de_cellule(sim, SimCamp._cell_de(sim, j.pos))
		if not id.is_empty() and str(sim.territoires[id].get("proprietaire", "")) == "joueur":
			return sim.territoires[id]
	return sim.territoires.get("joueur", sim.territoire)


## Suit le joueur à chaque tick du monde : le contexte ambiant est son territoire courant (l'écran Gestion, P, les
## assignations, les périmètres dessinés travaillent sur la ville qu'il contrôle quand il s'y tient).
static func _maj_contexte(sim: Simulation) -> void:
	var voulu := str(territoire_courant(sim).get("id", "joueur"))
	if voulu != str(sim.territoire.get("id", "joueur")):
		_entrer_contexte(sim, voulu)


static func _joueur(sim: Simulation) -> Dictionary:
	for x in sim.entites.values():
		if x.controle == "joueur":
			return x
	return {}


## Un territoire de ville : créé à sa première cellule chargée (B1), ou par un test.
static func creer_territoire(sim: Simulation, id: String, proprietaire: String, tresor: int = 0) -> Dictionary:
	if sim.territoires.has(id):
		return sim.territoires[id]
	var t := Simulation.territoire_vide(id, proprietaire)
	t.tresor = tresor
	sim.territoires[id] = t
	return t


## L'entité qui répond du territoire dans sa semaine : le joueur s'il le possède, sinon son magistrat (une fonction
## qui porte `magistrat`), sinon personne (un dictionnaire vide de droits : pas de guilde, pas d'or, pas de relation).
static func _proprietaire_entite(sim: Simulation, id: String) -> Dictionary:
	var t: Dictionary = sim.territoires.get(id, {})
	if str(t.get("proprietaire", "")) == "joueur":
		return _joueur(sim)
	for x in sim.vivants():
		if str(x.get("village", "")) == id and bool(GameData.catalogues.functions.get(str(x.get("fonction", "")), {}).get("magistrat", false)):
			return x
	return {"id": "", "or": 0, "guildes": {}, "reputations": {}, "name_key": "", "pos": Vector2i.ZERO}


## Une ville est chargée si l'une de ses cellules est dans la fenêtre (rien ne vit hors fenêtre — LOD de simulation).
static func _territoire_charge(sim: Simulation, id: String) -> bool:
	if sim.monde == null or sim.lieu != "camp" or not sim.territoires.has(id):
		return false
	for cell in sim.territoires[id].get("cellules", {}).keys():
		if absi(cell.x - sim.monde.centre.x) <= sim.monde.rayon and absi(cell.y - sim.monde.centre.y) <= sim.monde.rayon:
			return true
	return false


## La semaine des villes chargées : chacune dans son contexte, par les fonctions du camp.
static func _semaine_villes(sim: Simulation) -> void:
	for id in sim.territoires.keys():
		if str(id) == "joueur" or not _territoire_charge(sim, str(id)):
			continue
		var e := _proprietaire_entite(sim, str(id))
		_dans_territoire(sim, str(id), func() -> void: _semaine_territoire(sim, e))


static func _semaine_joueur(sim: Simulation, x: Dictionary) -> void:
	_semaine_territoire(sim, x)
	SimPerimetres._semaine_migrants(sim, x)   # la base attire (Population et exploitation, 2026-09-04)


# ---------------------------------------------------------------- les royaumes-pays (D — Royaumes — état, ères, blasons et événements, 2026-09-05)

## La catégorie économique d'un objet (villes.economie.categories) : le type de l'objet d'abord, la matière sinon.
static func categorie_economique(sim: Simulation, it: Dictionary) -> String:
	var cats: Dictionary = GameData.config("villes").economie.categories
	var type := str(it.get("type", ""))
	if type == "consommable":
		return "nourriture" if float(it.get("nutrition", 0)) > 0.0 else "luxe"
	if type != "materiau" and cats.par_type.has(type):
		return str(cats.par_type[type])
	var mat := str(it.get("materiau", ""))
	if mat.is_empty() and it.has("composants") and not it.composants.is_empty():
		mat = str(it.composants[it.composants.keys()[0]].materiau)
	var cm := str(GameData.catalogues.materials.get(mat, {}).get("category", ""))
	return str(cats.par_materiau.get(cm, ""))


## La catégorie d'une clé de stock (« base » ou « base|forme ») : un objet du catalogue, ou une matière.
static func _categorie_cle(sim: Simulation, cle: String) -> String:
	var base := str(cle).split("|")[0]
	if GameData.catalogues.items.has(base):
		return categorie_economique(sim, GameData.catalogues.items[base])
	if GameData.catalogues.materials.has(base):
		return str(GameData.config("villes").economie.categories.par_materiau.get(str(GameData.catalogues.materials[base].get("category", "")), ""))
	return ""


## Les stocks du territoire courant par catégorie.
static func stocks_par_categorie(sim: Simulation) -> Dictionary:
	var res := {}
	for cle in sim.territoire.stocks.keys():
		var cat := _categorie_cle(sim, str(cle))
		if not cat.is_empty():
			res[cat] = int(res.get(cat, 0)) + int(sim.territoire.stocks[cle])
	return res


## Retire `n` unités d'une catégorie dans les stocks (les clés les plus fournies d'abord) ; retourne ce qui a été pris.
static func _consommer_categorie(sim: Simulation, cat: String, n: int) -> int:
	var pris := 0
	var cles: Array = sim.territoire.stocks.keys()
	cles.sort_custom(func(a, b) -> bool: return int(sim.territoire.stocks[a]) > int(sim.territoire.stocks[b]))
	for cle in cles:
		if pris >= n:
			break
		if _categorie_cle(sim, str(cle)) != cat:
			continue
		var q := mini(int(sim.territoire.stocks[cle]), n - pris)
		sim.territoire.stocks[cle] = int(sim.territoire.stocks[cle]) - q
		if int(sim.territoire.stocks[cle]) <= 0:
			sim.territoire.stocks.erase(cle)
		pris += q
	return pris


## La semaine économique du territoire courant (Villes B3) : le besoin par catégorie, la consommation (la nourriture
## est mangée par `_nourrir_residents`, le reste s'use ici), le prix entre surplus et pénurie.
static func _semaine_economie(sim: Simulation) -> void:
	var eco: Dictionary = GameData.config("villes").economie
	var pop := maxi(residents(sim).size(), int(sim.territoire.get("agglomeration", {}).get("population", 0)))
	if pop <= 0:
		return
	var prix := {}
	for cat in eco.consommation.keys():
		var besoin := float(pop) * float(eco.consommation[cat])
		if str(cat) != "nourriture":
			_consommer_categorie(sim, str(cat), int(round(besoin)))
		var stock := int(stocks_par_categorie(sim).get(str(cat), 0))
		var ratio := clampf(float(stock) / maxf(1.0, besoin * float(eco.semaines_surplus)), 0.0, 1.0)
		prix[str(cat)] = snappedf(lerpf(float(eco.prix_max), float(eco.prix_min), ratio), 0.01)
	sim.territoire["prix"] = prix


## Le facteur de prix d'un objet chez un marchand : celui de sa catégorie dans le territoire de sa ville (1 sinon).
static func facteur_economie(sim: Simulation, uid: String, pnj: Dictionary) -> float:
	var t: Dictionary = sim.territoires.get(str(pnj.get("village", "")), {})
	if t.is_empty() or not t.has("prix"):
		return 1.0
	var cat := categorie_economique(sim, sim.items.get(uid, {}))
	return float(t.prix.get(cat, 1.0)) if not cat.is_empty() else 1.0


## La taxe de la ville à son royaume : une part de l'or produit dans la semaine (Villes B3 ; D en fait un pays).
static func _taxe_royaume(sim: Simulation, or_prod: int) -> void:
	var roy_id := str(sim.territoire.get("proprietaire", ""))
	if or_prod <= 0 or roy_id.is_empty() or roy_id == "joueur" or sim.monde == null:
		return
	var roy: Dictionary = {}
	for sect in sim.monde.surface.royaumes_cache.values():
		if sect.has(roy_id):
			roy = sect[roy_id]
	if roy.is_empty():
		return
	var taxe := int(round(float(or_prod) * float(roy.taxes.get("base_rate", 0.08))))
	if taxe <= 0:
		return
	sim.territoire.tresor = int(sim.territoire.tresor) - taxe
	sim.monde.tresors_royaumes[roy_id] = int(sim.monde.tresors_royaumes.get(roy_id, 0)) + taxe
	EventBus.emettre(&"journal", [&"journal.taxe_royaume", {"ville": str(sim.territoire.get("id", "")), "n": taxe}])


## Les villes reliées à une ville par la route, à `distance_max` cellules : leurs fiches d'agglomération.
static func villes_reliees(sim: Simulation, centre: Vector2i, distance_max: int) -> Array:
	var res: Array = []
	var vus := {centre: 0}
	var file: Array = [centre]
	while not file.is_empty():
		var c: Vector2i = file.pop_front()
		var d: int = int(vus[c])
		if d >= distance_max:
			continue
		for v in sim.monde.surface.route_de(c):
			if vus.has(v):
				continue
			vus[v] = d + 1
			file.append(v)
			if v != centre and bool(sim.monde.surface.poi_de(v).get("village", false)):
				res.append(sim.monde.surface.fiche_agglomeration(v))
	return res


## Le jour de marché d'une ville chargée, les marchands itinérants des villes reliées arrivent (Villes B3) ; ceux
## de la veille repartent.
static func _caravanes_du_jour(sim: Simulation, jour: int) -> void:
	var cv: Dictionary = GameData.config("villes").economie.caravane
	for x in sim.vivants():   # la veille repart
		if x.has("itinerant") and int(x.itinerant.get("jour", -1)) < jour:
			EventBus.emettre(&"journal", [&"journal.itinerant_part", {"origine": str(x.itinerant.get("depuis", ""))}])
			sim.grille.liberer(x.pos)
			x.vivant = false
			sim.ordre.erase(x.id)
			sim.entites.erase(x.id)
	var d := Calendrier.date(jour)
	for nom in sim.territoires.keys():
		var t: Dictionary = sim.territoires[nom]
		if str(nom) == "joueur" or not t.has("agglomeration") or not _territoire_charge(sim, str(nom)):
			continue
		if Calendrier.jour_de_marche(str(nom)) != str(d.jour_semaine):
			continue
		var centre: Vector2i = t.agglomeration.get("centre", Vector2i(-1, -1))
		if absi(centre.x - sim.monde.centre.x) > sim.monde.rayon or absi(centre.y - sim.monde.centre.y) > sim.monde.rayon:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.graine, "caravane", str(nom), jour])
		var roy_ici := str(sim.monde.surface.royaume_de(centre).get("id", ""))
		for f in villes_reliees(sim, centre, int(cv.distance_max)):
			if rng.randf() >= float(cv.chance) or SimRoyaumes.en_guerre(sim, roy_ici, str(f.get("royaume", ""))):   # pas de caravane entre deux royaumes en guerre (D)
				continue
			_arrivee_itinerant(sim, str(nom), f, jour)


## Un marchand itinérant arrive au marché de `ville` depuis la ville `origine` : posé au bord de la place, l'étal
## garni de la caravane, une part du surplus de l'origine transférée aux stocks de la destination.
static func _arrivee_itinerant(sim: Simulation, ville: String, origine: Dictionary, jour: int) -> Dictionary:
	var cv: Dictionary = GameData.config("villes").economie.caravane
	var t: Dictionary = sim.territoires[ville]
	var centre_cell: Vector2i = t.agglomeration.centre
	var e_c: Dictionary = sim.monde.cellule(centre_cell)
	var place: Vector2i = sim.monde.pos_monde(centre_cell, e_c.get("village", {}).get("centre", Vector2i(sim.monde.taille / 2, sim.monde.taille / 2)))
	var pos: Vector2i = sim._tuile_libre_autour(place + Vector2i(int(GameData.config("villes").rayon_place), 0))
	if not sim.grille.dans(pos) or not sim.grille.occupant(pos).is_empty():
		return {}
	var x: Dictionary = SimObjets.ajouter(sim, str(cv.creature), pos, "ia")
	if x.is_empty():
		return {}
	SimObjets._habiller_pnj(sim, x, GameData.entree("creatures", str(cv.creature)), str(origine.get("culture", "")))
	x.camp = "civil"
	x["village"] = str(origine.nom)
	x["royaume"] = str(origine.get("royaume", ""))
	x["itinerant"] = {"depuis": str(origine.nom), "ville": ville, "jour": jour}
	x["place"] = place
	x["poste"] = pos
	x["lit"] = pos
	x.ancre = pos
	x.stock = []
	SimObjets._garnir_stock(sim, x, cv.selection)
	# Le surplus de l'origine voyage : une part de chaque catégorie excédentaire passe dans les stocks de la destination.
	var to: Dictionary = sim.territoires.get(str(origine.nom), {})
	if not to.is_empty() and to.has("agglomeration"):
		var eco: Dictionary = GameData.config("villes").economie
		var pop_o := maxi(1, int(to.agglomeration.get("population", 1)))
		_dans_territoire(sim, str(origine.nom), func() -> void: _transferer_surplus(sim, t, pop_o, eco))
	EventBus.emettre(&"journal", [&"journal.itinerant_arrive", {"origine": str(origine.nom), "ville": ville}])
	return x


## Dans le contexte de l'origine : chaque catégorie au-delà de son surplus cède `part_transferee` à `dest`.
static func _transferer_surplus(sim: Simulation, dest: Dictionary, pop_o: int, eco: Dictionary) -> void:
	var cv: Dictionary = eco.caravane
	var par_cat := stocks_par_categorie(sim)
	for cat in eco.consommation.keys():
		var seuil := float(pop_o) * float(eco.consommation[cat]) * float(eco.semaines_surplus)
		var exces := int(par_cat.get(str(cat), 0)) - int(ceil(seuil))
		if exces <= 0:
			continue
		var n := maxi(1, int(round(float(exces) * float(cv.part_transferee))))
		var cles: Array = sim.territoire.stocks.keys()
		for cle in cles:
			if n <= 0:
				break
			if _categorie_cle(sim, str(cle)) != str(cat):
				continue
			var q := mini(int(sim.territoire.stocks[cle]), n)
			sim.territoire.stocks[cle] = int(sim.territoire.stocks[cle]) - q
			if int(sim.territoire.stocks[cle]) <= 0:
				sim.territoire.stocks.erase(cle)
			dest.stocks[cle] = int(dest.stocks.get(cle, 0)) + q
			n -= q


## Le passage hebdomadaire du territoire : production, entretien, dette et ses paliers, taxe de guilde, rapport.
static func _semaine_territoire(sim: Simulation, e: Dictionary) -> void:
	if sim.monde == null or sim.monde.claims.is_empty():
		return
	var horloge_debut_semaine := Time.get_ticks_usec()
	var ry := _ry(sim)
	var prod_txt: Array[String] = []
	var prod_par := {}   # cumulé par matière, l'or en une somme (grande base, 2026-09-04)
	var or_prod := 0
	for x in residents(sim):
		var pr := production_de(sim, x)
		if pr.is_empty():
			continue
		if bool(pr.get("sans_stockage", false)):   # un poste sans stockage ne produit pas, et on le dit
			EventBus.emettre(&"journal", [&"journal.poste_sans_stockage", {"nom": x.name_key}])
			continue
		if pr.has("or"):
			or_prod += int(pr.or)
			prod_par["or"] = int(prod_par.get("or", 0)) + int(pr.or)
		elif int(pr.n) > 0:
			var cle: String = pr.base + ("|" + pr.forme if not str(pr.forme).is_empty() else "")
			sim.territoire.stocks[cle] = int(sim.territoire.stocks.get(cle, 0)) + int(pr.n)
			prod_par[str(pr.base)] = int(prod_par.get(str(pr.base), 0)) + int(pr.n)
			if pr.has("perimetre") and SimPerimetres.perimetres(sim).has(str(pr.perimetre)):   # pris sur la réserve du périmètre
				var per_p: Dictionary = SimPerimetres.perimetres(sim)[str(pr.perimetre)]
				per_p.reserve = maxf(0.0, float(per_p.get("reserve", 0.0)) - float(pr.n))
			if pr.has("stockage") and SimPerimetres.perimetres(sim).has(str(pr.stockage)):   # et rangé dans son stockage
				var st: Dictionary = SimPerimetres.perimetres(sim)[str(pr.stockage)]
				if not st.has("contenu"):
					st["contenu"] = {}
				st.contenu[cle] = int(st.contenu.get(cle, 0)) + int(pr.n)
				if SimPerimetres.place_stockage(sim, str(st.id)) <= 0:
					EventBus.emettre(&"journal", [&"journal.stockage_plein", {"x": st.cellule.x, "y": st.cellule.y}])
	sim.territoire.tresor = int(sim.territoire.tresor) + or_prod
	_taxe_royaume(sim, or_prod)   # une ville verse sa part au royaume (Villes B3)
	var t0: int = sim._top("t.production", horloge_debut_semaine)
	# Ressources naturelles : la régénération efface le bâti de la cellule.
	for cell in sim.monde.claims.keys():
		if str(sim.monde.claims[cell].role) == "ressources":
			sim.monde.modifications.erase(cell)
	SimPerimetres._repousser_perimetres(sim)
	SimVilles._recolter_champs(sim)   # les fermiers récoltent et ressèment (Villes B2)
	SimVilles._semaine_betail(sim)
	if str(sim.territoire.get("id", "joueur")) != "joueur":
		_semaine_economie(sim)   # le besoin, l'usure, les prix (Villes B3) — le camp du joueur n'a pas de prix
	t0 = sim._top("t.repousser", t0)
	_nourrir_residents(sim)   # le repas de la semaine (Faim des PNJ) : une fois, avant les maisons et le bilan
	t0 = sim._top("t.nourrir", t0)
	SimPerimetres._batir_maisons(sim)   # les maisons automatiques du résidentiel (Population et exploitation, 2026-09-04)
	t0 = sim._top("t.maisons", t0)
	var entretien := int(ry.entretien_pnj) * residents(sim).size() + int(ry.entretien_structure) * _structures_speciales(sim)
	if str(sim.territoire.get("proprietaire", "joueur")) != "joueur":
		entretien = 0   # une ville qui n'est pas au joueur ne lui doit pas de gages : son budget propre vient avec l'économie (B3)
	if not str(sim.territoire.gouvernance).is_empty():
		var g: Dictionary = GameData.entree("governments", str(sim.territoire.gouvernance))
		entretien = int(round(float(entretien) * float(g.base_rate) / float(ry.gouvernance.base_rate_ref)))
	var du := entretien + int(sim.territoire.dette)
	if int(sim.territoire.tresor) >= du:
		sim.territoire.tresor = int(sim.territoire.tresor) - du
		sim.territoire.dette = 0
		sim.territoire.semaines_dette = 0
		sim.territoire["productivite"] = 1.0
	else:
		sim.territoire.dette = du - int(sim.territoire.tresor)
		sim.territoire.tresor = 0
		sim.territoire.semaines_dette = int(sim.territoire.semaines_dette) + 1
	var pal: Dictionary = ry.dette_paliers
	_recalculer_humeurs(sim)   # chaque semaine (Habitat des PNJ) — en dette aussi : le palier est un état, pas une pente (2026-09-04)
	t0 = sim._top("t.humeurs", t0)
	if int(sim.territoire.semaines_dette) >= int(pal.humeur[0]):
		for x in residents(sim):
			x.humeur = int(x.get("humeur", ry.humeur_base)) + int(pal.humeur[1])
		EventBus.emettre(&"journal", [&"journal.dette_palier", {"texte": "dette.humeur"}])
	if int(sim.territoire.semaines_dette) >= int(pal.productivite[0]):
		sim.territoire["productivite"] = float(pal.productivite[1])
		EventBus.emettre(&"journal", [&"journal.dette_palier", {"texte": "dette.productivite"}])
	if int(sim.territoire.semaines_dette) >= int(pal.depart[0]) and not residents(sim).is_empty():
		var moins_fidele: Dictionary = residents(sim)[0]
		for x in residents(sim):
			if SimPnj.relation_de(sim, x, e) < SimPnj.relation_de(sim, moins_fidele, e):
				moins_fidele = x
		_quitter_le_territoire(sim, moins_fidele)   # il part pour de bon (Entretien et taxes : « quitter le territoire », 2026-09-04)
		EventBus.emettre(&"journal", [&"journal.dette_palier", {"texte": "dette.depart"}])
	# Taxe de guilde sur les gains de quêtes de la semaine (Entretien et taxes).
	var gains := int(sim.territoire.get("gains_quetes", 0))
	if gains > 0:
		var rang := int(e.get("guildes", {}).get("guerriers", {}).get("rang", 0))
		var taxe := int(round(float(gains) * float(ry.taxe_guilde) * (1.0 + float(ry.taxe_rang) * maxi(0, rang - 1))))
		e.or = maxi(0, int(e.or) - taxe)
		sim.territoire.gains_quetes = 0
		if taxe > 0:
			EventBus.emettre(&"journal", [&"journal.taxe_guilde", {"n": taxe}])
	# Transition de gouvernance (Gouvernance, lois et diplomatie).
	if int(sim.territoire.transition) > 0:
		sim.territoire.transition = int(sim.territoire.transition) - 1
		if int(sim.territoire.transition) == 0:
			sim.territoire.gouvernance = str(sim.territoire.gouvernance_cible)
			sim.territoire.gouvernance_cible = ""
			EventBus.emettre(&"journal", [&"journal.gouvernance_faite", {"gouv": GameData.entree("governments", str(sim.territoire.gouvernance)).name_key}])
	SimRoyaumes._semaine_accords(sim)
	SimRoyaumes._jet_raid(sim, e, sim.horloge_monde.ticks)
	sim._top("t.fin", t0)
	for b in prod_par.keys():
		if str(b) == "or":
			prod_txt.append("%d or" % int(prod_par[b]))
		else:   # le nom traduit de la matière ou de l'objet, pas son id (vu « champignon_des_pres » au rapport)
			var fiche_b: Dictionary = GameData.catalogues.materials.get(str(b), GameData.catalogues.items.get(str(b), {}))
			prod_txt.append("%s ×%d" % [TranslationServer.translate(str(fiche_b.get("name_key", str(b)))), int(prod_par[b])])
	var rapport := {"prod": " · ".join(prod_txt) if not prod_txt.is_empty() else "—", "entretien": entretien, "tresor": int(sim.territoire.tresor), "dette": int(sim.territoire.dette)}
	sim.territoire.rapports.append(rapport)
	while sim.territoire.rapports.size() > 8:
		sim.territoire.rapports.pop_front()
	EventBus.emettre(&"journal", [&"journal.rapport_semaine", rapport])


static func _structures_speciales(sim: Simulation) -> int:
	var n: int = sim.territoire.get("halls", {}).size()
	if sim.monde == null:
		return 0
	for gi in sim.grille.stations_fixes.keys():
		if sim.monde.claims.has(SimCamp._cell_de(sim, sim.grille.pos_de(int(gi)))):
			n += 1
	return n


## Le prévisionnel hebdomadaire (revenus en or − entretien).
static func previsionnel(sim: Simulation) -> int:
	var revenus := 0
	for x in residents(sim):
		var pr := production_de(sim, x)
		if pr.has("or"):
			revenus += int(pr.or)
	return revenus - (int(_ry(sim).entretien_pnj) * residents(sim).size() + int(_ry(sim).entretien_structure) * _structures_speciales(sim))


static func deposer(sim: Simulation, e: Dictionary, n: int) -> bool:
	if int(e.or) < n:
		return false
	e.or = int(e.or) - n
	sim.territoire.tresor = int(sim.territoire.tresor) + n
	EventBus.emettre(&"journal", [&"journal.depot", {"n": n, "tresor": int(sim.territoire.tresor)}])
	return true


static func retirer(sim: Simulation, e: Dictionary, n: int) -> bool:
	n = mini(n, int(sim.territoire.tresor))
	if n <= 0:
		EventBus.emettre(&"journal", [&"journal.tresor_vide", {}])
		return false
	sim.territoire.tresor = int(sim.territoire.tresor) - n
	e.or = int(e.or) + n
	EventBus.emettre(&"journal", [&"journal.retrait", {"n": n, "tresor": int(sim.territoire.tresor)}])
	return true


## Retirer un stock du territoire dans le sac (matériaux et consommables).
static func retirer_stock(sim: Simulation, e: Dictionary, cle: String) -> bool:
	var n := int(sim.territoire.stocks.get(cle, 0))
	if n <= 0:
		return false
	var parts: PackedStringArray = cle.split("|")
	if parts.size() > 1 and GameData.catalogues.materials.has(parts[0]):
		SimTerrain._donner_materiau(sim, e, parts[0], n, parts[1])
	else:   # un objet (baies, ortie, champignon : la récolte d'un périmètre de plantes porte aussi « |brut »), pas une matière
		for k in n:
			var o: Dictionary = SimObjets.generer_objet(sim, parts[0], 1, {}, "commun", 0)
			if not o.is_empty():
				SimObjets.donner(sim, e, o.uid)
	sim.territoire.stocks.erase(cle)
	SimPerimetres._retirer_des_stockages(sim, cle, n)   # le joueur a pris : les stockages suivent
	EventBus.emettre(&"journal", [&"journal.stock_retire", {"nom": parts[0], "n": n}])
	return true


## La puissance d'un matériau paramétrique : stat de la créature / 10, bornée.
static func _puissance_de(sim: Simulation, valeur: int) -> float:
	var al: Dictionary = sim.regles.r.alchimie
	return snappedf(clampf(float(valeur) / float(al.puissance_div), float(al.puissance_bornes[0]), float(al.puissance_bornes[1])), 0.1)


# ---------------------------------------------------------------- capacités : slots et assemblage (Structure compétences-modules-slots)
