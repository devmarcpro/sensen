extends Node
## GameData — charge et indexe tout `data/` au boot, valide les schémas, expose les catalogues.
## Règles : docs/08 - Technique/Décision — Pipeline de contenu.md · Décisions d'architecture.md
##   · un fichier = une entrée, l'id est le nom du fichier ; les fichiers `_*` sont ignorés ;
##   · validation `fichier → champ → erreur`, BLOQUANTE en debug, warning en release ;
##   · le menu recharge tout sans relancer (signal `donnees_rechargees`) ;
##   · les systèmes lisent des tags et des champs, jamais des ids : `entree()` et `par_tag()`.
## Les textes passent par `tr()` : les CSV de `locale/` sont chargés ici (Localisation).

signal donnees_rechargees

const RACINE := "res://data/"
const RACINE_LOCALE := "res://locale/"
## Collections (un fichier par entrée) — une ligne ici = un catalogue (règle 5 du pipeline).
const CATALOGUES: Array[String] = [
	"modules", "creatures", "creature_actions", "ai_profiles", "functionalities",
	"items", "status_effects", "prototype_arenas", "rigs", "tutorials",
	"dungeon_rooms", "dungeon_connectors", "dungeon_themes", "affixes", "competences", "races", "classes",
	"materials", "stations", "recipes", "components", "component_recipes", "meubles", "biomes", "vegetaux", "weather_states",
	"functions", "dialogue", "name_cultures", "village_buildings", "quest_templates", "plants", "governments", "guilds", "shop_types", "species", "talents",
]
## Tags dérivés des stats d'un matériau au seuil ≥ 50 (Schéma matériau).
const TAGS_DERIVES := {"flammabilite": "inflammable", "conductivite_mana": "conducteur_mana", "flottabilite": "flottant",
	"isolation": "isolant", "luminosite": "luminescent", "transparence": "transparent", "conductivite_electrique": "conducteur"}
## Vecteur Wu Xing par catégorie quand le matériau n'a pas de surcharge (Décision — Surcharges Wu Xing).
const WUXING_CATEGORIE := {"metal": {"metal": 1.0}, "bois": {"bois": 1.0}, "vegetal": {"bois": 1.0}, "roche": {"terre": 1.0},
	"terre": {"terre": 1.0}, "mineral": {"terre": 1.0}, "fossile": {"terre": 1.0}, "gemme": {"terre": 1.0},
	"liquide": {"eau": 1.0}, "meteorologique": {"eau": 1.0}, "synthetique": {"terre": 1.0}}
## Configurations (fichier unique à la racine de data/).
const CONFIGS: Array[String] = ["combat_rules", "tile_contents", "wuxing", "palette_materiaux", "loot_rules", "rare_epithets", "reading_failures", "astrologie", "material_categories", "minerais_par_etage", "material_families", "camp", "noise_layers", "planete", "absurd_laws_pool"]

var catalogues: Dictionary = {}   # nom → { id → Dictionary }
var configs: Dictionary = {}      # nom → Dictionary
var erreurs: Array[String] = []
var avertissements: Array[String] = []
var _cles_locale: Dictionary = {} # clés de traduction connues (validation des name_key)
var _cache_filtres: Dictionary = {} # filtre de catégorie → ids (vidé au rechargement)


func _ready() -> void:
	_installer_police()
	charger()


# Le rechargement à chaud passe par le menu (Tab → Débogage : recharger les données) — plus de touche F5 (contrôles tranchés le 2026-08-28).


## Recharge tout. Bloquant en debug si une erreur de schéma est trouvée.
func charger() -> void:
	erreurs.clear()
	avertissements.clear()
	catalogues.clear()
	configs.clear()
	_cache_filtres.clear()
	_charger_locales()
	for nom in CATALOGUES:
		catalogues[nom] = _charger_dossier(nom)
	for nom in CONFIGS:
		configs[nom] = _charger_config(nom)
	_finir_materiaux()
	_deriver_recettes_objets()
	_verifier_craft()
	_rapport()


## Un objet fini qui porte `recipe.inputs` (meuble, station) DIT lui-même ce qu'il coûte : sa recette est
## dérivée ici, sous son propre id, au lieu d'exister comme un 33e fichier « meuble_x → meuble_x » à tenir à la
## main (Craft compositionnel — le coût est une propriété de la chose, pas une recette nommée à part).
func _deriver_recettes_objets() -> void:
	for id in catalogues.get("items", {}).keys():
		var it: Dictionary = catalogues.items[id]
		var rc: Dictionary = it.get("recipe", {})
		if it.has("slots") or not rc.has("inputs"):
			continue   # les objets à slots passent par l'assemblage de composants
		if catalogues.recipes.has(id):
			erreurs.append("items/%s.json → recipe → une recette plate du même nom existe déjà dans recipes/" % id)
			continue
		catalogues.recipes[id] = {"id": id, "name_key": str(it.name_key), "station": str(rc.station),
			"craft_skill": str(rc.craft_skill), "inputs": rc.inputs, "output": {"item": id, "amount": int(rc.get("amount", 1))},
			"fuel": null, "derivee": true}


## Craft compositionnel : chaque recette de composant vise un composant, une famille et une station
## connus (le laminoir du palier industriel est toléré) ; chaque objet à slots vise des composants connus.
func _verifier_craft() -> void:
	var fam: Dictionary = configs.get("material_families", {})
	for id in catalogues.get("component_recipes", {}).keys():
		var r: Dictionary = catalogues.component_recipes[id]
		if not catalogues.components.has(r.component):
			erreurs.append("component_recipes/%s.json → component → « %s » inconnu" % [id, r.component])
		if not fam.has(r.material_family):
			erreurs.append("component_recipes/%s.json → material_family → « %s » absente de material_families.json" % [id, r.material_family])
		if not catalogues.stations.has(r.station) and r.station != "laminoir":
			erreurs.append("component_recipes/%s.json → station → « %s » inconnue" % [id, r.station])
	for id in catalogues.get("items", {}).keys():
		var it: Dictionary = catalogues.items[id]
		for slot in it.get("slots", {}).keys():
			if not catalogues.components.has(it.slots[slot]):
				erreurs.append("items/%s.json → slots.%s → composant « %s » inconnu" % [id, slot, it.slots[slot]])


## Matériaux (Schéma matériau) : couleur unique, tags dérivés au seuil 50, vecteur Wu Xing résolu,
## catégorie connue et compétence de récolte existante.
func _finir_materiaux() -> void:
	var couleurs := {}
	var cats: Dictionary = configs.get("material_categories", {})
	for id in catalogues.get("materials", {}).keys():
		var m: Dictionary = catalogues.materials[id]
		var fichier := "materials/%s.json" % id
		if couleurs.has(m.color):
			erreurs.append("%s → color → « %s » déjà prise par %s" % [fichier, m.color, couleurs[m.color]])
		couleurs[m.color] = id
		if not cats.has(m.category):
			erreurs.append("%s → category → « %s » absente de material_categories.json" % [fichier, m.category])
		var tags: Array = m.tags
		for stat in TAGS_DERIVES.keys():
			if int(m.stats.get(stat, 0)) >= 50 and not TAGS_DERIVES[stat] in tags:
				tags.append(TAGS_DERIVES[stat])
		if m.get("wuxing") == null:
			m["wuxing"] = WUXING_CATEGORIE.get(m.category, {"terre": 1.0}).duplicate()
		var skill: Variant = m.harvest.get("skill")
		if skill != null and not catalogues.get("competences", {}).has(skill):
			erreurs.append("%s → harvest.skill → compétence « %s » inconnue" % [fichier, str(skill)])


# ---------------------------------------------------------------- accès

## L'entrée `id` du catalogue, ou un dictionnaire vide (erreur signalée).
func entree(catalogue: String, id: String) -> Dictionary:
	var cat: Dictionary = catalogues.get(catalogue, {})
	if not cat.has(id):
		push_error("GameData : %s/%s introuvable" % [catalogue, id])
		return {}
	return cat[id]


func existe(catalogue: String, id: String) -> bool:
	return catalogues.get(catalogue, {}).has(id)


## Toutes les entrées d'un catalogue portant le tag.
func par_tag(catalogue: String, tag: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for e: Dictionary in catalogues.get(catalogue, {}).values():
		if tag in e.get("tags", []):
			res.append(e)
	return res


## Les **ids** qui répondent à un filtre de catégorie — le seul moyen correct de désigner « toutes les armes
## de prototype » ou « tous les consommables sauf les parties de bête » (Data-driven design : les systèmes
## lisent des tags et des champs, jamais des listes d'ids écrites à la main).
## Filtre : `types_any`, `tags_any`, `tags_all`, `tags_none`, `exclut`. Résultat trié (déterministe) et mis en cache.
func filtrer(catalogue: String, filtre: Dictionary) -> Array[String]:
	var cle := catalogue + ":" + JSON.stringify(filtre)
	if _cache_filtres.has(cle):
		return _cache_filtres[cle]
	var types: Array = filtre.get("types_any", [])
	var t_any: Array = filtre.get("tags_any", [])
	var t_all: Array = filtre.get("tags_all", [])
	var t_non: Array = filtre.get("tags_none", [])
	var exclut: Array = filtre.get("exclut", [])
	var cats_mat: Array = filtre.get("categories_materiau", [])   # metal, bois, vegetal… (Catégories de matériaux)
	var res: Array[String] = []
	for id in catalogues.get(catalogue, {}).keys():
		var e: Dictionary = catalogues[catalogue][id]
		if id in exclut:
			continue
		if not types.is_empty() and not (str(e.get("type", "")) in types):
			continue
		var tags: Array = e.get("tags", [])
		if not t_any.is_empty():
			var trouve := false
			for t in t_any:
				if t in tags:
					trouve = true
			if not trouve:
				continue
		var manque := false
		for t in t_all:
			if not (t in tags):
				manque = true
		for t in t_non:
			if t in tags:
				manque = true
		if manque:
			continue
		if not cats_mat.is_empty():
			var m: Dictionary = catalogues.get("materials", {}).get(str(e.get("materiau", "")), {})
			if not (str(m.get("category", "")) in cats_mat):
				continue
		res.append(str(id))
	res.sort()
	_cache_filtres[cle] = res
	return res


## Un id tiré au hasard parmi ceux qui répondent au filtre ("" si le filtre ne matche rien).
func tirer(catalogue: String, filtre: Dictionary, rng: RandomNumberGenerator) -> String:
	var ids := filtrer(catalogue, filtre)
	if ids.is_empty():
		return ""
	return ids[rng.randi_range(0, ids.size() - 1)]


## Une règle chiffrée, par chemin : `regle("combat_rules/endurance/max")`.
func regle(chemin: String) -> Variant:
	var parts := chemin.split("/")
	var v: Variant = configs.get(parts[0], {})
	for i in range(1, parts.size()):
		if not (v is Dictionary) or not v.has(parts[i]):
			push_error("GameData : règle « %s » introuvable" % chemin)
			return null
		v = v[parts[i]]
	return v


func config(nom: String) -> Dictionary:
	return configs.get(nom, {})


# ---------------------------------------------------------------- chargement

func _charger_dossier(nom: String) -> Dictionary:
	var res := {}
	var chemin := RACINE + nom
	var dir := DirAccess.open(chemin)
	if dir == null:
		avertissements.append("%s : dossier absent" % nom)
		return res
	var schema := _charger_schema(nom)
	_charger_recursif(nom, "", schema, res)
	return res


## Un catalogue peut être **rangé en sous-dossiers** (data/modules/noyau/…) : l'id reste le nom du fichier,
## le sous-dossier n'est qu'un classement pour l'humain (décision du designer, 2026-08-29).
func _charger_recursif(nom: String, sous: String, schema: Dictionary, res: Dictionary) -> void:
	var chemin := RACINE + nom + sous
	var dir := DirAccess.open(chemin)
	if dir == null:
		return
	for d2 in dir.get_directories():
		if not d2.begins_with("_"):
			_charger_recursif(nom, sous + "/" + d2, schema, res)
	for f in dir.get_files():
		if not f.ends_with(".json") or f.begins_with("_"):
			continue
		var fichier := "%s%s/%s" % [nom, sous, f]
		var d: Variant = _lire_json(chemin + "/" + f, fichier)
		if not (d is Dictionary):
			continue
		var id := f.trim_suffix(".json")
		if d.has("id") and d["id"] != id:
			erreurs.append("%s → id → « %s » ne correspond pas au nom du fichier" % [fichier, d["id"]])
		if res.has(id):
			erreurs.append("%s → deux fichiers portent l'id « %s » dans le catalogue" % [fichier, id])
		d["id"] = id
		d.erase("_doc")
		if not schema.is_empty():
			_valider(d, schema, "", fichier)
		if d.has("name_key"):
			_verifier_cle(d["name_key"], fichier)
		if d.has("text_key"):
			_verifier_cle(d["text_key"], fichier)
		res[id] = d


func _charger_config(nom: String) -> Dictionary:
	var fichier := nom + ".json"
	var d: Variant = _lire_json(RACINE + fichier, fichier)
	if not (d is Dictionary):
		return {}
	_purger_docs(d)
	var schema := _charger_schema(nom)
	if not schema.is_empty():
		_valider(d, schema, "", fichier)
	return d


func _charger_schema(nom: String) -> Dictionary:
	var p := RACINE + "schemas/" + nom + ".schema.json"
	if not FileAccess.file_exists(p):
		avertissements.append("%s : aucun schéma (%s)" % [nom, p])
		return {}
	var s: Variant = _lire_json(p, "schemas/" + nom)
	return s if s is Dictionary else {}


func _lire_json(chemin: String, fichier: String) -> Variant:
	var texte := FileAccess.get_file_as_string(chemin)
	if texte.is_empty():
		erreurs.append("%s → fichier illisible ou vide" % fichier)
		return null
	var json := JSON.new()
	if json.parse(texte) != OK:
		erreurs.append("%s → ligne %d → %s" % [fichier, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _purger_docs(d: Variant) -> void:
	if d is Dictionary:
		d.erase("_doc")
		for v in d.values():
			_purger_docs(v)
	elif d is Array:
		for v in d:
			_purger_docs(v)


# ---------------------------------------------------------------- validation (sous-ensemble de JSON Schema)

func _type_ok(v: Variant, t: String) -> bool:
	match t:
		"object": return v is Dictionary
		"array": return v is Array
		"string": return v is String
		"number": return v is float or v is int
		"integer": return v is int or (v is float and v == floorf(v))
		"boolean": return v is bool
		"null": return v == null
	return true


func _valider(v: Variant, schema: Dictionary, chemin: String, fichier: String) -> void:
	var ou := chemin if not chemin.is_empty() else "(racine)"
	if schema.has("type"):
		var types: Array = schema["type"] if schema["type"] is Array else [schema["type"]]
		var ok := false
		for t in types:
			if _type_ok(v, t):
				ok = true
		if not ok:
			erreurs.append("%s → %s → type attendu %s" % [fichier, ou, str(types)])
			return
	if schema.has("enum") and not (v in schema["enum"]):
		erreurs.append("%s → %s → valeur « %s » hors de %s" % [fichier, ou, str(v), str(schema["enum"])])
	if v is float or v is int:
		if schema.has("minimum") and v < schema["minimum"]:
			erreurs.append("%s → %s → %s < minimum %s" % [fichier, ou, str(v), str(schema["minimum"])])
		if schema.has("maximum") and v > schema["maximum"]:
			erreurs.append("%s → %s → %s > maximum %s" % [fichier, ou, str(v), str(schema["maximum"])])
	if v is Dictionary:
		for champ in schema.get("required", []):
			if not v.has(champ):
				erreurs.append("%s → %s → champ « %s » manquant" % [fichier, ou, champ])
		var props: Dictionary = schema.get("properties", {})
		for k in v.keys():
			var sous := chemin + "/" + str(k) if not chemin.is_empty() else str(k)
			if props.has(k):
				_valider(v[k], props[k], sous, fichier)
			elif schema.get("additionalProperties", true) is Dictionary:
				_valider(v[k], schema["additionalProperties"], sous, fichier)
	if v is Array:
		if schema.has("minItems") and v.size() < schema["minItems"]:
			erreurs.append("%s → %s → %d éléments, minimum %d" % [fichier, ou, v.size(), schema["minItems"]])
		if schema.has("maxItems") and v.size() > schema["maxItems"]:
			erreurs.append("%s → %s → %d éléments, maximum %d" % [fichier, ou, v.size(), schema["maxItems"]])
		if schema.has("items"):
			for i in v.size():
				_valider(v[i], schema["items"], "%s[%d]" % [chemin, i], fichier)


func _verifier_cle(cle: String, fichier: String) -> void:
	# Clé manquante = warning + affichage de la clé brute, jamais de crash (Localisation).
	if not _cles_locale.has(cle):
		avertissements.append("%s → name_key « %s » absente de locale/fr.csv" % [fichier, cle])


# ---------------------------------------------------------------- locales

func _charger_locales() -> void:
	_cles_locale.clear()
	var dir := DirAccess.open(RACINE_LOCALE)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".csv"):
			continue
		var fa := FileAccess.open(RACINE_LOCALE + f, FileAccess.READ)
		if fa == null:
			continue
		var entete := fa.get_csv_line()
		var traductions: Array[Translation] = []
		for i in range(1, entete.size()):
			var t := Translation.new()
			t.locale = entete[i]
			traductions.append(t)
		while not fa.eof_reached():
			var ligne := fa.get_csv_line()
			if ligne.size() < 2 or ligne[0].is_empty():
				continue
			if f == "fr.csv":
				_cles_locale[ligne[0]] = true
			for i in range(1, mini(ligne.size(), entete.size())):
				traductions[i - 1].add_message(ligne[0], ligne[i])
		for t in traductions:
			TranslationServer.add_translation(t)
	TranslationServer.set_locale("fr")


## Un nom propre généré devient une clé de traduction : tout ce qui affiche `name_key` affiche le nom.
var _traduction_dynamique: Translation = null
func enregistrer_nom(cle: String, texte: String) -> void:
	if _traduction_dynamique == null:
		_traduction_dynamique = Translation.new()
		_traduction_dynamique.locale = "fr"
		TranslationServer.add_translation(_traduction_dynamique)
	_traduction_dynamique.add_message(cle, texte)


# ---------------------------------------------------------------- rapport

func _rapport() -> void:
	var n := 0
	for c in catalogues.values():
		n += c.size()
	print("GameData : %d entrées dans %d catalogues, %d configurations, %d clés de traduction" % [
		n, catalogues.size(), configs.size(), _cles_locale.size()])
	if not avertissements.is_empty():
		push_warning("GameData : %d avertissement(s) — détail ci-dessous" % avertissements.size())
		for a in avertissements:
			print("  avertissement : " + a)
	for e in erreurs:
		push_error("GameData : " + e)
	if not erreurs.is_empty() and OS.is_debug_build():
		# Bloquant en debug (Décision — Pipeline de contenu, règle 3).
		printerr("GameData : %d erreur(s) de données — arrêt (bloquant en debug)" % erreurs.size())
		get_tree().quit(1)


## La police du jeu (Écrans d'interface, décision du 2026-08-30) : MingLiU-ExtB, police **système** — aucun asset dans
## le dépôt. Posée en police de repli du thème (tous les draw_string du client) et sur le thème de la fenêtre racine
## (tous les Control). Si la famille manque sur la machine, Godot garde sa police par défaut.
func _installer_police() -> void:
	var police := SystemFont.new()
	police.font_names = PackedStringArray(["MingLiU-ExtB", "MingLiU_HKSCS-ExtB", "PMingLiU-ExtB"])
	police.allow_system_fallback = true
	police.antialiasing = TextServer.FONT_ANTIALIASING_NONE   # le tracé bitmap de MingLiU, net
	police.hinting = TextServer.HINTING_NORMAL
	police.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	ThemeDB.fallback_font = police
	# Le thème par défaut porte sa propre police : les Control sous un Node2D ou un CanvasLayer n'ont pas de
	# propriétaire de thème (seuls Control et Window propagent), le thème de la fenêtre racine ne les atteint pas.
	var defaut := ThemeDB.get_default_theme()
	if defaut != null:
		defaut.default_font = police

