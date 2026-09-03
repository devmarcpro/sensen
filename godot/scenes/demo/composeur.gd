class_name Composeur
extends VBoxContainer
## Le composeur de sorts : **une grille, et on fait son Tetris** (Six types de modules et assemblage, décision du
## designer du 2026-09-03 : « on retire l'assembleur qu'on avait, ça devient du drag and drop directement dans la
## grille »). La grille est la silhouette de l'arme tenue ; chaque module est une pièce dont la forme dit ce qu'il
## fait. On prend une carte dans le catalogue et on la pose dans la grille, R la tourne, clic droit ou Suppr la
## retire, on la reprend pour la déplacer. **L'ordre de lecture est l'ordre du sort** : ligne par ligne, de gauche
## à droite — un modificateur posé au-dessus ou à gauche de son noyau s'y rattache. Le clavier reste possible :
## ← → ↑ ↓ parcourent le catalogue, Entrée pose au premier endroit libre, Suppr retire, R tourne, V valide.
## Sous la grille : le catalogue à gauche, section par type ; à droite le détail, le Wu Xing du sort et l'aperçu.

const CARTE := Vector2(48, 48)   # les cartes du catalogue : des carrés (uniformité, 2026-08-30 ; 48 px à la demande du designer)
const SLOT := Vector2(48, 48)
const COLONNES := 8
const GLYPHES := {"portee": "⟿", "forme": "◇", "noyau": "●", "modificateur": "▲", "condition": "?", "declencheur": "⚡", "liaison": "∞"}
const ORDRE_TYPES: Array[String] = ["portee", "forme", "noyau", "modificateur", "condition", "declencheur", "liaison"]

var ecrans: Node                       # l'écran parent (Ecrans) : _apercu_plan, _contribution_module, sequence_composee
var main: Node
var placements: Array[Dictionary] = []   # les pièces posées : {module, rot, ancre: Vector2i, cases: Array}
var rotation_courante := 0             # la rotation qu'aura la prochaine pièce posée (R sur une carte du catalogue)
var piece_choisie := -1                # l'index dans `placements` de la pièce sélectionnée dans la grille (−1 : aucune)
var selection := 0                     # la carte sélectionnée au clavier / au clic
var cartes: Array[Control] = []
var ids: Array[String] = []            # les modules du catalogue, dans l'ordre des cartes

var replie: Dictionary = {}            # type → section repliée (▸) ou déployée (▾)
var filtre_style := ""                 # "" = tous ; sinon un style de data/styles.json
var rangee_filtres: HBoxContainer
var etiquette_style: Label            # le style du sort en composition
var nom: LineEdit
var icone_sort: Control                # l'icône combinée du sort en cours, à côté du nom
var grille_ctrl: GrilleControl         # LA surface de composition (designer 2026-09-03)
var defil_grille: ScrollContainer      # sa rangée : haute comme la grille, pas plus
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
	defil_grille = ScrollContainer.new()   # rangée 2 : la grille, défilable si la silhouette est large
	defil_grille.custom_minimum_size = Vector2(0, GrilleControl.HAUTEUR_MIN)
	defil_grille.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(defil_grille)
	grille_ctrl = GrilleControl.new()
	grille_ctrl.composeur = self
	defil_grille.add_child(grille_ctrl)
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
	var zone := ZoneCatalogue.new()   # accepte qu'on y ramène une pièce prise dans la grille : elle en sort
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
	var liste: Array = [""] + Array(cfg.get("ordre", []))
	for st in liste:
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


# ---------------------------------------------------------------- la grille et la séquence

func grille_sort() -> GrilleSort:
	return main.sim.grille_sort


## Les cases de la grille de l'arme tenue, et sa voie.
func grille_courante() -> Dictionary:
	return main.sim.grille_composition(main.joueur())


## La séquence lue dans la grille : ligne par ligne, de gauche à droite, chaque pièce à sa case la plus
## haute puis la plus à gauche. C'est ce que le moteur assemble — l'ancienne barre de slots, à deux dimensions.
func sequence() -> Array:
	var tri: Array = placements.duplicate()
	tri.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Vector2i = _case_de_lecture(a)
		var cb: Vector2i = _case_de_lecture(b)
		return ca.y < cb.y or (ca.y == cb.y and ca.x < cb.x))
	var seq: Array = []
	for p in tri:
		seq.append(str(p.module))
	return seq


static func _case_de_lecture(p: Dictionary) -> Vector2i:
	var meilleure := Vector2i(999999, 999999)
	for c in p.cases:
		if c.y < meilleure.y or (c.y == meilleure.y and c.x < meilleure.x):
			meilleure = c
	return meilleure


func _occupees(sauf: int = -1) -> Dictionary:
	var occ := {}
	for k in placements.size():
		if k == sauf:
			continue
		for c in placements[k].cases:
			occ[c] = true
	return occ


## Pose `module` avec la rotation `rot`, ancré en `ancre` ; `deplace` = l'index d'une pièce qu'on déplace
## (ses cases ne comptent pas comme prises). Retourne vrai si la pièce tient là.
func poser(module: String, rot: int, ancre: Vector2i, deplace: int = -1) -> bool:
	var g := grille_sort()
	var forme: Array = g.tournee(g.forme_de(module), rot)
	var cases: Array = g.poser(forme, ancre, grille_courante().cases, _occupees(deplace))
	if cases.is_empty():
		grille_ctrl.refuser()
		return false
	if deplace >= 0 and deplace < placements.size():
		placements.remove_at(deplace)
	placements.append({"module": module, "rot": rot, "ancre": ancre, "cases": cases})
	piece_choisie = placements.size() - 1
	reconstruire(main.joueur())
	return true


## Pose `module` au premier endroit où il tient — sa rotation courante d'abord, puis les autres.
func poser_quelque_part(module: String) -> bool:
	var g := grille_sort()
	var cases_g: Array = grille_courante().cases
	var occ := _occupees()
	for k in 4:
		var rot := (rotation_courante + k) % 4
		var forme: Array = g.tournee(g.forme_de(module), rot)
		for ancre in cases_g:
			if occ.get(ancre, false):
				continue
			var cases: Array = g.poser(forme, ancre, cases_g, occ)
			if not cases.is_empty():
				return poser(module, rot, ancre)
	grille_ctrl.refuser()
	return false


func retirer(index: int) -> void:
	if index < 0 or index >= placements.size():
		return
	placements.remove_at(index)
	piece_choisie = -1
	reconstruire(main.joueur())


## Tourne la pièce posée `index` d'un quart de tour, si elle tient encore ; sinon rien ne bouge.
func tourner(index: int) -> void:
	if index < 0 or index >= placements.size():
		return
	var p: Dictionary = placements[index]
	var g := grille_sort()
	var forme: Array = g.tournee(g.forme_de(str(p.module)), int(p.rot) + 1)
	var cases: Array = g.poser(forme, p.ancre, grille_courante().cases, _occupees(index))
	if cases.is_empty():
		grille_ctrl.refuser()
		return
	placements[index] = {"module": p.module, "rot": (int(p.rot) + 1) % 4, "ancre": p.ancre, "cases": cases}
	reconstruire(main.joueur())


func vider_grille() -> void:
	placements = []
	piece_choisie = -1


## Une séquence venue d'ailleurs (hotbar, capture) est rangée d'office par le moteur, qui cherche un emboîtement.
func _ranger(depart: Array) -> void:
	placements = []
	piece_choisie = -1
	var emb: Dictionary = main.sim.emboitement(main.joueur(), depart)
	if not emb.ok:
		return
	for p in emb.placement:
		placements.append({"module": str(p.module), "rot": 0, "ancre": _case_de_lecture({"cases": p.cases}), "cases": p.cases})


## Reconstruit tout depuis l'état du joueur ; `depart` = une séquence à pré-remplir (hotbar, capture).
func reconstruire(j: Dictionary, depart: Array = []) -> void:
	if not depart.is_empty() and sequence() != depart:
		_ranger(depart)
	_reconstruire_catalogue(j)
	_rafraichir_detail(j)


func _reconstruire_catalogue(j: Dictionary) -> void:
	for c in catalogue.get_children():
		c.queue_free()
	cartes = []
	ids = []
	var connus: Array = j.get("modules_connus", []).duplicate()
	var seq := sequence()
	for type in ORDRE_TYPES:
		var du_type: Array = []
		for m in connus:
			if type_de(str(m)) == type and (filtre_style.is_empty() or style_de(str(m)) == filtre_style):
				du_type.append(str(m))
		if du_type.is_empty():
			continue
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
		# Les noyaux se rangent par FAMILLE (designer 2026-09-02 : « sépare dans le composeur les noyaux
		# par types »). Ils sont quatre-vingt-huit : en une seule grille, on ne trouve rien, et le
		# joueur ne voit même pas qu'il existe des familles. Les autres types restent en une grille.
		var groupes_cat: Array = []
		if type == "noyau":
			var par_famille := {}
			for m in du_type:
				var fam := str(GameData.catalogues.modules.get(str(m), {}).get("famille", ""))
				if not par_famille.has(fam):
					par_famille[fam] = []
				(par_famille[fam] as Array).append(str(m))
			var familles: Array = par_famille.keys()
			familles.sort()
			for fam in familles:
				groupes_cat.append({"titre": str(fam), "cle": type + "/" + str(fam), "modules": par_famille[fam]})
		else:
			groupes_cat.append({"titre": "", "cle": type, "modules": du_type})
		for gr in groupes_cat:
			if not str(gr.titre).is_empty():
				var sous_ferme: bool = bool(replie.get(str(gr.cle), false))
				var sous := Button.new()
				sous.text = "   %s %s (%d)" % ["▸" if sous_ferme else "▾", str(gr.titre), (gr.modules as Array).size()]
				sous.flat = true
				sous.alignment = HORIZONTAL_ALIGNMENT_LEFT
				sous.focus_mode = Control.FOCUS_NONE
				sous.add_theme_font_size_override("font_size", 10)
				sous.modulate = Color(0.7, 0.72, 0.66)
				var cle_c := str(gr.cle)
				sous.pressed.connect(func() -> void:
					replie[cle_c] = not bool(replie.get(cle_c, false))
					reconstruire(main.joueur()))
				catalogue.add_child(sous)
				if sous_ferme:
					continue
			var grille_cat := GridContainer.new()
			grille_cat.columns = COLONNES
			catalogue.add_child(grille_cat)
			for m in gr.modules:
				var carte := CarteModule.new()
				carte.composeur = self
				carte.module = str(m)
				carte.charges = -1   # un module connu l'est pour toujours : rien à afficher en coin
				carte.fois = seq.count(str(m))
				carte.index = ids.size()
				grille_cat.add_child(carte)
				cartes.append(carte)
				ids.append(str(m))
	selection = clampi(selection, 0, maxi(0, ids.size() - 1))
	for k in cartes.size():
		cartes[k].selectionnee = k == selection
		cartes[k].queue_redraw()


func _rafraichir_detail(j: Dictionary) -> void:
	var seq := sequence()
	ecrans.sequence_composee = seq.duplicate()
	var plan: Dictionary = main.sim.plan_sequence(j, seq.duplicate()) if not seq.is_empty() else {}
	apercu.montrer(plan)
	pentagramme.montrer(plan)
	grille_ctrl.montrer(grille_courante())
	icone_sort.queue_redraw()
	var texte := ""
	if piece_choisie >= 0 and piece_choisie < placements.size():   # une pièce de la grille : c'est elle qu'on décrit
		var mp := str(placements[piece_choisie].module)
		var mdp: Dictionary = GameData.catalogues.modules.get(mp, {})
		texte = tr("ui.composer.module").format({"nom": tr(mdp.get("name_key", mp)), "desc": str(mdp.get("description", ""))}) \
			+ "\n" + ecrans._contribution_module(j, mp, false) + "\n\n"
	elif selection < ids.size():
		var m := ids[selection]
		var md: Dictionary = GameData.catalogues.modules.get(m, {})
		texte = tr("ui.composer.module").format({"nom": tr(md.get("name_key", m)), "desc": str(md.get("description", ""))}) \
			+ "\n" + ecrans._contribution_module(j, m, false) + "\n\n"
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

## Entrée : le module sélectionné au catalogue va au premier endroit libre de la grille.
func ajouter_selection() -> void:
	if selection >= ids.size():
		return
	poser_quelque_part(ids[selection])


## Suppr : la pièce choisie dans la grille ; sinon la dernière pièce posée du module sélectionné ; sinon la dernière posée.
func retirer_selection() -> void:
	if piece_choisie >= 0:
		retirer(piece_choisie)
		return
	var m := ids[selection] if selection < ids.size() else ""
	for k in range(placements.size() - 1, -1, -1):
		if m.is_empty() or str(placements[k].module) == m:
			retirer(k)
			return
	if not placements.is_empty():
		retirer(placements.size() - 1)


## R : tourne la pièce choisie dans la grille ; sinon la rotation de la prochaine pièce posée.
func tourner_selection() -> void:
	if piece_choisie >= 0:
		tourner(piece_choisie)
	else:
		rotation_courante = (rotation_courante + 1) % 4
		grille_ctrl.queue_redraw()


func selectionner(index: int) -> void:
	selection = clampi(index, 0, maxi(0, ids.size() - 1))
	piece_choisie = -1
	for k in cartes.size():
		cartes[k].selectionnee = k == selection
		cartes[k].queue_redraw()
	_rafraichir_detail(main.joueur())


func choisir_piece(index: int) -> void:
	piece_choisie = index if index >= 0 and index < placements.size() else -1
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
		KEY_R:
			tourner_selection()
			return true
	return false


# ---------------------------------------------------------------- icônes

static func type_de(m: String) -> String:
	var md: Dictionary = GameData.catalogues.modules.get(m, {})
	return str(md.get("module_type", ""))


static func couleur_de(m: String) -> Color:
	return Pictos.couleur_module(GameData.catalogues.modules.get(m, {}))


## Une carte carrée complète : le cadre teinté, le pictogramme, le nom en bas, les charges en coin, « ×n » si déjà posé.
static func dessiner_carte(ci: CanvasItem, taille: Vector2, m: String, charges: int, fois: int, alpha: float = 1.0) -> void:
	var c := couleur_de(m)
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


## L'icône d'un module, dessinée par code : un cadre teinté, le pictogramme de son effet.
static func dessiner_icone(ci: CanvasItem, r: Rect2, m: String, alpha: float = 1.0) -> void:
	var c := couleur_de(m)
	ci.draw_rect(r, Color(c.r * 0.25, c.g * 0.25, c.b * 0.25, alpha))
	ci.draw_rect(r, Color(c.r, c.g, c.b, alpha), false, 2.0)
	var marge := r.size.x * 0.18
	Pictos.dessiner(ci, Pictos.icone_de(GameData.catalogues.modules.get(m, {})), Rect2(r.position + Vector2(marge, marge), r.size - Vector2(2.0 * marge, 2.0 * marge)), Color(c.r, c.g, c.b, alpha))


## L'aperçu d'une pièce pendant qu'on la glisse : sa silhouette, dans la couleur du module.
func apercu_piece(module: String, rot: int) -> Control:
	var g := grille_sort()
	var forme: Array = g.tournee(g.forme_de(module), rot)
	var ctrl := Control.new()
	var mx := 0
	var my := 0
	var minx := 0
	var miny := 0
	for c in forme:
		mx = maxi(mx, c.x)
		my = maxi(my, c.y)
		minx = mini(minx, c.x)
		miny = mini(miny, c.y)
	var cs := GrilleControl.CASE
	ctrl.custom_minimum_size = Vector2(float(mx - minx + 1), float(my - miny + 1)) * cs
	var col := couleur_de(module)
	ctrl.draw.connect(func() -> void:
		for c in forme:
			ctrl.draw_rect(Rect2(Vector2(float(c.x - minx), float(c.y - miny)) * cs + Vector2(1, 1), Vector2(cs - 2.0, cs - 2.0)), Color(col.r, col.g, col.b, 0.85)))
	return ctrl


# ---------------------------------------------------------------- les Control internes

## L'icône combinée du sort en cours de composition (Pictos.dessiner_sort), à côté du nom.
class IconeSort extends Control:
	var composeur: Composeur

	func _ready() -> void:
		custom_minimum_size = Composeur.SLOT

	func _draw() -> void:
		Pictos.dessiner_sort(self, composeur.sequence(), Rect2(Vector2(2, 2), Composeur.SLOT - Vector2(4, 4)))


## Une carte du catalogue : icône + nom court ; source de glisser-déposer vers la grille.
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
		set_drag_preview(composeur.apercu_piece(module, composeur.rotation_courante))
		return {"module": module, "rot": composeur.rotation_courante, "deplace": -1}


## La zone du catalogue : y ramener une pièce prise dans la grille la retire.
class ZoneCatalogue extends MarginContainer:
	var composeur: Composeur

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and int(data.get("deplace", -1)) >= 0

	func _drop_data(_at: Vector2, data: Variant) -> void:
		composeur.retirer(int(data.deplace))


## La grille de composition (designer 2026-09-03) : la silhouette de l'arme tenue, où l'on pose les pièces.
## Chaque pièce est teintée par son module et porte son nom court ; la pièce choisie a un liseré blanc ;
## la case survolée pendant un glissement montre en clair ou en rouge si la pièce y tiendrait. Sous la
## grille : combien de cases sont prises, et la voie de l'arme.
class GrilleControl extends Control:
	const CASE := 30.0
	const HAUTEUR_MIN := 3.0 * 30.0 + 40.0   # trois rangées au moins ; la rangée grandit avec la silhouette
	var composeur: Composeur
	var grille: Dictionary = {}          # {stat, niveau, cases}
	var survol := Vector2i(-1, -1)      # la case sous la souris pendant un glissement
	var survol_ok := false
	var donnees_survol: Dictionary = {}
	var refus_jusqua := 0.0             # un flash rouge quand une pose est refusée

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(300, HAUTEUR_MIN)

	func montrer(g: Dictionary) -> void:
		grille = g
		var mx := 0
		var my := 0
		for c in g.get("cases", []):
			mx = maxi(mx, c.x)
			my = maxi(my, c.y)
		custom_minimum_size = Vector2(maxf(300.0, float(mx + 1) * CASE + 220.0), maxf(HAUTEUR_MIN, float(my + 1) * CASE + 40.0))
		if composeur.defil_grille != null:   # la rangée suit la hauteur de la grille : pas de bande vide sous une petite silhouette
			composeur.defil_grille.custom_minimum_size = Vector2(0, custom_minimum_size.y)
		queue_redraw()

	func refuser() -> void:
		refus_jusqua = Time.get_ticks_msec() / 1000.0 + 0.4
		queue_redraw()

	func _origine() -> Vector2:
		return Vector2(6.0, 22.0)

	func case_a(pos: Vector2) -> Vector2i:
		var rel := (pos - _origine()) / CASE
		return Vector2i(int(floorf(rel.x)), int(floorf(rel.y)))

	func _piece_a(case: Vector2i) -> int:
		for k in composeur.placements.size():
			if case in composeur.placements[k].cases:
				return k
		return -1

	func _draw() -> void:
		var cases: Array = grille.get("cases", [])
		var o := _origine()
		var refuse := Time.get_ticks_msec() / 1000.0 < refus_jusqua
		draw_string(ThemeDB.fallback_font, Vector2(0, 12), tr("ui.composeur.grille"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.8, 0.6))
		var fond := Color(0.35, 0.1, 0.1) if refuse else Color(0.12, 0.12, 0.16)
		var maxy := 0
		var maxx := 0
		for c in cases:
			maxy = maxi(maxy, c.y)
			maxx = maxi(maxx, c.x)
			draw_rect(Rect2(o + Vector2(c.x, c.y) * CASE, Vector2(CASE - 1.0, CASE - 1.0)), fond)
			draw_rect(Rect2(o + Vector2(c.x, c.y) * CASE, Vector2(CASE - 1.0, CASE - 1.0)), Color(0.35, 0.33, 0.28, 0.8), false, 1.0)
		for k in composeur.placements.size():
			var p: Dictionary = composeur.placements[k]
			var md: Dictionary = GameData.catalogues.modules.get(str(p.module), {})
			var col := Pictos.couleur_module(md)
			for c in p.cases:
				draw_rect(Rect2(o + Vector2(c.x, c.y) * CASE + Vector2(2, 2), Vector2(CASE - 5.0, CASE - 5.0)), Color(col.r * 0.55, col.g * 0.55, col.b * 0.55))
				if k == composeur.piece_choisie:
					draw_rect(Rect2(o + Vector2(c.x, c.y) * CASE + Vector2(1, 1), Vector2(CASE - 3.0, CASE - 3.0)), Color(1, 1, 1, 0.9), false, 2.0)
			var cl := Composeur._case_de_lecture(p)   # le pictogramme et le nom sur la case de lecture : l'ordre se voit
			var r_ic := Rect2(o + Vector2(cl.x, cl.y) * CASE + Vector2(5, 3), Vector2(CASE - 11.0, CASE - 11.0))
			Pictos.dessiner(self, Pictos.icone_de(md), r_ic, col)
			var nom_c := TranslationServer.translate(str(md.get("name_key", p.module))).left(6)
			draw_string(ThemeDB.fallback_font, o + Vector2(cl.x, cl.y) * CASE + Vector2(3, CASE - 4.0), nom_c, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.95, 0.95, 0.9))
		if survol.x >= 0 and not donnees_survol.is_empty():   # la pièce en train d'être glissée, en clair ou en rouge
			var g := composeur.grille_sort()
			var forme: Array = g.tournee(g.forme_de(str(donnees_survol.module)), int(donnees_survol.rot))
			for c in forme:
				var pos: Vector2i = survol + c
				draw_rect(Rect2(o + Vector2(pos.x, pos.y) * CASE + Vector2(2, 2), Vector2(CASE - 5.0, CASE - 5.0)), Color(0.5, 1.0, 0.6, 0.45) if survol_ok else Color(1.0, 0.3, 0.3, 0.45))
		var pris := 0
		for p in composeur.placements:
			pris += (p.cases as Array).size()
		var bas_y := o.y + float(maxy + 1) * CASE + 12.0
		var msg := tr("ui.composeur.grille_ok").format({"demande": pris, "cases": cases.size()})
		draw_string(ThemeDB.fallback_font, Vector2(0, bas_y), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.9, 0.8))
		var stat := str(grille.get("stat", ""))
		var voie := tr("stat." + stat) if not stat.is_empty() else tr("ui.composeur.mains_nues")
		var x_droite := o.x + float(maxx + 1) * CASE + 14.0
		draw_string(ThemeDB.fallback_font, Vector2(x_droite, o.y + 12.0), tr("ui.composeur.grille_voie").format({"stat": voie}), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.7, 0.65))
		# la prochaine pièce, à la rotation courante, pour qu'on sache ce que R a fait
		if composeur.selection < composeur.ids.size() and composeur.piece_choisie < 0:
			var m_sel: String = composeur.ids[composeur.selection]
			var g2 := composeur.grille_sort()
			var f2: Array = g2.tournee(g2.forme_de(m_sel), composeur.rotation_courante)
			var minx := 0
			var miny := 0
			for c in f2:
				minx = mini(minx, c.x)
				miny = mini(miny, c.y)
			var col2 := Composeur.couleur_de(m_sel)
			var petit := CASE * 0.5
			for c in f2:
				draw_rect(Rect2(Vector2(x_droite, o.y + 20.0) + Vector2(float(c.x - minx), float(c.y - miny)) * petit, Vector2(petit - 1.0, petit - 1.0)), Color(col2.r, col2.g, col2.b, 0.8))
			draw_string(ThemeDB.fallback_font, Vector2(x_droite, o.y + 20.0 + 2.5 * petit + 12.0), tr("ui.composeur.rotation").format({"n": composeur.rotation_courante}), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.6, 0.55))
		if refuse:
			draw_string(ThemeDB.fallback_font, Vector2(0, bas_y + 13.0), tr("ui.composeur.ne_rentre_pas"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.55, 0.5))
			get_tree().create_timer(0.45).timeout.connect(queue_redraw)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			var k := _piece_a(case_a(ev.position))
			if ev.button_index == MOUSE_BUTTON_LEFT:
				composeur.choisir_piece(k)
				queue_redraw()
				accept_event()
			elif ev.button_index == MOUSE_BUTTON_RIGHT and k >= 0:
				composeur.retirer(k)   # clic droit : la pièce sort de la grille
				accept_event()

	func _get_drag_data(at: Vector2) -> Variant:
		var k := _piece_a(case_a(at))
		if k < 0:
			return null
		var p: Dictionary = composeur.placements[k]
		composeur.choisir_piece(k)
		set_drag_preview(composeur.apercu_piece(str(p.module), int(p.rot)))
		return {"module": str(p.module), "rot": int(p.rot), "deplace": k}

	func _can_drop_data(at: Vector2, data: Variant) -> bool:
		if not (data is Dictionary and data.has("module")):
			return false
		var case := case_a(at)
		var g := composeur.grille_sort()
		var forme: Array = g.tournee(g.forme_de(str(data.module)), int(data.get("rot", 0)))
		var ok := not g.poser(forme, case, grille.get("cases", []), composeur._occupees(int(data.get("deplace", -1)))).is_empty()
		if case != survol or ok != survol_ok or donnees_survol != data:
			survol = case
			survol_ok = ok
			donnees_survol = data
			queue_redraw()
		return true   # on accepte toujours le dépôt pour pouvoir dire « non » en rouge, pas en silence

	func _drop_data(at: Vector2, data: Variant) -> void:
		survol = Vector2i(-1, -1)
		donnees_survol = {}
		composeur.poser(str(data.module), int(data.get("rot", 0)), case_a(at), int(data.get("deplace", -1)))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
			survol = Vector2i(-1, -1)
			donnees_survol = {}
			queue_redraw()


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
		# Le pentagramme se dessinait à TAILLE fixe, quelle que soit la case qu'on lui donnait : dans une
		# fenêtre courte il sortait par le bas du panneau (point 67). Il tient désormais dans SA boîte, et
		# tout ce qu'il trace suit la même échelle.
		var cote := minf(size.x, size.y - 18.0)
		if cote < 60.0:
			return
		var k_ech := cote / TAILLE
		var rayon := RAYON * k_ech
		draw_rect(Rect2(Vector2.ZERO, Vector2(cote, cote)), Color(0.06, 0.06, 0.08, 1.0))
		draw_rect(Rect2(Vector2.ZERO, Vector2(cote, cote)), Color(0.6, 0.55, 0.4, 0.6), false, 1.0)
		var centre := Vector2(cote * 0.5, cote * 0.5 + 6.0 * k_ech)
		var pts: Array[Vector2] = []
		for k in elements.size():   # le cercle d'engendrement, le premier élément en haut
			var a := -PI / 2.0 + TAU * float(k) / float(elements.size())
			pts.append(centre + Vector2(cos(a), sin(a)) * rayon)
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
			draw_circle(pts[k], (4.0 + 10.0 * part) * k_ech, Color(c.r, c.g, c.b, 0.35 + 0.65 * part) if part > 0.0 else Color(c.r, c.g, c.b, 0.3))
			var etiquette := tr("element." + el) + (" %d %%" % roundi(part * 100.0) if part > 0.0 else "")
			var dir := (pts[k] - centre).normalized()
			draw_string(ThemeDB.fallback_font, pts[k] + dir * 14.0 * k_ech + Vector2(-14.0, 4.0), etiquette, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.9, 0.85))
		draw_string(ThemeDB.fallback_font, Vector2(6.0, 12.0), tr("ui.composeur.wuxing_legende"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.7, 0.65))
		var legende: String
		if dominante.is_empty():
			legende = tr("ui.composeur.wuxing_vide")
		else:
			legende = tr("ui.composeur.wuxing").format({"dominante": tr("element." + dominante), "engendre": tr("element." + str(wx.engendre.get(dominante, ""))), "domine": tr("element." + str(wx.domine.get(dominante, "")))})
		draw_string(ThemeDB.fallback_font, Vector2(2.0, cote + 13.0), legende, HORIZONTAL_ALIGNMENT_LEFT, size.x - 4.0, 9, Color(0.85, 0.85, 0.8))   # bornée à son carré : pas de chevauchement avec l'aperçu

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
