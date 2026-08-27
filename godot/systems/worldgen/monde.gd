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
	if bool(e.get("a_donjon", false)):
		g.poser_contenu(base + e.entree_donjon, "entree_donjon")
	if cell == cellule_camp:
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
