extends Node
## Sonde du commerce et des quêtes (designer 2026-09-05, 12 h 45 : « je crois bien que les commerces sont cassés, la plupart n'ont
## rien à vendre ou sinon vendent seulement des boucliers non craft »). Elle dit ce que chaque type de boutique tire
## vraiment, ce que la génération d'un objet rend, et ce que les marchands du village le plus proche ont en stock.
##   godot --headless --path godot res://scenes/tests/sonde_commerce.tscn [-- --graine_monde N]

var soucis: Array[String] = []


func _ready() -> void:
	var graine := 9
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--graine_monde" and i + 1 < args.size():
			graine = int(args[i + 1])
	_filtres()
	_generation(graine)
	_village(graine)
	for s in soucis:
		print("  souci : " + s)
	print("SONDE COMMERCE : %s" % ("rien à signaler" if soucis.is_empty() else "%d souci(s)" % soucis.size()))
	get_tree().quit(0 if soucis.is_empty() else 1)


## Chaque bloc de chaque boutique : combien d'objets répondent au filtre, et lesquels.
func _filtres() -> void:
	var ids: Array = GameData.catalogues.shop_types.keys()
	ids.sort()
	for bid in ids:
		var b: Dictionary = GameData.catalogues.shop_types[bid]
		for k in b.get("selection", []).size():
			var bloc: Dictionary = b.selection[k]
			var res: Array = GameData.filtrer("items", bloc.filtre)
			print("boutique %-11s bloc %d %-60s → %d objet(s) : %s" % [bid, k, JSON.stringify(bloc.filtre), res.size(), ", ".join(res.slice(0, 8)) + (" …" if res.size() > 8 else "")])
			if res.is_empty():
				soucis.append("boutique %s bloc %d : aucun objet ne répond au filtre %s" % [bid, k, JSON.stringify(bloc.filtre)])


## Générer un objet de chaque sorte, comme un étal le fait : la base, puis les composants.
func _generation(graine: int) -> void:
	var s := Simulation.new(graine)
	s.charger_arene("gorge")
	for essai in [["craft_cuirasse", ["metal"]], ["craft_bouclier", []], ["proto_bouclier", []], ["craft_epee", ["metal"]], ["craft_tunique", ["vegetal"]], ["potion_soin", []], ["ble", []], ["achillee", []]]:
		var base := str(essai[0])
		if not GameData.catalogues.items.has(base):
			print("génération %-16s : base inconnue" % base)
			continue
		var o: Dictionary = s.generer_objet(base, 1, {"categories_materiau": essai[1]}, "commun", 0)
		if o.is_empty():
			print("génération %-16s → VIDE" % base)
			soucis.append("generer_objet(%s) rend vide" % base)
		else:
			var comps: Dictionary = o.get("composants", {})
			print("génération %-16s → %s · composants %d · matériau « %s » · qualité %.2f" % [base, str(o.get("uid", "")).substr(0, 12), comps.size(), str(o.get("materiau", "")), float(o.get("qualite", 0.0))])
	# Un étal garni comme au village, pour chaque boutique.
	var ids: Array = GameData.catalogues.shop_types.keys()
	ids.sort()
	for bid in ids:
		var faux := {"id": "sonde_" + bid, "stock": []}
		s._garnir_stock(faux, GameData.catalogues.shop_types[bid].selection)
		var bases: Array = []
		for uid in faux.stock:
			bases.append(str(s.items.get(uid, {}).get("base", "?")))
		print("étal %-11s garni : %d objet(s) — %s" % [bid, faux.stock.size(), ", ".join(bases)])
		if faux.stock.is_empty():
			soucis.append("l'étal %s se garnit vide" % bid)


## Le village le plus proche du camp (comme la capture --village) : ses marchands et leurs stocks.
func _village(graine: int) -> void:
	var s := Simulation.new(graine)
	s.charger_camp()
	var c0: Vector2i = s.monde.cellule_camp
	var cible := Vector2i(-9999, -9999)
	for r in range(1, 70):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var cv := c0 + Vector2i(dx, dy)
				if not (s.monde.surface.terre_a(cv) and bool(s.monde.surface.poi_de(cv).get("village", false))):
					continue
				var vv: Dictionary = s.monde.surface.generer_cellule(cv.x, cv.y, {}, false).get("village", {})
				if vv.get("pnj", []).size() >= 4:
					cible = cv
					break
			if cible.x != -9999:
				break
		if cible.x != -9999:
			break
	if cible.x == -9999:
		print("village : aucun village habité à 70 cellules du camp")
		return
	var s2 := Simulation.new(graine)
	s2.charger_camp({}, cible + Vector2i(1, 0))
	var ev: Dictionary = s2.monde.cellule(cible)
	var v: Dictionary = ev.get("village", {})
	var n_bout := 0
	for pj in v.get("pnj", []):
		if not str(pj.get("boutique", "")).is_empty():
			n_bout += 1
	print("village %s en %s : %d PNJ prévus, %d avec boutique, %d bâtiments" % [str(v.get("nom", "?")), str(cible), v.get("pnj", []).size(), n_bout, v.get("batiments", []).size()])
	var n_m := 0
	var vides := 0
	for e in s2.vivants():
		if e.controle == "joueur":
			continue
		var bout := str(e.get("boutique", ""))
		var stock: Array = e.get("stock", [])
		var fiche_vend: bool = not GameData.entree("creatures", str(e.get("def", ""))).get("stock_marchand", []).is_empty()
		if bout.is_empty() and not fiche_vend:
			continue   # tout PNJ porte un `stock` (vide) : n'est marchand que qui a une boutique ou un stock de fiche
		n_m += 1
		var bases := {}
		for uid in stock:
			var b := str(s2.items.get(uid, {}).get("base", "?"))
			bases[b] = int(bases.get(b, 0)) + 1
		print("  %s · boutique « %s » · fonction « %s » · stock %d : %s" % [e.id, bout, str(e.get("fonction", "")), stock.size(), str(bases)])
		if stock.is_empty():
			vides += 1
	print("marchands chargés : %d, dont %d sans rien à vendre" % [n_m, vides])
	if n_m == 0:
		soucis.append("aucun marchand chargé au village")
	elif vides > 0:
		soucis.append("%d marchand(s) sur %d n'ont rien à vendre" % [vides, n_m])
	# Les guichets de quêtes : qui porte le tag, et ce qu'il offre au joueur qui arrive (2026-09-05, 14 h).
	var j2: Dictionary = s2.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_q := 0
	var sans_quete := 0
	for e in s2.vivants():
		if e.controle == "joueur" or not ("quetes" in e.get("tags", [])):
			continue
		n_q += 1
		var offres: Array = s2.quetes_offertes(e, j2)
		var titres: Array = []
		for q in offres:
			titres.append(str(q.get("gabarit", q.get("id", "?"))))
		print("  %s · fonction « %s » · %d quête(s) offerte(s) : %s" % [e.id, str(e.get("fonction", "")), offres.size(), ", ".join(titres)])
		if offres.is_empty():
			sans_quete += 1
	print("guichets de quêtes : %d, dont %d sans rien à proposer" % [n_q, sans_quete])
	if n_q > 0 and sans_quete == n_q:
		soucis.append("aucun guichet de quêtes n'a rien à proposer")
