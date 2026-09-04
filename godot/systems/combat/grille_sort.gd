class_name GrilleSort
extends RefCounted
## La grille de composition (Six types de modules et assemblage, designer 2026-09-03) : un sort est un
## puzzle. Chaque module a une silhouette déduite de son type et de son prix ; l'arme tenue donne, par
## sa voie et son niveau, la silhouette dans laquelle tout doit tenir. Ce fichier ne connaît ni les
## êtres ni la simulation : il reçoit des modules et une grille, il dit si ça rentre et où.
##
## Il possède aussi la règle de LECTURE — « l'ordre de lecture est l'ordre du sort » : ligne par ligne,
## de gauche à droite, chaque pièce prise à sa case la plus haute puis la plus à gauche. L'écran la lit
## ici ; l'emboîtement automatique la respecte (revue du 2026-09-04 : il rangeait les grosses pièces
## d'abord et rendait un sort dans un autre ordre que celui qu'on lui donnait).
##
## Tout est lu dans `combat_rules.grille` — aucune forme n'est écrite ici.

var cfg: Dictionary
var catalogue: Dictionary   # les modules, pour lire type, prix et `forme_grille`


func _init(regles_grille: Dictionary, modules: Dictionary) -> void:
	cfg = regles_grille
	catalogue = modules


# ---------------------------------------------------------------- l'ordre de lecture

## `a` se lit-il avant `b` ? Ligne par ligne, de gauche à droite.
static func avant(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


## La case de lecture d'une pièce : la plus haute, puis la plus à gauche.
static func case_de_lecture(cases: Array) -> Vector2i:
	var meilleure := Vector2i(999999, 999999)
	for c in cases:
		if avant(c, meilleure):
			meilleure = c
	return meilleure


# ---------------------------------------------------------------- la silhouette d'un module

## Les cases d'un module, en coordonnées relatives à sa case de lecture (0, 0). Un module peut porter
## sa propre silhouette (`forme_grille`) ; sinon elle se déduit de son type et de son prix en ticks —
## la première entrée de la table dont le seuil est atteint gagne. Le prix est `cout_ticks` s'il est
## écrit, sinon `surcout_ticks` : on teste la présence de la clé, pas sa valeur (un noyau à 0 tick est
## un noyau à 0 tick, pas un modificateur).
func forme_de(module_id: String) -> Array:
	var m: Dictionary = catalogue.get(module_id, {})
	if m.has("forme_grille") and not (m.forme_grille as Array).is_empty():
		return _normaliser(_vec(m.forme_grille))
	var type := str(m.get("module_type", ""))
	var ticks := int(m.cout_ticks) if m.has("cout_ticks") else int(m.get("surcout_ticks", 0))
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


## Combien de rotations une pièce peut prendre : quatre, ou une seule si la règle les interdit. C'est
## la seule source pour l'écran (R, Entrée) comme pour l'emboîtement — les deux doivent tomber d'accord.
func rotations_permises() -> int:
	return 4 if bool(cfg.get("rotations", true)) else 1


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


# ---------------------------------------------------------------- la grille d'une voie

## La silhouette d'une voie à un niveau : la dernière entrée de `grilles_par_stat[stat]` dont
## `niveau_min` est atteint. Sans voie (stat inconnue) : la grille de poche.
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

## Cherche un emboîtement des modules de `sequence` dans `grille`, DANS L'ORDRE DE LA SÉQUENCE : la
## case de lecture de chaque pièce vient strictement après celle de la précédente, si bien qu'une
## grille rangée par le moteur se relit exactement comme la séquence qu'on lui a donnée. Retourne
## {"ok", "placement": [{"module", "rot", "ancre", "cases"}], "demande", "capacite", "manque"}.
## `manque` est le nombre de cases qui dépassent la grille ; il vaut 0 quand la place brute suffit mais
## que les formes ne s'emboîtent pas dans cet ordre — `ok` est alors faux quand même.
func emboiter(sequence: Array, grille: Array) -> Dictionary:
	var pieces: Array = []
	for m in sequence:
		var forme: Array = forme_de(str(m))
		pieces.append({"module": str(m), "forme": forme, "rotations": _rotations(forme)})
	var demande := 0
	for p in pieces:
		demande += (p.forme as Array).size()
	var res := {"ok": false, "placement": [], "demande": demande, "capacite": grille.size(), "manque": maxi(0, demande - grille.size())}
	if demande > grille.size():
		return res
	var cases_lues: Array = grille.duplicate()   # les ancres s'essaient dans l'ordre de lecture
	cases_lues.sort_custom(avant)
	var libres := {}
	for c in grille:
		libres[c] = true
	var placement: Array = []
	if _placer(pieces, 0, cases_lues, libres, placement, Vector2i(-1, -1)):
		res.ok = true
		res.placement = placement
	return res


## Le retour arrière : la pièce `i` s'ancre sur une case libre qui vient après `apres` dans l'ordre de
## lecture, dans l'une de ses rotations ; on essaie chaque case libre et chaque rotation, on descend, on
## remonte si rien ne tient plus loin.
func _placer(pieces: Array, i: int, cases_lues: Array, libres: Dictionary, placement: Array, apres: Vector2i) -> bool:
	if i >= pieces.size():
		return true
	var piece: Dictionary = pieces[i]
	for ancre in cases_lues:
		if not libres[ancre] or not avant(apres, ancre):
			continue
		for rot in piece.rotations:
			var cases: Array = []
			var ok := true
			for c in rot.forme:
				var pos: Vector2i = ancre + c
				if not libres.get(pos, false):
					ok = false
					break
				cases.append(pos)
			if not ok:
				continue
			for c in cases:
				libres[c] = false
			placement.append({"module": piece.module, "rot": int(rot.k), "ancre": ancre, "cases": cases})
			if _placer(pieces, i + 1, cases_lues, libres, placement, ancre):
				return true
			placement.pop_back()
			for c in cases:
				libres[c] = true
	return false


## Les rotations distinctes d'une silhouette, avec leur quart de tour `k` : [{k, forme}]. Quatre au
## plus, jamais de miroir ; une seule si la règle interdit de tourner. Chaque forme est normalisée sur
## sa case de lecture, donc l'ancre est toujours la case (0, 0) de la forme : essayer chaque rotation
## sur chaque case libre couvre tous les placements.
func _rotations(forme: Array) -> Array:
	var vues: Array = []
	for k in rotations_permises():
		var f: Array = tournee(forme, k)
		var deja := false
		for v in vues:
			if _memes(v.forme, f):
				deja = true
				break
		if not deja:
			vues.append({"k": k, "forme": f})
	return vues


## Ramène une silhouette sur sa case de lecture : la case la plus haute puis la plus à gauche devient
## (0, 0), les autres se comptent depuis elle (des x négatifs sont possibles : un L couché). Une
## silhouette vide devient une case, pour qu'une table de formes mal écrite ne plante pas le jeu.
static func _normaliser(forme: Array) -> Array:
	if forme.is_empty():
		return [Vector2i.ZERO]
	var res: Array = forme.duplicate()
	res.sort_custom(avant)
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
