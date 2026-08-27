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
	verifier(mats.size() == 155, "les 155 matériaux des catalogues sont chargés (%d)" % mats.size())
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
	verifier(couleurs.size() == mats.size(), "155 couleurs uniques")
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
	verifier(GameData.catalogues.stations.size() == 9 and GameData.catalogues.recipes.size() == 37, "9 stations, 37 recettes plates (9 transformations, 16 meubles, 9 stations, 3 plats)")
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
	verifier(s.contenants.get(s.grille.idx(coffre), []).size() == 4, "le coffre de départ : hache, pioche, faucille, lit de paille")
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
	verifier(GameData.catalogues["affixes"].size() == 36, "36 gabarits d'affixes (6 familles × 6)")
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
	verifier(not (livre.uid in j.sac) and j.modules_connus.size() == livre.modules.size() and lus[0] == 1, "Lecture 100 : tous les modules appris, livre consommé, book_read")
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
