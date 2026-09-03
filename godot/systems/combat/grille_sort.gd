class_name GrilleSort
extends RefCounted
## La grille de composition (Six types de modules et assemblage, designer 2026-09-03) : un sort est un
## puzzle. Chaque module a une silhouette déduite de son type et de son prix ; l'arme tenue donne, par
## sa voie et son niveau, la silhouette dans laquelle tout doit tenir. Ce fichier ne connaît ni les
## êtres ni la simulation : il reçoit des modules et une grille, il dit si ça rentre et où.
##
## Tout est lu dans `combat_rules.grille` — aucune forme n'est écrite ici.

var cfg: Dictionary
var catalogue: Dictionary   # les modules, pour lire type, prix et `forme_grille`


func _init(regles_grille: Dictionary, modules: Dictionary) -> void:
	cfg = regles_grille
	catalogue = modules


# ---------------------------------------------------------------- la silhouette d'un module

## Les cases d'un module, en coordonnées relatives (le coin haut-gauche est (0,0)). Un module peut
## porter sa propre silhouette (`forme_grille`) ; sinon elle se déduit de son type et de son prix en
## ticks — la première entrée de la table dont le seuil est atteint gagne.
func forme_de(module_id: String) -> Array:
	var m: Dictionary = catalogue.get(module_id, {})
	if m.has("forme_grille") and not (m.forme_grille as Array).is_empty():
		return _normaliser(_vec(m.forme_grille))
	var type := str(m.get("module_type", ""))
	var ticks := int(m.get("cout_ticks", 0))
	if ticks == 0:
		ticks = int(m.get("surcout_ticks", 0))
	var table: Array = cfg.get("formes_par_type", {}).get(type, [])
	for entree in table:
		if ticks >= int(entree.get("ticks_min", -999)):
			return _normaliser(_vec(entree.get("cellules", [[0, 0]])))
	return [Vector2i.ZERO]


## Le nombre de cases qu'une séquence demande, toutes pièces confondues.
func taille_de(sequence: Array) -> int:
	var n := 0
	for m in sequence:
		n += forme_de(str(m)).size()
	return n


# ---------------------------------------------------------------- la grille d'une voie

## La silhouette d'une voie à un niveau : la dernière entrée de `grilles_par_stat[stat]` dont
## `niveau_min` est atteint. Sans voie (mains nues, stat inconnue) : la grille de poche.
func grille_de(stat: String, niveau: int) -> Array:
	var paliers: Array = cfg.get("grilles_par_stat", {}).get(stat, [])
	var choisi: Dictionary = {}
	for p in paliers:
		if niveau >= int(p.get("niveau_min", 0)):
			choisi = p
	if choisi.is_empty():
		choisi = cfg.get("mains_nues", {"lignes": ["##", "##"]})
	return _cases_des_lignes(choisi.get("lignes", []))


## Les lignes de texte (`#` une case, `.` rien) → la liste des cases.
static func _cases_des_lignes(lignes: Array) -> Array:
	var cases: Array = []
	for y in lignes.size():
		var l := str(lignes[y])
		for x in l.length():
			if l[x] == "#":
				cases.append(Vector2i(x, y))
	return cases


# ---------------------------------------------------------------- l'emboîtement

## Cherche un emboîtement des modules de `sequence` dans `grille`. Retourne
## {"ok": bool, "placement": [{"module", "cases": [Vector2i]}], "manque": int}. `manque` est le
## nombre de cases qui dépassent la grille — le message pour le joueur — même quand la place brute
## suffit mais que les formes ne s'emboîtent pas (alors `manque` vaut 0 et `ok` est faux).
func emboiter(sequence: Array, grille: Array) -> Dictionary:
	var res := {"ok": false, "placement": [], "manque": 0}
	var libres := {}
	for c in grille:
		libres[c] = true
	var pieces: Array = []
	for m in sequence:
		pieces.append({"module": str(m), "forme": forme_de(str(m))})
	var demande := 0
	for p in pieces:
		demande += p.forme.size()
	if demande > grille.size():
		res.manque = demande - grille.size()
		return res
	# les grosses pièces d'abord : c'est elles qui décident, et le retour arrière coupe plus tôt
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.forme.size() > b.forme.size())
	var placement: Array = []
	if _placer(pieces, 0, libres, placement):
		res.ok = true
		res.placement = placement
	return res


func _placer(pieces: Array, i: int, libres: Dictionary, placement: Array) -> bool:
	if i >= pieces.size():
		return true
	var piece: Dictionary = pieces[i]
	var rotations := _rotations(piece.forme)
	for ancre in libres.keys():
		if not libres[ancre]:
			continue
		for forme in rotations:
			var cases: Array = []
			var ok := true
			for c in forme:
				var pos: Vector2i = ancre + c
				if not libres.get(pos, false):
					ok = false
					break
				cases.append(pos)
			if not ok:
				continue
			for c in cases:
				libres[c] = false
			placement.append({"module": piece.module, "cases": cases})
			if _placer(pieces, i + 1, libres, placement):
				return true
			placement.pop_back()
			for c in cases:
				libres[c] = true
	return false


## La silhouette tournée `k` quarts de tour (0 à 3), normalisée : c'est ce que le composeur pose quand
## le joueur appuie sur R — la même figure que le moteur essaie de lui-même dans `emboiter`.
func tournee(forme: Array, k: int) -> Array:
	var courante: Array = _normaliser(forme)
	for i in (k % 4 + 4) % 4:
		var t: Array = []
		for c in courante:
			t.append(Vector2i(-c.y, c.x))
		courante = _normaliser(t)
	return courante


## Les cases qu'occuperait `forme` ancrée en `ancre`, ou [] si une case sort de `grille` ou est prise.
func poser(forme: Array, ancre: Vector2i, grille: Array, occupees: Dictionary) -> Array:
	var cases: Array = []
	for c in forme:
		var pos: Vector2i = ancre + c
		if not (pos in grille) or occupees.get(pos, false):
			return []
		cases.append(pos)
	return cases


## Les rotations distinctes d'une silhouette (quatre au plus, jamais de miroir). Chaque rotation est
## ramenée en coin haut-gauche, et l'ancre est toujours sa première case : on essaie donc chaque
## rotation posée par sa case (0, 0) sur chaque case libre, ce qui couvre tous les placements.
func _rotations(forme: Array) -> Array:
	var vues: Array = [_normaliser(forme)]
	if not bool(cfg.get("rotations", true)):
		return vues
	var courante: Array = forme
	for k in 3:
		var tournee: Array = []
		for c in courante:
			tournee.append(Vector2i(-c.y, c.x))
		courante = _normaliser(tournee)
		var deja := false
		for v in vues:
			if _memes(v, courante):
				deja = true
				break
		if not deja:
			vues.append(courante)
	return vues


static func _normaliser(forme: Array) -> Array:
	var mx := 999999
	var my := 999999
	for c in forme:
		mx = mini(mx, c.x)
		my = mini(my, c.y)
	var res: Array = []
	for c in forme:
		res.append(Vector2i(c.x - mx, c.y - my))
	# on met la première case en (0, y) minimal pour que l'ancre soit la case la plus haute à gauche,
	# ce qui rend les placements par ancre exhaustifs (voir _rotations)
	res.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var premiere: Vector2i = res[0]
	var decalee: Array = []
	for c in res:
		decalee.append(c - premiere)
	return decalee


static func _memes(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for c in a:
		if not (c in b):
			return false
	return true


static func _vec(cellules: Array) -> Array:
	var res: Array = []
	for c in cellules:
		res.append(Vector2i(int(c[0]), int(c[1])))
	return res
