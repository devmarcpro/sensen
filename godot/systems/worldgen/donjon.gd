class_name Donjon
extends RefCounted
## Génération d'un étage : **un labyrinthe avec des salles, contenu dans une cellule** (64×64 tuiles —
## Grille continue), à étages, deux escaliers par étage (un vers le haut, un vers le bas), murs
## destructibles, **salles procédurales façon Elin** (décisions du designer, 2026-08-27 — Génération de donjon).
##   1. des salles rectangulaires tirées au hasard (`taille_salles` du thème) sont posées sans
##      chevauchement, avec 1 à 3 portes ;
##   2. le labyrinthe (backtracker sur une trame de 4 tuiles) remplit tout le reste ;
##   3. chaque porte s'ouvre sur le couloir voisin ; connexité vérifiée par BFS et réparée par une
##      tranchée droite si besoin ;
##   4. l'escalier montant (l'arrivée) dans une salle, l'escalier descendant dans la salle la plus
##      lointaine ; le boss au dernier étage y remplace l'escalier ;
##   5. peuplement par le thème, contenants de loot.
## Déterministe par seed(monde, id_donjon, étage). Le plein est du mur (destructible) ; le bord
## de la cellule est de la roche (indestructible). La bibliothèque de prefabs reste en données.

const H_BASE := 10                 # hauteur de référence d'un étage (Hauteur de terrain ±10)
const PAS := 4                     # trame du labyrinthe : 3 tuiles de couloir + 1 de mur
const ESSAIS_SALLE := 12

var salles: Dictionary             # bibliothèque de prefabs, conservée mais non posée
var connecteurs: Dictionary
var theme: Dictionary
var rng := RandomNumberGenerator.new()


func _init(p_salles: Dictionary, p_connecteurs: Dictionary, p_theme: Dictionary) -> void:
	salles = p_salles
	connecteurs = p_connecteurs
	theme = p_theme


## Génère un étage : {largeur, hauteur, hauteurs, murs, sol, bord, pieces: [{id, kind, rect, attaches}],
##  entree (escalier montant), escalier (descendant, null au dernier), boss, spawns, coffres, graphe}.
func generer_etage(graine: int, id_donjon: int, etage: int, nb_salles: int, dernier: bool, taille: int = 64) -> Dictionary:
	rng.seed = hash([graine, id_donjon, etage])
	var e := {"largeur": taille, "hauteur": taille, "hauteurs": PackedByteArray(), "murs": {}, "sol": {}, "bord": {},
		"pieces": [], "entree": Vector2i.ZERO, "escalier": null, "boss": null, "spawns": [], "coffres": [], "graphe": {}, "etage": etage}
	e.hauteurs.resize(taille * taille)
	e.hauteurs.fill(H_BASE)
	for i in taille:
		for b in [Vector2i(i, 0), Vector2i(i, taille - 1), Vector2i(0, i), Vector2i(taille - 1, i)]:
			e.bord[b.y * taille + b.x] = true
	# 1. Les salles : des rectangles au hasard (façon Elin), alignés sur la trame, sans chevauchement.
	var tailles: Array = theme.get("taille_salles", [4, 9])
	var essais := 0
	while _nb_salles(e) < nb_salles and essais < nb_salles * ESSAIS_SALLE:
		essais += 1
		var w := rng.randi_range(int(tailles[0]), int(tailles[1]))
		var h := rng.randi_range(int(tailles[0]), int(tailles[1]))
		var origine := Vector2i(rng.randi_range(2, taille - w - 3), rng.randi_range(2, taille - h - 3))
		origine = Vector2i(origine.x - origine.x % PAS + 1, origine.y - origine.y % PAS + 1)   # aligné sur la trame
		var r := Rect2i(origine, Vector2i(w, h))
		if not _libre(e, r):
			continue
		_placer_rectangle(e, r)
	# 2. Le labyrinthe dans tout ce qui reste.
	_labyrinthe(e)
	# 3. Les portes des salles s'ouvrent sur le couloir voisin ; connexité réparée si besoin.
	for p in e.pieces:
		for a in p.attaches:
			if a.type == "porte":
				_ouvrir_porte(e, a)
	_reparer_connexite(e)
	# 4. Les escaliers : l'arrivée dans la première salle, la descente dans la plus lointaine.
	var p0: Dictionary = e.pieces[0]
	e.entree = _centre_libre(e, p0)
	e.sol[e.entree.y * taille + e.entree.x] = true
	var loin := _piece_la_plus_loin(e, e.entree)
	if dernier:
		e.boss = _centre_libre(e, e.pieces[loin])
		e.pieces[loin]["boss_room"] = true
	else:
		e.escalier = _centre_libre(e, e.pieces[loin])
	# 5. Peuplement et contenants.
	_peupler(e, etage)
	_poser_coffres(e)
	return e


# ---------------------------------------------------------------- salles

func _salles_du_theme() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for s: Dictionary in salles.values():
		var themes: Array = s.get("floor_theme", [])
		if themes.is_empty() or theme.id in themes:
			res.append(s)
	return res


func _libre(e: Dictionary, r: Rect2i) -> bool:
	if r.position.x < 2 or r.position.y < 2 or r.end.x > e.largeur - 2 or r.end.y > e.hauteur - 2:
		return false
	for p in e.pieces:
		if p.rect.grow(2).intersects(r):
			return false
	return true


## Pose un prefab (sols, hauteurs, attaches) ; ses murs sont le plein. Retourne la pièce.
func _placer(e: Dictionary, prefab: Dictionary, origine: Vector2i, kind: String) -> Dictionary:
	var plan: Array = prefab.plan
	var attaches: Array = []
	for y in plan.size():
		var ligne: String = plan[y]
		for x in ligne.length():
			var c := ligne[x]
			if c == " " or c == "#":
				continue
			var p := origine + Vector2i(x, y)
			var idx: int = p.y * e.largeur + p.x
			e.sol[idx] = true
			e.hauteurs[idx] = H_BASE + (int(c) if c.is_valid_int() else 0)
			if c in "NSEW":
				attaches.append({"type": "porte", "pos": p, "direction": {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}[c], "libre": true})
	var piece := {"id": prefab.id, "kind": kind, "rect": Rect2i(origine, Vector2i(plan[0].length(), plan.size())), "attaches": attaches}
	e.pieces.append(piece)
	return piece


## Une salle procédurale : un rectangle de sol, 1 à 3 portes sur des côtés distincts.
func _placer_rectangle(e: Dictionary, r: Rect2i) -> Dictionary:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			e.sol[y * e.largeur + x] = true
	var attaches: Array = []
	var nb := rng.randi_range(1, 3)
	var pris := {}
	for k in nb:
		var i := rng.randi_range(0, 3)
		while pris.has(i):
			i = (i + 1) % 4
		pris[i] = true
		var d: Vector2i = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)][i]
		var pos: Vector2i
		if d.y != 0:
			pos = Vector2i(rng.randi_range(r.position.x, r.end.x - 1), r.position.y if d.y < 0 else r.end.y - 1)
		else:
			pos = Vector2i(r.position.x if d.x < 0 else r.end.x - 1, rng.randi_range(r.position.y, r.end.y - 1))
		attaches.append({"type": "porte", "pos": pos, "direction": d, "libre": true})
	var piece := {"id": "salle_%dx%d" % [r.size.x, r.size.y], "kind": "salle", "rect": r, "attaches": attaches}
	e.pieces.append(piece)
	return piece


func _nb_salles(e: Dictionary) -> int:
	var n := 0
	for p in e.pieces:
		if p.kind == "salle":
			n += 1
	return n


# ---------------------------------------------------------------- labyrinthe

## Backtracker récursif sur une trame de PAS tuiles : chaque nœud est un carré de 3 tuiles de sol,
## chaque arête ouverte creuse la tuile de mur entre deux nœuds. Les nœuds sous une salle sont exclus.
func _labyrinthe(e: Dictionary) -> void:
	var n: int = (e.largeur - 1) / PAS
	var ok := {}
	for gy in n:
		for gx in n:
			var r := Rect2i(Vector2i(gx * PAS + 1, gy * PAS + 1), Vector2i(3, 3))
			var libre := true
			for p in e.pieces:
				if p.rect.grow(1).intersects(r):
					libre = false
			if libre:
				ok[Vector2i(gx, gy)] = true
	if ok.is_empty():
		return
	var visites := {}
	var pile: Array[Vector2i] = []
	var depart: Vector2i = ok.keys()[rng.randi_range(0, ok.size() - 1)]
	visites[depart] = true
	pile.append(depart)
	_creuser_noeud(e, depart)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not pile.is_empty():
		var c: Vector2i = pile.back()
		var voisins: Array[Vector2i] = []
		for d in dirs:
			var v: Vector2i = c + d
			if ok.has(v) and not visites.has(v):
				voisins.append(v)
		if voisins.is_empty():
			pile.pop_back()
			# Les nœuds jamais reliés (îlots entre salles) repartent d'un nouveau départ.
			if pile.is_empty():
				for k in ok.keys():
					if not visites.has(k):
						visites[k] = true
						pile.append(k)
						_creuser_noeud(e, k)
						break
			continue
		var v: Vector2i = voisins[rng.randi_range(0, voisins.size() - 1)]
		visites[v] = true
		_creuser_noeud(e, v)
		_creuser_arete(e, c, v)
		pile.append(v)


func _creuser_noeud(e: Dictionary, g: Vector2i) -> void:
	for y in 3:
		for x in 3:
			var p := Vector2i(g.x * PAS + 1 + x, g.y * PAS + 1 + y)
			e.sol[p.y * e.largeur + p.x] = true


func _creuser_arete(e: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var d := b - a
	var base := Vector2i(a.x * PAS + 2, a.y * PAS + 2)   # centre du nœud a
	for k in range(1, PAS + 1):
		var p := base + d * k
		if p.x > 0 and p.y > 0 and p.x < e.largeur - 1 and p.y < e.hauteur - 1:
			e.sol[p.y * e.largeur + p.x] = true


## Une porte s'ouvre : on creuse droit devant elle jusqu'au premier sol (au plus PAS + 1 tuiles).
func _ouvrir_porte(e: Dictionary, a: Dictionary) -> void:
	var p: Vector2i = a.pos
	for k in range(1, PAS + 2):
		var q: Vector2i = p + a.direction * k
		if q.x <= 0 or q.y <= 0 or q.x >= e.largeur - 1 or q.y >= e.hauteur - 1:
			return
		var idx: int = q.y * e.largeur + q.x
		if e.sol.has(idx):
			return
		e.sol[idx] = true


## Connexité : BFS depuis la première salle ; toute salle isolée reçoit une tranchée droite.
func _reparer_connexite(e: Dictionary) -> void:
	if e.pieces.is_empty():
		return
	var origine: Vector2i = _centre_libre(e, e.pieces[0])
	for essai in 4:
		var atteint := _bfs(e, origine)
		var repare := false
		for p in e.pieces:
			var c := _centre_libre(e, p)
			if not atteint.has(c.y * e.largeur + c.x):
				_tranchee(e, c, _plus_proche_atteint(e, c, atteint))
				repare = true
		if not repare:
			return


func _bfs(e: Dictionary, depart: Vector2i) -> Dictionary:
	var vu := {depart.y * e.largeur + depart.x: true}
	var file: Array[Vector2i] = [depart]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not file.is_empty():
		var c: Vector2i = file.pop_front()
		for d in dirs:
			var v: Vector2i = c + d
			var idx: int = v.y * e.largeur + v.x
			if v.x >= 0 and v.y >= 0 and v.x < e.largeur and v.y < e.hauteur and e.sol.has(idx) and not vu.has(idx):
				vu[idx] = true
				file.append(v)
	return vu


func _plus_proche_atteint(e: Dictionary, c: Vector2i, atteint: Dictionary) -> Vector2i:
	var meilleur := c
	var dmin := 1 << 30
	for idx in atteint.keys():
		var p := Vector2i(idx % e.largeur, idx / e.largeur)
		var d := absi(p.x - c.x) + absi(p.y - c.y)
		if d < dmin:
			dmin = d
			meilleur = p
	return meilleur


func _tranchee(e: Dictionary, de: Vector2i, vers: Vector2i) -> void:
	var p := de
	while p != vers:
		var d := Vector2i(signi(vers.x - p.x), signi(vers.y - p.y))
		p += Vector2i(d.x, 0) if d.x != 0 else Vector2i(0, d.y)
		if p.x > 0 and p.y > 0 and p.x < e.largeur - 1 and p.y < e.hauteur - 1:
			e.sol[p.y * e.largeur + p.x] = true


func _piece_la_plus_loin(e: Dictionary, depart: Vector2i) -> int:
	# Distance de marche (BFS) : la salle la plus lointaine reçoit l'escalier ou le boss.
	var dist := {depart.y * e.largeur + depart.x: 0}
	var file: Array[Vector2i] = [depart]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not file.is_empty():
		var c: Vector2i = file.pop_front()
		var dc: int = dist[c.y * e.largeur + c.x]
		for d in dirs:
			var v: Vector2i = c + d
			var idx: int = v.y * e.largeur + v.x
			if v.x >= 0 and v.y >= 0 and v.x < e.largeur and v.y < e.hauteur and e.sol.has(idx) and not dist.has(idx):
				dist[idx] = dc + 1
				file.append(v)
	var meilleur := 0
	var dmax := -1
	for i in range(1, e.pieces.size()):
		var c := _centre_libre(e, e.pieces[i])
		var d: int = int(dist.get(c.y * e.largeur + c.x, -1))
		if d > dmax:
			dmax = d
			meilleur = i
	return meilleur


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


# ---------------------------------------------------------------- peuplement et contenants

## Chaque salle reçoit 0-N créatures du pool du thème, davantage en profondeur (E.29, étape 6).
func _peupler(e: Dictionary, etage: int) -> void:
	var pool: Array = theme.get("creatures", [])
	if pool.is_empty():
		return
	var facteur: float = 1.0 + float(etage) * float(theme.get("croissance_par_etage", 0.25))
	for i in e.pieces.size():
		var p: Dictionary = e.pieces[i]
		if i == 0:
			continue
		var r: Rect2i = p.rect
		var n := maxi(1, int(floorf(float(r.size.x * r.size.y) / float(theme.get("tuiles_par_creature", 64)) * facteur)))   # au moins un occupant par salle
		if p.get("boss_room", false):
			var boss: String = str(theme.get("boss", ""))
			if not boss.is_empty():
				e.spawns.append({"creature": boss, "pos": e.boss})
		var poses := {}
		for k in n:
			var c: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
			var pos := Vector2i(r.position.x + rng.randi_range(1, r.size.x - 2), r.position.y + rng.randi_range(1, r.size.y - 2))
			if not e.sol.has(pos.y * e.largeur + pos.x) or poses.has(pos) or pos == e.boss or pos == e.escalier:
				continue
			poses[pos] = true
			e.spawns.append({"creature": c.id, "pos": pos})


## Contenants de loot par salle (Génération de donjon, étape 6) ; le contenu est généré par la simulation.
func _poser_coffres(e: Dictionary) -> void:
	var lr: Dictionary = GameData.config("loot_rules").contenants
	var occupees := {}
	for sp in e.spawns:
		occupees[sp.pos] = true
	for i in e.pieces.size():
		var p: Dictionary = e.pieces[i]
		if i == 0:
			continue
		var r: Rect2i = p.rect
		var n := int(floorf(float(r.size.x * r.size.y) / float(lr.tuiles_par_coffre)))
		if p.get("boss_room", false):
			n += 1
		for k in n:
			var pos := Vector2i(r.position.x + rng.randi_range(1, r.size.x - 2), r.position.y + rng.randi_range(1, r.size.y - 2))
			if not e.sol.has(pos.y * e.largeur + pos.x) or occupees.has(pos) or pos == e.boss or pos == e.escalier or pos == e.entree:
				continue
			occupees[pos] = true
			var objets: Array = []
			for j in rng.randi_range(int(lr.objets_par_coffre[0]), int(lr.objets_par_coffre[1])):
				objets.append(_base_aleatoire(lr))
			e.coffres.append({"pos": pos, "bases": objets})


func _base_aleatoire(lr: Dictionary) -> String:
	var cats: Dictionary = lr.poids_categories
	var total := 0.0
	for c in cats.keys():
		total += float(cats[c])
	var t := rng.randf() * total
	var cat := "armes"
	for c in cats.keys():
		t -= float(cats[c])
		if t < 0.0:
			cat = c
			break
	var bases: Array = lr.get("bases_" + cat, [])
	if bases.is_empty():
		bases = lr.bases_armes
	return bases[rng.randi_range(0, bases.size() - 1)]
