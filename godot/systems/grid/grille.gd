class_name Grille
extends RefCounted
## Grille bornée de tuiles — structure plate en SoA, sérialisable (Décision — Structure de
## données de la grille) : hauteur (0-20), sol, contenu, c_data. L'occupant est un index
## runtime tuile → entité, jamais stocké dans la tuile.
## Coûts de pas et ligne de vue : Hauteur de terrain ±10 (règles lues dans combat_rules.json).
## Déplacement en 8 directions, portées mesurées en distance de Chebyshev (voir la note
## Stats d'armes, décision du 2026-08-26).

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var largeur: int
var hauteur_grille: int
var hauteurs := PackedByteArray()
var sol := PackedInt32Array()
var contenu := PackedInt32Array()
var c_data := PackedInt32Array()
var contenu_ids: Array[String] = [""]    # index de contenu → id (0 = rien)
var contenu_defs: Dictionary = {}         # id → définition (tile_contents.json)
var occupants: Dictionary = {}            # index de tuile → id d'entité
var dep: Dictionary = {}                  # combat_rules/deplacement
var hauteur_oeil: int = 1
var decouvert: Dictionary = {}            # index de tuile → true : tuiles déjà vues (brouillard de guerre)
var materiaux: Dictionary = {}            # index de tuile → id de matériau (filons) ; sinon materiau_defaut
var materiau_defaut: String = ""          # le matériau des murs ordinaires (materiau_mur du thème)
var meubles: Dictionary = {}              # index de tuile → id de meuble (data/meubles/)
var stations_fixes: Dictionary = {}       # index de tuile → id de station posée
var niveau_eau: Dictionary = {}           # index de tuile → niveau 1-7 d'un écoulement (Eau et liquides) ; une source vaut 8
var dangers: Dictionary = {}              # index de tuile → true : à éviter en chemin (le feu, Météo) — la simulation le tient à jour
var neige := false                        # état météo de la grille (Météo) : chaque pas coûte neige_surcout de plus
var gel := false                          # sous 0 °C : l'eau est de la glace, elle se marche
var sols: Dictionary = {}                 # index de tuile → id de matériau de sol (surface) ; vide = sol par défaut
var origine := Vector2i.ZERO              # coordonnée monde de la tuile locale (0, 0) — fenêtre glissante (Monde)
var modifies: Dictionary = {}             # index de tuile → true : tuiles modifiées depuis la construction (capture par cellule)


## Le niveau d'eau d'une tuile (Eau et liquides) : 8 pour une source, 1-7 pour un écoulement, 0 sinon.
func niveau_liquide(p: Vector2i) -> int:
	var tags: Array = contenu_de(p).get("tags", [])
	if "source" in tags and "liquide" in tags:
		return 8
	if "ecoulement" in tags:
		return int(niveau_eau.get(idx(p), 1))
	return int(niveau_eau.get(idx(p), 0))   # une tuile dont le contenu a été remplacé (du butin posé) reste mouillée


func materiau_sol(p: Vector2i) -> String:
	return str(sols.get(idx(p), ""))


## Le matériau d'une tuile de mur : le filon s'il y en a un, sinon celui du thème.
func materiau_de(p: Vector2i) -> String:
	return str(materiaux.get(idx(p), materiau_defaut))


func _init(l: int, h: int) -> void:
	largeur = l
	hauteur_grille = h
	hauteurs.resize(l * h)
	sol.resize(l * h)
	contenu.resize(l * h)
	c_data.resize(l * h)


## Construit la grille d'une arène (data/prototype_arenas) avec les règles et contenus.
static func depuis_arene(arene: Dictionary, contenus: Dictionary, regles_dep: Dictionary, oeil: int) -> Grille:
	var taille: Array = arene["size"]
	var g := Grille.new(int(taille[0]), int(taille[1]))
	g.contenu_defs = contenus
	g.dep = regles_dep
	g.hauteur_oeil = oeil
	var lignes: Array = arene["heights"]
	for y in g.hauteur_grille:
		for x in g.largeur:
			g.hauteurs[y * g.largeur + x] = int(lignes[y][x])
	for c: Dictionary in arene.get("contents", []):
		g.poser_contenu(Vector2i(int(c["pos"][0]), int(c["pos"][1])), c["type"])
	return g


## Construit la grille d'un étage de donjon généré (Donjon.generer_etage) : le plein est de la roche.
static func depuis_etage(etage: Dictionary, contenus: Dictionary, regles_dep: Dictionary, oeil: int) -> Grille:
	var g := Grille.new(int(etage.largeur), int(etage.hauteur))
	g.contenu_defs = contenus
	g.dep = regles_dep
	g.hauteur_oeil = oeil
	g.hauteurs = etage.hauteurs.duplicate()
	g.sols = etage.get("sols", {}).duplicate()
	for i in g.largeur * g.hauteur_grille:
		if not etage.sol.has(i):
			g.poser_contenu(Vector2i(i % g.largeur, i / g.largeur), "roche" if etage.get("bord", {}).has(i) else "mur")
	for i in etage.get("meubles", {}).keys():   # Talents de race : source maudite, autel du rituel
		var pm := Vector2i(int(i) % g.largeur, int(i) / g.largeur)
		g.meubles[int(i)] = str(etage.meubles[i])
		g.poser_contenu(pm, "meuble")
	for i in etage.get("portes", {}).keys():   # les seuils fermés des salles (Génération de donjon, 2026-08-30)
		g.poser_contenu(Vector2i(int(i) % g.largeur, int(i) / g.largeur), "porte_fermee")
	for i in etage.get("lave", {}).keys():   # Eau et liquides : les mares de lave
		g.poser_contenu(Vector2i(int(i) % g.largeur, int(i) / g.largeur), "lave")
		g.dangers[int(i)] = true
	return g


# ---------------------------------------------------------------- accès

func idx(p: Vector2i) -> int:
	return (p.y - origine.y) * largeur + (p.x - origine.x)


## La position monde d'un index de tuile.
func pos_de(i: int) -> Vector2i:
	return origine + Vector2i(i % largeur, i / largeur)


## Marque une tuile modifiée (Monde.capturer la mémorise par cellule).
func marquer(p: Vector2i) -> void:
	modifies[idx(p)] = true


func dans(p: Vector2i) -> bool:
	return p.x >= origine.x and p.y >= origine.y and p.x < origine.x + largeur and p.y < origine.y + hauteur_grille


func h(p: Vector2i) -> int:
	return hauteurs[idx(p)]


func poser_contenu(p: Vector2i, id: String) -> void:
	var avant: Array = contenu_de(p).get("tags", [])
	if "liquide" in avant:   # le contenu remplacé (du butin posé sur l'eau) : la tuile reste mouillée (Eau et liquides)
		niveau_eau[idx(p)] = 8 if "source" in avant else int(niveau_eau.get(idx(p), 1))
	var i := contenu_ids.find(id)
	if i < 0:
		contenu_ids.append(id)
		i = contenu_ids.size() - 1
	contenu[idx(p)] = i
	modifies[idx(p)] = true


## La tuile se nage (Eau et liquides) : tag `nage`, ou niveau d'eau mémorisé sous un contenu posé — hors gel.
func nageable(p: Vector2i) -> bool:
	if gel:
		return false
	return "nage" in contenu_de(p).get("tags", []) or niveau_liquide(p) > 0


func contenu_de(p: Vector2i) -> Dictionary:
	var i := contenu[idx(p)]
	return contenu_defs.get(contenu_ids[i], {}) if i > 0 else {}


func bloque_passage(p: Vector2i) -> bool:
	return contenu_de(p).get("bloque_passage", false)


## Hauteur effective pour la vue : le sol plus le contenu qui bloque la vue.
func hauteur_vue(p: Vector2i) -> int:
	var c := contenu_de(p)
	return h(p) + (int(c.get("hauteur_vue", 0)) if c.get("bloque_vue", false) else 0)


func occupant(p: Vector2i) -> String:
	return occupants.get(idx(p), "")


func placer(id: String, p: Vector2i) -> void:
	occupants[idx(p)] = id


func liberer(p: Vector2i) -> void:
	occupants.erase(idx(p))


## Distance de Tchebychev — la mesure du CONTACT et du déplacement : deux cases en diagonale sont voisines.
static func distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## La mesure d'une PORTÉE (designer 2026-09-01) : euclidienne, arrondie. Une boule de Tchebychev est un
## carré — la zone de lancer en devenait carrée, contre l'anneau rond que dessine l'aperçu.
static func portee_entre(a: Vector2i, b: Vector2i) -> int:
	return int(round(sqrt(float((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)))))


# ---------------------------------------------------------------- déplacement

## Coût en ticks pour passer d'une tuile à sa voisine ; -1 = infranchissable (falaise, mur,
## chute). Les volants ignorent le dénivelé (IA des créatures : morphologies).
## Le coût d'un pas, avec le franchissement progressif (designer 2026-09-01, points 56 et 57) :
## `facteurs` porte le facteur de compétence de l'être — {"escalade": f, "nage": f} — pour que grimper
## une paroi haute ou traverser un lac dépendent de qui le fait. Sans facteurs, on retombe sur 1.0.
func cout_pas(de: Vector2i, vers: Vector2i, volant: bool = false, eviter_nage: bool = false, facteurs: Dictionary = {}) -> int:
	if not dans(vers):
		return -1
	if bloque_passage(vers):
		if "fermee" in contenu_de(vers).get("tags", []):   # une porte fermée s'ouvre au passage : un pas de plus, pas un mur
			return int(dep["cout_base"]) * 2
		return -1
	var base: int = dep["cout_base"]
	if volant:
		return base
	if eviter_nage and nageable(vers) and not nageable(de):
		return -1   # Eau et liquides : la surcharge refuse d'entrer — le chemin ne le propose pas
	if nageable(vers):   # Nage (point 57) : chaque tuile d'eau coûte selon la compétence du nageur
		var np: Dictionary = dep.get("nage_progressive", {})
		var t_nage := float(np.get("ticks_par_tuile", int(dep.get("nage", base * 2))))
		return maxi(1, int(round(t_nage / maxf(0.2, float(facteurs.get("nage", 1.0)))))) + (int(dep.get("neige_surcout", 1)) if neige else 0)
	var dh := h(vers) - h(de)
	# Escalade (point 56) : au-delà d'une marche, on grimpe — le coût monte avec le CARRÉ de la
	# hauteur et descend avec la compétence ; au-delà de hauteur_max, la paroi reste infranchissable.
	var esc: Dictionary = dep.get("escalade", {})
	if dh >= int(dep["falaise_delta"]):   # toute paroi de terrain se grimpe : c'est un temps à payer, pas un mur
		var t_esc := float(esc.get("ticks_par_niveau", 14)) * float(dh * dh)
		return maxi(1, int(round(t_esc / maxf(0.2, float(facteurs.get("escalade", 1.0))))))
	if dh >= int(dep["falaise_delta"]) or dh <= -int(dep["chute_delta"]):
		return -1
	var sur := int(dep.get("neige_surcout", 1)) if neige else 0   # Météo : la neige ralentit
	var brut := base + sur
	if dh == 2:
		brut = int(dep["montee_2"]) + sur
	elif dh == 1:
		brut = int(dep["montee_1"]) + sur
	elif dh < 0:
		brut = int(dep["descente"]) + sur
	# La FRICTION du sol change la vitesse : x (0,85 + friction x 0,003), bornée [0,85 ; 1,15]
	# (« Application des stats de matériau »). Une des quatre stats de matière que le code n'avait
	# jamais lues : la glace à friction 0 fait glisser, les pavés à 100 donnent quinze pour cent.
	# Le coût en ticks est l'INVERSE de la vitesse — aller plus vite, c'est payer moins.
	return maxi(1, int(round(float(brut) / _mult_friction(vers))))


## Le multiplicateur de vitesse du sol d'une tuile, borné. Sans matériau connu, rien ne change.
func _mult_friction(t: Vector2i) -> float:
	var sm: Dictionary = GameData.config("combat_rules").get("stats_materiau", {})
	if sm.is_empty():
		return 1.0
	var mid := str(sols.get(idx(t), materiau_defaut))
	var m: Dictionary = GameData.catalogues.materials.get(mid, {})
	if m.is_empty():
		return 1.0
	var f := float(m.get("stats", {}).get("friction", 50.0))
	return clampf(float(sm.get("friction_base", 0.85)) + f * float(sm.get("friction_par_point", 0.003)),
		float(sm.get("friction_min", 0.85)), float(sm.get("friction_max", 1.15)))


## Une chute (descente ≥ chute_delta) est autorisée en un pas volontaire : dégâts = (niveaux − franchise) × 5.
func est_chute(de: Vector2i, vers: Vector2i) -> bool:
	return dans(vers) and not bloque_passage(vers) and h(de) - h(vers) >= int(dep["chute_delta"])


func degats_chute(niveaux: int) -> int:
	return maxi(0, niveaux - int(dep["chute_franchise"])) * int(dep["chute_degats_par_niveau"])


## A* 8-directions sur les coûts de pente. Retourne les étapes SANS la case de départ.
## `ignorer` : id d'entité dont on ignore l'occupation (la cible, pour s'approcher d'elle).
func chemin(depart: Vector2i, arrivee: Vector2i, volant: bool = false, ignorer: String = "", eviter_nage: bool = false, max_noeuds: int = 0) -> Array[Vector2i]:
	var vide: Array[Vector2i] = []
	if depart == arrivee or not dans(arrivee):
		return vide
	var ouverts: Array[Vector3i] = [Vector3i(depart.x, depart.y, 0)]   # un tas binaire sur z (Villes B1 : la liste se fouillait en entier à chaque pas)
	var g := {depart: 0}
	var vient_de := {}
	var base: int = dep["cout_base"]
	var explores := 0
	while not ouverts.is_empty():
		explores += 1
		if max_noeuds > 0 and explores > max_noeuds:
			return vide   # un budget de nœuds (Villes B1) : une cible inaccessible ne fait pas fouiller toute la grille
		var c3 := _tas_pop(ouverts)
		var courant := Vector2i(c3.x, c3.y)
		if courant == arrivee:
			var pas: Array[Vector2i] = []
			var c := courant
			while c != depart:
				pas.push_front(c)
				c = vient_de[c]
			return pas
		for d in DIRS:
			var voisin := courant + d
			var cout := cout_pas(courant, voisin, volant, eviter_nage)
			if cout < 0:
				continue
			var occ := occupant(voisin)
			if not occ.is_empty() and occ != ignorer and voisin != arrivee:
				continue
			if dangers.has(idx(voisin)) and voisin != arrivee:   # on contourne le feu
				continue
			var ng: int = g[courant] + cout
			if ng < int(g.get(voisin, 1 << 30)):
				g[voisin] = ng
				vient_de[voisin] = courant
				_tas_push(ouverts, Vector3i(voisin.x, voisin.y, ng + base * distance(voisin, arrivee)))
	return vide


## Un tas binaire minimal sur la composante z (le coût estimé) — push et pop en O(log n).
static func _tas_push(tas: Array[Vector3i], v: Vector3i) -> void:
	tas.append(v)
	var i := tas.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if tas[parent].z <= tas[i].z:
			break
		var tmp := tas[parent]
		tas[parent] = tas[i]
		tas[i] = tmp
		i = parent


static func _tas_pop(tas: Array[Vector3i]) -> Vector3i:
	var racine := tas[0]
	var dernier: Vector3i = tas.pop_back()
	if tas.is_empty():
		return racine
	tas[0] = dernier
	var i := 0
	var n := tas.size()
	while true:
		var gauche := 2 * i + 1
		var droite := gauche + 1
		var plus_petit := i
		if gauche < n and tas[gauche].z < tas[plus_petit].z:
			plus_petit = gauche
		if droite < n and tas[droite].z < tas[plus_petit].z:
			plus_petit = droite
		if plus_petit == i:
			break
		var tmp := tas[i]
		tas[i] = tas[plus_petit]
		tas[plus_petit] = tmp
		i = plus_petit
	return racine


## Dijkstra borné : tuile → coût en ticks pour l'atteindre (UI : coûts sur les tuiles atteignables).
func atteignables(depart: Vector2i, budget: int, volant: bool = false, eviter_nage: bool = false) -> Dictionary:
	var couts := {depart: 0}
	var file: Array[Vector2i] = [depart]
	while not file.is_empty():
		var k := 0
		for i in file.size():
			if couts[file[i]] < couts[file[k]]:
				k = i
		var c: Vector2i = file[k]
		file.remove_at(k)
		for d in DIRS:
			var v := c + d
			var cout := cout_pas(c, v, volant, eviter_nage)
			if cout < 0 or not occupant(v).is_empty():
				continue
			var nc: int = couts[c] + cout
			if nc <= budget and nc < int(couts.get(v, 1 << 30)):
				couts[v] = nc
				file.append(v)
	return couts


# ---------------------------------------------------------------- vue

## Ligne de vue a → b : un relief (ou un mur) plus haut que la ligne des yeux coupe la vue.
func ligne_de_vue(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	if not dans(a) or not dans(b):   # une position d'une autre grille : hors de vue
		return false
	var ha := float(h(a) + hauteur_oeil)
	var hb := float(h(b) + hauteur_oeil)
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, n):
		var t := float(i) / float(n)
		var p := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if float(hauteur_vue(p)) > lerpf(ha, hb, t):
			return false
	return true


## La première tuile qui coupe la vue de a vers b (même parcours que ligne_de_vue), ou (-1, -1) si la vue est dégagée.
func premier_obstacle_vue(a: Vector2i, b: Vector2i) -> Vector2i:
	if a == b or not dans(a) or not dans(b):
		return Vector2i(-1, -1)
	var ha := float(h(a) + hauteur_oeil)
	var hb := float(h(b) + hauteur_oeil)
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, n):
		var t := float(i) / float(n)
		var p := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if float(hauteur_vue(p)) > lerpf(ha, hb, t):
			return p
	return Vector2i(-1, -1)


## Les tuiles intermédiaires de la trajectoire a → b (sans les extrémités), dans l'ordre.
func trajectoire(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, n):
		var t := float(i) / float(n)
		res.append(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	return res


## Tuiles d'une ligne de `longueur` depuis `origine` dans la direction (8-dir) de `vers`.
func ligne(origine: Vector2i, vers: Vector2i, longueur: int) -> Array[Vector2i]:
	var d := Vector2i(signi(vers.x - origine.x), signi(vers.y - origine.y))
	var res: Array[Vector2i] = []
	if d == Vector2i.ZERO:
		return res
	var p := origine
	for i in longueur:
		p += d
		if not dans(p):
			break
		res.append(p)
	return res


## Anneau de rayon r autour de `centre` (sans le centre).
func anneau(centre: Vector2i, r: int) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var p := centre + Vector2i(x, y)
			if p != centre and dans(p):
				res.append(p)
	return res
