class_name EcransListe
extends RefCounted
## La liste et le détail communs : rafraîchir, les boutons, le glisser-déposer, la sélection, le détail, l'action principale.
## Bibliothèque STATIQUE des écrans (Modules de la simulation et le C++, 2026-09-06) : l'état et les nœuds vivent dans
## `Ecrans`, reçu en premier paramètre ; ici, seulement la construction et la logique d'un écran. Déplacé depuis
## `ecrans.gd` par `tools/fragmenter.py --cible ecrans`, sans changement de comportement.


static func rafraichir(ec: Ecrans) -> void:
	var j: Dictionary = ec.main.joueur()
	if j.is_empty():
		return
	var sel := ec.selection
	ec.liste.clear()
	ec.entrees.clear()
	for b in ec.boutons.get_children():
		b.queue_free()
	match ec.courant:
		"inventaire":
			EcransInventaire._construire_inventaire(ec, j)
		"atelier":
			EcransAtelier._construire_atelier(ec, j)
		"feuille":
			EcransFeuille._construire_feuille(ec, j)
		"dialogue":
			EcransDialogue._construire_dialogue(ec, j)
		"quetes":
			EcransDialogue._construire_quetes(ec, j)
		"gestion":
			EcransGestion._construire_gestion(ec, j)
		"menu":
			EcransCreation._construire_menu(ec, j)
		"titre":
			EcransGestion._construire_titre(ec)
		"creation":
			EcransCreation._construire_creation(ec)
		"monde":
			EcransCreation._construire_monde(ec)
		"options":
			EcransCreation._construire_options(ec)
		"charger":
			EcransCreation._construire_charger(ec)
		"capacites":
			EcransGestion._construire_capacites(ec, j)
		"composer":
			EcransGestion._construire_composer(ec, j)
		"contexte":
			EcransCreation._construire_contexte(ec, j)
		"registre":
			EcransGestion._construire_registre(ec, j)
		"assigner":
			EcransCreation._construire_assigner(ec, j)
		"perimetre":
			EcransCreation._construire_perimetre(ec, j)
		"echange":
			EcransCreation._construire_echange(ec, j)
		"entrainer":
			EcransGestion._construire_entrainer(ec, j)
		"commerce":
			EcransDialogue._construire_commerce(ec, j)
		"triche":
			EcransCreation._construire_triche(ec, j)
		"triche_liste":
			EcransCreation._construire_triche_liste(ec, j)
		_:
			# Un nom inconnu laissait le panneau ouvert, vide, sous le titre du dernier écran construit :
			# une faute de frappe dans une recette de capture rendait une image fausse sans rien signaler.
			push_error("Écran inconnu : « %s »" % ec.courant)
			ec.fermer()
			return
	_paginer(ec)
	if ec.courant == "inventaire" and not ec.objet_choisi.is_empty():   # les options de l'objet choisi : la sélection va sur la première
		for i in ec.entrees.size():
			if str(ec.entrees[i].get("kind", "")) == "action_objet":
				sel = i
				break
	ec.selection = clampi(sel, 0, maxi(0, ec.entrees.size() - 1))
	if ec.entrees.size() > 0:
		ec.liste.select(ec.selection)
	_montrer_detail(ec)
	ec.cadre_perso.visible = ec.courant == "creation"
	if ec.courant == "charger" and ec.selection < ec.entrees.size():
		EcransCreation._portrait_partie(ec, str(ec.entrees[ec.selection].get("id", "")))   # `cadre_perso` reste visible : c'est le portrait de la partie
	ec.apercu_monde.visible = ec.courant == "monde"
	ec.inventaire_visuel.visible = ec.courant == "inventaire"
	ec.echange_visuel.visible = ec.courant in ["commerce", "echange"]
	ec.hotbar_ecran.visible = ec.courant == "inventaire" or ec.courant == "capacites"
	ec.atelier_visuel.visible = ec.courant == "atelier"
	ec.dialogue_visuel.visible = ec.courant == "dialogue"
	ec.droite.visible = ec.courant != "dialogue"   # la carte de dialogue porte elle-même ses informations
	ec.titre.visible = ec.courant != "dialogue"    # et le nom du PNJ en grand : pas de titre au-dessus
	ec.liste.visible = not (ec.courant in ["inventaire", "atelier", "commerce", "echange", "dialogue"])
	ec.penta_objet.visible = ec.courant == "inventaire"   # la place qu'on lui laisse se décide plus bas, à la hauteur connue
	# Chaque écran demandait une largeur en pixels fixes pour sa colonne de droite ; additionnée à la
	# liste (340 px), la somme dépassait une fenêtre étroite et le contenu sortait du cadre. Ces
	# largeurs sont désormais des PARTS du panneau, plafonnées à la valeur d'origine (point 67).
	# La largeur vient de `_dimensionner`, pas de `panneau.size` : la taille d'un Control n'est à jour
	# qu'après le tour de mise en page suivant, et s'en servir ici rendait des largeurs d'un cran en
	# retard — les colonnes se calculaient pour la fenêtre précédente et débordaient de la nouvelle.
	ec._dimensionner()
	# Le panneau a ses propres marges intérieures et les conteneurs leur séparation : compter sur la
	# largeur brute laissait les colonnes déborder d'une trentaine de pixels, juste assez pour manger
	# la fin de chaque ligne de texte. On travaille donc sur la largeur UTILE.
	var large := ec.largeur_panneau - 48.0
	# Même raisonnement en HAUTEUR, et c'est là que ça coupait vraiment : le panneau de l'inventaire
	# demandait 724 px de haut quoi qu'il arrive (détail 340 + pentagramme 222 + en-têtes), donc il
	# débordait de toute fenêtre plus courte — et un PanelContainer ne rétrécit jamais sous le minimum
	# de son contenu, si bien que `custom_minimum_size` ne le retenait pas. La sonde des écrans le
	# mesure maintenant à chaque passage. On réserve le titre, la hotbar et la rangée de boutons.
	var haut := maxf(220.0, ec.hauteur_panneau - 150.0)
	var part_droite := func(px: float, part: float) -> float: return minf(px, maxf(120.0, large * part))
	ec.liste.custom_minimum_size = Vector2(minf(float(GameData.config("styles").get("ecrans", {}).get("liste_min", 340.0)), large * 0.42), 0)
	if ec.courant == "gestion":   # Territoire : ses lignes sont longues et son détail court — la liste prend la moitié du panneau (2026-09-04)
		ec.liste.custom_minimum_size = Vector2(minf(float(GameData.config("styles").get("ecrans", {}).get("liste_gestion", 620.0)), large * 0.5), 0)
	if ec.courant == "monde":   # la carte du monde prend presque toute la fenêtre (designer, point 49)
		ec.droite.custom_minimum_size = Vector2(part_droite.call(900.0, 0.62), 0)
		ec.droite.size_flags_stretch_ratio = 3.0
		ec.detail.size_flags_vertical = Control.SIZE_SHRINK_END   # le texte se tasse : la carte prend le reste
		ec.detail.custom_minimum_size = Vector2(0, 44)
		ec.apercu_monde.custom_minimum_size = Vector2(0, minf(880.0, haut * 0.92))
	elif ec.courant == "inventaire":
		# L'inventaire a quatre colonnes de front : grille d'équipement, avatar, fiche, détail. On sert
		# d'abord les trois qui portent de l'information, et le détail prend ce qui reste — jamais moins
		# de 200 px, sous quoi une description d'objet redevient illisible.
		ec.droite.custom_minimum_size = Vector2(clampf(large - 500.0, 200.0, 360.0), 0)
		ec.droite.size_flags_stretch_ratio = 0.9
		ec.detail.size_flags_vertical = Control.SIZE_FILL   # le Wu Xing de l'objet juste sous le détail, pas au fond du panneau
		# Le détail prend la moitié haute, le Wu Xing de l'objet un tiers, et les deux se rabotent
		# ensemble quand la fenêtre raccourcit : c'est ce qui empêche la colonne de pousser le panneau
		# hors de l'écran. Sous 96 px le pentagramme n'est plus lisible — il s'efface alors.
		ec.detail.custom_minimum_size = Vector2(0, clampf(haut * 0.48, 110.0, 340.0))
		var cote_penta := clampf(haut * 0.34, 0.0, Composeur.PentagrammeSort.TAILLE)
		ec.penta_objet.visible = cote_penta >= 96.0
		ec.penta_objet.custom_minimum_size = Vector2(0, cote_penta + 18.0 if cote_penta >= 96.0 else 0.0)
		ec.inventaire_visuel.ajuster_largeur(large - ec.droite.custom_minimum_size.x)
		ec.inventaire_visuel.reconstruire()
	elif ec.courant in ["commerce", "echange"]:   # deux volets d'objets, le détail à droite (designer 2026-09-04)
		ec.droite.custom_minimum_size = Vector2(part_droite.call(300.0, 0.28), 0)
		ec.droite.size_flags_stretch_ratio = 0.6
		ec.detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ec.echange_visuel.reconstruire(ec.courant)
	elif ec.courant == "atelier":
		ec.droite.custom_minimum_size = Vector2(part_droite.call(380.0, 0.36), 0)
		ec.droite.size_flags_stretch_ratio = 0.8
		ec.detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ec.atelier_visuel.reconstruire()
	elif ec.courant == "dialogue":   # la carte : portrait, nom, informations, options lettrées (designer 2026-09-06)
		ec.dialogue_visuel.reconstruire()
	else:
		ec.droite.custom_minimum_size = Vector2(0, 0)
		ec.droite.size_flags_stretch_ratio = 1.0
		ec.detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ec.detail.custom_minimum_size = Vector2(0, 0)
	if ec.courant == "titre":   # rien derrière l'écran principal : pas de « Fermer »
		pass
	elif ec.courant == "creation":
		_bouton(ec, ec.tr("ui.creation.commencer"), func() -> void: ec.main._creer_personnage())
		_bouton(ec, ec.tr("ui.monde.retour"), func() -> void: ec.main.creation = {}; ec.ouvrir("titre"))
	elif ec.courant in ["monde", "charger"] or (ec.courant == "options" and ec.main.titre_ouvert):
		_bouton(ec, ec.tr("ui.monde.retour"), func() -> void: ec.ouvrir("titre"))
	else:
		_bouton(ec, ec.tr("ui.ecran.fermer"), ec.fermer)


## Une ligne qui porte une lettre : tout ce qui se choisit — pas un texte d'en-tête, pas une case d'équipement (la grille).
static func _lettrable(en: Dictionary) -> bool:
	return str(en.get("kind", "")) != "texte" and not bool(en.get("equipe", false)) and bool(en.get("lettre", true))


## Une option = une lettre, une page à la fois (designer 2026-09-06, 17 h 55) : après la construction d'un écran, les lignes
## qui se choisissent reçoivent a), b), c)… dans l'ordre ; s'il y en a plus que de lettres (styles.ecrans.lettres), seules
## celles de la page courante restent — les en-têtes et les cases d'équipement restent sur toutes les pages — et la
## dernière lettre est « Page suivante (n / N) ». Les textes de la liste prennent leur lettre en préfixe ; les écrans en
## icônes lisent `ec.lettres` (index → lettre) pour dessiner la leur.
static func _paginer(ec: Ecrans) -> void:
	ec.lettres.clear()
	var n_lettres := clampi(int(GameData.config("styles").get("ecrans", {}).get("lettres", 26)), 2, 26)
	var lettrables: Array[int] = []
	for i in ec.entrees.size():
		if _lettrable(ec.entrees[i]):
			lettrables.append(i)
	var par_page := n_lettres - 1
	var n_pages := 1 if lettrables.size() <= n_lettres else ceili(float(lettrables.size()) / float(par_page))
	if ec.page >= n_pages:
		ec.page = 0   # la dernière page tourne vers la première
	if n_pages > 1 and ec.liste.item_count == ec.entrees.size():
		var garder := {}
		var debut := ec.page * par_page
		for k in lettrables.size():
			if k >= debut and k < debut + par_page:
				garder[lettrables[k]] = true
		var entrees2: Array = []
		var textes: Array[String] = []
		var icones: Array = []
		var choisissables: Array[bool] = []
		for i in ec.entrees.size():
			if garder.has(i) or not _lettrable(ec.entrees[i]):
				entrees2.append(ec.entrees[i])
				textes.append(ec.liste.get_item_text(i))
				icones.append(ec.liste.get_item_icon(i))
				choisissables.append(ec.liste.is_item_selectable(i))
		ec.liste.clear()
		ec.entrees = entrees2
		for k in textes.size():
			ec.liste.add_item(textes[k], icones[k], choisissables[k])
		ec.liste.add_item(ec.tr("ui.ecran.page_suivante").format({"n": ec.page + 1, "total": n_pages}))
		ec.entrees.append({"kind": "page", "texte": ""})
	var k := 0
	for i in ec.entrees.size():
		if k >= n_lettres:
			break
		if _lettrable(ec.entrees[i]):
			var lettre := char(97 + k)
			ec.lettres[i] = lettre
			if i < ec.liste.item_count:   # les anciens rappels de raccourci « (E) » en fin de libellé s'effacent : la lettre est celle de la ligne
				ec.liste.set_item_text(i, "%s) %s" % [lettre, _sans_raccourci(ec.liste.get_item_text(i))])
			k += 1


static var _rx_raccourci: RegEx = null
static func _sans_raccourci(texte: String) -> String:
	if _rx_raccourci == null:
		_rx_raccourci = RegEx.new()
		_rx_raccourci.compile("\\s\\((?:[A-Z]|Échap|Esc)\\)(?=\\s—|$)")
	return _rx_raccourci.sub(texte, "")


## La lettre tapée (a → 0, b → 1…) joue la ligne qui la porte : la page suivante, ou l'action principale de la ligne.
static func choisir_lettre(ec: Ecrans, rang: int) -> bool:
	if rang < 0 or rang >= 26:
		return false
	var lettre := char(97 + rang)
	for i in ec.entrees.size():
		if ec.lettres.get(i, "") != lettre:
			continue
		if i < ec.liste.item_count and not ec.liste.is_item_selectable(i):
			return true   # une ligne grisée : la lettre est prise, rien ne se passe
		ec.selection = i
		if i < ec.liste.item_count:
			ec.liste.select(i)
		_action_principale(ec)
		return true
	return false


## La page suivante de l'écran (la dernière lettre, ou un clic sur sa ligne).
static func page_suivante(ec: Ecrans) -> void:
	ec.page += 1
	ec.selection = 0
	rafraichir(ec)


static func _bouton(ec: Ecrans, texte: String, action: Callable) -> void:
	var b := Button.new()
	b.text = texte
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	ec.boutons.add_child(b)


## Le glisser d'une capacité vers la hotbar (designer 2026-08-31, point 35).
static func _glisser_liste(ec: Ecrans, at: Vector2) -> Variant:
	if ec.courant != "capacites":
		return null
	var idx := ec.liste.get_item_at_position(at, true)
	if idx < 0 or idx >= ec.entrees.size():
		return null
	var en: Dictionary = ec.entrees[idx]
	if str(en.get("kind", "")) != "capacite":
		return null
	var ap := Label.new()
	ap.text = ec.liste.get_item_text(idx)
	ec.liste.set_drag_preview(ap)   # ecrans est un CanvasLayer : l'aperçu se pose sur le Control qui glisse
	return {"hotbar_type": "capacite", "ref": int(en.index)}


static func _depot_refuse(ec: Ecrans, _p: Vector2, _d: Variant) -> bool:
	return false


static func _depot_rien(ec: Ecrans, _p: Vector2, _d: Variant) -> void:
	pass


static func _sur_selection(ec: Ecrans, i: int) -> void:
	ec.selection = i
	_montrer_detail(ec)


static func _montrer_detail(ec: Ecrans) -> void:
	if ec.entrees.is_empty() or ec.selection >= ec.entrees.size():
		ec.detail.text = ""
		return
	var en: Dictionary = ec.entrees[ec.selection]
	if ec.courant == "charger":   # le portrait suit la ligne pointée, flèches comme souris (designer 2026-09-02)
		EcransCreation._portrait_partie(ec, str(en.get("id", "")))
	match str(en.get("kind", "")):
		"action_objet":
			ec.detail.text = EcransInventaire.texte_objet_et_actions(ec, str(en.uid))
			var it_a: Dictionary = ec.main.sim.items.get(str(en.uid), {})
			ec.penta_objet.visible = not ec.main.sim.inconnu(it_a)
			ec.penta_objet.montrer({"elements": ec.main.sim.vecteur_objet(it_a)})
			ec.inventaire_visuel.rafraichir_selection()
		"action_inventaire":
			ec.detail.text = ""
		"objet":
			ec.detail.text = EcransInventaire.texte_objet_et_actions(ec, str(en.uid)) if (ec.courant == "inventaire" and str(en.uid) == ec.objet_choisi) else EcransInventaire.texte_objet(ec, str(en.uid))
			if ec.courant == "inventaire":
				var it_p: Dictionary = ec.main.sim.items.get(str(en.uid), {})
				# Tout objet montre son Wu Xing (point 65) — sauf s'il n'est pas identifié : on ne lit
				# pas l'élément d'une fiole dont on ignore encore ce qu'elle contient.
				ec.penta_objet.visible = not ec.main.sim.inconnu(it_p)
				ec.penta_objet.montrer({"elements": ec.main.sim.vecteur_objet(it_p)})
				ec.inventaire_visuel.rafraichir_selection()
		"recette", "ingredient":
			ec.detail.text = EcransAtelier.texte_recette(ec, en.plan)
			if ec.courant == "atelier":
				ec.atelier_visuel.rafraichir_selection()
		"texte":
			ec.detail.text = str(en.texte)
		"donner", "reprendre":
			ec.detail.text = EcransInventaire.texte_objet(ec, str(en.uid))
		"achat", "vente":   # on n'achète plus à l'aveugle : la fiche et le Wu Xing de l'objet en vitrine (point 65)
			var pr: Dictionary = en.get("prix", {})
			var ligne := ec.tr("ui.commerce.detail_achat").format({"prix": int(pr.get("prix", 0)), "or": int(ec.main.joueur().get("or", 0))}) if str(en.kind) == "achat" else ec.tr("ui.commerce.detail_vente").format({"prix": int(pr.get("achat", 0))})
			ec.detail.text = ligne + "

" + EcransInventaire.texte_objet(ec, str(en.uid))
			var it_c: Dictionary = ec.main.sim.items.get(str(en.uid), {})
			ec.penta_objet.visible = not ec.main.sim.inconnu(it_c)
			ec.penta_objet.montrer({"elements": ec.main.sim.vecteur_objet(it_c)})
		"option", "quete", "cellule", "resident", "stock", "fonction", "voisin", "competence_entrainer", "menu", "contexte", "capacite", "nouvelle_capacite", "module_composer", "triche", "triche_catalogue", "triche_item", "titre", "monde", "options", "charger_slot":
			ec.detail.text = str(en.get("texte", ""))
		"creation":
			ec.detail.text = EcransCreation._detail_creation(ec, str(en.id))
		"achat", "vente":
			var p: Dictionary = en.prix
			ec.detail.text = EcransInventaire.texte_objet(ec, str(en.uid)) + "\n\n" + ec.tr("ui.prix.detail").format({"prix": int(p.prix), "base": p.base, "marge": p.marge, "qualite": p.qualite, "rarete": p.rarete, "rep": p.rep}) \
				+ "\n" + (ec.tr("ui.prix.vente").format({"n": int(p.prix)}) if en.kind == "achat" else ec.tr("ui.prix.achat").format({"n": int(p.achat)}))
		_:
			ec.detail.text = ""


static func _action_principale(ec: Ecrans) -> void:
	if ec.entrees.is_empty() or ec.selection >= ec.entrees.size():
		return
	var en: Dictionary = ec.entrees[ec.selection]
	var j: Dictionary = ec.main.joueur()
	match str(en.get("kind", "")):
		"page":
			page_suivante(ec)
			return
		"action_objet":
			EcransInventaire._action_objet(ec, str(en.action), str(en.uid))
			return
		"action_inventaire":
			EcransInventaire._action_inventaire(ec, str(en.action))
			return
		"objet":
			if ec.courant == "inventaire":   # choisir un objet, c'est voir ses options (designer 2026-09-06, 18 h 25)
				ec.objet_choisi = str(en.uid)
				rafraichir(ec)
				return
			if bool(en.get("equipe", false)):
				ec.main.sim.intention(j.id, {"type": "desequiper", "slot": str(en.slot)})
			else:
				ec.main.sim.intention(j.id, {"type": "equiper", "objet": str(en.uid)})
		"recette":
			ec.main.sim.intention(j.id, {"type": "fabriquer", "recette": str(en.plan.id)})
		"ingredient":
			ec.main.sim.basculer_ingredient(j, str(en.rid), str(en.uid))
		"option":
			EcransDialogue._option(ec, str(en.option))
			return
		"achat":
			ec.main.sim.intention(j.id, {"type": "acheter", "pnj": ec.pnj_id, "objet": str(en.uid)})
		"vente":
			ec.main.sim.intention(j.id, {"type": "vendre", "pnj": ec.pnj_id, "objet": str(en.uid)})
		"quete":
			var q: Dictionary = en.quete
			if q.etat == "offerte":
				ec.main.sim.intention(j.id, {"type": "accepter_quete", "pnj": ec.pnj_id, "quete": str(q.uid)})
			elif q.etat == "terminee":
				ec.main.sim.intention(j.id, {"type": "rendre_quete", "pnj": ec.pnj_id, "quete": str(q.uid)})
		"cellule":
			var roles: Array = ec.main.sim.regles.r.royaume.roles
			var cell: Vector2i = en.cellule
			var actuel := str(ec.main.sim.monde.claims[cell].role)
			ec.main.sim.changer_role(cell, str(roles[(roles.find(actuel) + 1) % roles.size()]))
		"type_perimetre":   # le type choisi : le monde attend deux clics
			ec.main.mode_perimetre = {"type": str(en.type)}
			ec.fermer()
			ec.main._log(ec.tr("journal.perimetre_dessin").format({"type": ec.tr("perimetre.%s.name" % str(en.type))}))
			return
		"resident":   # Entrée : réassigner — le choix de fonction s'ouvre depuis l'écran (Gestion de base, étape 2)
			ec.pnj_id = str(en.id)
			ec.ouvrir("assigner")
			return
		"compagnon":   # Entrée : suis-moi ⇄ attends ici (étape 3)
			var c_o: Dictionary = ec.main.sim.entites.get(str(en.id), {})
			ec.main.sim.ordonner(j, str(en.id), "attendre" if str(c_o.get("ordre", "suivre")) == "suivre" else "suivre")
		"stock":
			ec.main.sim.retirer_stock(j, str(en.cle))
		"donner", "reprendre":
			ec.main.sim.echanger(j, ec.pnj_id, str(en.uid), str(en.kind))
		"fonction":
			ec.main.sim.intention(j.id, {"type": "assigner", "pnj": ec.pnj_id, "fonction": str(en.fonction), "perimetre": str(en.get("perimetre", ""))})
			ec.fermer()
			return
		"competence_entrainer":
			ec.main.sim.intention(j.id, {"type": "entrainer", "pnj": ec.pnj_id, "competence": str(en.competence)})
		"menu":
			ec.main._action_menu(str(en.id))
			return
		"creation":
			EcransCreation._action_creation(ec, str(en.id), 0 if str(en.id) == "pose" else 1)
			return
		"titre":
			match str(en.id):
				"nouvelle": ec.main._nouvelle_partie()
				"continuer": ec.main._charger_partie()
				"charger": ec.ouvrir("charger")
				"options": ec.ouvrir("options")
				"quitter": ec.get_tree().quit()
			return
		"monde":
			if str(en.id).begins_with("opt:"):   # un réglage de génération (designer, point 49)
				EcransCreation._regler_monde(ec, str(en.id).trim_prefix("opt:"), 1)   # Entrée : un pas vers le haut
				rafraichir(ec)
				return
			match str(en.id):
				"graine": ec.main.graine_monde = randi() % 1000000
				"commencer":
					ec.main._commencer_monde()
					return
				"retour":
					ec.main.fiche_monde = {}
					ec.ouvrir("titre")
					return
		"options":
			match str(en.id):
				"langue": TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("fr") else "fr")
				"plein_ecran":
					var plein: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if plein else DisplayServer.WINDOW_MODE_FULLSCREEN)
				"retour":
					ec.ouvrir("titre" if ec.main.titre_ouvert else "menu")
					return
		"charger_slot":
			if str(en.id).is_empty():
				ec.ouvrir("titre")
			else:
				ec.main._charger_partie(str(en.id))
			return
		"capacite":
			ec.main.sim.supprimer_capacite(j, int(en.index))
		"nouvelle_capacite":
			ec.sequence_composee = []
			ec.crans_composes = []
			ec.ouvrir("composer")
			return
		"module_composer":   # Entrée ajoute (même déjà présent : la séquence se cumule) ; Suppr / Retour arrière retire
			ec.sequence_composee.append(str(en.module))
		"contexte":
			ec.fermer()
			ec.main._executer_option(en.opt)
			return
		"triche":
			ec.main.sim.triche(j, str(en.id))
		"triche_catalogue":
			ec.triche_categorie = str(en.id)
			ec.ouvrir("triche_liste")
			return
		"triche_item":
			ec.main.sim.triche(j, ec.triche_categorie, str(en.id))
	rafraichir(ec)


# ---------------------------------------------------------------- dialogue et commerce (E.23, Prix suggéré)
