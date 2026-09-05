class_name SimCamp
extends RefCounted
## Le camp : poser, murs, démonter, coffres, ranger, prendre, dormir, voyager ; les parcelles et la boutique passive ; le tick d'un territoire.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


static func _tuile_libre_pour_poser(sim: Simulation, e: Dictionary, vers: Vector2i) -> bool:
	return sim.lieu == "camp" and sim.grille.dans(vers) and Grille.distance(e.pos, vers) == 1 and sim.grille.contenu_de(vers).is_empty() \
		and sim.grille.occupant(vers).is_empty() and not sim.contenants.has(sim.grille.idx(vers))


## Poser un meuble ou une station portative du sac sur une tuile adjacente (Construction cadrée).
static func _poser(sim: Simulation, e: Dictionary, uid: String, vers: Vector2i, tick: int) -> bool:
	var it: Dictionary = sim.items.get(uid, {})
	if not (uid in e.sac) or not it.get("type", "") in ["meuble", "station"]:
		return false
	if not _tuile_libre_pour_poser(sim, e, vers):
		EventBus.emettre(&"journal", [&"journal.rien_a_poser", {}])
		return false
	var idx := sim.grille.idx(vers)
	if sim.monde != null and sim.monde.claims.has(_cell_de(sim, vers)):
		SimPnj._progresser_quetes(sim, e, "construire", ["meuble" if it.type == "meuble" else "station"])
	if it.type == "meuble":
		var m: Dictionary = GameData.entree("meubles", str(it.meuble))
		sim.grille.poser_contenu(vers, "meuble" if bool(m.bloque_passage) else "meuble_sol")
		sim.grille.meubles[idx] = str(it.meuble)
		if int(m.capacite_slots) > 0:
			sim.contenants[idx] = []
		if str(m.type_meuble) == "etal" and sim.monde != null:
			sim.territoire.etals[_pm(sim, vers)] = true
		if str(m.type_meuble) == "hall":
			var guilde: String = SimTerritoire._meilleure_guilde(sim, e)
			if guilde.is_empty():
				sim.grille.contenu[idx] = 0
				sim.grille.meubles.erase(idx)
				EventBus.emettre(&"journal", [&"journal.hall_refuse", {}])
				return false
			var vil: Dictionary = SimTerritoire._ry(sim).villes
			for d in Grille.DIRS:
				var q: Vector2i = vers + d
				if sim.grille.dans(q) and not sim.grille.bloque_passage(q) and sim.grille.occupant(q).is_empty():
					var maitre: Dictionary = SimObjets.ajouter(sim, str(vil.creature_hall), q, "ia")
					SimObjets._habiller_pnj(sim, maitre, GameData.entree("creatures", str(vil.creature_hall)))
					maitre["guilde"] = guilde
					maitre["hall"] = vers
					maitre["lit"] = q
					maitre["poste"] = q
					maitre.ancre = q
					break
			if not sim.territoire.has("halls"):
				sim.territoire["halls"] = {}
			sim.territoire.halls[_pm(sim, vers)] = guilde
			EventBus.emettre(&"journal", [&"journal.hall_pose", {"guilde": "guilde.%s.name" % guilde}])
	else:
		if sim.monde != null and str(sim.monde.claims.get(sim.monde.cellule_de(vers), {}).get("role", "base")) == "champs" and str(it.station) in SimTerritoire._ry(sim).stations_lourdes:
			EventBus.emettre(&"journal", [&"journal.station_refusee", {}])
			return false
		sim.grille.poser_contenu(vers, "station_fixe")
		sim.grille.stations_fixes[idx] = str(it.station)
	e.sac.erase(uid)
	e["objets_poses"] = e.get("objets_poses", {})
	e.objets_poses[idx] = uid
	e.compteur = tick + int(sim.regles.r.camp.poser_ticks)
	EventBus.emettre(&"journal", [&"journal.pose", {"nom": e.name_key, "objet": SimObjets.nom_objet(sim, uid)}])
	EventBus.emettre(&"tile_changed", [vers])
	return true


## Un mur (1 unité de pierre taillée / planche / brique) ou une porte (1 planche) sur une tuile adjacente.
static func _poser_mur(sim: Simulation, e: Dictionary, vers: Vector2i, porte: bool, tick: int) -> bool:
	if not _tuile_libre_pour_poser(sim, e, vers):
		EventBus.emettre(&"journal", [&"journal.rien_a_poser", {}])
		return false
	var familles: Array = [str(sim.regles.r.camp.porte_famille)] if porte else sim.regles.r.camp.mur_familles
	var pile := {}
	for f in familles:
		pile = SimFabrication._pile_famille(sim, e, GameData.config("material_families").get(str(f), {}))
		if not pile.is_empty():
			break
	if pile.is_empty():
		EventBus.emettre(&"journal", [&"journal.pas_de_materiau_mur", {}])
		return false
	var mat_id := str(pile.materiau)
	SimTerrain._retirer_materiau(sim, e, pile, 1)
	sim.grille.poser_contenu(vers, "porte" if porte else "mur_construit")
	if sim.monde != null and sim.monde.claims.has(_cell_de(sim, vers)):
		SimPnj._progresser_quetes(sim, e, "construire", ["mur"])
	sim.grille.materiaux[sim.grille.idx(vers)] = mat_id
	e.compteur = tick + int(sim.regles.r.camp.poser_ticks)
	EventBus.emettre(&"journal", [&"journal.pose", {"nom": e.name_key, "objet": {"base": "tile_content.%s.name" % ("porte" if porte else "mur_construit")}}])
	EventBus.emettre(&"tile_changed", [vers])
	return true


## Démonter ce qui a été construit sur une tuile adjacente : meuble et station reviennent au sac.
static func _demonter(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if not sim.grille.dans(vers) or Grille.distance(e.pos, vers) != 1:
		return false
	var c := sim.grille.contenu_de(vers)
	if not ("construit" in c.get("tags", [])):
		return false
	var idx := sim.grille.idx(vers)
	if sim.contenants.has(idx) and not sim.contenants[idx].is_empty():
		_prendre(sim, e, vers, tick)   # on vide le coffre d'abord
	var uid: String = str(e.get("objets_poses", {}).get(idx, ""))
	if not uid.is_empty() and sim.items.has(uid):
		e.sac.append(uid)
		e.objets_poses.erase(idx)
		EventBus.emettre(&"journal", [&"journal.demonte", {"nom": e.name_key, "objet": SimObjets.nom_objet(sim, uid)}])
	else:
		EventBus.emettre(&"journal", [&"journal.demonte", {"nom": e.name_key, "objet": {"base": str(c.name_key)}}])
	sim.grille.contenu[idx] = 0
	sim.grille.marquer(vers)
	if sim.monde != null:
		sim.territoire.etals.erase(_pm(sim, vers))
		sim.territoire.cultures.erase(_pm(sim, vers))
		if sim.territoire.get("halls", {}).has(_pm(sim, vers)):
			for x in sim.vivants():
				if x.get("hall", Vector2i(-1, -1)) == vers:
					x.vivant = false
					sim.grille.liberer(x.pos)
			EventBus.emettre(&"journal", [&"journal.hall_demonte", {"guilde": "guilde.%s.name" % str(sim.territoire.halls[_pm(sim, vers)])}])
			sim.territoire.halls.erase(_pm(sim, vers))
	sim.grille.meubles.erase(idx)
	sim.grille.stations_fixes.erase(idx)
	sim.grille.materiaux.erase(idx)
	sim.contenants.erase(idx)
	e.compteur = tick + int(sim.regles.r.camp.poser_ticks)
	EventBus.emettre(&"tile_changed", [vers])
	return true


static func _coffre_a(sim: Simulation, vers: Vector2i) -> Dictionary:
	if not sim.grille.dans(vers) or not sim.grille.meubles.has(sim.grille.idx(vers)):
		return {}
	var m: Dictionary = GameData.entree("meubles", str(sim.grille.meubles[sim.grille.idx(vers)]))
	return m if int(m.capacite_slots) > 0 else {}


## Ranger un objet du sac dans un coffre adjacent (capacité du meuble).
static func _ranger(sim: Simulation, e: Dictionary, uid: String, vers: Vector2i, tick: int) -> bool:
	var m := _coffre_a(sim, vers)
	if m.is_empty() or Grille.distance(e.pos, vers) > 1 or not (uid in e.sac):
		return false
	var idx := sim.grille.idx(vers)
	if sim.contenants.get(idx, []).size() >= int(m.capacite_slots):
		EventBus.emettre(&"journal", [&"journal.coffre_plein", {}])
		return false
	e.sac.erase(uid)
	e.ratelier.erase(uid)
	if not sim.contenants.has(idx):
		sim.contenants[idx] = []
	sim.contenants[idx].append(uid)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.range", {"nom": e.name_key, "objet": SimObjets.nom_objet(sim, uid)}])
	return true


## Prendre tout ce qu'un coffre adjacent contient.
static func _prendre(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if not sim.grille.dans(vers) or Grille.distance(e.pos, vers) > 1:
		return false
	var idx := sim.grille.idx(vers)
	if "parcelle" in sim.grille.contenu_de(vers).get("tags", []):
		return _recolter_culture(sim, e, vers, tick)
	if sim.grille.meubles.has(idx) and str(GameData.entree("meubles", str(sim.grille.meubles[idx])).type_meuble) == "etal" and int(sim.territoire.caisse) > 0:
		e.or = int(e.or) + int(sim.territoire.caisse)
		EventBus.emettre(&"journal", [&"journal.caisse", {"nom": e.name_key, "n": int(sim.territoire.caisse)}])
		sim.territoire.caisse = 0
		e.compteur = tick + int(sim.regles.r.actions.objet)
		return true
	if not sim.contenants.has(idx) or sim.contenants[idx].is_empty():
		return false
	var n := 0
	for uid in sim.contenants[idx]:
		if not (uid in e.sac):
			e.sac.append(uid)
			n += 1
	sim.contenants[idx] = []
	if sim.grille.meubles.has(idx) and sim.monde != null and sim.lieu == "camp" and e.controle == "joueur" and not sim.monde.claims.has(_cell_de(sim, vers)) and bool(sim.monde.cellule(_cell_de(sim, vers)).has("village")):
		SimRoyaumes._infraction(sim, e, "comportement", "vol", vers, "")
	if not sim.grille.meubles.has(idx):   # un butin au sol disparaît ; un coffre reste
		sim.grille.contenu[idx] = 0
		sim.grille.marquer(vers)
		sim.contenants.erase(idx)
		EventBus.emettre(&"tile_changed", [vers])
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.prend", {"nom": e.name_key, "n": n}])
	return true


## Dormir sur un lit adjacent (Cycle jour-nuit et sommeil, la partie sommeil) : le monde avance de
## dormir_ticks, puis vitaux pleins, buff Reposé (xp_mult) et +potentiel aux compétences les plus
## travaillées depuis le dernier repos ; le lit devient le point de respawn.
static func _dormir(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	var lit: String = str(sim.grille.meubles.get(sim.grille.idx(vers), "")) if sim.grille.dans(vers) else ""
	if lit.is_empty() or not bool(GameData.entree("meubles", str(lit)).dormir) or Grille.distance(e.pos, vers) > 1:
		EventBus.emettre(&"journal", [&"journal.pas_de_lit", {}])
		return false
	for x in sim.vivants():
		if SimPnj.ennemis(sim, e, x) and sim.voit(e, x.pos):
			EventBus.emettre(&"journal", [&"journal.hostile_en_vue", {}])
			return false
	var cp: Dictionary = sim.regles.r.camp
	var duree := int(cp.dormir_ticks)
	if sim.lieu == "camp" and SimTerrain.est_nuit(sim):   # saut de nuit : dormir entre 21 h et 5 h avance au matin
		var jour := int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
		var reveil := int(float(SimTerrain._cycle(sim).get("heure_reveil", 5)) / 24.0 * float(jour))
		var dans_jour := posmod(sim.horloge_monde.ticks, jour)
		duree = (reveil - dans_jour) if dans_jour < reveil else (jour - dans_jour + reveil)
		EventBus.emettre(&"journal", [&"journal.dort_nuit", {"nom": e.name_key}])
	e.compteur = tick + duree
	e["lit"] = vers
	e["spawn"] = vers
	# Le monde avance pendant le sommeil (les êtres agissent ; le dormeur est vulnérable).
	var pas_max := 200
	var reste := duree
	while reste > 0 and pas_max > 0:
		var n := mini(reste, 100)
		sim.horloge_monde.avancer(n)
		reste -= n
		pas_max -= 1
		if not sim.territoire.raid.is_empty():   # un raid réveille le dormeur (Défense et raids)
			EventBus.emettre(&"journal", [&"journal.raid_reveil", {}])
			e.compteur = sim.horloge_monde.ticks
			break
	if not e.vivant:
		return true
	e.sante = e.sante_max
	e["sang"] = 0
	e.mana = e.mana_max
	e.vigueur = e.vigueur_max
	e.tick_vigueur = sim.horloge_monde.ticks
	e["repose_jusqua"] = sim.horloge_monde.ticks + int(cp.repose_ticks)
	e["xp_mult"] = float(cp.repose_xp_mult)
	# +potentiel aux compétences consommées récemment (Potentiel : Reposé).
	var travail: Dictionary = e.get("xp_depuis_repos", {})
	var cles: Array = travail.keys()
	cles.sort_custom(func(a: String, b: String) -> bool: return int(travail[a]) > int(travail[b]))
	var cap := int(sim.regles.r.progression.potentiel_max)
	var liste: Array[String] = []
	for cle in cles.slice(0, int(cp.repose_top)):
		e.potentiels[cle] = mini(cap, int(e.potentiels.get(cle, int(sim.regles.r.progression.potentiel_defaut))) + int(cp.repose_potentiel))
		liste.append(sim._nom_competence(cle))
	e["xp_depuis_repos"] = {}
	EventBus.emettre(&"journal", [&"journal.dort", {"nom": e.name_key, "heures": duree / 1000, "potentiel": int(cp.repose_potentiel), "liste": ", ".join(liste) if not liste.is_empty() else "—"}])
	return true


## Voyage rapide (Carte du monde) : vers une cellule de terre déjà explorée ; le temps avance de
## ticks_par_cellule × distance ; le joueur arrive au point marchable du centre (ou à l'entrée du donjon).
static func voyager(sim: Simulation, e: Dictionary, cell: Vector2i, cout_force: int = -1) -> bool:
	if sim.lieu != "camp" or sim.monde == null or e.controle != "joueur":
		return false
	if not sim.monde.surface.terre_a(cell):   # on marche vers l'inconnu : seule l'eau se refuse (designer 2026-09-01)
		EventBus.emettre(&"journal", [&"journal.voyage_impossible", {}])
		return false
	var d := maxi(absi(cell.x - sim.monde.cellule_de(e.pos).x), absi(cell.y - sim.monde.cellule_de(e.pos).y))
	# Le voyage coûte ce que coûterait la marche (designer 2026-09-01, point 59) : la distance en
	# TUILES multipliée par le coût d'un pas de cet être — sa vitesse, sa charge, comprises.
	var tuiles := d * int(GameData.config("planete").taille_cellule)
	var pas := sim.regles.ticks_deplacement(int(sim.regles.r.deplacement.cout_base), e.get("competences_eff", e.get("competences", {})), false)
	var cout := int(round(float(tuiles) * float(pas) * float(sim.poids_de(e).facteur)))
	if not sim.monde.surface.route_de(cell).is_empty() and not sim.monde.surface.route_de(sim.monde.cellule_de(e.pos)).is_empty():   # par la route (Carte du monde)
		cout = int(round(float(cout) * float(GameData.config("planete").voyage.get("route_mult", 1.0))))
	if cout_force >= 0:
		cout = cout_force   # le train a son propre temps (Villes B4)
	var ec := sim.monde.cellule(cell)
	var ou: Vector2i = sim.monde.pos_monde(cell, ec.entree_donjon + Vector2i(0, 1)) if bool(ec.get("a_donjon", false)) else sim.monde.point_marchable(cell)
	if sim.en_combat(e):
		sim._quitter_combat(e)   # on ne voyage pas en gardant un combat derrière soi
	sim.grille.liberer(e.pos)
	e.pos = ou
	SimLieux._verifier_fenetre(sim, e)
	if not sim.grille.occupant(ou).is_empty() or sim.grille.bloque_passage(ou):
		ou = sim.monde.point_marchable(cell)
		e.pos = ou
	sim.grille.placer(e.id, ou)
	e.compteur = sim.horloge_monde.ticks + cout
	sim.horloge_monde.avancer(cout)
	sim.maj_vision()
	EventBus.emettre(&"journal", [&"journal.voyage", {"nom": e.name_key, "x": cell.x, "y": cell.y, "ticks": cout}])
	SimLieux.entrer_donjon_de_la_cellule(sim, e)   # arriver sur la cellule d'un donjon, c'est y entrer (designer 2026-09-02)
	return true


# ---------------------------------------------------------------- dialogue (E.23) et commerce (Prix suggéré)

static func _pm(sim: Simulation, vers: Vector2i) -> Vector2i:
	return vers


## La cellule d'une tuile locale de la grille courante.
static func _cell_de(sim: Simulation, vers: Vector2i) -> Vector2i:
	return sim.monde.cellule_de(vers)


## Planter une culture (Agriculture et élevage) : 1 unité consommée, sur une tuile libre voisine d'une cellule Champs.
static func _planter(sim: Simulation, e: Dictionary, base: String, tick: int) -> bool:
	if sim.monde == null or sim.lieu != "camp" or not GameData.catalogues.plants.has(base):
		return false
	var pile: Dictionary = SimTerrain._pile_objet(sim, e, base)
	if pile.is_empty():
		return false
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var vers: Vector2i = e.pos + d
		if not sim.grille.dans(vers) or not sim.grille.contenu_de(vers).is_empty() or sim.grille.meubles.has(sim.grille.idx(vers)) or sim.grille.h(vers) != sim.grille.h(e.pos):
			continue
		if str(sim.monde.claims.get(_cell_de(sim, vers), {}).get("role", "")) != "champs":
			continue
		var occupe := false
		for x in sim.vivants():
			if x.pos == vers:
				occupe = true
		if occupe:
			continue
		_consommer_pile(sim, e, pile)
		var pl: Dictionary = GameData.catalogues.plants[base]
		var duree := float(pl.duree_jours) * float(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
		if "arrose" in GameData.catalogues.weather_states.get(str(SimTerrain.meteo(sim, _cell_de(sim, vers))), {}).get("effects", []):   # Météo : pluie ET orage arrosent (tag arrose)
			duree *= 1.0 - float(SimTerritoire._ry(sim).agriculture.pluie_bonus)
		SimVilles._semer_tuile(sim, vers, base, tick, 1.0 - duree / (float(pl.duree_jours) * float(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))))   # la pluie a déjà avancé la pousse
		e.compteur = tick + int(sim.regles.r.actions.objet)
		EventBus.emettre(&"tile_changed", [vers])
		EventBus.emettre(&"journal", [&"journal.plante", {"nom": e.name_key, "plante": pl.name_key}])
		return true
	EventBus.emettre(&"journal", [&"journal.planter_refuse", {}])
	return false


static func _consommer_pile(sim: Simulation, e: Dictionary, pile: Dictionary) -> void:
	pile.quantite = int(pile.quantite) - 1
	if int(pile.quantite) <= 0:
		e.sac.erase(pile.uid)
		e.ratelier.erase(pile.uid)


static func fertilite_a(sim: Simulation, pm: Vector2i, vers: Vector2i) -> int:
	if sim.territoire.fertilite.has(pm):
		return int(sim.territoire.fertilite[pm])
	var sol := str(sim.grille.sols.get(sim.grille.idx(vers), ""))
	if sol.is_empty():
		return int(SimTerritoire._ry(sim).agriculture.fertilite_defaut)
	return int(GameData.catalogues.materials.get(sol, {}).get("stats", {}).get("fertilite", SimTerritoire._ry(sim).agriculture.fertilite_defaut))


## Fertiliser une parcelle adjacente avec un engrais brut du sac (Guano 95, Phosphorite 80, Tourbe compactée 55).
static func _fertiliser(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if sim.monde == null or not sim.grille.dans(vers) or Grille.distance(e.pos, vers) > 1 or not sim.territoire.cultures.has(_pm(sim, vers)):
		return false
	var engrais: Dictionary = SimTerritoire._ry(sim).agriculture.engrais
	for mat in engrais.keys():
		var pile: Dictionary = SimTerrain._pile(sim, e, str(mat), "brut")
		if pile.is_empty():
			continue
		_consommer_pile(sim, e, pile)
		sim.territoire.fertilite[_pm(sim, vers)] = int(engrais[mat])
		e.compteur = tick + int(sim.regles.r.actions.objet)
		EventBus.emettre(&"journal", [&"journal.fertilise", {"fertilite": int(engrais[mat])}])
		return true
	return false


## Récolter une parcelle mûre : recolte_base × farming_yield(biome) × (0,5 + fertilité/100), ×0,5 en canicule.
static func _recolter_culture(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	var pm := _pm(sim, vers)
	var c: Dictionary = sim.territoire.cultures.get(pm, {})
	if c.is_empty() or tick < int(c.echeance):
		EventBus.emettre(&"journal", [&"journal.culture_pas_mure", {}])
		return false
	var cell := _cell_de(sim, vers)
	var biome := str(sim.monde.cellule(cell).get("biome", ""))
	var fy := float(GameData.catalogues.biomes.get(biome, {}).get("farming_yield", 1.0))
	var pl: Dictionary = GameData.catalogues.plants[str(c.plante)]
	var ag: Dictionary = sim.regles.r.get("agriculture_recolte", {})
	var alea := float(sim.des.jet(str(ag.get("des", "2d6")))) / float(ag.get("moyenne", 7.0))   # jamais deux récoltes identiques
	var q := float(pl.recolte_base) * fy * (0.5 + float(fertilite_a(sim, pm, vers)) / 100.0) * alea \
		* sim.regles.skill_factor(sim.regles.niveau(e.competences_eff, str(ag.get("competence", "agriculture"))))
	if SimTerrain.meteo(sim, cell) == "canicule":
		q *= float(SimTerritoire._ry(sim).agriculture.canicule_facteur)
	var n := maxi(1, roundi(q))
	for k in n:
		var o: Dictionary = SimObjets.generer_objet(sim, str(c.plante), 1, {}, "commun", 0)
		if not o.is_empty():
			SimObjets.donner(sim, e, o.uid)
	sim.territoire.cultures.erase(pm)
	sim.territoire.fertilite.erase(pm)
	sim.grille.contenu[sim.grille.idx(vers)] = 0
	sim.grille.marquer(vers)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"tile_changed", [vers])
	EventBus.emettre(&"journal", [&"journal.recolte_culture", {"nom": e.name_key, "plante": pl.name_key, "n": n}])
	return true


## L'heure du territoire (Abstraction hors-site) : mûrissement des parcelles, ventes des boutiques.
## Rattrape toutes les heures dues — nuit sautée, voyage, retour d'expédition.
static func _tiquer_territoire(sim: Simulation, tick: int) -> void:
	if sim.monde == null or sim.lieu != "camp":
		return
	SimTerritoire._dans_territoire(sim, "joueur", func() -> void: _tiquer_territoire_courant(sim, tick))
	for id in sim.territoires.keys():
		if str(id) != "joueur" and SimTerritoire._territoire_charge(sim, str(id)):
			SimTerritoire._dans_territoire(sim, str(id), func() -> void: _tiquer_territoire_courant(sim, tick))


static func _tiquer_territoire_courant(sim: Simulation, tick: int) -> void:
	var h_ticks := int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000)) / 24
	var heure_idx := tick / h_ticks
	if int(sim.territoire.heure_resolue) < 0:
		sim.territoire.heure_resolue = heure_idx
	var maxi_h := int(SimTerritoire._ry(sim).boutique.heures_max_rattrapage)
	sim.territoire.heure_resolue = maxi(int(sim.territoire.heure_resolue), heure_idx - maxi_h)
	while int(sim.territoire.heure_resolue) < heure_idx:
		sim.territoire.heure_resolue = int(sim.territoire.heure_resolue) + 1
		var t := int(sim.territoire.heure_resolue) * h_ticks
		_heure_parcelles(sim, t)
		_heure_boutique(sim, t)


static func _heure_parcelles(sim: Simulation, t: int) -> void:
	for pm in sim.territoire.cultures.keys():
		var c: Dictionary = sim.territoire.cultures[pm]
		if bool(c.mure) or t < int(c.echeance):
			continue
		c.mure = true
		sim.territoire.absence.mures = int(sim.territoire.absence.mures) + 1
		var local: Vector2i = pm
		if sim.grille.dans(local):
			sim.grille.poser_contenu(local, "culture_mure")
			sim.grille.marquer(local)
			EventBus.emettre(&"tile_changed", [local])
		if str(sim.territoire.get("id", "joueur")) == "joueur":   # les deux cents parcelles d'une ville ne s'annoncent pas une à une (Villes B2)
			EventBus.emettre(&"journal", [&"journal.culture_mure", {"plante": GameData.catalogues.plants[str(c.plante)].name_key}])


static func population_autour(sim: Simulation, cell: Vector2i) -> int:
	var r := int(SimTerritoire._ry(sim).boutique.rayon)
	var n := 0
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			n += sim.monde.cellule(cell + Vector2i(dx, dy)).get("village", {}).get("pnj", []).size()
	return n


static func _stock_etal(sim: Simulation, pm: Vector2i) -> Array:
	var local: Vector2i = pm
	if sim.grille.dans(local):
		return sim.contenants.get(sim.grille.idx(local), [])
	return sim.monde.contenants_hors.get(sim.monde.cellule_de(pm), {}).get(sim.monde.idx_local(pm), [])


## Une heure de boutique passive : trafic par formule, clients accumulés, acceptation du prix par aléa.
static func _heure_boutique(sim: Simulation, t: int) -> void:
	if sim.territoire.etals.is_empty():
		return
	var b: Dictionary = SimTerritoire._ry(sim).boutique
	var joueur: Dictionary = {}
	for x in sim.entites.values():
		if x.controle == "joueur":
			joueur = x
	var rep := int(joueur.get("reputations", {}).get("_globale", 0))
	for pm in sim.territoire.etals.keys():
		var stock := _stock_etal(sim, pm)
		if stock.is_empty():
			continue
		var trafic := (float(b.clients_base) + float(b.par_habitant) * float(population_autour(sim, sim.monde.cellule_de(pm)))) * (1.0 + float(rep) / 100.0)
		if not sim.monde.surface.route_de(sim.monde.cellule_de(pm)).is_empty():   # l'accessibilité (Boutique passive)
			trafic *= float(b.get("route_mult", 1.0))
		sim.territoire.clients = float(sim.territoire.clients) + trafic
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.graine, t, pm])
		while float(sim.territoire.clients) >= 1.0 and not stock.is_empty():
			sim.territoire.clients = float(sim.territoire.clients) - 1.0
			var uid: String = str(stock[rng.randi() % stock.size()])
			var ref := int(SimPnj.prix_suggere(sim, uid, {}, joueur).prix)
			var affiche := maxi(1, roundi(float(ref) * float(sim.territoire.marge)))
			if float(affiche) <= float(ref) * rng.randf_range(float(b.acceptation[0]), float(b.acceptation[1])):
				stock.erase(uid)
				sim.territoire.caisse = int(sim.territoire.caisse) + affiche
				sim.territoire.absence.ventes = int(sim.territoire.absence.ventes) + 1
				sim.territoire.absence.or = int(sim.territoire.absence.or) + affiche
				EventBus.emettre(&"journal", [&"journal.vente_boutique", {"objet": SimObjets.nom_objet(sim, uid), "n": affiche}])


static func regler_marge(sim: Simulation, delta: float) -> void:
	var b: Dictionary = SimTerritoire._ry(sim).boutique
	sim.territoire.marge = snappedf(clampf(float(sim.territoire.marge) + delta, float(b.marge_bornes[0]), float(b.marge_bornes[1])), 0.01)
	EventBus.emettre(&"journal", [&"journal.marge", {"marge": sim.territoire.marge}])


## Le rapport d'absence (Abstraction hors-site) : au retour d'expédition, ce que le territoire a fait.
static func _rapport_absence(sim: Simulation) -> void:
	var a: Dictionary = sim.territoire.absence
	if int(a.ventes) + int(a.mures) > 0:
		EventBus.emettre(&"journal", [&"journal.rapport_absence", {"ventes": int(a.ventes), "or": int(a.or), "mures": int(a.mures)}])
	sim.territoire.absence = {"ventes": 0, "or": 0, "mures": 0}


# ---------------------------------------------------------------- compagnons, apprivoisement, âge
