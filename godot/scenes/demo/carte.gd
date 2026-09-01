class_name Carte
extends CanvasLayer
## La carte du monde (Carte du monde, 3.1) : une vue abstraite de la même grille — une case par
## cellule, le biome échantillonné au centre, la heat-map de danger en trois niveaux (paisible /
## dangereuse / mortelle — Niveau de danger), les icônes des POI ; déplacement case par case ; le
## voyage rapide en cliquant une cellule déjà explorée (Carte du monde : le raccourci) ; en mode
## « départ », le clic choisit la case de départ (Début de partie). Dessinée par code, sans asset.

var case_px := 18.0           # taille d'une cellule à l'écran (le zoom est annulé — designer, 2026-09-01)
var decalage := Vector2.ZERO   # défilement fin, en pixels (le glisser à la souris)

var main: Node
var ouverte := false
var survol := Vector2i(-1, -1)   # la cellule sous la souris
var mode := "voyage"          # "voyage" | "depart"
var centre := Vector2i.ZERO   # cellule au centre de la carte
var dessin: Control
var titre: Label
var _glisse := false
var avatar: Paperdoll   # le joueur, dessiné sur sa cellule (designer, point 59)


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
	if avatar != null:
		avatar.visible = false


## Combien de cellules tiennent à l'écran, au zoom courant (impair : le centre est une case).
## La carte a LE FORMAT DU MONDE (designer 2026-09-01) : le monde est une mappemonde deux fois plus
## large que haute, la carte l'est aussi. On tient le maximum de cellules à l'écran en gardant ce
## rapport ; le nombre de colonnes et de lignes est impair, pour qu'une case soit au centre.
func _fenetre() -> Vector2i:
	var taille := dessin.get_viewport_rect().size
	var ratio := float(GameData.config("planete").get("monde_ratio", 1.0))
	var nx := int(minf(taille.x - 40.0, (taille.y - 60.0) / maxf(0.2, ratio)) / case_px)
	var ny := int(round(nx * ratio))
	nx = maxi(5, nx if nx % 2 == 1 else nx - 1)
	ny = maxi(5, ny if ny % 2 == 1 else ny - 1)
	return Vector2i(nx, ny)


func _n() -> int:
	return _fenetre().x


func _origine() -> Vector2:
	var taille := dessin.get_viewport_rect().size
	var f := _fenetre()
	return Vector2((taille.x - f.x * case_px) * 0.5, (taille.y - f.y * case_px) * 0.5 + 10) + decalage


func _cellule_sous(p: Vector2) -> Vector2i:
	var o := _origine()
	var f := _fenetre()
	var c := Vector2i(int(floor((p.x - o.x) / case_px)), int(floor((p.y - o.y) / case_px)))
	if c.x < 0 or c.y < 0 or c.x >= f.x or c.y >= f.y:
		return Vector2i(-1, -1)
	return centre + c - Vector2i(f.x / 2, f.y / 2)


func _dessiner() -> void:
	var sim = main.sim
	if sim == null or sim.monde == null:
		return
	var surf = sim.monde.surface
	var o := _origine()
	dessin.draw_rect(Rect2(o - Vector2(6, 6), Vector2(_fenetre().x * case_px + 12, _fenetre().y * case_px + 12)), Color(0.05, 0.05, 0.07, 0.96))
	var j: Dictionary = main.joueur()
	var cj: Vector2i = sim.monde.cellule_de(j.pos) if not j.is_empty() else centre
	var tc: int = int(GameData.config('planete').taille_cellule)
	var sp_min: int = int(GameData.config('styles').get('carte', {}).get('sous_points_min_px', 10))
	var f := _fenetre()
	for y in f.y:
		for x in f.x:
			var cell := centre + Vector2i(x, y) - Vector2i(f.x / 2, f.y / 2)
			var r := Rect2(o + Vector2(x * case_px, y * case_px), Vector2(case_px - 1.0, case_px - 1.0))
			var info: Dictionary = surf.resume_cellule(cell)
			var col: Color = Color.html(str(info.couleur))
			if not info.terre:
				col = Color(0.15, 0.3, 0.55)
			var exploree: bool = sim.monde.cellule_exploree(cell)
			if mode == "voyage" and not exploree:
				col = col.darkened(0.55)
			if case_px >= float(sp_min):   # une cellule = 5 × 5 sondes : les côtes et les reliefs se lisent
				_peindre_cellule(cell, r, col, surf, tc)
			else:
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
			var dc: Dictionary = sim.monde.donjon_de_corruption(cell, sim.jour_courant()) if exploree else {}
			if not dc.is_empty():   # un donjon né de la corruption (designer, point 51) : sa teinte d'élément
				var tel: Dictionary = GameData.config("wuxing").get("teintes", {})
				var ce := Color.html(str(tel.get(str(dc.element), "#aa3333")))
				dessin.draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), ce.darkened(0.35))
				dessin.draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), ce, false, 1.0)
				if case_px >= 16.0:
					dessin.draw_string(ThemeDB.fallback_font, r.position + Vector2(3, r.size.y - 3), str(int(dc.niveau)), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.9))
			if info.poi.get("donjon", false):
				dessin.draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(case_px - 11.0, case_px - 11.0)), Color(0.1, 0.05, 0.1))
				dessin.draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(case_px - 11.0, case_px - 11.0)), Color(0.9, 0.8, 0.3), false, 1.0)
			if info.poi.get("filon_majeur", false):
				dessin.draw_circle(r.position + Vector2(case_px * 0.5, case_px * 0.5), 3.0, Color(0.8, 0.85, 0.9))
			if sim.monde.claims.has(cell):
				dessin.draw_rect(r.grow(-1), Color(0.3, 1.0, 0.4, 0.9), false, 2.0)
			elif sim.monde.revendicable(cell, sim.horloge_monde.ticks):
				dessin.draw_rect(r.grow(-2), Color(0.3, 1.0, 0.4, 0.35), false, 1.0)
			if cell == cj:
				dessin.draw_rect(r.grow(-3), Color(0.3, 0.8, 1.0), false, 2.0)
				_placer_avatar(r)
	dessin.draw_string(ThemeDB.fallback_font, o + Vector2(0, _fenetre().y * case_px + 20), tr("ui.carte.legende"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.8))
	# Les routes : un trait ocre entre cellules reliées (Unification macro-micro).
	for y in f.y:
		for x in f.x:
			var cell := centre + Vector2i(x, y) - Vector2i(f.x / 2, f.y / 2)
			if not surf.terre_a(cell):
				continue
			var c0 := o + Vector2(x * case_px + case_px * 0.5, y * case_px + case_px * 0.5)
			for v in surf.route_de(cell):
				var dv: Vector2i = v - cell
				dessin.draw_line(c0, c0 + Vector2(dv.x, dv.y) * case_px * 0.5, Color(0.85, 0.7, 0.4, 0.9), 2.0)
	# Les noms des royaumes sur leur capitale (la carte politique se lit avant toute visite — Génération des royaumes PNJ).
	for y in f.y:
		for x in f.x:
			var cell := centre + Vector2i(x, y) - Vector2i(f.x / 2, f.y / 2)
			var roy: Dictionary = surf.royaume_de(cell) if surf.terre_a(cell) else {}
			if not roy.is_empty() and roy.capital_poi == cell:
				dessin.draw_string(ThemeDB.fallback_font, o + Vector2(x * case_px - 10.0, y * case_px - 3.0), str(roy.nom), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.95, 0.7))
	# Le survol : biome, danger, royaume, dirigeant, relation.
	if survol != Vector2i(-1, -1):
		var info_s: Dictionary = surf.resume_cellule(survol)
		var texte := tr("ui.carte.survol").format({"x": survol.x, "y": survol.y, "biome": tr(GameData.entree("biomes", str(info_s.biome)).name_key) if info_s.terre else tr("ui.carte.mer"), "danger": int(sim.monde.danger_de(survol))})
		var dsurv: Dictionary = sim.monde.donjon_de_corruption(survol, sim.jour_courant())
		if not dsurv.is_empty():   # le donjon dit sa difficulté au survol (designer, point 61)
			var cr_s: Dictionary = GameData.config("planete").corruption
			var etages_s := int(cr_s.etages_mineur[0]) + int(dsurv.niveau) / 4
			texte += tr("ui.carte.survol_donjon").format({
				"nom": tr(GameData.entree("dungeon_themes", str(dsurv.theme)).name_key),
				"element": tr("element." + str(dsurv.element)),
				"niveau": int(dsurv.niveau), "etages": etages_s,
				"corruption": roundi(sim.monde.corruption_jour(survol, sim.jour_courant())),
			})
		var derive := int(sim.monde.delta.get(survol, 0))   # Dérive de la corruption : le delta accumulé se lit
		if derive != 0:
			texte += tr("ui.carte.survol_derive").format({"d": ("+%d" % derive) if derive > 0 else str(derive)})
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
		dessin.draw_string(ThemeDB.fallback_font, o + Vector2(0, _fenetre().y * case_px + 38.0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.9, 0.7))


## Une cellule peinte en 5 × 5 sous-points (designer 2026-09-01, point 59) : la surface est
## échantillonnée cinq fois par côté, de sorte qu'une côte, une lisière ou un flanc se lisent
## DANS la case. La couleur de base reste celle du biome : les sondes la nuancent, mer comprise.
## L'avatar du joueur sur sa cellule (designer 2026-09-01, point 59) : le paperdoll du jeu, réduit,
## pas une pastille — on doit se reconnaître sur la carte comme on se reconnaît sur le terrain.
func _placer_avatar(r: Rect2) -> void:
	var j: Dictionary = main.joueur()
	if j.is_empty():
		return
	if avatar == null:
		avatar = Paperdoll.new()
		dessin.add_child(avatar)
	avatar.configurer(j, GameData.entree("rigs", str(j.get("skeleton_template", "humanoide"))), main.sim.items, GameData.catalogues.functionalities, GameData.config("palette_materiaux"))
	var ech := clampf(case_px / 26.0, 0.25, 1.4)   # il grandit avec le zoom, sans jamais déborder
	avatar.scale = Vector2(ech, ech)
	avatar.position = r.position + Vector2(r.size.x * 0.5, r.size.y * 0.92)
	avatar.visible = true
	avatar.queue_redraw()


func _peindre_cellule(cell: Vector2i, r: Rect2, col: Color, surf, tc: int) -> void:
	var sp: int = int(GameData.config("styles").get("carte", {}).get("sous_points", 5))
	var pas := r.size.x / float(sp)
	var mer := Color(0.10, 0.22, 0.42)
	for sy in sp:
		for sx in sp:
			var px := cell.x * tc + int((sx + 0.5) / sp * tc)
			var py := cell.y * tc + int((sy + 0.5) / sp * tc)
			var t: Dictionary = surf.tectonique_a(px, py)
			var alt := float(t.get("altitude", 0.0))
			var c := col
			if alt < 0.30:                       # sous le niveau de la mer : la profondeur se voit
				c = mer.lerp(Color(0.20, 0.38, 0.62), clampf(alt / 0.30, 0.0, 1.0))
			elif alt < 0.38:                     # la frange littorale
				c = col.lerp(Color(0.85, 0.80, 0.60), 0.45)
			elif alt > 0.72:                     # les hautes terres
				c = col.lerp(Color(0.93, 0.93, 0.96), clampf((alt - 0.72) / 0.28, 0.0, 1.0) * 0.8)
			else:
				c = col.lerp(Color.BLACK, (0.55 - alt) * 0.25)
			dessin.draw_rect(Rect2(r.position + Vector2(sx * pas, sy * pas), Vector2(pas + 0.5, pas + 0.5)), c)


func _entree(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		_glisse = ev.pressed   # la carte se fait glisser au bouton du milieu ou au bouton droit
		return
	if ev is InputEventMouseMotion:
		if _glisse:   # le glissement se traite ICI : une branche placée après le survol ne serait jamais atteinte
			decalage += ev.relative
			var pas_c := int(decalage.x / case_px)   # au-delà d'une case, on décale la fenêtre elle-même
			if pas_c != 0:
				centre.x -= pas_c
				decalage.x -= pas_c * case_px
			var pas_l := int(decalage.y / case_px)
			if pas_l != 0:
				centre.y -= pas_l
				decalage.y -= pas_l * case_px
			dessin.queue_redraw()
			return
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
