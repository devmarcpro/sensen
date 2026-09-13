class_name SimCamp
extends RefCounted
## Le camp : poser, murs, démonter, coffres, ranger, prendre, dormir, voyager ; les parcelles et la boutique passive ; le tick d'un territoire.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


## UN MEUBLE SE POSE SUR UN MEUBLE (designer 2026-09-08 : « on peut aussi mettre des meubles les uns sur les
## autres »). La tuile doit être libre — ou porter DÉJÀ des meubles, et pas plus que `camp.meuble_pile_max` : on
## empile alors dessus. Ce qui n'est pas un meuble (un mur, un arbre, une porte) barre toujours.
static func _tuile_libre_pour_poser(sim: Simulation, e: Dictionary, vers: Vector2i) -> bool:
	if not (sim.lieu == "camp" and sim.grille.dans(vers) and Grille.distance(e.pos, vers) == 1) \
			or not sim.grille.occupant(vers).is_empty():
		return false
	var idx_l := sim.grille.idx(vers)
	if sim.grille.contenu_de(vers).is_empty():
		return not sim.contenants.has(idx_l)
	var pile_l: Array = sim.grille.meubles_de(idx_l)
	return not pile_l.is_empty() and pile_l.size() < int(sim.regles.r.camp.get("meuble_pile_max", 3))


## Ce que cet être a posé sur une tuile, du bas vers le haut. Une sauvegarde d'avant le 2026-09-09 y range une
## CHAÎNE (une tuile ne portait qu'un meuble) : on la relit comme une liste d'un élément, sans migration.
static func _poses_de(e: Dictionary, idx: int) -> Array:
	var v: Variant = e.get("objets_poses", {}).get(idx, null)
	if v == null:
		return []
	if v is Array:
		return (v as Array).duplicate()
	return [str(v)]


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
		sim.grille.poser_meuble(idx, str(it.meuble))
		_maj_contenu_pile(sim, vers)   # la pile bloque dès qu'UN de ses meubles bloque
		if int(m.capacite_slots) > 0:
			sim.contenants[idx] = []
		if str(m.type_meuble) == "etal" and sim.monde != null:
			sim.territoire.etals[_pm(sim, vers)] = true
		if str(m.type_meuble) == "hall":
			var guilde: String = SimTerritoire._meilleure_guilde(sim, e)
			if guilde.is_empty():
				sim.grille.retirer_meuble(idx, str(it.meuble))
				_maj_contenu_pile(sim, vers)
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
	# CE QU'ON A POSÉ SUR UNE TUILE EST UNE LISTE (26 undecies) : une tuile peut porter plusieurs meubles, et
	# démonter doit rendre CELUI DU SOMMET. Une sauvegarde d'avant y range une chaîne : `_poses_de` la relit.
	e["objets_poses"] = e.get("objets_poses", {})
	var poses_l := _poses_de(e, idx)
	poses_l.append(uid)
	e.objets_poses[idx] = poses_l
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
	# On ne vide le contenant que si c'est LUI qu'on démonte (26 undecies) : retirer le lit posé SUR le coffre ne
	# doit pas vider le coffre.
	var somm := str(sim.grille.meubles.get(idx, ""))
	var porte_contenu := int(GameData.entree("meubles", somm).get("capacite_slots", 0)) > 0 if not somm.is_empty() else true
	if porte_contenu and sim.contenants.has(idx) and not sim.contenants[idx].is_empty():
		_prendre(sim, e, vers, tick)   # on vide le coffre d'abord
	var poses_d := _poses_de(e, idx)
	var uid: String = str(poses_d.pop_back()) if not poses_d.is_empty() else ""
	if not uid.is_empty() and sim.items.has(uid):
		e.sac.append(uid)
		if poses_d.is_empty():
			e.objets_poses.erase(idx)
		else:
			e.objets_poses[idx] = poses_d
		EventBus.emettre(&"journal", [&"journal.demonte", {"nom": e.name_key, "objet": SimObjets.nom_objet(sim, uid)}])
	else:
		EventBus.emettre(&"journal", [&"journal.demonte", {"nom": e.name_key, "objet": {"base": str(c.name_key)}}])
	sim.grille.retirer_meuble(idx)   # le SOMMET : c'est celui qu'on voit et qu'on démonte
	_maj_contenu_pile(sim, vers)
	sim.grille.marquer(vers)
	if sim.monde != null:
		sim.territoire.etals.erase(_pm(sim, vers))
		sim.territoire.cultures.erase(_pm(sim, vers))
		if sim.territoire.get("halls", {}).has(_pm(sim, vers)):
			for x in sim.vivants():
				if x.get("hall", Vector2i(-1, -1)) == vers:
					x.vivant = false
					sim.grille.liberer(x.pos, x.id)
			EventBus.emettre(&"journal", [&"journal.hall_demonte", {"guilde": "guilde.%s.name" % str(sim.territoire.halls[_pm(sim, vers)])}])
			sim.territoire.halls.erase(_pm(sim, vers))
	if sim.grille.meubles_de(idx).is_empty():   # la pile est vide : la tuile redevient nue
		sim.grille.stations_fixes.erase(idx)
		sim.grille.materiaux.erase(idx)
		sim.contenants.erase(idx)
	elif porte_contenu:
		sim.contenants.erase(idx)   # c'est le contenant qu'on a retiré : ce qui reste dessous n'en porte pas
	e.compteur = tick + int(sim.regles.r.camp.poser_ticks)
	EventBus.emettre(&"tile_changed", [vers])
	return true


## Le contenu d'une tuile qui porte des meubles : « meuble » si UN SEUL de la pile bloque le passage, « meuble_sol »
## sinon, et rien du tout si la pile est vide. Sans ça, démonter la table laisserait le coffre posé dessus dans une
## tuile déclarée nue — et poser un coffre sur une table rendrait la table franchissable.
static func _maj_contenu_pile(sim: Simulation, vers: Vector2i) -> void:
	var idx_c := sim.grille.idx(vers)
	var pile_c: Array = sim.grille.meubles_de(idx_c)
	if pile_c.is_empty():
		sim.grille.contenu[idx_c] = 0
		return
	var bloque := false
	for mid in pile_c:
		if bool(GameData.entree("meubles", str(mid)).get("bloque_passage", false)):
			bloque = true
			break
	sim.grille.poser_contenu(vers, "meuble" if bloque else "meuble_sol")


static func _coffre_a(sim: Simulation, vers: Vector2i) -> Dictionary:
	if not sim.grille.dans(vers):
		return {}
	# ON CHERCHE DANS LA PILE (2026-09-09) : `meubles[i]` ne donne que le SOMMET depuis que les meubles s'empilent,
	# si bien qu'un coffre sous une lanterne devenait introuvable — l'écran ne s'ouvrait plus, sans rien dire.
	for mid in sim.grille.meubles_de(sim.grille.idx(vers)):
		var m: Dictionary = GameData.entree("meubles", str(mid))
		if int(m.capacite_slots) > 0:
			return m
	return {}


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


## Prendre UN objet d'un contenant adjacent (designer 2026-09-08 : le coffre s'ouvre comme un échange). Le pendant
## exact de `_ranger` — même portée, même coût, même journal.
static func _prendre_un(sim: Simulation, e: Dictionary, uid: String, vers: Vector2i, tick: int) -> bool:
	if not sim.grille.dans(vers) or Grille.distance(e.pos, vers) > 1:
		return false
	var idx := sim.grille.idx(vers)
	var dedans: Array = sim.contenants.get(idx, [])
	if not (uid in dedans) or (uid in e.sac):
		return false
	dedans.erase(uid)
	sim.contenants[idx] = dedans
	e.sac.append(uid)
	# Vider le coffre d'autrui reste un vol, objet par objet comme d'un seul coup (Royaumes et lois).
	if sim.grille.meubles.has(idx) and sim.monde != null and sim.lieu == "camp" and e.controle == "joueur" and not sim.monde.claims.has(_cell_de(sim, vers)) and bool(sim.monde.cellule(_cell_de(sim, vers)).has("village")):
		SimRoyaumes._infraction(sim, e, "comportement", "vol", vers, "")
	if dedans.is_empty() and not sim.grille.meubles.has(idx):   # un butin au sol disparaît quand il est vide ; un meuble reste
		sim.grille.contenu[idx] = 0
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.prend", {"nom": e.name_key, "objet": SimObjets.nom_objet(sim, uid)}])
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
	# La tranche et le plafond sont en DONNÉES depuis le 2026-09-08 : ils valaient 100 et 200, écrits en dur, et le
	# passage du tick à la milliseconde les a rendus faux d'un facteur cent — une nuit de 800 000 ticks n'en
	# avançait plus que 20 000, et le dormeur se réveillait douze minutes plus tard au lieu du matin.
	var pas_max := int(cp.get("sommeil_tranches_max", 400))
	var tranche := maxi(1, int(cp.get("sommeil_tranche_ticks", 10000)))
	var reste := duree
	while reste > 0 and pas_max > 0:
		var n := mini(reste, tranche)
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
	# Une nuit entière remet le corps d'aplomb, partie par partie — mais elle ne rend pas un bras : ce qui est tombé
	# est tombé, et c'est la prothèse qui le remplacera (ordre de travail 28 bis).
	if e.get("corps", {}).has("sante_parties"):
		e.corps.sante_parties.clear()
	e["sang"] = 0
	e.mana = e.mana_max
	e.vigueur = e.vigueur_max
	e.tick_vigueur = sim.horloge_monde.ticks
	e["veille_depuis"] = maxi(1, sim.horloge_monde.ticks)   # le sommeil (ordre de travail 31) : on s'éveille maintenant
	if e.has("effroi"):   # une nuit apaise la peur, elle ne l'efface pas
		e["effroi"] = Simulation.effroi(e, sim.horloge_monde.ticks, sim.regles.r) * float(sim.regles.r.get("frayeur", {}).get("sommeil_mult", 0.5))
		e["effroi_tick"] = sim.horloge_monde.ticks
	if int(e.get("fatigue_palier", 0)) != 0:
		e["fatigue_palier"] = 0
		Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
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
	sim.grille.liberer(e.pos, e.id)
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
		# Une cellule au rôle « champs », OU une tuile qu'on a labourée soi-même (2026-09-07) : le jardin du joueur.
		if str(sim.monde.claims.get(_cell_de(sim, vers), {}).get("role", "")) != "champs" and not sim.territoire.get("laboure", {}).has(_pm(sim, vers)):
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
		# Un buisson planté par le joueur est un VERGER : à la cueillette il repart de lui-même, comme ceux des villes.
		var champ_j := {"verger": true, "plante": base} if str(pl.get("categorie", "")) == "buisson" else {}
		SimVilles._semer_tuile(sim, vers, base, tick, 1.0 - duree / (float(pl.duree_jours) * float(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))), champ_j)   # la pluie a déjà avancé la pousse
		sim.territoire.get("laboure", {}).erase(_pm(sim, vers))   # la terre labourée est semée : elle n'attend plus
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


## Labourer une tuile de terre voisine (Agriculture et élevage, 2026-09-07) : elle devient une parcelle nue où l'on peut
## semer, où qu'elle soit, et la terre y gagne `labour.fertilite`. Il faut l'outil de récolte du sol en main (la pioche,
## la faucille — ce que la catégorie du matériau demande), et la tuile doit être libre, plate et d'un sol qui se laboure.
static func _labourer(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if sim.monde == null or sim.lieu != "camp" or not sim.grille.dans(vers) or Grille.distance(e.pos, vers) != 1:
		return false
	var ag: Dictionary = SimTerritoire._ry(sim).agriculture
	var lb: Dictionary = ag.get("labour", {})
	if not sim.grille.contenu_de(vers).is_empty() or sim.grille.meubles.has(sim.grille.idx(vers)) or sim.grille.h(vers) != sim.grille.h(e.pos):
		return false
	if not (str(sim.grille.materiau_sol(vers)) in lb.get("sols", [])):
		EventBus.emettre(&"journal", [&"journal.labour_refuse", {}])
		return false
	var pm := _pm(sim, vers)
	if sim.territoire.get("laboure", {}).has(pm) or sim.territoire.cultures.has(pm):
		return false
	if not sim.territoire.has("laboure"):
		sim.territoire["laboure"] = {}
	sim.territoire.laboure[pm] = true
	sim.territoire.fertilite[pm] = clampi(fertilite_a(sim, pm, vers) + int(lb.get("fertilite", 8)), 0, 100)
	e.orientation = vers - e.pos
	e.compteur = tick + sim._ticks_avec_statuts(e, int(lb.get("ticks", 30)))
	sim.gagner_xp(e, "agriculture", int(lb.get("fertilite", 8)))
	EventBus.emettre(&"journal", [&"journal.laboure", {"nom": e.name_key, "fertilite": int(sim.territoire.fertilite[pm])}])
	EventBus.emettre(&"tile_changed", [vers])
	return true


## Arroser une parcelle qui pousse (Agriculture et élevage, 2026-09-07) : avec un seau en main, la pousse avance de
## `arrosage.avance` du temps restant. Une parcelle déjà arrosée dans la journée ne gagne rien de plus.
static func _arroser(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if not sim.grille.dans(vers) or Grille.distance(e.pos, vers) != 1:
		return false
	var pm := _pm(sim, vers)
	var c: Dictionary = sim.territoire.cultures.get(pm, {})
	if c.is_empty() or bool(c.get("mure", false)) or tick >= int(c.echeance):
		return false
	var ar: Dictionary = SimTerritoire._ry(sim).agriculture.get("arrosage", {})
	var seau := false   # le seau se reconnaît à sa FONCTIONNALITÉ : il y en a deux au catalogue (proto et façonné)
	for slot in ["main_principale", "main_secondaire"]:
		var it: Dictionary = sim.items.get(str(e.get("equipement", {}).get(slot, "")), {})
		if str(it.get("functionality", "")) == str(ar.get("outil", "seau")):
			seau = true
	if not seau:
		EventBus.emettre(&"journal", [&"journal.arrosage_sans_seau", {}])
		return false
	var jour := int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
	if tick / jour <= int(c.get("arrose_jour", -1)):
		EventBus.emettre(&"journal", [&"journal.deja_arrose", {}])
		return false
	c["arrose_jour"] = tick / jour
	c.echeance = tick + int(float(int(c.echeance) - tick) * (1.0 - float(ar.get("avance", 0.2))))
	e.orientation = vers - e.pos
	e.compteur = tick + int(sim.regles.r.actions.objet)
	sim.gagner_xp(e, "agriculture", 1)
	EventBus.emettre(&"journal", [&"journal.arrose", {"nom": e.name_key}])
	EventBus.emettre(&"tile_changed", [vers])
	return true


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
			sim.grille.poser_contenu(local, str(c.get("mur_id", "culture_mure")))   # un verger mûrit en verger, pas en blé
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
