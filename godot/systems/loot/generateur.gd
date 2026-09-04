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
	# Le plafond etait ECRIT EN DUR : `mini(profondeur, 4)`. Ajouter des lignes a la table ne servait
	# donc a rien — un donjon de niveau 90 tirait sa rarete sur la ligne du niveau 4, et la rarete du
	# butin etait plate de bout en bout (mesure du 2026-09-03 : 15 % d'exceptionnel au niveau 5 comme au
	# niveau 90). C'est aussi un nombre de gameplay en dur, ce que les contraintes du projet interdisent.
	# On prend desormais la plus haute ligne que la TABLE declare, et le plafond redevient une donnee.
	var plafond := 0
	for k in table.keys():
		if str(k).is_valid_int():
			plafond = maxi(plafond, int(k))
	var cle := str(mini(profondeur, plafond))
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
		var candidats := valides.filter(func(a: Dictionary) -> bool: return not pris.has(a.id) and not ("tres_rare" in a.tags and not (rarete in ["exceptionnel", "artefact"])) and not ("rare" in a.tags and rarete in ["commun", "inhabituel"]) and not ("artefact_seulement" in a.tags and rarete != "artefact"))
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
	# Un parchemin porte un sort déjà composé (designer 2026-09-02).
	if base.get("type", "") == "parchemin":
		_composer_parchemin(inst, profondeur, rng)
	return inst


## Un parchemin : une portée, une forme, un noyau — parfois un modificateur — et ses charges. Le sort est
## prêt à partir, gratuitement ; la profondeur décide du nombre de charges et de la générosité.
func _composer_parchemin(inst: Dictionary, profondeur: int, rng: RandomNumberGenerator) -> void:
	var cfg: Dictionary = GameData.config("loot_rules").get("parchemins", {})
	var par_type := {"portee": [], "forme": [], "noyau": [], "modificateur": []}
	var ids: Array = GameData.catalogues.modules.keys()
	ids.sort()
	for mid in ids:
		var t := str(GameData.catalogues.modules[mid].get("module_type", ""))
		if par_type.has(t):
			par_type[t].append(str(mid))
	if par_type.forme.is_empty() or par_type.noyau.is_empty():
		return
	var seq: Array = []
	if not par_type.portee.is_empty():
		seq.append(str(par_type.portee[rng.randi_range(0, par_type.portee.size() - 1)]))
	seq.append(str(par_type.forme[rng.randi_range(0, par_type.forme.size() - 1)]))
	seq.append(str(par_type.noyau[rng.randi_range(0, par_type.noyau.size() - 1)]))
	var chance_mod := float(cfg.get("chance_modificateur", 0.35)) + float(profondeur) * float(cfg.get("chance_modificateur_par_etage", 0.1))
	if not par_type.modificateur.is_empty() and rng.randf() < chance_mod:
		seq.append(str(par_type.modificateur[rng.randi_range(0, par_type.modificateur.size() - 1)]))
	inst["modules"] = seq
	inst["charges"] = clampi(int(round(float(cfg.get("charges_base", 1)) + float(profondeur) * float(cfg.get("charges_par_etage", 0.5)))), 1, int(cfg.get("charges_max", 5)))
	var noyau_id := str(seq[seq.size() - 1]) if seq.size() > 0 else ""
	for m in seq:
		if str(GameData.catalogues.modules[str(m)].get("module_type", "")) == "noyau":
			noyau_id = str(m)
	inst["nom"] = {"affixe": "", "params": {}, "parchemin": {"module": str(GameData.catalogues.modules[noyau_id].get("name_key", noyau_id)), "charges": int(inst.charges)}}


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
	if "trame" in base.get("tags", []):   # une trame apprend une GRILLE (designer 2026-09-04) : n'importe laquelle du catalogue, sauf la poche
		var ids_g: Array = GameData.catalogues.get("grilles", {}).keys()
		ids_g.sort()
		var pool_g: Array = []
		for gid in ids_g:
			if str(gid) != str(regles.get("grille_poche", "poche")):
				pool_g.append(str(gid))
		inst["grille"] = str(pool_g[rng.randi_range(0, pool_g.size() - 1)]) if not pool_g.is_empty() else ""
		inst["modules"] = []
		inst["difficulte"] = int(lv.difficulte_base) + maxi(0, profondeur - 1) * int(lv.difficulte_par_etage) / 2
		inst["nom"] = {"affixe": "", "params": {"grille": str(GameData.catalogues.get("grilles", {}).get(inst.grille, {}).get("name_key", ""))}}
		return
	if "plan" in base.get("tags", []):   # un plan industriel (Palier industriel) : une recette industrielle, pas de modules
		var indus: Array = []
		var ids_r: Array = GameData.catalogues.recipes.keys()
		ids_r.sort()
		for rid in ids_r:
			if bool(GameData.catalogues.recipes[rid].get("industrielle", false)):
				indus.append(str(rid))
		inst["recette"] = str(indus[rng.randi_range(0, indus.size() - 1)]) if not indus.is_empty() else ""
		inst["difficulte"] = int(lv.difficulte_base) + maxi(0, profondeur - 2) * int(lv.difficulte_par_etage)
		inst["modules"] = []
		inst["domaine"] = "industriel"
		inst["nom"] = {"affixe": "", "params": {"recette": GameData.catalogues.recipes.get(inst.recette, {}).get("name_key", "")}}
		return
	# Tout livre n'enseigne qu'UN module (designer 2026-08-31) : le grimoire comme le manuel.
	# Le domaine reste ce qui les distingue — un grimoire tire dans les modules de magie,
	# un manuel dans ceux du corps — et la difficulté suit la profondeur.
	var ids_m: Array = modules.keys()
	ids_m.sort()
	var grimoire: bool = base.type == "grimoire"
	var pool: Array = []
	for id: String in ids_m:
		var md: Dictionary = modules[id]
		var magique: bool = not Dictionary(md.get("elements", {})).is_empty() or int(md.get("cout_mana", 0)) > 0
		if "module_unique" in base.get("tags", []) or (grimoire == magique):
			pool.append(id)
	if pool.is_empty():
		pool = ids_m
	var choisi_m := str(pool[rng.randi_range(0, pool.size() - 1)])
	inst["modules"] = [choisi_m]
	inst["domaine"] = str(modules[choisi_m].get("module_type", "noyau"))
	inst["difficulte"] = int(lv.difficulte_base) + maxi(0, profondeur - 1) * int(lv.difficulte_par_etage) / 2
	inst["nom"] = {"affixe": "", "params": {}, "module": str(modules[choisi_m].get("name_key", choisi_m))}


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
			if nom == "vers" and str(res[nom]) == str(res.get("element", "")):   # transmutation : deux éléments distincts
				res[nom] = elements[(elements.find(res[nom]) + 1) % elements.size()]
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
func _base_pour(rng: RandomNumberGenerator, profondeur: int = 99, affixable: bool = false) -> String:
	# La profondeur décide de ce qui PEUT sortir (designer 2026-09-02) : chaque catégorie porte sa
	# `profondeur_min`. Les stations, les meubles et les bijoux se méritent en descendant.
	var lr: Dictionary = regles.contenants
	var cats: Dictionary = lr.categories
	var ouvertes: Array = []
	for c in cats.keys():
		if affixable and not bool(cats[c].get("affixable", false)):
			continue   # un drop à affixes ne tire que dans ce qui peut en porter : pas un lingot, pas un lit
		if profondeur >= int(cats[c].get("profondeur_min", 0)):
			ouvertes.append(str(c))
	if ouvertes.is_empty():
		ouvertes = cats.keys()
	var total := 0.0
	for c in ouvertes:
		total += float(cats[c].poids)
	var t := rng.randf() * total
	var cat := str(ouvertes[0])
	for c in ouvertes:
		t -= float(cats[c].poids)
		if t < 0.0:
			cat = str(c)
			break
	# Une CATÉGORIE, pas une liste d'ids : tout objet qui répond au filtre entre dans le loot du jour où il existe.
	var choisi := GameData.tirer("items", cats[cat].filtre, rng)
	if choisi.is_empty():
		choisi = GameData.tirer("items", cats[cats.keys()[0]].filtre, rng)
	return choisi


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
