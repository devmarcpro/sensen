class_name SimPerimetres
extends RefCounted
## Les périmètres de récolte : dessiner, scanner, postes, stockages, maisons, la base, engager, migrants.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


## Les périmètres du territoire : id → {id, cellule, type, richesse, reserve, dominant, matieres}.
static func perimetres(sim: Simulation) -> Dictionary:
	if not sim.territoire.has("perimetres"):
		sim.territoire["perimetres"] = {}
	return sim.territoire.perimetres


## Le premier périmètre d'une cellule ("" sinon) — celui que la touche P de l'écran Gestion fait tourner.
static func perimetre_de(sim: Simulation, cell: Vector2i) -> String:
	for pid in perimetres_de(sim, cell):
		return str(pid)
	return ""


## Tous les périmètres d'une cellule : depuis le 2026-09-04 (10 h 25) le joueur les DESSINE, il peut y en avoir plusieurs.
static func perimetres_de(sim: Simulation, cell: Vector2i) -> Array:
	var res: Array = []
	for pid in perimetres(sim).keys():
		if perimetres(sim)[pid].cellule == cell:
			res.append(str(pid))
	return res


## Les tuiles d'un périmètre, en coordonnées monde : celles qu'il porte (dessinées), sinon toute la cellule.
static func tuiles_de_perimetre(sim: Simulation, pid: String) -> Array:
	var per: Dictionary = perimetres(sim).get(pid, {})
	if per.is_empty() or sim.monde == null:
		return []
	var cell: Vector2i = per.cellule
	var res: Array = []
	if per.has("tuiles") and not (per.tuiles as Array).is_empty():
		for t in per.tuiles:
			res.append(sim.monde.pos_monde(cell, t))
		return res
	for ly in sim.monde.taille:
		for lx in sim.monde.taille:
			res.append(sim.monde.pos_monde(cell, Vector2i(lx, ly)))
	return res


## Créer un périmètre sur une cellule revendiquée : dessiné (`tuiles`, en coordonnées locales) ou, sans tuiles,
## la cellule entière — un seul de ce genre par cellule, retypé s'il existe. Scanné si la cellule est dans la fenêtre.
static func creer_perimetre(sim: Simulation, cell: Vector2i, type: String, tuiles: Array = [], silencieux: bool = false) -> String:
	if sim.monde == null or not sim.monde.claims.has(cell) or not SimTerritoire._ry(sim).get("perimetres", {}).get("types", {}).has(type):
		return ""
	var pid := ""
	if tuiles.is_empty():
		for autre in perimetres_de(sim, cell):
			if not perimetres(sim)[autre].has("tuiles"):
				pid = str(autre)
	if pid.is_empty():
		var n := 1
		while perimetres(sim).has("per_%d_%d_%d" % [cell.x, cell.y, n]):
			n += 1
		pid = "per_%d_%d_%d" % [cell.x, cell.y, n]
	perimetres(sim)[pid] = {"id": pid, "cellule": cell, "type": type, "richesse": 0, "reserve": 0.0, "dominant": "", "matieres": {}}
	if not tuiles.is_empty():
		perimetres(sim)[pid]["tuiles"] = tuiles.duplicate()
	scanner_perimetre(sim, pid)
	if not silencieux:
		EventBus.emettre(&"journal", [&"journal.perimetre_cree", {"type": sim.tr("perimetre.%s.name" % type), "x": cell.x, "y": cell.y, "richesse": int(perimetres(sim)[pid].richesse)}])
	return pid


## Dessiner un périmètre depuis deux coins en coordonnées monde (Écrans d'interface, 2026-09-04) : le rectangle,
## coupé à la cellule du premier coin. Retourne l'id, ou "" si la cellule n'est pas revendiquée.
static func dessiner_perimetre(sim: Simulation, a: Vector2i, b: Vector2i, type: String) -> String:
	if sim.monde == null:
		return ""
	var cell := sim.monde.cellule_de(a)
	var tuiles: Array = []
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			var pos := Vector2i(x, y)
			if sim.monde.cellule_de(pos) == cell:
				var li := sim.monde.idx_local(pos)
				tuiles.append(Vector2i(li % sim.monde.taille, li / sim.monde.taille))
	return creer_perimetre(sim, cell, type, tuiles)


## Retirer un périmètre : ses résidents reviennent à la production de leur fonction.
static func retirer_perimetre(sim: Simulation, pid: String) -> bool:
	if not perimetres(sim).has(pid):
		return false
	var cell: Vector2i = perimetres(sim)[pid].cellule
	perimetres(sim).erase(pid)
	for x in SimTerritoire.residents(sim):
		if str(x.assignation.get("perimetre", "")) == pid:
			x.assignation.erase("perimetre")
		if str(x.assignation.get("residence", "")) == pid:
			x.assignation.erase("residence")
	EventBus.emettre(&"journal", [&"journal.perimetre_retire", {"x": cell.x, "y": cell.y}])
	return true


## Scanner un périmètre : combien de tuiles de sa cellule portent la ressource, et quelle matière domine. Ne
## regarde que la fenêtre ; hors fenêtre, la dernière mesure reste. Retourne la richesse.
static func scanner_perimetre(sim: Simulation, pid: String) -> int:
	if not perimetres(sim).has(pid) or sim.monde == null or sim.lieu != "camp":
		return 0
	var per: Dictionary = perimetres(sim)[pid]
	var cell: Vector2i = per.cellule
	if absi(cell.x - sim.monde.centre.x) > sim.monde.rayon or absi(cell.y - sim.monde.centre.y) > sim.monde.rayon:
		return int(per.richesse)
	var pcfg: Dictionary = SimTerritoire._ry(sim).get("perimetres", {})
	var tp: Dictionary = pcfg.get("types", {}).get(str(per.type), {})
	var tag := str(tp.get("tag", ""))
	var matieres := {}
	var n := 0
	var interieur := {}   # résidentiel : l'intérieur d'une maison n'est pas à bâtir (2026-09-04)
	if bool(tp.get("residentiel", false)):
		for piece in SimTerritoire.pieces_de_cellule(sim, cell):
			for t in piece.get("tuiles", []):
				interieur[t] = true
	for pos in tuiles_de_perimetre(sim, pid):
		if not sim.grille.dans(pos):
			continue
		if bool(tp.get("residentiel", false)) or bool(tp.get("stockage", false)):   # résidentiel, stockage : la richesse, ce sont les tuiles libres
			# libre = ni mur, ni meuble, ni bâti, ni intérieur d'une pièce ; quelqu'un debout ne compte pas (il bouge)
			if not sim.grille.bloque_passage(pos) and not sim.grille.meubles.has(sim.grille.idx(pos)) and not interieur.has(pos) 				and not ("construit" in sim.grille.contenu_de(pos).get("tags", [])):
				n += 1
			continue
		if not (tag in sim.grille.contenu_de(pos).get("tags", [])):
			continue
		n += 1
		var m := sim.grille.materiau_de(pos)
		if m.is_empty():
			m = str(tp.get("materiau_defaut", ""))
		if not m.is_empty():
			matieres[m] = int(matieres.get(m, 0)) + 1
	var dominant := str(tp.get("materiau_defaut", ""))
	var meilleur := 0
	for m in matieres.keys():
		if int(matieres[m]) > meilleur:
			meilleur = int(matieres[m])
			dominant = str(m)
	per.richesse = n
	per.matieres = matieres
	per.dominant = dominant
	per.reserve = float(n) * float(pcfg.get("unites_par_tuile", 1.5))
	if bool(tp.get("stockage", false)):   # un stockage : sa capacité suit ses tuiles (un stockage par poste, 2026-09-04)
		per["capacite"] = n * int(SimTerritoire._ry(sim).get("stockage", {}).get("unites_par_tuile", 10))
		if not per.has("contenu"):
			per["contenu"] = {}
	return n


## Une tuile de travail dans un périmètre : la case libre au bord de la ressource la plus proche de `depuis`,
## ou (−1, −1) si la cellule n'est pas dans la fenêtre (le poste reste alors là où l'on est).
static func _poste_de_perimetre(sim: Simulation, pid: String, depuis: Vector2i) -> Vector2i:
	if not perimetres(sim).has(pid) or sim.monde == null or sim.lieu != "camp":
		return Vector2i(-1, -1)
	var per: Dictionary = perimetres(sim)[pid]
	var cell: Vector2i = per.cellule
	if absi(cell.x - sim.monde.centre.x) > sim.monde.rayon or absi(cell.y - sim.monde.centre.y) > sim.monde.rayon:
		return Vector2i(-1, -1)
	var tag := str(SimTerritoire._ry(sim).get("perimetres", {}).get("types", {}).get(str(per.type), {}).get("tag", ""))
	var meilleur := Vector2i(-1, -1)
	var dmin := 999999
	if tag.is_empty():
		return meilleur
	for pos in tuiles_de_perimetre(sim, pid):
		if not sim.grille.dans(pos) or not (tag in sim.grille.contenu_de(pos).get("tags", [])):
			continue
		for v: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = pos + v
			if not sim.grille.dans(q) or sim.grille.bloque_passage(q) or not sim.grille.occupant(q).is_empty():
				continue
			var d := Grille.distance(depuis, q)
			if d < dmin:
				dmin = d
				meilleur = q
	return meilleur


## Prendre `n` unités d'une famille de matériaux sur le stock du territoire, n'importe quelle forme : vrai si on a pu.
static func _prendre_stock_famille(sim: Simulation, famille: String, n: int) -> bool:
	var fam: Dictionary = GameData.config("material_families").get(famille, {})
	var cles: Array = []
	var total := 0
	for cle in sim.territoire.stocks.keys():
		var mat_id := str(cle).split("|")[0]
		var mat: Dictionary = GameData.catalogues.materials.get(mat_id, {})
		var ok: bool = (fam.has("category") and str(mat.get("category", "")) == str(fam.category)) \
			or (fam.has("material") and mat_id == str(fam.material)) \
			or (fam.has("tag") and str(fam.tag) in mat.get("tags", []))
		if ok:
			cles.append(cle)
			total += int(sim.territoire.stocks[cle])
	if total < n:
		return false
	var reste := n
	for cle in cles:
		var pris := mini(reste, int(sim.territoire.stocks[cle]))
		sim.territoire.stocks[cle] = int(sim.territoire.stocks[cle]) - pris
		if int(sim.territoire.stocks[cle]) <= 0:
			sim.territoire.stocks.erase(cle)
		_retirer_des_stockages(sim, str(cle), pris)
		reste -= pris
		if reste <= 0:
			break
	return true


## La place qui reste dans un stockage : sa capacité moins ce qu'il contient.
static func place_stockage(sim: Simulation, pid: String) -> int:
	var st: Dictionary = perimetres(sim).get(pid, {})
	if st.is_empty():
		return 0
	var total := 0
	for cle in st.get("contenu", {}).keys():
		total += int(st.contenu[cle])
	return maxi(0, int(st.get("capacite", 0)) - total)


## Désigner le stockage d'un périmètre de production ("" pour aucun) : un stockage par poste (designer 2026-09-04).
static func assigner_stockage(sim: Simulation, pid: String, pid_stockage: String) -> bool:
	if not perimetres(sim).has(pid):
		return false
	if pid_stockage.is_empty():
		perimetres(sim)[pid].erase("stockage")
		return true
	var st: Dictionary = perimetres(sim).get(pid_stockage, {})
	if st.is_empty() or not bool(SimTerritoire._ry(sim).get("perimetres", {}).get("types", {}).get(str(st.type), {}).get("stockage", false)):
		return false
	perimetres(sim)[pid]["stockage"] = pid_stockage
	return true


## Ce qu'on prend au stock du territoire sort aussi des stockages qui le tenaient.
static func _retirer_des_stockages(sim: Simulation, cle: String, n: int) -> void:
	var reste := n
	for pid in perimetres(sim).keys():
		var st: Dictionary = perimetres(sim)[pid]
		if not st.has("contenu") or int(st.contenu.get(cle, 0)) <= 0:
			continue
		var pris := mini(reste, int(st.contenu[cle]))
		st.contenu[cle] = int(st.contenu[cle]) - pris
		if int(st.contenu[cle]) <= 0:
			st.contenu.erase(cle)
		reste -= pris
		if reste <= 0:
			return


## Les maisons automatiques (Population et exploitation, 2026-09-04) : au passage de semaine, chaque résident
## assigné à un périmètre résidentiel sans lit valide se fait bâtir le préfab `royaume.maisons.plan` sur les tuiles
## libres du périmètre, si le stock a `royaume.maisons.cout`. Seulement quand la cellule est dans la fenêtre.
static func _batir_maisons(sim: Simulation) -> int:
	var mc: Dictionary = SimTerritoire._ry(sim).get("maisons", {})
	if mc.is_empty() or sim.monde == null or sim.lieu != "camp":
		return 0
	var bat: Dictionary = GameData.catalogues.get("village_buildings", {}).get(str(mc.get("plan", "chaumiere")), {})
	if bat.is_empty():
		return 0
	var plan: Array = bat.plan
	var meubles: Dictionary = bat.get("meubles", {})
	var baties := 0
	var sans_place := 0   # une ligne pour tous ceux qu'on n'a pas pu loger (grande base, 2026-09-04)
	var pieces_par_cell: Dictionary = {}   # la détection de pièces d'une cellule, une fois par semaine (une ville : cent résidents)
	for x in SimTerritoire.residents(sim):
		if baties >= int(mc.get("max_par_semaine", 2)):
			break
		var pid := str(x.assignation.get("residence", ""))
		if pid.is_empty() or not perimetres(sim).has(pid):
			continue
		var cell: Vector2i = perimetres(sim)[pid].cellule
		if absi(cell.x - sim.monde.centre.x) > sim.monde.rayon or absi(cell.y - sim.monde.centre.y) > sim.monde.rayon:
			continue
		if not pieces_par_cell.has(cell):
			pieces_par_cell[cell] = SimTerritoire.pieces_de_cellule(sim, cell)
		if x.has("lit") and not SimTerritoire._piece_du_lit(sim, x.lit, pieces_par_cell[cell]).is_empty():
			continue   # déjà logé dans une pièce valide
		var origine := _emplacement_maison(sim, pid, plan)
		if origine == Vector2i(-1, -1):
			sans_place += 1
			continue
		var ok := true
		for c in mc.get("cout", []):
			if not _prendre_stock_famille(sim, str(c.famille), int(c.n)):
				ok = false
		if not ok:
			EventBus.emettre(&"journal", [&"journal.maison_pas_de_materiaux", {"nom": x.name_key}])
			return baties
		var lit := Vector2i(-1, -1)
		var mat_mur := _materiau_de_famille(sim, str(mc.get("cout", [{"famille": "bois"}])[0].famille))
		for y in plan.size():
			var ligne: String = plan[y]
			for xx in ligne.length():
				var ch := ligne[xx]
				var pos := origine + Vector2i(xx, y)
				var idx := sim.grille.idx(pos)
				if ch == "#":
					sim.grille.poser_contenu(pos, "mur_construit")
					sim.grille.materiaux[idx] = mat_mur
				elif ch == "P":
					sim.grille.poser_contenu(pos, "porte")
					sim.grille.materiaux[idx] = mat_mur
				elif meubles.has(ch):
					var m: Dictionary = GameData.entree("meubles", str(meubles[ch]))
					sim.grille.poser_contenu(pos, "meuble" if bool(m.get("bloque_passage", false)) else "meuble_sol")
					sim.grille.meubles[idx] = str(meubles[ch])
					if str(meubles[ch]).begins_with("lit"):
						lit = pos
				sim.grille.marquer(pos)
				EventBus.emettre(&"tile_changed", [pos])
		for y2 in plan.size():   # quiconque se tenait sur un mur ou un meuble est déplacé sur la tuile libre la plus proche (2026-09-04)
			for x2 in str(plan[y2]).length():
				var pos2 := origine + Vector2i(x2, y2)
				var occ := str(sim.grille.occupant(pos2))
				if occ.is_empty() or not sim.entites.has(occ) or not (sim.grille.bloque_passage(pos2) or sim.grille.meubles.has(sim.grille.idx(pos2))):
					continue
				var y_o: Dictionary = sim.entites[occ]
				var q_o: Vector2i = SimLieux._tuile_libre_pres(sim, y_o, pos2)
				if q_o == Vector2i(-1, -1) or q_o == pos2:
					continue
				sim.grille.liberer(pos2)
				var dedans_o: bool = y_o.get("poste", pos2) == pos2
				y_o.pos = q_o
				sim.grille.placer(y_o.id, q_o)
				if dedans_o:
					y_o["poste"] = q_o
					y_o.ancre = q_o
					y_o["place"] = q_o
		if lit != Vector2i(-1, -1):
			x["lit"] = lit
		x.humeur = int(SimTerritoire._ry(sim).humeur_base)
		sim.lumiere_sale = true
		baties += 1
		scanner_perimetre(sim, pid)   # ses tuiles libres viennent de diminuer : la place restante se lit juste (2026-09-04)
		EventBus.emettre(&"journal", [&"journal.maison_batie", {"nom": x.name_key, "x": origine.x, "y": origine.y}])
	if sans_place > 0:
		EventBus.emettre(&"journal", [&"journal.maison_pas_de_place", {"n": sans_place}])
	if baties > 0:
		SimTerritoire._recalculer_humeurs(sim)
	return baties


## Un matériau de la famille pour les murs : le premier du catalogue qui en est, sinon le nom de la famille.
static func _materiau_de_famille(sim: Simulation, famille: String) -> String:
	var fam: Dictionary = GameData.config("material_families").get(famille, {})
	if fam.has("material"):
		return str(fam.material)
	for mid in GameData.catalogues.materials.keys():
		var mat: Dictionary = GameData.catalogues.materials[mid]
		if fam.has("category") and str(mat.get("category", "")) == str(fam.category):
			return str(mid)
	return famille


## Où poser le préfab dans un périmètre : la première origine dont toute l'empreinte tient sur des tuiles du
## périmètre, libres, praticables, sans construction ni meuble ; (−1, −1) sinon.
static func _emplacement_maison(sim: Simulation, pid: String, plan: Array) -> Vector2i:
	var tuiles: Array = tuiles_de_perimetre(sim, pid)
	var dedans := {}
	for t in tuiles:
		dedans[t] = true
	var h: int = plan.size()
	var w: int = 0
	for ligne in plan:
		w = maxi(w, str(ligne).length())
	for o in tuiles:
		var ok := true
		for y in h:
			for x in w:
				var pos: Vector2i = o + Vector2i(x, y)
				# un être debout ne bloque pas le chantier : il sera déplacé (2026-09-04) — murs et meubles bloquent toujours
				if not dedans.has(pos) or not sim.grille.dans(pos) or sim.grille.bloque_passage(pos) \
					or sim.grille.meubles.has(sim.grille.idx(pos)) or ("construit" in sim.grille.contenu_de(pos).get("tags", [])):
					ok = false
					break
			if not ok:
				break
		if ok:
			return o
	return Vector2i(-1, -1)


## Le passage de semaine : la réserve d'un périmètre repousse sur une cellule Ressources naturelles (Rôles de cases).
static func _repousser_perimetres(sim: Simulation) -> void:
	var pcfg: Dictionary = SimTerritoire._ry(sim).get("perimetres", {})
	for pid in perimetres(sim).keys():
		var per: Dictionary = perimetres(sim)[pid]
		if str(sim.monde.claims.get(per.cellule, {}).get("role", "")) != "ressources":
			continue
		var plein := float(per.get("richesse", 0)) * float(pcfg.get("unites_par_tuile", 1.5))
		per.reserve = minf(plein, float(per.get("reserve", 0.0)) + plein * float(pcfg.get("repousse_hebdo", 0.1)))


## La cellule de la base (Décision — Gestion de base) : la revendiquée de rôle « base », sinon la première.
static func _cellule_base(sim: Simulation) -> Vector2i:
	if sim.monde == null or sim.monde.claims.is_empty():
		return Vector2i(-1, -1)
	for cell in sim.monde.claims.keys():
		if str(sim.monde.claims[cell].get("role", "")) == "base":
			return cell
	var cells: Array = sim.monde.claims.keys()
	cells.sort()
	return cells[0]


## Un PNJ devient résident oisif de la base (Population et exploitation, 2026-09-04) : engagé ou migrant. S'il est
## dans la fenêtre, il s'installe sur une case libre près de `chez` ; sinon il est mis de côté dans la cellule de la
## base, et la projection du LOD 2 le placera à son réveil. Retourne la position qu'il a prise.
static func _installer_a_la_base(sim: Simulation, x: Dictionary, base: Vector2i) -> Vector2i:
	var ry: Dictionary = SimTerritoire._ry(sim)
	x.erase("maitre")
	x.camp = "joueur"
	x.ai_profile = "civil"
	x["fonction"] = str(ry.get("engagement", {}).get("fonction_defaut", "oisif"))
	x["role"] = "resident"
	x["assignation"] = {"fonction": x.fonction, "cellule": base}
	x["humeur"] = int(ry.humeur_base) + int(ry.sans_logement)   # sans logement tant qu'on ne l'assigne pas à un lit
	x.erase("lit")
	x["village"] = ""
	var centre := Vector2i(sim.monde.taille / 2, sim.monde.taille / 2)
	var chez: Vector2i = sim.camp_sauve.get("entree", sim.monde.pos_monde(base, centre)) if base == sim.monde.cellule_camp else sim.monde.pos_monde(base, centre)
	var dans_fenetre: bool = sim.lieu == "camp" and absi(base.x - sim.monde.centre.x) <= sim.monde.rayon and absi(base.y - sim.monde.centre.y) <= sim.monde.rayon
	if dans_fenetre and sim.grille.dans(chez):
		if SimCamp._cell_de(sim, x.pos) != base or not sim.entites.has(x.id):
			var q: Vector2i = SimLieux._tuile_libre_pres(sim, x, chez)
			if sim.entites.has(x.id):
				sim.grille.liberer(x.pos)
			x.pos = q
			if not sim.entites.has(x.id):
				sim.entites[x.id] = x
				sim.ordre.append(x.id)
			sim.grille.placer(x.id, x.pos)
	else:
		if sim.entites.has(x.id):   # il part : hors de la grille, dormant dans la cellule de la base
			sim.grille.liberer(x.pos)
			sim.ordre.erase(x.id)
			sim.entites.erase(x.id)
		x.pos = chez
		x["dormant_depuis"] = sim.horloge_monde.ticks
		if not sim.monde.dormants.has(base):
			sim.monde.dormants[base] = []
		sim.monde.dormants[base].append(x)
	x["poste"] = x.pos
	x.ancre = x.pos
	x["place"] = x.pos
	return x.pos


## Engager un PNJ pour la base (Décision — Gestion de base, étape 1) : même seuil de relation que le recrutement,
## moins une tolérance, contre de l'or qui va dans sa bourse ; il part s'installer, résident oisif, sans place d'escorte.
static func _engager(sim: Simulation, e: Dictionary, pnj_id: String, tick: int) -> bool:
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	if pnj.is_empty() or not pnj.vivant or pnj.has("maitre") or pnj.has("assignation") or Grille.distance(e.pos, pnj.pos) > 2:
		return false
	var base := _cellule_base(sim)
	if base == Vector2i(-1, -1):
		EventBus.emettre(&"journal", [&"journal.pas_de_base", {}])
		return false
	var def: Dictionary = GameData.catalogues.creatures.get(str(pnj.def), {})
	var rc: Dictionary = def.get("recruitable", {"method": "jamais"})
	var eng: Dictionary = SimTerritoire._ry(sim).get("engagement", {})
	var seuil := int(rc.get("threshold", 60)) - int(eng.get("tolerance_relation", 10))
	var ok := (str(rc.get("method", "jamais")) == "relation" and SimPnj.relation_de(sim, pnj, e) >= seuil) or bool(pnj.get("recrutable_hors_condition", false))
	if not ok:
		EventBus.emettre(&"journal", [&"journal.pas_recrutable", {"nom": pnj.name_key}])
		return false
	var prix := int(eng.get("or", 20))
	if int(e.get("or", 0)) < prix:
		EventBus.emettre(&"journal", [&"journal.engager_or", {"or": prix}])
		return false
	e.or = int(e.or) - prix
	pnj["or"] = int(pnj.get("or", 0)) + prix
	_installer_a_la_base(sim, pnj, base)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.engage", {"nom": pnj.name_key, "or": prix}])
	SimTerritoire._verifier_royaume(sim, e)
	return true


## Les migrants (Population et exploitation, 2026-09-04) : au passage de semaine, si la base a de la place, un
## villageois vient de lui-même — une chance de base, que la réputation globale multiplie. Un par semaine au plus.
static func _semaine_migrants(sim: Simulation, e: Dictionary) -> void:
	var mg: Dictionary = SimTerritoire._ry(sim).get("migrants", {})
	if mg.is_empty() or sim.monde == null:
		return
	var base := _cellule_base(sim)
	if base == Vector2i(-1, -1):
		return
	if SimTerritoire.residents(sim).size() >= int(mg.get("residents_par_cellule", 4)) * sim.monde.claims.size():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "migrant", sim.monde.semaine_courante])
	var chance := float(mg.get("chance_base", 0.2)) * (1.0 + float(e.get("reputations", {}).get("_globale", 0)) / 100.0)
	if rng.randf() > chance:
		return
	sim._n_entites += 1
	var def_id := str(mg.get("creature", "villageois"))
	var def: Dictionary = GameData.entree("creatures", def_id)
	var x := Etres.instancier("%s_%d" % [def_id, sim._n_entites], def, Vector2i.ZERO, "ia", sim.regles, sim.items)
	x["or"] = 0
	SimObjets._habiller_pnj(sim, x, def)
	_installer_a_la_base(sim, x, base)
	EventBus.emettre(&"journal", [&"journal.migrant", {"nom": x.name_key}])
