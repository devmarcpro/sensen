class_name Minimap
extends TextureRect
## La minimap (Minimap et brouillard de guerre — designer, 2026-08-30) : **la cellule où est le joueur, rien d'autre**,
## 128 × 128 px en haut à droite (2 px par tuile d'une cellule de 64). Chaque tuile découverte a sa teinte (eau,
## mur ou roche, végétation, sol du matériau), le reste reste noir ; le joueur et les êtres en vue en points.
## Fonctionne au camp comme en donjon (un étage = une cellule).

const TAILLE := 128

var main: Node
var image: Image
var derniere_cle := ""                 # évite de recalculer l'image si rien n'a bougé


func _ready() -> void:
	custom_minimum_size = Vector2(TAILLE, TAILLE)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	set_anchor_and_offset(SIDE_LEFT, 1.0, -TAILLE - 12)
	set_anchor_and_offset(SIDE_TOP, 0.0, 12)
	set_anchor_and_offset(SIDE_RIGHT, 1.0, -12)
	set_anchor_and_offset(SIDE_BOTTOM, 0.0, 12 + TAILLE)
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	image = Image.create(TAILLE, TAILLE, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)


func cycler_zoom() -> void:
	pass   # plus de zoom : la minimap est la cellule, toujours à la même échelle


## La cellule du joueur : son coin (en tuiles monde) et sa taille.
func _cellule(j: Dictionary) -> Rect2i:
	var sim = main.sim
	var taille: int = int(GameData.config("planete").taille_cellule)
	if sim.lieu == "camp" and sim.monde != null:
		var c: Vector2i = sim.monde.cellule_de(j.pos)
		return Rect2i(c * taille, Vector2i(taille, taille))
	return Rect2i(sim.grille.origine, Vector2i(sim.grille.largeur, sim.grille.hauteur_grille))   # donjon, arène : la grille entière


## Redessine si le joueur a changé de cellule ou découvert des tuiles ; sinon seules les icônes bougent.
func rafraichir(force: bool = false) -> void:
	var sim = main.sim
	if sim == null or not visible:
		return
	var j: Dictionary = main.joueur()
	if j.is_empty():
		return
	var g = sim.grille
	var cell := _cellule(j)
	var cle := "%s,%d,%s" % [str(cell.position), g.decouvert.size(), sim.lieu]
	if cle == derniere_cle and not force:
		_icones(j, cell)
		return
	derniere_cle = cle
	var px := float(TAILLE) / float(maxi(cell.size.x, cell.size.y))
	image.fill(Color(0.02, 0.02, 0.03))
	var mats: Dictionary = GameData.catalogues.materials
	for dy in cell.size.y:
		for dx in cell.size.x:
			var t: Vector2i = cell.position + Vector2i(dx, dy)
			if not g.dans(t) or not g.decouvert.has(g.idx(t)):
				continue
			var col := Color(0.35, 0.3, 0.22)
			var ct: Dictionary = g.contenu_de(t)
			var tags: Array = ct.get("tags", [])
			if "liquide" in tags or g.niveau_liquide(t) > 0:
				col = Color(0.2, 0.4, 0.7)
			elif "vegetation" in tags:
				col = Color(0.2, 0.45, 0.2)
			elif g.bloque_passage(t):
				col = Color(0.5, 0.5, 0.52) if "mur" in tags else Color(0.42, 0.4, 0.38)
			elif "porte" in tags:
				col = Color(0.7, 0.5, 0.25)
			else:
				var sol: String = g.materiau_sol(t)
				if not sol.is_empty() and mats.has(sol):
					col = Color.html(str(mats[sol].color)).darkened(0.2)
				var k := clampf((g.h(t) - 4) / 12.0, 0.0, 1.0)   # plus haut, plus clair
				col = col.lightened(k * 0.25)
			image.fill_rect(Rect2i(int(dx * px), int(dy * px), maxi(1, int(ceil(px))), maxi(1, int(ceil(px)))), col)
	_icones(j, cell)


## La surcouche : le joueur, puis les êtres en vue en points (état live, pas de mémoire).
func _icones(j: Dictionary, cell: Rect2i) -> void:
	var sim = main.sim
	var px := float(TAILLE) / float(maxi(cell.size.x, cell.size.y))
	var img := image.duplicate()
	for e in sim.vivants():
		if e.id != j.id and not sim.voit(j, e.pos):
			continue
		var d: Vector2i = e.pos - cell.position
		var p := Vector2i(int(d.x * px), int(d.y * px))
		if p.x < 1 or p.y < 1 or p.x >= TAILLE - 1 or p.y >= TAILLE - 1:
			continue
		var c := Color(0.3, 0.8, 1.0) if e.id == j.id else (Color(1.0, 0.3, 0.3) if sim.ennemis(j, e) else Color(0.6, 1.0, 0.6))
		img.fill_rect(Rect2i(p.x - 1, p.y - 1, 3, 3), c)
	texture.update(img)
