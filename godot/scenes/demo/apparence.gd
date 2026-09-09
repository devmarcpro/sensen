class_name ApparenceVisuelle
extends VBoxContainer
## L'APPARENCE EN VIGNETTES (designer 2026-09-09 : « pour l'apparence fais plutôt un menu scrollable séparé par
## catégories et le joueur peut choisir dans la liste avec la flèche ou en sélectionnant l'image du composant en
## cliquant dessus, toujours la roue de couleur en bas à gauche comme ça le joueur peut choisir la couleur du
## composant quand il l'a sélectionné »).
##
## **On choisit une tête en la VOYANT.** Chaque catégorie montre ses variantes dessinées, prises aux mêmes planches
## que le jeu — pas une liste de mots où « ovale » et « en cœur » ne veulent rien dire tant qu'on n'a pas essayé les
## deux. La flèche navigue comme avant, le clic fait la même chose ; les deux écrivent au même endroit.
##
## **La roue est en bas à gauche, et elle ne se referme jamais.** Elle colore ce que la sélection désigne : les
## cheveux quand on est sur les cheveux, la peau pour tout le reste du corps. C'est ce qui remplace l'ancien système —
## une roue qui s'ouvrait sur Entrée, et qui **ne s'ouvrait pas** : le dispatch passait 1 là où la branche attendait
## 0, si bien que la fonctionnalité était écrite et injoignable. *Ce qui n'a pas de chemin n'existe pas.*
##
## Il ne décide rien : il lit `ecrans.entrees` / `ecrans.selection` et appelle l'écran pour changer une valeur.

const VIGNETTE := Vector2(56, 56)
## CHAQUE PARTIE A SA COULEUR (designer 2026-09-09 : « sépare couleurs pour chaque parties »). Se tenir sur une
## catégorie et tourner la roue colore CETTE partie-là, sous `couleur_<locus>` — une surcharge, pas un remplacement :
## sans elle, le trait garde la teinte dont il héritait. Les trois teintes de base (peau, cheveux, pilosité) gardent
## leurs propres lignes et habillent tout le reste du corps.
## Ce dont chaque partie hérite quand elle n'a pas sa couleur — c'est ce que la roue montre au départ.
const HERITE_DE := {"cheveux": "teinte_cheveux", "pilosite": "teinte_pilosite"}
const TEINTES_BASE := ["teinte_peau", "teinte_cheveux", "teinte_pilosite"]

var ecrans: Node
var defilement: ScrollContainer
var colonne: VBoxContainer
var roue: ColorPicker
var titre_roue: Label
var _vignettes: Dictionary = {}     # "locus:valeur" → le bouton
var _locus_lignes: Dictionary = {}  # locus → l'index de son entrée dans `ecrans.entrees`
var _locus_courant := ""
var _muet := false                  # la roue écrit dans l'apparence ; se relire soi-même bouclerait


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	defilement = ScrollContainer.new()
	defilement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(defilement)
	colonne = VBoxContainer.new()
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_theme_constant_override("separation", 4)
	defilement.add_child(colonne)
	var bas := VBoxContainer.new()   # LA ROUE, EN BAS À GAUCHE, ET TOUJOURS LÀ
	bas.add_theme_constant_override("separation", 2)
	add_child(bas)
	titre_roue = Label.new()
	titre_roue.add_theme_font_size_override("font_size", 11)
	bas.add_child(titre_roue)
	roue = ColorPicker.new()
	roue.edit_alpha = false
	roue.picker_shape = ColorPicker.SHAPE_HSV_WHEEL
	# ELLE DOIT RESTER PETITE. Une roue complète — curseurs RVB, modes, échantillons — occupait la moitié du panneau
	# et ne laissait voir que deux catégories : la fonction chassait le contenu. On garde la roue et le champ hexa
	# (qui sert à recopier une couleur exacte), on jette le reste.
	roue.can_add_swatches = false
	roue.sampler_visible = false
	roue.presets_visible = false
	roue.sliders_visible = false
	roue.color_modes_visible = false
	roue.custom_minimum_size = Vector2(190, 205)
	roue.color_changed.connect(_sur_couleur)
	bas.add_child(roue)


## La couleur choisie s'écrit en clair dans l'apparence en cours — c'est ce que le pantin sait déjà lire.
func _sur_couleur(col: Color) -> void:
	if _muet or ecrans == null:
		return
	var regl: Dictionary = ecrans.main.creation.get("apparence", {})
	regl[_cle_couleur()] = "#" + col.to_html(false)
	ecrans.main.creation["apparence"] = regl
	EcransListe.rafraichir(ecrans)


## LA CLÉ QUE LA ROUE ÉCRIT. Sur une teinte de base, c'est elle-même — la peau habille le corps entier. Sur une
## catégorie du visage, c'est la couleur PROPRE de cette partie.
func _cle_couleur() -> String:
	if _locus_courant in TEINTES_BASE:
		return _locus_courant
	if _locus_courant.is_empty() or _locus_courant == "corps":
		return "teinte_peau"
	return "couleur_" + _locus_courant


## Ce que la roue doit MONTRER : la couleur propre de la partie si elle en a une, sinon celle dont elle hérite.
func _couleur_montree(app: Dictionary) -> Color:
	var cle := _cle_couleur()
	var v := str(app.get(cle, ""))
	if v.begins_with("#"):
		return Color.html(v)
	if cle.begins_with("couleur_"):
		# L'HÉRITAGE EXACT, pas une approximation : les yeux, le nez et la bouche sont dessinés à l'ENCRE — la peau
		# assombrie, ou la teinte que l'être déclare —, pas à la couleur de la peau. Montrer la peau sur ces trois-là
		# aurait fait mentir la roue avant même qu'on la tourne.
		if _locus_courant in ["yeux", "nez", "bouche"]:
			var e := str(app.get("teinte_encre", ""))
			if not e.is_empty():
				return EcransCreation._couleur_courante("teinte_encre", app)
			return EcransCreation._couleur_courante("teinte_peau", app).darkened(0.55)
		var herite := str(HERITE_DE.get(_locus_courant, "teinte_peau"))
		return EcransCreation._couleur_courante(herite, app)
	return EcransCreation._couleur_courante(cle, app)


## Reconstruit les catégories et leurs vignettes depuis `ecrans.entrees` : une entrée `app:<locus>` par catégorie,
## dans l'ordre où l'écran les a posées. Les valeurs viennent du catalogue, les images des planches.
func rafraichir() -> void:
	if ecrans == null or ecrans.main == null:
		return
	for ch in colonne.get_children():
		colonne.remove_child(ch)
		ch.queue_free()
	_vignettes.clear()
	_locus_lignes.clear()
	var app: Dictionary = EcransCreation._apparence_apercu(ecrans, EcransCreation._fiche_apercu(ecrans))
	var lignes: Array = EcransCreation._lignes_apparence(ecrans, true)
	for i in ecrans.entrees.size():
		var en: Dictionary = ecrans.entrees[i]
		if str(en.get("kind", "")) == "creation" and str(en.get("id", "")).begins_with("app:"):
			_locus_lignes[str(en.id).trim_prefix("app:")] = i
	for ligne in lignes:
		var lid := str(ligne.id)
		if bool(ligne.get("couleur", false)):
			continue   # les couleurs n'ont pas de vignette : c'est la roue qui les fait, et elle est en bas
		if not _locus_lignes.has(lid):
			continue
		var titre := Label.new()
		titre.text = ecrans.tr("ui.apparence." + lid)
		titre.add_theme_font_size_override("font_size", 12)
		colonne.add_child(titre)
		var rangee := HFlowContainer.new()
		rangee.add_theme_constant_override("h_separation", 4)
		rangee.add_theme_constant_override("v_separation", 4)
		colonne.add_child(rangee)
		var courante := str(app.get(lid, ""))
		for v in ligne.valeurs:
			var b := CaseApparence.new()
			b.panneau = self
			b.locus = lid
			b.valeur = str(v)
			b.choisie = str(v) == courante
			b.custom_minimum_size = VIGNETTE
			b.tooltip_text = ecrans.tr("ui.apparence.val." + str(v))
			rangee.add_child(b)
			_vignettes["%s:%s" % [lid, str(v)]] = b
	_suivre_selection()


## La sélection du clavier désigne une catégorie : la roue la suit, et la vignette courante se marque.
func _suivre_selection() -> void:
	var sel: int = ecrans.selection
	_locus_courant = ""
	for lid: String in _locus_lignes.keys():
		if int(_locus_lignes[lid]) == sel:
			_locus_courant = lid
	if _locus_courant.is_empty():   # une ligne qui n'est pas une catégorie : c'est peut-être une teinte de base
		var en_sel: Dictionary = ecrans.entrees[sel] if sel >= 0 and sel < ecrans.entrees.size() else {}
		var id_sel := str(en_sel.get("id", "")).trim_prefix("app:")
		_locus_courant = id_sel if id_sel in TEINTES_BASE else "corps"
	titre_roue.text = ecrans.tr("ui.creation.roue_de").format({
		"quoi": ecrans.tr("ui.apparence." + (_locus_courant if _locus_courant != "corps" else "teinte_peau"))})
	var app: Dictionary = EcransCreation._apparence_apercu(ecrans, EcransCreation._fiche_apercu(ecrans))
	_muet = true
	roue.color = _couleur_montree(app)
	_muet = false
	for cle: String in _vignettes.keys():
		var b: CaseApparence = _vignettes[cle]
		b.pointee = b.locus == _locus_courant
		b.queue_redraw()


## Un clic sur une vignette : la valeur est prise ET sa catégorie devient la ligne courante, pour que la roue suive.
func choisir(locus: String, valeur: String) -> void:
	var regl: Dictionary = ecrans.main.creation.get("apparence", {})
	regl[locus] = valeur
	ecrans.main.creation["apparence"] = regl
	if _locus_lignes.has(locus):
		ecrans.selection = int(_locus_lignes[locus])
		ecrans.liste.select(ecrans.selection)
	EcransListe.rafraichir(ecrans)


## Une vignette : le composant dessiné, pris à la même planche que le jeu. Un cadre clair quand c'est la valeur
## portée, un cadre doré quand sa catégorie est celle que la sélection désigne.
class CaseApparence extends Button:
	var panneau: ApparenceVisuelle
	var locus := ""
	var valeur := ""
	var choisie := false
	var pointee := false

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		pressed.connect(func() -> void: panneau.choisir(locus, valeur))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.12, 0.12, 0.14), true)
		var dossier := "visage/" + locus
		var idx := Planches.index_locus(locus, valeur)
		if Planches.variantes(dossier) > 0 and idx >= 0:
			# UNE PIÈCE SE MONTRE À SA PLACE (designer 2026-09-09, les marqueurs de visage). Un sprite de PIÈCE —
			# un œil, une oreille — est dessiné au centre de sa case et posé par le jeu sur chaque ancre. La
			# vignette le montrait donc comme un point au milieu du carré, et l'on choisissait ses yeux à l'aveugle.
			# Elle applique maintenant les mêmes ancres que le visage : deux yeux, deux oreilles.
			var cadre := r.grow(-3.0)
			var siens: Array = Planches.marqueurs(dossier, idx).get(locus, [])
			var places: Array = [Vector2.ZERO]
			if not siens.is_empty():
				places = []
				var k := cadre.size / float(Planches.case())
				for a in Planches.ancres_defaut(locus):
					places.append(((a as Vector2) - (siens[0] as Vector2)) * k)
			for d_p in places:
				Planches.dessiner(self, dossier, idx, Rect2(cadre.position + d_p, cadre.size))
		else:
			# Pas de planche pour ce locus (la carrure, la taille) : on écrit le mot, faute d'image à montrer.
			var f := get_theme_default_font()
			draw_string(f, Vector2(5, size.y * 0.58), tooltip_text.left(9), HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 10)
		if choisie:
			draw_rect(r, Color(0.95, 0.9, 0.7), false, 2.0)
		elif pointee:
			draw_rect(r, Color(0.6, 0.55, 0.35), false, 1.0)
