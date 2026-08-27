extends Node2D
## Prototype de combat — le CLIENT : rend l'état de la Simulation et lui envoie des intentions.
## Il ne décide de rien (Contraintes permanentes, règle 1) ; il rythme seulement l'avancement
## des horloges d'action pour que l'œil suive. Tout est dessiné en polygones — aucun asset.
## La lisibilité EST le game feel (Combat tactique sur grille) : timeline, coûts sur les tuiles
## atteignables, prévisualisation des dégâts, télégraphes, journal.

const TW := 40            # largeur d'une tuile à l'écran
const TH := 20            # hauteur du losange
const HSTEP := 8          # pixels par niveau de hauteur
const DELAI_PAS := 0.12   # secondes réelles entre deux pas d'une horloge de combat (lisibilité)
const BUDGET_ATTEIGNABLE := 12   # ticks : rayon des coûts affichés

var sim: Simulation
var arenes: Array[String] = []
var arene_courante := 0
var joueur_id := ""
var chemin_en_cours: Array[Vector2i] = []
var minuterie_pas := 0.0
var minuterie_ui := 0.0
var minuterie_clavier := 0.0        # cadence des pas au clavier (ZQSD maintenu)
var survol := Vector2i(-1, -1)
var journal: Array[String] = []
var telegraphes: Dictionary = {}   # id → action engagée
var atteignables: Dictionary = {}
var camera_offset := Vector2.ZERO
var profil_sans_ui := false        # mesure de perf : saute la mise à jour du texte
var profil_sans_terrain := false   # mesure de perf : saute le dessin des tuiles
var visee := -1                    # capacité en cours de visée (index), -1 sinon
var ecran_fin: Array[String] = []  # récapitulatif du dernier combat (écran de fin), vide sinon
var zoom := 1.0

var terrain: Terrain              # couche statique : les tuiles, dessinées une fois (perf É0)

@onready var ui: Label = $CanvasLayer/Info
@onready var ui_droite: Label = $CanvasLayer/Droite
@onready var ui_bas: Label = $CanvasLayer/Bas   # journal + aide en bas : le centre de l'écran reste au joueur


## La couche statique du terrain : ses commandes de dessin persistent d'une image à l'autre.
class Terrain extends Node2D:
	var proprio: Node2D
	func _draw() -> void:
		proprio._dessiner_terrain(self)


func _ready() -> void:
	terrain = Terrain.new()
	terrain.proprio = self
	terrain.z_index = -1
	add_child(terrain)
	arenes.assign(GameData.catalogues.get("prototype_arenas", {}).keys())
	arenes.sort()
	EventBus.journal.connect(_sur_journal)
	EventBus.action_engaged.connect(func(id: String, a: Dictionary) -> void: telegraphes[id] = a)
	EventBus.action_resolved.connect(func(id: String, _a: Dictionary) -> void: telegraphes.erase(id))
	EventBus.combat_ended.connect(_sur_fin_de_combat)
	EventBus.tile_changed.connect(func(_p: Vector2i) -> void: terrain.queue_redraw())
	GameData.donnees_rechargees.connect(_charger)
	_charger()


func _charger() -> void:
	sim = Simulation.new(0x68EE)
	sim.charger_arene(arenes[arene_courante])
	joueur_id = ""
	for e in sim.vivants():
		if e.controle == "joueur":
			joueur_id = e.id
	chemin_en_cours.clear()
	telegraphes.clear()
	journal.clear()
	terrain.queue_redraw()
	_log(tr("ui.aide"))
	var j := joueur()
	if not j.is_empty() and not j.ratelier.is_empty():
		var noms: Array[String] = []
		for k in j.ratelier.size():
			noms.append("%d=%s" % [k + 1, tr(sim.items[j.ratelier[k]].name_key)])
		_log(tr("ui.aide.armes").format({"liste": " · ".join(noms)}))
	if not j.is_empty() and not j.get("capacites", []).is_empty():
		var caps: Array[String] = []
		for k in j.capacites.size():
			caps.append("F%d=%s" % [k + 1, tr(j.capacites[k].get("name_key", j.capacites[k].id))])
		_log(tr("ui.aide.capacites").format({"liste": " · ".join(caps)}))
	visee = -1
	_recentrer()


func _recentrer() -> void:
	scale = Vector2.ONE * zoom
	var j := joueur()
	if j.is_empty():
		return
	var taille := get_viewport_rect().size
	# Le joueur est centré à l'écran, la vue le suit (Écrans d'interface, décision du 2026-08-27).
	position = taille * 0.5 - _ecran(j.pos, sim.grille.h(j.pos)) * zoom


func joueur() -> Dictionary:
	return sim.entites.get(joueur_id, {})


func _sur_journal(cle: String, params: Dictionary) -> void:
	var p := {}
	for k in params.keys():
		var v: Variant = params[k]
		p[k] = tr(v) if (v is String and v.contains(".")) else v
	_log(tr(cle).format(p))


func _log(t: String) -> void:
	journal.append(t)
	if journal.size() > 9:
		journal.pop_front()


# ---------------------------------------------------------------- rythme (client)

func _process(delta: float) -> void:
	var j := joueur()
	if j.is_empty():
		return
	_recentrer()
	# ZQSD (8 directions d'écran) : Z = haut, S = bas, Q = gauche, D = droite ; deux touches = diagonale.
	minuterie_clavier -= delta
	if sim.attente.has(joueur_id) and visee < 0 and minuterie_clavier <= 0.0:
		var dir := Vector2i.ZERO
		if Input.is_key_pressed(KEY_Z):
			dir += Vector2i(-1, -1)
		if Input.is_key_pressed(KEY_S):
			dir += Vector2i(1, 1)
		if Input.is_key_pressed(KEY_D):
			dir += Vector2i(1, -1)
		if Input.is_key_pressed(KEY_Q):
			dir += Vector2i(-1, 1)
		dir = Vector2i(signi(dir.x), signi(dir.y))
		if dir != Vector2i.ZERO:
			chemin_en_cours.clear()
			minuterie_clavier = 0.15
			if not sim.intention(joueur_id, {"type": "deplacer", "vers": j.pos + dir}):
				_log(tr("journal.inaccessible"))
	# En attente d'intention : on consomme la file d'ordres du joueur (un pas par décision).
	if sim.attente.has(joueur_id) and not chemin_en_cours.is_empty():
		var cible: Vector2i = chemin_en_cours[0]
		if not sim.intention(joueur_id, {"type": "deplacer", "vers": cible}):
			chemin_en_cours.clear()
			_log(tr("journal.inaccessible"))
		else:
			chemin_en_cours.pop_front()
	# Les horloges de combat n'avancent qu'à l'action : le client les fait avancer pas à pas.
	minuterie_pas -= delta
	if minuterie_pas <= 0.0:
		minuterie_pas = DELAI_PAS
		for nom in sim.combats.keys():
			sim.pas(nom)
	_maj_atteignables()
	minuterie_ui -= delta
	if minuterie_ui <= 0.0 and not profil_sans_ui:
		minuterie_ui = 0.05
		_maj_ui()
	queue_redraw()


func _maj_atteignables() -> void:
	var j := joueur()
	atteignables = {}
	if j.vivant and sim.attente.has(joueur_id) and sim.en_combat(j):
		atteignables = sim.grille.atteignables(j.pos, BUDGET_ATTEIGNABLE, Etres.est_volant(j))


# ---------------------------------------------------------------- entrées → intentions

func _unhandled_input(ev: InputEvent) -> void:
	var j := joueur()
	if not ecran_fin.is_empty() and ((ev is InputEventMouseButton and ev.pressed) or (ev is InputEventKey and ev.pressed)):
		ecran_fin.clear()
		if ev is InputEventKey and ev.keycode == KEY_TAB:
			arene_courante = (arene_courante + 1) % arenes.size()
			_charger()
		return
	if ev is InputEventMouseMotion:
		survol = _tuile_sous(get_local_mouse_position())
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = minf(2.0, zoom * 1.1)
			scale = Vector2.ONE * zoom
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxf(0.5, zoom / 1.1)
			scale = Vector2.ONE * zoom
		elif ev.button_index == MOUSE_BUTTON_LEFT and not j.is_empty() and j.vivant:
			_clic(_tuile_sous(get_local_mouse_position()), ev.shift_pressed)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_G:
				chemin_en_cours.clear()
				sim.intention(joueur_id, {"type": "garde"})
			KEY_SPACE:
				chemin_en_cours.clear()
				sim.intention(joueur_id, {"type": "attendre"})
			KEY_TAB:
				arene_courante = (arene_courante + 1) % arenes.size()
				_charger()
			KEY_F1, KEY_F2, KEY_F3:
				var k: int = ev.keycode - KEY_F1
				if not j.is_empty() and k < j.get("capacites", []).size():
					chemin_en_cours.clear()
					var plan := sim.plan_capacite(j, k)
					if plan.geometrie == "soi":
						sim.intention(joueur_id, {"type": "capacite", "index": k, "cible": j.pos})
						visee = -1
					else:
						visee = k
			KEY_ESCAPE:
				visee = -1
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
				var k: int = ev.keycode - KEY_1
				if not j.is_empty() and k < j.ratelier.size():
					chemin_en_cours.clear()
					sim.intention(joueur_id, {"type": "changer_arme", "item": j.ratelier[k]})


func _clic(t: Vector2i, lourde: bool) -> void:
	if t.x < 0:
		return
	var j := joueur()
	if visee >= 0:
		if sim.attente.has(joueur_id):
			if not sim.intention(joueur_id, {"type": "capacite", "index": visee, "cible": t}):
				_log(tr("journal.inaccessible"))
			else:
				visee = -1
		return
	var occ := sim.grille.occupant(t)
	if not occ.is_empty() and occ != joueur_id:
		chemin_en_cours.clear()
		if not sim.attente.has(joueur_id):
			return
		if not sim.intention(joueur_id, {"type": "attaquer", "cible": occ, "lourde": lourde}):
			var tir := sim.verifier_tir(j, sim.entites[occ])
			if not tir.ok:
				_log(tr("journal.tir_refuse").format({"raison": tr("raison." + tir.raison)}))
			else:
				_log(tr("journal.inaccessible"))
		return
	if Grille.distance(j.pos, t) == 1:
		chemin_en_cours = [t]   # un pas direct : autorise la chute volontaire
		return
	chemin_en_cours = sim.grille.chemin(j.pos, t, Etres.est_volant(j))
	if chemin_en_cours.is_empty() and t != j.pos:
		_log(tr("journal.inaccessible"))


func _tuile_sous(p: Vector2) -> Vector2i:
	var meilleur := Vector2i(-1, -1)
	var meilleure_d := 1e9
	var g := sim.grille
	for y in g.hauteur_grille:
		for x in g.largeur:
			var t := Vector2i(x, y)
			var c := _ecran(t, g.h(t))
			var d := c.distance_squared_to(p)
			if d < meilleure_d and d < float(TW * TW) * 0.3:
				meilleure_d = d
				meilleur = t
	return meilleur


# ---------------------------------------------------------------- rendu

func _ecran(t: Vector2i, h: int) -> Vector2:
	return Vector2((t.x - t.y) * TW * 0.5, (t.x + t.y) * TH * 0.5 - h * HSTEP)


func _draw() -> void:
	if sim == null:
		return
	var g := sim.grille
	var j := joueur()
	# Superpositions translucides sur les tuiles (atteignables, télégraphes, survol, forme visée).
	for t in atteignables.keys():
		_losange(t, Color(0.9, 0.9, 0.5, 0.28))
	for t in _zones_telegraphes().keys():
		_losange(t, Color(1.0, 0.2, 0.1, 0.5))
	if survol.x >= 0:
		_losange(survol, Color(1, 1, 1, 0.22))
	for gl in sim.glyphes:   # les glyphes : un losange cerclé à la teinte de leur élément
		var cg := _ecran(gl.pos, g.h(gl.pos))
		var teinte := sim.wuxing.teinte(sim.wuxing.dominante(gl.elements)) if not gl.elements.is_empty() else Color(0.8, 0.8, 0.9)
		draw_arc(cg, 7.0, 0.0, TAU, 12, teinte, 2.0)
	if visee < 0 and survol.x >= 0 and not j.is_empty() and not g.occupant(survol).is_empty() and g.occupant(survol) != joueur_id:
		var tir := sim.verifier_tir(j, sim.entites[g.occupant(survol)])
		if tir.has("bloqueur"):
			_losange(tir.bloqueur, Color(1, 0.2, 0.2, 0.45))
	if visee >= 0 and survol.x >= 0 and not j.is_empty():
		var plan := sim.plan_capacite(j, visee)
		var ok := sim.capacite_visable(j, plan, survol)
		for t in Capacites.tuiles_de_forme(g, plan.geometrie, j.pos, survol, int(plan.taille)):
			_losange(t, Color(0.3, 0.6, 1.0, 0.45) if ok else Color(0.5, 0.5, 0.5, 0.35))
	if not chemin_en_cours.is_empty() and not j.is_empty():
		var pts := PackedVector2Array([_ecran(j.pos, g.h(j.pos))])
		for c in chemin_en_cours:
			pts.append(_ecran(c, g.h(c)))
		draw_polyline(pts, Color(1, 1, 1, 0.55), 2.0)
	# Entités par profondeur (x+y croissant) ; les tuiles plus hautes devant elles sont redessinées
	# par-dessus, pour que le relief les occulte comme dans la passe unique.
	var acteurs := sim.vivants()
	acteurs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.x + a.pos.y < b.pos.x + b.pos.y)
	for e in acteurs:
		_dessine_entite(e)
		var he := g.h(e.pos)
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 1), Vector2i(1, 2)]:
			var t: Vector2i = e.pos + d
			if g.dans(t) and (g.h(t) > he or g.bloque_passage(t)):
				_dessine_tuile(self, t)
	for t in atteignables.keys():
		if t == j.pos:
			continue
		var c := _ecran(t, g.h(t)) + Vector2(-6, 4)
		draw_string(ThemeDB.fallback_font, c, str(atteignables[t]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 0.8, 0.8))


func _losange(t: Vector2i, col: Color) -> void:
	var c := _ecran(t, sim.grille.h(t))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0), c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)]), col)


## La passe statique : toutes les tuiles, une seule fois (appelée par la couche Terrain).
func _dessiner_terrain(ci: CanvasItem) -> void:
	if sim == null or profil_sans_terrain:
		return
	var g := sim.grille
	for s in range(g.largeur + g.hauteur_grille - 1):     # tri de profondeur : diagonales x+y
		for x in g.largeur:
			var y := s - x
			if y >= 0 and y < g.hauteur_grille:
				_dessine_tuile(ci, Vector2i(x, y))


func _zones_telegraphes() -> Dictionary:
	var zones := {}
	for id in telegraphes.keys():
		var e: Dictionary = sim.entites[id]
		var a: Dictionary = telegraphes[id]
		if a.type == "creature":
			var action: Dictionary = sim.actions_creatures[a.action]
			var cible: Dictionary = sim.entites.get(a.cible, {})
			match str(action.forme):
				"ligne":
					for p in sim.grille.ligne(e.pos, cible.pos if not cible.is_empty() else e.pos + e.orientation, int(action.taille)):
						zones[p] = true
				"anneau", "soi":
					for p in sim.grille.anneau(e.pos, int(action.taille)):
						zones[p] = true
				_:
					if not cible.is_empty():
						zones[cible.pos] = true
		elif sim.entites.has(a.cible):
			zones[sim.entites[a.cible].pos] = true
	return zones


func _dessine_tuile(ci: CanvasItem, t: Vector2i) -> void:
	var g := sim.grille
	var h := g.h(t)
	var c := _ecran(t, h)
	var haut := PackedVector2Array([
		c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0),
		c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)])
	var k := clampf((h - 4) / 12.0, 0.0, 1.0)   # gradient : bas sombre, sommets clairs
	var col := Color(0.20, 0.34, 0.18).lerp(Color(0.62, 0.66, 0.42), k)
	ci.draw_colored_polygon(haut, col)
	var flanc := col.darkened(0.35)
	var hs := g.h(t + Vector2i(0, 1)) if g.dans(t + Vector2i(0, 1)) else 0
	if hs < h:
		var d := (h - hs) * HSTEP
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-TW * 0.5, 0), c + Vector2(0, TH * 0.5),
			c + Vector2(0, TH * 0.5 + d), c + Vector2(-TW * 0.5, d)]), flanc)
	var he := g.h(t + Vector2i(1, 0)) if g.dans(t + Vector2i(1, 0)) else 0
	if he < h:
		var d2 := (h - he) * HSTEP
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, TH * 0.5), c + Vector2(TW * 0.5, 0),
			c + Vector2(TW * 0.5, d2), c + Vector2(0, TH * 0.5 + d2)]), flanc.darkened(0.15))
	if g.bloque_passage(t):   # un mur : un bloc sombre posé sur la tuile
		var hm := 3 * HSTEP
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-TW * 0.5, 0), c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0),
			c + Vector2(TW * 0.5, -hm), c + Vector2(0, -TH * 0.5 - hm), c + Vector2(-TW * 0.5, -hm)]),
			Color(0.35, 0.32, 0.30))
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-TW * 0.5, -hm), c + Vector2(0, -TH * 0.5 - hm),
			c + Vector2(TW * 0.5, -hm), c + Vector2(0, TH * 0.5 - hm)]), Color(0.5, 0.47, 0.44))


## Billboard placeholder : une silhouette teintée dont la forme vient de la morphologie.
func _dessine_entite(e: Dictionary) -> void:
	var c := _ecran(e.pos, sim.grille.h(e.pos))
	var teinte := Color(e.teinte[0], e.teinte[1], e.teinte[2])
	match str(e.corps.silhouette):
		"quadrupede":
			draw_rect(Rect2(c + Vector2(-10, -12), Vector2(20, 9)), teinte)
			draw_circle(c + Vector2(e.orientation.x * 8, -13), 4.0, teinte.darkened(0.2))
		"volant":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -20), c + Vector2(0, -14), c + Vector2(12, -20), c + Vector2(0, -8)]), teinte)
		_:
			draw_rect(Rect2(c + Vector2(-5, -20), Vector2(10, 16)), teinte)
			draw_circle(c + Vector2(0, -24), 4.5, teinte.lightened(0.2))
	if e.garde:   # la garde : un arc devant l'orientation
		var o := Vector2(e.orientation.x - e.orientation.y, (e.orientation.x + e.orientation.y) * 0.5).normalized()
		draw_arc(c + Vector2(0, -10), 14.0, o.angle() - 0.9, o.angle() + 0.9, 8, Color(0.6, 0.85, 1.0), 2.0)
	if telegraphes.has(e.id):   # intention visible : le télégraphe est une information d'interface
		draw_string(ThemeDB.fallback_font, c + Vector2(-4, -30), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.3, 0.2))
	var w := 22.0
	draw_rect(Rect2(c + Vector2(-w * 0.5, -32), Vector2(w, 3)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(c + Vector2(-w * 0.5, -32), Vector2(w * e.sante / e.sante_max, 3)), Color(0.3, 0.9, 0.3))
	draw_rect(Rect2(c + Vector2(-w * 0.5, -28), Vector2(w * e.endurance / e.endurance_max, 2)), Color(0.9, 0.8, 0.3))
	if e.has("chaine"):   # la jauge de chaîne, toujours visible (pastilles colorées)
		var segs := _segments(e)
		var cap: int = e.chaine.capacite
		for k in cap:
			var p := c + Vector2(-w * 0.5 + 2 + k * (w - 2) / cap, 4)
			if k < segs.size():
				draw_circle(p, 2.6, sim.wuxing.teinte(segs[k].element))
			else:
				draw_circle(p, 2.2, Color(0, 0, 0, 0.5))


## Les segments effectifs d'une jauge à l'instant présent (décroissance calculée, sans la modifier).
func _segments(e: Dictionary) -> Array:
	var copie: Dictionary = e.chaine.duplicate(true)
	sim.wuxing.decroitre(copie, sim.horloge_de(e).ticks)
	return copie.segments


# ---------------------------------------------------------------- UI texte

func _maj_ui() -> void:
	var j := joueur()
	var g := sim.grille
	var lignes: Array[String] = [tr("ui.titre") + " · " + tr(GameData.entree("prototype_arenas", arenes[arene_courante]).name_key)]
	var mode := tr("ui.mode.combat") if sim.en_combat(j) else tr("ui.mode.exploration").format({"tps": sim.regles.r.ticks_par_seconde_exploration})
	lignes.append(tr("ui.horloge").format({"horloge": sim.horloge_de(j).ticks, "mode": mode}))
	for e in sim.vivants():
		lignes.append("  " + tr("ui.entite.ligne").format({"nom": tr(e.name_key), "pv": e.sante, "pv_max": e.sante_max,
			"end": e.endurance, "compteur": e.compteur, "h": g.h(e.pos)}) + (" · GARDE" if e.garde else "")
			+ (" · " + tr(sim.items[e.equipement.main_principale].name_key) if e.equipement.has("main_principale") else "")
			+ (" + " + tr(sim.items[e.equipement.main_secondaire].name_key) if e.equipement.has("main_secondaire") else "")
			+ (" · " + _texte_chaine(e) if e.has("chaine") else "")
			+ (" · " + _texte_statuts(e) if not e.statuts.is_empty() else ""))
	if survol.x >= 0 and not j.is_empty():
		lignes.append("  " + tr("ui.case").format({"x": survol.x, "y": survol.y, "h": g.h(survol), "dh": g.h(survol) - g.h(j.pos)}))
		var occ := g.occupant(survol)
		if not occ.is_empty() and occ != joueur_id and j.vivant:
			lignes.append_array(_preview(j, sim.entites[occ]))
	if not j.is_empty():
		lignes.append("  " + tr("ui.entite.mana").format({"mana": j.mana, "mana_max": j.mana_max}) + " · " + tr("ui.munitions").format({"n": j.munitions}))
		for k in j.get("capacites", []).size():
			lignes.append("  " + _texte_capacite(j, k))
		if visee >= 0:
			var plan := sim.plan_capacite(j, visee)
			lignes.append("  " + tr("ui.capacite.visee").format({"nom": tr(plan.name_key)}))
			if survol.x >= 0 and not g.occupant(survol).is_empty():
				lignes.append("  " + _preview_capacite(j, plan, sim.entites[g.occupant(survol)]))
	ui.text = "\n".join(lignes)
	var bas: Array[String] = []
	if not ecran_fin.is_empty():
		bas.append_array(ecran_fin)
		bas.append("")
	bas.append_array(journal)
	if not j.vivant:
		bas.append(tr("journal.defaite"))
	ui_bas.text = "\n".join(bas)
	# Timeline : les prochaines actions de l'horloge du joueur, par compteur croissant.
	var timeline: Array[String] = [tr("ui.timeline")]
	var acteurs := sim.vivants().filter(func(e: Dictionary) -> bool: return e.horloge == j.horloge)
	acteurs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.compteur < b.compteur)
	for e in acteurs:
		var suffixe := ""
		if not e.action_en_cours.is_empty():
			suffixe = " ← " + tr(e.action_en_cours.name_key)
		timeline.append("  t=%d  %s%s" % [e.compteur, tr(e.name_key), suffixe])
	ui_droite.text = "\n".join(timeline)


## Prévisualisation des dégâts avec le détail du calcul (la lisibilité est le but).
func _preview(j: Dictionary, cible: Dictionary) -> Array[String]:
	var res: Array[String] = []
	var arme := Etres.arme(j, sim.items)
	if arme.is_empty():
		return res
	var fonct: Dictionary = sim.fonctionnalites[arme.functionality]
	var zone: Dictionary = sim.regles.zone_de_coup(g_h(j.pos), g_h(cible.pos))
	var piece := Etres.piece_zone(cible, zone.zone, sim.items)
	var armure := sim.regles.armure_piece(piece, fonct.type_degats)
	var a_zero: bool = j.endurance <= 0
	var vecteur := sim.vecteur_arme(arme)
	var wx: Dictionary = sim._facteur_wuxing(j, cible, vecteur, sim.horloge_de(j).ticks)
	var f := sim.regles.fourchette_arme(j.corps.stats, arme, fonct, false, zone.mult, armure, a_zero, wx.total, j.competences, vecteur)
	var stat := int(j.corps.stats.force) / int(sim.regles.r.degats.stat_div)
	res.append("  " + tr("ui.preview").format({"nom": tr(arme.name_key), "des": fonct.degats_des,
		"dur": "%.2f" % (float(arme.durete_base) / float(sim.regles.r.degats.durete_reference) * float(arme.qualite)),
		"stat": stat, "zone": zone.zone, "mult": zone.mult, "armure": "%.1f" % armure,
		"min": f.x, "max": f.y, "ticks": sim.regles.ticks_attaque(fonct, false)}))
	var fl := sim.regles.fourchette_arme(j.corps.stats, arme, fonct, true, zone.mult, armure, a_zero, wx.total, j.competences, vecteur)
	res.append("  " + tr("ui.preview.lourde").format({"lourde": "%d–%d" % [fl.x, fl.y], "ticks": sim.regles.ticks_attaque(fonct, true)}))
	if not vecteur.is_empty():
		var contre: Array[String] = []
		for k in wx.contre.keys():
			contre.append("%s %d%%" % [tr("element." + k), roundi(float(wx.contre[k]) * 100.0)])
		var prev: Dictionary = wx.prevision
		res.append("  " + tr("ui.wuxing").format({"element": tr("element." + sim.wuxing.dominante(vecteur)),
			"contre": " ".join(contre) if not contre.is_empty() else "—", "dom": "%.2f" % wx.dom,
			"segments": _segments(j).size() if j.has("chaine") else 0, "capacite": j.chaine.capacite if j.has("chaine") else 0,
			"gain": "%.2f" % wx.gain, "position": prev.get("position", 0),
			"transition": "(+%.2f)" % prev.get("transition", 0.0), "chaine": ("RÉSOUT ×%.2f" % prev.multiplicateur) if prev.get("resout", false) else "%.2f" % wx.chaine}))
	if not sim.regles.a_portee(fonct, Grille.distance(j.pos, cible.pos)) or not sim.grille.ligne_de_vue(j.pos, cible.pos):
		res.append("  (hors de portée ou hors de vue)")
	return res


func g_h(p: Vector2i) -> int:
	return sim.grille.h(p)


## L'infobulle exhaustive d'une capacité : forme, portée, coûts, dés — calculés pour le porteur.
func _texte_capacite(j: Dictionary, k: int) -> String:
	var plan := sim.plan_capacite(j, k)
	var mods: Array[String] = []
	for m in plan.modules:
		mods.append(tr(sim.capacites.modules.get(m, {}).get("name_key", m)))
	return tr("ui.capacite").format({"touche": "F%d" % (k + 1), "nom": tr(plan.name_key), "modules": " + ".join(mods),
		"forme": plan.geometrie, "pmin": plan.portee.x, "pmax": plan.portee.y, "taille": plan.taille,
		"ticks": plan.ticks, "ressource": plan.ressource, "monnaie": plan.monnaie if not plan.monnaie.is_empty() else "—",
		"des": str(plan.des) if plan.des != null else "—", "bonus": (" +%d dé(s)" % plan.des_bonus) if plan.des_bonus > 0 else ""}) \
		+ ((" → " + tr(plan.charge_suivante.name_key) + " : " + tr(plan.charge_suivante.noyau.get("name_key", ""))) if not plan.charge_suivante.is_empty() else "")


func _preview_capacite(j: Dictionary, plan: Dictionary, cible: Dictionary) -> String:
	if not ("degats" in plan.effets):
		return ""
	var zone: Dictionary = sim.regles.zone_de_coup(g_h(j.pos), g_h(cible.pos))
	var dom: Dictionary = sim.multiplicateur_domination(plan.elements, cible, zone.zone)
	var piece := Etres.piece_zone(cible, zone.zone, sim.items)
	var arme_noyau: bool = plan.noyau.get("power_base") == "arme"
	var armure := 0.0
	if not plan.drapeaux.get("ignore_armure", false):
		armure = sim.regles.armure_piece(piece, str(plan.fonct.get("type_degats", "contondant")) if arme_noyau else "contondant")
		if not arme_noyau:
			armure *= float(sim.regles.r.armure.magie_facteur)
	var f := Des.fourchette(plan.des, int(plan.des_bonus))
	var k: float = float(dom.mult) * float(plan.mult)
	if j.has("chaine") and not plan.elements.is_empty():
		var prev: Dictionary = sim.wuxing.prevoir(j.chaine, sim.wuxing.dominante(plan.elements))
		k *= float(prev.gain) * float(prev.multiplicateur)
	return tr("ui.capacite.preview").format({"nom": tr(plan.name_key), "def": tr(cible.name_key), "des": str(plan.des),
		"bonus": (" +%d dé(s)" % plan.des_bonus) if plan.des_bonus > 0 else "", "dom": "%.2f" % dom.mult,
		"zone": zone.zone, "mult": zone.mult, "armure": "%.1f" % armure,
		"min": sim.regles.degats_finaux(f.x * k, zone.mult, armure, false), "max": sim.regles.degats_finaux(f.y * k, zone.mult, armure, false)})


func _texte_statuts(e: Dictionary) -> String:
	var noms: Array[String] = []
	var tick := sim.horloge_de(e).ticks
	for s in e.statuts:
		noms.append("%s (%d)" % [tr(sim.statuts_defs.get(s.id, {}).get("name_key", s.id)), int(s.fin) - tick])
	return tr("ui.statuts").format({"liste": ", ".join(noms)})


## Écran de fin de combat : issue, durée en ticks, XP des trois pistes et de l'armure (XP de combat).
func _sur_fin_de_combat(_nom: String) -> void:
	telegraphes.clear()
	var j := joueur()
	var dc: Dictionary = sim.dernier_combat
	if j.is_empty() or dc.is_empty():
		return
	ecran_fin = [tr("ui.fin.titre").format({"issue": tr("ui.fin.victoire") if dc.victoire else tr("ui.fin.defaite"), "ticks": dc.ticks})]
	for piste in ["element", "competence", "type", "construction"]:
		var parts: Array[String] = []
		for k in j.xp[piste].keys():
			var nom: String = tr("element." + k) if piste == "element" else str(k)
			parts.append("%s %d" % [nom, j.xp[piste][k]])
		ecran_fin.append(tr("ui.fin.piste").format({"piste": piste, "detail": ", ".join(parts) if not parts.is_empty() else "—"}))
	ecran_fin.append(tr("ui.fin.suite"))
	for piste in j.xp.keys():
		j.xp[piste] = {}   # non persistée : l'écran la montre, la partie ne la garde pas (prototype)


func _texte_chaine(e: Dictionary) -> String:
	var noms: Array[String] = []
	for s in _segments(e):
		noms.append(tr("element." + s.element))
	return tr("ui.chaine").format({"segments": " → ".join(noms) if not noms.is_empty() else "∅"})
