class_name ApercuSort
extends Control
## L'aperçu visuel d'un sort (Écrans d'interface, décision du designer du 2026-08-30) : une grille plate vue de dessus,
## le lanceur au centre, la visée nominale à portée maximale vers le nord, les tuiles couvertes par toutes les formes
## du plan. Dessiné par code, sans asset ; la grille est virtuelle — l'aperçu montre la forme, pas le terrain.

const COTE := 17            # tuiles par côté de la grille virtuelle (impair : le lanceur au centre)
const CASE := 9.0           # pixels par tuile (assez petit pour laisser le détail lisible au composeur)

var plan: Dictionary = {}   # le plan assemblé (Capacites.assembler / Simulation.plan_sequence)
var grille_virtuelle: Grille


func _ready() -> void:
	custom_minimum_size = Vector2(COTE * CASE + 8.0, COTE * CASE + 24.0)
	grille_virtuelle = Grille.new(COTE, COTE)


func montrer(p: Dictionary) -> void:
	plan = p
	queue_redraw()


## Les tuiles couvertes par le plan sur la grille virtuelle, et combien de formes couvrent chacune.
func couverture() -> Dictionary:
	var compte := {}
	if plan.is_empty() or str(plan.get("geometrie", "")).is_empty():
		return compte
	var lanceur := Vector2i(COTE / 2, COTE / 2)
	var portee_max: int = clampi(int(plan.get("portee", Vector2i(0, 1)).y), 0, COTE / 2)
	var cible := lanceur + Vector2i(0, -maxi(1, portee_max)) if str(plan.get("origine", "cible")) == "lanceur" else lanceur + Vector2i(0, -portee_max)
	var lots: Array = [{"geometrie": str(plan.geometrie), "taille": int(plan.get("taille", 1))}]
	for f in plan.get("formes_sup", []):
		lots.append({"geometrie": str(f.geometrie), "taille": int(f.taille)})
	for lot in lots:
		for t in Capacites.tuiles_de_forme(grille_virtuelle, str(lot.geometrie), lanceur, cible, int(lot.taille)):
			if grille_virtuelle.dans(t):
				compte[t] = int(compte.get(t, 0)) + 1
	return compte


func _draw() -> void:
	var o := Vector2(4.0, 4.0)
	var fond := Color(0.06, 0.06, 0.08, 1.0)
	draw_rect(Rect2(o, Vector2(COTE * CASE, COTE * CASE)), fond)
	for k in COTE + 1:   # le quadrillage
		draw_line(o + Vector2(k * CASE, 0.0), o + Vector2(k * CASE, COTE * CASE), Color(1, 1, 1, 0.06))
		draw_line(o + Vector2(0.0, k * CASE), o + Vector2(COTE * CASE, k * CASE), Color(1, 1, 1, 0.06))
	if plan.is_empty() or str(plan.get("geometrie", "")).is_empty():
		draw_string(ThemeDB.fallback_font, o + Vector2(4.0, COTE * CASE + 14.0), tr("ui.apercu.vide"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.7, 0.7))
		return
	var lanceur := Vector2i(COTE / 2, COTE / 2)
	var portee: Vector2i = plan.get("portee", Vector2i(0, 1))
	var teinte := _couleur_element()
	var compte := couverture()
	var maxi_c := 1
	for v in compte.values():
		maxi_c = maxi(maxi_c, int(v))
	for t in compte.keys():   # les tuiles couvertes, plus foncées quand plusieurs formes se recouvrent
		var f := 0.45 + 0.55 * float(compte[t]) / float(maxi_c)
		draw_rect(Rect2(o + Vector2(t.x * CASE + 1.0, t.y * CASE + 1.0), Vector2(CASE - 2.0, CASE - 2.0)), Color(teinte.r, teinte.g, teinte.b, f))
	# L'anneau de portée (min–max), en pointillé : ce que la visée peut atteindre.
	var centre := o + Vector2((lanceur.x + 0.5) * CASE, (lanceur.y + 0.5) * CASE)
	for r in [portee.x, portee.y]:
		if r > 0 and r <= COTE / 2:
			draw_arc(centre, float(r) * CASE + CASE * 0.5, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 1.0)
	# La visée nominale (anneau blanc) et le lanceur (losange bleu).
	var portee_max: int = clampi(int(portee.y), 0, COTE / 2)
	var cible := lanceur + Vector2i(0, -portee_max) if str(plan.get("origine", "cible")) == "cible" else lanceur + Vector2i(0, -maxi(1, portee_max))
	var pc := o + Vector2((cible.x + 0.5) * CASE, (cible.y + 0.5) * CASE)
	draw_arc(pc, CASE * 0.45, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 1.5)
	var pts := PackedVector2Array([centre + Vector2(0, -CASE * 0.45), centre + Vector2(CASE * 0.45, 0), centre + Vector2(0, CASE * 0.45), centre + Vector2(-CASE * 0.45, 0)])
	draw_colored_polygon(pts, Color(0.35, 0.6, 1.0, 1.0))
	var legende: String
	if str(plan.get("geometrie", "")) == "horizon":
		legende = tr("ui.apercu.horizon")
	else:
		legende = tr("ui.apercu.tuiles").format({"n": compte.size(), "origine": tr("origine." + str(plan.get("origine", "cible"))), "portee": "%d–%d" % [portee.x, portee.y]})
	draw_string(ThemeDB.fallback_font, o + Vector2(4.0, COTE * CASE + 14.0), legende, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.8))


## La couleur de l'élément dominant du plan (wuxing.teintes), ou un ocre neutre.
func _couleur_element() -> Color:
	var els: Dictionary = plan.get("elements", {})
	var meilleur := ""
	var poids := 0.0
	for el in els.keys():
		if float(els[el]) > poids:
			poids = float(els[el])
			meilleur = str(el)
	var teintes: Dictionary = GameData.config("wuxing").get("teintes", {})
	if not meilleur.is_empty() and teintes.has(meilleur):
		var t: Variant = teintes[meilleur]
		if t is String:
			return Color.html(str(t))
		if t is Array and t.size() >= 3:
			return Color(float(t[0]), float(t[1]), float(t[2]))
	return Color(0.85, 0.65, 0.3)
