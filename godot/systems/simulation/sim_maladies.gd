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


# ---------------------------------------------------------------- les drogues (28 quater, 2026-09-13)

## L'accoutumance d'un être à une drogue, maintenant : la valeur de la dernière dose éteinte par demi-vie.
static func accoutumance(sim: Simulation, e: Dictionary, id: String, tick: int) -> float:
	var d: Dictionary = GameData.config("drogues").get("liste", {}).get(id, {})
	var a: Dictionary = (e.get("accoutumances", {}) as Dictionary).get(id, {})
	if d.is_empty() or a.is_empty():
		return 0.0
	var jour := maxi(1, int(SimTerrain._cycle(sim).get("ticks_par_jour", 2400000)))
	var ecoule := maxi(0, tick - int(a.get("tick", tick)))
	return float(a.get("niveau", 0.0)) * pow(0.5, float(ecoule) / maxf(1.0, float(d.get("demi_vie_jours", 2.0)) * float(jour)))


## UNE DOSE : l'accoutumance monte, le manque se lève, et l'effet cherché dure d'autant moins qu'on y est habitué.
## Rend la durée de l'effet à poser.
static func prendre(sim: Simulation, e: Dictionary, it: Dictionary, tick: int) -> int:
	var id := str(it.get("drogue", ""))
	var d: Dictionary = GameData.config("drogues").get("liste", {}).get(id, {})
	var duree := int(it.get("statut_ticks", 0))
	if d.is_empty():
		return duree
	var avant := accoutumance(sim, e, id, tick)
	var mx := float(d.get("max", 100.0))
	duree = roundi(float(duree) * lerpf(1.0, float(d.get("tolerance", 1.0)), clampf(avant / maxf(1.0, mx), 0.0, 1.0)))
	if not e.has("accoutumances"):
		e["accoutumances"] = {}
	e.accoutumances[id] = {"niveau": minf(mx, avant + float(d.get("accoutumance_par_dose", 10.0))), "tick": tick}
	SimTalents._retirer_statut(sim, e, str(d.get("statut_manque", "")))
	return duree


## LE MANQUE, à la passe horaire : il s'installe chez l'habitué privé de sa dose, et se lève quand l'habitude retombe.
static func tiquer_drogues(sim: Simulation, tick: int) -> void:
	var liste: Dictionary = GameData.config("drogues").get("liste", {})
	if liste.is_empty():
		return
	var heure := maxi(1, int(SimTerrain._cycle(sim).get("ticks_par_jour", 2400000)) / 24)
	for e in sim.vivants():
		if not e.has("accoutumances"):
			continue
		for id in (e.accoutumances as Dictionary).keys():
			var d: Dictionary = liste.get(str(id), {})
			if d.is_empty():
				continue
			var niv := accoutumance(sim, e, str(id), tick)
			var sans := tick - int(e.accoutumances[id].get("tick", tick))
			var st := str(d.get("statut_manque", ""))
			var en_manque: bool = e.statuts.any(func(s0: Dictionary) -> bool: return str(s0.id) == st)
			if niv >= float(d.get("seuil_manque", 40.0)) and sans >= int(d.get("manque_apres_heures", 12)) * heure:
				if not en_manque:
					sim.appliquer_statut(e, st, int(sim.statuts_defs.get(st, {}).get("duree_ticks", 2400000)), e.id)
					if e.controle == "joueur":
						EventBus.emettre(&"journal", [&"journal.manque", {"nom": e.name_key}])
			elif en_manque and niv < float(d.get("seuil_manque", 40.0)):
				SimTalents._retirer_statut(sim, e, st)


# ---------------------------------------------------------------- mutations et déformations (28 quater, 2026-09-13)

## MUTER : le corps de CET être reçoit la mutation ; une partie avec laquelle on naît sans est inscrite perdue.
static func muter(sim: Simulation, e: Dictionary, id: String) -> bool:
	var m: Dictionary = GameData.config("mutations").get("liste", {}).get(id, {})
	if (m.is_empty() and not id.begins_with("rnd:")) or not e.has("corps"):
		return false
	var muts: Array = e.corps.get("mutations", [])
	if id in muts:
		return false
	muts.append(id)
	muts.sort()   # un ordre fixe : deux êtres de mêmes mutations partagent le même plan
	e.corps["mutations"] = muts
	for p in m.get("perdue", []):
		if Etres.plan_corps(e).get("parties", {}).has(str(p)):
			var perdues: Array = e.corps.get("perdues", [])
			if not (str(p) in perdues):
				perdues.append(str(p))
			e.corps["perdues"] = perdues
	Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
	return true


## CE QUI PASSE À L'ENFANT : chaque mutation héritable d'un parent, avec la chance `heredite`. Tiré à la graine.
static func heriter(sim: Simulation, enfant: Dictionary, parents: Array) -> void:
	var cfg: Dictionary = GameData.config("mutations")
	var liste: Dictionary = cfg.get("liste", {})
	for pa in parents:
		if not (pa is Dictionary):
			continue
		for mid in (pa as Dictionary).get("corps", {}).get("mutations", []):
			var heritable: bool = bool(cfg.get("aleatoires", {}).get("heritable", false)) if str(mid).begins_with("rnd:") else bool(liste.get(str(mid), {}).get("heritable", false))
			if not heritable:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([sim.graine, str(enfant.get("id", "")), str(pa.get("id", "")), str(mid)])
			if rng.randf() < float(cfg.get("heredite", 0.5)):
				muter(sim, enfant, str(mid))


## LA CORRUPTION FAIT MUTER, rarement, qui s'y tient : une passe par heure, à la chance du jour divisée par vingt-quatre.
static func tiquer_mutations(sim: Simulation, tick: int) -> void:
	var cfg: Dictionary = GameData.config("mutations")
	var liste: Dictionary = cfg.get("liste", {})
	if liste.is_empty() or sim.monde == null or sim.lieu != "camp":
		return
	var ids: Array = []
	for mid in liste.keys():
		if bool(liste[mid].get("par_corruption", false)):
			ids.append(str(mid))
	if ids.is_empty():
		return
	ids.sort()
	var heure := maxi(1, int(SimTerrain._cycle(sim).get("ticks_par_jour", 2400000)) / 24)
	for e in sim.vivants():
		if sim.monde.corruption_de(sim.monde.cellule_de(e.pos)) < float(cfg.get("seuil_corruption", 60)):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sim.graine, str(e.id), "mutation", tick / heure])
		if rng.randf() < float(cfg.get("chance_par_jour", 0.01)) / 24.0:
			if rng.randf() < float(cfg.get("aleatoires", {}).get("part_corruption", 0.0)):
				var code := muter_aleatoire(sim, e, rng)
				if not code.is_empty() and e.controle == "joueur":
					EventBus.emettre(&"journal", [&"journal.mutation_aleatoire", {"nom": e.name_key, "type": "mutation.type." + code.trim_prefix("rnd:").get_slice("@", 0), "partie": "partie." + code.get_slice("@", 1).get_slice("#", 0)}])
				continue
			var mid: String = ids[rng.randi() % ids.size()]
			if muter(sim, e, mid) and e.controle == "joueur":
				EventBus.emettre(&"journal", [&"journal.mutation", {"nom": e.name_key, "mutation": str(liste[mid].name_key)}])



## UNE MUTATION AU HASARD (designer 2026-09-13) : un type au poids, un hôte parmi les parties externes intactes qu'il
## accepte. Rend le code posé, ou "" si ce corps n'offre aucun hôte.
static func muter_aleatoire(sim: Simulation, e: Dictionary, rng: RandomNumberGenerator) -> String:
	var al: Dictionary = GameData.config("mutations").get("aleatoires", {})
	var types: Dictionary = al.get("types", {})
	if types.is_empty() or not e.has("corps"):
		return ""
	var cles: Array = types.keys()
	cles.sort()
	var total := 0.0
	for k in cles:
		total += float(types[k].get("poids", 1))
	var r := rng.randf() * total
	var type: String = str(cles[0])
	for k in cles:
		r -= float(types[k].get("poids", 1))
		if r <= 0.0:
			type = str(k)
			break
	var parties: Dictionary = Etres.plan_corps(e).get("parties", {})
	var hotes: Array = []
	for nom: String in parties.keys():
		if bool(parties[nom].get("interne", false)) or not Etres.partie_intacte(e, nom):
			continue
		for pref in types[type].get("hotes", []):
			if nom.begins_with(str(pref)):
				hotes.append(nom)
				break
	if hotes.is_empty():
		return ""
	hotes.sort()
	var hote: String = hotes[rng.randi() % hotes.size()]
	var n := 1
	for mid in e.corps.get("mutations", []):
		if str(mid).begins_with("rnd:"):
			n += 1
	var code := "rnd:%s@%s#%d" % [type, hote, n]
	return code if muter(sim, e, code) else ""
