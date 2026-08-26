extends Node2D
## Démo 0 — grille iso + hauteur + horloge à ticks.
## Aucun asset : tout est dessiné en polygones. Les règles viennent du design :
##   docs/03 - Combat/Action-time à ticks.md   (compteurs, réfléchir est gratuit)
##   docs/03 - Combat/Boucle de tick.md        (coûts, 10 ticks/s hors combat)
##   docs/02 - Monde/Hauteur de terrain ±10.md (pentes 3/5/8/∞, descente 2)

const TW := 44          # largeur d'une tuile à l'écran
const TH := 22          # hauteur du losange
const HSTEP := 9        # pixels par niveau de hauteur
const TICKS_PAR_SEC := 10.0
const PORTEE_AGGRO := 6
const DELAI_PAS := 0.12  # secondes réelles entre deux étapes de simulation (lisibilité)

var carte: DemoMap
var horloge: int = 0
var frac_explo := 0.0
var en_combat := false

# Entités : le schéma minimal — position, compteur, PV. Le joueur n'est PAS un type à part
# (Contraintes permanentes, règle 5) : la seule différence est qui décide de son action.
var entites: Array[Dictionary] = []
var joueur: Dictionary
var loup: Dictionary

var chemin_en_cours: Array[Vector2i] = []
var attaque_visee := false
var minuterie_pas := 0.0
var survol := Vector2i(-1, -1)
var journal: Array[String] = []

@onready var ui: Label = $CanvasLayer/Info


func _ready() -> void:
	carte = DemoMap.new()
	joueur = {"nom": "toi", "pos": Vector2i(4, 18), "compteur": 0, "pv": 60, "pv_max": 60,
			"couleur": Color(0.28, 0.62, 0.92), "controle": "joueur"}
	loup = {"nom": "loup", "pos": Vector2i(19, 5), "compteur": 0, "pv": 30, "pv_max": 30,
			"couleur": Color(0.85, 0.33, 0.27), "controle": "ia"}
	entites = [joueur, loup]
	position = Vector2(get_viewport_rect().size.x * 0.5, 120)
	_log("clic gauche : se déplacer · clic sur le loup adjacent : frapper (2d6, 5 ticks)")


func _log(t: String) -> void:
	journal.append(t)
	if journal.size() > 6:
		journal.pop_front()


# ---------------------------------------------------------------- simulation

func _process(delta: float) -> void:
	# Hors combat, l'horloge avance seule à 10 ticks/s (Boucle de tick).
	if not en_combat:
		frac_explo += delta * TICKS_PAR_SEC
		while frac_explo >= 1.0:
			frac_explo -= 1.0
			horloge += 1
	# En combat : 0 tick tant qu'aucune action. Réfléchir est gratuit.
	if not chemin_en_cours.is_empty() or attaque_visee:
		minuterie_pas -= delta
		if minuterie_pas <= 0.0:
			minuterie_pas = DELAI_PAS
			_pas_de_simulation()
	_maj_combat()
	_maj_ui()
	queue_redraw()


## Fait agir l'entité au plus petit compteur. Le joueur consomme sa file d'ordres.
func _pas_de_simulation() -> void:
	var suivant := joueur
	for e in entites:
		if e.pv > 0 and e.compteur < suivant.compteur:
			suivant = e
	horloge = maxi(horloge, suivant.compteur)
	if suivant.controle == "joueur":
		_action_joueur()
	else:
		_action_ia(suivant)


func _action_joueur() -> void:
	if attaque_visee and loup.pv > 0 and _adjacent(joueur.pos, loup.pos):
		attaque_visee = false
		var degats := randi_range(1, 6) + randi_range(1, 6)
		loup.pv -= degats
		joueur.compteur = horloge + 5  # épée : 10 / 2.0
		_log("tu frappes le loup : %d dégâts (5 ticks)" % degats)
		if loup.pv <= 0:
			_log("le loup tombe. L'horloge se relâche.")
		return
	attaque_visee = false
	if chemin_en_cours.is_empty():
		return
	var cible: Vector2i = chemin_en_cours[0]
	var cout := carte.cout_pas(joueur.pos, cible)
	if cout < 0:
		chemin_en_cours.clear()
		return
	chemin_en_cours.pop_front()
	joueur.pos = cible
	joueur.compteur = horloge + cout


func _action_ia(e: Dictionary) -> void:
	if not en_combat:
		e.compteur = horloge + 10  # il dort : il attend
		return
	if _adjacent(e.pos, joueur.pos):
		var degats := randi_range(1, 6) + 2
		joueur.pv = maxi(0, joueur.pv - degats)
		e.compteur = horloge + 8
		_log("le loup mord : %d dégâts (8 ticks)" % degats)
		return
	var pas := carte.chemin(e.pos, joueur.pos)
	if pas.is_empty() or pas[0] == joueur.pos:
		e.compteur = horloge + 5
		return
	var cout := carte.cout_pas(e.pos, pas[0])
	e.pos = pas[0]
	e.compteur = horloge + maxi(cout, 1)


func _maj_combat() -> void:
	var etait := en_combat
	var d: Vector2i = (loup.pos - joueur.pos).abs()
	en_combat = loup.pv > 0 and (d.x + d.y) <= PORTEE_AGGRO
	if en_combat and not etait:
		loup.compteur = horloge + 3
		_log("le loup t'a vu — COMBAT : le temps n'avance plus qu'à l'action")
	elif etait and not en_combat:
		_log("plus d'hostile — retour au temps réel (10 ticks/s)")


func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d := (a - b).abs()
	return d.x + d.y == 1


# ---------------------------------------------------------------- entrées

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		survol = _tuile_sous(get_local_mouse_position())
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var t := _tuile_sous(get_local_mouse_position())
		if t.x < 0 or joueur.pv <= 0:
			return
		if loup.pv > 0 and t == loup.pos and _adjacent(joueur.pos, loup.pos):
			attaque_visee = true
			chemin_en_cours.clear()
			return
		chemin_en_cours = carte.chemin(joueur.pos, t)
		if chemin_en_cours.is_empty() and t != joueur.pos:
			_log("inaccessible — une falaise (Δ ≥ 3) barre la route")


func _tuile_sous(p: Vector2) -> Vector2i:
	var meilleur := Vector2i(-1, -1)
	var meilleure_d := 1e9
	for y in DemoMap.TAILLE:
		for x in DemoMap.TAILLE:
			var c := _ecran(x, y, carte.h(x, y))
			var d := c.distance_squared_to(p)
			if d < meilleure_d and d < float(TW * TW) * 0.35:
				meilleure_d = d
				meilleur = Vector2i(x, y)
	return meilleur


# ---------------------------------------------------------------- rendu

func _ecran(x: int, y: int, h: int) -> Vector2:
	return Vector2((x - y) * TW * 0.5, (x + y) * TH * 0.5 - h * HSTEP)


func _draw() -> void:
	for s in range(2 * DemoMap.TAILLE - 1):          # tri de profondeur : diagonales x+y
		for x in DemoMap.TAILLE:
			var y := s - x
			if y < 0 or y >= DemoMap.TAILLE:
				continue
			_dessine_tuile(x, y)
			for e in entites:
				if e.pos.x == x and e.pos.y == y and e.pv > 0:
					_dessine_entite(e)
	if not chemin_en_cours.is_empty():
		var pts := PackedVector2Array([_ecran(joueur.pos.x, joueur.pos.y, carte.h(joueur.pos.x, joueur.pos.y))])
		for c in chemin_en_cours:
			pts.append(_ecran(c.x, c.y, carte.h(c.x, c.y)))
		draw_polyline(pts, Color(1, 1, 1, 0.55), 2.0)


func _dessine_tuile(x: int, y: int) -> void:
	var h := carte.h(x, y)
	var c := _ecran(x, y, h)
	var haut := PackedVector2Array([
		c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0),
		c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)])
	var t := clampf((h - 4) / 12.0, 0.0, 1.0)   # gradient : bas sombre, sommets clairs
	var col := Color(0.20, 0.34, 0.18).lerp(Color(0.62, 0.66, 0.42), t)
	if Vector2i(x, y) == survol:
		col = col.lightened(0.25)
	draw_colored_polygon(haut, col)
	var flanc := col.darkened(0.35)
	for voisin_h in [_h_ou(x, y + 1, h), 0]:     # flanc sud-ouest si le voisin est plus bas
		break
	var hs := _h_ou(x, y + 1, 0)
	if hs < h:
		var d := (h - hs) * HSTEP
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-TW * 0.5, 0), c + Vector2(0, TH * 0.5),
			c + Vector2(0, TH * 0.5 + d), c + Vector2(-TW * 0.5, d)]), flanc)
	var he := _h_ou(x + 1, y, 0)
	if he < h:
		var d2 := (h - he) * HSTEP
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, TH * 0.5), c + Vector2(TW * 0.5, 0),
			c + Vector2(TW * 0.5, d2), c + Vector2(0, TH * 0.5 + d2)]), flanc.darkened(0.15))


func _h_ou(x: int, y: int, defaut: int) -> int:
	return carte.h(x, y) if carte.dans_carte(x, y) else defaut


func _dessine_entite(e: Dictionary) -> void:
	var c := _ecran(e.pos.x, e.pos.y, carte.h(e.pos.x, e.pos.y))
	draw_circle(c + Vector2(0, -8), 8.0, e.couleur)
	draw_circle(c + Vector2(0, -8), 8.0, Color.BLACK, false, 1.5)
	var w := 20.0
	draw_rect(Rect2(c + Vector2(-w * 0.5, -24), Vector2(w, 3)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(c + Vector2(-w * 0.5, -24), Vector2(w * e.pv / e.pv_max, 3)), Color(0.3, 0.9, 0.3))


func _maj_ui() -> void:
	var lignes := ["SENSEN — démo 0 · grille + hauteur + horloge",
		"horloge : %d ticks · %s" % [horloge, "COMBAT (le temps n'avance qu'à l'action)" if en_combat else "exploration (10 ticks/s)"]]
	for e in entites:
		if e.pv > 0:
			lignes.append("  %-5s pv %d/%d · agit à t=%d · h=%d" % [e.nom, e.pv, e.pv_max, e.compteur, carte.h(e.pos.x, e.pos.y)])
	if survol.x >= 0:
		var dh := carte.h(survol.x, survol.y) - carte.h(joueur.pos.x, joueur.pos.y)
		lignes.append("  case (%d,%d) h=%d · Δh vs toi : %+d" % [survol.x, survol.y, carte.h(survol.x, survol.y), dh])
	lignes.append("")
	lignes.append_array(journal)
	ui.text = "\n".join(lignes)
