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
var continent_de_plaque: Array = []   # plaque → id de continent (designer 2026-09-02) : les plaques continentales qui se touchent n'en font qu'un
var continents: Dictionary = {}       # id de continent → {id, nom, plaques}
var regions_cache: Dictionary = {}    # Vector2i (germe de région) → {id, nom, germe, continent}
var points_chauds: Array = [] # [Vector2] : chapelets d'îles en plein océan
var seuil_mer: float = 0.0    # continentalité au-dessus de laquelle la terre émerge (calibré sur planete.tectonique.terres)
var warp: FastNoiseLite       # domain warping (un seul niveau)
var conti: FastNoiseLite      # bruit basse fréquence de la continentalité
var cote: FastNoiseLite       # bruit crêté du rivage : ce qui découpe les côtes (designer 2026-09-02)
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
	var roy := royaume_de(cell)
	var rayon_q: int = int(GameData.config("villes").get("rayon_place", 6)) + 1
	for v in voisines:
		var d: Vector2i = v - cell
		# Les rails suivent la route quand elle relie deux cellules du même royaume (Villes B4) — jamais hors territoire.
		var rail: bool = not roy.is_empty() and str(royaume_de(v).get("id", "")) == str(roy.id)
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
			var iq := q.y * taille + q.x
			if rail and _dans(q, taille) and not e.eau.has(iq) and not e.murs.has(iq):
				e.rails[iq] = true
				if not e.village.is_empty() and Grille.distance(q, depart) == rayon_q and not e.village.has("quai"):
					e.village["quai"] = q   # la gare : là où le rail touche la place
				if not e.village.is_empty() and q == arrivee:
					if not e.village.has("entrees_rail"):
						e.village["entrees_rail"] = []
					e.village.entrees_rail.append(q)


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
	var res := {"donjon": false, "filon_majeur": false}   # plus aucun donjon posé : ils naissent de la corruption (designer 2026-09-01)
	if not terre_a(c):
		return res
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, c.x, c.y, "poi"])
	var taille: int = int(planete.taille_cellule)
	var b: Dictionary = biomes.get(biome_a(c.x * taille + taille / 2, c.y * taille + taille / 2), {})
	var poids: Dictionary = b.get("poi_weights", {})
	var dens: Dictionary = planete.get("poi", {})
	rng.randf()   # le tirage du donjon est consommé sans effet : le retirer décalerait le flux et changerait tous les mondes
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


## L'élément dominant d'une cellule (Wu Xing hors combat) : la même lecture que le vecteur du lieu,
## agrégée au centre de la cellule. Sert au thème des donjons de corruption (designer, point 51).
func element_dominant(c: Vector2i) -> String:
	var t: int = int(planete.taille_cellule)
	var x := c.x * t + t / 2
	var y := c.y * t + t / 2
	var v := {
		"bois": valeur("vegetation", x, y) * valeur("humidite", x, y),
		"eau": valeur("humidite", x, y),
		"metal": valeur("ressources", x, y),
		"feu": maxf(absf(valeur("temperature", x, y) - 0.5) * 2.0, valeur("sismique", x, y)),
		"terre": 0.3 + valeur("altitude", x, y) * 0.4,
	}
	var meilleur := "terre"
	var part := -1.0
	for cle: String in v.keys():
		if float(v[cle]) > part:
			part = float(v[cle])
			meilleur = cle
	return meilleur


## La cellule est-elle de la terre ferme (son centre et ses quatre quarts au-dessus du niveau de la mer) ?
func terre_a(c: Vector2i) -> bool:
	var taille: int = int(planete.taille_cellule)
	var seuil := float(planete.get("mer", {}).get("altitude", 0.30))
	var q := taille / 4   # cinq sondes DANS la cellule (centre + quatre quarts) — des offsets figés sur 128 tombaient dans la cellule voisine depuis les cellules de 64 (2026-08-30)
	for off in [Vector2i(2 * q, 2 * q), Vector2i(q, q), Vector2i(3 * q, q), Vector2i(q, 3 * q), Vector2i(3 * q, 3 * q)]:
		# Le MÊME critère que la pose des tuiles de mer (generer_cellule : couches_a().altitude < mer.altitude) — l'altitude
		# tectonique seule disait « terre » sur des cellules dont chaque tuile devenait mer (départ dans l'eau, 2026-08-30).
		if float(couches_a(c.x * taille + off.x, c.y * taille + off.y).get("altitude", 1.0)) < seuil:
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
	var monde_haut := monde_tuiles * float(planete.get("monde_ratio", 1.0))   # le monde est rectangulaire
	var bord := float(int(tc.get("bord_secteurs", 2)) * 64 * int(planete.taille_cellule))
	plaques.clear()
	for k in int(tc.get("plaques", 24)):
		var c := Vector2(rng.randf() * monde_tuiles, rng.randf() * monde_haut)
		var pres_du_bord := c.x < bord or c.y < bord or c.x > monde_tuiles - bord or c.y > monde_haut - bord
		plaques.append({"centre": c, "continentale": (rng.randf() < float(tc.get("continentales", 0.4))) and not pres_du_bord,
			"derive": Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 1.0)})
	points_chauds.clear()
	var pc: Array = tc.get("points_chauds", [8, 14])
	for k in rng.randi_range(int(pc[0]), int(pc[1])):
		points_chauds.append(Vector2(rng.randf() * monde_tuiles, rng.randf() * monde_haut))
	warp = FastNoiseLite.new()
	warp.seed = graine + 101
	warp.frequency = float(tc.get("warp_frequence", 0.00025))
	warp.fractal_octaves = 2
	conti = FastNoiseLite.new()
	conti.seed = graine + 102
	conti.frequency = float(tc.get("continentalite_frequence", 0.00012))
	conti.fractal_octaves = 3
	cote = FastNoiseLite.new()   # le ciselage du rivage (designer 2026-09-02)
	cote.seed = graine + 104
	cote.frequency = float(tc.get("cote_frequence", 0.0022))
	cote.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	cote.fractal_octaves = 4
	cote.fractal_gain = 0.55
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
			valeurs.append(_continentalite(Vector2((i + 0.5) / n * monde_tuiles, (j + 0.5) / n * monde_haut)))
	valeurs.sort()
	var part_terres: float = float(tc.get("terres", 0.35))
	seuil_mer = valeurs[clampi(int(float(valeurs.size()) * (1.0 - part_terres)), 0, valeurs.size() - 1)]
	_continents()   # le seuil de mer est posé : les masses de terre peuvent être réunies et nommées


## ---------------------------------------------------------------- continents et régions (designer 2026-09-02)
##
## Le designer a écarté « la région est le territoire d'un royaume » d'une phrase juste : « les territoires
## sont voués à changer ». Une région dont les frontières bougent au gré des conquêtes ne peut porter ni un
## nom stable, ni un gouffre permanent, ni la mémoire de ce qu'on y a fait. La découpe est donc purement
## géographique, et lue à la demande comme la tectonique — aucune passe sur le monde entier.

## Les continents : les plaques continentales qui se touchent n'en forment qu'un. Deux plaques se touchent
## si aucune troisième ne s'intercale entre leurs centres — l'approximation de Voronoï qui suffit ici, et
## qui évite de parcourir un million de cellules pour un remplissage par diffusion.
func _continents() -> void:
	continent_de_plaque.clear()
	continents.clear()
	var parent: Array[int] = []
	for k in plaques.size():
		parent.append(k)
		continent_de_plaque.append(-1)
	var trouver := func(a: int) -> int:
		var r := a
		while parent[r] != r:
			r = parent[r]
		return r
	for a in plaques.size():
		if not bool(plaques[a].continentale):
			continue
		for b in range(a + 1, plaques.size()):
			if not bool(plaques[b].continentale) or not _plaques_voisines(a, b):
				continue
			var ra: int = trouver.call(a)
			var rb: int = trouver.call(b)
			if ra != rb:
				parent[rb] = ra
	var rng := RandomNumberGenerator.new()
	var cultures: Dictionary = GameData.catalogues.get("name_cultures", {})
	for k in plaques.size():
		if not bool(plaques[k].continentale):
			continue
		var racine: int = trouver.call(k)
		continent_de_plaque[k] = racine
		if not continents.has(racine):
			rng.seed = hash([graine, racine, "continent"])
			continents[racine] = {"id": racine, "nom": _nom_de_terre(rng, cultures), "plaques": []}
		(continents[racine].plaques as Array).append(k)


## Deux plaques sont voisines si le milieu de leurs centres appartient à l'une des deux (test de Voronoï).
func _plaques_voisines(a: int, b: int) -> bool:
	var m: Vector2 = (plaques[a].centre + plaques[b].centre) * 0.5
	var d_ab: float = m.distance_to(plaques[a].centre)
	for k in plaques.size():
		if k != a and k != b and m.distance_to(plaques[k].centre) < d_ab:
			return false
	return true


## Un nom de terre : le générateur de noms de ville d'une culture tirée au sort — les cultures portent
## déjà des sonorités par race, et une terre se nomme comme une ville, pas comme une personne.
func _nom_de_terre(rng: RandomNumberGenerator, cultures: Dictionary) -> String:
	if cultures.is_empty():
		return "Terre-%d" % (rng.randi() % 1000)
	var ids: Array = cultures.keys()
	ids.sort()
	return Noms.ville(cultures[str(ids[rng.randi() % ids.size()])], rng)


## Le pas du réseau de germes de région, en cellules.
func _pas_region() -> int:
	return maxi(2, int(planete.get("regions", {}).get("pas_cellules", 24)))


## Le germe de région le plus proche d'une cellule. Les germes sont posés sur un réseau régulier puis
## déplacés d'un hash — un Voronoï jitteré, qui donne des régions de taille comparable sans les rendre
## carrées, et qui se lit en neuf comparaisons quelle que soit la taille du monde.
func germe_region(c: Vector2i) -> Vector2i:
	var pas := _pas_region()
	var amp: float = float(planete.get("regions", {}).get("jitter", 0.38)) * float(pas)
	var base := Vector2i(floori(float(c.x) / float(pas)), floori(float(c.y) / float(pas)))
	var meilleur := base
	var d_min := INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var g: Vector2i = base + Vector2i(dx, dy)
			var h := hash([graine, g.x, g.y, "region"])
			var jx := (float(h % 1000) / 1000.0 - 0.5) * 2.0 * amp
			var jy := (float((h / 1000) % 1000) / 1000.0 - 0.5) * 2.0 * amp
			var centre := Vector2((float(g.x) + 0.5) * pas + jx, (float(g.y) + 0.5) * pas + jy)
			var d := centre.distance_squared_to(Vector2(c))
			if d < d_min:
				d_min = d
				meilleur = g
	return meilleur


## La région d'une cellule : {id, nom, germe, cellule (le centre de la région), continent}. La mer n'a
## pas de région — on ne nomme pas le large, et le gouffre d'une région doit avoir un sol où s'ouvrir.
func region_de(c: Vector2i) -> Dictionary:
	var g := germe_region(c)
	if regions_cache.has(g):
		return regions_cache[g]
	var pas := _pas_region()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, g.x, g.y, "nom_region"])
	# Où s'ouvre le gouffre de la région. Le prendre au centre géométrique donnait une grille de gouffres
	# parfaitement régulière sur la carte — on lisait le réseau de germes à l'œil nu. On part donc d'un
	# point tiré au hasard DANS la région, et on cherche le sol autour : même coût, plus de grille.
	var h_c := hash([graine, g.x, g.y, "coeur"])
	var ecart := pas / 3
	var centre := Vector2i(g.x * pas + pas / 2 + (h_c % (2 * ecart + 1)) - ecart,
		g.y * pas + pas / 2 + ((h_c / 977) % (2 * ecart + 1)) - ecart)
	var sol := Vector2i(-9999, -9999)
	for rayon in range(0, pas):
		for dy in range(-rayon, rayon + 1):
			for dx in range(-rayon, rayon + 1):
				if absi(dx) != rayon and absi(dy) != rayon:
					continue
				var v: Vector2i = centre + Vector2i(dx, dy)
				if sol.x == -9999 and germe_region(v) == g and terre_a(v):
					sol = v
		if sol.x != -9999:
			break
	var res := {"id": "%d_%d" % [g.x, g.y], "germe": g, "cellule": sol,
		"nom": _nom_de_terre(rng, GameData.catalogues.get("name_cultures", {})),
		"continent": continent_de(sol) if sol.x != -9999 else {}}
	regions_cache[g] = res
	return res


## Le continent d'une cellule : {} en mer, sinon le continent de sa plaque.
func continent_de(c: Vector2i) -> Dictionary:
	if not terre_a(c):
		return {}
	if continent_de_plaque.is_empty():
		_continents()
	var t: int = int(planete.taille_cellule)
	var q := _warpe(Vector2(c.x * t + t / 2, c.y * t + t / 2))
	var k: int = int(_plaques_proches(q)[0])
	var racine: int = int(continent_de_plaque[k]) if k >= 0 and k < continent_de_plaque.size() else -1
	return continents.get(racine, {})


## Combien le relief de rivage doit peser en ce point : 1 sur le trait de côte, 0 dès qu'on s'en
## éloigne. Sans cette fenêtre, un bruit assez fort pour ciseler les côtes trouerait aussi l'intérieur
## des terres et sèmerait des cailloux au milieu de l'océan.
func _fenetre_cote(c: float) -> float:
	var largeur := float(planete.get("tectonique", {}).get("cote_fenetre", 0.35))
	if largeur <= 0.0:
		return 0.0
	return maxf(0.0, 1.0 - absf(c - seuil_mer) / largeur)


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
	# Le dessin des côtes (designer 2026-09-02 : « plus réaliste et moins plat »). La continentalité seule
	# donne des rivages lisses, en galets — parce que ses deux termes sont à très basse fréquence : la
	# plaque et un bruit de 0,00012. Les vraies côtes doivent leur découpe à des accidents BIEN plus
	# fins que le continent qui les porte : caps, baies, presqu'îles, chapelets d'îles.
	# On ajoute donc un relief de rivage à haute fréquence, mais dont l'effet est **concentré près du
	# niveau de la mer** : `_fenetre_cote` vaut 1 sur le trait de côte et retombe à 0 dès qu'on entre
	# dans les terres ou au large. Le continent garde ainsi sa forme d'ensemble — seul son bord est
	# ciselé. Un bruit ajouté partout aurait troué les continents et semé des îles dans tout l'océan.
	var tcz: Dictionary = planete.get("tectonique", {})
	var amp_cote := float(tcz.get("cote_amplitude", 0.0))
	if amp_cote > 0.0 and cote != null:
		var brut := cote.get_noise_2d(q.x, q.y)
		# Le bruit crêté (`FRACTAL_RIDGED`) donne des arêtes franches plutôt que des ondulations molles :
		# des pointes de terre qui avancent dans l'eau, pas des bosses.
		var decoupe := brut + 0.45 * cote.get_noise_2d(q.x * 2.7 + 4111.0, q.y * 2.7 - 907.0)
		c += decoupe * amp_cote * _fenetre_cote(c)
	var r := float(planete.get("tectonique", {}).get("point_chaud_rayon", 9000.0))
	for pc in points_chauds:
		var dp: float = q.distance_to(pc)
		if dp < r:
			c += (1.0 - dp / r) * 1.4
	# Le monde est entouré d'eau (designer 2026-08-31) : la continentalité s'effondre sur la marge du
	# bord, quelles que soient les plaques — aucune terre ne touche la limite de la carte.
	var larg := float(int(planete.monde_cellules) * int(planete.taille_cellule))
	var haut := larg * float(planete.get("monde_ratio", 1.0))
	var marge := minf(larg, haut) * float(planete.get("tectonique", {}).get("ocean_bord", 0.10))
	if marge > 0.0:
		var d_bord: float = minf(minf(p.x, larg - p.x), minf(p.y, haut - p.y))
		if d_bord < marge:
			c -= (1.0 - clampf(d_bord / marge, 0.0, 1.0)) * 6.0
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
	e["stations"] = {}
	e["rails"] = {}
	var agglo := agglomeration_de(Vector2i(cx, cy)) if camp.is_empty() else {}   # une cellule d'agglomération : un quartier (Villes B1)
	if not agglo.is_empty():
		_poser_quartier(e, Vector2i(cx, cy), rng, agglo)
	_poser_route(e, Vector2i(cx, cy))
	for d in [e.arbres, e.rochers, e.filons, e.eau]:
		for i in d.keys():
			e.sol.erase(i)
	return e   # les plantes restent du sol (franchissables) : la simulation les pose comme contenu


# ---------------------------------------------------------------- les agglomérations (Villes — B1, 2026-09-05)

const SPIRALE: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]

var agglos_cache: Dictionary = {}      # cellule → l'agglomération dont elle fait partie ({} : aucune)
var fiches_agglo: Dictionary = {}      # cellule-centre → sa fiche
var mutex_agglo := Mutex.new()
var cellule_camp := Vector2i(-99999, -99999)   # la cellule du camp n'est jamais un quartier : le camp est le territoire du joueur


## L'agglomération dont une cellule fait partie (Villes — population, quartiers et économie) : {} si aucune ; sinon
## la fiche du centre plus `quartier` (le type de cette cellule) et `index` (son rang dans l'emprise). Une lecture
## pure du voisinage, en cache : toutes les cellules sont d'accord sur l'emprise d'un centre, sans générer personne.
func agglomeration_de(c: Vector2i) -> Dictionary:
	mutex_agglo.lock()
	if agglos_cache.has(c):
		var r0: Dictionary = agglos_cache[c]
		mutex_agglo.unlock()
		return r0
	mutex_agglo.unlock()
	var res := {}
	if terre_a(c) and c != cellule_camp:
		var centres: Array = []
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var k := c + Vector2i(dx, dy)
				if k != cellule_camp and terre_a(k) and bool(poi_de(k).get("village", false)):
					centres.append(k)
		centres.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _rang_centre(c, a) < _rang_centre(c, b))
		for k in centres:
			var fiche := fiche_agglomeration(k)
			var idx: int = fiche.cellules.find(c)
			if idx >= 0:
				res = fiche.duplicate()
				res["quartier"] = str(fiche.quartiers[idx])
				res["index"] = idx
				break
	mutex_agglo.lock()
	agglos_cache[c] = res
	mutex_agglo.unlock()
	return res


## Le rang d'un centre vu d'une cellule : la distance d'abord, puis un hachage de sa position (toujours le même).
func _rang_centre(c: Vector2i, k: Vector2i) -> int:
	return Grille.distance(c, k) * 1000 + posmod(hash([k.x, k.y]), 1000)


## Un autre centre revendique-t-il mieux la cellule `k` que `centre` ? (plus proche, ou de même distance et de rang plus petit)
func _centre_plus_proche(k: Vector2i, centre: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var k2 := k + Vector2i(dx, dy)
			if k2 == centre or k2 == k or k2 == cellule_camp or not terre_a(k2) or not bool(poi_de(k2).get("village", false)):
				continue
			if _rang_centre(k, k2) < _rang_centre(k, centre):
				return true
	return false


func _tirer_liste(liste: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for it in liste:
		total += float(it[1])
	var t := rng.randf() * total
	for it in liste:
		t -= float(it[1])
		if t <= 0.0:
			return str(it[0])
	return str(liste[0][0])


## La fiche d'une agglomération (son centre est une cellule-village de poi_de) : palier et population selon sa
## situation (data/villes.json), l'emprise en spirale, le type de chaque cellule, la population de chacune, les
## boutiques de chacune (jamais deux du même type dans l'agglomération), la culture et le nom.
func fiche_agglomeration(centre: Vector2i) -> Dictionary:
	mutex_agglo.lock()
	if fiches_agglo.has(centre):
		var f0: Dictionary = fiches_agglo[centre]
		mutex_agglo.unlock()
		return f0
	mutex_agglo.unlock()
	var cfg: Dictionary = GameData.config("villes")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, centre.x, centre.y, "agglomeration"])
	var roy := royaume_de(centre)
	var capitale: bool = not roy.is_empty() and roy.capital_poi == centre
	var palier := "hameau"
	if capitale:
		palier = str(cfg.situations.capitale.get(str(roy.taille), "village"))
	else:
		var sit := "sauvage"
		if not roy.is_empty():
			sit = "territoire_route" if not route_de(centre).is_empty() else "territoire"
		palier = _tirer_liste(cfg.situations[sit], rng)
	var fourchette: Array = cfg.paliers[palier].pop
	var population := rng.randi_range(int(fourchette[0]), int(fourchette[1]))
	var n_cells := clampi(int(ceil(float(population) / float(cfg.habitants_par_cellule))), 1, int(cfg.cellules_max))
	var cellules: Array = [centre]
	for d in SPIRALE:
		if cellules.size() >= n_cells:
			break
		var k: Vector2i = centre + d
		if k == cellule_camp or not terre_a(k) or bool(poi_de(k).get("village", false)) or _centre_plus_proche(k, centre):
			continue
		cellules.append(k)
	var ordre: Array = cfg.quartiers.get(palier, ["centre"])
	var quartiers: Array = []
	for i in cellules.size():
		quartiers.append(str(ordre[i]) if i < ordre.size() else str(ordre[ordre.size() - 1]))
	var total := 0.0
	for q in quartiers:
		total += float(cfg.parts.get(q, 1.0))
	var pops: Array = []
	var reste := population
	for i in quartiers.size():
		var n := reste if i == quartiers.size() - 1 else clampi(int(round(float(population) * float(cfg.parts.get(quartiers[i], 1.0)) / total)), 1, maxi(1, reste - (quartiers.size() - 1 - i)))
		pops.append(n)
		reste -= n
	# Les boutiques : une liste de types mélangée à la graine de l'agglomération, servie quartier par quartier.
	var types: Array = GameData.catalogues.shop_types.keys()
	types.sort()
	for i in range(types.size() - 1, 0, -1):
		var k2 := rng.randi_range(0, i)
		var tmp = types[i]
		types[i] = types[k2]
		types[k2] = tmp
	var boutiques: Array = []
	var pris := 0
	for i in quartiers.size():
		var comp: Dictionary = cfg.composition[str(quartiers[i])]
		var n_b := 0
		if i == 0:
			var fb: Array = cfg.paliers[palier].boutiques
			n_b = rng.randi_range(int(fb[0]), int(fb[1]))
		else:
			n_b = int(pops[i]) / maxi(1, int(comp.boutiques_par_habitant))
		var liste: Array = []
		for k3 in n_b:
			if pris < types.size():
				liste.append(str(types[pris]))
				pris += 1
		boutiques.append(liste)
	var halls: Array = []
	var fh: Array = cfg.paliers[palier].halls
	var guildes: Array = GameData.catalogues.guilds.keys()
	guildes.sort()
	for k4 in rng.randi_range(int(fh[0]), int(fh[1])):
		if guildes.is_empty():
			break
		var g: String = str(guildes[rng.randi() % guildes.size()])
		guildes.erase(g)
		halls.append(g)
	var cultures: Dictionary = GameData.catalogues.name_cultures
	var culture_id := Noms.culture_pour("humain", cultures, rng)
	if not roy.is_empty() and cultures.has(str(roy.culture)):
		culture_id = str(roy.culture)
	var nom := Noms.ville(cultures.get(culture_id, {}), rng) if cultures.has(culture_id) else "Hameau"
	var fiche := {"centre": centre, "nom": nom, "culture": culture_id, "royaume": str(roy.get("id", "")), "capitale": capitale, "gouvernance": str(roy.get("government_type", "")),
		"palier": palier, "population": population, "cellules": cellules, "quartiers": quartiers, "populations": pops, "boutiques": boutiques, "halls": halls}
	mutex_agglo.lock()
	fiches_agglo[centre] = fiche
	mutex_agglo.unlock()
	return fiche


## Pave une tuile au sol de la palette (une rue, une place, un chemin) et la note dans `rue`.
func _paver(e: Dictionary, p: Vector2i, palette: Dictionary, rue: Dictionary) -> void:
	var taille: int = e.largeur
	var i := p.y * taille + p.x
	if not _dans(p, taille) or e.eau.has(i) or e.murs.has(i):
		return
	e.sols[i] = str(palette.sol)
	e.hauteurs[i] = H_BASE
	_degager(e, i)
	rue[i] = true


## Un plan de préfab orienté : la porte vers le sud (tel quel), le nord (lignes renversées), l'est ou l'ouest (transposé).
func _orienter(plan: Array, sens: String) -> Array:
	var res: Array = []
	match sens:
		"nord":
			for k in range(plan.size() - 1, -1, -1):
				res.append(str(plan[k]))
		"est", "ouest":
			var w: int = str(plan[0]).length()
			for x in w:
				var ligne := ""
				for y in plan.size():
					ligne += str(plan[y])[x]
				res.append(ligne.reverse() if sens == "ouest" else ligne)
		_:
			for ligne in plan:
				res.append(str(ligne))
	return res


## Un quartier d'agglomération (Villes B1) — le hameau et le village en sont un seul, de type « centre ». Deux rues
## par le milieu, une place au croisement, les bâtiments en parcelles le long des rues, façade sur la rue ; les gens,
## leurs postes et leurs lits ; le plan du territoire (rôle, périmètres, stockages) que la simulation créera.
func _poser_quartier(e: Dictionary, cell: Vector2i, rng: RandomNumberGenerator, agglo: Dictionary) -> void:
	var cfg: Dictionary = GameData.config("villes")
	var vc: Dictionary = planete.get("village", {})
	var taille: int = e.largeur
	var bats: Dictionary = GameData.catalogues.village_buildings
	var b: Dictionary = biomes.get(e.biome, {})
	var palette: Dictionary = b.get("village_palette", {"mur": "chene", "toit": "chaume_tresse", "sol": "calcaire"})
	var quartier := str(agglo.quartier)
	var comp: Dictionary = cfg.composition[quartier]
	var palier := str(agglo.palier)
	var pop: int = int(agglo.populations[int(agglo.index)])
	var centre := Vector2i(taille / 2, taille / 2)
	var roles: Dictionary = cfg.roles
	e.village = {"nom": str(agglo.nom), "culture": str(agglo.culture), "centre": centre, "batiments": [], "pnj": [], "royaume": str(agglo.royaume),
		"palier": palier, "taille": palier, "population": int(agglo.population), "population_quartier": pop, "quartier": quartier, "cellule_centre": agglo.centre,
		"index": int(agglo.index), "capitale": bool(agglo.capitale), "gouvernance": str(agglo.gouvernance),
		"territoire": {"role": str(roles.get(quartier, "base")), "perimetres": [], "stockages": []}}
	# 1. Les rues : deux axes par le milieu, `rue_largeur` tuiles de large — elles se raccordent d'une cellule à
	#    l'autre ; à partir du bourg, deux rues parallèles à chaque axe (une grille de neuf îlots, plus de façades).
	var larg: int = int(cfg.rue_largeur)
	var rue := {}
	var rues_h: Array[int] = [centre.y]
	var rues_v: Array[int] = [centre.x]
	if palier != "hameau":   # dès le village : un village de trente-cinq âmes ne loge pas le long de deux rues
		rues_h.append_array([centre.y - taille / 4, centre.y + taille / 4])
		rues_v.append_array([centre.x - taille / 4, centre.x + taille / 4])
	for yr in rues_h:
		for k in taille:
			for w in larg:
				_paver(e, Vector2i(k, yr - larg / 2 + w), palette, rue)
	for xr in rues_v:
		for k in taille:
			for w in larg:
				_paver(e, Vector2i(xr - larg / 2 + w, k), palette, rue)
	# 2. La place au croisement (le centre, le quartier marchand, une placette au résidentiel).
	var pris: Array[Rect2i] = []
	var rayon: int = int(cfg.rayon_place) if quartier == "centre" else int(cfg.rayon_placette)
	if bool(comp.place):
		for dy in range(-rayon, rayon + 1):
			for dx in range(-rayon, rayon + 1):
				_paver(e, centre + Vector2i(dx, dy), palette, rue)
		pris.append(Rect2i(centre - Vector2i(rayon, rayon), Vector2i(2 * rayon + 1, 2 * rayon + 1)))
	# 3. La file des bâtiments : [préfab, boutique, guilde, station, fonction].
	var file: Array = []
	var siege_fonction := ""
	if bool(comp.siege) and palier in ["bourg", "ville", "cite"] and not str(agglo.gouvernance).is_empty():
		var siege: Dictionary = GameData.entree("governments", str(agglo.gouvernance)).get("siege", {})
		if bats.has(str(siege.get("batiment", ""))):
			siege_fonction = str(siege.get("fonction", ""))
			file.append([str(siege.batiment), "", "", "", siege_fonction])
	if bool(comp.halls):
		for g in agglo.halls:
			file.append(["hall", "", str(g), "", ""])
	for t in agglo.boutiques[int(agglo.index)]:
		file.append(["echoppe", str(t), "", "", ""])
	if bool(comp.chapelle) and not (siege_fonction == "pretre"):
		file.append(["chapelle", "", "", "", ""])
	if bool(comp.auberge):
		file.append(["auberge", "", "", "", ""])
	if bool(comp.get("ecurie", false)) and bats.has("ecurie"):   # le maquignon vend des montures (Villes B4)
		file.append(["ecurie", "", "", "", ""])
	var stations: Array = cfg.stations_ateliers.duplicate()
	var n_ateliers: int = pop / maxi(1, int(comp.ateliers_par_habitant)) if int(comp.ateliers_par_habitant) > 0 else 0
	for k in n_ateliers:
		file.append(["atelier", "", "", str(stations[(k + rng.randi_range(0, stations.size() - 1)) % stations.size()]), ""])
	for k in int(comp.entrepots):
		file.append(["entrepot", "", "", "", ""])
	# Les logements : autant de lits que d'habitants, les fonctionnels comptés.
	var lits := 0
	for f in file:
		lits += _lits_du_plan(bats[str(f[0])].plan, bats[str(f[0])].meubles)
	var logements: Array = comp.logements
	var k_log := rng.randi_range(0, logements.size() - 1)
	var garde_fou := 0
	while lits < pop and garde_fou < 60:
		garde_fou += 1
		var bid: String = str(logements[k_log % logements.size()])
		k_log += 1
		if not bats.has(bid):
			continue
		file.append([bid, "", "", "", ""])
		lits += _lits_du_plan(bats[bid].plan, bats[bid].meubles)
	# 4. Les parcelles le long des rues : les quatre côtés à tour de rôle, du centre vers les bords.
	var cotes := ["sud", "nord", "est", "ouest"]
	var curseurs := {"sud": 0, "nord": 0, "est": 0, "ouest": 0}
	var lots := {}   # index de tuile → true : les emprises des bâtiments (les zones de récolte les évitent)
	var residentiel: Dictionary = {}   # tuiles du périmètre résidentiel (les logements et une marge)
	for k in file.size():
		var bid: String = str(file[k][0])
		var bat: Dictionary = bats[bid]
		var pose := false
		for essai in 4:
			var sens: String = cotes[(k + essai) % 4]
			var plan := _orienter(bat.plan, sens)
			var w: int = str(plan[0]).length()
			var h: int = plan.size()
			var origine := _parcelle(e, sens, w, h, centre, larg, curseurs, pris, rues_h, rues_v)
			if origine == Vector2i(-1, -1):
				continue
			var r := Rect2i(origine, Vector2i(w, h))
			pris.append(r)
			var b2 := bat.duplicate()
			b2.plan = plan
			if not str(file[k][3]).is_empty():
				b2["station_id"] = str(file[k][3])
			_poser_batiment(e, b2, origine, palette, bid)
			var info: Dictionary = e.village.batiments.back()
			info["boutique"] = str(file[k][1])
			info["guilde"] = str(file[k][2])
			info["station"] = str(file[k][3])
			info["fonction"] = str(file[k][4])
			info["rect"] = r
			for y in h:
				for x in w:
					lots[(origine.y + y) * taille + origine.x + x] = true
			if "logement" in bat.get("tags", []) or "hameau" in bat.get("tags", []) or bid in ["maison", "maison_haute", "chaumiere"]:
				for y in range(-3, h + 3):
					for x in range(-3, w + 3):
						var q := origine + Vector2i(x, y)
						if _dans(q, taille):
							residentiel[q] = true
			# Le chemin de la porte à la rue.
			var dir: Vector2i = {"sud": Vector2i(0, 1), "nord": Vector2i(0, -1), "est": Vector2i(1, 0), "ouest": Vector2i(-1, 0)}[sens]
			var q2: Vector2i = info.porte + dir
			var pas := 0
			while pas < 8 and _dans(q2, taille) and not rue.has(q2.y * taille + q2.x):
				_paver(e, q2, palette, rue)
				q2 += dir
				pas += 1
			pose = true
			break
		if not pose:
			continue
	# 5. Les gens : un résident par lit ; la fiche et la fonction du bâtiment ; le poste dans le bâtiment.
	var residents: Dictionary = vc.residents
	var fiches: Dictionary = cfg.fiches
	var fonctions: Dictionary = cfg.fonctions
	var villes: Dictionary = GameData.config("combat_rules").royaume.villes
	var forgeron_pose := false
	for bat in e.village.batiments:
		var fiche := str(fiches.get(bat.id, residents.get(bat.id, "villageois")))
		var fonction := str(bat.get("fonction", ""))
		if fonction.is_empty():
			fonction = str(fonctions.get(bat.id, ""))
		if not str(bat.get("guilde", "")).is_empty():
			fiche = str(villes.creature_hall)
			fonction = "maitre_de_guilde"
		elif not str(bat.get("boutique", "")).is_empty():
			fiche = str(villes.creature_boutique)
			fonction = "commercant"
		var poste: Vector2i = bat.get("poste", bat.porte)
		var premier := true
		for lit in bat.lits:
			var pj := {"creature": fiche, "pos": poste if premier else lit, "lit": lit, "poste": poste, "boutique": str(bat.get("boutique", "")), "guilde": str(bat.get("guilde", "")), "batiment": bat.id}
			if not fonction.is_empty() and (premier or fonction in ["oisif", "fermier"]):
				pj["fonction"] = fonction
			elif not premier:
				pj["fonction"] = "oisif"
			e.village.pnj.append(pj)
			premier = false
			if bat.id == "echoppe" or bat.id == "hall":
				break
		if bat.id in ["maison", "maison_haute"] and not forgeron_pose and rng.randf() < float(vc.get("forgeron_chance", 0.5)) and not bat.lits.is_empty() and quartier != "centre":
			forgeron_pose = true   # un forgeron au plus par quartier (la chance de la fiche vaut pour le quartier, pas par maison)
			e.village.pnj[e.village.pnj.size() - 1].creature = "forgeron"
			e.village.pnj[e.village.pnj.size() - 1]["fonction"] = "artisan"
	# 6. Les gardes : un sur la place du centre, puis un par `gardes_par_habitant`, aux croisements.
	var n_gardes: int = (1 if quartier == "centre" else 0) + pop / maxi(1, int(cfg.gardes_par_habitant))
	for k in n_gardes:
		var d: Vector2i = [Vector2i(0, 0), Vector2i(taille / 4, 0), Vector2i(-taille / 4, 0), Vector2i(0, taille / 4), Vector2i(0, -taille / 4)][k % 5]
		var p := centre + d
		e.village.pnj.append({"creature": str(vc.garde), "pos": p, "lit": p, "poste": p, "fonction": "garde"})
	# 7. Le pouvoir : le dirigeant du royaume dans sa capitale (au siège s'il y en a un, sinon sur la place).
	if bool(agglo.capitale) and quartier == "centre" and not str(agglo.gouvernance).is_empty() and bool(GameData.entree("governments", str(agglo.gouvernance)).leadership):
		var ou := centre + Vector2i(1, 1)
		var lit_d := ou
		for bat in e.village.batiments:
			if "siege" in bats[bat.id].get("tags", []):
				ou = bat.get("poste", bat.porte)
				lit_d = bat.lits[0] if not bat.lits.is_empty() else ou
				for pj in e.village.pnj:   # le magistrat cède la place au dirigeant
					if pj.get("batiment", "") == bat.id and pj.get("fonction", "") == siege_fonction:
						pj.erase("fonction")
						pj["fonction"] = "oisif"
				break
		e.village.pnj.append({"creature": str(GameData.config("combat_rules").royaume.succession.creature_dirigeant), "pos": ou, "lit": lit_d, "poste": ou, "fonction": "dirigeant"})
	# 8. Les champs et l'enclos (Villes B2) : des rectangles de terre libre derrière les maisons, hors rues.
	var per: Array = e.village.territoire.perimetres
	var tags_b: Array = b.get("tags", [])
	var ch: Dictionary = cfg.get("champs", {})
	e.village["champs"] = []
	e.village["betes"] = []
	var n_champs := 0
	if quartier in ch.get("quartiers", []):
		n_champs = pop / maxi(1, int(ch.par_habitant if quartier == "agricole" else ch.get("par_habitant_hors_agricole", 20)))
	var liste_c: Array = _liste_par_biome(ch.get("cultures_par_biome", {}), tags_b)
	for k in n_champs:
		if liste_c.is_empty():
			break
		var r := _rectangle_libre(e, Vector2i(int(ch.taille[0]), int(ch.taille[1])), pris, rue, rng)
		if r.position == Vector2i(-1, -1):
			break
		pris.append(r)
		var tuiles_c: Array = []
		for y in r.size.y:
			for x in r.size.x:
				var q := r.position + Vector2i(x, y)
				var i := q.y * taille + q.x
				_degager(e, i)
				lots[i] = true
				tuiles_c.append(q)
		var plante := str(liste_c[(k + rng.randi_range(0, liste_c.size() - 1)) % liste_c.size()])
		e.village.champs.append({"rect": r, "plante": plante, "tuiles": tuiles_c})
		per.append({"type": "champs", "tuiles": tuiles_c, "plante": plante})
		var n_f := 0   # deux fermiers du quartier (ou deux oisifs qui le deviennent) y travaillent
		for pj in e.village.pnj:
			if n_f >= int(ch.get("fermiers_par_champ", 2)):
				break
			if not pj.has("perimetre") and str(pj.get("fonction", "oisif")) in ["fermier", "oisif"] and str(pj.get("creature", "")) in ["villageois", "fermier"]:
				pj["fonction"] = "fermier"
				pj["perimetre"] = per.size() - 1
				n_f += 1
	var en: Dictionary = cfg.get("enclos", {})
	var especes: Array = _liste_par_biome(en.get("especes_par_biome", {}), tags_b)
	for k in int(en.get("par_quartier", {}).get(quartier, 0)):
		if especes.is_empty():
			break
		var r := _rectangle_libre(e, Vector2i(int(en.taille[0]), int(en.taille[1])), pris, rue, rng)
		if r.position == Vector2i(-1, -1):
			break
		pris.append(r)
		var interieur: Array = []
		for y in r.size.y:
			for x in r.size.x:
				var q := r.position + Vector2i(x, y)
				var i := q.y * taille + q.x
				_degager(e, i)
				lots[i] = true
				if x == 0 or y == 0 or x == r.size.x - 1 or y == r.size.y - 1:
					e.meubles[i] = "enclos"
				else:
					interieur.append(q)
		for kb in rng.randi_range(int(en.betes[0]), int(en.betes[1])):
			if interieur.is_empty():
				break
			var q_b: Vector2i = interieur[rng.randi_range(0, interieur.size() - 1)]
			interieur.erase(q_b)
			e.village.betes.append({"espece": str(especes[rng.randi_range(0, especes.size() - 1)]), "pos": q_b})
		for pj in e.village.pnj:   # un éleveur devant l'enclos
			if str(pj.get("fonction", "oisif")) == "oisif" and str(pj.get("creature", "")) == "villageois" and not pj.has("perimetre"):
				pj["fonction"] = "eleveur"
				pj["poste"] = r.position + Vector2i(-1, r.size.y / 2)
				pj["pos"] = pj.poste
				break
	# 9. Le plan du territoire : le résidentiel, les stockages (les entrepôts), les zones de récolte en lisière.
	if not residentiel.is_empty():
		var tuiles_r: Array = residentiel.keys()
		per.append({"type": "residentiel", "tuiles": tuiles_r})
	for bat in e.village.batiments:
		if "stockage" in bats[bat.id].get("tags", []):
			var tuiles_s: Array = []
			var r: Rect2i = bat.rect
			for y in range(1, r.size.y - 1):
				for x in range(1, r.size.x - 1):
					var q := r.position + Vector2i(x, y)
					if not e.murs.has(q.y * taille + q.x) and not e.meubles.has(q.y * taille + q.x):
						tuiles_s.append(q)
			per.append({"type": "stockage", "tuiles": tuiles_s, "batiment": bat.id})
			e.village.territoire.stockages.append(per.size() - 1)
	var maxz: int = int(cfg.get("zone_tuiles_max", 40))
	for z in comp.zones:
		var source: Dictionary = {"bois": e.arbres, "minerai": e.filons, "plantes": e.plantes}.get(str(z), {})
		var tuiles_z: Array = []
		for i in source.keys():
			if tuiles_z.size() >= maxz:
				break
			if lots.has(i) or rue.has(i):
				continue
			tuiles_z.append(Vector2i(int(i) % taille, int(i) / taille))
		if str(z) == "plantes":
			for i in e.cueillette.keys():
				if tuiles_z.size() >= maxz:
					break
				if not lots.has(i) and not rue.has(i):
					tuiles_z.append(Vector2i(int(i) % taille, int(i) / taille))
		if tuiles_z.size() >= 4:
			per.append({"type": str(z), "tuiles": tuiles_z})
			# Deux résidents sans métier deviennent ses ouvriers (bûcheron, mineur, herboriste).
			var fonction_z := str(GameData.config("combat_rules").royaume.perimetres.types[str(z)].fonction)
			var n_ouvriers := 0
			for pj in e.village.pnj:
				if n_ouvriers >= 2:
					break
				if str(pj.get("fonction", "oisif")) == "oisif" and str(pj.get("creature", "")) == "villageois":
					pj["fonction"] = fonction_z
					pj["perimetre"] = per.size() - 1
					n_ouvriers += 1


## La liste d'une table par tag de biome (`_defaut` sinon).
func _liste_par_biome(table: Dictionary, tags: Array) -> Array:
	for t in tags:
		if table.has(str(t)):
			return table[str(t)]
	return table.get("_defaut", [])


## Un rectangle de terre libre (ni rue, ni parcelle prise, ni eau), tiré au sort ; position (-1,-1) s'il n'y en a pas.
func _rectangle_libre(e: Dictionary, dims: Vector2i, pris: Array[Rect2i], rue: Dictionary, rng: RandomNumberGenerator) -> Rect2i:
	var taille: int = e.largeur
	for essai in 80:
		var origine := Vector2i(rng.randi_range(2, taille - 3 - dims.x), rng.randi_range(2, taille - 3 - dims.y))
		var r := Rect2i(origine, dims)
		var libre := true
		for pr in pris:
			if pr.grow(1).intersects(r):
				libre = false
				break
		if not libre:
			continue
		for y in dims.y:
			for x in dims.x:
				var i := (origine.y + y) * taille + origine.x + x
				if e.eau.has(i) or rue.has(i) or e.murs.has(i):
					libre = false
		if libre:
			return r
	return Rect2i(Vector2i(-1, -1), dims)


## Le nombre de lits d'un plan.
func _lits_du_plan(plan: Array, meubles: Dictionary) -> int:
	var n := 0
	for ligne in plan:
		for x in str(ligne).length():
			var c: String = str(ligne)[x]
			if meubles.has(c) and str(meubles[c]).begins_with("lit"):
				n += 1
	return n


## Une parcelle libre le long d'une rue, façade sur la rue, du centre vers les bords, la rue principale avant les
## parallèles ; (-1,-1) s'il n'y en a plus. `sens` : le côté vers lequel la porte regarde — « sud » : le bâtiment
## est au nord d'une rue est-ouest, etc.
func _parcelle(e: Dictionary, sens: String, w: int, h: int, centre: Vector2i, larg: int, curseurs: Dictionary, pris: Array[Rect2i], rues_h: Array[int], rues_v: Array[int]) -> Vector2i:
	var taille: int = e.largeur
	var lignes: Array[int] = rues_h if sens in ["sud", "nord"] else rues_v
	for li in lignes.size():
		var cle := sens + str(li)
		var rue0: int = int(lignes[li]) - larg / 2
		var essais := 0
		while essais < taille / 2:
			essais += 1
			var k: int = int(curseurs.get(cle, 0))
			curseurs[cle] = k + 1
			var pas: int = (k + 1) / 2 * (1 if k % 2 == 0 else -1)   # 0, +1, −1, +2, −2… du centre vers les bords
			var origine := Vector2i(-1, -1)
			match sens:
				"sud":
					origine = Vector2i(centre.x + pas * 2 - w / 2, rue0 - 2 - h + 1)
				"nord":
					origine = Vector2i(centre.x + pas * 2 - w / 2, rue0 + larg + 1)
				"est":
					origine = Vector2i(rue0 - 2 - w + 1, centre.y + pas * 2 - h / 2)
				"ouest":
					origine = Vector2i(rue0 + larg + 1, centre.y + pas * 2 - h / 2)
			var r := Rect2i(origine, Vector2i(w, h))
			if origine.x < 2 or origine.y < 2 or r.end.x > taille - 2 or r.end.y > taille - 2:
				continue
			var libre := true
			for pr in pris:
				if pr.grow(1).intersects(r):
					libre = false
					break
			if not libre:
				continue
			var mouille := false
			for y in h:
				for x in w:
					var idx := (origine.y + y) * taille + origine.x + x
					if e.eau.has(idx):
						mouille = true
			if mouille:
				continue
			return origine
	return Vector2i(-1, -1)

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
	var info := {"id": bid, "origine": origine, "porte": origine, "lits": [], "rect": Rect2i(origine, Vector2i(str(plan[0]).length(), plan.size()))}
	var poste_c := str(bat.get("poste", ""))
	var stations: Dictionary = bat.get("stations", {})
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
			if c == poste_c and not poste_c.is_empty():
				info["poste"] = p   # la case de travail du résident (Villes B1)
			if c == "#":
				e.murs[i] = str(palette.mur)
				e.sol.erase(i)
			elif c == "P":
				e.portes[i] = true
				info.porte = p
			elif stations.has(c):   # une station de l'atelier, celle du quartier si le préfab la laisse vide
				var sid := str(stations[c]) if not str(stations[c]).is_empty() else str(bat.get("station_id", ""))
				if not sid.is_empty() and GameData.catalogues.stations.has(sid):
					if not e.has("stations"):
						e["stations"] = {}
					e.stations[i] = sid
					info["poste"] = p
			elif meubles.has(c):
				e.meubles[i] = str(meubles[c])
				if str(meubles[c]).begins_with("lit"):
					info.lits.append(p)
	if info.has("poste"):   # on ne se tient pas sur l'étal ni sur l'enclume : la case de travail est une case de sol à côté
		var pl: Vector2i = info.poste - origine
		var libre := Vector2i(-1, -1)
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			var q: Vector2i = pl + d
			if q.y >= 0 and q.y < plan.size() and q.x >= 0 and q.x < str(plan[q.y]).length() and str(plan[q.y])[q.x] == ".":
				libre = origine + q
				break
		if libre == Vector2i(-1, -1):
			info.erase("poste")
		else:
			info.poste = libre
	if not info.has("poste"):   # sans case de travail nommée : la porte
		info["poste"] = info.porte
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
