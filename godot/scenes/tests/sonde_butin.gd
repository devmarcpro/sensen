extends Node
## Sonde du butin par NIVEAU DE DONJON (designer 2026-09-02 : « la rareté du loot ne se fait pas par
## étage mais par niveau du donjon »). Elle tire beaucoup d'objets à plusieurs niveaux et dit, pour
## chacun : quels paliers de matériau sortent, et ce que valent les objets assemblés. C'est la mesure
## qui permet de juger les chiffres de `paliers_materiaux` — sans elle on ne règle qu'à l'intuition.
##   Godot --headless --path godot res://scenes/tests/sonde_butin.tscn -- --tirages 400


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var tirages := 400
	for i in args.size():
		if args[i] == "--tirages" and i + 1 < args.size():
			tirages = int(args[i + 1])
	var s := Simulation.new(4242)
	s.charger_camp()
	var niveaux: Array[int] = [1, 3, 6, 10, 15, 25]
	print("butin par niveau de donjon — %d tirages par niveau" % tirages)
	for niv in niveaux:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([4242, niv, "sonde"])
		var paliers := {}
		var duretes: Array[float] = []
		var valeurs: Array[float] = []
		var assembles := 0
		for k in tirages:
			var base := str(s.loot._base_pour(rng, niv))
			var o := s.generer_objet(base, niv, {"sonde": true})
			if o.is_empty():
				continue
			for slot in o.get("composants", {}).keys():
				var m := str(o.composants[slot].materiau)
				var pal := int(GameData.catalogues.materials.get(m, {}).get("palier", 1))
				paliers[pal] = int(paliers.get(pal, 0)) + 1
			if not o.get("composants", {}).is_empty():
				assembles += 1
				duretes.append(float(o.get("stats", {}).get("durete", 0.0)))
				valeurs.append(float(o.get("stats", {}).get("valeur_base", 0.0)))
		var total := 0
		for p in paliers.values():
			total += int(p)
		var parts: Array[String] = []
		for p in [1, 2, 3, 4, 5]:
			parts.append("P%d %2d %%" % [p, roundi(100.0 * float(paliers.get(p, 0)) / maxf(1.0, float(total)))])
		print("  niveau %2d · %3d objets assemblés · %s · dureté moyenne %5.1f · valeur moyenne %5.1f"
			% [niv, assembles, " ".join(parts), _moyenne(duretes), _moyenne(valeurs)])
	s.monde.fermer()
	get_tree().quit()


func _moyenne(v: Array[float]) -> float:
	if v.is_empty():
		return 0.0
	var t := 0.0
	for x in v:
		t += x
	return t / float(v.size())
