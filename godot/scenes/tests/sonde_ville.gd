extends Node
## La sonde des villes (Villes — population, quartiers et économie, B1, 2026-09-05). Autour du camp d'une graine :
## les agglomérations à portée par palier, la plus grande en détail — ses cellules et leurs quartiers, ses bâtiments,
## ses lits contre sa population, ses boutiques et ses halls, ses rues (chaque porte rejoint le croisement), le temps
## de génération de chaque cellule contre le budget ; puis la fenêtre chargée dessus : ses résidents par fonction,
## ses périmètres, ses stocks ; puis des semaines qui passent comme dans une partie.
##   godot --headless --path godot res://scenes/tests/sonde_ville.tscn -- --graine_monde 9 --semaines 4

const GrandeBase := preload("res://scenes/tests/grande_base.gd")

var soucis: Array[String] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var graine := 9
	var semaines := 4
	var rayon := 60
	for i in args.size():
		if args[i] == "--graine_monde" and i + 1 < args.size():
			graine = int(args[i + 1])
		elif args[i] == "--semaines" and i + 1 < args.size():
			semaines = int(args[i + 1])
		elif args[i] == "--rayon" and i + 1 < args.size():
			rayon = int(args[i + 1])
	var cfg: Dictionary = GameData.config("villes")
	var ordre: Array = cfg.ordre_paliers
	var s := Simulation.new(graine)
	s.graine_monde = graine   # la graine du MONDE (sans elle, toutes les graines donnaient la même ville)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var c0: Vector2i = s.monde.cellule_camp
	# 1. Les agglomérations à portée, par palier ; la plus grande.
	var compte := {}
	var meilleure: Dictionary = {}
	for r in range(1, rayon + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var cv := c0 + Vector2i(dx, dy)
				if not (surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false))):
					continue
				var f: Dictionary = surf.fiche_agglomeration(cv)
				compte[str(f.palier)] = int(compte.get(str(f.palier), 0)) + 1
				if meilleure.is_empty() or ordre.find(str(f.palier)) > ordre.find(str(meilleure.palier)) or (str(f.palier) == str(meilleure.palier) and int(f.population) > int(meilleure.population)):
					meilleure = f
	print("VILLES — monde %d, agglomérations à %d cellules du camp : %s" % [graine, rayon, str(compte)])
	if meilleure.is_empty():
		print("SONDE VILLE : aucune agglomération — rien à mesurer")
		get_tree().quit()
		return
	var f := meilleure
	print("la plus grande : %s, %s de %d habitants, %d cellule(s), royaume « %s »%s, gouvernance « %s », culture %s" % [str(f.nom), str(f.palier), int(f.population), f.cellules.size(), str(f.royaume), " (capitale)" if bool(f.capitale) else "", str(f.gouvernance), str(f.culture)])
	print("  boutiques par cellule : %s · halls : %s" % [str(f.boutiques), str(f.halls)])
	var fourchette: Array = cfg.paliers[str(f.palier)].pop
	if int(f.population) < int(fourchette[0]) or int(f.population) > int(fourchette[1]):
		soucis.append("population %d hors de la fourchette du palier %s" % [int(f.population), str(f.palier)])
	# 2. Chaque cellule générée : cohérence de l'emprise, bâtiments, lits, rues, temps.
	var budget := float(cfg.get("budget_ms_cellule", 120))
	var lits_total := 0
	var pnj_total := 0
	for k in f.cellules.size():
		var c: Vector2i = f.cellules[k]
		var t0 := Time.get_ticks_usec()
		var e: Dictionary = surf.generer_cellule(c.x, c.y, {}, false)
		var dt := (Time.get_ticks_usec() - t0) / 1000.0
		var v: Dictionary = e.get("village", {})
		var a: Dictionary = surf.agglomeration_de(c)
		if v.is_empty() or str(a.get("nom", "")) != str(f.nom) or str(a.get("quartier", "")) != str(f.quartiers[k]) or str(v.get("quartier", "")) != str(f.quartiers[k]):
			soucis.append("cellule %s : l'emprise n'est pas d'accord avec la fiche (%s / %s)" % [str(c), str(a.get("quartier", "?")), str(f.quartiers[k])])
			continue
		var par_id := {}
		var lits := 0
		var portes_jointes := 0
		var atteint := _atteignable(e, Vector2i(e.largeur / 2, e.largeur / 2))
		for bat in v.batiments:
			par_id[str(bat.id)] = int(par_id.get(str(bat.id), 0)) + 1
			lits += bat.lits.size()
			var porte: Vector2i = bat.porte
			var voisines := 0
			for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var q: Vector2i = porte + d
				if atteint.has(q.y * e.largeur + q.x):
					voisines += 1
			if voisines > 0:
				portes_jointes += 1
		var fonctions := {}
		for pj in v.pnj:
			fonctions[str(pj.get("fonction", "?"))] = int(fonctions.get(str(pj.get("fonction", "?")), 0)) + 1
		var per_types := {}
		for per in v.territoire.perimetres:
			per_types[str(per.type)] = int(per_types.get(str(per.type), 0)) + per.tuiles.size()
		lits_total += lits
		pnj_total += v.pnj.size()
		print("  cellule %s · %s · %d habitants prévus · %d bâtiments %s · %d lits · %d PNJ %s · rues : %d/%d portes jointes · périmètres %s · %d stations · %d champs · %d bêtes · %.0f ms" % [str(c), str(v.quartier), int(v.population_quartier), v.batiments.size(), str(par_id), lits, v.pnj.size(), str(fonctions), portes_jointes, v.batiments.size(), str(per_types), e.get("stations", {}).size(), v.get("champs", []).size(), v.get("betes", []).size(), dt])
		if lits < int(v.population_quartier):
			soucis.append("cellule %s (%s) : %d lits pour %d habitants" % [str(c), str(v.quartier), lits, int(v.population_quartier)])
		if portes_jointes < v.batiments.size():
			soucis.append("cellule %s : %d porte(s) sur %d ne rejoignent pas la rue" % [str(c), v.batiments.size() - portes_jointes, v.batiments.size()])
		if dt > budget:
			soucis.append("cellule %s : %.0f ms, budget %.0f" % [str(c), dt, budget])
		if v.batiments.size() == 0:
			soucis.append("cellule %s : aucun bâtiment" % str(c))
	print("  total : %d lits, %d PNJ prévus pour %d habitants" % [lits_total, pnj_total, int(f.population)])
	# 3. La fenêtre chargée sur la ville : le territoire, ses résidents, ses périmètres, ses stocks.
	var s2 := Simulation.new(graine)
	s2.graine_monde = graine
	s2.charger_camp({}, Vector2i(f.centre) + Vector2i(2, 0))
	var j: Dictionary = s2.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_sub: int = s2.monde.taille / 32
	for cy in n_sub:
		for cx in n_sub:
			s2.monde.explores[Vector2i(int(f.centre.x) * n_sub + cx, int(f.centre.y) * n_sub + cy)] = true
	s2.voyager(j, f.centre)
	s2.invincible = true
	var nom := str(f.nom)
	if not s2.territoires.has(nom):
		soucis.append("la ville chargée n'a pas de territoire")
		_fin()
		return
	var t: Dictionary = s2.territoires[nom]
	var rapport: Dictionary = s2._dans_territoire(nom, func() -> Dictionary: return _etat(s2))
	print("territoire « %s » : %d cellule(s) chargée(s) %s · propriétaire %s · trésor %d" % [nom, t.cellules.size(), str(t.cellules.keys()), str(t.proprietaire), int(t.tresor)])
	print("  résidents %d : %s · périmètres %s · stocks %s" % [int(rapport.residents), str(rapport.fonctions), str(rapport.perimetres), str(rapport.stocks)])
	if int(rapport.residents) == 0:
		soucis.append("aucun résident dans le territoire de la ville")
	if s2.territoire.id != "joueur":
		soucis.append("le contexte n'est pas revenu au joueur")
	# 4. Le tempo : deux cents ticks du monde à l'allure du jeu, le coût d'un tick (le client en paie dix par seconde).
	for k in 300:   # la ruée du premier matin (tout le monde part vers son poste) n'est pas le régime de croisière
		s2.horloge_monde.avancer(1)
	var t_tempo := Time.get_ticks_usec()
	s2.chrono.clear()
	for k in 200:
		s2.horloge_monde.avancer(1)
	var ms_tick := (Time.get_ticks_usec() - t_tempo) / 1000.0 / 200.0
	print("tempo : %.2f ms par tick du monde avec %d êtres (pas %.0f ms sur 200 ticks) · chrono %s" % [ms_tick, s2.vivants().size(), float(s2.chrono.get("pas", 0.0)), str(s2.chrono)])
	var budget_tick := float(GameData.config("combat_rules").get("tempo", {}).get("ms_max_par_image", 12))
	if ms_tick > budget_tick:
		soucis.append("tempo : %.2f ms par tick, plus que le budget d'une image (%.0f)" % [ms_tick, budget_tick])
	# 5. Les semaines.
	var journal: Array = []
	EventBus.journal.connect(func(cle: String, params: Dictionary) -> void: journal.append({"cle": cle, "params": params}))
	for w in semaines:
		s2.chrono.clear()
		var etat := GrandeBase.semaine(s2, journal, j)
		var r2: Dictionary = s2._dans_territoire(nom, func() -> Dictionary: return _etat(s2))
		var cles := {}
		for l in journal:
			cles[str(l.cle)] = int(cles.get(str(l.cle), 0)) + 1
		print("  semaine %d (%.0f ms) : résidents %d · stocks %s · trésor %d · dette %d · rapport %s · journal %s" % [w + 1, float(etat.get("ms", 0.0)), int(r2.residents), str(r2.stocks), int(t.tresor), int(t.dette), str(t.rapports.back().get("prod", "?")) if not t.rapports.is_empty() else "—", str(cles)])
		print("    prix : %s · trésor du royaume %s" % [str(t.get("prix", {})), str(s2.monde.tresors_royaumes)])
		print("    chrono (ms) : %s" % str(s2.chrono))
		if int(r2.residents) == 0:
			soucis.append("semaine %d : plus aucun résident" % (w + 1))
	_fin()


func _etat(s2: Simulation) -> Dictionary:
	var fonctions := {}
	for x in s2.residents():
		fonctions[str(x.fonction)] = int(fonctions.get(str(x.fonction), 0)) + 1
	var betes := 0
	for x in s2.vivants():
		if str(x.get("betail", "")) == str(s2.territoire.id):
			betes += 1
	var mures := 0
	for pm in s2.territoire.cultures.keys():
		if bool(s2.territoire.cultures[pm].get("mure", false)):
			mures += 1
	fonctions["(bêtes)"] = betes
	fonctions["(parcelles)"] = s2.territoire.cultures.size()
	fonctions["(mûres)"] = mures
	var pers := {}
	for pid in s2.perimetres().keys():
		var p: Dictionary = s2.perimetres()[pid]
		pers[str(p.type)] = int(pers.get(str(p.type), 0)) + 1
	return {"residents": s2.residents().size(), "fonctions": fonctions, "perimetres": pers, "stocks": s2.territoire.stocks.duplicate()}


## Les tuiles de sol atteignables depuis `depuis` à quatre voisines (les portes comprises, les murs non).
func _atteignable(e: Dictionary, depuis: Vector2i) -> Dictionary:
	var taille: int = e.largeur
	var vus := {}
	var file: Array = [depuis]
	vus[depuis.y * taille + depuis.x] = true
	while not file.is_empty():
		var p: Vector2i = file.pop_front()
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var q: Vector2i = p + d
			var i := q.y * taille + q.x
			if q.x < 0 or q.y < 0 or q.x >= taille or q.y >= taille or vus.has(i):
				continue
			if e.murs.has(i) or e.eau.has(i) or not (e.sol.has(i) or e.portes.has(i)):
				continue
			vus[i] = true
			file.append(q)
	return vus


func _fin() -> void:
	for s in soucis:
		print("  souci : " + s)
	print("SONDE VILLE : %s" % ("rien à signaler" if soucis.is_empty() else "%d souci(s)" % soucis.size()))
	get_tree().quit(0 if soucis.is_empty() else 1)
