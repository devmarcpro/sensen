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
	verifier(p.resout and is_equal_approx(p.bonus_total, 1.40) and is_equal_approx(p.multiplicateur, 2.40), "rotation parfaite : 4 × 0.35 → ×2.40")
	verifier(is_equal_approx(p.gain, 1.20), "gain intermédiaire : +5 %% × 4 segments")
	w.poser(j, "eau", t)
	verifier(j.segments.is_empty(), "le résolveur vide la barre")
	# Construction / détonation : 4 × même élément puis l'engendré → +0.65 → ×1.65
	j = w.jauge_neuve()
	for i in 4:
		w.poser(j, "metal", i * 3)
	p = w.prevoir(j, "eau")
	verifier(p.resout and is_equal_approx(p.multiplicateur, 1.65), "construction/détonation : 3 × 0.10 + 0.35 → ×1.65")
	verifier(is_equal_approx(w.prevoir(j, "feu").multiplicateur, 1.50), "hors ordre : 3 × 0.10 + 0.20 → ×1.50")
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
	verifier(j.equipement.main_principale == "proto_masse" and j.compteur == t + 4, "swap : 4 ticks")
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
