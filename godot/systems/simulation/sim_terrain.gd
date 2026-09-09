class_name SimTerrain
extends RefCounted
## Le terrain vivant : eau, courants, lave, feu, foudre, pluie, vent, terrassement, cueillette, creusage ; le cycle jour-nuit et la météo.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


## Creuser : détruire un mur adjacent (Destruction du terrain) — la tuile redevient sol.
## Le bord de la cellule (roche) ne se creuse pas. Coût en ticks et en endurance, XP de Terrassement.
## Mémoriser l'état d'origine d'une tuile avant de la modifier (régénération des cases sauvages).
static func _memoriser_terrain(sim: Simulation, t: Vector2i) -> void:
	if not sim.modifs_terrain.has(t):
		sim.modifs_terrain[t] = {"h": sim.grille.h(t), "contenu": int(sim.grille.contenu[sim.grille.idx(t)])}
	_reveiller_eau_autour(sim, t)


## Une tuile modifiée réveille les liquides voisins (Eau et liquides) : la tranchée s'inonde, le talus endigue.
static func _reveiller_eau_autour(sim: Simulation, t: Vector2i) -> void:
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = t + dd
		if sim.grille.dans(q) and sim.grille.niveau_liquide(q) > 0:
			sim.eau_active[sim.grille.idx(q)] = true


## L'automate d'eau (Eau et liquides) : chaque tuile active verse vers ses quatre voisines.
static func _tiquer_eau(sim: Simulation, tick: int) -> void:
	if sim.eau_active.is_empty() or tick < sim.eau_prochain_pas:
		return
	var ea: Dictionary = sim.regles.r.get("eau", {})
	sim.eau_prochain_pas = tick + int(ea.get("periode_ticks", 5))
	var budget := int(ea.get("tuiles_par_pas", 64))
	var portee := int(ea.get("portee", 7))
	for idx in sim.eau_active.keys():
		if budget <= 0:
			break
		budget -= 1
		sim.eau_active.erase(idx)
		var t := sim.grille.pos_de(int(idx))
		var niveau := sim.grille.niveau_liquide(t)
		if niveau < 8 and niveau > 0 and not _alimentee(sim, t):   # plus rien ne l'alimente : elle ne verse plus, et se retire si elle n'est pas dans un creux
			if not _en_creux(sim, t):
				_retirer_eau(sim, t)
			continue
		if niveau <= 1:
			continue
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = t + dd
			if not sim.grille.dans(q) or sim.grille.bloque_passage(q) or sim.grille.meubles.has(sim.grille.idx(q)):
				continue
			var cible := 0
			if sim.grille.h(q) < sim.grille.h(t):
				cible = portee   # elle descend le relief et remplit le creux
			elif sim.grille.h(q) == sim.grille.h(t):
				cible = niveau - 1   # elle s'étale en perdant un niveau par tuile
			if cible <= 0 or sim.grille.niveau_liquide(q) >= cible:
				continue
			_poser_eau(sim, q, cible)


## La direction du courant sur une tuile d'écoulement (Eau et liquides) : là où l'eau s'en va — la voisine
## la plus basse, sinon celle du niveau le plus faible. Zéro sur une source, sur la glace, ou dans un creux.
static func courant_de(sim: Simulation, t: Vector2i) -> Vector2i:
	var niveau := sim.grille.niveau_liquide(t)
	if niveau <= 0 or niveau >= 8 or sim.grille.gel:
		return Vector2i.ZERO
	var meilleure := Vector2i.ZERO
	var meilleur_h := sim.grille.h(t)
	var meilleur_niv := niveau
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = t + dd
		if not sim.grille.dans(q) or sim.grille.bloque_passage(q):
			continue
		if sim.grille.h(q) < meilleur_h:
			meilleur_h = sim.grille.h(q)
			meilleur_niv = sim.grille.niveau_liquide(q)
			meilleure = dd
		elif sim.grille.h(q) == meilleur_h and meilleure == Vector2i.ZERO and sim.grille.niveau_liquide(q) < meilleur_niv:
			meilleur_niv = sim.grille.niveau_liquide(q)
			meilleure = dd
	return meilleure


## Le courant emporte ce qui flotte (Eau et liquides) : les êtres légers, puis les objets au sol.
static func _tiquer_courant(sim: Simulation, tick: int) -> void:
	var ea: Dictionary = sim.regles.r.get("eau", {})
	var chance := float(ea.get("courant_chance", 0.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "courant", tick])
	for x in sim.vivants():
		if sim.grille.niveau_liquide(x.pos) <= 0 or rng.randf() >= chance:
			continue
		var pd: Dictionary = sim.poids_de(x)   # la charge relative, pas le facteur de surcharge : à moitié chargé, on tient déjà
		if float(pd.capacite) > 0.0 and float(pd.poids) / float(pd.capacite) > float(ea.get("courant_poids", 0.5)):
			continue   # trop lourd pour dériver : on tient debout
		var d := courant_de(sim, x.pos)
		if d == Vector2i.ZERO or not sim.grille.dans(x.pos + d) or not sim.grille.occupant(x.pos + d).is_empty():
			continue
		var avant: Vector2i = x.pos
		var compteur: int = int(x.compteur)
		if sim._deplacer(x, x.pos + d, sim.tick_de(x)):
			x.compteur = compteur   # la dérive ne coûte aucun tick à qui la subit
			if x.pos != avant:
				EventBus.emettre(&"journal", [&"journal.emporte", {"nom": x.name_key}])
	for idx in sim.contenants.keys().duplicate():
		var t := sim.grille.pos_de(int(idx))
		if not ("butin" in sim.grille.contenu_de(t).get("tags", [])) or sim.grille.niveau_liquide(t) <= 0 or rng.randf() >= chance:
			continue
		var d2 := courant_de(sim, t)
		if d2 == Vector2i.ZERO or not sim.grille.dans(t + d2) or sim.grille.bloque_passage(t + d2):
			continue
		var uids: Array = sim.contenants[idx]
		var emportes: Array = []   # le courant n'emporte que ce qui flotte : une enclume reste au fond
		var restent: Array = []
		for uid in uids:
			(emportes if flotte(sim, str(uid)) else restent).append(uid)
		if emportes.is_empty():
			continue
		sim.contenants.erase(idx)
		sim.grille.contenu[int(idx)] = 0
		EventBus.emettre(&"tile_changed", [t])
		if not restent.is_empty():
			SimObjets._poser_contenant(sim, t, restent, "butin")
		SimObjets._poser_contenant(sim, t + d2, emportes, "butin")


## Une tuile d'écoulement est alimentée si, en remontant le courant (voisine plus haute portant un liquide, ou de même hauteur d'un niveau
## supérieur), on atteint une source. Un simple regard aux voisines ne suffit pas : un bord qui s'assèche « nourrirait » l'intérieur.
static func _alimentee(sim: Simulation, t: Vector2i) -> bool:
	var vus: Dictionary = {sim.grille.idx(t): true}
	var file: Array[Vector2i] = [t]
	while not file.is_empty() and vus.size() < 128:
		var c: Vector2i = file.pop_front()
		var nc := sim.grille.niveau_liquide(c)
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + dd
			if not sim.grille.dans(q) or vus.has(sim.grille.idx(q)):
				continue
			var nq := sim.grille.niveau_liquide(q)
			if nq <= 0:
				continue
			if sim.grille.h(q) > sim.grille.h(c) or (sim.grille.h(q) == sim.grille.h(c) and nq > nc):
				if nq >= 8:
					return true
				vus[sim.grille.idx(q)] = true
				file.append(q)
	return false


## Un creux : l'eau n'a nulle part où aller (chaque voisine est plus haute, bloquante, ou déjà liquide).
static func _en_creux(sim: Simulation, t: Vector2i) -> bool:
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = t + dd
		if sim.grille.dans(q) and sim.grille.h(q) <= sim.grille.h(t) and sim.grille.niveau_liquide(q) == 0 and not sim.grille.bloque_passage(q):
			return false
	return true


## L'eau se retire d'un niveau ; à sec, la tuile redevient du sol et ses voisines sont réévaluées.
static func _retirer_eau(sim: Simulation, t: Vector2i, tout: bool = false) -> void:
	var ti := sim.grille.idx(t)
	var niveau := sim.grille.niveau_liquide(t)
	if niveau <= 0 or niveau >= 8:
		return
	if niveau > 1 and not tout:
		sim.grille.poser_eau(ti, niveau - 1)
		sim.eau_active[ti] = true
	else:
		sim.grille.contenu[ti] = 0
		sim.grille.oter_eau(ti)
		EventBus.emettre(&"journal", [&"journal.retrait", {"x": t.x, "y": t.y}])
	sim.grille.marquer(t)
	sim.lumiere_sale = true
	_reveiller_eau_autour(sim, t)
	EventBus.emettre(&"tile_changed", [t])


## Une source détruite disparaît (Eau et liquides) : la tuile redevient du sol, la nappe qu'elle nourrissait se retire.
static func _retirer_source(sim: Simulation, t: Vector2i) -> void:
	if sim.grille.niveau_liquide(t) < 8:
		return
	sim.grille.contenu[sim.grille.idx(t)] = 0
	sim.grille.marquer(t)
	sim.lumiere_sale = true
	EventBus.emettre(&"journal", [&"journal.source_comblee", {"x": t.x, "y": t.y}])
	_reveiller_eau_autour(sim, t)
	EventBus.emettre(&"tile_changed", [t])


## La canicule (Météo, effet evapore) : chaque flaque non alimentée perd un niveau.
static func _evaporation(sim: Simulation) -> void:
	var n := 0
	for ti in sim.grille.niveau_eau.keys():
		var t := sim.grille.pos_de(int(ti))
		if sim.grille.niveau_liquide(t) in range(1, 8) and not _alimentee(sim, t):
			_retirer_eau(sim, t)
			n += 1
	if n > 0:
		EventBus.emettre(&"journal", [&"journal.evaporation", {}])


## Poser un écoulement de niveau donné (jamais sur une source) et le rendre actif.
static func _poser_eau(sim: Simulation, q: Vector2i, niveau: int) -> void:
	var qi := sim.grille.idx(q)
	if sim.grille.niveau_liquide(q) >= 8:
		return
	var nouveau := sim.grille.niveau_liquide(q) == 0
	sim.grille.poser_contenu(q, "eau_ecoulement")
	sim.grille.poser_eau(qi, clampi(niveau, 1, 7))
	sim.grille.marquer(q)
	sim.eau_active[qi] = true
	sim.lumiere_sale = true
	if nouveau:
		EventBus.emettre(&"journal", [&"journal.inondation", {"x": q.x, "y": q.y}])
	EventBus.emettre(&"tile_changed", [q])


## Une goutte sur une tuile : elle ne prend qu'un creux ouvert (plus bas que ses quatre voisines), un niveau, jamais plus.
static func _pluie_sur(sim: Simulation, t: Vector2i) -> bool:
	if not sim.grille.dans(t) or sim.grille.bloque_passage(t) or sim.grille.niveau_liquide(t) > 0 or sim.grille.meubles.has(sim.grille.idx(t)) or not sim.grille.occupant(t).is_empty():
		return false
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = t + dd
		if not sim.grille.dans(q) or sim.grille.h(q) <= sim.grille.h(t):
			return false
	_poser_eau(sim, t, 1)
	sim.eau_active.erase(sim.grille.idx(t))   # une flaque de pluie ne se propage pas
	return true


## La lave (Eau et liquides) : elle brûle qui s'y tient, enflamme ses voisines, et se fige au contact de l'eau.
static func _tiquer_lave(sim: Simulation, tick: int) -> void:
	if tick < sim.eau_prochain_pas:
		return
	var lv: Dictionary = sim.regles.r.get("lave", {})
	for idx in sim.grille.dangers.keys():
		var t := sim.grille.pos_de(int(idx))
		if not ("lave" in sim.grille.contenu_de(t).get("tags", [])):
			continue
		var occ := sim.grille.occupant(t)
		if not occ.is_empty() and sim.entites.has(occ) and sim.entites[occ].vivant:
			var x: Dictionary = sim.entites[occ]
			var deg := sim.des.jet(str(lv.get("degats", "3d6")))
			sim._appliquer_degats(x, deg, "", {"type": "lave", "element": {"feu": 1.0}})
			sim.appliquer_statut(x, "brulure", int(lv.get("brulure_ticks", 40)), "")
			EventBus.emettre(&"journal", [&"journal.lave_brule", {"nom": x.name_key, "degats": deg}])
		var fige := ""
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = t + dd
			if not sim.grille.dans(q):
				continue
			var niv := sim.grille.niveau_liquide(q)
			if niv >= 8:
				fige = str(lv.get("obsidienne_source", "obsidienne"))
			elif niv > 0:
				if fige.is_empty():
					fige = str(lv.get("pierre_ecoulement", "basalte"))
				sim.grille.contenu[sim.grille.idx(q)] = 0   # l'écoulement s'évapore au contact
				sim.grille.oter_eau(sim.grille.idx(q))
				sim.grille.marquer(q)
				EventBus.emettre(&"tile_changed", [q])
			# Plus d'ignition directe : la coulée CHAUFFE (Émergence — les champs partagés) et la voisine s'enflamme
			# quand sa chaleur atteint le seuil de sa matière. C'est la même règle que pour le feu.
		if not fige.is_empty():
			_figer_lave(sim, t, fige)


## La lave figée par l'eau : obsidienne au contact d'une source, basalte au contact d'un écoulement.
static func _figer_lave(sim: Simulation, t: Vector2i, materiau: String) -> void:
	var idx := sim.grille.idx(t)
	sim.grille.poser_contenu(t, "obsidienne_figee")
	sim.grille.materiaux[idx] = materiau
	sim.grille.oter_danger(idx)
	sim.grille.marquer(t)
	sim.lumiere_sale = true
	EventBus.emettre(&"journal", [&"journal.lave_figee", {"x": t.x, "y": t.y}])
	EventBus.emettre(&"tile_changed", [t])


## La flammabilité d'une tuile (Météo : le feu) : celle du matériau de son contenu, d'une culture, ou de son sol nu.
static func flammabilite_de(sim: Simulation, t: Vector2i) -> int:
	if not sim.grille.dans(t) or sim.grille.niveau_liquide(t) > 0 or sim.grille.gel:
		return 0
	var fe: Dictionary = sim.regles.r.get("feu", {})
	var tags: Array = sim.grille.contenu_de(t).get("tags", [])
	if "culture" in tags:
		return int(fe.get("flamm_culture", 60))
	if "plante_sauvage" in tags:
		return int(fe.get("flamm_plante_sauvage", 50))
	if "vegetation" in tags or "construit" in tags or "mur" in tags:
		return int(GameData.catalogues.materials.get(sim.grille.materiau_de(t), {}).get("stats", {}).get("flammabilite", 0))
	if tags.is_empty() and sim.grille.meubles.has(sim.grille.idx(t)):
		return 40
	if tags.is_empty():
		return int(GameData.catalogues.materials.get(sim.grille.materiau_sol(t), {}).get("stats", {}).get("flammabilite", 0))
	return 0


## Une tuile prend feu si elle brûle ; retourne vrai si un feu vient de naître.
static func _enflammer(sim: Simulation, t: Vector2i) -> bool:
	if flammabilite_de(sim, t) <= 0 or sim.feux.has(sim.grille.idx(t)):
		return false
	sim.feux[sim.grille.idx(t)] = {"reste": int(sim.regles.r.get("feu", {}).get("duree_ticks", 80))}
	sim.grille.poser_danger(sim.grille.idx(t))
	sim.lumiere_sale = true
	EventBus.emettre(&"journal", [&"journal.feu_prend", {"x": t.x, "y": t.y}])
	EventBus.emettre(&"tile_changed", [t])
	return true


## Une poche percée (Gaz dans le sol) : le gaz remplit par inondation `volume` tuiles d'air à partir de la brèche — les
## galeries ouvertes, pas la roche — en zones au sol qui se dissipent après `duree_ticks`. Rend le nombre de tuiles.
static func _liberer_gaz(sim: Simulation, breche: Vector2i, gaz_id: String, tick: int) -> int:
	var cfg: Dictionary = GameData.config("gaz_regles")
	var lib: Dictionary = cfg.get("liberation", {})
	var volume := maxi(1, int(lib.get("volume", 14)))
	var duree := int(lib.get("duree_ticks", 400))
	sim.poches_gaz.erase(sim.grille.idx(breche))
	var vus := {breche: true}
	var file: Array[Vector2i] = [breche]
	var tete := 0
	var n := 0
	while tete < file.size() and n < volume:
		var t: Vector2i = file[tete]
		tete += 1
		sim.zones.append({"pos": t, "type": "gaz", "gaz": gaz_id, "fin": tick + duree, "source": "", "params": {}})
		EventBus.emettre(&"tile_changed", [t])
		n += 1
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = t + dd
			if vus.has(q) or not sim.grille.dans(q) or sim.grille.bloque_passage(q):
				continue
			vus[q] = true
			file.append(q)
	EventBus.emettre(&"journal", [&"journal.gaz_echappe", {"gaz": "gaz." + gaz_id, "n": n}])
	return n


## Une autre poche percée (Gaz dans le sol, 18 h 40) : la nappe fait de la brèche une source et l'automate d'eau inonde
## la galerie ; la géode rend ses gemmes brutes au sol ; le magma fait de la brèche de la lave.
static func _liberer_sous_sol(sim: Simulation, breche: Vector2i, genre: String, tick: int) -> void:
	var cfg: Dictionary = GameData.config("sous_sol")
	var i := sim.grille.idx(breche)
	sim.poches_sous_sol.erase(i)
	match genre:
		"eau":
			sim.grille.poser_contenu(breche, "eau")
			sim.grille.poser_eau(i, 8)
			sim.grille.marquer(breche)
			sim.eau_active[i] = true
			sim.lumiere_sale = true
			EventBus.emettre(&"journal", [&"journal.nappe_percee", {"x": breche.x, "y": breche.y}])
		"geode":
			var c: Dictionary = cfg.get("geodes", {})
			var profondeur := int(sim.donjon.get("profondeur", int(sim.donjon.get("etage", 1))))
			var gemmes: Array = []
			for b in c.get("gemmes_par_profondeur", []):
				if profondeur >= int(b[0]) and profondeur <= int(b[1]):
					gemmes = b[2]
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([sim.graine, "geode", i, tick])
			var uids: Array = []
			var n := maxi(1, sim.des.jet(str(c.get("quantite", "1d3"))))
			for k in n:
				var choix: Array = gemmes.filter(func(g: String) -> bool: return GameData.catalogues.materials.has(g))
				if choix.is_empty():
					break
				var brut: Dictionary = SimObjets.generer_objet(sim, "materiau_brut", 1, {}, "commun", 0)
				if brut.is_empty():
					break
				brut.materiau = str(choix[rng.randi_range(0, choix.size() - 1)])
				brut["forme"] = "brut"
				brut.quantite = 1
				uids.append(brut.uid)
			if not uids.is_empty():
				SimObjets._poser_contenant(sim, breche, uids, "butin")
			EventBus.emettre(&"journal", [&"journal.geode", {"n": uids.size()}])
		"magma":
			sim.grille.poser_contenu(breche, "lave")
			sim.grille.poser_danger(i)
			sim.grille.marquer(breche)
			sim.lumiere_sale = true
			EventBus.emettre(&"journal", [&"journal.magma_perce", {"x": breche.x, "y": breche.y}])
	EventBus.emettre(&"tile_changed", [breche])


## LA FUSION (ordre de travail 23, 2026-09-09) — la matière change d'état quand la chaleur atteint SON point de
## fusion. **Aucun seuil n'est écrit ici** : chacun est lu sur la fiche de la matière, en degrés réels, et la donnée
## de `thermique.fusion` ne dit que ce que la chose DEVIENT. C'est pour cela que le tableau est court et que le
## comportement est riche — l'étain coule à 232 et l'hématite tient à 1565 sans qu'une ligne le dise.
## **Ce qui est atteignable, c'est la donnée qui le décide** : un feu impose 1100 °C et une coulée 1150, donc le gypse
## (150) rend du plâtre au bord d'un feu, le calcaire (825) de la chaux, la malachite (200) son cuivre, le cinabre
## (580) son mercure ; la galène (1114) demande une coulée ; et le SABLE (1710) ne vitrifie jamais ainsi — il faut un
## four. C'est la vérité du monde réel, et elle vaut mieux qu'un nombre baissé pour rendre la démonstration jolie.
static func _fondre(sim: Simulation, t: Vector2i, i: int, degres: float, fu: Dictionary, mats: Dictionary) -> void:
	# a. Le SOL qui cuit : un dallage de calcaire devient de la chaux, le gypse du plâtre. C'est un four sans recette.
	var sols: Dictionary = fu.get("sols", {})
	var sid := sim.grille.materiau_sol(t)
	if sols.has(sid) and degres >= _fusion_de(mats, sid):
		sim.grille.sols[i] = str(sols[sid])
		sim.grille.recompiler_sols()
		sim.grille.marquer(t)
		EventBus.emettre(&"journal", [&"journal.sol_cuit", {"avant": sid, "apres": str(sols[sid]), "x": t.x, "y": t.y}])
		EventBus.emettre(&"tile_changed", [t])
	# b. Le FILON qui coule : le minerai rend son métal, et le lingot est ce qu'on en extrait ensuite. La malachite
	#    grillée au bord d'un feu devient du cuivre dans la paroi — personne n'a écrit cette scène, elle se déduit.
	var filons: Dictionary = fu.get("filons", {})
	var mid := str(sim.grille.materiaux.get(i, ""))
	if filons.has(mid) and degres >= _fusion_de(mats, mid):
		sim.grille.materiaux[i] = str(filons[mid])
		sim.grille.marquer(t)
		EventBus.emettre(&"journal", [&"journal.filon_fondu", {"avant": mid, "apres": str(filons[mid]), "x": t.x, "y": t.y}])
		EventBus.emettre(&"tile_changed", [t])


## Le point de fusion d'une matière, en degrés. 9999 : elle ne fond pas — elle brûle, se décompose, ou tient jusqu'à
## disparaître. Zéro serait un VRAI point de fusion, celui de la glace : c'est pourquoi le sentinelle est en haut.
static func _fusion_de(mats: Dictionary, id: String) -> float:
	return float(mats.get(id, {}).get("stats", {}).get("fusion", 9999))


## ---------------------------------------------------------------- le champ de danger (Émergence, 2026-09-08)

## Ce que vaut un nuage, lu sur la fiche du gaz : des dégâts ou une explosion valent le maximum, un statut vaut moins,
## un gaz qui ne fait qu'étouffer les feux vaut peu. Rien n'est inventé ici — tout se déduit de `gaz.json`.
static func _danger_du_gaz(cfg: Dictionary, gaz_id: String) -> int:
	var g: Dictionary = GameData.catalogues.gaz.get(gaz_id, {})
	if not str(g.get("degats", "")).is_empty() or g.has("explosion"):
		return int(cfg.get("gaz_degats", 100))
	if not str(g.get("statut", "")).is_empty():
		return int(cfg.get("gaz_statut", 60))
	return int(cfg.get("gaz_inerte", 30))


## Le pas du champ de danger. Il n'invente aucune source : il rend visibles à l'IA celles qui ne l'étaient pas.
## Le feu, la lave et les glyphes posent DÉJÀ leur danger eux-mêmes et gardent ce privilège — le champ ne touche jamais
## à leurs tuiles. Il n'ajoute que les deux qui manquaient, et c'est tout l'objet :
##   · **les nuages de gaz**, qui vivaient dans `sim.zones` sans que rien ne prévienne l'IA — elle marchait dans le
##     poison et dans le grisou ;
##   · **la chaleur**, invisible tant qu'il n'y a pas de flamme, alors qu'une tuile à 300 °C brûle celui qui s'y tient.
## Le code de décision de l'IA ne change pas d'une ligne : « on ne reste pas dans le danger » couvre désormais les deux.
static func _tiquer_danger(sim: Simulation, tick: int) -> void:
	var cfg: Dictionary = GameData.config("thermique").get("danger", {})
	if cfg.is_empty() or tick < sim.danger_prochain_pas:
		return
	sim.danger_prochain_pas = tick + maxi(1, int(cfg.get("periode_ticks", 10)))
	var voulu := {}
	# a. Les nuages.
	for z in sim.zones:
		if not sim.grille.dans(z.pos):
			continue
		var i_z := sim.grille.idx(z.pos)
		var v := int(cfg.get("gaz_degats", 100)) if str(z.get("type", "")) != "gaz" else _danger_du_gaz(cfg, str(z.get("gaz", "")))
		voulu[i_z] = maxi(int(voulu.get(i_z, 0)), v)
	# b. La chaleur, au-delà du seuil où elle blesse.
	var seuil := float(cfg.get("chaleur_seuil", 70.0))
	var plein := maxf(seuil + 1.0, float(cfg.get("chaleur_plein", 400.0)))
	for idx_c in sim.chaleur_active.keys():
		var i_c := int(idx_c)
		if i_c < 0 or i_c >= sim.carte_chaleur.size():
			continue
		var c := float(sim.carte_chaleur[i_c])
		if c < seuil:
			continue
		var v_c := clampi(roundi((c - seuil) / (plein - seuil) * 100.0), 1, 100)
		voulu[i_c] = maxi(int(voulu.get(i_c, 0)), v_c)
	# c. On retire ce que le champ avait posé et que plus rien ne justifie — sans jamais toucher au danger qu'un feu,
	#    une coulée ou un glyphe tient lui-même.
	for idx_a in sim.danger_champ.keys():
		var i_a := int(idx_a)
		if voulu.has(i_a) or _danger_tenu_ailleurs(sim, i_a):
			continue
		sim.grille.oter_danger(i_a)
	sim.danger_champ = voulu
	for i_v in voulu.keys():
		sim.grille.poser_danger(int(i_v), maxi(int(voulu[i_v]), sim.grille.dangers.get(int(i_v), 0)))


## Une tuile dont le danger appartient à quelqu'un d'autre que le champ : un feu qui brûle, une coulée de lave, un
## glyphe armé. Le champ ne les retire jamais — ce sont leurs propriétaires qui le font.
static func _danger_tenu_ailleurs(sim: Simulation, i: int) -> bool:
	if sim.feux.has(i):
		return true
	var t := sim.grille.pos_de(i)
	if "lave" in sim.grille.contenu_de(t).get("tags", []):
		return true
	for g in sim.glyphes:
		if sim.grille.dans(g.pos) and sim.grille.idx(g.pos) == i:
			return true
	return false


## Les effets météo de la cellule sous la fenêtre — lus par le feu (qui s'éteint sous la neige) et par la chaleur
## (le vent attise). Extrait le 2026-09-08 pour que les deux disent la même chose.
static func _effets_meteo(sim: Simulation) -> Array:
	if sim.lieu != "camp" or sim.monde == null:
		return []
	var centre := sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	return GameData.catalogues.weather_states.get(meteo(sim, sim.monde.cellule_de(centre)), {}).get("effects", [])


## ---------------------------------------------------------------- le champ de chaleur (Émergence, 2026-09-08)

## La chaleur d'une tuile, en degrés. Hors du champ actif c'est l'ambiante : le champ ne stocke que ce qui s'en écarte.
static func chaleur_a(sim: Simulation, t: Vector2i) -> float:
	if sim.carte_chaleur.is_empty() or not sim.grille.dans(t):
		return ambiante_de(sim)
	var i := sim.grille.idx(t)
	if i < 0 or i >= sim.carte_chaleur.size():
		return ambiante_de(sim)
	return float(sim.carte_chaleur[i])


## L'ambiante : la température de la cellule au camp, une valeur fixe ailleurs — sous terre, la roche tempère.
static func ambiante_de(sim: Simulation) -> float:
	if sim.lieu == "camp" and sim.monde != null:
		return temperature_cellule(sim)
	return float(GameData.config("thermique").get("ambiante_souterraine", 12.0))


## Verser des degrés sur une tuile — le geste qu'emploie tout ce qui chauffe : un feu, une coulée, et demain un noyau
## de sort. La tuile entre dans le champ actif, et c'est ce qui réveille la diffusion autour d'elle.
static func chauffer(sim: Simulation, t: Vector2i, degres: float) -> void:
	if not sim.grille.dans(t):
		return
	_chaleur_dimensionner(sim)
	var i := sim.grille.idx(t)
	if i < 0 or i >= sim.carte_chaleur.size():
		return
	sim.carte_chaleur[i] = maxf(float(sim.carte_chaleur[i]), degres)
	sim.chaleur_active[i] = true


## La carte, dimensionnée sur la couche 0 de la grille courante et remplie de l'ambiante. Elle se refait quand la
## grille change : ses index ne veulent rien dire ailleurs.
static func _chaleur_dimensionner(sim: Simulation) -> void:
	var n := sim.grille.largeur * sim.grille.hauteur_grille
	if sim.chaleur_grille == sim.grille and sim.carte_chaleur.size() == n:
		return
	sim.chaleur_grille = sim.grille
	sim.carte_chaleur = PackedFloat32Array()
	sim.carte_chaleur.resize(n)
	sim.chaleur_active.clear()
	var amb := ambiante_de(sim)
	for i in n:
		sim.carte_chaleur[i] = amb


## Le pas du champ de chaleur. Les sources imposent leur température, la chaleur diffuse vers les quatre voisines
## (modérée par l'isolation de la matière), tout revient vers l'ambiante, et ce qui l'a rejointe quitte le champ actif.
## Puis les CONSOMMATEURS : une tuile s'enflamme quand sa chaleur atteint le seuil de sa matière — ce qui remplace le
## jet de propagation du feu et l'ignition directe par la lave — et l'occupant d'une tuile trop chaude ou trop froide
## en souffre (sauf sur le feu et la lave eux-mêmes : ceux-là brûlent au contact, c'est leur règle propre).
static func _tiquer_chaleur(sim: Simulation, tick: int) -> void:
	var cfg: Dictionary = GameData.config("thermique")
	if cfg.is_empty() or tick < sim.chaleur_prochain_pas:
		return
	sim.chaleur_prochain_pas = tick + maxi(1, int(cfg.get("periode_ticks", 10)))
	var amb := ambiante_de(sim)
	# 1. Les sources. Le vent attise le feu — c'est ce qui reste de `vent_mult` après le retrait du jet.
	var src: Dictionary = cfg.get("sources", {})
	var effets: Array = _effets_meteo(sim)
	var vent := 1.0
	if "vent" in effets or "tempete" in effets:
		vent = float(sim.regles.r.get("feu", {}).get("vent_mult", 2.0))
	var laves := {}
	for idx in sim.feux.keys():
		chauffer(sim, sim.grille.pos_de(int(idx)), float(src.get("feu", 950.0)) * vent)
	for idx in sim.grille.dangers.keys():
		var td := sim.grille.pos_de(int(idx))
		if "lave" in sim.grille.contenu_de(td).get("tags", []):
			laves[int(idx)] = true
			chauffer(sim, td, float(src.get("lave", 1150.0)))
	if sim.chaleur_active.is_empty():
		return   # rien ne chauffe : le champ EST l'ambiante, et le pas ne coûte rien
	_chaleur_dimensionner(sim)
	# 2. La diffusion, sur les seules tuiles actives et leurs voisines — jamais sur la fenêtre entière.
	var diff := float(cfg.get("diffusion", 0.45))
	var iso_ref := float(cfg.get("isolation_ref", 45.0))
	var retour := float(cfg.get("retour_ambiante", 0.035))
	var eps := float(cfg.get("epsilon", 1.5))
	var inertie_ref := float(cfg.get("inertie_ref", 8.0))
	var etendre := sim.chaleur_active.size() < int(cfg.get("actives_max", 4096))
	var mats: Dictionary = GameData.catalogues.materials
	var a_traiter := {}
	for idx in sim.chaleur_active.keys():
		a_traiter[int(idx)] = true
		if not etendre:
			continue
		var tv := sim.grille.pos_de(int(idx))
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if sim.grille.dans(tv + dd):
				a_traiter[sim.grille.idx(tv + dd)] = true
	var cles: Array = a_traiter.keys()
	cles.sort()   # un ordre FIXE : la suite compare des résultats exacts, un champ diffusé ne peut pas dépendre du hasard
	var neuf := {}
	for idx in cles:
		var i := int(idx)
		if i < 0 or i >= sim.carte_chaleur.size():
			continue
		var t := sim.grille.pos_de(i)
		var somme := 0.0
		var n_v := 0
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = t + dd
			if not sim.grille.dans(q):
				continue
			somme += chaleur_a(sim, q)
			n_v += 1
		var cur := float(sim.carte_chaleur[i])
		var v := cur
		if n_v > 0:
			# Deux propriétés de la matière, et deux seulement. L'ISOLATION freine l'échange : une paroi isolante garde
			# sa chaleur, un métal la donne. La DENSITÉ est la masse thermique : une matière dense met du temps à
			# changer de température, une matière légère suit tout de suite. Le facteur d'inertie vaut 1 pile à la
			# densité de référence, ce qui laisse le calage du 2026-09-08 intact ; le pin (densité 4) chauffe plus vite
			# qu'avant, le granit (16) et le fer (8) plus lentement.
			var mat := str(sim.grille.materiau_de(t))
			if mat.is_empty():
				mat = str(sim.grille.materiau_sol(t))
			var st: Dictionary = mats.get(mat, {}).get("stats", {})
			var iso := float(st.get("isolation", 0.0))
			var dens := float(st.get("densite", inertie_ref))
			var inertie := clampf(2.0 * inertie_ref / maxf(0.1, inertie_ref + dens), 0.25, 2.0)
			v += diff * (iso_ref / maxf(1.0, iso_ref + iso)) * inertie * (somme / float(n_v) - cur)
		v += retour * (amb - v)
		neuf[i] = v
	for i in neuf.keys():
		sim.carte_chaleur[int(i)] = float(neuf[i])
		if absf(float(neuf[i]) - amb) <= eps:
			sim.chaleur_active.erase(int(i))
		else:
			sim.chaleur_active[int(i)] = true
	# 3. Les consommateurs.
	var ig: Dictionary = cfg.get("ignition", {})
	var dg: Dictionary = cfg.get("degats", {})
	var s_min := float(ig.get("seuil_min", 110.0))
	var s_max := float(ig.get("seuil_max", 460.0))
	var fu: Dictionary = cfg.get("fusion", {})
	var chaud := float(dg.get("seuil_chaud", 70.0))
	var froid := float(dg.get("seuil_froid", -12.0))
	for idx in sim.chaleur_active.keys():
		var i := int(idx)
		var t := sim.grille.pos_de(i)
		var c := float(sim.carte_chaleur[i])
		# a. L'ignition : le seuil d'une tuile s'interpole sur sa flammabilité. C'est ce qui REMPLACE les deux jets.
		var fl := flammabilite_de(sim, t)
		if fl >= int(ig.get("flammabilite_min", 1)) and not sim.feux.has(i):
			if c >= s_max - clampf(float(fl) / 100.0, 0.0, 1.0) * (s_max - s_min):
				_enflammer(sim, t)
		# b. LA FUSION (ordre de travail 23, 2026-09-09) : la matière change d'état quand la chaleur atteint SON
		#    point de fusion. Jusqu'ici la chaleur ne savait que BRÛLER.
		if not fu.is_empty():
			_fondre(sim, t, i, c, fu, mats)
		# c. Ce qu'un corps prend de l'air lui-même. Le feu et la lave brûlent au contact : leur tuile n'est pas ici.
		if sim.feux.has(i) or laves.has(i):
			continue
		var occ := sim.grille.occupant(t)
		if occ.is_empty() or not sim.entites.has(occ) or not sim.entites[occ].vivant:
			continue
		var c_ecart := 0.0
		if c >= chaud:
			c_ecart = c - chaud
		elif c <= froid:
			c_ecart = froid - c
		if c_ecart <= 0.0:
			continue
		var x: Dictionary = sim.entites[occ]
		var fact := minf(float(dg.get("facteur_max", 2.5)), 1.0 + c_ecart * float(dg.get("par_degre", 0.01)))
		var deg := maxi(1, roundi(float(sim.des.jet(str(dg.get("des", "1d4")))) * fact))
		sim._appliquer_degats(x, deg, "", {"type": "chaleur", "element": {"feu": 1.0} if c >= chaud else {"eau": 1.0}})
		if c >= chaud:
			sim.appliquer_statut(x, "brulure", int(dg.get("brulure_ticks", 20)), "")
		EventBus.emettre(&"journal", [&"journal.chaleur_blesse", {"nom": x.name_key, "degres": int(c), "degats": deg}])


## Le pas du gaz (Gaz dans le sol), à la cadence de `gaz.periode_ticks` : chaque zone de gaz fait sa nature à son
## occupant (dégâts, statut) ; un gaz inflammable qu'une flamme touche — une lumière en main, un feu au sol, de la lave
## voisine — explose avec la formule des Explosions, et tout le nuage de ce gaz part d'un coup.
static func _tiquer_gaz(sim: Simulation, tick: int) -> void:
	if tick < sim.gaz_prochain_pas:
		return
	var cfg: Dictionary = GameData.config("gaz_regles")
	sim.gaz_prochain_pas = tick + int(cfg.get("periode_ticks", 10))
	var defs: Dictionary = GameData.catalogues.gaz   # le CATALOGUE, un fichier par gaz depuis le 2026-09-08
	for z in sim.zones.duplicate():
		if str(z.get("type", "")) != "gaz":
			continue
		var d: Dictionary = defs.get(str(z.gaz), {})
		if d.is_empty():
			continue
		var t: Vector2i = z.pos
		var occ := sim.grille.occupant(t)
		var x: Dictionary = sim.entites.get(occ, {}) if not occ.is_empty() else {}
		if bool(d.get("eteint_feux", false)) and sim.feux.has(sim.grille.idx(t)):   # le nuage étouffe le feu sous lui
			sim.feux.erase(sim.grille.idx(t))
			sim.grille.oter_danger(sim.grille.idx(t))
			sim.lumiere_sale = true
			EventBus.emettre(&"tile_changed", [t])
		if not x.is_empty() and bool(x.get("vivant", false)):
			if not str(d.get("degats", "")).is_empty():
				var deg := sim.des.jet(str(d.degats))
				sim._appliquer_degats(x, deg, "", {"type": "gaz", "element": d.get("element", {})})
				EventBus.emettre(&"journal", [&"journal.gaz_blesse", {"nom": x.name_key, "gaz": "gaz." + str(z.gaz), "degats": deg}])
			if not str(d.get("statut", "")).is_empty():
				sim.appliquer_statut(x, str(d.statut), int(d.get("statut_ticks", 30)), "")
			if not str(d.get("soigne", "")).is_empty() and int(x.sante) < int(x.sante_max):
				var soin := mini(sim.des.jet(str(d.soigne)), int(x.sante_max) - int(x.sante))
				x.sante = int(x.sante) + soin
				EventBus.emettre(&"journal", [&"journal.gaz_soigne", {"nom": x.name_key, "gaz": "gaz." + str(z.gaz), "n": soin}])
			if not str(d.get("mana", "")).is_empty() and x.has("mana_max") and int(x.get("mana", 0)) < int(x.mana_max):
				var plus := mini(sim.des.jet(str(d.mana)), int(x.mana_max) - int(x.get("mana", 0)))
				x.mana = int(x.get("mana", 0)) + plus
				EventBus.emettre(&"journal", [&"journal.gaz_mana", {"nom": x.name_key, "gaz": "gaz." + str(z.gaz), "n": plus}])
		if not bool(d.get("inflammable", false)):
			continue
		var flamme := sim.feux.has(sim.grille.idx(t)) or (not x.is_empty() and sim.lumiere_de(x) >= int(d.get("lumiere_min", 1)))
		if not flamme:
			for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = t + dd
				if sim.grille.dans(q) and "lave" in sim.grille.contenu_de(q).get("tags", []):
					flamme = true
		if not flamme:
			continue
		var restantes: Array[Dictionary] = []   # tout le nuage de ce gaz part d'un coup
		for z2 in sim.zones:
			if str(z2.get("type", "")) == "gaz" and str(z2.gaz) == str(z.gaz):
				EventBus.emettre(&"tile_changed", [z2.pos])
			else:
				restantes.append(z2)
		sim.zones = restantes
		var ex: Dictionary = d.get("explosion", {})
		EventBus.emettre(&"journal", [&"journal.gaz_explose", {"gaz": "gaz." + str(z.gaz)}])
		sim._exploser({"pos": t, "rayon": int(ex.get("rayon", 2)), "puissance": float(ex.get("puissance", 25)), "degats": str(ex.get("degats", "4d6")), "source": ""})
		return   # les zones ont changé : le reste attend le pas suivant


## Le pas du feu : brûle qui s'y tient, gagne ses voisines, s'éteint sous la pluie, consume la tuile au bout de sa durée.
static func _tiquer_feux(sim: Simulation, tick: int) -> void:
	if sim.feux.is_empty() or tick < sim.feu_prochain_pas:
		return
	var fe: Dictionary = sim.regles.r.get("feu", {})
	var periode := int(fe.get("periode_ticks", 10))
	sim.feu_prochain_pas = tick + periode
	var effets: Array = _effets_meteo(sim)
	if "eteint_feux" in effets or "neige" in effets or sim.grille.neige:
		var n := sim.feux.size()
		for idx in sim.feux.keys():
			sim.grille.oter_danger(int(idx))
			EventBus.emettre(&"tile_changed", [sim.grille.pos_de(int(idx))])
		sim.feux.clear()
		sim.lumiere_sale = true
		EventBus.emettre(&"journal", [&"journal.feux_eteints", {"n": n}])
		return
	for idx in sim.feux.keys():
		var t := sim.grille.pos_de(int(idx))
		var occ := sim.grille.occupant(t)
		if not occ.is_empty() and sim.entites.has(occ) and sim.entites[occ].vivant:
			var x: Dictionary = sim.entites[occ]
			var deg := sim.des.jet(str(fe.get("degats", "1d6")))
			sim._appliquer_degats(x, deg, "", {"type": "feu", "element": {"feu": 1.0}})
			sim.appliquer_statut(x, "brulure", int(fe.get("brulure_ticks", 30)), "")
			EventBus.emettre(&"journal", [&"journal.brule", {"nom": x.name_key, "degats": deg}])
		# La propagation par jet a été RETIRÉE le 2026-09-08 (Émergence — les champs partagés) : le feu ne fait plus
		# que CHAUFFER sa tuile, et une voisine s'enflamme quand sa propre chaleur atteint le seuil de sa matière.
		# Le vent n'est pas perdu — il attise la source de chaleur au lieu de doubler un tirage.
		sim.feux[idx].reste = int(sim.feux[idx].reste) - periode
		if int(sim.feux[idx].reste) <= 0:
			_consumer(sim, t)


## La tuile consumée : son contenu s'en va, le terrain est mémorisé (il repousse hors claim).
static func _consumer(sim: Simulation, t: Vector2i) -> void:
	var idx := sim.grille.idx(t)
	sim.feux.erase(idx)
	sim.grille.oter_danger(idx)
	if sim.grille.contenu[idx] != 0 and not ("contenant" in sim.grille.contenu_de(t).get("tags", [])):
		_memoriser_terrain(sim, t)
		sim.grille.contenu[idx] = 0
		sim.grille.marquer(t)
	if sim.grille.meubles.has(idx):
		sim.grille.retirer_meuble(idx)
		sim.grille.marquer(t)
	sim.lumiere_sale = true
	EventBus.emettre(&"journal", [&"journal.feu_consume", {"x": t.x, "y": t.y}])
	EventBus.emettre(&"tile_changed", [t])


## La tempête (effet météo arrache_fragiles) : quelques tuiles très fragiles et exposées s'envolent.
static func _arrachage(sim: Simulation, tick: int) -> void:
	var fe: Dictionary = sim.regles.r.get("feu", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "arrachage", tick])
	var centre := sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	for x in sim.vivants():
		if x.controle == "joueur":
			centre = x.pos
			break
	var portee := int(fe.get("arrachage_portee", 20))
	var reste := int(fe.get("arrachage_tuiles", 3))
	for essai in 60:
		if reste <= 0:
			return
		var t := centre + Vector2i(rng.randi_range(-portee, portee), rng.randi_range(-portee, portee))
		if _arracher(sim, t, int(fe.get("arrachage_durete", 3))):
			reste -= 1


## Une tuile s'arrache si son matériau est très tendre et qu'aucune voisine plus haute ne l'abrite.
static func _arracher(sim: Simulation, t: Vector2i, durete_max: int) -> bool:
	if not sim.grille.dans(t) or sim.grille.contenu[sim.grille.idx(t)] == 0 or sim.grille.meubles.has(sim.grille.idx(t)):
		return false
	if "contenant" in sim.grille.contenu_de(t).get("tags", []) or sim.grille.niveau_liquide(t) > 0:
		return false
	var mat: Dictionary = GameData.catalogues.materials.get(sim.grille.materiau_de(t), {})
	if mat.is_empty() or int(mat.get("stats", {}).get("durete", 99)) > durete_max:
		return false
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if sim.grille.dans(t + dd) and sim.grille.h(t + dd) > sim.grille.h(t):
			return false   # abritée par plus haut qu'elle
	_memoriser_terrain(sim, t)
	sim.grille.contenu[sim.grille.idx(t)] = 0
	sim.grille.marquer(t)
	sim.lumiere_sale = true
	EventBus.emettre(&"journal", [&"journal.arrachage", {"x": t.x, "y": t.y}])
	EventBus.emettre(&"tile_changed", [t])
	return true


## La canicule (effet météo ignition) : chaque heure, une chance qu'une tuile inflammable prenne autour du joueur.
static func _ignition_canicule(sim: Simulation, tick: int) -> void:
	var fe: Dictionary = sim.regles.r.get("feu", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "canicule", tick])
	if rng.randf() >= float(fe.get("canicule_chance", 0.15)):
		return
	var centre := sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	for x in sim.vivants():
		if x.controle == "joueur":
			centre = x.pos
			break
	var portee := int(fe.get("canicule_portee", 20))
	for essai in 40:
		var t := centre + Vector2i(rng.randi_range(-portee, portee), rng.randi_range(-portee, portee))
		if _enflammer(sim, t):
			return


## La foudre de l'orage (Météo) : un impact par heure, ciblé par hauteur et conductivité autour du joueur.
static func _foudre(sim: Simulation, tick: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "foudre", tick])
	var centre := sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	for x in sim.vivants():
		if x.controle == "joueur":
			centre = x.pos
			break
	var t := _cible_foudre(sim, rng, centre)
	if sim.grille.dans(t):
		_frapper_foudre(sim, t)


## La tuile que la foudre choisit : la plus haute et la plus conductrice parmi des candidates au hasard (paratonnerre émergent).
static func _cible_foudre(sim: Simulation, rng: RandomNumberGenerator, centre: Vector2i) -> Vector2i:
	var ea: Dictionary = sim.regles.r.get("eau", {})
	var portee := int(ea.get("foudre_portee_joueur", 24))
	var meilleure := Vector2i(-1, -1)
	var score_max := -1.0
	for essai in int(ea.get("foudre_candidats", 40)):
		var t := centre + Vector2i(rng.randi_range(-portee, portee), rng.randi_range(-portee, portee))
		if not sim.grille.dans(t):
			continue
		var score := float(sim.grille.h(t)) * 10.0 + rng.randf()
		if sim.grille.bloque_passage(t):   # un relief ou un mur : son matériau compte
			score += float(GameData.entree("materials", sim.grille.materiau_de(t)).get("stats", {}).get("conductivite_electrique", 5))
		if score > score_max:
			score_max = score
			meilleure = t
	return meilleure


## L'impact : 3d8 en zone 1, puis la nappe d'eau connexe (Eau et liquides : conductivité).
static func _frapper_foudre(sim: Simulation, t: Vector2i) -> void:
	var ea: Dictionary = sim.regles.r.get("eau", {})
	EventBus.emettre(&"journal", [&"journal.foudre", {"x": t.x, "y": t.y}])
	sim.lumiere_sale = true
	_enflammer(sim, t)   # ignition
	var touches: Dictionary = {}
	for x in sim.vivants():
		if Grille.distance(x.pos, t) <= 1:
			touches[x.id] = true
			sim._appliquer_degats(x, sim.des.jet(str(ea.get("foudre_des", "3d8"))), "", {"type": "foudre"})
	if sim.grille.niveau_liquide(t) <= 0 or sim.grille.gel:
		return
	var rayon := int(ea.get("foudre_rayon_mer", 8)) if sim.grille.niveau_liquide(t) >= 8 else int(ea.get("foudre_rayon_eau", 5))
	var nappe: Dictionary = {sim.grille.idx(t): true}
	var file: Array[Vector2i] = [t]
	var tete := 0
	while tete < file.size():
		var c: Vector2i = file[tete]
		tete += 1
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + dd
			if sim.grille.dans(q) and not nappe.has(sim.grille.idx(q)) and Grille.distance(q, t) <= rayon and sim.grille.niveau_liquide(q) > 0:
				nappe[sim.grille.idx(q)] = true
				file.append(q)
	var n := 0
	for x in sim.vivants():
		if not touches.has(x.id) and nappe.has(sim.grille.idx(x.pos)):
			n += 1
			sim._appliquer_degats(x, sim.des.jet(str(ea.get("foudre_des", "3d8"))), "", {"type": "foudre"})
	if n > 0:
		EventBus.emettre(&"journal", [&"journal.foudre_eau", {"n": n}])


## La pluie (Météo) remplit les creux ouverts d'un niveau : des tuiles plus basses que leurs quatre voisines.
static func _pluie(sim: Simulation, tick: int) -> void:
	var ea: Dictionary = sim.regles.r.get("eau", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "pluie", tick])
	var n := 0
	for essai in int(ea.get("pluie_tuiles", 20)) * 8:
		if n >= int(ea.get("pluie_tuiles", 20)):
			break
		var t := sim.grille.pos_de(rng.randi_range(0, sim.grille.largeur * sim.grille.hauteur_grille - 1))
		if _pluie_sur(sim, t):
			n += 1
	if n > 0:
		EventBus.emettre(&"journal", [&"journal.pluie_creux", {}])


## Terrasser (Destruction du terrain) : ±1 de hauteur sur une tuile de sol adjacente ; élever demande une pioche.
static func _terrasser(sim: Simulation, e: Dictionary, vers: Vector2i, sens: int, tick: int) -> bool:
	var tr: Dictionary = sim.regles.r.terrasser
	if not sim.grille.dans(vers) or Grille.distance(e.pos, vers) != 1 or sens == 0:
		return false
	if sim.grille.bloque_passage(vers) or not sim.grille.occupant(vers).is_empty() or sim.grille.meubles.has(sim.grille.idx(vers)) or sim.grille.stations_fixes.has(sim.grille.idx(vers)):
		return false
	var h := sim.grille.h(vers) + signi(sens)
	if h < int(tr.h_min) or h > int(tr.h_max):
		return false
	if sens > 0:
		var fonct: Dictionary = sim.fonctionnalites.get(str(Etres.arme(e, sim.items).get("functionality", "")), {})
		if not (str(fonct.get("outil", "")) in tr.outils_elever):   # pioche ou pelle (Destruction du terrain)
			EventBus.emettre(&"journal", [&"journal.terrasser_outil", {}])
			return false
	if e.vigueur < int(tr.vigueur):
		return false
	_memoriser_terrain(sim, vers)
	sim.grille.hauteurs[sim.grille.idx(vers)] = h
	if sens > 0 and sim.grille.niveau_liquide(vers) > 0:   # Eau et liquides : élever une tuile d'eau la comble (une source détruite disparaît)
		if sim.grille.niveau_liquide(vers) >= 8:
			_retirer_source(sim, vers)
		else:
			_retirer_eau(sim, vers, true)
	e.vigueur -= int(tr.vigueur)
	e.compteur = tick + int(tr.ticks)
	e["vue_sale"] = true
	sim.gagner_xp(e, "terrassement", int(tr.xp))
	EventBus.emettre(&"journal", [&"journal.terrasse", {"nom": e.name_key, "x": vers.x, "y": vers.y, "h": h}])
	EventBus.emettre(&"tile_changed", [vers])
	return true


## Chaque semaine, le monde efface les modifications de terrain hors des claims (Claims et persistance).
static func _regenerer_terrain_sauvage(sim: Simulation) -> void:
	var n := 0
	for t in sim.modifs_terrain.keys():
		if not sim.grille.dans(t):
			continue   # hors de la fenêtre : la mémoire reste, la tuile redeviendra atteignable
		if sim.monde != null and sim.monde.claims.has(SimCamp._cell_de(sim, t)):
			continue
		if not sim.grille.occupant(t).is_empty() or sim.grille.meubles.has(sim.grille.idx(t)) or sim.grille.stations_fixes.has(sim.grille.idx(t)):
			continue
		var o: Dictionary = sim.modifs_terrain[t]
		sim.grille.hauteurs[sim.grille.idx(t)] = int(o.h)
		sim.grille.contenu[sim.grille.idx(t)] = int(o.contenu)
		sim.modifs_terrain.erase(t)
		sim.lumiere_sale = true
		EventBus.emettre(&"tile_changed", [t])
		n += 1
	if n > 0:
		EventBus.emettre(&"journal", [&"journal.regeneration", {"n": n}])


## Cueillir une plante sauvage adjacente (Plantes) : la moitié d'une récolte cultivée, la tuile repoussera hors claim.
static func _cueillir(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if not sim.grille.dans(vers) or Grille.distance(e.pos, vers) != 1:
		return false
	if not ("plante_sauvage" in sim.grille.contenu_de(vers).get("tags", [])):
		return false
	var pid := sim.grille.materiau_de(vers)
	var pl: Dictionary = GameData.catalogues.plants.get(pid, {})
	if pl.is_empty():
		return false
	var cu: Dictionary = sim.regles.r.get("cueillette", {})
	var n := maxi(1, roundi(float(sim.des.jet(str(cu.get("des", "1d2")))) * sim.regles.skill_factor(sim.regles.niveau(e.competences_eff, str(cu.get("competence", "collecte"))))))
	for k in n:
		var o: Dictionary = SimObjets.generer_objet(sim, pid, 1, {}, "commun", 0)
		if not o.is_empty():
			SimObjets.donner(sim, e, o.uid)
	_memoriser_terrain(sim, vers)
	sim.grille.contenu[sim.grille.idx(vers)] = 0
	sim.grille.marquer(vers)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	e["vue_sale"] = true
	sim.gagner_xp(e, "herboristerie", 3)
	sim.lumiere_sale = true
	EventBus.emettre(&"tile_changed", [vers])
	EventBus.emettre(&"journal", [&"journal.cueillette", {"nom": e.name_key, "plante": pl.name_key, "n": n}])
	return true


static func _creuser(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	e["vue_sale"] = true
	if not sim.grille.dans(vers) or Grille.distance(e.pos, vers) != 1:
		return false
	var contenu := sim.grille.contenu_de(vers)
	if not ("destructible" in contenu.get("tags", [])):
		return false
	var cr: Dictionary = sim.regles.r.creuser
	var mat_id := sim.grille.materiau_de(vers)
	var mat: Dictionary = GameData.catalogues.materials.get(mat_id, {})
	var outil := Etres.arme(e, sim.items)
	var fonct: Dictionary = sim.fonctionnalites.get(str(outil.get("functionality", "")), {})
	var recolte := not mat.is_empty() and str(fonct.get("outil", "")) == str(mat.harvest.tool_category)
	var ticks := int(cr.ticks)
	if recolte:
		# Récolte (Récolte) : l'outil adapté est en main — la formule de la note, en ticks.
		var rr: Dictionary = sim.regles.r.recolte
		var force := float(outil.get("durete_base", rr.mains_nues_durete)) * float(outil.get("qualite", 1.0))
		var durete := float(mat.stats.durete)
		# Ce qui se trouve au fond ne se ramasse pas à la pioche de départ (designer 2026-09-02) : le
		# palier du matériau relève le seuil d'outil exigé et allonge le temps d'extraction. La dureté
		# seule ne suffisait pas — deux matières de même dureté ne coûtent pas le même effort.
		var pex: Dictionary = sim.regles.r.get("paliers_materiaux", {}).get(str(int(mat.get("palier", 1))), {})
		var lent := false
		if force < durete * float(rr.seuil_irrecoltable) * float(pex.get("outil_min", 1.0)):
			if SimTalents.a_talent(sim, e, "oeil_de_la_pierre"):   # Œil de la pierre (Talents de race) : rien n'est irrécoltable, mais ÷ 3
				lent = true
			else:
				EventBus.emettre(&"journal", [&"journal.rebondit", {"materiau": mat.name_key}])
				return false
		var n := sim.regles.niveau(e.competences_eff, str(mat.harvest.skill))
		ticks = maxi(1, ceili(durete / (force * sim.regles.skill_factor(n)) * float(rr.ticks_par_seconde) * float(pex.get("extraction_ticks", 1.0))))
		if lent:
			ticks = ticks * int(sim.regles.r.talents.oeil_de_la_pierre.recolte_div)
	sim._quitter_garde(e)
	e.orientation = vers - e.pos
	_memoriser_terrain(sim, vers)
	if bool(sim.donjon.get("mine", false)):   # dans une mine, ce qu'on ouvre reste ouvert (Mine sous une cellule)
		var cle_m := "%d|%d" % [int(sim.donjon.get("id", 0)), int(sim.donjon.get("etage", 1))]
		var deja: Array = sim.mines_creusees.get(cle_m, [])
		deja.append(sim.grille.idx(vers))
		sim.mines_creusees[cle_m] = deja
	sim.grille.contenu[sim.grille.idx(vers)] = 0
	sim.grille.materiaux.erase(sim.grille.idx(vers))
	sim.grille.hauteurs[sim.grille.idx(vers)] = sim.grille.h(e.pos)   # la brèche est au niveau de celui qui creuse
	sim.grille.marquer(vers)
	if sim.poches_gaz.has(sim.grille.idx(vers)):   # la pioche perce une poche : le gaz s'échappe (Gaz dans le sol)
		_liberer_gaz(sim, vers, str(sim.poches_gaz[sim.grille.idx(vers)]), tick)
	elif sim.poches_sous_sol.has(sim.grille.idx(vers)):   # la nappe, la géode, le magma
		_liberer_sous_sol(sim, vers, str(sim.poches_sous_sol[sim.grille.idx(vers)]), tick)
	e.vigueur = maxi(0, int(e.vigueur) - int(cr.vigueur))
	e.compteur = tick + sim._ticks_avec_statuts(e, ticks)
	if recolte:
		var rr2: Dictionary = sim.regles.r.recolte
		var n2 := sim.regles.niveau(e.competences_eff, str(mat.harvest.skill))
		# « aucun chiffre fixe » (Récolte) : un jet, multiplié par la compétence — plancher 1
		var quantite := maxi(1, roundi(float(sim.des.jet(str(rr2.get("des", "1d2")))) * sim.regles.skill_factor(n2)))
		_donner_materiau(sim, e, mat_id, quantite)
		sim.gagner_xp(e, str(mat.harvest.skill), int(mat.stats.durete))
		EventBus.emettre(&"journal", [&"journal.recolte", {"nom": e.name_key, "quantite": quantite, "materiau": mat.name_key}])
	else:
		sim.gagner_xp(e, "terrassement", int(cr.xp))
		if mat.is_empty():
			EventBus.emettre(&"journal", [&"journal.creuse", {"nom": e.name_key, "x": vers.x, "y": vers.y}])
		else:
			EventBus.emettre(&"journal", [&"journal.effrite", {"nom": e.name_key, "materiau": mat.name_key}])
	EventBus.emettre(&"tile_changed", [vers])
	return true


## Un matériau dans le sac : une pile par (matériau, forme) — `quantite` ; l'objet `materiau_brut` en base.
static func _donner_materiau(sim: Simulation, e: Dictionary, mat_id: String, quantite: int, forme: String = "brut", espece: String = "") -> void:
	var pile := _pile(sim, e, mat_id, forme, espece)   # deux cuirs d'espèces différentes ne s'empilent pas
	if not pile.is_empty():
		pile.quantite = int(pile.quantite) + quantite
		return
	var inst: Dictionary = SimObjets.generer_objet(sim, "materiau_brut", 1, {}, "commun", 0)
	if inst.is_empty():
		return
	inst.materiau = mat_id
	inst.forme = forme
	inst.quantite = quantite
	if not espece.is_empty():   # la matière garde la bête dont elle vient (point 69)
		inst["espece"] = espece
	inst.name_key = GameData.entree("materials", mat_id).name_key
	e.sac.append(inst.uid)


## La pile d'objets empilables d'une base (consommables) dans le sac.
static func _pile_objet(sim: Simulation, e: Dictionary, base: String) -> Dictionary:
	for uid in e.sac:
		var it: Dictionary = sim.items.get(uid, {})
		if str(it.get("base", "")) == base and "empilable" in it.get("tags", []):
			return it
	return {}


static func _pile(sim: Simulation, e: Dictionary, mat_id: String, forme: String, espece: String = "") -> Dictionary:
	for uid in e.sac:
		var it: Dictionary = sim.items.get(uid, {})
		if it.get("type", "") == "materiau" and it.get("materiau", "") == mat_id and str(it.get("forme", "brut")) == forme and str(it.get("espece", "")) == espece:
			return it
	return {}


## Retire `quantite` d'une pile ; la pile vide disparaît du sac.
static func _retirer_materiau(sim: Simulation, e: Dictionary, pile: Dictionary, quantite: int) -> void:
	pile.quantite = int(pile.quantite) - quantite
	if int(pile.quantite) <= 0:
		e.sac.erase(pile.uid)
		sim.items.erase(pile.uid)


# ---------------------------------------------------------------- le camp : poser, coffres, dormir

## Une tuile d'eau à nager (Eau et liquides) — gelée, elle se marche.
static func dans_l_eau(sim: Simulation, pos: Vector2i) -> bool:
	return sim.grille.dans(pos) and sim.grille.nageable(pos)


## Un objet flotte-t-il ? Sa flottabilité (stat de matière, 1 à 4 pour les métaux et les roches, 80 pour
## les bois) contre `stats_materiau.flottabilite_seuil`. Sans matière — un livre, une fiole — il flotte :
## c'est le comportement d'avant, et la stat ne doit mordre que là où elle existe (2026-09-04).
static func flotte(sim: Simulation, uid: String) -> bool:
	var it: Dictionary = sim.items.get(uid, {})
	if not it.get("stats", {}).has("flottabilite"):
		return true
	return float(it.get("stats", {}).get("flottabilite", 100.0)) >= float(sim.regles.r.get("stats_materiau", {}).get("flottabilite_seuil", 50.0))


## Pose des objets sur une tuile ; sur l'eau, ceux qui ne flottent pas COULENT — retirés du jeu, dits au
## journal — et seuls les autres se posent. Retourne ce qui reste à la surface.
static func _poser_ou_couler(sim: Simulation, pos: Vector2i, uids: Array, sorte: String) -> Array:
	if not dans_l_eau(sim, pos):
		SimObjets._poser_contenant(sim, pos, uids, sorte)
		return uids
	var restent: Array = []
	for uid in uids:
		if flotte(sim, str(uid)):
			restent.append(uid)
		else:
			EventBus.emettre(&"journal", [&"journal.coule", {"objet": SimObjets.nom_objet(sim, str(uid))}])
			sim.items.erase(str(uid))
			sim.objets.erase(str(uid))
	if not restent.is_empty():
		SimObjets._poser_contenant(sim, pos, restent, sorte)
	return restent


## La température au centre de la cellule chargée (biome, saison, météo, nuit) — pour le gel (Météo).
static func temperature_cellule(sim: Simulation) -> float:
	if sim.monde == null or sim.lieu != "camp":
		return 18.0
	var m: Dictionary = GameData.config("planete").get("meteo", {})
	var cell := sim.monde.cellule_de(sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2))
	var centre := sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	var temp: float = lerpf(float(m.temp_min), float(m.temp_max), sim.monde.surface.valeur("temperature", centre.x, centre.y)) + float(_saison_info(sim).temp)
	temp += float(GameData.catalogues.weather_states.get(meteo(sim, cell), {}).get("temp_mod", 0))
	if est_nuit(sim):
		temp += float(m.get("mod_nuit", -8))
	return temp


## Les états météo de la grille (Météo) : neige et gel, recalculés à chaque pas au camp.
static func _maj_etats_meteo(sim: Simulation) -> void:
	if sim.monde == null or sim.lieu != "camp":
		sim.grille.neige = false
		sim.grille.gel = false
		return
	var cell := sim.monde.cellule_de(sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2))
	var etat: Dictionary = GameData.catalogues.weather_states.get(meteo(sim, cell), {})
	var neige_avant := sim.grille.neige
	var gel_avant := sim.grille.gel
	sim.grille.neige = "neige" in etat.get("effects", [])
	sim.grille.gel = temperature_cellule(sim) < float(sim.regles.r.deplacement.get("gel_seuil", 0.0))
	if neige_avant != sim.grille.neige or gel_avant != sim.grille.gel:
		EventBus.emettre(&"tile_changed", [sim.grille.pos_de(0)])   # le client redessine (neige, glace)


static func souffle_max(sim: Simulation, e: Dictionary) -> int:
	return int(sim.regles.r.nage.souffle_base) + int(e.stats_eff.get("endurance", 0)) * int(sim.regles.r.nage.souffle_par_endurance)


## Le souffle (Eau et liquides) : décroît dans l'eau, se remplit dehors ; à zéro, 1d6 par période.
static func _tiquer_souffle(sim: Simulation, nom: String, tick: int) -> void:
	var ng: Dictionary = sim.regles.r.nage
	for e in sim.vivants():
		if e.horloge != nom or Etres.est_volant(e):
			continue
		var maxi_s := souffle_max(sim, e)
		if not e.has("souffle"):
			e["souffle"] = maxi_s
			e["souffle_tick"] = tick
		var ecoules := tick - int(e.souffle_tick)
		if ecoules <= 0:
			continue
		e.souffle_tick = tick
		if dans_l_eau(sim, e.pos) and not ("respiration_aquatique" in e.get("tags_acquis", [])):
			e.souffle = maxi(0, int(e.souffle) - ecoules)
			if int(e.souffle) <= 0:
				var periodes := tick / int(ng.periode_ticks) - (tick - ecoules) / int(ng.periode_ticks)
				for k in periodes:
					var deg := sim.des.jet(str(ng.degats_des))
					EventBus.emettre(&"journal", [&"journal.noyade", {"nom": e.name_key, "degats": deg}])
					sim._appliquer_degats(e, deg, "", {"type": "noyade", "element": {}})
		else:
			e.souffle = mini(maxi_s, int(e.souffle) + ecoules)


static func _cycle(sim: Simulation) -> Dictionary:
	return GameData.config("planete").get("cycle", {})


## L'heure du monde (0-24, décimale) et sa phase.
static func heure(sim: Simulation, tick: int = -1) -> float:
	var t := sim.horloge_monde.ticks if tick < 0 else tick
	var jour := int(_cycle(sim).get("ticks_par_jour", 24000))
	return float(posmod(t, jour)) / float(jour) * 24.0


static func phase(sim: Simulation, tick: int = -1) -> String:
	var h := heure(sim, tick)
	var c := _cycle(sim)
	if h >= float(c.aube[0]) and h < float(c.aube[1]):
		return "aube"
	if h >= float(c.jour[0]) and h < float(c.jour[1]):
		return "jour"
	if h >= float(c.crepuscule[0]) and h < float(c.crepuscule[1]):
		return "crepuscule"
	return "nuit"


static func est_nuit(sim: Simulation, tick: int = -1) -> bool:
	return phase(sim, tick) == "nuit"


## La saison (Décision — Saisons activées à l'étape 10) : 120 jours, cinq saisons Wu Xing, un écart de température.
static func saison(sim: Simulation, tick: int = -1) -> String:
	return _saison_info(sim, tick).id


static func _saison_info(sim: Simulation, tick: int = -1) -> Dictionary:
	var t := sim.horloge_monde.ticks if tick < 0 else tick
	var c := _cycle(sim)
	var sa: Dictionary = c.get("saisons", {})
	if sa.is_empty():
		return {"id": "printemps", "element": "bois", "temp": 0.0}
	var jour := (t / int(c.get("ticks_par_jour", 24000))) % int(sa.jours_par_an)
	for s in sa.liste:
		if jour >= int(s[1]) and jour < int(s[2]):
			return {"id": str(s[0]), "element": str(s[3]), "temp": float(s[4])}
	return {"id": str(sa.liste[0][0]), "element": str(sa.liste[0][3]), "temp": float(sa.liste[0][4])}


static func meteo(sim: Simulation, cell: Vector2i, tick: int = -1) -> String:
	if not sim.meteo_force.is_empty():
		return sim.meteo_force
	if sim.monde == null:
		return "clair"
	var m: Dictionary = GameData.config("planete").get("meteo", {})
	var t := sim.horloge_monde.ticks if tick < 0 else tick
	var n: FastNoiseLite = sim.monde.surface.bruits.get("meteo")
	if n == null:
		n = FastNoiseLite.new()
		n.seed = sim.monde.surface.graine + int(m.get("seed_offset", 77))
		n.frequency = float(m.get("frequence_spatiale", 0.0003))
		n.fractal_octaves = 2
		sim.monde.surface.bruits["meteo"] = n
	var taille: int = sim.monde.taille
	var cx := float(cell.x * taille)
	var cy := float(cell.y * taille)
	var front := float(t) / float(m.get("ticks_par_front", 24000)) * 900.0   # le front se déplace : le bruit défile
	var p := clampf((n.get_noise_2d(cx + front, cy - front * 0.4) + 1.0) * 0.5, 0.0, 1.0)
	var temp: float = sim.monde.surface.valeur("temperature", int(cx) + taille / 2, int(cy) + taille / 2) + float(_saison_info(sim, t).temp) / 40.0   # l'écart saisonnier, en fraction de la plage
	var hum := sim.monde.surface.valeur("humidite", int(cx) + taille / 2, int(cy) + taille / 2)
	var s: Dictionary = m.seuils
	if p >= float(s.extreme):
		return "blizzard" if temp < float(m.neige_temp) else "tempete"
	if p >= float(s.violent):
		return "neige" if temp < float(m.neige_temp) else "orage"
	if p >= float(s.precipitation):
		return "neige" if temp < float(m.neige_temp) else "pluie"
	if p >= float(s.couvert):
		return "brouillard" if hum >= float(m.brouillard_humidite) else "nuageux"
	if temp >= float(m.canicule_temp) and p < 0.2:
		return "canicule"
	if p < 0.12:
		return "vent_fort"
	return "clair"


## Température ressentie d'un être en surface (°C) et son écart à la zone de confort.
static func temperature_ressentie(sim: Simulation, e: Dictionary) -> Dictionary:
	var m: Dictionary = GameData.config("planete").get("meteo", {})
	if sim.monde == null or sim.lieu != "camp":
		return {"temp": 18.0, "ecart": 0.0, "meteo": "clair"}
	var cell := sim.monde.cellule_de(e.pos)
	var temp01 := sim.monde.surface.valeur("temperature", e.pos.x, e.pos.y)
	var temp: float = lerpf(float(m.temp_min), float(m.temp_max), temp01) + float(_saison_info(sim).temp)
	var etat_id := meteo(sim, cell)
	var etat: Dictionary = GameData.catalogues.weather_states.get(etat_id, {})
	temp += float(etat.get("temp_mod", 0))
	if est_nuit(sim):
		temp += float(_cycle(sim).get("mod_nuit", -8))
	var alt: float = float(sim.monde.surface.tectonique_a(e.pos.x, e.pos.y).altitude)
	var ma: Dictionary = m.mod_altitude
	if not e.has("corps"):   # un point du monde, pas un être : la température brute
		return {"temp": temp, "ecart": 0.0, "meteo": etat_id}
	if alt >= 0.85:
		temp += float(ma.haute_montagne)
	elif alt >= 0.70:
		temp += float(ma.montagne)
	elif alt >= 0.55:
		temp += float(ma.colline)
	var confort: Array = m.confort
	var ecart := 0.0
	if temp < float(confort[0]):
		# L'isolation de l'équipement compense le froid (Application des stats de matériau).
		var iso := Etres.add_statuts(e, "isolation", sim.statuts_defs)   # potion de résistance au froid
		for slot in e.equipement.keys():
			var it: Dictionary = sim.items.get(e.equipement[slot], {})
			iso += float(it.get("stats", {}).get("isolation", 0.0))
			iso += float(it.get("doublure_isolation", 0.0))   # la DOUBLURE compte en plus : c'est sa raison d'etre
		temp += iso / float(m.isolation_div)
		if temp < float(confort[0]):
			ecart = temp - float(confort[0])
	elif temp > float(confort[1]):
		temp -= Etres.add_statuts(e, "isolation_chaud", sim.statuts_defs) / float(m.isolation_div)   # potion de résistance au feu
		if temp > float(confort[1]):
			ecart = temp - float(confort[1])
	return {"temp": temp, "ecart": ecart, "meteo": etat_id}


static func _tiquer_meteo(sim: Simulation, tick: int) -> void:
	if sim.monde == null or sim.lieu != "camp":
		return
	var m: Dictionary = GameData.config("planete").get("meteo", {})
	for e in sim.joueurs():
		if not e.vivant:
			continue
		var cell := sim.monde.cellule_de(e.pos)
		var etat := meteo(sim, cell, tick)
		if etat != sim._meteo_courante:
			sim._meteo_courante = etat
			EventBus.emettre(&"journal", [&"journal.meteo", {"meteo": GameData.catalogues.weather_states[etat].name_key}])
		var demain := meteo(sim, cell, tick + int(_cycle(sim).get("ticks_par_jour", 24000)))
		if demain != sim._meteo_annoncee and demain in ["tempete", "blizzard", "canicule"]:
			sim._meteo_annoncee = demain
			EventBus.emettre(&"journal", [&"journal.meteo_annonce", {"meteo": GameData.catalogues.weather_states[demain].name_key}])
		var tr_ := temperature_ressentie(sim, e)
		e["temp_ressentie"] = tr_.temp
		e["ecart_confort"] = tr_.ecart
		if absf(float(tr_.ecart)) >= float(m.degats_hors_confort_ecart):
			var per := int(m.degats_periode)
			if tick / per != int(e.get("meteo_tick", 0)) / per:
				e.sante = maxi(1, int(e.sante) - 1)
				EventBus.emettre(&"journal", [&"journal.froid" if float(tr_.ecart) < 0.0 else &"journal.chaud", {"nom": e.name_key}])
		e["meteo_tick"] = tick


# ---------------------------------------------------------------- sauvegarde (Sauvegarde, E.10)
