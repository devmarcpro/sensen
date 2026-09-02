extends Node
## Sonde du monde : compte ce que la carte montre, sans y jouer. Née d'une remarque du designer
## (2026-09-02) — « les carrés noirs avec des chiffres blancs sont des donjons ? il y en a beaucoup
## trop » — à laquelle je ne savais répondre que par une impression. On mesure donc : combien de
## donjons de corruption, combien de gouffres, combien de régions, sur quelle part de terre.
##   godot --headless --path godot res://scenes/tests/sonde_monde.tscn -- --graine 4242 --rayon 40


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var graine := 4242
	var rayon := 40
	for i in args.size():
		if args[i] == "--graine" and i + 1 < args.size():
			graine = int(args[i + 1])
		if args[i] == "--rayon" and i + 1 < args.size():
			rayon = int(args[i + 1])
	var s := Simulation.new(graine)
	s.charger_camp()
	var m = s.monde
	var su = m.surface
	var camp: Vector2i = m.cellule_camp
	var jour: int = s.jour_courant()
	var terre := 0
	var cellules_donjon := 0     # les cellules qui cristallisent
	var donjons := {}            # les VRAIS donjons : une grappe fusionnée compte pour un
	var gouffres := 0
	var regions := {}
	var niveaux: Array[int] = []
	for dy in range(-rayon, rayon + 1):
		for dx in range(-rayon, rayon + 1):
			var c: Vector2i = camp + Vector2i(dx, dy)
			if not su.terre_a(c):
				continue
			terre += 1
			regions[su.germe_region(c)] = true
			if not m.gouffre_de(c).is_empty():
				gouffres += 1
			if m.donjon_corrompu(c, jour):
				cellules_donjon += 1
				var d: Dictionary = m.donjon_de_corruption(c, jour)
				var tete: Vector2i = Vector2i(d.get("tete", c))
				if not donjons.has(tete):
					donjons[tete] = true
					niveaux.append(int(d.niveau))
	niveaux.sort()
	var med: int = niveaux[niveaux.size() / 2] if not niveaux.is_empty() else 0
	print("graine %d, carré de %d cellules de côté autour du camp" % [graine, rayon * 2 + 1])
	print("  terre ferme        : %d cellules" % terre)
	print("  régions            : %d  (une région ≈ %d cellules de terre)" % [regions.size(), terre / maxi(1, regions.size())])
	print("  gouffres           : %d  (%.2f par région)" % [gouffres, float(gouffres) / maxf(1.0, float(regions.size()))])
	print("  donjons corrompus  : %d  (%d cellules cristallisées)" % [donjons.size(), cellules_donjon])
	print("     par région      : %.2f" % (float(donjons.size()) / maxf(1.0, float(regions.size()))))
	print("     part des terres : %.1f %%  (une cellule de terre sur %d)" % [100.0 * float(cellules_donjon) / maxf(1.0, float(terre)), terre / maxi(1, cellules_donjon)])
	print("     niveau médian   : %d  (de %d à %d)" % [med, niveaux[0] if not niveaux.is_empty() else 0, niveaux[-1] if not niveaux.is_empty() else 0])
	m.fermer()
	get_tree().quit()
