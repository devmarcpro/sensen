class_name EchangeVisuel
extends HBoxContainer
## Les écrans d'échange refaits comme l'inventaire (designer 2026-09-04, 12 h 30 : « afficher les inventaires des
## deux personnages avec icônes des objets et tri »). Une même vue pour le **commerce** (un marchand) et
## l'**échange** (un compagnon) : deux volets, à gauche le sac du joueur, à droite le sac ou l'étal de l'autre,
## chacun une liste d'objets comme celle de l'inventaire — pictogramme, nom, type, qualité, quantité, et le prix
## en commerce. T trie sur la colonne suivante du volet courant, Tab passe à l'autre volet, Entrée achète / vend
## ou donne / reprend selon le volet (l'action principale de l'écran, inchangée), le détail à droite.
## Cette vue ne calcule rien : elle lit `ecrans.entrees` (kinds achat / vente / donner / reprendre) et la
## mécanique reste dans la simulation (`acheter`, `vendre`, `echanger`, `prix_suggere`).

const LIGNE := 26.0
const COLONNES: Array[String] = ["nom", "type", "qualite", "quantite", "prix"]
const LARGEURS := {"type": 92.0, "qualite": 52.0, "quantite": 40.0, "prix": 56.0}

var ecrans: Node
var volets: Array = []       # [VoletObjets, VoletObjets] : joueur, autre
var volet_courant := 0
var mode := "commerce"       # « commerce » (prix affichés) ou « echange »


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	for cote in ["joueur", "autre"]:
		var v := VoletObjets.new()
		v.echange = self
		v.cote = cote
		add_child(v)
		volets.append(v)


## Reconstruit les deux volets depuis `ecrans.entrees` : les kinds vente / donner vont au joueur, achat / reprendre à l'autre.
func reconstruire(mode_: String) -> void:
	mode = mode_
	var pnj: Dictionary = ecrans.main.sim.entites.get(ecrans.pnj_id, {})
	var j: Dictionary = ecrans.main.joueur()
	volets[0].titre.text = tr("ui.echange.volet_joueur").format({"n": j.get("sac", []).size(), "or": int(j.get("or", 0))})
	volets[1].titre.text = tr("ui.echange.volet_marchand" if mode == "commerce" else "ui.echange.volet_autre").format({"nom": tr(str(pnj.get("name_key", "")))})
	for v in volets:
		v.vider()
		v.montrer_prix(mode == "commerce")   # en échange, pas de colonne Prix
	for k in ecrans.entrees.size():
		var en: Dictionary = ecrans.entrees[k]
		var kind := str(en.get("kind", ""))
		if kind in ["vente", "donner"]:
			volets[0].ajouter(str(en.uid), k, en)
		elif kind in ["achat", "reprendre"]:
			volets[1].ajouter(str(en.uid), k, en)
	for v in volets:
		v.ordonner()
	# la sélection courante de l'écran doit tomber sur un objet, jamais sur une ligne de titre de l'ancienne liste
	if ecrans.selection >= ecrans.entrees.size() or not (str(ecrans.entrees[ecrans.selection].get("kind", "")) in ["vente", "donner", "achat", "reprendre"]):
		var premier: int = volets[0].premier_index() if not volets[0].lignes.is_empty() else volets[1].premier_index()
		if premier >= 0:
			ecrans.selection = premier
	volet_courant = 1 if _volet_de(ecrans.selection) == 1 else 0
	rafraichir_selection()


func _volet_de(index: int) -> int:
	for l in volets[1].lignes:
		if l.index == index:
			return 1
	return 0


func rafraichir_selection() -> void:
	for v in volets:
		v.marquer(v.get_index() == volet_courant)
		for l in v.lignes:
			l.queue_redraw()


func selectionner(index: int) -> void:
	if index < 0 or index >= ecrans.entrees.size():
		return
	ecrans.selection = index
	volet_courant = _volet_de(index)
	ecrans._montrer_detail()
	rafraichir_selection()


## Tab : l'autre volet — sa première ligne, ou celle qu'on y avait choisie.
func basculer_volet() -> void:
	var autre: int = 1 - volet_courant
	if volets[autre].lignes.is_empty():
		return
	var idx: int = volets[autre].derniere if volets[autre].derniere >= 0 else volets[autre].premier_index()
	selectionner(idx)


## T : la colonne suivante du volet courant (puis l'ordre inverse sur la même, comme à l'inventaire).
func trier_suivant() -> void:
	volets[volet_courant].trier_suivant()


## Un volet : un titre, un en-tête triable, une liste de lignes.
class VoletObjets extends VBoxContainer:
	var echange: EchangeVisuel
	var cote := "joueur"
	var titre: Label
	var entete: HBoxContainer
	var defilement: ScrollContainer
	var colonne: VBoxContainer
	var lignes: Array = []
	var tri := "nom"
	var tri_inverse := false
	var derniere := -1   # l'index (dans ecrans.entrees) de la dernière ligne choisie ici
	var avec_prix := true   # la colonne Prix : en commerce seulement

	func _ready() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_theme_constant_override("separation", 4)
		titre = Label.new()
		titre.add_theme_font_size_override("font_size", 12)
		titre.modulate = Color(0.85, 0.8, 0.6)
		add_child(titre)
		entete = HBoxContainer.new()
		entete.add_theme_constant_override("separation", 0)
		add_child(entete)
		for col in EchangeVisuel.COLONNES:
			var b := Button.new()
			b.text = tr("ui.inventaire.col_" + col) if col != "prix" else tr("ui.echange.col_prix")
			b.focus_mode = Control.FOCUS_NONE
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 11)
			if col == "nom":
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			else:
				b.custom_minimum_size = Vector2(float(EchangeVisuel.LARGEURS[col]), 0)
			var c2: String = col
			b.pressed.connect(func() -> void: trier(c2))
			entete.add_child(b)
		defilement = ScrollContainer.new()
		defilement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		defilement.size_flags_vertical = Control.SIZE_EXPAND_FILL
		defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(defilement)
		colonne = VBoxContainer.new()
		colonne.add_theme_constant_override("separation", 2)
		colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		defilement.add_child(colonne)

	func montrer_prix(oui: bool) -> void:
		avec_prix = oui
		var k := EchangeVisuel.COLONNES.find("prix")
		if k >= 0 and k < entete.get_child_count():
			entete.get_child(k).visible = oui

	func vider() -> void:
		for ch in colonne.get_children():
			colonne.remove_child(ch)
			ch.queue_free()
		lignes.clear()
		derniere = -1

	func ajouter(uid: String, index: int, entree: Dictionary) -> void:
		var l := LigneEchange.new()
		l.volet = self
		l.uid = uid
		l.index = index
		l.entree = entree
		l.nom = echange.ecrans._nom_court(uid)
		colonne.add_child(l)
		lignes.append(l)

	func premier_index() -> int:
		return int(colonne.get_child(0).index) if colonne.get_child_count() > 0 else -1

	func marquer(courant: bool) -> void:
		titre.modulate = Color(1.0, 0.95, 0.75) if courant else Color(0.7, 0.66, 0.5)
		if colonne.get_child_count() == 0 and courant:
			return

	func trier(col: String) -> void:
		if tri == col:
			tri_inverse = not tri_inverse
		else:
			tri = col
			tri_inverse = false
		ordonner()
		for b in entete.get_children():
			var nom_col: String = EchangeVisuel.COLONNES[b.get_index()]
			var base: String = tr("ui.inventaire.col_" + nom_col) if nom_col != "prix" else tr("ui.echange.col_prix")
			b.text = base + ((" ▼" if tri_inverse else " ▲") if nom_col == tri else "")

	func trier_suivant() -> void:
		var k := EchangeVisuel.COLONNES.find(tri)
		if tri_inverse or k < 0:
			trier(EchangeVisuel.COLONNES[(k + 1) % EchangeVisuel.COLONNES.size()])
		else:
			trier(tri)   # la même colonne, à l'envers — puis la suivante

	## La valeur de tri d'une ligne pour la colonne courante (les mêmes clés que l'inventaire, plus le prix).
	func cle(l: LigneEchange) -> Variant:
		var sim = echange.ecrans.main.sim
		var it: Dictionary = sim.items.get(l.uid, {})
		match tri:
			"type": return tr("type." + str(it.get("type", "")))
			"qualite": return float(it.get("qualite", 0.0)) if it.get("type", "") != "materiau" else 0.0
			"quantite": return int(it.get("quantite", 1))
			"prix": return l.prix()
		return l.nom.to_lower()

	func ordonner() -> void:
		var ordre: Array = lignes.duplicate()
		ordre.sort_custom(func(a: LigneEchange, b: LigneEchange) -> bool:
			var ka: Variant = cle(a)
			var kb: Variant = cle(b)
			if ka == kb:
				return a.index < b.index
			return (ka > kb) if tri_inverse else (ka < kb))
		for k in ordre.size():
			colonne.move_child(ordre[k], k)


## Une ligne : pictogramme, nom, type, qualité, quantité, prix — comme à l'inventaire, avec le prix en plus.
class LigneEchange extends Control:
	var volet: EchangeVisuel.VoletObjets
	var uid := ""
	var index := -1
	var nom := ""
	var entree: Dictionary = {}
	var survolee := false

	func _ready() -> void:
		custom_minimum_size = Vector2(0, EchangeVisuel.LIGNE)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = nom
		mouse_entered.connect(func() -> void: survolee = true; queue_redraw())
		mouse_exited.connect(func() -> void: survolee = false; queue_redraw())

	## Le prix de la ligne : ce qu'il demande (achat) ou ce qu'il donne (vente) ; rien en échange.
	func prix() -> int:
		var p: Dictionary = entree.get("prix", {})
		if p.is_empty():
			return 0
		return int(p.get("prix", 0)) if str(entree.get("kind", "")) == "achat" else int(p.get("achat", 0))

	func _draw() -> void:
		var sim = volet.echange.ecrans.main.sim
		var it: Dictionary = sim.items.get(uid, {})
		var r := Rect2(Vector2.ZERO, size)
		var choisie: bool = volet.echange.ecrans.selection == index
		var cadre := Pictos.couleur_qualite(it)
		draw_rect(r, Color(1, 1, 1, 0.12) if choisie else (Color(1, 1, 1, 0.06) if survolee else Color(1, 1, 1, 0.02)))
		if choisie:
			draw_rect(r, Color(1, 1, 1, 0.8), false, 1.0)
		Pictos.dessiner_objet(self, it, Rect2(Vector2(4, 3), Vector2(20, 20)))
		var f := ThemeDB.fallback_font
		var y := EchangeVisuel.LIGNE * 0.5 + 4.0
		var x_fin := size.x
		for col in ["prix", "quantite", "qualite", "type"]:   # de droite à gauche, aux largeurs de l'en-tête
			if col == "prix" and not volet.avec_prix:
				continue
			x_fin -= float(EchangeVisuel.LARGEURS[col])
			var texte := ""
			var teinte := Color(0.85, 0.83, 0.75)
			match col:
				"prix":
					if volet.echange.mode == "commerce":
						texte = tr("ui.prix.or").format({"n": prix()})   # « 5 or » / « 5 gold » (vu sur la capture anglaise, 2026-09-04)
						teinte = Color(0.95, 0.8, 0.35)
				"quantite": texte = ("×%d" % int(it.quantite)) if int(it.get("quantite", 1)) > 1 else ""
				"qualite":
					texte = ("%.2f" % float(it.qualite)) if (it.has("qualite") and it.get("type", "") != "materiau") else "—"
					teinte = cadre
				"type": texte = tr("type." + str(it.get("type", "")))
			draw_string(f, Vector2(x_fin + 4.0, y), texte, HORIZONTAL_ALIGNMENT_LEFT, float(EchangeVisuel.LARGEURS[col]) - 6.0, 11, teinte)
		draw_string(f, Vector2(30, y), nom, HORIZONTAL_ALIGNMENT_LEFT, x_fin - 34.0, 12, Color(0.95, 0.93, 0.85))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			volet.derniere = index
			volet.echange.selectionner(index)
			if ev.double_click:
				volet.echange.ecrans._action_principale()
			accept_event()
