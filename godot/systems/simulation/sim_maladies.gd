class_name SimMaladies
extends RefCounted
## LES MALADIES, LES MÉDICAMENTS ET LES VACCINS (ordre de travail 28 quater ; designer 2026-09-09 : « maladies, drogues,
## vaccins, médicaments… », puis « oui pour tout » aux trois questions).
##
## **Les trois réponses du designer font le dessin** :
## · **LA CONTAGION EST UN CHAMP PARTAGÉ**, comme le bruit et l'odeur. Une épidémie est un LIEU, pas un compteur par
##   individu : un malade charge sa tuile (et, pour ce qui passe par l'air, les voisines), la charge s'éteint heure
##   après heure, et un être qui s'y tient la respire. On peut donc FUIR un quartier malade.
## · **UNE MALADIE TOUCHE AUSSI LES BÊTES** : chaque maladie dit qui elle frappe (`touche` : des tags de silhouette ou
##   d'être), et rien ne réserve la pathologie aux êtres pensants.
## · **ELLE ATTAQUE UN ORGANE NOMMÉ** : le plan de corps existe depuis le 2026-09-09. Une grippe prend les poumons (les
##   branchies d'un nautique, les trachées d'un insectoïde : les organes se désignent par PRÉFIXE), et un organe vital
##   détruit tue par le seul chemin de mort qui existe.
##
## **RIEN NE SE TIQUE QUI PUISSE SE DÉDUIRE** : un être porte l'heure où il a été infecté ; incubation, maladie et
## guérison se lisent sur elle. Une passe par heure du monde fait ce qui ne se déduit pas — la contagion, les dégâts
## d'organe, le passage d'un stade à l'autre (pour recalculer les stats et le dire).
##
## **LE MÉDICAMENT ET LE VACCIN SONT SUR LA FICHE DE L'OBJET** : `guerit` (des maladies qu'il fait cesser, et ce qu'il
## rend aux organes touchés), `vaccin` (des maladies contre lesquelles il immunise). Le vaccin est le premier effet du
## jeu qui agit sur ce qui n'est PAS ENCORE arrivé : un état du corps, pas un statut à durée.


static func _cfg() -> Dictionary:
	return GameData.config("maladies")


## Le stade d'une maladie chez un être, lu sur l'heure d'infection : « incubation », « malade » ou « guerie ».
static func stade(sim: Simulation, e: Dictionary, id: String, tick: int) -> String:
	var m: Dictionary = _cfg().get("liste", {}).get(id, {})
	if m.is_empty() or not (e.get("maladies", {}) as Dictionary).has(id):
		return ""
	var jour := maxi(1, int(SimTerrain._cycle(sim).get("ticks_par_jour", 2400000)))
	var age := tick - int(e.maladies[id])
	if age < int(float(m.get("incubation_jours", 1.0)) * jour):
		return "incubation"
	if age < int((float(m.get("incubation_jours", 1.0)) + float(m.get("duree_jours", 3.0))) * jour):
		return "malade"
	return "guerie"


## Une maladie peut-elle toucher cet être ? Ni immunisé, ni déjà atteint, et de ceux qu'elle frappe.
static func sensible(e: Dictionary, id: String) -> bool:
	var m: Dictionary = _cfg().get("liste", {}).get(id, {})
	if m.is_empty() or (e.get("immunites", {}) as Dictionary).has(id) or (e.get("maladies", {}) as Dictionary).has(id):
		return false
	var touche: Array = m.get("touche", [])
	if touche.is_empty():
		return true
	var sil := str(e.get("corps", {}).get("silhouette", ""))
	for t in touche:
		if str(t) == sil or str(t) in e.get("tags", []):
			return true
	return false


static func infecter(sim: Simulation, e: Dictionary, id: String, tick: int) -> bool:
	if not sensible(e, id):
		return false
	if not e.has("maladies"):
		e["maladies"] = {}
	e.maladies[id] = tick
	return true


## Les maladies en cours de symptômes : ce que `Etres.recalculer` lit pour le malus de stats.
static func malades(e: Dictionary) -> Array:
	return e.get("maladies_actives", [])


## Les organes qu'une maladie attaque chez CET être : les parties de son plan dont le nom commence par un des préfixes.
static func organes_vises(e: Dictionary, id: String) -> Array[String]:
	var m: Dictionary = _cfg().get("liste", {}).get(id, {})
	var res: Array[String] = []
	var parties: Dictionary = Etres.plan_corps(e).get("parties", {})
	for nom: String in parties.keys():
		for pref in m.get("organes", []):
			if nom.begins_with(str(pref)) and Etres.partie_intacte(e, nom):
				res.append(nom)
				break
	return res


## La charge de contagion d'une maladie sur une tuile.
static func charge(sim: Simulation, t: Vector2i, id: String) -> float:
	if not sim.grille.dans(t):
		return 0.0
	return float((sim.contagion.get(sim.grille.idx(t), {}) as Dictionary).get(id, 0.0))


static func _charger(sim: Simulation, t: Vector2i, id: String, v: float) -> void:
	if v <= 0.0 or not sim.grille.dans(t):
		return
	var i := sim.grille.idx(t)
	if not sim.contagion.has(i):
		sim.contagion[i] = {}
	sim.contagion[i][id] = minf(1.0, float(sim.contagion[i].get(id, 0.0)) + v)


## UNE HEURE DE MALADIE. L'ordre est fixe : le champ s'éteint, les malades le rechargent et souffrent, les bien-portants
## le respirent. Les tirages sont semés par (graine, être, maladie, heure) : deux parties rejouent la même épidémie.
static func tiquer(sim: Simulation, tick: int) -> void:
	var cfg := _cfg()
	var liste: Dictionary = cfg.get("liste", {})
	if liste.is_empty():
		return
	var jour := maxi(1, int(SimTerrain._cycle(sim).get("ticks_par_jour", 2400000)))
	var heure := jour / 24
	# 1. Le champ s'éteint.
	var fondu := clampf(float(cfg.get("fondu_par_heure", 0.35)), 0.0, 1.0)
	var eps := float(cfg.get("epsilon", 0.02))
	for i in sim.contagion.keys().duplicate():
		var d: Dictionary = sim.contagion[i]
		for id in d.keys().duplicate():
			var v := float(d[id]) * (1.0 - fondu)
			if v < eps:
				d.erase(id)
			else:
				d[id] = v
		if d.is_empty():
			sim.contagion.erase(i)
	var ids: Array = liste.keys()
	ids.sort()
	var vivants := sim.vivants()
	# 2. Les malades : stade, charge, organes.
	for e in vivants:
		if not e.has("maladies"):
			continue
		var actives: Array = []
		for id in (e.maladies as Dictionary).keys().duplicate():
			var m: Dictionary = liste.get(str(id), {})
			var st := stade(sim, e, str(id), tick)
			if st == "guerie":
				e.maladies.erase(id)
				if not e.has("immunites"):
					e["immunites"] = {}
				e.immunites[id] = true
				if e.controle == "joueur":
					EventBus.emettre(&"journal", [&"journal.maladie_guerie", {"nom": e.name_key, "maladie": str(m.get("name_key", id))}])
				continue
			var emission := float(m.get("emission", 0.3)) * (float(m.get("emission_incubation", 0.3)) if st == "incubation" else 1.0)
			_charger(sim, e.pos, str(id), emission)
			if str(m.get("voie", "contact")) == "air":
				for dd in Grille.DIRS:
					_charger(sim, e.pos + dd, str(id), emission * float(cfg.get("air_voisins", 0.5)))
			if st != "malade":
				continue
			actives.append(str(id))
			var par_heure := float(m.get("degats_organe_par_jour", 0.0)) / 24.0
			if par_heure > 0.0:
				var reste := float(e.get("maladie_reste", 0.0)) + par_heure
				var n := int(floor(reste))
				e["maladie_reste"] = reste - float(n)
				if n > 0:
					for org in organes_vises(e, str(id)):
						var issue := Etres.blesser_partie(e, org, n)
						if issue == "vitale" and e.vivant:
							e.sante = 0
							e.vivant = false
							e["mort_tick"] = tick
							sim.grille.liberer(e.pos, e.id)
							EventBus.emettre(&"journal", [&"journal.maladie_mort", {"nom": e.name_key, "maladie": str(m.get("name_key", id))}])
							EventBus.emettre(&"creature_killed", [e.id, e.id])
							break
			if not e.vivant:
				break
		var avant: Array = e.get("maladies_actives", [])
		if actives != avant:
			e["maladies_actives"] = actives
			Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
			if e.controle == "joueur" and actives.size() > avant.size():
				EventBus.emettre(&"journal", [&"journal.maladie_symptomes", {"nom": e.name_key}])
	# 3. Les bien-portants respirent le champ — et une maladie peut naître de rien, rarement, là où elle se plaît.
	var h_idx := tick / maxi(1, heure)
	for e in vivants:
		if not e.vivant:
			continue
		for id in ids:
			if not sensible(e, str(id)):
				continue
			var m: Dictionary = liste[id]
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([sim.graine, str(e.id), str(id), h_idx])
			var p := charge(sim, e.pos, str(id)) * float(m.get("transmission", 0.5))
			p += float(m.get("apparition_par_jour", 0.0)) / 24.0 * (float(m.get("apparition_mult_biome", 1.0)) if _biome_propice(sim, e.pos, m) else 1.0)
			if p > 0.0 and rng.randf() < p:
				infecter(sim, e, str(id), tick)


static func _biome_propice(sim: Simulation, pos: Vector2i, m: Dictionary) -> bool:
	var tags_b: Array = m.get("biomes_propices", [])
	if tags_b.is_empty() or sim.monde == null or sim.lieu != "camp":
		return false
	var b: Dictionary = GameData.catalogues.biomes.get(str(sim.monde.cellule(sim.monde.cellule_de(pos)).get("biome", "")), {})
	for t in tags_b:
		if str(t) in b.get("tags", []):
			return true
	return false


## MANGER UN MÉDICAMENT OU UN VACCIN : ce que la fiche de l'objet dit (`guerit`, `soin_organes`, `vaccin`).
static func soigner_par_objet(sim: Simulation, e: Dictionary, it: Dictionary) -> void:
	for id in it.get("guerit", []):
		if (e.get("maladies", {}) as Dictionary).has(str(id)):
			for org in organes_vises(e, str(id)):
				var etat: Dictionary = e.get("corps", {}).get("sante_parties", {})
				if etat.has(org):
					etat[org] = mini(Etres.sante_partie_max(e, org), int(etat[org]) + int(it.get("soin_organes", 0)))
			e.maladies.erase(str(id))
			e["maladies_actives"] = (e.get("maladies_actives", []) as Array).filter(func(x) -> bool: return str(x) != str(id))
			Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
			EventBus.emettre(&"journal", [&"journal.maladie_soignee", {"nom": e.name_key, "maladie": str(_cfg().get("liste", {}).get(str(id), {}).get("name_key", id))}])
	for id in it.get("vaccin", []):
		if not e.has("immunites"):
			e["immunites"] = {}
		e.immunites[str(id)] = true
		EventBus.emettre(&"journal", [&"journal.vaccine", {"nom": e.name_key, "maladie": str(_cfg().get("liste", {}).get(str(id), {}).get("name_key", id))}])
