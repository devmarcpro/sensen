class_name Simulation
extends RefCounted
## La simulation autoritaire — le « serveur », même en solo (Contraintes permanentes, règle 1).
## Le client envoie des INTENTIONS (`intention()`), lit l'ÉTAT (`entites`, `grille`) et rythme
## l'avancement (`pas()`) ; il ne décide de rien. Aucune lecture d'input ici.
## Temps : une horloge du monde (temps réel) et une par combat (action) — Temporalités
## parallèles. Ordre d'un tick : entités → systèmes → EventBus (Boucle de tick).

var graine: int
var des: Des
var regles: Regles
var wuxing: WuXing
var capacites: Capacites
var grille: Grille
var arene_id: String
var entites: Dictionary = {}          # id → être (Etres.instancier)
var ordre: Array[String] = []         # ordre stable des ids (départage des égalités de compteur)
var items: Dictionary
var fonctionnalites: Dictionary
var actions_creatures: Dictionary
var profils_ia: Dictionary
var horloge_monde: Horloge
var combats: Dictionary = {}          # nom → {"horloge": Horloge, "participants": Array[String]}
var attente: Dictionary = {}          # id → true : une entité contrôlée attend une intention
var _n_combats := 0
var _n_entites := 0


func _init(p_graine: int) -> void:
	graine = p_graine
	des = Des.new(p_graine)
	regles = Regles.new(GameData.config("combat_rules"))
	wuxing = WuXing.new(GameData.config("wuxing"))
	capacites = Capacites.new(GameData.catalogues.get("modules", {}))
	items = GameData.catalogues.get("items", {})
	fonctionnalites = GameData.catalogues.get("functionalities", {})
	actions_creatures = GameData.catalogues.get("creature_actions", {})
	profils_ia = GameData.catalogues.get("ai_profiles", {})


# ---------------------------------------------------------------- mise en place

## Charge une arène de data/prototype_arenas et instancie ses êtres.
func charger_arene(id: String) -> void:
	arene_id = id
	var arene := GameData.entree("prototype_arenas", id)
	grille = Grille.depuis_arene(arene, GameData.config("tile_contents"),
		regles.r.deplacement, int(regles.r.vision.hauteur_oeil))
	entites.clear()
	ordre.clear()
	combats.clear()
	attente.clear()
	for nom in TickManager.horloges.keys():
		TickManager.retirer(nom)
	horloge_monde = TickManager.creer("monde", Horloge.Mode.TEMPS_REEL, float(regles.r.ticks_par_seconde_exploration))
	horloge_monde.avancee.connect(_sur_avancee_monde)
	var j: Dictionary = arene.spawns.player
	ajouter(j.creature, Vector2i(int(j.pos[0]), int(j.pos[1])), "joueur")
	for s: Dictionary in arene.spawns.enemies:
		ajouter(s.creature, Vector2i(int(s.pos[0]), int(s.pos[1])), "ia")


func ajouter(def_id: String, pos: Vector2i, controle: String) -> Dictionary:
	_n_entites += 1
	var id := "%s_%d" % [def_id, _n_entites]
	var e := Etres.instancier(id, GameData.entree("creatures", def_id), pos, controle, regles, items)
	if e.chain_gauge:
		e.chaine = wuxing.jauge_neuve()
	entites[id] = e
	ordre.append(id)
	grille.placer(id, pos)
	return e


func vivants() -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for id in ordre:
		if entites[id].vivant:
			res.append(entites[id])
	return res


func horloge_de(e: Dictionary) -> Horloge:
	return horloge_monde if e.horloge == "monde" else combats[e.horloge].horloge


func en_combat(e: Dictionary) -> bool:
	return e.horloge != "monde"


# ---------------------------------------------------------------- avancement

## Fait agir la prochaine entité de l'horloge `nom`. Retourne false si l'horloge est bloquée
## sur une entité contrôlée qui attend une intention (réfléchir est gratuit).
func pas(nom: String) -> bool:
	var h: Horloge = horloge_monde if nom == "monde" else combats[nom].horloge
	var e := _prochaine(nom)
	if e.is_empty():
		return false
	if h.mode == Horloge.Mode.ACTION:
		h.sauter_a(e.compteur)
	elif e.compteur > h.ticks:
		return false
	_regenerer(e, h.ticks)
	if not e.action_en_cours.is_empty():
		var a: Dictionary = e.action_en_cours
		e.action_en_cours = {}
		_resoudre_action_engagee(e, a)
		_fin_de_pas(nom)
		return true
	if e.controle == "joueur":
		attente[e.id] = true
		return false
	_decider_ia(e, h.ticks)
	_fin_de_pas(nom)
	return true


## L'entité vivante de cette horloge au plus petit compteur (ordre d'ajout en cas d'égalité).
func _prochaine(nom: String) -> Dictionary:
	var meilleure := {}
	for id in ordre:
		var e: Dictionary = entites[id]
		if e.vivant and e.horloge == nom and (meilleure.is_empty() or e.compteur < meilleure.compteur):
			meilleure = e
	return meilleure


func _sur_avancee_monde(_de: int, _a: int) -> void:
	# Temps réel : tout ce qui est dû agit, dans l'ordre des compteurs.
	var garde_fou := 64
	while garde_fou > 0 and pas("monde"):
		garde_fou -= 1


func _fin_de_pas(nom: String) -> void:
	_verifier_desengagements()
	EventBus.dispatcher()
	if nom != "monde" and not combats.has(nom):
		return


## Régénération d'endurance : +2 par tick écoulé depuis la dernière application (Endurance).
func _regenerer(e: Dictionary, tick: int) -> void:
	var ecoules := tick - int(e.tick_endurance)
	if ecoules > 0:
		e.endurance = mini(e.endurance_max, e.endurance + ecoules * int(regles.r.endurance.regen_par_tick))
		# Mana (A.5) : à chaque tranche de 10 ticks franchie, 1 chance sur 8 de rendre 1 + N_meditation × 0.2.
		var periode := int(regles.r.mana.periode_ticks)
		var tranches := tick / periode - int(e.tick_endurance) / periode
		for i in tranches:
			if des.reel() < float(regles.r.mana.chance):
				e.mana = mini(e.mana_max, e.mana + roundi(float(regles.r.mana.regen_base)))
	e.tick_endurance = tick


# ---------------------------------------------------------------- intentions (client → serveur)

## Une intention pour l'entité `id`, qui doit être en attente. Valide, exécute, retourne
## vrai si elle a été consommée. Types : deplacer{vers} · attaquer{cible, lourde} · garde · attendre.
func intention(id: String, i: Dictionary) -> bool:
	if not attente.has(id) or not entites.has(id):
		return false
	var e: Dictionary = entites[id]
	if not e.vivant:
		return false
	var h := horloge_de(e)
	_regenerer(e, h.ticks)
	var ok := false
	match str(i.get("type", "")):
		"deplacer":
			ok = _deplacer(e, i.vers, h.ticks)
		"attaquer":
			if entites.has(i.cible):
				ok = _attaquer_arme(e, entites[i.cible], bool(i.get("lourde", false)), h.ticks)
		"garde":
			ok = _prendre_garde(e, h.ticks)
		"attendre":
			ok = _attendre(e, h.ticks)
		"changer_arme":
			ok = _changer_arme(e, str(i.get("item", "")), h.ticks)
		"capacite":
			ok = _lancer_capacite(e, int(i.get("index", -1)), i.get("cible", Vector2i(-1, -1)), h.ticks)
	if ok:
		attente.erase(id)
		_fin_de_pas(e.horloge)
	return ok


# ---------------------------------------------------------------- actions

## Déplacement d'une tuile (8 directions). Une chute volontaire (Δ ≤ −3) est autorisée : dégâts.
func _deplacer(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if Grille.distance(e.pos, vers) != 1 or not grille.occupant(vers).is_empty():
		return false
	var volant := Etres.est_volant(e)
	var cout := grille.cout_pas(e.pos, vers, volant)
	var chute := 0
	if cout < 0:
		if not volant and grille.est_chute(e.pos, vers):
			chute = grille.h(e.pos) - grille.h(vers)
			cout = int(regles.r.deplacement.descente)
		else:
			return false
	_quitter_garde(e)
	grille.liberer(e.pos)
	e.orientation = vers - e.pos
	e.pos = vers
	grille.placer(e.id, vers)
	e.compteur = tick + cout
	EventBus.emettre(&"journal", [&"journal.deplacement", {"nom": e.name_key, "cout": cout}])
	if chute > 0:
		var d := grille.degats_chute(chute)
		EventBus.emettre(&"journal", [&"journal.chute", {"nom": e.name_key, "niveaux": chute, "degats": d}])
		_appliquer_degats(e, d, "", {"chute": true})
	return true


func _prendre_garde(e: Dictionary, tick: int) -> bool:
	if e.endurance <= 0:
		return false   # à zéro d'endurance, garde impossible
	e.garde = true
	e.compteur = tick + int(regles.r.actions.garde)
	EventBus.emettre(&"journal", [&"journal.garde", {"nom": e.name_key}])
	return true


func _attendre(e: Dictionary, tick: int) -> bool:
	_quitter_garde(e)
	e.endurance = mini(e.endurance_max, e.endurance + int(regles.r.actions.attendre_endurance))
	e.compteur = tick + int(regles.r.actions.attendre)
	EventBus.emettre(&"journal", [&"journal.attendre", {"nom": e.name_key}])
	return true


func _quitter_garde(e: Dictionary) -> void:
	e.garde = false


## Changer d'arme (4 ticks) : l'objet doit être au râtelier. Un bouclier va en main secondaire
## (main principale à une main) ; une arme à deux mains range le bouclier.
func _changer_arme(e: Dictionary, item_id: String, tick: int) -> bool:
	if not (item_id in e.ratelier):
		return false
	var item: Dictionary = items.get(item_id, {})
	if item.is_empty():
		return false
	if item.type == "bouclier":
		var principale: Dictionary = items.get(e.equipement.get("main_principale", ""), {})
		if int(principale.get("hands", 1)) > 1 or e.equipement.get("main_secondaire", "") == item_id:
			return false
		e.equipement["main_secondaire"] = item_id
	else:
		if e.equipement.get("main_principale", "") == item_id:
			return false
		e.equipement["main_principale"] = item_id
		if int(item.get("hands", 1)) > 1:
			e.equipement.erase("main_secondaire")
	_quitter_garde(e)
	e.compteur = tick + int(regles.r.actions.changer_arme)
	EventBus.emettre(&"journal", [&"journal.changer_arme", {"nom": e.name_key, "objet": item.name_key, "ticks": regles.r.actions.changer_arme}])
	return true


## Attaque à l'arme équipée. Une lourde est télégraphée : engagée maintenant, résolue à l'échéance.
func _attaquer_arme(e: Dictionary, cible: Dictionary, lourde: bool, tick: int) -> bool:
	var arme := Etres.arme(e, items)
	if arme.is_empty() or not cible.vivant:
		return false
	var fonct: Dictionary = fonctionnalites.get(arme.functionality, {})
	if not _cible_atteignable(e, cible, regles.portee_de(fonct), true):
		return false
	_quitter_garde(e)
	e.orientation = Vector2i(signi(cible.pos.x - e.pos.x), signi(cible.pos.y - e.pos.y))
	var ticks := regles.ticks_attaque(fonct, lourde)
	_engager_combat(e, cible)
	if regles.est_telegraphee(ticks) or lourde:
		e.action_en_cours = {"type": "arme", "cible": cible.id, "lourde": lourde, "ticks": ticks, "name_key": arme.name_key}
		e.compteur = horloge_de(e).ticks + ticks
		EventBus.emettre(&"journal", [&"journal.telegraphe", {"nom": e.name_key, "action": arme.name_key, "ticks": ticks}])
		EventBus.emettre(&"action_engaged", [e.id, e.action_en_cours])
		return true
	e.compteur = horloge_de(e).ticks + ticks
	_frapper_arme(e, cible, arme, fonct, false, ticks)
	return true


func _frapper_arme(e: Dictionary, cible: Dictionary, arme: Dictionary, fonct: Dictionary, lourde: bool, ticks: int) -> void:
	var a_zero: bool = e.endurance <= 0
	e.endurance = maxi(0, e.endurance - int(regles.r.endurance.lourde if lourde else regles.r.endurance.attaque))
	var d := regles.degats_arme(e.corps.stats, arme, fonct, des, lourde, a_zero)
	var vecteur := vecteur_arme(arme)
	var wx := _facteur_wuxing(e, cible, vecteur, tick_de(e))
	var res := _resoudre_coup(e, cible, d.bruts * wx.total, fonct.type_degats, lourde, vecteur)
	res.merge(wx)
	var cle := &"journal.attaque_lourde" if lourde else &"journal.attaque"
	EventBus.emettre(&"journal", [cle, {"att": e.name_key, "def": cible.name_key, "zone": res.zone, "degats": res.degats, "ticks": ticks}])
	_appliquer_degats(cible, res.degats, e.id, res)
	_poser_segment(e, vecteur, tick_de(e))


func tick_de(e: Dictionary) -> int:
	return horloge_de(e).ticks


## Le vecteur d'une arme du prototype : son élément, pur ({} si elle n'en porte pas).
func vecteur_arme(arme: Dictionary) -> Dictionary:
	var el: Variant = arme.get("element")
	return {el: 1.0} if el is String and not el.is_empty() else {}


## L'alignement contre lequel un coup se résout : le vecteur de la pièce touchée (multiplicateurs
## défensifs compressés), sinon l'alignement propre de la créature (offensifs), sinon neutre.
func multiplicateur_domination(v_att: Dictionary, cible: Dictionary, zone: String) -> Dictionary:
	if v_att.is_empty():
		return {"mult": 1.0, "contre": {}, "table": "neutre"}
	var piece := Etres.piece_zone(cible, zone, items)
	if piece.has("elements") and piece.elements is Dictionary and not piece.elements.is_empty():
		return {"mult": wuxing.multiplicateur(v_att, piece.elements, "defensif"), "contre": piece.elements, "table": "defensif"}
	if cible.elements is Dictionary and not cible.elements.is_empty():
		return {"mult": wuxing.multiplicateur(v_att, cible.elements, "offensif"), "contre": cible.elements, "table": "offensif"}
	return {"mult": 1.0, "contre": {}, "table": "neutre"}


## Domination × gain intermédiaire × bonus de résolution (Domination et multiplicateurs).
func _facteur_wuxing(e: Dictionary, cible: Dictionary, v_att: Dictionary, tick: int) -> Dictionary:
	var zone: Dictionary = regles.zone_de_coup(grille.h(e.pos), grille.h(cible.pos))
	var dom := multiplicateur_domination(v_att, cible, zone.zone)
	var gain := 1.0
	var chaine := 1.0
	var prev := {}
	if e.has("chaine") and not v_att.is_empty():
		wuxing.decroitre(e.chaine, tick)
		prev = wuxing.prevoir(e.chaine, wuxing.dominante(v_att))
		gain = prev.gain
		chaine = prev.multiplicateur
	return {"dom": dom.mult, "contre": dom.contre, "gain": gain, "chaine": chaine, "prevision": prev, "total": dom.mult * gain * chaine}


## Un coup qui touche pose UN segment (Jauge de chaîne Wu Xing) — s'il résout, la barre retombe.
func _poser_segment(e: Dictionary, v_att: Dictionary, tick: int) -> void:
	if not e.has("chaine") or v_att.is_empty():
		return
	var element := wuxing.dominante(v_att)
	var p := wuxing.poser(e.chaine, element, tick)
	if p.resout:
		EventBus.emettre(&"journal", [&"journal.chaine_resout", {"nom": e.name_key, "mult": "%.2f" % p.multiplicateur}])
	else:
		EventBus.emettre(&"journal", [&"journal.chaine_segment", {"nom": e.name_key, "element": "element." + element,
			"position": p.position, "capacite": e.chaine.capacite, "transition": "%.2f" % p.transition}])


## Un coup contre une cible : zone par dénivelé, garde (frontale / bouclier), armure de zone.
func _resoudre_coup(att: Dictionary, cible: Dictionary, bruts: float, type_degats: String, lourde: bool, element: Variant) -> Dictionary:
	var zone: Dictionary = regles.zone_de_coup(grille.h(att.pos), grille.h(cible.pos))
	var piece := Etres.piece_zone(cible, zone.zone, items)
	var armure := regles.armure_piece(piece, type_degats)
	var direction := Regles.direction_relative(cible.orientation, att.pos - cible.pos)
	var bouclier := Etres.a_bouclier(cible, items)
	var tient: bool = cible.garde and regles.garde_tient(direction, bouclier, lourde)
	var sans_garde := regles.degats_finaux(bruts, zone.mult, armure, false)
	var degats := regles.degats_finaux(bruts, zone.mult, armure, tient)
	if cible.garde:
		if tient:
			var cout := regles.cout_garde_impact(sans_garde, bouclier)
			cible.endurance = maxi(0, cible.endurance - cout)
			EventBus.emettre(&"journal", [&"journal.garde_tient", {"nom": cible.name_key, "avant": sans_garde, "apres": degats}])
			if cible.endurance <= 0:
				cible.garde = false
		elif lourde and not bouclier:
			cible.garde = false   # la lourde brise la garde
	return {"zone": zone.zone, "mult": zone.mult, "armure": armure, "direction": direction,
		"garde": tient, "degats": degats, "bruts": bruts, "type": type_degats, "element": element}


func _appliquer_degats(cible: Dictionary, degats: int, source: String, detail: Dictionary) -> void:
	cible.sante = maxi(0, cible.sante - degats)
	EventBus.emettre(&"damage_dealt", [source, cible.id, degats, detail])
	if cible.sante <= 0 and cible.vivant:
		cible.vivant = false
		grille.liberer(cible.pos)
		EventBus.emettre(&"journal", [&"journal.mort", {"nom": cible.name_key}])
		EventBus.emettre(&"creature_killed", [cible.id, source])


## Résolution d'une action engagée (télégraphée) à son échéance.
func _resoudre_action_engagee(e: Dictionary, a: Dictionary) -> void:
	EventBus.emettre(&"action_resolved", [e.id, a])
	var cible: Dictionary = entites.get(a.get("cible", ""), {})
	match str(a.type):
		"arme":
			var arme := Etres.arme(e, items)
			var fonct: Dictionary = fonctionnalites.get(arme.get("functionality", ""), {})
			if cible.is_empty() or not cible.vivant or not _cible_atteignable(e, cible, regles.portee_de(fonct), true):
				return   # la cible s'est dérobée : le coup passe dans le vide
			_frapper_arme(e, cible, arme, fonct, a.lourde, a.ticks)
		"creature":
			_executer_action_creature(e, actions_creatures[a.action], cible)
		"capacite":
			_executer_capacite(e, a.plan, a.cible_pos)


func _cible_atteignable(e: Dictionary, cible: Dictionary, portee: Vector2i, ldv: bool) -> bool:
	var d := Grille.distance(e.pos, cible.pos)
	if d < portee.x or d > portee.y:
		return false
	return not ldv or grille.ligne_de_vue(e.pos, cible.pos)


# ---------------------------------------------------------------- actions de créatures

func _action_creature_possible(e: Dictionary, action: Dictionary, cible: Dictionary) -> bool:
	if "passive" in action.tags:
		return false
	if action.cible == "ennemi" and cible.is_empty():
		return false
	var p := Vector2i(int(action.portee[0]), int(action.portee[1]))
	if action.cible == "ennemi":
		return _cible_atteignable(e, cible, p, bool(action.ligne_de_vue))
	return true   # anneau/soi : toujours lançable


func _lancer_action_creature(e: Dictionary, action: Dictionary, cible: Dictionary, tick: int) -> void:
	var ticks := int(action.cout_ticks)
	if not cible.is_empty():
		e.orientation = Vector2i(signi(cible.pos.x - e.pos.x), signi(cible.pos.y - e.pos.y))
	_quitter_garde(e)
	e.compteur = tick + ticks
	if regles.est_telegraphee(ticks) or "telegraphe" in action.tags:
		e.action_en_cours = {"type": "creature", "action": action.id, "cible": cible.get("id", ""), "ticks": ticks, "name_key": action.name_key}
		EventBus.emettre(&"journal", [&"journal.telegraphe", {"nom": e.name_key, "action": action.name_key, "ticks": ticks}])
		EventBus.emettre(&"action_engaged", [e.id, e.action_en_cours])
		return
	_executer_action_creature(e, action, cible)


func _executer_action_creature(e: Dictionary, action: Dictionary, cible: Dictionary) -> void:
	var a_zero: bool = e.endurance <= 0
	e.endurance = maxi(0, e.endurance - int(action.cout_endurance))
	var cibles: Array[Dictionary] = _cibles_de_forme(e, action, cible)
	for effet: Dictionary in action.effets:
		match str(effet.type):
			"degats":
				for c in cibles:
					if not c.vivant:
						continue
					var bonus := _bonus_des_conditions(e, c, action)
					var d := regles.degats_action(e.corps.stats, action, des, a_zero, bonus)
					var wx := _facteur_wuxing(e, c, action.elements, tick_de(e))
					var res := _resoudre_coup(e, c, d.bruts * wx.total, str(action.get("type_degats", "contondant")), false, action.elements)
					res.merge(wx)
					EventBus.emettre(&"journal", [&"journal.action_creature", {"att": e.name_key, "action": action.name_key, "def": c.name_key, "zone": res.zone, "degats": res.degats}])
					_appliquer_degats(c, res.degats, e.id, res)
				if not cibles.is_empty():
					_poser_segment(e, action.elements, tick_de(e))
			"deplacement":
				_effet_deplacement(e, effet, cibles, cible)
			"attaque_arme":
				var arme := Etres.arme(e, items)
				if not arme.is_empty() and not cible.is_empty() and cible.vivant:
					var fonct: Dictionary = fonctionnalites.get(arme.functionality, {})
					if _cible_atteignable(e, cible, regles.portee_de(fonct), true):
						_frapper_arme(e, cible, arme, fonct, false, int(action.cout_ticks))
			"fuite":
				e.fuite = true
			_:
				pass   # statut, bonus_premiere_attaque : jalons 8-10 (Statuts, embuscade)


func _cibles_de_forme(e: Dictionary, action: Dictionary, cible: Dictionary) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	match str(action.forme):
		"cible_unique":
			if not cible.is_empty():
				res.append(cible)
		"ligne":
			for p in grille.ligne(e.pos, cible.pos if not cible.is_empty() else e.pos + e.orientation, int(action.taille)):
				var occ := grille.occupant(p)
				if not occ.is_empty() and _cible_valide(e, entites[occ], action.cible):
					res.append(entites[occ])
		"anneau", "soi":
			for p in grille.anneau(e.pos, int(action.taille)):
				var occ := grille.occupant(p)
				if not occ.is_empty() and _cible_valide(e, entites[occ], action.cible):
					res.append(entites[occ])
	return res


func _cible_valide(e: Dictionary, c: Dictionary, type_cible: String) -> bool:
	match type_cible:
		"ennemi": return c.camp != e.camp
		"allie": return c.camp == e.camp and c.id != e.id
		"soi": return c.id == e.id
	return true


## Conditions à bonus (Vocabulaire des modules — six axes, axe 5) : dés supplémentaires.
func _bonus_des_conditions(e: Dictionary, c: Dictionary, action: Dictionary) -> int:
	var bonus := 0
	for cond: Dictionary in action.get("conditions", []):
		var vrai := false
		match str(cond.type):
			"hauteur_relative":
				vrai = (grille.h(e.pos) > grille.h(c.pos)) if cond.get("valeur", "plus_haut") == "plus_haut" else (grille.h(e.pos) < grille.h(c.pos))
			"cible_adjacente_a_allie":
				for autre in vivants():
					if autre.id != e.id and autre.camp == e.camp and Grille.distance(autre.pos, c.pos) == 1:
						vrai = true
			"cible_isolee":
				vrai = true
				for autre in vivants():
					if autre.id != c.id and autre.camp == c.camp and Grille.distance(autre.pos, c.pos) == 1:
						vrai = false
		if vrai:
			bonus += int(cond.get("bonus", {}).get("des", 0))
	return bonus


## Effets de déplacement : projection (la cible recule), au_contact (le lanceur avance).
func _effet_deplacement(e: Dictionary, effet: Dictionary, cibles: Array[Dictionary], cible: Dictionary) -> void:
	match str(effet.get("mode", "")):
		"projection":
			for c in cibles:
				if not c.vivant:
					continue
				var d := Vector2i(signi(c.pos.x - e.pos.x), signi(c.pos.y - e.pos.y))
				if d == Vector2i.ZERO:
					continue
				var n := des.jet(effet.get("distance", "1"))
				for i in n:
					var vers: Vector2i = c.pos + d
					if not grille.dans(vers) or grille.bloque_passage(vers) or not grille.occupant(vers).is_empty():
						break
					var dh := grille.h(vers) - grille.h(c.pos)
					if dh >= int(regles.r.deplacement.falaise_delta):
						break
					grille.liberer(c.pos)
					c.pos = vers
					grille.placer(c.id, vers)
					if -dh >= int(regles.r.deplacement.chute_delta):
						var deg := grille.degats_chute(-dh)
						EventBus.emettre(&"journal", [&"journal.chute", {"nom": c.name_key, "niveaux": -dh, "degats": deg}])
						_appliquer_degats(c, deg, e.id, {"chute": true})
						break
		"au_contact":
			if cible.is_empty():
				return
			var chemin := grille.ligne(e.pos, cible.pos, Grille.distance(e.pos, cible.pos) - 1)
			for p in chemin:
				if grille.cout_pas(e.pos, p, Etres.est_volant(e)) < 0 or not grille.occupant(p).is_empty():
					break
				grille.liberer(e.pos)
				e.pos = p
				grille.placer(e.id, p)


# ---------------------------------------------------------------- capacités (modules assemblés)

## Le plan d'une capacité de `e` : assemblage avec l'arme tenue (pour les noyaux « arme »).
func plan_capacite(e: Dictionary, index: int) -> Dictionary:
	var caps: Array = e.get("capacites", [])
	if index < 0 or index >= caps.size():
		return {}
	var arme := Etres.arme(e, items)
	var fonct: Dictionary = fonctionnalites.get(arme.get("functionality", ""), {})
	var ticks_arme := regles.ticks_attaque(fonct, false) if not fonct.is_empty() else int(regles.r.actions.attaque_base)
	var plan := capacites.assembler(caps[index].modules, ticks_arme, fonct.get("degats_des", "1d4"), vecteur_arme(arme))
	plan["id"] = caps[index].id
	plan["name_key"] = caps[index].get("name_key", "")
	plan["arme"] = arme
	plan["fonct"] = fonct
	return plan


## La cible d'une capacité est-elle valide (portée, ligne de vue) ?
func capacite_visable(e: Dictionary, plan: Dictionary, cible: Vector2i) -> bool:
	if not grille.dans(cible):
		return false
	if plan.geometrie == "soi":
		return true
	var d := Grille.distance(e.pos, cible)
	if d < plan.portee.x or d > plan.portee.y:
		return false
	return not plan.ligne_de_vue or grille.ligne_de_vue(e.pos, cible)


## Évalue les conditions du plan (Modules : un verrou qui paie — si faux, la capacité ne part pas
## et rend 50 % de ses ticks). Applique les bonus des conditions vraies. Retourne la condition fausse ou {}.
func _evaluer_conditions(e: Dictionary, plan: Dictionary, cible_pos: Vector2i) -> Dictionary:
	var occ := grille.occupant(cible_pos)
	var cible: Dictionary = entites.get(occ, {}) if not occ.is_empty() else {}
	for c: Dictionary in plan.conditions:
		var p: Dictionary = c.predicat
		var vrai := false
		match str(p.type):
			"hauteur_relative":
				var dh := grille.h(e.pos) - grille.h(cible_pos)
				vrai = dh > 0 if p.get("signe", ">") == ">" else dh < 0
			"dos_ou_flanc":
				vrai = not cible.is_empty() and Regles.direction_relative(cible.orientation, e.pos - cible.pos) != "front"
			"ligne_de_vue_degagee":
				vrai = grille.ligne_de_vue(e.pos, cible_pos)
			"cible_isolee":
				vrai = not cible.is_empty()
				for autre in vivants():
					if not cible.is_empty() and autre.id != cible.id and autre.camp == cible.camp and Grille.distance(autre.pos, cible.pos) == 1:
						vrai = false
			"cible_adjacente_a_allie":
				for autre in vivants():
					if not cible.is_empty() and autre.id != e.id and autre.camp == e.camp and Grille.distance(autre.pos, cible.pos) == 1:
						vrai = true
			"pv_cible_sous":
				vrai = not cible.is_empty() and float(cible.sante) / float(cible.sante_max) * 100.0 < float(p.pct)
			"pv_porteur_sous":
				vrai = float(e.sante) / float(e.sante_max) * 100.0 < float(p.pct)
			"porteur_en_posture":
				vrai = e.garde
			"jauge_chaine_pleine":
				vrai = e.has("chaine") and e.chaine.segments.size() >= int(e.chaine.capacite) - 1
			"segment_chaine_present":
				vrai = e.has("chaine") and not e.chaine.segments.is_empty()
			_:
				vrai = false
		if not vrai:
			return c
		Capacites.appliquer_bonus(plan, c.bonus)
	return {}


## Lance la capacité n° `index` sur la tuile `cible` : coûts, conditions, télégraphe ou exécution.
func _lancer_capacite(e: Dictionary, index: int, cible: Variant, tick: int) -> bool:
	var plan := plan_capacite(e, index)
	if plan.is_empty() or not plan.erreurs.is_empty():
		return false
	var cible_pos: Vector2i = e.pos if plan.geometrie == "soi" else cible
	if not (cible is Vector2i) and plan.geometrie != "soi":
		return false
	if not capacite_visable(e, plan, cible_pos):
		return false
	_quitter_garde(e)
	if cible_pos != e.pos:
		e.orientation = Vector2i(signi(cible_pos.x - e.pos.x), signi(cible_pos.y - e.pos.y))
	var fausse := _evaluer_conditions(e, plan, cible_pos)
	if not fausse.is_empty():
		# Le verrou est fermé : la capacité ne part pas et rend 50 % de ses ticks.
		e.compteur = tick + maxi(1, roundi(float(plan.ticks) * (1.0 - float(fausse.ticks_rendus))))
		EventBus.emettre(&"journal", [&"journal.condition_fausse", {"nom": e.name_key, "capacite": plan.name_key, "condition": fausse.name_key}])
		return true
	_payer(e, plan)
	e.compteur = tick + int(plan.ticks)
	if regles.est_telegraphee(int(plan.ticks)):
		e.action_en_cours = {"type": "capacite", "plan": plan, "cible_pos": cible_pos, "cible": grille.occupant(cible_pos), "ticks": plan.ticks, "name_key": plan.name_key}
		EventBus.emettre(&"journal", [&"journal.telegraphe", {"nom": e.name_key, "action": plan.name_key, "ticks": plan.ticks}])
		EventBus.emettre(&"action_engaged", [e.id, e.action_en_cours])
		return true
	_executer_capacite(e, plan, cible_pos)
	return true


## Paie la monnaie du noyau. Mana insuffisant = surchauffe : le déficit est infligé en PV × 2 (Mana).
func _payer(e: Dictionary, plan: Dictionary) -> void:
	match str(plan.monnaie):
		"mana":
			var deficit: int = maxi(0, int(plan.ressource) - int(e.mana))
			e.mana = maxi(0, int(e.mana) - int(plan.ressource))
			if deficit > 0:
				var degats := deficit * int(regles.r.mana.surchauffe_mult)
				EventBus.emettre(&"journal", [&"journal.surchauffe", {"nom": e.name_key, "deficit": deficit, "degats": degats}])
				_appliquer_degats(e, degats, "", {"surchauffe": true})
		"endurance":
			e.endurance = maxi(0, int(e.endurance) - int(plan.ressource))


## Exécute une capacité : forme → cibles (friendly fire des zones), puis les effets du noyau.
func _executer_capacite(e: Dictionary, plan: Dictionary, cible_pos: Vector2i) -> void:
	var tick := tick_de(e)
	var tuiles := Capacites.tuiles_de_forme(grille, plan.geometrie, e.pos, cible_pos, int(plan.taille))
	var touchees: Array[Dictionary] = []
	for t in tuiles:
		var occ := grille.occupant(t)
		if occ.is_empty():
			continue
		var c: Dictionary = entites[occ]
		if not c.vivant:
			continue
		# Point : une cible unique ; les zones touchent tout ce qu'elles couvrent, alliés compris.
		if plan.geometrie == "point" and c.id == e.id:
			continue
		if plan.ligne_de_vue and plan.geometrie != "point" and plan.geometrie != "soi" and not grille.ligne_de_vue(e.pos, t):
			continue
		touchees.append(c)
	var elements: Dictionary = plan.elements
	var a_touche := false
	var non_offensif := true
	var prev := {}
	if e.has("chaine") and not elements.is_empty() and not plan.parametres.get("sans_segment", false):
		wuxing.decroitre(e.chaine, tick)
		prev = wuxing.prevoir(e.chaine, wuxing.dominante(elements))
	for effet: String in plan.effets:
		match effet:
			"degats":
				non_offensif = false
				for c in touchees:
					var d := _degats_capacite(e, c, plan, prev)
					a_touche = true
					EventBus.emettre(&"journal", [&"journal.capacite", {"att": e.name_key, "capacite": plan.name_key, "def": c.name_key, "zone": d.zone, "degats": d.degats}])
					_appliquer_degats(c, d.degats, e.id, d)
					if plan.drapeaux.has("vampirique"):
						e.sante = mini(e.sante_max, e.sante + roundi(float(d.degats) * float(plan.drapeaux.vampirique)))
			"soin":
				for c in touchees:
					if c.camp != e.camp:
						continue
					var soin := des.jet(plan.des, int(plan.des_bonus))
					if not prev.is_empty() and prev.resout:
						soin = roundi(float(soin) * float(prev.multiplicateur) * float(wuxing.w.chaine.resolveur_non_offensif))
					var avant: int = c.sante
					c.sante = mini(c.sante_max, c.sante + soin)
					a_touche = true
					EventBus.emettre(&"journal", [&"journal.soin", {"att": e.name_key, "capacite": plan.name_key, "def": c.name_key, "soin": c.sante - avant}])
			"deplacement":
				var dp: Dictionary = plan.parametres.get("deplacement", {})
				if not dp.is_empty():
					var occ := grille.occupant(cible_pos)
					_effet_deplacement(e, dp, touchees, entites.get(occ, {}))
					a_touche = a_touche or not touchees.is_empty()
			_:
				pass   # statut, terrain, invocation, tempo, saisie : jalons suivants
	if plan.drapeaux.has("projection"):
		_effet_deplacement(e, {"mode": "projection", "distance": str(plan.drapeaux.projection)}, touchees, {})
	if a_touche and not elements.is_empty() and not plan.parametres.get("sans_segment", false):
		_poser_segment(e, elements, tick)
		var extra := int(plan.drapeaux.get("segments", 0))
		for i in extra:
			_poser_segment(e, elements, tick)
	EventBus.emettre(&"action_resolved", [e.id, {"type": "capacite", "plan": plan}])


## Dégâts d'un noyau sur une cible : noyau « arme » = formule de l'arme ; noyau magique = jet × niveau.
## La réduction d'armure ne s'applique qu'à 50 % aux dégâts magiques (Armure par zone).
func _degats_capacite(e: Dictionary, c: Dictionary, plan: Dictionary, prev: Dictionary) -> Dictionary:
	var a_zero: bool = e.endurance <= 0 and plan.monnaie == "endurance"
	var arme_noyau: bool = plan.noyau.get("power_base") == "arme"
	var d: Dictionary
	var type_degats := "magique"
	if arme_noyau and not plan.arme.is_empty():
		d = regles.degats_arme(e.corps.stats, plan.arme, plan.fonct, des, false, a_zero, int(plan.des_bonus))
		type_degats = str(plan.fonct.type_degats)
	else:
		var jet := des.jet(plan.des, int(plan.des_bonus))
		d = {"jet": jet, "bruts": float(jet)}
	var bruts: float = d.bruts * float(plan.mult)
	var zone: Dictionary = regles.zone_de_coup(grille.h(e.pos), grille.h(c.pos))
	var dom := multiplicateur_domination(plan.elements, c, zone.zone)
	var gain: float = float(prev.get("gain", 1.0)) if not prev.is_empty() else 1.0
	var chaine: float = float(prev.get("multiplicateur", 1.0)) if not prev.is_empty() else 1.0
	bruts *= float(dom.mult) * float(gain) * float(chaine)
	var piece := Etres.piece_zone(c, zone.zone, items)
	var armure := 0.0
	if not plan.drapeaux.get("ignore_armure", false):
		armure = regles.armure_piece(piece, type_degats if type_degats != "magique" else "contondant")
		if type_degats == "magique":
			armure *= float(regles.r.armure.magie_facteur)
		armure = maxf(0.0, armure - float(plan.parametres.get("ignore_armure_points", 0)))
	var direction := Regles.direction_relative(c.orientation, e.pos - c.pos)
	var bouclier := Etres.a_bouclier(c, items)
	var tient: bool = c.garde and regles.garde_tient(direction, bouclier, false)
	var sans_garde := regles.degats_finaux(bruts, zone.mult, armure, false)
	var degats := regles.degats_finaux(bruts, zone.mult, armure, tient)
	if tient:
		c.endurance = maxi(0, c.endurance - regles.cout_garde_impact(sans_garde, bouclier))
		if c.endurance <= 0:
			c.garde = false
	return {"zone": zone.zone, "mult": zone.mult, "armure": armure, "direction": direction, "garde": tient,
		"degats": degats, "bruts": bruts, "type": type_degats, "element": plan.elements, "dom": dom.mult,
		"contre": dom.contre, "gain": gain, "chaine": chaine, "jet": d.jet}


# ---------------------------------------------------------------- engagement (Temporalités parallèles)

## Place `a` et `b` dans la même horloge de combat (créée au besoin), compteurs rebasés.
func _engager_combat(a: Dictionary, b: Dictionary) -> void:
	if a.camp == b.camp:
		return
	var nom := ""
	if en_combat(a):
		nom = a.horloge
	elif en_combat(b):
		nom = b.horloge
	else:
		_n_combats += 1
		nom = "combat_%d" % _n_combats
		var h := TickManager.creer(nom, Horloge.Mode.ACTION)
		combats[nom] = {"horloge": h, "participants": []}
		EventBus.emettre(&"combat_started", [nom, [a.id, b.id]])
		EventBus.emettre(&"journal", [&"journal.engagement", {"nom": (a.name_key if a.controle != "joueur" else b.name_key)}])
	for e in [a, b]:
		if e.horloge != nom:
			_rejoindre(e, nom)


func _rejoindre(e: Dictionary, nom: String) -> void:
	var de := horloge_de(e)
	var vers: Horloge = combats[nom].horloge
	e.compteur = vers.ticks + maxi(0, e.compteur - de.ticks)
	e.tick_endurance = vers.ticks - maxi(0, de.ticks - e.tick_endurance)
	if en_combat(e):
		combats[e.horloge].participants.erase(e.id)
	e.horloge = nom
	combats[nom].participants.append(e.id)


func _quitter_combat(e: Dictionary) -> void:
	var de := horloge_de(e)
	combats[e.horloge].participants.erase(e.id)
	e.compteur = horloge_monde.ticks + maxi(0, e.compteur - de.ticks)
	e.tick_endurance = horloge_monde.ticks
	e.horloge = "monde"
	e.action_en_cours = {}


## Un combat se relâche quand plus aucun hostile n'y menace un participant contrôlé :
## tous morts, ou à plus de 12 tuiles, ou hors de vue depuis 30 ticks (Décision — Fuite).
func _verifier_desengagements() -> void:
	for nom in combats.keys():
		var c: Dictionary = combats[nom]
		var h: Horloge = c.horloge
		var menace := false
		for id in c.participants:
			var e: Dictionary = entites[id]
			if not e.vivant or e.camp == "joueur":
				continue
			for id2 in c.participants:
				var j: Dictionary = entites[id2]
				if not j.vivant or j.camp != "joueur":
					continue
				var proche := Grille.distance(e.pos, j.pos) <= int(regles.r.engagement.sortie_distance)
				var vue := grille.ligne_de_vue(e.pos, j.pos)
				if vue:
					e.tick_derniere_vue = h.ticks
				var recemment_vu: bool = e.tick_derniere_vue >= 0 and h.ticks - int(e.tick_derniere_vue) < int(regles.r.engagement.sortie_ticks_sans_vue)
				if proche and (vue or recemment_vu):
					menace = true
		if not menace:
			for id in c.participants.duplicate():
				_quitter_combat(entites[id])
			TickManager.retirer(nom)
			combats.erase(nom)
			EventBus.emettre(&"combat_ended", [nom])
			EventBus.emettre(&"journal", [&"journal.desengagement", {}])


# ---------------------------------------------------------------- IA utility (IA des créatures)

func _decider_ia(e: Dictionary, tick: int) -> void:
	var profil: Dictionary = profils_ia.get(e.ai_profile, {})
	var cible := _chercher_cible(e, tick)
	var candidates := _actions_candidates(e, cible, profil, tick)
	var meilleure := ""
	var meilleur_score := -1.0
	for nom in candidates.keys():
		var score := 0.0
		for consideration in profil.considerations.get(nom, {}).keys():
			score += float(candidates[nom].get(consideration, 0.0)) * float(profil.considerations[nom][consideration])
		if score > meilleur_score:
			meilleur_score = score
			meilleure = nom
	match meilleure:
		"attaquer":
			_ia_attaquer(e, cible, tick)
		"poursuivre":
			_ia_pas_vers(e, cible.pos, tick, cible.id)
		"fuir":
			_ia_fuir(e, cible, tick)
		"retour":
			e.cible = ""
			e.fuite = false
			if e.pos == e.ancre:
				_attendre(e, tick)
			else:
				_ia_pas_vers(e, e.ancre, tick, "")
		_:
			_attendre(e, tick)


## Détection : un ennemi à portée de Perception et en ligne de vue devient la cible ;
## la perte d'intérêt suit les seuils de Décision — Fuite et désengagement.
func _chercher_cible(e: Dictionary, tick: int) -> Dictionary:
	var portee := int(float(e.corps.stats.perception) * float(regles.r.engagement.detection_par_perception))
	if not e.cible.is_empty():
		var c: Dictionary = entites.get(e.cible, {})
		if c.is_empty() or not c.vivant:
			e.cible = ""
		else:
			if grille.ligne_de_vue(e.pos, c.pos):
				e.tick_derniere_vue = tick
				e.pos_connue = c.pos
			elif tick - int(e.tick_derniere_vue) > int(regles.r.engagement.ia_ticks_sans_vue):
				e.cible = ""
			if Grille.distance(e.pos, e.ancre) > int(regles.r.engagement.ia_distance_ancre):
				e.cible = ""
	if e.cible.is_empty():
		var meilleure := {}
		var dmin := 1 << 30
		for autre in vivants():
			if autre.camp == e.camp:
				continue
			var d := Grille.distance(e.pos, autre.pos)
			if d <= portee and d < dmin and grille.ligne_de_vue(e.pos, autre.pos):
				dmin = d
				meilleure = autre
		if not meilleure.is_empty():
			e.cible = meilleure.id
			e.tick_derniere_vue = tick
			e.pos_connue = meilleure.pos
			_engager_combat(e, meilleure)
	return entites.get(e.cible, {})


## Considérations normalisées (0-1) par action candidate ; une action infaisable est absente.
func _actions_candidates(e: Dictionary, cible: Dictionary, profil: Dictionary, tick: int) -> Dictionary:
	var c := {}
	var a_cible := not cible.is_empty()
	var sante_basse := float(e.sante) / float(e.sante_max) < float(profil.get("seuil_fuite_sante", 0.25))
	if a_cible and not _meilleure_attaque(e, cible).is_empty():
		c["attaquer"] = {"cible_a_portee": 1.0, "agressivite": 1.0, "acculee": 1.0 if Grille.distance(e.pos, cible.pos) == 1 else 0.0}
	if a_cible:
		c["poursuivre"] = {"cible_visible": 1.0 if grille.ligne_de_vue(e.pos, cible.pos) else 0.5,
			"distance_cible": clampf(1.0 - float(Grille.distance(e.pos, cible.pos)) / 20.0, 0.0, 1.0)}
		c["fuir"] = {"sante_basse": 1.0 if (sante_basse or e.fuite) else 0.0,
			"joueur_proche": 1.0 if Grille.distance(e.pos, cible.pos) <= 6 else 0.0}
	if e.pos != e.ancre:
		c["retour"] = {"loin_de_l_ancre": 1.0 if Grille.distance(e.pos, e.ancre) > int(regles.r.engagement.ia_distance_ancre) else 0.0,
			"cible_perdue": 0.0 if a_cible else 1.0}
	c["attendre"] = {"endurance_basse": 1.0 if e.endurance < 20 else 0.0, "calme": 0.0 if a_cible else 1.0}
	return c


## L'attaque faisable la plus forte (dégâts moyens) : action de créature ou arme.
func _meilleure_attaque(e: Dictionary, cible: Dictionary) -> Dictionary:
	var meilleure := {}
	var moy := -1.0
	for aid: String in e.actions:
		var a: Dictionary = actions_creatures.get(aid, {})
		if a.is_empty() or not _action_creature_possible(e, a, cible):
			continue
		var f := Des.fourchette(a.get("degats_des"))
		var m := float(f.x + f.y) * 0.5
		if m > moy:
			moy = m
			meilleure = {"type": "creature", "action": a}
	var arme := Etres.arme(e, items)
	if not arme.is_empty():
		var fonct: Dictionary = fonctionnalites.get(arme.functionality, {})
		if _cible_atteignable(e, cible, regles.portee_de(fonct), true):
			var f := Des.fourchette(fonct.degats_des)
			var m := float(f.x + f.y) * 0.5 * float(arme.durete_base) / float(regles.r.degats.durete_reference)
			if m > moy:
				meilleure = {"type": "arme", "arme": arme, "fonct": fonct}
	return meilleure


func _ia_attaquer(e: Dictionary, cible: Dictionary, tick: int) -> void:
	var att := _meilleure_attaque(e, cible)
	if att.is_empty():
		_attendre(e, tick)
		return
	_engager_combat(e, cible)
	if att.type == "creature":
		_lancer_action_creature(e, att.action, cible, tick)
	else:
		# Un humanoïde armé utilise le système standard : garde si l'endurance manque, sinon frappe.
		_attaquer_arme(e, cible, false, tick)


func _ia_pas_vers(e: Dictionary, but: Vector2i, tick: int, ignorer: String) -> void:
	var pas := grille.chemin(e.pos, but, Etres.est_volant(e), ignorer)
	if pas.is_empty() or pas[0] == but and not grille.occupant(but).is_empty():
		_attendre(e, tick)
		return
	if not _deplacer(e, pas[0], tick):
		_attendre(e, tick)


func _ia_fuir(e: Dictionary, cible: Dictionary, tick: int) -> void:
	var meilleur: Vector2i = e.pos
	var dmax := Grille.distance(e.pos, cible.pos)
	for d in Grille.DIRS:
		var v: Vector2i = e.pos + d
		if grille.cout_pas(e.pos, v, Etres.est_volant(e)) < 0 or not grille.occupant(v).is_empty():
			continue
		var dist := Grille.distance(v, cible.pos)
		if dist > dmax:
			dmax = dist
			meilleur = v
	if meilleur == e.pos or not _deplacer(e, meilleur, tick):
		_attendre(e, tick)
