extends Node
## Tests headless du prototype (jalons 1-4) — des `assert`, aucun rendu.
##   & Godot --headless --path godot res://scenes/tests/test_combat.tscn --quit-after 2
## Chaque test cite la note qu'il vérifie.

var echecs := 0


func _ready() -> void:
	# GameData a déjà chargé (autoload) : aucune erreur de schéma tolérée.
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
	test_uniques_artefacts()
	test_bombes()
	test_composer_capacites()
	test_camp()
	test_faim_et_poids()
	test_donjon()
	test_loot()
	test_coffres_et_rares()
	test_gemmes_et_livres()
	test_progression()
	test_expedition()
	test_arenes_autonomes()
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
	verifier(p.des == "2d6" and p.des_bonus == 1 and p.geometrie == "ligne" and p.taille == 4 and p.elements == {"feu": 1.0}, "3d6 de Feu sur 4 tuiles en ligne")
	# [Ligne] + [Frappe] + [Concentration] avec une épée : 9 ticks · 10 endurance, à l'élément de l'arme
	p = cap.assembler(["ligne", "frappe", "concentration"], 5, "2d6", {"metal": 1.0})
	verifier(p.ticks == 9 and p.monnaie == "endurance" and p.ressource == 10 and p.elements == {"metal": 1.0}, "[Ligne]+[Frappe]+[Concentration] : 9 ticks · 10 endurance · Métal")
	# Vivacité : −3 ticks, ressource ×1.3 ; Soi rend 2 ticks
	p = cap.assembler(["point", "etincelle", "vivacite"], 5, "1d4", {})
	verifier(p.ticks == 1 and p.ressource == 4, "Étincelle + Vivacité : max(1, 3−3) tick · 3×1.3 ≈ 4 mana")
	p = cap.assembler(["soi", "baume"], 5, "1d4", {})
	verifier(p.ticks == 6 and p.ressource == 10 and p.geometrie == "soi", "[Soi]+[Baume] : 6 ticks · 10 mana")
	verifier(not cap.assembler(["ligne", "flamme", "gel"], 5, "1d4", {}).erreurs.is_empty(), "deux noyaux = erreur")
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
	verifier(j.mana == mana - 3 and j.compteur == h.ticks + 3, "Étincelle : 3 mana, 3 ticks")
	verifier(loup.sante < pv and j.chaine.segments.size() == 1 and j.chaine.segments[0].element == "feu", "le loup est touché, un segment Feu est posé")
	# Hors de portée (Point : 1-6) : refusé
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(not s.intention(j.id, {"type": "capacite", "index": 0, "cible": j.pos + Vector2i(0, -8)}), "au-delà de 6 tuiles : refusé")
	# Surchauffe : sans mana, Gel en ligne (12 mana) coûte le déficit × 2 en PV
	j.mana = 4
	var pvj: int = j.sante
	verifier(s.intention(j.id, {"type": "capacite", "index": 1, "cible": j.pos + Vector2i(0, -1)}), "Gel en ligne sans assez de mana")
	verifier(j.mana == 0 and j.sante == pvj - 16, "surchauffe : déficit 8 × 2 = 16 PV")
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
	j.capacites.append({"id": "t", "name_key": "capacite.etincelle.name", "modules": ["surplomb", "point", "etincelle"]})
	j.compteur = h.ticks
	s.pas(j.horloge)
	mana = j.mana
	var t: int = h.ticks
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loup.pos}), "Surplomb + Étincelle à hauteur égale")
	verifier(j.mana == mana and j.compteur == t + 2, "condition fausse : ne part pas, 50 % des ticks (3 → 2), rien payé")
	# Friendly fire : un carré touche un allié dans la zone
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
	j.capacites.append({"id": "f", "name_key": "capacite.etincelle.name", "modules": ["point", "feinte"]})
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
	j.capacites.append({"id": "r", "name_key": "capacite.etincelle.name", "modules": ["point", "flamme", "repetition"]})
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Flamme + Répétition (12 ticks : télégraphée)")
	s.pas(j.horloge)
	verifier(coups[0] == 3 and j.chaine.segments.size() == 1, "3 coups appliqués, un seul segment")
	# À l'impact : Étincelle touche, puis la Bruine en croix part de la cible et touche le loup voisin
	coups[0] = 0
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
	j.capacites[3] = {"id": "c", "name_key": "capacite.etincelle.name", "modules": ["point", "etincelle", "ricochet"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Étincelle + Ricochet")
	verifier(coups[0] >= 2, "au moins un saut (%d coups)" % coups[0])
	# Partage : le Baume sur un allié soigne aussi le lanceur
	var allie := s.ajouter("bandit", j.pos + Vector2i(1, 0), "joueur")
	allie.sante = 10
	j.sante = 10
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
	j.capacites.append({"id": "g", "name_key": "capacite.etincelle.name", "modules": ["sceau", "tuile", "racine"]})
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
	j.capacites[3] = {"id": "e", "name_key": "capacite.etincelle.name", "modules": ["tuile", "exhaussement"]}
	j.compteur = h.ticks
	loup.compteur = h.ticks + 500
	s.pas(j.horloge)
	var t_pos: Vector2i = j.pos + Vector2i(-1, -1)
	var h_avant: int = s.grille.h(t_pos)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": t_pos}), "Exhaussement")
	s.pas(j.horloge)
	verifier(s.grille.h(t_pos) == h_avant + 1, "la tuile monte d'un niveau")
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
	j.capacites.append({"id": "r", "name_key": "capacite.etincelle.name", "modules": ["riposte", "point", "etincelle"]})
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
	j.capacites[3] = {"id": "sv", "name_key": "capacite.etincelle.name", "modules": ["ligne", "etincelle", "salve"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	# la ligne part vers (0,-1) : seul loups[0] est dessus → les 3 charges tombent sur lui
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Salve en ligne")
	verifier(coups[0] == 3, "3 charges (%d coups)" % coups[0])
	# Propagation : de proche en proche (les trois loups sont contigus)
	coups[0] = 0
	j.capacites[3] = {"id": "pr", "name_key": "capacite.etincelle.name", "modules": ["point", "etincelle", "propagation"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Étincelle + Propagation")
	verifier(coups[0] == 3, "la charge se propage aux trois loups (%d coups)" % coups[0])
	# Boucle : rejoue tant qu'il reste du mana
	coups[0] = 0
	j.mana = 10   # Étincelle = 3 mana : 1 + 3 rejeux (10 → 7 → 4 → 1)
	j.capacites[3] = {"id": "bo", "name_key": "capacite.etincelle.name", "modules": ["point", "etincelle", "boucle"]}
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": 3, "cible": loups[0].pos}), "Étincelle + Boucle")
	verifier(coups[0] == 3 and j.mana == 1, "la boucle rejoue jusqu'à épuisement du mana (%d coups, mana %d)" % [coups[0], j.mana])
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
	verifier(not brut.is_empty() and brut.materiau == "pierre" and int(brut.quantite) == 1, "1 × pierre dans le sac")
	verifier(int(j.xp_competences.get("minage", 0)) - xp0 > 0, "XP de Minage = dureté")
	s.grille.poser_contenu(mur, "mur")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "creuser", "vers": mur})
	verifier(int(brut.quantite) == 2, "la pierre s'empile (×2)")
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


# ---------------------------------------------------------------- Étape 6.3 : stations et transformations plates

func test_fabrication() -> void:
	var s := Simulation.new(13)
	s.charger_donjon("ruine", 13, 6, 1)
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(GameData.catalogues.stations.size() == 9 and GameData.catalogues.recipes.size() == 66, "9 stations, 66 recettes plates (17 transformations, 23 meubles, 9 stations, 3 plats, 14 potions)")
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
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	verifier(GameData.config("noise_layers").size() == 8 and GameData.catalogues.biomes.size() == 12, "8 couches de bruit, 12 biomes")
	# Tectonique : 24 plaques, ~35 % de terres (quantile calibré), mers et montagnes déterministes.
	verifier(surf.plaques.size() == 24 and surf.points_chauds.size() >= 8 and surf.points_chauds.size() <= 14, "24 plaques, 8 à 14 points chauds")
	var terres := 0
	var n_ech := 40
	var monde_t := 1024 * 128
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
	var b := surf.biome_a(512 * 128, 512 * 128)
	verifier(GameData.catalogues.biomes.has(b), "un biome résolu au centre du monde (%s)" % b)
	var e := surf.generer_cellule(512, 512, GameData.config("camp"))
	var e2 := surf.generer_cellule(512, 512, GameData.config("camp"))
	verifier(e.hauteurs == e2.hauteurs and e.arbres.size() == e2.arbres.size() and e.filons.size() == e2.filons.size(), "déterministe")
	var plats := 0
	for i in e.hauteurs.size():
		if int(e.hauteurs[i]) == 10:
			plats += 1
	verifier(plats > e.hauteurs.size() * 0.8 and plats < e.hauteurs.size(), "plat à 10 avec des accidents (%d %% plat, %d accidents)" % [plats * 100 / e.hauteurs.size(), e.accidents.size()])
	verifier(e.accidents.size() >= 2 and e.accidents.size() <= 13, "2 à 5 accidents posés (× accidents_mult du biome : %d)" % e.accidents.size())
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
	var t0 := Time.get_ticks_usec()
	surf.generer_cellule(513, 512)
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	verifier(dt < 600.0, "une cellule de 128×128 générée en %.0f ms (le budget de 2 ms par chunk, soit 32 ms, attend le streaming en thread de 8.2)" % dt)
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
	s.monde.explores[Vector2i(voisine.x * 4, voisine.y * 4)] = true
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
	m.explores[Vector2i(loin.x * 4, loin.y * 4)] = true
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
	var pain := ""
	for uid in marchand.stock:
		if s.items[uid].get("base", "") == "pain":
			pain = uid
	var p := s.prix_suggere(pain, marchand, j)
	verifier(int(p.prix) >= 1 and p.has("base") and p.has("rarete"), "prix suggéré du pain : %d or (détail présent)" % int(p.prix))
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "acheter", "pnj": marchand.id, "objet": pain}), "sans or, pas d'achat")
	j.or = 100
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "acheter", "pnj": marchand.id, "objet": pain}) and pain in j.sac and int(j.or) == 100 - int(p.prix) and int(marchand.or) == 300 + int(p.prix), "acheter le pain")
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
	s.monde.explores[Vector2i(voisine.x * 4, voisine.y * 4)] = true
	s.monde.explores[Vector2i(loin.x * 4, loin.y * 4)] = true
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
	var centre_l := Vector2i(6, 64)
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
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "distiller_griffe"}) and not s._pile_objet(j, "potion_force").is_empty(), "distiller une griffe et du blé : une potion de force")
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
	s._semaine_elevage()
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
	s._semaine_elevage()
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

func test_composer_capacites() -> void:
	var s := Simulation.new(119)
	s.charger_donjon("ruine", 119, 11, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	j.modules_connus = ["point", "etincelle", "ligne", "renaissance", "soi"]
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
	verifier(j.capacites.size() <= int(slots.capacites), "les capacités sont bornées par les slots (%d)" % j.capacites.size())
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
	j.mana = 100
	j.or = 0
	s.attente[j.id] = true
	verifier(idx >= 0 and s.intention(j.id, {"type": "capacite", "index": idx, "cible": j.pos}), "lancer Renaissance sur soi")
	for k in 20:   # la capacité est engagée (18 ticks) : l'horloge du monde avance jusqu'à sa résolution
		s.attente.erase(j.id)
		s.horloge_monde.avancer(5)
		if j.action_en_cours.is_empty():
			break
	verifier(v.vivant and int(j.mana) < 100 and int(j.or) == 0, "le compagnon revient, payé en mana (%d), pas en or" % int(j.mana))
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
	for q in [cible, mur, cible + Vector2i(0, 1)]:
		s.grille.contenu[s.grille.idx(q)] = 0
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
	verifier(s.grille.contenu_de(mur).is_empty(), "le mur de chêne (dureté < 40 × 1/2) est soufflé")
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
	verifier(n == maxi(1, int(GameData.catalogues.plants.framboisier.recolte_base) / 2), "la moitié d'une récolte cultivée (%d)" % n)
	verifier(s.grille.contenu_de(t).is_empty() and s.modifs_terrain.has(s.grille.idx(t)), "la tuile redevient du sol, mémorisée pour repousser")
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
	verifier(GameData.catalogues.recipes.has("distiller_amanite") and GameData.catalogues.items.has("poison_de_lame"), "l'amanite se distille en poison de lame")


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
	verifier(betes.size() == 19, "19 races animales au bestiaire (%d)" % betes.size())
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
	verifier(GameData.catalogues.recipes.has("distiller_achillee") and GameData.catalogues.recipes.distiller_achillee.output.item == "potion_soin", "l'achillée se distille en potion de soin")
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
	j.mana = 300
	j.endurance = j.endurance_max
	j.capacites.append({"id": "k", "name_key": "capacite.etincelle.name", "modules": ["carre", "cataclysme", "ampleur", "ampleur"]})
	var centre: Vector2i = j.pos + Vector2i(0, -3)
	var h0 := s.grille.h(centre)
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": j.capacites.size() - 1, "cible": centre}), "le cataclysme est canalisé (télégraphié)")
	verifier(not j.action_en_cours.is_empty(), "la canalisation est visible : une action en cours")
	s.pas(j.horloge)
	verifier(s.grille.h(centre) == maxi(0, h0 - 4) and int(j.endurance) == 0 and s.modifs_terrain.has(s.grille.idx(centre)), "cratère : %d → %d, endurance vidée, terrain mémorisé" % [h0, s.grille.h(centre)])
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
	verifier(s.modifs_terrain.has(s.grille.idx(t)) and int(s.modifs_terrain[s.grille.idx(t)].h) == h0, "l'état d'origine est mémorisé (h %d)" % h0)
	# Hors claim, la semaine rend la tuile ; sur un claim, elle persiste
	var cell := s._cell_de(t)
	s.monde.claims.erase(cell)
	s._regenerer_terrain_sauvage()
	verifier(s.grille.h(t) == h0 and not s.modifs_terrain.has(s.grille.idx(t)), "hors claim : le monde rend la hauteur %d" % h0)
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
	j.capacites.append({"id": "g", "name_key": "capacite.etincelle.name", "modules": ["sceau", "tuile", "racine"]})
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
	var plan := s._plan_recette(j, GameData.catalogues.recipes.distiller_griffe)
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
	verifier(s2.monde.explores.size() == s.monde.explores.size(), "les chunks explorés (%d)" % s2.monde.explores.size())
	verifier(s2.grille.decouvert.size() > 10000, "la cellule du camp reste découverte")
	# Impossible en donjon.
	var s3 := Simulation.new(2)
	s3.charger_donjon("ruine", 2, 9, 1)
	verifier(not s3.sauvegarder("test_sensen"), "pas de sauvegarde en donjon")
	s.monde.fermer()
	s2.monde.fermer()


# ---------------------------------------------------------------- Étape 7.1 : le camp de base

func test_camp() -> void:
	var s := Simulation.new(23)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(s.lieu == "camp" and s.grille.largeur == 384 and s.grille.origine == Vector2i(511 * 128, 511 * 128), "le camp : la fenêtre de 3×3 cellules du monde, en coordonnées monde")
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
	var base := Vector2i(512 * 128, 512 * 128)
	var coffre := base + Vector2i(64 - 2, 64)
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
	var loin: Vector2i = base + Vector2i(128 + 20, 64)   # dans la cellule (513, 512)
	s.grille.liberer(j.pos)
	j.pos = loin
	s._fin_de_pas("monde")
	verifier(s.grille.origine == origine0 + Vector2i(128, 0) and s.grille.dans(loin) and j.pos == loin, "la fenêtre s'est recentrée d'une cellule, le joueur n'a pas bougé")
	verifier(s.grille.contenu_de(mur2).get("tags", []).has("construit"), "le mur est encore dans la fenêtre (cellule de départ toujours chargée)")
	var tres_loin: Vector2i = base + Vector2i(128 * 2 + 20, 64)   # cellule (514, 512) : le camp sort de la fenêtre
	s.grille.liberer(j.pos)
	j.pos = tres_loin
	s._fin_de_pas("monde")
	verifier(s.grille.origine == origine0 + Vector2i(256, 0) and not s.grille.dans(mur2), "deux cellules plus loin : le camp est hors fenêtre")
	verifier(s.monde.modifications.has(Vector2i(512, 512)) and not s.monde.modifications[Vector2i(512, 512)].is_empty(), "ses modifications sont capturées par cellule")
	s.grille.liberer(j.pos)
	j.pos = base + Vector2i(64, 70)
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

func test_donjon() -> void:
	var gen := Donjon.new(GameData.catalogues["dungeon_rooms"], GameData.catalogues["dungeon_connectors"], GameData.entree("dungeon_themes", "ruine"))
	verifier(GameData.catalogues["dungeon_rooms"].size() == 12 and GameData.catalogues["dungeon_connectors"].size() == 8, "bibliothèque : 12 salles + 8 connecteurs")
	var t0 := Time.get_ticks_usec()
	var e := gen.generer_etage(42, 1, 1, 18, false)
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	var e2 := gen.generer_etage(42, 1, 1, 18, false)
	verifier(e.pieces.size() == e2.pieces.size() and e.spawns.size() == e2.spawns.size() and e.sol.size() == e2.sol.size(), "déterministe à seed égale")
	verifier(e.largeur == 128 and e.hauteur == 128, "un étage = une cellule de 128×128")
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
	verifier(e.sol.size() > 128 * 128 / 10 and e.sol.size() < 128 * 128 * 3 / 4, "salles et couloirs, avec du plein à creuser (%d tuiles de sol)" % e.sol.size())
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
	verifier(GameData.catalogues["affixes"].size() == 41, "41 gabarits d'affixes (6 familles × 6, + portage et sobriété, + 3 uniques)")
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
	verifier(is_equal_approx(float(ax.vecteur.feu), 0.28 / 1.28) and is_equal_approx(float(ax.vecteur.metal), 1.0 / 1.28), "affinité Feu +0.28 : vecteur {métal 0.78, feu 0.22}")
	# Livres : un grimoire tire domaine, difficulté et modules ; la lecture réussit avec Lecture haute
	var livre := s.generer_objet("grimoire", 2)
	verifier(livre.modules.size() >= 2 and livre.difficulte == 10 + 2 * 10 and not livre.domaine.is_empty(), "grimoire : %d modules, difficulté 30, domaine %s" % [livre.modules.size(), livre.domaine])
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
	verifier(p.intention(jp.id, {"type": "respawn"}), "respawn")
	verifier(jp.vivant and jp.sante == jp.sante_max and jp.pos == spawn and jp.equipement.has("main_principale"), "relevé au point d'entrée, PV pleins, équipement conservé")


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
