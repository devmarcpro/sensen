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
	return {"origine": origine, "direction": d, "perp": perp, "longueur": float(s.longueur), "largeur": float(s.largeur)}


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
		draw_circle(o + d * l * 0.5, l * 0.5, col)
		if contour > 0.0:
			draw_arc(o + d * l * 0.5, l * 0.5, 0.0, TAU, 16, col.darkened(0.45), contour)
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
