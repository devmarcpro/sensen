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
	var age := SimClimat.age_decompose(sim, c, "mort_tick", sim.horloge_monde.ticks) / jour   # un mort dans la neige reste frais (lot 6)
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
	var apparence := Etres.apparence_membre(c, nom)   # avant qu'elle quitte le corps : ce qu'elle emporte, et sa peau (2026-09-13)
	Etres.perdre_partie(c, nom)
	var corps: Dictionary = c.get("corps", {})
	var prises: Array = corps.get("prelevees", [])
	prises.append(nom)
	corps["prelevees"] = prises
	c["corps"] = corps
	if jet < int(pr.get("dd_organe" if interne else "dd_membre", 10)):
		EventBus.emettre(&"journal", [&"journal.preleve_rate", {"nom": e.name_key, "partie": "partie." + nom}])
		return true
	var o := objet_de_partie(sim, c, nom, apparence, 1.0)
	if o.is_empty():
		return true
	e.sac.append(o.uid)
	EventBus.emettre(&"journal", [&"journal.preleve", {"nom": e.name_key, "partie": "partie." + nom, "def": c.name_key}])
	return true


## L'OBJET QU'UNE PARTIE DEVIENT hors du corps — prélevée sur une dépouille ou tombée au combat : sa pièce, son poids et
## sa valeur tirés de la bête, et l'apparence qu'elle avait sur elle (lue par l'appelant AVANT qu'elle ne tombe).
static func objet_de_partie(sim: Simulation, c: Dictionary, nom: String, apparence: Dictionary, valeur_mult: float) -> Dictionary:
	var pr: Dictionary = _cfg().get("prelevement", {})
	var p: Dictionary = Etres.plan_corps(c).get("parties", {}).get(nom, {})
	var interne := bool(p.get("interne", false))
	var o := SimObjets.generer_objet(sim, str(pr.get("item_organe" if interne else "item_membre", "")), SimObjets.niveau_loot(sim), {"creature": c.name_key}, "commun", 0)
	if o.is_empty():
		return {}
	SimObjets.identifier(sim, o)   # ce qu'on a tiré d'un corps n'est pas un mystère
	o["espece"] = str(c.get("def", ""))
	o["nom"] = {"partie": Etres.cle_nom_partie(nom), "de_creature": str(c.name_key)}
	if not apparence.is_empty():
		o["apparence_membre"] = apparence
	# LA TAILLE DE LA BÊTE PÈSE ET SE PAIE : un membre de troll n'est pas un membre de lièvre, et le seul nombre qui
	# dise la carrure sans table à côté est la santé maximale du corps dont il vient.
	var bornes: Array = pr.get("poids_bornes", [0.3, 4.0])
	var f := clampf(float(c.get("sante_max", 10)) / maxf(1.0, float(pr.get("sante_reference", 40.0))), float(bornes[0]), float(bornes[1]))
	o["poids"] = float(pr.get("poids_organe" if interne else "poids_membre", 1.0)) * f
	o["valeur"] = maxf(1.0, float(pr.get("valeur_base", 8.0)) * f * (float(pr.get("mult_vital", 3.0)) if bool(p.get("vital", false)) else 1.0) * valeur_mult)
	return o


## CE QUE DEVIENT UN MEMBRE PERDU AU COMBAT (designer 2026-09-13 : « ça dépend de la blessure ») : la ligne de
## `blessures.par_type` du type du coup — `tombe` (avec `valeur_mult`), `broye` ou `calcine`.
static func issue_blessure(detail: Dictionary) -> Dictionary:
	var bl: Dictionary = _cfg().get("blessures", {})
	var type := str(detail.get("type", ""))
	if type.is_empty() and bool(detail.get("chute", false)):
		type = "chute"
	var ligne: Dictionary = bl.get("par_type", {}).get(type, {})
	if ligne.is_empty():
		ligne = {"issue": str(bl.get("defaut", "broye"))}
	return ligne


## Un membre vient de tomber au combat : selon la blessure, il reste au sol — tel qu'il était sur la créature — ou il
## n'en reste rien. Rend l'issue (`tombe`, `broye`, `calcine`) pour le journal.
static func membre_perdu_au_combat(sim: Simulation, c: Dictionary, nom: String, apparence: Dictionary, detail: Dictionary) -> String:
	var ligne := issue_blessure(detail)
	var issue := str(ligne.get("issue", "broye"))
	if issue != "tombe" or apparence.is_empty() or bool(apparence.get("interne", false)):
		return issue if not bool(apparence.get("interne", false)) else ""
	var o := objet_de_partie(sim, c, nom, apparence, float(ligne.get("valeur_mult", 1.0)))
	if not o.is_empty():
		sim._poser_contenant(c.pos, [str(o.uid)], "butin")
	return issue


## ÉQUARRIR (ordre de travail 42 bis, 2026-09-14) : ce qu'une pièce de bête rend en MATIÈRE BRUTE. Une peau, une dent, un
## membre prélevé étaient des objets ; aucune recette ne pouvait partir d'eux. `[]` si l'objet ne se réduit pas.
static func matieres_de(sim: Simulation, it: Dictionary) -> Array:
	var eq: Dictionary = _cfg().get("equarrissage", {})
	var base := str(it.get("base", ""))
	var res: Array = []
	if (eq.get("objets", {}) as Dictionary).has(base):
		for m in eq.objets[base]:
			res.append([str(m[0]), int(m[1])])
		return res
	var pr: Dictionary = _cfg().get("prelevement", {})
	if base == str(pr.get("item_membre", "membre")):
		var def: Dictionary = GameData.catalogues.creatures.get(str(it.get("espece", "")), {})
		var tegument := ""   # une peau se tanne, elle ne se découpe pas : sans plume, écaille ni carapace, le membre ne rend pas de tégument
		for cle in (eq.get("teguments", {}) as Dictionary).keys():
			if cle in def.get("drops_chasse", []):
				tegument = str(eq.teguments[cle])
				break
		for m in eq.get("membre", []):
			var mat := tegument if str(m[0]) == "tegument" else str(m[0])
			if mat.is_empty():
				continue
			res.append([mat, maxi(1, roundi(float(it.get("poids", 1.0)) * float(m[1])))])
		for m2 in (eq.get("par_espece", {}) as Dictionary).get(str(it.get("espece", "")), []):   # l'araignée géante rend sa soie
			res.append([str(m2[0]), maxi(1, roundi(float(it.get("poids", 1.0)) * float(m2[1])))])
		return res
	if base == str(pr.get("item_organe", "organe")):
		var nom_p := str((it.get("nom", {}) as Dictionary).get("partie", "")).get_slice(".", 1).trim_suffix("_D").trim_suffix("_G")
		var org: Dictionary = eq.get("organes", {})
		for m in org.get(nom_p, org.get("_defaut", [])):
			res.append([str(m[0]), int(m[1])])
	return res


static func equarrir(sim: Simulation, e: Dictionary, uid: String, tick: int) -> bool:
	var it: Dictionary = sim.items.get(uid, {})
	if it.is_empty() or not (uid in e.sac):
		return false
	var matieres := matieres_de(sim, it)
	if matieres.is_empty():
		return false
	var eq: Dictionary = _cfg().get("equarrissage", {})
	var rendus: Array[String] = []
	for m in matieres:
		if not GameData.catalogues.materials.has(str(m[0])):
			continue
		var brut: Dictionary = SimObjets.generer_objet(sim, "materiau_brut", 1, {}, "commun", 0)
		if brut.is_empty():
			continue
		brut.materiau = str(m[0])
		brut["forme"] = "brut"
		brut.quantite = int(m[1])
		brut["espece"] = str(it.get("espece", ""))
		SimObjets.identifier(sim, brut)
		e.sac.append(brut.uid)
		rendus.append("%d %s" % [int(m[1]), str(m[0])])
	if int(it.get("quantite", 1)) > 1:
		it.quantite = int(it.quantite) - 1
	else:
		e.sac.erase(uid)
	sim.gagner_xp(e, str(eq.get("competence", "chasse")), int(eq.get("xp", 1)))
	e.compteur = tick + int(eq.get("ticks", 800))
	EventBus.emettre(&"journal", [&"journal.equarri", {"nom": e.name_key, "matieres": ", ".join(rendus)}])
	return true

