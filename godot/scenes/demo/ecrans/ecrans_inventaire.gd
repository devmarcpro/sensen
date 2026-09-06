class_name EcransInventaire
extends RefCounted
## L'inventaire : le menu d'un objet, jeter, lire, sertir, manger, poser, le texte d'un objet.
## Bibliothèque STATIQUE des écrans (Modules de la simulation et le C++, 2026-09-06) : l'état et les nœuds vivent dans
## `Ecrans`, reçu en premier paramètre ; ici, seulement la construction et la logique d'un écran. Déplacé depuis
## `ecrans.gd` par `tools/fragmenter.py --cible ecrans`, sans changement de comportement.


static func _construire_inventaire(ec: Ecrans, j: Dictionary) -> void:
	ec.titre.text = ec.tr("ui.ecran.inventaire").format({"n": j.sac.size()})
	var slots: Array = Array(GameData.config("combat_rules").equipement.slots)
	for slot in slots:
		var uid: String = str(j.equipement.get(slot, ""))
		var nom: String = ec.main.nom_objet(ec.main.sim.nom_objet(uid)) if not uid.is_empty() else "—"
		ec.liste.add_item("%s : %s" % [ec.tr("slot." + slot), nom])
		ec.liste.set_item_custom_fg_color(ec.liste.item_count - 1, Color(0.85, 0.8, 0.55))
		ec.entrees.append({"kind": "objet", "uid": uid, "equipe": true, "slot": slot} if not uid.is_empty() else {"kind": "texte", "texte": ec.tr("ui.ecran.slot_vide")})
	ec.liste.add_item("— " + ec.tr("ui.ecran.sac") + " —", null, false)
	ec.entrees.append({"kind": "texte", "texte": ""})
	for uid in j.sac:
		ec.liste.add_item(_nom_court(ec, uid))
		ec.entrees.append({"kind": "objet", "uid": uid, "equipe": false})
	EcransListe._bouton(ec, ec.tr("ui.ecran.equiper"), func() -> void: EcransListe._action_principale(ec))
	EcransListe._bouton(ec, ec.tr("ui.ecran.jeter"), _jeter)
	EcransListe._bouton(ec, ec.tr("ui.ecran.lire"), _lire)
	EcransListe._bouton(ec, ec.tr("ui.ecran.sertir"), _sertir)
	EcransListe._bouton(ec, ec.tr("ui.ecran.manger"), _manger)
	if ec.main.sim.lieu == "camp":
		EcransListe._bouton(ec, ec.tr("ui.ecran.poser"), _poser)
		EcransListe._bouton(ec, ec.tr("ui.ecran.mur"), func() -> void: _mur(ec, false))
		EcransListe._bouton(ec, ec.tr("ui.ecran.porte"), func() -> void: _mur(ec, true))
		EcransListe._bouton(ec, ec.tr("ui.ecran.ranger"), _ranger)


## Le clic droit sur un objet du sac (designer 2026-08-31, point 46) : ses actions possibles,
## là où pointe la souris. Les entrées sont celles des boutons du bas, filtrées par le type d'objet.
static func menu_objet(ec: Ecrans, uid: String, ou: Vector2) -> void:
	if uid.is_empty() or ec.main.sim == null:
		return
	for k in ec.entrees.size():   # la ligne cliquée devient la sélection : les actions portent sur elle
		if ec.entrees[k].get("kind", "") == "objet" and str(ec.entrees[k].get("uid", "")) == uid:
			ec.selection = k
			break
	var it: Dictionary = ec.main.sim.items.get(uid, {})
	if it.is_empty():
		return
	var tags: Array = it.get("tags", [])
	var type_it := str(it.get("type", ""))
	var actions: Array = []
	if not str(it.get("equip_slot", "")).is_empty():
		actions.append(["ui.ecran.equiper", func() -> void: EcransListe._action_principale(ec)])
	if type_it in ["grimoire", "manuel"] or "ame" in tags:
		actions.append(["ui.ecran.lire", _lire])
	if type_it == "consommable" or "nourriture" in tags:
		actions.append(["ui.ecran.manger", _manger])
	if type_it == "gemme":
		actions.append(["ui.ecran.sertir", _sertir])
	if ec.main.sim.lieu == "camp":
		actions.append(["ui.ecran.poser", _poser])
	actions.append(["ui.ecran.jeter", _jeter])
	if ec.menu_contextuel_objet != null:
		ec.menu_contextuel_objet.queue_free()
	ec.menu_contextuel_objet = PopupMenu.new()
	ec.add_child(ec.menu_contextuel_objet)
	for k in actions.size():
		ec.menu_contextuel_objet.add_item(ec.tr(str(actions[k][0])), k)
	ec.menu_contextuel_objet.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < actions.size():
			(actions[id][1] as Callable).call())
	ec.menu_contextuel_objet.position = Vector2i(ou)
	ec.menu_contextuel_objet.popup()


static func _nom_court(ec: Ecrans, uid: String) -> String:
	var it: Dictionary = ec.main.sim.items[uid]
	var nom: String = ec.main.nom_objet(ec.main.sim.nom_objet(uid))
	if it.get("type", "") == "materiau":
		nom = ec.tr("forme." + str(it.get("forme", "brut"))).format({"materiau": nom}) + " ×%d" % int(it.quantite)
	elif int(it.get("quantite", 1)) > 1:
		nom += " ×%d" % int(it.quantite)
	return nom


static func _uid_selection(ec: Ecrans) -> String:
	if ec.entrees.is_empty() or ec.selection >= ec.entrees.size() or ec.entrees[ec.selection].get("kind", "") != "objet":
		return ""
	return str(ec.entrees[ec.selection].uid)


static func _jeter(ec: Ecrans) -> void:
	var uid := _uid_selection(ec)
	if not uid.is_empty():
		ec.main.sim.intention(ec.main.joueur().id, {"type": "jeter", "objet": uid})
		EcransListe.rafraichir(ec)


static func _lire(ec: Ecrans) -> void:
	var uid := _uid_selection(ec)
	if not uid.is_empty():
		var it: Dictionary = ec.main.sim.items.get(uid, {})
		if "ame" in it.get("tags", []):   # l'âme d'un compagnon : le rappeler à l'autel domestique
			ec.main.sim.intention(ec.main.joueur().id, {"type": "ressusciter", "ame": uid})
		else:
			ec.main.sim.intention(ec.main.joueur().id, {"type": "lire", "objet": uid})
		EcransListe.rafraichir(ec)


static func _sertir(ec: Ecrans) -> void:
	var uid := _uid_selection(ec)
	var j: Dictionary = ec.main.joueur()
	if not uid.is_empty() and j.equipement.has("main_principale"):
		if not ec.main.sim.intention(j.id, {"type": "sertir", "objet": j.equipement.main_principale, "gemme": uid}):
			ec.main._log(ec.tr("journal.pas_de_sertissure"))
		EcransListe.rafraichir(ec)


## La tuile devant le joueur (son orientation), sinon la première adjacente libre.
static func _devant(ec: Ecrans, j: Dictionary) -> Vector2i:
	var g: Grille = ec.main.sim.grille
	var t: Vector2i = j.pos + j.orientation
	if g.dans(t) and g.contenu_de(t).is_empty() and g.occupant(t).is_empty():
		return t
	for d in Grille.DIRS:
		var v: Vector2i = j.pos + d
		if g.dans(v) and g.contenu_de(v).is_empty() and g.occupant(v).is_empty():
			return v
	return t


static func _manger(ec: Ecrans) -> void:
	var uid := _uid_selection(ec)
	if not uid.is_empty():
		ec.main.sim.intention(ec.main.joueur().id, {"type": "manger", "objet": uid})
		EcransListe.rafraichir(ec)


static func _poser(ec: Ecrans) -> void:
	var uid := _uid_selection(ec)
	var j: Dictionary = ec.main.joueur()
	if not uid.is_empty():
		ec.main.sim.intention(j.id, {"type": "poser", "objet": uid, "vers": _devant(ec, j)})
		EcransListe.rafraichir(ec)


static func _mur(ec: Ecrans, porte: bool) -> void:
	var j: Dictionary = ec.main.joueur()
	ec.main.sim.intention(j.id, {"type": "poser_porte" if porte else "poser_mur", "vers": _devant(ec, j)})
	EcransListe.rafraichir(ec)


static func _ranger(ec: Ecrans) -> void:
	var uid := _uid_selection(ec)
	var j: Dictionary = ec.main.joueur()
	if uid.is_empty():
		return
	for d in Grille.DIRS:
		var t: Vector2i = j.pos + d
		if ec.main.sim.grille.dans(t) and not ec.main.sim._coffre_a(t).is_empty():
			ec.main.sim.intention(j.id, {"type": "ranger", "objet": uid, "vers": t})
			break
	EcransListe.rafraichir(ec)


## Le détail exhaustif d'un objet (Infobulle exhaustive : aucune information cachée).
static func texte_objet(ec: Ecrans, uid: String) -> String:
	var sim = ec.main.sim
	var it: Dictionary = sim.items.get(uid, {})
	if it.is_empty():
		return ""
	var l: Array[String] = ["[b]%s[/b]" % ec.main.nom_objet(sim.nom_objet(uid))]
	l.append(ec.tr("ui.objet.type").format({"type": ec.tr("type." + str(it.get("type", ""))), "slot": ec.tr("slot." + str(it.equip_slot)) if not str(it.get("equip_slot", "")).is_empty() else "—", "rarete": ec.tr("rarete." + str(it.get("rarete", "commun")))}))
	if it.has("qualite") and it.get("type", "") != "materiau":
		l.append(ec.tr("ui.objet.qualite").format({"palier": ec.tr("qualite." + sim.regles.palier_qualite(float(it.qualite))), "valeur": "%.2f" % float(it.qualite)}))
	if it.has("functionality"):
		var f: Dictionary = sim.fonctionnalites.get(str(it.functionality), {})
		if not f.is_empty():
			l.append(ec.tr("ui.objet.arme").format({"des": f.degats_des, "type": ec.tr("degats." + str(f.type_degats)), "ticks": sim.regles.ticks_attaque(f, false, it), "portee": "%d-%d" % [int(f.get("portee_min", 1)), int(f.portee)]}))
	if it.has("durete_base"):
		l.append(ec.tr("ui.objet.durete").format({"durete": int(it.durete_base), "ref": int(sim.regles.r.degats.durete_reference), "facteur": "%.2f" % (float(it.durete_base) / float(sim.regles.r.degats.durete_reference) * float(it.get("qualite", 1.0)))}))
	if it.has("durete_composite"):
		l.append(ec.tr("ui.objet.armure").format({"zone": ec.tr("zone." + str(it.get("zone", ""))), "construction": ec.tr("construction.%s.nom" % it.get("construction", "")), "durete": int(it.durete_composite), "niveau": int(it.get("niveau_construction", 0))}))
	if it.has("elements") or it.has("element"):
		var vec: Dictionary = it.get("elements", {str(it.get("element", "")): 1.0})
		var parts: Array[String] = []
		for el in vec.keys():
			parts.append("%s %d %%" % [ec.tr("element." + str(el)), roundi(float(vec[el]) * 100.0)])
		l.append(ec.tr("ui.objet.elements").format({"liste": " · ".join(parts)}))
	if it.has("vitesse_facteur"):
		l.append(ec.tr("ui.objet.vitesse").format({"facteur": "%.2f" % float(it.vitesse_facteur)}))
	if it.has("composants"):
		l.append(ec.tr("ui.objet.composants"))
		for slot in it.composants.keys():
			var c: Dictionary = it.composants[slot]
			l.append("   %s : %s — %s (%s %.2f)" % [ec.tr("slotc." + str(slot)), ec.tr(GameData.entree("components", str(c.composant)).name_key), ec.tr(GameData.entree("materials", str(c.materiau)).name_key), ec.tr("qualite." + sim.regles.palier_qualite(float(c.qualite))), float(c.qualite)])
	if it.get("type", "") == "composant":
		l.append(ec.tr("ui.objet.composant").format({"materiau": ec.tr(GameData.entree("materials", str(it.materiau)).name_key)}))
	if it.get("type", "") == "materiau":
		var m: Dictionary = GameData.entree("materials", str(it.materiau))
		l.append(ec.tr("ui.objet.materiau").format({"categorie": ec.tr("categorie." + str(m.category)), "forme": ec.tr("forme." + str(it.get("forme", "brut"))).format({"materiau": ec.tr(m.name_key)}), "quantite": int(it.quantite)}))
	if it.has("stats") and it.stats is Dictionary and not it.stats.is_empty():
		var st: Array[String] = []
		for k in it.stats.keys():
			st.append("%s %d" % [ec.tr("mstat." + str(k)), roundi(float(it.stats[k]))])
		l.append(ec.tr("ui.objet.stats").format({"liste": " · ".join(st)}))
	elif it.get("type", "") == "materiau":
		var m2: Dictionary = GameData.entree("materials", str(it.materiau))
		var st2: Array[String] = []
		for k in m2.stats.keys():
			st2.append("%s %d" % [ec.tr("mstat." + str(k)), int(m2.stats[k])])
		l.append(ec.tr("ui.objet.stats").format({"liste": " · ".join(st2)}))
	for ax in it.get("affixes", []):
		var a: Dictionary = GameData.catalogues.affixes.get(str(ax.id), {})
		var p: Dictionary = ax.get("params", {}).duplicate()
		p["base"] = ""
		if p.has("element"):
			p["epithete"] = ec.tr("epithete." + str(p.element))
			p["element"] = ec.tr("element." + str(p.element))
		l.append("   ✦ " + ec.tr(str(a.get("name_key", ax.id))).format(p).strip_edges())
	if it.has("sertissures"):
		var s: Dictionary = it.sertissures
		l.append(ec.tr("ui.objet.sertissures").format({"n": int(s.nombre), "contenu": str(s.contenu.size())}))
	if it.has("livre"):
		l.append(ec.tr("ui.objet.livre").format({"domaine": ec.tr("domaine." + str(it.livre.domaine)), "difficulte": int(it.livre.difficulte), "n": int(it.livre.n)}))
	if it.get("type", "") == "consommable":
		var pot: Array[String] = []
		for stt in it.get("potentiel", {}).keys():
			pot.append("%s +%d" % [ec.tr(sim._nom_competence(str(stt))), int(it.potentiel[stt])])
		l.append(ec.tr("ui.objet.consommable").format({"nutrition": int(it.get("nutrition", 0)), "soin": str(it.get("soin_des", "")) if not str(it.get("soin_des", "")).is_empty() else "—", "mana": int(it.get("mana", 0)),
			"statut": str(it.get("statut", "")) if not str(it.get("statut", "")).is_empty() else "—", "potentiel": " · ".join(pot) if not pot.is_empty() else "—", "cru": ec.tr("ui.objet.consommable.cru") if bool(it.get("cru", false)) else ""}))
	l.append(ec.tr("ui.objet.poids").format({"poids": "%.1f" % sim.regles.poids_objet(it, sim.fonctionnalites)}))
	if it.get("type", "") == "meuble":
		var mb: Dictionary = GameData.entree("meubles", str(it.meuble))
		var det: Array[String] = []
		if bool(mb.dormir):
			det.append(ec.tr("ui.objet.meuble.lit"))
		if int(mb.capacite_slots) > 0:
			det.append(ec.tr("ui.objet.meuble.slots").format({"n": int(mb.capacite_slots)}))
		if int(mb.luminosite) > 0:
			det.append(ec.tr("ui.objet.meuble.lumiere").format({"n": int(mb.luminosite)}))
		l.append(ec.tr("ui.objet.meuble").format({"type": str(mb.type_meuble), "details": " · ".join(det) if not det.is_empty() else "—"}))
	if it.get("type", "") == "station":
		var stn: Dictionary = GameData.entree("stations", str(it.station))
		l.append(ec.tr("ui.objet.station").format({"poids": int(stn.poids), "competence": ec.tr(sim._nom_competence(str(stn.craft_skill)))}))
	if not it.get("tags", []).is_empty():
		var tags_tr: Array[String] = []   # les étiquettes ont leur mot (« portative » s'affichait en anglais, 2026-09-04) ; une inconnue reste telle quelle
		for t in it.tags:
			var cle_t := "tag." + str(t)
			var mot := ec.tr(cle_t)
			tags_tr.append(mot if mot != cle_t else str(t))
		l.append("[color=#888]" + " · ".join(tags_tr) + "[/color]")
	return "\n".join(l)


# ---------------------------------------------------------------- atelier
