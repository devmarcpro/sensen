class_name EcransGestion
extends RefCounted
## La gestion du territoire : le rapport, les lois, le registre, l'entraîneur, les quêtes, les capacités et le composeur, le titre.
## Bibliothèque STATIQUE des écrans (Modules de la simulation et le C++, 2026-09-06) : l'état et les nœuds vivent dans
## `Ecrans`, reçu en premier paramètre ; ici, seulement la construction et la logique d'un écran. Déplacé depuis
## `ecrans.gd` par `tools/fragmenter.py --cible ecrans`, sans changement de comportement.


static func _construire_gestion(ec: Ecrans, j: Dictionary) -> void:
	var sim = ec.main.sim
	if sim.monde == null:
		ec.fermer()
		return
	var t: Dictionary = sim.territoire
	ec.titre.text = ec.tr("ui.ecran.gestion").format({"n": sim.monde.claims.size(), "pnj": sim.residents().size(), "tresor": int(t.tresor), "dette": int(t.dette), "prev": sim.previsionnel()})
	var cells: Array = sim.monde.claims.keys()
	cells.sort()
	for cell in cells:
		ec.liste.add_item(ec.tr("ui.gestion.cellule").format({"x": cell.x, "y": cell.y, "role": ec.tr("role." + str(sim.monde.claims[cell].role)), "camp": ec.tr("ui.gestion.camp") if cell == sim.monde.cellule_camp else ""}))
		ec.entrees.append({"kind": "cellule", "cellule": cell, "texte": ec.tr("ui.gestion.role_aide") + "\n" + ec.tr("ui.gestion.perimetre_touche")})
		for pid_c in sim.perimetres_de(cell):   # les périmètres de la cellule (Population et exploitation, 2026-09-04) — dessinés ou entiers
			var per_c: Dictionary = sim.perimetres()[pid_c]
			var tp_c: Dictionary = sim.regles.r.royaume.perimetres.types.get(str(per_c.type), {})
			var n_res := 0
			for x_r in sim.residents():
				if str(x_r.assignation.get("perimetre", "")) == pid_c or str(x_r.assignation.get("residence", "")) == pid_c:
					n_res += 1
			var st_txt: String = ""   # court sur la ligne (la colonne coupe à quarante signes), entier dans le détail
			var st_long: String = ""
			if bool(tp_c.get("stockage", false)):
				st_txt = ec.tr("ui.gestion.stockage_capacite").format({"reste": sim.place_stockage(pid_c), "capacite": int(per_c.get("capacite", 0))})
				st_long = st_txt
			elif not bool(tp_c.get("residentiel", false)):
				var st_id: String = str(per_c.get("stockage", ""))
				if sim.perimetres().has(st_id):
					var cs: Vector2i = sim.perimetres()[st_id].cellule
					st_txt = ec.tr("ui.gestion.stockage_vers_court").format({"cellule": "(%d,%d)" % [cs.x, cs.y]})
					st_long = ec.tr("ui.gestion.stockage_vers").format({"cellule": "(%d,%d)" % [cs.x, cs.y]})
				else:
					st_txt = ec.tr("ui.gestion.sans_stockage_court")
					st_long = ec.tr("ui.gestion.sans_stockage")
			else:   # résidentiel : combien de chaumières tiennent encore sur ses tuiles libres (grande base, 2026-09-04)
				var bat_r: Dictionary = GameData.catalogues.get("village_buildings", {}).get(str(sim.regles.r.royaume.maisons.get("plan", "chaumiere")), {})
				var plan_r: Array = bat_r.get("plan", [])
				var w_r := 0
				for l_r in plan_r:
					w_r = maxi(w_r, str(l_r).length())
				var t_r: int = maxi(1, w_r * plan_r.size())
				st_txt = ec.tr("ui.gestion.residentiel_place").format({"n": int(per_c.richesse) / t_r})
				st_long = ec.tr("ui.gestion.residentiel_detail").format({"w": w_r, "h": plan_r.size(), "t": t_r})
			ec.liste.add_item(ec.tr("ui.gestion.perimetre").format({"type": ec.tr("perimetre.%s.name" % str(per_c.type)), "richesse": int(per_c.richesse), "reserve": int(per_c.reserve), "dominant": ec.tr(GameData.entree("materials", str(per_c.dominant)).get("name_key", "ui.assigner.rien")) if not str(per_c.dominant).is_empty() else ec.tr("ui.assigner.rien"), "n": n_res, "stockage": st_txt}))
			var detail_p: String = ec.tr("ui.gestion.perimetre_detail").format({"reserve": int(per_c.reserve), "dominant": ec.tr(GameData.entree("materials", str(per_c.dominant)).get("name_key", "ui.assigner.rien")) if not str(per_c.dominant).is_empty() else ec.tr("ui.assigner.rien")})
			ec.entrees.append({"kind": "perimetre", "id": pid_c, "cellule": cell, "texte": (st_long + "
" if not st_long.is_empty() else "") + detail_p + "
" + ec.tr("ui.gestion.perimetre_aide")})
	var residents_tries: Array = sim.residents().duplicate()   # par métier puis par nom : vingt lignes se lisent par groupes (2026-09-04)
	residents_tries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var fa := ec.tr(GameData.entree("functions", str(a.assignation.fonction)).name_key)
		var fb := ec.tr(GameData.entree("functions", str(b.assignation.fonction)).name_key)
		return fa < fb if fa != fb else ec.tr(a.name_key) < ec.tr(b.name_key))
	for x in residents_tries:
		var poste: Vector2i = x.get("poste", x.pos)
		var cell_p: Vector2i = sim._cell_de(poste)
		var per_x: Dictionary = sim.perimetres().get(str(x.assignation.get("perimetre", "")), {})   # son poste : le périmètre, sinon la cellule (grande base, 2026-09-04)
		var poste_txt: String = ec.tr("ui.gestion.poste_perimetre").format({"type": ec.tr("perimetre.%s.name" % str(per_x.type)), "x": cell_p.x, "y": cell_p.y}) if not per_x.is_empty() else ec.tr("ui.gestion.poste_cellule").format({"x": cell_p.x, "y": cell_p.y})
		ec.liste.add_item(ec.tr("ui.gestion.resident").format({"nom": ec.tr(x.name_key), "fonction": ec.tr(GameData.entree("functions", str(x.assignation.fonction)).name_key), "betail": ec.tr("ui.gestion.betail") if str(x.get("statut_habitat", "normal")) == "betail" else "", "humeur": int(x.get("humeur", 60)), "facteur": "%.2f" % sim.facteur_humeur(x), "logement": ec.tr("ui.gestion.loge" if x.has("lit") else "ui.gestion.sans_lit"), "poste": poste_txt}))
		ec.entrees.append({"kind": "resident", "id": x.id, "texte": ec.tr("ui.gestion.resident_detail").format({"facteur": "%.2f" % sim.facteur_humeur(x), "poste": poste_txt}) + " · " + EcransCreation._texte_production(ec, sim.production_de(x)) + "\n" + ec.tr("ui.gestion.resident_aide")})
	for c in sim.compagnons_de(j, true):   # l'escorte, sous les résidents (Décision — Gestion de base, étape 3)
		ec.liste.add_item(ec.tr("ui.gestion.compagnon").format({"nom": ec.tr(c.name_key), "ordre": ec.tr("ordre." + str(c.get("ordre", "suivre"))), "sante": int(c.sante), "sante_max": int(c.sante_max)}))
		ec.entrees.append({"kind": "compagnon", "id": c.id, "texte": ec.tr("ui.gestion.compagnon_aide")})
	for cle in t.stocks.keys():
		ec.liste.add_item(ec.tr("ui.gestion.stock").format({"nom": str(cle).split("|")[0], "n": int(t.stocks[cle])}))
		ec.entrees.append({"kind": "stock", "cle": cle, "texte": ec.tr("ui.gestion.stock_aide")})
	for r in t.rapports:
		ec.liste.add_item(ec.tr("ui.gestion.rapport").format({"texte": ec.tr("journal.rapport_semaine").format(r)}), null, false)
		ec.entrees.append({"kind": "texte", "texte": ec.tr("journal.rapport_semaine").format(r)})
	var gouv: String = ec.tr(GameData.entree("governments", str(t.gouvernance)).name_key) if not str(t.gouvernance).is_empty() else "—"
	var trans: String = ec.tr("ui.gestion.transition").format({"cible": ec.tr(GameData.entree("governments", str(t.gouvernance_cible)).name_key), "n": int(t.transition)}) if int(t.transition) > 0 else ""
	var dr: Dictionary = t.dernier_raid
	var raid_txt: String = ec.tr("ui.gestion.aucun_raid") if dr.is_empty() else ec.tr("ui.gestion.raid").format({"force": dr.force, "defense": dr.defense, "issue": ec.tr("ui.gestion.victoire" if bool(dr.victoire) else "ui.gestion.defaite"), "perte": int(round(float(dr.perte) * 100.0))})
	ec.liste.add_item(ec.tr("ui.gestion.royaume").format({"statut": ec.tr("ui.gestion.royaume_statut" if bool(t.royaume) else "ui.gestion.campement"), "gouv": gouv, "transition": trans, "defense": "%.1f" % sim.defense_totale(), "valeur": int(sim.valeur_territoire()), "raid": raid_txt}), null, false)
	ec.entrees.append({"kind": "texte", "texte": ec.tr("ui.gestion.gouv_aide")})
	for roy in sim.royaumes_voisins():
		var accord: String = str(t.accords.get(str(roy.id), ""))
		ec.liste.add_item(ec.tr("ui.gestion.voisin").format({"nom": roy.nom, "gouv": ec.tr(GameData.entree("governments", str(roy.government_type)).name_key), "n": roy.territory_cells.size(), "rep": int(j.get("reputations", {}).get(str(roy.id), 0)), "rel": ec.tr("relation." + sim.relation_royaume(j, roy)), "accord": ec.tr("accord." + accord) if not accord.is_empty() else ec.tr("accord.aucun")}))
		ec.entrees.append({"kind": "voisin", "id": str(roy.id), "texte": ec.tr("ui.gestion.voisin_aide") + "\n" + _lois_txt(ec, roy)})
	var npieces := 0
	var loges := 0
	for cell0 in sim.monde.claims.keys():
		var ps: Array = sim.pieces_de_cellule(cell0)
		npieces += ps.size()
		for x in sim.residents():
			if not sim._piece_du_lit(x.get("lit", Vector2i(-1, -1)), ps).is_empty():
				loges += 1
	ec.liste.add_item(ec.tr("ui.gestion.pieces").format({"n": npieces, "logees": loges}), null, false)
	ec.entrees.append({"kind": "texte", "texte": ""})
	var mures := 0
	for c in t.cultures.values():
		if bool(c.mure):
			mures += 1
	ec.liste.add_item(ec.tr("ui.gestion.boutique").format({"caisse": int(t.caisse), "marge": "%.2f" % float(t.marge), "etals": t.etals.size(), "clients": "%.1f" % float(t.clients)}), null, false)
	ec.entrees.append({"kind": "texte", "texte": ""})
	ec.liste.add_item(ec.tr("ui.gestion.parcelles").format({"n": t.cultures.size(), "mures": mures}), null, false)
	ec.entrees.append({"kind": "texte", "texte": ""})
	var nv := 0
	var especes: Array[String] = []
	for esp in t.get("registre", {}).keys():
		nv += t.registre[esp].size()
		especes.append(ec.tr(GameData.entree("species", str(esp)).name_key))
	ec.liste.add_item(ec.tr("ui.gestion.elevage").format({"n": nv, "especes": ", ".join(especes) if not especes.is_empty() else "—"}), null, false)
	ec.entrees.append({"kind": "texte", "texte": ""})
	var cmd: Dictionary = t.get("commande", {})
	ec.liste.add_item(ec.tr("ui.gestion.commande").format({"espece": ec.tr(GameData.entree("species", str(cmd.espece)).name_key), "couleur": cmd.couleur, "motif": cmd.motif, "or": int(cmd.or), "chatoyant": ec.tr("ui.gestion.commande_chatoyant") if bool(cmd.get("chatoyant", false)) else ""}) if not cmd.is_empty() else ec.tr("ui.gestion.commande_aucune"), null, false)
	ec.entrees.append({"kind": "texte", "texte": ""})
	# Les actions du territoire qui ne portent sur aucune entrée : des lignes lettrées après la liste (designer 2026-09-06, 18 h 50)
	EcransListe._actions_ecran(ec, [["ui.ecran.deposer", "deposer"], ["ui.ecran.retirer", "retirer"], ["ui.choix.gouvernance_suivante", "gouvernance_suivante"], ["ui.choix.marge_plus", "marge_plus"], ["ui.choix.marge_moins", "marge_moins"]])


static func _lois_txt(ec: Ecrans, roy: Dictionary) -> String:
	var sim = ec.main.sim
	var l: Array[String] = []
	# Le dirigeant, la vacance, les villages connus, la diplomatie (Familles et succession, Gouvernance).
	var dirigeant := ""
	for x in sim.vivants():
		if str(x.get("royaume", "")) == str(roy.id) and str(x.get("fonction", "")) == "dirigeant":
			dirigeant = ec.tr(x.name_key) + ((" — " + ec.tr(str(x.titre))) if not str(x.get("titre", "")).is_empty() else "")
	if sim.monde.vacances.has(str(roy.id)):
		dirigeant = ec.tr("ui.carte.vacance") + " (%d sem.)" % maxi(0, int(sim.monde.vacances[str(roy.id)]) - int(sim.monde.semaine_courante))
	if dirigeant.is_empty():
		dirigeant = ec.tr("ui.royaume.dirigeant_inconnu")
	var villages: Array[String] = []
	for nom in sim.monde.villages.keys():
		if str(sim.monde.villages[nom].get("royaume", "")) == str(roy.id):
			villages.append(str(nom) + (" (conquis)" if not str(sim.monde.villages[nom].get("conquis_par", "")).is_empty() else ""))
	var diplo: Array[String] = []
	for autre in roy.get("diplomacy", {}).keys():
		diplo.append("%s : %s" % [str(autre), ec.tr("relation." + str(roy.diplomacy[autre]))])
	l.append(ec.tr("ui.royaume.fiche").format({"race": ec.tr("race.%s.name" % str(roy.get("race", "humain"))), "culture": str(roy.get("culture", "")), "capitale": "(%d,%d)" % [roy.capital_poi.x, roy.capital_poi.y], "dirigeant": dirigeant,
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
static func _construire_registre(ec: Ecrans, _j: Dictionary) -> void:
	var sim = ec.main.sim
	var t: Dictionary = sim.territoire
	var reg: Dictionary = t.get("registre", {})
	var nv := 0
	for esp in reg.keys():
		nv += reg[esp].size()
	var pal: Dictionary = sim.paliers_elevage()
	var atteints: Array[String] = []
	for a in pal.atteints:
		atteints.append(ec.tr(str(a)).format({"n": pal.get(str(a).trim_prefix("palier."), 0)}))
	ec.titre.text = ec.tr("ui.ecran.registre").format({"n": nv, "especes": reg.size(), "total": GameData.catalogues.species.size(), "paliers": ", ".join(atteints) if not atteints.is_empty() else ec.tr("ui.registre.paliers_aucun")})
	if reg.is_empty():   # la ligne était coupée dans la colonne et le détail restait vide : la phrase entière se lit à droite
		ec.liste.add_item(ec.tr("ui.registre.aucun"))
		ec.entrees.append({"kind": "texte", "texte": ec.tr("ui.registre.aucun")})
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
				rtxt += ec.tr("ui.registre.record").format({"locus": str(nom), "v": "%.2f" % float(recs[nom])})
				lignes.append("%s : record %.2f" % [str(nom), float(recs[nom])])
			elif recs[nom] is Dictionary:
				var als: Array = recs[nom].keys()
				als.sort()
				lignes.append("%s : allèles vus %s" % [str(nom), ", ".join(als)])
		var nch: int = int(t.get("chatoyants", {}).get(esp, 0))
		ec.liste.add_item(ec.tr("ui.registre.espece").format({"nom": ec.tr(e.name_key), "mode": str(e.get("registre", "grille")), "n": reg[esp].size(), "possibles": sim.varietes_possibles(str(esp)), "records": rtxt + (ec.tr("ui.registre.chatoyants").format({"n": nch}) if nch > 0 else "")}))
		lignes.append_array(_detail_registre(ec, str(e.get("registre", "grille")), reg[esp].keys()))
		ec.entrees.append({"kind": "texte", "texte": "\n".join(lignes)})


## Le détail d'une espèce selon son mode de registre (Vivarium — registre et paliers : six modes).
static func _detail_registre(ec: Ecrans, mode: String, cles: Array) -> Array[String]:
	var lignes: Array[String] = []
	match mode:
		"records", "studbook":   # les variétés vues, une par ligne (les records sont déjà en en-tête)
			var vues: Array = cles.duplicate()
			vues.sort()
			for cle in vues:
				lignes.append(ec.tr("ui.registre.variete").format({"v": str(cle).replace("|", " · ")}))
		"sequences":   # les rythmes observés
			var seqs: Array = []
			for cle in cles:
				var parts: PackedStringArray = str(cle).split("|")
				if parts.size() > 1 and not (parts[1] in seqs):
					seqs.append(parts[1])
			seqs.sort()
			for s2 in seqs:
				lignes.append(ec.tr("ui.registre.sequence").format({"s": str(s2).replace(",", " ")}))
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
				lignes.append(ec.tr("ui.registre.grille_ligne").format({"c": t2, "motifs": ", ".join(v2)}))
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
				lignes.append(ec.tr("ui.registre.grille_ligne").format({"c": c, "motifs": ", ".join(ms)}))
	return lignes


static func _construire_entrainer(ec: Ecrans, j: Dictionary) -> void:
	var pnj: Dictionary = ec.main.sim.entites.get(ec.pnj_id, {})
	if pnj.is_empty():
		ec.fermer()
		return
	ec.titre.text = ec.tr("ui.entrainer.titre").format({"nom": ec.tr(pnj.name_key), "or": int(j.or)})
	var ids: Array = j.competences.keys()
	ids.sort()
	var n := 0
	for cid in ids:
		if not ec.main.sim.peut_entrainer(pnj, str(cid)):
			continue
		n += 1
		var cout: int = ec.main.sim.cout_entrainement(j, str(cid))
		ec.liste.add_item(ec.tr("ui.entrainer.competence").format({"nom": ec.tr(ec.main.sim._nom_competence(str(cid))), "niveau": int(j.competences[cid]), "potentiel": int(j.potentiels.get(cid, ec.main.sim.regles.r.progression.potentiel_defaut)), "cout": cout}))
		ec.entrees.append({"kind": "competence_entrainer", "competence": str(cid), "texte": ec.tr("ui.entrainer.competence").format({"nom": ec.tr(ec.main.sim._nom_competence(str(cid))), "niveau": int(j.competences[cid]), "potentiel": int(j.potentiels.get(cid, ec.main.sim.regles.r.progression.potentiel_defaut)), "cout": cout})})
	if n == 0:
		ec.liste.add_item(ec.tr("ui.entrainer.aucune"), null, false)
		ec.entrees.append({"kind": "texte", "texte": ""})


static func _texte_quete(ec: Ecrans, q: Dictionary) -> String:
	return ec.tr(q.text_key).format({"count": int(q.count), "objet": ec.tr(GameData.entree("items", str(q.objet)).name_key) if q.has("objet") else "", "destination": str(q.get("destination", ""))})


## Les capacités du joueur (Structure compétences-modules-slots) : la liste, et la porte vers la composition.
static func _construire_capacites(ec: Ecrans, j: Dictionary) -> void:
	var grille: Dictionary = ec.main.sim.grille_composition(j)   # la grille de l'arme tenue (Six types de modules, 2026-09-03)
	ec.titre.text = ec.tr("ui.ecran.capacites").format({"n": j.get("capacites", []).size(), "cases": (grille.cases as Array).size(), "voie": ec.tr("stat." + str(grille.stat)) if not str(grille.stat).is_empty() else ec.tr("ui.composeur.mains_nues")})
	for k in j.get("capacites", []).size():
		var cap: Dictionary = j.capacites[k]
		var noms: Array[String] = []
		var crans_c: Array = cap.get("crans", [])   # le cran de chaque pièce se lit dans la liste (designer 2026-09-04)
		for k_m in cap.get("modules", []).size():
			var m_k: String = str(cap.modules[k_m])
			var nom_m: String = ec.tr(GameData.catalogues.modules.get(m_k, {}).get("name_key", m_k))
			var c_m: int = int(crans_c[k_m]) if k_m < crans_c.size() else 0
			if c_m > 0:
				nom_m += " +%d" % c_m
			elif c_m < 0:
				nom_m += " −%d" % -c_m
			noms.append(nom_m)
		ec.liste.add_item(ec.tr("ui.capacites.ligne").format({"nom": ec.tr(str(cap.get("name_key", cap.id))), "modules": " → ".join(noms)}))
		ec.entrees.append({"kind": "capacite", "index": k, "texte": _texte_capacite_plan(ec, j, k)})
	ec.liste.add_item(ec.tr("ui.capacites.nouvelle"))
	ec.entrees.append({"kind": "nouvelle_capacite", "texte": ""})


static func _texte_capacite_plan(ec: Ecrans, j: Dictionary, k: int) -> String:
	var plan: Dictionary = ec.main.sim.plan_capacite(j, k)
	if plan.is_empty():
		return ""
	return _apercu_plan(ec, plan)


## Ce qu'un module AJOUTE à la séquence en cours : la différence entre le plan avec lui et le plan sans lui
## (Structure compétences-modules-slots). Calculé par l'assembleur, avec l'arme tenue — jamais écrit à la main.
static func _contribution_module(ec: Ecrans, j: Dictionary, m: String, _deja_dedans: bool) -> String:
	# Entrée ajoute toujours une occurrence : la contribution est celle d'une occurrence DE PLUS (un noyau
	# répété double ses dés, une forme répétée grandit — Six types de modules).
	var avec: Array = ec.sequence_composee.duplicate()
	var sans: Array = ec.sequence_composee.duplicate()
	avec.append(m)
	var pa: Dictionary = ec.main.sim.plan_sequence(j, avec)
	var ps: Dictionary = ec.main.sim.plan_sequence(j, sans) if not sans.is_empty() else {}
	var parts: Array[String] = []
	var d_ticks := int(pa.get("ticks", 0)) - int(ps.get("ticks", 0))
	var d_res := int(pa.get("ressource", 0)) - int(ps.get("ressource", 0))
	var d_des := int(pa.get("des_bonus", 0)) - int(ps.get("des_bonus", 0))
	if d_ticks != 0:
		parts.append("%+d ticks" % d_ticks)
	if d_res != 0 or str(pa.get("monnaie", "")) != str(ps.get("monnaie", "")):
		parts.append("%+d %s" % [d_res, ec.tr("monnaie." + str(pa.get("monnaie", ""))) if not str(pa.get("monnaie", "")).is_empty() else ""])
	if d_des != 0:
		parts.append("%+d %s" % [d_des, ec.tr("bonus.des")])
	if pa.get("des") != null and ps.get("des") == null:
		parts.append(ec.tr("bonus.des") + " " + str(pa.des))
	elif pa.get("des") != null and ps.get("des") != null and str(pa.des) != str(ps.des):
		parts.append("%s → %s" % [str(ps.des), str(pa.des)])   # le noyau répété : 3d6 → 6d6
	if int(pa.get("taille", 0)) != int(ps.get("taille", 0)) and not ps.is_empty():
		parts.append("%s %d → %d" % [ec.tr("ui.composer.taille_courte"), int(ps.get("taille", 0)), int(pa.get("taille", 0))])
	if str(pa.get("geometrie", "")) != str(ps.get("geometrie", "")):
		parts.append(ec.tr("geometrie." + str(pa.get("geometrie", ""))) + " %d–%d" % [int(pa.portee.x), int(pa.portee.y)])
	elif pa.has("portee") and ps.has("portee") and pa.portee != ps.portee:
		parts.append(ec.tr("bonus.portee") + " %d–%d" % [int(pa.portee.x), int(pa.portee.y)])
	if int(pa.get("taille", 1)) != int(ps.get("taille", 1)):
		parts.append("%s %+d" % [ec.tr("bonus.taille"), int(pa.get("taille", 1)) - int(ps.get("taille", 1))])
	if float(pa.get("mult", 1.0)) != float(ps.get("mult", 1.0)):
		parts.append("×%.2f" % (float(pa.get("mult", 1.0)) / maxf(0.01, float(ps.get("mult", 1.0)))))
	var els_a: Dictionary = pa.get("elements", {})
	if els_a != ps.get("elements", {}) and not els_a.is_empty():
		var noms_el: Array[String] = []
		for el in els_a.keys():
			noms_el.append(ec.tr("element." + str(el)))
		parts.append(", ".join(noms_el))
	for ef in pa.get("effets", []):
		if not (ef in ps.get("effets", [])):
			parts.append(ec.tr("effet." + str(ef)))
	for cle in pa.get("drapeaux", {}).keys():
		if not ps.get("drapeaux", {}).has(cle):
			parts.append(ec.tr("drapeau." + str(cle)))
	for c: Dictionary in pa.get("conditions", []):
		var deja := false
		for c2: Dictionary in ps.get("conditions", []):
			deja = deja or str(c2.id) == str(c.id)
		if not deja:
			parts.append(ec.tr("predicat." + str(c.get("predicat", {}).get("type", ""))))
	if parts.is_empty():
		return ec.tr("ui.composer.contribution_nulle")
	return ec.tr("ui.composer.contribution").format({"liste": " · ".join(parts)})


## L'aperçu exhaustif d'un plan (Vocabulaire des modules — six axes : « chaque module affiche ses valeurs
## calculées pour le personnage courant »). Une ligne par axe, et rien d'implicite.
static func _apercu_plan(ec: Ecrans, plan: Dictionary) -> String:
	var effets: Array[String] = []
	for ef in plan.get("effets", []):
		effets.append(ec.tr("effet." + str(ef)))
	var err: Array[String] = []
	for er in plan.get("erreurs", []):
		err.append(str(er))
	var txt := ec.tr("ui.composer.apercu").format({"geometrie": ec.tr("geometrie." + str(plan.get("geometrie", ""))) + " (" + ec.tr("origine." + str(plan.get("origine", "cible"))) + ")", "portee": "%d–%d" % [int(plan.portee.x), int(plan.portee.y)],
		"taille": int(plan.get("taille", 1)), "ticks": int(plan.get("ticks", 0)), "ressource": int(plan.get("ressource", 0)),
		"monnaie": ec.tr("monnaie." + str(plan.monnaie)) if not str(plan.get("monnaie", "")).is_empty() else "—",
		"des": str(plan.get("des", "—")), "effets": ", ".join(effets) if not effets.is_empty() else "—",
		"erreurs": ec.tr("ui.composer.erreurs").format({"liste": " ; ".join(err)}) if not err.is_empty() else ""})
	var fc: Vector2i = ec.main.sim.fourchette_cout(plan)   # « aucun chiffre fixe » : le coût est une fourchette
	txt += "\n" + ec.tr("ui.composer.cout").format({"min": fc.x, "max": fc.y, "monnaie": ec.tr("monnaie." + str(plan.get("monnaie", ""))) if not str(plan.get("monnaie", "")).is_empty() else "—",
		"affinite": "%.2f" % float(plan.get("affinite_arme", 1.0)), "arme": ec.tr(str(plan.get("fonct", {}).get("name_key", "functionality.mains_nues.name")))})
	if ec.main.sim.regles.est_telegraphee(int(plan.get("ticks", 0))):   # au-delà du seuil de télégraphie : visible et interruptible
		txt += "
" + ec.tr("ui.composer.telegraphe").format({"ticks": int(plan.get("ticks", 0)), "seuil": int(ec.main.sim.regles.r.actions.telegraphe_seuil_ticks)})
	if ec.main.sim.plan_par_tuile(plan):   # le prix suit la surface (Six types de modules) : le composeur le dit avant la visée
		var n: int = ec.main.sim.surface_nominale(ec.main.joueur(), plan)
		txt += "\n" + ec.tr("ui.composer.surface").format({"n": n, "min": fc.x * n, "max": fc.y * n, "monnaie": ec.tr("monnaie." + str(plan.get("monnaie", ""))) if not str(plan.get("monnaie", "")).is_empty() else "—"})
	# Les dégâts attendus, avec le détail : fourchette du dé, dés de bonus, multiplicateur.
	if plan.get("des") != null and not str(plan.get("des", "")).is_empty():
		var f := Des.fourchette(plan.des, int(plan.get("des_bonus", 0)))
		var mult := float(plan.get("mult", 1.0))
		txt += "\n" + ec.tr("ui.composer.degats").format({"min": roundi(float(f.x) * mult), "max": roundi(float(f.y) * mult),
			"des": str(plan.des), "bonus": int(plan.get("des_bonus", 0)), "mult": "%.2f" % mult})
	if not str(plan.get("element_dominant", "")).is_empty() or not plan.get("elements", {}).is_empty():
		var els: Array[String] = []
		for el in plan.get("elements", {}).keys():
			els.append("%s %d %%" % [ec.tr("element." + str(el)), roundi(float(plan.elements[el]) * 100.0)])
		if not els.is_empty():
			txt += "\n" + ec.tr("ui.composer.elements").format({"liste": ", ".join(els)})
	# Les conditions : ce qu'elles exigent, ce qu'elles rendent.
	for c: Dictionary in plan.get("conditions", []):
		var bonus: Array[String] = []
		for cle in c.get("bonus", {}).keys():
			bonus.append("%s %s" % [ec.tr("bonus." + str(cle)), str(c.bonus[cle])])
		txt += "\n" + ec.tr("ui.composer.condition").format({"nom": ec.tr(str(c.get("name_key", c.id))),
			"predicat": ec.tr("predicat." + str(c.get("predicat", {}).get("type", ""))), "bonus": ", ".join(bonus) if not bonus.is_empty() else "—"})
	# Les modificateurs actifs (drapeaux) et les liaisons.
	var drap: Array[String] = []
	for cle in plan.get("drapeaux", {}).keys():
		drap.append(ec.tr("drapeau." + str(cle)))
	if not drap.is_empty():
		txt += "\n" + ec.tr("ui.composer.modificateurs").format({"liste": ", ".join(drap)})
	if not plan.get("liaisons", []).is_empty():
		var li: Array[String] = []
		for l: Dictionary in plan.liaisons:
			for cle in l.keys():
				li.append(ec.tr("drapeau." + str(cle)))
		txt += "\n" + ec.tr("ui.composer.liaisons").format({"liste": ", ".join(li)})
	if not plan.get("avertissements", []).is_empty():
		txt += "\n" + ec.tr("ui.composer.avertissements").format({"liste": " ; ".join(PackedStringArray(plan.avertissements))})
	return txt


## Composer : les modules connus, groupés par type ; Entrée les ajoute à la séquence (ou les en retire) ; V valide.
static func _construire_composer(ec: Ecrans, j: Dictionary) -> void:
	var emb: Dictionary = ec.main.sim.emboitement(j, ec.sequence_composee)   # la grille (Six types de modules, 2026-09-03)
	var noms: Array[String] = []
	for m in ec.sequence_composee:
		noms.append(ec.tr(GameData.catalogues.modules.get(str(m), {}).get("name_key", str(m))))
	var fiche_g: Dictionary = GameData.catalogues.get("grilles", {}).get(str(emb.get("grille", "")), {})
	var nom_grille: String = ec.tr(str(fiche_g.name_key)) if fiche_g.has("name_key") else ec.tr("ui.composeur.grille_arme")
	ec.titre.text = ec.tr("ui.ecran.composer").format({"sequence": " → ".join(noms) if not noms.is_empty() else ec.tr("ui.composeur.sequence_vide"), "grille": nom_grille, "n": int(emb.demande), "max": int(emb.capacite)})
	# Le composeur en glisser-déposer (décision du designer, 2026-08-30) remplace la liste : slots, cartes, nom, Wu Xing.
	ec.corps.visible = false
	ec.composeur.visible = true
	ec.composeur.reconstruire(j, ec.sequence_composee.duplicate(), ec.crans_composes.duplicate())
	EcransListe._bouton(ec, ec.tr("ui.composer.valider"), _valider_composition)


static func _valider_composition(ec: Ecrans) -> void:
	var j: Dictionary = ec.main.joueur()
	var seq: Array = ec.composeur.sequence()
	if ec.main.sim.composer_capacite(j, seq, ec.composeur.nom_choisi(), ec.composeur.grilles_des_etapes(), ec.composeur.crans()):
		ec.sequence_composee = []
		ec.crans_composes = []
		ec.composeur.vider_grille()
		ec.composeur.nom.text = ""
		ec.ouvrir("capacites")
	else:
		EcransListe.rafraichir(ec)


## L'écran principal (Écrans d'interface, 2026-08-30) : Nouvelle partie, Continuer, Charger, Options, Quitter.
## L'écran de MORT (Ordre de travail, palier 3 — 2026-09-08). Avant, la défaite était une ligne de journal et
## n'importe quelle touche relevait le joueur sur-le-champ : il ne savait ni où il repartirait, ni ce que ça coûterait.
## L'écran dit les deux et demande un choix. Étant un écran, il met aussi le monde en pause (la pause du même jour).
## Les pertes étant appliquées par `_respawn`, donc AU RELÈVEMENT, l'écran annonce ce que ça VA coûter : c'est un choix
## éclairé, pas un constat.
static func _construire_mort(ec: Ecrans, j: Dictionary) -> void:
	ec.titre.text = ec.tr("ui.ecran.mort")
	var m: Dictionary = ec.main.sim.regles.r.get("mort", {})
	var lignes: Array[String] = []
	# Où l'on se relève — la seule information vraiment décisive. [[Mort et pénalité]] : sans lit activé, on repart du
	# point d'entrée ; avec un lit, mourir en donjon termine l'expédition et ramène au camp.
	lignes.append(ec.tr("ui.mort.au_lit" if j.has("lit") else "ui.mort.a_l_entree"))
	var pc := roundi(float(m.get("perte_or", 0.0)) * 100.0)
	if pc > 0 and int(j.get("or", 0)) > 0:
		lignes.append(ec.tr("ui.mort.or").format({"pc": pc, "or": int(floor(float(j.or) * float(m.get("perte_or", 0.0))))}))
	if not j.get("sac", []).is_empty():
		lignes.append(ec.tr("ui.mort.sac").format({"n": int(j.sac.size()), "jours": int(m.get("peremption_jours", 1))}))
	else:
		lignes.append(ec.tr("ui.mort.sac_vide"))
	var recap := "\n".join(lignes)
	var ids: Array[String] = ["relever"]
	if not ec.main.parties_presentes().is_empty():
		ids.append("charger")
	ids.append("titre")
	for id in ids:
		ec.liste.add_item(ec.tr("ui.mort." + id))
		# Le détail montre TOUJOURS le récapitulatif, quel que soit le choix survolé : c'est l'information qui compte.
		ec.entrees.append({"kind": "mort", "id": id, "texte": recap + "\n\n" + ec.tr("ui.mort.d_" + id)})


static func _construire_titre(ec: Ecrans) -> void:
	ec.titre.text = ec.tr("ui.ecran.titre")
	# Plusieurs parties, UNE sauvegarde par partie (designer 2026-09-02) : « Continuer » reprend la
	# dernière jouée, « Charger » montre les autres avec leur personnage et l'état de leur monde.
	var ids: Array[String] = ["nouvelle"]
	if not ec.main.parties_presentes().is_empty():
		ids.append_array(["continuer", "charger"])
	ids.append_array(["options", "quitter"])
	for id in ids:
		ec.liste.add_item(ec.tr("ui.titre." + id))
		ec.entrees.append({"kind": "titre", "id": id, "texte": ec.tr("ui.titre.d_" + id)})


# ---------------------------------------------------------------- l'écran de création (Écrans d'interface, 2026-08-30)
