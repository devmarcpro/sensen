extends Control
class_name HudEcran
## Le HUD fixe à l'écran (Écrans d'interface — décision du designer, 2026-08-30) : un **compas** avec
## l'**horloge** dedans, la **température**, le **pentagramme Wu Xing** (la jauge de chaîne), les barres
## **vie / endurance / mana / faim**, et la **hotbar**. Dessiné par code, sans asset (règle du projet) ;
## tout ce qui est affiché vient de la simulation — le HUD ne calcule rien, il montre.

var main: Node2D
const MARGE := 12.0
const RAYON_COMPAS := 34.0
const RAYON_PENTA := 30.0
const BARRE_L := 160.0
const BARRE_H := 10.0
const CASE := 56.0   # assez large pour lire « Étincelle » ou « Attaque » sans les tronquer
const COULEURS := {"sante": Color(0.85, 0.2, 0.2), "endurance": Color(0.9, 0.7, 0.2), "mana": Color(0.3, 0.5, 0.95), "faim": Color(0.55, 0.35, 0.15)}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main == null or main.sim == null or main.titre_ouvert:   # pas de HUD derrière l'écran principal
		return
	var j: Dictionary = main.joueur()
	if j.is_empty():
		return
	var sim = main.sim
	var taille := get_viewport_rect().size
	# Sous la minimap (128 px en haut à droite — designer, 2026-08-30) : le compas, puis le pentagramme.
	var sous_minimap := MARGE + float(Minimap.TAILLE) + 12.0
	_dessiner_compas(sim, j, Vector2(taille.x - MARGE - float(Minimap.TAILLE) * 0.5, sous_minimap + RAYON_COMPAS))
	_dessiner_pentagramme(sim, j, Vector2(taille.x - MARGE - float(Minimap.TAILLE) * 0.5, sous_minimap + RAYON_COMPAS * 2 + 30.0 + RAYON_PENTA))
	_dessiner_barres(j, Vector2(MARGE, taille.y - MARGE - CASE - 4.0 * (BARRE_H + 6.0) - 12.0))

	_dessiner_hotbar(sim, j, Vector2(MARGE, taille.y - MARGE - CASE))


## Le compas : le nord en haut (la grille est orientée), l'orientation du joueur en aiguille, et l'horloge
## du monde au centre — l'aiguille des heures fait le tour en 24 h, la phase teinte le cadran.
func _dessiner_compas(sim, j: Dictionary, c: Vector2) -> void:
	var nuit: bool = sim.est_nuit()
	draw_circle(c, RAYON_COMPAS + 2.0, Color(0.05, 0.05, 0.08, 0.85))
	draw_arc(c, RAYON_COMPAS, 0.0, TAU, 48, Color(0.6, 0.55, 0.4), 2.0)
	var noms := ["N", "E", "S", "O"]
	for k in 4:
		var a := -PI / 2.0 + k * PI / 2.0
		var p := c + Vector2(cos(a), sin(a)) * (RAYON_COMPAS - 9.0)
		draw_string(ThemeDB.fallback_font, p + Vector2(-4.0, 4.0), noms[k], HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0.8, 0.75, 0.6))
	# l'orientation du joueur : une aiguille rouge
	var o: Vector2i = j.get("orientation", Vector2i(0, 1))
	if o != Vector2i.ZERO:
		var d := Vector2(o).normalized()
		draw_line(c, c + d * (RAYON_COMPAS - 4.0), Color(0.9, 0.3, 0.2), 2.0)
	# l'horloge : 24 h sur un tour, minuit en haut ; le disque central dit la phase
	var h: float = sim.heure()
	var ang := -PI / 2.0 + h / 24.0 * TAU
	draw_circle(c, 14.0, Color(0.15, 0.15, 0.3, 0.9) if nuit else Color(0.9, 0.8, 0.45, 0.9))
	draw_line(c, c + Vector2(cos(ang), sin(ang)) * 12.0, Color(0.1, 0.1, 0.1) if not nuit else Color(0.9, 0.9, 0.8), 2.0)
	draw_string(ThemeDB.fallback_font, c + Vector2(-RAYON_COMPAS, RAYON_COMPAS + 14.0), "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.85))
	# la température ressentie, à côté de l'heure
	var t: Dictionary = sim.temperature_ressentie(j)
	var col := Color(0.6, 0.75, 1.0) if float(t.get("ecart", 0.0)) < 0.0 else (Color(1.0, 0.6, 0.4) if float(t.get("ecart", 0.0)) > 0.0 else Color(0.85, 0.85, 0.8))
	draw_string(ThemeDB.fallback_font, c + Vector2(4.0, RAYON_COMPAS + 14.0), "%.0f°" % float(t.get("temp", 18.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


## Le pentagramme Wu Xing : les cinq éléments en étoile dans l'ordre d'engendrement ; les segments de la
## jauge de chaîne s'allument sur leur élément, le dernier posé plus fort (Jauge de chaîne Wu Xing).
func _dessiner_pentagramme(sim, j: Dictionary, c: Vector2) -> void:
	var elements: Array = sim.wuxing.w.elements
	var pts: Array[Vector2] = []
	for k in elements.size():
		var a := -PI / 2.0 + k * TAU / elements.size()
		pts.append(c + Vector2(cos(a), sin(a)) * RAYON_PENTA)
	draw_circle(c, RAYON_PENTA + 6.0, Color(0.05, 0.05, 0.08, 0.75))
	for k in pts.size():   # le cycle d'engendrement (le cercle) et celui de domination (l'étoile)
		draw_line(pts[k], pts[(k + 1) % pts.size()], Color(0.5, 0.5, 0.45, 0.7), 1.0)
		draw_line(pts[k], pts[(k + 2) % pts.size()], Color(0.35, 0.35, 0.3, 0.5), 1.0)
	var segments: Array = j.get("chaine", {}).get("segments", [])
	var compte := {}
	for s in segments:
		compte[str(s.element)] = int(compte.get(str(s.element), 0)) + 1
	# L'élément à enchaîner clignote (designer 2026-09-01, point 60) : celui qu'ENGENDRE le dernier
	# segment posé. Le joueur n'a plus à connaître le cycle par cœur pour savoir où frapper ensuite.
	var cap_c := int(j.get("chaine", {}).get("capacite", 0))
	var suivant := ""
	if not segments.is_empty() and segments.size() < cap_c:
		suivant = str(sim.wuxing.w.engendre.get(str(segments.back().element), ""))
	var cli: Dictionary = GameData.config("wuxing").get("clignotement", {})
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / maxf(80.0, float(cli.get("periode_ms", 420))) * TAU)
	for k in elements.size():
		var el := str(elements[k])
		var teinte: Color = sim.wuxing.teinte(el)
		var n := int(compte.get(el, 0))
		draw_circle(pts[k], 5.0 + 2.0 * n, teinte if n > 0 else teinte.darkened(0.55))
		if not segments.is_empty() and str(segments.back().element) == el:
			draw_arc(pts[k], 9.0 + 2.0 * n, 0.0, TAU, 16, Color(1, 1, 1, 0.9), 1.5)
		if el == suivant and not suivant.is_empty():
			var a_cli: float = float(cli.get("amplitude", 0.85)) * pulse
			draw_circle(pts[k], 5.0 + 2.0 * n + 4.0 * pulse, Color(teinte.r, teinte.g, teinte.b, a_cli * 0.45))
			draw_arc(pts[k], 12.0 + 3.0 * pulse, 0.0, TAU, 18, Color(1.0, 1.0, 1.0, a_cli), 2.0)
			var dep_fl := pts[elements.find(str(segments.back().element))]   # une flèche depuis l'élément courant
			var dir_fl := (pts[k] - dep_fl).normalized()
			draw_line(dep_fl + dir_fl * 10.0, pts[k] - dir_fl * 12.0, Color(1.0, 1.0, 1.0, a_cli * 0.7), 1.5)
	var cap := int(j.get("chaine", {}).get("capacite", 0))
	if cap > 0:
		draw_string(ThemeDB.fallback_font, c + Vector2(-8.0, 5.0), "%d/%d" % [segments.size(), cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.9, 0.85))


## Les quatre barres : vie, endurance, mana, faim — la valeur écrite dedans, jamais un pourcentage seul.
func _dessiner_barres(j: Dictionary, o: Vector2) -> void:
	var lignes := [["sante", int(j.sante), int(j.sante_max)], ["endurance", int(j.endurance), int(j.endurance_max)],
		["mana", int(j.mana), int(j.mana_max)], ["faim", int(j.get("faim", 100)), 100]]
	for k in lignes.size():
		var l: Array = lignes[k]
		var y := o.y + k * (BARRE_H + 6.0)
		var part := clampf(float(l[1]) / maxf(1.0, float(l[2])), 0.0, 1.0)
		draw_rect(Rect2(o.x, y, BARRE_L, BARRE_H), Color(0.05, 0.05, 0.08, 0.85))
		draw_rect(Rect2(o.x, y, BARRE_L * part, BARRE_H), COULEURS[str(l[0])])
		draw_rect(Rect2(o.x, y, BARRE_L, BARRE_H), Color(0.6, 0.55, 0.4, 0.8), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(o.x + BARRE_L + 6.0, y + BARRE_H), "%s %d/%d" % [tr("barre." + str(l[0])), l[1], l[2]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.9, 0.85))


## La hotbar : dix cases (1 → 0), la sélection encadrée, la molette la fait tourner (main.gd).
func _dessiner_hotbar(sim, j: Dictionary, o: Vector2) -> void:
	var entrees: Array = main.hotbar_entrees(j)
	for k in 10:
		var r := Rect2(o.x + k * (CASE + 4.0), o.y, CASE, CASE)
		var sel: bool = k == int(main.hotbar_sel)
		draw_rect(r, Color(0.05, 0.05, 0.08, 0.85))
		draw_rect(r, Color(1.0, 0.9, 0.5) if sel else Color(0.6, 0.55, 0.4, 0.8), false, 2.0 if sel else 1.0)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(3.0, 11.0), str((k + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.65, 0.5))
		if k < entrees.size() and not str(entrees[k].get("type", "")).is_empty():
			var nom := str(entrees[k].nom)
			if str(entrees[k].type) == "capacite":   # l'icône combinée du sort (Pictos), au-dessus de son nom
				var cap: Dictionary = j.capacites[int(entrees[k].ref)]
				Pictos.dessiner_sort(self, cap.get("modules", []), Rect2(r.position + Vector2(CASE * 0.22, 12.0), Vector2(CASE * 0.56, CASE * 0.56)))
			_nom_ajuste(nom, r)

## Le nom d'une case tenu dans sa largeur : la police rétrécit (jusqu'à 7) au lieu de couper le mot.
func _nom_ajuste(nom: String, r: Rect2) -> void:
	var f := ThemeDB.fallback_font
	var large := r.size.x - 6.0
	var taille_police := 10
	while taille_police > 7 and f.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, taille_police).x > large:
		taille_police -= 1
	draw_string(f, r.position + Vector2(3.0, CASE - 6.0), nom, HORIZONTAL_ALIGNMENT_LEFT, large, taille_police, Color(0.95, 0.95, 0.9))
