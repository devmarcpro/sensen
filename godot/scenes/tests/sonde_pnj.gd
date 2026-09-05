extends Node
## La sonde des PNJ (PNJ — traits, histoires et souhaits, 2026-09-05) : la plus grande ville à portée du camp,
## chargée ; ses gens un à un — traits, souhait, histoire, opinions — et ce que deux PNJ de même fiche partagent.
##   godot --headless --path godot res://scenes/tests/sonde_pnj.tscn -- --graine_monde 9

var soucis: Array[String] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var graine := 9
	for i in args.size():
		if args[i] == "--graine_monde" and i + 1 < args.size():
			graine = int(args[i + 1])
	var s := Simulation.new(graine)
	s.graine_monde = graine
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var ordre: Array = GameData.config("villes").ordre_paliers
	var c0: Vector2i = s.monde.cellule_camp
	var f: Dictionary = {}
	for dy in range(-25, 26):
		for dx in range(-25, 26):
			var cv := c0 + Vector2i(dx, dy)
			if surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false)):
				var fa: Dictionary = surf.fiche_agglomeration(cv)
				if f.is_empty() or ordre.find(str(fa.palier)) > ordre.find(str(f.palier)) or (str(fa.palier) == str(f.palier) and int(fa.population) > int(f.population)):
					f = fa
	if f.is_empty():
		print("SONDE PNJ : aucune agglomération — rien à mesurer")
		get_tree().quit()
		return
	var s2 := Simulation.new(graine)
	s2.graine_monde = graine
	s2.charger_camp({}, Vector2i(f.centre) + Vector2i(2, 0))
	var j: Dictionary = s2.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_sub: int = s2.monde.taille / 32
	for cy in n_sub:
		for cx in n_sub:
			s2.monde.explores[Vector2i(int(f.centre.x) * n_sub + cx, int(f.centre.y) * n_sub + cy)] = true
	s2.voyager(j, f.centre)
	var gens: Array = s2.vivants().filter(func(x: Dictionary) -> bool: return str(x.get("village", "")) == str(f.nom) and x.has("traits"))
	print("PNJ — monde %d, %s (%s, %d habitants) : %d PNJ distingués" % [graine, str(f.nom), str(f.palier), int(f.population), gens.size()])
	var traits := {}
	var souhaits := {}
	var histoires := {}
	var opinions := 0
	var sans_trait := 0
	var par_fiche := {}
	for x in gens:
		for tid in x.traits:
			traits[str(tid)] = int(traits.get(str(tid), 0)) + 1
		if x.traits.size() < 2:
			sans_trait += 1
		souhaits[str(x.get("souhait", "—"))] = int(souhaits.get(str(x.get("souhait", "—")), 0)) + 1
		histoires[str(x.get("histoire", {}).get("cle", "—"))] = int(histoires.get(str(x.get("histoire", {}).get("cle", "—")), 0)) + 1
		opinions += x.social.get("opinions", {}).size()
		var cle_f := str(x.def) + "|" + str(x.get("fonction", ""))
		if not par_fiche.has(cle_f):
			par_fiche[cle_f] = []
		par_fiche[cle_f].append(x)
	print("  traits : %s" % str(traits))
	print("  souhaits : %s" % str(souhaits))
	print("  histoires : %s" % str(histoires))
	print("  opinions : %d au total, %d sans les deux traits" % [opinions, sans_trait])
	for k in mini(6, gens.size()):
		var x: Dictionary = gens[k]
		var ops: Array[String] = []
		for autre in x.social.get("opinions", {}).keys():
			if s2.entites.has(str(autre)):
				ops.append("%s %+d" % [Noms.afficher(s2.entites[str(autre)].nom), int(x.social.opinions[autre])])
		print("  %s · %s · %d ans · %s · traits %s · souhaite %s · « %s » · %s" % [Noms.afficher(x.nom), str(x.fonction), int(x.age), str(x.get("signe", {}).get("element", "")) + "-" + str(x.get("signe", {}).get("animal", "")), str(x.traits), str(x.get("souhait", "—")), str(x.get("histoire", {}).get("cle", "—")), ", ".join(ops)])
	# Deux PNJ de même fiche et de même fonction ne se ressemblent jamais.
	var jumeaux := 0
	for cle_f in par_fiche.keys():
		var liste: Array = par_fiche[cle_f]
		for a in liste.size():
			for b in range(a + 1, liste.size()):
				var xa: Dictionary = liste[a]
				var xb: Dictionary = liste[b]
				if xa.traits == xb.traits and str(xa.get("souhait", "")) == str(xb.get("souhait", "")) and str(xa.get("histoire", {}).get("cle", "")) == str(xb.get("histoire", {}).get("cle", "")):
					jumeaux += 1
	print("  jumeaux (mêmes traits, souhait et histoire) : %d" % jumeaux)
	if sans_trait > 0:
		soucis.append("%d PNJ sans leurs deux traits" % sans_trait)
	if gens.size() >= 10 and traits.size() < 6:
		soucis.append("trop peu de traits différents (%d)" % traits.size())
	if gens.size() >= 10 and jumeaux > gens.size() / 10:
		soucis.append("%d paires de jumeaux pour %d PNJ" % [jumeaux, gens.size()])
	for sc in soucis:
		print("  souci : " + sc)
	print("SONDE PNJ : %s" % ("rien à signaler" if soucis.is_empty() else "%d souci(s)" % soucis.size()))
	get_tree().quit(0 if soucis.is_empty() else 1)
