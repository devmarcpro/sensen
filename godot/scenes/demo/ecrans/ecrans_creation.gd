class_name EcransCreation
extends RefCounted
## La création de personnage (fiche, apparence, pantin, kit), le monde, les options, charger, le menu, la triche, le contexte, les périmètres, assigner, l'échange.
## Bibliothèque STATIQUE des écrans (Modules de la simulation et le C++, 2026-09-06) : l'état et les nœuds vivent dans
## `Ecrans`, reçu en premier paramètre ; ici, seulement la construction et la logique d'un écran. Déplacé depuis
## `ecrans.gd` par `tools/fragmenter.py --cible ecrans`, sans changement de comportement.


## La fiche telle qu'elle serait créée maintenant (aperçu : stats, potentiels, kit) — sans la valider.
static func _fiche_apercu(ec: Ecrans) -> Dictionary:
	var c: Dictionary = ec.main.creation
	var races: Array = GameData.catalogues.races.keys()
	races.sort()
	var classes: Array = ec.main._classes_visibles()
	var prog: Progression = Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	var f := Etres.creer_personnage("creature.aventurier.name", races[int(c.race) % races.size()], classes[int(c.classe) % classes.size()], c.points, int(c.annee), prog, c.get("tirage", {}))
	return f


## L'apparence de l'aperçu : le bloc de la race, recouvert des loci réglés à la main (points 39 et 41).
static func _apparence_apercu(ec: Ecrans, fiche: Dictionary) -> Dictionary:
	var ap: Dictionary = fiche.get("apparence", {}).duplicate()
	for cle: String in ec.main.creation.get("apparence", {}).keys():
		ap[cle] = ec.main.creation.apparence[cle]
	return ap


## Les lignes réglables de l'apparence : les loci du catalogue, puis les deux palettes.
static func _lignes_apparence(ec: Ecrans, avec_visage: bool = true) -> Array:
	var cfg: Dictionary = GameData.config("apparence")
	var l: Array = []
	for locus in cfg.get("loci", []):
		if not avec_visage and not bool(locus.get("universel", false)):
			continue
		var vals: Array = []
		for v in locus.get("valeurs", []):
			vals.append(str(v))
		l.append({"id": str(locus.id), "valeurs": vals})
	for pal in (["teinte_peau", "teinte_cheveux"] if avec_visage else ["teinte_peau"]):   # sans visage : pas de couleur de cheveux
		var ids: Array = []
		for t in cfg.get("teintes_peau" if pal == "teinte_peau" else "teintes_cheveux", []):
			ids.append(str(t.id))
		l.append({"id": pal, "valeurs": ids})
	return l


static func _points_creation(ec: Ecrans) -> Dictionary:
	var c: Dictionary = ec.main.creation
	var classes: Array = ec.main._classes_visibles()
	var cl: Dictionary = GameData.entree("classes", classes[int(c.classe) % classes.size()])
	var cfg: Dictionary = GameData.config("creation")
	var total := int(cfg.get("points_base", 30)) + int(cl.get("points_creation_bonus", 0))
	var utilises := 0
	for st in ec.main.STATS:
		utilises += int(c.points.get(st, 0))
	return {"total": total, "utilises": utilises, "restants": total - utilises, "max": int(cfg.get("max_par_stat", 10))}


static func _construire_creation(ec: Ecrans) -> void:
	ec.titre.text = ec.tr("ui.ecran.creation")
	var c: Dictionary = ec.main.creation
	var volet := str(Ecrans.VOLETS[int(c.get("volet", 0)) % Ecrans.VOLETS.size()])
	var onglets: Array[String] = []
	for v in Ecrans.VOLETS:
		onglets.append(("[ %s ]" % ec.tr("ui.creation.volet_" + v)) if v == volet else ("  %s  " % ec.tr("ui.creation.volet_" + v)))
	ec.liste.add_item(" ".join(onglets))
	ec.entrees.append({"kind": "creation", "id": "volet"})
	var fiche := _fiche_apercu(ec)
	var cfg: Dictionary = GameData.config("creation")
	var pts := _points_creation(ec)
	var nom: String = str(c.get("nom", ""))
	if volet == "personnage":
		ec.liste.add_item(ec.tr("ui.creation.nom_l").format({"nom": nom if not nom.is_empty() else ec.tr("ui.creation.nom_vide")}))
		ec.entrees.append({"kind": "creation", "id": "nom"})
		ec.liste.add_item(ec.tr("ui.creation.race_l").format({"race": ec.tr(GameData.entree("races", fiche.race).name_key)}))
		ec.entrees.append({"kind": "creation", "id": "race"})
		ec.liste.add_item(ec.tr("ui.creation.classe_l").format({"classe": ec.tr(GameData.entree("classes", fiche.classe).name_key)}))
		ec.entrees.append({"kind": "creation", "id": "classe"})
		ec.liste.add_item(ec.tr("ui.creation.annee_l").format({"annee": int(c.annee), "element": ec.tr("element." + str(fiche.signe.element)), "animal": ec.tr("animal." + str(fiche.signe.animal))}))
		ec.entrees.append({"kind": "creation", "id": "annee"})
		ec.liste.add_item(ec.tr("ui.creation.points_l").format({"restants": pts.restants, "total": pts.total}))
		ec.entrees.append({"kind": "creation", "id": "points"})
		for st in ec.main.STATS:
			ec.liste.add_item(ec.tr("ui.creation.stat_l").format({"stat": ec.tr("stat." + st), "valeur": int(fiche.corps.stats[st]), "points": int(c.points.get(st, 0))})
				+ ec.tr("ui.creation.stat_de").format({"de": int(c.get("tirage", {}).get(st, 0))}))
			ec.entrees.append({"kind": "creation", "id": "stat:" + st})
	var app: Dictionary = _apparence_apercu(ec, fiche)   # apparence : les loci visuels (designer, points 39 et 41)
	if volet == "apparence":
		for ligne in _lignes_apparence(ec, not app.is_empty()):
			ec.liste.add_item(ec.tr("ui.creation.app_l").format({
				"locus": ec.tr("ui.apparence." + str(ligne.id)),
				"valeur": ec.tr("ui.apparence.val." + str(app.get(str(ligne.id), ligne.valeurs[0] if not ligne.valeurs.is_empty() else ""))),
			}))
			ec.entrees.append({"kind": "creation", "id": "app:" + str(ligne.id)})
	var actions_p: Array = GameData.config("poses").get("actions", [])   # articuler ses poses (designer, point 63)
	if volet == "pose" and not actions_p.is_empty():
		var i_p: int = int(c.get("pose_action", 0)) % actions_p.size()
		ec.liste.add_item(ec.tr("ui.creation.pose_l").format({"action": ec.tr(str(actions_p[i_p].name_key))}))
		ec.entrees.append({"kind": "creation", "id": "pose"})
	if volet == "serments":   # le pari du nen : une contrainte tenue toute la partie, un don en échange
		var jures: Array = c.get("serments", [])
		var ids_s: Array = GameData.catalogues.serments.keys()
		ids_s.sort()
		for sid in ids_s:
			var sd: Dictionary = GameData.catalogues.serments[sid]
			ec.liste.add_item(ec.tr("ui.creation.serment_l").format({"jure": "✓" if str(sid) in jures else "·", "nom": ec.tr(str(sd.name_key)), "desc": ec.tr(str(sd.desc_key))}))
			ec.entrees.append({"kind": "creation", "id": "serment:" + str(sid)})
	if volet == "apparence" and not app.is_empty():   # les réglages continus du visage (designer, point 53)
		for cur in GameData.config("apparence").get("curseurs", []):
			var vc: float = float(app.get("curseurs", {}).get(str(cur.id), float(cur.defaut)))
			ec.liste.add_item(ec.tr("ui.creation.curseur_l").format({"nom": ec.tr("ui.apparence." + str(cur.id)), "valeur": "%.2f" % vc}))
			ec.entrees.append({"kind": "creation", "id": "cur:" + str(cur.id)})
	if volet == "personnage":
		ec.liste.add_item(ec.tr("ui.creation.depart_l").format({"lieu": ec.tr("ui.creation.depart_donjon" if int(c.get("depart", 0)) == 1 else "ui.creation.depart_camp")}))
		ec.entrees.append({"kind": "creation", "id": "depart"})
	ec.liste.add_item(ec.tr("ui.creation.commencer"))
	ec.entrees.append({"kind": "creation", "id": "commencer"})
	if not ec.pose_edition.is_empty():   # le bandeau du pantin (point 63)
		var acts_t: Array = GameData.config("poses").get("actions", [])
		var nom_a := ec.pose_edition
		for a_t in acts_t:
			if str(a_t.id) == ec.pose_edition:
				nom_a = ec.tr(str(a_t.name_key))
		ec.titre.text = ec.tr("ui.pose.editer").format({"action": nom_a})
		if not ec.pose_segment.is_empty():
			ec.titre.text += "  ·  " + ec.tr("ui.pose.segment").format({"nom": ec.pose_segment})
	_apercu_personnage(ec, fiche)


## Le pantin (designer 2026-09-01, point 63) : en mode pose, un clic saisit le membre le plus proche
## et le glissement le fait pivoter. Rien n'est calculé ailleurs : on écrit un angle par segment.
static func _pantin_entree(ec: Ecrans, ev: InputEvent) -> void:
	if ec.pose_edition.is_empty() or ec.main.creation.is_empty():
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		# le membre réellement sous le curseur : le paperdoll sait où il a posé chaque segment (point 68)
		var local: Vector2 = (ev.position - ec.apercu_perso.position) / ec.apercu_perso.scale.x
		var touche: String = ec.apercu_perso.segment_sous(local, float(GameData.config("poses").get("marge_saisie", 6.0)))
		if not touche.is_empty():
			ec.pose_segment = touche
			ec._angle_saisie = _angle_souris(ec, ev.position, touche)
			EcransListe.rafraichir(ec)
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and not ec.pose_segment.is_empty():
		# le membre suit la souris : on tourne de l'angle parcouru AUTOUR DE SON JOINT, pas d'un delta de pixels
		var a := _angle_souris(ec, ev.position, ec.pose_segment)
		var d := rad_to_deg(angle_difference(ec._angle_saisie, a))
		ec._angle_saisie = a
		_tourner_membre(ec, d)


## L'angle du curseur vu depuis le joint du segment saisi — le pantin se manipule comme une marionnette.
static func _angle_souris(ec: Ecrans, pos: Vector2, segment: String) -> float:
	var joint: Vector2 = ec.apercu_perso.position + ec.apercu_perso.joint_de(segment) * ec.apercu_perso.scale.x
	return (pos - joint).angle()


## Fait pivoter le membre saisi, dans l'amplitude autorisée par les données.
static func _tourner_membre(ec: Ecrans, delta: float) -> void:
	if ec.pose_segment.is_empty():
		return
	var cfg: Dictionary = GameData.config("poses")
	var poses: Dictionary = ec.main.creation.get("poses", {})
	var pose: Dictionary = poses.get(ec.pose_edition, {})
	var a := float(pose.get(ec.pose_segment, 0.0)) + delta
	pose[ec.pose_segment] = clampf(a, -float(cfg.get("amplitude_max", 170.0)), float(cfg.get("amplitude_max", 170.0)))
	poses[ec.pose_edition] = pose
	ec.main.creation["poses"] = poses
	_apercu_personnage(ec, _fiche_apercu(ec))


## Le personnage en grand : le paperdoll du jeu, avec la teinte choisie et l'équipement de départ de la classe.
static func _apercu_personnage(ec: Ecrans, fiche: Dictionary) -> void:
	var e: Dictionary = fiche.duplicate(true)
	e["apparence"] = _apparence_apercu(ec, fiche)
	var items := {}
	var equip := {}
	for id in fiche.get("equipement", []):
		var d: Dictionary = GameData.entree("items", str(id))
		if d.is_empty():
			continue
		var it: Dictionary = d.duplicate(true)
		it["uid"] = str(id)
		items[str(id)] = it
		equip[str(d.get("equip_slot", "main_principale"))] = str(id)
	e.equipement = equip
	e["orientation"] = Vector2i(1, 1)
	e["poses"] = ec.main.creation.get("poses", {}).duplicate(true)   # le pantin montre la pose qu'on articule
	if not ec.pose_edition.is_empty():
		e["poses"] = {"repos": e.poses.get(ec.pose_edition, {})}
	ec.apercu_perso.configurer(e, GameData.entree("rigs", str(e.skeleton_template)), items, GameData.catalogues.functionalities, GameData.config("palette_materiaux"))
	ec.apercu_perso.queue_redraw()
	ec.cadre_visage.visible = not e.get("apparence", {}).is_empty()   # pas de portrait pour qui n'a pas de visage
	ec.portrait_perso.configurer(e, GameData.entree("rigs", str(e.skeleton_template)), items, GameData.catalogues.functionalities, GameData.config("palette_materiaux"))
	ec.portrait_perso.queue_redraw()
	var regles := Regles.new(GameData.config("combat_rules"))   # les trois jauges du personnage à naître (point 42)
	var stats: Dictionary = fiche.corps.stats
	ec.barres_perso.valeurs = [
		["sante", regles.sante_max(stats)],
		["vigueur", regles.vigueur_max(stats)],
		["mana", regles.mana_max(stats)],
		["sang_froid", regles.sang_froid_max(stats)],
	]
	ec.barres_perso.queue_redraw()


## Le détail de la ligne choisie : ce que change la race, la classe (talent, bonus, compétences, kit), la stat…
static func _detail_creation(ec: Ecrans, id: String) -> String:
	var fiche := _fiche_apercu(ec)
	var race: Dictionary = GameData.entree("races", fiche.race)
	var cl: Dictionary = GameData.entree("classes", fiche.classe)
	var pts := _points_creation(ec)
	var l: Array[String] = []
	match id:
		"nom":
			l.append(ec.tr("ui.creation.d_nom").format({"max": int(GameData.config("creation").get("nom_max", 16))}))
		"race":
			l.append("[b]%s[/b]" % ec.tr(race.name_key))
			l.append(ec.tr("ui.creation.talent_race").format({"talent": ec.main._texte_talent(str(race.get("talent", "")))}))
			l.append(ec.tr("ui.creation.bonus").format({"bonus": _texte_bonus(ec, race.get("bonus_stats", {}))}))
			l.append(ec.tr("ui.creation.xp_mult").format({"mult": "%.2f" % float(race.get("xp_mult", 1.0)), "vie": int(race.get("lifespan", 80))}))
			l.append(ec.tr("ui.creation.d_race"))
		"classe":
			l.append("[b]%s[/b]" % ec.tr(cl.name_key))
			l.append(ec.tr("ui.creation.talent_classe").format({"talent": ec.main._texte_talent(str(cl.get("talent", "")))}))
			l.append(ec.tr("ui.creation.bonus").format({"bonus": _texte_bonus(ec, cl.get("bonus_stats", {}))}))
			var comps: Array[String] = []
			for k in cl.get("competences", {}).keys():
				comps.append("%s %d" % [ec.tr(GameData.catalogues.competences.get(k, {}).get("name_key", "competence.%s.name" % k)), int(cl.competences[k])])
			l.append(ec.tr("ui.creation.competences_l").format({"liste": ", ".join(comps) if not comps.is_empty() else "—"}))
			var pots: Array[String] = []
			for k in cl.get("base_potentials", {}).keys():
				if str(k) != "_defaut":
					pots.append("%s %d" % [ec.tr(GameData.catalogues.competences.get(k, {}).get("name_key", "competence.%s.name" % k)), int(cl.base_potentials[k])])
			l.append(ec.tr("ui.creation.potentiels_l").format({"defaut": int(cl.get("base_potentials", {}).get("_defaut", 80)), "liste": ", ".join(pots) if not pots.is_empty() else "—"}))
			l.append(ec.tr("ui.creation.kit_l").format({"liste": _texte_kit(ec, cl)}))
			l.append(ec.tr("ui.creation.d_classe"))
		"annee":
			l.append(ec.tr("ui.creation.signe").format({"annee": int(ec.main.creation.annee), "element": ec.tr("element." + str(fiche.signe.element)), "animal": ec.tr("animal." + str(fiche.signe.animal))}))
			l.append(ec.tr("ui.creation.d_annee"))
		"points":
			l.append(ec.tr("ui.creation.points").format({"restants": pts.restants, "total": pts.total}))
			l.append(ec.tr("ui.creation.d_points").format({"max": pts.max}))
		"commencer":
			l.append(ec.tr("ui.creation.d_commencer"))
		_:
			if id == "volet":
				l.append(ec.tr("ui.creation.d_volet"))
			elif id.begins_with("cur:"):
				l.append(ec.tr("ui.creation.d_curseur"))
			elif id.begins_with("app:"):   # le détail d'un locus visuel (designer, points 39 et 41)
				l.append(ec.tr("ui.creation.d_apparence"))
			elif id.begins_with("stat:"):
				var st := id.trim_prefix("stat:")
				l.append("[b]%s[/b] : %d" % [ec.tr("stat." + st), int(fiche.corps.stats[st])])
				l.append(ec.tr("ui.creation.points").format({"restants": pts.restants, "total": pts.total}))
				l.append(ec.tr("stat." + st + ".desc"))
	l.append("")
	l.append(ec.tr("ui.creation.aide2"))
	return "\n".join(l)


static func _texte_bonus(ec: Ecrans, bonus: Dictionary) -> String:
	var parts: Array[String] = []
	for k in bonus.keys():
		parts.append("%s %+d" % [ec.tr("stat." + str(k)), int(bonus[k])])
	return ", ".join(parts) if not parts.is_empty() else "—"


## Le kit de départ : l'équipement et le râtelier de la classe, l'établi portatif, le coffre du camp.
static func _texte_kit(ec: Ecrans, cl: Dictionary) -> String:
	var noms: Array[String] = []
	var vus := {}
	for id in cl.get("equipement", []) + cl.get("ratelier", []) + ["station_etabli"] + GameData.config("camp").get("coffre_depart", []):
		if vus.has(str(id)):
			continue
		vus[str(id)] = true
		var d: Dictionary = GameData.entree("items", str(id))
		noms.append(ec.tr(str(d.get("name_key", "item.%s.name" % id))))
	return ", ".join(noms)


## Une ligne de création réagit à ← → / + − / Entrée : cycler, ajuster, ou commencer.
static func _action_creation(ec: Ecrans, id: String, sens: int) -> void:
	var c: Dictionary = ec.main.creation
	var pts := _points_creation(ec)
	match id:
		"race":
			c.race = posmod(int(c.race) + sens, GameData.catalogues.races.size())
		"classe":
			c.classe = posmod(int(c.classe) + sens, ec.main._classes_visibles().size())
		"annee":
			c.annee = int(c.annee) + sens
		_ when id.begins_with("serment:"):   # on jure ou on retire, tant qu'on n'a pas commencé
			var sid_c := id.trim_prefix("serment:")
			var jures_c: Array = c.get("serments", []).duplicate()
			if sid_c in jures_c:
				jures_c.erase(sid_c)
			else:
				jures_c.append(sid_c)
			c["serments"] = jures_c
			EcransListe.rafraichir(ec)
		"pose":   # l'action à mettre en scène ; Entrée ouvre le pantin (designer, point 63)
			var acts: Array = GameData.config("poses").get("actions", [])
			if acts.is_empty():
				return
			if sens == 0:
				ec.pose_edition = str(acts[int(c.get("pose_action", 0)) % acts.size()].id)
				ec.pose_segment = ""
				EcransListe.rafraichir(ec)
				return
			c["pose_action"] = posmod(int(c.get("pose_action", 0)) + sens, acts.size())
		"volet":   # les trois volets de la création (designer, point 66)
			c["volet"] = posmod(int(c.get("volet", 0)) + (sens if sens != 0 else 1), Ecrans.VOLETS.size())
			ec.selection = 0
		"depart":   # Départ : Camp / Donjon (designer, point 34)
			c.depart = posmod(int(c.get("depart", 0)) + sens, 2)
		"commencer":
			ec.main._creer_personnage()
			return
		"nom", "points":
			if sens > 0:   # Entrée sur le nom ou les points : la ligne suivante
				ec.selection = mini(ec.selection + 1, ec.entrees.size() - 1)
		_:
			if id.begins_with("cur:"):   # un réglage continu du visage (designer, point 53)
				var cid := id.trim_prefix("cur:")
				for cur2 in GameData.config("apparence").get("curseurs", []):
					if str(cur2.id) != cid:
						continue
					var regl: Dictionary = c.get("apparence", {})
					var curs: Dictionary = regl.get("curseurs", {})
					var v2: float = float(curs.get(cid, float(cur2.defaut))) + float(cur2.pas) * float(sens)
					curs[cid] = clampf(v2, float(cur2.min), float(cur2.max))
					regl["curseurs"] = curs
					c["apparence"] = regl
			elif id.begins_with("app:"):   # apparence : le locus suivant / précédent (designer, points 39 et 41)
				var lid := id.trim_prefix("app:")
				var courante := ""
				var valeurs: Array = []
				for ligne2 in _lignes_apparence(ec, true):
					if str(ligne2.id) == lid:
						valeurs = ligne2.valeurs
				if valeurs.is_empty():
					return
				courante = str(_apparence_apercu(ec, _fiche_apercu(ec)).get(lid, valeurs[0]))
				var i2 := valeurs.find(courante)
				var suivant := str(valeurs[posmod(maxi(i2, 0) + sens, valeurs.size())])
				var reglages: Dictionary = c.get("apparence", {})
				reglages[lid] = suivant
				c["apparence"] = reglages
			elif id.begins_with("stat:"):
				var st := id.trim_prefix("stat:")
				var actuel := int(c.points.get(st, 0))
				if sens > 0 and pts.restants > 0 and actuel < pts.max:
					c.points[st] = actuel + 1
				elif sens < 0 and actuel > 0:
					c.points[st] = actuel - 1
	EcransListe.rafraichir(ec)


static func _touche_creation(ec: Ecrans, ev: InputEventKey) -> bool:
	if ec.entrees.is_empty() or ec.selection >= ec.entrees.size():
		return false
	var en: Dictionary = ec.entrees[ec.selection]
	var id := str(en.get("id", ""))
	match ev.keycode:
		KEY_LEFT, KEY_MINUS, KEY_KP_SUBTRACT:
			_action_creation(ec, id, -1)
			return true
		KEY_RIGHT, KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
			_action_creation(ec, id, 1)
			return true
		KEY_BACKSPACE:
			if id == "nom":
				ec.main.creation.nom = str(ec.main.creation.nom).left(maxi(0, str(ec.main.creation.nom).length() - 1))
				EcransListe.rafraichir(ec)
				return true
		KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
			return false
	if id == "nom" and ev.unicode >= 32 and ev.unicode != 127:
		var nom := str(ec.main.creation.nom)
		if nom.length() < int(GameData.config("creation").get("nom_max", 16)):
			ec.main.creation.nom = nom + char(ev.unicode)
			EcransListe.rafraichir(ec)
		return true
	return false


## L'écran Monde : la graine (aléatoire, re-tirable — aucun chiffre fixe), puis Commencer → la carte du départ.
## Change un réglage de génération d'un pas, dans ses bornes (designer 2026-08-31, point 49).
static func _regler_monde(ec: Ecrans, id: String, sens: int) -> void:
	for opt in GameData.config("planete").get("generation_options", []):
		if str(opt.id) != id:
			continue
		var v: float = ec.main.option_monde(opt) + float(opt.pas) * float(sens if sens != 0 else 1)
		ec.main.monde_options[id] = clampf(v, float(opt.min), float(opt.max))
		return


static func _construire_monde(ec: Ecrans) -> void:
	ec.titre.text = ec.tr("ui.ecran.monde")
	ec.liste.add_item(ec.tr("ui.monde.graine").format({"graine": int(ec.main.graine_monde)}))
	ec.entrees.append({"kind": "monde", "id": "graine", "texte": ec.tr("ui.monde.d_graine")})
	for opt in GameData.config("planete").get("generation_options", []):   # les réglages du monde (designer, point 49)
		var v: float = ec.main.option_monde(opt)
		var texte := ("%.2f" % v) if float(opt.pas) < 1.0 else str(int(v))
		ec.liste.add_item(ec.tr("ui.monde.option").format({"nom": ec.tr("ui.monde.opt." + str(opt.id)), "valeur": texte}))
		ec.entrees.append({"kind": "monde", "id": "opt:" + str(opt.id), "texte": ec.tr("ui.monde.d_opt." + str(opt.id))})
	ec.apercu_monde.rafraichir()   # l'aperçu suit les réglages (designer, point 49)
	ec.liste.add_item(ec.tr("ui.monde.commencer"))
	ec.entrees.append({"kind": "monde", "id": "commencer", "texte": ec.tr("ui.monde.d_commencer")})
	ec.liste.add_item(ec.tr("ui.monde.retour"))
	ec.entrees.append({"kind": "monde", "id": "retour", "texte": ""})


## Les options : la langue (à chaud), le plein écran.
static func _construire_options(ec: Ecrans) -> void:
	ec.titre.text = ec.tr("ui.ecran.options")
	ec.liste.add_item(ec.tr("ui.options.langue").format({"langue": TranslationServer.get_locale().substr(0, 2)}))
	ec.entrees.append({"kind": "options", "id": "langue", "texte": ec.tr("ui.options.d_langue")})
	var plein: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	ec.liste.add_item(ec.tr("ui.options.plein_ecran").format({"etat": ec.tr("ui.triche.oui" if plein else "ui.triche.non")}))
	ec.entrees.append({"kind": "options", "id": "plein_ecran", "texte": ""})
	ec.liste.add_item(ec.tr("ui.options.retour"))
	ec.entrees.append({"kind": "options", "id": "retour", "texte": ""})


## Charger : une ligne par partie (designer 2026-09-02 — plusieurs parties, une sauvegarde chacune).
## Chaque ligne dit qui on y jouait et où on en était ; le panneau de droite ajoute le portrait et
## l'état du monde. Tout vient du `resume` écrit à la sauvegarde : aucun monde n'est chargé pour cela.
static func _construire_charger(ec: Ecrans) -> void:
	ec.titre.text = ec.tr("ui.ecran.charger")
	ec.parties_listees = ec.main.parties_presentes()
	if ec.parties_listees.is_empty():
		ec.liste.add_item(ec.tr("ui.charger.aucune"))
		ec.entrees.append({"kind": "charger_slot", "id": "", "texte": ""})
		return
	for pa in ec.parties_listees:
		var r: Dictionary = pa.resume
		if r.is_empty():   # une partie d'avant le résumé : on la liste quand même, sous son seul nom de dossier
			ec.liste.add_item(ec.tr("ui.charger.ligne_muette").format({"slot": str(pa.slot)}))
			ec.entrees.append({"kind": "charger_slot", "id": str(pa.slot), "texte": _detail_partie(ec, pa)})
			continue
		ec.liste.add_item(ec.tr("ui.charger.ligne").format({
			"nom": str(r.get("nom", pa.slot)), "niveau": int(r.get("niveau", 0)),
			"classe": _nom_de(ec, "classes", str(r.get("classe", ""))),
			"jour": int(r.get("jour", 0))}))
		ec.entrees.append({"kind": "charger_slot", "id": str(pa.slot), "texte": _detail_partie(ec, pa)})


## Le nom lisible d'une entrée de catalogue, ou son identifiant si le catalogue ne la connaît plus
## (une partie peut avoir été jouée avec une race ou une classe depuis renommée).
static func _nom_de(ec: Ecrans, catalogue: String, id: String) -> String:
	if id.is_empty():
		return "\u2014"
	var e: Dictionary = GameData.catalogues.get(catalogue, {}).get(id, {})
	return ec.tr(str(e.get("name_key", id))) if not e.is_empty() else id


## Toutes les stats du monde d'une partie, pour le panneau de droite (demande du designer).
static func _detail_partie(ec: Ecrans, pa: Dictionary) -> String:
	var r: Dictionary = pa.resume
	if r.is_empty():
		return ec.tr("ui.charger.illisible").format({"slot": str(pa.slot)})
	var biome_id := str(r.get("biome", ""))
	var ou := ec.tr("ui.charger.en_donjon").format({"etage": int(r.get("etage", 0))}) if str(r.get("lieu", "")) == "donjon" else ec.tr("ui.charger.en_surface")
	var l: Array[String] = [
		ec.tr("ui.charger.perso").format({"nom": str(r.get("nom", "\u2014")), "race": _nom_de(ec, "races", str(r.get("race", ""))), "classe": _nom_de(ec, "classes", str(r.get("classe", ""))), "niveau": int(r.get("niveau", 0))}),
		ec.tr("ui.charger.corps").format({"pv": int(r.get("sante", 0)), "pv_max": int(r.get("sante_max", 0)), "or": int(r.get("or", 0)), "sac": int(r.get("sac", 0))}),
		"",
		ec.tr("ui.charger.temps").format({"jour": int(r.get("jour", 0)), "heure": int(r.get("heure", 0)), "saison": ec.tr("saison." + str(r.get("saison", "printemps")))}),
		ec.tr("ui.charger.ou").format({"ou": ou, "biome": _nom_de(ec, "biomes", biome_id)}),
		ec.tr("ui.charger.monde").format({"graine": int(r.get("graine_monde", -1)) if int(r.get("graine_monde", -1)) >= 0 else int(GameData.config("planete").graine), "vues": int(r.get("cellules_vues", 0)), "claims": int(r.get("claims", 0)), "villages": int(r.get("villages_connus", 0))}),
		ec.tr("ui.charger.corruption").format({"n": int(r.get("corruption_camp", 0))}),
		ec.tr("ui.charger.ecrit_le").format({"date": str(r.get("ecrit_le", "\u2014")), "slot": str(pa.slot)}),
	]
	return "\n".join(l)


## Le portrait de la partie pointée : l'être du joueur est dans sa sauvegarde et le paperdoll sait le
## dessiner tel quel — avec son équipement, puisque les instances d'objets sont sauvegardées à côté.
static func _portrait_partie(ec: Ecrans, slot: String) -> void:
	var pj: Variant = Sauvegarde.lire(slot, "players/joueur.json")
	if not (pj is Dictionary) or not (pj as Dictionary).has("etre"):
		ec.cadre_perso.visible = false
		return
	var e: Dictionary = (pj as Dictionary).etre
	var items: Dictionary = {}
	var inst: Variant = Sauvegarde.lire(slot, "items.json")
	if inst is Dictionary:
		items = inst
	var rig: Dictionary = GameData.entree("rigs", str(e.get("skeleton_template", "humanoide")))
	ec.cadre_perso.visible = true
	ec.apercu_perso.configurer(e, rig, items, GameData.catalogues.functionalities, GameData.config("palette_materiaux"))
	ec.apercu_perso.queue_redraw()
	ec.cadre_visage.visible = not (e.get("apparence", {}) as Dictionary).is_empty()
	ec.portrait_perso.configurer(e, rig, items, GameData.catalogues.functionalities, GameData.config("palette_materiaux"))
	ec.portrait_perso.queue_redraw()
	ec.barres_perso.valeurs = [
		["sante", int(e.get("sante_max", 0))],
		["vigueur", int(e.get("vigueur_max", 0))],
		["mana", int(e.get("mana_max", 0))],
	]
	ec.barres_perso.queue_redraw()


## La production hebdomadaire d'un résident, en mots (le détail affichait le dictionnaire brut — grande base, 2026-09-04).
static func _texte_production(ec: Ecrans, pr: Dictionary) -> String:
	if pr.is_empty():
		return ec.tr("ui.gestion.prod_rien")
	if bool(pr.get("sans_stockage", false)):
		return ec.tr("ui.gestion.sans_stockage")
	if pr.has("or"):
		return ec.tr("ui.gestion.prod_or").format({"n": int(pr.or)})
	var base := str(pr.get("base", ""))
	var fiche: Dictionary = GameData.catalogues.materials.get(base, GameData.catalogues.items.get(base, {}))
	var nom := ec.tr(str(fiche.get("name_key", base)))
	var forme := str(pr.get("forme", ""))
	if not forme.is_empty():   # « chêne (planche) » : la clé de forme est un gabarit, comme pour les objets
		var cle_f := "forme.%s" % forme   # la clé d'une forme est un gabarit « {materiau} (planche) », sans suffixe
		var gabarit := ec.tr(cle_f)
		nom = gabarit.format({"materiau": nom}) if gabarit != cle_f else nom + " " + forme
	var txt := ec.tr("ui.gestion.prod_matiere").format({"nom": nom, "n": int(pr.get("n", 0))})
	if pr.has("stockage") and ec.main.sim.perimetres().has(str(pr.stockage)):
		var cs: Vector2i = ec.main.sim.perimetres()[str(pr.stockage)].cellule
		txt += " · " + ec.tr("ui.gestion.stockage_vers").format({"cellule": "(%d,%d)" % [cs.x, cs.y]})
	return txt


## Le menu (Tab) : les écrans et les actions générales (Écrans d'interface, contrôles).
static func _construire_menu(ec: Ecrans, _j: Dictionary) -> void:
	ec.titre.text = ec.tr("ui.ecran.menu")
	var ids: Array = ["inventaire", "atelier", "feuille", "capacites", "carte", "gestion", "perimetre", "registre", "sauvegarder", "volet", "minimap_zoom", "minimap_masquer", "titre", "arene", "banc_objets", "recharger", "fermer"]
	for id in ids:
		if id in ["carte", "gestion", "perimetre"] and ec.main.sim.lieu != "camp":
			continue
		ec.liste.add_item(ec.tr("ui.menu." + str(id)))
		ec.entrees.append({"kind": "menu", "id": str(id), "texte": ""})


static func _construire_triche(ec: Ecrans, _j: Dictionary) -> void:
	ec.titre.text = ec.tr("ui.ecran.triche").format({"invincible": ec.tr("ui.triche.oui" if ec.main.sim.invincible else "ui.triche.non")})
	for id in Ecrans.TRICHE_ACTIONS:
		ec.liste.add_item(ec.tr("ui.triche." + id))
		ec.entrees.append({"kind": "triche", "id": id, "texte": ec.tr("ui.triche." + id)})
	for id in Ecrans.TRICHE_CATALOGUES:
		ec.liste.add_item(ec.tr("ui.triche." + id) + " …")
		ec.entrees.append({"kind": "triche_catalogue", "id": id, "texte": ec.tr("ui.triche." + id)})


## Les ids d'un catalogue, triés — la liste que le menu de triche parcourt.
static func _ids_triche(ec: Ecrans, categorie: String) -> Array:
	var ids: Array = []
	match categorie:
		"objet": ids = GameData.catalogues.items.keys()
		"materiau": ids = GameData.catalogues.materials.keys()
		"creature": ids = GameData.catalogues.creatures.keys()
		"meteo": ids = GameData.catalogues.weather_states.keys()
		"statut": ids = GameData.catalogues.status_effects.keys()
		"race": ids = GameData.catalogues.races.keys()
	ids.sort()
	return ids


static func _construire_triche_liste(ec: Ecrans, _j: Dictionary) -> void:
	ec.titre.text = ec.tr("ui.ecran.triche_liste").format({"quoi": ec.tr("ui.triche." + ec.triche_categorie)})
	for id in _ids_triche(ec, ec.triche_categorie):
		var nom := str(id)
		var fiche: Dictionary = GameData.catalogues[Ecrans._CAT_TRICHE[ec.triche_categorie]].get(id, {})
		if fiche.has("name_key"):
			nom = "%s  [color=#777]%s[/color]" % [ec.tr(str(fiche.name_key)), id]
		ec.liste.add_item(nom.replace("[color=#777]", "(").replace("[/color]", ")"))
		ec.entrees.append({"kind": "triche_item", "id": str(id), "texte": nom})


## Le clic droit : toutes les options de la tuile visée.
static func _construire_contexte(ec: Ecrans, _j: Dictionary) -> void:
	ec.titre.text = ec.tr("ui.ecran.contexte").format({"x": ec.contexte_tuile.x, "y": ec.contexte_tuile.y})
	if ec.contexte_options.is_empty():
		ec.liste.add_item(ec.tr("ui.contexte.aucune"), null, false)
		ec.entrees.append({"kind": "texte", "texte": ""})
		return
	for opt in ec.contexte_options:
		ec.liste.add_item(ec.tr("option." + str(opt.id)))
		ec.entrees.append({"kind": "contexte", "opt": opt, "texte": ""})


## Le type d'un périmètre à dessiner (Gestion de base, 2026-09-04) : on choisit, l'écran se ferme, deux clics dessinent.
static func _construire_perimetre(ec: Ecrans, _j: Dictionary) -> void:
	ec.titre.text = ec.tr("ui.perimetre.titre")
	var pcfg: Dictionary = ec.main.sim.regles.r.royaume.get("perimetres", {})
	for t in pcfg.get("ordre", []):
		ec.liste.add_item(ec.tr("perimetre.%s.name" % str(t)))
		ec.entrees.append({"kind": "type_perimetre", "type": str(t), "texte": ec.tr("ui.perimetre.aide")})


static func _construire_assigner(ec: Ecrans, j: Dictionary) -> void:
	var pnj: Dictionary = ec.main.sim.entites.get(ec.pnj_id, {})
	if pnj.is_empty():
		ec.fermer()
		return
	ec.titre.text = ec.tr("ui.assigner.titre").format({"nom": ec.tr(pnj.name_key)})
	var ids: Array = GameData.catalogues.functions.keys()
	ids.sort()
	for fid in ids:
		var f: Dictionary = GameData.catalogues.functions[fid]
		if fid in ["aventurier", "dirigeant", "oisif"]:
			continue
		var prod = f.get("produit")
		var ptxt: String = ec.tr("ui.assigner.rien")   # ce que la fonction produit : de l'or par unité, ou une matière nommée (traduit — vu « or/unité » en anglais, 2026-09-04)
		if prod != null and prod.has("or"):
			ptxt = ec.tr("ui.assigner.or_unite").format({"n": str(prod.or)})
		elif prod != null:
			var base_p := str(prod.get("item", prod.get("materiau", "")))
			var fiche_p: Dictionary = GameData.catalogues.materials.get(base_p, GameData.catalogues.items.get(base_p, {}))
			ptxt = ec.tr(str(fiche_p.get("name_key", base_p)))
		ec.liste.add_item(ec.tr(f.name_key))
		ec.entrees.append({"kind": "fonction", "fonction": fid, "texte": ec.tr("ui.assigner.fonction").format({"fonction": ec.tr(f.name_key), "produit": ptxt, "rendement": str(f.get("rendement_base", 0))})})
	for pid in ec.main.sim.perimetres().keys():   # les périmètres de récolte du territoire (Population et exploitation, 2026-09-04)
		var per: Dictionary = ec.main.sim.perimetres()[pid]
		var tp: Dictionary = ec.main.sim.regles.r.royaume.perimetres.types.get(str(per.type), {})
		var f_p: Dictionary = GameData.catalogues.functions.get(str(tp.get("fonction", "")), {})
		var txt_p: String = ec.tr("ui.assigner.perimetre").format({"fonction": ec.tr(f_p.get("name_key", "ui.assigner.rien")), "type": ec.tr("perimetre.%s.name" % str(per.type)), "x": per.cellule.x, "y": per.cellule.y, "richesse": int(per.richesse)})
		ec.liste.add_item(txt_p)
		ec.entrees.append({"kind": "fonction", "fonction": str(tp.get("fonction", "")), "perimetre": str(pid), "texte": txt_p})


## L'échange d'équipement avec un compagnon (Compagnons) : ton sac à donner, son équipement et son sac à reprendre.
static func _construire_echange(ec: Ecrans, j: Dictionary) -> void:
	var pnj: Dictionary = ec.main.sim.entites.get(ec.pnj_id, {})
	if pnj.is_empty():
		ec.fermer()
		return
	ec.titre.text = ec.tr("ui.echange.titre").format({"nom": ec.tr(pnj.name_key)})
	ec.liste.add_item(ec.tr("ui.echange.donner"), null, false)
	ec.entrees.append({"kind": "texte", "texte": ""})
	for uid in j.sac:
		ec.liste.add_item(EcransInventaire._nom_court(ec, uid))
		ec.entrees.append({"kind": "donner", "uid": uid})
	ec.liste.add_item(ec.tr("ui.echange.reprendre").format({"nom": ec.tr(pnj.name_key)}), null, false)
	ec.entrees.append({"kind": "texte", "texte": ""})
	for slot in Array(GameData.config("combat_rules").equipement.slots):
		var uid: String = str(pnj.equipement.get(slot, ""))
		if uid.is_empty():
			continue
		ec.liste.add_item("%s : %s" % [ec.tr("slot." + slot), ec.main.nom_objet(ec.main.sim.nom_objet(uid))])
		ec.liste.set_item_custom_fg_color(ec.liste.item_count - 1, Color(0.85, 0.8, 0.55))
		ec.entrees.append({"kind": "reprendre", "uid": uid})
	for uid in pnj.sac:
		ec.liste.add_item(EcransInventaire._nom_court(ec, uid))
		ec.entrees.append({"kind": "reprendre", "uid": uid})


# ---------------------------------------------------------------- inventaire
