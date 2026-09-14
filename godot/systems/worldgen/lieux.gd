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
## LES LIEUX NÉS DE LA SIMULATION (39 ter, pas F — 2026-09-14) : id → lieu. La graine pose les ruines ; la simulation, elle,
## fait naître une tanière où les prédateurs prolifèrent, et la retire quand on l'a nettoyée. Ceux-là se sauvegardent.
var nes: Dictionary = {}
var _n_nes := 0
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
	var res: Array = _cache.get(sect, [])
	var connu := _cache.has(sect)
	_mutex.unlock()
	if not connu:
		res = _generer(sect)
		_mutex.lock()
		_cache[sect] = res
		_mutex.unlock()
	if nes.is_empty():
		return res
	var tout := res.duplicate()
	for l in nes.values():
		if secteur_de_tuile(l.centre, int(surface.planete.taille_cellule)) == sect:
			tout.append(l)
	return tout


## FAIRE NAÎTRE UN LIEU (2026-09-14) : un lieu que la simulation pose là où elle en a besoin — il vit dans le registre
## comme les autres (la rumeur en parle, le voyage le fait découvrir, la carte le montre, la fenêtre le peuple).
func naitre(type: String, sous_type: String, centre: Vector2i, cote: int, tick: int) -> Dictionary:
	var tc := int(surface.planete.taille_cellule)
	var sect := secteur_de_tuile(centre, tc)
	var id := "lieu:%d,%d:ne%d" % [sect.x, sect.y, _n_nes]
	while nes.has(id):
		_n_nes += 1
		id = "lieu:%d,%d:ne%d" % [sect.x, sect.y, _n_nes]
	_n_nes += 1
	var lieu := {"id": id, "type": type, "sous_type": sous_type, "emprise": Rect2i(centre - Vector2i(cote / 2, cote / 2), Vector2i(cote, cote)),
		"centre": centre, "biome": surface.biome_a(centre.x, centre.y), "graine": hash([surface.graine, "ne", id, tick]), "ne_tick": tick}
	nes[id] = lieu
	return lieu


func retirer(id: String) -> void:
	nes.erase(id)


## Pour la sauvegarde : l'emprise en nombres (le format ne sait pas écrire un Rect2i).
func nes_serialise() -> Dictionary:
	var d := {}
	for id in nes.keys():
		var l: Dictionary = nes[id].duplicate()
		var r: Rect2i = l.emprise
		l.emprise = [r.position.x, r.position.y, r.size.x, r.size.y]
		d[id] = l
	return d


func nes_charger(d: Dictionary) -> void:
	nes.clear()
	for id in d.keys():
		var l: Dictionary = (d[id] as Dictionary).duplicate()
		var e: Array = l.get("emprise", [0, 0, 1, 1])
		l.emprise = Rect2i(int(e[0]), int(e[1]), int(e[2]), int(e[3]))
		l.centre = Vector2i(l.centre)
		nes[str(id)] = l
	_n_nes = nes.size()


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


# ---------------------------------------------------------------- l'estampage (39 ter, pas B — 2026-09-13)

var _plans: Dictionary = {}   # id de lieu → plan


## LE PLAN D'UN LIEU, en coordonnées MONDE : position → [genre, valeur]. Les genres sont ceux qu'un morceau sait poser :
## `mur` (matière), `rocher` (matière), `porte`, `sol` (matière de sol), `meuble` (id), `entree` (l'entrée d'un donjon),
## `degage` (on arrache l'arbre ou la roche, rien de plus). Calculé une fois à la graine du lieu : deux morceaux qui le
## recoupent lisent exactement le même, et c'est ce qui rend l'estampage sans couture.
func plan(lieu: Dictionary) -> Dictionary:
	var id := str(lieu.get("id", ""))
	_mutex.lock()
	if _plans.has(id):
		var deja: Dictionary = _plans[id]
		_mutex.unlock()
		return deja
	_mutex.unlock()
	var p := _tracer(lieu)
	_mutex.lock()
	_plans[id] = p
	_mutex.unlock()
	return p


func _tracer(lieu: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(lieu.graine)
	var r: Rect2i = lieu.emprise
	var p := {}
	var pierre := "granit" if rng.randf() < 0.5 else "calcaire"
	match str(lieu.type):
		"ruine":
			_degager_rect(p, r)
			match str(lieu.sous_type):
				"tour_effondree":
					_anneau(p, r.get_center(), mini(r.size.x, r.size.y) / 2 - 1, "mur", pierre, 0.55, rng)
				"pont_brise":
					var y0 := r.get_center().y
					for x in range(r.position.x, r.end.x):
						for dy in [-1, 1]:
							if rng.randf() < 0.5:
								p[Vector2i(x, y0 + dy)] = ["mur", pierre]
						if rng.randf() < 0.7:
							p[Vector2i(x, y0)] = ["sol", "calcaire"]
				_:
					_contour(p, r.grow(-1), "mur", pierre, 0.45, rng)
					if str(lieu.sous_type) != "hameau_abandonne" and r.size.x > 14 and r.size.y > 14:
						_contour(p, r.grow(-5), "mur", pierre, 0.35, rng)   # le fort et le temple : une enceinte, et un cœur
			for y in range(r.position.y + 2, r.end.y - 2):
				for x in range(r.position.x + 2, r.end.x - 2):
					var q := Vector2i(x, y)
					if p.has(q) and str(p[q][0]) != "degage":
						continue
					var t := rng.randf()
					if t < 0.08:
						p[q] = ["rocher", pierre]   # les gravats
					elif t < 0.45:
						p[q] = ["sol", "calcaire"]   # le dallage qui reste
		"donjon_batiment":
			var cote := mini(mini(r.size.x, r.size.y) - 4, 11)
			var b := Rect2i(r.get_center() - Vector2i(cote / 2, cote / 2), Vector2i(cote, cote))
			_degager_rect(p, r)
			var matiere := "chene" if str(lieu.sous_type) == "mine_abandonnee" else pierre
			var genre := "rocher" if str(lieu.sous_type) in ["mine_abandonnee", "grotte_inondee"] else "mur"
			if str(lieu.sous_type) == "grotte_inondee":
				_anneau(p, b.get_center(), cote / 2, "rocher", pierre, 1.0, rng)
			else:
				_contour(p, b, genre, matiere, 1.0, rng)
			for y in range(b.position.y + 1, b.end.y - 1):
				for x in range(b.position.x + 1, b.end.x - 1):
					var q2 := Vector2i(x, y)
					if not p.has(q2) or str(p[q2][0]) == "degage":
						p[q2] = ["sol", "calcaire"]
			var porte := Vector2i(b.get_center().x, b.end.y - 1)
			p[porte] = ["porte", ""] if genre == "mur" else ["sol", "calcaire"]
			p[porte + Vector2i(0, 1)] = ["sol", "calcaire"]
			match str(lieu.sous_type):
				"crypte":
					for k in 4:
						p[b.position + Vector2i(2 + k * 2, 2)] = ["meuble", "tombe"]
				"temple_enfoui":
					p[b.position + Vector2i(2, 2)] = ["meuble", "statue"]
					p[Vector2i(b.end.x - 3, b.position.y + 2)] = ["meuble", "statue"]
				"mine_abandonnee":
					p[porte + Vector2i(-1, -1)] = ["meuble", "etai"]
					p[porte + Vector2i(1, -1)] = ["meuble", "etai"]
			p[b.get_center()] = ["entree", str(lieu.id)]
		"hameau":
			_degager_rect(p, r)
			var n := 2 + rng.randi() % 3
			var centre := r.get_center()
			p[centre] = ["meuble", "puits"]
			var coins := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
			for k in n:
				var d: Vector2i = coins[k]
				var o := centre + Vector2i(d.x * 3 + (0 if d.x > 0 else -6), d.y * 3 + (0 if d.y > 0 else -5))
				var maison := Rect2i(o, Vector2i(6, 5))
				if not r.encloses(maison):
					continue
				_contour(p, maison, "mur", "chene", 1.0, rng)
				for y in range(maison.position.y + 1, maison.end.y - 1):
					for x in range(maison.position.x + 1, maison.end.x - 1):
						p[Vector2i(x, y)] = ["sol", "chene"]
				var pm := Vector2i(maison.get_center().x, maison.end.y - 1 if d.y < 0 else maison.position.y)
				p[pm] = ["porte", ""]
				p[maison.position + Vector2i(1, 1)] = ["meuble", "lit_de_paille"]
		"camp":
			_degager_rect(p, r)
			var c := r.get_center()
			p[c] = ["meuble", "torchere"]
			for k in 3 + rng.randi() % 3:
				var a := TAU * float(k) / 5.0 + rng.randf() * 0.5
				p[c + Vector2i(roundi(cos(a) * 3.0), roundi(sin(a) * 3.0))] = ["meuble", "lit_de_paille"]
			if str(lieu.sous_type) == "bandits":
				p[c + Vector2i(0, -2)] = ["meuble", "coffre"]
			_anneau(p, c, mini(r.size.x, r.size.y) / 2 - 1, "rocher", pierre, 0.35, rng)
		"sanctuaire":
			var c2 := r.get_center()
			match str(lieu.sous_type):
				"cercle_de_pierres":
					_anneau(p, c2, mini(r.size.x, r.size.y) / 2 - 1, "rocher", pierre, 0.7, rng)
				_:
					p[c2 + Vector2i(-2, 0)] = ["meuble", "statue"]
					p[c2 + Vector2i(2, 0)] = ["meuble", "statue"]
			p[c2] = ["meuble", "bassin" if str(lieu.sous_type) == "source_sacree" else "autel_rituel"]
	return p


static func _degager_rect(p: Dictionary, r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			p[Vector2i(x, y)] = ["degage", ""]


static func _contour(p: Dictionary, r: Rect2i, genre: String, matiere: String, garde: float, rng: RandomNumberGenerator) -> void:
	for x in range(r.position.x, r.end.x):
		for y in [r.position.y, r.end.y - 1]:
			if rng.randf() < garde:
				p[Vector2i(x, y)] = [genre, matiere]
	for y in range(r.position.y + 1, r.end.y - 1):
		for x in [r.position.x, r.end.x - 1]:
			if rng.randf() < garde:
				p[Vector2i(x, y)] = [genre, matiere]


static func _anneau(p: Dictionary, c: Vector2i, rayon: int, genre: String, matiere: String, garde: float, rng: RandomNumberGenerator) -> void:
	if rayon < 2:
		return
	var vus := {}
	for k in rayon * 8:
		var a := TAU * float(k) / float(rayon * 8)
		var q := c + Vector2i(roundi(cos(a) * rayon), roundi(sin(a) * rayon))
		if vus.has(q):
			continue
		vus[q] = true
		if rng.randf() < garde:
			p[q] = [genre, matiere]


## ESTAMPER UN MORCEAU : la part de chaque lieu qui recoupe la cellule `cell`, écrite dans le dictionnaire de cellule de
## `Surface.generer_cellule`. On ne pose rien sur l'eau ; une entrée de donjon est notée dans `entrees_lieux`.
func estamper(e: Dictionary, cell: Vector2i) -> void:
	var tc := int(surface.planete.taille_cellule)
	var base := cell * tc
	var rect := Rect2i(base, Vector2i(tc, tc))
	for lieu in dans(rect):
		var pl := plan(lieu)
		for q: Vector2i in pl.keys():
			if not rect.has_point(q):
				continue
			var l := q - base
			var i := l.y * tc + l.x
			if e.get("eau", {}).has(i):
				continue
			var v: Array = pl[q]
			match str(v[0]):
				"degage":
					e.arbres.erase(i)
					e.rochers.erase(i)
					e.filons.erase(i)
					e.plantes.erase(i)
					e.get("cueillette", {}).erase(i)
				"mur":
					Surface._degager_tuile(e, i)
					e.murs[i] = str(v[1])
					e.sol.erase(i)
				"rocher":
					Surface._degager_tuile(e, i)
					e.rochers[i] = str(v[1])
				"porte":
					Surface._degager_tuile(e, i)
					e.portes[i] = true
				"sol":
					Surface._degager_tuile(e, i)
					e.sols[i] = str(v[1])
				"meuble":
					if GameData.catalogues.meubles.has(str(v[1])):
						Surface._degager_tuile(e, i)
						e.meubles[i] = str(v[1])
				"entree":
					Surface._degager_tuile(e, i)
					if not e.has("entrees_lieux"):
						e["entrees_lieux"] = {}
					e.entrees_lieux[i] = str(v[1])


# ---------------------------------------------------------------- les habitants (39 ter, pas D — 2026-09-14)

## Qui vit dans ce lieu : la liste `habitants` de son sous-type, sinon de son type.
static func habitants_de(lieu: Dictionary) -> Array:
	var h: Dictionary = _cfg().get("habitants", {})
	return h.get(str(lieu.type) + "/" + str(lieu.sous_type), h.get(str(lieu.type), []))


## PEUPLER LES LIEUX DE LA FENÊTRE : une fois par lieu, quand son centre y entre. Les lits du plan logent les habitants,
## la place est le centre du lieu, le poste une tuile libre autour.
static func peupler(sim: Simulation) -> void:
	_peupler(sim)


## UN HABITANT EST MORT (2026-09-14) : le dernier habitant d'un lieu né de la simulation emporte le lieu avec lui — une
## tanière nettoyée n'est plus une tanière, et sa cellule s'en ressent.
static func habitant_mort(sim: Simulation, x: Dictionary) -> void:
	if sim.monde == null:
		return
	var id := str(x.get("lieu", ""))
	var reg: Lieux = sim.monde.surface.lieux()
	if id.is_empty() or not reg.nes.has(id) or not bool(reg.nes[id].get("se_vide", str(reg.nes[id].type) == "taniere")):
		return   # les corbeaux d'un champ de bataille ne font pas le champ : il s'efface avec ses morts, pas avec eux
	for y in sim.vivants():
		if str(y.get("lieu", "")) == id:
			return
	var lieu: Dictionary = reg.nes[id]
	reg.retirer(id)
	sim.monde.peuplees.erase(id)
	sim.monde.lieux_connus.erase(id)
	if str(lieu.type) == "taniere":
		var cell := sim.monde.cellule_de(lieu.centre)
		var i := SimEcologie.indices(sim, cell)
		SimEcologie._poser(sim, cell, float(i.proies), float(i.predateurs) - float(SimEcologie._cfg().get("tanieres", {}).get("nettoyee", 0.6)))
		EventBus.emettre(&"journal", [&"journal.taniere_nettoyee", {"lieu": "lieu.sous_type." + str(lieu.sous_type)}])


## La fenêtre chargée, en tuiles monde ; vide hors du monde de surface. Un lieu né ne naît ni ne meurt dedans.
static func fenetre(sim: Simulation) -> Rect2i:
	if sim.lieu == "camp" and sim.grille != null:
		return Rect2i(sim.grille.origine, Vector2i(sim.grille.largeur, sim.grille.hauteur_grille))
	return Rect2i()


## LES LIEUX QUI S'EFFACENT (2026-09-14) : un lieu né avec une échéance (`expire_tick`) disparaît quand elle est passée —
## hors de la vue du joueur.
static func expirer(sim: Simulation) -> void:
	if sim.monde == null:
		return
	var reg: Lieux = sim.monde.surface.lieux()
	var f := fenetre(sim)
	for id in reg.nes.keys().duplicate():
		var l: Dictionary = reg.nes[id]
		if l.has("expire_tick") and sim.horloge_monde.ticks >= int(l.expire_tick) and not f.has_point(l.centre):
			reg.retirer(str(id))
			sim.monde.peuplees.erase(str(id))
			sim.monde.lieux_connus.erase(str(id))


## LES MORTS D'UN LIEU (2026-09-14) : au premier passage, des corps morts depuis la naissance du lieu — ils ont pourri
## depuis ce jour-là — et qui lâchent leur butin. Sur un champ de bataille, ils portent les couleurs des deux camps.
static func poser_morts(sim: Simulation, lieu: Dictionary) -> int:
	var m: Array = _cfg().get("morts", {}).get(str(lieu.type), [])
	if m.is_empty():
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(lieu.graine), "morts"])
	var roys: Array = lieu.get("royaumes", [])
	var r: Rect2i = lieu.emprise
	var n := 0
	for spec in m:
		if not GameData.catalogues.creatures.has(str(spec[0])):
			continue
		for k in rng.randi_range(int(spec[1]), int(spec[2])):
			var pos := sim._tuile_libre_autour(Vector2i(r.position.x + rng.randi_range(1, maxi(1, r.size.x - 2)), r.position.y + rng.randi_range(1, maxi(1, r.size.y - 2))))
			if not sim.grille.dans(pos):
				continue
			var x := SimObjets.ajouter(sim, str(spec[0]), pos, "ia")
			if x.is_empty():
				continue
			if not roys.is_empty():
				x["royaume"] = str(roys[n % roys.size()])
			x.vivant = false
			x.sante = 0
			x["mort_tick"] = int(lieu.get("ne_tick", sim.horloge_monde.ticks))
			sim.grille.liberer(x.pos, x.id)
			SimObjets._drop(sim, x, "")
			n += 1
	return n


static func _peupler(sim: Simulation) -> void:
	if sim.monde == null or sim.grille == null:
		return
	var rect := Rect2i(sim.grille.origine, Vector2i(sim.grille.largeur, sim.grille.hauteur_grille))
	var reg: Lieux = sim.monde.surface.lieux()
	for lieu in reg.dans(rect):
		var id := str(lieu.id)
		if not rect.has_point(lieu.centre):
			continue
		sim.monde.lieux_connus[id] = true   # passé dans les parages, on sait qu'il est là : la carte le montre
		if sim.monde.peuplees.has(id):
			continue
		sim.monde.peuplees[id] = true
		poser_tresors(sim, lieu)   # une ruine garde ses coffres (2026-09-14)
		poser_morts(sim, lieu)   # un champ de bataille, ses morts (2026-09-14)
		var liste := habitants_de(lieu)
		if liste.is_empty():
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(lieu.graine), "habitants"])
		var pl := reg.plan(lieu)
		var lits: Array = []
		for q: Vector2i in pl.keys():
			if str(pl[q][0]) == "meuble" and str(pl[q][1]).begins_with("lit"):
				lits.append(q)
		lits.sort()
		var k_lit := 0
		for spec in liste:
			if not GameData.catalogues.creatures.has(str(spec[0])):
				continue
			for n in rng.randi_range(int(spec[1]), int(spec[2])):
				var pos := sim._tuile_libre_autour(lieu.centre)
				if not sim.grille.dans(pos):
					continue
				var x := SimObjets.ajouter(sim, str(spec[0]), pos, "ia")
				if x.is_empty():
					continue
				x["lieu"] = id
				if lieu.has("royaume"):
					x["royaume"] = str(lieu.royaume)   # un déserteur porte encore la bannière qu'il a quittée
				x["place"] = lieu.centre
				x["poste"] = sim._tuile_libre_autour(lieu.centre + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4)))
				if k_lit < lits.size():
					x["lit"] = lits[k_lit]
					k_lit += 1
				x.ancre = x.poste if sim.grille.dans(x.poste) else pos


## LES TRÉSORS D'UN LIEU (2026-09-14) : au premier passage, des coffres dans son emprise, remplis comme ceux d'un donjon —
## la même table (`loot_rules.contenants`), au niveau du monde. Explorer une ruine rapporte.
static func poser_tresors(sim: Simulation, lieu: Dictionary) -> int:
	var t: Dictionary = _cfg().get("tresors", {})
	var bornes: Array = t.get(str(lieu.type) + "/" + str(lieu.sous_type), t.get(str(lieu.type), []))
	if bornes.size() < 2:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(lieu.graine), "tresors"])
	var lr: Dictionary = GameData.config("loot_rules").get("contenants", {})
	var cats: Dictionary = lr.get("categories", {})
	if cats.is_empty():
		return 0
	var r: Rect2i = lieu.emprise
	var n := 0
	for k in rng.randi_range(int(bornes[0]), int(bornes[1])):
		var pos := Vector2i(r.position.x + rng.randi_range(2, maxi(2, r.size.x - 3)), r.position.y + rng.randi_range(2, maxi(2, r.size.y - 3)))
		if not sim.grille.dans(pos) or sim.grille.bloque_passage(pos) or sim.contenants.has(sim.grille.idx(pos)):
			continue
		var uids: Array = []
		for j in rng.randi_range(int(lr.get("objets_par_coffre", [1, 3])[0]), int(lr.get("objets_par_coffre", [1, 3])[1])):
			var total := 0.0
			for c in cats.keys():
				total += float(cats[c].poids)
			var tir := rng.randf() * total
			var cat := str(cats.keys()[0])
			for c in cats.keys():
				tir -= float(cats[c].poids)
				if tir < 0.0:
					cat = str(c)
					break
			var base := GameData.tirer("items", cats[cat].filtre, rng)
			if base.is_empty():
				continue
			var o := SimObjets.generer_objet(sim, base, SimObjets.niveau_loot(sim), {"lieu": str(lieu.id)})
			if not o.is_empty():
				uids.append(o.uid)
		if not uids.is_empty():
			SimObjets._poser_contenant(sim, pos, uids, "coffre")
			n += 1
	return n
