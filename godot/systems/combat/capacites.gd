class_name Capacites
extends RefCounted
## L'assemblage des modules (Six types de modules et assemblage · Modules · Vocabulaire des
## modules — six axes) : une capacité est une séquence ordonnée [forme, noyau, modificateurs,
## conditions…] résolue comme UNE action. Ici : la lecture de la séquence → un plan exécutable
## {noyau, forme, dés, coûts, monnaie, conditions, drapeaux}. La géométrie des formes aussi.

var modules: Dictionary   # le catalogue data/modules


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
func assembler(sequence: Array, ticks_arme: int, des_arme: Variant, element_arme: Dictionary) -> Dictionary:
	var plan := {
		"modules": sequence, "noyau": {}, "forme": {}, "erreurs": [], "avertissements": [],
		"geometrie": "point", "portee": Vector2i(1, 1), "taille": 1, "ligne_de_vue": true,
		"ticks": 0, "monnaie": "", "ressource": 0, "des": null, "des_bonus": 0, "mult": 1.0,
		"elements": {}, "effets": [], "conditions": [], "drapeaux": {}, "parametres": {},
		"liaisons": [], "charge_suivante": {},
	}
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
			var suite := assembler(sequence.slice(k + 1), ticks_arme, des_arme, element_arme)
			suite["declencheur"] = str(ef.declencheur)
			suite["duree_declencheur"] = int(ef.get("duree_ticks", 100))
			suite["ticks_declencheur"] = int(ef.get("ticks", 20))
			suite["pct_declencheur"] = int(ef.get("pct", 40))
			suite["n_declencheur"] = int(ef.get("n", 3))
			suite["name_key"] = m.name_key
			plan.charge_suivante = suite
			plan.ticks += int(m.get("surcout_ticks", 0)) + int(suite.ticks)
			plan.erreurs.append_array(suite.erreurs)
			break
		match str(m.module_type):
			"noyau":
				if not plan.noyau.is_empty():
					plan.erreurs.append("deux noyaux dans la même séquence (" + id + ")")
					continue
				plan.noyau = m
				var arme: bool = m.get("power_base") == "arme"
				plan.ticks += ticks_arme if arme else int(m.cout_ticks)
				plan.des = des_arme if arme else m.get("power_base")
				plan.elements = element_arme.duplicate() if (arme or m.get("element_special") == "arme") else m.get("elements", {}).duplicate()
				plan.effets = m.get("effets", []).duplicate()
				if int(m.get("cout_mana", 0)) > 0:
					plan.monnaie = "mana"
					plan.ressource = int(m.cout_mana)
				elif int(m.get("cout_endurance", 0)) > 0:
					plan.monnaie = "endurance"
					plan.ressource = int(m.cout_endurance)
				plan.parametres = m.get("effet", {}).duplicate()
			"forme":
				if not plan.forme.is_empty():
					plan.erreurs.append("deux formes dans la même séquence (" + id + ")")
					continue
				plan.forme = m
				plan.geometrie = str(m.geometrie)
				plan.portee = Vector2i(int(m.portee_base[0]), int(m.portee_base[1]))
				plan.taille = int(m.taille_base)
				plan.ligne_de_vue = bool(m.get("ligne_de_vue", true))
				plan.ticks += int(m.get("surcout_ticks", 0))
			"modificateur":
				plan.ticks += int(m.get("surcout_ticks", 0))
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
				for cle in ["ignore_armure", "vampirique", "durees_mult", "projection", "attraction", "segments", "purification"]:
					if ef.has(cle):
						plan.drapeaux[cle] = ef[cle]
			"condition":
				var ef: Dictionary = m.get("effet", {})
				if ef.is_empty():
					plan.avertissements.append("condition sans prédicat structuré : " + id)
					continue
				plan.conditions.append({"id": id, "name_key": m.name_key, "predicat": ef.predicat_structure,
					"bonus": ef.bonus_structure, "ticks_rendus": float(ef.get("echec_ticks_rendus", 0.5))})
				plan.ticks += int(m.get("surcout_ticks", 0))
			"liaison":
				plan.ticks += int(m.get("surcout_ticks", 0))
				var ef: Dictionary = m.get("effet", {})
				if ef.is_empty():
					plan.avertissements.append("liaison non résolue dans le prototype : " + id)
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
		_:
			res.append(cible)
	return res
