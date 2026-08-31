class_name Paperdoll
extends Node2D
## Le rendu d'un être — creature.tscn, la seule scène pour tout être vivant (Décisions
## d'architecture). Tout vient des données : la silhouette du rig (`data/rigs/`), les pièces
## d'équipement aux ancrages (Squelette modulaire et points d'attache), la teinte du matériau
## (Palette de couleurs des matériaux). Aucune branche par type d'être (Apparence — données).
## Les sprites n'existent pas encore : chaque segment est un rectangle procédural accroché à
## son ancrage — le rig, l'ordre de calque, les décalages et le miroir sont déjà les vrais.

## Orientation de grille → facing d'écran (géométrie de la vue, pas du gameplay).
const FACINGS := {
	Vector2i(1, 1): "S", Vector2i(1, 0): "SE", Vector2i(1, -1): "E", Vector2i(0, -1): "NE",
	Vector2i(-1, -1): "N", Vector2i(-1, 0): "NW", Vector2i(-1, 1): "W", Vector2i(0, 1): "SW"}
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
	var facing: String = FACINGS.get(e.get("orientation", Vector2i(1, 1)), "S")
	var f: Dictionary = rig.facings.get(facing, {})
	var miroir := false
	if f.has("miroir"):
		miroir = true
		f = rig.facings[f.miroir]
	_ap = e.get("apparence", {})
	_vue_tete = str(f.get("vue_tete", "face"))
	var fac: Dictionary = GameData.config("apparence").get("facteurs", {})
	_carrure = float(fac.get("carrure", {}).get(str(_ap.get("carrure", "moyenne")), 1.0))
	var ech := float(_ap.get("echelle", 1.0))
	if not is_equal_approx(ech, 1.0):
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(ech, ech))
	var monde := _poser_segments(f, miroir)
	var peint := _segments_peints()
	var teinte := Color(e.teinte[0], e.teinte[1], e.teinte[2])
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
			monde[nom] = _placer(nom, pt, miroir)
			restants.erase(nom)
	return monde


func _placer(nom: String, origine: Vector2, miroir: bool) -> Dictionary:
	var s: Dictionary = rig.segments[nom]
	var angle := float(s.angle) + float(pose.get(nom, 0.0))
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
		var r := l * 0.5 * float(fact.get(str(_ap.get("tete", "ronde")), 1.0))
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
		var haut := Vector2(0, -1)
		match str(fonct.get("combat_skill", "")):
			"dague": draw_line(pt, pt + haut * 6, col, 1.5)
			"epee": draw_line(pt, pt + haut * 12, col, 1.8)
			"masse":
				draw_line(pt, pt + haut * 8, col.darkened(0.3), 1.5)
				draw_circle(pt + haut * 9, 2.5, col)
			"lance": draw_line(pt + Vector2(0, 6), pt + haut * 16, col, 1.5)
			"arc": draw_arc(pt + Vector2(2, -4), 7.0, -PI * 0.6, PI * 0.6, 10, col, 1.5)
			"baton_magique": draw_line(pt + Vector2(0, 6), pt + haut * 14, col, 1.8)
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
	var oreille := float(_ap.get("oreilles", 0.0))
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
	var ecart := 0.42 if _vue_tete == "face" else 0.18
	match str(_ap.get("yeux", "points")):
		"grands":
			for cote3 in [-1.0, 1.0]:
				draw_circle(c + p * (r * ecart * cote3) + d * r * 0.15, maxf(0.8, r * 0.2), encre)
		"en_amande":
			for cote7 in [-1.0, 1.0]:
				var o7: Vector2 = c + p * (r * ecart * cote7) + d * r * 0.15
				draw_arc(o7, r * 0.2, 0.0, TAU, 10, encre, maxf(0.7, r * 0.09))
		"tombants":
			for cote8 in [-1.0, 1.0]:
				var o8: Vector2 = c + p * (r * ecart * cote8) + d * r * 0.18
				draw_line(o8 - p * r * 0.14, o8 + p * r * 0.14 - d * r * 0.12, encre, maxf(0.8, r * 0.1))
		"fentes":
			for cote4 in [-1.0, 1.0]:
				var o4: Vector2 = c + p * (r * ecart * cote4) + d * r * 0.15
				draw_line(o4 - p * r * 0.16, o4 + p * r * 0.16, encre, maxf(0.8, r * 0.1))
		_:
			for cote5 in [-1.0, 1.0]:
				draw_circle(c + p * (r * ecart * cote5) + d * r * 0.15, maxf(0.6, r * 0.12), encre)
	var nez := str(_ap.get("nez", "droit"))
	var haut_nez: Vector2 = c + d * r * 0.05
	if nez == "fin":
		draw_line(haut_nez, haut_nez - d * r * 0.3, encre, maxf(0.5, r * 0.05))
	elif nez == "busque":
		draw_line(haut_nez + d * r * 0.1, haut_nez - d * r * 0.15 + p * r * 0.08, encre, maxf(0.7, r * 0.1))
		draw_line(haut_nez - d * r * 0.15 + p * r * 0.08, haut_nez - d * r * 0.4, encre, maxf(0.7, r * 0.1))
	elif nez == "crochu":
		draw_line(haut_nez, haut_nez - d * r * 0.35 + p * r * 0.12, encre, maxf(0.7, r * 0.09))
	elif nez == "plat":
		draw_line(haut_nez - p * r * 0.1, haut_nez + p * r * 0.1, encre, maxf(0.7, r * 0.09))
	else:
		draw_line(haut_nez, haut_nez - d * r * 0.35, encre, maxf(0.7, r * 0.09))
	var bouche := str(_ap.get("bouche", "fine"))
	var y_bouche: Vector2 = c - d * r * 0.5
	var demi := r * (0.3 if bouche == "large" else 0.18)
	if bouche == "boudeuse":
		draw_arc(y_bouche - d * r * 0.24, r * 0.3, PI * 0.2, PI * 0.8, 10, encre, maxf(0.7, r * 0.09))
	elif bouche == "sourire":
		draw_arc(y_bouche + d * r * 0.2, r * 0.32, PI * 1.15, PI * 1.85, 10, encre, maxf(0.7, r * 0.09))
	else:
		draw_line(y_bouche - p * demi, y_bouche + p * demi, encre, maxf(0.7, r * 0.09))
	var barbe := float(_ap.get("barbe", 0.0))
	if barbe > 0.0:
		draw_colored_polygon(PackedVector2Array([
			c - p * r * 0.8 - d * r * 0.1, c + p * r * 0.8 - d * r * 0.1,
			c + p * r * 0.35 - d * (r + barbe), c - p * r * 0.35 - d * (r + barbe),
		]), cheveux)
