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
var progression: Progression
var niveaux_gagnes: Array = []       # [{id, competence, niveau}] depuis le dernier écran de fin
var fiche_joueur: Dictionary = {}    # la fiche créée (Création de personnage), sinon l'aventurier du catalogue
var etages_visites: Dictionary = {}  # étage → état sauvé (grille, êtres, contenants) : mobs et loot sont FIXES (Donjons)
var expedition: Dictionary = {}      # compteurs de l'expédition en cours : tués, objets, étage max
var camp_sauve: Dictionary = {}      # le camp mis de côté pendant une expédition (Claims et persistance)
var lieu: String = "arene"           # "arene" | "camp" | "donjon"
var prochain_donjon: int = 1         # id du prochain donjon lancé depuis le camp
var monde: Monde = null              # la surface comme fenêtre glissante (étape 8.2a)
var territoire: Dictionary = {"tresor": 0, "dette": 0, "semaines_dette": 0, "stocks": {}, "rapports": [], "gains_quetes": 0, "royaume": false}   # le royaume du joueur (étape 10)
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
	progression = Progression.new(regles.r.progression, GameData.catalogues.get("competences", {}), GameData.config("astrologie"))


# ---------------------------------------------------------------- mise en place

## Charge une arène de data/prototype_arenas et instancie ses êtres.
func charger_arene(id: String) -> void:
	arene_id = id
	donjon = {}
	lieu = "arene"
	var arene := GameData.entree("prototype_arenas", id)
	grille = Grille.depuis_arene(arene, GameData.config("tile_contents"),
		regles.r.deplacement, int(regles.r.vision.hauteur_oeil))
	_reinitialiser()
	var j: Dictionary = arene.spawns.player
	ajouter(j.creature, Vector2i(int(j.pos[0]), int(j.pos[1])), "joueur")
	for s: Dictionary in arene.spawns.enemies:
		ajouter(s.creature, Vector2i(int(s.pos[0]), int(s.pos[1])), "ia")
	maj_vision()


## Le camp de base (Claims et persistance, étape 7) : une cellule plate revendiquée d'office. Restauré
## tel quel s'il a déjà été visité ; sinon généré, avec le coffre de départ. `joueur` : l'être qui
## revient d'expédition (vide au premier chargement : créé depuis la fiche).
func charger_camp(joueur: Dictionary = {}, cellule_choisie: Vector2i = Vector2i(-1, -1)) -> void:
	arene_id = "camp"
	lieu = "camp"
	donjon = {}
	if not camp_sauve.is_empty():
		var sauve: Dictionary = camp_sauve
		grille = sauve.grille
		_reinitialiser()
		for id in sauve.ordre:
			entites[id] = sauve.entites[id]
			ordre.append(id)
			if entites[id].vivant:
				grille.placer(id, entites[id].pos)
		contenants = sauve.contenants
		if not joueur.is_empty():
			var ou: Vector2i = joueur.get("lit", sauve.entree) if joueur.get("mort_en_expedition", false) else joueur.get("retour", sauve.entree)
			joueur.erase("mort_en_expedition")
			joueur.erase("retour")
			_reprendre(joueur, ou)
			joueur.spawn = joueur.get("lit", sauve.entree)
		maj_vision()
		return
	# Première venue : le monde (fenêtre glissante) centré sur la cellule de départ.
	var cfg: Dictionary = GameData.config("camp")
	var planete: Dictionary = GameData.config("planete")
	var surface := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, int(planete.graine))
	monde = Monde.new(surface, planete, cfg)
	var depart := monde.cellule_camp if cellule_choisie == Vector2i(-1, -1) else cellule_choisie
	# Garde-fou (Début de partie) : si la cellule de départ est en mer, la première cellule de terre en spirale.
	var essais := 0
	var origine_spirale := depart
	while essais < 400 and not surface.terre_a(depart):
		essais += 1
		var r := 1
		var trouve := false
		while r < 20 and not trouve:
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if absi(dx) != r and absi(dy) != r:
						continue
					var c := origine_spirale + Vector2i(dx, dy)
					if surface.terre_a(c):
						depart = c
						trouve = true
						break
				if trouve:
					break
			r += 1
		break
	monde.cellule_camp = depart
	grille = monde.fenetre(depart, GameData.config("tile_contents"), regles.r.deplacement, int(regles.r.vision.hauteur_oeil))
	var e := monde.cellule(depart)
	var entree := monde.point_marchable(depart)   # le point marchable le plus proche du centre (Début de partie)
	_reinitialiser()
	if joueur.is_empty():
		var j := ajouter("aventurier", entree, "joueur")
		j.spawn = entree
	else:
		_reprendre(joueur, entree)
		joueur.spawn = entree
	var uids: Array = []
	for base in cfg.coffre_depart:
		var o := generer_objet(str(base), 1, {}, "commun", 0)
		if not o.is_empty():
			uids.append(o.uid)
	_poser_contenant(monde.pos_monde(depart, e.coffre_depart), uids, "coffre")
	camp_sauve = {"entree": entree, "biome": e.biome, "cellule": depart}
	_peupler_fenetre()
	maj_vision()
	monde.pregenerer_voisins()


## Le joueur a changé de cellule : la fenêtre se recentre (Monde). Les positions sont en coordonnées
## monde : rien ne bouge ; ce que l'ancienne fenêtre avait de non regénérable est capturé.
func _verifier_fenetre(e: Dictionary) -> void:
	if lieu != "camp" or monde == null:
		return
	var c := monde.cellule_de(e.pos)
	if c == monde.centre:
		return
	monde.capturer(grille)
	# Contenants et êtres : ce qui reste dans la nouvelle fenêtre est remappé, le reste est mis de côté.
	var anciens := {}
	for gi in contenants.keys():
		anciens[grille.pos_de(int(gi))] = contenants[gi]
	var nouvelle := monde.fenetre(c, GameData.config("tile_contents"), regles.r.deplacement, int(regles.r.vision.hauteur_oeil))
	contenants = {}
	for pos in anciens.keys():
		if nouvelle.dans(pos):
			contenants[nouvelle.idx(pos)] = anciens[pos]
			if anciens[pos].size() > 0 and nouvelle.contenu_de(pos).is_empty():
				nouvelle.poser_contenu(pos, "butin")
		else:
			var cell := monde.cellule_de(pos)
			if not monde.contenants_hors.has(cell):
				monde.contenants_hors[cell] = {}
			monde.contenants_hors[cell][monde.idx_local(pos)] = anciens[pos]
	for cell in monde.contenants_hors.keys().duplicate():
		if absi(cell.x - c.x) <= monde.rayon and absi(cell.y - c.y) <= monde.rayon:
			for li in monde.contenants_hors[cell].keys():
				var pos: Vector2i = monde.pos_monde(cell, Vector2i(int(li) % monde.taille, int(li) / monde.taille))
				contenants[nouvelle.idx(pos)] = monde.contenants_hors[cell][li]
				if nouvelle.contenu_de(pos).is_empty():
					nouvelle.poser_contenu(pos, "butin")
			monde.contenants_hors.erase(cell)
	for id in ordre.duplicate():
		var x: Dictionary = entites[id]
		if x.id != e.id and not nouvelle.dans(x.pos):
			var cell := monde.cellule_de(x.pos)
			if not monde.dormants.has(cell):
				monde.dormants[cell] = []
			monde.dormants[cell].append(x)
			ordre.erase(id)
			entites.erase(id)
	for cell in monde.dormants.keys().duplicate():
		if absi(cell.x - c.x) <= monde.rayon and absi(cell.y - c.y) <= monde.rayon:
			for x in monde.dormants[cell]:
				entites[x.id] = x
				ordre.append(x.id)
			monde.dormants.erase(cell)
	grille = nouvelle
	nouvelle.modifies.clear()
	for id in ordre:
		if entites[id].vivant:
			grille.placer(id, entites[id].pos)
	_peupler_fenetre()
	maj_vision()
	monde.pregenerer_voisins()
	EventBus.emettre(&"fenetre_recentree", [grille.origine])


## Met le camp de côté avant une expédition : grille, meubles, coffres, êtres — tout reste.
func _sauver_camp(joueur: Dictionary) -> void:
	var sauve := {"entree": camp_sauve.get("entree", joueur.pos), "biome": camp_sauve.get("biome", ""), "cellule": camp_sauve.get("cellule", Vector2i.ZERO), "grille": grille, "entites": {}, "ordre": [], "contenants": contenants}
	if monde != null:
		monde.capturer(grille)
	for id in ordre:
		if id != joueur.id:
			sauve.entites[id] = entites[id]
			sauve.ordre.append(id)
	grille.liberer(joueur.pos)
	camp_sauve = sauve


## Partir en expédition depuis l'entrée du donjon du camp.
func _partir_en_expedition(e: Dictionary) -> bool:
	if lieu != "camp" or not ("entree_donjon" in grille.contenu_de(e.pos).get("tags", [])):
		return false
	var cell := monde.cellule_de(e.pos)
	e["retour"] = e.pos   # ressortir ramène devant l'entrée (Donjons — structure et intégration)
	_sauver_camp(e)
	expedition = {}
	etages_visites.clear()
	# Le donjon de cette cellule : id déterministe, thème selon le biome (repaire en marécage/zone corrompue).
	if not monde.donjon_ouvert(cell, horloge_monde.ticks):
		return false
	var f := monde.foyer(cell)
	var id := int(hash([graine, cell.x, cell.y, "donjon", int(f.get("generation", 0))]) & 0x7fffffff)
	var b: Dictionary = GameData.catalogues.biomes.get(str(monde.surface.resume_cellule(cell).biome), {})
	var theme := "repaire" if ("marecage" in b.get("tags", []) or "corrompu" in b.get("tags", [])) else "ruine"
	var cr: Dictionary = GameData.config("planete").corruption
	var fourchette: Array = cr.etages_majeur if bool(f.get("majeur", false)) else cr.etages_mineur
	var corruption := monde.corruption_de(cell)
	if est_nuit():
		corruption = minf(100.0, corruption * (1.0 + float(_cycle().get("corruption_nuit", 0.1))))   # la nuit : +10 %
	donjon = {"etages_fixes": fourchette, "corruption": corruption, "cellule": cell}
	EventBus.emettre(&"journal", [&"journal.expedition_depart", {}])
	charger_donjon(theme, graine, id, 1, e)
	return true


## Génère et charge l'étage `etage` d'un donjon (Génération de donjon). `joueur` : la fiche du
## joueur au premier étage, ou son état courant pour le faire descendre avec ses PV et son sac.
func charger_donjon(theme_id: String, graine: int, id_donjon: int, etage: int, joueur: Dictionary = {}) -> void:
	var theme := GameData.entree("dungeon_themes", theme_id)
	var etages: int = donjon.get("etages", 0)
	var corruption_locale: float = float(donjon.get("corruption", 0.0))
	var cellule_donjon: Vector2i = donjon.get("cellule", Vector2i(-9999, -9999))
	if etages == 0:
		var r := RandomNumberGenerator.new()
		r.seed = hash([graine, id_donjon])
		var fourchette: Array = donjon.get("etages_fixes", theme.etages)   # majeur / mineur (Dérive de la corruption)
		etages = r.randi_range(int(fourchette[0]), int(fourchette[1]))
	var gen := Donjon.new(GameData.catalogues.get("dungeon_rooms", {}), GameData.catalogues.get("dungeon_connectors", {}), theme)
	var r2 := RandomNumberGenerator.new()
	r2.seed = hash([graine, id_donjon, etage, "salles"])
	var nb := r2.randi_range(int(theme.salles_par_etage[0]), int(theme.salles_par_etage[1]))
	if not joueur.is_empty() and not donjon.is_empty() and int(donjon.get("id", -1)) == id_donjon:
		_sauver_etage(joueur)
	if expedition.is_empty() or int(expedition.get("id", -1)) != id_donjon:
		expedition = {"id": id_donjon, "theme": theme_id, "tues": 0, "objets": 0, "etage_max": 1, "ticks": 0}
	expedition.etage_max = maxi(int(expedition.etage_max), etage)
	arene_id = "donjon"
	lieu = "donjon"
	if etages_visites.has(etage):
		# Un étage déjà visité revient dans l'état où on l'a laissé.
		var sauve: Dictionary = etages_visites[etage]
		donjon = sauve.donjon
		grille = sauve.grille
		_reinitialiser()
		for id in sauve.ordre:
			entites[id] = sauve.entites[id]
			ordre.append(id)
			if entites[id].vivant:
				grille.placer(id, entites[id].pos)
		contenants = sauve.contenants
		var ou: Vector2i = sauve.donjon.escalier if (not joueur.is_empty() and int(joueur.get("etage_depuis", 0)) > etage and sauve.donjon.escalier != null) else sauve.donjon.entree
		_reprendre(joueur, ou)
		return
	var e := gen.generer_etage(graine, id_donjon, etage, nb, etage == etages)
	var cr: Dictionary = GameData.config("planete").get("corruption", {})
	var corruption_etage := minf(100.0, corruption_locale + float(etage) * float(cr.get("corruption_par_etage", 8)))
	donjon = {"theme": theme_id, "graine": graine, "id": id_donjon, "etage": etage, "etages": etages,
		"salles": gen._nb_salles(e), "escalier": e.escalier, "boss": e.boss, "entree": e.entree,
		"corruption": corruption_locale, "corruption_etage": corruption_etage, "cellule": cellule_donjon,
		"profondeur": etage + int(corruption_etage / float(cr.get("profondeur_par_corruption", 25)))}
	grille = Grille.depuis_etage(e, GameData.config("tile_contents"), regles.r.deplacement, int(regles.r.vision.hauteur_oeil))
	grille.materiau_defaut = str(theme.get("materiau_mur", ""))
	for idx in e.filons.keys():
		grille.materiaux[idx] = e.filons[idx]
		grille.poser_contenu(Vector2i(int(idx) % grille.largeur, int(idx) / grille.largeur), "filon")
	_reinitialiser()
	if joueur.is_empty():
		ajouter(theme.get("joueur", "aventurier"), e.entree, "joueur")
	else:
		_reprendre(joueur, e.entree)
	var n_spawns := int(ceil(float(e.spawns.size()) * (1.0 + corruption_etage / 100.0)))   # la corruption densifie
	var k_spawn := 0
	for s: Dictionary in e.spawns:
		if grille.occupant(s.pos).is_empty():
			ajouter(s.creature, s.pos, "ia")
			k_spawn += 1
	var i_extra := 0
	while k_spawn < n_spawns and not e.spawns.is_empty() and i_extra < e.spawns.size():
		var s2: Dictionary = e.spawns[i_extra]
		i_extra += 1
		for d in Grille.DIRS:
			var q: Vector2i = s2.pos + d
			if grille.dans(q) and not grille.bloque_passage(q) and grille.occupant(q).is_empty():
				ajouter(s2.creature, q, "ia")
				k_spawn += 1
				break
	for c: Dictionary in e.coffres:
		var uids: Array = []
		for base in c.bases:
			var o := generer_objet(str(base), int(donjon.profondeur), {"donjon": theme_id, "etage": etage})
			if not o.is_empty():
				uids.append(o.uid)
		_poser_contenant(c.pos, uids, "coffre")
	maj_vision()


func _reinitialiser() -> void:
	entites.clear()
	ordre.clear()
	combats.clear()
	attente.clear()
	glyphes.clear()
	contenants = {}   # jamais clear() : un lieu mis de côté garde la référence à ses contenants
	differe_clear()
	for nom in TickManager.horloges.keys():
		TickManager.retirer(nom)
	horloge_monde = TickManager.creer("monde", Horloge.Mode.TEMPS_REEL, float(regles.r.ticks_par_seconde_exploration))
	horloge_monde.avancee.connect(_sur_avancee_monde)


## Un être qui change d'étage garde son état (PV, mana, sac, XP, compétences) — instance ≠ définition.
func _reprendre(e: Dictionary, pos: Vector2i) -> void:
	_n_entites += 1
	if not grille.occupant(pos).is_empty():
		for d in Grille.DIRS:
			if grille.dans(pos + d) and grille.occupant(pos + d).is_empty() and not grille.bloque_passage(pos + d):
				pos = pos + d
				break
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


## Creuser : détruire un mur adjacent (Destruction du terrain) — la tuile redevient sol.
## Le bord de la cellule (roche) ne se creuse pas. Coût en ticks et en endurance, XP de Terrassement.
func _creuser(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	e["vue_sale"] = true
	if not grille.dans(vers) or Grille.distance(e.pos, vers) != 1:
		return false
	var contenu := grille.contenu_de(vers)
	if not ("destructible" in contenu.get("tags", [])):
		return false
	var cr: Dictionary = regles.r.creuser
	var mat_id := grille.materiau_de(vers)
	var mat: Dictionary = GameData.catalogues.materials.get(mat_id, {})
	var outil := Etres.arme(e, items)
	var fonct: Dictionary = fonctionnalites.get(str(outil.get("functionality", "")), {})
	var recolte := not mat.is_empty() and str(fonct.get("outil", "")) == str(mat.harvest.tool_category)
	var ticks := int(cr.ticks)
	if recolte:
		# Récolte (Récolte) : l'outil adapté est en main — la formule de la note, en ticks.
		var rr: Dictionary = regles.r.recolte
		var force := float(outil.get("durete_base", rr.mains_nues_durete)) * float(outil.get("qualite", 1.0))
		var durete := float(mat.stats.durete)
		if force < durete * float(rr.seuil_irrecoltable):
			EventBus.emettre(&"journal", [&"journal.rebondit", {"materiau": mat.name_key}])
			return false
		var n := regles.niveau(e.competences_eff, str(mat.harvest.skill))
		ticks = maxi(1, ceili(durete / (force * regles.skill_factor(n)) * float(rr.ticks_par_seconde)))
	_quitter_garde(e)
	e.orientation = vers - e.pos
	grille.contenu[grille.idx(vers)] = 0
	grille.materiaux.erase(grille.idx(vers))
	grille.hauteurs[grille.idx(vers)] = grille.h(e.pos)   # la brèche est au niveau de celui qui creuse
	grille.marquer(vers)
	e.endurance = maxi(0, int(e.endurance) - int(cr.endurance))
	e.compteur = tick + _ticks_avec_statuts(e, ticks)
	if recolte:
		var rr2: Dictionary = regles.r.recolte
		var n2 := regles.niveau(e.competences_eff, str(mat.harvest.skill))
		var quantite := 1 + n2 / int(rr2.niveaux_par_unite)
		_donner_materiau(e, mat_id, quantite)
		gagner_xp(e, str(mat.harvest.skill), int(mat.stats.durete))
		EventBus.emettre(&"journal", [&"journal.recolte", {"nom": e.name_key, "quantite": quantite, "materiau": mat.name_key}])
	else:
		gagner_xp(e, "terrassement", int(cr.xp))
		if mat.is_empty():
			EventBus.emettre(&"journal", [&"journal.creuse", {"nom": e.name_key, "x": vers.x, "y": vers.y}])
		else:
			EventBus.emettre(&"journal", [&"journal.effrite", {"nom": e.name_key, "materiau": mat.name_key}])
	EventBus.emettre(&"tile_changed", [vers])
	return true


## Un matériau dans le sac : une pile par (matériau, forme) — `quantite` ; l'objet `materiau_brut` en base.
func _donner_materiau(e: Dictionary, mat_id: String, quantite: int, forme: String = "brut") -> void:
	var pile := _pile(e, mat_id, forme)
	if not pile.is_empty():
		pile.quantite = int(pile.quantite) + quantite
		return
	var inst := generer_objet("materiau_brut", 1, {}, "commun", 0)
	if inst.is_empty():
		return
	inst.materiau = mat_id
	inst.forme = forme
	inst.quantite = quantite
	inst.name_key = GameData.entree("materials", mat_id).name_key
	e.sac.append(inst.uid)


## La pile d'objets empilables d'une base (consommables) dans le sac.
func _pile_objet(e: Dictionary, base: String) -> Dictionary:
	for uid in e.sac:
		var it: Dictionary = items.get(uid, {})
		if str(it.get("base", "")) == base and "empilable" in it.get("tags", []):
			return it
	return {}


func _pile(e: Dictionary, mat_id: String, forme: String) -> Dictionary:
	for uid in e.sac:
		var it: Dictionary = items.get(uid, {})
		if it.get("type", "") == "materiau" and it.get("materiau", "") == mat_id and str(it.get("forme", "brut")) == forme:
			return it
	return {}


## Retire `quantite` d'une pile ; la pile vide disparaît du sac.
func _retirer_materiau(e: Dictionary, pile: Dictionary, quantite: int) -> void:
	pile.quantite = int(pile.quantite) - quantite
	if int(pile.quantite) <= 0:
		e.sac.erase(pile.uid)
		items.erase(pile.uid)


# ---------------------------------------------------------------- le camp : poser, coffres, dormir

func _tuile_libre_pour_poser(e: Dictionary, vers: Vector2i) -> bool:
	return lieu == "camp" and grille.dans(vers) and Grille.distance(e.pos, vers) == 1 and grille.contenu_de(vers).is_empty() \
		and grille.occupant(vers).is_empty() and not contenants.has(grille.idx(vers))


## Poser un meuble ou une station portative du sac sur une tuile adjacente (Construction cadrée).
func _poser(e: Dictionary, uid: String, vers: Vector2i, tick: int) -> bool:
	var it: Dictionary = items.get(uid, {})
	if not (uid in e.sac) or not it.get("type", "") in ["meuble", "station"]:
		return false
	if not _tuile_libre_pour_poser(e, vers):
		EventBus.emettre(&"journal", [&"journal.rien_a_poser", {}])
		return false
	var idx := grille.idx(vers)
	if it.type == "meuble":
		var m: Dictionary = GameData.entree("meubles", str(it.meuble))
		grille.poser_contenu(vers, "meuble" if bool(m.bloque_passage) else "meuble_sol")
		grille.meubles[idx] = str(it.meuble)
		if int(m.capacite_slots) > 0:
			contenants[idx] = []
	else:
		if monde != null and str(monde.claims.get(monde.cellule_de(vers), {}).get("role", "base")) == "champs" and str(it.station) in _ry().stations_lourdes:
			EventBus.emettre(&"journal", [&"journal.station_refusee", {}])
			return false
		grille.poser_contenu(vers, "station_fixe")
		grille.stations_fixes[idx] = str(it.station)
	e.sac.erase(uid)
	e["objets_poses"] = e.get("objets_poses", {})
	e.objets_poses[idx] = uid
	e.compteur = tick + int(regles.r.camp.poser_ticks)
	EventBus.emettre(&"journal", [&"journal.pose", {"nom": e.name_key, "objet": nom_objet(uid)}])
	EventBus.emettre(&"tile_changed", [vers])
	return true


## Un mur (1 unité de pierre taillée / planche / brique) ou une porte (1 planche) sur une tuile adjacente.
func _poser_mur(e: Dictionary, vers: Vector2i, porte: bool, tick: int) -> bool:
	if not _tuile_libre_pour_poser(e, vers):
		EventBus.emettre(&"journal", [&"journal.rien_a_poser", {}])
		return false
	var familles: Array = [str(regles.r.camp.porte_famille)] if porte else regles.r.camp.mur_familles
	var pile := {}
	for f in familles:
		pile = _pile_famille(e, GameData.config("material_families").get(str(f), {}))
		if not pile.is_empty():
			break
	if pile.is_empty():
		EventBus.emettre(&"journal", [&"journal.pas_de_materiau_mur", {}])
		return false
	var mat_id := str(pile.materiau)
	_retirer_materiau(e, pile, 1)
	grille.poser_contenu(vers, "porte" if porte else "mur_construit")
	grille.materiaux[grille.idx(vers)] = mat_id
	e.compteur = tick + int(regles.r.camp.poser_ticks)
	EventBus.emettre(&"journal", [&"journal.pose", {"nom": e.name_key, "objet": {"base": "tile_content.%s.name" % ("porte" if porte else "mur_construit")}}])
	EventBus.emettre(&"tile_changed", [vers])
	return true


## Démonter ce qui a été construit sur une tuile adjacente : meuble et station reviennent au sac.
func _demonter(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if not grille.dans(vers) or Grille.distance(e.pos, vers) != 1:
		return false
	var c := grille.contenu_de(vers)
	if not ("construit" in c.get("tags", [])):
		return false
	var idx := grille.idx(vers)
	if contenants.has(idx) and not contenants[idx].is_empty():
		_prendre(e, vers, tick)   # on vide le coffre d'abord
	var uid: String = str(e.get("objets_poses", {}).get(idx, ""))
	if not uid.is_empty() and items.has(uid):
		e.sac.append(uid)
		e.objets_poses.erase(idx)
		EventBus.emettre(&"journal", [&"journal.demonte", {"nom": e.name_key, "objet": nom_objet(uid)}])
	else:
		EventBus.emettre(&"journal", [&"journal.demonte", {"nom": e.name_key, "objet": {"base": str(c.name_key)}}])
	grille.contenu[idx] = 0
	grille.marquer(vers)
	grille.meubles.erase(idx)
	grille.stations_fixes.erase(idx)
	grille.materiaux.erase(idx)
	contenants.erase(idx)
	e.compteur = tick + int(regles.r.camp.poser_ticks)
	EventBus.emettre(&"tile_changed", [vers])
	return true


func _coffre_a(vers: Vector2i) -> Dictionary:
	if not grille.dans(vers) or not grille.meubles.has(grille.idx(vers)):
		return {}
	var m: Dictionary = GameData.entree("meubles", str(grille.meubles[grille.idx(vers)]))
	return m if int(m.capacite_slots) > 0 else {}


## Ranger un objet du sac dans un coffre adjacent (capacité du meuble).
func _ranger(e: Dictionary, uid: String, vers: Vector2i, tick: int) -> bool:
	var m := _coffre_a(vers)
	if m.is_empty() or Grille.distance(e.pos, vers) > 1 or not (uid in e.sac):
		return false
	var idx := grille.idx(vers)
	if contenants.get(idx, []).size() >= int(m.capacite_slots):
		EventBus.emettre(&"journal", [&"journal.coffre_plein", {}])
		return false
	e.sac.erase(uid)
	e.ratelier.erase(uid)
	if not contenants.has(idx):
		contenants[idx] = []
	contenants[idx].append(uid)
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.range", {"nom": e.name_key, "objet": nom_objet(uid)}])
	return true


## Prendre tout ce qu'un coffre adjacent contient.
func _prendre(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if not grille.dans(vers) or Grille.distance(e.pos, vers) > 1:
		return false
	var idx := grille.idx(vers)
	if not contenants.has(idx) or contenants[idx].is_empty():
		return false
	var n := 0
	for uid in contenants[idx]:
		if not (uid in e.sac):
			e.sac.append(uid)
			n += 1
	contenants[idx] = []
	if not grille.meubles.has(idx):   # un butin au sol disparaît ; un coffre reste
		grille.contenu[idx] = 0
		grille.marquer(vers)
		contenants.erase(idx)
		EventBus.emettre(&"tile_changed", [vers])
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.prend", {"nom": e.name_key, "n": n}])
	return true


## Dormir sur un lit adjacent (Cycle jour-nuit et sommeil, la partie sommeil) : le monde avance de
## dormir_ticks, puis vitaux pleins, buff Reposé (xp_mult) et +potentiel aux compétences les plus
## travaillées depuis le dernier repos ; le lit devient le point de respawn.
func _dormir(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	var lit: String = str(grille.meubles.get(grille.idx(vers), "")) if grille.dans(vers) else ""
	if lit.is_empty() or not bool(GameData.entree("meubles", str(lit)).dormir) or Grille.distance(e.pos, vers) > 1:
		EventBus.emettre(&"journal", [&"journal.pas_de_lit", {}])
		return false
	for x in vivants():
		if ennemis(e, x) and voit(e, x.pos):
			EventBus.emettre(&"journal", [&"journal.hostile_en_vue", {}])
			return false
	var cp: Dictionary = regles.r.camp
	var duree := int(cp.dormir_ticks)
	if lieu == "camp" and est_nuit():   # saut de nuit : dormir entre 21 h et 5 h avance au matin
		var jour := int(_cycle().get("ticks_par_jour", 24000))
		var reveil := int(float(_cycle().get("heure_reveil", 5)) / 24.0 * float(jour))
		var dans_jour := posmod(horloge_monde.ticks, jour)
		duree = (reveil - dans_jour) if dans_jour < reveil else (jour - dans_jour + reveil)
		EventBus.emettre(&"journal", [&"journal.dort_nuit", {"nom": e.name_key}])
	e.compteur = tick + duree
	e["lit"] = vers
	e["spawn"] = vers
	# Le monde avance pendant le sommeil (les êtres agissent ; le dormeur est vulnérable).
	var pas_max := 200
	var reste := duree
	while reste > 0 and pas_max > 0:
		var n := mini(reste, 100)
		horloge_monde.avancer(n)
		reste -= n
		pas_max -= 1
	if not e.vivant:
		return true
	e.sante = e.sante_max
	e.mana = e.mana_max
	e.endurance = e.endurance_max
	e.tick_endurance = horloge_monde.ticks
	e["repose_jusqua"] = horloge_monde.ticks + int(cp.repose_ticks)
	e["xp_mult"] = float(cp.repose_xp_mult)
	# +potentiel aux compétences consommées récemment (Potentiel : Reposé).
	var travail: Dictionary = e.get("xp_depuis_repos", {})
	var cles: Array = travail.keys()
	cles.sort_custom(func(a: String, b: String) -> bool: return int(travail[a]) > int(travail[b]))
	var cap := int(regles.r.progression.potentiel_max)
	var liste: Array[String] = []
	for cle in cles.slice(0, int(cp.repose_top)):
		e.potentiels[cle] = mini(cap, int(e.potentiels.get(cle, int(regles.r.progression.potentiel_defaut))) + int(cp.repose_potentiel))
		liste.append(_nom_competence(cle))
	e["xp_depuis_repos"] = {}
	EventBus.emettre(&"journal", [&"journal.dort", {"nom": e.name_key, "heures": duree / 1000, "potentiel": int(cp.repose_potentiel), "liste": ", ".join(liste) if not liste.is_empty() else "—"}])
	return true


## Voyage rapide (Carte du monde) : vers une cellule de terre déjà explorée ; le temps avance de
## ticks_par_cellule × distance ; le joueur arrive au point marchable du centre (ou à l'entrée du donjon).
func voyager(e: Dictionary, cell: Vector2i) -> bool:
	if lieu != "camp" or monde == null or e.controle != "joueur":
		return false
	if not monde.surface.terre_a(cell) or not monde.cellule_exploree(cell):
		EventBus.emettre(&"journal", [&"journal.voyage_impossible", {}])
		return false
	var d := maxi(absi(cell.x - monde.cellule_de(e.pos).x), absi(cell.y - monde.cellule_de(e.pos).y))
	var cout := d * int(GameData.config("planete").voyage.ticks_par_cellule)
	var ec := monde.cellule(cell)
	var ou: Vector2i = monde.pos_monde(cell, ec.entree_donjon + Vector2i(0, 1)) if bool(ec.get("a_donjon", false)) else monde.point_marchable(cell)
	grille.liberer(e.pos)
	e.pos = ou
	_verifier_fenetre(e)
	if not grille.occupant(ou).is_empty() or grille.bloque_passage(ou):
		ou = monde.point_marchable(cell)
		e.pos = ou
	grille.placer(e.id, ou)
	e.compteur = horloge_monde.ticks + cout
	horloge_monde.avancer(cout)
	maj_vision()
	EventBus.emettre(&"journal", [&"journal.voyage", {"nom": e.name_key, "x": cell.x, "y": cell.y, "ticks": cout}])
	return true


# ---------------------------------------------------------------- dialogue (E.23) et commerce (Prix suggéré)

## La réplique d'ambiance d'un PNJ pour le joueur : tirage pondéré parmi les gabarits dont les
## conditions matchent, anti-répétition sur les 3 dernières.
func replique(pnj: Dictionary, j: Dictionary) -> String:
	var rel := int(pnj.get("social", {}).get("relations", {}).get(j.id, 0))
	var ph := phase()
	var met := meteo(monde.cellule_de(pnj.pos)) if (monde != null and lieu == "camp") else "clair"
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
		if did in recentes:
			continue
		candidats.append(d)
		total += float(d.get("poids", 1))
	if candidats.is_empty():
		return "dialogue.salut.text"
	var t := des.reel() * total
	for d in candidats:
		t -= float(d.get("poids", 1))
		if t <= 0.0:
			recentes.append(d.id)
			while recentes.size() > 3:
				recentes.pop_front()
			pnj["dernieres_repliques"] = recentes
			return str(d.text_key)
	return str(candidats.back().text_key)


## Parler : la réplique, +1 de relation une fois par jour et par PNJ, +1 sur un jet de Charisme.
func _parler(e: Dictionary, pnj_id: String, tick: int) -> bool:
	var pnj: Dictionary = entites.get(pnj_id, {})
	if pnj.is_empty() or not pnj.vivant or not ("civil" in pnj.get("tags", [])) or Grille.distance(e.pos, pnj.pos) > 2:
		return false
	var texte := replique(pnj, e)
	EventBus.emettre(&"journal", [&"journal.parle", {"nom": pnj.name_key, "texte": texte}])
	var jour := int(tick / int(_cycle().get("ticks_par_jour", 24000)))
	if int(pnj.get("dernier_parler_jour", -1)) != jour:
		pnj["dernier_parler_jour"] = jour
		var cm: Dictionary = regles.r.commerce
		var gain := int(cm.parler_relation)
		if des.jet("1d20") + int(e.stats_eff.charisme) / 4 >= int(cm.parler_charisme_dd):
			gain += int(cm.parler_bonus)
		pnj.social.relations[e.id] = clampi(int(pnj.social.relations.get(e.id, 0)) + gain, -100, 100)
		EventBus.emettre(&"journal", [&"journal.relation", {"nom": pnj.name_key, "n": int(pnj.social.relations[e.id])}])
	_rumeur(pnj, e, tick)
	e.compteur = tick + int(regles.r.actions.objet)
	return true


## Le prix suggéré d'un objet face à un PNJ, avec le détail du calcul (Prix suggéré).
func prix_suggere(uid: String, pnj: Dictionary, acheteur: Dictionary) -> Dictionary:
	var cm: Dictionary = regles.r.commerce
	var it: Dictionary = items.get(uid, {})
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
	var prix := maxi(1, roundi(base * float(cm.marge_artisanat) * qualite * rarete * rep))
	return {"prix": prix, "base": snappedf(base, 0.1), "marge": float(cm.marge_artisanat), "qualite": snappedf(qualite, 0.01), "rarete": snappedf(rarete, 0.01), "rep": snappedf(rep, 0.01),
		"achat": maxi(1, roundi(float(prix) * float(cm.achat_ratio)))}


## Acheter un objet du stock d'un marchand.
func _acheter(e: Dictionary, pnj_id: String, uid: String, tick: int) -> bool:
	var pnj: Dictionary = entites.get(pnj_id, {})
	if pnj.is_empty() or not (uid in pnj.get("stock", [])) or Grille.distance(e.pos, pnj.pos) > 2:
		return false
	var p := prix_suggere(uid, pnj, e)
	if int(e.or) < int(p.prix):
		EventBus.emettre(&"journal", [&"journal.pas_assez_or", {}])
		return false
	e.or = int(e.or) - int(p.prix)
	pnj.or = int(pnj.or) + int(p.prix)
	pnj.stock.erase(uid)
	e.sac.append(uid)
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.achete", {"nom": e.name_key, "objet": nom_objet(uid), "n": int(p.prix)}])
	EventBus.emettre(&"item_sold", [uid, pnj.id, int(p.prix)])
	return true


## Vendre un objet du sac à un marchand : il paie achat_ratio du prix suggéré, s'il a l'or.
func _vendre(e: Dictionary, pnj_id: String, uid: String, tick: int) -> bool:
	var pnj: Dictionary = entites.get(pnj_id, {})
	if pnj.is_empty() or not (uid in e.sac) or Grille.distance(e.pos, pnj.pos) > 2 or not ("commerce_possible" in pnj.get("tags", [])):
		return false
	var p := prix_suggere(uid, pnj, e)
	if int(pnj.or) < int(p.achat):
		EventBus.emettre(&"journal", [&"journal.marchand_a_sec", {"nom": pnj.name_key}])
		return false
	pnj.or = int(pnj.or) - int(p.achat)
	e.or = int(e.or) + int(p.achat)
	e.sac.erase(uid)
	e.ratelier.erase(uid)
	pnj.stock.append(uid)
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.vend", {"nom": e.name_key, "objet": nom_objet(uid), "n": int(p.achat)}])
	EventBus.emettre(&"item_sold", [uid, e.id, int(p.achat)])
	return true


# ---------------------------------------------------------------- territoire : claims, rôles, résidents, semaine (étape 10)

func _ry() -> Dictionary:
	return regles.r.royaume


## Revendiquer une cellule contiguë explorée (Expansion territoriale) : 50 or × cellules possédées.
func revendiquer(e: Dictionary, cell: Vector2i) -> bool:
	if monde == null or e.controle != "joueur":
		return false
	if not monde.revendicable(cell, horloge_monde.ticks):
		EventBus.emettre(&"journal", [&"journal.claim_refuse", {}])
		return false
	var cout := int(_ry().claim_cout_par_cellule) * monde.claims.size()
	if int(e.or) < cout:
		EventBus.emettre(&"journal", [&"journal.claim_or", {"or": cout}])
		return false
	e.or = int(e.or) - cout
	monde.claims[cell] = {"role": "base"}
	if not monde.decouvert.has(cell):
		monde.decouvert[cell] = {}
	EventBus.emettre(&"cell_claimed", [cell])
	EventBus.emettre(&"journal", [&"journal.claim", {"x": cell.x, "y": cell.y, "or": cout, "n": monde.claims.size()}])
	_verifier_royaume(e)
	return true


func changer_role(cell: Vector2i, role: String) -> bool:
	if monde == null or not monde.claims.has(cell) or not (role in _ry().roles):
		return false
	monde.claims[cell].role = role
	EventBus.emettre(&"cell_role_changed", [cell, role])
	EventBus.emettre(&"journal", [&"journal.role", {"x": cell.x, "y": cell.y, "role": "role." + role}])
	return true


func residents() -> Array:
	var res: Array = []
	for x in entites.values():
		if x.vivant and x.has("assignation"):
			res.append(x)
	return res


## Le facteur d'humeur d'un résident (Population et exploitation) : humeur/100 × 1,5, borné [0,4 ; 1,2].
func facteur_humeur(x: Dictionary) -> float:
	var b: Array = _ry().facteur_humeur_bornes
	return clampf(float(x.get("humeur", _ry().humeur_base)) / 100.0 * float(_ry().facteur_humeur_mult), float(b[0]), float(b[1]))


## Assigner un compagnon ou un PNJ ami à une fonction, sur la cellule où il se trouve.
func _assigner(e: Dictionary, pnj_id: String, fonction: String, tick: int) -> bool:
	var x: Dictionary = entites.get(pnj_id, {})
	if x.is_empty() or monde == null or not GameData.catalogues.functions.has(fonction):
		return false
	var cell := monde.cellule_de(x.pos)
	if not monde.claims.has(cell) or (str(x.get("maitre", "")) != e.id and x.camp != "joueur"):
		return false
	x.erase("maitre")
	x.camp = "joueur"
	x.ai_profile = "civil" if fonction != "garde" else "garde"
	x["fonction"] = fonction
	x["role"] = "resident"
	x["assignation"] = {"fonction": fonction, "cellule": cell}
	x["poste"] = x.pos
	x.ancre = x.pos
	x["place"] = x.pos
	x["humeur"] = int(_ry().humeur_base)
	# Logement : un lit libre de la cellule.
	x.erase("lit")
	for gi in grille.meubles.keys():
		var p := grille.pos_de(int(gi))
		if monde.cellule_de(p) == cell and bool(GameData.entree("meubles", str(grille.meubles[gi])).dormir):
			var pris := false
			for autre in residents():
				if autre.get("lit", Vector2i(-1, -1)) == p:
					pris = true
			if not pris:
				x["lit"] = p
				break
	if not x.has("lit"):
		x.humeur = int(x.humeur) + int(_ry().sans_logement)
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.assigne", {"nom": x.name_key, "fonction": GameData.entree("functions", fonction).name_key}])
	_verifier_royaume(e)
	return true


func desassigner(e: Dictionary, pnj_id: String) -> bool:
	var x: Dictionary = entites.get(pnj_id, {})
	if x.is_empty() or not x.has("assignation"):
		return false
	x.erase("assignation")
	_devenir_compagnon(e, x)
	EventBus.emettre(&"journal", [&"journal.desassigne", {"nom": x.name_key}])
	return true


func _verifier_royaume(e: Dictionary) -> void:
	var seuil: Dictionary = _ry().seuil_royaume
	if not bool(territoire.royaume) and monde != null and monde.claims.size() >= int(seuil.cellules) and residents().size() >= int(seuil.pnj):
		territoire.royaume = true
		EventBus.emettre(&"journal", [&"journal.royaume", {}])


## La production hebdomadaire d'un résident (Abstraction hors-site) : rendement × heures × humeur.
func production_de(x: Dictionary) -> Dictionary:
	var f: Dictionary = GameData.catalogues.functions.get(str(x.assignation.fonction), {})
	var prod = f.get("produit")
	if prod == null:
		return {}
	var niveau := regles.niveau(x.competences_eff, str(f.get("skill", ""))) if not str(f.get("skill", "")).is_empty() else 0
	var rendement := float(f.get("rendement_base", 0.02)) * (1.0 + float(niveau) / 10.0)
	var mult := float(territoire.get("productivite", 1.0))
	var q := rendement * float(_ry().heures_semaine) * facteur_humeur(x) * mult
	if prod.has("or"):
		return {"or": int(round(q * float(prod.or)))}
	return {"base": str(prod.get("item", prod.get("materiau", ""))), "forme": str(prod.get("forme", "")), "n": int(floor(q * float(prod.get("par_unite", 1.0))))}


## Le passage hebdomadaire du territoire : production, entretien, dette et ses paliers, taxe de guilde, rapport.
func _semaine_territoire(e: Dictionary) -> void:
	if monde == null or monde.claims.is_empty():
		return
	var ry := _ry()
	var prod_txt: Array[String] = []
	var or_prod := 0
	for x in residents():
		var pr := production_de(x)
		if pr.is_empty():
			continue
		if pr.has("or"):
			or_prod += int(pr.or)
			prod_txt.append("%d or" % int(pr.or))
		elif int(pr.n) > 0:
			var cle: String = pr.base + ("|" + pr.forme if not str(pr.forme).is_empty() else "")
			territoire.stocks[cle] = int(territoire.stocks.get(cle, 0)) + int(pr.n)
			prod_txt.append("%s ×%d" % [pr.base, int(pr.n)])
	territoire.tresor = int(territoire.tresor) + or_prod
	# Ressources naturelles : la régénération efface le bâti de la cellule.
	for cell in monde.claims.keys():
		if str(monde.claims[cell].role) == "ressources":
			monde.modifications.erase(cell)
	var entretien := int(ry.entretien_pnj) * residents().size() + int(ry.entretien_structure) * _structures_speciales()
	var du := entretien + int(territoire.dette)
	if int(territoire.tresor) >= du:
		territoire.tresor = int(territoire.tresor) - du
		territoire.dette = 0
		territoire.semaines_dette = 0
		territoire["productivite"] = 1.0
	else:
		territoire.dette = du - int(territoire.tresor)
		territoire.tresor = 0
		territoire.semaines_dette = int(territoire.semaines_dette) + 1
	var pal: Dictionary = ry.dette_paliers
	if int(territoire.semaines_dette) >= int(pal.humeur[0]):
		for x in residents():
			x.humeur = int(x.get("humeur", ry.humeur_base)) + int(pal.humeur[1])
		EventBus.emettre(&"journal", [&"journal.dette_palier", {"texte": "dette.humeur"}])
	if int(territoire.semaines_dette) >= int(pal.productivite[0]):
		territoire["productivite"] = float(pal.productivite[1])
		EventBus.emettre(&"journal", [&"journal.dette_palier", {"texte": "dette.productivite"}])
	if int(territoire.semaines_dette) >= int(pal.depart[0]) and not residents().is_empty():
		var moins_fidele: Dictionary = residents()[0]
		for x in residents():
			if relation_de(x, e) < relation_de(moins_fidele, e):
				moins_fidele = x
		moins_fidele.erase("assignation")
		moins_fidele.camp = "civil"
		EventBus.emettre(&"journal", [&"journal.dette_palier", {"texte": "dette.depart"}])
	if int(territoire.semaines_dette) == 0:
		for x in residents():
			x.humeur = int(ry.humeur_base) + (int(ry.sans_logement) if not x.has("lit") else 0)
	# Taxe de guilde sur les gains de quêtes de la semaine (Entretien et taxes).
	var gains := int(territoire.get("gains_quetes", 0))
	if gains > 0:
		var rang := int(e.get("guildes", {}).get("guerriers", {}).get("rang", 0))
		var taxe := int(round(float(gains) * float(ry.taxe_guilde) * (1.0 + float(ry.taxe_rang) * rang)))
		e.or = maxi(0, int(e.or) - taxe)
		territoire.gains_quetes = 0
		if taxe > 0:
			EventBus.emettre(&"journal", [&"journal.taxe_guilde", {"n": taxe}])
	var rapport := {"prod": " · ".join(prod_txt) if not prod_txt.is_empty() else "—", "entretien": entretien, "tresor": int(territoire.tresor), "dette": int(territoire.dette)}
	territoire.rapports.append(rapport)
	while territoire.rapports.size() > 8:
		territoire.rapports.pop_front()
	EventBus.emettre(&"journal", [&"journal.rapport_semaine", rapport])


func _structures_speciales() -> int:
	var n := 0
	if monde == null:
		return 0
	for gi in grille.stations_fixes.keys():
		if monde.claims.has(monde.cellule_de(grille.pos_de(int(gi)))):
			n += 1
	return n


## Le prévisionnel hebdomadaire (revenus en or − entretien).
func previsionnel() -> int:
	var revenus := 0
	for x in residents():
		var pr := production_de(x)
		if pr.has("or"):
			revenus += int(pr.or)
	return revenus - (int(_ry().entretien_pnj) * residents().size() + int(_ry().entretien_structure) * _structures_speciales())


func deposer(e: Dictionary, n: int) -> bool:
	if int(e.or) < n:
		return false
	e.or = int(e.or) - n
	territoire.tresor = int(territoire.tresor) + n
	EventBus.emettre(&"journal", [&"journal.depot", {"n": n, "tresor": int(territoire.tresor)}])
	return true


func retirer(e: Dictionary, n: int) -> bool:
	n = mini(n, int(territoire.tresor))
	if n <= 0:
		EventBus.emettre(&"journal", [&"journal.tresor_vide", {}])
		return false
	territoire.tresor = int(territoire.tresor) - n
	e.or = int(e.or) + n
	EventBus.emettre(&"journal", [&"journal.retrait", {"n": n, "tresor": int(territoire.tresor)}])
	return true


## Retirer un stock du territoire dans le sac (matériaux et consommables).
func retirer_stock(e: Dictionary, cle: String) -> bool:
	var n := int(territoire.stocks.get(cle, 0))
	if n <= 0:
		return false
	var parts: PackedStringArray = cle.split("|")
	if parts.size() > 1:
		_donner_materiau(e, parts[0], n, parts[1])
	else:
		for k in n:
			var o := generer_objet(parts[0], 1, {}, "commun", 0)
			if not o.is_empty():
				donner(e, o.uid)
	territoire.stocks.erase(cle)
	EventBus.emettre(&"journal", [&"journal.stock_retire", {"nom": parts[0], "n": n}])
	return true


# ---------------------------------------------------------------- compagnons, apprivoisement, âge

## Places d'escorte (Compagnons) : 1 + Charisme/5 + Leadership/10.
func places_escorte(e: Dictionary) -> int:
	var c: Dictionary = regles.r.compagnons
	return int(c.places_base) + int(e.stats_eff.charisme) / int(c.par_charisme) + regles.niveau(e.competences_eff, "leadership") / int(c.par_leadership)


func compagnons_de(e: Dictionary) -> Array:
	var res: Array = []
	for x in vivants():
		if str(x.get("maitre", "")) == e.id:
			res.append(x)
	return res


## Faire d'un être un compagnon du joueur.
func _devenir_compagnon(e: Dictionary, x: Dictionary) -> void:
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
func _recruter(e: Dictionary, pnj_id: String, tick: int) -> bool:
	var pnj: Dictionary = entites.get(pnj_id, {})
	if pnj.is_empty() or not pnj.vivant or pnj.has("maitre") or Grille.distance(e.pos, pnj.pos) > 2:
		return false
	var def: Dictionary = GameData.catalogues.creatures.get(str(pnj.def), {})
	var rc: Dictionary = def.get("recruitable", {"method": "jamais"})
	var ok := false
	if str(rc.get("method", "jamais")) == "relation" and relation_de(pnj, e) >= int(rc.get("threshold", 60)):
		ok = true
	if bool(pnj.get("recrutable_hors_condition", false)):
		ok = true
	if not ok:
		EventBus.emettre(&"journal", [&"journal.pas_recrutable", {"nom": pnj.name_key}])
		return false
	if compagnons_de(e).size() >= places_escorte(e):
		EventBus.emettre(&"journal", [&"journal.pas_de_place", {}])
		return false
	_devenir_compagnon(e, pnj)
	EventBus.emettre(&"journal", [&"journal.recrute", {"nom": pnj.name_key, "places": places_escorte(e)}])
	return true


## Un ordre à un compagnon : sans coût de ticks (Compagnons).
func ordonner(e: Dictionary, id: String, ordre: String) -> bool:
	var x: Dictionary = entites.get(id, {})
	if x.is_empty() or str(x.get("maitre", "")) != e.id or not (ordre in ["suivre", "attendre"]):
		return false
	x.ordre = ordre
	if ordre == "attendre":
		x.ancre = x.pos
	EventBus.emettre(&"journal", [&"journal.ordre", {"nom": x.name_key, "ordre": "ordre." + ordre}])
	return true


## Apprivoiser une bête adjacente (Apprivoisement et recrutement) : le jet universel.
func _apprivoiser(e: Dictionary, cible_id: String, tick: int) -> bool:
	var c: Dictionary = entites.get(cible_id, {})
	if c.is_empty() or not c.vivant or not ("bete" in c.get("tags", [])) or Grille.distance(e.pos, c.pos) > 1 or c.has("maitre"):
		EventBus.emettre(&"journal", [&"journal.pas_de_bete", {}])
		return false
	var def: Dictionary = GameData.catalogues.creatures.get(str(c.def), {})
	if str(def.get("recruitable", {}).get("method", "dressage")) == "jamais":
		return false
	var jour := tick / int(_cycle().get("ticks_par_jour", 24000))
	if int(c.get("dernier_apprivoisement", -1)) == jour:
		EventBus.emettre(&"journal", [&"journal.deja_tente", {"nom": c.name_key}])
		return false
	c["dernier_apprivoisement"] = jour
	var ap: Dictionary = regles.r.apprivoisement
	var jet := des.jet("1d20") + regles.niveau(e.competences_eff, "dressage") / 2 + int(e.stats_eff.charisme) / 4
	var pv := float(c.sante) / float(c.sante_max)
	if pv < 0.25:
		jet += int(ap.bonus_25)
	elif pv < 0.5:
		jet += int(ap.bonus_50)
	var niveau := int(round(progression.niveaux_derives(c).combat))
	var dd := int(ap.dd_base) + niveau / 2
	gagner_xp(e, "dressage", 5)
	e.compteur = tick + int(regles.r.actions.objet)
	if jet >= dd:
		if compagnons_de(e).size() >= places_escorte(e):
			EventBus.emettre(&"journal", [&"journal.pas_de_place", {}])
			return false
		_devenir_compagnon(e, c)
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
func _mort_compagnon(x: Dictionary) -> void:
	var maitre: Dictionary = entites.get(str(x.get("maitre", "")), {})
	if maitre.is_empty():
		return
	var ame := generer_objet("ame", 1, {}, "commun", 0)
	if ame.is_empty():
		return
	ame["compagnon"] = x.id
	ame["name_key"] = x.name_key
	maitre.sac.append(ame.uid)
	x["corps_pos"] = x.pos
	EventBus.emettre(&"journal", [&"journal.compagnon_mort", {"nom": x.name_key}])


## Ressusciter un compagnon : l'âme dans le sac, un autel domestique adjacent, l'or ; il revient affaibli.
func _ressusciter(e: Dictionary, uid_ame: String, tick: int) -> bool:
	var ame: Dictionary = items.get(uid_ame, {})
	if ame.is_empty() or not (uid_ame in e.sac) or not ame.has("compagnon"):
		return false
	var autel := false
	for d in Grille.DIRS:
		var t: Vector2i = e.pos + d
		if grille.dans(t) and str(grille.meubles.get(grille.idx(t), "")) == "autel_domestique":
			autel = true
	if not autel:
		EventBus.emettre(&"journal", [&"journal.pas_d_autel", {}])
		return false
	var x: Dictionary = entites.get(str(ame.compagnon), {})
	if x.is_empty():
		return false
	var c: Dictionary = regles.r.compagnons
	var niveau := maxi(1, int(round(progression.niveaux_derives(x).combat)))
	var cout := int(float(c.or_par_niveau) * niveau * float(c.autel_mult))
	if int(e.or) < cout:
		EventBus.emettre(&"journal", [&"journal.pas_assez_or", {}])
		return false
	e.or = int(e.or) - cout
	e.sac.erase(uid_ame)
	items.erase(uid_ame)
	x.vivant = true
	x.sante = maxi(1, int(x.sante_max) / 2)
	x.statuts = []
	x.action_en_cours = {}
	var ou: Vector2i = e.pos
	for d in Grille.DIRS:
		var t: Vector2i = e.pos + d
		if grille.dans(t) and not grille.bloque_passage(t) and grille.occupant(t).is_empty():
			ou = t
			break
	x.pos = ou
	grille.placer(x.id, ou)
	x.compteur = tick
	x.horloge = "monde"
	if not (x.id in ordre):
		ordre.append(x.id)
	appliquer_statut(x, "affaibli", int(c.affaibli_ticks), e.id)
	x["affaibli_mult"] = float(c.affaibli_mult)
	Etres.recalculer(x, items, affixes_defs, regles)
	EventBus.emettre(&"journal", [&"journal.ressuscite", {"nom": x.name_key, "or": cout}])
	return true


## L'âge (Âge des PNJ) : le passage hebdomadaire fait vieillir ; au-delà de l'espérance, une chance
## croissante de mourir ; les âgés perdent des stats physiques par tranche.
func _vieillir_semaine(tick: int) -> void:
	var ag: Dictionary = regles.r.age
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "age", tick])
	for x in entites.values():
		if not x.has("age") or not x.vivant:
			continue
		x.age = float(x.age) + 7.0 / float(ag.jours_par_an)
		if float(x.age) > float(x.get("lifespan", 80.0)):
			var ecart := float(x.age) - float(x.lifespan)
			if rng.randf() < float(ag.chance_mort_par_an) * ecart:
				x.vivant = false
				grille.liberer(x.pos)
				EventBus.emettre(&"journal", [&"journal.mort_vieillesse", {"nom": x.name_key}])
				continue
		var tranches := int(maxf(0.0, float(x.age) - float(ag.age)) / float(ag.tranche))
		x["age_mult"] = maxf(0.3, 1.0 - float(ag.malus_par_tranche) * tranches)


func categorie_age(x: Dictionary) -> String:
	var ag: Dictionary = regles.r.age
	var a := float(x.get("age", 30.0))
	return "jeune" if a < float(ag.adulte) else ("age" if a >= float(ag.age) else "adulte")


# ---------------------------------------------------------------- quêtes et guildes (Gabarit de quête)

## Les quêtes qu'un donneur offre cette semaine (générées depuis les gabarits, jusqu'à quetes_par_semaine).
func quetes_offertes(pnj: Dictionary, e: Dictionary) -> Array:
	if not ("quetes" in pnj.get("tags", [])):
		return []
	# Refusées sous −20 : la relation du donneur, ou la réputation de son village (le collectif compte).
	if mini(relation_de(pnj, e), int(e.get("reputations", {}).get(str(pnj.get("village", "")), 0))) < int(regles.r.reputation.quetes_seuil):
		return []
	var semaine := horloge_monde.ticks / int(GameData.config("planete").corruption.ticks_par_semaine)
	if int(pnj.get("quetes_semaine", -1)) != semaine:
		pnj["quetes_semaine"] = semaine
		pnj["quetes"] = []
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([graine, "quetes", pnj.id, semaine])
		var ids: Array = GameData.catalogues.quest_templates.keys()
		ids.sort()
		for k in int(regles.r.guildes.quetes_par_semaine):
			var gid: String = ids[rng.randi_range(0, ids.size() - 1)]
			var g: Dictionary = GameData.catalogues.quest_templates[gid]
			var count := rng.randi_range(int(g.count_range[0]), int(g.count_range[1]))
			var niveau := maxi(1, int(round(monde.corruption_de(monde.cellule_de(pnj.pos)) / 20.0))) if monde != null else 1
			pnj.quetes.append({"uid": "q_%s_%d_%d" % [pnj.id, semaine, k], "gabarit": gid, "guild": str(g.guild), "pattern": str(g.pattern), "selector": g.target_selector,
				"count": count, "fait": 0, "niveau": niveau, "or": int(g.reward.gold_per_target_level) * niveau * count, "xp": int(g.reward.guild_xp) * count,
				"text_key": str(g.text_key), "donneur": pnj.id, "village": str(pnj.get("village", "")), "cellule": monde.cellule_de(pnj.pos) if monde != null else Vector2i.ZERO, "etat": "offerte"})
	return pnj.quetes


func _accepter_quete(e: Dictionary, pnj_id: String, uid: String, tick: int) -> bool:
	var pnj: Dictionary = entites.get(pnj_id, {})
	if pnj.is_empty():
		return false
	for q in quetes_offertes(pnj, e):
		if q.uid == uid and q.etat == "offerte":
			q.etat = "en_cours"
			if not e.has("quetes"):
				e["quetes"] = []
			e.quetes.append(q)
			EventBus.emettre(&"journal", [&"journal.quete_acceptee", {"texte": q.text_key}])
			e.compteur = tick + int(regles.r.actions.objet)
			return true
	return false


## Une créature tuée par le joueur : les quêtes « tuer » dont le sélecteur matche avancent.
func _quetes_sur_mort(cible: Dictionary, tueur: String) -> void:
	var e: Dictionary = entites.get(tueur, {})
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


## Un donjon vidé : les quêtes « donjon » de cette cellule sont terminées.
func _quetes_sur_donjon(cellule: Vector2i, joueur: String) -> void:
	var e: Dictionary = entites.get(joueur, {})
	for q in e.get("quetes", []):
		if q.etat == "en_cours" and q.pattern == "donjon" and Vector2i(q.cellule).distance_to(cellule) <= 6.0:
			q.fait = int(q.count)
			q.etat = "terminee"


## Rendre une quête terminée à son donneur : or, XP de guilde (rangs), relation.
func _rendre_quete(e: Dictionary, pnj_id: String, uid: String, tick: int) -> bool:
	var pnj: Dictionary = entites.get(pnj_id, {})
	if pnj.is_empty():
		return false
	for q in e.get("quetes", []):
		if q.uid == uid and q.etat == "terminee" and q.donneur == pnj_id:
			q.etat = "rendue"
			e.or = int(e.or) + int(q.or)
			territoire.gains_quetes = int(territoire.get("gains_quetes", 0)) + int(q.or)
			if not e.has("guildes"):
				e["guildes"] = {}
			var g: Dictionary = e.guildes.get(q.guild, {"xp": 0, "rang": 0})
			g.xp = int(g.xp) + int(q.xp)
			var seuils: Array = regles.r.guildes.seuils_xp
			var rang := 0
			for k in seuils.size():
				if int(g.xp) >= int(seuils[k]):
					rang = k
			if rang > int(g.rang):
				EventBus.emettre(&"journal", [&"journal.rang_guilde", {"guilde": "guilde.%s.name" % q.guild, "rang": "rang." + str(regles.r.guildes.rangs[rang])}])
			g.rang = rang
			e.guildes[q.guild] = g
			reputation(e, pnj, "quete")
			EventBus.emettre(&"journal", [&"journal.quete_rendue", {"or": int(q.or), "xp": int(q.xp), "guilde": "guilde.%s.name" % q.guild}])
			EventBus.emettre(&"quest_completed", [q])
			e.compteur = tick + int(regles.r.actions.objet)
			return true
	return false


# ---------------------------------------------------------------- cycle jour-nuit (E.21) et météo (E.28)

func _cycle() -> Dictionary:
	return GameData.config("planete").get("cycle", {})


## L'heure du monde (0-24, décimale) et sa phase.
func heure(tick: int = -1) -> float:
	var t := horloge_monde.ticks if tick < 0 else tick
	var jour := int(_cycle().get("ticks_par_jour", 24000))
	return float(posmod(t, jour)) / float(jour) * 24.0


func phase(tick: int = -1) -> String:
	var h := heure(tick)
	var c := _cycle()
	if h >= float(c.aube[0]) and h < float(c.aube[1]):
		return "aube"
	if h >= float(c.jour[0]) and h < float(c.jour[1]):
		return "jour"
	if h >= float(c.crepuscule[0]) and h < float(c.crepuscule[1]):
		return "crepuscule"
	return "nuit"


func est_nuit(tick: int = -1) -> bool:
	return phase(tick) == "nuit"


## La saison (Décision — Saisons activées à l'étape 10) : exposée, inerte.
func saison() -> int:
	return 0


## La météo d'une cellule à un instant : une fonction pure du bruit spatial lent, du temps, de la
## température et de l'humidité locales (Météo). Retourne l'id d'un état de data/weather_states/.
func meteo(cell: Vector2i, tick: int = -1) -> String:
	if monde == null:
		return "clair"
	var m: Dictionary = GameData.config("planete").get("meteo", {})
	var t := horloge_monde.ticks if tick < 0 else tick
	var n: FastNoiseLite = monde.surface.bruits.get("meteo")
	if n == null:
		n = FastNoiseLite.new()
		n.seed = monde.surface.graine + int(m.get("seed_offset", 77))
		n.frequency = float(m.get("frequence_spatiale", 0.0003))
		n.fractal_octaves = 2
		monde.surface.bruits["meteo"] = n
	var taille: int = monde.taille
	var cx := float(cell.x * taille)
	var cy := float(cell.y * taille)
	var front := float(t) / float(m.get("ticks_par_front", 24000)) * 900.0   # le front se déplace : le bruit défile
	var p := clampf((n.get_noise_2d(cx + front, cy - front * 0.4) + 1.0) * 0.5, 0.0, 1.0)
	var temp := monde.surface.valeur("temperature", int(cx) + taille / 2, int(cy) + taille / 2)
	var hum := monde.surface.valeur("humidite", int(cx) + taille / 2, int(cy) + taille / 2)
	var s: Dictionary = m.seuils
	if p >= float(s.extreme):
		return "blizzard" if temp < float(m.neige_temp) else "tempete"
	if p >= float(s.violent):
		return "neige" if temp < float(m.neige_temp) else "orage"
	if p >= float(s.precipitation):
		return "neige" if temp < float(m.neige_temp) else "pluie"
	if p >= float(s.couvert):
		return "brouillard" if hum >= float(m.brouillard_humidite) else "nuageux"
	if temp >= float(m.canicule_temp) and p < 0.2:
		return "canicule"
	if p < 0.12:
		return "vent_fort"
	return "clair"


## Température ressentie d'un être en surface (°C) et son écart à la zone de confort.
func temperature_ressentie(e: Dictionary) -> Dictionary:
	var m: Dictionary = GameData.config("planete").get("meteo", {})
	if monde == null or lieu != "camp":
		return {"temp": 18.0, "ecart": 0.0, "meteo": "clair"}
	var cell := monde.cellule_de(e.pos)
	var temp01 := monde.surface.valeur("temperature", e.pos.x, e.pos.y)
	var temp := lerpf(float(m.temp_min), float(m.temp_max), temp01)
	var etat_id := meteo(cell)
	var etat: Dictionary = GameData.catalogues.weather_states.get(etat_id, {})
	temp += float(etat.get("temp_mod", 0))
	if est_nuit():
		temp += float(_cycle().get("mod_nuit", -8))
	var alt: float = float(monde.surface.tectonique_a(e.pos.x, e.pos.y).altitude)
	var ma: Dictionary = m.mod_altitude
	if alt >= 0.85:
		temp += float(ma.haute_montagne)
	elif alt >= 0.70:
		temp += float(ma.montagne)
	elif alt >= 0.55:
		temp += float(ma.colline)
	var confort: Array = m.confort
	var ecart := 0.0
	if temp < float(confort[0]):
		# L'isolation de l'équipement compense le froid (Application des stats de matériau).
		var iso := 0.0
		for slot in e.equipement.keys():
			var it: Dictionary = items.get(e.equipement[slot], {})
			iso += float(it.get("stats", {}).get("isolation", 0.0))
		temp += iso / float(m.isolation_div)
		if temp < float(confort[0]):
			ecart = temp - float(confort[0])
	elif temp > float(confort[1]):
		ecart = temp - float(confort[1])
	return {"temp": temp, "ecart": ecart, "meteo": etat_id}


## Les effets de la météo et du froid/chaud sur le joueur (phase 2, avec la faim).
var _meteo_annoncee: String = ""
var _meteo_courante: String = ""
func _tiquer_meteo(tick: int) -> void:
	if monde == null or lieu != "camp":
		return
	var m: Dictionary = GameData.config("planete").get("meteo", {})
	for e in vivants():
		if e.controle != "joueur":
			continue
		var cell := monde.cellule_de(e.pos)
		var etat := meteo(cell, tick)
		if etat != _meteo_courante:
			_meteo_courante = etat
			EventBus.emettre(&"journal", [&"journal.meteo", {"meteo": GameData.catalogues.weather_states[etat].name_key}])
		var demain := meteo(cell, tick + int(_cycle().get("ticks_par_jour", 24000)))
		if demain != _meteo_annoncee and demain in ["tempete", "blizzard", "canicule"]:
			_meteo_annoncee = demain
			EventBus.emettre(&"journal", [&"journal.meteo_annonce", {"meteo": GameData.catalogues.weather_states[demain].name_key}])
		var tr_ := temperature_ressentie(e)
		e["temp_ressentie"] = tr_.temp
		e["ecart_confort"] = tr_.ecart
		if absf(float(tr_.ecart)) >= float(m.degats_hors_confort_ecart):
			var per := int(m.degats_periode)
			if tick / per != int(e.get("meteo_tick", 0)) / per:
				e.sante = maxi(1, int(e.sante) - 1)
				EventBus.emettre(&"journal", [&"journal.froid" if float(tr_.ecart) < 0.0 else &"journal.chaud", {"nom": e.name_key}])
		e["meteo_tick"] = tick


# ---------------------------------------------------------------- sauvegarde (Sauvegarde, E.10)

## Sauvegarde la partie (surface seulement : au camp ou à pied). Retourne vrai si tout est écrit.
func sauvegarder(nom: String = "monde") -> bool:
	if lieu != "camp" or monde == null:
		return false
	monde.capturer(grille)
	var j := {}
	for e in entites.values():
		if e.controle == "joueur":
			j = e
	var instances := {}
	for uid in objets.keys():
		instances[uid] = objets[uid]
	var surface := {}
	for cell in monde.modifications.keys():
		surface[cell] = {"modifications": monde.modifications[cell], "decouvert": monde.decouvert.get(cell, {}), "contenants": monde.contenants_hors.get(cell, {}), "dormants": monde.dormants.get(cell, [])}
	for cell in monde.decouvert.keys():
		if not surface.has(cell):
			surface[cell] = {"modifications": {}, "decouvert": monde.decouvert[cell], "contenants": monde.contenants_hors.get(cell, {}), "dormants": monde.dormants.get(cell, [])}
	for cell in monde.contenants_hors.keys():
		if not surface.has(cell):
			surface[cell] = {"modifications": {}, "decouvert": {}, "contenants": monde.contenants_hors[cell], "dormants": monde.dormants.get(cell, [])}
	for cell in monde.dormants.keys():
		if not surface.has(cell):
			surface[cell] = {"modifications": {}, "decouvert": {}, "contenants": {}, "dormants": monde.dormants[cell]}
	var autres := {}
	var ordre_autres: Array = []
	for id in ordre:
		if entites[id].controle != "joueur":
			autres[id] = entites[id]
			ordre_autres.append(id)
	var contenants_monde := {}
	for gi in contenants.keys():
		contenants_monde[grille.pos_de(int(gi))] = contenants[gi]
	var ok := Sauvegarde.ecrire(nom, "world.json", {"version": 1, "graine": graine, "ticks": horloge_monde.ticks, "prochain_donjon": prochain_donjon, "n_entites": _n_entites,
		"cellule_camp": monde.cellule_camp, "camp": {"entree": camp_sauve.get("entree", Vector2i.ZERO), "biome": camp_sauve.get("biome", ""), "cellule": camp_sauve.get("cellule", Vector2i.ZERO)}, "explores": monde.explores,
		"delta": monde.delta, "foyers": monde.foyers, "semaine": monde.semaine_courante, "peuplees": monde.peuplees, "claims": monde.claims, "territoire": territoire})
	ok = Sauvegarde.ecrire(nom, "surface.json", surface) and ok
	ok = Sauvegarde.ecrire(nom, "entities.json", {"entites": autres, "ordre": ordre_autres, "contenants": contenants_monde}) and ok
	ok = Sauvegarde.ecrire(nom, "items.json", instances) and ok
	ok = Sauvegarde.ecrire(nom, "players/joueur.json", {"fiche": fiche_joueur, "etre": j}) and ok
	if ok:
		EventBus.emettre(&"sauvegarde_faite", [nom])
	return ok


## Recharge une partie : le monde depuis la graine, puis les modifications, les êtres et le joueur.
func charger_sauvegarde(nom: String = "monde") -> bool:
	var w: Variant = Sauvegarde.lire(nom, "world.json")
	if w == null:
		return false
	var surface: Dictionary = Sauvegarde.lire(nom, "surface.json")
	var ent: Dictionary = Sauvegarde.lire(nom, "entities.json")
	var instances: Dictionary = Sauvegarde.lire(nom, "items.json")
	var pj: Dictionary = Sauvegarde.lire(nom, "players/joueur.json")
	graine = int(w.graine)
	des = Des.new(graine)
	fiche_joueur = pj.get("fiche", {})
	camp_sauve = {}
	etages_visites.clear()
	expedition = {}
	charger_camp()   # regénère le monde depuis la graine
	# Les objets d'abord (les êtres y font référence par uid).
	for uid in instances.keys():
		objets[uid] = instances[uid]
		items[uid] = instances[uid]
	monde.cellule_camp = w.cellule_camp
	monde.explores = w.get("explores", {})
	monde.delta = w.get("delta", {})
	monde.foyers = w.get("foyers", {})
	monde.semaine_courante = int(w.get("semaine", 0))
	monde.peuplees = w.get("peuplees", {})
	monde.claims = w.get("claims", {})
	territoire = w.get("territoire", territoire)
	for cell in surface.keys():
		var sc: Dictionary = surface[cell]
		if not sc.modifications.is_empty():
			monde.modifications[cell] = sc.modifications
		if not sc.decouvert.is_empty():
			monde.decouvert[cell] = sc.decouvert
		if not sc.contenants.is_empty():
			monde.contenants_hors[cell] = sc.contenants
		if not sc.dormants.is_empty():
			monde.dormants[cell] = sc.dormants
	# Le joueur, puis la fenêtre autour de lui (les cellules mémorisées y sont rejouées).
	var joueur_sauve: Dictionary = pj.etre
	_reinitialiser()
	monde.centre = Vector2i(-1, -1)
	grille = monde.fenetre(monde.cellule_de(joueur_sauve.pos), GameData.config("tile_contents"), regles.r.deplacement, int(regles.r.vision.hauteur_oeil))
	monde.tick(int(w.ticks))   # les grâces échues avant la sauvegarde
	entites[joueur_sauve.id] = joueur_sauve
	ordre.append(joueur_sauve.id)
	for id in ent.ordre:
		entites[id] = ent.entites[id]
		ordre.append(id)
	for pos in ent.contenants.keys():
		if grille.dans(pos):
			contenants[grille.idx(pos)] = ent.contenants[pos]
			if grille.contenu_de(pos).is_empty():
				grille.poser_contenu(pos, "butin")
	for cell in monde.contenants_hors.keys().duplicate():
		if absi(cell.x - monde.centre.x) <= monde.rayon and absi(cell.y - monde.centre.y) <= monde.rayon:
			for li in monde.contenants_hors[cell].keys():
				var pos: Vector2i = monde.pos_monde(cell, Vector2i(int(li) % monde.taille, int(li) / monde.taille))
				contenants[grille.idx(pos)] = monde.contenants_hors[cell][li]
			monde.contenants_hors.erase(cell)
	for id in ordre:
		if entites[id].vivant:
			grille.placer(id, entites[id].pos)
	grille.modifies.clear()
	horloge_monde.ticks = int(w.ticks)
	prochain_donjon = int(w.prochain_donjon)
	_n_entites = int(w.n_entites)
	camp_sauve = {"entree": w.camp.entree, "biome": str(w.camp.biome), "cellule": w.camp.cellule}
	lieu = "camp"
	maj_vision()
	monde.pregenerer_voisins()
	EventBus.emettre(&"fenetre_recentree", [grille.origine])
	return true


# ---------------------------------------------------------------- craft compositionnel

## Façonner un composant : une unité de la famille, à la station de la recette ; le composant porte les
## 13 stats et le vecteur Wu Xing de son matériau, et une qualité A.3 sur la compétence de la station.
func _faconner(e: Dictionary, r: Dictionary, tick: int) -> bool:
	if not stations_de(e).has(str(r.station)):
		EventBus.emettre(&"journal", [&"journal.pas_de_station", {"recette": GameData.entree("components", r.component).name_key}])
		return false
	if not bool(r.unlocked_by_default) and not (str(r.id) in e.get("recettes_connues", [])):
		return false
	var plan := _plan_composant(e, r)
	if not plan.faisable:
		EventBus.emettre(&"journal", [&"journal.manque", {"recette": GameData.entree("components", r.component).name_key}])
		return false
	var pile: Dictionary = plan.entrees[0].pile
	var mat_id := str(pile.materiau)
	_retirer_materiau(e, pile, 1)
	var comp: Dictionary = GameData.entree("components", r.component)
	var station: Dictionary = GameData.entree("stations", r.station)
	var skill := str(station.craft_skill)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "craft", objets.size(), r.id])
	var inst := generer_objet("composant", 1, {}, "commun", 0)
	if inst.is_empty():
		return false
	var mat: Dictionary = GameData.entree("materials", mat_id)
	inst.composant = str(r.component)
	inst.materiau = mat_id
	inst.name_key = comp.name_key
	inst.stats = mat.stats.duplicate()
	inst.elements = mat.wuxing.duplicate()
	inst.qualite = regles.qualite_craft(regles.niveau(e.competences_eff, skill), rng)
	e.sac.append(inst.uid)
	var n := regles.niveau(e.competences_eff, skill)
	e.compteur = tick + _ticks_avec_statuts(e, maxi(1, ceili(float(regles.r.craft.ticks_base) / regles.skill_factor(n))))
	gagner_xp(e, skill, int(mat.stats.durete))
	EventBus.emettre(&"journal", [&"journal.faconne", {"nom": e.name_key, "objet": nom_objet(inst.uid), "qualite": "qualite." + regles.palier_qualite(inst.qualite)}])
	return true


## Assembler un objet depuis ses composants (Stats et qualité de l'assemblage) : stats = Σ stat × poids,
## durete_base avant qualité, qualité = Σ q × poids × jet borné, Wu Xing composite, vitesse du manche.
func _assembler(e: Dictionary, def: Dictionary, tick: int) -> bool:
	var st := str(def.recipe.station)
	if not stations_de(e).has(st):
		EventBus.emettre(&"journal", [&"journal.pas_de_station", {"recette": def.name_key}])
		return false
	var plan := _plan_objet(e, def)
	if not plan.faisable:
		EventBus.emettre(&"journal", [&"journal.manque", {"recette": def.name_key}])
		return false
	var poids: Dictionary = regles.r.craft.poids.armure if def.type == "armure" else regles.r.craft.poids.arme
	var stats := {}
	var elements := {}
	var q_somme := 0.0
	var composants := {}
	var tete: Dictionary = {}
	var manche: Dictionary = {}
	for en in plan.entrees:
		var c: Dictionary = en.pile
		var w := float(poids.get(en.slot, 0.0))
		for s in c.stats.keys():
			stats[s] = float(stats.get(s, 0.0)) + float(c.stats[s]) * w
		for el in c.elements.keys():
			elements[el] = float(elements.get(el, 0.0)) + float(c.elements[el]) * w
		q_somme += float(c.qualite) * w
		composants[en.slot] = {"composant": c.composant, "materiau": c.materiau, "qualite": c.qualite}
		if en.slot in ["tete", "plaque"]:
			tete = c
		elif en.slot == "manche":
			manche = c
		e.sac.erase(c.uid)
		items.erase(c.uid)
	var skill := str(def.recipe.craft_skill)
	var n := regles.niveau(e.competences_eff, skill)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "assemblage", objets.size(), def.id])
	var borne: Array = regles.r.craft.qualite.jet_assemblage
	var jet := clampf(regles.qualite_craft(n, rng), float(borne[0]), float(borne[1]))
	var inst := generer_objet(def.id, 1, {}, "commun", 0)
	if inst.is_empty():
		return false
	inst.stats = stats
	inst.durete_base = roundi(float(stats.get("durete", 0.0)))   # la moyenne pondérée AVANT qualité
	inst.qualite = snappedf(q_somme * jet, 0.01)
	inst.elements = elements
	inst.element = wuxing.dominante(elements)
	inst.materiau = str(tete.get("materiau", ""))
	inst.composants = composants
	if not manche.is_empty():
		var v: Dictionary = regles.r.craft.vitesse
		inst.vitesse_facteur = snappedf(1.0 + (float(manche.stats.densite) - float(v.densite_reference)) * float(v.par_point), 0.01)
	if def.type == "armure":
		inst.durete_composite = inst.durete_base
		inst.niveau_construction = 0
	e.sac.append(inst.uid)
	e.compteur = tick + _ticks_avec_statuts(e, maxi(1, ceili(float(regles.r.craft.ticks_base) / regles.skill_factor(n))))
	gagner_xp(e, skill, inst.durete_base)
	EventBus.emettre(&"journal", [&"journal.assemble", {"nom": e.name_key, "objet": nom_objet(inst.uid), "qualite": "qualite." + regles.palier_qualite(inst.qualite)}])
	return true


# ---------------------------------------------------------------- fabrication (Stations de transformation)

## Les stations portées : id de station → uid de l'objet.
func stations_de(e: Dictionary) -> Dictionary:
	var res := {}
	for uid in e.sac:
		var it: Dictionary = items.get(uid, {})
		if it.get("type", "") == "station":
			res[str(it.station)] = uid
	# Les stations fixes sous le joueur ou adjacentes (Stations de transformation : la version fixe).
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t: Vector2i = e.pos + Vector2i(dx, dy)
			if grille.dans(t) and grille.stations_fixes.has(grille.idx(t)):
				res[str(grille.stations_fixes[grille.idx(t)])] = "fixe"
	return res


## Tout ce que les stations du sac permettent : transformations plates, composants (recettes connues),
## objets assemblés. [{id, kind, recette, station, faisable, entrees, sortie}]
func recettes_disponibles(e: Dictionary) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	var stations := stations_de(e)
	var ids: Array = GameData.catalogues.recipes.keys()
	ids.sort()
	for rid in ids:
		var r: Dictionary = GameData.catalogues.recipes[rid]
		if stations.has(str(r.station)):
			var pl := _plan_recette(e, r)
			pl["kind"] = "plate"
			res.append(pl)
	ids = GameData.catalogues.component_recipes.keys()
	ids.sort()
	for rid in ids:
		var r: Dictionary = GameData.catalogues.component_recipes[rid]
		if not stations.has(str(r.station)):
			continue
		if not bool(r.unlocked_by_default) and not (rid in e.get("recettes_connues", [])):
			continue
		res.append(_plan_composant(e, r))
	ids = GameData.catalogues.items.keys()
	ids.sort()
	for iid in ids:
		var it: Dictionary = GameData.catalogues.items[iid]
		if it.has("slots") and stations.has(str(it.get("recipe", {}).get("station", ""))):
			res.append(_plan_objet(e, it))
	return res


## Le plan d'une recette de composant : une unité de la famille de matériaux, prise dans le sac.
func _plan_composant(e: Dictionary, r: Dictionary) -> Dictionary:
	var fam: Dictionary = GameData.config("material_families").get(str(r.material_family), {})
	var pile := _pile_famille(e, fam)
	return {"id": r.id, "kind": "composant", "recette": r, "station": str(r.station), "faisable": not pile.is_empty(),
		"entrees": [{"pile": pile, "besoin": 1, "forme": str(fam.get("forme", "brut")), "filtre": str(r.material_family)}],
		"sortie": {"composant": str(r.component), "materiau": str(pile.get("materiau", "")), "quantite": 1}}


## La première pile du sac qui appartient à la famille (catégorie ou matériau(x), et forme).
func _pile_famille(e: Dictionary, fam: Dictionary) -> Dictionary:
	if fam.is_empty() or fam.has("tag"):
		return {}   # familles paramétriques (os, écailles…) : pas de source encore
	var forme := str(fam.get("forme", "brut"))
	for uid in e.sac:
		var it: Dictionary = items.get(uid, {})
		if it.get("type", "") != "materiau" or str(it.get("forme", "brut")) != forme or int(it.quantite) < 1:
			continue
		var m := str(it.materiau)
		var mat: Dictionary = GameData.catalogues.materials.get(m, {})
		if fam.has("category") and str(mat.get("category", "")) != str(fam.category):
			continue
		if fam.has("material") and m != str(fam.material):
			continue
		if fam.has("materials") and not (m in fam.materials):
			continue
		return it
	return {}


## Le plan d'un objet assemblé : un composant du sac par slot.
func _plan_objet(e: Dictionary, it: Dictionary) -> Dictionary:
	var plan := {"id": it.id, "kind": "objet", "recette": it, "station": str(it.recipe.station), "faisable": true, "entrees": [], "sortie": {"objet": it.id, "quantite": 1}}
	var pris := {}
	for slot in it.slots.keys():
		var trouve := {}
		for uid in e.sac:
			var c: Dictionary = items.get(uid, {})
			if c.get("type", "") == "composant" and str(c.composant) == str(it.slots[slot]) and not pris.has(uid):
				trouve = c
				pris[uid] = true
				break
		plan.entrees.append({"pile": trouve, "besoin": 1, "forme": "", "filtre": str(it.slots[slot]), "slot": slot})
		if trouve.is_empty():
			plan.faisable = false
	return plan


## Le plan d'une recette pour cet être : les piles du sac qui satisfont chaque entrée (par matériau
## ou par catégorie — la première pile suffisante, dans l'ordre du sac).
func _plan_recette(e: Dictionary, r: Dictionary) -> Dictionary:
	var plan := {"id": r.id, "recette": r, "station": str(r.station), "faisable": true, "entrees": [], "sortie": {}}
	var mat_sortie := str(r.output.get("material", ""))
	for entree in r.inputs:
		var besoin := int(entree.amount)
		var forme := str(entree.get("forme", "brut"))
		var trouvee := {}
		for uid in e.sac:
			var it: Dictionary = items.get(uid, {})
			if entree.has("item"):   # une entrée par objet (viande crue, baies…) : la pile de cette base
				if str(it.get("base", "")) == str(entree.item) and int(it.get("quantite", 1)) >= besoin:
					trouvee = it
					break
				continue
			if it.get("type", "") != "materiau" or str(it.get("forme", "brut")) != forme or int(it.quantite) < besoin:
				continue
			var mat: Dictionary = GameData.catalogues.materials.get(str(it.materiau), {})
			if entree.has("material") and str(it.materiau) != str(entree.material):
				continue
			if entree.has("category") and str(mat.get("category", "")) != str(entree.category):
				continue
			trouvee = it
			break
		plan.entrees.append({"pile": trouvee, "besoin": besoin, "forme": forme, "filtre": str(entree.get("material", entree.get("category", entree.get("item", ""))))})
		if trouvee.is_empty():
			plan.faisable = false
		elif mat_sortie.is_empty() and trouvee.has("materiau"):
			mat_sortie = str(trouvee.materiau)   # la sortie garde le matériau de l'entrée (lingot de fer…)
	plan.sortie = {"materiau": mat_sortie, "forme": str(r.output.get("forme", "brut")), "quantite": int(r.output.amount), "item": str(r.output.get("item", ""))}
	return plan


## Fabriquer : consomme les entrées, produit la sortie ; ticks = ticks_base / skill_factor(N) ;
## XP à la compétence de la station = dureté du matériau produit.
func _fabriquer(e: Dictionary, rid: String, tick: int) -> bool:
	if GameData.catalogues.component_recipes.has(rid):
		return _faconner(e, GameData.catalogues.component_recipes[rid], tick)
	if GameData.catalogues.items.has(rid) and GameData.catalogues.items[rid].has("slots"):
		return _assembler(e, GameData.catalogues.items[rid], tick)
	var r: Dictionary = GameData.catalogues.recipes.get(rid, {})
	if r.is_empty():
		return false
	if not stations_de(e).has(str(r.station)):
		EventBus.emettre(&"journal", [&"journal.pas_de_station", {"recette": r.name_key}])
		return false
	var plan := _plan_recette(e, r)
	if not plan.faisable:
		EventBus.emettre(&"journal", [&"journal.manque", {"recette": r.name_key}])
		return false
	var durete_entrees := 0
	for entree in plan.entrees:
		durete_entrees += int(GameData.catalogues.materials.get(str(entree.pile.get("materiau", "")), {}).get("stats", {}).get("durete", 1))
		_retirer_materiau(e, entree.pile, int(entree.besoin))
	var sortie: Dictionary = plan.sortie
	var n := regles.niveau(e.competences_eff, str(r.craft_skill))
	e.compteur = tick + _ticks_avec_statuts(e, maxi(1, ceili(float(regles.r.craft.ticks_base) / regles.skill_factor(n))))
	if r.output.has("item"):   # un objet fini (meuble, station, plat) : XP = dureté des entrées (10 par plat)
		var nom_obj := ""
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([graine, "plat", objets.size(), r.id])
		for k in int(sortie.quantite):
			var inst := generer_objet(str(r.output.item), 1, {}, "commun", 0)
			if not inst.is_empty():
				if inst.get("type", "") == "consommable":   # un plat : qualité A.3 sur Cuisine, empilé
					inst.qualite = snappedf(regles.qualite_craft(regles.niveau(e.competences_eff, str(r.craft_skill)), rng), 0.01)
					var pile := _pile_objet(e, str(r.output.item))
					if not pile.is_empty():
						pile.quantite = int(pile.quantite) + 1
						items.erase(inst.uid)
						nom_obj = pile.name_key
						continue
				e.sac.append(inst.uid)
				nom_obj = inst.name_key
		gagner_xp(e, str(r.craft_skill), maxi(10, durete_entrees))
		EventBus.emettre(&"journal", [&"journal.fabrique", {"nom": e.name_key, "quantite": int(sortie.quantite), "objet": nom_obj, "recette": r.name_key}])
		return true
	_donner_materiau(e, sortie.materiau, int(sortie.quantite), sortie.forme)
	var mat: Dictionary = GameData.catalogues.materials.get(str(sortie.materiau), {})
	gagner_xp(e, str(r.craft_skill), int(mat.get("stats", {}).get("durete", 1)))
	EventBus.emettre(&"journal", [&"journal.fabrique", {"nom": e.name_key, "quantite": int(sortie.quantite), "objet": mat.get("name_key", sortie.materiau), "recette": r.name_key}])
	return true


## L'état de l'étage courant, sans le joueur, mis de côté : rien ne repop, tout reste où c'est.
func _sauver_etage(joueur: Dictionary) -> void:
	var sauve := {"donjon": donjon.duplicate(), "grille": grille, "entites": {}, "ordre": [], "contenants": contenants}
	for id in ordre:
		if id != joueur.id:
			sauve.entites[id] = entites[id]
			sauve.ordre.append(id)
	grille.liberer(joueur.pos)
	etages_visites[int(donjon.etage)] = sauve


## Descendre : l'être doit être sur la cage d'escalier de l'étage (Donjons : escalier = lien).
func _descendre(e: Dictionary) -> bool:
	if lieu == "camp":
		return _partir_en_expedition(e)
	if donjon.is_empty() or donjon.escalier == null or e.pos != donjon.escalier:
		return false
	if int(donjon.etage) >= int(donjon.etages):
		return false
	var prochain: int = int(donjon.etage) + 1
	e.etage_depuis = int(donjon.etage)
	EventBus.emettre(&"journal", [&"journal.descente", {"etage": prochain}])
	charger_donjon(donjon.theme, int(donjon.graine), int(donjon.id), prochain, e)
	return true


## Remonter : sur la tuile d'entrée de l'étage. À l'étage 1, c'est la sortie du donjon — le jalon
## « entrer, combattre, looter, progresser, ressortir » se ferme ici.
func _remonter(e: Dictionary) -> bool:
	if donjon.is_empty() or e.pos != Vector2i(donjon.get("entree", Vector2i(-1, -1))):
		return false
	if int(donjon.etage) <= 1:
		return _sortir(e)
	var precedent: int = int(donjon.etage) - 1
	e.etage_depuis = int(donjon.etage)
	EventBus.emettre(&"journal", [&"journal.remontee", {"etage": precedent}])
	charger_donjon(donjon.theme, int(donjon.graine), int(donjon.id), precedent, e)
	return true


## Sortir du donjon : récapitulatif de l'expédition, puis une nouvelle expédition (graine suivante)
## avec le même être — son sac, ses niveaux, ses potentiels.
func _sortir(e: Dictionary) -> bool:
	var recap := expedition.duplicate()
	recap["sac"] = e.sac.size()
	recap["niveaux"] = progression.niveaux_derives(e)
	recap["boss_vaincu"] = _boss_vaincu()
	EventBus.emettre(&"journal", [&"journal.sortie", {"nom": e.name_key, "tues": recap.tues, "objets": recap.objets, "etage_max": recap.etage_max}])
	EventBus.emettre(&"expedition_terminee", [recap])
	etages_visites.clear()
	expedition = {}
	if not camp_sauve.is_empty():   # le camp est le point d'ancrage entre deux expéditions (étape 7)
		EventBus.emettre(&"journal", [&"journal.retour_camp", {}])
		var cell_donjon: Vector2i = donjon.get("cellule", Vector2i(-9999, -9999))
		charger_camp(e)
		if recap.boss_vaincu and monde != null and cell_donjon != Vector2i(-9999, -9999):
			monde.nettoyer(cell_donjon, horloge_monde.ticks)   # Dérive de la corruption : foyer nettoyé
			EventBus.emettre(&"journal", [&"journal.donjon_nettoye", {}])
			_quetes_sur_donjon(cell_donjon, e.id)
			EventBus.emettre(&"dungeon_cleared", [cell_donjon, e.id])
		sauvegarder()   # autosave au retour (Sauvegarde : sur événements clés)
		return true
	var suivant: int = int(donjon.id) + 1
	charger_donjon(donjon.theme, int(donjon.graine), suivant, 1, e)
	return true


func _boss_vaincu() -> bool:
	for etage in etages_visites.keys():
		for id in etages_visites[etage].ordre:
			var x: Dictionary = etages_visites[etage].entites[id]
			if x.get("chain_gauge", false) and not x.vivant:
				return true
	for x in entites.values():
		if x.get("chain_gauge", false) and x.controle == "ia" and not x.vivant:
			return true
	return false


func ajouter(def_id: String, pos: Vector2i, controle: String) -> Dictionary:
	_n_entites += 1
	var id := "%s_%d" % [def_id, _n_entites]
	var def := fiche_joueur if (controle == "joueur" and not fiche_joueur.is_empty()) else GameData.entree("creatures", def_id)
	var e := Etres.instancier(id, def, pos, controle, regles, items)
	e["or"] = 0
	if controle != "joueur" and "civil" in def.get("tags", []):
		_habiller_pnj(e, def)
	for base in def.get("sac", []):   # objets de départ (bases) : instanciés dans le sac
		var inst := generer_objet(str(base), 1, {}, "commun", 0)
		if not inst.is_empty():
			e.sac.append(inst.uid)
	# Variante rare (Monstres rares) : tirage à la résolution du spawn, stats ×2.5, teinte or, épithète, drop garanti.
	if controle == "ia":
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([graine, "rare", _n_entites, def_id])
		var chance := float(def.get("rare_chance", regles.r.get("monstres_rares", {}).get("chance_defaut", 0.02)))
		if rng.randf() < chance:
			_rendre_rare(e, rng)
	if e.chain_gauge:
		e.chaine = wuxing.jauge_neuve()
	e.spawn = pos
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


## Un PNJ civil : son camp, son nom (culture du village ou de sa race), sa bourse (fonction), son stock.
func _habiller_pnj(e: Dictionary, def: Dictionary, culture_id: String = "") -> void:
	e.camp = "civil"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "pnj", e.id])
	var cultures: Dictionary = GameData.catalogues.name_cultures
	if culture_id.is_empty():
		culture_id = str(def.get("social", {}).get("culture", ""))
	if culture_id.is_empty() or not cultures.has(culture_id):
		culture_id = Noms.culture_pour(str(def.get("race", "humain")), cultures, rng)
	var genre := str(def.get("genre", "m" if rng.randf() < 0.5 else "f"))
	e["nom"] = Noms.generer(culture_id, cultures.get(culture_id, {}), genre, rng)
	e["genre"] = genre
	e["name_key"] = "pnj.%s.name" % e.id
	GameData.enregistrer_nom(e.name_key, Noms.afficher(e.nom))
	e["fonction"] = str(def.get("fonction", "oisif"))
	e["role"] = str(def.get("role", "resident"))
	e["social"] = {"culture": culture_id, "relations": {}}
	var f: Dictionary = GameData.catalogues.functions.get(e.fonction, {})
	e["or_max"] = int(float(f.get("portefeuille", 30)) * (1.0 + float(e.get("rang", 0)) * 0.5))
	e.or = e.or_max
	e["stock"] = []
	for base in def.get("inventaire_marchand", []):
		var o := generer_objet(str(base), 1, {}, "commun", 0)
		if not o.is_empty():
			e.stock.append(o.uid)
	e["dernieres_repliques"] = []
	e["dernier_parler_jour"] = -1
	var ag: Dictionary = regles.r.age
	e["age"] = float(rng.randi_range(int(ag.depart[0]), int(ag.depart[1])))
	var esp := float(ag.esperance.get(str(def.get("race", "humain")), ag.esperance._defaut))
	e["lifespan"] = esp * rng.randf_range(1.0 - float(ag.variance), 1.0 + float(ag.variance))


## Deux êtres sont-ils ennemis ? Deux camps différents, sauf le joueur et les civils (IA des créatures).
func ennemis(a: Dictionary, b: Dictionary) -> bool:
	if a.camp == b.camp:
		return false
	var doux := ["joueur", "civil"]
	if a.camp in doux and b.camp in doux:
		# Réputation et relations : ≤ −50, hostile à vue.
		var seuil := int(regles.r.reputation.hostile_seuil)
		if a.camp == "civil" and b.camp == "joueur":
			return relation_de(a, b) <= seuil
		if b.camp == "civil" and a.camp == "joueur":
			return relation_de(b, a) <= seuil
		return false
	return true


## La relation d'un PNJ envers un être (−100..+100), la réputation de son village en repli.
func relation_de(pnj: Dictionary, e: Dictionary) -> int:
	var rels: Dictionary = pnj.get("social", {}).get("relations", {})
	if rels.has(e.id):
		return int(rels[e.id])
	return int(e.get("reputations", {}).get(str(pnj.get("village", "")), 0))


## Un acte du joueur envers un PNJ : gains [pnj, village, globale] (Réputation et relations), modulés
## par la vitesse liée à la réputation du village.
func reputation(e: Dictionary, pnj: Dictionary, acte: String) -> void:
	var rp: Dictionary = regles.r.reputation
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
	pnj.social.relations[e.id] = clampi(relation_de(pnj, e) + g0, -100, 100)
	if not village.is_empty():
		e.reputations[village] = clampi(rep_v + int(gains[1]), -100, 100)
	e.reputations["_globale"] = clampi(int(e.reputations.get("_globale", 0)) + int(gains[2]), -100, 100)
	EventBus.emettre(&"journal", [&"journal.reputation", {"nom": pnj.name_key, "pnj": int(pnj.social.relations[e.id]), "village": village if not village.is_empty() else "—", "rep": int(e.reputations.get(village, 0))}])
	if relation_de(pnj, e) <= int(rp.hostile_seuil):
		EventBus.emettre(&"journal", [&"journal.hostile_a_vue", {"nom": pnj.name_key}])


## Le palier d'information d'un PNJ pour le joueur (L'information comme récompense) : 0..5.
func palier_info(pnj: Dictionary, e: Dictionary) -> int:
	var rel := relation_de(pnj, e)
	if rel < 0:
		return 0
	var paliers: Array = regles.r.reputation.paliers_info
	var p := 0
	for k in paliers.size():
		if rel >= int(paliers[k]):
			p = k + 1
	return p


## Une rumeur (≥ 50) : révèle une cellule à POI non explorée dans le rayon, filtrée par le métier.
func _rumeur(pnj: Dictionary, e: Dictionary, tick: int) -> bool:
	if monde == null or relation_de(pnj, e) < int(regles.r.reputation.confidences_seuil):
		return false
	var semaine := tick / int(GameData.config("planete").corruption.ticks_par_semaine)
	if int(pnj.get("derniere_rumeur", -1)) == semaine:
		return false
	var centre := monde.cellule_de(pnj.pos)
	var r := int(regles.r.reputation.rumeur_rayon)
	var cle := "filon_majeur" if str(pnj.get("fonction", "")) == "artisan" else "donjon"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "rumeur", pnj.id, semaine])
	var candidats: Array[Vector2i] = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := centre + Vector2i(dx, dy)
			if c != centre and monde.surface.terre_a(c) and not monde.cellule_exploree(c) and bool(monde.surface.poi_de(c).get(cle, false)):
				candidats.append(c)
	if candidats.is_empty():
		return false
	var c: Vector2i = candidats[rng.randi_range(0, candidats.size() - 1)]
	monde.explores[Vector2i(c.x * (monde.taille / 32) + 1, c.y * (monde.taille / 32) + 1)] = true
	pnj["derniere_rumeur"] = semaine
	EventBus.emettre(&"journal", [&"journal.rumeur", {"nom": pnj.name_key, "x": c.x, "y": c.y}])
	EventBus.emettre(&"chunk_explored", [Vector2i(c.x * (monde.taille / 32) + 1, c.y * (monde.taille / 32) + 1)])
	return true


## Peuple les cellules à hameau de la fenêtre à leur première visite (Villages PNJ).
func _peupler_fenetre() -> void:
	if monde == null:
		return
	for dy in range(-monde.rayon, monde.rayon + 1):
		for dx in range(-monde.rayon, monde.rayon + 1):
			var cell: Vector2i = monde.centre + Vector2i(dx, dy)
			if monde.peuplees.has(cell):
				continue
			var e := monde.cellule(cell)
			var v: Dictionary = e.get("village", {})
			if v.is_empty():
				continue
			monde.peuplees[cell] = true
			for pj in v.pnj:
				var pos: Vector2i = monde.pos_monde(cell, pj.pos)
				if grille.occupant(pos).is_empty():
					var x := ajouter(str(pj.creature), pos, "ia")
					_habiller_pnj(x, GameData.entree("creatures", str(pj.creature)), str(v.culture))
					x["lit"] = monde.pos_monde(cell, pj.lit)
					x["poste"] = pos
					x["place"] = monde.pos_monde(cell, v.centre)
					x["village"] = str(v.nom)
					x.ancre = pos
			EventBus.emettre(&"journal", [&"journal.village", {"nom": v.nom}])


## Donne un objet à un être (dans son sac).
func donner(e: Dictionary, uid: String) -> void:
	if items.has(uid) and not (uid in e.sac):
		var it: Dictionary = items[uid]
		if "empilable" in it.get("tags", []) and it.get("type", "") == "consommable":
			var pile := _pile_objet(e, str(it.get("base", "")))
			if not pile.is_empty():
				pile.quantite = int(pile.quantite) + int(it.get("quantite", 1))
				items.erase(uid)
				EventBus.emettre(&"journal", [&"journal.loot", {"nom": e.name_key, "objet": nom_objet(pile.uid)}])
				return
		e.sac.append(uid)
		EventBus.emettre(&"journal", [&"journal.loot", {"nom": e.name_key, "objet": nom_objet(uid)}])


## Le nom affichable d'un objet : {"base": name_key, "affixe": id ou "", "params": {}} — le client formate.
func nom_objet(uid: String) -> Dictionary:
	var it: Dictionary = items.get(uid, {})
	var nom: Dictionary = it.get("nom", {})
	var res := {"base": it.get("name_key", uid), "affixe": nom.get("affixe", ""), "params": nom.get("params", {}), "rarete": it.get("rarete", "commun")}
	if it.get("type", "") == "composant" or it.has("composants"):   # craft : l'objet se décrit par son matériau
		res["materiau"] = GameData.catalogues.materials.get(str(it.get("materiau", "")), {}).get("name_key", "")
		res["construction"] = str(it.get("construction", ""))
		res["qualite"] = float(it.get("qualite", 1.0))
	return res


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


## Retirer une pièce : elle retourne au sac (utiliser un objet : le coût de `actions.objet`).
func _desequiper(e: Dictionary, slot: String, tick: int) -> bool:
	if not e.equipement.has(slot):
		return false
	var uid: String = e.equipement[slot]
	e.equipement.erase(slot)
	e.sac.append(uid)
	Etres.recalculer(e, items, affixes_defs, regles)
	_quitter_garde(e)
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.desequipe", {"nom": e.name_key, "objet": nom_objet(uid)}])
	return true


## Jeter un objet du sac : il tombe en butin sur la tuile (ramassable, R).
func _jeter(e: Dictionary, uid: String, tick: int) -> bool:
	if not (uid in e.sac) or not items.has(uid):
		return false
	e.sac.erase(uid)
	e.ratelier.erase(uid)
	_poser_contenant(e.pos, [uid], "butin")
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.jette", {"nom": e.name_key, "objet": nom_objet(uid)}])
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
		if not expedition.is_empty() and e.controle == "joueur":
			expedition.objets = int(expedition.objets) + 1
	contenants.erase(idx)
	grille.contenu[idx] = 0
	EventBus.emettre(&"tile_changed", [e.pos])
	e.compteur = tick + int(regles.r.actions.objet)
	return true


## Mort et pénalité : respawn au point d'entrée, 10 % de chance par objet du sac de tomber sur le
## lieu de mort, équipement conservé, aucune perte d'XP. Le respawn est une intention du client.
func _respawn(e: Dictionary) -> bool:
	if e.vivant or e.controle != "joueur":
		return false
	var perdus: Array = []
	for uid in e.sac.duplicate():
		if des.reel() < float(regles.r.mort.chance_perte_objet):
			e.sac.erase(uid)
			perdus.append(uid)
	_poser_contenant(e.pos, perdus, "butin")
	if en_combat(e):
		_quitter_combat(e)
	e.vivant = true
	e.sante = e.sante_max
	e.endurance = e.endurance_max
	e.statuts = []
	e.action_en_cours = {}
	if lieu == "donjon" and not camp_sauve.is_empty() and e.has("lit"):
		# Mort en expédition : on se relève au dernier lit, au camp (Mort et pénalité) ; l'expédition est finie.
		grille.liberer(e.pos)
		e["mort_en_expedition"] = true
		etages_visites.clear()
		expedition = {}
		charger_camp(e)
		EventBus.emettre(&"journal", [&"journal.respawn", {"nom": e.name_key, "perdus": perdus.size()}])
		return true
	var spawn: Vector2i = e.get("spawn", e.pos)
	if not grille.occupant(spawn).is_empty() or grille.bloque_passage(spawn):
		spawn = e.pos
	e.pos = spawn
	grille.placer(e.id, spawn)
	e.compteur = horloge_monde.ticks
	EventBus.emettre(&"journal", [&"journal.respawn", {"nom": e.name_key, "perdus": perdus.size()}])
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
		gagner_xp(e, "lecture", int(livre.difficulte) * int(lv.xp_succes))
		EventBus.emettre(&"journal", [&"journal.lecture_reussie", {"nom": e.name_key, "n": appris.size(), "livre": nom_objet(objet)}])
	else:
		e.xp.competence["lecture"] = int(e.xp.competence.get("lecture", 0)) + int(livre.difficulte) * int(lv.xp_echec)
		gagner_xp(e, "lecture", int(livre.difficulte) * int(lv.xp_echec))
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
	var profondeur: int = int(donjon.get("profondeur", donjon.get("etage", 0)))
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
	# La dépouille (Nourriture : la viande crue des animaux, en attendant les viandes paramétriques).
	for base in GameData.catalogues.creatures.get(str(cible.def), {}).get("depouille", []):
		var v := generer_objet(str(base), profondeur, {"creature": cible.name_key}, "commun", 0)
		if not v.is_empty():
			uids.append(v.uid)
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
	_tiquer_faim(horloge_monde.ticks)
	_tiquer_monde(horloge_monde.ticks)
	_tiquer_meteo(horloge_monde.ticks)
	_tiquer_faune(horloge_monde.ticks)


## La faune de surface (Créatures) : un tirage toutes les intervalle_ticks — sous le budget, une bête
## (ou une meute) apparaît dans l'anneau hors de vue, dans la faune du biome ; ×2 et volet nuit la nuit ;
## les bêtes trop loin et hors combat disparaissent.
var _dernier_tick_faune: int = -1
func _tiquer_faune(tick: int) -> void:
	if lieu != "camp" or monde == null:
		return
	var fa: Dictionary = GameData.config("planete").faune
	if _dernier_tick_faune >= 0 and tick / int(fa.intervalle_ticks) == _dernier_tick_faune / int(fa.intervalle_ticks):
		return
	_dernier_tick_faune = tick
	var j := {}
	var betes: Array = []
	for x in vivants():
		if x.controle == "joueur":
			j = x
		elif "bete" in x.get("tags", []) and x.controle == "ia":
			betes.append(x)
	if j.is_empty():
		return
	for b in betes:   # despawn au loin, hors combat
		if Grille.distance(b.pos, j.pos) > int(fa.despawn) and not en_combat(b):
			grille.liberer(b.pos)
			b.vivant = false
			ordre.erase(b.id)
			entites.erase(b.id)
	if betes.size() >= int(fa.budget):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "faune", tick])
	var nuit := est_nuit()
	if rng.randf() > float(fa.chance_base) * (float(fa.nuit_mult) if nuit else 1.0):
		return
	for essai in 12:
		var d := rng.randi_range(int(fa.anneau[0]), int(fa.anneau[1]))
		var a := rng.randf() * TAU
		var q: Vector2i = j.pos + Vector2i(roundi(cos(a) * d), roundi(sin(a) * d))
		if not grille.dans(q) or grille.bloque_passage(q) or not grille.occupant(q).is_empty() or grille.ligne_de_vue(j.pos, q) or grille.contenu_de(q).get("tags", []).has("liquide"):
			continue
		var b: Dictionary = GameData.catalogues.biomes.get(monde.surface.biome_a(q.x, q.y), {})
		var pool: Array = b.get("faune", []).duplicate()
		if nuit:
			pool.append_array(b.get("faune_nuit", []))
		if pool.is_empty():
			return
		var total := 0.0
		for f in pool:
			total += float(f.density)
		var t := rng.randf() * total
		var choix := ""
		for f in pool:
			t -= float(f.density)
			if t <= 0.0:
				choix = str(f.id)
				break
		if choix.is_empty():
			choix = str(pool.back().id)
		var def: Dictionary = GameData.catalogues.creatures.get(choix, {})
		var n := 1
		if def.has("meute") and (nuit or def.get("ai_profile", "") == "hostile"):
			n = des.jet(str(def.meute))
		for k in n:
			var pos: Vector2i = q + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2)) if k > 0 else q
			if grille.dans(pos) and not grille.bloque_passage(pos) and grille.occupant(pos).is_empty():
				var x := ajouter(choix, pos, "ia")
				# De jour, une bête est une bête sauvage ; la nuit, le loup chasse (hostile) — Créatures.
				if def.get("ai_profile", "") == "hostile" and "bete" in def.get("tags", []) and not nuit:
					x.ai_profile = "bete_sauvage"
				x["spawn_faune"] = true
		return


## La dérive de la corruption sur l'horloge du monde : le passage hebdomadaire, les grâces échues.
func _tiquer_monde(tick: int) -> void:
	if monde == null:
		return
	var cr: Dictionary = GameData.config("planete").corruption
	var semaine := tick / int(cr.ticks_par_semaine)
	while monde.semaine_courante < semaine:
		monde.semaine_courante += 1
		var touchees := monde.semaine(tick)
		var derive := int(regles.r.reputation.derive_hebdo)
		_vieillir_semaine(tick)
		for x in entites.values():
			if x.controle == "joueur":
				_semaine_territoire(x)
		for x in entites.values():   # les bourses des PNJ se rechargent (+15 % par semaine, Barèmes économiques)
			if x.has("or_max"):
				x.or = mini(int(x.or_max), int(x.or) + int(ceil(float(x.or_max) * float(regles.r.commerce.recharge_hebdo))))
			for rels in [x.get("social", {}).get("relations", {}), x.get("reputations", {})]:   # Voie de rédemption : +1/semaine vers 0
				for cle in rels.keys():
					if int(rels[cle]) < 0:
						rels[cle] = mini(0, int(rels[cle]) + derive)
		EventBus.emettre(&"journal", [&"journal.semaine", {"n": touchees.size()}])
		for cell in touchees:
			if monde.foyer(cell).get("generation", 0) > 0 and bool(monde.foyer(cell).actif):
				EventBus.emettre(&"journal", [&"journal.donjon_reapparu", {"x": cell.x, "y": cell.y}])
	for cell in monde.tick(tick):
		EventBus.emettre(&"journal", [&"journal.donjon_disparu", {"x": cell.x, "y": cell.y}])
		if lieu == "camp":
			EventBus.emettre(&"tile_changed", [monde.pos_monde(cell, monde.cellule(cell).entree_donjon)])


## La faim (Faim) : −1 par `ticks_par_point` sur l'horloge du monde, pour les êtres qui ont une jauge
## (les joueurs) ; à zéro, la santé max s'érode ; sous le seuil, les stats baissent (Etres.recalculer).
func _tiquer_faim(tick: int) -> void:
	var f: Dictionary = regles.r.faim
	for e in vivants():
		if e.controle != "joueur":
			continue
		if not e.has("faim"):
			e["faim"] = 100
			e["faim_tick"] = tick
		var periode := int(float(f.ticks_par_point) / float(e.get("faim_vitesse", 1.0)))
		var points := tick / periode - int(e.faim_tick) / periode
		if points > 0:
			var avant := int(e.faim)
			e.faim = maxi(0, int(e.faim) - points)
			if avant >= int(f.seuil_stats) and int(e.faim) < int(f.seuil_stats):
				Etres.recalculer(e, items, affixes_defs, regles)
				EventBus.emettre(&"journal", [&"journal.faim_stats", {"nom": e.name_key}])
			if avant > 0 and int(e.faim) == 0:
				EventBus.emettre(&"journal", [&"journal.affame", {"nom": e.name_key}])
		if int(e.faim) == 0:
			var pz := int(f.periode_zero)
			var coups := tick / pz - int(e.faim_tick) / pz
			if coups > 0:
				e.sante = maxi(1, int(e.sante) - coups * maxi(1, int(e.sante_max) * int(f.pct_sante_max) / 100))
		e.faim_tick = tick


## Le poids porté et la capacité d'un être (Armures et poids porté).
func poids_de(e: Dictionary) -> Dictionary:
	var total := 0.0
	for uid in e.sac:
		total += regles.poids_objet(items.get(uid, {}), fonctionnalites)
	for slot in e.equipement.keys():
		total += regles.poids_objet(items.get(e.equipement[slot], {}), fonctionnalites)
	var cap := regles.capacite_poids(e.stats_eff)
	return {"poids": total, "capacite": cap, "facteur": regles.facteur_surcharge(total, cap)}


## Manger un consommable du sac (Nourriture) : nutrition, soin, mana, statut, risque, potentiel du plat.
func _manger(e: Dictionary, uid: String, tick: int) -> bool:
	var it: Dictionary = items.get(uid, {})
	if not (uid in e.sac) or it.get("type", "") != "consommable":
		EventBus.emettre(&"journal", [&"journal.pas_comestible", {}])
		return false
	if not e.has("faim"):
		e["faim"] = 100
		e["faim_tick"] = tick
	var cru := bool(it.get("cru", false))
	var nutrition := float(it.get("nutrition", 0)) * (float(regles.r.cru_facteur) if cru else 1.0)
	var extra: Array[String] = []
	var avant := int(e.faim)
	e.faim = mini(100, int(e.faim) + roundi(nutrition))
	if avant < int(regles.r.faim.seuil_stats) and int(e.faim) >= int(regles.r.faim.seuil_stats):
		Etres.recalculer(e, items, affixes_defs, regles)
	if not str(it.get("soin_des", "")).is_empty():
		var soin := des.jet(str(it.soin_des))
		e.sante = mini(e.sante_max, int(e.sante) + soin)
		extra.append("+%d PV" % soin)
	if int(it.get("mana", 0)) > 0:
		e.mana = mini(e.mana_max, int(e.mana) + int(it.mana))
		extra.append("+%d mana" % int(it.mana))
	var statut := str(it.get("statut", ""))
	if statut.begins_with("purge:"):
		var cible := statut.trim_prefix("purge:")
		e.statuts = e.statuts.filter(func(s: Dictionary) -> bool: return str(s.id) != cible)
		EventBus.emettre(&"journal", [&"journal.purge", {"nom": e.name_key, "statut": "status.%s.name" % cible}])
	elif statut == "huile_feu":
		e["huile_feu"] = true
		EventBus.emettre(&"journal", [&"journal.huile", {"nom": e.name_key}])
	elif not statut.is_empty():
		appliquer_statut(e, statut, int(it.get("statut_ticks", 0)), e.id)
	for risque in it.get("risque", {}).keys():
		if des.reel() < float(it.risque[risque]):
			appliquer_statut(e, str(risque), 0, e.id)
	if not cru:
		var q := float(it.get("qualite", 1.0))
		for stat in it.get("potentiel", {}).keys():
			var gain := roundi(float(it.potentiel[stat]) * nutrition / 100.0 * q)
			if gain > 0:
				e.potentiels[stat] = mini(int(regles.r.progression.potentiel_max), int(e.potentiels.get(stat, int(regles.r.progression.potentiel_defaut))) + gain)
				EventBus.emettre(&"journal", [&"journal.potentiel_plat", {"nom": e.name_key, "n": gain, "stat": _nom_competence(stat)}])
	it.quantite = int(it.get("quantite", 1)) - 1
	if int(it.quantite) <= 0:
		e.sac.erase(uid)
		items.erase(uid)
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.mange", {"nom": e.name_key, "objet": nom_objet(uid) if items.has(uid) else {"base": it.name_key}, "faim": int(e.faim), "extra": (" · " + " · ".join(extra)) if not extra.is_empty() else ""}])
	return true


## Brouillard de guerre (Minimap et brouillard de guerre) : le champ de vue de chaque être contrôlé
## par un joueur — portée Perception × detection_par_perception, ligne de vue — est recalculé et
## mémorisé sur la grille (`decouvert`). `e.vue` : index de tuile → true ; `e.vue_version` change
## quand le champ change (le client redessine le terrain sur ce signal).
func maj_vision() -> void:
	for e in vivants():
		if e.controle != "joueur":
			continue
		var portee := int(float(e.stats_eff.perception) * float(regles.r.engagement.detection_par_perception))
		if lieu == "camp" and monde != null:
			var facteur := 1.0
			if est_nuit() and not ("vision_nocturne" in e.get("tags_acquis", [])):
				facteur *= float(_cycle().get("vision_nuit", 0.6))   # la nuit : malus de vision pour tous
			var etat: Dictionary = GameData.catalogues.weather_states.get(str(e.get("meteo_locale", meteo(monde.cellule_de(e.pos)))), {})
			facteur *= float(etat.get("visibility_mult", 1.0))
			portee = maxi(1, roundi(float(portee) * facteur))
		var vue := {}
		for dy in range(-portee, portee + 1):
			for dx in range(-portee, portee + 1):
				var t: Vector2i = e.pos + Vector2i(dx, dy)
				if grille.dans(t) and Grille.distance(e.pos, t) <= portee and grille.ligne_de_vue(e.pos, t):
					var idx := grille.idx(t)
					vue[idx] = true
					grille.decouvert[idx] = true
		if vue.size() != e.get("vue", {}).size() or e.get("vue_pos", Vector2i(-1, -1)) != e.pos or e.get("vue_sale", false):
			e["vue_version"] = int(e.get("vue_version", 0)) + 1
			if lieu == "camp" and monde != null:   # exploration à résolution chunk (minimap)
				for ch in monde.explorer(vue, grille):
					EventBus.emettre(&"chunk_explored", [ch])
		e["vue"] = vue
		e["vue_pos"] = e.pos
		e["vue_sale"] = false


## Un être voit-il la tuile `t` ? (les êtres sans champ de vue calculé — IA — voient tout : leur
## détection a sa propre règle)
func voit(e: Dictionary, t: Vector2i) -> bool:
	return not e.has("vue") or e.vue.has(grille.idx(t))


func _fin_de_pas(nom: String) -> void:
	for e in vivants():
		if e.controle == "joueur":
			_verifier_fenetre(e)
	maj_vision()
	for e in vivants():   # fin du buff Reposé
		if e.has("repose_jusqua") and int(e.repose_jusqua) <= horloge_de(e).ticks:
			e.erase("repose_jusqua")
			e["xp_mult"] = 1.0
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
		var regen := ecoules * int(regles.r.endurance.regen_par_tick)
		if float(e.get("ecart_confort", 0.0)) != 0.0:
			regen = int(float(regen) * float(GameData.config("planete").get("meteo", {}).get("endurance_regen_hors_confort", 0.5)))
		e.endurance = mini(e.endurance_max, e.endurance + regen)
		# Mana (A.5) : à chaque tranche de 10 ticks franchie, 1 chance sur 8 de rendre 1 + N_meditation × 0.2.
		var periode := int(regles.r.mana.periode_ticks)
		var tranches := tick / periode - int(e.tick_endurance) / periode
		for i in tranches:
			if des.reel() < float(regles.r.mana.chance):
				e.mana = mini(e.mana_max, e.mana + roundi(float(regles.r.mana.regen_base) + float(e.competences_eff.get("meditation", 0)) * float(regles.r.mana.regen_par_meditation)))
				gagner_xp(e, "meditation", 1)
	e.tick_endurance = tick


# ---------------------------------------------------------------- intentions (client → serveur)

## Une intention pour l'entité `id`, qui doit être en attente. Valide, exécute, retourne
## vrai si elle a été consommée. Types : deplacer{vers} · attaquer{cible, lourde} · garde · attendre.
func intention(id: String, i: Dictionary) -> bool:
	if str(i.get("type", "")) == "respawn" and entites.has(id):
		return _respawn(entites[id])   # un mort n'attend rien : le respawn passe hors de la file
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
				EventBus.dispatcher()
				return true   # la grille a changé : plus rien à finir sur l'ancienne
		"remonter":
			if _remonter(e):
				EventBus.dispatcher()
				return true
		"creuser":
			ok = _creuser(e, i.get("vers", Vector2i(-1, -1)), h.ticks)
		"equiper":
			ok = _equiper(e, str(i.get("objet", "")), h.ticks)
		"ramasser":
			ok = _ramasser(e, h.ticks)
		"respawn":
			ok = _respawn(e)
		"sertir":
			ok = _sertir(e, str(i.get("objet", "")), str(i.get("gemme", "")), h.ticks)
		"lire":
			ok = _lire(e, str(i.get("objet", "")), h.ticks)
		"fabriquer":
			ok = _fabriquer(e, str(i.get("recette", "")), h.ticks)
		"desequiper":
			ok = _desequiper(e, str(i.get("slot", "")), h.ticks)
		"poser":
			ok = _poser(e, str(i.get("objet", "")), i.get("vers", Vector2i(-1, -1)), h.ticks)
		"poser_mur":
			ok = _poser_mur(e, i.get("vers", Vector2i(-1, -1)), false, h.ticks)
		"poser_porte":
			ok = _poser_mur(e, i.get("vers", Vector2i(-1, -1)), true, h.ticks)
		"demonter":
			ok = _demonter(e, i.get("vers", Vector2i(-1, -1)), h.ticks)
		"ranger":
			ok = _ranger(e, str(i.get("objet", "")), i.get("vers", Vector2i(-1, -1)), h.ticks)
		"prendre":
			ok = _prendre(e, i.get("vers", Vector2i(-1, -1)), h.ticks)
		"dormir":
			ok = _dormir(e, i.get("vers", Vector2i(-1, -1)), h.ticks)
		"manger":
			ok = _manger(e, str(i.get("objet", "")), h.ticks)
		"parler":
			ok = _parler(e, str(i.get("pnj", "")), h.ticks)
		"acheter":
			ok = _acheter(e, str(i.get("pnj", "")), str(i.get("objet", "")), h.ticks)
		"vendre":
			ok = _vendre(e, str(i.get("pnj", "")), str(i.get("objet", "")), h.ticks)
		"accepter_quete":
			ok = _accepter_quete(e, str(i.get("pnj", "")), str(i.get("quete", "")), h.ticks)
		"recruter":
			ok = _recruter(e, str(i.get("pnj", "")), h.ticks)
		"assigner":
			ok = _assigner(e, str(i.get("pnj", "")), str(i.get("fonction", "")), h.ticks)
		"apprivoiser":
			ok = _apprivoiser(e, str(i.get("cible", "")), h.ticks)
		"ressusciter":
			ok = _ressusciter(e, str(i.get("ame", "")), h.ticks)
		"rendre_quete":
			ok = _rendre_quete(e, str(i.get("pnj", "")), str(i.get("quete", "")), h.ticks)
		"jeter":
			ok = _jeter(e, str(i.get("objet", "")), h.ticks)
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
	var ticks_dep := regles.ticks_deplacement(cout, e.competences_eff, en_combat(e))
	if e.controle == "joueur":   # surcharge (Armures et poids porté) : sur les ticks d'Athlétisme, jamais sur une stat
		ticks_dep = ceili(float(ticks_dep) * poids_de(e).facteur)
	e.compteur = tick + _ticks_avec_statuts(e, ticks_dep)
	_declencher_glyphe(e, vers)
	if en_combat(e):
		for autre in vivants():
			if autre.camp != e.camp and Grille.distance(autre.pos, e.pos) == 1:
				gagner_xp(e, "esquive", 1)   # la mobilité s'apprend sous le feu (Décision — Esquive active)
				break
	gagner_xp(e, "athletisme", 1)
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
	var ticks := _ticks_avec_statuts(e, regles.ticks_attaque(fonct, lourde, arme))
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
			if bouclier:
				gagner_xp(cible, "bouclier", sans_garde)   # la compétence Bouclier progresse à chaque impact bloqué
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
	if not att.is_empty() and att.controle == "joueur" and cible.camp == "civil" and "civil" in cible.get("tags", []):
		reputation(att, cible, "tuer" if cible.sante <= 0 else "frapper")
	if cible.sante <= 0 and cible.vivant:
		cible.vivant = false
		grille.liberer(cible.pos)
		EventBus.emettre(&"journal", [&"journal.mort", {"nom": cible.name_key}])
		EventBus.emettre(&"creature_killed", [cible.id, source])
		_quetes_sur_mort(cible, source)
		if cible.has("maitre"):
			_mort_compagnon(cible)
		_declencher(cible, "testament", cible.pos)   # la charge part quand le porteur tombe
		_drop(cible, source)
		if not expedition.is_empty() and entites.get(source, {}).get("controle", "") == "joueur":
			expedition.tues = int(expedition.tues) + 1
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
			gagner_xp(att, "element_" + el, xp)
		var comp := str(detail.get("competence", ""))
		if not comp.is_empty():
			att.xp.competence[comp] = int(att.xp.competence.get(comp, 0)) + xp
			gagner_xp(att, comp, xp)
		var type := str(detail.get("type", ""))
		if not type.is_empty() and type != "statut" and type != "magique":
			att.xp.type[type] = int(att.xp.type.get(type, 0)) + xp
			gagner_xp(att, type, xp)
		for m in detail.get("modules", []):
			gagner_xp(att, str(m), xp)   # les modules montent par l'usage, sous leur id
		EventBus.emettre(&"skill_xp_gained", [att.id, comp, xp])
	var cons := str(detail.get("construction", ""))
	if cible.has("xp") and not cons.is_empty() and int(detail.get("evites", 0)) > 0:
		cible.xp.construction[cons] = int(cible.xp.construction.get(cons, 0)) + int(detail.evites)
		gagner_xp(cible, cons, int(detail.evites))
	if cible.has("xp") and xp > 0 and not att.is_empty():
		gagner_xp(cible, "encaissement", xp)   # le défenseur gagne en Encaissement (E.3, étape 6)


## Verse de l'XP à une compétence par le moteur de progression ; la stat associée en reçoit la
## moitié ; chaque niveau gagné est journalisé et signalé (skill_level_up), l'équipement recalculé.
func gagner_xp(e: Dictionary, cle: String, xp: int) -> void:
	if xp <= 0 or not e.has("xp_competences"):
		return
	if not e.has("xp_depuis_repos"):
		e["xp_depuis_repos"] = {}
	e.xp_depuis_repos[cle] = int(e.xp_depuis_repos.get(cle, 0)) + xp   # « consommées récemment » (sommeil)
	var gagnes := progression.verser(e, cle, xp)
	var stat := progression.stat_associee(cle)
	if not stat.is_empty() and e.corps.stats.has(stat):
		_verser_stat(e, stat, roundi(float(xp) * float(regles.r.progression.part_stat)))
	if gagnes > 0:
		niveaux_gagnes.append({"id": e.id, "competence": cle, "niveau": int(e.competences[cle])})
		EventBus.emettre(&"skill_level_up", [e.id, cle, int(e.competences[cle])])
		EventBus.emettre(&"journal", [&"journal.niveau", {"nom": e.name_key, "competence": _nom_competence(cle), "niveau": int(e.competences[cle]), "potentiel": int(e.potentiels.get(cle, 80))}])
		Etres.recalculer(e, items, affixes_defs, regles)


## Une stat progresse comme une compétence (même courbe, même potentiel) ; un niveau = +1 à la stat.
func _verser_stat(e: Dictionary, stat: String, xp: int) -> void:
	if xp <= 0:
		return
	var cle := "stat:" + stat
	e.competences[cle] = int(e.corps.stats[stat])
	var gagnes := progression.verser(e, cle, xp)
	if gagnes > 0:
		e.corps.stats[stat] = int(e.corps.stats[stat]) + gagnes
		EventBus.emettre(&"journal", [&"journal.niveau", {"nom": e.name_key, "competence": "stat." + stat, "niveau": int(e.corps.stats[stat]), "potentiel": int(e.potentiels.get(cle, 80))}])
		Etres.recalculer(e, items, affixes_defs, regles)
	e.competences.erase(cle)


func _nom_competence(cle: String) -> String:
	if GameData.existe("competences", cle):
		return str(GameData.entree("competences", cle).name_key)
	if GameData.existe("modules", cle):
		return str(GameData.entree("modules", cle).name_key)
	return cle


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
		"ennemi": return ennemis(e, c)
		"allie": return not ennemis(e, c) and c.id != e.id
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
	var ticks_arme := regles.ticks_attaque(fonct, false, arme) if not fonct.is_empty() else int(regles.r.actions.attaque_base)
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
		"competence": str(plan.fonct.get("combat_skill", "")) if arme_noyau else "magie_" + wuxing.dominante(plan.elements), "modules": plan.modules,
		"construction": str(piece.get("construction", "")), "evites": maxi(0, roundi(bruts * zone.mult) - degats)}


# ---------------------------------------------------------------- engagement (Temporalités parallèles)

## Place `a` et `b` dans la même horloge de combat (créée au besoin), compteurs rebasés.
func _engager_combat(a: Dictionary, b: Dictionary) -> void:
	if a.get("huile_feu", false) and not en_combat(a):
		a.erase("huile_feu")
		a["degats_element_bonus"] = {"feu": "1d4"}   # consommé par le premier combat (Nourriture : huile d'arme)
	if not ennemis(a, b):
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
			dernier_combat = {"nom": nom, "ticks": h.ticks, "participants": c.participants.duplicate(), "victoire": true, "niveaux": niveaux_gagnes.duplicate()}
			niveaux_gagnes.clear()
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
			_ia_fuir(e, cible if not cible.is_empty() else entites.get(str(e.get("menace", "")), {}), tick)
		"suivre":
			_ia_pas_routine(e, entites[str(e.maitre)].pos, tick)
		"routine":
			_ia_pas_routine(e, _cible_routine(e, profil), tick)
		"errer":
			_ia_errer(e, tick)
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
			if not ennemis(e, autre):
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
			"joueur_proche": 1.0 if Grille.distance(e.pos, cible.pos) <= 6 else 0.0, "menace_en_vue": 1.0}
	if e.pos != e.ancre:
		c["retour"] = {"loin_de_l_ancre": 1.0 if Grille.distance(e.pos, e.ancre) > int(regles.r.engagement.ia_distance_ancre) else 0.0,
			"cible_perdue": 0.0 if a_cible else 1.0}
	c["attendre"] = {"endurance_basse": 1.0 if e.endurance < 20 else 0.0, "calme": 0.0 if a_cible else 1.0}
	if e.has("maitre") and entites.has(str(e.maitre)):
		var m: Dictionary = entites[str(e.maitre)]
		var loin := Grille.distance(e.pos, m.pos) > int(regles.r.compagnons.distance_suivi)
		c["suivre"] = {"loin_du_maitre": 1.0 if (loin and str(e.get("ordre", "suivre")) == "suivre") else 0.0}
	if not a_cible and not e.has("maitre"):
		c["errer"] = {"calme": 1.0}
		if profil.get("horaires") != null and lieu == "camp":
			var cible_r := _cible_routine(e, profil)
			c["routine"] = {"hors_poste": 1.0 if cible_r != e.pos else 0.0}
	if not a_cible and not e.get("fuite", false) and lieu == "camp":
		for autre in vivants():   # une menace en vue sans être engagé : les proies et les civils fuient
			if ennemis(e, autre) and Grille.distance(e.pos, autre.pos) <= 8 and voit_ia(e, autre):
				c["fuir"] = {"menace_en_vue": 1.0, "joueur_proche": 1.0 if Grille.distance(e.pos, autre.pos) <= 6 else 0.0, "sante_basse": 1.0 if sante_basse else 0.0}
				e["menace"] = autre.id
				break
	return c


## Une IA voit-elle un être ? (portée de Perception et ligne de vue)
func voit_ia(e: Dictionary, autre: Dictionary) -> bool:
	var portee := int(float(e.corps.stats.perception) * float(regles.r.engagement.detection_par_perception))
	return Grille.distance(e.pos, autre.pos) <= portee and grille.ligne_de_vue(e.pos, autre.pos)


## La cible de la routine horaire d'un PNJ (IA des créatures) : poste, place ou lit selon l'heure.
func _cible_routine(e: Dictionary, profil: Dictionary) -> Vector2i:
	var h := heure()
	var activite := "poste"
	for plage in profil.horaires.keys():
		var parts: PackedStringArray = str(plage).split("-")
		var a := float(parts[0])
		var b := float(parts[1])
		if (a <= b and h >= a and h < b) or (a > b and (h >= a or h < b)):
			activite = str(profil.horaires[plage])
	match activite:
		"lit":
			return e.get("lit", e.ancre)
		"social":
			return e.get("place", e.ancre)
		_:
			if e.ai_profile == "garde":   # le garde patrouille autour de son ancrage
				var pat: Vector2i = e.get("patrouille", e.ancre)
				if pat == e.pos or pat == e.ancre:
					var r := int(GameData.config("planete").routine.rayon_patrouille)
					var rng := RandomNumberGenerator.new()
					rng.seed = hash([graine, e.id, horloge_monde.ticks])
					for essai in 8:
						var q: Vector2i = e.ancre + Vector2i(rng.randi_range(-r, r), rng.randi_range(-r, r))
						if grille.dans(q) and not grille.bloque_passage(q):
							pat = q
							break
					e["patrouille"] = pat
				return pat
			return e.get("poste", e.ancre)


## Un pas de routine : glouton (la case adjacente libre la plus proche de la cible), A* sous 20 tuiles.
func _ia_pas_routine(e: Dictionary, cible: Vector2i, tick: int) -> void:
	if cible == e.pos:
		_attendre(e, tick)
		return
	if Grille.distance(e.pos, cible) <= int(GameData.config("planete").routine.astar_sous):
		var chemin := grille.chemin(e.pos, cible, Etres.est_volant(e))
		if chemin.size() > 0:
			if _deplacer(e, chemin[0], tick):
				return
	var meilleur: Vector2i = e.pos
	var dmin := Grille.distance(e.pos, cible)
	for d in Grille.DIRS:
		var q: Vector2i = e.pos + d
		if grille.dans(q) and not grille.bloque_passage(q) and grille.occupant(q).is_empty() and Grille.distance(q, cible) < dmin:
			dmin = Grille.distance(q, cible)
			meilleur = q
	if meilleur == e.pos or not _deplacer(e, meilleur, tick):
		_attendre(e, tick)


## Errer : un pas au hasard sur une case libre, sans s'éloigner de plus de 12 tuiles de l'ancrage.
func _ia_errer(e: Dictionary, tick: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, e.id, tick])
	var d: Vector2i = Grille.DIRS[rng.randi_range(0, Grille.DIRS.size() - 1)]
	var q: Vector2i = e.pos + d
	if grille.dans(q) and not grille.bloque_passage(q) and grille.occupant(q).is_empty() and Grille.distance(q, e.ancre) <= 12 and _deplacer(e, q, tick):
		return
	_attendre(e, tick)


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
