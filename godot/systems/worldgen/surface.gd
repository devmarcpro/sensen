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
	for off in [Vector2i(64, 64), Vector2i(32, 32), Vector2i(96, 32), Vector2i(32, 96), Vector2i(96, 96)]:
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
		"arbres": {}, "rochers": {}, "plantes": {}, "eau": {}, "cellule": Vector2i(cx, cy), "biome": "", "biomes_vus": {}, "accidents": [],
		"entree": Vector2i(taille / 2, taille / 2), "entree_donjon": Vector2i(taille / 2 + 10, taille / 2), "coffre_depart": Vector2i(taille / 2 - 2, taille / 2),
		"pieces": [], "spawns": [], "coffres": [], "escalier": null, "boss": null, "etage": 0}
	e.hauteurs.resize(taille * taille)
	e.hauteurs.fill(H_BASE)
	var ox := cx * taille
	var oy := cy * taille
	e.biome = biome_a(ox + taille / 2, oy + taille / 2)
	# 1. Sol, biome et matériau par tuile. Les couches sont échantillonnées par bloc de PAS_BRUIT tuiles
	#    (fréquences ≤ 0,003 : rien ne varie à l'échelle de la tuile) — 16 fois moins d'appels au bruit.
	var par_tuile: Dictionary = {}
	var par_bloc: Dictionary = {}
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
				par_bloc[cle] = {"couches": v, "biome": _biome_de(v)}
			var b: String = par_bloc[cle].biome
			par_tuile[i] = cle
			e.biomes_vus[b] = true
			e.sols[i] = str(biomes.get(b, {}).get("surface_material", "terre"))
			if float(par_bloc[cle].couches.altitude) < float(planete.get("mer", {}).get("altitude", 0.30)):
				e.eau[i] = true   # la mer (Eau et liquides : une source, niveau 8/8 — statique tant que l'automate attend)
				e.hauteurs[i] = int(planete.get("mer", {}).get("hauteur", 8))
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
		var bloc: Dictionary = par_bloc[par_tuile[i]]
		var b: Dictionary = biomes.get(str(bloc.biome), {})
		var veg: float = float(bloc.couches.vegetation)
		var res: float = float(bloc.couches.ressources)
		var tire := rng.randf()
		var pose := false
		for v in b.get("vegetation", []):
			if tire < float(v.density) * veg * 2.0:
				e.arbres[i] = str(v.id)
				pose = true
				break
		if pose:
			continue
		for pl in b.get("plantes", []):
			if tire < float(pl.density) * veg * 2.0:
				e.plantes[i] = str(pl.id)
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
				reste -= 1
				if reste <= 0:
					break
			pf += [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi_range(0, 3)]
			if not _dans(pf, taille):
				break
	for d in [e.arbres, e.rochers, e.filons, e.eau]:
		for i in d.keys():
			e.sol.erase(i)
	return e   # les plantes restent du sol (franchissables) : la simulation les pose comme contenu


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
