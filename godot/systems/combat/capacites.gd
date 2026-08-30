class_name Capacites
extends RefCounted
## L'assemblage des modules (Six types de modules et assemblage · Modules · Vocabulaire des
## modules — six axes) : une capacité est une séquence ordonnée [forme, noyau, modificateurs,
## conditions…] résolue comme UNE action. Ici : la lecture de la séquence → un plan exécutable
## {noyau, forme, dés, coûts, monnaie, conditions, drapeaux}. La géométrie des formes aussi.

var modules: Dictionary   # le catalogue data/modules
var par_niveau := 0.02    # skill_factor : + par niveau (combat_rules.progression)
var plancher := 0.5       # ticks d'un module : jamais sous 50 % de sa base


func _init(catalogue: Dictionary) -> void:
	modules = catalogue


## Lit `"+4"`, `"×1.3"`, `"−2"`, `"0"` → {"plus": int, "mult": float}.
static func lire_surcout(s: Variant) -> Dictionary:
	var r := {"plus": 0, "mult": 1.0}
	if s == null:
		return r
	var t := str(s).strip_edges().replace("−", "-")
	if t.begins_with("×") or t.begins_with("x"):
		r.mult = float(t.substr(1))
	elif not t.is_empty():
		r.plus = int(t)
	return r


## Assemble une séquence d'ids de modules. `ticks_arme` / `des_arme` : pour les noyaux « arme ».
## Retourne le plan ; `plan.erreurs` liste ce que la séquence a d'invalide.
## Ticks d'un module selon son niveau : base / skill_factor, plancher 50 % (décision du 2026-08-27).
func ticks_module(base: int, id: String, niveaux: Dictionary) -> int:
	if base <= 0:
		return base
	var sf := 1.0 + float(niveaux.get(id, 0)) * par_niveau
	return maxi(int(ceilf(float(base) * plancher)), roundi(float(base) / sf))


## Alternance (Modules) : une séquence à deux noyaux devient deux plans, joués à tour de rôle.
## `sans` retire le n-ième noyau de la séquence (0 = le premier).
static func _sans_noyau(sequence: Array, modules: Dictionary, n: int) -> Array:
	var res: Array = []
	var vus := 0
	for id in sequence:
		if str(modules.get(str(id), {}).get("module_type", "")) == "noyau":
			if vus == n:
				vus += 1
				continue
			vus += 1
		res.append(id)
	return res


func assembler(sequence: Array, ticks_arme: int, des_arme: Variant, element_arme: Dictionary, niveaux: Dictionary = {}) -> Dictionary:
	var plan := {
		"modules": sequence, "noyau": {}, "forme": {}, "erreurs": [], "avertissements": [],
		"geometrie": "point", "origine": "cible", "portee": Vector2i(1, 1), "taille": 1, "ligne_de_vue": true,
		"ticks": 0, "monnaie": "", "ressource": 0, "des": null, "des_bonus": 0, "mult": 1.0,
		"elements": {}, "effets": [], "conditions": [], "drapeaux": {}, "parametres": {},
		"liaisons": [], "charge_suivante": {}, "charges_sup": [], "formes_sup": [],
	}
	var alternance := false   # Alternance (Modules) : la séquence a droit à deux noyaux
	var noyaux := 0
	for id0 in sequence:
		var m0: Dictionary = modules.get(str(id0), {})
		if bool(m0.get("effet", {}).get("alternance", false)):
			alternance = true
		if str(m0.get("module_type", "")) == "noyau":
			noyaux += 1
	if alternance and noyaux >= 2 and not sequence.has("__alt__"):
		var plan_a := assembler(_sans_noyau(sequence, modules, 1), ticks_arme, des_arme, element_arme, niveaux)
		plan_a["alt"] = assembler(_sans_noyau(sequence, modules, 0), ticks_arme, des_arme, element_arme, niveaux)
		plan_a["modules"] = sequence
		return plan_a
	var plus := 0
	var mult := 1.0
	for k in sequence.size():
		var id: String = sequence[k]
		var m: Dictionary = modules.get(id, {})
		if m.is_empty():
			plan.erreurs.append("module inconnu : " + id)
			continue
		if str(m.module_type) == "declencheur":
			# Un déclencheur encapsule tout ce qui le suit comme charge utile (Six types de modules).
			var ef: Dictionary = m.get("effet", {})
			if ef.is_empty():
				plan.avertissements.append("déclencheur non résolu dans le prototype : " + id)
				plan.ticks += int(m.get("surcout_ticks", 0))
				break
			var suite := assembler(sequence.slice(k + 1), ticks_arme, des_arme, element_arme, niveaux)
			suite["declencheur"] = str(ef.declencheur)
			suite["duree_declencheur"] = int(ef.get("duree_ticks", 100))
			suite["ticks_declencheur"] = int(ef.get("ticks", 20))
			suite["pct_declencheur"] = int(ef.get("pct", 40))
			suite["n_declencheur"] = int(ef.get("n", 3))
			suite["name_key"] = m.name_key
			plan.charge_suivante = suite
			plan.ticks += ticks_module(int(m.get("surcout_ticks", 0)), id, niveaux) + int(suite.ticks)
			plan.erreurs.append_array(suite.erreurs)
			break
		match str(m.module_type):
			"noyau":
				if not plan.noyau.is_empty():
					if alternance:
						continue   # Alternance : le second noyau est assemblé dans le plan `alt`
					# Aucune limite d'assemblage (Six types de modules) : le noyau de plus est une charge de
					# plus, avec ses dés, ses effets et son coût. Le prix, pas l'assembleur, est la borne.
					var sup := {"noyau": m, "effets": m.get("effets", []).duplicate(),
						"des": des_arme if m.get("power_base") == "arme" else m.get("power_base"),
						"elements": element_arme.duplicate() if (m.get("power_base") == "arme" or m.get("element_special") == "arme") else m.get("elements", {}).duplicate(),
						"parametres": m.get("effet", {}).duplicate(), "des_bonus": 0, "mult": 1.0,
						"drapeaux": plan.drapeaux, "liaisons": [], "modules": [id], "name_key": m.name_key}
					plan.charges_sup.append(sup)
					plan.ticks += ticks_arme if m.get("power_base") == "arme" else ticks_module(int(m.cout_ticks), id, niveaux)
					var sf_sup := 1.0 + float(niveaux.get(id, 0)) * par_niveau
					if int(m.get("cout_mana", 0)) > 0 and plan.monnaie in ["", "mana"]:
						plan.monnaie = "mana"
						plan.ressource += roundi(float(m.cout_mana) / sf_sup)
					elif int(m.get("cout_endurance", 0)) > 0:
						if plan.monnaie == "":
							plan.monnaie = "endurance"
						plan.ressource += roundi(float(m.cout_endurance) / sf_sup)
					continue
				plan.noyau = m
				var arme: bool = m.get("power_base") == "arme"
				plan.ticks += ticks_arme if arme else ticks_module(int(m.cout_ticks), id, niveaux)
				plan.des = des_arme if arme else m.get("power_base")
				plan.elements = element_arme.duplicate() if (arme or m.get("element_special") == "arme") else m.get("elements", {}).duplicate()
				plan.effets = m.get("effets", []).duplicate()
				plan.des_bonus += int(m.get("des_bonus", 0))   # le palier moyen de la matrice : +1 dé
				# Ressource : coût de base / skill_factor(N_module) (Mana, Structure compétences-modules-slots).
				var sf_noyau := 1.0 + float(niveaux.get(id, 0)) * par_niveau
				if int(m.get("cout_mana", 0)) > 0:
					plan.monnaie = "mana"
					plan.ressource = roundi(float(m.cout_mana) / sf_noyau)
				elif int(m.get("cout_endurance", 0)) > 0:
					plan.monnaie = "endurance"
					plan.ressource = roundi(float(m.cout_endurance) / sf_noyau)
				plan.parametres = m.get("effet", {}).duplicate()
			"forme":
				if not plan.forme.is_empty():
					# Deux formes : les tuiles s'additionnent (union), la portée retenue est la plus longue.
					plan.formes_sup.append({"geometrie": str(m.geometrie), "taille": int(m.taille_base)})
					plan.portee.y = maxi(int(plan.portee.y), int(m.portee_base[1]))
					plan.ticks += ticks_module(int(m.get("surcout_ticks", 0)), id, niveaux)
					continue
				plan.forme = m
				plan.geometrie = str(m.geometrie)
				plan.origine = str(m.get("origine", "cible"))   # d'où part la forme (Six types de modules)
				plan.portee = Vector2i(int(m.portee_base[0]), int(m.portee_base[1]))
				plan.taille = int(m.taille_base)
				plan.ligne_de_vue = bool(m.get("ligne_de_vue", true))
				plan.ticks += ticks_module(int(m.get("surcout_ticks", 0)), id, niveaux)
			"modificateur":
				plan.ticks += ticks_module(int(m.get("surcout_ticks", 0)), id, niveaux)
				var s := lire_surcout(m.get("surcout_ressource"))
				plus += s.plus
				mult *= s.mult
				var ef: Dictionary = m.get("effet", {})
				if ef.is_empty() and m.has("effet") == false:
					plan.avertissements.append("modificateur sans effet structuré : " + id)
				plan.des_bonus += int(ef.get("des", 0))
				plan.portee.y += int(ef.get("portee", 0))
				if ef.has("portee_mult"):
					plan.portee.y *= int(ef.portee_mult)
				if ef.has("portee_fixe"):
					plan.portee = Vector2i(1, int(ef.portee_fixe))
				if ef.has("portee_min"):
					plan.portee.x = int(ef.portee_min)
				plan.taille = maxi(1, plan.taille + int(ef.get("taille", 0)))
				for cle in ["ignore_armure", "vampirique", "durees_mult", "projection", "attraction", "segments", "purification",
						"silencieux", "sans_trace", "detonation", "emprise", "tracant", "prisme", "element_vers",
						"canalisation", "enchainement", "fragmentation", "ligature", "remanence", "ricochet"]:
					if ef.has(cle):
						plan.drapeaux[cle] = ef[cle]
				if ef.has("geometrie_map"):   # Évasement : la forme s'ouvre (Ligne → Cône, Anneau → Carré)
					var mapg: Dictionary = ef.geometrie_map
					if mapg.has(plan.geometrie):
						plan.geometrie = str(mapg[plan.geometrie])
						plan.taille = maxi(1, int(plan.taille) + 1)
			"condition":
				var ef: Dictionary = m.get("effet", {})
				if ef.is_empty():
					plan.avertissements.append("condition sans prédicat structuré : " + id)
					continue
				plan.conditions.append({"id": id, "name_key": m.name_key, "predicat": ef.predicat_structure,
					"bonus": ef.bonus_structure, "ticks_rendus": float(ef.get("echec_ticks_rendus", 0.5))})
				plan.ticks += ticks_module(int(m.get("surcout_ticks", 0)), id, niveaux)
			"liaison":
				plan.ticks += ticks_module(int(m.get("surcout_ticks", 0)), id, niveaux)
				var ef: Dictionary = m.get("effet", {})
				if ef.is_empty():
					plan.avertissements.append("liaison sans effet en données (ignorée) : " + id)
				else:
					plan.liaisons.append(ef.duplicate())
			_:
				plan.ticks += int(m.get("surcout_ticks", 0))
				plan.avertissements.append("type non résolu dans le prototype : " + id)
	if plan.noyau.is_empty():
		var suite: Dictionary = plan.charge_suivante
		if suite.is_empty() or suite.noyau.is_empty():
			plan.erreurs.append("aucun noyau")
		elif suite.declencheur in ["entree", "apres_ticks"]:
			# Séquence ouverte par un déclencheur (Sceau, Mèche) : on vise avec la géométrie de la charge différée.
			plan.geometrie = suite.geometrie
			plan.portee = suite.portee
			plan.taille = suite.taille
			plan.ligne_de_vue = suite.ligne_de_vue
			plan.forme = suite.forme
		else:
			plan.geometrie = "soi"   # déclencheur à événement : la séquence arme le porteur
			plan.forme = {"geometrie": "soi"}
	if plan.forme.is_empty():
		# Sans forme, un noyau vise l'adjacent (Modules).
		plan.geometrie = "point"
		plan.portee = Vector2i(1, 1)
	plan.ressource = maxi(0, roundi((float(plan.ressource) + float(plus)) * mult))
	plan.ticks = maxi(1, plan.ticks)
	return plan


## Bonus d'une condition vraie, appliqué au plan (dés, ticks, portée, taille, multiplicateur).
static func appliquer_bonus(plan: Dictionary, bonus: Dictionary) -> void:
	plan.des_bonus += int(bonus.get("des", 0))
	plan.ticks = maxi(1, plan.ticks + int(bonus.get("ticks", 0)))
	plan.portee.y += int(bonus.get("portee", 0))
	plan.taille += int(bonus.get("taille", 0))
	plan.mult *= float(bonus.get("mult", 1.0))
	if bonus.has("ressource_mult"):   # Terroir : −25 % de ressource
		plan.ressource = maxi(0, roundi(float(plan.ressource) * float(bonus.ressource_mult)))


# ---------------------------------------------------------------- géométrie des formes

## Les tuiles d'une forme, depuis `origine` vers `cible` (la tuile visée).
static func tuiles_de_forme(g: Grille, geometrie: String, origine: Vector2i, cible: Vector2i, taille: int) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	var d := Vector2i(signi(cible.x - origine.x), signi(cible.y - origine.y))
	match geometrie:
		"point":
			res.append(cible)
		"soi":
			res.append(origine)
		"ligne":
			res = g.ligne(origine, cible, taille)
		"cone":
			# S'élargit avec la distance : à la profondeur k, largeur 2k−1 perpendiculaire.
			if d == Vector2i.ZERO:
				return res
			var perp := Vector2i(-d.y, d.x)
			for k in range(1, taille + 1):
				var centre := origine + d * k
				for w in range(-(k - 1), k):
					var p := centre + perp * w
					if g.dans(p):
						res.append(p)
		"croix":
			res.append(cible)
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				for k in range(1, taille + 1):
					var p: Vector2i = cible + dir * k
					if g.dans(p):
						res.append(p)
		"diagonale":
			res.append(cible)
			for dir in [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				for k in range(1, taille + 1):
					var p: Vector2i = cible + dir * k
					if g.dans(p):
						res.append(p)
		"carre":
			for y in range(-taille, taille + 1):
				for x in range(-taille, taille + 1):
					var p := cible + Vector2i(x, y)
					if g.dans(p):
						res.append(p)
		"anneau":
			res = g.anneau(cible, taille)
		"tuile":
			res.append(cible)
		"vague":
			if d == Vector2i.ZERO:
				return res
			var perp := Vector2i(-d.y, d.x)
			for k in range(1, 3):
				for w in range(-(taille / 2), taille / 2 + 1):
					var p := origine + d * k + perp * w
					if g.dans(p):
						res.append(p)
		"mur":
			var perp := Vector2i(-d.y, d.x) if d != Vector2i.ZERO else Vector2i(1, 0)
			for w in range(-(taille / 2), taille / 2 + 1):
				var p := cible + perp * w
				if g.dans(p):
					res.append(p)
		"sillage":   # les N tuiles DERRIÈRE la cible, dans l'axe du lanceur — pour ce qui traverse
			if d == Vector2i.ZERO:
				return res
			for k in range(1, taille + 1):
				var p: Vector2i = cible + d * k
				if g.dans(p):
					res.append(p)
		"chemin":   # le trajet du lanceur vers la cible : tout ce qu'il longe est touché
			for p in g.ligne(origine, cible, taille):
				if p != origine and g.dans(p):
					res.append(p)
		"colonne":   # toute la hauteur d'une tuile : la tuile elle-même (volants et contrebas y sont)
			res.append(cible)
		"horizon":   # toutes les tuiles en vue dans la portée — le prix des ticks est le garde-fou
			var r := mini(taille, 12)
			for y in range(-r, r + 1):
				for x in range(-r, r + 1):
					var p := origine + Vector2i(x, y)
					if p != origine and g.dans(p) and Grille.distance(origine, p) <= r and g.ligne_de_vue(origine, p):
						res.append(p)
		"nuee":   # N tuiles aléatoires autour de la cible, reproductibles pour une même visée
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([origine, cible, taille])
			var cand: Array[Vector2i] = []
			for y in range(-2, 3):
				for x in range(-2, 3):
					var p := cible + Vector2i(x, y)
					if g.dans(p):
						cand.append(p)
			while res.size() < taille and not cand.is_empty():
				res.append(cand.pop_at(rng.randi_range(0, cand.size() - 1)))
		_:
			push_warning("Capacités : géométrie de forme inconnue « %s » — visée au point" % geometrie)
			res.append(cible)
	return res
