class_name Composeur
extends VBoxContainer
## Le composeur de sorts en glisser-déposer (Écrans d'interface, décision du designer du 2026-08-30) : des **groupes de
## slots par type** (Formes · Noyaux · Modificateurs · Conditions · Liaisons · Déclencheur · Suite), chacun avec ses
## boutons + / −, on glisse un module du catalogue dans un slot de son type ou on l'en sort, chaque module a son
## **icône** dessinée par code (un glyphe par type, teinté par son élément), le joueur **nomme** son sort. Le clavier
## reste possible : ← → ↑ ↓ parcourent le catalogue, Entrée ajoute, Suppr retire, V valide. Sous la rangée : le
## catalogue à gauche, section par type ; à droite le détail, le Wu Xing du sort et l'aperçu visuel.

const CARTE := Vector2(60, 66)
const SLOT := Vector2(52, 54)
const COLONNES := 6
const GLYPHES := {"forme:cible": "◇", "forme:lanceur": "◈", "noyau": "●", "modificateur": "▲", "condition": "?", "declencheur": "⚡", "liaison": "∞"}
const ORDRE_TYPES: Array[String] = ["forme:cible", "forme:lanceur", "noyau", "modificateur", "condition", "declencheur", "liaison"]
## Les groupes de la composition, dans l'ordre de la séquence : tout ce qui précède le déclencheur est la charge
## principale, tout ce qui le suit (« suite », libre) est sa charge différée (Six types de modules).
const GROUPES: Array[String] = ["forme", "noyau", "modificateur", "condition", "liaison", "declencheur", "suite"]

var ecrans: Node                       # l'écran parent (Ecrans) : _apercu_plan, _contribution_module, sequence_composee
var main: Node
var groupes: Dictionary = {}           # groupe → Array[String] (un module par slot, "" = vide)
var selection := 0                     # la carte sélectionnée au clavier / au clic
var cartes: Array[Control] = []
var ids: Array[String] = []            # les modules du catalogue, dans l'ordre des cartes

var nom: LineEdit
var rangee_slots: HBoxContainer
var catalogue: VBoxContainer
var detail: RichTextLabel
var apercu: ApercuSort
var pentagramme: Control


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h1 := HBoxContainer.new()   # rangée 1 : le nom du sort
	add_child(h1)
	var l_nom := Label.new()
	l_nom.text = tr("ui.composeur.nom")
	h1.add_child(l_nom)
	nom = LineEdit.new()
	nom.custom_minimum_size = Vector2(220, 0)
	nom.placeholder_text = tr("ui.composeur.nom_auto")
	nom.max_length = 32
	h1.add_child(nom)
	var aide := Label.new()
	aide.text = tr("ui.composeur.aide")
	aide.add_theme_font_size_override("font_size", 10)
	aide.modulate = Color(0.75, 0.75, 0.7)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h1.add_child(aide)
	var defil_slots := ScrollContainer.new()   # rangée 2 : les groupes de slots, défilables si la composition s'allonge
	defil_slots.custom_minimum_size = Vector2(0, SLOT.y + 40)
	defil_slots.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(defil_slots)
	rangee_slots = HBoxContainer.new()
	defil_slots.add_child(rangee_slots)
	var h2 := HBoxContainer.new()   # rangée 3 : le catalogue à gauche, le détail + Wu Xing + aperçu à droite
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
	catalogue = VBoxContainer.new()
	zone.add_child(catalogue)
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

## Le groupe naturel d'un module : les formes ensemble, quelle que soit leur origine.
static func groupe_de(m: String) -> String:
	var t := type_de(m)
	if t.begins_with("forme"):
		return "forme"
	return t if t in GROUPES else "suite"


func sequence() -> Array:
	var seq: Array = []
	for g in GROUPES:
		for m in groupes.get(g, []):
			if not str(m).is_empty():
				seq.append(str(m))
	return seq


## Répartit une séquence dans les groupes : par type avant le déclencheur, tout ce qui le suit dans « suite ».
func _repartir(depart: Array) -> void:
	groupes = {}
	for g in GROUPES:
		groupes[g] = []
	var apres := false
	for m in depart:
		var id := str(m)
		if apres:
			groupes.suite.append(id)
			continue
		var g := groupe_de(id)
		groupes[g].append(id)
		if g == "declencheur":
			apres = true
	if groupes.forme.is_empty():   # deux slots d'accueil : une forme, un noyau
		groupes.forme.append("")
	if groupes.noyau.is_empty():
		groupes.noyau.append("")


## Reconstruit tout depuis l'état du joueur ; `depart` = une séquence à pré-remplir (hotbar, capture).
func reconstruire(j: Dictionary, depart: Array = []) -> void:
	if groupes.is_empty() or (not depart.is_empty() and sequence() != depart):
		_repartir(depart)
	_reconstruire_catalogue(j)
	_reconstruire_slots()
	_rafraichir_detail(j)


func _reconstruire_catalogue(j: Dictionary) -> void:
	for c in catalogue.get_children():
		c.queue_free()
	cartes = []
	ids = []
	var connus: Array = j.get("modules_connus", []).duplicate()
	for type in ORDRE_TYPES:
		var du_type: Array = []
		for m in connus:
			if type_de(str(m)) == type:
				du_type.append(str(m))
		if du_type.is_empty():
			continue
		du_type.sort()
		du_type.sort_custom(func(a: String, b: String) -> bool:
			var ca: int = int(j.get("modules_charges", {}).get(a, 0))
			var cb: int = int(j.get("modules_charges", {}).get(b, 0))
			return ca > cb if ca != cb else a < b)
		var entete := Label.new()   # une section par type, bien séparée (demande du designer)
		entete.text = "%s %s (%d)" % [GLYPHES.get(type, ""), tr("type_module." + type), du_type.size()]
		entete.add_theme_font_size_override("font_size", 12)
		entete.modulate = Color(0.85, 0.8, 0.6)
		catalogue.add_child(entete)
		var grille := GridContainer.new()
		grille.columns = COLONNES
		catalogue.add_child(grille)
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
	for g in GROUPES:
		var bloc := VBoxContainer.new()
		rangee_slots.add_child(bloc)
		var entete := HBoxContainer.new()
		bloc.add_child(entete)
		var l := Label.new()
		l.text = tr("ui.composeur.groupe." + g)
		l.add_theme_font_size_override("font_size", 10)
		l.modulate = Color(0.85, 0.8, 0.6)
		entete.add_child(l)
		var moins := Button.new()
		moins.text = "−"
		moins.focus_mode = Control.FOCUS_NONE
		moins.add_theme_font_size_override("font_size", 10)
		moins.pressed.connect(func() -> void: _retirer_slot(g))
		entete.add_child(moins)
		var plus := Button.new()
		plus.text = "+"
		plus.focus_mode = Control.FOCUS_NONE
		plus.add_theme_font_size_override("font_size", 10)
		plus.pressed.connect(func() -> void: _ajouter_slot(g))
		entete.add_child(plus)
		var rangee := HBoxContainer.new()
		bloc.add_child(rangee)
		var slots: Array = groupes.get(g, [])
		if slots.is_empty():
			var vide := Label.new()   # un groupe sans slot : un simple tiret, le + en ouvre un
			vide.text = "—"
			vide.custom_minimum_size = Vector2(SLOT.x, SLOT.y)
			vide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			vide.modulate = Color(0.45, 0.45, 0.45)
			rangee.add_child(vide)
		for k in slots.size():
			var s := SlotModule.new()
			s.composeur = self
			s.groupe = g
			s.index = k
			s.module = str(slots[k])
			rangee.add_child(s)
		rangee_slots.add_child(VSeparator.new())


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


## Le nom proposé quand le joueur n'en saisit pas : celui du noyau (comme avant).
func _nom_auto(plan: Dictionary) -> String:
	if plan.is_empty() or plan.get("noyau", {}).is_empty():
		return tr("ui.composeur.nom_auto")
	return tr(str(plan.noyau.get("name_key", "")))


func nom_choisi() -> String:
	return nom.text.strip_edges()


# ---------------------------------------------------------------- actions

func _ajouter_slot(g: String) -> void:
	groupes[g].append("")
	_reconstruire_slots()


func _retirer_slot(g: String) -> void:
	if groupes[g].is_empty():
		return
	groupes[g].remove_at(groupes[g].size() - 1)   # le dernier slot du groupe part, plein ou vide
	reconstruire(main.joueur())


## Un module peut-il aller dans ce groupe ? « suite » accepte tout ; les autres, leur type.
func accepte(g: String, module: String) -> bool:
	return g == "suite" or groupe_de(module) == g


## Pose `module` dans le slot (`g`, `index`) — depuis le catalogue, ou depuis le slot (`g_de`, `i_de`) : échange.
func poser(g: String, index: int, module: String, g_de: String = "", i_de: int = -1) -> void:
	if not groupes.has(g) or index < 0 or index >= groupes[g].size() or not accepte(g, module):
		return
	if not g_de.is_empty() and groupes.has(g_de) and i_de >= 0 and i_de < groupes[g_de].size():
		var ancien: String = str(groupes[g][index])
		if not ancien.is_empty() and not accepte(g_de, ancien):
			return   # l'échange mettrait un module dans un groupe qui n'est pas le sien
		groupes[g][index] = module
		groupes[g_de][i_de] = ancien
	else:
		groupes[g][index] = module
	reconstruire(main.joueur())


func vider(g: String, index: int) -> void:
	if groupes.has(g) and index >= 0 and index < groupes[g].size():
		groupes[g][index] = ""
		reconstruire(main.joueur())


## Ajoute le module sélectionné dans son groupe : premier slot vide, sinon un slot de plus.
func ajouter_selection() -> void:
	if selection >= ids.size():
		return
	var m := ids[selection]
	var g := groupe_de(m)
	var libre: int = groupes[g].find("")
	if libre < 0:
		groupes[g].append("")
		libre = groupes[g].size() - 1
	poser(g, libre, m)


## Retire la dernière occurrence du module sélectionné (sinon le dernier slot plein, groupes à rebours).
func retirer_selection() -> void:
	var m := ids[selection] if selection < ids.size() else ""
	for gi in range(GROUPES.size() - 1, -1, -1):
		var g := GROUPES[gi]
		var i: int = groupes[g].rfind(m) if not m.is_empty() else -1
		if i >= 0:
			vider(g, i)
			return
	for gi in range(GROUPES.size() - 1, -1, -1):
		var g := GROUPES[gi]
		for k in range(groupes[g].size() - 1, -1, -1):
			if not str(groupes[g][k]).is_empty():
				vider(g, k)
				return


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
			if selection < ids.size():
				_ajouter_slot(groupe_de(ids[selection]))
			return true
		KEY_KP_SUBTRACT, KEY_MINUS:
			if selection < ids.size():
				_retirer_slot(groupe_de(ids[selection]))
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


## L'icône d'un module, dessinée par code : un cadre teinté, le glyphe de son type.
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
		return {"module": module, "groupe": "", "index": -1}


## Un slot d'un groupe : reçoit un module de son type (du catalogue ou d'un autre slot), se laisse vider par glissement.
class SlotModule extends Control:
	var composeur: Composeur
	var groupe := ""
	var index := 0
	var module := ""

	func _ready() -> void:
		custom_minimum_size = Composeur.SLOT
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var r := Rect2(Vector2(2, 2), Composeur.SLOT - Vector2(4, 4))
		draw_rect(r, Color(0.12, 0.12, 0.15, 1.0))
		draw_rect(r, Color(0.6, 0.55, 0.4, 0.9), false, 1.0)
		if module.is_empty():
			var g_glyphe: String = Composeur.GLYPHES.get("forme:cible" if groupe == "forme" else groupe, "·")
			draw_string(ThemeDB.fallback_font, Vector2(Composeur.SLOT.x * 0.5 - 6, Composeur.SLOT.y * 0.5 + 6), g_glyphe, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.35, 0.35, 0.35))
		else:
			Composeur.dessiner_icone(self, Rect2(Vector2(8, 4), Vector2(36, 34)), module)
			var nom_s := tr(GameData.catalogues.modules.get(module, {}).get("name_key", module)).left(7)
			draw_string(ThemeDB.fallback_font, Vector2(3, Composeur.SLOT.y - 4), nom_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.95, 0.9))

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("module") and composeur.accepte(groupe, str(data.module))

	func _drop_data(_at: Vector2, data: Variant) -> void:
		composeur.poser(groupe, index, str(data.module), str(data.get("groupe", "")), int(data.get("index", -1)))

	func _get_drag_data(_at: Vector2) -> Variant:
		if module.is_empty():
			return null
		var apercu := Control.new()
		apercu.custom_minimum_size = Vector2(40, 40)
		var m := module
		apercu.draw.connect(func() -> void: Composeur.dessiner_icone(apercu, Rect2(Vector2.ZERO, Vector2(40, 40)), m, 0.9))
		set_drag_preview(apercu)
		return {"module": module, "groupe": groupe, "index": index}

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and not module.is_empty():
			composeur.vider(groupe, index)   # clic droit : le slot se vide
			accept_event()


## La zone du catalogue : y ramener un module pris dans un slot vide ce slot.
class ZoneCatalogue extends MarginContainer:
	var composeur: Composeur

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and not str(data.get("groupe", "")).is_empty()

	func _drop_data(_at: Vector2, data: Variant) -> void:
		composeur.vider(str(data.groupe), int(data.index))


## Le Wu Xing du sort : le pentagramme des cinq éléments, chaque sommet gonflé selon la part de l'élément dans le
## plan, la dominante nommée avec ce qu'elle engendre et ce qu'elle domine (Wu Xing — cycles et vecteurs).
class PentagrammeSort extends Control:
	var composeur: Composeur
	var plan: Dictionary = {}
	const RAYON := 38.0

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
