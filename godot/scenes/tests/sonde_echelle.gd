extends Node
## La sonde d'échelle (Modules de la simulation et le C++, section 2, 2026-09-05) — « je veux pouvoir simuler le plus de
## systèmes possible sur énormément de PNJ et de terrain ». Elle charge la plus grande agglomération d'un monde, mesure
## le coût d'un tick du monde tel quel, puis CLONE ses résidents (même métier, même lit, même poste, même assignation)
## jusqu'à 500, 1 000, 2 000 êtres et remesure : le coût par tick, et où il part (`Simulation.chrono`). C'est la
## mesure qui décide ce que l'anneau moyen et un noyau C++ gagneraient.
##   godot --headless --path godot res://scenes/tests/sonde_echelle.tscn -- --graine_monde 9 --cibles 500,1000,2000 --ticks 200

var soucis: Array[String] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var graine := 9
	var cibles: Array[int] = [500, 1000, 2000]
	var ticks := 200
	var rayon := 60
	for i in args.size():
		if args[i] == "--graine_monde" and i + 1 < args.size():
			graine = int(args[i + 1])
		elif args[i] == "--cibles" and i + 1 < args.size():
			cibles.clear()
			for c in str(args[i + 1]).split(","):
				cibles.append(int(c))
		elif args[i] == "--ticks" and i + 1 < args.size():
			ticks = int(args[i + 1])
		elif args[i] == "--rayon" and i + 1 < args.size():
			rayon = int(args[i + 1])
	var cfg: Dictionary = GameData.config("villes")
	var ordre: Array = cfg.ordre_paliers
	var s0 := Simulation.new(graine)
	s0.graine_monde = graine
	s0.charger_camp()
	var surf: Surface = s0.monde.surface
	var c0: Vector2i = s0.monde.cellule_camp
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
				if meilleure.is_empty() or ordre.find(str(f.palier)) > ordre.find(str(meilleure.palier)) or (str(f.palier) == str(meilleure.palier) and int(f.population) > int(meilleure.population)):
					meilleure = f
	s0.monde.fermer()
	if meilleure.is_empty():
		print("SONDE ÉCHELLE : aucune agglomération — rien à mesurer")
		get_tree().quit()
		return
	var f := meilleure
	print("ÉCHELLE — monde %d : %s « %s », %d habitants, %d cellule(s)" % [graine, str(f.palier), str(f.nom), int(f.population), f.cellules.size()])
	var s := Simulation.new(graine)
	s.graine_monde = graine
	s.charger_camp({}, Vector2i(f.centre) + Vector2i(2, 0))
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_sub: int = s.monde.taille / 32
	for cy in n_sub:
		for cx in n_sub:
			s.monde.explores[Vector2i(int(f.centre.x) * n_sub + cx, int(f.centre.y) * n_sub + cy)] = true
	s.voyager(j, f.centre)
	s.invincible = true
	print("fenêtre : %d × %d tuiles, %d êtres" % [s.grille.largeur, s.grille.largeur, s.vivants().size()])
	# 1. Tel quel.
	_mesurer(s, "tel quel", 300, ticks)
	# 2. Les paliers d'échelle : des clones des résidents, jusqu'au compte demandé.
	var modeles: Array = []
	for x in s.vivants():
		if x.get("role", "") == "resident" and x.has("assignation"):
			modeles.append(x)
	if modeles.is_empty():
		soucis.append("aucun résident à cloner")
		_fin()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	for cible in cibles:
		var k := 0
		var manques := 0
		while s.vivants().size() < cible and manques < 2000:
			var modele: Dictionary = modeles[k % modeles.size()]
			k += 1
			var pos := s._tuile_libre_autour(modele.pos)
			if pos == Vector2i(-1, -1) or rng.randf() < 0.5:
				pos = _tuile_libre_au_hasard(s, rng)
			if pos == Vector2i(-1, -1):
				manques += 1
				continue
			var x: Dictionary = s.ajouter(str(modele.def), pos, "ia")
			if x.is_empty():
				manques += 1
				continue
			for cle in ["fonction", "lit", "poste", "place", "village", "royaume", "ancre", "role", "ai_profile", "camp", "boutique", "guilde"]:
				if modele.has(cle):
					x[cle] = modele[cle]
			x["assignation"] = modele.assignation.duplicate(true)
			x.tags = modele.tags.duplicate()
			if modele.has("stock"):
				x["stock"] = []
		if s.vivants().size() < cible:
			soucis.append("échelle %d : seulement %d êtres placés (plus de tuiles libres ?)" % [cible, s.vivants().size()])
		_mesurer(s, "échelle %d" % cible, 100, ticks)
	_fin()


## `chauffe` ticks pour sortir de la ruée (tout le monde part vers son poste), puis `n` ticks mesurés.
func _mesurer(s: Simulation, titre: String, chauffe: int, n: int) -> void:
	for k in chauffe:
		s.horloge_monde.avancer(1)
	s.chrono.clear()
	var t0 := Time.get_ticks_usec()
	for k in n:
		s.horloge_monde.avancer(1)
	var ms_tick := (Time.get_ticks_usec() - t0) / 1000.0 / float(n)
	var cles: Array = s.chrono.keys()
	cles.sort_custom(func(a: String, b: String) -> bool: return float(s.chrono[a]) > float(s.chrono[b]))
	var parts: Array[String] = []
	for c in cles.slice(0, 10):
		parts.append("%s %.2f" % [c, float(s.chrono[c]) / float(n)])
	var vivants := s.vivants().size()
	print("%s : %.2f ms par tick du monde, %d êtres (%.1f µs par être) · par tick : %s" % [titre, ms_tick, vivants, ms_tick * 1000.0 / maxi(1, vivants), ", ".join(parts)])
	var budget_tick := float(GameData.config("combat_rules").get("tempo", {}).get("ms_max_par_image", 12))
	if ms_tick > budget_tick:
		print("  (au-dessus du budget d'une image : %.0f ms)" % budget_tick)


func _tuile_libre_au_hasard(s: Simulation, rng: RandomNumberGenerator) -> Vector2i:
	for essai in 200:
		var p := s.grille.origine + Vector2i(rng.randi_range(1, s.grille.largeur - 2), rng.randi_range(1, s.grille.largeur - 2))
		if s.grille.dans(p) and not s.grille.bloque_passage(p) and s.grille.occupant(p).is_empty() and not s.dans_l_eau(p):
			return p
	return Vector2i(-1, -1)


func _fin() -> void:
	if soucis.is_empty():
		print("SONDE ÉCHELLE : rien à signaler")
	else:
		print("SONDE ÉCHELLE : %d souci(s)" % soucis.size())
		for x in soucis:
			print("  - " + x)
	Monde.fermer_tous()
	get_tree().quit()
