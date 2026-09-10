class_name BandeauJournal
extends CanvasLayer
## LE REFUS VISIBLE (ordre de travail 39, 2026-09-09 : « aujourd\'hui il part au journal, que le panneau recouvre »).
##
## Un refus — *on ne peut pas creuser ça*, *le coffre est plein*, *il faudrait un atelier* — s'écrit dans le journal
## du bas, et un écran ouvert le cache. Le joueur clique, rien ne se passe, et **rien ne lui dit pourquoi**.
##
## Ce bandeau montre la dernière ligne du journal, en grand, au centre bas, et l'efface en quelques secondes. Il est
## monté **après les écrans** sur la couche d'interface : il passe donc par-dessus un panneau ouvert, ce qui est
## exactement le cas que la ligne visait. *Un message qu'on ne peut pas voir n'a pas été dit.*

var texte := ""
var reste := 0.0

## IL LUI FAUT SA PROPRE COUCHE, ET LA SONDE L A DIT AVANT MOI. Le premier jet etait un `Control` monte sur la
## couche du HUD ; or les ecrans sont un `CanvasLayer` a `layer = 10`, qui passe par-dessus TOUTE la couche du HUD
## quel que soit l ordre des enfants. Le bandeau serait donc reste sous le panneau — exactement le defaut que la
## ligne 39 corrige. Il est sur `layer = 20` : au-dessus des ecrans, sous rien.
var toile: Control

func _ready() -> void:
	layer = 20
	toile = Control.new()
	toile.set_anchors_preset(Control.PRESET_FULL_RECT)
	toile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toile.draw.connect(_dessiner)
	add_child(toile)
	set_process(true)


## Une ligne à montrer. La même deux fois de suite remet le compteur à zéro — insister est une information.
func montrer(t: String) -> void:
	if t.strip_edges().is_empty():
		return
	texte = t
	reste = float(GameData.config("styles").get("journal", {}).get("bandeau_s", 3.5))
	toile.queue_redraw()


func _process(delta: float) -> void:
	if reste <= 0.0:
		return
	reste -= delta
	toile.queue_redraw()


func _dessiner() -> void:
	if reste <= 0.0 or texte.is_empty():
		return
	var st: Dictionary = GameData.config("styles").get("journal", {})
	var duree := maxf(0.2, float(st.get("bandeau_s", 3.5)))
	var a := clampf(reste / (duree * 0.35), 0.0, 1.0)   # plein, puis il s'efface sur le dernier tiers
	var f := ThemeDB.fallback_font
	var taille := int(st.get("bandeau_police", 16))
	var l := f.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille)
	var ecran := toile.size
	var centre := Vector2(ecran.x * 0.5, ecran.y - float(st.get("bandeau_bas", 150.0)))
	var boite := Rect2(centre - Vector2(l.x * 0.5 + 12.0, l.y + 6.0), Vector2(l.x + 24.0, l.y + 12.0))
	toile.draw_rect(boite, Color(0.06, 0.05, 0.04, 0.86 * a))
	toile.draw_rect(boite, Color(0.85, 0.72, 0.35, 0.9 * a), false, 1.0)
	toile.draw_string(f, centre - Vector2(l.x * 0.5, 0.0), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(0.98, 0.94, 0.82, a))
