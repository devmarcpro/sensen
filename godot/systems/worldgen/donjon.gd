class_name Donjon
extends RefCounted
## Génération d'un étage de donjon, **procédurale façon Elin / Tales of Maj'Eyal** (décisions du
## designer, 2026-08-27 — Génération de donjon) : une cellule de 128×128 (Grille continue), à étages,
## deux escaliers par étage (un vers le haut, un vers le bas), murs destructibles.
##   1. des salles de tailles variées (petites, moyennes, grandes — `tailles_salles` du thème,
##      tirées selon `poids_salles`) sont posées au hasard sans chevauchement ;
##   2. des **couloirs sinueux** relient chaque salle à ses `voisins_relies` plus proches voisines
##      (réseau maillé, pas une chaîne), puis des boucles entre salles au hasard et des impasses ;
##   3. connexité vérifiée par BFS et réparée par une tranchée droite si besoin ;
##   4. l'escalier montant (l'arrivée) dans une salle, l'escalier descendant dans la salle la plus
##      lointaine ; le boss au dernier étage y remplace l'escalier ;
##   5. peuplement par le thème, contenants de loot.
## Déterministe par seed(monde, id_donjon, étage) : chaque étage est différent, stable au retour.
## Le plein est du mur (destructible) ; le bord de la cellule est de la roche (indestructible).
## La bibliothèque de prefabs (salles, connecteurs) reste en données, non posée.

const H_BASE := 10                 # hauteur de référence d'un étage (Hauteur de terrain ±10)
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
func generer_etage(graine: int, id_donjon: int, etage: int, nb_salles: int, dernier: bool, taille: int = -1) -> Dictionary:
	if taille < 0:
		taille = int(GameData.config("planete").taille_cellule)   # un étage = une cellule (Grille continue)
	rng.seed = hash([graine, id_donjon, etage])
	var e := {"largeur": taille, "hauteur": taille, "hauteurs": PackedByteArray(), "murs": {}, "sol": {}, "bord": {},
		"pieces": [], "entree": Vector2i.ZERO, "escalier": null, "boss": null, "spawns": [], "coffres": [], "filons": {}, "graphe": {}, "etage": etage}
	e.hauteurs.resize(taille * taille)
	e.hauteurs.fill(H_BASE)
	for i in taille:
		for b in [Vector2i(i, 0), Vector2i(i, taille - 1), Vector2i(0, i), Vector2i(taille - 1, i)]:
			e.bord[b.y * taille + b.x] = true
	# 1. Les salles : petites, moyennes, grandes, posées au hasard sans chevauchement.
	var essais := 0
	while _nb_salles(e) < nb_salles and essais < nb_salles * ESSAIS_SALLE:
		essais += 1
		var dim := _dimension_salle()
		if dim.x > taille - 6 or dim.y > taille - 6:
			continue
		var origine := Vector2i(rng.randi_range(2, taille - dim.x - 3), rng.randi_range(2, taille - dim.y - 3))
		var r := Rect2i(origine, dim)
		if not _libre(e, r):
			continue
		_placer_rectangle(e, r)
	# 2. Les couloirs : chaque salle vers ses plus proches voisines (réseau maillé), puis des
	#    boucles et des impasses — plusieurs chemins mènent partout.
	var couloirs: Dictionary = theme.get("couloirs", {})
	var nb_voisins: int = int(couloirs.get("voisins_relies", 3))
	var relies := {}
	for i in e.pieces.size():
		var ci := _centre_libre(e, e.pieces[i])
		var autres: Array = []
		for k in e.pieces.size():
			if k != i:
				var ck := _centre_libre(e, e.pieces[k])
				autres.append({"k": k, "d": absi(ck.x - ci.x) + absi(ck.y - ci.y)})
		autres.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.d < b.d)
		for v in autres.slice(0, nb_voisins):
			var cle := Vector2i(mini(i, v.k), maxi(i, v.k))
			if relies.has(cle):
				continue
			relies[cle] = true
			_tunnel(e, ci, _centre_libre(e, e.pieces[v.k]), couloirs)
	var f_boucles: Array = couloirs.get("boucles", [1, 3])
	for k in rng.randi_range(int(f_boucles[0]), int(f_boucles[1])):
		if e.pieces.size() < 2:
			break
		var a := rng.randi_range(0, e.pieces.size() - 1)
		var b := rng.randi_range(0, e.pieces.size() - 1)
		if a != b:
			_tunnel(e, _centre_libre(e, e.pieces[a]), _centre_libre(e, e.pieces[b]), couloirs)
	var f_impasses: Array = couloirs.get("impasses", [2, 5])
	for k in rng.randi_range(int(f_impasses[0]), int(f_impasses[1])):
		_impasse(e, couloirs)
	# 3. Connexité.
	_reparer_connexite(e)
	# 3 bis. Les décors de salles (Génération de donjon, 2026-08-30) : piliers cassables, estrades, fosses.
	_poser_decors(e)
	# 3 ter. Les portes : certaines salles ont leurs seuils fermés (theme.portes).
	_poser_portes(e)
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
	# 5. Peuplement, contenants, filons.
	_peupler(e, etage)
	_poser_coffres(e)
	_poser_filons(e, etage)
	_poser_lave(e, etage)
	_poser_meubles_rituels(e, etage)
	return e


## Les meubles de race cachée dans les étages profonds (Talents de race) : un au plus, loin des points fixes.
func _poser_meubles_rituels(e: Dictionary, etage: int) -> void:
	var mr: Dictionary = GameData.config("combat_rules").get("talents", {}).get("meubles_rituels", {})
	if etage < int(mr.get("etage_min", 4)) or rng.randf() >= float(mr.get("chance", 0.35)):
		return
	var sols: Array = e.sol.keys()
	if sols.is_empty():
		return
	e["meubles"] = e.get("meubles", {})
	var id: String = "source_maudite" if rng.randf() < 0.5 else "autel_rituel"
	for essai in 60:
		var idx: int = int(sols[rng.randi_range(0, sols.size() - 1)])
		var p := Vector2i(idx % e.largeur, idx / e.largeur)
		if Grille.distance(p, e.entree) < 6:
			continue
		if e.escalier != null and Grille.distance(p, e.escalier) < 6:
			continue
		var libre := true
		for c in e.coffres:
			if c.pos == p:
				libre = false
		if libre and not e.meubles.has(idx):
			e.meubles[idx] = id
			return


## Des mares de lave dans les étages profonds (Eau et liquides) : des tuiles de sol, loin des points fixes.
func _poser_lave(e: Dictionary, etage: int) -> void:
	var lv: Dictionary = GameData.config("combat_rules").get("lave", {})
	if etage < int(lv.get("etage_min", 5)):
		return
	var interdits := {}
	for pt in [e.entree, e.escalier, e.boss]:
		if pt != null:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					interdits[(pt.y + dy) * e.largeur + pt.x + dx] = true
	for c in e.coffres:
		interdits[c.pos.y * e.largeur + c.pos.x] = true
	var mares: Array = lv.get("mares", [1, 3])
	var tailles: Array = lv.get("taille", [6, 20])
	e["lave"] = {}
	var sols: Array = e.sol.keys()   # la marche part d'une tuile de sol : au hasard dans la grille, elle tomberait dans la roche
	if sols.is_empty():
		return
	for k in rng.randi_range(int(mares[0]), int(mares[1])):
		var depart: int = int(sols[rng.randi_range(0, sols.size() - 1)])
		var p := Vector2i(depart % e.largeur, depart / e.largeur)
		var reste := rng.randi_range(int(tailles[0]), int(tailles[1]))
		for pas in reste * 20:
			var idx: int = p.y * e.largeur + p.x
			if e.sol.has(idx) and not interdits.has(idx) and not e.lave.has(idx):
				e.lave[idx] = true
				reste -= 1
				if reste <= 0:
					break
			var libres: Array[Vector2i] = []   # la marche reste sur le sol : sinon elle se perd dans la roche
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if q.x >= 2 and q.y >= 2 and q.x < e.largeur - 2 and q.y < e.hauteur - 2 and e.sol.has(q.y * e.largeur + q.x):
					libres.append(q)
			if libres.is_empty():
				break
			p = libres[rng.randi_range(0, libres.size() - 1)]


# ---------------------------------------------------------------- salles

## Tire une catégorie de salle selon `poids_salles`, puis une dimension dans sa fourchette.
func _dimension_salle() -> Vector2i:
	var tailles: Dictionary = theme.get("tailles_salles", {"petite": [3, 5], "moyenne": [6, 9], "grande": [10, 16]})
	var poids: Dictionary = theme.get("poids_salles", {"petite": 4, "moyenne": 3, "grande": 1})
	var total := 0.0
	for k in tailles.keys():
		total += float(poids.get(k, 1))
	var t := rng.randf() * total
	var cat: String = tailles.keys()[0]
	for k in tailles.keys():
		t -= float(poids.get(k, 1))
		if t < 0.0:
			cat = k
			break
	var f: Array = tailles[cat]
	return Vector2i(rng.randi_range(int(f[0]), int(f[1])), rng.randi_range(int(f[0]), int(f[1])))


func _libre(e: Dictionary, r: Rect2i) -> bool:
	if r.position.x < 2 or r.position.y < 2 or r.end.x > e.largeur - 2 or r.end.y > e.hauteur - 2:
		return false
	for p in e.pieces:
		if p.rect.grow(2).intersects(r):
			return false
	return true


## Une salle procédurale : un rectangle de sol.
func _placer_rectangle(e: Dictionary, r: Rect2i) -> Dictionary:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			e.sol[y * e.largeur + x] = true
	var taille_max: int = maxi(r.size.x, r.size.y)
	var cat := "petite" if taille_max <= 5 else ("moyenne" if taille_max <= 9 else "grande")
	var piece := {"id": "salle_%s_%dx%d" % [cat, r.size.x, r.size.y], "kind": "salle", "rect": r, "attaches": []}
	e.pieces.append(piece)
	return piece


## Les décors des salles moyennes et grandes, au dé selon `theme.decors` : des piliers (murs du thème, destructibles),
## une estrade (hauteur +1/+2) ou une fosse (hauteur −chute_delta). Le centre reste libre, les bords aussi.
func _poser_decors(e: Dictionary) -> void:
	var regles: Array = theme.get("decors", [])
	if regles.is_empty():
		return
	var reliefs := 0
	var plus_grande: Dictionary = {}
	for piece in e.pieces:
		if piece.kind != "salle":
			continue
		var r: Rect2i = piece.rect
		if mini(r.size.x, r.size.y) < 5:
			continue   # une petite salle reste nue
		var centre := _centre_libre(e, piece)
		var interieur := Rect2i(r.position + Vector2i(1, 1), r.size - Vector2i(2, 2))
		if plus_grande.is_empty() or r.get_area() > (plus_grande.rect as Rect2i).get_area():
			plus_grande = piece
		for d in regles:
			if rng.randf() >= float(d.get("chance", 0.0)):
				continue
			match str(d.get("type", "")):
				"piliers":
					var f_n: Array = d.get("n", [1, 3])
					for k in rng.randi_range(int(f_n[0]), int(f_n[1])):
						var p := Vector2i(rng.randi_range(interieur.position.x, interieur.end.x - 1), rng.randi_range(interieur.position.y, interieur.end.y - 1))
						if Grille.distance(p, centre) <= 1 or _pilier_voisin(e, p):
							continue
						e.sol.erase(p.y * e.largeur + p.x)
						e.murs[p.y * e.largeur + p.x] = true
				"estrade", "fosse":
					var f_t: Array = d.get("taille", [2, 3])
					var dim := Vector2i(rng.randi_range(int(f_t[0]), int(f_t[1])), rng.randi_range(int(f_t[0]), int(f_t[1])))
					if dim.x > interieur.size.x - 1 or dim.y > interieur.size.y - 1:
						continue
					var o := Vector2i(rng.randi_range(interieur.position.x, interieur.end.x - dim.x), rng.randi_range(interieur.position.y, interieur.end.y - dim.y))
					var zone := Rect2i(o, dim)
					if zone.has_point(centre):
						continue   # le centre reste plat : escaliers, boss, spawns
					var delta: int = int(d.get("delta", 1))
					for y in range(zone.position.y, zone.end.y):
						for x in range(zone.position.x, zone.end.x):
							if e.sol.has(y * e.largeur + x):
								e.hauteurs[y * e.largeur + x] = clampi(H_BASE + delta, 0, 20)
								reliefs += 1
	if reliefs == 0 and not plus_grande.is_empty():   # un étage a toujours au moins un relief : une estrade dans la plus grande salle
		var rg: Rect2i = plus_grande.rect
		var cg := _centre_libre(e, plus_grande)
		var zone_g := Rect2i(rg.position + Vector2i(1, 1), Vector2i(2, 2))
		if zone_g.has_point(cg):
			zone_g.position = rg.end - Vector2i(3, 3)
		for y in range(zone_g.position.y, zone_g.end.y):
			for x in range(zone_g.position.x, zone_g.end.x):
				if e.sol.has(y * e.largeur + x) and Vector2i(x, y) != cg:
					e.hauteurs[y * e.largeur + x] = H_BASE + 1


## Les seuils d'une salle : ses tuiles de sol du bord qui touchent un couloir (du sol hors de la salle). Une salle
## tirée au sort (theme.portes) les reçoit fermés — e.portes, posés par Grille.depuis_etage.
func _poser_portes(e: Dictionary) -> void:
	var chance: float = float(theme.get("portes", 0.0))
	if chance <= 0.0:
		return
	e["portes"] = {}
	for piece in e.pieces:
		if piece.kind != "salle" or rng.randf() >= chance:
			continue
		var r: Rect2i = piece.rect
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if x != r.position.x and x != r.end.x - 1 and y != r.position.y and y != r.end.y - 1:
					continue   # seulement le bord
				var p := Vector2i(x, y)
				if not e.sol.has(p.y * e.largeur + p.x):
					continue
				for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + dv
					if not r.has_point(q) and e.sol.has(q.y * e.largeur + q.x):
						e.portes[p.y * e.largeur + p.x] = true
						break


## Un pilier ne touche pas un autre pilier ni un mur : on peut toujours le contourner.
func _pilier_voisin(e: Dictionary, p: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := p + Vector2i(dx, dy)
			if q == p:
				continue
			var i: int = q.y * int(e.largeur) + q.x
			if not e.sol.has(i) or e.murs.has(i):
				return true
	return false


func _nb_salles(e: Dictionary) -> int:
	var n := 0
	for p in e.pieces:
		if p.kind == "salle":
			n += 1
	return n


# ---------------------------------------------------------------- couloirs

## Un couloir sinueux de `de` vers `vers` : à chaque pas on avance sur l'axe courant, avec une
## chance de `virage` de changer d'axe ; largeur 1 ou 2 tuiles.
func _tunnel(e: Dictionary, de: Vector2i, vers: Vector2i, couloirs: Dictionary) -> void:
	var virage: float = float(couloirs.get("virage", 0.25))
	var largeurs: Array = couloirs.get("largeur", [1, 2])
	var largeur := rng.randi_range(int(largeurs[0]), int(largeurs[1]))
	var p := de
	var axe_x := absi(vers.x - p.x) >= absi(vers.y - p.y)
	var garde := 0
	while p != vers and garde < e.largeur * e.hauteur:
		garde += 1
		if rng.randf() < virage:
			axe_x = not axe_x
		if axe_x and p.x == vers.x:
			axe_x = false
		elif not axe_x and p.y == vers.y:
			axe_x = true
		p += Vector2i(signi(vers.x - p.x), 0) if axe_x else Vector2i(0, signi(vers.y - p.y))
		_creuser(e, p)
		if largeur > 1:
			_creuser(e, p + (Vector2i(0, 1) if axe_x else Vector2i(1, 0)))


## Une impasse : une marche au hasard depuis une tuile de sol.
func _impasse(e: Dictionary, couloirs: Dictionary) -> void:
	if e.sol.is_empty():
		return
	var cles: Array = e.sol.keys()
	var idx: int = cles[rng.randi_range(0, cles.size() - 1)]
	var p := Vector2i(idx % e.largeur, idx / e.largeur)
	var longueurs: Array = couloirs.get("impasse_longueur", [4, 12])
	var d: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi_range(0, 3)]
	for k in rng.randi_range(int(longueurs[0]), int(longueurs[1])):
		if rng.randf() < float(couloirs.get("virage", 0.25)):
			d = Vector2i(d.y, d.x) * (1 if rng.randf() < 0.5 else -1)
		p += d
		if p.x <= 1 or p.y <= 1 or p.x >= e.largeur - 2 or p.y >= e.hauteur - 2:
			return
		_creuser(e, p)


func _creuser(e: Dictionary, p: Vector2i) -> void:
	if p.x > 0 and p.y > 0 and p.x < e.largeur - 1 and p.y < e.hauteur - 1:
		e.sol[p.y * e.largeur + p.x] = true


# ---------------------------------------------------------------- connexité

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


## Filons muraux (Minerais par profondeur) : les tiers de la bande d'étage, plus les fossiles aux
## premiers étages et les matériaux propres au thème. Un filon = un amas de tuiles de mur.
func _poser_filons(e: Dictionary, etage: int) -> void:
	var mp: Dictionary = GameData.config("minerais_par_etage")
	var pool: Array = []
	for b in mp.bandes_etage:
		if etage >= int(b.etages[0]) and etage <= int(b.etages[1]):
			for t in range(int(b.tiers[0]), int(b.tiers[1]) + 1):
				pool.append_array(mp.tiers[str(t)])
	var fo: Dictionary = mp.fossiles
	if etage >= int(fo.etages[0]) and etage <= int(fo.etages[1]):
		pool.append_array(fo.materiaux)
	pool.append_array(mp.get("par_theme", {}).get(theme.id, []))
	if pool.is_empty():
		return
	var facteur := 1.0 + float(etage - 1) * float(mp.croissance_par_etage)
	var nb := int(float(rng.randi_range(int(mp.filons_par_etage[0]), int(mp.filons_par_etage[1]))) * facteur)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for k in nb:
		var mat: String = pool[rng.randi_range(0, pool.size() - 1)]
		var p := Vector2i(rng.randi_range(2, e.largeur - 3), rng.randi_range(2, e.hauteur - 3))
		var taille := rng.randi_range(int(mp.taille_filon[0]), int(mp.taille_filon[1]))
		for pas in taille * 3:
			var idx: int = p.y * e.largeur + p.x
			if not e.sol.has(idx) and not e.bord.has(idx) and not e.filons.has(idx):
				e.filons[idx] = mat
				taille -= 1
				if taille <= 0:
					break
			var d: Vector2i = dirs[rng.randi_range(0, 3)]
			p += d
			if p.x < 2 or p.y < 2 or p.x > e.largeur - 3 or p.y > e.hauteur - 3:
				break


func _base_aleatoire(lr: Dictionary) -> String:
	var cats: Dictionary = lr.categories
	var total := 0.0
	for c in cats.keys():
		total += float(cats[c].poids)
	var t := rng.randf() * total
	var cat := str(cats.keys()[0])
	for c in cats.keys():
		t -= float(cats[c].poids)
		if t < 0.0:
			cat = str(c)
			break
	# Une CATÉGORIE, pas une liste d'ids : tout objet qui répond au filtre entre dans le loot du jour où il existe.
	var choisi := GameData.tirer("items", cats[cat].filtre, rng)
	if choisi.is_empty():
		choisi = GameData.tirer("items", cats[cats.keys()[0]].filtre, rng)
	return choisi
