class_name Ecrans
extends CanvasLayer
## Les écrans du prototype (Écrans d'interface) : Inventaire + équipement, Atelier, Feuille de
## personnage — des Control Godot construits par code, sans asset. Un écran à la fois ; Échap ferme.
## L'écran ne décide rien : il lit la simulation et lui envoie des intentions.

const LARGEUR := 900.0
const HAUTEUR := 560.0

var main: Node                          # la scène principale (sim, joueur(), nom_objet())
var courant := ""                       # "inventaire" | "atelier" | "feuille" | ""
var panneau: PanelContainer
var titre: Label
var liste: ItemList
var detail: RichTextLabel
var boutons: HBoxContainer
var entrees: Array = []                 # ce que chaque ligne de la liste représente
var selection := 0
var minuterie := 0.0


func _ready() -> void:
	layer = 10
	panneau = PanelContainer.new()
	panneau.set_anchors_preset(Control.PRESET_CENTER)
	panneau.custom_minimum_size = Vector2(LARGEUR, HAUTEUR)
	panneau.position = Vector2(-LARGEUR / 2.0, -HAUTEUR / 2.0)
	panneau.set_anchor_and_offset(SIDE_LEFT, 0.5, -LARGEUR / 2.0)
	panneau.set_anchor_and_offset(SIDE_TOP, 0.5, -HAUTEUR / 2.0)
	panneau.set_anchor_and_offset(SIDE_RIGHT, 0.5, LARGEUR / 2.0)
	panneau.set_anchor_and_offset(SIDE_BOTTOM, 0.5, HAUTEUR / 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.94)
	style.border_color = Color(0.6, 0.55, 0.4)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	panneau.add_theme_stylebox_override("panel", style)
	panneau.visible = false
	add_child(panneau)
	var v := VBoxContainer.new()
	panneau.add_child(v)
	titre = Label.new()
	titre.add_theme_font_size_override("font_size", 16)
	v.add_child(titre)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	liste = ItemList.new()
	liste.custom_minimum_size = Vector2(340, 0)
	liste.size_flags_vertical = Control.SIZE_EXPAND_FILL
	liste.focus_mode = Control.FOCUS_NONE          # les lettres restent au jeu (pas de recherche incrémentale)
	liste.item_selected.connect(_sur_selection)
	liste.item_activated.connect(func(i: int) -> void: _sur_selection(i); _action_principale())
	h.add_child(liste)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("normal_font_size", 13)
	h.add_child(detail)
	boutons = HBoxContainer.new()
	v.add_child(boutons)


func est_ouvert() -> bool:
	return not courant.is_empty()


func basculer(nom: String) -> void:
	if courant == nom:
		fermer()
	else:
		ouvrir(nom)


func ouvrir(nom: String) -> void:
	courant = nom
	selection = 0
	panneau.visible = true
	rafraichir()


func fermer() -> void:
	courant = ""
	panneau.visible = false


func _process(delta: float) -> void:
	if not est_ouvert():
		return
	minuterie -= delta
	if minuterie <= 0.0:
		minuterie = 0.25
		rafraichir()


## Touches quand un écran est ouvert ; true si consommée.
func touche(ev: InputEventKey) -> bool:
	match ev.keycode:
		KEY_ESCAPE:
			fermer()
			return true
		KEY_UP, KEY_DOWN:
			if entrees.size() > 0:
				selection = posmod(selection + (1 if ev.keycode == KEY_DOWN else -1), entrees.size())
				liste.select(selection)
				_montrer_detail()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			_action_principale()
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
	selection = clampi(sel, 0, maxi(0, entrees.size() - 1))
	if entrees.size() > 0:
		liste.select(selection)
	_montrer_detail()
	_bouton(tr("ui.ecran.fermer"), fermer)


func _bouton(texte: String, action: Callable) -> void:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	boutons.add_child(b)


func _sur_selection(i: int) -> void:
	selection = i
	_montrer_detail()


func _montrer_detail() -> void:
	if entrees.is_empty() or selection >= entrees.size():
		detail.text = ""
		return
	var en: Dictionary = entrees[selection]
	match str(en.get("kind", "")):
		"objet":
			detail.text = texte_objet(str(en.uid))
		"recette":
			detail.text = texte_recette(en.plan)
		"texte":
			detail.text = str(en.texte)
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
	rafraichir()


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
		liste.add_item(("✓ " if pl.faisable else "✗ ") + _titre_plan(pl) + "   [" + tr(GameData.entree("stations", pl.station).name_key) + "]")
		if not pl.faisable:
			liste.set_item_custom_fg_color(liste.item_count - 1, Color(0.6, 0.6, 0.6))
		entrees.append({"kind": "recette", "plan": pl})
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
				l.append("   %d × %s — %s" % [int(en.besoin), _nom_filtre(en), _nom_pile(en)])
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
