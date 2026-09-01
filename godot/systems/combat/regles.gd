class_name Regles
extends RefCounted
## Les formules du combat, pures, lues dans `combat_rules.json` — aucune valeur en dur.
##   Zones de coup par dénivelé · Armure par zone et constructions · Pipeline de résolution
##   du combat (E.3 étape 3) · Stats d'armes · Garde en posture · Endurance · Stats de personnage.

var r: Dictionary   # la configuration combat_rules


func _init(regles: Dictionary) -> void:
	r = regles


# ---------------------------------------------------------------- progression

## skill_factor(N) = 1 + N × 0,02 (Progression par l'usage).
func skill_factor(niveau: int) -> float:
	return 1.0 + float(niveau) * float(r.progression.skill_factor_par_niveau)


func niveau(competences: Dictionary, cle: String) -> int:
	return int(competences.get(cle, 0))


## Facteur de compétences d'un coup d'arme : arme × type de dégâts × élément dominant pondéré
## (Pipeline de résolution du combat, décision du 2026-08-27).
func facteur_competences(competences: Dictionary, fonct: Dictionary, vecteur: Dictionary) -> float:
	var f := skill_factor(niveau(competences, str(fonct.get("combat_skill", "")))) \
		* skill_factor(niveau(competences, str(fonct.get("type_degats", ""))))
	if not vecteur.is_empty():
		var somme := 0.0
		for e: String in vecteur.keys():
			somme += float(vecteur[e]) * (1.0 + float(niveau(competences, "element_" + e)) / 100.0)
		f *= somme
	return f


## Ticks de déplacement d'un être : coût de pente / skill_factor(Athlétisme) × esquive en combat, min 2.
func ticks_deplacement(cout_pente: int, competences: Dictionary, en_combat: bool) -> int:
	var k := 1.0 / skill_factor(niveau(competences, "athletisme"))
	if en_combat:
		k *= 1.0 - minf(float(r.progression.esquive_max), float(niveau(competences, "esquive")) * float(r.progression.esquive_par_niveau))
	return maxi(int(r.progression.deplacement_min), roundi(float(cout_pente) * k))


# ---------------------------------------------------------------- stats dérivées

func sante_max(stats: Dictionary) -> int:
	return int(r.stats.sante_max_base) + int(stats.endurance) * int(r.stats.sante_max_par_endurance)


func mana_max(stats: Dictionary) -> int:
	return int(r.stats.mana_max_base) + int(stats.volonte) * int(r.stats.mana_max_par_volonte)


# ---------------------------------------------------------------- tempo

## `attaque : 10 / vitesse_arme` ticks, ×2 pour la lourde (Boucle de tick).
func ticks_attaque(fonct: Dictionary, lourde: bool, arme: Dictionary = {}) -> int:
	# la densité du manche pilote la vitesse (Stats et qualité de l'assemblage) : facteur porté par l'objet
	var t := roundi(float(r.actions.attaque_base) / float(fonct.vitesse_base) * float(arme.get("vitesse_facteur", 1.0)))
	return maxi(1, t) * int(r.actions.lourde_mult_ticks) if lourde else maxi(1, t)


## Poids porté (Armures et poids porté) : capacité = base + Force × par_force.
func capacite_poids(stats: Dictionary) -> float:
	return float(r.poids.base) + float(stats.force) * float(r.poids.par_force)


## Le poids d'un objet : champ `poids`, sinon la fonctionnalité, la station, la densité du matériau.
func poids_objet(it: Dictionary, fonctionnalites: Dictionary) -> float:
	if it.has("poids"):
		return float(it.poids) * float(it.get("quantite", 1))
	match str(it.get("type", "")):
		"materiau":
			var mat: Dictionary = GameData.catalogues.materials.get(str(it.get("materiau", "")), {})
			return float(mat.get("stats", {}).get("densite", 4)) / float(r.poids.densite_div) * float(it.get("quantite", 1))
		"station":
			return float(GameData.catalogues.stations.get(str(it.get("station", "")), {}).get("poids", r.poids.defaut))
		"meuble":
			return float(r.poids.meuble)
		"armure":
			return float(r.poids.armure)
		_:
			var f: Dictionary = fonctionnalites.get(str(it.get("functionality", "")), {})
			return float(f.get("poids_reference", r.poids.defaut))


## Le facteur de surcharge sur les ticks de déplacement : 1 jusqu'à la capacité, puis croissant, plafonné.
func facteur_surcharge(poids: float, capacite: float) -> float:
	if capacite <= 0.0 or poids <= capacite:
		return 1.0
	return minf(float(r.poids.plafond), 1.0 + (poids / capacite - 1.0) * float(r.poids.pente))


## Qualité d'artisanat (A.3) : max(min, N/(N+pivot) × max × aléa[a, b]) — composants, plats, potions.
## `resserrement` (Axe des niveaux de recette) : réduit l'aléa des deux côtés — jamais la qualité elle-même.
func qualite_craft(niveau: int, rng: RandomNumberGenerator, resserrement: float = 0.0) -> float:
	var q: Dictionary = r.craft.qualite
	var a0 := float(q.alea[0]) + resserrement
	var a1 := maxf(a0, float(q.alea[1]) - resserrement)
	var brut := float(niveau) / float(niveau + int(q.pivot)) * float(q.max) * rng.randf_range(a0, a1)
	return maxf(float(q.min), brut)


## Le resserrement d'un niveau de recette N : (N − 1) × resserrement_par_niveau.
func resserrement_recette(niveau_recette: int) -> float:
	return float(maxi(0, niveau_recette - 1)) * float(r.craft.qualite.get("resserrement_par_niveau", 0.03))


## Le palier de nom d'une qualité (Qualité d'artisanat : 8 paliers).
func palier_qualite(q: float) -> String:
	var nom := "miserable"
	for p in r.craft.paliers_qualite:
		if q >= float(p[0]):
			nom = str(p[1])
	return nom


## Portée en tuiles de Chebyshev : [min, floor(max)] (décision du 2026-08-26, Stats d'armes).
func portee_de(fonct: Dictionary) -> Vector2i:
	return Vector2i(int(fonct.get("portee_min", 1)), int(floorf(float(fonct.portee))))


func a_portee(fonct: Dictionary, d: int) -> bool:
	var p := portee_de(fonct)
	return d >= p.x and d <= p.y


func est_telegraphee(ticks: int) -> bool:
	return ticks > int(r.actions.telegraphe_seuil_ticks)


# ---------------------------------------------------------------- zones et armure

## La zone frappée dépend du dénivelé attaquant → cible, jamais visée.
func zone_de_coup(h_attaquant: int, h_cible: int) -> Dictionary:
	if h_attaquant > h_cible:
		return r.zones.plus_haut
	if h_attaquant < h_cible:
		return r.zones.plus_bas
	return r.zones.egal


## armure_zone = dureté/4 × qualité × (1 + niveau/100) × matrice[construction][type]
func armure_piece(piece: Dictionary, type_degats: String) -> float:
	if piece.is_empty():
		return 0.0
	var mat: Dictionary = r.armure.matrice.get(piece.get("construction", ""), {})
	var facteur: float = float(mat.get(type_degats, 1.0))
	if type_degats == "magique" and not mat.has("magique"):   # « magique » : un type à part entière (2026-08-30) ; à défaut d'une colonne, contondant × magie_facteur
		facteur = float(mat.get("contondant", 1.0)) * float(r.armure.get("magie_facteur", 0.5))
	return float(piece.durete_composite) / float(r.armure.durete_div) * float(piece.qualite) \
		* (1.0 + float(piece.get("niveau_construction", 0)) / 100.0) * facteur


## Dégâts finaux = max(1, bruts × zone − armure). La garde (frontale) retire ensuite 80 %.
func degats_finaux(bruts: float, zone_mult: float, armure: float, garde_tient: bool) -> int:
	var d := maxf(float(r.armure.degats_min), bruts * zone_mult - armure)
	if garde_tient:
		d *= 1.0 - float(r.garde.reduction)
	return maxi(int(r.armure.degats_min), roundi(d))


# ---------------------------------------------------------------- dégâts bruts

## bruts = jet(dés) × (dureté_base/20) × qualité + For/4 (mêlée) ou Dex/4 (distance),
## ×2.2 en lourde, ×0.6 à zéro d'endurance.
func degats_arme(stats: Dictionary, arme: Dictionary, fonct: Dictionary, des: Des, lourde: bool, endurance_a_zero: bool, des_bonus: int = 0, competences: Dictionary = {}, vecteur: Dictionary = {}) -> Dictionary:
	var jet := des.jet(fonct.degats_des, des_bonus)
	var mult := float(arme.durete_base) / float(r.degats.durete_reference) * float(arme.qualite) * facteur_competences(competences, fonct, vecteur)
	var distance := portee_de(fonct).y > 1 and int(fonct.get("portee_min", 1)) > 1
	var stat := int(stats.dexterite if distance else stats.force) / int(r.degats.stat_div)
	var bruts := float(jet) * mult + float(stat)
	if lourde:
		bruts *= float(r.actions.lourde_mult_degats)
	if endurance_a_zero:
		bruts *= float(r.endurance.a_zero_degats_mult)
	return {"jet": jet, "mult": mult, "stat": stat, "bruts": bruts, "lourde": lourde, "des": fonct.degats_des}


## Dégâts bruts d'une action de créature : jet(dés + dés bonus) + For/4, ×0.6 à zéro d'endurance.
func degats_action(stats: Dictionary, action: Dictionary, des: Des, endurance_a_zero: bool, des_bonus: int) -> Dictionary:
	var jet := des.jet(action.get("degats_des"), des_bonus)
	var stat := int(stats.force) / int(r.degats.stat_div)
	var bruts := float(jet + stat)
	if endurance_a_zero:
		bruts *= float(r.endurance.a_zero_degats_mult)
	return {"jet": jet, "mult": 1.0, "stat": stat, "bruts": bruts, "lourde": false, "des": action.get("degats_des")}


## Fourchette [min, max] des dégâts finaux d'une arme (prévisualisation UI, détail du calcul).
## `k_ext` : facteur externe (Wu Xing : domination × gain × chaîne).
func fourchette_arme(stats: Dictionary, arme: Dictionary, fonct: Dictionary, lourde: bool, zone_mult: float, armure: float, endurance_a_zero: bool, k_ext: float = 1.0, competences: Dictionary = {}, vecteur: Dictionary = {}) -> Vector2i:
	var f := Des.fourchette(fonct.degats_des)
	var mult := float(arme.durete_base) / float(r.degats.durete_reference) * float(arme.qualite) * facteur_competences(competences, fonct, vecteur)
	var distance := int(fonct.get("portee_min", 1)) > 1
	var stat := int(stats.dexterite if distance else stats.force) / int(r.degats.stat_div)
	var k := (float(r.actions.lourde_mult_degats) if lourde else 1.0) * (float(r.endurance.a_zero_degats_mult) if endurance_a_zero else 1.0) * k_ext
	return Vector2i(degats_finaux((f.x * mult + stat) * k, zone_mult, armure, false),
		degats_finaux((f.y * mult + stat) * k, zone_mult, armure, false))


# ---------------------------------------------------------------- garde

## Direction d'où vient le coup, pour une cible orientée `orientation` : front · flanc · dos.
static func direction_relative(orientation: Vector2i, de_cible_vers_attaquant: Vector2i) -> String:
	if orientation == Vector2i.ZERO or de_cible_vers_attaquant == Vector2i.ZERO:
		return "front"
	var a := Vector2(orientation).normalized()
	var b := Vector2(de_cible_vers_attaquant).normalized()
	var cosinus := a.dot(b)
	if cosinus > 0.6:      # ≤ 45° : les trois tuiles devant
		return "front"
	if cosinus > -0.6:     # 90° : les deux flancs
		return "flanc"
	return "dos"


## La garde tient-elle ? Frontale ; avec bouclier : front + flancs, et la lourde ne la brise pas.
func garde_tient(direction: String, bouclier: bool, lourde: bool) -> bool:
	if lourde and not bouclier:
		return false
	if bouclier:
		return direction != "dos"
	return direction == "front"


## Endurance perdue à l'impact : 12 + dégâts/4 (6 + dégâts/8 avec bouclier).
func cout_garde_impact(degats: int, bouclier: bool, competences: Dictionary = {}) -> int:
	if bouclier:   # Décision — Boucliers : la compétence Bouclier réduit le coût à l'impact
		return maxi(1, roundi(float(int(r.garde.bouclier_impact_base) + degats / int(r.garde.bouclier_impact_div)) / skill_factor(niveau(competences, "bouclier"))))
	return int(r.endurance.garde_impact_base) + degats / int(r.endurance.garde_impact_div)

## Les dégâts bruts d'un SORT (designer 2026-09-01) : le miroir de ceux d'une arme —
## jet × (focus × école × affinités) + stat/stat_div. Sans focus en main, le facteur vaut 1.
func degats_sort(stats: Dictionary, competences: Dictionary, vecteur: Dictionary, focus: Dictionary, des: Des, notation: Variant, des_bonus: int = 0) -> Dictionary:
	var cfg: Dictionary = r.degats.get("sort", {})
	var jet := des.jet(notation, des_bonus)
	var f := 1.0
	if not focus.is_empty():   # ce qu'on tient joue le rôle de l'arme : sa dureté et sa qualité
		f *= float(focus.get("durete_base", r.degats.durete_reference)) / float(r.degats.durete_reference) * float(focus.get("qualite", 1.0))
	var dom := ""
	for el: String in vecteur.keys():
		if dom.is_empty() or float(vecteur[el]) > float(vecteur[dom]):
			dom = str(el)
	if not dom.is_empty():
		f *= skill_factor(niveau(competences, str(cfg.get("ecole_prefixe", "magie_")) + dom))
		var somme := 0.0
		for el: String in vecteur.keys():
			somme += float(vecteur[el]) * (1.0 + float(niveau(competences, "element_" + el)) / 100.0)
		f *= somme
	var stat := int(stats.get(str(cfg.get("stat", "volonte")), 0)) / int(r.degats.stat_div)
	return {"jet": jet, "mult": f, "stat": stat, "bruts": float(jet) * f + float(stat), "des": notation}


## Le focus en main : le premier objet équipé dont un tag figure dans degats.sort.focus_tags.
func focus_de(equipement: Dictionary, items: Dictionary) -> Dictionary:
	var tags_focus: Array = r.degats.get("sort", {}).get("focus_tags", [])
	for slot in ["main_principale", "main_secondaire"]:
		var it: Dictionary = items.get(str(equipement.get(slot, "")), {})
		for t in it.get("tags", []):
			if str(t) in tags_focus:
				return it
		if tags_focus.has(str(it.get("functionality", ""))):
			return it
	return {}
