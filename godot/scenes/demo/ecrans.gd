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
var pnj_id := ""                     # le PNJ du dialogue / du commerce en cours
var replique_key := ""


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


var reforge_objet := ""   # Main du métal : l'objet choisi, en attente de son composant


var sequence_composee: Array = []   # la séquence en cours de composition (écran composer)
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
	if ev.keycode == KEY_TAB:
		fermer()
		return true
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
		"entrainer":
			_construire_entrainer(j)
		"commerce":
			_construire_commerce(j)
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
		"recette", "ingredient":
			detail.text = texte_recette(en.plan)
		"texte":
			detail.text = str(en.texte)
		"option", "quete", "cellule", "resident", "stock", "fonction", "voisin", "competence_entrainer", "menu", "contexte", "capacite", "nouvelle_capacite", "module_composer":
			detail.text = str(en.get("texte", ""))
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
		"fonction":
			main.sim.intention(j.id, {"type": "assigner", "pnj": pnj_id, "fonction": str(en.fonction)})
			fermer()
			return
		"competence_entrainer":
			main.sim.intention(j.id, {"type": "entrainer", "pnj": pnj_id, "competence": str(en.competence)})
		"menu":
			main._action_menu(str(en.id))
			return
		"capacite":
			main.sim.supprimer_capacite(j, int(en.index))
		"nouvelle_capacite":
			sequence_composee = []
			ouvrir("composer")
			return
		"module_composer":
			if str(en.module) in sequence_composee:
				sequence_composee.erase(str(en.module))
			else:
				sequence_composee.append(str(en.module))
		"contexte":
			fermer()
			main._executer_option(en.opt)
			return
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
	if pnj.has("maitre"):
		liste.add_item(tr("ui.ecran.suivre"))
		entrees.append({"kind": "option", "option": "suivre"})
		liste.add_item(tr("ui.ecran.attendre"))
		entrees.append({"kind": "option", "option": "attendre"})
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
		"suivre", "attendre":
			main.sim.ordonner(j, pnj_id, opt)
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
		# Le détail : par couleur, les motifs obtenus.
		var par_couleur: Dictionary = {}
		for cle in reg[esp].keys():
			var parts: PackedStringArray = str(cle).split("|")
			if not par_couleur.has(parts[0]):
				par_couleur[parts[0]] = []
			par_couleur[parts[0]].append(parts[1] if parts.size() > 1 else "")
		var couleurs: Array = par_couleur.keys()
		couleurs.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
		for c in couleurs:
			var ms: Array = par_couleur[c]
			ms.sort()
			lignes.append(tr("ui.registre.grille_ligne").format({"c": c, "motifs": ", ".join(ms)}))
		entrees.append({"kind": "texte", "texte": "\n".join(lignes)})


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


func _apercu_plan(plan: Dictionary) -> String:
	var effets: Array[String] = []
	for ef in plan.get("effets", []):
		effets.append(str(ef))
	var err: Array[String] = []
	for er in plan.get("erreurs", []):
		err.append(str(er))
	return tr("ui.composer.apercu").format({"geometrie": str(plan.get("geometrie", "")), "portee": str(plan.get("portee", "")), "taille": int(plan.get("taille", 1)), "ticks": int(plan.get("ticks", 0)), "ressource": int(plan.get("ressource", 0)), "monnaie": str(plan.get("monnaie", "")),
		"des": str(plan.get("des", "—")), "effets": ", ".join(effets) if not effets.is_empty() else "—", "erreurs": tr("ui.composer.erreurs").format({"liste": " ; ".join(err)}) if not err.is_empty() else ""})


## Composer : les modules connus, groupés par type ; Entrée les ajoute à la séquence (ou les en retire) ; V valide.
func _construire_composer(j: Dictionary) -> void:
	var slots: Dictionary = main.sim.slots_capacites(j)
	var noms: Array[String] = []
	for m in sequence_composee:
		noms.append(tr(GameData.catalogues.modules.get(str(m), {}).get("name_key", str(m))))
	titre.text = tr("ui.ecran.composer").format({"sequence": " → ".join(noms) if not noms.is_empty() else "—", "n": sequence_composee.size(), "max": int(slots.modules)})
	var connus: Array = j.get("modules_connus", []).duplicate()
	if connus.is_empty():
		liste.add_item(tr("ui.composer.vide"), null, false)
		entrees.append({"kind": "texte", "texte": ""})
		return
	var apercu := ""
	if not sequence_composee.is_empty():
		apercu = _apercu_plan(main.sim.capacites.assembler(sequence_composee.duplicate(), 10, "1d4", {}, j.competences_eff))
	for type in ["forme", "noyau", "modificateur", "condition", "declencheur", "liaison"]:
		var du_type: Array = []
		for m in connus:
			if str(GameData.catalogues.modules.get(str(m), {}).get("module_type", "")) == type:
				du_type.append(str(m))
		if du_type.is_empty():
			continue
		du_type.sort()
		liste.add_item(tr("ui.composer.type").format({"type": type}), null, false)
		entrees.append({"kind": "texte", "texte": apercu})
		for m in du_type:
			var md: Dictionary = GameData.catalogues.modules[m]
			var dans: bool = m in sequence_composee
			liste.add_item(("☑ " if dans else "☐ ") + tr(md.name_key))
			entrees.append({"kind": "module_composer", "module": m, "texte": tr("ui.composer.module").format({"nom": tr(md.name_key), "desc": str(md.get("description", ""))}) + "\n\n" + apercu})
	_bouton(tr("ui.composer.valider"), _valider_composition)


func _valider_composition() -> void:
	var j: Dictionary = main.joueur()
	if main.sim.composer_capacite(j, sequence_composee):
		sequence_composee = []
		ouvrir("capacites")
	else:
		rafraichir()


## Le menu (Tab) : les écrans et les actions générales (Écrans d'interface, contrôles).
func _construire_menu(_j: Dictionary) -> void:
	titre.text = tr("ui.ecran.menu")
	var ids: Array = ["inventaire", "atelier", "feuille", "capacites", "carte", "gestion", "registre", "sauvegarder", "charger", "minimap_zoom", "minimap_masquer", "arene", "recharger", "fermer"]
	for id in ids:
		if id in ["carte", "gestion"] and main.sim.lieu != "camp":
			continue
		liste.add_item(tr("ui.menu." + str(id)))
		entrees.append({"kind": "menu", "id": str(id), "texte": ""})


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
		liste.add_item(("✓ " if pl.faisable else "✗ ") + _titre_plan(pl) + "   [" + tr(GameData.entree("stations", pl.station).name_key) + "]")
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
