class_name Monde
extends RefCounted
## Le monde de surface comme **fenêtre glissante** sur des cellules générées (Grille continue :
## « on marche d'une cellule à l'autre sans rupture ; les chunks se génèrent devant et se déchargent
## derrière » ; Sauvegarde : « seed + liste des modifications »). La grille active couvre les
## (2 × rayon + 1)² cellules autour de celle du joueur, en **coordonnées monde** (Grille.origine) :
## aucune position ne bouge quand la fenêtre se recentre. Ce qui n'est pas regénérable est capturé
## par cellule : modifications de tuiles, tuiles découvertes, contenants, êtres endormis hors fenêtre.
## Les cellules voisines se pré-génèrent en thread.

var surface: Surface
var planete: Dictionary
var camp_cfg: Dictionary
var cellule_camp: Vector2i
var taille: int
var rayon: int = 1
var centre: Vector2i = Vector2i(-1, -1)
var cellules: Dictionary = {}          # Vector2i → cellule générée (Surface.generer_cellule)
var modifications: Dictionary = {}     # Vector2i → {idx local: {h, contenu, materiau, meuble, station, sol}}
var decouvert: Dictionary = {}         # Vector2i → {idx local: true}
var contenants_hors: Dictionary = {}   # Vector2i → {idx local: [uids]}
var dormants: Dictionary = {}          # Vector2i → [êtres] hors fenêtre
var explores: Dictionary = {}          # Vector2i (chunk de 32) → true : bit d'exploration (minimap, sauvegardé)
var teintes: Dictionary = {}           # Vector2i (chunk) → Color : teinte dominante, calculée une fois
var delta: Dictionary = {}             # Vector2i (cellule) → int : dérive de la corruption, borné (sauvegardé)
var foyers: Dictionary = {}            # Vector2i (cellule) → {actif, majeur, generation, repit, nettoye_tick} (donjons connus)
var semaine_courante: int = 0          # dernière semaine passée (ticks / ticks_par_semaine)
var grille_active: Grille = null       # la fenêtre courante, pour effacer une entrée après la grâce
var peuplees: Dictionary = {}          # Vector2i (cellule) → true : ses PNJ ont été instanciés (première visite)
var claims: Dictionary = {}            # Vector2i (cellule) → {role} : le territoire du joueur (Expansion territoriale)
var vacances: Dictionary = {}          # id de royaume → semaine de résolution : trône vacant (Familles et succession)
var villages: Dictionary = {}          # nom de village → {cellule, royaume, conquis_par, defense_jusqua, abandonne} (Conquête de village)
var mutex := Mutex.new()
var tache: int = -1                    # tâche WorkerThreadPool de pré-génération en cours (−1 : aucune)


func _init(p_surface: Surface, p_planete: Dictionary, p_camp: Dictionary) -> void:
	surface = p_surface
	planete = p_planete
	camp_cfg = p_camp
	taille = int(planete.taille_cellule)
	cellule_camp = Vector2i(int(planete.cellule_depart[0]), int(planete.cellule_depart[1]))


func cellule_de(p: Vector2i) -> Vector2i:
	return Vector2i(floori(float(p.x) / float(taille)), floori(float(p.y) / float(taille)))


func pos_monde(cell: Vector2i, local: Vector2i) -> Vector2i:
	return cell * taille + local


func idx_local(p: Vector2i) -> int:
	var l := p - cellule_de(p) * taille
	return l.y * taille + l.x


## La cellule (générée à la demande, mise en cache — le thread de pré-génération y contribue).
func cellule(c: Vector2i) -> Dictionary:
	mutex.lock()
	var e: Dictionary = cellules.get(c, {})
	mutex.unlock()
	if not e.is_empty():
		return e
	e = surface.generer_cellule(c.x, c.y, camp_cfg if c == cellule_camp else {}, false)
	mutex.lock()
	cellules[c] = e
	mutex.unlock()
	return e


## Construit la grille-fenêtre centrée sur `c` : (2r+1)² cellules, en coordonnées monde.
func fenetre(c: Vector2i, contenus: Dictionary, regles_dep: Dictionary, oeil: int) -> Grille:
	centre = c
	var n := 2 * rayon + 1
	var g := Grille.new(n * taille, n * taille)
	g.origine = (c - Vector2i(rayon, rayon)) * taille
	g.contenu_defs = contenus
	g.dep = regles_dep
	g.hauteur_oeil = oeil
	g.materiau_defaut = "pierre"
	for dy in range(-rayon, rayon + 1):
		for dx in range(-rayon, rayon + 1):
			var cell := c + Vector2i(dx, dy)
			_poser_cellule(g, cell, cellule(cell))
	grille_active = g
	return g


## Copie une cellule dans la fenêtre : hauteurs, sol, contenus générés, puis les modifications et les
## découvertes mémorisées de cette cellule.
func _poser_cellule(g: Grille, cell: Vector2i, e: Dictionary) -> void:
	var base := pos_monde(cell, Vector2i.ZERO)
	for i in taille * taille:
		var p := base + Vector2i(i % taille, i / taille)
		var gi := g.idx(p)
		g.hauteurs[gi] = e.hauteurs[i]
		if e.sols.has(i):
			g.sols[gi] = e.sols[i]
	for i in e.arbres.keys():
		var p := base + Vector2i(int(i) % taille, int(i) / taille)
		g.materiaux[g.idx(p)] = e.arbres[i]
		g.poser_contenu(p, "arbre")
	for i in e.rochers.keys():
		var p := base + Vector2i(int(i) % taille, int(i) / taille)
		g.materiaux[g.idx(p)] = e.rochers[i]
		g.poser_contenu(p, "mur")
	for i in e.filons.keys():
		var p := base + Vector2i(int(i) % taille, int(i) / taille)
		g.materiaux[g.idx(p)] = e.filons[i]
		g.poser_contenu(p, "filon")
	for i in e.get("plantes", {}).keys():
		var p := base + Vector2i(int(i) % taille, int(i) / taille)
		g.materiaux[g.idx(p)] = e.plantes[i]
		g.poser_contenu(p, "plante")
	for i in e.get("eau", {}).keys():
		g.poser_contenu(base + Vector2i(int(i) % taille, int(i) / taille), "eau")
	for i in e.get("murs", {}).keys():   # les bâtiments du hameau
		var p := base + Vector2i(int(i) % taille, int(i) / taille)
		g.materiaux[g.idx(p)] = e.murs[i]
		g.poser_contenu(p, "mur_construit")
	for i in e.get("portes", {}).keys():
		g.poser_contenu(base + Vector2i(int(i) % taille, int(i) / taille), "porte")
	for i in e.get("meubles", {}).keys():
		var p := base + Vector2i(int(i) % taille, int(i) / taille)
		var m: Dictionary = GameData.catalogues.meubles.get(str(e.meubles[i]), {})
		g.meubles[g.idx(p)] = str(e.meubles[i])
		g.poser_contenu(p, "meuble" if bool(m.get("bloque_passage", true)) else "meuble_sol")
	if bool(e.get("a_donjon", false)):
		g.poser_contenu(base + e.entree_donjon, "entree_donjon")
		foyer(cell)   # le donjon devient un foyer connu de la dérive
	if cell == cellule_camp:
		if not claims.has(cell):
			claims[cell] = {"role": "base"}
		if not decouvert.has(cell):   # sa cellule, on la connaît (Claims et persistance) — tuiles et chunks
			var tout := {}
			for i in taille * taille:
				tout[i] = true
			decouvert[cell] = tout
			for cy in taille / 32:
				for cx in taille / 32:
					explores[Vector2i(cell.x * (taille / 32) + cx, cell.y * (taille / 32) + cy)] = true
	# Les modifications (seed + liste des modifications) puis les découvertes.
	for i in modifications.get(cell, {}).keys():
		var m: Dictionary = modifications[cell][i]
		var p := base + Vector2i(int(i) % taille, int(i) / taille)
		var gi := g.idx(p)
		g.hauteurs[gi] = int(m.h)
		g.contenu[gi] = 0
		g.materiaux.erase(gi)
		g.meubles.erase(gi)
		g.stations_fixes.erase(gi)
		if not str(m.contenu).is_empty():
			g.poser_contenu(p, str(m.contenu))
		if not str(m.materiau).is_empty():
			g.materiaux[gi] = str(m.materiau)
		if not str(m.meuble).is_empty():
			g.meubles[gi] = str(m.meuble)
		if not str(m.station).is_empty():
			g.stations_fixes[gi] = str(m.station)
	for i in decouvert.get(cell, {}).keys():
		g.decouvert[g.idx(base + Vector2i(int(i) % taille, int(i) / taille))] = true
	g.modifies.clear()


## Capture ce que la fenêtre a changé : tuiles modifiées et découvertes, par cellule.
func capturer(g: Grille) -> void:
	for gi in g.modifies.keys():
		var p := g.pos_de(int(gi))
		var cell := cellule_de(p)
		if not modifications.has(cell):
			modifications[cell] = {}
		var c := g.contenu_de(p)
		modifications[cell][idx_local(p)] = {"h": g.h(p), "contenu": str(g.contenu_ids[g.contenu[gi]]) if g.contenu[gi] > 0 else "",
			"materiau": str(g.materiaux.get(gi, "")), "meuble": str(g.meubles.get(gi, "")), "station": str(g.stations_fixes.get(gi, "")), "sol": str(g.sols.get(gi, ""))}
	for gi in g.decouvert.keys():
		var p := g.pos_de(int(gi))
		var cell := cellule_de(p)
		if not decouvert.has(cell):
			decouvert[cell] = {}
		decouvert[cell][idx_local(p)] = true
	g.modifies.clear()


## Marque explorés les chunks touchés par un champ de vue ; retourne ceux qui viennent de l'être.
func explorer(vue: Dictionary, g: Grille) -> Array[Vector2i]:
	var nouveaux: Array[Vector2i] = []
	for gi in vue.keys():
		var p := g.pos_de(int(gi))
		var ch := Vector2i(floori(float(p.x) / 32.0), floori(float(p.y) / 32.0))
		if not explores.has(ch):
			explores[ch] = true
			nouveaux.append(ch)
	return nouveaux


## La teinte dominante d'un chunk de 32×32 : matériau de sol majoritaire (eau : bleu), ombré par la
## hauteur moyenne ; calculée une fois depuis la cellule générée.
func couleur_chunk(ch: Vector2i) -> Color:
	if teintes.has(ch):
		return teintes[ch]
	var cell := Vector2i(floori(float(ch.x * 32) / float(taille)), floori(float(ch.y * 32) / float(taille)))
	var e := cellule(cell)
	var base := ch * 32 - cell * taille
	var comptes := {}
	var eau := 0
	var somme_h := 0
	for y in 32:
		for x in 32:
			var i := (base.y + y) * taille + base.x + x
			somme_h += int(e.hauteurs[i])
			if e.eau.has(i):
				eau += 1
			else:
				var m: String = str(e.sols.get(i, "terre"))
				comptes[m] = int(comptes.get(m, 0)) + 1
	var col := Color(0.18, 0.35, 0.6)
	if eau < 512:
		var meilleur := ""
		var n := -1
		for m in comptes.keys():
			if int(comptes[m]) > n:
				n = int(comptes[m])
				meilleur = m
		var mat: Dictionary = GameData.catalogues.materials.get(meilleur, {})
		col = Color.html(str(mat.color)) if not mat.is_empty() else Color(0.4, 0.5, 0.3)
		if meilleur.begins_with("terre"):
			col = col.lerp(Color(0.35, 0.5, 0.25), 0.35)
		if e.arbres.size() > 300:
			col = col.lerp(Color(0.2, 0.4, 0.15), 0.3)
	var h_moy := float(somme_h) / 1024.0
	col = col.darkened(clampf((10.0 - h_moy) * 0.06, -0.3, 0.4)) if h_moy < 10.0 else col.lightened(clampf((h_moy - 10.0) * 0.05, 0.0, 0.3))
	teintes[ch] = col
	return col


# ---------------------------------------------------------------- dérive de la corruption (E.20)

func _cr() -> Dictionary:
	return planete.get("corruption", {})


## Le foyer d'une cellule à donjon (créé à la première demande) ; {} si la cellule n'en a pas.
func foyer(cell: Vector2i) -> Dictionary:
	if foyers.has(cell):
		return foyers[cell]
	if not surface.poi_de(cell, cell == cellule_camp).donjon:
		return {}
	foyers[cell] = {"actif": true, "majeur": surface.danger_de(cell) >= 2, "generation": 0, "repit": 0, "nettoye_tick": -1}
	return foyers[cell]


## Corruption effective d'une cellule (0-100) : le bruit de danger plus le delta.
func corruption_de(cell: Vector2i) -> float:
	var taille_c: int = taille
	var d := surface.valeur("danger", cell.x * taille_c + taille_c / 2, cell.y * taille_c + taille_c / 2) * 100.0
	return clampf(d + float(delta.get(cell, 0)), 0.0, 100.0)


## Le niveau de danger affiché (0 paisible, 1 dangereuse, 2 mortelle) à partir de la corruption effective.
func danger_de(cell: Vector2i) -> int:
	var seuils: Array = planete.get("danger", {}).get("seuils", [0.45, 0.75])
	var c := corruption_de(cell) / 100.0
	return 2 if c >= float(seuils[1]) else (1 if c >= float(seuils[0]) else 0)


func _ajouter_delta(cell: Vector2i, n: int) -> void:
	var cr := _cr()
	delta[cell] = clampi(int(delta.get(cell, 0)) + n, int(cr.get("delta_min", -40)), int(cr.get("delta_max", 40)))
	if delta[cell] == 0:
		delta.erase(cell)


## Les cellules que la dérive simule (LOD) : les explorées et leurs voisines.
func _cellules_simulees() -> Dictionary:
	var res := {}
	var n := taille / 32
	var cellules_explorees := {}
	for ch in explores.keys():
		cellules_explorees[Vector2i(floori(float(ch.x) / n), floori(float(ch.y) / n))] = true
	for cell in cellules_explorees.keys():
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				res[cell + Vector2i(dx, dy)] = true
	return res


## Le passage hebdomadaire : infection des foyers actifs, répit et repeuplement des foyers nettoyés,
## décroissance loin des foyers, effet civilisateur du camp. Retourne les cellules touchées.
func semaine(tick: int) -> Array[Vector2i]:
	var cr := _cr()
	var touchees: Array[Vector2i] = []
	var cellules := _cellules_simulees()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([surface.graine, "semaine", tick])
	var actifs := {}
	for cell in cellules.keys():
		var f := foyer(cell)
		if f.is_empty():
			continue
		if bool(f.actif):
			actifs[cell] = true
			var plafond := int(cr.get("plafond_majeur", 25)) if bool(f.majeur) else int(cr.get("plafond_mineur", 10))
			if int(delta.get(cell, 0)) < plafond:
				_ajouter_delta(cell, int(cr.get("infection_cellule", 2)))
				touchees.append(cell)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var v: Vector2i = cell + Vector2i(dx, dy)
					if v != cell and int(delta.get(v, 0)) < plafond:
						_ajouter_delta(v, int(cr.get("infection_voisines", 1)))
		else:
			if int(f.repit) > 0:
				f.repit = int(f.repit) - 1
			elif rng.randf() < corruption_de(cell) / 100.0:   # repeuplement ∝ corruption locale restante
				f.actif = true
				f.generation = int(f.generation) + 1
				f.majeur = danger_de(cell) >= 2
				f.nettoye_tick = -1
				touchees.append(cell)
				_reposer_entree(cell)
	for cell in cellules.keys():
		if not delta.has(cell):
			continue
		var proche := false
		for a in actifs.keys():
			if absi(a.x - cell.x) <= 2 and absi(a.y - cell.y) <= 2:
				proche = true
				break
		if not proche:
			_ajouter_delta(cell, -signi(int(delta.get(cell, 0))) * int(cr.get("decroissance", 1)))
	for dy in range(-1, 2):   # le camp, zone civilisée
		for dx in range(-1, 2):
			var v := cellule_camp + Vector2i(dx, dy)
			if v != cellule_camp and delta.has(v) and int(delta[v]) > 0:
				_ajouter_delta(v, -int(cr.get("civilisation", 1)))
	return touchees


## Le boss d'un donjon est vaincu : le foyer s'endort (répit), la corruption recule, la grâce commence.
func nettoyer(cell: Vector2i, tick: int) -> void:
	var f := foyer(cell)
	if f.is_empty() or not bool(f.actif):
		return
	var cr := _cr()
	f.actif = false
	f.repit = int(cr.get("repit_majeur", 12)) if bool(f.majeur) else int(cr.get("repit_mineur", 4))
	f.nettoye_tick = tick
	_ajouter_delta(cell, int(cr.get("nettoyage_cellule", -8)))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dy != 0:
				_ajouter_delta(cell + Vector2i(dx, dy), int(cr.get("nettoyage_voisines", -3)))


## Le donjon d'une cellule est-il ouvert (actif, ou nettoyé depuis moins que la grâce) ?
func donjon_ouvert(cell: Vector2i, tick: int) -> bool:
	var f := foyer(cell)
	if f.is_empty():
		return false
	if bool(f.actif):
		return true
	return int(f.nettoye_tick) >= 0 and tick - int(f.nettoye_tick) < int(_cr().get("grace_ticks", 36000))


## Le tick du monde : les grâces échues effacent l'entrée de la fenêtre (et de la cellule mémorisée).
func tick(t: int) -> Array[Vector2i]:
	var disparues: Array[Vector2i] = []
	for cell in foyers.keys():
		var f: Dictionary = foyers[cell]
		if bool(f.actif) or int(f.nettoye_tick) < 0 or bool(f.get("effacee", false)):
			continue
		if t - int(f.nettoye_tick) >= int(_cr().get("grace_ticks", 36000)):
			f["effacee"] = true
			_effacer_entree(cell)
			disparues.append(cell)
	return disparues


func _effacer_entree(cell: Vector2i) -> void:
	var e := cellule(cell)
	var pe: Vector2i = e.entree_donjon
	var base := pos_monde(cell, Vector2i.ZERO)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var l := pe + Vector2i(dx, dy)
			var i := l.y * taille + l.x
			e.rochers.erase(i)
			e.sol[i] = true
			if not modifications.has(cell):
				modifications[cell] = {}
			modifications[cell][i] = {"h": int(e.hauteurs[i]), "contenu": "", "materiau": "", "meuble": "", "station": "", "sol": str(e.sols.get(i, ""))}
			if grille_active != null and grille_active.dans(base + l):
				var gi := grille_active.idx(base + l)
				grille_active.contenu[gi] = 0
				grille_active.materiaux.erase(gi)
	e["a_donjon"] = false


func _reposer_entree(cell: Vector2i) -> void:
	var e := cellule(cell)
	var f := foyer(cell)
	f.erase("effacee")
	var pe: Vector2i = e.entree_donjon
	var base := pos_monde(cell, Vector2i.ZERO)
	e["a_donjon"] = true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var l: Vector2i = pe + Vector2i(dx, dy)
			var i := l.y * taille + l.x
			var centre_ou_sud := (dx == 0 and dy == 0) or (dx == 0 and dy == 1)
			if not centre_ou_sud:
				e.rochers[i] = "pierre"
				e.sol.erase(i)
			modifications.get(cell, {}).erase(i)
			if grille_active != null and grille_active.dans(base + l):
				var gi := grille_active.idx(base + l)
				if centre_ou_sud:
					if dx == 0 and dy == 0:
						grille_active.poser_contenu(base + l, "entree_donjon")
				else:
					grille_active.materiaux[gi] = "pierre"
					grille_active.poser_contenu(base + l, "mur")


## Une cellule est-elle revendicable : contiguë au territoire, explorée, de terre, sans donjon actif ni village.
func revendicable(cell: Vector2i, tick: int) -> bool:
	if claims.has(cell) or not surface.terre_a(cell) or not cellule_exploree(cell):
		return false
	var contigue := false
	for c in claims.keys():
		if absi(c.x - cell.x) <= 1 and absi(c.y - cell.y) <= 1 and c != cell:
			contigue = true
	if not contigue:
		return false
	if donjon_ouvert(cell, tick):
		return false
	if bool(surface.poi_de(cell).get("village", false)):
		return false
	return true


## Une cellule est explorée si l'un de ses chunks l'est (carte du monde, voyage rapide).
func cellule_exploree(cell: Vector2i) -> bool:
	var n := taille / 32
	for cy in n:
		for cx in n:
			if explores.has(Vector2i(cell.x * n + cx, cell.y * n + cy)):
				return true
	return false


## Le point marchable le plus proche du centre d'une cellule (Début de partie), en coordonnées monde.
func point_marchable(cell: Vector2i) -> Vector2i:
	var e := cellule(cell)
	var centre_l := Vector2i(taille / 2, taille / 2)
	for r in 40:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var l := centre_l + Vector2i(dx, dy)
				if l.x < 1 or l.y < 1 or l.x >= taille - 1 or l.y >= taille - 1:
					continue
				var i := l.y * taille + l.x
				if e.sol.has(i) and not e.get("plantes", {}).has(i):
					return pos_monde(cell, l)
	return pos_monde(cell, centre_l)


func dans_fenetre(p: Vector2i) -> bool:
	var c := cellule_de(p)
	return absi(c.x - centre.x) <= rayon and absi(c.y - centre.y) <= rayon


## Pré-génère en thread (WorkerThreadPool) les cellules voisines manquantes autour du centre.
func pregenerer_voisins() -> void:
	if tache >= 0:
		if not WorkerThreadPool.is_task_completed(tache):
			return
		WorkerThreadPool.wait_for_task_completion(tache)
		tache = -1
	var manquantes: Array[Vector2i] = []
	for dy in range(-rayon - 1, rayon + 2):
		for dx in range(-rayon - 1, rayon + 2):
			var cell := centre + Vector2i(dx, dy)
			if not cellules.has(cell):
				manquantes.append(cell)
	if manquantes.is_empty():
		return
	tache = WorkerThreadPool.add_task(_generer_en_thread.bind(manquantes), false, "Sensen : pré-génération de cellules")


func _generer_en_thread(liste: Array[Vector2i]) -> void:
	for cell in liste:
		cellule(cell)


## Attend la fin de la pré-génération (tests, fermeture).
func fermer() -> void:
	if tache >= 0:
		WorkerThreadPool.wait_for_task_completion(tache)
		tache = -1
