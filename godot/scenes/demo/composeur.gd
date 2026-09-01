class_name Composeur
extends VBoxContainer
## Le composeur de sorts en glisser-déposer (Écrans d'interface, décision du designer du 2026-08-30) : des **groupes de
## slots par type** (Formes · Noyaux · Modificateurs · Conditions · Liaisons · Déclencheur · Suite), chacun avec ses
## boutons + / −, on glisse un module du catalogue dans un slot de son type ou on l'en sort, chaque module a son
## **icône** dessinée par code (un glyphe par type, teinté par son élément), le joueur **nomme** son sort. Le clavier
## reste possible : ← → ↑ ↓ parcourent le catalogue, Entrée ajoute, Suppr retire, V valide. Sous la rangée : le
## catalogue à gauche, section par type ; à droite le détail, le Wu Xing du sort et l'aperçu visuel.

const CARTE := Vector2(48, 48)   # cartes et slots : des carrés, de la même taille (uniformité, 2026-08-30 ; 48 px à la demande du designer)
const SLOT := Vector2(48, 48)
const COLONNES := 8
const GLYPHES := {"portee": "⟿", "forme": "◇", "noyau": "●", "modificateur": "▲", "condition": "?", "declencheur": "⚡", "liaison": "∞"}
const ORDRE_TYPES: Array[String] = ["portee", "forme", "noyau", "modificateur", "condition", "declencheur", "liaison"]
## Les groupes de la composition, dans l'ordre de la séquence : tout ce qui précède le déclencheur est la charge
## principale, tout ce qui le suit (« suite », libre) est sa charge différée (Six types de modules).
const GROUPES: Array[String] = ["portee", "forme", "noyau", "modificateur", "condition", "liaison", "declencheur", "suite"]

var ecrans: Node                       # l'écran parent (Ecrans) : _apercu_plan, _contribution_module, sequence_composee
var main: Node
var groupes: Dictionary = {}           # groupe → Array[String] (un module par slot, "" = vide)
var selection := 0                     # la carte sélectionnée au clavier / au clic
var cartes: Array[Control] = []
var ids: Array[String] = []            # les modules du catalogue, dans l'ordre des cartes

var replie: Dictionary = {}            # type → section repliée (▸) ou déployée (▾)
var filtre_style := ""                 # "" = tous ; sinon un style de data/styles.json
var rangee_filtres: HBoxContainer
var etiquette_style: Label            # le style du sort en composition
var nom: LineEdit
var icone_sort: Control                # l'icône combinée du sort en cours, à côté du nom
var rangee_slots: HBoxContainer
var catalogue: VBoxContainer
var detail: RichTextLabel
var apercu: ApercuSort
var pentagramme: Control


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h1 := HBoxContainer.new()   # rangée 1 : le nom du sort, et son style
	add_child(h1)
	icone_sort = IconeSort.new()
	icone_sort.composeur = self
	h1.add_child(icone_sort)
	var l_nom := Label.new()
	l_nom.text = tr("ui.composeur.nom")
	h1.add_child(l_nom)
	nom = LineEdit.new()
	nom.custom_minimum_size = Vector2(220, 0)
	nom.placeholder_text = tr("ui.composeur.nom_auto")
	nom.max_length = 32
	h1.add_child(nom)
	etiquette_style = Label.new()
	etiquette_style.add_theme_font_size_override("font_size", 11)
	etiquette_style.modulate = Color(0.85, 0.85, 0.8)
	h1.add_child(etiquette_style)
	var aide := Label.new()
	aide.text = tr("ui.composeur.aide")
	aide.add_theme_font_size_override("font_size", 10)
	aide.modulate = Color(0.75, 0.75, 0.7)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h1.add_child(aide)
	var defil_slots := ScrollContainer.new()   # rangée 2 : les groupes de slots, défilables si la composition s'allonge
	defil_slots.custom_minimum_size = Vector2(0, SLOT.y + 34)
	defil_slots.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(defil_slots)
	rangee_slots = HBoxContainer.new()
	defil_slots.add_child(rangee_slots)
	var h2 := HBoxContainer.new()   # rangée 3 : le catalogue à gauche, le détail + Wu Xing + aperçu à droite
	h2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(h2)
	var gauche := VBoxContainer.new()   # à gauche : les filtres de style, puis le catalogue
	gauche.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h2.add_child(gauche)
	rangee_filtres = HBoxContainer.new()
	gauche.add_child(rangee_filtres)
	_construire_filtres()
	var defil := ScrollContainer.new()
	defil.custom_minimum_size = Vector2(COLONNES * (CARTE.x + 4) + 18, 0)
	defil.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defil.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gauche.add_child(defil)
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


## Les filtres de style (Six types de modules, 2026-08-30) : Tous, puis un bouton par style de data/styles.json.
func _construire_filtres() -> void:
	for c in rangee_filtres.get_children():
		c.queue_free()
	var cfg: Dictionary = GameData.config("styles")
	var ids: Array = [""] + Array(cfg.get("ordre", []))
	for st in ids:
		var b := Button.new()
		b.text = tr("ui.composeur.filtre_tous") if str(st).is_empty() else tr(str(cfg.styles.get(st, {}).get("name_key", "style." + str(st) + ".name")))
		b.flat = str(st) != filtre_style
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 10)
		if not str(st).is_empty():
			b.modulate = teinte_style(str(st))
		var st_c := str(st)
		b.pressed.connect(func() -> void:
			filtre_style = st_c
			_construire_filtres()
			reconstruire(main.joueur()))
		rangee_filtres.add_child(b)


static func style_de(m: String) -> String:
	return str(GameData.catalogues.modules.get(m, {}).get("style", "neutre"))


static func teinte_style(st: String) -> Color:
	var t: Array = GameData.config("styles").get("styles", {}).get(st, {}).get("teinte", [0.5, 0.5, 0.5])
	return Color(float(t[0]), float(t[1]), float(t[2]))


## Le style du sort : le mélange des styles de ses modules, le neutre mis à part, en pourcentages.
func texte_style_sort() -> String:
	var compte := {}
	var total := 0
	for m in sequence():
		var st := style_de(str(m))
		if st == "neutre":
			continue
		compte[st] = int(compte.get(st, 0)) + 1
		total += 1
	if total == 0:
		return tr("ui.composeur.style_neutre")
	var cfg: Dictionary = GameData.config("styles")
	var parts: Array[String] = []
	for st in cfg.get("ordre", []):
		if compte.has(st):
			parts.append("%s %d %%" % [tr(str(cfg.styles[st].name_key)), roundi(100.0 * float(compte[st]) / float(total))])
	return tr("ui.composeur.style").format({"liste": " · ".join(parts)})


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
			if type_de(str(m)) == type and (filtre_style.is_empty() or style_de(str(m)) == filtre_style):
				du_type.append(str(m))
		if du_type.is_empty():
			continue
		du_type.sort()
		du_type.sort()   # plus de charges (designer 2026-08-31) : l'ordre alphabétique suffit
		var ferme: bool = bool(replie.get(type, false))
		var entete := Button.new()   # une section par type, repliable d'un clic (demande du designer)
		entete.text = "%s %s %s (%d)" % ["▸" if ferme else "▾", GLYPHES.get(type, ""), tr("type_module." + type), du_type.size()]
		entete.flat = true
		entete.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entete.focus_mode = Control.FOCUS_NONE
		entete.add_theme_font_size_override("font_size", 11)
		entete.modulate = Color(0.85, 0.8, 0.6)
		var type_c := type
		entete.pressed.connect(func() -> void:
			replie[type_c] = not bool(replie.get(type_c, false))
			reconstruire(main.joueur()))
		catalogue.add_child(entete)
		if ferme:
			continue
		var grille := GridContainer.new()
		grille.columns = COLONNES
		catalogue.add_child(grille)
		for m in du_type:
			var carte := CarteModule.new()
			carte.composeur = self
			carte.module = m
			carte.charges = -1   # un module connu l'est pour toujours : rien à afficher en coin
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
		l.add_theme_font_size_override("font_size", 11)
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
	icone_sort.queue_redraw()
	var texte := ""
	if selection < ids.size():
		var m := ids[selection]
		var md: Dictionary = GameData.catalogues.modules.get(m, {})
		texte = tr("ui.composer.module").format({"nom": tr(md.get("name_key", m)), "desc": str(md.get("description", ""))}) \
			+ "
" + ecrans._contribution_module(j, m, false) + "

"
	if not plan.is_empty():
		texte += ecrans._apercu_plan(plan)
	else:
		texte += tr("ui.composeur.glisser")
	detail.text = texte
	etiquette_style.text = texte_style_sort()
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
	return t


static func couleur_de(m: String) -> Color:
	return Pictos.couleur_module(GameData.catalogues.modules.get(m, {}))


## Une carte carrée complète : le cadre teinté, le glyphe, le nom en bas, les charges en coin, « ×n » si déjà posé.
static func dessiner_carte(ci: CanvasItem, taille: Vector2, m: String, charges: int, fois: int, alpha: float = 1.0) -> void:
	var c := couleur_de(m)
	var t := type_de(m)
	var r := Rect2(Vector2(2, 2), taille - Vector2(4, 4))
	ci.draw_rect(r, Color(c.r * 0.22, c.g * 0.22, c.b * 0.22, alpha))
	ci.draw_rect(r, Color(c.r, c.g, c.b, alpha), false, 1.5)
	var md: Dictionary = GameData.catalogues.modules.get(m, {})
	var marge := taille.x * 0.2   # le pictogramme de l'effet (Pictos), centré, au-dessus du nom
	Pictos.dessiner(ci, Pictos.icone_de(md), Rect2(Vector2(marge, marge * 0.55), Vector2(taille.x - 2.0 * marge, taille.x - 2.0 * marge)), Color(c.r, c.g, c.b, alpha))
	if fois > 0:
		ci.draw_string(ThemeDB.fallback_font, Vector2(12, 12), "×%d" % fois, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, alpha))
	if charges >= 0:
		ci.draw_string(ThemeDB.fallback_font, Vector2(taille.x - 20, 12), str(charges), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.9, 0.8, 0.8 * alpha))
	var nom_c := TranslationServer.translate(md.get("name_key", m)).left(8)
	ci.draw_string(ThemeDB.fallback_font, Vector2(4, taille.y - 5), nom_c, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.95, 0.95, 0.9, alpha))
	var st := str(md.get("style", "neutre"))   # la pastille du style de jeu, en haut à gauche
	if st != "neutre":
		var cs := teinte_style(st)
		ci.draw_circle(Vector2(7, taille.y * 0.5), 3.0, Color(cs.r, cs.g, cs.b, alpha))


## L'icône d'un module, dessinée par code : un cadre teinté, le glyphe de son type.
static func dessiner_icone(ci: CanvasItem, r: Rect2, m: String, alpha: float = 1.0) -> void:
	var c := couleur_de(m)
	var t := type_de(m)
	ci.draw_rect(r, Color(c.r * 0.25, c.g * 0.25, c.b * 0.25, alpha))
	ci.draw_rect(r, Color(c.r, c.g, c.b, alpha), false, 2.0)
	var marge := r.size.x * 0.18
	Pictos.dessiner(ci, Pictos.icone_de(GameData.catalogues.modules.get(m, {})), Rect2(r.position + Vector2(marge, marge), r.size - Vector2(2.0 * marge, 2.0 * marge)), Color(c.r, c.g, c.b, alpha))


# ---------------------------------------------------------------- les Control internes

## L'icône combinée du sort en cours de composition (Pictos.dessiner_sort), à côté du nom.
class IconeSort extends Control:
	var composeur: Composeur

	func _ready() -> void:
		custom_minimum_size = Composeur.SLOT

	func _draw() -> void:
		Pictos.dessiner_sort(self, composeur.sequence(), Rect2(Vector2(2, 2), Composeur.SLOT - Vector2(4, 4)))


## Une carte du catalogue : icône + nom court + charges ; source de glisser-déposer.
class CarteModule extends Control:
	var composeur: Composeur
	var module := ""
	var charges := 0
	var fois := 0
	var index := 0
	var selectionnee := false
	var survolee := false

	func _ready() -> void:
		custom_minimum_size = Composeur.CARTE
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = tr(GameData.catalogues.modules.get(module, {}).get("name_key", module))
		mouse_entered.connect(func() -> void: survolee = true; queue_redraw())
		mouse_exited.connect(func() -> void: survolee = false; queue_redraw())

	func _draw() -> void:
		Composeur.dessiner_carte(self, Composeur.CARTE, module, charges, fois, 1.0)
		if selectionnee:
			draw_rect(Rect2(Vector2(1, 1), Composeur.CARTE - Vector2(2, 2)), Color(1, 1, 1, 0.95), false, 2.0)
		elif survolee:   # la souris passe : la carte s'éclaire
			draw_rect(Rect2(Vector2(1, 1), Composeur.CARTE - Vector2(2, 2)), Color(1, 1, 1, 0.5), false, 1.0)

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
	var depot_possible := false   # un module compatible est en train d'être glissé au-dessus

	func _ready() -> void:
		custom_minimum_size = Composeur.SLOT
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_exited.connect(func() -> void: depot_possible = false; queue_redraw())

	func _draw() -> void:
		if depot_possible:
			draw_rect(Rect2(Vector2.ZERO, Composeur.SLOT), Color(1, 1, 0.6, 0.25))
		if module.is_empty():
			var r := Rect2(Vector2(2, 2), Composeur.SLOT - Vector2(4, 4))
			draw_rect(r, Color(0.1, 0.1, 0.12, 1.0))
			draw_rect(r, Color(0.6, 0.55, 0.4, 0.9), false, 1.0)
			var g_glyphe: String = Composeur.GLYPHES.get(groupe, "·")
			draw_string(ThemeDB.fallback_font, Vector2(Composeur.SLOT.x * 0.5 - 7, Composeur.SLOT.y * 0.5 + 6), g_glyphe, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.35, 0.35, 0.35))
		else:
			Composeur.dessiner_carte(self, Composeur.SLOT, module, -1, 0, 1.0)
			draw_rect(Rect2(Vector2(1, 1), Composeur.SLOT - Vector2(2, 2)), Color(0.6, 0.55, 0.4, 0.9), false, 1.0)

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		var ok: bool = data is Dictionary and data.has("module") and composeur.accepte(groupe, str(data.module))
		if ok != depot_possible:
			depot_possible = ok
			queue_redraw()
		return ok

	func _drop_data(_at: Vector2, data: Variant) -> void:
		depot_possible = false
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
	const TAILLE := ApercuSort.TAILLE   # le même carré que l'aperçu visuel (uniformité, 2026-08-30)
	const RAYON := 66.0

	func _ready() -> void:
		custom_minimum_size = Vector2(TAILLE, TAILLE + 18.0)

	func montrer(p: Dictionary) -> void:
		plan = p
		queue_redraw()

	func _draw() -> void:
		var wx: Dictionary = GameData.config("wuxing")
		var elements: Array = wx.get("elements", ["bois", "feu", "terre", "metal", "eau"])
		var teintes: Dictionary = wx.get("teintes", {})
		draw_rect(Rect2(Vector2.ZERO, Vector2(TAILLE, TAILLE)), Color(0.06, 0.06, 0.08, 1.0))
		draw_rect(Rect2(Vector2.ZERO, Vector2(TAILLE, TAILLE)), Color(0.6, 0.55, 0.4, 0.6), false, 1.0)
		var centre := Vector2(TAILLE * 0.5, TAILLE * 0.5 + 6.0)
		var pts: Array[Vector2] = []
		for k in elements.size():   # le cercle d'engendrement, le premier élément en haut
			var a := -PI / 2.0 + TAU * float(k) / float(elements.size())
			pts.append(centre + Vector2(cos(a), sin(a)) * RAYON)
		var parts: Dictionary = plan.get("elements", {}) if not plan.is_empty() else {}
		var total := 0.0
		for v in parts.values():
			total += float(v)
		var dominante := ""
		var poids := 0.0
		for el in parts.keys():
			if float(parts[el]) > poids:
				poids = float(parts[el])
				dominante = str(el)
		var i_dom: int = elements.find(dominante)
		for k in pts.size():   # les flèches : engendre (plein, le cercle), domine (pointillé, l'étoile) — Wu Xing — cycles et vecteurs
			var eng_dom: bool = k == i_dom
			var dom_dom: bool = k == i_dom
			var c_eng := _teinte(teintes, str(elements[k])) if eng_dom else Color(1, 1, 1, 0.3)
			_fleche_courte(pts[k], pts[(k + 1) % pts.size()], c_eng, 1.6 if eng_dom else 1.0, 7.0)
			var c_dom := _teinte(teintes, str(elements[k])) if dom_dom else Color(1, 1, 1, 0.14)
			_pointille(pts[k], pts[(k + 2) % pts.size()], c_dom, 1.4 if dom_dom else 1.0)
			_fleche_courte(pts[k].lerp(pts[(k + 2) % pts.size()], 0.82), pts[(k + 2) % pts.size()], c_dom, 1.4 if dom_dom else 1.0, 7.0)
		poids = 0.0
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
		draw_string(ThemeDB.fallback_font, Vector2(6.0, 12.0), tr("ui.composeur.wuxing_legende"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.7, 0.65))
		var legende: String
		if dominante.is_empty():
			legende = tr("ui.composeur.wuxing_vide")
		else:
			legende = tr("ui.composeur.wuxing").format({"dominante": tr("element." + dominante), "engendre": tr("element." + str(wx.engendre.get(dominante, ""))), "domine": tr("element." + str(wx.domine.get(dominante, "")))})
		draw_string(ThemeDB.fallback_font, Vector2(2.0, TAILLE + 13.0), legende, HORIZONTAL_ALIGNMENT_LEFT, TAILLE - 4.0, 9, Color(0.85, 0.85, 0.8))   # bornée à son carré : pas de chevauchement avec l'aperçu

	static func _teinte(teintes: Dictionary, el: String) -> Color:
		var t: Array = teintes.get(el, [0.7, 0.7, 0.7])
		return Color(float(t[0]), float(t[1]), float(t[2]), 0.95)

	func _fleche_courte(a: Vector2, b: Vector2, c: Color, largeur: float, tete: float) -> void:
		draw_line(a, b, c, largeur)
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		var m := a.lerp(b, 0.55)   # la tête au milieu du trait : elle ne se cache pas sous les sommets
		draw_colored_polygon(PackedVector2Array([m + d * tete * 0.6, m - d * tete * 0.4 + n * tete * 0.5, m - d * tete * 0.4 - n * tete * 0.5]), c)

	func _pointille(a: Vector2, b: Vector2, c: Color, largeur: float) -> void:
		var n := 12
		for k in n:
			if k % 2 == 0:
				draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), c, largeur)
