class_name InventaireVisuel
extends VBoxContainer
## L'inventaire visuel (Écrans d'interface — designer, 2026-08-30 / 31) : en haut, les **slots d'équipement** en deux
## rangées à gauche du **personnage** (le paperdoll du jeu, avec ce qu'il porte) ; en dessous, le **sac** en **liste
## triable** (nom, type, qualité, poids, quantité — un clic sur l'en-tête trie, un second inverse). Le détail et le
## Wu Xing de l'objet restent à droite (Ecrans). Il ne décide rien : il lit `ecrans.entrees` / `ecrans.selection` et
## ne fait que sélectionner ; les actions (équiper, jeter…) restent celles de l'écran.

const CASE := Vector2(52, 52)
const LIGNE := 26.0
const COLONNES := ["nom", "type", "qualite", "poids", "quantite"]
# « station portative » se lisait « station portati » : le type prend 125 px, le nom garde le reste.
const LARGEURS := {"type": 125.0, "qualite": 70.0, "poids": 60.0, "quantite": 50.0}

var ecrans: Node
var cadre_avatar: Control
var fiche: FichePorteur   # la fiche du porteur : stats, jauges, charge (designer, point 64)
var avatar: Paperdoll
var cases: Dictionary = {}        # slot → CaseSlot
var entete: HBoxContainer
var defilement: ScrollContainer
var colonne: VBoxContainer
var lignes: Array = []
var tri := "nom"
var tri_inverse := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	var haut := HBoxContainer.new()   # les slots à gauche du personnage
	haut.add_theme_constant_override("separation", 16)
	add_child(haut)
	var grille_slots := GridContainer.new()
	grille_slots.columns = 5
	grille_slots.add_theme_constant_override("h_separation", 6)
	grille_slots.add_theme_constant_override("v_separation", 6)
	haut.add_child(grille_slots)
	for slot in ["main_principale", "main_secondaire", "casque", "cuirasse", "brassards", "jambieres", "bottes", "dos", "anneau_1", "anneau_2", "amulette", "carquois", "accessoire_1", "accessoire_2"]:
		var c := CaseSlot.new()
		c.inventaire = self
		c.slot = slot
		grille_slots.add_child(c)
		cases[slot] = c
	cadre_avatar = Control.new()
	cadre_avatar.custom_minimum_size = Vector2(190, FichePorteur.hauteur_requise())   # le personnage en grand (designer, point 64), aussi haut que la fiche
	cadre_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haut.add_child(cadre_avatar)
	avatar = Paperdoll.new()
	avatar.scale = Vector2(4.2, 4.2)
	avatar.position = Vector2(95, 200)
	cadre_avatar.add_child(avatar)
	fiche = FichePorteur.new()   # à droite : stats, jauges, charge, or — ce que le HUD dit en jeu
	fiche.inventaire = self
	fiche.custom_minimum_size = Vector2(230, FichePorteur.hauteur_requise())
	fiche.clip_contents = true   # rien ne mord sur la liste du sac, même si la fiche grandit (point 67)
	fiche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haut.add_child(fiche)
	entete = HBoxContainer.new()   # l'en-tête triable
	entete.add_theme_constant_override("separation", 0)
	add_child(entete)
	for col in COLONNES:
		var b := Button.new()
		b.text = tr("ui.inventaire.col_" + col)
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 11)
		if col == "nom":
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			b.custom_minimum_size = Vector2(float(LARGEURS[col]), 0)
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


func trier(col: String) -> void:
	if tri == col:
		tri_inverse = not tri_inverse
	else:
		tri = col
		tri_inverse = false
	_ordonner()
	for b in entete.get_children():
		var nom_col: String = COLONNES[b.get_index()]
		b.text = tr("ui.inventaire.col_" + nom_col) + ((" ▼" if tri_inverse else " ▲") if nom_col == tri else "")


## La valeur de tri d'une ligne pour la colonne courante.
func _cle(l: LigneObjet) -> Variant:
	var it: Dictionary = ecrans.main.sim.items.get(l.uid, {})
	match tri:
		"type": return tr("type." + str(it.get("type", "")))
		"qualite": return float(it.get("qualite", 0.0)) if it.get("type", "") != "materiau" else 0.0
		"poids": return float(ecrans.main.sim.regles.poids_objet(it, ecrans.main.sim.fonctionnalites))
		"quantite": return int(it.get("quantite", 1))
	return l.nom.to_lower()


func _ordonner() -> void:
	var ordre: Array = lignes.duplicate()
	ordre.sort_custom(func(a: LigneObjet, b: LigneObjet) -> bool:
		var ka: Variant = _cle(a)
		var kb: Variant = _cle(b)
		if ka == kb:
			return a.index < b.index
		return (ka > kb) if tri_inverse else (ka < kb))
	for k in ordre.size():
		colonne.move_child(ordre[k], k)


## Reconstruit depuis `ecrans.entrees` : les slots (kind objet/equipe ou texte « slot vide »), puis le sac.
func reconstruire() -> void:
	var sim = ecrans.main.sim
	var j: Dictionary = ecrans.main.joueur()
	if j.is_empty():
		return
	avatar.configurer(j, GameData.entree("rigs", str(j.get("skeleton_template", "humanoide"))), sim.items, sim.fonctionnalites, GameData.config("palette_materiaux"))
	avatar.queue_redraw()
	fiche.queue_redraw()
	for ch in colonne.get_children():
		colonne.remove_child(ch)
		ch.queue_free()
	lignes.clear()
	for c in cases.values():
		c.uid = ""
		c.index = -1
	var slots_ordre: Array = ["main_principale", "main_secondaire", "casque", "cuirasse", "brassards", "jambieres", "bottes", "dos", "anneau_1", "anneau_2", "amulette", "carquois", "accessoire_1", "accessoire_2"]
	var k := 0
	for en in ecrans.entrees:
		var kind := str(en.get("kind", ""))
		if kind == "objet" and bool(en.get("equipe", false)):
			var slot := str(en.slot)
			if cases.has(slot):
				cases[slot].uid = str(en.uid)
				cases[slot].index = k
		elif kind == "objet":
			var l := LigneObjet.new()
			l.inventaire = self
			l.uid = str(en.uid)
			l.index = k
			l.nom = ecrans._nom_court(l.uid)
			colonne.add_child(l)
			lignes.append(l)
		elif kind == "texte" and k < slots_ordre.size():   # un slot vide : la case k correspond à l'ordre des slots de l'écran
			cases[slots_ordre[k]].index = k
		k += 1
	_ordonner()
	rafraichir_selection()


func rafraichir_selection() -> void:
	for c in cases.values():
		c.queue_redraw()
	for l in lignes:
		l.queue_redraw()


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


## Une ligne du sac : l'icône, le nom, le type, la qualité, le poids, la quantité.
class LigneObjet extends Control:
	var inventaire: InventaireVisuel
	var uid := ""
	var index := -1
	var nom := ""
	var survolee := false

	func _ready() -> void:
		custom_minimum_size = Vector2(0, InventaireVisuel.LIGNE)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		var it: Dictionary = inventaire.ecrans.main.sim.items.get(uid, {})
		tooltip_text = inventaire.ecrans.main.nom_objet(inventaire.ecrans.main.sim.nom_objet(uid)) if not it.is_empty() else ""
		mouse_entered.connect(func() -> void: survolee = true; queue_redraw())
		mouse_exited.connect(func() -> void: survolee = false; queue_redraw())

	func _draw() -> void:
		var sim = inventaire.ecrans.main.sim
		var it: Dictionary = sim.items.get(uid, {})
		var r := Rect2(Vector2.ZERO, size)
		var choisie: bool = inventaire.ecrans.selection == index
		var cadre := Pictos.couleur_qualite(it)
		draw_rect(r, Color(1, 1, 1, 0.12) if choisie else (Color(1, 1, 1, 0.06) if survolee else Color(1, 1, 1, 0.02)))
		if choisie:
			draw_rect(r, Color(1, 1, 1, 0.8), false, 1.0)
		Pictos.dessiner_objet(self, it, Rect2(Vector2(4, 3), Vector2(20, 20)))
		var f := ThemeDB.fallback_font
		var y := InventaireVisuel.LIGNE * 0.5 + 4.0
		var x_fin := size.x
		for col in ["quantite", "poids", "qualite", "type"]:   # de droite à gauche, aux largeurs de l'en-tête
			x_fin -= float(InventaireVisuel.LARGEURS[col])
			var texte := ""
			match col:
				"quantite": texte = ("×%d" % int(it.quantite)) if int(it.get("quantite", 1)) > 1 else ""
				"poids": texte = "%.1f" % float(sim.regles.poids_objet(it, sim.fonctionnalites))
				"qualite": texte = ("%.2f" % float(it.qualite)) if (it.has("qualite") and it.get("type", "") != "materiau") else "—"
				"type": texte = tr("type." + str(it.get("type", "")))
			draw_string(f, Vector2(x_fin + 4.0, y), texte, HORIZONTAL_ALIGNMENT_LEFT, float(InventaireVisuel.LARGEURS[col]) - 6.0, 11, cadre if col == "qualite" else Color(0.85, 0.83, 0.75))
		draw_string(f, Vector2(30, y), nom, HORIZONTAL_ALIGNMENT_LEFT, x_fin - 34.0, 12, Color(0.95, 0.93, 0.85))

	func _get_drag_data(_pos: Vector2) -> Variant:   # vers la hotbar (designer, point 35)
		var ap := Label.new()
		ap.text = nom
		set_drag_preview(ap)
		return {"hotbar_type": "objet", "ref": uid}

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			inventaire.selectionner(index)
			if ev.double_click:
				inventaire.ecrans._action_principale()
			accept_event()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			inventaire.selectionner(index)   # clic droit : les actions de l'objet (designer, point 46)
			inventaire.ecrans.menu_objet(uid, get_global_mouse_position())
			accept_event()


## La fiche du porteur, à droite du personnage (designer 2026-09-01, point 64) : ses six stats avec
## ce que l'équipement leur ajoute, ses quatre jauges, sa charge, son or et ses niveaux.
## Elle ne calcule rien : elle lit l'être et les règles, comme le HUD le fait en jeu.
class FichePorteur extends Control:
	const COULEURS := {"sante": Color(0.85, 0.2, 0.2), "endurance": Color(0.9, 0.7, 0.2), "mana": Color(0.3, 0.5, 0.95), "faim": Color(0.55, 0.35, 0.15)}
	const TITRE_H := 14.0 + 18.0
	const STAT_H := 15.0
	const JAUGE_H := 16.0
	const LIGNE_H := 16.0
	var inventaire: InventaireVisuel

	## La hauteur réellement dessinée : six stats, quatre jauges, charge, or, niveaux. Un seul endroit
	## fait foi — la fiche débordait de 36 px sur l'en-tête du sac tant que le cadre l'ignorait (point 67).
	static func hauteur_requise() -> float:
		return TITRE_H + 6.0 * STAT_H + 6.0 + 4.0 * JAUGE_H + 6.0 + 3.0 * LIGNE_H + 8.0

	func _draw() -> void:
		var j: Dictionary = inventaire.ecrans.main.joueur()
		var sim = inventaire.ecrans.main.sim
		if j.is_empty() or sim == null:
			return
		var f := ThemeDB.fallback_font
		var y := 14.0
		draw_string(f, Vector2(0, y), tr("ui.inventaire.fiche"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.88, 0.7))
		y += 18.0
		for st in ["force", "dexterite", "endurance", "volonte", "perception", "charisme"]:
			var base := int(j.corps.stats.get(st, 0))
			var eff := int(j.get("stats_eff", j.corps.stats).get(st, base))
			var texte := "%s %d" % [tr("stat." + st), eff]
			if eff != base:
				texte += "  (%+d)" % (eff - base)
			draw_string(f, Vector2(6, y), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.8) if eff == base else Color(0.6, 0.9, 0.7))
			y += 15.0
		y += 6.0
		var jauges := [["sante", int(j.sante), int(j.sante_max)], ["endurance", int(j.endurance), int(j.endurance_max)],
			["mana", int(j.mana), int(j.mana_max)], ["faim", int(j.get("faim", 100)), 100]]
		for jg in jauges:
			var part := clampf(float(jg[1]) / maxf(1.0, float(jg[2])), 0.0, 1.0)
			draw_rect(Rect2(6, y, 150, 11), Color(0.05, 0.05, 0.08, 0.85))
			draw_rect(Rect2(6, y, 150 * part, 11), COULEURS.get(str(jg[0]), Color.WHITE))
			draw_rect(Rect2(6, y, 150, 11), Color(0.6, 0.55, 0.4, 0.8), false, 1.0)
			draw_string(f, Vector2(162, y + 10), "%d/%d" % [int(jg[1]), int(jg[2])], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.9, 0.85))
			y += 16.0
		y += 6.0
		var pds: Dictionary = sim.poids_de(j)
		draw_string(f, Vector2(6, y), tr("ui.inventaire.charge").format({"poids": "%.1f" % float(pds.poids), "capacite": "%.0f" % float(pds.capacite)}), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.8, 0.6) if float(pds.facteur) <= 1.0 else Color(0.95, 0.5, 0.4))
		y += 16.0
		draw_string(f, Vector2(6, y), tr("ui.inventaire.or").format({"or": int(j.get("or", 0))}), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.85, 0.4))
		y += 16.0
		var nd: Dictionary = sim.progression.niveaux_derives(j)
		draw_string(f, Vector2(6, y), tr("ui.inventaire.niveaux").format({"combat": "%.1f" % float(nd.combat), "general": "%.1f" % float(nd.general)}), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.85, 0.9))


## Rendre les largeurs fixes du haut proportionnelles à la place offerte (file d'attente du designer,
## point 67). Un conteneur Godot ne descend jamais un enfant sous sa taille minimale : la somme des
## minimums (grille des slots + avatar + fiche + colonne de détail) dépassait une fenêtre étroite, et
## l'excédent sortait du cadre sans un mot. On rabote donc les minimums quand la place manque.
func ajuster_largeur(dispo: float) -> void:
	if cadre_avatar == null or fiche == null:
		return
	var k := clampf(dispo / 1010.0, 0.45, 1.0)   # 1010 : la somme des minimums à pleine taille
	# L'avatar est décoratif : c'est lui qui cède. La fiche, elle, porte des chiffres — sous 210 px ses
	# valeurs de jauges passaient hors cadre et disparaissaient, ce qui est une autre façon de couper.
	cadre_avatar.custom_minimum_size.x = 190.0 * k
	fiche.custom_minimum_size.x = maxf(210.0, 230.0 * k)
	if avatar != null:
		avatar.scale = Vector2(4.2 * k, 4.2 * k)
		avatar.position = Vector2(95.0 * k, 200.0 * k)
