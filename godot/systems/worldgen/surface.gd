class_name Surface
extends RefCounted
## Génération de surface (Génération par couches de bruit, Biomes — schéma, Décision — Altitude sur
## 21 niveaux, décision du 2026-08-27 « terrain plat, reliefs en exception »). Une cellule de 128×128
## du monde, adressée (cx, cy), lue comme une fenêtre sur des champs de bruit continus : aucune couture.
##   - les 8 couches de `data/noise_layers.json` (FastNoiseLite natif, une seed monde + seed_offset),
##     échantillonnées une fois par tuile et normalisées 0..1 ;
##   - le biome d'une tuile = celui dont toutes les `conditions` matchent, à la `priority` la plus haute ;
##   - le sol est plat à la référence (10) ; le relief est une **exception posée** : des accidents
##     (talus, estrade, gorge, piton, cratère — Terrain spectaculaire : « modificateurs 2D paramétriques,
##     jamais des prefabs ») tirés par hash(seed, cellule) selon `planete.relief` ;
##   - le matériau de sol, les arbres, rochers et filons viennent du biome (densités × couche vegetation
##     / ressources) ; les filons suivent les tiers par corruption (Décision — Minerais et strates).
## Déterministe : même seed, même cellule → même résultat. Le camp (coffre, entrée) s'y greffe.

const H_BASE := 10
const PAS_BRUIT := 4     # les couches sont lues tous les 4 tuiles (fréquences ≤ 0,003)

var couches: Dictionary
var biomes: Dictionary
var planete: Dictionary
var bruits: Dictionary = {}   # nom de couche → FastNoiseLite
var graine: int = 0
var plaques: Array = []       # tectonique (Décision — Monde fini) : [{centre: Vector2 (tuiles), continentale: bool, derive}]
var points_chauds: Array = [] # [Vector2] : chapelets d'îles en plein océan
var seuil_mer: float = 0.0    # continentalité au-dessus de laquelle la terre émerge (calibré sur planete.tectonique.terres)
var warp: FastNoiseLite       # domain warping (un seul niveau)
var conti: FastNoiseLite      # bruit basse fréquence de la continentalité
var ridged: FastNoiseLite     # chaînes de montagnes sur les sutures


func _init(p_couches: Dictionary, p_biomes: Dictionary, p_planete: Dictionary, p_graine: int) -> void:
	couches = p_couches
	biomes = p_biomes
	planete = p_planete
	graine = p_graine
	for nom in couches.keys():
		var c: Dictionary = couches[nom]
		var n := FastNoiseLite.new()
		n.seed = graine + int(c.seed_offset)
		n.frequency = float(c.frequency)
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH if str(c.type) == "simplex" else FastNoiseLite.TYPE_PERLIN
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = int(c.octaves)
		bruits[nom] = n
	_tectonique()


## La valeur d'une couche en un point du monde, normalisée 0..1.
func valeur(nom: String, x: int, y: int) -> float:
	var n: FastNoiseLite = bruits[nom]
	return clampf((n.get_noise_2d(float(x), float(y)) + 1.0) * 0.5, 0.0, 1.0)


## Les 8 couches en un point ; `altitude` et `sismique` sont dérivées de la tectonique, pas tirées.
func couches_a(x: int, y: int) -> Dictionary:
	var v := {}
	for nom in bruits.keys():
		v[nom] = valeur(nom, x, y)
	var t := tectonique_a(x, y)
	v["altitude"] = t.altitude
	v["sismique"] = t.sismique
	return v


## Les royaumes PNJ d'un secteur (Génération des royaumes PNJ) : déterministes, lecture pure des bruits.
var royaumes_cache: Dictionary = {}   # Vector2i (secteur) → {id: royaume}
var royaume_par_cellule: Dictionary = {}   # Vector2i (cellule) → id
var routes_par_cellule: Dictionary = {}    # Vector2i (cellule) → Array[Vector2i] : les cellules voisines reliées par une route


func secteur_de(c: Vector2i) -> Vector2i:
	var s: int = int(GameData.config("combat_rules").royaume.pnj.secteur)
	return Vector2i(floori(float(c.x) / float(s)), floori(float(c.y) / float(s)))


func royaume_de(c: Vector2i) -> Dictionary:
	var sect := secteur_de(c)
	if not royaumes_cache.has(sect):
		royaumes_secteur(sect)
	var id: String = str(royaume_par_cellule.get(c, ""))
	return royaumes_cache[sect].get(id, {}) if not id.is_empty() else {}


var mutex_roy := Mutex.new()   # les threads de pré-génération lisent les royaumes


func royaumes_secteur(sect: Vector2i) -> Dictionary:
	mutex_roy.lock()
	var res0: Dictionary = _royaumes_secteur_calc(sect)
	mutex_roy.unlock()
	return res0


func _royaumes_secteur_calc(sect: Vector2i) -> Dictionary:
	if royaumes_cache.has(sect):
		return royaumes_cache[sect]
	var cfg: Dictionary = GameData.config("combat_rules").royaume.pnj
	var s: int = int(cfg.secteur)
	var taille: int = int(planete.taille_cellule)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, sect.x, sect.y, "royaumes"])
	var res: Dictionary = {}
	royaumes_cache[sect] = res
	# Les cellules-villages du secteur, triées par danger croissant.
	var villages: Array = []
	for y in s:
		for x in s:
			var c := Vector2i(sect.x * s + x, sect.y * s + y)
			if terre_a(c) and bool(poi_de(c).get("village", false)):
				villages.append({"c": c, "danger": valeur("danger", c.x * taille + taille / 2, c.y * taille + taille / 2)})
	if villages.is_empty():
		return res
	villages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.danger) < float(b.danger))
	var n := rng.randi_range(0, int(cfg.capitales_max))
	var gouvs: Dictionary = GameData.catalogues.governments
	var cultures: Dictionary = GameData.catalogues.name_cultures
	var pool: Dictionary = GameData.config("absurd_laws_pool")
	var ordre: Array = []
	for k in mini(n, villages.size()):
		var cap: Vector2i = villages[k].c
		var id := "royaume_%d_%d_%d" % [sect.x, sect.y, k]
		# Taille.
		var tirage := rng.randf()
		var cumul := 0.0
		var taille_id := "hameau"
		var cellules_max := 1
		for t in cfg.tailles:
			cumul += float(t[2])
			if tirage <= cumul:
				taille_id = str(t[0])
				cellules_max = int(t[1])
				break
		# Identité : race par le biome de la capitale, culture par affinité, gouvernance pondérée.
		var b: Dictionary = biomes.get(biome_a(cap.x * taille + taille / 2, cap.y * taille + taille / 2), {})
		var race := str(b.get("race_dominante", "humain"))
		var culture := Noms.culture_pour(race, cultures, rng)
		var gouv := _tirer_pondere(cfg.gouvernances, rng)
		var g: Dictionary = gouvs.get(gouv, {})
		var lois: Array = []
		if not bool(g.get("meurtre_legal", false)):
			lois.append({"id": "loi_meurtre", "type": "comportement", "target": "meurtre", "status": "illegal", "consequence": "gardes_hostiles"})
			lois.append({"id": "loi_vol", "type": "comportement", "target": "vol", "status": "illegal", "consequence": "amende:50"})
		if not bool(g.get("meurtre_legal", false)):   # Lois et infractions : les substances illégales le sont partout où l'on juge (Potions)
			for sub in pool.get("substances_illegales", []):
				if rng.randf() < float(pool.get("substances_chance", 0.8)):
					lois.append({"id": "loi_" + str(sub), "type": "objet", "target": str(sub), "status": "illegal", "consequence": "confiscation"})
		if rng.randf() < float(pool.chance):
			for a in rng.randi_range(1, int(pool.max)):
				var obj: String = str(pool.objets[rng.randi() % pool.objets.size()])
				lois.append({"id": "loi_" + obj, "type": "objet", "target": obj, "status": "illegal", "consequence": str(pool.consequences[rng.randi() % pool.consequences.size()])})
		var tarifs: Dictionary = {}
		for k2 in rng.randi_range(1, 2):
			var cat: String = str(cfg.tarif_categories[rng.randi() % cfg.tarif_categories.size()])
			tarifs[cat] = snappedf(rng.randf_range(float(cfg.tarif_bornes[0]), float(cfg.tarif_bornes[1])), 0.05)
		var nom := Noms.ville(cultures.get(culture, {}), rng) if cultures.has(culture) else "Royaume"
		var r := {"id": id, "nom": nom, "government_type": gouv, "culture": culture, "race": race, "taille": taille_id, "capital_poi": cap, "territory_cells": [cap],
			"taxes": {"base_rate": float(g.get("base_rate", 0.08)), "tariff_default": 0.1}, "tariffs": tarifs, "laws": lois, "diplomacy": {}, "rivals": [], "tags": []}
		res[id] = r
		royaume_par_cellule[cap] = id
		ordre.append(id)
	# Croissance par coût : Dijkstra borné depuis la capitale, dans le secteur, jamais l'eau ni un autre royaume.
	for id in ordre:
		var r: Dictionary = res[id]
		var cap: Vector2i = r.capital_poi
		var cellules_max := 1
		for t in cfg.tailles:
			if str(t[0]) == str(r.taille):
				cellules_max = int(t[1])
		var couts: Dictionary = {cap: 0.0}
		var ouverts: Array = [cap]
		while r.territory_cells.size() < cellules_max and not ouverts.is_empty():
			var meilleur_i := 0
			for i in ouverts.size():
				if float(couts[ouverts[i]]) < float(couts[ouverts[meilleur_i]]):
					meilleur_i = i
			var c: Vector2i = ouverts[meilleur_i]
			ouverts.remove_at(meilleur_i)
			if c != cap:
				if royaume_par_cellule.has(c):
					continue
				r.territory_cells.append(c)
				royaume_par_cellule[c] = id
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var v: Vector2i = c + d
				if secteur_de(v) != sect or couts.has(v) or not terre_a(v) or royaume_par_cellule.has(v):
					continue
				var cout := 1.0 + float(cfg.cout_danger) * valeur("danger", v.x * taille + taille / 2, v.y * taille + taille / 2) + float(cfg.cout_altitude) * maxf(0.0, valeur("altitude", v.x * taille + taille / 2, v.y * taille + taille / 2) - 0.5)
				couts[v] = float(couts[c]) + cout
				ouverts.append(v)
	# Les routes : chaque village du territoire rejoint la capitale par le plus court chemin à coût (Unification macro-micro).
	for id in ordre:
		var r: Dictionary = res[id]
		var cap: Vector2i = r.capital_poi
		var dans_t: Dictionary = {}
		for c in r.territory_cells:
			dans_t[c] = true
		var couts: Dictionary = {cap: 0.0}
		var pred: Dictionary = {}
		var ouverts: Array = [cap]
		while not ouverts.is_empty():
			var mi := 0
			for i in ouverts.size():
				if float(couts[ouverts[i]]) < float(couts[ouverts[mi]]):
					mi = i
			var c: Vector2i = ouverts[mi]
			ouverts.remove_at(mi)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var v: Vector2i = c + d
				if not dans_t.has(v):
					continue
				var cout := 1.0 + float(cfg.cout_danger) * valeur("danger", v.x * taille + taille / 2, v.y * taille + taille / 2) + float(cfg.cout_altitude) * maxf(0.0, valeur("altitude", v.x * taille + taille / 2, v.y * taille + taille / 2) - 0.5)
				if not couts.has(v) or float(couts[c]) + cout < float(couts[v]):
					couts[v] = float(couts[c]) + cout
					pred[v] = c
					ouverts.append(v)
		r["routes"] = []
		for c in r.territory_cells:
			if c == cap or not bool(poi_de(c).get("village", false)):
				continue
			var q: Vector2i = c
			while pred.has(q):
				var p0: Vector2i = pred[q]
				_relier(q, p0)
				if not (q in r.routes):
					r.routes.append(q)
				q = p0
			if not (cap in r.routes):
				r.routes.append(cap)
	# Les routes commerciales entre royaumes voisins non hostiles (Unification macro-micro) : capitale à capitale,
	# par les deux territoires seulement — une route est un lien de confiance, elle ne traverse pas un tiers.
	for i in ordre.size():
		for j in range(i + 1, ordre.size()):
			var ra: Dictionary = res[ordre[i]]
			var rb: Dictionary = res[ordre[j]]
			if str(ra.diplomacy.get(rb.id, "")) == "hostile" or str(rb.diplomacy.get(ra.id, "")) == "hostile":
				continue
			var voisins := false
			var passables: Dictionary = {}
			for c in ra.territory_cells:
				passables[c] = true
			for c in rb.territory_cells:
				passables[c] = true
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if (c + d) in ra.territory_cells:
						voisins = true
			if not voisins:
				continue
			_route_entre(ra.capital_poi, rb.capital_poi, passables, cfg)
	# Diplomatie initiale entre royaumes du secteur : compatibilité de gouvernance et de race.
	for i in ordre.size():
		for j in ordre.size():
			if i == j:
				continue
			var a: Dictionary = res[ordre[i]]
			var b2: Dictionary = res[ordre[j]]
			var score := 0.0
			score += 0.3 if a.race == b2.race else -0.2
			score += 0.2 if a.government_type == b2.government_type else 0.0
			if a.government_type == "dictature_militaire" and b2.government_type == "dictature_militaire":
				score -= 0.6
			if a.government_type == "anarchie" or b2.government_type == "anarchie":
				score -= 0.3
			score += rng.randf_range(-0.3, 0.3)
			a.diplomacy[b2.id] = "hostile" if score < -0.3 else ("tension" if score < 0.0 else ("cordial" if score < 0.4 else "allie"))
	return res


## Une route entre deux points, par le plus court chemin à coût dans un ensemble de cellules autorisées.
func _route_entre(depart: Vector2i, arrivee: Vector2i, passables: Dictionary, cfg: Dictionary) -> void:
	var taille: int = int(planete.taille_cellule)
	var couts: Dictionary = {depart: 0.0}
	var pred: Dictionary = {}
	var ouverts: Array = [depart]
	while not ouverts.is_empty():
		var mi := 0
		for i in ouverts.size():
			if float(couts[ouverts[i]]) < float(couts[ouverts[mi]]):
				mi = i
		var c: Vector2i = ouverts[mi]
		ouverts.remove_at(mi)
		if c == arrivee:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + d
			if not passables.has(v) or not terre_a(v):
				continue
			var cout := 1.0 + float(cfg.cout_danger) * valeur("danger", v.x * taille + taille / 2, v.y * taille + taille / 2) + float(cfg.cout_altitude) * maxf(0.0, valeur("altitude", v.x * taille + taille / 2, v.y * taille + taille / 2) - 0.5)
			if not couts.has(v) or float(couts[c]) + cout < float(couts[v]):
				couts[v] = float(couts[c]) + cout
				pred[v] = c
				ouverts.append(v)
	if not pred.has(arrivee):
		return   # aucun chemin par les deux territoires : pas de route
	var q: Vector2i = arrivee
	while pred.has(q):
		_relier(q, pred[q])
		q = pred[q]


func _relier(a: Vector2i, b: Vector2i) -> void:
	for paire in [[a, b], [b, a]]:
		if not routes_par_cellule.has(paire[0]):
			routes_par_cellule[paire[0]] = []
		if not (paire[1] in routes_par_cellule[paire[0]]):
			routes_par_cellule[paire[0]].append(paire[1])


## Les cellules voisines reliées à celle-ci par une route (vide si aucune).
func route_de(c: Vector2i) -> Array:
	royaumes_secteur(secteur_de(c))
	return routes_par_cellule.get(c, [])


## Le chemin de sol d'une route dans la cellule : de la place (ou du centre) vers le milieu du bord de chaque voisine reliée.
func _poser_route(e: Dictionary, cell: Vector2i) -> void:
	var voisines: Array = route_de(cell)
	if voisines.is_empty():
		return
	var taille: int = e.largeur
	var b: Dictionary = biomes.get(e.biome, {})
	var sol := str(b.get("village_palette", {}).get("sol", "calcaire"))
	var depart: Vector2i = Vector2i(e.village.centre) if not e.village.is_empty() and e.village.has("centre") else Vector2i(taille / 2, taille / 2)
	e["route"] = {}
	for v in voisines:
		var d: Vector2i = v - cell
		var arrivee := Vector2i(taille / 2 + d.x * (taille / 2), taille / 2 + d.y * (taille / 2))
		arrivee = Vector2i(clampi(arrivee.x, 0, taille - 1), clampi(arrivee.y, 0, taille - 1))
		var q := depart
		var garde := 0
		while q != arrivee and garde < taille * 3:
			garde += 1
			q += Vector2i(signi(arrivee.x - q.x), 0) if absi(arrivee.x - q.x) > absi(arrivee.y - q.y) else Vector2i(0, signi(arrivee.y - q.y))
			for dx in range(-1, 1):   # deux tuiles de large
				var t := q + Vector2i(dx, 0) if d.y != 0 else q + Vector2i(0, dx)
				var i := t.y * taille + t.x
				if _dans(t, taille) and not e.eau.has(i) and not e.murs.has(i):
					e.sols[i] = sol
					_degager(e, i)
					e.route[i] = true


func _tirer_pondere(poids: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	var ids: Array = poids.keys()
	ids.sort()
	for k in ids:
		total += float(poids[k])
	var t := rng.randf() * total
	for k in ids:
		t -= float(poids[k])
		if t <= 0.0:
			return str(k)
	return str(ids[0])


## Les POI d'une cellule (Unification macro-micro) : hash(seed, cx, cy), densités de la planète × poids du biome.
func poi_de(c: Vector2i, camp: bool = false) -> Dictionary:
	var res := {"donjon": camp, "filon_majeur": false}
	if not terre_a(c):
		return res
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, c.x, c.y, "poi"])
	var taille: int = int(planete.taille_cellule)
	var b: Dictionary = biomes.get(biome_a(c.x * taille + taille / 2, c.y * taille + taille / 2), {})
	var poids: Dictionary = b.get("poi_weights", {})
	var dens: Dictionary = planete.get("poi", {})
	if not camp:
		res.donjon = rng.randf() < float(dens.get("donjon", 0.06)) * float(poids.get("donjon", 1))
	res.filon_majeur = rng.randf() < float(dens.get("filon_majeur", 0.06)) * float(poids.get("filon_majeur", 1))
	res["village"] = (not camp) and rng.randf() < float(dens.get("village", 0.04)) * float(poids.get("village", 1))
	return res


## Le niveau de danger d'une cellule : 0 paisible, 1 dangereuse, 2 mortelle (couche danger au centre).
func danger_de(c: Vector2i) -> int:
	var taille: int = int(planete.taille_cellule)
	var d := valeur("danger", c.x * taille + taille / 2, c.y * taille + taille / 2)
	var seuils: Array = planete.get("danger", {}).get("seuils", [0.45, 0.75])
	return 2 if d >= float(seuils[1]) else (1 if d >= float(seuils[0]) else 0)


## Le résumé d'une cellule pour la carte du monde : biome au centre, terre, danger, POI, couleur.
func resume_cellule(c: Vector2i, camp: bool = false) -> Dictionary:
	var taille: int = int(planete.taille_cellule)
	var b := biome_a(c.x * taille + taille / 2, c.y * taille + taille / 2)
	var terre := terre_a(c)
	return {"biome": b, "terre": terre, "danger": danger_de(c), "poi": poi_de(c, camp), "couleur": str(biomes.get(b, {}).get("couleur", "#7fa64a"))}


## La cellule est-elle de la terre ferme (son centre et ses quatre quarts au-dessus du niveau de la mer) ?
func terre_a(c: Vector2i) -> bool:
	var taille: int = int(planete.taille_cellule)
	var seuil := float(planete.get("mer", {}).get("altitude", 0.30))
	var q := taille / 4   # cinq sondes DANS la cellule (centre + quatre quarts) — des offsets figés sur 128 tombaient dans la cellule voisine depuis les cellules de 64 (2026-08-30)
	for off in [Vector2i(2 * q, 2 * q), Vector2i(q, q), Vector2i(3 * q, q), Vector2i(q, 3 * q), Vector2i(3 * q, 3 * q)]:
		if float(tectonique_a(c.x * taille + off.x, c.y * taille + off.y).altitude) < seuil:
			return false
	return true


# ---------------------------------------------------------------- tectonique (Décision — Monde fini, continents et océan)

## Les plaques (Voronoï de germes), 40 % continentales, forcées océaniques près du bord ; les points chauds ;
## le seuil de mer calibré pour la part de terres émergées demandée.
func _tectonique() -> void:
	var tc: Dictionary = planete.get("tectonique", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "tectonique"])
	var monde_tuiles := float(int(planete.monde_cellules) * int(planete.taille_cellule))
	var bord := float(int(tc.get("bord_secteurs", 2)) * 64 * int(planete.taille_cellule))
	plaques.clear()
	for k in int(tc.get("plaques", 24)):
		var c := Vector2(rng.randf() * monde_tuiles, rng.randf() * monde_tuiles)
		var pres_du_bord := c.x < bord or c.y < bord or c.x > monde_tuiles - bord or c.y > monde_tuiles - bord
		plaques.append({"centre": c, "continentale": (rng.randf() < float(tc.get("continentales", 0.4))) and not pres_du_bord,
			"derive": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 1.0)})
	points_chauds.clear()
	var pc: Array = tc.get("points_chauds", [8, 14])
	for k in rng.randi_range(int(pc[0]), int(pc[1])):
		points_chauds.append(Vector2(rng.randf() * monde_tuiles, rng.randf() * monde_tuiles))
	warp = FastNoiseLite.new()
	warp.seed = graine + 101
	warp.frequency = float(tc.get("warp_frequence", 0.00025))
	warp.fractal_octaves = 2
	conti = FastNoiseLite.new()
	conti.seed = graine + 102
	conti.frequency = float(tc.get("continentalite_frequence", 0.00012))
	conti.fractal_octaves = 3
	ridged = FastNoiseLite.new()
	ridged.seed = graine + 103
	ridged.frequency = float(tc.get("ridged_frequence", 0.0015))
	ridged.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridged.fractal_octaves = 3
	# Calibrage du seuil : le quantile de la continentalité sur une grille d'échantillons.
	var n: int = int(tc.get("calibrage_echantillons", 48))
	var valeurs: Array[float] = []
	for j in n:
		for i in n:
			valeurs.append(_continentalite(Vector2((i + 0.5) / n * monde_tuiles, (j + 0.5) / n * monde_tuiles)))
	valeurs.sort()
	var part_terres: float = float(tc.get("terres", 0.35))
	seuil_mer = valeurs[clampi(int(float(valeurs.size()) * (1.0 - part_terres)), 0, valeurs.size() - 1)]


func _warpe(p: Vector2) -> Vector2:
	var amp := float(planete.get("tectonique", {}).get("warp_amplitude", 6000.0))
	return p + Vector2(warp.get_noise_2d(p.x, p.y), warp.get_noise_2d(p.x + 7919.0, p.y - 1013.0)) * amp


## Les deux plaques les plus proches d'un point warpé : [i1, d1, i2, d2].
func _plaques_proches(q: Vector2) -> Array:
	var d1 := INF
	var d2 := INF
	var i1 := -1
	var i2 := -1
	for k in plaques.size():
		var d: float = q.distance_to(plaques[k].centre)
		if d < d1:
			d2 = d1
			i2 = i1
			d1 = d
			i1 = k
		elif d < d2:
			d2 = d
			i2 = k
	return [i1, d1, i2, d2]


## Continentalité en un point (tuiles) : base ±1 de la plaque, bordure adoucie, warp obligatoire, bruit lent, points chauds.
func _continentalite(p: Vector2) -> float:
	var q := _warpe(p)
	var pp := _plaques_proches(q)
	var base: float = 1.0 if plaques[pp[0]].continentale else -1.0
	var bordure: float = clampf((float(pp[3]) - float(pp[1])) / float(planete.get("tectonique", {}).get("bordure_tuiles", 20000.0)), 0.0, 1.0)
	var c := base * (0.35 + 0.65 * bordure) + conti.get_noise_2d(q.x, q.y) * 0.6
	var r := float(planete.get("tectonique", {}).get("point_chaud_rayon", 9000.0))
	for pc in points_chauds:
		var dp: float = q.distance_to(pc)
		if dp < r:
			c += (1.0 - dp / r) * 1.4
	return c


## Altitude 0..1 (classes macro : mer < 0,30 · littoral 0,30-0,38 · plaine · colline · montagne) et
## sismicité 0..1 (proximité d'une suture), déterministes.
func tectonique_a(x: int, y: int) -> Dictionary:
	var p := Vector2(float(x), float(y))
	var c := _continentalite(p)
	var q := _warpe(p)
	var pp := _plaques_proches(q)
	var i1: int = pp[0]
	var i2: int = pp[2]
	var suture := 1.0 - clampf((float(pp[3]) - float(pp[1])) / float(planete.get("tectonique", {}).get("suture_tuiles", 6000.0)), 0.0, 1.0)
	var alt: float
	if c < seuil_mer:
		alt = clampf(0.30 * (1.0 - (seuil_mer - c) / 1.5), 0.0, 0.30)   # mer : 0 au large, 0,30 au rivage
	else:
		var terre := clampf((c - seuil_mer) / 1.2, 0.0, 1.0)             # 0 au rivage, 1 au cœur
		alt = 0.30 + 0.25 * terre                                        # littoral → plaine
		if i1 >= 0 and i2 >= 0 and plaques[i1].continentale and plaques[i2].continentale:
			alt += suture * ((ridged.get_noise_2d(q.x, q.y) + 1.0) * 0.5) * 0.45   # chaîne de montagnes sur la suture
		elif i1 >= 0 and i2 >= 0 and plaques[i1].continentale != plaques[i2].continentale:
			alt += suture * ((ridged.get_noise_2d(q.x, q.y) + 1.0) * 0.5) * 0.2    # cordillère côtière
	return {"altitude": clampf(alt, 0.0, 1.0), "sismique": suture, "continentalite": c}


## Le biome d'un point : toutes les conditions satisfaites, priorité la plus haute (Biomes — schéma).
func biome_a(x: int, y: int) -> String:
	return _biome_de(couches_a(x, y))


func _biome_de(v: Dictionary) -> String:
	var meilleur := ""
	var prio := -1
	for id in biomes.keys():
		var b: Dictionary = biomes[id]
		var ok := true
		for couche in b.conditions.keys():
			var f: Array = b.conditions[couche]
			var val: float = float(v.get(couche, 0.5))
			if val < float(f[0]) or val > float(f[1]):
				ok = false
				break
		if ok and int(b.priority) > prio:
			prio = int(b.priority)
			meilleur = id
	return meilleur


## Génère la cellule (cx, cy) : {largeur, hauteur, hauteurs, sol, bord, sols, arbres, rochers, filons,
## biome, biomes_vus, entree, ...}. `camp` : la configuration du camp à y greffer (coffre, entrée).
func generer_cellule(cx: int, cy: int, camp: Dictionary = {}, bord: bool = true) -> Dictionary:
	var taille: int = int(planete.taille_cellule)
	var rng := RandomNumberGenerator.new()   # local : la génération peut tourner en thread (Monde)
	rng.seed = hash([graine, cx, cy, "cellule"])
	var e := {"largeur": taille, "hauteur": taille, "hauteurs": PackedByteArray(), "sol": {}, "bord": {}, "sols": {}, "filons": {},
		"arbres": {}, "rochers": {}, "plantes": {}, "cueillette": {}, "eau": {}, "cellule": Vector2i(cx, cy), "biome": "", "biomes_vus": {}, "accidents": [],
		"entree": Vector2i(taille / 2, taille / 2), "entree_donjon": Vector2i(taille / 2 + 10, taille / 2), "coffre_depart": Vector2i(taille / 2 - 2, taille / 2),
		"pieces": [], "spawns": [], "coffres": [], "escalier": null, "boss": null, "etage": 0}
	e.hauteurs.resize(taille * taille)
	e.hauteurs.fill(H_BASE)
	var ox := cx * taille
	var oy := cy * taille
	e.biome = biome_a(ox + taille / 2, oy + taille / 2)
	# 1. Sol, biome et matériau par tuile. Les couches sont échantillonnées par bloc de PAS_BRUIT tuiles
	#    (fréquences ≤ 0,003 : rien ne varie à l'échelle de la tuile) — 16 fois moins d'appels au bruit.
	var par_bloc: Dictionary = {}   # la clé de bloc se recalcule (x / PAS_BRUIT) : pas de table de 16 384 entrées
	var mer_alt := float(planete.get("mer", {}).get("altitude", 0.30))   # hors boucle : 16 384 tuiles
	var mer_h := int(planete.get("mer", {}).get("hauteur", 8))
	for y in taille:
		for x in taille:
			var i := y * taille + x
			if bord and (x == 0 or y == 0 or x == taille - 1 or y == taille - 1):
				e.bord[i] = true
				continue
			e.sol[i] = true
			var cle := Vector2i(x / PAS_BRUIT, y / PAS_BRUIT)
			if not par_bloc.has(cle):
				var v := couches_a(ox + cle.x * PAS_BRUIT + PAS_BRUIT / 2, oy + cle.y * PAS_BRUIT + PAS_BRUIT / 2)
				var b0 := _biome_de(v)
				par_bloc[cle] = {"couches": v, "biome": b0, "sol": str(biomes.get(b0, {}).get("surface_material", "terre")),
					"mer": float(v.get("altitude", 1.0)) < mer_alt}
				e.biomes_vus[b0] = true
			var bl: Dictionary = par_bloc[cle]
			e.sols[i] = bl.sol
			if bool(bl.mer):
				e.eau[i] = true   # la mer (Eau et liquides : une source, niveau 8/8)
				e.hauteurs[i] = mer_h
	# 2. Le relief : des accidents posés, hors de la zone d'arrivée si un camp s'y greffe.
	var reserve := Rect2i(e.entree - Vector2i(8, 8), Vector2i(24, 16)) if not camp.is_empty() else Rect2i(-1, -1, 0, 0)
	_poser_accidents(e, reserve, rng)
	# 3. Arbres, rochers, filons selon le biome de chaque tuile et les couches vegetation / ressources.
	var mp: Dictionary = GameData.config("minerais_par_etage")
	var seuils: Array = planete.tiers_corruption
	for i in e.sol.keys():
		var x: int = i % taille
		var y: int = i / taille
		if reserve.has_point(Vector2i(x, y)) or e.eau.has(i):
			continue
		var bloc: Dictionary = par_bloc[Vector2i(x / PAS_BRUIT, y / PAS_BRUIT)]
		var b: Dictionary = biomes.get(str(bloc.biome), {})
		var veg: float = float(bloc.couches.vegetation)
		var res: float = float(bloc.couches.ressources)
		var tire := rng.randf()
		var pose := false
		var seuil := 0.0   # seuils cumulés : chaque entrée garde sa densité propre (sinon une densité plus faible qu'une précédente ne sort jamais)
		for v in b.get("vegetation", []):
			seuil += float(v.density) * veg * 2.0
			if tire < seuil:
				e.arbres[i] = str(v.id)
				pose = true
				break
		if pose:
			continue
		for pl in b.get("plantes", []):
			seuil += float(pl.density) * veg * 2.0
			if tire < seuil:
				e.plantes[i] = str(pl.id)
				pose = true
				break
		if pose:
			continue
		for cu in b.get("cueillette", []):   # Plantes : la cueillette sauvage par biome
			seuil += float(cu.density) * veg * 2.0
			if tire < seuil:
				e.cueillette[i] = str(cu.id)
				pose = true
				break
		if pose:
			continue
		for r in b.get("rochers", []):
			if tire < float(r.density) * (1.0 - res):
				e.rochers[i] = str(r.id)
				pose = true
				break
		if pose:
			continue
		if res > float(planete.filons.seuil) and tire < float(planete.filons.densite) * float(b.get("filons_mult", 1.0)):
			var danger: float = float(bloc.couches.danger) * 100.0
			var tier := 1
			for k in range(1, seuils.size()):
				if danger >= float(seuils[k]) or (k == 1 and "montagne" in b.get("tags", [])):
					tier = k + 1
			var pool: Array = []
			for t in range(1, tier + 1):
				pool.append_array(mp.tiers[str(t)])
			e.filons[i] = str(pool[rng.randi_range(0, pool.size() - 1)])
	# 4. Les POI : l'entrée scellée d'un donjon (anneau de roche ouvert au sud), un filon majeur.
	var poi := poi_de(Vector2i(cx, cy), not camp.is_empty())
	e["poi"] = poi
	e["a_donjon"] = bool(poi.donjon)
	if bool(poi.donjon):
		var pe: Vector2i = e.entree_donjon if not camp.is_empty() else Vector2i(taille / 2 + rng.randi_range(-30, 30), taille / 2 + rng.randi_range(-30, 30))
		var essais := 0
		while essais < 40 and (e.eau.has(pe.y * taille + pe.x) or reserve.has_point(pe)):
			essais += 1
			pe = Vector2i(rng.randi_range(8, taille - 9), rng.randi_range(8, taille - 9))
		e.entree_donjon = pe
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q := pe + Vector2i(dx, dy)
				var qi := q.y * taille + q.x
				if (dx == 0 and dy == 0) or (dx == 0 and dy == 1) or not _dans(q, taille):
					continue
				e.rochers[qi] = "pierre"
				e.arbres.erase(qi)
				e.plantes.erase(qi)
				e.cueillette.erase(qi)
				e.filons.erase(qi)
	if bool(poi.filon_majeur):
		var fm: Array = planete.get("poi", {}).get("filon_majeur_taille", [20, 40])
		var danger := valeur("danger", ox + taille / 2, oy + taille / 2) * 100.0
		var tier := 1
		for k in range(1, seuils.size()):
			if danger >= float(seuils[k]):
				tier = k + 1
		var pool: Array = mp.tiers[str(tier)]
		var mat: String = str(pool[rng.randi_range(0, pool.size() - 1)])
		var pf := Vector2i(rng.randi_range(10, taille - 11), rng.randi_range(10, taille - 11))
		var reste := rng.randi_range(int(fm[0]), int(fm[1]))
		for pas in reste * 4:
			var fi := pf.y * taille + pf.x
			if e.sol.has(fi) and not e.eau.has(fi) and not reserve.has_point(pf) and not e.filons.has(fi):
				e.filons[fi] = mat
				e.arbres.erase(fi)
				e.plantes.erase(fi)
				e.cueillette.erase(fi)
				reste -= 1
				if reste <= 0:
					break
			pf += [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi_range(0, 3)]
			if not _dans(pf, taille):
				break
	e["murs"] = {}
	e["portes"] = {}
	e["meubles"] = {}
	e["village"] = {}
	if bool(poi.get("village", false)):
		_poser_village(e, Vector2i(cx, cy), rng)
	_poser_route(e, Vector2i(cx, cy))
	for d in [e.arbres, e.rochers, e.filons, e.eau]:
		for i in d.keys():
			e.sol.erase(i)
	return e   # les plantes restent du sol (franchissables) : la simulation les pose comme contenu


## Un hameau (Villages PNJ) : une place, 3 à 5 bâtiments préfab autour, des chemins, la palette du biome.
func _poser_village(e: Dictionary, cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var vc: Dictionary = planete.get("village", {})
	var taille: int = e.largeur
	var bats: Dictionary = GameData.catalogues.village_buildings
	var b: Dictionary = biomes.get(e.biome, {})
	var palette: Dictionary = b.get("village_palette", {"mur": "chene", "toit": "chaume_tresse", "sol": "calcaire"})
	# Le centre du village : au milieu de la cellule, à ± un cinquième — en unités de la cellule, pas en tuiles
	# fixes (les ± 25 tuiles d'avant sortaient une capitale d'une cellule de 64 : bâtiments perdus).
	var jeu: int = maxi(4, taille / 5)
	var centre := Vector2i(taille / 2 + rng.randi_range(-jeu, jeu), taille / 2 + rng.randi_range(-jeu, jeu))
	var rayon: int = int(vc.get("rayon_place", 6))
	if e.has("a_donjon") and bool(e.a_donjon) and Vector2i(e.entree_donjon).distance_to(centre) < taille / 6:
		centre = Vector2i(e.entree_donjon) + Vector2i(taille / 4, 0)
	centre = Vector2i(clampi(centre.x, taille / 4, taille * 3 / 4), clampi(centre.y, taille / 4, taille * 3 / 4))
	# La culture et le nom du village : la race dominante (humain) tire parmi ses cultures.
	var cultures: Dictionary = GameData.catalogues.name_cultures
	var culture_id := Noms.culture_pour("humain", cultures, rng)
	var roy := royaume_de(cell)
	if not roy.is_empty() and cultures.has(str(roy.culture)):
		culture_id = str(roy.culture)
	var nom_village := Noms.ville(cultures.get(culture_id, {}), rng) if not culture_id.is_empty() else "Hameau"
	e.village = {"nom": nom_village, "culture": culture_id, "centre": centre, "batiments": [], "pnj": [], "royaume": str(roy.get("id", ""))}
	# La place : sol de la palette, dégagée.
	for dy in range(-rayon, rayon + 1):
		for dx in range(-rayon, rayon + 1):
			var p := centre + Vector2i(dx, dy)
			var i := p.y * taille + p.x
			if _dans(p, taille) and not e.eau.has(i):
				e.sols[i] = str(palette.sol)
				e.hauteurs[i] = H_BASE
				_degager(e, i)
	# Les bâtiments autour de la place, dans les 8 directions, sans chevauchement.
	var ids: Array = []
	for bid0 in bats.keys():
		if not ("ville" in bats[bid0].get("tags", [])):
			ids.append(bid0)
	ids.sort()
	# La taille de l'agglomération : celle du royaume pour sa capitale, un hameau sinon (Génération des royaumes PNJ).
	var villes: Dictionary = GameData.config("combat_rules").royaume.villes
	var taille_ville := "hameau"
	if not roy.is_empty() and roy.capital_poi == cell and villes.has(str(roy.taille)):
		taille_ville = str(roy.taille)
	var tv: Dictionary = villes[taille_ville]
	e.village["taille"] = taille_ville
	var nb := rng.randi_range(int(tv.batiments[0]), int(tv.batiments[1]))
	var nb_boutiques := rng.randi_range(int(tv.boutiques[0]), int(tv.boutiques[1]))
	var nb_halls := rng.randi_range(int(tv.halls[0]), int(tv.halls[1]))
	var types_boutiques: Array = GameData.catalogues.shop_types.keys()
	types_boutiques.sort()
	var guildes: Array = GameData.catalogues.guilds.keys()
	guildes.sort()
	var plan_bats: Array = []   # [bid, boutique, guilde] — sans doublon de type par ville
	for k in nb_boutiques:
		if types_boutiques.is_empty():
			break
		var t: String = str(types_boutiques[rng.randi() % types_boutiques.size()])
		types_boutiques.erase(t)
		plan_bats.append(["echoppe", t, ""])
	for k in nb_halls:
		if guildes.is_empty():
			break
		var g: String = str(guildes[rng.randi() % guildes.size()])
		guildes.erase(g)
		plan_bats.append(["hall", "", g])
	if plan_bats.is_empty():
		plan_bats.append(["echoppe", "", ""])
	while plan_bats.size() < nb:
		plan_bats.append([str(ids[rng.randi_range(0, ids.size() - 1)]), "", ""])
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1)]
	var pris: Array[Rect2i] = []
	for k in plan_bats.size():
		var bid: String = str(plan_bats[k][0])
		var plan: Array = bats[bid].plan
		var w: int = str(plan[0]).length()
		var h: int = plan.size()
		var d: Vector2i = dirs[k % dirs.size()]
		var anneau: int = rayon + 3 + 9 * (k / dirs.size())   # au-delà de huit bâtiments, un second anneau
		var origine := centre + d * anneau - Vector2i(w / 2, h / 2) + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		var r := Rect2i(origine, Vector2i(w, h))
		if origine.x < 2 or origine.y < 2 or r.end.x >= taille - 2 or r.end.y >= taille - 2:
			continue
		var libre := true
		for pr in pris:
			if pr.grow(1).intersects(r):
				libre = false
		var mouille := false
		for y in h:
			for x in w:
				if e.eau.has((origine.y + y) * taille + origine.x + x):
					mouille = true
		if not libre or mouille:
			continue
		pris.append(r)
		_poser_batiment(e, bats[bid], origine, palette, bid)
		e.village.batiments.back()["boutique"] = str(plan_bats[k][1])
		e.village.batiments.back()["guilde"] = str(plan_bats[k][2])
		# Le chemin du bâtiment à la place.
		var porte: Vector2i = e.village.batiments.back().porte
		var q := porte + Vector2i(0, 1)
		var garde := 0
		while Grille.distance(q, centre) > rayon and garde < 80:
			garde += 1
			var i := q.y * taille + q.x
			if _dans(q, taille) and not e.eau.has(i) and not e.murs.has(i):
				e.sols[i] = str(palette.sol)
				e.hauteurs[i] = H_BASE
				_degager(e, i)
			q += Vector2i(signi(centre.x - q.x), 0) if absi(centre.x - q.x) > absi(centre.y - q.y) else Vector2i(0, signi(centre.y - q.y))
	# La population : un résident par lit, le marchand dans l'échoppe, un garde sur la place.
	var residents: Dictionary = vc.residents
	for bat in e.village.batiments:
		var fiche := str(residents.get(bat.id, "villageois"))
		if not str(bat.get("guilde", "")).is_empty():
			fiche = str(villes.creature_hall)
		elif not str(bat.get("boutique", "")).is_empty():
			fiche = str(villes.creature_boutique)
		for lit in bat.lits:
			e.village.pnj.append({"creature": fiche, "pos": lit, "lit": lit, "boutique": str(bat.get("boutique", "")), "guilde": str(bat.get("guilde", ""))})
			if bat.id == "echoppe":
				break
		if bat.id == "maison" and rng.randf() < float(vc.get("forgeron_chance", 0.5)) and not bat.lits.is_empty():
			e.village.pnj[e.village.pnj.size() - 1].creature = "forgeron"
	e.village.pnj.append({"creature": str(vc.garde), "pos": centre, "lit": centre})
	if not roy.is_empty() and roy.capital_poi == cell and bool(GameData.entree("governments", str(roy.government_type)).leadership):
		e.village.pnj.append({"creature": str(GameData.config("combat_rules").royaume.succession.creature_dirigeant), "pos": centre + Vector2i(1, 1), "lit": centre + Vector2i(1, 1), "fonction": "dirigeant"})


func _degager(e: Dictionary, i: int) -> void:
	e.arbres.erase(i)
	e.rochers.erase(i)
	e.filons.erase(i)
	e.plantes.erase(i)
	e.sol[i] = true


## Pose un bâtiment préfab : murs de la palette, sol, porte, meubles ; note ses lits.
func _poser_batiment(e: Dictionary, bat: Dictionary, origine: Vector2i, palette: Dictionary, bid: String) -> void:
	var taille: int = e.largeur
	var plan: Array = bat.plan
	var meubles: Dictionary = bat.meubles
	var info := {"id": bid, "origine": origine, "porte": origine, "lits": []}
	for y in plan.size():
		var ligne: String = plan[y]
		for x in ligne.length():
			var c := ligne[x]
			if c == " ":
				continue
			var p := origine + Vector2i(x, y)
			var i := p.y * taille + p.x
			_degager(e, i)
			e.hauteurs[i] = H_BASE
			e.sols[i] = str(palette.sol)
			if c == "#":
				e.murs[i] = str(palette.mur)
				e.sol.erase(i)
			elif c == "P":
				e.portes[i] = true
				info.porte = p
			elif meubles.has(c):
				e.meubles[i] = str(meubles[c])
				if str(meubles[c]).begins_with("lit"):
					info.lits.append(p)
	e.village.batiments.append(info)


## Les accidents de relief d'une cellule (planete.relief) : chacun un modificateur 2D paramétrique.
func _poser_accidents(e: Dictionary, reserve: Rect2i, rng: RandomNumberGenerator) -> void:
	var rel: Dictionary = planete.relief
	var taille: int = e.largeur
	var nb := int(float(rng.randi_range(int(rel.par_cellule[0]), int(rel.par_cellule[1]))) * float(biomes.get(e.biome, {}).get("accidents_mult", 1.0)))
	var types: Dictionary = rel.types
	var total := 0.0
	for t in types.keys():
		total += float(types[t].poids)
	for k in nb:
		var tirage := rng.randf() * total
		var type := ""
		for t in types.keys():
			tirage -= float(types[t].poids)
			if tirage < 0.0:
				type = t
				break
		var a: Dictionary = types[type]
		var c := Vector2i(rng.randi_range(8, taille - 9), rng.randi_range(8, taille - 9))
		if reserve.grow(6).has_point(c):
			continue
		var delta := int(a.delta)
		match str(a.forme):
			"disque":   # talus, estrade, piton, cratère : un disque, bord adouci d'un niveau
				var r := rng.randi_range(int(a.rayon[0]), int(a.rayon[1]))
				for y in range(-r, r + 1):
					for x in range(-r, r + 1):
						var p := c + Vector2i(x, y)
						var d2 := x * x + y * y
						if d2 > r * r or not _dans(p, taille):
							continue
						var pente := 1.0 if d2 <= (r - 1) * (r - 1) else 0.5
						_deltater(e, p, roundi(float(delta) * pente))
			"saignee":  # gorge : un trait sinueux de largeur donnée
				var longueur := rng.randi_range(int(a.longueur[0]), int(a.longueur[1]))
				var dir := Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1)
				var p := c
				for s in longueur:
					for w in int(a.largeur):
						var q := p + (Vector2i(0, w) if dir.x != 0 else Vector2i(w, 0))
						if _dans(q, taille):
							_deltater(e, q, delta)
					p += dir
					if rng.randf() < 0.3:
						p += Vector2i(0, 1 if rng.randf() < 0.5 else -1) if dir.x != 0 else Vector2i(1 if rng.randf() < 0.5 else -1, 0)
		e.accidents.append({"type": type, "pos": c})


func _dans(p: Vector2i, taille: int) -> bool:
	return p.x > 0 and p.y > 0 and p.x < taille - 1 and p.y < taille - 1


func _deltater(e: Dictionary, p: Vector2i, delta: int) -> void:
	var i: int = p.y * e.largeur + p.x
	e.hauteurs[i] = clampi(int(e.hauteurs[i]) + delta, 0, 20)
