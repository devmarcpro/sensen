class_name GrilleSort
extends RefCounted
## La grille de composition (Six types de modules et assemblage, designer 2026-09-03) : un sort est un
## puzzle. Chaque module a une silhouette déduite de son type et de son prix ; l'arme tenue donne, par
## sa voie et son niveau, la silhouette dans laquelle tout doit tenir. Ce fichier ne connaît ni les
## êtres ni la simulation : il reçoit des modules et une grille, il dit si ça rentre et où.
##
## La grille n'a PAS de sens de lecture (designer 2026-09-04) : c'est un sac de pièces, où l'on pose ne
## change rien au sort, seul compte ce qui rentre. La séquence qu'on en tire suit un ORDRE CANONIQUE par
## type (`ordonner`), sans effet sur le plan ; et un sort se compose par ÉTAPES — un déclencheur ferme la
## sienne et ouvre la suivante — chacune dans sa propre grille (`etapes_de`). `avant` et `case_de_lecture`
## ne sont plus que des commodités de dessin et de parcours déterministe.
##
## Tout est lu dans `combat_rules.grille` — aucune forme n'est écrite ici.

var cfg: Dictionary
var catalogue: Dictionary   # les modules, pour lire type, prix et `forme_grille`
var grilles: Dictionary     # le catalogue des silhouettes (`data/grilles/`) — le joueur en possède plusieurs (2026-09-04)


func _init(regles_grille: Dictionary, modules: Dictionary, catalogue_grilles: Dictionary = {}) -> void:
	cfg = regles_grille
	catalogue = modules
	grilles = catalogue_grilles


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


# ---------------------------------------------------------------- les étapes et l'ordre canonique

## L'ordre canonique d'une étape : par type — portée, forme, noyaux, modificateurs, conditions, liaisons,
## déclencheur — et, à type égal, l'ordre reçu. C'est l'ordre des groupes du composeur du 1er septembre. Il est
## sans effet sur le plan (l'assembleur applique un modificateur au sort entier) ; il sert à ce que deux grilles
## qui contiennent les mêmes pièces donnent la même séquence, et à ce que deux pièces d'un même module se suivent.
const ORDRE_CANONIQUE: Array[String] = ["portee", "forme", "noyau", "modificateur", "condition", "liaison", "declencheur"]


func rang_de(id: String) -> int:
	var k := ORDRE_CANONIQUE.find(str(catalogue.get(id, {}).get("module_type", "")))
	return k if k >= 0 else ORDRE_CANONIQUE.size()


func ordonner(modules: Array) -> Array:
	var indices: Array = []
	for i in modules.size():
		indices.append(i)
	var rangs: Array = []
	for m in modules:
		rangs.append(rang_de(str(m)))
	indices.sort_custom(func(a: int, b: int) -> bool:   # tri stable : à rang égal, l'ordre reçu
		return rangs[a] < rangs[b] or (rangs[a] == rangs[b] and a < b))
	var tri: Array = []
	for i in indices:
		tri.append(str(modules[i]))
	return tri


## Les étapes d'une séquence : un déclencheur ferme la sienne et ouvre la suivante (sa charge utile). Une
## séquence sans déclencheur est une seule étape ; une étape vide en queue (déclencheur sans suite) est ignorée.
func etapes_de(sequence: Array) -> Array:
	var etapes: Array = [[]]
	for m in sequence:
		(etapes.back() as Array).append(str(m))
		if str(catalogue.get(str(m), {}).get("module_type", "")) == "declencheur":
			etapes.append([])
	if etapes.size() > 1 and (etapes.back() as Array).is_empty():
		etapes.pop_back()
	return etapes


## La séquence canonique : chaque étape dans l'ordre canonique, les étapes à la suite.
func canonique(sequence: Array) -> Array:
	var res: Array = []
	for et in etapes_de(sequence):
		res.append_array(ordonner(et))
	return res


# ---------------------------------------------------------------- la silhouette d'un module

## Les cases d'un module, en coordonnées relatives à sa case de lecture (0, 0). Un module peut porter
## sa propre silhouette (`forme_grille`) ; sinon elle se déduit de son type et de son prix en ticks —
## la première entrée de la table dont le seuil est atteint gagne. Le prix est `cout_ticks` s'il est
## écrit, sinon `surcout_ticks` : on teste la présence de la clé, pas sa valeur (un noyau à 0 tick est
## un noyau à 0 tick, pas un modificateur).
func forme_de(module_id: String, fois: int = 1) -> Array:
	var m: Dictionary = catalogue.get(module_id, {})
	var base: Array = []
	if m.has("forme_grille") and not (m.forme_grille as Array).is_empty():
		base = _normaliser(_vec(m.forme_grille))
	else:
		var type := str(m.get("module_type", ""))
		var ticks := int(m.cout_ticks) if m.has("cout_ticks") else int(m.get("surcout_ticks", 0))
		base = _forme_au_prix(type, ticks)
	if fois > 1:
		# Le CRAN DE PUISSANCE (designer 2026-09-04) : une pièce ×n prend n fois la place, en un BLOC
		# aussi carré que possible. Un domino ×2 est un carré, ×3 un rectangle 3×2. La première version
		# allongeait la pièce en ligne : trop large pour les petites grilles, et impossible à prévoir.
		return _bloc(base.size() * fois)
	return base


## La forme de la table pour un type et un prix : la première entrée dont le seuil est atteint.
func _forme_au_prix(type: String, ticks: int) -> Array:
	var table: Array = cfg.get("formes_par_type", {}).get(type, [])
	for entree in table:
		if ticks >= int(entree.get("ticks_min", -999)):
			return _normaliser(_vec(entree.get("cellules", [[0, 0]])))
	return [Vector2i.ZERO]


## Un bloc de `n` cases, aussi carré que possible : la largeur est la racine carrée arrondie au-dessus,
## les rangées se remplissent de gauche à droite, la dernière peut être incomplète.
static func _bloc(n: int) -> Array:
	var largeur := maxi(1, int(ceil(sqrt(float(n)))))
	var res: Array = []
	for k in n:
		res.append(Vector2i(k % largeur, k / largeur))
	return _normaliser(res)


## Les pièces d'une séquence : une suite de modules identiques est UNE pièce ×n (le cran de puissance).
static func pieces_de(sequence: Array) -> Array:
	var pieces: Array = []
	for m in sequence:
		if not pieces.is_empty() and str(pieces[pieces.size() - 1].module) == str(m):
			pieces[pieces.size() - 1].fois += 1
		else:
			pieces.append({"module": str(m), "fois": 1})
	return pieces


## Le nombre de cases qu'une séquence demande, toutes pièces confondues.
func taille_de(sequence: Array) -> int:
	var n := 0
	for p in pieces_de(sequence):
		n += forme_de(str(p.module), int(p.fois)).size()
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
## `niveau_min` est atteint — une fiche du catalogue, ou des lignes écrites en place. Sans voie
## (stat inconnue) : la grille de poche.
func grille_de(stat: String, niveau: int) -> Array:
	var paliers: Array = cfg.get("grilles_par_stat", {}).get(stat, [])
	var choisi: Dictionary = {}
	for p in paliers:
		if niveau >= int(p.get("niveau_min", 0)):
			choisi = p
	if choisi.is_empty():
		choisi = cfg.get("mains_nues", {"lignes": ["##", "##"]})
	return _cases_de(choisi)


## L'id de la fiche qu'une voie donne à un niveau ("" si la table écrit ses lignes en place).
func id_grille_de(stat: String, niveau: int) -> String:
	var paliers: Array = cfg.get("grilles_par_stat", {}).get(stat, [])
	var choisi := ""
	for p in paliers:
		if niveau >= int(p.get("niveau_min", 0)):
			choisi = str(p.get("grille", ""))
	return choisi


## Les paliers d'une voie : [{niveau_min, grille}], pour débloquer au bon moment.
func paliers_de(stat: String) -> Array:
	return cfg.get("grilles_par_stat", {}).get(stat, [])


## Les cases d'une fiche du catalogue (vide si l'id est inconnu).
func cases_de_grille(id: String) -> Array:
	var fiche: Dictionary = grilles.get(id, {})
	if fiche.is_empty():
		return []
	return _cases_des_lignes(fiche.get("lignes", []))


## Une entrée de table : soit `grille` (une fiche), soit `lignes` (en place).
func _cases_de(entree: Dictionary) -> Array:
	if entree.has("grille"):
		var c := cases_de_grille(str(entree.grille))
		if not c.is_empty():
			return c
	return _cases_des_lignes(entree.get("lignes", []))


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

## Cherche un emboîtement des modules de `sequence` dans `grille` — un sac de pièces, sans ordre (designer
## 2026-09-04) : les pièces s'essaient dans l'ordre canonique, sur chaque case libre et dans chaque rotation,
## avec retour arrière. Retourne {"ok", "placement": [{"module", "fois", "rot", "ancre", "cases"}], "demande",
## "capacite", "manque"}. `manque` est le nombre de cases qui dépassent la grille ; il vaut 0 quand la place
## brute suffit mais que les formes ne s'emboîtent pas — `ok` est alors faux quand même.
func emboiter(sequence: Array, grille: Array) -> Dictionary:
	var pieces: Array = []
	for pc in pieces_de(ordonner(sequence)):   # une suite de modules identiques est une pièce ×n
		var forme: Array = forme_de(str(pc.module), int(pc.fois))
		pieces.append({"module": str(pc.module), "fois": int(pc.fois), "forme": forme, "rotations": _rotations(forme)})
	var demande := 0
	for p in pieces:
		demande += (p.forme as Array).size()
	var res := {"ok": false, "placement": [], "demande": demande, "capacite": grille.size(), "manque": maxi(0, demande - grille.size())}
	if demande > grille.size():
		return res
	var ancres: Array = grille.duplicate()   # du haut à gauche vers le bas à droite : déterministe, pas une règle
	ancres.sort_custom(avant)
	var libres := {}
	for c in grille:
		libres[c] = true
	var placement: Array = []
	if _placer(pieces, 0, ancres, libres, placement):
		res.ok = true
		res.placement = placement
	return res


## Le retour arrière : la pièce `i` s'ancre sur une case libre, dans l'une de ses rotations ; on essaie
## chaque case libre et chaque rotation, on descend, on remonte si rien ne tient plus loin.
func _placer(pieces: Array, i: int, ancres: Array, libres: Dictionary, placement: Array) -> bool:
	if i >= pieces.size():
		return true
	var piece: Dictionary = pieces[i]
	for ancre in ancres:
		if not libres[ancre]:
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
			placement.append({"module": piece.module, "fois": int(piece.get("fois", 1)), "rot": int(rot.k), "ancre": ancre, "cases": cases})
			if _placer(pieces, i + 1, ancres, libres, placement):
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
