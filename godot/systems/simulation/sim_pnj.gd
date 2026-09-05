class_name SimPnj
extends RefCounted
## Les PNJ : dialogue, commerce, traits, histoires et souhaits, cadeaux, opinions ; compagnons et recrutement ; échanges, ordres, apprivoisement, résurrection, âge ; quêtes et guildes ; relations et réputation.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


## La réplique d'ambiance d'un PNJ pour le joueur : tirage pondéré parmi les gabarits dont les
## conditions matchent, anti-répétition sur les 3 dernières.
static func replique(sim: Simulation, pnj: Dictionary, j: Dictionary) -> String:
	var rel := int(pnj.get("social", {}).get("relations", {}).get(j.id, 0))
	var ph: String = SimTerrain.phase(sim)
	var met: String = SimTerrain.meteo(sim, sim.monde.cellule_de(pnj.pos)) if (sim.monde != null and sim.lieu == "camp") else "clair"
	var candidats: Array = []
	var total := 0.0
	var recentes: Array = pnj.get("dernieres_repliques", [])
	for did in GameData.catalogues.dialogue.keys():
		var d: Dictionary = GameData.catalogues.dialogue[did]
		var c: Dictionary = d.conditions
		if c.get("metier") != null and str(c.metier) != str(pnj.get("fonction", "")):
			continue
		if c.get("phase") != null and str(c.phase) != ph:
			continue
		if c.get("meteo") != null and str(c.meteo) != met:
			continue
		if c.get("relation_min") != null and rel < int(c.relation_min):
			continue
		if c.get("relation_max") != null and rel > int(c.relation_max):
			continue
		if c.get("tag") != null and not (str(c.tag) in pnj.get("tags", [])):   # un tag que le PNJ doit porter (l'itinérant, Villes B3)
			continue
		if c.get("trait") != null and not (str(c.trait) in pnj.get("traits", [])):   # un trait de caractère (PNJ distincts)
			continue
		if c.get("gouvernance") != null and str(SimRoyaumes.royaume_par_id(sim, str(pnj.get("royaume", ""))).get("government_type", "")) != str(c.gouvernance):   # le sujet parle de son régime (D)
			continue
		if str(d.text_key) == "rumeur_royaume" and (str(pnj.get("royaume", "")).is_empty() or SimRoyaumes.etat_royaume(sim, str(pnj.get("royaume", ""))).get("journal", []).is_empty()):
			continue
		if c.get("souhait_realise") != null and bool(c.souhait_realise) != bool(pnj.get("souhait_realise", false)):
			continue
		if str(d.text_key) == "histoire" and not pnj.has("histoire"):
			continue
		if str(d.text_key) == "opinion" and pnj.get("social", {}).get("opinions", {}).is_empty():
			continue
		if c.get("fete") != null and bool(c.fete) != (not SimVilles.fete_de(sim, pnj).is_empty()):   # Calendrier : un jour de fête, de marché, d'anniversaire
			continue
		if c.get("marche") != null and bool(c.marche) != SimVilles.jour_de_marche_de(sim, pnj):
			continue
		if c.get("anniversaire") != null and bool(c.anniversaire) != _anniversaire_aujourdhui(sim, pnj):
			continue
		if did in recentes:
			continue
		candidats.append(d)
		total += float(d.get("poids", 1))
	if candidats.is_empty():
		return "dialogue.salut.text"
	var t := sim.des.reel() * total
	for d in candidats:
		t -= float(d.get("poids", 1))
		if t <= 0.0:
			recentes.append(d.id)
			while recentes.size() > 3:
				recentes.pop_front()
			pnj["dernieres_repliques"] = recentes
			return str(d.text_key)
	return str(candidats.back().text_key)


# ---------------------------------------------------------------- les PNJ distincts (C — PNJ — traits, histoires et souhaits, 2026-09-05)

## Ce qui distingue un PNJ d'un autre de même fiche : deux traits qui ne s'excluent pas, un souhait, une histoire,
## une apparence qui dit son âge. Tiré à sa graine, une fois.
static func _distinguer_pnj(sim: Simulation, e: Dictionary, rng: RandomNumberGenerator) -> void:
	var pc: Dictionary = sim.regles.r.get("pnj", {})
	var traits: Dictionary = GameData.catalogues.get("traits", {})
	var ids: Array = traits.keys()
	ids.sort()
	var pris: Array = []
	var essais := 0
	while pris.size() < int(pc.get("traits_par_pnj", 2)) and essais < 20 and not ids.is_empty():
		essais += 1
		var tid := str(ids[rng.randi_range(0, ids.size() - 1)])
		if tid in pris:
			continue
		var exclu := false
		for autre in pris:
			if tid in traits[autre].get("exclut", []) or autre in traits[tid].get("exclut", []):
				exclu = true
		if not exclu:
			pris.append(tid)
	e["traits"] = pris
	e["humeur"] = clampi(int(e.get("humeur", SimTerritoire._ry(sim).humeur_base)) + int(trait_somme(sim, e, "humeur")), 0, 100)
	# Le souhait : parmi ceux dont les conditions matchent (fonction, trait).
	var souhaits: Dictionary = GameData.catalogues.get("souhaits", {})
	var candidats: Array = []
	for sid in souhaits.keys():
		if _conditions_pnj(sim, souhaits[sid].get("conditions", {}), e):
			candidats.append(str(sid))
	candidats.sort()
	if not candidats.is_empty():
		e["souhait"] = str(candidats[rng.randi_range(0, candidats.size() - 1)])
	# L'histoire : un gabarit pondéré, ses paramètres fixés une fois.
	var histoires: Dictionary = GameData.catalogues.get("histoires", {})
	var hids: Array = []
	var total := 0.0
	for hid in histoires.keys():
		if _conditions_pnj(sim, histoires[hid].get("conditions", {}), e):
			hids.append(str(hid))
	hids.sort()
	for hid in hids:
		total += float(histoires[hid].get("poids", 1))
	var t := rng.randf() * total
	for hid in hids:
		t -= float(histoires[hid].get("poids", 1))
		if t <= 0.0:
			e["histoire"] = {"cle": str(histoires[hid].text_key), "params": {"prenom": str(e.nom.get("prenom", "")), "ville": str(e.get("village", "")), "ville_natale": _ville_natale(sim, e, rng), "metier": "function.%s.name" % str(e.get("fonction", "oisif")), "age": int(e.get("age", 30))}}
			break
	# L'âge se voit : les cheveux grisonnent, l'enfant est petit.
	var ap: Dictionary = e.get("apparence", {})
	if not ap.is_empty():
		var ag: Dictionary = sim.regles.r.age
		if float(e.get("age", 30)) >= float(ag.age):
			ap["teinte_cheveux"] = "neige" if float(e.age) >= float(ag.age) + float(ag.tranche) else "argent"
		elif float(e.get("age", 30)) < float(ag.adulte):
			ap["taille"] = "petite"


## Une ville natale pour l'histoire : une agglomération à trente cellules, sinon la sienne.
static func _ville_natale(sim: Simulation, e: Dictionary, rng: RandomNumberGenerator) -> String:
	if sim.monde == null:
		return str(e.get("village", ""))
	var c0 := sim.monde.cellule_de(e.pos)
	for essai in 12:
		var c := c0 + Vector2i(rng.randi_range(-30, 30), rng.randi_range(-30, 30))
		if c != c0 and sim.monde.surface.terre_a(c) and bool(sim.monde.surface.poi_de(c).get("village", false)):
			return str(sim.monde.surface.fiche_agglomeration(c).get("nom", ""))
	return str(e.get("village", ""))


## Les conditions d'un souhait ou d'une histoire : fonction, trait (nul = toujours).
static func _conditions_pnj(sim: Simulation, c: Dictionary, e: Dictionary) -> bool:
	if c.get("fonction") != null and str(c.fonction) != str(e.get("fonction", "")):
		return false
	if c.get("trait") != null and not (str(c.trait) in e.get("traits", [])):
		return false
	return true


## Le produit des effets multiplicatifs d'un nom sur les traits d'un être (1 sans trait).
static func facteur_trait(sim: Simulation, e: Dictionary, cle: String) -> float:
	var f := 1.0
	var traits: Dictionary = GameData.catalogues.get("traits", {})
	for tid in e.get("traits", []):
		f *= float(traits.get(str(tid), {}).get("effets", {}).get(cle, 1.0))
	return f


## La somme des effets additifs d'un nom sur les traits d'un être (0 sans trait).
static func trait_somme(sim: Simulation, e: Dictionary, cle: String) -> float:
	var s := 0.0
	var traits: Dictionary = GameData.catalogues.get("traits", {})
	for tid in e.get("traits", []):
		s += float(traits.get(str(tid), {}).get("effets", {}).get(cle, 0.0))
	return s


## Un PNJ aime-t-il recevoir cet objet ? (les cadeaux de ses traits : un type ou un tag de l'objet)
static func aime_cadeau(sim: Simulation, pnj: Dictionary, it: Dictionary) -> bool:
	var traits: Dictionary = GameData.catalogues.get("traits", {})
	for tid in pnj.get("traits", []):
		for c in traits.get(str(tid), {}).get("cadeaux", []):
			if str(c) == str(it.get("type", "")) or (str(c) in it.get("tags", [])) or (str(c) == "nourriture" and float(it.get("nutrition", 0)) > 0.0):
				return true
	return false


## Offrir un cadeau (Dialogue PNJ) : l'objet passe au PNJ ; la relation monte selon sa valeur, son goût, son souhait.
static func _offrir(sim: Simulation, e: Dictionary, pnj_id: String, uid: String, tick: int) -> bool:
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	var it: Dictionary = sim.items.get(uid, {})
	if pnj.is_empty() or it.is_empty() or not (uid in e.sac) or Grille.distance(e.pos, pnj.pos) > 2 or not ("civil" in pnj.get("tags", [])):
		return false
	var cc: Dictionary = sim.regles.r.get("pnj", {}).get("cadeau", {"relation_base": 3, "relation_par_valeur": 0.1, "relation_max": 15, "bonus_aime": 8})
	var valeur := float(prix_suggere(sim, uid, {}, e).prix)
	var gain := mini(int(cc.relation_max), int(cc.relation_base) + int(round(valeur * float(cc.relation_par_valeur))))
	if aime_cadeau(sim, pnj, it):
		gain += int(cc.bonus_aime)
	gain = maxi(1, int(round(float(gain) * facteur_trait(sim, pnj, "relation_mult"))))
	e.sac.erase(uid)
	if pnj.has("sac"):
		pnj.sac.append(uid)
	else:
		pnj["sac"] = [uid]
	pnj.social.relations[e.id] = clampi(int(pnj.social.relations.get(e.id, 0)) + gain, -100, 100)
	EventBus.emettre(&"journal", [&"journal.cadeau", {"nom": pnj.name_key, "objet": SimObjets.nom_objet(sim, uid), "n": gain}])
	var sid := str(pnj.get("souhait", ""))
	if not sid.is_empty() and not bool(pnj.get("souhait_realise", false)) and GameData.catalogues.souhaits.has(sid) and (str(it.get("base", "")) in GameData.filtrer("items", GameData.catalogues.souhaits[sid].filtre)):
		var bonus := int(GameData.catalogues.souhaits[sid].get("relation", 25))
		pnj["souhait_realise"] = true
		pnj.social.relations[e.id] = clampi(int(pnj.social.relations[e.id]) + bonus, -100, 100)
		EventBus.emettre(&"journal", [&"journal.souhait_realise", {"nom": pnj.name_key, "souhait": "souhait.%s.name" % sid, "n": bonus}])
	e.compteur = tick + int(sim.regles.r.actions.objet)
	return true


## Les opinions d'un PNJ sur d'autres : une relation avec un ou deux voisins de son quartier, tirée de leurs signes et
## de leurs traits (les époux s'aiment). Appelé à la formation des familles.
static func _former_opinions(sim: Simulation, cell: Vector2i, v: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "opinions", cell])
	var gens: Array = []
	for x in sim.vivants():
		if str(x.get("village", "")) == str(v.nom) and x.has("traits") and sim.monde.cellule_de(x.pos) == cell:
			gens.append(x)
	if gens.size() < 2:
		return
	var n_op := int(sim.regles.r.get("pnj", {}).get("opinions_par_pnj", 2))
	var traits: Dictionary = GameData.catalogues.get("traits", {})
	for x in gens:
		if not x.social.has("opinions"):
			x.social["opinions"] = {}
		var conjoint := str(x.get("family", {}).get("spouse", ""))
		if not conjoint.is_empty():
			x.social.opinions[conjoint] = 60
		for k in n_op:
			var y: Dictionary = gens[rng.randi_range(0, gens.size() - 1)]
			if y.id == x.id or x.social.opinions.has(y.id):
				continue
			var score := rng.randi_range(-10, 10)
			for tx in x.get("traits", []):
				if tx in y.get("traits", []):
					score += 15   # les mêmes travers s'entendent
				if str(tx) in traits.get(str(y.get("traits", [""])[0]), {}).get("exclut", []):
					score -= 15   # l'avare et le généreux, le bavard et le taciturne
			var sx: Dictionary = x.get("signe", {})
			var sy: Dictionary = y.get("signe", {})
			if not sx.is_empty() and not sy.is_empty() and str(sx.get("element", "")) == str(sy.get("element", "")):
				score += 10
			x.social.opinions[y.id] = clampi(score, -100, 100)


## C'est l'anniversaire du PNJ ? (mois et jour tirés de son identifiant, Calendrier)
static func _anniversaire_aujourdhui(sim: Simulation, pnj: Dictionary) -> bool:
	if sim.monde == null or sim.lieu != "camp":
		return false
	var a: Dictionary = pnj.get("anniversaire", Calendrier.anniversaire(str(pnj.id)))
	var d: Dictionary = SimVilles.date_courante(sim)
	return str(a.mois) == str(d.mois) and int(a.jour) == int(d.jour_mois)


## Parler : la réplique, +1 de relation une fois par jour et par PNJ, +1 sur un jet de Charisme.
static func _parler(sim: Simulation, e: Dictionary, pnj_id: String, tick: int) -> bool:
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	if pnj.is_empty() or not pnj.vivant or not ("civil" in pnj.get("tags", [])) or Grille.distance(e.pos, pnj.pos) > 2:
		return false
	var texte := replique(sim, pnj, e)
	EventBus.emettre(&"journal", [&"journal.parle", {"nom": pnj.name_key, "texte": texte}])
	_livraisons(sim, e, pnj)
	var jour := int(tick / int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000)))
	if int(pnj.get("dernier_parler_jour", -1)) != jour:
		pnj["dernier_parler_jour"] = jour
		var cm: Dictionary = sim.regles.r.commerce
		var gain := int(cm.parler_relation)
		if sim.des.jet("1d20") + int(e.stats_eff.charisme) / 4 >= int(cm.parler_charisme_dd):
			gain += int(cm.parler_bonus)
		gain = maxi(1, int(round(float(gain) * facteur_trait(sim, pnj, "relation_mult"))))   # le méfiant se lie lentement, le jovial vite (traits)
		pnj.social.relations[e.id] = clampi(int(pnj.social.relations.get(e.id, 0)) + gain, -100, 100)
		EventBus.emettre(&"journal", [&"journal.relation", {"nom": pnj.name_key, "n": int(pnj.social.relations[e.id])}])
	_rumeur(sim, pnj, e, tick)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	return true


## Le prix suggéré d'un objet face à un PNJ, avec le détail du calcul (Prix suggéré).
static func prix_suggere(sim: Simulation, uid: String, pnj: Dictionary, acheteur: Dictionary) -> Dictionary:
	var cm: Dictionary = sim.regles.r.commerce
	var it: Dictionary = sim.items.get(uid, {})
	var mats: Dictionary = GameData.catalogues.materials
	var base := 0.0
	if it.has("composants"):
		for slot in it.composants.keys():
			base += float(mats.get(str(it.composants[slot].materiau), {}).get("stats", {}).get("valeur_base", 1))
	elif it.get("type", "") == "materiau":
		base = float(mats.get(str(it.materiau), {}).get("stats", {}).get("valeur_base", 1)) * float(it.get("quantite", 1)) / float(cm.marge_artisanat)
	elif it.has("materiau") and mats.has(str(it.materiau)):
		base = float(mats[str(it.materiau)].stats.valeur_base) * float(cm.valeur_par_defaut) / float(cm.marge_artisanat)
	else:
		base = float(it.get("valeur", cm.valeur_par_defaut)) * float(it.get("quantite", 1)) / float(cm.marge_artisanat)
	var qualite := float(it.get("qualite", 1.0)) if it.get("type", "") != "materiau" else 1.0
	var rarete := float(cm.facteur_rarete.get(str(it.get("rarete", "commun")), 1.0))
	rarete += float(cm.bonus_affixe) * float(it.get("affixes", []).size()) + float(cm.bonus_sertissure) * float(it.get("sertissures", {}).get("contenu", []).size())
	var rel := int(pnj.get("social", {}).get("relations", {}).get(acheteur.id, 0))
	var rep := clampf(1.0 + float(rel) / 200.0, float(cm.reputation_bornes[0]), float(cm.reputation_bornes[1]))
	for pal in cm.paliers:
		if rel >= int(pal[0]) and rel <= int(pal[1]):
			rep *= float(pal[2])
	var marche := float(GameData.config("calendrier").marche.prix_mult) if SimVilles.jour_de_marche_de(sim, pnj) else 1.0   # le jour de marché, les prix baissent (Calendrier)
	var economie: float = SimTerritoire.facteur_economie(sim, uid, pnj)   # les stocks de la ville du marchand font ses prix (Villes B3)
	var caractere := facteur_trait(sim, pnj, "prix_mult")   # l'avare vend plus cher, le généreux moins (traits)
	var prix := maxi(1, roundi(base * float(cm.marge_artisanat) * qualite * rarete * rep * marche * economie * caractere))
	return {"prix": prix, "base": snappedf(base, 0.1), "marge": float(cm.marge_artisanat), "qualite": snappedf(qualite, 0.01), "rarete": snappedf(rarete, 0.01), "rep": snappedf(rep, 0.01),
		"marche": marche, "economie": snappedf(economie, 0.01), "achat": maxi(1, roundi(float(prix) * float(cm.achat_ratio)))}


## Acheter un objet du stock d'un marchand.
static func _acheter(sim: Simulation, e: Dictionary, pnj_id: String, uid: String, tick: int) -> bool:
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	if pnj.is_empty() or not (uid in pnj.get("stock", [])) or Grille.distance(e.pos, pnj.pos) > 2:
		return false
	var p := prix_suggere(sim, uid, pnj, e)
	var tarif: float = SimRoyaumes.tarif_de(sim, uid, pnj)
	if tarif >= 1.0:
		EventBus.emettre(&"journal", [&"journal.douane_interdit", {"objet": SimObjets.nom_objet(sim, uid)}])
		return false
	p.prix = maxi(1, roundi(float(p.prix) * (1.0 + tarif)))
	if int(e.or) < int(p.prix):
		EventBus.emettre(&"journal", [&"journal.pas_assez_or", {}])
		return false
	e.or = int(e.or) - int(p.prix)
	pnj.or = int(pnj.or) + int(p.prix)
	if tarif > 0.0:
		EventBus.emettre(&"journal", [&"journal.douane", {"pct": int(round(tarif * 100.0)), "objet": SimObjets.nom_objet(sim, uid)}])
	SimRoyaumes._infraction(sim, e, "objet", str(sim.items[uid].get("base", "")), e.pos, uid)
	pnj.stock.erase(uid)
	e.sac.append(uid)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.achete", {"nom": e.name_key, "objet": SimObjets.nom_objet(sim, uid), "n": int(p.prix)}])
	EventBus.emettre(&"item_sold", [uid, pnj.id, int(p.prix)])
	return true


## Vendre un objet du sac à un marchand : il paie achat_ratio du prix suggéré, s'il a l'or.
static func _vendre(sim: Simulation, e: Dictionary, pnj_id: String, uid: String, tick: int) -> bool:
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	if pnj.is_empty() or not (uid in e.sac) or Grille.distance(e.pos, pnj.pos) > 2 or not ("commerce_possible" in pnj.get("tags", [])):
		return false
	var p := prix_suggere(sim, uid, pnj, e)
	var tarif: float = SimRoyaumes.tarif_de(sim, uid, pnj)
	if tarif >= 1.0:
		EventBus.emettre(&"journal", [&"journal.douane_interdit", {"objet": SimObjets.nom_objet(sim, uid)}])
		return false
	p.achat = maxi(1, roundi(float(p.achat) * (1.0 - tarif)))
	if tarif > 0.0:
		EventBus.emettre(&"journal", [&"journal.douane", {"pct": int(round(tarif * 100.0)), "objet": SimObjets.nom_objet(sim, uid)}])
	if int(pnj.or) < int(p.achat):
		# Troc automatique (Économie — sources et puits) : un objet du stock à ±15 % de la valeur.
		var tol := float(sim.regles.r.commerce.get("troc_tolerance", 0.15))
		for autre in pnj.stock:
			var pa := prix_suggere(sim, str(autre), pnj, e)
			if absf(float(pa.achat) - float(p.achat)) <= float(p.achat) * tol:
				pnj.stock.erase(autre)
				pnj.stock.append(uid)
				e.sac.erase(uid)
				e.ratelier.erase(uid)
				e.sac.append(autre)
				e.compteur = tick + int(sim.regles.r.actions.objet)
				EventBus.emettre(&"journal", [&"journal.troc", {"nom": pnj.name_key, "objet": SimObjets.nom_objet(sim, str(autre))}])
				EventBus.emettre(&"item_sold", [uid, e.id, 0])
				return true
		EventBus.emettre(&"journal", [&"journal.marchand_a_sec", {"nom": pnj.name_key}])
		return false
	pnj.or = int(pnj.or) - int(p.achat)
	e.or = int(e.or) + int(p.achat)
	e.sac.erase(uid)
	e.ratelier.erase(uid)
	pnj.stock.append(uid)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.vend", {"nom": e.name_key, "objet": SimObjets.nom_objet(sim, uid), "n": int(p.achat)}])
	EventBus.emettre(&"item_sold", [uid, e.id, int(p.achat)])
	_progresser_quetes(sim, e, "vendre", [])
	return true


# ---------------------------------------------------------------- territoire : claims, rôles, résidents, semaine (étape 10)

## Places d'escorte (Compagnons) : 1 + Charisme/5 + Leadership/10.
static func places_escorte(sim: Simulation, e: Dictionary) -> int:
	var c: Dictionary = sim.regles.r.compagnons
	return int(c.places_base) + int(e.stats_eff.charisme) / int(c.par_charisme) + sim.regles.niveau(e.competences_eff, "leadership") / int(c.par_leadership) + (1 if SimTalents.a_talent(sim, e, "oeil_du_prix") else 0)


static func compagnons_de(sim: Simulation, e: Dictionary, avec_suiveurs: bool = true) -> Array:
	var res: Array = []
	for x in sim.vivants():
		if str(x.get("maitre", "")) == e.id and (avec_suiveurs or not bool(x.get("suiveur_local", false))):
			res.append(x)
	return res


## Le suiveur territorial (Compagnons) : un résident assigné suit sur le territoire, sans place d'escorte.
static func suiveur_local(sim: Simulation, e: Dictionary, id: String, actif: bool) -> bool:
	var x: Dictionary = sim.entites.get(id, {})
	if x.is_empty() or not x.vivant or Grille.distance(e.pos, x.pos) > 2:
		return false
	if actif:
		if not x.has("assignation") or x.has("maitre"):
			return false
		x["maitre"] = e.id
		x["suiveur_local"] = true
		x["ordre"] = "suivre"
		x["posture"] = "defensive"
		x.ai_profile = "compagnon"
		EventBus.emettre(&"journal", [&"journal.suiveur_local", {"nom": x.name_key}])
		return true
	if not bool(x.get("suiveur_local", false)):
		return false
	_fin_suiveur(sim, x)
	return true


## Il redevient un résident ordinaire : plus de maître, retour au profil civil et à son poste.
static func _fin_suiveur(sim: Simulation, x: Dictionary) -> void:
	x.erase("maitre")
	x.erase("suiveur_local")
	x.erase("ordre")
	x.ai_profile = "civil"
	x.cible = ""
	x.ancre = x.get("poste", x.pos)


## L'escorte qui SUIT le joueur d'un lieu à l'autre (Compagnons, 2026-09-04) : ses compagnons à l'ordre « suis-moi »,
## vivants, présents dans la fenêtre — pas le suiveur territorial, qui refuse de quitter le territoire.
static func _escorte_qui_suit(sim: Simulation, joueur: Dictionary) -> Array:
	var res: Array = []
	if joueur.is_empty():
		return res
	for id in sim.ordre:
		var x: Dictionary = sim.entites.get(id, {})
		if x.is_empty() or not bool(x.vivant) or str(x.get("maitre", "")) != joueur.id:
			continue
		if str(x.get("ordre", "suivre")) != "suivre" or bool(x.get("suiveur_local", false)):
			continue
		res.append(x)
	return res


## L'escorte arrive avec le joueur : chacun sur une tuile libre près de lui, compteur remis, cible oubliée.
static func _placer_escorte(sim: Simulation, joueur: Dictionary, escorte: Array) -> void:
	for x in escorte:
		if sim.entites.has(x.id):
			continue
		var q: Vector2i = SimLieux._tuile_libre_pres(sim, x, joueur.pos)
		if q == Vector2i(-1, -1):
			continue
		x.pos = q
		x.ancre = q
		x.compteur = 0
		x.horloge = "monde"
		x.tick_vigueur = 0
		x.action_en_cours = {}
		x.cible = ""
		x.contact = false
		x.erase("dormant_depuis")
		sim.entites[x.id] = x
		sim.ordre.append(x.id)
		sim.grille.placer(x.id, q)


## Faire d'un être un compagnon du joueur.
static func _devenir_compagnon(sim: Simulation, e: Dictionary, x: Dictionary) -> void:
	x.camp = "joueur"
	x.ai_profile = "compagnon"
	x["maitre"] = e.id
	x["ordre"] = "suivre"
	x.cible = ""
	x.fuite = false
	if not x.has("social"):
		x["social"] = {"culture": "", "relations": {}}
	if not x.social.relations.has(e.id):
		x.social.relations[e.id] = 0
	EventBus.emettre(&"creature_recruited", [x.id, e.id])


## Recruter un PNJ par la relation (recruitable.method relation, seuil, ou faveur du palier 90).
## Qui peut être recruté (designer 2026-09-05 : « sur tous les PNJ ») : un humanoïde vivant, non hostile au joueur, qui
## n'est pas déjà le compagnon de quelqu'un. La relation décide du prix, pas de la possibilité.
static func recrutable(sim: Simulation, e: Dictionary, pnj: Dictionary) -> bool:
	if pnj.is_empty() or not pnj.vivant or pnj.has("maitre") or pnj.controle != "ia":
		return false
	var def: Dictionary = GameData.catalogues.creatures.get(str(pnj.def), {})
	return ("humanoide" in def.get("tags", [])) and not ennemis(sim, e, pnj)


static func _recruter(sim: Simulation, e: Dictionary, pnj_id: String, tick: int) -> bool:
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	if pnj.is_empty() or not pnj.vivant or pnj.has("maitre") or Grille.distance(e.pos, pnj.pos) > 2:
		return false
	var def: Dictionary = GameData.catalogues.creatures.get(str(pnj.def), {})
	var rc: Dictionary = def.get("recruitable", {"method": "jamais"})
	var ok := false
	if str(rc.get("method", "jamais")) == "relation" and relation_de(sim, pnj, e) >= int(rc.get("threshold", 60)):
		ok = true
	if bool(pnj.get("recrutable_hors_condition", false)):
		ok = true
	var prix := 0
	if not ok and recrutable(sim, e, pnj):   # tout PNJ humanoïde non hostile se recrute, contre un prix quand la relation manque (designer 2026-09-05)
		prix = int(sim.regles.r.compagnons.get("prix_recrutement", 40))
		if int(e.get("or", 0)) < prix:
			EventBus.emettre(&"journal", [&"journal.recrutement_prix", {"nom": pnj.name_key, "prix": prix}])
			return false
		ok = true
	if not ok:
		EventBus.emettre(&"journal", [&"journal.pas_recrutable", {"nom": pnj.name_key}])
		return false
	if compagnons_de(sim, e, false).size() >= places_escorte(sim, e):
		EventBus.emettre(&"journal", [&"journal.pas_de_place", {}])
		return false
	if prix > 0:
		e.or = int(e.get("or", 0)) - prix
		pnj.or = int(pnj.get("or", 0)) + prix
	_devenir_compagnon(sim, e, pnj)
	EventBus.emettre(&"journal", [&"journal.recrute", {"nom": pnj.name_key, "places": places_escorte(sim, e)}])
	return true


# ---------------------------------------------------------------- périmètres de récolte (Population et exploitation, 2026-09-04)

## Échange d'équipement avec un compagnon (Compagnons) : donner (il s'équipe s'il peut) ou reprendre (il se déséquipe).
static func echanger(sim: Simulation, e: Dictionary, id: String, uid: String, sens: String) -> bool:
	var x: Dictionary = sim.entites.get(id, {})
	if x.is_empty() or str(x.get("maitre", "")) != e.id or not x.vivant or not sim.items.has(uid):
		return false
	if sens == "donner":
		if not (uid in e.sac):
			return false
		e.sac.erase(uid)
		x.sac.append(uid)
		EventBus.emettre(&"journal", [&"journal.echange_donne", {"nom": x.name_key, "objet": SimObjets.nom_objet(sim, uid)}])
		if not str(sim.items[uid].get("equip_slot", "")).is_empty():
			SimObjets._equiper(sim, x, uid, sim.tick_de(x))
		return true
	if uid in x.sac:
		x.sac.erase(uid)
	else:
		var slot := ""
		for s in x.equipement.keys():
			if str(x.equipement[s]) == uid:
				slot = str(s)
		if slot.is_empty() or not SimObjets._desequiper(sim, x, slot, sim.tick_de(x)):
			return false
		x.sac.erase(uid)
	if uid in x.ratelier:
		x.ratelier.erase(uid)
	e.sac.append(uid)
	EventBus.emettre(&"journal", [&"journal.echange_reprend", {"nom": x.name_key, "objet": SimObjets.nom_objet(sim, uid)}])
	return true


## Désigner une cible à tous ses compagnons (Compagnons : consignes de combat), sans coût de ticks.
static func designer_cible(sim: Simulation, e: Dictionary, cible_id: String) -> bool:
	var c: Dictionary = sim.entites.get(cible_id, {})
	if c.is_empty() or not c.vivant or not ennemis(sim, e, c):
		return false
	var n := 0
	for x in compagnons_de(sim, e):
		if not x.vivant:
			continue
		x["cible_prioritaire"] = cible_id
		x.cible = cible_id
		x.tick_derniere_vue = sim.tick_de(x)
		x.pos_connue = c.pos
		if str(x.get("posture", "defensive")) == "eviter":
			x["posture"] = "defensive"
		sim._engager_combat(x, c)
		n += 1
	if n == 0:
		return false
	EventBus.emettre(&"journal", [&"journal.cible_designee", {"nom": e.name_key, "cible": c.name_key}])
	return true


## Un ordre à un compagnon : sans coût de ticks (Compagnons).
static func ordonner(sim: Simulation, e: Dictionary, id: String, ordre: String) -> bool:
	var x: Dictionary = sim.entites.get(id, {})
	if x.is_empty() or str(x.get("maitre", "")) != e.id or not (ordre in ["suivre", "attendre", "agressive", "defensive", "eviter", "retour", "repli"]):
		return false
	if ordre == "repli":   # consigne de combat : ils lâchent tout et reviennent en évitant
		x.ordre = "suivre"
		x["posture"] = "eviter"
		x.cible = ""
		x.erase("cible_prioritaire")
	elif ordre in ["agressive", "defensive", "eviter"]:   # une posture, pas un déplacement
		x["posture"] = ordre
	elif ordre == "retour":   # à la base : l'ancre au centre de la cellule du camp, si c'est elle qui est chargée
		if sim.lieu != "camp" or sim.monde == null or sim.monde.cellule_de(x.pos) != sim.monde.cellule_camp:
			EventBus.emettre(&"journal", [&"journal.retour_impossible", {}])
			return false
		x.ordre = "attendre"
		x.ancre = sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	else:
		x.ordre = ordre
	if ordre == "attendre":
		x.ancre = x.pos
	EventBus.emettre(&"journal", [&"journal.ordre", {"nom": x.name_key, "ordre": "ordre." + ordre}])
	return true


## Apprivoiser une bête adjacente (Apprivoisement et recrutement) : le jet universel.
static func _apprivoiser(sim: Simulation, e: Dictionary, cible_id: String, tick: int) -> bool:
	var c: Dictionary = sim.entites.get(cible_id, {})
	if c.is_empty() or not c.vivant or not ("bete" in c.get("tags", [])) or Grille.distance(e.pos, c.pos) > 1 or c.has("maitre"):
		EventBus.emettre(&"journal", [&"journal.pas_de_bete", {}])
		return false
	var def: Dictionary = GameData.catalogues.creatures.get(str(c.def), {})
	if str(def.get("recruitable", {}).get("method", "dressage")) == "jamais":
		return false
	var jour := tick / int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
	if int(c.get("dernier_apprivoisement", -1)) == jour:
		EventBus.emettre(&"journal", [&"journal.deja_tente", {"nom": c.name_key}])
		return false
	c["dernier_apprivoisement"] = jour
	var ap: Dictionary = sim.regles.r.apprivoisement
	var jet := sim.des.jet("1d20") + sim.regles.niveau(e.competences_eff, "dressage") / 2 + int(e.stats_eff.charisme) / 4
	var pv := float(c.sante) / float(c.sante_max)
	if pv < 0.25:
		jet += int(ap.bonus_25)
	elif pv < 0.5:
		jet += int(ap.bonus_50)
	var niveau := int(round(sim.progression.niveaux_derives(c).combat))
	var dd := int(ap.dd_base) + niveau / 2
	sim.gagner_xp(e, "dressage", 5)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	if jet >= dd:
		if compagnons_de(sim, e).size() >= places_escorte(sim, e):
			EventBus.emettre(&"journal", [&"journal.pas_de_place", {}])
			return false
		_devenir_compagnon(sim, e, c)
		EventBus.emettre(&"journal", [&"journal.apprivoise", {"nom": c.name_key, "jet": jet, "dd": dd}])
		return true
	EventBus.emettre(&"journal", [&"journal.apprivoisement_rate", {"nom": c.name_key, "jet": jet, "dd": dd}])
	if c.ai_profile in ["proie"]:
		c.fuite = true
	else:
		c.ai_profile = "hostile"
		c.cible = e.id
	return true


## Un compagnon mort laisse son âme dans le sac du maître (Compagnons).
static func _mort_compagnon(sim: Simulation, x: Dictionary) -> void:
	var maitre: Dictionary = sim.entites.get(str(x.get("maitre", "")), {})
	if maitre.is_empty():
		return
	var ame: Dictionary = SimObjets.generer_objet(sim, "ame", 1, {}, "commun", 0)
	SimObjets.identifier(sim, ame)   # une âme qu'on récolte soi-même n'est pas un mystère (2026-09-02)
	if ame.is_empty():
		return
	ame["compagnon"] = x.id
	ame["name_key"] = x.name_key
	maitre.sac.append(ame.uid)
	x["corps_pos"] = x.pos
	EventBus.emettre(&"journal", [&"journal.compagnon_mort", {"nom": x.name_key}])


## Ressusciter un compagnon : l'âme dans le sac, un autel domestique adjacent, l'or ; il revient affaibli.
static func _ressusciter(sim: Simulation, e: Dictionary, uid_ame: String, tick: int, pnj_id: String = "", par_sort: bool = false) -> bool:
	var ame: Dictionary = sim.items.get(uid_ame, {})
	if ame.is_empty() or not (uid_ame in e.sac) or not ame.has("compagnon"):
		return false
	var pretre: Dictionary = sim.entites.get(pnj_id, {})   # chez un prêtre (Compagnons) : sans le ×1,5 de l'autel, l'or va à sa bourse finie
	if not pretre.is_empty() and (not ("pretre" in pretre.get("tags", [])) or Grille.distance(e.pos, pretre.pos) > 2):
		pretre = {}
	var autel := false
	for d in Grille.DIRS:
		var t: Vector2i = e.pos + d
		if sim.grille.dans(t) and str(sim.grille.meubles.get(sim.grille.idx(t), "")) == "autel_domestique":
			autel = true
	if not autel and pretre.is_empty() and not par_sort:
		EventBus.emettre(&"journal", [&"journal.pas_d_autel", {}])
		return false
	var x: Dictionary = sim.entites.get(str(ame.compagnon), {})
	if x.is_empty():
		return false
	var c: Dictionary = sim.regles.r.compagnons
	var niveau := maxi(1, int(round(sim.progression.niveaux_derives(x).combat)))
	var cout := int(float(c.or_par_niveau) * niveau * (float(c.get("pretre_mult", 1.0)) if not pretre.is_empty() else float(c.autel_mult)))
	if par_sort:
		cout = 0   # le sort de Vie paie en mana, pas en or (Compagnons)
	if int(e.or) < cout:
		EventBus.emettre(&"journal", [&"journal.pas_assez_or", {}])
		return false
	e.or = int(e.or) - cout
	if not pretre.is_empty():
		pretre.or = mini(int(pretre.get("or_max", cout)), int(pretre.or) + cout)   # ce qui dépasse sa bourse sort du jeu
		EventBus.emettre(&"journal", [&"journal.resurrection_pretre", {"pretre": pretre.name_key, "nom": x.name_key, "cout": cout}])
	e.sac.erase(uid_ame)
	sim.items.erase(uid_ame)
	x.vivant = true
	x.sante = maxi(1, int(x.sante_max) / 2)
	x.statuts = []
	x.action_en_cours = {}
	var ou: Vector2i = e.pos
	for d in Grille.DIRS:
		var t: Vector2i = e.pos + d
		if sim.grille.dans(t) and not sim.grille.bloque_passage(t) and sim.grille.occupant(t).is_empty():
			ou = t
			break
	x.pos = ou
	sim.grille.placer(x.id, ou)
	x.compteur = tick
	x.horloge = "monde"
	if not (x.id in sim.ordre):
		sim.ordre.append(x.id)
	sim.appliquer_statut(x, "affaibli", int(c.affaibli_ticks), e.id)
	x["affaibli_mult"] = float(c.affaibli_mult)
	Etres.recalculer(x, sim.items, sim.affixes_defs, sim.regles)
	EventBus.emettre(&"journal", [&"journal.ressuscite", {"nom": x.name_key, "or": cout}])
	return true


## L'âge (Âge des PNJ) : le passage hebdomadaire fait vieillir ; au-delà de l'espérance, une chance
## croissante de mourir ; les âgés perdent des stats physiques par tranche.
static func _vieillir_semaine(sim: Simulation, tick: int) -> void:
	var ag: Dictionary = sim.regles.r.age
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "age", tick])
	for x in sim.entites.values():
		if not x.has("age") or not x.vivant:
			continue
		x.age = float(x.age) + 7.0 / float(ag.jours_par_an)
		if float(x.age) > float(x.get("lifespan", 80.0)):
			var ecart := float(x.age) - float(x.lifespan)
			if rng.randf() < float(ag.chance_mort_par_an) * ecart:
				x.vivant = false
				sim.grille.liberer(x.pos)
				EventBus.emettre(&"journal", [&"journal.mort_vieillesse", {"nom": x.name_key}])
				continue
		var tranches := int(maxf(0.0, float(x.age) - float(ag.age)) / float(ag.tranche))
		x["age_mult"] = maxf(0.3, 1.0 - float(ag.malus_par_tranche) * tranches)


static func categorie_age(sim: Simulation, x: Dictionary) -> String:
	var ag: Dictionary = sim.regles.r.age
	var a := float(x.get("age", 30.0))
	return "jeune" if a < float(ag.adulte) else ("age" if a >= float(ag.age) else "adulte")


# ---------------------------------------------------------------- quêtes et guildes (Gabarit de quête)

## Les quêtes qu'un donneur offre cette semaine (générées depuis les gabarits, jusqu'à quetes_par_semaine).
static func quetes_offertes(sim: Simulation, pnj: Dictionary, e: Dictionary) -> Array:
	if not ("quetes" in pnj.get("tags", [])):
		return []
	# Refusées sous −20 : la relation du donneur, ou la réputation de son village (le collectif compte).
	if mini(relation_de(sim, pnj, e), int(e.get("reputations", {}).get(str(pnj.get("village", "")), 0))) < int(sim.regles.r.reputation.quetes_seuil):
		return []
	var semaine := sim.horloge_monde.ticks / int(GameData.config("planete").corruption.ticks_par_semaine)
	if int(pnj.get("quetes_semaine", -1)) != semaine:
		pnj["quetes_semaine"] = semaine
		pnj["quetes"] = []
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.graine, "quetes", pnj.id, semaine])
		var ids: Array = []
		for gid0 in GameData.catalogues.quest_templates.keys():
			var g0: Dictionary = GameData.catalogues.quest_templates[gid0]
			if pnj.has("guilde") and str(g0.guild) != str(pnj.guilde):
				continue
			# rank_min (Gabarit de quête) : 1 = novice … 5 = maître ; les rangs internes sont indexés à 0.
			if int(g0.get("rank_min", 1)) > int(e.get("guildes", {}).get(str(g0.guild), {}).get("rang", 0)) + 1:
				continue
			ids.append(gid0)
		ids.sort()
		if ids.is_empty():
			return pnj.quetes
		for k in int(sim.regles.r.guildes.quetes_par_semaine):
			var gid: String = ids[rng.randi_range(0, ids.size() - 1)]
			var g: Dictionary = GameData.catalogues.quest_templates[gid]
			var count := rng.randi_range(int(g.count_range[0]), int(g.count_range[1]))
			var niveau := maxi(1, int(round(sim.monde.corruption_de(sim.monde.cellule_de(pnj.pos)) / 20.0))) if sim.monde != null else 1
			var q := {"uid": "q_%s_%d_%d" % [pnj.id, semaine, k], "gabarit": gid, "guild": str(g.guild), "pattern": str(g.pattern), "selector": g.target_selector,
				"count": count, "fait": 0, "niveau": niveau, "or": Des.jet_rng(str(g.reward.gold_per_target_level), rng) * niveau * count, "xp": Des.jet_rng(str(g.reward.guild_xp), rng) * count,
				"text_key": str(g.text_key), "donneur": pnj.id, "village": str(pnj.get("village", "")), "cellule": sim.monde.cellule_de(pnj.pos) if sim.monde != null else Vector2i.ZERO, "etat": "offerte"}
			if str(g.pattern) == "livrer":   # une livraison : un objet du pool, vers un autre village connu (sinon le sien)
				# Le bien à livrer : une CATÉGORIE (denrées empilables), jamais une liste d'ids (Gabarit de quête)
				q["objet"] = GameData.tirer("items", g.target_selector.get("filtre", {"types_any": ["consommable"]}), rng)
				var autres: Array = []
				for nom_v in sim.monde.villages.keys():
					if nom_v != str(pnj.get("village", "")):
						autres.append(nom_v)
				autres.sort()
				q["destination"] = str(autres[rng.randi() % autres.size()]) if not autres.is_empty() else str(pnj.get("village", ""))
			pnj.quetes.append(q)
	return pnj.quetes


static func _accepter_quete(sim: Simulation, e: Dictionary, pnj_id: String, uid: String, tick: int) -> bool:
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	if pnj.is_empty():
		return false
	for q in quetes_offertes(sim, pnj, e):
		if q.uid == uid and q.etat == "offerte":
			q.etat = "en_cours"
			if not e.has("quetes"):
				e["quetes"] = []
			e.quetes.append(q)
			EventBus.emettre(&"journal", [&"journal.quete_acceptee", {"texte": q.text_key}])
			e.compteur = tick + int(sim.regles.r.actions.objet)
			return true
	return false


## Une créature tuée par le joueur : les quêtes « tuer » dont le sélecteur matche avancent.
static func _quetes_sur_mort(sim: Simulation, cible: Dictionary, tueur: String) -> void:
	var e: Dictionary = sim.entites.get(tueur, {})
	if e.is_empty() or e.controle != "joueur":
		return
	for q in e.get("quetes", []):
		if q.etat != "en_cours" or q.pattern != "tuer":
			continue
		var ok := false
		for t in q.selector.get("tags_any", []):
			if t in cible.get("tags", []) or (t == "hostile" and cible.camp == "hostile"):
				ok = true
		if ok:
			q.fait = int(q.fait) + 1
			EventBus.emettre(&"journal", [&"journal.quete_progres", {"fait": int(q.fait), "count": int(q.count)}])
			if int(q.fait) >= int(q.count):
				q.etat = "terminee"


## Le progresseur générique des quêtes (Gabarit de quête) : un pattern, des tags de contexte, le sélecteur décide.
static func _progresser_quetes(sim: Simulation, e: Dictionary, pattern: String, tags: Array) -> void:
	if e.controle != "joueur":
		return
	for q in e.get("quetes", []):
		if q.etat != "en_cours" or str(q.pattern) != pattern:
			continue
		var sel: Dictionary = q.selector
		var ok := true
		if sel.has("tags_any"):
			ok = false
			for t in sel.tags_any:
				if t in tags:
					ok = true
		if sel.has("kinds_any"):
			ok = false
			for t in sel.kinds_any:
				if t in tags:
					ok = true
		if not ok:
			continue
		q.fait = int(q.fait) + 1
		EventBus.emettre(&"journal", [&"journal.quete_progres", {"fait": int(q.fait), "count": int(q.count)}])
		if int(q.fait) >= int(q.count):
			q.etat = "terminee"


## Une livraison : parler à un PNJ du village de destination avec l'objet dans le sac.
static func _livraisons(sim: Simulation, e: Dictionary, pnj: Dictionary) -> void:
	for q in e.get("quetes", []):
		if q.etat != "en_cours" or str(q.pattern) != "livrer" or str(pnj.get("village", "")) != str(q.get("destination", "")):
			continue
		var pile: Dictionary = SimTerrain._pile_objet(sim, e, str(q.objet))
		if pile.is_empty():
			continue
		SimCamp._consommer_pile(sim, e, pile)
		q.fait = int(q.count)
		q.etat = "terminee"
		EventBus.emettre(&"journal", [&"journal.livraison", {"nom": e.name_key, "objet": GameData.entree("items", str(q.objet)).name_key}])


## Un donjon vidé : les quêtes « donjon » de cette cellule sont terminées.
static func _quetes_sur_donjon(sim: Simulation, cellule: Vector2i, joueur: String) -> void:
	var e: Dictionary = sim.entites.get(joueur, {})
	for q in e.get("quetes", []):
		if q.etat == "en_cours" and q.pattern == "donjon" and Vector2i(q.cellule).distance_to(cellule) <= 6.0:
			q.fait = int(q.count)
			q.etat = "terminee"


## Rendre une quête terminée à son donneur : or, XP de guilde (rangs), relation.
static func _rendre_quete(sim: Simulation, e: Dictionary, pnj_id: String, uid: String, tick: int) -> bool:
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	if pnj.is_empty():
		return false
	for q in e.get("quetes", []):
		if q.uid == uid and q.etat == "terminee" and q.donneur == pnj_id:
			q.etat = "rendue"
			e.or = int(e.or) + int(q.or)
			sim.territoire.gains_quetes = int(sim.territoire.get("gains_quetes", 0)) + int(q.or)
			if not e.has("guildes"):
				e["guildes"] = {}
			var g: Dictionary = e.guildes.get(q.guild, {"xp": 0, "rang": 0})
			g.xp = int(g.xp) + int(q.xp)
			var seuils: Array = sim.regles.r.guildes.seuils_xp
			var rang := 0
			for k in seuils.size():
				if int(g.xp) >= int(seuils[k]):
					rang = k
			if rang > int(g.rang):
				EventBus.emettre(&"journal", [&"journal.rang_guilde", {"guilde": "guilde.%s.name" % q.guild, "rang": "rang." + str(sim.regles.r.guildes.rangs[rang])}])
			g.rang = rang
			e.guildes[q.guild] = g
			reputation(sim, e, pnj, "quete")
			EventBus.emettre(&"journal", [&"journal.quete_rendue", {"or": int(q.or), "xp": int(q.xp), "guilde": "guilde.%s.name" % q.guild}])
			EventBus.emettre(&"quest_completed", [q])
			e.compteur = tick + int(sim.regles.r.actions.objet)
			return true
	return false


# ---------------------------------------------------------------- cycle jour-nuit (E.21) et météo (E.28)

## Deux êtres sont-ils ennemis ? Deux camps différents, sauf le joueur et les civils (IA des créatures).
static func ennemis(sim: Simulation, a: Dictionary, b: Dictionary) -> bool:
	if a.camp == b.camp:
		return false
	var doux := ["joueur", "civil"]
	if a.camp in doux and b.camp in doux:
		# Réputation et relations : ≤ −50, hostile à vue.
		var seuil := int(sim.regles.r.reputation.hostile_seuil)
		if a.camp == "civil" and b.camp == "joueur":
			return relation_de(sim, a, b) <= seuil
		if b.camp == "civil" and a.camp == "joueur":
			return relation_de(sim, b, a) <= seuil
		return false
	return true


## La relation d'un PNJ envers un être (−100..+100), la réputation de son village en repli.
static func relation_de(sim: Simulation, pnj: Dictionary, e: Dictionary) -> int:
	var rels: Dictionary = pnj.get("social", {}).get("relations", {})
	if rels.has(e.id):
		return int(rels[e.id])
	return int(e.get("reputations", {}).get(str(pnj.get("village", "")), 0))


## Un acte du joueur envers un PNJ : gains [pnj, village, globale] (Réputation et relations), modulés
## par la vitesse liée à la réputation du village.
static func reputation(sim: Simulation, e: Dictionary, pnj: Dictionary, acte: String) -> void:
	var rp: Dictionary = sim.regles.r.reputation
	var gains: Array = rp.get(acte, [0, 0, 0])
	var village := str(pnj.get("village", ""))
	if not e.has("reputations"):
		e["reputations"] = {}
	var rep_v := int(e.reputations.get(village, 0))
	var vitesse := 1.0
	for v in rp.vitesse:
		if rep_v >= int(v[0]) and rep_v <= int(v[1]):
			vitesse = float(v[2])
	var g0 := int(round(float(gains[0]) * (vitesse if int(gains[0]) > 0 else 1.0)))
	pnj.social.relations[e.id] = clampi(relation_de(sim, pnj, e) + g0, -100, 100)
	if not village.is_empty():
		e.reputations[village] = clampi(rep_v + int(gains[1]), -100, 100)
	var roy := str(pnj.get("royaume", ""))
	if not roy.is_empty():
		e.reputations[roy] = clampi(int(e.reputations.get(roy, 0)) + int(gains[1]), -100, 100)
	e.reputations["_globale"] = clampi(int(e.reputations.get("_globale", 0)) + int(gains[2]), -100, 100)
	EventBus.emettre(&"journal", [&"journal.reputation", {"nom": pnj.name_key, "pnj": int(pnj.social.relations[e.id]), "village": village if not village.is_empty() else "—", "rep": int(e.reputations.get(village, 0))}])
	if relation_de(sim, pnj, e) <= int(rp.hostile_seuil):
		EventBus.emettre(&"journal", [&"journal.hostile_a_vue", {"nom": pnj.name_key}])


## Le palier d'information d'un PNJ pour le joueur (L'information comme récompense) : 0..5.
static func palier_info(sim: Simulation, pnj: Dictionary, e: Dictionary) -> int:
	var rel := relation_de(sim, pnj, e)
	if rel < 0:
		return 0
	var paliers: Array = sim.regles.r.reputation.paliers_info
	var p := 0
	for k in paliers.size():
		if rel >= int(paliers[k]):
			p = k + 1
	return p


## Une rumeur (≥ 50) : révèle une cellule à POI non explorée dans le rayon, filtrée par le métier.
static func _rumeur(sim: Simulation, pnj: Dictionary, e: Dictionary, tick: int) -> bool:
	if sim.monde == null or relation_de(sim, pnj, e) < int(sim.regles.r.reputation.confidences_seuil):
		return false
	var semaine := tick / int(GameData.config("planete").corruption.ticks_par_semaine)
	if int(pnj.get("derniere_rumeur", -1)) == semaine:
		return false
	var centre := sim.monde.cellule_de(pnj.pos)
	var r := int(sim.regles.r.reputation.rumeur_rayon)
	var cle := "filon_majeur" if str(pnj.get("fonction", "")) == "artisan" else "donjon"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "rumeur", pnj.id, semaine])
	var candidats: Array[Vector2i] = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := centre + Vector2i(dx, dy)
			if c != centre and sim.monde.surface.terre_a(c) and not sim.monde.cellule_exploree(c) and bool(sim.monde.surface.poi_de(c).get(cle, false)):
				candidats.append(c)
	if candidats.is_empty():
		return false
	var c: Vector2i = candidats[rng.randi_range(0, candidats.size() - 1)]
	sim.monde.explores[Vector2i(c.x * (sim.monde.taille / 32) + 1, c.y * (sim.monde.taille / 32) + 1)] = true
	pnj["derniere_rumeur"] = semaine
	EventBus.emettre(&"journal", [&"journal.rumeur", {"nom": pnj.name_key, "x": c.x, "y": c.y}])
	EventBus.emettre(&"chunk_explored", [Vector2i(c.x * (sim.monde.taille / 32) + 1, c.y * (sim.monde.taille / 32) + 1)])
	return true
