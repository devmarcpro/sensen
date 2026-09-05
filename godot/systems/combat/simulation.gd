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
var grille_sort: GrilleSort                  # la grille de composition (Six types de modules, 2026-09-03)
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
var gouffres_vides: Dictionary = {}  # "<id de gouffre>|<etage>" → true : un etage vide le reste POUR TOUJOURS (designer 2026-09-02)
## Ce qu'on a creusé dans une mine : "<id de mine>|<etage>" → [index de tuiles]. Une mine est un
## OUVRAGE, pas une excursion ([[Mine sous une cellule]]) : l'espace qu'on a ouvert reste ouvert, d'une
## visite à l'autre et d'une session à l'autre. On ne stocke pas la grille — elle est déterministe —
## seulement la LISTE de ce qu'on a enlevé, ce qui tient dans quelques centaines d'entiers.
var mines_creusees: Dictionary = {}
var nom_partie := ""                 # l'emplacement de CETTE partie (designer 2026-09-02) : plusieurs parties, une sauvegarde chacune
var prochain_donjon: int = 1         # id du prochain donjon lancé depuis le camp
var monde: Monde = null              # la surface comme fenêtre glissante (étape 8.2a)
var bombes: Array = []               # les bombes posées, en attente d'explosion (Explosions)
var affuts: Array[Dictionary] = []   # tourelles portatives de L'Engrenage : {pos, source, prochain}
var pluie_heure := -1   # la dernière heure de monde où la pluie a rempli les creux
var foudre_heure := -1   # la dernière heure d'orage où la foudre a frappé (Météo)
var evapo_heure := -1   # la dernière heure de canicule où les flaques ont baissé
var peremption_heure := -1   # la dernière heure où le butin de mort périmé a été balayé (Mort et pénalité)
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
## La forme d'un territoire (Villes — B0, 2026-09-05) : celle du royaume du joueur (étape 10). Une ville générée en a
## une aussi, avec son propriétaire (l'id de son royaume, ou « joueur » quand il la contrôle) et ses cellules à rôle —
## « un camp et une ville sont identiques, seule différence c'est que la ville est générée » (designer).
static func territoire_vide(id: String = "joueur", proprietaire: String = "joueur") -> Dictionary:
	var t := {"tresor": 0, "dette": 0, "semaines_dette": 0, "stocks": {}, "rapports": [], "gains_quetes": 0, "royaume": false,
	"cultures": {}, "fertilite": {}, "etals": {}, "caisse": 0, "marge": 1.0, "clients": 0.0, "heure_resolue": -1, "absence": {"ventes": 0, "or": 0, "mures": 0},
	"gouvernance": "", "gouvernance_cible": "", "transition": 0, "raid": {}, "dernier_raid": {}, "accords": {}}
	t["id"] = id
	t["proprietaire"] = proprietaire
	t["cellules"] = {}   # le joueur : le même dictionnaire que monde.claims ; une ville : ses cellules à rôle
	return t


var territoire: Dictionary = territoire_vide()   # le territoire COURANT : le joueur, ou une ville qu'il contrôle et où il se tient (Villes B0)
var territoires: Dictionary = {}                 # id → territoire : « joueur » et les villes générées (Villes B0)
var chrono: Dictionary = {}                      # étape → ms cumulées de la dernière semaine (les sondes le lisent : Budgets de performance)


func _top(cle: String, t0: int) -> int:
	chrono[cle] = float(chrono.get(cle, 0.0)) + float(Time.get_ticks_usec() - t0) / 1000.0
	return Time.get_ticks_usec()
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
var identifies: Dictionary = {}      # bases d'objets révélées dans cette partie (identification, point 52)
var planete_options: Dictionary = {}   # config planete surchargée par l'écran Monde (designer, point 49)
var graine_monde := -1   # la graine du monde choisie à l'écran Monde (Écrans d'interface) ; -1 = celle de planete.json


func _init(p_graine: int) -> void:
	graine = p_graine
	des = Des.new(p_graine)
	regles = Regles.new(GameData.config("combat_rules"))
	wuxing = WuXing.new(GameData.config("wuxing"))
	capacites = Capacites.new(GameData.catalogues.get("modules", {}))
	grille_sort = GrilleSort.new(regles.r.get("grille", {}), GameData.catalogues.modules, GameData.catalogues.get("grilles", {}))
	territoires["joueur"] = territoire
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
	if nom != "monde" and not combats.has(nom):   # un combat dissous par le pas précédent (le client itère sur une copie des noms)
		return false
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
	if e.has("saisi_par") and SimTalents._ia_se_debattre(self, e, h.ticks):
		_fin_de_pas(nom)
		return true
	var t0 := Time.get_ticks_usec()
	_decider_ia(e, h.ticks)
	t0 = _top("pas.decider", t0)
	_fin_de_pas(nom)
	_top("pas.fin", t0)
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
	SimCamp._consommer_pile(self, e, it)
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
			if Grille.distance(pos, ft) <= R and grille.dans(ft) and rng_feu.randf() < float(SimTerrain.flammabilite_de(self, ft)) / 100.0:
				SimTerrain._enflammer(self, ft)
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
						var brut: Dictionary = SimObjets.generer_objet(self, "materiau_brut", 1, {}, "commun", 0)
						if not brut.is_empty():
							brut.materiau = mat_id
							brut["forme"] = "brut"
							brut.quantite = 1
							SimObjets._poser_contenant(self, t, [brut.uid], "butin")
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
	if not lanceur.is_empty() and SimTalents.a_talent(self, lanceur, "chaine_d_amorces"):
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
	var t0 := Time.get_ticks_usec()
	if not _dans_avancee_monde:
		_dans_avancee_monde = true
		var garde_fou := 64
		while garde_fou > 0 and (horloge_monde.mode == Horloge.Mode.TEMPS_REEL or _du_sur_monde()) and pas("monde"):
			garde_fou -= 1
		_dans_avancee_monde = false
	t0 = _top("pas", t0)
	_tiquer_faim(horloge_monde.ticks)
	t0 = _top("faim", t0)
	_tiquer_monde(horloge_monde.ticks)
	t0 = _top("monde", t0)
	SimCamp._tiquer_territoire(self, horloge_monde.ticks)
	SimVilles._tiquer_transports(self, horloge_monde.ticks)
	t0 = _top("territoire", t0)
	SimRoyaumes._tiquer_raid(self, horloge_monde.ticks)
	SimTerrain._tiquer_meteo(self, horloge_monde.ticks)
	t0 = _top("raid_meteo", t0)
	_tiquer_faune(horloge_monde.ticks)
	_top("faune", t0)


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
	var nuit: bool = SimTerrain.est_nuit(self)
	if rng.randf() > float(fa.chance_base) * (float(fa.nuit_mult) if nuit else 1.0) * densite_faune(j.pos):
		return   # une clairière qu'on a vidée se repeuple moins (Créatures, 2026-09-04)
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
				var x: Dictionary = SimObjets.ajouter(self, choix, pos, "ia")
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
	SimTerritoire._maj_contexte(self)   # le territoire courant suit le joueur (Villes B0)
	monde.jour_monde = SimVilles.jour_courant(self)   # `foyer()` s'allume sur les donjons de corruption : il lui faut le jour
	if monde.jour_monde != _jour_annonce:
		SimVilles._nouveau_jour(self, monde.jour_monde)
	var semaine := tick / int(cr.ticks_par_semaine)
	while monde.semaine_courante < semaine:
		monde.semaine_courante += 1
		var touchees := monde.semaine(tick)
		var derive := int(regles.r.reputation.derive_hebdo)
		var t0 := Time.get_ticks_usec()
		SimPnj._vieillir_semaine(self, tick)
		t0 = _top("vieillir", t0)
		SimRoyaumes._semaine_royaumes_pnj(self)
		SimRoyaumes._semaine_royaumes_pays(self)   # chaque royaume connu vit sa semaine : humeur, événements, guerres (D)
		t0 = _top("royaumes_pnj", t0)
		SimElevage._semaine_elevage(self)
		t0 = _top("elevage", t0)
		for x in entites.values():
			if x.controle == "joueur":
				SimTerritoire._dans_territoire(self, "joueur", func() -> void: SimTerritoire._semaine_joueur(self, x))
		t0 = _top("joueur", t0)
		SimTerritoire._semaine_villes(self)   # chaque ville chargée vit la même semaine, dans son contexte (Villes B0)
		t0 = _top("villes", t0)
		SimTerrain._regenerer_terrain_sauvage(self)
		_regenerer_faune_hebdo()
		t0 = _top("regeneration", t0)
		for x in entites.values():   # les bourses des PNJ se rechargent (+15 % par semaine, Barèmes économiques)
			if x.has("or_max"):
				x.or = mini(int(x.or_max), int(x.or) + int(ceil(float(x.or_max) * float(regles.r.commerce.recharge_hebdo))))
			# … et le marchand se réapprovisionne : un stock vidé par le joueur revient la semaine suivante.
			SimObjets._reapprovisionner(self, x)
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


## Une bête PAISIBLE de la faune : proie, fuyarde ou bête sauvage — pas le loup qui chasse la nuit.
static func est_faune_paisible(x: Dictionary) -> bool:
	return str(x.get("ai_profile", "")) in ["proie", "fuyard", "bete_sauvage"]


## La densité de faune de la cellule de `pos` : 1 sauf si la chasse l'a raréfiée (Monde.faune_densite).
func densite_faune(pos: Vector2i) -> float:
	if monde == null:
		return 1.0
	return float(monde.faune_densite.get(monde.cellule_de(pos), 1.0))


## Une bête paisible tuée par le joueur : la faune de sa cellule se raréfie, jusqu'au plancher.
func _rarefier_faune(pos: Vector2i) -> void:
	if monde == null:
		return
	var ra: Dictionary = GameData.config("planete").faune.get("rarefaction", {})
	var cell := monde.cellule_de(pos)
	monde.faune_densite[cell] = maxf(float(ra.get("plancher", 0.25)), float(monde.faune_densite.get(cell, 1.0)) - float(ra.get("par_mort", 0.15)))


## Le passage hebdomadaire : la faune revient par génération, jamais par reproduction (Créatures, 2026-09-04).
func _regenerer_faune_hebdo() -> void:
	if monde == null:
		return
	var retour := float(GameData.config("planete").faune.get("rarefaction", {}).get("retour_hebdo", 0.05))
	for cell in monde.faune_densite.keys().duplicate():
		var d := float(monde.faune_densite[cell]) + retour
		if d >= 1.0:
			monde.faune_densite.erase(cell)
		else:
			monde.faune_densite[cell] = d


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
			# La faim tue (designer 2026-09-01, point 52) : plus de plancher à 1 PV — la famine va
			# jusqu'au bout, et le compte à rebours de la nourriture redevient une vraie horloge.
			var pz := int(f.periode_zero)
			var coups := tick / pz - int(e.faim_tick) / pz
			if coups > 0 and not (invincible and e.controle == "joueur"):   # la triche « invincible » vaut aussi contre la famine (2026-09-04)
				var degats := coups * maxi(int(f.get("degats_par_palier", 2)), int(e.sante_max) * int(f.pct_sante_max) / 100)
				e.sante = int(e.sante) - degats
				EventBus.emettre(&"journal", [&"journal.famine", {"nom": e.name_key, "n": degats}])
				if int(e.sante) <= 0 and e.vivant:   # mort de faim : la même sortie que la mort au combat
					e.sante = 0
					e.vivant = false
					grille.liberer(e.pos)
					EventBus.emettre(&"journal", [&"journal.mort", {"nom": e.name_key}])
					EventBus.emettre(&"creature_killed", [e.id, e.id])
		e.faim_tick = tick


## Le poids porté et la capacité d'un être (Armures et poids porté).
func poids_de(e: Dictionary) -> Dictionary:
	var total := 0.0
	for uid in e.sac:
		total += regles.poids_objet(items.get(uid, {}), fonctionnalites)
	for slot in e.equipement.keys():
		total += regles.poids_objet(items.get(e.equipement[slot], {}), fonctionnalites)
	var cap := regles.capacite_poids(e.stats_eff) + float(e.get("mecaniques", {}).get("capacite_poids", {}).get("n", 0))
	if SimTalents.a_talent(self, e, "sans_chair"):   # le Spectre : capacité fixe
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
	SimObjets.identifier(self, it)   # goûter, c'est identifier (designer 2026-09-01, point 52)
	if "potion" in it.get("tags", []):   # les serments d'abstinence se rompent sur l'ACTE, pas sur l'état
		rompre_serment(e, "sobriete")
	if "viande" in it.get("tags", []):   # le tag fait foi (l'audit refuse un tag que rien ne porte)
		rompre_serment(e, "vegetarien")
	if SimTalents.a_talent(self, e, "soif_de_sang") and "plat" in it.get("tags", []):   # le Vampire ne mange plus de plats
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
	if not str(it.get("soin_des", "")).is_empty() and not SimTalents.a_talent(self, e, "sans_chair"):   # le Spectre ne se soigne que par mana
		var soin := des.jet(str(it.soin_des))
		e["sang"] = 0
		e.sante = mini(e.sante_max, int(e.sante) + soin)
		extra.append("+%d PV" % soin)
	if int(it.get("mana", 0)) > 0:
		e.mana = mini(e.mana_max, int(e.mana) + int(it.mana))
		extra.append("+%d mana" % int(it.mana))
	var statut := str(it.get("statut", ""))
	if "illegal" in statuts_defs.get(statut, {}).get("tags", []) and lieu == "camp":   # poison de lame : l'usage est une infraction là où c'est illégal
		SimRoyaumes._infraction(self, e, "objet", str(it.get("base", "")), e.pos, uid)
	if statut.begins_with("purge:"):
		var cible := statut.trim_prefix("purge:")
		e.statuts = e.statuts.filter(func(s: Dictionary) -> bool: return str(s.id) != cible)
		EventBus.emettre(&"journal", [&"journal.purge", {"nom": e.name_key, "statut": "status.%s.name" % cible}])
	elif statut == "huile_feu":
		e["huile_feu"] = true
		EventBus.emettre(&"journal", [&"journal.huile", {"nom": e.name_key}])
	elif not statut.is_empty():
		appliquer_statut(e, statut, int(float(it.get("statut_ticks", 0)) * float(it.get("qualite", 1.0))), e.id, float(it.get("puissance", 1.0)))
		if "potion" in it.get("tags", []) and SimTalents.a_talent(self, e, "fiole_vive"):   # Fiole vive (Talents de classe) : les alliés adjacents aussi
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
	EventBus.emettre(&"journal", [&"journal.mange", {"nom": e.name_key, "objet": SimObjets.nom_objet(self, uid) if items.has(uid) else {"base": it.name_key}, "faim": int(e.faim), "extra": (" · " + " · ".join(extra)) if not extra.is_empty() else ""}])
	return true


## Brouillard de guerre (Minimap et brouillard de guerre) : le champ de vue de chaque être contrôlé
## par un joueur — portée Perception × detection_par_perception, ligne de vue — est recalculé et
## mémorisé sur la grille (`decouvert`). `e.vue` : index de tuile → true ; `e.vue_version` change
## quand le champ change (le client redessine le terrain sur ce signal).
var _vision_tick := -1          # la vision du joueur se calcule une fois par tick : un pas de PNJ ne change pas ce qu'il voit
var _vision_grille: Grille = null


func maj_vision() -> void:
	for e in vivants():
		if e.controle != "joueur":
			continue
		var t_now := horloge_de(e).ticks
		if _vision_tick == t_now and _vision_grille == grille and e.has("vue") and e.get("vue_pos", Vector2i(-1, -1)) == e.pos and not bool(e.get("vue_sale", false)):
			continue   # déjà calculée à ce tick, au même endroit, sur la même grille (Villes B1 : 218 êtres, dix pas par tick)
		_vision_tick = t_now
		_vision_grille = grille
		var portee := int(float(e.stats_eff.perception) * float(regles.r.engagement.detection_par_perception))
		if SimTalents.a_talent(self, e, "oeil_de_la_pierre"):
			portee = maxi(1, roundi(float(portee) * float(regles.r.talents.oeil_de_la_pierre.vision_mult)))
		if lieu == "camp" and monde != null:
			var facteur := 1.0
			if SimTerrain.est_nuit(self) and not ("vision_nocturne" in e.get("tags_acquis", [])):
				facteur *= maxf(float(SimTerrain._cycle(self).get("vision_nuit", 0.6)), float(lumiere_de(e)) / 100.0)   # la nuit : malus de vision, sauf une lumière en main (Éclairage)
			var etat: Dictionary = GameData.catalogues.weather_states.get(str(e.get("meteo_locale", SimTerrain.meteo(self, monde.cellule_de(e.pos)))), {})
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
					SimPnj._progresser_quetes(self, e, "explorer", [])
		e["vue"] = vue
		e["vue_pos"] = e.pos
		e["vue_sale"] = false


## Un être voit-il la tuile `t` ? (les êtres sans champ de vue calculé — IA — voient tout : leur
## détection a sa propre règle)
func voit(e: Dictionary, t: Vector2i) -> bool:
	return not e.has("vue") or e.vue.has(grille.idx(t))


func _fin_de_pas(nom: String) -> void:
	var vs := vivants()   # une seule liste par fin de pas (une ville : deux cents êtres, dix pas par tick)
	for e in vs:
		if e.controle == "joueur":
			SimLieux._verifier_fenetre(self, e)
	var t0 := Time.get_ticks_usec()
	maj_vision()
	_top("fin.vision", t0)
	for e in vs:   # fin du buff Reposé
		if e.has("repose_jusqua") and int(e.repose_jusqua) <= horloge_de(e).ticks:
			e.erase("repose_jusqua")
			e["xp_mult"] = 1.0
	# Phase 2 (Boucle de tick) : les statuts de tous les êtres de cette horloge.
	var h: Horloge = horloge_monde if nom == "monde" else combats.get(nom, {}).get("horloge", horloge_monde)
	for e in vs:
		if e.horloge == nom and not e.statuts.is_empty():
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
			SimTalents._oublier_glyphe(self, gl.pos)   # expiré : la marque au sol s'efface
	glyphes = g_restants
	SimLieux._tiquer_zones(self, tick)
	for x in vivants():   # les relevés du Fossoyeur retournent à la terre
		if x.has("fin_invocation") and x.horloge == nom and int(x.fin_invocation) <= tick:
			x.vivant = false
			grille.liberer(x.pos)
			EventBus.emettre(&"journal", [&"journal.releve_fin", {"nom": x.name_key}])
	SimTalents._tirs_d_affuts(self, nom, tick)
	SimTerrain._maj_etats_meteo(self)
	if nom == "monde":
		if tick >= eau_prochain_pas:
			SimTerrain._tiquer_courant(self, tick)
		SimTerrain._tiquer_eau(self, tick)
		SimTerrain._tiquer_lave(self, tick)
		SimTerrain._tiquer_feux(self, tick)
		var h_per := int(SimTerrain._cycle(self).get("ticks_par_jour", 24000)) / 24
		if tick / h_per != peremption_heure:
			peremption_heure = tick / h_per
			SimObjets._perimer_butin(self, tick)
		var h_ticks := int(SimTerrain._cycle(self).get("ticks_par_jour", 24000)) / 24
		if lieu == "camp" and monde != null:
			var met: String = SimTerrain.meteo(self, monde.cellule_de(grille.pos_de(grille.largeur * grille.hauteur_grille / 2)))
			if tick / h_ticks != pluie_heure and met in ["pluie", "orage"]:   # l'orage arrose aussi
				pluie_heure = tick / h_ticks
				SimTerrain._pluie(self, tick)
			if tick / h_ticks != foudre_heure and met == "orage":   # Météo : la foudre réelle
				foudre_heure = tick / h_ticks
				SimTerrain._foudre(self, tick)
			if tick / h_ticks != evapo_heure and "evapore" in GameData.catalogues.weather_states.get(met, {}).get("effects", []):
				evapo_heure = tick / h_ticks
				SimTerrain._evaporation(self)
			if tick / h_ticks != canicule_heure and "ignition" in GameData.catalogues.weather_states.get(met, {}).get("effects", []):
				canicule_heure = tick / h_ticks
				SimTerrain._ignition_canicule(self, tick)
			if tick / h_ticks != arrachage_heure and "arrache_fragiles" in GameData.catalogues.weather_states.get(met, {}).get("effects", []):
				arrachage_heure = tick / h_ticks
				SimTerrain._arrachage(self, tick)
	SimTalents._tiquer_vampires(self, nom, tick)
	SimTalents._tiquer_armes_fantomes(self, nom, tick)
	SimTerrain._tiquer_souffle(self, nom, tick)
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
		SimTalents._oublier_glyphe(self, pos)
		if src.is_empty():
			continue
		EventBus.emettre(&"journal", [&"journal.glyphe_declenche", {"nom": entrant.name_key, "source": src.name_key}])
		var charge: Dictionary = gl.plan.duplicate()
		charge.geometrie = "point"   # la charge au sol frappe celui qui entre
		_executer_capacite(src, charge, pos, true)


## Régénération d'endurance : +2 par tick écoulé depuis la dernière application (Endurance).
func _regenerer(e: Dictionary, tick: int) -> void:
	var ecoules := tick - int(e.tick_vigueur)
	if ecoules > 0:
		# Récupération (designer 2026-09-01) : le pendant de Méditation pour l'endurance — le niveau
		# augmente le gain par tick, et l'usage entraîne, mais seulement si le corps regagne vraiment.
		var nv_rec := regles.niveau(e.get("competences_eff", e.get("competences", {})), str(regles.r.vigueur.get("competence", "recuperation")))
		var regen := int(round(float(ecoules) * float(regles.r.vigueur.regen_par_tick) * (1.0 + float(nv_rec) * float(regles.r.vigueur.get("regen_par_niveau", 0.0)))))
		if float(e.get("ecart_confort", 0.0)) != 0.0:
			regen = int(float(regen) * float(GameData.config("planete").get("meteo", {}).get("vigueur_regen_hors_confort", 0.5)))
		var avant_end: int = e.vigueur
		e.vigueur = mini(e.vigueur_max, e.vigueur + regen)
		if e.vigueur > avant_end:   # on ne s'entraîne pas à récupérer quand on est déjà au maximum
			var per_r := maxi(1, int(regles.r.vigueur.get("xp_periode_ticks", 20)))
			var tr_r := tick / per_r - int(e.tick_vigueur) / per_r
			if tr_r > 0:
				gagner_xp(e, str(regles.r.vigueur.get("competence", "recuperation")), tr_r)
		# Mana (A.5) : à chaque tranche de 10 ticks franchie, 1 chance sur 8 de rendre 1 + N_meditation × 0.2.
		var periode := int(regles.r.mana.periode_ticks)
		var tranches := tick / periode - int(e.tick_vigueur) / periode
		for i in tranches:
			if des.reel() < float(regles.r.mana.chance):
				e.mana = mini(e.mana_max, e.mana + roundi((float(regles.r.mana.regen_base) + float(e.competences_eff.get("meditation", 0)) * float(regles.r.mana.regen_par_meditation)) * (float(regles.r.talents.chair_de_mana.mana_regen_mult) if SimTalents.a_talent(self, e, "chair_de_mana") else 1.0)))
				gagner_xp(e, "meditation", 1)
		# Sang-froid : l'inverse des deux autres monnaies. Hors combat elle revient seule ; EN combat
		# elle ne monte que si le corps est immobile depuis `seuil_ticks` — celui qui se replace perd
		# son sang-froid, celui qui tient sa ligne le construit. On réutilise `immobile_depuis`, que la
		# canalisation et Pied ferme lisent déjà : un seul compteur d'immobilité pour tout le jeu.
		var sf_r: Dictionary = regles.r.get("sang_froid", {})
		var immobile_sf := tick - int(e.get("immobile_depuis", tick))
		if not en_combat(e) or immobile_sf >= int(sf_r.get("seuil_ticks", 6)):
			e["sang_froid"] = mini(int(e.get("sang_froid_max", 0)), int(e.get("sang_froid", 0)) + int(round(float(ecoules) * float(sf_r.get("regen_par_tick", 1)))))
		var f_faim: Dictionary = regles.r.faim
		var faim_e := int(e.get("faim", 100))
		if e.get("mecaniques", {}).has("regen_sante") and not en_combat(e) and faim_e >= int(f_faim.seuil_stats):   # Effets d'équipement : 1 PV toutes les 200 × 100 / pct ticks ; Faim : plus de régén sous seuil_stats
			var pct_regen := float(e.mecaniques.regen_sante.get("pct", 50))
			if faim_e < int(f_faim.seuil_regen):
				pct_regen *= float(f_faim.get("malus_regen", 0.9))   # Faim < 50 : −10 % de régénération
			var per := maxi(1, roundi(float(regles.r.effets_equipement.regen_base_ticks) * 100.0 / pct_regen))
			var pv := tick / per - int(e.tick_vigueur) / per
			if pv > 0:
				e.sante = mini(e.sante_max, int(e.sante) + pv)
	e.tick_vigueur = tick


# ---------------------------------------------------------------- intentions (client → serveur)

## Une intention pour l'entité `id`, qui doit être en attente. Valide, exécute, retourne
## vrai si elle a été consommée. Types : deplacer{vers} · attaquer{cible, lourde} · garde · attendre.
func intention(id: String, i: Dictionary) -> bool:
	if str(i.get("type", "")) == "respawn" and entites.has(id):
		return SimObjets._respawn(self, entites[id])   # un mort n'attend rien : le respawn passe hors de la file
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
		"parchemin":   # lire un parchemin : le sort part gratuitement, une charge en moins (2026-09-02)
			ok = _lire_parchemin(e, str(i.get("objet", "")), i.get("cible", Vector2i(-1, -1)), h.ticks)
		"attaquer":
			if entites.has(i.cible):
				ok = SimTalents._attaquer_bete(self, e, entites[i.cible], h.ticks) if (bool(e.get("forme_bestiale", false)) or (Etres.arme(e, items).is_empty() and not e.get("actions", []).is_empty())) else _attaquer_arme(e, entites[i.cible], bool(i.get("lourde", false)), h.ticks)
		"transformer":
			ok = SimTalents._transformer(self, e, h.ticks)
		"incarner":
			ok = SimTalents._incarner(self, e, str(i.get("pnj", "")), h.ticks)
		"arme_fantome":
			ok = SimTalents._invoquer_arme_fantome(self, e, str(i.get("element", "")), h.ticks)
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
			if SimLieux._descendre(self, e):
				EventBus.dispatcher()
				return true   # la grille a changé : plus rien à finir sur l'ancienne
		"remonter":
			if SimLieux._remonter(self, e):
				EventBus.dispatcher()
				return true
		"creuser":
			ok = SimTerrain._creuser(self, e, i.get("vers", Vector2i(-1, -1)), h.ticks)
		"puits":   # creuser un puits : ouvrir la mine, ou descendre d'un étage (Mine sous une cellule)
			if SimLieux.creuser_un_puits(self, e, h.ticks):
				EventBus.dispatcher()
				return true   # la grille a changé : plus rien à finir sur l'ancienne
		"cueillir":
			ok = SimTerrain._cueillir(self, e, i.get("vers", Vector2i(-1, -1)), h.ticks)
		"terrasser":
			ok = SimTerrain._terrasser(self, e, i.get("vers", Vector2i(-1, -1)), int(i.get("sens", -1)), h.ticks)
		"equiper":
			ok = SimObjets._equiper(self, e, str(i.get("objet", "")), h.ticks)
		"ramasser":
			ok = SimObjets._ramasser(self, e, h.ticks)
		"respawn":
			ok = SimObjets._respawn(self, e)
		"sertir":
			ok = SimObjets._sertir(self, e, str(i.get("objet", "")), str(i.get("gemme", "")), h.ticks)
		"lire":
			ok = SimObjets._lire(self, e, str(i.get("objet", "")), h.ticks)
		"fabriquer":
			ok = SimFabrication._fabriquer(self, e, str(i.get("recette", "")), h.ticks)
		"desequiper":
			ok = SimObjets._desequiper(self, e, str(i.get("slot", "")), h.ticks)
		"poser":
			ok = SimCamp._poser(self, e, str(i.get("objet", "")), i.get("vers", Vector2i(-1, -1)), h.ticks)
		"poser_mur":
			ok = SimCamp._poser_mur(self, e, i.get("vers", Vector2i(-1, -1)), false, h.ticks)
		"poser_porte":
			ok = SimCamp._poser_mur(self, e, i.get("vers", Vector2i(-1, -1)), true, h.ticks)
		"porte":   # ouvrir / fermer une porte adjacente
			ok = _basculer_porte(e, i.get("vers", Vector2i(-1, -1)), h.ticks)
		"demonter":
			ok = SimCamp._demonter(self, e, i.get("vers", Vector2i(-1, -1)), h.ticks)
		"ranger":
			ok = SimCamp._ranger(self, e, str(i.get("objet", "")), i.get("vers", Vector2i(-1, -1)), h.ticks)
		"prendre":
			ok = SimCamp._prendre(self, e, i.get("vers", Vector2i(-1, -1)), h.ticks)
		"dormir":
			ok = SimCamp._dormir(self, e, i.get("vers", Vector2i(-1, -1)), h.ticks)
		"manger":
			ok = _manger(e, str(i.get("objet", "")), h.ticks)
		"parler":
			if str(e.corps.get("silhouette", "humanoide")) != "humanoide":
				EventBus.emettre(&"journal", [&"journal.monde_muet", {}])
			elif bool(e.get("forme_bestiale", false)):
				EventBus.emettre(&"journal", [&"journal.bete_refus", {}])
			else:
				ok = SimPnj._parler(self, e, str(i.get("pnj", "")), h.ticks)
		"acheter":
			ok = SimPnj._acheter(self, e, str(i.get("pnj", "")), str(i.get("objet", "")), h.ticks)
		"vendre":
			ok = SimPnj._vendre(self, e, str(i.get("pnj", "")), str(i.get("objet", "")), h.ticks)
		"accepter_quete":
			ok = SimPnj._accepter_quete(self, e, str(i.get("pnj", "")), str(i.get("quete", "")), h.ticks)
		"offrir":
			ok = SimPnj._offrir(self, e, str(i.get("pnj", "")), str(i.get("objet", "")), h.ticks)
		"monter":
			ok = SimVilles._monter(self, e, str(i.get("pnj", "")), i, h.ticks)
		"descendre_monture":
			ok = SimVilles._descendre_monture(self, e, h.ticks)
		"acheter_monture":
			ok = SimVilles._acheter_monture(self, e, str(i.get("pnj", "")), h.ticks)
		"recruter":
			ok = SimPnj._recruter(self, e, str(i.get("pnj", "")), h.ticks)
		"engager":
			ok = SimPerimetres._engager(self, e, str(i.get("pnj", "")), h.ticks)
		"assigner":
			ok = SimTerritoire._assigner(self, e, str(i.get("pnj", "")), str(i.get("fonction", "")), h.ticks, str(i.get("perimetre", "")))
		"conquerir":
			ok = SimRoyaumes._conquerir(self, e, i.get("vers", e.pos), h.ticks)
		"capturer":
			ok = SimElevage._capturer(self, e, h.ticks)
		"entrainer":
			ok = SimElevage._entrainer(self, e, str(i.get("pnj", "")), str(i.get("competence", "")), h.ticks)
		"apprendre_talent":
			ok = SimTalents._apprendre_talent(self, e, str(i.get("pnj", "")), h.ticks)
		"reforger":
			ok = SimTalents._reforger(self, e, str(i.get("objet", "")), str(i.get("composant", "")), h.ticks)
		"lancer":
			ok = _lancer(e, str(i.get("objet", "")), i.get("cible", e.pos), h.ticks)
		"statut_habitat":
			ok = SimTerritoire._statut_habitat(self, e, str(i.get("pnj", "")), str(i.get("statut", "normal")), h.ticks)
		"saisir":
			ok = SimTalents._saisir(self, e, str(i.get("cible", "")), h.ticks)
		"poser_portail":
			ok = SimTalents._poser_portail(self, e, i.get("cible", e.pos), h.ticks)
		"boire_source":
			ok = SimTalents._rituel_race(self, e, i.get("vers", Vector2i(-1, -1)), "source_maudite", h.ticks)
		"rituel":
			ok = SimTalents._rituel_race(self, e, i.get("vers", Vector2i(-1, -1)), "autel_rituel", h.ticks)
		"traverser":
			ok = SimTalents._traverser(self, e, h.ticks)
		"masque":
			ok = SimTalents._porter_masque(self, e, str(i.get("masque", "")), h.ticks)
		"relever":
			ok = SimTalents._relever(self, e, str(i.get("cible", "")), h.ticks)
		"mordre":
			ok = SimTalents._mordre(self, e, str(i.get("cible", "")), h.ticks)
		"traverser_mur":
			ok = SimTalents._traverser_mur(self, e, i.get("cible", e.pos), h.ticks)
		"affut":
			ok = SimTalents._deployer_affut(self, e, i.get("cible", e.pos), h.ticks)
		"declencher_glyphe":
			ok = SimTalents._declencher_glyphe_distance(self, e, i.get("cible", e.pos), h.ticks)
		"tempo":
			ok = SimTalents._voler_tempo(self, e, str(i.get("cible", "")), h.ticks)
		"lancer_etre":
			ok = SimTalents._lancer_etre(self, e, i.get("vers", e.pos), h.ticks)
		"livrer":
			ok = SimElevage._livrer_commande(self, e, str(i.get("pnj", "")), h.ticks)
		"planter":
			ok = SimCamp._planter(self, e, str(i.get("base", "")), h.ticks)
		"fertiliser":
			ok = SimCamp._fertiliser(self, e, i.get("vers", e.pos), h.ticks)
		"apprivoiser":
			ok = SimPnj._apprivoiser(self, e, str(i.get("cible", "")), h.ticks)
		"ressusciter":
			ok = SimPnj._ressusciter(self, e, str(i.get("ame", "")), h.ticks, str(i.get("pnj", "")))
		"rendre_quete":
			ok = SimPnj._rendre_quete(self, e, str(i.get("pnj", "")), str(i.get("quete", "")), h.ticks)
		"jeter":
			ok = SimObjets._jeter(self, e, str(i.get("objet", "")), h.ticks)
	if ok:
		attente.erase(id)
		_fin_de_pas(e.horloge)
	return ok


# ---------------------------------------------------------------- actions

## Les affixes qui allègent un pas (Loot) : « nocturne », la nuit, −pct % par pièce, jamais sous 1 tick.
func cout_pas_affixes(e: Dictionary, cout: int) -> int:
	if not SimTerrain.est_nuit(self):
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
	return monde.corruption_de(SimCamp._cell_de(self, pos))


## Déplacement d'une tuile (8 directions). Une chute volontaire (Δ ≤ −3) est autorisée : dégâts.
## Les facteurs de franchissement d'un être (designer 2026-09-01, points 56 et 57) : ce que valent
## son Escalade et sa Nage, charge comprise — grimper chargé est plus lent, nager chargé aussi.
func facteurs_franchissement(e: Dictionary) -> Dictionary:
	var comp: Dictionary = e.get("competences_eff", e.get("competences", {}))
	var charge := 1.0 / maxf(0.2, float(poids_de(e).facteur))
	var dep: Dictionary = regles.r.deplacement
	return {
		"escalade": regles.skill_factor(regles.niveau(comp, str(dep.get("escalade", {}).get("competence", "escalade")))) * charge,
		"nage": regles.skill_factor(regles.niveau(comp, str(dep.get("nage_progressive", {}).get("competence", "nage")))) * charge,
	}


func _deplacer(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	if Grille.distance(e.pos, vers) != 1 or not grille.occupant(vers).is_empty():
		return false
	if "fermee" in grille.contenu_de(vers).get("tags", []):   # une porte fermée : ce pas l'ouvre, le suivant passe
		return _basculer_porte(e, vers, tick)
	var volant := Etres.est_volant(e)
	var cout := grille.cout_pas(e.pos, vers, volant, false, facteurs_franchissement(e))
	var chute := 0
	if cout < 0:
		if not volant and grille.est_chute(e.pos, vers):
			chute = grille.h(e.pos) - grille.h(vers)
			cout = int(regles.r.deplacement.descente)
		else:
			return false
	var dh_pas := grille.h(vers) - grille.h(e.pos)   # l'usage entraîne (points 56 et 57)
	if dh_pas >= int(regles.r.deplacement.falaise_delta):
		gagner_xp(e, str(regles.r.deplacement.get("escalade", {}).get("competence", "escalade")), dh_pas)
		EventBus.emettre(&"journal", [&"journal.escalade", {"nom": e.name_key, "n": cout}])
	elif grille.nageable(vers):
		gagner_xp(e, str(regles.r.deplacement.get("nage_progressive", {}).get("competence", "nage")), 1)
	cout = cout_pas_affixes(e, cout)
	if Etres.bloque_statuts(e, "deplacement", statuts_defs):
		return false
	if SimTerrain.dans_l_eau(self, vers) and not SimTerrain.dans_l_eau(self, e.pos) and bool(regles.r.nage.get("refus_surcharge", true)) and poids_de(e).facteur > 1.0 and not volant:
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
	if e.has("monture"):   # à cheval, la marche coûte moins (Villes B4)
		ticks_dep = maxi(1, ceili(float(ticks_dep) * float(GameData.config("villes").get("transports", {}).get("montures", {}).get("facteur_vitesse", 0.5))))
	if e.get("mecaniques", {}).has("vitesse_deplacement"):   # Effets d'équipement : +pct % de vitesse
		ticks_dep = maxi(1, roundi(float(ticks_dep) / (1.0 + float(e.mecaniques.vitesse_deplacement.get("pct", 0)) / 100.0)))
	e.compteur = tick + _ticks_avec_statuts(e, ticks_dep)
	if Etres.a_statut_id(e, "brulure"):   # l'eau éteint la Brûlure (Statuts) : l'eau ne se traverse pas, s'y plonger = y arriver au bord
		for dd in Grille.DIRS:
			var q: Vector2i = vers + dd
			if grille.dans(q) and "liquide" in grille.contenu_de(q).get("tags", []):
				SimTalents._retirer_statut(self, e, "brulure")
				EventBus.emettre(&"journal", [&"journal.brulure_eteinte", {}])
				break
	_declencher_glyphe(e, vers)
	SimLieux._zones_a_l_entree(self, e, vers, tick)   # Racine, Sol vif, Nappe
	if en_combat(e):
		for autre in vivants():
			if autre.camp != e.camp and Grille.distance(autre.pos, e.pos) == 1:
				gagner_xp(e, "esquive", 1)   # la mobilité s'apprend sous le feu (Décision — Esquive active)
				_declencher(e, "derobade", e.pos)   # Dérobade : « quand le porteur esquive » = un pas sous la menace
				break
	e["immobile_depuis"] = e.compteur   # Canalisation : l'immobilité repart de zéro à chaque pas
	gagner_xp(e, "athletisme", 1)
	if e.controle == "joueur":   # le pas d'un PNJ ne s'écrit pas dans le journal du joueur (grande base, 2026-09-04)
		EventBus.emettre(&"journal", [&"journal.deplacement", {"nom": e.name_key, "cout": e.compteur - tick}])
	if chute > 0:
		# Le SOL qui recoit amortit : degats x (1 - elasticite / 150). Tomber sur de la tourbe ou du
		# caoutchouc n'est pas tomber sur du granit — la note le disait, le code l'ignorait.
		var sm_c: Dictionary = regles.r.get("stats_materiau", {})
		var mat_sol: Dictionary = GameData.catalogues.materials.get(str(grille.sols.get(grille.idx(vers), grille.materiau_defaut)), {})
		var amorti := 1.0 - float(mat_sol.get("stats", {}).get("elasticite", 0.0)) / float(sm_c.get("chute_elasticite_div", 150.0))
		var d := maxi(0, roundi(float(grille.degats_chute(chute)) * clampf(amorti, 0.0, 1.0)))
		EventBus.emettre(&"journal", [&"journal.chute", {"nom": e.name_key, "niveaux": chute, "degats": d}])
		_appliquer_degats(e, d, "", {"chute": true})
	# De vrais escaliers (Génération de donjon, designer 2026-08-31) : marcher dessus change d'étage.
	if e.controle == "joueur" and lieu == "donjon" and not donjon.is_empty():
		if donjon.get("escalier") != null and vers == donjon.escalier and SimLieux._descendre(self, e):
			EventBus.dispatcher()
			return true
		if donjon.has("entree") and vers == donjon.entree and SimLieux._remonter(self, e):
			EventBus.dispatcher()
			return true
	# L'escalier d'un bâtiment à étages : y marcher monte (Villes, 99).
	if e.controle == "joueur" and lieu == "camp" and monde != null and str(grille.meubles.get(grille.idx(vers), "")) == "escalier" and SimVilles._entrer_interieur(self, e, vers):
		EventBus.dispatcher()
		return true
	# Une cellule corrompue happe qui y met le pied (designer 2026-09-01, point 51).
	if e.controle == "joueur" and lieu == "camp" and monde != null and SimLieux.entrer_donjon_de_la_cellule(self, e):
		EventBus.dispatcher()
		return true
	return true


func _prendre_garde(e: Dictionary, tick: int) -> bool:
	if e.vigueur <= 0 or Etres.bloque_statuts(e, "garde", statuts_defs):
		return false   # à zéro d'endurance (ou feinté), garde impossible
	if SimTalents.a_talent(self, e, "masques"):   # Le Masque : la main secondaire est prise
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
	e.vigueur = mini(e.vigueur_max, e.vigueur + int(regles.r.actions.attendre_vigueur))
	e.compteur = tick + int(regles.r.actions.attendre)
	if e.controle == "joueur":   # vingt résidents qui attendent n'écrivent pas vingt lignes (grande base, 2026-09-04)
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
	if SimTalents.a_talent(self, e, "ratelier_vivant") and not bool(e.get("swap_gratuit_pris", false)):   # Râtelier vivant (Talents de classe)
		cout = 0
		e["swap_gratuit_pris"] = true
		EventBus.emettre(&"journal", [&"journal.swap_gratuit", {"nom": e.name_key}])
	e.compteur = tick + cout
	EventBus.emettre(&"journal", [&"journal.changer_arme", {"nom": e.name_key, "objet": item.name_key, "ticks": cout}])
	return true


## Attaque à l'arme équipée. Une lourde est télégraphée : engagée maintenant, résolue à l'échéance.
func _attaquer_arme(e: Dictionary, cible: Dictionary, lourde: bool, tick: int) -> bool:
	var arme := Etres.arme(e, items)
	if arme.is_empty():   # main vide : on frappe aux poings (Le Masque, Le Porteur — leur identité même)
		arme = arme_mains_nues()
	if not cible.vivant:
		return false
	if not str(e.get("porte", "")).is_empty():   # Le Porteur : il porte quelqu'un
		EventBus.emettre(&"journal", [&"journal.porte", {}])
		return false
	var fonct: Dictionary = fonctionnalites.get(arme.functionality, {})
	if not _cible_atteignable(e, cible, _portee_effective(e, arme, fonct), true):
		return false
	if est_projectile(fonct) or est_jet(fonct):
		# Projectile (Décision — Projectiles) : munitions, trajectoire réelle, tir refusé si un allié masque.
		# Une arme de JET suit la même trajectoire, mais sa munition est elle-même : pas de carquois.
		if est_projectile(fonct) and e.munitions <= 0:
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
	_onde_sonore(e, cible, arme, fonct, ticks)
	return true


## L'attaque des instruments est une ONDE, pas un coup (designer 2026-09-03 : « les attaques au cac des
## armes charisme sont des zones autour du lanceur, hé oui logique c'est du son »).
##
## Trois choses la distinguent de tout le reste du jeu, et elles découlent toutes de la même idée :
##   — elle part du PORTEUR, pas de la cible : se coller à un barde ne met pas à l'abri ;
##   — elle ne demande AUCUNE ligne de vue : le son passe les angles, c'est sa signature ;
##   — elle touche moins fort chacun, parce qu'elle les touche tous.
## La cible désignée a déjà pris son coup plein juste avant : l'onde ramasse les autres.
func _onde_sonore(e: Dictionary, cible: Dictionary, arme: Dictionary, fonct: Dictionary, ticks: int) -> int:
	var rayon := int(fonct.get("attaque_zone", 0))
	if rayon <= 0:
		return 0
	var z: Dictionary = regles.r.get("armes", {}).get("zone_sonore", {})
	var mult := float(z.get("mult_degats", 0.5))
	var touches := 0
	for c in vivants():
		if c.id == e.id or c.id == cible.id or c.camp == e.camp:
			continue
		if Grille.distance(e.pos, c.pos) > rayon:
			continue
		_frapper_arme(e, c, arme, fonct, false, ticks, mult)
		touches += 1
	if touches > 0:
		EventBus.emettre(&"journal", [&"journal.onde_sonore", {"nom": e.name_key, "arme": arme.name_key, "n": touches}])
	return touches


func est_distance(fonct: Dictionary) -> bool:
	return int(fonct.get("portee_min", 1)) > 1


## Projectile (Décision — Projectiles) : munitions et trajectoire — l'arc, pas la lance.
## La zone morte au contact (portee_min > 1) est commune ; le carquois ne l'est pas.
func est_projectile(fonct: Dictionary) -> bool:
	return bool(fonct.get("projectile", false))


## Arme de JET (designer 2026-09-03, point 78) : « l'item en lui-même est la munition, le stack
## s'équipe en main ». C'est ce qui la sépare d'une arme à munitions : l'arc reste en main et vide un
## carquois, le javelot QUITTE LA MAIN. La pile équipée diminue d'un à chaque jet, l'objet lancé tombe
## au sol où on peut le reprendre, et quand la pile est vide la main l'est aussi.
func est_jet(fonct: Dictionary) -> bool:
	return bool(fonct.get("jet", false))


## Le javelot part : un de moins dans la pile, et il retombe sur la tuile visée. S'il n'en reste
## aucun, l'emplacement se vide — on ne se bat pas avec une pile de zéro javelot.
func _lancer_arme_de_jet(e: Dictionary, arme: Dictionary, ou: Vector2i) -> void:
	var reste := int(arme.get("quantite", 1)) - 1
	# L'objet qui tombe est une pile d'UN, copiée sur celle qu'on tient : même matière, même qualité,
	# même affixe. Un javelot ramassé vaut exactement celui qu'on a lancé.
	var tombe: Dictionary = arme.duplicate(true)
	tombe["uid"] = "%s_jet_%d" % [str(arme.uid), objets.size()]
	tombe["quantite"] = 1
	items[str(tombe.uid)] = tombe
	objets[str(tombe.uid)] = tombe
	var cible_sol := ou
	if not grille.dans(cible_sol) or grille.bloque_passage(cible_sol):
		cible_sol = e.pos
	SimTerrain._poser_ou_couler(self, cible_sol, [str(tombe.uid)], "butin")   # au-dessus d'un lac, un javelot d'acier est perdu ; un javelot de frêne flotte
	arme.quantite = maxi(0, reste)   # meme quand la pile part : un dictionnaire encore reference ne doit pas mentir sur son compte
	if reste <= 0:
		for slot in e.get("equipement", {}).keys():
			if str(e.equipement[slot]) == str(arme.uid):
				e.equipement.erase(slot)
				break
		e.sac.erase(str(arme.uid))
		items.erase(str(arme.uid))
		EventBus.emettre(&"journal", [&"journal.jet_dernier", {"nom": e.name_key, "arme": arme.name_key}])


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
	var arme := arme_utilisable(Etres.arme(e, items))
	var fonct: Dictionary = fonct_arme(arme)
	if fonct.is_empty() or not est_projectile(fonct):
		return {"ok": true}
	if e.munitions <= 0:
		return {"ok": false, "raison": "munitions"}
	var m := _premier_sur_trajectoire(e, cible)
	if not m.is_empty() and m.camp == e.camp:
		return {"ok": false, "raison": "allie", "bloqueur": m.pos}
	return {"ok": true, "devie": m.get("id", "")}


func _frapper_arme(e: Dictionary, cible: Dictionary, arme: Dictionary, fonct: Dictionary, lourde: bool, ticks: int, mult_degats: float = 1.0) -> void:
	var a_zero: bool = e.vigueur <= 0
	e.vigueur = maxi(0, e.vigueur - int(regles.r.vigueur.lourde if lourde else regles.r.vigueur.attaque))
	if est_projectile(fonct):
		e.munitions -= 1
		e.munitions_tirees += 1
	var jet_en_cours: bool = est_jet(fonct)   # l'arme quitte la main : on la lit AVANT que le coup la retire
	var jet_pos: Vector2i = cible.pos
	# Affixes de l'arme (Loot — affixes) : vecteur, dés, armure ignorée, multiplicateurs — avant le jet.
	var ax := _affixes_offensifs(e, arme, cible)
	e["riposte_des"] = 0   # les bonus armés (riposte à cadence, combo) sont dépensés par ce coup — raté compris, la fenêtre passe
	e["combo_des"] = 0
	var vecteur: Dictionary = ax.vecteur
	# Le jet de coup (Pipeline de résolution du combat) : critique ≥ crit_range, raté ≤ fumble_max ; Le Rieur élargit les deux queues.
	var jet_coup := des.jet("1d20")
	var crit_seuil := int(fonct.get("crit_range", 20)) - (int(regles.r.talents.deux_queues.crit_bonus) if SimTalents.a_talent(self, e, "deux_queues") else 0)
	var fumble := int(regles.r.degats.get("fumble_max", 1)) + (int(regles.r.talents.deux_queues.fumble_bonus) if SimTalents.a_talent(self, e, "deux_queues") else 0)
	if jet_coup <= fumble and SimTalents.a_talent(self, e, "deux_queues") and not bool(e.get("relance_utilisee", false)):
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
	mult_coup *= mult_degats   # l'onde sonore touche plusieurs corps : chacun prend moins
	if SimTalents.a_talent(self, e, "jauge_de_sang"):   # L'Écarlate : jusqu'à ×1,8 la jauge pleine
		mult_coup *= 1.0 + (float(regles.r.talents.jauge_de_sang.mult_max) - 1.0) * float(e.get("sang", 0)) / float(regles.r.talents.jauge_de_sang.max)
	for s0 in e.statuts:   # Poison de lame : chaque coup d'arme applique un statut à la cible
		for mod in statuts_defs.get(str(s0.id), {}).get("modifiers", []):
			if str(mod.cible) == "attaque_statut" and cible.vivant:
				appliquer_statut(cible, str(mod.statut), int(mod.get("duree", 30)), e.id)
				EventBus.emettre(&"journal", [&"journal.lame_empoisonnee", {"nom": e.name_key, "cible": cible.name_key}])
	if SimTalents.a_talent(self, e, "dissimulation"):   # L'Ombre : −25 % de face ; attaquer lève la dissimulation
		if Regles.direction_relative(cible.orientation, e.pos - cible.pos) == "front":
			mult_coup *= float(regles.r.talents.dissimulation.face_mult)
		if not bool(e.get("sans_trace", false)):   # Sans trace / Silencieux : ce coup-là ne trahit pas son auteur
			e.statuts = e.statuts.filter(func(s0: Dictionary) -> bool: return str(s0.id) != "dissimule")
	var d := regles.degats_arme(e.stats_eff, arme, fonct, des, lourde, a_zero, int(ax.des) + int(Etres.add_statuts(e, "des", statuts_defs)) - (int(regles.r.nage.des_malus) if SimTerrain.dans_l_eau(self, e.pos) else 0), e.competences_eff, vecteur)   # Béni : +dés ; dans l'eau : −dés
	var wx := _facteur_wuxing(e, cible, vecteur, tick_de(e))
	var dom := wuxing.dominante(vecteur)
	var plat := int(e.get("degats_element", {}).get(dom, 0))
	for el_h in e.get("degats_element_bonus", {}).keys():   # Nourriture : l'huile d'arme, le temps d'un combat —
		plat += des.jet(str(e.degats_element_bonus[el_h]))   # ses dés s'ajoutent quel que soit l'élément de l'arme
	# L'ELASTICITE fait la puissance d'un arc (« Application des stats de materiau » : degats x (0,8 +
	# elasticite / 250)). La note le decidait depuis longtemps et le code ne l'avait jamais lue : sur les
	# treize stats de matiere, quatre ne servaient a rien. Un arc d'if — elastique — vaut desormais
	# nettement plus qu'un arc de pierre, ce que tout le monde attend d'un arc.
	var mult_elastique := 1.0
	if est_projectile(fonct) or est_jet(fonct):
		var sm: Dictionary = regles.r.get("stats_materiau", {})
		# La corde d'abord : c'est elle qui se tend. A defaut — une fronde de fortune, une arme sans
		# piece dediee — on retombe sur la moyenne de l'objet.
		var elas := float(arme.get("elasticite_corde", arme.get("stats", {}).get("elasticite", 0.0)))
		mult_elastique = float(sm.get("arc_elasticite_base", 0.8)) + elas / float(sm.get("arc_elasticite_div", 250.0))
	var res := _resoudre_coup(e, cible, (d.bruts + float(plat)) * wx.total * float(ax.mult) * mult_coup * mult_elastique * Etres.mult_statuts(e, "degats", statuts_defs), fonct.type_degats, lourde, vecteur, float(ax.ignore_armure))
	res.merge(wx)
	res["competence"] = str(fonct.get("combat_skill", ""))
	var cle := &"journal.attaque_lourde" if lourde else &"journal.attaque"
	EventBus.emettre(&"journal", [cle, {"att": e.name_key, "def": cible.name_key, "zone": res.zone, "degats": res.degats, "ticks": ticks}])
	_appliquer_degats(cible, res.degats, e.id, res)
	_affixes_apres_coup(e, arme, cible, res)
	_poser_segment(e, vecteur, tick_de(e))
	_communion_tourner(e, arme)
	if jet_en_cours:   # le javelot est parti : il retombe au sol, et la pile en main diminue d'un
		_lancer_arme_de_jet(e, arme, jet_pos)


## Portée de l'arme, allongée par l'affixe « +N allonge ».
func _portee_effective(e: Dictionary, arme: Dictionary, fonct: Dictionary) -> Vector2i:
	var p := regles.portee_de(fonct, e.get("stats_eff", {}))
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
	if SimTalents.a_talent(self, e, "communion_des_cinq") and e.has("element_communion"):
		return {str(e.element_communion): 1.0}
	for s: Dictionary in e.get("statuts", []):   # Trempe (Modules) : l'arme chauffée passe à l'élément accordé
		for mod: Dictionary in statuts_defs.get(s.id, {}).get("modifiers", []):
			if str(mod.get("cible", "")) == "element_arme" and mod.has("grant"):
				return {str(mod.grant): 1.0}
	return vecteur_arme(arme)


## Après un coup qui pose un segment : l'élément tourne dans le cycle d'engendrement, contre du mana.
func _communion_tourner(e: Dictionary, arme: Dictionary) -> void:
	if not SimTalents.a_talent(self, e, "communion_des_cinq"):
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
		if not SimTerritoire.a_unique(self, e, "chaine_eternelle"):   # Chaîne éternelle : la jauge ne décroît plus
			wuxing.decroitre(e.chaine, tick)
		prev = wuxing.prevoir(e.chaine, wuxing.dominante(v_att))
		gain = prev.gain
		chaine = prev.multiplicateur
	return {"dom": dom.mult, "contre": dom.contre, "gain": gain, "chaine": chaine, "prevision": prev, "total": dom.mult * gain * chaine}


## Un coup qui touche pose UN segment (Jauge de chaîne Wu Xing) — s'il résout, la barre retombe.
func _poser_segment(e: Dictionary, v_att: Dictionary, tick: int, origine: String = "arme") -> void:
	if v_att.is_empty():
		return
	if origine == "arme" and SimTalents.a_talent(self, e, "souffle_rendu"):   # Souffle rendu : les coups d'arme ne tissent pas
		return
	if e.has("maitre") and entites.has(str(e.maitre)) and SimTalents.a_talent(self, entites[str(e.maitre)], "meute"):   # Meute : la jauge du maître
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
	# La GARDE de l'arme tenue protege son porteur : une piece d'armure minuscule, toujours au bon
	# endroit (designer 2026-09-03, option C — chaque troisieme piece a un effet mecanique propre).
	for slot_g in ["main_principale", "main_secondaire"]:
		armure += float(items.get(cible.get("equipement", {}).get(slot_g, ""), {}).get("garde_armure", 0.0))
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
			for ax in Etres.affixes_equipes(cible, items, affixes_defs, "meca_garde_vigueur"):
				cout = roundi(float(cout) * (1.0 - float(ax.params.pct) / 100.0))   # garde −N % d'endurance
			cible.vigueur = maxi(0, cible.vigueur - cout)
			for ax in Etres.affixes_equipes(cible, items, affixes_defs, "decl_parade_vigueur"):
				cible.vigueur = mini(cible.vigueur_max, cible.vigueur + int(ax.params.vigueur))
			for ax in Etres.affixes_equipes(cible, items, affixes_defs, "cadence_garde_vigueur"):
				ax.instance.compteur = int(ax.instance.compteur) + 1
				if int(ax.instance.compteur) % int(ax.params.n) == 0:
					cible.vigueur = mini(cible.vigueur_max, cible.vigueur + int(ax.params.vigueur))
			_declencher(cible, "parade", att.pos)
			EventBus.emettre(&"journal", [&"journal.garde_tient", {"nom": cible.name_key, "avant": sans_garde, "apres": degats}])
			if cible.vigueur <= 0:
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
			e.vigueur = int(e.vigueur_max)
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
			var inst: Dictionary = SimObjets.generer_objet(self, arg, 10, {}, "exceptionnel", -1)
			if inst.is_empty():
				return false
			e.sac.append(inst.uid)
		"materiau":
			SimTerrain._donner_materiau(self, e, arg, 20, "brut")
		"creature":
			if not GameData.existe("creatures", arg):   # un identifiant inconnu (« rat » pour rat_geant) plantait dans instancier
				return false
			var libre := _tuile_libre_autour(e.pos)
			if libre == Vector2i(-1, -1):
				return false
			var x: Dictionary = SimObjets.ajouter(self, arg, libre, "ia")
			if x.is_empty():
				return false
			if "civil" in GameData.entree("creatures", arg).get("tags", []):   # habiller un loup ou un bandit en faisait un civil nommé qui ne se battait plus (GIF du combat, 2026-09-04)
				SimObjets._habiller_pnj(self, x, GameData.entree("creatures", arg))
		"meteo":
			meteo_force = arg
		"heure":   # bascule jour ↔ nuit : saute à midi quand il fait nuit, à minuit quand il fait jour
			var jour := int(SimTerrain._cycle(self).ticks_par_jour)
			var cible := jour / 2 if SimTerrain.est_nuit(self) else 0
			var avance := posmod(cible - posmod(horloge_monde.ticks, jour), jour)
			horloge_monde.ticks += avance if avance > 0 else jour
		"semaine":
			_tiquer_monde(horloge_monde.ticks + int(GameData.config("planete").corruption.ticks_par_semaine))
		"reveler":   # les cellules autour du joueur : de quoi voyager partout sans tout marquer (1024² cellules)
			if monde == null:
				return false
			var n := monde.taille / 32
			var centre: Vector2i = SimCamp._cell_de(self, e.pos)
			for dx in range(-RAYON_REVELE, RAYON_REVELE + 1):
				for dy in range(-RAYON_REVELE, RAYON_REVELE + 1):
					var c := centre + Vector2i(dx, dy)
					if c.x >= 0 and c.y >= 0:
						monde.explores[Vector2i(c.x * n, c.y * n)] = true
		"claim":
			if monde == null:
				return false
			monde.claims[SimCamp._cell_de(self, e.pos)] = {"role": "base"}
			EventBus.emettre(&"cell_claimed", [SimCamp._cell_de(self, e.pos)])
		"tuer":   # tout ce qui est hostile dans la fenêtre tombe
			for x in vivants():
				if SimPnj.ennemis(self, e, x):
					_appliquer_degats(x, int(x.sante), e.id, {"type": "triche"})
		"race":
			match arg:
				"vampire": SimTalents._devenir_vampire(self, e)
				"spectre": SimTalents._devenir_spectre(self, e)
				"lycanthrope": SimTalents._devenir_lycanthrope(self, e)
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
		SimTalents._retirer_statut(self, cible, "voile")   # Voile : le prochain coup subi est esquivé, et le voile tombe
		EventBus.emettre(&"journal", [&"journal.voile_esquive", {"nom": cible.name_key}])
		return
	var pct_reflet := 1.0 - float(Etres.mult_statuts(cible, "reflet", statuts_defs))   # Reflet : une part revient
	if degats > 0 and pct_reflet > 0.0 and not source.is_empty() and entites.has(source) and str(detail.get("type", "")) != "reflet":
		var att: Dictionary = entites[source]
		if att.vivant and att.id != cible.id:
			var renvoi := maxi(1, roundi(float(degats) * pct_reflet))
			EventBus.emettre(&"journal", [&"journal.reflet", {"nom": cible.name_key, "att": att.name_key, "degats": renvoi}])
			_appliquer_degats(att, renvoi, cible.id, {"type": "reflet", "element": {}})
	if SimTalents.a_talent(self, cible, "sans_chair") and str(detail.get("type", "")) in ["contondant", "tranchant", "perforant"]:   # le Spectre
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
				SimTalents._retirer_statut(self, cible, "absorption")
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
		SimTalents._retirer_statut(self, cible, "reserve")
		EventBus.emettre(&"journal", [&"journal.reserve", {"nom": cible.name_key, "soin": reserve}])
	cible.sante = maxi(0, cible.sante - degats)
	if float(detail.get("erosion", 0.0)) > 0.0 and degats > 0:   # Érosif : une part des dégâts rogne les PV max, pour le combat
		var rogne := maxi(1, roundi(float(degats) * float(detail.erosion)))
		cible["erosion"] = int(cible.get("erosion", 0)) + rogne
		Etres.recalculer(cible, items, affixes_defs, regles)
		EventBus.emettre(&"journal", [&"journal.erosion", {"nom": cible.name_key, "pv": rogne, "max": int(cible.sante_max)}])
	if cible.sante > 0 and not bool(cible.get("second_souffle_pris", false)) and float(cible.sante) / float(cible.sante_max) * 100.0 < float(regles.r.uniques.second_souffle_seuil_pct):
		var ax_ss: Dictionary = SimTerritoire.a_unique_ax(self, cible, "second_souffle")   # Second souffle : une fois par combat
		if not ax_ss.is_empty():
			var soin := roundi(float(cible.sante_max) * float(ax_ss.params.get("pct", 30)) / 100.0)
			cible.sante = mini(cible.sante_max, int(cible.sante) + soin)
			cible["second_souffle_pris"] = true
			EventBus.emettre(&"journal", [&"journal.second_souffle", {"nom": cible.name_key, "soin": soin}])
	if SimTalents.a_talent(self, cible, "jauge_de_sang"):   # L'Écarlate : les dégâts subis remplissent la jauge
		cible["sang"] = mini(int(regles.r.talents.jauge_de_sang.max), int(cible.get("sang", 0)) + degats)
	if degats > 0:
		_monter_aggro(cible, source, float(degats) * float(regles.r.get("ia", {}).get("aggro_par_degat", 1.0)), true)
	EventBus.emettre(&"damage_dealt", [source, cible.id, degats, detail])
	var att: Dictionary = entites.get(source, {})
	if not att.is_empty() and att.controle == "joueur" and cible.camp == "civil" and "civil" in cible.get("tags", []):
		SimPnj.reputation(self, att, cible, "tuer" if cible.sante <= 0 else "frapper")
	if cible.sante <= 0 and cible.vivant:
		cible.vivant = false
		grille.liberer(cible.pos)
		EventBus.emettre(&"journal", [&"journal.mort", {"nom": cible.name_key}])
		EventBus.emettre(&"creature_killed", [cible.id, source])
		SimPnj._quetes_sur_mort(self, cible, source)
		if not att.is_empty() and att.controle == "joueur" and bool(cible.get("spawn_faune", false)) and est_faune_paisible(cible):
			_rarefier_faune(cible.pos)   # massacrer la faune vide la forêt (Créatures, 2026-09-04)
		if not att.is_empty() and SimTalents.a_talent(self, att, "dissimulation"):   # L'Ombre : dissimulé après chaque mise à mort
			appliquer_statut(att, "dissimule", int(statuts_defs.get("dissimule", {}).get("duree_ticks", 24000)), att.id)
			EventBus.emettre(&"journal", [&"journal.dissimule", {"nom": att.name_key}])
		if not att.is_empty() and att.controle == "joueur" and cible.camp == "civil":
			SimRoyaumes._infraction(self, att, "comportement", "meurtre", cible.pos, "")
		if str(cible.get("fonction", "")) == "dirigeant" and not str(cible.get("royaume", "")).is_empty() and monde != null:
			monde.vacances[str(cible.royaume)] = monde.semaine_courante + int(SimTerritoire._ry(self).succession.semaines)
			var h: String = SimRoyaumes.heritier_de(self, cible)
			if not h.is_empty():
				monde.heritiers[str(cible.royaume)] = h
			EventBus.emettre(&"journal", [&"journal.vacance", {"royaume": monde.surface.royaume_de(SimCamp._cell_de(self, cible.pos)).get("nom", cible.royaume)}])
		if str(cible.get("fonction", "")) == "maitre_de_guilde" and cible.has("guilde") and monde != null and not str(cible.get("village", "")).is_empty():
			monde.vacances_guildes["%s|%s" % [str(cible.guilde), str(cible.village)]] = monde.semaine_courante + int(SimTerritoire._ry(self).succession.semaines_guilde)
			EventBus.emettre(&"journal", [&"journal.vacance_guilde", {"guilde": "guilde.%s.name" % str(cible.guilde)}])
		if cible.has("maitre"):
			SimPnj._mort_compagnon(self, cible)
		_declencher(cible, "testament", cible.pos)   # la charge part quand le porteur tombe
		SimObjets._drop(self, cible, source)
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
		SimTalents._debloquer_grilles_de_palier(self, e, cle, int(e.competences[cle]))   # un palier d'arme franchi apprend la grille suivante de sa voie (2026-09-04)
		if e.controle == "joueur" or str(e.get("maitre", "")) != "":   # le joueur et ses compagnons ; pas les vingt résidents (2026-09-04)
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
		if e.controle == "joueur" or str(e.get("maitre", "")) != "":
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
			var arme := arme_utilisable(Etres.arme(e, items))
			var fonct: Dictionary = fonct_arme(arme)
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


func _lancer_action_creature(e: Dictionary, action: Dictionary, cible: Dictionary, _tick: int) -> void:
	var ticks := int(action.cout_ticks)
	if not cible.is_empty():
		e.orientation = Vector2i(signi(cible.pos.x - e.pos.x), signi(cible.pos.y - e.pos.y))
	_quitter_garde(e)
	# Sur l'horloge de l'être, pas sur le tick reçu : l'engagement qui précède (_engager_combat) vient de le faire
	# changer d'horloge, et « tick + coût » restait un tampon du monde — un rat posé au camp mordait puis restait
	# « agit à t=8007 » dans un combat à t=15, figé, le joueur seul en combat avec lui (capture --dump, 2026-09-04).
	e.compteur = horloge_de(e).ticks + ticks
	if regles.est_telegraphee(ticks) or "telegraphe" in action.tags:
		e.action_en_cours = {"type": "creature", "action": action.id, "cible": cible.get("id", ""), "ticks": ticks, "name_key": action.name_key}
		EventBus.emettre(&"journal", [&"journal.telegraphe", {"nom": e.name_key, "action": action.name_key, "ticks": ticks}])
		EventBus.emettre(&"action_engaged", [e.id, e.action_en_cours])
		return
	_executer_action_creature(e, action, cible)


func _executer_action_creature(e: Dictionary, action: Dictionary, cible: Dictionary) -> void:
	var a_zero: bool = e.vigueur <= 0
	e.vigueur = maxi(0, e.vigueur - int(action.cout_vigueur))
	var cibles: Array[Dictionary] = _cibles_de_forme(e, action, cible)
	for effet: Dictionary in action.effets:
		match str(effet.type):
			"degats":
				for c in cibles:
					if not c.vivant and not (c.id in lot_simultane):   # tuée dans le même lot : frappée quand même (Boucle de tick)
						continue
					var bonus := _bonus_des_conditions(e, c, action) + SimTalents._bonus_embuscade(self, e, c) + int(Etres.add_statuts(e, "des", statuts_defs))   # Béni
					var d := regles.degats_action(e.stats_eff, action, des, a_zero, bonus)
					var wx := _facteur_wuxing(e, c, action.elements, tick_de(e))
					var res := _resoudre_coup(e, c, d.bruts * wx.total * Etres.mult_statuts(e, "degats", statuts_defs), str(action.get("type_degats", "contondant")), false, action.elements)
					res.merge(wx)
					res["competence"] = action.id
					EventBus.emettre(&"journal", [&"journal.action_creature", {"att": e.name_key, "action": action.name_key, "def": c.name_key, "zone": res.zone, "degats": res.degats}])
					_appliquer_degats(c, res.degats, e.id, res)
					if c.vivant and SimTalents.a_talent(self, e, "lune") and bool(e.get("forme_bestiale", false)) and ("morsure" in action.tags or str(action.id).begins_with("morsure")) and "humanoide" in c.get("tags", []):
						appliquer_statut(c, "morsure_lunaire", int(statuts_defs.morsure_lunaire.duree_ticks), e.id)   # la lycanthropie se transmet
				if not cibles.is_empty():
					_poser_segment(e, action.elements, tick_de(e))
			"deplacement":
				_effet_deplacement(e, effet, cibles, cible)
			"attaque_arme":
				var arme := Etres.arme(e, items)
				if not arme.is_empty() and not cible.is_empty() and cible.vivant:
					var fonct: Dictionary = fonctionnalites.get(arme.functionality, {})
					if _cible_atteignable(e, cible, regles.portee_de(fonct, e.get("stats_eff", {})), true):
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
		var x: Dictionary = SimObjets.ajouter(self, str(effet.get("creature", "feu_follet")), q, "ia")
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
						if x.id == e.id or SimPnj.ennemis(self, e, x) or Grille.distance(e.pos, x.pos) > int(a.portee[1]):
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
				"statut":   # un cri, un hurlement : l'anneau autour de soi, pour les alliés qui n'ont pas encore le statut (IA des créatures, 2026-09-04)
					if str(a.get("cible", "")) != "allie" or str(e.get("cible", "")).is_empty():
						continue
					for p in grille.anneau(e.pos, int(a.get("taille", 1))):
						var occ := grille.occupant(p)
						if occ.is_empty() or occ == e.id or not entites.has(occ):
							continue
						var x: Dictionary = entites[occ]
						if x.vivant and not SimPnj.ennemis(self, e, x) and not Etres.a_statut_id(x, str(effet.id)):
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
		"ennemi": return SimPnj.ennemis(self, e, c)
		"allie": return not SimPnj.ennemis(self, e, c) and c.id != e.id
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
				if SimPnj.ennemis(self, e, c):
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
				if not c.vivant or SimPnj.ennemis(self, e, c) or c.id == e.id:
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
				SimTalents._liberer_saisie(self, e, vole)
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
				SimTalents._retirer_statut(self, c, "au_sol")
				appliquer_statut(c, "au_sol", int(statuts_defs.au_sol.duree_ticks), e.id)
				EventBus.emettre(&"journal", [&"journal.fauche", {"nom": c.name_key}])


# ---------------------------------------------------------------- capacités (modules assemblés)

## Le plan d'une SÉQUENCE pour `e`, avec l'arme tenue : ticks, dés et élément de l'arme pour les noyaux
## « arme », et l'**affinité** de la fonctionnalité pour tous les sorts (Structure compétences-modules-slots :
## un sceptre porte les sorts de mana, une épée ceux d'endurance). C'est aussi ce que l'écran Composer lit.
func plan_sequence(e: Dictionary, sequence: Array, crans: Array = []) -> Dictionary:
	var arme := arme_utilisable(Etres.arme(e, items))
	var fonct: Dictionary = fonct_arme(arme)
	var ticks_arme := regles.ticks_attaque(fonct, false, arme) if not fonct.is_empty() else int(regles.r.actions.attaque_base)
	var plan := capacites.assembler(sequence, ticks_arme, fonct.get("degats_des", "1d4"), _vecteur_arme_de(e, arme), e.competences_eff, crans)
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
	var aff: Dictionary = fonct.get("affinite_sorts", regles.r.get("modules", {}).get("affinite_mains_nues", {"mana": 1.0, "vigueur": 1.0}))
	var monnaie := str(plan.get("monnaie", ""))
	var f := float(aff.get(monnaie, 1.0)) if not monnaie.is_empty() else 1.0
	# `cout_mana_mult` : un talisman ne rend pas les sorts plus forts, il les rend moins CHERS — donc
	# plus nombreux. C'est l'autre facon de servir un lanceur, et la seule qui reponde au vrai goulot
	# mesure le 2026-09-03 : six sorts par etage, faute de mana.
	# (Une affinite par ELEMENT a existe une heure le meme jour — un baton de cendre poussant le Feu —
	# et le designer a retire ces armes-la. Le levier est parti avec elles : un mecanisme que plus
	# aucune fiche n'utilise trompe le prochain lecteur, qui le croit vivant.)
	plan["affinite_arme"] = f
	plan["cout_mana_mult_arme"] = float(fonct.get("cout_mana_mult", 1.0))
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
	var plan := plan_sequence(e, caps[index].modules, caps[index].get("crans", []))   # le cran de chaque pièce (designer 2026-09-04)
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
		return Grille.portee_entre(e.pos, cible) >= int(plan.portee.x) and Grille.portee_entre(e.pos, cible) <= int(plan.portee.y)
	var occ_t := grille.occupant(cible)   # Traque : la proie marquée se vise sans ligne de vue
	if not occ_t.is_empty() and entites.has(occ_t):
		for st: Dictionary in entites[occ_t].get("statuts", []):
			if str(st.id) == "traque" and str(st.get("source", "")) == e.id:
				return Grille.portee_entre(e.pos, cible) >= int(plan.portee.x) and Grille.portee_entre(e.pos, cible) <= int(plan.portee.y)
	if plan.geometrie == "soi":
		return true
	if str(plan.get("origine", "cible")) == "lanceur":
		return cible != e.pos   # la forme part du lanceur : la tuile cliquée n'est qu'une direction
	var d := Grille.portee_entre(e.pos, cible)   # une portée est un disque, pas un carré (designer 2026-09-01)
	if d < plan.portee.x or d > plan.portee.y:
		return false
	if not motif_atteint(str(plan.get("motif", "")), e.pos, cible):   # certaines portées ont une forme (2026-09-02)
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
				var el_lieu := wuxing.dominante(SimTalents.vecteur_lieu(self, e.pos))
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
				vrai = monde != null and monde.corruption_de(SimCamp._cell_de(self, e.pos)) >= float(p.get("seuil", 50))
			"phase_du_jour":   # Heure : selon le cycle jour-nuit
				vrai = (str(p.get("phase", "nuit")) == "nuit") == SimTerrain.est_nuit(self)
			"meteo_parmi":   # Intempérie : l'orage nourrit la Foudre
				vrai = monde != null and str(SimTerrain.meteo(self, SimCamp._cell_de(self, e.pos))) in p.get("etats", [])
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
			SimTalents._retirer_statut(self, cible, str(p.consomme))
	return {}


## Lance la capacité n° `index` sur la tuile `cible` : coûts, conditions, télégraphe ou exécution.
## Apprendre un module (Grimoires et manuels, designer 2026-08-31) : c'est définitif et sans munitions —
## les charges n'existent plus. Le paramètre `charges` n'est gardé que pour les appels historiques.
func crediter_module(e: Dictionary, mid: String, _charges: int = 0) -> void:
	if not e.has("modules_connus"):
		e["modules_connus"] = []
	if not (mid in e.modules_connus):
		e.modules_connus.append(mid)


## Les modules du plan que l'être ne connaît pas (Grimoires et manuels) : un module connu l'est pour toujours.
func modules_sans_charge(e: Dictionary, plan: Dictionary) -> Array[String]:
	var manquants: Array[String] = []
	if e.controle != "joueur":
		return manquants   # les créatures n'apprennent pas dans des livres
	var connus: Array = e.get("modules_connus", [])
	for m in plan.get("modules", []):
		if not (str(m) in connus) and not (str(m) in manquants):
			manquants.append(str(m))
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
	if SimTerrain.dans_l_eau(self, e.pos) and wuxing.dominante(plan.get("elements", {})) == "feu":   # pas de Feu sous l'eau (Eau et liquides)
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


## Les modules ne s'épuisent plus (designer 2026-08-31) : lancer un sort ne coûte que mana, endurance et ticks.
func _consommer_charges(_e: Dictionary, _plan: Dictionary) -> void:
	pass


## Paie la monnaie du noyau. Mana insuffisant = surchauffe : le déficit est infligé en PV × 2 (Mana).
func _payer(e: Dictionary, plan: Dictionary) -> void:
	if not plan.charge_suivante.is_empty():
		_payer(e, plan.charge_suivante)   # la charge différée paie aussi, dans sa propre monnaie
	match str(plan.monnaie):
		"mana":
			# Le focus tenu peut rendre le sort moins cher (`cout_mana_mult`) : c'est la specificite du
			# talisman, qui ne frappe pas plus fort mais permet de lancer plus souvent.
			# La CONDUCTIVITE DE MANA de la matiere tenue reduit le cout : cout x (1 - conductivite / 140).
			# La note « Application des stats de materiau » le decidait — « le choix de la gemme du baton
			# devient structurant » — et le code ne lisait pas cette stat du tout. C'est la version
			# MATIERE de ce que j'avais ajoute une heure plus tot au niveau de la fonctionnalite
			# (`cout_mana_mult`, la signature du talisman) : les deux se cumulent, l'archetype et la
			# matiere, et c'est ce qui rend un talisman d'opale different d'un talisman de plomb.
			var sm_m: Dictionary = regles.r.get("stats_materiau", {})
			var arme_m: Dictionary = Etres.arme(e, items)
			var cond := float(arme_m.get("stats", {}).get("conductivite_mana", 0.0))
			var mult_cond := clampf(1.0 - cond / float(sm_m.get("mana_conductivite_div", 140.0)), 0.2, 1.0)
			var cout := roundi(float(plan.ressource) * SimTalents.mult_mana_lieu(self, e, plan) * SimTalents.mult_mana_sources(self, e) * float(plan.get("cout_mana_mult_arme", 1.0)) * mult_cond)
			var deficit: int = maxi(0, cout - int(e.mana))
			e.mana = maxi(0, int(e.mana) - cout)
			if deficit > 0:
				var degats := roundi(float(deficit * int(regles.r.mana.surchauffe_mult)) * float(e.get("mecaniques", {}).get("surchauffe_mult", {}).get("mult", 100)) / 100.0)
				EventBus.emettre(&"journal", [&"journal.surchauffe", {"nom": e.name_key, "deficit": deficit, "degats": degats}])
				if SimTalents.a_talent(self, e, "chair_de_mana"):   # Chair de mana (Talents de race) : le corps paie en endurance
					e.vigueur = maxi(0, int(e.vigueur) - degats)
				else:
					_appliquer_degats(e, degats, "", {"surchauffe": true})
		"vigueur":   # Épuisement (Mana) : au-delà du pool, le déficit se paie en PV — rien n'est gratuit
			var deficit_e: int = maxi(0, int(plan.ressource) - int(e.vigueur))
			e.vigueur = maxi(0, int(e.vigueur) - int(plan.ressource))
			if deficit_e > 0:
				var degats_e := roundi(float(deficit_e) * float(regles.r.vigueur.get("epuisement_mult", 1)))
				if degats_e > 0:
					EventBus.emettre(&"journal", [&"journal.epuisement", {"nom": e.name_key, "deficit": deficit_e, "degats": degats_e}])
					_appliquer_degats(e, degats_e, "", {"surchauffe": true})
		"sang_froid":   # Le sang-froid se paie comme les deux autres : dépenser à vide coûte des PV.
			var deficit_s: int = maxi(0, int(plan.ressource) - int(e.get("sang_froid", 0)))
			e["sang_froid"] = maxi(0, int(e.get("sang_froid", 0)) - int(plan.ressource))
			if deficit_s > 0:
				var degats_s := roundi(float(deficit_s) * float(regles.r.sang_froid.get("epuisement_mult", 2)))
				if degats_s > 0:
					EventBus.emettre(&"journal", [&"journal.sang_froid_rompu", {"nom": e.name_key, "deficit": deficit_s, "degats": degats_s}])
					_appliquer_degats(e, degats_s, "", {"surchauffe": true})


## Exécute une capacité : forme → cibles (friendly fire des zones), puis les effets du noyau.
func _executer_capacite(e: Dictionary, plan: Dictionary, cible_pos: Vector2i, segment: bool = true) -> void:
	var tick := tick_de(e)
	if "cataclysme" in plan.noyau.get("tags", []):   # Sorts cataclysmiques : le coût mord — l'endurance est vidée, et c'est noté pour le combat
		e.vigueur = 0
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
			for comp in SimPnj.compagnons_de(self, e):
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
	# La surface dilue la puissance (designer 2026-09-01) : ×1/√n sur le nombre de TUILES de la forme —
	# ce que l'aperçu montre avant le lancer. La liaison Concentration l'annule, contre son surcoût.
	var concentre := false
	for l: Dictionary in plan.liaisons:
		if l.get("concentration", false):
			concentre = true
	var dil := facteur_dilution(tuiles.size()) * facteur_distance(int(plan.portee.y))
	if not concentre and dil < 1.0:
		charge = plan.duplicate()
		charge.mult = float(plan.mult) * dil
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
					"source": e.id, "params": {"plan": plan.duplicate()}, "elements": plan.elements.duplicate(), "cachee": SimLieux._plan_discret(self, plan)})
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
	# Déclencheur : la charge qui suit part à l'impact, ou à la mise à mort. Elle pose SON segment
	# (designer 2026-09-01) : chaque étape est un acte, payé en ticks, donc elle vaut son segment.
	var suite: Dictionary = plan.charge_suivante
	if not suite.is_empty() and suite.erreurs.is_empty():
		var ou: Vector2i = res.premiere.pos if not res.premiere.is_empty() else cible_pos
		match str(suite.declencheur):
			"impact":
				if a_touche:
					_executer_capacite(e, suite, ou)
			"mise_a_mort":
				if not res.tuee.is_empty():
					_executer_capacite(e, suite, res.tuee.pos)
			"entree":
				# Sceau : la charge attend au sol, jusqu'à 100 ticks — overlay runtime, jamais sauvegardé.
				var duree := int(suite.get("duree_declencheur", 100))
				if SimTalents.a_talent(self, e, "graveur"):   # Le Sceau : permanent, 2× mana, immobile pendant la gravure
					duree = 1 << 30
					e.mana = maxi(0, int(e.mana) - int(plan.ressource) * (int(regles.r.talents.graveur.mana_mult) - 1))
					appliquer_statut(e, "gravure", int(regles.r.talents.graveur.gravure_ticks), e.id)
				glyphes.append({"pos": cible_pos, "plan": suite, "source": e.id, "fin": tick + duree, "elements": suite.elements,
					"cache": SimTalents.a_talent(self, e, "dissimulation")})
				if not SimTalents.a_talent(self, e, "dissimulation"):   # L'Ombre : ses pièges ne se voient pas (Talents de classe)
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
					_executer_capacite(e, suite, ou)
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
					if SimTalents.a_talent(self, e, "souffle_rendu") and c.sante > avant:   # Souffle rendu : un segment de l'élément de la cible
						var el_c: Dictionary = c.get("elements", {}) if c.get("elements") is Dictionary else {}
						_poser_segment(e, el_c if not el_c.is_empty() else {"bois": 1.0}, tick, "soin")
					if premiere.is_empty():
						premiere = c
					EventBus.emettre(&"journal", [&"journal.soin", {"att": e.name_key, "capacite": plan.name_key, "def": c.name_key, "soin": c.sante - avant}])
			"resurrection":   # Renaissance (Domaines de grimoires et manuels) : l'âme portée rappelle le compagnon
				var ame: String = SimElevage.ame_dans_sac(self, e)
				if ame.is_empty():
					EventBus.emettre(&"journal", [&"journal.renaissance_rien", {}])
				else:
					var comp: Dictionary = entites.get(str(items[ame].get("compagnon", "")), {})
					if SimPnj._ressusciter(self, e, ame, tick, "", true):
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
							"source": e.id, "params": tp, "elements": plan.elements.duplicate(), "cachee": SimLieux._plan_discret(self, plan)})
						a_touche = true
						EventBus.emettre(&"tile_changed", [t])
					EventBus.emettre(&"journal", [&"journal.zone_posee", {"nom": e.name_key, "zone": "zone." + str(tp.zone)}])
				if not tp.is_empty() and tp.has("delta"):
					for t in tuiles:
						var avant := grille.h(t)
						var apres := clampi(avant + int(tp.delta), 0, 20)
						if apres == avant:
							continue
						SimTerrain._memoriser_terrain(self, t)   # le monde se soigne hors claim (Destruction du terrain)
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
						if rs.has("vigueur"):
							c.vigueur = clampi(int(c.vigueur) + int(rs.vigueur), 0, int(c.vigueur_max))
						if rs.has("sang"):   # L'Écarlate : la jauge monte d'un cran
							c["sang"] = mini(int(regles.r.talents.jauge_de_sang.max), int(c.get("sang", 0)) + int(rs.sang) * int(regles.r.talents.jauge_de_sang.max) / 4)
						if rs.has("purge"):   # retire un statut négatif, le premier trouvé
							for st: Dictionary in c.statuts.duplicate():
								if "negatif" in statuts_defs.get(st.id, {}).get("tags", []) or "controle" in statuts_defs.get(st.id, {}).get("tags", []):
									SimTalents._retirer_statut(self, c, str(st.id))
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
							SimObjets._poser_contenant(self, c.pos, [arme_c], "butin")
							Etres.recalculer(c, items, affixes_defs, regles)
							EventBus.emettre(&"journal", [&"journal.desarmement", {"nom": c.name_key, "objet": SimObjets.nom_objet(self, arme_c)}])
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
							if c.id == e.id or SimPnj.ennemis(self, e, c):
								continue
							var el_c: Dictionary = c.get("elements", {}) if c.get("elements") is Dictionary else {}
							_poser_segment(e, el_c if not el_c.is_empty() else {"bois": 1.0}, tick, "soin")
							break
					if rs.has("releve_allie_pct"):   # Rappel à la vie : un allié tombé se relève à N % de ses PV
						var tombes: Array[Dictionary] = []   # les touchés ne comptent que les vivants : les morts se cherchent sur les tuiles
						for x in entites.values():
							if not x.vivant and x.pos in tuiles and not SimPnj.ennemis(self, e, x) and x.id != e.id:
								tombes.append(x)
						for c in tombes:
							if c.vivant or SimPnj.ennemis(self, e, c):
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
							if c.id == e.id or not c.vivant or SimPnj.ennemis(self, e, c):
								continue
							var don := mini(int(rs.transfert_pv), maxi(0, int(e.sante) - 1))
							e.sante = int(e.sante) - don
							c.sante = mini(int(c.sante_max), int(c.sante) + don)
							EventBus.emettre(&"journal", [&"journal.transfert", {"nom": e.name_key, "def": c.name_key, "pv": don}])
							break
			"saisie":   # Empoigne : la première cible vivante adjacente est saisie (Talents de classe — Le Porteur)
				for c in touchees:
					if c.vivant and c.id != e.id and SimTalents._saisir(self, e, c.id, tick_de(e), false):
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
						if SimTalents._relever_brut(self, e, x, tick):
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
				var x: Dictionary = SimObjets.ajouter(self, str(c.get("creature", "loup")), q, "ia")
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
					var x3: Dictionary = SimObjets.ajouter(self, str(c.get("creature", "loup")), q2, "ia")
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
				var x2: Dictionary = SimObjets.ajouter(self, str(c.get("creature", "loup")), libre, "ia")
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
	for z in SimLieux.zones_sur(self, pos, "balise"):
		if str(z.source) == e.id:
			bonus += int(z.params.get("des", 1))
	return bonus


func _degats_capacite(e: Dictionary, c: Dictionary, plan: Dictionary, prev: Dictionary) -> Dictionary:
	var a_zero: bool = e.vigueur <= 0 and plan.monnaie == "vigueur"
	var arme_noyau: bool = plan.noyau.get("power_base") == "arme"
	var d: Dictionary
	var type_degats := "magique"
	var des_bonus := int(plan.des_bonus) + _bonus_balise(e, c.pos)   # Balise : la tuile marquée donne ses dés
	if arme_noyau and not plan.arme.is_empty():
		d = regles.degats_arme(e.stats_eff, plan.arme, plan.fonct, des, false, a_zero, des_bonus, e.competences_eff, plan.elements)
		type_degats = str(plan.fonct.type_degats)
	else:
		# Un sort roule comme un coup d'arme (designer 2026-09-01) : école, affinités, focus et Volonté.
		d = regles.degats_sort(e.stats_eff, e.competences_eff, plan.elements, regles.focus_de(e.equipement, items), des, plan.des, des_bonus, str(plan.get("noyau", {}).get("stat", "")))
		if Etres.bloque_statuts(e, "relance", statuts_defs):   # Pari : le second résultat s'applique, quel qu'il soit
			d = regles.degats_sort(e.stats_eff, e.competences_eff, plan.elements, regles.focus_de(e.equipement, items), des, plan.des, des_bonus, str(plan.get("noyau", {}).get("stat", "")))
			SimTalents._retirer_statut(self, e, "pari")
			EventBus.emettre(&"journal", [&"journal.pari", {"nom": e.name_key, "jet": int(d.jet)}])
	var bruts: float = d.bruts * float(plan.mult) * mult_serments(e)   # les serments tenus paient (point Nen)
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
		c.vigueur = maxi(0, c.vigueur - regles.cout_garde_impact(sans_garde, bouclier))
		if c.vigueur <= 0:
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
	for x in [a, b]:   # pas de combat monté (Villes B4, décidé) : on met pied à terre
		if x.has("monture"):
			SimVilles._descendre_monture(self, x, horloge_de(x).ticks)
			EventBus.emettre(&"journal", [&"journal.descend_combat", {"nom": x.name_key}])
	a.erase("relance_utilisee")   # Le Rieur : une relance par combat
	b.erase("relance_utilisee")
	a.erase("cataclysmes_combat")   # Sorts cataclysmiques : un par combat
	b.erase("cataclysmes_combat")
	a.erase("second_souffle_pris")   # Trésors et artefacts : un second souffle par combat
	b.erase("second_souffle_pris")
	if a.get("huile_feu", false) and not en_combat(a):
		a.erase("huile_feu")
		a["degats_element_bonus"] = {"feu": "1d4"}   # consommé par le premier combat (Nourriture : huile d'arme)
	if not SimPnj.ennemis(self, a, b):
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
	# L'escorte entre dans le combat de son maître (Compagnons, 2026-09-04) : sans ça les compagnons restaient sur
	# l'horloge du monde, figés à deux pas pendant que le joueur se battait — deux compagnons, huit combats, zéro coup.
	var d_eng := int(regles.r.compagnons.get("distance_engagement", 6))
	for p in [a, b]:
		var adversaire: Dictionary = b if p.id == a.id else a
		for c in SimPnj.compagnons_de(self, p, false):
			if c.horloge == nom or not bool(c.vivant) or str(c.get("ordre", "suivre")) != "suivre" or str(c.get("posture", "defensive")) == "eviter":
				continue
			if Grille.distance(c.pos, p.pos) > d_eng or not SimPnj.ennemis(self, c, adversaire):
				continue
			_rejoindre(c, nom)
			if str(c.cible).is_empty():
				c.cible = adversaire.id
				c.tick_derniere_vue = horloge_de(c).ticks
				c.pos_connue = adversaire.pos


func _rejoindre(e: Dictionary, nom: String) -> void:
	var de := horloge_de(e)
	var vers: Horloge = combats[nom].horloge
	e.compteur = vers.ticks + maxi(0, e.compteur - de.ticks)
	e.tick_vigueur = vers.ticks - maxi(0, de.ticks - e.tick_vigueur)
	if en_combat(e):
		combats[e.horloge].participants.erase(e.id)
	e.horloge = nom
	combats[nom].participants.append(e.id)


func _quitter_combat(e: Dictionary) -> void:
	var de := horloge_de(e)
	combats[e.horloge].participants.erase(e.id)
	e.compteur = horloge_monde.ticks + maxi(0, e.compteur - de.ticks)
	e.tick_vigueur = horloge_monde.ticks
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
	if e.has("vehicule_etat"):   # un train, une calèche : un itinéraire, pas une utilité (Villes B4)
		SimVilles._ia_vehicule(self, e, tick)
		return
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
		if m0.is_empty() or monde == null or lieu != "camp" or not monde.claims.has(SimCamp._cell_de(self, m0.pos)):
			EventBus.emettre(&"journal", [&"journal.suiveur_fin", {"nom": e.name_key}])
			SimPnj._fin_suiveur(self, e)
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
			if SimTalents.a_talent(self, x, "sans_chair") and voit_ia(e, x):
				appliquer_statut(e, "terreur", int(regles.r.talents.sans_chair.terreur_ticks), x.id)
				break
	_decroitre_aggro(e)   # le temps efface : sans ca, une rencontre devient une course a travers l'etage
	var horloge_avant := str(e.horloge)
	var cible := _chercher_cible(e, tick)
	if e.horloge != horloge_avant:   # la recherche vient d'ouvrir ou de rejoindre un combat : la suite (déplacement, attente, attaque) se compte sur cette horloge-là, pas sur le tick du monde reçu
		tick = horloge_de(e).ticks
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
	# Aggro (designer 2026-08-31, point 48) : une bête qui a une cible hostile en vue ne flâne pas.
	if e.camp == "hostile" and _profil_offensif(e) and not cible.is_empty() and cible.vivant and SimPnj.ennemis(self, e, cible) and meilleure in ["errer", "routine", "attendre", ""]:
		meilleure = "poursuivre"
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
			SimRoyaumes._ia_assaut(self, e, tick)
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


## L'AGGRO (designer 2026-09-03, point 77 : « rajoute du roam de l'aggro etc »). Chaque être tient une
## table « qui m'a fait quoi » : frapper la fait monter, le temps la fait redescendre, et la cible est
## celle qui pèse le plus — pas la plus proche. Avant, un être visait le premier ennemi visible : on
## pouvait le cribler de flèches depuis l'ombre sans jamais devenir sa cible, et un soigneur d'arrière-
## garde n'était jamais inquiété tant qu'un allié se tenait devant lui.
## `alerter` propage aux camarades proches, à poids réduit : une meute réagit ENSEMBLE. C'est ce qui
## rend un loup effrayant, et c'est ce qui donne enfin un effet au cri de ralliement, qui existait
## comme action et ne réveillait personne.
func _monter_aggro(e: Dictionary, source: String, valeur: float, alerter: bool) -> void:
	if source.is_empty() or source == e.id or valeur <= 0.0 or not e.vivant:
		return
	var att: Dictionary = entites.get(source, {})
	if att.is_empty() or not SimPnj.ennemis(self, e, att):
		return
	var ia: Dictionary = regles.r.get("ia", {})
	var t: Dictionary = e.get("aggro", {})
	t[source] = minf(float(t.get(source, 0.0)) + valeur, float(ia.get("aggro_max", 500.0)))
	e["aggro"] = t
	if not alerter:
		return
	var rayon := int(ia.get("aggro_rayon_alerte", 8))
	var part := float(ia.get("aggro_part_alerte", 0.5))
	for allie in vivants():
		if allie.id == e.id or allie.camp != e.camp or allie.controle == "joueur":
			continue
		if Grille.distance(allie.pos, e.pos) > rayon:
			continue
		_monter_aggro(allie, source, valeur * part, false)   # un seul rebond : pas de proche en proche


## L'aggro s'efface avec le temps : sans elle, une rencontre devient une course à travers l'étage.
## Rendue chaque tour de décision, elle laisse un être rentrer chez lui quand plus rien ne le retient.
func _decroitre_aggro(e: Dictionary) -> void:
	var ia: Dictionary = regles.r.get("ia", {})
	var d := float(ia.get("aggro_decroissance", 0.12))
	if d <= 0.0 or not e.has("aggro"):
		return
	var t: Dictionary = e.aggro
	var oubli := float(ia.get("aggro_seuil_oubli", 1.0))
	for k in t.keys():
		t[k] = float(t[k]) - d
	for k in t.keys().duplicate():
		if float(t[k]) < oubli:
			t.erase(k)
			if str(e.get("cible", "")) == str(k):
				e.cible = ""   # plus rien ne le retient : il rentre
	if t.is_empty():
		e.erase("aggro")


## Celui qui pèse le plus dans la table d'aggro, s'il est encore vivant ET qu'on le PERÇOIT.
## La distinction a coûté un test avant que je la comprenne : l'aggro dit qui on VEUT, la perception
## dit si on peut y faire quelque chose. Sans le filtre, un être gardait pour cible un joueur passé en
## Discrétion parce qu'il l'avait vu une seconde plus tôt — et toute la furtivité tombait avec.
## Ce que l'aggro décide, c'est LEQUEL des ennemis visibles on vise : l'archer qui vous a blessé plutôt
## que le colosse planté devant vous. Pas de voir à travers les murs.
func _cible_par_aggro(e: Dictionary, seulement_vus: bool = true) -> Dictionary:
	var t: Dictionary = e.get("aggro", {})
	var meilleur := ""
	var poids := 0.0
	for k in t.keys():
		var x: Dictionary = entites.get(str(k), {})
		if x.is_empty() or not x.vivant or not SimPnj.ennemis(self, e, x):
			continue
		if seulement_vus and not voit_ia(e, x):
			continue
		if float(t[k]) > poids:
			poids = float(t[k])
			meilleur = str(k)
	return entites.get(meilleur, {})


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
			if not e.has("maitre") and Grille.distance(e.pos, e.ancre) > int(regles.r.engagement.ia_distance_ancre):
				e.cible = ""   # un compagnon n'a pas d'ancre : son maître en tient lieu (deux compagnons en donjon, 2026-09-04)
	# Voir un ennemi met un peu d'aggro sur lui : c'est ce qui remplace « le plus proche visible ». Un
	# tireur embusque monte alors dans la table de sa victime par ses DEGATS, meme sans etre vu, la ou
	# l'ancienne regle le laissait tranquille tant qu'un allie se tenait devant elle (point 77).
	var ia_agg: Dictionary = regles.r.get("ia", {})
	for vu in vivants():
		if SimPnj.ennemis(self, e, vu) and voit_ia(e, vu):
			_monter_aggro(e, str(vu.id), float(ia_agg.get("aggro_par_vue", 2.0)), false)
	if e.cible.is_empty():
		var meilleure: Dictionary = _cible_par_aggro(e)
		if meilleure.is_empty():
			var dmin := 1 << 30
			for autre in vivants():
				if not SimPnj.ennemis(self, e, autre):
					continue
				var d := Grille.distance(e.pos, autre.pos)
				if d < dmin and voit_ia(e, autre):
					dmin = d
					meilleure = autre
		if not meilleure.is_empty():
			e.cible = meilleure.id
			e.tick_derniere_vue = tick
			e.pos_connue = meilleure.pos
			if _profil_offensif(e):   # un cerf qui voit le joueur ne lui ouvre pas un combat : il prend la cible pour la fuir (IA des créatures, 2026-09-04)
				_engager_combat(e, meilleure)
	return entites.get(e.cible, {})


## Un profil qui attaque à vue : il pondère `attaquer` par `cible_a_portee`. Les proies, les civils, les fuyards et
## les bêtes sauvages (acculées seulement) n'engagent un combat qu'en frappant vraiment — sinon voir un ennemi
## suffisait à mettre le joueur « en combat » avec une bête qui fuit, et le monde s'arrêtait pour un cerf.
func _profil_offensif(e: Dictionary) -> bool:
	return profils_ia.get(str(e.get("ai_profile", "")), {}).get("considerations", {}).get("attaquer", {}).has("cible_a_portee")


## Considérations normalisées (0-1) par action candidate ; une action infaisable est absente.
func _actions_candidates(e: Dictionary, cible: Dictionary, profil: Dictionary, tick: int) -> Dictionary:
	var c := {}
	var a_cible := not cible.is_empty()
	var sante_basse := float(e.sante) / float(e.sante_max) < float(profil.get("seuil_fuite_sante", 0.25)) / maxf(0.1, SimPnj.facteur_trait(self, e, "courage"))   # le peureux fuit plus tôt (traits)
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
	# L'heure du repos : une bete paisible dort quand ce n'est pas son heure. Les nocturnes font
	# l'inverse — c'est le meme drapeau, lu a l'envers (point 77). Seuls les profils qui ponderent
	# `heure_de_repos` le voient : rien ne change pour un garde ou un assaillant.
	var nocturne: bool = "nocturne" in e.get("tags", [])
	var repos: bool = (SimTerrain.est_nuit(self) != nocturne) and not a_cible
	c["attendre"] = {"vigueur_basse": 1.0 if e.vigueur < 20 else 0.0, "calme": 0.0 if a_cible else 1.0,
		"heure_de_repos": 1.0 if repos else 0.0}
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
			# À un pas de sa cible quand elle est prise, il y est : sinon deux cents habitants piétinaient sans fin
			# autour de leur coin (designer 2026-09-05 : « les PNJ se sentent obligés de bouger constamment »).
			var arrive: bool = cible_r == e.pos or (Grille.distance(e.pos, cible_r) <= 1 and (not grille.occupant(cible_r).is_empty() or grille.bloque_passage(cible_r)))
			c["routine"] = {"hors_poste": 0.0 if arrive else 1.0}
	if not a_cible and not e.get("fuite", false) and lieu == "camp":
		for autre in vivants():   # une menace en vue sans être engagé : les proies et les civils fuient
			if SimPnj.ennemis(self, e, autre) and Grille.distance(e.pos, autre.pos) <= 8 and voit_ia(e, autre):
				c["fuir"] = {"menace_en_vue": 1.0, "joueur_proche": 1.0 if Grille.distance(e.pos, autre.pos) <= 6 else 0.0, "sante_basse": 1.0 if sante_basse else 0.0}
				e["menace"] = autre.id
				break
	return c


## La lumière qu'un être porte (Éclairage) : le plus lumineux de ses objets en main, 0-100.
func lumiere_de(e: Dictionary) -> int:
	# La LUMINOSITE DE LA MATIERE compte autant que celle de la fiche. On ne lisait que le champ
	# `luminosite` pose a la main sur l'objet — la torche a 70 — et jamais `stats.luminosite`, qui
	# vient des matieres assemblees. Une lampe taillee dans une matiere lumineuse ne brillait donc pas,
	# alors que la fiche du materiau annonce une luminosite. Une stat qu'on montre au joueur et que
	# rien ne lit est une promesse en l'air (designer 2026-09-03 : « t'es sur que les autres 9 stats
	# sont vraiment utilisees ? » — non, et voici les deux qui ne l'etaient pas).
	var lum := 0
	for slot in ["main_principale", "main_secondaire"]:
		var it: Dictionary = items.get(e.get("equipement", {}).get(slot, ""), {})
		lum = maxi(lum, int(it.get("luminosite", 0)))
		lum = maxi(lum, int(float(it.get("stats", {}).get("luminosite", 0.0))))
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
		# La TRANSPARENCE DE LA MATIERE ouvre le mur : « transparence >= 50 -> la tuile laisse passer
		# lumiere et regard (fenetres, serres) » (Application des stats de materiau). On ne lisait que
		# la transparence du CONTENU de tuile, jamais celle de la matiere — un mur de verre arretait
		# donc la lumiere exactement comme un mur de granit.
		var seuil_t := int(GameData.config("combat_rules").get("stats_materiau", {}).get("transparence_seuil", 50))
		var trans_mat := int(float(GameData.catalogues.materials.get(grille.materiau_de(p), {}).get("stats", {}).get("transparence", 0.0)))
		if c.get("bloque_vue", false) and int(c.get("transparence", 0)) < seuil_t and trans_mat < seuil_t and not grille.meubles.has(gi):
			continue   # un mur est éclairé mais ne laisse rien passer — sauf s'il est de verre
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
	if lieu == "camp" and SimTerrain.est_nuit(self) and not ("vision_nocturne" in e.get("tags_acquis", [])):
		var lum := lumiere_a(autre.pos)
		if lum <= 0:
			portee *= float(SimTerrain._cycle(self).get("vision_nuit", 0.6))
		else:
			portee *= 1.0 + float(lum) / 100.0 * float(regles.r.engagement.get("lumiere_detection", 0.5))
	if "pas_silencieux" in autre.get("tags_acquis", []):   # Effets d'équipement : détecté de moins loin
		portee *= float(regles.r.effets_equipement.silence_mult)
	portee *= 1.0 - discretion_reduction(autre)   # IA des créatures : la Discrétion de la cible raccourcit le cône
	portee *= float(Etres.mult_statuts(e, "detection", statuts_defs))   # Aveuglement : l'observateur ne voit plus
	if not SimLieux.zones_sur(self, autre.pos, "brume").is_empty() or not SimLieux.zones_sur(self, e.pos, "brume").is_empty():
		return false   # Voile de brume : ni vu, ni voyant
	return Grille.distance(e.pos, autre.pos) <= maxi(int(regles.r.engagement.get("portee_min", 1)), int(portee)) and grille.ligne_de_vue(e.pos, autre.pos)


## Ce que la Discrétion d'un être retire à la portée à laquelle on le repère (IA des créatures) : 0 à
## `discretion_max_pct`. La nuit vaut `cycle.discretion_nuit` niveaux de plus ; en garde, on ne se cache pas.
func discretion_reduction(e: Dictionary) -> float:
	var en: Dictionary = regles.r.engagement
	if bool(e.get("garde", false)):
		return 0.0
	var niveau := float(regles.niveau(e.get("competences_eff", {}), "discretion"))
	if SimTerrain.est_nuit(self):
		niveau += float(SimTerrain._cycle(self).get("discretion_nuit", 4))
	return minf(float(en.get("discretion_max_pct", 0.6)), niveau * float(en.get("discretion_par_niveau", 0.02)))


## Le coin de la place d'un PNJ : un point de la place tiré de son identifiant (Villes B1 : deux cents habitants qui
## visent la même tuile se bloquent tous, et chacun refait son chemin — chacun a son coin).
func _coin_de_place(e: Dictionary) -> Vector2i:
	var place: Vector2i = e.get("place", e.ancre)
	var r := maxi(1, int(GameData.config("villes").get("rayon_place", 6)) - 1)
	var h := str(e.id).hash()
	var coin := place + Vector2i(posmod(h, 2 * r + 1) - r, posmod(h / 31, 2 * r + 1) - r)
	return coin if grille.dans(coin) and not grille.bloque_passage(coin) else place


## La plage horaire d'un profil à l'heure `h` : {activite, debut} — « poste » par défaut, début 0.
func _plage_routine(profil: Dictionary, h: float) -> Dictionary:
	var res := {"activite": "poste", "debut": 0.0}
	for plage in profil.get("horaires", {}).keys():
		var parts: PackedStringArray = str(plage).split("-")
		var a := float(parts[0])
		var b := float(parts[1])
		if (a <= b and h >= a and h < b) or (a > b and (h >= a or h < b)):
			res = {"activite": str(profil.horaires[plage]), "debut": a}
	return res


## La cible de la routine horaire d'un PNJ (IA des créatures) : poste, place ou lit selon l'heure — celle de
## `tick` si on le donne (la projection du LOD 2 relit la routine à un autre moment que maintenant).
func _cible_routine(e: Dictionary, profil: Dictionary, tick: int = -1) -> Vector2i:
	var activite := str(_plage_routine(profil, fposmod(SimTerrain.heure(self, tick) - SimPnj.trait_somme(self, e, "horaires_decalage"), 24.0)).activite)   # le lève-tôt vit deux heures en avance (traits)
	if activite == "poste" and bool(profil.get("fetes", false)) and e.has("place") and not Calendrier.fetes_du_jour(Calendrier.date(int((horloge_monde.ticks if tick < 0 else tick) / maxi(1, int(SimTerrain._cycle(self).ticks_par_jour)))), str(e.get("social", {}).get("culture", ""))).is_empty():
		activite = "social"   # un jour de fête, la place toute la journée (Calendrier)
	match activite:
		"lit":
			return e.get("lit", e.ancre)
		"social":
			return _coin_de_place(e)
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
	if cible == e.pos or (Grille.distance(e.pos, cible) <= 1 and (not grille.occupant(cible).is_empty() or grille.bloque_passage(cible))):
		_attendre(e, tick)   # arrivé, ou à côté d'une case prise : on se tient là
		return
	if SimTalents._ia_par_portail(self, e, cible, tick):
		return
	if Grille.distance(e.pos, cible) <= int(GameData.config("planete").routine.astar_sous):
		# Le chemin se garde d'un pas à l'autre tant que la cible et la position sont celles prévues (Villes B1 :
		# recalculer A* à chaque pas de chaque habitant coûtait le quart du tick d'une ville).
		var cache: Dictionary = e.get("chemin_routine", {})
		var chemin: Array = cache.get("chemin", []) if cache.get("cible", Vector2i(-9999, -9999)) == cible and cache.get("depuis", Vector2i(-9999, -9999)) == e.pos else []
		if chemin.is_empty():
			var t0 := Time.get_ticks_usec()
			chemin = grille.chemin(e.pos, cible, Etres.est_volant(e), "", refuse_nage(e), int(GameData.config("planete").routine.get("astar_noeuds_max", 0)))
			_top("ia.chemin_routine", t0)
			chrono["n.chemin_routine"] = float(chrono.get("n.chemin_routine", 0.0)) + 1.0
		if chemin.size() > 0:
			var prochain: Vector2i = chemin[0]
			if _deplacer(e, prochain, tick):   # un pas — ou une porte ouverte sans bouger : le chemin reste bon
				e["chemin_routine"] = {"cible": cible, "depuis": e.pos, "chemin": chemin.slice(1) if e.pos == prochain else chemin, "echecs": 0}
				return
			var echecs := int(cache.get("echecs", 0)) + 1
			if echecs < 3:   # quelqu'un est sur le pas suivant : on attend qu'il passe plutôt que de refaire le chemin
				e["chemin_routine"] = {"cible": cible, "depuis": e.pos, "chemin": chemin, "echecs": echecs}
				_attendre(e, tick)
				return
			e.erase("chemin_routine")
	var meilleur: Vector2i = e.pos
	var dmin := Grille.distance(e.pos, cible)
	var rn := refuse_nage(e)   # l'eau refuse la surcharge : le pas glouton ne la propose pas
	for d in Grille.DIRS:
		var q: Vector2i = e.pos + d
		if grille.dans(q) and not grille.bloque_passage(q) and grille.occupant(q).is_empty() and not grille.dangers.has(grille.idx(q)) and not (rn and SimTerrain.dans_l_eau(self, q) and not SimTerrain.dans_l_eau(self, e.pos)) and Grille.distance(q, cible) < dmin:
			dmin = Grille.distance(q, cible)
			meilleur = q
	if meilleur == e.pos or not _deplacer(e, meilleur, tick):
		_attendre(e, tick)


## Errer : un pas au hasard sur une case libre, sans s'éloigner de plus de 12 tuiles de l'ancrage.
func _ia_errer(e: Dictionary, tick: int) -> void:
	# On tirait une case ADJACENTE au hasard a chaque tick. Une marche au hasard ne s'eloigne que d'une
	# dizaine de tuiles en cent pas : un etre ne se promenait pas, il TREMBLAIT SUR PLACE — un garde ne
	# quittait jamais sa salle, un cerf ne traversait jamais sa clairiere (designer 2026-09-03, point 77).
	# Il a maintenant un BUT : il le rejoint par le chemin, souffle en arrivant, puis en choisit un autre.
	var ia: Dictionary = regles.r.get("ia", {})
	var but: Vector2i = e.get("but_roam", Vector2i(-9999, -9999))
	if int(e.get("roam_pause", 0)) > tick:
		_attendre(e, tick)
		return
	if but.x > -9000 and e.pos != but and grille.dans(but) and not grille.bloque_passage(but):
		_ia_pas_vers(e, but, tick, "")
		return
	if but.x > -9000 and e.pos == but:   # arrive : on souffle, comme une bete qui broute ou un garde qui veille
		e["roam_pause"] = tick + int(ia.get("roam_pause_ticks", 12))
		e.erase("but_roam")
		_attendre(e, tick)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, e.id, tick, "roam"])
	var rayon := int(ia.get("roam_rayon", 14))
	# Une bete PAISIBLE ne se promene pas au hasard : elle va vers ce qui se broute et ce qui se boit.
	# On garde le premier but valable, mais si l'un des essais tombe pres d'une plante ou d'une eau, on
	# le prefere. C'est assez pour que le monde ait l'air d'etre habite par des betes qui font quelque
	# chose, sans inventer un systeme de faim et de soif pour la faune (designer 2026-09-03, point 77).
	var paisible: bool = "paisible" in e.get("tags", [])
	var repli := Vector2i(-9999, -9999)
	for essai in int(ia.get("roam_essais", 12)):
		var q: Vector2i = e.ancre + Vector2i(rng.randi_range(-rayon, rayon), rng.randi_range(-rayon, rayon))
		if not grille.dans(q) or grille.bloque_passage(q) or not grille.occupant(q).is_empty() or q == e.pos:
			continue
		if grille.chemin(e.pos, q, Etres.est_volant(e), "", refuse_nage(e)).is_empty():
			continue   # un but injoignable fait pietiner : on en cherche un autre plutot que de s'entêter
		if paisible and not _pature_proche(q):
			if repli.x < -9000:
				repli = q
			continue
		e["but_roam"] = q
		_ia_pas_vers(e, q, tick, "")
		return
	if repli.x > -9000:   # rien a brouter dans le rayon : on se promene quand meme
		e["but_roam"] = repli
		_ia_pas_vers(e, repli, tick, "")
		return
	_attendre(e, tick)


## Y a-t-il de quoi brouter ou boire a cote de cette tuile ? Une plante, ou de l'eau.
func _pature_proche(t: Vector2i) -> bool:
	for d in Grille.DIRS + [Vector2i.ZERO]:
		var q: Vector2i = t + d
		if not grille.dans(q):
			continue
		if int(grille.niveau_eau.get(grille.idx(q), 0)) > 0:
			return true
		if "plante" in grille.contenu_de(q).get("tags", []):
			return true
	return false


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
	if arme.is_empty() and ("humanoide" in e.get("tags", [])):   # un humanoïde désarmé frappe à mains nues, comme le joueur (compagnons, 2026-09-04)
		arme = arme_mains_nues()
	if not arme.is_empty():
		var fonct: Dictionary = fonctionnalites.get(arme.functionality, {})
		if _cible_atteignable(e, cible, regles.portee_de(fonct, e.get("stats_eff", {})), true):
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
		# Aggro (designer 2026-08-31, point 48) : hors de portée, on s'approche — attendre laissait
		# les bêtes tourner en rond à deux cases du joueur.
		if not cible.is_empty() and cible.vivant:
			_ia_pas_vers(e, cible.pos, tick, str(cible.id))
		else:
			_attendre(e, tick)
		return
	_engager_combat(e, cible)
	if att.type == "creature":
		_lancer_action_creature(e, att.action, cible, tick)
	else:
		# Un humanoïde armé utilise le système standard : garde si l'endurance manque, sinon frappe.
		_attaquer_arme(e, cible, false, tick)


func _ia_pas_vers(e: Dictionary, but: Vector2i, tick: int, ignorer: String) -> void:
	if SimTalents._ia_par_portail(self, e, but, tick):   # Talents de classe : une brèche ouverte sert à tout le monde
		return
	var pas := grille.chemin(e.pos, but, Etres.est_volant(e), ignorer, refuse_nage(e), int(GameData.config("planete").routine.get("astar_noeuds_max", 0)))
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

## Le facteur de dilution d'une forme : 1 / n^exposant, borné par un plancher (combat_rules.surface.dilution).
## Une tuile ne dilue rien ; un carré de neuf frappe à un tiers, pas à un neuvième.
func facteur_dilution(n_tuiles: int) -> float:
	var cfg: Dictionary = regles.r.get("surface", {}).get("dilution", {})
	if n_tuiles <= 1:
		return 1.0
	var f := 1.0 / pow(float(n_tuiles), float(cfg.get("exposant", 0.5)))
	return maxf(f, float(cfg.get("plancher", 0.25)))

## La distance affaiblit (designer 2026-09-01) : 1 / (1 + coef × (portée − 1)), borné par un plancher.
## Frapper loin coûtait des ticks ; ça coûte aussi de la puissance. S'ajoute à la dilution par la surface.
func facteur_distance(portee_max: int) -> float:
	var cfg: Dictionary = regles.r.get("surface", {}).get("portee", {})
	if portee_max <= 1:
		return 1.0
	var f := 1.0 / (1.0 + float(cfg.get("coef", 0.06)) * float(portee_max - 1))
	return maxf(f, float(cfg.get("plancher", 0.4)))

## Les stats d'un matériau tel qu'il sort d'une bête (designer 2026-09-01) : l'espèce est un modificateur
## porté par l'objet — un seul `cuir` au catalogue, et l'ours le durcit là où le serpent l'assouplit.
func stats_materiau(mat: Dictionary, espece: String) -> Dictionary:
	var stats: Dictionary = (mat.get("stats", {}) as Dictionary).duplicate()
	if espece.is_empty():
		return stats
	var def: Dictionary = GameData.catalogues.creatures.get(espece, {})
	if def.is_empty():
		return stats
	var cfg: Dictionary = regles.r.craft.get("materiau_espece", {})
	var st_bete: Dictionary = def.get("corps", {}).get("stats", {})
	var ecart := float(int(st_bete.get("force", 8)) + int(st_bete.get("endurance", 8)) - int(cfg.get("reference", 16)))
	for nom_stat: String in (cfg.get("stats", {}) as Dictionary).keys():
		if not stats.has(nom_stat):
			continue
		var c: Dictionary = cfg.stats[nom_stat]
		var v := float(stats[nom_stat]) + ecart * float(c.get("par_point", 0.0))
		stats[nom_stat] = clampf(v, float(c.get("min", 0.0)), float(c.get("max", 999.0)))
	return stats

# ---------------------------------------------------------------- serments (Création de personnage, point Nen)

## Un serment tient-il encore ? Le prédicat est vérifié en continu ; il se rompt une fois, définitivement.
func serment_tenu(e: Dictionary, sid: String) -> bool:
	if str(sid) in e.get("serments_rompus", []):
		return false
	var d: Dictionary = GameData.catalogues.serments.get(sid, {})
	if d.is_empty():
		return true
	match str(d.predicat):
		"aucune_armure":
			for slot: String in e.get("equipement", {}).keys():
				if str(items.get(str(e.equipement[slot]), {}).get("type", "")) == "armure":
					return false
		"aucune_arme":
			for slot in ["main_principale", "main_secondaire"]:
				if str(items.get(str(e.get("equipement", {}).get(slot, "")), {}).get("type", "")) == "arme":
					return false
		"or_max":
			return int(e.get("or", 0)) <= int(d.bonus.get("seuil", 100))
	return true   # les serments d'abstinence (potion, viande, livre) se rompent sur l'acte, pas sur l'état


## Rompt un serment : le don est perdu pour la partie, et le journal le dit.
func rompre_serment(e: Dictionary, sid: String) -> void:
	if not e.has("serments") or not (str(sid) in e.serments) or (str(sid) in e.get("serments_rompus", [])):
		return
	if not e.has("serments_rompus"):
		e["serments_rompus"] = []
	e.serments_rompus.append(str(sid))
	Etres.recalculer(e, items, GameData.catalogues.affixes, regles)
	EventBus.emettre(&"journal", [&"journal.serment_rompu", {"nom": e.name_key, "serment": GameData.catalogues.serments.get(sid, {}).get("name_key", sid)}])


## Le multiplicateur de dégâts que les serments tenus accordent (Corps nu, Mains nues…).
func mult_serments(e: Dictionary) -> float:
	var m := 1.0
	for sid in e.get("serments", []):
		if serment_tenu(e, str(sid)):
			m *= float(GameData.catalogues.serments.get(str(sid), {}).get("bonus", {}).get("degats_mult", 1.0))
	return m

## L'arme d'une main vide : les poings. Le catalogue avait la compétence, la dureté et l'affinité de sorts
## des mains nues, mais aucune fonctionnalité — donc un personnage désarmé ne pouvait pas frapper.
## La fonctionnalité de combat d'une arme. Un objet équipé qui n'en a pas — une torche, une station
## portative, un bijou glissé en main principale — ne doit pas arrêter la résolution : on frappe alors
## comme à mains nues. Trouvé par le fuzz (graine 909) : lire `portee` sur un dictionnaire vide coupait
## le tick en plein combat, et la partie continuait comme si le coup n'avait jamais eu lieu.
func fonct_arme(arme: Dictionary) -> Dictionary:
	var f: Dictionary = fonctionnalites.get(str(arme.get("functionality", "")), {})
	return f if f.has("portee") else fonctionnalites.get("mains_nues", {})


## L'arme dont on frappe VRAIMENT. Rendre seulement la fonctionnalité des poings ne suffisait pas :
## la résolution continuait ensuite avec l'objet tenu et lisait sur lui une dureté et une qualité qu'un
## meuble ou un bijou n'a pas — le tick s'arrêtait une ligne plus loin (fuzz, graines 55 et 777).
## Un objet qui n'est pas une arme ne le devient pas : on frappe aux poings, l'objet reste en main.
func arme_utilisable(arme: Dictionary) -> Dictionary:
	var f: Dictionary = fonctionnalites.get(str(arme.get("functionality", "")), {})
	return arme if (f.has("portee") and arme.has("durete_base")) else arme_mains_nues()


func arme_mains_nues() -> Dictionary:
	return {"uid": "", "name_key": "item.mains_nues.name", "type": "arme", "functionality": "mains_nues",
		"durete_base": int(regles.r.recolte.get("mains_nues_durete", 1)), "qualite": 1.0, "hands": 0,
		"materiau": "", "affixes": [], "sertissures": {"nombre": 0, "contenu": []}, "tags": ["arme"]}

## Le kit de départ d'un être : les entrées de catalogue marquées `assemble` deviennent de vraies
## instances composées (designer 2026-09-02). Sans ça, une épée de classe n'avait ni matériau, ni
## dureté, ni qualité — juste des slots vides.
func _assembler_kit(e: Dictionary) -> void:
	var prof := int(donjon.get("profondeur", donjon.get("etage", 0)))
	for slot: String in e.get("equipement", {}).keys().duplicate():
		var id := str(e.equipement[slot])
		var fiche_i: Dictionary = GameData.catalogues.items.get(id, {})
		if fiche_i.is_empty() or not ("assemble" in fiche_i.get("tags", [])) or items.get(id, {}).has("composants"):
			continue   # rien à assembler, ou déjà une instance composée
		var inst: Dictionary = SimObjets.generer_objet(self, id, prof, {}, "commun", 0)
		if not inst.is_empty():
			e.equipement[slot] = str(inst.uid)
	var rat: Array = e.get("ratelier", [])
	for k in rat.size():
		var rid := str(rat[k])
		var fiche_r: Dictionary = GameData.catalogues.items.get(rid, {})
		if fiche_r.is_empty() or not ("assemble" in fiche_r.get("tags", [])) or items.get(rid, {}).has("composants"):
			continue
		var inst_r: Dictionary = SimObjets.generer_objet(self, rid, prof, {}, "commun", 0)
		if not inst_r.is_empty():
			rat[k] = str(inst_r.uid)

## Lire un parchemin (designer 2026-09-02) : le sort qu'il porte part SANS RIEN COÛTER — ni mana, ni
## endurance, ni le fait de connaître ses modules. Il ne prend que ses ticks et une charge ; à zéro, il
## tombe en poussière.
func _lire_parchemin(e: Dictionary, uid: String, cible: Vector2i, tick: int) -> bool:
	var it: Dictionary = items.get(uid, {})
	if not (uid in e.sac) or str(it.get("type", "")) != "parchemin" or int(it.get("charges", 0)) <= 0:
		return false
	var plan := plan_sequence(e, it.get("modules", []))
	if not plan.erreurs.is_empty():
		EventBus.emettre(&"journal", [&"journal.parchemin_illisible", {"nom": e.name_key}])
		return false
	plan.ressource = 0   # gratuit : c'est tout l'intérêt du parchemin
	plan["name_key"] = it.get("name_key", "item.parchemin.name")
	SimObjets.identifier(self, it)
	if not capacite_visable(e, plan, cible):
		return false
	it["charges"] = int(it.charges) - 1
	EventBus.emettre(&"journal", [&"journal.parchemin", {"nom": e.name_key, "charges": int(it.charges)}])
	_executer_capacite(e, plan, cible)
	e.compteur = tick + int(plan.ticks)
	if int(it.charges) <= 0:   # le parchemin tombe en poussière
		e.sac.erase(uid)
		EventBus.emettre(&"journal", [&"journal.parchemin_use", {"nom": e.name_key}])
	return true

## La forme d'atteinte d'une portée (designer 2026-09-02) : sans motif, tout le disque ; sinon la figure
## que dessinent les cases où le sort peut être posé. Il faut se placer au lieu de payer des ticks.
static func motif_atteint(motif: String, de: Vector2i, vers: Vector2i) -> bool:
	if motif.is_empty():
		return true
	var dx := absi(vers.x - de.x)
	var dy := absi(vers.y - de.y)
	match motif:
		"ligne":
			return dx == 0 or dy == 0
		"diagonale":
			return dx == dy and dx > 0
		"zigzag":
			return dx > 0 and dy > 0 and absi(dx - dy) <= 1
		"etoile":   # les huit directions : les axes ET les diagonales, rien entre les deux
			return dx == 0 or dy == 0 or dx == dy
	return true


# ---------------------------------------------------------------- l'état des bibliothèques Sim… (Modules de la simulation et le C++, 2026-09-05)
## Ces variables étaient déclarées au fil des sections déplacées ; l'état reste ici, les règles sont dans les modules.
## température et de l'humidité locales (Météo). Retourne l'id d'un état de data/weather_states/.
## La météo d'une cellule à un instant : une fonction pure du bruit spatial lent, du temps, de la
var meteo_force := ""   # tests et arènes : imposer un état météo
var invincible := false   # menu de triche : le joueur ne perd plus de PV (Écrans d'interface)
const RAYON_REVELE := 40   # menu de triche : cellules révélées autour du joueur (l'écran de carte en montre 33)
## Les effets de la météo et du froid/chaud sur le joueur (phase 2, avec la faim).
var _meteo_annoncee: String = ""
var _meteo_courante: String = ""
var _jour_annonce := -1   # le dernier jour dont le journal a dit la date (Calendrier)
var _cache_familles: Dictionary = {}   # (famille, catégories) → candidats : le pool se recalcule sinon à chaque objet
var _cache_hors_attente: Dictionary = {}   # slot + attendues → les matières hors attente et leur poids
var _cache_poids_paliers: Dictionary = {}   # (candidats, niveau) → poids par matériau : le tirage est appelé des milliers de fois par étage


# ---------------------------------------------------------------- délégués vers les bibliothèques Sim… (Modules de la simulation et le C++, 2026-09-05)
## Ce que le client, les tests et les sondes appellent sur la simulation garde sa signature ; les règles vivent dans
## les modules `godot/systems/simulation/`. Écrits par `tools/fragmenter.py`.

# SimLieux

func charger_arene(id: String) -> void:
	SimLieux.charger_arene(self, id)

func charger_camp(joueur: Dictionary = {}, cellule_choisie: Vector2i = Vector2i(-1, -1)) -> void:
	SimLieux.charger_camp(self, joueur, cellule_choisie)

func _verifier_fenetre(e: Dictionary) -> void:
	SimLieux._verifier_fenetre(self, e)

func _projeter_routine(x: Dictionary) -> void:
	SimLieux._projeter_routine(self, x)

func commencer_en_donjon(e: Dictionary) -> bool:
	return SimLieux.commencer_en_donjon(self, e)

func creuser_un_puits(e: Dictionary, tick: int) -> bool:
	return SimLieux.creuser_un_puits(self, e, tick)

func gouffre_etage_vide(etage: int) -> bool:
	return SimLieux.gouffre_etage_vide(self, etage)

func charger_donjon(theme_id: String, graine: int, id_donjon: int, etage: int, joueur: Dictionary = {}) -> void:
	SimLieux.charger_donjon(self, theme_id, graine, id_donjon, etage, joueur)

func zones_sur(pos: Vector2i, type: String = "") -> Array[Dictionary]:
	return SimLieux.zones_sur(self, pos, type)

func _zones_a_l_entree(e: Dictionary, pos: Vector2i, tick: int) -> void:
	SimLieux._zones_a_l_entree(self, e, pos, tick)

func _tiquer_zones(tick: int) -> void:
	SimLieux._tiquer_zones(self, tick)

# SimTerrain

func _memoriser_terrain(t: Vector2i) -> void:
	SimTerrain._memoriser_terrain(self, t)

func _tiquer_eau(tick: int) -> void:
	SimTerrain._tiquer_eau(self, tick)

func courant_de(t: Vector2i) -> Vector2i:
	return SimTerrain.courant_de(self, t)

func _tiquer_courant(tick: int) -> void:
	SimTerrain._tiquer_courant(self, tick)

func _retirer_eau(t: Vector2i, tout: bool = false) -> void:
	SimTerrain._retirer_eau(self, t, tout)

func _retirer_source(t: Vector2i) -> void:
	SimTerrain._retirer_source(self, t)

func _evaporation() -> void:
	SimTerrain._evaporation(self)

func _poser_eau(q: Vector2i, niveau: int) -> void:
	SimTerrain._poser_eau(self, q, niveau)

func _pluie_sur(t: Vector2i) -> bool:
	return SimTerrain._pluie_sur(self, t)

func _tiquer_lave(tick: int) -> void:
	SimTerrain._tiquer_lave(self, tick)

func flammabilite_de(t: Vector2i) -> int:
	return SimTerrain.flammabilite_de(self, t)

func _enflammer(t: Vector2i) -> bool:
	return SimTerrain._enflammer(self, t)

func _tiquer_feux(tick: int) -> void:
	SimTerrain._tiquer_feux(self, tick)

func _arracher(t: Vector2i, durete_max: int) -> bool:
	return SimTerrain._arracher(self, t, durete_max)

func _cible_foudre(rng: RandomNumberGenerator, centre: Vector2i) -> Vector2i:
	return SimTerrain._cible_foudre(self, rng, centre)

func _frapper_foudre(t: Vector2i) -> void:
	SimTerrain._frapper_foudre(self, t)

func _regenerer_terrain_sauvage() -> void:
	SimTerrain._regenerer_terrain_sauvage(self)

func _creuser(e: Dictionary, vers: Vector2i, tick: int) -> bool:
	return SimTerrain._creuser(self, e, vers, tick)

func _donner_materiau(e: Dictionary, mat_id: String, quantite: int, forme: String = "brut", espece: String = "") -> void:
	SimTerrain._donner_materiau(self, e, mat_id, quantite, forme, espece)

func _pile_objet(e: Dictionary, base: String) -> Dictionary:
	return SimTerrain._pile_objet(self, e, base)

func _pile(e: Dictionary, mat_id: String, forme: String, espece: String = "") -> Dictionary:
	return SimTerrain._pile(self, e, mat_id, forme, espece)

# SimCamp

func _coffre_a(vers: Vector2i) -> Dictionary:
	return SimCamp._coffre_a(self, vers)

func _ranger(e: Dictionary, uid: String, vers: Vector2i, tick: int) -> bool:
	return SimCamp._ranger(self, e, uid, vers, tick)

func voyager(e: Dictionary, cell: Vector2i, cout_force: int = -1) -> bool:
	return SimCamp.voyager(self, e, cell, cout_force)

# SimPnj

func replique(pnj: Dictionary, j: Dictionary) -> String:
	return SimPnj.replique(self, pnj, j)

func _distinguer_pnj(e: Dictionary, rng: RandomNumberGenerator) -> void:
	SimPnj._distinguer_pnj(self, e, rng)

func facteur_trait(e: Dictionary, cle: String) -> float:
	return SimPnj.facteur_trait(self, e, cle)

func trait_somme(e: Dictionary, cle: String) -> float:
	return SimPnj.trait_somme(self, e, cle)

func _offrir(e: Dictionary, pnj_id: String, uid: String, tick: int) -> bool:
	return SimPnj._offrir(self, e, pnj_id, uid, tick)

func _former_opinions(cell: Vector2i, v: Dictionary) -> void:
	SimPnj._former_opinions(self, cell, v)

func prix_suggere(uid: String, pnj: Dictionary, acheteur: Dictionary) -> Dictionary:
	return SimPnj.prix_suggere(self, uid, pnj, acheteur)

# SimTerritoire

func _ry() -> Dictionary:
	return SimTerritoire._ry(self)

func revendiquer(e: Dictionary, cell: Vector2i) -> bool:
	return SimTerritoire.revendiquer(self, e, cell)

func changer_role(cell: Vector2i, role: String) -> bool:
	return SimTerritoire.changer_role(self, cell, role)

func residents() -> Array:
	return SimTerritoire.residents(self)

func facteur_humeur(x: Dictionary) -> float:
	return SimTerritoire.facteur_humeur(self, x)

func _assigner(e: Dictionary, pnj_id: String, fonction: String, tick: int, perimetre: String = "") -> bool:
	return SimTerritoire._assigner(self, e, pnj_id, fonction, tick, perimetre)

func desassigner(e: Dictionary, pnj_id: String, renvoyer: bool = false) -> bool:
	return SimTerritoire.desassigner(self, e, pnj_id, renvoyer)

func pieces_de_cellule(cell: Vector2i) -> Array:
	return SimTerritoire.pieces_de_cellule(self, cell)

func _poches_de_strates(theme: Dictionary, etage: int, graine: int, id_donjon: int) -> void:
	SimTerritoire._poches_de_strates(self, theme, etage, graine, id_donjon)

func materiau_mur_etage(theme: Dictionary, etage: int) -> String:
	return SimTerritoire.materiau_mur_etage(self, theme, etage)

func tresors_detectes(e: Dictionary) -> Array[Vector2i]:
	return SimTerritoire.tresors_detectes(self, e)

func niveau_recette(e: Dictionary, rid: String) -> int:
	return SimTerritoire.niveau_recette(self, e, rid)

func _doublon_recette(e: Dictionary, rid: String) -> void:
	SimTerritoire._doublon_recette(self, e, rid)

func a_unique(e: Dictionary, mecanique: String) -> bool:
	return SimTerritoire.a_unique(self, e, mecanique)

# SimTerrain

func dans_l_eau(pos: Vector2i) -> bool:
	return SimTerrain.dans_l_eau(self, pos)

func flotte(uid: String) -> bool:
	return SimTerrain.flotte(self, uid)

func temperature_cellule() -> float:
	return SimTerrain.temperature_cellule(self)

func _maj_etats_meteo() -> void:
	SimTerrain._maj_etats_meteo(self)

func souffle_max(e: Dictionary) -> int:
	return SimTerrain.souffle_max(self, e)

func _tiquer_souffle(nom: String, tick: int) -> void:
	SimTerrain._tiquer_souffle(self, nom, tick)

# SimVilles

func jour_courant() -> int:
	return SimVilles.jour_courant(self)

func date_courante() -> Dictionary:
	return SimVilles.date_courante(self)

func annee_courante() -> int:
	return SimVilles.annee_courante(self)

func annoncer_jour() -> void:
	SimVilles.annoncer_jour(self)

func _nouveau_jour(jour: int) -> void:
	SimVilles._nouveau_jour(self, jour)

func _garnir_marche(x: Dictionary) -> bool:
	return SimVilles._garnir_marche(self, x)

# SimTalents

func vecteur_lieu(pos: Vector2i) -> Dictionary:
	return SimTalents.vecteur_lieu(self, pos)

func mult_mana_lieu(e: Dictionary, plan: Dictionary) -> float:
	return SimTalents.mult_mana_lieu(self, e, plan)

func mult_mana_sources(e: Dictionary) -> float:
	return SimTalents.mult_mana_sources(self, e)

func _invoquer_arme_fantome(e: Dictionary, element: String, tick: int) -> bool:
	return SimTalents._invoquer_arme_fantome(self, e, element, tick)

func _tiquer_armes_fantomes(nom: String, tick: int) -> void:
	SimTalents._tiquer_armes_fantomes(self, nom, tick)

func _bonus_embuscade(e: Dictionary, c: Dictionary) -> int:
	return SimTalents._bonus_embuscade(self, e, c)

func _tiquer_vampires(nom: String, tick: int) -> void:
	SimTalents._tiquer_vampires(self, nom, tick)

func _retirer_statut(e: Dictionary, id: String) -> void:
	SimTalents._retirer_statut(self, e, id)

func _deployer_affut(e: Dictionary, t: Vector2i, tick: int) -> bool:
	return SimTalents._deployer_affut(self, e, t, tick)

func _tirs_d_affuts(nom: String, tick: int) -> void:
	SimTalents._tirs_d_affuts(self, nom, tick)

func _porter_masque(e: Dictionary, id: String, _tick: int) -> bool:
	return SimTalents._porter_masque(self, e, id, _tick)

func _contreparties(e: Dictionary) -> void:
	SimTalents._contreparties(self, e)

func _poser_portail(e: Dictionary, t: Vector2i, tick: int) -> bool:
	return SimTalents._poser_portail(self, e, t, tick)

func portail_utile(e: Dictionary, but: Vector2i) -> Vector2i:
	return SimTalents.portail_utile(self, e, but)

func _ia_par_portail(e: Dictionary, but: Vector2i, tick: int) -> bool:
	return SimTalents._ia_par_portail(self, e, but, tick)

# SimTerritoire

func _piece_du_lit(lit: Vector2i, pieces: Array) -> Dictionary:
	return SimTerritoire._piece_du_lit(self, lit, pieces)

func _recalculer_humeurs() -> void:
	SimTerritoire._recalculer_humeurs(self)

func _nourrir_residents() -> void:
	SimTerritoire._nourrir_residents(self)

func production_de(x: Dictionary) -> Dictionary:
	return SimTerritoire.production_de(self, x)

func _dans_territoire(id: String, f: Callable) -> Variant:
	return SimTerritoire._dans_territoire(self, id, f)

func territoire_de_cellule(cell: Vector2i) -> String:
	return SimTerritoire.territoire_de_cellule(self, cell)

func _maj_contexte() -> void:
	SimTerritoire._maj_contexte(self)

func creer_territoire(id: String, proprietaire: String, tresor: int = 0) -> Dictionary:
	return SimTerritoire.creer_territoire(self, id, proprietaire, tresor)

# SimRoyaumes

func royaume_par_id(id: String) -> Dictionary:
	return SimRoyaumes.royaume_par_id(self, id)

func etat_royaume(id: String) -> Dictionary:
	return SimRoyaumes.etat_royaume(self, id)

func an_de_regne(etat: Dictionary) -> int:
	return SimRoyaumes.an_de_regne(self, etat)

func _nouvelle_ere(id: String, dirigeant: Dictionary) -> void:
	SimRoyaumes._nouvelle_ere(self, id, dirigeant)

func _semaine_royaumes_pays() -> void:
	SimRoyaumes._semaine_royaumes_pays(self)

func _conditions_evenement(id: String, roy: Dictionary, etat: Dictionary, c: Dictionary) -> bool:
	return SimRoyaumes._conditions_evenement(self, id, roy, etat, c)

func _appliquer_evenement(id: String, roy: Dictionary, etat: Dictionary, ev: Dictionary) -> void:
	SimRoyaumes._appliquer_evenement(self, id, roy, etat, ev)

func en_guerre(a: String, b: String) -> bool:
	return SimRoyaumes.en_guerre(self, a, b)

# SimVilles

func _faire_venir_train(nom: String, centre: Vector2i, v: Dictionary) -> Dictionary:
	return SimVilles._faire_venir_train(self, nom, centre, v)

func _ia_vehicule(e: Dictionary, tick: int) -> void:
	SimVilles._ia_vehicule(self, e, tick)

func _monter(e: Dictionary, id: String, i: Dictionary, tick: int) -> bool:
	return SimVilles._monter(self, e, id, i, tick)

func _descendre_monture(e: Dictionary, tick: int) -> bool:
	return SimVilles._descendre_monture(self, e, tick)

func _acheter_monture(e: Dictionary, id: String, tick: int) -> bool:
	return SimVilles._acheter_monture(self, e, id, tick)

# SimTerritoire

func categorie_economique(it: Dictionary) -> String:
	return SimTerritoire.categorie_economique(self, it)

func _categorie_cle(cle: String) -> String:
	return SimTerritoire._categorie_cle(self, cle)

func _semaine_economie() -> void:
	SimTerritoire._semaine_economie(self)

func _taxe_royaume(or_prod: int) -> void:
	SimTerritoire._taxe_royaume(self, or_prod)

func villes_reliees(centre: Vector2i, distance_max: int) -> Array:
	return SimTerritoire.villes_reliees(self, centre, distance_max)

func _caravanes_du_jour(jour: int) -> void:
	SimTerritoire._caravanes_du_jour(self, jour)

func _arrivee_itinerant(ville: String, origine: Dictionary, jour: int) -> Dictionary:
	return SimTerritoire._arrivee_itinerant(self, ville, origine, jour)

func _semaine_territoire(e: Dictionary) -> void:
	SimTerritoire._semaine_territoire(self, e)

func _structures_speciales() -> int:
	return SimTerritoire._structures_speciales(self)

func previsionnel() -> int:
	return SimTerritoire.previsionnel(self)

func deposer(e: Dictionary, n: int) -> bool:
	return SimTerritoire.deposer(self, e, n)

func retirer(e: Dictionary, n: int) -> bool:
	return SimTerritoire.retirer(self, e, n)

func retirer_stock(e: Dictionary, cle: String) -> bool:
	return SimTerritoire.retirer_stock(self, e, cle)

# SimTalents

func grille_composition(e: Dictionary, id_grille: String = "") -> Dictionary:
	return SimTalents.grille_composition(self, e, id_grille)

func apprendre_grille(e: Dictionary, id: String) -> bool:
	return SimTalents.apprendre_grille(self, e, id)

func choisir_grille(e: Dictionary, id: String) -> bool:
	return SimTalents.choisir_grille(self, e, id)

func emboitement(e: Dictionary, sequence: Array, grilles: Array = []) -> Dictionary:
	return SimTalents.emboitement(self, e, sequence, grilles)

func composer_capacite(e: Dictionary, sequence: Array, nom: String = "", grilles: Array = [], crans: Array = []) -> bool:
	return SimTalents.composer_capacite(self, e, sequence, nom, grilles, crans)

func supprimer_capacite(e: Dictionary, index: int) -> bool:
	return SimTalents.supprimer_capacite(self, e, index)

func talents_de(e: Dictionary) -> Array:
	return SimTalents.talents_de(self, e)

func a_talent(e: Dictionary, id: String) -> bool:
	return SimTalents.a_talent(self, e, id)

# SimElevage

func ame_dans_sac(e: Dictionary) -> String:
	return SimElevage.ame_dans_sac(self, e)

func cout_resurrection(e: Dictionary, uid_ame: String, chez_pretre: bool) -> int:
	return SimElevage.cout_resurrection(self, e, uid_ame, chez_pretre)

func cout_entrainement(e: Dictionary, competence: String) -> int:
	return SimElevage.cout_entrainement(self, e, competence)

func peut_entrainer(pnj: Dictionary, competence: String) -> bool:
	return SimElevage.peut_entrainer(self, pnj, competence)

func _tirer_commande() -> void:
	SimElevage._tirer_commande(self)

func _genome_aleatoire(esp: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	return SimElevage._genome_aleatoire(self, esp, rng)

func _exprimer_loci(sp: Dictionary, cell: Vector2i, naissance: bool) -> void:
	SimElevage._exprimer_loci(self, sp, cell, naissance)

func _heriter(a: Variant, b: Variant, L: Dictionary, rng: RandomNumberGenerator) -> Variant:
	return SimElevage._heriter(self, a, b, L, rng)

func conditions_repro(a: Dictionary, b: Dictionary, ctx: Dictionary) -> Dictionary:
	return SimElevage.conditions_repro(self, a, b, ctx)

func _tirer_chatoyant(rng: RandomNumberGenerator, parent_chatoyant: bool) -> bool:
	return SimElevage._tirer_chatoyant(self, rng, parent_chatoyant)

func _nouveau_specimen(esp_id: String, genome: Dictionary, sexe: String, chatoyant: bool = false) -> Dictionary:
	return SimElevage._nouveau_specimen(self, esp_id, genome, sexe, chatoyant)

func _enregistrer_variete(sp: Dictionary) -> void:
	SimElevage._enregistrer_variete(self, sp)

func _appliquer_paliers_potentiel() -> void:
	SimElevage._appliquer_paliers_potentiel(self)

func paliers_elevage() -> Dictionary:
	return SimElevage.paliers_elevage(self)

func varietes_possibles(esp_id: String) -> int:
	return SimElevage.varietes_possibles(self, esp_id)

func cle_variete(sp: Dictionary) -> String:
	return SimElevage.cle_variete(self, sp)

func _semaine_elevage() -> void:
	SimElevage._semaine_elevage(self)

# SimRoyaumes

func village_a(vers: Vector2i) -> Dictionary:
	return SimRoyaumes.village_a(self, vers)

func population_village(nom: String) -> Array:
	return SimRoyaumes.population_village(self, nom)

func _former_familles(cell: Vector2i, v: Dictionary) -> void:
	SimRoyaumes._former_familles(self, cell, v)

func _semaine_royaumes_pnj() -> void:
	SimRoyaumes._semaine_royaumes_pnj(self)

func tarif_de(uid: String, pnj: Dictionary) -> float:
	return SimRoyaumes.tarif_de(self, uid, pnj)

func royaumes_voisins() -> Array:
	return SimRoyaumes.royaumes_voisins(self)

func relation_royaume(e: Dictionary, roy: Dictionary) -> String:
	return SimRoyaumes.relation_royaume(self, e, roy)

func proposer_accord(e: Dictionary, roy_id: String, type: String) -> bool:
	return SimRoyaumes.proposer_accord(self, e, roy_id, type)

func changer_gouvernance(id: String) -> bool:
	return SimRoyaumes.changer_gouvernance(self, id)

func defense_totale() -> float:
	return SimRoyaumes.defense_totale(self)

func valeur_territoire() -> float:
	return SimRoyaumes.valeur_territoire(self)

func _resoudre_raid_abstrait(force: float, tick: int) -> void:
	SimRoyaumes._resoudre_raid_abstrait(self, force, tick)

func _lancer_raid_reel(force: float, tick: int) -> void:
	SimRoyaumes._lancer_raid_reel(self, force, tick)

# SimCamp

func _pm(vers: Vector2i) -> Vector2i:
	return SimCamp._pm(self, vers)

func _cell_de(vers: Vector2i) -> Vector2i:
	return SimCamp._cell_de(self, vers)

func population_autour(cell: Vector2i) -> int:
	return SimCamp.population_autour(self, cell)

func _stock_etal(pm: Vector2i) -> Array:
	return SimCamp._stock_etal(self, pm)

func regler_marge(delta: float) -> void:
	SimCamp.regler_marge(self, delta)

# SimPnj

func places_escorte(e: Dictionary) -> int:
	return SimPnj.places_escorte(self, e)

func compagnons_de(e: Dictionary, avec_suiveurs: bool = true) -> Array:
	return SimPnj.compagnons_de(self, e, avec_suiveurs)

func suiveur_local(e: Dictionary, id: String, actif: bool) -> bool:
	return SimPnj.suiveur_local(self, e, id, actif)

func _devenir_compagnon(e: Dictionary, x: Dictionary) -> void:
	SimPnj._devenir_compagnon(self, e, x)

func recrutable(e: Dictionary, pnj: Dictionary) -> bool:
	return SimPnj.recrutable(self, e, pnj)

func _recruter(e: Dictionary, pnj_id: String, tick: int) -> bool:
	return SimPnj._recruter(self, e, pnj_id, tick)

# SimPerimetres

func perimetres() -> Dictionary:
	return SimPerimetres.perimetres(self)

func perimetre_de(cell: Vector2i) -> String:
	return SimPerimetres.perimetre_de(self, cell)

func perimetres_de(cell: Vector2i) -> Array:
	return SimPerimetres.perimetres_de(self, cell)

func tuiles_de_perimetre(pid: String) -> Array:
	return SimPerimetres.tuiles_de_perimetre(self, pid)

func creer_perimetre(cell: Vector2i, type: String, tuiles: Array = [], silencieux: bool = false) -> String:
	return SimPerimetres.creer_perimetre(self, cell, type, tuiles, silencieux)

func dessiner_perimetre(a: Vector2i, b: Vector2i, type: String) -> String:
	return SimPerimetres.dessiner_perimetre(self, a, b, type)

func retirer_perimetre(pid: String) -> bool:
	return SimPerimetres.retirer_perimetre(self, pid)

func place_stockage(pid: String) -> int:
	return SimPerimetres.place_stockage(self, pid)

func assigner_stockage(pid: String, pid_stockage: String) -> bool:
	return SimPerimetres.assigner_stockage(self, pid, pid_stockage)

func _batir_maisons() -> int:
	return SimPerimetres._batir_maisons(self)

func _repousser_perimetres() -> void:
	SimPerimetres._repousser_perimetres(self)

func _cellule_base() -> Vector2i:
	return SimPerimetres._cellule_base(self)

func _engager(e: Dictionary, pnj_id: String, tick: int) -> bool:
	return SimPerimetres._engager(self, e, pnj_id, tick)

func _semaine_migrants(e: Dictionary) -> void:
	SimPerimetres._semaine_migrants(self, e)

# SimPnj

func echanger(e: Dictionary, id: String, uid: String, sens: String) -> bool:
	return SimPnj.echanger(self, e, id, uid, sens)

func designer_cible(e: Dictionary, cible_id: String) -> bool:
	return SimPnj.designer_cible(self, e, cible_id)

func ordonner(e: Dictionary, id: String, ordre: String) -> bool:
	return SimPnj.ordonner(self, e, id, ordre)

func _vieillir_semaine(tick: int) -> void:
	SimPnj._vieillir_semaine(self, tick)

func categorie_age(x: Dictionary) -> String:
	return SimPnj.categorie_age(self, x)

func quetes_offertes(pnj: Dictionary, e: Dictionary) -> Array:
	return SimPnj.quetes_offertes(self, pnj, e)

# SimTerrain

func _cycle() -> Dictionary:
	return SimTerrain._cycle(self)

func heure(tick: int = -1) -> float:
	return SimTerrain.heure(self, tick)

func phase(tick: int = -1) -> String:
	return SimTerrain.phase(self, tick)

func est_nuit(tick: int = -1) -> bool:
	return SimTerrain.est_nuit(self, tick)

func saison(tick: int = -1) -> String:
	return SimTerrain.saison(self, tick)

func _saison_info(tick: int = -1) -> Dictionary:
	return SimTerrain._saison_info(self, tick)

func meteo(cell: Vector2i, tick: int = -1) -> String:
	return SimTerrain.meteo(self, cell, tick)

func temperature_ressentie(e: Dictionary) -> Dictionary:
	return SimTerrain.temperature_ressentie(self, e)

# SimSauvegarde

func slot() -> String:
	return SimSauvegarde.slot(self)

func sauvegarder(nom: String = "") -> bool:
	return SimSauvegarde.sauvegarder(self, nom)

func charger_sauvegarde(nom: String = "") -> bool:
	return SimSauvegarde.charger_sauvegarde(self, nom)

# SimFabrication

func stations_de(e: Dictionary) -> Dictionary:
	return SimFabrication.stations_de(self, e)

func recettes_disponibles(e: Dictionary) -> Array[Dictionary]:
	return SimFabrication.recettes_disponibles(self, e)

func _plan_recette(e: Dictionary, r: Dictionary) -> Dictionary:
	return SimFabrication._plan_recette(self, e, r)

func candidats_optionnels(e: Dictionary, r: Dictionary) -> Array:
	return SimFabrication.candidats_optionnels(self, e, r)

func basculer_ingredient(e: Dictionary, rid: String, uid: String) -> void:
	SimFabrication.basculer_ingredient(self, e, rid, uid)

func harmonie_prevue(plan: Dictionary) -> Dictionary:
	return SimFabrication.harmonie_prevue(self, plan)

# SimVilles

func _entrer_interieur(e: Dictionary, pos: Vector2i) -> bool:
	return SimVilles._entrer_interieur(self, e, pos)

# SimLieux

func _remonter(e: Dictionary) -> bool:
	return SimLieux._remonter(self, e)

func _sortir(e: Dictionary) -> bool:
	return SimLieux._sortir(self, e)

func _boss_vaincu() -> bool:
	return SimLieux._boss_vaincu(self)

# SimObjets

func ajouter(def_id: String, pos: Vector2i, controle: String) -> Dictionary:
	return SimObjets.ajouter(self, def_id, pos, controle)

func _reapprovisionner(x: Dictionary) -> void:
	SimObjets._reapprovisionner(self, x)

func _garnir_stock(e: Dictionary, selection: Array) -> void:
	SimObjets._garnir_stock(self, e, selection)

func generer_objet(base_id: String, profondeur: int, provenance: Dictionary = {}, rarete: String = "", nb_affixes: int = -1) -> Dictionary:
	return SimObjets.generer_objet(self, base_id, profondeur, provenance, rarete, nb_affixes)

func _habiller_pnj(e: Dictionary, def: Dictionary, culture_id: String = "") -> void:
	SimObjets._habiller_pnj(self, e, def, culture_id)

# SimPnj

func ennemis(a: Dictionary, b: Dictionary) -> bool:
	return SimPnj.ennemis(self, a, b)

func relation_de(pnj: Dictionary, e: Dictionary) -> int:
	return SimPnj.relation_de(self, pnj, e)

func reputation(e: Dictionary, pnj: Dictionary, acte: String) -> void:
	SimPnj.reputation(self, e, pnj, acte)

func palier_info(pnj: Dictionary, e: Dictionary) -> int:
	return SimPnj.palier_info(self, pnj, e)

# SimVilles

func _peupler_fenetre() -> void:
	SimVilles._peupler_fenetre(self)

func _semaine_betail() -> void:
	SimVilles._semaine_betail(self)

# SimObjets

func donner(e: Dictionary, uid: String) -> void:
	SimObjets.donner(self, e, uid)

func nom_objet(uid: String) -> Dictionary:
	return SimObjets.nom_objet(self, uid)

func vecteur_objet(it: Dictionary) -> Dictionary:
	return SimObjets.vecteur_objet(self, it)

func inconnu(it: Dictionary) -> bool:
	return SimObjets.inconnu(self, it)

func identifier(it: Dictionary) -> void:
	SimObjets.identifier(self, it)

func _equiper(e: Dictionary, uid: String, tick: int) -> bool:
	return SimObjets._equiper(self, e, uid, tick)

func _jeter(e: Dictionary, uid: String, tick: int) -> bool:
	return SimObjets._jeter(self, e, uid, tick)

func _rendre_rare(e: Dictionary, rng: RandomNumberGenerator) -> void:
	SimObjets._rendre_rare(self, e, rng)

func _perimer_butin(tick: int) -> void:
	SimObjets._perimer_butin(self, tick)

func _poser_contenant(pos: Vector2i, uids: Array, type: String) -> void:
	SimObjets._poser_contenant(self, pos, uids, type)

func _respawn(e: Dictionary) -> bool:
	return SimObjets._respawn(self, e)

func _sertir(e: Dictionary, objet: String, gemme: String, tick: int) -> bool:
	return SimObjets._sertir(self, e, objet, gemme, tick)

func _lire(e: Dictionary, objet: String, tick: int) -> bool:
	return SimObjets._lire(self, e, objet, tick)

func _drop(cible: Dictionary, source: String) -> void:
	SimObjets._drop(self, cible, source)

