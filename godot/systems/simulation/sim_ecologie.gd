class_name SimEcologie
extends RefCounted
## L'ÉCOLOGIE VIVANTE (ordre de travail 22 ter, lot 5 — 2026-09-14). La faune revenait « par génération, jamais par
## reproduction » : tuer des cerfs raréfiait les cerfs, et rien d'autre. Or une forêt est une chaîne. Chaque cellule porte
## maintenant un indice de PROIES et un de PRÉDATEURS, qui se répondent chaque semaine. Personne n'a écrit « les loups
## attaquent les fermes quand on a trop chassé » : c'est ce que donnent deux nombres qui se nourrissent l'un de l'autre.
## Comme pour la faune raréfiée, on ne stocke que l'écart : une cellule à l'équilibre ne coûte rien.

static func _cfg() -> Dictionary:
	return GameData.config("ecologie")


static func indices(sim: Simulation, cell: Vector2i) -> Dictionary:
	if sim.monde == null:
		return {"proies": 1.0, "predateurs": 1.0}
	var d: Dictionary = sim.monde.ecologie.get(cell, {})
	return {"proies": float(d.get("proies", 1.0)), "predateurs": float(d.get("predateurs", 1.0))}


static func _poser(sim: Simulation, cell: Vector2i, proies: float, predateurs: float) -> void:
	var c := _cfg()
	proies = clampf(proies, float(c.get("min", 0.1)), float(c.get("max", 2.0)))
	predateurs = clampf(predateurs, float(c.get("min", 0.1)), float(c.get("max", 2.0)))
	if absf(proies - 1.0) < 0.02 and absf(predateurs - 1.0) < 0.02:
		sim.monde.ecologie.erase(cell)
	else:
		sim.monde.ecologie[cell] = {"proies": proies, "predateurs": predateurs}


## La classe d'une bête : "proie", "predateur" ou "".
static func classe(def_ou_etre: Dictionary) -> String:
	var c := _cfg()
	if not ("bete" in def_ou_etre.get("tags", [])):
		return ""
	var profil := str(def_ou_etre.get("ai_profile", ""))
	if profil in c.get("profils_proies", []):
		return "proie"
	if profil in c.get("profils_predateurs", []):
		return "predateur"
	return ""


## LA CHASSE : une bête tuée déséquilibre sa cellule.
static func chasser(sim: Simulation, bete: Dictionary, pos: Vector2i) -> void:
	if sim.monde == null:
		return
	var def: Dictionary = GameData.catalogues.creatures.get(str(bete.get("def", "")), bete)
	var cl := classe(def)
	if cl.is_empty():
		return
	var cell := sim.monde.cellule_de(pos)
	var i := indices(sim, cell)
	var c := _cfg()
	if cl == "proie":
		_poser(sim, cell, float(i.proies) - float(c.get("chasse_proie", 0.12)), float(i.predateurs))
	else:
		_poser(sim, cell, float(i.proies), float(i.predateurs) - float(c.get("chasse_predateur", 0.2)))


## LA SEMAINE : les deux indices se répondent et reviennent vers l'équilibre. Puis les troupeaux des cellules affamées
## paient leur tribut.
static func semaine(sim: Simulation) -> void:
	if sim.monde == null:
		return
	var c := _cfg()
	# LE TRIBUT SE LÈVE SUR LA FAIM DE LA SEMAINE ÉCOULÉE : les prédateurs qui déclinent ont encore chassé avant de décliner.
	var affamees := {}
	for cell0 in sim.monde.ecologie.keys():
		if affamee(sim, cell0):
			affamees[cell0] = true
	for cell in sim.monde.ecologie.keys().duplicate():
		var i := indices(sim, cell)
		var p := float(i.proies)
		var q := float(i.predateurs)
		var p2 := p + float(c.get("retour", 0.12)) * (1.0 - p) - float(c.get("predation", 0.25)) * (q - 1.0) * p
		var q2 := q + float(c.get("retour", 0.12)) * (1.0 - q) + float(c.get("nourriture", 0.3)) * (p - 1.0) * q
		_poser(sim, cell, p2, q2)
	if sim.lieu != "camp":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "rafle", sim.monde.semaine_courante])
	var n := 0
	for x in sim.vivants():
		if str(x.get("betail", "")).is_empty() or not affamees.has(sim.monde.cellule_de(x.pos)):
			continue
		if rng.randf() < float(c.get("rafle_chance", 0.25)):
			x.vivant = false
			x.sante = 0
			x["mort_tick"] = sim.horloge_monde.ticks
			sim.grille.liberer(x.pos, x.id)
			n += 1
	if n > 0:
		EventBus.emettre(&"journal", [&"journal.rafle_predateurs", {"n": n}])


## Une cellule AFFAMÉE : peu de proies, encore beaucoup de prédateurs — ils sortent de jour et viennent aux troupeaux.
static func affamee(sim: Simulation, cell: Vector2i) -> bool:
	var i := indices(sim, cell)
	var c := _cfg()
	return float(i.proies) < float(c.get("affame_proies", 0.55)) and float(i.predateurs) > float(c.get("affame_predateurs", 0.8))


## Une cellule SURPÂTURÉE : trop de proies — elles ravagent les champs.
static func mult_recolte(sim: Simulation, cell: Vector2i) -> float:
	var c := _cfg()
	return float(c.get("surpature_recolte", 0.8)) if float(indices(sim, cell).proies) > float(c.get("surpature_proies", 1.4)) else 1.0


## Le poids d'une espèce dans le tirage de faune : l'indice de sa classe dans la cellule.
static func poids_espece(sim: Simulation, cell: Vector2i, id: String) -> float:
	var cl := classe(GameData.catalogues.creatures.get(id, {}))
	if cl.is_empty():
		return 1.0
	var i := indices(sim, cell)
	return float(i.proies) if cl == "proie" else float(i.predateurs)


## LA SAISON D'UNE ESPÈCE (lot 10 — 2026-09-14) : l'ours hiberne, l'oie migre, le papillon disparaît au froid. Le poids que
## la saison donne à son tirage, 1 si elle n'appartient à aucun groupe saisonnier.
static func poids_saison(sim: Simulation, id: String) -> float:
	var c := _cfg()
	var s: Dictionary = c.get("saisons", {}).get(SimTerrain.saison(sim), {})
	if s.is_empty():
		return 1.0
	for groupe: String in (c.get("groupes", {}) as Dictionary).keys():
		if id in c.groupes[groupe]:
			return float(s.get(groupe, 1.0))
	return 1.0
