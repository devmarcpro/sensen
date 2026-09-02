class_name Paperdoll
extends Node2D
## Le rendu d'un être — creature.tscn, la seule scène pour tout être vivant (Décisions
## d'architecture). Tout vient des données : la silhouette du rig (`data/rigs/`), les pièces
## d'équipement aux ancrages (Squelette modulaire et points d'attache), la teinte du matériau
## (Palette de couleurs des matériaux). Aucune branche par type d'être (Apparence — données).
## Les sprites n'existent pas encore : chaque segment est un rectangle procédural accroché à
## son ancrage — le rig, l'ordre de calque, les décalages et le miroir sont déjà les vrais.

## Orientation de grille → facing d'écran (géométrie de la vue, pas du gameplay).
## Épaisseur de contour par construction — « la construction est la forme, le matériau la teinte ».
const CONTOURS := {"matelasse": 0.6, "cuir": 1.0, "mailles": 1.4, "ecailles": 1.6, "plaque": 2.2}

var e: Dictionary = {}          # l'être (état de la simulation)
var rig: Dictionary = {}
var items: Dictionary = {}
var fonctionnalites: Dictionary = {}
var palette: Dictionary = {}
var dessine_apres: Callable     # le client peut dessiner par-dessus (tuiles occultantes)
var pose: Dictionary = {}       # segment → delta d'angle (animation par pivots)
var _anim_restant := 0.0
var _anim_duree := 0.25
var _ap: Dictionary = {}       # loci visuels de l'être (Apparence — données et équipement)
var _vue_tete := "face"
var _carrure := 1.0
var _pose_courante: Dictionary = {}   # la pose du joueur pour l'action en cours (point 63)
var _monde_dessine: Dictionary = {}   # dernier placement des segments — l'écran de pose y clique (point 68)
var _echelle_dessin := 1.0
var _peint: Dictionary = {}


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


func _process(delta: float) -> void:
	if _anim_restant > 0.0:
		_anim_restant -= delta
		if _anim_restant <= 0.0:
			pose = {}
		queue_redraw()


# ---------------------------------------------------------------- rendu

func _draw() -> void:
	if e.is_empty() or rig.is_empty():
		return
	# Une seule vue : de face (designer 2026-09-01, point 54). L'orientation de l'être continue de
	# décider la garde, les zones de coup et le champ de vision — elle ne décide plus le dessin.
	var f: Dictionary = rig.facings.get("S", {})
	var miroir := false
	if f.has("miroir"):
		miroir = true
		f = rig.facings[f.miroir]
	_ap = e.get("apparence", {})
	_pose_courante = _pose_action()
	_vue_tete = str(f.get("vue_tete", "face"))
	var fac: Dictionary = GameData.config("apparence").get("facteurs", {})
	_carrure = float(fac.get("carrure", {}).get(str(_ap.get("carrure", "moyenne")), 1.0))
	var ech := float(_ap.get("echelle", 1.0)) * float(fac.get("taille", {}).get(str(_ap.get("taille", "moyenne")), 1.0))
	if not is_equal_approx(ech, 1.0):
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(ech, ech))
	var monde := _poser_segments(f, miroir)
	_monde_dessine = monde
	_echelle_dessin = ech
	_peint = _segments_peints()
	var peint: Dictionary = _peint
	var teinte := Color(e.teinte[0], e.teinte[1], e.teinte[2])
	if not _ap.is_empty():   # nu : la peau peint le corps entier, l'équipement seul le recouvre (point 43)
		teinte = _teinte_de("teintes_peau", str(_ap.get("teinte_peau", "")), teinte)
	for nom: String in f.ordre:
		if not monde.has(nom):
			continue
		var m: Dictionary = monde[nom]
		var col := teinte
		var contour := 0.0
		if peint.has(nom):
			col = peint[nom].couleur
			contour = float(CONTOURS.get(peint[nom].construction, 1.0))
		_dessine_segment(m, col, contour, nom)
	_dessine_tenus(monde)
	if dessine_apres.is_valid():
		dessine_apres.call(self)


## Place chaque segment dans le repère du nœud : {origine, direction, perp, longueur, largeur}.
func _poser_segments(f: Dictionary, miroir: bool) -> Dictionary:
	var monde := {}
	var racine: String = rig.racine
	var offsets: Dictionary = f.get("offsets", {})
	var restants: Array = rig.segments.keys()
	var herite := {racine: _delta_pose(racine)}   # ce que chaque segment transmet à ses enfants
	monde[racine] = _placer(racine, Vector2(0, -float(rig.hauteur_pieds)), miroir)
	restants.erase(racine)
	var garde_fou := 64
	while not restants.is_empty() and garde_fou > 0:
		garde_fou -= 1
		for nom in restants.duplicate():
			var s: Dictionary = rig.segments[nom]
			if not monde.has(s.parent):
				continue
			var p: Dictionary = monde[s.parent]
			var a: Array = rig.segments[s.parent].ancrages.get(s.ancrage, [0, 0])
			var off: Array = offsets.get(s.ancrage, [0, 0])
			var along := float(a[0]) + float(off[0])
			var across := float(a[1]) + float(off[1])
			var pt: Vector2 = p.origine + p.direction * along + p.perp * across
			var h: float = float(herite.get(str(s.parent), 0.0))
			monde[nom] = _placer(nom, pt, miroir, h)
			herite[nom] = h + _delta_pose(nom)
			restants.erase(nom)
	return monde


## Ce qu'un segment ajoute à l'angle de ses enfants : sa propre rotation de pose, rien d'autre —
## l'angle de repos du rig est déjà absolu et ne doit pas se propager deux fois.
func _delta_pose(nom: String) -> float:
	return float(pose.get(nom, 0.0)) + float(_pose_courante.get(nom, 0.0))


## La pose enregistrée par le joueur pour l'action en cours (designer 2026-09-01, point 63) :
## un dictionnaire segment → angle, appliqué par-dessus le rig. Sans pose, le rig parle seul.
func _pose_action() -> Dictionary:
	var poses: Dictionary = e.get("poses", {})
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


func _placer(nom: String, origine: Vector2, miroir: bool, herite: float = 0.0) -> Dictionary:
	var s: Dictionary = rig.segments[nom]
	# `herite` : la somme des rotations de pose des PARENTS. L'origine d'un segment suivait déjà son
	# parent, mais pas sa direction : tourner un bras laissait l'avant-bras pointer dans son ancienne
	# direction, et la chaîne se cassait au coude. Un pantin se manipule d'un bloc (point 68).
	var angle := float(s.angle) + float(pose.get(nom, 0.0)) + float(_pose_courante.get(nom, 0.0)) + herite
	if miroir:
		angle = 180.0 - angle
	var d := Vector2.from_angle(deg_to_rad(angle))
	var perp := Vector2(-d.y, d.x) * (-1.0 if miroir else 1.0)
	var lg := float(s.largeur)
	if not nom.begins_with("tete"):
		lg *= _carrure
	return {"origine": origine, "direction": d, "perp": perp, "longueur": float(s.longueur), "largeur": lg}


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
		draw_circle(c, r, peau)
		if contour > 0.0:
			draw_arc(c, r, 0.0, TAU, 16, peau.darkened(0.45), contour)
		if not _ap.is_empty():
			_dessine_visage(c, r, d, p, peau)
		return
	draw_colored_polygon(poly, col)
	draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), col.darkened(0.45), maxf(0.7, contour))


## L'arme à l'ancrage `prise` de la main d'arme, le bouclier à celle de l'autre main.
func _dessine_tenus(monde: Dictionary) -> void:
	var equip: Dictionary = e.get("equipement", {})
	var main_arme: Variant = rig.get("prise_arme")
	if main_arme is String and monde.has(main_arme) and equip.has("main_principale"):
		var it: Dictionary = items.get(equip.main_principale, {})
		var fonct: Dictionary = fonctionnalites.get(it.get("functionality", ""), {})
		var m: Dictionary = monde[main_arme]
		var prise: Array = rig.segments[main_arme].ancrages.get("prise", [0, 0])
		var pt: Vector2 = m.origine + m.direction * float(prise[0]) + m.perp * float(prise[1])
		var col := _couleur_materiau(it.get("materiau", ""))
		# L'arme suit la MAIN, pas la verticale de l'écran : elle était dessinée vers le haut absolu, si
		# bien qu'articuler le bras la laissait droite dans le vide, détachée du poing (point 68).
		var haut: Vector2 = -Vector2(m.direction)
		var bas: Vector2 = Vector2(m.direction)
		match str(fonct.get("combat_skill", "")):
			"dague": draw_line(pt, pt + haut * 6, col, 1.5)
			"epee": draw_line(pt, pt + haut * 12, col, 1.8)
			"masse":
				draw_line(pt, pt + haut * 8, col.darkened(0.3), 1.5)
				draw_circle(pt + haut * 9, 2.5, col)
			"lance": draw_line(pt + bas * 6, pt + haut * 16, col, 1.5)
			"arc": draw_arc(pt + Vector2(m.perp) * 2.0 + haut * 4.0, 7.0, -PI * 0.6, PI * 0.6, 10, col, 1.5)
			"baton_magique": draw_line(pt + bas * 6, pt + haut * 14, col, 1.8)
			_: draw_line(pt, pt + haut * 8, col, 1.5)
	var main_bouclier: Variant = rig.get("prise_bouclier")
	if main_bouclier is String and monde.has(main_bouclier) and equip.has("main_secondaire"):
		var it: Dictionary = items.get(equip.main_secondaire, {})
		var m: Dictionary = monde[main_bouclier]
		var prise: Array = rig.segments[main_bouclier].ancrages.get("prise", [0, 0])
		var pt: Vector2 = m.origine + m.direction * float(prise[0]) + m.perp * float(prise[1])
		draw_circle(pt, 5.0, _couleur_materiau(it.get("materiau", "")))
		draw_arc(pt, 5.0, 0.0, TAU, 12, Color(0.2, 0.15, 0.1), 1.2)


## Une teinte nommée d'une palette de `apparence.json` (peau, cheveux) ; la couleur de repli si l'id est inconnu.
func _teinte_de(palette_id: String, id: String, repli: Color) -> Color:
	for t in GameData.config("apparence").get(palette_id, []):
		if str(t.id) == id:
			return Color(float(t.rgb[0]), float(t.rgb[1]), float(t.rgb[2]))
	return repli


## Le visage dessiné sur le disque du crâne : yeux, nez, bouche, cheveux, oreilles, barbe.
## Tout vient des loci de l'être (Apparence — données et équipement) — jamais de sa race.
func _dessine_visage(c: Vector2, r: float, d: Vector2, p: Vector2, peau: Color) -> void:
	var cheveux := _teinte_de("teintes_cheveux", str(_ap.get("teinte_cheveux", "")), peau.darkened(0.6))
	var encre := peau.darkened(0.55)
	var o_brut: Variant = _ap.get("oreilles", 0.0)   # une valeur de locus, ou l'ancienne longueur chiffrée
	var oreille := float(GameData.config("apparence").get("facteurs", {}).get("oreilles", {}).get(str(o_brut), 0.0)) if o_brut is String else float(o_brut)
	if oreille > 0.0 and _vue_tete != "dos":   # les oreilles pointent vers le haut et vers l'extérieur
		for cote in [-1.0, 1.0]:
			var base: Vector2 = c + p * (r * 0.9 * cote)
			draw_colored_polygon(PackedVector2Array([
				base - d * r * 0.2, base + d * r * 0.2,
				base + p * (oreille * cote) + d * (oreille * 0.6),
			]), peau)
	var coif := str(_ap.get("cheveux", "courts"))
	if coif == "crete":   # une crête dressée : pas de calotte, une bande sur le sommet
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
	match str(_ap.get("yeux", "points")):
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
	if nez == "fin":
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
	if bouche == "boudeuse":
		draw_arc(y_bouche - d * r * 0.24, r * 0.3, PI * 0.2, PI * 0.8, 10, encre, maxf(0.7, r * 0.09))
	elif bouche == "sourire":
		draw_arc(y_bouche + d * r * 0.2, r * 0.32, PI * 1.15, PI * 1.85, 10, encre, maxf(0.7, r * 0.09))
	else:
		draw_line(y_bouche - p * demi, y_bouche + p * demi, encre, maxf(0.7, r * 0.09))
	var b_brut: Variant = _ap.get("barbe", 0.0)
	var barbe := float(GameData.config("apparence").get("facteurs", {}).get("barbe", {}).get(str(b_brut), 0.0)) if b_brut is String else float(b_brut)
	if barbe > 0.0:
		draw_colored_polygon(PackedVector2Array([
			c - p * r * 0.8 - d * r * 0.1, c + p * r * 0.8 - d * r * 0.1,
			c + p * r * 0.35 - d * (r + barbe), c - p * r * 0.35 - d * (r + barbe),
		]), cheveux)
	var sourcils := str(_ap.get("sourcils", "fins"))
	if sourcils != "aucun":
		for cote9 in [-1.0, 1.0]:
			var o9: Vector2 = c + p * (r * ecart * cote9) + d * r * 0.42
			draw_line(o9 - p * r * 0.16, o9 + p * r * 0.16, cheveux, maxf(0.8, r * (0.16 if sourcils == "epais" else 0.08)))
	if str(_ap.get("machoire", "")) != "":   # la mâchoire : un trait sous les pommettes, plus ou moins large
		var lg_m: float = float({"fine": 0.42, "carree": 0.66, "lourde": 0.80}.get(str(_ap.machoire), 0.55))
		draw_line(c - p * r * lg_m - d * r * 0.55, c + p * r * lg_m - d * r * 0.55, encre.lightened(0.1), maxf(0.6, r * 0.07))
	match str(_ap.get("menton", "")):
		"pointu":
			draw_colored_polygon(PackedVector2Array([c - p * r * 0.2 - d * r * 0.8, c + p * r * 0.2 - d * r * 0.8, c - d * r * 1.1]), peau.darkened(0.05))
		"fendu":
			draw_line(c - d * r * 0.78, c - d * r * 0.95, encre, maxf(0.6, r * 0.08))
	match str(_ap.get("pommettes", "")):
		"hautes", "saillantes":
			for cote_p in [-1.0, 1.0]:
				var o_p: Vector2 = c + p * (r * 0.62 * cote_p) + d * r * (0.05 if str(_ap.pommettes) == "hautes" else -0.02)
				draw_line(o_p - d * r * 0.12, o_p + d * r * 0.12, encre.lightened(0.2), maxf(0.6, r * (0.10 if str(_ap.pommettes) == "saillantes" else 0.06)))
	match str(_ap.get("implantation", "")):
		"en_pointe":
			draw_colored_polygon(PackedVector2Array([c - p * r * 0.22 + d * r * 0.72, c + p * r * 0.22 + d * r * 0.72, c + d * r * 0.42]), cheveux)
		"degarnie":
			for cote_i in [-1.0, 1.0]:
				draw_circle(c + p * (r * 0.6 * cote_i) + d * r * 0.62, r * 0.2, peau)
	match str(_ap.get("paupieres", "")):
		"lourdes":
			for cote_pa in [-1.0, 1.0]:
				var o_pa: Vector2 = c + p * (r * ecart * cote_pa) + d * r * (0.30 + f_haut)
				draw_line(o_pa - p * r * 0.2, o_pa + p * r * 0.2, encre, maxf(0.7, r * 0.11))
		"plissees":
			for cote_pl in [-1.0, 1.0]:
				var o_pl: Vector2 = c + p * (r * ecart * cote_pl) + d * r * (0.33 + f_haut)
				draw_arc(o_pl, r * 0.2, PI * 1.1, PI * 1.9, 8, encre, maxf(0.5, r * 0.06))
	match str(_ap.get("marque", "aucune")):
		"cicatrice":
			draw_line(c + p * r * 0.5 + d * r * 0.5, c + p * r * 0.25 - d * r * 0.45, encre.lightened(0.25), maxf(0.6, r * 0.08))
		"tatouage":
			draw_arc(c - p * r * 0.45 + d * r * 0.05, r * 0.24, 0.0, TAU, 10, cheveux.lightened(0.1), maxf(0.6, r * 0.08))

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
