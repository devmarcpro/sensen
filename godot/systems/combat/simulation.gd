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
static var slot_autosave := "monde"  # l'emplacement des sauvegardes automatiques — les tests et le fuzz le détournent pour ne jamais écraser une vraie partie
var prochain_donjon: int = 1         # id du prochain donjon lancé depuis le camp
var monde: Monde = null              # la surface comme fenêtre glissante (étape 8.2a)
var bombes: Array = []               # les bombes posées, en attente d'explosion (Explosions)
var affuts: Array[Dictionary] = []   # tourelles portatives de L'Engrenage : {pos, source, prochain}
var pluie_heure := -1   # la dernière heure de monde où la pluie a rempli les creux
var foudre_heure := -1   # la dernière heure d'orage où la foudre a frappé (Météo)
var evapo_heure := -1   # la dernière heure de canicule où les flaques ont baissé
var eau_active: Dictionary = {}   # idx → true : tuiles de liquide à propager (Eau et liquides)
var feux: Dictionary = {}   # idx → {reste} : tuiles en feu (Météo : le feu de tuile)
var feu_prochain_pas := 0
var canicule_heure := -1
var arrachage_heure := -1   # la dernière heure de tempête où le vent a arraché (Météo)
var eau_prochain_pas := 0
var modifs_terrain: Dictionary = {}   # **position monde** → {h, contenu} d'origine : ce que le monde rendra hors claim
                                     # (Destruction du terrain). Jamais un index de grille : la fenêtre glisse.
var vecteur_lieu_force: Dictionary = {}   # tests et arènes : imposer le vecteur du lieu (Wu Xing hors combat)
var portails: Dictionary = {}   # **position monde** → id du Passeur qui l'a ouverte (Talents de classe)
var territoire: Dictionary = {"tresor": 0, "dette": 0, "semaines_dette": 0, "stocks": {}, "rapports": [], "gains_quetes": 0, "royaume": false,
	"cultures": {}, "fertilite": {}, "etals": {}, "caisse": 0, "marge": 1.0, "clients": 0.0, "heure_resolue": -1, "absence": {"ventes": 0, "or": 0, "mures": 0},
	"gouvernance": "", "gouvernance_cible": "", "transition": 0, "raid": {}, "dernier_raid": {}, "accords": {}}   # le royaume du joueur (étape 10)
var objets: Dictionary = {}          # uid → instance générée (le catalogue reste dans `items`, fusionné)
var contenants: Dictionary = {}      # index de tuile → [uids] (coffres, butin au sol)
var dernier_combat: Dictionary = {}   # récapitulatif du dernier combat terminé (écran de fin)
var glyphes: Array[Dictionary] = []   # couche d'overlay runtime : {pos, plan, source, fin} — jamais sauvegardée
## Les zones au sol (Modules — Racine, Sol vif, Nappe, Voile de brume, Balise) : une tuile marquée qui agit
## sur ce qui y passe, ou sur la vue. Clés en **position monde** (la fenêtre glisse), vidées au changement de
## grille comme les feux. {pos, type, fin, source, params}
var zones: Array[Dictionary] = []
var differes: Array[Dictionary] = []  # charges différées : {tick, source, plan, pos}
var obstacles: Array[Dictionary] = [] # invocations temporaires : {pos, fin}
var horloge_monde: Horloge
var combats: Dictionary = {}          # nom → {"horloge": Horloge, "participants": Array[String]}
var attente: Dictionary = {}          # id → true : une entité contrôlée attend une intention
var _n_combats := 0
var _n_entites := 0


var lot_simultane: Array[String] = []   # les êtres dont l'action part à ce tick (Boucle de tick) : un mort du lot frappe et est frappé quand même
var graine_monde := -1   # la graine du monde choisie à l'écran Monde (Écrans d'interface) ; -1 = celle de planete.json


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
	if camp_sauve.has("grille"):   # un camp mis de côté (pas seulement ses métadonnées : biome…)
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
	var surface := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, graine_monde if graine_monde >= 0 else int(planete.graine))
	monde = Monde.new(surface, planete, cfg)
	var depart := monde.cellule_camp if cellule_choisie == Vector2i(-1, -1) else cellule_choisie
	# Garde-fou (Début de partie) : si la cellule de départ est en mer, la première cellule de terre en spirale.
	var essais := 0
	var origine_spirale := depart
	while essais < 400 and not surface.terre_a(depart):
		essais += 1
		var r := 1
		var trouve := false
		while r < 96 and not trouve:   # une graine peut poser (512, 512) en plein océan : on cherche loin (2026-08-30 : 4 graines sur 16 démarraient en mer)
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
	# Une partie commence à heure_depart (Cycle jour-nuit, designer 2026-08-30 : 8 h) ; une sauvegarde garde son heure.
	var cy: Dictionary = planete.get("cycle", {})
	horloge_monde.ticks = int(float(cy.get("heure_depart", 0)) / 24.0 * float(cy.get("ticks_par_jour", 24000)))
	if joueur.is_empty():
		var j := ajouter("aventurier", entree, "joueur")
		j.spawn = entree
	else:
		_reprendre(joueur, entree)
	for x in entites.values():   # les compteurs des premiers êtres partent de l'heure de départ, pas de minuit
		x.compteur = horloge_monde.ticks
		x.tick_endurance = horloge_monde.ticks
		if x.has("faim_tick"):
			x.faim_tick = horloge_monde.ticks
		joueur.spawn = entree
	var uids: Array = []
	for base in cfg.coffre_depart:
		var o := generer_objet(str(base), 1, {}, "commun", 0)
		if not o.is_empty():
			uids.append(o.uid)
	_poser_contenant(monde.pos_monde(depart, e.coffre_depart), uids, "coffre")
	var pnj_sauves: Dictionary = camp_sauve.get("entites", {})   # une sauvegarde en expédition : les PNJ du camp reviennent
	var ordre_sauves: Array = camp_sauve.get("ordre", [])
	var cont_sauves: Dictionary = camp_sauve.get("contenants_pos", {})
	camp_sauve = {"entree": entree, "biome": e.biome, "cellule": depart}
	_peupler_fenetre()
	for id in ordre_sauves:
		if not entites.has(id) and pnj_sauves.has(id):
			var x2: Dictionary = pnj_sauves[id]
			entites[id] = x2
			ordre.append(id)
			if x2.vivant and grille.dans(x2.pos) and grille.occupant(x2.pos).is_empty():
				grille.placer(id, x2.pos)
	for pos in cont_sauves.keys():
		if grille.dans(pos):
			contenants[grille.idx(pos)] = cont_sauves[pos]
			if grille.contenu_de(pos).is_empty():
				grille.poser_contenu(pos, "butin")
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
			var cell := _cell_de(x.pos)
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
	_vider_etats_tuiles()   # la fenêtre a glissé : les index de l'ancienne grille ne veulent plus rien dire
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
	if lieu == "camp" and not joueur.is_empty() and monde != null and not camp_sauve.has("grille"):
		_sauver_camp(joueur)   # descendre depuis le camp sans passer par l'expédition : le camp est quand même mis de côté
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
		_reinitialiser()   # vide aussi les feux et l'eau en cours de l'étage quitté
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
	grille.materiau_defaut = materiau_mur_etage(theme, etage)
	_poches_de_strates(theme, etage, graine, id_donjon)
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


## Les états indexés par tuile ne valent que pour la grille courante : tout changement de grille les vide
## (voyage, donjon, retour au camp, chargement). Sans ça, un feu continue de brûler les mêmes index ailleurs.
## Les zones au sol posées sur une tuile (Modules) — une tuile peut en porter plusieurs.
func zones_sur(pos: Vector2i, type: String = "") -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for z: Dictionary in zones:
		if z.pos == pos and (type.is_empty() or str(z.type) == type):
			res.append(z)
	return res


## Ce qu'une zone fait à celui qui entre sur sa tuile (appelé après chaque pas).
## Un plan discret (Sans trace, Silencieux) pose des zones cachées : des pièges (Six types de modules, 2026-08-30).
func _plan_discret(plan: Dictionary) -> bool:
	var dr: Dictionary = plan.get("drapeaux", {})
	return bool(dr.get("sans_trace", false)) or bool(dr.get("silencieux", false))


func _zones_a_l_entree(e: Dictionary, pos: Vector2i, tick: int) -> void:
	for z in zones_sur(pos):
		if bool(z.get("cachee", false)) and str(z.get("source", "")) != e.id:
			z.cachee = false   # le piège se révèle sur celui qui y met le pied
			EventBus.emettre(&"journal", [&"journal.piege_revele", {"nom": e.name_key, "zone": "zone." + str(z.type)}])
		match str(z.type):
			"entrave":   # Racine : ce qui s'arrête là s'enracine
				appliquer_statut(e, str(z.params.get("statut", "enracinement")), int(z.params.get("statut_ticks", 20)), str(z.source))
			"blessure":   # Sol vif : la tuile blesse ce qui la traverse
				var deg := des.jet(str(z.params.get("degats", "1d6")))
				EventBus.emettre(&"journal", [&"journal.zone_blesse", {"nom": e.name_key, "degats": deg}])
				_appliquer_degats(e, deg, str(z.source), {"type": "zone", "element": z.get("elements", {})})
			"portail":   # Portail : deux tuiles appairées, on entre par l'une et on sort par l'autre
				var paire: Array[Dictionary] = []
				for z2 in zones:
					if str(z2.type) == "portail" and str(z2.source) == str(z.source) and z2.pos != pos:
						paire.append(z2)
				if not paire.is_empty():
					var sortie: Vector2i = paire.back().pos
					if grille.dans(sortie) and grille.occupant(sortie).is_empty() and not grille.bloque_passage(sortie):
						grille.liberer(e.pos)
						e.pos = sortie
						grille.placer(e.id, sortie)
						EventBus.emettre(&"journal", [&"journal.portail_traverse", {"nom": e.name_key}])
			"remanence":   # Rémanence : la charge se rejoue sur qui entre dans la zone
				var src_r: Dictionary = entites.get(str(z.source), {})
				if not src_r.is_empty() and src_r.get("vivant", false) and src_r.id != e.id:
					_appliquer_charge(src_r, z.params.plan, [e] as Array[Dictionary], [pos] as Array[Vector2i], pos, {})
			"vapeur":   # Vapeur : le nuage applique son statut à ce qui entre
				appliquer_statut(e, str(z.params.get("statut", "confusion")), int(z.params.get("statut_ticks", 20)), str(z.source))
			"glissante":   # Nappe : on glisse d'une tuile de plus, dans son élan
				var suite: Vector2i = pos + e.orientation
				if grille.dans(suite) and grille.occupant(suite).is_empty() and not grille.bloque_passage(suite) and grille.cout_pas(pos, suite, Etres.est_volant(e)) >= 0:
					grille.liberer(pos)
					e.pos = suite
					grille.placer(e.id, suite)
					EventBus.emettre(&"journal", [&"journal.glisse", {"nom": e.name_key}])
					_zones_a_l_entree(e, suite, tick)


## Les zones expirées s'effacent (appelé avec les glyphes).
func _tiquer_zones(tick: int) -> void:
	var restantes: Array[Dictionary] = []
	for z in zones:
		if int(z.fin) > tick:
			restantes.append(z)
		else:
			EventBus.emettre(&"tile_changed", [z.pos])
	zones = restantes


func _vider_etats_tuiles(change_de_lieu: bool = false) -> void:
	zones.clear()
	if change_de_lieu:   # camp ↔ donjon : deux espaces de coordonnées, rien ne se transporte
		modifs_terrain.clear()
		portails.clear()
		bombes.clear()   # une bombe lancée au camp n'explose pas au fond du donjon
		affuts.clear()
	feux.clear()
	eau_active.clear()
	glyphes.clear()
	obstacles.clear()
	feu_prochain_pas = 0
	eau_prochain_pas = 0


func _reinitialiser() -> void:
	_vider_etats_tuiles(true)
	entites.clear()
	ordre.clear()
	combats.clear()
	attente.clear()
	contenants = {}   # jamais clear() : un lieu mis de côté garde la référence à ses contenants
	differe_clear()
	for nom in TickManager.horloges.keys():
		TickManager.retirer(nom)
	horloge_monde = TickManager.creer("monde", Horloge.Mode.TEMPS_REEL, float(regles.r.ticks_par_seconde_exploration))
	if temps_a_l_action():
		horloge_monde.mode = Horloge.Mode.ACTION   # en donjon, le temps n'avance qu'à l'action (Boucle de tick, 2026-08-30)
	horloge_monde.avancee.connect(_sur_avancee_monde)


## En donjon, l'horloge du monde est une horloge d'action : elle s'arrête sur le joueur tant qu'il réfléchit.
func temps_a_l_action() -> bool:
	return lieu == "donjon" and bool(regles.r.get("donjon", {}).get("temps_a_l_action", false))


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
## Mémoriser l'état d'origine d'une tuile avant de la modifier (régénération des cases sauvages).
func _memoriser_terrain(t: Vector2i) -> void:
	if not modifs_terrain.has(t):
		modifs_terrain[t] = {"h": grille.h(t), "contenu": int(grille.contenu[grille.idx(t)])}
	_reveiller_eau_autour(t)


## Une tuile modifiée réveille les liquides voisins (Eau et liquides) : la tranchée s'inonde, le talus endigue.
func _reveiller_eau_autour(t: Vector2i) -> void:
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = t + dd
		if grille.dans(q) and grille.niveau_liquide(q) > 0:
			eau_active[grille.idx(q)] = true


## L'automate d'eau (Eau et liquides) : chaque tuile active verse vers ses quatre voisines.
func _tiquer_eau(tick: int) -> void:
	if eau_active.is_empty() or tick < eau_prochain_pas:
		return
	var ea: Dictionary = regles.r.get("eau", {})
	eau_prochain_pas = tick + int(ea.get("periode_ticks", 5))
	var budget := int(ea.get("tuiles_par_pas", 64))
	var portee := int(ea.get("portee", 7))
	for idx in eau_active.keys():
		if budget <= 0:
			break
		budget -= 1
		eau_active.erase(idx)
		var t := grille.pos_de(int(idx))
		var niveau := grille.niveau_liquide(t)
		if niveau < 8 and niveau > 0 and not _alimentee(t):   # plus rien ne l'alimente : elle ne verse plus, et se retire si elle n'est pas dans un creux
			if not _en_creux(t):
				_retirer_eau(t)
			continue
		if niveau <= 1:
			continue
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = t + dd
			if not grille.dans(q) or grille.bloque_passage(q) or grille.meubles.has(grille.idx(q)):
				continue
			var cible := 0
			if grille.h(q) < grille.h(t):
				cible = portee   # elle descend le relief et remplit le creux
			elif grille.h(q) == grille.h(t):
				cible = niveau - 1   # elle s'étale en perdant un niveau par tuile
			if cible <= 0 or grille.niveau_liquide(q) >= cible:
				continue
			_poser_eau(q, cible)


## La direction du courant sur une tuile d'écoulement (Eau et liquides) : là où l'eau s'en va — la voisine
## la plus basse, sinon celle du niveau le plus faible. Zéro sur une source, sur la glace, ou dans un creux.
func courant_de(t: Vector2i) -> Vector2i:
	var niveau := grille.niveau_liquide(t)
	if niveau <= 0 or niveau >= 8 or grille.gel:
		return Vector2i.ZERO
	var meilleure := Vector2i.ZERO
	var meilleur_h := grille.h(t)
	var meilleur_niv := niveau
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = t + dd
		if not grille.dans(q) or grille.bloque_passage(q):
			continue
		if grille.h(q) < meilleur_h:
			meilleur_h = grille.h(q)
			meilleur_niv = grille.niveau_liquide(q)
			meilleure = dd
		elif grille.h(q) == meilleur_h and meilleure == Vector2i.ZERO and grille.niveau_liquide(q) < meilleur_niv:
			meilleur_niv = grille.niveau_liquide(q)
			meilleure = dd
	return meilleure


## Le courant emporte ce qui flotte (Eau et liquides) : les êtres légers, puis les objets au sol.
func _tiquer_courant(tick: int) -> void:
	var ea: Dictionary = regles.r.get("eau", {})
	var chance := float(ea.get("courant_chance", 0.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "courant", tick])
	for x in vivants():
		if grille.niveau_liquide(x.pos) <= 0 or rng.randf() >= chance:
			continue
		var pd := poids_de(x)   # la charge relative, pas le facteur de surcharge : à moitié chargé, on tient déjà
		if float(pd.capacite) > 0.0 and float(pd.poids) / float(pd.capacite) > float(ea.get("courant_poids", 0.5)):
			continue   # trop lourd pour dériver : on tient debout
		var d := courant_de(x.pos)
		if d == Vector2i.ZERO or not grille.dans(x.pos + d) or not grille.occupant(x.pos + d).is_empty():
			continue
		var avant: Vector2i = x.pos
		var compteur: int = int(x.compteur)
		if _deplacer(x, x.pos + d, tick_de(x)):
			x.compteur = compteur   # la dérive ne coûte aucun tick à qui la subit
			if x.pos != avant:
				EventBus.emettre(&"journal", [&"journal.emporte", {"nom": x.name_key}])
	for idx in contenants.keys().duplicate():
		var t := grille.pos_de(int(idx))
		if not ("butin" in grille.contenu_de(t).get("tags", [])) or grille.niveau_liquide(t) <= 0 or rng.randf() >= chance:
			continue
		var d2 := courant_de(t)
		if d2 == Vector2i.ZERO or not grille.dans(t + d2) or grille.bloque_passage(t + d2):
			continue
		var uids: Array = contenants[idx]
		contenants.erase(idx)
		grille.contenu[int(idx)] = 0
		EventBus.emettre(&"tile_changed", [t])
		_poser_contenant(t + d2, uids, "butin")


## Une tuile d'écoulement est alimentée si, en remontant le courant (voisine plus haute portant un liquide, ou de même hauteur d'un niveau
## supérieur), on atteint une source. Un simple regard aux voisines ne suffit pas : un bord qui s'assèche « nourrirait » l'intérieur.
func _alimentee(t: Vector2i) -> bool:
	var vus: Dictionary = {grille.idx(t): true}
	var file: Array[Vector2i] = [t]
	while not file.is_empty() and vus.size() < 128:
		var c: Vector2i = file.pop_front()
		var nc := grille.niveau_liquide(c)
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + dd
			if not grille.dans(q) or vus.has(grille.idx(q)):
				continue
			var nq := grille.niveau_liquide(q)
			if nq <= 0:
				continue
			if grille.h(q) > grille.h(c) or (grille.h(q) == grille.h(c) and nq > nc):
				if nq >= 8:
					return true
				vus[grille.idx(q)] = true
				file.append(q)
	return false


## Un creux : l'eau n'a nulle part où aller (chaque voisine est plus haute, bloquante, ou déjà liquide).
func _en_creux(t: Vector2i) -> bool:
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = t + dd
		if grille.dans(q) and grille.h(q) <= grille.h(t) and grille.niveau_liquide(q) == 0 and not grille.bloque_passage(q):
			return false
	return true


## L'eau se retire d'un niveau ; à sec, la tuile redevient du sol et ses voisines sont réévaluées.
func _retirer_eau(t: Vector2i, tout: bool = false) -> void:
	var ti := grille.idx(t)
	var niveau := grille.niveau_liquide(t)
	if niveau <= 0 or niveau >= 8:
		return
	if niveau > 1 and not tout:
		grille.niveau_eau[ti] = niveau - 1
		eau_active[ti] = true
	else:
		grille.contenu[ti] = 0
		grille.niveau_eau.erase(ti)
		EventBus.emettre(&"journal", [&"journal.retrait", {"x": t.x, "y": t.y}])
	grille.marquer(t)
	lumiere_sale = true
	_reveiller_eau_autour(t)
	EventBus.emettre(&"tile_changed", [t])


## Une source détruite disparaît (Eau et liquides) : la tuile redevient du sol, la nappe qu'elle nourrissait se retire.
func _retirer_source(t: Vector2i) -> void:
	if grille.niveau_liquide(t) < 8:
		return
	grille.contenu[grille.idx(t)] = 0
	grille.marquer(t)
	lumiere_sale = true
	EventBus.emettre(&"journal", [&"journal.source_comblee", {"x": t.x, "y": t.y}])
	_reveiller_eau_autour(t)
	EventBus.emettre(&"tile_changed", [t])


## La canicule (Météo, effet evapore) : chaque flaque non alimentée perd un niveau.
func _evaporation() -> void:
	var n := 0
	for ti in grille.niveau_eau.keys():
		var t := grille.pos_de(int(ti))
		if grille.niveau_liquide(t) in range(1, 8) and not _alimentee(t):
			_retirer_eau(t)
			n += 1
	if n > 0:
		EventBus.emettre(&"journal", [&"journal.evaporation", {}])


## Poser un écoulement de niveau donné (jamais sur une source) et le rendre actif.
func _poser_eau(q: Vector2i, niveau: int) -> void:
	var qi := grille.idx(q)
	if grille.niveau_liquide(q) >= 8:
		return
	var nouveau := grille.niveau_liquide(q) == 0
	grille.poser_contenu(q, "eau_ecoulement")
	grille.niveau_eau[qi] = clampi(niveau, 1, 7)
	grille.marquer(q)
	eau_active[qi] = true
	lumiere_sale = true
	if nouveau:
		EventBus.emettre(&"journal", [&"journal.inondation", {"x": q.x, "y": q.y}])
	EventBus.emettre(&"tile_changed", [q])


## Une goutte sur une tuile : elle ne prend qu'un creux ouvert (plus bas que ses quatre voisines), un niveau, jamais plus.
func _pluie_sur(t: Vector2i) -> bool:
	if not grille.dans(t) or grille.bloque_passage(t) or grille.niveau_liquide(t) > 0 or grille.meubles.has(grille.idx(t)) or not grille.occupant(t).is_empty():
		return false
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = t + dd
		if not grille.dans(q) or grille.h(q) <= grille.h(t):
			return false
	_poser_eau(t, 1)
	eau_active.erase(grille.idx(t))   # une flaque de pluie ne se propage pas
	return true


## La lave (Eau et liquides) : elle brûle qui s'y tient, enflamme ses voisines, et se fige au contact de l'eau.
func _tiquer_lave(tick: int) -> void:
	if tick < eau_prochain_pas:
		return
	var lv: Dictionary = regles.r.get("lave", {})
	for idx in grille.dangers.keys():
		var t := grille.pos_de(int(idx))
		if not ("lave" in grille.contenu_de(t).get("tags", [])):
			continue
		var occ := grille.occupant(t)
		if not occ.is_empty() and entites.has(occ) and entites[occ].vivant:
			var x: Dictionary = entites[occ]
			var deg := des.jet(str(lv.get("degats", "3d6")))
			_appliquer_degats(x, deg, "", {"type": "lave", "element": {"feu": 1.0}})
			appliquer_statut(x, "brulure", int(lv.get("brulure_ticks", 40)), "")
			EventBus.emettre(&"journal", [&"journal.lave_brule", {"nom": x.name_key, "degats": deg}])
		var fige := ""
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = t + dd
			if not grille.dans(q):
				continue
			var niv := grille.niveau_liquide(q)
			if niv >= 8:
				fige = str(lv.get("obsidienne_source", "obsidienne"))
			elif niv > 0:
				if fige.is_empty():
					fige = str(lv.get("pierre_ecoulement", "basalte"))
				grille.contenu[grille.idx(q)] = 0   # l'écoulement s'évapore au contact
				grille.niveau_eau.erase(grille.idx(q))
				grille.marquer(q)
				EventBus.emettre(&"tile_changed", [q])
			else:
				_enflammer(q)
		if not fige.is_empty():
			_figer_lave(t, fige)


## La lave figée par l'eau : obsidienne au contact d'une source, basalte au contact d'un écoulement.
func _figer_lave(t: Vector2i, materiau: String) -> void:
	var idx := grille.idx(t)
	grille.poser_contenu(t, "obsidienne_figee")
	grille.materiaux[idx] = materiau
	grille.dangers.erase(idx)
	grille.marquer(t)
	lumiere_sale = true
	EventBus.emettre(&"journal", [&"journal.lave_figee", {"x": t.x, "y": t.y}])
	EventBus.emettre(&"tile_changed", [t])


## La flammabilité d'une tuile (Météo : le feu) : celle du matériau de son contenu, d'une culture, ou de son sol nu.
func flammabilite_de(t: Vector2i) -> int:
	if not grille.dans(t) or grille.niveau_liquide(t) > 0 or grille.gel:
		return 0
	var fe: Dictionary = regles.r.get("feu", {})
	var tags: Array = grille.contenu_de(t).get("tags", [])
	if "culture" in tags:
		return int(fe.get("flamm_culture", 60))
	if "plante_sauvage" in tags:
		return int(fe.get("flamm_plante_sauvage", 50))
	if "vegetation" in tags or "construit" in tags or "mur" in tags:
		return int(GameData.catalogues.materials.get(grille.materiau_de(t), {}).get("stats", {}).get("flammabilite", 0))
	if tags.is_empty() and grille.meubles.has(grille.idx(t)):
		return 40
	if tags.is_empty():
		return int(GameData.catalogues.materials.get(grille.materiau_sol(t), {}).get("stats", {}).get("flammabilite", 0))
	return 0


## Une tuile prend feu si elle brûle ; retourne vrai si un feu vient de naître.
func _enflammer(t: Vector2i) -> bool:
	if flammabilite_de(t) <= 0 or feux.has(grille.idx(t)):
		return false
	feux[grille.idx(t)] = {"reste": int(regles.r.get("feu", {}).get("duree_ticks", 80))}
	grille.dangers[grille.idx(t)] = true
	lumiere_sale = true
	EventBus.emettre(&"journal", [&"journal.feu_prend", {"x": t.x, "y": t.y}])
	EventBus.emettre(&"tile_changed", [t])
	return true


## Le pas du feu : brûle qui s'y tient, gagne ses voisines, s'éteint sous la pluie, consume la tuile au bout de sa durée.
func _tiquer_feux(tick: int) -> void:
	if feux.is_empty() or tick < feu_prochain_pas:
		return
	var fe: Dictionary = regles.r.get("feu", {})
	var periode := int(fe.get("periode_ticks", 10))
	feu_prochain_pas = tick + periode
	var effets: Array = []
	if lieu == "camp" and monde != null:
		effets = GameData.catalogues.weather_states.get(meteo(monde.cellule_de(grille.pos_de(grille.largeur * grille.hauteur_grille / 2))), {}).get("effects", [])
	if "eteint_feux" in effets or "neige" in effets or grille.neige:
		var n := feux.size()
		for idx in feux.keys():
			grille.dangers.erase(idx)
			EventBus.emettre(&"tile_changed", [grille.pos_de(int(idx))])
		feux.clear()
		lumiere_sale = true
		EventBus.emettre(&"journal", [&"journal.feux_eteints", {"n": n}])
		return
	var vent := float(fe.get("vent_mult", 2.0)) if ("vent" in effets or "tempete" in effets) else 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "feu", tick])
	for idx in feux.keys():
		var t := grille.pos_de(int(idx))
		var occ := grille.occupant(t)
		if not occ.is_empty() and entites.has(occ) and entites[occ].vivant:
			var x: Dictionary = entites[occ]
			var deg := des.jet(str(fe.get("degats", "1d6")))
			_appliquer_degats(x, deg, "", {"type": "feu", "element": {"feu": 1.0}})
			appliquer_statut(x, "brulure", int(fe.get("brulure_ticks", 30)), "")
			EventBus.emettre(&"journal", [&"journal.brule", {"nom": x.name_key, "degats": deg}])
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = t + dd
			var fl := flammabilite_de(q)
			if fl > 0 and not feux.has(grille.idx(q)) and rng.randf() < float(fl) / 100.0 * float(fe.get("propagation", 0.35)) * vent:
				_enflammer(q)
		feux[idx].reste = int(feux[idx].reste) - periode
		if int(feux[idx].reste) <= 0:
			_consumer(t)


## La tuile consumée : son contenu s'en va, le terrain est mémorisé (il repousse hors claim).
func _consumer(t: Vector2i) -> void:
	var idx := grille.idx(t)
	feux.erase(idx)
	grille.dangers.erase(idx)
	if grille.contenu[idx] != 0 and not ("contenant" in grille.contenu_de(t).get("tags", [])):
		_memoriser_terrain(t)
		grille.contenu[idx] = 0
		grille.marquer(t)
	if grille.meubles.has(idx):
		grille.meubles.erase(idx)
		grille.marquer(t)
	lumiere_sale = true
	EventBus.emettre(&"journal", [&"journal.feu_consume", {"x": t.x, "y": t.y}])
	EventBus.emettre(&"tile_changed", [t])


## La tempête (effet météo arrache_fragiles) : quelques tuiles très fragiles et exposées s'envolent.
func _arrachage(tick: int) -> void:
	var fe: Dictionary = regles.r.get("feu", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "arrachage", tick])
	var centre := grille.pos_de(grille.largeur * grille.hauteur_grille / 2)
	for x in vivants():
		if x.controle == "joueur":
			centre = x.pos
			break
	var portee := int(fe.get("arrachage_portee", 20))
	var reste := int(fe.get("arrachage_tuiles", 3))
	for essai in 60:
		if reste <= 0:
			return
		var t := centre + Vector2i(rng.randi_range(-portee, portee), rng.randi_range(-portee, portee))
		if _arracher(t, int(fe.get("arrachage_durete", 3))):
			reste -= 1


## Une tuile s'arrache si son matériau est très tendre et qu'aucune voisine plus haute ne l'abrite.
func _arracher(t: Vector2i, durete_max: int) -> bool:
	if not grille.dans(t) or grille.contenu[grille.idx(t)] == 0 or grille.meubles.has(grille.idx(t)):
		return false
	if "contenant" in grille.contenu_de(t).get("tags", []) or grille.niveau_liquide(t) > 0:
		return false
	var mat: Dictionary = GameData.catalogues.materials.get(grille.materiau_de(t), {})
	if mat.is_empty() or int(mat.get("stats", {}).get("durete", 99)) > durete_max:
		return false
	for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if grille.dans(t + dd) and grille.h(t + dd) > grille.h(t):
			return false   # abritée par plus haut qu'elle
	_memoriser_terrain(t)
	grille.contenu[grille.idx(t)] = 0
	grille.marquer(t)
	lumiere_sale = true
	EventBus.emettre(&"journal", [&"journal.arrachage", {"x": t.x, "y": t.y}])
	EventBus.emettre(&"tile_changed", [t])
	return true


## La canicule (effet météo ignition) : chaque heure, une chance qu'une tuile inflammable prenne autour du joueur.
func _ignition_canicule(tick: int) -> void:
	var fe: Dictionary = regles.r.get("feu", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "canicule", tick])
	if rng.randf() >= float(fe.get("canicule_chance", 0.15)):
		return
	var centre := grille.pos_de(grille.largeur * grille.hauteur_grille / 2)
	for x in vivants():
		if x.controle == "joueur":
			centre = x.pos
			break
	var portee := int(fe.get("canicule_portee", 20))
	for essai in 40:
		var t := centre + Vector2i(rng.randi_range(-portee, portee), rng.randi_range(-portee, portee))
		if _enflammer(t):
			return


## La foudre de l'orage (Météo) : un impact par heure, ciblé par hauteur et conductivité autour du joueur.
func _foudre(tick: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "foudre", tick])
	var centre := grille.pos_de(grille.largeur * grille.hauteur_grille / 2)
	for x in vivants():
		if x.controle == "joueur":
			centre = x.pos
			break
	var t := _cible_foudre(rng, centre)
	if grille.dans(t):
		_frapper_foudre(t)


## La tuile que la foudre choisit : la plus haute et la plus conductrice parmi des candidates au hasard (paratonnerre émergent).
func _cible_foudre(rng: RandomNumberGenerator, centre: Vector2i) -> Vector2i:
	var ea: Dictionary = regles.r.get("eau", {})
	var portee := int(ea.get("foudre_portee_joueur", 24))
	var meilleure := Vector2i(-1, -1)
	var score_max := -1.0
	for essai in int(ea.get("foudre_candidats", 40)):
		var t := centre + Vector2i(rng.randi_range(-portee, portee), rng.randi_range(-portee, portee))
		if not grille.dans(t):
			continue
		var score := float(grille.h(t)) * 10.0 + rng.randf()
		if grille.bloque_passage(t):   # un relief ou un mur : son matériau compte
			score += float(GameData.entree("materials", grille.materiau_de(t)).get("stats", {}).get("conductivite_electrique", 5))
		if score > score_max:
			score_max = score
			meilleure = t
	return meilleure


## L'impact : 3d8 en zone 1, puis la nappe d'eau connexe (Eau et liquides : conductivité).
func _frapper_foudre(t: Vector2i) -> void:
	var ea: Dictionary = regles.r.get("eau", {})
	EventBus.emettre(&"journal", [&"journal.foudre", {"x": t.x, "y": t.y}])
	lumiere_sale = true
	_enflammer(t)   # ignition
	var touches: Dictionary = {}
	for x in vivants():
		if Grille.distance(x.pos, t) <= 1:
			touches[x.id] = true
			_appliquer_degats(x, des.jet(str(ea.get("foudre_des", "3d8"))), "", {"type": "foudre"})
	if grille.niveau_liquide(t) <= 0 or grille.gel:
		return
	var rayon := int(ea.get("foudre_rayon_mer", 8)) if grille.niveau_liquide(t) >= 8 else int(ea.get("foudre_rayon_eau", 5))
	var nappe: Dictionary = {grille.idx(t): true}
	var file: Array[Vector2i] = [t]
	while not file.is_empty():
		var c: Vector2i = file.pop_front()
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + dd
			if grille.dans(q) and not nappe.has(grille.idx(q)) and Grille.distance(q, t) <= rayon and grille.niveau_liquide(q) > 0:
				nappe[grille.idx(q)] = true
				file.append(q)
	var n := 0
	for x in vivants():
		if not touches.has(x.id) and nappe.has(grille.idx(x.pos)):
			n += 1
			_appliquer_degats(x, des.jet(str(ea.get("foudre_des", "3d8"))), "", {"type": "foudre"})
	if n > 0:
		EventBus.emettre(&"journal", [&"journal.foudre_eau", {"n": n}])


## La pluie (Météo) remplit les creux ouverts d'un niveau : des tuiles plus basses que leurs quatre voisines.
func _pluie(tick: int) -> void:
	var ea: Dictionary = regles.r.get("eau", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "pluie", tick])
	var n := 0
	for essai in int(ea.get("pluie_tuiles", 20)) * 8:
		if n >= int(ea.get("pluie_tuiles", 20)):
			break
		var t := grille.pos_de(rng.randi_range(0, grille.largeur * grille.hauteur_grille - 1))
		if _pluie_sur(t):
			n += 1
	if n > 0:
		EventBus.emettre(&"journal", [&"journal.pluie_creux", {}])


## Terrasser (Destruction du terrain) : ±1 de hauteur sur une tuile de sol adjacente ; élever demande une pioche.
func _terrasser(e: Dictionary, vers: Vector2i, sens: int, tick: int) -> bool:
	var tr: Dictionary = regles.r.terrasser
	if not grille.dans(vers) or Grille.distance(e.pos, vers) != 1 or sens == 0:
		return false
	if grille.bloque_passage(vers) or not grille.occupant(vers).is_empty() or grille.meubles.has(grille.idx(vers)) or grille.stations_fixes.has(grille.idx(vers)):
		return false
	var h := grille.h(vers) + signi(sens)
	if h < int(tr.h_min) or h > int(tr.h_max):
		return false
	if sens > 0:
		var fonct: Dictionary = fonctionnalites.get(str(Etres.arme(e, items).get("functionality", "")), {})
		if not (str(fonct.get("outil", "")) in tr.outils_elever):   # pioche ou pelle (Destruction du terrain)
			EventBus.emettre(&"journal", [&"journal.terrasser_outil", {}])
			return false
	if e.endurance < int(tr.endurance):
		return false
	_memoriser_terrain(vers)
	grille.hauteurs[grille.idx(vers)] = h
	if sens > 0 and grille.niveau_liquide(vers) > 0:   # Eau et liquides : élever une tuile d'eau la comble (une source détruite disparaît)
		if grille.niveau_liquide(vers) >= 8:
			_retirer_source(vers)
		else:
			_retirer_eau(vers, true)
	e.endurance -= int(tr.endurance)
	e.compteur = tick + int(tr.ticks)
	e["vue_sale"] = true
	gagner_xp(e, "terrassement", int(tr.xp))
	EventBus.emettre(&"journal", [&"journal.terrasse", {"nom": e.name_key, "x": vers.x, "y": vers.y, "h": h}])
	EventBus.emettre(&"tile_changed", [vers])
	return true


## Chaque semaine, le monde efface les modifications de terrain hors des claims (Claims et persistance).
func _regenerer_terrain_sauvage() -> void:
	var n := 0
	for t in modifs_terrain.keys():
		if not grille.dans(t):
			continue   # hors de la fenêtre : la mémoire reste, la tuile redeviendra atteignable
		if monde != null and monde.claims.has(_cell_de(t)):
			continue
		if not grille.occupant(t).is_empty() or grille.meubles.has(grille.idx(t)) or grille.stations_fixes.has(grille.idx(t)):
			continue
		var o: Dictionary = modifs_terrain[t]
		grille.hauteurs[grille.idx(t)] = int(o.h)
		grille.contenu[grille.idx(t)] = int(o.contenu)
		modifs_terrain.erase(t)
		lumiere_sale = true
		EventBus.emettre(&"tile_changed", [t])
		n += 1
	if n > 0:
		EventBus.emettre(&"journal", [&"journal.regeneration", {"n": n}])


## Cueillir une plante sauvage adjacente (Plantes) : la moitié d'une récolte cultivée, la tuile repoussera hors claim.
func _cueillir(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if not grille.dans(vers) or Grille.distance(e.pos, vers) != 1:
		return false
	if not ("plante_sauvage" in grille.contenu_de(vers).get("tags", [])):
		return false
	var pid := grille.materiau_de(vers)
	var pl: Dictionary = GameData.catalogues.plants.get(pid, {})
	if pl.is_empty():
		return false
	var cu: Dictionary = regles.r.get("cueillette", {})
	var n := maxi(1, roundi(float(des.jet(str(cu.get("des", "1d2")))) * regles.skill_factor(regles.niveau(e.competences_eff, str(cu.get("competence", "collecte"))))))
	for k in n:
		var o := generer_objet(pid, 1, {}, "commun", 0)
		if not o.is_empty():
			donner(e, o.uid)
	_memoriser_terrain(vers)
	grille.contenu[grille.idx(vers)] = 0
	grille.marquer(vers)
	e.compteur = tick + int(regles.r.actions.objet)
	e["vue_sale"] = true
	gagner_xp(e, "herboristerie", 3)
	lumiere_sale = true
	EventBus.emettre(&"tile_changed", [vers])
	EventBus.emettre(&"journal", [&"journal.cueillette", {"nom": e.name_key, "plante": pl.name_key, "n": n}])
	return true


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
		var lent := false
		if force < durete * float(rr.seuil_irrecoltable):
			if a_talent(e, "oeil_de_la_pierre"):   # Œil de la pierre (Talents de race) : rien n'est irrécoltable, mais ÷ 3
				lent = true
			else:
				EventBus.emettre(&"journal", [&"journal.rebondit", {"materiau": mat.name_key}])
				return false
		var n := regles.niveau(e.competences_eff, str(mat.harvest.skill))
		ticks = maxi(1, ceili(durete / (force * regles.skill_factor(n)) * float(rr.ticks_par_seconde)))
		if lent:
			ticks = ticks * int(regles.r.talents.oeil_de_la_pierre.recolte_div)
	_quitter_garde(e)
	e.orientation = vers - e.pos
	_memoriser_terrain(vers)
	grille.contenu[grille.idx(vers)] = 0
	grille.materiaux.erase(grille.idx(vers))
	grille.hauteurs[grille.idx(vers)] = grille.h(e.pos)   # la brèche est au niveau de celui qui creuse
	grille.marquer(vers)
	e.endurance = maxi(0, int(e.endurance) - int(cr.endurance))
	e.compteur = tick + _ticks_avec_statuts(e, ticks)
	if recolte:
		var rr2: Dictionary = regles.r.recolte
		var n2 := regles.niveau(e.competences_eff, str(mat.harvest.skill))
		# « aucun chiffre fixe » (Récolte) : un jet, multiplié par la compétence — plancher 1
		var quantite := maxi(1, roundi(float(des.jet(str(rr2.get("des", "1d2")))) * regles.skill_factor(n2)))
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
	if monde != null and monde.claims.has(_cell_de(vers)):
		_progresser_quetes(e, "construire", ["meuble" if it.type == "meuble" else "station"])
	if it.type == "meuble":
		var m: Dictionary = GameData.entree("meubles", str(it.meuble))
		grille.poser_contenu(vers, "meuble" if bool(m.bloque_passage) else "meuble_sol")
		grille.meubles[idx] = str(it.meuble)
		if int(m.capacite_slots) > 0:
			contenants[idx] = []
		if str(m.type_meuble) == "etal" and monde != null:
			territoire.etals[_pm(vers)] = true
		if str(m.type_meuble) == "hall":
			var guilde := _meilleure_guilde(e)
			if guilde.is_empty():
				grille.contenu[idx] = 0
				grille.meubles.erase(idx)
				EventBus.emettre(&"journal", [&"journal.hall_refuse", {}])
				return false
			var vil: Dictionary = _ry().villes
			for d in Grille.DIRS:
				var q: Vector2i = vers + d
				if grille.dans(q) and not grille.bloque_passage(q) and grille.occupant(q).is_empty():
					var maitre := ajouter(str(vil.creature_hall), q, "ia")
					_habiller_pnj(maitre, GameData.entree("creatures", str(vil.creature_hall)))
					maitre["guilde"] = guilde
					maitre["hall"] = vers
					maitre["lit"] = q
					maitre["poste"] = q
					maitre.ancre = q
					break
			if not territoire.has("halls"):
				territoire["halls"] = {}
			territoire.halls[_pm(vers)] = guilde
			EventBus.emettre(&"journal", [&"journal.hall_pose", {"guilde": "guilde.%s.name" % guilde}])
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
	if monde != null and monde.claims.has(_cell_de(vers)):
		_progresser_quetes(e, "construire", ["mur"])
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
	if monde != null:
		territoire.etals.erase(_pm(vers))
		territoire.cultures.erase(_pm(vers))
		if territoire.get("halls", {}).has(_pm(vers)):
			for x in vivants():
				if x.get("hall", Vector2i(-1, -1)) == vers:
					x.vivant = false
					grille.liberer(x.pos)
			EventBus.emettre(&"journal", [&"journal.hall_demonte", {"guilde": "guilde.%s.name" % str(territoire.halls[_pm(vers)])}])
			territoire.halls.erase(_pm(vers))
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
	if "parcelle" in grille.contenu_de(vers).get("tags", []):
		return _recolter_culture(e, vers, tick)
	if grille.meubles.has(idx) and str(GameData.entree("meubles", str(grille.meubles[idx])).type_meuble) == "etal" and int(territoire.caisse) > 0:
		e.or = int(e.or) + int(territoire.caisse)
		EventBus.emettre(&"journal", [&"journal.caisse", {"nom": e.name_key, "n": int(territoire.caisse)}])
		territoire.caisse = 0
		e.compteur = tick + int(regles.r.actions.objet)
		return true
	if not contenants.has(idx) or contenants[idx].is_empty():
		return false
	var n := 0
	for uid in contenants[idx]:
		if not (uid in e.sac):
			e.sac.append(uid)
			n += 1
	contenants[idx] = []
	if grille.meubles.has(idx) and monde != null and lieu == "camp" and e.controle == "joueur" and not monde.claims.has(_cell_de(vers)) and bool(monde.cellule(_cell_de(vers)).has("village")):
		_infraction(e, "comportement", "vol", vers, "")
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
		if not territoire.raid.is_empty():   # un raid réveille le dormeur (Défense et raids)
			EventBus.emettre(&"journal", [&"journal.raid_reveil", {}])
			e.compteur = horloge_monde.ticks
			break
	if not e.vivant:
		return true
	e.sante = e.sante_max
	e["sang"] = 0
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
	if not monde.surface.route_de(cell).is_empty() and not monde.surface.route_de(monde.cellule_de(e.pos)).is_empty():   # par la route (Carte du monde)
		cout = int(round(float(cout) * float(GameData.config("planete").voyage.get("route_mult", 1.0))))
	var ec := monde.cellule(cell)
	var ou: Vector2i = monde.pos_monde(cell, ec.entree_donjon + Vector2i(0, 1)) if bool(ec.get("a_donjon", false)) else monde.point_marchable(cell)
	if en_combat(e):
		_quitter_combat(e)   # on ne voyage pas en gardant un combat derrière soi
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
	_livraisons(e, pnj)
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
	var tarif := tarif_de(uid, pnj)
	if tarif >= 1.0:
		EventBus.emettre(&"journal", [&"journal.douane_interdit", {"objet": nom_objet(uid)}])
		return false
	p.prix = maxi(1, roundi(float(p.prix) * (1.0 + tarif)))
	if int(e.or) < int(p.prix):
		EventBus.emettre(&"journal", [&"journal.pas_assez_or", {}])
		return false
	e.or = int(e.or) - int(p.prix)
	pnj.or = int(pnj.or) + int(p.prix)
	if tarif > 0.0:
		EventBus.emettre(&"journal", [&"journal.douane", {"pct": int(round(tarif * 100.0)), "objet": nom_objet(uid)}])
	_infraction(e, "objet", str(items[uid].get("base", "")), e.pos, uid)
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
	var tarif := tarif_de(uid, pnj)
	if tarif >= 1.0:
		EventBus.emettre(&"journal", [&"journal.douane_interdit", {"objet": nom_objet(uid)}])
		return false
	p.achat = maxi(1, roundi(float(p.achat) * (1.0 - tarif)))
	if tarif > 0.0:
		EventBus.emettre(&"journal", [&"journal.douane", {"pct": int(round(tarif * 100.0)), "objet": nom_objet(uid)}])
	if int(pnj.or) < int(p.achat):
		# Troc automatique (Économie — sources et puits) : un objet du stock à ±15 % de la valeur.
		var tol := float(regles.r.commerce.get("troc_tolerance", 0.15))
		for autre in pnj.stock:
			var pa := prix_suggere(str(autre), pnj, e)
			if absf(float(pa.achat) - float(p.achat)) <= float(p.achat) * tol:
				pnj.stock.erase(autre)
				pnj.stock.append(uid)
				e.sac.erase(uid)
				e.ratelier.erase(uid)
				e.sac.append(autre)
				e.compteur = tick + int(regles.r.actions.objet)
				EventBus.emettre(&"journal", [&"journal.troc", {"nom": pnj.name_key, "objet": nom_objet(str(autre))}])
				EventBus.emettre(&"item_sold", [uid, e.id, 0])
				return true
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
	_progresser_quetes(e, "vendre", [])
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
	var cell := _cell_de(x.pos)
	var conquis: bool = str(monde.villages.get(str(x.get("village", "")), {}).get("conquis_par", "")) == e.id
	if not monde.claims.has(cell) or (str(x.get("maitre", "")) != e.id and x.camp != "joueur" and not conquis):
		return false
	x.erase("maitre")
	if not conquis:
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
		if _cell_de(p) == cell and bool(GameData.entree("meubles", str(grille.meubles[gi])).dormir):
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


## La guilde où le joueur a le rang le plus haut, si ce rang atteint le minimum d'un hall (Halls de guilde).
func _meilleure_guilde(e: Dictionary) -> String:
	var meilleure := ""
	var rang_max := -1
	for gid in e.get("guildes", {}).keys():
		var rang := int(e.guildes[gid].get("rang", 0))
		if rang > rang_max:
			rang_max = rang
			meilleure = str(gid)
	return meilleure if rang_max >= int(_ry().villes.hall_rang_min) else ""


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
		territoire.gouvernance = str(_ry().gouvernance.defaut)
		EventBus.emettre(&"journal", [&"journal.royaume", {}])
		EventBus.emettre(&"journal", [&"journal.royaume_fonde", {"gouv": GameData.entree("governments", territoire.gouvernance).name_key}])


## Les pièces valides d'une cellule (Détection de pièces, Décision — Pièces en 2D) : flood fill depuis chaque porte.
func pieces_de_cellule(cell: Vector2i) -> Array:
	var res: Array = []
	if monde == null or lieu != "camp":
		return res
	var pc: Dictionary = _ry().pieces
	var vues: Dictionary = {}
	for i in grille.contenu.size():
		if grille.contenu[i] <= 0 or grille.contenu_ids[grille.contenu[i]] != "porte":
			continue
		var porte := grille.pos_de(i)
		if _cell_de(porte) != cell:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var depart: Vector2i = porte + d
			if not grille.dans(depart) or vues.has(depart) or grille.bloque_passage(depart):
				continue
			var region: Dictionary = {}
			var pile: Array = [depart]
			var ouvert := false
			while not pile.is_empty() and region.size() <= int(pc.fill_max):
				var q: Vector2i = pile.pop_back()
				if region.has(q):
					continue
				if not grille.dans(q) or _cell_de(q) != cell:
					ouvert = true
					break
				var tags: Array = grille.contenu_de(q).get("tags", [])
				if "mur" in tags or "porte" in tags:
					continue
				if grille.bloque_passage(q) and not grille.meubles.has(grille.idx(q)):
					continue
				region[q] = true
				for d2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					pile.append(q + d2)
			for q in region.keys():
				vues[q] = true
			if ouvert or region.size() > int(pc.fill_max) or region.size() < int(pc.surface_min):
				continue
			var types: Dictionary = {}
			for q in region.keys():
				if grille.meubles.has(grille.idx(q)):
					types[str(grille.meubles[grille.idx(q)])] = true
			if types.is_empty():
				continue
			res.append({"tuiles": region.keys(), "meubles": types.keys(), "porte": porte})
	return res


## Les poches locales (Stratification verticale) : un bruit dédié déplace le mur d'une strate, ±1, par taches.
func _poches_de_strates(theme: Dictionary, etage: int, graine: int, id_donjon: int) -> void:
	var pal: Dictionary = GameData.config("minerais_par_etage").get("palette_mur", {})
	var pc: Dictionary = pal.get("poches", {})
	if pc.is_empty() or etage < int(pal.get("etage_min", 3)):
		return
	var bruit := FastNoiseLite.new()
	bruit.seed = hash([graine, "poches", id_donjon, etage])
	bruit.frequency = float(pc.get("frequence", 0.08))
	var dur := materiau_mur_etage(theme, etage + int(pc.get("saut", 2)))
	var tendre := materiau_mur_etage(theme, maxi(int(pal.get("etage_min", 3)), etage - int(pc.get("saut", 2))))
	var defaut := grille.materiau_defaut
	for y in grille.hauteur_grille:
		for x in grille.largeur:
			var t := Vector2i(x, y)
			if not ("destructible" in grille.contenu_de(t).get("tags", [])):
				continue
			var v := (bruit.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			if v > float(pc.get("seuil_dur", 0.7)) and dur != defaut:
				grille.materiaux[grille.idx(t)] = dur
			elif v < float(pc.get("seuil_tendre", 0.3)) and tendre != defaut:
				grille.materiaux[grille.idx(t)] = tendre


## Le matériau des murs d'un étage (Stratification verticale) : le thème en surface, la palette en profondeur.
func materiau_mur_etage(theme: Dictionary, etage: int) -> String:
	var pal: Dictionary = GameData.config("minerais_par_etage").get("palette_mur", {})
	if pal.is_empty() or etage < int(pal.get("etage_min", 3)):
		return str(theme.get("materiau_mur", ""))
	for b in pal.get("bandes", []):
		if etage >= int(b.etages[0]) and etage <= int(b.etages[1]):
			return str(b.materiau)
	return str(theme.get("materiau_mur", ""))


## Les trésors détectés (Effets d'équipement : detection_tresors) : les contenants à portée, vus ou non.
func tresors_detectes(e: Dictionary) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	if not ("detection_tresors" in e.get("tags_acquis", [])):
		return res
	var r := int(regles.r.effets_equipement.tresors_rayon)
	for gi in contenants.keys():
		if contenants[gi].is_empty():
			continue
		var t := grille.pos_de(int(gi))
		if Grille.distance(e.pos, t) <= r:
			res.append(t)
	return res


## Le niveau d'une recette pour un être (Axe des niveaux de recette) : 1 par défaut, jusqu'à 5.
func niveau_recette(e: Dictionary, rid: String) -> int:
	return int(e.get("niveaux_recettes", {}).get(rid, 1))


## Un doublon de plan : il compte, et quand les doublons atteignent le niveau, la recette monte.
func _doublon_recette(e: Dictionary, rid: String) -> void:
	if not e.has("niveaux_recettes"):
		e["niveaux_recettes"] = {}
	if not e.has("doublons_recettes"):
		e["doublons_recettes"] = {}
	var n := niveau_recette(e, rid)
	var maxi_n := int(regles.r.craft.qualite.get("niveau_recette_max", 5))
	var nom: String = GameData.catalogues.recipes.get(rid, GameData.catalogues.component_recipes.get(rid, {})).get("name_key", rid)
	if n >= maxi_n:
		EventBus.emettre(&"journal", [&"journal.plan_deja", {}])
		return
	var d := int(e.doublons_recettes.get(rid, 0)) + 1
	if d >= n:
		e.niveaux_recettes[rid] = n + 1
		e.doublons_recettes[rid] = 0
		EventBus.emettre(&"journal", [&"journal.recette_niveau", {"recette": nom, "n": n + 1}])
	else:
		e.doublons_recettes[rid] = d
		EventBus.emettre(&"journal", [&"journal.recette_doublon", {"k": n - d, "n": n + 1}])


## Un effet unique d'artefact porté ? (Trésors et artefacts)
func a_unique(e: Dictionary, mecanique: String) -> bool:
	return not a_unique_ax(e, mecanique).is_empty()


func a_unique_ax(e: Dictionary, mecanique: String) -> Dictionary:
	for ax in Etres.affixes_equipes(e, items, affixes_defs, "unique"):
		if str(affixes_defs.get(ax.id, {}).get("effet", {}).get("mecanique", "")) == mecanique:
			return ax
	return {}


## Une tuile d'eau à nager (Eau et liquides) — gelée, elle se marche.
func dans_l_eau(pos: Vector2i) -> bool:
	return grille.dans(pos) and grille.nageable(pos)


## La température au centre de la cellule chargée (biome, saison, météo, nuit) — pour le gel (Météo).
func temperature_cellule() -> float:
	if monde == null or lieu != "camp":
		return 18.0
	var m: Dictionary = GameData.config("planete").get("meteo", {})
	var cell := monde.cellule_de(grille.pos_de(grille.largeur * grille.hauteur_grille / 2))
	var centre := grille.pos_de(grille.largeur * grille.hauteur_grille / 2)
	var temp: float = lerpf(float(m.temp_min), float(m.temp_max), monde.surface.valeur("temperature", centre.x, centre.y)) + float(_saison_info().temp)
	temp += float(GameData.catalogues.weather_states.get(meteo(cell), {}).get("temp_mod", 0))
	if est_nuit():
		temp += float(m.get("mod_nuit", -8))
	return temp


## Les états météo de la grille (Météo) : neige et gel, recalculés à chaque pas au camp.
func _maj_etats_meteo() -> void:
	if monde == null or lieu != "camp":
		grille.neige = false
		grille.gel = false
		return
	var cell := monde.cellule_de(grille.pos_de(grille.largeur * grille.hauteur_grille / 2))
	var etat: Dictionary = GameData.catalogues.weather_states.get(meteo(cell), {})
	var neige_avant := grille.neige
	var gel_avant := grille.gel
	grille.neige = "neige" in etat.get("effects", [])
	grille.gel = temperature_cellule() < float(regles.r.deplacement.get("gel_seuil", 0.0))
	if neige_avant != grille.neige or gel_avant != grille.gel:
		EventBus.emettre(&"tile_changed", [grille.pos_de(0)])   # le client redessine (neige, glace)


func souffle_max(e: Dictionary) -> int:
	return int(regles.r.nage.souffle_base) + int(e.stats_eff.get("endurance", 0)) * int(regles.r.nage.souffle_par_endurance)


## Le souffle (Eau et liquides) : décroît dans l'eau, se remplit dehors ; à zéro, 1d6 par période.
func _tiquer_souffle(nom: String, tick: int) -> void:
	var ng: Dictionary = regles.r.nage
	for e in vivants():
		if e.horloge != nom or Etres.est_volant(e):
			continue
		var maxi_s := souffle_max(e)
		if not e.has("souffle"):
			e["souffle"] = maxi_s
			e["souffle_tick"] = tick
		var ecoules := tick - int(e.souffle_tick)
		if ecoules <= 0:
			continue
		e.souffle_tick = tick
		if dans_l_eau(e.pos) and not ("respiration_aquatique" in e.get("tags_acquis", [])):
			e.souffle = maxi(0, int(e.souffle) - ecoules)
			if int(e.souffle) <= 0:
				var periodes := tick / int(ng.periode_ticks) - (tick - ecoules) / int(ng.periode_ticks)
				for k in periodes:
					var deg := des.jet(str(ng.degats_des))
					EventBus.emettre(&"journal", [&"journal.noyade", {"nom": e.name_key, "degats": deg}])
					_appliquer_degats(e, deg, "", {"type": "noyade", "element": {}})
		else:
			e.souffle = mini(maxi_s, int(e.souffle) + ecoules)


## Le vecteur élémentaire d'une tuile (Wu Xing hors combat) : dérivé des couches de bruit, jamais du biome.
func vecteur_lieu(pos: Vector2i) -> Dictionary:
	if not vecteur_lieu_force.is_empty():
		return vecteur_lieu_force
	if monde == null or monde.surface == null:
		return {}
	var sf = monde.surface
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
func mult_mana_lieu(e: Dictionary, plan: Dictionary) -> float:
	var el := wuxing.dominante(plan.get("elements", {}))
	var lieu_el := wuxing.dominante(vecteur_lieu(e.pos))
	if el.is_empty() or lieu_el.is_empty():
		return 1.0
	var ml: Dictionary = regles.r.mana.get("lieu", {})
	if el == lieu_el:
		return float(ml.get("meme", 0.85))
	if wuxing.relation(lieu_el, el) == "domine":
		return float(ml.get("domine_par", 1.15))
	return 1.0


## « Des sources » (Loot) : dans une forte densité de mana, le coût baisse de pct % par pièce.
func mult_mana_sources(e: Dictionary) -> float:
	if densite_mana(e.pos) < float(regles.r.effets_equipement.get("densite_mana_seuil", 0.6)):
		return 1.0
	var m := 1.0
	for ax in Etres.affixes_equipes(e, items, affixes_defs, "cond_densite_mana_cout"):
		m *= 1.0 - float(ax.params.get("pct", 0)) / 100.0
	return m


## Armes fantomatiques : une lame d'élément pur invoquée en main principale, entretenue en mana.
func _invoquer_arme_fantome(e: Dictionary, element: String, tick: int) -> bool:
	var af: Dictionary = regles.r.armes_fantomes
	if not (element in af.elements) or str(e.corps.get("silhouette", "humanoide")) != "humanoide":
		return false
	if int(e.mana) < int(af.cout_mana):
		EventBus.emettre(&"journal", [&"journal.arme_fantome_mana", {}])
		return false
	_dissiper_arme_fantome(e, false)
	e.mana -= int(af.cout_mana)
	var uid := "fantome_%s" % e.id
	var niveau := regles.niveau(e.competences_eff, str(af.competence))
	var durete := float(regles.r.degats.durete_reference) * (1.0 + float(e.stats_eff.volonte) / float(af.volonte_div) + float(niveau) / float(af.niveau_div))
	items[uid] = {"uid": uid, "name_key": "item.arme_fantome.name", "type": "arme", "equip_slot": "main_principale", "hands": 1, "functionality": str(af.functionality), "durete_base": durete, "qualite": 1.0, "element": element, "tags": ["arme", "fantome"], "materiau": "", "fantome": true, "fini": true, "dernier_tick": tick, "affixes": [], "sertissures": {"nombre": 0, "contenu": []}}
	var portee: String = e.equipement.get("main_principale", "")
	if not portee.is_empty():
		e.sac.append(portee)
	e.equipement["main_principale"] = uid
	Etres.recalculer(e, items, affixes_defs, regles)
	e.compteur = tick + int(af.ticks)
	EventBus.emettre(&"journal", [&"journal.arme_fantome", {"nom": e.name_key, "element": "element." + element}])
	return true


func _dissiper_arme_fantome(e: Dictionary, journal: bool = true) -> void:
	var uid := "fantome_%s" % e.id
	if not items.has(uid):
		return
	for slot in e.equipement.keys():
		if str(e.equipement[slot]) == uid:
			e.equipement.erase(slot)
	e.sac.erase(uid)
	items.erase(uid)
	Etres.recalculer(e, items, affixes_defs, regles)
	if journal:
		EventBus.emettre(&"journal", [&"journal.arme_fantome_dissipee", {}])


## L'entretien des lames fantômes (au pas de leur horloge) : du mana à intervalles, sinon la lame se dissipe.
func _tiquer_armes_fantomes(nom: String, tick: int) -> void:
	var af: Dictionary = regles.r.armes_fantomes
	for e in vivants():
		if e.horloge != nom:
			continue
		var uid := "fantome_%s" % e.id
		if not items.has(uid):
			continue
		if str(e.equipement.get("main_principale", "")) != uid:   # rangée : elle n'existe qu'en main
			_dissiper_arme_fantome(e)
			continue
		var it: Dictionary = items[uid]
		var n := (tick - int(it.dernier_tick)) / int(af.entretien_ticks)
		if n <= 0:
			continue
		it.dernier_tick = int(it.dernier_tick) + n * int(af.entretien_ticks)
		e.mana = maxi(0, int(e.mana) - n * int(af.entretien_mana))
		if int(e.mana) <= 0:
			_dissiper_arme_fantome(e)


## Incarner un compagnon (Changer de personnage) : le contrôle est un attribut — on l'échange.
func _incarner(e: Dictionary, pnj_id: String, tick: int) -> bool:
	var c: Dictionary = entites.get(pnj_id, {})
	if c.is_empty() or not c.vivant or str(c.get("maitre", "")) != e.id or Grille.distance(e.pos, c.pos) > 2:
		return false
	if "humanoide" in c.get("tags", []) and relation_de(c, e) < int(regles.r.talents.incarnation.relation_min):
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
	if attente.has(e.id):
		attente.erase(e.id)
	attente[c.id] = true
	c.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.incarne", {"nom": c.name_key, "ancien": e.name_key}])
	EventBus.emettre(&"controle_change", [c.id])
	return true


## Le Lycanthrope (Talents de race) : la forme bestiale, à volonté ou sous la lune.
func _transformer(e: Dictionary, tick: int) -> bool:
	if not a_talent(e, "lune"):
		return false
	if bool(e.get("forme_bestiale", false)) and bool(e.get("forme_forcee", false)):
		EventBus.emettre(&"journal", [&"journal.forme_forcee", {}])
		return false
	_poser_forme(e, not bool(e.get("forme_bestiale", false)))
	e.compteur = tick + int(regles.r.talents.lune.ticks_transformation)
	return true


func _poser_forme(e: Dictionary, bestiale: bool) -> void:
	e["forme_bestiale"] = bestiale
	if bestiale:
		e["forme_mult"] = float(regles.r.talents.lune.stats_mult)
		_quitter_garde(e)
	else:
		e.erase("forme_mult")
		e.erase("forme_forcee")
	Etres.recalculer(e, items, affixes_defs, regles)
	EventBus.emettre(&"journal", [&"journal.transformation" if bestiale else &"journal.forme_humaine", {"nom": e.name_key}])


## Attaquer sous forme bestiale : la première action de créature de la forme qui atteint la cible.
func _attaquer_bete(e: Dictionary, cible: Dictionary, tick: int) -> bool:
	if not cible.vivant:
		return false
	var jeu: Array = regles.r.talents.lune.actions if bool(e.get("forme_bestiale", false)) else e.get("actions", [])
	for aid in jeu:
		var action: Dictionary = actions_creatures.get(str(aid), {})
		if not action.is_empty() and _action_creature_possible(e, action, cible):
			# Embuscade : la frappe qui OUVRE le combat contre une cible qui ne se bat pas encore est une surprise
			e["surprise_sur"] = str(cible.id) if not en_combat(cible) else ""
			if not en_combat(e):
				_engager_combat(e, cible)
			_lancer_action_creature(e, action, cible, tick)
			return true
	return false


## Embuscade (Prototype de combat — six axes, axe 5) : une action passive `bonus_premiere_attaque` de
## l'attaquant ajoute ses dés à la **première** frappe portée sur une cible surprise — celle contre qui
## cette frappe ouvre le combat. Une seule fois par proie : après, elle est prévenue.
func _bonus_embuscade(e: Dictionary, c: Dictionary) -> int:
	if str(e.get("surprise_sur", "")) != str(c.id):
		return 0
	e.surprise_sur = ""
	var bonus := 0
	for aid in e.get("actions", []):
		for effet: Dictionary in actions_creatures.get(str(aid), {}).get("effets", []):
			if str(effet.get("type", "")) == "bonus_premiere_attaque":
				bonus += int(effet.get("des", 0))
	if bonus > 0:
		EventBus.emettre(&"journal", [&"journal.embuscade", {"att": e.name_key, "def": c.name_key, "des": bonus}])
	return bonus


func _devenir_lycanthrope(e: Dictionary) -> void:
	_retirer_statut(e, "morsure_lunaire")
	e["race_origine"] = str(e.get("race", ""))
	e.race = "lycanthrope"
	e["tags_acquis_race"] = GameData.catalogues.races.lycanthrope.get("tags_acquis", []).duplicate()
	_contreparties(e)
	EventBus.emettre(&"journal", [&"journal.lycanthrope", {"nom": e.name_key}])


## La source maudite et l'autel du rituel (Talents de race) : deux meubles de donjon, à usage unique,
## qui ouvrent une race cachée à qui n'en porte pas déjà une.
func _rituel_race(e: Dictionary, vers: Vector2i, type_meuble: String, tick: int) -> bool:
	if not grille.dans(vers) or Grille.distance(e.pos, vers) > 1:
		return false
	var gi := grille.idx(vers)
	var id_meuble := str(grille.meubles.get(gi, ""))
	if id_meuble.is_empty():   # pas de meuble sur la tuile : rien à interroger (le fuzz pousse cette intention partout)
		return false
	if str(GameData.entree("meubles", id_meuble).get("type_meuble", "")) != type_meuble:
		return false
	if str(e.get("race", "")) in ["vampire", "spectre", "lycanthrope"]:
		EventBus.emettre(&"journal", [&"journal.deja_maudit", {}])
		return false
	grille.meubles.erase(gi)   # à usage unique : la source se tarit, l'autel se brise
	grille.contenu[gi] = 0
	grille.marquer(vers)
	lumiere_sale = true
	EventBus.emettre(&"tile_changed", [vers])
	e.compteur = tick + int(regles.r.actions.objet)
	if type_meuble == "source_maudite":
		EventBus.emettre(&"journal", [&"journal.source_bue", {"nom": e.name_key}])
		_devenir_vampire(e)
	else:
		EventBus.emettre(&"journal", [&"journal.rituel_accompli", {"nom": e.name_key}])
		_devenir_lycanthrope(e)
	return true


## Le Spectre (Talents de race) : se relever spectre, traverser un mur d'une tuile.
func _devenir_spectre(e: Dictionary) -> void:
	e["race_origine"] = str(e.get("race", ""))
	e.race = "spectre"
	e["tags_acquis_race"] = GameData.catalogues.races.spectre.get("tags_acquis", []).duplicate()
	for slot in regles.r.talents.sans_chair.slots_refuses:
		if e.equipement.has(str(slot)):
			e.equipement.erase(str(slot))
	_contreparties(e)
	EventBus.emettre(&"journal", [&"journal.spectre", {"nom": e.name_key}])


func _traverser_mur(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if not a_talent(e, "sans_chair") or Grille.distance(e.pos, vers) != 2 or not grille.dans(vers):
		return false
	var d: Vector2i = vers - e.pos
	if not (d.x == 0 or d.y == 0 or absi(d.x) == absi(d.y)):
		return false
	var milieu: Vector2i = e.pos + Vector2i(signi(d.x), signi(d.y))
	if not grille.bloque_passage(milieu) or grille.bloque_passage(vers) or not grille.occupant(vers).is_empty():
		return false
	if Etres.bloque_statuts(e, "deplacement", statuts_defs):
		return false
	_quitter_garde(e)
	grille.liberer(e.pos)
	e.orientation = Vector2i(signi(d.x), signi(d.y))
	e.pos = vers
	grille.placer(e.id, vers)
	e["vue_sale"] = true
	e.compteur = tick + 2 * regles.ticks_deplacement(int(regles.r.deplacement.cout_base), e.competences_eff, en_combat(e))
	_declencher_glyphe(e, vers)
	EventBus.emettre(&"journal", [&"journal.traverse_mur", {"nom": e.name_key}])
	return true


## Le Vampire (Talents de race) : la nuit le porte, le jour le brûle ; les mordus s'éveillent à l'aube.
func _tiquer_vampires(nom: String, tick: int) -> void:
	var nuit := est_nuit()
	var refresh := int(regles.r.talents.get("soif_de_sang", {}).get("refresh_ticks", 200))
	for e in vivants():
		if e.horloge != nom and a_talent(e, "soif_de_sang"):
			continue
		if a_talent(e, "soif_de_sang"):
			if nuit:
				appliquer_statut(e, "sang_de_la_nuit", refresh, e.id)
				_retirer_statut(e, "soleil")
			else:
				_retirer_statut(e, "sang_de_la_nuit")
				if lieu != "donjon":
					appliquer_statut(e, "soleil", refresh, e.id)
		elif not nuit and Etres.a_statut_tag(e, "morsure", statuts_defs):
			_devenir_vampire(e)
		if a_talent(e, "lune"):   # la lune : une nuit sur trente, la bête s'impose
			var jour_idx := int(horloge_monde.ticks / int(_cycle().get("ticks_par_jour", 24000)))
			if nuit and jour_idx > 0 and jour_idx % int(regles.r.talents.lune.nuit_forcee_toutes_les) == 0 and not bool(e.get("forme_forcee", false)):   # jamais la première nuit
				if not bool(e.get("forme_bestiale", false)):
					_poser_forme(e, true)
				e["forme_forcee"] = true
				EventBus.emettre(&"journal", [&"journal.forme_forcee", {}])
			elif not nuit and bool(e.get("forme_forcee", false)):
				_poser_forme(e, false)
		elif not nuit and Etres.a_statut_tag(e, "morsure_lune", statuts_defs):
			_devenir_lycanthrope(e)


func _retirer_statut(e: Dictionary, id: String) -> void:
	var avant: int = e.statuts.size()
	e.statuts = e.statuts.filter(func(s0: Dictionary) -> bool: return str(s0.id) != id)
	if e.statuts.size() != avant and Etres.statut_touche_stats(id, statuts_defs):
		Etres.recalculer(e, items, affixes_defs, regles)


func _devenir_vampire(e: Dictionary) -> void:
	_retirer_statut(e, "morsure")
	e["race_origine"] = str(e.get("race", ""))
	e.race = "vampire"
	e["tags_acquis_race"] = GameData.catalogues.races.vampire.get("tags_acquis", []).duplicate()   # vision nocturne, relu par Etres.recalculer
	_contreparties(e)
	e["vue_sale"] = true
	EventBus.emettre(&"journal", [&"journal.vampire", {"nom": e.name_key}])


## Mordre un être adjacent : des dégâts, la jauge pleine de son élément, et la Morsure aux humanoïdes.
func _mordre(e: Dictionary, cible_id: String, tick: int) -> bool:
	var c: Dictionary = entites.get(cible_id, {})
	if not a_talent(e, "soif_de_sang") or c.is_empty() or not c.vivant or Grille.distance(e.pos, c.pos) != 1:
		return false
	var deg := des.jet(str(regles.r.talents.soif_de_sang.degats_morsure))
	_appliquer_degats(c, deg, e.id, {"type": "perforant", "element": {}, "morsure": true})
	if e.has("chaine"):
		var elem := wuxing.dominante(c.get("elements", {}) if c.get("elements") != null else {})
		if elem.is_empty():
			elem = "eau"
		while e.chaine.segments.size() < int(e.chaine.capacite) - 1:
			wuxing.poser(e.chaine, elem, tick)
	if c.vivant and "humanoide" in c.get("tags", []):
		appliquer_statut(c, "morsure", int(statuts_defs.morsure.duree_ticks), e.id)
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.morsure", {"nom": e.name_key, "cible": c.name_key, "degats": deg}])
	return true


## Le Fossoyeur (Talents de classe) : relever un cadavre en invocation temporaire, contre de la réputation.
func _relever(e: Dictionary, cible_id: String, tick: int) -> bool:
	var c: Dictionary = entites.get(cible_id, {})
	var rl: Dictionary = regles.r.talents.releveur
	if not a_talent(e, "releveur") or c.is_empty() or Grille.distance(e.pos, c.pos) > int(rl.portee):
		return false
	return _relever_brut(e, c, tick)


## Le relevé lui-même, sans le talent : le noyau *Relevé* y accède en payant son mana (Modules).
func _relever_brut(e: Dictionary, c: Dictionary, tick: int) -> bool:
	var rl: Dictionary = regles.r.talents.releveur
	if c.is_empty() or c.vivant or bool(c.get("releve", false)) or not grille.occupant(c.pos).is_empty():
		return false
	c["releve"] = true
	var x := ajouter(str(c.def), c.pos, "ia")
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
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.releve", {"nom": e.name_key, "cible": c.name_key, "n": -int(rl.reputation)}])
	return true


## L'Engrenage : déployer l'affût sur une tuile libre adjacente — une seule, redéployer la déplace.
func _deployer_affut(e: Dictionary, t: Vector2i, tick: int) -> bool:
	if not a_talent(e, "affut") or Grille.distance(e.pos, t) != 1 or not grille.dans(t) or grille.bloque_passage(t) or not grille.occupant(t).is_empty():
		return false
	_replier_affut(e)
	grille.poser_contenu(t, "barriere")
	affuts.append({"pos": t, "source": e.id, "prochain": tick + int(regles.r.talents.affut.cadence_ticks)})   # le temps de l'armer
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.affut_pose", {"nom": e.name_key}])
	EventBus.emettre(&"tile_changed", [t])
	return true


func _replier_affut(e: Dictionary) -> void:
	for a in affuts.duplicate():
		if str(a.source) == e.id:
			grille.contenu[grille.idx(a.pos)] = 0
			EventBus.emettre(&"tile_changed", [a.pos])
			affuts.erase(a)


## Les affûts tirent à leur cadence sur l'ennemi le plus proche, avec les éléments de l'arme du propriétaire ;
## chaque tir consomme une munition du carquois, sans munition l'affût se replie.
func _tirs_d_affuts(nom: String, tick: int) -> void:
	var af: Dictionary = regles.r.talents.get("affut", {})
	for a in affuts.duplicate():
		var src: Dictionary = entites.get(str(a.source), {})
		if src.is_empty() or src.horloge != nom or int(a.prochain) > tick:
			continue
		if not src.vivant:
			_replier_affut(src)
			continue
		var autonome: bool = a.has("fin")   # une Tourelle invoquée : ses ticks, ses dés, pas de carquois
		if autonome and int(a.fin) <= tick:
			grille.contenu[grille.idx(a.pos)] = 0
			EventBus.emettre(&"tile_changed", [a.pos])
			affuts.erase(a)
			continue
		if not autonome and int(src.munitions) <= 0:   # le compteur de munitions de l'être (Projectiles)
			EventBus.emettre(&"journal", [&"journal.affut_replie", {}])
			_replier_affut(src)
			continue
		a.prochain = tick + int(a.get("cadence", af.cadence_ticks))
		var cible: Dictionary = {}
		var dmin: int = int(a.get("portee", af.portee)) + 1
		for x in vivants():
			if x.camp == src.camp or x.camp == "civil":
				continue
			var dist := Grille.distance(a.pos, x.pos)
			if dist < dmin and grille.ligne_de_vue(a.pos, x.pos):
				dmin = dist
				cible = x
		if cible.is_empty():
			continue
		if not autonome:
			src.munitions = int(src.munitions) - 1
			src.munitions_tirees = int(src.get("munitions_tirees", 0)) + 1
		var arme := Etres.arme(src, items)
		var elems: Dictionary = a.get("elements", {}) if autonome and not a.get("elements", {}).is_empty() else (arme.get("elements", {}) if arme.get("elements") != null else {})
		var deg := des.jet(str(a.get("degats", af.degats)))
		_appliquer_degats(cible, deg, src.id, {"type": str(af.get("type", "perforant")), "element": elems, "affut": true})
		EventBus.emettre(&"journal", [&"journal.affut_tire", {"nom": cible.name_key, "degats": deg}])


## Le Masque (Talents de classe) : porter ou retirer un masque — un statut, à 0 tick, deux au plus.
func _porter_masque(e: Dictionary, id: String, _tick: int) -> bool:
	var d: Dictionary = statuts_defs.get(id, {})
	if not a_talent(e, "masques") or d.is_empty() or not ("masque" in d.get("tags", [])):
		return false
	var portes: Array = e.statuts.filter(func(s0: Dictionary) -> bool: return "masque" in statuts_defs.get(str(s0.id), {}).get("tags", []))
	for s0 in portes:
		if str(s0.id) == id:
			e.statuts.erase(s0)
			Etres.recalculer(e, items, affixes_defs, regles)
			EventBus.emettre(&"journal", [&"journal.masque", {"nom": e.name_key, "masque": d.name_key}])
			return true
	while portes.size() >= int(regles.r.talents.masques.max):
		e.statuts.erase(portes.pop_front())
	appliquer_statut(e, id, int(d.duree_ticks), e.id)
	EventBus.emettre(&"journal", [&"journal.masque", {"nom": e.name_key, "masque": d.name_key}])
	return true


## La marque au sol d'un glyphe s'efface — sauf si un feu ou de la lave occupe encore la tuile.
func _oublier_glyphe(pos: Vector2i) -> void:
	var idx := grille.idx(pos)
	if feux.has(idx) or "lave" in grille.contenu_de(pos).get("tags", []):
		return
	grille.dangers.erase(idx)


## Le Sceau : déclencher à distance l'un de ses glyphes — la charge part sur la tuile, occupée ou non.
func _declencher_glyphe_distance(e: Dictionary, pos: Vector2i, tick: int) -> bool:
	if not a_talent(e, "graveur") or Grille.distance(e.pos, pos) > int(regles.r.talents.graveur.portee_declenchement):
		return false
	for gl in glyphes.duplicate():
		if gl.pos != pos or str(gl.source) != e.id:
			continue
		glyphes.erase(gl)
		_oublier_glyphe(pos)
		var charge: Dictionary = gl.plan.duplicate()
		charge.geometrie = "point"
		e.compteur = tick + int(regles.r.actions.objet)
		EventBus.emettre(&"journal", [&"journal.glyphe_distance", {"nom": e.name_key}])
		_executer_capacite(e, charge, pos, true)
		return true
	return false


## Contreparties permanentes des talents (Talents de classe) : posées sur l'être, lues par Etres.recalculer.
func _contreparties(e: Dictionary) -> void:
	if a_talent(e, "breche"):
		e["mana_max_mult"] = float(regles.r.talents.breche.mana_max_mult)
	else:
		e.erase("mana_max_mult")
	Etres.recalculer(e, items, affixes_defs, regles)


## Le Passeur : poser un portail sur une tuile libre adjacente ; le troisième déplace le plus ancien.
func _poser_portail(e: Dictionary, t: Vector2i, tick: int) -> bool:
	if not a_talent(e, "breche") or Grille.distance(e.pos, t) != 1 or not grille.dans(t) or grille.bloque_passage(t) or not grille.occupant(t).is_empty():
		return false
	if portails.has(t):
		return false
	if not e.has("portails"):
		e["portails"] = []
	while e.portails.size() >= int(regles.r.talents.breche.portails_max):
		portails.erase(e.portails.pop_front())
	e.portails.append(t)
	portails[t] = e.id
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.portail_pose", {"nom": e.name_key}])
	return true


## Traverser : debout sur un portail, vers son jumeau s'il est libre (ouvert à tous).
func _traverser(e: Dictionary, tick: int) -> bool:
	if not portails.has(e.pos):
		return false
	var p: Dictionary = entites.get(str(portails[e.pos]), {})
	if p.is_empty():
		return false
	for j in p.get("portails", []):
		if j != e.pos and portails.has(j):
			var vers: Vector2i = j
			if not grille.occupant(vers).is_empty():
				return false
			grille.liberer(e.pos)
			e.pos = vers
			grille.placer(e.id, vers)
			e["vue_sale"] = true
			e.compteur = tick + int(regles.r.actions.objet)
			EventBus.emettre(&"journal", [&"journal.traverse", {"nom": e.name_key}])
			return true
	return false


## Le portail qui rapproche le plus du but (Talents de classe) : Vector2i(-1, -1) si aucun ne vaut le détour.
## Retourne la tuile du portail à rejoindre — si c'est celle où l'on est déjà, il n'y a qu'à traverser.
func portail_utile(e: Dictionary, but: Vector2i) -> Vector2i:
	if portails.is_empty():
		return Vector2i(-1, -1)
	var br: Dictionary = regles.r.talents.get("breche", {})
	var portee := int(br.get("ia_portee", 8))
	var meilleur := Vector2i(-1, -1)
	var meilleur_gain := int(br.get("ia_gain_min", 6)) - 1
	for entree in portails.keys():
		if not grille.dans(entree):
			continue
		var d_entree := Grille.distance(e.pos, entree)
		if d_entree > portee or (d_entree > 0 and not grille.occupant(entree).is_empty()):
			continue
		var p: Dictionary = entites.get(str(portails[entree]), {})
		for j in p.get("portails", []):
			if j == entree or not portails.has(j):
				continue
			var sortie: Vector2i = j
			if not grille.occupant(sortie).is_empty():
				continue
			var gain := Grille.distance(e.pos, but) - (d_entree + Grille.distance(sortie, but))
			if gain > meilleur_gain:
				meilleur_gain = gain
				meilleur = entree
	return meilleur


## Le pas d'une IA qui passe par un portail : vrai si elle a traversé ou avancé vers la brèche.
func _ia_par_portail(e: Dictionary, but: Vector2i, tick: int) -> bool:
	var entree := portail_utile(e, but)
	if entree == Vector2i(-1, -1):
		return false
	if entree == e.pos:
		return _traverser(e, tick)
	var pas := grille.chemin(e.pos, entree, Etres.est_volant(e), "", refuse_nage(e))
	return not pas.is_empty() and _deplacer(e, pas[0], tick)


## Le Sablier : voler du tempo — l'ennemi recule, le Sablier avance d'autant, et paie en santé.
func _voler_tempo(e: Dictionary, cible_id: String, tick: int) -> bool:
	var c: Dictionary = entites.get(cible_id, {})
	var st: Dictionary = regles.r.talents.maitre_du_tempo
	if not a_talent(e, "maitre_du_tempo") or c.is_empty() or not c.vivant or Grille.distance(e.pos, c.pos) > int(st.portee) or int(e.sante) <= int(st.sante):
		return false
	var n := _tempo(c, int(st.tempo_vole), e.id)
	if n <= 0:
		EventBus.emettre(&"journal", [&"journal.tempo_refuse", {}])
		return false
	e.sante = maxi(1, int(e.sante) - int(st.sante))
	e.compteur = tick + int(regles.r.actions.objet)
	_tempo(e, -n, e.id)
	EventBus.emettre(&"journal", [&"journal.tempo_vole", {"nom": e.name_key, "cible": c.name_key, "n": n, "sante": int(st.sante)}])
	return true


## Le Porteur (Talents de classe) : saisir un être adjacent — il est immobilisé, le Porteur ne frappe ni ne se garde.
func _saisir(e: Dictionary, cible_id: String, tick: int, par_talent: bool = true) -> bool:
	var c: Dictionary = entites.get(cible_id, {})
	if (par_talent and not a_talent(e, "saisie")) or c.is_empty() or not c.vivant or c.id == e.id or Grille.distance(e.pos, c.pos) != 1 or not str(e.get("porte", "")).is_empty():
		return false
	if Etres.bloque_statuts(c, "projection", statuts_defs):
		return false   # Ancrage : on ne l'empoigne pas non plus
	e["porte"] = cible_id
	c["saisi_par"] = e.id
	appliquer_statut(c, "saisi", int(statuts_defs.saisi.duree_ticks), e.id)
	_quitter_garde(e)
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.saisi", {"nom": e.name_key, "cible": c.name_key}])
	return true


## Lancer l'être saisi vers une tuile : projection de distance_lancer dans cette direction, dégâts à l'arrivée.
func _lancer_etre(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	var c: Dictionary = entites.get(str(e.get("porte", "")), {})
	if c.is_empty():
		return false
	var d := Vector2i(signi(vers.x - e.pos.x), signi(vers.y - e.pos.y))
	if d == Vector2i.ZERO:
		return false
	var sa: Dictionary = regles.r.talents.saisie
	# On place la cible du côté du lancer, puis on la projette.
	var depart: Vector2i = e.pos + d
	if grille.dans(depart) and not grille.bloque_passage(depart) and (grille.occupant(depart).is_empty() or grille.occupant(depart) == c.id):
		grille.liberer(c.pos)
		c.pos = depart
		grille.placer(c.id, depart)
	var cibles: Array[Dictionary] = [c]
	_effet_deplacement(e, {"mode": "projection", "distance": str(int(sa.distance_lancer) - 1)}, cibles, {})
	_liberer_saisie(e, c)
	var deg := des.jet(str(sa.degats_lancer))
	_appliquer_degats(c, deg, e.id, {"type": "contondant", "element": {}, "lancer": true})
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.lance", {"nom": e.name_key, "cible": c.name_key, "degats": deg}])
	return true


func _liberer_saisie(e: Dictionary, c: Dictionary) -> void:
	e.erase("porte")
	c.erase("saisi_par")
	c.statuts = c.statuts.filter(func(s0: Dictionary) -> bool: return str(s0.id) != "saisi")


## La cible saisie se débat à son tour : jet de Force opposé, elle se libère si elle gagne.
func _ia_se_debattre(c: Dictionary, tick: int) -> bool:
	var p: Dictionary = entites.get(str(c.get("saisi_par", "")), {})
	if p.is_empty() or not p.vivant or str(p.get("porte", "")) != c.id:
		c.erase("saisi_par")
		return false
	if des.jet("1d20") + int(c.stats_eff.force) / 2 > des.jet("1d20") + int(p.stats_eff.force) / 2:
		_liberer_saisie(p, c)
		EventBus.emettre(&"journal", [&"journal.debat", {"nom": c.name_key}])
	c.compteur = tick + int(regles.r.actions.objet)
	return true


## Un abri pour le bétail (Habitat des PNJ) : un enclos à portée.
func _abri_a(pos: Vector2i) -> bool:
	var r := int(_ry().betail.abri_rayon)
	for gi in grille.meubles.keys():
		if str(GameData.entree("meubles", str(grille.meubles[gi])).type_meuble) == "enclos" and Grille.distance(pos, grille.pos_de(int(gi))) <= r:
			return true
	return false


## Changer le statut d'habitat d'un compagnon ou d'un résident (Habitat des PNJ) : bétail ou normal.
func _statut_habitat(e: Dictionary, pnj_id: String, statut: String, tick: int) -> bool:
	var x: Dictionary = entites.get(pnj_id, {})
	if x.is_empty() or Grille.distance(e.pos, x.pos) > 2 or not (str(x.get("maitre", "")) == e.id or x.has("assignation")):
		return false
	if str(x.get("statut_habitat", "normal")) == statut:
		return false
	x["statut_habitat"] = statut
	e.compteur = tick + int(regles.r.actions.objet)
	if statut == "betail":
		EventBus.emettre(&"journal", [&"journal.statut_betail", {"nom": x.name_key}])
		if not ("bete" in x.get("tags", [])) and x.has("social"):   # un ancien corps de joueur n'a pas de bloc social
			x.social.relations[e.id] = int(x.social.relations.get(e.id, 0)) + int(_ry().betail.retrogradation_relation)
			EventBus.emettre(&"journal", [&"journal.retrogradation", {"nom": x.name_key}])
	else:
		EventBus.emettre(&"journal", [&"journal.statut_resident", {"nom": x.name_key}])
	return true


## La pièce d'un lit (ou vide).
func _piece_du_lit(lit: Vector2i, pieces: Array) -> Dictionary:
	for pi in pieces:
		if lit in pi.tuiles:
			return pi
	return {}


## Les humeurs recalculées au passage de semaine (Habitat des PNJ, Faim des PNJ) : logement, chambre, co-occupants, faim.
func _recalculer_humeurs() -> void:
	var ry := _ry()
	var pc: Dictionary = ry.pieces
	var pieces_par_cell: Dictionary = {}
	var res := residents()
	var garde_manger: Array = []
	for gi in grille.meubles.keys():
		if str(GameData.entree("meubles", str(grille.meubles[gi])).type_meuble) == "garde_manger" and monde.claims.has(_cell_de(grille.pos_de(int(gi)))):
			garde_manger.append(int(gi))
	for x in res:
		var h := int(ry.humeur_base)
		var lit: Vector2i = x.get("lit", Vector2i(-1, -1))
		var cell := _cell_de(lit) if lit != Vector2i(-1, -1) else Vector2i(-9999, -9999)
		if not pieces_par_cell.has(cell):
			pieces_par_cell[cell] = pieces_de_cellule(cell) if cell != Vector2i(-9999, -9999) else []
		var piece := _piece_du_lit(lit, pieces_par_cell[cell]) if lit != Vector2i(-1, -1) else {}
		if str(x.get("statut_habitat", "normal")) == "betail":   # bétail (Habitat des PNJ) : un abri suffit, il broute
			if not _abri_a(x.pos) and piece.is_empty():
				h += int(ry.sans_logement)
			if not ("bete" in x.get("tags", [])):
				h += int(ry.betail.retrogradation_humeur)
			x.humeur = h
			continue
		if piece.is_empty():
			h += int(ry.sans_logement)
		else:
			h += mini(int(pc.bonus_meubles_max), int(pc.bonus_par_meuble) * piece.meubles.size())
			if piece.tuiles.size() >= int(pc.surface_bonus):
				h += int(pc.bonus_taille)
			var co := 0
			for autre in res:
				if autre.id != x.id and autre.get("lit", Vector2i(-2, -2)) in piece.tuiles:
					co += 1
			h += int(pc.co_occupant) * co
		# La faim : une unité au garde-manger, sinon le malus.
		var mange := false
		for gi in garde_manger:
			for uid in contenants.get(gi, []):
				var it: Dictionary = items.get(uid, {})
				if it.get("type", "") == "consommable" and float(it.get("nutrition", 0)) > 0.0:
					it.quantite = int(it.get("quantite", 1)) - 1
					if int(it.quantite) <= 0:
						contenants[gi].erase(uid)
						items.erase(uid)
					mange = true
					break
			if mange:
				break
		if not mange:
			h += int(ry.get("faim_pnj", -10))
			EventBus.emettre(&"journal", [&"journal.pnj_affame", {"nom": x.name_key}])
		x.humeur = h


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
	if not str(territoire.gouvernance).is_empty():
		var g: Dictionary = GameData.entree("governments", str(territoire.gouvernance))
		entretien = int(round(float(entretien) * float(g.base_rate) / float(ry.gouvernance.base_rate_ref)))
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
		_recalculer_humeurs()
	# Taxe de guilde sur les gains de quêtes de la semaine (Entretien et taxes).
	var gains := int(territoire.get("gains_quetes", 0))
	if gains > 0:
		var rang := int(e.get("guildes", {}).get("guerriers", {}).get("rang", 0))
		var taxe := int(round(float(gains) * float(ry.taxe_guilde) * (1.0 + float(ry.taxe_rang) * maxi(0, rang - 1))))
		e.or = maxi(0, int(e.or) - taxe)
		territoire.gains_quetes = 0
		if taxe > 0:
			EventBus.emettre(&"journal", [&"journal.taxe_guilde", {"n": taxe}])
	# Transition de gouvernance (Gouvernance, lois et diplomatie).
	if int(territoire.transition) > 0:
		territoire.transition = int(territoire.transition) - 1
		if int(territoire.transition) == 0:
			territoire.gouvernance = str(territoire.gouvernance_cible)
			territoire.gouvernance_cible = ""
			EventBus.emettre(&"journal", [&"journal.gouvernance_faite", {"gouv": GameData.entree("governments", str(territoire.gouvernance)).name_key}])
	_semaine_accords()
	_jet_raid(e, horloge_monde.ticks)
	var rapport := {"prod": " · ".join(prod_txt) if not prod_txt.is_empty() else "—", "entretien": entretien, "tresor": int(territoire.tresor), "dette": int(territoire.dette)}
	territoire.rapports.append(rapport)
	while territoire.rapports.size() > 8:
		territoire.rapports.pop_front()
	EventBus.emettre(&"journal", [&"journal.rapport_semaine", rapport])


func _structures_speciales() -> int:
	var n: int = territoire.get("halls", {}).size()
	if monde == null:
		return 0
	for gi in grille.stations_fixes.keys():
		if monde.claims.has(_cell_de(grille.pos_de(int(gi)))):
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


## La puissance d'un matériau paramétrique : stat de la créature / 10, bornée.
func _puissance_de(valeur: int) -> float:
	var al: Dictionary = regles.r.alchimie
	return snappedf(clampf(float(valeur) / float(al.puissance_div), float(al.puissance_bornes[0]), float(al.puissance_bornes[1])), 0.1)


# ---------------------------------------------------------------- capacités : slots et assemblage (Structure compétences-modules-slots)

func niveau_arme(e: Dictionary) -> int:
	var arme := Etres.arme(e, items)
	var fonct: Dictionary = fonctionnalites.get(str(arme.get("functionality", "")), {})
	return regles.niveau(e.competences_eff, str(fonct.get("combat_skill", "")))


func slots_capacites(e: Dictionary) -> Dictionary:
	var c: Dictionary = regles.r.capacites
	var n := niveau_arme(e)
	return {"capacites": mini(int(c.capacites_max), int(c.capacites_base) + n / int(c.par_niveau_capacites)), "modules": mini(int(c.modules_max), int(c.modules_base) + n / int(c.par_niveau_modules))}


## Composer une capacité depuis des modules connus : l'assembleur juge la séquence, les slots bornent le **nombre**
## de capacités tenues prêtes — pas la longueur d'une séquence (assemblage sans limite, 2026-08-30).
func composer_capacite(e: Dictionary, sequence: Array, nom: String = "") -> bool:
	if sequence.is_empty():   # plus de plafond de capacités non plus (décision du designer, 2026-08-30) : on en compose autant qu'on veut
		EventBus.emettre(&"journal", [&"journal.capacite_refusee", {}])
		return false
	for m in sequence:
		if not (str(m) in e.get("modules_connus", [])):
			EventBus.emettre(&"journal", [&"journal.capacite_refusee", {}])
			return false
	var plan := capacites.assembler(sequence.duplicate(), 10, "1d4", {}, e.competences_eff)
	if not plan.erreurs.is_empty():
		EventBus.emettre(&"journal", [&"journal.capacite_refusee", {}])
		return false
	var noyau: Dictionary = plan.noyau
	var nom_key := str(noyau.get("name_key", "capacite.etincelle.name"))
	if not nom.strip_edges().is_empty():   # le nom choisi par le joueur (Écrans d'interface) : tr() le rend tel quel
		nom_key = nom.strip_edges()
	var cap := {"id": "cap_%d_%d" % [e.get("capacites", []).size(), sequence.hash()], "name_key": nom_key, "modules": sequence.duplicate()}
	if not e.has("capacites"):
		e["capacites"] = []
	e.capacites.append(cap)
	EventBus.emettre(&"journal", [&"journal.capacite_creee", {"nom": nom_key}])
	return true


func supprimer_capacite(e: Dictionary, index: int) -> bool:
	if index < 0 or index >= e.get("capacites", []).size():
		return false
	var cap: Dictionary = e.capacites[index]
	e.capacites.remove_at(index)
	EventBus.emettre(&"journal", [&"journal.capacite_supprimee", {"nom": cap.get("name_key", "")}])
	return true


# ---------------------------------------------------------------- talents (Talents de classe, Talents de race)

## Les talents d'un être : celui de sa classe, celui de sa race, ceux qu'il a appris.
func talents_de(e: Dictionary) -> Array:
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


func a_talent(e: Dictionary, id: String) -> bool:
	return id in talents_de(e)


## Main du métal (La Braise) : remplacer un composant d'un objet assemblé sans perdre ses affixes.
func _reforger(e: Dictionary, objet: String, composant: String, tick: int) -> bool:
	var it: Dictionary = items.get(objet, {})
	var c: Dictionary = items.get(composant, {})
	var def: Dictionary = GameData.catalogues.items.get(str(it.get("base", "")), {})
	if not a_talent(e, "main_du_metal") or it.is_empty() or c.is_empty() or not (composant in e.sac) or not (objet in e.sac or objet in e.equipement.values()) or not def.has("slots") or c.get("type", "") != "composant":
		EventBus.emettre(&"journal", [&"journal.reforge_refuse", {}])
		return false
	if not stations_de(e).has(str(def.get("recipe", {}).get("station", ""))):
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
	var poids: Dictionary = regles.r.craft.poids.armure if def.get("type", "") == "armure" else regles.r.craft.poids.arme
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
	it.element = wuxing.dominante(elements)
	if slot in ["tete", "plaque"]:
		it.materiau = str(c.materiau)
	e.sac.erase(composant)
	items.erase(composant)
	Etres.recalculer(e, items, affixes_defs, regles)
	e.compteur = tick + int(regles.r.craft.ticks_base)
	EventBus.emettre(&"journal", [&"journal.reforge", {"nom": e.name_key, "objet": nom_objet(objet), "composant": GameData.entree("components", str(c.composant)).name_key}])
	return true


## Apprendre le talent de classe d'un PNJ (Sans maître, Polyvalent) : relation ≥ 75, une place.
func _apprendre_talent(e: Dictionary, pnj_id: String, tick: int) -> bool:
	var pnj: Dictionary = entites.get(pnj_id, {})
	if pnj.is_empty() or Grille.distance(e.pos, pnj.pos) > 2:
		return false
	var t = GameData.catalogues.classes.get(str(pnj.get("classe", "")), {}).get("talent")
	var talent := str(t) if t != null else ""
	var peut := a_talent(e, "sans_maitre") or a_talent(e, "polyvalent")
	if talent.is_empty() or talent == "sans_maitre" or not peut or relation_de(pnj, e) < int(regles.r.talents.apprendre_relation) or a_talent(e, talent):
		EventBus.emettre(&"journal", [&"journal.talent_refuse", {}])
		return false
	e["talents_appris"] = [talent]   # une seule place : le nouveau remplace l'ancien
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.talent_appris", {"nom": pnj.name_key, "talent": GameData.entree("talents", talent).name_key}])
	_contreparties(e)
	return true


# ---------------------------------------------------------------- entraîneur (Potentiel) et commandes de collectionneurs

## L'âme d'un compagnon dans le sac, s'il y en a une (dialogue du prêtre).
func ame_dans_sac(e: Dictionary) -> String:
	for uid in e.sac:
		if items.get(uid, {}).has("compagnon"):
			return str(uid)
	return ""


func cout_resurrection(e: Dictionary, uid_ame: String, chez_pretre: bool) -> int:
	var ame: Dictionary = items.get(uid_ame, {})
	var x: Dictionary = entites.get(str(ame.get("compagnon", "")), {})
	if x.is_empty():
		return 0
	var c: Dictionary = regles.r.compagnons
	var niveau := maxi(1, int(round(progression.niveaux_derives(x).combat)))
	return int(float(c.or_par_niveau) * niveau * (float(c.get("pretre_mult", 1.0)) if chez_pretre else float(c.autel_mult)))


func cout_entrainement(e: Dictionary, competence: String) -> int:
	var en: Dictionary = regles.r.progression.entraineur
	return maxi(int(en.or_min), int(en.or_par_niveau) * regles.niveau(e.competences, competence))


func peut_entrainer(pnj: Dictionary, competence: String) -> bool:
	if not ("entraineur" in pnj.get("tags", [])):
		return false
	if str(pnj.get("fonction", "")) == "maitre_de_guilde":
		return true
	return str(GameData.catalogues.competences.get(competence, {}).get("category", "combat")) != "general"


func _entrainer(e: Dictionary, pnj_id: String, competence: String, tick: int) -> bool:
	var pnj: Dictionary = entites.get(pnj_id, {})
	if pnj.is_empty() or Grille.distance(e.pos, pnj.pos) > 2 or not peut_entrainer(pnj, competence) or not GameData.catalogues.competences.has(competence):
		return false
	var cout := cout_entrainement(e, competence)
	if int(e.or) < cout:
		EventBus.emettre(&"journal", [&"journal.entraine_refuse", {}])
		return false
	var cap := int(regles.r.progression.potentiel_max)
	var actuel := int(e.potentiels.get(competence, int(regles.r.progression.potentiel_defaut)))
	if actuel >= cap:
		EventBus.emettre(&"journal", [&"journal.entraine_plafond", {}])
		return false
	e.or = int(e.or) - cout
	pnj.or = int(pnj.or) + cout
	e.potentiels[competence] = mini(cap, actuel + int(regles.r.progression.entraineur.potentiel))
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.entraine", {"nom": pnj.name_key, "competence": _nom_competence(competence), "potentiel": int(e.potentiels[competence]), "cout": cout}])
	return true


## La commande hebdomadaire d'un collectionneur : une variété possédée, décalée d'un ou deux pas de couleur.
func _tirer_commande() -> void:
	var reg: Dictionary = territoire.get("registre", {})
	if reg.is_empty():
		return
	var cm: Dictionary = _elv().commandes
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "commande", monde.semaine_courante])
	var especes: Array = reg.keys()
	especes.sort()
	var esp_id: String = especes[rng.randi() % especes.size()]
	var esp: Dictionary = GameData.catalogues.species[esp_id]
	if not esp.loci.has("couleur"):
		return
	var cles: Array = reg[esp_id].keys()
	cles.sort()
	var parts: PackedStringArray = str(cles[rng.randi() % cles.size()]).split("|")
	var pas := rng.randi_range(1, int(cm.pas_max))
	var couleur := posmod(int(parts[0]) + pas * (1 if rng.randf() < 0.5 else -1), int(esp.loci.couleur.n))
	var pal_e := paliers_elevage()
	var mult := float(pal_e.commande_mult) * (1.0 + float(pal_e.commande_pct) / 100.0)
	var ch: Dictionary = _elv().get("chatoyant", {})
	var chatoyant := not ch.is_empty() and rng.randf() < float(ch.commande_chance)
	if chatoyant:
		mult *= float(ch.commande_mult)
	var or_ := int(round((float(cm.base) + float(cm.par_rarete) * float(esp.capture.get("rarete", 1)) + float(cm.par_pas) * float(pas)) * mult))
	territoire["commande"] = {"espece": esp_id, "couleur": couleur, "motif": parts[1] if parts.size() > 1 else "", "or": or_, "semaine": monde.semaine_courante, "chatoyant": chatoyant}
	EventBus.emettre(&"journal", [&"journal.commande", {"espece": esp.name_key, "couleur": couleur, "motif": territoire.commande.motif, "or": or_, "chatoyant": "ui.gestion.commande_chatoyant" if chatoyant else ""}])


func _total_varietes() -> int:
	var n := 0
	for esp in territoire.get("registre", {}).keys():
		n += territoire.registre[esp].size()
	return n


func _livrer_commande(e: Dictionary, pnj_id: String, tick: int) -> bool:
	var cmd: Dictionary = territoire.get("commande", {})
	var pnj: Dictionary = entites.get(pnj_id, {})
	if cmd.is_empty() or pnj.is_empty() or Grille.distance(e.pos, pnj.pos) > 2 or not ("commerce_possible" in pnj.get("tags", [])):
		return false
	var uid := ""
	for u in e.sac:
		var it: Dictionary = items.get(u, {})
		if str(it.get("espece", "")) == str(cmd.espece) and str(it.get("genome", {}).get("couleur", "")) == str(cmd.couleur) and str(it.get("genome", {}).get("motif", "")) == str(cmd.motif) and (not bool(cmd.get("chatoyant", false)) or bool(it.get("chatoyant", false))):
			uid = u
			break
	if uid.is_empty():
		EventBus.emettre(&"journal", [&"journal.commande_manque", {}])
		return false
	if int(pnj.or) < int(cmd.or):
		EventBus.emettre(&"journal", [&"journal.commande_bourse", {}])
		return false
	pnj.or = int(pnj.or) - int(cmd.or)
	e.or = int(e.or) + int(cmd.or)
	e.sac.erase(uid)
	items.erase(uid)
	territoire.erase("commande")
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.commande_livree", {"or": int(cmd.or)}])
	EventBus.emettre(&"item_sold", [uid, e.id, int(cmd.or)])
	return true


# ---------------------------------------------------------------- élevage (Annexe H) : capture, hérédité, couvées, registre

func _elv() -> Dictionary:
	return regles.r.elevage


## Un génome tiré au hasard selon les loci de l'espèce (aucune connaissance de l'espèce dans le code).
func _genome_aleatoire(esp: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var g := {}
	for nom in esp.loci.keys():
		var L: Dictionary = esp.loci[nom]
		match str(L.type):
			"anneau":
				g[nom] = rng.randi() % int(L.n)
			"nombre":
				g[nom] = snappedf(rng.randf_range(float(L.get("min", 1)), float(L.get("min", 1)) * 3.0), 0.01)
			"recessif":
				g[nom] = [rng.randi() % 2, rng.randi() % 2]
			"sequence":
				var seq: Array = []
				for k in int(L.get("n", 4)):
					seq.append(rng.randi() % int(L.get("valeurs", 2)))
				g[nom] = seq
			"age":
				g[nom] = 0
			"colonie":
				g[nom] = 1
			"lie_au_sexe":   # deux allèles (femelle) ou un (mâle) : tranché à la naissance par _exprimer_loci, ici deux
				g[nom] = [rng.randi() % int(L.get("n", 2)), rng.randi() % int(L.get("n", 2))]
			"carte":
				var carte: Array = []
				for k in int(L.get("n", 4)) * int(L.get("n", 4)):
					carte.append(1 if rng.randf() < 0.5 else 0)
				g[nom] = carte
			_:
				g[nom] = null
	return g


## Les loci qui s'expriment après la conception (Loci — les dix types) : acquis du lieu, âge, colonie.
func _exprimer_loci(sp: Dictionary, cell: Vector2i, naissance: bool) -> void:
	var esp: Dictionary = GameData.catalogues.species.get(str(sp.espece), {})
	for nom in esp.get("loci", {}).keys():
		var L: Dictionary = esp.loci[nom]
		match str(L.type):
			"acquis":
				if naissance and str(L.get("source", "")) == "corruption" and monde != null:
					sp.genome[nom] = 1 if monde.corruption_de(cell) / 100.0 >= float(L.get("seuil", 0.5)) else 0
			"age":
				sp.genome[nom] = mini(int(L.get("max", 999)), int(sp.get("age_semaines", 0)) * int(L.get("par_semaine", 1)))
			"colonie":
				if not naissance:
					sp.genome[nom] = mini(int(L.get("max", 10)), int(sp.genome.get(nom, 1)) + int(L.get("par_semaine", 1)))
			"lie_au_sexe":   # un mâle ne porte qu'un allèle
				if naissance and str(sp.get("sexe", "f")) == "m" and sp.genome.get(nom) is Array and sp.genome[nom].size() > 1:
					sp.genome[nom] = [sp.genome[nom][0]]
			"automate":   # jamais tiré : une règle sur les autres loci
				var autres: Array = []
				for k in esp.loci.keys():
					if k != nom and str(esp.loci[k].type) != "automate":
						autres.append(str(sp.genome.get(k)))
				sp.genome[nom] = posmod(hash("|".join(autres)), int(L.get("n", 8)))


## L'hérédité, locus par locus (Loci — les dix types) : une fonction par type, aucune ne connaît d'espèce.
func _heriter(a: Variant, b: Variant, L: Dictionary, rng: RandomNumberGenerator) -> Variant:
	match str(L.type):
		"anneau":   # Règle d'anneau : 34 % A, 34 % B, 16 % une voisine de A, 16 % une voisine de B
			var pr: Array = _elv().anneau
			var r := rng.randf()
			if r < float(pr[0]):
				return a
			if r < float(pr[0]) + float(pr[1]):
				return b
			var s: int = int(a) if rng.randf() < 0.5 else int(b)
			return posmod(s + (1 if rng.randf() < 0.5 else -1), int(L.n))
		"nombre":   # moyenne des parents × dérive gaussienne, sans plafond si max est null
			var v := (float(a) + float(b)) / 2.0 * (1.0 + rng.randfn(0.0, 1.0) * float(L.get("var", 0.05)))
			v = maxf(float(L.get("min", 0)), v)
			if L.get("max") != null:
				v = minf(float(L.max), v)
			return snappedf(v, 0.01)
		"recessif":
			return [a[rng.randi() % 2], b[rng.randi() % 2]]
		"sequence":
			var seq: Array = []
			for i in a.size():
				seq.append(a[i] if rng.randf() < 0.5 else b[i])
			return seq
		"carte":   # la carte d'un parent, déformée : une fraction mut de cases retournées
			if a == null or b == null:
				return a if b == null else b
			var src: Array = (a if rng.randf() < 0.5 else b).duplicate()
			for i in src.size():
				if rng.randf() < float(L.get("mut", 0.1)):
					src[i] = 1 - int(src[i])
			return src
		"lie_au_sexe":   # un allèle de la mère (a) toujours ; un du père (b) si l'enfant est femelle — tranché ensuite
			if a == null or b == null:
				return a if b == null else b
			return [a[rng.randi() % a.size()], b[rng.randi() % b.size()]]
		_:
			return null


## Les conditions de reproduction (Conditions de reproduction) : un seul évaluateur, qui dit pourquoi.
func conditions_repro(a: Dictionary, b: Dictionary, ctx: Dictionary) -> Dictionary:
	var raisons: Array = []
	if str(a.espece) != str(b.espece):
		raisons.append({"cle": "raison.espece"})
	var esp: Dictionary = GameData.catalogues.species.get(str(a.espece), {})
	for c in esp.get("repro", {}).get("conditions", []):
		match str(c.c):
			"habitat":
				if str(ctx.get("habitat", "")) != str(c.v):
					raisons.append({"cle": "raison.habitat", "v": str(c.v)})
			"place":
				if int(ctx.get("libre", 0)) <= 0:
					raisons.append({"cle": "raison.place"})
			"temperature":
				var t := float(ctx.get("temp", 18.0))
				if t < float(c.min) or t > float(c.max):
					raisons.append({"cle": "raison.temperature", "temp": int(round(t)), "min": c.min, "max": c.max})
			"saison":
				if not (str(ctx.get("saison", "")) in c.v):
					raisons.append({"cle": "raison.saison"})
			"sexe":
				if str(a.sexe) == str(b.sexe):
					raisons.append({"cle": "raison.sexe"})
			"age":
				var min_age := maxi(1, roundi(float(c.min) * float(paliers_elevage().eclosion)))   # palier 200 : éclosions plus rapides
				if mini(int(a.get("age_semaines", 0)), int(b.get("age_semaines", 0))) < min_age:
					raisons.append({"cle": "raison.age"})
			"stat":
				if minf(float(a.genome.get(str(c.k), 0)), float(b.genome.get(str(c.k), 0))) < float(c.min):
					raisons.append({"cle": "raison.stat", "k": str(c.k)})
			"colonie":   # Lucioles : elles ne s'accordent qu'en nombre (Catalogue des groupes d'élevage)
				if int(ctx.get("occupants", 0)) < int(c.min):
					raisons.append({"cle": "raison.colonie", "n": int(c.min)})
			"ressource":
				if int(territoire.stocks.get(str(c.k), 0)) < int(c.n):
					raisons.append({"cle": "raison.ressource", "k": str(c.k), "n": int(c.n)})
	return {"ok": raisons.is_empty(), "raisons": raisons}


## Capturer au filet sur une tuile d'eau adjacente : jet 1d20 + Collecte contre le dd de l'espèce.
func _capturer(e: Dictionary, tick: int) -> bool:
	if monde == null or lieu != "camp":
		return false
	var milieux: Dictionary = {"sol": true}
	for d in Grille.DIRS:
		var q: Vector2i = e.pos + d
		if not grille.dans(q):
			continue
		var tags: Array = grille.contenu_de(q).get("tags", [])
		for t in ["eau", "plante", "arbre"]:
			if t in tags:
				milieux[t] = true
	var ids: Array = GameData.catalogues.species.keys()
	ids.sort()
	var candidats: Array = []
	var refus := ""
	for sid in ids:
		var c: Dictionary = GameData.catalogues.species[sid].capture
		if not milieux.has(str(c.get("milieu", ""))):
			continue
		if bool(c.get("nuit", false)) and not est_nuit():
			refus = "journal.capture_nuit"
			continue
		if c.has("appat") and _pile_objet(e, str(c.appat)).is_empty():
			refus = "journal.capture_appat"
			continue
		candidats.append(str(sid))
	if candidats.is_empty():
		if refus == "journal.capture_appat":
			EventBus.emettre(&"journal", [&"journal.capture_appat", {"appat": "item.viande_crue.name"}])
		elif not refus.is_empty():
			EventBus.emettre(&"journal", [StringName(refus), {}])
		else:
			EventBus.emettre(&"journal", [&"journal.capture_rien", {}])
		return false
	var rng0 := RandomNumberGenerator.new()
	rng0.seed = hash([graine, "milieu", tick, e.id])
	var esp_id: String = candidats[rng0.randi() % candidats.size()]
	var esp: Dictionary = GameData.catalogues.species[esp_id]
	if esp.capture.has("appat"):
		_consommer_pile(e, _pile_objet(e, str(esp.capture.appat)))
	e.compteur = tick + int(regles.r.actions.objet) * 2
	var jet := des.jet("1d20") + regles.niveau(e.competences_eff, str(_elv().competence_capture)) + int(paliers_elevage().capture)
	var dd := int(esp.capture.get("dd", 10))
	gagner_xp(e, str(_elv().competence_capture), 5)
	if jet < dd:
		EventBus.emettre(&"journal", [&"journal.capture_ratee", {"jet": jet, "dd": dd}])
		return true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "capture", tick, e.id])
	var sp := _nouveau_specimen(esp_id, _genome_aleatoire(esp, rng), "m" if rng.randf() < 0.5 else "f", _tirer_chatoyant(rng, false))
	_exprimer_loci(sp, _cell_de(e.pos), true)
	_enregistrer_variete(sp)
	donner(e, sp.uid)
	EventBus.emettre(&"journal", [&"journal.capture_reussie", {"nom": e.name_key, "espece": esp.name_key, "couleur": str(sp.genome.get("couleur", "-")), "motif": str(sp.genome.get("motif", "-"))}])
	return true


## Le tirage du chatoyant (Vivarium — loci et variétés) : 1,5 %, ×6 si un parent l'est, ×3 au palier 500.
func _tirer_chatoyant(rng: RandomNumberGenerator, parent_chatoyant: bool) -> bool:
	var ch: Dictionary = _elv().get("chatoyant", {})
	if ch.is_empty():
		return false
	var chance := float(ch.chance)
	if parent_chatoyant:
		chance *= float(ch.mult_parent)
	if _total_varietes() >= int(ch.palier_varietes):
		chance *= float(ch.mult_palier)
	return rng.randf() < chance


func _nouveau_specimen(esp_id: String, genome: Dictionary, sexe: String, chatoyant: bool = false) -> Dictionary:
	var sp := generer_objet("specimen", 1, {"espece": esp_id}, "commun", 0)
	sp["espece"] = esp_id
	sp["genome"] = genome
	sp["sexe"] = sexe
	sp["age_semaines"] = 0
	sp["chatoyant"] = chatoyant
	if chatoyant:
		if not territoire.has("chatoyants"):
			territoire["chatoyants"] = {}
		territoire.chatoyants[esp_id] = int(territoire.chatoyants.get(esp_id, 0)) + 1
		EventBus.emettre(&"journal", [&"journal.chatoyant", {"espece": GameData.catalogues.species[esp_id].name_key}])
	sp["nom"] = {"params": {"espece": GameData.catalogues.species[esp_id].name_key, "couleur": str(genome.get("couleur", "")), "motif": str(genome.get("motif", "")), "chatoyant": "ui.specimen.chatoyant" if chatoyant else ""}}
	sp.tags = sp.tags.duplicate()
	sp.tags.erase("empilable")
	_enregistrer_variete(sp)
	return sp


func _enregistrer_variete(sp: Dictionary) -> void:
	if not territoire.has("registre"):
		territoire["registre"] = {}
	_appliquer_paliers_potentiel()
	var esp := str(sp.espece)
	if not territoire.registre.has(esp):
		territoire.registre[esp] = {}
	territoire.registre[esp][cle_variete(sp)] = true
	# Records des loci nombre et allèles vus (Vivarium — registre et paliers).
	if not territoire.has("records"):
		territoire["records"] = {}
	if not territoire.records.has(esp):
		territoire.records[esp] = {}
	var loci: Dictionary = GameData.catalogues.species.get(esp, {}).get("loci", {})
	for nom in loci.keys():
		var t := str(loci[nom].type)
		var v = sp.genome.get(nom)
		if t == "nombre" and v != null:
			territoire.records[esp][nom] = maxf(float(territoire.records[esp].get(nom, 0.0)), float(v))
		elif t in ["recessif", "lie_au_sexe"] and v is Array:
			var vus: Dictionary = territoire.records[esp].get(nom, {})
			for al in v:
				vus[str(al)] = true
			territoire.records[esp][nom] = vus


## Applique les planchers de potentiel au joueur et à ses compagnons (après une nouvelle variété, un chargement).
func _appliquer_paliers_potentiel() -> void:
	for x in entites.values():
		if x.controle == "joueur" or (x.has("maitre") and str(x.maitre) != ""):
			_paliers_potentiel(x)


## Le plancher de potentiel donné par les paliers du registre (Vivarium — registre et paliers) : sur le joueur
## et ses compagnons seulement — le registre est celui du camp.
func _paliers_potentiel(e: Dictionary) -> void:
	if not e.has("potentiels") or territoire.get("registre", {}).is_empty():
		return
	var pal := paliers_elevage()
	var n_elevage := int(pal.potentiel)
	var n_vie := int(pal.potentiel_vie)
	if n_elevage <= 0 and n_vie <= 0:
		return
	var defaut := int(regles.r.progression.potentiel_defaut)
	var cap := int(regles.r.progression.get("potentiel_max", 200))
	for cle in GameData.catalogues.competences.keys():
		var bonus := 0
		if str(cle) == "elevage":
			bonus = maxi(bonus, n_elevage)
		if str(GameData.catalogues.competences[cle].get("famille", "")) == "vie":
			bonus = maxi(bonus, n_vie)
		if bonus <= 0:
			continue
		var base := int(e.get("potentiels_base", {}).get(cle, defaut))   # un plancher sur le potentiel de base, pas un cumul
		e.potentiels[cle] = mini(cap, maxi(int(e.potentiels.get(cle, defaut)), base + bonus))


## Les paliers du registre (Vivarium — registre et paliers) : bonus de capture, couvées supplémentaires.
func paliers_elevage() -> Dictionary:
	var res := {"capture": 0, "couvees": 0, "potentiel": 0, "potentiel_vie": 0, "eclosion": 1.0, "commande_mult": 1, "commande_pct": 0, "atteints": []}
	var pal: Dictionary = _elv().get("paliers", {})
	var nv := 0
	for esp in territoire.get("registre", {}).keys():
		nv += territoire.registre[esp].size()
	var ne: int = territoire.get("registre", {}).size()
	for s in pal.get("varietes", []) + pal.get("especes", []):
		var seuil := nv if (s in pal.get("varietes", [])) else ne
		if seuil < int(s[0]):
			continue
		var effet := str(s[1])
		if effet in ["eclosion", "commande_mult"]:   # des multiplicateurs, pas des sommes
			res[effet] = float(s[2]) if effet == "eclosion" else int(s[2])
		else:
			res[effet] = int(res.get(effet, 0)) + int(s[2])
		res.atteints.append("palier." + effet)
	if ne >= GameData.catalogues.species.size() and ne > 0:
		res.capture = int(res.capture) + int(pal.get("bestiaire_complet_capture", 0))
		res.atteints.append("palier.bestiaire")
	return res


## Les variétés possibles d'une espèce : le produit des anneaux couleur × motif, sinon des loci qualitatifs.
func varietes_possibles(esp_id: String) -> int:
	var loci: Dictionary = GameData.catalogues.species.get(esp_id, {}).get("loci", {})
	var n := 1
	for nom in loci.keys():
		var L: Dictionary = loci[nom]
		match str(L.type):
			"anneau":
				n *= int(L.n)
			"sequence":
				n *= int(pow(float(L.get("valeurs", 2)), float(L.get("n", 4))))
			"automate", "acquis":
				n *= maxi(2, int(L.get("n", 2)))
	return n


## La clé d'une variété au registre (Vivarium) : les loci **qualitatifs** de l'espèce, dans l'ordre du
## catalogue — pas seulement couleur|motif, sinon une luciole (rythme) ou un coquillage (automate) ne
## collectionnerait rien. Les loci `nombre`, `age` et `colonie` en sont exclus : ils vont aux records.
func cle_variete(sp: Dictionary) -> String:
	var loci: Dictionary = GameData.catalogues.species.get(str(sp.espece), {}).get("loci", {})
	var parts: Array[String] = []
	for nom in loci.keys():
		if str(loci[nom].type) in ["anneau", "sequence", "automate", "carte", "acquis"]:
			var v = sp.get("genome", {}).get(nom)
			parts.append(",".join(v.map(func(x: Variant) -> String: return str(x))) if v is Array else str(v))
	if parts.is_empty():
		parts.append(str(sp.get("genome", {}).get("couleur", "")))
	return "|".join(parts)


## Le passage hebdomadaire de l'élevage : dans chaque vivarium de la fenêtre, le premier couple valide donne une couvée.
func _semaine_elevage() -> void:
	if monde == null or lieu != "camp":
		return
	_tirer_commande()
	for gi in grille.meubles.keys():
		var m: Dictionary = GameData.entree("meubles", str(grille.meubles[gi]))
		var specimens: Array = []
		var pos := grille.pos_de(int(gi))
		for uid in contenants.get(gi, []):
			var it: Dictionary = items.get(uid, {})
			if it.has("genome"):
				it.age_semaines = int(it.get("age_semaines", 0)) + 1
				_exprimer_loci(it, _cell_de(pos), false)
				specimens.append(it)
				var prod: Dictionary = GameData.catalogues.species[str(it.espece)].get("production", {})
				if not prod.is_empty() and (not prod.has("saisons") or saison() in prod.saisons):
					var col := 1
					for nom in it.genome.keys():
						if str(GameData.catalogues.species[str(it.espece)].loci[nom].type) == "colonie":
							col = int(it.genome[nom])
					var n := int(floor(float(prod.par_colonie) * float(col)))
					if n > 0:
						territoire.stocks[str(prod.item)] = int(territoire.stocks.get(str(prod.item), 0)) + n
						EventBus.emettre(&"journal", [&"journal.production_colonie", {"espece": GameData.catalogues.species[str(it.espece)].name_key, "n": n, "item": "item.%s.name" % str(prod.item)}])
		if specimens.size() < 2:
			continue
		var ctx := {"habitat": str(m.type_meuble), "occupants": contenants[gi].size(), "libre": int(m.capacite_slots) - contenants[gi].size(), "temp": float(temperature_ressentie({"pos": pos}).temp), "saison": saison()}
		var fait := false
		var couvees := 0
		var couvees_max: int = int(_elv().couvees_par_semaine) + int(paliers_elevage().couvees)
		var derniere: Array = []
		for i in specimens.size():
			for j in range(i + 1, specimens.size()):
				if couvees >= couvees_max:
					break
				var res := conditions_repro(specimens[i], specimens[j], ctx)
				if not res.ok:
					derniere = res.raisons
					continue
				var esp: Dictionary = GameData.catalogues.species[str(specimens[i].espece)]
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([graine, "couvee", gi, monde.semaine_courante])
				var n := mini(rng.randi_range(int(esp.repro.portee[0]), int(esp.repro.portee[1])), int(ctx.libre))
				for cout in esp.repro.get("couts", []):   # coût par croisement (vers à soie : des feuilles du stock)
					if str(cout.c) == "ressource":
						territoire.stocks[str(cout.k)] = int(territoire.stocks.get(str(cout.k), 0)) - int(cout.n)
						if int(territoire.stocks[str(cout.k)]) <= 0:
							territoire.stocks.erase(str(cout.k))
				for k in n:
					var g := {}
					for nom in esp.loci.keys():
						g[nom] = _heriter(specimens[i].genome.get(nom), specimens[j].genome.get(nom), esp.loci[nom], rng)
					var enfant := _nouveau_specimen(str(specimens[i].espece), g, "m" if rng.randf() < 0.5 else "f", _tirer_chatoyant(rng, bool(specimens[i].get("chatoyant", false)) or bool(specimens[j].get("chatoyant", false))))
					_exprimer_loci(enfant, _cell_de(pos), true)
					_enregistrer_variete(enfant)
					contenants[gi].append(enfant.uid)
					ctx.libre = int(ctx.libre) - 1
					EventBus.emettre(&"journal", [&"journal.couvee", {"espece": esp.name_key, "n": n, "couleur": str(g.get("couleur", "-")), "motif": str(g.get("motif", "-"))}])
				fait = true
				couvees += 1
		if not fait and not derniere.is_empty():
			var r0: Dictionary = derniere[0]
			EventBus.emettre(&"journal", [&"journal.couvee_refusee", {"espece": GameData.catalogues.species[str(specimens[0].espece)].name_key, "raison": str(r0.cle)}])


# ---------------------------------------------------------------- conquête, succession, repeuplement (étape 10.5)

func village_a(vers: Vector2i) -> Dictionary:
	if monde == null or lieu != "camp":
		return {}
	var v: Dictionary = monde.cellule(_cell_de(vers)).get("village", {})
	return v


func population_village(nom: String) -> Array:
	var res: Array = []
	for x in vivants():
		if str(x.get("village", "")) == nom and x.camp == "civil":
			res.append(x)
	return res


## Conquérir un village (Conquête de village) : gardes affaiblis, puis un jet de Leadership/Charisme contre 2 × population.
func _conquerir(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	var v := village_a(vers)
	if v.is_empty() or e.controle != "joueur":
		return false
	var cell := _cell_de(vers)
	var centre: Vector2i = monde.pos_monde(cell, v.centre)
	if Grille.distance(e.pos, centre) > 2 or monde.claims.has(cell):
		return false
	var cq: Dictionary = _ry().conquete
	var info: Dictionary = monde.villages.get(str(v.nom), {})
	var pop := population_village(str(v.nom))
	var gardes := 0.0
	for x in pop:
		if x.ai_profile == "garde":
			gardes += float(progression.niveaux_derives(x).combat) + 1.0
	if monde.semaine_courante < int(info.get("defense_jusqua", 0)):
		gardes *= float(cq.echec_defense_mult)
	var seuil := float(cq.gardes_pct) * float(cq.valeur_par_habitant) * float(pop.size())
	if gardes >= seuil:
		EventBus.emettre(&"journal", [&"journal.conquete_gardes", {"gardes": "%.1f" % gardes, "seuil": "%.1f" % seuil}])
		return false
	var roy_id := str(v.get("royaume", ""))
	var dd := float(cq.dd_par_habitant) * float(pop.size())
	if monde.vacances.has(roy_id):
		dd *= float(cq.vacance_dd_mult)
	var jet := des.jet("1d20") + regles.niveau(e.competences_eff, "leadership") / 2 + int(e.corps.stats.charisme) / 4
	e.compteur = tick + int(regles.r.actions.objet)
	var roy: Dictionary = monde.surface.royaume_de(cell)
	if float(jet) < dd:
		if not e.has("reputations"):
			e["reputations"] = {}
		e.reputations[str(v.nom)] = clampi(int(e.reputations.get(str(v.nom), 0)) - int(cq.echec_reputation), -100, 100)
		info["defense_jusqua"] = monde.semaine_courante + int(cq.echec_semaines)
		monde.villages[str(v.nom)] = info
		EventBus.emettre(&"journal", [&"journal.conquete_echec", {"village": v.nom, "jet": jet, "dd": int(dd)}])
		return true
	monde.claims[cell] = {"role": "habitation"}
	info["conquis_par"] = e.id
	monde.villages[str(v.nom)] = info
	if not roy.is_empty():
		var hostile := relation_royaume(e, roy) == "hostile"
		var n := int(cq.reputation_liberation) if hostile else int(cq.reputation_agression)
		_baisser_reputation(e, roy_id, -n)
		EventBus.emettre(&"journal", [&"journal.conquete_liberation" if hostile else &"journal.conquete_agression", {"royaume": roy.nom, "n": n}])
	EventBus.emettre(&"journal", [&"journal.conquete_reussie", {"village": v.nom, "jet": jet, "dd": int(dd)}])
	EventBus.emettre(&"cell_claimed", [cell])
	EventBus.emettre(&"village_conquered", [cell, e.id])
	_verifier_royaume(e)
	return true


## Un village conquis retourne à son royaume (raid de reconquête perdu).
func _rendre_village(nom: String) -> void:
	var info: Dictionary = monde.villages.get(nom, {})
	if info.is_empty() or str(info.get("conquis_par", "")).is_empty():
		return
	monde.claims.erase(info.cellule)
	info.conquis_par = ""
	EventBus.emettre(&"journal", [&"journal.village_rendu", {"village": nom, "royaume": monde.surface.royaume_de(info.cellule).get("nom", "—")}])


## Les familles d'un village (Familles et succession) : par bâtiment, le plus âgé est le parent, le second adulte
## son conjoint, les autres ses enfants.
func _former_familles(cell: Vector2i, v: Dictionary) -> void:
	var sc: Dictionary = _ry().succession
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "familles", cell])
	for bat in v.get("batiments", []):
		var lits: Dictionary = {}
		for l in bat.get("lits", []):
			lits[monde.pos_monde(cell, l)] = true
		var membres: Array = []
		for x in vivants():
			if str(x.get("village", "")) == str(v.nom) and lits.has(x.get("lit", Vector2i(-1, -1))):
				membres.append(x)
		if membres.size() < 2:
			continue
		membres.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("age", 0)) > float(b.get("age", 0)))
		var parent: Dictionary = membres[0]
		var conjoint: Dictionary = membres[1] if float(membres[1].get("age", 0)) >= float(regles.r.age.adulte) else {}
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
	for x in vivants():
		if str(x.get("village", "")) == str(v.nom) and str(x.get("fonction", "")) in ["dirigeant", "maitre_de_guilde"]:
			x["titre"] = titre_de(x)


## Le titre culturel d'un PNJ à rôle (Génération de noms) : la culture, la gouvernance de son royaume, son genre.
func titre_de(x: Dictionary) -> String:
	var culture: Dictionary = GameData.catalogues.name_cultures.get(str(x.get("social", {}).get("culture", "")), {})
	var titres: Dictionary = culture.get("titres", {})
	var gouv := ""
	if monde != null and not str(x.get("royaume", "")).is_empty():
		for sect in monde.surface.royaumes_cache.values():
			if sect.has(str(x.royaume)):
				gouv = str(sect[str(x.royaume)].government_type)
	if str(x.get("fonction", "")) == "maitre_de_guilde":
		gouv = "guilde"
	for cle in titres.keys():
		if gouv.begins_with(str(cle)):
			return str(titres[cle].get(str(x.get("genre", "m")), titres[cle].get("m", "")))
	return ""


## L'héritier d'un PNJ : l'aîné vivant de ses enfants.
func heritier_de(x: Dictionary) -> String:
	var meilleur := ""
	var age := -1.0
	for id in x.get("family", {}).get("parent_of", []):
		var enfant: Dictionary = entites.get(str(id), {})
		if not enfant.is_empty() and bool(enfant.vivant) and float(enfant.get("age", 0)) > age:
			age = float(enfant.age)
			meilleur = str(id)
	return meilleur


## La semaine des royaumes : successions, repeuplement, décimation.
func _semaine_royaumes_pnj() -> void:
	if monde == null:
		return
	for roy_id in monde.vacances.keys().duplicate():
		if monde.semaine_courante < int(monde.vacances[roy_id]):
			continue
		var meilleur: Dictionary = {}
		var niv := -1.0
		var nom_roy: String = str(roy_id)
		var gouv_id := ""
		for sect in monde.surface.royaumes_cache.values():
			if sect.has(roy_id):
				nom_roy = str(sect[roy_id].nom)
				gouv_id = str(sect[roy_id].government_type)
		var par_heritier := false
		if str(GameData.catalogues.governments.get(gouv_id, {}).get("succession", "")) == "heritier" and monde.heritiers.has(roy_id):
			var h: Dictionary = entites.get(str(monde.heritiers[roy_id]), {})
			if not h.is_empty() and bool(h.vivant):
				meilleur = h
				par_heritier = true
		monde.heritiers.erase(roy_id)
		if meilleur.is_empty():
			for x in vivants():
				if str(x.get("royaume", "")) == roy_id and x.camp == "civil" and str(x.get("fonction", "")) != "dirigeant":
					var g := float(progression.niveaux_derives(x).general)
					if g > niv:
						niv = g
						meilleur = x
		if meilleur.is_empty():
			EventBus.emettre(&"journal", [&"journal.vacance_prolongee", {"royaume": nom_roy}])
			continue
		meilleur.fonction = "dirigeant"
		meilleur["or_max"] = int(GameData.entree("functions", "dirigeant").portefeuille)
		meilleur["titre"] = titre_de(meilleur)
		monde.vacances.erase(roy_id)
		EventBus.emettre(&"journal", [&"journal.succession_heritier" if par_heritier else &"journal.succession", {"royaume": nom_roy, "nom": meilleur.name_key}])
		EventBus.emettre(&"leadership_changed", [roy_id, meilleur.id])
	# Les halls sans maître : le plus haut niveau général du village reprend le hall (2 semaines).
	for cle in monde.vacances_guildes.keys().duplicate():
		if monde.semaine_courante < int(monde.vacances_guildes[cle]):
			continue
		var parts: PackedStringArray = str(cle).split("|")
		var candidat: Dictionary = {}
		var niv_g := -1.0
		for x in vivants():
			if str(x.get("village", "")) == parts[1] and x.camp == "civil" and str(x.get("fonction", "")) in ["villageois", "oisif", "fermier", "artisan", "commercant"] and not x.has("guilde"):
				var g := float(progression.niveaux_derives(x).general)
				if g > niv_g:
					niv_g = g
					candidat = x
		if candidat.is_empty():
			continue
		candidat.fonction = "maitre_de_guilde"
		candidat["guilde"] = parts[0]
		candidat["titre"] = titre_de(candidat)
		if not ("quetes" in candidat.tags):
			candidat.tags.append("quetes")
		candidat["or_max"] = int(GameData.entree("functions", "maitre_de_guilde").portefeuille)
		monde.vacances_guildes.erase(cle)
		EventBus.emettre(&"journal", [&"journal.succession_guilde", {"nom": candidat.name_key, "guilde": "guilde.%s.name" % parts[0]}])
		EventBus.emettre(&"leadership_changed", [parts[0], candidat.id])
	var rp: Dictionary = _ry().repeuplement
	for nom in monde.villages.keys():
		var info: Dictionary = monde.villages[nom]
		if bool(info.get("abandonne", false)) or not monde.peuplees.has(info.cellule) or lieu != "camp":
			continue
		var cell: Vector2i = info.cellule
		if absi(cell.x - monde.centre.x) > monde.rayon or absi(cell.y - monde.centre.y) > monde.rayon:
			continue
		var pop := population_village(nom).size()
		var cap := int(info.get("capacite", 1))
		if pop == 0:
			info.abandonne = true
			EventBus.emettre(&"journal", [&"journal.village_abandonne", {"village": nom}])
			continue
		if pop >= cap:
			continue
		var chance := float(rp.chance) * (1.0 - float(pop) / float(cap)) * (1.0 - monde.corruption_de(cell) / 100.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([graine, "repop", nom, monde.semaine_courante])
		if rng.randf() >= chance:
			continue
		var v: Dictionary = monde.cellule(cell).get("village", {})
		for pj in v.get("pnj", []):
			var lit: Vector2i = monde.pos_monde(cell, pj.lit)
			var libre := true
			for x in population_village(nom):
				if x.get("lit", Vector2i(-1, -1)) == lit:
					libre = false
			if libre and grille.dans(lit) and grille.occupant(lit).is_empty():
				var x := ajouter(str(rp.creature), lit, "ia")
				_habiller_pnj(x, GameData.entree("creatures", str(rp.creature)), str(v.culture))
				x["lit"] = lit
				x["poste"] = lit
				x["place"] = monde.pos_monde(cell, v.centre)
				x["village"] = nom
				x["royaume"] = str(v.get("royaume", ""))
				x.ancre = lit
				# Une naissance (Familles et succession) : l'enfant d'un couple du village, sinon un arrivant.
				var mere: Dictionary = {}
				for p in population_village(nom):
					if p.id != x.id and not str(p.get("family", {}).get("spouse", "")).is_empty():
						mere = p
						break
				if not mere.is_empty():
					x.age = 0.0
					x.family.child_of = [mere.id, str(mere.family.spouse)]
					mere.family.parent_of.append(x.id)
					if entites.has(str(mere.family.spouse)):
						entites[str(mere.family.spouse)].family.parent_of.append(x.id)
					EventBus.emettre(&"journal", [&"journal.naissance", {"village": nom, "nom": mere.name_key}])
				else:
					EventBus.emettre(&"journal", [&"journal.repeuplement", {"village": nom}])
				break


# ---------------------------------------------------------------- royaumes PNJ : lois, douanes, accords (étape 10.4)

func royaume_a(vers: Vector2i) -> Dictionary:
	if monde == null or lieu != "camp":
		return {}
	return monde.surface.royaume_de(_cell_de(vers))


## Le tarif douanier d'un objet chez un PNJ (Gouvernance, lois et diplomatie) : catégorie du matériau dominant.
func tarif_de(uid: String, pnj: Dictionary) -> float:
	var roy: Dictionary = {}
	if monde != null and lieu == "camp":
		roy = monde.surface.royaume_de(_cell_de(pnj.pos))
	if roy.is_empty():
		return 0.0
	var it: Dictionary = items.get(uid, {})
	var mat := ""
	if it.has("composants") and not it.composants.is_empty():
		mat = str(it.composants[it.composants.keys()[0]].materiau)
	elif it.has("materiau"):
		mat = str(it.materiau)
	var cat := str(GameData.catalogues.materials.get(mat, {}).get("category", ""))
	var tarif := float(roy.tariffs.get(cat, roy.taxes.tariff_default)) if not cat.is_empty() else float(roy.taxes.tariff_default)
	if str(territoire.accords.get(str(roy.id), "")) == "commercial":
		tarif *= float(_ry().accords.commercial.tarif_mult)
	return tarif


## Une infraction (Lois et infractions) : lookup des lois, détection par témoin, conséquence, réputation.
func _infraction(e: Dictionary, type: String, cible: String, pos: Vector2i, uid: String) -> bool:
	var roy := royaume_a(pos)
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
	for x in vivants():
		if x.id == e.id or x.camp != "civil" or Grille.distance(x.pos, pos) > int(_ry().lois.portee_temoin_max) or not voit_ia(x, e):
			continue
		if temoin.is_empty() or Grille.distance(x.pos, pos) < Grille.distance(temoin.pos, pos):
			temoin = x
	if temoin.is_empty():
		return false
	var jet_temoin := des.jet("1d20") + int(temoin.corps.stats.perception) / 2
	var jet_joueur := des.jet("1d20") + regles.niveau(e.competences_eff, "discretion") + (int(_cycle().get("discretion_nuit", 4)) if est_nuit() else 0)   # Cycle jour-nuit : Discrétion +4 la nuit
	if jet_joueur >= jet_temoin:
		EventBus.emettre(&"journal", [&"journal.infraction_ignoree", {}])
		return false
	var cons := str(loi.consequence)
	var sev: Dictionary = _ry().lois.severite
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
		_baisser_reputation(e, str(roy.id), int(sev.amende))
	elif cons == "confiscation":
		if not uid.is_empty() and uid in e.sac:
			e.sac.erase(uid)
			e.ratelier.erase(uid)
		texte = "consequence.confiscation"
		_baisser_reputation(e, str(roy.id), int(sev.confiscation))
	else:
		for x in vivants():
			if x.camp == "civil" and str(x.get("royaume", "")) == str(roy.id) and x.ai_profile == "garde":
				x.social.relations[e.id] = -100
		texte = "consequence.gardes_hostiles"
		_baisser_reputation(e, str(roy.id), int(sev.gardes_hostiles))
	var loi_txt: String = "loi.meurtre" if cible == "meurtre" else ("loi.vol" if cible == "vol" else "loi.objet")
	EventBus.emettre(&"journal", [&"journal.infraction", {"royaume": roy.nom, "loi": loi_txt, "consequence": texte, "objet": cible, "detail": detail}])
	return true


func _baisser_reputation(e: Dictionary, roy_id: String, n: int) -> void:
	if not e.has("reputations"):
		e["reputations"] = {}
	e.reputations[roy_id] = clampi(int(e.reputations.get(roy_id, 0)) - n, -100, 100)


## Les royaumes voisins du territoire (à moins de rayon_voisin cellules d'une cellule revendiquée).
func royaumes_voisins() -> Array:
	var res: Array = []
	if monde == null:
		return res
	var r := int(_ry().pnj.rayon_voisin)
	var vus: Dictionary = {}
	for cell in monde.claims.keys():
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var roy := monde.surface.royaume_de(cell + Vector2i(dx, dy))
				if not roy.is_empty() and not vus.has(str(roy.id)):
					vus[str(roy.id)] = true
					res.append(roy)
	return res


func relation_royaume(e: Dictionary, roy: Dictionary) -> String:
	var rep := int(e.get("reputations", {}).get(str(roy.id), 0))
	if str(territoire.accords.get(str(roy.id), "")) == "alliance":
		return "allie"
	if rep <= -30:
		return "hostile"
	if rep < 0:
		return "tension"
	if rep >= 30:
		return "cordial"
	return "neutre"


## Proposer un accord à un royaume voisin (Gouvernance, lois et diplomatie) : réputation et régime décident.
func proposer_accord(e: Dictionary, roy_id: String, type: String) -> bool:
	var roy: Dictionary = {}
	for v in royaumes_voisins():
		if str(v.id) == roy_id:
			roy = v
	if roy.is_empty():
		return false
	var ac: Dictionary = _ry().accords
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
			type = "tribut_recoit" if defense_totale() > float(_ry().pnj.force_par_cellule) * float(roy.territory_cells.size()) else "tribut_paie"
	if not ok:
		EventBus.emettre(&"journal", [&"journal.accord_refuse", {"nom": roy.nom, "accord": "accord." + type}])
		return false
	territoire.accords[roy_id] = type
	EventBus.emettre(&"journal", [&"journal.accord", {"nom": roy.nom, "accord": "accord." + type}])
	return true


## Les tributs hebdomadaires et les renforts d'alliance.
func _semaine_accords() -> void:
	var ac: Dictionary = _ry().accords
	for roy_id in territoire.accords.keys():
		match str(territoire.accords[roy_id]):
			"tribut_paie":
				var n := int(ac.tribut.paie)
				if int(territoire.tresor) >= n:
					territoire.tresor = int(territoire.tresor) - n
					EventBus.emettre(&"journal", [&"journal.tribut", {"n": n, "sens": "tribut.verse"}])
				else:
					territoire.accords.erase(roy_id)   # tribut impayé : la paix tombe
			"tribut_recoit":
				territoire.tresor = int(territoire.tresor) + int(ac.tribut.recoit)
				EventBus.emettre(&"journal", [&"journal.tribut", {"n": int(ac.tribut.recoit), "sens": "tribut.recu"}])


# ---------------------------------------------------------------- défense, raids, gouvernance (étape 10.3)

func changer_gouvernance(id: String) -> bool:
	if not bool(territoire.royaume):
		EventBus.emettre(&"journal", [&"journal.gouvernance_refuse", {}])
		return false
	if not GameData.catalogues.governments.has(id) or id == str(territoire.gouvernance) or id == str(territoire.gouvernance_cible):
		return false
	var gv: Dictionary = _ry().gouvernance
	territoire.gouvernance_cible = id
	territoire.transition = int(gv.transition_semaines)
	for x in residents():
		x.humeur = int(x.get("humeur", _ry().humeur_base)) + int(gv.malus_humeur)
	EventBus.emettre(&"journal", [&"journal.gouvernance", {"gouv": GameData.entree("governments", id).name_key}])
	return true


## La défense totale (Défense et raids) : gardes × niveau × équipement + tourelles + murs, × gouvernance.
func defense_totale() -> float:
	if monde == null:
		return 0.0
	var d: Dictionary = _ry().defense
	var total := 0.0
	var dette := int(territoire.semaines_dette)
	if dette < int(d.dette_gardes):
		for x in residents():
			if str(x.assignation.fonction) != "garde":
				continue
			# « niveau mêlée » de la note = la compétence de l'arme que le garde tient (mains nues sans arme) ;
			# « melee » n'est pas une compétence du jeu — le niveau valait toujours 0.
			var fonct_g: Dictionary = fonctionnalites.get(str(Etres.arme(x, items).get("functionality", "")), {})
			var niv := regles.niveau(x.competences_eff, str(fonct_g.get("combat_skill", "mains_nues")))
			total += float(d.garde_base) * (1.0 + float(niv) / float(d.niveau_div)) * (1.0 + float(d.equipement_par_piece) * float(x.equipement.size()))
	var murs := 0
	var tourelles := 0
	if lieu == "camp":
		for gi in grille.meubles.keys():
			if str(GameData.entree("meubles", str(grille.meubles[gi])).type_meuble) == "tourelle" and monde.claims.has(_cell_de(grille.pos_de(int(gi)))):
				tourelles += 1
		for i in grille.contenu.size():
			if grille.contenu[i] > 0 and grille.contenu_ids[grille.contenu[i]] == "mur_construit" and monde.claims.has(_cell_de(grille.pos_de(i))):
				murs += 1
	if dette < int(d.dette_tourelles):
		total += float(d.tourelle) * float(tourelles)
	total += minf(float(d.mur_max), float(murs) / float(d.mur_par))
	if not str(territoire.gouvernance).is_empty():
		total *= float(GameData.entree("governments", str(territoire.gouvernance)).defense_mult)
	for roy_id in territoire.accords.keys():
		if str(territoire.accords[roy_id]) == "alliance":
			total += float(_ry().accords.alliance.defense)
	return total


## La valeur du territoire (Raids et menaces) : ce qui attire les pillards.
func valeur_territoire() -> float:
	if monde == null:
		return 0.0
	var r: Dictionary = _ry().raids
	var stocks := 0
	for n in territoire.stocks.values():
		stocks += int(n)
	return float(int(territoire.tresor) + int(territoire.caisse)) + float(r.valeur_par_stock) * float(stocks) + float(r.valeur_par_structure) * float(_structures_speciales()) + float(r.valeur_par_cellule) * float(monde.claims.size())


## Le jet hebdomadaire de raid : probabilité par corruption, valeur et réputation ; force = valeur × aléa / échelle.
func _jet_raid(e: Dictionary, tick: int) -> void:
	if monde == null or not territoire.raid.is_empty():
		return
	var r: Dictionary = _ry().raids
	var rep := int(e.get("reputations", {}).get("_globale", 0))
	var valeur := valeur_territoire()
	var proba := clampf(float(r.proba_base) + float(r.par_corruption) * monde.corruption_de(monde.cellule_camp) / 100.0 + float(r.par_valeur) * valeur + float(r.par_reputation) * float(maxi(0, -rep)), 0.0, float(r.proba_max))
	var hostile: Dictionary = {}
	if bool(territoire.royaume):   # les royaumes hostiles n'attaquent qu'un royaume reconnu (Raids et menaces)
		for roy in royaumes_voisins():
			var accord := str(territoire.accords.get(str(roy.id), ""))
			if relation_royaume(e, roy) == "hostile" and not monde.vacances.has(str(roy.id)) and not (accord in ["non_agression", "alliance", "tribut_paie", "tribut_recoit"]):
				proba = minf(float(r.proba_max), proba + float(_ry().accords.raid_hostile))
				hostile = roy
	var reconquete := ""   # un royaume d'origine hostile veut reprendre son village (Conquête de village)
	for nom in monde.villages.keys():
		var info: Dictionary = monde.villages[nom]
		if str(info.get("conquis_par", "")) == e.id:
			var roy0 := monde.surface.royaume_de(info.cellule)
			if not roy0.is_empty() and relation_royaume(e, roy0) == "hostile" and not monde.vacances.has(str(roy0.id)):
				proba = minf(float(r.proba_max), proba + float(_ry().conquete.raid_reconquete))
				reconquete = nom
				hostile = roy0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "raid", monde.semaine_courante])
	if rng.randf() >= proba:
		return
	var force := valeur * rng.randf_range(float(r.force_bornes[0]), float(r.force_bornes[1])) / float(r.echelle_force)
	if not hostile.is_empty():
		EventBus.emettre(&"journal", [&"journal.raid_royaume", {"nom": hostile.nom}])
	if lieu == "camp":
		_lancer_raid_reel(force, tick)
	else:
		_resoudre_raid_abstrait(force, tick)
		if not reconquete.is_empty() and not bool(territoire.dernier_raid.get("victoire", true)):
			_rendre_village(reconquete)


## Les pertes d'un raid (jamais de wipe) : stocks, caisse, structures de la fenêtre.
func _appliquer_pertes(perte: float) -> int:
	for cle in territoire.stocks.keys():
		territoire.stocks[cle] = int(floor(float(territoire.stocks[cle]) * (1.0 - perte)))
		if int(territoire.stocks[cle]) <= 0:
			territoire.stocks.erase(cle)
	territoire.caisse = int(floor(float(territoire.caisse) * (1.0 - perte)))
	var detruites := 0
	if lieu == "camp":
		var cibles: Array = []
		for gi in grille.stations_fixes.keys():
			if monde.claims.has(_cell_de(grille.pos_de(int(gi)))):
				cibles.append(int(gi))
		var n := int(floor(perte * float(cibles.size())))
		for k in n:
			var idx: int = cibles[k]
			var pos := grille.pos_de(idx)
			grille.contenu[idx] = 0
			grille.marquer(pos)
			grille.stations_fixes.erase(idx)
			detruites += 1
			EventBus.emettre(&"tile_changed", [pos])
	return detruites


## Joueur absent : un seul jet, force contre défense (Abstraction hors-site).
func _resoudre_raid_abstrait(force: float, tick: int) -> void:
	var r: Dictionary = _ry().raids
	var defense := defense_totale()
	var victoire := defense >= force
	var perte := float(r.perte_victoire) if victoire else clampf((force - defense) / maxf(force, 0.001), float(r.perte_bornes[0]), float(r.perte_bornes[1]))
	var detruites := _appliquer_pertes(perte)
	territoire.dernier_raid = {"force": snappedf(force, 0.1), "defense": snappedf(defense, 0.1), "victoire": victoire, "perte": perte, "tick": tick}
	EventBus.emettre(&"journal", [&"journal.raid_abstrait", {"force": "%.1f" % force, "defense": "%.1f" % defense, "issue": "ui.gestion.victoire" if victoire else "ui.gestion.defaite"}])
	if victoire:
		EventBus.emettre(&"journal", [&"journal.raid_mineur", {}])
	else:
		EventBus.emettre(&"journal", [&"journal.raid_pertes", {"perte": int(round(perte * 100.0)), "structures": detruites}])
	EventBus.emettre(&"raid_resolved", [victoire, perte])


## Joueur présent : des assaillants apparaissent au bord de la cellule du camp, profil `assaillant`.
func _lancer_raid_reel(force: float, tick: int) -> void:
	var r: Dictionary = _ry().raids
	var n := clampi(roundi(force / 2.0), int(r.assaillants_bornes[0]), int(r.assaillants_bornes[1]))
	var cell: Vector2i = monde.cellule_camp
	var coeur: Vector2i = camp_sauve.get("entree", monde.pos_monde(cell, Vector2i(monde.taille / 2, monde.taille / 2)))
	var bord: Array[Vector2i] = []
	for i in monde.taille:
		for p in [Vector2i(0, i), Vector2i(monde.taille - 1, i), Vector2i(i, 0), Vector2i(i, monde.taille - 1)]:
			var q := monde.pos_monde(cell, p)
			if grille.dans(q) and not grille.bloque_passage(q) and grille.occupant(q).is_empty():
				bord.append(q)
	if bord.is_empty():
		_resoudre_raid_abstrait(force, tick)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "raid_reel", tick])
	var depart: Vector2i = bord[rng.randi() % bord.size()]
	var ids: Array = []
	for k in n:
		var pos := depart
		for essai in 30:
			var c := depart + Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
			if grille.dans(c) and not grille.bloque_passage(c) and grille.occupant(c).is_empty():
				pos = c
				break
		var x := ajouter(str(r.chef) if k == 0 else str(r.creature), pos, "ia")
		if x.is_empty():
			continue
		x.camp = "raid"
		x.ai_profile = "assaillant"
		x.ancre = coeur
		x["raid"] = true
		ids.append(x.id)
	territoire.raid = {"fin": tick + int(r.duree_ticks), "n": ids.size(), "ids": ids, "force": force}
	EventBus.emettre(&"journal", [&"journal.raid_commence", {"n": ids.size(), "force": "%.1f" % force}])


## Le raid réel se termine quand tous sont tombés ou à l'échéance : victoire si la moitié au moins est tombée.
func _tiquer_raid(tick: int) -> void:
	if territoire.raid.is_empty() or lieu != "camp":
		return
	var rd: Dictionary = territoire.raid
	var vivants_raid := 0
	for id in rd.ids:
		if entites.has(str(id)) and bool(entites[str(id)].vivant):
			vivants_raid += 1
	if vivants_raid > 0 and tick < int(rd.fin):
		_tirs_de_tourelles(tick)
		return
	var r: Dictionary = _ry().raids
	var n := maxi(1, int(rd.n))
	var morts := n - vivants_raid
	var victoire := morts * 2 >= n
	var perte := float(r.perte_victoire) if victoire else clampf(float(vivants_raid) / float(n) * float(r.perte_bornes[1]), float(r.perte_bornes[0]), float(r.perte_bornes[1]))
	var detruites := _appliquer_pertes(perte)
	for id in rd.ids:   # les survivants restent hostiles sur place
		if entites.has(str(id)):
			entites[str(id)].erase("raid")
			entites[str(id)].ai_profile = "hostile"
			entites[str(id)].ancre = entites[str(id)].pos
	territoire.dernier_raid = {"force": snappedf(float(rd.force), 0.1), "defense": snappedf(defense_totale(), 0.1), "victoire": victoire, "perte": perte, "tick": tick}
	territoire.raid = {}
	EventBus.emettre(&"journal", [&"journal.raid_fin", {"issue": "ui.gestion.victoire" if victoire else "ui.gestion.defaite", "morts": morts, "n": n}])
	if not victoire:
		EventBus.emettre(&"journal", [&"journal.raid_pertes", {"perte": int(round(perte * 100.0)), "structures": detruites}])
	EventBus.emettre(&"raid_resolved", [victoire, perte])


## Les tourelles tirent pendant un raid réel (Défense et raids) : l'assaillant le plus proche à portée, en ligne de vue.
func _tirs_de_tourelles(tick: int) -> void:
	var d: Dictionary = _ry().defense
	var tt: Dictionary = d.get("tourelle_tir", {})
	if tt.is_empty() or int(territoire.semaines_dette) >= int(d.dette_tourelles):
		return
	if tick < int(territoire.raid.get("prochain_tir", 0)):
		return
	territoire.raid["prochain_tir"] = tick + int(tt.cadence_ticks)
	for gi in grille.meubles.keys():
		if str(GameData.entree("meubles", str(grille.meubles[gi])).type_meuble) != "tourelle":
			continue
		var pos := grille.pos_de(int(gi))
		if not monde.claims.has(_cell_de(pos)):
			continue
		var cible: Dictionary = {}
		var dmin := int(tt.portee) + 1
		for x in vivants():
			if x.camp != "raid":
				continue
			var dist := Grille.distance(pos, x.pos)
			if dist < dmin and grille.ligne_de_vue(pos, x.pos):
				dmin = dist
				cible = x
		if cible.is_empty():
			continue
		var deg := des.jet(str(tt.degats))
		_appliquer_degats(cible, deg, "tourelle", {"type": str(tt.get("type", "perforant")), "element": {}, "tourelle": true})
		EventBus.emettre(&"journal", [&"journal.tourelle_tire", {"nom": cible.name_key, "degats": deg}])


## L'assaut : vers le cœur du claim ; un mur construit qui bloque se creuse.
func _ia_assaut(e: Dictionary, tick: int) -> void:
	var coeur: Vector2i = e.ancre
	if Grille.distance(e.pos, coeur) <= 1:
		_attendre(e, tick)
		return
	var avant: Vector2i = e.pos
	_ia_pas_routine(e, coeur, tick)
	if e.pos != avant:
		return
	var meilleur := Vector2i(-1, -1)
	var dmin := Grille.distance(e.pos, coeur)
	for d in Grille.DIRS:
		var q: Vector2i = e.pos + d
		if grille.dans(q) and Grille.distance(q, coeur) < dmin and "construit" in grille.contenu_de(q).get("tags", []) and "destructible" in grille.contenu_de(q).get("tags", []):
			dmin = Grille.distance(q, coeur)
			meilleur = q
	if meilleur != Vector2i(-1, -1):
		_creuser(e, meilleur, tick)


# ---------------------------------------------------------------- parcelles et boutique passive (étape 10.2)

func _pm(vers: Vector2i) -> Vector2i:
	return vers


## La cellule d'une tuile locale de la grille courante.
func _cell_de(vers: Vector2i) -> Vector2i:
	return monde.cellule_de(vers)


## Planter une culture (Agriculture et élevage) : 1 unité consommée, sur une tuile libre voisine d'une cellule Champs.
func _planter(e: Dictionary, base: String, tick: int) -> bool:
	if monde == null or lieu != "camp" or not GameData.catalogues.plants.has(base):
		return false
	var pile := _pile_objet(e, base)
	if pile.is_empty():
		return false
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var vers: Vector2i = e.pos + d
		if not grille.dans(vers) or not grille.contenu_de(vers).is_empty() or grille.meubles.has(grille.idx(vers)) or grille.h(vers) != grille.h(e.pos):
			continue
		if str(monde.claims.get(_cell_de(vers), {}).get("role", "")) != "champs":
			continue
		var occupe := false
		for x in vivants():
			if x.pos == vers:
				occupe = true
		if occupe:
			continue
		_consommer_pile(e, pile)
		var pl: Dictionary = GameData.catalogues.plants[base]
		var duree := float(pl.duree_jours) * float(_cycle().get("ticks_par_jour", 24000))
		if "arrose" in GameData.catalogues.weather_states.get(str(meteo(_cell_de(vers))), {}).get("effects", []):   # Météo : pluie ET orage arrosent (tag arrose)
			duree *= 1.0 - float(_ry().agriculture.pluie_bonus)
		territoire.cultures[_pm(vers)] = {"plante": base, "semis": tick, "echeance": tick + int(duree), "mure": false}
		grille.poser_contenu(vers, "culture")
		grille.marquer(vers)
		e.compteur = tick + int(regles.r.actions.objet)
		EventBus.emettre(&"tile_changed", [vers])
		EventBus.emettre(&"journal", [&"journal.plante", {"nom": e.name_key, "plante": pl.name_key}])
		return true
	EventBus.emettre(&"journal", [&"journal.planter_refuse", {}])
	return false


func _consommer_pile(e: Dictionary, pile: Dictionary) -> void:
	pile.quantite = int(pile.quantite) - 1
	if int(pile.quantite) <= 0:
		e.sac.erase(pile.uid)
		e.ratelier.erase(pile.uid)


func fertilite_a(pm: Vector2i, vers: Vector2i) -> int:
	if territoire.fertilite.has(pm):
		return int(territoire.fertilite[pm])
	var sol := str(grille.sols.get(grille.idx(vers), ""))
	if sol.is_empty():
		return int(_ry().agriculture.fertilite_defaut)
	return int(GameData.catalogues.materials.get(sol, {}).get("stats", {}).get("fertilite", _ry().agriculture.fertilite_defaut))


## Fertiliser une parcelle adjacente avec un engrais brut du sac (Guano 95, Phosphorite 80, Tourbe compactée 55).
func _fertiliser(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if monde == null or not grille.dans(vers) or Grille.distance(e.pos, vers) > 1 or not territoire.cultures.has(_pm(vers)):
		return false
	var engrais: Dictionary = _ry().agriculture.engrais
	for mat in engrais.keys():
		var pile := _pile(e, str(mat), "brut")
		if pile.is_empty():
			continue
		_consommer_pile(e, pile)
		territoire.fertilite[_pm(vers)] = int(engrais[mat])
		e.compteur = tick + int(regles.r.actions.objet)
		EventBus.emettre(&"journal", [&"journal.fertilise", {"fertilite": int(engrais[mat])}])
		return true
	return false


## Récolter une parcelle mûre : recolte_base × farming_yield(biome) × (0,5 + fertilité/100), ×0,5 en canicule.
func _recolter_culture(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	var pm := _pm(vers)
	var c: Dictionary = territoire.cultures.get(pm, {})
	if c.is_empty() or tick < int(c.echeance):
		EventBus.emettre(&"journal", [&"journal.culture_pas_mure", {}])
		return false
	var cell := _cell_de(vers)
	var biome := str(monde.cellule(cell).get("biome", ""))
	var fy := float(GameData.catalogues.biomes.get(biome, {}).get("farming_yield", 1.0))
	var pl: Dictionary = GameData.catalogues.plants[str(c.plante)]
	var ag: Dictionary = regles.r.get("agriculture_recolte", {})
	var alea := float(des.jet(str(ag.get("des", "2d6")))) / float(ag.get("moyenne", 7.0))   # jamais deux récoltes identiques
	var q := float(pl.recolte_base) * fy * (0.5 + float(fertilite_a(pm, vers)) / 100.0) * alea \
		* regles.skill_factor(regles.niveau(e.competences_eff, str(ag.get("competence", "agriculture"))))
	if meteo(cell) == "canicule":
		q *= float(_ry().agriculture.canicule_facteur)
	var n := maxi(1, roundi(q))
	for k in n:
		var o := generer_objet(str(c.plante), 1, {}, "commun", 0)
		if not o.is_empty():
			donner(e, o.uid)
	territoire.cultures.erase(pm)
	territoire.fertilite.erase(pm)
	grille.contenu[grille.idx(vers)] = 0
	grille.marquer(vers)
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"tile_changed", [vers])
	EventBus.emettre(&"journal", [&"journal.recolte_culture", {"nom": e.name_key, "plante": pl.name_key, "n": n}])
	return true


## L'heure du territoire (Abstraction hors-site) : mûrissement des parcelles, ventes des boutiques.
## Rattrape toutes les heures dues — nuit sautée, voyage, retour d'expédition.
func _tiquer_territoire(tick: int) -> void:
	if monde == null or lieu != "camp":
		return
	var h_ticks := int(_cycle().get("ticks_par_jour", 24000)) / 24
	var heure_idx := tick / h_ticks
	if int(territoire.heure_resolue) < 0:
		territoire.heure_resolue = heure_idx
	var maxi_h := int(_ry().boutique.heures_max_rattrapage)
	territoire.heure_resolue = maxi(int(territoire.heure_resolue), heure_idx - maxi_h)
	while int(territoire.heure_resolue) < heure_idx:
		territoire.heure_resolue = int(territoire.heure_resolue) + 1
		var t := int(territoire.heure_resolue) * h_ticks
		_heure_parcelles(t)
		_heure_boutique(t)


func _heure_parcelles(t: int) -> void:
	for pm in territoire.cultures.keys():
		var c: Dictionary = territoire.cultures[pm]
		if bool(c.mure) or t < int(c.echeance):
			continue
		c.mure = true
		territoire.absence.mures = int(territoire.absence.mures) + 1
		var local: Vector2i = pm
		if grille.dans(local):
			grille.poser_contenu(local, "culture_mure")
			grille.marquer(local)
			EventBus.emettre(&"tile_changed", [local])
		EventBus.emettre(&"journal", [&"journal.culture_mure", {"plante": GameData.catalogues.plants[str(c.plante)].name_key}])


func population_autour(cell: Vector2i) -> int:
	var r := int(_ry().boutique.rayon)
	var n := 0
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			n += monde.cellule(cell + Vector2i(dx, dy)).get("village", {}).get("pnj", []).size()
	return n


func _stock_etal(pm: Vector2i) -> Array:
	var local: Vector2i = pm
	if grille.dans(local):
		return contenants.get(grille.idx(local), [])
	return monde.contenants_hors.get(monde.cellule_de(pm), {}).get(monde.idx_local(pm), [])


## Une heure de boutique passive : trafic par formule, clients accumulés, acceptation du prix par aléa.
func _heure_boutique(t: int) -> void:
	if territoire.etals.is_empty():
		return
	var b: Dictionary = _ry().boutique
	var joueur: Dictionary = {}
	for x in entites.values():
		if x.controle == "joueur":
			joueur = x
	var rep := int(joueur.get("reputations", {}).get("_globale", 0))
	for pm in territoire.etals.keys():
		var stock := _stock_etal(pm)
		if stock.is_empty():
			continue
		var trafic := (float(b.clients_base) + float(b.par_habitant) * float(population_autour(monde.cellule_de(pm)))) * (1.0 + float(rep) / 100.0)
		if not monde.surface.route_de(monde.cellule_de(pm)).is_empty():   # l'accessibilité (Boutique passive)
			trafic *= float(b.get("route_mult", 1.0))
		territoire.clients = float(territoire.clients) + trafic
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([graine, t, pm])
		while float(territoire.clients) >= 1.0 and not stock.is_empty():
			territoire.clients = float(territoire.clients) - 1.0
			var uid: String = str(stock[rng.randi() % stock.size()])
			var ref := int(prix_suggere(uid, {}, joueur).prix)
			var affiche := maxi(1, roundi(float(ref) * float(territoire.marge)))
			if float(affiche) <= float(ref) * rng.randf_range(float(b.acceptation[0]), float(b.acceptation[1])):
				stock.erase(uid)
				territoire.caisse = int(territoire.caisse) + affiche
				territoire.absence.ventes = int(territoire.absence.ventes) + 1
				territoire.absence.or = int(territoire.absence.or) + affiche
				EventBus.emettre(&"journal", [&"journal.vente_boutique", {"objet": nom_objet(uid), "n": affiche}])


func regler_marge(delta: float) -> void:
	var b: Dictionary = _ry().boutique
	territoire.marge = snappedf(clampf(float(territoire.marge) + delta, float(b.marge_bornes[0]), float(b.marge_bornes[1])), 0.01)
	EventBus.emettre(&"journal", [&"journal.marge", {"marge": territoire.marge}])


## Le rapport d'absence (Abstraction hors-site) : au retour d'expédition, ce que le territoire a fait.
func _rapport_absence() -> void:
	var a: Dictionary = territoire.absence
	if int(a.ventes) + int(a.mures) > 0:
		EventBus.emettre(&"journal", [&"journal.rapport_absence", {"ventes": int(a.ventes), "or": int(a.or), "mures": int(a.mures)}])
	territoire.absence = {"ventes": 0, "or": 0, "mures": 0}


# ---------------------------------------------------------------- compagnons, apprivoisement, âge

## Places d'escorte (Compagnons) : 1 + Charisme/5 + Leadership/10.
func places_escorte(e: Dictionary) -> int:
	var c: Dictionary = regles.r.compagnons
	return int(c.places_base) + int(e.stats_eff.charisme) / int(c.par_charisme) + regles.niveau(e.competences_eff, "leadership") / int(c.par_leadership) + (1 if a_talent(e, "oeil_du_prix") else 0)


func compagnons_de(e: Dictionary, avec_suiveurs: bool = true) -> Array:
	var res: Array = []
	for x in vivants():
		if str(x.get("maitre", "")) == e.id and (avec_suiveurs or not bool(x.get("suiveur_local", false))):
			res.append(x)
	return res


## Le suiveur territorial (Compagnons) : un résident assigné suit sur le territoire, sans place d'escorte.
func suiveur_local(e: Dictionary, id: String, actif: bool) -> bool:
	var x: Dictionary = entites.get(id, {})
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
	_fin_suiveur(x)
	return true


## Il redevient un résident ordinaire : plus de maître, retour au profil civil et à son poste.
func _fin_suiveur(x: Dictionary) -> void:
	x.erase("maitre")
	x.erase("suiveur_local")
	x.erase("ordre")
	x.ai_profile = "civil"
	x.cible = ""
	x.ancre = x.get("poste", x.pos)


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
	if compagnons_de(e, false).size() >= places_escorte(e):
		EventBus.emettre(&"journal", [&"journal.pas_de_place", {}])
		return false
	_devenir_compagnon(e, pnj)
	EventBus.emettre(&"journal", [&"journal.recrute", {"nom": pnj.name_key, "places": places_escorte(e)}])
	return true


## Échange d'équipement avec un compagnon (Compagnons) : donner (il s'équipe s'il peut) ou reprendre (il se déséquipe).
func echanger(e: Dictionary, id: String, uid: String, sens: String) -> bool:
	var x: Dictionary = entites.get(id, {})
	if x.is_empty() or str(x.get("maitre", "")) != e.id or not x.vivant or not items.has(uid):
		return false
	if sens == "donner":
		if not (uid in e.sac):
			return false
		e.sac.erase(uid)
		x.sac.append(uid)
		EventBus.emettre(&"journal", [&"journal.echange_donne", {"nom": x.name_key, "objet": nom_objet(uid)}])
		if not str(items[uid].get("equip_slot", "")).is_empty():
			_equiper(x, uid, tick_de(x))
		return true
	if uid in x.sac:
		x.sac.erase(uid)
	else:
		var slot := ""
		for s in x.equipement.keys():
			if str(x.equipement[s]) == uid:
				slot = str(s)
		if slot.is_empty() or not _desequiper(x, slot, tick_de(x)):
			return false
		x.sac.erase(uid)
	if uid in x.ratelier:
		x.ratelier.erase(uid)
	e.sac.append(uid)
	EventBus.emettre(&"journal", [&"journal.echange_reprend", {"nom": x.name_key, "objet": nom_objet(uid)}])
	return true


## Désigner une cible à tous ses compagnons (Compagnons : consignes de combat), sans coût de ticks.
func designer_cible(e: Dictionary, cible_id: String) -> bool:
	var c: Dictionary = entites.get(cible_id, {})
	if c.is_empty() or not c.vivant or not ennemis(e, c):
		return false
	var n := 0
	for x in compagnons_de(e):
		if not x.vivant:
			continue
		x["cible_prioritaire"] = cible_id
		x.cible = cible_id
		x.tick_derniere_vue = tick_de(x)
		x.pos_connue = c.pos
		if str(x.get("posture", "defensive")) == "eviter":
			x["posture"] = "defensive"
		_engager_combat(x, c)
		n += 1
	if n == 0:
		return false
	EventBus.emettre(&"journal", [&"journal.cible_designee", {"nom": e.name_key, "cible": c.name_key}])
	return true


## Un ordre à un compagnon : sans coût de ticks (Compagnons).
func ordonner(e: Dictionary, id: String, ordre: String) -> bool:
	var x: Dictionary = entites.get(id, {})
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
		if lieu != "camp" or monde == null or monde.cellule_de(x.pos) != monde.cellule_camp:
			EventBus.emettre(&"journal", [&"journal.retour_impossible", {}])
			return false
		x.ordre = "attendre"
		x.ancre = grille.pos_de(grille.largeur * grille.hauteur_grille / 2)
	else:
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
func _ressusciter(e: Dictionary, uid_ame: String, tick: int, pnj_id: String = "", par_sort: bool = false) -> bool:
	var ame: Dictionary = items.get(uid_ame, {})
	if ame.is_empty() or not (uid_ame in e.sac) or not ame.has("compagnon"):
		return false
	var pretre: Dictionary = entites.get(pnj_id, {})   # chez un prêtre (Compagnons) : sans le ×1,5 de l'autel, l'or va à sa bourse finie
	if not pretre.is_empty() and (not ("pretre" in pretre.get("tags", [])) or Grille.distance(e.pos, pretre.pos) > 2):
		pretre = {}
	var autel := false
	for d in Grille.DIRS:
		var t: Vector2i = e.pos + d
		if grille.dans(t) and str(grille.meubles.get(grille.idx(t), "")) == "autel_domestique":
			autel = true
	if not autel and pretre.is_empty() and not par_sort:
		EventBus.emettre(&"journal", [&"journal.pas_d_autel", {}])
		return false
	var x: Dictionary = entites.get(str(ame.compagnon), {})
	if x.is_empty():
		return false
	var c: Dictionary = regles.r.compagnons
	var niveau := maxi(1, int(round(progression.niveaux_derives(x).combat)))
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
		for k in int(regles.r.guildes.quetes_par_semaine):
			var gid: String = ids[rng.randi_range(0, ids.size() - 1)]
			var g: Dictionary = GameData.catalogues.quest_templates[gid]
			var count := rng.randi_range(int(g.count_range[0]), int(g.count_range[1]))
			var niveau := maxi(1, int(round(monde.corruption_de(monde.cellule_de(pnj.pos)) / 20.0))) if monde != null else 1
			var q := {"uid": "q_%s_%d_%d" % [pnj.id, semaine, k], "gabarit": gid, "guild": str(g.guild), "pattern": str(g.pattern), "selector": g.target_selector,
				"count": count, "fait": 0, "niveau": niveau, "or": Des.jet_rng(str(g.reward.gold_per_target_level), rng) * niveau * count, "xp": Des.jet_rng(str(g.reward.guild_xp), rng) * count,
				"text_key": str(g.text_key), "donneur": pnj.id, "village": str(pnj.get("village", "")), "cellule": monde.cellule_de(pnj.pos) if monde != null else Vector2i.ZERO, "etat": "offerte"}
			if str(g.pattern) == "livrer":   # une livraison : un objet du pool, vers un autre village connu (sinon le sien)
				# Le bien à livrer : une CATÉGORIE (denrées empilables), jamais une liste d'ids (Gabarit de quête)
				q["objet"] = GameData.tirer("items", g.target_selector.get("filtre", {"types_any": ["consommable"]}), rng)
				var autres: Array = []
				for nom_v in monde.villages.keys():
					if nom_v != str(pnj.get("village", "")):
						autres.append(nom_v)
				autres.sort()
				q["destination"] = str(autres[rng.randi() % autres.size()]) if not autres.is_empty() else str(pnj.get("village", ""))
			pnj.quetes.append(q)
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


## Le progresseur générique des quêtes (Gabarit de quête) : un pattern, des tags de contexte, le sélecteur décide.
func _progresser_quetes(e: Dictionary, pattern: String, tags: Array) -> void:
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
func _livraisons(e: Dictionary, pnj: Dictionary) -> void:
	for q in e.get("quetes", []):
		if q.etat != "en_cours" or str(q.pattern) != "livrer" or str(pnj.get("village", "")) != str(q.get("destination", "")):
			continue
		var pile := _pile_objet(e, str(q.objet))
		if pile.is_empty():
			continue
		_consommer_pile(e, pile)
		q.fait = int(q.count)
		q.etat = "terminee"
		EventBus.emettre(&"journal", [&"journal.livraison", {"nom": e.name_key, "objet": GameData.entree("items", str(q.objet)).name_key}])


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


## La saison (Décision — Saisons activées à l'étape 10) : 120 jours, cinq saisons Wu Xing, un écart de température.
func saison(tick: int = -1) -> String:
	return _saison_info(tick).id


func _saison_info(tick: int = -1) -> Dictionary:
	var t := horloge_monde.ticks if tick < 0 else tick
	var c := _cycle()
	var sa: Dictionary = c.get("saisons", {})
	if sa.is_empty():
		return {"id": "printemps", "element": "bois", "temp": 0.0}
	var jour := (t / int(c.get("ticks_par_jour", 24000))) % int(sa.jours_par_an)
	for s in sa.liste:
		if jour >= int(s[1]) and jour < int(s[2]):
			return {"id": str(s[0]), "element": str(s[3]), "temp": float(s[4])}
	return {"id": str(sa.liste[0][0]), "element": str(sa.liste[0][3]), "temp": float(sa.liste[0][4])}


## La météo d'une cellule à un instant : une fonction pure du bruit spatial lent, du temps, de la
## température et de l'humidité locales (Météo). Retourne l'id d'un état de data/weather_states/.
var meteo_force := ""   # tests et arènes : imposer un état météo
var invincible := false   # menu de triche : le joueur ne perd plus de PV (Écrans d'interface)
const RAYON_REVELE := 40   # menu de triche : cellules révélées autour du joueur (l'écran de carte en montre 33)


func meteo(cell: Vector2i, tick: int = -1) -> String:
	if not meteo_force.is_empty():
		return meteo_force
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
	var temp: float = monde.surface.valeur("temperature", int(cx) + taille / 2, int(cy) + taille / 2) + float(_saison_info(t).temp) / 40.0   # l'écart saisonnier, en fraction de la plage
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
	var temp: float = lerpf(float(m.temp_min), float(m.temp_max), temp01) + float(_saison_info().temp)
	var etat_id := meteo(cell)
	var etat: Dictionary = GameData.catalogues.weather_states.get(etat_id, {})
	temp += float(etat.get("temp_mod", 0))
	if est_nuit():
		temp += float(_cycle().get("mod_nuit", -8))
	var alt: float = float(monde.surface.tectonique_a(e.pos.x, e.pos.y).altitude)
	var ma: Dictionary = m.mod_altitude
	if not e.has("corps"):   # un point du monde, pas un être : la température brute
		return {"temp": temp, "ecart": 0.0, "meteo": etat_id}
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
		var iso := Etres.add_statuts(e, "isolation", statuts_defs)   # potion de résistance au froid
		for slot in e.equipement.keys():
			var it: Dictionary = items.get(e.equipement[slot], {})
			iso += float(it.get("stats", {}).get("isolation", 0.0))
		temp += iso / float(m.isolation_div)
		if temp < float(confort[0]):
			ecart = temp - float(confort[0])
	elif temp > float(confort[1]):
		temp -= Etres.add_statuts(e, "isolation_chaud", statuts_defs) / float(m.isolation_div)   # potion de résistance au feu
		if temp > float(confort[1]):
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
	# Sauvegarde possible partout (designer, 2026-08-31) : au camp comme en donjon. Seule l'arène de test reste hors jeu.
	if not (lieu in ["camp", "donjon"]) or monde == null:
		return false
	if lieu == "camp":
		monde.capturer(grille)
	for x in entites.values():   # aucun combat ne survit au rechargement (précédent : l'atelier) — on normalise à l'écriture
		if x.horloge != "monde":
			x.horloge = "monde"
			x.compteur = horloge_monde.ticks
			x.action_en_cours = {}
	combats.clear()
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
	var ok := Sauvegarde.ecrire(nom, "world.json", {"version": 1, "graine": graine, "graine_monde": graine_monde, "ticks": horloge_monde.ticks, "prochain_donjon": prochain_donjon, "n_entites": _n_entites,
		"cellule_camp": monde.cellule_camp, "camp": {"entree": camp_sauve.get("entree", Vector2i.ZERO), "biome": camp_sauve.get("biome", ""), "cellule": camp_sauve.get("cellule", Vector2i.ZERO)}, "explores": monde.explores,
		"delta": monde.delta, "foyers": monde.foyers, "semaine": monde.semaine_courante, "peuplees": monde.peuplees, "claims": monde.claims, "territoire": territoire, "vacances": monde.vacances, "villages": monde.villages, "heritiers": monde.heritiers, "vacances_guildes": monde.vacances_guildes,
		"modifs_terrain": modifs_terrain, "portails": portails})   # indexés par position monde, donc valables au rechargement
	ok = Sauvegarde.ecrire(nom, "surface.json", surface) and ok
	ok = Sauvegarde.ecrire(nom, "entities.json", {"entites": autres, "ordre": ordre_autres, "contenants": contenants_monde}) and ok
	ok = Sauvegarde.ecrire(nom, "items.json", instances) and ok
	ok = Sauvegarde.ecrire(nom, "players/joueur.json", {"fiche": fiche_joueur, "etre": j}) and ok
	var exp := {"lieu": lieu}
	if lieu == "donjon":   # l'expédition en cours : l'étage se régénère de sa graine, ses êtres sont dans entities.json
		var camp_ent: Dictionary = camp_sauve.get("entites", {})
		var camp_cont := {}
		if camp_sauve.has("grille") and camp_sauve.has("contenants"):
			for gi in camp_sauve.contenants.keys():
				camp_cont[camp_sauve.grille.pos_de(int(gi))] = camp_sauve.contenants[gi]
		exp = {"lieu": "donjon", "donjon": {"theme": donjon.theme, "graine": int(donjon.graine), "id": int(donjon.id), "etage": int(donjon.etage), "etages": int(donjon.etages), "cellule": donjon.get("cellule", Vector2i(-9999, -9999)), "corruption": float(donjon.get("corruption", 0.0))},
			"expedition": expedition, "camp": {"entites": camp_ent, "ordre": camp_sauve.get("ordre", []), "contenants": camp_cont}, "retour": j.get("retour", Vector2i.ZERO),
			"decouvert": grille.decouvert.duplicate()}   # le brouillard de l'étage courant survit au rechargement (l'expédition reprend où elle était)
	ok = Sauvegarde.ecrire(nom, "expedition.json", exp) and ok
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
	graine_monde = int(w.get("graine_monde", -1))   # le monde de cette partie, pas celui de planete.json
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
	monde.vacances = w.get("vacances", {})
	monde.heritiers = w.get("heritiers", {})
	monde.vacances_guildes = w.get("vacances_guildes", {})
	monde.villages = w.get("villages", {})
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
	var exp: Variant = Sauvegarde.lire(nom, "expedition.json")
	if exp != null and str(exp.get("lieu", "camp")) == "donjon":
		# Sauvegarde en expédition (designer, 2026-08-31) : l'étage se régénère de sa graine, puis les êtres
		# sauvés remplacent les êtres frais ; le camp mis de côté garde ses PNJ (réinjectés à la sortie).
		var d: Dictionary = exp.donjon
		horloge_monde = TickManager.creer("monde", Horloge.Mode.TEMPS_REEL, float(regles.r.ticks_par_seconde_exploration))
		monde.tick(int(w.ticks))
		modifs_terrain = w.get("modifs_terrain", {})
		portails = w.get("portails", {})
		joueur_sauve["retour"] = exp.get("retour", Vector2i.ZERO)
		donjon = {"etages": int(d.etages), "cellule": d.get("cellule", Vector2i(-9999, -9999)), "corruption": float(d.get("corruption", 0.0)), "id": -1}
		entites[joueur_sauve.id] = joueur_sauve   # charger_donjon reprendra cette fiche telle quelle
		lieu = "donjon"
		var pos_sauvee: Vector2i = joueur_sauve.pos   # _reprendre replace à l'entrée : on garde où le joueur a sauvé
		var statuts_sauves: Array = joueur_sauve.get("statuts", []).duplicate(true)   # et ses statuts, que _reprendre efface
		charger_donjon(str(d.theme), int(d.graine), int(d.id), int(d.etage), joueur_sauve)
		for id in ordre.duplicate():   # les êtres frais de la régénération cèdent la place aux êtres sauvés
			if id != joueur_sauve.id:
				grille.liberer(entites[id].pos)
				entites.erase(id)
				ordre.erase(id)
		for id in ent.ordre:
			entites[id] = ent.entites[id]
			ordre.append(id)
			if entites[id].vivant and grille.dans(entites[id].pos):
				grille.placer(id, entites[id].pos)
		if grille.dans(pos_sauvee) and not grille.bloque_passage(pos_sauvee) and grille.occupant(pos_sauvee).is_empty():
			grille.liberer(joueur_sauve.pos)   # le joueur reprend où il a sauvé, pas à l'entrée (Sauvegarde)
			joueur_sauve.pos = pos_sauvee
			joueur_sauve.ancre = pos_sauvee
			grille.placer(joueur_sauve.id, pos_sauvee)
		joueur_sauve.statuts = statuts_sauves
		grille.decouvert = exp.get("decouvert", grille.decouvert)   # le brouillard de l'étage tel qu'à la sauvegarde
		contenants = {}
		for pos in ent.contenants.keys():
			if grille.dans(pos):
				contenants[grille.idx(pos)] = ent.contenants[pos]
				if grille.contenu_de(pos).is_empty():
					grille.poser_contenu(pos, "butin")
		expedition = exp.get("expedition", {})
		etages_visites.clear()
		camp_sauve = {"entree": w.camp.entree, "biome": str(w.camp.biome), "cellule": w.camp.cellule,
			"entites": exp.camp.get("entites", {}), "ordre": exp.camp.get("ordre", []), "contenants_pos": exp.camp.get("contenants", {})}
		horloge_monde.ticks = int(w.ticks)
		if temps_a_l_action():
			horloge_monde.mode = Horloge.Mode.ACTION
		for x in entites.values():
			x.compteur = mini(int(x.get("compteur", 0)), horloge_monde.ticks)
		prochain_donjon = int(w.prochain_donjon)
		_n_entites = int(w.n_entites)
		maj_vision()
		EventBus.emettre(&"journal", [&"journal.chargement", {}])
		return true
	_reinitialiser()
	monde.centre = Vector2i(-1, -1)
	modifs_terrain = w.get("modifs_terrain", {})   # après _reinitialiser, qui les vide : ce que le monde doit rendre
	portails = w.get("portails", {})               # et les brèches du Passeur, indexées par position monde
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
	inst.qualite = regles.qualite_craft(regles.niveau(e.competences_eff, skill), rng, regles.resserrement_recette(niveau_recette(e, str(r.id))))
	e.sac.append(inst.uid)
	var n := regles.niveau(e.competences_eff, skill)
	e.compteur = tick + _ticks_avec_statuts(e, maxi(1, ceili(float(regles.r.craft.ticks_base) / regles.skill_factor(n))))
	gagner_xp(e, skill, int(mat.stats.durete))
	EventBus.emettre(&"journal", [&"journal.faconne", {"nom": e.name_key, "objet": nom_objet(inst.uid), "qualite": "qualite." + regles.palier_qualite(inst.qualite)}])
	_progresser_quetes(e, "fabriquer", ["composant"])
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
	var pieces: Array[Dictionary] = []
	for en in plan.entrees:
		var c: Dictionary = en.pile
		pieces.append({"slot": en.slot, "composant": c.composant, "materiau": c.materiau, "qualite": c.qualite, "stats": c.stats, "elements": c.elements})
		e.sac.erase(c.uid)
		items.erase(c.uid)
	var skill := str(def.recipe.craft_skill)
	var n := regles.niveau(e.competences_eff, skill)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "assemblage", objets.size(), def.id])
	var borne: Array = regles.r.craft.qualite.jet_assemblage
	var jet := clampf(regles.qualite_craft(n, rng, regles.resserrement_recette(niveau_recette(e, str(def.id)))), float(borne[0]), float(borne[1]))
	var inst := generer_objet(def.id, 1, {"assemblage": true}, "commun", 0)
	if inst.is_empty():
		return false
	_appliquer_composition(inst, def, pieces, jet)
	e.sac.append(inst.uid)
	e.compteur = tick + _ticks_avec_statuts(e, maxi(1, ceili(float(regles.r.craft.ticks_base) / regles.skill_factor(n))))
	gagner_xp(e, skill, inst.durete_base)
	EventBus.emettre(&"journal", [&"journal.assemble", {"nom": e.name_key, "objet": nom_objet(inst.uid), "qualite": "qualite." + regles.palier_qualite(inst.qualite)}])
	_progresser_quetes(e, "fabriquer", ["objet"])
	for x in entites.values():   # Sauvegarde : aucun combat ne survit au rechargement — tout le monde sur l'horloge du monde
		if x.horloge != "monde":
			x.horloge = "monde"
			x.compteur = horloge_monde.ticks
			x.action_en_cours = {}
	combats.clear()
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
		if bool(r.get("industrielle", false)) and not (str(rid) in e.get("recettes_connues", [])):   # Palier industriel : il faut le plan
			continue
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
	var deja: Dictionary = {}   # les piles déjà retenues par une entrée optionnelle
	# Fiole vive : le double d'ingrédients pour deux fioles — vrai pour toute recette d'alchimie,
	# y compris celles dont la sortie n'est connue qu'une fois l'ingrédient choisi (`depuis_entree`).
	var potion_double: bool = a_talent(e, "fiole_vive") and ("potion" in GameData.catalogues.items.get(str(r.get("output", {}).get("item", "")), {}).get("tags", []) or str(r.station) == "alambic")
	for entree in r.inputs:
		var besoin := int(entree.amount) * (2 if potion_double else 1)   # Fiole vive : le double d'ingrédients
		var forme := str(entree.get("forme", "brut"))
		var trouvee := {}
		var exclus: Array = e.get("exclusions_recette", {}).get(str(r.get("id", "")), [])
		for uid in e.sac:
			var it: Dictionary = items.get(uid, {})
			if deja.has(uid) or (bool(entree.get("optionnel", false)) and uid in exclus):
				continue
			if entree.has("item"):   # une entrée par objet (viande crue, baies…) : la pile de cette base
				if str(it.get("base", "")) == str(entree.item) and int(it.get("quantite", 1)) >= besoin:
					trouvee = it
					break
				continue
			if entree.has("tag"):   # une entrée par tag d'objet (toute culture pour une potion)
				if str(entree.tag) in it.get("tags", []) and int(it.get("quantite", 1)) >= besoin:
					trouvee = it
					break
				continue
			if entree.has("espece"):   # un spécimen d'élevage de cette espèce (filer la soie)
				if str(it.get("espece", "")) == str(entree.espece):
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
		if bool(entree.get("optionnel", false)):
			if trouvee.is_empty():
				continue
			deja[str(trouvee.uid)] = true
			plan.entrees.append({"pile": trouvee, "besoin": besoin, "forme": forme, "optionnel": true, "filtre": str(entree.get("material", entree.get("category", entree.get("item", entree.get("tag", entree.get("espece", ""))))))})
			continue
		plan.entrees.append({"pile": trouvee, "besoin": besoin, "forme": forme, "filtre": str(entree.get("material", entree.get("category", entree.get("item", entree.get("tag", entree.get("espece", ""))))))})
		if trouvee.is_empty():
			plan.faisable = false
		elif mat_sortie.is_empty() and trouvee.has("materiau"):
			mat_sortie = str(trouvee.materiau)   # la sortie garde le matériau de l'entrée (lingot de fer…)
	plan.sortie = {"materiau": mat_sortie, "forme": str(r.output.get("forme", "brut")), "quantite": int(r.output.amount), "item": str(r.output.get("item", ""))}
	if r.output.has("depuis_entree"):   # la sortie se lit sur l'INGRÉDIENT (Craft compositionnel) : une seule
		plan.sortie.item = ""            # recette « distiller une herbe » plutôt qu'une par plante du jeu
		for entree in plan.entrees:
			if str(entree.filtre) != str(r.output.depuis_entree) or entree.pile.is_empty():
				continue
			var fiche: Dictionary = GameData.catalogues.items.get(str(entree.pile.get("base", "")), {})
			plan.sortie.item = str(fiche.get(str(r.output.champ), ""))
		if plan.sortie.item.is_empty():
			plan.faisable = false
	if r.output.has("par_locus") and plan.faisable:   # la quantité suit un locus du spécimen consommé (finesse du fil)
		for entree in plan.entrees:
			if entree.pile.has("genome"):
				plan.sortie.quantite = maxi(1, roundi(float(entree.pile.genome.get(str(r.output.par_locus), 1)) * float(r.output.amount)))
	return plan


## Les ingrédients optionnels candidats d'une recette (Décision — Affinités de cuisine) : chaque pile du sac
## qui correspond à une entrée optionnelle, incluse ou exclue par le joueur.
func candidats_optionnels(e: Dictionary, r: Dictionary) -> Array:
	var res: Array = []
	var exclus: Array = e.get("exclusions_recette", {}).get(str(r.get("id", "")), [])
	for uid in e.sac:
		var it: Dictionary = items.get(uid, {})
		var ok := false
		for entree in r.get("inputs", []):
			if not bool(entree.get("optionnel", false)):
				continue
			if entree.has("tag") and str(entree.tag) in it.get("tags", []):
				ok = true
			elif entree.has("item") and str(it.get("base", "")) == str(entree.item):
				ok = true
			elif entree.has("material") and it.get("type", "") == "materiau" and str(it.get("materiau", "")) == str(entree.material) and str(it.get("forme", "brut")) == str(entree.get("forme", "brut")):
				ok = true
		if ok:
			res.append({"uid": uid, "inclus": not (uid in exclus)})
	return res


func basculer_ingredient(e: Dictionary, rid: String, uid: String) -> void:
	if not e.has("exclusions_recette"):
		e["exclusions_recette"] = {}
	if not e.exclusions_recette.has(rid):
		e.exclusions_recette[rid] = []
	if uid in e.exclusions_recette[rid]:
		e.exclusions_recette[rid].erase(uid)
	else:
		e.exclusions_recette[rid].append(uid)


## Le vecteur et l'harmonie qu'un plan de plat donnerait (aperçu de l'atelier).
func harmonie_prevue(plan: Dictionary) -> Dictionary:
	var wx := {}
	for entree in plan.entrees:
		var v: Dictionary = entree.pile.get("wuxing", {})
		if v.is_empty() and entree.pile.get("type", "") == "materiau":
			v = regles.r.craft.harmonie.ingredients_materiaux.get(str(entree.pile.get("materiau", "")), GameData.catalogues.materials.get(str(entree.pile.get("materiau", "")), {}).get("wuxing", {}))
		for el in v.keys():
			wx[el] = float(wx.get(el, 0.0)) + float(v[el])
	if wx.is_empty():
		return {}
	wx["feu"] = float(wx.get("feu", 0.0)) + float(regles.r.craft.harmonie.feu_cuisson)
	var total := 0.0
	for el in wx.keys():
		total += float(wx[el])
	var n := 0
	for el in wuxing.w.elements:
		if float(wx.get(el, 0.0)) > 0.0:
			n += 1
		wx[el] = snappedf(float(wx.get(el, 0.0)) / total, 0.01)
	return {"vecteur": wx, "elements": n, "harmonie": n >= wuxing.w.elements.size()}


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
	if bool(r.get("industrielle", false)) and not (rid in e.get("recettes_connues", [])):
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
	if not str(sortie.get("item", "")).is_empty():   # un objet fini (meuble, station, plat, potion) : XP = dureté des entrées
		var nom_obj := ""
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([graine, "plat", objets.size(), r.id])
		for k in int(sortie.quantite):
			var inst := generer_objet(str(sortie.item), 1, {}, "commun", 0)
			if not inst.is_empty():
				if inst.get("type", "") == "consommable":   # un plat : qualité A.3 sur Cuisine, empilé
					inst.qualite = snappedf(regles.qualite_craft(regles.niveau(e.competences_eff, str(r.craft_skill)), rng, regles.resserrement_recette(niveau_recette(e, str(r.id)))), 0.01)
					if "potion" in inst.get("tags", []) and float(inst.qualite) >= float(regles.r.alchimie.seuil_forte) and statuts_defs.has(str(inst.get("statut", "")) + "_forte"):
						inst.statut = str(inst.statut) + "_forte"   # une potion forte (Cuisine et alchimie)
					var wx := {}   # le vecteur du plat : Σ ingrédients + la cuisson (Décision — Affinités de cuisine)
					for entree in plan.entrees:
						var v: Dictionary = entree.pile.get("wuxing", {})
						if v.is_empty() and entree.pile.get("type", "") == "materiau":   # un matériau en cuisine : son vecteur de cuisine (le sel), sinon celui du matériau
							v = regles.r.craft.harmonie.ingredients_materiaux.get(str(entree.pile.get("materiau", "")), GameData.catalogues.materials.get(str(entree.pile.get("materiau", "")), {}).get("wuxing", {}))
						for el in v.keys():
							wx[el] = float(wx.get(el, 0.0)) + float(v[el])
					if not wx.is_empty():
						var ha: Dictionary = regles.r.craft.harmonie
						wx["feu"] = float(wx.get("feu", 0.0)) + float(ha.feu_cuisson)
						var total := 0.0
						for el in wx.keys():
							total += float(wx[el])
						for el in wx.keys():
							wx[el] = snappedf(float(wx[el]) / total, 0.01)
						inst["wuxing"] = wx
						var cinq := true
						for el in wuxing.w.elements:
							cinq = cinq and float(wx.get(el, 0.0)) > 0.0
						if cinq:
							inst["harmonie"] = float(ha.mult)
					var pot: Dictionary = inst.get("potentiel", {}).duplicate()
					for entree in plan.entrees:   # ingrédients paramétriques : la puissance de la partie, les potentiels des viandes
						if entree.pile.has("puissance") and "potion" in inst.get("tags", []):
							inst["puissance"] = float(entree.pile.puissance)
						for st in entree.pile.get("potentiel", {}).keys():
							pot[st] = int(pot.get(st, 0)) + int(entree.pile.potentiel[st])
					inst.potentiel = pot
					var pile := _pile_objet(e, str(sortie.item))
					if not pile.is_empty():
						pile.quantite = int(pile.quantite) + 1
						items.erase(inst.uid)
						nom_obj = pile.name_key
						continue
				e.sac.append(inst.uid)
				nom_obj = inst.name_key
		gagner_xp(e, str(r.craft_skill), maxi(10, durete_entrees))
		var genre_obj: Dictionary = GameData.catalogues.items.get(str(sortie.item), {})
		var tags_q: Array = ["objet"]
		if genre_obj.get("type", "") == "consommable":
			tags_q = ["plat"] if not ("potion" in genre_obj.get("tags", [])) else ["potion"]
		_progresser_quetes(e, "fabriquer", tags_q)
		EventBus.emettre(&"journal", [&"journal.fabrique", {"nom": e.name_key, "quantite": int(sortie.quantite), "objet": nom_obj, "recette": r.name_key}])
		return true
	_donner_materiau(e, sortie.materiau, int(sortie.quantite), sortie.forme)
	var mat: Dictionary = GameData.catalogues.materials.get(str(sortie.materiau), {})
	gagner_xp(e, str(r.craft_skill), int(mat.get("stats", {}).get("durete", 1)))
	_progresser_quetes(e, "fabriquer", ["materiau"])
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
	charger_donjon(donjon.theme, int(donjon.graine), int(donjon.id), prochain, e)
	# Le message d'arrivée dit l'étage, la profondeur du donjon, la corruption et le nombre de salles (parcours du 2026-08-30)
	EventBus.emettre(&"journal", [&"journal.descente", {"etage": prochain, "etages": int(donjon.etages), "corruption": int(donjon.get("corruption_etage", 0)), "salles": int(donjon.salles)}])
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
		_tiquer_territoire(horloge_monde.ticks)   # les heures d'absence sont résolues au retour (Abstraction hors-site)
		_rapport_absence()
		if recap.boss_vaincu and monde != null and cell_donjon != Vector2i(-9999, -9999):
			monde.nettoyer(cell_donjon, horloge_monde.ticks)   # Dérive de la corruption : foyer nettoyé
			EventBus.emettre(&"journal", [&"journal.donjon_nettoye", {}])
			_quetes_sur_donjon(cell_donjon, e.id)
			EventBus.emettre(&"dungeon_cleared", [cell_donjon, e.id])
		sauvegarder(slot_autosave)   # autosave au retour (Sauvegarde : sur événements clés)
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
	if controle == "joueur":   # les modules des capacités de départ sont connus, avec un kit de charges au dé
		for m in def.get("modules_connus", []):
			crediter_module(e, str(m), charges_lues(e, true))
		for cap in e.get("capacites", []):
			for m in cap.get("modules", []):
				if int(e.get("modules_charges", {}).get(str(m), 0)) <= 0:
					crediter_module(e, str(m), charges_lues(e, true))
	_contreparties(e)
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
## Le stock d'un marchand, décrit par des CATÉGORIES (`{filtre, nombre}`) et jamais par une liste d'objets :
## une boutique d'armurier vend « les armures de prototype en métal », donc toute armure qui le sera un jour.
## Complété chaque semaine quand il est vide (Commerce et boutiques).
func _garnir_stock(e: Dictionary, selection: Array) -> void:
	if not e.has("stock"):
		e["stock"] = []
	var rng := RandomNumberGenerator.new()
	var sem := 0
	if horloge_monde != null:
		sem = horloge_monde.ticks / maxi(1, int(GameData.config("planete").corruption.ticks_par_semaine))
	rng.seed = hash([graine, "stock", e.id, sem])
	for bloc: Dictionary in selection:
		var n := rng.randi_range(int(bloc.nombre[0]), int(bloc.nombre[1]))
		for k in n:
			var base := GameData.tirer("items", bloc.filtre, rng)
			if base.is_empty():
				continue   # une catégorie vide n'est pas une erreur de jeu : l'audit des données la signale
			var o := generer_objet(base, 1, {"categories_materiau": bloc.get("materiaux", [])}, "commun", 0)   # un forgeron assemble dans le métal
			if not o.is_empty():
				e.stock.append(o.uid)


func generer_objet(base_id: String, profondeur: int, provenance: Dictionary = {}, rarete: String = "", nb_affixes: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, "loot", objets.size(), base_id, profondeur])
	var inst := loot.generer(base_id, profondeur, rng, provenance, rarete, nb_affixes)
	if inst.is_empty():
		return {}
	objets[inst.uid] = inst
	items[inst.uid] = inst
	if "assemble" in inst.get("tags", []) and not bool(provenance.get("assemblage", false)):
		_composer_loot(inst, profondeur, rng, provenance.get("categories_materiau", []))   # un objet assemblé trouvé est composé : manche, tête, fixations tirés (designer, 2026-08-30)
	return inst


## Le loot assemblé (Loot — affixes, gemmes et rareté, 2026-08-30) : jamais « une simple épée » — chaque composant
## reçoit une recette, un matériau de sa famille (les minerais de l'étage favorisés) et une qualité d'artisan.
func _composer_loot(inst: Dictionary, profondeur: int, rng: RandomNumberGenerator, cats_mat: Array = []) -> void:
	var def: Dictionary = GameData.entree("items", str(inst.base))
	if def.get("slots", {}).is_empty():
		return
	var la: Dictionary = GameData.config("loot_rules").get("assemblage", {})
	var niveau := int(la.get("niveau_base", 8)) + int(la.get("niveau_par_profondeur", 6)) * maxi(0, profondeur)
	var pieces: Array[Dictionary] = []
	for slot in def.slots.keys():
		var comp_id := str(def.slots[slot])
		var recettes: Array = []
		for rid in GameData.catalogues.component_recipes.keys():
			if str(GameData.catalogues.component_recipes[rid].component) == comp_id:
				recettes.append(GameData.catalogues.component_recipes[rid])
		if recettes.is_empty():
			continue
		recettes.shuffle()   # une famille sans matériau au catalogue (os, écailles… paramétriques) : la recette suivante
		var mat_id := ""
		for r in recettes:
			var fam: Dictionary = GameData.config("material_families").get(str(r.material_family), {})
			mat_id = _materiau_loot(fam, profondeur, rng, cats_mat if slot in ["tete", "plaque"] else [])   # la catégorie demandée vaut pour la pièce maîtresse
			if not mat_id.is_empty():
				break
		if mat_id.is_empty():
			continue
		var mat: Dictionary = GameData.entree("materials", mat_id)
		pieces.append({"slot": slot, "composant": comp_id, "materiau": mat_id, "qualite": regles.qualite_craft(niveau, rng),
			"stats": mat.get("stats", {}), "elements": mat.get("wuxing", {}) if mat.get("wuxing") != null else {}})
	if pieces.is_empty():
		return
	var borne: Array = regles.r.craft.qualite.jet_assemblage
	var jet := clampf(regles.qualite_craft(niveau, rng), float(borne[0]), float(borne[1]))
	_appliquer_composition(inst, def, pieces, jet)


## Un matériau d'une famille (Recettes de composants) pour le loot : les minerais des étages ≤ profondeur pèsent plus.
func _materiau_loot(fam: Dictionary, profondeur: int, rng: RandomNumberGenerator, cats_mat: Array = []) -> String:
	var candidats: Array[String] = []
	if fam.has("material"):
		candidats.append(str(fam.material))
	elif fam.has("materials"):
		for m in fam.materials:
			candidats.append(str(m))
	else:
		for m in GameData.catalogues.materials.keys():
			var d: Dictionary = GameData.catalogues.materials[m]
			if fam.has("category") and str(d.get("category", "")) == str(fam.category):
				candidats.append(str(m))
			elif fam.has("tag") and str(fam.tag) in d.get("tags", []):
				candidats.append(str(m))
	candidats = candidats.filter(func(m: String) -> bool: return GameData.catalogues.materials.has(m))
	if not cats_mat.is_empty():   # une boutique demande une catégorie (métal chez le forgeron) : cette famille doit la fournir
		candidats = candidats.filter(func(m: String) -> bool: return str(GameData.catalogues.materials[m].get("category", "")) in cats_mat)
	if candidats.is_empty():
		return ""
	var tiers: Dictionary = GameData.config("minerais_par_etage").get("tiers", {})
	var la: Dictionary = GameData.config("loot_rules").get("assemblage", {})
	var favoris := {}
	var trop_profonds := {}   # un minerai d'un tier trop profond pour l'étage n'apparaît pas (pas de titane à l'étage 2)
	for k in tiers.keys():
		for m in tiers[k]:
			if int(k) <= maxi(1, profondeur):
				favoris[str(m)] = true
			elif int(k) > maxi(1, profondeur) + int(la.get("tiers_au_dela", 1)):
				trop_profonds[str(m)] = true
	var sans := candidats.filter(func(m: String) -> bool: return not trop_profonds.has(m))
	if not sans.is_empty():
		candidats = sans
	var poids_fav := float(la.get("poids_etage", 3))
	var total := 0.0
	for m in candidats:
		total += poids_fav if favoris.has(m) else 1.0
	var t := rng.randf() * total
	for m in candidats:
		t -= poids_fav if favoris.has(m) else 1.0
		if t < 0.0:
			return m
	return candidats[candidats.size() - 1]


## Ce que les composants font à l'objet (Stats et qualité de l'assemblage) : stats = Σ stat × poids, durete_base avant
## qualité, qualité = Σ q × poids × jet, Wu Xing composite, matériau de la tête, vitesse du manche. Partagé par
## l'atelier (_assembler) et le loot (_composer_loot).
func _appliquer_composition(inst: Dictionary, def: Dictionary, pieces: Array[Dictionary], jet: float) -> void:
	var poids: Dictionary = regles.r.craft.poids.armure if def.type == "armure" else regles.r.craft.poids.arme
	var stats := {}
	var elements := {}
	var q_somme := 0.0
	var composants := {}
	var tete: Dictionary = {}
	var manche: Dictionary = {}
	for c in pieces:
		var w := float(poids.get(c.slot, 0.0))
		for s in c.stats.keys():
			stats[s] = float(stats.get(s, 0.0)) + float(c.stats[s]) * w
		for el in c.elements.keys():
			elements[el] = float(elements.get(el, 0.0)) + float(c.elements[el]) * w
		q_somme += float(c.qualite) * w
		composants[c.slot] = {"composant": c.composant, "materiau": c.materiau, "qualite": c.qualite}
		if c.slot in ["tete", "plaque"]:
			tete = c
		elif c.slot == "manche":
			manche = c
	inst.stats = stats
	inst.durete_base = roundi(float(stats.get("durete", 0.0)))   # la moyenne pondérée AVANT qualité
	inst.qualite = snappedf(q_somme * jet, 0.01)
	inst.elements = elements
	inst.element = wuxing.dominante(elements)
	inst.materiau = str(tete.get("materiau", ""))
	inst.composants = composants
	if not manche.is_empty():
		var v: Dictionary = regles.r.craft.vitesse
		inst.vitesse_facteur = snappedf(1.0 + (float(manche.stats.get("densite", v.densite_reference)) - float(v.densite_reference)) * float(v.par_point), 0.01)
	if def.type == "armure":
		inst.durete_composite = inst.durete_base
		inst.niveau_construction = 0


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
	if str(e.get("classe", "")).is_empty():   # une classe tirée parmi celles de sa fonction (Les trois axes)
		var possibles: Array = GameData.catalogues.functions.get(e.fonction, {}).get("classes_possibles", [])
		if not possibles.is_empty():
			e.classe = str(possibles[rng.randi() % possibles.size()])
	e["social"] = {"culture": culture_id, "relations": {}}
	var f: Dictionary = GameData.catalogues.functions.get(e.fonction, {})
	e["or_max"] = int(float(f.get("portefeuille", 30)) * (1.0 + float(e.get("rang", 0)) * 0.5))
	e.or = e.or_max
	e["stock"] = []
	_garnir_stock(e, def.get("stock_marchand", []))
	e["dernieres_repliques"] = []
	e["dernier_parler_jour"] = -1
	e["family"] = {"parent_of": [], "child_of": [], "spouse": ""}
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
	var roy := str(pnj.get("royaume", ""))
	if not roy.is_empty():
		e.reputations[roy] = clampi(int(e.reputations.get(roy, 0)) + int(gains[1]), -100, 100)
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
					if pj.has("fonction"):
						x.fonction = str(pj.fonction)
					_habiller_pnj(x, GameData.entree("creatures", str(pj.creature)), str(v.culture))
					if not str(pj.get("boutique", "")).is_empty():   # une boutique typée : les catégories du type
						x["boutique"] = str(pj.boutique)
						x.stock = []
						_garnir_stock(x, GameData.entree("shop_types", str(pj.boutique)).selection)
					if not str(pj.get("guilde", "")).is_empty():
						x["guilde"] = str(pj.guilde)
					x["lit"] = monde.pos_monde(cell, pj.lit)
					x["poste"] = pos
					x["place"] = monde.pos_monde(cell, v.centre)
					x["village"] = str(v.nom)
					x["royaume"] = str(v.get("royaume", ""))
					x.ancre = pos
			if not monde.villages.has(str(v.nom)):
				monde.villages[str(v.nom)] = {"cellule": cell, "royaume": str(v.get("royaume", "")), "conquis_par": "", "defense_jusqua": 0, "abandonne": false, "capacite": v.pnj.size()}
			_former_familles(cell, v)
			EventBus.emettre(&"journal", [&"journal.village", {"nom": v.nom}])


## Donne un objet à un être (dans son sac).
func donner(e: Dictionary, uid: String) -> void:
	if items.has(uid) and not (uid in e.sac):
		var it: Dictionary = items[uid]
		if "empilable" in it.get("tags", []) and it.get("type", "") == "consommable":
			var pile := _pile_objet(e, str(it.get("base", "")))
			if not pile.is_empty() and float(pile.get("puissance", 1.0)) != float(it.get("puissance", 1.0)):
				pile = {}   # une pile ne mêle pas deux puissances (viande d'ours, viande de renard)
			if not pile.is_empty() and pile.get("potentiel", {}) != it.get("potentiel", {}):
				pile = {}
			if not pile.is_empty():
				pile.quantite = int(pile.quantite) + int(it.get("quantite", 1))
				items.erase(uid)
				EventBus.emettre(&"journal", [&"journal.loot", {"nom": e.name_key, "objet": nom_objet(pile.uid)}])
				return
		e.sac.append(uid)
		EventBus.emettre(&"journal", [&"journal.loot", {"nom": e.name_key, "objet": nom_objet(uid)}])
		if e.controle == "joueur" and lieu == "camp":
			_infraction(e, "objet", str(it.get("base", "")), e.pos, uid)


## Le nom affichable d'un objet : {"base": name_key, "affixe": id ou "", "params": {}} — le client formate.
## La fiche de créature d'une entité (drops pondérés par race — Créatures).
func def_stats_c(cible: Dictionary) -> Dictionary:
	return GameData.catalogues.creatures.get(str(cible.def), {})


func nom_objet(uid: String) -> Dictionary:
	var it: Dictionary = items.get(uid, {})
	var nom: Dictionary = it.get("nom", {})
	var res := {"base": it.get("name_key", uid), "affixe": nom.get("affixe", ""), "params": nom.get("params", {}), "rarete": it.get("rarete", "commun")}
	if nom.has("de_creature"):   # « Statue de loup » : le nom porte la créature dont l'objet est tiré
		res["de_creature"] = str(nom.de_creature)
	if it.get("type", "") in ["grimoire", "manuel"] and it.has("modules"):   # un livre dit son domaine et sa difficulté
		res["livre"] = {"domaine": str(it.get("domaine", "")), "difficulte": int(it.get("difficulte", 0)), "n": it.modules.size()}
		if nom.has("module"):   # un livre de module : le module au nom
			res["module_livre"] = str(nom.module)
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
	if str(e.corps.get("silhouette", "humanoide")) != "humanoide" and not (slot in regles.r.talents.incarnation.slots_bete):   # pas de mains (Changer de personnage)
		EventBus.emettre(&"journal", [&"journal.pas_de_mains", {}])
		return false
	if a_talent(e, "sans_chair") and slot in regles.r.talents.sans_chair.slots_refuses:   # le Spectre ne porte aucune armure
		EventBus.emettre(&"journal", [&"journal.armure_refusee", {}])
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
	var or_perdu := int(floor(float(e.get("or", 0)) * float(regles.r.mort.get("perte_or", 0.0))))   # Mort et pénalité : −10 % de l'or porté
	if or_perdu > 0:
		e.or = int(e.or) - or_perdu
		EventBus.emettre(&"journal", [&"journal.mort_or", {"nom": e.name_key, "or": or_perdu}])
	if en_combat(e):
		_quitter_combat(e)
	e.vivant = true
	e.sante = e.sante_max
	e.endurance = e.endurance_max
	e.statuts = []
	e.action_en_cours = {}
	if monde != null and lieu != "arene" and not a_talent(e, "sans_chair") and monde.corruption_de(_cell_de(e.pos)) >= float(regles.r.talents.sans_chair.corruption_seuil):
		_devenir_spectre(e)   # mort en forte corruption sans Renaissance (Talents de race)
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
	if not grille.dans(spawn) or not grille.occupant(spawn).is_empty() or grille.bloque_passage(spawn):   # le spawn d'une autre grille (camp → donjon) ne vaut rien ici
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
	if bool(it.get("fini", false)):
		EventBus.emettre(&"journal", [&"journal.objet_fini", {}])
		return false
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
	if str(e.corps.get("silhouette", "humanoide")) != "humanoide":   # une bête ne lit pas (Changer de personnage)
		EventBus.emettre(&"journal", [&"journal.pas_de_lecture", {}])
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
	if succes and livre.has("recette") and not str(livre.recette).is_empty():   # un plan industriel : une recette apprise
		if not e.has("recettes_connues"):
			e["recettes_connues"] = []
		if str(livre.recette) in e.recettes_connues:
			_doublon_recette(e, str(livre.recette))   # Axe des niveaux de recette : le doublon fait monter le niveau
		else:
			e.recettes_connues.append(str(livre.recette))
			EventBus.emettre(&"journal", [&"journal.plan_appris", {"nom": e.name_key, "recette": GameData.catalogues.recipes[str(livre.recette)].name_key}])
		gagner_xp(e, "lecture", int(livre.difficulte) * int(lv.xp_succes))
		e.compteur = tick + int(regles.r.actions.objet)
		EventBus.emettre(&"book_read", [e.id, objet, true])
		return true
	if succes:
		var n: int = livre.modules.size()
		if marge < 10:
			n = maxi(1, int(floorf(float(livre.modules.size()) * minf(1.0, float(n_lecture) / float(livre.difficulte)))))
		for k in n:
			var m: String = str(livre.modules[k])
			crediter_module(e, m, charges_lues(e))   # un jet par module, porté par la Lecture
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
	# Le drop rare universel (Créatures) : la statue 1:1 de la bête abattue, meuble décoratif et trophée.
	if cible.controle == "ia" and lr.drops.has("statue"):
		var st: Dictionary = lr.drops.statue
		var mult := float(def_stats_c(cible).get("statue_mult", 1.0))
		if rng.randf() < float(st.chance) * mult:
			var stat_moy := 0.0
			var stats_s: Dictionary = GameData.catalogues.creatures.get(str(cible.def), {}).get("corps", {}).get("stats", {})
			for v in stats_s.values():
				stat_moy += float(v)
			stat_moy = stat_moy / maxf(1.0, float(stats_s.size()))
			var statue := generer_objet(str(st.item), profondeur, {"creature": cible.name_key}, "commun", 0)
			if not statue.is_empty():
				statue["valeur"] = maxf(1.0, stat_moy * float(st.valeur_par_stat))   # Prix suggéré : ∝ niveau de la créature
				statue["nom"] = {"affixe": "", "params": {}, "de_creature": str(cible.name_key)}
				uids.append(statue.uid)
				EventBus.emettre(&"journal", [&"journal.statue", {"nom": cible.name_key}])
	# Un plan industriel dans les ruines profondes (Palier industriel).
	if cible.controle == "ia" and lr.drops.has("plan") and profondeur >= int(lr.drops.plan.profondeur_min) and rng.randf() < float(lr.drops.plan.chance):
		var plan_i := generer_objet("plan_industriel", profondeur, {"creature": cible.name_key}, "commun", 0)
		if not plan_i.is_empty():
			uids.append(plan_i.uid)
	# Le boss d'un donjon : un artefact, garanti si le donjon est majeur (Trésors et artefacts).
	if bool(cible.get("chain_gauge", false)) and lieu != "camp" and lr.drops.has("artefact"):
		var majeur := int(donjon.get("etages", 1)) >= int(lr.drops.artefact.etages_majeur)
		if majeur or rng.randf() < float(lr.drops.artefact.chance_boss):
			var art := generer_objet(str(loot._base_pour(rng)), profondeur, {"boss": cible.name_key}, "artefact")
			if not art.is_empty():
				uids.append(art.uid)
				EventBus.emettre(&"journal", [&"journal.artefact", {"nom": cible.name_key}])
	# La dépouille (Nourriture : la viande crue des animaux, en attendant les viandes paramétriques).
	var def_c: Dictionary = GameData.catalogues.creatures.get(str(cible.def), {})
	var stats_c: Dictionary = def_c.get("corps", {}).get("stats", {})
	var top_stat := ""
	for st in stats_c.keys():
		if top_stat.is_empty() or int(stats_c[st]) > int(stats_c[top_stat]):
			top_stat = str(st)
	var al: Dictionary = regles.r.alchimie
	for base in def_c.get("depouille", []):
		var v := generer_objet(str(base), profondeur, {"creature": cible.name_key}, "commun", 0)
		if not v.is_empty():
			if not top_stat.is_empty():   # viande paramétrique (Cuisine et alchimie) : la stat dominante de la bête
				v["potentiel"] = {top_stat: 1}
				v["wuxing"] = def_c.elements.duplicate() if def_c.get("elements") is Dictionary else regles.r.craft.harmonie.viande_defaut.duplicate()
				v["puissance"] = _puissance_de(int(stats_c[top_stat]))
				v["nom"] = {"params": {"creature": cible.name_key}}
			uids.append(v.uid)
	# Une partie de bête pour l'alchimie (Cuisine et alchimie) : œil, peau, griffe, dent ou os.
	if str(regles.r.alchimie.tag_bete) in cible.get("tags", []):
		var parties: Array = regles.r.alchimie.parties.keys()
		parties.sort()
		var rp := RandomNumberGenerator.new()
		rp.seed = hash([graine, "partie", cible.id])
		var pid: String = str(parties[rp.randi() % parties.size()])
		var partie := generer_objet(pid, profondeur, {"creature": cible.name_key}, "commun", 0)
		if not partie.is_empty():
			partie["puissance"] = _puissance_de(int(stats_c.get(str(al.parties[pid]), 10)))
			partie["nom"] = {"params": {"creature": cible.name_key}}
			uids.append(partie.uid)
		if GameData.catalogues.materials.has(pid):   # la même partie comme matériau brut (l'os des pointes — Catalogue matériaux — Paramétriques)
			var brut := generer_objet("materiau_brut", profondeur, {"creature": cible.name_key}, "commun", 0)
			if not brut.is_empty():
				var mat_id := pid
				if GameData.catalogues.materials.has(pid + "_massif") and partie.get("puissance", 1.0) >= 2.0:
					mat_id = pid + "_massif"
				brut.materiau = mat_id
				brut["forme"] = "brut"
				brut.quantite = 1
				uids.append(brut.uid)
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
	if e.horloge == "monde" or not combats.has(e.horloge):   # un combat disparu (sauvegarde, changement de grille) : l'horloge du monde
		if e.horloge != "monde":
			e.horloge = "monde"
			e.action_en_cours = {}
		return horloge_monde
	return combats[e.horloge].horloge


func en_combat(e: Dictionary) -> bool:
	if e.horloge == "monde":
		return false
	if not combats.has(e.horloge):   # un combat disparu (rechargement, grille changée) : l'être est de fait sur le monde
		e.horloge = "monde"
		e.action_en_cours = {}
		return false
	return true


# ---------------------------------------------------------------- avancement

## Fait agir la prochaine entité de l'horloge `nom`. Retourne false si l'horloge est bloquée
## sur une entité contrôlée qui attend une intention (réfléchir est gratuit).
func pas(nom: String) -> bool:
	var h: Horloge = horloge_monde if nom == "monde" else combats[nom].horloge
	var e := _prochaine(nom)
	# Les bombes de cette horloge dues avant l'entité suivante explosent d'abord (Explosions).
	var prochaine_bombe := _prochaine_bombe(nom)
	var bombe_due := false
	if not prochaine_bombe.is_empty():
		bombe_due = (e.is_empty() or int(prochaine_bombe.fin) <= int(e.compteur)) if h.mode == Horloge.Mode.ACTION else int(prochaine_bombe.fin) <= h.ticks
	if bombe_due:
		if h.mode == Horloge.Mode.ACTION:
			h.sauter_a(int(prochaine_bombe.fin))
		bombes.erase(prochaine_bombe)
		_exploser(prochaine_bombe)
		return true
	if e.is_empty():
		return false
	if h.mode == Horloge.Mode.ACTION:
		h.sauter_a(e.compteur)
	elif e.compteur > h.ticks:
		return false
	_regenerer(e, h.ticks)
	if not e.action_en_cours.is_empty():
		# Résolution simultanée (Boucle de tick, 2026-08-30) : toutes les actions engagées dues à ce tick partent
		# ensemble — détachées d'un coup, puis résolues comme si elles frappaient au même instant.
		var lot: Array[Dictionary] = []
		for id in ordre:
			var x: Dictionary = entites[id]
			if x.vivant and x.horloge == nom and int(x.compteur) == int(e.compteur) and not x.action_en_cours.is_empty():
				lot.append({"e": x, "a": x.action_en_cours})
				x.action_en_cours = {}
				lot_simultane.append(x.id)
		for entree in lot:
			_resoudre_action_engagee(entree.e, entree.a)
		lot_simultane.clear()
		_fin_de_pas(nom)
		return true
	if e.controle == "joueur":
		attente[e.id] = true
		return false
	if e.has("saisi_par") and _ia_se_debattre(e, h.ticks):
		_fin_de_pas(nom)
		return true
	_decider_ia(e, h.ticks)
	_fin_de_pas(nom)
	return true


func _prochaine_bombe(nom: String) -> Dictionary:
	var meilleure := {}
	for b in bombes:
		if str(b.horloge) == nom and (meilleure.is_empty() or int(b.fin) < int(meilleure.fin)):
			meilleure = b
	return meilleure


## Lancer une bombe du sac sur une tuile (Explosions) : portée, ligne de vue ; elle attend sur l'horloge du lanceur.
func _lancer(e: Dictionary, uid: String, cible: Vector2i, tick: int) -> bool:
	var it: Dictionary = items.get(uid, {})
	if it.is_empty() or not (uid in e.sac) or not it.has("bombe") or not grille.dans(cible):
		return false
	var bc: Dictionary = regles.r.bombes
	if Grille.distance(e.pos, cible) > int(bc.portee) or not grille.ligne_de_vue(e.pos, cible):
		EventBus.emettre(&"journal", [&"journal.bombe_refusee", {}])
		return false
	var b: Dictionary = it.bombe
	_consommer_pile(e, it)
	bombes.append({"pos": cible, "fin": tick + int(b.retard_ticks), "horloge": str(e.horloge), "puissance": float(b.puissance), "rayon": int(b.rayon), "degats": str(b.degats), "source": e.id})
	_quitter_garde(e)
	e.compteur = tick + int(regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.bombe_lancee", {"nom": e.name_key, "retard": int(b.retard_ticks)}])
	return true


## L'explosion : les tuiles détruites si durete < P × (1 − d/R), 50 % de matériau brut ; dégâts × (1 − d/R) à tout être.
func _exploser(b: Dictionary) -> void:
	var bc: Dictionary = regles.r.bombes
	var pos: Vector2i = b.pos
	var R: int = int(b.rayon)
	var P: float = float(b.puissance)
	var rng_feu := RandomNumberGenerator.new()   # Explosions : les tuiles du rayon prennent feu selon leur flammabilité
	rng_feu.seed = hash([graine, "explosion_feu", pos])
	for fy in range(-R, R + 1):
		for fx in range(-R, R + 1):
			var ft := pos + Vector2i(fx, fy)
			if Grille.distance(pos, ft) <= R and grille.dans(ft) and rng_feu.randf() < float(flammabilite_de(ft)) / 100.0:
				_enflammer(ft)
	var tuiles := 0
	var etres := 0
	for dy in range(-R, R + 1):
		for dx in range(-R, R + 1):
			var t := pos + Vector2i(dx, dy)
			if not grille.dans(t):
				continue
			var d := Grille.distance(pos, t)
			var f := 1.0 - float(d) / float(R)
			if f <= 0.0:
				continue
			var contenu := grille.contenu_de(t)
			if "destructible" in contenu.get("tags", []):
				var mat_id := grille.materiau_de(t)
				var mat: Dictionary = GameData.catalogues.materials.get(mat_id, {})
				var durete := float(mat.get("stats", {}).get("durete", bc.durete_defaut))
				if durete < P * f:
					grille.contenu[grille.idx(t)] = 0
					grille.materiaux.erase(grille.idx(t))
					grille.marquer(t)
					tuiles += 1
					if not mat.is_empty() and des.reel() < float(bc.chance_drop):
						var brut := generer_objet("materiau_brut", 1, {}, "commun", 0)
						if not brut.is_empty():
							brut.materiau = mat_id
							brut["forme"] = "brut"
							brut.quantite = 1
							_poser_contenant(t, [brut.uid], "butin")
					EventBus.emettre(&"tile_changed", [t])
			var occ := grille.occupant(t)
			if not occ.is_empty() and entites.has(occ) and bool(entites[occ].vivant):
				var deg := maxi(1, roundi(float(des.jet(str(b.degats))) * f))
				EventBus.emettre(&"journal", [&"journal.explosion_degats", {"degats": deg, "nom": entites[occ].name_key}])
				_appliquer_degats(entites[occ], deg, str(b.source), {"type": "explosion", "element": {"feu": 1.0}, "explosion": true})
				etres += 1
	EventBus.emettre(&"journal", [&"journal.explosion", {"tuiles": tuiles, "etres": etres}])
	EventBus.emettre(&"explosion", [pos, R, str(b.source)])
	# Chaîne d'amorces (La Mèche) : les bombes en attente dans le rayon explosent aussitôt.
	var lanceur: Dictionary = entites.get(str(b.source), {})
	if not lanceur.is_empty() and a_talent(lanceur, "chaine_d_amorces"):
		var voisines: Array = []
		for autre in bombes:
			if Grille.distance(pos, autre.pos) <= R:
				voisines.append(autre)
		voisines.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return Grille.distance(pos, x.pos) < Grille.distance(pos, y.pos))
		for autre in voisines:
			if autre in bombes:
				bombes.erase(autre)
				EventBus.emettre(&"journal", [&"journal.amorce", {}])
				_exploser(autre)
	for x in vivants():
		if x.controle == "joueur":
			x["vue_sale"] = true


## L'entité vivante de cette horloge au plus petit compteur (ordre d'ajout en cas d'égalité).
## Mode action : quelque chose est-il dû à l'instant présent de l'horloge du monde (être ou bombe) ?
func _du_sur_monde() -> bool:
	var e := _prochaine("monde")
	if not e.is_empty() and int(e.compteur) <= horloge_monde.ticks:
		return true
	var b := _prochaine_bombe("monde")
	return not b.is_empty() and int(b.fin) <= horloge_monde.ticks


func _prochaine(nom: String) -> Dictionary:
	var meilleure := {}
	for id in ordre:
		var e: Dictionary = entites[id]
		if e.vivant and e.horloge == nom and (meilleure.is_empty() or e.compteur < meilleure.compteur):
			meilleure = e
	return meilleure


var _dans_avancee_monde := false
func _sur_avancee_monde(_de: int, _a: int) -> void:
	# Tout ce qui est dû agit, dans l'ordre des compteurs. En mode action (donjon), l'horloge saute d'elle-même
	# dans pas() — ici on ne résout que ce qui est déjà dû (un avancer() externe : tests, voyage), sans réentrer.
	if not _dans_avancee_monde:
		_dans_avancee_monde = true
		var garde_fou := 64
		while garde_fou > 0 and (horloge_monde.mode == Horloge.Mode.TEMPS_REEL or _du_sur_monde()) and pas("monde"):
			garde_fou -= 1
		_dans_avancee_monde = false
	_tiquer_faim(horloge_monde.ticks)
	_tiquer_monde(horloge_monde.ticks)
	_tiquer_territoire(horloge_monde.ticks)
	_tiquer_raid(horloge_monde.ticks)
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
		n = mini(n, int(fa.budget) - betes.size())   # la meute ne dépasse jamais le budget de faune
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
		_semaine_royaumes_pnj()
		_semaine_elevage()
		for x in entites.values():
			if x.controle == "joueur":
				_semaine_territoire(x)
		_regenerer_terrain_sauvage()
		for x in entites.values():   # les bourses des PNJ se rechargent (+15 % par semaine, Barèmes économiques)
			if x.has("or_max"):
				x.or = mini(int(x.or_max), int(x.or) + int(ceil(float(x.or_max) * float(regles.r.commerce.recharge_hebdo))))
			# … et le marchand se réapprovisionne : un stock vidé par le joueur revient la semaine suivante.
			if not str(x.get("boutique", "")).is_empty() and x.get("stock", []).is_empty():
				_garnir_stock(x, GameData.entree("shop_types", str(x.boutique)).selection)
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
		var periode := int(float(f.ticks_par_point) / (float(e.get("faim_vitesse", 1.0)) * float(e.get("mecaniques", {}).get("faim_vitesse", {}).get("mult", 100)) / 100.0))
		var points := tick / periode - int(e.faim_tick) / periode
		if points > 0:
			var avant := int(e.faim)
			e.faim = maxi(0, int(e.faim) - points)
			if avant >= int(f.get("tooltip_seuil", 60)) and int(e.faim) < int(f.get("tooltip_seuil", 60)):
				EventBus.emettre(&"journal", [&"journal.faim_conseil", {"nom": e.name_key}])   # Faim : le conseil arrive avant le malus
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
	var cap := regles.capacite_poids(e.stats_eff) + float(e.get("mecaniques", {}).get("capacite_poids", {}).get("n", 0))
	if a_talent(e, "sans_chair"):   # le Spectre : capacité fixe
		cap = float(regles.r.talents.sans_chair.capacite_poids)
	return {"poids": total, "capacite": cap, "facteur": regles.facteur_surcharge(total, cap)}


## L'eau refuse un être en surcharge (Eau et liquides) : le pathfinding doit le savoir,
## sinon l'A* propose des pas que _deplacer refusera — l'être piétine au bord de l'eau.
func refuse_nage(e: Dictionary) -> bool:
	return bool(regles.r.nage.get("refus_surcharge", true)) and not Etres.est_volant(e) and poids_de(e).facteur > 1.0


## Manger un consommable du sac (Nourriture) : nutrition, soin, mana, statut, risque, potentiel du plat.
func _manger(e: Dictionary, uid: String, tick: int) -> bool:
	var it: Dictionary = items.get(uid, {})
	if not (uid in e.sac) or it.get("type", "") != "consommable":
		EventBus.emettre(&"journal", [&"journal.pas_comestible", {}])
		return false
	if not e.has("faim"):
		e["faim"] = 100
		e["faim_tick"] = tick
	if a_talent(e, "soif_de_sang") and "plat" in it.get("tags", []):   # le Vampire ne mange plus de plats
		EventBus.emettre(&"journal", [&"journal.plat_refuse", {}])
		return false
	var cru := bool(it.get("cru", false))
	var nutrition := float(it.get("nutrition", 0)) * (float(regles.r.cru_facteur) if cru else 1.0) * float(it.get("harmonie", 1.0))
	var extra: Array[String] = []
	if float(it.get("harmonie", 1.0)) > 1.0:
		EventBus.emettre(&"journal", [&"journal.harmonie", {}])
	var avant := int(e.faim)
	e.faim = mini(100, int(e.faim) + roundi(nutrition))
	if avant < int(regles.r.faim.seuil_stats) and int(e.faim) >= int(regles.r.faim.seuil_stats):
		Etres.recalculer(e, items, affixes_defs, regles)
	if not str(it.get("soin_des", "")).is_empty() and not a_talent(e, "sans_chair"):   # le Spectre ne se soigne que par mana
		var soin := des.jet(str(it.soin_des))
		e["sang"] = 0
		e.sante = mini(e.sante_max, int(e.sante) + soin)
		extra.append("+%d PV" % soin)
	if int(it.get("mana", 0)) > 0:
		e.mana = mini(e.mana_max, int(e.mana) + int(it.mana))
		extra.append("+%d mana" % int(it.mana))
	var statut := str(it.get("statut", ""))
	if "illegal" in statuts_defs.get(statut, {}).get("tags", []) and lieu == "camp":   # poison de lame : l'usage est une infraction là où c'est illégal
		_infraction(e, "objet", str(it.get("base", "")), e.pos, uid)
	if statut.begins_with("purge:"):
		var cible := statut.trim_prefix("purge:")
		e.statuts = e.statuts.filter(func(s: Dictionary) -> bool: return str(s.id) != cible)
		EventBus.emettre(&"journal", [&"journal.purge", {"nom": e.name_key, "statut": "status.%s.name" % cible}])
	elif statut == "huile_feu":
		e["huile_feu"] = true
		EventBus.emettre(&"journal", [&"journal.huile", {"nom": e.name_key}])
	elif not statut.is_empty():
		appliquer_statut(e, statut, int(float(it.get("statut_ticks", 0)) * float(it.get("qualite", 1.0))), e.id, float(it.get("puissance", 1.0)))
		if "potion" in it.get("tags", []) and a_talent(e, "fiole_vive"):   # Fiole vive (Talents de classe) : les alliés adjacents aussi
			var n_all := 0
			for x in vivants():
				if x.id != e.id and x.camp == e.camp and Grille.distance(e.pos, x.pos) <= 1:
					appliquer_statut(x, statut, int(float(it.get("statut_ticks", 0)) * float(it.get("qualite", 1.0))), e.id, float(it.get("puissance", 1.0)))
					n_all += 1
			if n_all > 0:
				EventBus.emettre(&"journal", [&"journal.fiole_vive", {"nom": e.name_key, "n": n_all}])
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
		if a_talent(e, "oeil_de_la_pierre"):
			portee = maxi(1, roundi(float(portee) * float(regles.r.talents.oeil_de_la_pierre.vision_mult)))
		if lieu == "camp" and monde != null:
			var facteur := 1.0
			if est_nuit() and not ("vision_nocturne" in e.get("tags_acquis", [])):
				facteur *= maxf(float(_cycle().get("vision_nuit", 0.6)), float(lumiere_de(e)) / 100.0)   # la nuit : malus de vision, sauf une lumière en main (Éclairage)
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
					_progresser_quetes(e, "explorer", [])
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
		else:
			_oublier_glyphe(gl.pos)   # expiré : la marque au sol s'efface
	glyphes = g_restants
	_tiquer_zones(tick)
	for x in vivants():   # les relevés du Fossoyeur retournent à la terre
		if x.has("fin_invocation") and x.horloge == nom and int(x.fin_invocation) <= tick:
			x.vivant = false
			grille.liberer(x.pos)
			EventBus.emettre(&"journal", [&"journal.releve_fin", {"nom": x.name_key}])
	_tirs_d_affuts(nom, tick)
	_maj_etats_meteo()
	if nom == "monde":
		if tick >= eau_prochain_pas:
			_tiquer_courant(tick)
		_tiquer_eau(tick)
		_tiquer_lave(tick)
		_tiquer_feux(tick)
		var h_ticks := int(_cycle().get("ticks_par_jour", 24000)) / 24
		if lieu == "camp" and monde != null:
			var met := meteo(monde.cellule_de(grille.pos_de(grille.largeur * grille.hauteur_grille / 2)))
			if tick / h_ticks != pluie_heure and met in ["pluie", "orage"]:   # l'orage arrose aussi
				pluie_heure = tick / h_ticks
				_pluie(tick)
			if tick / h_ticks != foudre_heure and met == "orage":   # Météo : la foudre réelle
				foudre_heure = tick / h_ticks
				_foudre(tick)
			if tick / h_ticks != evapo_heure and "evapore" in GameData.catalogues.weather_states.get(met, {}).get("effects", []):
				evapo_heure = tick / h_ticks
				_evaporation()
			if tick / h_ticks != canicule_heure and "ignition" in GameData.catalogues.weather_states.get(met, {}).get("effects", []):
				canicule_heure = tick / h_ticks
				_ignition_canicule(tick)
			if tick / h_ticks != arrachage_heure and "arrache_fragiles" in GameData.catalogues.weather_states.get(met, {}).get("effects", []):
				arrachage_heure = tick / h_ticks
				_arrachage(tick)
	_tiquer_vampires(nom, tick)
	_tiquer_armes_fantomes(nom, tick)
	_tiquer_souffle(nom, tick)
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
		_oublier_glyphe(pos)
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
				e.mana = mini(e.mana_max, e.mana + roundi((float(regles.r.mana.regen_base) + float(e.competences_eff.get("meditation", 0)) * float(regles.r.mana.regen_par_meditation)) * (float(regles.r.talents.chair_de_mana.mana_regen_mult) if a_talent(e, "chair_de_mana") else 1.0)))
				gagner_xp(e, "meditation", 1)
		var f_faim: Dictionary = regles.r.faim
		var faim_e := int(e.get("faim", 100))
		if e.get("mecaniques", {}).has("regen_sante") and not en_combat(e) and faim_e >= int(f_faim.seuil_stats):   # Effets d'équipement : 1 PV toutes les 200 × 100 / pct ticks ; Faim : plus de régén sous seuil_stats
			var pct_regen := float(e.mecaniques.regen_sante.get("pct", 50))
			if faim_e < int(f_faim.seuil_regen):
				pct_regen *= float(f_faim.get("malus_regen", 0.9))   # Faim < 50 : −10 % de régénération
			var per := maxi(1, roundi(float(regles.r.effets_equipement.regen_base_ticks) * 100.0 / pct_regen))
			var pv := tick / per - int(e.tick_endurance) / per
			if pv > 0:
				e.sante = mini(e.sante_max, int(e.sante) + pv)
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
	if Etres.a_statut_tag(e, "confusion", statuts_defs) and str(i.get("type", "")) in ["deplacer", "attaquer", "capacite"] and des.reel() < float(regles.r.get("statuts", {}).get("confusion_chance", 0.3)):
		var libres: Array[Vector2i] = []   # Confusion : un pas au hasard remplace l'intention
		for dd in Grille.DIRS:
			var q: Vector2i = e.pos + dd
			if grille.dans(q) and not grille.bloque_passage(q) and grille.occupant(q).is_empty() and grille.cout_pas(e.pos, q) >= 0:
				libres.append(q)
		if not libres.is_empty():
			EventBus.emettre(&"journal", [&"journal.confusion", {"nom": e.name_key}])
			i = {"type": "deplacer", "vers": libres[des.entier(0, libres.size() - 1)]}
	var ok := false
	match str(i.get("type", "")):
		"deplacer":
			ok = _deplacer(e, i.vers, h.ticks)
		"attaquer":
			if entites.has(i.cible):
				ok = _attaquer_bete(e, entites[i.cible], h.ticks) if (bool(e.get("forme_bestiale", false)) or (Etres.arme(e, items).is_empty() and not e.get("actions", []).is_empty())) else _attaquer_arme(e, entites[i.cible], bool(i.get("lourde", false)), h.ticks)
		"transformer":
			ok = _transformer(e, h.ticks)
		"incarner":
			ok = _incarner(e, str(i.get("pnj", "")), h.ticks)
		"arme_fantome":
			ok = _invoquer_arme_fantome(e, str(i.get("element", "")), h.ticks)
		"segment_prefere":   # 0 tick : un réglage, pas un acte
			var el := str(i.get("element", ""))
			if el.is_empty():
				e.erase("segment_prefere")
			else:
				e["segment_prefere"] = el
			ok = true
		"garde":
			ok = _prendre_garde(e, h.ticks)
		"attendre":
			ok = _attendre(e, h.ticks)
		"changer_arme":
			ok = _changer_arme(e, str(i.get("item", "")), h.ticks)
		"capacite":
			if bool(e.get("forme_bestiale", false)):
				EventBus.emettre(&"journal", [&"journal.bete_refus", {}])
			else:
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
		"cueillir":
			ok = _cueillir(e, i.get("vers", Vector2i(-1, -1)), h.ticks)
		"terrasser":
			ok = _terrasser(e, i.get("vers", Vector2i(-1, -1)), int(i.get("sens", -1)), h.ticks)
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
		"porte":   # ouvrir / fermer une porte adjacente
			ok = _basculer_porte(e, i.get("vers", Vector2i(-1, -1)), h.ticks)
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
			if str(e.corps.get("silhouette", "humanoide")) != "humanoide":
				EventBus.emettre(&"journal", [&"journal.monde_muet", {}])
			elif bool(e.get("forme_bestiale", false)):
				EventBus.emettre(&"journal", [&"journal.bete_refus", {}])
			else:
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
		"conquerir":
			ok = _conquerir(e, i.get("vers", e.pos), h.ticks)
		"capturer":
			ok = _capturer(e, h.ticks)
		"entrainer":
			ok = _entrainer(e, str(i.get("pnj", "")), str(i.get("competence", "")), h.ticks)
		"apprendre_talent":
			ok = _apprendre_talent(e, str(i.get("pnj", "")), h.ticks)
		"reforger":
			ok = _reforger(e, str(i.get("objet", "")), str(i.get("composant", "")), h.ticks)
		"lancer":
			ok = _lancer(e, str(i.get("objet", "")), i.get("cible", e.pos), h.ticks)
		"statut_habitat":
			ok = _statut_habitat(e, str(i.get("pnj", "")), str(i.get("statut", "normal")), h.ticks)
		"saisir":
			ok = _saisir(e, str(i.get("cible", "")), h.ticks)
		"poser_portail":
			ok = _poser_portail(e, i.get("cible", e.pos), h.ticks)
		"boire_source":
			ok = _rituel_race(e, i.get("vers", Vector2i(-1, -1)), "source_maudite", h.ticks)
		"rituel":
			ok = _rituel_race(e, i.get("vers", Vector2i(-1, -1)), "autel_rituel", h.ticks)
		"traverser":
			ok = _traverser(e, h.ticks)
		"masque":
			ok = _porter_masque(e, str(i.get("masque", "")), h.ticks)
		"relever":
			ok = _relever(e, str(i.get("cible", "")), h.ticks)
		"mordre":
			ok = _mordre(e, str(i.get("cible", "")), h.ticks)
		"traverser_mur":
			ok = _traverser_mur(e, i.get("cible", e.pos), h.ticks)
		"affut":
			ok = _deployer_affut(e, i.get("cible", e.pos), h.ticks)
		"declencher_glyphe":
			ok = _declencher_glyphe_distance(e, i.get("cible", e.pos), h.ticks)
		"tempo":
			ok = _voler_tempo(e, str(i.get("cible", "")), h.ticks)
		"lancer_etre":
			ok = _lancer_etre(e, i.get("vers", e.pos), h.ticks)
		"livrer":
			ok = _livrer_commande(e, str(i.get("pnj", "")), h.ticks)
		"planter":
			ok = _planter(e, str(i.get("base", "")), h.ticks)
		"fertiliser":
			ok = _fertiliser(e, i.get("vers", e.pos), h.ticks)
		"apprivoiser":
			ok = _apprivoiser(e, str(i.get("cible", "")), h.ticks)
		"ressusciter":
			ok = _ressusciter(e, str(i.get("ame", "")), h.ticks, str(i.get("pnj", "")))
		"rendre_quete":
			ok = _rendre_quete(e, str(i.get("pnj", "")), str(i.get("quete", "")), h.ticks)
		"jeter":
			ok = _jeter(e, str(i.get("objet", "")), h.ticks)
	if ok:
		attente.erase(id)
		_fin_de_pas(e.horloge)
	return ok


# ---------------------------------------------------------------- actions

## Les affixes qui allègent un pas (Loot) : « nocturne », la nuit, −pct % par pièce, jamais sous 1 tick.
func cout_pas_affixes(e: Dictionary, cout: int) -> int:
	if not est_nuit():
		return cout
	var c := float(cout)
	for ax in Etres.affixes_equipes(e, items, affixes_defs, "cond_nuit_vitesse"):
		c *= 1.0 - float(ax.params.get("pct", 0)) / 100.0
	return maxi(1, roundi(c))


## La densité de mana au point d'un être (Loot : « des sources ») : la couche `mana` de la surface, rien en donjon.
func densite_mana(pos: Vector2i) -> float:
	if monde == null or lieu != "camp":
		return 0.0
	return float(monde.surface.valeur("mana", pos.x, pos.y))


## La corruption effective là où se tient un être : la cellule (dérive comprise) au camp, celle du donjon en bas.
func corruption_ici(pos: Vector2i) -> float:
	if lieu != "camp":
		return float(donjon.get("corruption", 0))
	if monde == null:
		return 0.0
	return monde.corruption_de(_cell_de(pos))


## Déplacement d'une tuile (8 directions). Une chute volontaire (Δ ≤ −3) est autorisée : dégâts.
func _deplacer(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if Grille.distance(e.pos, vers) != 1 or not grille.occupant(vers).is_empty():
		return false
	if "fermee" in grille.contenu_de(vers).get("tags", []):   # une porte fermée : ce pas l'ouvre, le suivant passe
		return _basculer_porte(e, vers, tick)
	var volant := Etres.est_volant(e)
	var cout := grille.cout_pas(e.pos, vers, volant)
	var chute := 0
	if cout < 0:
		if not volant and grille.est_chute(e.pos, vers):
			chute = grille.h(e.pos) - grille.h(vers)
			cout = int(regles.r.deplacement.descente)
		else:
			return false
	cout = cout_pas_affixes(e, cout)
	if Etres.bloque_statuts(e, "deplacement", statuts_defs):
		return false
	if dans_l_eau(vers) and not dans_l_eau(e.pos) and bool(regles.r.nage.get("refus_surcharge", true)) and poids_de(e).facteur > 1.0 and not volant:
		EventBus.emettre(&"journal", [&"journal.coule", {}])   # le poids tire vers le fond : on refuse d'entrer
		return false
	_quitter_garde(e)
	grille.liberer(e.pos)
	e.orientation = vers - e.pos
	e.pos = vers
	grille.placer(e.id, vers)
	var ticks_dep := regles.ticks_deplacement(cout, e.competences_eff, en_combat(e))
	if e.controle == "joueur":   # surcharge (Armures et poids porté) : sur les ticks d'Athlétisme, jamais sur une stat
		ticks_dep = ceili(float(ticks_dep) * poids_de(e).facteur)
	if e.get("mecaniques", {}).has("vitesse_deplacement"):   # Effets d'équipement : +pct % de vitesse
		ticks_dep = maxi(1, roundi(float(ticks_dep) / (1.0 + float(e.mecaniques.vitesse_deplacement.get("pct", 0)) / 100.0)))
	e.compteur = tick + _ticks_avec_statuts(e, ticks_dep)
	if Etres.a_statut_id(e, "brulure"):   # l'eau éteint la Brûlure (Statuts) : l'eau ne se traverse pas, s'y plonger = y arriver au bord
		for dd in Grille.DIRS:
			var q: Vector2i = vers + dd
			if grille.dans(q) and "liquide" in grille.contenu_de(q).get("tags", []):
				_retirer_statut(e, "brulure")
				EventBus.emettre(&"journal", [&"journal.brulure_eteinte", {}])
				break
	_declencher_glyphe(e, vers)
	_zones_a_l_entree(e, vers, tick)   # Racine, Sol vif, Nappe
	if en_combat(e):
		for autre in vivants():
			if autre.camp != e.camp and Grille.distance(autre.pos, e.pos) == 1:
				gagner_xp(e, "esquive", 1)   # la mobilité s'apprend sous le feu (Décision — Esquive active)
				_declencher(e, "derobade", e.pos)   # Dérobade : « quand le porteur esquive » = un pas sous la menace
				break
	e["immobile_depuis"] = e.compteur   # Canalisation : l'immobilité repart de zéro à chaque pas
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
	if a_talent(e, "masques"):   # Le Masque : la main secondaire est prise
		EventBus.emettre(&"journal", [&"journal.garde_masque", {}])
		return false
	if not str(e.get("porte", "")).is_empty():   # on porte quelqu'un : pas de garde
		EventBus.emettre(&"journal", [&"journal.garde_porte", {}])
		return false
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
	var cout := int(regles.r.actions.changer_arme)
	if a_talent(e, "ratelier_vivant") and not bool(e.get("swap_gratuit_pris", false)):   # Râtelier vivant (Talents de classe)
		cout = 0
		e["swap_gratuit_pris"] = true
		EventBus.emettre(&"journal", [&"journal.swap_gratuit", {"nom": e.name_key}])
	e.compteur = tick + cout
	EventBus.emettre(&"journal", [&"journal.changer_arme", {"nom": e.name_key, "objet": item.name_key, "ticks": cout}])
	return true


## Attaque à l'arme équipée. Une lourde est télégraphée : engagée maintenant, résolue à l'échéance.
func _attaquer_arme(e: Dictionary, cible: Dictionary, lourde: bool, tick: int) -> bool:
	var arme := Etres.arme(e, items)
	if arme.is_empty() or not cible.vivant:
		return false
	if not str(e.get("porte", "")).is_empty():   # Le Porteur : il porte quelqu'un
		EventBus.emettre(&"journal", [&"journal.porte", {}])
		return false
	var fonct: Dictionary = fonctionnalites.get(arme.functionality, {})
	if not _cible_atteignable(e, cible, _portee_effective(e, arme, fonct), true):
		return false
	if est_projectile(fonct):
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


## Projectile (Décision — Projectiles) : munitions et trajectoire — l'arc, pas la lance.
## La zone morte au contact (portee_min > 1) est commune ; le carquois ne l'est pas.
func est_projectile(fonct: Dictionary) -> bool:
	return bool(fonct.get("projectile", false))


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
	if fonct.is_empty() or not est_projectile(fonct):
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
	if est_projectile(fonct):
		e.munitions -= 1
		e.munitions_tirees += 1
	# Affixes de l'arme (Loot — affixes) : vecteur, dés, armure ignorée, multiplicateurs — avant le jet.
	var ax := _affixes_offensifs(e, arme, cible)
	e["riposte_des"] = 0   # les bonus armés (riposte à cadence, combo) sont dépensés par ce coup — raté compris, la fenêtre passe
	e["combo_des"] = 0
	var vecteur: Dictionary = ax.vecteur
	# Le jet de coup (Pipeline de résolution du combat) : critique ≥ crit_range, raté ≤ fumble_max ; Le Rieur élargit les deux queues.
	var jet_coup := des.jet("1d20")
	var crit_seuil := int(fonct.get("crit_range", 20)) - (int(regles.r.talents.deux_queues.crit_bonus) if a_talent(e, "deux_queues") else 0)
	var fumble := int(regles.r.degats.get("fumble_max", 1)) + (int(regles.r.talents.deux_queues.fumble_bonus) if a_talent(e, "deux_queues") else 0)
	if jet_coup <= fumble and a_talent(e, "deux_queues") and not bool(e.get("relance_utilisee", false)):
		e["relance_utilisee"] = true
		jet_coup = des.jet("1d20")
		EventBus.emettre(&"journal", [&"journal.relance", {"att": e.name_key}])
	var mult_coup := 1.0
	if jet_coup <= fumble:
		e["coups_rates"] = int(e.get("coups_rates", 0)) + 1
		EventBus.emettre(&"journal", [&"journal.rate", {"att": e.name_key}])
		EventBus.emettre(&"coup_rate", [e.id])
		return
	if jet_coup >= crit_seuil:
		mult_coup = float(regles.r.degats.get("crit_mult", 1.5))
		e["coups_critiques"] = int(e.get("coups_critiques", 0)) + 1
		EventBus.emettre(&"journal", [&"journal.critique", {"att": e.name_key, "mult": "%.1f" % mult_coup}])
		EventBus.emettre(&"coup_critique", [e.id, cible.id, mult_coup])
	if bool(arme.get("fantome", false)):   # Armes fantomatiques : pures, mais ×0,7
		mult_coup *= float(regles.r.armes_fantomes.degats_mult)
	if a_talent(e, "jauge_de_sang"):   # L'Écarlate : jusqu'à ×1,8 la jauge pleine
		mult_coup *= 1.0 + (float(regles.r.talents.jauge_de_sang.mult_max) - 1.0) * float(e.get("sang", 0)) / float(regles.r.talents.jauge_de_sang.max)
	for s0 in e.statuts:   # Poison de lame : chaque coup d'arme applique un statut à la cible
		for mod in statuts_defs.get(str(s0.id), {}).get("modifiers", []):
			if str(mod.cible) == "attaque_statut" and cible.vivant:
				appliquer_statut(cible, str(mod.statut), int(mod.get("duree", 30)), e.id)
				EventBus.emettre(&"journal", [&"journal.lame_empoisonnee", {"nom": e.name_key, "cible": cible.name_key}])
	if a_talent(e, "dissimulation"):   # L'Ombre : −25 % de face ; attaquer lève la dissimulation
		if Regles.direction_relative(cible.orientation, e.pos - cible.pos) == "front":
			mult_coup *= float(regles.r.talents.dissimulation.face_mult)
		if not bool(e.get("sans_trace", false)):   # Sans trace / Silencieux : ce coup-là ne trahit pas son auteur
			e.statuts = e.statuts.filter(func(s0: Dictionary) -> bool: return str(s0.id) != "dissimule")
	var d := regles.degats_arme(e.stats_eff, arme, fonct, des, lourde, a_zero, int(ax.des) + int(Etres.add_statuts(e, "des", statuts_defs)) - (int(regles.r.nage.des_malus) if dans_l_eau(e.pos) else 0), e.competences_eff, vecteur)   # Béni : +dés ; dans l'eau : −dés
	var wx := _facteur_wuxing(e, cible, vecteur, tick_de(e))
	var dom := wuxing.dominante(vecteur)
	var plat := int(e.get("degats_element", {}).get(dom, 0))
	for el_h in e.get("degats_element_bonus", {}).keys():   # Nourriture : l'huile d'arme, le temps d'un combat —
		plat += des.jet(str(e.degats_element_bonus[el_h]))   # ses dés s'ajoutent quel que soit l'élément de l'arme
	var res := _resoudre_coup(e, cible, (d.bruts + float(plat)) * wx.total * float(ax.mult) * mult_coup * Etres.mult_statuts(e, "degats", statuts_defs), fonct.type_degats, lourde, vecteur, float(ax.ignore_armure))
	res.merge(wx)
	res["competence"] = str(fonct.get("combat_skill", ""))
	var cle := &"journal.attaque_lourde" if lourde else &"journal.attaque"
	EventBus.emettre(&"journal", [cle, {"att": e.name_key, "def": cible.name_key, "zone": res.zone, "degats": res.degats, "ticks": ticks}])
	_appliquer_degats(cible, res.degats, e.id, res)
	_affixes_apres_coup(e, arme, cible, res)
	_poser_segment(e, vecteur, tick_de(e))
	_communion_tourner(e, arme)


## Portée de l'arme, allongée par l'affixe « +N allonge ».
func _portee_effective(e: Dictionary, arme: Dictionary, fonct: Dictionary) -> Vector2i:
	var p := regles.portee_de(fonct)
	for ax in Loot.affixes_de_type(arme, affixes_defs, "meca_allonge"):
		p.y += int(ax.params.n)
	return p


## Ce que les affixes de l'arme changent AVANT le jet : {vecteur, des, mult, ignore_armure}.
## Les compteurs rythmiques avancent ici (une attaque = un cran, jamais par cible).
func _affixes_offensifs(e: Dictionary, arme: Dictionary, cible: Dictionary) -> Dictionary:
	var r := {"vecteur": _vecteur_arme_de(e, arme), "des": 0, "mult": 1.0, "ignore_armure": 0.0, "plat": 0}
	# Bonus armés par les coups précédents (riposte à cadence, combo Wu Xing) — lus sans être consommés
	# (la prévisualisation passe ici aussi) ; _frapper_arme les vide après le coup qui les dépense.
	r.des += int(e.get("riposte_des", 0)) + int(e.get("combo_des", 0))
	# Gemmes de l'arme : la taille en affinité déplace le vecteur (AJOUT normalisé), les dégâts
	# élémentaires plats s'ajoutent si le coup porte cet élément.
	if not _vecteur_pur(r.vecteur):   # Modificateurs d'affinité : « sur une arme PURE, jamais » — la pureté reste une propriété du craft
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
			"cond_corruption":   # du danger : la corruption du lieu atteint le seuil
				if corruption_ici(e.pos) >= float(p.seuil):
					r.mult *= 1.0 + float(p.pct) / 100.0
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
	r.vecteur = _vecteur_modifie(e, r.vecteur)   # anneaux et amulettes : amplification puis transmutation
	return r


## Les modificateurs d'affinité portés par l'équipement (anneaux, amulettes) appliqués au vecteur d'un coup,
## dans l'ordre de la note : base → amplifications → ajouts → transmutations → purifications → normalisation.
func _vecteur_modifie(e: Dictionary, v: Dictionary) -> Dictionary:
	if v.is_empty():
		return v
	var res := v.duplicate()
	for ax in Etres.affixes_equipes(e, items, affixes_defs, "wuxing_amplification"):   # amplification : sans effet si absent
		var el := str(ax.params.get("element", ""))
		if res.has(el):
			res[el] = float(res[el]) * (1.0 + float(ax.params.get("pct", 0)) / 100.0)
	for ax in Etres.affixes_equipes(e, items, affixes_defs, "wuxing_transmutation"):   # remplace X par Y
		var de := str(ax.params.get("element", ""))
		var vers := str(ax.params.get("vers", ""))
		if de != vers and res.has(de) and not vers.is_empty():
			res[vers] = float(res.get(vers, 0.0)) + float(res[de])
			res.erase(de)
	var total := 0.0
	for k in res.keys():
		total += float(res[k])
	if total <= 0.0:
		return v
	for k in res.keys():
		res[k] = float(res[k]) / total
	return res


## Modificateur d'affinité AJOUT puis normalisation à somme 1 (Modificateurs d'affinité).
## Un vecteur pur : un seul élément qui porte tout (à l'arrondi près).
func _vecteur_pur(v: Dictionary) -> bool:
	var n := 0
	for k in v.keys():
		if float(v[k]) > 0.001:
			n += 1
	return n == 1


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
			"unique":   # Trésors et artefacts : effets uniques hors pools
				if str(d.effet.mecanique) == "vol_de_mana":
					e.mana = mini(e.mana_max, int(e.mana) + roundi(float(res.degats) * float(p.pct) / 100.0))
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
## Le vecteur de l'arme pour un être : Communion des cinq (Le Souffle) remplace l'élément par celui qui tourne.
func _vecteur_arme_de(e: Dictionary, arme: Dictionary) -> Dictionary:
	if a_talent(e, "communion_des_cinq") and e.has("element_communion"):
		return {str(e.element_communion): 1.0}
	for s: Dictionary in e.get("statuts", []):   # Trempe (Modules) : l'arme chauffée passe à l'élément accordé
		for mod: Dictionary in statuts_defs.get(s.id, {}).get("modifiers", []):
			if str(mod.get("cible", "")) == "element_arme" and mod.has("grant"):
				return {str(mod.grant): 1.0}
	return vecteur_arme(arme)


## Après un coup qui pose un segment : l'élément tourne dans le cycle d'engendrement, contre du mana.
func _communion_tourner(e: Dictionary, arme: Dictionary) -> void:
	if not a_talent(e, "communion_des_cinq"):
		return
	var actuel := str(e.get("element_communion", arme.get("element", "")))
	if actuel.is_empty() or not wuxing.w.engendre.has(actuel):
		return
	var cout := int(regles.r.talents.get("communion_des_cinq", {}).get("mana", 2))
	if int(e.mana) < cout:
		return
	e.mana = int(e.mana) - cout
	e["element_communion"] = str(wuxing.w.engendre[actuel])
	EventBus.emettre(&"journal", [&"journal.communion", {"nom": e.name_key, "element": "element." + str(e.element_communion)}])


func vecteur_arme(arme: Dictionary) -> Dictionary:
	var elems: Variant = arme.get("elements")
	if elems is Dictionary and not elems.is_empty():   # une arme assemblée : son vecteur complet (Compensation de l'arme mixte)
		return elems
	var el: Variant = arme.get("element")
	return {el: 1.0} if el is String and not el.is_empty() else {}


## Les éléments qu'une arme mixte peut poser en segment : ceux portés à ≥ seuil_mixte (au moins deux, sinon vide).
func segments_possibles(arme: Dictionary) -> Array[String]:
	var res: Array[String] = []
	var v := vecteur_arme(arme)
	var seuil := float(regles.r.get("chaine", {}).get("seuil_mixte", 0.25))
	for k in v.keys():
		if float(v[k]) >= seuil:
			res.append(str(k))
	if res.size() < 2:
		return []
	res.sort()
	return res


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
		if not a_unique(e, "chaine_eternelle"):   # Chaîne éternelle : la jauge ne décroît plus
			wuxing.decroitre(e.chaine, tick)
		prev = wuxing.prevoir(e.chaine, wuxing.dominante(v_att))
		gain = prev.gain
		chaine = prev.multiplicateur
	return {"dom": dom.mult, "contre": dom.contre, "gain": gain, "chaine": chaine, "prevision": prev, "total": dom.mult * gain * chaine}


## Un coup qui touche pose UN segment (Jauge de chaîne Wu Xing) — s'il résout, la barre retombe.
func _poser_segment(e: Dictionary, v_att: Dictionary, tick: int, origine: String = "arme") -> void:
	if v_att.is_empty():
		return
	if origine == "arme" and a_talent(e, "souffle_rendu"):   # Souffle rendu : les coups d'arme ne tissent pas
		return
	if e.has("maitre") and entites.has(str(e.maitre)) and a_talent(entites[str(e.maitre)], "meute"):   # Meute : la jauge du maître
		_poser_segment(entites[str(e.maitre)], v_att, tick, "meute")
		return
	if not e.has("chaine"):
		return
	var element := wuxing.dominante(v_att)
	var pref := str(e.get("segment_prefere", ""))   # l'arme mixte choisit son segment (Compensation de l'arme mixte)
	if not pref.is_empty() and float(v_att.get(pref, 0.0)) >= float(regles.r.get("chaine", {}).get("seuil_mixte", 0.25)):
		element = pref
	_declencher(e, "accord", e.derniere_cible_pos)
	var precedent := str(e.chaine.segments.back().element) if not e.chaine.segments.is_empty() else ""
	if wuxing.relation(precedent, element) == "engendre":   # un combo : la transition d'engendrement du cycle
		for ax in Etres.affixes_equipes(e, items, affixes_defs, "wuxing_combo_des"):   # très rare : le combo arme +des dés sur le coup suivant
			e["combo_des"] = int(e.get("combo_des", 0)) + int(ax.params.des)
	var p := wuxing.poser(e.chaine, element, tick)
	if p.resout:
		e.erase("swap_gratuit_pris")
		EventBus.emettre(&"journal", [&"journal.chaine_resout", {"nom": e.name_key, "mult": "%.2f" % p.multiplicateur}])
	else:
		EventBus.emettre(&"journal", [&"journal.chaine_segment", {"nom": e.name_key, "element": "element." + element,
			"position": p.position, "capacite": e.chaine.capacite, "transition": "%.2f" % p.transition}])


## Un coup contre une cible : zone par dénivelé, garde (frontale / bouclier), armure de zone.
func _resoudre_coup(att: Dictionary, cible: Dictionary, bruts: float, type_degats: String, lourde: bool, element: Variant, ignore_armure: float = 0.0) -> Dictionary:
	var zone: Dictionary = regles.zone_de_coup(grille.h(att.pos), grille.h(cible.pos))
	var piece := Etres.piece_zone(cible, zone.zone, items)
	var armure := (regles.armure_piece(piece, type_degats) + Etres.add_statuts(cible, "armure", statuts_defs)) \
		* float(Etres.mult_statuts(cible, "armure", statuts_defs))   # Rupture : −50 % de réduction de zone
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
			var cout := regles.cout_garde_impact(sans_garde, bouclier, cible.competences_eff)
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


## Menu de triche (Écrans d'interface) : tout obtenir et tout déclencher, pour juger sans farmer.
## Un seul point d'entrée côté simulation — le client n'écrit jamais l'état lui-même (Réseau).
## `action` est une catégorie, `arg` l'id choisi dans un catalogue : rien n'est écrit en dur ici.
func triche(e: Dictionary, action: String, arg: String = "") -> bool:
	match action:
		"or":
			e.or = int(e.or) + 10000
		"soin":
			e.sante = int(e.sante_max)
			e.endurance = int(e.endurance_max)
			e.mana = int(e.mana_max)
			e["faim"] = 100
			e.statuts.clear()
		"invincible":
			invincible = not invincible
		"competences":   # toutes les compétences du catalogue au niveau 50, potentiel au plafond
			for cid in GameData.catalogues.competences.keys():
				e.competences[str(cid)] = 50
				e.potentiels[str(cid)] = int(regles.r.progression.potentiel_max)
		"talents":
			if not e.has("talents_appris"):
				e["talents_appris"] = []
			for tid in GameData.catalogues.talents.keys():
				if not (str(tid) in e.talents_appris):
					e.talents_appris.append(str(tid))
		"modules":
			for mid in GameData.catalogues.modules.keys():
				crediter_module(e, str(mid), 99)   # menu de triche : de quoi tout essayer
		"recettes":
			if not e.has("recettes_connues"):
				e["recettes_connues"] = []
			for rid in GameData.catalogues.recipes.keys():
				if not (str(rid) in e.recettes_connues):
					e.recettes_connues.append(str(rid))
			for rid in GameData.catalogues.component_recipes.keys():
				if not (str(rid) in e.recettes_connues):
					e.recettes_connues.append(str(rid))
		"objet":
			var inst := generer_objet(arg, 10, {}, "exceptionnel", -1)
			if inst.is_empty():
				return false
			e.sac.append(inst.uid)
		"materiau":
			_donner_materiau(e, arg, 20, "brut")
		"creature":
			var libre := _tuile_libre_autour(e.pos)
			if libre == Vector2i(-1, -1):
				return false
			var x := ajouter(arg, libre, "ia")
			if x.is_empty():
				return false
			_habiller_pnj(x, GameData.entree("creatures", arg))
		"meteo":
			meteo_force = arg
		"heure":   # bascule jour ↔ nuit : saute à midi quand il fait nuit, à minuit quand il fait jour
			var jour := int(_cycle().ticks_par_jour)
			var cible := jour / 2 if est_nuit() else 0
			var avance := posmod(cible - posmod(horloge_monde.ticks, jour), jour)
			horloge_monde.ticks += avance if avance > 0 else jour
		"semaine":
			_tiquer_monde(horloge_monde.ticks + int(GameData.config("planete").corruption.ticks_par_semaine))
		"reveler":   # les cellules autour du joueur : de quoi voyager partout sans tout marquer (1024² cellules)
			if monde == null:
				return false
			var n := monde.taille / 32
			var centre := _cell_de(e.pos)
			for dx in range(-RAYON_REVELE, RAYON_REVELE + 1):
				for dy in range(-RAYON_REVELE, RAYON_REVELE + 1):
					var c := centre + Vector2i(dx, dy)
					if c.x >= 0 and c.y >= 0:
						monde.explores[Vector2i(c.x * n, c.y * n)] = true
		"claim":
			if monde == null:
				return false
			monde.claims[_cell_de(e.pos)] = {"role": "base"}
			EventBus.emettre(&"cell_claimed", [_cell_de(e.pos)])
		"tuer":   # tout ce qui est hostile dans la fenêtre tombe
			for x in vivants():
				if ennemis(e, x):
					_appliquer_degats(x, int(x.sante), e.id, {"type": "triche"})
		"race":
			match arg:
				"vampire": _devenir_vampire(e)
				"spectre": _devenir_spectre(e)
				"lycanthrope": _devenir_lycanthrope(e)
				_: return false
		"statut":
			appliquer_statut(e, arg, int(statuts_defs.get(arg, {}).get("duree_ticks", 300)), e.id)
		_:
			return false
	Etres.recalculer(e, items, affixes_defs, regles)
	EventBus.emettre(&"journal", [&"journal.triche", {"action": "ui.triche." + action}])
	return true


## La première tuile libre autour d'une position (menu de triche, invocations).
func _tuile_libre_autour(pos: Vector2i) -> Vector2i:
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := pos + Vector2i(dx, dy)
				if grille.dans(t) and not grille.bloque_passage(t) and grille.occupant(t).is_empty():
					return t
	return Vector2i(-1, -1)


func _appliquer_degats(cible: Dictionary, degats: int, source: String, detail: Dictionary) -> void:
	if invincible and cible.controle == "joueur":
		return   # menu de triche
	if degats > 0 and Etres.bloque_statuts(cible, "esquive_prochaine", statuts_defs):
		_retirer_statut(cible, "voile")   # Voile : le prochain coup subi est esquivé, et le voile tombe
		EventBus.emettre(&"journal", [&"journal.voile_esquive", {"nom": cible.name_key}])
		return
	var pct_reflet := 1.0 - float(Etres.mult_statuts(cible, "reflet", statuts_defs))   # Reflet : une part revient
	if degats > 0 and pct_reflet > 0.0 and not source.is_empty() and entites.has(source) and str(detail.get("type", "")) != "reflet":
		var att: Dictionary = entites[source]
		if att.vivant and att.id != cible.id:
			var renvoi := maxi(1, roundi(float(degats) * pct_reflet))
			EventBus.emettre(&"journal", [&"journal.reflet", {"nom": cible.name_key, "att": att.name_key, "degats": renvoi}])
			_appliquer_degats(att, renvoi, cible.id, {"type": "reflet", "element": {}})
	if a_talent(cible, "sans_chair") and str(detail.get("type", "")) in ["contondant", "tranchant", "perforant"]:   # le Spectre
		degats = roundi(float(degats) * float(regles.r.talents.sans_chair.physique_mult))
	if degats > 0 and Etres.bloque_statuts(cible, "ecaille", statuts_defs):   # Écaille élémentaire : l'élément choisi ne passe pas
		var el_dom := wuxing.dominante(detail.get("element", {}) if detail.get("element") is Dictionary else {})
		if not el_dom.is_empty() and el_dom == str(cible.get("ecaille_element", "")):
			EventBus.emettre(&"journal", [&"journal.ecaille", {"nom": cible.name_key, "element": "element." + el_dom}])
			return
		# … et le revers : l'élément que l'écaille DOMINE passe amplifié (vulnérabilité, un modificateur du statut)
		if not el_dom.is_empty() and str(wuxing.w.domine.get(str(cible.get("ecaille_element", "")), "")) == el_dom:
			degats = roundi(float(degats) * float(Etres.mult_statuts(cible, "vulnerabilite", statuts_defs)))
			EventBus.emettre(&"journal", [&"journal.ecaille_revers", {"nom": cible.name_key, "element": "element." + el_dom}])
	if degats > 0:   # Absorption : un matelas de PV encaisse d'abord, puis disparaît
		var matelas := int(cible.get("absorption_pv", 0))
		if matelas > 0:
			var pris := mini(matelas, degats)
			cible["absorption_pv"] = matelas - pris
			degats -= pris
			EventBus.emettre(&"journal", [&"journal.absorption", {"nom": cible.name_key, "degats": pris}])
			if int(cible.absorption_pv) <= 0:
				_retirer_statut(cible, "absorption")
			if degats <= 0:
				return
	var part_communion := 1.0 - float(Etres.mult_statuts(cible, "communion", statuts_defs))   # Communion : le lanceur partage
	if degats > 0 and part_communion > 0.0 and not str(cible.get("communion_avec", "")).is_empty():
		var garant: Dictionary = entites.get(str(cible.communion_avec), {})
		if garant.get("vivant", false) and garant.id != cible.id:
			var pris_c := roundi(float(degats) * part_communion)
			degats -= pris_c
			EventBus.emettre(&"journal", [&"journal.communion", {"nom": garant.name_key, "def": cible.name_key, "degats": pris_c}])
			_appliquer_degats(garant, pris_c, "", {"type": "communion", "element": {}})
	_verser_xp(cible, degats, source, detail)
	var avant_pct := float(cible.sante) / float(cible.sante_max)
	var reserve := int(Etres.add_statuts(cible, "reserve", statuts_defs))   # Réserve : le soin dormant
	if reserve > 0 and float(int(cible.sante) - degats) / float(cible.sante_max) < float(regles.r.get("soins", {}).get("reserve_seuil_pct", 30)) / 100.0:
		cible.sante = mini(int(cible.sante_max), int(cible.sante) + reserve)
		_retirer_statut(cible, "reserve")
		EventBus.emettre(&"journal", [&"journal.reserve", {"nom": cible.name_key, "soin": reserve}])
	cible.sante = maxi(0, cible.sante - degats)
	if float(detail.get("erosion", 0.0)) > 0.0 and degats > 0:   # Érosif : une part des dégâts rogne les PV max, pour le combat
		var rogne := maxi(1, roundi(float(degats) * float(detail.erosion)))
		cible["erosion"] = int(cible.get("erosion", 0)) + rogne
		Etres.recalculer(cible, items, affixes_defs, regles)
		EventBus.emettre(&"journal", [&"journal.erosion", {"nom": cible.name_key, "pv": rogne, "max": int(cible.sante_max)}])
	if cible.sante > 0 and not bool(cible.get("second_souffle_pris", false)) and float(cible.sante) / float(cible.sante_max) * 100.0 < float(regles.r.uniques.second_souffle_seuil_pct):
		var ax_ss := a_unique_ax(cible, "second_souffle")   # Second souffle : une fois par combat
		if not ax_ss.is_empty():
			var soin := roundi(float(cible.sante_max) * float(ax_ss.params.get("pct", 30)) / 100.0)
			cible.sante = mini(cible.sante_max, int(cible.sante) + soin)
			cible["second_souffle_pris"] = true
			EventBus.emettre(&"journal", [&"journal.second_souffle", {"nom": cible.name_key, "soin": soin}])
	if a_talent(cible, "jauge_de_sang"):   # L'Écarlate : les dégâts subis remplissent la jauge
		cible["sang"] = mini(int(regles.r.talents.jauge_de_sang.max), int(cible.get("sang", 0)) + degats)
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
		if not att.is_empty() and a_talent(att, "dissimulation"):   # L'Ombre : dissimulé après chaque mise à mort
			appliquer_statut(att, "dissimule", int(statuts_defs.get("dissimule", {}).get("duree_ticks", 24000)), att.id)
			EventBus.emettre(&"journal", [&"journal.dissimule", {"nom": att.name_key}])
		if not att.is_empty() and att.controle == "joueur" and cible.camp == "civil":
			_infraction(att, "comportement", "meurtre", cible.pos, "")
		if str(cible.get("fonction", "")) == "dirigeant" and not str(cible.get("royaume", "")).is_empty() and monde != null:
			monde.vacances[str(cible.royaume)] = monde.semaine_courante + int(_ry().succession.semaines)
			var h := heritier_de(cible)
			if not h.is_empty():
				monde.heritiers[str(cible.royaume)] = h
			EventBus.emettre(&"journal", [&"journal.vacance", {"royaume": monde.surface.royaume_de(_cell_de(cible.pos)).get("nom", cible.royaume)}])
		if str(cible.get("fonction", "")) == "maitre_de_guilde" and cible.has("guilde") and monde != null and not str(cible.get("village", "")).is_empty():
			monde.vacances_guildes["%s|%s" % [str(cible.guilde), str(cible.village)]] = monde.semaine_courante + int(_ry().succession.semaines_guilde)
			EventBus.emettre(&"journal", [&"journal.vacance_guilde", {"guilde": "guilde.%s.name" % str(cible.guilde)}])
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
			# Riposte à cadence (Loot — affixes, armure) : tous les n coups reçus, la prochaine attaque du porteur gagne +des dés.
			for ax in Etres.affixes_equipes(cible, items, affixes_defs, "cadence_riposte_des"):
				ax.instance.compteur = int(ax.instance.compteur) + 1
				if int(ax.instance.compteur) % int(ax.params.n) == 0:
					cible["riposte_des"] = int(cible.get("riposte_des", 0)) + int(ax.params.des)
	for p in vivants():
		if p.id != cible.id and p.camp == cible.camp:
			for d in p.declencheurs_armes.duplicate():
				if d.evenement == "veille" and avant_pct * 100.0 >= float(d.plan.pct_declencheur) and float(cible.sante) / float(cible.sante_max) * 100.0 < float(d.plan.pct_declencheur):
					p.declencheurs_armes.erase(d)
					_executer_capacite(p, d.plan, cible.pos, false)


## Ouvre une porte fermée, ou ferme une porte ouverte (jamais sur un être) — Génération de donjon, 2026-08-30.
func _basculer_porte(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if not grille.dans(vers) or Grille.distance(e.pos, vers) > 1:
		return false
	var tags: Array = grille.contenu_de(vers).get("tags", [])
	if not ("porte" in tags):
		return false
	if "fermee" in tags:
		grille.poser_contenu(vers, "porte")
		EventBus.emettre(&"journal", [&"journal.porte_ouverte", {"nom": e.name_key}])
	else:
		if not grille.occupant(vers).is_empty():
			return false
		grille.poser_contenu(vers, "porte_fermee")
		EventBus.emettre(&"journal", [&"journal.porte_fermee", {"nom": e.name_key}])
	grille.marquer(vers)
	lumiere_sale = true
	EventBus.emettre(&"tile_changed", [vers])
	_quitter_garde(e)
	e.compteur = tick + int(regles.r.actions.objet)
	return true


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
	EventBus.emettre(&"xp_gagnee", [e.id, cle, xp])   # l'XP s'affiche à chaque action (XP de combat, 2026-08-30)
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
func appliquer_statut(cible: Dictionary, id: String, duree: int, source: String, puissance: float = 1.0) -> bool:
	var d: Dictionary = statuts_defs.get(id, {})
	if d.is_empty() or not cible.vivant:
		return false
	if "poison" in d.get("tags", []) and "immunite_poison" in cible.get("tags_acquis", []):   # Effets d'équipement
		EventBus.emettre(&"journal", [&"journal.immunite_poison", {}])
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
	cible.statuts.append({"id": id, "fin": tick + duree, "prochain": tick + int(d.periode_ticks), "source": source, "puissance": puissance})
	match id:   # les statuts qui portent un compteur ou une cible (Modules)
		"absorption":
			cible["absorption_pv"] = int(Etres.add_statuts(cible, "absorption", statuts_defs))
		"communion":
			cible["communion_avec"] = source
		"ecaille_elementaire":
			cible["ecaille_element"] = str(cible.get("ecaille_choix", "feu"))
	if Etres.statut_touche_stats(id, statuts_defs):
		Etres.recalculer(cible, items, affixes_defs, regles)
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
		while e.vivant and d.get("soin_des") != null and int(s.prochain) <= tick and int(s.prochain) <= int(s.fin):   # Régénération
			var soin := des.jet(str(d.soin_des))
			e.sante = mini(e.sante_max, int(e.sante) + soin)
			EventBus.emettre(&"journal", [&"journal.statut_soin", {"nom": e.name_key, "statut": d.name_key, "soin": soin}])
			s.prochain = int(s.prochain) + int(d.periode_ticks)
		var libere := false
		if d.has("liberation") and int(s.prochain) <= tick:   # Gel : un jet de Force par période pour se libérer
			var lb: Dictionary = d.liberation
			s.prochain = int(s.prochain) + int(d.periode_ticks)
			if des.jet("1d20") + int(e.stats_eff.get(str(lb.stat), 0)) / 2 >= int(lb.seuil):
				libere = true
				EventBus.emettre(&"journal", [&"journal.liberation", {"nom": e.name_key, "statut": d.name_key}])
		if int(s.fin) > tick and not libere:
			restants.append(s)
		elif Etres.statut_touche_stats(str(s.id), statuts_defs):
			e.statuts = restants
			Etres.recalculer(e, items, affixes_defs, regles)
	e.statuts = restants


## Résolution d'une action engagée (télégraphée) à son échéance.
func _resoudre_action_engagee(e: Dictionary, a: Dictionary) -> void:
	EventBus.emettre(&"action_resolved", [e.id, a])
	var cible: Dictionary = entites.get(a.get("cible", ""), {})
	match str(a.type):
		"arme":
			var arme := Etres.arme(e, items)
			var fonct: Dictionary = fonctionnalites.get(arme.get("functionality", ""), {})
			var cible_du_lot: bool = not cible.is_empty() and cible.id in lot_simultane   # tuée dans le même lot : elle était vivante à l'instant du coup
			if cible.is_empty() or (not cible.vivant and not cible_du_lot) or not _cible_atteignable(e, cible, _portee_effective(e, arme, fonct), true):
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
					if not c.vivant and not (c.id in lot_simultane):   # tuée dans le même lot : frappée quand même (Boucle de tick)
						continue
					var bonus := _bonus_des_conditions(e, c, action) + _bonus_embuscade(e, c) + int(Etres.add_statuts(e, "des", statuts_defs))   # Béni
					var d := regles.degats_action(e.stats_eff, action, des, a_zero, bonus)
					var wx := _facteur_wuxing(e, c, action.elements, tick_de(e))
					var res := _resoudre_coup(e, c, d.bruts * wx.total * Etres.mult_statuts(e, "degats", statuts_defs), str(action.get("type_degats", "contondant")), false, action.elements)
					res.merge(wx)
					res["competence"] = action.id
					EventBus.emettre(&"journal", [&"journal.action_creature", {"att": e.name_key, "action": action.name_key, "def": c.name_key, "zone": res.zone, "degats": res.degats}])
					_appliquer_degats(c, res.degats, e.id, res)
					if c.vivant and a_talent(e, "lune") and bool(e.get("forme_bestiale", false)) and ("morsure" in action.tags or str(action.id).begins_with("morsure")) and "humanoide" in c.get("tags", []):
						appliquer_statut(c, "morsure_lunaire", int(statuts_defs.morsure_lunaire.duree_ticks), e.id)   # la lycanthropie se transmet
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
			"soin":   # Créatures (2026-08-30) : un soigneur — la cible est l'allié choisi par _meilleur_soutien
				for c in cibles:
					if not c.vivant:
						continue
					var avant: int = int(c.sante)
					c.sante = mini(int(c.sante_max), int(c.sante) + des.jet(str(effet.get("des", "1d4"))))
					EventBus.emettre(&"journal", [&"journal.soin", {"att": e.name_key, "capacite": action.name_key, "def": c.name_key, "soin": int(c.sante) - avant}])
				if not cibles.is_empty():
					_poser_segment(e, action.elements, tick_de(e), "soin")
			"invoquer":   # un invocateur : n créatures alliées autour de lui, plafonnées par `max`
				_invoquer_creature_ia(e, effet, action)
			_:
				pass   # bonus_premiere_attaque : passif, lu par _bonus_embuscade au moment de la frappe


## L'invocation d'une créature par une action de créature (Créatures, 2026-08-30) : comme l'Écho de chair du
## joueur — même camp, `maitre`, durée — mais plafonnée : un chaman n'a jamais plus de `max` invocations vivantes.
func _invoquer_creature_ia(e: Dictionary, effet: Dictionary, action: Dictionary) -> void:
	var tick := tick_de(e)
	var n := 0
	for _k in range(int(effet.get("n", 1))):
		if _invocations_de(e) >= int(effet.get("max", 2)):
			break
		var q := _tuile_libre_autour(e.pos)
		if q == Vector2i(-1, -1):
			break
		var x := ajouter(str(effet.get("creature", "feu_follet")), q, "ia")
		if x.is_empty():
			break
		x.camp = e.camp
		x["maitre"] = e.id
		x["fin_invocation"] = tick + int(effet.get("duree_ticks", 120))
		x.horloge = e.horloge
		x.compteur = tick + 1
		n += 1
	if n > 0:
		EventBus.emettre(&"journal", [&"journal.invocation_creature", {"nom": e.name_key, "action": action.name_key, "n": n}])


func _invocations_de(e: Dictionary) -> int:
	var n := 0
	for x in vivants():
		if str(x.get("maitre", "")) == e.id and x.has("fin_invocation"):
			n += 1
	return n


## Une action de créature est un soutien (soin, invocation) : elle ne se choisit pas comme une attaque.
func _est_soutien(a: Dictionary) -> bool:
	if str(a.get("cible", "")) == "allie":
		return true
	for effet: Dictionary in a.get("effets", []):
		if str(effet.get("type", "")) in ["soin", "invoquer"]:
			return true
	return false


## Le meilleur soutien possible maintenant : l'allié le plus blessé à portée d'un soin (sous `ia.soin_seuil`),
## ou une invocation s'il reste de la place et qu'un ennemi est pris pour cible. Vide sinon.
func _meilleur_soutien(e: Dictionary) -> Dictionary:
	var ia_r: Dictionary = regles.r.get("ia", {})
	for aid: String in e.actions:
		var a: Dictionary = actions_creatures.get(aid, {})
		if a.is_empty() or "passive" in a.tags or not _est_soutien(a):
			continue
		for effet: Dictionary in a.effets:
			match str(effet.type):
				"soin":
					var pire := {}
					var ratio_min := float(ia_r.get("soin_seuil", 0.7))
					for x in vivants():
						if x.id == e.id or ennemis(e, x) or Grille.distance(e.pos, x.pos) > int(a.portee[1]):
							continue
						var ratio := float(x.sante) / maxf(1.0, float(x.sante_max))
						if ratio < ratio_min:
							ratio_min = ratio
							pire = x
					if not pire.is_empty():
						return {"action": a, "cible": pire}
				"invoquer":
					if not str(e.get("cible", "")).is_empty() and _invocations_de(e) < int(effet.get("max", 2)):
						return {"action": a, "cible": e}
	return {}


## L'être a une attaque à distance (portée minimale ≥ 2) : au contact, un tireur préfère reculer.
func _a_action_a_distance(e: Dictionary) -> bool:
	for aid: String in e.actions:
		var a: Dictionary = actions_creatures.get(aid, {})
		if not a.is_empty() and not ("passive" in a.tags) and int(a.portee[0]) >= 2:
			return true
	return false


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
## Les modes de déplacement des noyaux (Modules) : projection, attraction, recul, saut, permutation,
## convocation, lancer d'un être porté, traversée, retour à l'Ancre, lévitation, fauchage.
## `cible_hors_entite` sert aux modes qui visent une **tuile** et non un être (Traversée).
## Le choc d'une poussée (Six types de modules, 2026-08-30) : l'être poussé qui bute sur `vers` prend un dé par
## tuile perdue ; si c'est un être qui bloque, il en encaisse une part.
func _choc_de_poussee(c: Dictionary, vers: Vector2i, tuiles_perdues: int, source: String) -> void:
	if tuiles_perdues <= 0 or not grille.dans(vers):
		return
	var dp: Dictionary = regles.r.deplacement
	var deg := des.jet(Des.multiplier(str(dp.get("poussee_des_par_tuile", "1d4")), tuiles_perdues))
	if deg <= 0:
		return
	EventBus.emettre(&"journal", [&"journal.poussee_choc", {"nom": c.name_key, "degats": deg, "tuiles": tuiles_perdues}])
	_appliquer_degats(c, deg, source, {"type": "contondant", "element": {}, "poussee": true})
	var occ := grille.occupant(vers)
	if not occ.is_empty() and entites.has(occ) and entites[occ].vivant:
		var part := roundi(float(deg) * float(dp.get("poussee_part_occupant", 0.5)))
		if part > 0:
			_appliquer_degats(entites[occ], part, source, {"type": "contondant", "element": {}, "poussee": true})


## Où finiraient les êtres si ce plan partait vers `cible_pos` (Écrans d'interface, 2026-08-30) : la règle du
## déplacement rejouée en lecture seule, à la distance maximale du dé. Retourne [{id, de, vers}] (vers ≠ de seulement).
func prevoir_deplacement(e: Dictionary, plan: Dictionary, cible_pos: Vector2i) -> Array:
	var res: Array = []
	var dp: Dictionary = plan.get("parametres", {}).get("deplacement", {})
	if dp.is_empty() or not grille.dans(cible_pos):
		return res
	var tuiles := tuiles_du_plan(e, plan, cible_pos)
	var cibles: Array[Dictionary] = []
	for t in tuiles:
		var occ := grille.occupant(t)
		if not occ.is_empty() and entites.has(occ) and entites[occ].vivant and occ != e.id:
			cibles.append(entites[occ])
	var cible: Dictionary = entites.get(grille.occupant(cible_pos), {})
	var portee_max: int = Des.fourchette(str(dp.get("distance", "1"))).y
	var libre := func(v: Vector2i, hors: Array) -> bool:
		return grille.dans(v) and not grille.bloque_passage(v) and (grille.occupant(v).is_empty() or grille.occupant(v) in hors)
	match str(dp.get("mode", "")):
		"projection":
			for c in cibles:
				if Etres.bloque_statuts(c, "projection", statuts_defs):
					continue
				var d := Vector2i(signi(c.pos.x - e.pos.x), signi(c.pos.y - e.pos.y))
				if d == Vector2i.ZERO:
					continue
				var pos: Vector2i = c.pos
				for i in portee_max:
					var vers: Vector2i = pos + d
					if not libre.call(vers, [c.id]) or grille.h(vers) - grille.h(pos) >= int(regles.r.deplacement.falaise_delta):
						break
					pos = vers
					if grille.h(pos) - grille.h(vers) >= int(regles.r.deplacement.chute_delta):
						break
				if pos != c.pos:
					res.append({"id": c.id, "de": c.pos, "vers": pos})
		"attraction":
			for c in cibles:
				if Etres.bloque_statuts(c, "projection", statuts_defs):
					continue
				var d := Vector2i(signi(e.pos.x - c.pos.x), signi(e.pos.y - c.pos.y))
				var pos: Vector2i = c.pos
				for i in portee_max:
					var vers: Vector2i = pos + d
					if vers == e.pos or not libre.call(vers, [c.id]):
						break
					pos = vers
				if pos != c.pos:
					res.append({"id": c.id, "de": c.pos, "vers": pos})
		"recul":
			var dr: Vector2i = Vector2i(signi(e.pos.x - cible.pos.x), signi(e.pos.y - cible.pos.y)) if not cible.is_empty() else -Vector2i(e.orientation)
			var pos: Vector2i = e.pos
			for i in portee_max:
				var vers: Vector2i = pos + dr
				if not libre.call(vers, [e.id]):
					break
				pos = vers
			if pos != e.pos:
				res.append({"id": e.id, "de": e.pos, "vers": pos})
		"saut":
			var but: Vector2i = cible.pos if not cible.is_empty() else cible_pos
			var ds := Vector2i(signi(but.x - e.pos.x), signi(but.y - e.pos.y))
			var arrivee: Vector2i = e.pos
			for i in portee_max:
				var vers: Vector2i = arrivee + ds
				if not grille.dans(vers) or Grille.distance(e.pos, vers) > Grille.distance(e.pos, but):
					break
				if grille.bloque_passage(vers) or not grille.occupant(vers).is_empty():
					continue
				arrivee = vers
			if arrivee != e.pos:
				res.append({"id": e.id, "de": e.pos, "vers": arrivee})
		"permutation":
			if not cible.is_empty() and cible.vivant and not Etres.bloque_statuts(cible, "projection", statuts_defs):
				res.append({"id": e.id, "de": e.pos, "vers": cible.pos})
				res.append({"id": cible.id, "de": cible.pos, "vers": e.pos})
		"convocation":
			for c in cibles:
				if ennemis(e, c):
					continue
				var l := _tuile_libre_autour(e.pos)
				if l != Vector2i(-1, -1):
					res.append({"id": c.id, "de": c.pos, "vers": l})
	return res


func _effet_deplacement(e: Dictionary, effet: Dictionary, cibles: Array[Dictionary], cible: Dictionary, cible_hors_entite: Vector2i = Vector2i(-1, -1)) -> void:
	match str(effet.get("mode", "")):
		"projection":
			for c in cibles:
				if not c.vivant or Etres.bloque_statuts(c, "projection", statuts_defs):
					continue   # Ancrage : rien ne le déplace
				var d := Vector2i(signi(c.pos.x - e.pos.x), signi(c.pos.y - e.pos.y))
				if d == Vector2i.ZERO:
					continue
				var n := des.jet(effet.get("distance", "1"))
				for i in n:
					var vers: Vector2i = c.pos + d
					if not grille.dans(vers) or grille.bloque_passage(vers) or not grille.occupant(vers).is_empty():
						_choc_de_poussee(c, vers, n - i, e.id)   # ce qui bloque fait mal : un dé par tuile perdue
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
		"attraction":   # la cible est tirée vers le lanceur (Modules — Attraction, Convocation)
			for c in cibles:
				if not c.vivant or Etres.bloque_statuts(c, "projection", statuts_defs):
					continue
				var d := Vector2i(signi(e.pos.x - c.pos.x), signi(e.pos.y - c.pos.y))
				var n_a := des.jet(effet.get("distance", "1"))
				for i in n_a:
					var vers: Vector2i = c.pos + d
					if vers == e.pos or not grille.dans(vers) or grille.bloque_passage(vers) or not grille.occupant(vers).is_empty():
						if vers != e.pos:
							_choc_de_poussee(c, vers, n_a - i, e.id)   # tiré contre un mur ou un autre être
						break
					grille.liberer(c.pos)
					c.pos = vers
					grille.placer(c.id, vers)
		"recul":   # le lanceur se dégage, dos à sa cible (Botte)
			var dr: Vector2i = Vector2i(signi(e.pos.x - cible.pos.x), signi(e.pos.y - cible.pos.y)) if not cible.is_empty() else -Vector2i(e.orientation)
			for i in des.jet(effet.get("distance", "1")):
				var vers: Vector2i = e.pos + dr
				if not grille.dans(vers) or grille.bloque_passage(vers) or not grille.occupant(vers).is_empty():
					break
				grille.liberer(e.pos)
				e.pos = vers
				grille.placer(e.id, vers)
		"saut":   # Élan : le lanceur bondit vers la tuile visée, par-dessus ce qui gêne
			if cible.is_empty():
				return
			var ds := Vector2i(signi(cible.pos.x - e.pos.x), signi(cible.pos.y - e.pos.y))
			var arrivee: Vector2i = e.pos
			for i in des.jet(effet.get("distance", "1")):
				var vers: Vector2i = arrivee + ds
				if not grille.dans(vers) or Grille.distance(e.pos, vers) > Grille.distance(e.pos, cible.pos):
					break
				if grille.bloque_passage(vers) or not grille.occupant(vers).is_empty():
					continue   # on saute par-dessus
				arrivee = vers
			if arrivee != e.pos:
				grille.liberer(e.pos)
				e.pos = arrivee
				grille.placer(e.id, arrivee)
		"permutation":   # les deux échangent leurs places
			if cible.is_empty() or not cible.vivant or Etres.bloque_statuts(cible, "projection", statuts_defs):
				return
			var pe: Vector2i = e.pos
			var pc: Vector2i = cible.pos
			grille.liberer(pe)
			grille.liberer(pc)
			e.pos = pc
			cible.pos = pe
			grille.placer(e.id, pc)
			grille.placer(cible.id, pe)
		"convocation":   # un allié consentant rejoint le lanceur, depuis n'importe où en vue
			for c in cibles:
				if not c.vivant or ennemis(e, c) or c.id == e.id:
					continue
				var libre := _tuile_libre_autour(e.pos)
				if libre == Vector2i(-1, -1):
					continue
				grille.liberer(c.pos)
				c.pos = libre
				grille.placer(c.id, libre)
				EventBus.emettre(&"journal", [&"journal.convocation", {"nom": e.name_key, "allie": c.name_key}])
		"lancer_porte":   # Projection : ce qui est saisi ou lévité part sur N tuiles, dégâts de chute à l'arrivée
			var vole: Dictionary = entites.get(str(e.get("porte", "")), {})
			if vole.is_empty():
				for c in cibles:
					if c.vivant and Etres.a_statut_id(c, "levite"):
						vole = c
						break
			if vole.is_empty():
				EventBus.emettre(&"journal", [&"journal.rien_a_lancer", {"nom": e.name_key}])
				return
			_effet_deplacement(e, {"mode": "projection", "distance": str(effet.get("distance", "5"))}, [vole] as Array[Dictionary], {})
			if not str(e.get("porte", "")).is_empty():
				_liberer_saisie(e, vole)
			var dch := des.jet(str(regles.r.talents.saisie.degats_lancer))
			_appliquer_degats(vole, dch, e.id, {"type": "contondant", "element": {}, "lancer": true})
		"traversee":   # le lanceur traverse murs et entités : il réapparaît sur la première tuile libre au-delà
			if cible.is_empty() and cible_hors_entite == Vector2i(-1, -1):
				return
			var vise: Vector2i = cible.pos if not cible.is_empty() else cible_hors_entite
			var dt := Vector2i(signi(vise.x - e.pos.x), signi(vise.y - e.pos.y))
			if dt == Vector2i.ZERO:
				return
			var but: Vector2i = e.pos
			for i in int(des.jet(effet.get("distance", "1"))):
				var q: Vector2i = e.pos + dt * (i + 1)
				if not grille.dans(q):
					break
				if grille.occupant(q).is_empty() and not grille.bloque_passage(q):
					but = q
			if but != e.pos:
				grille.liberer(e.pos)
				e.pos = but
				grille.placer(e.id, but)
		"retour_ancre":   # Retour : l'Ancre posée plus tôt rappelle son auteur
			var ancres: Array[Dictionary] = []
			for z in zones:
				if str(z.type) == "ancre" and str(z.source) == e.id:
					ancres.append(z)
			if ancres.is_empty():
				EventBus.emettre(&"journal", [&"journal.pas_d_ancre", {"nom": e.name_key}])
				return
			var but_a: Vector2i = ancres.back().pos
			if grille.dans(but_a) and grille.occupant(but_a).is_empty() and not grille.bloque_passage(but_a):
				grille.liberer(e.pos)
				e.pos = but_a
				grille.placer(e.id, but_a)
				EventBus.emettre(&"journal", [&"journal.retour_ancre", {"nom": e.name_key}])
		"levitation":   # la cible flotte : plus rien ne la porte, et elle devient projetable
			for c in cibles:
				if c.vivant and not Etres.bloque_statuts(c, "projection", statuts_defs):
					EventBus.emettre(&"journal", [&"journal.levite", {"nom": c.name_key}])
		"fauchage":   # jet opposé de Force : la cible tombe
			for c in cibles:
				if not c.vivant or c.id == e.id:
					continue
				if des.jet("1d20") + int(e.stats_eff.force) < des.jet("1d20") + int(c.stats_eff.force):
					EventBus.emettre(&"journal", [&"journal.fauchage_rate", {"nom": e.name_key, "def": c.name_key}])
					continue
				_retirer_statut(c, "au_sol")
				appliquer_statut(c, "au_sol", int(statuts_defs.au_sol.duree_ticks), e.id)
				EventBus.emettre(&"journal", [&"journal.fauche", {"nom": c.name_key}])


# ---------------------------------------------------------------- capacités (modules assemblés)

## Le plan d'une SÉQUENCE pour `e`, avec l'arme tenue : ticks, dés et élément de l'arme pour les noyaux
## « arme », et l'**affinité** de la fonctionnalité pour tous les sorts (Structure compétences-modules-slots :
## un sceptre porte les sorts de mana, une épée ceux d'endurance). C'est aussi ce que l'écran Composer lit.
func plan_sequence(e: Dictionary, sequence: Array) -> Dictionary:
	var arme := Etres.arme(e, items)
	var fonct: Dictionary = fonctionnalites.get(arme.get("functionality", ""), {})
	var ticks_arme := regles.ticks_attaque(fonct, false, arme) if not fonct.is_empty() else int(regles.r.actions.attaque_base)
	var plan := capacites.assembler(sequence, ticks_arme, fonct.get("degats_des", "1d4"), _vecteur_arme_de(e, arme), e.competences_eff)
	plan["arme"] = arme
	plan["fonct"] = fonct
	_appliquer_affinite_arme(plan, fonct)
	if plan.has("alt"):
		plan.alt["arme"] = arme
		plan.alt["fonct"] = fonct
		_appliquer_affinite_arme(plan.alt, fonct)
	var suite: Dictionary = plan.get("charge_suivante", {})   # la charge différée d'un déclencheur part plus tard : elle porte l'arme aussi
	while not suite.is_empty():
		suite["arme"] = arme
		suite["fonct"] = fonct
		if not suite.has("name_key"):
			suite["name_key"] = str(suite.get("noyau", {}).get("name_key", ""))
		_appliquer_affinite_arme(suite, fonct)
		suite = suite.get("charge_suivante", {})
	return plan


## L'affinité d'arme d'un plan : ×mana ou ×endurance selon la monnaie, sur la puissance (dés et soins).
func _appliquer_affinite_arme(plan: Dictionary, fonct: Dictionary) -> void:
	var aff: Dictionary = fonct.get("affinite_sorts", regles.r.get("modules", {}).get("affinite_mains_nues", {"mana": 1.0, "endurance": 1.0}))
	var monnaie := str(plan.get("monnaie", ""))
	var f := float(aff.get(monnaie, 1.0)) if not monnaie.is_empty() else 1.0
	plan["affinite_arme"] = f
	plan.mult = float(plan.mult) * f


## La fourchette du coût réel d'un plan (« aucun chiffre fixe » : la ressource payée est un jet autour de sa base).
func fourchette_cout(plan: Dictionary) -> Vector2i:
	var rm: Dictionary = regles.r.get("modules", {})
	var f := Des.fourchette(str(rm.get("cout_variance_des", "2d6")))
	var moy := float(rm.get("cout_variance_moyenne", 7.0))
	var base := float(plan.get("ressource", 0))
	return Vector2i(roundi(base * float(f.x) / moy), roundi(base * float(f.y) / moy))


## Le plan d'une capacité de `e` : assemblage avec l'arme tenue (pour les noyaux « arme »).
func plan_capacite(e: Dictionary, index: int) -> Dictionary:
	var caps: Array = e.get("capacites", [])
	if index < 0 or index >= caps.size():
		return {}
	var plan := plan_sequence(e, caps[index].modules)
	plan["id"] = caps[index].id
	plan["name_key"] = caps[index].get("name_key", "")
	if plan.has("alt"):   # Alternance : le plan du second noyau est lancé tel quel — il lui faut les mêmes attaches
		for cle in ["id", "name_key"]:
			plan.alt[cle] = plan[cle]
	return plan


## La cible d'une capacité est-elle valide (portée, ligne de vue) ?
func capacite_visable(e: Dictionary, plan: Dictionary, cible: Vector2i) -> bool:
	if not grille.dans(cible):
		return false
	if bool(plan.get("drapeaux", {}).get("tracant", false)):   # Traçant : la charge suit, le couvert ne compte plus
		return Grille.distance(e.pos, cible) >= int(plan.portee.x) and Grille.distance(e.pos, cible) <= int(plan.portee.y)
	var occ_t := grille.occupant(cible)   # Traque : la proie marquée se vise sans ligne de vue
	if not occ_t.is_empty() and entites.has(occ_t):
		for st: Dictionary in entites[occ_t].get("statuts", []):
			if str(st.id) == "traque" and str(st.get("source", "")) == e.id:
				return Grille.distance(e.pos, cible) >= int(plan.portee.x) and Grille.distance(e.pos, cible) <= int(plan.portee.y)
	if plan.geometrie == "soi":
		return true
	if str(plan.get("origine", "cible")) == "lanceur":
		return cible != e.pos   # la forme part du lanceur : la tuile cliquée n'est qu'une direction
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
			"cible_marquee":   # Marquée : la cible porte une Marque (et la condition la consommera)
				vrai = not cible.is_empty() and Etres.a_statut_id(cible, str(p.get("consomme", "marque")))
			"cible_alignee":   # Alignement : même ligne, même colonne ou même diagonale que le lanceur
				var dx_a: int = cible_pos.x - e.pos.x
				var dy_a: int = cible_pos.y - e.pos.y
				vrai = cible_pos != e.pos and (dx_a == 0 or dy_a == 0 or absi(dx_a) == absi(dy_a))
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
			"vecteur_de_lieu":   # Terroir : le lieu porte l'élément du noyau
				var el_lieu := wuxing.dominante(vecteur_lieu(e.pos))
				vrai = not el_lieu.is_empty() and el_lieu == wuxing.dominante(plan.get("elements", {}))
			"porteur_en_posture":
				vrai = e.garde
			"jauge_chaine_pleine":
				vrai = e.has("chaine") and e.chaine.segments.size() >= int(e.chaine.capacite) - 1
			"segment_chaine_present":
				vrai = e.has("chaine") and not e.chaine.segments.is_empty()
			"element_cible":   # Affinité : la cible porte l'élément désigné ("X" = celui du noyau)
				var el_vise := str(p.get("element", "X"))
				if el_vise == "X":
					el_vise = wuxing.dominante(plan.get("elements", {}))
				vrai = not cible.is_empty() and not el_vise.is_empty() 					and wuxing.dominante(cible.get("elements", {}) if cible.get("elements") is Dictionary else {}) == el_vise
			"porteur_immobile_depuis":   # Pied ferme : le lanceur n'a pas bougé depuis N ticks
				vrai = tick_de(e) - int(e.get("immobile_depuis", -99999)) >= int(p.get("ticks", 20))
			"corruption_au_dessus":   # Corruption : l'arme qui aime le danger (Niveau de danger)
				vrai = monde != null and monde.corruption_de(_cell_de(e.pos)) >= float(p.get("seuil", 50))
			"phase_du_jour":   # Heure : selon le cycle jour-nuit
				vrai = (str(p.get("phase", "nuit")) == "nuit") == est_nuit()
			"meteo_parmi":   # Intempérie : l'orage nourrit la Foudre
				vrai = monde != null and str(meteo(_cell_de(e.pos))) in p.get("etats", [])
			"porteur_dissimule":   # Ombre : le lanceur est Dissimulé
				vrai = Etres.a_statut_tag(e, "dissimule", statuts_defs)
			"cible_immobilisee":   # Prise : la cible est saisie ou en lévitation
				vrai = not cible.is_empty() and (Etres.a_statut_id(cible, "saisi") or Etres.a_statut_id(cible, "levite") \
					or str(cible.get("saisi_par", "")) != "")
			_:
				vrai = false
		if not vrai:
			return c
		Capacites.appliquer_bonus(plan, c.bonus)
		if p.has("consomme") and not cible.is_empty():   # la marque se consomme : un deuxième sort ne l'exploitera pas
			_retirer_statut(cible, str(p.consomme))
	return {}


## Lance la capacité n° `index` sur la tuile `cible` : coûts, conditions, télégraphe ou exécution.
## Les charges qu'une lecture rapporte pour UN module (Grimoires et manuels) : un jet de dés, multiplié par
## le facteur de la compétence de lecture — aucun chiffre fixe. `depart` : le kit de création du personnage.
func charges_lues(e: Dictionary, depart: bool = false) -> int:
	var rm: Dictionary = regles.r.get("modules", {})
	var notation := str(rm.get("charges_depart_des" if depart else "charges_des", "1d4"))
	var niv := regles.niveau(e.get("competences_eff", e.get("competences", {})), str(rm.get("competence", "lecture")))
	return maxi(1, roundi(float(des.jet(notation)) * regles.skill_factor(niv)))


## Créditer des charges de module (Grimoires et manuels) : la lecture, la création, la triche.
## Apprendre un module, c'est le connaître pour toujours ET recevoir des munitions.
func crediter_module(e: Dictionary, mid: String, charges: int) -> void:
	if not e.has("modules_connus"):
		e["modules_connus"] = []
	if not e.has("modules_charges"):
		e["modules_charges"] = {}
	if not (mid in e.modules_connus):
		e.modules_connus.append(mid)
	e.modules_charges[mid] = int(e.modules_charges.get(mid, 0)) + charges


## Les charges qui manquent pour lancer ce plan (Grimoires et manuels) : une par module de la séquence.
func modules_sans_charge(e: Dictionary, plan: Dictionary) -> Array[String]:
	var manquants: Array[String] = []
	if e.controle != "joueur":
		return manquants   # les créatures n'ont pas de livres : leurs capacités ne se consomment pas
	var compte := {}
	for m in plan.get("modules", []):
		compte[str(m)] = int(compte.get(str(m), 0)) + 1
	for mid in compte.keys():
		if int(e.get("modules_charges", {}).get(mid, 0)) < int(compte[mid]):
			manquants.append(str(mid))
	return manquants


func _lancer_capacite(e: Dictionary, index: int, cible: Variant, tick: int) -> bool:
	var plan := plan_capacite(e, index)
	if plan.is_empty() or not plan.erreurs.is_empty():
		return false
	if plan.has("alt"):   # Alternance (Modules) : un emploi sur deux part avec l'autre noyau
		var cle_alt := "alt:%d" % index
		if int(e.get("emplois", {}).get(cle_alt, 0)) % 2 == 1:
			plan = plan.alt
		if not e.has("emplois"):
			e["emplois"] = {}
		e.emplois[cle_alt] = int(e.emplois.get(cle_alt, 0)) + 1
	var sans_charge := modules_sans_charge(e, plan)
	if not sans_charge.is_empty():   # Grimoires et manuels : un sort sans munition ne part pas
		EventBus.emettre(&"journal", [&"journal.sans_charge", {"nom": e.name_key,
			"module": GameData.catalogues.modules.get(sans_charge[0], {}).get("name_key", sans_charge[0])}])
		return false
	if not str(plan.monnaie).is_empty() and Etres.bloque_statuts(e, str(plan.monnaie), statuts_defs):
		EventBus.emettre(&"journal", [&"journal.monnaie_bloquee", {"nom": e.name_key, "monnaie": "monnaie." + str(plan.monnaie)}])
		return false   # Silence (mana) et Épuisement (endurance) : la ressource du noyau est coupée
	var cible_pos: Vector2i = e.pos if plan.geometrie == "soi" else cible
	if not (cible is Vector2i) and plan.geometrie != "soi":
		return false
	if not capacite_visable(e, plan, cible_pos):
		return false
	if dans_l_eau(e.pos) and wuxing.dominante(plan.get("elements", {})) == "feu":   # pas de Feu sous l'eau (Eau et liquides)
		EventBus.emettre(&"journal", [&"journal.feu_dans_eau", {}])
		return false
	if bool(plan.noyau.get("unique_par_combat", false)) and en_combat(e) and str(plan.noyau.id) in e.get("cataclysmes_combat", []):   # Sorts cataclysmiques : une fois par combat
		EventBus.emettre(&"journal", [&"journal.cataclysme_unique", {}])
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
	plan.ressource = int(plan.ressource) * _facteur_surface(e, plan, cible_pos)   # le prix suit la surface
	if not plan.charge_suivante.is_empty() and plan.charge_suivante.has("geometrie"):   # la charge différée d'un déclencheur aussi
		plan.charge_suivante.ressource = int(plan.charge_suivante.get("ressource", 0)) * _facteur_surface(e, plan.charge_suivante, cible_pos)
	var rm_c: Dictionary = regles.r.get("modules", {})   # « aucun chiffre fixe » : le coût réel est un jet autour de sa base
	plan.ressource = maxi(0, roundi(float(plan.ressource) * float(des.jet(str(rm_c.get("cout_variance_des", "2d6")))) / float(rm_c.get("cout_variance_moyenne", 7.0))))
	_payer(e, plan)
	_consommer_charges(e, plan)   # Grimoires et manuels : une charge par module de la séquence
	e.compteur = tick + int(plan.ticks)
	if bool(plan.drapeaux.get("enchainement", false)) and bool(e.get("dernier_coup_touche", false)):
		plan.ticks = 1   # Enchaînement : la suite d'un coup qui a porté ne coûte (presque) rien
	if regles.est_telegraphee(int(plan.ticks)):
		e.action_en_cours = {"type": "capacite", "plan": plan, "cible_pos": cible_pos, "cible": grille.occupant(cible_pos), "ticks": plan.ticks, "name_key": plan.name_key}
		EventBus.emettre(&"journal", [&"journal.telegraphe", {"nom": e.name_key, "action": plan.name_key, "ticks": plan.ticks}])
		EventBus.emettre(&"action_engaged", [e.id, e.action_en_cours])
		return true
	_executer_capacite(e, plan, cible_pos)
	return true


## Dépense une charge de chaque module de la séquence (Grimoires et manuels) — le joueur seul :
## les créatures n'ont pas de livres, leurs capacités ne s'épuisent pas.
func _consommer_charges(e: Dictionary, plan: Dictionary) -> void:
	if e.controle != "joueur":
		return
	for m in plan.get("modules", []):
		var mid := str(m)
		var reste := int(e.get("modules_charges", {}).get(mid, 0)) - 1
		if reste <= 0:
			e.modules_charges.erase(mid)
		else:
			e.modules_charges[mid] = reste


## Paie la monnaie du noyau. Mana insuffisant = surchauffe : le déficit est infligé en PV × 2 (Mana).
func _payer(e: Dictionary, plan: Dictionary) -> void:
	if not plan.charge_suivante.is_empty():
		_payer(e, plan.charge_suivante)   # la charge différée paie aussi, dans sa propre monnaie
	match str(plan.monnaie):
		"mana":
			var cout := roundi(float(plan.ressource) * mult_mana_lieu(e, plan) * mult_mana_sources(e))   # le lieu module le mana (Wu Xing hors combat)
			var deficit: int = maxi(0, cout - int(e.mana))
			e.mana = maxi(0, int(e.mana) - cout)
			if deficit > 0:
				var degats := roundi(float(deficit * int(regles.r.mana.surchauffe_mult)) * float(e.get("mecaniques", {}).get("surchauffe_mult", {}).get("mult", 100)) / 100.0)
				EventBus.emettre(&"journal", [&"journal.surchauffe", {"nom": e.name_key, "deficit": deficit, "degats": degats}])
				if a_talent(e, "chair_de_mana"):   # Chair de mana (Talents de race) : le corps paie en endurance
					e.endurance = maxi(0, int(e.endurance) - degats)
				else:
					_appliquer_degats(e, degats, "", {"surchauffe": true})
		"endurance":   # Épuisement (Mana) : au-delà du pool, le déficit se paie en PV — rien n'est gratuit
			var deficit_e: int = maxi(0, int(plan.ressource) - int(e.endurance))
			e.endurance = maxi(0, int(e.endurance) - int(plan.ressource))
			if deficit_e > 0:
				var degats_e := roundi(float(deficit_e) * float(regles.r.endurance.get("epuisement_mult", 1)))
				if degats_e > 0:
					EventBus.emettre(&"journal", [&"journal.epuisement", {"nom": e.name_key, "deficit": deficit_e, "degats": degats_e}])
					_appliquer_degats(e, degats_e, "", {"surchauffe": true})


## Exécute une capacité : forme → cibles (friendly fire des zones), puis les effets du noyau.
func _executer_capacite(e: Dictionary, plan: Dictionary, cible_pos: Vector2i, segment: bool = true) -> void:
	var tick := tick_de(e)
	if "cataclysme" in plan.noyau.get("tags", []):   # Sorts cataclysmiques : le coût mord — l'endurance est vidée, et c'est noté pour le combat
		e.endurance = 0
		if not e.has("cataclysmes_combat"):
			e["cataclysmes_combat"] = []
		if not (str(plan.noyau.id) in e.cataclysmes_combat):
			e.cataclysmes_combat.append(str(plan.noyau.id))
		EventBus.emettre(&"journal", [&"journal.cataclysme", {"nom": e.name_key}])
	e["sans_trace"] = bool(plan.drapeaux.get("sans_trace", false)) or bool(plan.drapeaux.get("silencieux", false))
	if plan.drapeaux.has("canalisation"):   # Canalisation : les dés de l'immobilité, comptés au lancement
		var cn: Dictionary = plan.drapeaux.canalisation
		var immobile := tick - int(e.get("immobile_depuis", tick))
		plan.des_bonus = int(plan.des_bonus) + int(cn.get("des_par", 1)) * int(immobile / maxi(1, int(cn.get("ticks", 5))))
	if bool(plan.drapeaux.get("prisme", false)):   # Prisme : le noyau prend l'élément qui domine la cible
		var occ_p := grille.occupant(cible_pos)
		if not occ_p.is_empty() and entites.has(occ_p):
			var dom_c := wuxing.dominante(entites[occ_p].get("elements", {}) if entites[occ_p].get("elements") is Dictionary else {})
			for el in wuxing.w.domine.keys():   # celui qui DOMINE l'élément de la cible (table domine : x → ce que x domine)
				if str(wuxing.w.domine[el]) == dom_c:
					plan.elements = {str(el): 1.0}
					break
	if plan.drapeaux.has("element_vers"):   # Transmutation : l'élément du noyau devient celui choisi
		plan.elements = {str(plan.drapeaux.element_vers): 1.0}
	var tuiles := tuiles_du_plan(e, plan, cible_pos)
	var touchees := _entites_dans(e, plan, tuiles)
	if int(plan.drapeaux.get("emprise", 0)) > 0:   # Emprise : ce qui est touché ne se déplace plus
		for c in touchees:
			if c.vivant and c.id != e.id:
				appliquer_statut(c, "enracinement", int(plan.drapeaux.emprise), e.id)
	# Liaisons qui étendent les cibles : Miroir (position symétrique), Partage (le lanceur aussi).
	for l: Dictionary in plan.liaisons:
		if l.get("meute", false):   # Meute (La Trace) : la forme s'applique aussi depuis la tuile de chaque compagnon
			for comp in compagnons_de(e):
				if not comp.vivant or Grille.distance(comp.pos, cible_pos) > int(plan.portee.y) + int(plan.taille):
					continue
				for c in _entites_dans(e, plan, Capacites.tuiles_de_forme(grille, plan.geometrie, comp.pos, cible_pos, int(plan.taille))):
					if not touchees.has(c):
						touchees.append(c)
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
	if plan.drapeaux.has("fragmentation") and salve.is_empty():   # Fragmentation : la charge se divise en éclats
		var fr: Dictionary = plan.drapeaux.fragmentation
		salve = {"salve": int(fr.get("n", 3)), "mult": float(fr.get("mult", 0.4))}
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
	for sup: Dictionary in plan.get("charges_sup", []):   # les noyaux de plus, chacun sa charge
		var r_sup := _appliquer_charge(e, sup, touchees, tuiles, cible_pos, {})
		res.a_touche = bool(res.get("a_touche", false)) or bool(r_sup.get("a_touche", false))
		if res.get("premiere", {}).is_empty():
			res.premiere = r_sup.premiere
	e["sans_trace"] = false   # le drapeau ne vaut que pour la capacité qui vient de partir
	if not res.has("a_touche"):   # un plan sans noyau (une suite de déclencheur réduite à sa forme) : rien n'a porté
		res = {"a_touche": false, "premiere": {}, "tuee": {}}
	e["dernier_coup_touche"] = res.a_touche   # Enchaînement : la prochaine capacité saura si celle-ci a porté
	if bool(plan.drapeaux.get("ligature", false)):   # Ligature : affûts et tourelles de la forme tirent tout de suite
		for a in affuts:
			if str(a.source) == e.id and a.pos in tuiles:
				a.prochain = tick
	if int(plan.drapeaux.get("remanence", 0)) > 0:   # Rémanence : la zone touchée réapplique la charge à l'entrée
		for t in tuiles:
			if grille.dans(t):
				zones.append({"pos": t, "type": "remanence", "fin": tick + int(plan.drapeaux.remanence),
					"source": e.id, "params": {"plan": plan.duplicate()}, "elements": plan.elements.duplicate(), "cachee": _plan_discret(plan)})
	var a_touche: bool = res.a_touche
	for l: Dictionary in plan.liaisons:
		if l.get("propagation", false) and a_touche and not touchees.is_empty():   # « a touché » sans être (terrain, zone) : rien d'où propager
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
				if a_talent(e, "graveur"):   # Le Sceau : permanent, 2× mana, immobile pendant la gravure
					duree = 1 << 30
					e.mana = maxi(0, int(e.mana) - int(plan.ressource) * (int(regles.r.talents.graveur.mana_mult) - 1))
					appliquer_statut(e, "gravure", int(regles.r.talents.graveur.gravure_ticks), e.id)
				glyphes.append({"pos": cible_pos, "plan": suite, "source": e.id, "fin": tick + duree, "elements": suite.elements,
					"cache": a_talent(e, "dissimulation")})
				if not a_talent(e, "dissimulation"):   # L'Ombre : ses pièges ne se voient pas (Talents de classe)
					grille.dangers[grille.idx(cible_pos)] = true
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
			"riposte", "parade", "ouverture", "veille", "testament", "accord", "derobade":
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
		if plan.geometrie == "point" and c.id == e.id and plan.get("formes_sup", []).is_empty():
			continue   # « point » vise autrui ; toute autre forme peut couvrir le lanceur — on peut se tuer
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
				for c in touchees:   # le lanceur n'est plus épargné : une forme qui le couvre le brûle (Six types de modules)
					var d := _degats_capacite(e, c, plan, prev)
					a_touche = true
					if premiere.is_empty():
						premiere = c
					EventBus.emettre(&"journal", [&"journal.capacite", {"att": e.name_key, "capacite": plan.get("name_key", ""), "def": c.name_key, "zone": d.zone, "degats": d.degats}])
					_appliquer_degats(c, d.degats, e.id, d)
					if not c.vivant and tuee.is_empty():
						tuee = c
					if plan.drapeaux.has("vampirique"):
						e.sante = mini(e.sante_max, e.sante + roundi(float(d.degats) * float(plan.drapeaux.vampirique)))
			"soin":
				for c in touchees:   # le camp n'est plus vérifié : un sort mal composé soigne l'ennemi
					if not c.vivant:
						continue
					var soin := des.jet(plan.des, int(plan.des_bonus))
					if not prev.is_empty() and prev.resout:
						soin = roundi(float(soin) * float(prev.multiplicateur) * float(wuxing.w.chaine.resolveur_non_offensif))
					var avant: int = c.sante
					c.sante = mini(c.sante_max, c.sante + soin)
					if c.sante > avant:
						c["sang"] = 0   # L'Écarlate : soigner vide la jauge
					a_touche = true
					if a_talent(e, "souffle_rendu") and c.sante > avant:   # Souffle rendu : un segment de l'élément de la cible
						var el_c: Dictionary = c.get("elements", {}) if c.get("elements") is Dictionary else {}
						_poser_segment(e, el_c if not el_c.is_empty() else {"bois": 1.0}, tick, "soin")
					if premiere.is_empty():
						premiere = c
					EventBus.emettre(&"journal", [&"journal.soin", {"att": e.name_key, "capacite": plan.name_key, "def": c.name_key, "soin": c.sante - avant}])
			"resurrection":   # Renaissance (Domaines de grimoires et manuels) : l'âme portée rappelle le compagnon
				var ame := ame_dans_sac(e)
				if ame.is_empty():
					EventBus.emettre(&"journal", [&"journal.renaissance_rien", {}])
				else:
					var comp: Dictionary = entites.get(str(items[ame].get("compagnon", "")), {})
					if _ressusciter(e, ame, tick, "", true):
						a_touche = true
						EventBus.emettre(&"journal", [&"journal.renaissance", {"nom": e.name_key, "compagnon": comp.get("name_key", "")}])
			"deplacement":
				var dp: Dictionary = plan.parametres.get("deplacement", {})
				if not dp.is_empty():
					var occ := grille.occupant(cible_pos)
					_effet_deplacement(e, dp, touchees, entites.get(occ, {}), cible_pos)
					a_touche = true   # un déplacement agit même sans cible vivante (Traversée, Retour, Élan)
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
				if tp.has("zone"):   # une zone au sol plutôt qu'un remodelage (Modules)
					for t in tuiles:
						if not grille.dans(t):
							continue
						zones.append({"pos": t, "type": str(tp.zone), "fin": tick + int(tp.get("duree_ticks", 50)),
							"source": e.id, "params": tp, "elements": plan.elements.duplicate(), "cachee": _plan_discret(plan)})
						a_touche = true
						EventBus.emettre(&"tile_changed", [t])
					EventBus.emettre(&"journal", [&"journal.zone_posee", {"nom": e.name_key, "zone": "zone." + str(tp.zone)}])
				if not tp.is_empty() and tp.has("delta"):
					for t in tuiles:
						var avant := grille.h(t)
						var apres := clampi(avant + int(tp.delta), 0, 20)
						if apres == avant:
							continue
						_memoriser_terrain(t)   # le monde se soigne hors claim (Destruction du terrain)
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
				if iv.has("mode"):   # une invocation vivante ou mécanique (Modules), pas un contenu de tuile
					a_touche = _invoquer(e, str(iv.mode), tuiles, cible_pos, plan, tick) or a_touche
				elif not iv.is_empty():
					for t in tuiles:
						if not grille.occupant(t).is_empty() or grille.bloque_passage(t):
							continue
						grille.poser_contenu(t, str(iv.contenu))
						obstacles.append({"pos": t, "fin": tick + int(iv.duree_ticks), "source": e.id})
						a_touche = true
						EventBus.emettre(&"journal", [&"journal.invocation", {"nom": e.name_key, "contenu": "tile_content." + str(iv.contenu) + ".name", "x": t.x, "y": t.y, "ticks": iv.duree_ticks}])
						EventBus.emettre(&"tile_changed", [t])
			"ressource":   # Modules : les noyaux qui déplacent des points (mana, endurance, PV, jauge de sang)
				var rs: Dictionary = plan.parametres.get("ressource", {})
				if not rs.is_empty():
					var sur_soi: bool = str(rs.get("cible", "")) == "soi"
					var vises: Array[Dictionary] = ([e] as Array[Dictionary]) if sur_soi else touchees
					for c in vises:
						if not c.vivant:
							continue
						if rs.has("mana"):
							c.mana = clampi(int(c.mana) + int(rs.mana), 0, int(c.mana_max))
						if rs.has("endurance"):
							c.endurance = clampi(int(c.endurance) + int(rs.endurance), 0, int(c.endurance_max))
						if rs.has("sang"):   # L'Écarlate : la jauge monte d'un cran
							c["sang"] = mini(int(regles.r.talents.jauge_de_sang.max), int(c.get("sang", 0)) + int(rs.sang) * int(regles.r.talents.jauge_de_sang.max) / 4)
						if rs.has("purge"):   # retire un statut négatif, le premier trouvé
							for st: Dictionary in c.statuts.duplicate():
								if "negatif" in statuts_defs.get(st.id, {}).get("tags", []) or "controle" in statuts_defs.get(st.id, {}).get("tags", []):
									_retirer_statut(c, str(st.id))
									EventBus.emettre(&"journal", [&"journal.purge", {"nom": c.name_key, "statut": statuts_defs[st.id].name_key}])
									break
						if rs.has("sante") and int(rs.sante) != 0:
							if int(rs.sante) < 0:
								_appliquer_degats(c, -int(rs.sante), "", {"type": "ressource", "element": {}})
							else:
								c.sante = mini(int(c.sante_max), int(c.sante) + int(rs.sante))
						a_touche = true
						if premiere.is_empty():
							premiere = c
					if rs.has("vol_mana"):   # Ponction : le mana pris à la cible revient au lanceur
						for c in touchees:
							if c.id == e.id or not c.vivant:
								continue
							var vole := mini(int(c.mana), int(rs.vol_mana))
							c.mana = int(c.mana) - vole
							e.mana = mini(int(e.mana_max), int(e.mana) + vole)
							EventBus.emettre(&"journal", [&"journal.ponction", {"nom": e.name_key, "def": c.name_key, "mana": vole}])
							break
					if rs.has("desarme"):   # Désarmement : jet opposé, l'arme tombe sur la tuile de la cible
						for c in touchees:
							if c.id == e.id or not c.vivant:
								continue
							var arme_c := str(c.get("equipement", {}).get("main_principale", ""))
							if arme_c.is_empty():
								continue
							if des.jet("1d20") + int(e.stats_eff.force) < des.jet("1d20") + int(c.stats_eff.force):
								EventBus.emettre(&"journal", [&"journal.desarmement_rate", {"nom": c.name_key}])
								continue
							c.equipement.erase("main_principale")
							c.sac.erase(arme_c)
							_poser_contenant(c.pos, [arme_c], "butin")
							Etres.recalculer(c, items, affixes_defs, regles)
							EventBus.emettre(&"journal", [&"journal.desarmement", {"nom": c.name_key, "objet": nom_objet(arme_c)}])
					if rs.has("estime"):   # Estimation : la fiche exacte de la cible, dans le journal
						for c in touchees:
							if c.id == e.id:
								continue
							EventBus.emettre(&"journal", [&"journal.estimation", {"nom": c.name_key,
								"pv": "%d/%d" % [int(c.sante), int(c.sante_max)],
								"element": "element." + wuxing.dominante(c.get("elements", {}) if c.get("elements") is Dictionary else {}),
								"stats": "F%d D%d E%d V%d P%d C%d" % [int(c.stats_eff.force), int(c.stats_eff.dexterite),
									int(c.stats_eff.endurance), int(c.stats_eff.volonte), int(c.stats_eff.perception), int(c.stats_eff.charisme)]}])
							break
					if rs.has("segment_de_la_cible"):   # Souffle rendu : un segment de l'élément de la cible soignée
						for c in touchees:
							if c.id == e.id or ennemis(e, c):
								continue
							var el_c: Dictionary = c.get("elements", {}) if c.get("elements") is Dictionary else {}
							_poser_segment(e, el_c if not el_c.is_empty() else {"bois": 1.0}, tick, "soin")
							break
					if rs.has("releve_allie_pct"):   # Rappel à la vie : un allié tombé se relève à N % de ses PV
						var tombes: Array[Dictionary] = []   # les touchés ne comptent que les vivants : les morts se cherchent sur les tuiles
						for x in entites.values():
							if not x.vivant and x.pos in tuiles and not ennemis(e, x) and x.id != e.id:
								tombes.append(x)
						for c in tombes:
							if c.vivant or ennemis(e, c):
								continue
							c.vivant = true
							c.sante = maxi(1, int(float(c.sante_max) * float(rs.releve_allie_pct) / 100.0))
							c.statuts.clear()
							if grille.occupant(c.pos).is_empty():
								grille.placer(c.id, c.pos)
							appliquer_statut(c, "affaibli", int(statuts_defs.affaibli.duree_ticks), e.id)
							EventBus.emettre(&"journal", [&"journal.rappel_a_la_vie", {"nom": e.name_key, "def": c.name_key}])
							break
					if rs.has("transfert_pv"):   # Transfert : le lanceur donne ses propres PV, 1:1
						for c in touchees:
							if c.id == e.id or not c.vivant or ennemis(e, c):
								continue
							var don := mini(int(rs.transfert_pv), maxi(0, int(e.sante) - 1))
							e.sante = int(e.sante) - don
							c.sante = mini(int(c.sante_max), int(c.sante) + don)
							EventBus.emettre(&"journal", [&"journal.transfert", {"nom": e.name_key, "def": c.name_key, "pv": don}])
							break
			"saisie":   # Empoigne : la première cible vivante adjacente est saisie (Talents de classe — Le Porteur)
				for c in touchees:
					if c.vivant and c.id != e.id and _saisir(e, c.id, tick_de(e), false):
						a_touche = true
						break
			_:
				push_warning("Capacités : effet de noyau inconnu, ignoré — « %s » (%s)" % [effet, str(plan.noyau.get("id", ""))])
	return {"a_touche": a_touche, "premiere": premiere, "tuee": tuee}


## Dégâts d'un noyau sur une cible : noyau « arme » = formule de l'arme ; noyau magique = jet × niveau.
## La réduction d'armure ne s'applique qu'à 50 % aux dégâts magiques (Armure par zone).
## Les dés d'une bombe : la notation × le noyau répété, plus les dés de bonus des modificateurs (Concentration…) —
## ce que l'écran Composer annonce est ce qui explose.
static func _des_bombe(notation: String, fois: int, des_bonus: int) -> String:
	var p := Des.analyser(Des.multiplier(notation, fois))
	if p.faces == 0:
		return str(p.bonus)
	return "%dd%d" % [maxi(1, p.n + des_bonus), p.faces] + ("+%d" % p.bonus if p.bonus > 0 else "")


## Les invocations des noyaux (Modules) : la charge de Bombe, la Tourelle, le Relevé, l'Écho de chair.
## Chacune réutilise la mécanique que le jeu a déjà — bombes, affûts, relevé du Fossoyeur, compagnon temporaire.
func _invoquer(e: Dictionary, mode: String, tuiles: Array[Vector2i], cible_pos: Vector2i, plan: Dictionary, tick: int) -> bool:
	var iv: Dictionary = regles.r.get("invocations", {})
	var fois: int = maxi(1, int(plan.get("fois", 1)))   # noyau répété : bombe et tourelle × n, n créatures
	match mode:
		"bombe":   # une charge PAR TUILE de la forme : on peut miner une salle entière, au prix fort
			var b: Dictionary = iv.get("bombe", {})
			var posees := 0
			for q in tuiles:
				if not grille.dans(q):
					continue
				bombes.append({"pos": q, "fin": tick + int(b.get("retard_ticks", 20)), "horloge": str(e.horloge),
					"puissance": float(b.get("puissance", 40.0)) * float(fois), "rayon": int(b.get("rayon", 2)),
					"degats": _des_bombe(str(b.get("degats", "3d6")), fois, int(plan.get("des_bonus", 0))), "source": e.id})
				posees += 1
			if posees > 0:
				EventBus.emettre(&"journal", [&"journal.bombes_posees", {"nom": e.name_key, "n": posees, "retard": int(b.get("retard_ticks", 20))}])
			return posees > 0
		"tourelle":   # un affût autonome : il tire tout seul, avec l'élément de l'arme du lanceur
			var t: Dictionary = iv.get("tourelle", {})
			var n_tour := 0
			for q in tuiles:
				if not grille.dans(q) or not grille.occupant(q).is_empty() or grille.bloque_passage(q):
					continue
				grille.poser_contenu(q, "barriere")
				affuts.append({"pos": q, "source": e.id, "prochain": tick + int(t.get("cadence_ticks", 6)),
					"fin": tick + int(t.get("duree_ticks", 120)), "degats": _des_bombe(str(t.get("degats", "1d6")), fois, int(plan.get("des_bonus", 0))),   # comme la bombe : × n, + dés de bonus
					"portee": int(t.get("portee", 6)), "elements": plan.elements.duplicate()})
				EventBus.emettre(&"tile_changed", [q])
				n_tour += 1   # une tourelle par tuile libre de la forme
			if n_tour > 0:
				EventBus.emettre(&"journal", [&"journal.tourelle_posee", {"nom": e.name_key, "n": n_tour}])
			return n_tour > 0
		"releve":   # un cadavre présent se relève au service du lanceur (la réputation en pâtit)
			for q in tuiles:
				for x in entites.values():
					if not x.vivant and x.pos == q and not bool(x.get("releve", false)):
						if _relever_brut(e, x, tick):
							return true
			EventBus.emettre(&"journal", [&"journal.pas_de_cadavre", {"nom": e.name_key}])
			return false
		"creature":   # Écho de chair, Feu follet… : une créature alliée temporaire PAR TUILE libre de la forme
			var c: Dictionary = iv.get("echo_de_chair", {}).duplicate()
			var inv_p: Dictionary = plan.get("parametres", {}).get("invocation", {})
			if inv_p.has("creature"):   # la fiche d'invocation est dans le noyau (Six types de modules, 2026-08-30)
				c["creature"] = str(inv_p.creature)
			if inv_p.has("duree_ticks"):
				c["duree_ticks"] = int(inv_p.duree_ticks)
			var n_inv := 0
			for q in tuiles:
				if not grille.dans(q) or not grille.occupant(q).is_empty() or grille.bloque_passage(q):
					continue
				var x := ajouter(str(c.get("creature", "loup")), q, "ia")
				if x.is_empty():
					continue
				x.camp = e.camp
				x["maitre"] = e.id
				x["fin_invocation"] = tick + int(c.get("duree_ticks", 80))
				x.horloge = e.horloge
				x.compteur = tick + 1
				n_inv += 1
				for _k in range(fois - 1):   # noyau répété : n créatures par tuile, les suivantes autour
					var q2 := _tuile_libre_autour(q)
					if q2 == Vector2i(-1, -1):
						break
					var x3 := ajouter(str(c.get("creature", "loup")), q2, "ia")
					if x3.is_empty():
						break
					x3.camp = e.camp
					x3["maitre"] = e.id
					x3["fin_invocation"] = tick + int(c.get("duree_ticks", 80))
					x3.horloge = e.horloge
					x3.compteur = tick + 1
					n_inv += 1
			if n_inv == 0:   # aucune tuile de la forme n'est libre : la plus proche fait l'affaire
				var libre := _tuile_libre_autour(cible_pos)
				if libre == Vector2i(-1, -1):
					return false
				var x2 := ajouter(str(c.get("creature", "loup")), libre, "ia")
				if x2.is_empty():
					return false
				x2.camp = e.camp
				x2["maitre"] = e.id
				x2["fin_invocation"] = tick + int(c.get("duree_ticks", 80))
				x2.horloge = e.horloge
				x2.compteur = tick + 1
				n_inv = 1
			EventBus.emettre(&"journal", [&"journal.echo_de_chair", {"nom": e.name_key, "n": n_inv}])
			return true
	return false


## Les tuiles couvertes par un plan : la forme principale, **plus** celles ajoutées par les formes
## suivantes (aucune limite d'assemblage — Six types de modules). Union, sans doublon.
func tuiles_du_plan(e: Dictionary, plan: Dictionary, cible_pos: Vector2i) -> Array[Vector2i]:
	var tuiles := Capacites.tuiles_de_forme(grille, plan.geometrie, e.pos, cible_pos, int(plan.taille))
	for f: Dictionary in plan.get("formes_sup", []):
		for t in Capacites.tuiles_de_forme(grille, str(f.geometrie), e.pos, cible_pos, int(f.taille)):
			if not tuiles.has(t):
				tuiles.append(t)
	return tuiles


## Le facteur de surface d'un plan (Six types de modules) : un effet qui s'instancie **par tuile**
## (invocation, zone au sol, remodelage) coûte son prix autant de fois qu'il y a de tuiles.
func _facteur_surface(e: Dictionary, plan: Dictionary, cible_pos: Vector2i) -> int:
	if not plan_par_tuile(plan):
		return 1
	return maxi(1, tuiles_du_plan(e, plan, cible_pos).size())


## Un plan dont un effet s'instancie par tuile (invocation, zone, terrain) : son prix suit la surface.
func plan_par_tuile(plan: Dictionary) -> bool:
	for lot in ([plan] as Array) + plan.get("charges_sup", []):
		for ef in lot.get("effets", []):
			if str(ef) in ["invocation", "terrain"]:
				return true
	return false


## La surface d'un plan par tuile **avant de viser** (écran Composer) : une visée nominale à portée maximale,
## vers le centre de la grille pour que la forme tienne dedans. 1 pour un plan qui n'est pas par tuile.
func surface_nominale(e: Dictionary, plan: Dictionary) -> int:
	if not plan_par_tuile(plan) or not plan.has("portee"):
		return 1
	var centre := grille.origine + Vector2i(grille.largeur / 2, grille.hauteur_grille / 2)
	var dir := Vector2i(signi(centre.x - e.pos.x), signi(centre.y - e.pos.y))
	if dir == Vector2i.ZERO:
		dir = Vector2i.RIGHT
	var cible: Vector2i = e.pos + dir * maxi(1, int(plan.portee.y))
	return _facteur_surface(e, plan, cible)


## Balise (Modules) : les dés de plus que la tuile visée accorde au porteur qui l'a marquée.
func _bonus_balise(e: Dictionary, pos: Vector2i) -> int:
	var bonus := 0
	for z in zones_sur(pos, "balise"):
		if str(z.source) == e.id:
			bonus += int(z.params.get("des", 1))
	return bonus


func _degats_capacite(e: Dictionary, c: Dictionary, plan: Dictionary, prev: Dictionary) -> Dictionary:
	var a_zero: bool = e.endurance <= 0 and plan.monnaie == "endurance"
	var arme_noyau: bool = plan.noyau.get("power_base") == "arme"
	var d: Dictionary
	var type_degats := "magique"
	var des_bonus := int(plan.des_bonus) + _bonus_balise(e, c.pos)   # Balise : la tuile marquée donne ses dés
	if arme_noyau and not plan.arme.is_empty():
		d = regles.degats_arme(e.stats_eff, plan.arme, plan.fonct, des, false, a_zero, des_bonus, e.competences_eff, plan.elements)
		type_degats = str(plan.fonct.type_degats)
	else:
		var jet := des.jet(plan.des, des_bonus)
		if Etres.bloque_statuts(e, "relance", statuts_defs):   # Pari : le second résultat s'applique, quel qu'il soit
			jet = des.jet(plan.des, des_bonus)
			_retirer_statut(e, "pari")
			EventBus.emettre(&"journal", [&"journal.pari", {"nom": e.name_key, "jet": jet}])
		d = {"jet": jet, "bruts": float(jet)}
	var bruts: float = d.bruts * float(plan.mult)
	if plan.drapeaux.has("detonation") and (c.has("fin_invocation") or bool(c.get("releve", false))):
		bruts *= float(plan.drapeaux.detonation)   # Détonation : le double contre les invocations
	var zone: Dictionary = regles.zone_de_coup(grille.h(e.pos), grille.h(c.pos))
	var dom := multiplicateur_domination(plan.elements, c, zone.zone)
	var gain: float = float(prev.get("gain", 1.0)) if not prev.is_empty() else 1.0
	var chaine: float = float(prev.get("multiplicateur", 1.0)) if not prev.is_empty() else 1.0
	bruts *= float(dom.mult) * float(gain) * float(chaine)
	var piece := Etres.piece_zone(c, zone.zone, items)
	var armure := 0.0
	if not plan.drapeaux.get("ignore_armure", false):
		armure = regles.armure_piece(piece, type_degats) + Etres.add_statuts(c, "armure", statuts_defs)   # « magique » : la matrice le connaît
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
		"construction": str(piece.get("construction", "")), "evites": maxi(0, roundi(bruts * zone.mult) - degats),
		"erosion": float(plan.get("drapeaux", {}).get("erosion", 0.0))}


# ---------------------------------------------------------------- engagement (Temporalités parallèles)

## Place `a` et `b` dans la même horloge de combat (créée au besoin), compteurs rebasés.
func _engager_combat(a: Dictionary, b: Dictionary) -> void:
	a.erase("relance_utilisee")   # Le Rieur : une relance par combat
	b.erase("relance_utilisee")
	a.erase("cataclysmes_combat")   # Sorts cataclysmiques : un par combat
	b.erase("cataclysmes_combat")
	a.erase("second_souffle_pris")   # Trésors et artefacts : un second souffle par combat
	b.erase("second_souffle_pris")
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
		c.participants = c.participants.filter(func(pid: String) -> bool: return entites.has(pid))   # la fenêtre glissante a pu décharger un participant
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
				p.erase("degats_element_bonus")   # Nourriture : l'huile d'arme ne vaut que pour ce combat
				if p.has("erosion"):   # Érosion : les PV max rognés reviennent à la fin du combat
					p.erase("erosion")
					Etres.recalculer(p, items, affixes_defs, regles)
				_quitter_combat(p)
			TickManager.retirer(nom)
			combats.erase(nom)
			EventBus.emettre(&"combat_ended", [nom])
			EventBus.emettre(&"journal", [&"journal.desengagement", {}])


# ---------------------------------------------------------------- IA utility (IA des créatures)

func _decider_ia(e: Dictionary, tick: int) -> void:
	var profil: Dictionary = profils_ia.get(e.ai_profile, {})
	if Etres.a_statut_tag(e, "confusion", statuts_defs) and des.reel() < float(regles.r.get("statuts", {}).get("confusion_chance", 0.3)):   # Confusion : l'IA aussi s'égare
		var libres: Array[Vector2i] = []
		for dd in Grille.DIRS:
			var q: Vector2i = e.pos + dd
			if grille.dans(q) and not grille.bloque_passage(q) and grille.occupant(q).is_empty() and grille.cout_pas(e.pos, q) >= 0:
				libres.append(q)
		if not libres.is_empty():
			EventBus.emettre(&"journal", [&"journal.confusion", {"nom": e.name_key}])
			_deplacer(e, libres[des.entier(0, libres.size() - 1)], tick)
			return
	if bool(e.get("suiveur_local", false)):   # Compagnons : un suiveur territorial ne sort pas de chez lui
		var m0: Dictionary = entites.get(str(e.get("maitre", "")), {})
		if m0.is_empty() or monde == null or lieu != "camp" or not monde.claims.has(_cell_de(m0.pos)):
			EventBus.emettre(&"journal", [&"journal.suiveur_fin", {"nom": e.name_key}])
			_fin_suiveur(e)
	if grille.dangers.has(grille.idx(e.pos)):   # Météo : on ne reste pas dans le feu — un pas hors des flammes
		var sorties: Array[Vector2i] = []
		for d in Grille.DIRS:
			var q: Vector2i = e.pos + d
			if grille.dans(q) and not grille.dangers.has(grille.idx(q)) and grille.cout_pas(e.pos, q, Etres.est_volant(e)) >= 0 and grille.occupant(q).is_empty():
				sorties.append(q)
		if not sorties.is_empty() and _deplacer(e, sorties[des.entier(0, sorties.size() - 1)], tick):
			return
	if e.camp == "civil":   # les civils fuient un spectre à vue (Talents de race)
		for x in vivants():
			if a_talent(x, "sans_chair") and voit_ia(e, x):
				appliquer_statut(e, "terreur", int(regles.r.talents.sans_chair.terreur_ticks), x.id)
				break
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
		"assaut":
			_ia_assaut(e, tick)
		"reculer":   # un pas qui éloigne de la cible (même pas que la fuite), pour retrouver sa portée
			_ia_fuir(e, cible, tick)
		"soutenir":
			var s := _meilleur_soutien(e)
			if s.is_empty():
				_attendre(e, tick)
			else:
				if not cible.is_empty():
					_engager_combat(e, cible)
				_lancer_action_creature(e, s.action, s.cible, tick)
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
	# Toute la détection passe par voit_ia : Perception, ligne de vue, nuit et lumière, Dissimulation de
	# L'Ombre, pas silencieux, Discrétion de la cible. Lire la Perception brute ici court-circuitait tout ça.
	if e.has("cible_prioritaire"):   # Compagnons : la cible désignée passe devant, tant qu'elle vit et se voit
		var cp: Dictionary = entites.get(str(e.cible_prioritaire), {})
		if cp.is_empty() or not cp.vivant:
			e.erase("cible_prioritaire")
		elif e.cible != cp.id and grille.ligne_de_vue(e.pos, cp.pos):
			e.cible = cp.id
	if not e.cible.is_empty():
		var c: Dictionary = entites.get(e.cible, {})
		if c.is_empty() or not c.vivant:
			e.cible = ""
		else:
			if voit_ia(e, c):
				e.tick_derniere_vue = tick
				e.pos_connue = c.pos
			elif tick - int(e.tick_derniere_vue) > int(regles.r.engagement.ia_ticks_sans_vue):
				e.cible = ""   # semée : la cible s'est dérobée assez longtemps (Discrétion, nuit, obstacle)
			if Grille.distance(e.pos, e.ancre) > int(regles.r.engagement.ia_distance_ancre):
				e.cible = ""
	if e.cible.is_empty():
		var meilleure := {}
		var dmin := 1 << 30
		for autre in vivants():
			if not ennemis(e, autre):
				continue
			var d := Grille.distance(e.pos, autre.pos)
			if d < dmin and voit_ia(e, autre):
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
	# Types d'ennemis (Créatures, 2026-08-30) : le tireur recule au contact, le soigneur / l'invocateur soutient,
	# l'embusqueur guette tant que la cible est loin. Seuls les profils qui pondèrent ces considérations les voient.
	var ia_r: Dictionary = regles.r.get("ia", {})
	if a_cible and Grille.distance(e.pos, cible.pos) <= int(ia_r.get("reculer_distance", 1)) and _a_action_a_distance(e):
		c["reculer"] = {"cible_au_contact": 1.0}
	if not _meilleur_soutien(e).is_empty():
		c["soutenir"] = {"allie_a_soutenir": 1.0}
	c.attendre["guet"] = 1.0 if (a_cible and Grille.distance(e.pos, cible.pos) > int(ia_r.get("guet_distance", 3))) else 0.0
	if e.has("maitre") and entites.has(str(e.maitre)):
		var m: Dictionary = entites[str(e.maitre)]
		var loin := Grille.distance(e.pos, m.pos) > int(regles.r.compagnons.distance_suivi)
		c["suivre"] = {"loin_du_maitre": 1.0 if (loin and str(e.get("ordre", "suivre")) == "suivre") else 0.0}
		match str(e.get("posture", "defensive")):   # Compagnons : la posture colore les considérations
			"agressive":
				if c.has("attaquer"):
					c.attaquer["posture_agressive"] = 1.0
				if c.has("poursuivre"):
					c.poursuivre["posture_agressive"] = 1.0
			"eviter":
				c.erase("attaquer")
				c.erase("poursuivre")
				if a_cible:
					c.fuir["eviter"] = 1.0 if Grille.distance(e.pos, cible.pos) <= 6 else 0.0
			_:
				if a_cible and c.has("poursuivre") and Grille.distance(cible.pos, m.pos) > 3 * int(regles.r.compagnons.distance_suivi):
					c.erase("poursuivre")   # défensive : il ne s'éloigne pas du maître pour poursuivre
	if e.ai_profile == "assaillant" and not a_cible:
		c["assaut"] = {"vers_le_coeur": 1.0}
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


## La lumière qu'un être porte (Éclairage) : le plus lumineux de ses objets en main, 0-100.
func lumiere_de(e: Dictionary) -> int:
	var lum := 0
	for slot in ["main_principale", "main_secondaire"]:
		lum = maxi(lum, int(items.get(e.get("equipement", {}).get(slot, ""), {}).get("luminosite", 0)))
	return lum


## La carte de lumière 0-15 (Éclairage) : flood fill 2D depuis les sources, −1 par tuile ; les contenus
## qui bloquent la vue reçoivent la lumière sans la propager (sauf transparence ≥ 50). Recalcul paresseux.
var carte_lumiere := PackedByteArray()
var lumiere_tick := -1
var lumiere_sale := true


func _recalculer_lumiere() -> void:
	var n := grille.largeur * grille.hauteur_grille
	carte_lumiere.resize(n)
	var ambiante := 0
	if lieu == "donjon" and not donjon.is_empty():   # Éclairage (2026-08-30) : une lueur ambiante de l'étage, le thème peut la fixer
		ambiante = clampi(int(GameData.entree("dungeon_themes", str(donjon.theme)).get("lumiere_ambiante", regles.r.get("eclairage", {}).get("donjon_ambiante", 0))), 0, 15)
	carte_lumiere.fill(ambiante)
	var file: Array[int] = []
	for gi in grille.meubles.keys():
		var l := int(GameData.entree("meubles", str(grille.meubles[gi])).get("luminosite", 0))
		if l > 0:
			var niv := clampi(roundi(float(l) / 100.0 * 15.0), 1, 15)
			if niv > carte_lumiere[int(gi)]:
				carte_lumiere[int(gi)] = niv
				file.append(int(gi))
	for e in vivants():
		var l := lumiere_de(e)
		if l > 0:
			var gi := grille.idx(e.pos)
			var niv := clampi(roundi(float(l) / 100.0 * 15.0), 1, 15)
			if niv > carte_lumiere[gi]:
				carte_lumiere[gi] = niv
				file.append(gi)
	# Propagation : file simple (les sources sont peu nombreuses, la décroissance borne le front à 15 tuiles).
	var tete := 0
	while tete < file.size():
		var gi := file[tete]
		tete += 1
		var niv := int(carte_lumiere[gi])
		if niv <= 1:
			continue
		var p := grille.pos_de(gi)
		var c := grille.contenu_de(p)
		if c.get("bloque_vue", false) and int(c.get("transparence", 0)) < 50 and not grille.meubles.has(gi):
			continue   # un mur est éclairé mais ne laisse rien passer
		for d in Grille.DIRS:
			var q: Vector2i = p + d
			if not grille.dans(q):
				continue
			var qi := grille.idx(q)
			if niv - 1 > int(carte_lumiere[qi]):
				carte_lumiere[qi] = niv - 1
				file.append(qi)
	lumiere_sale = false
	lumiere_tick = horloge_monde.ticks


## Le niveau 0-15 d'une tuile (recalcul au plus une fois par tick de monde, et seulement quand on lit).
func niveau_lumiere(pos: Vector2i) -> int:
	if lumiere_sale or lumiere_tick != horloge_monde.ticks or carte_lumiere.size() != grille.largeur * grille.hauteur_grille:
		_recalculer_lumiere()
	return int(carte_lumiere[grille.idx(pos)]) if grille.dans(pos) else 0


## La lumière locale d'une tuile, 0-100 (Éclairage) : la carte propagée, et ce que porte l'occupant.
func lumiere_a(pos: Vector2i) -> int:
	var lum := roundi(float(niveau_lumiere(pos)) * 100.0 / 15.0)
	var occ := grille.occupant(pos)
	if not occ.is_empty() and entites.has(occ):
		lum = maxi(lum, lumiere_de(entites[occ]))
	return lum


## Une IA voit-elle un être ? (portée de Perception et ligne de vue ; la nuit, la lumière locale module — Éclairage)
func voit_ia(e: Dictionary, autre: Dictionary) -> bool:
	if Etres.a_statut_tag(autre, "dissimule", statuts_defs) and Grille.distance(e.pos, autre.pos) > int(regles.r.talents.dissimulation.vu_a):   # L'Ombre
		return false
	var portee := float(e.corps.stats.perception) * float(regles.r.engagement.detection_par_perception)
	if lieu == "camp" and est_nuit() and not ("vision_nocturne" in e.get("tags_acquis", [])):
		var lum := lumiere_a(autre.pos)
		if lum <= 0:
			portee *= float(_cycle().get("vision_nuit", 0.6))
		else:
			portee *= 1.0 + float(lum) / 100.0 * float(regles.r.engagement.get("lumiere_detection", 0.5))
	if "pas_silencieux" in autre.get("tags_acquis", []):   # Effets d'équipement : détecté de moins loin
		portee *= float(regles.r.effets_equipement.silence_mult)
	portee *= 1.0 - discretion_reduction(autre)   # IA des créatures : la Discrétion de la cible raccourcit le cône
	portee *= float(Etres.mult_statuts(e, "detection", statuts_defs))   # Aveuglement : l'observateur ne voit plus
	if not zones_sur(autre.pos, "brume").is_empty() or not zones_sur(e.pos, "brume").is_empty():
		return false   # Voile de brume : ni vu, ni voyant
	return Grille.distance(e.pos, autre.pos) <= maxi(int(regles.r.engagement.get("portee_min", 1)), int(portee)) and grille.ligne_de_vue(e.pos, autre.pos)


## Ce que la Discrétion d'un être retire à la portée à laquelle on le repère (IA des créatures) : 0 à
## `discretion_max_pct`. La nuit vaut `cycle.discretion_nuit` niveaux de plus ; en garde, on ne se cache pas.
func discretion_reduction(e: Dictionary) -> float:
	var en: Dictionary = regles.r.engagement
	if bool(e.get("garde", false)):
		return 0.0
	var niveau := float(regles.niveau(e.get("competences_eff", {}), "discretion"))
	if est_nuit():
		niveau += float(_cycle().get("discretion_nuit", 4))
	return minf(float(en.get("discretion_max_pct", 0.6)), niveau * float(en.get("discretion_par_niveau", 0.02)))


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
	if _ia_par_portail(e, cible, tick):
		return
	if Grille.distance(e.pos, cible) <= int(GameData.config("planete").routine.astar_sous):
		var chemin := grille.chemin(e.pos, cible, Etres.est_volant(e), "", refuse_nage(e))
		if chemin.size() > 0:
			if _deplacer(e, chemin[0], tick):
				return
	var meilleur: Vector2i = e.pos
	var dmin := Grille.distance(e.pos, cible)
	var rn := refuse_nage(e)   # l'eau refuse la surcharge : le pas glouton ne la propose pas
	for d in Grille.DIRS:
		var q: Vector2i = e.pos + d
		if grille.dans(q) and not grille.bloque_passage(q) and grille.occupant(q).is_empty() and not grille.dangers.has(grille.idx(q)) and not (rn and dans_l_eau(q) and not dans_l_eau(e.pos)) and Grille.distance(q, cible) < dmin:
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
		if a.is_empty() or _est_soutien(a) or not _action_creature_possible(e, a, cible):
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
	if _ia_par_portail(e, but, tick):   # Talents de classe : une brèche ouverte sert à tout le monde
		return
	var pas := grille.chemin(e.pos, but, Etres.est_volant(e), ignorer, refuse_nage(e))
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
		if grille.cout_pas(e.pos, v, Etres.est_volant(e), refuse_nage(e)) < 0 or not grille.occupant(v).is_empty():
			continue
		var dist := Grille.distance(v, cible.pos)
		if dist > dmax:
			dmax = dist
			meilleur = v
	if meilleur == e.pos or not _deplacer(e, meilleur, tick):
		_attendre(e, tick)
