class_name DialogueVisuel
extends VBoxContainer
## La carte de dialogue avec un PNJ (designer 2026-09-06, 17 h 35 : « retravaille le menu d'interaction avec un PNJ
## pour que ça ressemble à ça » — un croquis : le portrait à gauche, « Prénom NOM » en grand à sa droite, quelques
## lignes d'informations dessous, puis les options en liste lettrée a), b), c)…). La carte ne décide rien : elle lit
## `ecrans.entrees` (kind option) et `ecrans.dialogue_infos`, composés par `EcransDialogue._construire_dialogue` ; une
## lettre ou un clic sur une ligne joue l'option (`EcransDialogue._option`). Les tailles viennent de styles.json → dialogue.

var ecrans: Node
var cadre: Control            # le cadre du portrait : il rogne tout ce qui n'est pas la tête
var portrait: Paperdoll
var nom: Label
var infos: RichTextLabel
var options: VBoxContainer
var _lignes: Array = []       # les Label des options, dans l'ordre des entrées de kind option
var _pnj_portrait := ""       # l'id du PNJ dont le portrait est configuré


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var st: Dictionary = GameData.config("styles").get("dialogue", {})
	var taille := float(st.get("portrait", 170.0))
	add_theme_constant_override("separation", int(st.get("espace", 14)))
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", int(st.get("espace", 14)))
	add_child(haut)
	cadre = Control.new()
	cadre.custom_minimum_size = Vector2(taille, taille)
	cadre.clip_contents = true
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.draw.connect(func() -> void:
		cadre.draw_rect(Rect2(Vector2.ZERO, cadre.size), Color(0.13, 0.13, 0.16))
		cadre.draw_rect(Rect2(Vector2.ZERO, cadre.size), Color(0.6, 0.55, 0.4), false, 2.0))
	haut.add_child(cadre)
	portrait = Paperdoll.new()   # les mêmes réglages que le portrait de la création (point 43), à l'échelle du cadre
	portrait.scale = Vector2.ONE * (11.0 * taille / 170.0)
	portrait.position = Vector2(taille * 0.5, taille * 415.0 / 170.0)
	cadre.add_child(portrait)
	var colonne := VBoxContainer.new()
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.size_flags_vertical = Control.SIZE_EXPAND_FILL
	haut.add_child(colonne)
	nom = Label.new()
	nom.add_theme_font_size_override("font_size", int(st.get("nom_taille", 24)))
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(nom)
	infos = RichTextLabel.new()
	infos.bbcode_enabled = true
	infos.fit_content = true
	infos.scroll_active = false
	infos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	infos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	infos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	infos.add_theme_font_size_override("normal_font_size", int(st.get("infos_taille", 13)))
	colonne.add_child(infos)
	options = VBoxContainer.new()
	options.add_theme_constant_override("separation", int(st.get("espace_options", 2)))
	options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(options)


## La carte depuis l'état des écrans : le portrait et le nom du PNJ, ses informations, ses options lettrées.
func reconstruire() -> void:
	var sim = ecrans.main.sim
	var pnj: Dictionary = sim.entites.get(ecrans.pnj_id, {})
	if pnj.is_empty():
		return
	if _pnj_portrait != str(pnj.id):
		_pnj_portrait = str(pnj.id)
		var rig: Dictionary = GameData.entree("rigs", str(pnj.get("corps", {}).get("silhouette", "")))
		cadre.visible = not rig.is_empty()
		if cadre.visible:
			portrait.configurer(pnj, rig, sim.items, sim.fonctionnalites, GameData.config("palette_materiaux"))
	portrait.queue_redraw()
	nom.text = _prenom_nom(tr(str(pnj.get("name_key", ""))))
	infos.text = str(ecrans.dialogue_infos)
	var st: Dictionary = GameData.config("styles").get("dialogue", {})
	var taille_opt := int(st.get("option_taille", 15))
	for l in _lignes:
		l.queue_free()
	_lignes.clear()
	var rx := RegEx.new()   # les anciens rappels de raccourci « (P) », « (Échap) » en fin de libellé : la lettre est celle de la ligne
	rx.compile("\\s\\((?:[A-Z]|Échap|Esc)\\)$")
	for i in ecrans.entrees.size():
		var en: Dictionary = ecrans.entrees[i]
		if not (str(en.get("kind", "")) in ["option", "page"]):
			continue
		var l := Label.new()
		l.text = rx.sub(ecrans.liste.get_item_text(i), "")   # « a) Parler » : la lettre est posée par EcransListe._paginer
		l.add_theme_font_size_override("font_size", taille_opt)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		if not ecrans.liste.is_item_selectable(i):   # une option grisée (rien à ressusciter, par exemple)
			l.modulate = Color(0.6, 0.6, 0.6)
		elif i == ecrans.selection:
			l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
		var index: int = i
		l.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				ecrans.selection = index
				ecrans.liste.select(index)
				EcransListe._action_principale(ecrans))
		options.add_child(l)
		_lignes.append(l)


## « Prénom NOM » : le dernier mot du nom en capitales, comme sur le croquis du designer.
static func _prenom_nom(complet: String) -> String:
	var mots := complet.strip_edges().split(" ", false)
	if mots.size() < 2:
		return complet
	mots[mots.size() - 1] = mots[mots.size() - 1].to_upper()
	return " ".join(mots)
