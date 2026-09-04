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
var _amorce := Vector2i(-9999, -9999)   # la cellule du donjon garanti du début de partie (point 51)
var nettoyages: Dictionary = {}   # cellule → jour du dernier nettoyage (donjons de corruption, point 51)
var taille: int
var rayon: int = 1
var centre: Vector2i = Vector2i(-1, -1)
var cellules: Dictionary = {}          # Vector2i → cellule générée (Surface.generer_cellule)
var modifications: Dictionary = {}     # Vector2i → {idx local: {h, contenu, materiau, meuble, station, sol}}
var decouvert: Dictionary = {}         # Vector2i → {idx local: true}
var contenants_hors: Dictionary = {}   # Vector2i → {idx local: [uids]}
var dormants: Dictionary = {}          # Vector2i → [êtres] hors fenêtre
var faune_densite: Dictionary = {}     # Vector2i (cellule) → float < 1 : la faune raréfiée par la chasse (Créatures, 2026-09-04 ; sauvegardé)
var explores: Dictionary = {}          # Vector2i (chunk de 32) → true : bit d'exploration (minimap, sauvegardé)
var teintes: Dictionary = {}           # Vector2i (chunk) → Color : teinte dominante, calculée une fois
# La carte du monde se REDESSINAIT entièrement à chaque ouverture : vingt-cinq sondes de tectonique par
# cellule, sur toutes les cellules de la vue, à chaque image. Le relief d'une cellule ne change jamais —
# il se calcule donc une fois et se garde, ici et dans la sauvegarde (designer 2026-09-02).
var carte_cache: Dictionary = {}       # Vector2i (cellule) → PackedByteArray : un octet d'altitude par sous-point
var carte_cache_sp: int = 0            # le nombre de sous-points par côté du cache : s'il change, le cache est périmé
var delta: Dictionary = {}             # Vector2i (cellule) → int : dérive de la corruption, borné (sauvegardé)
var foyers: Dictionary = {}            # Vector2i (cellule) → {actif, majeur, generation, repit, nettoye_tick} (donjons connus)
var semaine_courante: int = 0          # dernière semaine passée (ticks / ticks_par_semaine)
var jour_monde: int = 0                # le jour courant, poussé par la simulation : `foyer()` doit savoir si la cellule est cristallisée AUJOURD'HUI (designer 2026-09-02)
var grille_active: Grille = null       # la fenêtre courante, pour effacer une entrée après la grâce
var peuplees: Dictionary = {}          # Vector2i (cellule) → true : ses PNJ ont été instanciés (première visite)
var claims: Dictionary = {}            # Vector2i (cellule) → {role} : le territoire du joueur (Expansion territoriale)
var vacances: Dictionary = {}          # id de royaume → semaine de résolution : trône vacant (Familles et succession)
var heritiers: Dictionary = {}         # id de royaume → id de l'héritier désigné à la mort du dirigeant
var vacances_guildes: Dictionary = {}  # "guilde|village" → semaine de résolution : hall sans maître
var villages: Dictionary = {}          # nom de village → {cellule, royaume, conquis_par, defense_jusqua, abandonne} (Conquête de village)
var mutex := Mutex.new()
var tache: int = -1                    # plus utilisé (pré-génération synchrone) — gardé pour compatibilité des sauvegardes en mémoire
static var ouverts: Array = []          # plus utilisé depuis que la pré-génération est synchrone (gardé : `fermer_tous` reste appelé)


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
	for i in e.get("cueillette", {}).keys():   # Plantes : les plantes sauvages, l'id de la plante en « matériau »
		var p := base + Vector2i(int(i) % taille, int(i) / taille)
		g.materiaux[g.idx(p)] = e.cueillette[i]
		g.poser_contenu(p, "plante_sauvage")
	for i in e.get("eau", {}).keys():
		g.poser_contenu(base + Vector2i(int(i) % taille, int(i) / taille), "eau")
	for i in e.get("murs", {}).keys():   # les bâtiments du hameau
		var p := base + Vector2i(int(i) % taille, int(i) / taille)
		g.materiaux[g.idx(p)] = e.murs[i]
		g.poser_contenu(p, "mur_construit")
	for i in e.get("portes", {}).keys():   # fermées : les PNJ les ouvrent en rentrant (Génération de donjon, 2026-08-30)
		g.poser_contenu(base + Vector2i(int(i) % taille, int(i) / taille), "porte_fermee")
	for i in e.get("meubles", {}).keys():
		var p := base + Vector2i(int(i) % taille, int(i) / taille)
		var m: Dictionary = GameData.catalogues.meubles.get(str(e.meubles[i]), {})
		g.meubles[g.idx(p)] = str(e.meubles[i])
		g.poser_contenu(p, "meuble" if bool(m.get("bloque_passage", true)) else "meuble_sol")
	if not gouffre_de(cell).is_empty():
		e["a_donjon"] = true   # le gouffre de la région : une entrée permanente, dessinée comme les autres
		e["gouffre"] = true
	if bool(e.get("a_donjon", false)):
		g.poser_contenu(base + e.entree_donjon, "entree_donjon")
		foyer(cell)   # le donjon devient un foyer connu de la dérive (le gouffre, lui, n'en a pas)
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
		g.niveau_eau.erase(gi)
		if int(m.get("eau", 0)) > 0:   # le niveau d'un écoulement (Eau et liquides)
			g.niveau_eau[gi] = int(m.eau)
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
			"materiau": str(g.materiaux.get(gi, "")), "meuble": str(g.meubles.get(gi, "")), "station": str(g.stations_fixes.get(gi, "")), "sol": str(g.sols.get(gi, "")), "eau": int(g.niveau_eau.get(gi, 0))}
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


## Ce qu'une case de départ a sous la main, sur SA masse de terre (designer 2026-09-02) : combien de
## gouffres, combien de villes, et de combien de royaumes différents. Une graine qui pose le camp sur
## un îlot désert donne une partie sans rien à faire — et on ne s'en aperçoit qu'après avoir joué une
## heure. On compte donc avant de commencer.
##
## Deux raccourcis assumés, pour que le calcul tienne en une fraction de seconde. On ne parcourt pas
## la masse de terre entière mais un **voisinage** — un gouffre à l'autre bout d'un continent n'est de
## toute façon pas « sous la main ». Et on n'inspecte pas chaque cellule : les gouffres se déduisent
## des germes de région, les villes des capitales des royaumes du secteur. C'est exact pour ce qu'on
## cherche, et cent fois moins cher qu'un balayage.
func inventaire_depart(cell: Vector2i) -> Dictionary:
	var cfg: Dictionary = planete.get("depart_garanti", {})
	var rayon := int(cfg.get("rayon_cellules", 30))
	var cont: Dictionary = surface.continent_de(cell)
	if cont.is_empty():
		return {"gouffres": 0, "villes": 0, "royaumes": 0}
	var id_cont: int = int(cont.id)
	var gouffres := 0
	var pas := surface._pas_region()
	var vus := {}
	for dy in range(-rayon, rayon + 1, maxi(1, pas / 2)):
		for dx in range(-rayon, rayon + 1, maxi(1, pas / 2)):
			var g: Vector2i = surface.germe_region(cell + Vector2i(dx, dy))
			if vus.has(g):
				continue
			vus[g] = true
			var r: Dictionary = surface.region_de(cell + Vector2i(dx, dy))
			var cg: Vector2i = Vector2i(r.get("cellule", Vector2i(-9999, -9999)))
			if cg.x == -9999 or maxi(absi(cg.x - cell.x), absi(cg.y - cell.y)) > rayon:
				continue
			if int(surface.continent_de(cg).get("id", -1)) == id_cont and not gouffre_de(cg).is_empty():
				gouffres += 1
	var royaumes := {}
	var villes := 0
	var s_min := surface.secteur_de(cell - Vector2i(rayon, rayon))
	var s_max := surface.secteur_de(cell + Vector2i(rayon, rayon))
	for sy in range(s_min.y, s_max.y + 1):
		for sx in range(s_min.x, s_max.x + 1):
			for roy in surface.royaumes_secteur(Vector2i(sx, sy)).values():
				var cap: Vector2i = Vector2i(roy.capital_poi)
				if maxi(absi(cap.x - cell.x), absi(cap.y - cell.y)) > rayon:
					continue
				if int(surface.continent_de(cap).get("id", -1)) != id_cont:
					continue
				villes += 1
				royaumes[str(roy.id)] = true
	return {"gouffres": gouffres, "villes": villes, "royaumes": royaumes.size()}


## La case de départ tient-elle ses promesses ?
func depart_valable(cell: Vector2i) -> bool:
	if not surface.terre_a(cell):
		return false
	var cfg: Dictionary = planete.get("depart_garanti", {})
	var inv := inventaire_depart(cell)
	return int(inv.gouffres) >= int(cfg.get("gouffres_min", 1)) \
		and int(inv.villes) >= int(cfg.get("villes_min", 2)) \
		and int(inv.royaumes) >= int(cfg.get("royaumes_min", 2))


## Cherche autour de `origine` une case de départ qui tienne les promesses. À défaut, la première
## case de TERRE trouvée : mieux vaut une partie pauvre qu'une partie dans l'océan.
func chercher_depart(origine: Vector2i) -> Vector2i:
	var cfg: Dictionary = planete.get("depart_garanti", {})
	var rayon_max := int(cfg.get("rayon_recherche", 60))
	var repli := Vector2i(-9999, -9999)
	for r in range(0, rayon_max + 1, 3):
		for dy in range(-r, r + 1, 3):
			for dx in range(-r, r + 1, 3):
				if r > 0 and absi(dx) < r and absi(dy) < r:
					continue
				var c: Vector2i = origine + Vector2i(dx, dy)
				if not surface.terre_a(c):
					continue
				if repli.x == -9999:
					repli = c
				if depart_valable(c):
					return c
	return repli if repli.x != -9999 else origine


## Le gouffre de la région : un donjon infini, gratuit, dont un étage vidé le reste pour toujours
## (designer 2026-09-02). Il s'ouvre sur la cellule de sol qui fait le centre de sa région — un repère
## permanent, pas un événement : il ne s'éteint jamais, ne se repeuple pas et n'infecte rien.
func gouffre_de(cell: Vector2i) -> Dictionary:
	if cell == cellule_camp or not surface.terre_a(cell):
		return {}
	if surface.poi_de(cell).get("village", false):
		return {}
	var r: Dictionary = surface.region_de(cell)
	if r.is_empty() or Vector2i(r.get("cellule", Vector2i(-9999, -9999))) != cell:
		return {}
	return {"id": int(hash([surface.graine, cell.x, cell.y, "gouffre"]) & 0x7fffffff),
		"region": str(r.id), "nom": str(r.nom), "cellule": cell,
		"element": surface.element_dominant(cell)}


## L'altitude mémorisée des sous-points d'une cellule (un octet chacun), ou un tableau vide si on ne
## l'a pas encore calculée. `sp` : le nombre de sous-points par côté — s'il a changé, le souvenir est périmé.
##
## On retient l'**altitude**, pas la couleur. C'est l'altitude qui coûte cher — chaque sous-point demande
## un warp de bruit, la distance aux vingt-quatre plaques, un bruit de continentalité et les points
## chauds — alors que la couleur s'en déduit par trois comparaisons. Retenir la couleur coûtait trois
## fois plus de place pour rien, et figeait une teinte qui, elle, peut changer (biome, danger, saison).
func carte_altitudes(cell: Vector2i, sp: int) -> PackedByteArray:
	if carte_cache_sp != sp or not carte_cache.has(cell):
		return PackedByteArray()
	return carte_cache[cell]


## Retient les altitudes d'une cellule : un octet par sous-point, vingt-cinq octets à cinq sous-points.
func carte_retenir(cell: Vector2i, sp: int, altitudes: PackedByteArray) -> void:
	if carte_cache_sp != sp:
		carte_cache.clear()
		carte_cache_sp = sp
	carte_cache[cell] = altitudes


## Le souvenir de la carte, en UN bloc compressé (designer 2026-09-02). Écrit cellule par cellule dans
## le JSON, il pesait 718 Ko pour une seule ouverture de carte — 91 % du fichier de sauvegarde, à cause
## des clés `_v2i` et du base64 de chaque cellule. Un seul tableau d'octets compressé tombe à quelques
## dizaines de kilo-octets : des altitudes voisines se ressemblent, et la compression aime ça.
func carte_cache_serialise() -> Dictionary:
	if carte_cache.is_empty():
		return {}
	var sp := carte_cache_sp
	var n := sp * sp
	var brut := PackedByteArray()
	for cell in carte_cache.keys():
		var octets: PackedByteArray = carte_cache[cell]
		if octets.size() != n:
			continue
		brut.append((int(cell.x) >> 8) & 0xFF)
		brut.append(int(cell.x) & 0xFF)
		brut.append((int(cell.y) >> 8) & 0xFF)
		brut.append(int(cell.y) & 0xFF)
		brut.append_array(octets)
	return {"sp": sp, "taille": brut.size(), "octets": brut.compress(FileAccess.COMPRESSION_ZSTD)}


func carte_cache_charger(d: Dictionary) -> void:
	carte_cache.clear()
	carte_cache_sp = 0
	if d.is_empty() or not d.has("octets"):
		return
	var sp := int(d.get("sp", 0))
	var n := sp * sp
	if n <= 0:
		return
	var octets: PackedByteArray = d.octets
	var brut := octets.decompress(int(d.get("taille", 0)), FileAccess.COMPRESSION_ZSTD)
	var pas := 4 + n
	carte_cache_sp = sp
	for i in brut.size() / pas:
		var b := i * pas
		var cell := Vector2i((brut[b] << 8) | brut[b + 1], (brut[b + 2] << 8) | brut[b + 3])
		carte_cache[cell] = brut.slice(b + 4, b + 4 + n)


## Cette cellule porte-t-elle une entrée de donjon DESSINÉE ? Une entrée posée se voit et s'efface
## (grâce, répit, retour) ; un donjon de corruption n'a rien à dessiner — la cellule happe qui y met
## le pied. Les deux ne suivent donc pas le même cycle, et c'est ici qu'on les distingue.
func entree_posee(cell: Vector2i) -> bool:
	if cellules.has(cell):
		return bool(cellules[cell].get("a_donjon", false))
	return bool(surface.poi_de(cell, cell == cellule_camp).donjon)


## Le foyer d'une cellule à donjon (créé à la première demande) ; {} si la cellule n'en a pas.
func foyer(cell: Vector2i) -> Dictionary:
	if foyers.has(cell):
		return foyers[cell]
	# Le foyer d'une cellule EST son donjon (designer 2026-09-02). Il n'y a plus de donjon posé par la
	# génération de surface : c'est la corruption qui les fait naître, et c'est donc elle qui allume le
	# foyer. Tant que cette condition ne regardait que `poi_de().donjon`, toute la machinerie
	# hebdomadaire — infection, plafonds, répit, générations — tournait à vide.
	if not gouffre_de(cell).is_empty():
		return {}   # le gouffre n'est pas un foyer : il ne s'éteint pas, ne se repeuple pas, n'infecte rien
	if not entree_posee(cell) and not donjon_corrompu(cell, jour_monde):
		return {}
	# `pose` fige à la naissance ce qu'est ce foyer, car `entree_posee` ne peut pas servir de mémoire :
	# effacer l'entrée après la grâce remet `a_donjon` à false, et un foyer posé passerait pour un foyer
	# de corruption au milieu de son propre cycle. Les foyers d'anciennes sauvegardes sont tous posés.
	foyers[cell] = {"actif": true, "majeur": surface.danger_de(cell) >= 2, "generation": 0, "repit": 0, "nettoye_tick": -1, "pose": entree_posee(cell)}
	return foyers[cell]


## Corruption effective d'une cellule (0-100) : le bruit de danger plus le delta.
func corruption_de(cell: Vector2i) -> float:
	var taille_c: int = taille
	var d := surface.valeur("danger", cell.x * taille_c + taille_c / 2, cell.y * taille_c + taille_c / 2) * 100.0
	return clampf(d + float(delta.get(cell, 0)), 0.0, 100.0)


## La corruption d'une cellule UN JOUR DONNÉ (designer 2026-09-01, point 51) : la corruption de fond
## plus un bruit qui se déplace chaque période. Calculée à la demande — le monde entier « bouge »
## sans qu'aucune boucle ne parcoure ses cellules.
func corruption_jour(cell: Vector2i, jour: int) -> float:
	var cfg: Dictionary = planete.corruption.get("donjons", {})
	var per := maxi(1, int(cfg.get("periode_jours", 3)))
	var vague := jour / per
	var f := float(cfg.get("frequence", 0.045))
	var n := sin((cell.x + vague * 3) * f) * cos((cell.y - vague * 2) * f * 1.3) 		+ 0.5 * sin((cell.x + cell.y + vague) * f * 2.1)
	# Plus on s'éloigne du centre du monde, plus la corruption mord (designer 2026-09-01, point 62).
	var loin := float(cfg.get("gradient_bord", 0.0)) * eloignement(cell)
	return clampf(corruption_de(cell) + float(cfg.get("amplitude", 28.0)) * (n * 0.5 + 0.5) + loin, 0.0, 100.0)


## L'éloignement d'une cellule, de 0 au centre du monde à 1 au bord (point 62).
func eloignement(cell: Vector2i) -> float:
	var larg := float(planete.monde_cellules)
	var haut := larg * float(planete.get("monde_ratio", 1.0))
	var d := Vector2(cell.x - larg * 0.5, (cell.y - haut * 0.5) / maxf(0.2, float(planete.get("monde_ratio", 1.0)))).length()
	return clampf(d / maxf(1.0, larg * 0.5), 0.0, 1.0)


## Cette cellule est-elle cristallisée en donjon ce jour-là ? (point 51)
## Les lieux habités sont épargnés, et la densité de la région est plafonnée.
func donjon_corrompu(cell: Vector2i, jour: int) -> bool:
	var cfg: Dictionary = planete.corruption.get("donjons", {})
	if not surface.terre_a(cell) or cell == cellule_camp:
		return false
	if claims.has(cell) or surface.poi_de(cell).get("village", false):
		return false
	if surface.poi_de(cell, cell == cellule_camp).get("donjon", false):
		return false   # une cellule qui a déjà son donjon garde son entrée : la corruption ne la double pas
	if not gouffre_de(cell).is_empty():
		return false   # le gouffre tient déjà la cellule : la corruption n'ouvre pas un second trou dedans
	# Un donjon vaincu DISPARAÎT (designer 2026-09-02) : pendant le répit, la cellule ne peut plus se
	# cristalliser, quelle que soit sa corruption. Passé ce délai, si la corruption est toujours au-dessus
	# du seuil, un NOUVEAU donjon naît là — au niveau 1, pas à celui qu'on venait de vaincre.
	var nettoye_le := int(nettoyages.get(cell, -9999))
	if nettoye_le > -9999:
		var f_c: Dictionary = foyers.get(cell, {})
		var repit_sem: int = int(f_c.get("repit_initial", _cr().get("repit_mineur", 4)))
		var jours_repit := repit_sem * maxi(1, int(_cr().get("ticks_par_semaine", 168000)) / maxi(1, int(planete.get("cycle", {}).get("ticks_par_jour", 24000))))
		if jour - nettoye_le < jours_repit:
			return false
	if cell == cellule_amorce() and nettoye_le == -9999:
		return true   # le donjon garanti du début de partie (designer 2026-09-01)
	if corruption_jour(cell, jour) < float(cfg.get("seuil", 62.0)):
		return false
	return _dans_une_grappe(cell, jour)


## Combien de donjons de corruption le monde porte-t-il ? (designer 2026-09-02 : « il y en a beaucoup
## trop, vraiment beaucoup beaucoup trop » — mesuré à 18,8 par région, une cellule de terre sur 8.)
##
## La densité se réglait par un tirage à plat, `densite_max_pct` % des cellules au-dessus du seuil. Deux
## défauts : le pourcentage ne dit rien de ce qu'on voit à l'écran, et le gradient d'éloignement (point 62)
## met presque toute une marge au-dessus du seuil, si bien que ce pourcentage s'appliquait à presque tout
## le monde. Un donjon devenait le décor au lieu d'être un événement.
##
## Maintenant que les régions existent (designer 2026-09-02), la densité s'exprime dans l'unité qui se lit
## sur la carte : **N grappes par région et par période**. Chaque grappe est tirée de (région, période) et
## couvre un petit carré ; une cellule cristallise si elle tombe dans une grappe ET passe le seuil. La
## fusion des cellules contiguës continue d'opérer à l'intérieur d'une grappe — un donjon large reste
## possible — mais le nombre de donjons par région ne dépend plus du hasard : il est borné par les données.
func _dans_une_grappe(cell: Vector2i, jour: int) -> bool:
	var cfg: Dictionary = planete.corruption.get("donjons", {})
	var per := maxi(1, int(cfg.get("periode_jours", 3)))
	var vague := jour / per
	var g := surface.germe_region(cell)
	var pas: int = surface._pas_region()
	var rayon := maxi(0, int(cfg.get("rayon_grappe", 1)))
	for k in maxi(0, int(cfg.get("grappes_par_region", 2))):
		var h := absi(hash([surface.graine, g.x, g.y, vague, k, "grappe"]))
		var centre := Vector2i(g.x * pas + h % pas, g.y * pas + (h / pas) % pas)
		if absi(cell.x - centre.x) <= rayon and absi(cell.y - centre.y) <= rayon:
			return true
	return false


## Les cellules corrompues contiguës forment UN donjon (designer 2026-09-01, point 51) : on remonte
## le groupe depuis une cellule, en s'arrêtant au plafond (`fusion_max`). Un groupe de quatre est un
## donjon énorme, pas quatre donjons voisins — et le plafond empêche la mer de donjons.
func groupe_corrompu(cell: Vector2i, jour: int) -> Array:
	var cfg: Dictionary = planete.corruption.get("donjons", {})
	var plafond := maxi(1, int(cfg.get("fusion_max", 4)))
	var vus := {cell: true}
	var file: Array = [cell]
	var groupe: Array = [cell]
	while not file.is_empty() and groupe.size() < plafond:
		var c: Vector2i = file.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + d
			if vus.has(v) or groupe.size() >= plafond:
				continue
			vus[v] = true
			if donjon_corrompu(v, jour):
				groupe.append(v)
				file.append(v)
	groupe.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return groupe


## Le donjon d'une cellule corrompue : son thème (l'élément dominant du lieu) et son niveau,
## qui monte d'une période tant que personne ne l'a nettoyé (point 51).
func donjon_de_corruption(cell: Vector2i, jour: int) -> Dictionary:
	if not donjon_corrompu(cell, jour):
		return {}
	var cfg: Dictionary = planete.corruption.get("donjons", {})
	var per := maxi(1, int(cfg.get("periode_jours", 3)))
	var depuis := 0   # depuis combien de périodes cette cellule est-elle corrompue sans discontinuer ?
	while depuis < int(cfg.get("recherche_max", 120)) and donjon_corrompu(cell, jour - (depuis + 1) * per):
		depuis += 1
	if cell == cellule_amorce():
		# Le donjon garanti du début de partie est cristallisé « depuis toujours », puisqu'il ne dépend
		# pas du bruit : la recherche en arrière remontait donc jusqu'à `recherche_max` et lui donnait le
		# niveau 121 — le tout premier donjon d'une partie était le plus dur du jeu. Il a l'âge du monde : zéro.
		depuis = 0
	var nettoye := int(nettoyages.get(cell, -1))
	if nettoye >= 0:
		depuis = mini(depuis, maxi(0, (jour - nettoye) / per))
	# Le niveau n'a plus de plafond (point 62) : l'âge, ou le plancher géographique s'il est plus haut.
	# Nettoyer un donjon lointain le ramène à son plancher, jamais à 1 : la marge reste la marge.
	# La pente géographique (designer 2026-09-02, choix 2) : le niveau monte avec l'éloignement du centre
	# du monde — « le sud est calme, l'est est mortel ». Elle n'est pas droite mais **courbe** : linéaire,
	# elle donnait déjà du niveau 13 au pied du camp, sans berceau où apprendre à jouer. Avec un exposant,
	# le centre reste plat sur un bon rayon puis le niveau grimpe vite : on choisit sa difficulté en
	# s'éloignant, et on ne se la fait pas imposer par l'endroit où la partie a commencé.
	var loin_n := pow(eloignement(cell), float(cfg.get("niveau_courbe_distance", 1.0)))
	var plancher := int(round(float(cfg.get("niveau_par_cellule_distance", 0.0)) * loin_n * float(planete.monde_cellules) * 0.5))
	var el := str(surface.element_dominant(cell)) if surface.has_method("element_dominant") else "terre"
	# La fusion (point 51) : le groupe de cellules contiguës donne un seul donjon, plus grand et plus
	# fort — sa tête est la cellule de tête du groupe, pour que toutes y mènent au même endroit.
	var groupe := groupe_corrompu(cell, jour)
	var niveau := maxi(1 + depuis * int(cfg.get("niveau_par_periode", 1)), plancher)
	return {"theme": str(cfg.get("themes", {}).get(el, "terre")), "element": el,
		"niveau": niveau + (groupe.size() - 1) * int(cfg.get("niveau_par_fusion", 3)),
		"plancher": plancher, "cellules": groupe.size(), "tete": groupe[0]}


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
		# Un foyer de corruption n'a pas de vie propre : il EST le donjon de la cellule (designer
		# 2026-09-02). Son activité suit donc la cristallisation, et sa renaissance ne « repose » aucune
		# entrée — une cellule corrompue happe qui y met le pied, elle n'a pas de trappe à dessiner.
		if not bool(f.get("pose", true)):
			var vivant := donjon_corrompu(cell, jour_monde)
			if vivant != bool(f.actif):
				f.actif = vivant
				if vivant:
					f.generation = int(f.generation) + 1
					f.majeur = danger_de(cell) >= 2
					f.nettoye_tick = -1
					nettoyages.erase(cell)
				touchees.append(cell)
			if not vivant:
				if int(f.repit) > 0:
					f.repit = int(f.repit) - 1
				continue
			actifs[cell] = true
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
	f["repit_initial"] = int(f.repit)   # `donjon_corrompu` en déduit combien de jours la cellule reste stérile
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


## Pré-génère les cellules voisines manquantes autour du centre, **sur le fil principal** et par petites doses
## (`pregen_par_appel`). Décision du 2026-08-29 : le WorkerThreadPool écrivait dans les mêmes caches que le fil
## principal (GameData, `cellules`, `Surface`) — d'où des crashs aléatoires en fin de test (« Unreferenced static
## string », threads détruits sans wait). Une cellule par appel coûte quelques ms et rend la génération déterministe.
func pregenerer_voisins() -> void:
	var budget := int(GameData.config("planete").get("monde", {}).get("pregen_par_appel", 1))
	for dy in range(-rayon - 1, rayon + 2):
		for dx in range(-rayon - 1, rayon + 2):
			if budget <= 0:
				return
			var cell := centre + Vector2i(dx, dy)
			if not cellules.has(cell):
				cellule(cell)
				budget -= 1


## Ne fait plus rien (la pré-génération est synchrone) : gardé pour les scènes qui l'appellent avant de quitter.
static func fermer_tous() -> void:
	ouverts.clear()


## Attend la fin de la pré-génération (tests, fermeture).
func fermer() -> void:
	tache = -1
	ouverts.erase(self)

## La cellule d'amorce (designer 2026-09-01) : une nouvelle partie a toujours un donjon à portée. Elle est
## tirée sur la graine parmi les cellules de terre situées entre rayon_min et rayon_max cases du camp,
## villages et claims écartés. Nettoyée, elle redevient une cellule ordinaire soumise au seul bruit.
func cellule_amorce() -> Vector2i:
	if _amorce != Vector2i(-9999, -9999):
		return _amorce
	var g: Dictionary = planete.corruption.get("donjons", {}).get("garantie_depart", {})
	var rmin := int(g.get("rayon_min", 3))
	var rmax := int(g.get("rayon_max", 6))
	var candidates: Array[Vector2i] = []
	for dy in range(-rmax, rmax + 1):
		for dx in range(-rmax, rmax + 1):
			var d := maxi(absi(dx), absi(dy))
			if d < rmin or d > rmax:
				continue
			var c: Vector2i = cellule_camp + Vector2i(dx, dy)
			if not surface.terre_a(c) or claims.has(c) or surface.poi_de(c).get("village", false):
				continue
			candidates.append(c)
	if candidates.is_empty():
		_amorce = Vector2i(-1, -1)   # une île minuscule : pas d'amorce, le bruit décidera seul
		return _amorce
	candidates.sort_custom(func(u: Vector2i, v: Vector2i) -> bool: return u.y * 100000 + u.x < v.y * 100000 + v.x)
	_amorce = candidates[absi(hash([surface.graine, cellule_camp.x, cellule_camp.y, "amorce"])) % candidates.size()]
	return _amorce
