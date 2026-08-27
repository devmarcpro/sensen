class_name Donjon
extends RefCounted
## Génération d'un étage de donjon par graphe, façon Daggerfall (Génération de donjon, E.29) :
## salle d'entrée à position fixe → attache libre → connecteur compatible → salle compatible →
## collision AABB → placement ; connexité par construction ; escalier vers l'étage suivant sur
## la salle la plus profonde ; boss au plus loin de l'entrée ; peuplement par le thème.
## Déterministe par seed(monde, id_donjon, étage). Les prefabs sont des grilles JSON
## (Décision — Prefabs de donjon en tuiles ; plans en caractères, voir tools/gen_dungeon_prefabs.py).

const H_BASE := 10                 # hauteur de référence d'un étage (Hauteur de terrain ±10)
const ESSAIS_MAX := 8              # essais de placement par attache (E.29, étape 2)
const MARGE := 1                   # tuiles vides gardées entre deux pièces

var salles: Dictionary
var connecteurs: Dictionary
var theme: Dictionary
var rng := RandomNumberGenerator.new()


func _init(p_salles: Dictionary, p_connecteurs: Dictionary, p_theme: Dictionary) -> void:
	salles = p_salles
	connecteurs = p_connecteurs
	theme = p_theme


## Génère un étage : {largeur, hauteur, hauteurs: PackedByteArray, murs: Dictionary(idx→true),
##  pieces: [{id, kind, rect, attaches}], entree: Vector2i, escalier: Vector2i|null, boss: Vector2i|null,
##  spawns: [{creature, pos}], graphe: {index → [voisins]}}
func generer_etage(graine: int, id_donjon: int, etage: int, nb_salles: int, dernier: bool, taille: int = 96) -> Dictionary:
	rng.seed = hash([graine, id_donjon, etage])
	var e := {"largeur": taille, "hauteur": taille, "hauteurs": PackedByteArray(), "murs": {}, "sol": {},
		"pieces": [], "entree": Vector2i.ZERO, "escalier": null, "boss": null, "spawns": [], "graphe": {}, "etage": etage}
	e.hauteurs.resize(taille * taille)
	e.hauteurs.fill(H_BASE)
	# 1. La salle d'entrée, à position fixe (sous le point d'entrée de surface).
	var entrees := _salles_par(func(s: Dictionary) -> bool: return "entree_eligible" in s.special_tags)
	var s0: Dictionary = entrees[rng.randi_range(0, entrees.size() - 1)]
	var origine := Vector2i(taille / 2 - s0.plan[0].length() / 2, taille / 2 - s0.plan.size() / 2)
	var p0 := _placer(e, s0, origine, "salle")
	e.entree = _premiere_tuile_libre(e, p0)
	e.graphe[0] = []
	# 2. Extension par graphe.
	var echecs := 0
	while _nb_salles(e) < nb_salles and echecs < ESSAIS_MAX * 4:
		var libres := _attaches_libres(e)
		if libres.is_empty():
			break
		var att: Dictionary = libres[rng.randi_range(0, libres.size() - 1)]
		if not _etendre(e, att):
			echecs += 1
	# 4. L'escalier : une attache libre de la salle la plus profonde (distance de graphe maximale).
	var distances := _distances_graphe(e)
	if not dernier:
		for idx in _pieces_par_profondeur(e, distances):
			if e.escalier != null or e.pieces[idx].kind != "salle":
				continue
			for a in e.pieces[idx].attaches:
				if a.libre and a.type == "porte":
					var att: Dictionary = a.duplicate()
					att["piece"] = idx
					if _etendre(e, att, "escalier"):
						break
		if e.escalier == null:
			# Aucune porte libre ne laisse passer un connecteur : la cage s'ouvre dans la salle la plus profonde.
			for idx in _pieces_par_profondeur(e, distances):
				if e.pieces[idx].kind == "salle":
					e.escalier = _centre_libre(e, e.pieces[idx])
					break
	# 5. La salle du boss : la plus distante de l'entrée, au dernier étage.
	if dernier:
		for idx in _pieces_par_profondeur(e, distances):
			var p: Dictionary = e.pieces[idx]
			if p.kind == "salle" and idx != 0:
				e.boss = _centre_libre(e, p)
				p["boss_room"] = true
				break
	# 6. Peuplement par le thème, modulé par la profondeur.
	_peupler(e, etage)
	return e


# ---------------------------------------------------------------- placement

func _salles_par(filtre: Callable) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for s: Dictionary in salles.values():
		if _theme_ok(s) and filtre.call(s):
			res.append(s)
	return res


func _theme_ok(s: Dictionary) -> bool:
	var themes: Array = s.get("floor_theme", [])
	return themes.is_empty() or theme.id in themes


## Pose un prefab (ses murs, ses sols, ses hauteurs) à `origine` ; retourne la pièce enregistrée.
func _placer(e: Dictionary, prefab: Dictionary, origine: Vector2i, kind: String) -> Dictionary:
	var plan: Array = prefab.plan
	var attaches: Array = []
	for y in plan.size():
		var ligne: String = plan[y]
		for x in ligne.length():
			var c := ligne[x]
			if c == " ":
				continue
			var p := origine + Vector2i(x, y)
			var idx: int = p.y * e.largeur + p.x
			if c == "#":
				e.murs[idx] = true
				continue
			e.sol[idx] = true
			var h := H_BASE
			if c.is_valid_int():
				h = H_BASE + int(c)
			e.hauteurs[idx] = h
			if c in "NSEW":
				attaches.append({"type": "porte", "pos": p, "direction": {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}[c], "libre": true})
			elif c == "X":
				attaches.append({"type": "cage_escalier", "pos": p, "direction": Vector2i.ZERO, "libre": true})
				e.escalier = p
	var piece := {"id": prefab.id, "kind": kind, "rect": Rect2i(origine, Vector2i(plan[0].length(), plan.size())), "attaches": attaches}
	e.pieces.append(piece)
	return piece


func _nb_salles(e: Dictionary) -> int:
	var n := 0
	for p in e.pieces:
		if p.kind == "salle":
			n += 1
	return n


func _attaches_libres(e: Dictionary) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for i in e.pieces.size():
		for a in e.pieces[i].attaches:
			if a.libre and a.type == "porte":
				var copie: Dictionary = a.duplicate()
				copie["piece"] = i
				res.append(copie)
	return res


func _attache_libre_de(e: Dictionary, idx: int) -> Dictionary:
	for a in e.pieces[idx].attaches:
		if a.libre and a.type == "porte":
			var copie: Dictionary = a.duplicate()
			copie["piece"] = idx
			return copie
	return {}


## Depuis une porte libre : tire un connecteur compatible puis une salle compatible, teste la
## collision, place les deux. `force_type` : un type de connecteur imposé (escalier).
func _etendre(e: Dictionary, att: Dictionary, force_type: String = "") -> bool:
	var candidats: Array[Dictionary] = []
	for c: Dictionary in connecteurs.values():
		if force_type.is_empty() and c.type == "escalier":
			continue
		if not force_type.is_empty() and c.type != force_type:
			continue
		candidats.append(c)
	if candidats.is_empty():
		return false
	for essai in ESSAIS_MAX:
		var conn: Dictionary = candidats[rng.randi_range(0, candidats.size() - 1)]
		# La porte du connecteur qui fait face à la direction de l'attache.
		var porte_conn := _porte_opposee(conn, att.direction)
		if porte_conn.is_empty():
			continue
		var origine_conn: Vector2i = att.pos + att.direction - _v(porte_conn.position)
		var rect_conn := Rect2i(origine_conn, Vector2i(conn.plan[0].length(), conn.plan.size()))
		if not _libre(e, rect_conn, att.piece):
			continue
		if conn.type == "escalier":
			var p := _placer(e, conn, origine_conn, "connecteur")
			_marquer(att, e, p, _v(porte_conn.position) + origine_conn)
			_lier(e, att.piece, e.pieces.size() - 1)
			return true
		# L'autre bout du connecteur, puis une salle qui s'y attache.
		var autres := _autres_portes(conn, porte_conn)
		if autres.is_empty():
			continue
		var sortie: Dictionary = autres[rng.randi_range(0, autres.size() - 1)]
		var dir_sortie: Vector2i = _dir(sortie.direction)
		var salles_ok := _salles_par(func(s: Dictionary) -> bool: return not ("entree_eligible" in s.special_tags and e.pieces.size() > 6) and not _porte_opposee(s, dir_sortie).is_empty())
		if salles_ok.is_empty():
			continue
		var s: Dictionary = salles_ok[rng.randi_range(0, salles_ok.size() - 1)]
		var porte_salle := _porte_opposee(s, dir_sortie)
		var origine_salle: Vector2i = origine_conn + _v(sortie.position) + dir_sortie - _v(porte_salle.position)
		var rect_salle := Rect2i(origine_salle, Vector2i(s.plan[0].length(), s.plan.size()))
		# La salle touche son connecteur par la porte : pas de marge entre eux, mais aucun chevauchement.
		if rect_salle.intersects(rect_conn) or not _libre(e, rect_salle, -1):
			continue
		var pc := _placer(e, conn, origine_conn, "connecteur")
		var ic: int = e.pieces.size() - 1
		var ps := _placer(e, s, origine_salle, "salle")
		var i_s: int = e.pieces.size() - 1
		_marquer(att, e, pc, origine_conn + _v(porte_conn.position))
		_consommer(ps, origine_salle + _v(porte_salle.position))
		_consommer(pc, origine_conn + _v(sortie.position))
		_lier(e, att.piece, ic)
		_lier(e, ic, i_s)
		return true
	return false


## La porte d'un prefab dont la direction est l'opposée de `dir` (pour se brancher face à face).
func _porte_opposee(prefab: Dictionary, dir: Vector2i) -> Dictionary:
	for c in prefab.connectors:
		if c.type == "porte" and _dir(c.direction) == -dir:
			return c
	return {}


func _autres_portes(prefab: Dictionary, sauf: Dictionary) -> Array:
	var res := []
	for c in prefab.connectors:
		if c.type == "porte" and c != sauf:
			res.append(c)
	return res


static func _v(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func _dir(nom: String) -> Vector2i:
	return {"nord": Vector2i(0, -1), "sud": Vector2i(0, 1), "est": Vector2i(1, 0), "ouest": Vector2i(-1, 0)}.get(nom, Vector2i.ZERO)


## Le rectangle est-il libre (dans la grille, sans chevaucher une pièce existante, marge comprise) ?
func _libre(e: Dictionary, r: Rect2i, ignorer: int) -> bool:
	if r.position.x < 1 or r.position.y < 1 or r.end.x >= e.largeur - 1 or r.end.y >= e.hauteur - 1:
		return false
	for i in e.pieces.size():
		var autre: Rect2i = e.pieces[i].rect
		if i == ignorer:
			# La pièce d'origine peut toucher le connecteur (ils partagent la porte), pas le chevaucher.
			if autre.intersects(r):
				return false
			continue
		if autre.grow(MARGE).intersects(r):
			return false
	return true


## Une attache consommée des deux côtés ; les tuiles de porte deviennent du sol.
func _marquer(att: Dictionary, e: Dictionary, piece_conn: Dictionary, porte_conn_pos: Vector2i) -> void:
	for a in e.pieces[att.piece].attaches:
		if a.pos == att.pos:
			a.libre = false
	_consommer(piece_conn, porte_conn_pos)


func _consommer(piece: Dictionary, pos: Vector2i) -> void:
	for a in piece.attaches:
		if a.pos == pos:
			a.libre = false


func _lier(e: Dictionary, a: int, b: int) -> void:
	if not e.graphe.has(a):
		e.graphe[a] = []
	if not e.graphe.has(b):
		e.graphe[b] = []
	e.graphe[a].append(b)
	e.graphe[b].append(a)


# ---------------------------------------------------------------- profondeur, boss, peuplement

## Distances de graphe depuis l'entrée (BFS sur les pièces).
func _distances_graphe(e: Dictionary) -> Dictionary:
	var dist := {0: 0}
	var file := [0]
	while not file.is_empty():
		var i: int = file.pop_front()
		for v in e.graphe.get(i, []):
			if not dist.has(v):
				dist[v] = dist[i] + 1
				file.append(v)
	return dist


func _pieces_par_profondeur(e: Dictionary, dist: Dictionary) -> Array:
	var idx := dist.keys()
	idx.sort_custom(func(a: int, b: int) -> bool: return dist[a] > dist[b])
	return idx


func _premiere_tuile_libre(e: Dictionary, piece: Dictionary) -> Vector2i:
	return _centre_libre(e, piece)


func _centre_libre(e: Dictionary, piece: Dictionary) -> Vector2i:
	var r: Rect2i = piece.rect
	var c := r.position + r.size / 2
	for rayon in 8:
		for y in range(-rayon, rayon + 1):
			for x in range(-rayon, rayon + 1):
				var p := c + Vector2i(x, y)
				if r.has_point(p) and e.sol.has(p.y * e.largeur + p.x):
					return p
	return c


## Chaque salle reçoit 0-N créatures du pool du thème, davantage en profondeur (E.29, étape 6).
func _peupler(e: Dictionary, etage: int) -> void:
	var pool: Array = theme.get("creatures", [])
	if pool.is_empty():
		return
	var facteur: float = 1.0 + float(etage) * float(theme.get("croissance_par_etage", 0.25))
	for i in e.pieces.size():
		var p: Dictionary = e.pieces[i]
		if p.kind != "salle" or i == 0:
			continue
		var r: Rect2i = p.rect
		var n := int(floorf(float(r.size.x * r.size.y) / float(theme.get("tuiles_par_creature", 64)) * facteur))
		if p.get("boss_room", false):
			var boss: String = str(theme.get("boss", ""))
			if not boss.is_empty():
				e.spawns.append({"creature": boss, "pos": e.boss})
		var poses := {}
		for k in n:
			var c: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
			var pos := Vector2i(r.position.x + rng.randi_range(1, r.size.x - 2), r.position.y + rng.randi_range(1, r.size.y - 2))
			if not e.sol.has(pos.y * e.largeur + pos.x) or poses.has(pos) or pos == e.boss:
				continue
			poses[pos] = true
			e.spawns.append({"creature": c.id, "pos": pos})
