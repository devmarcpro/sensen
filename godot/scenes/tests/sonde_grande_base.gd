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
	if "--tempo" in args:   # le coût d'une image de jeu au camp avec la base peuplée : 5 ticks par image (combat_rules.tempo)
		var par_image: int = int(s.regles.r.get("tempo", {}).get("ticks_max_par_image", 5))
		var budget_ms: float = float(s.regles.r.get("tempo", {}).get("ms_max_par_image", 12))
		var images := 300
		var t3 := Time.get_ticks_usec()
		for k in images:
			s.horloge_monde.avancer(par_image)
		var dt_img := (Time.get_ticks_usec() - t3) / 1000.0 / float(images)
		var pas_n := 0
		for x in s.vivants():
			if x.controle == "ia" and str(x.camp) == "joueur":
				pas_n += 1
		print("tempo : %.2f ms par image de %d ticks avec %d résidents en vue (budget %.0f ms par image : %s)" % [dt_img, par_image, pas_n, budget_ms, "tenu" if dt_img < budget_ms else "DÉPASSÉ"])
	var pos_etal := Vector2i(-1, -1)   # --etal : un étal de vente à côté du joueur, garni chaque semaine du bois du stock (Boutique passive)
	if "--etal" in args:
		# les engagés entourent le joueur : on cherche deux tuiles libres voisines à quelques pas, l'étal sur l'une, le joueur sur l'autre
		for rayon_e in range(1, 6):
			if pos_etal != Vector2i(-1, -1):
				break
			for dy in range(-rayon_e, rayon_e + 1):
				for dx in range(-rayon_e, rayon_e + 1):
					var q: Vector2i = j.pos + Vector2i(dx, dy)
					if not (s.grille.dans(q) and not s.grille.bloque_passage(q) and s.grille.occupant(q).is_empty() and not s.grille.meubles.has(s.grille.idx(q))):
						continue
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var q2: Vector2i = q + d
						if s.grille.dans(q2) and not s.grille.bloque_passage(q2) and (s.grille.occupant(q2).is_empty() or q2 == j.pos) and not s.grille.meubles.has(s.grille.idx(q2)):
							pos_etal = q
							if q2 != j.pos:
								s.grille.liberer(j.pos)
								j.pos = q2
								s.grille.placer(j.id, q2)
							break
					if pos_etal != Vector2i(-1, -1):
						break
				if pos_etal != Vector2i(-1, -1):
					break
		if pos_etal != Vector2i(-1, -1):
			s.grille.poser_contenu(pos_etal, "meuble")
			s.grille.meubles[s.grille.idx(pos_etal)] = "etal_de_vente"
			s.territoire.etals[s._pm(pos_etal)] = true
			var cell_e: Vector2i = s.monde.cellule_de(s._pm(pos_etal))
			var b: Dictionary = s.regles.r.royaume.boutique
			print("étal posé en %s : %d villageois à %d cellules → trafic %.2f client(s) par heure%s · marge ×%.2f" % [str(pos_etal), s.population_autour(cell_e), int(b.rayon), float(b.clients_base) + float(b.par_habitant) * float(s.population_autour(cell_e)), " (sur une route ×%.1f)" % float(b.get("route_mult", 1.0)) if not s.monde.surface.route_de(cell_e).is_empty() else "", float(s.territoire.marge)])
	print("semaine | ms | résidents | logés | lits | trésor | dette | humeur | stocks | journal")
	for k in semaines:
		var ventes0 := 0
		if pos_etal != Vector2i(-1, -1):   # le bois du stock part à l'étal, jusqu'à ses douze places
			ventes0 = int(s.territoire.absence.ventes)
			for cle in s.territoire.stocks.keys():
				if str(cle).ends_with("|brut") and (s.contenants.get(s.grille.idx(pos_etal), []) as Array).size() < 12:
					var mat := str(cle).split("|")[0]
					if s.retirer_stock(j, str(cle)):
						var pile: Dictionary = s._pile(j, mat, "brut")
						if not pile.is_empty():
							s._ranger(j, str(pile.uid), pos_etal, s.horloge_monde.ticks)
		var w: Dictionary = GrandeBase.semaine(s, journal, j)
		var e: Dictionary = w.etat
		if pos_etal != Vector2i(-1, -1):
			print("  étal : %d vente(s) cette semaine · caisse %d or · %d objet(s) en rayon" % [int(s.territoire.absence.ventes) - ventes0, int(s.territoire.caisse), (s.contenants.get(s.grille.idx(pos_etal), []) as Array).size()])
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
	if "--sauvegarde" in args:   # sauvegarde partout (décidé) : la grande base revient entière d'un rechargement
		verifier_sauvegarde(s)
	print("SONDE GRANDE BASE : fin")
	get_tree().quit()


## L'aller-retour de sauvegarde de la base entière : mêmes résidents (poste ET logement), mêmes périmètres, mêmes stocks.
func verifier_sauvegarde(s: Simulation) -> void:
	var avant: Dictionary = GrandeBase.etat(s)
	var postes_avant := {}
	for x in s.residents():
		postes_avant[str(x.id)] = [str(x.assignation.get("perimetre", "")), str(x.assignation.get("residence", "")), str(x.fonction), bool(x.get("affame", false))]
	if not s.sauvegarder("sonde_grande_base"):
		print("SAUVEGARDE : échec d'écriture")
		return
	var s2 := Simulation.new(s.graine)
	if not s2.charger_sauvegarde("sonde_grande_base"):
		print("SAUVEGARDE : échec de relecture")
		return
	var apres: Dictionary = GrandeBase.etat(s2)
	var ecarts: Array[String] = []
	for cle in ["residents", "loges", "lits", "tresor", "dette", "stocks"]:
		if str(avant[cle]) != str(apres[cle]):
			ecarts.append("%s : %s → %s" % [cle, str(avant[cle]), str(apres[cle])])
	if avant.zones != apres.zones:
		ecarts.append("zones : %s → %s" % [str(avant.zones), str(apres.zones)])
	if avant.stockages != apres.stockages:
		ecarts.append("stockages : %s → %s" % [str(avant.stockages), str(apres.stockages)])
	for x in s2.residents():
		var p0: Array = postes_avant.get(str(x.id), [])
		var p1 := [str(x.assignation.get("perimetre", "")), str(x.assignation.get("residence", "")), str(x.fonction), bool(x.get("affame", false))]
		if p0 != p1:
			ecarts.append("%s : %s → %s" % [str(x.id), str(p0), str(p1)])
	if ecarts.is_empty():
		print("SAUVEGARDE : la base revient entière (%d résidents, %d périmètres, %d lits)" % [apres.residents, s2.perimetres().size(), apres.lits])
	else:
		print("SAUVEGARDE : %d écart(s)" % ecarts.size())
		for e in ecarts:
			print("  " + e)
	s2.monde.fermer()
