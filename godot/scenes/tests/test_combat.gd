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
	test_donjon()
	test_loot()
	test_coffres_et_rares()
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


# ---------------------------------------------------------------- Étape 2 : génération de donjon

func test_donjon() -> void:
	var gen := Donjon.new(GameData.catalogues["dungeon_rooms"], GameData.catalogues["dungeon_connectors"], GameData.entree("dungeon_themes", "ruine"))
	verifier(GameData.catalogues["dungeon_rooms"].size() == 12 and GameData.catalogues["dungeon_connectors"].size() == 8, "bibliothèque : 12 salles + 8 connecteurs")
	var t0 := Time.get_ticks_usec()
	var e := gen.generer_etage(42, 1, 1, 12, false)
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	var e2 := gen.generer_etage(42, 1, 1, 12, false)
	verifier(e.pieces.size() == e2.pieces.size() and e.spawns.size() == e2.spawns.size() and e.hauteurs == e2.hauteurs, "déterministe à seed égale")
	verifier(gen._nb_salles(e) >= 4, "au moins 4 salles placées (%d)" % gen._nb_salles(e))
	verifier(dt < 100.0, "étage généré en %.1f ms (< 100 ms, critère É2)" % dt)
	# Aucun chevauchement de pièces
	var ok := true
	for i in e.pieces.size():
		for k in range(i + 1, e.pieces.size()):
			if e.pieces[i].rect.intersects(e.pieces[k].rect):
				ok = false
	verifier(ok, "aucun chevauchement de pièces")
	# Connexité : toutes les tuiles de sol de toutes les salles sont atteignables depuis l'entrée
	var g := Grille.depuis_etage(e, GameData.config("tile_contents"), GameData.config("combat_rules").deplacement, 1)
	var atteint := g.atteignables(e.entree, 100000)
	var manquantes := 0
	for p in e.pieces:
		var c := gen._centre_libre(e, p)
		if not atteint.has(c):
			manquantes += 1
	verifier(manquantes == 0, "connexité par construction : chaque pièce est atteignable depuis l'entrée (%d manquantes)" % manquantes)
	verifier(e.escalier != null and atteint.has(e.escalier), "un escalier vers l'étage suivant, atteignable")
	# Dernier étage : boss dans la salle la plus lointaine
	var fin := gen.generer_etage(42, 1, 2, 10, true)
	verifier(fin.boss != null and fin.escalier == null, "dernier étage : boss, pas d'escalier")
	var a_boss := false
	for sp in fin.spawns:
		if sp.creature == "chef_de_bande":
			a_boss = true
	verifier(a_boss and fin.spawns.size() > 1, "le boss du thème et des créatures du pool sont posés")
	# En simulation : charger, descendre avec son état
	var s := Simulation.new(7)
	s.charger_donjon("ruine", 7, 1, 1)
	var j := joueur_de(s)
	verifier(not j.is_empty() and s.donjon.etage == 1 and s.grille.bloque_passage(Vector2i(0, 0)), "donjon chargé : le plein est de la roche, le joueur à l'entrée")
	j.sante = 30
	s.grille.liberer(j.pos)
	j.pos = s.donjon.escalier
	s.grille.placer(j.id, j.pos)
	s.horloge_monde.avancer(1)
	verifier(s.intention(j.id, {"type": "descendre"}), "descendre depuis la cage d'escalier")
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
