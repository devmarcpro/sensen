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
static var chrono: Dictionary = {}   # étape de generer_cellule → ms cumulées (sonde_perf_generation : où passe une cellule)
static func _top(cle: String, t0: int) -> int:
	chrono[cle] = float(chrono.get(cle, 0.0)) + float(Time.get_ticks_usec() - t0) / 1000.0
	return Time.get_ticks_usec()

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
		var dernier_rail := Vector2i(-1, -1)
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
				dernier_rail = q
				if not e.village.is_empty() and Grille.distance(q, depart) == rayon_q and not e.village.has("quai"):
					e.village["quai"] = q   # la gare : là où le rail touche la place
		if rail and dernier_rail != Vector2i(-1, -1) and not e.village.is_empty():   # l'entrée du train : le dernier rail avant le bord
			if not e.village.has("entrees_rail"):
				e.village["entrees_rail"] = []
			e.village.entrees_rail.append(dernier_rail)


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
	return _continentalite_q(p, q, _plaques_proches(q))


## La même, quand l'appelant a DÉJÀ le point warpé et ses deux plaques (2026-09-07) : `tectonique_a` les
## recalculait après coup — deux appels de bruit et un balayage des plaques pour rien, à chaque échantillon.
func _continentalite_q(p: Vector2, q: Vector2, pp: Array) -> float:
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
	var q := _warpe(p)
	var pp := _plaques_proches(q)
	var c := _continentalite_q(p, q, pp)
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
	var t_c := Time.get_ticks_usec()
	var ox := cx * taille
	var oy := cy * taille
	e.biome = biome_a(ox + taille / 2, oy + taille / 2)
	# 1. Sol, biome et matériau par tuile. Les couches sont échantillonnées par bloc de PAS_BRUIT tuiles
	#    (fréquences ≤ 0,003 : rien ne varie à l'échelle de la tuile) — 16 fois moins d'appels au bruit.
	var par_bloc: Dictionary = {}   # la clé de bloc se recalcule (x / PAS_BRUIT) : pas de table de 16 384 entrées
	var mer_alt := float(planete.get("mer", {}).get("altitude", 0.30))   # hors boucle : 16 384 tuiles
	var mer_h := int(planete.get("mer", {}).get("hauteur", 8))
	var nb := (taille + PAS_BRUIT - 1) / PAS_BRUIT
	var noyau: RefCounted = ClassDB.instantiate(&"SensenGrille") if (noyau_actif and Grille.noyau_present()) else null   # un par cellule : la génération tourne en thread
	# Les couches des blocs : le noyau les lit toutes d'un coup (file 109). Le GDScript reste la référence.
	var lot: Dictionary = couches_blocs(noyau, taille, ox, oy, nb)
	var noms_c: Array = bruits.keys()
	for by in nb:   # les blocs d'abord, dans l'ordre où la boucle des tuiles les rencontrait (ligne par ligne)
		for bx in nb:
			var cle := Vector2i(bx, by)
			var v: Dictionary = lot.blocs[by * nb + bx]
			var b0 := str(lot.biomes[by * nb + bx])
			par_bloc[cle] = {"couches": v, "biome": b0, "sol": str(biomes.get(b0, {}).get("surface_material", "terre")),
				"mer": float(v.get("altitude", 1.0)) < mer_alt}
			e.biomes_vus[b0] = true
	_sol(e, taille, bord, par_bloc, mer_h, nb, noyau)
	t_c = _top("cellule.sol", t_c)
	# 2. Le relief : des accidents posés, hors de la zone d'arrivée si un camp s'y greffe.
	var reserve := Rect2i(e.entree - Vector2i(8, 8), Vector2i(24, 16)) if not camp.is_empty() else Rect2i(-1, -1, 0, 0)
	_poser_accidents(e, reserve, rng)
	t_c = _top("cellule.relief", t_c)
	# 3. Arbres, rochers, filons selon le biome de chaque tuile et les couches vegetation / ressources.
	# Le sol suit la vocation de la ville qui s'y trouve (Villes, 2026-09-07) : une cité minière doit avoir du minerai
	# sous les pieds, sinon elle n'a ni mine, ni mineur, et ses ateliers travaillent le vide.
	var f_seuil := float(planete.filons.seuil)
	var f_dens := float(planete.filons.densite)
	var agglo_v := agglomeration_de(Vector2i(cx, cy)) if camp.is_empty() else {}
	if not agglo_v.is_empty():
		var fv: Dictionary = GameData.config("villes").get("vocations", {}).get("liste", {}).get(str(agglo_v.get("vocation", "")), {}).get("filons", {})
		if not fv.is_empty():
			f_seuil *= float(fv.get("seuil_mult", 1.0))
			f_dens *= float(fv.get("densite_mult", 1.0))
	_vegetation(e, taille, par_bloc, reserve, rng, nb, noyau, f_seuil, f_dens)
	var mp: Dictionary = GameData.config("minerais_par_etage")   # les POI en ont encore besoin (filon majeur)
	var seuils: Array = planete.tiers_corruption
	t_c = _top("cellule.vegetation", t_c)
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
	t_c = _top("cellule.poi", t_c)
	var agglo := agglomeration_de(Vector2i(cx, cy)) if camp.is_empty() else {}   # une cellule d'agglomération : un quartier (Villes B1)
	if not agglo.is_empty():
		_poser_quartier(e, Vector2i(cx, cy), rng, agglo)
	t_c = _top("cellule.village", t_c)
	_poser_route(e, Vector2i(cx, cy))
	for d in [e.arbres, e.rochers, e.filons, e.eau]:
		for i in d.keys():
			e.sol.erase(i)
	_top("cellule.routes", t_c)
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
## La vocation d'une agglomération (Villes, 2026-09-07) : ce dont elle vit, lu au centre de son emprise. Chaque
## vocation note le lieu (`villes.json → vocations`) à partir des couches du monde et de deux faits — une mer voisine,
## une route qui passe ; la mieux notée l'emporte si elle atteint le seuil, sinon la ville est « commune ».
func vocation_de(centre: Vector2i) -> String:
	var cfg: Dictionary = GameData.config("villes").get("vocations", {})
	var liste: Dictionary = cfg.get("liste", {})
	if liste.is_empty():
		return "commune"
	var t: int = int(planete.taille_cellule)
	var x := centre.x * t + t / 2
	var y := centre.y * t + t / 2
	var mer := 0.0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		if not terre_a(centre + d):
			mer = 1.0
			break
	# Les couches comptent en ÉCART À LA MÉDIANE : seul un lieu remarquable marque des points, sinon la moitié du monde
	# serait minière. Les deux faits (une mer voisine, une route) comptent tels quels.
	var faits := {
		"ressources": valeur("ressources", x, y) - 0.5,
		"vegetation": valeur("vegetation", x, y) - 0.5,
		"humidite": valeur("humidite", x, y) - 0.5,
		"altitude": valeur("altitude", x, y) - 0.5,
		"temperature": valeur("temperature", x, y) - 0.5,
		"mer": mer,
		"route": 1.0 if not route_de(centre).is_empty() else 0.0,
	}
	var meilleure := "commune"
	var note := float(cfg.get("seuil_min", 1.0))
	for vid in liste.keys():
		var n := 0.0
		var mesures: Dictionary = liste[vid].get("mesures", {})
		for m in mesures.keys():
			n += float(mesures[m]) * float(faits.get(str(m), 0.0))
		if n > note:
			note = n
			meilleure = str(vid)
	return meilleure


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
	# La vocation sert ses boutiques en premier (Villes, 2026-09-07) : une ville minière a son forgeron avant son
	# alchimiste — décisif pour un hameau qui n'en tient qu'une.
	var vocation := vocation_de(centre)
	var favorites: Array = cfg.get("vocations", {}).get("liste", {}).get(vocation, {}).get("boutiques", [])
	for k_v in range(favorites.size() - 1, -1, -1):
		var f_v := str(favorites[k_v])
		if types.has(f_v):
			types.erase(f_v)
			types.insert(0, f_v)
	# Les boutiques ne s'entassent pas toutes au centre (2026-09-07) : il en garde la moitié, le reste se répartit sur
	# les quartiers qui en veulent (le marchand d'abord, à la mesure de `boutiques_par_habitant`) — une ville a des
	# échoppes dans ses rues, pas seulement sur sa place, et son cœur reste bâtissable.
	var boutiques: Array = []
	var pris := 0
	var fb: Array = cfg.paliers[palier].boutiques
	var n_total := rng.randi_range(int(fb[0]), int(fb[1]))
	var parts_b: Array[int] = []
	parts_b.resize(quartiers.size())
	parts_b[0] = int(ceil(float(n_total) / 2.0))
	var reste_b := n_total - parts_b[0]
	var tours_b := 0
	while reste_b > 0 and tours_b < 40:
		tours_b += 1
		var avance := false
		for i in range(1, quartiers.size()):
			if reste_b <= 0:
				break
			var comp_i: Dictionary = cfg.composition[str(quartiers[i])]
			var cap: int = int(pops[i]) / maxi(1, int(comp_i.boutiques_par_habitant)) if int(comp_i.boutiques_par_habitant) > 0 else 0
			if parts_b[i] < cap:
				parts_b[i] += 1
				reste_b -= 1
				avance = true
		if not avance:
			break
	if reste_b > 0:
		parts_b[0] += reste_b   # personne d'autre n'en veut : le centre les prend
	for i in quartiers.size():
		var liste: Array = []
		for k3 in parts_b[i]:
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
	# Les halls de guilde ne tiennent pas tous sur la place (2026-09-07) : le centre en garde la moitié, les autres vont
	# aux quartiers qui en veulent (`composition.halls`) — la guilde des prospecteurs est bien mieux chez les artisans.
	var halls_q: Array = []
	for i in quartiers.size():
		halls_q.append([])
	var accueillants: Array[int] = []
	for i in quartiers.size():
		if bool(cfg.composition[str(quartiers[i])].get("halls", false)):
			accueillants.append(i)
	if accueillants.is_empty():
		accueillants.append(0)
	var au_centre := int(ceil(float(halls.size()) / 2.0)) if accueillants.size() > 1 else halls.size()
	for k5 in halls.size():
		var cible: int = 0 if k5 < au_centre else int(accueillants[1 + (k5 - au_centre) % maxi(1, accueillants.size() - 1)])
		(halls_q[cible] as Array).append(str(halls[k5]))
	var cultures: Dictionary = GameData.catalogues.name_cultures
	var culture_id := Noms.culture_pour("humain", cultures, rng)
	if not roy.is_empty() and cultures.has(str(roy.culture)):
		culture_id = str(roy.culture)
	var nom := Noms.ville(cultures.get(culture_id, {}), rng) if cultures.has(culture_id) else "Hameau"
	var fiche := {"centre": centre, "nom": nom, "culture": culture_id, "royaume": str(roy.get("id", "")), "capitale": capitale, "gouvernance": str(roy.get("government_type", "")),
		"palier": palier, "population": population, "cellules": cellules, "quartiers": quartiers, "populations": pops, "boutiques": boutiques, "halls": halls, "halls_q": halls_q, "vocation": vocation}
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
	var palette: Dictionary = _palette_village(b, agglo)
	var t_q0 := Time.get_ticks_usec()
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
	# 1. Les rues : des TRACÉS qui suivent le terrain, selon le plan de la ville (designer 2026-09-06, 23 h 45) — les
	#    routes viennent des quatre bords (au point que la cellule voisine trouve aussi) et convergent vers la place ;
	#    l'archétype ajoute ses anneaux, ses ruelles, ou sa trame droite.
	var t_q := _top("village.entete", t_q0)
	var plan_id := plan_de_ville(agglo)
	e.village["plan"] = plan_id
	var rue := {}
	_tracer_rues(e, cell, centre, plan_id, palier, palette, rue, rng)
	t_q = _top("village.rues", t_q)
	# 1 bis. Le rempart de la vieille ville : un bourg et plus fortifie son centre (2026-09-07).
	var pris: Array[Rect2i] = []
	var rayon_rempart := int(GameData.config("villes").get("remparts", {}).get("rayon", {}).get(palier, 0)) if quartier == "centre" else 0
	if rayon_rempart > 0:
		e.village["remparts"] = _poser_rempart(e, cell, centre, rayon_rempart, palette, rue)
	# 2. La place : un disque irrégulier au bout des rues (le centre, le quartier marchand, une placette au résidentiel).
	var rayon: int = int(cfg.rayon_place) if quartier == "centre" else int(cfg.rayon_placette)
	if bool(comp.place):
		pris.append(_paver_place(e, cell, centre, rayon, palette, rue))
		_meubler_place(e, cell, centre, rayon, palier, quartier, bool(agglo.get("capitale", false)), rue, rng)
	else:
		# Pas de place, mais un point d'eau quand même (Villes — les repères, 2026-09-07) : le puits se pose contre une
		# rue, au plus près du milieu du quartier — on ne va pas chercher l'eau à la cellule d'à côté.
		var mid := str(cfg.get("place", {}).get("placette", "puits"))
		var pose_p := false
		for r_p in range(1, 14):
			if pose_p:
				break
			for dy_p in range(-r_p, r_p + 1):
				for dx_p in range(-r_p, r_p + 1):
					if absi(dx_p) != r_p and absi(dy_p) != r_p:
						continue
					var q_p: Vector2i = centre + Vector2i(dx_p, dy_p)
					var i_p := q_p.y * taille + q_p.x
					if not _dans(q_p, taille) or e.murs.has(i_p) or e.eau.has(i_p) or rue.has(i_p) or e.meubles.has(i_p):
						continue
					var contre_rue := false
					for d_p in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var v_p: Vector2i = q_p + d_p
						if _dans(v_p, taille) and rue.has(v_p.y * taille + v_p.x):
							contre_rue = true
							break
					if not contre_rue or not GameData.catalogues.meubles.has(mid):
						continue
					_degager(e, i_p)
					e.meubles[i_p] = mid
					pris.append(Rect2i(q_p, Vector2i(1, 1)))   # le puits garde sa tuile : on ne bâtit pas dessus
					pose_p = true
					break
				if pose_p:
					break
	t_q = _top("village.place", t_q)
	# 3. La file des bâtiments : [préfab, boutique, guilde, station, fonction].
	var file: Array = []
	var siege_fonction := ""
	if bool(comp.siege) and palier in ["bourg", "ville", "cite"] and not str(agglo.gouvernance).is_empty():
		var siege: Dictionary = GameData.entree("governments", str(agglo.gouvernance)).get("siege", {})
		if bats.has(str(siege.get("batiment", ""))):
			siege_fonction = str(siege.get("fonction", ""))
			file.append([str(siege.batiment), "", "", "", siege_fonction])
	# L'ordre compte : ce qui est posé en premier a la place (Villes, 2026-09-07). Le siège, puis l'auberge et la
	# chapelle — une ville sans auberge ni église n'est pas une ville —, puis les halls, puis les échoppes : c'est la
	# dernière échoppe qui manquera si le cœur est plein, pas le presbytère.
	if bool(comp.auberge):
		file.append(["auberge", "", "", "", ""])
	if bool(comp.chapelle) and not (siege_fonction == "pretre"):
		file.append(["chapelle", "", "", "", ""])
	# Halls et échoppes en alternance : si le cœur se remplit, la ville garde au moins une guilde ET un marché, au lieu
	# de toutes ses guildes et aucune boutique.
	var halls_f: Array = agglo.get("halls_q", []).get(int(agglo.index)) if int(agglo.index) < agglo.get("halls_q", []).size() else (agglo.halls if bool(comp.halls) else [])
	var boutiques_f: Array = agglo.boutiques[int(agglo.index)]
	for k_hb in maxi(halls_f.size(), boutiques_f.size()):
		if k_hb < boutiques_f.size():
			file.append(["echoppe", str(boutiques_f[k_hb]), "", "", ""])
		if k_hb < halls_f.size():
			file.append(["hall", "", str(halls_f[k_hb]), "", ""])
	if bool(comp.get("ecurie", false)) and bats.has("ecurie"):   # le maquignon vend des montures (Villes B4)
		file.append(["ecurie", "", "", "", ""])
	# La vocation de la ville (Villes, 2026-09-07) : elle bâtit plus d'ateliers, plus de champs, un comptoir au port.
	var voc: Dictionary = cfg.get("vocations", {}).get("liste", {}).get(str(agglo.get("vocation", "commune")), {})
	# Le moulin (Villes — les repères, 2026-09-07) : là où il y a du grain à moudre, près des champs.
	var mou: Dictionary = cfg.get("reperes", {}).get("moulin", {})
	if bats.has(str(mou.get("prefab", ""))) and (quartier in mou.get("quartiers", []) or str(agglo.get("vocation", "")) in mou.get("vocations", [])):
		file.append([str(mou.prefab), "", "", "", ""])
	if quartier == "centre":
		for pid_v in voc.get("prefabs", []):
			if bats.has(str(pid_v)):
				file.append([str(pid_v), "", "", "", ""])
	var stations: Array = cfg.stations_ateliers.duplicate()
	var n_ateliers: int = pop / maxi(1, int(comp.ateliers_par_habitant)) if int(comp.ateliers_par_habitant) > 0 else 0
	n_ateliers = int(round(float(n_ateliers) * float(voc.get("ateliers_mult", 1.0))))
	for k in n_ateliers:
		file.append(["atelier", "", "", str(stations[(k + rng.randi_range(0, stations.size() - 1)) % stations.size()]), ""])
	for k in int(comp.entrepots):
		file.append(["entrepot", "", "", "", ""])
	# Les logements : autant de lits que d'habitants, les fonctionnels comptés.
	var lits := 0
	for f in file:
		lits += _lits_du_prefab(bats[str(f[0])])
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
		lits += _lits_du_prefab(bats[bid])
	t_q = _top("village.file", t_q)
	# 4. Les parcelles SUR LA RUE : la porte du bâtiment donne sur une tuile de rue, du centre vers les bords.
	var cotes := ["sud", "nord", "est", "ouest"]
	var lots := {}   # index de tuile → true : les emprises des bâtiments (les zones de récolte les évitent)
	var residentiel: Dictionary = {}   # tuiles du périmètre résidentiel (les logements et une marge)
	# La carte d'occupation : l'eau, les murs (rempart compris), les rues et la place — puis chaque emprise posée.
	var occupe := PackedByteArray()
	occupe.resize(taille * taille)
	for i in e.eau.keys():
		occupe[int(i)] = 1
	for i in e.murs.keys():
		occupe[int(i)] = 1
	for i in rue.keys():
		occupe[int(i)] = 1
	for pr in pris:
		_occuper(occupe, taille, pr, 1)
	# Les tuiles du quartier, du centre vers les bords : une spirale carrée, sans tri (trier 3 600 tuiles par un
	# comparateur GDScript coûtait plus cher que tout le reste de la pose). Les rues en sont extraites au passage.
	var tuiles_triees: Array = []
	var rues_triees: Array = []
	var garder := func(q: Vector2i) -> void:
		if q.x < 2 or q.y < 2 or q.x >= taille - 2 or q.y >= taille - 2:
			return
		var i := q.y * taille + q.x
		tuiles_triees.append(i)
		if rue.has(i):
			rues_triees.append(i)
	garder.call(centre)
	for r in range(1, taille):
		for dx in range(-r, r + 1):   # les deux côtés horizontaux de l'anneau
			garder.call(centre + Vector2i(dx, -r))
			garder.call(centre + Vector2i(dx, r))
		for dy in range(-r + 1, r):   # les deux côtés verticaux, sans les coins déjà pris
			garder.call(centre + Vector2i(-r, dy))
			garder.call(centre + Vector2i(r, dy))
	var essais_max: int = int(cfg.get("plans", {}).get("essais_parcelle", 600))
	var curseur_rue: Array = [0]
	var curseur_terrain_f: Array = [0]
	# Un balayage complet qui n'a rien trouvé pour une taille donnée n'en trouvera pas davantage plus tard (le quartier
	# ne fait que se remplir) : on s'en souvient, sinon six échoppes de la même taille rebalaient le quartier six fois.
	var sans_place := {}
	for k in file.size():
		var bid: String = str(file[k][0])
		var bat: Dictionary = bats[bid]
		var pose := false
		for essai in 8:   # quatre orientations sur la rue, puis les quatre mêmes sur un terrain avec sa ruelle : un plan
			# transposé (est/ouest) tient là où le plan droit ne tient pas — n'en essayer qu'une, c'était perdre le marché
			var sens: String = cotes[(k + essai) % 4]
			var plan := _orienter(bat.plan, sens)
			var w: int = str(plan[0]).length()
			var h: int = plan.size()
			var origine := Vector2i(-1, -1)
			# Les trois premiers essais de chaque genre sont bornés (le cas courant, celui qui doit rester rapide) ; le
			# quatrième balaie TOUT — sans quoi un bâtiment ne trouve jamais sa place quand le cœur est plein, et la
			# ville perd son marché (mesuré : le château, les halls et les six échoppes disparaissaient).
			var cle_taille := "%s_%dx%d" % ["rue" if essai < 4 else "sol", w, h]
			var complet := essai == 3 or essai == 7
			if complet and sans_place.has(cle_taille):
				continue
			if essai < 4:
				origine = _parcelle_sur_rue(e, sens, plan, occupe, rues_triees, essais_max if not complet else rues_triees.size(), curseur_rue)
			else:
				origine = _terrain_ruelle(e, cell, plan, sens, occupe, taille, tuiles_triees, rue, palette, rues_triees, curseur_terrain_f, 900 if not complet else 0)
			if origine == Vector2i(-2, -2):
				sans_place[cle_taille] = true   # le quartier n'a plus un terrain de cette taille : les suivants non plus
				continue
			if complet and origine == Vector2i(-1, -1):
				sans_place[cle_taille] = true
			if origine == Vector2i(-1, -1):
				continue
			var r := Rect2i(origine, Vector2i(w, h))
			pris.append(r)
			_occuper(occupe, taille, r, 1)
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
			var manques: Array = e.village.get("non_poses", [])
			manques.append(bid)
			e.village["non_poses"] = manques
			continue
	t_q = _top("village.parcelles", t_q)
	# 4 bis. Le rattrapage des lits (2026-09-06) : sur des rues tracées, un logement peut ne pas trouver sa façade —
	# la ville manquerait de lits pour ses habitants. On repose des logements, du plus petit au plus grand, tant qu'il
	# reste des gens à loger et qu'une place se trouve ; trois échecs de suite arrêtent (le quartier est plein).
	var lits_poses := 0
	for bat_p in e.village.batiments:
		lits_poses += (bat_p.lits as Array).size()
	var petits: Array = logements.duplicate()
	petits.sort_custom(func(a: Variant, b: Variant) -> bool:
		return _lits_du_prefab(bats[str(a)]) < _lits_du_prefab(bats[str(b)]) if bats.has(str(a)) and bats.has(str(b)) else false)
	var echecs := 0
	var tours := 0
	var facades_epuisees := false   # une fois les façades prises, elles le restent : on ne les recherche plus (le rattrapage coûtait 109 ms)
	var curseur_terrain: Array = curseur_terrain_f   # le même curseur que la file : on ne rebalaie pas le cœur déjà bâti
	while lits_poses < pop and echecs < 10 and tours < 90:
		tours += 1
		var bid_r := str(petits[tours % petits.size()])
		if not bats.has(bid_r):
			continue
		var pose_r := false
		for essai_r in (0 if facades_epuisees else 2):   # deux orientations sur la rue ; au-delà, la ruelle est plus sûre
			var sens_r: String = cotes[(tours + essai_r) % 4]
			var plan_r := _orienter(bats[bid_r].plan, sens_r)
			var origine_r := _parcelle_sur_rue(e, sens_r, plan_r, occupe, rues_triees, essais_max * 3, curseur_rue)
			if origine_r == Vector2i(-1, -1):
				continue
			var r_r := Rect2i(origine_r, Vector2i(str(plan_r[0]).length(), plan_r.size()))
			pris.append(r_r)
			_occuper(occupe, taille, r_r, 1)
			var b_r: Dictionary = bats[bid_r].duplicate()
			b_r.plan = plan_r
			_poser_batiment(e, b_r, origine_r, palette, bid_r)
			var info_r: Dictionary = e.village.batiments.back()
			info_r["rect"] = r_r
			info_r["boutique"] = ""
			info_r["guilde"] = ""
			info_r["station"] = ""
			info_r["fonction"] = ""
			for y in range(-3, r_r.size.y + 3):
				for x in range(-3, r_r.size.x + 3):
					var q_r := origine_r + Vector2i(x, y)
					if _dans(q_r, taille):
						residentiel[q_r] = true
			for y in r_r.size.y:
				for x in r_r.size.x:
					lots[(origine_r.y + y) * taille + origine_r.x + x] = true
			var dir_r: Vector2i = {"sud": Vector2i(0, 1), "nord": Vector2i(0, -1), "est": Vector2i(1, 0), "ouest": Vector2i(-1, 0)}[sens_r]
			var q3: Vector2i = info_r.porte + dir_r
			var pas_r := 0
			while pas_r < 8 and _dans(q3, taille) and not rue.has(q3.y * taille + q3.x):
				_paver(e, q3, palette, rue)
				q3 += dir_r
				pas_r += 1
			lits_poses += (info_r.lits as Array).size()
			pose_r = true
			break
		if not pose_r:   # aucune façade libre : le quartier fait pousser une ruelle jusqu'à un terrain vide et bâtit au bout
			facades_epuisees = true
			# La ruelle : on cherche un terrain, dans une orientation dont le devant de la porte est libre — sinon la
			# maison ouvrirait sur un mur (le rempart) et sa ruelle ne pourrait pas partir.
			var sens_l := "sud"
			var plan_l: Array = []
			var r_l := Rect2i(Vector2i(-1, -1), Vector2i(1, 1))
			for s_l in cotes:
				var pl_l := _orienter(bats[bid_r].plan, str(s_l))
				var dims_l := Vector2i(str(pl_l[0]).length(), pl_l.size())
				var cle_l := "sol_%dx%d" % [dims_l.x, dims_l.y]
				if sans_place.has(cle_l):
					continue   # ce gabarit n'a plus de place dans le quartier : inutile de rebalayer
				var rr_l := _terrain_libre(occupe, taille, dims_l, tuiles_triees, 0, 0, curseur_terrain)
				if rr_l.position == Vector2i(-1, -1):
					sans_place[cle_l] = true
				if rr_l.position == Vector2i(-1, -1):
					continue
				var porte_p := _porte_du_plan(pl_l)
				if porte_p == Vector2i(-1, -1):
					porte_p = Vector2i(dims_l.x / 2, dims_l.y - 1)
				var dev: Vector2i = rr_l.position + porte_p + {"sud": Vector2i(0, 1), "nord": Vector2i(0, -1), "est": Vector2i(1, 0), "ouest": Vector2i(-1, 0)}[str(s_l)]
				if not _dans(dev, taille) or e.murs.has(dev.y * taille + dev.x) or e.eau.has(dev.y * taille + dev.x):
					continue
				sens_l = str(s_l)
				plan_l = pl_l
				r_l = rr_l
				break
			if r_l.position != Vector2i(-1, -1):
				pris.append(r_l)
				_occuper(occupe, taille, r_l, 1)
				lots[r_l.position.y * taille + r_l.position.x] = true
				var b_l: Dictionary = bats[bid_r].duplicate()
				b_l.plan = plan_l
				_poser_batiment(e, b_l, r_l.position, palette, bid_r)
				var info_l: Dictionary = e.village.batiments.back()
				info_l["rect"] = r_l
				info_l["boutique"] = ""
				info_l["guilde"] = ""
				info_l["station"] = ""
				info_l["fonction"] = ""
				for y in range(-3, r_l.size.y + 3):
					for x in range(-3, r_l.size.x + 3):
						var q_l := r_l.position + Vector2i(x, y)
						if _dans(q_l, taille):
							residentiel[q_l] = true
				for y in r_l.size.y:
					for x in r_l.size.x:
						lots[(r_l.position.y + y) * taille + r_l.position.x + x] = true
				var porte_l: Vector2i = info_l.porte + {"sud": Vector2i(0, 1), "nord": Vector2i(0, -1), "est": Vector2i(1, 0), "ouest": Vector2i(-1, 0)}[sens_l]
				var plus_proche := centre   # la ruelle rejoint la tuile de rue la plus proche de la porte
				var d_min := 1 << 30
				for ir_l in rues_triees:
					var t_l := Vector2i(int(ir_l) % taille, int(ir_l) / taille)
					var d_l: int = (t_l - porte_l).length_squared()
					if d_l < d_min:
						d_min = d_l
						plus_proche = t_l
				_paver_trace(e, _tracer_rue(e, cell, porte_l, plus_proche, rue, 0.3, 3.0), 1, palette, rue)
				lits_poses += (info_l.lits as Array).size()
				pose_r = true
		echecs = 0 if pose_r else echecs + 1
	t_q = _top("village.rattrapage", t_q)
	# 4 ter. Le cimetière (Villes — les repères, 2026-09-07) : un enclos de tombes contre la chapelle, hors les murs
	# quand la ville est fortifiée — et il occupe du terrain, comme tout ce qui n'est pas une maison.
	var cim: Dictionary = cfg.get("reperes", {}).get("cimetiere", {})
	var n_tombes: int = int(cim.get("tombes", {}).get(palier, 0))
	var chapelle := Vector2i(-1, -1)
	for bat_c in e.village.batiments:
		if str(bat_c.id) in ["chapelle", "temple"]:
			chapelle = Vector2i(bat_c.porte)
			break
	# Une ville n'a qu'un cimetière : celui de sa chapelle, ou celui de son centre si elle n'en a pas.
	if n_tombes > 0 and (chapelle != Vector2i(-1, -1) or int(agglo.get("index", 0)) == 0):
		var dims_c := Vector2i(int(cim.taille[0]), int(cim.taille[1]))
		var r_c := Rect2i(Vector2i(-1, -1), dims_c)
		if (rayon_rempart > 0 and bool(cim.get("hors_les_murs", true))) or chapelle == Vector2i(-1, -1):
			r_c = _terrain_culture(e, occupe, taille, dims_c, tuiles_triees, false, PackedByteArray())   # depuis les bords : hors les murs
		else:
			r_c = _terrain_pres_de(occupe, taille, dims_c, tuiles_triees, chapelle, int(cim.get("distance_chapelle", 6)))
		if r_c.position != Vector2i(-1, -1):
			pris.append(r_c)
			_occuper(occupe, taille, r_c, 1)
			var libres_c: Array[Vector2i] = []
			var porte_c := Vector2i(r_c.position.x + r_c.size.x / 2, r_c.position.y + r_c.size.y - 1)   # la grille du cimetière
			for y in r_c.size.y:
				for x in r_c.size.x:
					var q := r_c.position + Vector2i(x, y)
					var i_c := q.y * taille + q.x
					_degager(e, i_c)
					lots[i_c] = true
					if q == porte_c:
						continue
					if x == 0 or y == 0 or x == r_c.size.x - 1 or y == r_c.size.y - 1:
						e.meubles[i_c] = "enclos"
					else:
						libres_c.append(q)
			for k_t in mini(n_tombes, libres_c.size()):
				e.meubles[libres_c[k_t].y * taille + libres_c[k_t].x] = "tombe"
			e.village["cimetiere"] = r_c
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
	# 5 bis. Les bras des lieux de travail (Villes, 2026-09-07) : les résidents sans métier logés le plus près prennent
	# la fonction du lieu et un poste dedans — un atelier a ses apprentis, une auberge ses servantes, une caserne ses gardes.
	var emplois: Dictionary = cfg.get("emplois", {}).get("par_batiment", {})
	for bat in e.village.batiments:
		var n_emp := int(emplois.get(str(bat.id), 0))
		if n_emp <= 0:
			continue
		var fonction_e := str(bat.get("fonction", ""))
		if fonction_e.is_empty():
			fonction_e = str(fonctions.get(str(bat.id), ""))
		if not str(bat.get("guilde", "")).is_empty():
			fonction_e = "maitre_de_guilde"
		elif not str(bat.get("boutique", "")).is_empty():
			fonction_e = "commercant"
		if fonction_e.is_empty() or fonction_e == "oisif":
			continue
		var poste_e: Vector2i = bat.get("poste", bat.porte)
		var libres: Array = []   # les sans-métier, du plus proche logé au plus loin
		for pj in e.village.pnj:
			if str(pj.get("fonction", "oisif")) == "oisif" and not pj.has("perimetre") and str(pj.get("creature", "")) in ["villageois", "fermier"]:
				libres.append(pj)
		libres.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (Vector2i(a.lit) - poste_e).length_squared() < (Vector2i(b.lit) - poste_e).length_squared())
		for k in mini(n_emp, libres.size()):
			var pj_e: Dictionary = libres[k]
			pj_e["fonction"] = fonction_e
			pj_e["poste"] = poste_e
			pj_e["batiment"] = str(bat.id)
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
	t_q = _top("village.gens", t_q)
	# 8. Les champs et l'enclos (Villes B2) : des rectangles de terre libre derrière les maisons, hors rues.
	var per: Array = e.village.territoire.perimetres
	var tags_b: Array = b.get("tags", [])
	var ch: Dictionary = cfg.get("champs", {})
	e.village["champs"] = []
	e.village["betes"] = []
	var n_champs := 0
	if quartier in ch.get("quartiers", []):
		n_champs = pop / maxi(1, int(ch.par_habitant if quartier == "agricole" else ch.get("par_habitant_hors_agricole", 20)))
		n_champs = int(round(float(n_champs) * float(voc.get("champs_mult", 1.0))))
	var liste_c: Array = _liste_par_biome(ch.get("cultures_par_biome", {}), tags_b)
	var carte_eau := _carte_pres_eau(e, taille, int(ch.get("irrigation", {}).get("distance", 3))) if not e.eau.is_empty() else PackedByteArray()
	for k in n_champs:
		if liste_c.is_empty():
			break
		var r := _terrain_culture(e, occupe, taille, Vector2i(int(ch.taille[0]), int(ch.taille[1])), tuiles_triees, true, carte_eau)
		if r.position == Vector2i(-1, -1):
			break
		pris.append(r)
		_occuper(occupe, taille, r, 1)
		var tuiles_c: Array = []
		for y in r.size.y:
			for x in r.size.x:
				var q := r.position + Vector2i(x, y)
				var i := q.y * taille + q.x
				_degager(e, i)
				lots[i] = true
				tuiles_c.append(q)
		var plante := str(liste_c[(k + rng.randi_range(0, liste_c.size() - 1)) % liste_c.size()])
		# Le champ garde TOUTES les cultures de son biome (Agriculture et élevage, 2026-09-06) : la rotation y puise à
		# chaque semaille, selon la saison ; `plante` reste la culture de départ, celle qu'on voit à la première visite.
		e.village.champs.append({"rect": r, "plante": plante, "tuiles": tuiles_c, "cultures": liste_c.duplicate()})
		per.append({"type": "champs", "tuiles": tuiles_c, "plante": plante, "cultures": liste_c.duplicate()})
		var n_f := 0   # deux fermiers du quartier (ou deux oisifs qui le deviennent) y travaillent
		for pj in e.village.pnj:
			if n_f >= int(ch.get("fermiers_par_champ", 2)):
				break
			if not pj.has("perimetre") and str(pj.get("fonction", "oisif")) in ["fermier", "oisif"] and str(pj.get("creature", "")) in ["villageois", "fermier"]:
				pj["fonction"] = "fermier"
				pj["perimetre"] = per.size() - 1
				n_f += 1
	# Le verger (Agriculture et élevage, 2026-09-07) : des buissons qu'on plante une fois et qu'on cueille des années —
	# ni rotation ni jachère. Il se pose aux abords comme un champ, sans la préférence pour l'eau.
	var vg: Dictionary = cfg.get("vergers", {})
	var n_vergers: int = int(vg.get("par_quartier", {}).get(quartier, 0))
	if quartier == "centre" and palier in vg.get("paliers_sans_centre", []):
		n_vergers = 0   # le cœur d'un bourg et plus est trop bâti : ses vergers sont dans ses autres quartiers
	if n_vergers > 0:
		n_vergers += int(vg.get("vocations_bonus", {}).get(str(agglo.get("vocation", "")), 0))
	var especes_v: Array = _liste_par_biome(vg.get("especes_par_biome", {}), tags_b)
	for k in n_vergers:
		if especes_v.is_empty():
			break
		var r := _terrain_culture(e, occupe, taille, Vector2i(int(vg.taille[0]), int(vg.taille[1])), tuiles_triees, false, PackedByteArray())
		if r.position == Vector2i(-1, -1):
			break
		pris.append(r)
		_occuper(occupe, taille, r, 1)
		var tuiles_v: Array = []
		for y in r.size.y:
			for x in r.size.x:
				var q := r.position + Vector2i(x, y)
				var i_v := q.y * taille + q.x
				_degager(e, i_v)
				lots[i_v] = true
				tuiles_v.append(q)
		var espece := str(especes_v[(k + rng.randi_range(0, especes_v.size() - 1)) % especes_v.size()])
		e.village.champs.append({"rect": r, "plante": espece, "tuiles": tuiles_v, "cultures": [espece], "verger": true})
		per.append({"type": "champs", "tuiles": tuiles_v, "plante": espece, "cultures": [espece], "verger": true,
			"contenu": str(vg.get("contenu", "verger")), "contenu_mur": str(vg.get("contenu_mur", "verger_mur"))})
		var n_v := 0   # un cueilleur : un verger demande moins de bras qu'un champ
		for pj in e.village.pnj:
			if n_v >= 1:
				break
			if not pj.has("perimetre") and str(pj.get("fonction", "oisif")) in ["fermier", "oisif"] and str(pj.get("creature", "")) in ["villageois", "fermier"]:
				pj["fonction"] = "fermier"
				pj["perimetre"] = per.size() - 1
				n_v += 1
	var en: Dictionary = cfg.get("enclos", {})
	var especes: Array = _liste_par_biome(en.get("especes_par_biome", {}), tags_b)
	var n_enclos: int = int(en.get("par_quartier", {}).get(quartier, 0))
	if quartier == "centre" and palier in en.get("paliers_sans_centre", []):
		n_enclos = 0   # le cœur d'un bourg et plus est trop bâti : ses bêtes sont dans ses quartiers agricoles
	if n_enclos > 0 or quartier == "agricole":
		n_enclos += int(voc.get("enclos_bonus", 0))   # une ville pastorale a ses parcs à bêtes, pas ses champs
	for k in n_enclos:
		if especes.is_empty():
			break
		var r := _terrain_culture(e, occupe, taille, Vector2i(int(en.taille[0]), int(en.taille[1])), tuiles_triees, false, PackedByteArray())
		if r.position == Vector2i(-1, -1):
			break
		pris.append(r)
		_occuper(occupe, taille, r, 1)
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
	t_q = _top("village.champs", t_q)
	e.village["rues"] = rue.keys()   # les tuiles de rue du quartier (le test du plan, et ce qui suivra les routes)
	var t_fin := Time.get_ticks_usec()
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
	var zones_q: Array = (comp.zones as Array).duplicate()
	for z_v in voc.get("zones", []):   # une ville forestière coupe du bois même là où la composition n'en prévoit pas
		if not zones_q.has(str(z_v)):
			zones_q.append(str(z_v))
	for z in zones_q:
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
			# Les résidents sans métier deviennent ses ouvriers (bûcheron, mineur, herboriste), à la mesure de la zone.
			var fonction_z := str(GameData.config("combat_rules").royaume.perimetres.types[str(z)].fonction)
			var emp: Dictionary = cfg.get("emplois", {})
			var max_ouvriers: int = clampi(tuiles_z.size() / maxi(1, int(emp.get("ouvriers_par_tuiles", 8))), 1, int(emp.get("ouvriers_max", 6)))
			var n_ouvriers := 0
			for pj in e.village.pnj:
				if n_ouvriers >= max_ouvriers:
					break
				if str(pj.get("fonction", "oisif")) == "oisif" and str(pj.get("creature", "")) == "villageois":
					pj["fonction"] = fonction_z
					pj["perimetre"] = per.size() - 1
					n_ouvriers += 1
	_top("village.territoire", t_fin)


## La liste d'une table par tag de biome (`_defaut` sinon).

func _liste_par_biome(table: Dictionary, tags: Array) -> Array:
	for t in tags:
		if table.has(str(t)):
			return table[str(t)]
	return table.get("_defaut", [])


## Un rectangle de terre libre (ni rue, ni parcelle prise, ni eau), tiré au sort ; position (-1,-1) s'il n'y en a pas.
func _rectangle_libre(e: Dictionary, dims: Vector2i, pris: Array[Rect2i], rue: Dictionary, rng: RandomNumberGenerator, essais: int = 80) -> Rect2i:
	var taille: int = e.largeur
	for essai in essais:
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


## Le nombre de lits d'un préfab : son plan et ses étages (les couches Z, 2026-09-06).
func _lits_du_prefab(bat: Dictionary) -> int:
	var n := _lits_du_plan(bat.plan, bat.meubles)
	for plan_z in bat.get("etages", []):
		n += _lits_du_plan(plan_z, bat.meubles)
	return n


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


## La palette d'un village (Villes, designer 2026-09-06) : le bois parmi les essences du biome, la pierre parmi ses roches,
## le toit et le sol selon le palier et les tags du biome — tirés à la graine de l'agglomération, la même pour tous ses
## quartiers. `mur` est ce dont la simulation fait le mur d'une tuile : le bois, ou la pierre si le village n'en a pas.
func _palette_village(b: Dictionary, agglo: Dictionary) -> Dictionary:
	var m: Dictionary = GameData.config("villes").get("materiaux", {})
	if m.is_empty():   # sans bloc materiaux : la palette du biome, comme avant
		var p: Dictionary = b.get("village_palette", {"mur": "chene", "toit": "chaume_tresse", "sol": "calcaire"}).duplicate()
		p["pierre"] = str(p.get("sol", "pierre"))
		p["bois"] = str(p.get("mur", "chene"))
		return p
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, str(agglo.get("nom", "")), Vector2i(agglo.get("centre", Vector2i.ZERO)), "palette"])
	var bois := _tirer_dans_liste(b.get("vegetation", []), rng)
	var pierre := _tirer_dans_liste(b.get("rochers", []), rng)
	if pierre.is_empty():
		pierre = str(m.get("pierre_sans_roche", "brique")) if b.has("rochers") else str(m.get("pierre_defaut", "pierre"))
	if not GameData.catalogues.materials.has(bois):
		bois = ""
	if not GameData.catalogues.materials.has(pierre):
		pierre = str(m.get("pierre_defaut", "pierre"))
	var palier := str(agglo.get("palier", "hameau"))
	var toit := str(m.get("toit_par_palier", {}).get(palier, "chaume_tresse"))
	for tag in b.get("tags", []):
		if m.get("toit_par_tag", {}).has(str(tag)):
			toit = str(m.toit_par_tag[str(tag)])
			break
	var sol := str(m.get("sol_par_palier", {}).get(palier, ""))
	if sol.is_empty() or not GameData.catalogues.materials.has(sol):
		sol = pierre
	return {"pierre": pierre, "bois": bois, "toit": toit, "sol": sol, "mur": bois if not bois.is_empty() else pierre}


## Un id tiré dans une liste {id, density} au poids des densités ; "" si la liste est vide.
static func _tirer_dans_liste(liste: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for v in liste:
		total += float(v.get("density", 1.0))
	if liste.is_empty() or total <= 0.0:
		return ""
	var r := rng.randf() * total
	for v in liste:
		r -= float(v.get("density", 1.0))
		if r <= 0.0:
			return str(v.id)
	return str(liste.back().id)


## Pose un bâtiment préfab : murs de la palette, sol, porte, meubles ; note ses lits.
func _poser_batiment(e: Dictionary, bat: Dictionary, origine: Vector2i, palette: Dictionary, bid: String) -> void:
	var taille: int = e.largeur
	var plan: Array = bat.plan
	var meubles: Dictionary = bat.meubles
	var info := {"id": bid, "origine": origine, "porte": origine, "lits": [], "rect": Rect2i(origine, Vector2i(str(plan[0]).length(), plan.size())),
		"niveaux": 1 + bat.get("etages", []).size(), "toit": str(palette.get("toit", "chaume_tresse")), "mur": str(palette.get("mur", "chene")),   # le dessin des façades et du toit (Villes, 2026-09-06)
		"pierre": str(palette.get("pierre", palette.get("sol", "pierre"))), "bois": str(palette.get("bois", "")), "sol": str(palette.get("sol", "calcaire"))}   # les blocs de matériaux (designer, 13 h)
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
				if c == "^":
					info["escalier"] = p   # l'escalier qui monte : l'étage se charge quand on y marche (99)
	# Les lits des étages (les couches Z, 2026-09-06) : à leur tuile de l'étage z — la position locale porte z × BANDE_Z,
	# Monde.pos_monde la garde ; le résident y dort, y naît, y rentre par l'escalier.
	var etages: Array = bat.get("etages", [])
	for z in etages.size():
		var plan_z: Array = etages[z]
		for y in plan_z.size():
			var ligne_z: String = str(plan_z[y])
			for x in ligne_z.length():
				var cz := ligne_z[x]
				if meubles.has(cz) and str(meubles[cz]).begins_with("lit"):
					info.lits.append(Grille.en_couche(origine + Vector2i(x, y), z + 1))
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


## Les couches des nb×nb blocs d'une cellule (file 109, 2026-09-07) : le noyau lit les bruits lui-même — ce sont LES
## MÊMES objets FastNoiseLite que le GDScript, passés tels quels, donc les mêmes valeurs. Sans noyau, la boucle
## GDScript d'origine (`couches_a` par bloc). Rend {blocs: Array[Dictionary]}, dans l'ordre ligne par ligne.
func couches_blocs(noyau: RefCounted, taille: int, ox: int, oy: int, nb: int) -> Dictionary:
	var blocs: Array = []
	if noyau == null or not noyau.has_method("couches_cellule"):
		var noms_b: Array = []
		for by in nb:
			for bx in nb:
				var v0 := couches_a(ox + bx * PAS_BRUIT + PAS_BRUIT / 2, oy + by * PAS_BRUIT + PAS_BRUIT / 2)
				blocs.append(v0)
				noms_b.append(_biome_de(v0))
		return {"blocs": blocs, "biomes": noms_b}
	var noms: Array = bruits.keys()
	var liste_b: Array = []
	for nom in noms:
		liste_b.append(bruits[nom])
	var centres := PackedVector2Array()
	var continentales := PackedByteArray()
	for pl in plaques:
		centres.append(pl.centre)
		continentales.append(1 if bool(pl.continentale) else 0)
	var chauds := PackedVector2Array()
	for pc in points_chauds:
		chauds.append(pc)
	# Les biomes compilés pour le noyau : les conditions en [emplacement, min, max] et les priorités, dans l'ordre
	# des clés — à priorité égale, le premier gagne, comme dans `_biome_de`.
	var ids_b: Array = biomes.keys()
	var cond_b: Array = []
	var prio_b := PackedInt32Array()
	for id_b in ids_b:
		var liste_b2: Array = []
		for couche_b in biomes[id_b].conditions.keys():
			var f_b: Array = biomes[id_b].conditions[couche_b]
			# « altitude » et « sismique » sont AUSSI des couches de bruit, mais `couches_a` les écrase par la
			# tectonique : leurs conditions doivent lire la valeur tectonique, pas le bruit (2026-09-07).
			var slot := -1
			if str(couche_b) == "altitude":
				slot = noms.size()
			elif str(couche_b) == "sismique":
				slot = noms.size() + 1
			else:
				slot = noms.find(str(couche_b))
			liste_b2.append([slot, float(f_b[0]), float(f_b[1])])
		cond_b.append(liste_b2)
		prio_b.append(int(biomes[id_b].priority))
	var tec: Dictionary = planete.get("tectonique", {})
	var larg := float(int(planete.monde_cellules) * int(planete.taille_cellule))
	var r: Dictionary = noyau.couches_cellule(taille, PAS_BRUIT, ox, oy, liste_b, warp, conti, cote, ridged, centres, continentales, chauds, {
		"seuil_mer": seuil_mer, "suture_tuiles": float(tec.get("suture_tuiles", 6000.0)), "bordure_tuiles": float(tec.get("bordure_tuiles", 20000.0)),
		"warp_amplitude": float(tec.get("warp_amplitude", 6000.0)), "cote_amplitude": float(tec.get("cote_amplitude", 0.0)),
		"cote_fenetre": float(tec.get("cote_fenetre", 0.35)), "point_chaud_rayon": float(tec.get("point_chaud_rayon", 9000.0)),
		"ocean_bord": float(tec.get("ocean_bord", 0.10)), "largeur": larg, "hauteur": larg * float(planete.get("monde_ratio", 1.0)),
	}, cond_b, prio_b)
	var vals: PackedFloat64Array = r.couches
	var alt: PackedFloat64Array = r.altitude
	var sis: PackedFloat64Array = r.sismique
	var n_c := noms.size()
	var idx_b: PackedInt32Array = r.get("biome", PackedInt32Array())
	var noms_biome: Array = []
	for i in nb * nb:
		var v := {}
		for k in n_c:
			v[noms[k]] = vals[i * n_c + k]
		v["altitude"] = alt[i]
		v["sismique"] = sis[i]
		blocs.append(v)
		noms_biome.append(str(ids_b[int(idx_b[i])]) if i < idx_b.size() and int(idx_b[i]) >= 0 else "")
	return {"blocs": blocs, "biomes": noms_biome}


## Le noyau C++ génère (file 109, 2026-09-06) : `noyau_actif` à false force le GDScript — la référence, que le noyau transcrit.
static var noyau_actif: bool = true


## Étape 1 d'une cellule : chaque tuile hors bord est du sol, prend le matériau de son bloc, la mer la couvre.
func _sol(e: Dictionary, taille: int, bord: bool, par_bloc: Dictionary, mer_h: int, nb: int, noyau: RefCounted) -> void:
	if noyau != null:
		var bloc_sol := PackedStringArray()
		var bloc_mer := PackedByteArray()
		bloc_sol.resize(nb * nb)
		bloc_mer.resize(nb * nb)
		for by in nb:
			for bx in nb:
				var bl: Dictionary = par_bloc[Vector2i(bx, by)]
				bloc_sol[by * nb + bx] = str(bl.sol)
				bloc_mer[by * nb + bx] = 1 if bool(bl.mer) else 0
		var r: Dictionary = noyau.sol_cellule(taille, bord, PAS_BRUIT, bloc_sol, bloc_mer, mer_h, e.hauteurs)
		e.sol = r.sol
		e.bord = r.bord
		e.sols = r.sols
		e.eau = r.eau
		e.hauteurs = r.hauteurs
		return
	_sol_gd(e, taille, bord, par_bloc, mer_h)


func _sol_gd(e: Dictionary, taille: int, bord: bool, par_bloc: Dictionary, mer_h: int) -> void:
	for y in taille:
		for x in taille:
			var i := y * taille + x
			if bord and (x == 0 or y == 0 or x == taille - 1 or y == taille - 1):
				e.bord[i] = true
				continue
			e.sol[i] = true
			var bl: Dictionary = par_bloc[Vector2i(x / PAS_BRUIT, y / PAS_BRUIT)]
			e.sols[i] = bl.sol
			if bool(bl.mer):
				e.eau[i] = true   # la mer (Eau et liquides : une source, niveau 8/8)
				e.hauteurs[i] = mer_h


## Étape 3 : arbres, plantes, cueillette, rochers et filons, un tirage par tuile de sol — le même RNG, dans le même ordre.
func _vegetation(e: Dictionary, taille: int, par_bloc: Dictionary, reserve: Rect2i, rng: RandomNumberGenerator, nb: int, noyau: RefCounted, f_seuil: float = -1.0, f_dens: float = -1.0) -> void:
	if f_seuil < 0.0:
		f_seuil = float(planete.filons.seuil)
	if f_dens < 0.0:
		f_dens = float(planete.filons.densite)
	var mp: Dictionary = GameData.config("minerais_par_etage")
	var seuils: Array = planete.tiers_corruption
	if noyau != null:
		var index_biome := {}
		var table: Array = []
		var bloc_biome := PackedInt32Array()
		var bloc_veg := PackedFloat64Array()
		var bloc_res := PackedFloat64Array()
		var bloc_danger := PackedFloat64Array()
		bloc_biome.resize(nb * nb)
		bloc_veg.resize(nb * nb)
		bloc_res.resize(nb * nb)
		bloc_danger.resize(nb * nb)
		for by in nb:
			for bx in nb:
				var bl: Dictionary = par_bloc[Vector2i(bx, by)]
				var bid := str(bl.biome)
				if not index_biome.has(bid):
					var b: Dictionary = biomes.get(bid, {})
					var comp := {"filons_mult": float(b.get("filons_mult", 1.0)), "montagne": "montagne" in b.get("tags", [])}
					for cle in ["vegetation", "plantes", "cueillette", "rochers"]:
						var liste: Array = []
						for v in b.get(cle, []):
							liste.append([str(v.id), float(v.density)])
						comp[cle] = liste
					index_biome[bid] = table.size()
					table.append(comp)
				var k := by * nb + bx
				bloc_biome[k] = int(index_biome[bid])
				bloc_veg[k] = float(bl.couches.vegetation)
				bloc_res[k] = float(bl.couches.ressources)
				bloc_danger[k] = float(bl.couches.danger)
		var tiers: Array = []
		var t := 1
		while mp.tiers.has(str(t)):
			tiers.append(PackedStringArray(mp.tiers[str(t)]))
			t += 1
		var seuils_f := PackedFloat64Array()
		for sv in seuils:
			seuils_f.append(float(sv))
		var r: Dictionary = noyau.vegetation_cellule(rng, taille, PAS_BRUIT, PackedInt32Array(e.sol.keys()), e.eau, reserve, bloc_biome, bloc_veg, bloc_res, bloc_danger,
			table, seuils_f, f_seuil, f_dens, tiers)
		for cle in ["arbres", "plantes", "cueillette", "rochers", "filons"]:
			e[cle].merge(r[cle], true)
		return
	_vegetation_gd(e, taille, par_bloc, reserve, rng, mp, seuils, f_seuil, f_dens)


func _vegetation_gd(e: Dictionary, taille: int, par_bloc: Dictionary, reserve: Rect2i, rng: RandomNumberGenerator, mp: Dictionary, seuils: Array, f_seuil: float = -1.0, f_dens: float = -1.0) -> void:
	if f_seuil < 0.0:
		f_seuil = float(planete.filons.seuil)
	if f_dens < 0.0:
		f_dens = float(planete.filons.densite)
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
		if res > f_seuil and tire < f_dens * float(b.get("filons_mult", 1.0)):
			var danger: float = float(bloc.couches.danger) * 100.0
			var tier := 1
			for k in range(1, seuils.size()):
				if danger >= float(seuils[k]) or (k == 1 and "montagne" in b.get("tags", [])):
					tier = k + 1
			var pool: Array = []
			for t in range(1, tier + 1):
				pool.append_array(mp.tiers[str(t)])
			e.filons[i] = str(pool[rng.randi_range(0, pool.size() - 1)])



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


# ---------------------------------------------------------------- le plan d'une ville (designer 2026-09-06, 23 h 30)

## Le plan d'une agglomération : un archétype tiré à SA graine (tous ses quartiers le partagent) — pondéré par le palier
## et poussé par la gouvernance du royaume (une monarchie trace des villes à la règle, une république les laisse pousser).
func plan_de_ville(agglo: Dictionary) -> String:
	var cfg: Dictionary = GameData.config("villes").get("plans", {})
	var poids: Dictionary = cfg.get("poids", {}).get(str(agglo.get("palier", "village")), {}).duplicate()
	if poids.is_empty():
		return "organique"
	for pid in cfg.get("biais_gouvernance", {}).get(str(agglo.get("gouvernance", "")), {}).keys():
		poids[pid] = float(poids.get(pid, 0.0)) + float(cfg.biais_gouvernance[str(agglo.gouvernance)][pid])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "plan", agglo.get("centre", Vector2i.ZERO), str(agglo.get("nom", ""))])
	var total := 0.0
	for pid in poids:
		total += maxf(0.0, float(poids[pid]))
	var tirage := rng.randf() * total
	for pid in poids:
		tirage -= maxf(0.0, float(poids[pid]))
		if tirage <= 0.0:
			return str(pid)
	return str(poids.keys()[0])


## Le point où une rue traverse un bord de cellule. Il est tiré à la graine de la PAIRE de cellules : les deux voisines
## trouvent le même point, et leurs rues se rejoignent sans que l'une sache ce que l'autre a fait.
func _sortie_bord(cell: Vector2i, cote: String, taille: int) -> Vector2i:
	var d: Vector2i = {"est": Vector2i(1, 0), "ouest": Vector2i(-1, 0), "sud": Vector2i(0, 1), "nord": Vector2i(0, -1)}.get(cote, Vector2i(1, 0))
	var autre := cell + d
	var a := cell
	var b := autre
	if b.x < a.x or (b.x == a.x and b.y < a.y):
		a = autre
		b = cell
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "bord_ville", a, b])
	var t := rng.randi_range(taille / 5, taille - 1 - taille / 5)
	match cote:
		"est": return Vector2i(taille - 1, t)
		"ouest": return Vector2i(0, t)
		"sud": return Vector2i(t, taille - 1)
		_: return Vector2i(t, 0)


## Le bruit d'une tuile pour la sinuosité d'une rue : déterministe, sans RNG à état — deux tracés qui passent au même
## endroit se courbent pareil, et une rue retracée est la même.
func _bruit_rue(cell: Vector2i, p: Vector2i) -> float:
	var h := hash([graine, "sinuo", cell, p])
	return float(h % 1000) / 1000.0


## Le tracé d'une rue de `depart` à `arrivee` : une marche gloutonne qui, à chaque pas, choisit parmi les trois directions
## qui rapprochent celle qui monte le moins, évite l'eau et suit une rue déjà tracée, avec un bruit de terrain qui la fait
## serpenter (`sinuosite`). Rend les tuiles du tracé. C'est ce qui remplace les axes droits : une rue épouse le relief.
func _tracer_rue(e: Dictionary, cell: Vector2i, depart: Vector2i, arrivee: Vector2i, rue: Dictionary, sinuosite: float, pente_pen: float) -> Array[Vector2i]:
	var taille: int = e.largeur
	var res: Array[Vector2i] = []
	var p := depart
	var vus := {}
	var max_pas := taille * 3
	while p != arrivee and res.size() < max_pas:
		res.append(p)
		vus[p.y * taille + p.x] = true
		var vers := Vector2(arrivee - p)
		var meilleur := Vector2i(0, 0)
		var meilleur_score := 1e18
		for d in Grille.DIRS:
			var q: Vector2i = p + d
			if not _dans(q, taille) or vus.has(q.y * taille + q.x):
				continue
			var vd := Vector2(d).normalized()
			var cap := vd.dot(vers.normalized()) if vers.length() > 0.01 else 1.0
			if cap < 0.2:
				continue   # on n'avance qu'en s'approchant : une rue ne revient pas sur ses pas
			var i := q.y * taille + q.x
			var score := float(Vector2(arrivee - q).length()) * 2.0
			score += absf(float(e.hauteurs[i]) - float(e.hauteurs[p.y * taille + p.x])) * pente_pen   # la pente coûte : la rue contourne la butte
			score += _bruit_rue(cell, q) * sinuosite * 8.0                                            # le terrain la fait serpenter
			if e.eau.has(i):
				score += 400.0        # l'eau se contourne ; s'il n'y a que ça, on la franchit (un gué)
			if rue.has(i):
				score -= 2.0          # une rue existante s'emprunte un peu : assez pour un tronc commun, pas assez pour
				                      # que deux tracés se tressent en nappe (2026-09-07 : à -6, la ville n'avait plus d'îlots)
			if e.rochers.has(i):
				score += 12.0
			if score < meilleur_score:
				meilleur_score = score
				meilleur = d
		if meilleur == Vector2i(0, 0):
			break
		p += meilleur
	res.append(arrivee if p == arrivee else p)
	return res


## Pave un tracé à sa largeur : la tuile et, selon la largeur, ses voisines — une rue de trois tuiles est un ruban.
func _paver_trace(e: Dictionary, trace: Array[Vector2i], largeur: int, palette: Dictionary, rue: Dictionary) -> void:
	for p in trace:
		_paver(e, p, palette, rue)
		if largeur >= 2:
			_paver(e, p + Vector2i(1, 0), palette, rue)
			_paver(e, p + Vector2i(0, 1), palette, rue)
		if largeur >= 3:
			_paver(e, p + Vector2i(-1, 0), palette, rue)
			_paver(e, p + Vector2i(0, -1), palette, rue)
		if largeur >= 4:
			_paver(e, p + Vector2i(1, 1), palette, rue)


## Les rues d'un quartier selon son plan (Villes, 2026-09-06) : les quatre sorties de bord d'abord (une ville est
## traversée par ses routes), puis ce que l'archétype ajoute — des anneaux autour de la place, des ruelles, ou la
## trame droite de la ville planifiée. Rend les tuiles de rue par `rue`.
func _tracer_rues(e: Dictionary, cell: Vector2i, centre: Vector2i, plan_id: String, palier: String, palette: Dictionary, rue: Dictionary, rng: RandomNumberGenerator) -> void:
	var taille: int = e.largeur
	var cfg: Dictionary = GameData.config("villes").get("plans", {})
	var lg: Dictionary = cfg.get("largeurs", {"principale": 3, "secondaire": 2, "ruelle": 1})
	var sinuosite := float(cfg.get("sinuosite", 0.55))
	var pente_pen := float(cfg.get("pente_penalite", 6.0))
	if plan_id == "grille":   # la ville tracée à la règle : la trame d'avant, mais posée sur le terrain
		var pas: int = maxi(8, taille / 5)
		var lignes: Array[int] = [centre.y]
		var colonnes: Array[int] = [centre.x]
		if palier != "hameau":
			lignes.append_array([centre.y - pas, centre.y + pas])
			colonnes.append_array([centre.x - pas, centre.x + pas])
		for yr in lignes:
			_paver_trace(e, _ligne_droite(Vector2i(0, yr), Vector2i(taille - 1, yr)), int(lg.principale) if yr == centre.y else int(lg.secondaire), palette, rue)
		for xr in colonnes:
			_paver_trace(e, _ligne_droite(Vector2i(xr, 0), Vector2i(xr, taille - 1)), int(lg.principale) if xr == centre.x else int(lg.secondaire), palette, rue)
		return
	var cotes: Array[String] = ["est", "ouest", "sud", "nord"]
	if plan_id == "rue_marchande":   # un village-rue : une seule traversée, de bord à bord, par la place
		var axe: Array[String] = ["est", "ouest"]
		if rng.randf() < 0.5:
			axe = ["sud", "nord"]
		_paver_trace(e, _tracer_rue(e, cell, _sortie_bord(cell, axe[0], taille), centre, rue, sinuosite, pente_pen), int(lg.principale), palette, rue)
		_paver_trace(e, _tracer_rue(e, cell, centre, _sortie_bord(cell, axe[1], taille), rue, sinuosite, pente_pen), int(lg.principale), palette, rue)
		var perp: Array[String] = ["sud", "nord"]
		if axe[0] != "est":
			perp = ["est", "ouest"]
		for c in perp:   # les deux autres bords rejoignent quand même la rue : une route ne s'arrête pas au champ
			_paver_trace(e, _tracer_rue(e, cell, _sortie_bord(cell, c, taille), centre, rue, sinuosite, pente_pen), int(lg.secondaire), palette, rue)
	else:   # organique et radioconcentrique : les quatre routes convergent vers la place
		for c in cotes:
			_paver_trace(e, _tracer_rue(e, cell, _sortie_bord(cell, c, taille), centre, rue, sinuosite, pente_pen), int(lg.principale), palette, rue)
	if plan_id == "radioconcentrique":   # les anneaux : une rue qui fait le tour de la place, et une plus loin
		for k in int(cfg.get("anneaux", {}).get(palier, 0)):
			var r := int(cfg.get("rayon_anneau", 9)) * (k + 1) + rng.randi_range(-2, 2)
			var precedent := Vector2i(-999, -999)
			var premier := Vector2i(-999, -999)
			for a in range(0, 360, 12):
				var ang := deg_to_rad(float(a))
				var rr := float(r) + _bruit_rue(cell, Vector2i(a, r)) * 2.5   # l'anneau n'est pas un cercle parfait
				var q := centre + Vector2i(roundi(cos(ang) * rr), roundi(sin(ang) * rr * 0.85))
				if not _dans(q, taille):
					precedent = Vector2i(-999, -999)
					continue
				if premier == Vector2i(-999, -999):
					premier = q
				if precedent != Vector2i(-999, -999):
					_paver_trace(e, _ligne_droite(precedent, q), int(lg.secondaire), palette, rue)   # la corde, pas un tracé glouton
				precedent = q
			if precedent != Vector2i(-999, -999) and premier != Vector2i(-999, -999):
				_paver_trace(e, _ligne_droite(precedent, premier), int(lg.secondaire), palette, rue)
	# Les ruelles : elles naissent d'une rue et meurent un peu plus loin — c'est ce qui fait un tissu, pas une étoile.
	var n_ruelles := int(cfg.get("ruelles", {}).get(palier, 0))
	if n_ruelles > 0 and not rue.is_empty():
		var tuiles_rue: Array = rue.keys()
		for k in n_ruelles:
			var i0: int = int(tuiles_rue[rng.randi_range(0, tuiles_rue.size() - 1)])
			@warning_ignore("integer_division")
			var depart := Vector2i(i0 % taille, i0 / taille)
			var ang2 := rng.randf() * TAU
			var lon := rng.randi_range(int(cfg.get("ruelle_longueur", [6, 16])[0]), int(cfg.get("ruelle_longueur", [6, 16])[1]))
			var fin := depart + Vector2i(roundi(cos(ang2) * lon), roundi(sin(ang2) * lon))
			fin.x = clampi(fin.x, 2, taille - 3)
			fin.y = clampi(fin.y, 2, taille - 3)
			_paver_trace(e, _tracer_rue(e, cell, depart, fin, rue, sinuosite * 1.4, pente_pen), int(lg.ruelle), palette, rue)


## Une ligne droite de tuiles (la trame de la ville planifiée).
func _ligne_droite(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	var n: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in n + 1:
		var t := float(k) / float(maxi(1, n))
		res.append(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	return res


## La place : un disque irrégulier (le bruit de la ville en mord les bords) plutôt qu'un carré — pavé, dégagé.
func _paver_place(e: Dictionary, cell: Vector2i, centre: Vector2i, rayon: int, palette: Dictionary, rue: Dictionary) -> Rect2i:
	for dy in range(-rayon - 1, rayon + 2):
		for dx in range(-rayon - 1, rayon + 2):
			var q := centre + Vector2i(dx, dy)
			var d := sqrt(float(dx * dx + dy * dy))
			if d <= float(rayon) - 1.0 + _bruit_rue(cell, q) * 2.0:
				_paver(e, q, palette, rue)
	return Rect2i(centre - Vector2i(rayon, rayon), Vector2i(2 * rayon + 1, 2 * rayon + 1))


## La position de la porte dans un plan orienté (la lettre 'P'), en tuiles depuis l'origine du plan ; (-1,-1) sans porte.
func _porte_du_plan(plan: Array) -> Vector2i:
	for y in plan.size():
		var ligne: String = str(plan[y])
		for x in ligne.length():
			if ligne[x] == "P":
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Une parcelle le long d'une rue TRACÉE (Villes, 2026-09-06) : on cherche une tuile de rue, on pose le bâtiment de
## façon que sa porte donne dessus, et l'on vérifie que l'emprise est libre, hors de l'eau, à peu près plate. Les
## candidats sont parcourus du centre vers les bords : la ville se remplit du cœur.
## `sens` dit de quel côté la porte regarde — « sud » : la rue est au sud du bâtiment.
## `occupe` : un octet par tuile — 1 là où l'on ne bâtit pas (eau, mur, rue, place, emprise déjà prise et sa marge).
## C'est ce qui rend la recherche tenable : un candidat se rejette au premier octet, sans parcourir une liste de rectangles
## (le centre d'une cité passait de 136 ms à 40). `curseur` (in/out, un tableau d'un élément) : l'index de rue où la
## dernière parcelle a été trouvée — la recherche y reprend au lieu de re-balayer le cœur déjà bâti.
func _parcelle_sur_rue(e: Dictionary, sens: String, plan: Array, occupe: PackedByteArray, rues_triees: Array, essais_max: int, curseur: Array = []) -> Vector2i:
	var taille: int = e.largeur
	var w: int = str(plan[0]).length()
	var h: int = plan.size()
	var porte := _porte_du_plan(plan)
	if porte == Vector2i(-1, -1):
		porte = Vector2i(w / 2, h - 1)
	var vers: Vector2i = {"sud": Vector2i(0, 1), "nord": Vector2i(0, -1), "est": Vector2i(1, 0), "ouest": Vector2i(-1, 0)}.get(sens, Vector2i(0, 1))
	var essais := 0
	var n_rues := rues_triees.size()
	var depart: int = int(curseur[0]) if not curseur.is_empty() else 0
	for k in n_rues:
		if essais >= essais_max:
			break
		essais += 1
		var k_rue: int = (depart + k) % n_rues
		var ir: int = int(rues_triees[k_rue])
		@warning_ignore("integer_division")
		var t_rue := Vector2i(ir % taille, ir / taille)
		var origine: Vector2i = t_rue - vers - porte   # la porte se colle à la rue : l'origine du plan s'en déduit
		if origine.x < 2 or origine.y < 2 or origine.x + w > taille - 2 or origine.y + h > taille - 2:
			continue
		# Rejet rapide : les quatre coins et le milieu d'abord — presque tous les candidats tombent là, sans parcourir
		# l'emprise entière (c'est ce qui tient le budget d'une cellule de centre : 200 ms → 40).
		var i0 := origine.y * taille + origine.x
		if occupe[i0] != 0 or occupe[i0 + w - 1] != 0 or occupe[i0 + (h - 1) * taille] != 0 or occupe[i0 + (h - 1) * taille + w - 1] != 0 or occupe[i0 + (h / 2) * taille + w / 2] != 0:
			continue
		var libre := true
		var h0 := int(e.hauteurs[i0])
		for y in h:
			var base := (origine.y + y) * taille + origine.x
			for x in w:
				var i := base + x
				if occupe[i] != 0 or absi(int(e.hauteurs[i]) - h0) > 2:   # pris, ou à cheval sur un talus
					libre = false
					break
			if not libre:
				break
		if libre:
			if not curseur.is_empty():
				curseur[0] = maxi(0, k_rue - 24)   # on revient un peu en arrière : une parcelle laisse des voisines libres
			return origine
	return Vector2i(-1, -1)


## Le premier terrain libre de `dims` dans la carte d'occupation, balayé du centre vers les bords (les tuiles sont
## déjà triées ainsi dans `ordre`). Systématique, là où un tirage au hasard rate dans un quartier fragmenté.
func _terrain_libre(occupe: PackedByteArray, taille: int, dims: Vector2i, ordre: Array, depuis: int = 0, max_candidats: int = 0, curseur: Array = []) -> Rect2i:
	var n_max: int = ordre.size() if max_candidats <= 0 else mini(max_candidats, ordre.size())
	var debut: int = int(curseur[0]) if not curseur.is_empty() else depuis
	for k in n_max:
		var k_ordre: int = (debut + k) % ordre.size()
		var i: int = int(ordre[k_ordre])
		@warning_ignore("integer_division")
		var o := Vector2i(i % taille, i / taille)
		if o.x < 2 or o.y < 2 or o.x + dims.x > taille - 2 or o.y + dims.y > taille - 2:
			continue
		var i0 := o.y * taille + o.x
		if occupe[i0] != 0 or occupe[i0 + dims.x - 1] != 0 or occupe[i0 + (dims.y - 1) * taille] != 0 or occupe[i0 + (dims.y - 1) * taille + dims.x - 1] != 0:
			continue
		var libre := true
		for y in dims.y:
			var base := (o.y + y) * taille + o.x
			for x in dims.x:
				if occupe[base + x] != 0:
					libre = false
					break
			if not libre:
				break
		if libre:
			if not curseur.is_empty():
				curseur[0] = k_ordre   # la prochaine recherche reprend là : le cœur déjà bâti ne se rebalaie pas
			return Rect2i(o, dims)
	return Rect2i(Vector2i(-1, -1), dims)


## Un terrain libre proche d'un point (Villes — les repères, 2026-09-07) : le premier de l'ordre donné qui tombe à
## `dist_max` de la cible ; à défaut, le premier terrain libre tout court — le cimetière veut la chapelle, mais il
## veut d'abord exister.
func _terrain_pres_de(occupe: PackedByteArray, taille: int, dims: Vector2i, ordre: Array, cible: Vector2i, dist_max: int) -> Rect2i:
	var premier := Rect2i(Vector2i(-1, -1), dims)
	var essais := 0
	for k in ordre.size():
		if essais > 900:
			break
		var i: int = int(ordre[k])
		@warning_ignore("integer_division")
		var o := Vector2i(i % taille, i / taille)
		if o.x < 2 or o.y < 2 or o.x + dims.x > taille - 2 or o.y + dims.y > taille - 2:
			continue
		var i0 := o.y * taille + o.x
		if occupe[i0] != 0 or occupe[i0 + dims.x - 1] != 0 or occupe[i0 + (dims.y - 1) * taille] != 0 or occupe[i0 + (dims.y - 1) * taille + dims.x - 1] != 0:
			continue
		essais += 1
		var libre := true
		for y in dims.y:
			var base := (o.y + y) * taille + o.x
			for x in dims.x:
				if occupe[base + x] != 0:
					libre = false
					break
			if not libre:
				break
		if not libre:
			continue
		var r := Rect2i(o, dims)
		if premier.position == Vector2i(-1, -1):
			premier = r
		var milieu := o + dims / 2
		if (milieu - cible).length_squared() <= dist_max * dist_max:
			return r
	return premier


## Marque une emprise (et sa marge d'une tuile) dans la carte d'occupation.
func _occuper(occupe: PackedByteArray, taille: int, r: Rect2i, marge: int = 1) -> void:
	for y in range(r.position.y - marge, r.end.y + marge):
		if y < 0 or y >= taille:
			continue
		for x in range(r.position.x - marge, r.end.x + marge):
			if x >= 0 and x < taille:
				occupe[y * taille + x] = 1


## Le rempart de la vieille ville (Villes, 2026-09-07) : un anneau irrégulier de la PIERRE du village autour de la place,
## tracé après les rues — une porte là où une rue le traverse, et les bâtiments n'y viennent pas. Rend ses tuiles.
## (Les tuiles du rempart sont des murs : `_parcelle_sur_rue` et `_rectangle_libre` les refusent déjà — inutile de les
## ajouter aux emprises prises, ce qui ferait des centaines de rectangles à tester par candidat.)
func _poser_rempart(e: Dictionary, cell: Vector2i, centre: Vector2i, rayon: int, palette: Dictionary, rue: Dictionary) -> Array[Vector2i]:
	var taille: int = e.largeur
	var res: Array[Vector2i] = []
	var cfg: Dictionary = GameData.config("villes").get("remparts", {})
	var bruit := float(cfg.get("bruit", 2.5))
	var vus := {}
	var pierre := str(palette.get("pierre", palette.get("mur", "granit")))
	for a in range(0, 3600, 4):   # un pas fin : l'anneau est continu, sans trou entre deux tuiles
		var ang := deg_to_rad(float(a) / 10.0)
		var rr := float(rayon) + _bruit_rue(cell, Vector2i(int(a) / 40, rayon)) * bruit
		var q := centre + Vector2i(roundi(cos(ang) * rr), roundi(sin(ang) * rr * 0.9))
		var i := q.y * taille + q.x
		if not _dans(q, taille) or vus.has(i):
			continue
		vus[i] = true
		if e.eau.has(i):
			continue   # le rempart s'arrête au bord de l'eau (la douve naturelle)
		_degager(e, i)
		e.hauteurs[i] = H_BASE
		if rue.has(i):   # une rue traverse : c'est une porte de ville
			e.portes[i] = true
			e.murs.erase(i)
		else:
			e.murs[i] = pierre
			e.sol.erase(i)
			rue.erase(i)
		res.append(q)
	return res


## Le mobilier de la place (Villes, 2026-09-07) : la fontaine au milieu, les torchères en couronne, les étals du marché —
## jamais sur une rue, jamais sur une emprise prise.
func _meubler_place(e: Dictionary, cell: Vector2i, centre: Vector2i, rayon: int, palier: String, quartier: String, capitale: bool, rue: Dictionary, rng: RandomNumberGenerator) -> void:
	var taille: int = e.largeur
	var cfg: Dictionary = GameData.config("villes").get("place", {})
	if cfg.is_empty():
		return
	var poser := func(q: Vector2i, mid: String) -> bool:
		var i := q.y * taille + q.x
		if mid.is_empty() or not _dans(q, taille) or e.murs.has(i) or e.meubles.has(i) or e.eau.has(i) or not GameData.catalogues.meubles.has(mid):
			return false
		_degager(e, i)
		e.meubles[i] = mid
		rue.erase(i)   # un meuble n'est pas une rue : les bâtiments ne s'y adossent pas
		return true
	# Le repère du milieu (Villes, 2026-09-07) : le bassin (ou la statue d'une capitale) sur la grande place du centre,
	# le puits sur la placette d'un quartier — et sur la place d'un hameau ou d'un village, qui n'ont pas de bassin.
	var au_centre := str(cfg.get("centre_capitale", "")) if capitale else str(cfg.get("centre", {}).get(palier, ""))
	if quartier != "centre":
		au_centre = str(cfg.get("placette", "puits"))
	poser.call(centre, au_centre)
	var cour: Dictionary = cfg.get("couronne", {})
	var n := int(cour.get("n", {}).get(palier, 0))
	for k in n:
		var ang := TAU * float(k) / float(maxi(1, n)) + rng.randf() * 0.3
		var r := float(rayon) * float(cour.get("rayon_part", 0.7))
		poser.call(centre + Vector2i(roundi(cos(ang) * r), roundi(sin(ang) * r * 0.85)), str(cour.get("meuble", "torchere")))
	if quartier == "marchand":
		var m: Dictionary = cfg.get("marchand", {})
		for k in int(m.get("n", 4)):
			var ang2 := TAU * float(k) / float(maxi(1, int(m.get("n", 4)))) + 0.4
			var r2 := float(rayon) * float(m.get("rayon_part", 0.55))
			poser.call(centre + Vector2i(roundi(cos(ang2) * r2), roundi(sin(ang2) * r2 * 0.85)), str(m.get("meuble", "etal_de_vente")))


## Un terrain de culture (Agriculture et élevage, 2026-09-07) : cherché depuis les BORDS du quartier vers le centre (la
## ville au milieu, les terres autour) et, à `dist_eau` tuiles d'une eau, préféré — c'est là que le champ sera irrigué.
## `pres_eau` false : la même recherche sans la préférence (un enclos).
## `carte_eau` : un octet par tuile, 1 à `dist_eau` d'une eau — bâti une fois par cellule (`_carte_pres_eau`), sans quoi
## chaque candidat rebalayerait son voisinage (une cellule agricole passait de 260 ms à 40).
func _terrain_culture(e: Dictionary, occupe: PackedByteArray, taille: int, dims: Vector2i, tuiles_triees: Array, pres_eau: bool, carte_eau: PackedByteArray) -> Rect2i:
	var premier := Rect2i(Vector2i(-1, -1), dims)
	var essais := 0
	var cherche_eau := pres_eau and carte_eau.size() == taille * taille
	for k in range(tuiles_triees.size() - 1, -1, -1):   # des bords vers le centre
		if essais > (250 if cherche_eau else 40):
			break
		var i: int = int(tuiles_triees[k])
		@warning_ignore("integer_division")
		var o := Vector2i(i % taille, i / taille)
		if o.x < 2 or o.y < 2 or o.x + dims.x > taille - 2 or o.y + dims.y > taille - 2:
			continue
		var i0 := o.y * taille + o.x
		if occupe[i0] != 0 or occupe[i0 + dims.x - 1] != 0 or occupe[i0 + (dims.y - 1) * taille] != 0 or occupe[i0 + (dims.y - 1) * taille + dims.x - 1] != 0:
			continue
		essais += 1
		var libre := true
		for y in dims.y:
			var base := (o.y + y) * taille + o.x
			for x in dims.x:
				if occupe[base + x] != 0:
					libre = false
					break
			if not libre:
				break
		if not libre:
			continue
		var r := Rect2i(o, dims)
		if not cherche_eau:
			return r
		if premier.position == Vector2i(-1, -1):
			premier = r   # le premier terrain venu : le repli si aucun n'est au bord de l'eau
		if true:
			for y in dims.y:
				var base2 := (o.y + y) * taille + o.x
				for x in dims.x:
					if carte_eau[base2 + x] != 0:
						return r   # une eau à portée : le champ sera irrigué
	return premier


## Les tuiles à `dist` d'une eau (un octet par tuile) : bâtie une fois, depuis les tuiles d'eau de la cellule.
func _carte_pres_eau(e: Dictionary, taille: int, dist: int) -> PackedByteArray:
	var carte := PackedByteArray()
	carte.resize(taille * taille)
	for i in e.eau.keys():
		@warning_ignore("integer_division")
		var p := Vector2i(int(i) % taille, int(i) / taille)
		for dy in range(-dist, dist + 1):
			var y := p.y + dy
			if y < 0 or y >= taille:
				continue
			for dx in range(-dist, dist + 1):
				var x := p.x + dx
				if x >= 0 and x < taille:
					carte[y * taille + x] = 1
	return carte


## Un terrain libre et la ruelle qui y mène (Villes, 2026-09-07) : quand plus aucune façade n'est libre, le quartier
## fait pousser une ruelle jusqu'à un terrain vide et l'on bâtit au bout — c'est ainsi qu'un bourg garde son marché et
## ses guildes même quand son cœur est plein. Rend l'origine du plan, ou (-1,-1) si le quartier n'a plus de place.
func _terrain_ruelle(e: Dictionary, cell: Vector2i, plan: Array, sens: String, occupe: PackedByteArray, taille: int, tuiles_triees: Array, rue: Dictionary, palette: Dictionary, rues_triees: Array, curseur: Array, max_candidats: int = 900) -> Vector2i:
	var dims := Vector2i(str(plan[0]).length(), plan.size())
	var porte := _porte_du_plan(plan)
	if porte == Vector2i(-1, -1):
		porte = Vector2i(dims.x / 2, dims.y - 1)
	var dir: Vector2i = {"sud": Vector2i(0, 1), "nord": Vector2i(0, -1), "est": Vector2i(1, 0), "ouest": Vector2i(-1, 0)}.get(sens, Vector2i(0, 1))
	# Le premier terrain venu peut avoir sa porte contre un mur : on passe au suivant (2026-09-07 — s'arrêter là, c'était
	# garer le curseur sur ce refus et déclarer le quartier plein alors qu'il gardait la moitié de ses tuiles libres).
	var local: Array = [int(curseur[0]) if not curseur.is_empty() else 0]
	for essai in 24:
		var r := _terrain_libre(occupe, taille, dims, tuiles_triees, 0, max_candidats, local)
		if r.position == Vector2i(-1, -1):
			# Un balayage COMPLET (max_candidats nul) qui ne trouve rien dit que le quartier n'a plus de terrain de cette
			# taille ; un balayage borné ne dit rien de tel — il a seulement regardé les 900 tuiles suivantes.
			return Vector2i(-2, -2) if max_candidats <= 0 else Vector2i(-1, -1)
		var devant: Vector2i = r.position + porte + dir
		if _dans(devant, taille) and not e.murs.has(devant.y * taille + devant.x) and not e.eau.has(devant.y * taille + devant.x):
			var plus_proche := devant
			var d_min := 1 << 30
			for ir in rues_triees:
				@warning_ignore("integer_division")
				var t := Vector2i(int(ir) % taille, int(ir) / taille)
				var d: int = (t - devant).length_squared()
				if d < d_min:
					d_min = d
					plus_proche = t
			_paver_trace(e, _tracer_rue(e, cell, devant, plus_proche, rue, 0.3, 3.0), 1, palette, rue)
			if not curseur.is_empty():
				curseur[0] = int(local[0])
			return r.position
		local[0] = (int(local[0]) + 1) % maxi(1, tuiles_triees.size())
	return Vector2i(-1, -1)
