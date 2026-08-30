class_name Composeur
extends VBoxContainer
## Le composeur de sorts en glisser-déposer (Écrans d'interface, décision du designer du 2026-08-30) : une rangée de
## **slots** (+ / − pour en ajouter ou en retirer), on glisse un module du catalogue dans un slot ou on l'en sort,
## chaque module a son **icône** dessinée par code (un glyphe par type, teinté par son élément), le joueur **nomme**
## son sort. Le clavier reste possible : ← → parcourent le catalogue, Entrée ajoute, Suppr retire, V valide.
## Sous la rangée : le catalogue à gauche, à droite le détail, le Wu Xing du sort et l'aperçu visuel.

const CARTE := Vector2(60, 66)
const SLOT := Vector2(60, 60)
const COLONNES := 6
const GLYPHES := {"forme:cible": "◇", "forme:lanceur": "◈", "noyau": "●", "modificateur": "▲", "condition": "?", "declencheur": "⚡", "liaison": "∞"}
const ORDRE_TYPES: Array[String] = ["forme:cible", "forme:lanceur", "noyau", "modificateur", "condition", "declencheur", "liaison"]

var ecrans: Node                       # l'écran parent (Ecrans) : _apercu_plan, _contribution_module, sequence_composee
var main: Node
var slots: Array[String] = []          # un module par slot, "" = vide
var selection := 0                     # la carte sélectionnée au clavier / au clic
var cartes: Array[Control] = []
var ids: Array[String] = []            # les modules du catalogue, dans l'ordre des cartes

var nom: LineEdit
var rangee_slots: HBoxContainer
var grille: GridContainer
var detail: RichTextLabel
var apercu: ApercuSort
var pentagramme: Control


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Rangée 1 : le nom, − slots +
	var h1 := HBoxContainer.new()
	add_child(h1)
	var l_nom := Label.new()
	l_nom.text = tr("ui.composeur.nom")
	h1.add_child(l_nom)
	nom = LineEdit.new()
	nom.custom_minimum_size = Vector2(200, 0)
	nom.placeholder_text = tr("ui.composeur.nom_auto")
	nom.max_length = 32
	h1.add_child(nom)
	var moins := Button.new()
	moins.text = "−"
	moins.focus_mode = Control.FOCUS_NONE
	moins.pressed.connect(func() -> void: _retirer_slot())
	h1.add_child(moins)
	rangee_slots = HBoxContainer.new()
	h1.add_child(rangee_slots)
	var plus := Button.new()
	plus.text = "+"
	plus.focus_mode = Control.FOCUS_NONE
	plus.pressed.connect(func() -> void: _ajouter_slot())
	h1.add_child(plus)
	var aide := Label.new()   # l'aide sur sa propre ligne, repliée : la rangée des slots ne pousse pas le panneau hors de l'écran
	aide.text = tr("ui.composeur.aide")
	aide.add_theme_font_size_override("font_size", 10)
	aide.modulate = Color(0.75, 0.75, 0.7)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(aide)
	# Rangée 2 : le catalogue à gauche, le détail + Wu Xing + aperçu à droite
	var h2 := HBoxContainer.new()
	h2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(h2)
	var defil := ScrollContainer.new()
	defil.custom_minimum_size = Vector2(COLONNES * (CARTE.x + 4) + 14, 0)
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h2.add_child(defil)
	var zone := ZoneCatalogue.new()   # accepte qu'on y ramène un module d'un slot : le slot se vide
	zone.composeur = self
	zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.add_child(zone)
	grille = GridContainer.new()
	grille.columns = COLONNES
	zone.add_child(grille)
	var droite := VBoxContainer.new()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h2.add_child(droite)
	detail = RichTextLabel.new()
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("normal_font_size", 13)
	droite.add_child(detail)
	var bas := HBoxContainer.new()
	droite.add_child(bas)
	pentagramme = PentagrammeSort.new()
	pentagramme.composeur = self
	bas.add_child(pentagramme)
	apercu = ApercuSort.new()
	bas.add_child(apercu)


# ---------------------------------------------------------------- la séquence

func sequence() -> Array:
	var seq: Array = []
	for m in slots:
		if not m.is_empty():
			seq.append(m)
	return seq


## Reconstruit tout depuis l'état du joueur ; `depart` = une séquence à pré-remplir (hotbar, capture).
func reconstruire(j: Dictionary, depart: Array = []) -> void:
	if slots.is_empty() or (not depart.is_empty() and sequence() != depart):
		slots = []
		for m in depart:
			slots.append(str(m))
		while slots.size() < 2:
			slots.append("")
	_reconstruire_catalogue(j)
	_reconstruire_slots()
	_rafraichir_detail(j)


func _reconstruire_catalogue(j: Dictionary) -> void:
	for c in grille.get_children():
		c.queue_free()
	cartes = []
	ids = []
	var connus: Array = j.get("modules_connus", []).duplicate()
	for type in ORDRE_TYPES:
		var du_type: Array = []
		for m in connus:
			if type_de(str(m)) == type:
				du_type.append(str(m))
		du_type.sort()
		du_type.sort_custom(func(a: String, b: String) -> bool:
			var ca: int = int(j.get("modules_charges", {}).get(a, 0))
			var cb: int = int(j.get("modules_charges", {}).get(b, 0))
			return ca > cb if ca != cb else a < b)
		for m in du_type:
			var carte := CarteModule.new()
			carte.composeur = self
			carte.module = m
			carte.charges = int(j.get("modules_charges", {}).get(m, 0))
			carte.fois = sequence().count(m)
			carte.index = ids.size()
			grille.add_child(carte)
			cartes.append(carte)
			ids.append(m)
	selection = clampi(selection, 0, maxi(0, ids.size() - 1))
	for k in cartes.size():
		cartes[k].selectionnee = k == selection
		cartes[k].queue_redraw()


func _reconstruire_slots() -> void:
	for c in rangee_slots.get_children():
		c.queue_free()
	for k in slots.size():
		var s := SlotModule.new()
		s.composeur = self
		s.index = k
		s.module = slots[k]
		rangee_slots.add_child(s)


func _rafraichir_detail(j: Dictionary) -> void:
	var seq := sequence()
	ecrans.sequence_composee = seq.duplicate()
	var plan: Dictionary = main.sim.plan_sequence(j, seq.duplicate()) if not seq.is_empty() else {}
	apercu.montrer(plan)
	pentagramme.montrer(plan)
	var texte := ""
	if selection < ids.size():
		var m := ids[selection]
		var md: Dictionary = GameData.catalogues.modules.get(m, {})
		var ch: int = int(j.get("modules_charges", {}).get(m, 0))
		texte = tr("ui.composer.module").format({"nom": tr(md.get("name_key", m)), "desc": str(md.get("description", ""))}) \
			+ "\n" + tr("ui.composer.charges").format({"n": ch}) + "\n" + ecrans._contribution_module(j, m, false) + "\n\n"
	if not plan.is_empty():
		texte += ecrans._apercu_plan(plan)
	else:
		texte += tr("ui.composeur.glisser")
	detail.text = texte
	if nom.placeholder_text != _nom_auto(plan):
		nom.placeholder_text = _nom_auto(plan)


## Le nom proposé quand le joueur n'en saisit pas : celui du noyau (comme avant), sinon « Sort ».
func _nom_auto(plan: Dictionary) -> String:
	if plan.is_empty() or plan.get("noyau", {}).is_empty():
		return tr("ui.composeur.nom_auto")
	return tr(str(plan.noyau.get("name_key", "")))


func nom_choisi() -> String:
	return nom.text.strip_edges()


# ---------------------------------------------------------------- actions

func _ajouter_slot() -> void:
	slots.append("")
	_reconstruire_slots()


func _retirer_slot() -> void:
	if slots.size() <= 1:
		return
	slots.remove_at(slots.size() - 1)   # le dernier slot part, plein ou vide
	_reconstruire_slots()
	_rafraichir_detail(main.joueur())


## Pose `module` dans le slot `index` (depuis le catalogue, ou depuis le slot `depuis`).
func poser(index: int, module: String, depuis: int = -1) -> void:
	if index < 0 or index >= slots.size():
		return
	if depuis >= 0 and depuis < slots.size():
		var ancien := slots[index]
		slots[index] = module
		slots[depuis] = ancien   # l'échange : ce qui était là prend la place d'origine
	else:
		slots[index] = module
	_reconstruire_slots()
	reconstruire(main.joueur())


func vider(index: int) -> void:
	if index >= 0 and index < slots.size():
		slots[index] = ""
		_reconstruire_slots()
		reconstruire(main.joueur())


## Ajoute le module sélectionné dans le premier slot vide (un slot de plus s'il n'y en a pas).
func ajouter_selection() -> void:
	if selection >= ids.size():
		return
	var m := ids[selection]
	var libre := slots.find("")
	if libre < 0:
		slots.append("")
		libre = slots.size() - 1
	poser(libre, m)


## Retire la dernière occurrence du module sélectionné (ou le dernier slot plein).
func retirer_selection() -> void:
	var m := ids[selection] if selection < ids.size() else ""
	var i := slots.rfind(m) if not m.is_empty() else -1
	if i < 0:
		for k in range(slots.size() - 1, -1, -1):
			if not slots[k].is_empty():
				i = k
				break
	if i >= 0:
		vider(i)


func selectionner(index: int) -> void:
	selection = clampi(index, 0, maxi(0, ids.size() - 1))
	for k in cartes.size():
		cartes[k].selectionnee = k == selection
		cartes[k].queue_redraw()
	_rafraichir_detail(main.joueur())


## Les touches propres au composeur ; true si consommée.
func touche(ev: InputEventKey) -> bool:
	if nom.has_focus():
		return false   # on tape le nom
	match ev.keycode:
		KEY_LEFT:
			selectionner(selection - 1)
			return true
		KEY_RIGHT:
			selectionner(selection + 1)
			return true
		KEY_UP:
			selectionner(selection - COLONNES)
			return true
		KEY_DOWN:
			selectionner(selection + COLONNES)
			return true
		KEY_ENTER, KEY_KP_ENTER:
			ajouter_selection()
			return true
		KEY_DELETE, KEY_BACKSPACE:
			retirer_selection()
			return true
		KEY_KP_ADD, KEY_EQUAL, KEY_PLUS:
			_ajouter_slot()
			return true
		KEY_KP_SUBTRACT, KEY_MINUS:
			_retirer_slot()
			return true
	return false


# ---------------------------------------------------------------- icônes

static func type_de(m: String) -> String:
	var md: Dictionary = GameData.catalogues.modules.get(m, {})
	var t := str(md.get("module_type", ""))
	if t == "forme":
		return "forme:" + str(md.get("origine", "cible"))
	return t


static func couleur_de(m: String) -> Color:
	var md: Dictionary = GameData.catalogues.modules.get(m, {})
	var els: Dictionary = md.get("elements", {})
	var meilleur := ""
	var poids := 0.0
	for el in els.keys():
		if float(els[el]) > poids:
			poids = float(els[el])
			meilleur = str(el)
	var teintes: Dictionary = GameData.config("wuxing").get("teintes", {})
	if not meilleur.is_empty() and teintes.has(meilleur):
		var t: Array = teintes[meilleur]
		return Color(float(t[0]), float(t[1]), float(t[2]))
	if int(md.get("cout_endurance", 0)) > 0:
		return Color(0.85, 0.6, 0.3)   # endurance : ocre
	return Color(0.7, 0.7, 0.8)      # arcane / neutre : gris bleuté


## L'icône d'un module, dessinée par code : un cadre teinté, le glyphe de son type, ses initiales.
static func dessiner_icone(ci: CanvasItem, r: Rect2, m: String, alpha: float = 1.0) -> void:
	var c := couleur_de(m)
	var t := type_de(m)
	ci.draw_rect(r, Color(c.r * 0.25, c.g * 0.25, c.b * 0.25, alpha))
	ci.draw_rect(r, Color(c.r, c.g, c.b, alpha), false, 2.0)
	var glyphe: String = GLYPHES.get(t, "·")
	ci.draw_string(ThemeDB.fallback_font, r.position + Vector2(r.size.x * 0.5 - 8.0, r.size.y * 0.5 + 6.0), glyphe, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(c.r, c.g, c.b, alpha))


# ---------------------------------------------------------------- les Control internes

## Une carte du catalogue : icône + nom court + charges ; source de glisser-déposer.
class CarteModule extends Control:
	var composeur: Composeur
	var module := ""
	var charges := 0
	var fois := 0
	var index := 0
	var selectionnee := false

	func _ready() -> void:
		custom_minimum_size = Composeur.CARTE
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = tr(GameData.catalogues.modules.get(module, {}).get("name_key", module))

	func _draw() -> void:
		var r := Rect2(Vector2(4, 2), Vector2(Composeur.CARTE.x - 8, 40))
		Composeur.dessiner_icone(self, r, module, 1.0 if charges > 0 else 0.45)
		if selectionnee:
			draw_rect(Rect2(Vector2.ZERO, Composeur.CARTE), Color(1, 1, 1, 0.9), false, 1.5)
		if fois > 0:
			draw_string(ThemeDB.fallback_font, Vector2(6, 14), "×%d" % fois, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1))
		draw_string(ThemeDB.fallback_font, Vector2(Composeur.CARTE.x - 26, 14), str(charges), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.9, 0.8, 0.8))
		var nom_c := tr(GameData.catalogues.modules.get(module, {}).get("name_key", module)).left(9)
		draw_string(ThemeDB.fallback_font, Vector2(4, Composeur.CARTE.y - 6), nom_c, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.95, 0.9))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			composeur.selectionner(index)
			if ev.double_click:
				composeur.ajouter_selection()
			accept_event()

	func _get_drag_data(_at: Vector2) -> Variant:
		composeur.selectionner(index)
		var apercu := Control.new()
		apercu.custom_minimum_size = Vector2(40, 40)
		var m := module
		apercu.draw.connect(func() -> void: Composeur.dessiner_icone(apercu, Rect2(Vector2.ZERO, Vector2(40, 40)), m, 0.9))
		set_drag_preview(apercu)
		return {"module": module, "depuis": -1}


## Un slot de la séquence : reçoit un module (du catalogue ou d'un autre slot), et se laisse vider par glissement.
class SlotModule extends Control:
	var composeur: Composeur
	var index := 0
	var module := ""

	func _ready() -> void:
		custom_minimum_size = Composeur.SLOT
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), Composeur.SLOT - Vector2(4, 4))
		draw_rect(r, Color(0.12, 0.12, 0.15, 1.0))
		draw_rect(r, Color(0.6, 0.55, 0.4, 0.9), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(4, 12), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.7, 0.7, 0.65))
		if module.is_empty():
			draw_string(ThemeDB.fallback_font, Vector2(6, Composeur.SLOT.y - 8), tr("ui.composeur.slot_vide"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.5, 0.5, 0.5))
		else:
			Composeur.dessiner_icone(self, Rect2(Vector2(10, 8), Vector2(40, 40)), module)
			var nom_s := tr(GameData.catalogues.modules.get(module, {}).get("name_key", module)).left(8)
			draw_string(ThemeDB.fallback_font, Vector2(4, Composeur.SLOT.y - 4), nom_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.95, 0.9))

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("module")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		composeur.poser(index, str(data.module), int(data.get("depuis", -1)))

	func _get_drag_data(_at: Vector2) -> Variant:
		if module.is_empty():
			return null
		var apercu := Control.new()
		apercu.custom_minimum_size = Vector2(40, 40)
		var m := module
		apercu.draw.connect(func() -> void: Composeur.dessiner_icone(apercu, Rect2(Vector2.ZERO, Vector2(40, 40)), m, 0.9))
		set_drag_preview(apercu)
		return {"module": module, "depuis": index}

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and not module.is_empty():
			composeur.vider(index)   # clic droit : le slot se vide
			accept_event()


## La zone du catalogue : y ramener un module pris dans un slot vide ce slot.
class ZoneCatalogue extends MarginContainer:
	var composeur: Composeur

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and int(data.get("depuis", -1)) >= 0

	func _drop_data(_at: Vector2, data: Variant) -> void:
		composeur.vider(int(data.depuis))


## Le Wu Xing du sort : le pentagramme des cinq éléments, chaque sommet gonflé selon la part de l'élément dans le
## plan, la dominante nommée avec ce qu'elle engendre et ce qu'elle domine (Wu Xing — cycles et vecteurs).
class PentagrammeSort extends Control:
	var composeur: Composeur
	var plan: Dictionary = {}
	const RAYON := 46.0

	func _ready() -> void:
		custom_minimum_size = Vector2(RAYON * 2 + 100, RAYON * 2 + 44)   # assez large pour la légende « X domine · engendre Y · domine Z »

	func montrer(p: Dictionary) -> void:
		plan = p
		queue_redraw()

	func _draw() -> void:
		var wx: Dictionary = GameData.config("wuxing")
		var elements: Array = wx.get("elements", ["bois", "feu", "terre", "metal", "eau"])
		var teintes: Dictionary = wx.get("teintes", {})
		var centre := Vector2(RAYON + 50, RAYON + 16)
		var pts: Array[Vector2] = []
		for k in elements.size():   # le cercle d'engendrement, le premier élément en haut
			var a := -PI / 2.0 + TAU * float(k) / float(elements.size())
			pts.append(centre + Vector2(cos(a), sin(a)) * RAYON)
		for k in pts.size():
			draw_line(pts[k], pts[(k + 1) % pts.size()], Color(1, 1, 1, 0.25), 1.0)          # engendre
			draw_line(pts[k], pts[(k + 2) % pts.size()], Color(1, 1, 1, 0.12), 1.0)          # domine (l'étoile)
		var parts: Dictionary = plan.get("elements", {}) if not plan.is_empty() else {}
		var total := 0.0
		for v in parts.values():
			total += float(v)
		var dominante := ""
		var poids := 0.0
		for k in elements.size():
			var el := str(elements[k])
			var t: Array = teintes.get(el, [0.7, 0.7, 0.7])
			var c := Color(float(t[0]), float(t[1]), float(t[2]))
			var part: float = float(parts.get(el, 0.0)) / total if total > 0.0 else 0.0
			if part > poids:
				poids = part
				dominante = el
			draw_circle(pts[k], 4.0 + 10.0 * part, Color(c.r, c.g, c.b, 0.35 + 0.65 * part) if part > 0.0 else Color(c.r, c.g, c.b, 0.3))
			var etiquette := tr("element." + el) + (" %d %%" % roundi(part * 100.0) if part > 0.0 else "")
			var dir := (pts[k] - centre).normalized()
			draw_string(ThemeDB.fallback_font, pts[k] + dir * 14.0 + Vector2(-14.0, 4.0), etiquette, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.9, 0.85))
		var legende: String
		if dominante.is_empty():
			legende = tr("ui.composeur.wuxing_vide")
		else:
			legende = tr("ui.composeur.wuxing").format({"dominante": tr("element." + dominante), "engendre": tr("element." + str(wx.engendre.get(dominante, ""))), "domine": tr("element." + str(wx.domine.get(dominante, "")))})
		draw_string(ThemeDB.fallback_font, Vector2(2.0, RAYON * 2 + 40), legende, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.85, 0.8))
