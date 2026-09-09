class_name MenuContexte
extends PanelContainer
## LA PETITE FENÊTRE DU CLIC DROIT (designer 2026-09-09 : « je veux que le menu qui s'affiche quand on fait clique
## droit n'importe où soit une petite fenêtre qui s'affiche là où on a cliqué avec les options, plusieurs pages si
## nécessaire »).
##
## **Elle remplace un écran plein cadre par une fenêtre de la taille de son contenu.** Le clic droit ouvrait
## jusqu'ici l'écran « contexte » — panneau entier, colonne de détail, voile noir — pour trois options qui tiennent
## dans un timbre-poste ; il couvrait justement la tuile qu'on venait de désigner.
##
## **Elle garde les conventions du dépôt, parce qu'elles sont ce qui rend l'interface apprenable** : une option =
## une lettre, `z)` pour la page suivante, Échap pour fermer, et tout se joue aussi bien à la souris qu'au clavier.
##
## Elle ne décide rien : `main` lui donne des options et un rappel (`sur_choix`), elle rend celle qu'on a prise.

var main: Node
var sur_choix: Callable = Callable()
var options: Array = []
var page := 0
var curseur := 0                    # la ligne pointée : les flèches la déplacent, Entrée la joue

var colonne: VBoxContainer
var titre: Label
var _boutons: Array = []


func _ready() -> void:
	visible = false
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	var st: Dictionary = GameData.config("styles").get("menu_contexte", {})
	custom_minimum_size = Vector2(float(st.get("largeur", 210.0)), 0.0)
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color(0.08, 0.08, 0.10, 0.96)
	fond.border_color = Color(0.55, 0.5, 0.35)
	fond.set_border_width_all(1)
	fond.set_content_margin_all(6)
	add_theme_stylebox_override("panel", fond)
	colonne = VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 1)
	add_child(colonne)
	titre = Label.new()
	titre.add_theme_font_size_override("font_size", 11)
	titre.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	colonne.add_child(titre)


func _lignes_par_page() -> int:
	return maxi(2, int(GameData.config("styles").get("menu_contexte", {}).get("lignes_par_page", 8)))


## Ouvrir la fenêtre AU POINT CLIQUÉ, sur ces options-là. `ou` est en coordonnées d'écran.
func ouvrir(opts: Array, ou: Vector2, texte_titre: String) -> void:
	options = opts
	page = 0
	curseur = 0
	titre.text = texte_titre
	visible = true
	_reconstruire()
	_poser(ou)


func fermer() -> void:
	visible = false
	options = []


## LA FENÊTRE NE SORT JAMAIS DE L'ÉCRAN. Elle s'ouvre au point cliqué, puis se replie vers l'intérieur si elle
## déborde — un menu ouvert au coin bas-droit remonte et rentre au lieu de se couper.
func _poser(ou: Vector2) -> void:
	# ON DEMANDE SA TAILLE AU PANNEAU, ON NE L'ESTIME PAS. La première version calculait « largeur minimale, plus
	# vingt pixels par ligne » : une option au libellé long élargit le bouton bien au-delà du minimum, et la fenêtre
	# ouverte au coin bas-droit sortait de l'écran de cinquante pixels. La sonde l'a levée à la seconde même.
	size = Vector2.ZERO
	var taille := get_combined_minimum_size()
	var ecran := get_viewport_rect().size
	position = Vector2(clampf(ou.x, 0.0, maxf(0.0, ecran.x - taille.x)), clampf(ou.y, 0.0, maxf(0.0, ecran.y - taille.y)))
	size = taille


## Une page de lignes, chacune lettrée, plus « z) Page suivante » quand il en reste.
func _reconstruire() -> void:
	for b in _boutons:
		colonne.remove_child(b)
		b.queue_free()
	_boutons.clear()
	var par_page := _lignes_par_page()
	var n_pages := maxi(1, int(ceil(float(options.size()) / float(par_page))))
	page = posmod(page, n_pages)
	var debut := page * par_page
	for k in range(debut, mini(options.size(), debut + par_page)):
		var opt: Dictionary = options[k]
		_ajouter(char(97 + (k - debut)) + ") " + main.tr("option." + str(opt.id)), k)
	if n_pages > 1:
		_ajouter("z) " + main.tr("ui.ecran.page_suivante").format({"n": page + 1, "total": n_pages}), -1)
	curseur = clampi(curseur, 0, maxi(0, _boutons.size() - 1))
	_surligner()


## LA LIGNE POINTÉE SE VOIT. Le titre promet « Entrée : choisir » depuis toujours : sans curseur, cette promesse
## était fausse dans une fenêtre où l'on ne peut que taper une lettre.
func _surligner() -> void:
	for k in _boutons.size():
		_boutons[k].modulate = Color(1.0, 0.95, 0.75) if k == curseur else Color(0.82, 0.80, 0.75)


func _ajouter(texte: String, k: int) -> void:
	var b := Button.new()
	b.text = texte
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 20)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(func() -> void: _prendre(k))
	colonne.add_child(b)
	_boutons.append(b)


## Prendre une ligne : `-1` est la page suivante, tout le reste est une option.
func _prendre(k: int) -> void:
	if k < 0:
		page += 1
		_reconstruire()
		return
	if k >= options.size():
		return
	var opt: Dictionary = options[k]
	fermer()
	if sur_choix.is_valid():
		sur_choix.call(opt)


## LE CLAVIER JOUE LA MÊME FENÊTRE : la lettre prend sa ligne, Échap ferme. On consomme l'événement pour que la
## touche ne parte pas aussi au personnage — « D » est une lettre d'option ET un pas vers la droite.
func _input(ev: InputEvent) -> void:
	if not visible or not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	if ev.keycode == KEY_ESCAPE:
		fermer()
		get_viewport().set_input_as_handled()
		return
	if ev.keycode == KEY_UP or ev.keycode == KEY_DOWN:
		curseur = posmod(curseur + (1 if ev.keycode == KEY_DOWN else -1), maxi(1, _boutons.size()))
		_surligner()
		get_viewport().set_input_as_handled()
		return
	if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
		if curseur >= 0 and curseur < _boutons.size():
			_boutons[curseur].emit_signal("pressed")
		get_viewport().set_input_as_handled()
		return
	if ev.keycode == KEY_Z:
		if _boutons.size() > 0 and str(_boutons[_boutons.size() - 1].text).begins_with("z)"):
			_prendre(-1)
			get_viewport().set_input_as_handled()
		return
	var rang := int(ev.keycode) - KEY_A
	if rang < 0 or rang >= _lignes_par_page():
		return
	var k := page * _lignes_par_page() + rang
	if k < options.size() and rang < _boutons.size():
		_prendre(k)
		get_viewport().set_input_as_handled()


## Un clic HORS de la fenêtre la ferme, comme n'importe quel menu contextuel. `main` l'appelle avant de traiter le
## clic : la fenêtre elle-même ne voit que ce qui la touche.
func hors_de(p: Vector2) -> bool:
	return not Rect2(position, size).has_point(p)
