class_name SimTalents
extends RefCounted
## Le vecteur du lieu, les armes fantômes, les formes et les rituels, les vampires, les affûts, les masques, les glyphes, les portails, la saisie ; les grilles de composition et les talents.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


static func vecteur_lieu(sim: Simulation, pos: Vector2i) -> Dictionary:
	if not sim.vecteur_lieu_force.is_empty():
		return sim.vecteur_lieu_force
	if sim.monde == null or sim.monde.surface == null:
		return {}
	var sf = sim.monde.surface
	var veg := sf.valeur("vegetation", pos.x, pos.y)
	var hum := sf.valeur("humidite", pos.x, pos.y)
	var temp := sf.valeur("temperature", pos.x, pos.y)
	var v := {"bois": veg * hum, "eau": hum, "metal": sf.valeur("ressources", pos.x, pos.y), "feu": maxf(absf(temp - 0.5) * 2.0, sf.valeur("sismique", pos.x, pos.y)), "terre": 0.3 + sf.valeur("altitude", pos.x, pos.y) * 0.4}
	var total := 0.0
	for k in v.keys():
		total += float(v[k])
	if total <= 0.0:
		return {}
	for k in v.keys():
		v[k] = float(v[k]) / total
	return v


## Le multiplicateur de mana du lieu pour un plan : même élément dominant ×0,85, dominé par le lieu ×1,15.
static func mult_mana_lieu(sim: Simulation, e: Dictionary, plan: Dictionary) -> float:
	var el := sim.wuxing.dominante(plan.get("elements", {}))
	var lieu_el := sim.wuxing.dominante(vecteur_lieu(sim, e.pos))
	if el.is_empty() or lieu_el.is_empty():
		return 1.0
	var ml: Dictionary = sim.regles.r.mana.get("lieu", {})
	if el == lieu_el:
		return float(ml.get("meme", 0.85))
	if sim.wuxing.relation(lieu_el, el) == "domine":
		return float(ml.get("domine_par", 1.15))
	return 1.0


## « Des sources » (Loot) : dans une forte densité de mana, le coût baisse de pct % par pièce.
static func mult_mana_sources(sim: Simulation, e: Dictionary) -> float:
	if sim.densite_mana(e.pos) < float(sim.regles.r.effets_equipement.get("densite_mana_seuil", 0.6)):
		return 1.0
	var m := 1.0
	for ax in Etres.affixes_equipes(e, sim.items, sim.affixes_defs, "cond_densite_mana_cout"):
		m *= 1.0 - float(ax.params.get("pct", 0)) / 100.0
	return m


## Armes fantomatiques : une lame d'élément pur invoquée en main principale, entretenue en mana.
static func _invoquer_arme_fantome(sim: Simulation, e: Dictionary, element: String, tick: int) -> bool:
	var af: Dictionary = sim.regles.r.armes_fantomes
	if not (element in af.elements) or str(e.corps.get("silhouette", "humanoide")) != "humanoide":
		return false
	if int(e.mana) < int(af.cout_mana):
		EventBus.emettre(&"journal", [&"journal.arme_fantome_mana", {}])
		return false
	_dissiper_arme_fantome(sim, e, false)
	e.mana -= int(af.cout_mana)
	var uid := "fantome_%s" % e.id
	var niveau := sim.regles.niveau(e.competences_eff, str(af.competence))
	var durete := float(sim.regles.r.degats.durete_reference) * (1.0 + float(e.stats_eff.volonte) / float(af.volonte_div) + float(niveau) / float(af.niveau_div))
	sim.items[uid] = {"uid": uid, "name_key": "item.arme_fantome.name", "type": "arme", "equip_slot": "main_principale", "hands": 1, "functionality": str(af.functionality), "durete_base": durete, "qualite": 1.0, "element": element, "tags": ["arme", "fantome"], "materiau": "", "fantome": true, "fini": true, "dernier_tick": tick, "affixes": [], "sertissures": {"nombre": 0, "contenu": []}}
	var portee: String = e.equipement.get("main_principale", "")
	if not portee.is_empty():
		e.sac.append(portee)
	e.equipement["main_principale"] = uid
	Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
	e.compteur = tick + int(af.ticks)
	EventBus.emettre(&"journal", [&"journal.arme_fantome", {"nom": e.name_key, "element": "element." + element}])
	return true


static func _dissiper_arme_fantome(sim: Simulation, e: Dictionary, journal: bool = true) -> void:
	var uid := "fantome_%s" % e.id
	if not sim.items.has(uid):
		return
	for slot in e.equipement.keys():
		if str(e.equipement[slot]) == uid:
			e.equipement.erase(slot)
	e.sac.erase(uid)
	sim.items.erase(uid)
	Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
	if journal:
		EventBus.emettre(&"journal", [&"journal.arme_fantome_dissipee", {}])


## L'entretien des lames fantômes (au pas de leur horloge) : du mana à intervalles, sinon la lame se dissipe.
static func _tiquer_armes_fantomes(sim: Simulation, nom: String, tick: int) -> void:
	var af: Dictionary = sim.regles.r.armes_fantomes
	for e in sim.vivants():
		if e.horloge != nom:
			continue
		var uid := "fantome_%s" % e.id
		if not sim.items.has(uid):
			continue
		if str(e.equipement.get("main_principale", "")) != uid:   # rangée : elle n'existe qu'en main
			_dissiper_arme_fantome(sim, e)
			continue
		var it: Dictionary = sim.items[uid]
		var n := (tick - int(it.dernier_tick)) / int(af.entretien_ticks)
		if n <= 0:
			continue
		it.dernier_tick = int(it.dernier_tick) + n * int(af.entretien_ticks)
		e.mana = maxi(0, int(e.mana) - n * int(af.entretien_mana))
		if int(e.mana) <= 0:
			_dissiper_arme_fantome(sim, e)


## Incarner un compagnon (Changer de personnage) : le contrôle est un attribut — on l'échange.
static func _incarner(sim: Simulation, e: Dictionary, pnj_id: String, tick: int) -> bool:
	var c: Dictionary = sim.entites.get(pnj_id, {})
	if c.is_empty() or not c.vivant or str(c.get("maitre", "")) != e.id or Grille.distance(e.pos, c.pos) > 2:
		return false
	if "humanoide" in c.get("tags", []) and SimPnj.relation_de(sim, c, e) < int(sim.regles.r.talents.incarnation.relation_min):
		EventBus.emettre(&"journal", [&"journal.incarner_refuse", {}])
		return false
	c.controle = e.controle
	c.erase("maitre")
	c.camp = e.camp
	if not c.has("spawn") and e.has("spawn"):
		c["spawn"] = e.spawn
	e.controle = "ia"
	e["maitre"] = c.id
	e["ordre"] = "suivre"
	e["ai_profile"] = "compagnon"
	c["vue_sale"] = true
	if sim.attente.has(e.id):
		sim.attente.erase(e.id)
	sim.attente[c.id] = true
	c.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.incarne", {"nom": c.name_key, "ancien": e.name_key}])
	EventBus.emettre(&"controle_change", [c.id])
	return true


## Le Lycanthrope (Talents de race) : la forme bestiale, à volonté ou sous la lune.
static func _transformer(sim: Simulation, e: Dictionary, tick: int) -> bool:
	if not a_talent(sim, e, "lune"):
		return false
	if bool(e.get("forme_bestiale", false)) and bool(e.get("forme_forcee", false)):
		EventBus.emettre(&"journal", [&"journal.forme_forcee", {}])
		return false
	_poser_forme(sim, e, not bool(e.get("forme_bestiale", false)))
	e.compteur = tick + int(sim.regles.r.talents.lune.ticks_transformation)
	return true


static func _poser_forme(sim: Simulation, e: Dictionary, bestiale: bool) -> void:
	e["forme_bestiale"] = bestiale
	if bestiale:
		e["forme_mult"] = float(sim.regles.r.talents.lune.stats_mult)
		sim._quitter_garde(e)
	else:
		e.erase("forme_mult")
		e.erase("forme_forcee")
	Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
	EventBus.emettre(&"journal", [&"journal.transformation" if bestiale else &"journal.forme_humaine", {"nom": e.name_key}])


## Attaquer sous forme bestiale : la première action de créature de la forme qui atteint la cible.
static func _attaquer_bete(sim: Simulation, e: Dictionary, cible: Dictionary, tick: int) -> bool:
	if not cible.vivant:
		return false
	var jeu: Array = sim.regles.r.talents.lune.actions if bool(e.get("forme_bestiale", false)) else e.get("actions", [])
	for aid in jeu:
		var action: Dictionary = sim.actions_creatures.get(str(aid), {})
		if not action.is_empty() and sim._action_creature_possible(e, action, cible):
			# Embuscade : la frappe qui OUVRE le combat contre une cible qui ne se bat pas encore est une surprise
			e["surprise_sur"] = str(cible.id) if not sim.en_combat(cible) else ""
			if not sim.en_combat(e):
				sim._engager_combat(e, cible)
			sim._lancer_action_creature(e, action, cible, tick)
			return true
	return false


## Embuscade (Prototype de combat — six axes, axe 5) : une action passive `bonus_premiere_attaque` de
## l'attaquant ajoute ses dés à la **première** frappe portée sur une cible surprise — celle contre qui
## cette frappe ouvre le combat. Une seule fois par proie : après, elle est prévenue.
static func _bonus_embuscade(sim: Simulation, e: Dictionary, c: Dictionary) -> int:
	if str(e.get("surprise_sur", "")) != str(c.id):
		return 0
	e.surprise_sur = ""
	var bonus := 0
	for aid in e.get("actions", []):
		for effet: Dictionary in sim.actions_creatures.get(str(aid), {}).get("effets", []):
			if str(effet.get("type", "")) == "bonus_premiere_attaque":
				bonus += int(effet.get("des", 0))
	if bonus > 0:
		EventBus.emettre(&"journal", [&"journal.embuscade", {"att": e.name_key, "def": c.name_key, "des": bonus}])
	return bonus


static func _devenir_lycanthrope(sim: Simulation, e: Dictionary) -> void:
	_retirer_statut(sim, e, "morsure_lunaire")
	e["race_origine"] = str(e.get("race", ""))
	e.race = "lycanthrope"
	e["tags_acquis_race"] = GameData.catalogues.races.lycanthrope.get("tags_acquis", []).duplicate()
	_contreparties(sim, e)
	EventBus.emettre(&"journal", [&"journal.lycanthrope", {"nom": e.name_key}])


## La source maudite et l'autel du rituel (Talents de race) : deux meubles de donjon, à usage unique,
## qui ouvrent une race cachée à qui n'en porte pas déjà une.
static func _rituel_race(sim: Simulation, e: Dictionary, vers: Vector2i, type_meuble: String, tick: int) -> bool:
	if not sim.grille.dans(vers) or Grille.distance(e.pos, vers) > 1:
		return false
	var gi := sim.grille.idx(vers)
	var id_meuble := str(sim.grille.meubles.get(gi, ""))
	if id_meuble.is_empty():   # pas de meuble sur la tuile : rien à interroger (le fuzz pousse cette intention partout)
		return false
	if str(GameData.entree("meubles", id_meuble).get("type_meuble", "")) != type_meuble:
		return false
	if str(e.get("race", "")) in ["vampire", "spectre", "lycanthrope"]:
		EventBus.emettre(&"journal", [&"journal.deja_maudit", {}])
		return false
	sim.grille.meubles.erase(gi)   # à usage unique : la source se tarit, l'autel se brise
	sim.grille.contenu[gi] = 0
	sim.grille.marquer(vers)
	sim.lumiere_sale = true
	EventBus.emettre(&"tile_changed", [vers])
	e.compteur = tick + int(sim.regles.r.actions.objet)
	if type_meuble == "source_maudite":
		EventBus.emettre(&"journal", [&"journal.source_bue", {"nom": e.name_key}])
		_devenir_vampire(sim, e)
	else:
		EventBus.emettre(&"journal", [&"journal.rituel_accompli", {"nom": e.name_key}])
		_devenir_lycanthrope(sim, e)
	return true


## Le Spectre (Talents de race) : se relever spectre, traverser un mur d'une tuile.
static func _devenir_spectre(sim: Simulation, e: Dictionary) -> void:
	e["race_origine"] = str(e.get("race", ""))
	e.race = "spectre"
	e["tags_acquis_race"] = GameData.catalogues.races.spectre.get("tags_acquis", []).duplicate()
	for slot in sim.regles.r.talents.sans_chair.slots_refuses:
		if e.equipement.has(str(slot)):
			e.equipement.erase(str(slot))
	_contreparties(sim, e)
	EventBus.emettre(&"journal", [&"journal.spectre", {"nom": e.name_key}])


static func _traverser_mur(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if not a_talent(sim, e, "sans_chair") or Grille.distance(e.pos, vers) != 2 or not sim.grille.dans(vers):
		return false
	var d: Vector2i = vers - e.pos
	if not (d.x == 0 or d.y == 0 or absi(d.x) == absi(d.y)):
		return false
	var milieu: Vector2i = e.pos + Vector2i(signi(d.x), signi(d.y))
	if not sim.grille.bloque_passage(milieu) or sim.grille.bloque_passage(vers) or not sim.grille.occupant(vers).is_empty():
		return false
	if Etres.bloque_statuts(e, "deplacement", sim.statuts_defs):
		return false
	sim._quitter_garde(e)
	sim.grille.liberer(e.pos)
	e.orientation = Vector2i(signi(d.x), signi(d.y))
	e.pos = vers
	sim.grille.placer(e.id, vers)
	e["vue_sale"] = true
	e.compteur = tick + 2 * sim.regles.ticks_deplacement(int(sim.regles.r.deplacement.cout_base), e.competences_eff, sim.en_combat(e))
	sim._declencher_glyphe(e, vers)
	EventBus.emettre(&"journal", [&"journal.traverse_mur", {"nom": e.name_key}])
	return true


## Le Vampire (Talents de race) : la nuit le porte, le jour le brûle ; les mordus s'éveillent à l'aube.
static func _tiquer_vampires(sim: Simulation, nom: String, tick: int) -> void:
	var nuit: bool = SimTerrain.est_nuit(sim)
	var refresh := int(sim.regles.r.talents.get("soif_de_sang", {}).get("refresh_ticks", 200))
	for e in sim.vivants():
		if e.horloge != nom and a_talent(sim, e, "soif_de_sang"):
			continue
		if a_talent(sim, e, "soif_de_sang"):
			if nuit:
				sim.appliquer_statut(e, "sang_de_la_nuit", refresh, e.id)
				_retirer_statut(sim, e, "soleil")
			else:
				_retirer_statut(sim, e, "sang_de_la_nuit")
				if sim.lieu != "donjon":
					sim.appliquer_statut(e, "soleil", refresh, e.id)
		elif not nuit and Etres.a_statut_tag(e, "morsure", sim.statuts_defs):
			_devenir_vampire(sim, e)
		if a_talent(sim, e, "lune"):   # la lune : une nuit sur trente, la bête s'impose
			var jour_idx := int(sim.horloge_monde.ticks / int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000)))
			if nuit and jour_idx > 0 and jour_idx % int(sim.regles.r.talents.lune.nuit_forcee_toutes_les) == 0 and not bool(e.get("forme_forcee", false)):   # jamais la première nuit
				if not bool(e.get("forme_bestiale", false)):
					_poser_forme(sim, e, true)
				e["forme_forcee"] = true
				EventBus.emettre(&"journal", [&"journal.forme_forcee", {}])
			elif not nuit and bool(e.get("forme_forcee", false)):
				_poser_forme(sim, e, false)
		elif not nuit and Etres.a_statut_tag(e, "morsure_lune", sim.statuts_defs):
			_devenir_lycanthrope(sim, e)


static func _retirer_statut(sim: Simulation, e: Dictionary, id: String) -> void:
	var avant: int = e.statuts.size()
	e.statuts = e.statuts.filter(func(s0: Dictionary) -> bool: return str(s0.id) != id)
	if e.statuts.size() != avant and Etres.statut_touche_stats(id, sim.statuts_defs):
		Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)


static func _devenir_vampire(sim: Simulation, e: Dictionary) -> void:
	_retirer_statut(sim, e, "morsure")
	e["race_origine"] = str(e.get("race", ""))
	e.race = "vampire"
	e["tags_acquis_race"] = GameData.catalogues.races.vampire.get("tags_acquis", []).duplicate()   # vision nocturne, relu par Etres.recalculer
	_contreparties(sim, e)
	e["vue_sale"] = true
	EventBus.emettre(&"journal", [&"journal.vampire", {"nom": e.name_key}])


## Mordre un être adjacent : des dégâts, la jauge pleine de son élément, et la Morsure aux humanoïdes.
static func _mordre(sim: Simulation, e: Dictionary, cible_id: String, tick: int) -> bool:
	var c: Dictionary = sim.entites.get(cible_id, {})
	if not a_talent(sim, e, "soif_de_sang") or c.is_empty() or not c.vivant or Grille.distance(e.pos, c.pos) != 1:
		return false
	var deg := sim.des.jet(str(sim.regles.r.talents.soif_de_sang.degats_morsure))
	sim._appliquer_degats(c, deg, e.id, {"type": "perforant", "element": {}, "morsure": true})
	if e.has("chaine"):
		var elem := sim.wuxing.dominante(c.get("elements", {}) if c.get("elements") != null else {})
		if elem.is_empty():
			elem = "eau"
		while e.chaine.segments.size() < int(e.chaine.capacite) - 1:
			sim.wuxing.poser(e.chaine, elem, tick)
	if c.vivant and "humanoide" in c.get("tags", []):
		sim.appliquer_statut(c, "morsure", int(sim.statuts_defs.morsure.duree_ticks), e.id)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.morsure", {"nom": e.name_key, "cible": c.name_key, "degats": deg}])
	return true


## Le Fossoyeur (Talents de classe) : relever un cadavre en invocation temporaire, contre de la réputation.
static func _relever(sim: Simulation, e: Dictionary, cible_id: String, tick: int) -> bool:
	var c: Dictionary = sim.entites.get(cible_id, {})
	var rl: Dictionary = sim.regles.r.talents.releveur
	if not a_talent(sim, e, "releveur") or c.is_empty() or Grille.distance(e.pos, c.pos) > int(rl.portee):
		return false
	return _relever_brut(sim, e, c, tick)


## Le relevé lui-même, sans le talent : le noyau *Relevé* y accède en payant son mana (Modules).
static func _relever_brut(sim: Simulation, e: Dictionary, c: Dictionary, tick: int) -> bool:
	var rl: Dictionary = sim.regles.r.talents.releveur
	if c.is_empty() or c.vivant or bool(c.get("releve", false)) or not sim.grille.occupant(c.pos).is_empty():
		return false
	c["releve"] = true
	var x: Dictionary = SimObjets.ajouter(sim, str(c.def), c.pos, "ia")
	x.camp = e.camp
	x["maitre"] = e.id
	x["fin_invocation"] = tick + int(rl.duree_ticks)
	x.horloge = e.horloge
	x.compteur = tick + 1
	if not ("releve" in x.get("tags", [])):
		x.tags.append("releve")
	if not e.has("reputations"):
		e["reputations"] = {}
	for v in e.reputations.keys():
		e.reputations[v] = clampi(int(e.reputations[v]) + int(rl.reputation), -100, 100)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.releve", {"nom": e.name_key, "cible": c.name_key, "n": -int(rl.reputation)}])
	return true


## L'Engrenage : déployer l'affût sur une tuile libre adjacente — une seule, redéployer la déplace.
static func _deployer_affut(sim: Simulation, e: Dictionary, t: Vector2i, tick: int) -> bool:
	if not a_talent(sim, e, "affut") or Grille.distance(e.pos, t) != 1 or not sim.grille.dans(t) or sim.grille.bloque_passage(t) or not sim.grille.occupant(t).is_empty():
		return false
	_replier_affut(sim, e)
	sim.grille.poser_contenu(t, "barriere")
	sim.affuts.append({"pos": t, "source": e.id, "prochain": tick + int(sim.regles.r.talents.affut.cadence_ticks)})   # le temps de l'armer
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.affut_pose", {"nom": e.name_key}])
	EventBus.emettre(&"tile_changed", [t])
	return true


static func _replier_affut(sim: Simulation, e: Dictionary) -> void:
	for a in sim.affuts.duplicate():
		if str(a.source) == e.id:
			sim.grille.contenu[sim.grille.idx(a.pos)] = 0
			EventBus.emettre(&"tile_changed", [a.pos])
			sim.affuts.erase(a)


## Les affûts tirent à leur cadence sur l'ennemi le plus proche, avec les éléments de l'arme du propriétaire ;
## chaque tir consomme une munition du carquois, sans munition l'affût se replie.
static func _tirs_d_affuts(sim: Simulation, nom: String, tick: int) -> void:
	var af: Dictionary = sim.regles.r.talents.get("affut", {})
	for a in sim.affuts.duplicate():
		var src: Dictionary = sim.entites.get(str(a.source), {})
		if src.is_empty() or src.horloge != nom or int(a.prochain) > tick:
			continue
		if not src.vivant:
			_replier_affut(sim, src)
			continue
		var autonome: bool = a.has("fin")   # une Tourelle invoquée : ses ticks, ses dés, pas de carquois
		if autonome and int(a.fin) <= tick:
			sim.grille.contenu[sim.grille.idx(a.pos)] = 0
			EventBus.emettre(&"tile_changed", [a.pos])
			sim.affuts.erase(a)
			continue
		if not autonome and int(src.munitions) <= 0:   # le compteur de munitions de l'être (Projectiles)
			EventBus.emettre(&"journal", [&"journal.affut_replie", {}])
			_replier_affut(sim, src)
			continue
		a.prochain = tick + int(a.get("cadence", af.cadence_ticks))
		var cible: Dictionary = {}
		var dmin: int = int(a.get("portee", af.portee)) + 1
		for x in sim.vivants():
			if x.camp == src.camp or x.camp == "civil":
				continue
			var dist := Grille.distance(a.pos, x.pos)
			if dist < dmin and sim.grille.ligne_de_vue(a.pos, x.pos):
				dmin = dist
				cible = x
		if cible.is_empty():
			continue
		if not autonome:
			src.munitions = int(src.munitions) - 1
			src.munitions_tirees = int(src.get("munitions_tirees", 0)) + 1
		var arme := Etres.arme(src, sim.items)
		var elems: Dictionary = a.get("elements", {}) if autonome and not a.get("elements", {}).is_empty() else (arme.get("elements", {}) if arme.get("elements") != null else {})
		var deg := sim.des.jet(str(a.get("degats", af.degats)))
		sim._appliquer_degats(cible, deg, src.id, {"type": str(af.get("type", "perforant")), "element": elems, "affut": true})
		EventBus.emettre(&"journal", [&"journal.affut_tire", {"nom": cible.name_key, "degats": deg}])


## Le Masque (Talents de classe) : porter ou retirer un masque — un statut, à 0 tick, deux au plus.
static func _porter_masque(sim: Simulation, e: Dictionary, id: String, _tick: int) -> bool:
	var d: Dictionary = sim.statuts_defs.get(id, {})
	if not a_talent(sim, e, "masques") or d.is_empty() or not ("masque" in d.get("tags", [])):
		return false
	var portes: Array = e.statuts.filter(func(s0: Dictionary) -> bool: return "masque" in sim.statuts_defs.get(str(s0.id), {}).get("tags", []))
	for s0 in portes:
		if str(s0.id) == id:
			e.statuts.erase(s0)
			Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
			EventBus.emettre(&"journal", [&"journal.masque", {"nom": e.name_key, "masque": d.name_key}])
			return true
	while portes.size() >= int(sim.regles.r.talents.masques.max):
		e.statuts.erase(portes.pop_front())
	sim.appliquer_statut(e, id, int(d.duree_ticks), e.id)
	EventBus.emettre(&"journal", [&"journal.masque", {"nom": e.name_key, "masque": d.name_key}])
	return true


## La marque au sol d'un glyphe s'efface — sauf si un feu ou de la lave occupe encore la tuile.
static func _oublier_glyphe(sim: Simulation, pos: Vector2i) -> void:
	var idx := sim.grille.idx(pos)
	if sim.feux.has(idx) or "lave" in sim.grille.contenu_de(pos).get("tags", []):
		return
	sim.grille.dangers.erase(idx)


## Le Sceau : déclencher à distance l'un de ses glyphes — la charge part sur la tuile, occupée ou non.
static func _declencher_glyphe_distance(sim: Simulation, e: Dictionary, pos: Vector2i, tick: int) -> bool:
	if not a_talent(sim, e, "graveur") or Grille.distance(e.pos, pos) > int(sim.regles.r.talents.graveur.portee_declenchement):
		return false
	for gl in sim.glyphes.duplicate():
		if gl.pos != pos or str(gl.source) != e.id:
			continue
		sim.glyphes.erase(gl)
		_oublier_glyphe(sim, pos)
		var charge: Dictionary = gl.plan.duplicate()
		charge.geometrie = "point"
		e.compteur = tick + int(sim.regles.r.actions.objet)
		EventBus.emettre(&"journal", [&"journal.glyphe_distance", {"nom": e.name_key}])
		sim._executer_capacite(e, charge, pos, true)
		return true
	return false


## Contreparties permanentes des talents (Talents de classe) : posées sur l'être, lues par Etres.recalculer.
static func _contreparties(sim: Simulation, e: Dictionary) -> void:
	if a_talent(sim, e, "breche"):
		e["mana_max_mult"] = float(sim.regles.r.talents.breche.mana_max_mult)
	else:
		e.erase("mana_max_mult")
	Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)


## Le Passeur : poser un portail sur une tuile libre adjacente ; le troisième déplace le plus ancien.
static func _poser_portail(sim: Simulation, e: Dictionary, t: Vector2i, tick: int) -> bool:
	if not a_talent(sim, e, "breche") or Grille.distance(e.pos, t) != 1 or not sim.grille.dans(t) or sim.grille.bloque_passage(t) or not sim.grille.occupant(t).is_empty():
		return false
	if sim.portails.has(t):
		return false
	if not e.has("portails"):
		e["portails"] = []
	while e.portails.size() >= int(sim.regles.r.talents.breche.portails_max):
		sim.portails.erase(e.portails.pop_front())
	e.portails.append(t)
	sim.portails[t] = e.id
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.portail_pose", {"nom": e.name_key}])
	return true


## Traverser : debout sur un portail, vers son jumeau s'il est libre (ouvert à tous).
static func _traverser(sim: Simulation, e: Dictionary, tick: int) -> bool:
	if not sim.portails.has(e.pos):
		return false
	var p: Dictionary = sim.entites.get(str(sim.portails[e.pos]), {})
	if p.is_empty():
		return false
	for j in p.get("portails", []):
		if j != e.pos and sim.portails.has(j):
			var vers: Vector2i = j
			if not sim.grille.occupant(vers).is_empty():
				return false
			sim.grille.liberer(e.pos)
			e.pos = vers
			sim.grille.placer(e.id, vers)
			e["vue_sale"] = true
			e.compteur = tick + int(sim.regles.r.actions.objet)
			EventBus.emettre(&"journal", [&"journal.traverse", {"nom": e.name_key}])
			return true
	return false


## Le portail qui rapproche le plus du but (Talents de classe) : Vector2i(-1, -1) si aucun ne vaut le détour.
## Retourne la tuile du portail à rejoindre — si c'est celle où l'on est déjà, il n'y a qu'à traverser.
static func portail_utile(sim: Simulation, e: Dictionary, but: Vector2i) -> Vector2i:
	if sim.portails.is_empty():
		return Vector2i(-1, -1)
	var br: Dictionary = sim.regles.r.talents.get("breche", {})
	var portee := int(br.get("ia_portee", 8))
	var meilleur := Vector2i(-1, -1)
	var meilleur_gain := int(br.get("ia_gain_min", 6)) - 1
	for entree in sim.portails.keys():
		if not sim.grille.dans(entree):
			continue
		var d_entree := Grille.distance(e.pos, entree)
		if d_entree > portee or (d_entree > 0 and not sim.grille.occupant(entree).is_empty()):
			continue
		var p: Dictionary = sim.entites.get(str(sim.portails[entree]), {})
		for j in p.get("portails", []):
			if j == entree or not sim.portails.has(j):
				continue
			var sortie: Vector2i = j
			if not sim.grille.occupant(sortie).is_empty():
				continue
			var gain := Grille.distance(e.pos, but) - (d_entree + Grille.distance(sortie, but))
			if gain > meilleur_gain:
				meilleur_gain = gain
				meilleur = entree
	return meilleur


## Le pas d'une IA qui passe par un portail : vrai si elle a traversé ou avancé vers la brèche.
static func _ia_par_portail(sim: Simulation, e: Dictionary, but: Vector2i, tick: int) -> bool:
	var entree := portail_utile(sim, e, but)
	if entree == Vector2i(-1, -1):
		return false
	if entree == e.pos:
		return _traverser(sim, e, tick)
	var pas := sim.grille.chemin(e.pos, entree, Etres.est_volant(e), "", sim.refuse_nage(e))
	return not pas.is_empty() and sim._deplacer(e, pas[0], tick)


## Le Sablier : voler du tempo — l'ennemi recule, le Sablier avance d'autant, et paie en santé.
static func _voler_tempo(sim: Simulation, e: Dictionary, cible_id: String, tick: int) -> bool:
	var c: Dictionary = sim.entites.get(cible_id, {})
	var st: Dictionary = sim.regles.r.talents.maitre_du_tempo
	if not a_talent(sim, e, "maitre_du_tempo") or c.is_empty() or not c.vivant or Grille.distance(e.pos, c.pos) > int(st.portee) or int(e.sante) <= int(st.sante):
		return false
	var n: int = sim._tempo(c, int(st.tempo_vole), e.id)
	if n <= 0:
		EventBus.emettre(&"journal", [&"journal.tempo_refuse", {}])
		return false
	e.sante = maxi(1, int(e.sante) - int(st.sante))
	e.compteur = tick + int(sim.regles.r.actions.objet)
	sim._tempo(e, -n, e.id)
	EventBus.emettre(&"journal", [&"journal.tempo_vole", {"nom": e.name_key, "cible": c.name_key, "n": n, "sante": int(st.sante)}])
	return true


## Le Porteur (Talents de classe) : saisir un être adjacent — il est immobilisé, le Porteur ne frappe ni ne se garde.
static func _saisir(sim: Simulation, e: Dictionary, cible_id: String, tick: int, par_talent: bool = true) -> bool:
	var c: Dictionary = sim.entites.get(cible_id, {})
	if (par_talent and not a_talent(sim, e, "saisie")) or c.is_empty() or not c.vivant or c.id == e.id or Grille.distance(e.pos, c.pos) != 1 or not str(e.get("porte", "")).is_empty():
		return false
	if Etres.bloque_statuts(c, "projection", sim.statuts_defs):
		return false   # Ancrage : on ne l'empoigne pas non plus
	e["porte"] = cible_id
	c["saisi_par"] = e.id
	sim.appliquer_statut(c, "saisi", int(sim.statuts_defs.saisi.duree_ticks), e.id)
	sim._quitter_garde(e)
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.saisi", {"nom": e.name_key, "cible": c.name_key}])
	return true


## Lancer l'être saisi vers une tuile : projection de distance_lancer dans cette direction, dégâts à l'arrivée.
static func _lancer_etre(sim: Simulation, e: Dictionary, vers: Vector2i, tick: int) -> bool:
	var c: Dictionary = sim.entites.get(str(e.get("porte", "")), {})
	if c.is_empty():
		return false
	var d := Vector2i(signi(vers.x - e.pos.x), signi(vers.y - e.pos.y))
	if d == Vector2i.ZERO:
		return false
	var sa: Dictionary = sim.regles.r.talents.saisie
	# On place la cible du côté du lancer, puis on la projette.
	var depart: Vector2i = e.pos + d
	if sim.grille.dans(depart) and not sim.grille.bloque_passage(depart) and (sim.grille.occupant(depart).is_empty() or sim.grille.occupant(depart) == c.id):
		sim.grille.liberer(c.pos)
		c.pos = depart
		sim.grille.placer(c.id, depart)
	var cibles: Array[Dictionary] = [c]
	sim._effet_deplacement(e, {"mode": "projection", "distance": str(int(sa.distance_lancer) - 1)}, cibles, {})
	_liberer_saisie(sim, e, c)
	var deg := sim.des.jet(str(sa.degats_lancer))
	sim._appliquer_degats(c, deg, e.id, {"type": "contondant", "element": {}, "lancer": true})
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.lance", {"nom": e.name_key, "cible": c.name_key, "degats": deg}])
	return true


static func _liberer_saisie(sim: Simulation, e: Dictionary, c: Dictionary) -> void:
	e.erase("porte")
	c.erase("saisi_par")
	c.statuts = c.statuts.filter(func(s0: Dictionary) -> bool: return str(s0.id) != "saisi")


## La cible saisie se débat à son tour : jet de Force opposé, elle se libère si elle gagne.
static func _ia_se_debattre(sim: Simulation, c: Dictionary, tick: int) -> bool:
	var p: Dictionary = sim.entites.get(str(c.get("saisi_par", "")), {})
	if p.is_empty() or not p.vivant or str(p.get("porte", "")) != c.id:
		c.erase("saisi_par")
		return false
	if sim.des.jet("1d20") + int(c.stats_eff.force) / 2 > sim.des.jet("1d20") + int(p.stats_eff.force) / 2:
		_liberer_saisie(sim, p, c)
		EventBus.emettre(&"journal", [&"journal.debat", {"nom": c.name_key}])
	c.compteur = tick + int(sim.regles.r.actions.objet)
	return true


static func niveau_arme(sim: Simulation, e: Dictionary) -> int:
	var arme := Etres.arme(e, sim.items)
	var fonct: Dictionary = sim.fonctionnalites.get(str(arme.get("functionality", "")), {})
	return sim.regles.niveau(e.competences_eff, str(fonct.get("combat_skill", "")))


## La grille de composition d'un être (Six types de modules et assemblage, designer 2026-09-03) : la
## silhouette de la VOIE de l'arme tenue — la stat de sa compétence — au palier de son niveau. Sans
## arme, la grille de poche. C'est ce contenant qui borne ce qu'on peut composer, et rien d'autre.
static func grille_composition(sim: Simulation, e: Dictionary, id_grille: String = "") -> Dictionary:
	var arme := Etres.arme(e, sim.items)
	if arme.is_empty():   # les mains nues sont une arme de force (compétence `mains_nues`) : la grille du guerrier, pas une grille de poche
		arme = sim.arme_mains_nues()
	var fonct: Dictionary = sim.fonctionnalites.get(str(arme.get("functionality", "")), {})
	var comp: Dictionary = GameData.catalogues.competences.get(str(fonct.get("combat_skill", "")), {})
	var stat := str(comp.get("stat", ""))
	# le niveau de LA compétence de l'arme résolue — à poings nus, celle des mains nues (revue du 2026-09-04 :
	# `niveau_arme` relisait la main vide et rendait toujours le palier 0 au bagarreur)
	var niveau := sim.regles.niveau(e.get("competences_eff", e.get("competences", {})), str(fonct.get("combat_skill", "")))
	# Le joueur possède plusieurs grilles (designer 2026-09-04) : s'il en a choisi une qu'il possède,
	# c'est là qu'il compose ; sinon — créature, robot, vieille sauvegarde — la grille de sa voie.
	# Une grille par étape (designer 2026-09-04) : l'étape peut nommer une fiche possédée ; sinon l'active.
	var active := id_grille if (not id_grille.is_empty() and id_grille in e.get("grilles", [])) else str(e.get("grille_active", ""))
	if not active.is_empty() and active in e.get("grilles", []):
		var cases_a: Array = sim.grille_sort.cases_de_grille(active)
		if not cases_a.is_empty():
			var fiche: Dictionary = GameData.catalogues.get("grilles", {}).get(active, {})
			return {"stat": str(fiche.get("voie", stat)), "niveau": niveau, "cases": cases_a, "grille": active}
	return {"stat": stat, "niveau": niveau, "cases": sim.grille_sort.grille_de(stat, niveau), "grille": sim.grille_sort.id_grille_de(stat, niveau)}


## Apprendre une grille (une trame lue, un palier franchi, le kit de départ) : elle entre dans la
## collection, et devient celle où l'on compose si l'on n'en avait pas encore choisi.
static func apprendre_grille(sim: Simulation, e: Dictionary, id: String) -> bool:
	if not GameData.catalogues.get("grilles", {}).has(id):
		return false
	if not e.has("grilles"):
		e["grilles"] = []
	if id in e.grilles:
		return false
	e.grilles.append(id)
	if str(e.get("grille_active", "")).is_empty():
		e["grille_active"] = id
	EventBus.emettre(&"journal", [&"journal.grille_apprise", {"nom": e.name_key, "grille": GameData.catalogues.grilles[id].name_key}])
	return true


## Choisir la grille où l'on compose : une de celles qu'on possède, ou "" pour revenir à celle de sa voie.
static func choisir_grille(sim: Simulation, e: Dictionary, id: String) -> bool:
	if not id.is_empty() and not (id in e.get("grilles", [])):
		return false
	e["grille_active"] = id
	if not id.is_empty():
		EventBus.emettre(&"journal", [&"journal.grille_choisie", {"nom": e.name_key, "grille": GameData.catalogues.grilles[id].name_key}])
	return true


## Les grilles que les paliers d'une compétence d'arme accordent à ce niveau : celles de sa voie,
## jusqu'au palier atteint. Appelé à chaque niveau gagné.
static func _debloquer_grilles_de_palier(sim: Simulation, e: Dictionary, competence: String, niveau: int) -> void:
	var comp: Dictionary = GameData.catalogues.competences.get(competence, {})
	if str(comp.get("famille", "")) != "armes":
		return
	var stat := str(comp.get("stat", ""))
	for p in sim.grille_sort.paliers_de(stat):
		if niveau >= int(p.get("niveau_min", 0)) and p.has("grille"):
			apprendre_grille(sim, e, str(p.grille))


## L'emboîtement d'une séquence dans les grilles de l'être — une grille par ÉTAPE (designer 2026-09-04) :
## un déclencheur ferme une étape et ouvre la suivante, chacune se range dans sa grille (`grilles[k]` si
## l'étape en nomme une possédée, sinon l'active). Retourne {ok, etapes: [{ok, placement, demande, capacite,
## manque, cases, stat, grille}], placement (toutes étapes), demande, capacite, manque, cases, stat, grille
## (ceux de la première étape)}. L'écran s'en sert pour dessiner ; la composition pour refuser.
static func emboitement(sim: Simulation, e: Dictionary, sequence: Array, grilles: Array = []) -> Dictionary:
	var res := {"ok": true, "etapes": [], "placement": [], "demande": 0, "capacite": 0, "manque": 0, "cases": [], "stat": "", "grille": ""}
	var etapes: Array = sim.grille_sort.etapes_de(sequence)
	for k in etapes.size():
		var g := grille_composition(sim, e, str(grilles[k]) if k < grilles.size() else "")
		var emb := sim.grille_sort.emboiter(etapes[k], g.cases)   # porte déjà demande, capacite, manque
		res.etapes.append({"ok": bool(emb.ok), "placement": emb.placement, "demande": int(emb.demande), "capacite": int(emb.capacite),
			"manque": int(emb.manque), "cases": g.cases, "stat": g.stat, "grille": str(g.get("grille", ""))})
		res.ok = res.ok and bool(emb.ok)
		(res.placement as Array).append_array(emb.placement)
		res.demande += int(emb.demande)
		res.capacite += int(emb.capacite)
		res.manque += int(emb.manque)
		if k == 0:
			res.cases = g.cases
			res.stat = g.stat
			res.grille = str(g.get("grille", ""))
	return res


## Composer une capacité depuis des modules connus : l'assembleur juge la séquence, les slots bornent le **nombre**
## de capacités tenues prêtes — pas la longueur d'une séquence (assemblage sans limite, 2026-08-30).
static func composer_capacite(sim: Simulation, e: Dictionary, sequence: Array, nom: String = "", grilles: Array = [], crans: Array = []) -> bool:
	if sequence.is_empty():   # plus de plafond de capacités non plus (décision du designer, 2026-08-30) : on en compose autant qu'on veut
		EventBus.emettre(&"journal", [&"journal.capacite_refusee", {}])
		return false
	for m in sequence:
		if not (str(m) in e.get("modules_connus", [])):
			EventBus.emettre(&"journal", [&"journal.capacite_refusee", {}])
			return false
	var plan := sim.capacites.assembler(sequence.duplicate(), 10, "1d4", {}, e.competences_eff, crans)
	if not plan.erreurs.is_empty():
		EventBus.emettre(&"journal", [&"journal.capacite_refusee", {}])
		return false
	# La grille (designer 2026-09-03) : la seule borne structurelle. Elle ne juge pas la séquence —
	# l'assembleur l'a déjà acceptée — elle juge si les pièces TIENNENT dans le contenant de l'arme.
	var emb := emboitement(sim, e, sequence, grilles)
	if not emb.ok:
		EventBus.emettre(&"journal", [&"journal.capacite_trop_grande", {"demande": int(emb.demande), "cases": int(emb.capacite), "manque": int(emb.manque)}])
		return false
	var noyau: Dictionary = plan.noyau
	var nom_key := str(noyau.get("name_key", "capacite.etincelle.name"))
	if not nom.strip_edges().is_empty():   # le nom choisi par le joueur (Écrans d'interface) : tr() le rend tel quel
		nom_key = nom.strip_edges()
	var cap := {"id": "cap_%d_%d" % [e.get("capacites", []).size(), sequence.hash()], "name_key": nom_key, "modules": sequence.duplicate()}
	if not grilles.is_empty():   # la grille de chaque étape, pour recomposer dans les mêmes (designer 2026-09-04)
		cap["grilles"] = grilles.duplicate()
	for c in crans:   # le cran de chaque pièce, s'il y en a un qui n'est pas zéro (designer 2026-09-04)
		if int(c) != 0:
			cap["crans"] = crans.duplicate()
			break
	if not e.has("capacites"):
		e["capacites"] = []
	e.capacites.append(cap)
	EventBus.emettre(&"journal", [&"journal.capacite_creee", {"nom": nom_key}])
	return true


static func supprimer_capacite(sim: Simulation, e: Dictionary, index: int) -> bool:
	if index < 0 or index >= e.get("capacites", []).size():
		return false
	var cap: Dictionary = e.capacites[index]
	e.capacites.remove_at(index)
	EventBus.emettre(&"journal", [&"journal.capacite_supprimee", {"nom": cap.get("name_key", "")}])
	return true


# ---------------------------------------------------------------- talents (Talents de classe, Talents de race)

## Les talents d'un être : celui de sa classe, celui de sa race, ceux qu'il a appris.
static func talents_de(sim: Simulation, e: Dictionary) -> Array:
	var res: Array = []
	var t_cl = GameData.catalogues.classes.get(str(e.get("classe", "")), {}).get("talent")
	if t_cl != null and not str(t_cl).is_empty():
		res.append(str(t_cl))
	var t_ra = GameData.catalogues.races.get(str(e.get("race", "")), {}).get("talent")
	if t_ra != null and not str(t_ra).is_empty():
		res.append(str(t_ra))
	for t in e.get("talents_appris", []):
		if not (str(t) in res):
			res.append(str(t))
	return res


static func a_talent(sim: Simulation, e: Dictionary, id: String) -> bool:
	return id in talents_de(sim, e)


## Main du métal (La Braise) : remplacer un composant d'un objet assemblé sans perdre ses affixes.
static func _reforger(sim: Simulation, e: Dictionary, objet: String, composant: String, tick: int) -> bool:
	var it: Dictionary = sim.items.get(objet, {})
	var c: Dictionary = sim.items.get(composant, {})
	var def: Dictionary = GameData.catalogues.items.get(str(it.get("base", "")), {})
	if not a_talent(sim, e, "main_du_metal") or it.is_empty() or c.is_empty() or not (composant in e.sac) or not (objet in e.sac or objet in e.equipement.values()) or not def.has("slots") or c.get("type", "") != "composant":
		EventBus.emettre(&"journal", [&"journal.reforge_refuse", {}])
		return false
	if not SimFabrication.stations_de(sim, e).has(str(def.get("recipe", {}).get("station", ""))):
		EventBus.emettre(&"journal", [&"journal.reforge_refuse", {}])
		return false
	var slot := ""
	for s0 in def.slots.keys():
		if str(def.slots[s0]) == str(c.composant):
			slot = str(s0)
	if slot.is_empty():
		EventBus.emettre(&"journal", [&"journal.reforge_refuse", {}])
		return false
	if not it.has("composants"):
		it["composants"] = {}
	it.composants[slot] = {"composant": c.composant, "materiau": c.materiau, "qualite": c.qualite}
	# Recalcul depuis les matériaux des composants présents, pondéré ; les affixes ne bougent pas.
	var poids: Dictionary = sim.regles.r.craft.poids.get(str(def.get("type", "arme")), sim.regles.r.craft.poids.arme)   # une part par type (arme, armure, bouclier, bijou)
	var stats := {}
	var elements := {}
	var q := 0.0
	var wt := 0.0
	for s1 in it.composants.keys():
		var mat: Dictionary = GameData.catalogues.materials.get(str(it.composants[s1].materiau), {})
		var w := float(poids.get(s1, 0.0))
		wt += w
		for st in mat.get("stats", {}).keys():
			stats[st] = float(stats.get(st, 0.0)) + float(mat.stats[st]) * w
		var wx = mat.get("wuxing")
		if wx is Dictionary:
			for el in wx.keys():
				elements[el] = float(elements.get(el, 0.0)) + float(wx[el]) * w
		q += float(it.composants[s1].qualite) * w
	if wt > 0.0:
		for st in stats.keys():
			stats[st] = float(stats[st]) / wt
		for el in elements.keys():
			elements[el] = float(elements[el]) / wt
		it.qualite = snappedf(q / wt, 0.01)
	it.stats = stats
	it.durete_base = roundi(float(stats.get("durete", it.get("durete_base", 0))))
	it.elements = elements
	it.element = sim.wuxing.dominante(elements)
	if slot in ["tete", "plaque"]:
		it.materiau = str(c.materiau)
	e.sac.erase(composant)
	sim.items.erase(composant)
	Etres.recalculer(e, sim.items, sim.affixes_defs, sim.regles)
	e.compteur = tick + int(sim.regles.r.craft.ticks_base)
	EventBus.emettre(&"journal", [&"journal.reforge", {"nom": e.name_key, "objet": SimObjets.nom_objet(sim, objet), "composant": GameData.entree("components", str(c.composant)).name_key}])
	return true


## Apprendre le talent de classe d'un PNJ (Sans maître, Polyvalent) : relation ≥ 75, une place.
static func _apprendre_talent(sim: Simulation, e: Dictionary, pnj_id: String, tick: int) -> bool:
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	if pnj.is_empty() or Grille.distance(e.pos, pnj.pos) > 2:
		return false
	var t = GameData.catalogues.classes.get(str(pnj.get("classe", "")), {}).get("talent")
	var talent := str(t) if t != null else ""
	var peut := a_talent(sim, e, "sans_maitre") or a_talent(sim, e, "polyvalent")
	if talent.is_empty() or talent == "sans_maitre" or not peut or SimPnj.relation_de(sim, pnj, e) < int(sim.regles.r.talents.apprendre_relation) or a_talent(sim, e, talent):
		EventBus.emettre(&"journal", [&"journal.talent_refuse", {}])
		return false
	e["talents_appris"] = [talent]   # une seule place : le nouveau remplace l'ancien
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.talent_appris", {"nom": pnj.name_key, "talent": GameData.entree("talents", talent).name_key}])
	_contreparties(sim, e)
	return true


# ---------------------------------------------------------------- entraîneur (Potentiel) et commandes de collectionneurs
