extends Node
## Ou passent les millisecondes d'un etage de donjon. Le budget (100 ms) est depasse a 119-134 ms et
## le test ne dit que le total : sans decoupage, on regle a l'aveugle.
##   Godot --headless --path godot res://scenes/tests/sonde_perf_etage.tscn

func _ready() -> void:
	var theme: Dictionary = GameData.entree("dungeon_themes", "ruine")
	var gen := Donjon.new(GameData.catalogues.get("dungeon_rooms", {}), GameData.catalogues.get("dungeon_connectors", {}), theme)
	var t0 := Time.get_ticks_usec()
	for k in 5:
		gen.generer_etage(51, 4, 1, 8, false)
	var dt_gen := (Time.get_ticks_usec() - t0) / 5000.0
	print("generer_etage (geometrie + peuplement) : %.1f ms" % dt_gen)
	var s := Simulation.new(51)
	t0 = Time.get_ticks_usec()
	s.charger_donjon("ruine", 51, 4, 1)
	var dt_total := (Time.get_ticks_usec() - t0) / 1000.0
	print("charger_donjon complet (1er appel, caches froids) : %.1f ms" % dt_total)
	var s2 := Simulation.new(51)
	t0 = Time.get_ticks_usec()
	s2.charger_donjon("ruine", 51, 5, 1)
	print("charger_donjon (2e simulation, caches froids a nouveau) : %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	t0 = Time.get_ticks_usec()
	s2.charger_donjon("ruine", 51, 6, 1)
	print("charger_donjon (meme simulation, caches chauds) : %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	# Le decoupage fin : les poches de strates balaient les 4096 tuiles avec du bruit, et le butin des
	# coffres tire un objet complet par piece. On mesure les deux separement.
	var e2: Dictionary = gen.generer_etage(51, 4, 1, 8, false)
	t0 = Time.get_ticks_usec()
	s2._poches_de_strates(theme, 1, 51, 4)
	print("  dont poches de strates (4096 tuiles de bruit) : %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var n_coffres: int = (e2.get("coffres", []) as Array).size()
	var n_pieces := 0
	for c in e2.get("coffres", []):
		n_pieces += (c.bases as Array).size()
	t0 = Time.get_ticks_usec()
	for c2 in e2.get("coffres", []):
		for base in c2.bases:
			s2.generer_objet(str(base), 4, {"donjon": "ruine", "etage": 1})
	print("  dont butin des coffres (%d coffres, %d pieces) : %.1f ms" % [n_coffres, n_pieces, (Time.get_ticks_usec() - t0) / 1000.0])
	t0 = Time.get_ticks_usec()
	var g2 := Grille.depuis_etage(e2, GameData.config("tile_contents"), s2.regles.r.deplacement, int(s2.regles.r.vision.hauteur_oeil))
	print("  dont Grille.depuis_etage : %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	t0 = Time.get_ticks_usec()
	s2.maj_vision()
	print("  dont maj_vision : %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var n_sp: int = (e2.get("spawns", []) as Array).size()
	t0 = Time.get_ticks_usec()
	for sp in e2.get("spawns", []):
		s2.ajouter(str(sp.creature), sp.pos, "ia")
	print("  dont %d creatures posees : %.1f ms" % [n_sp, (Time.get_ticks_usec() - t0) / 1000.0])
	print("materiaux au catalogue : %d · creatures : %d" % [GameData.catalogues.materials.size(), GameData.catalogues.creatures.size()])
	get_tree().quit()
