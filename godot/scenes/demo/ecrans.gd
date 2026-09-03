class_name Ecrans
extends CanvasLayer
## Les écrans du prototype (Écrans d'interface) : Inventaire + équipement, Atelier, Feuille de
## personnage — des Control Godot construits par code, sans asset. Un écran à la fois ; Échap ferme.
## L'écran ne décide rien : il lit la simulation et lui envoie des intentions.

const LARGEUR := 1000.0   # taille minimale ; à l'écran, le panneau prend PART de la fenêtre (designer, 2026-08-30 : plus de place)
const HAUTEUR := 660.0
const PART := Vector2(0.94, 0.92)

var main: Node                          # la scène principale (sim, joueur(), nom_objet())
var courant := ""                       # "inventaire" | "atelier" | "feuille" | ""
var panneau: PanelContainer
var titre: Label
var liste: ItemList
var detail: RichTextLabel
var apercu_sort: ApercuSort   # l'aperçu visuel du sort (écran Composer, Écrans d'interface)
var apercu_monde: ApercuMonde   # l'aperçu du monde entier (écran Monde, designer point 49)
var cadre_perso: Control      # l'aperçu du personnage (écran Création) : un paperdoll dans un cadre
var apercu_perso: Paperdoll
var _angle_saisie := 0.0   # l'angle souris→joint au moment de la saisie (point 68)
var cadre_visage: Control          # le cadre du portrait : il rogne tout ce qui n'est pas la tête
var portrait_perso: Paperdoll      # le même paperdoll, zoomé sur le visage (designer, point 43)
var pose_edition := ""      # l'action dont on articule la pose (designer, point 63)
var pose_segment := ""      # le membre saisi
var menu_contextuel_objet: PopupMenu   # clic droit sur un objet du sac (designer, point 46)
var barres_perso: BarresCreation   # vie, endurance, mana sous l'aperçu (designer, point 42)
var composeur: Composeur      # le composeur en glisser-déposer (écran Composer)
var corps: HBoxContainer      # liste + détail : caché quand le composeur est ouvert
var boutons: HFlowContainer
var entrees: Array = []                 # ce que chaque ligne de la liste représente
var selection := 0
var largeur_panneau := LARGEUR          # la largeur du panneau calculée au dernier `_dimensionner`
var hauteur_panneau := HAUTEUR          # sa hauteur, même règle : une colonne ne demande jamais plus que ça
var parties_listees: Array = []         # l'écran Charger : {slot, resume} par partie (designer 2026-09-02)
var minuterie := 0.0
var pnj_id := ""                     # le PNJ du dialogue / du commerce en cours
var replique_key := ""


var hotbar_ecran: Control   # la hotbar en bas de l'inventaire et des capacités (designer, point 35)


func _ready() -> void:
	layer = 10
	panneau = PanelContainer.new()
	panneau.set_anchors_preset(Control.PRESET_CENTER)
	_dimensionner()
	get_viewport().size_changed.connect(_dimensionner)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 1.0)   # opaque : a 0,94 le journal du jeu transparaissait a travers la liste
	style.border_color = Color(0.6, 0.55, 0.4)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	panneau.add_theme_stylebox_override("panel", style)
	panneau.resized.connect(_replacer_liste)   # la colonne suit la largeur du panneau (point 67)
	panneau.visible = false
	add_child(panneau)
	var v := VBoxContainer.new()
	panneau.add_child(v)
	titre = Label.new()
	titre.add_theme_font_size_override("font_size", 16)
	titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # un long titre (séquence composée) se replie, le panneau ne déborde pas de l'écran
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(titre)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	corps = h
	composeur = Composeur.new()
	composeur.ecrans = self
	composeur.main = main
	composeur.visible = false
	v.add_child(composeur)
	v.move_child(composeur, 1)
	inventaire_visuel = InventaireVisuel.new()
	inventaire_visuel.ecrans = self
	inventaire_visuel.visible = false
	h.add_child(inventaire_visuel)
	atelier_visuel = AtelierVisuel.new()
	atelier_visuel.ecrans = self
	atelier_visuel.visible = false
	h.add_child(atelier_visuel)
	liste = ItemList.new()
	liste.custom_minimum_size = Vector2(float(GameData.config("styles").get("ecrans", {}).get("liste_min", 340.0)), 0)
	liste.size_flags_vertical = Control.SIZE_EXPAND_FILL
	liste.focus_mode = Control.FOCUS_NONE          # les lettres restent au jeu (pas de recherche incrémentale)
	liste.item_selected.connect(_sur_selection)
	liste.item_activated.connect(func(i: int) -> void: _sur_selection(i); _action_principale())
	h.add_child(liste)
	liste.set_drag_forwarding(_glisser_liste, _depot_refuse, _depot_rien)
	hotbar_ecran = HotbarEcran.new()
	hotbar_ecran.ecrans = self
	hotbar_ecran.visible = false
	v.add_child(hotbar_ecran)
	droite = VBoxContainer.new()   # à droite : le détail, et sous lui l'aperçu visuel du sort (composeur)
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(droite)
	apercu_sort = ApercuSort.new()
	apercu_sort.visible = false
	apercu_monde = ApercuMonde.new()   # Monde : la carte entière, presque plein écran (designer, point 49)
	apercu_monde.ecrans = self
	apercu_monde.custom_minimum_size = Vector2(0, 620)
	apercu_monde.size_flags_vertical = Control.SIZE_EXPAND_FILL
	apercu_monde.visible = false
	apercu_monde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	droite.add_child(apercu_monde)
	cadre_perso = Control.new()   # Création : le personnage en grand, au-dessus du détail
	cadre_perso.custom_minimum_size = Vector2(0, 380)   # replacé à la hauteur réelle par `rafraichir`
	cadre_perso.size_flags_vertical = Control.SIZE_EXPAND_FILL   # il prend la hauteur offerte (point 67)
	cadre_perso.size_flags_stretch_ratio = float(GameData.config("styles").get("creation", {}).get("part_apercu", 2.6))
	cadre_perso.visible = false
	cadre_perso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	droite.add_child(cadre_perso)
	cadre_perso.mouse_filter = Control.MOUSE_FILTER_STOP   # le pantin se manipule à la souris (point 63)
	cadre_perso.gui_input.connect(_pantin_entree)
	cadre_perso.resized.connect(_replacer_apercu)   # tout se replace à la taille du cadre (point 67)
	apercu_perso = Paperdoll.new()
	apercu_perso.scale = Vector2(5.4, 5.4)   # le personnage en grand (designer, point 43)
	apercu_perso.dessine_apres = _surligner_membre   # le membre saisi est mis en évidence (point 68)
	apercu_perso.position = Vector2(210, 300)
	cadre_perso.add_child(apercu_perso)
	cadre_visage = Control.new()   # à sa droite, le seul visage, cadré sur la tête
	cadre_visage.position = Vector2(340, 60)
	cadre_visage.size = Vector2(170, 170)
	cadre_visage.custom_minimum_size = Vector2(170, 170)
	cadre_visage.clip_contents = true
	cadre_visage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre_perso.add_child(cadre_visage)
	portrait_perso = Paperdoll.new()
	portrait_perso.scale = Vector2(11.0, 11.0)
	portrait_perso.position = Vector2(85, 415)
	cadre_visage.add_child(portrait_perso)
	barres_perso = BarresCreation.new()
	barres_perso.position = Vector2(0, 316)
	barres_perso.custom_minimum_size = Vector2(0, 60)
	barres_perso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre_perso.add_child(barres_perso)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio = float(GameData.config("styles").get("creation", {}).get("part_detail", 1.0))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # une ligne longue se replie au lieu de sortir du panneau (point 67)
	detail.fit_content = false
	detail.clip_contents = true
	detail.add_theme_font_size_override("normal_font_size", 13)
	droite.add_child(detail)
	penta_objet = Composeur.PentagrammeSort.new()
	penta_objet.visible = false
	droite.add_child(penta_objet)
	droite.add_child(apercu_sort)
	# La rangée d'actions passe à la ligne quand elle ne tient plus (point 67). Le `HFlowContainer` avait
	# échoué sur les colonnes de l'inventaire — il décide sur les tailles minimales des enfants, que ces
	# colonnes ne déclarent pas. Ici c'est l'inverse : un Button déclare exactement la largeur de son
	# texte, donc le passage à la ligne tombe juste. Dix actions sur un objet équipable sortaient du
	# panneau par la droite, et « Fermer » — la seule dont on ne peut pas se passer — était la coupée.
	boutons = HFlowContainer.new()
	v.add_child(boutons)


var reforge_objet := ""   # Main du métal : l'objet choisi, en attente de son composant
var droite: VBoxContainer          # la colonne de droite : le détail, sous lui le Wu Xing de l'objet ou l'aperçu du sort
var inventaire_visuel: InventaireVisuel   # l'inventaire en icônes (Écrans d'interface, 2026-08-30)
var atelier_visuel: AtelierVisuel         # l'atelier en cartes de recettes
var penta_objet: Composeur.PentagrammeSort   # le Wu Xing de l'objet choisi


## Le panneau prend PART de la fenêtre, jamais moins que LARGEUR × HAUTEUR.
func _dimensionner() -> void:
	var v := get_viewport().get_visible_rect().size
	# Le plancher de taille (LARGEUR × HAUTEUR) sert les grandes fenêtres ; sur une petite, il faisait
	# déborder le panneau HORS de la fenêtre, et tout ce qui dépassait était coupé sans un mot
	# (file d'attente du designer, point 67). On le borne donc à la fenêtre elle-même.
	var l := minf(maxf(LARGEUR, v.x * PART.x), v.x)
	var h := minf(maxf(HAUTEUR, v.y * PART.y), v.y)
	largeur_panneau = l   # la largeur DE CE TOUR : `panneau.size` est encore celle du tour d'avant
	hauteur_panneau = h   # et sa hauteur : les minimums en pixels du contenu s'y mesurent (point 67)
	panneau.custom_minimum_size = Vector2(l, h)
	panneau.set_anchor_and_offset(SIDE_LEFT, 0.5, -l / 2.0)
	panneau.set_anchor_and_offset(SIDE_TOP, 0.5, -h / 2.0)
	panneau.set_anchor_and_offset(SIDE_RIGHT, 0.5, l / 2.0)
	panneau.set_anchor_and_offset(SIDE_BOTTOM, 0.5, h / 2.0)


var sequence_composee: Array = []   # la séquence en cours de composition (écran composer)
var triche_categorie := ""   # menu de triche : le catalogue en cours de parcours
var contexte_tuile := Vector2i(-1, -1)   # clic droit : la tuile et ses options
var contexte_options: Array = []


func ouvrir_contexte(t: Vector2i, options: Array) -> void:
	contexte_tuile = t
	contexte_options = options
	ouvrir("contexte")


func est_ouvert() -> bool:
	return not courant.is_empty()


func basculer(nom: String) -> void:
	if courant == nom:
		fermer()
	else:
		ouvrir(nom)


func ouvrir(nom: String) -> void:
	courant = nom
	_replacer_liste()   # la colonne suit la largeur du panneau : le signal resized ne suffit pas à l'ouverture
	selection = 0
	panneau.visible = true
	apercu_sort.visible = false
	corps.visible = nom != "composer"
	composeur.visible = nom == "composer"
	rafraichir()


func fermer() -> void:
	courant = ""
	panneau.visible = false
	apercu_sort.visible = false
	composeur.visible = false
	corps.visible = true


func _process(delta: float) -> void:
	if not est_ouvert():
		return
	minuterie -= delta
	if minuterie <= 0.0:
		minuterie = 0.25
		if courant == "composer":   # rien n'y change sans une touche, et 178 modules × 2 plans coûtent 40 ms
			return
		rafraichir()


## Touches quand un écran est ouvert ; true si consommée.
func touche(ev: InputEventKey) -> bool:
	if courant == "creation" and _touche_creation(ev):
		return true
	if ev.keycode == KEY_TAB:
		if courant == "creation":
			return true
		fermer()
		return true
	if courant == "composer" and ev.keycode != KEY_ESCAPE and ev.keycode != KEY_V and composeur.touche(ev):
		return true
	match ev.keycode:
		KEY_ESCAPE:
			if courant == "triche_liste":   # la sous-liste revient au menu de triche
				ouvrir("triche")
				return true
			if courant == "titre":   # rien derrière l'écran principal : Échap n'y fait rien
				return true
			if not pose_edition.is_empty():   # Échap : on sort du pantin sans quitter la création
				pose_edition = ""
				pose_segment = ""
				rafraichir()
				return true
			if courant == "creation":
				main.creation = {}
				ouvrir("titre")
				return true
			if courant in ["monde", "charger"] or (courant == "options" and main.titre_ouvert):
				ouvrir("titre")
				return true
			fermer()
			return true
		KEY_LEFT, KEY_RIGHT:
			if not pose_edition.is_empty() and courant == "creation":   # le pantin (point 63)
				_tourner_membre((-1.0 if ev.keycode == KEY_LEFT else 1.0) * float(GameData.config("poses").get("pas_degres", 6.0)))
				return true
			if courant == "monde" and selection < entrees.size():   # les réglages du monde (designer, point 49)
				var en_m: Dictionary = entrees[selection]
				if str(en_m.get("id", "")).begins_with("opt:"):
					_regler_monde(str(en_m.id).trim_prefix("opt:"), -1 if ev.keycode == KEY_LEFT else 1)
					rafraichir()
					return true
		KEY_UP, KEY_DOWN:
			if entrees.size() > 0:
				selection = posmod(selection + (1 if ev.keycode == KEY_DOWN else -1), entrees.size())
				liste.select(selection)
				_montrer_detail()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if not pose_edition.is_empty():   # garder la pose et sortir du pantin
				pose_edition = ""
				pose_segment = ""
				rafraichir()
				return true
			_action_principale()
			return true
		KEY_DELETE, KEY_BACKSPACE:
			if courant == "composer":   # retirer la dernière occurrence du module sélectionné
				var en_c: Dictionary = entrees[selection] if selection < entrees.size() else {}
				if en_c.get("kind", "") == "module_composer":
					var i_c: int = sequence_composee.rfind(str(en_c.module))
					if i_c >= 0:
						sequence_composee.remove_at(i_c)
						rafraichir()
				return true
		KEY_E:
			if courant == "inventaire":
				_action_principale()
				return true
		KEY_J:
			if courant == "inventaire":
				_jeter()
				return true
		KEY_L:
			if courant == "inventaire":
				_lire()
				return true
		KEY_T:
			if courant == "inventaire":
				_sertir()
				return true
		KEY_P:
			if courant == "inventaire":
				_poser()
				return true
		KEY_M:
			if courant == "inventaire":
				_mur(false)
				return true
		KEY_O:
			if courant == "inventaire":
				_mur(true)
				return true
		KEY_R:
			if courant == "inventaire":
				_ranger()
				return true
		KEY_G:
			if courant == "inventaire":
				_manger()
				return true
		KEY_P:
			if courant == "dialogue":
				_option("parler")
				return true
		KEY_C:
			if courant == "dialogue":
				_option("commercer")
				return true
		KEY_Q:
			if courant == "dialogue":
				_option("quetes")
				return true
		KEY_R:
			if courant == "dialogue":
				_option("recruter")
				return true
		KEY_S:
			if courant == "dialogue":
				_option("suivre")
				return true
		KEY_A:
			if courant == "dialogue":
				_option("attendre")
				return true
		KEY_F:
			if courant == "dialogue":
				_option("posture")
				return true
		KEY_B:
			if courant == "dialogue":
				_option("retour")
				return true
		KEY_K:
			if courant == "dialogue":
				_option("echanger")
				return true
		KEY_Y:
			if courant == "dialogue":
				_option("repli")
				return true
		KEY_W:
			if courant == "dialogue":
				_option("suiveur")
				return true
		KEY_X:
			if courant == "dialogue":
				_option("assigner")
				return true
		KEY_U:
			if courant == "dialogue":
				_option("entrainer")
				return true
		KEY_Z:
			if courant == "dialogue":
				_option("livrer")
				return true
		KEY_N:
			if courant == "dialogue":
				_option("ressusciter")
				return true
		KEY_Q:
			if courant == "dialogue":
				_option("apprendre_talent")
				return true
		KEY_D:
			if courant == "gestion":
				main.sim.deposer(main.joueur(), 50)
				rafraichir()
				return true
		KEY_T:
			if courant == "gestion":
				var en: Dictionary = entrees[liste.get_selected_items()[0]] if not liste.get_selected_items().is_empty() and liste.get_selected_items()[0] < entrees.size() else {}
				if en.get("kind", "") == "voisin":
					var types: Array = ["commercial", "non_agression", "alliance", "tribut"]
					var actuel: String = str(main.sim.territoire.accords.get(str(en.id), ""))
					if actuel.begins_with("tribut"):
						actuel = "tribut"
					main.sim.proposer_accord(main.joueur(), str(en.id), str(types[(types.find(actuel) + 1) % types.size()]))
					rafraichir()
				return true
		KEY_G:
			if courant == "gestion":
				var ids: Array = GameData.catalogues.governments.keys()
				ids.sort()
				var actuel: String = str(main.sim.territoire.gouvernance_cible) if not str(main.sim.territoire.gouvernance_cible).is_empty() else str(main.sim.territoire.gouvernance)
				main.sim.changer_gouvernance(str(ids[(ids.find(actuel) + 1) % ids.size()]))
				rafraichir()
				return true
		KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			if courant == "gestion":
				main.sim.regler_marge(float(main.sim.regles.r.royaume.boutique.marge_pas))
				rafraichir()
				return true
		KEY_MINUS, KEY_KP_SUBTRACT:
			if courant == "gestion":
				main.sim.regler_marge(-float(main.sim.regles.r.royaume.boutique.marge_pas))
				rafraichir()
				return true
		KEY_B:
			if courant == "inventaire":
				var en: Dictionary = entrees[liste.get_selected_items()[0]] if not liste.get_selected_items().is_empty() and liste.get_selected_items()[0] < entrees.size() else {}
				if en.get("kind", "") == "objet":
					if reforge_objet.is_empty() or reforge_objet == str(en.uid):
						reforge_objet = str(en.uid)
						main._log(tr("ui.ecran.reforger"))
					else:
						main.sim.intention(main.joueur().id, {"type": "reforger", "objet": reforge_objet, "composant": str(en.uid)})
						reforge_objet = ""
						rafraichir()
				return true
		KEY_V:
			if courant == "composer":
				_valider_composition()
				return true
		KEY_H:
			if courant == "inventaire":
				var en: Dictionary = entrees[liste.get_selected_items()[0]] if not liste.get_selected_items().is_empty() and liste.get_selected_items()[0] < entrees.size() else {}
				if en.get("kind", "") == "objet":
					main.sim.intention(main.joueur().id, {"type": "planter", "base": str(main.sim.items[str(en.uid)].base)})
					rafraichir()
				return true
		KEY_W:
			if courant == "gestion":
				main.sim.retirer(main.joueur(), 50)
				rafraichir()
				return true
	return false


# ---------------------------------------------------------------- construction

func rafraichir() -> void:
	var j: Dictionary = main.joueur()
	if j.is_empty():
		return
	var sel := selection
	liste.clear()
	entrees.clear()
	for b in boutons.get_children():
		b.queue_free()
	match courant:
		"inventaire":
			_construire_inventaire(j)
		"atelier":
			_construire_atelier(j)
		"feuille":
			_construire_feuille(j)
		"dialogue":
			_construire_dialogue(j)
		"quetes":
			_construire_quetes(j)
		"gestion":
			_construire_gestion(j)
		"menu":
			_construire_menu(j)
		"titre":
			_construire_titre()
		"creation":
			_construire_creation()
		"monde":
			_construire_monde()
		"options":
			_construire_options()
		"charger":
			_construire_charger()
		"capacites":
			_construire_capacites(j)
		"composer":
			_construire_composer(j)
		"contexte":
			_construire_contexte(j)
		"registre":
			_construire_registre(j)
		"assigner":
			_construire_assigner(j)
		"echange":
			_construire_echange(j)
		"entrainer":
			_construire_entrainer(j)
		"commerce":
			_construire_commerce(j)
		"triche":
			_construire_triche(j)
		"triche_liste":
			_construire_triche_liste(j)
		_:
			# Un nom inconnu laissait le panneau ouvert, vide, sous le titre du dernier écran construit :
			# une faute de frappe dans une recette de capture rendait une image fausse sans rien signaler.
			push_error("Écran inconnu : « %s »" % courant)
			fermer()
			return
	selection = clampi(sel, 0, maxi(0, entrees.size() - 1))
	if entrees.size() > 0:
		liste.select(selection)
	_montrer_detail()
	cadre_perso.visible = courant == "creation"
	if courant == "charger" and selection < entrees.size():
		_portrait_partie(str(entrees[selection].get("id", "")))   # `cadre_perso` reste visible : c'est le portrait de la partie
	apercu_monde.visible = courant == "monde"
	inventaire_visuel.visible = courant == "inventaire"
	hotbar_ecran.visible = courant == "inventaire" or courant == "capacites"
	atelier_visuel.visible = courant == "atelier"
	liste.visible = not (courant in ["inventaire", "atelier"])
	penta_objet.visible = courant == "inventaire"   # la place qu'on lui laisse se décide plus bas, à la hauteur connue
	# Chaque écran demandait une largeur en pixels fixes pour sa colonne de droite ; additionnée à la
	# liste (340 px), la somme dépassait une fenêtre étroite et le contenu sortait du cadre. Ces
	# largeurs sont désormais des PARTS du panneau, plafonnées à la valeur d'origine (point 67).
	# La largeur vient de `_dimensionner`, pas de `panneau.size` : la taille d'un Control n'est à jour
	# qu'après le tour de mise en page suivant, et s'en servir ici rendait des largeurs d'un cran en
	# retard — les colonnes se calculaient pour la fenêtre précédente et débordaient de la nouvelle.
	_dimensionner()
	# Le panneau a ses propres marges intérieures et les conteneurs leur séparation : compter sur la
	# largeur brute laissait les colonnes déborder d'une trentaine de pixels, juste assez pour manger
	# la fin de chaque ligne de texte. On travaille donc sur la largeur UTILE.
	var large := largeur_panneau - 48.0
	# Même raisonnement en HAUTEUR, et c'est là que ça coupait vraiment : le panneau de l'inventaire
	# demandait 724 px de haut quoi qu'il arrive (détail 340 + pentagramme 222 + en-têtes), donc il
	# débordait de toute fenêtre plus courte — et un PanelContainer ne rétrécit jamais sous le minimum
	# de son contenu, si bien que `custom_minimum_size` ne le retenait pas. La sonde des écrans le
	# mesure maintenant à chaque passage. On réserve le titre, la hotbar et la rangée de boutons.
	var haut := maxf(220.0, hauteur_panneau - 150.0)
	var part_droite := func(px: float, part: float) -> float: return minf(px, maxf(120.0, large * part))
	liste.custom_minimum_size = Vector2(minf(float(GameData.config("styles").get("ecrans", {}).get("liste_min", 340.0)), large * 0.42), 0)
	if courant == "monde":   # la carte du monde prend presque toute la fenêtre (designer, point 49)
		droite.custom_minimum_size = Vector2(part_droite.call(900.0, 0.62), 0)
		droite.size_flags_stretch_ratio = 3.0
		detail.size_flags_vertical = Control.SIZE_SHRINK_END   # le texte se tasse : la carte prend le reste
		detail.custom_minimum_size = Vector2(0, 44)
		apercu_monde.custom_minimum_size = Vector2(0, minf(880.0, haut * 0.92))
	elif courant == "inventaire":
		# L'inventaire a quatre colonnes de front : grille d'équipement, avatar, fiche, détail. On sert
		# d'abord les trois qui portent de l'information, et le détail prend ce qui reste — jamais moins
		# de 200 px, sous quoi une description d'objet redevient illisible.
		droite.custom_minimum_size = Vector2(clampf(large - 500.0, 200.0, 360.0), 0)
		droite.size_flags_stretch_ratio = 0.9
		detail.size_flags_vertical = Control.SIZE_FILL   # le Wu Xing de l'objet juste sous le détail, pas au fond du panneau
		# Le détail prend la moitié haute, le Wu Xing de l'objet un tiers, et les deux se rabotent
		# ensemble quand la fenêtre raccourcit : c'est ce qui empêche la colonne de pousser le panneau
		# hors de l'écran. Sous 96 px le pentagramme n'est plus lisible — il s'efface alors.
		detail.custom_minimum_size = Vector2(0, clampf(haut * 0.48, 110.0, 340.0))
		var cote_penta := clampf(haut * 0.34, 0.0, Composeur.PentagrammeSort.TAILLE)
		penta_objet.visible = cote_penta >= 96.0
		penta_objet.custom_minimum_size = Vector2(0, cote_penta + 18.0 if cote_penta >= 96.0 else 0.0)
		inventaire_visuel.ajuster_largeur(large - droite.custom_minimum_size.x)
		inventaire_visuel.reconstruire()
	elif courant == "atelier":
		droite.custom_minimum_size = Vector2(part_droite.call(380.0, 0.36), 0)
		droite.size_flags_stretch_ratio = 0.8
		detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
		atelier_visuel.reconstruire()
	else:
		droite.custom_minimum_size = Vector2(0, 0)
		droite.size_flags_stretch_ratio = 1.0
		detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
		detail.custom_minimum_size = Vector2(0, 0)
	if courant == "titre":   # rien derrière l'écran principal : pas de « Fermer »
		pass
	elif courant == "creation":
		_bouton(tr("ui.creation.commencer"), func() -> void: main._creer_personnage())
		_bouton(tr("ui.monde.retour"), func() -> void: main.creation = {}; ouvrir("titre"))
	elif courant in ["monde", "charger"] or (courant == "options" and main.titre_ouvert):
		_bouton(tr("ui.monde.retour"), func() -> void: ouvrir("titre"))
	else:
		_bouton(tr("ui.ecran.fermer"), fermer)


func _bouton(texte: String, action: Callable) -> void:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	boutons.add_child(b)


## Le glisser d'une capacité vers la hotbar (designer 2026-08-31, point 35).
func _glisser_liste(at: Vector2) -> Variant:
	if courant != "capacites":
		return null
	var idx := liste.get_item_at_position(at, true)
	if idx < 0 or idx >= entrees.size():
		return null
	var en: Dictionary = entrees[idx]
	if str(en.get("kind", "")) != "capacite":
		return null
	var ap := Label.new()
	ap.text = liste.get_item_text(idx)
	liste.set_drag_preview(ap)   # ecrans est un CanvasLayer : l'aperçu se pose sur le Control qui glisse
	return {"hotbar_type": "capacite", "ref": int(en.index)}


func _depot_refuse(_p: Vector2, _d: Variant) -> bool:
	return false


func _depot_rien(_p: Vector2, _d: Variant) -> void:
	pass


func _sur_selection(i: int) -> void:
	selection = i
	_montrer_detail()


func _montrer_detail() -> void:
	if entrees.is_empty() or selection >= entrees.size():
		detail.text = ""
		return
	var en: Dictionary = entrees[selection]
	if courant == "charger":   # le portrait suit la ligne pointée, flèches comme souris (designer 2026-09-02)
		_portrait_partie(str(en.get("id", "")))
	match str(en.get("kind", "")):
		"objet":
			detail.text = texte_objet(str(en.uid))
			if courant == "inventaire":
				var it_p: Dictionary = main.sim.items.get(str(en.uid), {})
				# Tout objet montre son Wu Xing (point 65) — sauf s'il n'est pas identifié : on ne lit
				# pas l'élément d'une fiole dont on ignore encore ce qu'elle contient.
				penta_objet.visible = not main.sim.inconnu(it_p)
				penta_objet.montrer({"elements": main.sim.vecteur_objet(it_p)})
				inventaire_visuel.rafraichir_selection()
		"recette", "ingredient":
			detail.text = texte_recette(en.plan)
			if courant == "atelier":
				atelier_visuel.rafraichir_selection()
		"texte":
			detail.text = str(en.texte)
		"donner", "reprendre":
			detail.text = texte_objet(str(en.uid))
		"achat", "vente":   # on n'achète plus à l'aveugle : la fiche et le Wu Xing de l'objet en vitrine (point 65)
			var pr: Dictionary = en.get("prix", {})
			var ligne := tr("ui.commerce.detail_achat").format({"prix": int(pr.get("prix", 0)), "or": int(main.joueur().get("or", 0))}) if str(en.kind) == "achat" else tr("ui.commerce.detail_vente").format({"prix": int(pr.get("achat", 0))})
			detail.text = ligne + "

" + texte_objet(str(en.uid))
			var it_c: Dictionary = main.sim.items.get(str(en.uid), {})
			penta_objet.visible = not main.sim.inconnu(it_c)
			penta_objet.montrer({"elements": main.sim.vecteur_objet(it_c)})
		"option", "quete", "cellule", "resident", "stock", "fonction", "voisin", "competence_entrainer", "menu", "contexte", "capacite", "nouvelle_capacite", "module_composer", "triche", "triche_catalogue", "triche_item", "titre", "monde", "options", "charger_slot":
			detail.text = str(en.get("texte", ""))
		"creation":
			detail.text = _detail_creation(str(en.id))
		"achat", "vente":
			var p: Dictionary = en.prix
			detail.text = texte_objet(str(en.uid)) + "\n\n" + tr("ui.prix.detail").format({"prix": int(p.prix), "base": p.base, "marge": p.marge, "qualite": p.qualite, "rarete": p.rarete, "rep": p.rep}) \
				+ "\n" + (tr("ui.prix.vente").format({"n": int(p.prix)}) if en.kind == "achat" else tr("ui.prix.achat").format({"n": int(p.achat)}))
		_:
			detail.text = ""


func _action_principale() -> void:
	if entrees.is_empty() or selection >= entrees.size():
		return
	var en: Dictionary = entrees[selection]
	var j: Dictionary = main.joueur()
	match str(en.get("kind", "")):
		"objet":
			if bool(en.get("equipe", false)):
				main.sim.intention(j.id, {"type": "desequiper", "slot": str(en.slot)})
			else:
				main.sim.intention(j.id, {"type": "equiper", "objet": str(en.uid)})
		"recette":
			main.sim.intention(j.id, {"type": "fabriquer", "recette": str(en.plan.id)})
		"ingredient":
			main.sim.basculer_ingredient(j, str(en.rid), str(en.uid))
		"option":
			_option(str(en.option))
			return
		"achat":
			main.sim.intention(j.id, {"type": "acheter", "pnj": pnj_id, "objet": str(en.uid)})
		"vente":
			main.sim.intention(j.id, {"type": "vendre", "pnj": pnj_id, "objet": str(en.uid)})
		"quete":
			var q: Dictionary = en.quete
			if q.etat == "offerte":
				main.sim.intention(j.id, {"type": "accepter_quete", "pnj": pnj_id, "quete": str(q.uid)})
			elif q.etat == "terminee":
				main.sim.intention(j.id, {"type": "rendre_quete", "pnj": pnj_id, "quete": str(q.uid)})
		"cellule":
			var roles: Array = main.sim.regles.r.royaume.roles
			var cell: Vector2i = en.cellule
			var actuel := str(main.sim.monde.claims[cell].role)
			main.sim.changer_role(cell, str(roles[(roles.find(actuel) + 1) % roles.size()]))
		"resident":
			main.sim.desassigner(j, str(en.id))
		"stock":
			main.sim.retirer_stock(j, str(en.cle))
		"donner", "reprendre":
			main.sim.echanger(j, pnj_id, str(en.uid), str(en.kind))
		"fonction":
			main.sim.intention(j.id, {"type": "assigner", "pnj": pnj_id, "fonction": str(en.fonction)})
			fermer()
			return
		"competence_entrainer":
			main.sim.intention(j.id, {"type": "entrainer", "pnj": pnj_id, "competence": str(en.competence)})
		"menu":
			main._action_menu(str(en.id))
			return
		"creation":
			_action_creation(str(en.id), 0 if str(en.id) == "pose" else 1)
			return
		"titre":
			match str(en.id):
				"nouvelle": main._nouvelle_partie()
				"continuer": main._charger_partie()
				"charger": ouvrir("charger")
				"options": ouvrir("options")
				"quitter": get_tree().quit()
			return
		"monde":
			if str(en.id).begins_with("opt:"):   # un réglage de génération (designer, point 49)
				_regler_monde(str(en.id).trim_prefix("opt:"), 1)   # Entrée : un pas vers le haut
				rafraichir()
				return
			match str(en.id):
				"graine": main.graine_monde = randi() % 1000000
				"commencer":
					main._commencer_monde()
					return
				"retour":
					main.fiche_monde = {}
					ouvrir("titre")
					return
		"options":
			match str(en.id):
				"langue": TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("fr") else "fr")
				"plein_ecran":
					var plein: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if plein else DisplayServer.WINDOW_MODE_FULLSCREEN)
				"retour":
					ouvrir("titre" if main.titre_ouvert else "menu")
					return
		"charger_slot":
			if str(en.id).is_empty():
				ouvrir("titre")
			else:
				main._charger_partie(str(en.id))
			return
		"capacite":
			main.sim.supprimer_capacite(j, int(en.index))
		"nouvelle_capacite":
			sequence_composee = []
			ouvrir("composer")
			return
		"module_composer":   # Entrée ajoute (même déjà présent : la séquence se cumule) ; Suppr / Retour arrière retire
			sequence_composee.append(str(en.module))
		"contexte":
			fermer()
			main._executer_option(en.opt)
			return
		"triche":
			main.sim.triche(j, str(en.id))
		"triche_catalogue":
			triche_categorie = str(en.id)
			ouvrir("triche_liste")
			return
		"triche_item":
			main.sim.triche(j, triche_categorie, str(en.id))
	rafraichir()


# ---------------------------------------------------------------- dialogue et commerce (E.23, Prix suggéré)

func ouvrir_dialogue(id: String) -> void:
	pnj_id = id
	var j: Dictionary = main.joueur()
	replique_key = main.sim.replique(main.sim.entites[id], j)
	ouvrir("dialogue")


func _construire_dialogue(j: Dictionary) -> void:
	var pnj: Dictionary = main.sim.entites.get(pnj_id, {})
	if pnj.is_empty():
		fermer()
		return
	titre.text = tr("ui.ecran.dialogue").format({"nom": tr(pnj.name_key), "fonction": tr(GameData.entree("functions", str(pnj.get("fonction", "oisif"))).name_key)})
	if pnj.has("boutique"):
		titre.text += tr("ui.dialogue.boutique").format({"boutique": tr(GameData.entree("shop_types", str(pnj.boutique)).name_key)})
	if pnj.has("guilde"):
		titre.text += tr("ui.dialogue.guilde").format({"guilde": tr("guilde.%s.name" % str(pnj.guilde))})
	if not str(pnj.get("titre", "")).is_empty():
		titre.text += tr("ui.dialogue.titre").format({"titre": tr(str(pnj.titre))})
	var fam: Dictionary = pnj.get("family", {})
	var ftxt: Array[String] = []
	if not str(fam.get("spouse", "")).is_empty() and main.sim.entites.has(str(fam.spouse)):
		ftxt.append(tr("famille.conjoint").format({"nom": tr(main.sim.entites[str(fam.spouse)].name_key)}))
	for pid in fam.get("child_of", []):
		if main.sim.entites.has(str(pid)):
			ftxt.append(tr("famille.enfant").format({"nom": tr(main.sim.entites[str(pid)].name_key)}))
	if not fam.get("parent_of", []).is_empty():
		ftxt.append(tr("famille.parent").format({"n": fam.parent_of.size()}))
	if not ftxt.is_empty():
		liste.add_item(tr("ui.dialogue.famille").format({"texte": " · ".join(ftxt)}), null, false)
		entrees.append({"kind": "texte", "texte": ""})
	var rel := int(pnj.get("social", {}).get("relations", {}).get(j.id, 0))
	liste.add_item(tr("ui.ecran.parler"))
	entrees.append({"kind": "option", "option": "parler"})
	if "commerce_possible" in pnj.get("tags", []):
		liste.add_item(tr("ui.ecran.commercer"))
		entrees.append({"kind": "option", "option": "commercer"})
	if "quetes" in pnj.get("tags", []):
		liste.add_item(tr("ui.ecran.quetes"))
		entrees.append({"kind": "option", "option": "quetes"})
	if pnj.has("assignation") and not pnj.has("maitre"):   # Compagnons : le suiveur territorial
		liste.add_item(tr("ui.ecran.suiveur"))
		entrees.append({"kind": "option", "option": "suiveur"})
	if bool(pnj.get("suiveur_local", false)):
		liste.add_item(tr("ui.ecran.suiveur_stop"))
		entrees.append({"kind": "option", "option": "suiveur_stop"})
	if pnj.has("maitre"):
		liste.add_item(tr("ui.ecran.incarner"))
		entrees.append({"kind": "option", "option": "incarner"})
		liste.add_item(tr("ui.ecran.suivre"))
		entrees.append({"kind": "option", "option": "suivre"})
		liste.add_item(tr("ui.ecran.attendre"))
		entrees.append({"kind": "option", "option": "attendre"})
		liste.add_item(tr("ui.ecran.posture").format({"posture": tr("posture." + str(pnj.get("posture", "defensive")))}))
		entrees.append({"kind": "option", "option": "posture"})
		liste.add_item(tr("ui.ecran.retour"))
		entrees.append({"kind": "option", "option": "retour"})
		liste.add_item(tr("ui.ecran.repli"))
		entrees.append({"kind": "option", "option": "repli"})
		liste.add_item(tr("ui.ecran.echanger"))
		entrees.append({"kind": "option", "option": "echanger"})
		if main.sim.monde != null and main.sim.monde.claims.has(main.sim._cell_de(pnj.pos)):
			liste.add_item(tr("ui.ecran.assigner"))
			entrees.append({"kind": "option", "option": "assigner"})
	else:
		var def: Dictionary = GameData.catalogues.creatures.get(str(pnj.def), {})
		var rc: Dictionary = def.get("recruitable", {"method": "jamais"})
		if (str(rc.get("method", "")) == "relation" and rel >= int(rc.get("threshold", 60)) - 10) or bool(pnj.get("recrutable_hors_condition", false)):
			liste.add_item(tr("ui.ecran.recruter"))
			entrees.append({"kind": "option", "option": "recruter"})
	if str(pnj.get("maitre", "")) == j.id or pnj.has("assignation"):
		var betail: bool = str(pnj.get("statut_habitat", "normal")) == "betail"
		liste.add_item(tr("ui.ecran.resident" if betail else "ui.ecran.betail"))
		entrees.append({"kind": "option", "option": "statut_habitat"})
	if "entraineur" in pnj.get("tags", []):
		liste.add_item(tr("ui.ecran.entrainer"))
		entrees.append({"kind": "option", "option": "entrainer"})
	var t_pnj = GameData.catalogues.classes.get(str(pnj.get("classe", "")), {}).get("talent")
	if t_pnj != null and str(t_pnj) != "sans_maitre" and (main.sim.a_talent(j, "sans_maitre") or main.sim.a_talent(j, "polyvalent")):
		liste.add_item(tr("ui.ecran.apprendre") + " — " + tr(GameData.entree("talents", str(t_pnj)).name_key))
		entrees.append({"kind": "option", "option": "apprendre_talent"})
	if "pretre" in pnj.get("tags", []):
		var ame: String = main.sim.ame_dans_sac(j)
		liste.add_item(tr("ui.ecran.ressusciter").format({"cout": main.sim.cout_resurrection(j, ame, true)}) if not ame.is_empty() else tr("ui.ecran.ressusciter_rien"), null, not ame.is_empty())
		entrees.append({"kind": "option", "option": "ressusciter"})
	if "commerce_possible" in pnj.get("tags", []) and not main.sim.territoire.get("commande", {}).is_empty():
		liste.add_item(tr("ui.ecran.livrer"))
		entrees.append({"kind": "option", "option": "livrer"})
	liste.add_item(tr("ui.ecran.partir"))
	entrees.append({"kind": "option", "option": "partir"})
	for en in entrees:
		en["texte"] = "[b]%s[/b]\n« %s »\n\n%s\n\n%s" % [tr(pnj.name_key), tr(replique_key), tr("ui.dialogue.relation").format({"n": rel}) + (("  ·  " + tr("ui.dialogue.compagnon").format({"ordre": tr("ordre." + str(pnj.get("ordre", "suivre")))})) if pnj.has("maitre") else ""), fiche_pnj(pnj, j)]
	_bouton(tr("ui.ecran.parler"), func() -> void: _option("parler"))
	if "commerce_possible" in pnj.get("tags", []):
		_bouton(tr("ui.ecran.commercer"), func() -> void: _option("commercer"))


func _option(opt: String) -> void:
	var j: Dictionary = main.joueur()
	match opt:
		"parler":
			if main.sim.intention(j.id, {"type": "parler", "pnj": pnj_id}):
				replique_key = main.sim.replique(main.sim.entites[pnj_id], j) if false else replique_key
				var pnj: Dictionary = main.sim.entites[pnj_id]
				replique_key = str(main.sim.replique(pnj, j))
			rafraichir()
		"commercer":
			ouvrir("commerce")
		"quetes":
			ouvrir("quetes")
		"recruter":
			main.sim.intention(j.id, {"type": "recruter", "pnj": pnj_id})
			rafraichir()
		"suiveur":
			main.sim.suiveur_local(j, pnj_id, true)
			rafraichir()
		"suiveur_stop":
			main.sim.suiveur_local(j, pnj_id, false)
			rafraichir()
		"suivre", "attendre", "retour", "repli":
			main.sim.ordonner(j, pnj_id, opt)
			rafraichir()
		"posture":
			var cycle := ["defensive", "agressive", "eviter"]
			var pnj: Dictionary = main.sim.entites.get(pnj_id, {})
			main.sim.ordonner(j, pnj_id, cycle[(cycle.find(str(pnj.get("posture", "defensive"))) + 1) % cycle.size()])
			rafraichir()
		"echanger":
			ouvrir("echange")
		"incarner":
			if main.sim.intention(j.id, {"type": "incarner", "pnj": pnj_id}):
				fermer()
			else:
				rafraichir()
		"assigner":
			ouvrir("assigner")
		"entrainer":
			ouvrir("entrainer")
		"livrer":
			main.sim.intention(j.id, {"type": "livrer", "pnj": pnj_id})
			rafraichir()
		"apprendre_talent":
			main.sim.intention(j.id, {"type": "apprendre_talent", "pnj": pnj_id})
			rafraichir()
		"statut_habitat":
			var pnj_s: Dictionary = main.sim.entites.get(pnj_id, {})
			main.sim.intention(j.id, {"type": "statut_habitat", "pnj": pnj_id, "statut": "normal" if str(pnj_s.get("statut_habitat", "normal")) == "betail" else "betail"})
			rafraichir()
		"ressusciter":
			var ame: String = main.sim.ame_dans_sac(j)
			if not ame.is_empty():
				main.sim.intention(j.id, {"type": "ressusciter", "ame": ame, "pnj": pnj_id})
			rafraichir()
		"partir":
			fermer()


## La fiche d'un PNJ, révélée par paliers de relation (L'information comme récompense).
func fiche_pnj(pnj: Dictionary, j: Dictionary) -> String:
	var sim = main.sim
	var palier: int = sim.palier_info(pnj, j)
	if palier == 0:
		return tr("ui.fiche.apparence")
	var l: Array[String] = [tr("ui.fiche.base").format({"nom": tr(pnj.name_key), "fonction": tr(GameData.entree("functions", str(pnj.get("fonction", "oisif"))).name_key), "village": str(pnj.get("village", "—"))})]
	if palier >= 2:
		var nd: Dictionary = sim.progression.niveaux_derives(pnj)
		l.append(tr("ui.fiche.age").format({"genre": tr("genre." + str(pnj.get("genre", "m"))), "age": int(pnj.get("age", 30)), "categorie": tr("age." + sim.categorie_age(pnj)), "signe": str(pnj.get("nom", {}).get("culture", "—")), "niveau": int(round(maxf(nd.combat, nd.general)))}))
	if palier >= 3:
		var comps: Array[String] = []
		for cle in pnj.competences.keys():
			if int(pnj.competences[cle]) > 0:
				comps.append("%s %d" % [tr(sim._nom_competence(cle)), int(pnj.competences[cle])])
		var equip: Array[String] = []
		for slot in pnj.equipement.keys():
			equip.append(main.nom_objet(sim.nom_objet(pnj.equipement[slot])))
		l.append(tr("ui.fiche.competences").format({"liste": " · ".join(comps) if not comps.is_empty() else "—", "equip": " · ".join(equip) if not equip.is_empty() else "—"}))
	if palier >= 4:
		l.append(tr("ui.fiche.gouts").format({"tags": " · ".join(pnj.get("tags", []))}))
	if palier >= 5:
		l.append(tr("ui.fiche.tout"))
		pnj["recrutable_hors_condition"] = true
	return "\n".join(l)


func _construire_quetes(j: Dictionary) -> void:
	var sim = main.sim
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	if pnj.is_empty():
		fermer()
		return
	var g: Dictionary = j.get("guildes", {}).get("guerriers", {"xp": 0, "rang": 0})
	titre.text = tr("ui.quetes.titre").format({"nom": tr(pnj.name_key), "guilde": tr("guilde.guerriers.name"), "rang": tr("rang." + str(sim.regles.r.guildes.rangs[int(g.rang)])), "xp": int(g.xp)})
	var offertes: Array = sim.quetes_offertes(pnj, j)
	if offertes.is_empty():
		liste.add_item(tr("ui.quetes.refus") if sim.relation_de(pnj, j) < int(sim.regles.r.reputation.quetes_seuil) else tr("ui.quetes.aucune"))
		entrees.append({"kind": "texte", "texte": ""})
	for q in offertes:
		if q.etat != "offerte":
			continue
		liste.add_item(tr("ui.quetes.offerte").format({"texte": _texte_quete(q)}))
		entrees.append({"kind": "quete", "quete": q, "texte": _texte_quete(q) + "\n" + tr("ui.quetes.recompense").format({"or": int(q.or), "xp": int(q.xp)})})
	for q in j.get("quetes", []):
		if q.etat == "en_cours" or q.etat == "terminee":
			var texte: String = _texte_quete(q)
			liste.add_item((tr("ui.quetes.terminee") if q.etat == "terminee" else tr("ui.quetes.en_cours")).format({"texte": texte, "fait": int(q.fait), "count": int(q.count)}))
			entrees.append({"kind": "quete", "quete": q, "texte": texte + "\n" + tr("ui.quetes.recompense").format({"or": int(q.or), "xp": int(q.xp)})})
	_bouton(tr("ui.ecran.accepter"), _action_principale)
	_bouton(tr("ui.ecran.rendre"), _action_principale)


func _construire_commerce(j: Dictionary) -> void:
	var pnj: Dictionary = main.sim.entites.get(pnj_id, {})
	if pnj.is_empty():
		fermer()
		return
	var cm: Dictionary = main.sim.regles.r.commerce
	titre.text = tr("ui.ecran.commerce").format({"nom": tr(pnj.name_key), "or": str(int(pnj.get("or", 0))) if main.sim.a_talent(j, "oeil_du_prix") else tr("ui.commerce.bourse_cachee"), "joueur": int(j.get("or", 0))})
	liste.add_item(tr("ui.commerce.stock"), null, false)
	entrees.append({"kind": "texte", "texte": ""})
	for uid in pnj.get("stock", []):
		var p: Dictionary = main.sim.prix_suggere(uid, pnj, j)
		liste.add_item("%s — %d or" % [_nom_court(uid), int(p.prix)])
		entrees.append({"kind": "achat", "uid": uid, "prix": p})
	liste.add_item(tr("ui.commerce.sac").format({"pct": int(float(cm.achat_ratio) * 100.0)}), null, false)
	entrees.append({"kind": "texte", "texte": ""})
	for uid in j.sac:
		var p2: Dictionary = main.sim.prix_suggere(uid, pnj, j)
		liste.add_item("%s — %d or" % [_nom_court(uid), int(p2.achat)])
		entrees.append({"kind": "vente", "uid": uid, "prix": p2})
	_bouton(tr("ui.ecran.acheter"), _action_principale)
	_bouton(tr("ui.ecran.vendre"), _action_principale)


# ---------------------------------------------------------------- territoire (Population et exploitation, Entretien et taxes)

func _construire_gestion(j: Dictionary) -> void:
	var sim = main.sim
	if sim.monde == null:
		fermer()
		return
	var t: Dictionary = sim.territoire
	titre.text = tr("ui.ecran.gestion").format({"n": sim.monde.claims.size(), "pnj": sim.residents().size(), "tresor": int(t.tresor), "dette": int(t.dette), "prev": sim.previsionnel()})
	var cells: Array = sim.monde.claims.keys()
	cells.sort()
	for cell in cells:
		liste.add_item(tr("ui.gestion.cellule").format({"x": cell.x, "y": cell.y, "role": tr("role." + str(sim.monde.claims[cell].role)), "camp": tr("ui.gestion.camp") if cell == sim.monde.cellule_camp else ""}))
		entrees.append({"kind": "cellule", "cellule": cell, "texte": tr("ui.gestion.role_aide")})
	for x in sim.residents():
		liste.add_item(tr("ui.gestion.resident").format({"nom": tr(x.name_key), "fonction": tr(GameData.entree("functions", str(x.assignation.fonction)).name_key), "betail": tr("ui.gestion.betail") if str(x.get("statut_habitat", "normal")) == "betail" else "", "humeur": int(x.get("humeur", 60)), "facteur": "%.2f" % sim.facteur_humeur(x)}))
		var pr: Dictionary = sim.production_de(x)
		entrees.append({"kind": "resident", "id": x.id, "texte": tr("ui.gestion.resident_aide") + "\n" + str(pr)})
	for cle in t.stocks.keys():
		liste.add_item(tr("ui.gestion.stock").format({"nom": str(cle).split("|")[0], "n": int(t.stocks[cle])}))
		entrees.append({"kind": "stock", "cle": cle, "texte": tr("ui.gestion.stock_aide")})
	for r in t.rapports:
		liste.add_item(tr("ui.gestion.rapport").format({"texte": tr("journal.rapport_semaine").format(r)}), null, false)
		entrees.append({"kind": "texte", "texte": tr("journal.rapport_semaine").format(r)})
	var gouv: String = tr(GameData.entree("governments", str(t.gouvernance)).name_key) if not str(t.gouvernance).is_empty() else "—"
	var trans: String = tr("ui.gestion.transition").format({"cible": tr(GameData.entree("governments", str(t.gouvernance_cible)).name_key), "n": int(t.transition)}) if int(t.transition) > 0 else ""
	var dr: Dictionary = t.dernier_raid
	var raid_txt: String = tr("ui.gestion.aucun_raid") if dr.is_empty() else tr("ui.gestion.raid").format({"force": dr.force, "defense": dr.defense, "issue": tr("ui.gestion.victoire" if bool(dr.victoire) else "ui.gestion.defaite"), "perte": int(round(float(dr.perte) * 100.0))})
	liste.add_item(tr("ui.gestion.royaume").format({"statut": tr("ui.gestion.royaume_statut" if bool(t.royaume) else "ui.gestion.campement"), "gouv": gouv, "transition": trans, "defense": "%.1f" % sim.defense_totale(), "valeur": int(sim.valeur_territoire()), "raid": raid_txt}), null, false)
	entrees.append({"kind": "texte", "texte": tr("ui.gestion.gouv_aide")})
	for roy in sim.royaumes_voisins():
		var accord: String = str(t.accords.get(str(roy.id), ""))
		liste.add_item(tr("ui.gestion.voisin").format({"nom": roy.nom, "gouv": tr(GameData.entree("governments", str(roy.government_type)).name_key), "n": roy.territory_cells.size(), "rep": int(j.get("reputations", {}).get(str(roy.id), 0)), "rel": tr("relation." + sim.relation_royaume(j, roy)), "accord": tr("accord." + accord) if not accord.is_empty() else tr("accord.aucun")}))
		entrees.append({"kind": "voisin", "id": str(roy.id), "texte": tr("ui.gestion.voisin_aide") + "\n" + _lois_txt(roy)})
	var npieces := 0
	var loges := 0
	for cell0 in sim.monde.claims.keys():
		var ps: Array = sim.pieces_de_cellule(cell0)
		npieces += ps.size()
		for x in sim.residents():
			if not sim._piece_du_lit(x.get("lit", Vector2i(-1, -1)), ps).is_empty():
				loges += 1
	liste.add_item(tr("ui.gestion.pieces").format({"n": npieces, "logees": loges}), null, false)
	entrees.append({"kind": "texte", "texte": ""})
	var mures := 0
	for c in t.cultures.values():
		if bool(c.mure):
			mures += 1
	liste.add_item(tr("ui.gestion.boutique").format({"caisse": int(t.caisse), "marge": "%.2f" % float(t.marge), "etals": t.etals.size(), "clients": "%.1f" % float(t.clients)}), null, false)
	entrees.append({"kind": "texte", "texte": ""})
	liste.add_item(tr("ui.gestion.parcelles").format({"n": t.cultures.size(), "mures": mures}), null, false)
	entrees.append({"kind": "texte", "texte": ""})
	var nv := 0
	var especes: Array[String] = []
	for esp in t.get("registre", {}).keys():
		nv += t.registre[esp].size()
		especes.append(tr(GameData.entree("species", str(esp)).name_key))
	liste.add_item(tr("ui.gestion.elevage").format({"n": nv, "especes": ", ".join(especes) if not especes.is_empty() else "—"}), null, false)
	entrees.append({"kind": "texte", "texte": ""})
	var cmd: Dictionary = t.get("commande", {})
	liste.add_item(tr("ui.gestion.commande").format({"espece": tr(GameData.entree("species", str(cmd.espece)).name_key), "couleur": cmd.couleur, "motif": cmd.motif, "or": int(cmd.or), "chatoyant": tr("ui.gestion.commande_chatoyant") if bool(cmd.get("chatoyant", false)) else ""}) if not cmd.is_empty() else tr("ui.gestion.commande_aucune"), null, false)
	entrees.append({"kind": "texte", "texte": ""})
	_bouton(tr("ui.ecran.deposer"), func() -> void: main.sim.deposer(main.joueur(), 50); rafraichir())
	_bouton(tr("ui.ecran.retirer"), func() -> void: main.sim.retirer(main.joueur(), 50); rafraichir())


func _lois_txt(roy: Dictionary) -> String:
	var sim = main.sim
	var l: Array[String] = []
	# Le dirigeant, la vacance, les villages connus, la diplomatie (Familles et succession, Gouvernance).
	var dirigeant := ""
	for x in sim.vivants():
		if str(x.get("royaume", "")) == str(roy.id) and str(x.get("fonction", "")) == "dirigeant":
			dirigeant = tr(x.name_key) + ((" — " + tr(str(x.titre))) if not str(x.get("titre", "")).is_empty() else "")
	if sim.monde.vacances.has(str(roy.id)):
		dirigeant = tr("ui.carte.vacance") + " (%d sem.)" % maxi(0, int(sim.monde.vacances[str(roy.id)]) - int(sim.monde.semaine_courante))
	if dirigeant.is_empty():
		dirigeant = tr("ui.royaume.dirigeant_inconnu")
	var villages: Array[String] = []
	for nom in sim.monde.villages.keys():
		if str(sim.monde.villages[nom].get("royaume", "")) == str(roy.id):
			villages.append(str(nom) + (" (conquis)" if not str(sim.monde.villages[nom].get("conquis_par", "")).is_empty() else ""))
	var diplo: Array[String] = []
	for autre in roy.get("diplomacy", {}).keys():
		diplo.append("%s : %s" % [str(autre), tr("relation." + str(roy.diplomacy[autre]))])
	l.append(tr("ui.royaume.fiche").format({"race": tr("race.%s.name" % str(roy.get("race", "humain"))), "culture": str(roy.get("culture", "")), "capitale": "(%d,%d)" % [roy.capital_poi.x, roy.capital_poi.y], "dirigeant": dirigeant,
		"villages": ", ".join(villages) if not villages.is_empty() else "—", "diplomatie": " · ".join(diplo) if not diplo.is_empty() else "—", "base_rate": int(round(float(roy.taxes.base_rate) * 100.0))}))
	for loi in roy.laws:
		l.append("%s → %s" % [str(loi.target), str(loi.consequence)])
	var tarifs: Array[String] = []
	for cat in roy.tariffs.keys():
		tarifs.append("%s %d %%" % [str(cat), int(round(float(roy.tariffs[cat]) * 100.0))])
	var fiche: String = l[0]
	l.remove_at(0)
	return fiche + "\nlois : " + (" · ".join(l) if not l.is_empty() else "aucune") + "\ndouanes : " + (" · ".join(tarifs) if not tarifs.is_empty() else "—") + " (défaut %d %%)" % int(round(float(roy.taxes.tariff_default) * 100.0))


## Le registre d'élevage (Vivarium — registre et paliers) : une ligne par espèce, le détail d'une seule à la fois.
func _construire_registre(_j: Dictionary) -> void:
	var sim = main.sim
	var t: Dictionary = sim.territoire
	var reg: Dictionary = t.get("registre", {})
	var nv := 0
	for esp in reg.keys():
		nv += reg[esp].size()
	var pal: Dictionary = sim.paliers_elevage()
	var atteints: Array[String] = []
	for a in pal.atteints:
		atteints.append(tr(str(a)).format({"n": pal.get(str(a).trim_prefix("palier."), 0)}))
	titre.text = tr("ui.ecran.registre").format({"n": nv, "especes": reg.size(), "total": GameData.catalogues.species.size(), "paliers": ", ".join(atteints) if not atteints.is_empty() else tr("ui.registre.paliers_aucun")})
	if reg.is_empty():
		liste.add_item(tr("ui.registre.aucun"), null, false)
		entrees.append({"kind": "texte", "texte": ""})
		return
	var ids: Array = reg.keys()
	ids.sort()
	for esp in ids:
		var e: Dictionary = GameData.entree("species", str(esp))
		var recs: Dictionary = t.get("records", {}).get(esp, {})
		var rtxt := ""
		var lignes: Array[String] = []
		for nom in recs.keys():
			if recs[nom] is float:
				rtxt += tr("ui.registre.record").format({"locus": str(nom), "v": "%.2f" % float(recs[nom])})
				lignes.append("%s : record %.2f" % [str(nom), float(recs[nom])])
			elif recs[nom] is Dictionary:
				var als: Array = recs[nom].keys()
				als.sort()
				lignes.append("%s : allèles vus %s" % [str(nom), ", ".join(als)])
		var nch: int = int(t.get("chatoyants", {}).get(esp, 0))
		liste.add_item(tr("ui.registre.espece").format({"nom": tr(e.name_key), "mode": str(e.get("registre", "grille")), "n": reg[esp].size(), "possibles": sim.varietes_possibles(str(esp)), "records": rtxt + (tr("ui.registre.chatoyants").format({"n": nch}) if nch > 0 else "")}))
		lignes.append_array(_detail_registre(str(e.get("registre", "grille")), reg[esp].keys()))
		entrees.append({"kind": "texte", "texte": "\n".join(lignes)})


## Le détail d'une espèce selon son mode de registre (Vivarium — registre et paliers : six modes).
func _detail_registre(mode: String, cles: Array) -> Array[String]:
	var lignes: Array[String] = []
	match mode:
		"records", "studbook":   # les variétés vues, une par ligne (les records sont déjà en en-tête)
			var vues: Array = cles.duplicate()
			vues.sort()
			for cle in vues:
				lignes.append(tr("ui.registre.variete").format({"v": str(cle).replace("|", " · ")}))
		"sequences":   # les rythmes observés
			var seqs: Array = []
			for cle in cles:
				var parts: PackedStringArray = str(cle).split("|")
				if parts.size() > 1 and not (parts[1] in seqs):
					seqs.append(parts[1])
			seqs.sort()
			for s2 in seqs:
				lignes.append(tr("ui.registre.sequence").format({"s": str(s2).replace(",", " ")}))
		"galerie", "familles":   # une entrée par combinaison, groupée par première composante
			var par: Dictionary = {}
			for cle in cles:
				var parts: PackedStringArray = str(cle).split("|")
				var tete := parts[0]
				if not par.has(tete):
					par[tete] = []
				par[tete].append(" · ".join(Array(parts).slice(1)))
			var tetes: Array = par.keys()
			tetes.sort()
			for t2 in tetes:
				var v2: Array = par[t2]
				v2.sort()
				lignes.append(tr("ui.registre.grille_ligne").format({"c": t2, "motifs": ", ".join(v2)}))
		_:   # grille, phenotypes, patrimoine : par couleur, les motifs obtenus
			var par_couleur: Dictionary = {}
			for cle in cles:
				var parts: PackedStringArray = str(cle).split("|")
				if not par_couleur.has(parts[0]):
					par_couleur[parts[0]] = []
				par_couleur[parts[0]].append(" · ".join(Array(parts).slice(1)))
			var couleurs: Array = par_couleur.keys()
			couleurs.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
			for c in couleurs:
				var ms: Array = par_couleur[c]
				ms.sort()
				lignes.append(tr("ui.registre.grille_ligne").format({"c": c, "motifs": ", ".join(ms)}))
	return lignes


func _construire_entrainer(j: Dictionary) -> void:
	var pnj: Dictionary = main.sim.entites.get(pnj_id, {})
	if pnj.is_empty():
		fermer()
		return
	titre.text = tr("ui.entrainer.titre").format({"nom": tr(pnj.name_key), "or": int(j.or)})
	var ids: Array = j.competences.keys()
	ids.sort()
	var n := 0
	for cid in ids:
		if not main.sim.peut_entrainer(pnj, str(cid)):
			continue
		n += 1
		var cout: int = main.sim.cout_entrainement(j, str(cid))
		liste.add_item(tr("ui.entrainer.competence").format({"nom": tr(main.sim._nom_competence(str(cid))), "niveau": int(j.competences[cid]), "potentiel": int(j.potentiels.get(cid, main.sim.regles.r.progression.potentiel_defaut)), "cout": cout}))
		entrees.append({"kind": "competence_entrainer", "competence": str(cid), "texte": tr("ui.entrainer.competence").format({"nom": tr(main.sim._nom_competence(str(cid))), "niveau": int(j.competences[cid]), "potentiel": int(j.potentiels.get(cid, main.sim.regles.r.progression.potentiel_defaut)), "cout": cout})})
	if n == 0:
		liste.add_item(tr("ui.entrainer.aucune"), null, false)
		entrees.append({"kind": "texte", "texte": ""})


func _texte_quete(q: Dictionary) -> String:
	return tr(q.text_key).format({"count": int(q.count), "objet": tr(GameData.entree("items", str(q.objet)).name_key) if q.has("objet") else "", "destination": str(q.get("destination", ""))})


## Les capacités du joueur (Structure compétences-modules-slots) : la liste, et la porte vers la composition.
func _construire_capacites(j: Dictionary) -> void:
	var slots: Dictionary = main.sim.slots_capacites(j)
	titre.text = tr("ui.ecran.capacites").format({"n": j.get("capacites", []).size(), "max": int(slots.capacites), "modules": int(slots.modules)})
	for k in j.get("capacites", []).size():
		var cap: Dictionary = j.capacites[k]
		var noms: Array[String] = []
		for m in cap.get("modules", []):
			noms.append(tr(GameData.catalogues.modules.get(str(m), {}).get("name_key", str(m))))
		liste.add_item(tr("ui.capacites.ligne").format({"nom": tr(str(cap.get("name_key", cap.id))), "modules": " → ".join(noms)}))
		entrees.append({"kind": "capacite", "index": k, "texte": _texte_capacite_plan(j, k)})
	liste.add_item(tr("ui.capacites.nouvelle"))
	entrees.append({"kind": "nouvelle_capacite", "texte": ""})


func _texte_capacite_plan(j: Dictionary, k: int) -> String:
	var plan: Dictionary = main.sim.plan_capacite(j, k)
	if plan.is_empty():
		return ""
	return _apercu_plan(plan)


## Ce qu'un module AJOUTE à la séquence en cours : la différence entre le plan avec lui et le plan sans lui
## (Structure compétences-modules-slots). Calculé par l'assembleur, avec l'arme tenue — jamais écrit à la main.
func _contribution_module(j: Dictionary, m: String, _deja_dedans: bool) -> String:
	# Entrée ajoute toujours une occurrence : la contribution est celle d'une occurrence DE PLUS (un noyau
	# répété double ses dés, une forme répétée grandit — Six types de modules).
	var avec: Array = sequence_composee.duplicate()
	var sans: Array = sequence_composee.duplicate()
	avec.append(m)
	var pa: Dictionary = main.sim.plan_sequence(j, avec)
	var ps: Dictionary = main.sim.plan_sequence(j, sans) if not sans.is_empty() else {}
	var parts: Array[String] = []
	var d_ticks := int(pa.get("ticks", 0)) - int(ps.get("ticks", 0))
	var d_res := int(pa.get("ressource", 0)) - int(ps.get("ressource", 0))
	var d_des := int(pa.get("des_bonus", 0)) - int(ps.get("des_bonus", 0))
	if d_ticks != 0:
		parts.append("%+d ticks" % d_ticks)
	if d_res != 0 or str(pa.get("monnaie", "")) != str(ps.get("monnaie", "")):
		parts.append("%+d %s" % [d_res, tr("monnaie." + str(pa.get("monnaie", ""))) if not str(pa.get("monnaie", "")).is_empty() else ""])
	if d_des != 0:
		parts.append("%+d %s" % [d_des, tr("bonus.des")])
	if pa.get("des") != null and ps.get("des") == null:
		parts.append(tr("bonus.des") + " " + str(pa.des))
	elif pa.get("des") != null and ps.get("des") != null and str(pa.des) != str(ps.des):
		parts.append("%s → %s" % [str(ps.des), str(pa.des)])   # le noyau répété : 3d6 → 6d6
	if int(pa.get("taille", 0)) != int(ps.get("taille", 0)) and not ps.is_empty():
		parts.append("%s %d → %d" % [tr("ui.composer.taille_courte"), int(ps.get("taille", 0)), int(pa.get("taille", 0))])
	if str(pa.get("geometrie", "")) != str(ps.get("geometrie", "")):
		parts.append(tr("geometrie." + str(pa.get("geometrie", ""))) + " %d–%d" % [int(pa.portee.x), int(pa.portee.y)])
	elif pa.has("portee") and ps.has("portee") and pa.portee != ps.portee:
		parts.append(tr("bonus.portee") + " %d–%d" % [int(pa.portee.x), int(pa.portee.y)])
	if int(pa.get("taille", 1)) != int(ps.get("taille", 1)):
		parts.append("%s %+d" % [tr("bonus.taille"), int(pa.get("taille", 1)) - int(ps.get("taille", 1))])
	if float(pa.get("mult", 1.0)) != float(ps.get("mult", 1.0)):
		parts.append("×%.2f" % (float(pa.get("mult", 1.0)) / maxf(0.01, float(ps.get("mult", 1.0)))))
	var els_a: Dictionary = pa.get("elements", {})
	if els_a != ps.get("elements", {}) and not els_a.is_empty():
		var noms_el: Array[String] = []
		for el in els_a.keys():
			noms_el.append(tr("element." + str(el)))
		parts.append(", ".join(noms_el))
	for ef in pa.get("effets", []):
		if not (ef in ps.get("effets", [])):
			parts.append(tr("effet." + str(ef)))
	for cle in pa.get("drapeaux", {}).keys():
		if not ps.get("drapeaux", {}).has(cle):
			parts.append(tr("drapeau." + str(cle)))
	for c: Dictionary in pa.get("conditions", []):
		var deja := false
		for c2: Dictionary in ps.get("conditions", []):
			deja = deja or str(c2.id) == str(c.id)
		if not deja:
			parts.append(tr("predicat." + str(c.get("predicat", {}).get("type", ""))))
	if parts.is_empty():
		return tr("ui.composer.contribution_nulle")
	return tr("ui.composer.contribution").format({"liste": " · ".join(parts)})


## L'aperçu exhaustif d'un plan (Vocabulaire des modules — six axes : « chaque module affiche ses valeurs
## calculées pour le personnage courant »). Une ligne par axe, et rien d'implicite.
func _apercu_plan(plan: Dictionary) -> String:
	var effets: Array[String] = []
	for ef in plan.get("effets", []):
		effets.append(tr("effet." + str(ef)))
	var err: Array[String] = []
	for er in plan.get("erreurs", []):
		err.append(str(er))
	var txt := tr("ui.composer.apercu").format({"geometrie": tr("geometrie." + str(plan.get("geometrie", ""))) + " (" + tr("origine." + str(plan.get("origine", "cible"))) + ")", "portee": "%d–%d" % [int(plan.portee.x), int(plan.portee.y)],
		"taille": int(plan.get("taille", 1)), "ticks": int(plan.get("ticks", 0)), "ressource": int(plan.get("ressource", 0)),
		"monnaie": tr("monnaie." + str(plan.monnaie)) if not str(plan.get("monnaie", "")).is_empty() else "—",
		"des": str(plan.get("des", "—")), "effets": ", ".join(effets) if not effets.is_empty() else "—",
		"erreurs": tr("ui.composer.erreurs").format({"liste": " ; ".join(err)}) if not err.is_empty() else ""})
	var fc: Vector2i = main.sim.fourchette_cout(plan)   # « aucun chiffre fixe » : le coût est une fourchette
	txt += "\n" + tr("ui.composer.cout").format({"min": fc.x, "max": fc.y, "monnaie": tr("monnaie." + str(plan.get("monnaie", ""))) if not str(plan.get("monnaie", "")).is_empty() else "—",
		"affinite": "%.2f" % float(plan.get("affinite_arme", 1.0)), "arme": tr(str(plan.get("fonct", {}).get("name_key", "functionality.mains_nues.name")))})
	if main.sim.regles.est_telegraphee(int(plan.get("ticks", 0))):   # au-delà du seuil de télégraphie : visible et interruptible
		txt += "
" + tr("ui.composer.telegraphe").format({"ticks": int(plan.get("ticks", 0)), "seuil": int(main.sim.regles.r.actions.telegraphe_seuil_ticks)})
	if main.sim.plan_par_tuile(plan):   # le prix suit la surface (Six types de modules) : le composeur le dit avant la visée
		var n: int = main.sim.surface_nominale(main.joueur(), plan)
		txt += "\n" + tr("ui.composer.surface").format({"n": n, "min": fc.x * n, "max": fc.y * n, "monnaie": tr("monnaie." + str(plan.get("monnaie", ""))) if not str(plan.get("monnaie", "")).is_empty() else "—"})
	# Les dégâts attendus, avec le détail : fourchette du dé, dés de bonus, multiplicateur.
	if plan.get("des") != null and not str(plan.get("des", "")).is_empty():
		var f := Des.fourchette(plan.des, int(plan.get("des_bonus", 0)))
		var mult := float(plan.get("mult", 1.0))
		txt += "\n" + tr("ui.composer.degats").format({"min": roundi(float(f.x) * mult), "max": roundi(float(f.y) * mult),
			"des": str(plan.des), "bonus": int(plan.get("des_bonus", 0)), "mult": "%.2f" % mult})
	if not str(plan.get("element_dominant", "")).is_empty() or not plan.get("elements", {}).is_empty():
		var els: Array[String] = []
		for el in plan.get("elements", {}).keys():
			els.append("%s %d %%" % [tr("element." + str(el)), roundi(float(plan.elements[el]) * 100.0)])
		if not els.is_empty():
			txt += "\n" + tr("ui.composer.elements").format({"liste": ", ".join(els)})
	# Les conditions : ce qu'elles exigent, ce qu'elles rendent.
	for c: Dictionary in plan.get("conditions", []):
		var bonus: Array[String] = []
		for cle in c.get("bonus", {}).keys():
			bonus.append("%s %s" % [tr("bonus." + str(cle)), str(c.bonus[cle])])
		txt += "\n" + tr("ui.composer.condition").format({"nom": tr(str(c.get("name_key", c.id))),
			"predicat": tr("predicat." + str(c.get("predicat", {}).get("type", ""))), "bonus": ", ".join(bonus) if not bonus.is_empty() else "—"})
	# Les modificateurs actifs (drapeaux) et les liaisons.
	var drap: Array[String] = []
	for cle in plan.get("drapeaux", {}).keys():
		drap.append(tr("drapeau." + str(cle)))
	if not drap.is_empty():
		txt += "\n" + tr("ui.composer.modificateurs").format({"liste": ", ".join(drap)})
	if not plan.get("liaisons", []).is_empty():
		var li: Array[String] = []
		for l: Dictionary in plan.liaisons:
			for cle in l.keys():
				li.append(tr("drapeau." + str(cle)))
		txt += "\n" + tr("ui.composer.liaisons").format({"liste": ", ".join(li)})
	if not plan.get("avertissements", []).is_empty():
		txt += "\n" + tr("ui.composer.avertissements").format({"liste": " ; ".join(PackedStringArray(plan.avertissements))})
	return txt


## Composer : les modules connus, groupés par type ; Entrée les ajoute à la séquence (ou les en retire) ; V valide.
func _construire_composer(j: Dictionary) -> void:
	var slots: Dictionary = main.sim.slots_capacites(j)
	var noms: Array[String] = []
	for m in sequence_composee:
		noms.append(tr(GameData.catalogues.modules.get(str(m), {}).get("name_key", str(m))))
	titre.text = tr("ui.ecran.composer").format({"sequence": " → ".join(noms) if not noms.is_empty() else "—", "n": sequence_composee.size(), "max": int(slots.modules)})
	# Le composeur en glisser-déposer (décision du designer, 2026-08-30) remplace la liste : slots, cartes, nom, Wu Xing.
	corps.visible = false
	composeur.visible = true
	composeur.reconstruire(j, sequence_composee.duplicate())
	_bouton(tr("ui.composer.valider"), _valider_composition)


func _valider_composition() -> void:
	var j: Dictionary = main.joueur()
	var seq: Array = composeur.sequence()
	if main.sim.composer_capacite(j, seq, composeur.nom_choisi()):
		sequence_composee = []
		composeur.groupes = {}
		composeur.nom.text = ""
		ouvrir("capacites")
	else:
		rafraichir()


## L'écran principal (Écrans d'interface, 2026-08-30) : Nouvelle partie, Continuer, Charger, Options, Quitter.
func _construire_titre() -> void:
	titre.text = tr("ui.ecran.titre")
	# Plusieurs parties, UNE sauvegarde par partie (designer 2026-09-02) : « Continuer » reprend la
	# dernière jouée, « Charger » montre les autres avec leur personnage et l'état de leur monde.
	var ids: Array[String] = ["nouvelle"]
	if not main.parties_presentes().is_empty():
		ids.append_array(["continuer", "charger"])
	ids.append_array(["options", "quitter"])
	for id in ids:
		liste.add_item(tr("ui.titre." + id))
		entrees.append({"kind": "titre", "id": id, "texte": tr("ui.titre.d_" + id)})


# ---------------------------------------------------------------- l'écran de création (Écrans d'interface, 2026-08-30)

## La fiche telle qu'elle serait créée maintenant (aperçu : stats, potentiels, kit) — sans la valider.
func _fiche_apercu() -> Dictionary:
	var c: Dictionary = main.creation
	var races: Array = GameData.catalogues.races.keys()
	races.sort()
	var classes: Array = main._classes_visibles()
	var prog: Progression = Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	var f := Etres.creer_personnage("creature.aventurier.name", races[int(c.race) % races.size()], classes[int(c.classe) % classes.size()], c.points, int(c.annee), prog, c.get("tirage", {}))
	return f


## L'apparence de l'aperçu : le bloc de la race, recouvert des loci réglés à la main (points 39 et 41).
func _apparence_apercu(fiche: Dictionary) -> Dictionary:
	var ap: Dictionary = fiche.get("apparence", {}).duplicate()
	for cle: String in main.creation.get("apparence", {}).keys():
		ap[cle] = main.creation.apparence[cle]
	return ap


## Les lignes réglables de l'apparence : les loci du catalogue, puis les deux palettes.
func _lignes_apparence(avec_visage: bool = true) -> Array:
	var cfg: Dictionary = GameData.config("apparence")
	var l: Array = []
	for locus in cfg.get("loci", []):
		if not avec_visage and not bool(locus.get("universel", false)):
			continue
		var vals: Array = []
		for v in locus.get("valeurs", []):
			vals.append(str(v))
		l.append({"id": str(locus.id), "valeurs": vals})
	for pal in (["teinte_peau", "teinte_cheveux"] if avec_visage else ["teinte_peau"]):   # sans visage : pas de couleur de cheveux
		var ids: Array = []
		for t in cfg.get("teintes_peau" if pal == "teinte_peau" else "teintes_cheveux", []):
			ids.append(str(t.id))
		l.append({"id": pal, "valeurs": ids})
	return l


func _points_creation() -> Dictionary:
	var c: Dictionary = main.creation
	var classes: Array = main._classes_visibles()
	var cl: Dictionary = GameData.entree("classes", classes[int(c.classe) % classes.size()])
	var cfg: Dictionary = GameData.config("creation")
	var total := int(cfg.get("points_base", 30)) + int(cl.get("points_creation_bonus", 0))
	var utilises := 0
	for st in main.STATS:
		utilises += int(c.points.get(st, 0))
	return {"total": total, "utilises": utilises, "restants": total - utilises, "max": int(cfg.get("max_par_stat", 10))}


## Les trois volets de la création (designer 2026-09-01, point 66) : le personnage, son apparence,
## ses poses. Une liste de vingt-cinq lignes ne se lit pas ; trois volets de huit se lisent.
const VOLETS := ["personnage", "apparence", "pose", "serments"]


func _construire_creation() -> void:
	titre.text = tr("ui.ecran.creation")
	var c: Dictionary = main.creation
	var volet := str(VOLETS[int(c.get("volet", 0)) % VOLETS.size()])
	var onglets: Array[String] = []
	for v in VOLETS:
		onglets.append(("[ %s ]" % tr("ui.creation.volet_" + v)) if v == volet else ("  %s  " % tr("ui.creation.volet_" + v)))
	liste.add_item(" ".join(onglets))
	entrees.append({"kind": "creation", "id": "volet"})
	var fiche := _fiche_apercu()
	var cfg: Dictionary = GameData.config("creation")
	var pts := _points_creation()
	var nom: String = str(c.get("nom", ""))
	if volet == "personnage":
		liste.add_item(tr("ui.creation.nom_l").format({"nom": nom if not nom.is_empty() else tr("ui.creation.nom_vide")}))
		entrees.append({"kind": "creation", "id": "nom"})
		liste.add_item(tr("ui.creation.race_l").format({"race": tr(GameData.entree("races", fiche.race).name_key)}))
		entrees.append({"kind": "creation", "id": "race"})
		liste.add_item(tr("ui.creation.classe_l").format({"classe": tr(GameData.entree("classes", fiche.classe).name_key)}))
		entrees.append({"kind": "creation", "id": "classe"})
		liste.add_item(tr("ui.creation.annee_l").format({"annee": int(c.annee), "element": tr("element." + str(fiche.signe.element)), "animal": tr("animal." + str(fiche.signe.animal))}))
		entrees.append({"kind": "creation", "id": "annee"})
		liste.add_item(tr("ui.creation.points_l").format({"restants": pts.restants, "total": pts.total}))
		entrees.append({"kind": "creation", "id": "points"})
		for st in main.STATS:
			liste.add_item(tr("ui.creation.stat_l").format({"stat": tr("stat." + st), "valeur": int(fiche.corps.stats[st]), "points": int(c.points.get(st, 0))})
				+ tr("ui.creation.stat_de").format({"de": int(c.get("tirage", {}).get(st, 0))}))
			entrees.append({"kind": "creation", "id": "stat:" + st})
	var app: Dictionary = _apparence_apercu(fiche)   # apparence : les loci visuels (designer, points 39 et 41)
	if volet == "apparence":
		for ligne in _lignes_apparence(not app.is_empty()):
			liste.add_item(tr("ui.creation.app_l").format({
				"locus": tr("ui.apparence." + str(ligne.id)),
				"valeur": tr("ui.apparence.val." + str(app.get(str(ligne.id), ligne.valeurs[0] if not ligne.valeurs.is_empty() else ""))),
			}))
			entrees.append({"kind": "creation", "id": "app:" + str(ligne.id)})
	var actions_p: Array = GameData.config("poses").get("actions", [])   # articuler ses poses (designer, point 63)
	if volet == "pose" and not actions_p.is_empty():
		var i_p: int = int(c.get("pose_action", 0)) % actions_p.size()
		liste.add_item(tr("ui.creation.pose_l").format({"action": tr(str(actions_p[i_p].name_key))}))
		entrees.append({"kind": "creation", "id": "pose"})
	if volet == "serments":   # le pari du nen : une contrainte tenue toute la partie, un don en échange
		var jures: Array = c.get("serments", [])
		var ids_s: Array = GameData.catalogues.serments.keys()
		ids_s.sort()
		for sid in ids_s:
			var sd: Dictionary = GameData.catalogues.serments[sid]
			liste.add_item(tr("ui.creation.serment_l").format({"jure": "✓" if str(sid) in jures else "·", "nom": tr(str(sd.name_key)), "desc": tr(str(sd.desc_key))}))
			entrees.append({"kind": "creation", "id": "serment:" + str(sid)})
	if volet == "apparence" and not app.is_empty():   # les réglages continus du visage (designer, point 53)
		for cur in GameData.config("apparence").get("curseurs", []):
			var vc: float = float(app.get("curseurs", {}).get(str(cur.id), float(cur.defaut)))
			liste.add_item(tr("ui.creation.curseur_l").format({"nom": tr("ui.apparence." + str(cur.id)), "valeur": "%.2f" % vc}))
			entrees.append({"kind": "creation", "id": "cur:" + str(cur.id)})
	if volet == "personnage":
		liste.add_item(tr("ui.creation.depart_l").format({"lieu": tr("ui.creation.depart_donjon" if int(c.get("depart", 0)) == 1 else "ui.creation.depart_camp")}))
		entrees.append({"kind": "creation", "id": "depart"})
	liste.add_item(tr("ui.creation.commencer"))
	entrees.append({"kind": "creation", "id": "commencer"})
	if not pose_edition.is_empty():   # le bandeau du pantin (point 63)
		var acts_t: Array = GameData.config("poses").get("actions", [])
		var nom_a := pose_edition
		for a_t in acts_t:
			if str(a_t.id) == pose_edition:
				nom_a = tr(str(a_t.name_key))
		titre.text = tr("ui.pose.editer").format({"action": nom_a})
		if not pose_segment.is_empty():
			titre.text += "  ·  " + tr("ui.pose.segment").format({"nom": pose_segment})
	_apercu_personnage(fiche)


## Le pantin (designer 2026-09-01, point 63) : en mode pose, un clic saisit le membre le plus proche
## et le glissement le fait pivoter. Rien n'est calculé ailleurs : on écrit un angle par segment.
func _pantin_entree(ev: InputEvent) -> void:
	if pose_edition.is_empty() or main.creation.is_empty():
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		# le membre réellement sous le curseur : le paperdoll sait où il a posé chaque segment (point 68)
		var local: Vector2 = (ev.position - apercu_perso.position) / apercu_perso.scale.x
		var touche: String = apercu_perso.segment_sous(local, float(GameData.config("poses").get("marge_saisie", 6.0)))
		if not touche.is_empty():
			pose_segment = touche
			_angle_saisie = _angle_souris(ev.position, touche)
			rafraichir()
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and not pose_segment.is_empty():
		# le membre suit la souris : on tourne de l'angle parcouru AUTOUR DE SON JOINT, pas d'un delta de pixels
		var a := _angle_souris(ev.position, pose_segment)
		var d := rad_to_deg(angle_difference(_angle_saisie, a))
		_angle_saisie = a
		_tourner_membre(d)


## L'angle du curseur vu depuis le joint du segment saisi — le pantin se manipule comme une marionnette.
func _angle_souris(pos: Vector2, segment: String) -> float:
	var joint: Vector2 = apercu_perso.position + apercu_perso.joint_de(segment) * apercu_perso.scale.x
	return (pos - joint).angle()


## Fait pivoter le membre saisi, dans l'amplitude autorisée par les données.
func _tourner_membre(delta: float) -> void:
	if pose_segment.is_empty():
		return
	var cfg: Dictionary = GameData.config("poses")
	var poses: Dictionary = main.creation.get("poses", {})
	var pose: Dictionary = poses.get(pose_edition, {})
	var a := float(pose.get(pose_segment, 0.0)) + delta
	pose[pose_segment] = clampf(a, -float(cfg.get("amplitude_max", 170.0)), float(cfg.get("amplitude_max", 170.0)))
	poses[pose_edition] = pose
	main.creation["poses"] = poses
	_apercu_personnage(_fiche_apercu())


## Le personnage en grand : le paperdoll du jeu, avec la teinte choisie et l'équipement de départ de la classe.
func _apercu_personnage(fiche: Dictionary) -> void:
	var e: Dictionary = fiche.duplicate(true)
	e["apparence"] = _apparence_apercu(fiche)
	var items := {}
	var equip := {}
	for id in fiche.get("equipement", []):
		var d: Dictionary = GameData.entree("items", str(id))
		if d.is_empty():
			continue
		var it: Dictionary = d.duplicate(true)
		it["uid"] = str(id)
		items[str(id)] = it
		equip[str(d.get("equip_slot", "main_principale"))] = str(id)
	e.equipement = equip
	e["orientation"] = Vector2i(1, 1)
	e["poses"] = main.creation.get("poses", {}).duplicate(true)   # le pantin montre la pose qu'on articule
	if not pose_edition.is_empty():
		e["poses"] = {"repos": e.poses.get(pose_edition, {})}
	apercu_perso.configurer(e, GameData.entree("rigs", str(e.skeleton_template)), items, GameData.catalogues.functionalities, GameData.config("palette_materiaux"))
	apercu_perso.queue_redraw()
	cadre_visage.visible = not e.get("apparence", {}).is_empty()   # pas de portrait pour qui n'a pas de visage
	portrait_perso.configurer(e, GameData.entree("rigs", str(e.skeleton_template)), items, GameData.catalogues.functionalities, GameData.config("palette_materiaux"))
	portrait_perso.queue_redraw()
	var regles := Regles.new(GameData.config("combat_rules"))   # les trois jauges du personnage à naître (point 42)
	var stats: Dictionary = fiche.corps.stats
	barres_perso.valeurs = [
		["sante", regles.sante_max(stats)],
		["endurance", regles.vigueur_max(stats)],
		["mana", regles.mana_max(stats)],
		["sang_froid", regles.sang_froid_max(stats)],
	]
	barres_perso.queue_redraw()


## Le détail de la ligne choisie : ce que change la race, la classe (talent, bonus, compétences, kit), la stat…
func _detail_creation(id: String) -> String:
	var fiche := _fiche_apercu()
	var race: Dictionary = GameData.entree("races", fiche.race)
	var cl: Dictionary = GameData.entree("classes", fiche.classe)
	var pts := _points_creation()
	var l: Array[String] = []
	match id:
		"nom":
			l.append(tr("ui.creation.d_nom").format({"max": int(GameData.config("creation").get("nom_max", 16))}))
		"race":
			l.append("[b]%s[/b]" % tr(race.name_key))
			l.append(tr("ui.creation.talent_race").format({"talent": main._texte_talent(str(race.get("talent", "")))}))
			l.append(tr("ui.creation.bonus").format({"bonus": _texte_bonus(race.get("bonus_stats", {}))}))
			l.append(tr("ui.creation.xp_mult").format({"mult": "%.2f" % float(race.get("xp_mult", 1.0)), "vie": int(race.get("lifespan", 80))}))
			l.append(tr("ui.creation.d_race"))
		"classe":
			l.append("[b]%s[/b]" % tr(cl.name_key))
			l.append(tr("ui.creation.talent_classe").format({"talent": main._texte_talent(str(cl.get("talent", "")))}))
			l.append(tr("ui.creation.bonus").format({"bonus": _texte_bonus(cl.get("bonus_stats", {}))}))
			var comps: Array[String] = []
			for k in cl.get("competences", {}).keys():
				comps.append("%s %d" % [tr(GameData.catalogues.competences.get(k, {}).get("name_key", "competence.%s.name" % k)), int(cl.competences[k])])
			l.append(tr("ui.creation.competences_l").format({"liste": ", ".join(comps) if not comps.is_empty() else "—"}))
			var pots: Array[String] = []
			for k in cl.get("base_potentials", {}).keys():
				if str(k) != "_defaut":
					pots.append("%s %d" % [tr(GameData.catalogues.competences.get(k, {}).get("name_key", "competence.%s.name" % k)), int(cl.base_potentials[k])])
			l.append(tr("ui.creation.potentiels_l").format({"defaut": int(cl.get("base_potentials", {}).get("_defaut", 80)), "liste": ", ".join(pots) if not pots.is_empty() else "—"}))
			l.append(tr("ui.creation.kit_l").format({"liste": _texte_kit(cl)}))
			l.append(tr("ui.creation.d_classe"))
		"annee":
			l.append(tr("ui.creation.signe").format({"annee": int(main.creation.annee), "element": tr("element." + str(fiche.signe.element)), "animal": tr("animal." + str(fiche.signe.animal))}))
			l.append(tr("ui.creation.d_annee"))
		"points":
			l.append(tr("ui.creation.points").format({"restants": pts.restants, "total": pts.total}))
			l.append(tr("ui.creation.d_points").format({"max": pts.max}))
		"commencer":
			l.append(tr("ui.creation.d_commencer"))
		_:
			if id == "volet":
				l.append(tr("ui.creation.d_volet"))
			elif id.begins_with("cur:"):
				l.append(tr("ui.creation.d_curseur"))
			elif id.begins_with("app:"):   # le détail d'un locus visuel (designer, points 39 et 41)
				l.append(tr("ui.creation.d_apparence"))
			elif id.begins_with("stat:"):
				var st := id.trim_prefix("stat:")
				l.append("[b]%s[/b] : %d" % [tr("stat." + st), int(fiche.corps.stats[st])])
				l.append(tr("ui.creation.points").format({"restants": pts.restants, "total": pts.total}))
				l.append(tr("stat." + st + ".desc"))
	l.append("")
	l.append(tr("ui.creation.aide2"))
	return "\n".join(l)


func _texte_bonus(bonus: Dictionary) -> String:
	var parts: Array[String] = []
	for k in bonus.keys():
		parts.append("%s %+d" % [tr("stat." + str(k)), int(bonus[k])])
	return ", ".join(parts) if not parts.is_empty() else "—"


## Le kit de départ : l'équipement et le râtelier de la classe, l'établi portatif, le coffre du camp.
func _texte_kit(cl: Dictionary) -> String:
	var noms: Array[String] = []
	var vus := {}
	for id in cl.get("equipement", []) + cl.get("ratelier", []) + ["station_etabli"] + GameData.config("camp").get("coffre_depart", []):
		if vus.has(str(id)):
			continue
		vus[str(id)] = true
		var d: Dictionary = GameData.entree("items", str(id))
		noms.append(tr(str(d.get("name_key", "item.%s.name" % id))))
	return ", ".join(noms)


## Une ligne de création réagit à ← → / + − / Entrée : cycler, ajuster, ou commencer.
func _action_creation(id: String, sens: int) -> void:
	var c: Dictionary = main.creation
	var pts := _points_creation()
	match id:
		"race":
			c.race = posmod(int(c.race) + sens, GameData.catalogues.races.size())
		"classe":
			c.classe = posmod(int(c.classe) + sens, main._classes_visibles().size())
		"annee":
			c.annee = int(c.annee) + sens
		_ when id.begins_with("serment:"):   # on jure ou on retire, tant qu'on n'a pas commencé
			var sid_c := id.trim_prefix("serment:")
			var jures_c: Array = c.get("serments", []).duplicate()
			if sid_c in jures_c:
				jures_c.erase(sid_c)
			else:
				jures_c.append(sid_c)
			c["serments"] = jures_c
			rafraichir()
		"pose":   # l'action à mettre en scène ; Entrée ouvre le pantin (designer, point 63)
			var acts: Array = GameData.config("poses").get("actions", [])
			if acts.is_empty():
				return
			if sens == 0:
				pose_edition = str(acts[int(c.get("pose_action", 0)) % acts.size()].id)
				pose_segment = ""
				rafraichir()
				return
			c["pose_action"] = posmod(int(c.get("pose_action", 0)) + sens, acts.size())
		"volet":   # les trois volets de la création (designer, point 66)
			c["volet"] = posmod(int(c.get("volet", 0)) + (sens if sens != 0 else 1), VOLETS.size())
			selection = 0
		"depart":   # Départ : Camp / Donjon (designer, point 34)
			c.depart = posmod(int(c.get("depart", 0)) + sens, 2)
		"commencer":
			main._creer_personnage()
			return
		"nom", "points":
			if sens > 0:   # Entrée sur le nom ou les points : la ligne suivante
				selection = mini(selection + 1, entrees.size() - 1)
		_:
			if id.begins_with("cur:"):   # un réglage continu du visage (designer, point 53)
				var cid := id.trim_prefix("cur:")
				for cur2 in GameData.config("apparence").get("curseurs", []):
					if str(cur2.id) != cid:
						continue
					var regl: Dictionary = c.get("apparence", {})
					var curs: Dictionary = regl.get("curseurs", {})
					var v2: float = float(curs.get(cid, float(cur2.defaut))) + float(cur2.pas) * float(sens)
					curs[cid] = clampf(v2, float(cur2.min), float(cur2.max))
					regl["curseurs"] = curs
					c["apparence"] = regl
			elif id.begins_with("app:"):   # apparence : le locus suivant / précédent (designer, points 39 et 41)
				var lid := id.trim_prefix("app:")
				var courante := ""
				var valeurs: Array = []
				for ligne2 in _lignes_apparence(true):
					if str(ligne2.id) == lid:
						valeurs = ligne2.valeurs
				if valeurs.is_empty():
					return
				courante = str(_apparence_apercu(_fiche_apercu()).get(lid, valeurs[0]))
				var i2 := valeurs.find(courante)
				var suivant := str(valeurs[posmod(maxi(i2, 0) + sens, valeurs.size())])
				var reglages: Dictionary = c.get("apparence", {})
				reglages[lid] = suivant
				c["apparence"] = reglages
			elif id.begins_with("stat:"):
				var st := id.trim_prefix("stat:")
				var actuel := int(c.points.get(st, 0))
				if sens > 0 and pts.restants > 0 and actuel < pts.max:
					c.points[st] = actuel + 1
				elif sens < 0 and actuel > 0:
					c.points[st] = actuel - 1
	rafraichir()


func _touche_creation(ev: InputEventKey) -> bool:
	if entrees.is_empty() or selection >= entrees.size():
		return false
	var en: Dictionary = entrees[selection]
	var id := str(en.get("id", ""))
	match ev.keycode:
		KEY_LEFT, KEY_MINUS, KEY_KP_SUBTRACT:
			_action_creation(id, -1)
			return true
		KEY_RIGHT, KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			_action_creation(id, 1)
			return true
		KEY_BACKSPACE:
			if id == "nom":
				main.creation.nom = str(main.creation.nom).left(maxi(0, str(main.creation.nom).length() - 1))
				rafraichir()
				return true
		KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
			return false
	if id == "nom" and ev.unicode >= 32 and ev.unicode != 127:
		var nom := str(main.creation.nom)
		if nom.length() < int(GameData.config("creation").get("nom_max", 16)):
			main.creation.nom = nom + char(ev.unicode)
			rafraichir()
		return true
	return false


## L'écran Monde : la graine (aléatoire, re-tirable — aucun chiffre fixe), puis Commencer → la carte du départ.
## Change un réglage de génération d'un pas, dans ses bornes (designer 2026-08-31, point 49).
func _regler_monde(id: String, sens: int) -> void:
	for opt in GameData.config("planete").get("generation_options", []):
		if str(opt.id) != id:
			continue
		var v: float = main.option_monde(opt) + float(opt.pas) * float(sens if sens != 0 else 1)
		main.monde_options[id] = clampf(v, float(opt.min), float(opt.max))
		return


func _construire_monde() -> void:
	titre.text = tr("ui.ecran.monde")
	liste.add_item(tr("ui.monde.graine").format({"graine": int(main.graine_monde)}))
	entrees.append({"kind": "monde", "id": "graine", "texte": tr("ui.monde.d_graine")})
	for opt in GameData.config("planete").get("generation_options", []):   # les réglages du monde (designer, point 49)
		var v: float = main.option_monde(opt)
		var texte := ("%.2f" % v) if float(opt.pas) < 1.0 else str(int(v))
		liste.add_item(tr("ui.monde.option").format({"nom": tr("ui.monde.opt." + str(opt.id)), "valeur": texte}))
		entrees.append({"kind": "monde", "id": "opt:" + str(opt.id), "texte": tr("ui.monde.d_opt." + str(opt.id))})
	apercu_monde.rafraichir()   # l'aperçu suit les réglages (designer, point 49)
	liste.add_item(tr("ui.monde.commencer"))
	entrees.append({"kind": "monde", "id": "commencer", "texte": tr("ui.monde.d_commencer")})
	liste.add_item(tr("ui.monde.retour"))
	entrees.append({"kind": "monde", "id": "retour", "texte": ""})


## Les options : la langue (à chaud), le plein écran.
func _construire_options() -> void:
	titre.text = tr("ui.ecran.options")
	liste.add_item(tr("ui.options.langue").format({"langue": TranslationServer.get_locale().substr(0, 2)}))
	entrees.append({"kind": "options", "id": "langue", "texte": tr("ui.options.d_langue")})
	var plein: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	liste.add_item(tr("ui.options.plein_ecran").format({"etat": tr("ui.triche.oui" if plein else "ui.triche.non")}))
	entrees.append({"kind": "options", "id": "plein_ecran", "texte": ""})
	liste.add_item(tr("ui.options.retour"))
	entrees.append({"kind": "options", "id": "retour", "texte": ""})


## Charger : une ligne par partie (designer 2026-09-02 — plusieurs parties, une sauvegarde chacune).
## Chaque ligne dit qui on y jouait et où on en était ; le panneau de droite ajoute le portrait et
## l'état du monde. Tout vient du `resume` écrit à la sauvegarde : aucun monde n'est chargé pour cela.
func _construire_charger() -> void:
	titre.text = tr("ui.ecran.charger")
	parties_listees = main.parties_presentes()
	if parties_listees.is_empty():
		liste.add_item(tr("ui.charger.aucune"))
		entrees.append({"kind": "charger_slot", "id": "", "texte": ""})
		return
	for pa in parties_listees:
		var r: Dictionary = pa.resume
		if r.is_empty():   # une partie d'avant le résumé : on la liste quand même, sous son seul nom de dossier
			liste.add_item(tr("ui.charger.ligne_muette").format({"slot": str(pa.slot)}))
			entrees.append({"kind": "charger_slot", "id": str(pa.slot), "texte": _detail_partie(pa)})
			continue
		liste.add_item(tr("ui.charger.ligne").format({
			"nom": str(r.get("nom", pa.slot)), "niveau": int(r.get("niveau", 0)),
			"classe": _nom_de("classes", str(r.get("classe", ""))),
			"jour": int(r.get("jour", 0))}))
		entrees.append({"kind": "charger_slot", "id": str(pa.slot), "texte": _detail_partie(pa)})


## Le nom lisible d'une entrée de catalogue, ou son identifiant si le catalogue ne la connaît plus
## (une partie peut avoir été jouée avec une race ou une classe depuis renommée).
func _nom_de(catalogue: String, id: String) -> String:
	if id.is_empty():
		return "\u2014"
	var e: Dictionary = GameData.catalogues.get(catalogue, {}).get(id, {})
	return tr(str(e.get("name_key", id))) if not e.is_empty() else id


## Toutes les stats du monde d'une partie, pour le panneau de droite (demande du designer).
func _detail_partie(pa: Dictionary) -> String:
	var r: Dictionary = pa.resume
	if r.is_empty():
		return tr("ui.charger.illisible").format({"slot": str(pa.slot)})
	var biome_id := str(r.get("biome", ""))
	var ou := tr("ui.charger.en_donjon").format({"etage": int(r.get("etage", 0))}) if str(r.get("lieu", "")) == "donjon" else tr("ui.charger.en_surface")
	var l: Array[String] = [
		tr("ui.charger.perso").format({"nom": str(r.get("nom", "\u2014")), "race": _nom_de("races", str(r.get("race", ""))), "classe": _nom_de("classes", str(r.get("classe", ""))), "niveau": int(r.get("niveau", 0))}),
		tr("ui.charger.corps").format({"pv": int(r.get("sante", 0)), "pv_max": int(r.get("sante_max", 0)), "or": int(r.get("or", 0)), "sac": int(r.get("sac", 0))}),
		"",
		tr("ui.charger.temps").format({"jour": int(r.get("jour", 0)), "heure": int(r.get("heure", 0)), "saison": tr("saison." + str(r.get("saison", "printemps")))}),
		tr("ui.charger.ou").format({"ou": ou, "biome": _nom_de("biomes", biome_id)}),
		tr("ui.charger.monde").format({"graine": int(r.get("graine_monde", 0)), "vues": int(r.get("cellules_vues", 0)), "claims": int(r.get("claims", 0)), "villages": int(r.get("villages_connus", 0))}),
		tr("ui.charger.corruption").format({"n": int(r.get("corruption_camp", 0))}),
		tr("ui.charger.ecrit_le").format({"date": str(r.get("ecrit_le", "\u2014")), "slot": str(pa.slot)}),
	]
	return "\n".join(l)


## Le portrait de la partie pointée : l'être du joueur est dans sa sauvegarde et le paperdoll sait le
## dessiner tel quel — avec son équipement, puisque les instances d'objets sont sauvegardées à côté.
func _portrait_partie(slot: String) -> void:
	var pj: Variant = Sauvegarde.lire(slot, "players/joueur.json")
	if not (pj is Dictionary) or not (pj as Dictionary).has("etre"):
		cadre_perso.visible = false
		return
	var e: Dictionary = (pj as Dictionary).etre
	var items: Dictionary = {}
	var inst: Variant = Sauvegarde.lire(slot, "items.json")
	if inst is Dictionary:
		items = inst
	var rig: Dictionary = GameData.entree("rigs", str(e.get("skeleton_template", "humanoide")))
	cadre_perso.visible = true
	apercu_perso.configurer(e, rig, items, GameData.catalogues.functionalities, GameData.config("palette_materiaux"))
	apercu_perso.queue_redraw()
	cadre_visage.visible = not (e.get("apparence", {}) as Dictionary).is_empty()
	portrait_perso.configurer(e, rig, items, GameData.catalogues.functionalities, GameData.config("palette_materiaux"))
	portrait_perso.queue_redraw()
	barres_perso.valeurs = [
		["sante", int(e.get("sante_max", 0))],
		["endurance", int(e.get("endurance_max", 0))],
		["mana", int(e.get("mana_max", 0))],
	]
	barres_perso.queue_redraw()


## Le menu (Tab) : les écrans et les actions générales (Écrans d'interface, contrôles).
func _construire_menu(_j: Dictionary) -> void:
	titre.text = tr("ui.ecran.menu")
	var ids: Array = ["inventaire", "atelier", "feuille", "capacites", "carte", "gestion", "registre", "sauvegarder", "minimap_zoom", "minimap_masquer", "titre", "arene", "banc_objets", "recharger", "fermer"]
	for id in ids:
		if id in ["carte", "gestion"] and main.sim.lieu != "camp":
			continue
		liste.add_item(tr("ui.menu." + str(id)))
		entrees.append({"kind": "menu", "id": str(id), "texte": ""})


## Le menu de triche (V) — Écrans d'interface : tout obtenir, tout déclencher, sans farmer.
## Les actions simples agissent tout de suite ; les autres ouvrent la liste d'un **catalogue**
## (objets, matériaux, créatures, météo, statuts, races cachées) — rien n'est écrit en dur ici.
const TRICHE_ACTIONS: Array[String] = ["or", "soin", "invincible", "competences", "talents", "modules",
	"recettes", "heure", "semaine", "reveler", "claim", "tuer"]
const TRICHE_CATALOGUES: Array[String] = ["objet", "materiau", "creature", "meteo", "statut", "race"]

func _construire_triche(_j: Dictionary) -> void:
	titre.text = tr("ui.ecran.triche").format({"invincible": tr("ui.triche.oui" if main.sim.invincible else "ui.triche.non")})
	for id in TRICHE_ACTIONS:
		liste.add_item(tr("ui.triche." + id))
		entrees.append({"kind": "triche", "id": id, "texte": tr("ui.triche." + id)})
	for id in TRICHE_CATALOGUES:
		liste.add_item(tr("ui.triche." + id) + " …")
		entrees.append({"kind": "triche_catalogue", "id": id, "texte": tr("ui.triche." + id)})


## Les ids d'un catalogue, triés — la liste que le menu de triche parcourt.
func _ids_triche(categorie: String) -> Array:
	var ids: Array = []
	match categorie:
		"objet": ids = GameData.catalogues.items.keys()
		"materiau": ids = GameData.catalogues.materials.keys()
		"creature": ids = GameData.catalogues.creatures.keys()
		"meteo": ids = GameData.catalogues.weather_states.keys()
		"statut": ids = GameData.catalogues.status_effects.keys()
		"race": ids = GameData.catalogues.races.keys()
	ids.sort()
	return ids


func _construire_triche_liste(_j: Dictionary) -> void:
	titre.text = tr("ui.ecran.triche_liste").format({"quoi": tr("ui.triche." + triche_categorie)})
	for id in _ids_triche(triche_categorie):
		var nom := str(id)
		var fiche: Dictionary = GameData.catalogues[_CAT_TRICHE[triche_categorie]].get(id, {})
		if fiche.has("name_key"):
			nom = "%s  [color=#777]%s[/color]" % [tr(str(fiche.name_key)), id]
		liste.add_item(nom.replace("[color=#777]", "(").replace("[/color]", ")"))
		entrees.append({"kind": "triche_item", "id": str(id), "texte": nom})


const _CAT_TRICHE := {"objet": "items", "materiau": "materials", "creature": "creatures",
	"meteo": "weather_states", "statut": "status_effects", "race": "races"}


## Le clic droit : toutes les options de la tuile visée.
func _construire_contexte(_j: Dictionary) -> void:
	titre.text = tr("ui.ecran.contexte").format({"x": contexte_tuile.x, "y": contexte_tuile.y})
	if contexte_options.is_empty():
		liste.add_item(tr("ui.contexte.aucune"), null, false)
		entrees.append({"kind": "texte", "texte": ""})
		return
	for opt in contexte_options:
		liste.add_item(tr("option." + str(opt.id)))
		entrees.append({"kind": "contexte", "opt": opt, "texte": ""})


func _construire_assigner(j: Dictionary) -> void:
	var pnj: Dictionary = main.sim.entites.get(pnj_id, {})
	if pnj.is_empty():
		fermer()
		return
	titre.text = tr("ui.assigner.titre").format({"nom": tr(pnj.name_key)})
	var ids: Array = GameData.catalogues.functions.keys()
	ids.sort()
	for fid in ids:
		var f: Dictionary = GameData.catalogues.functions[fid]
		if fid in ["aventurier", "dirigeant", "oisif"]:
			continue
		var prod = f.get("produit")
		var ptxt: String = tr("ui.assigner.rien") if prod == null else (("%s or/unité" % str(prod.or)) if prod.has("or") else str(prod.get("item", prod.get("materiau", ""))))
		liste.add_item(tr(f.name_key))
		entrees.append({"kind": "fonction", "fonction": fid, "texte": tr("ui.assigner.fonction").format({"fonction": tr(f.name_key), "produit": ptxt, "rendement": str(f.get("rendement_base", 0))})})


## L'échange d'équipement avec un compagnon (Compagnons) : ton sac à donner, son équipement et son sac à reprendre.
func _construire_echange(j: Dictionary) -> void:
	var pnj: Dictionary = main.sim.entites.get(pnj_id, {})
	if pnj.is_empty():
		fermer()
		return
	titre.text = tr("ui.echange.titre").format({"nom": tr(pnj.name_key)})
	liste.add_item(tr("ui.echange.donner"), null, false)
	entrees.append({"kind": "texte", "texte": ""})
	for uid in j.sac:
		liste.add_item(_nom_court(uid))
		entrees.append({"kind": "donner", "uid": uid})
	liste.add_item(tr("ui.echange.reprendre").format({"nom": tr(pnj.name_key)}), null, false)
	entrees.append({"kind": "texte", "texte": ""})
	for slot in ["main_principale", "main_secondaire", "casque", "cuirasse", "jambieres", "anneau_1", "anneau_2", "amulette", "carquois"]:
		var uid: String = str(pnj.equipement.get(slot, ""))
		if uid.is_empty():
			continue
		liste.add_item("%s : %s" % [tr("slot." + slot), main.nom_objet(main.sim.nom_objet(uid))])
		liste.set_item_custom_fg_color(liste.item_count - 1, Color(0.85, 0.8, 0.55))
		entrees.append({"kind": "reprendre", "uid": uid})
	for uid in pnj.sac:
		liste.add_item(_nom_court(uid))
		entrees.append({"kind": "reprendre", "uid": uid})


# ---------------------------------------------------------------- inventaire

func _construire_inventaire(j: Dictionary) -> void:
	titre.text = tr("ui.ecran.inventaire").format({"n": j.sac.size()})
	var slots: Array = ["main_principale", "main_secondaire", "casque", "cuirasse", "jambieres", "anneau_1", "anneau_2", "amulette", "carquois"]
	for slot in slots:
		var uid: String = str(j.equipement.get(slot, ""))
		var nom: String = main.nom_objet(main.sim.nom_objet(uid)) if not uid.is_empty() else "—"
		liste.add_item("%s : %s" % [tr("slot." + slot), nom])
		liste.set_item_custom_fg_color(liste.item_count - 1, Color(0.85, 0.8, 0.55))
		entrees.append({"kind": "objet", "uid": uid, "equipe": true, "slot": slot} if not uid.is_empty() else {"kind": "texte", "texte": tr("ui.ecran.slot_vide")})
	liste.add_item("— " + tr("ui.ecran.sac") + " —", null, false)
	entrees.append({"kind": "texte", "texte": ""})
	for uid in j.sac:
		liste.add_item(_nom_court(uid))
		entrees.append({"kind": "objet", "uid": uid, "equipe": false})
	_bouton(tr("ui.ecran.equiper"), _action_principale)
	_bouton(tr("ui.ecran.jeter"), _jeter)
	_bouton(tr("ui.ecran.lire"), _lire)
	_bouton(tr("ui.ecran.sertir"), _sertir)
	_bouton(tr("ui.ecran.manger"), _manger)
	if main.sim.lieu == "camp":
		_bouton(tr("ui.ecran.poser"), _poser)
		_bouton(tr("ui.ecran.mur"), func() -> void: _mur(false))
		_bouton(tr("ui.ecran.porte"), func() -> void: _mur(true))
		_bouton(tr("ui.ecran.ranger"), _ranger)


## Le clic droit sur un objet du sac (designer 2026-08-31, point 46) : ses actions possibles,
## là où pointe la souris. Les entrées sont celles des boutons du bas, filtrées par le type d'objet.
func menu_objet(uid: String, ou: Vector2) -> void:
	if uid.is_empty() or main.sim == null:
		return
	for k in entrees.size():   # la ligne cliquée devient la sélection : les actions portent sur elle
		if entrees[k].get("kind", "") == "objet" and str(entrees[k].get("uid", "")) == uid:
			selection = k
			break
	var it: Dictionary = main.sim.items.get(uid, {})
	if it.is_empty():
		return
	var tags: Array = it.get("tags", [])
	var type_it := str(it.get("type", ""))
	var actions: Array = []
	if not str(it.get("equip_slot", "")).is_empty():
		actions.append(["ui.ecran.equiper", _action_principale])
	if type_it in ["grimoire", "manuel"] or "ame" in tags:
		actions.append(["ui.ecran.lire", _lire])
	if type_it == "consommable" or "nourriture" in tags:
		actions.append(["ui.ecran.manger", _manger])
	if type_it == "gemme":
		actions.append(["ui.ecran.sertir", _sertir])
	if main.sim.lieu == "camp":
		actions.append(["ui.ecran.poser", _poser])
	actions.append(["ui.ecran.jeter", _jeter])
	if menu_contextuel_objet != null:
		menu_contextuel_objet.queue_free()
	menu_contextuel_objet = PopupMenu.new()
	add_child(menu_contextuel_objet)
	for k in actions.size():
		menu_contextuel_objet.add_item(tr(str(actions[k][0])), k)
	menu_contextuel_objet.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < actions.size():
			(actions[id][1] as Callable).call())
	menu_contextuel_objet.position = Vector2i(ou)
	menu_contextuel_objet.popup()


func _nom_court(uid: String) -> String:
	var it: Dictionary = main.sim.items[uid]
	var nom: String = main.nom_objet(main.sim.nom_objet(uid))
	if it.get("type", "") == "materiau":
		nom = tr("forme." + str(it.get("forme", "brut"))).format({"materiau": nom}) + " ×%d" % int(it.quantite)
	elif int(it.get("quantite", 1)) > 1:
		nom += " ×%d" % int(it.quantite)
	return nom


func _uid_selection() -> String:
	if entrees.is_empty() or selection >= entrees.size() or entrees[selection].get("kind", "") != "objet":
		return ""
	return str(entrees[selection].uid)


func _jeter() -> void:
	var uid := _uid_selection()
	if not uid.is_empty():
		main.sim.intention(main.joueur().id, {"type": "jeter", "objet": uid})
		rafraichir()


func _lire() -> void:
	var uid := _uid_selection()
	if not uid.is_empty():
		var it: Dictionary = main.sim.items.get(uid, {})
		if "ame" in it.get("tags", []):   # l'âme d'un compagnon : le rappeler à l'autel domestique
			main.sim.intention(main.joueur().id, {"type": "ressusciter", "ame": uid})
		else:
			main.sim.intention(main.joueur().id, {"type": "lire", "objet": uid})
		rafraichir()


func _sertir() -> void:
	var uid := _uid_selection()
	var j: Dictionary = main.joueur()
	if not uid.is_empty() and j.equipement.has("main_principale"):
		if not main.sim.intention(j.id, {"type": "sertir", "objet": j.equipement.main_principale, "gemme": uid}):
			main._log(tr("journal.pas_de_sertissure"))
		rafraichir()


## La tuile devant le joueur (son orientation), sinon la première adjacente libre.
func _devant(j: Dictionary) -> Vector2i:
	var g: Grille = main.sim.grille
	var t: Vector2i = j.pos + j.orientation
	if g.dans(t) and g.contenu_de(t).is_empty() and g.occupant(t).is_empty():
		return t
	for d in Grille.DIRS:
		var v: Vector2i = j.pos + d
		if g.dans(v) and g.contenu_de(v).is_empty() and g.occupant(v).is_empty():
			return v
	return t


func _manger() -> void:
	var uid := _uid_selection()
	if not uid.is_empty():
		main.sim.intention(main.joueur().id, {"type": "manger", "objet": uid})
		rafraichir()


func _poser() -> void:
	var uid := _uid_selection()
	var j: Dictionary = main.joueur()
	if not uid.is_empty():
		main.sim.intention(j.id, {"type": "poser", "objet": uid, "vers": _devant(j)})
		rafraichir()


func _mur(porte: bool) -> void:
	var j: Dictionary = main.joueur()
	main.sim.intention(j.id, {"type": "poser_porte" if porte else "poser_mur", "vers": _devant(j)})
	rafraichir()


func _ranger() -> void:
	var uid := _uid_selection()
	var j: Dictionary = main.joueur()
	if uid.is_empty():
		return
	for d in Grille.DIRS:
		var t: Vector2i = j.pos + d
		if main.sim.grille.dans(t) and not main.sim._coffre_a(t).is_empty():
			main.sim.intention(j.id, {"type": "ranger", "objet": uid, "vers": t})
			break
	rafraichir()


## Le détail exhaustif d'un objet (Infobulle exhaustive : aucune information cachée).
func texte_objet(uid: String) -> String:
	var sim = main.sim
	var it: Dictionary = sim.items.get(uid, {})
	if it.is_empty():
		return ""
	var l: Array[String] = ["[b]%s[/b]" % main.nom_objet(sim.nom_objet(uid))]
	l.append(tr("ui.objet.type").format({"type": tr("type." + str(it.get("type", ""))), "slot": tr("slot." + str(it.equip_slot)) if not str(it.get("equip_slot", "")).is_empty() else "—", "rarete": tr("rarete." + str(it.get("rarete", "commun")))}))
	if it.has("qualite") and it.get("type", "") != "materiau":
		l.append(tr("ui.objet.qualite").format({"palier": tr("qualite." + sim.regles.palier_qualite(float(it.qualite))), "valeur": "%.2f" % float(it.qualite)}))
	if it.has("functionality"):
		var f: Dictionary = sim.fonctionnalites.get(str(it.functionality), {})
		if not f.is_empty():
			l.append(tr("ui.objet.arme").format({"des": f.degats_des, "type": tr("degats." + str(f.type_degats)), "ticks": sim.regles.ticks_attaque(f, false, it), "portee": "%d-%d" % [int(f.get("portee_min", 1)), int(f.portee)]}))
	if it.has("durete_base"):
		l.append(tr("ui.objet.durete").format({"durete": int(it.durete_base), "ref": int(sim.regles.r.degats.durete_reference), "facteur": "%.2f" % (float(it.durete_base) / float(sim.regles.r.degats.durete_reference) * float(it.get("qualite", 1.0)))}))
	if it.has("durete_composite"):
		l.append(tr("ui.objet.armure").format({"zone": tr("zone." + str(it.get("zone", ""))), "construction": tr("construction.%s.nom" % it.get("construction", "")), "durete": int(it.durete_composite), "niveau": int(it.get("niveau_construction", 0))}))
	if it.has("elements") or it.has("element"):
		var vec: Dictionary = it.get("elements", {str(it.get("element", "")): 1.0})
		var parts: Array[String] = []
		for el in vec.keys():
			parts.append("%s %d %%" % [tr("element." + str(el)), roundi(float(vec[el]) * 100.0)])
		l.append(tr("ui.objet.elements").format({"liste": " · ".join(parts)}))
	if it.has("vitesse_facteur"):
		l.append(tr("ui.objet.vitesse").format({"facteur": "%.2f" % float(it.vitesse_facteur)}))
	if it.has("composants"):
		l.append(tr("ui.objet.composants"))
		for slot in it.composants.keys():
			var c: Dictionary = it.composants[slot]
			l.append("   %s : %s — %s (%s %.2f)" % [tr("slotc." + str(slot)), tr(GameData.entree("components", str(c.composant)).name_key), tr(GameData.entree("materials", str(c.materiau)).name_key), tr("qualite." + sim.regles.palier_qualite(float(c.qualite))), float(c.qualite)])
	if it.get("type", "") == "composant":
		l.append(tr("ui.objet.composant").format({"materiau": tr(GameData.entree("materials", str(it.materiau)).name_key)}))
	if it.get("type", "") == "materiau":
		var m: Dictionary = GameData.entree("materials", str(it.materiau))
		l.append(tr("ui.objet.materiau").format({"categorie": tr("categorie." + str(m.category)), "forme": tr("forme." + str(it.get("forme", "brut"))).format({"materiau": tr(m.name_key)}), "quantite": int(it.quantite)}))
	if it.has("stats") and it.stats is Dictionary and not it.stats.is_empty():
		var st: Array[String] = []
		for k in it.stats.keys():
			st.append("%s %d" % [tr("mstat." + str(k)), roundi(float(it.stats[k]))])
		l.append(tr("ui.objet.stats").format({"liste": " · ".join(st)}))
	elif it.get("type", "") == "materiau":
		var m2: Dictionary = GameData.entree("materials", str(it.materiau))
		var st2: Array[String] = []
		for k in m2.stats.keys():
			st2.append("%s %d" % [tr("mstat." + str(k)), int(m2.stats[k])])
		l.append(tr("ui.objet.stats").format({"liste": " · ".join(st2)}))
	for ax in it.get("affixes", []):
		var a: Dictionary = GameData.catalogues.affixes.get(str(ax.id), {})
		var p: Dictionary = ax.get("params", {}).duplicate()
		p["base"] = ""
		if p.has("element"):
			p["epithete"] = tr("epithete." + str(p.element))
			p["element"] = tr("element." + str(p.element))
		l.append("   ✦ " + tr(str(a.get("name_key", ax.id))).format(p).strip_edges())
	if it.has("sertissures"):
		var s: Dictionary = it.sertissures
		l.append(tr("ui.objet.sertissures").format({"n": int(s.nombre), "contenu": str(s.contenu.size())}))
	if it.has("livre"):
		l.append(tr("ui.objet.livre").format({"domaine": tr("domaine." + str(it.livre.domaine)), "difficulte": int(it.livre.difficulte), "n": int(it.livre.n)}))
	if it.get("type", "") == "consommable":
		var pot: Array[String] = []
		for stt in it.get("potentiel", {}).keys():
			pot.append("%s +%d" % [tr(sim._nom_competence(str(stt))), int(it.potentiel[stt])])
		l.append(tr("ui.objet.consommable").format({"nutrition": int(it.get("nutrition", 0)), "soin": str(it.get("soin_des", "")) if not str(it.get("soin_des", "")).is_empty() else "—", "mana": int(it.get("mana", 0)),
			"statut": str(it.get("statut", "")) if not str(it.get("statut", "")).is_empty() else "—", "potentiel": " · ".join(pot) if not pot.is_empty() else "—", "cru": tr("ui.objet.consommable.cru") if bool(it.get("cru", false)) else ""}))
	l.append(tr("ui.objet.poids").format({"poids": "%.1f" % sim.regles.poids_objet(it, sim.fonctionnalites)}))
	if it.get("type", "") == "meuble":
		var mb: Dictionary = GameData.entree("meubles", str(it.meuble))
		var det: Array[String] = []
		if bool(mb.dormir):
			det.append(tr("ui.objet.meuble.lit"))
		if int(mb.capacite_slots) > 0:
			det.append(tr("ui.objet.meuble.slots").format({"n": int(mb.capacite_slots)}))
		if int(mb.luminosite) > 0:
			det.append(tr("ui.objet.meuble.lumiere").format({"n": int(mb.luminosite)}))
		l.append(tr("ui.objet.meuble").format({"type": str(mb.type_meuble), "details": " · ".join(det) if not det.is_empty() else "—"}))
	if it.get("type", "") == "station":
		var stn: Dictionary = GameData.entree("stations", str(it.station))
		l.append(tr("ui.objet.station").format({"poids": int(stn.poids), "competence": tr(sim._nom_competence(str(stn.craft_skill)))}))
	if not it.get("tags", []).is_empty():
		l.append("[color=#888]" + " · ".join(it.tags) + "[/color]")
	return "\n".join(l)


# ---------------------------------------------------------------- atelier

func _construire_atelier(j: Dictionary) -> void:
	var plans: Array = main.sim.recettes_disponibles(j)
	plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.faisable != b.faisable:
			return a.faisable
		return str(a.kind) < str(b.kind))
	var stations: Dictionary = main.sim.stations_de(j)
	var noms: Array[String] = []
	for st in stations.keys():
		noms.append(tr(GameData.entree("stations", st).name_key))
	titre.text = tr("ui.ecran.atelier").format({"stations": " · ".join(noms) if not noms.is_empty() else "—"})
	for pl in plans:
		var niv_r: int = main.sim.niveau_recette(main.joueur(), str(pl.get("id", "")))   # Axe des niveaux de recette : le niveau se lit
		liste.add_item(("✓ " if pl.faisable else "✗ ") + _titre_plan(pl) + ((" " + tr("ui.atelier.niveau_recette").format({"n": niv_r})) if niv_r > 1 else "") + "   [" + tr(GameData.entree("stations", pl.station).name_key) + "]")
		if not pl.faisable:
			liste.set_item_custom_fg_color(liste.item_count - 1, Color(0.6, 0.6, 0.6))
		entrees.append({"kind": "recette", "plan": pl})
		if str(pl.kind) == "plate":   # les ingrédients optionnels d'un plat : à cocher (Décision — Affinités de cuisine)
			for cand in main.sim.candidats_optionnels(j, pl.recette):
				liste.add_item(tr("ui.atelier.ingredient").format({"coche": "☑" if cand.inclus else "☐", "nom": main.nom_objet(main.sim.nom_objet(str(cand.uid)))}))
				entrees.append({"kind": "ingredient", "rid": str(pl.id), "uid": str(cand.uid), "plan": pl})
	if plans.is_empty():
		liste.add_item(tr("ui.atelier.vide"))
		entrees.append({"kind": "texte", "texte": tr("ui.atelier.vide")})
	_bouton(tr("ui.ecran.fabriquer"), _action_principale)


func _titre_plan(pl: Dictionary) -> String:
	match str(pl.kind):
		"composant":
			return tr(GameData.entree("components", pl.recette.component).name_key) + " ← " + tr("famille." + str(pl.recette.material_family))
		_:
			return tr(pl.recette.name_key)


## Le détail d'une recette ; pour un objet, l'obtention de chaque composant se déplie (Navigation des recettes).
func texte_recette(pl: Dictionary) -> String:
	var l: Array[String] = ["[b]%s[/b]  (%s)" % [_titre_plan(pl), tr("ui.atelier.kind." + str(pl.kind))]]
	l.append(tr("ui.recette.station").format({"station": tr(GameData.entree("stations", pl.station).name_key), "competence": tr(main.sim._nom_competence(_competence_plan(pl)))}))
	l.append(tr("ui.recette.entrees"))
	for en in pl.entrees:
		match str(pl.kind):
			"objet":
				var c: Dictionary = GameData.entree("components", en.filtre)
				l.append("   %s : %s — %s" % [tr("slotc." + str(en.slot)), tr(c.name_key), (main.nom_objet(main.sim.nom_objet(en.pile.uid)) if not en.pile.is_empty() else "[color=#c66]" + tr("ui.recette.manque") + "[/color]")])
				l.append_array(_obtention_composant(str(en.filtre), "      "))
			"composant":
				l.append("   1 × %s — %s" % [tr("famille." + en.filtre), _nom_pile(en)])
				l.append_array(_obtention_famille(str(en.filtre), "      "))
			_:
				l.append("   %d × %s — %s%s" % [int(en.besoin), _nom_filtre(en), _nom_pile(en), tr("ui.recette.optionnel") if bool(en.get("optionnel", false)) else ""])
	if str(pl.kind) == "plate" and GameData.catalogues.items.has(str(pl.sortie.get("item", ""))) and GameData.catalogues.items[str(pl.sortie.item)].get("type", "") == "consommable":
		var hp: Dictionary = main.sim.harmonie_prevue(pl)
		if not hp.is_empty():
			var parts: Array[String] = []
			for el in hp.vecteur.keys():
				if float(hp.vecteur[el]) > 0.0:
					parts.append("%s %.2f" % [tr("element." + str(el)), float(hp.vecteur[el])])
			l.append(tr("ui.recette.harmonie").format({"vecteur": " · ".join(parts), "harmonie": tr("ui.recette.harmonie_oui") if bool(hp.harmonie) else tr("ui.recette.harmonie_non").format({"n": int(hp.elements)})}))
	l.append(tr("ui.recette.sortie"))
	match str(pl.kind):
		"plate":
			var mat_s: String = tr(GameData.entree("materials", pl.sortie.materiau).name_key) if GameData.catalogues.materials.has(pl.sortie.materiau) else "?"
			l.append("   %d × %s" % [int(pl.sortie.quantite), tr("forme." + str(pl.sortie.forme)).format({"materiau": mat_s})])
		"composant":
			l.append("   " + tr(GameData.entree("components", pl.sortie.composant).name_key) + " " + tr("ui.recette.qualite_composant"))
		"objet":
			l.append("   " + tr(pl.recette.name_key) + " " + tr("ui.recette.assemblage"))
	return "\n".join(l)


func _competence_plan(pl: Dictionary) -> String:
	match str(pl.kind):
		"plate":
			return str(pl.recette.craft_skill)
		"composant":
			return str(GameData.entree("stations", pl.station).craft_skill)
		_:
			return str(pl.recette.recipe.craft_skill)


func _nom_pile(en: Dictionary) -> String:
	if en.pile.is_empty():
		return "[color=#c66]" + tr("ui.recette.manque") + "[/color]"
	return _nom_court(str(en.pile.uid))


func _nom_filtre(en: Dictionary) -> String:
	var nom: String = tr("material.%s.name" % en.filtre) if GameData.catalogues.materials.has(en.filtre) else tr("categorie." + str(en.filtre))
	return tr("forme." + str(en.forme)).format({"materiau": nom})


## Les recettes d'obtention d'un composant : connues en clair, exotiques en silhouette.
func _obtention_composant(cid: String, indent: String) -> Array[String]:
	var res: Array[String] = []
	var j: Dictionary = main.joueur()
	var ids: Array = GameData.catalogues.component_recipes.keys()
	ids.sort()
	for rid in ids:
		var r: Dictionary = GameData.catalogues.component_recipes[rid]
		if str(r.component) != cid:
			continue
		var st_nom: String = tr(GameData.entree("stations", r.station).name_key) if GameData.catalogues.stations.has(r.station) else str(r.station)
		if bool(r.unlocked_by_default) or rid in j.get("recettes_connues", []):
			res.append(indent + "← %s [%s]" % [tr("famille." + str(r.material_family)), st_nom])
			res.append_array(_obtention_famille(str(r.material_family), indent + "   "))
		else:
			res.append(indent + "[color=#777]??? — %s (%s)[/color]" % [tr("ui.recette.inconnue"), ", ".join(r.unlock_sources)])
	return res


## D'où vient une famille : la transformation plate qui produit sa forme, et ce qu'elle consomme.
func _obtention_famille(fam_id: String, indent: String) -> Array[String]:
	var res: Array[String] = []
	var fam: Dictionary = GameData.config("material_families").get(fam_id, {})
	if fam.has("tag"):
		res.append(indent + "[color=#777]" + tr("ui.recette.sans_source") + "[/color]")
		return res
	var forme := str(fam.get("forme", "brut"))
	if forme == "brut":
		res.append(indent + tr("ui.recette.recolte"))
		return res
	for rid in GameData.catalogues.recipes.keys():
		var r: Dictionary = GameData.catalogues.recipes[rid]
		if str(r.output.get("forme", "")) == forme and not r.output.has("material"):
			var entrees_txt: Array[String] = []
			for en in r.inputs:
				entrees_txt.append("%d × %s" % [int(en.amount), tr("categorie." + str(en.get("category", en.get("material", ""))))])
			res.append(indent + "← %s [%s] : %s" % [tr(r.name_key), tr(GameData.entree("stations", r.station).name_key), " + ".join(entrees_txt)])
	return res


# ---------------------------------------------------------------- feuille

func _construire_feuille(j: Dictionary) -> void:
	titre.text = tr("ui.ecran.feuille").format({"nom": tr(j.name_key)})
	var sim = main.sim
	var nd: Dictionary = sim.progression.niveaux_derives(j)
	var l: Array[String] = [tr("ui.niveaux").format({"combat": "%.1f" % nd.combat, "general": "%.1f" % nd.general})]
	l.append(tr("ui.feuille.vitaux").format({"pv": j.sante, "pv_max": j.sante_max, "end": j.endurance, "mana": j.mana, "mana_max": j.mana_max}))
	l.append("")
	l.append("[b]" + tr("ui.feuille.stats") + "[/b]")
	for st in ["force", "dexterite", "endurance", "volonte", "perception", "charisme"]:
		l.append(tr("ui.feuille.stat").format({"stat": tr("stat." + st), "valeur": j.corps.stats[st], "potentiel": int(j.potentiels.get(st, 80))}))
	var lt: Array[String] = ["[b]" + tr("ui.feuille.talents") + "[/b]"]
	for tid in sim.talents_de(j):
		var td: Dictionary = GameData.entree("talents", str(tid))
		lt.append(tr("ui.feuille.talent").format({"nom": tr(td.name_key), "desc": tr(td.desc_key)}))
	l.append("")
	l.append_array(lt)
	liste.add_item(tr("ui.feuille.stats"))
	entrees.append({"kind": "texte", "texte": "\n".join(l)})
	var cles: Array = j.competences.keys()
	cles.sort()
	var par_cat := {"combat": [], "general": []}
	for cle in cles:
		if int(j.competences[cle]) <= 0 and float(j.xp_competences.get(cle, 0.0)) <= 0.0:
			continue
		var cat: String = str(GameData.catalogues.competences.get(cle, {}).get("category", "combat"))
		par_cat[cat if par_cat.has(cat) else "combat"].append(tr("ui.feuille.ligne").format({"competence": tr(sim._nom_competence(cle)), "niveau": int(j.competences[cle]),
			"xp": int(j.xp_competences.get(cle, 0.0)), "suivant": sim.progression.xp_next(int(j.competences[cle])), "potentiel": int(j.potentiels.get(cle, 80))}))
	for cat in ["combat", "general"]:
		liste.add_item(tr("ui.feuille.cat." + cat) + " (%d)" % par_cat[cat].size())
		entrees.append({"kind": "texte", "texte": "[b]" + tr("ui.feuille.cat." + cat) + "[/b]\n" + ("\n".join(par_cat[cat]) if not par_cat[cat].is_empty() else tr("ui.feuille.aucune"))})
	var eq: Array[String] = ["[b]" + tr("ui.feuille.equipement") + "[/b]"]
	for slot in j.equipement.keys():
		eq.append("%s : %s" % [tr("slot." + str(slot)), main.nom_objet(sim.nom_objet(j.equipement[slot]))])
	liste.add_item(tr("ui.feuille.equipement"))
	entrees.append({"kind": "texte", "texte": "\n".join(eq)})


## La hotbar en bas de l'inventaire et de l'écran de capacités (designer 2026-08-31, point 35) :
## dix cases identiques au HUD, cibles du glisser-déposer ; clic droit sur une case pour la vider.
class HotbarEcran extends Control:
	const CASE := 56.0
	var ecrans: Node

	func _ready() -> void:
		custom_minimum_size = Vector2(10 * (CASE + 4.0), CASE + 22.0)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var j: Dictionary = ecrans.main.joueur()
		if j.is_empty():
			return
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, 12), tr("ui.hotbar.glisser"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.65, 0.5))
		var entrees_h: Array = ecrans.main.hotbar_entrees(j)
		for k in 10:
			var r := Rect2(Vector2(k * (CASE + 4.0), 18.0), Vector2(CASE, CASE))
			draw_rect(r, Color(0.05, 0.05, 0.08, 0.85))
			draw_rect(r, Color(0.6, 0.55, 0.4, 0.8), false, 1.0)
			draw_string(f, r.position + Vector2(3.0, 11.0), str((k + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.65, 0.5))
			if k < entrees_h.size() and not str(entrees_h[k].get("type", "")).is_empty():
				if str(entrees_h[k].type) == "capacite":
					var cap: Dictionary = j.capacites[int(entrees_h[k].ref)]
					Pictos.dessiner_sort(self, cap.get("modules", []), Rect2(r.position + Vector2(CASE * 0.22, 12.0), Vector2(CASE * 0.56, CASE * 0.56)))
				draw_string(f, r.position + Vector2(3.0, CASE - 6.0), str(entrees_h[k].nom).left(9), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.95, 0.9))

	func _case_sous(pos: Vector2) -> int:
		if pos.y < 18.0 or pos.y > 18.0 + CASE:
			return -1
		var k := int(pos.x / (CASE + 4.0))
		if k < 0 or k >= 10 or fmod(pos.x, CASE + 4.0) > CASE:
			return -1
		return k

	func _can_drop_data(pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("hotbar_type") and _case_sous(pos) >= 0

	func _drop_data(pos: Vector2, data: Variant) -> void:
		var k := _case_sous(pos)
		var j: Dictionary = ecrans.main.joueur()
		if k < 0 or j.is_empty():
			return
		if not j.has("hotbar"):
			var vide: Array = []
			for i in 10:
				vide.append({})
			j["hotbar"] = vide
		j.hotbar[k] = {"type": str(data.hotbar_type), "ref": data.ref}
		queue_redraw()
		ecrans.main.hud_ecran.queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			var k := _case_sous(ev.position)
			var j: Dictionary = ecrans.main.joueur()
			if k >= 0 and not j.is_empty() and j.has("hotbar") and k < j.hotbar.size():
				j.hotbar[k] = {}
				queue_redraw()
				ecrans.main.hud_ecran.queue_redraw()


## Les trois jauges de l'écran de création : vie, endurance, mana, pleines, avec leur valeur écrite.
## Les mêmes couleurs que le HUD, la même lecture « valeur / max » — jamais un pourcentage seul.
class BarresCreation extends Control:
	const COULEURS := {"sante": Color(0.85, 0.2, 0.2), "endurance": Color(0.9, 0.7, 0.2), "mana": Color(0.3, 0.5, 0.95)}
	const BARRE_L := 190.0
	const BARRE_H := 12.0
	var valeurs: Array = []

	func _draw() -> void:
		for k in valeurs.size():
			var l: Array = valeurs[k]
			var y := k * (BARRE_H + 6.0)
			draw_rect(Rect2(0.0, y, BARRE_L, BARRE_H), Color(0.05, 0.05, 0.08, 0.85))
			draw_rect(Rect2(0.0, y, BARRE_L, BARRE_H), COULEURS.get(str(l[0]), Color.WHITE))
			draw_rect(Rect2(0.0, y, BARRE_L, BARRE_H), Color(0.6, 0.55, 0.4, 0.8), false, 1.0)
			draw_string(ThemeDB.fallback_font, Vector2(BARRE_L + 8.0, y + BARRE_H), "%s %d/%d" % [tr("barre." + str(l[0])), int(l[1]), int(l[1])], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.9, 0.85))


## L'aperçu du monde entier à l'écran Monde (designer 2026-08-31, point 49) : la carte est
## échantillonnée une fois par régénération — mers, côtes, reliefs — puis dessinée comme une image.
## Rien n'est deviné : c'est la même Surface que la partie, avec les réglages du joueur.
class ApercuMonde extends Control:
	const N := 256   # côté de l'échantillonnage : 65 536 sondes, une par lot de cellules
	var ecrans: Ecrans
	var image: Image
	var texture: ImageTexture
	var _cle := ""

	func rafraichir() -> void:
		var planete: Dictionary = ecrans.main.planete_effective()
		var graine: int = int(ecrans.main.graine_monde)
		var cle := "%d|%s" % [graine, JSON.stringify(planete.get("tectonique", {})) + str(planete.get("monde_cellules", 0)) + str(planete.get("monde_ratio", 1.0))]
		if cle == _cle:
			return
		_cle = cle
		var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, graine)
		var cellules: int = int(planete.get("monde_cellules", 1024))
		var ratio: float = float(planete.get("monde_ratio", 1.0))   # le monde est rectangulaire (designer, point 49)
		var nh := maxi(8, int(round(N * ratio)))
		image = Image.create(N, nh, false, Image.FORMAT_RGB8)
		for y in nh:
			for x in N:
				var cell := Vector2i(int(float(x) / N * cellules), int(float(y) / nh * cellules * ratio))
				image.set_pixel(x, y, _couleur(surf, cell, int(planete.get("taille_cellule", 64))))
		texture = ImageTexture.create_from_image(image)
		queue_redraw()

	## La couleur d'une cellule : la mer par profondeur, la terre par la teinte de son biome,
	## nuancée par l'altitude — on doit lire les côtes, les plaines et les montagnes d'un coup d'œil.
	func _couleur(surf: Surface, cell: Vector2i, taille: int) -> Color:
		var t := surf.tectonique_a(cell.x * taille + taille / 2, cell.y * taille + taille / 2)
		var alt := float(t.get("altitude", 0.0))
		if not surf.terre_a(cell):
			return Color(0.05, 0.10, 0.22).lerp(Color(0.16, 0.31, 0.52), clampf(alt / 0.30, 0.0, 1.0))
		var b: Dictionary = GameData.entree("biomes", str(surf.resume_cellule(cell).biome))
		var col := Color.html(str(b.couleur)) if b.has("couleur") else Color(0.35, 0.45, 0.28)
		if alt > 0.72:    # les hautes terres blanchissent, les basses s'assombrissent : le relief se lit
			col = col.lerp(Color(0.92, 0.92, 0.95), clampf((alt - 0.72) / 0.28, 0.0, 1.0) * 0.75)
		elif alt < 0.38:
			col = col.lerp(Color(0.85, 0.80, 0.60), 0.35)   # la frange littorale, sableuse
		return col

	func _draw() -> void:
		if texture == null:
			return
		var planete: Dictionary = ecrans.main.planete_effective()
		var ratio: float = float(planete.get("monde_ratio", 1.0))
		var larg := minf(size.x, (size.y - 24.0) / maxf(0.2, ratio))
		var haut := larg * ratio
		var o := Vector2((size.x - larg) * 0.5, maxf(0.0, (size.y - 24.0 - haut) * 0.5))
		draw_texture_rect(texture, Rect2(o, Vector2(larg, haut)), false)
		draw_rect(Rect2(o, Vector2(larg, haut)), Color(0.6, 0.55, 0.4, 0.9), false, 1.0)
		var cellules: float = float(planete.get("monde_cellules", 1024))
		var depart: Array = planete.get("cellule_depart", [cellules / 2.0, cellules * ratio / 2.0])
		var c := o + Vector2(float(depart[0]) / cellules * larg, float(depart[1]) / maxf(1.0, cellules * ratio) * haut)
		draw_arc(c, 9.0, 0.0, TAU, 16, Color(0.1, 0.08, 0.05, 0.9), 3.0)
		draw_arc(c, 9.0, 0.0, TAU, 16, Color(1, 0.9, 0.3), 1.5)
		draw_line(c - Vector2(12, 0), c + Vector2(12, 0), Color(1, 0.9, 0.3), 2.0)
		draw_line(c - Vector2(0, 12), c + Vector2(0, 12), Color(1, 0.9, 0.3), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(o.x, o.y + haut + 16.0), tr("ui.monde.apercu"), HORIZONTAL_ALIGNMENT_LEFT, larg, 11, Color(0.85, 0.85, 0.8))

## Le membre saisi dans le pantin : son joint cerclé et son corps souligné, pour qu'on voie ce qu'on tourne.
func _surligner_membre(pd: Paperdoll) -> void:
	if pose_edition.is_empty() or pose_segment.is_empty():
		return
	var corps: PackedVector2Array = pd.corps_de(pose_segment)
	if corps.size() < 2:
		return
	pd.draw_line(corps[0], corps[1], Color(1.0, 0.85, 0.3, 0.9), 1.2)
	pd.draw_arc(corps[0], 3.0, 0.0, TAU, 16, Color(1.0, 0.85, 0.3, 0.9), 1.0)

## L'aperçu de la création se replace sur la taille de son cadre (designer 2026-09-01, point 67) : plus
## une seule position en pixels, des proportions lues dans `styles.creation`. Rien ne flotte, rien n'est coupé.
func _replacer_apercu() -> void:
	if cadre_perso == null or apercu_perso == null:
		return
	var st: Dictionary = GameData.config("styles").get("creation", {})
	var cadre: Vector2 = cadre_perso.size
	if cadre.x <= 0.0 or cadre.y <= 0.0:
		return
	var ech := clampf(cadre.y / maxf(1.0, float(st.get("hauteur_ref", 52.0))), float(st.get("echelle_min", 3.0)), float(st.get("echelle_max", 9.0)))
	apercu_perso.scale = Vector2(ech, ech)
	apercu_perso.position = Vector2(cadre.x * float(st.get("personnage_x", 0.28)), cadre.y * float(st.get("personnage_y", 0.82)))
	var cote := cadre.y * float(st.get("visage_cote", 0.46))
	cadre_visage.size = Vector2(cote, cote)
	cadre_visage.custom_minimum_size = Vector2(cote, cote)
	cadre_visage.position = Vector2(cadre.x * float(st.get("visage_x", 0.55)), cadre.y * float(st.get("visage_y", 0.05)))
	var ep := cote * float(st.get("portrait_echelle", 0.065))
	portrait_perso.scale = Vector2(ep, ep)
	portrait_perso.position = Vector2(cote * 0.5, cote * 2.45)   # la tête du rig, recadrée dans le carré
	barres_perso.position = Vector2(0.0, cadre.y * float(st.get("barres_y", 0.88)))
	barres_perso.size = Vector2(cadre.x, cadre.y * 0.12)

## La colonne de liste prend une part de la largeur du panneau (designer 2026-09-01, point 67) : à 340 px
## fixes, l'écran Territoire coupait ses lignes pendant que les deux tiers droits restaient vides.
func _replacer_liste() -> void:
	if liste == null or panneau == null:
		return
	var st: Dictionary = GameData.config("styles").get("ecrans", {})
	var l := clampf(panneau.size.x * float(st.get("part_liste", 0.30)), float(st.get("liste_min", 340.0)), float(st.get("liste_max", 700.0)))
	liste.custom_minimum_size = Vector2(l, 0)
