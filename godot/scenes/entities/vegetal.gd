class_name Vegetal
extends Node2D
## Un végétal récoltable en **billboard** (Direction artistique : « personnages en billboards
## paperdoll » — les arbres et les plantes aussi, décision du designer du 2026-08-28). Dessiné par code,
## sans asset : une silhouette de `data/vegetaux/` (feuillu, conifère, buisson, herbe, palme…) teintée
## par le matériau de l'essence (palette). Trié en profondeur avec les êtres (z = x + y).

var fiche: Dictionary = {}          # data/vegetaux/<id>
var couleur := Color(0.3, 0.5, 0.2)
var tronc := Color(0.4, 0.28, 0.16)
var graine: int = 0                 # petites variations déterministes par tuile


func configurer(id_vegetal: String, p_fiche: Dictionary, materiau: Dictionary, p_graine: int) -> void:
	fiche = p_fiche
	graine = p_graine
	couleur = Color.html(str(fiche.get("couleur_feuillage", "#3f6f2a")))
	if not materiau.is_empty():
		var c := Color.html(str(materiau.color))
		tronc = c.darkened(0.2)
	queue_redraw()


## UN VÉGÉTAL EST UNE TEXTURE CUITE (ordre de travail 45 ter, 2026-09-13). La ventilation des appels de dessin (`capture
## -- --appels`) l'a dit sans ambiguïté : dans une ville, les végétaux faisaient **812 appels sur 1 435** — un par
## cercle, un par polygone, parce qu'une commande de polygone ne se regroupe avec aucune autre. Ni la teinte (modulate)
## ni la profondeur (z_index) n'y étaient pour rien : les deux essais n'ont pas retiré un appel. Dessinés en un seul
## rectangle, les mêmes végétaux tombaient à 622 appels, et le rendu CPU de 3,6 à 0,9 ms.
## **Le dessin ne change pas** : la silhouette est tracée par le MÊME code, une fois par essence, variante et teintes,
## dans un petit viewport qui ne rend qu'une image ; chaque arbre pose ensuite cette texture à sa taille. Les tailles
## restent continues (tirées par tuile, comme avant) ; seule la forme de l'herbe se tire parmi `VARIANTES`.
## Sans écran (les tests) : on dessine directement, comme avant — il n'y a rien à cuire.
const VARIANTES := 4
const PIXELS_PAR_UNITE := 4.0
static var _cuissons: Dictionary = {}   # clé → SubViewport
static var _atelier: Node = null


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var fh := rng.randf_range(0.85, 1.15)
	var fl := rng.randf_range(0.85, 1.15)
	var h0 := float(fiche.get("hauteur", 36))
	var l0 := float(fiche.get("largeur", 22))
	var vp := _cuisson(posmod(graine, VARIANTES), h0, l0)
	if vp == null or not vp.is_inside_tree() or Engine.get_frames_drawn() < int(vp.get_meta("pret_a", 0)):
		silhouette(self, fiche, couleur, tronc, h0 * fh, l0 * fl, rng)   # la première image, ou sans écran : le dessin direct
		if vp != null and _atelier != null and is_instance_valid(_atelier):
			(_atelier as _Atelier).attendre(self)   # redessiné par l'atelier quand sa texture sera peinte
		return
	var b: Rect2 = vp.get_meta("boite")   # la boîte de la silhouette, en unités, à la taille de base
	draw_texture_rect(vp.get_texture(), Rect2(Vector2(b.position.x * fl, b.position.y * fh), Vector2(b.size.x * fl, b.size.y * fh)), false)


## La cuisson d'une essence : un viewport transparent qui dessine la silhouette une fois. Rangé par essence, variante et
## teintes — deux chênes du même bois partagent la même texture.
func _cuisson(variante: int, h0: float, l0: float) -> SubViewport:
	if DisplayServer.get_name() == "headless":
		return null
	var cle := "%s|%d|%s|%s" % [str(fiche.get("silhouette", "feuillu")) + "/" + str(h0) + "x" + str(l0), variante, couleur.to_html(), tronc.to_html()]
	if _cuissons.has(cle):
		var deja: SubViewport = _cuissons[cle]
		if is_instance_valid(deja):
			return deja
	if _atelier == null or not is_instance_valid(_atelier):
		_atelier = _Atelier.new()
		_atelier.name = "AtelierVegetaux"
		Engine.get_main_loop().root.add_child.call_deferred(_atelier)
	var demi := maxf(l0 * 0.62, l0 * 0.4 + 6.0) + 2.0
	var haut := maxf(h0, maxf(h0 * 0.65 + l0 * 0.47, maxf(h0 * 0.7 + l0 * 0.62, h0 * 0.45 + l0 * 0.31))) + 4.0
	var bas := 6.0
	var boite := Rect2(-demi, -haut, demi * 2.0, haut + bas)
	var vp := SubViewport.new()
	vp.size = Vector2i(ceili(boite.size.x * PIXELS_PAR_UNITE), ceili(boite.size.y * PIXELS_PAR_UNITE))
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.set_meta("boite", boite)
	var toile := _Toile.new()
	toile.fiche = fiche
	toile.couleur = couleur
	toile.tronc = tronc
	toile.h = h0
	toile.l = l0
	toile.variante = variante
	toile.position = -boite.position * PIXELS_PAR_UNITE
	toile.scale = Vector2(PIXELS_PAR_UNITE, PIXELS_PAR_UNITE)
	vp.add_child(toile)
	_atelier.add_child.call_deferred(vp)
	# UNE IMAGE PLUS TARD, la texture est peinte : avant, elle est vide, et l'arbre se dessine directement.
	vp.set_meta("pret_a", Engine.get_frames_drawn() + 3)   # quelques images plus tard, la texture est peinte
	_cuissons[cle] = vp
	return vp


## L'atelier tient les cuissons et redessine, une fois la texture peinte, les arbres qui l'attendaient. Il les tient
## par référence FAIBLE : un arbre libéré entre-temps (la fenêtre a glissé) ne doit plus être appelé — un appel différé
## sur un nœud libéré faisait tomber le moteur (2026-09-13).
class _Atelier extends Node:
	var _attente: Array = []

	func attendre(v: Node) -> void:
		if _attente.size() < 20000:
			_attente.append(weakref(v))

	func _process(_delta: float) -> void:
		if _attente.is_empty():
			return
		var restent: Array = []
		for w in _attente:
			var v: Object = w.get_ref()
			if v == null or not is_instance_valid(v):
				continue
			(v as CanvasItem).queue_redraw()
		_attente = restent


class _Toile extends Node2D:
	var fiche: Dictionary
	var couleur: Color
	var tronc: Color
	var h: float
	var l: float
	var variante: int

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = variante
		Vegetal.silhouette(self, fiche, couleur, tronc, h, l, rng)


## La silhouette d'un végétal, tracée sur n'importe quelle toile : l'arbre lui-même (sans écran) ou sa cuisson.
static func silhouette(ci: CanvasItem, fiche: Dictionary, couleur: Color, tronc: Color, h: float, l: float, rng: RandomNumberGenerator) -> void:
	var ombre := Color(0, 0, 0, 0.22)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-l * 0.5, 0), Vector2(0, -4), Vector2(l * 0.5, 0), Vector2(0, 4)]), ombre)
	match str(fiche.get("silhouette", "feuillu")):
		"feuillu":
			ci.draw_rect(Rect2(-2.5, -h * 0.45, 5, h * 0.45), tronc)
			var c := Vector2(0, -h * 0.65)
			ci.draw_circle(c + Vector2(-l * 0.22, l * 0.1), l * 0.32, couleur.darkened(0.15))
			ci.draw_circle(c + Vector2(l * 0.22, l * 0.08), l * 0.32, couleur.darkened(0.08))
			ci.draw_circle(c + Vector2(0, -l * 0.1), l * 0.36, couleur)
			ci.draw_arc(c + Vector2(0, -l * 0.1), l * 0.36, 0.0, TAU, 20, couleur.darkened(0.5), 1.0)
		"conifere":
			ci.draw_rect(Rect2(-2, -h * 0.25, 4, h * 0.25), tronc)
			for k in 3:
				var y := -h * (0.25 + 0.25 * k)
				var w := l * (0.5 - 0.12 * k)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-w, y + h * 0.18), Vector2(0, y - h * 0.16), Vector2(w, y + h * 0.18)]), couleur.darkened(0.06 * k))
		"buisson":
			ci.draw_circle(Vector2(-l * 0.2, -h * 0.25), l * 0.28, couleur.darkened(0.1))
			ci.draw_circle(Vector2(l * 0.2, -h * 0.25), l * 0.28, couleur)
			ci.draw_circle(Vector2(0, -h * 0.45), l * 0.3, couleur.lightened(0.05))
		"herbe":
			for k in 5:
				var x := -l * 0.4 + l * 0.2 * k
				ci.draw_line(Vector2(x, 0), Vector2(x + rng.randf_range(-4, 4), -h * rng.randf_range(0.6, 1.0)), couleur, 2.0)
		"palme":
			ci.draw_rect(Rect2(-2, -h * 0.7, 4, h * 0.7), tronc)
			for k in 6:
				var a := -PI * 0.5 + (k - 2.5) * 0.45
				ci.draw_line(Vector2(0, -h * 0.7), Vector2(0, -h * 0.7) + Vector2(cos(a), sin(a)) * l * 0.6, couleur, 3.0)
		_:
			ci.draw_rect(Rect2(-l * 0.25, -h, l * 0.5, h), couleur)
