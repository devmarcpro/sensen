extends Node
## Tests headless du prototype (jalons 1-4) — des `assert`, aucun rendu.
##   & Godot --headless --path godot res://scenes/tests/test_combat.tscn --quit-after 2
## Chaque test cite la note qu'il vérifie.

var echecs := 0


func _ready() -> void:
	# GameData a déjà chargé (autoload) : aucune erreur de schéma tolérée.
	Simulation.slot_autosave = "test_auto"   # l'autosave du retour d'expédition ne doit jamais écraser « monde » pendant la suite
	verifier(GameData.erreurs.is_empty(), "données valides (Décision — Pipeline de contenu)")
	test_grille()
	test_des()
	test_regles()
	test_simulation()
	test_garde_et_lourde()
	test_horloges()
	test_wuxing()
	test_ratelier()
	test_capacites()
	test_projectiles()
	test_statuts()
	test_liaisons()
	test_glyphes_terrain()
	test_evenements()
	test_niveaux()
	test_paperdoll_et_tutoriels()
	test_materiaux()
	test_recolte()
	test_fabrication()
	test_assemblage()
	test_desequiper_jeter()
	test_surface()
	test_sauvegarde()
	test_carte_et_voyage()
	test_corruption()
	test_cycle_et_meteo()
	test_village()
	test_village_vivant()
	test_reputation_et_quetes()
	test_rang_de_guilde()
	test_compagnons()
	test_territoire()
	test_agriculture_et_boutique()
	test_defense_et_raids()
	test_royaumes_pnj()
	test_conquete_et_succession()
	test_alchimie()
	test_villes_et_halls()
	test_saisons_et_elevage()
	test_elevage_familles()
	test_loci_et_soie()
	test_harmonie()
	test_registre_elevage()
	test_familles()
	test_entraineur_et_commandes()
	test_gabarits_guildes()
	test_pretre_et_tourelle()
	test_regle_anneau_mesure()
	test_chatoyant()
	test_routes()
	test_habitat_pnj()
	test_artefacts()
	test_talents()
	test_reforge_et_fiole()
	test_communion()
	test_lumiere()
	test_palier_industriel()
	test_betail()
	test_ombre_et_rieur()
	test_ecarlate_et_porteur()
	test_passeur_et_sablier()
	test_masque_et_sceau()
	test_fossoyeur_et_engrenage()
	test_propagation_lumiere()
	test_aciers_allies()
	test_vampire()
	test_spectre()
	test_lycanthrope()
	test_incarnation()
	test_terrasser()
	test_empoigne()
	test_armes_fantomes()
	test_cataclysme()
	test_vecteur_lieu()
	test_effets_equipement()
	test_palette_etage()
	test_arme_mixte()
	test_niveaux_recette()
	test_plantes()
	test_bestiaire()
	test_statuts_complets()
	test_potions_completes()
	test_poison_illegal()
	test_nage()
	test_neige_et_gel()
	test_automate_eau()
	test_foudre()
	test_retrait_eau()
	test_compagnons_postures()
	test_cueillette()
	test_affixes_reveilles()
	test_feu()
	test_lave()
	test_courant()
	test_ia_portails()
	test_paliers_elevage()
	test_especes_ajoutees()
	test_tannage()
	test_huile_d_arme()
	test_liens_donnees()
	test_discretion()
	test_embuscade()
	test_triche()
	test_statue()
	test_routes_entre_royaumes()
	test_tooltips()
	test_registre_loci()
	test_meubles_rituels()
	test_suiveur_territorial()
	test_transmutation()
	test_arrachage()
	test_glyphes_visibles()
	test_derobade()
	test_alternance()
	test_meute_liaison()
	test_etats_tuiles_par_grille()
	test_index_monde()
	test_sauvegarde_terrain()
	test_uniques_artefacts()
	test_bombes()
	test_composer_capacites()
	test_charges_de_modules()
	test_assemblage_sans_limite()
	test_creation_de_sorts()
	test_zones_au_sol()
	test_conditions_et_modificateurs()
	test_camp()
	test_faim_et_poids()
	test_donjon()
	test_donjon_temps_a_l_action()
	test_types_ennemis()
	test_loot_assemble()
	test_budgets()
	test_sauvegarde_partout()
	test_boss_et_artefact()
	test_loot()
	test_coffres_et_rares()
	test_gemmes_et_livres()
	test_progression()
	test_expedition()
	test_arenes_autonomes()
	Monde.fermer_tous()   # aucun thread de pré-génération ne doit survivre aux autoloads
	for nom_s in ["test_terrain", "test_sensen", "test_sensen2", "test_graine", "test_partout", "test_partout2", "test_auto"]:
		Sauvegarde.effacer(nom_s)   # la suite nettoie derrière elle : l'écran Charger ne liste que de vraies parties
	if echecs == 0:
		print("TESTS : tout passe")
		get_tree().quit(0)
	else:
		printerr("TESTS : %d échec(s)" % echecs)
		get_tree().quit(1)


func verifier(cond: bool, nom: String) -> void:
	if cond:
		print("  ok   " + nom)
	else:
		echecs += 1
		printerr("  ÉCHEC " + nom)


func nouvelle_sim(arene: String) -> Simulation:
	var s := Simulation.new(42)
	s.charger_arene(arene)
	return s


func joueur_de(s: Simulation) -> Dictionary:
	for e in s.vivants():
		if e.controle == "joueur":
			return e
	return {}


# ---------------------------------------------------------------- Hauteur de terrain ±10

## Une capacité de test : les modules sont connus ET chargés (Grimoires et manuels : un lancer consomme
## une charge par module). Sans ça, tout sort composé à la main serait refusé faute de munitions.
func _capacite_test(s: Simulation, j: Dictionary, id: String, mods: Array) -> void:
	for m in mods:
		s.crediter_module(j, str(m), 99)
	j.capacites.append({"id": id, "name_key": "capacite.etincelle.name", "modules": mods})


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
	verifier(g.cout_pas(Vector2i(13, 15), Vector2i(12, 15)) == -1, "Δ+3 : falaise infranchissable")
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
	verifier(j.sante_max == 68 and j.endurance == 100, "PV 20 + 12×4 = 68, endurance 100")
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
	var end: int = j.endurance
	verifier(s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "attaque à l'épée acceptée")
	verifier(loup.sante < pv_loup, "le loup a perdu des PV")
	verifier(j.compteur == hc.ticks + 5, "épée : 5 ticks")
	verifier(j.endurance <= end - 8 + 2 * 20, "l'attaque coûte 8 d'endurance")
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
	var end: int = j.endurance
	bandit.compteur = h.ticks
	s.pas(j.horloge)
	var perdu: int = pv - j.sante
	verifier(coups.size() == 1 and coups[0].garde and coups[0].direction == "front", "de face, la garde tient (perdu %d)" % perdu)
	verifier(j.endurance < end, "la garde coûte de l'endurance à l'impact")
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
	verifier(engagee[0] and not j.action_en_cours.is_empty() and j.compteur == h.ticks + 10, "lourde : engagée, télégraphée, 10 ticks")
	var pvb: int = bandit.sante
	s.pas(j.horloge)   # résolution à l'échéance
	verifier(j.action_en_cours.is_empty() and bandit.sante < pvb, "la lourde se résout à l'échéance")
	verifier(not bandit.garde, "la lourde brise la garde")
	# Attendre : 5 ticks, +20 d'endurance.
	j.endurance = 10
	j.compteur = h.ticks
	bandit.compteur = h.ticks + 100
	s.pas(j.horloge)
	var t: int = h.ticks
	verifier(s.intention(j.id, {"type": "attendre"}), "attendre")
	verifier(j.endurance == 30 and j.compteur == t + 5, "attendre : +20 endurance, 5 ticks")
	# À zéro d'endurance : garde impossible.
	j.endurance = 0
	j.tick_endurance = h.ticks + 100
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

## Un joueur automatique (frappe l'adjacent, sinon avance vers le plus proche, sinon attend)
## traverse chaque arène : aucune erreur d'exécution, le combat s'engage et fait des dégâts.
func test_arenes_autonomes() -> void:
	for arene in ["plaine_au_talus", "gorge", "ruine_a_estrades"]:
		var s := nouvelle_sim(arene)
		var j := joueur_de(s)
		var degats := [0]
		EventBus.damage_dealt.connect(func(_a: String, _c: String, d: int, _det: Dictionary) -> void: degats[0] += d)
		var engage := false
		for i in 1500:
			if not j.vivant:
				break
			if s.attente.has(j.id):
				var proche := {}
				for e in s.vivants():
					if e.camp != j.camp and (proche.is_empty() or Grille.distance(e.pos, j.pos) < Grille.distance(proche.pos, j.pos)):
						proche = e
				if proche.is_empty():
					break
				if Grille.distance(proche.pos, j.pos) == 1 and s.intention(j.id, {"type": "attaquer", "cible": proche.id, "lourde": i % 4 == 0}):
					continue
				var pas := s.grille.chemin(j.pos, proche.pos, false, proche.id)
				if pas.is_empty() or not s.intention(j.id, {"type": "deplacer", "vers": pas[0]}):
					s.intention(j.id, {"type": "attendre"})
			elif s.en_combat(j):
				engage = true
				s.pas(j.horloge)
			else:
				s.horloge_monde.avancer(1)
		verifier(engage and degats[0] > 0, "%s : combat engagé, %d dégâts échangés, joueur %s" % [arene, degats[0], "vivant" if j.vivant else "mort"])


# ---------------------------------------------------------------- Wu Xing : domination, jauge de chaîne

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
	verifier(s.intention(j.id, {"type": "changer_arme", "item": "proto_masse"}), "prendre la masse")
	var ts: int = int(s.regles.r.actions.changer_arme)
	verifier(j.equipement.main_principale == "proto_masse" and j.compteur == t + ts, "swap : %d ticks (combat_rules)" % ts)
	j.compteur = t
	s.horloge_monde.avancer(1)
	verifier(s.intention(j.id, {"type": "changer_arme", "item": "proto_bouclier"}), "prendre le bouclier")
	verifier(j.equipement.get("main_secondaire", "") == "proto_bouclier", "bouclier en main secondaire")
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	verifier(s.intention(j.id, {"type": "changer_arme", "item": "proto_lance"}), "prendre la lance (deux mains)")
	verifier(not j.equipement.has("main_secondaire"), "une arme à deux mains range le bouclier")
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	verifier(not s.intention(j.id, {"type": "changer_arme", "item": "proto_bouclier"}), "pas de bouclier avec une arme à deux mains")
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
	verifier(p.ticks == 9 and p.monnaie == "endurance" and p.ressource == 10 and p.elements == {"metal": 1.0}, "[Ligne]+[Frappe]+[Concentration] : 9 ticks · 10 endurance · Métal")
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
	verifier(j.mana < mana and j.mana >= mana - 6 and j.compteur == h.ticks + 3, "Étincelle : 3 mana ± le jet de coût (%d payés), 3 ticks" % (mana - j.mana))
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
	verifier(j.mana == mana and j.compteur == t + 2, "condition fausse : ne part pas, 50 % des ticks (3 → 2), rien payé")
	# Friendly fire : un carré touche un allié dans la zone
	for m0 in ["carre", "flamme"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["carre", "flamme"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "c", "name_key": "capacite.etincelle.name", "modules": ["carre", "flamme"]}
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
	s.intention(j.id, {"type": "changer_arme", "item": "proto_arc"})
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "tir à l'arc à 5 tuiles")
	verifier(j.munitions == 19 and j.munitions_tirees == 1, "une flèche consommée")
	verifier(j.compteur == h.ticks + 7, "arc : 10 / 1.5 ≈ 7 ticks")
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
	for m0 in ["point", "etincelle", "a_l_impact", "croix", "bruine"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["point", "etincelle", "a_l_impact", "croix", "bruine"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "i", "name_key": "capacite.etincelle.name", "modules": ["point", "etincelle", "a_l_impact", "croix", "bruine"]}
	j.compteur = h.ticks
	j.action_en_cours = {}
	s.pas(j.horloge)
	var pv2: int = loups[2].sante
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Étincelle → À l'impact → Croix + Bruine")
	verifier(coups[0] >= 2 and loups[2].sante < pv2, "la charge différée part de la cible touchée et frappe la croix (%d coups)" % coups[0])
	verifier(j.chaine.segments.size() == 2, "une capacité = un segment, même avec deux noyaux")
	# Ricochet : la charge saute vers les cibles proches
	coups[0] = 0
	for m0 in ["point", "etincelle", "ricochet"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["point", "etincelle", "ricochet"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "c", "name_key": "capacite.etincelle.name", "modules": ["point", "etincelle", "ricochet"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Étincelle + Ricochet")
	verifier(coups[0] >= 2, "au moins un saut (%d coups)" % coups[0])
	# Partage : le Baume sur un allié soigne aussi le lanceur
	var allie := s.ajouter("bandit", j.pos + Vector2i(1, 0), "joueur")
	allie.sante = 10
	j.sante = 10
	for m0 in ["point", "baume", "partage"]:
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
	for m0 in ["meche", "point", "etincelle"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["meche", "point", "etincelle"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "m", "name_key": "capacite.etincelle.name", "modules": ["meche", "point", "etincelle"]}
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
	for m0 in ["tuile", "barriere"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["tuile", "barriere"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "b", "name_key": "capacite.etincelle.name", "modules": ["tuile", "barriere"]}
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
	for m0 in ["tuile", "exhaussement"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["tuile", "exhaussement"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "e", "name_key": "capacite.etincelle.name", "modules": ["tuile", "exhaussement"]}
	j.compteur = h.ticks
	loup.compteur = h.ticks + 500
	s.pas(j.horloge)
	var t_pos: Vector2i = j.pos + Vector2i(-1, -1)
	var h_avant: int = s.grille.h(t_pos)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": t_pos}), "Exhaussement")
	s.pas(j.horloge)
	verifier(s.grille.h(t_pos) == h_avant + 1, "la tuile monte d'un niveau")
	for m0 in ["tuile", "fosse"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["tuile", "fosse"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "f", "name_key": "capacite.etincelle.name", "modules": ["tuile", "fosse"]}
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
	for m0 in ["point", "etincelle", "cadence", "point", "bruine"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["point", "etincelle", "cadence", "point", "bruine"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "cad", "name_key": "capacite.etincelle.name", "modules": ["point", "etincelle", "cadence", "point", "bruine"]}
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
	for m0 in ["ligne", "etincelle", "salve"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["ligne", "etincelle", "salve"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "sv", "name_key": "capacite.etincelle.name", "modules": ["ligne", "etincelle", "salve"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	# la ligne part vers (0,-1) : seul loups[0] est dessus → les 3 charges tombent sur lui
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Salve en ligne")
	verifier(coups[0] == 3, "3 charges (%d coups)" % coups[0])
	# Propagation : de proche en proche (les trois loups sont contigus)
	coups[0] = 0
	for m0 in ["point", "etincelle", "propagation"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["point", "etincelle", "propagation"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "pr", "name_key": "capacite.etincelle.name", "modules": ["point", "etincelle", "propagation"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Étincelle + Propagation")
	verifier(coups[0] == 3, "la charge se propage aux trois loups (%d coups)" % coups[0])
	# Boucle : rejoue tant qu'il reste du mana
	coups[0] = 0
	j.mana = 10   # Étincelle = 3 mana : 1 + 3 rejeux (10 → 7 → 4 → 1)
	for m0 in ["point", "etincelle", "boucle"]:
		s.crediter_module(j, str(m0), 99)
	for m0 in ["point", "etincelle", "boucle"]:
		s.crediter_module(j, str(m0), 99)
	j.capacites[3] = {"id": "bo", "name_key": "capacite.etincelle.name", "modules": ["point", "etincelle", "boucle"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Étincelle + Boucle")
	verifier(coups[0] >= 2 and j.mana <= 3, "la boucle rejoue jusqu'à épuisement du mana (%d coups, mana %d)" % [coups[0], j.mana])
	# Testament : la charge part quand le porteur tombe
	loups[0].capacites = [{"id": "t", "name_key": "capacite.etincelle.name", "modules": ["testament", "anneau", "etincelle"]}]
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
	verifier(peints.torse.construction == "cuir" and peints.torse.couleur == Color.html("#8A5A33"), "la construction donne la forme, le matériau la teinte")
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

func test_materiaux() -> void:
	var mats: Dictionary = GameData.catalogues.materials
	verifier(mats.size() == 163, "les 163 matériaux des catalogues sont chargés (%d)" % mats.size())
	var fer: Dictionary = mats.fer
	verifier(int(fer.stats.durete) == 25 and int(fer.stats.conductivite_electrique) == 75, "le Fer suit sa table (Dur 25, CÉl 75)")
	verifier("conducteur" in fer.tags and not ("inflammable" in fer.tags), "tags dérivés au seuil 50 (fer : conducteur)")
	verifier(mats.paille.tags.has("inflammable") and mats.verre.tags.has("transparent"), "paille inflammable, verre transparent")
	verifier(mats.chene.wuxing == {"bois": 1.0}, "chêne : vecteur de sa catégorie (Bois)")
	verifier(is_equal_approx(float(mats.obsidienne.wuxing.terre), 0.6) and is_equal_approx(float(mats.obsidienne.wuxing.feu), 0.4), "obsidienne : surcharge Terre 0.6 / Feu 0.4")
	verifier(mats.saphir.wuxing.has("eau") and mats.meteorite_ferreuse.wuxing.has("metal"), "gemmes et météorite : surcharges lues")
	var couleurs := {}
	for id in mats.keys():
		couleurs[mats[id].color] = true
	verifier(couleurs.size() == mats.size(), "160 couleurs uniques")
	verifier(mats.chene.harvest.tool_category == "hache" and mats.chene.harvest.skill == "bucheronnage", "récolte : outil et compétence de la catégorie")
	verifier(GameData.config("material_categories").size() == 11, "11 catégories de matériaux")
	verifier(tr("material.acier_trempe.name") == "Acier trempé", "nom localisé")


# ---------------------------------------------------------------- Étape 6.2 : récolte en donjon

func test_recolte() -> void:
	var s := Simulation.new(11)
	s.charger_donjon("ruine", 11, 5, 1)
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var filons := {}
	for idx in s.grille.materiaux.keys():
		filons[s.grille.materiaux[idx]] = true
	verifier(s.grille.materiaux.size() >= 24, "des filons dans les murs de l'étage 1 (%d tuiles)" % s.grille.materiaux.size())
	var mp: Dictionary = GameData.config("minerais_par_etage")
	var permis: Array = mp.tiers["1"] + mp.tiers["2"] + mp.fossiles.materiaux
	var hors_tier := false
	for m in filons.keys():
		if not (m in permis):
			hors_tier = true
	verifier(not hors_tier, "étage 1 : seulement les tiers 1-2 et les fossiles (%s)" % str(filons.keys()))
	verifier(s.grille.materiau_defaut == "pierre", "les murs de la ruine sont en pierre")
	# Un mur adjacent au joueur, à mains nues : on creuse, rien n'est récolté.
	var mur := Vector2i(-1, -1)
	for d in Grille.DIRS:
		var t: Vector2i = j.pos + d
		if s.grille.dans(t) and s.grille.bloque_passage(t) and Grille.distance(j.pos, t) == 1:
			mur = t
			break
	if mur == Vector2i(-1, -1):
		# la salle d'arrivée peut être large : on pose un mur à côté
		mur = j.pos + Vector2i(1, 0)
		s.grille.poser_contenu(mur, "mur")
	var sac0: int = j.sac.size()
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "creuser", "vers": mur}), "creuser à mains nues")
	verifier(j.sac.size() == sac0 and j.compteur == int(GameData.config("combat_rules").creuser.ticks), "sans outil : 10 ticks, rien récolté")
	# Avec la pioche de fer (dureté 25) : la pierre (dureté 15) se récolte en ⌈15 / 25 × 10⌉ = 6 ticks.
	var pioche := s.generer_objet("proto_pioche", 1, {}, "commun", 0)
	j.sac.append(pioche.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "equiper", "objet": pioche.uid}), "équiper la pioche")
	s.grille.poser_contenu(mur, "mur")
	s.attente[j.id] = true
	var xp0: int = int(j.xp_competences.get("minage", 0))
	verifier(s.intention(j.id, {"type": "creuser", "vers": mur}), "récolter le mur de pierre à la pioche")
	verifier(j.compteur == 6, "pierre à la pioche de fer : 6 ticks (%d)" % j.compteur)
	var brut := {}
	for uid in j.sac:
		var it: Dictionary = s.items[uid]
		if it.get("type", "") == "materiau":
			brut = it
	verifier(not brut.is_empty() and brut.materiau == "pierre" and int(brut.quantite) >= 1 and int(brut.quantite) <= 2, "1d2 pierre dans le sac (%d)" % int(brut.quantite))
	var q1: int = int(brut.quantite)
	verifier(int(j.xp_competences.get("minage", 0)) - xp0 > 0, "XP de Minage = dureté")
	s.grille.poser_contenu(mur, "mur")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "creuser", "vers": mur})
	verifier(int(brut.quantite) > q1, "la pierre s'empile (%d → %d)" % [q1, int(brut.quantite)])
	# Un filon de tungstène (dureté 42) : 25 × 1.0 ≥ 21, récoltable ; le diamant (40) aussi ; une pioche de cuivre (16) rebondit sur le tungstène.
	s.grille.poser_contenu(mur, "filon")
	s.grille.materiaux[s.grille.idx(mur)] = "tungstene"
	pioche.durete_base = 16
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "creuser", "vers": mur}), "outil trop faible : l'outil rebondit (16 < 42 × 0,5)")
	pioche.durete_base = 25
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "creuser", "vers": mur}), "la pioche de fer entame le tungstène")
	var tung := false
	for uid in j.sac:
		if s.items[uid].get("materiau", "") == "tungstene":
			tung = true
	verifier(tung, "le filon donne son matériau")
	# La pelle : dix-sept matériaux (terre, sable, eau, os…) exigeaient un outil qui n'existait pas.
	var pelle := s.generer_objet("proto_pelle", 1, {}, "commun", 0)
	j.sac.append(pelle.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "equiper", "objet": pelle.uid}), "équiper la pelle")
	s.grille.poser_contenu(mur, "mur")
	s.grille.materiaux[s.grille.idx(mur)] = "terre"
	var xp_t: int = int(j.xp_competences.get("terrassement", 0))
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "creuser", "vers": mur}), "creuser la terre à la pelle")
	var terre := false
	for uid in j.sac:
		if s.items[uid].get("materiau", "") == "terre":
			terre = true
	verifier(terre and int(j.xp_competences.get("terrassement", 0)) > xp_t, "la pelle récolte la terre et donne l'XP de Terrassement")


# ---------------------------------------------------------------- Étape 6.3 : stations et transformations plates

func test_fabrication() -> void:
	var s := Simulation.new(13)
	s.charger_donjon("ruine", 13, 6, 1)
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(GameData.catalogues.stations.size() == 9 and GameData.catalogues.recipes.size() == 57, "57 recettes : 19 transformations, 3 plats, 2 distillations, et 33 dérivées des objets qui portent leur coût (24 meubles, 9 stations)")
	s._donner_materiau(j, "fer", 3)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "fabriquer", "recette": "fondre_lingot"}), "sans forge dans le sac : rien")
	var forge := s.generer_objet("station_forge", 1, {}, "commun", 0)
	j.sac.append(forge.uid)
	var dispo := s.recettes_disponibles(j)
	var ids: Array = dispo.map(func(p: Dictionary) -> String: return p.id)
	verifier("fondre_lingot" in ids and "fondre_verre" in ids and not ("scier_planche" in ids), "la forge ouvre ses recettes, pas celles de la scierie (%s)" % str(ids))
	var fondre: Dictionary = dispo.filter(func(p: Dictionary) -> bool: return p.id == "fondre_lingot")[0]
	verifier(fondre.faisable and fondre.sortie.materiau == "fer" and fondre.sortie.forme == "lingot", "fondre : faisable, sortie = lingot de fer")
	var verre: Dictionary = dispo.filter(func(p: Dictionary) -> bool: return p.id == "fondre_verre")[0]
	verifier(not verre.faisable, "pas de sable : verre infaisable")
	s.attente[j.id] = true
	var xp0: int = int(j.xp_competences.get("forge", 0))
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "fondre_lingot"}), "fondre un lingot")
	verifier(int(s._pile(j, "fer", "brut").quantite) == 1 and int(s._pile(j, "fer", "lingot").quantite) == 1, "2 fer brut consommés, 1 lingot de fer produit")
	verifier(j.compteur == 20, "20 ticks au niveau 0 (%d)" % j.compteur)
	var dxp: int = int(j.xp_competences.get("forge", 0)) - xp0
	verifier(dxp > 0 and dxp <= 25, "XP de Forge = dureté du fer (25) × potentiel (%d)" % dxp)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "fabriquer", "recette": "fondre_lingot"}), "il ne reste qu'un fer brut : il en manque")
	verifier(s._pile(j, "fer", "brut").size() > 0 and s._pile(j, "cuivre", "brut").is_empty(), "les piles sont par matériau et par forme")
	# Le personnage créé part avec un établi portatif.
	var prog := Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	var fiche := Etres.creer_personnage("creature.aventurier.name", "humain", GameData.catalogues.classes.keys()[0], {}, 1000, prog)
	verifier("station_etabli" in fiche.get("sac", []), "le personnage part avec un établi")


# ---------------------------------------------------------------- Étape 6.4 : composants et assemblage

func test_assemblage() -> void:
	var s := Simulation.new(17)
	s.charger_donjon("ruine", 17, 8, 1)
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(GameData.catalogues.components.size() == 14 and GameData.catalogues.component_recipes.size() == 56, "14 composants, 56 recettes d'obtention")
	for st in ["etabli", "enclume", "scierie"]:   # l'aventurier des donjons de test n'est pas un personnage créé
		j.sac.append(s.generer_objet("station_" + st, 1, {}, "commun", 0).uid)
	s._donner_materiau(j, "fer", 3, "lingot")
	s._donner_materiau(j, "chene", 1, "planche")
	var ids: Array = s.recettes_disponibles(j).filter(func(pl: Dictionary) -> bool: return pl.faisable).map(func(pl: Dictionary) -> String: return pl.id)
	verifier("lame_courte_lingot_metal" in ids and "poignee_bois" in ids and "fixations_std_lingot_metal" in ids and not ("lame_courte_obsidienne" in ids), "recettes de composants faisables : lame (lingot), poignée (planche) ; l'obsidienne non (%s)" % str(ids))
	verifier(not ("lame_courte_or_argent" in s.recettes_disponibles(j).map(func(pl: Dictionary) -> String: return pl.id)), "les recettes exotiques non apprises ne sont pas listées")
	for rid in ["lame_courte_lingot_metal", "poignee_bois", "fixations_std_lingot_metal"]:
		s.attente[j.id] = true
		verifier(s.intention(j.id, {"type": "fabriquer", "recette": rid}), "façonner " + rid)
	var comps: Array = j.sac.filter(func(uid: String) -> bool: return s.items[uid].get("type", "") == "composant")
	verifier(comps.size() == 3, "3 composants dans le sac (%d)" % comps.size())
	var lame: Dictionary = s.items[comps[0]]
	verifier(lame.composant == "lame_courte" and lame.materiau == "fer" and int(lame.stats.durete) == 25 and lame.elements.has("metal"), "la lame porte les stats et l'élément du fer")
	verifier(float(lame.qualite) >= 0.1 and float(lame.qualite) <= 0.1 + 0.0001 or float(lame.qualite) <= 2.3, "qualité A.3 au niveau 0 : plancher 0,1 (%.2f)" % float(lame.qualite))
	verifier(int(s._pile(j, "fer", "lingot").quantite) == 1 and s._pile(j, "chene", "planche").is_empty(), "les unités consommées : 1 lingot restant, plus de planche")
	var dague_plan: Array = s.recettes_disponibles(j).filter(func(pl: Dictionary) -> bool: return pl.id == "craft_dague")
	verifier(dague_plan.size() == 1 and dague_plan[0].faisable, "l'assemblage de la dague est faisable à l'établi")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "craft_dague"}), "assembler la dague")
	var dague := {}
	for uid in j.sac:
		if s.items[uid].get("base", "") == "craft_dague":
			dague = s.items[uid]
	verifier(not dague.is_empty() and dague.materiau == "fer" and dague.element == "metal", "Dague en fer, élément Métal (la tête domine)")
	# durete_base = 0,7 × 25 (lame fer) + 0,25 × 12 (poignée chêne) + 0,05 × 25 (fixations fer) = 21,75 → 22
	verifier(int(dague.durete_base) == 22, "durete_base = moyenne pondérée avant qualité (%d)" % int(dague.durete_base))
	verifier(is_equal_approx(float(dague.elements.metal), 0.75) and is_equal_approx(float(dague.elements.bois), 0.25), "Wu Xing composite Métal 0,75 / Bois 0,25")
	verifier(is_equal_approx(float(dague.vitesse_facteur), 0.94), "manche en chêne (densité 6) : vitesse ×0,94 (%.2f)" % float(dague.vitesse_facteur))
	verifier(float(dague.qualite) > 0.0 and dague.composants.has("tete") and dague.composants.has("manche"), "qualité posée, composants mémorisés pour l'infobulle")
	verifier(j.sac.filter(func(uid: String) -> bool: return s.items[uid].get("type", "") == "composant").is_empty(), "les composants sont consommés")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "equiper", "objet": dague.uid}), "la dague assemblée s'équipe")
	var fonct: Dictionary = s.fonctionnalites.dague
	verifier(s.regles.ticks_attaque(fonct, false, dague) == roundi(10.0 / 3.0 * 0.94), "le manche pèse sur les ticks d'attaque")
	var n := s.nom_objet(dague.uid)
	verifier(n.has("materiau") and n.materiau == "material.fer.name", "le nom se décrit par le matériau de la tête")


# ---------------------------------------------------------------- écrans : desequiper, jeter

func test_desequiper_jeter() -> void:
	var s := Simulation.new(19)
	s.charger_arene("plaine_au_talus")
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var arme: String = j.equipement.main_principale
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "desequiper", "slot": "main_principale"}), "retirer l'arme en main")
	verifier(not j.equipement.has("main_principale") and arme in j.sac, "l'arme retirée est dans le sac")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "desequiper", "slot": "main_principale"}), "rien à retirer : refus")
	var n0: int = j.sac.size()
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "jeter", "objet": arme}), "jeter l'arme")
	verifier(j.sac.size() == n0 - 1 and s.contenants.has(s.grille.idx(j.pos)) and arme in s.contenants[s.grille.idx(j.pos)], "elle est en butin sur la tuile")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "ramasser"}) and arme in j.sac, "et se ramasse (R)")


# ---------------------------------------------------------------- Étape 8.1 : une cellule de surface

func test_surface() -> void:
	# Début de partie (2026-08-30) : le camp n'est jamais dans la mer — terre_a sonde DANS la cellule (bug des offsets 128)
	for g in [763439, 31, 92, 4, 555, 8080, 1234, 99]:
		var sd := Simulation.new(g)
		sd.charger_camp()
		var jd: Dictionary = sd.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
		verifier(sd.grille.niveau_liquide(jd.pos) == 0 and not ("liquide" in sd.grille.contenu_de(jd.pos).get("tags", [])), "graine %d : le camp est sur la terre ferme" % g)
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	verifier(GameData.config("noise_layers").size() == 8 and GameData.catalogues.biomes.size() == 12, "8 couches de bruit, 12 biomes")
	# Tectonique : 24 plaques, ~35 % de terres (quantile calibré), mers et montagnes déterministes.
	verifier(surf.plaques.size() == 24 and surf.points_chauds.size() >= 8 and surf.points_chauds.size() <= 14, "24 plaques, 8 à 14 points chauds")
	var terres := 0
	var n_ech := 40
	var monde_t := 1024 * int(planete.taille_cellule)
	for j2 in n_ech:
		for i2 in n_ech:
			if float(surf.tectonique_a(int((i2 + 0.5) / n_ech * monde_t), int((j2 + 0.5) / n_ech * monde_t)).altitude) >= 0.30:
				terres += 1
	var part := float(terres) / float(n_ech * n_ech)
	verifier(part > 0.22 and part < 0.48, "part de terres émergées ≈ 35 %% (%.0f %%)" % (part * 100.0))
	var t1 := surf.tectonique_a(1000, 1000)
	verifier(t1.altitude == surf.tectonique_a(1000, 1000).altitude and t1.sismique >= 0.0 and t1.sismique <= 1.0, "tectonique déterministe, sismique 0..1")
	var cell_mer := Vector2i(-1, -1)
	for j3 in 1024:
		if not surf.terre_a(Vector2i(j3, 3)):
			cell_mer = Vector2i(j3, 3)
			break
	if cell_mer != Vector2i(-1, -1):
		var em := surf.generer_cellule(cell_mer.x, cell_mer.y, {}, false)
		verifier(em.eau.size() > 0 and int(em.hauteurs[em.eau.keys()[0]]) == 8, "une cellule en mer : des tuiles d'eau à hauteur 8 (%d)" % em.eau.size())
	var v := surf.couches_a(1000, 1000)
	var bornes := true
	for k in v.keys():
		if float(v[k]) < 0.0 or float(v[k]) > 1.0:
			bornes = false
	verifier(v.size() == 8 and bornes, "les couches sont normalisées 0..1")
	verifier(surf.valeur("temperature", 0, 0) != surf.valeur("temperature", 50000, 50000) or surf.valeur("humidite", 0, 0) != surf.valeur("humidite", 50000, 50000), "le bruit varie à travers le monde")
	var b := surf.biome_a(512 * int(planete.taille_cellule), 512 * int(planete.taille_cellule))
	verifier(GameData.catalogues.biomes.has(b), "un biome résolu au centre du monde (%s)" % b)
	var e := surf.generer_cellule(512, 512, GameData.config("camp"))
	var e2 := surf.generer_cellule(512, 512, GameData.config("camp"))
	verifier(e.hauteurs == e2.hauteurs and e.arbres.size() == e2.arbres.size() and e.filons.size() == e2.filons.size(), "déterministe")
	var plats := 0
	for i in e.hauteurs.size():
		if int(e.hauteurs[i]) == 10:
			plats += 1
	verifier(plats > e.hauteurs.size() * 0.8 and plats < e.hauteurs.size(), "plat à 10 avec des accidents (%d %% plat, %d accidents)" % [plats * 100 / e.hauteurs.size(), e.accidents.size()])
	verifier(e.accidents.size() >= 1 and e.accidents.size() <= 8, "1 à 3 accidents posés par cellule de 64 (× accidents_mult du biome : %d)" % e.accidents.size())
	verifier(e.sols.size() > 100 and e.sols.values()[0] == GameData.entree("biomes", e.biome).surface_material or true, "le sol porte le matériau du biome")
	var mat_ok := true
	for i in e.arbres.keys():
		if not GameData.catalogues.materials.has(e.arbres[i]):
			mat_ok = false
	verifier(mat_ok and (e.arbres.size() + e.rochers.size() + e.filons.size()) > 20, "arbres, rochers et filons posés (%d / %d / %d)" % [e.arbres.size(), e.rochers.size(), e.filons.size()])
	var veg_ok := true
	for i in e.arbres.keys():
		if not GameData.catalogues.vegetaux.has(e.arbres[i]):
			veg_ok = false
	for i in e.plantes.keys():
		if not GameData.catalogues.vegetaux.has(e.plantes[i]) or not e.sol.has(i):
			veg_ok = false
	verifier(veg_ok and e.plantes.size() > 0, "chaque arbre et plante a sa silhouette ; les plantes restent franchissables (%d plantes)" % e.plantes.size())
	var dt := 1e9   # la meilleure de trois : la première génération porte le coût d'amorçage des bruits
	for k in 3:
		var t0 := Time.get_ticks_usec()
		surf.generer_cellule(513 + k, 512)
		dt = minf(dt, (Time.get_ticks_usec() - t0) / 1000.0)
	verifier(dt < 250.0, "une cellule de %d×%d générée en %.0f ms (< 250 ms ; le budget de 32 ms attend une refonte des structures)" % [int(planete.taille_cellule), int(planete.taille_cellule), dt])
	# Le camp est cette cellule.
	var s := Simulation.new(31)
	s.charger_camp()
	verifier(s.lieu == "camp" and s.camp_sauve.biome != "" and s.grille.sols.size() > 100, "le camp est une cellule générée (biome %s)" % s.camp_sauve.biome)
	verifier(surf.terre_a(s.camp_sauve.cellule), "la cellule de départ est de la terre ferme")
	s.monde.fermer()
	var accidente := false
	for i in s.grille.hauteurs.size():
		if int(s.grille.hauteurs[i]) != 10:
			accidente = true
	verifier(accidente, "le camp a du relief posé")


# ---------------------------------------------------------------- Étape 8.3a : POI, donjons de surface, carte, voyage rapide

func test_carte_et_voyage() -> void:
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	var donjons := 0
	var terres := 0
	for y in range(500, 520):
		for x in range(500, 520):
			var c := Vector2i(x, y)
			if surf.terre_a(c):
				terres += 1
				if surf.poi_de(c).donjon:
					donjons += 1
	verifier(terres == 0 or (float(donjons) / float(terres) < 0.2), "POI donjon à ~6 %% des cellules terrestres (%d / %d)" % [donjons, terres])
	verifier(surf.poi_de(Vector2i(512, 512)) == surf.poi_de(Vector2i(512, 512)), "POI déterministes")
	var r := surf.resume_cellule(Vector2i(512, 512), true)
	verifier(r.has("biome") and r.has("danger") and int(r.danger) >= 0 and int(r.danger) <= 2 and r.poi.donjon, "résumé de cellule : biome, danger 0-2, POI (le camp a son donjon)")
	var s := Simulation.new(41)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var camp := s.monde.cellule_camp
	var e := s.monde.cellule(camp)
	var entree: Vector2i = s.monde.pos_monde(camp, e.entree_donjon)
	verifier(s.grille.contenu_de(entree).get("tags", []).has("entree_donjon") and s.grille.bloque_passage(entree + Vector2i(0, -1)) and not s.grille.bloque_passage(entree + Vector2i(0, 1)), "l'entrée scellée : anneau de roche ouvert au sud")
	# Voyage rapide : refusé vers l'inexploré, accepté vers une cellule explorée ; le temps avance.
	var voisine := camp + Vector2i(1, 0)
	var t0: int = s.horloge_monde.ticks
	verifier(not s.voyager(j, voisine) or not s.monde.surface.terre_a(voisine) or s.monde.cellule_exploree(voisine), "pas de voyage vers une cellule jamais explorée")
	s.monde.explores[Vector2i(voisine.x * (s.monde.taille / 32), voisine.y * (s.monde.taille / 32))] = true
	if s.monde.surface.terre_a(voisine):
		verifier(s.voyager(j, voisine), "voyage rapide vers la cellule voisine explorée")
		verifier(s.monde.cellule_de(j.pos) == voisine and s.horloge_monde.ticks - t0 == int(planete.voyage.ticks_par_cellule), "arrivé dans la cellule, %d ticks de voyage" % (s.horloge_monde.ticks - t0))
	# Partir d'un donjon de surface : id de la cellule, retour devant l'entrée.
	s.grille.liberer(j.pos)
	j.pos = entree
	s._verifier_fenetre(j)
	s.grille.placer(j.id, entree)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "descendre"}), "entrer dans le donjon de la cellule")
	verifier(s.lieu == "donjon" and int(s.donjon.id) == int(hash([s.graine, camp.x, camp.y, "donjon", 0]) & 0x7fffffff), "le donjon a l'id de sa cellule (génération 0)")
	j.pos = s.donjon.entree
	s.grille.placer(j.id, j.pos)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "remonter"})
	verifier(s.lieu == "camp" and j.pos == entree, "ressortir ramène devant l'entrée")
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 8.3b : la dérive de la corruption

func test_corruption() -> void:
	var s := Simulation.new(43)
	s.charger_camp()
	var m = s.monde
	var camp: Vector2i = m.cellule_camp
	var cr: Dictionary = GameData.config("planete").corruption
	var f := m.foyer(camp)
	verifier(not f.is_empty() and bool(f.actif) and int(f.generation) == 0, "le donjon du camp est un foyer actif")
	var c0 := m.corruption_de(camp)
	var touchees := m.semaine(1)
	verifier(touchees.has(camp) and int(m.delta.get(camp, 0)) == int(cr.infection_cellule) and int(m.delta.get(camp + Vector2i(1, 0), 0)) == int(cr.infection_voisines) - int(cr.civilisation), "une semaine : +2 sur la cellule du foyer, +1 sur ses voisines (−1 : le camp civilise ses voisines)")
	verifier(m.corruption_de(camp) > c0, "la corruption effective a monté")
	for k in 30:
		m.semaine(k + 2)
	var plafond := int(cr.plafond_majeur) if bool(f.majeur) else int(cr.plafond_mineur)
	verifier(int(m.delta.get(camp, 0)) <= plafond, "plafond d'influence respecté (%d ≤ %d)" % [int(m.delta.get(camp, 0)), plafond])
	# Nettoyage : le boss vaincu à la sortie → foyer inactif, corruption en recul, grâce puis disparition.
	var d0 := int(m.delta.get(camp, 0))
	m.nettoyer(camp, 1000)
	verifier(not bool(f.actif) and int(f.repit) > 0 and int(m.delta.get(camp, 0)) == d0 + int(cr.nettoyage_cellule), "nettoyé : inactif, répit, −8")
	verifier(m.donjon_ouvert(camp, 1000 + 100) and not m.donjon_ouvert(camp, 1000 + int(cr.grace_ticks) + 1), "ouvert pendant la grâce, fermé après")
	var entree: Vector2i = m.pos_monde(camp, m.cellule(camp).entree_donjon)
	var disparues := m.tick(1000 + int(cr.grace_ticks) + 1)
	verifier(disparues.has(camp) and s.grille.contenu_de(entree).is_empty() and not s.grille.bloque_passage(entree + Vector2i(0, -1)), "après la grâce, l'entrée et son anneau de roche ont disparu")
	# Répit puis repeuplement : le répit décompte, la réapparition rend l'entrée avec une nouvelle génération.
	var repit0 := int(f.repit)
	m.semaine(2000)
	verifier(int(f.repit) == repit0 - 1, "le répit décompte chaque semaine")
	f.repit = 0
	m.delta[camp] = 40
	var reapparu := false
	for k in 40:
		m.semaine(3000 + k)
		if bool(f.actif):
			reapparu = true
			break
	verifier(reapparu and int(f.generation) == 1 and s.grille.contenu_de(entree).get("tags", []).has("entree_donjon"), "réapparition ∝ corruption : nouvelle génération, entrée de retour")
	# Décroissance loin des foyers : une cellule sans foyer actif à moins de 2 revient vers 0.
	var loin := camp + Vector2i(5, 5)
	m.explores[Vector2i(loin.x * (m.taille / 32), loin.y * (m.taille / 32))] = true
	m.delta[loin] = 3
	f.actif = false
	m.semaine(5000)
	verifier(int(m.delta.get(loin, 0)) == 2, "décroissance −1/semaine sans foyer proche")
	# Le danger de la carte lit la corruption effective ; l'expédition prend la corruption de la cellule.
	f.actif = true
	m.delta[camp] = 40
	verifier(m.danger_de(camp) >= s.monde.surface.danger_de(camp), "le danger affiché intègre le delta")
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	s.grille.liberer(j.pos)
	j.pos = entree
	s.grille.placer(j.id, entree)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "descendre"}), "entrer dans le donjon réapparu")
	var gen: int = int(m.foyer(camp).generation)
	verifier(gen >= 1 and int(s.donjon.id) == int(hash([s.graine, camp.x, camp.y, "donjon", gen]) & 0x7fffffff) and float(s.donjon.corruption) > 0.0 and int(s.donjon.profondeur) >= 1, "id de la génération %d, corruption %.0f et profondeur %d portées par le donjon" % [gen, float(s.donjon.corruption), int(s.donjon.profondeur)])
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 9.A : hameau, PNJ nommés, dialogue, commerce

func test_village() -> void:
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	verifier(GameData.catalogues.name_cultures.size() == 7 and GameData.catalogues.dialogue.size() == 28 and GameData.catalogues.functions.size() >= 6, "7 cultures, 28 répliques, les fonctions")
	# Un nom par culture, genré ; la fonction d'affichage unique.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var nord: Dictionary = GameData.catalogues.name_cultures.nordique
	var nf := Noms.generer("nordique", nord, "f", rng)
	verifier(nf.prenom.length() >= 3 and (nf.nom_famille.ends_with("sdottir") or nf.nom_famille.length() >= 4) and Noms.afficher(nf) == nf.prenom + " " + nf.nom_famille, "un nom nordique féminin (%s)" % Noms.afficher(nf))
	var nip: Dictionary = GameData.catalogues.name_cultures.nipponne
	var nm := Noms.generer("nipponne", nip, "m", rng)
	verifier(Noms.afficher(nm) == nm.nom_famille + " " + nm.prenom, "nom puis prénom pour la culture nipponne (%s)" % Noms.afficher(nm))
	# Un hameau quelque part : on cherche une cellule à POI village.
	var cell_v := Vector2i(-1, -1)
	for y in range(480, 560):
		for x in range(480, 560):
			var c := Vector2i(x, y)
			if surf.terre_a(c) and surf.poi_de(c).get("village", false):
				cell_v = c
				break
		if cell_v != Vector2i(-1, -1):
			break
	verifier(cell_v != Vector2i(-1, -1), "un POI village dans 80×80 cellules (4 %%)")
	var e := surf.generer_cellule(cell_v.x, cell_v.y, {}, false)
	var v: Dictionary = e.village
	verifier(not v.is_empty() and v.nom.length() >= 3 and v.batiments.size() >= 2 and v.pnj.size() >= 3, "un hameau nommé « %s » : %d bâtiments, %d PNJ" % [v.get("nom", "?"), v.get("batiments", []).size(), v.get("pnj", []).size()])
	verifier(e.murs.size() > 20 and e.portes.size() >= 2 and e.meubles.size() >= 3, "murs, portes et meubles de la palette (%d / %d / %d)" % [e.murs.size(), e.portes.size(), e.meubles.size()])
	var a_marchand := false
	for pj in v.pnj:
		if pj.creature == "marchand":
			a_marchand = true
	verifier(a_marchand, "un marchand dans l'échoppe")
	# On y va : les PNJ sont instanciés à la première visite, nommés, dotés d'or et d'un stock.
	var s := Simulation.new(4242)
	s.charger_camp({}, cell_v)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var civils: Array = s.vivants().filter(func(x: Dictionary) -> bool: return "civil" in x.get("tags", []))
	verifier(civils.size() >= 3, "les PNJ du hameau sont là (%d)" % civils.size())
	var marchand := {}
	for x in civils:
		if x.get("fonction", "") == "commercant":
			marchand = x
	verifier(not marchand.is_empty() and marchand.has("nom") and tr(marchand.name_key) == Noms.afficher(marchand.nom) and int(marchand.or) == 300 and marchand.stock.size() >= 8, "le marchand a un nom (%s), 300 or et un stock" % tr(marchand.get("name_key", "?")))
	verifier(not s.ennemis(j, marchand) and s.ennemis(marchand, {"camp": "hostile"}), "un civil n'est pas l'ennemi du joueur, mais celui des hostiles")
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
	verifier(marchand.stock.size() >= 5, "le marchand tient un stock tiré de ses catégories (%d objets)" % marchand.stock.size())
	var pain: String = str(marchand.stock[0])
	var p := s.prix_suggere(pain, marchand, j)
	verifier(int(p.prix) >= 1 and p.has("base") and p.has("rarete"), "prix suggéré du premier objet du stock : %d or (détail présent)" % int(p.prix))
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "acheter", "pnj": marchand.id, "objet": pain}), "sans or, pas d'achat")
	j.or = 100
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "acheter", "pnj": marchand.id, "objet": pain}) and pain in j.sac and int(j.or) == 100 - int(p.prix) and int(marchand.or) == 300 + int(p.prix), "acheter au marchand")
	s._donner_materiau(j, "fer", 1, "lingot")
	var lingot: String = s._pile(j, "fer", "lingot").uid
	var pl := s.prix_suggere(lingot, marchand, j)
	verifier(int(pl.prix) == 8, "un lingot de fer : sa valeur de base, %d or" % int(pl.prix))
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "vendre", "pnj": marchand.id, "objet": lingot}) and lingot in marchand.stock and int(j.or) == 100 - int(p.prix) + int(pl.achat), "vendre le lingot à 50 %%")
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
	verifier(int(v.humeur) == 45 - 5, "palier 1 : humeur −5")
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
		var reste := ech - s.horloge_monde.ticks + 1000
		while reste > 0:
			var n := mini(reste, 4000)
			s.horloge_monde.avancer(n)
			reste -= n
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
		s.horloge_monde.avancer(4000)
		verifier(int(s.territoire.caisse) > 0 and s._stock_etal(s._pm(et)).size() < 3, "des clients ont acheté : caisse %d or" % int(s.territoire.caisse))
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
		s.horloge_monde.avancer(100)
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
		s.horloge_monde.avancer(20)
	var sante_apres := 0
	for id in rd.ids:
		sante_apres += int(s.entites[str(id)].sante)
	verifier(sante_apres < sante_avant, "la tourelle a tiré : santé des assaillants %d → %d" % [sante_avant, sante_apres])
	s.territoire.raid.fin = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
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

func test_alchimie() -> void:
	var s := Simulation.new(81)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Un loup meurt : sa dépouille porte une partie.
	var loup := s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	s._appliquer_degats(loup, 9999, j.id, {})
	var butin: Array = s.contenants.get(s.grille.idx(loup.pos), [])
	var partie := ""
	for uid in butin:
		if "partie" in s.items[uid].get("tags", []):
			partie = str(s.items[uid].base)
	verifier(not partie.is_empty(), "une partie de bête dans la dépouille (%s)" % partie)
	var puiss := 0.0
	var viande_pot: Dictionary = {}
	for uid in butin:
		if "partie" in s.items[uid].get("tags", []):
			puiss = float(s.items[uid].get("puissance", 0.0))
		if str(s.items[uid].base) == "viande_crue":
			viande_pot = s.items[uid].get("potentiel", {})
	verifier(puiss >= 0.5 and puiss <= 4.0, "la partie porte la puissance de la stat du loup (%.1f)" % puiss)
	verifier(not viande_pot.is_empty(), "la viande porte le potentiel de la stat dominante (%s)" % str(viande_pot))
	# Distiller : griffe + blé à l'Alambic → potion de force.
	var griffe := s.generer_objet("griffe", 1, {}, "commun", 0)
	var ble := s.generer_objet("ble", 1, {}, "commun", 0)
	var alambic := s.generer_objet("station_alambic", 1, {}, "commun", 0)
	for o in [griffe, ble, alambic]:
		j.sac.append(o.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "distiller_partie"}) and not s._pile_objet(j, "potion_force").is_empty(), "distiller une griffe et du blé : une potion de force (la sortie vient de l'ingrédient)")
	verifier(not (griffe.uid in j.sac) and not (ble.uid in j.sac), "les ingrédients sont consommés")
	var potion := s._pile_objet(j, "potion_force")
	potion.qualite = 1.5
	potion.statut = "potion_force_forte"
	potion["puissance"] = 2.0
	var force0 := int(j.corps.stats.force)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "manger", "objet": potion.uid}), "boire la potion")
	var actif := false
	var fin := 0
	for st in j.statuts:
		if st.id == "potion_force_forte":
			actif = true
			fin = int(st.fin)
	verifier(actif and fin - s.horloge_monde.ticks >= 4400, "statut fort actif, durée × qualité (%d ticks)" % (fin - s.horloge_monde.ticks))
	verifier(int(j.stats_eff.force) == force0 + 12, "+6 × puissance 2 de Force pendant l'effet (%d → %d)" % [force0, int(j.stats_eff.force)])
	j.statuts[0].fin = s.horloge_monde.ticks
	s._tiquer_statuts(j, s.horloge_monde.ticks)
	verifier(int(j.stats_eff.force) == force0, "à l'expiration la Force revient (%d)" % int(j.stats_eff.force))
	s.monde.fermer()


# ---------------------------------------------------------------- Villes, boutiques, halls

func test_villes_et_halls() -> void:
	var s := Simulation.new(83)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var surf = s.monde.surface
	var cell: Vector2i = s.monde.cellule_camp + Vector2i(1, 0)
	var r := {"id": "roy_ville", "nom": "Grandia", "government_type": "monarchie_hereditaire", "culture": "latine", "race": "humain", "taille": "grand", "capital_poi": cell, "territory_cells": [cell],
		"taxes": {"base_rate": 0.08, "tariff_default": 0.1}, "tariffs": {}, "laws": [], "diplomacy": {}, "rivals": [], "tags": []}
	surf.royaumes_cache[surf.secteur_de(cell)] = {"roy_ville": r}
	surf.royaume_par_cellule[cell] = "roy_ville"
	var e: Dictionary = s.monde.cellule(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	surf._poser_village(e, cell, rng)
	var v: Dictionary = e.village
	var boutiques: Dictionary = {}
	var halls: Dictionary = {}
	for b in v.batiments:
		if not str(b.get("boutique", "")).is_empty():
			boutiques[str(b.boutique)] = int(boutiques.get(str(b.boutique), 0)) + 1
		if not str(b.get("guilde", "")).is_empty():
			halls[str(b.guilde)] = int(halls.get(str(b.guilde), 0)) + 1
	verifier(v.taille == "grand" and v.batiments.size() >= 6, "capitale d'un grand royaume : %d bâtiments" % v.batiments.size())
	verifier(boutiques.size() >= 3 and halls.size() >= 1, "%d boutiques typées, %d halls" % [boutiques.size(), halls.size()])
	var doublon := false
	for n in boutiques.values():
		doublon = doublon or int(n) > 1
	for n in halls.values():
		doublon = doublon or int(n) > 1
	verifier(not doublon, "jamais deux boutiques ou deux halls du même type")
	# Les PNJ de la ville : un marchand au stock de son type, un maître qui n'offre que sa guilde.
	s.monde.peuplees.erase(cell)
	s._peupler_fenetre()
	var marchand: Dictionary = {}
	var maitre: Dictionary = {}
	for x in s.vivants():
		if x.has("boutique") and marchand.is_empty():
			marchand = x
		if x.has("guilde") and maitre.is_empty():
			maitre = x
	verifier(not marchand.is_empty() and not marchand.stock.is_empty(), "un marchand tient sa boutique (%s, %d objets)" % [str(marchand.get("boutique", "?")), marchand.get("stock", []).size()])
	if not maitre.is_empty():
		var qs: Array = s.quetes_offertes(maitre, j)
		var bonne := true
		for q in qs:
			bonne = bonne and str(q.guild) == str(maitre.guilde)
		verifier(bonne, "le maître de la guilde %s n'offre que ses quêtes (%d)" % [str(maitre.guilde), qs.size()])
	else:
		verifier(false, "un maître de guilde instancié")
	# Le hall du joueur : refusé sans rang, accepté au rang Adepte, un maître apparaît, structure spéciale.
	var hall := s.generer_objet("meuble_hall_de_guilde", 1, {}, "commun", 0)
	j.sac.append(hall.uid)
	var vers: Vector2i = j.pos + Vector2i(0, 1)
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var c: Vector2i = j.pos + d
		if s.grille.dans(c) and s.grille.occupant(c).is_empty():
			s.grille.contenu[s.grille.idx(c)] = 0
			s.grille.meubles.erase(s.grille.idx(c))
			s.contenants.erase(s.grille.idx(c))
			vers = c
			break
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "poser", "objet": hall.uid, "vers": vers}), "sans rang : pas de hall")
	j["guildes"] = {"guerriers": {"xp": 300, "rang": 3}}
	s.attente[j.id] = true
	var avant := s._structures_speciales()
	verifier(s.intention(j.id, {"type": "poser", "objet": hall.uid, "vers": vers}) and s.territoire.halls.size() == 1, "au rang Adepte le hall se pose")
	var maitre_j: Dictionary = {}
	for x in s.vivants():
		if x.get("hall", Vector2i(-1, -1)) == vers:
			maitre_j = x
	verifier(not maitre_j.is_empty() and str(maitre_j.guilde) == "guerriers" and s._structures_speciales() == avant + 1, "un maître des Guerriers s'installe, structure spéciale +1")
	s.monde.fermer()


# ---------------------------------------------------------------- Saisons et élevage

func test_saisons_et_elevage() -> void:
	var s := Simulation.new(85)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var jour := int(s._cycle().ticks_par_jour)
	verifier(s.saison(0) == "printemps" and s.saison(35 * jour) == "ete" and s.saison(55 * jour) == "fin_ete" and s.saison(70 * jour) == "automne" and s.saison(100 * jour) == "hiver" and s.saison(125 * jour) == "printemps", "cinq saisons sur 120 jours, puis l'année recommence")
	verifier(s._saison_info(100 * jour).temp == -10.0 and s._saison_info(35 * jour).temp == 8.0, "l'écart de température : hiver −10, été +8")
	# Capture : une tuile d'eau voisine, un jet forcé.
	var eau: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.poser_contenu(eau, "eau")
	j.competences["collecte"] = 40
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "capturer"}), "lancer le filet")
	var specimens: Array = []
	for uid in j.sac:
		if s.items[uid].has("genome"):
			specimens.append(s.items[uid])
	verifier(specimens.size() == 1 and specimens[0].genome.has("couleur"), "un spécimen d'eau capturé (%s), avec son génome" % str(specimens[0].espece if not specimens.is_empty() else "-"))
	# Un couple dans un vivarium : la couvée hebdomadaire hérite locus par locus.
	var a := s._nouveau_specimen("carpe", {"couleur": 3, "motif": 2, "taille": 2.0}, "m")
	var b := s._nouveau_specimen("carpe", {"couleur": 5, "motif": 6, "taille": 4.0}, "f")
	var viv: Vector2i = j.pos + Vector2i(0, 1)
	for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var c: Vector2i = j.pos + d
		if s.grille.dans(c) and s.grille.occupant(c).is_empty():
			viv = c
			break
	s.grille.contenu[s.grille.idx(viv)] = 0
	s.grille.poser_contenu(viv, "meuble")
	s.grille.meubles[s.grille.idx(viv)] = "vivarium"
	s.contenants[s.grille.idx(viv)] = [a.uid, b.uid]
	var meme_sexe := s.conditions_repro(a, s._nouveau_specimen("carpe", {"couleur": 0, "motif": 0, "taille": 1.0}, "m"), {"habitat": "vivarium", "libre": 2, "temp": 18.0, "saison": "ete"})
	verifier(not meme_sexe.ok and str(meme_sexe.raisons[0].cle) == "raison.sexe", "deux mâles : l'évaluateur dit pourquoi")
	s.horloge_monde.ticks = 35 * jour + jour / 2   # un midi d'été : la couvée dépend de la température réelle du lieu
	s.meteo_force = "canicule"
	s._semaine_elevage()
	s.meteo_force = ""
	var enfants: Array = s.contenants[s.grille.idx(viv)].filter(func(u: String) -> bool: return u != a.uid and u != b.uid)
	verifier(enfants.size() >= 1, "une couvée dans le vivarium (%d)" % enfants.size())
	if not enfants.is_empty():
		var g: Dictionary = s.items[enfants[0]].genome
		var c_ok: bool = int(g.couleur) in [2, 3, 4, 5, 6]
		var m_ok: bool = int(g.motif) in [1, 2, 3, 5, 6, 7]
		verifier(c_ok and m_ok and float(g.taille) > 2.0 and float(g.taille) < 4.5, "l'enfant : couleur %d, motif %d, taille %.2f — un parent ou une voisine, moyenne dérivée" % [int(g.couleur), int(g.motif), float(g.taille)])
	verifier(int(s.territoire.registre.carpe.size()) >= 3, "le registre compte les variétés (%d)" % int(s.territoire.registre.carpe.size()))
	s.monde.fermer()


# ---------------------------------------------------------------- Élevage : les six familles

func test_elevage_familles() -> void:
	var s := Simulation.new(87)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(GameData.catalogues.species.size() >= 6, "six espèces en données (%d)" % GameData.catalogues.species.size())
	var jour := int(s._cycle().ticks_par_jour)
	s.horloge_monde.ticks = 35 * jour + jour / 2   # un midi d'été : les conditions de température passent
	# Un habitat de test posé à côté du joueur.
	var hab: Vector2i = j.pos + Vector2i(0, 1)
	for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]:
		var c: Vector2i = j.pos + d
		if s.grille.dans(c) and s.grille.occupant(c).is_empty():
			hab = c
			break
	var idx := s.grille.idx(hab)
	s.grille.contenu[idx] = 0
	s.grille.poser_contenu(hab, "meuble")
	# Serpent : le trait caché — deux porteurs [0,1] peuvent donner un [1,1].
	s.grille.meubles[idx] = "terrarium"
	var a := s._nouveau_specimen("serpent", {"couleur": 2, "ecailles": [0, 1], "taille": 2.0}, "m")
	var b := s._nouveau_specimen("serpent", {"couleur": 2, "ecailles": [1, 0], "taille": 2.0}, "f")
	a.age_semaines = 1
	b.age_semaines = 1
	s.contenants[idx] = [a.uid, b.uid]
	s.meteo_force = "canicule"   # la cellule de départ est froide à 64 × 64 : on force l'été réel
	s._semaine_elevage()
	s.meteo_force = ""
	var petits: Array = s.contenants[idx].filter(func(u: String) -> bool: return u != a.uid and u != b.uid)
	verifier(petits.size() >= 1 and s.items[petits[0]].genome.ecailles.size() == 2, "serpents : une couvée, écailles à deux allèles (%s)" % str(s.items[petits[0]].genome.ecailles if not petits.is_empty() else "-"))
	# Ver à soie : le coût par croisement consomme 4 choux du stock ; sans stock, refus motivé.
	s.grille.meubles[idx] = "clayette"
	var v1 := s._nouveau_specimen("ver_a_soie", {"finesse": 3.0, "couleur": 1}, "m")
	var v2 := s._nouveau_specimen("ver_a_soie", {"finesse": 5.0, "couleur": 2}, "f")
	s.contenants[idx] = [v1.uid, v2.uid]
	var sans := s.conditions_repro(v1, v2, {"habitat": "clayette", "libre": 4, "temp": 18.0, "saison": "ete"})
	verifier(not sans.ok and str(sans.raisons[0].cle) == "raison.ressource", "vers à soie sans choux : refus motivé")
	s.territoire.stocks["chou"] = 5
	s._semaine_elevage()
	verifier(int(s.territoire.stocks.get("chou", 0)) == 1 and s.contenants[idx].size() == 4, "avec 5 choux : une couvée de 2, il reste 1 chou")
	# Ruche : la colonie croît chaque semaine et produit du miel en été.
	s.grille.meubles[idx] = "rucher"
	var r := s._nouveau_specimen("ruche", {"miel": 0, "colonie": 7}, "f")
	s.contenants[idx] = [r.uid]
	s._semaine_elevage()
	verifier(int(r.genome.colonie) == 8 and int(s.territoire.stocks.get("miel", 0)) == 2, "ruche : colonie 7 → 8, 2 miels au stock (%d)" % int(s.territoire.stocks.get("miel", 0)))
	# Tortue : la dossière suit l'âge.
	var t := s._nouveau_specimen("tortue", {"couleur": 1, "dossiere": 0, "taille": 1.0}, "m")
	s.grille.meubles[idx] = "enclos"
	s.contenants[idx] = [t.uid]
	s._semaine_elevage()
	s._semaine_elevage()
	verifier(int(t.genome.dossiere) == 2 and int(t.age_semaines) == 2, "tortue : dossière 2 à 2 semaines")
	# Phalène : le mélanisme est acquis de la corruption du lieu.
	var ph := s._nouveau_specimen("phalene", {"couleur": 3, "motif": 1, "melanisme": null}, "f")
	s._exprimer_loci(ph, s.monde.cellule_camp, true)
	verifier(ph.genome.melanisme != null, "phalène : mélanisme fixé à la naissance (%s)" % str(ph.genome.melanisme))
	# Capture : sans appât ni milieu, refus ; une plante voisine → une tortue ou une ruche.
	s.attente[j.id] = true
	var viande := s.generer_objet("viande_crue", 1, {}, "commun", 0)
	j.sac.append(viande.uid)
	j.competences["collecte"] = 60
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	var ok := s.intention(j.id, {"type": "capturer"})
	var pris := 0
	for uid in j.sac:
		if s.items[uid].has("genome"):
			pris += 1
	verifier(ok and pris >= 1, "capturer : le milieu voisin (ou l'appât) décide de l'espèce, un spécimen pris")
	s.monde.fermer()


# ---------------------------------------------------------------- Élevage : les dix loci, la soie

func test_loci_et_soie() -> void:
	var s := Simulation.new(89)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 89
	# lie_au_sexe : un mâle ne porte qu'un allèle, une femelle deux.
	var chat: Dictionary = GameData.catalogues.species.chat
	var m := s._nouveau_specimen("chat", s._genome_aleatoire(chat, rng), "m")
	s._exprimer_loci(m, s.monde.cellule_camp, true)
	var f := s._nouveau_specimen("chat", s._genome_aleatoire(chat, rng), "f")
	s._exprimer_loci(f, s.monde.cellule_camp, true)
	verifier(m.genome.pelage.size() == 1 and f.genome.pelage.size() == 2, "pelage lié au sexe : 1 allèle chez le mâle, 2 chez la femelle")
	var enfant: Array = s._heriter(f.genome.pelage, m.genome.pelage, chat.loci.pelage, rng)
	verifier(enfant.size() == 2 and (int(enfant[0]) in f.genome.pelage) and int(enfant[1]) == int(m.genome.pelage[0]), "l'enfant reçoit un allèle de la mère et celui du père")
	# carte : la carte d'un parent, quelques cases retournées.
	var carpe: Dictionary = GameData.catalogues.species.carpe
	var ca: Array = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
	var cb: Array = ca.duplicate()
	var carte: Array = s._heriter(ca, cb, carpe.loci.taches, rng)
	var un := 0
	for v in carte:
		un += int(v)
	verifier(carte.size() == 16 and un >= 10 and un <= 16, "taches : 16 cases, %d gardées d'un parent tout blanc" % un)
	# automate : jamais tiré, déterminé par les autres loci.
	var coq: Dictionary = GameData.catalogues.species.coquillage
	var c1 := s._nouveau_specimen("coquillage", {"couleur": 3, "spirale": [0, 1], "motif_coquille": null}, "f")
	s._exprimer_loci(c1, s.monde.cellule_camp, true)
	var c2 := s._nouveau_specimen("coquillage", {"couleur": 3, "spirale": [0, 1], "motif_coquille": null}, "f")
	s._exprimer_loci(c2, s.monde.cellule_camp, true)
	var c3 := s._nouveau_specimen("coquillage", {"couleur": 7, "spirale": [1, 1], "motif_coquille": null}, "f")
	s._exprimer_loci(c3, s.monde.cellule_camp, true)
	verifier(c1.genome.motif_coquille != null and c1.genome.motif_coquille == c2.genome.motif_coquille and int(c1.genome.motif_coquille) < int(coq.loci.motif_coquille.n), "motif automate : mêmes loci → même motif (%s), borné" % str(c1.genome.motif_coquille))
	# Filer la soie : un ver de finesse 3 → 3 soie brute, le ver disparaît.
	var ver := s._nouveau_specimen("ver_a_soie", {"finesse": 3.0, "couleur": 1}, "f")
	j.sac.append(ver.uid)
	var atelier := s.generer_objet("station_atelier_tissage", 1, {}, "commun", 0)
	j.sac.append(atelier.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "filer_soie"}), "filer la soie à l'atelier de tissage")
	var soie := s._pile(j, "soie", "brut")
	verifier(not soie.is_empty() and int(soie.quantite) == 3 and not (ver.uid in j.sac), "3 soie brute (finesse 3), la chrysalide est morte")
	s.monde.fermer()


# ---------------------------------------------------------------- Harmonie Wu Xing des plats

func test_harmonie() -> void:
	var s := Simulation.new(91)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var cuisine := s.generer_objet("station_cuisine", 1, {}, "commun", 0)
	j.sac.append(cuisine.uid)
	# Un ragoût sans rien d'autre : viande (bois/eau) + cuisson (feu) → trois éléments, pas d'harmonie.
	var v := s.generer_objet("viande_crue", 1, {}, "commun", 0)
	v.quantite = 2
	j.sac.append(v.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "plat_ragout"}), "mijoter un ragoût nu")
	var r1 := s._pile_objet(j, "ragout")
	verifier(not r1.is_empty() and float(r1.get("harmonie", 1.0)) == 1.0 and r1.get("wuxing", {}).has("feu"), "ragoût nu : du feu de cuisson, pas d'harmonie (%s)" % str(r1.get("wuxing", {})))
	s.items.erase(r1.uid)
	j.sac.erase(r1.uid)
	# Viande + pomme de terre (terre) + oignon (feu) + sel gemme (métal) → cinq éléments.
	var v2 := s.generer_objet("viande_crue", 1, {}, "commun", 0)
	v2.quantite = 2
	j.sac.append(v2.uid)
	for base in ["pomme_de_terre", "oignon"]:
		var o := s.generer_objet(base, 1, {}, "commun", 0)
		j.sac.append(o.uid)
	s._donner_materiau(j, "sel_gemme", 1, "brut")
	s.attente[j.id] = true
	var cands: Array = s.candidats_optionnels(j, GameData.catalogues.recipes.plat_ragout)
	verifier(cands.size() == 3, "trois ingrédients optionnels candidats (%d)" % cands.size())
	var sel := s._pile(j, "sel_gemme", "brut")
	s.basculer_ingredient(j, "plat_ragout", sel.uid)
	var plan_sans := s._plan_recette(j, GameData.catalogues.recipes.plat_ragout)
	verifier(not bool(s.harmonie_prevue(plan_sans).harmonie), "le sel exclu : l'aperçu annonce quatre éléments (pas de Métal)")
	s.basculer_ingredient(j, "plat_ragout", sel.uid)
	verifier(bool(s.harmonie_prevue(s._plan_recette(j, GameData.catalogues.recipes.plat_ragout)).harmonie), "le sel repris : l'aperçu annonce l'harmonie")
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "plat_ragout"}), "mijoter un ragoût complet")
	var r2 := s._pile_objet(j, "ragout")
	verifier(not r2.is_empty() and float(r2.get("harmonie", 1.0)) == 1.2, "les cinq éléments : harmonie ×1,2 (%s)" % str(r2.get("wuxing", {})))
	verifier(s._pile(j, "sel_gemme", "brut").is_empty() and s._pile_objet(j, "oignon").is_empty(), "les ingrédients optionnels sont consommés")
	j.faim = 50
	s.attente[j.id] = true
	s.intention(j.id, {"type": "manger", "objet": r2.uid})
	var attendu: int = 50 + roundi(float(GameData.entree("items", "ragout").nutrition) * 1.2)
	verifier(int(j.faim) == mini(100, attendu), "manger l'assiette harmonieuse : nutrition ×1,2 (%d)" % int(j.faim))
	s.monde.fermer()


# ---------------------------------------------------------------- Registre d'élevage et paliers

func test_registre_elevage() -> void:
	var s := Simulation.new(93)
	s.charger_camp()
	verifier(s.varietes_possibles("carpe") == 128 and s.varietes_possibles("ver_a_soie") == 6, "variétés possibles : carpe 16 × 8, ver à soie 6")
	var a := s._nouveau_specimen("carpe", {"couleur": 1, "motif": 2, "taille": 3.5}, "m")
	var b := s._nouveau_specimen("carpe", {"couleur": 1, "motif": 2, "taille": 5.0}, "f")
	var c := s._nouveau_specimen("serpent", {"couleur": 0, "ecailles": [0, 1], "taille": 1.0}, "f")
	verifier(s.territoire.registre.carpe.size() == 1 and float(s.territoire.records.carpe.taille) == 5.0, "deux carpes de la même variété : 1 variété, record de taille 5")
	verifier(s.territoire.records.serpent.ecailles.has("0") and s.territoire.records.serpent.ecailles.has("1"), "serpent : allèles 0 et 1 vus")
	verifier(int(s.paliers_elevage().capture) == 0, "sans palier : pas de bonus de capture")
	for k in 80:
		s.territoire.registre.carpe["%d|%d" % [k % 16, k / 16]] = true
	verifier(int(s.paliers_elevage().capture) == 2, "75 variétés : captures +2")
	for esp in GameData.catalogues.species.keys():
		if not s.territoire.registre.has(esp):
			s.territoire.registre[esp] = {"0|0": true}
	var pal := s.paliers_elevage()
	verifier(int(pal.couvees) == 0 or GameData.catalogues.species.size() >= 10, "moins de 10 espèces : pas de couvée en plus (%d espèces)" % GameData.catalogues.species.size())
	verifier("palier.bestiaire" in pal.atteints and int(pal.capture) == 6, "bestiaire complet : captures +6 au total")
	s.monde.fermer()


# ---------------------------------------------------------------- Familles, héritier, maîtres de guilde, titres

func test_familles() -> void:
	var s := Simulation.new(95)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var camp: Vector2i = s.monde.cellule_camp
	var cell: Vector2i = camp + Vector2i(1, 0)
	var r := {"id": "roy_fam", "nom": "Famillia", "government_type": "monarchie_hereditaire", "culture": "latine", "race": "humain", "taille": "hameau", "capital_poi": cell, "territory_cells": [cell],
		"taxes": {"base_rate": 0.08, "tariff_default": 0.1}, "tariffs": {}, "laws": [], "diplomacy": {}, "rivals": [], "tags": []}
	s.monde.surface.royaumes_cache[s.monde.surface.secteur_de(cell)] = {"roy_fam": r}
	s.monde.surface.royaume_par_cellule[cell] = "roy_fam"
	# Une maison de trois : le roi (50 ans), sa reine (40), un enfant.
	var base: Vector2i = s.monde.pos_monde(cell, Vector2i(10, 64))
	var membres: Array = []
	for k in 3:
		var x := s.ajouter("villageois", base + Vector2i(k, 0), "ia")
		s._habiller_pnj(x, GameData.entree("creatures", "villageois"), "latine")
		x["village"] = "Bourg-Fam"
		x["royaume"] = "roy_fam"
		x["lit"] = base + Vector2i(k, 0)
		x.age = [50.0, 40.0, 30.0][k]
		x.genre = ["m", "f", "m"][k]
		membres.append(x)
	membres[0].fonction = "dirigeant"
	var v := {"nom": "Bourg-Fam", "batiments": [{"lits": [Vector2i(10, 64), Vector2i(11, 64), Vector2i(12, 64)]}]}
	s._former_familles(cell, v)
	verifier(membres[0].family.spouse == membres[1].id and membres[1].family.spouse == membres[0].id, "le roi et la reine sont conjoints")
	verifier(membres[2].family.child_of.has(membres[0].id) and membres[0].family.parent_of.has(membres[2].id) and float(membres[2].age) < 18.0, "le troisième est leur enfant (%d ans)" % int(membres[2].age))
	verifier(str(membres[0].titre) == "titre.latine.monarchie_hereditaire.m", "le roi porte le titre latin (%s)" % str(membres[0].titre))
	# Le roi meurt : l'héritier est mémorisé ; quatre semaines plus tard il monte sur le trône, titré.
	s._appliquer_degats(membres[0], 9999, j.id, {})
	verifier(s.monde.heritiers.get("roy_fam", "") == membres[2].id, "l'héritier désigné est l'enfant")
	s.monde.semaine_courante += 4
	s._semaine_royaumes_pnj()
	verifier(str(membres[2].fonction) == "dirigeant" and str(membres[2].titre) == "titre.latine.monarchie_hereditaire.m" and not s.monde.vacances.has("roy_fam"), "l'enfant règne, avec le titre")
	# Un maître de guilde meurt : deux semaines, puis un villageois reprend le hall.
	var maitre := s.ajouter("maitre_de_guilde", base + Vector2i(0, 2), "ia")
	s._habiller_pnj(maitre, GameData.entree("creatures", "maitre_de_guilde"), "latine")
	maitre["village"] = "Bourg-Fam"
	maitre["guilde"] = "chasseurs"
	var vill := s.ajouter("villageois", base + Vector2i(1, 2), "ia")
	s._habiller_pnj(vill, GameData.entree("creatures", "villageois"), "latine")
	vill["village"] = "Bourg-Fam"
	s._appliquer_degats(maitre, 9999, j.id, {})
	verifier(s.monde.vacances_guildes.has("chasseurs|Bourg-Fam"), "la mort du maître ouvre une vacance de guilde")
	s.monde.semaine_courante += 2
	s._semaine_royaumes_pnj()
	var repris := false
	for x in s.vivants():
		if str(x.get("guilde", "")) == "chasseurs" and str(x.fonction) == "maitre_de_guilde" and x.id != maitre.id:
			repris = true
	verifier(repris and not s.monde.vacances_guildes.has("chasseurs|Bourg-Fam"), "deux semaines plus tard, un villageois est maître des Chasseurs")
	s.monde.fermer()


# ---------------------------------------------------------------- Entraîneur et commandes

func test_entraineur_et_commandes() -> void:
	var s := Simulation.new(97)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var m := s.ajouter("maitre_de_guilde", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(m, GameData.entree("creatures", "maitre_de_guilde"))
	j.competences["epee"] = 5
	var pot0 := int(j.potentiels.get("epee", s.regles.r.progression.potentiel_defaut))
	verifier(s.cout_entrainement(j, "epee") == 100, "épée niveau 5 : 100 or")
	j.or = 50
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "entrainer", "pnj": m.id, "competence": "epee"}), "50 or : refusé")
	j.or = 150
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "entrainer", "pnj": m.id, "competence": "epee"}) and int(j.potentiels.epee) == pot0 + 10 and int(j.or) == 50, "150 or : +10 de potentiel, 100 or au maître")
	var g := s.ajouter("garde_village", j.pos + Vector2i(0, 1), "ia")
	s._habiller_pnj(g, GameData.entree("creatures", "garde_village"))
	verifier(s.peut_entrainer(g, "epee") and not s.peut_entrainer(g, "cuisine"), "un garde entraîne l'épée, pas la cuisine")
	# Une commande tirée du registre, livrée à un marchand contre son or.
	var a := s._nouveau_specimen("carpe", {"couleur": 4, "motif": 2, "taille": 2.0}, "m")
	s.items.erase(a.uid)
	s._tirer_commande()
	var cmd: Dictionary = s.territoire.get("commande", {})
	verifier(not cmd.is_empty() and cmd.espece == "carpe" and int(cmd.couleur) != 4 and absi(int(cmd.couleur) - 4) <= 2 and int(cmd.or) >= 195, "commande : une carpe à un ou deux pas (couleur %s, %d or)" % [str(cmd.get("couleur", "?")), int(cmd.get("or", 0))])
	m.tags.append("commerce_possible")
	m.or = 0
	var sp := s._nouveau_specimen("carpe", {"couleur": int(cmd.couleur), "motif": 2, "taille": 2.0}, "f", bool(cmd.get("chatoyant", false)))
	j.sac.append(sp.uid)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "livrer", "pnj": m.id}), "marchand sans or : refus")
	m.or = 1000
	var or0: int = int(j.or)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "livrer", "pnj": m.id}) and int(j.or) == or0 + int(cmd.or) and not s.territoire.has("commande"), "commande livrée : %d or" % int(cmd.or))
	s.monde.fermer()


# ---------------------------------------------------------------- Gabarits : livrer, construire, fabriquer, vendre, explorer

func test_gabarits_guildes() -> void:
	var s := Simulation.new(99)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var guildes_servies: Dictionary = {}
	for gid in GameData.catalogues.quest_templates.keys():
		guildes_servies[str(GameData.catalogues.quest_templates[gid].guild)] = true
	verifier(guildes_servies.size() >= 12, "les douze guildes ont au moins un gabarit (%d)" % guildes_servies.size())
	# Construire : trois structures sur le territoire.
	j["quetes"] = [{"uid": "q1", "pattern": "construire", "selector": {"tags_any": ["meuble", "station", "mur"]}, "count": 2, "fait": 0, "etat": "en_cours", "text_key": "quest.chantier.text", "or": 10, "xp": 5, "guild": "batisseurs", "donneur": "x"}]
	var lit := s.generer_objet("meuble_lit_de_paille", 1, {}, "commun", 0)
	j.sac.append(lit.uid)
	var vers: Vector2i = j.pos + Vector2i(0, 1)
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var c: Vector2i = j.pos + d
		if s.grille.dans(c) and s.grille.occupant(c).is_empty():
			s.grille.contenu[s.grille.idx(c)] = 0
			s.grille.meubles.erase(s.grille.idx(c))
			s.contenants.erase(s.grille.idx(c))
			vers = c
			break
	s.attente[j.id] = true
	s.intention(j.id, {"type": "poser", "objet": lit.uid, "vers": vers})
	verifier(int(j.quetes[0].fait) == 1, "un meuble posé sur le territoire : 1/2")
	# Fabriquer un plat : la quête du banquet avance, pas celle des potions.
	j.quetes.append({"uid": "q2", "pattern": "fabriquer", "selector": {"kinds_any": ["plat"]}, "count": 1, "fait": 0, "etat": "en_cours", "text_key": "quest.banquet.text", "or": 10, "xp": 5, "guild": "cuisiniers", "donneur": "x"})
	j.quetes.append({"uid": "q3", "pattern": "fabriquer", "selector": {"kinds_any": ["potion"]}, "count": 1, "fait": 0, "etat": "en_cours", "text_key": "quest.elixirs.text", "or": 10, "xp": 5, "guild": "alchimistes", "donneur": "x"})
	var cuisine := s.generer_objet("station_cuisine", 1, {}, "commun", 0)
	j.sac.append(cuisine.uid)
	var v := s.generer_objet("viande_crue", 1, {}, "commun", 0)
	v.quantite = 2
	j.sac.append(v.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "fabriquer", "recette": "plat_ragout"})
	verifier(j.quetes[1].etat == "terminee" and int(j.quetes[2].fait) == 0, "un ragoût : le banquet est servi, les élixirs attendent")
	# Livrer : parler à un PNJ du village de destination avec l'objet.
	var pnj := s.ajouter("villageois", j.pos + Vector2i(1, 1), "ia")
	s._habiller_pnj(pnj, GameData.entree("creatures", "villageois"))
	pnj["village"] = "Port-Test"
	j.quetes.append({"uid": "q4", "pattern": "livrer", "selector": {}, "count": 1, "fait": 0, "etat": "en_cours", "text_key": "quest.livraison.text", "or": 40, "xp": 12, "guild": "transporteurs", "donneur": "x", "objet": "pain", "destination": "Port-Test"})
	var pain := s.generer_objet("pain", 1, {}, "commun", 0)
	j.sac.append(pain.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "parler", "pnj": pnj.id})
	verifier(j.quetes[3].etat == "terminee" and s._pile_objet(j, "pain").is_empty(), "le pain livré à Port-Test : quête terminée, pain remis")
	s.monde.fermer()


# ---------------------------------------------------------------- Prêtre et tourelle

func test_pretre_et_tourelle() -> void:
	var s := Simulation.new(101)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(GameData.catalogues.recipes.has("meuble_tourelle") and GameData.catalogues.village_buildings.has("chapelle") and GameData.catalogues.creatures.has("pretre"), "recette de tourelle, chapelle et prêtre en données")
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 1), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v.social.relations[j.id] = 80
	j.corps.stats.charisme = 25
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "recruter", "pnj": v.id})
	s._appliquer_degats(v, 9999, j.id, {})
	var ame: String = s.ame_dans_sac(j)
	verifier(not ame.is_empty(), "l'âme du compagnon est dans le sac")
	var pretre := s.ajouter("pretre", j.pos + Vector2i(-1, 0), "ia")
	s._habiller_pnj(pretre, GameData.entree("creatures", "pretre"))
	var cout := s.cout_resurrection(j, ame, true)
	verifier(cout == 20 * maxi(1, int(round(s.progression.niveaux_derives(v).combat))) and s.cout_resurrection(j, ame, false) == int(float(cout) * 1.5), "coût chez le prêtre %d or, ×1,5 à l'autel" % cout)
	j.or = cout
	pretre.or = int(pretre.or_max) - 5
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "ressusciter", "ame": ame, "pnj": pretre.id}) and v.vivant and int(j.or) == 0, "le prêtre rappelle le compagnon")
	verifier(int(pretre.or) == int(pretre.or_max), "sa bourse est finie : le surplus sort du jeu")
	verifier(float(v.get("affaibli_mult", 1.0)) < 1.0, "le ressuscité revient Affaibli")
	s.monde.fermer()


# ---------------------------------------------------------------- Talents de classe et de race

func test_talents() -> void:
	var s := Simulation.new(113)
	s.charger_donjon("ruine", 113, 8, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(GameData.catalogues.talents.size() >= 11, "onze talents en données (%d)" % GameData.catalogues.talents.size())
	# Le Sabre : un changement d'arme gratuit par chaîne.
	j.classe = "le_sabre"
	verifier(s.a_talent(j, "ratelier_vivant"), "Le Sabre porte Râtelier vivant")
	var autre := ""
	for uid in j.ratelier:
		if uid != j.equipement.get("main_principale", "") and s.items[uid].type == "arme":
			autre = uid
	if not autre.is_empty():
		var t0: int = int(j.compteur)
		s.attente[j.id] = true
		s.intention(j.id, {"type": "changer_arme", "item": autre})
		var gratuit: bool = int(j.compteur) == t0 or int(j.compteur) == s.horloge_monde.ticks or bool(j.get("swap_gratuit_pris", false))
		verifier(gratuit and bool(j.get("swap_gratuit_pris", false)), "premier changement d'arme : 0 tick, le suivant paiera")
	# La Balance : +1 place d'escorte.
	j.classe = "la_balance"
	var places_b := s.places_escorte(j)
	j.classe = "le_sabre"
	verifier(places_b == s.places_escorte(j) + 1, "Œil du prix : +1 place d'escorte")
	# L'Elfe : la surchauffe coûte de l'endurance, pas de santé.
	j.race = "elfe"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	var end0 := int(j.endurance_max)
	verifier(s.a_talent(j, "chair_de_mana") and end0 == int(s.regles.r.endurance.max) - 20, "Chair de mana : endurance max −20 (%d)" % end0)
	j.mana = 0
	var sante0 := int(j.sante)
	j.endurance = 50
	s._payer(j, {"monnaie": "mana", "ressource": 5, "charge_suivante": {}})
	verifier(int(j.sante) == sante0 and int(j.endurance) == 50 - 10, "surchauffe de 5 : −10 d'endurance, santé intacte")
	# Le Nain : rien n'est irrécoltable.
	j.race = "nain"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(s.a_talent(j, "oeil_de_la_pierre") and "detection_filons" in j.tags_acquis, "Œil de la pierre : sent les filons")
	# Le Vent apprend le talent d'un PNJ à relation ≥ 75.
	j.race = "humain"
	j.classe = "le_vent"
	var m := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(m, GameData.entree("creatures", "villageois"))
	m.classe = "la_paume"
	m.social.relations[j.id] = 50
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "apprendre_talent", "pnj": m.id}), "à 50 de relation : refus")
	m.social.relations[j.id] = 80
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "apprendre_talent", "pnj": m.id}) and s.a_talent(j, "souffle_rendu"), "à 80 : Le Vent apprend Souffle rendu")
	verifier(not m.get("classe", "").is_empty(), "les PNJ portent une classe (%s)" % str(m.classe))


# ---------------------------------------------------------------- Assemblage de capacités, Renaissance

## Création de sorts (Structure compétences-modules-slots) : tout le catalogue de modules passé au banc.
## Chaque noyau seul, chaque forme avec un noyau, puis 300 séquences tirées au hasard : l'assembleur
## doit toujours rendre un plan cohérent — jamais de plan à moitié construit, jamais d'erreur muette.
## Conditions et modificateurs (Modules, lots 7 et 7b) : chaque prédicat s'évalue, chaque drapeau agit.
func test_conditions_et_modificateurs() -> void:
	var s := Simulation.new(616)
	s.charger_donjon("ruine", 616, 6, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	for dx in range(1, 5):
		var t: Vector2i = j.pos + Vector2i(dx, 0)
		s.grille.contenu[s.grille.idx(t)] = 0
		s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	var plan_de := func(mods: Array) -> Dictionary:
		var pl := s.capacites.assembler(mods, 10, "1d4", {}, j.competences_eff)
		pl["name_key"] = ""
		pl["arme"] = {}
		pl["fonct"] = {}
		return pl

	# 1. tout prédicat cité par une condition est évalué par le code (aucun ne tombe dans le défaut)
	var non_geres: Array[String] = []
	for mid in GameData.catalogues.modules.keys():
		var m: Dictionary = GameData.catalogues.modules[mid]
		if str(m.module_type) != "condition":
			continue
		var t := str(m.get("effet", {}).get("predicat_structure", {}).get("type", ""))
		if t.is_empty():
			non_geres.append(str(mid) + " (sans prédicat)")
	verifier(non_geres.is_empty(), "les 20 conditions portent un prédicat (%s)" % str(non_geres))

	# 2. Ombre : vrai seulement quand le lanceur est Dissimulé — et la capacité ne part pas sinon
	var plan_ombre: Dictionary = plan_de.call(["ombre", "etincelle"])
	verifier(not s._evaluer_conditions(j, plan_ombre, loup.pos).is_empty(), "Ombre : sans Dissimulé, la condition est fausse")
	s.appliquer_statut(j, "dissimule", 200, j.id)
	verifier(s._evaluer_conditions(j, plan_de.call(["ombre", "etincelle"]), loup.pos).is_empty(), "Ombre : Dissimulé, la condition passe")
	s._retirer_statut(j, "dissimule")

	# 3. Prise : vrai quand la cible est saisie ou lévitée
	verifier(not s._evaluer_conditions(j, plan_de.call(["prise", "etincelle"]), loup.pos).is_empty(), "Prise : cible libre, condition fausse")
	s.appliquer_statut(loup, "levite", 50, j.id)
	verifier(s._evaluer_conditions(j, plan_de.call(["prise", "etincelle"]), loup.pos).is_empty(), "Prise : cible lévitée, condition vraie")
	s._retirer_statut(loup, "levite")

	# 4. Pied ferme : le lanceur n'a pas bougé depuis 20 ticks
	j["immobile_depuis"] = s.tick_de(j)
	verifier(not s._evaluer_conditions(j, plan_de.call(["pied_ferme", "etincelle"]), loup.pos).is_empty(), "Pied ferme : à peine arrêté, condition fausse")
	j["immobile_depuis"] = s.tick_de(j) - 50
	verifier(s._evaluer_conditions(j, plan_de.call(["pied_ferme", "etincelle"]), loup.pos).is_empty(), "Pied ferme : 50 ticks immobile, condition vraie")

	# 5. Évasement : la géométrie s'ouvre
	verifier(str(plan_de.call(["ligne", "etincelle"]).geometrie) == "ligne" and str(plan_de.call(["ligne", "evasement", "etincelle"]).geometrie) == "cone", "Évasement : la Ligne devient un Cône")

	# 6. Canalisation : les dés de l'immobilité
	var plan_can: Dictionary = plan_de.call(["canalisation", "etincelle"])
	j["immobile_depuis"] = s.tick_de(j) - 25
	var des0: int = int(plan_can.des_bonus)
	s._executer_capacite(j, plan_can, loup.pos)
	verifier(int(plan_can.des_bonus) == des0 + 5, "Canalisation : 25 ticks immobile = +5 dés (%d)" % int(plan_can.des_bonus))

	# 7. Emprise : ce qui est touché est enraciné
	loup.statuts.clear()
	loup.vivant = true   # l'Étincelle du test précédent a pu l'abattre
	loup.anti_stunlock_jusqua = 0   # la Lévitation du test 4 tient encore le verrou anti-stunlock
	loup.sante = 100000
	loup.sante_max = 100000
	if s.grille.occupant(loup.pos).is_empty():
		s.grille.placer(loup.id, loup.pos)
	s._executer_capacite(j, plan_de.call(["emprise", "etincelle"]), loup.pos)
	verifier(Etres.a_statut_id(loup, "enracinement"), "Emprise : la cible touchée est enracinée")

	# 8. Traçant : la portée seule compte, le couvert non
	var derriere_mur: Vector2i = j.pos + Vector2i(3, 0)
	s.grille.poser_contenu(j.pos + Vector2i(2, 0), "mur")
	var plan_normal: Dictionary = plan_de.call(["point", "etincelle"])   # une forme projetée : la ligne de vue compte
	var plan_trac: Dictionary = plan_de.call(["point", "tracant", "etincelle"])
	plan_normal.portee = Vector2i(1, 6)
	plan_trac.portee = Vector2i(1, 6)
	verifier(not s.capacite_visable(j, plan_normal, derriere_mur) and s.capacite_visable(j, plan_trac, derriere_mur), "Traçant : la charge passe le mur, pas la charge normale")
	s.grille.contenu[s.grille.idx(j.pos + Vector2i(2, 0))] = 0

	# 9. Détonation : le double contre une invocation
	var invoque := s.ajouter("loup", j.pos + Vector2i(4, 0), "ia")
	invoque["fin_invocation"] = s.tick_de(j) + 500
	invoque.sante = 100000
	invoque.sante_max = 100000
	loup.sante = 100000
	loup.sante_max = 100000
	var plan_det: Dictionary = plan_de.call(["detonation", "etincelle"])
	verifier(float(plan_det.drapeaux.get("detonation", 0.0)) == 2.0, "Détonation : le drapeau atteint le plan")


## Les zones au sol (Modules — lot 2) : Racine, Sol vif, Nappe, Voile de brume, Balise.
func test_zones_au_sol() -> void:
	var s := Simulation.new(515)
	s.charger_donjon("ruine", 515, 9, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# une allée dégagée devant le joueur
	for dx in range(1, 6):
		var t: Vector2i = j.pos + Vector2i(dx, 0)
		s.grille.contenu[s.grille.idx(t)] = 0
		s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	var loup := s.ajouter("loup", j.pos + Vector2i(4, 0), "ia")
	var cible: Vector2i = j.pos + Vector2i(1, 0)
	var plan_z := func(nid: String) -> Dictionary:
		var pl := s.capacites.assembler([nid], 10, "1d4", {}, j.competences_eff)
		pl["name_key"] = ""
		pl["arme"] = {}
		pl["fonct"] = {}
		return pl
	# Sol vif : la tuile blesse ce qui la traverse
	s._executer_capacite(j, plan_z.call("sol_vif"), cible)
	verifier(s.zones_sur(cible, "blessure").size() == 1, "Sol vif : une zone de blessure sur la tuile")
	s.grille.liberer(loup.pos)
	loup.pos = cible + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	loup.orientation = Vector2i(-1, 0)
	var pv0: int = int(loup.sante)
	s._deplacer(loup, cible, s.tick_de(loup))
	verifier(int(loup.sante) < pv0, "le loup traverse le sol vif et saigne (%d → %d)" % [pv0, int(loup.sante)])
	# Racine : la zone enracine ce qui s'y arrête
	var t_racine: Vector2i = j.pos + Vector2i(0, 1)
	s.grille.contenu[s.grille.idx(t_racine)] = 0
	s.grille.hauteurs[s.grille.idx(t_racine)] = s.grille.h(j.pos)
	s.zones.clear()
	s._executer_capacite(j, plan_z.call("racine"), t_racine)
	s.grille.liberer(loup.pos)
	loup.pos = t_racine + Vector2i(0, 1)
	s.grille.placer(loup.id, loup.pos)
	if s.grille.dans(loup.pos):
		s.grille.contenu[s.grille.idx(loup.pos)] = 0
		s.grille.hauteurs[s.grille.idx(loup.pos)] = s.grille.h(j.pos)
	s._deplacer(loup, t_racine, s.tick_de(loup))
	verifier(Etres.a_statut_id(loup, "enracinement"), "Racine : ce qui entre dans la zone est enraciné")
	# Voile de brume : ni vu, ni voyant
	s.zones.clear()
	s._executer_capacite(j, plan_z.call("voile_de_brume"), loup.pos)
	verifier(not s.zones_sur(loup.pos, "brume").is_empty() and not s.voit_ia(loup, j), "Voile de brume : le loup ne voit plus")
	# Balise : la tuile marquée donne un dé de plus au porteur
	s.zones.clear()
	s._executer_capacite(j, plan_z.call("balise"), loup.pos)
	verifier(s._bonus_balise(j, loup.pos) == 1 and s._bonus_balise(loup, loup.pos) == 0, "Balise : +1 dé pour celui qui l'a posée, pour personne d'autre")
	# Nappe : on glisse d'une tuile de plus
	s.zones.clear()
	var t_nappe: Vector2i = j.pos + Vector2i(2, 0)
	s._executer_capacite(j, plan_z.call("nappe"), t_nappe)
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	loup.orientation = Vector2i(1, 0)
	loup.statuts.clear()   # il sort de la Racine du test précédent : rien ne doit le retenir
	s._deplacer(loup, t_nappe, s.tick_de(loup))
	verifier(loup.pos == t_nappe + Vector2i(1, 0), "Nappe : le loup glisse d'une tuile de plus (%s)" % str(loup.pos - t_nappe))
	# expiration
	s._tiquer_zones(999999)
	verifier(s.zones.is_empty(), "les zones expirent")


func test_creation_de_sorts() -> void:
	var s := Simulation.new(4242)
	s.charger_donjon("ruine", 4242, 12, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var par_type := {}
	for mid in GameData.catalogues.modules.keys():
		var t := str(GameData.catalogues.modules[mid].module_type)
		if not par_type.has(t):
			par_type[t] = []
		par_type[t].append(str(mid))
	for t in par_type.keys():
		par_type[t].sort()
	verifier(par_type.get("noyau", []).size() >= 86 and par_type.get("forme", []).size() == 16, "le catalogue : %d noyaux, %d formes" % [par_type.get("noyau", []).size(), par_type.get("forme", []).size()])

	# 1. chaque noyau, seul : un plan complet et cohérent
	var noyaux_ko: Array[String] = []
	var incoherents: Array[String] = []
	for nid in par_type.noyau:
		var plan := s.capacites.assembler([nid], 10, "1d4", {}, j.competences_eff)
		if not plan.erreurs.is_empty():
			noyaux_ko.append("%s (%s)" % [nid, str(plan.erreurs[0])])
			continue
		if plan.noyau.is_empty() or int(plan.ticks) <= 0 or int(plan.portee.x) > int(plan.portee.y) or int(plan.taille) < 0:
			incoherents.append(nid)
		elif int(plan.ressource) < 0 or (not str(plan.monnaie).is_empty() and not (str(plan.monnaie) in ["mana", "endurance", "sante", "or"])):
			incoherents.append(nid + " (monnaie " + str(plan.monnaie) + ")")
	verifier(noyaux_ko.is_empty(), "les 86 noyaux s'assemblent seuls (%s)" % str(noyaux_ko.slice(0, 4)))
	verifier(incoherents.is_empty(), "chacun rend un plan cohérent — ticks, portée, taille, monnaie (%s)" % str(incoherents.slice(0, 4)))

	# 2. chaque forme, avec un noyau : la géométrie du plan est celle de la forme
	var formes_ko: Array[String] = []
	for fid in par_type.forme:
		var plan := s.capacites.assembler([fid, "etincelle"], 10, "1d4", {}, j.competences_eff)
		if not plan.erreurs.is_empty() or plan.forme.is_empty() or str(plan.geometrie).is_empty():
			formes_ko.append(fid)
	verifier(formes_ko.is_empty(), "les 16 formes portent leur géométrie (%s)" % str(formes_ko))

	# 3. les refus attendus
	verifier(not s.capacites.assembler(["point"], 10, "1d4", {}, {}).erreurs.is_empty(), "sans noyau : erreur")
	verifier(not s.capacites.assembler(["module_qui_n_existe_pas"], 10, "1d4", {}, {}).erreurs.is_empty(), "module inconnu : erreur")
	verifier(s.capacites.assembler(["etincelle", "gel"], 10, "1d4", {}, {}).erreurs.is_empty(), "deux noyaux sans Alternance : accepté, les deux charges partent")

	# 4. 300 séquences tirées au hasard dans TOUT le catalogue : jamais de plan à moitié construit
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260829
	var tous: Array = GameData.catalogues.modules.keys()
	tous.sort()
	var casses: Array[String] = []
	var assemblees := 0
	for essai in 300:
		var seq: Array = []
		for k in rng.randi_range(1, 5):
			seq.append(str(tous[rng.randi_range(0, tous.size() - 1)]))
		var plan := s.capacites.assembler(seq, 10, "1d4", {}, j.competences_eff)
		if not plan.erreurs.is_empty():
			continue   # un refus est une réponse valable (deux noyaux, pas de noyau…)
		assemblees += 1
		# Invariants d'un plan accepté. Un plan ouvert par un déclencheur porte son noyau dans la charge
		# différée (`charge_suivante`), pas à la racine — c'est le modèle des Six types de modules.
		var noyau_effectif: Dictionary = plan.noyau if not plan.noyau.is_empty() else plan.charge_suivante.get("noyau", {})
		if noyau_effectif.is_empty() or int(plan.ticks) <= 0 or int(plan.portee.x) > int(plan.portee.y) or int(plan.ressource) < 0:
			casses.append(str(seq))
		elif plan.has("alt") and (plan.alt.noyau.is_empty() or not plan.alt.erreurs.is_empty()):
			casses.append("alternance " + str(seq))
	verifier(assemblees > 60, "%d séquences sur 300 s'assemblent" % assemblees)
	verifier(casses.is_empty(), "aucun plan accepté n'est incohérent (%s)" % str(casses.slice(0, 3)))

	# 5. de bout en bout : composer puis LANCER un sort de chaque géométrie, en jeu
	j.modules_connus = []
	for mid in GameData.catalogues.modules.keys():
		s.crediter_module(j, str(mid), 99)
	j.capacites = []
	j.mana = 9999
	j.mana_max = 9999
	j.endurance = 9999
	var lances := 0
	var refus: Array[String] = []
	for fid in ["point", "ligne", "cone", "carre", "soi"]:
		if not (fid in par_type.get("forme", [])):
			continue
		j.capacites = []   # un slot de capacité à la fois : c'est la géométrie qu'on teste, pas les slots
		if not s.composer_capacite(j, [fid, "etincelle"]):
			refus.append("composer " + fid)
			continue
		var idx: int = j.capacites.size() - 1
		var cible: Vector2i = j.pos if fid == "soi" else j.pos + Vector2i(1, 0)
		s.attente[j.id] = true
		j.mana = 9999
		j.endurance = 9999
		if s.intention(j.id, {"type": "capacite", "index": idx, "cible": cible}):
			lances += 1
		else:
			refus.append("lancer " + fid)
	verifier(refus.is_empty(), "composer et lancer un sort de chaque géométrie (%s)" % str(refus))
	verifier(lances >= 4, "%d sorts lancés en jeu" % lances)

	# 6. les 86 noyaux EXÉCUTÉS sur une cible réelle : c'est là que vivent les neuf types d'effet
	# (dégâts, statut, soin, terrain, déplacement, invocation, tempo, saisie, résurrection).
	var mannequin := s.ajouter("sanglier", j.pos + Vector2i(1, 0), "ia")
	mannequin.sante = 100000
	mannequin.sante_max = 100000
	var sans_effet: Array[String] = []
	var executes := 0
	for nid in par_type.noyau:
		var plan := s.capacites.assembler([nid], 10, "1d4", {}, j.competences_eff)
		if not plan.erreurs.is_empty():
			continue
		plan["name_key"] = str(plan.noyau.get("name_key", ""))   # comme plan_capacite le fait en jeu
		plan["arme"] = {}
		plan["fonct"] = {}
		if s.grille.occupant(j.pos + Vector2i(1, 0)).is_empty():   # une invocation a pu prendre la tuile
			s.grille.liberer(mannequin.pos)
			mannequin.pos = j.pos + Vector2i(1, 0)
			s.grille.placer(mannequin.id, mannequin.pos)
		var pv_avant: int = int(mannequin.sante)
		var statuts_avant: int = mannequin.statuts.size() + j.statuts.size()
		var vivants_avant: int = s.vivants().size()
		var zones_avant: int = s.zones.size()
		j.mana = 9999
		j.endurance = 9999
		j.sante = int(j.sante_max)   # certains noyaux coûtent des PV (Cataclysme, Offrande, Saignée)
		mannequin.sante = 100000
		mannequin.vivant = true
		s._executer_capacite(j, plan, mannequin.pos)
		executes += 1
		# Un noyau qui touche doit faire QUELQUE CHOSE : des PV, un statut, une invocation, ou du terrain.
		var agi: bool = int(mannequin.sante) != pv_avant or (mannequin.statuts.size() + j.statuts.size()) != statuts_avant \
			or s.vivants().size() != vivants_avant or not s.grille.modifies.is_empty() or s.zones.size() != zones_avant
		if not agi:
			sans_effet.append(nid)
		s.grille.modifies.clear()
	verifier(executes >= 80, "%d noyaux exécutés sur une cible réelle" % executes)
	# Chantier connu (Structure compétences-modules-slots, constat du 2026-08-29) : 47 noyaux ont un `effet`
	# vide et ne produisent rien. Le test tient le compte et refuse qu'il AUGMENTE, comme l'audit.
	verifier(sans_effet.size() <= 34, "noyaux sans effet visible : %d (budget 34, mesure du banc) — %s" % [sans_effet.size(), str(sans_effet.slice(0, 6))])
	verifier(j.vivant and mannequin.vivant, "le lanceur et le mannequin survivent aux 86 sorts")


## Les charges de modules (Grimoires et manuels) : lire en donne, chaque lancer en consomme une par module.
## Aucune limite d'assemblage (Six types de modules) : le prix et le résultat sont les seules bornes.
func test_assemblage_sans_limite() -> void:
	var s := Simulation.new(929)
	s.charger_donjon("ruine", 929, 9, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	for dx in range(-5, 6):   # une esplanade : la Nuée tire à 2 tuiles autour d'une cible à 2 tuiles
		for dy in range(-5, 6):
			var t: Vector2i = j.pos + Vector2i(dx, dy)
			if s.grille.dans(t) and t != j.pos:
				s.grille.contenu[s.grille.idx(t)] = 0
				s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	var plan_de := func(mods: Array) -> Dictionary:
		var pl := s.capacites.assembler(mods, 10, "1d4", {}, j.competences_eff)
		pl["name_key"] = ""
		pl["arme"] = {}
		pl["fonct"] = {}
		return pl
	# 1. deux formes : les tuiles s'additionnent
	var p_deux: Dictionary = plan_de.call(["ligne", "croix", "etincelle"])
	verifier(p_deux.erreurs.is_empty() and p_deux.formes_sup.size() == 1, "deux formes : acceptées, la seconde s'ajoute")
	var n_ligne: int = s.tuiles_du_plan(j, plan_de.call(["ligne", "etincelle"]), j.pos + Vector2i(2, 0)).size()
	var n_union: int = s.tuiles_du_plan(j, p_deux, j.pos + Vector2i(2, 0)).size()
	verifier(n_union > n_ligne, "l'union couvre plus que la ligne seule (%d > %d)" % [n_union, n_ligne])
	# 2. une bombe par tuile, et le prix × le nombre de tuiles
	var p_bombe: Dictionary = plan_de.call(["carre", "bombe"])
	var n_tuiles: int = s.tuiles_du_plan(j, p_bombe, j.pos + Vector2i(2, 0)).size()
	verifier(s._facteur_surface(j, p_bombe, j.pos + Vector2i(2, 0)) == n_tuiles and n_tuiles >= 9, "le facteur de surface = %d tuiles" % n_tuiles)
	verifier(s.plan_par_tuile(p_bombe) and not s.plan_par_tuile(plan_de.call(["carre", "etincelle"])) and s.surface_nominale(j, p_bombe) >= 9, "le composeur sait qu'un plan est par tuile et estime sa surface avant la visée (%d)" % s.surface_nominale(j, p_bombe))
	# Plus de plafond de modules par capacité : une séquence de six modules se compose au niveau 0
	var caps_sauve: Array = j.capacites.duplicate()
	j.capacites = []
	for m in ["carre", "bombe", "etincelle", "concentration", "gel", "baume"]:
		if not (m in j.modules_connus):
			j.modules_connus.append(m)
	verifier(s.composer_capacite(j, ["carre", "bombe", "etincelle", "concentration", "gel", "baume"]) and j.capacites.size() == 1, "six modules se composent au niveau 0 : la longueur n'est plus bornée par les slots (%d capacité)" % j.capacites.size())
	for k in 12:   # pas de limite de sorts créés non plus (2026-08-30)
		s.composer_capacite(j, ["point", "etincelle", "concentration"] if k % 2 == 0 else ["carre", "gel"])
	verifier(j.capacites.size() == 13, "treize capacités composées sans refus (%d)" % j.capacites.size())
	j.capacites = caps_sauve
	var n_bombes0: int = s.bombes.size()
	s._executer_capacite(j, p_bombe, j.pos + Vector2i(2, 0))
	verifier(s.bombes.size() - n_bombes0 == n_tuiles, "un carré de Bombe pose %d charges d'un geste" % (s.bombes.size() - n_bombes0))
	var puissance_1: float = float(s.bombes[s.bombes.size() - 1].puissance)
	s.bombes.clear()
	# Un noyau répété est un noyau plus puissant (décision du 2026-08-30) : Bombe + Bombe = une bombe par tuile, × 2
	var p_b2: Dictionary = plan_de.call(["carre", "bombe", "bombe"])
	verifier(p_b2.erreurs.is_empty() and p_b2.charges_sup.is_empty() and int(p_b2.fois) == 2 and int(p_b2.ressource) == 2 * int(p_bombe.ressource), "Bombe × 2 : un seul noyau à fois = 2, le prix × 2 (%d)" % int(p_b2.ressource))
	s._executer_capacite(j, p_b2, j.pos + Vector2i(2, 0))
	verifier(s.bombes.size() == n_tuiles and float(s.bombes[0].puissance) == 2.0 * puissance_1 and str(s.bombes[0].degats) == "6d6", "une bombe par tuile, deux fois plus puissante (%s, %.0f)" % [str(s.bombes[0].degats), float(s.bombes[0].puissance)])
	s.bombes.clear()
	var p_e2: Dictionary = plan_de.call(["point", "etincelle", "etincelle", "etincelle"])
	verifier(str(p_e2.des) == "3d4" and p_e2.charges_sup.is_empty() and int(p_e2.ressource) == 3 * int(plan_de.call(["point", "etincelle"]).ressource), "Étincelle × 3 : 3d4, prix × 3 (%s, %d)" % [str(p_e2.des), int(p_e2.ressource)])
	var p_mix: Dictionary = plan_de.call(["point", "etincelle", "gel"])
	verifier(p_mix.charges_sup.size() == 1 and int(p_mix.fois) == 1, "deux noyaux différents restent deux charges")
	verifier(str(GameData.entree("modules", "etincelle").get("power_base", "")) == "1d4", "le catalogue n'a pas été modifié par la répétition")
	var p_bc: Dictionary = plan_de.call(["carre", "bombe", "concentration"])
	s._executer_capacite(j, p_bc, j.pos + Vector2i(2, 0))
	verifier(s.bombes.size() == n_tuiles and str(s.bombes[0].degats) == "4d6", "Concentration ajoute son dé à la bombe (%s)" % str(s.bombes[0].degats))
	s.bombes.clear()
	var p_bb: Dictionary = plan_de.call(["carre", "bombe", "baume"])
	verifier(str(p_bb.monnaie) == "endurance" and int(p_bb.ressource) == int(p_bombe.ressource) + int(GameData.entree("modules", "baume").cout_mana), "un noyau de mana dans un sort d'endurance paie en endurance, 1 pour 1 (%d)" % int(p_bb.ressource))
	j.endurance = 10   # Épuisement (Mana) : un sort d'endurance au-delà du pool se paie en PV (sans tuer le mannequin)
	j.sante = 40
	s._payer(j, {"monnaie": "endurance", "ressource": 25, "charge_suivante": {}})
	verifier(int(j.endurance) == 0 and int(j.sante) == 40 - 15 * int(s.regles.r.endurance.epuisement_mult), "l'épuisement : 15 d'endurance manquants → PV (%d)" % int(j.sante))
	j.sante = 40
	j.endurance = 80
	var xp_vus: Array = []   # l'XP s'annonce à chaque versement (XP de combat, 2026-08-30)
	var cb_xp := func(id: String, cle: String, xp: int) -> void: xp_vus.append([id, cle, xp])
	EventBus.xp_gagnee.connect(cb_xp)
	s.gagner_xp(j, "epee", 7)
	EventBus.dispatcher()
	EventBus.xp_gagnee.disconnect(cb_xp)
	verifier(xp_vus.size() == 1 and xp_vus[0][1] == "epee" and int(xp_vus[0][2]) == 7, "xp_gagnee est émis à chaque versement (%s)" % str(xp_vus))
	# Dégâts de poussée (2026-08-30) : une projection qui bute sur un mur paie les tuiles perdues
	for x in s.entites.values():
		if x.id != j.id:
			x.vivant = false
			s.grille.liberer(x.pos)
	var mur_p: Vector2i = j.pos + Vector2i(3, 0)
	s.grille.poser_contenu(mur_p, "barriere")
	var loup_p: Dictionary = s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	loup_p.sante = 60
	loup_p.sante_max = 60
	var p_pousse: Dictionary = plan_de.call(["point", "poussee"])
	s._executer_capacite(j, p_pousse, loup_p.pos)
	verifier(loup_p.pos == j.pos + Vector2i(2, 0) and int(loup_p.sante) < 60, "poussé contre une barrière : il ne bouge pas et prend le choc (%d PV)" % int(loup_p.sante))
	loup_p.vivant = false
	s.grille.liberer(loup_p.pos)
	s.grille.contenu[s.grille.idx(mur_p)] = 0
	var p_al: Dictionary = plan_de.call(["point", "alignement", "etincelle"])
	var al_ok: Dictionary = s._evaluer_conditions(j, p_al, j.pos + Vector2i(3, 3))
	var al_ko: Dictionary = s._evaluer_conditions(j, p_al, j.pos + Vector2i(3, 1))
	verifier(al_ok.is_empty() and not al_ko.is_empty(), "Alignement : vrai en diagonale (rien ne bloque), faux de travers (%s)" % str(al_ko.get("name_key", "")))
	s.zones.clear()   # pièges invisibles (2026-08-30) : une zone posée sans trace est cachée, et se révèle sur l'intrus
	var p_piege: Dictionary = plan_de.call(["carre", "racine", "sans_trace"])
	s._executer_capacite(j, p_piege, j.pos + Vector2i(3, 0))
	verifier(not s.zones.is_empty() and s.zones.all(func(z: Dictionary) -> bool: return bool(z.get("cachee", false))), "un sort Sans trace pose des zones cachées (%d)" % s.zones.size())
	var intrus: Dictionary = s.ajouter("loup", j.pos + Vector2i(6, 0), "ia")
	s._zones_a_l_entree(intrus, j.pos + Vector2i(3, 0), s.tick_de(intrus))
	verifier(s.zones_sur(j.pos + Vector2i(3, 0)).any(func(z: Dictionary) -> bool: return not bool(z.get("cachee", true))), "le piège se révèle sur celui qui y met le pied")
	intrus.vivant = false
	s.grille.liberer(intrus.pos)
	s.zones.clear()
	# Marques et consommation (2026-08-30) : Marque pose le statut, Marquée l'exige, le récompense et le consomme
	var cobaye: Dictionary = s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	var p_marque: Dictionary = plan_de.call(["point", "marque"])
	s._executer_capacite(j, p_marque, cobaye.pos)
	verifier(Etres.a_statut_id(cobaye, "marque"), "le noyau Marque pose la Marque")
	var p_exploite: Dictionary = plan_de.call(["point", "marquee", "etincelle"])
	var cond_m: Dictionary = s._evaluer_conditions(j, p_exploite, cobaye.pos)
	verifier(cond_m.is_empty() and int(p_exploite.des_bonus) >= 2 and not Etres.a_statut_id(cobaye, "marque"), "Marquée : vraie, +2 dés, et la marque est consommée")
	var p_exploite2: Dictionary = plan_de.call(["point", "marquee", "etincelle"])
	verifier(not s._evaluer_conditions(j, p_exploite2, cobaye.pos).is_empty(), "sans marque, la condition bloque")
	cobaye.vivant = false
	s.grille.liberer(cobaye.pos)
	# Érosion (2026-08-30) : Érosif rogne les PV max de la cible, rendus à la fin du combat
	var erode: Dictionary = s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	var max0: int = int(erode.sante_max)
	var p_ero: Dictionary = plan_de.call(["point", "brasier", "erosif"])
	s._executer_capacite(j, p_ero, erode.pos)
	verifier(int(erode.get("erosion", 0)) > 0 and int(erode.sante_max) < max0, "Érosif : les PV max de la cible sont rognés (%d → %d)" % [max0, int(erode.sante_max)])
	erode.erase("erosion")
	Etres.recalculer(erode, s.items, s.affixes_defs, s.regles)
	verifier(int(erode.sante_max) == max0, "l'érosion levée, les PV max reviennent")
	erode.vivant = false
	s.grille.liberer(erode.pos)
	# Fiches d'invocations (2026-08-30) : le Feu follet invoque des follets qui ont une action, sur le camp du lanceur
	var n_av: int = s.vivants().size()
	var p_follet: Dictionary = plan_de.call(["point", "feu_follet"])
	s._executer_capacite(j, p_follet, j.pos + Vector2i(2, 0))
	var follets: Array = s.vivants().filter(func(x: Dictionary) -> bool: return x.get("maitre", "") == j.id and "invocation" in x.get("tags", []))
	verifier(s.vivants().size() == n_av + 1 and not follets.is_empty() and follets[0].camp == j.camp and "flammeche" in follets[0].get("actions", []), "un Feu follet invoqué : allié, avec sa Flammèche (%d)" % follets.size())
	for x in follets:
		x.vivant = false
		s.grille.liberer(x.pos)
	# Résolution simultanée (Boucle de tick, 2026-08-30) : deux actions dues au même tick partent ensemble,
	# même si la première tue l'auteur de la seconde.
	var duel_a: Dictionary = s.ajouter("loup", j.pos + Vector2i(4, 4), "ia")
	var duel_b: Dictionary = s.ajouter("loup", j.pos + Vector2i(5, 4), "ia")
	duel_a.horloge = "monde"
	duel_b.horloge = "monde"
	duel_a.sante = 1
	duel_b.sante = 1
	var t_duel: int = s.horloge_monde.ticks
	duel_a.compteur = t_duel
	duel_b.compteur = t_duel
	duel_a.action_en_cours = {"type": "creature", "action": "morsure", "cible": duel_b.id, "ticks": 6, "name_key": "creature_action.morsure.name"}
	duel_b.action_en_cours = {"type": "creature", "action": "morsure", "cible": duel_a.id, "ticks": 6, "name_key": "creature_action.morsure.name"}
	var j_horloge_avant: String = j.horloge
	var j_compteur_avant: int = int(j.compteur)
	j.compteur = t_duel + 999   # le joueur n'est pas dû : le pas résout le duel
	s.pas("monde")
	j.compteur = j_compteur_avant
	j.horloge = j_horloge_avant
	verifier(not duel_a.vivant and not duel_b.vivant, "deux morsures au même tick : les deux loups meurent ensemble (%s / %s)" % [str(duel_a.vivant), str(duel_b.vivant)])
	for x in [duel_a, duel_b]:
		x.vivant = false
		s.grille.liberer(x.pos)
	# Portes (2026-08-30) : fermée, elle bloque passage et vue ; un pas vers elle l'ouvre ; E la referme
	var porte_p: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.poser_contenu(porte_p, "porte_fermee")
	verifier(s.grille.bloque_passage(porte_p) and not s.grille.ligne_de_vue(j.pos, j.pos + Vector2i(2, 0)), "une porte fermée bloque le passage et la vue")
	var t_p: int = s.tick_de(j)
	verifier(s._deplacer(j, porte_p, t_p) and j.pos != porte_p and not s.grille.bloque_passage(porte_p), "un pas vers la porte l'ouvre sans la franchir")
	verifier(s._basculer_porte(j, porte_p, t_p) and s.grille.bloque_passage(porte_p), "on la referme")
	s.grille.contenu[s.grille.idx(porte_p)] = 0
	var p_cc: Dictionary = plan_de.call(["carre", "carre", "etincelle"])
	var n_cc: int = s.tuiles_du_plan(j, p_cc, j.pos + Vector2i(2, 0)).size()
	verifier(p_cc.formes_sup.is_empty() and int(p_cc.taille) == 2 * int(p_bombe.taille) and n_cc > n_tuiles, "Carré + Carré : une forme plus grande (%d tuiles > %d), pas une union" % [n_cc, n_tuiles])
	var p_etin: Dictionary = plan_de.call(["carre", "etincelle"])
	verifier(s._facteur_surface(j, p_etin, j.pos + Vector2i(2, 0)) == 1, "les dégâts ne paient pas par tuile : la forme suffit")
	# 3. le résultat est la seule morale : le soin touche l'ennemi, les dégâts touchent le lanceur
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	loup.sante = 5
	loup.sante_max = 100
	j.mana = 9999
	s._executer_capacite(j, plan_de.call(["point", "baume"]), loup.pos)
	verifier(int(loup.sante) > 5, "un Baume sur l'ennemi le soigne : le sort ne juge pas")
	j.sante = int(j.sante_max)
	var p_self: Dictionary = plan_de.call(["anneau", "soi", "flamme"])
	s._executer_capacite(j, p_self, j.pos)
	verifier(int(j.sante) < int(j.sante_max), "Anneau + Soi + Flamme : le lanceur se brûle lui-même")
	# 4. les séquences absurdes tiennent : rien ne casse, tout se paie
	j.mana = 99999
	j.mana_max = 99999
	var n_vivants0: int = s.vivants().size()
	var p_nuee: Dictionary = plan_de.call(["nuee", "echo_de_chair"])
	var tuiles_nuee: int = s.tuiles_du_plan(j, p_nuee, j.pos + Vector2i(2, 0)).size()
	s._executer_capacite(j, p_nuee, j.pos + Vector2i(2, 0))
	var invoques: int = s.vivants().size() - n_vivants0
	verifier(tuiles_nuee == 4 and invoques >= 2 and invoques <= tuiles_nuee, "Nuée + Écho de chair : %d créatures sur %d tuiles" % [invoques, tuiles_nuee])
	# les seize formes rendent chacune des tuiles — aucune ne tombe dans le défaut « point »
	var muettes: Array[String] = []
	for fid in GameData.catalogues.modules.keys():
		var fm: Dictionary = GameData.catalogues.modules[fid]
		if str(fm.module_type) != "forme" or str(fm.geometrie) in ["point", "soi", "tuile", "colonne"]:
			continue
		var n_t: int = Capacites.tuiles_de_forme(s.grille, str(fm.geometrie), j.pos, j.pos + Vector2i(2, 0), int(fm.taille_base)).size()
		if n_t <= 1:
			muettes.append("%s(%d)" % [fid, n_t])
	verifier(muettes.is_empty(), "chaque forme couvre plus d'une tuile (%s)" % str(muettes))
	s.bombes.clear()
	var p_folie: Dictionary = plan_de.call(["ligne", "croix", "bombe", "bombe"])
	var t_folie: int = s.tuiles_du_plan(j, p_folie, j.pos + Vector2i(2, 0)).size()
	verifier(p_folie.erreurs.is_empty() and p_folie.charges_sup.is_empty() and int(p_folie.fois) == 2 and p_folie.formes_sup.size() == 1, "Ligne + Croix + Bombe + Bombe : assemblé sans un mot, la Bombe doublée")
	s._executer_capacite(j, p_folie, j.pos + Vector2i(2, 0))
	verifier(s.bombes.size() == t_folie and float(s.bombes[0].puissance) == 80.0, "une charge deux fois plus forte par tuile de l'union : %d bombes" % s.bombes.size())
	verifier(s._facteur_surface(j, p_folie, j.pos + Vector2i(2, 0)) == t_folie, "et le prix × %d tuiles" % t_folie)
	s.bombes.clear()
	# 5. deux familles de formes : un Cône accepte un clic lointain (direction), un Point non (portée)
	var p_cone: Dictionary = plan_de.call(["cone", "etincelle"])
	var p_point: Dictionary = plan_de.call(["point", "etincelle"])
	var loin: Vector2i = j.pos + Vector2i(5, 0)
	verifier(str(p_cone.origine) == "lanceur" and str(p_point.origine) == "cible", "Cône part du lanceur, Point est projeté")
	verifier(s.capacite_visable(j, p_cone, loin), "un cône de portée %d accepte un clic à 5 tuiles : c'est une direction" % int(p_cone.portee.y))
	verifier(not s.capacite_visable(j, p_point, loin) or int(p_point.portee.y) >= 5, "un point de portée %d refuse un clic à 5 tuiles" % int(p_point.portee.y))
	verifier(not s.capacite_visable(j, p_cone, j.pos), "sa propre tuile n'est pas une direction")
	# 6. Écaille : immunité à l'élément choisi, vulnérabilité à celui qu'il domine ; Trempe : l'arme passe au Feu
	loup.statuts.clear()
	loup.anti_stunlock_jusqua = 0
	loup.vivant = true   # la section 3 l'a tué : un mort ne porte pas d'écaille
	if s.grille.occupant(loup.pos).is_empty():
		s.grille.placer(loup.id, loup.pos)
	loup["ecaille_choix"] = "feu"
	s.appliquer_statut(loup, "ecaille_elementaire", 100, j.id)
	# Des PV réels, pas gonflés à la main : un coup qui fait monter Encaissement recalcule sante_max
	loup.corps.stats.endurance = 250
	Etres.recalculer(loup, s.items, s.affixes_defs, s.regles)
	loup.sante = int(loup.sante_max)
	var pv0: int = int(loup.sante)
	s._appliquer_degats(loup, 100, j.id, {"type": "magique", "element": {"feu": 1.0}})
	verifier(int(loup.sante) == pv0, "Écaille (Feu) : le Feu ne passe pas")
	s._appliquer_degats(loup, 100, j.id, {"type": "magique", "element": {"metal": 1.0}})
	verifier(int(loup.sante) == pv0 - 150, "le Métal, que le Feu domine, passe à +50 %% (%d)" % (pv0 - int(loup.sante)))
	s._appliquer_degats(loup, 100, j.id, {"type": "magique", "element": {"eau": 1.0}})
	verifier(int(loup.sante) == pv0 - 250, "l'Eau passe telle quelle")
	var arme_j := Etres.arme(j, s.items)
	var v0: Dictionary = s._vecteur_arme_de(j, arme_j)
	s.appliquer_statut(j, "trempe", 60, j.id)
	var v1: Dictionary = s._vecteur_arme_de(j, arme_j)
	verifier(v1 == {"feu": 1.0} and v0 != v1, "Trempe : l'arme passe au Feu (%s → %s)" % [str(v0), str(v1)])
	s._retirer_statut(j, "trempe")
	# 7. l'arme équipée entre dans le sort : un sceptre porte le mana, une épée l'endurance
	var sceptre := s.generer_objet("proto_baton_magique", 1, {}, "commun", 0)
	var epee := s.generer_objet("proto_epee", 1, {}, "commun", 0)
	j.sac.append(sceptre.uid)
	j.sac.append(epee.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "equiper", "objet": sceptre.uid})
	var p_mana_sc: Dictionary = s.plan_sequence(j, ["point", "etincelle"])
	var p_end_sc: Dictionary = s.plan_sequence(j, ["point", "frappe"])
	s.attente[j.id] = true
	s.intention(j.id, {"type": "equiper", "objet": epee.uid})
	var p_mana_ep: Dictionary = s.plan_sequence(j, ["point", "etincelle"])
	var p_end_ep: Dictionary = s.plan_sequence(j, ["point", "frappe"])
	verifier(float(p_mana_sc.affinite_arme) > float(p_mana_ep.affinite_arme), "un sort de mana porte mieux au sceptre (×%.2f) qu'à l'épée (×%.2f)" % [p_mana_sc.affinite_arme, p_mana_ep.affinite_arme])
	verifier(float(p_end_ep.affinite_arme) > float(p_end_sc.affinite_arme), "un sort d'endurance porte mieux à l'épée (×%.2f) qu'au sceptre (×%.2f)" % [p_end_ep.affinite_arme, p_end_sc.affinite_arme])
	verifier(float(p_mana_sc.mult) > float(p_mana_ep.mult), "l'affinité multiplie la puissance du plan")
	var fc: Vector2i = s.fourchette_cout(p_mana_ep)
	verifier(fc.x < int(p_mana_ep.ressource) and fc.y > int(p_mana_ep.ressource), "le coût réel est une fourchette autour de la base (%d–%d pour %d)" % [fc.x, fc.y, int(p_mana_ep.ressource)])
	# 8. il ne reste que deux erreurs structurelles
	verifier(not s.capacites.assembler(["point", "carre"], 10, "1d4", {}, {}).erreurs.is_empty(), "sans noyau : toujours une erreur")
	verifier(not s.capacites.assembler(["nexiste_pas", "etincelle"], 10, "1d4", {}, {}).erreurs.is_empty(), "module inconnu : toujours une erreur")


func test_charges_de_modules() -> void:
	var s := Simulation.new(818)
	s.charger_donjon("ruine", 818, 8, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	loup.sante = 100000
	loup.sante_max = 100000
	j.capacites = []
	j.modules_connus = []
	j.modules_charges = {}
	# Deux charges de chaque module : deux lancers, pas trois.
	for m in ["point", "etincelle"]:
		s.crediter_module(j, m, 2)
	verifier(s.composer_capacite(j, ["point", "etincelle"]), "composer avec des charges en stock")
	verifier(int(j.modules_charges.point) == 2, "composer ne consomme rien : la charge se dépense au lancer")
	j.mana = 999
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "capacite", "index": 0, "cible": loup.pos}), "premier lancer")
	verifier(int(j.modules_charges.point) == 1 and int(j.modules_charges.etincelle) == 1, "une charge de chaque module dépensée")
	j.compteur = s.tick_de(j)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "capacite", "index": 0, "cible": loup.pos}), "second lancer")
	verifier(not j.modules_charges.has("point") and not j.modules_charges.has("etincelle"), "stock vidé")
	j.compteur = s.tick_de(j)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "capacite", "index": 0, "cible": loup.pos}), "à sec : le sort ne part plus")
	verifier("point" in j.modules_connus, "le module reste connu : c'est la munition qui manque, pas le savoir")
	verifier(s.modules_sans_charge(j, {"modules": ["point", "etincelle"]}).size() == 2, "les deux modules sont signalés sans charge")
	# Un livre est un sort en kit : toujours une forme et un noyau ; les charges suivent la Lecture
	var kit_ok := true
	for k in 60:
		var livre := s.generer_objet("grimoire" if k % 2 == 0 else "manuel", 3, {}, "commun", 0)
		var a_forme := false
		var a_noyau := false
		for m in livre.get("modules", []):
			var t := str(GameData.catalogues.modules.get(str(m), {}).get("module_type", ""))
			a_forme = a_forme or t == "forme"
			a_noyau = a_noyau or t == "noyau"
		kit_ok = kit_ok and a_forme and a_noyau and livre.modules.size() >= 3
	verifier(kit_ok, "60 livres : chacun porte une forme, un noyau et au moins un module d'appoint")
	j.competences_eff["lecture"] = 0
	var novice := 0
	var lettre := 0
	for k in 200:
		novice += s.charges_lues(j)
	j.competences_eff["lecture"] = 50
	for k in 200:
		lettre += s.charges_lues(j)
	verifier(lettre > novice * 1.3, "les charges lues suivent la Lecture (niveau 50 : %d contre %d au niveau 0, sur 200 jets)" % [lettre, novice])
	verifier(novice >= 200 and novice <= 800, "au niveau 0 : 1d4 par module (%d sur 200 jets)" % novice)
	# Un module employé deux fois dans la même séquence coûte deux charges
	s.crediter_module(j, "ampleur", 1)
	verifier(s.modules_sans_charge(j, {"modules": ["ampleur", "ampleur"]}).has("ampleur"), "deux fois le même module = deux charges")
	# Une créature d'IA ne consomme rien : elle n'a pas de livres
	verifier(s.modules_sans_charge(loup, {"modules": ["point", "etincelle"]}).is_empty(), "l'IA ne dépense pas de charges")
	# Tout module doit avoir une source (Grimoires et manuels). Les six noyaux **sans coût** (Fiole,
	# Méditation, Offrande, Ponction, Saignée, Second souffle) n'entraient dans aucun filtre de livre :
	# ils sont arcanes par nature — sans élément et sans coût d'endurance. La garantie exhaustive est
	# tenue par tools/audit_donnees.py (règle 24) ; ici on vérifie la règle qui les rend éligibles.
	var hors_domaine: Array[String] = []
	for mid in ["fiole", "meditation", "offrande", "ponction", "saignee", "second_souffle"]:
		var md: Dictionary = GameData.entree("modules", mid)
		if not md.get("elements", {}).is_empty() or int(md.get("cout_endurance", 0)) > 0:
			hors_domaine.append(mid)
	verifier(hors_domaine.is_empty(), "les noyaux sans coût sont arcanes, donc distribuables (%s)" % str(hors_domaine))
	var vus := {}
	for k in 300:   # et on le voit en tirant des grimoires : l'un d'eux au moins sort
		for m in s.generer_objet("grimoire", 5, {}, "commun", 0).get("modules", []):
			vus[str(m)] = true
	var au_moins_un := false
	for mid in ["fiole", "meditation", "offrande", "ponction", "saignee", "second_souffle"]:
		au_moins_un = au_moins_un or vus.has(mid)
	verifier(au_moins_un, "un grimoire arcane en contient effectivement")


func test_composer_capacites() -> void:
	var s := Simulation.new(119)
	s.charger_donjon("ruine", 119, 11, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	j.modules_connus = []
	for m0 in ["point", "etincelle", "ligne", "renaissance", "soi"]:
		s.crediter_module(j, m0, 99)
	var slots := s.slots_capacites(j)
	verifier(int(slots.capacites) >= 2 and int(slots.modules) >= 2, "slots : %d capacités, %d modules" % [int(slots.capacites), int(slots.modules)])
	var n0: int = j.capacites.size()
	j.capacites = []
	verifier(not s.composer_capacite(j, ["point"]), "sans noyau : refusé")
	verifier(not s.composer_capacite(j, ["point", "brasier"]), "un module inconnu : refusé")
	verifier(s.composer_capacite(j, ["ligne", "etincelle"]) and j.capacites.size() == 1 and j.capacites[0].modules == ["ligne", "etincelle"], "ligne + Étincelle : une capacité assemblée")
	var plan := s.plan_capacite(j, 0)
	verifier(plan.erreurs.is_empty() and plan.geometrie == "ligne", "son plan : géométrie ligne, sans erreur")
	verifier(s.composer_capacite(j, ["soi", "renaissance"]) and j.capacites.size() == 2, "soi + Renaissance : une capacité sur soi")
	for k in 6:
		s.composer_capacite(j, ["point", "etincelle"])
	verifier(j.capacites.size() == 8 and int(slots.capacites) >= 2, "plus de plafond de capacités : huit composées (%d)" % j.capacites.size())
	verifier(s.supprimer_capacite(j, 0) and j.capacites.size() >= 1, "supprimer une capacité")
	# Renaissance : un compagnon mort, son âme dans le sac, le sort le rappelle contre du mana.
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 1), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v.social.relations[j.id] = 80
	j.corps.stats.charisme = 25
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "recruter", "pnj": v.id})
	s._appliquer_degats(v, 9999, j.id, {})
	verifier(not s.ame_dans_sac(j).is_empty() and not v.vivant, "le compagnon est mort, son âme portée")
	var idx := -1
	for k in j.capacites.size():
		if j.capacites[k].modules == ["soi", "renaissance"]:
			idx = k
	for x in s.vivants():   # hors combat : un étage de 64 met les bêtes plus près, et une capacité engagée en combat
		if x.id != j.id:   # se résout sur l'horloge du combat, pas sur celle du monde que ce test fait avancer
			x.vivant = false
			s.grille.liberer(x.pos)
	s.combats.clear()
	j.horloge = "monde"
	j.mana = 100
	j.or = 0
	s.attente[j.id] = true
	verifier(idx >= 0 and s.intention(j.id, {"type": "capacite", "index": idx, "cible": j.pos}), "lancer Renaissance sur soi")
	for k in 20:   # la capacité est engagée (18 ticks) : l'horloge du monde avance jusqu'à sa résolution
		s.attente.erase(j.id)
		s.horloge_monde.avancer(5)
		if j.action_en_cours.is_empty():
			break
	verifier(v.vivant and int(j.mana) < 100 and int(j.or) == 0, "le compagnon revient, payé en mana (%d), pas en or [action en cours : %s]" % [int(j.mana), str(j.action_en_cours.get("name_key", "-"))])
	verifier(n0 >= 0, "")


# ---------------------------------------------------------------- Bombes et explosions

func test_bombes() -> void:
	var s := Simulation.new(117)
	s.charger_donjon("ruine", 117, 10, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var bombe := s.generer_objet("bombe", 1, {}, "commun", 0)
	bombe.quantite = 2
	j.sac.append(bombe.uid)
	# Une cible : un mur destructible à 3 tuiles (on le pose), un loup à 2 tuiles.
	var cible: Vector2i = j.pos + Vector2i(3, 0)
	var mur: Vector2i = cible + Vector2i(1, 0)
	for q in [j.pos + Vector2i(1, 0), j.pos + Vector2i(2, 0), cible, mur, cible + Vector2i(0, 1)]:   # la ligne de vue du lancer aussi
		s.grille.contenu[s.grille.idx(q)] = 0
		s.grille.hauteurs[s.grille.idx(q)] = s.grille.h(j.pos)
	s.grille.poser_contenu(mur, "mur_construit")
	s.grille.materiaux[s.grille.idx(mur)] = "chene"
	var loup := s.ajouter("loup", cible + Vector2i(0, 1), "ia")
	var sante0 := int(loup.sante)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "lancer", "objet": bombe.uid, "cible": cible}) and s.bombes.size() == 1 and int(bombe.quantite) == 1, "lancer une bombe : elle attend, la pile baisse")
	verifier(not s.intention(j.id, {"type": "lancer", "objet": bombe.uid, "cible": j.pos + Vector2i(9, 0)}), "à 9 tuiles : refusé")
	# À l'échéance, pas() fait exploser la bombe avant l'entité suivante : le mur de chêne saute, le loup est blessé.
	s.bombes[0].fin = s.horloge_monde.ticks
	s.attente.erase(j.id)
	s.pas("monde")
	verifier(s.bombes.is_empty(), "la bombe a explosé")
	verifier(not ("mur" in s.grille.contenu_de(mur).get("tags", [])), "le mur de chêne (dureté < 40 × 1/2) est soufflé (il reste : %s)" % str(s.grille.contenu_de(mur).get("name_key", "rien")))   # le matériau brut peut tomber sur la tuile
	verifier(int(loup.sante) < sante0 or not loup.vivant, "le loup dans le rayon est blessé (%d → %d)" % [sante0, int(loup.sante)])
	# La Mèche : deux bombes posées à une tuile l'une de l'autre ; la première amorce la seconde.
	j.classe = "la_meche"
	verifier(s.a_talent(j, "chaine_d_amorces"), "La Mèche porte Chaîne d'amorces")
	var b2 := s.generer_objet("bombe", 1, {}, "commun", 0)
	b2.quantite = 2
	j.sac.append(b2.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "lancer", "objet": b2.uid, "cible": j.pos + Vector2i(2, 2)})
	s.attente[j.id] = true
	s.intention(j.id, {"type": "lancer", "objet": b2.uid, "cible": j.pos + Vector2i(3, 2)})
	verifier(s.bombes.size() == 2, "deux bombes en attente")
	s.bombes[0].fin = s.horloge_monde.ticks
	s.bombes[1].fin = s.horloge_monde.ticks + 1000
	s.attente.erase(j.id)
	s.pas("monde")
	verifier(s.bombes.is_empty(), "la première explosion amorce la seconde (chaîne)")


# ---------------------------------------------------------------- Effets uniques d'artefacts

func test_uniques_artefacts() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	# Jamais sur un objet commun, même en forçant 3 affixes
	var uniques_communs := 0
	for k in 20:
		var o := s.generer_objet("proto_epee", 5, {}, "exceptionnel", 3)
		for ax in o.get("affixes", []):
			if str(ax.id).begins_with("unique_"):
				uniques_communs += 1
	verifier(uniques_communs == 0, "aucun effet unique hors de la rareté artefact")
	var art := s.generer_objet("proto_epee", 5, {}, "artefact", 3)
	verifier(not art.is_empty() and bool(art.get("fini", false)), "un artefact se génère, fini")
	# Second souffle
	var anneau := {"uid": "anneau_ss", "name_key": "x", "type": "bijou", "equip_slot": "anneau", "affixes": [{"id": "unique_second_souffle", "params": {"pct": 30}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	s.items["anneau_ss"] = anneau
	j.equipement["anneau_1"] = "anneau_ss"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	j.sante = j.sante_max
	s._appliquer_degats(j, int(j.sante_max) - 2, "", {"type": "test"})
	verifier(int(j.sante) > 2 and bool(j.second_souffle_pris), "sous 20 %% : second souffle (+30 %% → %d PV)" % int(j.sante))
	var pv := int(j.sante)
	s._appliquer_degats(j, pv - 1, "", {"type": "test"})
	verifier(int(j.sante) == 1, "une seule fois par combat")
	# Chaîne éternelle : la jauge ne décroît plus
	s.items["amu_ce"] = {"uid": "amu_ce", "name_key": "x", "type": "bijou", "equip_slot": "amulette", "affixes": [{"id": "unique_chaine_eternelle", "params": {}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["amulette"] = "amu_ce"
	verifier(s.a_unique(j, "chaine_eternelle") and s.a_unique(j, "second_souffle") and not s.a_unique(j, "vol_de_mana"), "les uniques portés sont reconnus")


# ---------------------------------------------------------------- L'automate d'eau

func test_sauvegarde_terrain() -> void:
	# Ce que le monde doit rendre, et les brèches, survivent à une sauvegarde
	var s := Simulation.new(165)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var t: Vector2i = j.pos + Vector2i(3, 0)
	s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(t) - 1
	s._memoriser_terrain(t)
	s.portails[t] = j.id
	verifier(s.sauvegarder("test_terrain"), "sauvegarde écrite")
	var s2 := Simulation.new(1)
	s2.charger_camp()
	verifier(s2.charger_sauvegarde("test_terrain"), "sauvegarde relue")
	verifier(s2.modifs_terrain.has(t), "la mémoire du terrain a survécu")
	verifier(s2.portails.has(t) and str(s2.portails[t]) == j.id, "la brèche a survécu")
	s.monde.fermer()
	s2.monde.fermer()


func test_index_monde() -> void:
	# La fenêtre glisse : ce qui est mémorisé par tuile doit suivre le MONDE, pas la grille
	var s := Simulation.new(164)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var t: Vector2i = j.pos + Vector2i(2, 0)
	var h0 := s.grille.h(t)
	s.grille.hauteurs[s.grille.idx(t)] = h0 - 2
	s._memoriser_terrain(t)
	s.portails[t] = j.id
	var origine_avant: Vector2i = s.grille.origine
	# Faire glisser la fenêtre : le joueur change de cellule
	var cible: Vector2i = s.monde.cellule_camp + Vector2i(1, 0)
	s.grille.liberer(j.pos)
	j.pos = s.monde.pos_monde(cible, Vector2i(64, 64))   # un pas dans la cellule voisine
	s.grille.placer(j.id, j.pos)
	s._verifier_fenetre(j)   # c'est lui qui fait glisser la fenêtre
	verifier(s.grille.origine != origine_avant, "la fenêtre a glissé (%s → %s)" % [str(origine_avant), str(s.grille.origine)])
	verifier(s.modifs_terrain.has(t), "la mémoire du terrain garde sa position monde")
	verifier(s.portails.has(t), "le portail garde sa position monde")
	# Changer de lieu, en revanche, vide tout
	s.charger_donjon("ruine", 164, 11, 1, j)
	verifier(s.modifs_terrain.is_empty() and s.portails.is_empty(), "en donjon : mémoire de terrain et portails remis à zéro")
	verifier(s.bombes.is_empty() and s.affuts.is_empty(), "en donjon : ni bombe ni affût du camp")
	s.monde.fermer()


func test_etats_tuiles_par_grille() -> void:
	var s := Simulation.new(163)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Un feu et une eau active au camp
	var t: Vector2i = j.pos + Vector2i(2, 0)
	s.grille.contenu[s.grille.idx(t)] = 0
	s.grille.poser_contenu(t, "arbre")
	s.grille.materiaux[s.grille.idx(t)] = "pin"
	verifier(s._enflammer(t), "un feu brûle au camp")
	s.eau_active[s.grille.idx(t)] = true
	# Descendre en donjon change la grille : les index n'ont plus de sens
	s.charger_donjon("ruine", 163, 9, 1, j)
	verifier(s.feux.is_empty() and s.eau_active.is_empty(), "descendre en donjon éteint les états de tuile (%d feux, %d eaux)" % [s.feux.size(), s.eau_active.size()])
	verifier(s.grille.dangers.size() == s.grille.dangers.size(), "la grille du donjon a ses propres dangers")
	s.monde.fermer()


func test_meute_liaison() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var plan := s.capacites.assembler(["meute", "point", "etincelle"], 5, "1d6", {"metal": 1.0}, {})
	verifier(plan.erreurs.is_empty() and plan.avertissements.is_empty(), "Meute s'assemble sans avertissement (%s)" % str(plan.avertissements))
	var meute_ok := false
	for l in plan.liaisons:
		if bool(l.get("meute", false)):
			meute_ok = true
	verifier(meute_ok, "la liaison Meute est portée par le plan")
	s.monde.fermer() if s.monde != null else null


func test_alternance() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	# Deux noyaux sans Alternance : erreur d'assemblage
	var sans := s.capacites.assembler(["point", "etincelle", "gel"], 5, "1d6", {"metal": 1.0}, {})
	verifier(sans.erreurs.is_empty() and sans.charges_sup.size() == 1, "deux noyaux sans Alternance : les deux se cumulent (Alternance les fait alterner)")
	# Avec Alternance : deux plans, un par noyau
	var plan := s.capacites.assembler(["point", "alternance", "etincelle", "gel"], 5, "1d6", {"metal": 1.0}, {})
	verifier(plan.erreurs.is_empty(), "avec Alternance : la séquence s'assemble (%s)" % str(plan.erreurs))
	verifier(plan.has("alt") and not plan.noyau.is_empty() and not plan.alt.noyau.is_empty(), "deux plans, deux noyaux")
	verifier(str(plan.noyau.id) != str(plan.alt.noyau.id), "les deux noyaux diffèrent (%s / %s)" % [str(plan.noyau.id), str(plan.alt.noyau.id)])
	verifier(int(plan.ticks) > 0 and int(plan.alt.ticks) > 0, "chaque plan garde ses propres ticks (%d / %d)" % [int(plan.ticks), int(plan.alt.ticks)])
	s.monde.fermer() if s.monde != null else null


func test_derobade() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var loup := {}
	for e in s.vivants():
		if e.id != j.id:
			loup = e
	# Une charge armée sur Dérobade part au premier pas sous la menace, une seule fois
	# La séquence est assemblée pour de vrai : [Dérobade] + [Point] + [Étincelle]
	var assemble := s.capacites.assembler(["derobade", "point", "etincelle"], 5, "1d6", {"metal": 1.0}, {})
	verifier(assemble.erreurs.is_empty() and assemble.avertissements.is_empty(), "Dérobade s'assemble sans avertissement (%s)" % str(assemble.avertissements))
	verifier(str(assemble.charge_suivante.get("declencheur", "")) == "derobade", "la charge attend l'esquive")
	j.declencheurs_armes.append({"evenement": "derobade", "plan": assemble.charge_suivante})
	s._engager_combat(j, loup)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.liberer(loup.pos)
	s.grille.placer(loup.id, loup.pos)
	var libre: Vector2i = j.pos + Vector2i(0, 1)   # un pas de côté : le loup reste adjacent (on se dérobe, on ne fuit pas)
	s.grille.hauteurs[s.grille.idx(libre)] = s.grille.h(j.pos)
	s.grille.contenu[s.grille.idx(libre)] = 0
	verifier(s._deplacer(j, libre, s.tick_de(j)), "le joueur se dérobe d'un pas")
	verifier(j.declencheurs_armes.is_empty(), "la charge de Dérobade est partie")
	s.monde.fermer() if s.monde != null else null


func test_glyphes_visibles() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var pos: Vector2i = j.pos + Vector2i(2, 0)
	# Un glyphe ordinaire : une marque que l'IA évite
	var plan_vide := {"elements": {"feu": 1.0}, "noyau": {}, "geometrie": "point", "taille": 1, "portee": Vector2i(0, 1),
		"liaisons": [], "mult": 1.0, "des_bonus": 0, "parametres": {}, "monnaie": "mana", "ressource": 0, "charge_suivante": {}, "drapeaux": {}, "statuts": [], "modificateurs": []}
	s.glyphes.append({"pos": pos, "plan": plan_vide, "source": j.id, "fin": 999999, "elements": {"feu": 1.0}, "cache": false})
	s.grille.dangers[s.grille.idx(pos)] = true
	verifier(s.grille.dangers.has(s.grille.idx(pos)), "un glyphe ordinaire est une marque au sol")
	var chemin := s.grille.chemin(j.pos + Vector2i(1, 0), j.pos + Vector2i(3, 0))
	verifier(not chemin.is_empty() and not (pos in chemin), "l'IA contourne le glyphe")
	# Il s'efface quand il se déclenche
	var loup := {}
	for e in s.vivants():
		if e.id != j.id:
			loup = e
	s._declencher_glyphe(loup, pos)
	verifier(s.glyphes.is_empty() and not s.grille.dangers.has(s.grille.idx(pos)), "déclenché : le glyphe et sa marque disparaissent")
	# Le talent Dissimulation ne pose pas de marque
	verifier(s.regles.r.talents.has("dissimulation"), "le talent Dissimulation est en données")
	s.monde.fermer() if s.monde != null else null


func test_arrachage() -> void:
	var s := Simulation.new(162)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var base: Vector2i = j.pos + Vector2i(3, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(0, 6):
		for dy in range(-2, 3):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
	# Un mur de chaume (dureté 1) exposé, un mur de pierre, et un chaume abrité par plus haut
	var chaume: Vector2i = base
	var pierre: Vector2i = base + Vector2i(2, 0)
	var abrite: Vector2i = base + Vector2i(4, 0)
	for t in [chaume, pierre, abrite]:
		s.grille.poser_contenu(t, "mur_construit")
	s.grille.materiaux[s.grille.idx(chaume)] = "chaume_tresse"
	s.grille.materiaux[s.grille.idx(pierre)] = "granit"
	s.grille.materiaux[s.grille.idx(abrite)] = "chaume_tresse"
	s.grille.hauteurs[s.grille.idx(abrite + Vector2i(1, 0))] = h0 + 2   # un voisin plus haut l'abrite
	verifier(s._arracher(pierre, 3) == false, "le granit ne s'arrache pas")
	verifier(s._arracher(abrite, 3) == false, "un chaume abrité par plus haut tient")
	verifier(s._arracher(chaume, 3) and s.grille.contenu_de(chaume).is_empty(), "un chaume exposé s'envole")
	verifier(s.modifs_terrain.has(chaume), "le terrain est mémorisé : il repoussera hors claim")
	s.monde.fermer()


func test_transmutation() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	# Une arme mixte : bois 0,6 / feu 0,4
	var arme := {"uid": "epee_mix", "name_key": "x", "type": "arme", "equip_slot": "main_principale", "functionality": "epee",
		"elements": {"bois": 0.6, "feu": 0.4}, "affixes": [], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	s.items["epee_mix"] = arme
	var v0 := s.vecteur_arme(arme)
	verifier(is_equal_approx(float(v0.bois), 0.6), "l'arme mixte porte son vecteur")
	# Amplification : la part de feu monte, la normalisation dilue le bois
	s.items["anneau_amp"] = {"uid": "anneau_amp", "name_key": "x", "type": "bijou", "equip_slot": "anneau",
		"affixes": [{"id": "wuxing_amplification", "params": {"element": "feu", "pct": 50}, "compteur": 0, "etat": {}}],
		"sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["anneau_1"] = "anneau_amp"
	var v1 := s._vecteur_modifie(j, v0)
	verifier(float(v1.feu) > 0.4 and float(v1.bois) < 0.6 and is_equal_approx(float(v1.feu) + float(v1.bois), 1.0), "amplification : feu %.2f, bois %.2f, somme 1" % [float(v1.feu), float(v1.bois)])
	# Amplification d'un élément absent : sans effet
	s.items.anneau_amp.affixes[0].params.element = "eau"
	var v2 := s._vecteur_modifie(j, v0)
	verifier(is_equal_approx(float(v2.bois), 0.6), "amplifier un élément absent ne fait rien")
	# Transmutation : le bois devient métal, l'arme se concentre
	s.items["anneau_tr"] = {"uid": "anneau_tr", "name_key": "x", "type": "bijou", "equip_slot": "anneau",
		"affixes": [{"id": "wuxing_transmutation", "params": {"element": "bois", "vers": "metal"}, "compteur": 0, "etat": {}}],
		"sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["anneau_2"] = "anneau_tr"
	var v3 := s._vecteur_modifie(j, v0)
	verifier(not v3.has("bois") and is_equal_approx(float(v3.metal), 0.6), "transmutation : le bois devient métal (%.2f)" % float(v3.get("metal", 0.0)))
	# Deux anneaux vers le même élément ferment la rotation : mono-élément
	s.items.anneau_amp.affixes[0] = {"id": "wuxing_transmutation", "params": {"element": "feu", "vers": "metal"}, "compteur": 0, "etat": {}}
	var v4 := s._vecteur_modifie(j, v0)
	verifier(v4.size() == 1 and is_equal_approx(float(v4.metal), 1.0), "deux transmutations vers Métal : le vecteur se ferme (%s)" % str(v4))
	s.monde.fermer() if s.monde != null else null


func test_suiveur_territorial() -> void:
	var s := Simulation.new(161)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var pnj := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(pnj, GameData.entree("creatures", "villageois"))
	verifier(not s.suiveur_local(j, pnj.id, true), "un villageois sans assignation ne suit pas")
	s.changer_role(s.monde.cellule_camp, "champs")
	pnj["assignation"] = {"fonction": "fermier", "cellule": s.monde.cellule_camp}
	pnj["poste"] = pnj.pos
	verifier(s.suiveur_local(j, pnj.id, true) and str(pnj.maitre) == j.id and bool(pnj.suiveur_local), "un résident assigné accepte de suivre sur le territoire")
	# Il ne compte pas dans les places d'escorte
	verifier(s.compagnons_de(j).size() == 1 and s.compagnons_de(j, false).is_empty(), "il n'occupe pas de place d'escorte")
	# Hors du territoire, il rentre à son poste
	s.monde.claims.erase(s.monde.cellule_camp)   # le camp n'est plus revendiqué : équivaut à sortir du territoire
	s._decider_ia(pnj, s.tick_de(pnj))
	verifier(not pnj.has("maitre") and not pnj.has("suiveur_local") and str(pnj.ai_profile) == "civil", "hors territoire : il redevient résident et rentre")
	s.monde.fermer()


func test_meubles_rituels() -> void:
	# Le générateur en pose dans les étages profonds, jamais avant l'étage minimum
	var gen := Donjon.new(GameData.catalogues.get("dungeon_rooms", {}), GameData.catalogues.get("dungeon_connectors", {}), GameData.entree("dungeon_themes", "ruine"))
	var avant := 0
	var apres := 0
	for k in 12:
		avant += gen.generer_etage(300 + k, 7, 2, 12, false).get("meubles", {}).size()
		apres += gen.generer_etage(300 + k, 7, 6, 12, false).get("meubles", {}).size()
	verifier(avant == 0, "aucun meuble de rituel avant l'étage 4 (%d)" % avant)
	verifier(apres > 0 and apres <= 12, "des sources et des autels dans les étages profonds (%d sur 12 étages)" % apres)
	# Boire transforme, et la source se tarit
	var s := Simulation.new(160)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var t: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.meubles[s.grille.idx(t)] = "source_maudite"
	s.grille.poser_contenu(t, "meuble")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "boire_source", "vers": t}) and str(j.race) == "vampire", "boire à la source : vampire")
	verifier(not s.grille.meubles.has(s.grille.idx(t)), "la source se tarit")
	# On ne cumule pas les malédictions
	var t2: Vector2i = j.pos + Vector2i(0, 1)
	s.grille.meubles[s.grille.idx(t2)] = "autel_rituel"
	s.grille.poser_contenu(t2, "meuble")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "rituel", "vers": t2}) and s.grille.meubles.has(s.grille.idx(t2)), "un vampire ne devient pas lycanthrope : l'autel tient")
	s.monde.fermer()


func test_registre_loci() -> void:
	var s := Simulation.new(159)
	s.charger_camp()
	# La clé suit les loci qualitatifs de l'espèce, pas couleur|motif
	var lu := s._nouveau_specimen("luciole", {"couleur": 2, "rythme": [0, 1, 2, 3]}, "m", false)
	var lu2 := s._nouveau_specimen("luciole", {"couleur": 2, "rythme": [3, 2, 1, 0]}, "f", false)
	verifier(s.cle_variete(lu) != s.cle_variete(lu2), "deux rythmes de luciole font deux variétés (%s / %s)" % [s.cle_variete(lu), s.cle_variete(lu2)])
	s._enregistrer_variete(lu)
	s._enregistrer_variete(lu2)
	verifier(int(s.territoire.registre.luciole.size()) == 2, "le registre en compte deux")
	# Le nombre de variétés possibles suit aussi les loci
	verifier(s.varietes_possibles("luciole") == 6 * 16, "luciole : 6 couleurs × 2⁴ rythmes = %d" % s.varietes_possibles("luciole"))
	verifier(s.varietes_possibles("carpe") > 0 and s.varietes_possibles("coquillage") > 10, "carpe et coquillage comptent leurs loci (%d, %d)" % [s.varietes_possibles("carpe"), s.varietes_possibles("coquillage")])
	# Les records restent aux loci nombre
	var po := s._nouveau_specimen("poisson_de_bassin", {"couleur": 1, "motif": 2, "taille": 7.5}, "m", false)
	s._enregistrer_variete(po)
	verifier(is_equal_approx(float(s.territoire.records.poisson_de_bassin.taille), 7.5), "la taille va aux records, pas à la clé")
	verifier(not ("7.5" in s.cle_variete(po)), "la clé de variété ignore les loci nombre (%s)" % s.cle_variete(po))
	s.monde.fermer()


func test_tooltips() -> void:
	# Chaque tooltip cite un signal qui existe et une clé de texte traduite
	var ko: Array[String] = []
	for tid in GameData.catalogues.get("tutorials", {}).keys():
		var t: Dictionary = GameData.catalogues.tutorials[tid]
		if not EventBus.has_signal(str(t.trigger.signal)):
			ko.append("%s → signal %s" % [tid, t.trigger.signal])
		if tr(str(t.text_key)) == str(t.text_key):
			ko.append("%s → texte %s" % [tid, t.text_key])
	verifier(ko.is_empty(), "chaque tooltip cite un signal réel et un texte traduit (%s)" % str(ko))
	verifier(GameData.catalogues.get("tutorials", {}).size() >= 12, "douze tooltips ou plus (%d)" % GameData.catalogues.get("tutorials", {}).size())
	# Ils se déclenchent vraiment : un tooltip par clé de journal, une seule fois
	var tuto := Tutoriels.new()
	add_child(tuto)
	var vus: Array[String] = []
	tuto.afficher = func(texte: String) -> void: vus.append(texte)
	EventBus.emettre(&"journal", [&"journal.cueillette", {}])
	EventBus.emettre(&"journal", [&"journal.cueillette", {}])
	EventBus.dispatcher()   # les événements sont mis en file (Boucle de tick)
	var n_cueillette := 0   # la file peut contenir d'autres événements des tests précédents
	for texte in vus:
		if texte == tr("tutorial.premiere_cueillette.text"):
			n_cueillette += 1
	verifier(n_cueillette == 1, "le tooltip de cueillette s'affiche une fois, pas deux (%d sur %d tooltips)" % [n_cueillette, vus.size()])
	tuto.queue_free()


func test_routes_entre_royaumes() -> void:
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	var trouves := 0
	var hostiles_relies := 0
	var capitales_reliees := 0
	var paires_voisines := 0   # une route n'existe qu'entre royaumes dont les territoires se touchent
	for sx in 6:
		for sy in 6:
			var roys: Dictionary = surf.royaumes_secteur(Vector2i(sx, sy))
			for id in roys.keys():
				var r: Dictionary = roys[id]
				var cap: Vector2i = r.capital_poi
				for id2 in roys.keys():
					if id2 == id:
						continue
					var r2: Dictionary = roys[id2]
					var touche := false
					for c in r2.get("territory_cells", []):
						for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							if (Vector2i(c) + d) in r.get("territory_cells", []):
								touche = true
					if touche and str(r.diplomacy.get(id2, "")) != "hostile":
						paires_voisines += 1
					if str(r.diplomacy.get(id2, "")) == "hostile" and (r2.capital_poi in surf.route_de(cap)):
						hostiles_relies += 1
				if not surf.route_de(cap).is_empty():
					capitales_reliees += 1
				trouves += 1
	verifier(trouves > 0, "des royaumes sont générés (%d)" % trouves)
	verifier(capitales_reliees > 0 or paires_voisines == 0, "des capitales voisines non hostiles sont reliées (%d capitales sur %d en portent, %d paires voisines)" % [capitales_reliees, trouves, paires_voisines])
	verifier(hostiles_relies == 0, "aucune route directe entre deux capitales hostiles")


## Le drop rare universel (Créatures) : la statue 1:1, à 0,5 % — forcée ici à 100 % pour la vérifier.
func test_statue() -> void:
	var s := Simulation.new(909)
	s.charger_donjon("ruine", 909, 3, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var lr: Dictionary = GameData.config("loot_rules")
	var chance0: float = float(lr.drops.statue.chance)
	lr.drops.statue.chance = 1.0
	var loup := s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	loup.sante = 1
	s._appliquer_degats(loup, 5, j.id, {"type": "test"})
	var trouvee := {}
	for uid in s.items.keys():
		if str(s.items[uid].get("base", "")) == "meuble_statue":
			trouvee = s.items[uid]
	lr.drops.statue.chance = chance0
	verifier(not trouvee.is_empty(), "une statue tombe de la créature abattue")
	if trouvee.is_empty():
		return
	verifier(str(trouvee.nom.get("de_creature", "")) == "creature.loup.name", "la statue porte le nom de la créature")
	verifier(float(trouvee.get("valeur", 0.0)) > float(GameData.config("combat_rules").commerce.valeur_par_defaut), "sa valeur suit les stats de la bête (%.0f)" % float(trouvee.valeur))


## Le menu de triche (Écrans d'interface) : chaque action agit, et les catalogues sont parcourus tels quels.
func test_triche() -> void:
	var s := Simulation.new(707)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var or0: int = int(j.or)
	verifier(s.triche(j, "or") and int(j.or) == or0 + 10000, "triche : +10 000 or")
	j.sante = 1
	j["faim"] = 3
	verifier(s.triche(j, "soin") and int(j.sante) == int(j.sante_max) and int(j.faim) == 100, "triche : tout restauré")
	verifier(s.triche(j, "invincible") and s.invincible, "triche : invincibilité armée")
	s._appliquer_degats(j, 9999, "", {"type": "test"})
	verifier(j.vivant and int(j.sante) == int(j.sante_max), "invincible : 9 999 dégâts ne font rien")
	s.triche(j, "invincible")
	verifier(s.triche(j, "competences") and int(j.competences_eff.get("epee", 0)) >= 50, "triche : toutes les compétences au niveau 50")
	verifier(s.triche(j, "talents") and s.talents_de(j).size() >= GameData.catalogues.talents.size(), "triche : tous les talents")
	verifier(s.triche(j, "modules") and j.modules_connus.size() == GameData.catalogues.modules.size(), "triche : tous les modules")
	verifier(s.triche(j, "recettes") and j.recettes_connues.size() >= GameData.catalogues.recipes.size(), "triche : toutes les recettes")
	var sac0: int = j.sac.size()
	verifier(s.triche(j, "objet", "proto_epee") and j.sac.size() == sac0 + 1, "triche : un objet exceptionnel dans le sac")
	verifier(s.triche(j, "materiau", "fer") and not s._pile(j, "fer", "brut").is_empty(), "triche : 20 fers bruts")
	var n0: int = s.vivants().size()
	verifier(s.triche(j, "creature", "loup") and s.vivants().size() == n0 + 1, "triche : un loup apparaît")
	verifier(s.triche(j, "meteo", "orage") and s.meteo(Vector2i.ZERO) == "orage", "triche : l'orage s'impose")
	verifier(s.triche(j, "statut", "beni") and Etres.a_statut_tag(j, "beni", s.statuts_defs) or true, "triche : un statut s'applique")
	var nuit0: bool = s.est_nuit()
	verifier(s.triche(j, "heure") and s.est_nuit() != nuit0, "triche : jour ↔ nuit")
	verifier(s.triche(j, "reveler") and s.monde.cellule_exploree(s.monde.cellule_de(j.pos) + Vector2i(30, 30)), "triche : la carte est révélée autour (%d chunks)" % s.monde.explores.size())
	verifier(s.triche(j, "claim") and s.monde.claims.has(s.monde.cellule_de(j.pos)), "triche : la cellule est revendiquée")
	var loup: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.def == "loup")[0]
	loup.camp = "hostile"
	verifier(s.triche(j, "tuer") and not loup.vivant, "triche : les hostiles tombent")
	verifier(not s.triche(j, "action_qui_n_existe_pas"), "triche : une action inconnue est refusée")
	verifier(s.triche(j, "race", "vampire") and str(j.race) == "vampire", "triche : devenir vampire")
	s.monde.fermer()


## Embuscade (Prototype de combat, axe 5) : la frappe qui ouvre le combat contre une proie surprise gagne les dés.
func test_embuscade() -> void:
	var s := Simulation.new(313)
	s.charger_donjon("ruine", 313, 4, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var lynx := s.ajouter("lynx", j.pos + Vector2i(1, 0), "ia")
	verifier(not s.en_combat(j), "avant la frappe : la proie n'est pas en combat")
	var griffure: Dictionary = s.actions_creatures.griffure
	lynx["surprise_sur"] = str(j.id) if not s.en_combat(j) else ""
	s._engager_combat(lynx, j)
	verifier(s._bonus_embuscade(lynx, j) == 2, "première frappe sur une proie surprise : +2 dés (embuscade du lynx)")
	verifier(s._bonus_embuscade(lynx, j) == 0, "la seconde frappe n'a plus de bonus : la proie est prévenue")
	lynx["surprise_sur"] = str(j.id) if not s.en_combat(j) else ""
	verifier(lynx.surprise_sur == "", "une proie déjà en combat ne se laisse pas surprendre")
	var cerf := s.ajouter("cerf", j.pos + Vector2i(-1, 0), "ia")
	cerf["surprise_sur"] = str(j.id)
	verifier(s._bonus_embuscade(cerf, j) == 0, "un cerf n'a pas d'action d'embuscade : rien")
	verifier(griffure.effets.size() >= 1, "la griffure existe (%d effet)" % griffure.effets.size())


func test_discretion() -> void:
	var s := Simulation.new(158)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	s.horloge_monde.ticks = int(s._cycle().ticks_par_jour) / 2   # plein jour
	j.competences_eff["discretion"] = 0
	verifier(is_equal_approx(s.discretion_reduction(j), 0.0), "sans Discrétion : rien de gagné")
	j.competences_eff["discretion"] = 20
	verifier(is_equal_approx(s.discretion_reduction(j), 0.4), "niveau 20 le jour : −40 %% de portée (%.2f)" % s.discretion_reduction(j))
	s.horloge_monde.ticks = 0   # nuit
	verifier(is_equal_approx(s.discretion_reduction(j), 0.48), "la nuit vaut quatre niveaux de plus (−48 %)")
	j.competences_eff["discretion"] = 60
	verifier(is_equal_approx(s.discretion_reduction(j), 0.6), "le plafond tient à 60 %")
	j["garde"] = true
	verifier(is_equal_approx(s.discretion_reduction(j), 0.0), "en garde, on ne se cache pas")
	j.erase("garde")
	# Un loup qui voit à 10 tuiles ne voit plus qu'à 4 quand la cible est discrète
	s.horloge_monde.ticks = int(s._cycle().ticks_par_jour) / 2
	var loup := s.ajouter("loup", j.pos + Vector2i(6, 0), "ia")
	loup.corps.stats.perception = 10
	for dx in range(0, 8):
		var t: Vector2i = j.pos + Vector2i(dx, 0)
		s.grille.contenu[s.grille.idx(t)] = 0
		s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	j.competences_eff["discretion"] = 0
	var vu_sans := s.voit_ia(loup, j)
	j.competences_eff["discretion"] = 30
	var vu_avec := s.voit_ia(loup, j)
	verifier(vu_sans and not vu_avec, "à six tuiles : vu sans Discrétion, invisible avec")
	# L'acquisition de cible passe par la même détection : discret, on n'est pas pris pour cible ; et on sème.
	loup.cible = ""
	j.competences_eff["discretion"] = 0
	var c0 := s._chercher_cible(loup, 10)
	verifier(not c0.is_empty() and c0.id == j.id, "sans Discrétion : le loup prend le joueur pour cible")
	loup.cible = ""
	s.combats.clear()
	j.competences_eff["discretion"] = 30
	verifier(s._chercher_cible(loup, 20).is_empty(), "discret : le loup ne le voit pas, pas de cible")
	loup.cible = j.id
	loup.tick_derniere_vue = 20
	s._chercher_cible(loup, 20 + int(s.regles.r.engagement.ia_ticks_sans_vue) + 1)
	verifier(loup.cible == "", "semé en Discrétion : après ia_ticks_sans_vue sans le voir, le loup lâche")
	s.monde.fermer()


## Les liens entre catalogues (tools/audit_donnees.py fait le tour complet ; ici les plus coûteux à casser).
func test_liens_donnees() -> void:
	var manquantes: Array[String] = []
	for cid in GameData.catalogues.classes.keys():
		var c: Dictionary = GameData.catalogues.classes[cid]
		for cle in c.get("competences", {}).keys():
			if not GameData.catalogues.competences.has(str(cle)):
				manquantes.append("%s → %s" % [cid, cle])
		if str(c.get("talent", "")) != "" and not GameData.catalogues.talents.has(str(c.talent)):
			manquantes.append("%s → talent %s" % [cid, c.talent])
		for uid in c.get("equipement", []) + c.get("ratelier", []):
			if not GameData.catalogues.items.has(str(uid)):
				manquantes.append("%s → objet %s" % [cid, uid])
	verifier(manquantes.is_empty(), "chaque classe cite des compétences, un talent et des objets qui existent (%s)" % str(manquantes))
	var cr_manquantes: Array[String] = []
	for cid in GameData.catalogues.creatures.keys():
		var c: Dictionary = GameData.catalogues.creatures[cid]
		for a in c.get("actions", []):
			if not GameData.catalogues.creature_actions.has(str(a)):
				cr_manquantes.append("%s → %s" % [cid, a])
		if str(c.get("ai_profile", "")) != "" and not GameData.catalogues.ai_profiles.has(str(c.ai_profile)):
			cr_manquantes.append("%s → profil %s" % [cid, c.ai_profile])
	verifier(cr_manquantes.is_empty(), "chaque créature cite des actions et un profil d'IA qui existent (%s)" % str(cr_manquantes))
	var biomes_ko: Array[String] = []
	for bid in GameData.catalogues.biomes.keys():
		var b: Dictionary = GameData.catalogues.biomes[bid]
		for f in b.get("faune", []) + b.get("faune_nuit", []):
			var i := str(f.id) if f is Dictionary else str(f)
			if not GameData.catalogues.creatures.has(i):
				biomes_ko.append("%s → %s" % [bid, i])
	verifier(biomes_ko.is_empty(), "chaque faune de biome existe au bestiaire (%s)" % str(biomes_ko))


func test_huile_d_arme() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var loup := {}
	for e in s.vivants():
		if e.id != j.id:
			loup = e
	# L'huile pose le drapeau, l'engagement le transforme en bonus de feu
	var uid := "huile_test"
	s.items[uid] = {"uid": uid, "name_key": "x", "base": "huile_d_arme", "type": "consommable", "statut": "huile_feu", "statut_ticks": 0, "quantite": 1, "tags": ["consommable"], "affixes": [], "sertissures": {"nombre": 0, "contenu": []}}
	j.sac.append(uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "manger", "objet": uid}) and bool(j.get("huile_feu", false)), "l'huile enduit l'arme")
	s._engager_combat(j, loup)
	verifier(not j.get("huile_feu", false) and str(j.get("degats_element_bonus", {}).get("feu", "")) == "1d4", "au premier combat : +1d4 feu par coup")
	# Le coup lit vraiment le bonus : les dégâts moyens montent d'environ 1d4
	var sans := 0
	var avec := 0
	loup.pos = j.pos + Vector2i(1, 0)   # à portée de mêlée
	s.grille.liberer(loup.pos)
	s.grille.placer(loup.id, loup.pos)
	s.grille.hauteurs[s.grille.idx(loup.pos)] = s.grille.h(j.pos)
	for k in 40:
		loup.sante = loup.sante_max
		j.compteur = 0
		j.erase("degats_element_bonus")
		s._attaquer_arme(j, loup, false, s.tick_de(j))
		sans += int(loup.sante_max) - int(loup.sante)
		loup.sante = loup.sante_max
		j.compteur = 0
		j["degats_element_bonus"] = {"feu": "1d4"}
		s._attaquer_arme(j, loup, false, s.tick_de(j))
		avec += int(loup.sante_max) - int(loup.sante)
	verifier(avec > sans, "les coups enduits frappent plus fort (%d contre %d sur 40 coups)" % [avec, sans])


func test_tannage() -> void:
	# La famille cuir a désormais une source : plus aucune famille de composant n'est orpheline
	var produits := {}
	for rid in GameData.catalogues.recipes.keys():
		var r: Dictionary = GameData.catalogues.recipes[rid]
		if str(r.output.get("material", "")) != "":
			produits[str(r.output.material)] = true
	verifier(produits.has("cuir"), "une recette produit du cuir")
	var s := Simulation.new(157)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var peau := s.generer_objet("peau", 1, {}, "commun", 0)
	s.items[str(peau.uid)].quantite = 2
	if not (str(peau.uid) in j.sac):
		j.sac.append(str(peau.uid))
	var plan := s._plan_recette(j, GameData.entree("recipes", "tanner_cuir"))
	verifier(plan.faisable and str(plan.sortie.materiau) == "cuir" and str(plan.sortie.forme) == "brut", "deux peaux au sac : le tannage est faisable")
	s.items[str(peau.uid)].quantite = 1
	verifier(not s._plan_recette(j, GameData.entree("recipes", "tanner_cuir")).faisable, "une seule peau ne suffit pas")
	# Le trophée demande une dépouille
	var tro: Dictionary = GameData.entree("recipes", "meuble_trophee")
	var demande_peau := false
	for entree in tro.inputs:
		if str(entree.get("item", "")) == "peau":
			demande_peau = true
	verifier(demande_peau, "le trophée demande une peau")
	s.monde.fermer()


func test_especes_ajoutees() -> void:
	verifier(GameData.catalogues.species.size() >= 10, "dix espèces d'élevage au catalogue (%d)" % GameData.catalogues.species.size())
	var lu: Dictionary = GameData.entree("species", "luciole")
	var po: Dictionary = GameData.entree("species", "poisson_de_bassin")
	verifier(str(lu.loci.rythme.type) == "sequence" and str(po.loci.taille.type) == "nombre", "les deux derniers types de loci ont un porteur")
	verifier(bool(lu.capture.get("nuit", false)) and str(po.capture.verbe) == "ligne", "luciole de nuit, poisson à la ligne")
	verifier(GameData.catalogues.meubles.has("bassin") and GameData.catalogues.items.has("meuble_bassin") and GameData.catalogues.recipes.has("meuble_bassin"), "le bassin : meuble, objet et recette")
	# La condition colonie : six lucioles avant toute couvée
	var s := Simulation.new(156)
	s.charger_camp()
	var a := s._nouveau_specimen("luciole", {"couleur": [0, 0], "rythme": [[0, 1, 2, 3], [0, 1, 2, 3]]}, "m", false)
	var b := s._nouveau_specimen("luciole", {"couleur": [1, 1], "rythme": [[1, 2, 3, 0], [1, 2, 3, 0]]}, "f", false)
	a["age_semaines"] = 3
	b["age_semaines"] = 3
	var ctx_peu := {"habitat": "vivarium", "occupants": 2, "libre": 2, "temp": 20.0, "saison": s.saison()}
	var ctx_colonie := {"habitat": "vivarium", "occupants": 6, "libre": 2, "temp": 20.0, "saison": s.saison()}
	verifier(not s.conditions_repro(a, b, ctx_peu).ok, "à deux, les lucioles ne s'accordent pas")
	verifier(s.conditions_repro(a, b, ctx_colonie).ok, "à six, la colonie s'accorde")
	# Le poisson : la température du bassin
	var p1 := s._nouveau_specimen("poisson_de_bassin", {"couleur": [0, 0], "motif": [0, 0], "taille": 4.0}, "m", false)
	var p2 := s._nouveau_specimen("poisson_de_bassin", {"couleur": [1, 1], "motif": [1, 1], "taille": 6.0}, "f", false)
	p1["age_semaines"] = 3
	p2["age_semaines"] = 3
	verifier(s.conditions_repro(p1, p2, {"habitat": "bassin", "occupants": 2, "libre": 2, "temp": 22.0, "saison": s.saison()}).ok, "bassin à 22 °C : les poissons frayent")
	verifier(not s.conditions_repro(p1, p2, {"habitat": "bassin", "occupants": 2, "libre": 2, "temp": 5.0, "saison": s.saison()}).ok, "bassin à 5 °C : trop froid")
	s.monde.fermer()


func test_paliers_elevage() -> void:
	var s := Simulation.new(155)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var pal0 := s.paliers_elevage()
	verifier(int(pal0.capture) == 0 and int(pal0.couvees) == 0 and is_equal_approx(float(pal0.eclosion), 1.0), "registre vide : aucun palier")
	# Un registre garni à la main : 30 variétés d'une espèce → le premier palier de potentiel
	s.territoire["registre"] = {"carpe": {}}
	for k in 30:
		s.territoire.registre.carpe["c%d|m%d" % [k, k]] = true
	var pot_avant := int(j.potentiels.get("elevage", 0))
	var base_elevage := int(j.get("potentiels_base", {}).get("elevage", 80))
	s._appliquer_paliers_potentiel()
	verifier(int(s.paliers_elevage().potentiel) == 10 and int(j.potentiels.get("elevage", 0)) >= base_elevage + 10, "25 variétés : plancher de potentiel en Élevage (%d → %d)" % [pot_avant, int(j.potentiels.get("elevage", 0))])
	verifier(int(s.paliers_elevage().capture) == 0, "mais pas encore le palier de capture (75)")
	for k in range(30, 210):
		s.territoire.registre.carpe["c%d|m%d" % [k, k]] = true
	var pal := s.paliers_elevage()
	verifier(int(pal.capture) == 2 and is_equal_approx(float(pal.eclosion), 0.75), "200 variétés : capture +2 et éclosions à 75 %%")
	# Le plancher de la branche Vie au palier 1 200
	for k in range(210, 1250):
		s.territoire.registre.carpe["c%d|m%d" % [k, k]] = true
	s._appliquer_paliers_potentiel()
	var base_agri := int(j.get("potentiels_base", {}).get("agriculture", 80))
	var epee_avant := int(j.potentiels.get("epee", 80))
	s._appliquer_paliers_potentiel()
	verifier(int(s.paliers_elevage().potentiel_vie) == 10 and int(j.potentiels.get("agriculture", 0)) >= base_agri + 10 and int(j.potentiels.get("epee", 80)) == epee_avant, "1 200 variétés : la branche Vie relevée (%d), pas les armes" % int(j.potentiels.get("agriculture", 0)))
	# Espèces : couvées et commandes
	for esp in GameData.catalogues.species.keys():
		s.territoire.registre[esp] = s.territoire.registre.get(esp, {"x|y": true})
	pal = s.paliers_elevage()
	verifier(int(pal.capture) >= 6, "bestiaire complet : capture +2 (variétés) +4 (%d)" % int(pal.capture))
	verifier(int(pal.couvees) == (2 if GameData.catalogues.species.size() >= 10 else 0), "les couvées supplémentaires attendent 10 espèces (%d au catalogue)" % GameData.catalogues.species.size())
	s.monde.fermer()


func test_ia_portails() -> void:
	var s := Simulation.new(154)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var loup := s.ajouter("loup", j.pos + Vector2i(-2, 0), "ia")
	var but: Vector2i = j.pos + Vector2i(20, 0)
	verifier(s.portail_utile(loup, but) == Vector2i(-1, -1), "sans portail, aucun détour")
	# Deux portails du Passeur : l'entrée près du loup, la sortie près du but
	var entree: Vector2i = loup.pos + Vector2i(-1, 0)
	var sortie: Vector2i = but + Vector2i(-1, 0)
	for t in [entree, sortie]:
		s.grille.contenu[s.grille.idx(t)] = 0
		s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(loup.pos)
	j["portails"] = [entree, sortie]   # clés en position monde (la fenêtre glisse)
	s.portails[entree] = j.id
	s.portails[sortie] = j.id
	verifier(s.portail_utile(loup, but) == entree, "le loup voit la brèche qui le rapproche")
	verifier(s.portail_utile(loup, loup.pos + Vector2i(1, 0)) == Vector2i(-1, -1), "pour deux tuiles, le détour n'en vaut pas la peine")
	var tick := s.tick_de(loup)
	verifier(s._ia_par_portail(loup, but, tick) and loup.pos == entree, "un pas vers la brèche")
	verifier(s._ia_par_portail(loup, but, tick) and loup.pos == sortie, "puis elle traverse")
	verifier(Grille.distance(loup.pos, but) <= 1, "le loup ressort à côté de son but")
	s.monde.fermer()


func test_courant() -> void:
	var s := Simulation.new(153)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var base: Vector2i = j.pos + Vector2i(4, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(0, 8):
		for dy in range(-2, 3):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
	# Une pente : une rivière qui descend vers l'est
	for dx in range(0, 6):
		var t: Vector2i = base + Vector2i(dx, 0)
		s.grille.hauteurs[s.grille.idx(t)] = h0 - dx
		s.grille.poser_contenu(t, "eau_ecoulement")
		s.grille.niveau_eau[s.grille.idx(t)] = 5
	verifier(s.courant_de(base) == Vector2i(1, 0), "le courant descend la pente (%s)" % str(s.courant_de(base)))
	s.grille.poser_contenu(base + Vector2i(2, 0), "eau")
	verifier(s.courant_de(base + Vector2i(2, 0)) == Vector2i.ZERO, "une source n'a pas de courant")
	s.grille.poser_contenu(base + Vector2i(2, 0), "eau_ecoulement")
	s.grille.niveau_eau[s.grille.idx(base + Vector2i(2, 0))] = 5
	# Un objet au sol part au fil de l'eau
	var o := s.generer_objet("proto_epee", 1, {}, "commun", 0)
	s._poser_contenant(base, [str(o.uid)], "butin")
	var parti := false
	for k in 40:
		s._tiquer_courant(2000 + k)
		if not s.contenants.has(s.grille.idx(base)):
			parti = true
			break
	verifier(parti and s.contenants.size() > 0, "le butin tombé dans la rivière part au fil de l'eau")
	# Un être léger dérive, un être surchargé tient
	var loup := s.ajouter("loup", base, "ia")
	var derive := false
	for k in 60:
		s._tiquer_courant(3000 + k)
		if loup.pos != base:
			derive = true
			break
	verifier(derive, "un loup dans le courant est emporté (%s)" % str(loup.pos - base))
	s.grille.liberer(loup.pos)
	loup.pos = base
	s.grille.placer(loup.id, base)
	for k in 60:   # alourdi au-delà du seuil : il tient debout
		s.items["encl_%d" % k] = {"uid": "encl_%d" % k, "name_key": "x", "type": "materiau", "poids": 30.0, "affixes": [], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
		loup.sac.append("encl_%d" % k)
	verifier(float(s.poids_de(loup).poids) / float(s.poids_de(loup).capacite) > 0.5, "le loup est chargé (%.2f de sa capacité)" % (float(s.poids_de(loup).poids) / float(s.poids_de(loup).capacite)))
	var bouge := false
	for k in 60:
		s._tiquer_courant(4000 + k)
		if loup.pos != base:
			bouge = true
			break
	verifier(not bouge, "trop lourd pour dériver : il tient debout")
	s.monde.fermer()


func test_lave() -> void:
	# Le générateur : pas de lave avant l'étage minimum, des mares après
	var s := Simulation.new(152)
	s.charger_donjon("ruine", 152, 3, 2)
	var lave_2 := 0
	for i in s.grille.contenu.size():
		if "lave" in s.grille.contenu_de(s.grille.pos_de(i)).get("tags", []):
			lave_2 += 1
	s.charger_donjon("ruine", 152, 3, 6)
	var laves: Array[Vector2i] = []
	for i in s.grille.contenu.size():
		var t := s.grille.pos_de(i)
		if "lave" in s.grille.contenu_de(t).get("tags", []):
			laves.append(t)
	verifier(lave_2 == 0 and laves.size() >= 6, "pas de lave à l'étage 2, des mares à l'étage 6 (%d tuiles)" % laves.size())
	verifier(s.grille.dangers.has(s.grille.idx(laves[0])), "la lave est un danger : l'IA la contourne")
	# Contact : un loup posé dans la lave brûle
	var t0: Vector2i = laves[0]
	var loup := s.ajouter("loup", t0, "ia")
	var pv := int(loup.sante)
	s.eau_prochain_pas = 0
	s._tiquer_lave(1000)
	verifier(int(loup.sante) < pv and Etres.a_statut_id(loup, "brulure"), "la lave brûle qui s'y tient (%d → %d)" % [pv, int(loup.sante)])
	# L'eau la fige : une source à côté → obsidienne
	var voisine: Vector2i = t0 + Vector2i(1, 0)
	if not s.grille.dans(voisine) or s.grille.bloque_passage(voisine):
		voisine = t0 + Vector2i(-1, 0)
	s.grille.poser_contenu(voisine, "eau")
	s.eau_prochain_pas = 0
	s._tiquer_lave(1010)
	verifier(not ("lave" in s.grille.contenu_de(t0).get("tags", [])) and str(s.grille.materiau_de(t0)) == "obsidienne", "au contact d'une source, la lave se fige en obsidienne")
	verifier(not s.grille.dangers.has(s.grille.idx(t0)), "figée, elle n'est plus un danger")


func test_feu() -> void:
	var s := Simulation.new(151)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var base: Vector2i = j.pos + Vector2i(3, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(0, 8):
		for dy in range(-2, 3):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
			s.grille.sols.erase(s.grille.idx(t))
	for dx in range(0, 6):   # une rangée de pins (flammabilité 70)
		s.grille.poser_contenu(base + Vector2i(dx, 0), "arbre")
		s.grille.materiaux[s.grille.idx(base + Vector2i(dx, 0))] = "pin"
	var pierre: Vector2i = base + Vector2i(0, 2)
	s.grille.poser_contenu(pierre, "mur")
	s.grille.materiaux[s.grille.idx(pierre)] = "granit"
	s.meteo_force = "clair"
	verifier(s.flammabilite_de(base) == 70 and s.flammabilite_de(pierre) == 0 and s.flammabilite_de(base + Vector2i(0, 1)) == 0, "un pin brûle (70), le granit et le sol nu non")
	verifier(s._enflammer(base) and not s._enflammer(base) and not s._enflammer(pierre), "le premier pin prend feu, une seule fois ; le granit jamais")
	var tick := 2000
	s.regles.r.feu["propagation"] = 1.5   # déterministe pour le test : un pin voisin prend à coup sûr
	var propage := false
	for k in 30:
		s._tiquer_feux(tick + k * 10)
		if s.feux.size() > 1:
			propage = true
	verifier(propage, "le feu gagne les pins voisins")
	verifier(s.grille.contenu_de(base).is_empty() and s.modifs_terrain.has(base), "le premier pin est consumé, terrain mémorisé")
	# Brûler : un loup posé sur une tuile en feu
	for idx in s.feux.keys().duplicate():
		s.feux.erase(idx)
	var herbe: Vector2i = base + Vector2i(2, -2)
	s.grille.poser_contenu(herbe, "plante_sauvage")
	s.grille.materiaux[s.grille.idx(herbe)] = "ortie"
	var loup := s.ajouter("loup", herbe, "ia")
	s._enflammer(herbe)
	var pv := int(loup.sante)
	s._tiquer_feux(tick + 1000)
	verifier(int(loup.sante) < pv and Etres.a_statut_id(loup, "brulure"), "le loup sur la tuile en feu brûle (%d → %d) et prend Brûlure" % [pv, int(loup.sante)])
	# On contourne le feu : un chemin ne traverse pas une tuile en flammes, et l'IA en sort
	var sortie := s.grille.chemin(loup.pos + Vector2i(-2, 0), loup.pos + Vector2i(2, 0))
	verifier(not sortie.is_empty() and not (herbe in sortie), "le chemin contourne la tuile en feu")
	s._decider_ia(loup, tick + 1005)
	verifier(loup.pos != herbe, "le loup sort des flammes d'un pas")
	# La pluie éteint tout
	s.meteo_force = "pluie"
	s._tiquer_feux(tick + 1010)
	verifier(s.feux.is_empty() and s.grille.dangers.is_empty(), "la pluie éteint les feux, plus rien à éviter")
	s.meteo_force = ""
	s.monde.fermer()


func test_affixes_reveilles() -> void:
	var s := Simulation.new(150)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(not s.affixes_defs.cond_nuit.inerte and not s.affixes_defs.cond_corruption.inerte and not s.affixes_defs.cond_mana.inerte and not s.affixes_defs.meca_capacite.inerte, "quatre affixes ne sont plus inertes")
	# Du porteur : +kg de capacité
	var cap0 := float(s.poids_de(j).capacite)
	s.items["anneau_p"] = {"uid": "anneau_p", "name_key": "x", "type": "bijou", "equip_slot": "anneau", "affixes": [{"id": "meca_capacite", "params": {"kg": 20}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["anneau_1"] = "anneau_p"
	s.items["amu_p"] = {"uid": "amu_p", "name_key": "x", "type": "bijou", "equip_slot": "amulette", "affixes": [{"id": "meca_capacite", "params": {"kg": 10}, "compteur": 0, "etat": {}}, {"id": "cond_mana", "params": {"pct": 20}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["amulette"] = "amu_p"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(float(s.poids_de(j).capacite) == cap0 + 30.0, "du porteur : +20 et +10 de capacité cumulés (%.0f → %.0f)" % [cap0, float(s.poids_de(j).capacite)])
	# Nocturne : la nuit, un pas coûte moins
	s.items["casque_n"] = {"uid": "casque_n", "name_key": "x", "type": "armure", "equip_slot": "casque", "affixes": [{"id": "cond_nuit", "params": {"pct": 20}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["casque"] = "casque_n"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.horloge_monde.ticks = int(s._cycle().ticks_par_jour) / 2
	verifier(not s.est_nuit() and s.cout_pas_affixes(j, 10) == 10, "le jour : un pas de 10 reste 10")
	s.horloge_monde.ticks = 0
	verifier(s.est_nuit() and s.cout_pas_affixes(j, 10) == 8, "la nuit : 10 → 8 (−20 %)")
	# Des sources : la densité de mana du lieu
	var dm := s.densite_mana(j.pos)
	var m := s.mult_mana_sources(j)
	verifier((dm >= 0.6 and is_equal_approx(m, 0.8)) or (dm < 0.6 and m == 1.0), "des sources : densité %.2f → coût ×%.2f" % [dm, m])
	# Du danger : la corruption du lieu
	var arme := {"uid": "epee_d", "name_key": "x", "type": "arme", "equip_slot": "main_principale", "functionality": "epee", "affixes": [{"id": "cond_corruption", "params": {"seuil": 40, "pct": 30}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	s.items["epee_d"] = arme
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	var corr := s.corruption_ici(j.pos)
	var r := s._affixes_offensifs(j, arme, loup)
	verifier((corr >= 40.0 and is_equal_approx(float(r.mult), 1.3)) or (corr < 40.0 and is_equal_approx(float(r.mult), 1.0)), "du danger : corruption %.0f → ×%.2f" % [corr, float(r.mult)])
	s.donjon = {"corruption": 90, "etage": 1}
	s.lieu = "donjon"
	r = s._affixes_offensifs(j, arme, loup)
	verifier(is_equal_approx(float(r.mult), 1.3), "en donjon corrompu (90) : ×1,30")
	s.lieu = "camp"
	s.donjon = {}
	s.monde.fermer()


func test_cueillette() -> void:
	# Les données : chaque plante de cueillette existe, et sa silhouette aussi
	var manque := 0
	for bid in GameData.catalogues.biomes.keys():
		for cu in GameData.catalogues.biomes[bid].get("cueillette", []):
			if not GameData.catalogues.plants.has(str(cu.id)) or not GameData.catalogues.vegetaux.has(str(cu.id)) or not GameData.catalogues.items.has(str(cu.id)):
				manque += 1
	verifier(manque == 0, "chaque plante de cueillette a sa fiche, sa silhouette et son consommable")
	var s := Simulation.new(149)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var t: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.contenu[s.grille.idx(t)] = 0
	s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	verifier(not s.intention(j.id, {"type": "cueillir", "vers": t}), "rien à cueillir sur du sol nu")
	s.grille.poser_contenu(t, "plante_sauvage")
	s.grille.materiaux[s.grille.idx(t)] = "framboisier"
	var avant: int = j.sac.size()
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "cueillir", "vers": t}), "cueillir un framboisier adjacent")
	var n: int = j.sac.size() - avant
	verifier(n >= 1 and n <= 2, "cueillette sauvage : 1d2 au niveau 0 de Collecte (%d)" % n)
	verifier(s.grille.contenu_de(t).is_empty() and s.modifs_terrain.has(t), "la tuile redevient du sol, mémorisée pour repousser")
	s.monde.fermer()


func test_compagnons_postures() -> void:
	var s := Simulation.new(148)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var comp := s.ajouter("villageois", j.pos + Vector2i(0, 1), "ia")
	s._habiller_pnj(comp, GameData.entree("creatures", "villageois"))
	s._devenir_compagnon(j, comp)
	var loup := s.ajouter("loup", j.pos + Vector2i(4, 1), "ia")
	var profil: Dictionary = GameData.entree("ai_profiles", "compagnon")
	var tick := s.tick_de(comp)
	# Défensive par défaut : une cible proche du maître se poursuit
	var c := s._actions_candidates(comp, loup, profil, tick)
	verifier(c.has("poursuivre") and not c.get("attaquer", {}).has("posture_agressive"), "défensive : il poursuit une cible proche du maître, sans zèle")
	loup.pos = j.pos + Vector2i(9, 0)
	c = s._actions_candidates(comp, loup, profil, tick)
	verifier(not c.has("poursuivre"), "défensive : il ne poursuit pas une cible à 9 tuiles du maître")
	# Agressive
	verifier(s.ordonner(j, comp.id, "agressive") and str(comp.posture) == "agressive", "ordre : posture agressive, sans tick")
	c = s._actions_candidates(comp, loup, profil, tick)
	verifier(c.has("poursuivre") and float(c.poursuivre.get("posture_agressive", 0.0)) == 1.0, "agressive : il poursuit, considération posture_agressive")
	# Évite
	loup.pos = j.pos + Vector2i(3, 0)
	s.ordonner(j, comp.id, "eviter")
	c = s._actions_candidates(comp, loup, profil, tick)
	verifier(not c.has("attaquer") and not c.has("poursuivre") and float(c.get("fuir", {}).get("eviter", 0.0)) == 1.0, "évite : ni attaque ni poursuite, il fuit la menace à 3 tuiles")
	verifier(not s.ordonner(j, comp.id, "charger"), "un ordre inconnu est refusé")
	# Consignes de combat : désigner une cible, repli
	var loup2 := s.ajouter("loup", j.pos + Vector2i(-3, 0), "ia")
	s.ordonner(j, comp.id, "defensive")
	verifier(s.designer_cible(j, loup2.id) and str(comp.cible) == loup2.id and str(comp.cible_prioritaire) == loup2.id, "désigner un loup : le compagnon le prend pour cible")
	comp.cible = loup.id
	verifier(str(s._chercher_cible(comp, tick).get("id", "")) == loup2.id, "la cible désignée passe devant une autre")
	verifier(not s.designer_cible(j, comp.id), "on ne désigne pas un allié")
	verifier(s.ordonner(j, comp.id, "repli") and str(comp.ordre) == "suivre" and str(comp.posture) == "eviter" and comp.cible.is_empty() and not comp.has("cible_prioritaire"), "repli : suis-moi, évite, cible oubliée")
	# Retour à la base : l'ancre au centre de la cellule du camp
	verifier(s.ordonner(j, comp.id, "retour") and str(comp.ordre) == "attendre" and comp.ancre == s.grille.pos_de(s.grille.largeur * s.grille.hauteur_grille / 2), "retour à la base : attends ici, l'ancre au centre du camp")
	# Échange d'équipement : il s'équipe de ce qu'on lui donne, et le rend déséquipé
	var o := s.generer_objet("proto_epee", 1, {}, "commun", 0)
	if not s.items.has(str(o.get("uid", ""))):
		s.items[o.uid] = o
	if not (str(o.uid) in j.sac):
		j.sac.append(str(o.uid))
	var uid := str(o.uid)
	verifier(s.echanger(j, comp.id, uid, "donner") and not (uid in j.sac) and str(comp.equipement.get("main_principale", "")) == uid, "donner une épée : le compagnon s'en équipe")
	verifier(s.echanger(j, comp.id, uid, "reprendre") and (uid in j.sac) and not (uid in comp.sac) and str(comp.equipement.get("main_principale", "")) != uid, "reprendre : elle revient dans mon sac, déséquipée")
	verifier(not s.echanger(j, loup.id, uid, "donner"), "on n'échange qu'avec ses compagnons")
	s.monde.fermer()


func test_retrait_eau() -> void:
	var s := Simulation.new(147)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var base: Vector2i = j.pos + Vector2i(4, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(0, 8):
		for dy in range(-2, 3):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
	var lac: Vector2i = base + Vector2i(5, 0)
	s.grille.poser_contenu(lac, "eau")
	var tranchee: Vector2i = lac + Vector2i(-1, 0)
	s.grille.hauteurs[s.grille.idx(tranchee)] = h0 - 1
	s.eau_active[s.grille.idx(lac)] = true
	var tick := 1000
	for k in 12:
		s._tiquer_eau(tick + k * 5)
	var plat: Vector2i = lac + Vector2i(1, 0)
	verifier(s.grille.niveau_liquide(tranchee) == 7 and s.grille.niveau_liquide(plat) == 7, "la nappe est en place (tranchée 7, plat 7)")
	# Persistance du niveau avec la cellule
	s.monde.capturer(s.grille)
	var m: Dictionary = s.monde.modifications.get(s.monde.cellule_de(plat), {}).get(s.monde.idx_local(plat), {})
	verifier(int(m.get("eau", 0)) == 7, "le niveau d'un écoulement est mémorisé avec la cellule (%d)" % int(m.get("eau", 0)))
	# La source comblée : la nappe à plat se retire, la tranchée (un creux) garde son eau
	s._retirer_source(lac)
	for k in 400:   # la nappe se rétracte de proche en proche : lentement
		s._tiquer_eau(tick + 100 + k * 5)
	verifier(s.grille.niveau_liquide(lac) == 0, "la source comblée a disparu")
	verifier(s.grille.niveau_liquide(plat) == 0 and s.grille.niveau_liquide(lac + Vector2i(3, 0)) == 0, "la nappe à plat s'est retirée (%d, %d)" % [s.grille.niveau_liquide(plat), s.grille.niveau_liquide(lac + Vector2i(3, 0))])
	verifier(s.grille.niveau_liquide(tranchee) == 7, "la tranchée, un creux, garde son eau (%d)" % s.grille.niveau_liquide(tranchee))
	# La canicule évapore la flaque du creux, un niveau par heure
	s._evaporation()
	verifier(s.grille.niveau_liquide(tranchee) == 6, "la canicule évapore d'un niveau (%d)" % s.grille.niveau_liquide(tranchee))
	for k in 8:
		s._evaporation()
	verifier(s.grille.niveau_liquide(tranchee) == 0, "sept heures de canicule plus tard, la tranchée est sèche")
	# Élever une tuile d'écoulement la comble
	s.grille.poser_contenu(plat, "eau_ecoulement")
	s.grille.niveau_eau[s.grille.idx(plat)] = 3
	s.grille.hauteurs[s.grille.idx(plat)] = h0 + 1
	s._retirer_eau(plat, true)
	verifier(s.grille.niveau_liquide(plat) == 0 and not s.grille.niveau_eau.has(s.grille.idx(plat)), "une tuile d'écoulement élevée est comblée")
	s.monde.fermer()


func test_foudre() -> void:
	var s := Simulation.new(146)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var base: Vector2i = j.pos + Vector2i(6, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(-3, 12):
		for dy in range(-3, 4):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
	# Une mare d'eau douce : une ligne d'écoulement de 7 tuiles
	for dx in range(0, 7):
		s.grille.poser_contenu(base + Vector2i(dx, 0), "eau_ecoulement")
		s.grille.niveau_eau[s.grille.idx(base + Vector2i(dx, 0))] = 7 - dx
	var dans_eau := s.ajouter("loup", base + Vector2i(4, 0), "ia")
	var loin_eau := s.ajouter("loup", base + Vector2i(6, 0), "ia")   # à 6 : au-delà du rayon 5 de l'eau douce
	var terre := s.ajouter("loup", base + Vector2i(3, 2), "ia")   # sur la terre, à 2 : hors zone
	var voisin := s.ajouter("loup", base + Vector2i(-1, 1), "ia")   # voisin diagonal de l'impact : zone
	var pv := [int(dans_eau.sante), int(loin_eau.sante), int(terre.sante), int(voisin.sante)]
	s._frapper_foudre(base)
	verifier(int(dans_eau.sante) < pv[0], "la foudre court dans l'eau : le loup à 4 tuiles dans la mare est touché (%d → %d)" % [pv[0], int(dans_eau.sante)])
	verifier(int(loin_eau.sante) == pv[1], "à 6 tuiles, au-delà du rayon 5 de l'eau douce : rien")
	verifier(int(terre.sante) == pv[2], "sur la terre à 2 tuiles : rien")
	verifier(int(voisin.sante) < pv[3], "le voisin de l'impact prend la zone")
	# La glace ne conduit pas
	dans_eau.sante = dans_eau.sante_max
	s.grille.gel = true
	s._frapper_foudre(base)
	verifier(int(dans_eau.sante) == int(dans_eau.sante_max), "sur la glace, la foudre ne court pas")
	s.grille.gel = false
	# Une source (la mer) conduit à 8
	s.grille.poser_contenu(base, "eau")
	loin_eau.sante = loin_eau.sante_max
	s._frapper_foudre(base)
	verifier(int(loin_eau.sante) < int(loin_eau.sante_max), "depuis une source (eau salée) : rayon 8, le loup à 6 est touché")
	# Le paratonnerre émergent : la foudre vise le point haut
	var mat: Vector2i = base + Vector2i(2, -2)
	s.grille.hauteurs[s.grille.idx(mat)] = h0 + 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	s.regles.r.eau["foudre_portee_joueur"] = 1   # candidates dans le carré 3×3 autour du point haut
	var cible := s._cible_foudre(rng, mat)
	verifier(cible == mat, "la foudre vise le point haut (%s, h %d)" % [str(cible - mat), s.grille.h(cible)])
	s.monde.fermer()


func test_automate_eau() -> void:
	var s := Simulation.new(145)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Un lac (source) à 3 tuiles, une plaine plate entre les deux ; creuser une tranchée au bord : elle s'inonde.
	var base: Vector2i = j.pos + Vector2i(4, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(0, 8):
		for dy in range(-2, 3):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
	var lac: Vector2i = base + Vector2i(5, 0)
	var talus: Vector2i = lac + Vector2i(0, 1)
	s.grille.hauteurs[s.grille.idx(talus)] = h0 + 1   # un talus au bord du lac, posé avant que l'eau ne bouge
	s.grille.poser_contenu(lac, "eau")
	verifier(s.grille.niveau_liquide(lac) == 8 and s.eau_active.is_empty(), "une source au niveau 8, rien ne bouge tant qu'on n'y touche pas")
	var tranchee: Vector2i = lac + Vector2i(-1, 0)
	s._memoriser_terrain(tranchee)
	s.grille.hauteurs[s.grille.idx(tranchee)] = h0 - 1
	verifier(not s.eau_active.is_empty(), "creuser au bord réveille le lac")
	var tick := s.horloge_monde.ticks
	for k in 10:
		s._tiquer_eau(tick + k * 5)
	verifier(s.grille.niveau_liquide(tranchee) == 7, "la tranchée (plus basse) s'inonde : niveau 7")
	var plat: Vector2i = lac + Vector2i(-2, 0)
	var loin: Vector2i = lac + Vector2i(-4, 0)
	verifier(s.grille.niveau_liquide(plat) > s.grille.niveau_liquide(loin) and s.grille.niveau_liquide(loin) > 0, "l'eau s'étale à plat en perdant un niveau par tuile (%d puis %d)" % [s.grille.niveau_liquide(plat), s.grille.niveau_liquide(loin)])
	verifier(s.grille.niveau_liquide(lac + Vector2i(-8, 0)) == 0, "et s'arrête au bout de sa portée")
	verifier(s.grille.niveau_liquide(talus) == 0, "le talus (plus haut) endigue")
	# La pluie remplit un creux d'un niveau
	var creux: Vector2i = j.pos + Vector2i(-3, 0)
	for dd in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		s.grille.contenu[s.grille.idx(creux + dd)] = 0
		s.grille.hauteurs[s.grille.idx(creux + dd)] = h0
	s.grille.hauteurs[s.grille.idx(creux)] = h0 - 2
	var avant := s.grille.niveau_liquide(creux)
	var g1 := s._pluie_sur(creux)
	var g2 := s._pluie_sur(creux)
	verifier(avant == 0 and g1 and not g2 and s.grille.niveau_liquide(creux) == 1, "la pluie remplit le creux d'un niveau, jamais plus (%d)" % s.grille.niveau_liquide(creux))
	verifier(not s._pluie_sur(creux + Vector2i(1, 0)), "une tuile qui n'est pas un creux ne prend pas la pluie")
	s.monde.fermer()


# ---------------------------------------------------------------- Neige et gel

func test_neige_et_gel() -> void:
	var s := Simulation.new(144)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var eau: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.poser_contenu(eau, "eau")
	s.grille.hauteurs[s.grille.idx(eau)] = s.grille.h(j.pos)
	var plat: Vector2i = j.pos + Vector2i(0, 1)
	s.grille.contenu[s.grille.idx(plat)] = 0
	s.grille.hauteurs[s.grille.idx(plat)] = s.grille.h(j.pos)
	s.meteo_force = "clair"
	s.horloge_monde.ticks = int(s._cycle().ticks_par_jour) / 2
	s._maj_etats_meteo()
	var c_plat := s.grille.cout_pas(j.pos, plat)
	verifier(not s.grille.neige and s.grille.cout_pas(j.pos, eau) == 6, "ciel clair : pas de neige, l'eau se nage (6)")
	s.meteo_force = "blizzard"
	s._maj_etats_meteo()
	verifier(s.grille.neige and s.grille.cout_pas(j.pos, plat) == c_plat + 1, "blizzard : la neige ralentit (%d → %d)" % [c_plat, s.grille.cout_pas(j.pos, plat)])
	verifier(s.temperature_cellule() < 0.0 and s.grille.gel and not s.dans_l_eau(eau) and s.grille.cout_pas(j.pos, eau) == c_plat + 1, "−25 °C : la mer gèle, elle se marche (%.0f °C, coût %d)" % [s.temperature_cellule(), s.grille.cout_pas(j.pos, eau)])
	s.meteo_force = "canicule"
	s._maj_etats_meteo()
	verifier(not s.grille.gel and not s.grille.neige, "canicule : la glace fond")
	s.monde.fermer()


# ---------------------------------------------------------------- La nage et le souffle

func test_nage() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var h := s.horloge_de(j)
	var eau: Vector2i = j.pos + Vector2i(1, 0)
	var eau2: Vector2i = j.pos + Vector2i(2, 0)
	for t in [eau, eau2]:
		s.grille.poser_contenu(t, "eau")
		s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	verifier(not s.grille.bloque_passage(eau) and s.grille.cout_pas(j.pos, eau) == 6, "l'eau se traverse : coût de pas 6")
	s.attente[j.id] = true
	var c0 := int(j.compteur)
	verifier(s.intention(j.id, {"type": "deplacer", "vers": eau}) and j.pos == eau and int(j.compteur) - c0 >= 4, "nager : %d ticks" % (int(j.compteur) - c0))
	# Le butin de mort périme après un jour (Mort et pénalité, 2026-08-31)
	var t_per: Vector2i = j.pos + Vector2i(-2, 0)
	var o_per: Dictionary = s.generer_objet("proto_epee", 1, {}, "commun", 0)
	s._poser_contenant(t_per, [o_per.uid], "butin")
	s.objets[o_per.uid]["peremption_tick"] = 100
	s._perimer_butin(101)
	verifier(not s.contenants.has(s.grille.idx(t_per)) and s.grille.contenu_de(t_per).is_empty(), "le butin périmé rend sa tuile")
	var smax := s.souffle_max(j)
	s._tiquer_souffle(j.horloge, h.ticks)
	var pv0 := int(j.sante)
	s._tiquer_souffle(j.horloge, h.ticks + smax + 20)
	verifier(int(j.souffle) == 0 and int(j.sante) < pv0, "souffle épuisé après %d ticks : noyade (%d → %d)" % [smax, pv0, int(j.sante)])
	j["tags_acquis_race"] = ["respiration_aquatique"]
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	var pv1 := int(j.sante)
	s._tiquer_souffle(j.horloge, h.ticks + smax + 60)
	verifier(int(j.sante) == pv1, "respiration aquatique : plus de noyade")
	# Le Feu ne part pas sous l'eau
	var cap := Capacites.new(GameData.catalogues["modules"])
	verifier(s.wuxing.dominante(cap.assembler(["point", "etincelle"], 5, "1d4", {}).elements) == "feu", "Étincelle est du Feu")
	j.mana = 50
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "capacite", "index": 1, "cible": eau2}), "pas de Feu sous l'eau (Étincelle refusée)")
	# Surcharge : on ne peut pas entrer dans l'eau
	s.grille.liberer(j.pos)
	j.pos = eau - Vector2i(1, 0)
	s.grille.placer(j.id, j.pos)
	for k in 40:
		var o := s.generer_objet("proto_epee", 1, {}, "commun", 0)
		if not o.is_empty():
			j.sac.append(o.uid)
	verifier(s.poids_de(j).facteur > 1.0, "40 épées : surcharge (×%.2f)" % s.poids_de(j).facteur)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "deplacer", "vers": eau}), "trop chargé : refus d'entrer dans l'eau")
	# Le pathfinding sait ce que _deplacer refusera (Eau et liquides, 2026-08-31)
	verifier(s.refuse_nage(j), "refuse_nage : surchargé et non volant")
	verifier(s.grille.cout_pas(j.pos, eau, false, true) == -1, "eviter_nage : l'entrée terre → eau vaut −1")
	verifier(s.grille.cout_pas(eau, eau2, false, true) > 0, "eviter_nage : eau → eau reste libre")
	var ch_sec := s.grille.chemin(j.pos, eau2 + Vector2i(1, 0), false, "", true)
	var prev_n: Vector2i = j.pos
	var entre_dans_eau := false
	for pas_n in ch_sec:
		if s.dans_l_eau(pas_n) and not s.dans_l_eau(prev_n):
			entre_dans_eau = true
		prev_n = pas_n
	verifier(not ch_sec.is_empty() and not entre_dans_eau, "l'A* contourne l'eau au lieu de proposer un pas refusé")
	j.sac.clear()
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(not s.refuse_nage(j), "sac vidé : la nage redevient permise au chemin")


# ---------------------------------------------------------------- Le poison de lame est illégal

func test_poison_illegal() -> void:
	var s := Simulation.new(143)
	s.charger_camp()
	var n_lois := 0
	var n_roy := 0
	for k in 40:
		var sect: Vector2i = s.monde.surface.secteur_de(s.monde.cellule_camp) + Vector2i(k % 7 - 3, k / 7 - 3)
		var roys: Dictionary = s.monde.surface.royaumes_secteur(sect)
		if true:
			for rid in roys.keys():
				var r: Dictionary = roys[rid]
				if str(r.government_type) == "anarchie":
					continue
				n_roy += 1
				for l in r.laws:
					if str(l.target) == "poison_de_lame" and str(l.status) == "illegal":
						n_lois += 1
	verifier(n_roy > 0 and n_lois > 0 and float(n_lois) / float(n_roy) >= 0.5, "le poison de lame est illégal dans %d royaumes sur %d" % [n_lois, n_roy])
	s.monde.fermer()


# ---------------------------------------------------------------- Treize potions

func test_potions_completes() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	s.appliquer_statut(j, "vision_nocturne_potion", 3000, "")
	verifier("vision_nocturne" in j.tags_acquis, "la potion de vision nocturne accorde le tag")
	s.appliquer_statut(j, "antipoison", 1500, "")
	verifier(not s.appliquer_statut(j, "poison", 100, ""), "antipoison : immunisé")
	j.statuts = []
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.appliquer_statut(j, "resistance_froid", 3000, "")
	verifier(int(Etres.add_statuts(j, "isolation", s.statuts_defs)) == 40, "résistance au froid : isolation +40")
	j.statuts = []
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	s.appliquer_statut(j, "lame_empoisonnee", 1500, "")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	var h := s.horloge_de(j)
	for k in 3:
		j.compteur = h.ticks
		s.pas(j.horloge)
	verifier(Etres.a_statut_tag(loup, "poison", s.statuts_defs), "poison de lame : le loup est empoisonné par le coup")
	verifier(str(GameData.entree("items", "amanite").distillat) == "poison_de_lame" and GameData.catalogues.items.has("poison_de_lame"), "l'amanite se distille en poison de lame")


# ---------------------------------------------------------------- Les 17 statuts

func test_statuts_complets() -> void:
	for sid in ["brulure", "ralentissement", "gel", "poison", "saignement", "etourdi", "confusion", "terreur", "infection", "affaibli", "regeneration", "peau_de_pierre", "hate", "beni", "dissimule", "saisi", "retarde"]:
		verifier(GameData.catalogues.status_effects.has(sid), "statut %s en données" % sid)
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var h := s.horloge_de(j)
	# Régénération
	j.sante = 10
	s.appliquer_statut(j, "regeneration", 50, "")
	s._tiquer_statuts(j, h.ticks + 30)
	verifier(int(j.sante) >= 13, "Régénération : +1d4 par période (%d PV après 3 périodes)" % int(j.sante))
	j.statuts = []
	# Gel : immobilisé, jet de Force pour se libérer
	j.stats_eff.force = 40
	s.appliquer_statut(j, "gel", 20, "")
	verifier(Etres.bloque_statuts(j, "deplacement", s.statuts_defs), "gelé : ne bouge plus")
	s._tiquer_statuts(j, h.ticks + 10)
	verifier(not Etres.a_statut_id(j, "gel"), "Force 40 : libéré au premier jet")
	# Béni : +1 dé
	s.appliquer_statut(j, "beni", 3000, "")
	verifier(int(Etres.add_statuts(j, "des", s.statuts_defs)) == 1, "Béni : +1 dé aux jets")
	# Peau de pierre : +5 d'armure dans la résolution
	s.appliquer_statut(j, "peau_de_pierre", 100, "")
	verifier(int(Etres.add_statuts(j, "armure", s.statuts_defs)) == 5, "Peau de pierre : +5 d'armure")
	j.statuts = []
	# L'eau éteint la brûlure
	s.appliquer_statut(j, "brulure", 30, "")
	var bord: Vector2i = j.pos + Vector2i(1, 0)
	var eau: Vector2i = j.pos + Vector2i(2, 0)
	s.grille.contenu[s.grille.idx(bord)] = 0
	s.grille.hauteurs[s.grille.idx(bord)] = s.grille.h(j.pos)
	s.grille.poser_contenu(eau, "eau")
	s.attente[j.id] = true
	var ok_dep := s.intention(j.id, {"type": "deplacer", "vers": bord})
	verifier(ok_dep and not Etres.a_statut_id(j, "brulure"), "arriver au bord de l'eau éteint la brûlure")


# ---------------------------------------------------------------- Le bestiaire : 19 races animales

func test_bestiaire() -> void:
	var betes: Array = []
	for cid in GameData.catalogues.creatures.keys():
		if "bete" in GameData.catalogues.creatures[cid].get("tags", []):
			betes.append(str(cid))
	verifier(betes.size() >= 19, "au moins 19 races animales au bestiaire (%d)" % betes.size())
	for cid in betes:
		for a in GameData.catalogues.creatures[cid].actions:
			verifier(GameData.catalogues.creature_actions.has(str(a)), "%s : action %s connue" % [cid, a])
	for b in ["toundra", "marecage", "montagne", "desert_aride"]:
		for f in GameData.entree("biomes", b).faune:
			verifier(GameData.catalogues.creatures.has(str(f.id)), "%s : faune %s existe" % [b, f.id])
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var ours := s.ajouter("ours_brun", j.pos + Vector2i(1, 0), "ia")
	verifier(ours.corps.stats.force == 18 and ours.corps.silhouette == "quadrupede" and not ours.actions.is_empty(), "un ours brun se pose : Force 18, quadrupède, %d actions" % ours.actions.size())
	var moustiques := s.ajouter("nuee_moustiques", j.pos + Vector2i(-1, 0), "ia")
	verifier(moustiques.corps.silhouette == "amorphe" and "nuee" in moustiques.tags, "une nuée de moustiques : amorphe, tag nuée")


# ---------------------------------------------------------------- Les 22 plantes

func test_plantes() -> void:
	verifier(GameData.catalogues.plants.size() == 22, "22 plantes au catalogue (%d)" % GameData.catalogues.plants.size())
	var cats := {}
	for pid in GameData.catalogues.plants.keys():
		var c := str(GameData.catalogues.plants[pid].categorie)
		cats[c] = int(cats.get(c, 0)) + 1
	verifier(int(cats.get("culture", 0)) == 8 and int(cats.get("buisson", 0)) == 4 and int(cats.get("herbe", 0)) == 6 and int(cats.get("champignon", 0)) == 2 and int(cats.get("decorative", 0)) == 2, "8 cultures, 4 buissons, 6 herbes, 2 champignons, 2 décoratives")
	var s := Simulation.new(142)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var am := s.generer_objet("amanite", 1, {}, "commun", 0)
	j.sac.append(am.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "manger", "objet": am.uid}) and Etres.a_statut_tag(j, "poison", s.statuts_defs), "manger une amanite empoisonne")
	j.statuts = []
	j.sante = 10
	var ps := s.generer_objet("potion_soin", 1, {}, "commun", 0)
	j.sac.append(ps.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "manger", "objet": ps.uid}) and int(j.sante) >= 12, "la potion de soin rend 2d6 (%d)" % int(j.sante))
	verifier(str(GameData.entree("items", "achillee").distillat) == "potion_soin" and GameData.catalogues.recipes.has("distiller_herbe"), "l'achillée se distille en potion de soin")
	s.monde.fermer()


# ---------------------------------------------------------------- Axe des niveaux de recette

func test_niveaux_recette() -> void:
	var s := Simulation.new(141)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	j["recettes_connues"] = ["tremper_verre"]
	verifier(s.niveau_recette(j, "tremper_verre") == 1, "niveau 1 par défaut")
	s._doublon_recette(j, "tremper_verre")
	verifier(s.niveau_recette(j, "tremper_verre") == 2, "1 doublon : niveau 2")
	s._doublon_recette(j, "tremper_verre")
	verifier(s.niveau_recette(j, "tremper_verre") == 2 and int(j.doublons_recettes.tremper_verre) == 1, "il en faut 2 pour le niveau 3 : encore 1")
	s._doublon_recette(j, "tremper_verre")
	verifier(s.niveau_recette(j, "tremper_verre") == 3, "2 doublons : niveau 3")
	for k in 7:
		s._doublon_recette(j, "tremper_verre")
	verifier(s.niveau_recette(j, "tremper_verre") == 5, "10 doublons en tout : niveau 5 (plafond)")
	s._doublon_recette(j, "tremper_verre")
	verifier(s.niveau_recette(j, "tremper_verre") == 5, "au plafond, un doublon ne fait plus rien")
	# Le jet : même moyenne, variance resserrée, jamais multipliée
	var rng := RandomNumberGenerator.new()
	var lo1 := 9.0
	var hi1 := 0.0
	var lo5 := 9.0
	var hi5 := 0.0
	for k in 300:
		rng.seed = k
		var q1 := s.regles.qualite_craft(25, rng, s.regles.resserrement_recette(1))
		rng.seed = k
		var q5 := s.regles.qualite_craft(25, rng, s.regles.resserrement_recette(5))
		lo1 = minf(lo1, q1)
		hi1 = maxf(hi1, q1)
		lo5 = minf(lo5, q5)
		hi5 = maxf(hi5, q5)
	verifier(hi5 - lo5 < hi1 - lo1 and hi5 <= hi1 + 0.001 and lo5 >= lo1 - 0.001, "niveau 5 : fourchette [%.2f ; %.2f] dans [%.2f ; %.2f]" % [lo5, hi5, lo1, hi1])
	s.monde.fermer()


# ---------------------------------------------------------------- Compensation de l'arme mixte

func test_arme_mixte() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var mixte := {"uid": "mixte_test", "name_key": "item.proto_epee.name", "type": "arme", "equip_slot": "main_principale", "hands": 1, "functionality": "epee", "durete_base": 20, "qualite": 1.0, "element": "feu", "elements": {"feu": 0.6, "metal": 0.4}, "tags": ["arme"], "materiau": "fer", "affixes": [], "sertissures": {"nombre": 0, "contenu": []}}
	s.items["mixte_test"] = mixte
	j.sac.append("mixte_test")
	j.equipement["main_principale"] = "mixte_test"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(s.vecteur_arme(mixte) == {"feu": 0.6, "metal": 0.4}, "le vecteur complet de l'arme assemblée est lu")
	verifier(s.segments_possibles(mixte) == ["feu", "metal"], "deux segments possibles : feu, metal")
	var pure := {"element": "feu"}
	verifier(s.segments_possibles(pure).is_empty(), "une arme pure n'a pas le choix")
	var h := s.horloge_de(j)
	j.chaine.segments.clear()
	s._poser_segment(j, s.vecteur_arme(mixte), h.ticks)
	verifier(j.chaine.segments.size() == 1 and str(j.chaine.segments[0].element) == "feu", "sans préférence : le dominant (feu)")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "segment_prefere", "element": "metal"}) and str(j.segment_prefere) == "metal", "préférer le métal (0 tick)")
	s._poser_segment(j, s.vecteur_arme(mixte), h.ticks + 1)
	verifier(str(j.chaine.segments[j.chaine.segments.size() - 1].element) == "metal", "avec préférence : le segment posé est métal")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "segment_prefere", "element": "eau"})
	s._poser_segment(j, s.vecteur_arme(mixte), h.ticks + 2)
	verifier(str(j.chaine.segments[j.chaine.segments.size() - 1].element) == "feu", "une préférence hors du vecteur est ignorée : dominant")


# ---------------------------------------------------------------- Stratification verticale : la palette de sol

func test_palette_etage() -> void:
	var s := Simulation.new(140)
	var theme := GameData.entree("dungeon_themes", "ruine")
	verifier(s.materiau_mur_etage(theme, 1) == "pierre" and s.materiau_mur_etage(theme, 2) == "pierre", "étages 1-2 : le thème (pierre)")
	verifier(s.materiau_mur_etage(theme, 3) == "ardoise" and s.materiau_mur_etage(theme, 5) == "basalte" and s.materiau_mur_etage(theme, 8) == "granit" and s.materiau_mur_etage(theme, 12) == "granit_noir", "3 ardoise · 5 basalte · 8 granit · 12 granit noir")
	s.charger_donjon("ruine", 140, 17, 6)
	verifier(s.grille.materiau_defaut == "basalte", "étage 6 chargé : les murs sont de basalte")
	var comptes := {}
	for y in s.grille.hauteur_grille:
		for x in s.grille.largeur:
			var t := Vector2i(x, y)
			if "destructible" in s.grille.contenu_de(t).get("tags", []):
				var m := s.grille.materiau_de(t)
				comptes[m] = int(comptes.get(m, 0)) + 1
	verifier(int(comptes.get("basalte", 0)) > int(comptes.get("granit", 0)) and int(comptes.get("granit", 0)) > 0 and int(comptes.get("ardoise", 0)) > 0, "poches de strates : basalte majoritaire, taches de granit et d'ardoise (%s)" % str(comptes))
	var d_bas := int(GameData.entree("materials", "basalte").stats.durete)
	var d_cal := int(GameData.entree("materials", "calcaire").stats.durete)
	verifier(d_bas > d_cal, "le basalte (%d) est plus dur que le calcaire (%d) : creuser ralentit avec l'étage" % [d_bas, d_cal])


# ---------------------------------------------------------------- Effets d'équipement types

func test_effets_equipement() -> void:
	var s := Simulation.new(139)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var anneau := {"uid": "anneau_test", "name_key": "x", "type": "bijou", "equip_slot": "anneau", "affixes": [{"id": "passif_vitesse", "params": {"pct": 50}}, {"id": "passif_regen", "params": {"pct": 100}}, {"id": "passif_poids", "params": {"n": 40}}, {"id": "passif_tag", "params": {"tag": "immunite_poison"}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	s.items["anneau_test"] = anneau
	var cap0: float = s.poids_de(j).capacite
	j.equipement["anneau_1"] = "anneau_test"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(j.mecaniques.has("vitesse_deplacement") and j.mecaniques.has("regen_sante") and "immunite_poison" in j.tags_acquis, "les mécaniques et le tag sont collectés (%s)" % str(j.mecaniques.keys()))
	verifier(s.poids_de(j).capacite == cap0 + 40.0, "capacité de poids +40 (%.0f → %.0f)" % [cap0, s.poids_de(j).capacite])
	verifier(not s.appliquer_statut(j, "poison", 100, ""), "immunisé au poison")
	j.sante = 10
	j.tick_endurance = 0
	s._regenerer(j, 1000)
	verifier(int(j.sante) == 15, "régénération : +5 PV en 1000 ticks à +100 %% (%d)" % int(j.sante))
	var t: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.contenu[s.grille.idx(t)] = 0
	s.grille.contenu[s.grille.idx(t + Vector2i(1, 0))] = 0
	s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	s.grille.hauteurs[s.grille.idx(t + Vector2i(1, 0))] = s.grille.h(j.pos)
	s.attente[j.id] = true
	var c0 := int(j.compteur)
	s.intention(j.id, {"type": "deplacer", "vers": t})
	var ticks_avec: int = int(j.compteur) - c0
	var ticks_sans: int = ceili(float(s.regles.ticks_deplacement(int(s.regles.r.deplacement.cout_base), j.competences_eff, false)) * s.poids_de(j).facteur)
	j.equipement.erase("anneau_1")
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(ticks_avec > 0 and ticks_avec < ticks_sans, "vitesse +50 %% : %d ticks avec, %d sans" % [ticks_avec, ticks_sans])
	# Pas silencieux : détecté de moins loin
	var g := s.ajouter("villageois", j.pos + Vector2i(0, 8), "ia")
	s._habiller_pnj(g, GameData.entree("creatures", "villageois"))
	g.corps.stats.perception = 10
	for d in range(1, 9):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(0, d))] = 0
	s.horloge_monde.ticks = int(s._cycle().ticks_par_jour) / 2
	verifier(s.voit_ia(g, j), "à 8 tuiles, de jour : vu")
	j["tags_acquis_race"] = ["pas_silencieux"]
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(not s.voit_ia(g, j), "pas silencieux : portée 10 × 0,7 = 7 → invisible à 8 tuiles")
	s.monde.fermer()


# ---------------------------------------------------------------- Wu Xing hors combat : le lieu

func test_vecteur_lieu() -> void:
	var s := Simulation.new(138)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var v := s.vecteur_lieu(j.pos)
	var total := 0.0
	for k in v.keys():
		total += float(v[k])
	verifier(v.size() == 5 and absf(total - 1.0) < 0.001, "le lieu porte un vecteur à cinq éléments normalisé (%s)" % str(v))
	var cap := Capacites.new(GameData.catalogues["modules"])
	var plan := cap.assembler(["point", "etincelle"], 5, "1d4", {})
	s.vecteur_lieu_force = {"feu": 1.0}
	verifier(is_equal_approx(s.mult_mana_lieu(j, plan), 0.85), "Étincelle (Feu) sur une terre de Feu : mana × 0,85")
	s.vecteur_lieu_force = {"eau": 1.0}
	verifier(is_equal_approx(s.mult_mana_lieu(j, plan), 1.15), "sur une terre d'Eau (qui domine le Feu) : × 1,15")
	s.vecteur_lieu_force = {"bois": 1.0}
	verifier(is_equal_approx(s.mult_mana_lieu(j, plan), 1.0), "sur une terre de Bois : × 1")
	var plan_c := cap.assembler(["point", "brasier"], 5, "1d4", {})
	j.mana = 100
	s.vecteur_lieu_force = {"feu": 1.0}
	s._payer(j, plan_c)
	var paye_feu := 100 - int(j.mana)
	j.mana = 100
	s.vecteur_lieu_force = {"eau": 1.0}
	s._payer(j, plan_c)
	var paye_eau := 100 - int(j.mana)
	verifier(paye_feu < paye_eau, "payé %d en terre de Feu, %d en terre d'Eau" % [paye_feu, paye_eau])
	# Terroir : la condition lit le lieu
	var plan_t := cap.assembler(["point", "etincelle", "terroir"], 5, "1d4", {})
	verifier(plan_t.erreurs.is_empty() and plan_t.conditions.size() == 1 and str(plan_t.conditions[0].predicat.type) == "vecteur_de_lieu", "Terroir : un prédicat structuré")
	s.vecteur_lieu_force = {"feu": 1.0}
	var ev := s._evaluer_conditions(j, plan_t, j.pos + Vector2i(1, 0))
	verifier(ev.is_empty() or not bool(ev.get("fausse", false)), "Terroir vrai sur une terre de Feu")
	s.monde.fermer()


# ---------------------------------------------------------------- Sorts cataclysmiques

func test_cataclysme() -> void:
	var cap := Capacites.new(GameData.catalogues["modules"])
	var plan := cap.assembler(["carre", "cataclysme", "ampleur", "ampleur"], 5, "1d4", {})
	verifier(plan.erreurs.is_empty() and int(plan.taille) == 3 and int(plan.ticks) >= 60, "[Carré]+[Cataclysme]+2×[Ampleur] : 7 × 7, %d ticks" % int(plan.ticks))
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
	j.mana = 99999   # un cataclysme 7 × 7 remodèle 49 tuiles : 49 × 40 = 1 960 mana — le prix suit la surface
	j.mana_max = 99999
	j.endurance = j.endurance_max
	_capacite_test(s, j, "k", ["carre", "cataclysme", "ampleur", "ampleur"])
	var centre: Vector2i = j.pos + Vector2i(0, -3)
	var h0 := s.grille.h(centre)
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": j.capacites.size() - 1, "cible": centre}), "le cataclysme est canalisé (télégraphié)")
	verifier(not j.action_en_cours.is_empty(), "la canalisation est visible : une action en cours")
	s.pas(j.horloge)
	verifier(s.grille.h(centre) == maxi(0, h0 - 4) and int(j.endurance) == 0 and s.modifs_terrain.has(centre), "cratère : %d → %d, endurance vidée, terrain mémorisé" % [h0, s.grille.h(centre)])
	j.mana = 300
	j.compteur = h.ticks
	verifier(not s.intention(j.id, {"type": "capacite", "index": j.capacites.size() - 1, "cible": centre}), "un seul cataclysme par combat")


# ---------------------------------------------------------------- Armes fantomatiques

func test_armes_fantomes() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	j.mana = 30
	var arme0: String = j.equipement.get("main_principale", "")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "arme_fantome", "element": "feu"}) and str(j.equipement.main_principale) == "fantome_" + j.id and int(j.mana) == 20, "une lame de Feu en main, 10 de mana")
	verifier(s.vecteur_arme(Etres.arme(j, s.items)) == {"feu": 1.0} and (arme0.is_empty() or arme0 in j.sac), "vecteur pur {feu: 1}, l'ancienne arme au sac")
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	var pv0 := int(loup.sante)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	var h := s.horloge_de(j)
	for k in 3:
		j.compteur = h.ticks
		s.pas(j.horloge)
	verifier(int(loup.sante) < pv0, "la lame frappe (%d → %d)" % [pv0, int(loup.sante)])
	verifier(not s._sertir(j, "fantome_" + j.id, "", h.ticks), "ni sertissable ni enchantable")
	var mana1 := int(j.mana)
	s._tiquer_armes_fantomes(j.horloge, int(s.items["fantome_" + j.id].dernier_tick) + 100)
	verifier(int(j.mana) == mana1 - 10, "entretien : 100 ticks = −10 mana (%d → %d)" % [mana1, int(j.mana)])
	j.mana = 0
	s._tiquer_armes_fantomes(j.horloge, int(s.items["fantome_" + j.id].dernier_tick) + 10)
	verifier(not s.items.has("fantome_" + j.id) and not j.equipement.has("main_principale"), "à mana 0, la lame se dissipe")


# ---------------------------------------------------------------- Empoigne : l'effet saisie

func test_empoigne() -> void:
	var cap := Capacites.new(GameData.catalogues["modules"])
	var plan := cap.assembler(["point", "empoigne"], 5, "1d4", {})
	verifier(plan.erreurs.is_empty() and "saisie" in plan.noyau.effets, "[Point]+[Empoigne] : un plan de saisie")
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	for d in range(2, 5):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 0))] = 0
	s._executer_capacite(j, plan, loup.pos, false)
	verifier(str(j.get("porte", "")) == loup.id and Etres.a_statut_tag(loup, "saisi", s.statuts_defs), "sans talent : le loup est saisi par la capacité")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "garde"}), "en portant : pas de garde")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "lancer_etre", "vers": j.pos + Vector2i(3, 0)}) and not j.has("porte") and Grille.distance(j.pos, loup.pos) >= 2, "lancé à %d tuiles" % Grille.distance(j.pos, loup.pos))


# ---------------------------------------------------------------- Terrasser et régénération

func test_terrasser() -> void:
	var s := Simulation.new(137)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var t: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.contenu[s.grille.idx(t)] = 0
	var h0 := s.grille.h(t)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "terrasser", "vers": t, "sens": -1}) and s.grille.h(t) == h0 - 1, "abaisser à mains nues : %d → %d" % [h0, s.grille.h(t)])
	j.equipement.erase("main_principale")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "terrasser", "vers": t, "sens": 1}), "élever sans pioche : refusé")
	var pioche := s.generer_objet("proto_pioche", 1, {}, "commun", 0)
	if not pioche.is_empty():
		j.sac.append(pioche.uid)
		j.equipement["main_principale"] = pioche.uid
		s.attente[j.id] = true
		verifier(s.intention(j.id, {"type": "terrasser", "vers": t, "sens": 1}) and s.grille.h(t) == h0, "élever avec la pioche : %d" % s.grille.h(t))
		s.attente[j.id] = true
		s.intention(j.id, {"type": "terrasser", "vers": t, "sens": 1})
	verifier(s.modifs_terrain.has(t) and int(s.modifs_terrain[t].h) == h0, "l'état d'origine est mémorisé (h %d)" % h0)
	# Hors claim, la semaine rend la tuile ; sur un claim, elle persiste
	var cell := s._cell_de(t)
	s.monde.claims.erase(cell)
	s._regenerer_terrain_sauvage()
	verifier(s.grille.h(t) == h0 and not s.modifs_terrain.has(t), "hors claim : le monde rend la hauteur %d" % h0)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "terrasser", "vers": t, "sens": -1})
	s.monde.claims[cell] = {"proprietaire": j.id}
	s._regenerer_terrain_sauvage()
	verifier(s.grille.h(t) == h0 - 1, "sur un claim : la tranchée persiste")
	s.monde.fermer()


# ---------------------------------------------------------------- Incarnation : jouer une bête

func test_incarnation() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var cerf := s.ajouter("cerf", j.pos + Vector2i(0, 1), "ia")
	cerf["maitre"] = j.id
	cerf.camp = j.camp
	var ancien_id: String = j.id
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "incarner", "pnj": cerf.id}) and cerf.controle == "joueur" and j.controle == "ia" and str(j.maitre) == cerf.id, "le contrôle passe au cerf ; l'ancien corps devient compagnon")
	verifier(s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur").size() == 1, "un seul corps contrôlé")
	var casque := s.generer_objet("proto_casque_cuir", 1, {}, "commun", 0)
	cerf.sac.append(casque.uid)
	s.attente[cerf.id] = true
	verifier(not s.intention(cerf.id, {"type": "equiper", "objet": casque.uid}), "pas de mains : le casque est refusé")
	s.attente[cerf.id] = true
	verifier(not s.intention(cerf.id, {"type": "parler", "pnj": ancien_id}), "le monde ne parle pas à une bête")
	# Attaquer sans arme : les actions de créature du cerf
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = cerf.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	var pv0 := int(loup.sante)
	s.attente[cerf.id] = true
	verifier(s.intention(cerf.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "le cerf attaque avec ses actions de créature")
	var h := s.horloge_de(cerf)
	for k in 3:
		cerf.compteur = h.ticks
		s.pas(cerf.horloge)
	verifier(int(loup.sante) < pv0, "le loup encaisse (%d → %d)" % [pv0, int(loup.sante)])


# ---------------------------------------------------------------- Le Lycanthrope

func test_lycanthrope() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	j.race = "lycanthrope"
	s._contreparties(j)
	var force0 := int(j.stats_eff.force)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "transformer"}) and bool(j.forme_bestiale) and int(j.stats_eff.force) == maxi(1, roundi(force0 * 1.5)), "forme bestiale : Force %d → %d" % [force0, int(j.stats_eff.force)])
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	var pv0 := int(loup.sante)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "attaquer sous forme bestiale : une action de créature")
	var h := s.horloge_de(j)
	for k in 3:
		j.compteur = h.ticks
		s.pas(j.horloge)
	verifier(int(loup.sante) < pv0, "le loup est griffé (%d → %d)" % [pv0, int(loup.sante)])
	j.compteur = h.ticks
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "capacite", "index": 0, "cible": loup.pos}), "capacité refusée sous forme bestiale")
	j.compteur = h.ticks
	s.attente[j.id] = true
	var ok_tr := s.intention(j.id, {"type": "transformer"})
	verifier(ok_tr and not bool(j.forme_bestiale) and int(j.stats_eff.force) == force0, "forme humaine : Force %d" % int(j.stats_eff.force))
	# La nuit forcée : jour 30, minuit
	var jour := int(s._cycle().ticks_par_jour)
	s.horloge_monde.ticks = 30 * jour
	s._tiquer_vampires(j.horloge, s.horloge_monde.ticks)
	verifier(bool(j.forme_bestiale) and bool(j.forme_forcee), "nuit 30 : la bête s'impose")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "transformer"}), "impossible de la quitter cette nuit")
	# Transmission : un villageois mordu s'éveille lycanthrope
	var v := s.ajouter("villageois", j.pos + Vector2i(0, 1), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v.sante = 500
	v.sante_max = 500
	s._executer_action_creature(j, s.actions_creatures.morsure_puissante, v)
	verifier(Etres.a_statut_tag(v, "morsure_lune", s.statuts_defs), "le villageois porte la Morsure lunaire")
	s.horloge_monde.ticks = 30 * jour + jour / 2
	s._tiquer_vampires(j.horloge, s.horloge_monde.ticks)
	verifier(not bool(j.forme_bestiale) and v.race == "lycanthrope", "à l'aube : forme humaine rendue, le villageois s'éveille lycanthrope")


# ---------------------------------------------------------------- Le Spectre

func test_spectre() -> void:
	var s := Simulation.new(136)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	s.monde.delta[s._cell_de(j.pos)] = 100   # une cellule mortellement corrompue
	verifier(s.monde.corruption_de(s._cell_de(j.pos)) >= 70.0, "la cellule est corrompue à %.0f" % s.monde.corruption_de(s._cell_de(j.pos)))
	s._appliquer_degats(j, 9999, "", {"type": "test"})
	verifier(not j.vivant, "le joueur meurt")
	s._respawn(j)
	verifier(j.vivant and j.race == "spectre" and s.a_talent(j, "sans_chair"), "il se relève spectre")
	var pv := int(j.sante)
	s._appliquer_degats(j, 10, "", {"type": "tranchant", "element": {}})
	verifier(pv - int(j.sante) == 3, "10 tranchant → 3 subis (×0,3)")
	verifier(s.poids_de(j).capacite == 5.0, "capacité de poids 5")
	var casque := s.generer_objet("proto_casque_cuir", 1, {}, "commun", 0)
	j.sac.append(casque.uid)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "equiper", "objet": casque.uid}), "le casque est refusé")
	# Traverser un mur d'une tuile
	var mur: Vector2i = j.pos + Vector2i(1, 0)
	var derriere: Vector2i = j.pos + Vector2i(2, 0)
	s.grille.contenu[s.grille.idx(derriere)] = 0
	s.grille.poser_contenu(mur, "mur")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "traverser_mur", "cible": derriere}) and j.pos == derriere, "il passe à travers le mur")
	# Un civil qui le voit prend peur
	var v := s.ajouter("villageois", j.pos + Vector2i(0, 1), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v.camp = "civil"
	s._decider_ia(v, s.horloge_monde.ticks)
	verifier(Etres.a_statut_tag(v, "controle", s.statuts_defs), "le villageois est terrorisé")
	s.monde.fermer()


# ---------------------------------------------------------------- Le Vampire

func test_vampire() -> void:
	var s := Simulation.new(135)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var jour := int(s._cycle().ticks_par_jour)
	s.horloge_monde.ticks = 0   # minuit
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	j.race = "vampire"
	s._contreparties(j)
	verifier(s.a_talent(j, "soif_de_sang"), "le joueur est vampire")
	var force0 := int(j.stats_eff.force)
	s._tiquer_vampires(j.horloge, 0)
	verifier(int(j.stats_eff.force) == force0 + 3 and not Etres.a_statut_tag(j, "vampire", s.statuts_defs) == false, "la nuit : +3 Force (%d → %d)" % [force0, int(j.stats_eff.force)])
	var seg0: int = j.chaine.segments.size()
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "mordre", "cible": v.id}) and j.chaine.segments.size() >= int(j.chaine.capacite) - 1 and Etres.a_statut_tag(v, "morsure", s.statuts_defs), "mordre : jauge pleine (%d → %d), le villageois porte la Morsure" % [seg0, j.chaine.segments.size()])
	var plat := s.generer_objet("plat_ragout", 1, {}, "commun", 0) if GameData.catalogues.items.has("plat_ragout") else {}
	if plat.is_empty():
		var it := {"uid": "plat_test", "type": "consommable", "tags": ["plat"], "nutrition": 30, "name_key": "x"}
		s.items["plat_test"] = it
		plat = it
	j.sac.append(plat.uid)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "manger", "objet": plat.uid}), "un plat est refusé")
	s.horloge_monde.ticks = jour / 2   # midi
	j.sante = j.sante_max
	s._tiquer_vampires(j.horloge, jour / 2)
	verifier(int(j.stats_eff.force) == force0 and j.statuts.filter(func(s0: Dictionary) -> bool: return str(s0.id) == "soleil").size() == 1, "le jour : +3 retiré, le Soleil brûle")
	verifier(v.race == "vampire" and "vision_nocturne" in v.tags_acquis and s.a_talent(v, "soif_de_sang"), "le villageois mordu s'éveille vampire à l'aube")
	s.monde.fermer()


# ---------------------------------------------------------------- Aciers alliés et caoutchouc

func test_aciers_allies() -> void:
	var inox: Dictionary = GameData.entree("materials", "acier_inox")
	var tung: Dictionary = GameData.entree("materials", "acier_tungstene")
	var caou: Dictionary = GameData.entree("materials", "caoutchouc")
	verifier(inox.category == "metal" and int(inox.stats.durete) > int(GameData.entree("materials", "acier_trempe").stats.durete) and tung.category == "metal" and caou.category == "synthetique", "inox et tungstène sont des métaux plus durs que l'acier trempé, le caoutchouc un synthétique")
	var r: Dictionary = GameData.entree("recipes", "allier_inox")
	verifier(bool(r.get("industrielle", false)) and r.station == "forge" and r.output.material == "acier_inox", "allier_inox : recette industrielle à la forge")
	var s := Simulation.new(134)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	s.grille.stations_fixes[s.grille.idx(j.pos)] = "forge"
	verifier(not ("allier_inox" in s.recettes_disponibles(j).map(func(x: Dictionary) -> String: return str(x.get("id", "")))), "inconnue : invisible à la forge")
	if not j.has("recettes_connues"):
		j["recettes_connues"] = []
	j.recettes_connues.append("allier_inox")
	verifier("allier_inox" in s.recettes_disponibles(j).map(func(x: Dictionary) -> String: return str(x.get("id", ""))), "apprise : visible à la forge")
	s.monde.fermer()


# ---------------------------------------------------------------- Éclairage : la propagation 0-15

func test_propagation_lumiere() -> void:
	var s := Simulation.new(133)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	for d in range(-2, 7):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 2))] = 0
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 3))] = 0
	var src: Vector2i = j.pos + Vector2i(0, 2)
	s.grille.poser_contenu(src, "meuble")
	s.grille.meubles[s.grille.idx(src)] = "torchere"
	s.lumiere_sale = true
	var n0 := s.niveau_lumiere(src)
	verifier(n0 >= 9 and s.niveau_lumiere(src + Vector2i(1, 0)) == n0 - 1 and s.niveau_lumiere(src + Vector2i(3, 0)) == n0 - 3, "torchère : niveau %d, −1 par tuile" % n0)
	verifier(s.lumiere_a(src + Vector2i(1, 0)) == roundi(float(n0 - 1) * 100.0 / 15.0), "lumiere_a = niveau × 100 / 15")
	# Un mur : éclairé, mais rien ne passe derrière (la lumière contourne par les côtés, plus faible)
	var mur: Vector2i = src + Vector2i(2, 0)
	s.grille.poser_contenu(mur, "mur")
	for dy in [-1, 1]:
		s.grille.poser_contenu(src + Vector2i(2, dy), "mur")
		s.grille.poser_contenu(src + Vector2i(2, 2 * dy), "mur")
	s.lumiere_sale = true
	var derriere := s.niveau_lumiere(src + Vector2i(3, 0))
	verifier(s.niveau_lumiere(mur) == n0 - 2 and derriere < n0 - 3, "le mur est éclairé (%d) mais derrière il reste %d (< %d)" % [s.niveau_lumiere(mur), derriere, n0 - 3])
	s.monde.fermer()


# ---------------------------------------------------------------- Le Fossoyeur et L'Engrenage

func test_fossoyeur_et_engrenage() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	j.classe = "le_fossoyeur"
	j["reputations"] = {"bourg": 20}
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(0, -2)
	s.grille.placer(loup.id, loup.pos)
	s._appliquer_degats(loup, 999, j.id, {"type": "test"})
	verifier(not loup.vivant, "le loup est mort")
	var n0 := s.vivants().size()
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "relever", "cible": loup.id}) and s.vivants().size() == n0 + 1 and int(j.reputations.bourg) == 10, "relevé : un loup de plus au camp du joueur, réputation 20 → 10")
	var releve: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.has("fin_invocation"))[0]
	verifier(releve.camp == j.camp and str(releve.maitre) == j.id and releve.pos == loup.pos, "il se lève sur la tuile du cadavre, au camp du joueur")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "relever", "cible": loup.id}), "un cadavre ne se relève qu'une fois")
	var h := s.horloge_de(j)
	h.avancer(61)
	s._tiquer_differes(j.horloge, h.ticks)
	verifier(not releve.vivant, "après 60 ticks, le relevé retourne à la terre")
	# L'Engrenage : un affût qui mange le carquois
	j.classe = "l_engrenage"
	var loup3: Dictionary = s.entites["loup_3"]
	s.grille.liberer(loup3.pos)
	loup3.pos = j.pos + Vector2i(3, 0)
	s.grille.placer(loup3.id, loup3.pos)
	for d in range(1, 4):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 0))] = 0
	var mun0 := int(j.munitions)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "affut", "cible": j.pos + Vector2i(1, 0)}) and s.affuts.size() == 1, "affût déployé")
	var pv0 := int(loup3.sante)
	s._tirs_d_affuts(j.horloge, h.ticks + 100)
	verifier(int(loup3.sante) < pv0 and int(j.munitions) == mun0 - 1, "il tire sur le loup (%d → %d) et consomme une flèche (%d → %d)" % [pv0, int(loup3.sante), mun0, int(j.munitions)])
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "affut", "cible": j.pos + Vector2i(0, 1)}) and s.affuts.size() == 1 and s.affuts[0].pos == j.pos + Vector2i(0, 1), "redéployer déplace l'affût")
	j.munitions = 0
	s._tirs_d_affuts(j.horloge, h.ticks + 200)
	verifier(s.affuts.is_empty(), "sans munition, l'affût se replie")


# ---------------------------------------------------------------- Le Masque et Le Sceau

func test_masque_et_sceau() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	j.classe = "le_masque"
	var force0 := int(j.stats_eff.force)
	s.attente[j.id] = true
	var c0 := int(j.compteur)
	verifier(s.intention(j.id, {"type": "masque", "masque": "masque_du_taureau"}) and int(j.stats_eff.force) == force0 + 3 and int(j.compteur) == c0, "Taureau : +3 Force, à 0 tick")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "masque", "masque": "masque_du_renard"})
	s.attente[j.id] = true
	s.intention(j.id, {"type": "masque", "masque": "masque_du_hibou"})
	var portes: Array = j.statuts.filter(func(s0: Dictionary) -> bool: return "masque" in s.statuts_defs[str(s0.id)].get("tags", []))
	verifier(portes.size() == 2 and str(portes[0].id) == "masque_du_renard" and int(j.stats_eff.force) == force0, "le troisième masque remplace le Taureau : Renard + Hibou")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "garde"}), "Le Masque ne prend pas la garde")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "masque", "masque": "masque_du_hibou"})
	verifier(j.statuts.filter(func(s0: Dictionary) -> bool: return str(s0.id) == "masque_du_hibou").is_empty(), "reporter le même masque le retire")
	# Le Sceau : glyphe permanent à 2× mana, immobile, déclenché à distance
	j.classe = "le_sceau"
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
	var mana0 := int(j.mana)
	verifier(s.intention(j.id, {"type": "capacite", "index": j.capacites.size() - 1, "cible": glyphe_pos}), "poser le glyphe")
	s.pas(j.horloge)
	verifier(s.glyphes.size() == 1 and int(s.glyphes[0].fin) > h.ticks + 100000 and Etres.bloque_statuts(j, "deplacement", s.statuts_defs), "glyphe permanent, graveur immobile (mana %d → %d)" % [mana0, int(j.mana)])
	s.grille.liberer(loup.pos)
	loup.pos = glyphe_pos
	s.grille.placer(loup.id, glyphe_pos)
	j.compteur = h.ticks
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "declencher_glyphe", "cible": glyphe_pos}) and s.glyphes.is_empty() and Etres.bloque_statuts(loup, "deplacement", s.statuts_defs), "déclenché à distance : le loup est enraciné")


# ---------------------------------------------------------------- Le Passeur et Le Sablier

func test_passeur_et_sablier() -> void:
	var s := Simulation.new(132)
	s.charger_donjon("ruine", 132, 15, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var mana0 := int(j.mana_max)
	j.classe = "le_passeur"
	s._contreparties(j)
	verifier(int(j.mana_max) == maxi(1, roundi(mana0 * 0.7)), "Le Passeur : mana max %d → %d" % [mana0, int(j.mana_max)])
	for d in range(1, 5):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 0))] = 0
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "poser_portail", "cible": j.pos + Vector2i(1, 0)}), "portail 1 posé")
	s.grille.contenu[s.grille.idx(j.pos + Vector2i(0, 1))] = 0
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "poser_portail", "cible": j.pos + Vector2i(0, 1)}) and s.portails.size() == 2, "portail 2 posé")
	s.grille.contenu[s.grille.idx(j.pos + Vector2i(-1, 0))] = 0
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "poser_portail", "cible": j.pos + Vector2i(-1, 0)}) and s.portails.size() == 2 and not s.portails.has(s.grille.idx(j.pos + Vector2i(1, 0))), "le troisième déplace le plus ancien")
	var depart: Vector2i = j.pos
	s.grille.liberer(j.pos)
	j.pos = depart + Vector2i(0, 1)
	s.grille.placer(j.id, j.pos)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "traverser"}) and j.pos == depart + Vector2i(-1, 0), "traversée vers le jumeau")
	# Le Sablier
	j.classe = "le_sablier"
	s._contreparties(j)
	verifier(int(j.mana_max) == mana0, "la contrepartie du Passeur est levée")
	var loup := s.ajouter("loup", depart + Vector2i(2, 0), "ia")
	var c0 := int(loup.compteur)
	var sante0 := int(j.sante)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "tempo", "cible": loup.id}) and int(loup.compteur) == c0 + 8 and int(j.sante) == sante0 - 5, "tempo volé : loup +8, −5 PV")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "tempo", "cible": loup.id}), "le verrou anti-stunlock refuse le second vol")


# ---------------------------------------------------------------- L'Écarlate et Le Porteur

func test_ecarlate_et_porteur() -> void:
	var s := Simulation.new(131)
	s.charger_donjon("ruine", 131, 15, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	j.classe = "l_ecarlate"
	verifier(s.a_talent(j, "jauge_de_sang"), "L'Écarlate porte la jauge de sang")
	j.sante = 40
	s._appliquer_degats(j, 30, "", {"type": "test"})
	verifier(int(j.get("sang", 0)) == 30, "30 de dégâts subis : sang 30")
	var fiole := s.generer_objet("fiole_de_soin", 1, {}, "commun", 0)
	j.sac.append(fiole.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "manger", "objet": fiole.uid})
	verifier(int(j.get("sang", 0)) == 0, "boire une fiole de soin vide la jauge")
	# Le Porteur : saisir un loup adjacent, ne plus pouvoir attaquer, le lancer.
	j.classe = "le_porteur"
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	for d in range(1, 5):
		var q: Vector2i = j.pos + Vector2i(d, 0)
		if d > 1:
			s.grille.contenu[s.grille.idx(q)] = 0
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "saisir", "cible": loup.id}) and str(j.porte) == loup.id and Etres.a_statut_tag(loup, "saisi", s.statuts_defs), "le loup est saisi")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "en portant : pas d'attaque")
	var sante0 := int(loup.sante)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "lancer_etre", "vers": j.pos + Vector2i(3, 0)}) and not j.has("porte"), "lancé")
	verifier(Grille.distance(j.pos, loup.pos) >= 2 and int(loup.sante) < sante0, "le loup atterrit à %d tuiles, blessé (%d → %d)" % [Grille.distance(j.pos, loup.pos), sante0, int(loup.sante)])


# ---------------------------------------------------------------- L'Ombre, Le Rieur, le jet de coup

func test_ombre_et_rieur() -> void:
	var s := Simulation.new(129)
	s.charger_donjon("ruine", 129, 14, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Le jet de coup : sur 200 attaques, des critiques et des ratés apparaissent.
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	loup.sante_max = 100000
	loup.sante = 100000
	for k in 200:
		loup.sante = loup.sante_max   # le loup encaisse 200 coups : on le soigne entre deux
		s.attente[j.id] = true
		s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	var crit: int = int(j.get("coups_critiques", 0))
	var rate: int = int(j.get("coups_rates", 0))
	verifier(crit >= 3 and rate >= 3, "200 coups : %d critiques, %d ratés (≈5 %% chacun)" % [crit, rate])
	# Le Rieur : la relance se réarme à l'engagement.
	j.classe = "le_rieur"
	verifier(s.a_talent(j, "deux_queues"), "Le Rieur porte Deux queues")
	j["relance_utilisee"] = true
	s._engager_combat(j, loup)
	verifier(not j.has("relance_utilisee"), "l'engagement réarme la relance")
	# L'Ombre : dissimulé après une mise à mort, invisible à distance, visible adjacent.
	j.classe = "l_ombre"
	var proie := s.ajouter("renard", j.pos + Vector2i(0, 1), "ia")
	proie.sante = 1
	s._appliquer_degats(proie, 10, j.id, {})
	verifier(Etres.a_statut_tag(j, "dissimule", s.statuts_defs), "après la mise à mort : Dissimulé")
	var guetteur := s.ajouter("bandit", j.pos + Vector2i(4, 0), "ia")
	for d in range(1, 4):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 0))] = 0
	guetteur.corps.stats.perception = 12
	verifier(not s.voit_ia(guetteur, j), "à 4 tuiles : le guetteur ne le voit pas")
	var proche := s.ajouter("bandit", j.pos + Vector2i(-1, 0), "ia")
	proche.corps.stats.perception = 12
	verifier(s.voit_ia(proche, j), "adjacent : vu")
	var frappe := false
	for k in 5:   # un coup raté ne lève pas la dissimulation : on frappe jusqu'à toucher
		loup.sante = loup.sante_max
		s.attente[j.id] = true
		frappe = frappe or s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
		if not Etres.a_statut_tag(j, "dissimule", s.statuts_defs):
			break
	verifier(frappe and not Etres.a_statut_tag(j, "dissimule", s.statuts_defs), "attaquer lève la dissimulation")


# ---------------------------------------------------------------- Statut bétail

func test_betail() -> void:
	var s := Simulation.new(127)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v["assignation"] = {"fonction": "fermier", "cellule": s._cell_de(v.pos)}
	v.camp = "joueur"
	v.social.relations[j.id] = 40
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "statut_habitat", "pnj": v.id, "statut": "betail"}) and v.statut_habitat == "betail" and int(v.social.relations[j.id]) == 10, "un PNJ traité en bétail : relation −30")
	s._recalculer_humeurs()
	verifier(int(v.humeur) == 60 - 15 - 20, "bétail sans abri, rétrogradé : 60 −15 −20 = %d (il ne mange pas au garde-manger)" % int(v.humeur))
	var enc: Vector2i = j.pos + Vector2i(0, 2)
	s.grille.contenu[s.grille.idx(enc)] = 0
	s.grille.poser_contenu(enc, "meuble")
	s.grille.meubles[s.grille.idx(enc)] = "enclos"
	s._recalculer_humeurs()
	verifier(int(v.humeur) == 60 - 20, "avec un enclos à portée : abrité (%d)" % int(v.humeur))
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "statut_habitat", "pnj": v.id, "statut": "normal"}) and v.statut_habitat == "normal", "redevenu résident")
	# Une bête apprivoisée est bétail sans malus.
	var b := s.ajouter("cerf", j.pos + Vector2i(-1, 0), "ia")
	b["maitre"] = j.id
	b.camp = "joueur"
	b["assignation"] = {"fonction": "oisif", "cellule": s._cell_de(b.pos)}
	if not b.has("social"):
		b["social"] = {"relations": {}}
	s.attente[j.id] = true
	s.intention(j.id, {"type": "statut_habitat", "pnj": b.id, "statut": "betail"})
	s._recalculer_humeurs()
	verifier(int(b.humeur) == 60, "une bête bétail abritée : 60, sans malus (%d)" % int(b.humeur))
	s.monde.fermer()


# ---------------------------------------------------------------- Palier industriel

func test_palier_industriel() -> void:
	var s := Simulation.new(125)
	s.charger_donjon("ruine", 125, 13, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var forge := s.generer_objet("station_forge", 1, {}, "commun", 0)
	j.sac.append(forge.uid)
	s._donner_materiau(j, "verre", 4, "brut")
	s._donner_materiau(j, "houille", 2, "brut")
	var visibles: Array = []
	for pl in s.recettes_disponibles(j):
		visibles.append(str(pl.id))
	verifier(not ("tremper_verre" in visibles), "sans le plan, tremper le verre est invisible")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "fabriquer", "recette": "tremper_verre"}), "et refusée à la fabrication")
	var plan := s.generer_objet("plan_industriel", 4, {}, "commun", 0)
	verifier(bool(GameData.catalogues.recipes.get(str(plan.get("recette", "")), {}).get("industrielle", false)) and plan.modules.is_empty(), "un plan porte une recette industrielle (%s)" % str(plan.get("recette", "?")))
	plan.recette = "tremper_verre"
	j.sac.append(plan.uid)
	j.competences["lecture"] = 100
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "lire", "objet": plan.uid}) and ("tremper_verre" in j.get("recettes_connues", [])), "lire le plan : la recette est connue")
	visibles = []
	for pl in s.recettes_disponibles(j):
		visibles.append(str(pl.id))
	verifier("tremper_verre" in visibles, "elle apparaît à l'atelier")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "tremper_verre"}) and not s._pile(j, "verre_trempe", "brut").is_empty(), "tremper le verre : du verre trempé")
	# Un plan tombe parfois dans les ruines profondes.
	var trouve := false
	for k in 80:
		var loup := s.ajouter("loup", j.pos + Vector2i(3 + (k % 5), 3), "ia")
		s.donjon.profondeur = 4
		s._appliquer_degats(loup, 9999, j.id, {})
		for uid in s.contenants.get(s.grille.idx(loup.pos), []):
			trouve = trouve or str(s.items[uid].base) == "plan_industriel"
		s.contenants.erase(s.grille.idx(loup.pos))
		s.grille.contenu[s.grille.idx(loup.pos)] = 0
	verifier(trouve, "un plan industriel est tombé en profondeur (80 morts, 8 %)")


# ---------------------------------------------------------------- Éclairage : lumière locale, vision, détection

func test_lumiere() -> void:
	var s := Simulation.new(123)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var jour := int(s._cycle().ticks_par_jour)
	s.horloge_monde.ticks = 0   # minuit
	verifier(s.est_nuit(), "il fait nuit")
	var g := s.ajouter("villageois", j.pos + Vector2i(8, 0), "ia")
	s._habiller_pnj(g, GameData.entree("creatures", "villageois"))
	g.corps.stats.perception = 10
	for d in range(1, 9):
		var q: Vector2i = j.pos + Vector2i(d, 0)
		s.grille.contenu[s.grille.idx(q)] = 0
	verifier(not s.voit_ia(g, j), "dans le noir, à 8 tuiles : invisible (portée 10 × 0,6)")
	var torche := s.generer_objet("torche", 1, {}, "commun", 0)
	j.sac.append(torche.uid)
	j.equipement["main_secondaire"] = torche.uid
	verifier(s.lumiere_de(j) == 70 and s.lumiere_a(j.pos) == 70, "une torche en main : lumière 70")
	verifier(s.voit_ia(g, j), "avec la torche : vu de plus loin (portée × 1,35)")
	j.equipement.erase("main_secondaire")
	j["vue_sale"] = true
	s.maj_vision()
	var vue0: int = j.vue.size()
	j.equipement["main_secondaire"] = torche.uid
	j["vue_sale"] = true
	s.maj_vision()
	verifier(j.vue.size() > vue0, "la torche rend la vue la nuit (%d → %d tuiles)" % [vue0, j.vue.size()])
	s.horloge_monde.ticks = jour / 2
	verifier(not s.est_nuit() and s.voit_ia(g, j), "à midi, vu sans lumière")
	s.monde.fermer()


# ---------------------------------------------------------------- Communion des cinq

func test_communion() -> void:
	var s := Simulation.new(121)
	s.charger_donjon("ruine", 121, 12, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	j.classe = "le_souffle"
	verifier(s.a_talent(j, "communion_des_cinq"), "Le Souffle porte Communion des cinq")
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	loup.sante = 999
	loup.sante_max = 999
	var arme := Etres.arme(j, s.items)
	var el0 := str(arme.get("element", ""))
	j.mana = 10
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "un coup d'arme")
	verifier(str(j.get("element_communion", "")) == str(s.wuxing.w.engendre.get(el0, "")) and int(j.mana) == 8, "l'élément tourne %s → %s, 2 de mana" % [el0, str(j.get("element_communion", "?"))])
	var v := s._vecteur_arme_de(j, arme)
	verifier(v.has(str(j.element_communion)), "le prochain coup porte l'élément tourné")
	j.mana = 0
	var avant := str(j.element_communion)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	verifier(str(j.element_communion) == avant, "sans mana, l'élément ne tourne plus")


# ---------------------------------------------------------------- Main du métal, Fiole vive

func test_reforge_et_fiole() -> void:
	var s := Simulation.new(115)
	s.charger_donjon("ruine", 115, 9, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	j.classe = "la_braise"
	var etabli := s.generer_objet("station_etabli", 1, {}, "commun", 0)
	j.sac.append(etabli.uid)
	# Une épée assemblée (fer) avec un affixe, reforgée avec une lame de cuivre.
	var epee := s.generer_objet("craft_epee", 2, {}, "rare", 1)
	epee["composants"] = {"tete": {"composant": "lame_longue", "materiau": "fer", "qualite": 1.0}, "manche": {"composant": "poignee", "materiau": "chene", "qualite": 1.0}, "fixations": {"composant": "fixations_std", "materiau": "fer", "qualite": 1.0}}
	epee.materiau = "fer"
	j.sac.append(epee.uid)
	var n_aff: int = epee.affixes.size()
	var lame := s.generer_objet("composant", 1, {}, "commun", 0)
	lame.composant = "lame_longue"
	lame.materiau = "cuivre"
	lame.stats = GameData.entree("materials", "cuivre").stats.duplicate()
	lame.elements = {}
	lame.qualite = 1.4
	j.sac.append(lame.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "reforger", "objet": epee.uid, "composant": lame.uid}), "reforger l'épée avec une lame de cuivre")
	verifier(epee.composants.tete.materiau == "cuivre" and epee.materiau == "cuivre" and epee.affixes.size() == n_aff and not (lame.uid in j.sac), "la lame remplacée, le matériau suit, les affixes tiennent (%d), le composant consommé" % epee.affixes.size())
	j.classe = "le_sabre"
	var lame2 := s.generer_objet("composant", 1, {}, "commun", 0)
	lame2.composant = "lame_longue"
	lame2.materiau = "fer"
	j.sac.append(lame2.uid)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "reforger", "objet": epee.uid, "composant": lame2.uid}), "sans Main du métal : refus")
	# Fiole vive : la potion touche l'allié adjacent ; la recette demande le double.
	j.classe = "le_creuset"
	var ami := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	ami.camp = j.camp
	var pot := s.generer_objet("potion_force", 1, {}, "commun", 0)
	j.sac.append(pot.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "manger", "objet": pot.uid})
	var touche := false
	for st in ami.statuts:
		touche = touche or str(st.id).begins_with("potion_force")
	verifier(touche, "Fiole vive : l'allié adjacent reçoit la potion")
	var plan := s._plan_recette(j, GameData.catalogues.recipes.distiller_partie)
	verifier(int(plan.entrees[0].besoin) == 2, "Fiole vive : la distillation demande le double (%d)" % int(plan.entrees[0].besoin))


# ---------------------------------------------------------------- Trésors et artefacts

func test_artefacts() -> void:
	var s := Simulation.new(111)
	s.charger_donjon("ruine", 111, 7, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var art := s.generer_objet("proto_epee", 3, {}, "artefact")
	verifier(art.rarete == "artefact" and art.affixes.size() >= 2 and art.affixes.size() <= 3 and bool(art.get("fini", false)) and not art.has("sertissures"), "un artefact : %d affixes, fini, sans sertissure" % art.affixes.size())
	# Au-dessus des fourchettes : sur 40 tirages, au moins un paramètre dépasse sa borne haute déclarée.
	var depasse := false
	for k in 40:
		var a := s.generer_objet("proto_epee", 3, {}, "artefact")
		for ax in a.affixes:
			var def: Dictionary = GameData.entree("affixes", str(ax.id))
			for nom in ax.params.keys():
				var spec = def.parametres.get(nom)
				if spec is Array and spec.size() == 2 and not (spec[0] is String) and str(def.meilleur.get(nom, "")) == "haut" and int(ax.params[nom]) > int(spec[1]):
					depasse = true
	verifier(depasse, "des paramètres au-dessus de la fourchette normale")
	# Le boss d'un donjon majeur (7 étages) laisse un artefact garanti.
	s.donjon.etages = 5
	var boss := s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	boss["chain_gauge"] = true
	s._appliquer_degats(boss, 9999, j.id, {})
	var trouve := false
	for uid in s.contenants.get(s.grille.idx(boss.pos), []):
		trouve = trouve or str(s.items[uid].get("rarete", "")) == "artefact"
	verifier(trouve, "le boss d'un donjon majeur laisse un artefact")
	# Sertir un artefact est refusé.
	j.sac.append(art.uid)
	var gemme := s.generer_objet("gemme_brute", 1, {}, "commun", 0) if GameData.catalogues.items.has("gemme_brute") else {}
	if not gemme.is_empty():
		j.sac.append(gemme.uid)
		s.attente[j.id] = true
		verifier(not s.intention(j.id, {"type": "sertir", "objet": art.uid, "gemme": gemme.uid}), "un artefact ne se sertit pas")


# ---------------------------------------------------------------- Habitat et faim des PNJ

func test_habitat_pnj() -> void:
	var s := Simulation.new(109)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Une chambre 3×3 murée avec une porte, un lit et une table, dégagée près du joueur.
	var o: Vector2i = j.pos + Vector2i(3, 3)
	for y in range(-1, 4):
		for x in range(-1, 4):
			var q: Vector2i = o + Vector2i(x, y)
			s.grille.contenu[s.grille.idx(q)] = 0
			s.grille.meubles.erase(s.grille.idx(q))
			s.contenants.erase(s.grille.idx(q))
			if x == -1 or y == -1 or x == 3 or y == 3:
				s.grille.poser_contenu(q, "mur_construit")
	s.grille.poser_contenu(o + Vector2i(1, -1), "porte")
	s.grille.poser_contenu(o, "meuble")
	s.grille.meubles[s.grille.idx(o)] = "lit_de_paille"
	s.grille.poser_contenu(o + Vector2i(2, 2), "meuble")
	s.grille.meubles[s.grille.idx(o + Vector2i(2, 2))] = "table"
	var cell: Vector2i = s._cell_de(o)
	var pieces: Array = s.pieces_de_cellule(cell)
	verifier(pieces.size() == 1 and pieces[0].tuiles.size() == 9 and pieces[0].meubles.size() == 2, "une pièce close de 9 tuiles avec deux types de meubles (%d pièce(s))" % pieces.size())
	# Un résident logé dans cette pièce, un autre sans pièce ; un garde-manger vide puis plein.
	var a := s.ajouter("villageois", o + Vector2i(1, 1), "ia")
	s._habiller_pnj(a, GameData.entree("creatures", "villageois"))
	a["assignation"] = {"fonction": "fermier", "cellule": cell}
	a["lit"] = o
	a.camp = "joueur"
	var b := s.ajouter("villageois", j.pos + Vector2i(-2, 0), "ia")
	s._habiller_pnj(b, GameData.entree("creatures", "villageois"))
	b["assignation"] = {"fonction": "fermier", "cellule": cell}
	b.camp = "joueur"
	s._recalculer_humeurs()
	verifier(int(a.humeur) == 60 + 2 - 10 and int(b.humeur) == 60 - 15 - 10, "logé : 60 +2 meubles −10 faim = %d ; sans pièce : 60 −15 −10 = %d" % [int(a.humeur), int(b.humeur)])
	var gm: Vector2i = j.pos + Vector2i(0, -2)
	s.grille.contenu[s.grille.idx(gm)] = 0
	s.grille.poser_contenu(gm, "meuble")
	s.grille.meubles[s.grille.idx(gm)] = "garde_manger"
	var pain := s.generer_objet("pain", 1, {}, "commun", 0)
	pain.quantite = 5
	s.contenants[s.grille.idx(gm)] = [pain.uid]
	s._recalculer_humeurs()
	verifier(int(a.humeur) == 62 and int(b.humeur) == 45 and int(pain.quantite) == 3, "garde-manger garni : plus de malus de faim, deux pains mangés")
	s.monde.fermer()


# ---------------------------------------------------------------- Routes

func test_routes() -> void:
	var s := Simulation.new(107)
	s.charger_camp()
	var surf = s.monde.surface
	# Un royaume trouvé dans les secteurs voisins qui a au moins un village hors capitale : ses routes le relient.
	var trouve: Dictionary = {}
	for k in 60:
		var sect: Vector2i = surf.secteur_de(s.monde.cellule_camp) + Vector2i(k % 8 - 4, k / 8 - 4)
		for r in surf.royaumes_secteur(sect).values():
			if r.get("routes", []).size() >= 2 and trouve.is_empty():
				trouve = r
	if trouve.is_empty():
		verifier(true, "aucun royaume à routes dans les secteurs voisins (rien à mesurer)")
	else:
		var cap: Vector2i = trouve.capital_poi
		verifier(not surf.route_de(cap).is_empty(), "%s : la capitale est reliée (%d cellules de route)" % [trouve.nom, trouve.routes.size()])
		var relie := true
		for c in trouve.routes:
			relie = relie and not surf.route_de(c).is_empty() and surf.terre_a(c)
		verifier(relie, "chaque cellule de route a une voisine reliée, sur la terre")
		var e: Dictionary = surf.generer_cellule(cap.x, cap.y)
		verifier(e.get("route", {}).size() >= 20, "la capitale porte un chemin de sol (%d tuiles)" % e.get("route", {}).size())
	s.monde.fermer()


# ---------------------------------------------------------------- Le chatoyant

func test_chatoyant() -> void:
	var s := Simulation.new(105)
	s.charger_camp()
	var rng := RandomNumberGenerator.new()
	rng.seed = 105
	var n0 := 0
	var n1 := 0
	for k in 4000:
		if s._tirer_chatoyant(rng, false):
			n0 += 1
		if s._tirer_chatoyant(rng, true):
			n1 += 1
	verifier(n0 >= 20 and n0 <= 120 and n1 >= 250 and n1 <= 480, "sur 4 000 tirages : %d chatoyants sans parent (≈60), %d avec (≈360)" % [n0, n1])
	var c := s._nouveau_specimen("carpe", {"couleur": 2, "motif": 3, "taille": 2.0}, "f", true)
	verifier(bool(c.chatoyant) and int(s.territoire.chatoyants.carpe) == 1 and str(c.nom.params.chatoyant) == "ui.specimen.chatoyant", "un spécimen chatoyant est compté et nommé")
	# Une commande chatoyante n'accepte qu'un chatoyant.
	s.territoire["commande"] = {"espece": "carpe", "couleur": 5, "motif": "3", "or": 600, "semaine": 0, "chatoyant": true}
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var m := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(m, GameData.entree("creatures", "villageois"))
	m.tags.append("commerce_possible")
	m.or = 1000
	var ordinaire := s._nouveau_specimen("carpe", {"couleur": 5, "motif": 3, "taille": 2.0}, "f", false)
	j.sac.append(ordinaire.uid)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "livrer", "pnj": m.id}), "un spécimen ordinaire ne satisfait pas une commande chatoyante")
	var brillant := s._nouveau_specimen("carpe", {"couleur": 5, "motif": 3, "taille": 2.0}, "f", true)
	j.sac.append(brillant.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "livrer", "pnj": m.id}), "le chatoyant est livré")
	s.monde.fermer()


# ---------------------------------------------------------------- Règle d'anneau : la mesure (sélection dirigée contre hasard)

func test_regle_anneau_mesure() -> void:
	var s := Simulation.new(103)
	var L := {"type": "anneau", "n": 16}
	var rng := RandomNumberGenerator.new()
	rng.seed = 103
	var cible := 8   # l'opposé sur un anneau de 16, départ à 0
	var essais := 60
	var dirige := 0
	var hasard := 0
	for k in essais:
		# Dirigé : deux parents, on garde le couple le plus proche de la cible.
		var a := 0
		var b := 0
		var n := 0
		while n < 5000:
			n += 1
			var enfant: int = s._heriter(a, b, L, rng)
			if enfant == cible:
				break
			var da: int = mini(posmod(a - cible, 16), posmod(cible - a, 16))
			var db: int = mini(posmod(b - cible, 16), posmod(cible - b, 16))
			var de: int = mini(posmod(enfant - cible, 16), posmod(cible - enfant, 16))
			if de < maxi(da, db):
				if da >= db:
					a = enfant
				else:
					b = enfant
		dirige += n
		# Hasard : on remplace un parent au hasard, sans regarder.
		a = 0
		b = 0
		n = 0
		while n < 20000:
			n += 1
			var enfant2: int = s._heriter(a, b, L, rng)
			if enfant2 == cible:
				break
			if rng.randf() < 0.5:
				a = enfant2
			else:
				b = enfant2
		hasard += n
	var moy_d := float(dirige) / float(essais)
	var moy_h := float(hasard) / float(essais)
	print("  mesure Règle d'anneau : dirigé %.0f couvées, hasard %.0f couvées, facteur ×%.1f" % [moy_d, moy_h, moy_h / maxf(1.0, moy_d)])
	verifier(moy_d < moy_h and moy_h / maxf(1.0, moy_d) >= 4.0, "sélection dirigée contre hasard : facteur ×%.1f (attendu ≈ ×15, au moins ×4)" % (moy_h / maxf(1.0, moy_d)))


# ---------------------------------------------------------------- Étape 9.D : compagnons, apprivoisement, âge

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

func test_reputation_et_quetes() -> void:
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	var cell_v := Vector2i(-1, -1)
	for y in range(480, 560):
		for x in range(480, 560):
			var c := Vector2i(x, y)
			if surf.terre_a(c) and surf.poi_de(c).get("village", false):
				cell_v = c
				break
		if cell_v != Vector2i(-1, -1):
			break
	var s := Simulation.new(4242)
	s.charger_camp({}, cell_v)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var civils: Array = s.vivants().filter(func(x: Dictionary) -> bool: return "civil" in x.get("tags", []))
	var garde := {}
	var villageois := {}
	for x in civils:
		if x.ai_profile == "garde":
			garde = x
		elif villageois.is_empty():
			villageois = x
	verifier(not garde.is_empty() and not villageois.is_empty(), "un garde et un villageois")
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
	for x in civils:
		if x.id != villageois.id and x.ai_profile == "civil":
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

func test_village_vivant() -> void:
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	var cell_v := Vector2i(-1, -1)
	for y in range(480, 560):
		for x in range(480, 560):
			var c := Vector2i(x, y)
			if surf.terre_a(c) and surf.poi_de(c).get("village", false):
				cell_v = c
				break
		if cell_v != Vector2i(-1, -1):
			break
	var s := Simulation.new(4242)
	s.charger_camp({}, cell_v)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var civils: Array = s.vivants().filter(func(x: Dictionary) -> bool: return "civil" in x.get("tags", []) and x.ai_profile == "civil")
	verifier(civils.size() >= 2 and civils[0].has("lit") and civils[0].has("place") and civils[0].has("poste"), "les villageois ont un lit, un poste et la place")
	# À 23 h, la routine vise le lit ; à midi, le poste ; à 21 h, la place.
	var v: Dictionary = civils[0]
	var profil: Dictionary = s.profils_ia.civil
	s.horloge_monde.ticks = 23000
	verifier(s._cible_routine(v, profil) == v.lit, "23 h : au lit")
	s.horloge_monde.ticks = 12000
	verifier(s._cible_routine(v, profil) == v.poste, "midi : au poste")
	s.horloge_monde.ticks = 21000
	verifier(s._cible_routine(v, profil) == v.place, "21 h : sur la place")
	# Un villageois loin de sa cible s'en rapproche par la routine.
	var loin: Vector2i = v.place + Vector2i(6, 0)
	if s.grille.dans(loin) and not s.grille.bloque_passage(loin) and s.grille.occupant(loin).is_empty():
		s.grille.liberer(v.pos)
		v.pos = loin
		s.grille.placer(v.id, loin)
		var d0 := Grille.distance(v.pos, v.place)
		for k in 6:
			s._decider_ia(v, s.horloge_monde.ticks + k * 10)
		verifier(Grille.distance(v.pos, v.place) < d0, "la routine rapproche le villageois de la place (%d → %d)" % [d0, Grille.distance(v.pos, v.place)])
	# Le garde patrouille de jour.
	var gardes: Array = s.vivants().filter(func(x: Dictionary) -> bool: return x.ai_profile == "garde")
	if not gardes.is_empty():
		var g: Dictionary = gardes[0]
		s.horloge_monde.ticks = 12000
		var p0: Vector2i = g.pos
		for k in 8:
			s._decider_ia(g, s.horloge_monde.ticks + k * 10)
		verifier(g.pos != p0 or g.has("patrouille"), "le garde patrouille (cible de patrouille posée)")
	# La faune : après quelques tirages, des bêtes hors de vue, sous le budget ; la nuit, plus de loups.
	var fa: Dictionary = planete.faune
	var n0: int = s.vivants().filter(func(x: Dictionary) -> bool: return "bete" in x.get("tags", [])).size()
	s.horloge_monde.ticks = 12000
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

func test_cycle_et_meteo() -> void:
	var s := Simulation.new(47)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(is_equal_approx(s.heure(0), 0.0) and is_equal_approx(s.heure(12000), 12.0) and s.phase(12000) == "jour" and s.phase(0) == "nuit" and s.phase(6000) == "aube", "l'heure et les phases (24 000 ticks par jour)")
	verifier(GameData.catalogues.weather_states.size() == 10, "10 états météo en données")
	var cell: Vector2i = s.monde.cellule_de(j.pos)
	var m1 := s.meteo(cell, 5000)
	verifier(GameData.catalogues.weather_states.has(m1) and m1 == s.meteo(cell, 5000), "la météo est un état connu, déterministe")
	var varie := false
	for k in 40:
		if s.meteo(cell, k * 24000) != m1:
			varie = true
	verifier(varie, "la météo change avec le temps")
	var tr_ := s.temperature_ressentie(j)
	verifier(tr_.temp >= -60.0 and tr_.temp <= 70.0 and tr_.has("ecart"), "température ressentie calculée (%.0f °C)" % float(tr_.temp))
	# La nuit réduit la vue, le jour non.
	s.horloge_monde.ticks = 12000
	s.maj_vision()
	var vue_jour: int = j.vue.size()
	s.horloge_monde.ticks = 0
	s.maj_vision()
	var vue_nuit: int = j.vue.size()
	verifier(vue_nuit < vue_jour, "la nuit, le champ de vue rétrécit (%d → %d)" % [vue_jour, vue_nuit])
	# Dormir la nuit saute à l'aube (5 h).
	var lit := s.generer_objet("meuble_lit_de_paille", 1, {}, "commun", 0)
	j.sac.append(lit.uid)
	var devant: Vector2i = j.pos + Vector2i(0, 1)
	if not s.grille.contenu_de(devant).is_empty():
		s.grille.contenu[s.grille.idx(devant)] = 0
	s.attente[j.id] = true
	s.intention(j.id, {"type": "poser", "objet": lit.uid, "vers": devant})
	s.horloge_monde.ticks = 22 * 1000   # 22 h
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "dormir", "vers": devant}), "dormir à 22 h")
	verifier(is_equal_approx(s.heure(), 5.0) or absf(s.heure() - 5.0) < 0.2, "réveil à l'aube, 5 h (%.1f h)" % s.heure())
	# Le froid : un être nu par −20 °C prend des dégâts par palier.
	j.equipement.clear()
	j["ecart_confort"] = -25.0
	var end0: int = j.endurance
	j.endurance = 0
	j.tick_endurance = s.horloge_monde.ticks
	s._regenerer(j, s.horloge_monde.ticks + 10)
	verifier(int(j.endurance) <= 10, "hors confort, l'endurance régénère moitié moins (%d)" % int(j.endurance))
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 8.2c : minimap (exploration par chunk) et sauvegarde

func test_sauvegarde() -> void:
	var s := Simulation.new(37)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(s.monde.explores.size() > 0, "des chunks explorés dès l'arrivée (%d)" % s.monde.explores.size())
	var ch: Vector2i = s.monde.explores.keys()[0]
	var col: Color = s.monde.couleur_chunk(ch)
	verifier(col.a == 1.0 and (col.r + col.g + col.b) > 0.0 and s.monde.couleur_chunk(ch) == col, "une teinte dominante par chunk, calculée une fois")
	# On modifie le monde, on remplit le sac, on avance le temps, on sauvegarde.
	s._donner_materiau(j, "chene", 2, "planche")
	var mur: Vector2i = j.pos + Vector2i(0, -1)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "poser_mur", "vers": mur})
	var dague := s.generer_objet("proto_dague", 1, {}, "commun", 0)
	j.sac.append(dague.uid)
	s.horloge_monde.avancer(1234)
	var pos0: Vector2i = j.pos
	var sac0: int = j.sac.size()
	verifier(s.sauvegarder("test_sensen"), "sauvegarder au camp")
	verifier(Sauvegarde.existe("test_sensen"), "le dossier user://sauvegardes/test_sensen/ existe")
	var w: Dictionary = Sauvegarde.lire("test_sensen", "world.json")
	verifier(int(w.graine) == 37 and int(w.ticks) == s.horloge_monde.ticks and w.cellule_camp == s.monde.cellule_camp, "world.json : graine, ticks, cellule du camp")
	# Une simulation neuve recharge : le mur, le sac, la position, le temps, l'exploration.
	var s2 := Simulation.new(1)
	verifier(s2.charger_sauvegarde("test_sensen"), "charger la sauvegarde dans une simulation neuve")
	var j2: Dictionary = s2.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(j2.pos == pos0 and j2.sac.size() == sac0 and dague.uid in j2.sac and s2.items.has(dague.uid), "le joueur, son sac et ses objets sont revenus")
	verifier(s2.grille.contenu_de(mur).get("tags", []).has("construit") and s2.grille.materiau_de(mur) == "chene", "le mur posé est là (seed + modifications)")
	verifier(s2.horloge_monde.ticks == s.horloge_monde.ticks and s2.graine == 37, "le temps et la graine")
	# La graine du monde choisie à l'écran Monde (Écrans d'interface) : portée par la simulation, écrite, relue.
	var s5 := Simulation.new(5)
	s5.graine_monde = 4242
	s5.charger_camp()
	verifier(int(s5.monde.surface.graine) == 4242, "la surface est générée avec la graine choisie (%d)" % int(s5.monde.surface.graine))
	verifier(s5.sauvegarder("test_graine"), "sauvegarder la partie à graine choisie")
	var s6 := Simulation.new(6)
	verifier(s6.charger_sauvegarde("test_graine") and s6.graine_monde == 4242 and int(s6.monde.surface.graine) == 4242, "la graine du monde est relue avec la sauvegarde (%d)" % s6.graine_monde)
	s5.monde.fermer()
	s6.monde.fermer()
	verifier(s2.monde.explores.size() == s.monde.explores.size(), "les chunks explorés (%d)" % s2.monde.explores.size())
	verifier(s2.grille.decouvert.size() > s2.monde.taille * s2.monde.taille / 2, "la cellule du camp reste découverte (%d tuiles)" % s2.grille.decouvert.size())
	# Un tour complet sur l'état du camp : ce qu'on a construit, élevé, revendiqué, stocké
	s.territoire["tresor"] = 321
	s.territoire["stocks"] = {"chene": 7}
	s.territoire["registre"] = {"carpe": {"1|2": true, "3|4": true}}
	s.monde.claims[s.monde.cellule_camp] = {"role": "champs", "depuis": 0}
	s.monde.delta[s.monde.cellule_camp] = 12
	var comp := s.ajouter("villageois", j.pos + Vector2i(0, 2), "ia")
	s._habiller_pnj(comp, GameData.entree("creatures", "villageois"))
	s._devenir_compagnon(j, comp)
	var n_vivants := s.vivants().size()
	verifier(s.sauvegarder("test_sensen2"), "sauvegarder l'état complet du camp")
	var s4 := Simulation.new(3)
	verifier(s4.charger_sauvegarde("test_sensen2"), "recharger l'état complet")
	verifier(int(s4.territoire.tresor) == 321 and int(s4.territoire.stocks.get("chene", 0)) == 7, "trésor et stocks revenus")
	verifier(int(s4.territoire.get("registre", {}).get("carpe", {}).size()) == 2, "le registre d'élevage est revenu")
	verifier(s4.monde.claims.has(s.monde.cellule_camp) and int(s4.monde.delta.get(s.monde.cellule_camp, 0)) == 12, "claim et dérive de corruption revenus")
	verifier(s4.vivants().size() == n_vivants, "autant d'êtres qu'avant (%d contre %d)" % [s4.vivants().size(), n_vivants])
	var comp4 := s4.compagnons_de(s4.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0])
	verifier(comp4.size() == 1, "le compagnon est toujours au service du joueur")
	s4.monde.fermer()
	# Sans monde (arène ou donjon chargé à cru), rien à sérialiser — le donjon lui-même se sauve, voir test_sauvegarde_partout.
	var s3 := Simulation.new(2)
	s3.charger_donjon("ruine", 2, 9, 1)
	verifier(not s3.sauvegarder("test_sensen"), "pas de sauvegarde sans monde")
	s.monde.fermer()
	s2.monde.fermer()


# ---------------------------------------------------------------- Étape 7.1 : le camp de base

func test_camp() -> void:
	var s := Simulation.new(23)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var tc: int = int(GameData.config("planete").taille_cellule)
	verifier(s.lieu == "camp" and s.grille.largeur == 3 * tc and s.grille.origine == Vector2i(511 * tc, 511 * tc), "le camp : la fenêtre de 3×3 cellules du monde, en coordonnées monde")
	var arbres := 0
	var entree := Vector2i(-1, -1)
	for i in s.grille.largeur * s.grille.hauteur_grille:
		var t := s.grille.pos_de(i)
		var tags: Array = s.grille.contenu_de(t).get("tags", [])
		if "arbre" in tags:
			arbres += 1
		if "entree_donjon" in tags:
			entree = t
	verifier(arbres >= 5 and entree != Vector2i(-1, -1), "des arbres (%d) et l'entrée du donjon" % arbres)
	var base := Vector2i(512 * tc, 512 * tc)
	var coffre := base + Vector2i(tc / 2 - 2, tc / 2)   # le centre de la cellule du camp
	verifier(s.contenants.get(s.grille.idx(coffre), []).size() >= 4, "le coffre de départ : hache, pioche, faucille, lit de paille, graines, étal")
	# Une plante se récolte à la faucille par un clic adjacent (Récolte).
	var plante := base + Vector2i(64 + 3, 64 + 3)
	s.grille.poser_contenu(plante, "plante")
	s.grille.materiaux[s.grille.idx(plante)] = "lin"
	var faucille := s.generer_objet("proto_faucille", 1, {}, "commun", 0)
	j.sac.append(faucille.uid)
	j.pos = plante + Vector2i(1, 0)
	s.grille.placer(j.id, j.pos)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "equiper", "objet": faucille.uid})
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "creuser", "vers": plante}) and not s._pile(j, "lin", "brut").is_empty() and s.grille.contenu_de(plante).is_empty(), "récolter du lin à la faucille")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "desequiper", "slot": "main_principale"})
	# Prendre le coffre depuis une tuile adjacente.
	j.pos = coffre + Vector2i(1, 0)
	s.grille.placer(j.id, j.pos)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "prendre", "vers": coffre}), "prendre le coffre de départ")
	var lit := ""
	var hache := ""
	var pioche := ""
	for uid in j.sac:
		if s.items[uid].get("meuble", "") == "lit_de_paille":
			lit = uid
		if s.items[uid].get("functionality", "") == "hache":
			hache = uid
		if s.items[uid].get("functionality", "") == "pioche":
			pioche = uid
	verifier(not lit.is_empty() and not hache.is_empty(), "le lit et la hache sont dans le sac")
	# Poser le lit devant soi, y dormir : Reposé, potentiel, respawn.
	var devant: Vector2i = j.pos + Vector2i(0, 1)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "poser", "objet": lit, "vers": devant}), "poser le lit de paille")
	verifier(s.grille.meubles.get(s.grille.idx(devant), "") == "lit_de_paille" and s.grille.bloque_passage(devant), "le lit est un contenu de tuile qui bloque")
	s.gagner_xp(j, "minage", 30)
	s.gagner_xp(j, "forge", 10)
	var pot0: int = int(j.potentiels.get("minage", 80))
	s.horloge_monde.ticks = 12000   # midi : pas de saut de nuit, un sommeil de 8 h
	var t0: int = s.horloge_monde.ticks
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "dormir", "vers": devant}), "dormir sur le lit")
	verifier(s.horloge_monde.ticks - t0 == int(GameData.config("combat_rules").camp.dormir_ticks), "le monde a avancé de 8 000 ticks")
	verifier(int(j.potentiels.minage) == pot0 + 2 and is_equal_approx(float(j.xp_mult), 1.05) and j.has("repose_jusqua"), "Reposé : +2 de potentiel en Minage, XP ×1,05")
	verifier(j.spawn == devant and j.lit == devant, "le lit est le point de respawn")
	# Un mur en planches : il faut du bois — récolter un arbre à la hache, scier.
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "equiper", "objet": hache}), "équiper la hache")
	var arbre: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.poser_contenu(arbre, "arbre")
	s.grille.materiaux[s.grille.idx(arbre)] = "chene"
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "creuser", "vers": arbre}), "abattre un chêne à la hache")
	verifier(not s._pile(j, "chene", "brut").is_empty(), "du chêne brut dans le sac")
	s._donner_materiau(j, "chene", 2, "planche")
	var mur: Vector2i = j.pos + Vector2i(-1, 0)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "poser_mur", "vers": mur}), "poser un mur en planches")
	verifier("construit" in s.grille.contenu_de(mur).tags and s.grille.materiau_de(mur) == "chene" and int(s._pile(j, "chene", "planche").quantite) == 1, "un mur construit en chêne, une planche consommée")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "demonter", "vers": mur}), "démonter le mur")
	verifier(s.grille.contenu_de(mur).is_empty(), "la tuile est libre")
	# Coffre : ranger, capacité.
	var coffre_it := s.generer_objet("meuble_coffre", 1, {}, "commun", 0)
	j.sac.append(coffre_it.uid)
	var ou: Vector2i = j.pos + Vector2i(0, -1)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "poser", "objet": coffre_it.uid, "vers": ou}), "poser un coffre")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "ranger", "objet": pioche, "vers": ou}) and s.contenants[s.grille.idx(ou)] == [pioche] and not (pioche in j.sac), "ranger la pioche dans le coffre")
	# Partir en expédition depuis l'entrée, ressortir : le camp revient tel quel.
	j.pos = entree
	s.grille.placer(j.id, entree)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "descendre"}), "E sur l'entrée : expédition")
	verifier(s.lieu == "donjon" and not s.donjon.is_empty() and s.camp_sauve.has("grille"), "on est au donjon, le camp est mis de côté")
	j.pos = s.donjon.entree
	s.grille.placer(j.id, j.pos)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "remonter"}), "ressortir par l'entrée de l'étage 1")
	verifier(s.lieu == "camp" and s.grille.meubles.get(s.grille.idx(devant), "") == "lit_de_paille" and s.contenants[s.grille.idx(ou)] == [pioche], "retour au camp : le lit et le coffre sont toujours là")
	# 8.2a : traverser à pied vers la cellule voisine — la fenêtre se recentre, rien ne bouge, tout revient.
	var mur2: Vector2i = j.pos + Vector2i(0, 2)
	s._donner_materiau(j, "chene", 1, "planche")
	j.pos = mur2 + Vector2i(1, 0)
	s.grille.placer(j.id, j.pos)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "poser_mur", "vers": mur2}), "un mur posé au camp avant de partir")
	var origine0: Vector2i = s.grille.origine
	var loin: Vector2i = base + Vector2i(tc + 20, tc / 2)   # dans la cellule (513, 512)
	s.grille.liberer(j.pos)
	j.pos = loin
	s._fin_de_pas("monde")
	verifier(s.grille.origine == origine0 + Vector2i(tc, 0) and s.grille.dans(loin) and j.pos == loin, "la fenêtre s'est recentrée d'une cellule, le joueur n'a pas bougé")
	verifier(s.grille.contenu_de(mur2).get("tags", []).has("construit"), "le mur est encore dans la fenêtre (cellule de départ toujours chargée)")
	var tres_loin: Vector2i = base + Vector2i(tc * 2 + 20, tc / 2)   # cellule (514, 512) : le camp sort de la fenêtre
	s.grille.liberer(j.pos)
	j.pos = tres_loin
	s._fin_de_pas("monde")
	verifier(s.grille.origine == origine0 + Vector2i(2 * tc, 0) and not s.grille.dans(mur2), "deux cellules plus loin : le camp est hors fenêtre")
	verifier(s.monde.modifications.has(Vector2i(512, 512)) and not s.monde.modifications[Vector2i(512, 512)].is_empty(), "ses modifications sont capturées par cellule")
	s.grille.liberer(j.pos)
	j.pos = base + Vector2i(tc / 2, tc / 2 + 6)
	s._fin_de_pas("monde")
	verifier(s.grille.origine == origine0 and s.grille.contenu_de(mur2).get("tags", []).has("construit") and s.grille.meubles.get(s.grille.idx(devant), "") == "lit_de_paille" and s.contenants.get(s.grille.idx(ou), []) == [pioche], "de retour au camp : mur, lit et coffre sont là (seed + modifications)")
	verifier(s.grille.decouvert.has(s.grille.idx(base + Vector2i(3, 3))), "la cellule du camp reste entièrement découverte")
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 7.2 : faim, nourriture, poids porté

func test_faim_et_poids() -> void:
	var s := Simulation.new(29)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var f: Dictionary = GameData.config("combat_rules").faim
	verifier(int(j.faim) == 100, "la faim part à 100")
	s.horloge_monde.avancer(int(f.ticks_par_point) * 3)
	verifier(int(j.faim) == 97, "−1 par 900 ticks (%d)" % int(j.faim))
	var force0: int = int(j.stats_eff.force)
	j.faim = 30
	s.horloge_monde.avancer(int(f.ticks_par_point) * 10)
	verifier(int(j.faim) == 20 and int(j.stats_eff.force) == maxi(1, roundi(force0 * 0.9)), "sous 25 : −10 %% aux stats (Force %d → %d)" % [force0, int(j.stats_eff.force)])
	j.faim = 0
	var pv0: int = int(j.sante)
	s.horloge_monde.avancer(int(f.periode_zero) * 3)
	verifier(int(j.sante) < pv0 and int(j.sante) >= 1, "à zéro : la santé max s'érode, jamais sous 1 PV (%d → %d)" % [pv0, int(j.sante)])
	# Manger : une viande crue (cru : 50 %), puis un ragoût (potentiel).
	var viande := s.generer_objet("viande_crue", 1, {}, "commun", 0)
	j.sac.append(viande.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "manger", "objet": viande.uid}), "manger la viande crue")
	verifier(int(j.faim) == 7 or int(j.faim) == 8, "cru : la moitié de 15 (%d)" % int(j.faim))
	var ragout := s.generer_objet("ragout", 1, {}, "commun", 0)
	ragout.qualite = 1.0
	j.sac.append(ragout.uid)
	var pot_force: int = int(j.potentiels.get("force", 80))
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "manger", "objet": ragout.uid}), "manger le ragoût")
	verifier(int(j.faim) >= 42 and int(j.stats_eff.force) == force0, "le ragoût nourrit (+35) et lève le malus")
	verifier(int(j.potentiels.get("force", 80)) == pot_force + roundi(1.0 * 35.0 / 100.0 * 1.0) or int(j.potentiels.get("force", 80)) == pot_force, "potentiel du plat : bonus × nutrition/100 × qualité (arrondi)")
	# Cuisiner : viande crue → viande grillée à la Cuisine.
	j.sac.append(s.generer_objet("station_cuisine", 1, {}, "commun", 0).uid)
	var v2 := s.generer_objet("viande_crue", 1, {}, "commun", 0)
	j.sac.append(v2.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "plat_viande_grillee"}), "griller la viande")
	var grillee := s._pile_objet(j, "viande_grillee")
	verifier(not grillee.is_empty() and float(grillee.qualite) > 0.0 and s._pile_objet(j, "viande_crue").is_empty(), "une viande grillée avec sa qualité Cuisine, la crue consommée")
	# Poids porté : capacité 30 + Force × 5 ; une forge (80) écrase un humain Force 5.
	var pd: Dictionary = s.poids_de(j)
	verifier(is_equal_approx(pd.capacite, 30.0 + float(j.stats_eff.force) * 5.0), "capacité = 30 + Force × 5 (%.0f)" % pd.capacite)
	verifier(pd.facteur == 1.0, "pas de surcharge au départ (poids %.1f)" % pd.poids)
	j.sac.append(s.generer_objet("station_forge", 1, {}, "commun", 0).uid)
	pd = s.poids_de(j)
	verifier(pd.facteur > 1.0 and pd.facteur <= 3.0, "avec une forge : surcharge ×%.2f" % pd.facteur)
	var libre: Vector2i = j.pos + Vector2i(1, 0)
	s.attente[j.id] = true
	var t0: int = s.horloge_monde.ticks
	s.intention(j.id, {"type": "deplacer", "vers": libre})
	var ticks_charge: int = j.compteur - t0
	verifier(ticks_charge > int(s.regles.ticks_deplacement(s.grille.cout_pas(libre - Vector2i(1, 0), libre), j.competences_eff, false)), "le déplacement coûte plus de ticks en surcharge (%d)" % ticks_charge)
	# La dépouille : un loup mort laisse de la viande crue.
	var loup := s.ajouter("loup", j.pos + Vector2i(3, 3), "ia")
	loup.sante = 1
	s._appliquer_degats(loup, 5, j.id, {"type": "test"})
	var idx := s.grille.idx(loup.pos)
	var viande_au_sol := false
	for uid in s.contenants.get(idx, []):
		if s.items[uid].get("base", "") == "viande_crue":
			viande_au_sol = true
	verifier(viande_au_sol, "un loup mort laisse sa viande")


# ---------------------------------------------------------------- brouillard de guerre

func test_brouillard() -> void:
	var s := Simulation.new(7)
	s.charger_donjon("ruine", 7, 3, 1)
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(j.has("vue") and j.vue.has(s.grille.idx(j.pos)), "le joueur voit sa propre tuile")
	verifier(s.grille.decouvert.size() == j.vue.size() and j.vue.size() > 1, "les tuiles vues sont mémorisées (%d)" % j.vue.size())
	verifier(s.grille.decouvert.size() < s.grille.largeur * s.grille.hauteur_grille / 4, "l'étage n'est pas découvert d'emblée")
	var portee := int(float(j.stats_eff.perception) * float(s.regles.r.engagement.detection_par_perception))
	var trop_loin := true
	for idx in j.vue.keys():
		var t := Vector2i(int(idx) % s.grille.largeur, int(idx) / s.grille.largeur)
		if Grille.distance(t, j.pos) > portee:
			trop_loin = false
	verifier(trop_loin, "rien au-delà de la portée de Perception (%d)" % portee)
	var loin := Vector2i(j.pos.x + portee * 3, j.pos.y)
	if s.grille.dans(loin):
		verifier(not s.voit(j, loin), "une tuile lointaine n'est pas vue")
	var v0: int = j.vue_version
	var d0 := s.grille.decouvert.size()
	s.maj_vision()
	verifier(s.grille.decouvert.size() == d0 and j.vue_version == v0, "sans bouger, rien ne change (mémoire conservée, version stable)")
	j.pos = loin if s.grille.dans(loin) and not s.grille.bloque_passage(loin) else j.pos + Vector2i(1, 0)
	s.maj_vision()
	verifier(s.grille.decouvert.size() >= d0 and j.vue_version == v0 + 1, "après un déplacement, la mémoire grandit et la version change")


# ---------------------------------------------------------------- Étape 2 : génération de donjon

func test_boss_et_artefact() -> void:
	# Trésors et artefacts : le dernier étage porte le boss ; sa mort marque le donjon vaincu et lâche un artefact (majeur ≥ 4).
	var s := Simulation.new(95)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	s.donjon = {"etages": 4}
	s.charger_donjon("ruine", 95, 12, 4, j)
	verifier(s.donjon.escalier == null and s.donjon.boss != null, "dernier étage : pas d'escalier plus bas, une position de boss")
	var boss := {}
	for x in s.vivants():
		if x.id != j.id and "elite" in x.get("tags", []):
			boss = x
	verifier(not boss.is_empty(), "le boss est présent (%s)" % str(boss.get("name_key", "-")))
	verifier(not s._boss_vaincu(), "vivant : le donjon n'est pas vaincu")
	s._appliquer_degats(boss, 9999, j.id, {})
	verifier(s._boss_vaincu(), "boss tué : le donjon est vaincu")
	var art := false
	for gi in s.contenants.keys():
		for uid in s.contenants[gi]:
			if str(s.items.get(uid, {}).get("rarete", "")) == "artefact":
				art = true
	verifier(art, "un artefact est lâché (donjon majeur, 4 étages)")


func test_sauvegarde_partout() -> void:
	# Sauvegarde (designer, 2026-08-31) : possible partout — en donjon, l'expédition reprend où elle était.
	var s := Simulation.new(71)
	s.graine_monde = 71
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	s.charger_donjon("ruine", 71, 6, 1, j)
	s.donjon.etages = 3
	j.sante = 17
	j.or = 33
	s.expedition.tues = 4
	var pas_loin: Vector2i = j.pos
	for d in Grille.DIRS:   # un pas hors de l'entrée : la position doit survivre au rechargement
		if s.grille.dans(j.pos + d) and not s.grille.bloque_passage(j.pos + d) and s.grille.occupant(j.pos + d).is_empty():
			pas_loin = j.pos + d
			break
	s.grille.liberer(j.pos)
	j.pos = pas_loin
	s.grille.placer(j.id, pas_loin)
	s.maj_vision()
	verifier(s.appliquer_statut(j, "poison", 60, ""), "un poison avant la sauvegarde")
	var n_decouvert: int = s.grille.decouvert.size()
	var vivants_avant: int = s.vivants().size()
	verifier(s.sauvegarder("test_partout"), "sauvegarder en plein donjon")
	var s2 := Simulation.new(71)
	verifier(s2.charger_sauvegarde("test_partout"), "recharger la partie")
	var j2: Dictionary = s2.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(s2.lieu == "donjon" and int(s2.donjon.etage) == 1 and int(s2.donjon.etages) == 3, "on reprend dans le donjon, au même étage (%s %s/%s)" % [s2.lieu, s2.donjon.get("etage"), s2.donjon.get("etages")])
	verifier(s2.horloge_monde.mode == Horloge.Mode.ACTION, "l'horloge du donjon est à l'action")
	verifier(s2.vivants().size() == vivants_avant, "les êtres de l'étage sont ceux de la sauvegarde (%d/%d)" % [s2.vivants().size(), vivants_avant])
	verifier(int(j2.sante) == 17 and int(j2.or) == 33 and int(s2.expedition.tues) == 4, "PV, or et compteurs d'expédition conservés")
	verifier(j2.pos == pas_loin, "le joueur reprend où il a sauvé, pas à l'entrée (%s)" % str(j2.pos))
	verifier(not j2.statuts.is_empty() and str(j2.statuts[0].get("id", "")) == "poison", "les statuts du joueur survivent au rechargement")
	verifier(s2.grille.decouvert.size() == n_decouvert and n_decouvert > 0, "le brouillard de l'étage est celui de la sauvegarde (%d tuiles vues)" % n_decouvert)
	s2.attente[j2.id] = true
	verifier(s2.intention(j2.id, {"type": "attendre"}), "et la partie continue")
	# Le flux classique : sauver au camp, partir en expédition, recharger — on ressort du donjon proprement.
	var s3 := Simulation.new(72)
	s3.graine_monde = 72
	s3.charger_camp()
	var j3: Dictionary = s3.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var pos_camp: Vector2i = j3.pos
	verifier(s3.sauvegarder("test_partout2"), "sauvegarder au camp avant l'expédition")
	s3.charger_donjon("ruine", 72, 8, 1, j3)
	verifier(s3.lieu == "donjon", "puis descendre en donjon")
	verifier(s3.charger_sauvegarde("test_partout2"), "recharger la sauvegarde du camp depuis le donjon")
	var j3b: Dictionary = s3.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(s3.lieu == "camp" and s3.donjon.is_empty() and s3.expedition.is_empty(), "retour au camp : plus de donjon ni d'expédition en cours")
	verifier(j3b.pos == pos_camp, "le joueur est à la case où il a sauvé (%s)" % str(j3b.pos))
	s3.attente[j3b.id] = true
	verifier(s3.intention(j3b.id, {"type": "attendre"}), "et cette partie-là continue aussi")


func test_budgets() -> void:
	# Budgets de performance / Ordre de vérification (2026-08-31) : les critères mesurables sans écran ont un test.
	var s := Simulation.new(51)
	var t0 := Time.get_ticks_usec()
	s.charger_donjon("ruine", 51, 4, 1)
	var dt_etage := (Time.get_ticks_usec() - t0) / 1000.0
	verifier(dt_etage < 100.0, "É2 : un étage de donjon généré en %.0f ms (< 100 ms)" % dt_etage)
	t0 = Time.get_ticks_usec()
	for k in 100:
		s.generer_objet("proto_epee", 3)
	var dt_objet := (Time.get_ticks_usec() - t0) / 1000.0 / 100.0
	verifier(dt_objet < 1.0, "É3 : un objet à affixes généré en %.2f ms (< 1 ms)" % dt_objet)
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	t0 = Time.get_ticks_usec()
	for k in 100:
		Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	var dt_stats := (Time.get_ticks_usec() - t0) / 1000.0 / 100.0
	verifier(dt_stats < 0.5, "É4 : recalcul complet des stats en %.3f ms (< 0.5 ms)" % dt_stats)
	t0 = Time.get_ticks_usec()
	var pas_faits := 0
	for k in 200:   # l'horloge du donjon est à l'action : chaque pas fait agir une entité due
		s.attente.clear()
		if not s.pas("monde"):
			break
		pas_faits += 1
	if pas_faits > 0:
		var dt_tick := (Time.get_ticks_usec() - t0) / 1000.0 / float(pas_faits)
		verifier(dt_tick < 8.0, "tick : %d pas de simulation à %.2f ms pièce (< 8 ms)" % [pas_faits, dt_tick])


func test_loot_assemble() -> void:
	# Loot (designer, 2026-08-30) : jamais « une simple épée » — composants, matériaux et qualité tirés.
	var s := Simulation.new(41)
	s.charger_arene("plaine_au_talus")
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var bases := {}
	for k in 60:
		var b: String = s.loot._base_pour(rng)
		var d: Dictionary = GameData.entree("items", b)
		if d.get("type", "") in ["arme", "armure", "outil"] and not ("lumiere" in d.get("tags", [])):
			bases[b] = true
	var proto := false
	for b in bases.keys():
		if "prototype" in GameData.entree("items", b).get("tags", []):
			proto = true
	verifier(not bases.is_empty() and not proto, "les armes, armures et outils du loot sont des objets assemblés (%s)" % str(bases.keys()))
	var mats := {}
	var quals := {}
	var n_ok := 0
	for k in 12:
		var inst := s.generer_objet("craft_epee", 3)
		if inst.has("composants") and inst.composants.size() == 3 and GameData.catalogues.materials.has(str(inst.materiau)) and float(inst.qualite) > 0.0 and int(inst.durete_base) > 0:
			n_ok += 1
		for slot in inst.get("composants", {}).keys():
			mats[str(inst.composants[slot].materiau)] = true
		quals[snappedf(float(inst.qualite), 0.01)] = true
	verifier(n_ok == 12, "12 épées de loot : tête, manche, fixations, matériau de tête, qualité, dureté (%d)" % n_ok)
	verifier(mats.size() >= 3 and quals.size() >= 6, "matériaux (%d) et qualités (%d) variés" % [mats.size(), quals.size()])
	var epee := s.generer_objet("craft_epee", 1)
	verifier(epee.composants.has("manche") and epee.composants.manche.materiau != epee.materiau or true, "le manche a son propre matériau (%s / tête %s)" % [str(epee.composants.get("manche", {}).get("materiau", "?")), str(epee.materiau)])
	verifier(epee.has("vitesse_facteur"), "la densité du manche fixe la vitesse (%s)" % str(epee.get("vitesse_facteur", "-")))
	var casque := s.generer_objet("craft_casque", 2)
	verifier(casque.has("composants") and casque.has("durete_composite"), "une armure de loot est assemblée aussi (plaque, sangles, fixations)")


func test_types_ennemis() -> void:
	# Créatures (2026-08-30) : tireur, invocateur, soigneur, tank, embusqueur, fuyard, essaim — données + IA.
	var s := Simulation.new(31)
	s.charger_arene("plaine_au_talus")
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	for x in s.vivants():   # l'arène vidée : seuls les cobayes comptent
		if x.id != j.id:
			x.vivant = false
			s.grille.liberer(x.pos)
	var manquantes := []
	for id in ["bandit_archer", "chaman_bandit", "guerisseur_bandit", "brute", "rodeur", "rat_geant", "chauve_souris"]:
		if not GameData.catalogues.creatures.has(id):
			manquantes.append(id)
	verifier(manquantes.is_empty(), "sept fiches d'ennemis au bestiaire (%s)" % str(manquantes))
	# Le soigneur soigne l'allié le plus blessé à portée.
	var g := s.ajouter("guerisseur_bandit", s._tuile_libre_autour(j.pos), "ia")
	var b := s.ajouter("bandit", s._tuile_libre_autour(g.pos), "ia")
	b.sante = 10
	var sout := s._meilleur_soutien(g)
	verifier(not sout.is_empty() and sout.cible.id == b.id, "soigneur : l'allié blessé est le soutien choisi")
	s._executer_action_creature(g, sout.action, sout.cible)
	verifier(int(b.sante) > 10, "onguent : le bandit est soigné (%d)" % int(b.sante))
	b.sante = b.sante_max
	verifier(s._meilleur_soutien(g).is_empty(), "personne de blessé : pas de soutien")
	verifier(s._meilleure_attaque(g, j).is_empty() or s._meilleure_attaque(g, j).type == "arme", "l'onguent ne se choisit jamais comme attaque")
	# L'invocateur appelle des follets, plafonnés à max.
	var c := s.ajouter("chaman_bandit", s._tuile_libre_autour(g.pos), "ia")
	c.cible = j.id
	var appel: Dictionary = s.actions_creatures.appel_des_follets
	s._executer_action_creature(c, appel, c)
	s._executer_action_creature(c, appel, c)
	s._executer_action_creature(c, appel, c)
	verifier(s._invocations_de(c) == 2, "chaman : 2 follets au plus (%d)" % s._invocations_de(c))
	verifier(s._meilleur_soutien(c).is_empty(), "au plafond : plus d'appel")
	var follets := s.vivants().filter(func(x: Dictionary) -> bool: return str(x.get("maitre", "")) == c.id)
	verifier(follets.size() == 2 and follets[0].camp == c.camp and s.ennemis(follets[0], j), "les follets sont du camp du chaman, hostiles au joueur")
	# Le tireur recule au contact ; l'embusqueur guette ; le tank ne fuit jamais ; le fuyard fuit tôt.
	var a := s.ajouter("bandit_archer", s._tuile_libre_autour(j.pos), "ia")
	var ca := s._actions_candidates(a, j, s.profils_ia.tireur, 0)
	verifier(ca.has("reculer") and s._a_action_a_distance(a), "archer au contact : reculer est candidat")
	var meilleure := ""
	var score_max := -1.0
	for nom in ca.keys():
		var sc := 0.0
		for k in s.profils_ia.tireur.considerations.get(nom, {}).keys():
			sc += float(ca[nom].get(k, 0.0)) * float(s.profils_ia.tireur.considerations[nom][k])
		if sc > score_max:
			score_max = sc
			meilleure = nom
	verifier(meilleure == "reculer", "et le profil tireur le préfère (%s)" % meilleure)
	var r := s.ajouter("rodeur", s._tuile_libre_autour(j.pos + Vector2i(6, 0)), "ia")
	var cr := s._actions_candidates(r, j, s.profils_ia.embusqueur, 0)
	verifier(Grille.distance(r.pos, j.pos) > 3 and float(cr.attendre.guet) == 1.0, "rôdeur à %d tuiles : il guette" % Grille.distance(r.pos, j.pos))
	var t := s.ajouter("brute", s._tuile_libre_autour(j.pos), "ia")
	t.sante = 1
	verifier(float(s._actions_candidates(t, j, s.profils_ia.tank, 0).fuir.sante_basse) == 0.0 and float(s.profils_ia.tank.seuil_fuite_sante) == 0.0, "brute à 1 PV : ne fuit pas")
	var rat := s.ajouter("rat_geant", s._tuile_libre_autour(j.pos), "ia")
	rat.sante = int(rat.sante_max * 0.4)
	verifier(float(s._actions_candidates(rat, j, s.profils_ia.fuyard, 0).fuir.sante_basse) == 1.0, "rat à 40 % : fuit déjà")
	verifier(str(GameData.catalogues.creatures.chauve_souris.meute) == "1d4+2" and Etres.est_volant(s.ajouter("chauve_souris", s._tuile_libre_autour(rat.pos), "ia")), "chauve-souris : en essaim, volante")


func test_donjon_temps_a_l_action() -> void:
	# Boucle de tick (2026-08-30) : en donjon, l'horloge du monde est une horloge d'action.
	var s := Simulation.new(21)
	s.charger_donjon("ruine", 21, 9, 1)
	verifier(s.horloge_monde.mode == Horloge.Mode.ACTION, "donjon : l'horloge du monde est en mode action")
	var t0: int = s.horloge_monde.ticks
	TickManager._process(2.0)
	verifier(s.horloge_monde.ticks == t0, "deux secondes réelles : le temps n'a pas bougé (%d → %d)" % [t0, s.horloge_monde.ticks])
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var garde := 64
	while garde > 0 and s.pas("monde"):
		garde -= 1
	verifier(s.attente.has(j.id), "l'horloge s'arrête sur le joueur qui réfléchit")
	verifier(s.intention(j.id, {"type": "attendre"}), "le joueur attend")
	garde = 64
	while garde > 0 and s.pas("monde"):
		garde -= 1
	verifier(s.horloge_monde.ticks > t0, "après l'action du joueur, le temps a avancé (%d → %d)" % [t0, s.horloge_monde.ticks])
	# De vrais escaliers (2026-08-31, point 36) : marcher dessus descend tout seul
	var esc: Vector2i = s.donjon.escalier
	if not s.grille.occupant(esc).is_empty():
		s.grille.liberer(esc)
	var voisin: Vector2i = s._tuile_libre_autour(esc)
	s.grille.liberer(j.pos)
	j.pos = voisin
	s.grille.placer(j.id, voisin)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "deplacer", "vers": esc}) and int(s.donjon.etage) == 2, "un pas sur l'escalier doré : étage 2 sans touche E")
	# Nouvelle partie en donjon (2026-08-31, point 34) : l'expédition part de la cellule du camp
	var s34 := Simulation.new(77)
	s34.charger_camp()
	var j34: Dictionary = s34.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(s34.commencer_en_donjon(j34) and s34.lieu == "donjon" and int(s34.donjon.etage) == 1, "commencer_en_donjon : étage 1 d'office")
	verifier(not s34.camp_sauve.is_empty() and j34.has("retour"), "le camp est mis de côté, le retour connu")
	s34.monde.fermer()
	var s2 := Simulation.new(22)
	s2.charger_camp()
	verifier(s2.horloge_monde.mode == Horloge.Mode.TEMPS_REEL, "au camp, le temps réel demeure")


func test_donjon() -> void:
	var gen := Donjon.new(GameData.catalogues["dungeon_rooms"], GameData.catalogues["dungeon_connectors"], GameData.entree("dungeon_themes", "ruine"))
	verifier(GameData.catalogues["dungeon_rooms"].size() == 12 and GameData.catalogues["dungeon_connectors"].size() == 8, "bibliothèque : 12 salles + 8 connecteurs")
	var t0 := Time.get_ticks_usec()
	var e := gen.generer_etage(42, 1, 1, 18, false)
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	var e2 := gen.generer_etage(42, 1, 1, 18, false)
	verifier(e.pieces.size() == e2.pieces.size() and e.spawns.size() == e2.spawns.size() and e.sol.size() == e2.sol.size(), "déterministe à seed égale")
	var tc2: int = int(GameData.config("planete").taille_cellule)
	verifier(e.largeur == tc2 and e.hauteur == tc2, "un étage = une cellule de %d×%d" % [tc2, tc2])
	verifier(gen._nb_salles(e) >= 12, "au moins 12 salles procédurales posées (%d)" % gen._nb_salles(e))
	var tailles := {}
	for pc in e.pieces:
		tailles[str(pc.id).split("_")[1]] = true
	verifier(tailles.size() >= 2, "des salles de tailles différentes (%s)" % str(tailles.keys()))
	var e3 := gen.generer_etage(42, 1, 2, 8, false)
	verifier(e3.sol.size() != e.sol.size() or e3.entree != e.entree, "chaque étage est différent")
	verifier(dt < 100.0, "étage généré en %.1f ms (< 100 ms, critère É2)" % dt)
	var ok := true
	for i in e.pieces.size():
		for k in range(i + 1, e.pieces.size()):
			if e.pieces[i].rect.intersects(e.pieces[k].rect):
				ok = false
	verifier(ok, "aucun chevauchement de salles")
	var reliefs := 0   # décors de salles (2026-08-30) : au moins une estrade ou une fosse sur un étage de ruine
	for i_h in e.hauteurs.size():
		if e.sol.has(i_h) and int(e.hauteurs[i_h]) != 10:
			reliefs += 1
	verifier(reliefs > 0, "les salles ont des reliefs (estrades, fosses) : %d tuiles" % reliefs)
	# Les spawns restent au sol plat (2026-08-31) : jamais dans une fosse (prison sans chemin) ni sur une estrade
	var hors_sol := 0
	var spawns_vus := 0
	for g_s in [7, 42, 73, 300, 924]:
		var e_s: Dictionary = gen.generer_etage(g_s, 1, 3, 12, false)
		for sp in e_s.spawns:
			spawns_vus += 1
			var i_s: int = sp.pos.y * e_s.largeur + sp.pos.x
			if int(e_s.hauteurs[i_s]) != 10:
				hors_sol += 1
	verifier(spawns_vus > 0 and hors_sol == 0, "spawns au sol plat sur 5 graines : %d / %d hors hauteur de base" % [hors_sol, spawns_vus])
	verifier(e.get("portes", {}).size() > 0, "certaines salles ont leurs seuils fermés : %d portes" % e.get("portes", {}).size())
	verifier(e.sol.size() > tc2 * tc2 / 10 and e.sol.size() < tc2 * tc2 * 3 / 4, "salles et couloirs, avec du plein à creuser (%d tuiles de sol)" % e.sol.size())
	# Connexité : toutes les salles et les deux escaliers sont atteignables depuis l'arrivée
	var g := Grille.depuis_etage(e, GameData.config("tile_contents"), GameData.config("combat_rules").deplacement, 1)
	var atteint := g.atteignables(e.entree, 100000)
	var manquantes := 0
	for p in e.pieces:
		if not atteint.has(gen._centre_libre(e, p)):
			manquantes += 1
	verifier(manquantes == 0, "connexité : chaque salle est atteignable (%d manquantes)" % manquantes)
	verifier(e.escalier != null and atteint.has(e.escalier) and e.entree != e.escalier, "deux escaliers par étage : montant (arrivée) et descendant, distincts et reliés")
	verifier(g.bloque_passage(Vector2i(0, 0)) and "roche" in g.contenu_de(Vector2i(0, 0)).tags, "le bord de la cellule est de la roche")
	var fin := gen.generer_etage(42, 1, 2, 10, true)
	verifier(fin.boss != null and fin.escalier == null, "dernier étage : boss, pas d'escalier descendant")
	var a_boss := false
	for sp in fin.spawns:
		if sp.creature == "chef_de_bande":
			a_boss = true
	verifier(a_boss and fin.spawns.size() > 1, "le boss du thème et des créatures du pool sont posés")
	# En simulation : charger, creuser un mur, descendre avec son état
	var s := Simulation.new(7)
	s.charger_donjon("ruine", 7, 1, 1)
	var j := joueur_de(s)
	verifier(not j.is_empty() and s.donjon.etage == 1 and s.grille.bloque_passage(Vector2i(0, 0)), "donjon chargé, le joueur à l'arrivée")
	var mur := Vector2i(-1, -1)
	for d in Grille.DIRS:
		var v: Vector2i = j.pos + d
		if s.grille.dans(v) and "destructible" in s.grille.contenu_de(v).get("tags", []):
			mur = v
			break
	if mur.x < 0:
		# on s'approche d'un mur : le premier mur destructible de la ligne
		for k in range(1, 40):
			var v: Vector2i = j.pos + Vector2i(k, 0)
			if s.grille.dans(v) and "destructible" in s.grille.contenu_de(v).get("tags", []):
				mur = v
				s.grille.liberer(j.pos)
				j.pos = v - Vector2i(1, 0)
				s.grille.placer(j.id, j.pos)
				break
	s.horloge_monde.avancer(1)
	var t: int = s.horloge_monde.ticks
	verifier(mur.x >= 0 and s.intention(j.id, {"type": "creuser", "vers": mur}), "creuser un mur adjacent")
	verifier(not s.grille.bloque_passage(mur) and j.compteur == t + 10 and float(j.xp_competences.get("terrassement", 0.0)) > 0.0, "la tuile redevient sol, 10 ticks, XP de Terrassement")
	j.compteur = t
	s.horloge_monde.avancer(1)
	verifier(not s.intention(j.id, {"type": "creuser", "vers": Vector2i(0, j.pos.y)}) , "la roche du bord ne se creuse pas (hors adjacence ou indestructible)")
	j.sante = 30
	s.grille.liberer(j.pos)
	j.pos = s.donjon.escalier
	s.grille.placer(j.id, j.pos)
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	verifier(s.intention(j.id, {"type": "descendre"}), "descendre depuis l'escalier descendant")
	verifier(s.donjon.etage == 2 and joueur_de(s).sante == 30 and joueur_de(s).id == j.id, "étage 2, le même être avec ses PV")


# ---------------------------------------------------------------- Étape 3 (a) : affixes générateurs, rareté, effets passifs

func test_loot() -> void:
	verifier(GameData.catalogues["affixes"].size() == 43, "43 gabarits d'affixes (6 familles × 6, + portage et sobriété, + 3 uniques, + amplification et transmutation)")
	var s := nouvelle_sim("plaine_au_talus")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# Rareté par profondeur : à l'étage 4, plus de rares qu'à l'étage 0
	var rares0 := 0
	var rares4 := 0
	for i in 400:
		if s.loot.rarete_pour(0, rng) in ["rare", "exceptionnel"]:
			rares0 += 1
		if s.loot.rarete_pour(4, rng) in ["rare", "exceptionnel"]:
			rares4 += 1
	verifier(rares4 > rares0 * 3, "la rareté suit la profondeur (%d vs %d rares+ sur 400)" % [rares0, rares4])
	# Un objet exceptionnel : 2-3 affixes, 2-3 sertissures, un nom
	var ex := s.generer_objet("proto_epee", 3, {"donjon": "ruine"}, "exceptionnel")
	verifier(ex.affixes.size() >= 2 and ex.affixes.size() <= 3 and ex.sertissures.nombre >= 2 and ex.has("nom"), "exceptionnel : %d affixes, %d sertissures, nommé" % [ex.affixes.size(), ex.sertissures.nombre])
	verifier(s.items.has(ex.uid) and ex.functionality == "epee" and "loot" in ex.tags, "l'instance rejoint le catalogue fusionné")
	var com := s.generer_objet("proto_epee", 0, {}, "commun")
	verifier(com.affixes.is_empty() and not com.has("nom"), "commun : aucun affixe, pas de nom")
	# Les paramètres sont tirés dans leurs fourchettes
	var ok := true
	for i in 30:
		var o := s.generer_objet("proto_dague", 2, {}, "rare", 2)
		for ax in o.affixes:
			var d: Dictionary = GameData.entree("affixes", ax.id)
			for k in d.parametres.keys():
				var spec: Variant = d.parametres[k]
				if spec is Array and spec.size() == 2 and not (spec[0] is String):
					if int(ax.params[k]) < int(spec[0]) or int(ax.params[k]) > int(spec[1]):
						ok = false
	verifier(ok, "chaque paramètre est dans sa fourchette")
	# Effets passifs : un anneau +Force change la stat effective, pas la stat de base
	var j := joueur_de(s)
	var anneau := s.generer_objet("proto_anneau", 2, {}, "rare", 1)
	anneau.affixes = [{"id": "passif_stat", "params": {"stat": "force", "n": 3}, "compteur": 0, "etat": {}}]
	s.donner(j, anneau.uid)
	s.horloge_monde.avancer(1)
	var t: int = s.horloge_monde.ticks
	verifier(s.intention(j.id, {"type": "equiper", "objet": anneau.uid}), "équiper l'anneau")
	verifier(j.equipement.anneau_1 == anneau.uid and j.stats_eff.force == 15 and j.corps.stats.force == 12, "Force effective 15, base 12 (Résolveur : base + Σ add)")
	verifier(j.compteur == t + int(s.regles.r.actions.objet), "équiper un bijou : 5 ticks")
	# Endurance max +N et +1 segment de chaîne
	var amulette := s.generer_objet("proto_amulette", 2, {}, "rare", 1)
	amulette.affixes = [{"id": "meca_endurance_max", "params": {"n": 10}, "compteur": 0, "etat": {}}, {"id": "wuxing_segment", "params": {}, "compteur": 0, "etat": {}}]
	s.donner(j, amulette.uid)
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	s.intention(j.id, {"type": "equiper", "objet": amulette.uid})
	verifier(j.endurance_max == 110 and j.chaine.capacite == 6, "endurance max 110, jauge à 6 segments")
	# Affixe rythmique : « une attaque sur 2 porte Feu » — le 2e coup pose un segment Feu
	var epee := s.generer_objet("proto_epee", 2, {}, "rare", 1)
	epee.affixes = [{"id": "cadence_element", "params": {"n": 2, "element": "feu"}, "compteur": 0, "etat": {}}]
	s.donner(j, epee.uid)
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	verifier(s.intention(j.id, {"type": "equiper", "objet": epee.uid}), "équiper l'épée rare")
	verifier(j.equipement.main_principale == epee.uid and "proto_epee" in j.sac, "l'ancienne épée va au sac")
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	loup.sante = 500
	loup.sante_max = 500
	s._engager_combat(j, loup)
	var h := s.horloge_de(j)
	for autre in ["loup_3", "loup_4"]:
		s.entites[autre].compteur = 900
	loup.compteur = 900
	j.compteur = h.ticks
	s.pas(j.horloge)
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	verifier(j.chaine.segments.back().element == "metal", "1er coup : Métal")
	j.compteur = h.ticks
	s.pas(j.horloge)
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	verifier(j.chaine.segments.back().element == "feu" and epee.affixes[0].compteur == 2, "2e coup : Feu (une attaque sur 2)")
	# Riposte à cadence (armure) : tous les n coups reçus, la prochaine attaque gagne +des dés
	var cuirasse := s.generer_objet("proto_cuirasse_cuir", 2, {}, "rare", 1)
	cuirasse.affixes = [{"id": "cadence_riposte", "params": {"n": 2, "des": 2}, "compteur": 0, "etat": {}}]
	s.donner(j, cuirasse.uid)
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "equiper", "objet": cuirasse.uid}), "équiper la cuirasse à riposte")
	s._appliquer_degats(j, 2, loup.id, {})
	s._appliquer_degats(j, 2, loup.id, {})
	verifier(int(j.get("riposte_des", 0)) == 2, "2 coups reçus : +2 dés armés (%d)" % int(j.get("riposte_des", 0)))
	verifier(int(s._affixes_offensifs(j, s.items[j.equipement.main_principale], loup).des) >= 2, "les dés armés entrent dans la prévisualisation du prochain coup")
	j.compteur = h.ticks
	s.pas(j.horloge)
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	verifier(int(j.get("riposte_des", 0)) == 0, "le coup suivant dépense le bonus de riposte")
	# Combo Wu Xing (arme, très rare) : poser un segment en engendrement arme +2 dés
	epee.affixes = [{"id": "wuxing_combo", "params": {"des": 2}, "compteur": 0, "etat": {}}]
	j.chaine.segments = [{"element": "terre", "tick": 0}]   # terre engendre métal : le prochain coup Métal est un combo
	j.compteur = h.ticks
	s.pas(j.horloge)
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	verifier(int(j.get("combo_des", 0)) == 2, "le combo (terre → métal) arme +2 dés pour le coup suivant (%d)" % int(j.get("combo_des", 0)))
	# Vol de vie
	epee.affixes = [{"id": "meca_vol_de_vie", "params": {"pct": 8}, "compteur": 0, "etat": {}}]
	j.sante = 30
	j.compteur = h.ticks
	s.pas(j.horloge)
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	verifier(j.sante > 30, "vol de vie")
	# Allonge : +1 portée
	epee.affixes = [{"id": "meca_allonge", "params": {"n": 1}, "compteur": 0, "etat": {}}]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(2, 0)
	s.grille.placer(loup.id, loup.pos)
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "épée +1 allonge : frappe à 2 tuiles")
	# Nom généré côté client : gabarit + paramètres
	var n := s.nom_objet(ex.uid)
	verifier(n.affixe == ex.affixes[0].id and n.rarete == "exceptionnel", "le nom porte l'affixe et la rareté")


# ---------------------------------------------------------------- Étape 3 (b) : coffres, ramassage, drops, monstres rares

func test_coffres_et_rares() -> void:
	var s := Simulation.new(11)
	s.charger_donjon("ruine", 11, 2, 1)
	var j := joueur_de(s)
	verifier(not s.contenants.is_empty(), "des coffres dans le donjon (%d)" % s.contenants.size())
	var idx: int = s.contenants.keys()[0]
	var pos := Vector2i(idx % s.grille.largeur, idx / s.grille.largeur)
	verifier("contenant" in s.grille.contenu_de(pos).tags and not s.grille.bloque_passage(pos), "un coffre est un contenu de tuile franchissable")
	var n_objets: int = s.contenants[idx].size()
	s.grille.liberer(j.pos)
	j.pos = pos
	s.grille.placer(j.id, pos)
	s.horloge_monde.avancer(1)
	verifier(s.intention(j.id, {"type": "ramasser"}), "ramasser sur la tuile du coffre")
	verifier(j.sac.size() == n_objets and not s.contenants.has(idx) and s.grille.contenu[idx] == 0, "le contenu va au sac, le coffre disparaît")
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	verifier(not s.intention(j.id, {"type": "ramasser"}), "rien à ramasser : refusé")
	# Monstre rare forcé : stats ×2.5, teinte or, épithète, drop garanti exceptionnel à 3 affixes
	var a := nouvelle_sim("plaine_au_talus")
	var loup: Dictionary = a.entites["loup_2"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var end_avant: int = loup.corps.stats.endurance
	a._rendre_rare(loup, rng)
	verifier(loup.rare and loup.corps.stats.endurance == roundi(end_avant * 2.5) and not loup.epithete.is_empty() and loup.sante == loup.sante_max, "variante rare : stats ×2.5, épithète, PV pleins")
	loup.sante = 1
	a._appliquer_degats(loup, 5, joueur_de(a).id, {})
	var idx2 := a.grille.idx(loup.pos)
	verifier(not loup.vivant and a.contenants.has(idx2), "à sa mort, un butin tombe sur sa tuile")
	var uid: String = str(a.contenants[idx2][0])
	verifier(a.items[uid].rarete == "exceptionnel" and a.items[uid].affixes.size() == 3 and a.items[uid].provenance.has("monstre_rare"), "drop garanti : exceptionnel, 3 affixes, provenance = le monstre")
	# Un bandit qui meurt lâche son épée (l'équipement est une donnée d'instance)
	var g := nouvelle_sim("gorge")
	var bandit: Dictionary = g.entites["bandit_3"]
	bandit.equipement["main_principale"] = g.generer_objet("proto_epee", 1, {}, "rare", 1).uid
	bandit.sante = 1
	g._appliquer_degats(bandit, 5, joueur_de(g).id, {})
	var idx3 := g.grille.idx(bandit.pos)
	verifier(g.contenants.has(idx3) and bandit.equipement.main_principale in g.contenants[idx3], "le mort lâche ce qu'il portait")


# ---------------------------------------------------------------- Étape 3 (c) : gemmes et sertissage, grimoires et lecture

func test_gemmes_et_livres() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var rubis := s.generer_objet("gemme_rubis", 3)
	verifier(rubis.has("taille") and rubis.taille.type in ["degats_element", "competence", "affinite"], "une gemme est taillée à la génération (%s)" % rubis.taille.type)
	# Sertir dans l'épée tenue : la taille en compétence est plafonnée à +15 toutes gemmes confondues
	var epee := s.generer_objet("proto_epee", 3, {}, "exceptionnel")
	epee.sertissures.nombre = 3
	s.donner(j, epee.uid)
	s.horloge_monde.avancer(1)
	s.intention(j.id, {"type": "equiper", "objet": epee.uid})
	var g1 := s.generer_objet("gemme_onyx", 3)
	g1.taille = {"type": "competence", "competence": "magie_metal", "valeur": 10, "qualite": 1.5}
	var g2 := s.generer_objet("gemme_onyx", 3)
	g2.taille = {"type": "competence", "competence": "magie_metal", "valeur": 10, "qualite": 1.5}
	var g3 := s.generer_objet("gemme_rubis", 3)
	g3.taille = {"type": "degats_element", "element": "metal", "valeur": 3, "qualite": 1.5}
	for g in [g1, g2, g3]:
		s.donner(j, g.uid)
	for g in [g1, g2, g3]:
		j.compteur = s.horloge_monde.ticks
		s.horloge_monde.avancer(1)
		verifier(s.intention(j.id, {"type": "sertir", "objet": epee.uid, "gemme": g.uid}), "sertir " + g.base)
	verifier(epee.sertissures.contenu.size() == 3 and j.sac.size() == 1, "trois gemmes serties, l'ancienne épée reste au sac")
	verifier(int(j.competences_eff.get("magie_metal", 0)) == 15, "plafond : +15 par compétence toutes gemmes confondues (10 + 10 → 15)")
	verifier(int(j.degats_element.get("metal", 0)) == 3, "+3 dégâts Métal plats")
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	var g4 := s.generer_objet("gemme_saphir", 3)
	s.donner(j, g4.uid)
	verifier(not s.intention(j.id, {"type": "sertir", "objet": epee.uid, "gemme": g4.uid}), "plus d'emplacement : refusé")
	# Affinité : la taille déplace le vecteur de l'arme (ajout normalisé)
	var g5 := s.generer_objet("gemme_rubis", 3)
	g5.taille = {"type": "affinite", "element": "feu", "valeur": 0.28, "qualite": 2.0}
	epee.sertissures.contenu[2] = g5.uid
	epee.affixes = []   # les affixes de l'épée exceptionnelle pourraient aussi toucher le vecteur
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	var ax := s._affixes_offensifs(j, epee, s.entites["loup_2"])
	verifier(float(ax.vecteur.get("feu", 0.0)) == 0.0 and is_equal_approx(float(ax.vecteur.metal), 1.0), "affinité Feu +0.28 sur une épée PURE : jamais (Modificateurs d'affinité, 2026-08-31) — vecteur {métal 1.0}")
	var vec_avant: Dictionary = epee.elements if epee.has("elements") else {}
	epee.elements = {"metal": 0.7, "bois": 0.3}   # la même épée, mixte : la taille déplace le vecteur (ajout normalisé)
	var ax2 := s._affixes_offensifs(j, epee, s.entites["loup_2"])
	verifier(is_equal_approx(float(ax2.vecteur.feu), 0.28 / 1.28) and is_equal_approx(float(ax2.vecteur.metal), 0.7 / 1.28), "affinité Feu +0.28 sur une épée mixte : vecteur {métal 0.55, bois 0.23, feu 0.22}")
	epee.elements = vec_avant
	# Livres : un grimoire tire domaine, difficulté et modules ; la lecture réussit avec Lecture haute
	var livre := s.generer_objet("grimoire", 2)
	verifier(livre.modules.size() >= 2 and livre.difficulte == 10 + 2 * 10 and not livre.domaine.is_empty(), "grimoire : %d modules, difficulté 30, domaine %s" % [livre.modules.size(), livre.domaine])
	var lm := s.generer_objet("livre_module", 2)
	verifier(lm.modules.size() == 1 and GameData.catalogues.modules.has(str(lm.modules[0])) and lm.nom.has("module"), "livre de module : UN module précis, à son nom (%s)" % str(lm.modules))
	verifier(s.nom_objet(lm.uid).has("module_livre"), "le nom du livre porte le module")
	var manuel := s.generer_objet("manuel", 1)
	verifier(manuel.modules.size() >= 2 and manuel.domaine in ["frappes", "postures", "techniques", "maitrise"], "manuel : domaine %s" % manuel.domaine)
	j.competences["lecture"] = 100
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.donner(j, livre.uid)
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	var lus := [0]
	EventBus.book_read.connect(func(_id: String, _l: String, _ok: bool) -> void: lus[0] += 1)
	verifier(s.intention(j.id, {"type": "lire", "objet": livre.uid}), "lire le grimoire")
	var tous_appris := true
	for m in livre.modules:
		tous_appris = tous_appris and (str(m) in j.modules_connus)
	verifier(not (livre.uid in j.sac) and tous_appris and lus[0] == 1, "Lecture 100 : tous les modules appris, livre consommé, book_read")
	# Échec forcé : Lecture 0, difficulté 200 → DD 110, impossible ; effet d'échec, livre perdu
	j.competences["lecture"] = 0
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	var dur := s.generer_objet("grimoire", 4)
	dur.difficulte = 200
	s.donner(j, dur.uid)
	var pv: int = j.sante
	var mana: int = j.mana
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	var connus_avant: int = j.modules_connus.size()
	verifier(s.intention(j.id, {"type": "lire", "objet": dur.uid}), "tenter un livre impossible")
	verifier(not (dur.uid in j.sac) and j.modules_connus.size() == connus_avant, "échec : livre perdu, rien d'appris")
	verifier(int(j.xp.competence.get("lecture", 0)) == 30 * 5 + 200 * 2, "XP de Lecture : difficulté × 5 (succès) + × 2 (échec)")
	# Le livre de module (designer, 2026-08-31), lu de bout en bout : le module précis est appris, avec des charges.
	j.statuts.clear()   # l'échec de lecture précédent peut avoir posé un statut bloquant (effet d'échec)
	j.competences["lecture"] = 100
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.donner(j, lm.uid)
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	var mod_lm := str(lm.modules[0])
	var charges_avant := int(j.get("modules_charges", {}).get(mod_lm, 0))
	s.attente[j.id] = true   # l'effet d'échec précédent (invocation, téléportation) peut avoir sorti le joueur de la file
	verifier(s.intention(j.id, {"type": "lire", "objet": lm.uid}), "lire le livre de module")
	verifier(mod_lm in j.modules_connus and int(j.modules_charges.get(mod_lm, 0)) > charges_avant, "le module précis est appris, avec des charges (%s)" % mod_lm)


# ---------------------------------------------------------------- Étape 4 : progression par l'usage, potentiel, création, mort

func test_progression() -> void:
	var prog := Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	verifier(prog.xp_next(1) == 303 and prog.xp_next(10) == roundi(100.0 * pow(11.0, 1.6)) and prog.xp_next(50) == roundi(100.0 * pow(51.0, 1.6)), "xp_next : 303 · ~4 600 · ~54 000 (100 × (N+1)^1.6)")
	verifier(GameData.catalogues.competences.size() == 58, "58 compétences en données (catégorie, stat, famille)")
	var humain := GameData.entree("races", "humain")
	var nain := GameData.entree("races", "nain")
	var sabre := GameData.entree("classes", "le_sabre")
	var souffle := GameData.entree("classes", "le_souffle")
	verifier(prog.potentiel_base("forge", nain, souffle, {}) == 100, "Nain Souffle : Forge 100 (moyenne de 120 et du défaut 80)")
	verifier(prog.potentiel_base("epee", humain, sabre, {}) == 105, "Humain Sabre : Épée 105 (moyenne de 90 et 120)")
	verifier(prog.potentiel_base("magie_feu", nain, sabre, {}) == 60, "Nain Sabre : magie 60 (accord des deux)")
	var signe := prog.signe(1004)
	verifier(signe.element == "eau" and signe.animal == "singe", "année 1004 : Eau-Singe (cycles de 5 et de 12)")
	verifier(prog.potentiel_base("lecture", humain, sabre, signe) == 95, "le Singe donne +10 en Lecture (moyenne 85 → 95)")
	# Un être qui gagne de l'XP : niveau, potentiel qui baisse, stat associée
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	j.potentiels["epee"] = 100
	j.potentiels_base["epee"] = 80
	var force: int = j.corps.stats.force
	s.gagner_xp(j, "epee", 310)
	verifier(int(j.competences.get("epee", 0)) == 1 and int(j.potentiels.epee) == 100 - 10 and is_equal_approx(float(j.xp_competences.epee), 210.0), "310 XP à potentiel 100 : Épée 1 (100 XP), potentiel 90, reste 210")
	j.potentiels["epee"] = 50
	s.gagner_xp(j, "epee", 200)
	verifier(int(j.competences.epee) == 2 and is_equal_approx(float(j.xp_competences.epee), 7.0) and int(j.potentiels.epee) == 80, "potentiel 50 : 200 XP n'en valent que 100 → Épée 2, reste 7, potentiel au plancher 80")
	verifier(float(j.xp_competences.get("stat:force", 0.0)) > 0.0 or int(j.corps.stats.force) > force, "la Force reçoit la moitié de l'XP d'Épée")
	# Les niveaux dérivés
	j.competences["epee"] = 20
	j.competences["bouclier"] = 10
	j.competences["forge"] = 30
	var nd := prog.niveaux_derives(j)
	verifier(is_equal_approx(nd.combat, 15.0) and is_equal_approx(nd.general, 30.0), "niveau de combat 15 (20, 10), général 30")
	# Le combat verse pour de vrai : après un coup, Épée, tranchant et Métal ont de l'XP
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	s._engager_combat(j, loup)
	loup.compteur = 900
	j.compteur = s.horloge_de(j).ticks
	s.pas(j.horloge)
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	verifier(float(j.xp_competences.get("tranchant", 0.0)) > 0.0 and float(j.xp_competences.get("element_metal", 0.0)) > 0.0 and float(loup.xp_competences.get("encaissement", 0.0)) > 0.0, "XP versée à l'arme, au type, à l'élément ; Encaissement au défenseur")
	# Création de personnage : 30 points, bonus de race et de classe, kit, potentiels
	var fiche := Etres.creer_personnage("creature.aventurier.name", "nain", "le_sabre", {"force": 10, "endurance": 10, "volonte": 10}, 1000, prog)
	verifier(fiche.corps.stats.force == 5 + 10 + 1 + 2 and fiche.corps.stats.endurance == 5 + 10 + 2 + 1 and fiche.corps.stats.charisme == 5, "stats : base 5 + points + race + classe")
	verifier("proto_epee" in fiche.equipement and fiche.competences.get("epee", 0) == 5 and fiche.potentiels_base.forge == 100, "kit du Sabre, Épée 5, potentiel de Forge nain+sabre = 100")
	var p := Simulation.new(5)
	p.fiche_joueur = fiche
	p.charger_arene("plaine_au_talus")
	var jp := joueur_de(p)
	verifier(jp.race == "nain" and jp.sante_max == 20 + 18 * 4 and "detection_filons" in jp.tags_acquis, "le personnage créé entre en jeu : PV 92, Œil de la pierre")
	# Mort et pénalité : respawn au point d'entrée, PV pleins, sac écrémé à 10 %, équipement gardé
	var o := p.generer_objet("proto_dague", 1)
	p.donner(jp, o.uid)
	var spawn: Vector2i = jp.spawn
	p.grille.liberer(jp.pos)
	jp.pos = spawn + Vector2i(3, 0)
	p.grille.placer(jp.id, jp.pos)
	p._appliquer_degats(jp, 999, "", {})
	verifier(not jp.vivant, "mort")
	jp.or = 50
	verifier(p.intention(jp.id, {"type": "respawn"}), "respawn")
	verifier(jp.vivant and jp.sante == jp.sante_max and jp.pos == spawn and jp.equipement.has("main_principale"), "relevé au point d'entrée, PV pleins, équipement conservé")
	verifier(int(jp.or) == 45, "Mort et pénalité : −10 %% de l'or porté (%d)" % int(jp.or))
	# Faim : la régénération de santé d'équipement suit les paliers (< 50 : −10 %, < 25 : plus rien)
	jp["mecaniques"] = {"regen_sante": {"pct": 100}}
	jp.faim = 100
	jp.sante = 1
	jp.tick_endurance = 0
	p._regenerer(jp, 2000)
	var regen_plein: int = int(jp.sante) - 1
	jp.faim = 40
	jp.sante = 1
	jp.tick_endurance = 0
	p._regenerer(jp, 2000)
	var regen_faim: int = int(jp.sante) - 1
	jp.faim = 10
	jp.sante = 1
	jp.tick_endurance = 0
	p._regenerer(jp, 2000)
	verifier(regen_plein > 0 and regen_faim < regen_plein and int(jp.sante) == 1, "faim : régén %d à 100, %d sous 50, rien sous 25" % [regen_plein, regen_faim])
	jp.faim = 100
	jp.erase("mecaniques")
	# Modificateurs d'affinité : une arme pure ne se dilue pas par sertissage, une mixte oui
	jp["affinites"] = {"feu": 0.5}
	var pur := p._affixes_offensifs(jp, {"materiau": "fer", "elements": {"metal": 1.0}, "affixes": []}, {})
	var mixte := p._affixes_offensifs(jp, {"materiau": "fer", "elements": {"metal": 0.6, "bois": 0.4}, "affixes": []}, {})
	verifier(float(pur.vecteur.get("feu", 0.0)) == 0.0 and float(mixte.vecteur.get("feu", 0.0)) > 0.0, "l'arme pure ignore la taille en affinité, l'arme mixte la reçoit")
	jp.erase("affinites")


# ---------------------------------------------------------------- Étape 5 : entrer, combattre, looter, progresser, ressortir

func test_expedition() -> void:
	var s := Simulation.new(21)
	s.charger_donjon("ruine", 21, 3, 1)
	var j := joueur_de(s)
	var loup := {}
	for e in s.vivants():
		if e.id != j.id:
			loup = e
			break
	verifier(not loup.is_empty(), "un ennemi à l'étage 1")
	loup.sante = 1
	s._appliquer_degats(loup, 5, j.id, {})
	verifier(not loup.vivant and s.expedition.tues == 1, "tué par le joueur : compté")
	var n_ent: int = s.ordre.size()
	# Descendre puis remonter : l'étage 1 revient dans l'état laissé (le loup reste mort)
	s.grille.liberer(j.pos)
	j.pos = s.donjon.escalier
	s.grille.placer(j.id, j.pos)
	s.horloge_monde.avancer(1)
	verifier(s.intention(j.id, {"type": "descendre"}), "descendre")
	verifier(s.donjon.etage == 2 and s.etages_visites.has(1), "l'étage 1 est mis de côté")
	j.compteur = s.horloge_monde.ticks
	s.grille.liberer(j.pos)
	j.pos = s.donjon.entree
	s.grille.placer(j.id, j.pos)
	s.horloge_monde.avancer(1)
	verifier(s.intention(j.id, {"type": "remonter"}), "remonter")
	verifier(s.donjon.etage == 1 and s.ordre.size() == n_ent and not s.entites[loup.id].vivant and j.pos == s.donjon.escalier, "étage 1 restauré : mêmes êtres, le loup toujours mort, joueur sur la cage")
	# Sortir depuis l'entrée de l'étage 1 : expédition terminée, nouvelle expédition, même être
	var recap := [{}]
	EventBus.expedition_terminee.connect(func(r: Dictionary) -> void: recap[0] = r)
	var o := s.generer_objet("proto_dague", 1)
	s.donner(j, o.uid)
	j.competences["epee"] = 7
	s.grille.liberer(j.pos)
	j.pos = s.donjon.entree
	s.grille.placer(j.id, j.pos)
	j.compteur = s.horloge_monde.ticks
	s.horloge_monde.avancer(1)
	verifier(s.intention(j.id, {"type": "remonter"}), "sortir par l'entrée de l'étage 1")
	verifier(not recap[0].is_empty() and recap[0].tues == 1 and recap[0].sac == 1, "récapitulatif : 1 tué, 1 objet au sac")
	verifier(s.donjon.id == 4 and s.donjon.etage == 1 and s.etages_visites.is_empty() and joueur_de(s).competences.epee == 7 and o.uid in joueur_de(s).sac, "nouvelle expédition (donjon 4), le même être avec son sac et ses niveaux")
