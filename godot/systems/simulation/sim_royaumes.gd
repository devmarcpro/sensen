class_name SimRoyaumes
extends RefCounted
## Les royaumes : état, règne et ère, événements, guerres (D) ; conquête, familles, titres, succession, la semaine des royaumes PNJ ; lois, douanes, accords ; gouvernance, défense et raids.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


## Un royaume par son id, dans les secteurs déjà générés ({} sinon).
static func royaume_par_id(sim: Simulation, id: String) -> Dictionary:
	if sim.monde == null:
		return {}
	for sect in sim.monde.surface.royaumes_cache.values():
		if sect.has(id):
			return sect[id]
	return {}


## L'état d'un royaume (créé à la première lecture, à sa graine) : population, armée, humeur, règne et ère, blason.
static func etat_royaume(sim: Simulation, id: String) -> Dictionary:
	if sim.monde == null:
		return {}
	if sim.monde.etats_royaumes.has(id):
		return sim.monde.etats_royaumes[id]
	var roy := royaume_par_id(sim, id)
	if roy.is_empty():
		return {}
	var pays: Dictionary = SimTerritoire._ry(sim).get("pays", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, id, "etat"])
	var culture: Dictionary = GameData.catalogues.name_cultures.get(str(roy.culture), {})
	var eres: Array = culture.get("eres", ["grue"])
	var bl: Dictionary = GameData.config("blasons")
	var couleurs: Array = bl.couleurs.get(str(roy.culture), bl.couleurs._defaut).duplicate()
	var c1: String = str(couleurs[rng.randi_range(0, couleurs.size() - 1)])
	couleurs.erase(c1)
	var c2: String = str(couleurs[rng.randi_range(0, couleurs.size() - 1)]) if not couleurs.is_empty() else c1
	var motifs: Array = bl.motifs.get(str(roy.government_type), ["couronne"])
	var etat := {"population": 0, "armee": 0, "humeur": int(pays.get("humeur_base", 55)), "dirigeant": Noms.afficher(Noms.generer(str(roy.culture), culture, "m" if rng.randf() < 0.6 else "f", rng)),
		"ere": str(eres[rng.randi_range(0, eres.size() - 1)]), "avenement": int(GameData.config("calendrier").annee_depart) - rng.randi_range(0, int(pays.get("avenement_max", 30))),
		"blason": {"couleurs": [c1, c2], "motif": str(motifs[rng.randi_range(0, motifs.size() - 1)])}, "guerres": [], "journal": []}
	sim.monde.etats_royaumes[id] = etat
	_recompter_royaume(sim, id, roy, etat)
	return etat


## La population et l'armée d'un royaume : la somme des fiches de ses agglomérations, une lecture pure.
static func _recompter_royaume(sim: Simulation, id: String, roy: Dictionary, etat: Dictionary) -> void:
	var pop := 0
	for c in roy.territory_cells:
		if bool(sim.monde.surface.poi_de(c).get("village", false)):
			pop += int(sim.monde.surface.fiche_agglomeration(c).get("population", 0))
	etat.population = pop
	var pays: Dictionary = SimTerritoire._ry(sim).get("pays", {})
	etat.armee = int(pays.get("armee_base", {}).get(str(roy.taille), 2)) + pop / maxi(1, int(GameData.config("villes").get("gardes_par_habitant", 25)))
	etat.tresor = int(sim.monde.tresors_royaumes.get(id, 0))
	# Le dirigeant chargé porte son nom ; sinon celui tiré à la graine reste.
	for x in sim.vivants():
		if str(x.get("royaume", "")) == id and str(x.get("fonction", "")) == "dirigeant" and x.has("nom"):
			etat.dirigeant = Noms.afficher(x.nom)
			break


## L'an de règne d'un royaume sur le calendrier.
static func an_de_regne(sim: Simulation, etat: Dictionary) -> int:
	return maxi(1, SimVilles.annee_courante(sim) - int(etat.get("avenement", SimVilles.annee_courante(sim))) + 1)


## Une succession ouvre une ère nouvelle, à l'année courante (Familles et succession).
static func _nouvelle_ere(sim: Simulation, id: String, dirigeant: Dictionary) -> void:
	var etat := etat_royaume(sim, id)
	if etat.is_empty():
		return
	var roy := royaume_par_id(sim, id)
	var eres: Array = GameData.catalogues.name_cultures.get(str(roy.get("culture", "")), {}).get("eres", ["grue"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, id, "ere", sim.monde.semaine_courante])
	etat.ere = str(eres[rng.randi_range(0, eres.size() - 1)])
	etat.avenement = SimVilles.annee_courante(sim)
	if dirigeant.has("nom"):
		etat.dirigeant = Noms.afficher(dirigeant.nom)
	_noter_evenement(sim, id, roy, "evenement.avenement", {"ere": "ere.%s.name" % etat.ere})


## Un événement de royaume au journal du royaume (daté du calendrier) et, si le joueur est dans ce royaume ou si c'est
## une guerre, au journal du joueur.
static func _noter_evenement(sim: Simulation, id: String, roy: Dictionary, cle: String, params: Dictionary) -> void:
	var etat := etat_royaume(sim, id)
	var p := params.duplicate()
	p["royaume"] = str(roy.get("nom", id))
	etat.journal.append({"jour": SimVilles.jour_courant(sim), "cle": cle, "params": p})
	while etat.journal.size() > int(SimTerritoire._ry(sim).get("pays", {}).get("journal_max", 10)):
		etat.journal.pop_front()
	var j: Dictionary = SimTerritoire._joueur(sim)
	var chez_lui: bool = not j.is_empty() and sim.lieu == "camp" and str(sim.monde.surface.royaume_de(SimCamp._cell_de(sim, j.pos)).get("id", "")) == id
	if chez_lui or cle in ["evenement.guerre", "evenement.paix"]:
		EventBus.emettre(&"journal", [StringName(cle), p])


## La semaine des pays : pour chaque royaume connu, le recompte, l'humeur qui revient vers sa base, les événements.
static func _semaine_royaumes_pays(sim: Simulation) -> void:
	if sim.monde == null:
		return
	var pays: Dictionary = SimTerritoire._ry(sim).get("pays", {})
	var evs: Dictionary = GameData.catalogues.get("royaumes_evenements", {})
	var ids: Array = evs.keys()
	ids.sort()
	for sect in sim.monde.surface.royaumes_cache.values():
		for id in sect.keys():
			var roy: Dictionary = sect[id]
			var etat := etat_royaume(sim, str(id))
			if etat.is_empty():
				continue
			_recompter_royaume(sim, str(id), roy, etat)
			# L'humeur des résidents chargés compte ; sinon elle revient vers sa base.
			var n := 0
			var somme := 0
			for x in sim.vivants():
				if str(x.get("royaume", "")) == str(id) and x.has("assignation"):
					n += 1
					somme += int(x.get("humeur", pays.get("humeur_base", 55)))
			if n >= 5:
				etat.humeur = int(round((float(etat.humeur) + float(somme) / float(n)) / 2.0))
			else:
				var base := int(pays.get("humeur_base", 55))
				etat.humeur += clampi(base - int(etat.humeur), -int(pays.get("humeur_retour", 3)), int(pays.get("humeur_retour", 3)))
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([sim.graine, str(id), "evenements", sim.monde.semaine_courante])
			for eid in ids:
				var ev: Dictionary = evs[eid]
				if rng.randf() >= float(ev.chance) or not _conditions_evenement(sim, str(id), roy, etat, ev.conditions):
					continue
				_appliquer_evenement(sim, str(id), roy, etat, ev)
			etat.humeur = clampi(int(etat.humeur), 0, 100)


static func _conditions_evenement(sim: Simulation, id: String, roy: Dictionary, etat: Dictionary, c: Dictionary) -> bool:
	if c.has("humeur_max") and int(etat.humeur) > int(c.humeur_max):
		return false
	if c.has("humeur_min") and int(etat.humeur) < int(c.humeur_min):
		return false
	if c.has("tresor_max") and int(etat.tresor) > int(c.tresor_max):
		return false
	if c.has("guerre") and bool(c.guerre) != (not etat.guerres.is_empty()):
		return false
	if c.has("gouvernances") and not (str(roy.government_type) in c.gouvernances):
		return false
	if c.has("anniversaire_avenement"):
		var d: Dictionary = SimVilles.date_courante(sim)
		var a_av: Dictionary = Calendrier.date(0)
		if int(d.jour_de_l_an) != int(a_av.jour_de_l_an) + (int(etat.avenement) * 7) % 30:
			return false
	if c.has("nourriture_penurie") or c.has("nourriture_surplus"):
		var cap := str(sim.monde.surface.fiche_agglomeration(roy.capital_poi).get("nom", ""))
		var t: Dictionary = sim.territoires.get(cap, {})
		if t.is_empty() or not t.has("prix"):
			return false
		var eco: Dictionary = GameData.config("villes").economie
		var prix := float(t.prix.get("nourriture", 1.0))
		if c.has("nourriture_penurie") and (prix < float(eco.prix_max) - 0.01):
			return false
		if c.has("nourriture_surplus") and (prix > float(eco.prix_min) + 0.01):
			return false
	if c.has("voisin"):
		var trouve := false
		for autre in roy.get("diplomacy", {}).keys():
			if str(roy.diplomacy[autre]) in c.voisin and not (str(autre) in etat.guerres):
				trouve = true
		if not trouve:
			return false
	return true


static func _appliquer_evenement(sim: Simulation, id: String, roy: Dictionary, etat: Dictionary, ev: Dictionary) -> void:
	var ef: Dictionary = ev.effets
	var params := {}
	if ef.has("humeur"):
		etat.humeur = clampi(int(etat.humeur) + int(ef.humeur), 0, 100)
	if ef.has("tresor_pct"):
		var delta := int(round(float(etat.tresor) * float(ef.tresor_pct)))
		sim.monde.tresors_royaumes[id] = int(sim.monde.tresors_royaumes.get(id, 0)) + delta
		etat.tresor = int(sim.monde.tresors_royaumes[id])
	if ef.has("base_rate"):
		roy.taxes.base_rate = snappedf(float(roy.taxes.get("base_rate", 0.08)) + float(ef.base_rate), 0.01)
	if ef.has("loi"):
		var pool: Dictionary = GameData.config("absurd_laws_pool")
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.graine, id, "loi", sim.monde.semaine_courante])
		if str(ef.loi) == "ajoute":
			var obj: String = str(pool.objets[rng.randi() % pool.objets.size()])
			roy.laws.append({"id": "loi_" + obj + "_%d" % sim.monde.semaine_courante, "type": "objet", "target": obj, "status": "illegal", "consequence": str(pool.consequences[rng.randi() % pool.consequences.size()])})
			params["loi"] = "item.%s.name" % obj
		else:
			var absurdes: Array = []
			for l in roy.laws:
				if str(l.get("type", "")) == "objet" and not (str(l.target) in pool.get("substances_illegales", [])):
					absurdes.append(l)
			if absurdes.is_empty():
				return
			var l: Dictionary = absurdes[rng.randi() % absurdes.size()]
			roy.laws.erase(l)
			params["loi"] = "item.%s.name" % str(l.target)
	if ef.has("guerre"):
		if str(ef.guerre) == "declare":
			var cibles: Array = []
			for autre in roy.get("diplomacy", {}).keys():
				if str(roy.diplomacy[autre]) in ev.conditions.get("voisin", ["hostile"]) and not (str(autre) in etat.guerres):
					cibles.append(str(autre))
			if cibles.is_empty():
				return
			cibles.sort()
			var autre_id: String = cibles[0]
			etat.guerres.append(autre_id)
			var e2 := etat_royaume(sim, autre_id)
			if not e2.is_empty() and not (id in e2.guerres):
				e2.guerres.append(id)
			params["autre"] = str(royaume_par_id(sim, autre_id).get("nom", autre_id))
		else:
			if etat.guerres.is_empty():
				return
			var autre_id2: String = str(etat.guerres[0])
			etat.guerres.erase(autre_id2)
			var e3 := etat_royaume(sim, autre_id2)
			if not e3.is_empty():
				e3.guerres.erase(id)
			params["autre"] = str(royaume_par_id(sim, autre_id2).get("nom", autre_id2))
	_noter_evenement(sim, id, roy, str(ev.journal_key), params)


## Deux royaumes sont-ils en guerre ?
static func en_guerre(sim: Simulation, a: String, b: String) -> bool:
	if a.is_empty() or b.is_empty() or a == b:
		return false
	return b in etat_royaume(sim, a).get("guerres", [])


# ---------------------------------------------------------------- les transports (Villes — B4, 2026-09-05)

static func village_a(sim: Simulation, vers: Vector2i) -> Dictionary:
	if sim.monde == null or sim.lieu != "camp":
		return {}
	var v: Dictionary = sim.monde.cellule(SimCamp._cell_de(sim, vers)).get("village", {})
	return v


static func population_village(sim: Simulation, nom: String) -> Array:
	var res: Array = []
	for x in sim.vivants():
		if str(x.get("village", "")) == nom and x.camp == "civil":
			res.append(x)
	return res


## Conquérir un village (Conquête de village) : gardes affaiblis, puis un jet de Leadership/Charisme contre 2 × population.
static func _conquerir(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	var v := village_a(sim, vers)
	if v.is_empty() or e.controle != "joueur":
		return false
	var cell: Vector2i = SimCamp._cell_de(sim, vers)
	var centre: Vector2i = sim.monde.pos_monde(cell, v.centre)
	if Grille.distance(e.pos, centre) > 2 or sim.monde.claims.has(cell):
		return false
	var cq: Dictionary = SimTerritoire._ry(sim).conquete
	var info: Dictionary = sim.monde.villages.get(str(v.nom), {})
	var pop := population_village(sim, str(v.nom))
	var gardes := 0.0
	for x in pop:
		if x.ai_profile == "garde":
			gardes += float(sim.progression.niveaux_derives(x).combat) + 1.0
	if sim.monde.semaine_courante < int(info.get("defense_jusqua", 0)):
		gardes *= float(cq.echec_defense_mult)
	var seuil := float(cq.gardes_pct) * float(cq.valeur_par_habitant) * float(pop.size())
	if gardes >= seuil:
		EventBus.emettre(&"journal", [&"journal.conquete_gardes", {"gardes": "%.1f" % gardes, "seuil": "%.1f" % seuil}])
		return false
	var roy_id := str(v.get("royaume", ""))
	var dd := float(cq.dd_par_habitant) * float(pop.size())
	if sim.monde.vacances.has(roy_id):
		dd *= float(cq.vacance_dd_mult)
	var jet := sim.des.jet("1d20") + sim.regles.niveau(e.competences_eff, "leadership") / 2 + int(e.corps.stats.charisme) / 4
	e.compteur = tick + int(sim.regles.r.actions.objet)
	var roy: Dictionary = sim.monde.surface.royaume_de(cell)
	if float(jet) < dd:
		if not e.has("reputations"):
			e["reputations"] = {}
		e.reputations[str(v.nom)] = clampi(int(e.reputations.get(str(v.nom), 0)) - int(cq.echec_reputation), -100, 100)
		info["defense_jusqua"] = sim.monde.semaine_courante + int(cq.echec_semaines)
		sim.monde.villages[str(v.nom)] = info
		EventBus.emettre(&"journal", [&"journal.conquete_echec", {"village": v.nom, "jet": jet, "dd": int(dd)}])
		return true
	sim.monde.claims[cell] = {"role": "habitation"}
	info["conquis_par"] = e.id
	if sim.territoires.has(str(v.nom)):   # une ville-territoire (Villes B0) : elle devient sienne, avec ses gens, ses stocks, ses dettes
		sim.territoires[str(v.nom)].proprietaire = "joueur"
	sim.monde.villages[str(v.nom)] = info
	if not roy.is_empty():
		var hostile := relation_royaume(sim, e, roy) == "hostile"
		var n := int(cq.reputation_liberation) if hostile else int(cq.reputation_agression)
		_baisser_reputation(sim, e, roy_id, -n)
		EventBus.emettre(&"journal", [&"journal.conquete_liberation" if hostile else &"journal.conquete_agression", {"royaume": roy.nom, "n": n}])
	EventBus.emettre(&"journal", [&"journal.conquete_reussie", {"village": v.nom, "jet": jet, "dd": int(dd)}])
	EventBus.emettre(&"cell_claimed", [cell])
	EventBus.emettre(&"village_conquered", [cell, e.id])
	SimTerritoire._verifier_royaume(sim, e)
	return true


## Un village conquis retourne à son royaume (raid de reconquête perdu).
static func _rendre_village(sim: Simulation, nom: String) -> void:
	var info: Dictionary = sim.monde.villages.get(nom, {})
	if info.is_empty() or str(info.get("conquis_par", "")).is_empty():
		return
	sim.monde.claims.erase(info.cellule)
	info.conquis_par = ""
	EventBus.emettre(&"journal", [&"journal.village_rendu", {"village": nom, "royaume": sim.monde.surface.royaume_de(info.cellule).get("nom", "—")}])


## Les familles d'un village (Familles et succession) : par bâtiment, le plus âgé est le parent, le second adulte
## son conjoint, les autres ses enfants.
static func _former_familles(sim: Simulation, cell: Vector2i, v: Dictionary) -> void:
	var sc: Dictionary = SimTerritoire._ry(sim).succession
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "familles", cell])
	for bat in v.get("batiments", []):
		var lits: Dictionary = {}
		for l in bat.get("lits", []):
			lits[sim.monde.pos_monde(cell, l)] = true
		var membres: Array = []
		for x in sim.vivants():
			if str(x.get("village", "")) == str(v.nom) and lits.has(x.get("lit", Vector2i(-1, -1))):
				membres.append(x)
		if membres.size() < 2:
			continue
		membres.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("age", 0)) > float(b.get("age", 0)))
		var parent: Dictionary = membres[0]
		var conjoint: Dictionary = membres[1] if float(membres[1].get("age", 0)) >= float(sim.regles.r.age.adulte) else {}
		if not conjoint.is_empty():
			parent.family.spouse = conjoint.id
			conjoint.family.spouse = parent.id
		for k in range(1 if conjoint.is_empty() else 2, membres.size()):
			var enfant: Dictionary = membres[k]
			enfant.age = float(rng.randi_range(int(sc.enfant_age[0]), int(sc.enfant_age[1])))
			enfant.family.child_of = [parent.id] + ([conjoint.id] if not conjoint.is_empty() else [])
			parent.family.parent_of.append(enfant.id)
			if not conjoint.is_empty():
				conjoint.family.parent_of.append(enfant.id)
	for x in sim.vivants():
		if str(x.get("village", "")) == str(v.nom) and str(x.get("fonction", "")) in ["dirigeant", "maitre_de_guilde"]:
			x["titre"] = titre_de(sim, x)
	SimPnj._former_opinions(sim, cell, v)   # qui aime qui dans le quartier (PNJ — traits, histoires et souhaits)


## Le titre culturel d'un PNJ à rôle (Génération de noms) : la culture, la gouvernance de son royaume, son genre.
static func titre_de(sim: Simulation, x: Dictionary) -> String:
	var culture: Dictionary = GameData.catalogues.name_cultures.get(str(x.get("social", {}).get("culture", "")), {})
	var titres: Dictionary = culture.get("titres", {})
	var gouv := ""
	if sim.monde != null and not str(x.get("royaume", "")).is_empty():
		for sect in sim.monde.surface.royaumes_cache.values():
			if sect.has(str(x.royaume)):
				gouv = str(sect[str(x.royaume)].government_type)
	if str(x.get("fonction", "")) == "maitre_de_guilde":
		gouv = "guilde"
	for cle in titres.keys():
		if gouv.begins_with(str(cle)):
			return str(titres[cle].get(str(x.get("genre", "m")), titres[cle].get("m", "")))
	return ""


## L'héritier d'un PNJ : l'aîné vivant de ses enfants.
static func heritier_de(sim: Simulation, x: Dictionary) -> String:
	var meilleur := ""
	var age := -1.0
	for id in x.get("family", {}).get("parent_of", []):
		var enfant: Dictionary = sim.entites.get(str(id), {})
		if not enfant.is_empty() and bool(enfant.vivant) and float(enfant.get("age", 0)) > age:
			age = float(enfant.age)
			meilleur = str(id)
	return meilleur


## La semaine des royaumes : successions, repeuplement, décimation.
static func _semaine_royaumes_pnj(sim: Simulation) -> void:
	if sim.monde == null:
		return
	for roy_id in sim.monde.vacances.keys().duplicate():
		if sim.monde.semaine_courante < int(sim.monde.vacances[roy_id]):
			continue
		var meilleur: Dictionary = {}
		var niv := -1.0
		var nom_roy: String = str(roy_id)
		var gouv_id := ""
		for sect in sim.monde.surface.royaumes_cache.values():
			if sect.has(roy_id):
				nom_roy = str(sect[roy_id].nom)
				gouv_id = str(sect[roy_id].government_type)
		var par_heritier := false
		if str(GameData.catalogues.governments.get(gouv_id, {}).get("succession", "")) == "heritier" and sim.monde.heritiers.has(roy_id):
			var h: Dictionary = sim.entites.get(str(sim.monde.heritiers[roy_id]), {})
			if not h.is_empty() and bool(h.vivant):
				meilleur = h
				par_heritier = true
		sim.monde.heritiers.erase(roy_id)
		if meilleur.is_empty():
			for x in sim.vivants():
				if str(x.get("royaume", "")) == roy_id and x.camp == "civil" and str(x.get("fonction", "")) != "dirigeant":
					var g := float(sim.progression.niveaux_derives(x).general)
					if g > niv:
						niv = g
						meilleur = x
		if meilleur.is_empty():
			EventBus.emettre(&"journal", [&"journal.vacance_prolongee", {"royaume": nom_roy}])
			continue
		meilleur.fonction = "dirigeant"
		meilleur["or_max"] = int(GameData.entree("functions", "dirigeant").portefeuille)
		meilleur["titre"] = titre_de(sim, meilleur)
		sim.monde.vacances.erase(roy_id)
		_nouvelle_ere(sim, str(roy_id), meilleur)   # un règne nouveau, une ère nouvelle (D)
		EventBus.emettre(&"journal", [&"journal.succession_heritier" if par_heritier else &"journal.succession", {"royaume": nom_roy, "nom": meilleur.name_key}])
		EventBus.emettre(&"leadership_changed", [roy_id, meilleur.id])
	# Les halls sans maître : le plus haut niveau général du village reprend le hall (2 semaines).
	for cle in sim.monde.vacances_guildes.keys().duplicate():
		if sim.monde.semaine_courante < int(sim.monde.vacances_guildes[cle]):
			continue
		var parts: PackedStringArray = str(cle).split("|")
		var candidat: Dictionary = {}
		var niv_g := -1.0
		for x in sim.vivants():
			if str(x.get("village", "")) == parts[1] and x.camp == "civil" and str(x.get("fonction", "")) in ["villageois", "oisif", "fermier", "artisan", "commercant"] and not x.has("guilde"):
				var g := float(sim.progression.niveaux_derives(x).general)
				if g > niv_g:
					niv_g = g
					candidat = x
		if candidat.is_empty():
			continue
		candidat.fonction = "maitre_de_guilde"
		candidat["guilde"] = parts[0]
		candidat["titre"] = titre_de(sim, candidat)
		if not ("quetes" in candidat.tags):
			candidat.tags.append("quetes")
		candidat["or_max"] = int(GameData.entree("functions", "maitre_de_guilde").portefeuille)
		sim.monde.vacances_guildes.erase(cle)
		EventBus.emettre(&"journal", [&"journal.succession_guilde", {"nom": candidat.name_key, "guilde": "guilde.%s.name" % parts[0]}])
		EventBus.emettre(&"leadership_changed", [parts[0], candidat.id])
	var rp: Dictionary = SimTerritoire._ry(sim).repeuplement
	for nom in sim.monde.villages.keys():
		var info: Dictionary = sim.monde.villages[nom]
		if bool(info.get("abandonne", false)) or not sim.monde.peuplees.has(info.cellule) or sim.lieu != "camp":
			continue
		var cell: Vector2i = info.cellule
		if absi(cell.x - sim.monde.centre.x) > sim.monde.rayon or absi(cell.y - sim.monde.centre.y) > sim.monde.rayon:
			continue
		var pop := population_village(sim, nom).size()
		var cap := int(info.get("capacite", 1))
		if pop == 0:
			info.abandonne = true
			EventBus.emettre(&"journal", [&"journal.village_abandonne", {"village": nom}])
			continue
		if pop >= cap:
			continue
		var chance := float(rp.chance) * (1.0 - float(pop) / float(cap)) * (1.0 - sim.monde.corruption_de(cell) / 100.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.graine, "repop", nom, sim.monde.semaine_courante])
		if rng.randf() >= chance:
			continue
		var v: Dictionary = sim.monde.cellule(cell).get("village", {})
		for pj in v.get("pnj", []):
			var lit: Vector2i = sim.monde.pos_monde(cell, pj.lit)
			var libre := true
			for x in population_village(sim, nom):
				if x.get("lit", Vector2i(-1, -1)) == lit:
					libre = false
			if libre and sim.grille.dans(lit) and sim.grille.occupant(lit).is_empty():
				var x: Dictionary = SimObjets.ajouter(sim, str(rp.creature), lit, "ia")
				SimObjets._habiller_pnj(sim, x, GameData.entree("creatures", str(rp.creature)), str(v.culture))
				x["lit"] = lit
				x["poste"] = lit
				x["place"] = sim.monde.pos_monde(cell, v.centre)
				x["village"] = nom
				x["royaume"] = str(v.get("royaume", ""))
				x.ancre = lit
				# Une naissance (Familles et succession) : l'enfant d'un couple du village, sinon un arrivant.
				var mere: Dictionary = {}
				for p in population_village(sim, nom):
					if p.id != x.id and not str(p.get("family", {}).get("spouse", "")).is_empty():
						mere = p
						break
				if not mere.is_empty():
					x.age = 0.0
					x.family.child_of = [mere.id, str(mere.family.spouse)]
					mere.family.parent_of.append(x.id)
					if sim.entites.has(str(mere.family.spouse)):
						sim.entites[str(mere.family.spouse)].family.parent_of.append(x.id)
					EventBus.emettre(&"journal", [&"journal.naissance", {"village": nom, "nom": mere.name_key}])
				else:
					EventBus.emettre(&"journal", [&"journal.repeuplement", {"village": nom}])
				break


# ---------------------------------------------------------------- royaumes PNJ : lois, douanes, accords (étape 10.4)

static func royaume_a(sim: Simulation, vers: Vector2i) -> Dictionary:
	if sim.monde == null or sim.lieu != "camp":
		return {}
	return sim.monde.surface.royaume_de(SimCamp._cell_de(sim, vers))


## Le tarif douanier d'un objet chez un PNJ (Gouvernance, lois et diplomatie) : catégorie du matériau dominant.
static func tarif_de(sim: Simulation, uid: String, pnj: Dictionary) -> float:
	var roy: Dictionary = {}
	if sim.monde != null and sim.lieu == "camp":
		roy = sim.monde.surface.royaume_de(SimCamp._cell_de(sim, pnj.pos))
	if roy.is_empty():
		return 0.0
	var it: Dictionary = sim.items.get(uid, {})
	var mat := ""
	if it.has("composants") and not it.composants.is_empty():
		mat = str(it.composants[it.composants.keys()[0]].materiau)
	elif it.has("materiau"):
		mat = str(it.materiau)
	var cat := str(GameData.catalogues.materials.get(mat, {}).get("category", ""))
	var tarif := float(roy.tariffs.get(cat, roy.taxes.tariff_default)) if not cat.is_empty() else float(roy.taxes.tariff_default)
	if str(sim.territoire.accords.get(str(roy.id), "")) == "commercial":
		tarif *= float(SimTerritoire._ry(sim).accords.commercial.tarif_mult)
	return tarif


## Une infraction (Lois et infractions) : lookup des lois, détection par témoin, conséquence, réputation.
static func _infraction(sim: Simulation, e: Dictionary, type: String, cible: String, pos: Vector2i, uid: String) -> bool:
	var roy := royaume_a(sim, pos)
	if roy.is_empty():
		return false
	var loi: Dictionary = {}
	for l in roy.laws:
		if str(l.type) == type and str(l.target) == cible and str(l.status) == "illegal":
			loi = l
	if loi.is_empty():
		return false
	# Détection : le témoin civil le plus proche qui voit le joueur, jet opposé Perception vs Discrétion.
	var temoin: Dictionary = {}
	for x in sim.vivants():
		if x.id == e.id or x.camp != "civil" or Grille.distance(x.pos, pos) > int(SimTerritoire._ry(sim).lois.portee_temoin_max) or not sim.voit_ia(x, e):
			continue
		if temoin.is_empty() or Grille.distance(x.pos, pos) < Grille.distance(temoin.pos, pos):
			temoin = x
	if temoin.is_empty():
		return false
	var jet_temoin := sim.des.jet("1d20") + int(temoin.corps.stats.perception) / 2
	var jet_joueur := sim.des.jet("1d20") + sim.regles.niveau(e.competences_eff, "discretion") + (int(SimTerrain._cycle(sim).get("discretion_nuit", 4)) if SimTerrain.est_nuit(sim) else 0)   # Cycle jour-nuit : Discrétion +4 la nuit
	if jet_joueur >= jet_temoin:
		EventBus.emettre(&"journal", [&"journal.infraction_ignoree", {}])
		return false
	var cons := str(loi.consequence)
	var sev: Dictionary = SimTerritoire._ry(sim).lois.severite
	var texte := ""
	var detail := ""
	if cons.begins_with("amende:"):
		var n := int(cons.split(":")[1])
		if int(e.or) >= n:
			e.or = int(e.or) - n
		elif not e.sac.is_empty():
			e.sac.erase(e.sac[0])
		texte = "consequence.amende"
		detail = "(%d or)" % n
		_baisser_reputation(sim, e, str(roy.id), int(sev.amende))
	elif cons == "confiscation":
		if not uid.is_empty() and uid in e.sac:
			e.sac.erase(uid)
			e.ratelier.erase(uid)
		texte = "consequence.confiscation"
		_baisser_reputation(sim, e, str(roy.id), int(sev.confiscation))
	else:
		for x in sim.vivants():
			if x.camp == "civil" and str(x.get("royaume", "")) == str(roy.id) and x.ai_profile == "garde":
				x.social.relations[e.id] = -100
		texte = "consequence.gardes_hostiles"
		_baisser_reputation(sim, e, str(roy.id), int(sev.gardes_hostiles))
	var loi_txt: String = "loi.meurtre" if cible == "meurtre" else ("loi.vol" if cible == "vol" else "loi.objet")
	EventBus.emettre(&"journal", [&"journal.infraction", {"royaume": roy.nom, "loi": loi_txt, "consequence": texte, "objet": cible, "detail": detail}])
	return true


static func _baisser_reputation(sim: Simulation, e: Dictionary, roy_id: String, n: int) -> void:
	if not e.has("reputations"):
		e["reputations"] = {}
	e.reputations[roy_id] = clampi(int(e.reputations.get(roy_id, 0)) - n, -100, 100)


## Les royaumes voisins du territoire (à moins de rayon_voisin cellules d'une cellule revendiquée).
static func royaumes_voisins(sim: Simulation) -> Array:
	var res: Array = []
	if sim.monde == null:
		return res
	var r := int(SimTerritoire._ry(sim).pnj.rayon_voisin)
	var vus: Dictionary = {}
	for cell in sim.monde.claims.keys():
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var roy := sim.monde.surface.royaume_de(cell + Vector2i(dx, dy))
				if not roy.is_empty() and not vus.has(str(roy.id)):
					vus[str(roy.id)] = true
					res.append(roy)
	return res


static func relation_royaume(sim: Simulation, e: Dictionary, roy: Dictionary) -> String:
	var rep := int(e.get("reputations", {}).get(str(roy.id), 0))
	if str(sim.territoire.accords.get(str(roy.id), "")) == "alliance":
		return "allie"
	if rep <= -30:
		return "hostile"
	if rep < 0:
		return "tension"
	if rep >= 30:
		return "cordial"
	return "neutre"


## Proposer un accord à un royaume voisin (Gouvernance, lois et diplomatie) : réputation et régime décident.
static func proposer_accord(sim: Simulation, e: Dictionary, roy_id: String, type: String) -> bool:
	var roy: Dictionary = {}
	for v in royaumes_voisins(sim):
		if str(v.id) == roy_id:
			roy = v
	if roy.is_empty():
		return false
	var ac: Dictionary = SimTerritoire._ry(sim).accords
	var rep := int(e.get("reputations", {}).get(roy_id, 0))
	var gouv := str(roy.government_type)
	var ok := false
	match type:
		"commercial":
			ok = rep >= int(ac.commercial.reputation)
		"non_agression":
			ok = rep >= int(ac.non_agression.reputation) and not (gouv in ac.non_agression.exclut)
		"alliance":
			ok = rep >= int(ac.alliance.reputation) and (gouv in ac.alliance.gouvernances)
		"tribut":
			ok = true
			type = "tribut_recoit" if defense_totale(sim) > float(SimTerritoire._ry(sim).pnj.force_par_cellule) * float(roy.territory_cells.size()) else "tribut_paie"
	if not ok:
		EventBus.emettre(&"journal", [&"journal.accord_refuse", {"nom": roy.nom, "accord": "accord." + type}])
		return false
	sim.territoire.accords[roy_id] = type
	EventBus.emettre(&"journal", [&"journal.accord", {"nom": roy.nom, "accord": "accord." + type}])
	return true


## Les tributs hebdomadaires et les renforts d'alliance.
static func _semaine_accords(sim: Simulation) -> void:
	var ac: Dictionary = SimTerritoire._ry(sim).accords
	for roy_id in sim.territoire.accords.keys():
		match str(sim.territoire.accords[roy_id]):
			"tribut_paie":
				var n := int(ac.tribut.paie)
				if int(sim.territoire.tresor) >= n:
					sim.territoire.tresor = int(sim.territoire.tresor) - n
					EventBus.emettre(&"journal", [&"journal.tribut", {"n": n, "sens": "tribut.verse"}])
				else:
					sim.territoire.accords.erase(roy_id)   # tribut impayé : la paix tombe
			"tribut_recoit":
				sim.territoire.tresor = int(sim.territoire.tresor) + int(ac.tribut.recoit)
				EventBus.emettre(&"journal", [&"journal.tribut", {"n": int(ac.tribut.recoit), "sens": "tribut.recu"}])


# ---------------------------------------------------------------- défense, raids, gouvernance (étape 10.3)

static func changer_gouvernance(sim: Simulation, id: String) -> bool:
	if not bool(sim.territoire.royaume):
		EventBus.emettre(&"journal", [&"journal.gouvernance_refuse", {}])
		return false
	if not GameData.catalogues.governments.has(id) or id == str(sim.territoire.gouvernance) or id == str(sim.territoire.gouvernance_cible):
		return false
	var gv: Dictionary = SimTerritoire._ry(sim).gouvernance
	sim.territoire.gouvernance_cible = id
	sim.territoire.transition = int(gv.transition_semaines)
	for x in SimTerritoire.residents(sim):
		x.humeur = int(x.get("humeur", SimTerritoire._ry(sim).humeur_base)) + int(gv.malus_humeur)
	EventBus.emettre(&"journal", [&"journal.gouvernance", {"gouv": GameData.entree("governments", id).name_key}])
	return true


## La défense totale (Défense et raids) : gardes × niveau × équipement + tourelles + murs, × gouvernance.
static func defense_totale(sim: Simulation) -> float:
	if sim.monde == null:
		return 0.0
	var d: Dictionary = SimTerritoire._ry(sim).defense
	var total := 0.0
	var dette := int(sim.territoire.semaines_dette)
	if dette < int(d.dette_gardes):
		for x in SimTerritoire.residents(sim):
			if str(x.assignation.fonction) != "garde":
				continue
			# « niveau mêlée » de la note = la compétence de l'arme que le garde tient (mains nues sans arme) ;
			# « melee » n'est pas une compétence du jeu — le niveau valait toujours 0.
			var fonct_g: Dictionary = sim.fonctionnalites.get(str(Etres.arme(x, sim.items).get("functionality", "")), {})
			var niv := sim.regles.niveau(x.competences_eff, str(fonct_g.get("combat_skill", "mains_nues")))
			total += float(d.garde_base) * (1.0 + float(niv) / float(d.niveau_div)) * (1.0 + float(d.equipement_par_piece) * float(x.equipement.size()))
	var murs := 0
	var tourelles := 0
	if sim.lieu == "camp":
		for gi in sim.grille.meubles.keys():
			if str(GameData.entree("meubles", str(sim.grille.meubles[gi])).type_meuble) == "tourelle" and sim.monde.claims.has(SimCamp._cell_de(sim, sim.grille.pos_de(int(gi)))):
				tourelles += 1
		for i in sim.grille.contenu.size():
			if sim.grille.contenu[i] > 0 and sim.grille.contenu_ids[sim.grille.contenu[i]] == "mur_construit" and sim.monde.claims.has(SimCamp._cell_de(sim, sim.grille.pos_de(i))):
				murs += 1
	if dette < int(d.dette_tourelles):
		total += float(d.tourelle) * float(tourelles)
	total += minf(float(d.mur_max), float(murs) / float(d.mur_par))
	if not str(sim.territoire.gouvernance).is_empty():
		total *= float(GameData.entree("governments", str(sim.territoire.gouvernance)).defense_mult)
	for roy_id in sim.territoire.accords.keys():
		if str(sim.territoire.accords[roy_id]) == "alliance":
			total += float(SimTerritoire._ry(sim).accords.alliance.defense)
	return total


## La valeur du territoire (Raids et menaces) : ce qui attire les pillards.
static func valeur_territoire(sim: Simulation) -> float:
	if sim.monde == null:
		return 0.0
	var r: Dictionary = SimTerritoire._ry(sim).raids
	var stocks := 0
	for n in sim.territoire.stocks.values():
		stocks += int(n)
	return float(int(sim.territoire.tresor) + int(sim.territoire.caisse)) + float(r.valeur_par_stock) * float(stocks) + float(r.valeur_par_structure) * float(SimTerritoire._structures_speciales(sim)) + float(r.valeur_par_cellule) * float(sim.monde.claims.size())


## Le jet hebdomadaire de raid : probabilité par corruption, valeur et réputation ; force = valeur × aléa / échelle.
static func _jet_raid(sim: Simulation, e: Dictionary, tick: int) -> void:
	if sim.monde == null or not sim.territoire.raid.is_empty() or str(sim.territoire.get("id", "joueur")) != "joueur":
		return   # une ville n'est pas raidée par ce jet : ses guerres viendront avec les royaumes (programme D)
	var r: Dictionary = SimTerritoire._ry(sim).raids
	var rep := int(e.get("reputations", {}).get("_globale", 0))
	var valeur := valeur_territoire(sim)
	var proba := clampf(float(r.proba_base) + float(r.par_corruption) * sim.monde.corruption_de(sim.monde.cellule_camp) / 100.0 + float(r.par_valeur) * valeur + float(r.par_reputation) * float(maxi(0, -rep)), 0.0, float(r.proba_max))
	var hostile: Dictionary = {}
	if bool(sim.territoire.royaume):   # les royaumes hostiles n'attaquent qu'un royaume reconnu (Raids et menaces)
		for roy in royaumes_voisins(sim):
			var accord := str(sim.territoire.accords.get(str(roy.id), ""))
			if relation_royaume(sim, e, roy) == "hostile" and not sim.monde.vacances.has(str(roy.id)) and not (accord in ["non_agression", "alliance", "tribut_paie", "tribut_recoit"]):
				proba = minf(float(r.proba_max), proba + float(SimTerritoire._ry(sim).accords.raid_hostile))
				hostile = roy
	var reconquete := ""   # un royaume d'origine hostile veut reprendre son village (Conquête de village)
	for nom in sim.monde.villages.keys():
		var info: Dictionary = sim.monde.villages[nom]
		if str(info.get("conquis_par", "")) == e.id:
			var roy0 := sim.monde.surface.royaume_de(info.cellule)
			if not roy0.is_empty() and relation_royaume(sim, e, roy0) == "hostile" and not sim.monde.vacances.has(str(roy0.id)):
				proba = minf(float(r.proba_max), proba + float(SimTerritoire._ry(sim).conquete.raid_reconquete))
				reconquete = nom
				hostile = roy0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "raid", sim.monde.semaine_courante])
	if rng.randf() >= proba:
		return
	var force := valeur * rng.randf_range(float(r.force_bornes[0]), float(r.force_bornes[1])) / float(r.echelle_force)
	if not hostile.is_empty():
		EventBus.emettre(&"journal", [&"journal.raid_royaume", {"nom": hostile.nom}])
	if sim.lieu == "camp":
		_lancer_raid_reel(sim, force, tick)
	else:
		_resoudre_raid_abstrait(sim, force, tick)
		if not reconquete.is_empty() and not bool(sim.territoire.dernier_raid.get("victoire", true)):
			_rendre_village(sim, reconquete)


## Les pertes d'un raid (jamais de wipe) : stocks, caisse, structures de la fenêtre.
static func _appliquer_pertes(sim: Simulation, perte: float) -> int:
	for cle in sim.territoire.stocks.keys():
		sim.territoire.stocks[cle] = int(floor(float(sim.territoire.stocks[cle]) * (1.0 - perte)))
		if int(sim.territoire.stocks[cle]) <= 0:
			sim.territoire.stocks.erase(cle)
	sim.territoire.caisse = int(floor(float(sim.territoire.caisse) * (1.0 - perte)))
	var detruites := 0
	if sim.lieu == "camp":
		var cibles: Array = []
		for gi in sim.grille.stations_fixes.keys():
			if sim.monde.claims.has(SimCamp._cell_de(sim, sim.grille.pos_de(int(gi)))):
				cibles.append(int(gi))
		var n := int(floor(perte * float(cibles.size())))
		for k in n:
			var idx: int = cibles[k]
			var pos := sim.grille.pos_de(idx)
			sim.grille.contenu[idx] = 0
			sim.grille.marquer(pos)
			sim.grille.stations_fixes.erase(idx)
			detruites += 1
			EventBus.emettre(&"tile_changed", [pos])
	return detruites


## Joueur absent : un seul jet, force contre défense (Abstraction hors-site).
static func _resoudre_raid_abstrait(sim: Simulation, force: float, tick: int) -> void:
	var r: Dictionary = SimTerritoire._ry(sim).raids
	var defense := defense_totale(sim)
	var victoire := defense >= force
	var perte := float(r.perte_victoire) if victoire else clampf((force - defense) / maxf(force, 0.001), float(r.perte_bornes[0]), float(r.perte_bornes[1]))
	var detruites := _appliquer_pertes(sim, perte)
	sim.territoire.dernier_raid = {"force": snappedf(force, 0.1), "defense": snappedf(defense, 0.1), "victoire": victoire, "perte": perte, "tick": tick}
	EventBus.emettre(&"journal", [&"journal.raid_abstrait", {"force": "%.1f" % force, "defense": "%.1f" % defense, "issue": "ui.gestion.victoire" if victoire else "ui.gestion.defaite"}])
	if victoire:
		EventBus.emettre(&"journal", [&"journal.raid_mineur", {}])
	else:
		EventBus.emettre(&"journal", [&"journal.raid_pertes", {"perte": int(round(perte * 100.0)), "structures": detruites}])
	EventBus.emettre(&"raid_resolved", [victoire, perte])


## Joueur présent : des assaillants apparaissent au bord de la cellule du camp, profil `assaillant`.
static func _lancer_raid_reel(sim: Simulation, force: float, tick: int) -> void:
	var r: Dictionary = SimTerritoire._ry(sim).raids
	var n := clampi(roundi(force / 2.0), int(r.assaillants_bornes[0]), int(r.assaillants_bornes[1]))
	var cell: Vector2i = sim.monde.cellule_camp
	var coeur: Vector2i = sim.camp_sauve.get("entree", sim.monde.pos_monde(cell, Vector2i(sim.monde.taille / 2, sim.monde.taille / 2)))
	var bord: Array[Vector2i] = []
	for i in sim.monde.taille:
		for p in [Vector2i(0, i), Vector2i(sim.monde.taille - 1, i), Vector2i(i, 0), Vector2i(i, sim.monde.taille - 1)]:
			var q := sim.monde.pos_monde(cell, p)
			if sim.grille.dans(q) and not sim.grille.bloque_passage(q) and sim.grille.occupant(q).is_empty():
				bord.append(q)
	if bord.is_empty():
		_resoudre_raid_abstrait(sim, force, tick)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "raid_reel", tick])
	var depart: Vector2i = bord[rng.randi() % bord.size()]
	var ids: Array = []
	for k in n:
		var pos := depart
		for essai in 30:
			var c := depart + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
			if sim.grille.dans(c) and not sim.grille.bloque_passage(c) and sim.grille.occupant(c).is_empty():
				pos = c
				break
		var x: Dictionary = SimObjets.ajouter(sim, str(r.chef) if k == 0 else str(r.creature), pos, "ia")
		if x.is_empty():
			continue
		x.camp = "raid"
		x.ai_profile = "assaillant"
		x.ancre = coeur
		x["raid"] = true
		ids.append(x.id)
	sim.territoire.raid = {"fin": tick + int(r.duree_ticks), "n": ids.size(), "ids": ids, "force": force}
	EventBus.emettre(&"journal", [&"journal.raid_commence", {"n": ids.size(), "force": "%.1f" % force}])


## Le raid réel se termine quand tous sont tombés ou à l'échéance : victoire si la moitié au moins est tombée.
static func _tiquer_raid(sim: Simulation, tick: int) -> void:
	if sim.territoire.raid.is_empty() or sim.lieu != "camp":
		return
	var rd: Dictionary = sim.territoire.raid
	var vivants_raid := 0
	for id in rd.ids:
		if sim.entites.has(str(id)) and bool(sim.entites[str(id)].vivant):
			vivants_raid += 1
	if vivants_raid > 0 and tick < int(rd.fin):
		_tirs_de_tourelles(sim, tick)
		return
	var r: Dictionary = SimTerritoire._ry(sim).raids
	var n := maxi(1, int(rd.n))
	var morts := n - vivants_raid
	var victoire := morts * 2 >= n
	var perte := float(r.perte_victoire) if victoire else clampf(float(vivants_raid) / float(n) * float(r.perte_bornes[1]), float(r.perte_bornes[0]), float(r.perte_bornes[1]))
	var detruites := _appliquer_pertes(sim, perte)
	for id in rd.ids:   # les survivants restent hostiles sur place
		if sim.entites.has(str(id)):
			sim.entites[str(id)].erase("raid")
			sim.entites[str(id)].ai_profile = "hostile"
			sim.entites[str(id)].ancre = sim.entites[str(id)].pos
	sim.territoire.dernier_raid = {"force": snappedf(float(rd.force), 0.1), "defense": snappedf(defense_totale(sim), 0.1), "victoire": victoire, "perte": perte, "tick": tick}
	sim.territoire.raid = {}
	EventBus.emettre(&"journal", [&"journal.raid_fin", {"issue": "ui.gestion.victoire" if victoire else "ui.gestion.defaite", "morts": morts, "n": n}])
	if not victoire:
		EventBus.emettre(&"journal", [&"journal.raid_pertes", {"perte": int(round(perte * 100.0)), "structures": detruites}])
	EventBus.emettre(&"raid_resolved", [victoire, perte])


## Les tourelles tirent pendant un raid réel (Défense et raids) : l'assaillant le plus proche à portée, en ligne de vue.
static func _tirs_de_tourelles(sim: Simulation, tick: int) -> void:
	var d: Dictionary = SimTerritoire._ry(sim).defense
	var tt: Dictionary = d.get("tourelle_tir", {})
	if tt.is_empty() or int(sim.territoire.semaines_dette) >= int(d.dette_tourelles):
		return
	if tick < int(sim.territoire.raid.get("prochain_tir", 0)):
		return
	sim.territoire.raid["prochain_tir"] = tick + int(tt.cadence_ticks)
	for gi in sim.grille.meubles.keys():
		if str(GameData.entree("meubles", str(sim.grille.meubles[gi])).type_meuble) != "tourelle":
			continue
		var pos := sim.grille.pos_de(int(gi))
		if not sim.monde.claims.has(SimCamp._cell_de(sim, pos)):
			continue
		var cible: Dictionary = {}
		var dmin := int(tt.portee) + 1
		for x in sim.vivants():
			if x.camp != "raid":
				continue
			var dist := Grille.distance(pos, x.pos)
			if dist < dmin and sim.grille.ligne_de_vue(pos, x.pos):
				dmin = dist
				cible = x
		if cible.is_empty():
			continue
		var deg := sim.des.jet(str(tt.degats))
		sim._appliquer_degats(cible, deg, "tourelle", {"type": str(tt.get("type", "perforant")), "element": {}, "tourelle": true})
		EventBus.emettre(&"journal", [&"journal.tourelle_tire", {"nom": cible.name_key, "degats": deg}])


## L'assaut : vers le cœur du claim ; un mur construit qui bloque se creuse.
static func _ia_assaut(sim: Simulation, e: Dictionary, tick: int) -> void:
	var coeur: Vector2i = e.ancre
	if Grille.distance(e.pos, coeur) <= 1:
		sim._attendre(e, tick)
		return
	var avant: Vector2i = e.pos
	sim._ia_pas_routine(e, coeur, tick)
	if e.pos != avant:
		return
	var meilleur := Vector2i(-1, -1)
	var dmin := Grille.distance(e.pos, coeur)
	for d in Grille.DIRS:
		var q: Vector2i = e.pos + d
		if sim.grille.dans(q) and Grille.distance(q, coeur) < dmin and "construit" in sim.grille.contenu_de(q).get("tags", []) and "destructible" in sim.grille.contenu_de(q).get("tags", []):
			dmin = Grille.distance(q, coeur)
			meilleur = q
	if meilleur != Vector2i(-1, -1):
		SimTerrain._creuser(sim, e, meilleur, tick)


# ---------------------------------------------------------------- parcelles et boutique passive (étape 10.2)
