class_name SimFabrication
extends RefCounted
## Le craft compositionnel et la fabrication aux stations.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


## Façonner un composant : une unité de la famille, à la station de la recette ; le composant porte les
## 13 stats et le vecteur Wu Xing de son matériau, et une qualité A.3 sur la compétence de la station.
static func _faconner(sim: Simulation, e: Dictionary, r: Dictionary, tick: int) -> bool:
	if not stations_de(sim, e).has(str(r.station)):
		EventBus.emettre(&"journal", [&"journal.pas_de_station", {"recette": GameData.entree("components", r.component).name_key}])
		return false
	if not bool(r.unlocked_by_default) and not (str(r.id) in e.get("recettes_connues", [])):
		return false
	var plan := _plan_composant(sim, e, r)
	if not plan.faisable:
		EventBus.emettre(&"journal", [&"journal.manque", {"recette": GameData.entree("components", r.component).name_key}])
		return false
	var pile: Dictionary = plan.entrees[0].pile
	var mat_id := str(pile.materiau)
	SimTerrain._retirer_materiau(sim, e, pile, 1)
	var comp: Dictionary = GameData.entree("components", r.component)
	var station: Dictionary = GameData.entree("stations", r.station)
	var skill := str(station.craft_skill)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "craft", sim.objets.size(), r.id])
	var inst: Dictionary = SimObjets.generer_objet(sim, "composant", 1, {}, "commun", 0)
	if inst.is_empty():
		return false
	var mat: Dictionary = GameData.entree("materials", mat_id)
	inst.composant = str(r.component)
	inst.materiau = mat_id
	if not str(pile.get("espece", "")).is_empty():   # l'espèce voyage de la peau au composant (point 69)
		inst["espece"] = str(pile.espece)
	inst.name_key = comp.name_key
	inst.stats = sim.stats_materiau(mat, str(inst.get("espece", "")))
	inst.elements = mat.wuxing.duplicate()
	inst.qualite = sim.regles.qualite_craft(sim.regles.niveau(e.competences_eff, skill), rng, sim.regles.resserrement_recette(SimTerritoire.niveau_recette(sim, e, str(r.id))))
	e.sac.append(inst.uid)
	var n := sim.regles.niveau(e.competences_eff, skill)
	e.compteur = tick + sim._ticks_avec_statuts(e, maxi(1, ceili(float(sim.regles.r.craft.ticks_base) / sim.regles.skill_factor(n))))
	sim.gagner_xp(e, skill, int(mat.stats.durete))
	EventBus.emettre(&"journal", [&"journal.faconne", {"nom": e.name_key, "objet": SimObjets.nom_objet(sim, inst.uid), "qualite": "qualite." + sim.regles.palier_qualite(inst.qualite)}])
	SimPnj._progresser_quetes(sim, e, "fabriquer", ["composant"])
	return true


## Assembler un objet depuis ses composants (Stats et qualité de l'assemblage) : stats = Σ stat × poids,
## durete_base avant qualité, qualité = Σ q × poids × jet borné, Wu Xing composite, vitesse du manche.
static func _assembler(sim: Simulation, e: Dictionary, def: Dictionary, tick: int) -> bool:
	var st := str(def.recipe.station)
	if not stations_de(sim, e).has(st):
		EventBus.emettre(&"journal", [&"journal.pas_de_station", {"recette": def.name_key}])
		return false
	var plan := _plan_objet(sim, e, def)
	if not plan.faisable:
		EventBus.emettre(&"journal", [&"journal.manque", {"recette": def.name_key}])
		return false
	var pieces: Array[Dictionary] = []
	for en in plan.entrees:
		var c: Dictionary = en.pile
		pieces.append({"slot": en.slot, "composant": c.composant, "materiau": c.materiau, "qualite": c.qualite, "stats": c.stats, "elements": c.elements})
		e.sac.erase(c.uid)
		sim.items.erase(c.uid)
	var skill := str(def.recipe.craft_skill)
	var n := sim.regles.niveau(e.competences_eff, skill)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "assemblage", sim.objets.size(), def.id])
	var borne: Array = sim.regles.r.craft.qualite.jet_assemblage
	var jet := clampf(sim.regles.qualite_craft(n, rng, sim.regles.resserrement_recette(SimTerritoire.niveau_recette(sim, e, str(def.id)))), float(borne[0]), float(borne[1]))
	var inst: Dictionary = SimObjets.generer_objet(sim, def.id, 1, {"assemblage": true}, "commun", 0)
	if inst.is_empty():
		return false
	SimObjets._appliquer_composition(sim, inst, def, pieces, jet)
	e.sac.append(inst.uid)
	e.compteur = tick + sim._ticks_avec_statuts(e, maxi(1, ceili(float(sim.regles.r.craft.ticks_base) / sim.regles.skill_factor(n))))
	sim.gagner_xp(e, skill, inst.durete_base)
	EventBus.emettre(&"journal", [&"journal.assemble", {"nom": e.name_key, "objet": SimObjets.nom_objet(sim, inst.uid), "qualite": "qualite." + sim.regles.palier_qualite(inst.qualite)}])
	SimPnj._progresser_quetes(sim, e, "fabriquer", ["objet"])
	for x in sim.entites.values():   # Sauvegarde : aucun combat ne survit au rechargement — tout le monde sur l'horloge du monde
		if x.horloge != "monde":
			x.horloge = "monde"
			x.compteur = sim.horloge_monde.ticks
			x.action_en_cours = {}
	sim.combats.clear()
	return true


# ---------------------------------------------------------------- fabrication (Stations de transformation)

## Les stations portées : id de station → uid de l'objet.
static func stations_de(sim: Simulation, e: Dictionary) -> Dictionary:
	var res := {}
	for uid in e.sac:
		var it: Dictionary = sim.items.get(uid, {})
		if it.get("type", "") == "station":
			res[str(it.station)] = uid
	# Les stations fixes sous le joueur ou adjacentes (Stations de transformation : la version fixe).
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t: Vector2i = e.pos + Vector2i(dx, dy)
			if sim.grille.dans(t) and sim.grille.stations_fixes.has(sim.grille.idx(t)):
				res[str(sim.grille.stations_fixes[sim.grille.idx(t)])] = "fixe"
	return res


## Tout ce que les stations du sac permettent : transformations plates, composants (recettes connues),
## objets assemblés. [{id, kind, recette, station, faisable, entrees, sortie}]
static func recettes_disponibles(sim: Simulation, e: Dictionary) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	var stations := stations_de(sim, e)
	var ids: Array = GameData.catalogues.recipes.keys()
	ids.sort()
	for rid in ids:
		var r: Dictionary = GameData.catalogues.recipes[rid]
		if bool(r.get("industrielle", false)) and not (str(rid) in e.get("recettes_connues", [])):   # Palier industriel : il faut le plan
			continue
		if stations.has(str(r.station)):
			var pl := _plan_recette(sim, e, r)
			pl["kind"] = "plate"
			res.append(pl)
	ids = GameData.catalogues.component_recipes.keys()
	ids.sort()
	for rid in ids:
		var r: Dictionary = GameData.catalogues.component_recipes[rid]
		if not stations.has(str(r.station)):
			continue
		if not bool(r.unlocked_by_default) and not (rid in e.get("recettes_connues", [])):
			continue
		res.append(_plan_composant(sim, e, r))
	ids = GameData.catalogues.items.keys()
	ids.sort()
	for iid in ids:
		var it: Dictionary = GameData.catalogues.items[iid]
		if it.has("slots") and stations.has(str(it.get("recipe", {}).get("station", ""))):
			res.append(_plan_objet(sim, e, it))
	return res


## Le plan d'une recette de composant : une unité de la famille de matériaux, prise dans le sac.
static func _plan_composant(sim: Simulation, e: Dictionary, r: Dictionary) -> Dictionary:
	var fam: Dictionary = GameData.config("material_families").get(str(r.material_family), {})
	var pile := _pile_famille(sim, e, fam)
	return {"id": r.id, "kind": "composant", "recette": r, "station": str(r.station), "faisable": not pile.is_empty(),
		"entrees": [{"pile": pile, "besoin": 1, "forme": str(fam.get("forme", "brut")), "filtre": str(r.material_family)}],
		"sortie": {"composant": str(r.component), "materiau": str(pile.get("materiau", "")), "quantite": 1}}


## La première pile du sac qui appartient à la famille (catégorie ou matériau(x), et forme).
static func _pile_famille(sim: Simulation, e: Dictionary, fam: Dictionary) -> Dictionary:
	if fam.is_empty() or fam.has("tag"):
		return {}   # familles paramétriques (os, écailles…) : pas de source encore
	var forme := str(fam.get("forme", "brut"))
	for uid in e.sac:
		var it: Dictionary = sim.items.get(uid, {})
		if it.get("type", "") != "materiau" or str(it.get("forme", "brut")) != forme or int(it.quantite) < 1:
			continue
		var m := str(it.materiau)
		var mat: Dictionary = GameData.catalogues.materials.get(m, {})
		if fam.has("category") and str(mat.get("category", "")) != str(fam.category):
			continue
		if fam.has("material") and m != str(fam.material):
			continue
		if fam.has("materials") and not (m in fam.materials):
			continue
		return it
	return {}


## Le plan d'un objet assemblé : un composant du sac par slot.
static func _plan_objet(sim: Simulation, e: Dictionary, it: Dictionary) -> Dictionary:
	var plan := {"id": it.id, "kind": "objet", "recette": it, "station": str(it.recipe.station), "faisable": true, "entrees": [], "sortie": {"objet": it.id, "quantite": 1}}
	var pris := {}
	for slot in it.slots.keys():
		var trouve := {}
		for uid in e.sac:
			var c: Dictionary = sim.items.get(uid, {})
			if c.get("type", "") == "composant" and str(c.composant) == str(it.slots[slot]) and not pris.has(uid):
				trouve = c
				pris[uid] = true
				break
		plan.entrees.append({"pile": trouve, "besoin": 1, "forme": "", "filtre": str(it.slots[slot]), "slot": slot})
		if trouve.is_empty():
			plan.faisable = false
	return plan


## Le plan d'une recette pour cet être : les piles du sac qui satisfont chaque entrée (par matériau
## ou par catégorie — la première pile suffisante, dans l'ordre du sac).
static func _plan_recette(sim: Simulation, e: Dictionary, r: Dictionary) -> Dictionary:
	var plan := {"id": r.id, "recette": r, "station": str(r.station), "faisable": true, "entrees": [], "sortie": {}}
	var mat_sortie := str(r.output.get("material", ""))
	var deja: Dictionary = {}   # les piles déjà retenues par une entrée optionnelle
	# Fiole vive : le double d'ingrédients pour deux fioles — vrai pour toute recette d'alchimie,
	# y compris celles dont la sortie n'est connue qu'une fois l'ingrédient choisi (`depuis_entree`).
	var potion_double: bool = SimTalents.a_talent(sim, e, "fiole_vive") and ("potion" in GameData.catalogues.items.get(str(r.get("output", {}).get("item", "")), {}).get("tags", []) or str(r.station) == "alambic")
	for entree in r.inputs:
		var besoin := int(entree.amount) * (2 if potion_double else 1)   # Fiole vive : le double d'ingrédients
		var forme := str(entree.get("forme", "brut"))
		var trouvee := {}
		var exclus: Array = e.get("exclusions_recette", {}).get(str(r.get("id", "")), [])
		for uid in e.sac:
			var it: Dictionary = sim.items.get(uid, {})
			if deja.has(uid) or (bool(entree.get("optionnel", false)) and uid in exclus):
				continue
			if entree.has("item"):   # une entrée par objet (viande crue, baies…) : la pile de cette base
				if str(it.get("base", "")) == str(entree.item) and int(it.get("quantite", 1)) >= besoin:
					trouvee = it
					break
				continue
			if entree.has("tag"):   # une entrée par tag d'objet (toute culture pour une potion)
				if str(entree.tag) in it.get("tags", []) and int(it.get("quantite", 1)) >= besoin:
					trouvee = it
					break
				continue
			if entree.has("espece"):   # un spécimen d'élevage de cette espèce (filer la soie)
				if str(it.get("espece", "")) == str(entree.espece):
					trouvee = it
					break
				continue
			if it.get("type", "") != "materiau" or str(it.get("forme", "brut")) != forme or int(it.quantite) < besoin:
				continue
			var mat: Dictionary = GameData.catalogues.materials.get(str(it.materiau), {})
			if entree.has("material") and str(it.materiau) != str(entree.material):
				continue
			if entree.has("category") and str(mat.get("category", "")) != str(entree.category):
				continue
			trouvee = it
			break
		if bool(entree.get("optionnel", false)):
			if trouvee.is_empty():
				continue
			deja[str(trouvee.uid)] = true
			plan.entrees.append({"pile": trouvee, "besoin": besoin, "forme": forme, "optionnel": true, "filtre": str(entree.get("material", entree.get("category", entree.get("item", entree.get("tag", entree.get("espece", ""))))))})
			continue
		plan.entrees.append({"pile": trouvee, "besoin": besoin, "forme": forme, "filtre": str(entree.get("material", entree.get("category", entree.get("item", entree.get("tag", entree.get("espece", ""))))))})
		if trouvee.is_empty():
			plan.faisable = false
		elif mat_sortie.is_empty() and trouvee.has("materiau"):
			mat_sortie = str(trouvee.materiau)   # la sortie garde le matériau de l'entrée (lingot de fer…)
	plan.sortie = {"materiau": mat_sortie, "forme": str(r.output.get("forme", "brut")), "quantite": int(r.output.amount), "item": str(r.output.get("item", ""))}
	if r.output.has("depuis_entree"):   # la sortie se lit sur l'INGRÉDIENT (Craft compositionnel) : une seule
		plan.sortie.item = ""            # recette « distiller une herbe » plutôt qu'une par plante du jeu
		for entree in plan.entrees:
			if str(entree.filtre) != str(r.output.depuis_entree) or entree.pile.is_empty():
				continue
			var fiche: Dictionary = GameData.catalogues.items.get(str(entree.pile.get("base", "")), {})
			plan.sortie.item = str(fiche.get(str(r.output.champ), ""))
		if plan.sortie.item.is_empty():
			plan.faisable = false
	if bool(r.output.get("herite_espece", false)) and plan.faisable:
		# L'espèce est un MODIFICATEUR porté par l'objet, jamais un matériau de plus (designer 2026-09-01) :
		# la peau transmet sa bête au cuir tanné, qui la transmettra au composant puis à l'objet assemblé.
		for entree in plan.entrees:
			var esp := str(entree.pile.get("espece", ""))
			if not esp.is_empty():
				plan.sortie["espece"] = esp
	if r.output.has("par_locus") and plan.faisable:   # la quantité suit un locus du spécimen consommé (finesse du fil)
		for entree in plan.entrees:
			if entree.pile.has("genome"):
				plan.sortie.quantite = maxi(1, roundi(float(entree.pile.genome.get(str(r.output.par_locus), 1)) * float(r.output.amount)))
	return plan


## Les ingrédients optionnels candidats d'une recette (Décision — Affinités de cuisine) : chaque pile du sac
## qui correspond à une entrée optionnelle, incluse ou exclue par le joueur.
static func candidats_optionnels(sim: Simulation, e: Dictionary, r: Dictionary) -> Array:
	var res: Array = []
	var exclus: Array = e.get("exclusions_recette", {}).get(str(r.get("id", "")), [])
	for uid in e.sac:
		var it: Dictionary = sim.items.get(uid, {})
		var ok := false
		for entree in r.get("inputs", []):
			if not bool(entree.get("optionnel", false)):
				continue
			if entree.has("tag") and str(entree.tag) in it.get("tags", []):
				ok = true
			elif entree.has("item") and str(it.get("base", "")) == str(entree.item):
				ok = true
			elif entree.has("material") and it.get("type", "") == "materiau" and str(it.get("materiau", "")) == str(entree.material) and str(it.get("forme", "brut")) == str(entree.get("forme", "brut")):
				ok = true
		if ok:
			res.append({"uid": uid, "inclus": not (uid in exclus)})
	return res


static func basculer_ingredient(sim: Simulation, e: Dictionary, rid: String, uid: String) -> void:
	if not e.has("exclusions_recette"):
		e["exclusions_recette"] = {}
	if not e.exclusions_recette.has(rid):
		e.exclusions_recette[rid] = []
	if uid in e.exclusions_recette[rid]:
		e.exclusions_recette[rid].erase(uid)
	else:
		e.exclusions_recette[rid].append(uid)


## Le vecteur et l'harmonie qu'un plan de plat donnerait (aperçu de l'atelier).
static func harmonie_prevue(sim: Simulation, plan: Dictionary) -> Dictionary:
	var wx := {}
	for entree in plan.entrees:
		var v: Dictionary = entree.pile.get("wuxing", {})
		if v.is_empty() and entree.pile.get("type", "") == "materiau":
			v = sim.regles.r.craft.harmonie.ingredients_materiaux.get(str(entree.pile.get("materiau", "")), GameData.catalogues.materials.get(str(entree.pile.get("materiau", "")), {}).get("wuxing", {}))
		for el in v.keys():
			wx[el] = float(wx.get(el, 0.0)) + float(v[el])
	if wx.is_empty():
		return {}
	wx["feu"] = float(wx.get("feu", 0.0)) + float(sim.regles.r.craft.harmonie.feu_cuisson)
	var total := 0.0
	for el in wx.keys():
		total += float(wx[el])
	var n := 0
	for el in sim.wuxing.w.elements:
		if float(wx.get(el, 0.0)) > 0.0:
			n += 1
		wx[el] = snappedf(float(wx.get(el, 0.0)) / total, 0.01)
	return {"vecteur": wx, "elements": n, "harmonie": n >= sim.wuxing.w.elements.size()}


## Fabriquer : consomme les entrées, produit la sortie ; ticks = ticks_base / skill_factor(N) ;
## XP à la compétence de la station = dureté du matériau produit.
static func _fabriquer(sim: Simulation, e: Dictionary, rid: String, tick: int) -> bool:
	if GameData.catalogues.component_recipes.has(rid):
		return _faconner(sim, e, GameData.catalogues.component_recipes[rid], tick)
	if GameData.catalogues.items.has(rid) and GameData.catalogues.items[rid].has("slots"):
		return _assembler(sim, e, GameData.catalogues.items[rid], tick)
	var r: Dictionary = GameData.catalogues.recipes.get(rid, {})
	if r.is_empty():
		return false
	if bool(r.get("industrielle", false)) and not (rid in e.get("recettes_connues", [])):
		return false
	if not stations_de(sim, e).has(str(r.station)):
		EventBus.emettre(&"journal", [&"journal.pas_de_station", {"recette": r.name_key}])
		return false
	var plan := _plan_recette(sim, e, r)
	if not plan.faisable:
		EventBus.emettre(&"journal", [&"journal.manque", {"recette": r.name_key}])
		return false
	var durete_entrees := 0
	for entree in plan.entrees:
		durete_entrees += int(GameData.catalogues.materials.get(str(entree.pile.get("materiau", "")), {}).get("stats", {}).get("durete", 1))
		SimTerrain._retirer_materiau(sim, e, entree.pile, int(entree.besoin))
	var sortie: Dictionary = plan.sortie
	var n := sim.regles.niveau(e.competences_eff, str(r.craft_skill))
	e.compteur = tick + sim._ticks_avec_statuts(e, maxi(1, ceili(float(sim.regles.r.craft.ticks_base) / sim.regles.skill_factor(n))))
	if not str(sortie.get("item", "")).is_empty():   # un objet fini (meuble, station, plat, potion) : XP = dureté des entrées
		var nom_obj := ""
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.graine, "plat", sim.objets.size(), r.id])
		for k in int(sortie.quantite):
			var inst: Dictionary = SimObjets.generer_objet(sim, str(sortie.item), 1, {}, "commun", 0)
			if not inst.is_empty():
				if inst.get("type", "") == "consommable":   # un plat : qualité A.3 sur Cuisine, empilé
					inst.qualite = snappedf(sim.regles.qualite_craft(sim.regles.niveau(e.competences_eff, str(r.craft_skill)), rng, sim.regles.resserrement_recette(SimTerritoire.niveau_recette(sim, e, str(r.id)))), 0.01)
					if "potion" in inst.get("tags", []) and float(inst.qualite) >= float(sim.regles.r.alchimie.seuil_forte) and sim.statuts_defs.has(str(inst.get("statut", "")) + "_forte"):
						inst.statut = str(inst.statut) + "_forte"   # une potion forte (Cuisine et alchimie)
					var wx := {}   # le vecteur du plat : Σ ingrédients + la cuisson (Décision — Affinités de cuisine)
					for entree in plan.entrees:
						var v: Dictionary = entree.pile.get("wuxing", {})
						if v.is_empty() and entree.pile.get("type", "") == "materiau":   # un matériau en cuisine : son vecteur de cuisine (le sel), sinon celui du matériau
							v = sim.regles.r.craft.harmonie.ingredients_materiaux.get(str(entree.pile.get("materiau", "")), GameData.catalogues.materials.get(str(entree.pile.get("materiau", "")), {}).get("wuxing", {}))
						for el in v.keys():
							wx[el] = float(wx.get(el, 0.0)) + float(v[el])
					if not wx.is_empty():
						var ha: Dictionary = sim.regles.r.craft.harmonie
						wx["feu"] = float(wx.get("feu", 0.0)) + float(ha.feu_cuisson)
						var total := 0.0
						for el in wx.keys():
							total += float(wx[el])
						for el in wx.keys():
							wx[el] = snappedf(float(wx[el]) / total, 0.01)
						inst["wuxing"] = wx
						var cinq := true
						for el in sim.wuxing.w.elements:
							cinq = cinq and float(wx.get(el, 0.0)) > 0.0
						if cinq:
							inst["harmonie"] = float(ha.mult)
					var pot: Dictionary = inst.get("potentiel", {}).duplicate()
					for entree in plan.entrees:   # ingrédients paramétriques : la puissance de la partie, les potentiels des viandes
						if entree.pile.has("puissance") and "potion" in inst.get("tags", []):
							inst["puissance"] = float(entree.pile.puissance)
						for st in entree.pile.get("potentiel", {}).keys():
							pot[st] = int(pot.get(st, 0)) + int(entree.pile.potentiel[st])
					inst.potentiel = pot
					var pile: Dictionary = SimTerrain._pile_objet(sim, e, str(sortie.item))
					if not pile.is_empty():
						pile.quantite = int(pile.quantite) + 1
						sim.items.erase(inst.uid)
						nom_obj = pile.name_key
						continue
				e.sac.append(inst.uid)
				nom_obj = inst.name_key
		sim.gagner_xp(e, str(r.craft_skill), maxi(10, durete_entrees))
		var genre_obj: Dictionary = GameData.catalogues.items.get(str(sortie.item), {})
		var tags_q: Array = ["objet"]
		if genre_obj.get("type", "") == "consommable":
			tags_q = ["plat"] if not ("potion" in genre_obj.get("tags", [])) else ["potion"]
		SimPnj._progresser_quetes(sim, e, "fabriquer", tags_q)
		EventBus.emettre(&"journal", [&"journal.fabrique", {"nom": e.name_key, "quantite": int(sortie.quantite), "objet": nom_obj, "recette": r.name_key}])
		return true
	# L'espèce traverse la recette (point 73). Elle ne pouvait pas : `sortie` est la DÉCLARATION de la
	# recette, qui ne connaît aucune bête — tanner une peau d'ours rendait du cuir anonyme, et tout le
	# travail fait sur la dépouille se perdait au premier atelier. On la reprend donc des ENTRÉES. Si
	# plusieurs bêtes ont contribué, la première déclarée l'emporte : mélanger deux peaux ne fait pas
	# une chimère, et il faut bien trancher.
	var espece_sortie := str(sortie.get("espece", ""))
	if espece_sortie.is_empty():
		for entree in plan.entrees:
			var esp_e := str(entree.pile.get("espece", ""))
			# `espece` porte DEUX choses selon l'objet : l'id d'une CRÉATURE sur la matière tirée d'un
			# corps, et l'id d'une espèce d'ÉLEVAGE sur un spécimen. Seule la première module les stats,
			# et n'hériter que d'elle évite qu'un ver à soie tamponne son élevage sur la soie qu'il file —
			# ce que la suite a attrapé le 2026-09-03, la pile de soie brute s'étant scindée en deux.
			if not esp_e.is_empty() and GameData.catalogues.creatures.has(esp_e):
				espece_sortie = esp_e
				break
	SimTerrain._donner_materiau(sim, e, sortie.materiau, int(sortie.quantite), sortie.forme, espece_sortie)
	var mat: Dictionary = GameData.catalogues.materials.get(str(sortie.materiau), {})
	sim.gagner_xp(e, str(r.craft_skill), int(mat.get("stats", {}).get("durete", 1)))
	SimPnj._progresser_quetes(sim, e, "fabriquer", ["materiau"])
	EventBus.emettre(&"journal", [&"journal.fabrique", {"nom": e.name_key, "quantite": int(sortie.quantite), "objet": mat.get("name_key", sortie.materiau), "recette": r.name_key}])
	return true
