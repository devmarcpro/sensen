class_name Etres
extends RefCounted
## Instanciation d'un être depuis sa fiche (Blocs de l'être, Schéma créature).
## Le joueur n'est PAS un type à part (Contraintes permanentes, règle 5) : même dictionnaire
## pour tout être, `controle` est un attribut. Les systèmes testent la présence d'un bloc ou
## d'un tag, jamais l'espèce.


## Crée l'instance sérialisable d'un être. `def` = entrée de data/creatures.
static func instancier(id: String, def: Dictionary, pos: Vector2i, controle: String, regles: Regles, items: Dictionary) -> Dictionary:
	var stats: Dictionary = def.corps.stats
	var equip := {}
	for item_id: String in def.get("equipement", []):
		var item: Dictionary = items.get(item_id, {})
		if item.is_empty():
			push_error("Etres : objet « %s » inconnu pour %s" % [item_id, id])
			continue
		equip[item.equip_slot] = item_id
	return {
		"id": id,
		"def": def.id,
		"name_key": def.name_key,
		"race": def.race,
		"controle": controle,                      # "joueur" | "ia" — un attribut, pas un type
		"camp": "joueur" if controle == "joueur" or def.ai_profile == "compagnon" else "hostile",
		"pos": pos,
		"ancre": pos,                              # point d'ancrage (Décision — Fuite et désengagement)
		"orientation": Vector2i(0, 1),
		"compteur": 0,
		"horloge": "monde",
		"corps": {"stats": stats.duplicate(), "silhouette": def.corps.silhouette},
		"sante": regles.sante_max(stats),
		"sante_max": regles.sante_max(stats),
		"endurance": regles.vigueur_max(stats),
		"endurance_max": regles.vigueur_max(stats),
		"mana": regles.mana_max(stats),
		"mana_max": regles.mana_max(stats),
		"sang_froid": regles.sang_froid_max(stats),
		"sang_froid_max": regles.sang_froid_max(stats),
		"tick_endurance": 0,                       # dernier tick où la régénération a été appliquée
		"equipement": equip,
		"ratelier": def.get("ratelier", []).duplicate(),
		"actions": def.get("actions", []).duplicate(),
		"capacites": def.get("capacites", []).duplicate(true),   # séquences de modules assemblées
		"competences": def.get("competences", {}).duplicate(),     # niveaux (Progression par l'usage) — modificateur de race au départ
		"stats_eff": stats.duplicate(),                            # (base + Σ add) × Π mult — Résolveur de modificateurs
		"xp_competences": {},                                       # XP accumulée par compétence et par stat (Progression par l'usage)
		"potentiels": def.get("potentiels", {}).duplicate(),       # potentiel courant par clé (Potentiel), défaut 80
		"potentiels_base": def.get("potentiels_base", {}).duplicate(),
		"xp_mult": float(def.get("xp_mult", 1.0)),
		"signe": def.get("signe", {}),
		"classe": def.get("classe", ""),
		"competences_eff": def.get("competences", {}).duplicate(),
		"sac": [],                                                  # uids des objets portés non équipés
		"faim": 100, "faim_tick": 0,                                # la jauge de faim (Faim), tickée par la simulation
		"tags_acquis": [],                                          # grant_tag des effets passifs
		"tags_acquis_race": def.get("tags_acquis_race", []).duplicate(),   # ceux du talent de race
		"apparence": def.get("apparence", {}).duplicate(),                 # loci visuels (Apparence — données et équipement)
		"poses": def.get("poses", {}).duplicate(true),                     # poses articulées par le joueur (point 63)
		"rare": false,                                              # variante rare (Monstres rares)
		"degats_element": {},                                       # bonus plats des gemmes
		"affinites": {},                                            # tailles en affinité de l'arme tenue
		"modules_connus": [],                                       # appris par la lecture (Grimoires et manuels)
		"epithete": "",
		"ai_profile": def.ai_profile,
		"chain_gauge": def.get("chain_gauge", false),   # porteurs de jauge : joueur, élites, boss
		"elements": def.get("elements"),
		"teinte": def.get("teinte", [0.8, 0.8, 0.8]),
		"tags": def.get("tags", []).duplicate(),
		"vivant": true,
		"garde": false,
		"action_en_cours": {},                     # télégraphe : action engagée, résolue à l'échéance
		"statuts": [],                             # [{id, fin, prochain, source}] — Statuts
		"anti_stunlock_jusqua": -1,               # aucun contrôle dur avant ce tick (Statuts de contrôle)
		"munitions": _munitions(equip, items),
		"munitions_tirees": 0,
		"declencheurs_armes": [],                 # charges armées sur le porteur : [{evenement, plan}] — une fois chacune
		"emplois": {},                             # nombre d'emplois par capacité (Cadence)
		"derniere_cible_pos": pos,
		"contact": false,                          # a-t-il déjà touché ou été touché dans ce combat ? (Ouverture)
		"xp": {"element": {}, "competence": {}, "type": {}, "construction": {}},   # XP de combat, trois pistes + défense
		"cible": "",
		"tick_derniere_vue": -1,
		"pos_connue": pos,
		"tick_decision": -1,
		"fuite": false,
	}


## Crée la fiche d'un personnage (Création de personnage) : 6 stats à base 5 + 30 points répartis
## (+ bonus de classe), bonus de race et de classe, kit, compétences de départ, potentiels de base
## par race + classe + signe. Le résultat est une fiche comme celles de data/creatures/.
static func creer_personnage(nom_key: String, race_id: String, classe_id: String, repartition: Dictionary, annee: int, prog: Progression, tirage: Dictionary = {}) -> Dictionary:
	var race: Dictionary = GameData.entree("races", race_id)
	var classe: Dictionary = GameData.entree("classes", classe_id)
	var stats := {}
	for st in ["force", "dexterite", "endurance", "volonte", "perception", "charisme"]:
		# La base d'une stat est tirée aux dés à la création (designer 2026-08-31, point 48) ;
		# sans tirage (PNJ, tests), la valeur de repli du catalogue s'applique.
		var base_st := int(tirage.get(st, int(GameData.config("creation").get("stat_base_defaut", 5))))
		stats[st] = base_st + int(repartition.get(st, 0)) + int(race.get("bonus_stats", {}).get(st, 0)) + int(classe.get("bonus_stats", {}).get(st, 0))
	var signe := prog.signe(annee)
	var pot_base := {}
	for cle: String in prog.competences.keys():
		pot_base[cle] = prog.potentiel_base(cle, race, classe, signe)
	for st in stats.keys():
		pot_base[st] = prog.potentiel_base(st, race, classe, signe)
	return {
		"id": "joueur", "name_key": nom_key, "race": race_id, "classe": classe_id, "fonction": "aventurier", "skeleton_template": "humanoide",
		"corps": {"stats": stats, "silhouette": "humanoide"}, "esprit": null, "ai_profile": "compagnon",
		"actions": [], "equipement": classe.get("equipement", []).duplicate(), "ratelier": classe.get("ratelier", []).duplicate(),
		"sac": ["station_etabli"],   # chaque personnage part avec un établi portatif (Stations de transformation, décidé le 2026-08-28)
		"competences": classe.get("competences", {}).duplicate(), "chain_gauge": true, "elements": null,
		"rare_chance": 0.0, "teinte": [0.28, 0.62, 0.92], "tags": ["humanoide", "joueur"] + race.get("tags", []),
		"potentiels": pot_base.duplicate(), "potentiels_base": pot_base, "xp_mult": float(race.get("xp_mult", 1.0)), "signe": signe,
		"tags_acquis_race": race.get("tags_acquis", []).duplicate(),
		"apparence": race.get("apparence", {}).duplicate(),   # loci visuels : la race donne le défaut, la création les règle
		"poses": {},                                          # poses articulées à la création (point 63)
		"capacites": classe.get("capacites", []).duplicate(true),   # les sorts de départ sont ceux de la classe (designer, point 47)
		"hotbar": classe.get("hotbar", []).duplicate(true),         # et son loadout de hotbar
		"modules_connus": _modules_de_classe(classe),               # et ses seuls modules : le reste s'apprend dans les livres
	}


## Les modules que la classe apporte : ceux de ses capacités de départ, sans doublon.
static func _modules_de_classe(classe: Dictionary) -> Array:
	var res: Array = []
	for cap in classe.get("capacites", []):
		for m in cap.get("modules", []):
			if not (str(m) in res):
				res.append(str(m))
	return res


## Recalcule ce que l'équipement change (Résolveur de modificateurs : (base + Σ add) × Π mult) :
## stats et compétences effectives (les affixes passifs des bijoux et armures), endurance max,
## capacité de jauge, tags acquis. À appeler à l'instanciation et à chaque changement d'équipement.
static func recalculer(e: Dictionary, items: Dictionary, affixes_defs: Dictionary, regles: Regles) -> void:
	var stats: Dictionary = e.corps.stats.duplicate()
	# Les statuts qui touchent une stat (potions : modifiers cible "stat:<nom>", add).
	var defs_statuts: Dictionary = GameData.catalogues.get("status_effects", {})
	var tags: Array = e.get("tags_acquis_race", []).duplicate()
	for s: Dictionary in e.get("statuts", []):
		for mod: Dictionary in defs_statuts.get(s.id, {}).get("modifiers", []):
			if str(mod.cible).begins_with("stat:") and mod.has("add"):
				var nom_stat := str(mod.cible).trim_prefix("stat:")
				stats[nom_stat] = int(stats.get(nom_stat, 0)) + roundi(float(mod.add) * float(s.get("puissance", 1.0)))
			elif str(mod.cible) == "tag" and mod.has("grant"):   # un statut accorde un tag (Potions : vision nocturne, antipoison)
				tags.append(str(mod.grant))
	# Serments tenus (point Nen, designer 2026-09-01) : leurs bonus de stat s'ajoutent tant qu'ils tiennent.
	for sid in e.get("serments", []):
		if str(sid) in e.get("serments_rompus", []):
			continue
		var sd: Dictionary = GameData.catalogues.get("serments", {}).get(str(sid), {})
		for nom_st: String in (sd.get("bonus", {}).get("stat", {}) as Dictionary).keys():
			stats[nom_st] = int(stats.get(nom_st, 0)) + int(sd.bonus.stat[nom_st])
	var comp: Dictionary = e.competences.duplicate()
	var segments_bonus := 0
	var endurance_bonus := 0
	var sante_bonus := 0
	var mana_bonus := 0
	var par_competence := {}   # plafond +15 par compétence toutes gemmes confondues
	var plafond := int(GameData.config("loot_rules").gemmes.plafond_par_competence)
	e.degats_element = {}
	e.affinites = {}
	e.mecaniques = {}   # affixes passif_mecanique : mécanique → paramètres (Effets d'équipement types)
	# CHAQUE CONSTRUCTION DONNE UNE STAT, par piece portee (designer 2026-09-03). La regle qui tient
	# l'ensemble : le bonus va CONTRE LE GRAIN — plus une construction protege, moins elle donne. Sans
	# cela la plaque cumulerait la meilleure armure ET le meilleur bonus, elle serait strictement
	# superieure, et le choix d'armure n'existerait plus. C'est aussi ce qui donne enfin une raison de
	# porter du tissu : il ne protege de rien, mais il vous presente.
	var bonus_c: Dictionary = regles.r.armure.get("bonus_construction", {})
	for slot: String in e.equipement.keys():
		var it: Dictionary = items.get(e.equipement[slot], {})
		var constr := str(it.get("construction", ""))
		if not constr.is_empty() and bonus_c.has(constr):
			var bc: Dictionary = bonus_c[constr]
			var nom_bc := str(bc.get("stat", ""))
			if not nom_bc.is_empty():
				stats[nom_bc] = int(stats.get(nom_bc, 0)) + int(bc.get("valeur", 0))
		var q := float(it.get("qualite", 1.0))
		for ax: Dictionary in it.get("affixes", []):
			var d: Dictionary = affixes_defs.get(ax.id, {})
			if d.is_empty() or d.get("inerte", false):
				continue
			match str(d.effet.type):
				"passif_stat":
					stats[ax.params.stat] = int(stats.get(ax.params.stat, 0)) + roundi(float(ax.params.n) * q)
				"passif_competence":
					comp[ax.params.competence] = int(comp.get(ax.params.competence, 0)) + roundi(float(ax.params.n) * q)
				"passif_tag":
					tags.append(str(ax.params.tag))
				"passif_mecanique":
					e.mecaniques[str(d.effet.mecanique)] = ax.params
				"wuxing_segment":
					segments_bonus += 1
				"meca_endurance_max":
					endurance_bonus += int(ax.params.n)
				"meca_capacite":   # du porteur : capacité de poids cumulée (lue par poids_de)
					e.mecaniques["capacite_poids"] = {"n": int(e.mecaniques.get("capacite_poids", {}).get("n", 0)) + int(ax.params.kg)}
		# Gemmes serties : tous les bonus plats (Loot — GEMMES = TOUS LES BONUS PLATS, jamais une règle).
		for uid in it.get("sertissures", {}).get("contenu", []):
			var gemme: Dictionary = items.get(uid, {})
			var t: Dictionary = gemme.get("taille", {})
			if t.is_empty():
				continue
			match str(t.type):
				"stat":
					stats[t.stat] = int(stats.get(t.stat, 0)) + int(t.valeur)
				"competence":
					var deja := int(par_competence.get(t.competence, 0))
					var ajout := mini(int(t.valeur), plafond - deja)
					if ajout > 0:
						par_competence[t.competence] = deja + ajout
						comp[t.competence] = int(comp.get(t.competence, 0)) + ajout
				"degats_element":
					e.degats_element[t.element] = int(e.degats_element.get(t.element, 0)) + int(t.valeur)
				"affinite":
					if slot == "main_principale":
						e.affinites[t.element] = float(e.affinites.get(t.element, 0.0)) + float(t.valeur)
				"sante_max":
					sante_bonus += int(t.valeur)
				"mana_max":
					mana_bonus += int(t.valeur)
				"endurance_max":
					endurance_bonus += int(t.valeur)
	if int(e.get("faim", 100)) < int(regles.r.faim.seuil_stats):   # Faim < 25 : −10 % à toutes les stats
		for k in stats.keys():
			stats[k] = maxi(1, roundi(float(stats[k]) * float(regles.r.faim.malus_stats)))
	var mult := 1.0
	for s in e.get("statuts", []):   # Compagnons : ressuscité → affaibli (−20 % un jour)
		if str(s.get("id", "")) == "affaibli":
			mult *= float(e.get("affaibli_mult", 0.8))
	mult *= float(e.get("age_mult", 1.0))   # Âge des PNJ : les âgés perdent des stats physiques
	if mult != 1.0:
		for k in ["force", "dexterite", "endurance"]:
			stats[k] = maxi(1, roundi(float(stats[k]) * mult))
	if float(e.get("forme_mult", 1.0)) != 1.0:   # Lycanthrope : la forme bestiale multiplie toutes les stats
		for k in stats.keys():
			stats[k] = maxi(1, roundi(float(stats[k]) * float(e.forme_mult)))
	e.stats_eff = stats
	e.competences_eff = comp
	e.tags_acquis = tags
	var talent_race = GameData.catalogues.get("races", {}).get(str(e.get("race", "")), {}).get("talent")
	if talent_race != null and str(talent_race) == "chair_de_mana":   # Chair de mana (Talents de race)
		endurance_bonus += int(regles.r.get("talents", {}).get("chair_de_mana", {}).get("endurance_max", -20))
	if talent_race != null and str(talent_race) == "oeil_de_la_pierre" and not ("detection_filons" in tags):
		tags.append("detection_filons")
	var end_max: int = regles.vigueur_max(stats) + endurance_bonus
	e.endurance = mini(int(e.endurance), end_max) if int(e.endurance_max) != end_max else int(e.endurance)
	e.endurance_max = end_max
	# Le sang-froid suit la dextérité comme la vigueur suit la force : la barre du propriétaire de la
	# monnaie bouge quand sa stat bouge, et ce qu'on avait dedans est rogné si le plafond descend.
	var sf_max := regles.sang_froid_max(stats)
	e["sang_froid"] = mini(int(e.get("sang_froid", sf_max)), sf_max) if int(e.get("sang_froid_max", -1)) != sf_max else int(e.get("sang_froid", sf_max))
	e["sang_froid_max"] = sf_max
	# Les maxima dérivés des stats effectives ; la valeur courante est clampée, plancher 1 pour la santé.
	e.sante_max = maxi(1, regles.sante_max(stats) + sante_bonus - int(e.get("erosion", 0)))   # Érosion : PV max rognés pour le combat
	e.sante = clampi(int(e.sante), 1, int(e.sante_max)) if int(e.sante) > 0 else int(e.sante)
	e.mana_max = regles.mana_max(stats) + mana_bonus
	if e.has("mana_max_mult"):   # contrepartie d'un talent (Le Passeur)
		e.mana_max = maxi(1, roundi(float(e.mana_max) * float(e.mana_max_mult)))
	e.mana = mini(int(e.mana), int(e.mana_max))
	if e.has("chaine"):
		e.chaine.capacite = int(GameData.config("wuxing").chaine.capacite_base) + segments_bonus


## Les affixes actifs d'un type sur l'équipement de `e` (toutes pièces), avec la pièce porteuse.
static func affixes_equipes(e: Dictionary, items: Dictionary, affixes_defs: Dictionary, type: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for slot: String in e.equipement.keys():
		var it: Dictionary = items.get(e.equipement[slot], {})
		for ax in Loot.affixes_de_type(it, affixes_defs, type):
			ax["piece"] = it
			res.append(ax)
	return res


## Les munitions du carquois équipé (Décision — Projectiles).
static func _munitions(equip: Dictionary, items: Dictionary) -> int:
	var id: String = equip.get("carquois", "")
	return int(items.get(id, {}).get("quantite", 0)) if not id.is_empty() else 0


## Un statut actif portant ce tag ?
static func statut_touche_stats(id: String, defs: Dictionary) -> bool:
	for mod: Dictionary in defs.get(id, {}).get("modifiers", []):
		if str(mod.cible).begins_with("stat:") or str(mod.cible) == "tag":
			return true
	return false


static func a_statut_id(e: Dictionary, id: String) -> bool:
	for s: Dictionary in e.statuts:
		if str(s.id) == id:
			return true
	return false


static func a_statut_tag(e: Dictionary, tag: String, defs: Dictionary) -> bool:
	for s: Dictionary in e.statuts:
		if tag in defs.get(s.id, {}).get("tags", []):
			return true
	return false


## Produit des multiplicateurs des statuts actifs pour une cible de modificateur (cout_ticks, degats…).
static func mult_statuts(e: Dictionary, cible: String, defs: Dictionary) -> float:
	var m := 1.0
	for s: Dictionary in e.statuts:
		for mod: Dictionary in defs.get(s.id, {}).get("modifiers", []):
			if mod.cible == cible and mod.has("mult"):
				m *= float(mod.mult)
	return m


## Somme des ajouts des statuts actifs pour une cible de modificateur (armure…).
static func add_statuts(e: Dictionary, cible: String, defs: Dictionary) -> float:
	var a := 0.0
	for s: Dictionary in e.statuts:
		for mod: Dictionary in defs.get(s.id, {}).get("modifiers", []):
			if mod.cible == cible and mod.has("add"):
				a += float(mod.add)
	return a


## Un statut bloque-t-il cette action (deplacement, garde) ?
static func bloque_statuts(e: Dictionary, cible: String, defs: Dictionary) -> bool:
	for s: Dictionary in e.statuts:
		for mod: Dictionary in defs.get(s.id, {}).get("modifiers", []):
			if mod.cible == cible and mod.get("bloque", false):
				return true
	return false


static func est_volant(e: Dictionary) -> bool:
	return e.corps.silhouette == "volant"


static func a_bouclier(e: Dictionary, items: Dictionary) -> bool:
	var id: String = e.equipement.get("main_secondaire", "")
	return not id.is_empty() and items.get(id, {}).get("type", "") == "bouclier"


static func arme(e: Dictionary, items: Dictionary) -> Dictionary:
	return items.get(e.equipement.get("main_principale", ""), {})


## La pièce d'armure couvrant la zone, ou {} (zone nue = 0).
static func piece_zone(e: Dictionary, zone: String, items: Dictionary) -> Dictionary:
	for item_id: String in e.equipement.values():
		var it: Dictionary = items.get(item_id, {})
		if it.get("type", "") == "armure" and it.get("zone", "") == zone:
			return it
	return {}
