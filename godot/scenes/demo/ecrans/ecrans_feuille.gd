class_name EcransFeuille
extends RefCounted
## La feuille de personnage et l'aperçu : surligner un membre, replacer l'aperçu et la liste.
## Bibliothèque STATIQUE des écrans (Modules de la simulation et le C++, 2026-09-06) : l'état et les nœuds vivent dans
## `Ecrans`, reçu en premier paramètre ; ici, seulement la construction et la logique d'un écran. Déplacé depuis
## `ecrans.gd` par `tools/fragmenter.py --cible ecrans`, sans changement de comportement.


## L'ÉCRAN D'ANATOMIE (designer 2026-09-09 : « rajoute un menu pour voir les membres et les organes en détail »,
## puis « je veux une vue du pantin avec zoom sur les membres et organes avec toutes les infos à droite »).
## Trois colonnes, et chacune fait une seule chose : **le corps à gauche** (`AnatomieVisuelle`, le vrai paperdoll
## cadré sur la partie choisie), **la liste au milieu** pour naviguer, **tout le détail à droite**.
## Il ne calcule rien : il LIT le plan de corps et l'état des parties, exactement comme le combat les lit.
## **L'ordre est celui de l'arbre**, membres d'abord puis organes logés dedans — on ne cherche pas un foie dans une
## liste alphabétique, on le cherche dans le torse.
static func _construire_anatomie(ec: Ecrans, j: Dictionary) -> void:
	ec.titre.text = ec.tr("ui.ecran.anatomie").format({"nom": ec.tr(j.name_key)})
	var plan: Dictionary = Etres.plan_corps(j)
	if plan.is_empty():
		ec.liste.add_item(ec.tr("ui.anatomie.sans_plan"))
		ec.entrees.append({"kind": "texte", "texte": ""})
		return
	var parties: Dictionary = plan.parties
	var externes: Array[String] = []
	var file: Array[String] = [str(plan.racine)]
	while not file.is_empty():
		var nom: String = file.pop_front()
		if nom in externes:
			continue
		externes.append(nom)
		for autre: String in parties.keys():
			if str((parties[autre] as Dictionary).get("parent", "")) == nom and not (autre in externes):
				file.append(autre)
	for nom2: String in parties.keys():
		if not bool((parties[nom2] as Dictionary).get("interne", false)) and not (nom2 in externes):
			externes.append(nom2)
	for membre in externes:
		_ligne_partie(ec, j, membre, false)
		for organe: String in parties.keys():
			if bool((parties[organe] as Dictionary).get("interne", false)) and str((parties[organe] as Dictionary).get("contenant", "")) == membre:
				_ligne_partie(ec, j, organe, true)


## Une ligne de la colonne du milieu : le nom, ce qu'il reste, et rien de plus — le détail est à droite. Un organe
## est décalé sous le membre qui le loge : c'est la seule chose que l'indentation dit, et elle suffit à lire un corps.
static func _ligne_partie(ec: Ecrans, j: Dictionary, nom: String, interne: bool) -> void:
	var intacte := Etres.partie_intacte(j, nom)
	var cle := "ui.anatomie.perdue" if not intacte else ("ui.anatomie.organe" if interne else "ui.anatomie.membre")
	ec.liste.add_item(ec.tr(cle).format({
		"nom": ec.tr("partie." + nom), "pv": Etres.sante_partie(j, nom), "pv_max": Etres.sante_partie_max(j, nom)}))
	ec.entrees.append({"kind": "partie", "id": nom, "texte": ""})


## TOUT CE QU'ON SAIT D'UNE PARTIE, pour la colonne de droite. Rien n'est calculé ici non plus : la réserve, la zone
## de coup, le poids qu'elle pèse dans cette zone, ce qu'elle accorde comme emplacement, le sens qu'elle porte et ce
## qu'elle loge sont tous dans le plan. L'écran ne fait que les mettre en français.
static func texte_partie(ec: Ecrans, nom: String) -> String:
	var j: Dictionary = ec.main.joueur()
	var plan: Dictionary = Etres.plan_corps(j)
	var p: Dictionary = plan.get("parties", {}).get(nom, {})
	if p.is_empty():
		return ""
	var l: Array[String] = ["[b]" + ec.tr("partie." + nom) + "[/b]"]
	var intacte := Etres.partie_intacte(j, nom)
	if not intacte:
		l.append(ec.tr("ui.anatomie.d_perdue"))
	else:
		l.append(ec.tr("ui.anatomie.d_reserve").format({"pv": Etres.sante_partie(j, nom), "pv_max": Etres.sante_partie_max(j, nom)}))
	l.append(ec.tr("ui.anatomie.d_nature").format({
		"nature": ec.tr("ui.anatomie.d_organe" if bool(p.get("interne", false)) else "ui.anatomie.d_membre"),
		"vital": ec.tr("ui.anatomie.d_vital") if bool(p.get("vital", false)) else ""}))
	l.append(ec.tr("ui.anatomie.d_zone").format({"zone": ec.tr("zone." + str(p.get("zone", "torse"))), "poids": "%.2f" % float(p.get("poids_coup", 1.0))}))
	var attache := str(p.get("contenant", p.get("parent", "")))
	if not attache.is_empty():
		l.append(ec.tr("ui.anatomie.d_attache").format({"nom": ec.tr("partie." + attache)}))
	if not str(p.get("sens", "")).is_empty():
		l.append(ec.tr("ui.anatomie.d_sens").format({
			"sens": ec.tr("sens." + str(p.sens)),
			"etat": ec.tr("ui.anatomie.sens_ok" if Etres.sens_actif(j, str(p.sens)) else "ui.anatomie.sens_perdu")}))
	var emplacements := Etres.emplacements(j)
	var siens: Array[String] = []
	for slot in p.get("emplacements", []):
		if str(slot) in emplacements:
			siens.append(ec.tr("slot." + str(slot)))
	if not siens.is_empty():
		l.append(ec.tr("ui.anatomie.d_emplacements").format({"liste": ", ".join(siens)}))
	# Ce qu'elle porte et ce qu'elle loge : c'est là qu'on comprend qu'une main tombe avec son bras.
	var portees: Array[String] = []
	var logees: Array[String] = []
	for autre: String in (plan.parties as Dictionary).keys():
		var q: Dictionary = plan.parties[autre]
		if str(q.get("parent", "")) == nom:
			portees.append(ec.tr("partie." + autre))
		if str(q.get("contenant", "")) == nom:
			logees.append(ec.tr("partie." + autre))
	if not portees.is_empty():
		l.append(ec.tr("ui.anatomie.d_porte").format({"liste": ", ".join(portees)}))
	if not logees.is_empty():
		l.append(ec.tr("ui.anatomie.d_loge").format({"liste": ", ".join(logees)}))
	return "\n".join(l)


static func _construire_feuille(ec: Ecrans, j: Dictionary) -> void:
	ec.titre.text = ec.tr("ui.ecran.feuille").format({"nom": ec.tr(j.name_key)})
	var sim = ec.main.sim
	var nd: Dictionary = sim.progression.niveaux_derives(j)
	var l: Array[String] = [ec.tr("ui.niveaux").format({"combat": "%.1f" % nd.combat, "general": "%.1f" % nd.general})]
	l.append(ec.tr("ui.feuille.vitaux").format({"pv": j.sante, "pv_max": j.sante_max, "end": j.vigueur, "end_max": j.vigueur_max, "mana": j.mana, "mana_max": j.mana_max, "sf": int(j.get("sang_froid", 0)), "sf_max": int(j.get("sang_froid_max", 0))}))
	l.append("")
	l.append("[b]" + ec.tr("ui.feuille.stats") + "[/b]")
	for st in ["force", "dexterite", "endurance", "volonte", "perception", "charisme"]:
		l.append(ec.tr("ui.feuille.stat").format({"stat": ec.tr("stat." + st), "valeur": j.corps.stats[st], "potentiel": int(j.potentiels.get(st, 80))}))
	var lt: Array[String] = ["[b]" + ec.tr("ui.feuille.talents") + "[/b]"]
	for tid in sim.talents_de(j):
		var td: Dictionary = GameData.entree("talents", str(tid))
		lt.append(ec.tr("ui.feuille.talent").format({"nom": ec.tr(td.name_key), "desc": ec.tr(td.desc_key)}))
	l.append("")
	l.append_array(lt)
	var lg: Array[String] = ["", "[b]" + ec.tr("ui.feuille.grilles") + "[/b]"]   # la collection de grilles (designer 2026-09-04) se lit ici aussi, pas seulement au composeur
	var active_g: String = str(sim.grille_composition(j).get("grille", ""))
	for gid in j.get("grilles", []):
		var fiche_g: Dictionary = GameData.catalogues.get("grilles", {}).get(str(gid), {})
		lg.append(ec.tr("ui.feuille.grille").format({"nom": ec.tr(str(fiche_g.get("name_key", gid))), "cases": sim.grille_sort.cases_de_grille(str(gid)).size(), "active": ec.tr("ui.feuille.grille_active") if str(gid) == active_g else ""}))
	if j.get("grilles", []).is_empty():   # sans collection (robot, vieille sauvegarde) : la grille de sa voie, comme au composeur
		var g_v: Dictionary = sim.grille_composition(j)
		var fiche_v: Dictionary = GameData.catalogues.get("grilles", {}).get(str(g_v.get("grille", "")), {})
		lg.append(ec.tr("ui.feuille.grille").format({"nom": ec.tr(str(fiche_v.name_key)) if fiche_v.has("name_key") else ec.tr("ui.composeur.grille_arme"), "cases": (g_v.cases as Array).size(), "active": ec.tr("ui.feuille.grille_active")}))
	lg.append(ec.tr("ui.feuille.modules").format({"n": j.get("modules_connus", []).size()}))
	l.append_array(lg)
	ec.liste.add_item(ec.tr("ui.feuille.stats"))
	ec.entrees.append({"kind": "texte", "texte": "\n".join(l)})
	var cles: Array = j.competences.keys()
	cles.sort()
	var par_cat := {"combat": [], "general": []}
	for cle in cles:
		if int(j.competences[cle]) <= 0 and float(j.xp_competences.get(cle, 0.0)) <= 0.0:
			continue
		var cat: String = str(GameData.catalogues.competences.get(cle, {}).get("category", "combat"))
		par_cat[cat if par_cat.has(cat) else "combat"].append(ec.tr("ui.feuille.ligne").format({"competence": ec.tr(sim._nom_competence(cle)), "niveau": int(j.competences[cle]),
			"xp": int(j.xp_competences.get(cle, 0.0)), "suivant": sim.progression.xp_next(int(j.competences[cle])), "potentiel": int(j.potentiels.get(cle, 80))}))
	for cat in ["combat", "general"]:
		ec.liste.add_item(ec.tr("ui.feuille.cat." + cat) + " (%d)" % par_cat[cat].size())
		ec.entrees.append({"kind": "texte", "texte": "[b]" + ec.tr("ui.feuille.cat." + cat) + "[/b]\n" + ("\n".join(par_cat[cat]) if not par_cat[cat].is_empty() else ec.tr("ui.feuille.aucune"))})
	var eq: Array[String] = ["[b]" + ec.tr("ui.feuille.equipement") + "[/b]"]
	for slot in j.equipement.keys():
		eq.append("%s : %s" % [ec.tr("slot." + str(slot)), ec.main.nom_objet(sim.nom_objet(j.equipement[slot]))])
	ec.liste.add_item(ec.tr("ui.feuille.equipement"))
	ec.entrees.append({"kind": "texte", "texte": "\n".join(eq)})


## Le membre saisi dans le pantin : son joint cerclé et son corps souligné, pour qu'on voie ce qu'on tourne.
static func _surligner_membre(ec: Ecrans, pd: Paperdoll) -> void:
	if ec.pose_edition.is_empty() or ec.pose_segment.is_empty():
		return
	var corps: PackedVector2Array = pd.corps_de(ec.pose_segment)
	if corps.size() < 2:
		return
	pd.draw_line(corps[0], corps[1], Color(1.0, 0.85, 0.3, 0.9), 1.2)
	pd.draw_arc(corps[0], 3.0, 0.0, TAU, 16, Color(1.0, 0.85, 0.3, 0.9), 1.0)

## L'aperçu de la création se replace sur la taille de son cadre (designer 2026-09-01, point 67) : plus
## une seule position en pixels, des proportions lues dans `styles.creation`. Rien ne flotte, rien n'est coupé.
static func _replacer_apercu(ec: Ecrans) -> void:
	if ec.cadre_perso == null or ec.apercu_perso == null:
		return
	var st: Dictionary = GameData.config("styles").get("creation", {})
	var cadre: Vector2 = ec.cadre_perso.size
	if cadre.x <= 0.0 or cadre.y <= 0.0:
		return
	var ech := clampf(cadre.y / maxf(1.0, float(st.get("hauteur_ref", 52.0))), float(st.get("echelle_min", 3.0)), float(st.get("echelle_max", 9.0)))
	ec.apercu_perso.scale = Vector2(ech, ech)
	ec.apercu_perso.position = Vector2(cadre.x * float(st.get("personnage_x", 0.28)), cadre.y * float(st.get("personnage_y", 0.82)))
	var cote := cadre.y * float(st.get("visage_cote", 0.46))
	ec.cadre_visage.size = Vector2(cote, cote)
	ec.cadre_visage.custom_minimum_size = Vector2(cote, cote)
	ec.cadre_visage.position = Vector2(cadre.x * float(st.get("visage_x", 0.55)), cadre.y * float(st.get("visage_y", 0.05)))
	var ep := cote * float(st.get("portrait_echelle", 0.065))
	ec.portrait_perso.scale = Vector2(ep, ep)
	ec.portrait_perso.position = Vector2(cote * 0.5, cote * 2.45)   # la tête du rig, recadrée dans le carré
	ec.barres_perso.position = Vector2(0.0, cadre.y * float(st.get("barres_y", 0.88)))
	ec.barres_perso.size = Vector2(cadre.x, cadre.y * 0.12)

## La colonne de liste prend une part de la largeur du panneau (designer 2026-09-01, point 67) : à 340 px
## fixes, l'écran Territoire coupait ses lignes pendant que les deux tiers droits restaient vides.
static func _replacer_liste(ec: Ecrans) -> void:
	if ec.liste == null or ec.panneau == null:
		return
	var st: Dictionary = GameData.config("styles").get("ecrans", {})
	var l := clampf(ec.panneau.size.x * float(st.get("part_liste", 0.30)), float(st.get("liste_min", 340.0)), float(st.get("liste_max", 700.0)))
	ec.liste.custom_minimum_size = Vector2(l, 0)
