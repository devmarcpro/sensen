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
## Les couches Z (designer 2026-09-06, 16 h : « changer d'étage change juste la dimension Z du monde, ce n'est pas une
## dimension à part ») : la grille a `couches` niveaux de largeur × hauteur_grille tuiles, la couche 0 est le sol, la
## couche z l'étage z des bâtiments. Une position reste un Vector2i : la couche est portée par y — la tuile (x, y) de
## l'étage z est (x, y + z × BANDE_Z). Les index de tuile s'empilent : idx(x, y, z) = z × n0 + idx(x, y). Tout ce qui
## parle en positions (occupants, chemins, vue, dangers) marche sans changer ; deux tuiles de couches différentes ne
## sont jamais voisines — sauf par un escalier (`lien_a`), qui relie une tuile à une tuile d'une autre couche.
const BANDE_Z := 1 << 20                  # y + z × BANDE_Z : au-delà de toute coordonnée monde (le noyau C++ porte la même)
var couches: int = 1                      # 1 + le nombre d'étages que la fenêtre porte
var lien_a := PackedInt32Array()          # index de tuile → index de la tuile liée par un escalier (−1 : aucun)
var hauteurs := PackedByteArray()
var sol := PackedInt32Array()
var contenu := PackedInt32Array()
var c_data := PackedInt32Array()
var contenu_ids: Array[String] = [""]    # index de contenu → id (0 = rien)
var contenu_defs: Dictionary = {}         # id → définition (tile_contents.json)
var occupants: Dictionary = {}            # index de tuile → id de l'entité AU SOMMET de la pile
## Les tuiles qui portent PLUSIEURS êtres (designer 2026-09-08, ordre de travail 26 ter) : index → tableau du bas
## vers le haut. Seules les tuiles à plusieurs y figurent — une tuile normale ne coûte rien de plus qu'avant.
var piles: Dictionary = {}                # index de tuile → Array[String], du bas vers le haut
var dep: Dictionary = {}:                 # combat_rules/deplacement
	set(v):
		dep = v
		_noyau_sale = true
var hauteur_oeil: int = 1:
	set(v):
		hauteur_oeil = v
		_noyau_sale = true
var decouvert: Dictionary = {}            # index de tuile → true : tuiles déjà vues (brouillard de guerre)
var decouvertes_recentes: PackedInt32Array = PackedInt32Array()   # les index découverts depuis que le client a lu (le terrain par morceaux, 2026-09-06)
var materiaux: Dictionary = {}            # index de tuile → id de matériau (filons) ; sinon materiau_defaut
var materiau_defaut: String = "":         # le matériau des murs ordinaires (materiau_mur du thème)
	set(v):
		materiau_defaut = v
		_frott_sale = true
var meubles: Dictionary = {}              # index de tuile → id du meuble AU SOMMET de la pile (data/meubles/)
## Les tuiles qui portent PLUSIEURS meubles (designer 2026-09-08, ordre de travail 26 undecies) : index → tableau du
## bas vers le haut. Comme pour les êtres, seules les tuiles à plusieurs y figurent.
var piles_meubles: Dictionary = {}        # index de tuile → Array[String], du bas vers le haut
var stations_fixes: Dictionary = {}       # index de tuile → id de station posée
var niveau_eau: Dictionary = {}           # index de tuile → niveau 1-7 d'un écoulement (Eau et liquides) ; une source vaut 8
var dangers: Dictionary = {}              # index de tuile → intensité 1-100 : à éviter en chemin (Émergence — le champ de danger, 2026-09-08). Le booléen d'avant ne disait que « oui » ; le noyau refuse toujours toute valeur non nulle, donc graduer ne change rien pour lui.
var neige := false                        # état météo de la grille (Météo) : chaque pas coûte neige_surcout de plus
var gel := false                          # sous 0 °C : l'eau est de la glace, elle se marche
var sols: Dictionary = {}                 # index de tuile → id de matériau de sol (surface) ; vide = sol par défaut
var origine := Vector2i.ZERO              # coordonnée monde de la tuile locale (0, 0) — fenêtre glissante (Monde)
var modifies: Dictionary = {}             # index de tuile → true : tuiles modifiées depuis la construction (capture par cellule)
var niveaux_bat := PackedByteArray()      # niveaux du bâtiment qui couvre la tuile (0 : hors bâtiment) — pour le dessin des façades et des toits (Villes, 2026-09-06)
var bat_de := PackedInt32Array()          # 1 + l'index du bâtiment dans batiments_liste (0 : aucun)
var batiments_liste: Array = []           # les bâtiments de la fenêtre : {"cle", "niveaux", "toit", "mur", "rect"}

## Le noyau C++ (SensenGrille, GDExtension `sensen_grille`, Modules de la simulation et le C++, section 3, 2026-09-06) :
## présent quand la bibliothèque est chargée, sinon tout se calcule en GDScript — les mêmes fonctions, les mêmes
## résultats (test_noyau_cpp les compare). Le noyau lit l'état de la grille au moment de l'appel : les tableaux
## compacts ci-dessous sont les MIROIRS des dictionnaires (occupants, dangers, niveau_eau, sols), tenus à jour par
## les méthodes placer/liberer, poser_danger/oter_danger, poser_eau/oter_eau, recompiler_sols — écrire dans le
## dictionnaire sans passer par elles désynchronise le noyau (test_noyau_cpp vérifie aussi les miroirs).
static var noyau_actif: bool = true        # false : tout en GDScript (mesures, équivalence)
static var _noyau_classe: int = -1         # -1 pas encore regardé, 0 la classe est absente, 1 présente
var _noyau: RefCounted = null
var _noyau_sale := true                    # règles ou œil changés : reconfigurer le noyau
var _table_n := -1                         # taille de contenu_ids à la dernière table de drapeaux
var occ := PackedByteArray()               # miroir de occupants : 1 = occupée
var danger_a := PackedByteArray()          # miroir de dangers : l'INTENSITÉ 1-100 (Émergence, 2026-09-08), 0 = sûr. Le noyau refuse toute valeur non nulle : graduer ne change rien pour lui, et l'IA peut peser.
var eau_a := PackedByteArray()             # miroir de niveau_eau : niveau + 1 (0 = pas d'entrée)
var frott_a := PackedFloat64Array()        # le multiplicateur de friction de chaque tuile (sols, materiau_defaut)
var _frott_sale := true
var transparent_a := PackedByteArray()     # miroir de materiaux : 1 = une matière qui laisse passer la lumière (le verre) — pour la propagation
var _n_materiaux := -1                     # materiaux.size() à la dernière compilation de transparent_a
var _n_occ := 0                            # les tailles des dictionnaires telles que les miroirs les ont vues (_miroirs_a_jour)
var _n_danger := 0
var _n_eau := 0


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
	occ.resize(l * h)
	danger_a.resize(l * h)
	eau_a.resize(l * h)
	niveaux_bat.resize(l * h)
	bat_de.resize(l * h)
	if noyau_present():
		_noyau = ClassDB.instantiate(&"SensenGrille")


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
	# Le plein, en bloc : ~3 500 tuiles par étage. `poser_contenu` tuile par tuile relisait le contenu d'avant (vide sur
	# une grille neuve) et marquait chaque tuile dans `modifies` (« modifiée depuis la construction » — à la construction,
	# c'était 3 500 entrées de dictionnaire pour rien) : 13,8 ms par étage (2026-09-07).
	var id_roche := g.id_contenu("roche")
	var id_mur := g.id_contenu("mur")
	var sol_e: Dictionary = etage.sol
	var bord_e: Dictionary = etage.get("bord", {})
	for i in g.largeur * g.hauteur_grille:
		if not sol_e.has(i):
			g.contenu[i] = id_roche if bord_e.has(i) else id_mur
	for i in etage.get("meubles", {}).keys():   # Talents de race : source maudite, autel du rituel
		var pm := Vector2i(int(i) % g.largeur, int(i) / g.largeur)
		g.poser_meuble(int(i), str(etage.meubles[i]))
		g.poser_contenu(pm, "meuble")
	for i in etage.get("portes", {}).keys():   # les seuils fermés des salles (Génération de donjon, 2026-08-30)
		g.poser_contenu(Vector2i(int(i) % g.largeur, int(i) / g.largeur), "porte_fermee")
	for i in etage.get("lave", {}).keys():   # Eau et liquides : les mares de lave
		g.poser_contenu(Vector2i(int(i) % g.largeur, int(i) / g.largeur), "lave")
		g.poser_danger(int(i))
	return g


# ---------------------------------------------------------------- accès

func idx(p: Vector2i) -> int:
	@warning_ignore("integer_division")
	var z := p.y / BANDE_Z   # une coordonnée négative (hors du monde) tombe sur la couche 0
	return z * (largeur * hauteur_grille) + (p.y - z * BANDE_Z - origine.y) * largeur + (p.x - origine.x)


## La position monde d'un index de tuile (sur sa couche : y porte z × BANDE_Z).
func pos_de(i: int) -> Vector2i:
	var n0 := largeur * hauteur_grille
	@warning_ignore("integer_division")
	var z := i / n0
	var r := i % n0
	@warning_ignore("integer_division")
	return origine + Vector2i(r % largeur, r / largeur) + Vector2i(0, z * BANDE_Z)


## La couche d'une position (0 : le sol).
static func z_de(p: Vector2i) -> int:
	@warning_ignore("integer_division")
	return p.y / BANDE_Z if p.y >= 0 else 0


## La position au sol d'une position de n'importe quelle couche.
static func plat(p: Vector2i) -> Vector2i:
	return Vector2i(p.x, p.y - z_de(p) * BANDE_Z)


## La même tuile à la couche z.
static func en_couche(p: Vector2i, z: int) -> Vector2i:
	return Vector2i(p.x, p.y - z_de(p) * BANDE_Z + z * BANDE_Z)


## La distance au sol, couches confondues (le client : ce qui est à l'écran, quelle que soit la hauteur).
static func distance_plate(a: Vector2i, b: Vector2i) -> int:
	return distance(plat(a), plat(b))


## Le nombre de tuiles de la grille, toutes couches comprises (la taille de ses tableaux par tuile).
func n_tuiles() -> int:
	return largeur * hauteur_grille * couches


## Donne à la grille `k` couches (Monde.fenetre, après le sol) : les tableaux par tuile s'allongent ; les couches neuves
## ont les hauteurs du sol (un étage est à plat sur sa tuile) et sont pleines de `vide` (l'air : on n'y marche pas, on
## voit au travers) — les bâtiments y posent ensuite leurs étages.
func poser_couches(k: int) -> void:
	k = maxi(1, k)
	if k == couches:
		return
	var n0 := largeur * hauteur_grille
	var sol_h := hauteurs.slice(0, n0)
	var vide_id := _index_contenu("vide")
	var couche_c := PackedInt32Array()
	couche_c.resize(n0)
	couche_c.fill(vide_id)
	var couche_z := PackedInt32Array()
	couche_z.resize(n0)
	var couche_b := PackedByteArray()
	couche_b.resize(n0)
	hauteurs = sol_h
	contenu = contenu.slice(0, n0)
	c_data = c_data.slice(0, n0)
	sol = sol.slice(0, n0)
	for z in range(1, k):
		hauteurs += sol_h
		contenu += couche_c
		c_data += couche_z
		sol += couche_z
	couches = k
	var n := n0 * k
	occ.resize(n)
	danger_a.resize(n)
	eau_a.resize(n)
	niveaux_bat.resize(n)
	bat_de.resize(n)
	lien_a.resize(n)
	lien_a.fill(-1)
	occ.fill(0)
	danger_a.fill(0)
	eau_a.fill(0)
	_n_occ = -1
	_n_danger = -1
	_n_eau = -1
	_n_materiaux = -1
	_frott_sale = true


## L'index d'un contenu par son id, ajouté à la table s'il manque (0 : inconnu du catalogue).
func _index_contenu(id: String) -> int:
	if id.is_empty() or not contenu_defs.has(id):
		return 0
	var ci := contenu_ids.find(id)
	if ci < 0:
		contenu_ids.append(id)
		ci = contenu_ids.size() - 1
	return ci


## Un escalier : la tuile `a` (la marche du bas) et la tuile `b` (l'arrivée, une autre couche) se répondent.
func poser_lien(a: Vector2i, b: Vector2i) -> void:
	var ia := idx(a)
	var ib := idx(b)
	if lien_a.size() != n_tuiles():
		lien_a.resize(n_tuiles())
		lien_a.fill(-1)
	if ia < 0 or ib < 0 or ia >= lien_a.size() or ib >= lien_a.size():
		return
	lien_a[ia] = ib
	lien_a[ib] = ia


func a_lien(p: Vector2i) -> bool:
	if lien_a.is_empty() or not dans(p):
		return false
	return lien_a[idx(p)] >= 0


## L'autre bout de l'escalier de `p` (`p` s'il n'en a pas).
func lien_de(p: Vector2i) -> Vector2i:
	if not a_lien(p):
		return p
	return pos_de(lien_a[idx(p)])


## Marque une tuile modifiée (Monde.capturer la mémorise par cellule).
func marquer(p: Vector2i) -> void:
	modifies[idx(p)] = true


func dans(p: Vector2i) -> bool:
	@warning_ignore("integer_division")
	var z := p.y / BANDE_Z
	if z >= couches:
		return false
	var ly := p.y - z * BANDE_Z
	return p.x >= origine.x and ly >= origine.y and p.x < origine.x + largeur and ly < origine.y + hauteur_grille


func h(p: Vector2i) -> int:
	return hauteurs[idx(p)]


func poser_contenu(p: Vector2i, id: String) -> void:
	var avant: Array = contenu_de(p).get("tags", [])
	if "liquide" in avant:   # le contenu remplacé (du butin posé sur l'eau) : la tuile reste mouillée (Eau et liquides)
		poser_eau(idx(p), 8 if "source" in avant else int(niveau_eau.get(idx(p), 1)))
	contenu[idx(p)] = id_contenu(id)
	modifies[idx(p)] = true


## L'index d'un identifiant de contenu dans `contenu_ids`, ajouté s'il est nouveau.
func id_contenu(id: String) -> int:
	var i := contenu_ids.find(id)
	if i < 0:
		contenu_ids.append(id)
		i = contenu_ids.size() - 1
	return i


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


## Le SOMMET de la pile d'une tuile — l'être qu'on vise, qu'on attaque, qu'on survole. Les cent quatre-vingts
## lecteurs de cette fonction n'ont pas eu à changer quand la tuile est devenue une pile (2026-09-09) : c'est tout
## le bénéfice d'avoir gardé `occupants` sous sa forme d'avant, un id par tuile, et d'avoir mis les tuiles à
## PLUSIEURS occupants dans un second dictionnaire.
func occupant(p: Vector2i) -> String:
	return occupants.get(idx(p), "")


## Toute la pile, du BAS vers le HAUT (designer 2026-09-08 : « les entités peuvent se stack sur la même case, un
## PNJ peut porter un PNJ qui porte un PNJ »). Un seul occupant : un tableau d'un élément ; aucun : vide.
func occupants_de(p: Vector2i) -> Array:
	var i := idx(p)
	if piles.has(i):
		return piles[i]
	var un: String = occupants.get(i, "")
	return [] if un.is_empty() else [un]


## L'étage d'un être dans la pile de sa tuile : 0 au sol, 1 sur les épaules du premier. −1 s'il n'y est pas.
func etage_pile(p: Vector2i, id: String) -> int:
	return occupants_de(p).find(id)


## Poser un être sur une tuile : il arrive AU SOMMET de la pile. Reposer un être déjà présent le remet au sommet
## plutôt que de le compter deux fois — un `placer` sans `liberer` est une erreur d'appelant, pas un doublon.
func placer(id: String, p: Vector2i) -> void:
	var pile := occupants_de(p)
	pile.erase(id)
	pile.append(id)
	_poser_pile(idx(p), pile)


## Retirer un être. Sans `id`, on retire le SOMMET : c'est ce que faisait cette fonction quand une tuile ne tenait
## qu'un occupant, et c'est encore juste partout où l'appelant est seul sur sa tuile. Là où un être peut être SOUS
## un autre — le déplacement, la mort, la téléportation —, l'appelant donne son id.
func liberer(p: Vector2i, id: String = "") -> void:
	var pile := occupants_de(p)
	if pile.is_empty():
		return
	if id.is_empty():
		pile.pop_back()
	else:
		pile.erase(id)
	_poser_pile(idx(p), pile)


## Le sommet, le dictionnaire des piles et le miroir d'octets, tenus ensemble. Le miroir garde son sens d'avant —
## 1 = il y a quelqu'un —, donc le noyau C++ n'a pas une ligne à changer.
func _poser_pile(i: int, pile: Array) -> void:
	if pile.is_empty():
		occupants.erase(i)
		piles.erase(i)
	else:
		occupants[i] = str(pile.back())
		if pile.size() > 1:
			piles[i] = pile
		else:
			piles.erase(i)
	if i >= 0 and i < occ.size():
		occ[i] = 0 if pile.is_empty() else 1
	_n_occ = occupants.size()


## Toute la pile de meubles d'une tuile, du BAS vers le HAUT (designer 2026-09-08 : « on peut aussi mettre des
## meubles les uns sur les autres »). Un seul meuble : un tableau d'un élément ; aucun : vide.
func meubles_de(i: int) -> Array:
	if piles_meubles.has(i):
		return piles_meubles[i]
	var un: String = meubles.get(i, "")
	return [] if un.is_empty() else [un]


## Poser un meuble AU SOMMET de la pile d'une tuile.
func poser_meuble(i: int, id: String) -> void:
	var pile := meubles_de(i)
	pile.append(id)
	_poser_pile_meubles(i, pile)


## Retirer un meuble. Sans `id`, on retire celui du SOMMET — c'est celui qu'on démonte, celui qu'on voit.
func retirer_meuble(i: int, id: String = "") -> void:
	var pile := meubles_de(i)
	if pile.is_empty():
		return
	if id.is_empty():
		pile.pop_back()
	else:
		pile.erase(id)
	_poser_pile_meubles(i, pile)


## Vider toute la pile d'une tuile — ce que fait la restitution d'une cellule avant de reposer ce qu'elle a gardé.
func vider_meubles(i: int) -> void:
	meubles.erase(i)
	piles_meubles.erase(i)


func _poser_pile_meubles(i: int, pile: Array) -> void:
	if pile.is_empty():
		meubles.erase(i)
		piles_meubles.erase(i)
		return
	meubles[i] = str(pile.back())
	if pile.size() > 1:
		piles_meubles[i] = pile
	else:
		piles_meubles.erase(i)


## Une tuile à éviter en chemin — et son miroir pour le noyau. L'intensité va de 1 à 100 (Émergence, 2026-09-08) :
## 100 pour ce qui tue à coup sûr (le feu, la lave, un glyphe armé), moins pour ce qui gêne ou blesse peu. Le noyau
## refuse toute valeur non nulle, donc les appelants d'avant, qui ne passaient rien, gardent exactement leur sens.
func poser_danger(i: int, intensite: int = 100) -> void:
	dangers[i] = clampi(intensite, 1, 100)
	if i >= 0 and i < danger_a.size():
		danger_a[i] = clampi(intensite, 1, 100)
	_n_danger = dangers.size()


## Le danger d'une tuile, de 0 (sûre) à 100 (mortelle). C'est ce que l'IA lit pour CHOISIR, là où le chemin se contente
## de refuser.
func danger_de(p: Vector2i) -> int:
	return int(dangers.get(idx(p), 0))


func oter_danger(i: int) -> void:
	dangers.erase(i)
	if i >= 0 and i < danger_a.size():
		danger_a[i] = 0
	_n_danger = dangers.size()


## Le niveau d'eau mémorisé d'une tuile (Eau et liquides) — et son miroir pour le noyau.
func poser_eau(i: int, niveau: int) -> void:
	niveau_eau[i] = niveau
	if i >= 0 and i < eau_a.size():
		eau_a[i] = clampi(niveau + 1, 0, 255)
	_n_eau = niveau_eau.size()


func oter_eau(i: int) -> void:
	niveau_eau.erase(i)
	if i >= 0 and i < eau_a.size():
		eau_a[i] = 0
	_n_eau = niveau_eau.size()


## Le garde-fou des miroirs : une écriture directe dans le dictionnaire (`grille.dangers[i] = true`, comme un test le
## fait) change sa taille sans passer par les méthodes ; avant chaque calcul du noyau, une taille qui ne correspond
## plus à celle vue par le miroir le fait recompiler depuis le dictionnaire. Un échange à taille égale passerait,
## d'où les méthodes ; ceci rattrape le cas courant.
func _miroirs_a_jour() -> void:
	var n := n_tuiles()
	if occupants.size() != _n_occ:
		occ.fill(0)
		for k in occupants:
			var i := int(k)
			if i >= 0 and i < n:
				occ[i] = 1
		_n_occ = occupants.size()
	if dangers.size() != _n_danger:
		danger_a.fill(0)
		for k in dangers:
			var i := int(k)
			if i >= 0 and i < n:
				danger_a[i] = 1
		_n_danger = dangers.size()
	if niveau_eau.size() != _n_eau:
		eau_a.fill(0)
		for k in niveau_eau:
			var i := int(k)
			if i >= 0 and i < n:
				eau_a[i] = clampi(int(niveau_eau[k]) + 1, 0, 255)
		_n_eau = niveau_eau.size()


## À appeler après avoir rempli `sols` en bloc (ou changé materiau_defaut) : la friction se recompile au prochain calcul.
func recompiler_sols() -> void:
	_frott_sale = true


## Le miroir des matières transparentes, recompilé quand `materiaux` a changé de taille (les tuiles de verre) :
## `transparents` est la liste des ids qui laissent passer la lumière (Éclairage, la propagation par le noyau).
func transparents_a_jour(transparents: PackedStringArray) -> void:
	if materiaux.size() == _n_materiaux and transparent_a.size() == n_tuiles():
		return
	_n_materiaux = materiaux.size()
	var n := n_tuiles()
	transparent_a.resize(n)
	transparent_a.fill(0)
	if transparents.size() <= 1:   # rien que l'entrée vide : aucune matière transparente au catalogue
		return
	for k in materiaux:
		var i := int(k)
		if i >= 0 and i < n and str(materiaux[k]) in transparents:
			transparent_a[i] = 1


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
	return _frott_de(str(sols.get(idx(t), materiau_defaut)), sm)


## Le multiplicateur de friction d'un matériau de sol (la formule de « Application des stats de matériau »).
static func _frott_de(mid: String, sm: Dictionary) -> float:
	var m: Dictionary = GameData.catalogues.materials.get(mid, {})
	if m.is_empty():
		return 1.0
	var f := float(m.get("stats", {}).get("friction", 50.0))
	return clampf(float(sm.get("friction_base", 0.85)) + f * float(sm.get("friction_par_point", 0.003)),
		float(sm.get("friction_min", 0.85)), float(sm.get("friction_max", 1.15)))


## Le miroir de friction par tuile pour le noyau : recompilé quand `sols` ou materiau_defaut ont changé.
func _recompiler_frott() -> void:
	_frott_sale = false
	var n := n_tuiles()
	if frott_a.size() != n:
		frott_a.resize(n)
	var sm: Dictionary = GameData.config("combat_rules").get("stats_materiau", {})
	if sm.is_empty():
		frott_a.fill(1.0)
		return
	frott_a.fill(_frott_de(materiau_defaut, sm))
	var cache := {}   # matériau → multiplicateur : une fenêtre a des milliers de tuiles et une dizaine de sols
	for k in sols:
		var i := int(k)
		if i < 0 or i >= n:
			continue
		var mid := str(sols[k])
		if not cache.has(mid):
			cache[mid] = _frott_de(mid, sm)
		frott_a[i] = cache[mid]


## Une chute (descente ≥ chute_delta) est autorisée en un pas volontaire : dégâts = (niveaux − franchise) × 5.
func est_chute(de: Vector2i, vers: Vector2i) -> bool:
	return dans(vers) and not bloque_passage(vers) and h(de) - h(vers) >= int(dep["chute_delta"])


func degats_chute(niveaux: int) -> int:
	return maxi(0, niveaux - int(dep["chute_franchise"])) * int(dep["chute_degats_par_niveau"])


## A* 8-directions sur les coûts de pente. Retourne les étapes SANS la case de départ.
## `ignorer` : id d'entité dont on ignore l'occupation (la cible, pour s'approcher d'elle).
## `bloque_a` (2026-09-09, ordre de travail 26 nonies) : un miroir d'octets de la forme d'`occ` — 1 = cette tuile
## barre CELUI QUI CHERCHE. Vide, on retombe sur `occ` : toute tuile occupée barre, ce qui était la règle d'avant.
## L'appelant qui connaît l'hostilité (`Simulation.bloque_pour`) efface les tuiles de ceux qui ne lui sont pas
## hostiles, et le chemin les traverse — un villageois dans une embrasure ne ferme plus le couloir.
func chemin(depart: Vector2i, arrivee: Vector2i, volant: bool = false, ignorer: String = "", eviter_nage: bool = false, max_noeuds: int = 0, bloque_a: PackedByteArray = PackedByteArray()) -> Array[Vector2i]:
	if _noyau_pret():
		var res: Array[Vector2i] = _noyau.chemin(self, depart, arrivee, volant, ignorer, eviter_nage, max_noeuds, bloque_a)
		return res
	return _chemin_gd(depart, arrivee, volant, ignorer, eviter_nage, max_noeuds, bloque_a)


## La version GDScript du chemin — la référence dont le noyau C++ est la transcription.
func _chemin_gd(depart: Vector2i, arrivee: Vector2i, volant: bool = false, ignorer: String = "", eviter_nage: bool = false, max_noeuds: int = 0, bloque_a: PackedByteArray = PackedByteArray()) -> Array[Vector2i]:
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
		var voisins: Array[Vector2i] = []   # les huit pas, et l'autre bout de l'escalier où l'on se tient (un pas de base)
		var couts: Array[int] = []
		for d in DIRS:
			var v := courant + d
			var cout := cout_pas(courant, v, volant, eviter_nage)
			if cout < 0:
				continue
			# Un escalier ne se tient pas : y poser le pied, c'est arriver à l'autre bout (une autre couche).
			voisins.append(lien_de(v) if a_lien(v) else v)
			couts.append(cout)
		if courant == depart and a_lien(courant):
			voisins.append(lien_de(courant))
			couts.append(base)
		for k in voisins.size():
			var voisin: Vector2i = voisins[k]
			var cout: int = couts[k]
			if _barre(voisin, bloque_a) and occupant(voisin) != ignorer and voisin != arrivee:
				continue
			if dangers.has(idx(voisin)) and voisin != arrivee:   # on contourne le feu
				continue
			var ng: int = g[courant] + cout
			if ng < int(g.get(voisin, 1 << 30)):
				g[voisin] = ng
				vient_de[voisin] = courant
				_tas_push(ouverts, Vector3i(voisin.x, voisin.y, ng + base * distance_plate(voisin, arrivee)))
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


## Cette tuile barre-t-elle celui qui cherche ? Avec un `bloque_a` de la bonne taille, c'est lui qui décide — il
## dit tuile par tuile qui gêne CE marcheur-là. Sans lui, la règle d'avant : toute tuile occupée barre.
func _barre(t: Vector2i, bloque_a: PackedByteArray) -> bool:
	if bloque_a.size() != occ.size():
		return not occupant(t).is_empty()
	var i := idx(t)
	return i >= 0 and i < bloque_a.size() and bloque_a[i] != 0


## Dijkstra borné : tuile → coût en ticks pour l'atteindre (UI : coûts sur les tuiles atteignables).
func atteignables(depart: Vector2i, budget: int, volant: bool = false, eviter_nage: bool = false, bloque_a: PackedByteArray = PackedByteArray()) -> Dictionary:
	if _noyau_pret():
		return _noyau.atteignables(self, depart, budget, volant, eviter_nage, bloque_a)
	return _atteignables_gd(depart, budget, volant, eviter_nage, bloque_a)


func _atteignables_gd(depart: Vector2i, budget: int, volant: bool = false, eviter_nage: bool = false, bloque_a: PackedByteArray = PackedByteArray()) -> Dictionary:
	var couts := {depart: 0}
	var file: Array[Vector2i] = [depart]
	while not file.is_empty():
		var k := 0
		for i in file.size():
			if couts[file[i]] < couts[file[k]]:
				k = i
		var c: Vector2i = file[k]
		file.remove_at(k)
		var voisins: Array[Vector2i] = []
		var couts_v: Array[int] = []
		for d in DIRS:
			var v := c + d
			var cout := cout_pas(c, v, volant, eviter_nage)
			if cout < 0:
				continue
			voisins.append(lien_de(v) if a_lien(v) else v)   # l'escalier mène à l'autre bout
			couts_v.append(cout)
		if c == depart and a_lien(c):
			voisins.append(lien_de(c))
			couts_v.append(int(dep["cout_base"]))
		for kv in voisins.size():
			var v: Vector2i = voisins[kv]
			if _barre(v, bloque_a):
				continue
			var nc: int = couts[c] + couts_v[kv]
			if nc <= budget and nc < int(couts.get(v, 1 << 30)):
				couts[v] = nc
				file.append(v)
	return couts


# ---------------------------------------------------------------- vue

## Ligne de vue a → b : un relief (ou un mur) plus haut que la ligne des yeux coupe la vue.
func ligne_de_vue(a: Vector2i, b: Vector2i) -> bool:
	if _noyau_pret():
		return _noyau.ligne_de_vue(self, a, b)
	return _ligne_de_vue_gd(a, b)


func _ligne_de_vue_gd(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	if not dans(a) or not dans(b) or z_de(a) != z_de(b):   # une position d'une autre grille, ou d'une autre couche : hors de vue
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
	if _noyau_pret():
		return _noyau.premier_obstacle_vue(self, a, b)
	return _premier_obstacle_vue_gd(a, b)


func _premier_obstacle_vue_gd(a: Vector2i, b: Vector2i) -> Vector2i:
	if a == b or not dans(a) or not dans(b) or z_de(a) != z_de(b):
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


## Le champ de vue depuis `pos` à `portee` (Tchebychev) : les index des tuiles de la grille en ligne de vue, dans
## l'ordre du balayage (dy puis dx) — c'est la boucle de Simulation.maj_vision, que le noyau calcule d'un trait.
func champ_de_vue(pos: Vector2i, portee: int) -> PackedInt32Array:
	if _noyau_pret():
		return _noyau.champ_de_vue(self, pos, portee)
	return _champ_de_vue_gd(pos, portee)


func _champ_de_vue_gd(pos: Vector2i, portee: int) -> PackedInt32Array:
	var res := PackedInt32Array()
	if not dans(pos):
		return res
	for dy in range(-portee, portee + 1):
		for dx in range(-portee, portee + 1):
			var t := pos + Vector2i(dx, dy)
			if dans(t) and _ligne_de_vue_gd(pos, t):
				res.append(idx(t))
	return res


## La carte d'ombre d'un rectangle de tuiles (Éclairage, le soleil, 2026-09-06) : depuis chaque tuile, on marche vers le
## soleil (`dir`, direction dans la grille, unitaire) ; au k-ième pas, ce qui se dresse là — le sol, plus le bloc :
## hauteur_vue d'un contenu qui bloque la vue, ou les niveaux du bâtiment × unites_par_niveau — fait de l'ombre s'il
## dépasse le sol de la tuile de plus de `pente` × k unités. Un octet par tuile, ligne par ligne, 1 = à l'ombre.
func ombres(dir: Vector2, pente: float, coin: Vector2i, taille: Vector2i, max_pas: int, unites_par_niveau: int) -> PackedByteArray:
	if _noyau_pret():
		return _noyau.ombres(self, dir, pente, coin, taille, max_pas, unites_par_niveau)
	return _ombres_gd(dir, pente, coin, taille, max_pas, unites_par_niveau)


func _ombres_gd(dir: Vector2, pente: float, coin: Vector2i, taille: Vector2i, max_pas: int, unites_par_niveau: int) -> PackedByteArray:
	var res := PackedByteArray()
	if taille.x <= 0 or taille.y <= 0:
		return res
	res.resize(taille.x * taille.y)
	for ly in taille.y:
		for lx in taille.x:
			var t := coin + Vector2i(lx, ly)
			var ombre := 0
			if dans(t):
				var h0 := h(t)
				for k in range(1, max_pas + 1):
					var q := Vector2i(t.x + roundi(dir.x * k), t.y + roundi(dir.y * k))
					if not dans(q):
						break
					var qi := idx(q)
					var c := contenu_de(q)
					var hv := int(c.get("hauteur_vue", 0)) if bool(c.get("bloque_vue", false)) else 0
					var n := int(niveaux_bat[qi])
					if n > 0:
						hv = maxi(hv, n * unites_par_niveau)
					if float(int(hauteurs[qi]) + hv - h0) > pente * k:
						ombre = 1
						break
			res[ly * taille.x + lx] = ombre
	return res


## La lumière de chaque tuile (Éclairage, designer 2026-09-06 : « une tuile n'est pas juste éclairée ou pas, c'est une
## échelle et il y a une teinte ») : le ciel (niveau et teinte de l'heure), assombri de `ombre_portee` sur les tuiles
## à l'ombre du rectangle coin/taille, plus la lumière locale (`locale` : 0-15 par tuile — torches, meubles, propagés
## par la simulation) × force à sa teinte, borné à 1. Trois octets par tuile (RGB) : la texture que le shader multiplie.
func carte_lumiere(ciel: Color, locale: PackedByteArray, teinte_locale: Color, force_locale: float, dir: Vector2, pente: float, max_pas: int, unites_par_niveau: int, ombre_portee: float, coin: Vector2i, taille: Vector2i) -> PackedByteArray:
	if _noyau_pret():
		return _noyau.carte_lumiere(self, ciel, locale, teinte_locale, force_locale, dir, pente, max_pas, unites_par_niveau, ombre_portee, coin, taille)
	return _carte_lumiere_gd(ciel, locale, teinte_locale, force_locale, dir, pente, max_pas, unites_par_niveau, ombre_portee, coin, taille)


func _carte_lumiere_gd(ciel: Color, locale: PackedByteArray, teinte_locale: Color, force_locale: float, dir: Vector2, pente: float, max_pas: int, unites_par_niveau: int, ombre_portee: float, coin: Vector2i, taille: Vector2i) -> PackedByteArray:
	var n := largeur * hauteur_grille
	var res := PackedByteArray()
	res.resize(n * 3)
	var avec_ombre := ombre_portee > 0.0 and max_pas > 0 and taille.x > 0 and taille.y > 0
	var ombre := _ombres_gd(dir, pente, coin, taille, max_pas, unites_par_niveau) if avec_ombre else PackedByteArray()
	var loc_ok := locale.size() >= n
	for i in n:
		var x := origine.x + i % largeur
		var y := origine.y + i / largeur
		var r := float(ciel.r)
		var g := float(ciel.g)
		var b := float(ciel.b)
		if avec_ombre:
			var lx := x - coin.x
			var ly := y - coin.y
			if lx >= 0 and ly >= 0 and lx < taille.x and ly < taille.y and ombre[ly * taille.x + lx] != 0:
				r *= (1.0 - ombre_portee)
				g *= (1.0 - ombre_portee)
				b *= (1.0 - ombre_portee)
		var l := float(locale[i]) / 15.0 * force_locale if loc_ok else 0.0
		r = minf(1.0, r + float(teinte_locale.r) * l)
		g = minf(1.0, g + float(teinte_locale.g) * l)
		b = minf(1.0, b + float(teinte_locale.b) * l)
		res[i * 3] = roundi(r * 255.0)
		res[i * 3 + 1] = roundi(g * 255.0)
		res[i * 3 + 2] = roundi(b * 255.0)
	return res


# ---------------------------------------------------------------- le noyau C++

## La classe SensenGrille est-elle chargée (GDExtension sensen_grille) ?
static func noyau_present() -> bool:
	if _noyau_classe < 0:
		_noyau_classe = 1 if ClassDB.class_exists(&"SensenGrille") else 0
	return _noyau_classe == 1


## Cette grille calcule-t-elle avec le noyau ? Le prépare au besoin (règles, œil, table des contenus, friction).
func _noyau_pret() -> bool:
	if _noyau == null or not noyau_actif:
		return false
	var n := n_tuiles()
	if hauteurs.size() != n or contenu.size() != n:
		return false   # une grille dont les tableaux ont été remplacés par d'autres tailles : le GDScript juge
	_miroirs_a_jour()
	if _frott_sale:
		_recompiler_frott()
	if _noyau_sale or contenu_ids.size() != _table_n:
		_noyau.configurer(dep, hauteur_oeil, _table_contenus())
		_noyau_sale = false
		_table_n = contenu_ids.size()
	return true


## La table des drapeaux par index de contenu, telle que le noyau la lit (SensenGrille::Drapeaux).
func _table_contenus() -> PackedInt32Array:
	var t := PackedInt32Array()
	t.resize(contenu_ids.size())
	for i in range(1, contenu_ids.size()):
		var def: Dictionary = contenu_defs.get(contenu_ids[i], {})
		var tags: Array = def.get("tags", [])
		var f := 0
		if bool(def.get("bloque_passage", false)):
			f |= 1
		if "fermee" in tags:
			f |= 2
		if "nage" in tags:
			f |= 4
		if "liquide" in tags:
			f |= 8
		if "source" in tags:
			f |= 16
		if "ecoulement" in tags:
			f |= 32
		if bool(def.get("bloque_vue", false)):
			f |= 64
		f |= (int(def.get("hauteur_vue", 0)) & 0xFF) << 8
		if "porte" in tags:   # les drapeaux des passes de dessin (file 114) : ce que le client lit des tags
			f |= 1 << 16
		if "vegetation" in tags:
			f |= 1 << 17
		if "mur" in tags:
			f |= 1 << 18
		if not def.has("hauteur_vue"):
			f |= 1 << 19
		if "meuble" in tags:
			f |= 1 << 20
		if "contenant" in tags:
			f |= 1 << 21
		if def.has("couleur"):
			f |= 1 << 22
		if "arbre" in tags:
			f |= 1 << 23
		t[i] = f
	return t
