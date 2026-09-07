class_name Noms
extends RefCounted
## Génération de noms (Génération de noms, Noms culturels) : prénom, nom de famille, titre, ville —
## concaténation de pools A + B d'une culture de `data/name_cultures/`, pools de prénom et de famille
## genrés (Pools de noms des cultures, corrigé le 2026-08-26). Une seule fonction d'affichage,
## réutilisée partout. Génération one-shot, stockée comme donnée d'instance.


static func _pick(rng: RandomNumberGenerator, pool: Array) -> String:
	if pool.is_empty():
		return ""
	return str(pool[rng.randi_range(0, pool.size() - 1)])


## Le prénom : un début et une fin (designer 2026-09-07, « fais du syllabique pour tout »). Les pools sont minés sur
## des listes de vrais noms de la culture, coupés à une frontière de syllabe : la saveur reste, et le nombre de noms
## possibles n'a plus de limite — de deux à cinq mille par genre et par culture, au lieu de soixante écrits à la main.
## La séparation homme/femme se joue sur la FIN : aucune désinence n'est dans les deux pools.
static func prenom(culture: Dictionary, genre: String, rng: RandomNumberGenerator) -> String:
	# Le DÉBUT est genré lui aussi : une culture aux noms courts (le chinois) garde ses noms entiers en début, et
	# « Wei » ne doit pas servir à une femme. `prenom_a` reste le repli d'une culture qui ne genre que la fin.
	var debuts: Array = culture.get("prenom_a_f", []) if genre == "f" else culture.get("prenom_a_m", [])
	if debuts.is_empty():
		debuts = culture.prenom_a
	return _pick(rng, debuts) + _pick(rng, culture.prenom_b_f if genre == "f" else culture.prenom_b_m)


## Le nom de famille : même assemblage, SANS genre (designer 2026-09-07 : « un nom de famille n'a pas de sexe »).
## Le patronyme nordique lui-même prend « -sson » pour tous, comme la Suède moderne où une femme est Andersson.
## Le paramètre `genre` reste dans la signature — les appelants le passent — mais il ne décide plus rien.
static func famille(culture: Dictionary, _genre: String, rng: RandomNumberGenerator) -> String:
	return _pick(rng, culture.famille_a) + _pick(rng, culture.famille_b_m)


static func ville(culture: Dictionary, rng: RandomNumberGenerator) -> String:
	return _pick(rng, culture.ville_a) + _pick(rng, culture.ville_b)


## Un nom complet : {prenom, nom_famille, titre (clé ou ""), genre, culture, name_order}.
static func generer(culture_id: String, culture: Dictionary, genre: String, rng: RandomNumberGenerator, titre: String = "") -> Dictionary:
	return {"prenom": prenom(culture, genre, rng), "nom_famille": famille(culture, genre, rng), "titre": titre, "genre": genre,
		"culture": culture_id, "name_order": str(culture.get("name_order", "prenom_nom"))}


## La fonction d'affichage unique : "{titre} {prenom} {nom_famille}" (ou nom puis prénom selon la culture).
static func afficher(nom: Dictionary) -> String:
	var t: String = TranslationServer.translate(str(nom.get("titre", ""))) if not str(nom.get("titre", "")).is_empty() else ""
	var corps: String = ("%s %s" % [nom.nom_famille, nom.prenom]) if str(nom.get("name_order", "prenom_nom")) == "nom_prenom" else ("%s %s" % [nom.prenom, nom.nom_famille])
	return (t + " " + corps).strip_edges()


## La culture d'une race (première culture dont race_affinity la contient), déterministe par graine.
static func culture_pour(race: String, cultures: Dictionary, rng: RandomNumberGenerator) -> String:
	var candidates: Array = []
	var ids: Array = cultures.keys()
	ids.sort()
	for id in ids:
		if cultures[id].get("race_affinity", {}).has(race):
			candidates.append(id)
	if candidates.is_empty():
		candidates = ids
	return str(candidates[rng.randi_range(0, candidates.size() - 1)]) if not candidates.is_empty() else ""
