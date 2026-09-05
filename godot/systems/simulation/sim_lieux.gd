class_name SimLieux
extends RefCounted
## L'arène, le camp, les donjons, les gouffres, les étages de donjon (charger, descendre, remonter, sortir).
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


## Charge une arène de data/prototype_arenas et instancie ses êtres.
static func charger_arene(sim: Simulation, id: String) -> void:
	sim.arene_id = id
	sim.donjon = {}
	sim.lieu = "arene"
	var arene := GameData.entree("prototype_arenas", id)
	sim.grille = Grille.depuis_arene(arene, GameData.config("tile_contents"),
		sim.regles.r.deplacement, int(sim.regles.r.vision.hauteur_oeil))
	_reinitialiser(sim)
	var j: Dictionary = arene.spawns.player
	SimObjets.ajouter(sim, j.creature, Vector2i(int(j.pos[0]), int(j.pos[1])), "joueur")
	for s: Dictionary in arene.spawns.enemies:
		SimObjets.ajouter(sim, s.creature, Vector2i(int(s.pos[0]), int(s.pos[1])), "ia")
	if id == "banc_objets":
		_remplir_banc_objets(sim, arene)
	sim.maj_vision()


## Le banc d'objets (designer 2026-09-02) : « un coffre par catégorie de matériaux avec 999 de chaque
## item, et un coffre par type d'équipement avec 1 de chaque combinaison possible ». Une carte pour
## REGARDER : elle sert à juger d'un coup d'œil ce que les paliers et l'étirement des stats ont produit.
##
## Le remplissage se fait ici et pas dans la fiche d'arène, parce qu'un conteneur et ses instances
## d'objets n'existent qu'à l'exécution — une fiche ne peut décrire que la tuile qui les portera.
static func _remplir_banc_objets(sim: Simulation, arene: Dictionary) -> void:
	var coffres: Array[Vector2i] = []
	for c in arene.get("contents", []):
		if str(c.get("type", "")) == "coffre":
			coffres.append(Vector2i(int(c.pos[0]), int(c.pos[1])))
	coffres.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	# Rangée du haut : les matériaux, une catégorie par coffre, 999 de chacun.
	var par_cat := {}
	for mid in GameData.catalogues.materials.keys():
		var cat := str(GameData.catalogues.materials[mid].get("category", "?"))
		if not par_cat.has(cat):
			par_cat[cat] = []
		(par_cat[cat] as Array).append(str(mid))
	var cats: Array = par_cat.keys()
	cats.sort()
	var i := 0
	for cat in cats:
		if i >= coffres.size():
			break
		var uids: Array = []
		for mid in par_cat[cat]:
			var pile: Dictionary = SimObjets.generer_objet(sim, "materiau_brut", 1, {}, "commun", 0)
			if pile.is_empty():
				continue
			pile.materiau = str(mid)
			pile.forme = "brut"
			pile.quantite = 999
			pile.name_key = GameData.entree("materials", str(mid)).name_key
			uids.append(pile.uid)
		SimObjets._poser_contenant(sim, coffres[i], uids, "coffre")
		i += 1
	# Rangée du bas : un coffre par type d'équipement, une pièce par combinaison base × matériau.
	var par_type := {}
	for bid in GameData.catalogues.items.keys():
		var it: Dictionary = GameData.catalogues.items[bid]
		if not it.has("slots") or (it.slots as Dictionary).is_empty():
			continue
		var t := str(it.get("type", "?"))
		if not par_type.has(t):
			par_type[t] = []
		(par_type[t] as Array).append(str(bid))
	var types: Array = par_type.keys()
	types.sort()
	var rng := RandomNumberGenerator.new()
	for t in types:
		if i >= coffres.size():
			break
		var uids2: Array = []
		for bid in par_type[t]:
			for niveau in [1, 6, 12, 20, 30]:   # un exemplaire par palier de profondeur : la progression se voit
				rng.seed = hash([bid, niveau, "banc"])
				var o: Dictionary = SimObjets.generer_objet(sim, str(bid), niveau, {"banc": true}, "commun", 0)
				if not o.is_empty():
					uids2.append(o.uid)
		SimObjets._poser_contenant(sim, coffres[i], uids2, "coffre")
		i += 1


## Le camp de base (Claims et persistance, étape 7) : une cellule plate revendiquée d'office. Restauré
## tel quel s'il a déjà été visité ; sinon généré, avec le coffre de départ. `joueur` : l'être qui
## revient d'expédition (vide au premier chargement : créé depuis la fiche).
static func charger_camp(sim: Simulation, joueur: Dictionary = {}, cellule_choisie: Vector2i = Vector2i(-1, -1)) -> void:
	var escorte: Array = SimPnj._escorte_qui_suit(sim, joueur) if sim.lieu == "donjon" else []   # elle rentre avec lui (Compagnons, 2026-09-04)
	sim.arene_id = "camp"
	sim.lieu = "camp"
	sim.donjon = {}
	if sim.camp_sauve.has("grille"):   # un camp mis de côté (pas seulement ses métadonnées : biome…)
		var sauve: Dictionary = sim.camp_sauve
		sim.grille = sauve.grille
		_reinitialiser(sim)
		for id in sauve.ordre:
			sim.entites[id] = sauve.entites[id]
			sim.ordre.append(id)
			if sim.entites[id].vivant:
				if sim.entites[id].has("dormant_depuis"):
					_projeter_routine(sim, sim.entites[id])   # le niveau 2 du LOD : le camp a vécu pendant l'expédition
				sim.grille.placer(id, sim.entites[id].pos)
		sim.contenants = sauve.contenants
		if not joueur.is_empty():
			var ou: Vector2i = joueur.get("lit", sauve.entree) if joueur.get("mort_en_expedition", false) else joueur.get("retour", sauve.entree)
			joueur.erase("mort_en_expedition")
			joueur.erase("retour")
			_reprendre(sim, joueur, ou)
			joueur.spawn = joueur.get("lit", sauve.entree)
			SimPnj._placer_escorte(sim, joueur, escorte)
		sim.maj_vision()
		return
	# Première venue : le monde (fenêtre glissante) centré sur la cellule de départ.
	var cfg: Dictionary = GameData.config("camp")
	var planete: Dictionary = sim.planete_options if not sim.planete_options.is_empty() else GameData.config("planete")
	var surface := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, sim.graine_monde if sim.graine_monde >= 0 else int(planete.graine))
	sim.monde = Monde.new(surface, planete, cfg)
	sim.monde.claims = sim.territoires.joueur.cellules   # les claims du joueur et les cellules de son territoire : un seul dictionnaire (Villes B0)
	var depart := sim.monde.cellule_camp if cellule_choisie == Vector2i(-1, -1) else cellule_choisie
	# Garde-fou (Début de partie) : si la cellule de départ est en mer, la première cellule de terre en spirale.
	var essais := 0
	# Une partie ne commence pas n'importe où (designer 2026-09-02) : la masse de terre du camp doit
	# porter un gouffre et deux villes de deux royaumes différents. On cherche donc une case qui tienne
	# ces promesses, et pas seulement une case de terre — une graine peut poser le camp sur un îlot
	# désert, et on ne s'en aperçoit qu'après avoir joué une heure.
	# Sauf si le joueur a choisi sa case lui-même sur la carte : c'est son droit de commencer au bout
	# du monde, et le garde-fou de terre ferme ci-dessous suffit alors.
	if cellule_choisie == Vector2i(-1, -1):
		depart = sim.monde.chercher_depart(depart)
	var origine_spirale := depart
	while essais < 400 and not surface.terre_a(depart):
		essais += 1
		var r := 1
		var trouve := false
		while r < 96 and not trouve:   # une graine peut poser (512, 512) en plein océan : on cherche loin (2026-08-30 : 4 graines sur 16 démarraient en mer)
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if absi(dx) != r and absi(dy) != r:
						continue
					var c := origine_spirale + Vector2i(dx, dy)
					if surface.terre_a(c):
						depart = c
						trouve = true
						break
				if trouve:
					break
			r += 1
		break
	sim.monde.cellule_camp = depart
	sim.monde.surface.cellule_camp = depart   # jamais un quartier d'agglomération : le camp est le territoire du joueur (Villes B1)
	sim.grille = sim.monde.fenetre(depart, GameData.config("tile_contents"), sim.regles.r.deplacement, int(sim.regles.r.vision.hauteur_oeil))
	var e := sim.monde.cellule(depart)
	var entree := sim.monde.point_marchable(depart)   # le point marchable le plus proche du centre (Début de partie)
	_reinitialiser(sim)
	# Une partie commence à heure_depart (Cycle jour-nuit, designer 2026-08-30 : 8 h) ; une sauvegarde garde son heure.
	var cy: Dictionary = planete.get("cycle", {})
	sim.horloge_monde.ticks = int(float(cy.get("heure_depart", 0)) / 24.0 * float(cy.get("ticks_par_jour", 24000))) + int(GameData.config("calendrier").get("jour_depart", 0)) * int(cy.get("ticks_par_jour", 24000))   # un jour sans fête (Calendrier)
	if joueur.is_empty():
		var j: Dictionary = SimObjets.ajouter(sim, "aventurier", entree, "joueur")
		j.spawn = entree
	else:
		_reprendre(sim, joueur, entree)
	for x in sim.entites.values():   # les compteurs des premiers êtres partent de l'heure de départ, pas de minuit
		x.compteur = sim.horloge_monde.ticks
		x.tick_vigueur = sim.horloge_monde.ticks
		if x.has("faim_tick"):
			x.faim_tick = sim.horloge_monde.ticks
		joueur.spawn = entree
	var uids: Array = []
	for base in cfg.coffre_depart:
		var o: Dictionary = SimObjets.generer_objet(sim, str(base), 1, {}, "commun", 0)
		if not o.is_empty():
			uids.append(o.uid)
	SimObjets._poser_contenant(sim, sim.monde.pos_monde(depart, e.coffre_depart), uids, "coffre")
	var pnj_sauves: Dictionary = sim.camp_sauve.get("entites", {})   # une sauvegarde en expédition : les PNJ du camp reviennent
	var ordre_sauves: Array = sim.camp_sauve.get("ordre", [])
	var cont_sauves: Dictionary = sim.camp_sauve.get("contenants_pos", {})
	sim.camp_sauve = {"entree": entree, "biome": e.biome, "cellule": depart}
	SimVilles._peupler_fenetre(sim)
	for id in ordre_sauves:
		if not sim.entites.has(id) and pnj_sauves.has(id):
			var x2: Dictionary = pnj_sauves[id]
			sim.entites[id] = x2
			sim.ordre.append(id)
			if x2.vivant and sim.grille.dans(x2.pos) and sim.grille.occupant(x2.pos).is_empty():
				sim.grille.placer(id, x2.pos)
	for pos in cont_sauves.keys():
		if sim.grille.dans(pos):
			sim.contenants[sim.grille.idx(pos)] = cont_sauves[pos]
			if sim.grille.contenu_de(pos).is_empty():
				sim.grille.poser_contenu(pos, "butin")
	sim.maj_vision()
	sim.monde.pregenerer_voisins()


## Le joueur a changé de cellule : la fenêtre se recentre (Monde). Les positions sont en coordonnées
## monde : rien ne bouge ; ce que l'ancienne fenêtre avait de non regénérable est capturé.
static func _verifier_fenetre(sim: Simulation, e: Dictionary) -> void:
	if sim.lieu != "camp" or sim.monde == null:
		return
	var c := sim.monde.cellule_de(e.pos)
	if c == sim.monde.centre:
		return
	sim.monde.capturer(sim.grille)
	# Contenants et êtres : ce qui reste dans la nouvelle fenêtre est remappé, le reste est mis de côté.
	var anciens := {}
	for gi in sim.contenants.keys():
		anciens[sim.grille.pos_de(int(gi))] = sim.contenants[gi]
	var nouvelle := sim.monde.fenetre(c, GameData.config("tile_contents"), sim.regles.r.deplacement, int(sim.regles.r.vision.hauteur_oeil))
	sim.contenants = {}
	for pos in anciens.keys():
		if nouvelle.dans(pos):
			sim.contenants[nouvelle.idx(pos)] = anciens[pos]
			if anciens[pos].size() > 0 and nouvelle.contenu_de(pos).is_empty():
				nouvelle.poser_contenu(pos, "butin")
		else:
			var cell := sim.monde.cellule_de(pos)
			if not sim.monde.contenants_hors.has(cell):
				sim.monde.contenants_hors[cell] = {}
			sim.monde.contenants_hors[cell][sim.monde.idx_local(pos)] = anciens[pos]
	for cell in sim.monde.contenants_hors.keys().duplicate():
		if absi(cell.x - c.x) <= sim.monde.rayon and absi(cell.y - c.y) <= sim.monde.rayon:
			for li in sim.monde.contenants_hors[cell].keys():
				var pos: Vector2i = sim.monde.pos_monde(cell, Vector2i(int(li) % sim.monde.taille, int(li) / sim.monde.taille))
				sim.contenants[nouvelle.idx(pos)] = sim.monde.contenants_hors[cell][li]
				if nouvelle.contenu_de(pos).is_empty():
					nouvelle.poser_contenu(pos, "butin")
			sim.monde.contenants_hors.erase(cell)
	for id in sim.ordre.duplicate():
		var x: Dictionary = sim.entites[id]
		if x.id != e.id and not nouvelle.dans(x.pos):
			var cell: Vector2i = SimCamp._cell_de(sim, x.pos)
			if not sim.monde.dormants.has(cell):
				sim.monde.dormants[cell] = []
			x["dormant_depuis"] = sim.horloge_monde.ticks   # LOD de simulation : au réveil, sa routine le remettra à sa place
			sim.monde.dormants[cell].append(x)
			sim.ordre.erase(id)
			sim.entites.erase(id)
	for cell in sim.monde.dormants.keys().duplicate():
		if absi(cell.x - c.x) <= sim.monde.rayon and absi(cell.y - c.y) <= sim.monde.rayon:
			for x in sim.monde.dormants[cell]:
				sim.entites[x.id] = x
				sim.ordre.append(x.id)
			sim.monde.dormants.erase(cell)
	sim.grille = nouvelle
	_vider_etats_tuiles(sim)   # la fenêtre a glissé : les index de l'ancienne grille ne veulent plus rien dire
	nouvelle.modifies.clear()
	for id in sim.ordre:
		if sim.entites[id].vivant:
			if sim.entites[id].has("dormant_depuis"):
				_projeter_routine(sim, sim.entites[id])   # le niveau 2 du LOD : là où sa routine l'aurait mené
			sim.grille.placer(id, sim.entites[id].pos)
	SimVilles._peupler_fenetre(sim)
	for pid in SimPerimetres.perimetres(sim).keys():   # une cellule qui rentre dans la fenêtre : son périmètre se rescanne (2026-09-04)
		SimPerimetres.scanner_perimetre(sim, str(pid))
	sim.maj_vision()
	sim.monde.pregenerer_voisins()
	EventBus.emettre(&"fenetre_recentree", [sim.grille.origine])


## Le niveau 2 du LOD (LOD de simulation, 2026-09-04) par PROJECTION AU RÉVEIL : un PNJ mis de côté hors
## fenêtre reprend là où sa routine l'aurait mené — à son poste, sa place ou son lit selon l'heure, ou EN
## CHEMIN entre l'ancien et le nouveau but si l'heure vient de tourner, au pas près sur le chemin réel. Rien
## ne tique pendant l'absence : le résultat observable est le même, le coût est nul. Appelé sur la nouvelle
## grille, avant que l'être y soit placé.
static func _projeter_routine(sim: Simulation, x: Dictionary) -> void:
	var depuis := int(x.get("dormant_depuis", -1))
	x.erase("dormant_depuis")
	if depuis < 0 or not bool(x.get("vivant", true)) or str(x.get("controle", "")) != "ia":
		return
	var profil: Dictionary = GameData.catalogues.get("ai_profiles", {}).get(str(x.get("ai_profile", "")), {})
	if not profil.has("horaires") or not x.has("lit"):
		return
	var tick := sim.horloge_monde.ticks
	if tick - depuis < int(GameData.config("planete").routine.get("projection_min_ticks", 100)):
		return   # une absence trop courte : rien à projeter
	var jour := int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
	var h: float = SimTerrain.heure(sim, tick)
	var debut_h := float(sim._plage_routine(profil, h).debut)
	var ecart_h := h - debut_h if h >= debut_h else h + 24.0 - debut_h
	var depuis_debut := roundi(ecart_h / 24.0 * float(jour))   # ticks écoulés depuis le début de la plage horaire
	var cible: Vector2i = sim._cible_routine(x, profil, tick)
	var avant: Vector2i = sim._cible_routine(x, profil, tick - depuis_debut - 1)
	var dest := cible
	if cible != avant:
		var chemin: Array = sim.grille.chemin(avant, cible, Etres.est_volant(x), "", sim.refuse_nage(x))
		var pas := sim.regles.ticks_deplacement(int(sim.regles.r.deplacement.cout_base), x.get("competences_eff", {}), false)
		var faits := depuis_debut / maxi(1, pas)
		if not chemin.is_empty() and faits < chemin.size():
			dest = avant if faits <= 0 else chemin[faits - 1]
	x.pos = _tuile_libre_pres(sim, x, dest)
	x["ancre"] = x.pos


## La case libre la plus proche de `p` (rayon 3), sans compter `x` lui-même ; sinon `p`.
static func _tuile_libre_pres(sim: Simulation, x: Dictionary, p: Vector2i) -> Vector2i:
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := p + Vector2i(dx, dy)
				if not sim.grille.dans(q) or sim.grille.bloque_passage(q):
					continue
				var occ := sim.grille.occupant(q)
				if not occ.is_empty() and occ != str(x.id):
					continue
				var pris := false
				for y in sim.entites.values():
					if y.id != x.id and bool(y.get("vivant", true)) and y.pos == q:
						pris = true
						break
				if not pris:
					return q
	return p


## Met le camp de côté avant une expédition : grille, meubles, coffres, êtres — tout reste.
static func _sauver_camp(sim: Simulation, joueur: Dictionary) -> void:
	var sauve := {"entree": sim.camp_sauve.get("entree", joueur.pos), "biome": sim.camp_sauve.get("biome", ""), "cellule": sim.camp_sauve.get("cellule", Vector2i.ZERO), "grille": sim.grille, "entites": {}, "ordre": [], "contenants": sim.contenants}
	if sim.monde != null:
		sim.monde.capturer(sim.grille)
	var partants: Array = []   # l'escorte descend avec le joueur (Compagnons, 2026-09-04)
	for x in SimPnj._escorte_qui_suit(sim, joueur):
		partants.append(x.id)
	for id in sim.ordre:
		if id != joueur.id and not (id in partants):
			sim.entites[id]["dormant_depuis"] = sim.horloge_monde.ticks   # LOD de simulation : au retour, sa routine le remettra à sa place
			sauve.entites[id] = sim.entites[id]
			sauve.ordre.append(id)
	sim.grille.liberer(joueur.pos)
	for id_p in partants:
		sim.grille.liberer(sim.entites[id_p].pos)
	sim.camp_sauve = sauve


## Partir en expédition depuis l'entrée du donjon du camp.
## Nouvelle partie directement en donjon (designer 2026-08-31, point 34) : l'expédition part de la cellule
## du camp, donjon ouvert d'office — mêmes invariants de retour que _partir_en_expedition.
static func commencer_en_donjon(sim: Simulation, e: Dictionary) -> bool:
	if sim.lieu != "camp" or sim.monde == null or e.is_empty():
		return false
	var cell := sim.monde.cellule_de(e.pos)
	e["retour"] = e.pos
	_sauver_camp(sim, e)
	sim.expedition = {}
	sim.etages_visites.clear()
	var f := sim.monde.foyer(cell)
	var id := int(hash([sim.graine, cell.x, cell.y, "donjon", int(f.get("generation", 0))]) & 0x7fffffff)
	var b: Dictionary = GameData.catalogues.biomes.get(str(sim.monde.surface.resume_cellule(cell).biome), {})
	var theme := "repaire" if ("marecage" in b.get("tags", []) or "corrompu" in b.get("tags", [])) else "ruine"
	var cr: Dictionary = GameData.config("planete").corruption
	var fourchette: Array = cr.etages_majeur if bool(f.get("majeur", false)) else cr.etages_mineur
	var corruption := sim.monde.corruption_de(cell)
	sim.donjon = {"etages_fixes": fourchette, "corruption": corruption, "cellule": cell}
	EventBus.emettre(&"journal", [&"journal.expedition_depart", {}])
	charger_donjon(sim, theme, sim.graine, id, 1, e)
	return true


## Entrer sur la cellule d'un donjon de corruption y fait entrer d'office (designer 2026-09-01,
## point 51) : la surface n'est plus un lieu qu'on traverse. Le niveau du donjon décide de sa
## profondeur — un donjon que personne n'a nettoyé depuis longtemps est un gouffre.
## Arriver sur la cellule d'un donjon, c'est y entrer — quelle que soit sa nature (designer 2026-09-02 :
## « entrer dans un donjon depuis la carte monde ne fait pas rentrer dans le donjon mais dans la cellule
## que le donjon occupe »). Un donjon de corruption happe qui y met le pied, un gouffre s'ouvre sous les
## pas : côté joueur c'est le même geste — cliquer le donjon sur la carte, et y être. Le garde-fou de
## `cellule_vue` vaut pour les deux : on n'entre qu'en ARRIVANT sur la cellule, sinon ressortir du
## donjon vous y replongerait au pas suivant, et on ne pourrait plus jamais en sortir.
static func entrer_donjon_de_la_cellule(sim: Simulation, e: Dictionary) -> bool:
	if sim.lieu != "camp" or sim.monde == null or e.controle != "joueur":
		return false
	var cell := sim.monde.cellule_de(e.pos)
	if cell == Vector2i(e.get("cellule_vue", Vector2i(-9999, -9999))):
		return false
	e["cellule_vue"] = cell
	if not sim.monde.donjon_de_corruption(cell, SimVilles.jour_courant(sim)).is_empty():
		return entrer_donjon_corrompu(sim, e)
	return _descendre_au_gouffre(sim, e, cell)


static func entrer_donjon_corrompu(sim: Simulation, e: Dictionary) -> bool:
	if sim.lieu != "camp" or sim.monde == null or e.controle != "joueur":
		return false
	var cell := sim.monde.cellule_de(e.pos)
	var dc := sim.monde.donjon_de_corruption(cell, SimVilles.jour_courant(sim))
	if dc.is_empty():
		return false
	e["retour"] = e.pos
	_sauver_camp(sim, e)
	sim.expedition = {}
	sim.etages_visites.clear()
	var cr: Dictionary = GameData.config("planete").corruption
	var base: Array = cr.etages_mineur
	var etages := int(base[0]) + int(dc.niveau) / 4 + (int(dc.get("cellules", 1)) - 1)   # le niveau creuse, la fusion élargit
	sim.donjon = {"etages_fixes": [etages, etages], "corruption": sim.monde.corruption_jour(cell, SimVilles.jour_courant(sim)),
		"cellule": Vector2i(dc.get("tete", cell)), "corrompu": true, "niveau": int(dc.niveau), "cellules": int(dc.get("cellules", 1))}
	EventBus.emettre(&"journal", [&"journal.donjon_corrompu", {
		"nom": GameData.entree("dungeon_themes", str(dc.theme)).name_key, "n": int(dc.niveau),
		"element": "element." + str(dc.element), "etages": etages,
		"corruption": roundi(sim.monde.corruption_jour(cell, SimVilles.jour_courant(sim))),
	}])
	charger_donjon(sim, str(dc.theme), sim.graine, int(hash([sim.graine, cell.x, cell.y, "corruption"]) & 0x7fffffff), 1, e)
	return true


static func _partir_en_expedition(sim: Simulation, e: Dictionary) -> bool:
	if sim.lieu != "camp" or not ("entree_donjon" in sim.grille.contenu_de(e.pos).get("tags", [])):
		return false
	var cell := sim.monde.cellule_de(e.pos)
	if _descendre_au_gouffre(sim, e, cell):
		return true
	e["retour"] = e.pos   # ressortir ramène devant l'entrée (Donjons — structure et intégration)
	_sauver_camp(sim, e)
	sim.expedition = {}
	sim.etages_visites.clear()
	# Le donjon de cette cellule : id déterministe, thème selon le biome (repaire en marécage/zone corrompue).
	if not sim.monde.donjon_ouvert(cell, sim.horloge_monde.ticks):
		return false
	var f := sim.monde.foyer(cell)
	var id := int(hash([sim.graine, cell.x, cell.y, "donjon", int(f.get("generation", 0))]) & 0x7fffffff)
	var b: Dictionary = GameData.catalogues.biomes.get(str(sim.monde.surface.resume_cellule(cell).biome), {})
	var theme := "repaire" if ("marecage" in b.get("tags", []) or "corrompu" in b.get("tags", [])) else "ruine"
	var cr: Dictionary = GameData.config("planete").corruption
	var fourchette: Array = cr.etages_majeur if bool(f.get("majeur", false)) else cr.etages_mineur
	var corruption := sim.monde.corruption_de(cell)
	if SimTerrain.est_nuit(sim):
		corruption = minf(100.0, corruption * (1.0 + float(SimTerrain._cycle(sim).get("corruption_nuit", 0.1))))   # la nuit : +10 %
	sim.donjon = {"etages_fixes": fourchette, "corruption": corruption, "cellule": cell}
	EventBus.emettre(&"journal", [&"journal.expedition_depart", {}])
	charger_donjon(sim, theme, sim.graine, id, 1, e)
	return true


## Le gouffre de la région (designer 2026-09-02) : infini, gratuit, et qui ne se régénère jamais.
## Rien ne verrouille l'entrée — la profondeur est déjà la porte, elle est gratuite et ne se contourne
## pas. Ce qui l'empêche d'être une machine à farmer, c'est qu'un étage vidé le reste pour toujours.
static func _descendre_au_gouffre(sim: Simulation, e: Dictionary, cell: Vector2i) -> bool:
	var g := sim.monde.gouffre_de(cell)
	if g.is_empty():
		return false
	e["retour"] = e.pos
	_sauver_camp(sim, e)
	sim.expedition = {}
	sim.etages_visites.clear()
	var cr: Dictionary = GameData.config("planete").corruption
	var b: Dictionary = GameData.catalogues.biomes.get(str(sim.monde.surface.resume_cellule(cell).biome), {})
	var theme := "repaire" if ("marecage" in b.get("tags", []) or "corrompu" in b.get("tags", [])) else "ruine"
	# « Infini » n'est pas un nombre : c'est l'absence de fond. On donne un plafond assez haut pour que
	# rien ne le rencontre, et le boss du dernier étage n'arrive donc jamais — on descend jusqu'à mourir.
	var fond := int(GameData.config("planete").get("regions", {}).get("gouffre_etages_max", 999))
	sim.donjon = {"etages_fixes": [fond, fond], "corruption": sim.monde.corruption_de(cell),
		"cellule": cell, "gouffre": int(g.id), "region": str(g.nom)}
	EventBus.emettre(&"journal", [&"journal.gouffre_depart", {"region": str(g.nom)}])
	charger_donjon(sim, theme, sim.graine, int(g.id), 1, e)
	return true


## Creuser un puits (designer 2026-09-02 : « on rajoute un escalier pour descendre et l'étage du dessous
## est généré », et « le minage en profondeur se fait sur une cellule au joueur »). Voir
## [[Mine sous une cellule]]. Deux usages, un seul geste :
##   - au CAMP, sur une cellule qu'on possède : le puits ouvre la mine et fait descendre à l'étage 1 ;
##   - DANS la mine, sur n'importe quelle tuile déjà dégagée : il ouvre l'étage suivant.
## On ne creuse pas n'importe où — la cellule doit être revendiquée. Une mine est un ouvrage, pas une
## excursion : elle demande un territoire, et elle reste.
static func creuser_un_puits(sim: Simulation, e: Dictionary, tick: int) -> bool:
	if e.controle != "joueur":
		return false
	var m: Dictionary = GameData.config("planete").get("mine", {})
	if sim.lieu == "camp":
		if sim.monde == null:
			return false
		var cell := sim.monde.cellule_de(e.pos)
		if not sim.monde.claims.has(cell):
			EventBus.emettre(&"journal", [&"journal.puits_hors_claim", {}])
			return false
		if int(e.vigueur) < int(m.get("vigueur_puits", 20)):
			EventBus.emettre(&"journal", [&"journal.puits_epuise", {}])
			return false
		e["retour"] = e.pos
		_sauver_camp(sim, e)
		sim.expedition = {}
		sim.etages_visites.clear()
		e.vigueur = maxi(0, int(e.vigueur) - int(m.get("vigueur_puits", 20)))
		sim.gagner_xp(e, "terrassement", int(m.get("xp_puits", 12)))
		var fond := int(m.get("etages_max", 999))
		sim.donjon = {"etages_fixes": [fond, fond], "corruption": 0.0, "cellule": cell,
			"mine": true, "cellule_mine": cell}
		EventBus.emettre(&"journal", [&"journal.mine_depart", {}])
		charger_donjon(sim, "ruine", sim.graine, Mine.id_de(sim.graine, cell), 1, e)
		return true
	if not bool(sim.donjon.get("mine", false)):
		return false
	if int(e.vigueur) < int(m.get("vigueur_puits", 20)):
		EventBus.emettre(&"journal", [&"journal.puits_epuise", {}])
		return false
	# Le puits part de LA TUILE OÙ L'ON SE TIENT : c'est la promesse de Dwarf Fortress — on décide où
	# descendre, on ne cherche pas un escalier que le monde aurait posé pour nous.
	var prochain: int = int(sim.donjon.etage) + 1
	e.vigueur = maxi(0, int(e.vigueur) - int(m.get("vigueur_puits", 20)))
	e.compteur = tick + sim._ticks_avec_statuts(e, int(m.get("ticks_puits", 40)))
	sim.gagner_xp(e, "terrassement", int(m.get("xp_puits", 12)))
	e.etage_depuis = int(sim.donjon.etage)
	EventBus.emettre(&"journal", [&"journal.puits_creuse", {"etage": prochain}])
	charger_donjon(sim, str(sim.donjon.theme), int(sim.donjon.graine), int(sim.donjon.id), prochain, e)
	return true


## Cet étage du gouffre a-t-il déjà été vidé ? Le terrain, lui, se régénère de sa graine — il est
## déterministe, le stocker ne servirait à rien ; ce qui ne revient pas, ce sont les êtres et le butin.
static func gouffre_etage_vide(sim: Simulation, etage: int) -> bool:
	if not sim.donjon.has("gouffre"):
		return false
	return bool(sim.gouffres_vides.get("%d|%d" % [int(sim.donjon.gouffre), etage], false))


## Génère et charge l'étage `etage` d'un donjon (Génération de donjon). `joueur` : la fiche du
## joueur au premier étage, ou son état courant pour le faire descendre avec ses PV et son sac.
static func charger_donjon(sim: Simulation, theme_id: String, graine: int, id_donjon: int, etage: int, joueur: Dictionary = {}) -> void:
	var theme := GameData.entree("dungeon_themes", theme_id)
	var escorte: Array = SimPnj._escorte_qui_suit(sim, joueur)   # elle change d'étage avec lui (Compagnons, 2026-09-04)
	if sim.lieu == "camp" and not joueur.is_empty() and sim.monde != null and not sim.camp_sauve.has("grille"):
		_sauver_camp(sim, joueur)   # descendre depuis le camp sans passer par l'expédition : le camp est quand même mis de côté
	var etages: int = sim.donjon.get("etages", 0)
	var corruption_locale: float = float(sim.donjon.get("corruption", 0.0))
	var cellule_donjon: Vector2i = sim.donjon.get("cellule", Vector2i(-9999, -9999))
	# Une mine n'est pas un donjon : pas de salles, pas de couloirs, pas d'habitants — un bloc de roche
	# pleine avec une chambre d'arrivee (Mine sous une cellule). Le reste de cette fonction lui va tel
	# quel : ses `spawns`, `coffres` et `filons` sont vides, donc les boucles ne font rien.
	var est_mine := bool(sim.donjon.get("mine", false))
	var cellule_mine: Vector2i = sim.donjon.get("cellule_mine", Vector2i(-9999, -9999))
	if etages == 0:
		var r := RandomNumberGenerator.new()
		r.seed = hash([graine, id_donjon])
		var fourchette: Array = sim.donjon.get("etages_fixes", theme.etages)   # majeur / mineur (Dérive de la corruption)
		etages = r.randi_range(int(fourchette[0]), int(fourchette[1]))
	var gen := Donjon.new(GameData.catalogues.get("dungeon_rooms", {}), GameData.catalogues.get("dungeon_connectors", {}), theme)
	var r2 := RandomNumberGenerator.new()
	r2.seed = hash([graine, id_donjon, etage, "salles"])
	var nb := r2.randi_range(int(theme.salles_par_etage[0]), int(theme.salles_par_etage[1]))
	if not joueur.is_empty() and not sim.donjon.is_empty() and int(sim.donjon.get("id", -1)) == id_donjon:
		SimSauvegarde._sauver_etage(sim, joueur)
	if sim.expedition.is_empty() or int(sim.expedition.get("id", -1)) != id_donjon:
		sim.expedition = {"id": id_donjon, "theme": theme_id, "tues": 0, "objets": 0, "etage_max": 1, "ticks": 0}
	sim.expedition.etage_max = maxi(int(sim.expedition.etage_max), etage)
	sim.arene_id = "donjon"
	sim.lieu = "donjon"
	if sim.etages_visites.has(etage):
		# Un étage déjà visité revient dans l'état où on l'a laissé.
		var sauve: Dictionary = sim.etages_visites[etage]
		sim.donjon = sauve.donjon
		sim.grille = sauve.grille
		_reinitialiser(sim)   # vide aussi les feux et l'eau en cours de l'étage quitté
		for id in sauve.ordre:
			sim.entites[id] = sauve.entites[id]
			sim.ordre.append(id)
			if sim.entites[id].vivant:
				sim.grille.placer(id, sim.entites[id].pos)
		sim.contenants = sauve.contenants
		var ou: Vector2i = sauve.donjon.escalier if (not joueur.is_empty() and int(joueur.get("etage_depuis", 0)) > etage and sauve.donjon.escalier != null) else sauve.donjon.entree
		_reprendre(sim, joueur, ou)
		SimPnj._placer_escorte(sim, joueur, escorte)
		return
	var e: Dictionary = Mine.generer_etage(graine, id_donjon, etage) if est_mine else gen.generer_etage(graine, id_donjon, etage, nb, etage == etages)
	var cr: Dictionary = GameData.config("planete").get("corruption", {})
	var corruption_etage := minf(100.0, corruption_locale + float(etage) * float(cr.get("corruption_par_etage", 8)))
	sim.donjon = {"theme": theme_id, "graine": graine, "id": id_donjon, "etage": etage, "etages": etages,
		"salles": gen._nb_salles(e), "escalier": e.escalier, "boss": e.boss, "entree": e.entree,
		"corruption": corruption_locale, "corruption_etage": corruption_etage, "cellule": cellule_donjon,
		"mine": est_mine, "cellule_mine": cellule_mine,
		"profondeur": etage + int(corruption_etage / float(cr.get("profondeur_par_corruption", 25)))}
	sim.grille = Grille.depuis_etage(e, GameData.config("tile_contents"), sim.regles.r.deplacement, int(sim.regles.r.vision.hauteur_oeil))
	var etage_matiere: int = Mine.profondeur_de(etage) if est_mine else etage
	sim.grille.materiau_defaut = SimTerritoire.materiau_mur_etage(sim, theme, etage_matiere)
	SimTerritoire._poches_de_strates(sim, theme, etage_matiere, graine, id_donjon)
	for idx in e.filons.keys():
		sim.grille.materiaux[idx] = e.filons[idx]
		sim.grille.poser_contenu(Vector2i(int(idx) % sim.grille.largeur, int(idx) / sim.grille.largeur), "filon")
	if est_mine:
		# Le sol d'une mine est la ROCHE qu'on vient d'y enlever, pas l'herbe du dehors : sans ça, la
		# chambre d'arrivée s'affichait en gazon vert à quatre étages sous terre.
		for i_sol in sim.grille.largeur * sim.grille.hauteur_grille:
			sim.grille.sols[i_sol] = sim.grille.materiau_defaut
	if est_mine:
		# La galerie déjà creusée se rouvre : le terrain est déterministe, seule la liste de ce qu'on a
		# enlevé est mémorisée. Redescendre dans sa mine, c'est retrouver son chantier, pas la roche.
		for idx_m in sim.mines_creusees.get("%d|%d" % [id_donjon, etage], []):
			var pm := sim.grille.pos_de(int(idx_m))
			sim.grille.contenu[int(idx_m)] = 0
			sim.grille.materiaux.erase(int(idx_m))
			sim.grille.hauteurs[int(idx_m)] = Mine.H_BASE
			sim.grille.marquer(pm)
	_reinitialiser(sim)
	if joueur.is_empty():
		SimObjets.ajouter(sim, theme.get("joueur", "aventurier"), e.entree, "joueur")
	else:
		_reprendre(sim, joueur, e.entree)
		SimPnj._placer_escorte(sim, joueur, escorte)
	if gouffre_etage_vide(sim, etage):
		# Un étage du gouffre déjà vidé le reste pour toujours (designer 2026-09-02) : le terrain revient,
		# les êtres et les coffres non. Redescendre à sa profondeur record est donc rapide et sans butin.
		sim.maj_vision()
		return
	if sim.donjon.has("gouffre"):
		sim.gouffres_vides["%d|%d" % [int(sim.donjon.gouffre), etage]] = true
	var n_spawns := int(ceil(float(e.spawns.size()) * (1.0 + corruption_etage / 100.0)))   # la corruption densifie
	var k_spawn := 0
	for s: Dictionary in e.spawns:
		if sim.grille.occupant(s.pos).is_empty():
			SimObjets.ajouter(sim, s.creature, s.pos, "ia")
			k_spawn += 1
	var i_extra := 0
	while k_spawn < n_spawns and not e.spawns.is_empty() and i_extra < e.spawns.size():
		var s2: Dictionary = e.spawns[i_extra]
		i_extra += 1
		for d in Grille.DIRS:
			var q: Vector2i = s2.pos + d
			if sim.grille.dans(q) and not sim.grille.bloque_passage(q) and sim.grille.occupant(q).is_empty():
				SimObjets.ajouter(sim, s2.creature, q, "ia")
				k_spawn += 1
				break
	for c: Dictionary in e.coffres:
		var uids: Array = []
		for base in c.bases:
			var o: Dictionary = SimObjets.generer_objet(sim, str(base), SimObjets.niveau_loot(sim), {"donjon": theme_id, "etage": etage})   # le niveau du donjon, pas l'étage
			if not o.is_empty():
				uids.append(o.uid)
		SimObjets._poser_contenant(sim, c.pos, uids, "coffre")
	sim.maj_vision()


## Les états indexés par tuile ne valent que pour la grille courante : tout changement de grille les vide
## (voyage, donjon, retour au camp, chargement). Sans ça, un feu continue de brûler les mêmes index ailleurs.
## Les zones au sol posées sur une tuile (Modules) — une tuile peut en porter plusieurs.
static func zones_sur(sim: Simulation, pos: Vector2i, type: String = "") -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for z: Dictionary in sim.zones:
		if z.pos == pos and (type.is_empty() or str(z.type) == type):
			res.append(z)
	return res


## Ce qu'une zone fait à celui qui entre sur sa tuile (appelé après chaque pas).
## Un plan discret (Sans trace, Silencieux) pose des zones cachées : des pièges (Six types de modules, 2026-08-30).
static func _plan_discret(sim: Simulation, plan: Dictionary) -> bool:
	var dr: Dictionary = plan.get("drapeaux", {})
	return bool(dr.get("sans_trace", false)) or bool(dr.get("silencieux", false))


static func _zones_a_l_entree(sim: Simulation, e: Dictionary, pos: Vector2i, tick: int) -> void:
	for z in zones_sur(sim, pos):
		if bool(z.get("cachee", false)) and str(z.get("source", "")) != e.id:
			z.cachee = false   # le piège se révèle sur celui qui y met le pied
			EventBus.emettre(&"journal", [&"journal.piege_revele", {"nom": e.name_key, "zone": "zone." + str(z.type)}])
		match str(z.type):
			"entrave":   # Racine : ce qui s'arrête là s'enracine
				sim.appliquer_statut(e, str(z.params.get("statut", "enracinement")), int(z.params.get("statut_ticks", 20)), str(z.source))
			"blessure":   # Sol vif : la tuile blesse ce qui la traverse
				var deg := sim.des.jet(str(z.params.get("degats", "1d6")))
				EventBus.emettre(&"journal", [&"journal.zone_blesse", {"nom": e.name_key, "degats": deg}])
				sim._appliquer_degats(e, deg, str(z.source), {"type": "zone", "element": z.get("elements", {})})
			"portail":   # Portail : deux tuiles appairées, on entre par l'une et on sort par l'autre
				var paire: Array[Dictionary] = []
				for z2 in sim.zones:
					if str(z2.type) == "portail" and str(z2.source) == str(z.source) and z2.pos != pos:
						paire.append(z2)
				if not paire.is_empty():
					var sortie: Vector2i = paire.back().pos
					if sim.grille.dans(sortie) and sim.grille.occupant(sortie).is_empty() and not sim.grille.bloque_passage(sortie):
						sim.grille.liberer(e.pos)
						e.pos = sortie
						sim.grille.placer(e.id, sortie)
						EventBus.emettre(&"journal", [&"journal.portail_traverse", {"nom": e.name_key}])
			"remanence":   # Rémanence : la charge se rejoue sur qui entre dans la zone
				var src_r: Dictionary = sim.entites.get(str(z.source), {})
				if not src_r.is_empty() and src_r.get("vivant", false) and src_r.id != e.id:
					sim._appliquer_charge(src_r, z.params.plan, [e] as Array[Dictionary], [pos] as Array[Vector2i], pos, {})
			"vapeur":   # Vapeur : le nuage applique son statut à ce qui entre
				sim.appliquer_statut(e, str(z.params.get("statut", "confusion")), int(z.params.get("statut_ticks", 20)), str(z.source))
			"glissante":   # Nappe : on glisse d'une tuile de plus, dans son élan
				var suite: Vector2i = pos + e.orientation
				if sim.grille.dans(suite) and sim.grille.occupant(suite).is_empty() and not sim.grille.bloque_passage(suite) and sim.grille.cout_pas(pos, suite, Etres.est_volant(e)) >= 0:
					sim.grille.liberer(pos)
					e.pos = suite
					sim.grille.placer(e.id, suite)
					EventBus.emettre(&"journal", [&"journal.glisse", {"nom": e.name_key}])
					_zones_a_l_entree(sim, e, suite, tick)


## Les zones expirées s'effacent (appelé avec les glyphes).
static func _tiquer_zones(sim: Simulation, tick: int) -> void:
	var restantes: Array[Dictionary] = []
	for z in sim.zones:
		if int(z.fin) > tick:
			restantes.append(z)
		else:
			EventBus.emettre(&"tile_changed", [z.pos])
	sim.zones = restantes


static func _vider_etats_tuiles(sim: Simulation, change_de_lieu: bool = false) -> void:
	sim.zones.clear()
	if change_de_lieu:   # camp ↔ donjon : deux espaces de coordonnées, rien ne se transporte
		sim.modifs_terrain.clear()
		sim.portails.clear()
		sim.bombes.clear()   # une bombe lancée au camp n'explose pas au fond du donjon
		sim.affuts.clear()
	sim.feux.clear()
	sim.eau_active.clear()
	sim.glyphes.clear()
	sim.obstacles.clear()
	sim.feu_prochain_pas = 0
	sim.eau_prochain_pas = 0


static func _reinitialiser(sim: Simulation) -> void:
	_vider_etats_tuiles(sim, true)
	sim.entites.clear()
	sim.ordre.clear()
	sim.combats.clear()
	sim.attente.clear()
	sim.contenants = {}   # jamais clear() : un lieu mis de côté garde la référence à ses contenants
	sim.differe_clear()
	for nom in TickManager.horloges.keys():
		TickManager.retirer(nom)
	sim.horloge_monde = TickManager.creer("monde", Horloge.Mode.TEMPS_REEL, float(sim.regles.r.ticks_par_seconde_exploration))
	if temps_a_l_action(sim):
		sim.horloge_monde.mode = Horloge.Mode.ACTION   # en donjon, le temps n'avance qu'à l'action (Boucle de tick, 2026-08-30)
	sim.horloge_monde.avancee.connect(sim._sur_avancee_monde)


## En donjon, l'horloge du monde est une horloge d'action : elle s'arrête sur le joueur tant qu'il réfléchit.
static func temps_a_l_action(sim: Simulation) -> bool:
	return sim.lieu == "donjon" and bool(sim.regles.r.get("donjon", {}).get("temps_a_l_action", false))


## Un être qui change d'étage garde son état (PV, mana, sac, XP, compétences) — instance ≠ définition.
static func _reprendre(sim: Simulation, e: Dictionary, pos: Vector2i) -> void:
	sim._n_entites += 1
	if not sim.grille.occupant(pos).is_empty():
		for d in Grille.DIRS:
			if sim.grille.dans(pos + d) and sim.grille.occupant(pos + d).is_empty() and not sim.grille.bloque_passage(pos + d):
				pos = pos + d
				break
	e.pos = pos
	e.ancre = pos
	e.compteur = 0
	e.horloge = "monde"
	e.tick_vigueur = 0
	e.action_en_cours = {}
	e.statuts = []
	e.declencheurs_armes = []
	e.cible = ""
	e.contact = false
	sim.entites[e.id] = e
	sim.ordre.append(e.id)
	sim.grille.placer(e.id, pos)


## Descendre : l'être doit être sur la cage d'escalier de l'étage (Donjons : escalier = lien).
static func _descendre(sim: Simulation, e: Dictionary) -> bool:
	if sim.lieu == "camp":
		if SimVilles._entrer_interieur(sim, e, e.pos):   # l'escalier d'un bâtiment à étages (99)
			return true
		return _partir_en_expedition(sim, e)
	if sim.donjon.is_empty() or sim.donjon.escalier == null or e.pos != sim.donjon.escalier:
		return false
	if bool(sim.donjon.get("interieur", false)):   # l'étage au-dessus (99)
		var suivant: int = int(sim.donjon.etage) + 1
		e.etage_depuis = int(sim.donjon.etage)
		SimVilles.charger_interieur(sim, suivant, e)
		return true
	if int(sim.donjon.etage) >= int(sim.donjon.etages):
		return false
	var prochain: int = int(sim.donjon.etage) + 1
	e.etage_depuis = int(sim.donjon.etage)
	charger_donjon(sim, sim.donjon.theme, int(sim.donjon.graine), int(sim.donjon.id), prochain, e)
	# Le message d'arrivée dit l'étage, la profondeur du donjon, la corruption et le nombre de salles (parcours du 2026-08-30)
	EventBus.emettre(&"journal", [&"journal.descente", {"etage": prochain, "etages": int(sim.donjon.etages), "corruption": int(sim.donjon.get("corruption_etage", 0)), "salles": int(sim.donjon.salles)}])
	return true


## Remonter : sur la tuile d'entrée de l'étage. À l'étage 1, c'est la sortie du donjon — le jalon
## « entrer, combattre, looter, progresser, ressortir » se ferme ici.
static func _remonter(sim: Simulation, e: Dictionary) -> bool:
	if sim.donjon.is_empty() or e.pos != Vector2i(sim.donjon.get("entree", Vector2i(-1, -1))):
		return false
	if bool(sim.donjon.get("interieur", false)):   # un bâtiment à étages (99) : l'étage du dessous, ou la rue
		if int(sim.donjon.etage) <= 1:
			return SimVilles._sortir_interieur(sim, e)
		e.etage_depuis = int(sim.donjon.etage)
		SimVilles.charger_interieur(sim, int(sim.donjon.etage) - 1, e)
		EventBus.emettre(&"journal", [&"journal.descend_etage", {"nom": e.name_key}])
		return true
	if int(sim.donjon.etage) <= 1:
		return _sortir(sim, e)
	var precedent: int = int(sim.donjon.etage) - 1
	e.etage_depuis = int(sim.donjon.etage)
	EventBus.emettre(&"journal", [&"journal.remontee", {"etage": precedent}])
	charger_donjon(sim, sim.donjon.theme, int(sim.donjon.graine), int(sim.donjon.id), precedent, e)
	return true


## Sortir du donjon : récapitulatif de l'expédition, puis une nouvelle expédition (graine suivante)
## avec le même être — son sac, ses niveaux, ses potentiels.
static func _sortir(sim: Simulation, e: Dictionary) -> bool:
	var recap := sim.expedition.duplicate()
	recap["sac"] = e.sac.size()
	recap["niveaux"] = sim.progression.niveaux_derives(e)
	recap["boss_vaincu"] = _boss_vaincu(sim)
	EventBus.emettre(&"journal", [&"journal.sortie", {"nom": e.name_key, "tues": recap.tues, "objets": recap.objets, "etage_max": recap.etage_max}])
	EventBus.emettre(&"expedition_terminee", [recap])
	sim.etages_visites.clear()
	sim.expedition = {}
	if not sim.camp_sauve.is_empty():   # le camp est le point d'ancrage entre deux expéditions (étape 7)
		EventBus.emettre(&"journal", [&"journal.retour_camp", {}])
		var cell_donjon: Vector2i = sim.donjon.get("cellule", Vector2i(-9999, -9999))
		charger_camp(sim, e)
		SimCamp._tiquer_territoire(sim, sim.horloge_monde.ticks)   # les heures d'absence sont résolues au retour (Abstraction hors-site)
		SimCamp._rapport_absence(sim)
		if recap.boss_vaincu and sim.monde != null and cell_donjon != Vector2i(-9999, -9999):
			sim.monde.nettoyer(cell_donjon, sim.horloge_monde.ticks)   # Dérive de la corruption : foyer nettoyé
			sim.monde.nettoyages[cell_donjon] = SimVilles.jour_courant(sim)   # un donjon de corruption vaincu retombe à son plancher (point 51)
			EventBus.emettre(&"journal", [&"journal.donjon_nettoye", {}])
		elif bool(sim.donjon.get("corrompu", false)) and sim.monde != null and cell_donjon != Vector2i(-9999, -9999):
			# Sortir sans vaincre : la cellule reste corrompue, on ressort DEHORS (point 51) —
			# le joueur est repoussé sur une cellule voisine saine plutôt que rejeté dans la gueule.
			var sortie := cell_donjon
			for d_s in Grille.DIRS:
				var c_s: Vector2i = cell_donjon + d_s
				if sim.monde.surface.terre_a(c_s) and not sim.monde.donjon_corrompu(c_s, SimVilles.jour_courant(sim)):
					sortie = c_s
					break
			if sortie != cell_donjon:
				e.pos = sim.monde.point_marchable(sortie)
				e["cellule_vue"] = sortie
				_verifier_fenetre(sim, e)
				sim.grille.placer(e.id, e.pos)
				sim.maj_vision()
				EventBus.emettre(&"journal", [&"journal.repousse_corruption", {}])
			SimPnj._quetes_sur_donjon(sim, cell_donjon, e.id)
			EventBus.emettre(&"dungeon_cleared", [cell_donjon, e.id])
		SimSauvegarde.sauvegarder(sim)   # autosave au retour (Sauvegarde : sur événements clés)
		return true
	var suivant: int = int(sim.donjon.id) + 1
	charger_donjon(sim, sim.donjon.theme, int(sim.donjon.graine), suivant, 1, e)
	return true


static func _boss_vaincu(sim: Simulation) -> bool:
	for etage in sim.etages_visites.keys():
		for id in sim.etages_visites[etage].ordre:
			var x: Dictionary = sim.etages_visites[etage].entites[id]
			if x.get("chain_gauge", false) and not x.vivant:
				return true
	for x in sim.entites.values():
		if x.get("chain_gauge", false) and x.controle == "ia" and not x.vivant:
			return true
	return false
