class_name Carte
extends CanvasLayer
## La carte du monde (Carte du monde, 3.1) : une vue abstraite de la même grille — une case par
## cellule, le biome échantillonné au centre, la heat-map de danger en trois niveaux (paisible /
## dangereuse / mortelle — Niveau de danger), les icônes des POI ; déplacement case par case ; le
## voyage rapide en cliquant une cellule déjà explorée (Carte du monde : le raccourci) ; en mode
## « départ », le clic choisit la case de départ (Début de partie). Dessinée par code, sans asset.

const CASE := 18
const N := 33                 # cellules par côté

var main: Node
var ouverte := false
var survol := Vector2i(-1, -1)   # la cellule sous la souris
var mode := "voyage"          # "voyage" | "depart"
var centre := Vector2i.ZERO   # cellule au centre de la carte
var dessin: Control
var titre: Label


func _ready() -> void:
	layer = 11
	visible = false
	dessin = Control.new()
	dessin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dessin.mouse_filter = Control.MOUSE_FILTER_STOP
	dessin.draw.connect(_dessiner)
	dessin.gui_input.connect(_entree)
	add_child(dessin)
	titre = Label.new()
	titre.position = Vector2(20, 12)
	titre.add_theme_font_size_override("font_size", 15)
	add_child(titre)


func ouvrir(p_mode: String = "voyage") -> void:
	if main.sim == null or main.sim.monde == null:
		return   # pas de monde (arène) : pas de carte
	mode = p_mode
	ouverte = true
	visible = true
	var j: Dictionary = main.joueur()
	centre = main.sim.monde.cellule_de(j.pos) if not j.is_empty() and main.sim.monde != null else main.sim.monde.cellule_camp
	titre.text = tr("ui.carte.depart") if mode == "depart" else tr("ui.carte.titre")
	dessin.queue_redraw()


func fermer() -> void:
	ouverte = false
	visible = false


func _origine() -> Vector2:
	var taille := dessin.get_viewport_rect().size
	return Vector2((taille.x - N * CASE) * 0.5, (taille.y - N * CASE) * 0.5 + 10)


func _cellule_sous(p: Vector2) -> Vector2i:
	var o := _origine()
	var c := Vector2i(int(floor((p.x - o.x) / CASE)), int(floor((p.y - o.y) / CASE)))
	if c.x < 0 or c.y < 0 or c.x >= N or c.y >= N:
		return Vector2i(-1, -1)
	return centre + c - Vector2i(N / 2, N / 2)


func _dessiner() -> void:
	var sim = main.sim
	if sim == null or sim.monde == null:
		return
	var surf = sim.monde.surface
	var o := _origine()
	dessin.draw_rect(Rect2(o - Vector2(6, 6), Vector2(N * CASE + 12, N * CASE + 12)), Color(0.05, 0.05, 0.07, 0.96))
	var j: Dictionary = main.joueur()
	var cj: Vector2i = sim.monde.cellule_de(j.pos) if not j.is_empty() else centre
	for y in N:
		for x in N:
			var cell := centre + Vector2i(x, y) - Vector2i(N / 2, N / 2)
			var r := Rect2(o + Vector2(x * CASE, y * CASE), Vector2(CASE - 1, CASE - 1))
			var info: Dictionary = surf.resume_cellule(cell)
			var col: Color = Color.html(str(info.couleur))
			if not info.terre:
				col = Color(0.15, 0.3, 0.55)
			var exploree: bool = sim.monde.cellule_exploree(cell)
			if mode == "voyage" and not exploree:
				col = col.darkened(0.55)
			dessin.draw_rect(r, col)
			var roy: Dictionary = surf.royaume_de(cell) if info.terre else {}
			if not roy.is_empty():
				var teinte := Color.from_hsv(float(hash(str(roy.id)) % 360) / 360.0, 0.7, 0.9, 0.35)
				dessin.draw_rect(r, teinte)
				if roy.capital_poi == cell:
					dessin.draw_rect(r.grow(-2), Color(1.0, 0.95, 0.6), false, 2.0)
			# Heat-map de danger : trois niveaux lisibles (Niveau de danger : vague par défaut).
			match int(sim.monde.danger_de(cell)):
				1: dessin.draw_rect(r, Color(1.0, 0.5, 0.1, 0.25))
				2: dessin.draw_rect(r, Color(1.0, 0.1, 0.1, 0.4))
			if info.poi.get("donjon", false):
				dessin.draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(CASE - 11, CASE - 11)), Color(0.1, 0.05, 0.1))
				dessin.draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(CASE - 11, CASE - 11)), Color(0.9, 0.8, 0.3), false, 1.0)
			if info.poi.get("filon_majeur", false):
				dessin.draw_circle(r.position + Vector2(CASE * 0.5, CASE * 0.5), 3.0, Color(0.8, 0.85, 0.9))
			if sim.monde.claims.has(cell):
				dessin.draw_rect(r.grow(-1), Color(0.3, 1.0, 0.4, 0.9), false, 2.0)
			elif sim.monde.revendicable(cell, sim.horloge_monde.ticks):
				dessin.draw_rect(r.grow(-2), Color(0.3, 1.0, 0.4, 0.35), false, 1.0)
			if cell == cj:
				dessin.draw_rect(r.grow(-3), Color(0.3, 0.8, 1.0), false, 2.0)
	dessin.draw_string(ThemeDB.fallback_font, o + Vector2(0, N * CASE + 20), tr("ui.carte.legende"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.8))
	# Les routes : un trait ocre entre cellules reliées (Unification macro-micro).
	for y in N:
		for x in N:
			var cell := centre + Vector2i(x, y) - Vector2i(N / 2, N / 2)
			if not surf.terre_a(cell):
				continue
			var c0 := o + Vector2(x * CASE + CASE * 0.5, y * CASE + CASE * 0.5)
			for v in surf.route_de(cell):
				var dv: Vector2i = v - cell
				dessin.draw_line(c0, c0 + Vector2(dv.x, dv.y) * CASE * 0.5, Color(0.85, 0.7, 0.4, 0.9), 2.0)
	# Les noms des royaumes sur leur capitale (la carte politique se lit avant toute visite — Génération des royaumes PNJ).
	for y in N:
		for x in N:
			var cell := centre + Vector2i(x, y) - Vector2i(N / 2, N / 2)
			var roy: Dictionary = surf.royaume_de(cell) if surf.terre_a(cell) else {}
			if not roy.is_empty() and roy.capital_poi == cell:
				dessin.draw_string(ThemeDB.fallback_font, o + Vector2(x * CASE - 10, y * CASE - 3), str(roy.nom), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.95, 0.7))
	# Le survol : biome, danger, royaume, dirigeant, relation.
	if survol != Vector2i(-1, -1):
		var info_s: Dictionary = surf.resume_cellule(survol)
		var texte := tr("ui.carte.survol").format({"x": survol.x, "y": survol.y, "biome": tr(GameData.entree("biomes", str(info_s.biome)).name_key) if info_s.terre else tr("ui.carte.mer"), "danger": int(sim.monde.danger_de(survol))})
		if info_s.terre:   # le vecteur du lieu (Wu Xing hors combat) : ce que le mana y coûtera
			var vl: Dictionary = sim.vecteur_lieu(sim.monde.pos_monde(survol, Vector2i(sim.monde.taille / 2, sim.monde.taille / 2)))
			if not vl.is_empty():
				var cles: Array = vl.keys()
				cles.sort_custom(func(p: String, q: String) -> bool: return float(vl[p]) > float(vl[q]))
				texte += tr("ui.carte.survol_lieu").format({"a": tr("element." + str(cles[0])), "pa": roundi(float(vl[cles[0]]) * 100.0), "b": tr("element." + str(cles[1])), "pb": roundi(float(vl[cles[1]]) * 100.0)})
		var roy_s: Dictionary = surf.royaume_de(survol) if info_s.terre else {}
		if not roy_s.is_empty():
			var jr: Dictionary = main.joueur()
			var etat := tr("ui.carte.vacance") if sim.monde.vacances.has(str(roy_s.id)) else tr("relation." + sim.relation_royaume(jr, roy_s))
			texte += tr("ui.carte.survol_royaume").format({"nom": roy_s.nom, "gouv": tr(GameData.entree("governments", str(roy_s.government_type)).name_key), "taille": tr("kingdom.taille." + str(roy_s.taille)), "n": roy_s.territory_cells.size(), "etat": etat, "capitale": tr("ui.carte.capitale") if roy_s.capital_poi == survol else ""})
		dessin.draw_string(ThemeDB.fallback_font, o + Vector2(0, N * CASE + 38), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.9, 0.7))


func _entree(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var c := _cellule_sous(ev.position)
		if c != survol:
			survol = c
			dessin.queue_redraw()
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cellule_sous(ev.position)
		if cell == Vector2i(-1, -1):
			return
		if mode == "depart":
			main._choisir_depart(cell)
		else:
			main._voyager(cell)
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		if mode != "depart":
			fermer()


## Touches quand la carte est ouverte (flèches : faire défiler la carte).
func touche(ev: InputEventKey) -> bool:
	match ev.keycode:
		KEY_ESCAPE, KEY_TAB:
			if mode != "depart":
				fermer()
			return true
		KEY_LEFT: centre.x -= 4
		KEY_RIGHT: centre.x += 4
		KEY_UP: centre.y -= 4
		KEY_DOWN: centre.y += 4
		_:
			return false
	dessin.queue_redraw()
	return true
