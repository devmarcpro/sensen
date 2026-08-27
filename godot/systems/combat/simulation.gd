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
var donjon: Dictionary = {}           # {theme, graine, id, etage, etages, salles} quand la grille est un étage de donjon
var entites: Dictionary = {}          # id → être (Etres.instancier)
var ordre: Array[String] = []         # ordre stable des ids (départage des égalités de compteur)
var items: Dictionary
var fonctionnalites: Dictionary
var actions_creatures: Dictionary
var profils_ia: Dictionary
var statuts_defs: Dictionary
var affixes_defs: Dictionary
var loot: Loot
var objets: Dictionary = {}          # uid → instance générée (le catalogue reste dans `items`, fusionné)
var contenants: Dictionary = {}      # index de tuile → [uids] (coffres, butin au sol)
var dernier_combat: Dictionary = {}   # récapitulatif du dernier combat terminé (écran de fin)
var glyphes: Array[Dictionary] = []   # couche d'overlay runtime : {pos, plan, source, fin} — jamais sauvegardée
var differes: Array[Dictionary] = []  # charges différées : {tick, source, plan, pos}
var obstacles: Array[Dictionary] = [] # invocations temporaires : {pos, fin}
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
	capacites.par_niveau = float(regles.r.progression.skill_factor_par_niveau)
	capacites.plancher = float(regles.r.progression.ticks_plancher_module)
	items = GameData.catalogues.get("items", {}).duplicate()   # catalogue + instances de loot (uid)
	affixes_defs = GameData.catalogues.get("affixes", {})
	fonctionnalites = GameData.catalogues.get("functionalities", {})
	actions_creatures = GameData.catalogues.get("creature_actions", {})
	profils_ia = GameData.catalogues.get("ai_profiles", {})
	statuts_defs = GameData.catalogues.get("status_effects", {})
	loot = Loot.new(GameData.config("loot_rules"), affixes_defs, GameData.catalogues.get("items", {}), GameData.config("wuxing").elements)
	loot.modules = GameData.catalogues.get("modules", {})


# ---------------------------------------------------------------- mise en place

## Charge une arène de data/prototype_arenas et instancie ses êtres.
func charger_arene(id: String) -> void:
	arene_id = id
	donjon = {}
	var arene := GameData.entree("prototype_arenas", id)
	grille = Grille.depuis_arene(arene, GameData.config("tile_contents"),
		regles.r.deplacement, int(regles.r.vision.hauteur_oeil))
	_reinitialiser()
	var j: Dictionary = arene.spawns.player
	ajouter(j.creature, Vector2i(int(j.pos[0]), int(j.pos[1])), "joueur")
	for s: Dictionary in arene.spawns.enemies:
		ajouter(s.creature, Vector2i(int(s.pos[0]), int(s.pos[1])), "ia")


## Génère et charge l'étage `etage` d'un donjon (Génération de donjon). `joueur` : la fiche du
## joueur au premier étage, ou son état courant pour le faire descendre avec ses PV et son sac.
func charger_donjon(theme_id: String, graine: int, id_donjon: int, etage: int, joueur: Dictionary = {}) -> void:
	var theme := GameData.entree("dungeon_themes", theme_id)
	var etages: int = donjon.get("etages", 0)
	if etages == 0:
		var r := RandomNumberGenerator.new()
		r.seed = hash([graine, id_donjon])
		etages = r.randi_range(int(theme.etages[0]), int(theme.etages[1]))
	var gen := Donjon.new(GameData.catalogues.get("dungeon_rooms", {}), GameData.catalogues.get("dungeon_connectors", {}), theme)
	var r2 := RandomNumberGenerator.new()
	r2.seed = hash([graine, id_donjon, etage, "salles"])
	var nb := r2.randi_range(int(theme.salles_par_etage[0]), int(theme.salles_par_etage[1]))
	var e := gen.generer_etage(graine, id_donjon, etage, nb, etage == etages)
	arene_id = "donjon"
	donjon = {"theme": theme_id, "graine": graine, "id": id_donjon, "etage": etage, "etages": etages,
		"salles": gen._nb_salles(e), "escalier": e.escalier, "boss": e.boss}
	grille = Grille.depuis_etage(e, GameData.config("tile_contents"), regles.r.deplacement, int(regles.r.vision.hauteur_oeil))
	_reinitialiser()
	if joueur.is_empty():
		ajouter(theme.get("joueur", "aventurier"), e.entree, "joueur")
	else:
		_reprendre(joueur, e.entree)
	for s: Dictionary in e.spawns:
		if grille.occupant(s.pos).is_empty():
			ajouter(s.creature, s.pos, "ia")
	for c: Dictionary in e.coffres:
		var uids: Array = []
		for base in c.bases:
			var o := generer_objet(str(base), etage, {"donjon": theme_id, "etage": etage})
			if not o.is_empty():
				uids.append(o.uid)
		_poser_contenant(c.pos, uids, "coffre")


func _reinitialiser() -> void:
	entites.clear()
	ordre.clear()
	combats.clear()
	attente.clear()
	glyphes.clear()
	contenants.clear()
	differe_clear()
	for nom in TickManager.horloges.keys():
		TickManager.retirer(nom)
	horloge_monde = TickManager.creer("monde", Horloge.Mode.TEMPS_REEL, float(regles.r.ticks_par_seconde_exploration))
	horloge_monde.avancee.connect(_sur_avancee_monde)


## Un être qui change d'étage garde son état (PV, mana, sac, XP, compétences) — instance ≠ définition.
func _reprendre(e: Dictionary, pos: Vector2i) -> void:
	_n_entites += 1
	e.pos = pos
	e.ancre = pos
	e.compteur = 0
	e.horloge = "monde"
	e.tick_endurance = 0
	e.action_en_cours = {}
	e.statuts = []
	e.declencheurs_armes = []
	e.cible = ""
	e.contact = false
	entites[e.id] = e
	ordre.append(e.id)
	grille.placer(e.id, pos)


## Descendre : l'être doit être sur la cage d'escalier de l'étage (Donjons : escalier = lien).
func _descendre(e: Dictionary) -> bool:
	if donjon.is_empty() or donjon.escalier == null or e.pos != donjon.escalier:
		return false
	if int(donjon.etage) >= int(donjon.etages):
		return false
	var prochain: int = int(donjon.etage) + 1
	EventBus.emettre(&"journal", [&"journal.descente", {"etage": prochain}])
	charger_donjon(donjon.theme, int(donjon.graine), int(donjon.id), prochain, e)
	return true


func ajouter(def_id: String, pos: Vector2i, controle: String) -> Dictionary:
	_n_entites += 1
	var id := "%s_%d" % [def_id, _n_entites]
	var def := GameData.entree("creatures", def_id)
	var e := Etres.instancier(id, def, pos, controle, regles, items)
	# Variante rare (Monstres rares) : tirage à la résolution du spawn, stats ×2.5, teinte or, épithète, drop garanti.
	if controle == "ia":
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([graine, "rare", _n_entites, def_id])
		var chance := float(def.get("rare_chance", regles.r.get("monstres_rares", {}).get("chance_defaut", 0.02)))
		if rng.randf() < chance:
			_rendre_rare(e, rng)
	if e.chain_gauge:
		e.chaine = wuxing.jauge_neuve()
	Etres.recalculer(e, items, affixes_defs, regles)
	entites[id] = e
	ordre.append(id)
	grille.placer(id, pos)
	return e


## Génère un objet de loot et l'enregistre (son uid devient une clé de `items`).
func generer_objet(base_id: String, profondeur: int, provenance: Dictionary = {}, rarete: String = "", nb_affixes: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "loot", objets.size(), base_id, profondeur])
	var inst := loot.generer(base_id, profondeur, rng, provenance, rarete, nb_affixes)
	if inst.is_empty():
		return {}
	objets[inst.uid] = inst
	items[inst.uid] = inst
	return inst


## Donne un objet à un être (dans son sac).
func donner(e: Dictionary, uid: String) -> void:
	if items.has(uid) and not (uid in e.sac):
		e.sac.append(uid)
		EventBus.emettre(&"journal", [&"journal.loot", {"nom": e.name_key, "objet": nom_objet(uid)}])


## Le nom affichable d'un objet : {"base": name_key, "affixe": id ou "", "params": {}} — le client formate.
func nom_objet(uid: String) -> Dictionary:
	var it: Dictionary = items.get(uid, {})
	var nom: Dictionary = it.get("nom", {})
	return {"base": it.get("name_key", uid), "affixe": nom.get("affixe", ""), "params": nom.get("params", {}), "rarete": it.get("rarete", "commun")}


## Équiper un objet du sac : le slot de l'objet (anneau : premier libre des deux) ; l'ancien va au sac.
func _equiper(e: Dictionary, uid: String, tick: int) -> bool:
	if not (uid in e.sac) or not items.has(uid):
		return false
	var it: Dictionary = items[uid]
	var slot := str(it.get("equip_slot", ""))
	if slot.is_empty():
		return false
	if slot == "anneau":
		slot = "anneau_1" if not e.equipement.has("anneau_1") else ("anneau_2" if not e.equipement.has("anneau_2") else "anneau_1")
	if slot == "main_secondaire":
		var principale: Dictionary = items.get(e.equipement.get("main_principale", ""), {})
		if int(principale.get("hands", 1)) > 1:
			return false
	e.sac.erase(uid)
	if e.equipement.has(slot):
		e.sac.append(e.equipement[slot])
	e.equipement[slot] = uid
	if slot == "main_principale" and int(it.get("hands", 1)) > 1 and e.equipement.has("main_secondaire"):
		e.sac.append(e.equipement.main_secondaire)
		e.equipement.erase("main_secondaire")
	if not (uid in e.ratelier) and it.get("type", "") in ["arme", "bouclier"]:
		e.ratelier.append(uid)
	Etres.recalculer(e, items, affixes_defs, regles)
	_quitter_garde(e)
	e.compteur = tick + int(regles.r.actions.objet if it.get("type", "") != "arme" else regles.r.actions.changer_arme)
	EventBus.emettre(&"journal", [&"journal.equipe", {"nom": e.name_key, "objet": nom_objet(uid)}])
	return true


func _rendre_rare(e: Dictionary, rng: RandomNumberGenerator) -> void:
	var mr: Dictionary = GameData.config("loot_rules").monstres_rares
	e.rare = true
	for k in e.corps.stats.keys():
		e.corps.stats[k] = roundi(float(e.corps.stats[k]) * float(mr.mult_stats))
	e.teinte = mr.teinte.duplicate()
	var pool: Array = GameData.config("rare_epithets").get("or", [])
	e.epithete = str(pool[rng.randi_range(0, pool.size() - 1)]) if not pool.is_empty() else ""
	Etres.recalculer(e, items, affixes_defs, regles)
	e.sante = e.sante_max
	EventBus.emettre(&"journal", [&"journal.rare", {"nom": e.name_key, "epithete": e.epithete}])


## Pose un contenant (coffre, butin) sur une tuile ; s'il y en a déjà un, le contenu s'ajoute.
func _poser_contenant(pos: Vector2i, uids: Array, type: String) -> void:
	if uids.is_empty():
		return
	var idx := grille.idx(pos)
	if contenants.has(idx):
		contenants[idx].append_array(uids)
	else:
		contenants[idx] = uids.duplicate()
		grille.poser_contenu(pos, type)
	EventBus.emettre(&"tile_changed", [pos])


## Ramasser : tout ce qui est sur sa tuile va au sac (utiliser un objet : 5 ticks).
func _ramasser(e: Dictionary, tick: int) -> bool:
	var idx := grille.idx(e.pos)
	if not contenants.has(idx):
		return false
	for uid in contenants[idx]:
		donner(e, str(uid))
	contenants.erase(idx)
	grille.contenu[idx] = 0
	EventBus.emettre(&"tile_changed", [e.pos])
	e.compteur = tick + int(regles.r.actions.objet)
	return true


## Sertir une gemme du sac dans un emplacement libre d'un objet porté ou du sac (5 ticks).
func _sertir(e: Dictionary, objet: String, gemme: String, tick: int) -> bool:
	if not (gemme in e.sac) or not items.has(objet) or items.get(gemme, {}).get("type", "") != "gemme":
		return false
	var porte: bool = objet in e.sac or objet in e.equipement.values()
	var it: Dictionary = items[objet]
	if not porte or not it.has("sertissures") or it.sertissures.contenu.size() >= int(it.sertissures.nombre):
		return false
	e.sac.erase(gemme)
	it.sertissures.contenu.append(gemme)
	Etres.recalculer(e, items, affixes_defs, regles)
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.serti", {"nom": e.name_key, "gemme": nom_objet(gemme), "objet": nom_objet(objet)}])
	return true


## Lire un livre (Lecture des livres) : jet universel, modules appris, échec à effet, livre consommé.
func _lire(e: Dictionary, objet: String, tick: int) -> bool:
	if not (objet in e.sac) or not items.get(objet, {}).get("type", "") in ["grimoire", "manuel"]:
		return false
	var livre: Dictionary = items[objet]
	var lv: Dictionary = GameData.config("loot_rules").livres
	var n_lecture := int(e.competences_eff.get("lecture", 0))
	var jet := des.jet("1d20")
	var total := jet + n_lecture / 2 + int(e.stats_eff.perception) / 4
	var dd := int(lv.dd_base) + int(livre.difficulte) / 2
	var marge := total - dd
	e.sac.erase(objet)   # consommé dans tous les cas
	var succes := marge >= 0 and jet != 1
	var appris: Array = []
	if succes:
		var n: int = livre.modules.size()
		if marge < 10:
			n = maxi(1, int(floorf(float(livre.modules.size()) * minf(1.0, float(n_lecture) / float(livre.difficulte)))))
		for k in n:
			var m: String = str(livre.modules[k])
			if not (m in e.modules_connus):
				e.modules_connus.append(m)
			appris.append(m)
		e.xp.competence["lecture"] = int(e.xp.competence.get("lecture", 0)) + int(livre.difficulte) * int(lv.xp_succes)
		EventBus.emettre(&"journal", [&"journal.lecture_reussie", {"nom": e.name_key, "n": appris.size(), "livre": nom_objet(objet)}])
	else:
		e.xp.competence["lecture"] = int(e.xp.competence.get("lecture", 0)) + int(livre.difficulte) * int(lv.xp_echec)
		var grave := marge <= -10 or jet == 1
		_effet_echec_lecture(e, grave, tick)
		EventBus.emettre(&"journal", [&"journal.lecture_echouee", {"nom": e.name_key, "livre": nom_objet(objet), "grave": grave}])
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"book_read", [e.id, objet, succes])
	return true


func _effet_echec_lecture(e: Dictionary, grave: bool, tick: int) -> void:
	var table: Array = GameData.config("reading_failures").get("grave" if grave else "mineur", [])
	if table.is_empty():
		return
	var ef: Dictionary = table[des.entier(0, table.size() - 1)]
	if ef.has("statut"):
		appliquer_statut(e, str(ef.statut), int(ef.get("duree_ticks", 20)), "")
	if ef.has("mana"):
		e.mana = maxi(0, int(e.mana) + int(ef.mana))
	if ef.get("teleportation", false):
		for essai in 50:
			var p := Vector2i(des.entier(0, grille.largeur - 1), des.entier(0, grille.hauteur_grille - 1))
			if not grille.bloque_passage(p) and grille.occupant(p).is_empty():
				grille.liberer(e.pos)
				e.pos = p
				grille.placer(e.id, p)
				break
	if ef.has("invocation"):
		for d in Grille.DIRS:
			var p: Vector2i = e.pos + d
			if grille.dans(p) and not grille.bloque_passage(p) and grille.occupant(p).is_empty():
				ajouter(str(ef.invocation), p, "ia")
				break


## À la mort : un drop (chance du tout-venant ; garanti et renforcé pour une variante rare).
func _drop(cible: Dictionary, source: String) -> void:
	var lr: Dictionary = GameData.config("loot_rules")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "drop", cible.id])
	var profondeur: int = int(donjon.get("etage", 0))
	var uids: Array = []
	if cible.get("rare", false):
		var base := str(loot._base_pour(rng))
		var o := generer_objet(base, profondeur, {"monstre_rare": cible.name_key}, str(lr.drops.rare_rarete), int(lr.drops.rare_affixes))
		if not o.is_empty():
			uids.append(o.uid)
	elif cible.controle == "ia" and rng.randf() < float(lr.drops.chance_tout_venant):
		var o := generer_objet(str(loot._base_pour(rng)), profondeur, {"creature": cible.name_key})
		if not o.is_empty():
			uids.append(o.uid)
	# Ce que le mort portait tombe aussi (l'équipement est une donnée d'instance).
	for slot in cible.equipement.keys():
		var uid: String = str(cible.equipement[slot])
		if objets.has(uid):
			uids.append(uid)
	for uid in cible.sac:
		uids.append(str(uid))
	_poser_contenant(cible.pos, uids, "butin")


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
	# Phase 2 (Boucle de tick) : les statuts de tous les êtres de cette horloge.
	var h: Horloge = horloge_monde if nom == "monde" else combats.get(nom, {}).get("horloge", horloge_monde)
	for e in vivants():
		if e.horloge == nom:
			_tiquer_statuts(e, h.ticks)
	_tiquer_differes(nom, h.ticks)
	_verifier_desengagements()
	EventBus.dispatcher()


func differe_clear() -> void:
	differes.clear()
	obstacles.clear()


## Charges différées (Mèche, Écho) et expirations (glyphes, barrières) de l'horloge `nom`.
func _tiquer_differes(nom: String, tick: int) -> void:
	var restants: Array[Dictionary] = []
	for d in differes:
		var src: Dictionary = entites.get(d.source, {})
		if src.is_empty() or src.horloge != nom:
			restants.append(d)
		elif int(d.tick) <= tick:
			if src.vivant:
				_executer_capacite(src, d.plan, d.pos, false)
		else:
			restants.append(d)
	differes = restants
	var g_restants: Array[Dictionary] = []
	for gl in glyphes:
		var src: Dictionary = entites.get(gl.source, {})
		if src.is_empty() or src.horloge != nom or int(gl.fin) > tick:
			g_restants.append(gl)
	glyphes = g_restants
	var o_restants: Array[Dictionary] = []
	for o in obstacles:
		var src: Dictionary = entites.get(o.source, {})
		if not src.is_empty() and src.horloge == nom and int(o.fin) <= tick:
			grille.contenu[grille.idx(o.pos)] = 0
			EventBus.emettre(&"tile_changed", [o.pos])
		else:
			o_restants.append(o)
	obstacles = o_restants


## Un glyphe posé sur cette tuile ? Il se déclenche à l'entrée (Familles de capacités de la grille).
func _declencher_glyphe(entrant: Dictionary, pos: Vector2i) -> void:
	for gl in glyphes.duplicate():
		if gl.pos != pos:
			continue
		var src: Dictionary = entites.get(gl.source, {})
		glyphes.erase(gl)
		if src.is_empty():
			continue
		EventBus.emettre(&"journal", [&"journal.glyphe_declenche", {"nom": entrant.name_key, "source": src.name_key}])
		var charge: Dictionary = gl.plan.duplicate()
		charge.geometrie = "point"   # la charge au sol frappe celui qui entre
		_executer_capacite(src, charge, pos, true)


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
		"descendre":
			if _descendre(e):
				return true   # la grille a changé : plus rien à finir sur l'ancienne
		"equiper":
			ok = _equiper(e, str(i.get("objet", "")), h.ticks)
		"ramasser":
			ok = _ramasser(e, h.ticks)
		"sertir":
			ok = _sertir(e, str(i.get("objet", "")), str(i.get("gemme", "")), h.ticks)
		"lire":
			ok = _lire(e, str(i.get("objet", "")), h.ticks)
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
	if Etres.bloque_statuts(e, "deplacement", statuts_defs):
		return false
	_quitter_garde(e)
	grille.liberer(e.pos)
	e.orientation = vers - e.pos
	e.pos = vers
	grille.placer(e.id, vers)
	e.compteur = tick + _ticks_avec_statuts(e, regles.ticks_deplacement(cout, e.competences_eff, en_combat(e)))
	_declencher_glyphe(e, vers)
	EventBus.emettre(&"journal", [&"journal.deplacement", {"nom": e.name_key, "cout": e.compteur - tick}])
	if chute > 0:
		var d := grille.degats_chute(chute)
		EventBus.emettre(&"journal", [&"journal.chute", {"nom": e.name_key, "niveaux": chute, "degats": d}])
		_appliquer_degats(e, d, "", {"chute": true})
	return true


func _prendre_garde(e: Dictionary, tick: int) -> bool:
	if e.endurance <= 0 or Etres.bloque_statuts(e, "garde", statuts_defs):
		return false   # à zéro d'endurance (ou feinté), garde impossible
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
	Etres.recalculer(e, items, affixes_defs, regles)
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
	if not _cible_atteignable(e, cible, _portee_effective(e, arme, fonct), true):
		return false
	if est_distance(fonct):
		# Projectile (Décision — Projectiles) : munitions, trajectoire réelle, tir refusé si un allié masque.
		if e.munitions <= 0:
			return false
		var masque := _premier_sur_trajectoire(e, cible)
		if not masque.is_empty():
			if masque.camp == e.camp:
				return false
			cible = masque   # un ennemi sur la trajectoire prend la flèche
	_quitter_garde(e)
	e.orientation = Vector2i(signi(cible.pos.x - e.pos.x), signi(cible.pos.y - e.pos.y))
	e.derniere_cible_pos = cible.pos
	var ticks := _ticks_avec_statuts(e, regles.ticks_attaque(fonct, lourde))
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


func est_distance(fonct: Dictionary) -> bool:
	return int(fonct.get("portee_min", 1)) > 1


## Coût en ticks modulé par les statuts (Ralentissement, Hâte) — Statuts.
func _ticks_avec_statuts(e: Dictionary, ticks: int) -> int:
	return maxi(1, roundi(float(ticks) * Etres.mult_statuts(e, "cout_ticks", statuts_defs)))


## La première entité vivante sur la trajectoire e → cible (sans les extrémités), ou {}.
func _premier_sur_trajectoire(e: Dictionary, cible: Dictionary) -> Dictionary:
	for t in grille.trajectoire(e.pos, cible.pos):
		var occ := grille.occupant(t)
		if not occ.is_empty() and entites[occ].vivant:
			return entites[occ]
	return {}


## Ce que verrait un tir : {ok, raison, bloqueur} — pour l'UI (la cible grisée, la tuile bloquante).
func verifier_tir(e: Dictionary, cible: Dictionary) -> Dictionary:
	var arme := Etres.arme(e, items)
	var fonct: Dictionary = fonctionnalites.get(arme.get("functionality", ""), {})
	if fonct.is_empty() or not est_distance(fonct):
		return {"ok": true}
	if e.munitions <= 0:
		return {"ok": false, "raison": "munitions"}
	var m := _premier_sur_trajectoire(e, cible)
	if not m.is_empty() and m.camp == e.camp:
		return {"ok": false, "raison": "allie", "bloqueur": m.pos}
	return {"ok": true, "devie": m.get("id", "")}


func _frapper_arme(e: Dictionary, cible: Dictionary, arme: Dictionary, fonct: Dictionary, lourde: bool, ticks: int) -> void:
	var a_zero: bool = e.endurance <= 0
	e.endurance = maxi(0, e.endurance - int(regles.r.endurance.lourde if lourde else regles.r.endurance.attaque))
	if est_distance(fonct):
		e.munitions -= 1
		e.munitions_tirees += 1
	# Affixes de l'arme (Loot — affixes) : vecteur, dés, armure ignorée, multiplicateurs — avant le jet.
	var ax := _affixes_offensifs(e, arme, cible)
	var vecteur: Dictionary = ax.vecteur
	var d := regles.degats_arme(e.stats_eff, arme, fonct, des, lourde, a_zero, int(ax.des), e.competences_eff, vecteur)
	var wx := _facteur_wuxing(e, cible, vecteur, tick_de(e))
	var plat := int(e.get("degats_element", {}).get(wuxing.dominante(vecteur), 0))
	var res := _resoudre_coup(e, cible, (d.bruts + float(plat)) * wx.total * float(ax.mult) * Etres.mult_statuts(e, "degats", statuts_defs), fonct.type_degats, lourde, vecteur, float(ax.ignore_armure))
	res.merge(wx)
	res["competence"] = str(fonct.get("combat_skill", ""))
	var cle := &"journal.attaque_lourde" if lourde else &"journal.attaque"
	EventBus.emettre(&"journal", [cle, {"att": e.name_key, "def": cible.name_key, "zone": res.zone, "degats": res.degats, "ticks": ticks}])
	_appliquer_degats(cible, res.degats, e.id, res)
	_affixes_apres_coup(e, arme, cible, res)
	_poser_segment(e, vecteur, tick_de(e))


## Portée de l'arme, allongée par l'affixe « +N allonge ».
func _portee_effective(e: Dictionary, arme: Dictionary, fonct: Dictionary) -> Vector2i:
	var p := regles.portee_de(fonct)
	for ax in Loot.affixes_de_type(arme, affixes_defs, "meca_allonge"):
		p.y += int(ax.params.n)
	return p


## Ce que les affixes de l'arme changent AVANT le jet : {vecteur, des, mult, ignore_armure}.
## Les compteurs rythmiques avancent ici (une attaque = un cran, jamais par cible).
func _affixes_offensifs(e: Dictionary, arme: Dictionary, cible: Dictionary) -> Dictionary:
	var r := {"vecteur": vecteur_arme(arme), "des": 0, "mult": 1.0, "ignore_armure": 0.0, "plat": 0}
	# Gemmes de l'arme : la taille en affinité déplace le vecteur (AJOUT normalisé), les dégâts
	# élémentaires plats s'ajoutent si le coup porte cet élément.
	for el in e.get("affinites", {}).keys():
		r.vecteur = _ajouter_element(r.vecteur, str(el), float(e.affinites[el]))
	if arme.get("affixes", []).is_empty():
		return r
	for ax: Dictionary in arme.affixes:
		var d: Dictionary = affixes_defs.get(ax.id, {})
		if d.is_empty() or d.get("inerte", false):
			continue
		var p: Dictionary = ax.params
		match str(d.effet.type):
			"cadence_element", "cadence_des", "cadence_percant", "cadence_statut":
				ax.compteur = int(ax.compteur) + 1
				if int(ax.compteur) % int(p.n) == 0:
					match str(d.effet.type):
						"cadence_element": r.vecteur = {str(p.element): 1.0}
						"cadence_des": r.des += int(p.des)
						"cadence_percant": r.ignore_armure = maxf(r.ignore_armure, float(p.pct) / 100.0)
						"cadence_statut": ax.etat["declenche"] = true
			"cond_pv":
				if float(e.sante) / float(e.sante_max) * 100.0 < float(p.pct_pv):
					r.des += int(p.des)
			"cond_element_cible":
				if wuxing.dominante(cible.get("elements")) == str(p.element):
					r.mult *= 1.0 + float(p.pct) / 100.0
			"cond_profondeur":
				if not donjon.is_empty() and int(donjon.etage) >= int(p.etage):
					r.des += int(p.des)
			"wuxing_avance":
				# L'élément avance dans le cycle d'engendrement à chaque coup touché (état sur l'objet).
				var courant: String = str(ax.etat.get("element", wuxing.dominante(r.vecteur)))
				if not courant.is_empty():
					r.vecteur = {courant: 1.0}
					ax.etat["element"] = str(wuxing.w.engendre[courant])
			"wuxing_ajout":
				r.vecteur = _ajouter_element(r.vecteur, str(p.element), float(p.pct) / 100.0)
			"wuxing_purification":
				var dom := wuxing.dominante(r.vecteur)
				if not dom.is_empty():
					r.vecteur = _ajouter_element(r.vecteur, dom, float(p.pct) / 100.0)
	return r


## Modificateur d'affinité AJOUT puis normalisation à somme 1 (Modificateurs d'affinité).
func _ajouter_element(v: Dictionary, element: String, part: float) -> Dictionary:
	var res := v.duplicate()
	res[element] = float(res.get(element, 0.0)) + part
	var total := 0.0
	for k in res.keys():
		total += float(res[k])
	if total <= 0.0:
		return res
	for k in res.keys():
		res[k] = float(res[k]) / total
	return res


## Ce que les affixes de l'arme font APRÈS le coup : vol de vie, statuts par zone ou cadence,
## hâte à la mise à mort.
func _affixes_apres_coup(e: Dictionary, arme: Dictionary, cible: Dictionary, res: Dictionary) -> void:
	for ax: Dictionary in arme.get("affixes", []):
		var d: Dictionary = affixes_defs.get(ax.id, {})
		if d.is_empty() or d.get("inerte", false):
			continue
		var p: Dictionary = ax.params
		match str(d.effet.type):
			"meca_vol_de_vie":
				e.sante = mini(e.sante_max, e.sante + roundi(float(res.degats) * float(p.pct) / 100.0))
			"decl_zone_statut":
				if res.zone == str(p.zone) and cible.vivant:
					appliquer_statut(cible, str(d.effet.statut), int(p.duree_ticks), e.id)
			"cadence_statut":
				if ax.etat.get("declenche", false):
					ax.etat.erase("declenche")
					if cible.vivant:
						appliquer_statut(cible, str(d.effet.statut), int(d.effet.get("duree_ticks", 30)), e.id)
			"decl_mise_a_mort_hate":
				if not cible.vivant:
					appliquer_statut(e, "hate", int(p.ticks), e.id)


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
		var m := wuxing.multiplicateur(v_att, piece.elements, "defensif")
		for ax in Loot.affixes_de_type(piece, affixes_defs, "wuxing_defense"):
			if m < 1.0:
				m = 1.0 - (1.0 - m) * (1.0 + float(ax.params.pct) / 100.0)   # un bon matchup défensif l'est un peu plus
		return {"mult": m, "contre": piece.elements, "table": "defensif"}
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
	_declencher(e, "accord", e.derniere_cible_pos)
	var p := wuxing.poser(e.chaine, element, tick)
	if p.resout:
		EventBus.emettre(&"journal", [&"journal.chaine_resout", {"nom": e.name_key, "mult": "%.2f" % p.multiplicateur}])
	else:
		EventBus.emettre(&"journal", [&"journal.chaine_segment", {"nom": e.name_key, "element": "element." + element,
			"position": p.position, "capacite": e.chaine.capacite, "transition": "%.2f" % p.transition}])


## Un coup contre une cible : zone par dénivelé, garde (frontale / bouclier), armure de zone.
func _resoudre_coup(att: Dictionary, cible: Dictionary, bruts: float, type_degats: String, lourde: bool, element: Variant, ignore_armure: float = 0.0) -> Dictionary:
	var zone: Dictionary = regles.zone_de_coup(grille.h(att.pos), grille.h(cible.pos))
	var piece := Etres.piece_zone(cible, zone.zone, items)
	var armure := regles.armure_piece(piece, type_degats) + Etres.add_statuts(cible, "armure", statuts_defs)
	for ax in Etres.affixes_equipes(cible, items, affixes_defs, "meca_armure"):
		armure += float(ax.params.n)
	armure *= 1.0 - ignore_armure
	var direction := Regles.direction_relative(cible.orientation, att.pos - cible.pos)
	var bouclier := Etres.a_bouclier(cible, items)
	var tient: bool = cible.garde and regles.garde_tient(direction, bouclier, lourde) and not Etres.bloque_statuts(cible, "garde", statuts_defs)
	var sans_garde := regles.degats_finaux(bruts, zone.mult, armure, false)
	var degats := regles.degats_finaux(bruts, zone.mult, armure, tient)
	if cible.garde:
		if tient:
			var cout := regles.cout_garde_impact(sans_garde, bouclier)
			for ax in Etres.affixes_equipes(cible, items, affixes_defs, "meca_garde_endurance"):
				cout = roundi(float(cout) * (1.0 - float(ax.params.pct) / 100.0))   # garde −N % d'endurance
			cible.endurance = maxi(0, cible.endurance - cout)
			for ax in Etres.affixes_equipes(cible, items, affixes_defs, "decl_parade_endurance"):
				cible.endurance = mini(cible.endurance_max, cible.endurance + int(ax.params.endurance))
			for ax in Etres.affixes_equipes(cible, items, affixes_defs, "cadence_garde_endurance"):
				ax.instance.compteur = int(ax.instance.compteur) + 1
				if int(ax.instance.compteur) % int(ax.params.n) == 0:
					cible.endurance = mini(cible.endurance_max, cible.endurance + int(ax.params.endurance))
			_declencher(cible, "parade", att.pos)
			EventBus.emettre(&"journal", [&"journal.garde_tient", {"nom": cible.name_key, "avant": sans_garde, "apres": degats}])
			if cible.endurance <= 0:
				cible.garde = false
		elif lourde and not bouclier:
			cible.garde = false   # la lourde brise la garde
	# Inversés en armure : « quand le porteur est touché » (Loot — affixes, déclencheurs)
	if att.has("id"):
		for ax in Etres.affixes_equipes(cible, items, affixes_defs, "decl_touche_statut"):
			if des.reel() * 100.0 < float(ax.params.chance):
				appliquer_statut(att, str(ax.effet.statut), int(ax.params.duree_ticks), cible.id)
	return {"zone": zone.zone, "mult": zone.mult, "armure": armure, "direction": direction,
		"garde": tient, "degats": degats, "bruts": bruts, "type": type_degats, "element": element,
		"construction": str(piece.get("construction", "")), "evites": maxi(0, roundi(bruts * zone.mult) - degats)}


func _appliquer_degats(cible: Dictionary, degats: int, source: String, detail: Dictionary) -> void:
	_verser_xp(cible, degats, source, detail)
	var avant_pct := float(cible.sante) / float(cible.sante_max)
	cible.sante = maxi(0, cible.sante - degats)
	EventBus.emettre(&"damage_dealt", [source, cible.id, degats, detail])
	var att: Dictionary = entites.get(source, {})
	if cible.sante <= 0 and cible.vivant:
		cible.vivant = false
		grille.liberer(cible.pos)
		EventBus.emettre(&"journal", [&"journal.mort", {"nom": cible.name_key}])
		EventBus.emettre(&"creature_killed", [cible.id, source])
		_declencher(cible, "testament", cible.pos)   # la charge part quand le porteur tombe
		_drop(cible, source)
	# Déclencheurs à événement (Modules) : Ouverture au premier contact, Riposte quand le porteur est
	# touché, Veille quand un allié passe sous le seuil.
	if not att.is_empty():
		for e in [att, cible]:
			if not e.contact:
				e.contact = true
				_declencher(e, "ouverture", cible.pos if e.id == att.id else att.pos)
		if cible.vivant:
			_declencher(cible, "riposte", att.pos)
	for p in vivants():
		if p.id != cible.id and p.camp == cible.camp:
			for d in p.declencheurs_armes.duplicate():
				if d.evenement == "veille" and avant_pct * 100.0 >= float(d.plan.pct_declencheur) and float(cible.sante) / float(cible.sante_max) * 100.0 < float(d.plan.pct_declencheur):
					p.declencheurs_armes.erase(d)
					_executer_capacite(p, d.plan, cible.pos, false)


## Fait partir les charges armées sur `e` pour cet événement (chacune une seule fois).
func _declencher(e: Dictionary, evenement: String, pos: Vector2i) -> void:
	for d in e.declencheurs_armes.duplicate():
		if d.evenement == evenement:
			e.declencheurs_armes.erase(d)
			EventBus.emettre(&"journal", [&"journal.declencheur", {"nom": e.name_key, "evenement": "declencheur." + evenement, "capacite": d.plan.noyau.name_key}])
			_executer_capacite(e, d.plan, pos, false)


## XP de combat : les dégâts appliqués, plafonnés aux PV restants, versés à l'élément, à la
## compétence et au type de dégâts ; l'armure de la cible gagne ce qu'elle épargne.
func _verser_xp(cible: Dictionary, degats: int, source: String, detail: Dictionary) -> void:
	var xp := mini(degats, int(cible.sante))
	var att: Dictionary = entites.get(source, {})
	if not att.is_empty() and att.has("xp") and xp > 0:
		var el := wuxing.dominante(detail.get("element"))
		if not el.is_empty():
			att.xp.element[el] = int(att.xp.element.get(el, 0)) + xp
		var comp := str(detail.get("competence", ""))
		if not comp.is_empty():
			att.xp.competence[comp] = int(att.xp.competence.get(comp, 0)) + xp
		var type := str(detail.get("type", ""))
		if not type.is_empty():
			att.xp.type[type] = int(att.xp.type.get(type, 0)) + xp
		EventBus.emettre(&"skill_xp_gained", [att.id, comp, xp])
	var cons := str(detail.get("construction", ""))
	if cible.has("xp") and not cons.is_empty() and int(detail.get("evites", 0)) > 0:
		cible.xp.construction[cons] = int(cible.xp.construction.get(cons, 0)) + int(detail.evites)


# ---------------------------------------------------------------- statuts (Statuts · anti-stunlock)

## Applique un statut. Un contrôle dur est plafonné à 20 ticks et ne peut se réappliquer dans les
## 50 ticks suivant sa fin (joueur comme créatures). Un statut « interrompt » coupe l'action engagée
## et retire le dernier segment de chaîne (Décision — Chaîne côté ennemis).
func appliquer_statut(cible: Dictionary, id: String, duree: int, source: String) -> bool:
	var d: Dictionary = statuts_defs.get(id, {})
	if d.is_empty() or not cible.vivant:
		return false
	var tick := tick_de(cible)
	if d.get("controle", false):
		if tick < int(cible.anti_stunlock_jusqua):
			return false
		duree = mini(duree, int(regles.r.anti_stunlock.max_ticks))
		cible.anti_stunlock_jusqua = tick + duree + int(regles.r.anti_stunlock.verrou_ticks)
	if not d.get("cumule", false):
		for s: Dictionary in cible.statuts:
			if s.id == id:
				s.fin = maxi(int(s.fin), tick + duree)   # rafraîchi, jamais cumulé
				return true
	cible.statuts.append({"id": id, "fin": tick + duree, "prochain": tick + int(d.periode_ticks), "source": source})
	for mod: Dictionary in d.get("modifiers", []):
		if mod.cible == "compteur" and mod.has("add"):
			cible.compteur = maxi(cible.compteur, tick) + int(mod.add)
	if "interrompt" in d.get("tags", []):
		_interrompre(cible)
	EventBus.emettre(&"journal", [&"journal.statut", {"nom": cible.name_key, "statut": d.name_key, "duree": duree}])
	return true


func _interrompre(cible: Dictionary) -> void:
	if not cible.action_en_cours.is_empty():
		EventBus.emettre(&"action_resolved", [cible.id, cible.action_en_cours])
		cible.action_en_cours = {}
	if cible.has("chaine") and wuxing.interrompre(cible.chaine):
		EventBus.emettre(&"journal", [&"journal.chaine_interrompue", {"nom": cible.name_key}])


## Un contrôle de tempo (effet `tempo`) : retarde le compteur, dans le budget anti-stunlock.
func _tempo(cible: Dictionary, ticks: int, source: String) -> int:
	var tick := tick_de(cible)
	if ticks <= 0:
		cible.compteur = maxi(tick, cible.compteur + ticks)   # avancer : sans plafond
		return ticks
	if tick < int(cible.anti_stunlock_jusqua):
		return 0
	var n := mini(ticks, int(regles.r.anti_stunlock.max_ticks))
	cible.anti_stunlock_jusqua = tick + n + int(regles.r.anti_stunlock.verrou_ticks)
	cible.compteur += n
	cible.statuts.append({"id": "retarde", "fin": tick + n, "prochain": tick + n, "source": source})
	return n


## Dégâts périodiques et expirations — appelé en fin de pas pour tous les êtres de l'horloge.
func _tiquer_statuts(e: Dictionary, tick: int) -> void:
	var restants: Array = []
	for s: Dictionary in e.statuts:
		var d: Dictionary = statuts_defs.get(s.id, {})
		while e.vivant and int(s.prochain) <= tick and int(s.prochain) <= int(s.fin) and d.get("degats_des") != null:
			var deg := des.jet(d.degats_des)
			EventBus.emettre(&"journal", [&"journal.statut_degats", {"nom": e.name_key, "statut": d.name_key, "degats": deg}])
			_appliquer_degats(e, deg, s.source, {"statut": s.id, "element": {d.element: 1.0} if d.get("element") else {}, "type": "statut"})
			s.prochain = int(s.prochain) + int(d.periode_ticks)
		if int(s.fin) > tick:
			restants.append(s)
	e.statuts = restants


## Résolution d'une action engagée (télégraphée) à son échéance.
func _resoudre_action_engagee(e: Dictionary, a: Dictionary) -> void:
	EventBus.emettre(&"action_resolved", [e.id, a])
	var cible: Dictionary = entites.get(a.get("cible", ""), {})
	match str(a.type):
		"arme":
			var arme := Etres.arme(e, items)
			var fonct: Dictionary = fonctionnalites.get(arme.get("functionality", ""), {})
			if cible.is_empty() or not cible.vivant or not _cible_atteignable(e, cible, _portee_effective(e, arme, fonct), true):
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
					var d := regles.degats_action(e.stats_eff, action, des, a_zero, bonus)
					var wx := _facteur_wuxing(e, c, action.elements, tick_de(e))
					var res := _resoudre_coup(e, c, d.bruts * wx.total * Etres.mult_statuts(e, "degats", statuts_defs), str(action.get("type_degats", "contondant")), false, action.elements)
					res.merge(wx)
					res["competence"] = action.id
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
			"statut":
				for c in cibles:
					if effet.has("chance") and des.reel() >= float(effet.chance):
						continue
					appliquer_statut(c, str(effet.id), int(effet.get("duree_ticks", statuts_defs.get(effet.id, {}).get("duree_ticks", 10))), e.id)
			_:
				pass   # bonus_premiere_attaque (embuscade) : la détection du joueur n'existe pas encore


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
	var plan := capacites.assembler(caps[index].modules, ticks_arme, fonct.get("degats_des", "1d4"), vecteur_arme(arme), e.competences_eff)
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
		e.derniere_cible_pos = cible_pos
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
	if not plan.charge_suivante.is_empty():
		_payer(e, plan.charge_suivante)   # la charge différée paie aussi, dans sa propre monnaie
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
func _executer_capacite(e: Dictionary, plan: Dictionary, cible_pos: Vector2i, segment: bool = true) -> void:
	var tick := tick_de(e)
	var tuiles := Capacites.tuiles_de_forme(grille, plan.geometrie, e.pos, cible_pos, int(plan.taille))
	var touchees := _entites_dans(e, plan, tuiles)
	# Liaisons qui étendent les cibles : Miroir (position symétrique), Partage (le lanceur aussi).
	for l: Dictionary in plan.liaisons:
		if l.get("miroir", false):
			var sym: Vector2i = e.pos - (cible_pos - e.pos)
			for c in _entites_dans(e, plan, Capacites.tuiles_de_forme(grille, plan.geometrie, e.pos, sym, int(plan.taille))):
				if not touchees.has(c):
					touchees.append(c)
		if l.get("partage", false) and not touchees.has(e):
			touchees.append(e)
	var elements: Dictionary = plan.elements
	var prev := {}
	if segment and e.has("chaine") and not elements.is_empty() and not plan.parametres.get("sans_segment", false):
		wuxing.decroitre(e.chaine, tick)
		prev = wuxing.prevoir(e.chaine, wuxing.dominante(elements))
	var charge := plan
	for l: Dictionary in plan.liaisons:
		if l.get("dispersion", false) and touchees.size() > 1:
			charge = plan.duplicate()
			charge.mult = float(plan.mult) / float(touchees.size())   # la charge répartie, divisée par leur nombre
	var res := {"a_touche": false, "premiere": {}, "tuee": {}}
	var salve := {}
	for l: Dictionary in plan.liaisons:
		if l.has("salve"):
			salve = l
	if not plan.noyau.is_empty() and not salve.is_empty() and not touchees.is_empty():
		# Salve : 3 charges simultanées à 60 %, réparties dans la forme (une cible chacune, à tour de rôle).
		for k in int(salve.salve):
			var tir := plan.duplicate()
			tir.mult = float(plan.mult) * float(salve.mult)
			tir.liaisons = []
			var r := _appliquer_charge(e, tir, [touchees[k % touchees.size()]], tuiles, cible_pos, prev if k == 0 else {})
			res.a_touche = res.a_touche or r.a_touche
			if res.premiere.is_empty():
				res.premiere = r.premiere
	elif not plan.noyau.is_empty():
		res = _appliquer_charge(e, charge, touchees, tuiles, cible_pos, prev)
	var a_touche: bool = res.a_touche
	for l: Dictionary in plan.liaisons:
		if l.get("propagation", false) and a_touche:
			# De proche en proche tant que ça touche, −1 dé par pas.
			var deja: Array[Dictionary] = touchees.duplicate()
			var depuis: Dictionary = touchees.back()
			var pas := 1
			while true:
				var suivante := _voisine_non_touchee(e, depuis, deja, 1)
				if suivante.is_empty():
					break
				var saut := plan.duplicate()
				saut.des_bonus = int(plan.des_bonus) + int(l.get("des", -1)) * pas
				saut.liaisons = []
				_appliquer_charge(e, saut, [suivante], [suivante.pos], suivante.pos, {})
				deja.append(suivante)
				depuis = suivante
				pas += 1
		if l.get("boucle", false) and a_touche and plan.monnaie == "mana":
			# Rejoue tant qu'il reste de la ressource, −1 dé cumulé par tour ; jamais de surchauffe.
			var tour := 1
			while int(e.mana) >= int(plan.ressource) and tour < 20:
				e.mana -= int(plan.ressource)
				var rejeu := plan.duplicate()
				rejeu.des_bonus = int(plan.des_bonus) + int(l.get("des", -1)) * tour
				rejeu.liaisons = []
				if not _appliquer_charge(e, rejeu, touchees, tuiles, cible_pos, {}).a_touche:
					break
				tour += 1
		if l.get("contagion", false) and plan.parametres.has("statut"):
			# Les statuts du noyau se propagent aux ennemis adjacents des cibles touchées.
			var st: Dictionary = plan.parametres.statut
			for c in touchees.duplicate():
				for v in vivants():
					if v.camp != e.camp and not touchees.has(v) and Grille.distance(v.pos, c.pos) == 1:
						appliquer_statut(v, str(st.id), int(st.duree_ticks), e.id)
	for l: Dictionary in plan.liaisons:
		if l.has("echo"):   # Écho : rejoue la charge à 50 % après 20 ticks
			var rejeu := plan.duplicate()
			rejeu.mult = float(plan.mult) * float(l.echo)
			rejeu.liaisons = []
			rejeu.charge_suivante = {}
			differes.append({"tick": tick + int(l.get("apres_ticks", 20)), "source": e.id, "plan": rejeu, "pos": cible_pos})
	# Liaisons qui rejouent : Répétition (2 fois, −1 dé), Ricochet (1d3 cibles proches, −1 dé par saut).
	for l: Dictionary in plan.liaisons:
		if l.has("rejoue"):
			for i in int(l.rejoue):
				var rejeu := plan.duplicate()
				rejeu.des_bonus = int(plan.des_bonus) + int(l.get("des", -1))
				rejeu.liaisons = []
				a_touche = _appliquer_charge(e, rejeu, touchees, tuiles, cible_pos, {}).a_touche or a_touche
		if l.has("sauts") and not touchees.is_empty():
			var deja: Array[Dictionary] = touchees.duplicate()
			var depuis: Dictionary = touchees.back()
			for k in des.jet(l.sauts):
				var suivante := _voisine_non_touchee(e, depuis, deja, int(l.get("portee", 2)))
				if suivante.is_empty():
					break
				var saut := plan.duplicate()
				saut.des_bonus = int(plan.des_bonus) + int(l.get("des", -1)) * (k + 1)
				saut.liaisons = []
				a_touche = _appliquer_charge(e, saut, [suivante], [suivante.pos], suivante.pos, {}).a_touche or a_touche
				deja.append(suivante)
				depuis = suivante
	if plan.drapeaux.has("projection"):
		_effet_deplacement(e, {"mode": "projection", "distance": str(plan.drapeaux.projection)}, touchees, {})
	if segment and a_touche and not elements.is_empty() and not plan.parametres.get("sans_segment", false):
		_poser_segment(e, elements, tick)
		var extra := int(plan.drapeaux.get("segments", 0))
		for i in extra:
			_poser_segment(e, elements, tick)
	# Déclencheur : la charge qui suit part à l'impact, ou à la mise à mort — sans second segment.
	var suite: Dictionary = plan.charge_suivante
	if not suite.is_empty() and suite.erreurs.is_empty():
		var ou: Vector2i = res.premiere.pos if not res.premiere.is_empty() else cible_pos
		match str(suite.declencheur):
			"impact":
				if a_touche:
					_executer_capacite(e, suite, ou, false)
			"mise_a_mort":
				if not res.tuee.is_empty():
					_executer_capacite(e, suite, res.tuee.pos, false)
			"entree":
				# Sceau : la charge attend au sol, jusqu'à 100 ticks — overlay runtime, jamais sauvegardé.
				var duree := int(suite.get("duree_declencheur", 100))
				glyphes.append({"pos": cible_pos, "plan": suite, "source": e.id, "fin": tick + duree, "elements": suite.elements})
				EventBus.emettre(&"journal", [&"journal.glyphe_pose", {"nom": e.name_key, "capacite": suite.noyau.name_key, "x": cible_pos.x, "y": cible_pos.y}])
				var occ := grille.occupant(cible_pos)
				if not occ.is_empty():
					_declencher_glyphe(entites[occ], cible_pos)
			"apres_ticks":
				var n := int(suite.get("ticks_declencheur", 20))
				differes.append({"tick": tick + n, "source": e.id, "plan": suite, "pos": ou})
				EventBus.emettre(&"journal", [&"journal.differe", {"nom": e.name_key, "capacite": suite.noyau.name_key, "ticks": n}])
			"cadence":
				# Tous les N emplois de la capacité, la charge qui suit part aussi.
				var cle := str(plan.get("id", ""))
				e.emplois[cle] = int(e.emplois.get(cle, 0)) + 1
				if int(e.emplois[cle]) % int(suite.get("n_declencheur", 3)) == 0:
					_executer_capacite(e, suite, ou, false)
			"riposte", "parade", "ouverture", "veille", "testament", "accord":
				# La charge attend l'événement sur le porteur — armée une fois.
				e.declencheurs_armes.append({"evenement": str(suite.declencheur), "plan": suite})
				EventBus.emettre(&"journal", [&"journal.arme", {"nom": e.name_key, "capacite": suite.noyau.name_key, "evenement": "declencheur." + str(suite.declencheur)}])
	EventBus.emettre(&"action_resolved", [e.id, {"type": "capacite", "plan": plan}])


## Les entités vivantes couvertes par des tuiles (Point : une cible unique, jamais le lanceur ;
## les zones touchent tout ce qu'elles couvrent, alliés compris).
func _entites_dans(e: Dictionary, plan: Dictionary, tuiles: Array[Vector2i]) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	if plan.geometrie == "tuile":
		return res   # Tuile : au sol, sans cible vivante (la forme des glyphes et des zones)
	for t in tuiles:
		var occ := grille.occupant(t)
		if occ.is_empty():
			continue
		var c: Dictionary = entites[occ]
		if not c.vivant:
			continue
		if plan.geometrie == "point" and c.id == e.id:
			continue
		if plan.ligne_de_vue and plan.geometrie != "point" and plan.geometrie != "soi" and not grille.ligne_de_vue(e.pos, t):
			continue
		res.append(c)
	return res


## L'ennemi vivant le plus proche de `depuis` (≤ portée), pas encore touché.
func _voisine_non_touchee(e: Dictionary, depuis: Dictionary, deja: Array[Dictionary], portee: int) -> Dictionary:
	var meilleure := {}
	var dmin := 1 << 30
	for c in vivants():
		if c.camp == e.camp or deja.has(c):
			continue
		var d := Grille.distance(c.pos, depuis.pos)
		if d <= portee and d < dmin:
			dmin = d
			meilleure = c
	return meilleure


## Applique les effets du noyau à des cibles. Retourne {a_touche, premiere, tuee}.
func _appliquer_charge(e: Dictionary, plan: Dictionary, touchees: Array[Dictionary], tuiles: Array[Vector2i], cible_pos: Vector2i, prev: Dictionary) -> Dictionary:
	var tick := tick_de(e)
	var a_touche := false
	var premiere := {}
	var tuee := {}
	for effet: String in plan.effets:
		match effet:
			"degats":
				for c in touchees:
					if c.id == e.id:
						continue
					var d := _degats_capacite(e, c, plan, prev)
					a_touche = true
					if premiere.is_empty():
						premiere = c
					EventBus.emettre(&"journal", [&"journal.capacite", {"att": e.name_key, "capacite": plan.name_key, "def": c.name_key, "zone": d.zone, "degats": d.degats}])
					_appliquer_degats(c, d.degats, e.id, d)
					if not c.vivant and tuee.is_empty():
						tuee = c
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
					if premiere.is_empty():
						premiere = c
					EventBus.emettre(&"journal", [&"journal.soin", {"att": e.name_key, "capacite": plan.name_key, "def": c.name_key, "soin": c.sante - avant}])
			"deplacement":
				var dp: Dictionary = plan.parametres.get("deplacement", {})
				if not dp.is_empty():
					var occ := grille.occupant(cible_pos)
					_effet_deplacement(e, dp, touchees, entites.get(occ, {}))
					a_touche = a_touche or not touchees.is_empty()
			"statut":
				var st: Dictionary = plan.parametres.get("statut", {})
				if not st.is_empty():
					var pour_allie: bool = plan.parametres.get("cible", "ennemi") == "allie"
					var duree := int(st.duree_ticks) * int(plan.drapeaux.get("durees_mult", 1))
					if not prev.is_empty() and prev.resout and pour_allie:
						duree = roundi(float(duree) * float(prev.multiplicateur) * float(wuxing.w.chaine.resolveur_non_offensif))
					for c in touchees:
						if (c.camp == e.camp) == pour_allie or plan.geometrie == "soi":
							if appliquer_statut(c, str(st.id), duree, e.id):
								a_touche = true
								if premiere.is_empty():
									premiere = c
			"tempo":
				var n := int(plan.parametres.get("tempo", 0))
				for c in touchees:
					if c.camp == e.camp and n > 0:
						continue
					var applique := _tempo(c, n, e.id)
					a_touche = a_touche or applique != 0
					if plan.parametres.get("vol", false) and applique > 0:
						e.compteur = maxi(tick, e.compteur - applique)
			"terrain":
				var tp: Dictionary = plan.parametres.get("terrain", {})
				if not tp.is_empty():
					for t in tuiles:
						var avant := grille.h(t)
						var apres := clampi(avant + int(tp.delta), 0, 20)
						if apres == avant:
							continue
						grille.hauteurs[grille.idx(t)] = apres
						a_touche = true
						EventBus.emettre(&"journal", [&"journal.terrain", {"x": t.x, "y": t.y, "avant": avant, "apres": apres}])
						EventBus.emettre(&"tile_changed", [t])
						var occ := grille.occupant(t)
						if tp.get("chute", false) and not occ.is_empty() and avant - apres >= int(regles.r.deplacement.chute_delta):
							var c: Dictionary = entites[occ]
							var deg := grille.degats_chute(avant - apres)
							EventBus.emettre(&"journal", [&"journal.chute", {"nom": c.name_key, "niveaux": avant - apres, "degats": deg}])
							_appliquer_degats(c, deg, e.id, {"chute": true})
			"invocation":
				var iv: Dictionary = plan.parametres.get("invocation", {})
				if not iv.is_empty():
					for t in tuiles:
						if not grille.occupant(t).is_empty() or grille.bloque_passage(t):
							continue
						grille.poser_contenu(t, str(iv.contenu))
						obstacles.append({"pos": t, "fin": tick + int(iv.duree_ticks), "source": e.id})
						a_touche = true
						EventBus.emettre(&"journal", [&"journal.invocation", {"nom": e.name_key, "contenu": "tile_content." + str(iv.contenu) + ".name", "x": t.x, "y": t.y, "ticks": iv.duree_ticks}])
						EventBus.emettre(&"tile_changed", [t])
			_:
				pass   # saisie : étape suivante
	return {"a_touche": a_touche, "premiere": premiere, "tuee": tuee}


## Dégâts d'un noyau sur une cible : noyau « arme » = formule de l'arme ; noyau magique = jet × niveau.
## La réduction d'armure ne s'applique qu'à 50 % aux dégâts magiques (Armure par zone).
func _degats_capacite(e: Dictionary, c: Dictionary, plan: Dictionary, prev: Dictionary) -> Dictionary:
	var a_zero: bool = e.endurance <= 0 and plan.monnaie == "endurance"
	var arme_noyau: bool = plan.noyau.get("power_base") == "arme"
	var d: Dictionary
	var type_degats := "magique"
	if arme_noyau and not plan.arme.is_empty():
		d = regles.degats_arme(e.stats_eff, plan.arme, plan.fonct, des, false, a_zero, int(plan.des_bonus), e.competences_eff, plan.elements)
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
		armure = regles.armure_piece(piece, type_degats if type_degats != "magique" else "contondant") + Etres.add_statuts(c, "armure", statuts_defs)
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
		"contre": dom.contre, "gain": gain, "chaine": chaine, "jet": d.jet,
		"competence": str(plan.fonct.get("combat_skill", "")) if arme_noyau else "magie_" + wuxing.dominante(plan.elements),
		"construction": str(piece.get("construction", "")), "evites": maxi(0, roundi(bruts * zone.mult) - degats)}


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
			dernier_combat = {"nom": nom, "ticks": h.ticks, "participants": c.participants.duplicate(), "victoire": true}
			for id in c.participants.duplicate():
				var p: Dictionary = entites[id]
				if p.camp == "joueur" and not p.vivant:
					dernier_combat.victoire = false
				# 50 % des munitions tirées sont récupérées au sol (arrondi bas).
				var recup := int(floorf(float(p.munitions_tirees) * float(regles.r.projectiles.recuperation)))
				p.munitions += recup
				p.munitions_tirees = 0
				p.declencheurs_armes.clear()
				p.contact = false
				_quitter_combat(p)
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
		var m := float(f.x + f.y) * 0.5 + _bonus_chaine_ia(e, a.get("elements", {}))
		if m > moy:
			moy = m
			meilleure = {"type": "creature", "action": a}
	var arme := Etres.arme(e, items)
	if not arme.is_empty():
		var fonct: Dictionary = fonctionnalites.get(arme.functionality, {})
		if _cible_atteignable(e, cible, regles.portee_de(fonct), true):
			var f := Des.fourchette(fonct.degats_des)
			var m := float(f.x + f.y) * 0.5 * float(arme.durete_base) / float(regles.r.degats.durete_reference) + _bonus_chaine_ia(e, vecteur_arme(arme))
			if m > moy:
				meilleure = {"type": "arme", "arme": arme, "fonct": fonct}
	return meilleure


## Les porteurs de jauge privilégient les transitions d'engendrement (considération `chain_bonus`).
func _bonus_chaine_ia(e: Dictionary, elements: Dictionary) -> float:
	if not e.has("chaine") or elements.is_empty():
		return 0.0
	var profil: Dictionary = profils_ia.get(e.ai_profile, {})
	var p := wuxing.prevoir(e.chaine, wuxing.dominante(elements))
	return float(profil.get("chain_bonus", 0.0)) * float(p.transition) * 10.0


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
