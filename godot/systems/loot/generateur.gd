class_name Loot
extends RefCounted
## Le générateur de loot (Loot — affixes, gemmes et rareté) : une base d'objet du catalogue,
## une profondeur, un RNG → une INSTANCE avec sa rareté, ses affixes tirés dans leurs fourchettes
## (budget de rareté : le meilleur tiers), ses sertissures, son nom et sa provenance.
## « L'atelier améliore, le donjon transforme » : les affixes n'existent que par ce chemin.

var regles: Dictionary      # loot_rules.json
var affixes: Dictionary     # catalogue data/affixes
var items: Dictionary       # catalogue data/items (les bases)
var elements: Array         # les cinq éléments (wuxing.json)
var modules: Dictionary = {}    # le catalogue des modules (pour les livres)
var _n := 0


func _init(p_regles: Dictionary, p_affixes: Dictionary, p_items: Dictionary, p_elements: Array) -> void:
	regles = p_regles
	affixes = p_affixes
	items = p_items
	elements = p_elements


## La rareté tirée pour une profondeur (grille de rareté suivant l'étage).
func rarete_pour(profondeur: int, rng: RandomNumberGenerator) -> String:
	var table: Dictionary = regles.poids_par_profondeur
	var cle := str(mini(profondeur, 4))
	while not table.has(cle) and int(cle) > 0:
		cle = str(int(cle) - 1)
	var poids: Array = table.get(cle, [70, 25, 5, 0])
	var noms := ["commun", "inhabituel", "rare", "exceptionnel"]
	var total := 0.0
	for p in poids:
		total += float(p)
	var t := rng.randf() * total
	for i in poids.size():
		t -= float(poids[i])
		if t < 0.0:
			return noms[i]
	return "commun"


## Génère une instance depuis une base. `rarete` forcée si non vide ; `nb_affixes` forcé si ≥ 0.
func generer(base_id: String, profondeur: int, rng: RandomNumberGenerator, provenance: Dictionary = {}, rarete: String = "", nb_affixes: int = -1) -> Dictionary:
	var base: Dictionary = items.get(base_id, {})
	if base.is_empty():
		push_error("Loot : base inconnue " + base_id)
		return {}
	if rarete.is_empty():
		rarete = rarete_pour(profondeur, rng)
	var r: Dictionary = regles.raretes[rarete]
	_n += 1
	var inst: Dictionary = base.duplicate(true)
	inst["uid"] = "%s#%d_%d" % [base_id, profondeur, _n + rng.randi() % 1000]
	inst["base"] = base_id
	inst["rarete"] = rarete
	inst["affixes"] = []
	inst["provenance"] = provenance.duplicate()
	inst["tags"] = base.get("tags", []).duplicate()
	inst.tags.append("loot")
	# Affixes : tirés parmi les gabarits valides pour le slot, sans doublon d'id.
	var n := nb_affixes if nb_affixes >= 0 else rng.randi_range(int(r.affixes[0]), int(r.affixes[1]))
	var valides := _affixes_pour(str(base.get("equip_slot", "")))
	var pris := {}
	for k in n:
		var candidats := valides.filter(func(a: Dictionary) -> bool: return not pris.has(a.id) and not ("tres_rare" in a.tags and not (rarete in ["exceptionnel", "artefact"])) and not ("rare" in a.tags and rarete in ["commun", "inhabituel"]))
		if candidats.is_empty():
			break
		var a: Dictionary = candidats[rng.randi_range(0, candidats.size() - 1)]
		pris[a.id] = true
		inst.affixes.append({"id": a.id, "params": _tirer_parametres(a, float(r.budget), rng, float(r.get("depassement", 1.0))), "compteur": 0, "etat": {}})
	if bool(r.get("fini", false)):   # un artefact (Trésors et artefacts) : fini par nature
		inst["fini"] = true
	# Sertissures : des emplacements, éventuellement un occupé (exceptionnel).
	var slots := rng.randi_range(int(r.sertissures[0]), int(r.sertissures[1]))
	if base.get("type", "") in ["arme", "armure", "bijou"] and not bool(r.get("fini", false)):
		inst["sertissures"] = {"nombre": slots, "contenu": []}
	# Nom : tout loot rare+ reçoit un nom généré depuis les paramètres tirés.
	if bool(r.nom) and not inst.affixes.is_empty():
		inst["nom"] = {"affixe": inst.affixes[0].id, "params": inst.affixes[0].params}
	# Une gemme est taillée à la génération : sa spécialisation et sa qualité de taille (A.3).
	if base.get("type", "") == "gemme" and base.has("tailles"):
		_tailler(inst, base, profondeur, rng)
	# Un livre tire son domaine, sa difficulté et ses modules (Grimoires et manuels).
	if base.get("type", "") in ["grimoire", "manuel"]:
		_composer_livre(inst, base, profondeur, rng)
	return inst


## Tailler une gemme CHOISIT sa spécialisation ; la qualité de taille place la valeur dans la fourchette.
func _tailler(inst: Dictionary, base: Dictionary, profondeur: int, rng: RandomNumberGenerator) -> void:
	var qt: Dictionary = regles.gemmes.qualite_taille
	var q: float = clampf(float(qt.base) + float(profondeur) * float(qt.par_etage) + rng.randf() * float(qt.alea), float(qt.min), float(qt.max))
	var t: Dictionary = base.tailles[rng.randi_range(0, base.tailles.size() - 1)]
	var frac: float = clampf((q - float(qt.min)) / (float(qt.max) - float(qt.min)), 0.0, 1.0)
	var lo := float(t.fourchette[0])
	var hi := float(t.fourchette[1])
	var v := lo + (hi - lo) * frac
	var taille: Dictionary = t.duplicate()
	taille.erase("fourchette")
	taille["valeur"] = v if t.type in ["affinite", "qualite"] else float(roundi(v))
	taille["qualite"] = q
	inst["taille"] = taille
	inst["nom"] = {"affixe": "", "params": {}, "taille": taille}


## Un livre : domaine tiré, difficulté par profondeur, 2-4 modules du catalogue filtrés par le domaine.
func _composer_livre(inst: Dictionary, base: Dictionary, profondeur: int, rng: RandomNumberGenerator) -> void:
	var lv: Dictionary = regles.livres
	var grimoire: bool = base.type == "grimoire"
	var domaine := ""
	if grimoire:
		var doms: Array = lv.domaines_grimoire.keys()
		domaine = str(doms[rng.randi_range(0, doms.size() - 1)])
	else:
		domaine = str(lv.domaines_manuel[rng.randi_range(0, lv.domaines_manuel.size() - 1)])
	var candidats: Array[String] = []
	for id: String in modules.keys():
		var m: Dictionary = modules[id]
		if grimoire:
			var el := str(lv.domaines_grimoire[domaine])
			if m.module_type == "noyau":
				var dom_m := _dominante(m.get("elements", {}))
				if int(m.get("cout_mana", 0)) > 0 and (dom_m == el or (el == "neutre" and dom_m.is_empty())):
					candidats.append(id)
			elif m.module_type in ["forme", "modificateur"] and el == "neutre":
				candidats.append(id)
		else:
			match domaine:
				"frappes":
					if m.module_type == "noyau" and int(m.get("cout_endurance", 0)) > 0:
						candidats.append(id)
				"postures":
					if m.module_type == "condition":
						candidats.append(id)
				"techniques":
					if m.module_type in ["declencheur", "liaison"]:
						candidats.append(id)
				"maitrise":
					if m.module_type in ["modificateur", "forme"]:
						candidats.append(id)
	var n := rng.randi_range(int(lv.modules_par_livre[0]), int(lv.modules_par_livre[1]))
	var choisis: Array = []
	while choisis.size() < n and not candidats.is_empty():
		var k := rng.randi_range(0, candidats.size() - 1)
		choisis.append(candidats[k])
		candidats.remove_at(k)
	inst["domaine"] = domaine
	inst["difficulte"] = int(lv.difficulte_base) + profondeur * int(lv.difficulte_par_etage)
	inst["modules"] = choisis
	inst["nom"] = {"affixe": "", "params": {}, "livre": {"domaine": domaine, "difficulte": inst.difficulte, "n": choisis.size()}}


static func _dominante(v: Dictionary) -> String:
	var meilleur := ""
	var part := 0.0
	for k in v.keys():
		if float(v[k]) > part:
			part = float(v[k])
			meilleur = str(k)
	return meilleur


func _affixes_pour(slot: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for a: Dictionary in affixes.values():
		if slot in a.slots_valides:
			res.append(a)
	return res


## Tire chaque paramètre dans sa fourchette ; avec un budget, une chance `budget` de piocher
## dans le meilleur tiers (dans le sens déclaré par `meilleur`).
func _tirer_parametres(a: Dictionary, budget: float, rng: RandomNumberGenerator, depassement: float = 1.0) -> Dictionary:
	var res := {}
	for nom: String in a.parametres.keys():
		var spec: Variant = a.parametres[nom]
		if spec is String and spec == "element":
			res[nom] = elements[rng.randi_range(0, elements.size() - 1)]
		elif spec is Array and spec.size() == 2 and (spec[0] is float or spec[0] is int) and not (spec[0] is String):
			var lo := int(spec[0])
			var hi := int(spec[1])
			var sens: String = a.meilleur.get(nom, "")
			if depassement > 1.0 and not sens.is_empty():   # au-dessus des fourchettes (artefacts)
				if sens == "haut":
					hi = maxi(hi + 1, roundi(float(hi) * depassement))
				else:
					lo = maxi(1, mini(lo - 1, roundi(float(lo) / depassement)))
			if budget > 0.0 and not sens.is_empty() and rng.randf() < budget and hi - lo >= 2:
				var tiers := maxi(1, (hi - lo + 1) / 3)
				if sens == "haut":
					lo = hi - tiers + 1
				else:
					hi = lo + tiers - 1
			res[nom] = rng.randi_range(lo, hi)
		elif spec is Array:
			res[nom] = spec[rng.randi_range(0, spec.size() - 1)]
		else:
			res[nom] = spec
	return res


## Une base d'objet tirée selon les poids de catégorie de `contenants` (armes, armures, bijoux…).
func _base_pour(rng: RandomNumberGenerator) -> String:
	var lr: Dictionary = regles.contenants
	var cats: Dictionary = lr.poids_categories
	var total := 0.0
	for c in cats.keys():
		total += float(cats[c])
	var t := rng.randf() * total
	var cat := "armes"
	for c in cats.keys():
		t -= float(cats[c])
		if t < 0.0:
			cat = c
			break
	var bases: Array = lr.get("bases_" + cat, [])
	if bases.is_empty():
		bases = lr.bases_armes
	return str(bases[rng.randi_range(0, bases.size() - 1)])


## Les affixes d'une instance dont l'effet est d'un type donné (avec leurs paramètres).
static func affixes_de_type(inst: Dictionary, defs: Dictionary, type: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for ax: Dictionary in inst.get("affixes", []):
		var d: Dictionary = defs.get(ax.id, {})
		if d.is_empty() or d.get("inerte", false):
			continue
		if d.effet.type == type:
			res.append({"id": ax.id, "params": ax.params, "effet": d.effet, "instance": ax})
	return res
