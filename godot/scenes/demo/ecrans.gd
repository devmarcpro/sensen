class_name Ecrans
extends CanvasLayer
## Les écrans du prototype (Écrans d'interface) : Inventaire + équipement, Atelier, Feuille de
## personnage — des Control Godot construits par code, sans asset. Un écran à la fois ; Échap ferme.
## L'écran ne décide rien : il lit la simulation et lui envoie des intentions.

const LARGEUR := 1000.0   # taille minimale ; à l'écran, le panneau prend PART de la fenêtre (designer, 2026-08-30 : plus de place)
const HAUTEUR := 660.0
const PART := Vector2(0.94, 0.92)

var main: Node                          # la scène principale (sim, joueur(), nom_objet())
var voile: ColorRect                    # le voile sous tout écran ouvert : grise le jeu, absorbe la souris (designer 2026-09-04)
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
	panneau.resized.connect(func() -> void: EcransFeuille._replacer_liste(self))   # la colonne suit la largeur du panneau (point 67)
	panneau.visible = false
	voile = ColorRect.new()   # sous le panneau : le jeu se grise, et rien derrière ne se clique (designer 2026-09-04, 13 h 05)
	voile.color = Color(0.0, 0.0, 0.0, 0.55)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	voile.visible = false
	add_child(voile)
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
	echange_visuel = EchangeVisuel.new()
	echange_visuel.ecrans = self
	echange_visuel.visible = false
	h.add_child(echange_visuel)
	atelier_visuel = AtelierVisuel.new()
	atelier_visuel.ecrans = self
	atelier_visuel.visible = false
	h.add_child(atelier_visuel)
	dialogue_visuel = DialogueVisuel.new()
	dialogue_visuel.ecrans = self
	dialogue_visuel.visible = false
	h.add_child(dialogue_visuel)
	liste = ItemList.new()
	liste.custom_minimum_size = Vector2(float(GameData.config("styles").get("ecrans", {}).get("liste_min", 340.0)), 0)
	liste.size_flags_vertical = Control.SIZE_EXPAND_FILL
	liste.focus_mode = Control.FOCUS_NONE          # les lettres restent au jeu (pas de recherche incrémentale)
	liste.item_selected.connect(func(i: int) -> void: EcransListe._sur_selection(self, i))
	liste.item_activated.connect(func(i: int) -> void: EcransListe._sur_selection(self, i); EcransListe._action_principale(self))
	h.add_child(liste)
	liste.set_drag_forwarding(func(at: Vector2) -> Variant: return EcransListe._glisser_liste(self, at), func(_p: Vector2, _d: Variant) -> bool: return EcransListe._depot_refuse(self, _p, _d), func(_p: Vector2, _d: Variant) -> void: EcransListe._depot_rien(self, _p, _d))
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
	cadre_perso.gui_input.connect(func(ev: InputEvent) -> void: EcransCreation._pantin_entree(self, ev))
	cadre_perso.resized.connect(func() -> void: EcransFeuille._replacer_apercu(self))   # tout se replace à la taille du cadre (point 67)
	apercu_perso = Paperdoll.new()
	apercu_perso.scale = Vector2(5.4, 5.4)   # le personnage en grand (designer, point 43)
	apercu_perso.dessine_apres = func(pd: Paperdoll) -> void: EcransFeuille._surligner_membre(self, pd)   # le membre saisi est mis en évidence (point 68)
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
	detail.meta_clicked.connect(func(meta: Variant) -> void: EcransInventaire._clic_action(self, str(meta)))   # une option d'objet cliquée (2026-09-06)
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
var echange_visuel: EchangeVisuel         # commerce et échange à deux volets, comme l'inventaire (designer 2026-09-04)
var atelier_visuel: AtelierVisuel         # l'atelier en cartes de recettes
var dialogue_visuel: DialogueVisuel       # la carte de dialogue : portrait, nom, informations, options lettrées (designer 2026-09-06)
var dialogue_infos := ""                  # le texte d'informations de la carte, composé par EcransDialogue
var page := 0                             # la page courante de l'écran (une option = une lettre, designer 2026-09-06, 17 h 55)
var lettres: Dictionary = {}              # index d'entrée → sa lettre (« a », « b »…), posées par EcransListe._paginer
var objet_choisi := ""                    # l'inventaire : l'objet choisi, dont les options sont les lignes lettrées (designer 2026-09-06, 18 h 25)
var choix: Dictionary = {}                # tout écran : l'entrée choisie, dont les options sont les lignes lettrées (designer 2026-09-06, 18 h 50 : « partout »)
var secteur := 0                          # les secteurs d'un menu (designer 2026-09-06, 19 h 40) : le secteur surligné, le seul à porter des lettres ; Tab passe au suivant
var secteurs: Array = []                  # les groupes d'entrées de l'écran, dans l'ordre (EcransListe._secteurs) ; en.secteur en est l'index
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
var crans_composes: Array = []      # le cran de chaque pièce de cette séquence, dans le même ordre (designer 2026-09-04)
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
	if courant != nom:
		page = 0   # une page se garde tant que l'écran reste ouvert
		objet_choisi = ""
		choix = {}
		secteur = 0
	courant = nom
	EcransFeuille._replacer_liste(self)   # la colonne suit la largeur du panneau : le signal resized ne suffit pas à l'ouverture
	selection = 0
	panneau.visible = true
	voile.visible = true
	apercu_sort.visible = false
	corps.visible = nom != "composer"
	composeur.visible = nom == "composer"
	EcransListe.rafraichir(self)


func fermer() -> void:
	courant = ""
	panneau.visible = false
	voile.visible = false
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
		EcransListe.rafraichir(self)


## Touches quand un écran est ouvert ; true si consommée.
func touche(ev: InputEventKey) -> bool:
	if courant == "creation" and EcransCreation._touche_creation(self, ev):
		return true
	if ev.keycode == KEY_TAB:
		if courant == "creation":
			return true
		if secteurs.size() > 1:   # Tab : le secteur suivant du menu (designer 2026-09-06, 19 h 40) — il se surligne, ses lignes prennent les lettres
			secteur = (secteur + 1) % secteurs.size()
			page = 0
			selection = -1   # la première ligne du secteur, choisie par rafraichir
			EcransListe.rafraichir(self)
			return true
		fermer()
		return true
	if courant == "composer" and ev.keycode != KEY_ESCAPE and ev.keycode != KEY_V and composeur.touche(ev):
		return true
	# Une option = une lettre (designer 2026-09-06, 17 h 55) : la lettre tapée joue la ligne qui la porte, sur tous les écrans ;
	# la dernière lettre d'un écran plein tourne la page. Une lettre que nulle ligne ne porte passe aux raccourcis d'écran.
	if ev.keycode >= KEY_A and ev.keycode <= KEY_Z and not ev.ctrl_pressed and not ev.alt_pressed and courant != "creation":
		if EcransListe.choisir_lettre(self, ev.keycode - KEY_A):
			return true
	match ev.keycode:
		KEY_ESCAPE:
			if courant == "triche_liste":   # la sous-liste revient au menu de triche
				ouvrir("triche")
				return true
			if courant == "inventaire" and not objet_choisi.is_empty():   # les options d'un objet : Échap revient à la liste
				objet_choisi = ""
				EcransListe.rafraichir(self)
				return true
			if not choix.is_empty():   # les options d'une entrée : Échap revient à la liste
				choix = {}
				EcransListe.rafraichir(self)
				return true
			if courant == "titre":   # rien derrière l'écran principal : Échap n'y fait rien
				return true
			if not pose_edition.is_empty():   # Échap : on sort du pantin sans quitter la création
				pose_edition = ""
				pose_segment = ""
				EcransListe.rafraichir(self)
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
				EcransCreation._tourner_membre(self, (-1.0 if ev.keycode == KEY_LEFT else 1.0) * float(GameData.config("poses").get("pas_degres", 6.0)))
				return true
			if courant == "monde" and selection < entrees.size():   # les réglages du monde (designer, point 49)
				var en_m: Dictionary = entrees[selection]
				if str(en_m.get("id", "")).begins_with("opt:"):
					EcransCreation._regler_monde(self, str(en_m.id).trim_prefix("opt:"), -1 if ev.keycode == KEY_LEFT else 1)
					EcransListe.rafraichir(self)
					return true
		KEY_UP, KEY_DOWN:
			var du_secteur: Array[int] = EcransListe._indices_secteur(self)   # les flèches restent dans le secteur surligné
			if not du_secteur.is_empty():
				var k: int = du_secteur.find(selection)
				selection = du_secteur[posmod(k + (1 if ev.keycode == KEY_DOWN else -1), du_secteur.size())]
				liste.select(selection)
				EcransListe._montrer_detail(self)
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if not pose_edition.is_empty():   # garder la pose et sortir du pantin
				pose_edition = ""
				pose_segment = ""
				EcransListe.rafraichir(self)
				return true
			EcransListe._action_principale(self)
			return true
		KEY_DELETE, KEY_BACKSPACE:
			if courant == "composer":   # retirer la dernière occurrence du module sélectionné
				var en_c: Dictionary = entrees[selection] if selection < entrees.size() else {}
				if en_c.get("kind", "") == "module_composer":
					var i_c: int = sequence_composee.rfind(str(en_c.module))
					if i_c >= 0:
						sequence_composee.remove_at(i_c)
						EcransListe.rafraichir(self)
				return true
		KEY_T:
			if courant in ["commerce", "echange"]:   # T : trier le volet courant (designer 2026-09-04)
				echange_visuel.trier_suivant()
				return true
		KEY_V:
			if courant == "composer":
				EcransGestion._valider_composition(self)
				return true
	return false


# ---------------------------------------------------------------- construction


# ---------------------------------------------------------------- l'état et les classes internes des écrans déplacés (2026-09-06)
## Déclarés au fil des sections déplacées ; l'état reste ici, les règles sont dans les modules.
## ses poses. Une liste de vingt-cinq lignes ne se lit pas ; trois volets de huit se lisent.
## Les trois volets de la création (designer 2026-09-01, point 66) : le personnage, son apparence,
const VOLETS := ["personnage", "apparence", "pose", "serments"]
## (objets, matériaux, créatures, météo, statuts, races cachées) — rien n'est écrit en dur ici.
## Les actions simples agissent tout de suite ; les autres ouvrent la liste d'un **catalogue**
## Le menu de triche (V) — Écrans d'interface : tout obtenir, tout déclencher, sans farmer.
const TRICHE_ACTIONS: Array[String] = ["or", "soin", "invincible", "competences", "talents", "modules",
	"recettes", "heure", "semaine", "reveler", "claim", "tuer"]
const TRICHE_CATALOGUES: Array[String] = ["objet", "materiau", "creature", "meteo", "statut", "race"]
const _CAT_TRICHE := {"objet": "items", "materiau": "materials", "creature": "creatures",
	"meteo": "weather_states", "statut": "status_effects", "race": "races"}
## dix cases identiques au HUD, cibles du glisser-déposer ; clic droit sur une case pour la vider.
## La hotbar en bas de l'inventaire et de l'écran de capacités (designer 2026-08-31, point 35) :
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


## Les mêmes couleurs que le HUD, la même lecture « valeur / max » — jamais un pourcentage seul.
## Les quatre jauges de l'écran de création : vie, vigueur, mana, sang-froid, pleines, avec leur valeur écrite.
class BarresCreation extends Control:
	const COULEURS := {"sante": Color(0.85, 0.2, 0.2), "vigueur": Color(0.9, 0.7, 0.2), "mana": Color(0.3, 0.5, 0.95), "sang_froid": Color(0.55, 0.75, 0.8)}
	const BARRE_L := 190.0
	const BARRE_H := 10.0   # quatre jauges depuis le sang-froid (2026-09-03) dans la place prévue pour trois : plus fines, même bloc
	const PAS := 4.0
	var valeurs: Array = []

	func _draw() -> void:
		for k in valeurs.size():
			var l: Array = valeurs[k]
			var y := k * (BARRE_H + PAS)
			draw_rect(Rect2(0.0, y, BARRE_L, BARRE_H), Color(0.05, 0.05, 0.08, 0.85))
			draw_rect(Rect2(0.0, y, BARRE_L, BARRE_H), COULEURS.get(str(l[0]), Color.WHITE))
			draw_rect(Rect2(0.0, y, BARRE_L, BARRE_H), Color(0.6, 0.55, 0.4, 0.8), false, 1.0)
			draw_string(ThemeDB.fallback_font, Vector2(BARRE_L + 8.0, y + BARRE_H), "%s %d/%d" % [tr("barre." + str(l[0])), int(l[1]), int(l[1])], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.9, 0.85))


## Rien n'est deviné : c'est la même Surface que la partie, avec les réglages du joueur.
## échantillonnée une fois par régénération — mers, côtes, reliefs — puis dessinée comme une image.
## L'aperçu du monde entier à l'écran Monde (designer 2026-08-31, point 49) : la carte est
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


# ---------------------------------------------------------------- délégués vers les bibliothèques Ecrans… (2026-09-06)
## Ce que la scène, les sondes et les autres écrans appellent sur `Ecrans` garde sa signature ; la construction des
## écrans vit dans `scenes/demo/ecrans/`. Écrits par `tools/fragmenter.py --cible ecrans`.

# EcransListe

func rafraichir() -> void:
	EcransListe.rafraichir(self)

func _sur_selection(i: int) -> void:
	EcransListe._sur_selection(self, i)

func _montrer_detail() -> void:
	EcransListe._montrer_detail(self)

func _action_principale() -> void:
	EcransListe._action_principale(self)

# EcransDialogue

func ouvrir_dialogue(id: String) -> void:
	EcransDialogue.ouvrir_dialogue(self, id)

# EcransGestion

func _contribution_module(j: Dictionary, m: String, _deja_dedans: bool) -> String:
	return EcransGestion._contribution_module(self, j, m, _deja_dedans)

func _apercu_plan(plan: Dictionary) -> String:
	return EcransGestion._apercu_plan(self, plan)

# EcransCreation

func _pantin_entree(ev: InputEvent) -> void:
	EcransCreation._pantin_entree(self, ev)

# EcransInventaire

func menu_objet(uid: String, ou: Vector2) -> void:
	EcransInventaire.menu_objet(self, uid, ou)

func _nom_court(uid: String) -> String:
	return EcransInventaire._nom_court(self, uid)

func _jeter() -> void:
	EcransInventaire._jeter(self)

func _lire() -> void:
	EcransInventaire._lire(self)

func _sertir() -> void:
	EcransInventaire._sertir(self)

func _poser() -> void:
	EcransInventaire._poser(self)

func _ranger() -> void:
	EcransInventaire._ranger(self)

# EcransAtelier

func _titre_plan(pl: Dictionary) -> String:
	return EcransAtelier._titre_plan(self, pl)

