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
	# La graine du MONDE, pas seulement celle des jets : sans elle, toutes les sondes tournaient sur le
	# même monde et `--graine` ne changeait rien — mes mesures par graine ne mesuraient qu'une graine.
	s.graine_monde = graine
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
	# À quelle distance est le donjon le plus proche ? (designer 2026-09-02 : « il y a un problème si on
	# n'a pas de donjon à proximité ».) On mesure depuis un échantillon de cellules de terre, en cellules
	# de Chebyshev, vers le plus proche donjon de corruption ET vers le plus proche gouffre.
	var d_corr: Array[int] = []
	var d_gouf: Array[int] = []
	var echantillon: Array[Vector2i] = []
	for dy_e in range(-rayon, rayon + 1, 7):
		for dx_e in range(-rayon, rayon + 1, 7):
			var c_e: Vector2i = camp + Vector2i(dx_e, dy_e)
			if su.terre_a(c_e):
				echantillon.append(c_e)
	for depart in echantillon:
		var meilleur_c := 999
		var meilleur_g := 999
		for r_d in range(0, 26):
			for dy_d in range(-r_d, r_d + 1):
				for dx_d in range(-r_d, r_d + 1):
					if absi(dx_d) != r_d and absi(dy_d) != r_d:
						continue
					var c_d: Vector2i = depart + Vector2i(dx_d, dy_d)
					if meilleur_c > r_d and m.donjon_corrompu(c_d, jour):
						meilleur_c = r_d
					if meilleur_g > r_d and not m.gouffre_de(c_d).is_empty():
						meilleur_g = r_d
			if meilleur_c < 999 and meilleur_g < 999:
				break
		d_corr.append(meilleur_c)
		d_gouf.append(meilleur_g)
	print("  distance au donjon le plus proche, depuis %d cellules de terre :" % echantillon.size())
	print("     corruption : mediane %d cellules, pire %d, jamais trouve %d fois" % [_mediane(d_corr), _pire(d_corr), _compte(d_corr, 999)])
	print("     gouffre    : mediane %d cellules, pire %d, jamais trouve %d fois" % [_mediane(d_gouf), _pire(d_gouf), _compte(d_gouf, 999)])
	niveaux.sort()
	var med: int = niveaux[niveaux.size() / 2] if not niveaux.is_empty() else 0
	print("graine %d, carré de %d cellules de côté autour du camp" % [graine, rayon * 2 + 1])
	# La promesse du départ (designer 2026-09-02) : ce que le camp a sous la main sur sa masse de terre.
	var inv := m.inventaire_depart(camp)
	print("  depart en %s : %d gouffre(s), %d ville(s), %d royaume(s) — %s" % [str(camp), int(inv.gouffres), int(inv.villes), int(inv.royaumes), "TENU" if m.depart_valable(camp) else "NON TENU"])
	print("  terre ferme        : %d cellules" % terre)
	print("  régions            : %d  (une région ≈ %d cellules de terre)" % [regions.size(), terre / maxi(1, regions.size())])
	print("  gouffres           : %d  (%.2f par région)" % [gouffres, float(gouffres) / maxf(1.0, float(regions.size()))])
	print("  donjons corrompus  : %d  (%d cellules cristallisées)" % [donjons.size(), cellules_donjon])
	print("     par région      : %.2f" % (float(donjons.size()) / maxf(1.0, float(regions.size()))))
	print("     part des terres : %.1f %%  (une cellule de terre sur %d)" % [100.0 * float(cellules_donjon) / maxf(1.0, float(terre)), terre / maxi(1, cellules_donjon)])
	print("     niveau médian   : %d  (de %d à %d)" % [med, niveaux[0] if not niveaux.is_empty() else 0, niveaux[-1] if not niveaux.is_empty() else 0])
	# La pente géographique (designer 2026-09-02, choix 2) : le niveau doit monter quand on s'éloigne du
	# centre du monde. On l'affiche par bandes d'éloignement, sur tout le monde et pas seulement autour
	# du camp — une pente ne se juge pas sur un carré de terrain, elle se juge d'un bout à l'autre.
	print("  la pente : niveau des donjons par bande d'éloignement (monde entier)")
	var larg_m: int = int(m.planete.monde_cellules)
	var haut_m: int = int(float(larg_m) * float(m.planete.get("monde_ratio", 1.0)))
	var bandes := {}
	for j_m in range(0, haut_m, 9):
		for i_m in range(0, larg_m, 9):
			var c_m := Vector2i(i_m, j_m)
			if not su.terre_a(c_m) or not m.donjon_corrompu(c_m, jour):
				continue
			var b := mini(4, int(m.eloignement(c_m) * 5.0))
			if not bandes.has(b):
				bandes[b] = []
			(bandes[b] as Array).append(int(m.donjon_de_corruption(c_m, jour).niveau))
	for b in range(0, 5):
		var v: Array = bandes.get(b, [])
		if v.is_empty():
			print("     eloignement %.1f-%.1f : aucun donjon" % [b * 0.2, (b + 1) * 0.2])
			continue
		v.sort()
		print("     eloignement %.1f-%.1f : %3d donjons, niveau median %3d (de %d a %d)" % [b * 0.2, (b + 1) * 0.2, v.size(), int(v[v.size() / 2]), int(v[0]), int(v[-1])])
	m.fermer()
	get_tree().quit()


func _mediane(v: Array[int]) -> int:
	if v.is_empty():
		return 0
	var t := v.duplicate()
	t.sort()
	return t[t.size() / 2]


func _pire(v: Array[int]) -> int:
	var m := 0
	for x in v:
		if x != 999 and x > m:
			m = x
	return m


func _compte(v: Array[int], val: int) -> int:
	var n := 0
	for x in v:
		if x == val:
			n += 1
	return n
