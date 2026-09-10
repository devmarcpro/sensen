class_name EcransDialogue
extends RefCounted
## Le dialogue et le commerce : les répliques, l'histoire, la fiche du PNJ, les quêtes, l'échange.
## Bibliothèque STATIQUE des écrans (Modules de la simulation et le C++, 2026-09-06) : l'état et les nœuds vivent dans
## `Ecrans`, reçu en premier paramètre ; ici, seulement la construction et la logique d'un écran. Déplacé depuis
## `ecrans.gd` par `tools/fragmenter.py --cible ecrans`, sans changement de comportement.


static func ouvrir_dialogue(ec: Ecrans, id: String) -> void:
	ec.pnj_id = id
	var j: Dictionary = ec.main.joueur()
	ec.replique_key = ec.main.sim.replique(ec.main.sim.entites[id], j)
	ec.ouvrir("dialogue")


static func _construire_dialogue(ec: Ecrans, j: Dictionary) -> void:
	var pnj: Dictionary = ec.main.sim.entites.get(ec.pnj_id, {})
	if pnj.is_empty():
		ec.fermer()
		return
	ec.titre.text = ec.tr("ui.ecran.dialogue").format({"nom": ec.tr(pnj.name_key), "fonction": ec.tr(GameData.entree("functions", str(pnj.get("fonction", "oisif"))).name_key)})
	if pnj.has("boutique"):
		ec.titre.text += ec.tr("ui.dialogue.boutique").format({"boutique": ec.tr(GameData.entree("shop_types", str(pnj.boutique)).name_key)})
	if pnj.has("guilde"):
		ec.titre.text += ec.tr("ui.dialogue.guilde").format({"guilde": ec.tr("guilde.%s.name" % str(pnj.guilde))})
	if not str(pnj.get("titre", "")).is_empty():
		ec.titre.text += ec.tr("ui.dialogue.titre").format({"titre": ec.tr(str(pnj.titre))})
	var fam: Dictionary = pnj.get("family", {})
	var ftxt: Array[String] = []
	if not str(fam.get("spouse", "")).is_empty() and ec.main.sim.entites.has(str(fam.spouse)):
		ftxt.append(ec.tr("famille.conjoint").format({"nom": ec.tr(ec.main.sim.entites[str(fam.spouse)].name_key)}))
	for pid in fam.get("child_of", []):
		if ec.main.sim.entites.has(str(pid)):
			ftxt.append(ec.tr("famille.enfant").format({"nom": ec.tr(ec.main.sim.entites[str(pid)].name_key)}))
	if not fam.get("parent_of", []).is_empty():
		ftxt.append(ec.tr("famille.parent").format({"n": fam.parent_of.size()}))
	var rel := int(pnj.get("social", {}).get("relations", {}).get(j.id, 0))
	ec.liste.add_item(ec.tr("ui.ecran.parler"))
	ec.entrees.append({"kind": "option", "option": "parler"})
	if "civil" in pnj.get("tags", []) and not pnj.has("vehicule_etat") and not j.get("sac", []).is_empty():   # Offrir un cadeau (PNJ distincts)
		ec.liste.add_item(ec.tr("ui.ecran.offrir"))
		ec.entrees.append({"kind": "option", "option": "offrir"})
	if "commerce_possible" in pnj.get("tags", []):
		ec.liste.add_item(ec.tr("ui.ecran.commercer"))
		ec.entrees.append({"kind": "option", "option": "commercer"})
	if "quetes" in pnj.get("tags", []):
		ec.liste.add_item(ec.tr("ui.ecran.quetes"))
		ec.entrees.append({"kind": "option", "option": "quetes"})
	if pnj.has("vehicule_etat"):   # un train à quai, une calèche à l'arrêt (Villes B4)
		var ve: Dictionary = pnj.vehicule_etat
		var tcfg: Dictionary = GameData.config("villes").get("transports", {})
		if str(ve.type) == "train" and str(ve.etat) == "attend":
			var t_v: Dictionary = ec.main.sim.territoires.get(str(ve.ville), {})
			var centre_v: Vector2i = t_v.get("agglomeration", {}).get("centre", Vector2i(-99999, -99999))
			var roy_v := str(ec.main.sim.monde.surface.royaume_de(centre_v).get("id", ""))
			for f in ec.main.sim.villes_reliees(centre_v, int(tcfg.trains.distance_max)):
				if str(f.get("royaume", "")) != roy_v:
					continue
				var prix_t: int = Grille.distance(centre_v, Vector2i(f.centre)) * int(tcfg.trains.prix_par_cellule)
				ec.liste.add_item(ec.tr("ui.ecran.train_vers").format({"ville": str(f.nom), "prix": prix_t}))
				ec.entrees.append({"kind": "option", "option": "train:%d,%d" % [int(f.centre.x), int(f.centre.y)]})
		elif str(ve.type) == "caleche" and str(ve.etat) == "attend":
			for k in ve.places.size():
				var pl: Vector2i = ve.places[k]
				if Grille.distance(pl, j.pos) <= 8:
					continue
				ec.liste.add_item(ec.tr("ui.ecran.caleche_vers").format({"quartier": ec.tr("quartier." + str(ve.quartiers[k])), "prix": int(tcfg.caleches.prix_par_quartier)}))
				ec.entrees.append({"kind": "option", "option": "caleche:%d,%d" % [pl.x, pl.y]})
	if str(pnj.get("maitre", "")) == j.id and bool(GameData.catalogues.creatures.get(str(pnj.def), {}).get("monture", false)) and not j.has("monture"):
		ec.liste.add_item(ec.tr("ui.ecran.monter").format({"nom": ec.tr(str(pnj.name_key))}))
		ec.entrees.append({"kind": "option", "option": "monter"})
	if j.has("monture"):
		ec.liste.add_item(ec.tr("ui.ecran.descendre"))
		ec.entrees.append({"kind": "option", "option": "descendre"})
	if "maquignon" in pnj.get("tags", []):
		ec.liste.add_item(ec.tr("ui.ecran.acheter_monture").format({"prix": int(GameData.config("villes").get("transports", {}).get("montures", {}).get("prix_monture", 120))}))
		ec.entrees.append({"kind": "option", "option": "acheter_monture"})
	if pnj.has("assignation") and not pnj.has("maitre"):   # Compagnons : le suiveur territorial
		ec.liste.add_item(ec.tr("ui.ecran.suiveur"))
		ec.entrees.append({"kind": "option", "option": "suiveur"})
	if bool(pnj.get("suiveur_local", false)):
		ec.liste.add_item(ec.tr("ui.ecran.suiveur_stop"))
		ec.entrees.append({"kind": "option", "option": "suiveur_stop"})
	if pnj.has("maitre"):
		ec.liste.add_item(ec.tr("ui.ecran.incarner"))
		ec.entrees.append({"kind": "option", "option": "incarner"})
		ec.liste.add_item(ec.tr("ui.ecran.suivre"))
		ec.entrees.append({"kind": "option", "option": "suivre"})
		ec.liste.add_item(ec.tr("ui.ecran.attendre"))
		ec.entrees.append({"kind": "option", "option": "attendre"})
		ec.liste.add_item(ec.tr("ui.ecran.posture").format({"posture": ec.tr("posture." + str(pnj.get("posture", "defensive")))}))
		ec.entrees.append({"kind": "option", "option": "posture"})
		ec.liste.add_item(ec.tr("ui.ecran.retour"))
		ec.entrees.append({"kind": "option", "option": "retour"})
		ec.liste.add_item(ec.tr("ui.ecran.repli"))
		ec.entrees.append({"kind": "option", "option": "repli"})
		ec.liste.add_item(ec.tr("ui.ecran.echanger"))
		ec.entrees.append({"kind": "option", "option": "echanger"})
		if ec.main.sim.monde != null and ec.main.sim.monde.claims.has(ec.main.sim._cell_de(pnj.pos)):
			ec.liste.add_item(ec.tr("ui.ecran.assigner"))
			ec.entrees.append({"kind": "option", "option": "assigner"})
	else:
		var def: Dictionary = GameData.catalogues.creatures.get(str(pnj.def), {})
		var rc: Dictionary = def.get("recruitable", {"method": "jamais"})
		if (str(rc.get("method", "")) == "relation" and rel >= int(rc.get("threshold", 60)) - 10) or bool(pnj.get("recrutable_hors_condition", false)) or ec.main.sim.recrutable(j, pnj):   # sur tous les PNJ (designer 2026-09-05)
			var gratuit: bool = (str(rc.get("method", "")) == "relation" and rel >= int(rc.get("threshold", 60))) or bool(pnj.get("recrutable_hors_condition", false))
			ec.liste.add_item(ec.tr("ui.ecran.recruter") if gratuit else ec.tr("ui.ecran.recruter_prix").format({"prix": int(ec.main.sim.regles.r.compagnons.get("prix_recrutement", 40))}))
			ec.entrees.append({"kind": "option", "option": "recruter"})
			if ec.main.sim.monde != null and not ec.main.sim.monde.claims.is_empty() and not pnj.has("assignation"):   # engager pour la base (2026-09-04)
				ec.liste.add_item(ec.tr("ui.ecran.engager").format({"or": int(ec.main.sim._ry().get("engagement", {}).get("or", 20))}))
				ec.entrees.append({"kind": "option", "option": "engager"})
	if str(pnj.get("maitre", "")) == j.id or pnj.has("assignation"):
		var betail: bool = str(pnj.get("statut_habitat", "normal")) == "betail"
		ec.liste.add_item(ec.tr("ui.ecran.resident" if betail else "ui.ecran.betail"))
		ec.entrees.append({"kind": "option", "option": "statut_habitat"})
	if "entraineur" in pnj.get("tags", []):
		ec.liste.add_item(ec.tr("ui.ecran.entrainer"))
		ec.entrees.append({"kind": "option", "option": "entrainer"})
	var t_pnj = GameData.catalogues.classes.get(str(pnj.get("classe", "")), {}).get("talent")
	if t_pnj != null and str(t_pnj) != "sans_maitre" and (ec.main.sim.a_talent(j, "sans_maitre") or ec.main.sim.a_talent(j, "polyvalent")):
		ec.liste.add_item(ec.tr("ui.ecran.apprendre") + " — " + ec.tr(GameData.entree("talents", str(t_pnj)).name_key))
		ec.entrees.append({"kind": "option", "option": "apprendre_talent"})
	if "pretre" in pnj.get("tags", []):
		var ame: String = ec.main.sim.ame_dans_sac(j)
		ec.liste.add_item(ec.tr("ui.ecran.ressusciter").format({"cout": ec.main.sim.cout_resurrection(j, ame, true)}) if not ame.is_empty() else ec.tr("ui.ecran.ressusciter_rien"), null, not ame.is_empty())
		ec.entrees.append({"kind": "option", "option": "ressusciter"})
	if "commerce_possible" in pnj.get("tags", []) and not ec.main.sim.territoire.get("commande", {}).is_empty():
		ec.liste.add_item(ec.tr("ui.ecran.livrer"))
		ec.entrees.append({"kind": "option", "option": "livrer"})
	ec.liste.add_item(ec.tr("ui.ecran.partir"))
	ec.entrees.append({"kind": "option", "option": "partir"})
	# La carte de dialogue (designer 2026-09-06, 17 h 35) : sous le nom, la fonction (boutique, guilde, titre), la réplique,
	# la relation, la famille, puis la fiche révélée par paliers ; les options sont la liste lettrée de la carte.
	var sous_titre := ec.tr(GameData.entree("functions", str(pnj.get("fonction", "oisif"))).name_key)
	if pnj.has("boutique"):
		sous_titre += ec.tr("ui.dialogue.boutique").format({"boutique": ec.tr(GameData.entree("shop_types", str(pnj.boutique)).name_key)})
	if pnj.has("guilde"):
		sous_titre += ec.tr("ui.dialogue.guilde").format({"guilde": ec.tr("guilde.%s.name" % str(pnj.guilde))})
	if not str(pnj.get("titre", "")).is_empty():
		sous_titre += ec.tr("ui.dialogue.titre").format({"titre": ec.tr(str(pnj.titre))})
	var relation := ec.tr("ui.dialogue.relation").format({"n": rel}) + (("  ·  " + ec.tr("ui.dialogue.compagnon").format({"ordre": ec.tr("ordre." + str(pnj.get("ordre", "suivre")))})) if pnj.has("maitre") else "")
	var blocs: Array[String] = [sous_titre, "« %s »" % texte_replique(ec, pnj), relation]
	if not ftxt.is_empty():
		blocs.append(ec.tr("ui.dialogue.famille").format({"texte": " · ".join(ftxt)}))
	blocs.append(fiche_pnj(ec, pnj, j))
	ec.dialogue_infos = "\n".join(blocs)
	for en in ec.entrees:
		en["texte"] = "[b]%s[/b]\n%s" % [ec.tr(pnj.name_key), ec.dialogue_infos]


static func _option(ec: Ecrans, opt: String) -> void:
	var j: Dictionary = ec.main.joueur()
	if opt == "offrir":   # le choix du cadeau : les objets du sac en options (PNJ distincts)
		ec.liste.clear()
		ec.entrees.clear()
		for uid in j.get("sac", []).slice(0, 12):
			ec.liste.add_item(ec.tr("ui.ecran.offrir_objet").format({"objet": ec.main.nom_objet(ec.main.sim.nom_objet(str(uid)))}))
			ec.entrees.append({"kind": "option", "option": "offrir:" + str(uid)})
		ec.liste.add_item(ec.tr("ui.ecran.retour"))
		ec.entrees.append({"kind": "option", "option": "retour_dialogue"})
		ec.selection = 0
		EcransListe._paginer(ec)
		ec.dialogue_visuel.reconstruire()
		return
	if opt.begins_with("offrir:"):
		ec.main.sim.intention(j.id, {"type": "offrir", "pnj": ec.pnj_id, "objet": opt.substr(7)})
		ec.replique_key = str(ec.main.sim.replique(ec.main.sim.entites[ec.pnj_id], j))
		EcransListe.rafraichir(ec)
		return
	if opt == "retour_dialogue":
		EcransListe.rafraichir(ec)
		return
	if opt.begins_with("train:") or opt.begins_with("caleche:"):   # le train vers une gare, la calèche vers une place (Villes B4)
		var parts: PackedStringArray = opt.split(":")[1].split(",")
		var cible_v := Vector2i(int(parts[0]), int(parts[1]))
		if opt.begins_with("train:"):
			ec.main.sim.intention(j.id, {"type": "monter", "pnj": ec.pnj_id, "cellule": cible_v})
		else:
			ec.main.sim.intention(j.id, {"type": "monter", "pnj": ec.pnj_id, "vers": cible_v})
		ec.fermer()
		return
	match opt:
		"parler":
			if ec.main.sim.intention(j.id, {"type": "parler", "pnj": ec.pnj_id}):
				ec.replique_key = ec.main.sim.replique(ec.main.sim.entites[ec.pnj_id], j) if false else ec.replique_key
				var pnj: Dictionary = ec.main.sim.entites[ec.pnj_id]
				ec.replique_key = str(ec.main.sim.replique(pnj, j))
			EcransListe.rafraichir(ec)
		"commercer":
			ec.ouvrir("commerce")
		"quetes":
			ec.ouvrir("quetes")
		"monter":
			ec.main.sim.intention(j.id, {"type": "monter", "pnj": ec.pnj_id})
			ec.fermer()
		"descendre":
			ec.main.sim.intention(j.id, {"type": "descendre_monture"})
			ec.fermer()
		"acheter_monture":
			ec.main.sim.intention(j.id, {"type": "acheter_monture", "pnj": ec.pnj_id})
			EcransListe.rafraichir(ec)
		"recruter":
			ec.main.sim.intention(j.id, {"type": "recruter", "pnj": ec.pnj_id})
		"engager":
			ec.main.sim.intention(j.id, {"type": "engager", "pnj": ec.pnj_id})
			EcransListe.rafraichir(ec)
		"suiveur":
			ec.main.sim.suiveur_local(j, ec.pnj_id, true)
			EcransListe.rafraichir(ec)
		"suiveur_stop":
			ec.main.sim.suiveur_local(j, ec.pnj_id, false)
			EcransListe.rafraichir(ec)
		"suivre", "attendre", "retour", "repli":
			ec.main.sim.ordonner(j, ec.pnj_id, opt)
			EcransListe.rafraichir(ec)
		"posture":
			var cycle := ["defensive", "agressive", "eviter"]
			var pnj: Dictionary = ec.main.sim.entites.get(ec.pnj_id, {})
			ec.main.sim.ordonner(j, ec.pnj_id, cycle[(cycle.find(str(pnj.get("posture", "defensive"))) + 1) % cycle.size()])
			EcransListe.rafraichir(ec)
		"echanger":
			ec.ouvrir("echange")
		"incarner":
			if ec.main.sim.intention(j.id, {"type": "incarner", "pnj": ec.pnj_id}):
				ec.fermer()
			else:
				EcransListe.rafraichir(ec)
		"assigner":
			ec.ouvrir("assigner")
		"entrainer":
			ec.ouvrir("entrainer")
		"livrer":
			ec.main.sim.intention(j.id, {"type": "livrer", "pnj": ec.pnj_id})
			EcransListe.rafraichir(ec)
		"apprendre_talent":
			ec.main.sim.intention(j.id, {"type": "apprendre_talent", "pnj": ec.pnj_id})
			EcransListe.rafraichir(ec)
		"statut_habitat":
			var pnj_s: Dictionary = ec.main.sim.entites.get(ec.pnj_id, {})
			ec.main.sim.intention(j.id, {"type": "statut_habitat", "pnj": ec.pnj_id, "statut": "normal" if str(pnj_s.get("statut_habitat", "normal")) == "betail" else "betail"})
			EcransListe.rafraichir(ec)
		"ressusciter":
			var ame: String = ec.main.sim.ame_dans_sac(j)
			if not ame.is_empty():
				ec.main.sim.intention(j.id, {"type": "ressusciter", "ame": ame, "pnj": ec.pnj_id})
			EcransListe.rafraichir(ec)
		"partir":
			ec.fermer()


## CE QU'ON RACONTE ICI, ET CE QUE CELUI QUI PARLE EN PENSE (ordre de travail 29, 2026-09-09).
## Le fait le plus frais qui soit arrivé jusqu'à cette cellule — jamais un fait dont le PNJ est lui-même l'auteur, et
## jamais un fait dont la nouvelle n'est pas encore là : la fraîcheur le dit déjà, il suffit de la respecter.
## **Le ton vient des valeurs de ses factions**, pas d'une table de phrases : la même somme qui décide de sa relation
## décide de son indignation. C'est ce qui rend le système audible sans l'écrire deux fois.
static func texte_on_raconte(ec: Ecrans, pnj: Dictionary) -> String:
	var sim = ec.main.sim
	if sim == null or sim.monde == null:
		return ec.tr("dialogue.on_raconte.rien")
	var connus: Array = SimRumeur.connus(sim, sim.monde.cellule_de(pnj.get("pos", Vector2i.ZERO)), sim.horloge_monde.ticks)
	for c in connus:
		var fait: Dictionary = c.fait
		if str(fait.auteur) == str(pnj.id):
			continue   # on ne se raconte pas soi-même
		var qui := ec.tr("dialogue.on_raconte.quelqu_un")
		if str(fait.auteur) == str(ec.main.joueur().get("id", "")):
			qui = ec.tr("dialogue.on_raconte.toi")
		elif sim.entites.has(str(fait.auteur)):
			qui = ec.tr(str(sim.entites[str(fait.auteur)].name_key))
		# CE QU'IL EN PENSE : la somme de ce que ses factions valent à ce fait-là, et rien d'autre.
		var jugement := 0.0
		for fid in SimRumeur.factions_de(pnj):
			for tag in fait.tags:
				jugement += SimRumeur.valeur_de(str(fid), str(tag))
		var ton := "dialogue.on_raconte.neutre"
		if jugement < -0.5:
			ton = "dialogue.on_raconte.blame"
		elif jugement > 0.5:
			ton = "dialogue.on_raconte.approuve"
		return ec.tr("dialogue.on_raconte.prefixe").format({
			"qui": qui, "fait": ec.tr("fait." + str(fait.acte)), "ton": ec.tr(ton)})
	return ec.tr("dialogue.on_raconte.rien")


## La fiche d'un PNJ, révélée par paliers de relation (L'information comme récompense).
## La réplique d'un PNJ telle qu'elle s'affiche : une clé, ou « histoire » / « opinion » que le client compose.
static func texte_replique(ec: Ecrans, pnj: Dictionary) -> String:
	if ec.replique_key == "histoire" and pnj.has("histoire"):
		return texte_histoire(ec, pnj)
	if ec.replique_key == "rumeur_royaume":
		var etat_r: Dictionary = ec.main.sim.etat_royaume(str(pnj.get("royaume", "")))
		var jr: Array = etat_r.get("journal", [])
		if jr.is_empty():
			return ec.tr("dialogue.rumeur_royaume.rien")
		var ev: Dictionary = jr[jr.size() - 1]
		var pr: Dictionary = ev.get("params", {}).duplicate()
		for k in pr.keys():
			if pr[k] is String and str(pr[k]).contains("."):
				pr[k] = ec.tr(str(pr[k]))
		return ec.tr("dialogue.rumeur_royaume.prefixe").format({"rumeur": ec.tr(str(ev.cle)).format(pr)})
	# LE PNJ COLPORTE (ordre de travail 29, 2026-09-09). La rumeur existait et personne ne pouvait l'entendre : un
	# joueur voyait un garde le regarder de travers sans jamais apprendre pourquoi. Le PNJ raconte maintenant le
	# fait le plus FRAIS arrivé jusqu'ici — et il dit ce que SA faction en pense. Trois tons pour un même fait : le
	# bûcheron s'indigne de l'arbre abattu, le garde hausse les épaules, le Cercle du soufre s'en amuse.
	if ec.replique_key == "on_raconte":
		return texte_on_raconte(ec, pnj)
	if ec.replique_key == "opinion":
		var ops: Dictionary = pnj.get("social", {}).get("opinions", {})
		for autre in ops.keys():
			if ec.main.sim.entites.has(str(autre)):
				return ec.tr("dialogue.opinion.aime" if int(ops[autre]) >= 0 else "dialogue.opinion.n_aime_pas").format({"nom": ec.tr(ec.main.sim.entites[str(autre)].name_key)})
		return ec.tr("dialogue.opinion.personne")
	return ec.tr(ec.replique_key)


static func texte_histoire(ec: Ecrans, pnj: Dictionary) -> String:
	var h: Dictionary = pnj.get("histoire", {})
	var params: Dictionary = h.get("params", {}).duplicate()
	if params.has("metier"):
		params["metier"] = ec.tr(str(params.metier))
	return ec.tr(str(h.get("cle", ""))).format(params)


static func fiche_pnj(ec: Ecrans, pnj: Dictionary, j: Dictionary) -> String:
	var sim = ec.main.sim
	var palier: int = sim.palier_info(pnj, j)
	if palier == 0:
		return ec.tr("ui.fiche.apparence")
	var l: Array[String] = [ec.tr("ui.fiche.base").format({"nom": ec.tr(pnj.name_key), "fonction": ec.tr(GameData.entree("functions", str(pnj.get("fonction", "oisif"))).name_key), "village": str(pnj.get("village", "—"))})]
	if palier >= 2:
		var nd: Dictionary = sim.progression.niveaux_derives(pnj)
		l.append(ec.tr("ui.fiche.age").format({"genre": ec.tr("genre." + str(pnj.get("genre", "m"))), "age": int(pnj.get("age", 30)), "categorie": ec.tr("age." + sim.categorie_age(pnj)), "signe": str(pnj.get("nom", {}).get("culture", "—")), "niveau": int(round(maxf(nd.combat, nd.general)))}))
	if palier >= 3:
		var comps: Array[String] = []
		for cle in pnj.competences.keys():
			if int(pnj.competences[cle]) > 0:
				comps.append("%s %d" % [ec.tr(sim._nom_competence(cle)), int(pnj.competences[cle])])
		var equip: Array[String] = []
		for slot in pnj.equipement.keys():
			equip.append(ec.main.nom_objet(sim.nom_objet(pnj.equipement[slot])))
		l.append(ec.tr("ui.fiche.competences").format({"liste": " · ".join(comps) if not comps.is_empty() else "—", "equip": " · ".join(equip) if not equip.is_empty() else "—"}))
	if palier >= 3 and pnj.has("traits"):   # le caractère se lit à 50 (PNJ distincts)
		var noms_t: Array[String] = []
		for tid in pnj.traits:
			noms_t.append(ec.tr("trait.%s.name" % str(tid)))
		l.append(ec.tr("ui.fiche.traits").format({"traits": " · ".join(noms_t) if not noms_t.is_empty() else "—"}))
	if palier >= 4:
		var cadeaux: Array[String] = []
		for tid in pnj.get("traits", []):
			for c in GameData.catalogues.get("traits", {}).get(str(tid), {}).get("cadeaux", []):
				if not (str(c) in cadeaux):
					cadeaux.append(str(c))
		l.append(ec.tr("ui.fiche.souhait").format({"souhait": ec.tr("souhait.%s.name" % str(pnj.souhait)) if pnj.has("souhait") else "—", "cadeaux": " · ".join(cadeaux) if not cadeaux.is_empty() else "—"}))
	if palier >= 5:
		if pnj.has("histoire"):
			l.append(ec.tr("ui.fiche.histoire").format({"histoire": texte_histoire(ec, pnj)}))
		var ops: Dictionary = pnj.get("social", {}).get("opinions", {})
		var textes_o: Array[String] = []
		for autre in ops.keys():
			if sim.entites.has(str(autre)):
				textes_o.append(ec.tr("ui.fiche.opinion_aime" if int(ops[autre]) >= 0 else "ui.fiche.opinion_n_aime_pas").format({"nom": ec.tr(sim.entites[str(autre)].name_key)}))
		if not textes_o.is_empty():
			l.append(ec.tr("ui.fiche.opinions").format({"opinions": " · ".join(textes_o)}))
		l.append(ec.tr("ui.fiche.tout"))
		pnj["recrutable_hors_condition"] = true
	return "\n".join(l)


static func _construire_quetes(ec: Ecrans, j: Dictionary) -> void:
	var sim = ec.main.sim
	var pnj: Dictionary = sim.entites.get(ec.pnj_id, {})
	if pnj.is_empty():
		ec.fermer()
		return
	var g: Dictionary = j.get("guildes", {}).get("guerriers", {"xp": 0, "rang": 0})
	ec.titre.text = ec.tr("ui.quetes.titre").format({"nom": ec.tr(pnj.name_key), "guilde": ec.tr("guilde.guerriers.name"), "rang": ec.tr("rang." + str(sim.regles.r.guildes.rangs[int(g.rang)])), "xp": int(g.xp)})
	var offertes: Array = sim.quetes_offertes(pnj, j)
	if offertes.is_empty():
		ec.liste.add_item(ec.tr("ui.quetes.refus") if sim.relation_de(pnj, j) < int(sim.regles.r.reputation.quetes_seuil) else ec.tr("ui.quetes.aucune"))
		ec.entrees.append({"kind": "texte", "texte": ""})
	for q in offertes:
		if q.etat != "offerte":
			continue
		ec.liste.add_item(ec.tr("ui.quetes.offerte").format({"texte": EcransGestion._texte_quete(ec, q)}))
		ec.entrees.append({"kind": "quete", "quete": q, "texte": EcransGestion._texte_quete(ec, q) + "\n" + ec.tr("ui.quetes.recompense").format({"or": int(q.or), "xp": int(q.xp)})})
	for q in j.get("quetes", []):
		if q.etat == "en_cours" or q.etat == "terminee":
			var texte: String = EcransGestion._texte_quete(ec, q)
			ec.liste.add_item((ec.tr("ui.quetes.terminee") if q.etat == "terminee" else ec.tr("ui.quetes.en_cours")).format({"texte": texte, "fait": int(q.fait), "count": int(q.count)}))
			ec.entrees.append({"kind": "quete", "quete": q, "texte": texte + "\n" + ec.tr("ui.quetes.recompense").format({"or": int(q.or), "xp": int(q.xp)})})


static func _construire_commerce(ec: Ecrans, j: Dictionary) -> void:
	var pnj: Dictionary = ec.main.sim.entites.get(ec.pnj_id, {})
	if pnj.is_empty():
		ec.fermer()
		return
	var cm: Dictionary = ec.main.sim.regles.r.commerce
	ec.titre.text = ec.tr("ui.ecran.commerce").format({"nom": ec.tr(pnj.name_key), "or": str(int(pnj.get("or", 0))) if ec.main.sim.a_talent(j, "oeil_du_prix") else ec.tr("ui.commerce.bourse_cachee"), "joueur": int(j.get("or", 0))})
	ec.liste.add_item(ec.tr("ui.commerce.stock"), null, false)
	ec.entrees.append({"kind": "texte", "texte": ""})
	for uid in pnj.get("stock", []):
		var p: Dictionary = ec.main.sim.prix_suggere(uid, pnj, j)
		ec.liste.add_item("%s — %s" % [EcransInventaire._nom_court(ec, uid), ec.tr("ui.prix.or").format({"n": int(p.prix)})])
		ec.entrees.append({"kind": "achat", "uid": uid, "prix": p})
	ec.liste.add_item(ec.tr("ui.commerce.sac").format({"pct": int(float(cm.achat_ratio) * 100.0)}), null, false)
	ec.entrees.append({"kind": "texte", "texte": ""})
	for uid in j.sac:
		var p2: Dictionary = ec.main.sim.prix_suggere(uid, pnj, j)
		ec.liste.add_item("%s — %s" % [EcransInventaire._nom_court(ec, uid), ec.tr("ui.prix.or").format({"n": int(p2.achat)})])
		ec.entrees.append({"kind": "vente", "uid": uid, "prix": p2})


# ---------------------------------------------------------------- territoire (Population et exploitation, Entretien et taxes)
