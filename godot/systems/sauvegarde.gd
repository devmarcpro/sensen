class_name Sauvegarde
extends RefCounted
## La sauvegarde (Sauvegarde, E.10) : **seed + liste des modifications**. Un dossier par monde sous
## `user://sauvegardes/<nom>/` : `world.json` (graine, temps, compteurs), `surface.json` (par cellule :
## modifications, tuiles découvertes, contenants, êtres endormis — jamais ce qui se regénère),
## `entities.json` (les êtres de la fenêtre courante et leurs contenants), `items.json` (les instances
## d'objets), `players/joueur.json` (la fiche et l'être du joueur). Écriture atomique (tmp + rename).
## JSON plutôt que .bin tant qu'on prototype (décision du 2026-08-28) ; les Vector2i et les clés non
## textuelles sont encodés explicitement pour rester relisibles.

const RACINE := "user://sauvegardes/"


## Encode récursivement : Vector2i → {"_v2i": [x, y]}, dictionnaire à clés non textuelles → {"_dict": [[k, v]…]}.
static func encoder(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2I:
			return {"_v2i": [v.x, v.y]}
		TYPE_VECTOR2:
			return {"_v2": [v.x, v.y]}
		TYPE_DICTIONARY:
			var textuel := true
			for k in v.keys():
				if typeof(k) != TYPE_STRING and typeof(k) != TYPE_STRING_NAME:
					textuel = false
					break
			if textuel:
				var d := {}
				for k in v.keys():
					d[str(k)] = encoder(v[k])
				return d
			var paires := []
			for k in v.keys():
				paires.append([encoder(k), encoder(v[k])])
			return {"_dict": paires}
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var a := []
			for x in v:
				a.append(encoder(x))
			return a
		TYPE_PACKED_BYTE_ARRAY:
			return {"_bytes": Marshalls.raw_to_base64(v)}
		TYPE_PACKED_INT32_ARRAY:
			return {"_i32": Array(v)}
		TYPE_STRING_NAME:
			return str(v)
		_:
			return v


static func decoder(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			if v.has("_v2i"):
				return Vector2i(int(v._v2i[0]), int(v._v2i[1]))
			if v.has("_v2"):
				return Vector2(float(v._v2[0]), float(v._v2[1]))
			if v.has("_bytes"):
				return Marshalls.base64_to_raw(str(v._bytes))
			if v.has("_i32"):
				return PackedInt32Array(v._i32)
			if v.has("_dict"):
				var d := {}
				for paire in v._dict:
					d[decoder(paire[0])] = decoder(paire[1])
				return d
			var d2 := {}
			for k in v.keys():
				d2[k] = decoder(v[k])
			return d2
		TYPE_ARRAY:
			var a := []
			for x in v:
				a.append(decoder(x))
			return a
		TYPE_FLOAT:
			# JSON ne distingue pas 3 de 3.0 : les entiers reviennent en float — on les rend entiers quand ils le sont.
			return int(v) if v == floorf(v) and absf(v) < 1e15 else v
		_:
			return v


static func ecrire(nom: String, fichier: String, donnees: Variant) -> bool:
	var dossier := RACINE + nom + "/"
	var cible := dossier + fichier
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cible.get_base_dir()))
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("Sauvegarde : dossier impossible " + cible.get_base_dir())
		return false
	var tmp := cible + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Sauvegarde : impossible d'écrire %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(encoder(donnees), "", false, true))
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_cible := ProjectSettings.globalize_path(cible)
	if FileAccess.file_exists(cible):
		DirAccess.remove_absolute(abs_cible)
	var r := DirAccess.rename_absolute(abs_tmp, abs_cible)
	if r != OK:
		push_error("Sauvegarde : rename %s → %s : %s" % [abs_tmp, abs_cible, error_string(r)])
	return r == OK


static func lire(nom: String, fichier: String) -> Variant:
	var chemin := RACINE + nom + "/" + fichier
	if not FileAccess.file_exists(chemin):
		return null
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return null
	var texte := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(texte) != OK:
		push_error("Sauvegarde : %s illisible (%s)" % [chemin, j.get_error_message()])
		return null
	return decoder(j.data)


static func existe(nom: String) -> bool:
	return FileAccess.file_exists(RACINE + nom + "/world.json")
