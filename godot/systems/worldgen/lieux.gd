class_name Lieux
extends RefCounted
## LE REGISTRE DES LIEUX (ordre de travail 39 ter, pas A — 2026-09-13). Le designer : « on garde le monde en cellule juste
## pour les claim, sinon on part sur une génération plus variée avec des ruines dans le monde, des villages de toutes
## tailles, des donjons bâtiments ».
##
## **Un lieu n'est pas une cellule.** Il a une position monde et une EMPRISE (un rectangle de tuiles) : un hameau de vingt
## tuiles tient où il tombe, une ruine de dix aussi, et aucune ne s'aligne sur la grille des claims. Les lieux se posent
## par SECTEUR (`lieux.secteur_cellules` cellules de côté), à la graine, et restent à l'intérieur du leur : deux secteurs
## voisins ne se disputent jamais une tuile, et un secteur se génère sans regarder ses voisins.
##
## **Rien ne se stocke** : un secteur se recalcule de la graine, et le cache n'est qu'un cache. Les agglomérations
## existantes ne sont pas encore des lieux (pas D) ; elles sont évitées, pas remplacées.

var surface: Surface
var _cache: Dictionary = {}   # secteur → Array[Dictionary]
var _mutex := Mutex.new()


func _init(p_surface: Surface) -> void:
	surface = p_surface


static func _cfg() -> Dictionary:
	return GameData.config("lieux")


## Le secteur qui contient une tuile du monde.
static func secteur_de_tuile(p: Vector2i, taille_cellule: int) -> Vector2i:
	var cote := int(_cfg().get("secteur_cellules", 8)) * taille_cellule
	return Vector2i(floori(float(p.x) / float(cote)), floori(float(p.y) / float(cote)))


## Les lieux d'un secteur, du plus ancien tiré au plus récent — toujours les mêmes pour une graine.
func secteur(sect: Vector2i) -> Array:
	_mutex.lock()
	if _cache.has(sect):
		var deja: Array = _cache[sect]
		_mutex.unlock()
		return deja
	_mutex.unlock()
	var res := _generer(sect)
	_mutex.lock()
	_cache[sect] = res
	_mutex.unlock()
	return res


## Les lieux dont l'emprise recoupe un rectangle de tuiles (un morceau à estamper, la fenêtre, une zone de carte).
func dans(rect: Rect2i) -> Array:
	var tc := int(surface.planete.taille_cellule)
	var s0 := secteur_de_tuile(rect.position, tc)
	var s1 := secteur_de_tuile(rect.end - Vector2i.ONE, tc)
	var res: Array = []
	for sy in range(s0.y, s1.y + 1):
		for sx in range(s0.x, s1.x + 1):
			for l in secteur(Vector2i(sx, sy)):
				if (l.emprise as Rect2i).intersects(rect):
					res.append(l)
	return res


## Le lieu qui porte cet id, ou {} — l'id dit son secteur, on n'en génère qu'un.
func par_id(id: String) -> Dictionary:
	var morceaux := id.split(":")
	if morceaux.size() < 3 or morceaux[0] != "lieu":
		return {}
	var coords := morceaux[1].split(",")
	if coords.size() != 2:
		return {}
	for l in secteur(Vector2i(int(coords[0]), int(coords[1]))):
		if str(l.id) == id:
			return l
	return {}


func _generer(sect: Vector2i) -> Array:
	var cfg := _cfg()
	var tc := int(surface.planete.taille_cellule)
	var cote := int(cfg.get("secteur_cellules", 8)) * tc
	var origine := sect * cote
	var marge := int(cfg.get("marge", 6))
	var essais := int(cfg.get("essais", 24))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([surface.graine, sect.x, sect.y, "lieux"])
	var poses: Array = []
	var types: Dictionary = cfg.get("types", {})
	var noms_types: Array = types.keys()
	noms_types.sort()   # un ordre FIXE : deux exécutions doivent poser les mêmes lieux
	var n := 0
	for type_id: String in noms_types:
		var t: Dictionary = types[type_id]
		var bornes: Array = t.get("par_secteur", [0, 0])
		var voulu := rng.randi_range(int(bornes[0]), int(bornes[1]))
		for k in voulu:
			var em: Array = t.get("emprise", [10, 20])
			for essai in essais:
				var cote_l := rng.randi_range(int(em[0]), int(em[1]))
				var haut_l := rng.randi_range(int(em[0]), int(em[1]))
				var jeu := Vector2i(cote - cote_l - 2 * marge, cote - haut_l - 2 * marge)
				if jeu.x <= 0 or jeu.y <= 0:
					break
				var pos := origine + Vector2i(marge + rng.randi_range(0, jeu.x), marge + rng.randi_range(0, jeu.y))
				var rect := Rect2i(pos, Vector2i(cote_l, haut_l))
				var tirage := rng.randf()   # consommé à chaque essai, qu'il serve ou non : le flux ne dépend pas du terrain
				if not _place_libre(rect, poses, marge, tc):
					continue
				var centre := rect.get_center()
				var biome := surface.biome_a(centre.x, centre.y)
				var mult := float((t.get("biomes", {}) as Dictionary).get(biome, 1.0))
				if tirage >= clampf(mult, 0.0, 1.0) and mult < 1.0:
					continue   # un biome qui l'interdit ou le raréfie
				var sous := _tirer_sous_type(t.get("sous_types", {}), rng)
				var lieu := {"id": "lieu:%d,%d:%d" % [sect.x, sect.y, n], "type": type_id, "sous_type": sous, "emprise": rect,
					"centre": centre, "biome": biome, "graine": hash([surface.graine, "lieu", sect.x, sect.y, n])}
				var st: Variant = (t.get("sous_types", {}) as Dictionary).get(sous, 1)
				if st is Dictionary and (st as Dictionary).has("theme"):
					lieu["theme"] = str(st.theme)
				poses.append(lieu)
				n += 1
				break
	return poses


## Une place est libre si l'emprise est entièrement sur terre, loin des autres lieux, hors de toute agglomération et
## hors de la cellule du camp.
func _place_libre(rect: Rect2i, poses: Array, marge: int, tc: int) -> bool:
	var agrandi := rect.grow(marge)
	for l in poses:
		if (l.emprise as Rect2i).intersects(agrandi):
			return false
	var seuil := float(surface.planete.get("mer", {}).get("altitude", 0.30))
	for p in [rect.position, rect.end - Vector2i.ONE, Vector2i(rect.position.x, rect.end.y - 1), Vector2i(rect.end.x - 1, rect.position.y), rect.get_center()]:
		if float(surface.couches_a(p.x, p.y).get("altitude", 1.0)) < seuil:
			return false
		var c := Vector2i(floori(float(p.x) / float(tc)), floori(float(p.y) / float(tc)))
		if c == surface.cellule_camp or not surface.agglomeration_de(c).is_empty():
			return false
	return true


static func _tirer_sous_type(sous: Dictionary, rng: RandomNumberGenerator) -> String:
	var ids: Array = sous.keys()
	ids.sort()
	var total := 0.0
	for id in ids:
		var v: Variant = sous[id]
		total += float(v.get("poids", 1)) if v is Dictionary else float(v)
	var r := rng.randf() * total
	for id in ids:
		var v2: Variant = sous[id]
		r -= float(v2.get("poids", 1)) if v2 is Dictionary else float(v2)
		if r <= 0.0:
			return str(id)
	return str(ids[ids.size() - 1]) if not ids.is_empty() else ""
