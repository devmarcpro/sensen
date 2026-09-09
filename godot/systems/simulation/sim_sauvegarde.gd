class_name SimSauvegarde
extends RefCounted
## La sauvegarde : emplacements, résumé, sauvegarder, charger, l'étage mis de côté.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


## Sauvegarde la partie (surface seulement : au camp ou à pied). Retourne vrai si tout est écrit.
## L'emplacement où cette partie s'écrit. Un outil (tests, fuzz, robot) détourne `slot_autosave` pour ne
## jamais toucher à une vraie partie ; sinon c'est le dossier de la partie en cours (designer 2026-09-02).
static func slot(sim: Simulation) -> String:
	if Simulation.slot_autosave != "monde":
		return Simulation.slot_autosave
	return sim.nom_partie if not sim.nom_partie.is_empty() else "monde"


## Ce qu'il faut savoir d'une partie SANS la charger (designer 2026-09-02 : « sélectionner une partie
## devrait afficher le portrait de personnage et toutes les stats du monde »). Charger un monde entier
## pour peupler une liste coûterait des secondes par ligne ; ce résumé est écrit à chaque sauvegarde.
static func resume_partie(sim: Simulation) -> Dictionary:
	var j := {}
	for x in sim.entites.values():
		if x.controle == "joueur":
			j = x
			break
	var nd: Dictionary = sim.progression.niveaux_derives(j) if not j.is_empty() else {}
	var chunks_par_cellule := maxi(1, (sim.monde.taille / 32) * (sim.monde.taille / 32)) if sim.monde != null else 1
	return {
		"nom": sim.tr(str(sim.fiche_joueur.get("name_key", j.get("name_key", "creature.aventurier.name")))),
		"race": str(sim.fiche_joueur.get("race", j.get("race", ""))),
		"classe": str(sim.fiche_joueur.get("classe", j.get("classe", ""))),
		"niveau": int(round(maxf(float(nd.get("combat", 0.0)), float(nd.get("general", 0.0))))),
		"sante": int(j.get("sante", 0)), "sante_max": int(j.get("sante_max", 0)),
		"or": int(j.get("or", 0)), "sac": int((j.get("sac", []) as Array).size()),
		"lieu": sim.lieu, "etage": int(sim.donjon.get("etage", 0)) if sim.lieu == "donjon" else 0,
		"jour": SimVilles.jour_courant(sim), "heure": int(SimTerrain.heure(sim)),
		"saison": str(SimTerrain._saison_info(sim).get("id", "")),
		"graine_monde": sim.graine_monde,
		"biome": str(sim.camp_sauve.get("biome", "")),
		"cellule_camp": sim.monde.cellule_camp if sim.monde != null else Vector2i.ZERO,
		"cellules_vues": int(ceil(float(sim.monde.explores.size()) / float(chunks_par_cellule))) if sim.monde != null else 0,
		"claims": sim.monde.claims.size() if sim.monde != null else 0,
		"villages_connus": sim.monde.villages.size() if sim.monde != null else 0,
		"corruption_camp": roundi(sim.monde.corruption_de(sim.monde.cellule_camp)) if sim.monde != null else 0,
		"options_monde": sim.planete_options,
		"ecrit_le": Time.get_datetime_string_from_system(false, true),
	}


static func sauvegarder(sim: Simulation, nom: String = "") -> bool:
	if nom.is_empty():
		nom = slot(sim)
	# Sauvegarde possible partout (designer, 2026-08-31) : au camp comme en donjon. Seule l'arène de test reste hors jeu.
	if not (sim.lieu in ["camp", "donjon"]) or sim.monde == null:
		return false
	if sim.lieu == "camp":
		sim.monde.capturer(sim.grille)
	# La sauvegarde ne doit RIEN changer à la partie en cours (2026-09-08). Elle normalisait les êtres et vidait
	# `sim.combats` sur la simulation VIVANTE : sauvegarder au milieu d'un combat le dissolvait sur place, sans passer
	# par la fin de combat. On normalise désormais les COPIES écrites — aucun combat ne survit toujours au
	# rechargement, mais celui qu'on est en train de jouer n'est plus touché.
	var j := {}
	for e in sim.entites.values():
		if e.controle == "joueur":
			j = _etre_a_ecrire(sim, e)
	# Les objets fantômes ne partent plus sur le disque : seuls ceux qu'un être, un contenant ou une cellule référence
	# encore sont écrits. La purge est à l'ÉCRITURE seulement — le dictionnaire vivant garde sa taille, parce que le
	# tirage du butin est semé dessus (`SimObjets`, `rng.seed = hash([graine, "loot", sim.objets.size(), ...])`) et
	# qu'en changer la taille changerait tout objet tiré ensuite.
	var atteignables := _uids_atteignables(sim)
	var instances := {}
	for uid in sim.objets.keys():
		if atteignables.has(uid):
			instances[uid] = sim.objets[uid]
	var surface := {}
	for cell in sim.monde.modifications.keys():
		surface[cell] = {"modifications": sim.monde.modifications[cell], "decouvert": sim.monde.decouvert.get(cell, {}), "contenants": sim.monde.contenants_hors.get(cell, {}), "dormants": sim.monde.dormants.get(cell, [])}
	for cell in sim.monde.decouvert.keys():
		if not surface.has(cell):
			surface[cell] = {"modifications": {}, "decouvert": sim.monde.decouvert[cell], "contenants": sim.monde.contenants_hors.get(cell, {}), "dormants": sim.monde.dormants.get(cell, [])}
	for cell in sim.monde.contenants_hors.keys():
		if not surface.has(cell):
			surface[cell] = {"modifications": {}, "decouvert": {}, "contenants": sim.monde.contenants_hors[cell], "dormants": sim.monde.dormants.get(cell, [])}
	for cell in sim.monde.dormants.keys():
		if not surface.has(cell):
			surface[cell] = {"modifications": {}, "decouvert": {}, "contenants": {}, "dormants": sim.monde.dormants[cell]}
	var autres := {}
	var ordre_autres: Array = []
	for id in sim.ordre:
		if sim.entites[id].controle != "joueur":
			autres[id] = _etre_a_ecrire(sim, sim.entites[id])
			ordre_autres.append(id)
	var contenants_monde := {}
	for gi in sim.contenants.keys():
		contenants_monde[sim.grille.pos_de(int(gi))] = sim.contenants[gi]
	# `world.json` est écrit EN DERNIER (2026-09-08) : c'est le seul fichier que `Sauvegarde.existe` teste, donc le
	# seul qui décide si l'écran Charger liste la partie. Écrit en premier, une coupure au milieu laissait une partie
	# annoncée valide dont les quatre autres fichiers étaient ceux d'avant. Les cinq écritures ne forment toujours pas
	# une transaction — mais la moitié du risque tient dans cet ordre.
	var monde_json := {"version": int(GameData.config("combat_rules").get("sauvegarde", {}).get("version", 2)), "resume": resume_partie(sim), "graine": sim.graine, "graine_monde": sim.graine_monde, "planete_options": sim.planete_options, "identifies": sim.identifies, "ticks": sim.horloge_monde.ticks, "prochain_donjon": sim.prochain_donjon, "n_entites": sim._n_entites,
		"cellule_camp": sim.monde.cellule_camp, "camp": {"entree": sim.camp_sauve.get("entree", Vector2i.ZERO), "biome": sim.camp_sauve.get("biome", ""), "cellule": sim.camp_sauve.get("cellule", Vector2i.ZERO)}, "explores": sim.monde.explores,
		"delta": sim.monde.delta, "foyers": sim.monde.foyers, "faune_densite": sim.monde.faune_densite, "semaine": sim.monde.semaine_courante, "peuplees": sim.monde.peuplees, "claims": sim.territoires.joueur.cellules, "territoire": sim.territoires.joueur, "territoires": sim.territoires, "tresors_royaumes": sim.monde.tresors_royaumes, "etats_royaumes": sim.monde.etats_royaumes, "vacances": sim.monde.vacances, "villages": sim.monde.villages, "tombes": sim.monde.tombes, "heritiers": sim.monde.heritiers, "vacances_guildes": sim.monde.vacances_guildes,
		"modifs_terrain": sim.modifs_terrain, "portails": sim.portails, "gouffres_vides": sim.gouffres_vides, "mines_creusees": sim.mines_creusees,
		"nettoyages": sim.monde.nettoyages,
		"carte_cache": sim.monde.carte_cache_serialise()}   # indexés par position monde, donc valables au rechargement
	var ok := Sauvegarde.ecrire(nom, "surface.json", surface)
	ok = Sauvegarde.ecrire(nom, "entities.json", {"entites": autres, "ordre": ordre_autres, "contenants": contenants_monde}) and ok
	ok = Sauvegarde.ecrire(nom, "items.json", instances) and ok
	ok = Sauvegarde.ecrire(nom, "players/joueur.json", {"fiche": sim.fiche_joueur, "etre": j}) and ok
	var exp := {"lieu": sim.lieu}
	if sim.lieu == "donjon":   # l'expédition en cours : l'étage se régénère de sa graine, ses êtres sont dans entities.json
		var camp_ent: Dictionary = sim.camp_sauve.get("entites", {})
		var camp_cont := {}
		if sim.camp_sauve.has("grille") and sim.camp_sauve.has("contenants"):
			for gi in sim.camp_sauve.contenants.keys():
				camp_cont[sim.camp_sauve.grille.pos_de(int(gi))] = sim.camp_sauve.contenants[gi]
		# L'identité du lieu voyage avec l'expédition (2026-09-08) : sans `mine`, recharger dans une mine régénérait un
		# donjon à salles — la promesse de « Mine sous une cellule » disparaissait au rechargement. Sans `gouffre`,
		# `corrompu` et `niveau`, un gouffre redevenait un donjon ordinaire et un donjon de corruption perdait sa
		# difficulté affichée. Ce sont exactement les clés que `charger_donjon` préserve désormais.
		var ident := {"theme": sim.donjon.theme, "graine": int(sim.donjon.graine), "id": int(sim.donjon.id), "etage": int(sim.donjon.etage), "etages": int(sim.donjon.etages), "cellule": sim.donjon.get("cellule", Vector2i(-9999, -9999)), "corruption": float(sim.donjon.get("corruption", 0.0)),
			"mine": bool(sim.donjon.get("mine", false)), "cellule_mine": sim.donjon.get("cellule_mine", Vector2i(-9999, -9999))}
		for cle_id in ["gouffre", "region", "corrompu", "niveau", "cellules", "etages_fixes"]:
			if sim.donjon.has(cle_id):
				ident[cle_id] = sim.donjon[cle_id]
		exp = {"lieu": "donjon", "donjon": ident,
			"expedition": sim.expedition, "camp": {"entites": camp_ent, "ordre": sim.camp_sauve.get("ordre", []), "contenants": camp_cont}, "retour": j.get("retour", Vector2i.ZERO),
			"decouvert": sim.grille.decouvert.duplicate()}   # le brouillard de l'étage courant survit au rechargement (l'expédition reprend où elle était)
	ok = Sauvegarde.ecrire(nom, "expedition.json", exp) and ok
	ok = Sauvegarde.ecrire(nom, "world.json", monde_json) and ok   # EN DERNIER : c'est lui qui rend la partie visible
	if ok:
		EventBus.emettre(&"sauvegarde_faite", [nom])
	return ok


## Recharge une partie : le monde depuis la graine, puis les modifications, les êtres et le joueur.
static func charger_sauvegarde(sim: Simulation, nom: String = "") -> bool:
	if nom.is_empty():
		nom = slot(sim)
	sim.nom_partie = nom
	var w: Variant = Sauvegarde.lire(nom, "world.json")
	if w == null:
		return false
	var surface: Dictionary = Sauvegarde.lire(nom, "surface.json")
	var ent: Dictionary = Sauvegarde.lire(nom, "entities.json")
	var instances: Dictionary = Sauvegarde.lire(nom, "items.json")
	var pj: Dictionary = Sauvegarde.lire(nom, "players/joueur.json")
	sim.graine = int(w.graine)
	sim.graine_monde = int(w.get("graine_monde", -1))   # le monde de cette partie, pas celui de planete.json
	sim.planete_options = w.get("planete_options", {})   # les réglages de génération de cette partie (designer, point 49)
	sim.identifies = w.get("identifies", {})             # ce que le joueur a déjà identifié (point 52)
	sim.des = Des.new(sim.graine)
	sim.fiche_joueur = pj.get("fiche", {})
	sim.camp_sauve = {}
	sim.etages_visites.clear()
	sim.expedition = {}
	SimLieux.charger_camp(sim)   # regénère le monde depuis la graine
	# Les objets d'abord (les êtres y font référence par uid).
	for uid in instances.keys():
		sim.objets[uid] = instances[uid]
		sim.items[uid] = instances[uid]
	sim.monde.cellule_camp = w.cellule_camp
	sim.monde.surface.cellule_camp = sim.monde.cellule_camp
	sim.monde.explores = w.get("explores", {})
	sim.monde.delta = w.get("delta", {})
	sim.monde.foyers = w.get("foyers", {})
	sim.monde.faune_densite = w.get("faune_densite", {})
	sim.monde.semaine_courante = int(w.get("semaine", 0))
	sim.monde.peuplees = w.get("peuplees", {})
	sim.monde.claims = w.get("claims", {})
	sim.monde.vacances = w.get("vacances", {})
	sim.monde.heritiers = w.get("heritiers", {})
	sim.monde.vacances_guildes = w.get("vacances_guildes", {})
	sim.monde.villages = w.get("villages", {})
	sim.monde.tombes = w.get("tombes", {})   # les morts enterres : le monde s en souvient, la cellule non
	sim.monde.tresors_royaumes = w.get("tresors_royaumes", {})
	sim.monde.etats_royaumes = w.get("etats_royaumes", {})
	sim.monde.nettoyages = w.get("nettoyages", {})   # un donjon de corruption vaincu le RESTE (il revenait au rechargement)
	# Ces quatre-là se lisaient APRÈS la branche « sauvegarde en donjon », qui sort par un `return` : recharger dans
	# une mine oubliait donc la galerie creusée, la profondeur atteinte d'un gouffre et la carte du monde (2026-09-08).
	sim.gouffres_vides = w.get("gouffres_vides", {})   # les étages de gouffre déjà vidés : ils le restent d'une session à l'autre
	sim.mines_creusees = w.get("mines_creusees", {})   # une mine est un ouvrage : la galerie creusée traverse les sessions
	sim.monde.carte_cache_charger(w.get("carte_cache", {}))   # la carte du monde se souvient d'elle-même (designer 2026-09-02)
	sim.territoires = w.get("territoires", {})
	sim.territoire = sim.territoires.get("joueur", w.get("territoire", sim.territoire))   # une sauvegarde d'avant B0 n'a que `territoire`
	sim.territoire["id"] = "joueur"
	sim.territoire["proprietaire"] = "joueur"
	sim.territoire["cellules"] = sim.monde.claims
	sim.territoires["joueur"] = sim.territoire
	for id in sim.territoires.keys():
		sim.territoires[id]["id"] = str(id)
	for cell in surface.keys():
		var sc: Dictionary = surface[cell]
		if not sc.modifications.is_empty():
			sim.monde.modifications[cell] = sc.modifications
		if not sc.decouvert.is_empty():
			sim.monde.decouvert[cell] = sc.decouvert
		if not sc.contenants.is_empty():
			sim.monde.contenants_hors[cell] = sc.contenants
		if not sc.dormants.is_empty():
			sim.monde.dormants[cell] = sc.dormants
	# UN TICK EST DEVENU UNE MILLISECONDE (2026-09-08) : une partie enregistrée avant comptait en ticks de 100 ms.
	# On met son horloge à l'échelle ici, avant que quoi que ce soit la lise — sans quoi le calendrier reculerait de
	# plusieurs jours et la corruption rejouerait des semaines. Les compteurs des êtres sont bornés à l'horloge plus
	# bas ; les statuts d'une vieille partie expirent, et c'est le prix visible du changement d'unité.
	var sv: Dictionary = GameData.config("combat_rules").get("sauvegarde", {})
	if int(w.get("version", 1)) < int(sv.get("version", 2)):
		w["ticks"] = int(w.get("ticks", 0)) * int(sv.get("echelle_v1_vers_v2", 100))
	# Le joueur, puis la fenêtre autour de lui (les cellules mémorisées y sont rejouées).
	var joueur_sauve: Dictionary = pj.etre
	var exp: Variant = Sauvegarde.lire(nom, "expedition.json")
	if exp != null and str(exp.get("lieu", "camp")) == "donjon":
		# Sauvegarde en expédition (designer, 2026-08-31) : l'étage se régénère de sa graine, puis les êtres
		# sauvés remplacent les êtres frais ; le camp mis de côté garde ses PNJ (réinjectés à la sortie).
		var d: Dictionary = exp.donjon
		sim.horloge_monde = TickManager.creer("monde", Horloge.Mode.TEMPS_REEL, float(sim.regles.r.ticks_par_seconde_exploration))
		sim.monde.tick(int(w.ticks))
		sim.modifs_terrain = w.get("modifs_terrain", {})
		sim.portails = w.get("portails", {})
		joueur_sauve["retour"] = exp.get("retour", Vector2i.ZERO)
		sim.donjon = {"etages": int(d.etages), "cellule": d.get("cellule", Vector2i(-9999, -9999)), "corruption": float(d.get("corruption", 0.0)), "id": -1,
			"mine": bool(d.get("mine", false)), "cellule_mine": d.get("cellule_mine", Vector2i(-9999, -9999))}
		for cle_id in ["gouffre", "region", "corrompu", "niveau", "cellules", "etages_fixes"]:
			if d.has(cle_id):
				sim.donjon[cle_id] = d[cle_id]
		sim.entites[joueur_sauve.id] = joueur_sauve   # charger_donjon reprendra cette fiche telle quelle
		sim.lieu = "donjon"
		var pos_sauvee: Vector2i = joueur_sauve.pos   # _reprendre replace à l'entrée : on garde où le joueur a sauvé
		var statuts_sauves: Array = joueur_sauve.get("statuts", []).duplicate(true)   # et ses statuts, que _reprendre efface
		SimLieux.charger_donjon(sim, str(d.theme), int(d.graine), int(d.id), int(d.etage), joueur_sauve)
		for id in sim.ordre.duplicate():   # les êtres frais de la régénération cèdent la place aux êtres sauvés
			if id != joueur_sauve.id:
				sim.grille.liberer(sim.entites[id].pos, sim.entites[id].id)
				sim.entites.erase(id)
				sim.ordre.erase(id)
		for id in ent.ordre:
			sim.entites[id] = ent.entites[id]
			sim.ordre.append(id)
			if sim.entites[id].vivant and sim.grille.dans(sim.entites[id].pos):
				sim.grille.placer(id, sim.entites[id].pos)
		if sim.grille.dans(pos_sauvee) and not sim.grille.bloque_passage(pos_sauvee) and sim.grille.occupant(pos_sauvee).is_empty():
			sim.grille.liberer(joueur_sauve.pos, joueur_sauve.id)   # le joueur reprend où il a sauvé, pas à l'entrée (Sauvegarde)
			joueur_sauve.pos = pos_sauvee
			joueur_sauve.ancre = pos_sauvee
			sim.grille.placer(joueur_sauve.id, pos_sauvee)
		joueur_sauve.statuts = statuts_sauves
		sim.grille.decouvert = exp.get("decouvert", sim.grille.decouvert)   # le brouillard de l'étage tel qu'à la sauvegarde
		sim.contenants = {}
		for pos in ent.contenants.keys():
			if sim.grille.dans(pos):
				sim.contenants[sim.grille.idx(pos)] = ent.contenants[pos]
				if sim.grille.contenu_de(pos).is_empty():
					sim.grille.poser_contenu(pos, "butin")
		sim.expedition = exp.get("expedition", {})
		sim.etages_visites.clear()
		sim.camp_sauve = {"entree": w.camp.entree, "biome": str(w.camp.biome), "cellule": w.camp.cellule,
			"entites": exp.camp.get("entites", {}), "ordre": exp.camp.get("ordre", []), "contenants_pos": exp.camp.get("contenants", {})}
		sim.horloge_monde.ticks = int(w.ticks)
		if SimLieux.temps_a_l_action(sim):
			sim.horloge_monde.mode = Horloge.Mode.ACTION
		for x in sim.entites.values():
			x.compteur = mini(int(x.get("compteur", 0)), sim.horloge_monde.ticks)
		sim.prochain_donjon = int(w.prochain_donjon)
		sim._n_entites = int(w.n_entites)
		sim.maj_vision()
		EventBus.emettre(&"journal", [&"journal.chargement", {}])
		return true
	SimLieux._reinitialiser(sim)
	sim.monde.centre = Vector2i(-1, -1)
	sim.modifs_terrain = w.get("modifs_terrain", {})   # après _reinitialiser, qui les vide : ce que le monde doit rendre
	sim.portails = w.get("portails", {})               # et les brèches du Passeur, indexées par position monde
	# `gouffres_vides`, `mines_creusees` et la carte du monde sont lus plus haut, avant la branche donjon.
	sim.grille = sim.monde.fenetre(sim.monde.cellule_de(joueur_sauve.pos), GameData.config("tile_contents"), sim.regles.r.deplacement, int(sim.regles.r.vision.hauteur_oeil))
	sim.monde.tick(int(w.ticks))   # les grâces échues avant la sauvegarde
	sim.entites[joueur_sauve.id] = joueur_sauve
	sim.ordre.append(joueur_sauve.id)
	for id in ent.ordre:
		sim.entites[id] = ent.entites[id]
		sim.ordre.append(id)
	for pos in ent.contenants.keys():
		if sim.grille.dans(pos):
			sim.contenants[sim.grille.idx(pos)] = ent.contenants[pos]
			if sim.grille.contenu_de(pos).is_empty():
				sim.grille.poser_contenu(pos, "butin")
	for cell in sim.monde.contenants_hors.keys().duplicate():
		if absi(cell.x - sim.monde.centre.x) <= sim.monde.rayon and absi(cell.y - sim.monde.centre.y) <= sim.monde.rayon:
			for li in sim.monde.contenants_hors[cell].keys():
				var pos: Vector2i = sim.monde.pos_monde(cell, sim.monde.local_pos(int(li)))
				if not sim.grille.dans(pos):
					continue
				sim.contenants[sim.grille.idx(pos)] = sim.monde.contenants_hors[cell][li]
			sim.monde.contenants_hors.erase(cell)
	for id in sim.ordre:
		if sim.entites[id].vivant:
			sim.grille.placer(id, sim.entites[id].pos)
	sim.grille.modifies.clear()
	sim.horloge_monde.ticks = int(w.ticks)
	sim.prochain_donjon = int(w.prochain_donjon)
	sim._n_entites = int(w.n_entites)
	sim.camp_sauve = {"entree": w.camp.entree, "biome": str(w.camp.biome), "cellule": w.camp.cellule}
	sim.lieu = "camp"
	sim.maj_vision()
	sim.monde.pregenerer_voisins()
	EventBus.emettre(&"fenetre_recentree", [sim.grille.origine])
	return true


# ---------------------------------------------------------------- craft compositionnel

## La copie ÉCRITE d'un être : aucun combat ne survit au rechargement, mais la sauvegarde ne touche plus la partie en
## cours — on normalise la copie, jamais l'original (2026-09-08).
static func _etre_a_ecrire(sim: Simulation, x: Dictionary) -> Dictionary:
	if str(x.get("horloge", "monde")) == "monde":
		return x
	var c: Dictionary = x.duplicate(true)
	c["horloge"] = "monde"
	c["compteur"] = sim.horloge_monde.ticks
	c["action_en_cours"] = {}
	return c


## Les uid d'objets qu'une fiche, un contenant ou une cellule référence encore. Le balayage est VOLONTAIREMENT large :
## il collecte toute chaîne qui se trouve être un uid connu, où qu'elle soit dans les dictionnaires. Il ne peut donc
## que garder trop, jamais jeter à tort — perdre un objet serait bien pire que d'en écrire un fantôme.
static func _uids_atteignables(sim: Simulation) -> Dictionary:
	var vus := {}
	var file: Array = []
	for x in sim.entites.values():
		file.append(x)
	for c in sim.contenants.values():
		file.append(c)
	for cell in sim.monde.contenants_hors.keys():
		file.append(sim.monde.contenants_hors[cell])
	for cell in sim.monde.dormants.keys():
		file.append(sim.monde.dormants[cell])
	if sim.camp_sauve.has("entites"):
		file.append(sim.camp_sauve.entites)
	if sim.camp_sauve.has("contenants"):
		file.append(sim.camp_sauve.contenants)
	for etage in sim.etages_visites.values():
		file.append(etage)
	file.append(sim.fiche_joueur)
	file.append(sim.expedition)
	var garde := 0
	while not file.is_empty() and garde < 2000000:
		garde += 1
		var v: Variant = file.pop_back()
		match typeof(v):
			TYPE_STRING, TYPE_STRING_NAME:
				var s := str(v)
				if sim.objets.has(s):
					vus[s] = true
			TYPE_DICTIONARY:
				for k in (v as Dictionary).keys():
					if typeof(k) == TYPE_STRING and sim.objets.has(str(k)):
						vus[str(k)] = true
					file.append((v as Dictionary)[k])
			TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
				for e in v:
					file.append(e)
	return vus


## L'état de l'étage courant, sans le joueur, mis de côté : rien ne repop, tout reste où c'est.
static func _sauver_etage(sim: Simulation, joueur: Dictionary) -> void:
	var sauve := {"donjon": sim.donjon.duplicate(), "grille": sim.grille, "entites": {}, "ordre": [], "contenants": sim.contenants}
	var partants: Array = []   # l'escorte part avec le joueur : pas dans l'étage mis de côté, sinon un doublon au retour
	for x in SimPnj._escorte_qui_suit(sim, joueur):
		partants.append(x.id)
	for id in sim.ordre:
		if id != joueur.id and not (id in partants):
			sauve.entites[id] = sim.entites[id]
			sauve.ordre.append(id)
	sim.grille.liberer(joueur.pos, joueur.id)
	for id_p in partants:
		sim.grille.liberer(sim.entites[id_p].pos, sim.entites[id_p].id)
	sim.etages_visites[int(sim.donjon.etage)] = sauve


# ---------------------------------------------------------------- les bâtiments à étages (Villes, 99, 2026-09-05)
