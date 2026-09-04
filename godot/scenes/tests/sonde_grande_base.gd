extends Node
## Une grande base simulée (designer, 2026-09-04, 14 h) : cinq cellules, des zones de récolte, deux stockages,
## un résidentiel, vingt engagés — puis des semaines qui passent. On lit ce que la simulation fait d'elle-même :
## production, maisons, migrants, entretien, dette, et le coût d'une semaine en millisecondes.
##   Godot --headless --path godot res://scenes/tests/sonde_grande_base.tscn -- --graine 31 --residents 20 --semaines 12 --tresor 1000

const GrandeBase := preload("res://scenes/tests/grande_base.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var graine := 31
	var n_res := 20
	var semaines := 12
	var tresor := 1000
	var graine_monde := -1   # -1 : le monde de planete.json ; sinon le même monde que la capture (--graine N)
	for i in args.size():
		if args[i] == "--graine" and i + 1 < args.size():
			graine = int(args[i + 1])
		elif args[i] == "--graine_monde" and i + 1 < args.size():
			graine_monde = int(args[i + 1])
		elif args[i] == "--residents" and i + 1 < args.size():
			n_res = int(args[i + 1])
		elif args[i] == "--semaines" and i + 1 < args.size():
			semaines = int(args[i + 1])
		elif args[i] == "--tresor" and i + 1 < args.size():
			tresor = int(args[i + 1])
	var journal: Array = []
	EventBus.journal.connect(func(cle: String, params: Dictionary) -> void: journal.append({"cle": cle, "params": params}))
	var s := Simulation.new(graine)
	s.graine_monde = graine_monde
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var t0 := Time.get_ticks_usec()
	var r: Dictionary = GrandeBase.batir(s, j, n_res, tresor)
	print("GRANDE BASE — graine %d, bâtie en %.0f ms" % [graine, (Time.get_ticks_usec() - t0) / 1000.0])
	for c in r.cellules:
		print("  cellule (%d,%d) %s — rôle %s" % [c.cellule.x, c.cellule.y, c.biome, c.role])
	for z in r.zones:
		print("  zone %s : %s sur (%d,%d) — richesse %d, réserve %.0f, dominant %s" % [z.pid, z.type, z.cellule.x, z.cellule.y, z.richesse, z.reserve, z.dominant])
	if not r.residentiel.is_empty():
		print("  résidentiel %s : %d tuiles libres, de (%d,%d) à (%d,%d)" % [r.residentiel.pid, r.residentiel.tuiles_libres, r.residentiel.a.x, r.residentiel.a.y, r.residentiel.b.x, r.residentiel.b.y])
	for st in r.stockages:
		print("  stockage %s : capacité %d" % [st.pid, st.capacite])
	print("  postes : %s" % str(r.postes))
	for ref in r.refus:
		print("  refus : %s" % ref)
	var e0: Dictionary = GrandeBase.etat(s)
	print("  départ : %d résidents, %d logés, %d lits, trésor %d, humeur %d" % [e0.residents, e0.loges, e0.lits, e0.tresor, e0.humeur])
	if "--profil" in args:   # où passent les millisecondes d'une semaine : chaque étape de _tiquer_monde, seule
		var tps: int = int(GameData.config("planete").corruption.ticks_par_semaine)
		s.horloge_monde.avancer(tps)
		var tk: int = s.horloge_monde.ticks
		for etape in ["monde.semaine", "_vieillir_semaine", "_semaine_royaumes_pnj", "_semaine_elevage", "_semaine_territoire", "_semaine_migrants", "_regenerer_terrain_sauvage", "_regenerer_faune_hebdo", "monde.tick"]:
			var t1 := Time.get_ticks_usec()
			match etape:
				"monde.semaine": s.monde.semaine(tk)
				"_vieillir_semaine": s._vieillir_semaine(tk)
				"_semaine_royaumes_pnj": s._semaine_royaumes_pnj()
				"_semaine_elevage": s._semaine_elevage()
				"_semaine_territoire": s._semaine_territoire(j)
				"_semaine_migrants": s._semaine_migrants(j)
				"_regenerer_terrain_sauvage": s._regenerer_terrain_sauvage()
				"_regenerer_faune_hebdo": s._regenerer_faune_hebdo()
				"monde.tick": s.monde.tick(tk)
			print("  profil %-28s %7.1f ms" % [etape, (Time.get_ticks_usec() - t1) / 1000.0])
		var t2 := Time.get_ticks_usec()
		s._batir_maisons()
		print("  profil %-28s %7.1f ms" % ["_batir_maisons (seul)", (Time.get_ticks_usec() - t2) / 1000.0])
		t2 = Time.get_ticks_usec()
		s.pieces_de_cellule(s.monde.cellule_camp)
		print("  profil %-28s %7.1f ms" % ["pieces_de_cellule (camp)", (Time.get_ticks_usec() - t2) / 1000.0])
		t2 = Time.get_ticks_usec()
		for x in s.residents():
			s.production_de(x)
		print("  profil %-28s %7.1f ms" % ["production_de ×résidents", (Time.get_ticks_usec() - t2) / 1000.0])
	print("semaine | ms | résidents | logés | lits | trésor | dette | humeur | stocks | journal")
	for k in semaines:
		var w: Dictionary = GrandeBase.semaine(s, journal, j)
		var e: Dictionary = w.etat
		print("  %2d | %4.0f | %2d | %2d | %2d | %5d | %4d | %3d | %s | %s" % [k + 1, w.ms, e.residents, e.loges, e.lits, e.tresor, e.dette, e.humeur, str(e.stocks), str(w.journal)])
	var ef: Dictionary = GrandeBase.etat(s)
	print("zones à la fin : %s" % ", ".join(ef.zones))
	print("stockages à la fin : %s" % ", ".join(ef.stockages))
	var sans_stock := 0
	for x in s.residents():
		if bool(s.production_de(x).get("sans_stockage", false)):
			sans_stock += 1
	print("postes sans stockage : %d" % sans_stock)
	if not r.residentiel.is_empty():   # pourquoi « pas de place » : qui se tient dans le résidentiel, ce qui y reste de libre
		var debout := 0
		var libres := 0
		var construit := 0
		for y in range(r.residentiel.a.y, r.residentiel.b.y + 1):
			for x in range(r.residentiel.a.x, r.residentiel.b.x + 1):
				var q := Vector2i(x, y)
				if not s.grille.occupant(q).is_empty():
					debout += 1
				if "construit" in s.grille.contenu_de(q).get("tags", []) or s.grille.meubles.has(s.grille.idx(q)):
					construit += 1
				elif not s.grille.bloque_passage(q) and s.grille.occupant(q).is_empty():
					libres += 1
		print("résidentiel à la fin : %d tuiles bâties, %d libres, %d occupées par quelqu'un debout" % [construit, libres, debout])
	print("SONDE GRANDE BASE : fin")
	get_tree().quit()
