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
	if cell == cellule_camp:
		g.poser_contenu(base + e.entree_donjon, "entree_donjon")
		if not decouvert.has(cell):   # sa cellule, on la connaît (Claims et persistance)
			var tout := {}
			for i in taille * taille:
				tout[i] = true
			decouvert[cell] = tout
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
