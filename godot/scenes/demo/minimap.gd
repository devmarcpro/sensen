class_name Minimap
extends TextureRect
## La minimap (Décision — Minimap en 2D, Minimap et brouillard de guerre) : coin haut-droit, 256×256,
## masquable, trois zooms (×1 ≈ 32 chunks visibles, ×2, ×4 — le ×4 rejoint l'échelle de la carte du
## monde). Une **teinte dominante par chunk** (matériau de sol majoritaire, eau, ombrage dérivé de la
## hauteur moyenne), un **bit d'exploration par chunk** (`explored[cx, cy]`, mis à jour sur
## `chunk_explored`, jamais de recalcul de zone), les êtres détectés en surcouche d'icônes (état live).
## Surface seulement : le donjon (un fog par étage) attend.

const TAILLE := 256
const CHUNK := 32

var main: Node
var image: Image
var zoom: int = 1                      # 1, 2, 4 : chunks visibles par côté = 32 × zoom
var derniere_cle := ""                 # évite de recalculer l'image si rien n'a bougé


func _ready() -> void:
	custom_minimum_size = Vector2(TAILLE, TAILLE)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-TAILLE - 12, 300)
	set_anchor_and_offset(SIDE_LEFT, 1.0, -TAILLE - 12)
	set_anchor_and_offset(SIDE_TOP, 0.0, 300)
	set_anchor_and_offset(SIDE_RIGHT, 1.0, -12)
	set_anchor_and_offset(SIDE_BOTTOM, 0.0, 300 + TAILLE)
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	image = Image.create(TAILLE, TAILLE, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)


func cycler_zoom() -> void:
	zoom = 2 if zoom == 1 else (4 if zoom == 2 else 1)
	derniere_cle = ""


## Redessine si le joueur a changé de chunk, si le zoom a changé, ou si un chunk vient d'être exploré.
func rafraichir(force: bool = false) -> void:
	var sim = main.sim
	if sim == null or sim.monde == null or sim.lieu != "camp" or not visible:
		return
	var j: Dictionary = main.joueur()
	if j.is_empty():
		return
	var monde = sim.monde
	var cj := Vector2i(floori(float(j.pos.x) / CHUNK), floori(float(j.pos.y) / CHUNK))
	var cle := "%d,%d,%d,%d" % [cj.x, cj.y, zoom, monde.explores.size()]
	if cle == derniere_cle and not force:
		_icones(j, cj)
		return
	derniere_cle = cle
	var n := 32 * zoom                      # chunks par côté
	var px := float(TAILLE) / float(n)      # pixels par chunk
	image.fill(Color(0.02, 0.02, 0.03))
	for dy in n:
		for dx in n:
			var ch := cj + Vector2i(dx - n / 2, dy - n / 2)
			if not monde.explores.has(ch):
				continue
			var col: Color = monde.couleur_chunk(ch)
			var r := Rect2i(int(dx * px), int(dy * px), maxi(1, int(ceil(px))), maxi(1, int(ceil(px))))
			image.fill_rect(r, col)
	_icones(j, cj)


## La surcouche : le joueur au centre, les êtres en vue en points (état live, pas de mémoire).
func _icones(j: Dictionary, cj: Vector2i) -> void:
	var sim = main.sim
	var n := 32 * zoom
	var px := float(TAILLE) / float(n)
	var img := image.duplicate()
	for e in sim.vivants():
		if e.id != j.id and not sim.voit(j, e.pos):
			continue
		var ch := Vector2i(floori(float(e.pos.x) / CHUNK), floori(float(e.pos.y) / CHUNK))
		var d := ch - cj + Vector2i(n / 2, n / 2)
		var fx: float = (float(e.pos.x) / CHUNK - floor(float(e.pos.x) / CHUNK)) * px
		var fy: float = (float(e.pos.y) / CHUNK - floor(float(e.pos.y) / CHUNK)) * px
		var p := Vector2i(int(d.x * px + fx), int(d.y * px + fy))
		if p.x < 1 or p.y < 1 or p.x >= TAILLE - 1 or p.y >= TAILLE - 1:
			continue
		var c := Color(0.3, 0.8, 1.0) if e.id == j.id else (Color(1.0, 0.3, 0.3) if e.camp != j.camp else Color(0.6, 1.0, 0.6))
		img.fill_rect(Rect2i(p.x - 1, p.y - 1, 3, 3), c)
	texture.update(img)
