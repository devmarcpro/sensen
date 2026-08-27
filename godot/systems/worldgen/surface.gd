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
var rng := RandomNumberGenerator.new()


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


## La valeur d'une couche en un point du monde, normalisée 0..1.
func valeur(nom: String, x: int, y: int) -> float:
	var n: FastNoiseLite = bruits[nom]
	return clampf((n.get_noise_2d(float(x), float(y)) + 1.0) * 0.5, 0.0, 1.0)


## Les 8 couches en un point.
func couches_a(x: int, y: int) -> Dictionary:
	var v := {}
	for nom in bruits.keys():
		v[nom] = valeur(nom, x, y)
	return v


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
func generer_cellule(cx: int, cy: int, camp: Dictionary = {}) -> Dictionary:
	var taille: int = int(planete.taille_cellule)
	rng.seed = hash([graine, cx, cy, "cellule"])
	var e := {"largeur": taille, "hauteur": taille, "hauteurs": PackedByteArray(), "sol": {}, "bord": {}, "sols": {}, "filons": {},
		"arbres": {}, "rochers": {}, "cellule": Vector2i(cx, cy), "biome": "", "biomes_vus": {}, "accidents": [],
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
			if x == 0 or y == 0 or x == taille - 1 or y == taille - 1:
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
	# 2. Le relief : des accidents posés, hors de la zone d'arrivée si un camp s'y greffe.
	var reserve := Rect2i(e.entree - Vector2i(8, 8), Vector2i(24, 16)) if not camp.is_empty() else Rect2i(-1, -1, 0, 0)
	_poser_accidents(e, reserve)
	# 3. Arbres, rochers, filons selon le biome de chaque tuile et les couches vegetation / ressources.
	var mp: Dictionary = GameData.config("minerais_par_etage")
	var seuils: Array = planete.tiers_corruption
	for i in e.sol.keys():
		var x: int = i % taille
		var y: int = i / taille
		if reserve.has_point(Vector2i(x, y)):
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
	for d in [e.arbres, e.rochers, e.filons]:
		for i in d.keys():
			e.sol.erase(i)
	return e


## Les accidents de relief d'une cellule (planete.relief) : chacun un modificateur 2D paramétrique.
func _poser_accidents(e: Dictionary, reserve: Rect2i) -> void:
	var rel: Dictionary = planete.relief
	var taille: int = e.largeur
	var nb := rng.randi_range(int(rel.par_cellule[0]), int(rel.par_cellule[1]))
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
