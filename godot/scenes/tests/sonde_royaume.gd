extends Node
## La sonde des royaumes (Royaumes — état, ères, blasons et événements, 2026-09-05) : les royaumes des secteurs
## autour du camp — état, règne, ère, blason, population, armée —, puis des semaines qui passent : humeur, événements,
## guerres, trésors.
##   godot --headless --path godot res://scenes/tests/sonde_royaume.tscn -- --graine_monde 21 --semaines 12

const GrandeBase := preload("res://scenes/tests/grande_base.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var graine := 21
	var semaines := 12
	for i in args.size():
		if args[i] == "--graine_monde" and i + 1 < args.size():
			graine = int(args[i + 1])
		elif args[i] == "--semaines" and i + 1 < args.size():
			semaines = int(args[i + 1])
	var s := Simulation.new(graine)
	s.graine_monde = graine
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	s.invincible = true
	var surf: Surface = s.monde.surface
	var sect0: Vector2i = surf.secteur_de(s.monde.cellule_camp)
	var ids: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for id in surf.royaumes_secteur(sect0 + Vector2i(dx, dy)).keys():
				ids.append(str(id))
	print("ROYAUMES — monde %d, %d royaume(s) dans les neuf secteurs autour du camp" % [graine, ids.size()])
	for id in ids:
		var roy := s.royaume_par_id(id)
		var e := s.etat_royaume(id)
		print("  %s (%s, %s, %s) : %s, an %d de l'ère de %s · %d âmes · armée %d · humeur %d · blason %s au %s · %d cellules, %d lois" % [str(roy.nom), str(roy.taille), str(roy.government_type), str(roy.culture), str(e.dirigeant), s.an_de_regne(e), str(e.ere), int(e.population), int(e.armee), int(e.humeur), str(e.blason.couleurs[0]), str(e.blason.motif), roy.territory_cells.size(), roy.laws.size()])
	var journal: Array = []
	EventBus.journal.connect(func(cle: String, params: Dictionary) -> void: journal.append({"cle": cle, "params": params}))
	var evenements := {}
	for w in semaines:
		GrandeBase.semaine(s, journal, j)
		for l in journal:
			if str(l.cle).begins_with("evenement."):
				evenements[str(l.cle)] = int(evenements.get(str(l.cle), 0)) + 1
	print("  après %d semaines : événements vus par le joueur %s" % [semaines, str(evenements)])
	var total_ev := 0
	var guerres := 0
	for id in ids:
		var e := s.etat_royaume(id)
		total_ev += e.journal.size()
		guerres += e.guerres.size()
		var derniers: Array[String] = []
		for ev in e.journal:
			derniers.append(str(ev.cle).trim_prefix("evenement."))
		print("  %s : humeur %d · trésor %d · guerres %s · journal %s" % [str(s.royaume_par_id(id).nom), int(e.humeur), int(e.tresor), str(e.guerres), ", ".join(derniers)])
	print("SONDE ROYAUME : %d événement(s) au total, %d guerre(s) en cours" % [total_ev, guerres])
	get_tree().quit()
