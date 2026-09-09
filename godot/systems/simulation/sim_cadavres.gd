class_name SimCadavres
extends RefCounted
## LES CADAVRES RESTENT, ET SE DÉMONTENT (ordre de travail 28 ter ; designer 2026-09-08 : « il va falloir faire en
## sorte que les cadavres restent, comme ça le joueur peut loot, faire le nécromancien, récupérer des membres, des
## organes — pour se les greffer, les vendre, les greffer sur un PNJ, construire une chimère »).
##
## **Ce qui existait déjà** : un mort n'est pas effacé, il est sauvegardé, il est dessiné depuis ce matin, et il sent
## dans le champ d'odeur. **Ce qui manquait, et que ce module apporte** : le TEMPS qui passe sur lui, et le fait
## qu'on puisse *en prendre quelque chose*.
##
## **LA POURRITURE NE SE TIQUE PAS.** Un stade se DÉDUIT du temps écoulé depuis `mort_tick` — mille cadavres sur un
## champ de bataille ne coûtent donc pas un pas d'horloge, ils vieillissent en étant lus. C'est la même économie que
## la file des compteurs du monde : *ce qui peut se déduire ne se balaie pas.*
##
## **PRÉLEVER EST À UN COUP PAR PIÈCE.** Le jet est semé sur la dépouille ET sur la partie, jamais sur le tick : on
## ne peut donc pas le rejouer en réessayant, et un échec abîme la pièce pour de bon. Sans cela, prélever serait un
## bouton qu'on presse jusqu'à réussir — et la compétence de chasse ne voudrait plus rien dire.
##
## Ce qu'il ne fait PAS, et qui attend la grammaire des modules (lignes 27-28) : greffer. Une pièce prélevée est
## aujourd'hui un objet — elle se porte, se vend, se cuisine. La reposer sur un corps est une autre ligne.


static func _cfg() -> Dictionary:
	return GameData.config("cadavres")


## Un cadavre est un être qui n'est plus vivant et qui a encore une place dans le monde.
static func est_cadavre(sim: Simulation, x: Dictionary) -> bool:
	return not bool(x.get("vivant", true)) and sim.grille.dans(x.get("pos", Vector2i(-9999, -9999)))


## La dépouille posée sur une tuile — la première trouvée, dans l'ordre stable des êtres.
static func cadavre_a(sim: Simulation, t: Vector2i) -> Dictionary:
	for id: String in sim.ordre:
		var x: Dictionary = sim.entites.get(id, {})
		if not x.is_empty() and est_cadavre(sim, x) and x.pos == t:
			return x
	return {}


## LE STADE, DÉDUIT DU TEMPS. Un mort d'avant cette ligne n'a pas de `mort_tick` : on le lui pose ici, une fois, au
## moment où on le regarde — sans quoi une partie chargée verrait ses anciens morts naître ossements.
static func stade(sim: Simulation, c: Dictionary) -> Dictionary:
	var stades: Array = _cfg().get("stades", [])
	if stades.is_empty():
		return {}
	if not c.has("mort_tick"):
		c["mort_tick"] = sim.horloge_monde.ticks
	var jour := maxf(1.0, float(SimTerrain._cycle(sim).get("ticks_par_jour", 2400000)))
	var age := float(sim.horloge_monde.ticks - int(c.mort_tick)) / jour
	var res: Dictionary = stades[0]
	for s in stades:
		if age >= float((s as Dictionary).get("jours", 0.0)):
			res = s
	return res


## Ce que la dépouille émet dans le champ d'odeur, en part de la source `depouille` : un mort frais sent peu, un mort
## gonflé appelle les charognards de loin, des ossements ne sentent plus rien.
static func odeur_mult(sim: Simulation, c: Dictionary) -> float:
	return float(stade(sim, c).get("odeur", 1.0))


## La couleur dont le pantin se voile — c'est ce qui rend l'âge d'une bataille lisible à l'œil.
static func teinte(sim: Simulation, c: Dictionary) -> Color:
	var t: Array = stade(sim, c).get("teinte", [1.0, 1.0, 1.0])
	return Color(float(t[0]), float(t[1]), float(t[2])) if t.size() >= 3 else Color.WHITE


static func prelevees(c: Dictionary) -> Array:
	return (c.get("corps", {}) as Dictionary).get("prelevees", [])


## CE QU'ON PEUT ENCORE PRENDRE. La racine du plan est exclue — le torse d'un corps *est* le corps, et l'emporter
## n'aurait aucun sens ; tout le reste se prélève, la tête comprise. Passé la putréfaction, plus rien : on ne
## l'apprend pas par un échec, mais par l'option qui n'est plus offerte.
static func prelevable(sim: Simulation, c: Dictionary, nom: String) -> bool:
	var plan := Etres.plan_corps(c)
	if plan.is_empty() or not (plan.get("parties", {}) as Dictionary).has(nom):
		return false
	if nom == str(plan.get("racine", "")):
		return false
	if not bool(stade(sim, c).get("preleve", false)):
		return false
	return Etres.partie_intacte(c, nom)


## Prélever une pièce : le jet, la pièce qui quitte le corps dans tous les cas, et l'objet si la main a été sûre.
static func prelever(sim: Simulation, e: Dictionary, c: Dictionary, nom: String, tick: int) -> bool:
	if not prelevable(sim, c, nom) or Grille.distance(e.pos, c.pos) > 1:
		return false
	var pr: Dictionary = _cfg().get("prelevement", {})
	var plan := Etres.plan_corps(c)
	var p: Dictionary = plan.parties[nom]
	var interne := bool(p.get("interne", false))
	var comp := str(pr.get("competence", "chasse"))
	# UN SEUL JET PAR PIÈCE, semé sur la dépouille et la partie : réessayer rendrait le même résultat, et l'échec
	# est donc définitif. On n'emprunte pas le dé du combat — un consommateur neuf ne perturbe pas un flux existant.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "prelever", str(c.id), nom])
	var jet := rng.randi_range(1, 20) + sim.regles.niveau(e.get("competences_eff", e.get("competences", {})), comp)
	sim.gagner_xp(e, comp, int(pr.get("xp", 1)))
	e.compteur = tick + int(pr.get("ticks", 1500))
	# CE QUI EST OUVERT NE SE REFERME PAS : la pièce quitte le corps dans les deux cas. `perdre_partie` emporte avec
	# elle ce qu'elle portait — prendre un bras prend la main —, et c'est le même chemin que la perte au combat.
	Etres.perdre_partie(c, nom)
	var corps: Dictionary = c.get("corps", {})
	var prises: Array = corps.get("prelevees", [])
	prises.append(nom)
	corps["prelevees"] = prises
	c["corps"] = corps
	if jet < int(pr.get("dd_organe" if interne else "dd_membre", 10)):
		EventBus.emettre(&"journal", [&"journal.preleve_rate", {"nom": e.name_key, "partie": "partie." + nom}])
		return true
	var o := SimObjets.generer_objet(sim, str(pr.get("item_organe" if interne else "item_membre", "")), SimObjets.niveau_loot(sim), {"creature": c.name_key}, "commun", 0)
	if o.is_empty():
		return true
	SimObjets.identifier(sim, o)   # ce qu'on a tiré de sa main n'est pas un mystère
	o["espece"] = str(c.get("def", ""))
	o["nom"] = {"partie": "partie." + nom, "de_creature": str(c.name_key)}
	# LA TAILLE DE LA BÊTE PÈSE ET SE PAIE : un membre de troll n'est pas un membre de lièvre, et le seul nombre qui
	# dise la carrure sans table à côté est la santé maximale du corps dont il vient.
	var bornes: Array = pr.get("poids_bornes", [0.3, 4.0])
	var f := clampf(float(c.get("sante_max", 10)) / maxf(1.0, float(pr.get("sante_reference", 40.0))), float(bornes[0]), float(bornes[1]))
	o["poids"] = float(pr.get("poids_organe" if interne else "poids_membre", 1.0)) * f
	o["valeur"] = maxf(1.0, float(pr.get("valeur_base", 8.0)) * f * (float(pr.get("mult_vital", 3.0)) if bool(p.get("vital", false)) else 1.0))
	e.sac.append(o.uid)
	EventBus.emettre(&"journal", [&"journal.preleve", {"nom": e.name_key, "partie": "partie." + nom, "def": c.name_key}])
	return true
