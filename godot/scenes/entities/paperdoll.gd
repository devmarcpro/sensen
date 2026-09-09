class_name Paperdoll
extends Node2D
## Le rendu d'un être — creature.tscn, la seule scène pour tout être vivant (Décisions
## d'architecture). Tout vient des données : la silhouette du rig (`data/rigs/`), les pièces
## d'équipement aux ancrages (Squelette modulaire et points d'attache), la teinte du matériau
## (Palette de couleurs des matériaux). Aucune branche par type d'être (Apparence — données).
## Un segment est une ORIENTATION DANS L'ESPACE du corps depuis le 2026-09-08 : le lacet le tourne, l'isométrie le
## projette, et la profondeur donne l'ordre de dessin — plus un seul ordre de calque ni un seul décalage à la main.

## Orientation de grille → facing d'écran (géométrie de la vue, pas du gameplay).
## Épaisseur de contour par construction — « la construction est la forme, le matériau la teinte ».
const CONTOURS := {"matelasse": 0.6, "cuir": 1.0, "mailles": 1.4, "ecailles": 1.6, "plaque": 2.2}

var e: Dictionary = {}          # l'être (état de la simulation)
var rig: Dictionary = {}
var items: Dictionary = {}
var fonctionnalites: Dictionary = {}
var palette: Dictionary = {}
var dessine_apres: Callable     # le client peut dessiner par-dessus (tuiles occultantes)
## Les occulteurs se dessinent sur un ENFANT fixé au monde (2026-09-06, designer : « quand un paperdoll se déplace il
## emmène avec lui des blocs ») : le paperdoll glisse d'une tuile à l'autre (~0,2 s) et tout ce qui est dessiné sur lui
## glissait aussi — les murs redessinés par-dessus lui suivaient sa marche. L'enfant est replacé chaque image à la
## tuile visée (le client règle sa position à cible − position), ses commandes restent où sont les tuiles.
var occulteurs: Node2D = null
var lointain := false           # au-delà de tempo.pictogramme_au_dela tuiles du joueur : un pictogramme, pas le paperdoll (Budgets de performance, 2026-09-06)
var pose: Dictionary = {}       # segment → delta d'angle (animation par pivots)
var _anim_restant := 0.0
var _anim_duree := 0.25
var _ap: Dictionary = {}       # loci visuels de l'être (Apparence — données et équipement)
var _vue_tete := "face"
var _carrure := 1.0
var _pose_courante: Dictionary = {}   # la pose du joueur pour l'action en cours (point 63)
var _pose_marche: Dictionary = {}     # l'oscillation du pas (designer 2026-09-08) : recalculée quand `avancement` bouge
var avancement := -1.0                # 0 → 1 pendant un pas, −1 à l'arrêt ; le client la règle à chaque image
var _monde_dernier: Dictionary = {}   # les segments tels qu'ils viennent d'être posés, pour qui veut les situer
var _lacet := 0.0                     # le lacet du corps, en radians (la profondeur, designer 2026-09-08)
var _prof_ecran := Vector2(0.0, -0.5) # ce qu'une unité de profondeur (vers le FOND) fait à l'écran
var _largeur_min := 0.12              # le plancher absolu : un segment ne devient jamais un trait, même vu de bout
var _epaisseur_defaut := 0.7          # l'épaisseur d'un segment qui ne la déclare pas, en part de sa largeur
var _monde_dessine: Dictionary = {}   # dernier placement des segments — l'écran de pose y clique (point 68)
var _echelle_dessin := 1.0
var _peint: Dictionary = {}


## Les réglages de dessin (styles.json → sprites), lus une fois par image.
func _st_sprites() -> Dictionary:
	return GameData.config("styles").get("sprites", {})


func configurer(p_e: Dictionary, p_rig: Dictionary, p_items: Dictionary, p_fonct: Dictionary, p_palette: Dictionary) -> void:
	e = p_e
	rig = p_rig
	items = p_items
	fonctionnalites = p_fonct
	palette = p_palette


## Animation par pivots : une frappe fait pivoter le bras d'arme, sans dessiner de frame.
func frapper() -> void:
	var seg: Variant = rig.get("prise_arme")
	if seg is String:
		var haut := str(seg).replace("main", "bras_haut")
		var bas := str(seg).replace("main", "bras_bas")
		pose = {haut: -70.0, bas: -30.0}
		_anim_restant = _anim_duree


var _encaisse_restant := 0.0   # le retour d'un coup reçu (Écrans d'interface, 2026-09-05) : tremblement et rouge, le temps de styles.coups
var _encaisse_duree := 0.0
var _decalage := Vector2.ZERO   # le tremblement du moment, appliqué au repère de dessin


## Un coup reçu : le personnage tremble et clignote rouge un instant (designer 2026-09-05, 13 h).
func encaisser() -> void:
	var st: Dictionary = GameData.config("styles").get("coups", {})
	_encaisse_duree = maxf(float(st.get("secousse_s", 0.22)), float(st.get("rouge_s", 0.16)))
	_encaisse_restant = _encaisse_duree
	queue_redraw()


func _process(delta: float) -> void:
	if _anim_restant > 0.0:
		_anim_restant -= delta
		if _anim_restant <= 0.0:
			pose = {}
		queue_redraw()
	if _encaisse_restant > 0.0:
		_encaisse_restant -= delta
		var st: Dictionary = GameData.config("styles").get("coups", {})
		var ecoule := _encaisse_duree - _encaisse_restant
		var amp := float(st.get("secousse_px", 2.5)) if ecoule < float(st.get("secousse_s", 0.22)) else 0.0
		_decalage = Vector2(randf_range(-amp, amp), randf_range(-amp, amp) * 0.5)
		var rouge := Color.html(str(st.get("rouge", "#ff6a5a")))
		var part := clampf(1.0 - ecoule / maxf(0.01, float(st.get("rouge_s", 0.16))), 0.0, 1.0)
		self_modulate = Color.WHITE.lerp(rouge, part)
		if _encaisse_restant <= 0.0:
			_decalage = Vector2.ZERO
			self_modulate = Color.WHITE
		queue_redraw()


# ---------------------------------------------------------------- rendu

func _draw() -> void:
	if e.is_empty() or rig.is_empty():
		return
	var t0_p := Time.get_ticks_usec()
	_dessiner_etre()
	var parent := get_parent()
	if parent != null and "chrono" in parent:
		parent.chrono["draw.paperdoll"] = float(parent.chrono.get("draw.paperdoll", 0.0)) + float(Time.get_ticks_usec() - t0_p) / 1000.0
		parent.chrono["n.paperdoll"] = float(parent.chrono.get("n.paperdoll", 0.0)) + 1.0


func _top_pp(cle: String, t0: int) -> int:
	var parent := get_parent()
	if parent != null and "chrono" in parent:
		parent.chrono[cle] = float(parent.chrono.get(cle, 0.0)) + float(Time.get_ticks_usec() - t0) / 1000.0
	return Time.get_ticks_usec()


func _dessiner_etre() -> void:
	if "vehicule" in e.get("tags", []):   # un train, une calèche : une caisse et des roues tant qu'il n'y a pas de sprite (Villes B4)
		_dessine_vehicule()
		return
	if lointain:   # de loin, une silhouette : trois primitives, aucun redessin quand il tourne ou s'équipe
		_dessine_pictogramme()
		return
	if e.has("monture"):
		_dessine_monture()
	# IL TOURNE POUR DE BON (designer 2026-09-08 : « rajouter la profondeur, comme ça on pourrait avoir les
	# personnages dans les 8 angles »). Le corps n'a plus un facing choisi parmi trois, il a un LACET continu tiré de
	# son orientation de grille : la composante « vers la caméra » est x + y (l'isométrie regarde la grille depuis le
	# sud-est), la composante « vers la droite de l'écran » est x − y. Les huit orientations du rig ne servent plus
	# qu'à nommer le lacet le plus proche pour choisir la vue de la tête.
	# TROIS DIRECTIONS (designer 2026-09-09 : « on va faire 3 orientations pour les personnages, droite gauche et de
	# face »). Le corps se CALE sur l'orientation la plus proche parmi celles que le rig DÉCLARE : c'est la table du
	# rig, et elle seule, qui dit combien de vues existent — trois aujourd'hui, la face et les deux profils, ce que
	# le designer dessine à la main. Y rajouter le dos ou les trois-quarts suffirait, sans une ligne de code.
	var o_e: Vector2i = e.get("orientation", Vector2i.ZERO)
	var ori := {}
	_lacet = 0.0
	if o_e != Vector2i.ZERO and bool(rig.get("lacet_actif", false)):
		ori = _orientation_proche(_dir_ecran(o_e))
		if ori.has("lacet"):
			_lacet = deg_to_rad(float(ori.lacet))
	if ori.is_empty():
		ori = _orientation_proche(Vector2(0.0, 1.0))   # sans mouvement : la vue qui regarde vers nous
	var st_pd: Dictionary = GameData.config("styles").get("sprites", {})
	_prof_ecran = Vector2(float(st_pd.get("profondeur_ecran", [0.0, -0.5])[0]), float(st_pd.get("profondeur_ecran", [0.0, -0.5])[1]))
	_largeur_min = float(st_pd.get("largeur_min_profil", 0.12))
	_epaisseur_defaut = float(st_pd.get("epaisseur_defaut", 0.7))
	_ap = e.get("apparence", {})
	_pose_courante = _pose_action()
	_vue_tete = str(ori.get("vue_tete", "face"))
	var fac: Dictionary = GameData.config("apparence").get("facteurs", {})
	_carrure = float(fac.get("carrure", {}).get(str(_ap.get("carrure", "moyenne")), 1.0))
	var ech := float(_ap.get("echelle", 1.0)) * float(fac.get("taille", {}).get(str(_ap.get("taille", "moyenne")), 1.0))
	if not is_equal_approx(ech, 1.0) or _decalage != Vector2.ZERO:
		draw_set_transform(_decalage, 0.0, Vector2(ech, ech))   # le tremblement d'un coup reçu décale tout le dessin
	var t_pp := Time.get_ticks_usec()
	var monde := _poser_segments()
	_monde_dernier = monde   # ce que l'écran d'anatomie interroge : OÙ chaque segment a réellement été posé
	t_pp = _top_pp("pd.segments", t_pp)
	_monde_dessine = monde
	_echelle_dessin = ech
	_peint = _segments_peints()
	t_pp = _top_pp("pd.peints", t_pp)
	var peint: Dictionary = _peint
	var teinte := Color(e.teinte[0], e.teinte[1], e.teinte[2])
	if not _ap.is_empty():   # nu : la peau peint le corps entier, l'équipement seul le recouvre (point 43)
		teinte = _teinte_de("teintes_peau", str(_ap.get("teinte_peau", "")), teinte)
	# LE PANTIN MONTRE LES BLESSURES (2026-09-09). Chaque segment dit désormais QUELLE PARTIE il dessine ; on ne
	# dessine donc pas un bras qu'on a perdu, et une partie entamée rougit à proportion de ce qui lui reste.
	# **La garde est explicite** : sans plan de corps — le pantin de la création, un être d'une vieille sauvegarde —
	# rien ne change. Une partie que le plan ne déclare pas se dessine comme avant. *Ce qui ne sait pas ne cache pas.*
	var plan_c: Dictionary = Etres.plan_corps(e)
	var coul_bl := Color.html(str(_st_sprites().get("blessure_couleur", "#8e2020")))
	var force_bl := float(_st_sprites().get("blessure_force", 0.65))
	for nom: String in _ordre_profondeur(monde):
		if not monde.has(nom):
			continue
		var m: Dictionary = monde[nom]
		var col := teinte
		var contour := 0.0
		if peint.has(nom):
			col = peint[nom].couleur
			contour = float(CONTOURS.get(peint[nom].construction, 1.0))
		if not plan_c.is_empty():
			var pc := str((rig.segments.get(nom, {}) as Dictionary).get("partie", ""))
			if not pc.is_empty() and (plan_c.parties as Dictionary).has(pc):
				if not Etres.partie_intacte(e, pc):
					continue   # ce membre n'est plus là : il ne se dessine pas
				var pmax := Etres.sante_partie_max(e, pc)
				if pmax > 0:
					var reste := clampf(float(Etres.sante_partie(e, pc)) / float(pmax), 0.0, 1.0)
					if reste < 1.0:
						col = col.lerp(coul_bl, (1.0 - reste) * force_bl)
		_dessine_segment(m, col, contour, nom)
		t_pp = _top_pp("pd.seg." + nom, t_pp)
	_dessine_tenus(monde)
	t_pp = _top_pp("pd.tenus", t_pp)
	if e.has("blason"):   # le garde porte le fanion de son royaume (D)
		var col := Color.html(str(e.blason))
		var h_f := float(rig.hauteur_pieds) + 6.0
		draw_line(Vector2(6.0, -h_f), Vector2(6.0, -h_f - 9.0), Color(0.25, 0.2, 0.15), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(6.0, -h_f - 9.0), Vector2(11.0, -h_f - 7.5), Vector2(6.0, -h_f - 6.0)]), col)
	if dessine_apres.is_valid():
		_assurer_occulteurs()
		occulteurs.queue_redraw()


func _assurer_occulteurs() -> void:
	if occulteurs != null:
		return
	occulteurs = Node2D.new()
	occulteurs.use_parent_material = true   # le grain et la lumière du terrain
	occulteurs.draw.connect(func() -> void:
		if dessine_apres.is_valid():
			dessine_apres.call(self))
	add_child(occulteurs)


## OÙ UN SEGMENT A ÉTÉ POSÉ, dans les coordonnées du pantin — la position de son origine et celle de son bout.
## L'écran d'anatomie s'en sert pour cadrer : demander au dessin où il a mis un bras vaut mieux que le deviner d'une
## table de proportions écrite à côté, qui vieillirait au premier rig retouché.
func position_segment(nom: String) -> Vector2:
	if not _monde_dernier.has(nom):
		return Vector2.ZERO
	var m: Dictionary = _monde_dernier[nom]
	var o: Vector2 = m.origine
	return o + m.direction * float(m.longueur) * 0.5


## Le pictogramme d'un être lointain (Budgets de performance, 2026-09-06) : un corps et une tête à la couleur de
## peau, à l'échelle de sa taille, un liseré rouge s'il est hostile — lisible à la taille d'une tuile, sans détail.
func _dessine_pictogramme() -> void:
	var col := Color(e.teinte[0], e.teinte[1], e.teinte[2])
	var ap: Dictionary = e.get("apparence", {})
	if not ap.is_empty():
		col = _teinte_de("teintes_peau", str(ap.get("teinte_peau", "")), col)
	var fac: Dictionary = GameData.config("apparence").get("facteurs", {})
	var ech := float(ap.get("echelle", 1.0)) * float(fac.get("taille", {}).get(str(ap.get("taille", "moyenne")), 1.0))
	var h := maxf(6.0, float(rig.hauteur_pieds) * 0.7 * ech)
	var l := 3.0 * ech
	draw_rect(Rect2(-l, -h, 2.0 * l, h), col.darkened(0.2))
	draw_circle(Vector2(0.0, -h - 2.5 * ech), 2.5 * ech, col)
	if str(e.get("camp", "")) == "hostile":
		draw_rect(Rect2(-l, -h, 2.0 * l, h), Color(0.9, 0.2, 0.2), false, 1.0)
	if dessine_apres.is_valid():
		dessine_apres.call(self)


func _dessine_vehicule() -> void:
	var col := Color(e.teinte[0], e.teinte[1], e.teinte[2])
	var h := float(rig.hauteur_pieds)
	var train: bool = "train" in e.get("tags", [])
	draw_rect(Rect2(-9.0, -h - 8.0, 18.0, 8.0), col)
	draw_rect(Rect2(-9.0, -h - 8.0, 18.0, 8.0), Color(0.1, 0.1, 0.1), false, 1.0)
	if train:
		draw_rect(Rect2(4.0, -h - 13.0, 3.0, 5.0), col.darkened(0.3))
		draw_rect(Rect2(-7.0, -h - 6.0, 4.0, 3.0), Color(0.85, 0.8, 0.5))
	else:
		draw_rect(Rect2(-7.0, -h - 6.0, 5.0, 4.0), Color(0.85, 0.8, 0.5))
	for x in [-5.0, 5.0]:
		draw_circle(Vector2(x, -h + 1.0), 3.0, Color(0.15, 0.15, 0.15))
		draw_circle(Vector2(x, -h + 1.0), 1.2, col.lightened(0.3))


func _dessine_monture() -> void:
	var m: Dictionary = e.monture.get("etre", {})
	var t: Array = m.get("teinte", [0.5, 0.4, 0.3])
	var col := Color(t[0], t[1], t[2])
	var h := float(rig.hauteur_pieds)
	draw_rect(Rect2(-9.0, -h + 1.0, 18.0, 5.0), col)
	draw_circle(Vector2(10.0, -h + 1.0), 3.0, col)
	for x in [-7.0, -3.0, 3.0, 7.0]:
		draw_line(Vector2(x, -h + 6.0), Vector2(x, -h + 10.0), col.darkened(0.2), 1.5)


## LE SQUELETTE A UNE PROFONDEUR (designer 2026-09-08 : « rajouter la profondeur, comme ça on pourrait avoir les
## personnages dans les 8 angles et faire des poses plus complexes » — ordre de travail 26 quater bis).
##
## Un segment n'est plus un angle d'écran, c'est une orientation dans l'ESPACE DU CORPS : `x` la droite de l'écran,
## `y` le bas de l'écran (le corps est debout, cet axe ne tourne pas), `z` la profondeur vers le fond. `angle` reste
## l'angle dans le plan (x, y) — les chiffres du rig n'ont pas changé de sens ; `profondeur` (degrés) fait sortir le
## segment de ce plan, vers l'avant quand elle est positive. Chaque frame est ensuite tournée du lacet du corps,
## puis projetée.
##
## Ce que ça supprime : les ordres de calque et les décalages d'ancrage écrits à la main pour les huit facings de
## chacun des six rigs — de la profondeur simulée, que la vraie calcule. Il ne reste qu'un `ordre` par rig, qui
## départage les ex æquo.
## Place chaque segment : {origine, direction, perp, longueur, largeur} à l'écran, et {origine3, dir3, perp3, norm3,
## z} dans l'espace du corps — c'est `z` qui décide de l'ordre de dessin.
func _poser_segments() -> Dictionary:
	var monde := {}
	var racine: String = rig.racine
	var restants: Array = rig.segments.keys()
	var herite := {racine: _delta_pose(racine)}   # ce que chaque segment transmet à ses enfants
	monde[racine] = _placer(racine, Vector3(0.0, -float(rig.hauteur_pieds), 0.0), Vector2.ZERO)
	restants.erase(racine)
	var garde_fou := 64
	while not restants.is_empty() and garde_fou > 0:
		garde_fou -= 1
		for nom in restants.duplicate():
			var s: Dictionary = rig.segments[nom]
			if not monde.has(s.parent):
				continue
			var p: Dictionary = monde[s.parent]
			var a: Array = rig.segments[s.parent].ancrages.get(s.ancrage, [0, 0, 0])
			var pt3: Vector3 = p.origine3 + p.dir3 * float(a[0]) + p.perp3 * float(a[1])
			if a.size() > 2:
				pt3 += p.norm3 * float(a[2])   # l'ancrage a une profondeur : l'épaule est DEVANT le plan du torse
			var h: Vector2 = herite.get(str(s.parent), Vector2.ZERO)
			monde[nom] = _placer(nom, pt3, h)
			herite[nom] = h + _delta_pose(nom)
			restants.erase(nom)
	return monde


## L'ordre de dessin : du plus loin au plus près. `rig.ordre` ne sert qu'à départager deux segments à la même
## profondeur (un serpent à plat, une méduse) — sans lui, `sort_custom` n'est pas stable et le pantin scintillerait.
func _ordre_profondeur(monde: Dictionary) -> Array:
	var rangs := {}
	var liste: Array = rig.get("ordre", [])
	for k in liste.size():
		rangs[str(liste[k])] = k
	var noms: Array = monde.keys()
	noms.sort_custom(func(a: String, b: String) -> bool:
		var za := float((monde[a] as Dictionary).z)
		var zb := float((monde[b] as Dictionary).z)
		if not is_equal_approx(za, zb):
			return za > zb   # le fond d'abord
		return int(rangs.get(a, 999)) < int(rangs.get(b, 999)))
	return noms


## Où va, À L'ÉCRAN, un pas dans cette direction de grille. C'est la projection du monde : `x − y` vers la droite,
## `x + y` vers le bas — et la seconde est écrasée de moitié par l'isométrie. C'est cet écrasement qui fait qu'un pas
## le long d'un axe de la grille se lit comme un déplacement LATÉRAL, et non comme une diagonale à quarante-cinq degrés.
func _dir_ecran(o: Vector2i) -> Vector2:
	return Vector2(float(o.x - o.y), float(o.x + o.y) * 0.5).normalized()


## L'orientation déclarée dont le regard, À L'ÉCRAN, ressemble le plus à la direction donnée. On compare des
## directions d'écran et non des angles de grille : sur un angle, les quatre pas le long des axes tombent à égalité
## parfaite entre deux vues (45° est à mi-chemin de 0 et de 90) et il faut trancher par une règle arbitraire — or
## toute règle arbitraire est un choix de design déguisé en détail technique. L'isométrie, elle, tranche seule.
##
## Le regard d'une vue de lacet θ va à l'écran vers `(sin θ ; cos θ / 2)` : la face regarde vers le bas (vers nous),
## le profil droit vers la droite. Même écrasement que pour le mouvement, donc la comparaison est juste.
func _orientation_proche(dir_ecran: Vector2) -> Dictionary:
	var orients: Dictionary = rig.get("orientations", {})
	if orients.is_empty():
		return {}
	var meilleure: Dictionary = {}
	var meilleur := -2.0
	for nom: String in orients.keys():
		var o: Dictionary = orients[nom]
		var t := deg_to_rad(float(o.get("lacet", 0.0)))
		var regard := Vector2(sin(t), cos(t) * 0.5).normalized()
		var d := regard.dot(dir_ecran)
		# `>` strict : À ÉGALITÉ, LA PREMIÈRE DÉCLARÉE GAGNE. Avec trois vues, un pas droit vers le haut de l'écran
		# — s'éloigner — met les deux profils à égalité parfaite, puisque aucun des deux ne regarde de ce côté.
		# L'ordre de la table du rig tranche donc, et c'est le seul endroit où il compte.
		if d > meilleur:
			meilleur = d
			meilleure = o
	return meilleure


## Ce qu'un segment ajoute à ses enfants : sa rotation de pose dans le plan (x) et en profondeur (y). L'angle de
## repos du rig est déjà absolu et ne doit pas se propager deux fois. Une pose vaut un nombre (l'angle seul, comme
## avant) ou un couple [angle, profondeur] — un bras qui part en arrière est une pose que la 2D ne savait pas dire.
func _delta_pose(nom: String) -> Vector2:
	return _val_pose(pose, nom) + _val_pose(_pose_courante, nom) + _val_pose(_pose_marche, nom)


func _val_pose(d: Dictionary, nom: String) -> Vector2:
	if not d.has(nom):
		return Vector2.ZERO
	var v: Variant = d[nom]
	if v is Array:
		var t: Array = v
		return Vector2(float(t[0]), float(t[1]) if t.size() > 1 else 0.0)
	return Vector2(float(v), 0.0)


## Une unité de profondeur, projetée à l'écran : l'isométrie du monde écrase la profondeur de moitié et la fait
## monter. C'est la seule chose qui distingue le pantin d'un dessin plat.
func _projeter(v: Vector3) -> Vector2:
	return Vector2(v.x + v.z * _prof_ecran.x, v.y + v.z * _prof_ecran.y)


func _tourner(v: Vector3, c: float, sn: float) -> Vector3:
	return Vector3(v.x * c - v.z * sn, v.y, v.x * sn + v.z * c)


## La pose enregistrée par le joueur pour l'action en cours (designer 2026-09-01, point 63) :
## un dictionnaire segment → angle, appliqué par-dessus le rig. Sans pose, le rig parle seul.
## LA MARCHE (designer 2026-09-08) : le client donne l'avancement du pas, les jambes et les bras oscillent. Ce n'est
## pas une pose figée mais une amplitude — un aller-retour complet par tuile franchie, pris dans `poses.marche`.
func marcher(av: float) -> void:
	var a := -1.0 if av < 0.0 else clampf(av, 0.0, 1.0)
	if is_equal_approx(a, avancement):
		return
	avancement = a
	_pose_marche = {}
	if a >= 0.0:
		var m: Dictionary = GameData.config("poses").get("marche", {})
		var phase := sin(a * TAU)
		for seg: String in m.keys():
			if seg != "_doc":
				_pose_marche[seg] = float(m[seg]) * phase
	queue_redraw()


## La pose de l'action en cours. Une fiche peut porter les siennes (`poses`, point 63) ; sinon celles de
## `poses.defauts`, pour que TOUT être ait une pose par état — sans elles, `poses` vide ne posait rien (2026-09-08).
func _pose_action() -> Dictionary:
	var poses: Dictionary = e.get("poses", {})
	if poses.is_empty():
		poses = GameData.config("poses").get("defauts", {})
	if poses.is_empty():
		return {}
	var act := "repos"
	if not bool(e.get("vivant", true)):
		act = "mort"
	elif bool(e.get("dort", false)):
		act = "sommeil"
	elif bool(e.get("garde", false)):
		act = "garde"
	elif not pose.is_empty():
		act = "attaque"
	return poses.get(act, poses.get("repos", {}))


func _placer(nom: String, origine3: Vector3, herite: Vector2) -> Dictionary:
	var s: Dictionary = rig.segments[nom]
	# `herite` : la somme des rotations de pose des PARENTS, dans le plan ET en profondeur. L'origine d'un segment
	# suivait déjà son parent, mais pas sa direction : tourner un bras laissait l'avant-bras pointer dans son
	# ancienne direction, et la chaîne se cassait au coude. Un pantin se manipule d'un bloc (point 68).
	var dp := _delta_pose(nom)
	var a := deg_to_rad(float(s.angle) + dp.x + herite.x)
	var p := deg_to_rad(float(s.get("profondeur", 0.0)) + dp.y + herite.y)
	# La direction dans le plan du corps, puis sa sortie du plan : une rotation autour de `perp`, qui ne bouge pas.
	# `profondeur` positive envoie le segment vers l'AVANT, donc vers les z négatifs.
	var perp3 := Vector3(-sin(a), cos(a), 0.0)
	var dir3 := Vector3(cos(a) * cos(p), sin(a) * cos(p), -sin(p))
	# Le lacet du corps : une rotation autour de la verticale de l'écran, qui mélange la droite et la profondeur.
	var c := cos(_lacet)
	var sn := sin(_lacet)
	dir3 = _tourner(dir3, c, sn)
	perp3 = _tourner(perp3, c, sn)
	var norm3 := dir3.cross(perp3)
	var lg := float(s.largeur)
	var ep := float(s.get("epaisseur", lg * _epaisseur_defaut))
	if not nom.begins_with("tete"):
		lg *= _carrure
		ep *= _carrure
	# À l'écran, la direction se raccourcit d'elle-même quand le segment plonge vers nous : c'est la profondeur qui
	# se voit. La mesure DE TRAVERS, elle, vient de ce qu'un segment est un CYLINDRE et non un ruban : `largeur`
	# d'un côté à l'autre, `epaisseur` de l'avant à l'arrière. Sa silhouette est la projection de cette ellipse sur
	# la perpendiculaire de l'écran — un torse de profil fait son épaisseur, pas une fraction arbitraire de sa
	# largeur. L'axe de largeur, lui, reste face à la caméra : sinon un bras vu de tranche deviendrait un trait.
	var d2 := _projeter(dir3)
	var u := d2.normalized() if d2.length() > 0.0001 else Vector2.RIGHT
	var perp2 := Vector2(-u.y, u.x)
	var e_lg := lg * _projeter(perp3).dot(perp2)
	var e_ep := ep * _projeter(norm3).dot(perp2)
	var lg_vue := maxf(sqrt(e_lg * e_lg + e_ep * e_ep), lg * _largeur_min)
	return {"origine": _projeter(origine3), "direction": d2, "perp": perp2,
		"longueur": float(s.longueur), "largeur": lg_vue,
		"origine3": origine3, "dir3": dir3, "perp3": perp3, "norm3": norm3,
		"z": origine3.z + dir3.z * float(s.longueur) * 0.5}


## Quels segments l'équipement peint, et de quelle couleur (slot → segments du rig).
func _segments_peints() -> Dictionary:
	var res := {}
	for slot: String in e.get("equipement", {}).keys():
		var it: Dictionary = items.get(e.equipement[slot], {})
		if it.get("type", "") != "armure":
			continue
		var couleur := _couleur_materiau(it.get("materiau", ""))
		for seg in rig.slots_segments.get(slot, []):
			res[seg] = {"couleur": couleur, "construction": it.get("construction", "")}
	return res


func _couleur_materiau(materiau: String) -> Color:
	var m: Dictionary = palette.get(materiau, {})
	return Color.html(m.hex) if m.has("hex") else Color(0.6, 0.6, 0.6)


func _dessine_segment(m: Dictionary, col: Color, contour: float, nom: String) -> void:
	var o: Vector2 = m.origine
	var d: Vector2 = m.direction
	var p: Vector2 = m.perp
	var w: float = m.largeur * 0.5
	var l: float = m.longueur
	var poly := PackedVector2Array([o - p * w, o + p * w, o + d * l + p * w, o + d * l - p * w])
	if nom.begins_with("tete"):
		var fact: Dictionary = GameData.config("apparence").get("facteurs", {}).get("tete", {})
		var r := l * 0.5 * float(fact.get(str(_ap.get("tete", "ronde")), 1.0)) * float(_ap.get("curseurs", {}).get("largeur_visage", 1.0))
		var c := o + d * l * 0.5
		var peau := col if _ap.is_empty() else _teinte_de("teintes_peau", str(_ap.get("teinte_peau", "")), col)
		if not _planche_visage("tete", c, r, d, p, _teinte_partie("tete", peau), str(_ap.get("tete", "ronde"))):   # la forme de la tête par planche, sinon le disque
			draw_circle(c, r, peau)
			if contour > 0.0:
				draw_arc(c, r, 0.0, TAU, 16, peau.darkened(0.45), contour)
		if not _ap.is_empty():
			_dessine_visage(c, r, d, p, peau)
		return
	if _planche_membre(nom, m, col):   # le membre par sa planche (assets/membres/<segment>/), sinon le polygone
		return
	draw_colored_polygon(poly, col)
	draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), col.darkened(0.45), maxf(0.7, contour))


## Un membre par sa planche (designer 2026-09-06, 20 h 50 : « pour chaque membre et item ; s'il n'y a pas de sprite, fallback
## dessiné par code ») : le dossier `assets/membres/<segment sans côté>/` ; la case est CARRÉE et fait la LONGUEUR du segment,
## centrée sur son axe — le dessin part du bas de la case (l'origine du segment) vers le haut (son bout) ; le côté gauche
## est le miroir du droit ; la variante suit la carrure ; la case prend la couleur du segment (la peau, ou la matière qui le
## couvre — les planches se dessinent en blanc-gris pour cela).
func _planche_membre(nom: String, m: Dictionary, col: Color) -> bool:
	var base := nom.trim_suffix("_G").trim_suffix("_D")
	var dossier := "membres/" + base
	if Planches.variantes(dossier) <= 0:
		return false
	var l: float = m.longueur
	var d: Vector2 = m.direction
	var p: Vector2 = m.perp
	var o: Vector2 = m.origine
	# La case est carrée et CENTRÉE sur le segment ; son côté est la plus grande des deux mesures (2026-09-08) :
	# la longueur suffisait tant qu'un membre était plus long que large, mais le bassin est plus LARGE que long —
	# sa planche sortait écrasée dans une case de sa longueur. Pour un membre long, `cote == l` : rien ne change.
	var cote := maxf(l, float(m.largeur))
	var k := cote / float(Planches.case())
	var miroir := nom.ends_with("_G")   # le côté gauche : la case retournée, par son repère (l'axe x inversé)
	var local := Transform2D(-p * k if miroir else p * k, -d * k, o + d * (l * 0.5 + cote * 0.5) + p * (cote * 0.5) * (1.0 if miroir else -1.0))   # (0,0) de la case : en haut à gauche
	draw_set_transform_matrix(Transform2D(0.0, _decalage) * Transform2D().scaled(Vector2(_echelle_dessin, _echelle_dessin)) * local)
	var variante := maxi(0, Planches.index_locus("carrure", str(_ap.get("carrure", "moyenne"))))
	var c := float(Planches.case())
	Planches.dessiner(self, dossier, variante, Rect2(0, 0, c, c), col)
	draw_set_transform(_decalage, 0.0, Vector2(_echelle_dessin, _echelle_dessin))
	return true


## Un trait du visage par sa planche (`assets/visage/<trait>/`) : la case est la tête entière — un carré de
## `planches.visage_boite` × le rayon de la tête, centré sur elle, le haut de la case vers le haut de la tête — et le trait y
## est dessiné à sa place ; la variante est l'index de la valeur du locus (l'ordre de apparence.json). Faux sans planche.
func _planche_visage(trait_id: String, c: Vector2, r: float, d: Vector2, p: Vector2, teinte: Color, valeur: String) -> bool:
	if _vue_tete == "dos" and trait_id != "cheveux":
		return false
	var dossier := "visage/" + trait_id
	if Planches.variantes(dossier) <= 0:
		return false
	var cote := r * float(GameData.config("styles").get("planches", {}).get("visage_boite", 2.6))
	var k := cote / float(Planches.case())
	var local := Transform2D(p * k, -d * k, c - p * (cote * 0.5) + d * (cote * 0.5))
	draw_set_transform_matrix(Transform2D(0.0, _decalage) * Transform2D().scaled(Vector2(_echelle_dessin, _echelle_dessin)) * local)
	var cc := float(Planches.case())
	var idx := maxi(0, Planches.index_locus(trait_id, valeur))
	for decalage in _places_trait(trait_id, dossier, idx):
		Planches.dessiner(self, dossier, idx, Rect2(decalage, Vector2(cc, cc)), teinte)
	draw_set_transform(_decalage, 0.0, Vector2(_echelle_dessin, _echelle_dessin))
	return true


## OÙ POSER UN TRAIT, ET COMBIEN DE FOIS (designer 2026-09-09 : « avoir sur chaque forme de visage des marqueurs pour
## les autres éléments… une couleur par élément… le sprite de l'élément correspondant est centré sur le pixel »).
##
## **Trois règles, et elles se lisent d'un trait :**
## · **Les ancres d'un élément** sont les marqueurs que la case de TÊTE porte pour lui ; à défaut, les ancres par
##   défaut des données — là où le visage les a toujours portés.
## · Une case de trait qui porte **son propre marqueur** est une **pièce** : dessinée UNE FOIS PAR ANCRE, calée pour
##   que son marqueur tombe dessus. C'est ainsi qu'un seul œil dessiné sert aux deux yeux.
## · Une case sans marqueur est un **visage entier**, comme avant : dessinée une fois, translatée du déplacement
##   MOYEN des ancres. Une tête sans marqueurs ne translate rien — le comportement d'avant, à l'octet près.
##
## Rend la liste des décalages, en pixels de case.
func _places_trait(trait_id: String, dossier: String, idx: int) -> Array:
	if trait_id == "tete":
		return [Vector2.ZERO]   # la tête EST la case : rien à ancrer sur elle-même
	var defaut: Array = Planches.ancres_defaut(trait_id)
	var idx_tete := maxi(0, Planches.index_locus("tete", str(_ap.get("tete", "ronde"))))
	var ancres: Array = Planches.marqueurs("visage/tete", idx_tete).get(trait_id, [])
	if ancres.is_empty():
		ancres = defaut
	if ancres.is_empty():
		return [Vector2.ZERO]
	var siens: Array = Planches.marqueurs(dossier, idx).get(trait_id, [])
	if not siens.is_empty():
		var propre: Vector2 = siens[0]   # une pièce n'a qu'un point d'attache : le premier suffit
		var res: Array = []
		for a in ancres:
			res.append(a - propre)
		return res
	# Un visage entier : on le déplace du mouvement moyen des ancres, et de rien du tout si la tête est muette.
	if defaut.is_empty() or defaut.size() != ancres.size():
		return [Vector2.ZERO]
	var somme := Vector2.ZERO
	for i in ancres.size():
		somme += (ancres[i] as Vector2) - (defaut[i] as Vector2)
	return [somme / float(ancres.size())]


func _angle_arme() -> float:
	return float(GameData.config("styles").get("sprites", {}).get("arme_angle_deg", 45.0))


## L'arme à l'ancrage `prise` de la main d'arme, le bouclier à celle de l'autre main.
func _dessine_tenus(monde: Dictionary) -> void:
	var equip: Dictionary = e.get("equipement", {})
	var main_arme: Variant = rig.get("prise_arme")
	var main_bouclier_c: Variant = rig.get("prise_bouclier")
	# CE QU'IL TIENT RESTE DU MÊME CÔTÉ (designer 2026-09-08 : « toujours garder l'item de la main droite à droite et
	# l'item de la main gauche à gauche »). Retourner le rig échange les deux mains à l'écran ; l'arme sautait donc
	# d'un côté à l'autre à chaque demi-tour. On la dessine sur la main la plus à DROITE, quelle qu'elle soit, et
	# l'objet secondaire sur l'autre : le joueur voit son épée toujours du même côté, et le corps, lui, se retourne.
	if main_arme is String and main_bouclier_c is String and monde.has(main_arme) and monde.has(main_bouclier_c):
		if float((monde[main_bouclier_c] as Dictionary).origine.x) > float((monde[main_arme] as Dictionary).origine.x):
			var echange: Variant = main_arme
			main_arme = main_bouclier_c
			main_bouclier_c = echange
	if main_arme is String and monde.has(main_arme) and equip.has("main_principale"):
		var it: Dictionary = items.get(equip.main_principale, {})
		var fonct: Dictionary = fonctionnalites.get(it.get("functionality", ""), {})
		var m: Dictionary = monde[main_arme]
		var prise: Array = rig.segments[main_arme].ancrages.get("prise", [0, 0])
		var pt: Vector2 = m.origine + m.direction * float(prise[0]) + m.perp * float(prise[1])
		# L'arme suit la MAIN, pas la verticale de l'écran : elle était dessinée vers le haut absolu, si
		# bien qu'articuler le bras la laissait droite dans le vide, détachée du poing (point 68).
		# LA MAIN PRÉSENTE L'ARME VERS L'EXTÉRIEUR (designer 2026-09-08) : elle la tenait dans l'axe du bras, donc
		# droite le long du corps. Inclinée de `arme_angle_deg`, la droite part à droite et la gauche à gauche —
		# le signe vient de la position de la main par rapport à l'axe du corps, pas du nom du segment, pour que
		# le retournement du paperdoll n'inverse rien.
		var haut: Vector2 = (-Vector2(m.direction)).rotated(deg_to_rad(_angle_arme()) * (1.0 if pt.x >= 0.0 else -1.0))
		if not _dessine_arme_sprite(it, pt, haut):   # le montage pré-rendu de l'arme, s'il existe (Squelette modulaire, 2026-09-05)
			_dessine_tenu_picto(it, pt, haut)   # sinon le pictogramme de l'inventaire, dans la main (designer 2026-09-06)
	var main_bouclier: Variant = main_bouclier_c
	if main_bouclier is String and monde.has(main_bouclier) and equip.has("main_secondaire"):
		var it: Dictionary = items.get(equip.main_secondaire, {})
		var m: Dictionary = monde[main_bouclier]
		var prise: Array = rig.segments[main_bouclier].ancrages.get("prise", [0, 0])
		var pt: Vector2 = m.origine + m.direction * float(prise[0]) + m.perp * float(prise[1])
		var haut: Vector2 = (-Vector2(m.direction)).rotated(deg_to_rad(_angle_arme()) * (1.0 if pt.x >= 0.0 else -1.0))
		if not _dessine_arme_sprite(it, pt, haut):   # l'autre main : un bouclier, une torche, une dague — son montage ou son pictogramme
			_dessine_tenu_picto(it, pt, haut)


## Ce qu'on tient, sans montage pré-rendu : LE MÊME pictogramme que dans l'inventaire (`Pictos.dessiner_objet`, designer
## 2026-09-06 : « quand une arme est équipée, elle devrait avoir le même sprite que dans l'inventaire »), posé dans la main
## et tourné avec elle. Le pictogramme est dessiné dans une case de `picto_tenu_unites` unités de rig ; son point de prise
## et son axe (styles.sprites.pictos_tenus, par nom de pictogramme — la diagonale bas-gauche → haut-droite pour une lame)
## se posent sur la main et sur `haut`.
func _dessine_tenu_picto(it: Dictionary, pt: Vector2, haut: Vector2) -> void:
	if it.is_empty():
		return
	var st: Dictionary = GameData.config("styles").get("sprites", {})
	var cote := float(st.get("picto_tenu_unites", 14.0))
	var reglages: Dictionary = st.get("pictos_tenus", {})
	var nom := Pictos.nom_picto(it)
	var reg: Dictionary = reglages.get(nom, reglages.get("_defaut", {}))
	var axe_l: Array = reg.get("axe", [1.0, -1.0])
	var prise_l: Array = reg.get("prise", [2.5, 7.5])
	var axe := Vector2(float(axe_l[0]), float(axe_l[1])).normalized()
	var prise := Vector2(float(prise_l[0]), float(prise_l[1])) * (cote / 10.0)
	var local := Transform2D(haut.angle() - axe.angle(), Vector2.ZERO)
	local.origin = pt - local.basis_xform(prise)
	draw_set_transform_matrix(Transform2D(0.0, _decalage) * Transform2D().scaled(Vector2(_echelle_dessin, _echelle_dessin)) * local)
	Pictos.dessiner_objet(self, it, Rect2(Vector2.ZERO, Vector2(cote, cote)))
	draw_set_transform(_decalage, 0.0, Vector2(_echelle_dessin, _echelle_dessin))


## Le contrat de remplacement (Squelette modulaire et points d'attache, 2026-09-05) : l'arme tenue est LE MÊME montage
## que son icône d'inventaire (`Pictos.assembler`, le designer : « c'est le même sprite »), dessiné dans la main, tourné
## avec elle. Le repère du montage est en unités de rig, comme le paperdoll : son origine (le pied du manche) se pose à
## « prise » unités sous la main, son axe −Y sur `haut`. Faux si une pièce n'a pas de sprite : le trait par code reste.
func _dessine_arme_sprite(it: Dictionary, pt: Vector2, haut: Vector2) -> bool:
	var parts: Array = Pictos.assembler(it)
	if parts.is_empty():
		return false
	var manche: Dictionary = it.get("composants", {}).get("manche", {})
	var sp: Dictionary = GameData.catalogues.get("components", {}).get(str(manche.get("composant", "")), {}).get("sprite", {})
	var prise: Array = sp.get("ancrages", {}).get("prise", [0, 0])
	var base: Vector2 = pt - haut * float(prise[0])
	var local := Transform2D(haut.angle() + PI * 0.5, Vector2.ONE, 0.0, base)   # −Y du montage = haut
	draw_set_transform_matrix(Transform2D(0.0, _decalage) * Transform2D().scaled(Vector2(_echelle_dessin, _echelle_dessin)) * local)
	for p in parts:
		draw_texture_rect(p.tex, p.rect, false, p.teinte)
	draw_set_transform(_decalage, 0.0, Vector2(_echelle_dessin, _echelle_dessin))
	return true


## Une teinte nommée d'une palette de `apparence.json` (peau, cheveux) ; la couleur de repli si l'id est inconnu.
## Une couleur écrite en clair (« #rrggbb ») passe telle quelle (2026-09-08) : le gabarit `00_substitution.png` est
## blanc-gris et se laisse teindre, mais une planche DÉJÀ coloriée doit se dessiner sans être multipliée — sinon la
## peau du personnage repeint le sprite. Un visage peint se donne donc `"teinte_peau": "#ffffff"`.
func _teinte_de(palette_id: String, id: String, repli: Color) -> Color:
	if id.begins_with("#"):
		return Color.html(id)
	for t in GameData.config("apparence").get(palette_id, []):
		if str(t.id) == id:
			return Color(float(t.rgb[0]), float(t.rgb[1]), float(t.rgb[2]))
	return repli


## LA COULEUR PROPRE D'UNE PARTIE (designer 2026-09-09 : « sépare couleurs pour chaque parties »). Chaque trait peut
## porter la sienne, écrite en clair sous `couleur_<trait>` ; à défaut, il garde la teinte dont il héritait — la peau
## pour la tête et les oreilles, l'encre pour les yeux, le nez et la bouche, les cheveux pour la coiffe.
## **C'est une SURCHARGE, pas un remplacement** : un personnage qui n'en déclare aucune se dessine exactement comme
## avant, et les trois teintes de base (peau, cheveux, pilosité) restent ce qui habille tout le reste.
func _teinte_partie(trait_id: String, defaut: Color) -> Color:
	var v := str(_ap.get("couleur_" + trait_id, ""))
	return Color.html(v) if v.begins_with("#") else defaut


## Le visage dessiné sur le disque du crâne : yeux, nez, bouche, cheveux, oreilles, barbe.
## Tout vient des loci de l'être (Apparence — données et équipement) — jamais de sa race.
func _dessine_visage(c: Vector2, r: float, d: Vector2, p: Vector2, peau: Color) -> void:
	var cheveux := _teinte_de("teintes_cheveux", str(_ap.get("teinte_cheveux", "")), peau.darkened(0.6))
	# L'encre des traits (yeux, nez, bouche, mâchoire…) : la peau assombrie, sauf si l'être la déclare —
	# une planche coloriée veut du blanc, pas de l'encre (2026-09-08).
	var encre := _teinte_de("teintes_peau", str(_ap.get("teinte_encre", "")), peau.darkened(0.55))
	var o_brut: Variant = _ap.get("oreilles", 0.0)   # une valeur de locus, ou l'ancienne longueur chiffrée
	var oreille := float(GameData.config("apparence").get("facteurs", {}).get("oreilles", {}).get(str(o_brut), 0.0)) if o_brut is String else float(o_brut)
	var pv := func(trait_id: String, teinte_t: Color) -> bool: return _planche_visage(trait_id, c, r, d, p, _teinte_partie(trait_id, teinte_t), str(_ap.get(trait_id, "")))
	if pv.call("oreilles", peau):
		pass
	elif oreille > 0.0 and _vue_tete != "dos":   # les oreilles pointent vers le haut et vers l'extérieur
		for cote in [-1.0, 1.0]:
			var base: Vector2 = c + p * (r * 0.9 * cote)
			draw_colored_polygon(PackedVector2Array([
				base - d * r * 0.2, base + d * r * 0.2,
				base + p * (oreille * cote) + d * (oreille * 0.6),
			]), peau)
	var coif := str(_ap.get("cheveux", "courts"))
	if pv.call("cheveux", cheveux):
		pass
	elif coif == "crete":   # une crête dressée : pas de calotte, une bande sur le sommet
		draw_line(c + d * r * 0.9, c + d * r * 1.5, cheveux, maxf(1.5, r * 0.4))
	elif coif != "chauve":   # la calotte, vue de face comme de dos
		var ang := d.angle()   # la calotte suit le haut du crâne, quelle que soit l'inclinaison de la tête
		draw_arc(c, r * 0.94, ang - PI * 0.44, ang + PI * 0.44, 18, cheveux, maxf(1.5, r * 0.34))
		if coif == "longs":
			for cote2 in [-1.0, 1.0]:
				draw_line(c + p * (r * 0.85 * cote2), c + p * (r * 0.85 * cote2) - d * r * 1.5, cheveux, maxf(1.2, r * 0.3))
		elif coif == "queue":
			draw_line(c - d * r * 0.6, c - d * r * 1.8, cheveux, maxf(1.2, r * 0.25))
		elif coif == "chignon":
			draw_circle(c - d * r * 1.05, maxf(1.5, r * 0.42), cheveux)
		elif coif == "tresses":
			for cote6 in [-1.0, 1.0]:
				var haut6: Vector2 = c + p * (r * 0.8 * cote6) + d * r * 0.2
				draw_line(haut6, haut6 - d * r * 1.6 + p * (r * 0.3 * cote6), cheveux, maxf(1.2, r * 0.22))
	if _vue_tete == "dos":
		return
	var cur: Dictionary = _ap.get("curseurs", {})   # les réglages continus (point 53)
	var f_ecart := float(cur.get("ecart_yeux", 1.0))
	var f_haut := float(cur.get("hauteur_yeux", 0.0))
	var f_nez := float(cur.get("longueur_nez", 1.0))
	var f_bouche := float(cur.get("largeur_bouche", 1.0))
	var ecart := (0.42 if _vue_tete == "face" else 0.18) * f_ecart
	match ("planche" if pv.call("yeux", encre) else str(_ap.get("yeux", "points"))):
		"planche":
			pass
		"grands":
			for cote3 in [-1.0, 1.0]:
				draw_circle(c + p * (r * ecart * cote3) + d * r * (0.15 + f_haut), maxf(0.8, r * 0.2), encre)
		"en_amande":
			for cote7 in [-1.0, 1.0]:
				var o7: Vector2 = c + p * (r * ecart * cote7) + d * r * (0.15 + f_haut)
				draw_arc(o7, r * 0.2, 0.0, TAU, 10, encre, maxf(0.7, r * 0.09))
		"tombants":
			for cote8 in [-1.0, 1.0]:
				var o8: Vector2 = c + p * (r * ecart * cote8) + d * r * (0.18 + f_haut)
				draw_line(o8 - p * r * 0.14, o8 + p * r * 0.14 - d * r * 0.12, encre, maxf(0.8, r * 0.1))
		"fentes":
			for cote4 in [-1.0, 1.0]:
				var o4: Vector2 = c + p * (r * ecart * cote4) + d * r * (0.15 + f_haut)
				draw_line(o4 - p * r * 0.16, o4 + p * r * 0.16, encre, maxf(0.8, r * 0.1))
		_:
			for cote5 in [-1.0, 1.0]:
				draw_circle(c + p * (r * ecart * cote5) + d * r * (0.15 + f_haut), maxf(0.6, r * 0.12), encre)
	var nez := str(_ap.get("nez", "droit"))
	var haut_nez: Vector2 = c + d * r * 0.05
	if pv.call("nez", encre):
		pass
	elif nez == "fin":
		draw_line(haut_nez, haut_nez - d * r * 0.3 * f_nez, encre, maxf(0.5, r * 0.05))
	elif nez == "busque":
		draw_line(haut_nez + d * r * 0.1, haut_nez - d * r * 0.15 + p * r * 0.08, encre, maxf(0.7, r * 0.1))
		draw_line(haut_nez - d * r * 0.15 + p * r * 0.08, haut_nez - d * r * 0.4, encre, maxf(0.7, r * 0.1))
	elif nez == "crochu":
		draw_line(haut_nez, haut_nez - d * r * 0.35 * f_nez + p * r * 0.12, encre, maxf(0.7, r * 0.09))
	elif nez == "plat":
		draw_line(haut_nez - p * r * 0.1, haut_nez + p * r * 0.1, encre, maxf(0.7, r * 0.09))
	else:
		draw_line(haut_nez, haut_nez - d * r * 0.35 * f_nez, encre, maxf(0.7, r * 0.09))
	var bouche := str(_ap.get("bouche", "fine"))
	var y_bouche: Vector2 = c - d * r * 0.5
	var demi := r * (0.3 if bouche == "large" else 0.18) * f_bouche
	if pv.call("bouche", encre):
		pass
	elif bouche == "boudeuse":
		draw_arc(y_bouche - d * r * 0.24, r * 0.3, PI * 0.2, PI * 0.8, 10, encre, maxf(0.7, r * 0.09))
	elif bouche == "sourire":
		draw_arc(y_bouche + d * r * 0.2, r * 0.32, PI * 1.15, PI * 1.85, 10, encre, maxf(0.7, r * 0.09))
	else:
		draw_line(y_bouche - p * demi, y_bouche + p * demi, encre, maxf(0.7, r * 0.09))
	# LA PILOSITÉ (2026-09-08, designer : « tete, yeux, bouche, cheveux, pilosité, oreilles, nez ») : ce qui reste du
	# visage. Sourcils, marque, mâchoire, menton, pommettes, implantation et paupières ont été retirés — un trait qui
	# n'est pas dessiné n'a pas à être réglable. La pilosité a sa propre couleur, qui retombe sur celle des cheveux.
	var poils := _teinte_de("teintes_cheveux", str(_ap.get("teinte_pilosite", "")), cheveux)
	var p_brut: Variant = _ap.get("pilosite", 0.0)
	var pilosite := float(GameData.config("apparence").get("facteurs", {}).get("pilosite", {}).get(str(p_brut), 0.0)) if p_brut is String else float(p_brut)
	if pv.call("pilosite", poils):
		pass
	elif pilosite > 0.0:
		draw_colored_polygon(PackedVector2Array([
			c - p * r * 0.8 - d * r * 0.1, c + p * r * 0.8 - d * r * 0.1,
			c + p * r * 0.35 - d * (r + pilosite), c - p * r * 0.35 - d * (r + pilosite),
		]), poils)


## Le segment sous un point, en coordonnées locales du nœud (designer 2026-09-01, point 68) : l'écran de
## pose y clique pour saisir un membre. On rend le segment dont le corps — pas l'ancrage — est le plus
## proche ; au-delà de `marge` pixels, rien n'est saisi.
func segment_sous(p: Vector2, marge: float = 10.0) -> String:
	if _monde_dessine.is_empty():
		return ""
	var q: Vector2 = p / maxf(0.01, _echelle_dessin)
	var meilleur := ""
	var d_min := 1e9
	for nom: String in _monde_dessine.keys():
		var m: Dictionary = _monde_dessine[nom]
		var a: Vector2 = m.origine
		var b: Vector2 = m.origine + m.direction * float(m.longueur)
		var ab: Vector2 = b - a
		var t := 0.0 if ab.length_squared() < 0.001 else clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d: float = q.distance_to(a + ab * t) - float(m.largeur) * 0.5
		if d < d_min:
			d_min = d
			meilleur = nom
	return meilleur if d_min <= marge else ""


## L'origine d'un segment (son joint) dans le repère du nœud — l'écran de pose y dessine la poignée.
func joint_de(nom: String) -> Vector2:
	if not _monde_dessine.has(nom):
		return Vector2.ZERO
	return (_monde_dessine[nom].origine as Vector2) * _echelle_dessin


## Le corps d'un segment : [joint, extrémité], dans le repère de dessin du nœud (avant l'échelle d'apparence).
func corps_de(nom: String) -> PackedVector2Array:
	if not _monde_dessine.has(nom):
		return PackedVector2Array()
	var m: Dictionary = _monde_dessine[nom]
	return PackedVector2Array([m.origine, (m.origine as Vector2) + (m.direction as Vector2) * float(m.longueur)])
