class_name PluieVisuelle
extends Node2D
## Traits de pluie (Météo, 2026-08-31) : les états à effet « arrose » se voient — traits obliques
## animés au-dessus du monde et des êtres (sous le HUD), densité double et voile sombre sous l'orage.
## Dessin par code, coordonnées écran (la scène principale n'est pas déplacée : la caméra vit dans les couches).

var proprio: Node2D   # la scène principale (main.gd)
var densite := 0      # 0 : rien · 1 : pluie · 2 : orage


func _process(_delta: float) -> void:
	var d := 0
	if proprio != null and proprio.get("sim") != null and proprio.sim.lieu == "camp" and proprio.sim.monde != null:
		var j: Dictionary = proprio.joueur()
		if not j.is_empty():
			var etat := str(proprio.sim.meteo(proprio.sim.monde.cellule_de(j.pos)))
			if "arrose" in GameData.catalogues.weather_states.get(etat, {}).get("effects", []):
				d = 2 if etat == "orage" else 1
	if d != densite or d > 0:   # animée : on redessine chaque image tant qu'il pleut
		densite = d
		queue_redraw()


func _draw() -> void:
	if densite <= 0:
		return
	var r := get_viewport_rect()
	var t := Time.get_ticks_msec() / 1000.0
	if densite >= 2:   # l'orage assombrit légèrement la scène
		draw_rect(Rect2(Vector2(-40, -40), r.size + Vector2(80, 80)), Color(0.05, 0.06, 0.10, 0.10))
	var n := 90 * densite
	for k in n:   # traits pseudo-aléatoires portés par le temps : aucun état à stocker, rien à mettre à jour
		var derive := 40.0 + fmod(float(k) * 37.7, 30.0)
		var chute := 520.0 + fmod(float(k) * 53.3, 160.0)
		var gx := fmod(float(k) * 127.31 + t * derive, r.size.x + 80.0) - 40.0
		var gy := fmod(float(k) * 311.17 + t * chute, r.size.y + 60.0) - 30.0
		draw_line(Vector2(gx, gy), Vector2(gx - 4.0, gy + 12.0), Color(0.62, 0.70, 0.86, 0.32 if densite == 1 else 0.42), 1.0)
