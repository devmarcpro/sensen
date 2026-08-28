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


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var h: float = float(fiche.get("hauteur", 36)) * rng.randf_range(0.85, 1.15)
	var l: float = float(fiche.get("largeur", 22)) * rng.randf_range(0.85, 1.15)
	var ombre := Color(0, 0, 0, 0.22)
	draw_colored_polygon(PackedVector2Array([Vector2(-l * 0.5, 0), Vector2(0, -4), Vector2(l * 0.5, 0), Vector2(0, 4)]), ombre)
	match str(fiche.get("silhouette", "feuillu")):
		"feuillu":
			draw_rect(Rect2(-2.5, -h * 0.45, 5, h * 0.45), tronc)
			var c := Vector2(0, -h * 0.65)
			draw_circle(c + Vector2(-l * 0.22, l * 0.1), l * 0.32, couleur.darkened(0.15))
			draw_circle(c + Vector2(l * 0.22, l * 0.08), l * 0.32, couleur.darkened(0.08))
			draw_circle(c + Vector2(0, -l * 0.1), l * 0.36, couleur)
			draw_arc(c + Vector2(0, -l * 0.1), l * 0.36, 0.0, TAU, 20, couleur.darkened(0.5), 1.0)
		"conifere":
			draw_rect(Rect2(-2, -h * 0.25, 4, h * 0.25), tronc)
			for k in 3:
				var y := -h * (0.25 + 0.25 * k)
				var w := l * (0.5 - 0.12 * k)
				draw_colored_polygon(PackedVector2Array([Vector2(-w, y + h * 0.18), Vector2(0, y - h * 0.16), Vector2(w, y + h * 0.18)]), couleur.darkened(0.06 * k))
		"buisson":
			draw_circle(Vector2(-l * 0.2, -h * 0.25), l * 0.28, couleur.darkened(0.1))
			draw_circle(Vector2(l * 0.2, -h * 0.25), l * 0.28, couleur)
			draw_circle(Vector2(0, -h * 0.45), l * 0.3, couleur.lightened(0.05))
		"herbe":
			for k in 5:
				var x := -l * 0.4 + l * 0.2 * k
				draw_line(Vector2(x, 0), Vector2(x + rng.randf_range(-4, 4), -h * rng.randf_range(0.6, 1.0)), couleur, 2.0)
		"palme":
			draw_rect(Rect2(-2, -h * 0.7, 4, h * 0.7), tronc)
			for k in 6:
				var a := -PI * 0.5 + (k - 2.5) * 0.45
				draw_line(Vector2(0, -h * 0.7), Vector2(0, -h * 0.7) + Vector2(cos(a), sin(a)) * l * 0.6, couleur, 3.0)
		_:
			draw_rect(Rect2(-l * 0.25, -h, l * 0.5, h), couleur)
