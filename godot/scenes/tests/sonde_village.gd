extends Node
## Un hameau sur la durée (Villages PNJ — repeuplement et décimation) : on en vide la moitié, on regarde
## combien de semaines il met à se repeupler ; puis on le vide entièrement et on regarde s'il devient
## un lieu abandonné, et s'il le reste. Même mécanique de semaine que la grande base.
##   Godot --headless --path godot res://scenes/tests/sonde_village.tscn -- --graine_monde 9 --semaines 30

const GrandeBase := preload("res://scenes/tests/grande_base.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var graine_monde := 9
	var semaines := 30
	for i in args.size():
		if args[i] == "--graine_monde" and i + 1 < args.size():
			graine_monde = int(args[i + 1])
		elif args[i] == "--semaines" and i + 1 < args.size():
			semaines = int(args[i + 1])
	var journal: Array = []
	EventBus.journal.connect(func(cle: String, params: Dictionary) -> void: journal.append({"cle": cle, "params": params}))
	var s := Simulation.new(31)
	s.graine_monde = graine_monde
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	s.invincible = true
	print("VILLAGES — monde %d, %d hameau(x) dans la fenêtre" % [graine_monde, s.monde.villages.size()])
	var choisi := ""
	for nom in s.monde.villages.keys():
		var info: Dictionary = s.monde.villages[nom]
		var pop: int = s.population_village(str(nom)).size()
		print("  %s : cellule (%d,%d) · %d habitant(s) / capacité %d · corruption %.0f %% · abandonné %s" % [str(nom), info.cellule.x, info.cellule.y, pop, int(info.get("capacite", 0)), s.monde.corruption_de(info.cellule), str(info.get("abandonne", false))])
		if choisi.is_empty() and pop >= 2:
			choisi = str(nom)
	if choisi.is_empty():
		print("SONDE VILLAGE : aucun hameau peuplé dans la fenêtre — rien à mesurer")
		get_tree().quit()
		return
	var cap: int = int(s.monde.villages[choisi].get("capacite", 0))
	var rp: Dictionary = s.regles.r.royaume.repeuplement
	# 1. La moitié meurt.
	var habitants: Array = s.population_village(choisi)
	var a_tuer: int = habitants.size() / 2
	for k in a_tuer:
		s._appliquer_degats(habitants[k], 9999, "", {})
	var pop0: int = s.population_village(choisi).size()
	var corr: float = s.monde.corruption_de(s.monde.villages[choisi].cellule)
	print("%s : %d tués, reste %d / %d — chance de repeuplement par semaine = %.2f × (1 − %d/%d) × (1 − %.0f/100) = %.3f" % [choisi, a_tuer, pop0, cap, float(rp.chance), pop0, cap, corr, float(rp.chance) * (1.0 - float(pop0) / float(cap)) * (1.0 - corr / 100.0)])
	print("semaine | ms | habitants | événements")
	var premiere_arrivee := -1
	for k in semaines:
		var w: Dictionary = GrandeBase.semaine(s, journal, j)
		var pop: int = s.population_village(choisi).size()
		var ev: Array[String] = []
		for cle in ["journal.repeuplement", "journal.naissance", "journal.village_abandonne", "journal.mort"]:
			if w.journal.has(cle):
				ev.append("%s ×%d" % [cle.trim_prefix("journal."), int(w.journal[cle])])
		if premiere_arrivee < 0 and pop > pop0:
			premiere_arrivee = k + 1
		print("  %2d | %4.0f | %2d / %d | %s" % [k + 1, w.ms, pop, cap, " · ".join(ev)])
	print("première arrivée : %s · population finale %d / %d" % ["semaine %d" % premiere_arrivee if premiere_arrivee > 0 else "jamais en %d semaines" % semaines, s.population_village(choisi).size(), cap])
	# 2. Décimation totale : tout le monde meurt ; le village doit devenir abandonné et le rester.
	for x in s.population_village(choisi):
		s._appliquer_degats(x, 9999, "", {})
	var abandonne_a := -1
	for k in 12:
		var w: Dictionary = GrandeBase.semaine(s, journal, j)
		if abandonne_a < 0 and bool(s.monde.villages[choisi].get("abandonne", false)):
			abandonne_a = k + 1
	print("décimé : abandonné %s · population après 12 semaines : %d" % ["à la semaine %d" % abandonne_a if abandonne_a > 0 else "JAMAIS", s.population_village(choisi).size()])
	print("SONDE VILLAGE : fin")
	get_tree().quit()
