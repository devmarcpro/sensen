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
		if (g.danger_a[i] == 1) != g.dangers.has(i):
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
	sv.monde.fermer()


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


func test_grille() -> void:
	var s := nouvelle_sim("gorge")
	var g := s.grille
	verifier(g.largeur == 32 and g.hauteur_grille == 32, "arène 32×32 chargée depuis JSON")
	# Rampe sud : 10 → 9 → 8 → 7 : descente = 2 ticks, montée +1 = 5 ticks
	verifier(g.cout_pas(Vector2i(16, 31), Vector2i(16, 30)) == 2, "descente −1 : 2 ticks")
	verifier(g.cout_pas(Vector2i(16, 30), Vector2i(16, 31)) == 5, "montée +1 : 5 ticks")
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
	verifier(synth.cout_pas(Vector2i(0, 0), Vector2i(1, 0)) == 8 and synth.cout_pas(Vector2i(1, 0), Vector2i(2, 0)) == 2, "montée +2 : 8 ; descente −2 : 2")
	verifier(g.cout_pas(Vector2i(10, 10), Vector2i(9, 10)) == 5, "rampe du plateau")
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
	verifier(r.ticks_attaque(GameData.entree("functionalities", "epee"), false) == 5, "épée : 10 / 2.0 = 5 ticks")
	verifier(r.ticks_attaque(GameData.entree("functionalities", "dague"), false) == 3, "dague : 3 ticks")
	verifier(r.ticks_attaque(GameData.entree("functionalities", "masse"), true) == 16, "masse lourde : 8 × 2 = 16 ticks")
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
	j["immobile_depuis"] = s.horloge_monde.ticks - 100
	j.tick_vigueur = s.horloge_monde.ticks
	s._regenerer(j, s.horloge_monde.ticks + 10)
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
	s.horloge_monde.avancer(1)
	verifier(s.attente.has(j.id), "en exploration, le joueur est en attente d'intention")
	var avant: int = j.compteur
	verifier(s.intention(j.id, {"type": "deplacer", "vers": j.pos + Vector2i(0, -1)}), "intention de déplacement acceptée")
	verifier(j.compteur == s.horloge_monde.ticks + 3, "déplacement plat : 3 ticks")
	verifier(not s.intention(j.id, {"type": "deplacer", "vers": j.pos + Vector2i(0, -1)}), "pas d'intention hors attente")
	verifier(not s.attente.has(j.id), "intention consommée")
	# Placer un loup adjacent et le faire détecter : combat, horloge dédiée, compteurs rebasés.
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	loup.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
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
	bandit.compteur = h.ticks + 100
	s.pas(j.horloge)
	verifier(s.attente.has(j.id), "le joueur est dû")
	j.orientation = Vector2i(0, -1)   # face au bandit
	verifier(s.intention(j.id, {"type": "garde"}), "prendre la garde")
	verifier(j.garde and j.compteur == h.ticks + 2, "garde : 2 ticks, posture active")
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
	j.compteur = h.ticks + 100
	pv = j.sante
	s.pas(j.horloge)
	verifier(coups.size() == 2 and not coups[1].garde and coups[1].direction == "flanc", "de flanc, la garde est ignorée (perdu %d)" % (pv - j.sante))
	# Attaque lourde du joueur : télégraphée (engagée, résolue à l'échéance), ×2 ticks, brise la garde.
	j.compteur = h.ticks
	bandit.compteur = h.ticks + 100
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
	bandit.compteur = h.ticks + 100
	s.pas(j.horloge)
	var t: int = h.ticks
	verifier(s.intention(j.id, {"type": "attendre"}), "attendre")
	verifier(j.vigueur == 30 and j.compteur == t + 5, "attendre : +20 endurance, 5 ticks")
	# À zéro d'endurance : garde impossible.
	j.vigueur = 0
	j.tick_vigueur = h.ticks + 100
	j.compteur = h.ticks + 5
	s.pas(j.horloge)
	verifier(not s.intention(j.id, {"type": "garde"}), "à zéro d'endurance, garde impossible")


# ---------------------------------------------------------------- Temporalités parallèles

func test_horloges() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	s.horloge_monde.avancer(50)
	verifier(s.horloge_monde.ticks == 50, "l'horloge du monde avance en temps réel")
	var loup: Dictionary = s.entites["loup_2"]
	s._engager_combat(j, loup)
	var hc := s.horloge_de(j)
	verifier(hc.ticks == 0 and hc.nom.begins_with("combat_"), "un combat naît avec sa propre horloge à 0")
	s.horloge_monde.avancer(100)
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
	w.poser(j, "feu", 10)
	w.decroitre(j, 39)
	verifier(j.segments.size() == 2, "à 29 ticks du dernier segment : rien ne tombe")
	w.decroitre(j, 40)
	verifier(j.segments.size() == 1 and j.segments[0].element == "bois", "à 30 ticks : le dernier posé tombe")
	w.decroitre(j, 70)
	verifier(j.segments.is_empty(), "à 60 ticks : la barre est vide")
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
	s.horloge_monde.avancer(1)
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
	s.horloge_monde.avancer(1)
	verifier(s.intention(j.id, {"type": "changer_arme", "item": bouclier}), "prendre le bouclier")
	verifier(j.equipement.get("main_secondaire", "") == bouclier, "bouclier en main secondaire")
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	verifier(s.intention(j.id, {"type": "changer_arme", "item": lance}), "prendre la lance (deux mains)")
	verifier(not j.equipement.has("main_secondaire"), "une arme à deux mains range le bouclier")
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	verifier(not s.intention(j.id, {"type": "changer_arme", "item": bouclier}), "pas de bouclier avec une arme à deux mains")
	verifier(not s.intention(j.id, {"type": "changer_arme", "item": "inconnu"}), "objet hors râtelier refusé")


# ---------------------------------------------------------------- Modules : assemblage, mana, formes

func test_capacites() -> void:
	var cap := Capacites.new(GameData.catalogues["modules"])
	# L'exemple chiffré de la note Modules : [Ligne] + [Flamme] + [Concentration] = 12 ticks, 12 mana, 3d6
	var p := cap.assembler(["ligne", "flamme", "concentration"], 5, "2d6", {"metal": 1.0})
	verifier(p.erreurs.is_empty() and p.ticks == 12 and p.monnaie == "mana" and p.ressource == 12, "[Ligne]+[Flamme]+[Concentration] : 12 ticks · 12 mana")
	verifier(p.des == "2d6" and p.des_bonus == 2 and p.geometrie == "ligne" and p.taille == 4 and p.elements == {"feu": 1.0}, "4d6 de Feu sur 4 tuiles en ligne (Flamme, palier moyen : +1 dé ; Concentration : +1)")
	# [Ligne] + [Frappe] + [Concentration] avec une épée : 9 ticks · 10 endurance, à l'élément de l'arme
	p = cap.assembler(["ligne", "frappe", "concentration"], 5, "2d6", {"metal": 1.0})
	verifier(p.ticks == 9 and p.monnaie == "vigueur" and p.ressource == 10 and p.elements == {"metal": 1.0}, "[Ligne]+[Frappe]+[Concentration] : 9 ticks · 10 vigueur · Métal")
	# Vivacité : −3 ticks, ressource ×1.3 ; Soi rend 2 ticks
	p = cap.assembler(["point", "etincelle", "vivacite"], 5, "1d4", {})
	verifier(p.ticks == 1 and p.ressource == 4, "Étincelle + Vivacité : max(1, 3−3) tick · 3×1.3 ≈ 4 mana")
	p = cap.assembler(["soi", "baume"], 5, "1d4", {})
	verifier(p.ticks == 6 and p.ressource == 10 and p.geometrie == "soi", "[Soi]+[Baume] : 6 ticks · 10 mana")
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
	verifier(s.appliquer_statut(j, "poison", 50, chef.id), "poison appliqué")
	var pv: int = j.sante
	chef.compteur = h.ticks + 10
	j.compteur = h.ticks + 100
	s.pas(j.horloge)   # le chef agit à t+10 : le poison tique
	verifier(j.sante < pv and j.statuts.size() == 1, "le poison fait des dégâts périodiques")
	# Anti-stunlock : un contrôle dur est plafonné à 20 ticks, puis verrouillé 50 ticks
	verifier(s.appliquer_statut(j, "enracinement", 40, chef.id), "enracinement appliqué")
	var enr: Dictionary = j.statuts.back()
	verifier(int(enr.fin) - h.ticks <= 20, "contrôle dur plafonné à 20 ticks")
	verifier(not s.appliquer_statut(j, "etourdi", 10, chef.id), "réapplication refusée (verrou 50 ticks)")
	verifier(int(j.anti_stunlock_jusqua) == h.ticks + 20 + 50, "verrou = fin + 50")
	# Enraciné : le déplacement est refusé
	j.compteur = h.ticks
	chef.compteur = h.ticks + 500
	s.pas(j.horloge)
	verifier(not s.intention(j.id, {"type": "deplacer", "vers": j.pos + Vector2i(0, 1)}), "enraciné : pas de déplacement")
	verifier(s.intention(j.id, {"type": "attendre"}), "mais on peut attendre")
	# Interruption : le chef (élite, jauge) engage une lourde ; Étourdi coupe l'action et retire un segment
	chef.chaine.segments = [{"element": "metal", "tick": h.ticks}, {"element": "eau", "tick": h.ticks}]
	chef.chaine.tick_ref = h.ticks
	chef.anti_stunlock_jusqua = -1
	chef.action_en_cours = {"type": "arme", "cible": j.id, "lourde": true, "ticks": 10, "name_key": "x"}
	verifier(s.appliquer_statut(chef, "etourdi", 10, j.id), "Étourdi sur le chef")
	verifier(chef.action_en_cours.is_empty() and chef.chaine.segments.size() == 1, "interruption : action coupée, dernier segment retiré")
	# Ralliement : ×1.15 dégâts ; Ralentissement : coûts ticks ×1.3
	s.appliquer_statut(j, "ralentissement", 30, chef.id)
	j.compteur = h.ticks
	s.pas(j.horloge)
	var t: int = h.ticks
	j.statuts = j.statuts.filter(func(x: Dictionary) -> bool: return x.id != "enracinement")
	verifier(s.intention(j.id, {"type": "deplacer", "vers": j.pos + Vector2i(0, 1)}), "déplacement ralenti")
	verifier(j.compteur == t + 4, "3 ticks × 1.3 ≈ 4")
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
	verifier(p.ticks == 3 + 1 + (3 + 3) and p.ressource == 3 and p.charge_suivante.ressource == 3, "ticks : 3 + 1 + 6 ; chaque charge paie son mana")
	p = cap.assembler(["point", "flamme", "repetition"], 5, "1d4", {})
	verifier(p.ticks == 12 and p.liaisons.size() == 1 and p.liaisons[0].rejoue == 2, "[Point]+[Flamme]+[Répétition] : 12 ticks, rejoue 2 fois")
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
	j.compteur = h.ticks + 500
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
	loup.compteur = h.ticks + 500
	s.pas(j.horloge)
	var pv: int = loup.sante
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loup.pos}), "Mèche + Étincelle")
	verifier(s.differes.size() == 1 and loup.sante == pv, "la charge est différée, rien ne part encore")
	loup.compteur = h.ticks + 25
	j.compteur = h.ticks + 600
	s.pas(j.horloge)   # le loup agit à t+25 : la mèche (t+20) est tiquée en fin de pas
	verifier(s.differes.is_empty() and loup.sante < pv, "20 ticks plus tard, l'Étincelle part")
	# Barrière : occupe la tuile, bloque le passage, disparaît après 50 ticks
	for m0 in ["tuile", "barriere", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["tuile", "barriere", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "b", "name_key": "capacite.etincelle.name", "modules": ["tuile", "jet_court", "barriere"]}
	j.compteur = h.ticks
	loup.compteur = h.ticks + 500
	s.pas(j.horloge)
	var mur_pos: Vector2i = j.pos + Vector2i(1, -1)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": mur_pos}), "Barrière")
	s.pas(j.horloge)   # 15 ticks : télégraphée
	verifier(s.grille.bloque_passage(mur_pos) and s.obstacles.size() == 1, "la barrière bloque la tuile")
	loup.compteur = h.ticks + 60
	j.compteur = h.ticks + 600
	s.pas(j.horloge)
	verifier(not s.grille.bloque_passage(mur_pos) and s.obstacles.is_empty(), "après 50 ticks, la barrière disparaît")
	# Exhaussement : +1 niveau ; Fosse : −3 niveaux et ce qui est dessus chute
	for m0 in ["tuile", "exhaussement", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["tuile", "exhaussement", "jet_court"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "e", "name_key": "capacite.etincelle.name", "modules": ["tuile", "jet_court", "exhaussement"]}
	j.compteur = h.ticks
	loup.compteur = h.ticks + 500
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
	loup.compteur = h.ticks + 500
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
	j.compteur = h.ticks + 500
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
		loups[0].compteur = h.ticks + 500
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
	verifier(loup.compteur == t + 2, "le loup se déplace en 2 ticks")
	# Modules : ticks / skill_factor, plancher 50 % ; ressource / skill_factor
	var cap := Capacites.new(GameData.catalogues["modules"])
	var p := cap.assembler(["ligne", "flamme", "concentration"], 5, "2d6", {}, {"flamme": 50, "ligne": 50, "concentration": 50})
	verifier(p.ticks == 4 + 1 + 1 and p.ressource == 4 + 4, "niveau 50 partout : (8+2+2)/2 = 6 ticks · 8/2 + 4 = 8 mana")
	p = cap.assembler(["ligne", "flamme"], 5, "2d6", {}, {"flamme": 1000})
	verifier(p.ticks == 4 + 2, "plancher : Flamme ne descend jamais sous 4 ticks")


# ---------------------------------------------------------------- Étape 1 : rigs, paperdoll, tutoriels

func test_paperdoll_et_tutoriels() -> void:
	for id in ["humanoide", "quadrupede", "volant", "amorphe"]:
		var rig: Dictionary = GameData.entree("rigs", id)
		verifier(rig.segments.has(rig.racine) and rig.facings.has("S") and rig.facings.SW.miroir == "SE", "rig %s : racine, facings, miroir" % id)
	var h: Dictionary = GameData.entree("rigs", "humanoide")
	verifier(h.segments.size() == 14 and h.slots_segments.casque == ["tete"] and h.prise_arme == "main_D", "rig humanoïde : 14 segments, le casque peint la tête, l'arme à la main droite")
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
	var monde := pd._poser_segments(h.facings.S, false)
	verifier(monde.size() == 14 and monde.has("main_D"), "les 14 segments se placent depuis la racine")
	var miroir := pd._poser_segments(h.facings.SE, true)
	var droit := pd._poser_segments(h.facings.SE, false)
	verifier(is_equal_approx(miroir.main_D.origine.x, -droit.main_D.origine.x), "le miroir inverse l'axe horizontal")
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
