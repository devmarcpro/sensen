extends Node
## GameData — charge et indexe tout `data/` au boot, valide les schémas, expose les catalogues.
## Règles : docs/08 - Technique/Décision — Pipeline de contenu.md · Décisions d'architecture.md
##   · un fichier = une entrée, l'id est le nom du fichier ; les fichiers `_*` sont ignorés ;
##   · validation `fichier → champ → erreur`, BLOQUANTE en debug, warning en release ;
##   · F5 recharge tout sans relancer (signal `donnees_rechargees`) ;
##   · les systèmes lisent des tags et des champs, jamais des ids : `entree()` et `par_tag()`.
## Les textes passent par `tr()` : les CSV de `locale/` sont chargés ici (Localisation).

signal donnees_rechargees

const RACINE := "res://data/"
const RACINE_LOCALE := "res://locale/"
## Collections (un fichier par entrée) — une ligne ici = un catalogue (règle 5 du pipeline).
const CATALOGUES: Array[String] = [
	"modules", "creatures", "creature_actions", "ai_profiles", "functionalities",
	"items", "status_effects", "prototype_arenas", "rigs", "tutorials",
	"dungeon_rooms", "dungeon_connectors", "dungeon_themes", "affixes",
]
## Configurations (fichier unique à la racine de data/).
const CONFIGS: Array[String] = ["combat_rules", "tile_contents", "wuxing", "palette_materiaux", "loot_rules"]

var catalogues: Dictionary = {}   # nom → { id → Dictionary }
var configs: Dictionary = {}      # nom → Dictionary
var erreurs: Array[String] = []
var avertissements: Array[String] = []
var _cles_locale: Dictionary = {} # clés de traduction connues (validation des name_key)


func _ready() -> void:
	charger()


func _unhandled_input(ev: InputEvent) -> void:
	# Rechargement à chaud en debug (Décisions d'architecture : F5 recharge les données).
	if OS.is_debug_build() and ev is InputEventKey and ev.pressed and ev.keycode == KEY_F5:
		charger()
		donnees_rechargees.emit()


## Recharge tout. Bloquant en debug si une erreur de schéma est trouvée.
func charger() -> void:
	erreurs.clear()
	avertissements.clear()
	catalogues.clear()
	configs.clear()
	_charger_locales()
	for nom in CATALOGUES:
		catalogues[nom] = _charger_dossier(nom)
	for nom in CONFIGS:
		configs[nom] = _charger_config(nom)
	_rapport()


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
	for f in dir.get_files():
		if not f.ends_with(".json") or f.begins_with("_"):
			continue
		var fichier := "%s/%s" % [nom, f]
		var d: Variant = _lire_json(chemin + "/" + f, fichier)
		if not (d is Dictionary):
			continue
		var id := f.trim_suffix(".json")
		if d.has("id") and d["id"] != id:
			erreurs.append("%s → id → « %s » ne correspond pas au nom du fichier" % [fichier, d["id"]])
		d["id"] = id
		d.erase("_doc")
		if not schema.is_empty():
			_valider(d, schema, "", fichier)
		if d.has("name_key"):
			_verifier_cle(d["name_key"], fichier)
		if d.has("text_key"):
			_verifier_cle(d["text_key"], fichier)
		res[id] = d
	return res


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
