class_name SimObjets
extends RefCounted
## Les êtres et les objets : ajouter un être, réapprovisionner, le loot composé, l'apparence et l'habillage ; donner, nommer, identifier, équiper, jeter, périmer, contenants, ramasser, respawn, sertir, lire, drop.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


static func ajouter(sim: Simulation, def_id: String, pos: Vector2i, controle: String) -> Dictionary:
	sim._n_entites += 1
	var id := "%s_%d" % [def_id, sim._n_entites]
	var def := sim.fiche_joueur if (controle == "joueur" and not sim.fiche_joueur.is_empty()) else GameData.entree("creatures", def_id)
	var e := Etres.instancier(id, def, pos, controle, sim.regles, sim.items)
	if controle == "joueur":   # les modules des capacités de départ sont connus, avec un kit de charges au dé
		for m in def.get("modules_connus", []):
			sim.crediter_module(e, str(m))
		for cap in e.get("capacites", []):
			for m in cap.get("modules", []):
				sim.crediter_module(e, str(m))
	if str(e.corps.get("silhouette", "")) == "humanoide" and e.get("apparence", {}).is_empty():
		var rng_ap := RandomNumberGenerator.new()   # un visage à tout humanoïde, tiré une fois pour toutes
		rng_ap.seed = hash([sim.graine, "apparence", id])
		e["apparence"] = _apparence_pour(sim, str(e.get("race", "humain")), rng_ap)
	SimTalents._contreparties(sim, e)
	e["or"] = 0
	if controle != "joueur" and "civil" in def.get("tags", []):
		_habiller_pnj(sim, e, def)
	for base in def.get("sac", []):   # objets de départ (bases) : instanciés dans le sac
		var inst := generer_objet(sim, str(base), 1, {}, "commun", 0)
		if not inst.is_empty():
			e.sac.append(inst.uid)
	# Variante rare (Monstres rares) : tirage à la résolution du spawn, stats ×2.5, teinte or, épithète, drop garanti.
	if controle == "ia":
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.graine, "rare", sim._n_entites, def_id])
		var chance := float(def.get("rare_chance", sim.regles.r.get("monstres_rares", {}).get("chance_defaut", 0.02)))
		if rng.randf() < chance:
			_rendre_rare(sim, e, rng)
	if e.chain_gauge:
		e.chaine = sim.wuxing.jauge_neuve()
	e.spawn = pos
	sim._assembler_kit(e)   # tout l'équipement est assemblé (designer 2026-09-02) : composants, matière, qualité
	Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
	sim.entites[id] = e
	sim.ordre.append(id)
	sim.grille.placer(id, pos)
	return e


## Génère un objet de loot et l'enregistre (son uid devient une clé de `items`).
## Le stock d'un marchand, décrit par des CATÉGORIES (`{filtre, nombre}`) et jamais par une liste d'objets :
## une boutique d'armurier vend « les armures de prototype en métal », donc toute armure qui le sera un jour.
## Complété chaque semaine quand il est vide (Commerce et boutiques).
## Le réapprovisionnement hebdomadaire d'un marchand vidé : sa boutique typée, ou le stock de sa fiche (marchand,
## forgeron — ceux-là ne se regarnissaient jamais, 2026-09-05 : « la plupart n'ont rien à vendre »).
static func _reapprovisionner(sim: Simulation, x: Dictionary) -> void:
	if not x.has("stock") or not x.get("stock", []).is_empty():
		return
	if not str(x.get("boutique", "")).is_empty():
		_garnir_stock(sim, x, GameData.entree("shop_types", str(x.boutique)).selection)
	else:
		_garnir_stock(sim, x, GameData.entree("creatures", str(x.get("def", ""))).get("stock_marchand", []))


static func _garnir_stock(sim: Simulation, e: Dictionary, selection: Array) -> void:
	if not e.has("stock"):
		e["stock"] = []
	var rng := RandomNumberGenerator.new()
	var sem := 0
	if sim.horloge_monde != null:
		sem = sim.horloge_monde.ticks / maxi(1, int(GameData.config("planete").corruption.ticks_par_semaine))
	rng.seed = hash([sim.graine, "stock", e.id, sem])
	var avant: int = e.stock.size()
	for bloc: Dictionary in selection:
		var n := rng.randi_range(int(bloc.nombre[0]), int(bloc.nombre[1]))
		for k in n:
			var base := GameData.tirer("items", bloc.filtre, rng)
			if base.is_empty():
				continue   # une catégorie vide n'est pas une erreur de jeu : l'audit des données la signale
			var o := generer_objet(sim, base, 1, {"categories_materiau": bloc.get("materiaux", [])}, "commun", 0)   # un forgeron assemble dans le métal
			if not o.is_empty():
				e.stock.append(o.uid)
	if avant == 0:
		e["stock_garni"] = e.stock.size()   # un garnissage complet : le plafond du jour de marché en dépend (Calendrier)


static func generer_objet(sim: Simulation, base_id: String, profondeur: int, provenance: Dictionary = {}, rarete: String = "", nb_affixes: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "loot", sim.objets.size(), base_id, profondeur])
	var inst := sim.loot.generer(base_id, profondeur, rng, provenance, rarete, nb_affixes)
	if inst.is_empty():
		return {}
	sim.objets[inst.uid] = inst
	sim.items[inst.uid] = inst
	if "assemble" in inst.get("tags", []) and not bool(provenance.get("assemblage", false)):
		_composer_loot(sim, inst, profondeur, rng, provenance.get("categories_materiau", []))   # un objet assemblé trouvé est composé : manche, tête, fixations tirés (designer, 2026-08-30)
	return inst


## Le loot assemblé (Loot — affixes, gemmes et rareté, 2026-08-30) : jamais « une simple épée » — chaque composant
## reçoit une recette, un matériau de sa famille (les minerais de l'étage favorisés) et une qualité d'artisan.
static func _composer_loot(sim: Simulation, inst: Dictionary, profondeur: int, rng: RandomNumberGenerator, cats_mat: Array = []) -> void:
	var def: Dictionary = GameData.entree("items", str(inst.base))
	if def.get("slots", {}).is_empty():
		return
	var la: Dictionary = GameData.config("loot_rules").get("assemblage", {})
	var niveau := int(la.get("niveau_base", 8)) + int(la.get("niveau_par_profondeur", 6)) * maxi(0, profondeur)
	var pieces: Array[Dictionary] = []
	for slot in def.slots.keys():
		var comp_id := str(def.slots[slot])
		var recettes: Array = []
		for rid in GameData.catalogues.component_recipes.keys():
			if str(GameData.catalogues.component_recipes[rid].component) == comp_id:
				recettes.append(GameData.catalogues.component_recipes[rid])
		if recettes.is_empty():
			continue
		# Les candidats de TOUTES les recettes du composant sont réunis avant le tirage (designer
		# 2026-09-01) : une famille d'un seul matériau ne doit pas peser autant qu'une famille de vingt-
		# trois — l'os massif sortait sur une armure sur deux.
		# `pool.has(m)` est un balayage LINEAIRE, et le pool d'une famille large compte deux cent trente
		# matieres : dedupliquer coutait 230 x 230 / 2 comparaisons par emplacement, trois emplacements
		# par objet, quatre-vingts objets par etage — six millions de comparaisons pour un plancher de
		# donjon. Un dictionnaire repond en temps constant et rend exactement le meme pool, dans le meme
		# ordre. Mesure : le butin des coffres passe de 53 ms a ce que dit la sonde de perf d'etage.
		var pool: Array[String] = []
		var vus_pool := {}
		for r in recettes:
			var fam: Dictionary = GameData.config("material_families").get(str(r.material_family), {})
			for m in _candidats_famille(sim, fam, cats_mat if slot in ["tete", "plaque", "monture"] else []):
				if not vus_pool.has(m):
					vus_pool[m] = true
					pool.append(m)
		# Le butin n'est pas limite aux matieres ATTENDUES pour ce composant (designer 2026-09-02) :
		# toutes peuvent sortir, mais celles qui s'eloignent de l'attendu deviennent rares. Un plastron
		# de metal est l'ordinaire, un plastron d'eau de mer existe et ne se voit presque jamais.
		var hors_slot := _hors_attente(sim, pool, slot)
		var mat_id := _tirer_materiau(sim, pool, profondeur, rng, hors_slot, slot)
		if mat_id.is_empty():
			continue
		var mat: Dictionary = GameData.entree("materials", mat_id)
		# On note si la matiere tiree sortait de l'attendu. C'est deja decide juste au-dessus ; sans le
		# noter, plus personne ne peut le savoir apres coup — ni la sonde de butin, ni l'inventaire un
		# jour. Une epee dont la lame est en cuir n'est pas un defaut (le designer l'a voulu), mais on
		# doit pouvoir MESURER a quelle frequence elle sort.
		pieces.append({"slot": slot, "composant": comp_id, "materiau": mat_id, "qualite": sim.regles.qualite_craft(niveau, rng),
			"hors_attente": hors_slot.has(mat_id),
			"stats": mat.get("stats", {}), "elements": mat.get("wuxing", {}) if mat.get("wuxing") != null else {}})
	if pieces.is_empty():
		return
	var borne: Array = sim.regles.r.craft.qualite.jet_assemblage
	var jet := clampf(sim.regles.qualite_craft(niveau, rng), float(borne[0]), float(borne[1]))
	_appliquer_composition(sim, inst, def, pieces, jet)


## Un matériau d'une famille (Recettes de composants) pour le loot : les minerais des étages ≤ profondeur pèsent plus.
static func _materiau_loot(sim: Simulation, fam: Dictionary, profondeur: int, rng: RandomNumberGenerator, cats_mat: Array = []) -> String:
	return _tirer_materiau(sim, _candidats_famille(sim, fam, cats_mat), profondeur, rng)


## Les matériaux qu'une famille propose vraiment (par id, par liste, par catégorie ou par tag).
static func _candidats_famille(sim: Simulation, fam: Dictionary, cats_mat: Array = []) -> Array[String]:
	var cle := str(fam.get("material", fam.get("materials", fam.get("category", fam.get("tag", ""))))) + "|" + ",".join(PackedStringArray(cats_mat))
	if sim._cache_familles.has(cle):
		return sim._cache_familles[cle]
	var candidats: Array[String] = []
	if fam.has("material"):
		candidats.append(str(fam.material))
	elif fam.has("materials"):
		for m in fam.materials:
			candidats.append(str(m))
	else:
		for m in GameData.catalogues.materials.keys():
			var d: Dictionary = GameData.catalogues.materials[m]
			if fam.has("category") and str(d.get("category", "")) == str(fam.category):
				candidats.append(str(m))
			elif fam.has("tag") and str(fam.tag) in d.get("tags", []):
				candidats.append(str(m))
	candidats = candidats.filter(func(m: String) -> bool: return GameData.catalogues.materials.has(m))
	if not cats_mat.is_empty():   # une boutique demande une catégorie (métal chez le forgeron) : cette famille doit la fournir
		candidats = candidats.filter(func(m: String) -> bool: return str(GameData.catalogues.materials[m].get("category", "")) in cats_mat)
	sim._cache_familles[cle] = candidats
	return candidats


## Le tirage dans un pool de matériaux : les minerais des étages ≤ profondeur pèsent plus, ceux d'un tier
## trop profond ne sortent pas.
## Les matieres qu'on n'attend PAS pour ce composant : tout le reste du catalogue. Elles peuvent
## sortir, mais avec un poids qui tient compte de l'ecart — une matiere qui ne tient meme pas la forme
## du composant (un liquide pour une lame, une poudre pour une plaque) est penalisee une seconde fois.
static func _hors_attente(sim: Simulation, attendues: Array[String], slot: String) -> Dictionary:
	# Le résultat ne dépend que du slot et des matières attendues : on le garde. Le recalculer parcourait
	# les deux cent trente fiches du catalogue à CHAQUE composant de CHAQUE objet généré — quarante-cinq
	# millisecondes de plus par étage de donjon, mesurées au budget de génération (2026-09-02).
	var cle_h := slot + "|" + str(attendues.size()) + "|" + (str(attendues[0]) if not attendues.is_empty() else "")
	if sim._cache_hors_attente.has(cle_h):
		return sim._cache_hors_attente[cle_h]
	var ea: Dictionary = GameData.config("loot_rules").get("assemblage", {}).get("ecart_attendu", {})
	var base := float(ea.get("poids_hors_attente", 0.04))
	if base <= 0.0:
		return {}
	var maitresse := slot in ["tete", "plaque", "monture", "lame", "pointe"]
	var seuil := float(ea.get("durete_min_piece_maitresse", 4))
	# L'ECHELLE DE FREQUENCE, categorie par categorie (designer 2026-09-03 : « un manche, le plus
	# frequent c'est qu'il soit en bois, un peu moins en metal, et le plus absurde c'est en eau »).
	# Avant, un seul poids valait pour TOUT l'inattendu : un manche en metal et un manche en eau de mer
	# sortaient aussi souvent l'un que l'autre, alors que l'un est inhabituel et l'autre une curiosite
	# de foire. Le slot est la bonne maille — un manche est un manche, sur une hache comme sur une
	# torche — et c'est l'exemple meme du designer.
	var echelles: Dictionary = ea.get("echelle_frequence", {})
	var echelle: Dictionary = echelles.get(slot, echelles.get("_defaut", {}))
	var res := {}
	for mid in GameData.catalogues.materials.keys():
		if str(mid) in attendues:
			continue
		var m: Dictionary = GameData.catalogues.materials[mid]
		# Du plus PRECIS au plus general : « animal/peau » l'emporte sur « animal ». Une peau fait des
		# sangles evidentes, un tendon une fixation evidente, un boyau une corde acceptable, un organe
		# non — et la maille categorie les mettait tous au meme rang (designer 2026-09-03 : « developpe
		# encore plus ce systeme avec les sous categories pour qu'on ait aucune lacune »).
		var cat := str(m.get("category", ""))
		var sous := str(m.get("sous_categorie", ""))
		var f_ech := 1.0
		if not sous.is_empty() and echelle.has(cat + "/" + sous):
			f_ech = float(echelle[cat + "/" + sous])
		else:
			f_ech = float(echelle.get(cat, 1.0))
		var poids := base * f_ech
		# Une piece maitresse faite d'une matiere sans tenue : possible, mais c'est la curiosite meme.
		if maitresse and float(m.get("stats", {}).get("durete", 0)) < seuil:
			poids *= float(ea.get("penalite_forme", 0.15))
		res[str(mid)] = poids
	sim._cache_hors_attente[cle_h] = res
	return res


static func _tirer_materiau(sim: Simulation, candidats: Array[String], profondeur: int, rng: RandomNumberGenerator, hors: Dictionary = {}, slot: String = "") -> String:
	if candidats.is_empty():
		return ""
	# Le PALIER du matériau décide, pas la liste des minerais (designer 2026-09-02) : les bandes de
	# `minerais_par_etage` ne couvraient que les minerais, et un drap de soie ou un os massif tombait
	# dès le premier étage. Chaque fiche porte maintenant son palier, et chaque palier sa profondeur
	# minimale — lue sur le NIVEAU DU DONJON, puisque c'est lui qui commande la rareté.
	var la: Dictionary = GameData.config("loot_rules").get("assemblage", {})
	var pm: Dictionary = sim.regles.r.get("paliers_materiaux", {})
	# Trois sorts pour un candidat, selon la place de son palier par rapport au niveau du donjon :
	#   - à sa portée (profondeur_min ≤ niveau) : poids plein, c'est le butin normal du donjon ;
	#   - un cran au-dessus, dans la tolérance : poids RÉDUIT — la trouvaille chanceuse, pas l'ordinaire.
	#     Sans ce poids réduit, un palier trop haut noyait le butin dès qu'il comptait plus de matières
	#     que le palier légitime : un donjon de niveau 1 rendait 46 % de matériaux de palier 2 ;
	#   - hors tolérance : écarté, on ne trouve pas de titane dans un donjon de niveau 2.
	var au_dela := int(la.get("paliers_au_dela", 3))
	var poids_chance := float(la.get("poids_au_dela", 0.15))
	var niv := maxi(1, profondeur)
	# Le pondéré se garde en cache par (candidats, niveau) : il ne dépend que d'eux, et le tirage est
	# appelé une fois par composant de chaque objet généré — des milliers de fois pour un étage de
	# donjon. Le recalculer à chaque coup faisait payer la taille du catalogue à chaque objet, et le
	# catalogue vient de passer de 166 à 197 matières (2026-09-02).
	# Le SLOT entre dans la cle depuis que l'echelle de frequence depend de lui (2026-09-03) : deux
	# emplacements qui puisent dans le meme pool — une tete et une plaque, toutes deux limitees aux
	# matieres dures — ont desormais des poids DIFFERENTS pour l'inattendu. Sans le slot ici, le second
	# aurait recupere les poids du premier, et l'echelle n'aurait servi qu'a moitie, en silence.
	var cle_poids := slot + ":" + str(candidats.size()) + ":" + str(niv) + ":" + str(hors.size()) + ":" + str(candidats[0]) + str(candidats[candidats.size() - 1])
	if sim._cache_poids_paliers.has(cle_poids):
		return _tirer_pondere_cache(sim, sim._cache_poids_paliers[cle_poids], rng)
	var poids := {}
	for m in hors.keys():   # tout le catalogue, au poids de l'ecart
		var pal_h := str(int(GameData.catalogues.materials.get(m, {}).get("palier", 1)))
		if int(pm.get(pal_h, {}).get("profondeur_min", 0)) <= niv:
			poids[m] = float(hors[m])
	for m in candidats:
		var pal := str(int(GameData.catalogues.materials.get(m, {}).get("palier", 1)))
		var mini := int(pm.get(pal, {}).get("profondeur_min", 0))
		if mini <= niv:
			poids[m] = 1.0
		elif mini <= niv + au_dela:
			poids[m] = poids_chance
	if poids.is_empty():   # aucun candidat à portée : on ne rend pas la main vide
		for m in candidats:
			poids[m] = 1.0
	sim._cache_poids_paliers[cle_poids] = poids
	return _tirer_pondere_cache(sim, poids, rng)


static func _tirer_pondere_cache(sim: Simulation, poids: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for m in poids.keys():
		total += float(poids[m])
	var t := rng.randf() * total
	for m in poids.keys():
		t -= float(poids[m])
		if t < 0.0:
			return str(m)
	return str(poids.keys()[poids.size() - 1])


## Ce que les composants font à l'objet (Stats et qualité de l'assemblage) : stats = Σ stat × poids, durete_base avant
## qualité, qualité = Σ q × poids × jet, Wu Xing composite, matériau de la tête, vitesse du manche. Partagé par
## l'atelier (_assembler) et le loot (_composer_loot).
static func _appliquer_composition(sim: Simulation, inst: Dictionary, def: Dictionary, pieces: Array[Dictionary], jet: float) -> void:
	var poids: Dictionary = sim.regles.r.craft.poids.get(str(def.get("type", "arme")), sim.regles.r.craft.poids.arme)   # une part par type
	# La table des parts ne connaît que les armes, armures, boucliers et bijoux. Un objet dont les slots
	# s'appellent autrement — la torche est un « outil » fait d'un manche et de sangles — tombait sur la
	# table des armes, où « sangles » ne figure pas : sa part valait zéro, et la qualité de l'objet ne
	# devait presque rien à ses composants (une torche de pièces à 0,9 sortait « misérable 0,25 »).
	# Les slots inconnus se partagent donc ce qui reste, et le total est ramené à 1.
	var parts := {}
	var connus := 0.0
	var inconnus := 0
	for c0 in pieces:
		if poids.has(c0.slot):
			connus += float(poids[c0.slot])
		else:
			inconnus += 1
	var chacun := maxf(0.0, 1.0 - connus) / float(maxi(1, inconnus))
	var somme_parts := 0.0
	for c0 in pieces:
		var pw: float = float(poids[c0.slot]) if poids.has(c0.slot) else chacun
		parts[c0.slot] = pw
		somme_parts += pw
	if somme_parts > 0.0:
		for k0 in parts.keys():
			parts[k0] = float(parts[k0]) / somme_parts
	var stats := {}
	var elements := {}
	var q_somme := 0.0
	var composants := {}
	var tete: Dictionary = {}
	var manche: Dictionary = {}
	# Le palier du matériau multiplie ce qu'il apporte (designer 2026-09-02 : « plus différencier les
	# stats des équipements qui en découlent »). Sans lui, une épée de fin de partie ne valait que
	# l'écart de dureté écrit dans les fiches — trop peu pour qu'on sente qu'on a changé d'époque.
	var pmat: Dictionary = sim.regles.r.get("paliers_materiaux", {})
	for c in pieces:
		var w := float(parts.get(c.slot, 0.0))
		var mult_pal := float(pmat.get(str(int(GameData.catalogues.materials.get(str(c.materiau), {}).get("palier", 1))), {}).get("mult_stats", 1.0))
		for s in c.stats.keys():
			stats[s] = float(stats.get(s, 0.0)) + float(c.stats[s]) * w * mult_pal
		for el in c.elements.keys():
			elements[el] = float(elements.get(el, 0.0)) + float(c.elements[el]) * w
		q_somme += float(c.qualite) * w
		composants[c.slot] = {"composant": c.composant, "materiau": c.materiau, "qualite": c.qualite, "hors_attente": bool(c.get("hors_attente", false))}
		if c.slot in ["tete", "plaque", "monture"]:   # la pièce maîtresse donne son matériau et son nom
			tete = c
		elif c.slot == "manche":
			manche = c
	inst.stats = stats
	inst.durete_base = roundi(float(stats.get("durete", 0.0)))   # la moyenne pondérée AVANT qualité
	inst.qualite = snappedf(q_somme * jet, 0.01)
	inst.elements = elements
	inst.element = sim.wuxing.dominante(elements)
	# La pièce maîtresse donne son matériau à l'objet ; sans tête, plaque ni monture, c'est la pièce qui
	# pèse le plus — sinon le nom s'arrêtait au milieu, sur « Torche en  ».
	if tete.is_empty():
		# Sans tête, plaque ni monture : la PREMIÈRE pièce déclarée par l'objet. C'est celle que l'auteur
		# de la fiche a mise en tête parce qu'elle définit l'objet — une torche est d'abord un manche, pas
		# des sangles, même si les sangles pèsent plus dans la table des parts.
		for slot_def in def.get("slots", {}).keys():
			for c1 in pieces:
				if str(c1.slot) == str(slot_def):
					tete = c1
					break
			if not tete.is_empty():
				break
	inst.materiau = str(tete.get("materiau", ""))
	inst.composants = composants
	if not manche.is_empty():
		var v: Dictionary = sim.regles.r.craft.vitesse
		inst.vitesse_facteur = snappedf(1.0 + (float(manche.stats.get("densite", v.densite_reference)) - float(v.densite_reference)) * float(v.par_point), 0.01)
	# LA TROISIEME PIECE DIT CE QU'EST L'OBJET (designer 2026-09-03, option C). Chacune a un effet
	# MECANIQUE propre — sans quoi ce serait l'ancienne fixation repeinte, la piece que quarante objets
	# sur quarante-trois portaient sans qu'elle ne differencie jamais rien.
	var tr: Dictionary = sim.regles.r.craft.get("troisieme_piece", {})
	for c3 in pieces:
		match str(c3.slot):
			"contrepoids":
				# L'EQUILIBRE : le contrepoids compense la densite du manche. Une masse a manche de plomb
				# reste maniable si son contrepoids est bien mis — c'est le geste meme du forgeron.
				var comp := float(c3.stats.get("densite", 0.0)) * float(tr.get("contrepoids_par_densite", 0.004))
				inst.vitesse_facteur = snappedf(maxf(float(tr.get("vitesse_facteur_min", 0.6)), float(inst.get("vitesse_facteur", 1.0)) - comp), 0.01)
			"garde":
				# LA PARADE : la durete de la garde protege la main qui tient. Elle s'ajoute a l'armure
				# de celui qui porte l'arme, comme une piece d'armure minuscule et toujours au bon endroit.
				inst["garde_armure"] = snappedf(float(c3.stats.get("durete", 0.0)) * float(tr.get("garde_par_durete", 0.05)), 0.01)
			"corde":
				# LA PUISSANCE DU TIR : c'est ce qui se TEND qui arme le trait, pas le fut. On retient
				# donc l'elasticite de la corde seule, la ou la formule prenait la moyenne de tout
				# l'objet — une corde de soie d'araignee noyee dans un fut de chene.
				inst["elasticite_corde"] = float(c3.stats.get("elasticite", 0.0))
			"doublure":
				# L'ISOLATION : une doublure de fourrure tient chaud, une doublure de lin non.
				inst["doublure_isolation"] = float(c3.stats.get("isolation", 0.0))
	if def.type == "armure":
		inst.durete_composite = inst.durete_base
		inst.niveau_construction = 0


## Un PNJ civil : son camp, son nom (culture du village ou de sa race), sa bourse (fonction), son stock.
## Les loci visuels d'un être : le bloc `apparence` de sa race, dont les traits du visage varient
## au tirage (Apparence — données et équipement). Aucune branche par race : tout vient des données.
static func _apparence_pour(sim: Simulation, race_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var cfg: Dictionary = GameData.config("apparence")
	var ap: Dictionary = GameData.catalogues.races.get(race_id, {}).get("apparence", {}).duplicate()   # une race inconnue (invoqués, échos) : pas d'erreur, pas de visage imposé
	for locus in cfg.get("loci", []):
		var vals: Array = locus.get("valeurs", [])
		if vals.is_empty():
			continue
		if str(locus.id) in ["tete", "carrure"] and ap.has(str(locus.id)):
			continue   # la forme du crâne et la carrure appartiennent à la race
		ap[str(locus.id)] = str(vals[rng.randi() % vals.size()])
	var cheveux: Array = cfg.get("teintes_cheveux", [])
	if not cheveux.is_empty() and rng.randf() < 0.6:
		ap["teinte_cheveux"] = str(cheveux[rng.randi() % cheveux.size()].id)
	return ap


static func _habiller_pnj(sim: Simulation, e: Dictionary, def: Dictionary, culture_id: String = "") -> void:
	e.camp = "civil"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "pnj", e.id])
	var cultures: Dictionary = GameData.catalogues.name_cultures
	if culture_id.is_empty():
		culture_id = str(def.get("social", {}).get("culture", ""))
	if culture_id.is_empty() or not cultures.has(culture_id):
		culture_id = Noms.culture_pour(str(def.get("race", "humain")), cultures, rng)
	var genre := str(def.get("genre", "m" if rng.randf() < 0.5 else "f"))
	e["nom"] = Noms.generer(culture_id, cultures.get(culture_id, {}), genre, rng)
	e["genre"] = genre
	e["apparence"] = _apparence_pour(sim, str(e.get("race", def.get("race", "humain"))), rng)   # loci visuels : le défaut de la race, varié par tirage
	e["name_key"] = "pnj.%s.name" % e.id
	GameData.enregistrer_nom(e.name_key, Noms.afficher(e.nom))
	e["fonction"] = str(def.get("fonction", "oisif"))
	e["role"] = str(def.get("role", "resident"))
	if str(e.get("classe", "")).is_empty():   # une classe tirée parmi celles de sa fonction (Les trois axes)
		# Les classes cachées ignorent le pool : tirées AVANT lui, rares, sur n'importe quelle fonction (Fonctions, 2026-09-04)
		var cachees: Array = []
		for cid in GameData.catalogues.classes.keys():
			if bool(GameData.catalogues.classes[cid].get("cachee", false)):
				cachees.append(str(cid))
		var possibles: Array = GameData.catalogues.functions.get(e.fonction, {}).get("classes_possibles", [])
		if not cachees.is_empty() and rng.randf() < float(sim.regles.r.get("pnj", {}).get("classe_cachee_chance", 0.0)):
			e.classe = str(cachees[rng.randi() % cachees.size()])
		elif not possibles.is_empty():
			e.classe = str(possibles[rng.randi() % possibles.size()])
	e["social"] = {"culture": culture_id, "relations": {}}
	var f: Dictionary = GameData.catalogues.functions.get(e.fonction, {})
	e["or_max"] = int(float(f.get("portefeuille", 30)) * (1.0 + float(e.get("rang", 0)) * 0.5))
	e.or = e.or_max
	e["stock"] = []
	_garnir_stock(sim, e, def.get("stock_marchand", []))
	e["dernieres_repliques"] = []
	e["dernier_parler_jour"] = -1
	e["family"] = {"parent_of": [], "child_of": [], "spouse": ""}
	var ag: Dictionary = sim.regles.r.age
	e["age"] = float(rng.randi_range(int(ag.depart[0]), int(ag.depart[1])))
	var esp := float(ag.esperance.get(str(def.get("race", "humain")), ag.esperance._defaut))
	e["lifespan"] = esp * rng.randf_range(1.0 - float(ag.variance), 1.0 + float(ag.variance))
	# Son signe suit son année de naissance (Âge des PNJ : « dérivé gratuitement ») et son anniversaire son identifiant (Calendrier).
	if e.get("signe", {}).is_empty() and sim.horloge_monde != null:
		e["signe"] = sim.progression.signe(SimVilles.annee_courante(sim) - int(e.age))
	e["anniversaire"] = Calendrier.anniversaire(str(e.id))
	SimPnj._distinguer_pnj(sim, e, rng)   # ses traits, son souhait, son histoire, son âge qui se voit (PNJ — traits, histoires et souhaits)


## Donne un objet à un être (dans son sac).
static func donner(sim: Simulation, e: Dictionary, uid: String) -> void:
	if sim.items.has(uid) and not (uid in e.sac):
		var it: Dictionary = sim.items[uid]
		if "empilable" in it.get("tags", []) and it.get("type", "") == "consommable":
			var pile: Dictionary = SimTerrain._pile_objet(sim, e, str(it.get("base", "")))
			if not pile.is_empty() and float(pile.get("puissance", 1.0)) != float(it.get("puissance", 1.0)):
				pile = {}   # une pile ne mêle pas deux puissances (viande d'ours, viande de renard)
			if not pile.is_empty() and pile.get("potentiel", {}) != it.get("potentiel", {}):
				pile = {}
			if not pile.is_empty():
				pile.quantite = int(pile.quantite) + int(it.get("quantite", 1))
				sim.items.erase(uid)
				EventBus.emettre(&"journal", [&"journal.loot", {"nom": e.name_key, "objet": nom_objet(sim, pile.uid)}])
				return
		e.sac.append(uid)
		EventBus.emettre(&"journal", [&"journal.loot", {"nom": e.name_key, "objet": nom_objet(sim, uid)}])
		if e.controle == "joueur" and sim.lieu == "camp":
			SimRoyaumes._infraction(sim, e, "objet", str(it.get("base", "")), e.pos, uid)


## Le nom affichable d'un objet : {"base": name_key, "affixe": id ou "", "params": {}} — le client formate.
## La fiche de créature d'une entité (drops pondérés par race — Créatures).
static func def_stats_c(sim: Simulation, cible: Dictionary) -> Dictionary:
	return GameData.catalogues.creatures.get(str(cible.def), {})


static func nom_objet(sim: Simulation, uid: String) -> Dictionary:
	var it: Dictionary = sim.items.get(uid, {})
	var nom: Dictionary = it.get("nom", {})
	if inconnu(sim, it):   # non identifié (designer 2026-09-01, point 52) : une apparence, pas un nom
		return {"base": "objet.inconnu.%s" % str(it.get("type", "objet")), "affixe": "", "params": {"apparence": apparence_inconnue(sim, it)}, "rarete": "commun", "inconnu": true}
	var res := {"base": it.get("name_key", uid), "affixe": nom.get("affixe", ""), "params": nom.get("params", {}), "rarete": it.get("rarete", "commun")}
	if nom.has("parchemin"):   # « Parchemin de Flamme (2 charges) » — le sort qu'il porte et ce qui reste
		res["parchemin"] = {"module": str(nom.parchemin.module), "charges": int(it.get("charges", nom.parchemin.get("charges", 1)))}
	if nom.has("de_creature"):   # « Statue de loup » : le nom porte la créature dont l'objet est tiré
		res["de_creature"] = str(nom.de_creature)
	if it.has("grille") and not str(it.grille).is_empty():   # une trame dit sa grille, pas un domaine (vu « Pattern — {grille} », 2026-09-04)
		res.params = res.params.duplicate()
		res.params["grille"] = str(GameData.catalogues.grilles.get(str(it.grille), {}).get("name_key", str(it.grille)))
	elif it.get("type", "") in ["grimoire", "manuel"] and it.has("modules"):   # un livre dit son domaine et sa difficulté
		res["livre"] = {"domaine": str(it.get("domaine", "")), "difficulte": int(it.get("difficulte", 0)), "n": it.modules.size()}
		if nom.has("module"):   # un livre de module : le module au nom
			res["module_livre"] = str(nom.module)
	if it.get("type", "") == "materiau" and not str(it.get("espece", "")).is_empty():
		res["espece"] = GameData.catalogues.creatures.get(str(it.espece), {}).get("name_key", "")
	if it.get("type", "") == "composant" or it.has("composants"):   # craft : l'objet se décrit par son matériau
		res["materiau"] = GameData.catalogues.materials.get(str(it.get("materiau", "")), {}).get("name_key", "")
		var esp_o := str(it.get("espece", ""))
		if esp_o.is_empty():   # un objet assemblé porte l'espèce du premier composant qui en a une (point 69)
			for sc in it.get("composants", {}).keys():
				if not str(it.composants[sc].get("espece", "")).is_empty():
					esp_o = str(it.composants[sc].espece)
					break
		if not esp_o.is_empty():
			res["espece"] = GameData.catalogues.creatures.get(esp_o, {}).get("name_key", "")
		res["construction"] = str(it.get("construction", ""))
		res["qualite"] = float(it.get("qualite", 1.0))
	return res


## Le Wu Xing d'un objet (designer 2026-09-01, point 65) : son vecteur propre s'il en a un, sinon
## celui de la MATIÈRE dont il est fait — un objet assemblé agrège les matériaux de ses composants.
## Tout objet a donc un élément à montrer, et l'inventaire n'a plus de case vide.
static func vecteur_objet(sim: Simulation, it: Dictionary) -> Dictionary:
	if it.get("elements") is Dictionary and not Dictionary(it.elements).is_empty():
		return it.elements
	var table: Dictionary = GameData.config("wuxing").get("materiaux_par_categorie", {})
	var v := {}
	var matieres: Array = []
	if not str(it.get("materiau", "")).is_empty():
		matieres.append(str(it.materiau))
	for comp in it.get("composants", []):
		var m := str(comp.get("materiau", "")) if comp is Dictionary else ""
		if not m.is_empty():
			matieres.append(m)
	for m in matieres:
		var cat := str(GameData.catalogues.materials.get(m, {}).get("category", ""))
		var el := str(table.get(cat, ""))
		if el.is_empty():
			continue
		v[el] = float(v.get(el, 0.0)) + 1.0
	var total := 0.0
	for k in v.keys():
		total += float(v[k])
	if total <= 0.0:
		return {}
	for k in v.keys():
		v[k] = float(v[k]) / total
	return v


## Un objet est-il encore inconnu ? (Loot — identification, designer 2026-09-01, point 52)
## Les consommables et les gemmes sortent anonymes ; essayer l'un d'eux révèle sa base pour toute la partie.
static func inconnu(sim: Simulation, it: Dictionary) -> bool:
	var ident: Dictionary = GameData.config("loot_rules").get("identification", {})
	if not (str(it.get("type", "")) in ident.get("types", [])):
		return false
	return not sim.identifies.has(str(it.get("base", it.get("id", ""))))


## L'apparence d'un objet inconnu : une couleur, un aspect — stable pour toute la partie et par base,
## de sorte que deux fioles de la même potion se ressemblent avant d'être bues.
static func apparence_inconnue(sim: Simulation, it: Dictionary) -> String:
	var apparences: Array = GameData.config("loot_rules").get("identification", {}).get("apparences", [])
	if apparences.is_empty():
		return ""
	return str(apparences[absi(hash([sim.graine, str(it.get("base", it.get("id", "")))])) % apparences.size()])


## Révèle la base d'un objet : toutes ses copies prennent leur vrai nom (Rogue : une potion bue les nomme toutes).
static func identifier(sim: Simulation, it: Dictionary) -> void:
	var base := str(it.get("base", it.get("id", "")))
	if base.is_empty() or sim.identifies.has(base):
		return
	sim.identifies[base] = true
	EventBus.emettre(&"journal", [&"journal.identifie", {"objet": str(it.get("name_key", base))}])


## Équiper un objet du sac : le slot de l'objet (anneau : premier libre des deux) ; l'ancien va au sac.
static func _equiper(sim: Simulation, e: Dictionary, uid: String, tick: int) -> bool:
	if not (uid in e.sac) or not sim.items.has(uid):
		return false
	var it: Dictionary = sim.items[uid]
	var slot := str(it.get("equip_slot", ""))
	if slot.is_empty():
		return false
	if str(e.corps.get("silhouette", "humanoide")) != "humanoide" and not (slot in sim.regles.r.talents.incarnation.slots_bete):   # pas de mains (Changer de personnage)
		EventBus.emettre(&"journal", [&"journal.pas_de_mains", {}])
		return false
	if SimTalents.a_talent(sim, e, "sans_chair") and slot in sim.regles.r.talents.sans_chair.slots_refuses:   # le Spectre ne porte aucune armure
		EventBus.emettre(&"journal", [&"journal.armure_refusee", {}])
		return false
	if slot == "anneau":
		slot = "anneau_1" if not e.equipement.has("anneau_1") else ("anneau_2" if not e.equipement.has("anneau_2") else "anneau_1")
	if slot == "main_secondaire":
		var principale: Dictionary = sim.items.get(e.equipement.get("main_principale", ""), {})
		if int(principale.get("hands", 1)) > 1:
			return false
	e.sac.erase(uid)
	if e.equipement.has(slot):
		e.sac.append(e.equipement[slot])
	e.equipement[slot] = uid
	if slot == "main_principale" and int(it.get("hands", 1)) > 1 and e.equipement.has("main_secondaire"):
		e.sac.append(e.equipement.main_secondaire)
		e.equipement.erase("main_secondaire")
	if not (uid in e.ratelier) and it.get("type", "") in ["arme", "bouclier"]:
		e.ratelier.append(uid)
	Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
	sim._quitter_garde(e)
	e.compteur = tick + int(sim.regles.r.actions.objet if it.get("type", "") != "arme" else sim.regles.r.actions.changer_arme)
	EventBus.emettre(&"journal", [&"journal.equipe", {"nom": e.name_key, "objet": nom_objet(sim, uid)}])
	return true


## Retirer une pièce : elle retourne au sac (utiliser un objet : le coût de `actions.objet`).
static func _desequiper(sim: Simulation, e: Dictionary, slot: String, tick: int) -> bool:
	if not e.equipement.has(slot):
		return false
	var uid: String = e.equipement[slot]
	e.equipement.erase(slot)
	e.sac.append(uid)
	Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
	sim._quitter_garde(e)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.desequipe", {"nom": e.name_key, "objet": nom_objet(sim, uid)}])
	return true


## Jeter un objet du sac : il tombe en butin sur la tuile (ramassable, R).
static func _jeter(sim: Simulation, e: Dictionary, uid: String, tick: int) -> bool:
	if not (uid in e.sac) or not sim.items.has(uid):
		return false
	e.sac.erase(uid)
	e.ratelier.erase(uid)
	var nom_jete := nom_objet(sim, uid)   # avant : s'il coule, l'objet n'existe plus quand le journal parle
	SimTerrain._poser_ou_couler(sim, e.pos, [uid], "butin")
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.jette", {"nom": e.name_key, "objet": nom_jete}])
	return true


static func _rendre_rare(sim: Simulation, e: Dictionary, rng: RandomNumberGenerator) -> void:
	var mr: Dictionary = GameData.config("loot_rules").monstres_rares
	e.rare = true
	for k in e.corps.stats.keys():
		e.corps.stats[k] = roundi(float(e.corps.stats[k]) * float(mr.mult_stats))
	e.teinte = mr.teinte.duplicate()
	var pool: Array = GameData.config("rare_epithets").get("or", [])
	e.epithete = str(pool[rng.randi_range(0, pool.size() - 1)]) if not pool.is_empty() else ""
	Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
	e.sante = e.sante_max
	EventBus.emettre(&"journal", [&"journal.rare", {"nom": e.name_key, "epithete": e.epithete}])


## Pose un contenant (coffre, butin) sur une tuile ; s'il y en a déjà un, le contenu s'ajoute.
## Le butin de mort périme (Mort et pénalité : « récupérable pendant 1 jour ») : les objets marqués
## d'un peremption_tick dépassé quittent leur tas ; un tas vidé rend sa tuile. Les coffres ne périment pas.
static func _perimer_butin(sim: Simulation, tick: int) -> void:
	for gi in sim.contenants.keys().duplicate():
		var restants: Array = []
		var retire := false
		for uid in sim.contenants[gi]:
			var o: Dictionary = sim.objets.get(str(uid), {})
			if o.has("peremption_tick") and int(o.peremption_tick) <= tick:
				retire = true
			else:
				restants.append(uid)
		if not retire:
			continue
		if restants.is_empty():
			sim.contenants.erase(gi)
			sim.grille.contenu[int(gi)] = 0
			EventBus.emettre(&"tile_changed", [sim.grille.pos_de(int(gi))])
		else:
			sim.contenants[gi] = restants


static func _poser_contenant(sim: Simulation, pos: Vector2i, uids: Array, type: String) -> void:
	if uids.is_empty() or not sim.grille.dans(pos):   # hors grille : rien à poser (un être hors grille est une erreur du test qui l'a mis là)
		return
	var idx := sim.grille.idx(pos)
	if sim.contenants.has(idx):
		sim.contenants[idx].append_array(uids)
	else:
		sim.contenants[idx] = uids.duplicate()
		sim.grille.poser_contenu(pos, type)
	EventBus.emettre(&"tile_changed", [pos])


## Ramasser : tout ce qui est sur sa tuile va au sac (utiliser un objet : 5 ticks).
static func _ramasser(sim: Simulation, e: Dictionary, tick: int) -> bool:
	var idx := sim.grille.idx(e.pos)
	if not sim.contenants.has(idx):
		return false
	for uid in sim.contenants[idx]:
		donner(sim, e, str(uid))
		if not sim.expedition.is_empty() and e.controle == "joueur":
			sim.expedition.objets = int(sim.expedition.objets) + 1
	sim.contenants.erase(idx)
	sim.grille.contenu[idx] = 0
	EventBus.emettre(&"tile_changed", [e.pos])
	e.compteur = tick + int(sim.regles.r.actions.objet)
	return true


## Mort et pénalité : respawn au point d'entrée, 10 % de chance par objet du sac de tomber sur le
## lieu de mort, équipement conservé, aucune perte d'XP. Le respawn est une intention du client.
static func _respawn(sim: Simulation, e: Dictionary) -> bool:
	if e.vivant or e.controle != "joueur":
		return false
	# Mort et pénalité (designer 2026-09-02) : UN SEUL jet de dé décide de la part du sac qui tombe.
	# Un tirage par objet donnait toujours à peu près la même perte sur un gros sac ; ici on peut
	# tout perdre, la moitié, ou rien — et les objets emportés sont ensuite tirés au hasard.
	var faces: Array = sim.regles.r.mort.get("perte_sac_faces", [0.0, 0.25, 0.5, 0.75, 1.0])
	var part := 0.0
	if not faces.is_empty():
		part = float(faces[sim.des.entier(0, faces.size() - 1)])
	var restants: Array = e.sac.duplicate()
	var combien := int(round(float(restants.size()) * part))
	var perdus: Array = []
	while perdus.size() < combien and not restants.is_empty():
		var uid: Variant = restants.pop_at(sim.des.entier(0, restants.size() - 1))
		e.sac.erase(uid)
		perdus.append(uid)
	_poser_contenant(sim, e.pos, perdus, "butin")
	if sim.horloge_monde != null:   # Mort et pénalité : récupérable pendant 1 jour in-game, puis poussière
		for uid_p in perdus:
			if sim.objets.has(str(uid_p)):   # le sac peut porter des ids de catalogue (râtelier du prototype) sans instance : eux ne périment pas
				sim.objets[str(uid_p)]["peremption_tick"] = sim.horloge_monde.ticks + int(sim.regles.r.mort.get("peremption_jours", 1)) * int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
	var or_perdu := int(floor(float(e.get("or", 0)) * float(sim.regles.r.mort.get("perte_or", 0.0))))   # Mort et pénalité : −10 % de l'or porté
	if or_perdu > 0:
		e.or = int(e.or) - or_perdu
		EventBus.emettre(&"journal", [&"journal.mort_or", {"nom": e.name_key, "or": or_perdu}])
	if sim.en_combat(e):
		sim._quitter_combat(e)
	e.vivant = true
	e.sante = e.sante_max
	e.vigueur = e.vigueur_max
	e.statuts = []
	e.action_en_cours = {}
	if sim.monde != null and sim.lieu != "arene" and not SimTalents.a_talent(sim, e, "sans_chair") and sim.monde.corruption_de(SimCamp._cell_de(sim, e.pos)) >= float(sim.regles.r.talents.sans_chair.corruption_seuil):
		SimTalents._devenir_spectre(sim, e)   # mort en forte corruption sans Renaissance (Talents de race)
	if sim.lieu == "donjon" and not sim.camp_sauve.is_empty() and e.has("lit"):
		# Mort en expédition : on se relève au dernier lit, au camp (Mort et pénalité) ; l'expédition est finie.
		sim.grille.liberer(e.pos)
		e["mort_en_expedition"] = true
		sim.etages_visites.clear()
		sim.expedition = {}
		SimLieux.charger_camp(sim, e)
		EventBus.emettre(&"journal", [&"journal.respawn", {"nom": e.name_key, "perdus": perdus.size()}])
		return true
	var spawn: Vector2i = e.get("spawn", e.pos)
	if not sim.grille.dans(spawn) or not sim.grille.occupant(spawn).is_empty() or sim.grille.bloque_passage(spawn):   # le spawn d'une autre grille (camp → donjon) ne vaut rien ici
		spawn = e.pos
	e.pos = spawn
	sim.grille.placer(e.id, spawn)
	e.compteur = sim.horloge_monde.ticks
	EventBus.emettre(&"journal", [&"journal.respawn", {"nom": e.name_key, "perdus": perdus.size()}])
	return true


## Sertir une gemme du sac dans un emplacement libre d'un objet porté ou du sac (5 ticks).
static func _sertir(sim: Simulation, e: Dictionary, objet: String, gemme: String, tick: int) -> bool:
	if not (gemme in e.sac) or not sim.items.has(objet) or sim.items.get(gemme, {}).get("type", "") != "gemme":
		return false
	var porte: bool = objet in e.sac or objet in e.equipement.values()
	var it: Dictionary = sim.items[objet]
	if bool(it.get("fini", false)):
		EventBus.emettre(&"journal", [&"journal.objet_fini", {}])
		return false
	if not porte or not it.has("sertissures") or it.sertissures.contenu.size() >= int(it.sertissures.nombre):
		return false
	identifier(sim, sim.items[gemme])   # sertir une gemme révèle son espèce (point 52)
	e.sac.erase(gemme)
	it.sertissures.contenu.append(gemme)
	Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.serti", {"nom": e.name_key, "gemme": nom_objet(sim, gemme), "objet": nom_objet(sim, objet)}])
	return true


## Lire un livre (Lecture des livres) : jet universel, modules appris, échec à effet, livre consommé.
static func _lire(sim: Simulation, e: Dictionary, objet: String, tick: int) -> bool:
	if not (objet in e.sac) or not sim.items.get(objet, {}).get("type", "") in ["grimoire", "manuel"]:
		return false
	if str(e.corps.get("silhouette", "humanoide")) != "humanoide":   # une bête ne lit pas (Changer de personnage)
		EventBus.emettre(&"journal", [&"journal.pas_de_lecture", {}])
		return false
	sim.rompre_serment(e, "silence")   # lire rompt le Silence, définitivement
	var livre: Dictionary = sim.items[objet]
	var lv: Dictionary = GameData.config("loot_rules").livres
	var n_lecture := int(e.competences_eff.get("lecture", 0))
	var jet := sim.des.jet("1d20")
	var total := jet + n_lecture / 2 + int(e.stats_eff.perception) / 4
	var dd := int(lv.dd_base) + int(livre.difficulte) / 2
	var marge := total - dd
	var succes := marge >= 0 and jet != 1
	# Une TRAME (designer 2026-09-04 : « le joueur peut débloquer d'autres grilles ») apprend une grille
	# comme un livre apprend un module. Une grille déjà possédée ne consomme pas la trame : on la garde,
	# on la vendra — une trame est rare, la gâcher sur un doublon serait une punition sans décision.
	if livre.has("grille") and not str(livre.grille).is_empty():
		if str(livre.grille) in e.get("grilles", []):
			EventBus.emettre(&"journal", [&"journal.grille_deja", {"nom": e.name_key, "grille": GameData.catalogues.grilles.get(str(livre.grille), {}).get("name_key", "")}])
			return false
		e.sac.erase(objet)
		if succes:
			SimTalents.apprendre_grille(sim, e, str(livre.grille))
			sim.gagner_xp(e, "lecture", int(livre.difficulte) * int(lv.xp_succes))
		else:
			sim.gagner_xp(e, "lecture", int(livre.difficulte) * int(lv.xp_echec))
			_effet_echec_lecture(sim, e, marge <= -10 or jet == 1, tick)
			EventBus.emettre(&"journal", [&"journal.lecture_echouee", {"nom": e.name_key, "livre": nom_objet(sim, objet), "grave": marge <= -10 or jet == 1}])
		e.compteur = tick + int(sim.regles.r.actions.objet)
		EventBus.emettre(&"book_read", [e.id, objet, succes])
		return true
	e.sac.erase(objet)   # consommé dans tous les cas
	var appris: Array = []
	if succes and livre.has("recette") and not str(livre.recette).is_empty():   # un plan industriel : une recette apprise
		if not e.has("recettes_connues"):
			e["recettes_connues"] = []
		if str(livre.recette) in e.recettes_connues:
			SimTerritoire._doublon_recette(sim, e, str(livre.recette))   # Axe des niveaux de recette : le doublon fait monter le niveau
		else:
			e.recettes_connues.append(str(livre.recette))
			EventBus.emettre(&"journal", [&"journal.plan_appris", {"nom": e.name_key, "recette": GameData.catalogues.recipes[str(livre.recette)].name_key}])
		sim.gagner_xp(e, "lecture", int(livre.difficulte) * int(lv.xp_succes))
		e.compteur = tick + int(sim.regles.r.actions.objet)
		EventBus.emettre(&"book_read", [e.id, objet, true])
		return true
	if succes:
		var n: int = livre.modules.size()
		if marge < 10:
			n = maxi(1, int(floorf(float(livre.modules.size()) * minf(1.0, float(n_lecture) / float(livre.difficulte)))))
		for k in n:
			var m: String = str(livre.modules[k])
			sim.crediter_module(e, m)   # apprendre un module est définitif (designer 2026-08-31)
			appris.append(m)
		e.xp.competence["lecture"] = int(e.xp.competence.get("lecture", 0)) + int(livre.difficulte) * int(lv.xp_succes)
		sim.gagner_xp(e, "lecture", int(livre.difficulte) * int(lv.xp_succes))
		EventBus.emettre(&"journal", [&"journal.lecture_reussie", {"nom": e.name_key, "n": appris.size(), "livre": nom_objet(sim, objet)}])
	else:
		e.xp.competence["lecture"] = int(e.xp.competence.get("lecture", 0)) + int(livre.difficulte) * int(lv.xp_echec)
		sim.gagner_xp(e, "lecture", int(livre.difficulte) * int(lv.xp_echec))
		var grave := marge <= -10 or jet == 1
		_effet_echec_lecture(sim, e, grave, tick)
		EventBus.emettre(&"journal", [&"journal.lecture_echouee", {"nom": e.name_key, "livre": nom_objet(sim, objet), "grave": grave}])
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"book_read", [e.id, objet, succes])
	return true


static func _effet_echec_lecture(sim: Simulation, e: Dictionary, grave: bool, tick: int) -> void:
	var table: Array = GameData.config("reading_failures").get("grave" if grave else "mineur", [])
	if table.is_empty():
		return
	var ef: Dictionary = table[sim.des.entier(0, table.size() - 1)]
	if ef.has("statut"):
		sim.appliquer_statut(e, str(ef.statut), int(ef.get("duree_ticks", 20)), "")
	if ef.has("mana"):
		e.mana = maxi(0, int(e.mana) + int(ef.mana))
	if ef.get("teleportation", false):
		for essai in 50:
			var p := Vector2i(sim.des.entier(0, sim.grille.largeur - 1), sim.des.entier(0, sim.grille.hauteur_grille - 1))
			if not sim.grille.bloque_passage(p) and sim.grille.occupant(p).is_empty():
				sim.grille.liberer(e.pos)
				e.pos = p
				sim.grille.placer(e.id, p)
				break
	if ef.has("invocation"):
		for d in Grille.DIRS:
			var p: Vector2i = e.pos + d
			if sim.grille.dans(p) and not sim.grille.bloque_passage(p) and sim.grille.occupant(p).is_empty():
				ajouter(sim, str(ef.invocation), p, "ia")
				break


## Le niveau qui commande le butin (designer 2026-09-02 : « la rareté du loot ne se fait pas par étage
## mais par niveau du donjon »). Un donjon de corruption vaut son niveau à tous ses étages : descendre
## n'enrichit pas le butin, c'est le donjon qu'on a choisi qui le décide. Le gouffre fait exception, et
## il le doit à sa nature : sans fond, il n'a pas de niveau propre, c'est la descente qui en tient lieu.
static func niveau_loot(sim: Simulation) -> int:
	if sim.donjon.is_empty():
		return 0
	if sim.donjon.has("gouffre"):
		var pg: Dictionary = GameData.config("planete").get("regions", {})
		return maxi(1, roundi(float(sim.donjon.get("etage", 1)) * float(pg.get("gouffre_niveau_par_etage", 1.5))))
	if sim.donjon.has("niveau"):
		return maxi(1, int(sim.donjon.niveau))
	return maxi(1, int(sim.donjon.get("profondeur", sim.donjon.get("etage", 1))))


## Le boss du dernier étage : celui qui garde le fond. Le gouffre n'en a pas — il n'a pas de fond.
static func est_boss_final(sim: Simulation, cible: Dictionary) -> bool:
	if not bool(cible.get("chain_gauge", false)) or sim.lieu != "donjon" or sim.donjon.has("gouffre"):
		return false
	return int(sim.donjon.get("etage", 0)) >= int(sim.donjon.get("etages", 0))


## À la mort : un drop (chance du tout-venant ; garanti et renforcé pour une variante rare).
static func _drop(sim: Simulation, cible: Dictionary, source: String) -> void:
	var lr: Dictionary = GameData.config("loot_rules")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "drop", cible.id])
	# Le NIVEAU du donjon, pas l'étage : deux étages du même donjon donnent le même calibre de butin.
	var profondeur: int = niveau_loot(sim)
	var bf: Dictionary = lr.drops.get("boss_final", {})
	var final := est_boss_final(sim, cible)
	if final:
		profondeur += int(bf.get("bonus_niveau", 0))
	var uids: Array = []
	if cible.get("rare", false):
		var base := str(sim.loot._base_pour(rng, profondeur, true))
		var o := generer_objet(sim, base, profondeur, {"monstre_rare": cible.name_key}, str(lr.drops.rare_rarete), int(lr.drops.rare_affixes))
		if not o.is_empty():
			uids.append(o.uid)
	elif cible.controle == "ia" and rng.randf() < float(lr.drops.chance_tout_venant):
		var o := generer_objet(sim, str(sim.loot._base_pour(rng, profondeur)), profondeur, {"creature": cible.name_key})
		if not o.is_empty():
			uids.append(o.uid)
	# Le drop rare universel (Créatures) : la statue 1:1 de la bête abattue, meuble décoratif et trophée.
	if cible.controle == "ia" and lr.drops.has("statue"):
		var st: Dictionary = lr.drops.statue
		var mult := float(def_stats_c(sim, cible).get("statue_mult", 1.0))
		if rng.randf() < float(st.chance) * mult:
			var stat_moy := 0.0
			var stats_s: Dictionary = GameData.catalogues.creatures.get(str(cible.def), {}).get("corps", {}).get("stats", {})
			for v in stats_s.values():
				stat_moy += float(v)
			stat_moy = stat_moy / maxf(1.0, float(stats_s.size()))
			var statue := generer_objet(sim, str(st.item), profondeur, {"creature": cible.name_key}, "commun", 0)
			if not statue.is_empty():
				statue["valeur"] = maxf(1.0, stat_moy * float(st.valeur_par_stat))   # Prix suggéré : ∝ niveau de la créature
				statue["nom"] = {"affixe": "", "params": {}, "de_creature": str(cible.name_key)}
				uids.append(statue.uid)
				EventBus.emettre(&"journal", [&"journal.statue", {"nom": cible.name_key}])
	# Un plan industriel dans les ruines profondes (Palier industriel).
	if cible.controle == "ia" and lr.drops.has("plan") and profondeur >= int(lr.drops.plan.profondeur_min) and rng.randf() < float(lr.drops.plan.chance):
		var plan_i := generer_objet(sim, "plan_industriel", profondeur, {"creature": cible.name_key}, "commun", 0)
		if not plan_i.is_empty():
			uids.append(plan_i.uid)
	# Le boss du DERNIER étage garde le fond : son butin est tiré au-dessus du niveau du donjon (plus
	# haut), et ne descend pas sous une rareté plancher (designer 2026-09-02).
	if final and not bf.is_empty():
		for k_bf in maxi(1, int(bf.get("objets", 1))):
			var ob := generer_objet(sim, str(sim.loot._base_pour(rng, profondeur, true)), profondeur, {"boss": cible.name_key}, str(bf.get("rarete_min", "rare")))
			if not ob.is_empty():
				uids.append(ob.uid)
	# Le boss d'un donjon : un artefact, garanti si le donjon est majeur (Trésors et artefacts).
	if bool(cible.get("chain_gauge", false)) and sim.lieu != "camp" and lr.drops.has("artefact"):
		var majeur := int(sim.donjon.get("etages", 1)) >= int(lr.drops.artefact.etages_majeur)
		if majeur or rng.randf() < float(lr.drops.artefact.chance_boss):
			var art := generer_objet(sim, str(sim.loot._base_pour(rng, profondeur, true)), profondeur, {"boss": cible.name_key}, "artefact")
			if not art.is_empty():
				uids.append(art.uid)
				EventBus.emettre(&"journal", [&"journal.artefact", {"nom": cible.name_key}])
	# La bourse (designer 2026-09-02) : 179 kills ne rapportaient pas une piece — rien ne donnait de monnaie.
	var lo: Dictionary = lr.drops.get("or", {})
	if cible.controle == "ia" and not lo.is_empty() and rng.randf() < float(lo.get("chance", 0.0)):
		var pieces := float(lo.get("base", 3)) + float(cible.get("sante_max", 10)) * float(lo.get("par_pv", 0.25)) + float(profondeur) * float(lo.get("par_etage", 4))
		if bool(cible.get("chain_gauge", false)):   # un boss porte une vraie bourse
			pieces *= float(lo.get("mult_boss", 6))
		pieces *= 1.0 + (rng.randf() * 2.0 - 1.0) * float(lo.get("variance", 0.4))
		var n_or := maxi(1, roundi(pieces))
		var bourse: Dictionary = generer_objet(sim, "or", profondeur, {"creature": cible.name_key}, "commun", 0) if GameData.catalogues.items.has("or") else {}
		if bourse.is_empty():   # pas d'objet « or » au catalogue : on crédite le tueur directement
			var t_or: Dictionary = sim.entites.get(source, {})
			if not t_or.is_empty():
				t_or["or"] = int(t_or.get("or", 0)) + n_or
				EventBus.emettre(&"journal", [&"journal.bourse", {"nom": t_or.name_key, "or": n_or}])
		else:
			bourse["quantite"] = n_or
			uids.append(bourse.uid)
	# La dépouille (Nourriture : la viande crue des animaux, en attendant les viandes paramétriques).
	var def_c: Dictionary = GameData.catalogues.creatures.get(str(cible.def), {})
	var stats_c: Dictionary = def_c.get("corps", {}).get("stats", {})
	var top_stat := ""
	for st in stats_c.keys():
		if top_stat.is_empty() or int(stats_c[st]) > int(stats_c[top_stat]):
			top_stat = str(st)
	var al: Dictionary = sim.regles.r.alchimie
	# Chasseur (designer 2026-09-01, point 71) : chaque pièce passe un jet contre la taille de la bête ;
	# une réussite large en donne plusieurs. Sans compétence, on repart souvent avec la viande seule.
	var ch: Dictionary = sim.regles.r.get("chasse", {})
	var dd_chasse := int(ch.get("dd_base", 8)) + int(cible.get("sante_max", 10)) / maxi(1, int(ch.get("pv_par_point", 12)))
	var tueur: Dictionary = sim.entites.get(source, {})   # celui qui a porté le coup fatal fait le jet
	if tueur.is_empty():
		for x in sim.vivants():   # personne d'identifiable : le joueur, sinon aucun jet ne se ferait
			if x.controle == "joueur":
				tueur = x
				break
	for base in def_c.get("depouille", []):   # ce qui tombe toujours : la viande, le miel
		var v0 := generer_objet(sim, str(base), profondeur, {"creature": cible.name_key}, "commun", 0)
		if not v0.is_empty():
			v0["espece"] = str(cible.def)
			identifier(sim, v0)   # ce qu'on dépèce soi-même n'est pas un mystère (2026-09-02)
			if not top_stat.is_empty():   # viande paramétrique (Cuisine et alchimie) : la stat dominante de la bête
				v0["potentiel"] = {top_stat: 1}
				v0["wuxing"] = def_c.elements.duplicate() if def_c.get("elements") is Dictionary else sim.regles.r.craft.harmonie.viande_defaut.duplicate()
				v0["puissance"] = SimTerritoire._puissance_de(sim, int(stats_c[top_stat]))
				v0["nom"] = {"params": {"creature": cible.name_key}}
			uids.append(v0.uid)
	for base in def_c.get("drops_chasse", []):   # ce qui demande de savoir chasser (point 71)
		var jet_ch := sim.des.jet("1d20") + sim.regles.niveau(tueur.get("competences_eff", tueur.get("competences", {})), str(ch.get("competence", "chasse")))
		sim.gagner_xp(tueur, str(ch.get("competence", "chasse")), int(ch.get("xp_par_jet", 1)))
		if jet_ch < dd_chasse:
			continue
		var n_pieces := 1 + mini(int(ch.get("pieces_max", 3)) - 1, (jet_ch - dd_chasse) / maxi(1, int(ch.get("marge_par_piece", 6))))
		for _p in n_pieces:
			var v := generer_objet(sim, str(base), profondeur, {"creature": cible.name_key}, "commun", 0)
			if v.is_empty():
				continue
			v["espece"] = str(cible.def)   # la matière sait de quelle bête elle vient (point 69)
			identifier(sim, v)   # dépecée de sa main : la peau, le croc et l'écaille sont reconnus
			if not top_stat.is_empty():   # viande paramétrique (Cuisine et alchimie) : la stat dominante de la bête
				v["potentiel"] = {top_stat: 1}
				v["wuxing"] = def_c.elements.duplicate() if def_c.get("elements") is Dictionary else sim.regles.r.craft.harmonie.viande_defaut.duplicate()
				v["puissance"] = SimTerritoire._puissance_de(sim, int(stats_c[top_stat]))
				v["nom"] = {"params": {"creature": cible.name_key}}
			uids.append(v.uid)
	# Une partie de bête pour l'alchimie (Cuisine et alchimie) : œil, peau, griffe, dent ou os.
	if str(sim.regles.r.alchimie.tag_bete) in cible.get("tags", []):
		var parties: Array = sim.regles.r.alchimie.parties.keys()
		parties.sort()
		var rp := RandomNumberGenerator.new()
		rp.seed = hash([sim.graine, "partie", cible.id])
		var pid: String = str(parties[rp.randi() % parties.size()])
		var partie := generer_objet(sim, pid, profondeur, {"creature": cible.name_key}, "commun", 0)
		identifier(sim, partie)
		if not partie.is_empty():
			partie["puissance"] = SimTerritoire._puissance_de(sim, int(stats_c.get(str(al.parties[pid]), 10)))
			partie["nom"] = {"params": {"creature": cible.name_key}}
			uids.append(partie.uid)
		if GameData.catalogues.materials.has(pid):   # la même partie comme matériau brut (l'os des pointes — Catalogue matériaux — Paramétriques)
			var brut := generer_objet(sim, "materiau_brut", profondeur, {"creature": cible.name_key}, "commun", 0)
			if not brut.is_empty():
				var mat_id := pid
				if GameData.catalogues.materials.has(pid + "_massif") and partie.get("puissance", 1.0) >= 2.0:
					mat_id = pid + "_massif"
				brut.materiau = mat_id
				brut["forme"] = "brut"
				brut.quantite = 1
				# « L'os appartient à une créature et donc ses stats en sont dérivés » (designer 2026-09-02,
				# point 73). Le mécanisme existait pour le cuir depuis le 2026-09-01 — mais la MATIÈRE
				# brute, celle qui devient une pointe de lance, sortait sans espèce : un os de lièvre et
				# un os de troll donnaient exactement la même arme. L'espèce est posée ici, et les stats
				# recalculées avec elle — `generer_objet` les avait figées sur le matériau nu.
				brut["espece"] = str(cible.def)
				brut.stats = sim.stats_materiau(GameData.entree("materials", mat_id), str(cible.def))
				brut["nom"] = {"params": {"creature": cible.name_key}}
				uids.append(brut.uid)
	# Ce que le mort portait tombe aussi (l'équipement est une donnée d'instance).
	for slot in cible.equipement.keys():
		var uid: String = str(cible.equipement[slot])
		if sim.objets.has(uid):
			uids.append(uid)
	for uid in cible.sac:
		uids.append(str(uid))
	_poser_contenant(sim, cible.pos, uids, "butin")
