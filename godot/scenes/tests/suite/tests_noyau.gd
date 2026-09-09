extends TestsBase
## Le noyau : grille, dés, règles, simulation, horloges, Wu Xing, capacités, statuts, liaisons, niveaux, paperdoll.
## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de
## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l'ordre de sa liste.


## Le noyau C++ de la grille (Modules de la simulation et le C++, section 3, 2026-09-06) rend EXACTEMENT ce que le
## GDScript rend : chemins, atteignables, lignes de vue, premier obstacle, champ de vue, coûts de pas — sur l'arène
## « gorge » (le relief) puis sur la fenêtre d'un monde (eau, portes, bâtiments, occupants, dangers, neige, gel) —
## et ses miroirs (occ, danger_a, eau_a, frott_a) disent la même chose que les dictionnaires qu'ils reflètent.
## Sans la bibliothèque chargée, le test le dit et passe : le jeu tourne alors tout en GDScript.
func test_noyau_cpp() -> void:
	if not Grille.noyau_present():
		verifier(true, "noyau C++ absent (sensen_grille non chargée) : tout se calcule en GDScript")
		return
	var s := nouvelle_sim("gorge")
	verifier(s.grille._noyau != null and s.grille._noyau_pret(), "la grille de l'arène a son noyau")
	_comparer_noyau(s.grille, "gorge", 150)
	# De l'eau sur l'arène : un lac (sources), un écoulement à niveaux, une tuile mouillée sous du butin (Eau et liquides).
	var ga := s.grille
	for y in range(5, 10):
		for x in range(5, 10):
			ga.poser_contenu(Vector2i(x, y), "eau")
	for i in 3:
		var p := Vector2i(12 + i, 20)
		ga.poser_contenu(p, "eau_ecoulement")
		ga.poser_eau(ga.idx(p), 1 + i * 3)
	ga.poser_contenu(Vector2i(6, 6), "butin")
	verifier(ga.niveau_liquide(Vector2i(6, 6)) == 8 and ga.niveau_liquide(Vector2i(13, 20)) == 4, "l'eau posée pour le test : source sous le butin, écoulement à 4")
	_comparer_noyau(ga, "gorge, eau", 120)
	var sm := Simulation.new(9)
	sm.graine_monde = 9
	sm.charger_camp()
	var g := sm.grille
	verifier(g._noyau != null and g._noyau_pret(), "la fenêtre du monde a son noyau")
	var eau := 0
	var portes := 0
	for i in g.largeur * g.hauteur_grille:
		var tags: Array = g.contenu_de(g.pos_de(i)).get("tags", [])
		if "liquide" in tags:
			eau += 1
		if "fermee" in tags:
			portes += 1
	print("  noyau : fenêtre %d × %d, %d êtres, %d tuiles d'eau, %d portes fermées" % [g.largeur, g.hauteur_grille, sm.vivants().size(), eau, portes])
	_comparer_noyau(g, "monde", 120)
	# Les dangers (un feu), la neige et le gel changent les coûts : le noyau doit suivre.
	var j := joueur_de(sm)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 40:
		var p: Vector2i = j.pos + Vector2i(rng.randi_range(-30, 30), rng.randi_range(-30, 30))
		if g.dans(p) and not g.bloque_passage(p):
			g.poser_danger(g.idx(p))
	g.neige = true
	_comparer_noyau(g, "monde, neige et dangers", 40)
	g.gel = true
	_comparer_noyau(g, "monde, gel", 30)
	g.neige = false
	g.gel = false
	# Un chemin vers un être en l'ignorant (la cible qu'on approche), et les miroirs.
	var cibles := 0
	var ok_ignorer := true
	var autres: Array = sm.vivants().filter(func(x: Dictionary) -> bool: return x.id != j.id)
	autres.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return Grille.distance(x.pos, j.pos) < Grille.distance(y.pos, j.pos))
	for x in autres:
		if cibles >= 12:
			break
		cibles += 1
		var attendu := g._chemin_gd(j.pos, x.pos, false, x.id, false, 800)
		var obtenu: Array[Vector2i] = g._noyau.chemin(g, j.pos, x.pos, false, x.id, false, 800)
		if attendu != obtenu:
			ok_ignorer = false
	verifier(ok_ignorer and cibles > 0, "un chemin vers un être en l'ignorant : le même (%d cibles)" % cibles)
	var miroirs := 0
	for i in g.largeur * g.hauteur_grille:
		if (g.occ[i] == 1) != g.occupants.has(i):
			miroirs += 1
		# Le danger est GRADUÉ depuis le 2026-09-08 (Émergence — le champ de danger) : le miroir ne porte plus 1 ou 0
		# mais l'intensité 1-100, et c'est ce que le noyau lit (il refuse toute valeur non nulle). On vérifie donc
		# l'ÉGALITÉ EXACTE, ce qui est plus fort que l'ancien test booléen : une intensité mal reportée se voit.
		if int(g.danger_a[i]) != int(g.dangers.get(i, 0)):
			miroirs += 1
		if int(g.eau_a[i]) != (int(g.niveau_eau[i]) + 1 if g.niveau_eau.has(i) else 0):
			miroirs += 1
	var frott := 0
	for k in 400:
		var i := rng.randi_range(0, g.largeur * g.hauteur_grille - 1)
		if not is_equal_approx(g.frott_a[i], g._mult_friction(g.pos_de(i))):
			frott += 1
	verifier(miroirs == 0, "les miroirs du noyau (occupants, dangers, eau) reflètent leurs dictionnaires (%d écarts)" % miroirs)
	verifier(frott == 0, "la friction compilée par tuile est celle de _mult_friction (%d écarts sur 400)" % frott)
	# Les ombres portées (Éclairage) : la carte d'ombre du noyau est celle du GDScript, pour trois soleils.
	var ecarts_ombres := 0
	var t_o_gd := 0
	var t_o_cpp := 0
	for soleil in [[Vector2(0.7071, -0.7071), 2.0], [Vector2(0.9, 0.436), 4.5], [Vector2(-0.6, 0.8), 1.2]]:
		var coin: Vector2i = j.pos - Vector2i(20, 20)
		var t_a := Time.get_ticks_usec()
		var o_gd: PackedByteArray = g._ombres_gd(soleil[0], soleil[1], coin, Vector2i(41, 41), 8, 4)
		var t_b := Time.get_ticks_usec()
		var o_cpp: PackedByteArray = g._noyau.ombres(g, soleil[0], soleil[1], coin, Vector2i(41, 41), 8, 4)
		var t_c := Time.get_ticks_usec()
		t_o_gd += t_b - t_a
		t_o_cpp += t_c - t_b
		if o_gd != o_cpp:
			ecarts_ombres += 1
	verifier(ecarts_ombres == 0, "les ombres portées : la même carte par le noyau, trois soleils (GDScript %.1f ms, C++ %.2f ms)" % [float(t_o_gd) / 1000.0, float(t_o_cpp) / 1000.0])
	# La lumière des tuiles (Éclairage, designer 2026-09-06 : « une échelle et une teinte ») : la même carte par le noyau,
	# avec le ciel de midi et son ombre, puis la nuit et les torches de la ville.
	var locale := PackedByteArray()
	locale.resize(g.largeur * g.hauteur_grille)
	for k in 200:   # des torches semées : des niveaux 1-15
		locale[(k * 7919) % locale.size()] = 1 + (k * 13) % 15
	var ecarts_lum := 0
	var t_l_gd := 0
	var t_l_cpp := 0
	for cas in [[Color(1, 1, 1), Vector2(0.7071, -0.7071), 3.0, 0.28], [Color(0.28, 0.3, 0.45), Vector2.ZERO, 0.0, 0.0], [Color(0.8, 0.6, 0.55), Vector2(-0.6, 0.8), 1.2, 0.2]]:
		var coin_l: Vector2i = j.pos - Vector2i(24, 24)
		var ta_l := Time.get_ticks_usec()
		var c_gd: PackedByteArray = g._carte_lumiere_gd(cas[0], locale, Color(1.0, 0.85, 0.6), 1.0, cas[1], cas[2], 8, 4, cas[3], coin_l, Vector2i(49, 49))
		var tb_l := Time.get_ticks_usec()
		var c_cpp: PackedByteArray = g._noyau.carte_lumiere(g, cas[0], locale, Color(1.0, 0.85, 0.6), 1.0, cas[1], cas[2], 8, 4, cas[3], coin_l, Vector2i(49, 49))
		var tc_l := Time.get_ticks_usec()
		t_l_gd += tb_l - ta_l
		t_l_cpp += tc_l - tb_l
		if c_gd != c_cpp:
			ecarts_lum += 1
	verifier(ecarts_lum == 0, "la lumière des tuiles : la même carte par le noyau (midi et ombre, nuit et torches, crépuscule) — GDScript %.0f ms, C++ %.2f ms" % [float(t_l_gd) / 1000.0, float(t_l_cpp) / 1000.0])
	# Les règles de la lumière (designer) : à l'ombre à midi, plus clair que la nuit ; une torche teinte la nuit, pas le plein soleil.
	var force_t := float(GameData.config("planete").cycle.lumiere.get("torche_force", 0.7))
	var midi: PackedByteArray = g._carte_lumiere_gd(Color(1, 1, 1), PackedByteArray(), Color(1.0, 0.85, 0.6), force_t, Vector2.ZERO, 0.0, 0, 4, 0.0, Vector2i.ZERO, Vector2i.ZERO)
	var i0 := g.idx(j.pos)
	var ombre_midi := 255.0 * (1.0 - 0.28)
	var nuit_c: PackedByteArray = g._carte_lumiere_gd(Color(0.28, 0.3, 0.45), PackedByteArray(), Color(1.0, 0.85, 0.6), force_t, Vector2.ZERO, 0.0, 0, 4, 0.0, Vector2i.ZERO, Vector2i.ZERO)
	verifier(midi[i0 * 3] == 255 and ombre_midi > float(nuit_c[i0 * 3]) and nuit_c[i0 * 3 + 2] > nuit_c[i0 * 3], "à midi une tuile vaut 1, à l'ombre 0,72 — plus clair que la nuit (%d/255, bleutée)" % nuit_c[i0 * 3])
	var torche := PackedByteArray()
	torche.resize(g.largeur * g.hauteur_grille)
	torche[i0] = 15
	var nuit_t: PackedByteArray = g._carte_lumiere_gd(Color(0.28, 0.3, 0.45), torche, Color(1.0, 0.85, 0.6), force_t, Vector2.ZERO, 0.0, 0, 4, 0.0, Vector2i.ZERO, Vector2i.ZERO)
	var midi_t: PackedByteArray = g._carte_lumiere_gd(Color(1, 1, 1), torche, Color(1.0, 0.85, 0.6), force_t, Vector2.ZERO, 0.0, 0, 4, 0.0, Vector2i.ZERO, Vector2i.ZERO)
	verifier(nuit_t[i0 * 3] > nuit_t[i0 * 3 + 2] and nuit_t[i0 * 3] > nuit_c[i0 * 3] and midi_t[i0 * 3] == 255 and midi_t[i0 * 3 + 2] == 255, "une torche la nuit éclaire et teinte en chaud (%d, %d, %d) ; en plein soleil elle n'ajoute rien" % [nuit_t[i0 * 3], nuit_t[i0 * 3 + 1], nuit_t[i0 * 3 + 2]])
	sm.monde.fermer()
	# Les pièces d'une cellule de village (Détection de pièces) : les régions closes inondées par le noyau, les mêmes.
	var sv := Simulation.new(83)
	sv.charger_camp()
	var surf: Surface = sv.monde.surface
	var cell: Vector2i = sv.monde.cellule_camp + Vector2i(1, 0)
	surf.fiches_agglo.erase(cell)
	var agglo: Dictionary = surf.fiche_agglomeration(cell).duplicate()
	agglo["quartier"] = "centre"
	agglo["index"] = 0
	var ev: Dictionary = surf.generer_cellule(cell.x, cell.y, {}, false)
	if ev.village.is_empty():
		var rng_v := RandomNumberGenerator.new()
		rng_v.seed = 83
		surf._poser_quartier(ev, cell, rng_v, agglo)
	sv.monde.cellules[cell] = ev
	sv.grille = sv.monde.fenetre(sv.monde.centre, GameData.config("tile_contents"), sv.regles.r.deplacement, int(sv.regles.r.vision.hauteur_oeil))
	var t_gd0 := Time.get_ticks_usec()
	var p_gd: Array = SimTerritoire._pieces_de_cellule_gd(sv, cell)
	var t_gd1 := Time.get_ticks_usec()
	var p_cpp: Array = SimTerritoire._pieces_noyau(sv, cell)
	var t_gd2 := Time.get_ticks_usec()
	verifier(p_gd.size() > 0 and p_gd == p_cpp, "les pièces d'une cellule de village : les mêmes par le noyau (%d pièces, GDScript %.1f ms, C++ %.2f ms)" % [p_gd.size(), float(t_gd1 - t_gd0) / 1000.0, float(t_gd2 - t_gd1) / 1000.0])
	# La propagation de la lumière (les torches et meubles du village, les êtres) : la même carte 0-15 par le noyau.
	var t_p0 := Time.get_ticks_usec()
	sv._recalculer_lumiere_gd()
	var lum_gd: PackedByteArray = sv.carte_lumiere.duplicate()
	var t_p1 := Time.get_ticks_usec()
	sv._recalculer_lumiere_noyau()
	var t_p2 := Time.get_ticks_usec()
	var sources := 0
	for v_l in lum_gd:
		if v_l > 0:
			sources += 1
	verifier(lum_gd == sv.carte_lumiere and sources > 0, "la propagation de la lumière : la même carte par le noyau (%d tuiles éclairées, GDScript %.1f ms, C++ %.2f ms)" % [sources, float(t_p1 - t_p0) / 1000.0, float(t_p2 - t_p1) / 1000.0])
	# La génération d'une cellule de surface (file 109) : le sol et la végétation par le noyau, la même cellule au bit près
	# — le même RNG consommé dans le même ordre, donc le même quartier de village derrière.
	var c0: Vector2i = sv.monde.cellule_camp
	# Les couches d'abord, valeur par valeur (2026-09-07) : une dérive sous le seuil d'un biome ne changerait pas le
	# sol, mais elle voudrait dire que le noyau ne lit pas le monde comme le GDScript.
	var noyau_c: RefCounted = ClassDB.instantiate(&"SensenGrille")
	var nb_c: int = (sv.monde.taille + Surface.PAS_BRUIT - 1) / Surface.PAS_BRUIT
	var ecarts_c := 0
	var pire_c := 0.0
	var n_val := 0
	for d_c in [Vector2i(0, 0), Vector2i(3, -2), Vector2i(-4, 5)]:
		var cc: Vector2i = c0 + d_c
		var lot_gd: Dictionary = surf.couches_blocs(null, sv.monde.taille, cc.x * sv.monde.taille, cc.y * sv.monde.taille, nb_c)
		var lot_c: Dictionary = surf.couches_blocs(noyau_c, sv.monde.taille, cc.x * sv.monde.taille, cc.y * sv.monde.taille, nb_c)
		for i_c in lot_gd.blocs.size():
			var a_c: Dictionary = lot_gd.blocs[i_c]
			var b_c: Dictionary = lot_c.blocs[i_c]
			if a_c.keys() != b_c.keys():
				ecarts_c += 1
				continue
			for cle_c in a_c.keys():
				n_val += 1
				var ec: float = absf(float(a_c[cle_c]) - float(b_c[cle_c]))
				pire_c = maxf(pire_c, ec)
				if ec > 0.0:
					ecarts_c += 1
	verifier(n_val > 0 and ecarts_c == 0, "les couches des blocs : %d valeurs, %d écart(s), pire %.9f" % [n_val, ecarts_c, pire_c])
	var ecarts_gen := 0
	var n_gen := 0
	var t_gen_gd := 0
	var t_gen_cpp := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cg := c0 + Vector2i(dx * 2, dy * 2)
			if not surf.terre_a(cg):
				continue
			Surface.noyau_actif = false
			var ta := Time.get_ticks_usec()
			var e_gd: Dictionary = surf.generer_cellule(cg.x, cg.y, {}, true)
			var tb := Time.get_ticks_usec()
			Surface.noyau_actif = true
			var e_cpp: Dictionary = surf.generer_cellule(cg.x, cg.y, {}, true)
			var tc := Time.get_ticks_usec()
			t_gen_gd += tb - ta
			t_gen_cpp += tc - tb
			n_gen += 1
			for cle in ["hauteurs", "sol", "bord", "sols", "eau", "arbres", "plantes", "cueillette", "rochers", "filons", "murs", "portes", "meubles", "biomes_vus"]:
				if e_gd[cle] != e_cpp[cle] or (e_gd[cle] is Dictionary and e_gd[cle].keys() != e_cpp[cle].keys()):
					ecarts_gen += 1
					print("  cellule %s : %s diffère (%d contre %d)" % [str(cg), cle, e_gd[cle].size(), e_cpp[cle].size()])
			if e_gd.village.is_empty() != e_cpp.village.is_empty() or (not e_gd.village.is_empty() and e_gd.village.batiments.size() != e_cpp.village.batiments.size()):
				ecarts_gen += 1
				print("  cellule %s : le village diffère" % str(cg))
	Surface.noyau_actif = true
	verifier(n_gen > 0 and ecarts_gen == 0, "%d cellules de surface : sol, végétation, filons, village — les mêmes par le noyau (GDScript %.0f ms, C++ %.0f ms)" % [n_gen, float(t_gen_gd) / 1000.0, float(t_gen_cpp) / 1000.0])
	sv.monde.fermer()


## LE DANGER SE PÈSE (ordre de travail 24, 2026-09-09). Le champ de danger gradue de 1 à 100 depuis la veille, mais
## les deux chercheurs de chemin refusaient TOUTE valeur non nulle : une tuile graduée 1 barrait autant que la lave,
## et le grade était écrit sans jamais être lu.
## Un test d'égalité entre les deux implémentations ne prouverait rien à lui seul — si toutes deux refusaient tout,
## elles seraient d'accord. Celui-ci demande donc un COMPORTEMENT, sur un terrain plat bâti pour la question : une
## barrière de danger en travers du passage, et l'on regarde où le chemin la franchit.
func test_danger_pese() -> void:
	var s := nouvelle_sim("gorge")
	var regles: Dictionary = s.grille.dep
	var g := Grille.new(25, 11)
	g.dep = regles
	g.hauteur_oeil = s.grille.hauteur_oeil
	var refus: int = int(regles.get("danger_refus", 100))
	var par_grade: int = int(regles.get("danger_cout_par_grade", 100))
	verifier(refus > 1 and par_grade > 0, "les deux nombres du danger sont en données (refus %d, %d ticks le point)" % [refus, par_grade])

	# a. La barrière : grade 20 sur toute la colonne 12, sauf la rangée 5 à 1. Le détour vers la rangée 5 est gratuit
	#    en pas (les diagonales avancent aussi en x), donc le chemin doit franchir PAR la rangée bon marché.
	for y in g.hauteur_grille:
		g.poser_danger(g.idx(Vector2i(12, y)), 1 if y == 5 else 20)
	var depart := Vector2i(2, 0)
	var arrivee := Vector2i(22, 0)
	var c_gd := g._chemin_gd(depart, arrivee)
	verifier(not c_gd.is_empty(), "un chemin franchit une barrière graduée sous le refus (%d tuiles)" % c_gd.size())
	var franchi := -1
	for p in c_gd:
		if p.x == 12:
			franchi = p.y
	verifier(franchi == 5, "il la franchit par la rangée la moins dangereuse (rangée %d, grade %d)" % [franchi, g.danger_de(Vector2i(12, maxi(franchi, 0)))])
	_meme_chemin(g, depart, arrivee, c_gd, "barrière graduée")

	# b. La même barrière à 100 : ce qui tue à coup sûr ne se négocie pas, il n'y a plus de chemin.
	for y in g.hauteur_grille:
		g.poser_danger(g.idx(Vector2i(12, y)), 100)
	var c_mur := g._chemin_gd(depart, arrivee)
	verifier(c_mur.is_empty(), "une barrière au grade du refus reste infranchissable (%d tuiles)" % c_mur.size())
	_meme_chemin(g, depart, arrivee, c_mur, "barrière au refus")

	# c. Grade 20 partout, sans passage bon marché : on paie plutôt que de renoncer.
	for y in g.hauteur_grille:
		g.poser_danger(g.idx(Vector2i(12, y)), 20)
	var c_paye := g._chemin_gd(depart, arrivee)
	verifier(not c_paye.is_empty(), "sans passage bon marché, on paie et l'on traverse (%d tuiles)" % c_paye.size())
	_meme_chemin(g, depart, arrivee, c_paye, "barrière uniforme")

	# d. La tuile d'ARRIVÉE garde son passe-droit : on vise volontairement une tuile dangereuse — c'est ainsi qu'on
	#    entre dans le feu pour l'éteindre, ou qu'on frappe ce qui s'y tient.
	var c_vers = g._chemin_gd(depart, Vector2i(12, 5))
	verifier(not c_vers.is_empty(), "un chemin VERS une tuile dangereuse existe encore (%d tuiles)" % c_vers.size())
	_meme_chemin(g, depart, Vector2i(12, 5), c_vers, "vers le danger")


## Le noyau C++ rend exactement ce que le GDScript rend — sans lui, le test dit que tout se calcule en GDScript.
func _meme_chemin(g: Grille, a: Vector2i, b: Vector2i, attendu: Array[Vector2i], nom: String) -> void:
	if not Grille.noyau_present() or not g._noyau_pret():
		return
	var obtenu: Array[Vector2i] = g._noyau.chemin(g, a, b, false, "", false, 0)
	verifier(obtenu == attendu, "%s : le noyau C++ rend le même chemin (%d contre %d tuiles)" % [nom, obtenu.size(), attendu.size()])


## La régénération rattrapée d'un coup (Mana, 2026-09-06) : après une longue absence, le mana prend son espérance en un
## calcul, pas une tranche à la fois ; en dessous du seuil, tranche par tranche comme avant.
func test_regen_longue() -> void:
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	var r: Dictionary = s.regles.r.mana
	var periode := int(r.periode_ticks)
	var seuil := int(r.get("tranches_exactes", 100))
	j.mana = 0
	j.mana_max = 100000   # assez pour que rien ne plafonne
	j.tick_vigueur = 0
	j["xp_depuis_repos"] = {}
	var tranches := seuil * 100
	var t0 := Time.get_ticks_usec()
	s._regenerer(j, tranches * periode)
	var duree := float(Time.get_ticks_usec() - t0) / 1000.0
	var attendu := int(float(tranches) * float(r.chance))
	var succes := int(j.get("xp_depuis_repos", {}).get("meditation", 0))
	verifier(succes == attendu or succes == attendu + 1, "%d tranches rattrapées d'un coup : %d succès, l'espérance (%d ou %d)" % [tranches, succes, attendu, attendu + 1])
	# L'XP de Méditation recalcule les stats, et le plafond de mana redevient celui de la volonté : le mana est au plafond.
	verifier(int(j.mana) == int(j.mana_max) and int(j.mana) > 0, "le mana rendu est au plafond (%d / %d)" % [int(j.mana), int(j.mana_max)])
	print("  régénération longue : %d tranches en %.2f ms" % [tranches, duree])
	# En dessous du seuil : tranche par tranche, avec le RNG — jamais plus de succès que de tranches, jamais de mana sans succès.
	j.mana = 0
	j.tick_vigueur = 0
	j["xp_depuis_repos"] = {}
	s._regenerer(j, (seuil - 1) * periode)
	var petits := int(j.get("xp_depuis_repos", {}).get("meditation", 0))
	verifier(petits >= 0 and petits <= seuil - 1 and (int(j.mana) > 0) == (petits > 0), "sous le seuil, tranche par tranche : %d succès sur %d" % [petits, seuil - 1])


## Compare le noyau et le GDScript sur `n` paires tirées au sort dans la grille, toutes les fonctions.
func _comparer_noyau(g: Grille, nom: String, n: int) -> void:
	g._noyau_pret()   # les appels directs au noyau ci-dessous ne passent pas par les méthodes publiques : on le prépare (table des contenus, friction)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(nom)
	var libres: Array[Vector2i] = []
	for i in g.largeur * g.hauteur_grille:
		var p := g.pos_de(i)
		if not g.bloque_passage(p):
			libres.append(p)
	if libres.size() < 2:
		verifier(false, "%s : pas assez de tuiles libres" % nom)
		return
	var ecarts := {"chemin": 0, "vue": 0, "obstacle": 0, "cout": 0, "champ": 0, "atteignables": 0}
	var chemins_non_vides := 0
	var t_gd := 0
	var t_cpp := 0
	for k in n:
		var a: Vector2i = libres[rng.randi_range(0, libres.size() - 1)]
		var b: Vector2i = libres[rng.randi_range(0, libres.size() - 1)]
		if k % 2 == 1:   # une cible proche une fois sur deux : des chemins qui aboutissent
			b = a + Vector2i(rng.randi_range(-12, 12), rng.randi_range(-12, 12))
			if not g.dans(b):
				b = a
		var volant := k % 5 == 0
		var eviter := k % 3 == 0
		var max_n := 800 if k % 20 != 0 else 0   # sans budget une fois sur vingt : l'A* fouille toute la grille (192 × 192 : une demi-seconde en GDScript)
		var t0 := Time.get_ticks_usec()
		var c_gd := g._chemin_gd(a, b, volant, "", eviter, max_n)
		var t1 := Time.get_ticks_usec()
		var c_cpp: Array[Vector2i] = g._noyau.chemin(g, a, b, volant, "", eviter, max_n)
		var t2 := Time.get_ticks_usec()
		t_gd += t1 - t0
		t_cpp += t2 - t1
		if c_gd != c_cpp:
			ecarts.chemin += 1
		if not c_gd.is_empty():
			chemins_non_vides += 1
		if g._ligne_de_vue_gd(a, b) != g._noyau.ligne_de_vue(g, a, b):
			ecarts.vue += 1
		if g._premier_obstacle_vue_gd(a, b) != g._noyau.premier_obstacle_vue(g, a, b):
			ecarts.obstacle += 1
		for d in Grille.DIRS:
			if g.cout_pas(a, a + d, volant, eviter) != g._noyau.cout_pas_entre(g, a, a + d, volant, eviter):
				ecarts.cout += 1
		if k % 10 == 0:
			if g._champ_de_vue_gd(a, 12) != g._noyau.champ_de_vue(g, a, 12):
				ecarts.champ += 1
			var at_gd := g._atteignables_gd(a, 30, volant, eviter)
			var at_cpp: Dictionary = g._noyau.atteignables(g, a, 30, volant, eviter)
			if at_gd != at_cpp or at_gd.keys() != at_cpp.keys():
				ecarts.atteignables += 1
	var total := 0
	for cle in ecarts:
		total += int(ecarts[cle])
	verifier(total == 0, "%s : le noyau C++ rend ce que le GDScript rend sur %d paires (%d chemins trouvés) — écarts %s" % [nom, n, chemins_non_vides, str(ecarts)])
	print("  noyau (%s) : %d chemins, GDScript %.1f ms, C++ %.2f ms" % [nom, n, float(t_gd) / 1000.0, float(t_cpp) / 1000.0])


## UNE TUILE TIENT UNE PILE (ordre de travail 26 ter ; designer 2026-09-08 : « les entités peuvent se stack sur la
## même case, un PNJ peut porter un PNJ qui porte un PNJ »). Ce test prouve les quatre règles : on monte sur un ami,
## `occupant` reste le SOMMET (les cent quatre-vingts lecteurs de la grille lisent ça), celui du dessous peut partir
## sans emporter celui du dessus, et un ennemi ne s'escalade pas.
## PORTER N'EST PAS ÊTRE AU MÊME ENDROIT (ordre de travail 26 decies, 2026-09-09). La **pile** est une coïncidence
## de position — trois êtres sur une tuile, chacun libre de partir. **Porter est une relation** : l'un déplace
## l'autre, et l'autre cesse d'occuper une tuile à lui.
## Ce test tient les trois conséquences qui FONT la relation : le porté suit, il n'occupe plus, et il pèse.
func test_porter() -> void:
	var p: Dictionary = GameData.config("combat_rules").deplacement.get("porter", {})
	verifier(not p.is_empty() and float(p.poids_base) > 0.0, "ce que pèse un corps est en données (%.0f + %.0f par point d'endurance)" % [float(p.poids_base), float(p.poids_par_endurance)])
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	var autres: Array = s.vivants().filter(func(x: Dictionary) -> bool: return x.id != j.id)
	verifier(not autres.is_empty(), "l'arène a quelqu'un d'autre")
	var mort: Dictionary = autres[0]
	# UN ENNEMI CONSCIENT NE SE PORTE PAS : on ne l'emporte pas sur l'épaule.
	var colle := s._tuile_libre_autour(j.pos)
	s.grille.liberer(mort.pos, mort.id)
	mort.pos = colle
	s.grille.placer(mort.id, colle)
	verifier(not s.porter(j, mort, 0), "un ennemi conscient refuse d'être porté")
	# UN MORT, TOUJOURS.
	mort.vivant = false
	s.grille.liberer(mort.pos, mort.id)
	s.grille.placer(mort.id, colle)
	var poids0: float = s.poids_de(j).poids
	verifier(s.porter(j, mort, 0), "un mort se charge sur l'épaule")
	verifier(str(mort.get("porte_par", "")) == j.id and str(j.get("porte", "")) == mort.id, "la relation se lit des deux côtés")
	verifier(s.grille.occupant(colle).is_empty(), "et il N'OCCUPE PLUS sa tuile : on ne le vise pas, on ne le contourne pas")
	verifier(s.poids_de(j).poids > poids0, "il PÈSE sur la charge de qui le porte (%.0f → %.0f)" % [poids0, s.poids_de(j).poids])
	# IL SUIT, sans chemin ni décision propre.
	var vers := s._tuile_libre_autour(j.pos)
	var avant_j: Vector2i = j.pos
	verifier(s._deplacer(j, vers, 10) and j.pos != avant_j, "le porteur avance")
	verifier(mort.pos == j.pos, "et le porté suit, à la tuile près — c'est cela, la relation")
	# ON LE REPOSE, et il redevient une chose du monde.
	verifier(s.reposer_porte(j, 20), "on le repose")
	verifier(not j.has("porte") and not mort.has("porte_par") and s.grille.occupant(mort.pos) == mort.id, "il occupe de nouveau une tuile, et la charge retombe")
	verifier(is_equal_approx(s.poids_de(j).poids, poids0), "le porteur retrouve son poids (%.0f)" % s.poids_de(j).poids)


func test_pile_sur_une_tuile() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var g := s.grille
	var h := s.horloge_de(j)
	# Deux compagnons du même camp, l'un à côté de l'autre : personne n'est hostile à personne.
	var a := s.ajouter("villageois", j.pos + Vector2i(2, 0), "ia")
	var b := s.ajouter("villageois", j.pos + Vector2i(3, 0), "ia")
	a.camp = j.camp
	b.camp = j.camp
	var tuile: Vector2i = a.pos
	verifier(g.occupants_de(tuile) == [a.id] and g.etage_pile(tuile, a.id) == 0, "une tuile à un occupant : une pile d'un, au sol")
	# b monte sur a.
	b.compteur = h.ticks
	s.attente[b.id] = true
	verifier(s.intention(b.id, {"type": "deplacer", "vers": tuile}), "on marche sur un ami : le pas est accepté")
	verifier(b.pos == tuile and a.pos == tuile, "les deux êtres sont sur la MÊME tuile (%s)" % str(tuile))
	verifier(g.occupants_de(tuile) == [a.id, b.id], "la pile va du bas vers le haut : %s" % str(g.occupants_de(tuile)))
	verifier(g.occupant(tuile) == b.id and g.etage_pile(tuile, b.id) == 1, "`occupant` rend le SOMMET, et le sommet est à l'étage 1")
	# Celui du DESSOUS s'en va : celui du dessus reste, et redevient le sol de sa tuile.
	a.compteur = h.ticks
	s.attente[a.id] = true
	verifier(s.intention(a.id, {"type": "deplacer", "vers": tuile + Vector2i(0, 1)}), "celui du dessous s'en va")
	verifier(g.occupants_de(tuile) == [b.id] and g.occupant(tuile) == b.id and g.etage_pile(tuile, b.id) == 0, "le dessus reste et redescend au sol")
	verifier(not g.piles.has(g.idx(tuile)), "une tuile revenue à un seul occupant ne coûte plus rien : elle sort des piles")
	# Un ennemi ne s'escalade pas : c'est lui qu'on attaque.
	var loup: Dictionary = s.entites["loup_2"]
	g.liberer(loup.pos, loup.id)
	loup.pos = tuile + Vector2i(2, 0)
	g.placer(loup.id, loup.pos)
	b.compteur = h.ticks
	s.attente[b.id] = true
	verifier(not s.intention(b.id, {"type": "deplacer", "vers": loup.pos}) or b.pos != loup.pos, "un ennemi barre le passage : on ne lui monte pas dessus")
	# La hauteur de pile est en données, et elle borne.
	verifier(int(s.regles.r.deplacement.pile_max) >= 3, "pile_max vaut au moins trois : « un PNJ peut porter un PNJ qui porte un PNJ »")
	# LE CHEMIN TRAVERSE LES AMIS (ordre de travail 26 nonies ; designer 2026-09-08 : « si un PNJ non hostile bloque
	# une porte le joueur peut passer par-dessus »). Le pas passait déjà ; c'est l'ITINÉRAIRE qu'on prouve ici.
	# On bouche l'unique passage d'un couloir avec un ami, puis avec un ennemi.
	# Un couloir d'une seule tuile de large : la tuile du milieu est le SEUL passage, sans avoir besoin de murs
	# (une grille nue n'a pas le catalogue des contenus, et un relief se grimpe depuis le point 56).
	var g2 := Grille.new(9, 1)
	g2.dep = g.dep   # une grille nue n'a pas les règles de déplacement : on lui donne celles de la partie
	for x2 in 9:
		g2.hauteurs[g2.idx(Vector2i(x2, 0))] = 10
	var goulet := Vector2i(4, 0)
	g2.placer("gardien", goulet)
	var libre := g2.chemin(Vector2i(0, 0), Vector2i(8, 0))
	verifier(libre.is_empty(), "sans rien dire, un occupant ferme le goulet : aucun chemin")
	var passe := g2.occ.duplicate()
	passe[g2.idx(goulet)] = 0   # ce gardien-là ne me barre pas : c'est un ami
	var avec := g2.chemin(Vector2i(0, 0), Vector2i(8, 0), false, "", false, 0, passe)
	verifier(not avec.is_empty() and goulet in avec, "avec le miroir, le chemin PASSE par la tuile de l'ami (%d pas)" % avec.size())
	var avec_gd := g2._chemin_gd(Vector2i(0, 0), Vector2i(8, 0), false, "", false, 0, passe)
	verifier(avec == avec_gd, "le noyau C++ et le GDScript rendent le MÊME chemin à travers l'ami")
	var att_a := g2.atteignables(Vector2i(0, 0), 3000, false, false, passe)
	var att_gd := g2._atteignables_gd(Vector2i(0, 0), 3000, false, false, passe)
	verifier(att_a.has(goulet) and att_a == att_gd, "les atteignables franchissent l'ami, noyau et GDScript d'accord (%d tuiles)" % att_a.size())
	verifier(not g2.atteignables(Vector2i(0, 0), 3000).has(Vector2i(8, 0)), "sans le miroir, l'autre bout reste hors d'atteinte")
	# Et le miroir que la simulation construit efface bien les amis, pas les ennemis.
	var bl := s.bloque_pour(j)
	verifier(bl.size() == s.grille.occ.size(), "le miroir a la taille de la grille")
	verifier(int(bl[s.grille.idx(b.pos)]) == 0, "un villageois du même camp n'y barre rien")
	verifier(int(bl[s.grille.idx(loup.pos)]) == 1, "un loup hostile y barre sa tuile")


func test_grille() -> void:
	var s := nouvelle_sim("gorge")
	var g := s.grille
	verifier(g.largeur == 32 and g.hauteur_grille == 32, "arène 32×32 chargée depuis JSON")
	# Rampe sud : 10 → 9 → 8 → 7 : descente = 2 ticks, montée +1 = 5 ticks
	verifier(g.cout_pas(Vector2i(16, 31), Vector2i(16, 30)) == 200, "descente −1 : 200 ticks (2 dixièmes de seconde)")
	verifier(g.cout_pas(Vector2i(16, 30), Vector2i(16, 31)) == 500, "montée +1 : 500 ticks (une demi-seconde)")
	# Rive (10) → fond (7) : Δ−3 = chute, Δ+3 = falaise
	verifier(g.cout_pas(Vector2i(12, 15), Vector2i(13, 15)) == -1, "Δ−3 : pas un pas normal")
	verifier(g.est_chute(Vector2i(12, 15), Vector2i(13, 15)), "Δ−3 : chute autorisée")
	# Δ+3 s'escalade depuis le point 56 : ce n'est plus un mur, c'est un temps à payer.
	var esc_3 := g.cout_pas(Vector2i(13, 15), Vector2i(12, 15))
	verifier(esc_3 > int(GameData.config("combat_rules").deplacement.montee_2), "Δ+3 : escaladé, et bien plus cher qu'une montée (%d ticks)" % esc_3)
	# Un piton fait 8 niveaux : c'était la seule paroi qui demandait de grimper, et la seule qu'on ne
	# pouvait pas grimper (plafond hauteur_max, retiré le 2026-09-01 à la demande du designer).
	var piton := Grille.new(2, 1)
	piton.dep = g.dep
	piton.hauteurs[0] = 4
	piton.hauteurs[1] = 12
	var c_piton := piton.cout_pas(Vector2i(0, 0), Vector2i(1, 0))
	var c_expert := piton.cout_pas(Vector2i(0, 0), Vector2i(1, 0), false, false, {"escalade": 3.0})
	verifier(c_piton > 0, "un piton de 8 niveaux se grimpe (%d ticks)" % c_piton)
	verifier(c_expert < c_piton, "l'escalade récompense la compétence (%d ticks pour l'expert)" % c_expert)
	verifier(g.degats_chute(3) == 5 and g.degats_chute(6) == 20, "dégâts de chute = (h − 2) × 5")
	var synth := Grille.new(3, 1)
	synth.dep = g.dep
	synth.hauteurs[0] = 10
	synth.hauteurs[1] = 12
	synth.hauteurs[2] = 10
	verifier(synth.cout_pas(Vector2i(0, 0), Vector2i(1, 0)) == 800 and synth.cout_pas(Vector2i(1, 0), Vector2i(2, 0)) == 200, "montée +2 : 800 ; descente −2 : 200")
	verifier(g.cout_pas(Vector2i(10, 10), Vector2i(9, 10)) == 500, "rampe du plateau")
	# Ligne de vue : la falaise coupe la vue entre le fond (7) et la rive lointaine
	verifier(not g.ligne_de_vue(Vector2i(16, 15), Vector2i(3, 15)), "le plateau (13) coupe la vue depuis le fond (7)")
	verifier(g.ligne_de_vue(Vector2i(16, 15), Vector2i(16, 20)), "vue dégagée le long de la gorge")
	var chemin := g.chemin(Vector2i(16, 30), Vector2i(16, 3))
	verifier(not chemin.is_empty() and chemin.back() == Vector2i(16, 3), "A* traverse la gorge par le fond")
	var pas_de_chemin := g.chemin(Vector2i(16, 15), Vector2i(3, 15), false)
	var ok := true
	var prev := Vector2i(16, 15)
	for p in pas_de_chemin:
		if g.cout_pas(prev, p) < 0:
			ok = false
		prev = p
	verifier(ok, "A* n'emprunte jamais une falaise ni une chute")
	# Murs de la ruine : bloquent passage et vue
	var r := nouvelle_sim("ruine_a_estrades")
	verifier(r.grille.bloque_passage(Vector2i(10, 9)), "un mur bloque le passage (tile_contents)")
	verifier(not r.grille.ligne_de_vue(Vector2i(10, 5), Vector2i(10, 12)), "un mur coupe la vue")


# ---------------------------------------------------------------- Pipeline de résolution : dés

func test_des() -> void:
	var d := Des.new(7)
	var ok := true
	for i in 200:
		var v := d.jet("2d6")
		if v < 2 or v > 12:
			ok = false
	verifier(ok, "2d6 ∈ [2, 12]")
	verifier(Des.fourchette("3d8") == Vector2i(3, 24), "fourchette 3d8 = [3, 24]")
	verifier(Des.fourchette("1d6", 2) == Vector2i(3, 18), "+2 dés : 3d6")
	verifier(d.jet("5") == 5 and d.jet(null) == 0, "constante et vide")
	var a := Des.new(3)
	var b := Des.new(3)
	verifier(a.jet("2d6") == b.jet("2d6") and a.jet("1d20") == b.jet("1d20"), "déterministe à graine égale")


# ---------------------------------------------------------------- Zones, armure, tempo

func test_regles() -> void:
	var r := Regles.new(GameData.config("combat_rules"))
	verifier(r.zone_de_coup(12, 10).zone == "tete" and r.zone_de_coup(12, 10).mult == 2.5, "plus haut → tête ×2.5")
	verifier(r.zone_de_coup(8, 10).zone == "jambes" and r.zone_de_coup(8, 10).mult == 0.8, "plus bas → jambes ×0.8")
	verifier(r.zone_de_coup(10, 10).zone == "torse", "égal → torse ×1.0")
	var mailles: Dictionary = GameData.entree("items", "proto_cuirasse_mailles")
	verifier(is_equal_approx(r.armure_piece(mailles, "tranchant"), 20.0 / 4.0 * 1.25), "mailles vs tranchant : 5 × 1.25")
	verifier(is_equal_approx(r.armure_piece(mailles, "perforant"), 20.0 / 4.0 * 0.80), "mailles vs perforant : 5 × 0.80")
	verifier(r.armure_piece({}, "tranchant") == 0.0, "zone nue = 0")
	verifier(r.degats_finaux(2.0, 1.0, 10.0, false) == 1, "dégâts finaux minimum 1")
	verifier(r.degats_finaux(10.0, 2.5, 5.0, false) == 20, "(10 × 2.5 − 5) = 20")
	verifier(r.degats_finaux(10.0, 1.0, 0.0, true) == 2, "la garde retire 80 %")
	var att_b := float(GameData.config("combat_rules").actions.attaque_base)
	var f_epee: Dictionary = GameData.entree("functionalities", "epee")
	verifier(r.ticks_attaque(f_epee, false) == roundi(att_b / float(f_epee.vitesse_base)), "épée : %d / %.1f = %d ticks" % [int(att_b), float(f_epee.vitesse_base), r.ticks_attaque(f_epee, false)])
	var f_dague: Dictionary = GameData.entree("functionalities", "dague")
	verifier(r.ticks_attaque(f_dague, false) == roundi(att_b / float(f_dague.vitesse_base)), "dague : %d ticks — et le tick à la milliseconde les dit exactement, là où 3 ticks de 100 ms arrondissaient" % r.ticks_attaque(f_dague, false))
	var f_masse: Dictionary = GameData.entree("functionalities", "masse")
	var mult_l := int(GameData.config("combat_rules").actions.lourde_mult_ticks)
	verifier(r.ticks_attaque(f_masse, true) == roundi(att_b / float(f_masse.vitesse_base)) * mult_l, "masse lourde : %d × %d ticks" % [roundi(att_b / float(f_masse.vitesse_base)), mult_l])
	verifier(r.portee_de(GameData.entree("functionalities", "lance")) == Vector2i(2, 2), "lance : portée [2, 2] (zone morte au contact)")
	verifier(Regles.direction_relative(Vector2i(0, 1), Vector2i(0, 1)) == "front", "coup de face")
	verifier(Regles.direction_relative(Vector2i(0, 1), Vector2i(1, 0)) == "flanc", "coup de flanc")
	verifier(Regles.direction_relative(Vector2i(0, 1), Vector2i(0, -1)) == "dos", "coup dans le dos")
	verifier(r.garde_tient("front", false, false) and not r.garde_tient("flanc", false, false), "garde frontale")
	verifier(r.garde_tient("flanc", true, true) and not r.garde_tient("dos", true, false), "garde-bouclier : front + flancs, tient la lourde")
	verifier(r.cout_garde_impact(20, false) == 17 and r.cout_garde_impact(20, true) == 8, "endurance à l'impact : 12 + d/4 · 6 + d/8")
	verifier(r.sante_max({"endurance": 10}) == 60, "sante_max = 20 + End × 4")


# ---------------------------------------------------------------- Simulation : intentions, compteurs, mort

func test_simulation() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	verifier(not j.is_empty() and j.controle == "joueur" and j.def == "aventurier", "le joueur est un être comme un autre (contrôle = attribut)")
	# Les deux barres ne sont plus des constantes : les PV suivent l'endurance, la vigueur suit la force
	# (designer 2026-09-03, la philosophie des paires). Ce qui compte n'est pas leur valeur mais QUI les
	# fait bouger — un test qui gèle 68 et 100 ne dit rien le jour où la formule change.
	var st_j: Dictionary = j.corps.stats
	var st_f: Dictionary = st_j.duplicate()
	st_f.force = int(st_f.force) + 1
	var st_e: Dictionary = st_j.duplicate()
	st_e.endurance = int(st_e.endurance) + 1
	verifier(j.sante_max == s.regles.sante_max(st_j) and j.vigueur == s.regles.vigueur_max(st_j), "les PV et la vigueur sont ceux des formules, pas des constantes")
	verifier(s.regles.vigueur_max(st_f) > s.regles.vigueur_max(st_j) and s.regles.sante_max(st_f) == s.regles.sante_max(st_j), "+1 Force agrandit la vigueur et ne touche pas aux PV")
	verifier(s.regles.sante_max(st_e) > s.regles.sante_max(st_j) and s.regles.vigueur_max(st_e) == s.regles.vigueur_max(st_j), "+1 Endurance agrandit les PV et ne touche pas à la vigueur")

	# --- la troisième monnaie (designer 2026-09-03) -----------------------------------------------
	# Le sang-froid appartient à la dextérité, qui en dépend, et la perception s'en sert en bonus.
	var st_d: Dictionary = st_j.duplicate()
	st_d.dexterite = int(st_d.dexterite) + 1
	verifier(s.regles.sang_froid_max(st_d) > s.regles.sang_froid_max(st_j), "+1 Dextérité agrandit le sang-froid")
	verifier(int(j.get("sang_froid_max", 0)) == s.regles.sang_froid_max(j.stats_eff), "le personnage naît avec sa barre de sang-froid")
	var plan_sf := s.capacites.assembler(["estoc"], 10, "1d4", {}, j.competences_eff)
	verifier(str(plan_sf.monnaie) == "sang_froid" and int(plan_sf.ressource) > 0, "un noyau de dextérité se paie en sang-froid (%s)" % str(plan_sf.monnaie))
	# Dépenser à vide n'est pas refusé : ça se paie en PV, comme la surchauffe du mana.
	j["sang_froid"] = 0
	var pv_sf: int = int(j.sante)
	s._payer(j, plan_sf)
	verifier(int(j.sante) < pv_sf, "sang-froid à vide : le déficit se paie en PV (%d → %d)" % [pv_sf, int(j.sante)])
	# Et il ne remonte qu'à l'immobilité : c'est l'inverse des deux autres monnaies.
	j["immobile_depuis"] = s.horloge_monde.ticks - 10000
	j.tick_vigueur = s.horloge_monde.ticks
	s._regenerer(j, s.horloge_monde.ticks + 1000)
	verifier(int(j.get("sang_froid", 0)) > 0, "immobile, le sang-froid remonte (%d)" % int(j.get("sang_froid", 0)))

	# --- la perception allonge le tir, et seulement le tir (solution B) ----------------------------
	var arc_f: Dictionary = GameData.entree("functionalities", "arc")
	var epee_f: Dictionary = GameData.entree("functionalities", "epee")
	var vue: Dictionary = {"perception": 20}
	verifier(s.regles.portee_de(arc_f, vue).y > s.regles.portee_de(arc_f).y, "20 de Perception allongent la portée de l'arc")
	verifier(s.regles.portee_de(epee_f, vue).y == s.regles.portee_de(epee_f).y, "voir mieux n'allonge pas le bras : l'épée ne gagne rien")

	# --- l'onde sonore : l'attaque des instruments part du porteur (designer 2026-09-03) -----------
	# Ce qu'on vérifie n'est pas un chiffre de dégâts mais la FORME de l'attaque : deux ennemis dans le
	# rayon perdent des PV pour un seul coup porté, et un troisième hors du rayon n'en perd aucun.
	var cor_f: Dictionary = GameData.entree("functionalities", "cor")
	verifier(int(cor_f.get("attaque_zone", 0)) > int(GameData.entree("functionalities", "cymbales").get("attaque_zone", 0)), "le cor porte plus loin que les cymbales")
	var loups: Array[Dictionary] = []
	for v in s.vivants():
		if v.camp != j.camp:
			loups.append(v)
	if loups.size() >= 2:
		var rayon_c := int(cor_f.get("attaque_zone", 0))
		loups[0].pos = j.pos + Vector2i(1, 0)
		loups[1].pos = j.pos + Vector2i(0, 1)
		# On compte les CORPS ATTEINTS, pas les PV perdus : un coup peut rater, et un test qui lit les
		# dégâts mesure les dés, pas la forme de l'attaque.
		var faux_arme := {"name_key": &"x", "functionality": "cor", "stats": {}}
		verifier(s._onde_sonore(j, loups[0], faux_arme, cor_f, 10) == 1, "l'onde ramasse les autres, pas la cible déjà frappée")
		loups[1].pos = j.pos + Vector2i(rayon_c + 3, 0)
		verifier(s._onde_sonore(j, loups[0], faux_arme, cor_f, 10) == 0, "hors du rayon, l'onde ne touche personne")
	verifier(s.vivants().size() == 4, "1 joueur + 3 loups")
	# Hors combat : le joueur attend une intention dès que l'horloge du monde le rend dû.
	s.horloge_monde.avancer(100)
	verifier(s.attente.has(j.id), "en exploration, le joueur est en attente d'intention")
	var avant: int = j.compteur
	verifier(s.intention(j.id, {"type": "deplacer", "vers": j.pos + Vector2i(0, -1)}), "intention de déplacement acceptée")
	verifier(j.compteur == s.horloge_monde.ticks + 300, "déplacement plat : 300 ticks")
	# UNE TUILE TIENT UNE PILE (designer 2026-09-08, codée le 2026-09-09) : marcher sur un non-hostile met le
	# marcheur AU SOMMET de sa tuile — il ne prend plus sa place, il monte dessus. Un ennemi, lui, barre toujours le
	# passage : c'est lui qu'on attaque, pas qu'on escalade.
	var ami := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	ami.camp = "civil"
	var pos_ami: Vector2i = ami.pos
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "deplacer", "vers": pos_ami}), "marcher sur un PNJ non hostile est accepté")
	verifier(j.pos == pos_ami and ami.pos == pos_ami, "les deux êtres tiennent la MÊME tuile (%s)" % str(j.pos))
	verifier(s.grille.occupants_de(pos_ami) == [ami.id, j.id] and s.grille.occupant(pos_ami) == j.id, "la pile va du bas vers le haut, et `occupant` rend le sommet")
	var hostile := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	s.attente[j.id] = true
	var pos_avant_h: Vector2i = j.pos
	s.intention(j.id, {"type": "deplacer", "vers": hostile.pos})
	verifier(j.pos == pos_avant_h, "un hostile barre toujours le passage")
	# Ce loup-là a fini son office. On le retire de la grille : depuis la pile, poser un être sur une tuile occupée
	# n'ÉCRASE plus l'occupant, il s'empile — et la suite du test pose un second loup exactement ici.
	s.grille.liberer(hostile.pos, hostile.id)
	hostile.vivant = false
	s.attente.erase(j.id)   # le refus n'a pas consommé l'attente : on la rend, l'assertion suivante la teste
	verifier(not s.intention(j.id, {"type": "deplacer", "vers": j.pos + Vector2i(0, -1)}), "pas d'intention hors attente")
	verifier(not s.attente.has(j.id), "intention consommée")
	# Placer un loup adjacent et le faire détecter : combat, horloge dédiée, compteurs rebasés.
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	loup.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(100)
	verifier(s.en_combat(j) and s.en_combat(loup) and loup.horloge == j.horloge, "détection → les deux entités partagent une horloge de combat")
	var hc := s.horloge_de(j)
	verifier(hc.mode == Horloge.Mode.ACTION and s.combats.size() == 1, "l'horloge de combat est en mode action")
	# Le loup a agi (morsure 8 ticks ou attente) ; le joueur devient dû à son tour.
	var pv: int = j.sante
	var n := 0
	while not s.attente.has(j.id) and n < 20:
		s.pas(j.horloge)
		n += 1
	verifier(s.attente.has(j.id), "en combat, l'horloge s'arrête sur le joueur")
	# Frappe à l'épée : 5 ticks, 8 d'endurance, PV du loup diminuent.
	var pv_loup: int = loup.sante
	var end: int = j.vigueur
	verifier(s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "attaque à l'épée acceptée")
	verifier(loup.sante < pv_loup, "le loup a perdu des PV")
	var t_epee: int = s.regles.ticks_attaque(s.fonctionnalites[Etres.arme(j, s.items).functionality], false, Etres.arme(j, s.items))
	verifier(j.compteur == hc.ticks + t_epee, "épée assemblée : %d ticks (le manche décide de la vitesse)" % t_epee)
	verifier(j.vigueur <= end - 8 + 2 * 20, "l'attaque coûte 8 d'endurance")
	# Tuer le loup : creature_killed, tuile libérée.
	var tue := [false]
	EventBus.creature_killed.connect(func(id: String, _t: String) -> void: if id == loup.id: tue[0] = true)
	loup.sante = 1
	var garde_fou := 200
	while loup.vivant and garde_fou > 0:
		garde_fou -= 1
		if s.attente.has(j.id):
			if Grille.distance(j.pos, loup.pos) != 1:   # on ramène le loup au contact
				s.grille.liberer(loup.pos)
				loup.pos = j.pos + Vector2i(1, 0)
				s.grille.placer(loup.id, loup.pos)
			s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
		else:
			s.pas(j.horloge)
	verifier(not loup.vivant and tue[0] and s.grille.occupant(loup.pos).is_empty(), "mort : creature_killed émis, tuile libérée")


# ---------------------------------------------------------------- Garde, lourde, endurance, attendre

func test_garde_et_lourde() -> void:
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	var bandit: Dictionary = s.entites["bandit_3"]
	# Isoler : le bandit face au joueur, en combat.
	s.grille.liberer(bandit.pos)
	bandit.pos = j.pos + Vector2i(0, -1)
	s.grille.placer(bandit.id, bandit.pos)
	s._engager_combat(j, bandit)
	var h := s.horloge_de(j)
	j.compteur = h.ticks
	bandit.compteur = h.ticks + 10000
	s.pas(j.horloge)
	verifier(s.attente.has(j.id), "le joueur est dû")
	j.orientation = Vector2i(0, -1)   # face au bandit
	verifier(s.intention(j.id, {"type": "garde"}), "prendre la garde")
	verifier(j.garde and j.compteur == h.ticks + 200, "garde : 2 ticks, posture active")
	# Le bandit frappe de face : la garde tient, −80 %, endurance à l'impact.
	var coups: Array = []
	EventBus.damage_dealt.connect(func(_s: String, c: String, _d: int, detail: Dictionary) -> void: if c == j.id: coups.append(detail))
	var pv: int = j.sante
	var end: int = j.vigueur
	bandit.compteur = h.ticks
	s.pas(j.horloge)
	var perdu: int = pv - j.sante
	verifier(coups.size() == 1 and coups[0].garde and coups[0].direction == "front", "de face, la garde tient (perdu %d)" % perdu)
	verifier(j.vigueur < end, "la garde coûte de l'endurance à l'impact")
	verifier(j.garde, "la garde dure jusqu'à la prochaine action")
	# Une attaque de flanc ignore la garde.
	s.grille.liberer(bandit.pos)
	bandit.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(bandit.id, bandit.pos)
	bandit.compteur = h.ticks
	j.compteur = h.ticks + 10000
	pv = j.sante
	s.pas(j.horloge)
	verifier(coups.size() == 2 and not coups[1].garde and coups[1].direction == "flanc", "de flanc, la garde est ignorée (perdu %d)" % (pv - j.sante))
	# Attaque lourde du joueur : télégraphée (engagée, résolue à l'échéance), ×2 ticks, brise la garde.
	j.compteur = h.ticks
	bandit.compteur = h.ticks + 10000
	bandit.garde = true
	bandit.orientation = Vector2i(-1, 0)
	s.pas(j.horloge)
	var engagee := [false]
	EventBus.action_engaged.connect(func(id: String, _a: Dictionary) -> void: if id == j.id: engagee[0] = true)
	verifier(s.intention(j.id, {"type": "attaquer", "cible": bandit.id, "lourde": true}), "attaque lourde acceptée")
	var t_lourde: int = s.regles.ticks_attaque(s.fonctionnalites[Etres.arme(j, s.items).functionality], true, Etres.arme(j, s.items))
	verifier(engagee[0] and not j.action_en_cours.is_empty() and j.compteur == h.ticks + t_lourde, "lourde : engagée, télégraphée, %d ticks (arme assemblée)" % t_lourde)
	var pvb: int = bandit.sante
	s.pas(j.horloge)   # résolution à l'échéance
	verifier(j.action_en_cours.is_empty() and bandit.sante < pvb, "la lourde se résout à l'échéance")
	verifier(not bandit.garde, "la lourde brise la garde")
	# Attendre : 5 ticks, +20 d'endurance.
	j.vigueur = 10
	j.compteur = h.ticks
	bandit.compteur = h.ticks + 10000
	s.pas(j.horloge)
	var t: int = h.ticks
	verifier(s.intention(j.id, {"type": "attendre"}), "attendre")
	verifier(j.vigueur == 30 and j.compteur == t + 500, "attendre : +20 endurance, 500 ticks")
	# À zéro d'endurance : garde impossible.
	j.vigueur = 0
	j.tick_vigueur = h.ticks + 10000
	j.compteur = h.ticks + 500
	s.pas(j.horloge)
	verifier(not s.intention(j.id, {"type": "garde"}), "à zéro d'endurance, garde impossible")


# ---------------------------------------------------------------- Temporalités parallèles

func test_horloges() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	s.horloge_monde.avancer(5000)
	verifier(s.horloge_monde.ticks == 5000, "l'horloge du monde avance en temps réel")
	var loup: Dictionary = s.entites["loup_2"]
	s._engager_combat(j, loup)
	var hc := s.horloge_de(j)
	verifier(hc.ticks == 0 and hc.nom.begins_with("combat_"), "un combat naît avec sa propre horloge à 0")
	s.horloge_monde.avancer(10000)
	verifier(hc.ticks == 0, "le combat est hors du temps du monde")
	loup.sante = 0
	loup.vivant = false
	s._verifier_desengagements()
	verifier(not s.en_combat(j) and s.combats.is_empty(), "plus d'hostile : retour à l'horloge du monde")
	verifier(j.compteur >= s.horloge_monde.ticks, "compteur rebasé sur l'horloge du monde")


# ---------------------------------------------------------------- Les trois arènes, jouées par un automate

func test_wuxing() -> void:
	var w := WuXing.new(GameData.config("wuxing"))
	verifier(w.multiplicateur({"bois": 1.0}, {"terre": 1.0}) == 1.5, "Bois domine Terre : ×1.5")
	verifier(w.multiplicateur({"terre": 1.0}, {"bois": 1.0}) == 0.65, "Terre dominée par Bois : ×0.65")
	verifier(w.multiplicateur({"bois": 1.0}, {"feu": 1.0}) == 0.8, "Bois engendre Feu : ×0.8")
	verifier(w.multiplicateur({"bois": 1.0}, {"metal": 1.0}) == 0.65 and w.multiplicateur({"metal": 1.0}, {"bois": 1.0}) == 1.5, "Métal tranche Bois")
	verifier(w.multiplicateur({"bois": 1.0}, {"eau": 1.0}) == 1.0, "Bois vs Eau : neutre (l'eau nourrit le bois, pas l'inverse)")
	verifier(is_equal_approx(w.multiplicateur({"metal": 0.75, "bois": 0.25}, {"bois": 1.0}), 0.75 * 1.5 + 0.25 * 0.1 * 10), "vecteur mixte : moyenne pondérée (0.75×1.5 + 0.25×0.10×10)")
	verifier(w.multiplicateur({"bois": 1.0}, {"terre": 1.0}, "defensif") == 1.2, "défensif compressé : ×1.20")
	verifier(w.multiplicateur({}, {"terre": 1.0}) == 1.0 and w.multiplicateur({"bois": 1.0}, null) == 1.0, "sans vecteur : ×1.0")
	verifier(w.dominante({"metal": 0.75, "bois": 0.25}) == "metal", "dominante")
	# Jauge : rotation parfaite → ×2.40 au 5e acte
	var j := w.jauge_neuve()
	var t := 0
	for el in ["bois", "feu", "terre", "metal"]:
		w.poser(j, el, t)
		t += 5
	verifier(j.segments.size() == 4, "4 segments posés")
	var p := w.prevoir(j, "eau")
	var be: float = float(w.w.chaine.bonus_engendrement)
	verifier(p.resout and is_equal_approx(p.bonus_total, 4.0 * be) and is_equal_approx(p.multiplicateur, 1.0 + 4.0 * be), "rotation parfaite : 4 × engendrement (%.2f) → ×%.2f" % [be, 1.0 + 4.0 * be])
	verifier(is_equal_approx(p.gain, 1.20), "gain intermédiaire : +5 %% × 4 segments")
	w.poser(j, "eau", t)
	verifier(j.segments.is_empty(), "le résolveur vide la barre")
	# Construction / détonation : 4 × même élément puis l'engendré → +0.65 → ×1.65
	j = w.jauge_neuve()
	for i in 4:
		w.poser(j, "metal", i * 3)
	p = w.prevoir(j, "eau")
	var bm: float = float(w.w.chaine.bonus_meme_element)
	verifier(p.resout and is_equal_approx(p.multiplicateur, 1.0 + 3.0 * bm + be), "construction/détonation : 3 × même élément + engendrement → ×%.2f" % (1.0 + 3.0 * bm + be))
	verifier(is_equal_approx(w.prevoir(j, "feu").multiplicateur, 1.0 + 3.0 * bm + float(w.w.chaine.bonus_hors_ordre)), "hors ordre : 3 × même élément + hors ordre")
	# Décroissance : un segment tous les 30 ticks, le dernier posé en premier
	j = w.jauge_neuve()
	w.poser(j, "bois", 0)
	var dec_w := int(GameData.config("wuxing").chaine.decroissance_ticks)
	w.poser(j, "feu", dec_w / 3)
	w.decroitre(j, dec_w / 3 + dec_w - 100)
	verifier(j.segments.size() == 2, "à %d ticks du dernier segment : rien ne tombe" % (dec_w - 100))
	w.decroitre(j, dec_w / 3 + dec_w)
	verifier(j.segments.size() == 1 and j.segments[0].element == "bois", "à %d ticks : le dernier posé tombe" % dec_w)
	w.decroitre(j, 2 * dec_w + dec_w / 3)
	verifier(j.segments.is_empty(), "à %d ticks : la barre est vide" % (2 * dec_w))
	verifier(w.interrompre(j) == false, "interrompre une barre vide : rien")
	# En simulation : l'aventurier porte une jauge (chain_gauge), un loup non ; un coup qui touche pose un segment
	var s := nouvelle_sim("plaine_au_talus")
	var joueur := joueur_de(s)
	var loup: Dictionary = s.entites["loup_2"]
	verifier(joueur.has("chaine") and not loup.has("chaine"), "jauge : le joueur (fiche chain_gauge) oui, le loup non")
	s.grille.liberer(loup.pos)
	loup.pos = joueur.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	s._engager_combat(joueur, loup)
	joueur.compteur = 0
	loup.compteur = 500
	s.pas(joueur.horloge)
	var pv: int = loup.sante
	s.intention(joueur.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	verifier(joueur.chaine.segments.size() == 1 and joueur.chaine.segments[0].element == "metal", "l'épée (Métal) pose un segment Métal")
	verifier(loup.sante < pv, "Métal tranche Bois : le loup (Bois) a pris des dégâts ×1.5")


# ---------------------------------------------------------------- Râtelier et bouclier

func test_ratelier() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	s.horloge_monde.avancer(100)
	verifier(s.attente.has(j.id), "joueur dû")
	var t: int = s.horloge_monde.ticks
	# Tout l'équipement est assemblé (designer 2026-09-02) : le râtelier porte des UID, pas des ids de
	# catalogue — on retrouve chaque pièce par sa fonctionnalité.
	var du_ratelier := func(fonct: String) -> String:
		for uid in j.ratelier:
			var it: Dictionary = s.items.get(str(uid), {})
			if str(it.get("functionality", "")) == fonct or str(it.get("type", "")) == fonct:
				return str(uid)
		return ""
	var masse: String = du_ratelier.call("masse")
	var bouclier: String = du_ratelier.call("bouclier")
	var lance: String = du_ratelier.call("lance")
	verifier(not masse.is_empty() and not bouclier.is_empty() and not lance.is_empty(), "le râtelier porte une masse, un bouclier et une lance")
	verifier(s.intention(j.id, {"type": "changer_arme", "item": masse}), "prendre la masse")
	var ts: int = int(s.regles.r.actions.changer_arme)
	verifier(j.equipement.main_principale == masse and j.compteur == t + ts, "swap : %d ticks (combat_rules)" % ts)
	j.compteur = t
	s.horloge_monde.avancer(100)
	verifier(s.intention(j.id, {"type": "changer_arme", "item": bouclier}), "prendre le bouclier")
	verifier(j.equipement.get("main_secondaire", "") == bouclier, "bouclier en main secondaire")
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(100)
	verifier(s.intention(j.id, {"type": "changer_arme", "item": lance}), "prendre la lance (deux mains)")
	verifier(not j.equipement.has("main_secondaire"), "une arme à deux mains range le bouclier")
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(100)
	verifier(not s.intention(j.id, {"type": "changer_arme", "item": bouclier}), "pas de bouclier avec une arme à deux mains")
	verifier(not s.intention(j.id, {"type": "changer_arme", "item": "inconnu"}), "objet hors râtelier refusé")


# ---------------------------------------------------------------- Modules : assemblage, mana, formes

func test_capacites() -> void:
	var cap := Capacites.new(GameData.catalogues["modules"])
	# L'exemple chiffré de la note Modules : [Ligne] + [Flamme] + [Concentration] = 12 ticks, 12 mana, 3d6
	var p := cap.assembler(["ligne", "flamme", "concentration"], 5, "2d6", {"metal": 1.0})
	verifier(p.erreurs.is_empty() and p.ticks == 1200 and p.monnaie == "mana" and p.ressource == 12, "[Ligne]+[Flamme]+[Concentration] : 12 ticks · 12 mana")
	verifier(p.des == "2d6" and p.des_bonus == 2 and p.geometrie == "ligne" and p.taille == 4 and p.elements == {"feu": 1.0}, "4d6 de Feu sur 4 tuiles en ligne (Flamme, palier moyen : +1 dé ; Concentration : +1)")
	# [Ligne] + [Frappe] + [Concentration] avec une épée : 9 ticks · 10 endurance, à l'élément de l'arme
	p = cap.assembler(["ligne", "frappe", "concentration"], 5, "2d6", {"metal": 1.0})
	verifier(p.ticks == 900 and p.monnaie == "vigueur" and p.ressource == 10 and p.elements == {"metal": 1.0}, "[Ligne]+[Frappe]+[Concentration] : 9 ticks · 10 vigueur · Métal")
	# Vivacité : −3 ticks, ressource ×1.3 ; Soi rend 2 ticks
	p = cap.assembler(["point", "etincelle", "vivacite"], 5, "1d4", {})
	verifier(p.ticks == 1 and p.ressource == 4, "Étincelle + Vivacité : max(1, 3−3) tick · 3×1.3 ≈ 4 mana")
	p = cap.assembler(["soi", "baume"], 5, "1d4", {})
	verifier(p.ticks == 600 and p.ressource == 10 and p.geometrie == "soi", "[Soi]+[Baume] : 600 ticks · 10 mana")
	var deux := cap.assembler(["ligne", "flamme", "gel"], 5, "1d4", {})
	verifier(deux.erreurs.is_empty() and deux.charges_sup.size() == 1 and deux.ressource == 16, "deux noyaux : aucune limite, chacun paie (8 + 8 = %d mana)" % deux.ressource)
	verifier(Capacites.lire_surcout("×1.3").mult == 1.3 and Capacites.lire_surcout("−2").plus == -2, "lecture des surcoûts")
	# Formes : la ligne de 4, le cône qui s'élargit, le carré plein
	var s := nouvelle_sim("plaine_au_talus")
	var g := s.grille
	verifier(Capacites.tuiles_de_forme(g, "ligne", Vector2i(10, 10), Vector2i(10, 5), 4).size() == 4, "ligne : 4 tuiles")
	verifier(Capacites.tuiles_de_forme(g, "cone", Vector2i(10, 10), Vector2i(10, 5), 3).size() == 1 + 3 + 5, "cône : 1 + 3 + 5 tuiles")
	verifier(Capacites.tuiles_de_forme(g, "carre", Vector2i(10, 10), Vector2i(15, 15), 1).size() == 9, "carré r1 : 9 tuiles, centre compris")
	verifier(Capacites.tuiles_de_forme(g, "anneau", Vector2i(10, 10), Vector2i(15, 15), 1).size() == 8, "anneau r1 : 8 tuiles, sans le centre")
	# En simulation : Étincelle coûte 3 mana et 3 ticks, pose un segment Feu ; le loup (Bois) en prend ×0.8 (engendré)
	var j := joueur_de(s)
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(0, -3)
	s.grille.placer(loup.id, loup.pos)
	s._engager_combat(j, loup)
	var h := s.horloge_de(j)
	loup.compteur = 500
	j.compteur = h.ticks
	s.pas(j.horloge)
	var mana: int = j.mana
	var pv: int = loup.sante
	verifier(s.intention(j.id, {"type": "capacite", "index": 0, "cible": loup.pos}), "lancer Étincelle sur le loup à 3 tuiles")
	# Le sort de l'aventurier porte maintenant sa portée en module (point 70) : ses ticks sont ceux du plan.
	var ticks_e: int = int(s.plan_capacite(j, 0).ticks)
	verifier(j.mana < mana and j.mana >= mana - 6 and j.compteur == h.ticks + ticks_e, "Étincelle : 3 mana ± le jet de coût (%d payés), %d ticks avec sa portée" % [mana - j.mana, ticks_e])
	verifier(loup.sante < pv and j.chaine.segments.size() == 1 and j.chaine.segments[0].element == "feu", "le loup est touché, un segment Feu est posé")
	# Hors de portée (Point : 1-6) : refusé
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(not s.intention(j.id, {"type": "capacite", "index": 0, "cible": j.pos + Vector2i(0, -8)}), "au-delà de 6 tuiles : refusé")
	# Surchauffe : sans mana, Gel en ligne (12 mana) coûte le déficit × 2 en PV
	j.mana = 4
	var pvj: int = j.sante
	verifier(s.intention(j.id, {"type": "capacite", "index": 1, "cible": j.pos + Vector2i(0, -1)}), "Gel en ligne sans assez de mana")
	verifier(j.mana == 0 and j.sante < pvj and (pvj - j.sante) % 2 == 0, "surchauffe : le déficit × 2 en PV (%d)" % (pvj - j.sante))
	verifier(not j.action_en_cours.is_empty(), "12 ticks : la capacité est télégraphée (engagée)")
	# Baume sur soi : soigne
	j.compteur = h.ticks
	j.action_en_cours = {}
	s.pas(j.horloge)
	j.mana = 50
	var avant: int = j.sante
	verifier(s.intention(j.id, {"type": "capacite", "index": 2, "cible": j.pos}), "Baume sur soi")
	verifier(j.sante > avant, "le Baume soigne")
	# Une condition fausse ne part pas et rend 50 % des ticks
	_capacite_test(s, j, "t", ["surplomb", "point", "etincelle"])
	j.compteur = h.ticks
	s.pas(j.horloge)
	mana = j.mana
	var t: int = h.ticks
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loup.pos}), "Surplomb + Étincelle à hauteur égale")
	# Les ticks du plan dépendent de ses modules (la portée en est un depuis le 2026-09-01) : on compare
	# à la moitié des ticks du plan, pas à un chiffre écrit à la main.
	var ticks_t: int = int(s.plan_capacite(j, 3).ticks)
	verifier(j.mana == mana and j.compteur == t + maxi(1, roundi(float(ticks_t) * 0.5)), "condition fausse : ne part pas, 50 %% des ticks (%d → %d), rien payé" % [ticks_t, j.compteur - t])
	# Friendly fire : un carré touche un allié dans la zone
	for m0 in ["carre", "flamme", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["carre", "flamme", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "c", "name_key": "capacite.etincelle.name", "modules": ["carre", "jet_court", "flamme"]}
	var allie := s.ajouter("bandit", j.pos + Vector2i(1, -2), "joueur")
	allie.camp = "joueur"
	var pva: int = allie.sante
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": j.pos + Vector2i(0, -2)}), "Flamme en carré (12 ticks : télégraphée)")
	s.pas(j.horloge)   # l'échéance : la charge part
	verifier(allie.sante < pva, "friendly fire : l'allié dans le carré est touché")


# ---------------------------------------------------------------- Projectiles (Décision — Projectiles)

func test_projectiles() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	verifier(j.munitions == 20, "20 flèches au carquois")
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(0, -5)
	s.grille.placer(loup.id, loup.pos)
	s._engager_combat(j, loup)
	var h := s.horloge_de(j)
	loup.compteur = 500
	for autre in ["loup_3", "loup_4"]:
		s.entites[autre].compteur = 500
	j.compteur = h.ticks
	s.pas(j.horloge)
	var arc_uid := ""
	for uid_a in j.ratelier:
		if str(s.items.get(str(uid_a), {}).get("functionality", "")) == "arc":
			arc_uid = str(uid_a)
			break
	s.intention(j.id, {"type": "changer_arme", "item": arc_uid})
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "tir à l'arc à 5 tuiles")
	verifier(j.munitions == 19 and j.munitions_tirees == 1, "une flèche consommée")
	# Le coût en ticks était écrit en dur à 7. Or la vitesse d'une arme ASSEMBLÉE dépend aussi de la
	# densité de son manche (`vitesse_facteur`) — donc de la matière tirée au butin. Changer l'échelle
	# de fréquence des matières par emplacement (2026-09-03) a suffi à le faire tomber, alors que RIEN
	# n'était faux : c'est le huitième test à valeur figée que je convertis. Ce qu'on vérifie, c'est que
	# le tir a bien payé le prix de CET arc-là, et que la formule de l'arme lente est respectée.
	var arc_it: Dictionary = s.items.get(arc_uid, {})
	var fonct_arc: Dictionary = s.fonctionnalites.get(str(arc_it.get("functionality", "")), {})
	var attendu_arc := s.regles.ticks_attaque(fonct_arc, false, arc_it)
	verifier(j.compteur == h.ticks + attendu_arc, "arc : le tir coûte les ticks de CET arc (%d, base %d / vitesse %.1f)" % [attendu_arc, int(s.regles.r.actions.attaque_base), float(fonct_arc.vitesse_base)])
	verifier(attendu_arc > s.regles.ticks_attaque(s.fonctionnalites.get("dague", {}), false, {}), "et l'arc reste plus lent que la dague")
	# À portée 1 : le tir est impossible (portée minimale 2)
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(0, -1)
	s.grille.placer(loup.id, loup.pos)
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(not s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "arc au contact : refusé")
	# Un allié sur la trajectoire masque la cible : refusé, la tuile bloquante est désignée
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(0, -6)
	s.grille.placer(loup.id, loup.pos)
	var allie := s.ajouter("bandit", j.pos + Vector2i(0, -3), "joueur")
	verifier(not s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "un allié masque : tir refusé")
	var tir := s.verifier_tir(j, loup)
	verifier(not tir.ok and tir.raison == "allie" and tir.bloqueur == allie.pos, "l'UI connaît la tuile bloquante")
	# Un ennemi sur la trajectoire prend la flèche
	s.grille.liberer(allie.pos)
	allie.vivant = false
	var loup3: Dictionary = s.entites["loup_3"]
	s.grille.liberer(loup3.pos)
	loup3.pos = j.pos + Vector2i(0, -3)
	s.grille.placer(loup3.id, loup3.pos)
	var pv3: int = loup3.sante
	verifier(s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "tir avec un ennemi sur la trajectoire")
	verifier(loup3.sante < pv3, "l'ennemi interposé prend la flèche")
	# Sans munitions : refusé ; en fin de combat, 50 % des flèches tirées reviennent (arrondi bas)
	j.munitions = 0
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(not s.intention(j.id, {"type": "attaquer", "cible": loup3.id, "lourde": false}), "sans flèche : refusé")
	j.munitions_tirees = 3
	for id in ["loup_2", "loup_3", "loup_4"]:
		s.entites[id].sante = 0
		s.entites[id].vivant = false
	s._verifier_desengagements()
	verifier(j.munitions == 1 and not s.en_combat(j), "fin de combat : floor(3 × 0.5) = 1 flèche récupérée")
	verifier(s.dernier_combat.victoire and s.dernier_combat.ticks == h.ticks, "récapitulatif du combat : victoire, durée en ticks")
	# La lance n'est pas un projectile (Décision — Projectiles, 2026-08-31) : zone morte, mais ni munition ni trajectoire
	var lance_o: Dictionary = s.generer_objet("craft_lance", 1, {}, "commun", 0)
	verifier(not lance_o.is_empty(), "une lance générée")
	j.sac.append(lance_o.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "equiper", "objet": lance_o.uid}), "la lance en main")
	var loup2b: Dictionary = s.entites["loup_2"]
	loup2b.vivant = true
	loup2b.sante = 10
	s.grille.liberer(loup2b.pos)
	loup2b.pos = j.pos + Vector2i(0, -2)
	s.grille.placer(loup2b.id, loup2b.pos)
	j.munitions = 0
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "attaquer", "cible": loup2b.id, "lourde": false}), "lance à 2 tuiles, 0 munition : le coup part")
	s.grille.liberer(loup2b.pos)
	loup2b.pos = j.pos + Vector2i(0, -1)
	s.grille.placer(loup2b.id, loup2b.pos)
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(not s.intention(j.id, {"type": "attaquer", "cible": loup2b.id, "lourde": false}), "lance au contact : zone morte (portee_min 2)")


# ---------------------------------------------------------------- Statuts, anti-stunlock, interruption, XP

func test_statuts() -> void:
	var s := nouvelle_sim("ruine_a_estrades")
	var j := joueur_de(s)
	var chef: Dictionary = s.entites["chef_de_bande_2"]
	s.grille.liberer(chef.pos)
	chef.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(chef.id, chef.pos)
	s._engager_combat(j, chef)
	var h := s.horloge_de(j)
	for e in s.vivants():
		e.compteur = 500
	j.compteur = h.ticks
	# Poison : 1d3 par 10 ticks pendant 50 ticks — tiqué en fin de pas
	verifier(s.appliquer_statut(j, "poison", 5000, chef.id), "poison appliqué")
	var pv: int = j.sante
	chef.compteur = h.ticks + 1000
	j.compteur = h.ticks + 10000
	s.pas(j.horloge)   # le chef agit à t+10 : le poison tique
	verifier(j.sante < pv and j.statuts.size() == 1, "le poison fait des dégâts périodiques")
	# Anti-stunlock : un contrôle dur est plafonné à 20 ticks, puis verrouillé 50 ticks
	verifier(s.appliquer_statut(j, "enracinement", 4000, chef.id), "enracinement appliqué")
	var enr: Dictionary = j.statuts.back()
	verifier(int(enr.fin) - h.ticks <= 2000, "contrôle dur plafonné à 2000 ticks (deux secondes)")
	verifier(not s.appliquer_statut(j, "etourdi", 1000, chef.id), "réapplication refusée (verrou 50 ticks)")
	verifier(int(j.anti_stunlock_jusqua) == h.ticks + 2000 + 5000, "verrou = fin + 5000")
	# Enraciné : le déplacement est refusé
	j.compteur = h.ticks
	chef.compteur = h.ticks + 50000
	s.pas(j.horloge)
	verifier(not s.intention(j.id, {"type": "deplacer", "vers": j.pos + Vector2i(0, 1)}), "enraciné : pas de déplacement")
	verifier(s.intention(j.id, {"type": "attendre"}), "mais on peut attendre")
	# Interruption : le chef (élite, jauge) engage une lourde ; Étourdi coupe l'action et retire un segment
	chef.chaine.segments = [{"element": "metal", "tick": h.ticks}, {"element": "eau", "tick": h.ticks}]
	chef.chaine.tick_ref = h.ticks
	chef.anti_stunlock_jusqua = -1
	chef.action_en_cours = {"type": "arme", "cible": j.id, "lourde": true, "ticks": 10, "name_key": "x"}
	verifier(s.appliquer_statut(chef, "etourdi", 1000, j.id), "Étourdi sur le chef")
	verifier(chef.action_en_cours.is_empty() and chef.chaine.segments.size() == 1, "interruption : action coupée, dernier segment retiré")
	# Ralliement : ×1.15 dégâts ; Ralentissement : coûts ticks ×1.3
	s.appliquer_statut(j, "ralentissement", 3000, chef.id)
	j.compteur = h.ticks
	s.pas(j.horloge)
	var t: int = h.ticks
	j.statuts = j.statuts.filter(func(x: Dictionary) -> bool: return x.id != "enracinement")
	verifier(s.intention(j.id, {"type": "deplacer", "vers": j.pos + Vector2i(0, 1)}), "déplacement ralenti")
	verifier(j.compteur == t + 390, "300 ticks × 1.3 = 390")
	# XP des trois pistes : un coup d'épée sur le chef verse aux pistes métal / epee / tranchant
	j.statuts.clear()
	s.grille.liberer(j.pos)
	j.pos = chef.pos + Vector2i(0, 1)
	s.grille.placer(j.id, j.pos)
	j.compteur = h.ticks
	s.pas(j.horloge)
	var pvc: int = chef.sante
	verifier(s.intention(j.id, {"type": "attaquer", "cible": chef.id, "lourde": false}), "coup d'épée")
	var perdu: int = pvc - chef.sante
	verifier(int(j.xp.element.get("metal", 0)) == perdu and int(j.xp.competence.get("epee", 0)) == perdu and int(j.xp.type.get("tranchant", 0)) == perdu, "XP = dégâts appliqués, trois pistes")
	verifier(int(chef.xp.construction.get("mailles", 0)) >= 0, "l'armure du chef gagne ce qu'elle épargne")
	# Un statut par module : Feinte annule la garde 15 ticks
	chef.garde = true
	_capacite_test(s, j, "f", ["point", "feinte"])
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": chef.pos}), "Feinte")
	verifier(Etres.bloque_statuts(chef, "garde", s.statuts_defs), "garde annulée par la Feinte")


# ---------------------------------------------------------------- Liaisons et déclencheurs

func test_liaisons() -> void:
	var cap := Capacites.new(GameData.catalogues["modules"])
	var p := cap.assembler(["point", "etincelle", "a_l_impact", "croix", "bruine"], 5, "1d4", {})
	verifier(p.erreurs.is_empty() and p.charge_suivante.declencheur == "impact" and p.charge_suivante.geometrie == "croix", "À l'impact encapsule [Croix]+[Bruine]")
	verifier(p.ticks == 300 + 100 + (300 + 300) and p.ressource == 3 and p.charge_suivante.ressource == 3, "ticks : 3 + 1 + 6 ; chaque charge paie son mana")
	p = cap.assembler(["point", "flamme", "repetition"], 5, "1d4", {})
	verifier(p.ticks == 1200 and p.liaisons.size() == 1 and p.liaisons[0].rejoue == 2, "[Point]+[Flamme]+[Répétition] : 12 ticks, rejoue 2 fois")
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var loups: Array[Dictionary] = [s.entites["loup_2"], s.entites["loup_3"], s.entites["loup_4"]]
	var positions := [Vector2i(0, -3), Vector2i(1, -4), Vector2i(-1, -3)]
	for i in 3:
		s.grille.liberer(loups[i].pos)
		loups[i].pos = j.pos + positions[i]
		s.grille.placer(loups[i].id, loups[i].pos)
		loups[i].compteur = 500
		loups[i].sante = 400
		loups[i].sante_max = 400
	s._engager_combat(j, loups[0])
	var h := s.horloge_de(j)
	j.mana = 200
	var coups := [0]
	EventBus.damage_dealt.connect(func(src: String, _c: String, _d: int, _det: Dictionary) -> void: if src == j.id: coups[0] += 1)
	# Répétition : trois applications sur la même cible
	_capacite_test(s, j, "r", ["point", "flamme", "repetition"])
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Flamme + Répétition (12 ticks : télégraphée)")
	s.pas(j.horloge)
	verifier(coups[0] == 3 and j.chaine.segments.size() == 1, "3 coups appliqués, un seul segment")
	# À l'impact : Étincelle touche, puis la Bruine en croix part de la cible et touche le loup voisin
	coups[0] = 0
	for m0 in ["point", "etincelle", "a_l_impact", "croix", "bruine", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["point", "etincelle", "a_l_impact", "croix", "bruine", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "i", "name_key": "capacite.etincelle.name", "modules": ["point", "jet_court", "etincelle", "a_l_impact", "croix", "bruine"]}
	j.compteur = h.ticks
	j.action_en_cours = {}
	s.pas(j.horloge)
	var pv2: int = loups[2].sante
	var seg_avant: int = j.chaine.segments.size()
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Étincelle → À l'impact → Croix + Bruine")
	s.pas(j.horloge)   # la portée en module ajoute des ticks : le sort est télégraphié, il part au pas suivant
	verifier(coups[0] >= 2 and loups[2].sante < pv2, "la charge différée part de la cible touchée et frappe la croix (%d coups)" % coups[0])
	verifier(j.chaine.segments.size() - seg_avant == 2, "un segment par ÉTAPE (designer 2026-09-01) : deux étapes posent deux segments (%d de plus)" % (j.chaine.segments.size() - seg_avant))
	# Ricochet : la charge saute vers les cibles proches
	coups[0] = 0
	for m0 in ["point", "etincelle", "ricochet", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["point", "etincelle", "ricochet", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "c", "name_key": "capacite.etincelle.name", "modules": ["point", "jet_court", "etincelle", "ricochet"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Étincelle + Ricochet")
	s.pas(j.horloge)
	verifier(coups[0] >= 2, "au moins un saut (%d coups)" % coups[0])
	# Partage : le Baume sur un allié soigne aussi le lanceur
	var allie := s.ajouter("bandit", j.pos + Vector2i(1, 0), "joueur")
	allie.sante = 10
	j.sante = 10
	for m0 in ["point", "baume", "partage", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "p", "name_key": "capacite.baume.name", "modules": ["point", "baume", "partage"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": allie.pos}), "Baume + Partage")
	verifier(allie.sante > 10 and j.sante > 10, "l'allié et le lanceur sont soignés")


# ---------------------------------------------------------------- Glyphes, charges différées, terrain, invocations

func test_glyphes_terrain() -> void:
	var cap := Capacites.new(GameData.catalogues["modules"])
	var p := cap.assembler(["sceau", "tuile", "racine"], 5, "1d4", {})
	verifier(p.erreurs.is_empty() and p.noyau.is_empty() and p.charge_suivante.declencheur == "entree" and p.geometrie == "tuile", "[Sceau]+[Tuile]+[Racine] : un glyphe, visé avec la géométrie Tuile")
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(0, -4)
	s.grille.placer(loup.id, loup.pos)
	for id in ["loup_2", "loup_3", "loup_4"]:
		s.entites[id].compteur = 500
	s._engager_combat(j, loup)
	var h := s.horloge_de(j)
	j.mana = 300
	_capacite_test(s, j, "g", ["sceau", "tuile", "racine"])
	j.compteur = h.ticks
	s.pas(j.horloge)
	var glyphe_pos: Vector2i = j.pos + Vector2i(0, -2)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": glyphe_pos}), "poser le glyphe")
	s.pas(j.horloge)   # 3 + 1 + 11 = 15 ticks : télégraphé, résolu à l'échéance
	verifier(s.glyphes.size() == 1 and s.glyphes[0].pos == glyphe_pos, "un glyphe attend au sol")
	# Le loup entre sur la tuile : le glyphe se déclenche, la Racine l'enracine, un segment Bois est posé
	s.grille.liberer(loup.pos)
	loup.pos = glyphe_pos + Vector2i(0, -1)
	s.grille.placer(loup.id, loup.pos)
	loup.compteur = h.ticks
	j.compteur = h.ticks + 50000
	var seg_avant: int = j.chaine.segments.size()
	s._deplacer(loup, glyphe_pos, h.ticks)
	verifier(s.glyphes.is_empty() and Etres.bloque_statuts(loup, "deplacement", s.statuts_defs), "à l'entrée : le glyphe part, le loup est enraciné")
	verifier(j.chaine.segments.size() == seg_avant + 1 and j.chaine.segments.back().element == "bois", "le glyphe élémentaire pose un segment Bois au lanceur")
	# Mèche : la charge part après 20 ticks
	for m0 in ["meche", "point", "etincelle", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["meche", "point", "etincelle", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "m", "name_key": "capacite.etincelle.name", "modules": ["meche", "point", "jet_court", "etincelle"]}
	j.compteur = h.ticks
	loup.compteur = h.ticks + 50000
	s.pas(j.horloge)
	var pv: int = loup.sante
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loup.pos}), "Mèche + Étincelle")
	verifier(s.differes.size() == 1 and loup.sante == pv, "la charge est différée, rien ne part encore")
	loup.compteur = h.ticks + 2500
	j.compteur = h.ticks + 60000
	s.pas(j.horloge)   # le loup agit à t+25 : la mèche (t+20) est tiquée en fin de pas
	verifier(s.differes.is_empty() and loup.sante < pv, "20 ticks plus tard, l'Étincelle part")
	# Barrière : occupe la tuile, bloque le passage, disparaît après 50 ticks
	for m0 in ["tuile", "barriere", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["tuile", "barriere", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "b", "name_key": "capacite.etincelle.name", "modules": ["tuile", "jet_court", "barriere"]}
	j.compteur = h.ticks
	loup.compteur = h.ticks + 50000
	s.pas(j.horloge)
	var mur_pos: Vector2i = j.pos + Vector2i(1, -1)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": mur_pos}), "Barrière")
	s.pas(j.horloge)   # 15 ticks : télégraphée
	verifier(s.grille.bloque_passage(mur_pos) and s.obstacles.size() == 1, "la barrière bloque la tuile")
	loup.compteur = h.ticks + 6000
	j.compteur = h.ticks + 60000
	s.pas(j.horloge)
	verifier(not s.grille.bloque_passage(mur_pos) and s.obstacles.is_empty(), "après 50 ticks, la barrière disparaît")
	# Exhaussement : +1 niveau ; Fosse : −3 niveaux et ce qui est dessus chute
	for m0 in ["tuile", "exhaussement", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["tuile", "exhaussement", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "e", "name_key": "capacite.etincelle.name", "modules": ["tuile", "jet_court", "exhaussement"]}
	j.compteur = h.ticks
	loup.compteur = h.ticks + 50000
	s.pas(j.horloge)
	var t_pos: Vector2i = j.pos + Vector2i(-1, -1)
	var h_avant: int = s.grille.h(t_pos)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": t_pos}), "Exhaussement")
	s.pas(j.horloge)
	verifier(s.grille.h(t_pos) == h_avant + 1, "la tuile monte d'un niveau")
	for m0 in ["tuile", "jet_court", "fosse"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["tuile", "fosse", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "f", "name_key": "capacite.etincelle.name", "modules": ["tuile", "jet_court", "fosse"]}
	j.compteur = h.ticks
	loup.compteur = h.ticks + 50000
	s.pas(j.horloge)
	h_avant = s.grille.h(loup.pos)
	pv = loup.sante
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loup.pos}), "Fosse sous le loup")
	s.pas(j.horloge)
	verifier(s.grille.h(loup.pos) == h_avant - 3 and loup.sante == pv - 5, "la tuile s'effondre de 3 : le loup chute (5 dégâts)")


# ---------------------------------------------------------------- Déclencheurs à événement, Salve, Propagation, Boucle

func test_evenements() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var loups: Array[Dictionary] = [s.entites["loup_2"], s.entites["loup_3"], s.entites["loup_4"]]
	var positions := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1)]
	for i in 3:
		s.grille.liberer(loups[i].pos)
		loups[i].pos = j.pos + positions[i]
		s.grille.placer(loups[i].id, loups[i].pos)
		loups[i].compteur = 500
		loups[i].sante = 400
		loups[i].sante_max = 400
	s._engager_combat(j, loups[0])
	var h := s.horloge_de(j)
	j.mana = 300
	# Riposte : armée sur soi, part quand le porteur est touché
	_capacite_test(s, j, "r", ["riposte", "point", "etincelle"])
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": j.pos}), "armer une Riposte")
	verifier(j.declencheurs_armes.size() == 1 and j.declencheurs_armes[0].evenement == "riposte", "la Riposte attend")
	var pv0: int = loups[0].sante
	loups[0].compteur = h.ticks
	j.compteur = h.ticks + 50000
	s.pas(j.horloge)   # le loup mord
	verifier(j.declencheurs_armes.is_empty() and loups[0].sante < pv0, "touché : l'Étincelle part sur l'attaquant")
	# Cadence : tous les 3 emplois, la charge qui suit part aussi
	for m0 in ["point", "etincelle", "cadence", "point", "bruine", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["point", "etincelle", "cadence", "point", "bruine", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "cad", "name_key": "capacite.etincelle.name", "modules": ["point", "jet_court", "etincelle", "cadence", "point", "bruine"]}
	var coups := [0]
	EventBus.damage_dealt.connect(func(src: String, _c: String, _d: int, _det: Dictionary) -> void: if src == j.id: coups[0] += 1)
	for k in 3:
		j.compteur = h.ticks
		loups[0].compteur = h.ticks + 50000
		s.pas(j.horloge)
		s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos})
	verifier(coups[0] == 4, "3 emplois → 3 Étincelles + 1 Bruine (%d coups)" % coups[0])
	# Salve : 3 charges à 60 % réparties sur les cibles d'une ligne
	coups[0] = 0
	for m0 in ["ligne", "etincelle", "salve", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["ligne", "etincelle", "salve", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "sv", "name_key": "capacite.etincelle.name", "modules": ["ligne", "jet_court", "etincelle", "salve"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	# la ligne part vers (0,-1) : seul loups[0] est dessus → les 3 charges tombent sur lui
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Salve en ligne")
	s.pas(j.horloge)   # télégraphié depuis que la portée est un module : la salve part au pas suivant
	verifier(coups[0] == 3, "3 charges (%d coups)" % coups[0])
	# Propagation : de proche en proche (les trois loups sont contigus)
	coups[0] = 0
	for m0 in ["point", "etincelle", "propagation", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["point", "etincelle", "propagation", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "pr", "name_key": "capacite.etincelle.name", "modules": ["point", "jet_court", "etincelle", "propagation"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Étincelle + Propagation")
	s.pas(j.horloge)
	s.pas(j.horloge)
	verifier(coups[0] == 3, "la charge se propage aux trois loups (%d coups)" % coups[0])
	# Boucle : rejoue tant qu'il reste du mana
	coups[0] = 0
	j.mana = 10   # Étincelle = 3 mana : 1 + 3 rejeux (10 → 7 → 4 → 1)
	for m0 in ["point", "etincelle", "boucle", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["point", "etincelle", "boucle", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "bo", "name_key": "capacite.etincelle.name", "modules": ["point", "jet_court", "etincelle", "boucle"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Étincelle + Boucle")
	s.pas(j.horloge)
	verifier(coups[0] >= 2 and j.mana <= 3, "la boucle rejoue jusqu'à épuisement du mana (%d coups, mana %d)" % [coups[0], j.mana])
	# Testament : la charge part quand le porteur tombe
	loups[0].capacites = [{"id": "t", "name_key": "capacite.etincelle.name", "modules": ["testament", "anneau", "jet_court", "etincelle"]}]
	loups[0].mana = 50
	loups[0].declencheurs_armes.append({"evenement": "testament", "plan": s.plan_capacite(loups[0], 0).charge_suivante})
	var pvj: int = j.sante
	loups[0].sante = 1
	j.compteur = h.ticks
	s.pas(j.horloge)
	s.intention(j.id, {"type": "attaquer", "cible": loups[0].id, "lourde": false})
	verifier(not loups[0].vivant and j.sante < pvj, "le loup tombe : son Testament en anneau frappe le joueur")


# ---------------------------------------------------------------- Niveaux de compétence (décisions du 2026-08-27)

func test_niveaux() -> void:
	var r := Regles.new(GameData.config("combat_rules"))
	verifier(is_equal_approx(r.skill_factor(50), 2.0), "skill_factor(50) = 2.0")
	var epee: Dictionary = GameData.entree("functionalities", "epee")
	verifier(is_equal_approx(r.facteur_competences({}, epee, {"metal": 1.0}), 1.0), "sans niveau : facteur 1")
	verifier(is_equal_approx(r.facteur_competences({"epee": 50}, epee, {"metal": 1.0}), 2.0), "Épée 50 : ×2")
	verifier(is_equal_approx(r.facteur_competences({"tranchant": 50, "element_metal": 100}, epee, {"metal": 1.0}), 2.0 * 2.0), "tranchant 50 × Métal 100 : ×4")
	verifier(is_equal_approx(r.facteur_competences({"element_metal": 100}, epee, {"metal": 0.5, "bois": 0.5}), 1.5), "arme mixte : le niveau d'élément pèse à hauteur de sa part")
	# Déplacement : Athlétisme, minimum 2
	verifier(r.ticks_deplacement(3, {}, false) == 3 and r.ticks_deplacement(3, {"athletisme": 25}, false) == 2, "3 ticks ; Athlétisme 25 → 2")
	verifier(r.ticks_deplacement(3, {"athletisme": 200}, false) == 2, "jamais sous 2 ticks")
	verifier(r.ticks_deplacement(8, {"athletisme": 50}, false) == 4, "montée +2 (8) / 2 = 4")
	verifier(r.ticks_deplacement(3, {"esquive": 50}, true) == 2 and r.ticks_deplacement(3, {"esquive": 50}, false) == 3, "Esquive : −25 % en combat seulement")
	var s := nouvelle_sim("plaine_au_talus")
	var loup: Dictionary = s.entites["loup_2"]
	verifier(int(loup.competences.get("athletisme", 0)) == 25, "le loup part avec Athlétisme 25 (modificateur de race)")
	var t: int = s.horloge_monde.ticks
	s._deplacer(loup, loup.pos + Vector2i(0, 1), t)
	verifier(loup.compteur == t + 200, "le loup se déplace en 200 ticks")
	# Modules : ticks / skill_factor, plancher 50 % ; ressource / skill_factor
	var cap := Capacites.new(GameData.catalogues["modules"])
	var p := cap.assembler(["ligne", "flamme", "concentration"], 5, "2d6", {}, {"flamme": 50, "ligne": 50, "concentration": 50})
	verifier(p.ticks == 400 + 100 + 100 and p.ressource == 4 + 4, "niveau 50 partout : (8+2+2)/2 = 6 ticks · 8/2 + 4 = 8 mana")
	p = cap.assembler(["ligne", "flamme"], 5, "2d6", {}, {"flamme": 1000})
	verifier(p.ticks == 400 + 200, "plancher : Flamme ne descend jamais sous 400 ticks")


## LE CORPS EST UN PLAN DE PARTIES (ordre de travail 28 bis ; designer 2026-09-08 « un personnage est composé de
## membres, un personnage peut perdre ses membres », 2026-09-09 « oui on y va », puis quatre précisions le même
## jour : le monde réel donc des ORGANES, les non-humanoïdes portent de l'équipement ADAPTÉ, et il y a bien de la
## SANTÉ PAR PARTIES).
## **Ce test doit prouver que ce n'est pas la même liste déguisée** — sinon on aurait déplacé du code sans rien
## gagner. Il coupe donc un bras et compte ; puis il crève un cœur.
## Les règles de la simulation qui a fabriqué cet être — le test en a besoin pour appeler le soin par partie.
var _regles_test: Regles = null


func s_regles_de(_e: Dictionary) -> Regles:
	return _regles_test


func j3_regles(r: Regles) -> Regles:
	return r


func j_test_vide() -> Dictionary:
	return {"corps": {"silhouette": "humanoide"}}


func test_plan_corps() -> void:
	var plans: Dictionary = GameData.catalogues.plans_corps
	verifier(plans.size() >= 6, "chaque silhouette a son plan de corps (%d)" % plans.size())
	var sans := []
	for cid: String in GameData.catalogues.creatures.keys():
		var sil := str((GameData.catalogues.creatures[cid] as Dictionary).get("corps", {}).get("silhouette", ""))
		if not sil.is_empty() and not plans.has(sil) and not (sil in sans):
			sans.append(sil)
	verifier(sans.is_empty(), "aucune créature ne porte une silhouette sans plan (%s)" % str(sans))
	# Un plan est un ARBRE : racine présente, parents et contenants existants.
	var casse := []
	for pid: String in plans.keys():
		var plan: Dictionary = plans[pid]
		if not (plan.get("parties", {}) as Dictionary).has(str(plan.get("racine", ""))):
			casse.append(pid)
		for nom: String in (plan.parties as Dictionary).keys():
			for cle in ["parent", "contenant"]:
				var lien := str((plan.parties[nom] as Dictionary).get(cle, ""))
				if not lien.is_empty() and not (plan.parties as Dictionary).has(lien):
					casse.append("%s/%s.%s" % [pid, nom, cle])
	verifier(casse.is_empty(), "chaque plan est un arbre : racine, parents et contenants existants (%s)" % str(casse))

	# 1. LE MONDE RÉEL : un torse humain a cœur, poumons, foie, reins. Ce n'est pas de la couleur.
	var h: Dictionary = plans.humanoide.parties
	var attendus := ["coeur", "poumon_D", "poumon_G", "foie", "rein_D", "rein_G", "estomac", "cerveau"]
	var absents := []
	for o in attendus:
		if not h.has(o):
			absents.append(o)
	verifier(absents.is_empty(), "le torse et la tête humains ont leurs organes du monde réel (%s)" % str(absents))
	verifier(bool(h.coeur.get("interne", false)) and str(h.coeur.contenant) == "torse" and bool(h.coeur.get("vital", false)), "le cœur est un organe INTERNE du torse, et il est vital")
	verifier(not bool(h.poumon_D.get("vital", false)), "mais un poumon sur deux n'est pas vital : on respire encore")
	# Chaque silhouette a l'anatomie de SON animal, pas celle de l'homme recopiée.
	verifier(plans.volant.parties.has("sacs_aeriens") and plans.volant.parties.has("gesier"), "l'oiseau a des sacs aériens et un gésier")
	verifier(plans.arachnide.parties.has("poumons_livres") and plans.arachnide.parties.has("filieres"), "l'araignée a des poumons-livres et des filières")
	verifier(plans.serpentin.parties.has("poumon") and not plans.serpentin.parties.has("poumon_G"), "le serpent n'a qu'UN poumon fonctionnel — c'est le monde réel qui le dit")
	verifier(plans.amorphe.parties.size() == 1, "et la gelée n'a aucun organe : rien à lui percer")

	# 2. UN TORSE EST UN TORSE (designer 2026-09-09 : « pas de type d'armure différents pour les animaux SAUF pour
	#    les autres membres, genre pour queues, ailes »). Une pièce d'armure suit la FORME du membre, pas l'espèce :
	#    un torse de cheval et un torse d'homme portent la même cuirasse. Seuls la QUEUE et les AILES, qui n'ont
	#    aucun équivalent humain, gardent un emplacement à eux.
	var cheval := {"corps": {"silhouette": "quadrupede"}}
	var rapace := {"corps": {"silhouette": "volant"}}
	var emp_q := Etres.emplacements(cheval)
	verifier("cuirasse" in emp_q and "casque" in emp_q and "jambieres" in emp_q, "un quadrupède porte la MÊME cuirasse, le MÊME casque, les MÊMES jambières qu'un homme (%s)" % str(emp_q))
	verifier("protege_queue" in emp_q, "et un protège-queue, parce qu'une queue n'a pas d'équivalent humain")
	var emp_v := Etres.emplacements(rapace)
	verifier("protege_ailes" in emp_v and "cuirasse" in emp_v, "un volant porte un protège-ailes, et la même cuirasse que tout le monde (%s)" % str(emp_v))
	verifier(not ("brassards" in emp_v), "mais pas de brassards : une aile n'est pas un bras")
	verifier(not ("protege_queue" in Etres.emplacements(j_test_vide())), "et un humain ne reçoit ni queue ni ailes — la liste d'affichage ne décide de rien")
	verifier(Etres.emplacements({"corps": {"silhouette": "amorphe"}}).is_empty(), "une gelée ne porte rien, et c'est une affirmation, pas un manque")
	# Le compte des types d'armure reste petit : c'est la règle du designer, et elle se vérifie.
	var types := {}
	for pid3: String in GameData.catalogues.plans_corps.keys():
		for part3 in (GameData.catalogues.plans_corps[pid3] as Dictionary).parties.values():
			for sl in (part3 as Dictionary).get("emplacements", []):
				types[str(sl)] = true
	verifier(types.size() <= 16, "seize types d'équipement pour six anatomies — pas dix mille (%d)" % types.size())
	# Ce que chaque créature équipe tient dans son plan : si un jour on coiffe un loup, ça se verra ici.
	var hors_plan := []
	for cid2: String in GameData.catalogues.creatures.keys():
		var def: Dictionary = GameData.catalogues.creatures[cid2]
		var permis := Etres.emplacements({"corps": {"silhouette": str(def.get("corps", {}).get("silhouette", ""))}})
		for uid in def.get("equipement", []):
			var slot := str((GameData.catalogues.items.get(str(uid), {}) as Dictionary).get("equip_slot", ""))
			if not slot.is_empty() and not (slot in permis):
				hors_plan.append("%s:%s" % [cid2, slot])
		for slot2: String in (def.get("equipement_slots", {}) as Dictionary).keys():
			if not (slot2 in permis):
				hors_plan.append("%s:%s" % [cid2, slot2])
	verifier(hors_plan.is_empty(), "aucune créature n'équipe un emplacement que son plan n'accorde pas (%s)" % str(hors_plan))

	# 3. LES ORGANES DE SENS SONT LE LECTEUR D'UN CHAMP (designer 2026-09-09 : « tout ce qui est nez yeux oreilles
	#    etc font partie des organes »). Les trois champs qu'ils lisent existent depuis le même jour.
	var par_sens := {}
	for nom_p: String in (plans.humanoide.parties as Dictionary).keys():
		var sn := str((plans.humanoide.parties[nom_p] as Dictionary).get("sens", ""))
		if not sn.is_empty():
			par_sens[sn] = true
	verifier(par_sens.has("vue") and par_sens.has("ouie") and par_sens.has("odorat"), "l'humain a ses trois sens en organes : yeux, oreilles, nez")
	verifier(plans.serpentin.parties.has("organe_de_jacobson") and not plans.serpentin.parties.has("oreille_D"), "le serpent sent par son organe de Jacobson et n'a AUCUNE oreille externe — le monde réel, encore")
	verifier(plans.arachnide.parties.has("oeil_8") and plans.arachnide.parties.has("soies_sensorielles"), "l'araignée a huit yeux et perçoit par ses soies sensorielles")
	var borgne := {"corps": {"silhouette": "humanoide", "perdues": ["oeil_D"]}}
	verifier(Etres.sens_actif(borgne, "vue"), "un œil crevé ne rend pas aveugle : il en reste un")
	var aveugle := {"corps": {"silhouette": "humanoide", "perdues": ["oeil_D", "oeil_G"]}}
	verifier(not Etres.sens_actif(aveugle, "vue") and Etres.sens_actif(aveugle, "ouie"), "les deux crevés, la vue n'a plus de lecteur — mais il entend encore")
	verifier(Etres.sens_actif({"corps": {"silhouette": "amorphe"}}, "vue"), "une gelée ne déclare aucun œil : elle perçoit comme avant, rien de ce qui marchait ne se met à échouer")
	verifier(Etres.sens_actif({"corps": {"silhouette": "serpentin"}}, "ouie"), "et le serpent, qui ne déclare aucune oreille, n'est pas sourd pour autant — la règle ne punit pas une anatomie")

	# 4. COUPER UN BRAS : la preuve que la liste n'est pas une liste.
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	# La liste d'affichage en compte SEIZE depuis qu'elle range aussi les ailes et la queue ; un homme en reçoit
	# QUATORZE, parce qu'il n'a ni l'une ni l'autre. C'est précisément ce que « la liste ne décide de rien » veut dire.
	var tous: Array = Array(GameData.config("combat_rules").equipement.slots)
	var emp_j := Etres.emplacements(j)
	verifier(emp_j.size() == 14 and tous.size() == 16, "le joueur entier a ses 14 emplacements, sur les %d que la liste sait ranger" % tous.size())
	var ordre_ok := true
	var prec := -1
	for sl_j in emp_j:
		var pos := tous.find(sl_j)
		if pos <= prec:
			ordre_ok = false
		prec = pos
	verifier(ordre_ok, "et ils sortent dans l'ordre d'affichage des données")
	var arme_uid := str(j.equipement.get("main_principale", ""))
	verifier(not arme_uid.is_empty(), "le joueur tient une arme en main principale")
	var sac0: int = j.sac.size()
	verifier(not Etres.perdre_partie(j, "bras_D"), "un bras n'est pas vital — le module le dit à l'appelant, il ne tue personne")
	var emp2 := Etres.emplacements(j)
	verifier(not ("main_principale" in emp2) and not ("anneau_1" in emp2), "le bras perdu, la main principale et son anneau ne sont plus des emplacements")
	verifier("main_secondaire" in emp2 and "brassards" in emp2, "la main gauche reste, et les brassards tiennent avec un seul bras — une paire suffit")
	verifier(not j.equipement.has("main_principale") and arme_uid in j.sac and j.sac.size() > sac0, "l'arme est retombée dans le sac, pas détruite (%d → %d)" % [sac0, j.sac.size()])
	verifier(Etres.partie_intacte(j, "bras_G") and not Etres.partie_intacte(j, "main_D"), "une main ne survit pas au bras : l'état se lit par la chaîne des parents")

	# 5. LE PANTIN SAIT QUELLE PARTIE IL DESSINE — c'est ce qui lui permet de ne pas dessiner un bras perdu.
	var manques := []
	for rid: String in GameData.catalogues.rigs.keys():
		var rg: Dictionary = GameData.catalogues.rigs[rid]
		for sg: String in (rg.segments as Dictionary).keys():
			var pc2 := str((rg.segments[sg] as Dictionary).get("partie", ""))
			if pc2.is_empty():
				manques.append("%s/%s" % [rid, sg])
	verifier(manques.is_empty(), "chaque segment de chaque rig dit la partie du corps qu'il dessine (%s)" % str(manques))
	var ecarts := []
	for rid2: String in GameData.catalogues.rigs.keys():
		if not plans.has(rid2):
			continue   # le gabarit n'est le corps de personne
		for sg2: String in (GameData.catalogues.rigs[rid2].segments as Dictionary).keys():
			var pc3 := str((GameData.catalogues.rigs[rid2].segments[sg2] as Dictionary).get("partie", ""))
			if not (plans[rid2].parties as Dictionary).has(pc3):
				ecarts.append("%s/%s→%s" % [rid2, sg2, pc3])
	verifier(ecarts.is_empty(), "et cette partie existe dans le plan de la même silhouette (%s)" % str(ecarts))

	# 6. LA SANTÉ PAR PARTIES. Chaque partie a SA réserve, et le compteur global décide seul de la mort.
	var j2 := joueur_de(nouvelle_sim("gorge"))
	var max_torse := Etres.sante_partie_max(j2, "torse")
	var max_coeur := Etres.sante_partie_max(j2, "coeur")
	verifier(max_torse > max_coeur and max_coeur > 0, "chaque partie a sa réserve, tirée de la santé maximale (torse %d, cœur %d sur %d)" % [max_torse, max_coeur, int(j2.sante_max)])
	verifier(Etres.blesser_partie(j2, "jambe_D", 1) == "" and Etres.sante_partie(j2, "jambe_D") == Etres.sante_partie_max(j2, "jambe_D") - 1, "une égratignure entame la réserve de la jambe sans rien lui coûter")
	verifier(Etres.blesser_partie(j2, "jambe_D", 100000) == "perdue" and not Etres.partie_intacte(j2, "jambe_D"), "assez de dégâts sur la même jambe, et elle tombe")
	verifier(not Etres.partie_intacte(j2, "pied_D") and Etres.partie_intacte(j2, "pied_G"), "le pied qu'elle portait tombe avec elle, l'autre non")
	verifier(Etres.blesser_partie(j2, "coeur", 100000) == "vitale", "un cœur crevé se dit VITAL — et c'est l'appelant qui en tire la mort, pas ce module")

	# LE SOIN PAR PARTIE — et c'est une correction, pas un ajout : sans lui, la santé par partie était un CLIQUET,
	# et l'usure ordinaire d'une longue partie finissait par mutiler tout le monde.
	var s3 := nouvelle_sim("gorge")
	_regles_test = s3.regles
	var j3 := joueur_de(s3)
	verifier(Etres.blesser_partie(j3, "bras_G", Etres.sante_partie_max(j3, "bras_G") / 2) == "", "un bras à demi entamé tient encore")
	var avant_soin := Etres.sante_partie(j3, "bras_G")
	Etres.soigner_parties(j3, 20000, j3_regles(s_regles_de(j3)))
	verifier(Etres.sante_partie(j3, "bras_G") > avant_soin, "hors du combat, il se répare (%d → %d)" % [avant_soin, Etres.sante_partie(j3, "bras_G")])
	Etres.soigner_parties(j3, 100000000, j3_regles(s_regles_de(j3)))
	verifier(Etres.sante_partie(j3, "bras_G") == Etres.sante_partie_max(j3, "bras_G") and not j3.corps.get("sante_parties", {}).has("bras_G"), "et le temps le remet à plein — l'entrée disparaît, un corps intact ne coûte rien")
	Etres.perdre_partie(j3, "bras_D")
	Etres.soigner_parties(j3, 100000000, j3_regles(s_regles_de(j3)))
	verifier(not Etres.partie_intacte(j3, "bras_D"), "mais un bras PERDU ne repousse pas : c'est la prothèse qui le remplacera, pas le temps")

	# CE QUE COÛTE LA PERTE D'UN ORGANE. Jusqu'ici ils ne faisaient qu'une chose : tuer si on les crevait.
	var s4 := nouvelle_sim("gorge")
	var j4 := joueur_de(s4)
	var vig0: int = int(j4.vigueur_max)
	Etres.perdre_partie(j4, "poumon_D")
	Etres.recalculer(j4, s4.items, s4.affixes_defs, s4.regles)
	verifier(int(j4.vigueur_max) < vig0, "un poumon perdu retranche à la vigueur maximale : on respire encore, moins bien (%d → %d)" % [vig0, int(j4.vigueur_max)])
	verifier(Etres.sens_actif(j4, "ouie"), "et cela ne touche à aucun sens : un poumon n'entend pas")
	Etres.perdre_partie(j4, "estomac")
	Etres.recalculer(j4, s4.items, s4.affixes_defs, s4.regles)
	verifier(float(j4.get("faim_vitesse", 1.0)) > 1.0, "un estomac perdu fait creuser plus vite (×%.2f)" % float(j4.get("faim_vitesse", 1.0)))
	# ET LE CODE NE CONNAÎT AUCUN NOM D'ORGANE : tout est déclaré sur l'organe, dans son bloc `perdu`.
	var sans_bloc := 0
	for nom_o: String in (plans.humanoide.parties as Dictionary).keys():
		var po: Dictionary = plans.humanoide.parties[nom_o]
		# Un organe peut ne rien coûter ENCORE — mais il doit dire ce qu'il attend. Un manque écrit vaut mieux
		# qu'un manque tu : les reins attendent l'hydratation, et c'est dans la donnée, pas dans ma tête.
		if bool(po.get("interne", false)) and not po.has("perdu") and str(po.get("sens", "")).is_empty() and not bool(po.get("vital", false)) and str(po.get("attend", "")).is_empty():
			sans_bloc += 1
	verifier(sans_bloc == 0, "tout organe non vital et sans sens dit ce que sa perte coûte, ou ce qu'elle attend (%d muet(s))" % sans_bloc)
	# Le tirage de la partie touchée reste dans la zone demandée, et il atteint les organes.
	var vus := {}
	for k in 400:
		var q := Etres.partie_touchee(j2, "torse", s.des)
		vus[q] = true
	var hors_zone := []
	for q2: String in vus.keys():
		if str((GameData.catalogues.plans_corps.humanoide.parties[q2] as Dictionary).zone) != "torse":
			hors_zone.append(q2)
	verifier(hors_zone.is_empty(), "un coup au torse ne touche qu'une partie du torse (%s)" % str(hors_zone))
	verifier(vus.has("torse") and (vus.has("poumon_D") or vus.has("poumon_G") or vus.has("foie")), "et il atteint parfois un organe — le coup chanceux n'a demandé aucune règle de « critique » (%d parties vues)" % vus.size())


## LES CADAVRES RESTENT, ET SE DÉMONTENT (ordre de travail 28 ter). Trois choses à prouver, et elles sont
## indépendantes : le TEMPS passe sur un mort sans qu'aucune boucle ne le tique, on ne peut PRENDRE que ce qui est
## encore là et pas la racine du corps, et l'échec est DÉFINITIF — le jet est semé sur la pièce, pas sur l'heure.
func test_cadavres() -> void:
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	var cible: Dictionary = {}
	for e in s.vivants():
		if e.controle != "joueur" and not Etres.plan_corps(e).is_empty():
			cible = e
			break
	verifier(not cible.is_empty(), "l'arène offre un être avec un plan de corps à faire tomber")
	if cible.is_empty():
		return
	s._appliquer_degats(cible, int(cible.sante) + 100, j.id, {})
	verifier(not cible.vivant and int(cible.get("mort_tick", -1)) == s.horloge_monde.ticks, "un mort note l'HEURE de sa mort — c'est le seul nombre que la pourriture demande")
	verifier(str(SimCadavres.cadavre_a(s, cible.pos).get("id", "")) == str(cible.id), "et sa dépouille se trouve sur sa tuile, alors qu'elle n'occupe plus la grille")

	# 1. LE TEMPS PASSE SANS QUE RIEN NE LE TIQUE : les stades se déduisent de l'heure de la mort.
	var jour := int(SimTerrain._cycle(s).get("ticks_par_jour", 2400000))
	verifier(str(SimCadavres.stade(s, cible).get("id", "")) == "frais", "à la seconde de sa mort, la dépouille est fraîche")
	var vus: Array[String] = []
	for k in 25:
		s.horloge_monde.ticks += jour
		var st := str(SimCadavres.stade(s, cible).get("id", ""))
		if not (st in vus):
			vus.append(st)
	verifier(vus.size() >= 3 and vus[vus.size() - 1] == "ossements", "vingt-cinq jours la mènent du frais aux ossements, en passant par tous les stades (%s)" % str(vus))
	# L'ODEUR SUIT LA POURRITURE, et c'est ce qui donne le champ d'odeur aux charognards : un mort gonflé appelle de
	# loin, des ossements ne sentent plus rien. La source était plate — le champ ne disait pas depuis quand.
	s.horloge_monde.ticks = int(cible.mort_tick)
	var o_frais := SimCadavres.odeur_mult(s, cible)
	s.horloge_monde.ticks = int(cible.mort_tick) + jour * 3
	var o_gonfle := SimCadavres.odeur_mult(s, cible)
	s.horloge_monde.ticks = int(cible.mort_tick) + jour * 40
	verifier(o_gonfle > o_frais and SimCadavres.odeur_mult(s, cible) == 0.0, "elle sent de plus en plus fort, puis plus du tout : des ossements n'appellent personne (%.2f → %.2f → 0)" % [o_frais, o_gonfle])

	# 2. CE QU'ON PEUT PRENDRE. Passé la putréfaction, plus rien — et l'on ne l'apprend pas par un échec.
	s.horloge_monde.ticks = int(cible.mort_tick)
	var plan := Etres.plan_corps(cible)
	var racine := str(plan.racine)
	verifier(not SimCadavres.prelevable(s, cible, racine), "on ne prélève pas la RACINE du corps : ce torse-là *est* la dépouille")
	var membre := ""
	var organe := ""
	for nom: String in (plan.parties as Dictionary).keys():
		var p: Dictionary = plan.parties[nom]
		# ON PREND UNE PIÈCE ENCORE LÀ. Le coup qui a tué a frappé une partie au passage — la première version de ce
		# test choisissait la tête sans regarder, la trouvait déjà détruite (et le cerveau avec elle, puisqu'un
		# organe suit son contenant), et accusait le prélèvement d'un défaut qui était le sien.
		if nom == racine or not Etres.partie_intacte(cible, nom):
			continue
		if bool(p.get("interne", false)) and organe.is_empty():
			organe = nom
		elif not bool(p.get("interne", false)) and membre.is_empty():
			membre = nom
	verifier(not membre.is_empty() and not organe.is_empty(), "la dépouille garde des pièces intactes après le coup qui l'a tuée (%s, %s)" % [membre, organe])
	if membre.is_empty() or organe.is_empty():
		return
	verifier(SimCadavres.prelevable(s, cible, membre) and SimCadavres.prelevable(s, cible, organe), "sur une dépouille fraîche, membres et organes se prélèvent (%s, %s)" % [membre, organe])
	s.horloge_monde.ticks = int(cible.mort_tick) + jour * 10
	verifier(not SimCadavres.prelevable(s, cible, membre), "putréfiée, elle n'offre plus rien — l'option disparaît au lieu de faire échouer")
	s.horloge_monde.ticks = int(cible.mort_tick)

	# 3. PRÉLEVER : la pièce quitte le corps dans TOUS les cas, et une seule fois.
	j.pos = cible.pos
	var sac0: int = j.sac.size()
	verifier(SimCadavres.prelever(s, j, cible, membre, s.horloge_monde.ticks), "on prélève le membre")
	verifier(not Etres.partie_intacte(cible, membre) and (membre in SimCadavres.prelevees(cible)), "il a quitté le corps, et le corps dit qu'il a été PRÉLEVÉ — pas arraché au combat")
	verifier(not SimCadavres.prelever(s, j, cible, membre, s.horloge_monde.ticks), "et on ne le prélève pas deux fois")
	verifier(not SimCadavres.prelevable(s, cible, racine), "la racine reste hors de portée après coup")
	# Réussi ou abîmé, l'un des deux est arrivé — et s'il est arrivé, l'objet dit quelle pièce et de qui.
	if j.sac.size() > sac0:
		var it: Dictionary = s.items[str(j.sac[j.sac.size() - 1])]
		var n := s.nom_objet(str(it.uid))
		verifier(str(n.get("partie", "")) == "partie." + membre and not str(n.get("de_creature", "")).is_empty(), "la pièce dans le sac dit LAQUELLE et DE QUI (%s / %s)" % [str(n.get("partie", "")), str(n.get("de_creature", ""))])
		verifier(float(it.get("poids", 0.0)) > 0.0 and float(it.get("valeur", 0.0)) > 0.0, "elle pèse et elle vaut : un membre se porte et se vend (%.2f kg, %.0f)" % [float(it.get("poids", 0.0)), float(it.get("valeur", 0.0))])
	# LE JET NE SE REJOUE PAS : semé sur la dépouille et la pièce, jamais sur l'heure. Deux dépouilles différentes
	# donnent des jets différents ; la MÊME pièce du MÊME mort donnerait toujours le même — c'est ce qui interdit
	# de recommencer jusqu'à réussir.
	var g0 := hash([s.graine, "prelever", str(cible.id), membre])
	s.horloge_monde.ticks += 999999
	verifier(hash([s.graine, "prelever", str(cible.id), membre]) == g0, "et le jet ne dépend pas de l'heure : réessayer plus tard ne changerait rien")


## L'HYDRATATION (ordre de travail 31 ; designer 2026-09-09 : « on rajoutera l'hydratation aussi »). Elle est la
## faim en plus pressant, et c'est ce que le test vérifie d'abord : les nombres, pas seulement la mécanique. Puis
## ce qui la rend intéressante — elle est le seul manque que le corps déclarait ENCORE, sur les reins.
func test_hydratation() -> void:
	var f: Dictionary = GameData.config("combat_rules").get("soif", {})
	verifier(not f.is_empty(), "l'hydratation a ses nombres en données")
	if f.is_empty():
		return
	var faim: Dictionary = GameData.config("combat_rules").faim
	verifier(int(f.ticks_par_point) < int(faim.ticks_par_point) and int(f.periode_zero) < int(faim.periode_zero), "on tient MOINS longtemps sans boire que sans manger (%d contre %d ticks par point)" % [int(f.ticks_par_point), int(faim.ticks_par_point)])
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	verifier(int(j.get("soif", -1)) == 100, "un être naît désaltéré (%d)" % int(j.get("soif", -1)))
	# 1. LE TEMPS ASSÈCHE. On avance de quoi perdre vingt points, et pas un de plus.
	# L'HORLOGE PART D'UN TICK NON NUL : `soif_tick` à zéro est lu comme « jamais estampillé » (un être créé alors
	# que le monde en est à cinq millions de ticks ne doit pas mourir de soif à sa naissance), donc un test qui
	# part de zéro ne verrait rien s'écouler.
	var t0: int = maxi(1, s.horloge_monde.ticks)
	s.horloge_monde.ticks = t0
	j["soif_tick"] = t0
	s.horloge_monde.ticks = t0 + int(f.ticks_par_point) * 20
	s._tiquer_soif(s.horloge_monde.ticks)
	verifier(int(j.soif) == 80, "vingt périodes ôtent vingt points (%d)" % int(j.soif))
	# 2. SOUS LE SEUIL, LES STATS BAISSENT — et le malus de soif se cumule avec celui de la faim, parce que ce sont
	# deux manques et non deux noms du même.
	var for0: int = int(j.stats_eff.force)
	j["soif"] = int(f.seuil_stats) - 1
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(int(j.stats_eff.force) < for0, "déshydraté, il perd de la force (%d → %d)" % [for0, int(j.stats_eff.force)])
	# 3. BOIRE À MÊME L'EAU, s'il y a de l'eau à côté. Sinon la règle refuse, et c'est elle qu'on éprouve.
	var eau := Vector2i(-1, -1)
	for dd in Grille.DIRS:
		var q: Vector2i = j.pos + dd
		if s.grille.dans(q) and ("eau" in s.grille.contenu_de(q).get("tags", []) or "liquide" in s.grille.contenu_de(q).get("tags", [])):
			eau = q
	verifier(not s.boire(j, j.pos + Vector2i(0, 0), s.horloge_monde.ticks) or eau == j.pos, "on ne boit pas une tuile sèche")
	if eau.x >= 0:
		var avant: int = int(j.soif)
		verifier(s.boire(j, eau, s.horloge_monde.ticks) and int(j.soif) > avant, "une gorgée à même l'eau désaltère (%d → %d)" % [avant, int(j.soif)])
	# 4. CE QUI DÉSALTÈRE EST SUR LA FICHE DE L'OBJET, pas dans le code.
	var gourde: Dictionary = GameData.catalogues.items.get("gourde_eau", {})
	verifier(int(gourde.get("hydratation", 0)) > int(GameData.catalogues.items.get("biere", {}).get("hydratation", 0)), "une gourde d'eau désaltère mieux qu'une bière, et c'est écrit sur les fiches")
	j["soif"] = 40
	var o := s.generer_objet("gourde_eau", 1, {}, "commun", 0)
	if not o.is_empty():
		j.sac.append(o.uid)
		var avant_g: int = int(j.soif)
		# On appelle la RÈGLE directement : passer par la file d'intentions ferait échouer le test pour une raison
		# qui n'est pas la sienne — la gorgée d'eau juste avant a posé un compteur, et l'être n'est plus en attente.
		s._manger(j, str(o.uid), s.horloge_monde.ticks)
		verifier(int(j.soif) > avant_g, "boire la gourde remonte la jauge (%d → %d)" % [avant_g, int(j.soif)])
	# 5. LES REINS N'ATTENDENT PLUS. C'était le seul manque ÉCRIT du plan de corps — un organe qui ne coûtait rien
	# et disait ce qu'il attendait. Il coûte maintenant : un rein en moins fait boire plus souvent.
	var plans: Dictionary = GameData.catalogues.plans_corps
	var attend_encore: Array[String] = []
	for pid: String in plans.keys():
		for nom: String in (plans[pid].parties as Dictionary).keys():
			if str((plans[pid].parties[nom] as Dictionary).get("attend", "")) == "hydratation":
				attend_encore.append("%s/%s" % [pid, nom])
	verifier(attend_encore.is_empty(), "aucun organe n'attend plus l'hydratation (%s)" % str(attend_encore))
	var j5 := joueur_de(nouvelle_sim("gorge"))
	verifier(float(j5.get("soif_vitesse", 1.0)) == 1.0, "un corps entier boit à son rythme")
	Etres.perdre_partie(j5, "rein_D")
	Etres.recalculer(j5, s.items, s.affixes_defs, s.regles)
	verifier(float(j5.get("soif_vitesse", 1.0)) > 1.0, "un rein en moins fait boire plus souvent (×%.2f)" % float(j5.get("soif_vitesse", 1.0)))


# ---------------------------------------------------------------- Étape 1 : rigs, paperdoll, tutoriels

## La CARTE DE LUMIÈRE ne se refait plus à chaque tick (2026-09-08, sur « énorme lag en ville quand le joueur se
## déplace »). Elle était refaite ENTIÈREMENT dès qu'un tick de monde avait passé, même si rien n'avait bougé — et le
## monde avance jusqu'à cinq ticks par image quand le joueur marche, pendant que `voit_ia` lit la lumière pour chaque
## paire observateur/cible la nuit en ville. Une signature de l'état lumineux dit maintenant s'il faut recalculer.
func test_lumiere_incrementale() -> void:
	var s := Simulation.new(808)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	# Une première lecture calcule la carte.
	s.niveau_lumiere(j.pos)
	var n0: float = float(s.chrono.get("n.lumiere", 0.0))
	verifier(n0 > 0.0, "une première lecture calcule la carte (%d)" % int(n0))
	# 1. Cent ticks SANS que rien ne bouge : la carte ne doit pas se refaire une seule fois.
	for k in 100:
		s.horloge_monde.ticks += 1
		s.niveau_lumiere(j.pos)
	var n1: float = float(s.chrono.get("n.lumiere", 0.0))
	verifier(n1 == n0, "cent ticks sans rien qui bouge : ZÉRO recalcul (avant : cent — %d)" % int(n1 - n0))
	# 2. Une tuile qui change (`lumiere_sale`) DOIT refaire la carte : on ne casse pas la fraîcheur.
	s.lumiere_sale = true
	s.niveau_lumiere(j.pos)
	var n2: float = float(s.chrono.get("n.lumiere", 0.0))
	verifier(n2 == n1 + 1.0, "une tuile changée refait la carte, une fois")
	# 3. Une SOURCE QUI BOUGE doit la refaire aussi — c'est ce que `lumiere_sale` ne couvrait pas, et la raison pour
	#    laquelle le recalcul au tick existait.
	var porteur: Dictionary = s.ajouter("villageois", s._tuile_libre_autour(j.pos), "ia")
	var torche: Dictionary = s.generer_objet("torche", 1, {}, "commun", 0) if GameData.catalogues.items.has("torche") else {}
	if not torche.is_empty():
		porteur.equipement["main_secondaire"] = torche.uid
		verifier(s.lumiere_de(porteur) > 0, "le villageois porte une lumière (%d)" % s.lumiere_de(porteur))
		s.horloge_monde.ticks += 1
		s.niveau_lumiere(j.pos)
		var n3: float = float(s.chrono.get("n.lumiere", 0.0))
		verifier(n3 > n2, "allumer une source refait la carte")
		# Il se déplace : la carte doit suivre.
		var ailleurs: Vector2i = s._tuile_libre_autour(porteur.pos)
		s.grille.liberer(porteur.pos)
		porteur.pos = ailleurs
		s.grille.placer(porteur.id, ailleurs)
		s.horloge_monde.ticks += 1
		s.niveau_lumiere(j.pos)
		verifier(float(s.chrono.get("n.lumiere", 0.0)) > n3, "et le porteur qui se DÉPLACE la refait — c'est ce que `lumiere_sale` ne voyait pas")
		# Et à nouveau immobile : plus de recalcul.
		var n4: float = float(s.chrono.get("n.lumiere", 0.0))
		for k in 50:
			s.horloge_monde.ticks += 1
			s.niveau_lumiere(j.pos)
		verifier(float(s.chrono.get("n.lumiere", 0.0)) == n4, "puis cinquante ticks immobiles : plus aucun recalcul")

func test_paperdoll_et_tutoriels() -> void:
	for id in ["humanoide", "quadrupede", "volant", "amorphe"]:
		var rig: Dictionary = GameData.entree("rigs", id)
		# COMBIEN DE VUES EXISTE-T-IL ? C'est une décision de DONNÉES, pas de code — la table `orientations` du rig,
		# et elle seule. Ce test attendait « trois, dont W à −90 » ; le designer est passé à une seule le
		# 2026-09-09 (« uniquement de face ») et le test aurait rougi sans qu'aucune règle soit violée. Il dit
		# maintenant la règle : au moins une vue, chacune avec un lacet déclaré dans le tour complet.
		var oris: Dictionary = rig.orientations
		var lacets_ok := oris.size() >= 1
		for cle in oris.keys():
			var la := float((oris[cle] as Dictionary).get("lacet", 999.0))
			if la < -180.0 or la > 180.0:
				lacets_ok = false
		verifier(rig.segments.has(rig.racine) and lacets_ok and rig.ordre.size() == rig.segments.size(), "rig %s : racine, %d orientation(s) déclarée(s) avec un lacet valide (%s), un ordre de départage complet" % [id, oris.size(), ", ".join(PackedStringArray(oris.keys()))])
	var h: Dictionary = GameData.entree("rigs", "humanoide")
	verifier(h.segments.size() == 15 and h.racine == "bassin" and h.slots_segments.casque == ["tete"] and h.prise_arme == "main_D", "rig humanoïde : 15 segments depuis la coupe du bassin, le casque peint la tête, l'arme à la main droite")
	verifier(GameData.config("palette_materiaux").has("cuir") and GameData.config("palette_materiaux").cuir.hex == "#8A5A33", "palette : Cuir #8A5A33")
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var pd := Paperdoll.new()
	pd.configurer(j, h, s.items, s.fonctionnalites, GameData.config("palette_materiaux"))
	var peints := pd._segments_peints()
	verifier(peints.has("torse") and peints.has("tete") and not peints.has("pied_G"), "l'équipement peint torse (cuirasse) et tête (casque), pas les pieds")
	var mat_torse := str(s.items.get(str(j.equipement.get("cuirasse", "")), {}).get("materiau", ""))
	var pal: Dictionary = GameData.config("palette_materiaux").get(mat_torse, {})   # le paperdoll lit la PALETTE, pas la couleur du matériau
	var teinte_attendue := Color.html(str(pal.hex)) if pal.has("hex") else Color(0.6, 0.6, 0.6)
	verifier(not str(peints.torse.construction).is_empty() and peints.torse.couleur == teinte_attendue, "la construction donne la forme, le matériau (%s) la teinte" % mat_torse)
	var monde := pd._poser_segments()
	verifier(monde.size() == 15 and monde.has("main_D") and monde.has("bassin"), "les 15 segments se placent depuis la racine (le bassin)")
	# LA PROFONDEUR (designer 2026-09-08, ordre de travail 26 quater bis) : de face, les deux épaules s'écartent à
	# l'écran ; de profil, elles se superposent et leur écart passe en PROFONDEUR — et c'est la profondeur, non plus
	# une liste écrite à la main, qui envoie le bras du fond derrière le torse.
	var face := pd._poser_segments()
	pd._lacet = deg_to_rad(90.0)   # le corps tourné vers la droite de l'écran
	var profil := pd._poser_segments()
	pd._lacet = 0.0
	var ecart_face: float = absf(float(face.bras_haut_G.origine.x) - float(face.bras_haut_D.origine.x))
	var ecart_profil: float = absf(float(profil.bras_haut_G.origine.x) - float(profil.bras_haut_D.origine.x))
	verifier(ecart_face > 8.0 and ecart_profil < 1.0 and not is_equal_approx(float(profil.bras_haut_G.z), float(profil.bras_haut_D.z)), "la profondeur : de face les épaules s'écartent (%.1f px), de profil elles se superposent (%.1f) et se séparent en profondeur" % [ecart_face, ecart_profil])
	var ordre_profil: Array = pd._ordre_profondeur(profil)
	var bras_fond := "bras_haut_D" if float(profil.bras_haut_D.z) > float(profil.bras_haut_G.z) else "bras_haut_G"
	var bras_devant := "bras_haut_G" if bras_fond == "bras_haut_D" else "bras_haut_D"
	verifier(ordre_profil.find(bras_fond) < ordre_profil.find("torse") and ordre_profil.find(bras_devant) > ordre_profil.find("torse"), "de profil, le bras du fond passe derrière le torse et l'autre devant (%s / %s)" % [bras_fond, bras_devant])
	pd.free()
	# Tutoriels : le premier combat déclenche « bascule tactique », une seule fois
	var tuto := Tutoriels.new()
	var vus: Array = []
	tuto.afficher = func(t: String) -> void: vus.append(t)
	add_child(tuto)
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)   # au contact : le combat tient
	s.grille.placer(loup.id, loup.pos)
	s._engager_combat(j, loup)
	s._fin_de_pas(j.horloge)
	verifier(vus.size() == 1 and tuto.vus.has("bascule_tactique"), "combat_started → tutoriel affiché une fois")
	EventBus.emettre(&"combat_started", ["x", []])
	EventBus.dispatcher()
	verifier(vus.size() == 1, "once : pas de seconde fois")
	tuto.queue_free()


# ---------------------------------------------------------------- Étape 6 : matériaux


## Les planches de sprites (Direction artistique, designer 2026-09-06, 20 h 50) : un dossier de PNG — des cases seules et des
## planches de cases —, assemblé par le jeu en une colonne de cases, dans l'ordre des noms ; un fichier hors format est
## ignoré ; un dossier absent compte zéro variante (le code dessine).
func test_planches() -> void:
	var dossier := "user://planches_test/a"
	DirAccess.make_dir_recursive_absolute(dossier)
	for f in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier + "/" + f)
	var c := Planches.case()
	var seule := Image.create(c, c, false, Image.FORMAT_RGBA8)
	seule.fill(Color(1, 0, 0, 1))
	seule.save_png(dossier + "/01_rouge.png")
	var planche := Image.create(c, c * 2, false, Image.FORMAT_RGBA8)
	planche.fill_rect(Rect2i(0, 0, c, c), Color(0, 1, 0, 1))
	planche.fill_rect(Rect2i(0, c, c, c), Color(0, 0, 1, 1))
	planche.save_png(dossier + "/02_vert_bleu.png")
	var travers := Image.create(50, 50, false, Image.FORMAT_RGBA8)
	travers.save_png(dossier + "/03_travers.png")
	Planches.vider()
	verifier(Planches.variantes(dossier) == 3, "trois cases : une seule, puis une planche de deux ; le fichier de 50 px est ignoré (%d)" % Planches.variantes(dossier))
	var img: Image = Planches.image(dossier)
	verifier(img != null and img.get_width() == c and img.get_height() == 3 * c, "l'image assemblée est une colonne de trois cases")
	if img != null:
		verifier(img.get_pixel(5, 5).is_equal_approx(Color(1, 0, 0, 1)) and img.get_pixel(5, c + 5).is_equal_approx(Color(0, 1, 0, 1)) and img.get_pixel(5, 2 * c + 5).is_equal_approx(Color(0, 0, 1, 1)), "rouge, vert, bleu : l'ordre des noms, puis l'ordre des cases de la planche")
	verifier(Planches.variantes("user://planches_test/absent") == 0 and Planches.variantes("membres/nul_part") == 0, "un dossier absent : zéro variante, le code dessine")
	verifier(Planches.index_locus("yeux", "grands") == 2 and Planches.index_locus("yeux", "inconnu") == -1, "la variante d'un trait est l'index de la valeur de son locus")
	Planches.vider()


## LES MARQUEURS DE VISAGE (designer 2026-09-09 : « avoir sur chaque forme de visage des marqueurs pour les autres
## éléments… une couleur par élément… le sprite de l'élément correspondant est centré sur le pixel »).
## Quatre choses à prouver, et la troisième est celle qu'on oublierait : le marqueur **ne se voit pas**.
func test_marqueurs_visage() -> void:
	var st: Dictionary = GameData.config("styles").get("planches", {})
	var table: Dictionary = st.get("marqueurs", {})
	verifier(table.has("yeux") and table.has("bouche"), "chaque élément du visage a SA couleur de marqueur (%d)" % table.size())
	# 1. LES ANCRES PAR DÉFAUT sont là où le visage les a toujours portés : deux yeux, une bouche.
	verifier(Planches.ancres_defaut("yeux").size() == 2 and Planches.ancres_defaut("bouche").size() == 1, "les ancres par défaut : deux yeux, une bouche")
	var c := float(Planches.case())
	var oeil_g: Vector2 = Planches.ancres_defaut("yeux")[0]
	verifier(oeil_g.x < c * 0.5 and oeil_g.y < c * 0.5, "l'œil gauche est à gauche et au-dessus du centre (%s)" % str(oeil_g))
	# 2. UNE TÊTE MARQUÉE dit où vont les autres éléments — et une tête à museau ne les met pas où une tête ronde les met.
	var i_museau := Planches.index_locus("tete", "museau")
	var mk: Dictionary = Planches.marqueurs("visage/tete", maxi(0, i_museau))
	verifier(mk.has("yeux") and (mk.yeux as Array).size() == 2 and mk.has("bouche"), "la tête « museau » porte ses marqueurs (%s)" % str(mk.keys()))
	if mk.has("bouche"):
		verifier(float((mk.bouche as Array)[0].y) > float(Planches.ancres_defaut("bouche")[0].y), "et sa bouche est PLUS BAS que la bouche par défaut : au bout du museau (%.1f contre %.1f)" % [float((mk.bouche as Array)[0].y), float(Planches.ancres_defaut("bouche")[0].y)])
	# 3. LE MARQUEUR NE SE VOIT PAS. C'est ce qu'on oublierait de vérifier, et ce serait un pixel rouge en plein
	# front. Le chargement le lit puis l'efface : aucune case de visage ne garde de couleur saturée.
	# On cherche les COULEURS DE MARQUEUR, pas « toute couleur » : une planche dessinée à la main a le droit d'avoir
	# du rouge sombre dans un œil ou du châtain dans des cheveux, et le premier jet de ce test l'accusait d'être un
	# marqueur oublié. *Un test trop large accuse le contenu au lieu de la règle.*
	var restants := 0
	var tol := float(st.get("marqueur_tolerance", 0.06))
	for dossier in ["visage/tete", "visage/yeux", "visage/bouche", "visage/oreilles"]:
		var img: Image = Planches.image(dossier)
		if img == null:
			continue
		for y in img.get_height():
			for x in img.get_width():
				var px := img.get_pixel(x, y)
				if px.a < 0.5:
					continue
				for element: String in table.keys():
					var col := Color.html(str(table[element]))
					if absf(px.r - col.r) <= tol and absf(px.g - col.g) <= tol and absf(px.b - col.b) <= tol:
						restants += 1
						break
	verifier(restants == 0, "aucun marqueur ne survit au chargement : il ne se voit jamais en jeu (%d pixel(s))" % restants)
	# 4. UNE PIÈCE PORTE LE SIEN, AU CENTRE : c'est lui que le jeu fera tomber sur chaque ancre, si bien qu'un seul
	# œil dessiné sert aux deux yeux.
	var i_fauves := Planches.index_locus("yeux", "fauves")
	var mp: Dictionary = Planches.marqueurs("visage/yeux", maxi(0, i_fauves))
	if i_fauves >= 0:
		verifier(mp.has("yeux") and (mp.yeux as Array).size() == 1, "l'œil « fauve » est une PIÈCE : un seul marqueur, le sien (%s)" % str(mp.keys()))
	# Et une planche que le designer a dessinée sans marqueur reste un visage entier : rien ne l'y oblige.
	var i_points := Planches.index_locus("yeux", "points")
	verifier(Planches.marqueurs("visage/yeux", maxi(0, i_points)).is_empty(), "une planche sans marqueur reste un visage entier — le marquage est un CHOIX, pas une obligation")
	# 5. LE CALQUE DES POINTS N'EST PAS UNE CASE (designer 2026-09-09 : « le sprite et un autre fichier
	# correspondant qui est juste les points »). C'est LE piège de cette convention : laissé dans la liste des
	# fichiers, `06_museau.points.png` se rangerait entre deux dessins et décalerait d'un rang tout ce qui suit —
	# chaque visage sauvegardé changerait de tête, sans erreur et sans message. Le compte le prouve.
	for locus_v in GameData.config("apparence").get("loci", []):
		var lid := str((locus_v as Dictionary).id)
		var n_v: int = (locus_v as Dictionary).valeurs.size()
		var n_p := Planches.variantes("visage/" + lid)
		if n_p > 0:
			verifier(n_p == n_v, "visage/%s : %d cases pour %d valeurs — un calque de points ne compte pas pour une case" % [lid, n_p, n_v])


## Les passes de dessin par le noyau (file 114, 2026-09-06) : le brouillard et les toits en tableaux de triangles — le noyau
## C++ rend les mêmes tableaux que PassesGD (points, couleurs, UV, végétaux), sur une fenêtre de ville, de jour et de nuit,
## avec et sans champ de vue, au sol et à l'étage.
func test_noyau_passes() -> void:
	verifier(Grille.noyau_present(), "le noyau C++ est chargé (sensen_grille)")
	if not Grille.noyau_present():
		return
	var s := Simulation.new(21)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var surf: Surface = s.monde.surface
	var cell: Vector2i = s.monde.cellule_camp + Vector2i(1, 0)
	surf.fiches_agglo.erase(cell)
	var fiche: Dictionary = surf.fiche_agglomeration(cell)
	var agglo: Dictionary = fiche.duplicate()
	agglo["quartier"] = "centre"
	agglo["index"] = 0
	var e: Dictionary = surf.generer_cellule(cell.x, cell.y, {}, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	if e.village.is_empty():
		surf._poser_quartier(e, cell, rng, agglo)
	s.monde.cellules[cell] = e
	s.grille = s.monde.fenetre(s.monde.centre, GameData.config("tile_contents"), s.regles.r.deplacement, int(s.regles.r.vision.hauteur_oeil))
	var g := s.grille
	verifier(g._noyau_pret(), "la fenêtre a son noyau")
	# le joueur sur la place du village, tout découvert autour, un champ de vue réel
	var centre: Vector2i = s.monde.pos_monde(cell, Vector2i(e.village.centre))
	g.liberer(j.pos)
	j.pos = s._tuile_libre_autour(centre)
	g.placer(j.id, j.pos)
	for dy in range(-30, 31):
		for dx in range(-30, 31):
			var t: Vector2i = j.pos + Vector2i(dx, dy)
			if g.dans(t):
				g.decouvert[g.idx(t)] = true
	j["vue_sale"] = true
	s.maj_vision()
	var od: Vector2i = g.origine + Vector2i(7, 3)
	var bat_j := int(g.bat_de[g.idx(j.pos)])
	var couleurs := PackedColorArray()
	var styles := PackedFloat32Array()
	for k in g.batiments_liste.size():
		couleurs.append(Color(0.2 + 0.1 * (k % 5), 0.5, 0.3, 1.0))
		styles.append(float(k % 3) * 8192.0)
	var ecarts := 0
	var n_tri := 0
	var chrono_gd := 0.0
	var chrono_cpp := 0.0
	for cas in [["vue", false, Vector2(0.6, 0.4), true, 0.8], ["tout vu", true, Vector2(0.0, 0.0), false, 0.0], ["nuit", false, Vector2(-0.5, 0.7), false, 0.0]]:
		var tout_vu: bool = cas[1]
		var vue: Dictionary = j.get("vue", {})
		var t0 := Time.get_ticks_usec()
		var b_gd := PassesGD.brouillard(g, vue, tout_vu, 0, g.contenu_ids.find("vide"), j.pos, 24, od, 40.0, 20.0, 4.0, 6, bat_j, 1, Color(0.05, 0.05, 0.08, 0.55), Color(0.02, 0.02, 0.04, 0.85), Color(0.05, 0.05, 0.08, 0.88), Color(0.02, 0.02, 0.04, 0.98))
		var t_gd := PassesGD.toits(g, vue, tout_vu, 0, g.contenu_ids.find("vide"), j.pos, 24, od, 40.0, 20.0, 4.0, 6, bat_j, couleurs, styles, 1.0, 8.0, 0.72, cas[2], cas[3], cas[4], 4096.0, 0.75, 0.55)
		var t1 := Time.get_ticks_usec()
		var b_cpp: Dictionary = g._noyau.brouillard(g, vue, tout_vu, 0, g.contenu_ids.find("vide"), j.pos, 24, od, 40.0, 20.0, 4.0, 6, bat_j, 1, Color(0.05, 0.05, 0.08, 0.55), Color(0.02, 0.02, 0.04, 0.85), Color(0.05, 0.05, 0.08, 0.88), Color(0.02, 0.02, 0.04, 0.98))
		var t_cpp: Dictionary = g._noyau.toits(g, vue, tout_vu, 0, g.contenu_ids.find("vide"), j.pos, 24, od, 40.0, 20.0, 4.0, 6, bat_j, couleurs, styles, 1.0, 8.0, 0.72, cas[2], cas[3], cas[4], 4096.0, 0.75, 0.55)
		var t2 := Time.get_ticks_usec()
		chrono_gd += float(t1 - t0) / 1000.0
		chrono_cpp += float(t2 - t1) / 1000.0
		n_tri += b_gd.points.size() / 3 + t_gd.points.size() / 3
		# LA FUSION DES APLATS (ligne 45 bis, 2026-09-08) : les tuiles voilées voisines en x, de même hauteur et de même
		# voile, ne font qu'un parallélogramme. Le garde-fou : il doit sortir NETTEMENT moins de quadrilatères que de
		# tuiles voilées — sans fusion il en sortirait un par tuile, plus trois par bloc. Si la fusion cesse d'opérer un
		# jour (une clé qui ne se compare plus, un ordre changé), ce nombre remonte et la suite le dit.
		if not tout_vu:
			var voilees := 0
			for dy in range(-24, 25):
				for dx in range(-24, 25):
					var tv: Vector2i = j.pos + Vector2i(dx, dy)
					if g.dans(tv) and not vue.has(g.idx(tv)):
						voilees += 1
			var pts_b: PackedVector2Array = b_gd.points
			var quads := pts_b.size() / 6
			verifier(voilees > 200 and quads < voilees, "le brouillard fond ses aplats : %d quadrilatères pour %d tuiles voilées (%.1f par tuile)" % [quads, voilees, float(quads) / maxf(1.0, float(voilees))])
		for paire in [[b_gd, b_cpp, "brouillard"], [t_gd, t_cpp, "toits"]]:
			var a: Dictionary = paire[0]
			var b: Dictionary = paire[1]
			if a.points.size() != b.points.size() or a.couleurs.size() != b.couleurs.size() or a.uvs.size() != b.uvs.size() or a.indices != b.indices or a.veg_vus != b.veg_vus or a.veg_voiles != b.veg_voiles:
				ecarts += 1
				print("  écart de taille (%s, %s) : %d/%d points, %d/%d végétaux vus" % [str(cas[0]), str(paire[2]), a.points.size(), b.points.size(), a.veg_vus.size(), b.veg_vus.size()])
				continue
			for i in a.points.size():
				if not a.points[i].is_equal_approx(b.points[i]) or not a.uvs[i].is_equal_approx(b.uvs[i]) or not a.couleurs[i].is_equal_approx(b.couleurs[i]):
					ecarts += 1
					print("  écart (%s, %s) au triangle %d : %s / %s, %s / %s" % [str(cas[0]), str(paire[2]), i / 3, str(a.points[i]), str(b.points[i]), str(a.couleurs[i]), str(b.couleurs[i])])
					break
	# LA PREUVE DE LA FUSION (ligne 45 bis, 2026-09-08) : le brouillard par tuile et le brouillard fondu, découpés
	# par LA MÊME règle, doivent donner exactement les mêmes losanges. Un quadrilatère dont P1−P0 vaut (tw2, −th2)
	# et P3−P0 (N·tw2, N·th2) est un trait de N losanges (N = 1 compris : un losange seul, ou le dessus d'un bloc) ;
	# le reste — les deux flancs d'un bloc — garde sa forme entière. Aucun côté n'est privilégié, donc un écart est
	# un VRAI écart : la première version de cette preuve classait les deux côtés différemment et annonçait 193
	# différences qui n'existaient pas.
	var vue_p: Dictionary = j.get("vue", {})
	var av := PassesGD.brouillard_par_tuile(g, vue_p, false, 0, g.contenu_ids.find("vide"), j.pos, 24, od, 40.0, 20.0, 4.0, 6, bat_j, 1, Color(0.05, 0.05, 0.08, 0.55), Color(0.02, 0.02, 0.04, 0.85), Color(0.05, 0.05, 0.08, 0.88), Color(0.02, 0.02, 0.04, 0.98))
	var ap := PassesGD.brouillard(g, vue_p, false, 0, g.contenu_ids.find("vide"), j.pos, 24, od, 40.0, 20.0, 4.0, 6, bat_j, 1, Color(0.05, 0.05, 0.08, 0.55), Color(0.02, 0.02, 0.04, 0.85), Color(0.05, 0.05, 0.08, 0.88), Color(0.02, 0.02, 0.04, 0.98))
	var sacs: Array = [{}, {}]
	for lequel in 2:
		var res2: Dictionary = av if lequel == 0 else ap
		var sac: Dictionary = sacs[lequel]
		var p: PackedVector2Array = res2.points
		var cl: PackedColorArray = res2.couleurs
		var q := 0
		while q + 5 < p.size():
			var p0 := p[q]
			var p1 := p[q + 1]
			var p2 := p[q + 2]
			var p3 := p[q + 5]
			var col2: Color = cl[q]
			var n_los := 0
			if is_equal_approx(p1.x - p0.x, 20.0) and is_equal_approx(p1.y - p0.y, -10.0):
				var h_los := (p3.y - p0.y) / 10.0
				if h_los >= 0.99 and is_equal_approx(p3.y - p0.y, roundf(h_los) * 10.0) and is_equal_approx(p3.x - p0.x, roundf(h_los) * 20.0):
					n_los = int(roundf(h_los))
			if n_los > 0:
				for u in n_los:
					var ca2 := p0 + Vector2(20.0 * (u + 1), 10.0 * u)   # le centre du u-ième losange du trait
					var cle2 := "L|%.1f|%.1f|%s" % [ca2.x, ca2.y, col2]
					sac[cle2] = int(sac.get(cle2, 0)) + 1
			else:
				var cle3 := "Q|%.1f|%.1f|%.1f|%.1f|%.1f|%.1f|%s" % [p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, col2]
				sac[cle3] = int(sac.get(cle3, 0)) + 1
			q += 6
	var sac_av: Dictionary = sacs[0]
	var sac_ap: Dictionary = sacs[1]
	var ecarts_f := 0
	for cle5 in sac_av:
		if int(sac_ap.get(cle5, 0)) != int(sac_av[cle5]):
			ecarts_f += 1
	for cle6 in sac_ap:
		if not sac_av.has(cle6):
			ecarts_f += 1
	var pts_av: PackedVector2Array = av.points
	var pts_ap: PackedVector2Array = ap.points
	var quads_av := pts_av.size() / 6
	var quads_ap := pts_ap.size() / 6
	print("PREUVE FUSION : ancien %d formes / %d quadrilatères, fondu %d formes / %d quadrilatères, %d écarts" % [sac_av.size(), quads_av, sac_ap.size(), quads_ap, ecarts_f])
	verifier(ecarts_f == 0 and sac_av.size() > 100, "la fusion couvre exactement les mêmes losanges que l'ancien brouillard (%d écarts, %d quadrilatères au lieu de %d)" % [ecarts_f, quads_ap, quads_av])
	verifier(ecarts == 0 and n_tri > 100, "brouillard et toits : le noyau rend les mêmes tableaux que PassesGD (%d triangles sur trois cas, GDScript %.1f ms, C++ %.1f ms)" % [n_tri, chrono_gd, chrono_cpp])
	# Le toit MÉMORISÉ, hors de vue, s'assombrissait de 0,55 écrit en dur dans les deux implémentations, alors que
	# `styles.brouillard.toit_memorise` porte la valeur et que le `_doc` la promet (2026-09-07). On vérifie que le
	# réglage est vivant des deux côtés : une autre valeur doit donner d'autres couleurs, et les mêmes des deux.
	# Une vue VIDE et tout_vu faux : tout ce qui est decouvert tombe dans la branche « memorise, hors de vue ».
	var vue0: Dictionary = {}
	var clair := PassesGD.toits(g, vue0, false, 0, g.contenu_ids.find("vide"), j.pos, 24, od, 40.0, 20.0, 4.0, 6, bat_j, couleurs, styles, 1.0, 8.0, 0.72, Vector2(0.6, 0.4), true, 0.8, 4096.0, 0.75, 0.0)
	var sombre := PassesGD.toits(g, vue0, false, 0, g.contenu_ids.find("vide"), j.pos, 24, od, 40.0, 20.0, 4.0, 6, bat_j, couleurs, styles, 1.0, 8.0, 0.72, Vector2(0.6, 0.4), true, 0.8, 4096.0, 0.75, 0.9)
	var clair_c: Dictionary = g._noyau.toits(g, vue0, false, 0, g.contenu_ids.find("vide"), j.pos, 24, od, 40.0, 20.0, 4.0, 6, bat_j, couleurs, styles, 1.0, 8.0, 0.72, Vector2(0.6, 0.4), true, 0.8, 4096.0, 0.75, 0.0)
	verifier(clair.couleurs != sombre.couleurs and clair.couleurs == clair_c.couleurs, "toit_memorise est un réglage vivant : 0,0 et 0,9 ne rendent pas les mêmes toits, et le noyau suit le GDScript")
	# ce que le client montre de chaque être : les mêmes drapeaux
	var positions := PackedVector2Array()
	for x in s.vivants():
		positions.append(Vector2(x.pos.x, x.pos.y))
	var rng_p := RandomNumberGenerator.new()
	rng_p.seed = 7
	for k in 200:   # des positions au hasard, dans la fenêtre et hors d'elle, au sol et à l'étage
		positions.append(Vector2(j.pos.x + rng_p.randi_range(-40, 40), j.pos.y + rng_p.randi_range(-40, 40) + (Grille.BANDE_Z if rng_p.randf() < 0.2 else 0)))
	var v_gd := PassesGD.visibles(g, j.get("vue", {}), false, 0, g.contenu_ids.find("vide"), j.pos, 24, bat_j, positions)
	var v_cpp: PackedByteArray = g._noyau.visibles(g, j.get("vue", {}), false, 0, g.contenu_ids.find("vide"), j.pos, 24, bat_j, positions)
	var n_vus := 0
	for f in v_gd:
		if f & 1:
			n_vus += 1
	verifier(v_gd == v_cpp and v_gd.size() == positions.size() and n_vus > 0, "visibles : les mêmes drapeaux pour %d positions (%d en vue)" % [positions.size(), n_vus])
	# la minimap : les mêmes octets pour la cellule du joueur (Minimap et brouillard de guerre, 2026-09-07)
	var mini_col := {}
	for mid in GameData.catalogues.materials.keys():
		if GameData.catalogues.materials[mid].has("color"):
			mini_col[str(mid)] = Color.html(str(GameData.catalogues.materials[mid].color))
	var taille_mini := int(GameData.config("planete").taille_cellule)
	var cell_mini := Rect2i(s.monde.cellule_de(j.pos) * taille_mini, Vector2i(taille_mini, taille_mini))
	var tmini0 := Time.get_ticks_usec()
	var mini_gd := PassesGD.minimap(g, cell_mini, 128, mini_col, Color(0.02, 0.02, 0.03))
	var tmini1 := Time.get_ticks_usec()
	var mini_cpp: PackedByteArray = g._noyau.minimap(g, cell_mini.position, cell_mini.size, 128, mini_col, Color(0.02, 0.02, 0.03))
	var tmini2 := Time.get_ticks_usec()
	var teintes_mini := {}
	for k in 128 * 128:
		teintes_mini[mini_gd.slice(k * 4, k * 4 + 3)] = true
	verifier(mini_gd == mini_cpp and mini_gd.size() == 128 * 128 * 4 and teintes_mini.size() >= 4, "minimap : les mêmes octets (%d teintes ; GDScript %.1f ms, C++ %.2f ms)" % [teintes_mini.size(), float(tmini1 - tmini0) / 1000.0, float(tmini2 - tmini1) / 1000.0])
	# les morceaux de terrain autour du joueur : les mêmes triangles, les mêmes coupures, les mêmes végétaux
	var mat_col := {}
	var mat_st := {}
	var k_m := 0
	for mid in GameData.catalogues.materials.keys():
		var md: Dictionary = GameData.catalogues.materials[mid]
		if md.has("color"):
			mat_col[str(mid)] = Color.html(str(md.color))
		mat_st[str(mid)] = float(k_m % 4) * 8192.0
		k_m += 1
	mat_st["eau"] = 8192.0
	var meuble_col := {}
	var meuble_emprise := {}
	for mid in GameData.catalogues.meubles.keys():
		meuble_col[str(mid)] = Color.html(str(GameData.catalogues.meubles[mid].get("couleur", "#7a6a4a")))
		meuble_emprise[str(mid)] = float(GameData.catalogues.meubles[mid].get("emprise", 0.6))
	var contenu_col := PackedColorArray()
	contenu_col.resize(g.contenu_ids.size())
	for k in g.contenu_ids.size():
		var def: Dictionary = g.contenu_defs.get(g.contenu_ids[k], {})
		contenu_col[k] = Color.html(str(def.couleur)) if def.has("couleur") else Color(1, 1, 1, 1)
	var bat_mur := PackedStringArray()
	var bat_pierre := PackedStringArray()
	var bat_bois := PackedStringArray()
	for info in g.batiments_liste:
		bat_mur.append(str(info.get("mur", "")))
		bat_pierre.append(str(info.get("pierre", "")))
		bat_bois.append(str(info.get("bois", "")))
	var prm := {"origine_dessin": od, "tw": 40.0, "th": 20.0, "hstep": 8.0, "uv_haut": 4096.0, "uv_so": -1000.0, "uv_se": -2000.0, "uv_pas_face": 32.0,
		"niveau_u": 6, "bloc_u": 2, "porte_u": 4, "mur_coupe_u": 1, "bat_j": bat_j, "mat_col": mat_col, "mat_st": mat_st, "meuble_col": meuble_col,
		"meuble_emprise": meuble_emprise, "materiau_mur_defaut": "granit", "contenu_col": contenu_col, "bat_mur_id": bat_mur, "bat_pierre_id": bat_pierre, "bat_bois_id": bat_bois}
	var ecarts_m := 0
	var n_tri_m := 0
	var n_coup := 0
	var chrono_gd_m := 0.0
	var chrono_cpp_m := 0.0
	var coin_j := Vector2i((j.pos.x - g.origine.x) / 8, (j.pos.y - g.origine.y) / 8)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var coin := coin_j + Vector2i(dx, dy)
			if coin.x < 0 or coin.y < 0:
				continue
			var t0m := Time.get_ticks_usec()
			var m_gd := PassesGD.morceau(g, coin, 8, prm)
			var t1m := Time.get_ticks_usec()
			var m_cpp: Dictionary = g._noyau.morceau(g, coin, 8, prm)
			var t2m := Time.get_ticks_usec()
			chrono_gd_m += float(t1m - t0m) / 1000.0
			chrono_cpp_m += float(t2m - t1m) / 1000.0
			n_tri_m += m_gd.points.size() / 3
			n_coup += m_gd.coupures.size() / 3
			if m_gd.points.size() != m_cpp.points.size() or m_gd.coupures != m_cpp.coupures or m_gd.vegetaux != m_cpp.vegetaux:
				ecarts_m += 1
				print("  écart de taille (morceau %s) : %d/%d points, coupures %d/%d, végétaux %d/%d" % [str(coin), m_gd.points.size(), m_cpp.points.size(), m_gd.coupures.size(), m_cpp.coupures.size(), m_gd.vegetaux.size(), m_cpp.vegetaux.size()])
				continue
			for i in m_gd.points.size():
				if not m_gd.points[i].is_equal_approx(m_cpp.points[i]) or not m_gd.uvs[i].is_equal_approx(m_cpp.uvs[i]) or not m_gd.couleurs[i].is_equal_approx(m_cpp.couleurs[i]):
					ecarts_m += 1
					print("  écart (morceau %s) au triangle %d : %s / %s, %s / %s, uv %s / %s" % [str(coin), i / 3, str(m_gd.points[i]), str(m_cpp.points[i]), str(m_gd.couleurs[i]), str(m_cpp.couleurs[i]), str(m_gd.uvs[i]), str(m_cpp.uvs[i])])
					break
	verifier(ecarts_m == 0 and n_tri_m > 500 and n_coup > 0, "les morceaux de terrain : le noyau rend les mêmes tableaux que PassesGD (%d triangles, %d coupures sur 25 morceaux, GDScript %.1f ms, C++ %.1f ms)" % [n_tri_m, n_coup, chrono_gd_m, chrono_cpp_m])
	# à l'étage : la vue par l'air, les mêmes tableaux
	var esc := Vector2i(-1, -1)
	for bat in e.village.batiments:
		if bat.has("escalier") and g.a_lien(s.monde.pos_monde(cell, bat.escalier)):
			esc = s.monde.pos_monde(cell, bat.escalier)
			break
	if esc.x >= 0:
		var haut := g.lien_de(esc)
		g.liberer(j.pos)
		j.pos = haut
		g.placer(j.id, haut)
		j["vue_sale"] = true
		s.maj_vision()
		var bj := int(g.bat_de[g.idx(haut)])
		var vue_e: Dictionary = j.get("vue", {})
		var b_gd := PassesGD.brouillard(g, vue_e, false, 1, g.contenu_ids.find("vide"), Grille.plat(haut), 24, od, 40.0, 20.0, 4.0, 6, bj, 1, Color(0.05, 0.05, 0.08, 0.55), Color(0.02, 0.02, 0.04, 0.85), Color(0.05, 0.05, 0.08, 0.88), Color(0.02, 0.02, 0.04, 0.98))
		var b_cpp: Dictionary = g._noyau.brouillard(g, vue_e, false, 1, g.contenu_ids.find("vide"), Grille.plat(haut), 24, od, 40.0, 20.0, 4.0, 6, bj, 1, Color(0.05, 0.05, 0.08, 0.55), Color(0.02, 0.02, 0.04, 0.85), Color(0.05, 0.05, 0.08, 0.88), Color(0.02, 0.02, 0.04, 0.98))
		var t_gd := PassesGD.toits(g, vue_e, false, 1, g.contenu_ids.find("vide"), Grille.plat(haut), 24, od, 40.0, 20.0, 4.0, 6, bj, couleurs, styles, 1.0, 8.0, 0.72, Vector2(0.6, 0.4), true, 0.8, 4096.0, 0.75, 0.55)
		var t_cpp: Dictionary = g._noyau.toits(g, vue_e, false, 1, g.contenu_ids.find("vide"), Grille.plat(haut), 24, od, 40.0, 20.0, 4.0, 6, bj, couleurs, styles, 1.0, 8.0, 0.72, Vector2(0.6, 0.4), true, 0.8, 4096.0, 0.75, 0.55)
		verifier(b_gd.points == b_cpp.points and b_gd.couleurs == b_cpp.couleurs and t_gd.points == t_cpp.points and t_gd.couleurs == t_cpp.couleurs and b_gd.points.size() > 0, "à l'étage, la rue vue par l'air : les mêmes tableaux (%d triangles de brouillard)" % (b_gd.points.size() / 3))
