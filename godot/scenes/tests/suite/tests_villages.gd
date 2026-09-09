extends TestsBase
## Les villages et les royaumes : village vivant, réputation, guildes, compagnons, territoire, raids, conquête.
## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de
## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l'ordre de sa liste.


func test_village() -> void:
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	verifier(GameData.catalogues.name_cultures.size() == 51 and GameData.catalogues.dialogue.size() >= 31 and GameData.catalogues.functions.size() >= 6, "51 cultures, au moins 31 répliques (%d), les fonctions" % GameData.catalogues.dialogue.size())
	# Un nom par culture, genré ; la fonction d'affichage unique.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var nord: Dictionary = GameData.catalogues.name_cultures.nordique
	var nf := Noms.generer("nordique", nord, "f", rng)
	verifier(nf.prenom.length() >= 3 and (nf.nom_famille.ends_with("sdottir") or nf.nom_famille.length() >= 4) and Noms.afficher(nf) == nf.prenom + " " + nf.nom_famille, "un nom nordique féminin (%s)" % Noms.afficher(nf))
	var nip: Dictionary = GameData.catalogues.name_cultures.nipponne
	var nm := Noms.generer("nipponne", nip, "m", rng)
	verifier(Noms.afficher(nm) == nm.nom_famille + " " + nm.prenom, "nom puis prénom pour la culture nipponne (%s)" % Noms.afficher(nm))
	# Tout est syllabique (designer 2026-09-07) : un début genré et une fin genrée. On vérifie que chaque culture a de
	# quoi nommer une ville entière sans se répéter, et qu'un début d'homme ne sert jamais à une femme.
	var maigres: Array[String] = []
	var n_combi := 0
	for cid in GameData.catalogues.name_cultures.keys():
		var c: Dictionary = GameData.catalogues.name_cultures[cid]
		var am: Array = c.get("prenom_a_m", c.prenom_a)
		var af: Array = c.get("prenom_a_f", c.prenom_a)
		var h: int = am.size() * (c.prenom_b_m as Array).size()
		var f_c: int = af.size() * (c.prenom_b_f as Array).size()
		var fam: int = (c.famille_a as Array).size() * (c.famille_b_m as Array).size()
		n_combi += h + f_c
		if h < 150 or f_c < 150 or fam < 40:
			maigres.append("%s (%d H, %d F, %d familles)" % [str(cid), h, f_c, fam])
	verifier(maigres.is_empty(), "chaque culture peut nommer sans se répéter (150 H, 150 F, 40 familles au moins) %s" % str(maigres))
	verifier(n_combi >= 20000, "%d prénoms possibles dans le monde" % n_combi)
	# Le tirage suit bien le genre demandé, et les deux genres puisent dans des mondes différents.
	var vus_h := {}
	var vus_f := {}
	for k_n in 200:
		vus_h[Noms.prenom(nord, "m", rng)] = true
		vus_f[Noms.prenom(nord, "f", rng)] = true
	var croises := 0
	for p_h in vus_h.keys():
		if vus_f.has(p_h):
			croises += 1
	# Deux assemblages peuvent tomber sur le même nom (Sig|rid et Sigr|id font tous deux Sigrid) : on tolère l'accident,
	# pas le mélange — au-delà de 2 %, c'est que les désinences des deux genres ne sont plus disjointes.
	verifier(vus_h.size() > 60 and vus_f.size() > 60 and croises <= maxi(1, vus_h.size() / 50), "deux cents tirages nordiques : %d prénoms d'homme, %d de femme, %d en commun" % [vus_h.size(), vus_f.size(), croises])
	# Un nom de famille n'a pas de sexe (designer 2026-09-07) : les deux genres puisent dans le MÊME pool, et le
	# patronyme nordique prend « sson » pour tous, comme la Suède moderne.
	var genres_famille: Array[String] = []
	for cid2 in GameData.catalogues.name_cultures.keys():
		var c2: Dictionary = GameData.catalogues.name_cultures[cid2]
		if (c2.famille_b_m as Array) != (c2.famille_b_f as Array):
			genres_famille.append(str(cid2))
	verifier(genres_famille.is_empty(), "aucune culture ne genre son nom de famille %s" % str(genres_famille))
	var nf2 := Noms.generer("nordique", nord, "f", rng)
	verifier(str(nf2.nom_famille).ends_with("sson"), "une nordique porte le patronyme en sson comme son frère (%s)" % str(nf2.nom_famille))
	# Un hameau quelque part : on cherche une cellule à POI village.
	var cell_v := Vector2i(-1, -1)
	var dep_v: Array = [0, 0]   # on cherche autour du camp réel de cette partie
	# La simulation construit sa Surface avec la graine de `planete` : on cherche le hameau dans CE
	# monde-là, pas dans celui de la surface de test (les deux graines diffèrent).
	var s_v := Simulation.new(4242)
	s_v.planete_options = _planete_test()
	s_v.charger_camp()
	var surf_v: Surface = s_v.monde.surface   # le monde de la simulation, pas un monde de test
	var camp_v: Vector2i = s_v.monde.cellule_camp
	var meilleur_v := 0
	for y in range(camp_v.y - 80, camp_v.y + 80):   # de quoi trouver un vrai village, pas un lieu-dit
		for x in range(camp_v.x - 80, camp_v.x + 80):
			var c := Vector2i(x, y)
			if not (surf_v.terre_a(c) and surf_v.poi_de(c).get("village", false)):
				continue
			var essai_v: Dictionary = surf_v.generer_cellule(c.x, c.y, {}, false).get("village", {})
			var metiers_v := {}   # le test parle d'un marchand, d'un garde, de lits et de champs :
			for pj_v in essai_v.get("pnj", []):
				metiers_v[str(pj_v.get("creature", ""))] = true
			if essai_v.get("pnj", []).size() > meilleur_v and metiers_v.has("marchand") and metiers_v.has("garde_village") and metiers_v.has("fermier"):
				meilleur_v = essai_v.pnj.size()   # ... on retient le hameau le mieux pourvu des alentours
				cell_v = c
	verifier(cell_v != Vector2i(-1, -1), "un village pourvu (marchand et garde) dans 160×160 cellules")
	var e := surf_v.generer_cellule(cell_v.x, cell_v.y, {}, false)
	var v: Dictionary = e.village
	verifier(not v.is_empty() and v.nom.length() >= 3 and v.batiments.size() >= 2 and v.pnj.size() >= 3, "un hameau nommé « %s » : %d bâtiments, %d PNJ" % [v.get("nom", "?"), v.get("batiments", []).size(), v.get("pnj", []).size()])
	verifier(e.murs.size() > 20 and e.portes.size() >= 2 and e.meubles.size() >= 3, "murs, portes et meubles de la palette (%d / %d / %d)" % [e.murs.size(), e.portes.size(), e.meubles.size()])
	var a_marchand := false
	for pj in v.pnj:
		if pj.creature == "marchand":
			a_marchand = true
	verifier(a_marchand, "un marchand dans l'échoppe")
	# On y va : les PNJ sont instanciés à la première visite, nommés, dotés d'or et d'un stock.
	# On VISITE le hameau, on n'y plante pas son camp : poser le camp sur la cellule la ferait générer
	# avec la configuration du camp, qui remplace le village. Le chemin du jeu, c'est le voyage.
	var s := Simulation.new(4242)
	s.planete_options = _planete_test()
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# On ne voyage que vers une cellule connue : on marque le hameau exploré, comme l'aurait fait
	# une marche jusque là-bas (la triche « reveler » ne porte qu'autour du joueur).
	var n_sec: int = s.monde.taille / 32
	s.monde.explores[Vector2i(cell_v.x * n_sec, cell_v.y * n_sec)] = true
	verifier(s.voyager(j, cell_v), "voyager jusqu'au hameau (%s)" % str(cell_v))
	var civils: Array = s.vivants().filter(func(x: Dictionary) -> bool: return "civil" in x.get("tags", []))
	verifier(civils.size() >= 3, "les PNJ du hameau sont là (%d)" % civils.size())
	var marchand := {}
	for x in civils:
		if x.get("fonction", "") == "commercant":
			marchand = x
	# Le stock d'un étal dépend du type de boutique tiré par l'agglomération (Villes B1) : au moins le minimum de sa sélection
	# (un armurier peut n'avoir que trois objets), jamais un nombre en dur dans le test.
	var stock_mini := 1
	if not marchand.is_empty() and not str(marchand.get("boutique", "")).is_empty():
		for bloc: Dictionary in GameData.entree("shop_types", str(marchand.boutique)).selection:
			stock_mini += int(bloc.nombre[0])
		stock_mini = maxi(1, stock_mini - 1)
	verifier(not marchand.is_empty() and marchand.has("nom") and tr(marchand.name_key) == Noms.afficher(marchand.nom) and int(marchand.or) == 300 and marchand.stock.size() >= stock_mini, "le marchand a un nom (%s), 300 or et un stock" % tr(marchand.get("name_key", "?")))
	verifier(not s.ennemis(j, marchand) and s.ennemis(marchand, {"camp": "hostile"}), "un civil n'est pas l'ennemi du joueur, mais celui des hostiles")
	if not marchand.is_empty():   # on arrive par la route : le joueur se place devant l'échoppe pour parler et commercer
		var devant := s._tuile_libre_autour(marchand.pos)
		if devant != Vector2i(-1, -1):
			s.grille.liberer(j.pos)
			j.pos = devant
			s.grille.placer(j.id, devant)
			s.maj_vision()
	# Dialogue : réplique conditionnée, pas trois fois la même ; Parler : +1 de relation une fois par jour.
	s.grille.liberer(j.pos)
	j.pos = marchand.pos + Vector2i(1, 0)
	s.grille.placer(j.id, j.pos)
	var vues := {}
	for k in 6:
		vues[s.replique(marchand, j)] = true
	verifier(vues.size() >= 3, "les répliques varient (%d différentes en 6 tirages)" % vues.size())
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "parler", "pnj": marchand.id}), "parler au marchand")
	var rel1: int = int(marchand.social.relations.get(j.id, 0))
	s.attente[j.id] = true
	s.intention(j.id, {"type": "parler", "pnj": marchand.id})
	verifier(rel1 >= 1 and int(marchand.social.relations.get(j.id, 0)) == rel1, "+1 (ou +2) de relation, une seule fois par jour")
	# Commerce : acheter du pain, vendre un lingot, le marchand à sec refuse.
	# Le stock du marchand vient de ses CATÉGORIES (Commerce et boutiques) : le test prend ce qu'il y trouve.
	verifier(marchand.stock.size() >= stock_mini, "le marchand tient un stock tiré de ses catégories (%d objets, %d au moins pour cette boutique)" % [marchand.stock.size(), stock_mini])
	var pain: String = str(marchand.stock[0])
	var p := s.prix_suggere(pain, marchand, j)
	verifier(int(p.prix) >= 1 and p.has("base") and p.has("rarete"), "prix suggéré du premier objet du stock : %d or (détail présent)" % int(p.prix))
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "acheter", "pnj": marchand.id, "objet": pain}), "sans or, pas d'achat")
	j.or = 100
	s.attente[j.id] = true
	var or_avant := int(j.or)
	var or_marchand := int(marchand.or)
	var achat_ok := s.intention(j.id, {"type": "acheter", "pnj": marchand.id, "objet": pain})
	var paye := or_avant - int(j.or)   # le prix se recalcule au moment de l'achat (la relation vient de bouger)
	verifier(achat_ok and pain in j.sac and paye >= 1 and int(marchand.or) == or_marchand + paye, "acheter au marchand (%d or)" % paye)
	s._donner_materiau(j, "fer", 1, "lingot")
	var lingot: String = s._pile(j, "fer", "lingot").uid
	var pl := s.prix_suggere(lingot, marchand, j)
	var base_fer := roundi(float(GameData.catalogues.materials.fer.stats.valeur_base) * float(pl.marche))   # le jour de marché du village du marchand, × prix_mult (Calendrier)
	verifier(int(pl.prix) == base_fer + 1 or int(pl.prix) == base_fer, "un lingot de fer vaut sa valeur de base (%d or pour une base de %d, marché × %.2f)" % [int(pl.prix), int(GameData.catalogues.materials.fer.stats.valeur_base), float(pl.marche)])
	s.attente[j.id] = true
	var or_vente := int(j.or)
	verifier(s.intention(j.id, {"type": "vendre", "pnj": marchand.id, "objet": lingot}) and lingot in marchand.stock and int(j.or) == or_vente + int(pl.achat), "vendre le lingot à 50 %% (+%d or)" % int(pl.achat))
	marchand.or = 0
	s._donner_materiau(j, "fer", 1, "lingot")
	var lingot2: String = s._pile(j, "fer", "lingot").uid
	s.attente[j.id] = true
	var stock_avant: Array = marchand.stock.duplicate()
	marchand.stock = []
	verifier(not s.intention(j.id, {"type": "vendre", "pnj": marchand.id, "objet": lingot2}), "le marchand à sec (sans stock à troquer) refuse d'acheter")
	marchand.stock = stock_avant
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 10.1 : territoire, résidents, semaine

## AUCUN BÂTIMENT N'EST ENCLAVÉ (ordre de travail 26 terdecies, 2026-09-09). Un bâtiment dont la porte ouvre sur un
## sol coupé du reste de la cellule, c'est un commerce où l'on ne peut pas entrer et un occupant qui ne peut pas
## sortir. `sonde_ville --graine_monde 3` en trouvait deux sur treize ; la génération ouvre désormais un passage —
## un arbre abattu de préférence, une porte percée si l'enclave n'est bornée que par de la pierre.
##
## Le test refait exactement la cellule qui échouait, et vérifie les deux choses qui comptent : que la génération a
## bien eu à rattraper (sinon le test ne prouverait plus rien le jour où le monde changera), et qu'il ne reste
## aucune porte hors de la plus grande composante marchable de la cellule.
func test_portes_sans_enclave() -> void:
	var planete_e: Dictionary = GameData.config("planete")
	var surf_e := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete_e, 3)
	var e_e: Dictionary = surf_e.generer_cellule(510, 205, {}, false)
	var v_e: Dictionary = e_e.get("village", {})
	verifier(not v_e.is_empty() and v_e.get("batiments", []).size() >= 10, "la cellule (510, 205) porte bien son quartier (%d bâtiments)" % v_e.get("batiments", []).size())
	verifier(not v_e.get("portes_rattrapees", []).is_empty(), "la génération a eu une enclave à ouvrir, et l'a ouverte (%s)" % str(v_e.get("portes_rattrapees", [])))
	verifier(v_e.get("portes_enclavees", []).is_empty(), "aucune enclave n'est restée fermée (%s)" % str(v_e.get("portes_enclavees", [])))
	# Et la preuve indépendante : on refait le découpage en composantes sur la cellule FINIE, et toute porte touche
	# la plus grande. C'est la même mesure que la sonde, mais sans point de départ choisi.
	var taille_e: int = e_e.largeur
	var comp_e := {}
	var n_e := 0
	for i0_e in e_e.sol.keys():
		var dep_e: int = int(i0_e)
		if comp_e.has(dep_e):
			continue
		n_e += 1
		var file_e: Array[int] = [dep_e]
		comp_e[dep_e] = n_e
		var tete_e := 0
		while tete_e < file_e.size():
			var i_e: int = file_e[tete_e]
			tete_e += 1
			@warning_ignore("integer_division")
			var p_e := Vector2i(i_e % taille_e, i_e / taille_e)
			for d_e in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var q_e: Vector2i = p_e + d_e
				if q_e.x < 0 or q_e.y < 0 or q_e.x >= taille_e or q_e.y >= taille_e:
					continue
				var iq_e: int = q_e.y * taille_e + q_e.x
				if comp_e.has(iq_e) or e_e.murs.has(iq_e) or e_e.eau.has(iq_e):
					continue
				if not (e_e.sol.has(iq_e) or e_e.portes.has(iq_e)):
					continue
				comp_e[iq_e] = n_e
				file_e.append(iq_e)
	var tailles_e := {}
	for c_e in comp_e.values():
		tailles_e[c_e] = int(tailles_e.get(c_e, 0)) + 1
	var ville_e := -1
	var max_e := 0
	for cid_e in tailles_e.keys():
		if int(tailles_e[cid_e]) > max_e:
			max_e = int(tailles_e[cid_e])
			ville_e = int(cid_e)
	var hors := 0
	for bat_e in v_e.batiments:
		var porte_e: Vector2i = bat_e.get("porte", Vector2i(-1, -1))
		if porte_e.x < 0:
			continue
		var touche := false
		for d_e in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var iv_e: int = (porte_e.y + d_e.y) * taille_e + porte_e.x + d_e.x
			if comp_e.has(iv_e) and int(comp_e[iv_e]) == ville_e:
				touche = true
				break
		if not touche:
			hors += 1
	verifier(hors == 0, "les %d portes du quartier touchent toutes la ville (%d hors, %d composantes)" % [v_e.batiments.size(), hors, tailles_e.size()])


func test_village_vivant() -> void:
	# On visite un village habité du monde de la partie (rectangulaire depuis le point 49) : y planter
	# le camp le remplacerait par une esplanade, et une zone en dur tomberait aujourd'hui dans l'océan.
	var s := Simulation.new(4242)
	s.planete_options = _planete_test()
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var camp_r: Vector2i = s.monde.cellule_camp
	var cell_v := Vector2i(-1, -1)
	var meilleur_r := 0
	for y in range(camp_r.y - 80, camp_r.y + 80):
		for x in range(camp_r.x - 80, camp_r.x + 80):
			var c := Vector2i(x, y)
			if not (surf.terre_a(c) and surf.poi_de(c).get("village", false)):
				continue
			var v_r: Dictionary = surf.generer_cellule(c.x, c.y, {}, false).get("village", {})
			if v_r.get("pnj", []).size() > meilleur_r:
				meilleur_r = v_r.pnj.size()
				cell_v = c
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_r: int = s.monde.taille / 32
	s.monde.explores[Vector2i(cell_v.x * n_r, cell_v.y * n_r)] = true
	s.voyager(j, cell_v)
	var civils: Array = s.vivants().filter(func(x: Dictionary) -> bool: return "civil" in x.get("tags", []) and x.ai_profile == "civil")
	verifier(civils.size() >= 2 and civils[0].has("lit") and civils[0].has("place") and civils[0].has("poste"), "les villageois ont un lit, un poste et la place")
	# À 23 h, la routine vise le lit ; à midi, le poste ; à 21 h, la place — un jour sans fête (le jour 0 est le
	# Nouvel An : la place toute la journée, Calendrier), le 5 du Rat.
	var v: Dictionary = civils[0]
	for c_v in civils:   # un villageois sans trait « lève-tôt » ou « couche-tard » : la routine aux heures nominales
		if SimPnj.trait_somme(s, c_v, "horaires_decalage") == 0.0:
			v = c_v
			break
	var profil: Dictionary = s.profils_ia.civil
	var jour_calme := 4 * int(GameData.config("planete").cycle.ticks_par_jour)
	var par_heure := int(GameData.config("planete").cycle.ticks_par_jour) / 24   # une heure du monde, en ticks (2026-09-08)
	s.horloge_monde.ticks = jour_calme + 23 * par_heure
	verifier(s._cible_routine(v, profil) == v.lit, "23 h : au lit")
	s.horloge_monde.ticks = jour_calme + 12 * par_heure
	verifier(s._cible_routine(v, profil) == v.poste, "midi : au poste")
	s.horloge_monde.ticks = jour_calme + 21 * par_heure
	verifier(s._cible_routine(v, profil) == s._coin_de_place(v), "21 h : sur son coin de la place")
	# Un villageois loin de sa cible s'en rapproche par la routine.
	var loin: Vector2i = s._coin_de_place(v) + Vector2i(6, 0)
	if s.grille.dans(loin) and not s.grille.bloque_passage(loin) and s.grille.occupant(loin).is_empty():
		s.grille.liberer(v.pos)
		v.pos = loin
		s.grille.placer(v.id, loin)
		# On mesure le CHEMIN restant, pas la distance à vol d'oiseau : contourner un mur éloigne
		# d'abord le villageois de sa place, ce qui ne veut pas dire qu'il n'y va pas.
		var d0 := s.grille.chemin(v.pos, s._coin_de_place(v), false, "", false).size()
		if s.en_combat(v):
			s._quitter_combat(v)   # un villageois pris dans une échauffourée ne rentre évidemment pas
		v["horloge"] = "monde"
		# On vérifie LA ROUTINE elle-même (le pas vers la cible horaire) : dans un village visité, le
		# sélecteur d'utilité peut légitimement préférer autre chose (fuir une bête, discuter) — ce
		# choix-là est couvert par les tests d'IA, celui-ci parle du trajet.
		for k in 24:
			v.compteur = 0
			s._ia_pas_routine(v, s._cible_routine(v, profil), s.horloge_monde.ticks + k * 10)
		var d1 := s.grille.chemin(v.pos, s._coin_de_place(v), false, "", false).size()
		verifier(v.pos == s._coin_de_place(v) or d1 < d0, "la routine rapproche le villageois de la place (%d → %d pas)" % [d0, d1])
	# Le garde patrouille de jour.
	var gardes: Array = s.vivants().filter(func(x: Dictionary) -> bool: return x.ai_profile == "garde")
	if not gardes.is_empty():
		var g: Dictionary = gardes[0]
		s.horloge_monde.ticks = jour_calme + 12000
		var p0: Vector2i = g.pos
		for k in 8:
			s._decider_ia(g, s.horloge_monde.ticks + k * 10)
		verifier(g.pos != p0 or g.has("patrouille"), "le garde patrouille (cible de patrouille posée)")
	# La faune : après quelques tirages, des bêtes hors de vue, sous le budget ; la nuit, plus de loups.
	var fa: Dictionary = GameData.config("planete").faune
	var n0: int = s.vivants().filter(func(x: Dictionary) -> bool: return "bete" in x.get("tags", [])).size()
	s.horloge_monde.ticks = 1200000
	for k in 40:
		s._tiquer_faune(12000 + k * int(fa.intervalle_ticks))
	var betes: Array = s.vivants().filter(func(x: Dictionary) -> bool: return "bete" in x.get("tags", []) and x.get("spawn_faune", false))
	verifier(betes.size() > 0 and betes.size() <= int(fa.budget), "des bêtes de surface sont apparues (%d, budget %d)" % [betes.size(), int(fa.budget)])
	var en_vue := 0
	for b in betes:
		if s.voit(j, b.pos):
			en_vue += 1
	verifier(en_vue <= betes.size() / 2 + 1, "la plupart sont apparues hors de vue (%d en vue)" % en_vue)
	var loups_jour := betes.filter(func(x: Dictionary) -> bool: return x.def == "loup").size()
	var ok_jour := true
	for b in betes:
		if b.def == "loup" and b.ai_profile != "bete_sauvage":
			ok_jour = false
	verifier(ok_jour, "de jour, les loups sont des bêtes sauvages")
	# Despawn : une bête éloignée hors combat disparaît.
	if not betes.is_empty():
		var b0: Dictionary = betes[0]
		s.grille.liberer(b0.pos)
		b0.pos = j.pos + Vector2i(90, 0)
		if s.grille.dans(b0.pos):
			s.grille.placer(b0.id, b0.pos)
			s._tiquer_faune(12000 + 100 * int(fa.intervalle_ticks))
			verifier(not s.entites.has(b0.id), "une bête à 90 tuiles hors combat disparaît")
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 8.4 : cycle jour-nuit et météo

func test_reputation_et_quetes() -> void:
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	var s := Simulation.new(4242)
	s.charger_camp()
	var surf_g: Surface = s.monde.surface
	var camp_g: Vector2i = s.monde.cellule_camp
	var cell_v := Vector2i(-1, -1)
	var meilleur_g := 0
	for y in range(camp_g.y - 80, camp_g.y + 80):   # un village peuplé du monde de la partie (point 49)
		for x in range(camp_g.x - 80, camp_g.x + 80):
			var c := Vector2i(x, y)
			if not (surf_g.terre_a(c) and surf_g.poi_de(c).get("village", false)):
				continue
			var v_g: Dictionary = surf_g.generer_cellule(c.x, c.y, {}, false).get("village", {})
			if v_g.get("pnj", []).size() > meilleur_g:
				meilleur_g = v_g.pnj.size()
				cell_v = c
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_g: int = s.monde.taille / 32
	s.monde.explores[Vector2i(cell_v.x * n_g, cell_v.y * n_g)] = true
	s.voyager(j, cell_v)
	var civils: Array = s.vivants().filter(func(x: Dictionary) -> bool: return "civil" in x.get("tags", []))
	var garde := {}
	var villageois := {}
	for x in civils:
		if x.ai_profile == "garde" and garde.is_empty():
			garde = x
	# Le villageois doit être du MÊME village que le garde : la réputation est un compte par village, et la fenêtre
	# charge plusieurs agglomérations à la fois (2026-09-07 — sinon le garde d'à côté offre ses quêtes sans rien savoir).
	for x in civils:
		if x.ai_profile != "garde" and str(x.get("village", "")) == str(garde.get("village", "")):
			villageois = x
			break
	if villageois.is_empty():
		for x in civils:
			if x.ai_profile != "garde":
				villageois = x
				break
	verifier(not garde.is_empty() and not villageois.is_empty() and str(garde.get("village", "")) == str(villageois.get("village", "")), "un garde et un villageois du même village")
	# Paliers d'information : inconnu (0-19) → nom ; à 50, compétences ; à 90, tout.
	verifier(s.palier_info(villageois, j) == 1, "relation 0 : palier 1 (nom, métier, village)")
	villageois.social.relations[j.id] = 55
	verifier(s.palier_info(villageois, j) == 3, "relation 55 : palier 3 (compétences, équipement)")
	villageois.social.relations[j.id] = -5
	verifier(s.palier_info(villageois, j) == 0, "relation négative : apparence seule")
	# Frapper un civil : relation −30, village −10, globale −3 ; le tuer rend hostile à vue.
	villageois.social.relations[j.id] = 0
	s.reputation(j, villageois, "frapper")
	verifier(int(villageois.social.relations[j.id]) == -30 and int(j.reputations.get(villageois.village, 0)) == -10 and int(j.reputations._globale) == -3, "frapper : −30 / −10 / −3")
	verifier(not s.ennemis(villageois, j), "à −30, pas encore hostile à vue")
	s.reputation(j, villageois, "frapper")
	verifier(int(villageois.social.relations[j.id]) == -60 and s.ennemis(villageois, j), "à −60 : hostile à vue")
	# Un autre villageois hérite de la réputation du village (−20 : quêtes refusées, prix +25 %).
	var autre := {}
	for x in civils:   # du MÊME village : la fenêtre charge plusieurs agglomérations depuis les villes (B1)
		if x.id != villageois.id and x.ai_profile == "civil" and str(x.get("village", "")) == str(villageois.get("village", "")):
			autre = x
	if not autre.is_empty():
		verifier(s.relation_de(autre, j) == -20, "un autre villageois lit la réputation du village (−20)")
	# Rédemption : une semaine, +1 vers 0.
	s._tiquer_monde(int(planete.corruption.ticks_par_semaine) + 1)
	verifier(int(villageois.social.relations[j.id]) == -59 and int(j.reputations.get(villageois.village, 0)) == -19, "dérive hebdomadaire +1 vers 0")
	# Quêtes : le garde en offre 2 ; refusées sous −20 ; accepter, tuer, rendre.
	j.reputations[villageois.village] = 0
	var q_refus := s.quetes_offertes(garde, j)
	verifier(q_refus.size() == 2, "le garde offre 2 quêtes par semaine (%d)" % q_refus.size())
	var q_chasse := {}
	for q in q_refus:
		if q.pattern == "tuer":
			q_chasse = q
	if q_chasse.is_empty():
		q_chasse = q_refus[0]
		q_chasse.pattern = "tuer"
		q_chasse.selector = {"tags_any": ["bete"]}
		q_chasse.count = 2
	q_chasse.selector = {"tags_any": ["bete", "hostile"]}
	q_chasse.count = 2
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "accepter_quete", "pnj": garde.id, "quete": q_chasse.uid}) and j.quetes.size() == 1 and j.quetes[0].etat == "en_cours", "accepter la quête de chasse")
	var or0: int = int(j.or)
	for k in 2:
		var loup := s.ajouter("loup", j.pos + Vector2i(3 + k, 3), "ia")
		loup.sante = 1
		s._appliquer_degats(loup, 5, j.id, {"type": "test"})
	verifier(int(j.quetes[0].fait) == 2 and j.quetes[0].etat == "terminee", "deux loups tués : la quête est terminée")
	garde.social.relations[j.id] = 0
	or0 = int(j.or)   # les hostiles laissent une bourse depuis le 2026-09-02 : on repart de l'or d'après les kills
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "rendre_quete", "pnj": garde.id, "quete": q_chasse.uid}), "rendre la quête")
	verifier(int(j.or) == or0 + int(q_chasse.or) and int(j.guildes[str(q_chasse.guild)].xp) == int(q_chasse.xp) and int(garde.social.relations[j.id]) == 10, "or, XP de guilde, +10 de relation avec le donneur")
	j.reputations[villageois.village] = -25
	verifier(s.quetes_offertes(garde, j).is_empty(), "sous −20 de réputation : pas de quête")
	# Rumeur : à ≥ 50, parler révèle une cellule à POI non explorée.
	j.reputations[villageois.village] = 0
	garde.social.relations[j.id] = 60
	var n0: int = s.monde.explores.size()
	s.attente[j.id] = true
	s.intention(j.id, {"type": "parler", "pnj": garde.id})
	verifier(s.monde.explores.size() >= n0, "la rumeur d'un garde peut révéler un donjon (%d chunks explorés)" % s.monde.explores.size())
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 9.B : routines, patrouilles, faune

## rank_min (Gabarit de quête) : les quêtes au-dessus du rang du joueur ne sont pas offertes.
func test_rang_de_guilde() -> void:
	var s := Simulation.new(4242)
	s.charger_camp({}, Vector2i(512, 512))
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var garde := s.ajouter("garde_village", j.pos + Vector2i(2, 0), "ia")
	if not ("quetes" in garde.tags):
		garde.tags.append("quetes")
	garde["village"] = "Bourg-Test"
	garde.social.relations[j.id] = 50
	var reserves := ["donjon", "purge"]   # les deux gabarits passés à rank_min 2
	var vus_novice: Array = []
	var vus_maitre: Array = []
	var semaine := int(GameData.config("planete").corruption.ticks_par_semaine)
	for k in 24:
		s.horloge_monde.ticks = semaine * (k + 1) + 1
		for q in s.quetes_offertes(garde, j):
			if not vus_novice.has(str(q.gabarit)):
				vus_novice.append(str(q.gabarit))
	j["guildes"] = {}
	for gid in GameData.catalogues.quest_templates.keys():
		j.guildes[str(GameData.catalogues.quest_templates[gid].guild)] = {"xp": 9999, "rang": 4}
	for k in 24:
		s.horloge_monde.ticks = semaine * (k + 100) + 1
		for q in s.quetes_offertes(garde, j):
			if not vus_maitre.has(str(q.gabarit)):
				vus_maitre.append(str(q.gabarit))
	var fuite := false
	for r in reserves:
		if vus_novice.has(r):
			fuite = true
	verifier(not fuite and vus_novice.size() > 4, "novice : aucune quête de rang 2 offerte (%d gabarits vus)" % vus_novice.size())
	var atteint := false
	for r in reserves:
		if vus_maitre.has(r):
			atteint = true
	verifier(atteint, "maître : les quêtes de donjon s'ouvrent")


# ---------------------------------------------------------------- Étape 9.C : réputation, information, quêtes

func test_compagnons() -> void:
	var s := Simulation.new(61)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(s.places_escorte(j) == 1 + int(j.stats_eff.charisme) / 5, "places d'escorte = 1 + Charisme/5 (%d)" % s.places_escorte(j))
	# Apprivoiser un cerf adjacent : jet universel, une tentative par jour.
	var cerf := s.ajouter("cerf", j.pos + Vector2i(1, 0), "ia")
	j.competences.dressage = 40
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	cerf.sante = 1   # sous 25 % : +10
	s.attente[j.id] = true
	var ok := s.intention(j.id, {"type": "apprivoiser", "cible": cerf.id})
	verifier(ok, "tentative d'apprivoisement jouée")
	if cerf.has("maitre"):
		verifier(cerf.camp == "joueur" and cerf.ai_profile == "compagnon" and s.compagnons_de(j).size() == 1, "le cerf est un compagnon")
	else:
		s.attente[j.id] = true
		verifier(not s.intention(j.id, {"type": "apprivoiser", "cible": cerf.id}) or int(cerf.dernier_apprivoisement) >= 0, "une seule tentative par jour")
	# Recruter un civil : refusé sous le seuil, accepté au seuil ; il suit.
	var v := s.ajouter("villageois", j.pos + Vector2i(-1, 0), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	verifier(v.has("age") and v.has("lifespan") and s.categorie_age(v) in ["jeune", "adulte", "age"], "le PNJ a un âge (%d ans, %s) et une espérance" % [int(v.age), s.categorie_age(v)])
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "recruter", "pnj": v.id}), "relation 0 : pas recrutable")
	v.social.relations[j.id] = 60
	j.corps.stats.charisme = 25
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "recruter", "pnj": v.id}) and v.camp == "joueur" and v.maitre == j.id, "relation 60 : recruté, il est au camp du joueur")
	s.grille.liberer(j.pos)
	j.pos = j.pos + Vector2i(6, 0)
	s.grille.placer(j.id, j.pos)
	var d0 := Grille.distance(v.pos, j.pos)
	for k in 5:
		s._decider_ia(v, s.horloge_monde.ticks + k * 10)
	verifier(Grille.distance(v.pos, j.pos) < d0, "le compagnon suit (%d → %d)" % [d0, Grille.distance(v.pos, j.pos)])
	verifier(s.ordonner(j, v.id, "attendre") and v.ordre == "attendre", "ordre : attends ici (sans coût)")
	# Mort et résurrection à l'autel.
	s._appliquer_degats(v, 999, "loup_test", {"type": "test"})
	var ame := ""
	for uid in j.sac:
		if "ame" in s.items[uid].get("tags", []):
			ame = uid
	verifier(not v.vivant and not ame.is_empty(), "compagnon mort : son âme est dans le sac")
	var autel: Vector2i = j.pos + Vector2i(0, 1)
	s.grille.poser_contenu(autel, "meuble")
	s.grille.meubles[s.grille.idx(autel)] = "autel_domestique"
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "ressusciter", "ame": ame}), "sans or, pas de résurrection")
	j.or = 500
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "ressusciter", "ame": ame}) and v.vivant and int(j.or) < 500 and v.statuts.size() > 0, "ressuscité à l'autel, affaibli, l'or payé")
	# Vieillesse : bien au-delà de l'espérance, la mort finit par venir.
	var vieux := s.ajouter("villageois", j.pos + Vector2i(-2, -2), "ia")
	s._habiller_pnj(vieux, GameData.entree("creatures", "villageois"))
	vieux.age = float(vieux.lifespan) + 30.0
	for k in 60:
		s._vieillir_semaine(k * 1000 + 7)
	verifier(not vieux.vivant, "un PNJ de 30 ans au-delà de son espérance meurt de vieillesse")
	s.monde.fermer()


func test_territoire() -> void:
	var s := Simulation.new(71)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var camp: Vector2i = s.monde.cellule_camp
	verifier(s.monde.claims.has(camp) and s.monde.claims[camp].role == "base", "le camp est revendiqué, rôle base")
	var voisine := camp + Vector2i(1, 0)
	var loin := camp + Vector2i(3, 0)
	s.monde.explores[Vector2i(voisine.x * (s.monde.taille / 32), voisine.y * (s.monde.taille / 32))] = true
	s.monde.explores[Vector2i(loin.x * (s.monde.taille / 32), loin.y * (s.monde.taille / 32))] = true
	if s.monde.surface.terre_a(voisine) and not s.monde.surface.poi_de(voisine).get("village", false):
		j.or = 10
		verifier(not s.revendiquer(j, voisine), "10 or : pas assez pour revendiquer (50)")
		j.or = 100
		verifier(s.revendiquer(j, voisine) and int(j.or) == 50 and s.monde.claims.size() == 2, "revendiquer la voisine pour 50 or")
		verifier(not s.revendiquer(j, loin), "une cellule non contiguë est refusée")
		verifier(s.changer_role(voisine, "champs") and s.monde.claims[voisine].role == "champs", "changer le rôle en champs")
	# Un compagnon assigné devient résident ; sans lit, humeur −15 ; puis un lit.
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 1), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v.social.relations[j.id] = 80
	j.corps.stats.charisme = 25
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "recruter", "pnj": v.id})
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "assigner", "pnj": v.id, "fonction": "bucheron"}), "assigner le compagnon comme bûcheron")
	verifier(v.has("assignation") and not v.has("maitre") and s.residents().size() == 1 and int(v.humeur) == 60 - 15, "résident sans logement : humeur 45")
	var pr := s.production_de(v)
	verifier(pr.has("base") and pr.base == "chene" and int(pr.n) > 0, "production prévue : des planches de chêne (%d)" % int(pr.get("n", 0)))
	# La semaine : production en stock, entretien 10 or ; sans trésor → dette et palier humeur.
	s._semaine_territoire(j)
	verifier(int(s.territoire.stocks.get("chene|planche", 0)) > 0 and int(s.territoire.dette) == 10 and int(s.territoire.semaines_dette) == 1, "semaine 1 : planches en stock, dette 10 or")
	verifier(int(v.humeur) == 60 - 15 - 10 - 5, "palier 1 : humeur recalculée (60, sans toit −15, sans repas −10) puis le −5 de la dette = %d" % int(v.humeur))
	s.deposer(j, 40)
	s._semaine_territoire(j)
	verifier(int(s.territoire.dette) == 0 and int(s.territoire.tresor) == 40 - 20, "trésor : la dette et l'entretien sont réglés (reste %d)" % int(s.territoire.tresor))
	verifier(s.retirer_stock(j, "chene|planche") and not s._pile(j, "chene", "planche").is_empty(), "retirer les planches du stock dans le sac")
	var or0: int = int(j.or)
	verifier(s.retirer(j, 20) and int(j.or) == or0 + 20 and int(s.territoire.tresor) == 0, "retirer 20 or du trésor")
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 10.2 : parcelles, boutique passive, troc

func test_agriculture_et_boutique() -> void:
	var s := Simulation.new(73)
	s.planete_options = _planete_test()   # un camp tempéré et stable : le blé pousse, l'étal se pose
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var camp: Vector2i = s.monde.cellule_camp
	s.changer_role(camp, "champs")
	var o := s.generer_objet("ble", 1, {}, "commun", 0)
	o.quantite = 2
	s.donner(j, o.uid)
	# Une tuile libre voisine : on la libère au besoin.
	var vers: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.contenu[s.grille.idx(vers)] = 0
	s.grille.meubles.erase(s.grille.idx(vers))
	s.grille.h_set(vers, s.grille.h(j.pos)) if s.grille.has_method("h_set") else null
	var avant_h := s.grille.h(vers) == s.grille.h(j.pos)
	s.attente[j.id] = true
	var ok := s.intention(j.id, {"type": "planter", "base": "ble"})
	verifier(ok or not avant_h, "planter du blé sur une tuile voisine (%s)" % str(ok))
	if ok:
		verifier(s.territoire.cultures.size() == 1 and int(s._pile_objet(j, "ble").get("quantite", 0)) == 1, "une parcelle, une graine consommée")
		var pm: Vector2i = s.territoire.cultures.keys()[0]
		var loc: Vector2i = pm
		s.attente[j.id] = true
		verifier(not s.intention(j.id, {"type": "prendre", "vers": loc}), "pas mûre : la récolte est refusée")
		var ech: int = int(s.territoire.cultures[pm].echeance)
		var reste := ech - s.horloge_monde.ticks + 100000
		while reste > 0:
			var n := mini(reste, 4000)
			s.horloge_monde.avancer(n)
			reste -= n
		# La faim tue depuis le point 52 : quelques jours de pousse affameraient le fermier. Il mange.
		# ET IL BOIT, depuis l'hydratation (ordre de travail 31, 2026-09-09) : la soif vide sa jauge deux fois plus
		# vite que la faim, et quelques jours de pousse tuaient le fermier là où ils l'avaient seulement affamé.
		# Le test se comporte donc comme un joueur, au lieu d'exiger un monde sans soif.
		j.faim = 100
		j.faim_tick = s.horloge_monde.ticks
		j["soif"] = 100
		j["soif_tick"] = s.horloge_monde.ticks
		j.sante = j.sante_max
		j.vivant = true
		verifier(bool(s.territoire.cultures[pm].mure) and "mure" in s.grille.contenu_de(loc).get("tags", []), "à l'échéance la parcelle est mûre")
		s.attente[j.id] = true
		j.pos = loc + Vector2i(-1, 0)
		verifier(s.intention(j.id, {"type": "prendre", "vers": loc}) and int(s._pile_objet(j, "ble").get("quantite", 0)) >= 2, "récolter : du blé revient (%d)" % int(s._pile_objet(j, "ble").get("quantite", 0)))
	# Boutique : un étal posé, trois objets rangés, des heures passent, la caisse se remplit.
	var et: Vector2i = j.pos + Vector2i(0, 1)
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var cand: Vector2i = j.pos + d
		if s.grille.dans(cand) and s.grille.occupant(cand).is_empty():
			s.grille.contenu[s.grille.idx(cand)] = 0
			s.grille.meubles.erase(s.grille.idx(cand))
			s.contenants.erase(s.grille.idx(cand))
			et = cand
			break
	var meuble := s.generer_objet("meuble_etal_de_vente", 1, {}, "commun", 0)
	s.donner(j, meuble.uid)
	s.attente[j.id] = true
	var pose := s.intention(j.id, {"type": "poser", "objet": meuble.uid, "vers": et})
	verifier(pose and s.territoire.etals.size() == 1, "poser l'étal : il est suivi (%s)" % str(pose))
	if pose:
		for k in 3:
			var ob := s.generer_objet("pain", 1, {}, "commun", 0)
			j.sac.append(ob.uid)
			s.attente[j.id] = true
			s.intention(j.id, {"type": "ranger", "objet": ob.uid, "vers": et})
		verifier(s._stock_etal(s._pm(et)).size() == 3, "trois pains à l'étal")
		s.regles.r.royaume.boutique.clients_base = 3.0
		s.horloge_monde.avancer(400000)
		verifier(int(s.territoire.caisse) > 0 and s._stock_etal(s._pm(et)).size() < 3, "des clients ont acheté : caisse %d or" % int(s.territoire.caisse))
		verifier(j.vivant and int(j.sante) > 0, "le marchand a tenu la journée : il a mangé et bu (soif %d, faim %d, PV %d)" % [int(j.get("soif", 100)), int(j.get("faim", 100)), int(j.sante)])
		var or0: int = int(j.or)
		var caisse: int = int(s.territoire.caisse)
		s.attente[j.id] = true
		verifier(s.intention(j.id, {"type": "prendre", "vers": et}) and int(j.or) == or0 + caisse and int(s.territoire.caisse) == 0, "relever la caisse")
	# Troc : un marchand à sec échange un objet de valeur proche.
	var m := s.ajouter("villageois", j.pos + Vector2i(-1, -1), "ia")
	s._habiller_pnj(m, GameData.entree("creatures", "villageois"))
	m.tags.append("commerce_possible")
	m.or = 0
	var a := s.generer_objet("proto_hache", 1, {}, "commun", 0)
	var b := s.generer_objet("proto_hache", 1, {}, "commun", 0)
	j.sac.append(a.uid)
	m.stock.append(b.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "vendre", "pnj": m.id, "objet": a.uid}) and (b.uid in j.sac) and (a.uid in m.stock), "marchand à sec : troc automatique")
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 10.3 : défense, raids, gouvernance

func test_defense_et_raids() -> void:
	var s := Simulation.new(75)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(s.defense_totale() == 0.0, "sans garde ni mur : défense nulle")
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 1), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v.social.relations[j.id] = 80
	j.corps.stats.charisme = 25
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "recruter", "pnj": v.id})
	s.attente[j.id] = true
	s.intention(j.id, {"type": "assigner", "pnj": v.id, "fonction": "garde"})
	verifier(s.defense_totale() >= 1.0, "un garde assigné : défense %.2f" % s.defense_totale())
	# Raid abstrait : force 40 contre une défense faible → pertes bornées.
	s.territoire.stocks["chene|planche"] = 100
	s.territoire.caisse = 100
	s.lieu = "expedition"
	s._resoudre_raid_abstrait(40.0, s.horloge_monde.ticks)
	s.lieu = "camp"
	var st: int = int(s.territoire.stocks.get("chene|planche", 0))
	verifier(st >= 50 and st <= 90 and not s.territoire.dernier_raid.is_empty() and not bool(s.territoire.dernier_raid.victoire), "raid subi en absence : stocks %d/100 (pertes bornées)" % st)
	s._resoudre_raid_abstrait(0.5, s.horloge_monde.ticks)
	verifier(bool(s.territoire.dernier_raid.victoire), "un raid faible est repoussé")
	# Raid réel : des assaillants au bord de la cellule, qui avancent vers le cœur.
	s._lancer_raid_reel(8.0, s.horloge_monde.ticks)
	var rd: Dictionary = s.territoire.raid
	verifier(not rd.is_empty() and int(rd.n) >= 2 and s.entites[str(rd.ids[0])].ai_profile == "assaillant" and s.entites[str(rd.ids[0])].camp == "raid", "%d assaillants apparus" % int(rd.get("n", 0)))
	var coeur: Vector2i = s.camp_sauve.entree
	var d0 := Grille.distance(s.entites[str(rd.ids[0])].pos, coeur)
	s.attente[j.id] = true
	for k in 6:
		s.horloge_monde.avancer(10000)
	var d1 := Grille.distance(s.entites[str(rd.ids[0])].pos, coeur)
	verifier(d1 < d0, "l'assaillant avance vers le cœur (%d → %d)" % [d0, d1])
	# Une tourelle près de l'assaillant : elle tire pendant le raid.
	var ass: Dictionary = s.entites[str(rd.ids[0])]
	var pt: Vector2i = ass.pos + Vector2i(2, 0)
	for dd in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		var c: Vector2i = ass.pos + dd
		if s.grille.dans(c) and s.grille.occupant(c).is_empty():
			pt = c
			break
	s.grille.contenu[s.grille.idx(pt)] = 0
	s.grille.poser_contenu(pt, "meuble")
	s.grille.meubles[s.grille.idx(pt)] = "tourelle"
	s.monde.claims[s._cell_de(pt)] = {"role": "base"}
	var sante_avant := 0
	for id in rd.ids:
		sante_avant += int(s.entites[str(id)].sante)
	s.territoire.raid["prochain_tir"] = 0
	for k in 4:
		s.horloge_monde.avancer(2000)
	var sante_apres := 0
	for id in rd.ids:
		sante_apres += int(s.entites[str(id)].sante)
	verifier(sante_apres < sante_avant, "la tourelle a tiré : santé des assaillants %d → %d" % [sante_avant, sante_apres])
	s.territoire.raid.fin = s.horloge_monde.ticks
	s.horloge_monde.avancer(100)
	verifier(s.territoire.raid.is_empty() and not bool(s.territoire.dernier_raid.victoire) and s.entites[str(rd.ids[0])].ai_profile == "hostile", "à l'échéance le raid est résolu, les survivants restent hostiles")
	# Gouvernance : royaume, transition de 4 semaines, −10 d'humeur.
	verifier(not s.changer_gouvernance("dictature_militaire"), "pas de royaume : pas de régime")
	s.territoire.royaume = true
	s.territoire.gouvernance = "monarchie_hereditaire"
	var h0 := int(v.humeur)
	verifier(s.changer_gouvernance("dictature_militaire") and int(s.territoire.transition) == 4 and int(v.humeur) == h0 - 10, "transition lancée : 4 semaines, −10 d'humeur")
	s.territoire.tresor = 1000
	s.regles.r.royaume.raids.proba_max = 0.0
	for k in 4:
		s._semaine_territoire(j)
	verifier(s.territoire.gouvernance == "dictature_militaire" and int(s.territoire.transition) == 0, "quatre semaines plus tard : dictature militaire")
	verifier(s.defense_totale() > 1.0, "dictature : défense ×1,5 (%.2f)" % s.defense_totale())
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 10.4 : royaumes PNJ, lois, douanes, accords

func test_royaumes_pnj() -> void:
	var s := Simulation.new(77)
	s.charger_camp()
	var surf = s.monde.surface
	# Des royaumes déterministes : on parcourt des secteurs jusqu'à en trouver.
	var trouve: Dictionary = {}
	var sect := Vector2i.ZERO
	for k in 40:
		sect = surf.secteur_de(s.monde.cellule_camp) + Vector2i(k % 7 - 3, k / 7 - 3)
		var rs: Dictionary = surf.royaumes_secteur(sect)
		if not rs.is_empty():
			trouve = rs
			break
	verifier(not trouve.is_empty(), "des royaumes existent dans les secteurs voisins (%d dans le secteur %s)" % [trouve.size(), str(sect)])
	if not trouve.is_empty():
		var roy: Dictionary = trouve.values()[0]
		verifier(roy.territory_cells.size() >= 1 and surf.royaume_de(roy.capital_poi).id == roy.id, "%s (%s, %s) : %d cellules, capitale attribuée" % [roy.nom, roy.taille, roy.government_type, roy.territory_cells.size()])
		var terre := true
		for c in roy.territory_cells:
			terre = terre and surf.terre_a(c)
		verifier(terre, "le territoire ne franchit jamais l'eau")
		var meme: Dictionary = surf.royaumes_secteur(sect)
		verifier(meme.size() == trouve.size() and str(meme.values()[0].nom) == str(roy.nom), "génération déterministe et mise en cache")
	# Un royaume scripté pour tester lois, douanes et accords.
	var camp: Vector2i = s.monde.cellule_camp
	var voisine: Vector2i = camp + Vector2i(1, 0)
	var r := {"id": "royaume_test", "nom": "Testia", "government_type": "monarchie_hereditaire", "culture": "latine", "race": "humain", "taille": "hameau", "capital_poi": voisine, "territory_cells": [voisine],
		"taxes": {"base_rate": 0.08, "tariff_default": 0.1}, "tariffs": {"metal": 0.5}, "laws": [{"id": "loi_pdt", "type": "objet", "target": "pomme_de_terre", "status": "illegal", "consequence": "confiscation"}, {"id": "loi_meurtre", "type": "comportement", "target": "meurtre", "status": "illegal", "consequence": "gardes_hostiles"}], "diplomacy": {}, "rivals": [], "tags": []}
	surf.royaumes_cache[surf.secteur_de(voisine)] = {"royaume_test": r}
	surf.royaume_par_cellule[voisine] = "royaume_test"
	surf.royaume_par_cellule[camp] = "royaume_test"   # pour le test, le camp est en Testia
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Douane : un marchand de Testia taxe le métal à 50 %.
	var m := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(m, GameData.entree("creatures", "villageois"))
	m.tags.append("commerce_possible")
	m["royaume"] = "royaume_test"
	m.or = 500
	var lingot := s.generer_objet("materiau_brut", 1, {}, "commun", 0)
	lingot.materiau = "fer"
	lingot["forme"] = "lingot"
	j.sac.append(lingot.uid)
	verifier(absf(s.tarif_de(lingot.uid, m) - 0.5) < 0.01, "tarif du fer : 50 %%")
	var p0 := s.prix_suggere(lingot.uid, m, j)
	var or0: int = int(j.or)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "vendre", "pnj": m.id, "objet": lingot.uid}) and int(j.or) == or0 + maxi(1, roundi(float(p0.achat) * 0.5)), "vendre du fer : la douane retient la moitié")
	# Loi absurde : la pomme de terre est confisquée si un témoin le voit (Perception 30 contre Discrétion 0 → détecté, sauf jet).
	m.corps.stats.perception = 40
	var detecte := 0
	for k in 6:
		var pdt := s.generer_objet("pomme_de_terre", 1, {}, "commun", 0)
		s.donner(j, pdt.uid)
		if not (pdt.uid in j.sac) and s._pile_objet(j, "pomme_de_terre").is_empty():
			detecte += 1
	verifier(detecte >= 1, "objet interdit : confisqué au moins une fois sur six (%d)" % detecte)
	verifier(int(j.get("reputations", {}).get("royaume_test", 0)) < 0, "la réputation envers Testia a baissé (%d)" % int(j.get("reputations", {}).get("royaume_test", 0)))
	# Accords : à 20 de réputation l'accord commercial passe et divise les tarifs par deux.
	j.reputations["royaume_test"] = 25
	verifier(not s.proposer_accord(j, "royaume_test", "alliance"), "alliance refusée à 25 de réputation")
	verifier(s.proposer_accord(j, "royaume_test", "commercial") and absf(s.tarif_de(lingot.uid, m) - 0.25) < 0.01, "accord commercial : tarif du fer 25 %%")
	verifier(s.relation_royaume(j, r) == "neutre", "relation neutre entre 0 et 30")
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 10.5 : conquête, succession, repeuplement

func test_conquete_et_succession() -> void:
	var s := Simulation.new(79)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Un village scripté sur la cellule voisine : trois habitants, un garde de niveau 0, un dirigeant.
	var camp: Vector2i = s.monde.cellule_camp
	var cell: Vector2i = camp + Vector2i(1, 0)
	var e: Dictionary = s.monde.cellule(cell)
	var centre_l := Vector2i(6, s.monde.taille / 2)   # au bord gauche de la cellule, à mi-hauteur
	var centre: Vector2i = s.monde.pos_monde(cell, centre_l)
	for dy in range(-3, 4):
		for dx in range(-3, 6):
			var q: Vector2i = centre + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(q)] = 0
			s.grille.meubles.erase(s.grille.idx(q))
	j.pos = centre + Vector2i(-1, 0)
	e["village"] = {"nom": "Bourg-Test", "culture": "latine", "centre": centre_l, "batiments": [], "pnj": [], "royaume": "roy_test"}
	s.monde.villages["Bourg-Test"] = {"cellule": cell, "royaume": "roy_test", "conquis_par": "", "defense_jusqua": 0, "abandonne": false, "capacite": 6}
	var r := {"id": "roy_test", "nom": "Testonie", "government_type": "monarchie_hereditaire", "culture": "latine", "race": "humain", "taille": "hameau", "capital_poi": cell, "territory_cells": [cell],
		"taxes": {"base_rate": 0.08, "tariff_default": 0.1}, "tariffs": {}, "laws": [], "diplomacy": {}, "rivals": [], "tags": []}
	s.monde.surface.royaumes_cache[s.monde.surface.secteur_de(cell)] = {"roy_test": r}
	s.monde.surface.royaume_par_cellule[cell] = "roy_test"
	var habitants: Array = []
	for k in 3:
		var x := s.ajouter("villageois", centre + Vector2i(1 + k, 2), "ia")
		s._habiller_pnj(x, GameData.entree("creatures", "villageois"))
		x["village"] = "Bourg-Test"
		x["royaume"] = "roy_test"
		habitants.append(x)
	var garde := s.ajouter("garde_village", centre + Vector2i(1, -2), "ia")
	s._habiller_pnj(garde, GameData.entree("creatures", "garde_village"))
	garde["village"] = "Bourg-Test"
	garde["royaume"] = "roy_test"
	garde.ai_profile = "garde"
	var chef := s.ajouter("villageois", centre + Vector2i(2, -2), "ia")
	s._habiller_pnj(chef, GameData.entree("creatures", "villageois"))
	chef["village"] = "Bourg-Test"
	chef["royaume"] = "roy_test"
	chef.fonction = "dirigeant"
	# Le joueur va au pied de la place ; le garde (niveau 0 → 1 point) contre un seuil de 0,25 × 2 × 5 = 2,5 : conquérable.
	j.corps.stats.charisme = 80   # +20 au jet : la conquête réussit contre DD 10
	s.attente[j.id] = true
	for cle in garde.competences.keys():
		garde.competences[cle] = 0
	var ok := s.intention(j.id, {"type": "conquerir", "vers": centre})
	verifier(ok and s.monde.claims.has(cell) and s.monde.villages["Bourg-Test"].conquis_par == j.id, "conquête réussie : la cellule rejoint le territoire")
	# La jonction avec la mine (designer, rappel du 2026-09-07) : « on peut miner dans les profondeurs en descendant
	# d'un niveau Z avec un escalier à chaque fois ». Une mine ne s'ouvre que sur une cellule REVENDIQUÉE — et une
	# ville conquise l'est. Les deux systèmes se rejoignent donc sans rien ajouter : on prend la ville, on creuse dessous.
	var vig0: int = int(j.vigueur)
	j.vigueur = 100
	verifier(SimLieux.creuser_un_puits(s, j, s.horloge_monde.ticks), "sous une ville conquise, le puits s'ouvre")
	verifier(s.lieu == "donjon" and bool(s.donjon.get("mine", false)) and Vector2i(s.donjon.cellule_mine) == cell, "on descend dans la mine de CETTE cellule (étage %d)" % int(s.donjon.get("etage", 0)))
	var creusables := 0
	for i_m in s.grille.n_tuiles():
		if s.grille.bloque_passage(s.grille.pos_de(i_m)):
			creusables += 1
	verifier(creusables > 3000, "l'étage de mine est plein de roche à creuser (%d tuiles)" % creusables)
	SimLieux._sortir(s, j)   # on remonte : la suite du test se joue au village, pas au fond du puits
	verifier(s.lieu == "camp", "on remonte de la mine au village")
	j.vigueur = vig0
	j.pos = centre + Vector2i(1, 1)
	if not s.grille.occupant(j.pos).is_empty():
		j.pos = s._tuile_libre_autour(j.pos)
	verifier(int(j.reputations.get("roy_test", 0)) == -30, "agression : −30 envers Testonie (%d)" % int(j.get("reputations", {}).get("roy_test", 0)))
	# Les habitants deviennent assignables.
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "assigner", "pnj": habitants[0].id, "fonction": "fermier"}) and habitants[0].has("assignation") and habitants[0].camp == "civil", "un habitant conquis est assignable sans changer de camp")
	# Succession : le dirigeant meurt, vacance de 4 semaines, puis le plus haut niveau général reprend.
	s._appliquer_degats(chef, 9999, j.id, {})
	verifier(s.monde.vacances.has("roy_test"), "la mort du dirigeant ouvre une vacance")
	habitants[1].competences["negociation"] = 30
	s.monde.semaine_courante += 4
	s._semaine_royaumes_pnj()
	verifier(not s.monde.vacances.has("roy_test") and str(habitants[1].fonction) == "dirigeant", "quatre semaines plus tard, le plus haut niveau général succède")
	# Repeuplement : un lit libre, chance forcée à 1.
	e.village.pnj.append({"creature": "villageois", "pos": centre_l + Vector2i(0, 2), "lit": centre_l + Vector2i(0, 2)})
	s.monde.peuplees[cell] = true
	s.regles.r.royaume.repeuplement.chance = 10.0
	var pop0 := s.population_village("Bourg-Test").size()
	s._semaine_royaumes_pnj()
	verifier(s.population_village("Bourg-Test").size() == pop0 + 1, "repeuplement : un habitant de plus (%d → %d)" % [pop0, s.population_village("Bourg-Test").size()])
	s.monde.fermer()


# ---------------------------------------------------------------- Alchimie : parties, Alambic, potions
