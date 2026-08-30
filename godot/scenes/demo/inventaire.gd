class_name InventaireVisuel
extends HBoxContainer
## L'inventaire visuel (Écrans d'interface — designer, 2026-08-30) : à gauche l'**avatar** (le paperdoll du jeu, avec
## ce qu'il porte) entouré de ses **slots d'équipement** en cases, dessous le **sac** en grille d'icônes ; le détail et le
## Wu Xing de l'objet restent à droite (Ecrans). Il ne décide rien : il lit `ecrans.entrees` / `ecrans.selection` et
## ne fait que sélectionner ; les actions (équiper, jeter…) restent celles de l'écran.

const CASE := Vector2(52, 52)
const CARTE := Vector2(58, 72)

var ecrans: Node
var cadre_avatar: Control
var avatar: Paperdoll
var cases: Dictionary = {}        # slot → CaseSlot
var grille: GridContainer
var defilement: ScrollContainer
var cartes: Array = []


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	var gauche := VBoxContainer.new()   # l'avatar et ses slots
	gauche.custom_minimum_size = Vector2(240, 0)
	add_child(gauche)
	cadre_avatar = Control.new()
	cadre_avatar.custom_minimum_size = Vector2(240, 300)
	cadre_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauche.add_child(cadre_avatar)
	avatar = Paperdoll.new()
	avatar.scale = Vector2(3.0, 3.0)
	avatar.position = Vector2(120, 250)
	cadre_avatar.add_child(avatar)
	# Les cases, autour du personnage : main principale et casque à gauche… placement fixe dans le cadre.
	var places := {"casque": Vector2(4, 8), "amulette": Vector2(4, 68), "cuirasse": Vector2(4, 128), "jambieres": Vector2(4, 188),
		"main_principale": Vector2(184, 8), "main_secondaire": Vector2(184, 68), "anneau_1": Vector2(184, 128), "anneau_2": Vector2(184, 188), "carquois": Vector2(94, 244)}
	for slot in places.keys():
		var c := CaseSlot.new()
		c.inventaire = self
		c.slot = slot
		c.position = places[slot]
		cadre_avatar.add_child(c)
		cases[slot] = c
	var milieu := VBoxContainer.new()   # le sac
	milieu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	milieu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(milieu)
	var etiquette := Label.new()
	etiquette.text = tr("ui.ecran.sac")
	etiquette.add_theme_font_size_override("font_size", 12)
	milieu.add_child(etiquette)
	defilement = ScrollContainer.new()
	defilement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	milieu.add_child(defilement)
	grille = GridContainer.new()
	grille.columns = 5
	grille.add_theme_constant_override("h_separation", 6)
	grille.add_theme_constant_override("v_separation", 6)
	grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(grille)
	resized.connect(_colonnes)


func _colonnes() -> void:
	if grille != null and defilement != null:
		grille.columns = maxi(2, int(defilement.size.x / (CARTE.x + 6.0)))


## Reconstruit depuis `ecrans.entrees` : les slots (kind objet/equipe ou texte « slot vide »), puis le sac.
func reconstruire() -> void:
	var sim = ecrans.main.sim
	var j: Dictionary = ecrans.main.joueur()
	if j.is_empty():
		return
	avatar.configurer(j, GameData.entree("rigs", str(j.get("skeleton_template", "humanoide"))), sim.items, sim.fonctionnalites, GameData.config("palette_materiaux"))
	avatar.queue_redraw()
	for ch in grille.get_children():
		ch.queue_free()
	cartes.clear()
	for c in cases.values():
		c.uid = ""
		c.index = -1
	var k := 0
	for en in ecrans.entrees:
		var kind := str(en.get("kind", ""))
		if kind == "objet" and bool(en.get("equipe", false)):
			var slot := str(en.slot)
			if cases.has(slot):
				cases[slot].uid = str(en.uid)
				cases[slot].index = k
		elif kind == "objet":
			var carte := CarteObjet.new()
			carte.inventaire = self
			carte.uid = str(en.uid)
			carte.index = k
			grille.add_child(carte)
			cartes.append(carte)
		elif kind == "texte" and k < 9:   # un slot vide : la case k correspond à l'ordre des slots de l'écran
			var slots_ordre: Array = ["main_principale", "main_secondaire", "casque", "cuirasse", "jambieres", "anneau_1", "anneau_2", "amulette", "carquois"]
			cases[slots_ordre[k]].index = k
		k += 1
	_colonnes()
	rafraichir_selection()


func rafraichir_selection() -> void:
	for c in cases.values():
		c.queue_redraw()
	for c in cartes:
		c.queue_redraw()


func selectionner(index: int) -> void:
	if index < 0 or index >= ecrans.entrees.size():
		return
	ecrans.selection = index
	if ecrans.liste.item_count > index:
		ecrans.liste.select(index)
	ecrans._montrer_detail()
	rafraichir_selection()


## Une case d'équipement : le slot, l'objet porté (icône) ou rien.
class CaseSlot extends Control:
	var inventaire: InventaireVisuel
	var slot := ""
	var uid := ""
	var index := -1
	var survolee := false

	func _ready() -> void:
		custom_minimum_size = InventaireVisuel.CASE
		size = InventaireVisuel.CASE
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = tr("slot." + slot)
		mouse_entered.connect(func() -> void: survolee = true; queue_redraw())
		mouse_exited.connect(func() -> void: survolee = false; queue_redraw())

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, InventaireVisuel.CASE)
		var choisie: bool = index >= 0 and inventaire.ecrans.selection == index
		draw_rect(r, Color(0.1, 0.1, 0.13, 0.95))
		draw_rect(r, Color(1, 1, 1, 0.95) if choisie else (Color(1, 1, 1, 0.5) if survolee else Color(0.6, 0.55, 0.4, 0.8)), false, 2.0 if choisie else 1.0)
		if not uid.is_empty():
			var it: Dictionary = inventaire.ecrans.main.sim.items.get(uid, {})
			Pictos.dessiner_objet(self, it, Rect2(Vector2(8, 6), Vector2(36, 36)))
		else:
			Pictos.dessiner_slot_vide(self, slot, Rect2(Vector2(12, 10), Vector2(28, 28)))
		draw_string(ThemeDB.fallback_font, Vector2(2, InventaireVisuel.CASE.y - 3), tr("slot." + slot).left(9), HORIZONTAL_ALIGNMENT_LEFT, InventaireVisuel.CASE.x - 4, 8, Color(0.75, 0.72, 0.6))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and index >= 0:
			inventaire.selectionner(index)
			if ev.double_click:
				inventaire.ecrans._action_principale()
			accept_event()


## Une carte du sac : l'icône, le nom court, la quantité, la qualité en couleur de cadre.
class CarteObjet extends Control:
	var inventaire: InventaireVisuel
	var uid := ""
	var index := -1
	var survolee := false

	func _ready() -> void:
		custom_minimum_size = InventaireVisuel.CARTE
		mouse_filter = Control.MOUSE_FILTER_STOP
		var it: Dictionary = inventaire.ecrans.main.sim.items.get(uid, {})
		tooltip_text = inventaire.ecrans.main.nom_objet(inventaire.ecrans.main.sim.nom_objet(uid)) if not it.is_empty() else ""
		mouse_entered.connect(func() -> void: survolee = true; queue_redraw())
		mouse_exited.connect(func() -> void: survolee = false; queue_redraw())

	func _draw() -> void:
		var it: Dictionary = inventaire.ecrans.main.sim.items.get(uid, {})
		var r := Rect2(Vector2.ZERO, InventaireVisuel.CARTE)
		var choisie: bool = inventaire.ecrans.selection == index
		var cadre := Pictos.couleur_qualite(it)
		draw_rect(r, Color(cadre.r * 0.18, cadre.g * 0.18, cadre.b * 0.18, 0.95))
		draw_rect(r, Color(1, 1, 1, 0.95) if choisie else (Color(1, 1, 1, 0.55) if survolee else cadre), false, 2.0 if choisie else 1.0)
		Pictos.dessiner_objet(self, it, Rect2(Vector2(11, 6), Vector2(36, 36)))
		if int(it.get("quantite", 1)) > 1:
			draw_string(ThemeDB.fallback_font, Vector2(InventaireVisuel.CARTE.x - 18, 14), "×%d" % int(it.quantite), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 0.8))
		var nom: String = inventaire.ecrans._nom_court(uid) if not it.is_empty() else "?"
		draw_string(ThemeDB.fallback_font, Vector2(3, InventaireVisuel.CARTE.y - 15), nom, HORIZONTAL_ALIGNMENT_LEFT, InventaireVisuel.CARTE.x - 6, 8, Color(0.92, 0.9, 0.82))
		if it.has("qualite") and it.get("type", "") != "materiau":
			draw_string(ThemeDB.fallback_font, Vector2(3, InventaireVisuel.CARTE.y - 4), "%.2f" % float(it.qualite), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, cadre)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			inventaire.selectionner(index)
			if ev.double_click:
				inventaire.ecrans._action_principale()
			accept_event()
