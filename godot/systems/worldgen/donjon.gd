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
## Les salles PRÉFABRIQUÉES (ordre de travail 41, 2026-09-13) : `theme.prefabs` en mêle quelques-unes aux rectangles — un
## plan dessiné à la main, ses murs, ses reliefs et SES PORTES, par lesquelles arrivent les couloirs.

const H_BASE := 10                 # hauteur de référence d'un étage (Hauteur de terrain ±10)
const ESSAIS_SALLE := 12

var salles: Dictionary             # bibliothèque de prefabs (data/dungeon_rooms), posée selon `theme.prefabs`
var connecteurs: Dictionary
var theme: Dictionary
var rng := RandomNumberGenerator.new()


func _init(p_salles: Dictionary, p_connecteurs: Dictionary, p_theme: Dictionary) -> void:
	salles = p_salles
	connecteurs = p_connecteurs
	theme = p_theme


## Génère un étage : {largeur, hauteur, hauteurs, murs, sol, bord, pieces: [{id, kind, rect, attaches}],
##  entree (escalier montant), escalier (descendant, null au dernier), boss, spawns, coffres, graphe}.
## La puissance d'un etre : ce qu'il porte de force et d'endurance, sa vitesse pour moitie, un bonus
## par action speciale — un troll ne fait pas que frapper fort, il a des tours dans son sac — ET CE
## QU'IL PORTE VRAIMENT, arme et armure. Sert a decider quel etage peut l'accueillir.
##
## L'equipement manquait, et c'etait le trou par lequel passait tout le probleme du premier etage :
## un bandit en cuirasse avec une epee marquait exactement le meme score qu'un bandit a mains nues.
## Mesure du 2026-09-03 : sur la graine 73, le robot equipe mourait TROIS fois a l'etage 1 la ou la
## note du 2026-08-31 le voyait descendre quatre etages — et le meme robot sans sorts, sur la meme
## graine, en descendait deux. Ce n'etait ni l'aggro (verifie en la coupant : resultat identique),
## ni une regression recente (verifie sur le tag v0.4.1) : c'etait cette formule.
## Le bandit passe ainsi de 25 a 42 et quitte l'etage 1, dont le plafond est 26.
##
## Une arme vaut ses degats par tick ; une piece d'armure vaut un forfait, parce que sa vraie valeur
## depend du materiau, decide a l'instanciation et donc inconnu au moment du peuplement.
static func puissance_creature(c: Dictionary, bonus_action: float) -> float:
	var st: Dictionary = c.get("corps", {}).get("stats", {})
	var p := float(st.get("force", 5)) + float(st.get("endurance", 5)) + float(st.get("dexterite", 5)) * 0.5 \
		+ float((c.get("actions", []) as Array).size()) * bonus_action
	var pe: Dictionary = GameData.config("combat_rules").get("peuplement_etage", {})
	for iid in c.get("equipement", []):
		var it: Dictionary = GameData.catalogues.items.get(str(iid), {})
		if it.is_empty():
			continue
		var fo: Dictionary = GameData.catalogues.functionalities.get(str(it.get("functionality", "")), {})
		if str(fo.get("kind", "")) == "arme":
			var fr := Des.fourchette(str(fo.get("degats_des", "1d1")))
			p += float(fr.x + fr.y) * 0.5 * float(fo.get("vitesse_base", 1.0)) * float(pe.get("poids_arme", 1.0))
		else:
			p += float(pe.get("bonus_par_piece", 3.0))
	return p


## Où passe le temps d'un étage (file 109, comme Surface.chrono) : la sonde vide la table, génère, et lit les étapes.
static var chrono: Dictionary = {}
static func _top(cle: String, t0: int) -> int:
	chrono[cle] = float(chrono.get(cle, 0.0)) + float(Time.get_ticks_usec() - t0) / 1000.0
	return Time.get_ticks_usec()


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
	var t_e := Time.get_ticks_usec()
	# 1. Les salles : petites, moyennes, grandes, posées au hasard sans chevauchement.
	var essais := 0
	if dernier:   # le dernier étage essaie d'abord une salle faite pour le boss (special_tags, ordre de travail 41)
		for k_b in ESSAIS_SALLE:
			if _essayer_prefab(e, "boss_room_eligible"):
				break
	while _nb_salles(e) < nb_salles and essais < nb_salles * ESSAIS_SALLE:
		essais += 1
		if _essayer_prefab(e):
			continue
		var dim := _dimension_salle()
		if dim.x > taille - 6 or dim.y > taille - 6:
			continue
		var origine := Vector2i(rng.randi_range(2, taille - dim.x - 3), rng.randi_range(2, taille - dim.y - 3))
		var r := Rect2i(origine, dim)
		if not _libre(e, r):
			continue
		_placer_rectangle(e, r)
	# L'arène posée en premier ne doit pas devenir l'arrivée : elle passe en queue (on n'entre pas chez le boss).
	if dernier and e.pieces.size() > 1 and "boss_room_eligible" in e.pieces[0].get("tags", []):
		e.pieces.append(e.pieces.pop_front())
	# L'arrivée se fait de préférence dans une salle dessinée pour ça (`entree_eligible`) : elle passe en tête,
	# AVANT les couloirs, pour que tout ce qui lit « la première pièce » (connexité, escalier montant) la voie.
	for i_en in range(1, e.pieces.size()):
		if "entree_eligible" in e.pieces[i_en].get("tags", []):
			var p_en: Dictionary = e.pieces[i_en]
			e.pieces.remove_at(i_en)
			e.pieces.insert(0, p_en)
			break
	t_e = _top("etage.salles", t_e)
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
			var ck2 := _centre_libre(e, e.pieces[v.k])
			_tunnel(e, _ancre(e, e.pieces[i], ck2), _ancre(e, e.pieces[v.k], ci), couloirs)
	var f_boucles: Array = couloirs.get("boucles", [1, 3])
	for k in rng.randi_range(int(f_boucles[0]), int(f_boucles[1])):
		if e.pieces.size() < 2:
			break
		var a := rng.randi_range(0, e.pieces.size() - 1)
		var b := rng.randi_range(0, e.pieces.size() - 1)
		if a != b:
			var ca := _centre_libre(e, e.pieces[a])
			var cb := _centre_libre(e, e.pieces[b])
			_tunnel(e, _ancre(e, e.pieces[a], cb), _ancre(e, e.pieces[b], ca), couloirs)
	var f_impasses: Array = couloirs.get("impasses", [2, 5])
	for k in rng.randi_range(int(f_impasses[0]), int(f_impasses[1])):
		_impasse(e, couloirs)
	t_e = _top("etage.couloirs", t_e)
	# 3. Connexité.
	_reparer_connexite(e)
	t_e = _top("etage.connexite", t_e)
	# 3 bis. Les décors de salles (Génération de donjon, 2026-08-30) : piliers cassables, estrades, fosses.
	_poser_decors(e)
	t_e = _top("etage.decors", t_e)
	# 3 ter. Les portes : certaines salles ont leurs seuils fermés (theme.portes).
	_poser_portes(e)
	t_e = _top("etage.portes", t_e)
	# 4. Les escaliers : l'arrivée dans la première salle, la descente dans la plus lointaine.
	var p0: Dictionary = e.pieces[0]
	e.entree = _centre_libre(e, p0)
	e.sol[e.entree.y * taille + e.entree.x] = true
	var loin := _piece_la_plus_loin(e, e.entree, "boss_room_eligible" if dernier else "")
	if dernier:
		e.boss = _centre_libre(e, e.pieces[loin])
		e.pieces[loin]["boss_room"] = true
	else:
		e.escalier = _centre_libre(e, e.pieces[loin])
	t_e = _top("etage.escaliers", t_e)
	# 5. Peuplement, contenants, filons.
	_peupler(e, etage)
	t_e = _top("etage.peupler", t_e)
	_poser_coffres(e)
	t_e = _top("etage.coffres", t_e)
	_poser_filons(e, etage)
	t_e = _top("etage.filons", t_e)
	_poser_lave(e, etage)
	_poser_meubles_rituels(e, etage)
	_top("etage.lave_rituels", t_e)
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

## UNE SALLE PRÉFABRIQUÉE, au dé (ordre de travail 41). `theme.prefabs` : `chance` par salle posée, `max` par étage,
## `tailles` admises (les catégories du préfab), `themes` (les `floor_theme` qu'il accepte ; par défaut son propre id).
## Rend vrai si un préfab a été posé. Sans bloc `prefabs`, ne tire RIEN : l'étage d'un thème qui n'en veut pas reste
## exactement celui d'avant, dé pour dé.
## `tag` : ne tirer que parmi les préfabs qui portent ce `special_tags` — sans dé de chance, sans plafond ni filtre de
## taille (l'arène du boss est immense) : c'est le dernier étage qui la demande.
func _essayer_prefab(e: Dictionary, tag: String = "") -> bool:
	var cfg: Dictionary = theme.get("prefabs", {})
	if cfg.is_empty() or salles.is_empty():
		return false
	if tag.is_empty():
		var n_poses := 0
		for p in e.pieces:
			if p.has("prefab"):
				n_poses += 1
		if n_poses >= int(cfg.get("max", 1)) or rng.randf() >= float(cfg.get("chance", 0.0)):
			return false
	var admis: Array = cfg.get("themes", [str(theme.get("id", ""))])
	var tailles: Array = cfg.get("tailles", ["petite", "moyenne", "grande"])
	var ids: Array = []
	for id in salles.keys():
		var sd: Dictionary = salles[id]
		if str(sd.get("kind", "")) != "salle":
			continue
		if tag.is_empty() and not (str(sd.get("size_category", "")) in tailles):
			continue
		if not tag.is_empty() and not (tag in sd.get("special_tags", [])):
			continue
		for t in sd.get("floor_theme", []):
			if str(t) in admis:
				ids.append(str(id))
				break
	if ids.is_empty():
		return false
	ids.sort()   # l'ordre du catalogue n'est pas garanti : le dé doit tomber sur le même préfab à chaque génération
	var id_p: String = ids[rng.randi_range(0, ids.size() - 1)]
	var plan: Array = salles[id_p].plan
	var dim := Vector2i(str(plan[0]).length(), plan.size())
	if dim.x > e.largeur - 6 or dim.y > e.hauteur - 6:
		return false
	var r := Rect2i(Vector2i(rng.randi_range(2, e.largeur - dim.x - 3), rng.randi_range(2, e.hauteur - dim.y - 3)), dim)
	if not _libre(e, r):
		return false
	_placer_prefab(e, r, id_p)
	return true


## Estampe un plan : '.' et les chiffres sont du sol (le chiffre, une hauteur relative), N/S/E/W une porte sur le bord
## — du sol, que `_ancre` désigne aux couloirs —, X une cage d'escalier (du sol), '#' et ' ' restent du plein.
func _placer_prefab(e: Dictionary, r: Rect2i, id_p: String) -> Dictionary:
	var sd: Dictionary = salles[id_p]
	var plan: Array = sd.plan
	var ouvertures: Array = []
	for y in plan.size():
		var ligne := str(plan[y])
		for x in ligne.length():
			var c := ligne[x]
			if c == "#" or c == " ":
				continue
			var i: int = (r.position.y + y) * e.largeur + r.position.x + x
			e.sol[i] = true
			if c.is_valid_int():
				e.hauteurs[i] = clampi(H_BASE + int(c), 0, 20)
			elif c in ["N", "S", "E", "W"]:
				var dv: Vector2i = {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "W": Vector2i(-1, 0)}[c]
				ouvertures.append({"pos": r.position + Vector2i(x, y), "dir": dv})
	var piece := {"id": id_p, "kind": "salle", "rect": r, "attaches": ouvertures, "prefab": id_p,
		"tags": (sd.get("special_tags", []) as Array).duplicate()}
	e.pieces.append(piece)
	return piece


## Où un couloir rejoint une pièce : le centre d'une salle ordinaire ; pour un préfab, la tuile DEVANT la porte la plus
## proche de la destination — creusée, pour que le couloir arrive par la porte et non à travers un mur dessiné.
func _ancre(e: Dictionary, piece: Dictionary, vers: Vector2i) -> Vector2i:
	if not piece.has("prefab") or (piece.attaches as Array).is_empty():
		return _centre_libre(e, piece)
	var meilleur: Dictionary = piece.attaches[0]
	for o in piece.attaches:
		var po: Vector2i = o.pos
		var pm: Vector2i = meilleur.pos
		if absi(po.x - vers.x) + absi(po.y - vers.y) < absi(pm.x - vers.x) + absi(pm.y - vers.y):
			meilleur = o
	var dehors: Vector2i = (meilleur.pos as Vector2i) + (meilleur.dir as Vector2i)
	_creuser(e, dehors)
	return dehors


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
	if bool(theme.get("salles_carrees", false)):   # des salles carrées, pas des rectangles biscornus (designer, point 46)
		var cote := rng.randi_range(int(f[0]), int(f[1]))
		return Vector2i(cote, cote)
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
		if piece.kind != "salle" or piece.has("prefab"):
			continue   # un préfab porte ses propres reliefs : on ne lui en ajoute pas
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
	var seuils: Array = []
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
						seuils.append(p)
						break
	for p in _une_porte_par_ouverture(seuils):
		e.portes[p.y * e.largeur + p.x] = true


## Des seuils contigus forment UNE ouverture (un couloir large, un angle de salle) : elle ne reçoit qu'un
## battant, celui du milieu — deux portes côte à côte n'ont pas de sens (designer, 2026-09-01).
static func _une_porte_par_ouverture(seuils: Array) -> Array:
	var reste := seuils.duplicate()
	var portes := []
	while not reste.is_empty():
		var groupe: Array = [reste.pop_back()]
		var k := 0
		while k < groupe.size():   # propagation de proche en proche, en 4 voisins
			var a: Vector2i = groupe[k]
			for i in range(reste.size() - 1, -1, -1):
				var b: Vector2i = reste[i]
				if absi(a.x - b.x) + absi(a.y - b.y) == 1:
					groupe.append(b)
					reste.remove_at(i)
			k += 1
		groupe.sort_custom(func(u: Vector2i, v: Vector2i) -> bool: return u.y * 4096 + u.x < v.y * 4096 + v.x)
		portes.append(groupe[groupe.size() / 2])
	return portes


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
	var droit: bool = bool(couloirs.get("droits", false))   # un L franc : tout droit, un seul angle (designer, point 46)
	var garde := 0
	while p != vers and garde < e.largeur * e.hauteur:
		garde += 1
		if not droit and rng.randf() < virage:
			axe_x = not axe_x
		if axe_x and p.x == vers.x:
			axe_x = false
		elif not axe_x and p.y == vers.y:
			axe_x = true
		p += Vector2i(signi(vers.x - p.x), 0) if axe_x else Vector2i(0, signi(vers.y - p.y))
		_creuser(e, p)
		for l in range(1, largeur):   # un couloir large reste rectiligne sur toute sa largeur
			_creuser(e, p + (Vector2i(0, l) if axe_x else Vector2i(l, 0)))


## Une impasse : une marche au hasard depuis une tuile de sol.
func _impasse(e: Dictionary, couloirs: Dictionary) -> void:
	if e.sol.is_empty():
		return
	var p := _sol_au_hasard(e)
	if p.x < 0:
		return
	var longueurs: Array = couloirs.get("impasse_longueur", [4, 12])
	var d: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi_range(0, 3)]
	var droit: bool = bool(couloirs.get("droits", false))
	var larg_b: Array = couloirs.get("largeur", [1, 2])
	var lb := rng.randi_range(int(larg_b[0]), int(larg_b[1]))
	for k in rng.randi_range(int(longueurs[0]), int(longueurs[1])):
		if not droit and rng.randf() < float(couloirs.get("virage", 0.25)):
			d = Vector2i(d.y, d.x) * (1 if rng.randf() < 0.5 else -1)
		p += d
		if p.x <= 1 or p.y <= 1 or p.x >= e.largeur - 2 or p.y >= e.hauteur - 2:
			return
		_creuser(e, p)
		for l in range(1, lb):   # un branchement a la largeur d'un couloir
			_creuser(e, p + (Vector2i(0, l) if d.x != 0 else Vector2i(l, 0)))


## Une tuile de sol au hasard, tirée dans une pièce plutôt qu'en recopiant tout le dictionnaire :
## avec les salles immenses (designer 2026-08-31), `e.sol.keys()` faisait des milliers d'entrées par appel.
func _sol_au_hasard(e: Dictionary) -> Vector2i:
	if not e.pieces.is_empty():
		for essai in 24:
			var r: Rect2i = e.pieces[rng.randi_range(0, e.pieces.size() - 1)].rect
			var p := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
			if e.sol.has(p.y * e.largeur + p.x):
				return p
	var cles: Array = e.sol.keys()
	if cles.is_empty():
		return Vector2i(-1, -1)
	var idx: int = cles[rng.randi_range(0, cles.size() - 1)]
	return Vector2i(idx % e.largeur, idx / e.largeur)


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
		var vu_a: PackedByteArray = atteint.vu
		var repare := false
		for p in e.pieces:
			var c := _centre_libre(e, p)
			if vu_a[c.y * e.largeur + c.x] == 0:
				_tranchee(e, c, _plus_proche_atteint(e, c, atteint.ordre))
				repare = true
		if not repare:
			return


## Le BFS d'un étage sur des TABLEAUX COMPACTS (2026-09-07) : un curseur au lieu de `pop_front` (qui décale toute la
## file à chaque pas), des index plutôt que des Vector2i, et un octet par tuile au lieu d'un dictionnaire — le hachage
## de trois mille clés coûtait plus que le parcours lui-même. Même ordre de visite, même résultat ; 6,5 → moins de 1 ms.
func _bfs(e: Dictionary, depart: Vector2i) -> Dictionary:
	var n: int = e.largeur * e.hauteur
	var vu := PackedByteArray()
	vu.resize(n)
	var sol := PackedByteArray()   # `e.sol` est un dictionnaire : on le lit UNE fois, pas quatre fois par tuile
	sol.resize(n)
	for i in e.sol.keys():
		sol[int(i)] = 1
	var i0: int = depart.y * e.largeur + depart.x
	vu[i0] = 1
	var file := PackedInt32Array()
	file.append(i0)
	var tete := 0
	var larg: int = e.largeur
	var haut: int = e.hauteur
	while tete < file.size():
		var ci: int = file[tete]
		tete += 1
		var cx: int = ci % larg
		@warning_ignore("integer_division")
		var cy: int = ci / larg
		# Les quatre voisins déroulés, dans l'ordre de `dirs` (est, ouest, sud, nord) : écrire `[1, -1, 0, 0][k]`
		# alloue un tableau à CHAQUE tuile visitée — mesuré, c'était plus cher que le dictionnaire qu'on remplaçait.
		if cx + 1 < larg and sol[ci + 1] != 0 and vu[ci + 1] == 0:
			vu[ci + 1] = 1
			file.append(ci + 1)
		if cx - 1 >= 0 and sol[ci - 1] != 0 and vu[ci - 1] == 0:
			vu[ci - 1] = 1
			file.append(ci - 1)
		if cy + 1 < haut and sol[ci + larg] != 0 and vu[ci + larg] == 0:
			vu[ci + larg] = 1
			file.append(ci + larg)
		if cy - 1 >= 0 and sol[ci - larg] != 0 and vu[ci - larg] == 0:
			vu[ci - larg] = 1
			file.append(ci - larg)
	# `ordre` est la file elle-même : les tuiles dans l'ordre où le BFS les a atteintes — c'est-à-dire l'ordre
	# qu'avaient les clés du dictionnaire d'avant. `_plus_proche_atteint` départage à égalité de distance par
	# le PREMIER rencontré : sans cet ordre, les mêmes graines ne rendraient plus les mêmes étages.
	return {"vu": vu, "ordre": file}


func _plus_proche_atteint(e: Dictionary, c: Vector2i, ordre: PackedInt32Array) -> Vector2i:
	var meilleur := c
	var dmin := 1 << 30
	for idx in ordre:
		@warning_ignore("integer_division")
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


## `tag` : si une pièce (hors la première) porte ce `special_tags`, on ne choisit que parmi elles.
func _piece_la_plus_loin(e: Dictionary, depart: Vector2i, tag: String = "") -> int:
	# Distance de marche (BFS) : la salle la plus lointaine reçoit l'escalier ou le boss.
	# Les mêmes tableaux compacts que `_bfs` : la distance en int32, la file en index (2026-09-07).
	var n: int = e.largeur * e.hauteur
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var sol := PackedByteArray()
	sol.resize(n)
	for i_s in e.sol.keys():
		sol[int(i_s)] = 1
	var larg: int = e.largeur
	var haut: int = e.hauteur
	var i0: int = depart.y * larg + depart.x
	dist[i0] = 0
	var file := PackedInt32Array()
	file.append(i0)
	var tete := 0
	while tete < file.size():
		var ci: int = file[tete]
		tete += 1
		var cx: int = ci % larg
		@warning_ignore("integer_division")
		var cy: int = ci / larg
		var dc: int = dist[ci]
		if cx + 1 < larg and sol[ci + 1] != 0 and dist[ci + 1] < 0:
			dist[ci + 1] = dc + 1
			file.append(ci + 1)
		if cx - 1 >= 0 and sol[ci - 1] != 0 and dist[ci - 1] < 0:
			dist[ci - 1] = dc + 1
			file.append(ci - 1)
		if cy + 1 < haut and sol[ci + larg] != 0 and dist[ci + larg] < 0:
			dist[ci + larg] = dc + 1
			file.append(ci + larg)
		if cy - 1 >= 0 and sol[ci - larg] != 0 and dist[ci - larg] < 0:
			dist[ci - larg] = dc + 1
			file.append(ci - larg)
	var meilleur := 0
	var dmax := -1
	var marquees := false
	if not tag.is_empty():
		for i_t in range(1, e.pieces.size()):
			if tag in e.pieces[i_t].get("tags", []):
				marquees = true
	for i in range(1, e.pieces.size()):
		if marquees and not (tag in e.pieces[i].get("tags", [])):
			continue
		var c := _centre_libre(e, e.pieces[i])
		var d: int = int(dist[c.y * larg + c.x])
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
	# Qui a le droit d'être là (designer 2026-09-02 : « premier étage : ennemis très bas niveau »). Le
	# pool d'un thème va du rat géant au troll, et le PREMIER étage y puisait comme le dixième : on
	# pouvait tomber sur un lindworm au premier pas. Chaque étage a désormais son plafond de puissance.
	var pe: Dictionary = GameData.config("combat_rules").get("peuplement_etage", {})
	var plafond := float(pe.get("puissance_base", 22)) + float(pe.get("puissance_par_etage", 9)) * float(maxi(0, etage - 1))
	var bonus_a := float(pe.get("bonus_par_action", 4))
	var pool_etage: Array = []
	var plus_faible: Dictionary = {}
	var p_faible := INF
	for c in pool:
		var fiche: Dictionary = GameData.entree("creatures", str(c.id))
		var puiss := puissance_creature(fiche, bonus_a)
		if puiss < p_faible:
			p_faible = puiss
			plus_faible = c
		if puiss <= plafond:
			pool_etage.append(c)
	if pool_etage.is_empty():   # un étage vide n'est pas un étage : le plus faible du thème y reste
		pool_etage.append(plus_faible)
	var facteur: float = 1.0 + float(etage) * float(theme.get("croissance_par_etage", 0.25))
	for i in e.pieces.size():
		var p: Dictionary = e.pieces[i]
		if i == 0:
			continue
		var r: Rect2i = p.rect
		var n := maxi(1, int(floorf(float(r.size.x * r.size.y) / float(theme.get("tuiles_par_creature", 64)) * facteur)))   # au moins un occupant par salle
		# … et jamais plus que le plafond de l'étage (designer 2026-09-05 : « retravaille les spawns ») : une salle immense
		# en tirait vingt-deux au premier étage, quand le joueur de niveau 0 n'en tue pas un.
		n = mini(n, int(pe.get("max_par_salle_base", 2)) + int(pe.get("max_par_salle_par_etage", 1)) * maxi(0, etage - 1))
		if p.get("boss_room", false):
			var boss: String = str(theme.get("boss", ""))
			if not boss.is_empty():
				# Le boss est MARQUÉ (2026-09-08) : le code se servait de `chain_gauge` — le drapeau de la jauge de
				# chaîne Wu Xing — pour dire « c'est le boss », et trois créatures le portent (aventurier, brute,
				# chef de bande). Une brute de couloir valait donc un boss.
				e.spawns.append({"creature": boss, "pos": e.boss, "boss": true})
		var poses := {}
		for k in n:
			var c: Dictionary = pool_etage[rng.randi_range(0, pool_etage.size() - 1)]
			var pos := Vector2i(r.position.x + rng.randi_range(1, r.size.x - 2), r.position.y + rng.randi_range(1, r.size.y - 2))
			if not e.sol.has(pos.y * e.largeur + pos.x) or poses.has(pos) or pos == e.boss or pos == e.escalier:
				continue
			if int(e.hauteurs[pos.y * e.largeur + pos.x]) != H_BASE:
				continue   # jamais dans une fosse (prison sans chemin) ni sur une estrade — le décor se conquiert, il ne se naît pas
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
		if "treasure_eligible" in p.get("tags", []):   # une salle dessinée pour un trésor en garde un de plus (ordre de travail 41)
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
