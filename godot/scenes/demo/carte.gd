class_name Carte
extends CanvasLayer
## La carte du monde (Carte du monde, 3.1) : une vue abstraite de la même grille — une case par cellule, le biome
## échantillonné au centre, la heat-map de danger en trois niveaux, les icônes des POI ; déplacement case par case ;
## le voyage rapide en cliquant une cellule déjà explorée ; en mode « départ », le clic choisit la case de départ.
##
## Gardée en cache (designer 2026-09-06 : « la carte du monde lag énormément… il faudrait la garder en cache
## totalement comme ça on pourrait ouvrir fermer, zoomer dézoomer, se déplacer à notre guise ») : le monde est une
## IMAGE — une texture de base d'un pixel par cellule pour le monde entier, peinte une fois par tranches dans un fil
## de travail (les tranches autour du joueur d'abord) ; des tuiles de détail de 64 × 64 cellules à cinq sous-points
## par côté, peintes à la demande quand on zoome dessus, gardées pour la partie ; un voile d'état (non exploré,
## danger) ; et seulement quelques repères dessinés à chaque image. Le zoom est de retour à la molette.

const MORCEAU := 64            # une tuile de détail : 64 × 64 cellules
const BANDE := 8               # une tranche de la texture de base : 8 lignes de cellules

var case_px := 18.0            # taille d'une cellule à l'écran (le zoom, à la molette)
var decalage := Vector2.ZERO   # défilement fin, en pixels (le glisser à la souris)

var main: Node
var ouverte := false
var survol := Vector2i(-1, -1)   # la cellule sous la souris
var mode := "voyage"          # "voyage" | "depart"
var centre := Vector2i.ZERO   # cellule au centre de la carte
var dessin: Control
var titre: Label
var _glisse := false
var _regions_connues: Dictionary = {}   # germes de région dont au moins une cellule est explorée
var avatar: Paperdoll   # le joueur, dessiné sur sa cellule (designer, point 59)

# Le cache : le monde en images.
var _monde_id := 0                 # l'identité du monde en cache (un autre monde : on refait tout)
var _n := Vector2i.ZERO            # la taille du monde en cellules
var _sp := 5                       # sous-points par côté d'une cellule de détail
var _base: Image                   # un pixel par cellule, le monde entier
var _tex_base: ImageTexture
var _etat: Image                   # le danger, RGBA, peint par le fil à chaque ouverture
var _tex_etat: ImageTexture
var _voile: Image                  # les cellules non explorées assombries (mode voyage), refait à l'ouverture
var _tex_voile: ImageTexture
var _details: Dictionary = {}      # Vector2i (tuile) → ImageTexture
var _bandes_faites: Dictionary = {}   # index de bande → true
var _detail_demandes: Dictionary = {}  # tuile → true : en cours ou en attente
var _file: Array = []              # les travaux en attente : {"type": "base"|"etat"|"detail", ...}
var _tache := -1                   # la tâche du fil de travail en cours (-1 : aucune)
var _tache_travail: Dictionary = {}
var _resultat: Dictionary = {}     # le résultat de la tâche finie, posé par le fil
var _mutex := Mutex.new()
var _jour_etat := -1               # le jour du dernier état peint (le danger dérive avec la corruption)
var _secteurs_peints := -1         # combien de secteurs de royaumes étaient calculés à la dernière peinture de la base
var _connus: Array = []            # les donjons de corruption des cellules connues, listés à l'ouverture : [{cell, dc}]
var _capitales: Array = []         # les capitales des royaumes connus du cache : [{cell, nom}]


func _ready() -> void:
	layer = 11
	visible = false
	dessin = Control.new()
	dessin.set_anchors_preset(Control.PRESET_FULL_RECT)
	dessin.mouse_filter = Control.MOUSE_FILTER_STOP
	dessin.draw.connect(_dessiner)
	dessin.gui_input.connect(_entree)
	dessin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # un pixel par cellule, agrandi net : pas de flou entre les cases
	add_child(dessin)
	titre = Label.new()
	titre.position = Vector2(20, 12)
	titre.add_theme_font_size_override("font_size", 15)
	add_child(titre)
	set_process(true)


func _exit_tree() -> void:
	if _tache >= 0:
		WorkerThreadPool.wait_for_task_completion(_tache)
		_tache = -1


func ouvrir(p_mode: String = "voyage") -> void:
	if main.sim == null or main.sim.monde == null:
		return   # pas de monde (arène) : pas de carte
	mode = p_mode
	ouverte = true
	visible = true
	var j: Dictionary = main.joueur()
	centre = main.sim.monde.cellule_de(j.pos) if not j.is_empty() else main.sim.monde.cellule_camp
	decalage = Vector2.ZERO
	titre.text = tr("ui.carte.depart") if mode == "depart" else tr("ui.carte.titre")
	_assurer_cache()
	if main.sim.monde.surface.royaumes_cache.size() != _secteurs_peints:   # des royaumes calculés depuis : leurs teintes manquent à la base
		_planifier_base()
	_refaire_voile()
	_lister_reperes()
	if _jour_etat != main.sim.jour_courant():
		_jour_etat = main.sim.jour_courant()
		_planifier_etat()
	dessin.queue_redraw()


## Dès qu'un monde existe (nouvelle partie, partie reprise), la carte se prépare en arrière-plan : à la première
## ouverture, le monde est déjà peint autour du joueur — c'est le sens du cache (designer 2026-09-06).
func preparer() -> void:
	if main.sim == null or main.sim.monde == null:
		return
	var j: Dictionary = main.joueur()
	centre = main.sim.monde.cellule_de(j.pos) if not j.is_empty() else main.sim.monde.cellule_camp
	_assurer_cache()
	if _jour_etat != main.sim.jour_courant():
		_jour_etat = main.sim.jour_courant()
		_planifier_etat()


func fermer() -> void:
	ouverte = false
	visible = false
	if avatar != null:
		avatar.visible = false


## Le cache suit le monde : un autre monde (nouvelle partie, chargement), tout se refait. Les altitudes de détail sont
## déjà dans la sauvegarde (`Monde.carte_altitudes`) : la première ouverture d'une partie reprise a peu à calculer.
func _assurer_cache() -> void:
	var monde = main.sim.monde
	if _monde_id == monde.get_instance_id() and _base != null:
		return
	if _tache >= 0:
		WorkerThreadPool.wait_for_task_completion(_tache)
		_tache = -1
	_monde_id = monde.get_instance_id()
	var planete: Dictionary = GameData.config("planete")
	var nx := int(planete.get("monde_cellules", 1024))
	_n = Vector2i(nx, maxi(1, int(round(nx * float(planete.get("monde_ratio", 1.0))))))
	_sp = int(GameData.config("styles").get("carte", {}).get("sous_points", 5))
	_base = Image.create(_n.x, _n.y, false, Image.FORMAT_RGB8)
	_base.fill(Color(0.10, 0.22, 0.42))
	_tex_base = ImageTexture.create_from_image(_base)
	_etat = Image.create(_n.x, _n.y, false, Image.FORMAT_RGBA8)
	_etat.fill(Color(0, 0, 0, 0))
	_tex_etat = ImageTexture.create_from_image(_etat)
	_voile = Image.create(_n.x, _n.y, false, Image.FORMAT_RGBA8)
	_tex_voile = ImageTexture.create_from_image(_voile)
	_details.clear()
	_detail_demandes.clear()
	_bandes_faites.clear()
	_file.clear()
	_resultat = {}
	_jour_etat = -1
	_planifier_base()


## Les tranches de la base, celles autour du joueur d'abord (une tranche déjà en file n'y revient pas).
func _planifier_base() -> void:
	_secteurs_peints = main.sim.monde.surface.royaumes_cache.size()
	var bandes: Array = []
	for b in (_n.y + BANDE - 1) / BANDE:
		bandes.append(b)
	var bj := centre.y / BANDE
	bandes.sort_custom(func(a: int, b: int) -> bool: return absi(a - bj) < absi(b - bj))
	for k in range(_file.size() - 1, -1, -1):
		if _file[k].type == "base":
			_file.remove_at(k)
	for b in bandes:
		_file.append({"type": "base", "bande": b})


## Le danger dérive avec la corruption : à chaque nouveau jour, l'état se repeint par tranches, autour du joueur d'abord.
func _planifier_etat() -> void:
	var bandes: Array = []
	for b in (_n.y + BANDE - 1) / BANDE:
		bandes.append(b)
	var bj := centre.y / BANDE
	bandes.sort_custom(func(a: int, b: int) -> bool: return absi(a - bj) < absi(b - bj))
	for k in range(_file.size() - 1, -1, -1):
		if _file[k].type == "etat":
			_file.remove_at(k)
	for b in bandes:
		_file.append({"type": "etat", "bande": b})


## Le voile des cellules non explorées (mode voyage) : tout sombre, sauf les chunks explorés — c'est un petit ensemble.
func _refaire_voile() -> void:
	var monde = main.sim.monde
	_voile.fill(Color(0, 0, 0, 0.55) if mode == "voyage" else Color(0, 0, 0, 0))
	if mode == "voyage":
		var n_chunks: int = monde.taille / 32
		var clair := Color(0, 0, 0, 0)
		for ch in monde.explores.keys():
			var cx := int(ch.x) / n_chunks
			var cy := int(ch.y) / n_chunks
			if cx >= 0 and cy >= 0 and cx < _n.x and cy < _n.y:
				_voile.set_pixel(cx, cy, clair)
	_tex_voile.update(_voile)


## Les repères connus, listés une fois à l'ouverture : les donjons de corruption des régions connues, les capitales.
func _lister_reperes() -> void:
	var sim = main.sim
	var surf = sim.monde.surface
	_regions_connues.clear()
	var n_chunks: int = sim.monde.taille / 32
	for ch in sim.monde.explores.keys():
		_regions_connues[surf.germe_region(Vector2i(int(ch.x) / n_chunks, int(ch.y) / n_chunks))] = true
	_connus.clear()
	var jour: int = sim.jour_courant()
	var vues := {}
	for ch in sim.monde.explores.keys():   # les cellules explorées et leurs voisines à douze cellules : là où un donjon se sait (sa région connue)
		var c0 := Vector2i(int(ch.x) / n_chunks, int(ch.y) / n_chunks)
		for dy in range(-12, 13):
			for dx in range(-12, 13):
				var c := c0 + Vector2i(dx, dy)
				if vues.has(c):
					continue
				vues[c] = true
				var connue: bool = sim.monde.cellule_exploree(c) or _regions_connues.has(surf.germe_region(c))
				if not connue:
					continue
				var dc: Dictionary = sim.monde.donjon_de_corruption(c, jour)
				if not dc.is_empty():
					_connus.append({"cell": c, "dc": dc})
	_capitales.clear()
	for sect in surf.royaumes_cache.keys():
		for id in surf.royaumes_cache[sect].keys():
			var roy: Dictionary = surf.royaumes_cache[sect][id]
			if roy.has("capital_poi"):
				_capitales.append({"cell": roy.capital_poi, "nom": str(roy.get("nom", "")), "id": str(id)})


# ---------------------------------------------------------------- le fil de travail

func _process(_delta: float) -> void:
	if _base == null:
		return
	# Un résultat prêt : on le pose dans l'image, sur le fil principal.
	if _tache >= 0 and WorkerThreadPool.is_task_completed(_tache):
		WorkerThreadPool.wait_for_task_completion(_tache)
		_tache = -1
		_mutex.lock()
		var res: Dictionary = _resultat
		_resultat = {}
		_mutex.unlock()
		if not res.is_empty():
			_poser_resultat(res)
			if ouverte:
				dessin.queue_redraw()
	# Le travail suivant : le détail demandé d'abord (on le regarde), puis la base, puis l'état.
	if _tache < 0 and not _file.is_empty():
		var k := 0
		for i in _file.size():
			if _file[i].type == "detail":
				k = i
				break
		_tache_travail = _file[k]
		_file.remove_at(k)
		_tache = WorkerThreadPool.add_task(_travailler.bind(_tache_travail), false, "carte")


## Le fil : une tranche de la base (couleur de biome et de mer, teinte du royaume), une tranche d'état (danger), ou
## une tuile de détail (les altitudes à cinq sous-points). Rien ici n'écrit dans la simulation.
func _travailler(t: Dictionary) -> void:
	var surf = main.sim.monde.surface
	var res := {"type": str(t.type)}
	if t.type == "base" or t.type == "etat":
		var b := int(t.bande)
		var y0 := b * BANDE
		var y1 := mini(_n.y, y0 + BANDE)
		var rgb := PackedByteArray()
		rgb.resize((y1 - y0) * _n.x * (3 if t.type == "base" else 4))
		var k := 0
		for y in range(y0, y1):
			for x in _n.x:
				var cell := Vector2i(x, y)
				if t.type == "base":
					var col: Color
					if surf.terre_a(cell):
						col = Color.html(str(surf.biomes.get(surf.biome_a(cell.x * int(surf.planete.taille_cellule) + int(surf.planete.taille_cellule) / 2, cell.y * int(surf.planete.taille_cellule) + int(surf.planete.taille_cellule) / 2), {}).get("couleur", "#7fa64a")))
						var rid := str(surf.royaume_par_cellule.get(cell, ""))   # les royaumes déjà calculés seulement : en calculer un par secteur ici prendrait des minutes
						if not rid.is_empty():
							col = col.blend(Color.from_hsv(float(hash(rid) % 360) / 360.0, 0.7, 0.9, 0.35))
					else:
						col = Color(0.15, 0.3, 0.55)
					rgb[k] = int(col.r * 255.0)
					rgb[k + 1] = int(col.g * 255.0)
					rgb[k + 2] = int(col.b * 255.0)
					k += 3
				else:
					var d := int(main.sim.monde.danger_de(cell)) if surf.terre_a(cell) else 0
					var c := Color(0, 0, 0, 0)
					if d == 1:
						c = Color(1.0, 0.5, 0.1, 0.25)
					elif d == 2:
						c = Color(1.0, 0.1, 0.1, 0.4)
					rgb[k] = int(c.r * 255.0)
					rgb[k + 1] = int(c.g * 255.0)
					rgb[k + 2] = int(c.b * 255.0)
					rgb[k + 3] = int(c.a * 255.0)
					k += 4
		res["bande"] = b
		res["rgb"] = rgb
	else:
		var tuile: Vector2i = t.tuile
		var tc: int = int(surf.planete.taille_cellule)
		var px := MORCEAU * _sp
		var rgb := PackedByteArray()
		rgb.resize(px * px * 3)
		var altitudes: Dictionary = {}   # cellule → PackedByteArray des altitudes, à retenir dans le monde (fil principal)
		var mer := Color(0.10, 0.22, 0.42)
		for ly in MORCEAU:
			for lx in MORCEAU:
				var cell := tuile * MORCEAU + Vector2i(lx, ly)
				var col := Color(0.15, 0.3, 0.55)
				var terre: bool = cell.x < _n.x and cell.y < _n.y and surf.terre_a(cell)
				if terre:
					col = Color.html(str(surf.biomes.get(surf.biome_a(cell.x * tc + tc / 2, cell.y * tc + tc / 2), {}).get("couleur", "#7fa64a")))
					var rid := str(surf.royaume_par_cellule.get(cell, ""))
					if not rid.is_empty():
						col = col.blend(Color.from_hsv(float(hash(rid) % 360) / 360.0, 0.7, 0.9, 0.35))
				var memoire: PackedByteArray = t.memoires.get(cell, PackedByteArray())
				var calculees := PackedByteArray()
				for sy in _sp:
					for sx in _sp:
						var alt := 0.0
						if memoire.is_empty():
							if cell.x < _n.x and cell.y < _n.y:
								alt = float(surf.tectonique_a(cell.x * tc + int((sx + 0.5) / _sp * tc), cell.y * tc + int((sy + 0.5) / _sp * tc)).get("altitude", 0.0))
							calculees.append(clampi(roundi(alt * 255.0), 0, 255))
						else:
							alt = float(memoire[sy * _sp + sx]) / 255.0
						var c := col
						if alt < 0.30:
							c = mer.lerp(Color(0.20, 0.38, 0.62), clampf(alt / 0.30, 0.0, 1.0))
						elif alt < 0.38:
							c = col.lerp(Color(0.85, 0.80, 0.60), 0.45)
						elif alt > 0.72:
							c = col.lerp(Color(0.93, 0.93, 0.96), clampf((alt - 0.72) / 0.28, 0.0, 1.0) * 0.8)
						else:
							c = col.lerp(Color.BLACK, (0.55 - alt) * 0.25)
						var i := ((ly * _sp + sy) * px + lx * _sp + sx) * 3
						rgb[i] = int(c.r * 255.0)
						rgb[i + 1] = int(c.g * 255.0)
						rgb[i + 2] = int(c.b * 255.0)
				if memoire.is_empty() and not calculees.is_empty():
					altitudes[cell] = calculees
		res["tuile"] = tuile
		res["rgb"] = rgb
		res["altitudes"] = altitudes
	_mutex.lock()
	_resultat = res
	_mutex.unlock()


func _poser_resultat(res: Dictionary) -> void:
	match str(res.type):
		"base":
			var b := int(res.bande)
			var y0 := b * BANDE
			var h := mini(_n.y, y0 + BANDE) - y0
			var img := Image.create_from_data(_n.x, h, false, Image.FORMAT_RGB8, res.rgb)
			_base.blit_rect(img, Rect2i(0, 0, _n.x, h), Vector2i(0, y0))
			_tex_base.update(_base)
			_bandes_faites[b] = true
		"etat":
			var b := int(res.bande)
			var y0 := b * BANDE
			var h := mini(_n.y, y0 + BANDE) - y0
			var img := Image.create_from_data(_n.x, h, false, Image.FORMAT_RGBA8, res.rgb)
			_etat.blit_rect(img, Rect2i(0, 0, _n.x, h), Vector2i(0, y0))
			_tex_etat.update(_etat)
		"detail":
			var px := MORCEAU * _sp
			var img := Image.create_from_data(px, px, false, Image.FORMAT_RGB8, res.rgb)
			_details[res.tuile] = ImageTexture.create_from_image(img)
			_detail_demandes.erase(res.tuile)
			for cell in res.altitudes.keys():
				main.sim.monde.carte_retenir(cell, _sp, res.altitudes[cell])   # la prochaine partie reprise n'aura plus rien à calculer


## Une tuile de détail demandée par le dessin : ses altitudes déjà retenues partent avec la demande (le fil ne lit
## pas le monde), le reste se calcule.
func _demander_detail(tuile: Vector2i) -> void:
	if _details.has(tuile) or _detail_demandes.has(tuile):
		return
	_detail_demandes[tuile] = true
	var memoires := {}
	for ly in MORCEAU:
		for lx in MORCEAU:
			var cell := tuile * MORCEAU + Vector2i(lx, ly)
			var m: PackedByteArray = main.sim.monde.carte_altitudes(cell, _sp)
			if not m.is_empty():
				memoires[cell] = m
	_file.push_front({"type": "detail", "tuile": tuile, "memoires": memoires})


# ---------------------------------------------------------------- la vue

## L'origine : la position à l'écran de la cellule (0, 0) du monde ; la cellule `centre` est au milieu de l'écran.
func _origine() -> Vector2:
	var taille := dessin.get_viewport_rect().size
	return taille * 0.5 - (Vector2(centre) + Vector2(0.5, 0.5)) * case_px + decalage


func _ecran(cell: Vector2i) -> Vector2:
	return _origine() + Vector2(cell) * case_px


func _cellule_sous(p: Vector2) -> Vector2i:
	var o := _origine()
	var c := Vector2i(int(floor((p.x - o.x) / case_px)), int(floor((p.y - o.y) / case_px)))
	if c.x < 0 or c.y < 0 or c.x >= _n.x or c.y >= _n.y:
		return Vector2i(-1, -1)
	return c


## Les cellules visibles : de c0 (incluse) à c1 (exclue), rognées au monde.
func _visibles() -> Rect2i:
	var o := _origine()
	var taille := dessin.get_viewport_rect().size
	var c0 := Vector2i(int(floor(-o.x / case_px)), int(floor(-o.y / case_px)))
	var c1 := Vector2i(int(ceil((taille.x - o.x) / case_px)), int(ceil((taille.y - o.y) / case_px)))
	c0 = Vector2i(clampi(c0.x, 0, _n.x), clampi(c0.y, 0, _n.y))
	c1 = Vector2i(clampi(c1.x, 0, _n.x), clampi(c1.y, 0, _n.y))
	return Rect2i(c0, c1 - c0)


func _dessiner() -> void:
	dessin.draw_rect(Rect2(Vector2.ZERO, dessin.size), Color(0.05, 0.05, 0.06, 1.0))
	var sim = main.sim
	if sim == null or sim.monde == null or _base == null:
		return
	var surf = sim.monde.surface
	var o := _origine()
	var vis := _visibles()
	if vis.size.x <= 0 or vis.size.y <= 0:
		return
	var sp_min: int = int(GameData.config('styles').get('carte', {}).get('sous_points_min_px', 10))
	var dest := Rect2(o + Vector2(vis.position) * case_px, Vector2(vis.size) * case_px)
	# 1. La base : une texture, la région visible.
	dessin.draw_texture_rect_region(_tex_base, dest, Rect2(Vector2(vis.position), Vector2(vis.size)))
	# 2. Le détail, de près : les tuiles prêtes par-dessus, les autres demandées.
	if case_px >= float(sp_min):
		var t0 := Vector2i(vis.position.x / MORCEAU, vis.position.y / MORCEAU)
		var t1 := Vector2i((vis.end.x - 1) / MORCEAU, (vis.end.y - 1) / MORCEAU)
		for ty in range(t0.y, t1.y + 1):
			for tx in range(t0.x, t1.x + 1):
				var tuile := Vector2i(tx, ty)
				if _details.has(tuile):
					var px := float(MORCEAU * _sp)
					dessin.draw_texture_rect_region(_details[tuile], Rect2(_ecran(tuile * MORCEAU), Vector2(MORCEAU, MORCEAU) * case_px), Rect2(Vector2.ZERO, Vector2(px, px)))
				else:
					_demander_detail(tuile)
	# 3. L'état (danger) et le voile (non exploré).
	dessin.draw_texture_rect_region(_tex_etat, dest, Rect2(Vector2(vis.position), Vector2(vis.size)))
	dessin.draw_texture_rect_region(_tex_voile, dest, Rect2(Vector2(vis.position), Vector2(vis.size)))
	# 4. Les repères : peu de choses, et seulement de près pour ce qui demande une lecture par cellule.
	var j: Dictionary = main.joueur()
	var cj: Vector2i = sim.monde.cellule_de(j.pos) if not j.is_empty() else centre
	var zoome := case_px >= float(sp_min)
	if zoome:
		for y in range(vis.position.y, vis.end.y):
			for x in range(vis.position.x, vis.end.x):
				var cell := Vector2i(x, y)
				if not surf.terre_a(cell):
					continue
				var r := Rect2(_ecran(cell), Vector2(case_px - 1.0, case_px - 1.0))
				var poi: Dictionary = surf.poi_de(cell)
				if poi.get("filon_majeur", false):
					dessin.draw_circle(r.position + Vector2(case_px * 0.5, case_px * 0.5), 3.0, Color(0.8, 0.85, 0.9))
				if not sim.monde.gouffre_de(cell).is_empty():   # le gouffre : un repère permanent, un anneau noir cerné de blanc
					var c_g := r.position + Vector2(case_px * 0.5, case_px * 0.5)
					dessin.draw_circle(c_g, case_px * 0.32, Color(0.03, 0.02, 0.05))
					dessin.draw_arc(c_g, case_px * 0.32, 0.0, TAU, 20, Color(0.95, 0.95, 1.0), 1.5)
				var c0 := r.position + Vector2(case_px * 0.5, case_px * 0.5)
				for v in surf.route_de(cell):   # les routes : un trait ocre entre cellules reliées
					var dv: Vector2i = v - cell
					dessin.draw_line(c0, c0 + Vector2(dv.x, dv.y) * case_px * 0.5, Color(0.85, 0.7, 0.4, 0.9), 2.0)
				if sim.monde.claims.has(cell):
					dessin.draw_rect(r.grow(-1), Color(0.3, 1.0, 0.4, 0.9), false, 2.0)
				elif mode == "voyage" and sim.monde.revendicable(cell, sim.horloge_monde.ticks):
					dessin.draw_rect(r.grow(-2), Color(0.3, 1.0, 0.4, 0.35), false, 1.0)
	else:
		for cell in sim.monde.claims.keys():
			if vis.has_point(cell):
				dessin.draw_rect(Rect2(_ecran(cell), Vector2(case_px, case_px)), Color(0.3, 1.0, 0.4, 0.9), false, 1.0)
	for d in _connus:   # les donjons de corruption des cellules connues : la teinte de leur élément
		var cell: Vector2i = d.cell
		if not vis.has_point(cell):
			continue
		var r := Rect2(_ecran(cell), Vector2(case_px - 1.0, case_px - 1.0))
		var tel: Dictionary = GameData.config("wuxing").get("teintes", {})
		var t_el: Array = tel.get(str(d.dc.element), [0.66, 0.2, 0.2])
		var ce := Color(float(t_el[0]), float(t_el[1]), float(t_el[2]))
		var marge := clampf(case_px * 0.12, 0.5, 2.0)
		dessin.draw_rect(Rect2(r.position + Vector2(marge, marge), r.size - Vector2(2.0 * marge, 2.0 * marge)), ce.darkened(0.35))
		dessin.draw_rect(Rect2(r.position + Vector2(marge, marge), r.size - Vector2(2.0 * marge, 2.0 * marge)), ce, false, 1.0)
		if case_px >= 16.0:
			dessin.draw_string(ThemeDB.fallback_font, r.position + Vector2(3, r.size.y - 3), str(int(d.dc.niveau)), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.9))
	for cap in _capitales:   # les capitales : un liseré doré et le nom du royaume (la carte politique se lit avant toute visite)
		var cell: Vector2i = cap.cell
		if not vis.has_point(cell):
			continue
		var r := Rect2(_ecran(cell), Vector2(case_px - 1.0, case_px - 1.0))
		dessin.draw_rect(r.grow(-2), Color(1.0, 0.95, 0.6), false, 2.0)
		if case_px >= 6.0:
			dessin.draw_string(ThemeDB.fallback_font, r.position + Vector2(-10.0, -3.0), str(cap.nom), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.95, 0.7))
	if vis.has_point(cj):
		var r := Rect2(_ecran(cj), Vector2(case_px - 1.0, case_px - 1.0))
		dessin.draw_rect(r.grow(-3), Color(0.3, 0.8, 1.0), false, 2.0)
		_placer_avatar(r)
	elif avatar != null:
		avatar.visible = false
	var bas := dessin.get_viewport_rect().size.y
	dessin.draw_string(ThemeDB.fallback_font, Vector2(20, bas - 40), tr("ui.carte.legende"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.8))
	if not _file.is_empty():
		dessin.draw_string(ThemeDB.fallback_font, Vector2(dessin.get_viewport_rect().size.x - 260, 24), tr("ui.carte.en_cours").format({"n": _file.size()}), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.65))
	# Le survol : biome, danger, royaume, dirigeant, relation.
	if survol != Vector2i(-1, -1):
		dessin.draw_string(ThemeDB.fallback_font, Vector2(20, bas - 22), _texte_survol(sim, surf), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.9, 0.7))


func _texte_survol(sim, surf) -> String:
	var info_s: Dictionary = surf.resume_cellule(survol)
	var texte := tr("ui.carte.survol").format({"x": survol.x, "y": survol.y, "biome": tr(GameData.entree("biomes", str(info_s.biome)).name_key) if info_s.terre else tr("ui.carte.mer"), "danger": int(sim.monde.danger_de(survol))})
	if info_s.terre:   # la géographie du monde (designer 2026-09-02) : région et continent, immuables
		var reg: Dictionary = surf.region_de(survol)
		texte += tr("ui.carte.survol_region").format({
			"region": str(reg.get("nom", "—")),
			"continent": str(reg.get("continent", {}).get("nom", "—"))})
		if not sim.monde.gouffre_de(survol).is_empty():
			texte += tr("ui.carte.survol_gouffre")
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
		var etat_p: Dictionary = sim.etat_royaume(str(roy_s.id))   # le pays (D) : le règne, l'ère, la population, l'humeur, la guerre
		if not etat_p.is_empty():
			var guerre_t := ""
			for autre in etat_p.get("guerres", []):
				guerre_t += tr("ui.carte.guerre").format({"autre": str(sim.royaume_par_id(str(autre)).get("nom", autre))})
			texte += tr("ui.carte.survol_pays").format({"dirigeant": str(etat_p.dirigeant), "an": sim.an_de_regne(etat_p), "ere": tr("ere.%s.name" % str(etat_p.ere)), "population": int(etat_p.population), "armee": int(etat_p.armee), "humeur": int(etat_p.humeur), "guerre": guerre_t})
	return texte


## L'avatar du joueur sur sa cellule (designer 2026-09-01, point 59) : le paperdoll du jeu, réduit, pas une pastille.
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


# ---------------------------------------------------------------- les entrées

func _entree(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		_glisse = ev.pressed   # la carte se fait glisser au bouton du milieu ou au bouton droit
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoomer(1.25 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8, ev.position)
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


## Le zoom, à la molette : la cellule sous la souris reste sous la souris.
func _zoomer(facteur: float, souris: Vector2) -> void:
	var cfg: Dictionary = GameData.config("styles").get("carte", {})
	var avant := case_px
	case_px = clampf(case_px * facteur, float(cfg.get("zoom_min_px", 3)), float(cfg.get("zoom_max_px", 40)))
	if is_equal_approx(avant, case_px):
		return
	var o := _origine()
	var monde_sous := (souris - o) / avant   # la position monde (en cellules) sous la souris, avant
	# après le zoom, on veut o' + monde_sous × case_px = souris : on ajuste le décalage
	var o_voulu := souris - monde_sous * case_px
	var taille := dessin.get_viewport_rect().size
	decalage = o_voulu - (taille * 0.5 - (Vector2(centre) + Vector2(0.5, 0.5)) * case_px)
	var pas_c := int(decalage.x / case_px)
	centre.x -= pas_c
	decalage.x -= pas_c * case_px
	var pas_l := int(decalage.y / case_px)
	centre.y -= pas_l
	decalage.y -= pas_l * case_px
	survol = Vector2i(-1, -1)
	dessin.queue_redraw()


## Touches quand la carte est ouverte : les flèches font MARCHER le joueur d'une cellule (designer, 2026-09-05 :
## « comme un vieux RPG style Dragon Quest / Final Fantasy ») ; Maj + flèches font défiler la carte ; + et − zooment ;
## Échap et Tab la ferment.
func touche(ev: InputEventKey) -> bool:
	var pas := Vector2i.ZERO
	match ev.keycode:
		KEY_ESCAPE, KEY_TAB:
			if mode != "depart":
				fermer()
			return true
		KEY_LEFT: pas = Vector2i(-1, 0)
		KEY_RIGHT: pas = Vector2i(1, 0)
		KEY_UP: pas = Vector2i(0, -1)
		KEY_DOWN: pas = Vector2i(0, 1)
		KEY_KP_ADD, KEY_EQUAL, KEY_PLUS:
			_zoomer(1.25, dessin.get_viewport_rect().size * 0.5)
			return true
		KEY_KP_SUBTRACT, KEY_MINUS:
			_zoomer(0.8, dessin.get_viewport_rect().size * 0.5)
			return true
		_:
			return false
	if ev.shift_pressed or mode == "depart":
		centre += pas * 4
		dessin.queue_redraw()
		return true
	main._pas_sur_la_carte(pas)
	return true


## Recentre la carte sur une cellule (après un pas).
func recentrer(cell: Vector2i) -> void:
	centre = cell
	decalage = Vector2.ZERO
	if ouverte:
		_refaire_voile()
	dessin.queue_redraw()
