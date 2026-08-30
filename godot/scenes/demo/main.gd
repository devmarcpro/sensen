extends Node2D
## Prototype de combat — le CLIENT : rend l'état de la Simulation et lui envoie des intentions.
## Il ne décide de rien (Contraintes permanentes, règle 1) ; il rythme seulement l'avancement
## des horloges d'action pour que l'œil suive. Tout est dessiné en polygones — aucun asset.
## La lisibilité EST le game feel (Combat tactique sur grille) : timeline, coûts sur les tuiles
## atteignables, prévisualisation des dégâts, télégraphes, journal.

const TW := 40            # largeur d'une tuile à l'écran
const TH := 20            # hauteur du losange
const HSTEP := 8          # pixels par niveau de hauteur
const DELAI_PAS := 0.12   # secondes réelles entre deux pas d'une horloge de combat (lisibilité)
const BUDGET_ATTEIGNABLE := 12   # ticks : rayon des coûts affichés
const RAYON_VUE := 20            # tuiles dessinées autour du joueur (une cellule fait taille_cellule², 64 depuis le 2026-08-30)
var centre_terrain := Vector2i(-99, -99)   # centre de la dernière passe statique du terrain
var vue_version := -1                      # version du champ de vue dessiné (brouillard de guerre)
var centre_brouillard := Vector2i(-99, -99) # centre de la dernière passe du brouillard

var sim: Simulation
var arenes: Array[String] = []
var arene_courante := 0
var joueur_id := ""
var chemin_en_cours: Array[Vector2i] = []
var minuterie_pas := 0.0
var minuterie_ui := 0.0
var minuterie_clavier := 0.0        # cadence des pas au clavier (ZQSD maintenu)
var hotbar_sel := -1                 # l'action sélectionnée dans la hotbar (1 → 0), −1 = aucune
var lourde_armee := false            # la prochaine attaque au clic est une lourde
var visee_objet := ""                # une bombe sélectionnée dans la hotbar, à lancer au clic
var survol := Vector2i(-1, -1)
var journal: Array[String] = []
var telegraphes: Dictionary = {}   # id → action engagée
var atteignables: Dictionary = {}
var camera_offset := Vector2.ZERO
var profil_sans_ui := false        # mesure de perf : saute la mise à jour du texte
var profil_sans_terrain := false   # mesure de perf : saute le dessin des tuiles
var visee := -1                    # capacité en cours de visée (index), -1 sinon
var ecran_fin: Array[String] = []  # récapitulatif du dernier combat (écran de fin), vide sinon
var ecrans: Ecrans                 # inventaire, atelier, feuille (scenes/demo/ecrans.gd)
var minimap: Minimap               # coin haut-droit (Décision — Minimap en 2D)
var ambiance: CanvasModulate       # la lumière du cycle jour-nuit (un « uniform global »)
var lumieres: Node2D               # halos additifs des sources locales la nuit
var voiles: Node2D                 # le voile par tuile du donjon (mélange normal : l'additif ne peut pas assombrir)
var carte: Carte                   # la carte du monde (M), aussi le choix de la case de départ
var fiche_en_attente: Dictionary = {}   # la fiche créée, en attendant le choix de la case de départ
var minuterie_autosave := 300.0    # autosave toutes les 5 minutes réelles (Sauvegarde)
var creation: Dictionary = {}      # l'écran de création, tant que le personnage n'existe pas
var titre_ouvert := false          # l'écran principal (Écrans d'interface) : le monde derrière est un décor, l'entrée est bloquée
var xp_cumul: Dictionary = {}      # XP du joueur reçue dans la fenêtre en cours : clé → total (XP de combat)
var xp_fenetre := 0.0              # secondes restantes avant de « lâcher » le cumul en flottant + journal
var xp_flottants: Array = []       # [{lignes, t}] : les textes qui montent au-dessus du joueur
var gros_flottants: Array = []     # [{texte, pos, couleur, t}] : CRITIQUE / RATÉ en gros au-dessus d'un être
var graine_monde := -1             # la graine choisie à l'écran Monde, portée à la simulation
var fiche_monde: Dictionary = {}   # la fiche créée, en attente de l'écran Monde
const STATS := ["force", "dexterite", "endurance", "volonte", "perception", "charisme"]
var zoom := 1.0

var terrain: Terrain              # couche statique : les tuiles, dessinées une fois (perf É0)
var hud: Hud                      # couche au-dessus des êtres : barres, garde, télégraphes, jauges
var hud_ecran: HudEcran           # le HUD fixe à l'écran : compas-horloge, pentagramme, barres, hotbar (Écrans d'interface)
var chargement_restant := 0.0     # écran de chargement entre cellules (Grille continue) : secondes restantes, 0 = fermé
var chargement_cellule := Vector2i.ZERO
var chargement: ColorRect         # le voile noir de l'écran de chargement, sur le CanvasLayer
var chargement_texte: Label
var brouillard: Brouillard        # couche du brouillard de guerre, au-dessus du terrain et des êtres
var noeuds_vegetaux: Dictionary = {}   # index de tuile → Vegetal (billboards des arbres et plantes de la fenêtre)
var noeuds: Dictionary = {}       # id d'être → nœud creature.tscn (le paperdoll)
const SCENE_CREATURE := preload("res://scenes/entities/creature.tscn")

@onready var ui: Label = $CanvasLayer/Info
@onready var ui_droite: Label = $CanvasLayer/Droite
@onready var ui_bas: Label = $CanvasLayer/Bas   # journal + aide en bas : le centre de l'écran reste au joueur


## La couche statique du terrain : ses commandes de dessin persistent d'une image à l'autre.
class Terrain extends Node2D:
	var proprio: Node2D
	func _draw() -> void:
		proprio._dessiner_terrain(self)


## Le brouillard de guerre : une couche à part, redessinée seule quand le champ de vue change
## (le terrain, lui, reste statique) — opaque sur le jamais-vu, translucide sur le mémorisé.
class Brouillard extends Node2D:
	var proprio: Node2D
	func _draw() -> void:
		proprio._dessiner_brouillard(self)


## La couche d'interface au-dessus des êtres (z fixe, toujours visible).
class Hud extends Node2D:
	var proprio: Node2D
	func _draw() -> void:
		proprio._dessiner_hud(self)


func _ready() -> void:
	terrain = Terrain.new()
	terrain.proprio = self
	terrain.z_index = -1
	add_child(terrain)
	brouillard = Brouillard.new()
	brouillard.proprio = self
	brouillard.z_as_relative = false
	brouillard.z_index = 150
	add_child(brouillard)
	hud = Hud.new()
	hud.proprio = self
	hud.z_as_relative = false
	hud.z_index = 200
	add_child(hud)
	EventBus.damage_dealt.connect(func(src: String, _c: String, _d: int, _det: Dictionary) -> void: if noeuds.has(src): noeuds[src].frapper())
	arenes.assign(GameData.catalogues.get("prototype_arenas", {}).keys())
	arenes.sort()
	EventBus.journal.connect(_sur_journal)
	EventBus.coup_critique.connect(func(_att: String, cible_id: String, mult: float) -> void:
		if sim != null and sim.entites.has(cible_id):
			gros_flottants.append({"texte": tr("ui.critique").format({"mult": "%.1f" % mult}), "pos": sim.entites[cible_id].pos, "couleur": Color(1.0, 0.85, 0.3), "t": 0.0}))
	EventBus.coup_rate.connect(func(att_id: String) -> void:
		if sim != null and sim.entites.has(att_id):
			gros_flottants.append({"texte": tr("ui.rate"), "pos": sim.entites[att_id].pos, "couleur": Color(0.75, 0.75, 0.75), "t": 0.0}))
	EventBus.xp_gagnee.connect(func(id: String, cle: String, xp: int) -> void:
		if id == joueur_id and xp > 0:
			xp_cumul[cle] = int(xp_cumul.get(cle, 0)) + xp
			xp_fenetre = 0.4)
	EventBus.fenetre_recentree.connect(func(_o: Vector2i) -> void:
		_apres_changement_de_grille()
		_ouvrir_chargement())
	EventBus.action_engaged.connect(func(id: String, a: Dictionary) -> void: telegraphes[id] = a)
	EventBus.action_resolved.connect(func(id: String, _a: Dictionary) -> void: telegraphes.erase(id))
	EventBus.combat_ended.connect(_sur_fin_de_combat)
	EventBus.expedition_terminee.connect(_sur_fin_d_expedition)
	EventBus.controle_change.connect(func(id: String) -> void:
		joueur_id = id
		vue_version = -1
		terrain.queue_redraw()
		queue_redraw())
	EventBus.tile_changed.connect(func(p: Vector2i) -> void:
		terrain.queue_redraw()
		if sim != null:
			sim.lumiere_sale = true
		lumieres.queue_redraw()
		voiles.queue_redraw()
		var i := sim.grille.idx(p) if sim != null else -1
		if noeuds_vegetaux.has(i):
			noeuds_vegetaux[i].queue_free()
			noeuds_vegetaux.erase(i))
	GameData.donnees_rechargees.connect(_charger)
	ecrans = Ecrans.new()
	ecrans.main = self
	add_child(ecrans)
	hud_ecran = HudEcran.new()
	hud_ecran.main = self
	$CanvasLayer.add_child(hud_ecran)
	chargement = ColorRect.new()   # l'écran de chargement : par-dessus tout, fermé par défaut
	chargement.color = Color(0.02, 0.02, 0.03, 1.0)
	chargement.set_anchors_preset(Control.PRESET_FULL_RECT)
	chargement.mouse_filter = Control.MOUSE_FILTER_STOP
	chargement.visible = false
	$CanvasLayer.add_child(chargement)
	chargement_texte = Label.new()
	chargement_texte.set_anchors_preset(Control.PRESET_CENTER)
	chargement_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chargement_texte.add_theme_font_size_override("font_size", 18)
	chargement.add_child(chargement_texte)
	ambiance = CanvasModulate.new()
	add_child(ambiance)
	voiles = Node2D.new()
	voiles.z_as_relative = false
	voiles.z_index = 139
	voiles.draw.connect(_dessiner_voiles)
	add_child(voiles)
	lumieres = Node2D.new()
	lumieres.z_as_relative = false
	lumieres.z_index = 140
	var mat_add := CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lumieres.material = mat_add
	lumieres.draw.connect(_dessiner_lumieres)
	add_child(lumieres)
	minimap = Minimap.new()
	minimap.main = self
	$CanvasLayer.add_child(minimap)
	carte = Carte.new()
	carte.main = self
	add_child(carte)
	EventBus.chunk_explored.connect(func(_c: Vector2i) -> void: minimap.rafraichir(true))
	EventBus.sauvegarde_faite.connect(func(nom: String) -> void: _log(tr("journal.sauvegarde").format({"nom": nom})))
	var tutoriels := Tutoriels.new()
	tutoriels.afficher = func(texte: String) -> void: _log("💡 " + texte)
	add_child(tutoriels)
	_charger()
	if not (OS.get_cmdline_user_args().has("--sans-creation") or DisplayServer.get_name() == "headless"):
		_ouvrir_titre()   # le jeu s'ouvre sur l'écran principal (Écrans d'interface, 2026-08-30)


## L'écran principal : par-dessus l'arène de décor, monde en pause, entrée bloquée hors du panneau.
func _ouvrir_titre() -> void:
	titre_ouvert = true
	creation = {}
	fiche_en_attente = {}
	carte.fermer()
	minimap.visible = false
	hud_ecran.queue_redraw()
	ecrans.ouvrir("titre")


## Nouvelle partie : l'écran de création du personnage, puis l'écran Monde, puis la carte (case de départ).
func _nouvelle_partie() -> void:
	ecrans.fermer()
	titre_ouvert = false
	minimap.visible = true
	creation = {"race": 0, "classe": 0, "stat": 0, "points": {}, "annee": 1000}
	ui.text = _texte_creation()


## Continuer / Charger : la sauvegarde `nom` ; sans elle, retour au titre.
func _charger_partie(nom: String = "monde") -> void:
	ecrans.fermer()
	titre_ouvert = false
	minimap.visible = true
	arene_courante = arenes.size()
	if sim.charger_sauvegarde(nom):
		joueur_id = ""
		for e in sim.vivants():
			if e.controle == "joueur":
				joueur_id = e.id
		_apres_changement_de_grille()
		_log(tr("journal.chargement"))
	else:
		_log(tr("journal.pas_de_sauvegarde"))
		_ouvrir_titre()


## Écran Monde validé : le monde est généré avec la graine choisie, puis la carte s'ouvre pour la case de départ.
func _commencer_monde() -> void:
	ecrans.fermer()
	titre_ouvert = false
	minimap.visible = true
	arene_courante = arenes.size()   # une partie commence au camp, sur le monde (Début de partie)
	_charger(fiche_monde)
	_kit_de_test()
	fiche_en_attente = fiche_monde
	fiche_monde = {}
	carte.ouvrir("depart")


## Les sauvegardes présentes (dossiers de user://sauvegardes/), pour l'écran Charger.
static func sauvegardes_presentes() -> Array[String]:
	var noms: Array[String] = []
	var d := DirAccess.open(Sauvegarde.RACINE)
	if d == null:
		return noms
	for nom in d.get_directories():
		if Sauvegarde.existe(nom):
			noms.append(nom)
	noms.sort()
	return noms


## L'écran de création : R race, C classe, ↑↓ stat, +/− points, ← → année de naissance, Entrée.
## Le nom et la description d'un talent (Talents de classe / de race) pour l'écran de création.
func _texte_talent(id: String) -> String:
	if id.is_empty():
		return tr("ui.creation.sans_talent")
	var t: Dictionary = GameData.catalogues.get("talents", {}).get(id, {})
	if t.is_empty():
		return id
	return "%s — %s" % [tr(t.name_key), tr(t.desc_key)]


func _texte_creation() -> String:
	var races: Array = GameData.catalogues.races.keys()
	var classes: Array = _classes_visibles()
	races.sort()
	classes.sort()
	var race: String = races[creation.race % races.size()]
	var classe: String = classes[creation.classe % classes.size()]
	var cl: Dictionary = GameData.entree("classes", classe)
	var total := 30 + int(cl.get("points_creation_bonus", 0))
	var utilises := 0
	for st in STATS:
		utilises += int(creation.points.get(st, 0))
	var prog: Progression = Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	var signe := prog.signe(int(creation.annee))
	var l: Array[String] = [tr("ui.creation.titre"), tr("ui.creation.race").format({"race": tr(GameData.entree("races", race).name_key)}),
		tr("ui.creation.classe").format({"classe": tr(cl.name_key), "talent": _texte_talent(str(cl.get("talent", "")))}),
		tr("ui.creation.talent_race").format({"talent": _texte_talent(str(GameData.entree("races", race).get("talent", "")))}),
		tr("ui.creation.points").format({"restants": total - utilises, "total": total})]
	for i in STATS.size():
		var st: String = STATS[i]
		var base := 5 + int(creation.points.get(st, 0)) + int(GameData.entree("races", race).bonus_stats.get(st, 0)) + int(cl.bonus_stats.get(st, 0))
		l.append(("▶ " if i == creation.stat else "   ") + "%s : %d" % [tr("stat." + st), base])
	l.append(tr("ui.creation.signe").format({"annee": creation.annee, "element": tr("element." + signe.element), "animal": tr("animal." + signe.animal)}))
	l.append(tr("ui.creation.aide"))
	return "\n".join(l)


func _creer_personnage() -> void:
	var races: Array = GameData.catalogues.races.keys()
	var classes: Array = _classes_visibles()
	races.sort()
	classes.sort()
	var prog := Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	var fiche := Etres.creer_personnage("creature.aventurier.name", races[creation.race % races.size()], classes[creation.classe % classes.size()], creation.points, int(creation.annee), prog)
	fiche.capacites = GameData.entree("creatures", "aventurier").get("capacites", []).duplicate(true)
	if not fiche.has("modules_connus"):
		fiche["modules_connus"] = []
	for cap in fiche.capacites:   # les modules des capacités de départ sont connus : on peut les recombiner (Structure compétences-modules-slots)
		for m in cap.get("modules", []):
			if not (str(m) in fiche.modules_connus):
				fiche.modules_connus.append(str(m))
	creation = {}
	var interactif := DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--sans-creation")
	if interactif:
		# Début de partie : l'écran Monde (graine), puis la carte pour choisir sa case (Écrans d'interface).
		fiche_monde = fiche
		graine_monde = randi() % 1000000
		titre_ouvert = true
		ecrans.ouvrir("monde")
		return
	_charger(fiche)
	_kit_de_test()


## Mode test (Grimoires et manuels, décision du 2026-08-30) : tous les modules du catalogue au joueur à la nouvelle partie.
func _kit_de_test() -> void:
	if not bool(GameData.config("combat_rules").get("modules", {}).get("tout_au_depart", false)):
		return
	var j := joueur()
	if not j.is_empty():
		sim.triche(j, "modules")


## Le joueur a cliqué sa case de départ (Début de partie) : le camp y est établi.
func _choisir_depart(cell: Vector2i) -> void:
	if fiche_en_attente.is_empty() or sim.monde == null or not sim.monde.surface.terre_a(cell):
		return
	sim.monde.fermer()
	sim = Simulation.new(0x68EE)
	sim.graine_monde = graine_monde
	sim.fiche_joueur = fiche_en_attente
	sim.charger_camp({}, cell)
	_kit_de_test()   # le joueur est recréé sur la case choisie : le kit de test aussi
	fiche_en_attente = {}
	joueur_id = ""
	for e in sim.vivants():
		if e.controle == "joueur":
			joueur_id = e.id
	_apres_changement_de_grille()
	carte.fermer()
	_log(tr("journal.depart_choisi").format({"x": cell.x, "y": cell.y, "biome": tr(GameData.catalogues.biomes.get(str(sim.camp_sauve.get("biome", "")), {}).get("name_key", ""))}))


## Voyage rapide depuis la carte — ou revendication d'une cellule contiguë au territoire (Expansion territoriale).
func _voyager(cell: Vector2i) -> void:
	if sim.monde != null and sim.monde.revendicable(cell, sim.horloge_monde.ticks):
		sim.revendiquer(joueur(), cell)
		carte.dessin.queue_redraw()
		return
	if sim.voyager(joueur(), cell):
		carte.fermer()
		_apres_changement_de_grille()


func _charger(fiche: Dictionary = {}) -> void:
	if fiche.is_empty() and sim != null and not sim.fiche_joueur.is_empty():
		fiche = sim.fiche_joueur
	sim = Simulation.new(0x68EE)
	sim.graine_monde = graine_monde
	sim.fiche_joueur = fiche
	if arene_courante >= arenes.size():
		sim.charger_camp()   # Tab après les arènes : le camp de base (E sur l'entrée : le donjon)
	else:
		sim.charger_arene(arenes[arene_courante])
	joueur_id = ""
	for e in sim.vivants():
		if e.controle == "joueur":
			joueur_id = e.id
	chemin_en_cours.clear()
	telegraphes.clear()
	journal.clear()
	terrain.queue_redraw()
	for n in noeuds.values():
		n.queue_free()
	noeuds.clear()
	for v in noeuds_vegetaux.values():
		v.queue_free()
	noeuds_vegetaux.clear()
	vue_version = -1
	centre_brouillard = Vector2i(-99, -99)
	brouillard.queue_redraw()
	# Les rappels de touches ne s'affichent plus à l'écran (demande du designer, 2026-08-28) : ils vivent dans le README.
	visee = -1
	_recentrer()


## La simulation a changé de grille (descente) : la vue statique et les nœuds repartent de zéro.
## L'écran de chargement (Grille continue) : ouvert quand la fenêtre se recentre au camp, jamais en donjon.
func _ouvrir_chargement() -> void:
	if sim == null or sim.lieu != "camp" or sim.monde == null or profil_sans_ui:
		return
	var j := joueur()
	if j.is_empty():
		return
	chargement_restant = float(GameData.config("planete").get("monde", {}).get("chargement_s", 0.6))
	chargement_cellule = sim.monde.cellule_de(j.pos)
	var biome: Dictionary = GameData.catalogues.biomes.get(str(sim.monde.surface.biome_a(j.pos.x, j.pos.y)), {})
	chargement_texte.text = tr("ui.chargement").format({"x": chargement_cellule.x, "y": chargement_cellule.y, "biome": tr(str(biome.get("name_key", "")))})
	chargement.visible = true
	sim.horloge_monde.active = false   # le monde n'avance pas pendant le chargement (c'est un temps mort, pas une ellipse)
	chemin_en_cours.clear()


func _fermer_chargement() -> void:
	chargement_restant = 0.0
	chargement.visible = false
	if sim != null and sim.horloge_monde != null:
		sim.horloge_monde.active = true


func _apres_changement_de_grille() -> void:
	terrain.queue_redraw()
	for v in noeuds_vegetaux.values():
		v.queue_free()
	noeuds_vegetaux.clear()
	vue_version = -1
	centre_brouillard = Vector2i(-99, -99)
	brouillard.queue_redraw()
	for n in noeuds.values():
		n.queue_free()
	noeuds.clear()
	chemin_en_cours.clear()
	telegraphes.clear()


func _recentrer() -> void:
	scale = Vector2.ONE * zoom
	var j := joueur()
	if j.is_empty():
		return
	var taille := get_viewport_rect().size
	# Le joueur est centré à l'écran, la vue le suit (Écrans d'interface, décision du 2026-08-27) ;
	# elle suit le paperdoll qui glisse, pas la tuile, pour ne pas sauter.
	var p: Vector2 = noeuds[joueur_id].position if noeuds.has(joueur_id) else _ecran(j.pos, sim.grille.h(j.pos))
	position = taille * 0.5 - p * zoom


func joueur() -> Dictionary:
	return sim.entites.get(joueur_id, {})


func _sur_journal(cle: String, params: Dictionary) -> void:
	var p := {}
	if params.has("x") and params.has("y") and (params.x is int) and (params.y is int):   # le journal parle en tuiles locales à la cellule
		var cl := _coord_locale(Vector2i(int(params.x), int(params.y)))
		p["x"] = cl.x
		p["y"] = cl.y
	for k in params.keys():
		if p.has(k):
			continue
		var v: Variant = params[k]
		if v is Dictionary and v.has("base"):
			p[k] = nom_objet(v)
		else:
			p[k] = tr(v) if (v is String and v.contains(".")) else v
	_log(tr(cle).format(p))


func _log(t: String) -> void:
	journal.append(t)
	if journal.size() > 9:
		journal.pop_front()


# ---------------------------------------------------------------- rythme (client)

## La lumière ambiante du cycle (interpolée entre les phases) ; en donjon et en arène, il fait jour.
func _maj_ambiance() -> void:
	if sim == null or sim.lieu != "camp" or sim.monde == null:
		ambiance.color = Color.WHITE
		lumieres.queue_redraw()
		voiles.queue_redraw()
		return
	var c: Dictionary = GameData.config("planete").cycle
	var h := sim.heure()
	var l: Dictionary = c.lumiere
	var jour := Color(l.jour[0], l.jour[1], l.jour[2])
	var nuit := Color(l.nuit[0], l.nuit[1], l.nuit[2])
	var aube := Color(l.aube[0], l.aube[1], l.aube[2])
	var crep := Color(l.crepuscule[0], l.crepuscule[1], l.crepuscule[2])
	var col := nuit
	if h >= float(c.aube[0]) and h < float(c.aube[1]):
		col = nuit.lerp(aube, (h - float(c.aube[0])) / (float(c.aube[1]) - float(c.aube[0]))).lerp(jour, maxf(0.0, (h - float(c.aube[0])) / (float(c.aube[1]) - float(c.aube[0])) - 0.5) * 2.0)
	elif h >= float(c.jour[0]) and h < float(c.jour[1]):
		col = jour
	elif h >= float(c.crepuscule[0]) and h < float(c.crepuscule[1]):
		col = jour.lerp(crep, (h - float(c.crepuscule[0])) / (float(c.crepuscule[1]) - float(c.crepuscule[0])) * 0.5).lerp(nuit, maxf(0.0, (h - float(c.crepuscule[0])) / (float(c.crepuscule[1]) - float(c.crepuscule[0])) - 0.5) * 2.0)
	ambiance.color = col
	lumieres.queue_redraw()
	voiles.queue_redraw()


## Les halos des sources locales (meubles lumineux, torche en main), visibles quand l'ambiance baisse.
func _dessiner_lumieres() -> void:
	if sim == null:
		return
	var g := sim.grille
	var j := joueur()
	if j.is_empty():
		return
	for fi in sim.feux.keys():   # Météo : les flammes (couche additive, visibles de jour comme de nuit)
		var ft := g.pos_de(int(fi))
		if Grille.distance(ft, j.pos) > RAYON_VUE or not g.decouvert.has(int(fi)):
			continue
		var fc := _ecran(ft, g.h(ft))
		var ph := float((Time.get_ticks_msec() / 90 + int(fi)) % 6) / 6.0
		lumieres.draw_colored_polygon(PackedVector2Array([fc + Vector2(-9, 2), fc + Vector2(0, -22 - 8.0 * ph), fc + Vector2(9, 2)]), Color(1.0, 0.45, 0.1, 0.85))
		lumieres.draw_colored_polygon(PackedVector2Array([fc + Vector2(-5, 2), fc + Vector2(0, -12 - 6.0 * ph), fc + Vector2(5, 2)]), Color(1.0, 0.85, 0.3, 0.9))
		if sim.lieu == "camp" and ambiance.color.r <= 0.9:
			_halo(fc, (1.0 - ambiance.color.r) * 0.8)
	if sim.lieu == "donjon":
		return   # le voile du donjon est dessiné par la couche `voiles` (mélange normal)
	if sim.lieu != "camp" or ambiance.color.r > 0.9:
		return
	var force := 1.0 - ambiance.color.r
	for gi in g.meubles.keys():
		var m: Dictionary = GameData.entree("meubles", str(g.meubles[gi]))
		var lum := int(m.get("luminosite", 0))
		if lum <= 0:
			continue
		var t := g.pos_de(int(gi))
		if Grille.distance(t, j.pos) > RAYON_VUE:
			continue
		_halo(_ecran(t, g.h(t)), float(lum) / 100.0 * force)
	for slot in ["main_principale", "main_secondaire"]:
		var it: Dictionary = sim.items.get(j.equipement.get(slot, ""), {})
		if int(it.get("luminosite", 0)) > 0:
			_halo(_ecran(j.pos, g.h(j.pos)), float(it.luminosite) / 100.0 * force)


## Le voile du donjon (Éclairage) : l'ambiante n'entre pas, chaque tuile vue est voilée selon la carte de lumière.
func _dessiner_voiles() -> void:
	if sim == null or sim.lieu != "donjon":
		return
	var g := sim.grille
	var j := joueur()
	if j.is_empty():
		return
	for gi in j.get("vue", {}).keys():
		var t := g.pos_de(int(gi))
		if Grille.distance(t, j.pos) > RAYON_VUE or Grille.distance(t, j.pos) <= 1:   # le personnage et sa tuile restent nets dans le noir (lisibilité)
			continue
		var a := 0.8 * (1.0 - float(sim.niveau_lumiere(t)) / 15.0)
		if a > 0.02:
			var c := _ecran(t, g.h(t))
			var col := Color(0.02, 0.02, 0.05, a)
			voiles.draw_primitive(PackedVector2Array([c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0), c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)]), PackedColorArray([col, col, col, col]), PackedVector2Array())


func _halo(c: Vector2, intensite: float) -> void:
	var r := 22.0 + 60.0 * intensite
	for k in 4:
		var f := 1.0 - float(k) / 4.0
		lumieres.draw_circle(c + Vector2(0, -6), r * f, Color(1.0, 0.85, 0.55, 0.12 * intensite))


## À la fermeture : attendre la pré-génération en thread (elle lit GameData, qui va disparaître).
func _exit_tree() -> void:
	if sim != null and sim.monde != null:
		sim.monde.fermer()


func _process(delta: float) -> void:
	if not creation.is_empty():
		ui.text = _texte_creation()
		ui_bas.text = ""
		ui_droite.text = ""
		return
	var j := joueur()
	if j.is_empty():
		return
	if titre_ouvert:   # écran principal : rien n'avance derrière
		return
	if chargement_restant > 0.0:   # écran de chargement : le monde est en pause, le temps sert à pré-générer
		chargement_restant -= delta
		if sim.monde != null:
			sim.monde.pregenerer_voisins()
		if chargement_restant <= 0.0:
			_fermer_chargement()
		return
	_recentrer()
	# ZQSD (8 directions d'écran) : Z = haut, S = bas, Q = gauche, D = droite ; deux touches = diagonale.
	minuterie_clavier -= delta
	if sim.attente.has(joueur_id) and visee < 0 and minuterie_clavier <= 0.0:
		var dir := Vector2i.ZERO
		if Input.is_key_pressed(KEY_Z):
			dir += Vector2i(-1, -1)
		if Input.is_key_pressed(KEY_S):
			dir += Vector2i(1, 1)
		if Input.is_key_pressed(KEY_D):
			dir += Vector2i(1, -1)
		if Input.is_key_pressed(KEY_Q):
			dir += Vector2i(-1, 1)
		dir = Vector2i(signi(dir.x), signi(dir.y))
		if dir != Vector2i.ZERO:
			chemin_en_cours.clear()
			minuterie_clavier = 0.05
			if not sim.intention(joueur_id, {"type": "deplacer", "vers": j.pos + dir}):
				_log(tr("journal.inaccessible"))
	# En attente d'intention : on consomme la file d'ordres du joueur (un pas par décision).
	if sim.attente.has(joueur_id) and not chemin_en_cours.is_empty():
		var cible: Vector2i = chemin_en_cours[0]
		if not sim.intention(joueur_id, {"type": "deplacer", "vers": cible}):
			chemin_en_cours.clear()
			_log(tr("journal.inaccessible"))
		else:
			chemin_en_cours.pop_front()
	# Les horloges de combat n'avancent qu'à l'action : le client les fait avancer pas à pas.
	minuterie_pas -= delta
	if minuterie_pas <= 0.0:
		minuterie_pas = DELAI_PAS
		for nom in sim.combats.keys():
			sim.pas(nom)
	_maj_noeuds(delta)
	if Grille.distance(j.pos, centre_terrain) > RAYON_VUE / 3:
		terrain.queue_redraw()   # le joueur s'éloigne du centre de la passe statique
	if int(j.get("vue_version", 0)) != vue_version or Grille.distance(j.pos, centre_brouillard) > RAYON_VUE / 3:
		brouillard.queue_redraw()   # son champ de vue a changé : seul le brouillard se redessine
	hud.queue_redraw()
	_maj_atteignables()
	minuterie_ui -= delta
	if minuterie_ui <= 0.0 and not profil_sans_ui:
		minuterie_ui = 0.05
		_maj_ui()
		minimap.rafraichir()
		_maj_ambiance()
	if xp_fenetre > 0.0:   # l'XP de l'action : cumulée, puis affichée d'un bloc
		xp_fenetre -= delta
		if xp_fenetre <= 0.0 and not xp_cumul.is_empty():
			var lignes: Array[String] = []
			var resume: Array[String] = []
			for cle in xp_cumul.keys():
				lignes.append("+%d %s" % [int(xp_cumul[cle]), _nom_xp(str(cle))])
				resume.append("%s +%d" % [_nom_xp(str(cle)), int(xp_cumul[cle])])
			xp_flottants.append({"lignes": lignes, "t": 0.0})
			_log(tr("journal.xp").format({"liste": " · ".join(resume)}))
			xp_cumul = {}
	for f in xp_flottants:
		f.t += delta
	xp_flottants = xp_flottants.filter(func(f: Dictionary) -> bool: return f.t < 1.6)
	for f in gros_flottants:
		f.t += delta
	gros_flottants = gros_flottants.filter(func(f: Dictionary) -> bool: return f.t < 1.2)
	if not gros_flottants.is_empty():
		hud.queue_redraw()
	minuterie_autosave -= delta
	if minuterie_autosave <= 0.0:
		minuterie_autosave = 300.0
		sim.sauvegarder()
	queue_redraw()


## Un nœud creature.tscn par être vivant, configuré depuis sa fiche : position, profondeur, rig.
func _maj_noeuds(delta: float = 0.0) -> void:
	var vivants := {}
	var j := joueur()
	var k := 1.0 - exp(-delta * 12.0)   # glissement exponentiel : ≈ 0,2 s pour rejoindre la tuile
	for e in sim.vivants():
		vivants[e.id] = true
		var n: Paperdoll = noeuds.get(e.id)
		# Hors de la fenêtre de vue : le nœud reste, mais n'est ni dessiné ni redessiné.
		if n != null and not j.is_empty() and (Grille.distance(e.pos, j.pos) > RAYON_VUE or not sim.voit(j, e.pos)):
			n.visible = false   # hors fenêtre, ou hors du champ de vue (brouillard de guerre)
			continue
		if n == null:
			n = SCENE_CREATURE.instantiate()
			var rig: Dictionary = GameData.entree("rigs", str(e.corps.silhouette))
			n.configurer(e, rig, sim.items, sim.fonctionnalites, GameData.config("palette_materiaux"))
			n.dessine_apres = _dessiner_occulteurs
			add_child(n)
			noeuds[e.id] = n
		n.e = e
		var cible := _ecran(e.pos, sim.grille.h(e.pos))
		if not n.visible or n.position.distance_to(cible) > TW * 3.0:
			n.position = cible   # apparition ou saut (changement de grille, respawn) : pas de glissement
		else:
			n.position = n.position.lerp(cible, k)
		n.visible = true
		n.z_index = _profondeur(e.pos)
		n.queue_redraw()
	for id in noeuds.keys().duplicate():
		if not vivants.has(id):
			noeuds[id].queue_free()
			noeuds.erase(id)


## Les tuiles plus hautes devant un être sont redessinées par-dessus lui, à sa profondeur :
## le relief l'occulte comme dans une passe unique (appelé par le paperdoll après son dessin).
func _dessiner_occulteurs(n: Paperdoll) -> void:
	var g := sim.grille
	var e: Dictionary = n.e
	var he := g.h(e.pos)
	var base := _ecran(e.pos, he)
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 1), Vector2i(1, 2)]:
		var t: Vector2i = e.pos + d
		if g.dans(t) and (g.h(t) > he or (g.bloque_passage(t) and not ("vegetation" in g.contenu_de(t).get("tags", [])))):
			n.draw_set_transform(-base)
			_dessine_tuile(n, t)
			n.draw_set_transform(Vector2.ZERO)


func _maj_atteignables() -> void:
	var j := joueur()
	atteignables = {}
	if j.vivant and sim.attente.has(joueur_id) and sim.en_combat(j):
		atteignables = sim.grille.atteignables(j.pos, BUDGET_ATTEIGNABLE, Etres.est_volant(j))


# ---------------------------------------------------------------- entrées → intentions

## Les classes proposées à la création : sans les cachées (Talents de classe).
func _classes_visibles() -> Array:
	var res: Array = []
	for id in GameData.catalogues.classes.keys():
		if not ("cache" in GameData.catalogues.classes[id].get("tags", [])):
			res.append(id)
	res.sort()
	return res


func _unhandled_input(ev: InputEvent) -> void:
	if titre_ouvert:   # écran principal : seules les touches du panneau passent
		if ev is InputEventKey and ev.pressed and not ev.echo and ecrans.est_ouvert():
			ecrans.touche(ev)
		return
	if not creation.is_empty():
		if ev is InputEventKey and ev.pressed and not ev.echo:
			match ev.keycode:
				KEY_R: creation.race += 1
				KEY_C: creation.classe += 1
				KEY_UP: creation.stat = posmod(creation.stat - 1, STATS.size())
				KEY_DOWN: creation.stat = posmod(creation.stat + 1, STATS.size())
				KEY_LEFT: creation.annee -= 1
				KEY_RIGHT: creation.annee += 1
				KEY_KP_ADD, KEY_EQUAL, KEY_PLUS:
					var st: String = STATS[creation.stat]
					var cl: Dictionary = GameData.entree("classes", _classes_visibles()[creation.classe % GameData.catalogues.classes.size()])
					var total := 30 + int(cl.get("points_creation_bonus", 0))
					var utilises := 0
					for s2 in STATS:
						utilises += int(creation.points.get(s2, 0))
					if utilises < total and int(creation.points.get(st, 0)) < 10:
						creation.points[st] = int(creation.points.get(st, 0)) + 1
				KEY_KP_SUBTRACT, KEY_MINUS:
					var st: String = STATS[creation.stat]
					creation.points[st] = maxi(0, int(creation.points.get(st, 0)) - 1)
				KEY_ENTER, KEY_KP_ENTER:
					_creer_personnage()
			ui.text = _texte_creation() if not creation.is_empty() else ui.text
		return
	var j := joueur()
	if not j.is_empty() and not j.vivant and ev is InputEventKey and ev.pressed and not ev.echo:
		sim.intention(joueur_id, {"type": "respawn"})
		_apres_changement_de_grille()
		return
	if not ecran_fin.is_empty() and ((ev is InputEventMouseButton and ev.pressed) or (ev is InputEventKey and ev.pressed)):
		ecran_fin.clear()
		return
	if ev is InputEventMouseMotion:
		survol = _tuile_sous(get_local_mouse_position())
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var haut: bool = ev.button_index == MOUSE_BUTTON_WHEEL_UP
			if ev.ctrl_pressed:   # Ctrl + molette : le zoom (contrôles, décision du 2026-08-30)
				zoom = minf(2.0, zoom * 1.1) if haut else maxf(0.5, zoom / 1.1)
				scale = Vector2.ONE * zoom
			elif not ecrans.est_ouvert():   # molette seule : la hotbar tourne, en boucle
				var j_m := joueur()
				var n := hotbar_entrees(j_m).size() if not j_m.is_empty() else 0
				if n > 0:
					_hotbar(posmod(hotbar_sel + (-1 if haut else 1), n))
			return
		elif ev.button_index == MOUSE_BUTTON_LEFT and not j.is_empty() and j.vivant:
			_clic(_tuile_sous(get_local_mouse_position()), lourde_armee)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and not j.is_empty() and j.vivant:
			_contexte(_tuile_sous(get_local_mouse_position()))
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ecrans.est_ouvert() and ecrans.courant == "composer" and ecrans.composeur.nom.has_focus():
			return   # on tape le nom du sort : les lettres vont au champ, pas au jeu
		if ecrans.est_ouvert() and ecrans.touche(ev):
			return
		if carte.ouverte:
			if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
				if carte.mode == "depart":
					fiche_en_attente = {}
					carte.fermer()
				return
			carte.touche(ev)
			return
		match ev.keycode:
			KEY_TAB:
				ecrans.basculer("menu")
			KEY_V:
				ecrans.basculer("triche")   # menu de triche : tout obtenir, tout déclencher
			KEY_E:
				_interagir()
			KEY_R:
				if sim.attente.has(joueur_id):
					if not sim.intention(joueur_id, {"type": "ramasser"}):
						_log(tr("journal.rien_a_ramasser"))
			KEY_ESCAPE:
				visee = -1
				hotbar_sel = -1
				lourde_armee = false
				visee_objet = ""
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
				_hotbar(9 if ev.keycode == KEY_0 else ev.keycode - KEY_1)


## La hotbar (Écrans d'interface, contrôles) : armes du râtelier, capacités, lourde, garde, attendre — dix cases.
func hotbar_entrees(j: Dictionary) -> Array:
	var res: Array = []
	for k in j.ratelier.size():
		res.append({"type": "arme", "ref": j.ratelier[k], "nom": tr(sim.items[j.ratelier[k]].name_key)})
	for k in j.get("capacites", []).size():
		res.append({"type": "capacite", "ref": k, "nom": tr(j.capacites[k].get("name_key", j.capacites[k].id))})
	for uid in j.sac:   # les bombes du sac (Explosions)
		var it: Dictionary = sim.items.get(uid, {})
		if it.has("bombe"):
			res.append({"type": "objet", "ref": uid, "nom": tr("ui.hotbar.objet").format({"nom": tr(it.name_key), "n": int(it.get("quantite", 1))})})
	res.append({"type": "lourde", "ref": "", "nom": tr("ui.hotbar.lourde")})
	res.append({"type": "garde", "ref": "", "nom": tr("ui.hotbar.garde")})
	res.append({"type": "attendre", "ref": "", "nom": tr("ui.hotbar.attendre")})
	return res.slice(0, 10)


## La touche 1 → 0 sélectionne une action : une arme s'équipe et arme le clic, une capacité se vise, la lourde s'arme.
func _hotbar(k: int) -> void:
	var j := joueur()
	if j.is_empty():
		return
	var entrees := hotbar_entrees(j)
	if k >= entrees.size():
		return
	var en: Dictionary = entrees[k]
	chemin_en_cours.clear()
	match str(en.type):
		"arme":
			if j.equipement.get("main_principale", "") != str(en.ref) and j.equipement.get("main_secondaire", "") != str(en.ref):
				sim.intention(joueur_id, {"type": "changer_arme", "item": str(en.ref)})
			hotbar_sel = k
			visee = -1
			lourde_armee = false
		"capacite":
			var plan := sim.plan_capacite(j, int(en.ref))
			if plan.geometrie == "soi":
				sim.intention(joueur_id, {"type": "capacite", "index": int(en.ref), "cible": j.pos})
				visee = -1
			else:
				visee = int(en.ref)
				hotbar_sel = k
			lourde_armee = false
		"objet":
			visee_objet = str(en.ref)
			visee = -1
			hotbar_sel = k
			lourde_armee = false
		"lourde":
			lourde_armee = true
			hotbar_sel = k
			visee = -1
			visee_objet = ""
		"garde":
			sim.intention(joueur_id, {"type": "garde"})
		"attendre":
			sim.intention(joueur_id, {"type": "attendre"})


## Les options possibles sur une tuile (E et clic droit) : dans l'ordre de priorité de E.
func _options_tuile(t: Vector2i) -> Array:
	var res: Array = []
	var j := joueur()
	if j.is_empty() or t.x < 0 or not sim.grille.dans(t):
		return res
	var g := sim.grille
	var d := Grille.distance(j.pos, t)
	var occ := g.occupant(t)
	if not occ.is_empty() and occ != joueur_id:
		var x: Dictionary = sim.entites[occ]
		if ("civil" in x.get("tags", []) or x.has("maitre")) and d <= 2:
			res.append({"id": "parler", "cible": occ})
		if "bete" in x.get("tags", []) and not x.has("maitre") and d <= 1:
			res.append({"id": "apprivoiser", "cible": occ})
		if sim.a_talent(j, "saisie") and d == 1 and str(j.get("porte", "")).is_empty():
			res.append({"id": "saisir", "cible": occ})
		if sim.a_talent(j, "soif_de_sang") and d == 1:
			res.append({"id": "mordre", "cible": occ})
		if sim.a_talent(j, "maitre_du_tempo") and x.camp != j.camp and d <= int(sim.regles.r.talents.maitre_du_tempo.portee):
			res.append({"id": "tempo", "cible": occ})
		res.append({"id": "attaquer", "cible": occ})
		res.append({"id": "lourde", "cible": occ})
		if sim.ennemis(j, x) and not sim.compagnons_de(j).is_empty():   # Compagnons : cibler en priorité
			res.append({"id": "designer", "cible": occ})
		return res
	if t == j.pos:
		if not sim.donjon.is_empty() and sim.donjon.get("escalier") != null and sim.donjon.escalier == t:
			res.append({"id": "descendre", "vers": t})
		if not sim.donjon.is_empty() and sim.donjon.has("entree") and sim.donjon.entree == t:
			res.append({"id": "remonter", "vers": t})
		if sim.lieu == "camp" and sim.monde != null and sim.monde.cellule(sim._cell_de(t)).get("a_donjon", false) and sim.monde.pos_monde(sim._cell_de(t), sim.monde.cellule(sim._cell_de(t)).entree_donjon) == t:
			res.append({"id": "descendre", "vers": t})
		return res
	if not str(j.get("porte", "")).is_empty() and d >= 1 and d <= 3:
		res.append({"id": "lancer_etre", "vers": t})
	if d == 0 and sim.portails.has(t):
		res.append({"id": "traverser"})
	if sim.a_talent(j, "releveur") and d <= int(sim.regles.r.talents.releveur.portee) and g.occupant(t).is_empty():
		for x in sim.entites.values():
			if not x.vivant and x.pos == t and not bool(x.get("releve", false)):
				res.append({"id": "relever", "cible": str(x.id), "nom": tr(x.name_key)})
				break
	if sim.a_talent(j, "sans_chair") and d == 2 and g.dans(t) and not g.bloque_passage(t) and g.occupant(t).is_empty():
		var dm: Vector2i = t - j.pos
		if (dm.x == 0 or dm.y == 0 or absi(dm.x) == absi(dm.y)) and g.bloque_passage(j.pos + Vector2i(signi(dm.x), signi(dm.y))):
			res.append({"id": "traverser_mur", "cible": t})
	if sim.a_talent(j, "affut") and d == 1 and g.dans(t) and not g.bloque_passage(t) and g.occupant(t).is_empty():
		res.append({"id": "affut", "cible": t})
	if d == 0:
		for el in sim.segments_possibles(Etres.arme(j, sim.items)):   # l'arme mixte choisit son segment
			if str(el) != str(j.get("segment_prefere", "")):
				res.append({"id": "segment_prefere", "element": str(el), "nom": tr("element." + str(el))})
		if j.has("segment_prefere"):
			res.append({"id": "segment_dominant"})
	if d == 0 and str(j.corps.get("silhouette", "humanoide")) == "humanoide":
		for el in sim.regles.r.armes_fantomes.elements:
			res.append({"id": "arme_fantome", "element": str(el), "nom": tr("element." + str(el))})
	if d == 0 and sim.a_talent(j, "lune"):
		res.append({"id": "transformer", "forme_humaine": bool(j.get("forme_bestiale", false))})
	if d == 0 and sim.a_talent(j, "masques"):
		for sid in sim.statuts_defs.keys():
			if "masque" in sim.statuts_defs[sid].get("tags", []):
				res.append({"id": "masque", "masque": str(sid), "nom": tr(sim.statuts_defs[sid].name_key)})
	if sim.a_talent(j, "graveur") and d <= int(sim.regles.r.talents.graveur.portee_declenchement):
		for gl in sim.glyphes:
			if gl.pos == t and str(gl.source) == j.id:
				res.append({"id": "declencher_glyphe", "cible": t})
				break
	if sim.a_talent(j, "breche") and d == 1 and g.dans(t) and not g.bloque_passage(t) and g.occupant(t).is_empty() and not sim.portails.has(g.idx(t)):
		res.append({"id": "poser_portail", "cible": t})
	if d != 1:
		return res
	var tags: Array = g.contenu_de(t).get("tags", [])
	var idx := g.idx(t)
	if "meuble" in tags and g.meubles.has(idx):
		var m: Dictionary = GameData.entree("meubles", str(g.meubles[idx]))
		if bool(m.dormir):
			res.append({"id": "dormir", "vers": t})
		if str(m.type_meuble) == "etal" and int(sim.territoire.caisse) > 0:
			res.append({"id": "caisse", "vers": t})
		if int(m.capacite_slots) > 0 and sim.contenants.get(idx, []).size() > 0:
			res.append({"id": "prendre", "vers": t})
	if "contenant" in tags and sim.contenants.get(idx, []).size() > 0:
		res.append({"id": "prendre", "vers": t})
	if "parcelle" in tags:
		res.append({"id": "recolter" if "mure" in tags else "fertiliser", "vers": t})
	if sim.lieu == "camp" and sim.monde != null:
		var vil: Dictionary = sim.village_a(t)
		if not vil.is_empty() and sim.monde.pos_monde(sim._cell_de(t), vil.centre) == t and not sim.monde.claims.has(sim._cell_de(t)):
			res.append({"id": "conquerir", "vers": t})
		if "eau" in tags:
			res.append({"id": "capturer", "vers": t})
	var meuble_id := str(g.meubles.get(g.idx(t), ""))   # Talents de race : les deux meubles de donjon
	if d <= 1 and meuble_id == "source_maudite":
		res.append({"id": "boire_source", "vers": t})
	if d <= 1 and meuble_id == "autel_rituel":
		res.append({"id": "rituel", "vers": t})
	if "plante_sauvage" in tags:
		res.append({"id": "cueillir", "vers": t})
	if "plante" in tags or "arbre" in tags:
		res.append({"id": "creuser", "vers": t})
	if "construit" in tags:
		res.append({"id": "demonter", "vers": t})
	if not g.bloque_passage(t) and g.occupant(t).is_empty() and not g.meubles.has(g.idx(t)) and not g.stations_fixes.has(g.idx(t)):
		res.append({"id": "abaisser", "vers": t})
		res.append({"id": "elever", "vers": t})
	if g.bloque_passage(t) and not ("meuble" in tags) and not ("plante" in tags) and not ("arbre" in tags) and not ("eau" in tags):
		res.append({"id": "creuser", "vers": t})
	if "porte" in sim.grille.contenu_de(t).get("tags", []) and Grille.distance(j.pos, t) == 1:   # ouvrir / fermer une porte adjacente
		res.append({"id": "porte", "vers": t})
	return res


## Exécute une option (E, clic droit).
func _executer_option(opt: Dictionary) -> void:
	var j := joueur()
	if j.is_empty():
		return
	chemin_en_cours.clear()
	match str(opt.id):
		"parler":
			ecrans.ouvrir_dialogue(str(opt.cible))
			return
		"deplacer":
			_clic(opt.vers, false)
			return
	if not sim.attente.has(joueur_id):
		return
	match str(opt.id):
		"attaquer", "lourde":
			if not sim.intention(joueur_id, {"type": "attaquer", "cible": str(opt.cible), "lourde": str(opt.id) == "lourde"}):
				_log(tr("journal.inaccessible"))
		"apprivoiser":
			sim.intention(joueur_id, {"type": "apprivoiser", "cible": str(opt.cible)})
		"saisir":
			sim.intention(joueur_id, {"type": "saisir", "cible": str(opt.cible)})
		"tempo":
			sim.intention(joueur_id, {"type": "tempo", "cible": str(opt.cible)})
		"traverser":
			sim.intention(joueur_id, {"type": "traverser"})
		"porte":
			sim.intention(joueur_id, {"type": "porte", "vers": opt.vers})
		"masque":
			sim.intention(joueur_id, {"type": "masque", "masque": str(opt.masque)})
		"relever":
			sim.intention(joueur_id, {"type": "relever", "cible": str(opt.cible)})
		"mordre":
			sim.intention(joueur_id, {"type": "mordre", "cible": str(opt.cible)})
		"traverser_mur":
			sim.intention(joueur_id, {"type": "traverser_mur", "cible": opt.cible})
		"abaisser":
			sim.intention(joueur_id, {"type": "terrasser", "vers": opt.vers, "sens": -1})
		"elever":
			sim.intention(joueur_id, {"type": "terrasser", "vers": opt.vers, "sens": 1})
		"transformer":
			sim.intention(joueur_id, {"type": "transformer"})
		"arme_fantome":
			sim.intention(joueur_id, {"type": "arme_fantome", "element": str(opt.element)})
		"segment_prefere":
			sim.intention(joueur_id, {"type": "segment_prefere", "element": str(opt.element)})
		"segment_dominant":
			sim.intention(joueur_id, {"type": "segment_prefere", "element": ""})
		"affut":
			sim.intention(joueur_id, {"type": "affut", "cible": opt.cible})
		"declencher_glyphe":
			sim.intention(joueur_id, {"type": "declencher_glyphe", "cible": opt.cible})
		"poser_portail":
			sim.intention(joueur_id, {"type": "poser_portail", "cible": opt.cible})
		"lancer_etre":
			sim.intention(joueur_id, {"type": "lancer_etre", "vers": opt.vers})
		"descendre", "remonter":
			if sim.intention(joueur_id, {"type": str(opt.id)}):
				_apres_changement_de_grille()
			else:
				_log(tr("journal.pas_escalier"))
		"dormir":
			sim.intention(joueur_id, {"type": "dormir", "vers": opt.vers})
		"prendre", "caisse", "recolter":
			sim.intention(joueur_id, {"type": "prendre", "vers": opt.vers})
		"fertiliser":
			if not sim.intention(joueur_id, {"type": "fertiliser", "vers": opt.vers}):
				_log(tr("journal.culture_pas_mure"))
		"conquerir":
			sim.intention(joueur_id, {"type": "conquerir", "vers": opt.vers})
		"capturer":
			sim.intention(joueur_id, {"type": "capturer"})
		"cueillir":
			sim.intention(joueur_id, {"type": "cueillir", "vers": opt.vers})
		"boire_source":
			sim.intention(joueur_id, {"type": "boire_source", "vers": opt.vers})
		"rituel":
			sim.intention(joueur_id, {"type": "rituel", "vers": opt.vers})
		"designer":
			sim.designer_cible(j, str(opt.cible))
		"creuser":
			if not sim.intention(joueur_id, {"type": "creuser", "vers": opt.vers}):
				_log(tr("journal.increusable"))
		"demonter":
			sim.intention(joueur_id, {"type": "demonter", "vers": opt.vers})


## E : la première option de la tuile sous la souris si elle est adjacente, sinon la première autour du joueur.
func _interagir() -> void:
	var j := joueur()
	if j.is_empty():
		return
	var candidates: Array = []
	if survol.x >= 0 and Grille.distance(j.pos, survol) <= 2:
		candidates = _options_tuile(survol)
	if candidates.is_empty():
		candidates = _options_tuile(j.pos)
	if candidates.is_empty():
		for d in Grille.DIRS:
			candidates = _options_tuile(j.pos + d)
			if not candidates.is_empty():
				break
	if candidates.is_empty():
		_log(tr("journal.rien_a_interagir"))
		return
	_executer_option(candidates[0])


## Clic droit : toutes les options de la tuile, dans une liste.
func _contexte(t: Vector2i) -> void:
	var j := joueur()
	if j.is_empty() or t.x < 0:
		return
	var options: Array = _options_tuile(t)
	if Grille.distance(j.pos, t) >= 1 and sim.grille.occupant(t).is_empty():
		options.append({"id": "deplacer", "vers": t})
	ecrans.ouvrir_contexte(t, options)


## Le menu (Tab) : écrans et actions générales.
func _action_menu(id: String) -> void:
	var j := joueur()
	match id:
		"inventaire", "atelier", "feuille", "registre", "capacites":
			ecrans.ouvrir(id)
		"gestion":
			if sim.lieu == "camp":
				ecrans.ouvrir("gestion")
		"carte":
			ecrans.fermer()
			if sim.lieu == "camp":
				carte.ouvrir("voyage")
		"sauvegarder":
			ecrans.fermer()
			if not sim.sauvegarder():
				_log(tr("journal.sauvegarde_impossible"))
		"charger":
			ecrans.fermer()
			if sim.charger_sauvegarde():
				joueur_id = ""
				for e in sim.vivants():
					if e.controle == "joueur":
						joueur_id = e.id
				_apres_changement_de_grille()
				_log(tr("journal.chargement"))
			else:
				_log(tr("journal.pas_de_sauvegarde"))
		"minimap_zoom":
			minimap.cycler_zoom()
			minimap.rafraichir(true)
		"minimap_masquer":
			minimap.visible = not minimap.visible
			minimap.rafraichir(true)
		"arene":
			ecrans.fermer()
			arene_courante = (arene_courante + 1) % (arenes.size() + 1)
			_charger()
		"titre":
			_ouvrir_titre()
		"recharger":
			ecrans.fermer()
			GameData.charger()
			GameData.donnees_rechargees.emit()
			_charger()
		"fermer":
			ecrans.fermer()

func _clic(t: Vector2i, lourde: bool) -> void:
	if t.x < 0:
		return
	var j := joueur()
	if not visee_objet.is_empty():   # une bombe visée : le clic la lance
		if sim.attente.has(joueur_id):
			if sim.intention(joueur_id, {"type": "lancer", "objet": visee_objet, "cible": t}):
				visee_objet = ""
				hotbar_sel = -1
		return
	if visee >= 0:
		if sim.attente.has(joueur_id):
			if not sim.intention(joueur_id, {"type": "capacite", "index": visee, "cible": t}):
				_log(tr("journal.inaccessible"))
			else:
				visee = -1
				hotbar_sel = -1
		return
	var occ := sim.grille.occupant(t)
	if not occ.is_empty() and occ != joueur_id:   # un être : l'attaque avec l'action sélectionnée (les PNJ : clic droit ou E)
		chemin_en_cours.clear()
		if not sim.attente.has(joueur_id):
			return
		var x: Dictionary = sim.entites[occ]
		if not lourde and ("civil" in x.get("tags", []) or x.has("maitre")):
			ecrans.ouvrir_dialogue(occ)
			return
		if not sim.intention(joueur_id, {"type": "attaquer", "cible": occ, "lourde": lourde}):
			var tir := sim.verifier_tir(j, x)
			if not tir.ok:
				_log(tr("journal.tir_refuse").format({"raison": tr("raison." + tir.raison)}))
			else:
				_log(tr("journal.inaccessible"))
		lourde_armee = false
		return
	if Grille.distance(j.pos, t) == 1:
		if sim.grille.bloque_passage(t):
			return
		chemin_en_cours = [t]   # un pas direct : autorise la chute volontaire
		return
	chemin_en_cours = sim.grille.chemin(j.pos, t, Etres.est_volant(j))
	if chemin_en_cours.is_empty() and t != j.pos:
		_log(tr("journal.inaccessible"))

func _tuile_sous(p: Vector2) -> Vector2i:
	var meilleur := Vector2i(-1, -1)
	var meilleure_d := 1e9
	var g := sim.grille
	var j := joueur()
	var cj: Vector2i = j.pos if not j.is_empty() else Vector2i.ZERO
	for y in range(maxi(g.origine.y, cj.y - RAYON_VUE), mini(g.origine.y + g.hauteur_grille, cj.y + RAYON_VUE + 1)):
		for x in range(maxi(g.origine.x, cj.x - RAYON_VUE), mini(g.origine.x + g.largeur, cj.x + RAYON_VUE + 1)):
			var t := Vector2i(x, y)
			var c := _ecran(t, g.h(t))
			var d := c.distance_squared_to(p)
			if d < meilleure_d and d < float(TW * TW) * 0.3:
				meilleure_d = d
				meilleur = t
	return meilleur


# ---------------------------------------------------------------- rendu

## Tuile → écran, en coordonnées LOCALES à la fenêtre chargée : la simulation parle en coordonnées monde
## (cellule × 128 + tuile, jusqu'à ~65 000), mais le rendu ne doit jamais manipuler des pixels à 1e6 —
## précision float32, polygones dégénérés, jitter. L'origine de la fenêtre glissante est soustraite ici, une fois.
func _ecran(t: Vector2i, h: int) -> Vector2:
	var l: Vector2i = t - (sim.grille.origine if sim != null else Vector2i.ZERO)
	return Vector2((l.x - l.y) * TW * 0.5, (l.x + l.y) * TH * 0.5 - h * HSTEP)


## Le nom d'une piste d'XP (XP de combat) : l'élément, la compétence, le module, sinon la clé.
func _nom_xp(cle: String) -> String:
	if cle.begins_with("element_"):
		return tr("element." + cle.substr(8))
	if GameData.catalogues.competences.has(cle):
		return tr(str(GameData.catalogues.competences[cle].get("name_key", cle)))
	if GameData.catalogues.modules.has(cle):
		return tr(str(GameData.catalogues.modules[cle].get("name_key", cle)))
	var cle_tr := "xp." + cle
	var t := tr(cle_tr)
	return t if t != cle_tr else cle


## Une position affichée au joueur : locale à sa cellule (0-127), jamais la coordonnée monde.
func _coord_locale(t: Vector2i) -> Vector2i:
	if sim != null and sim.monde != null and sim.lieu == "camp":
		return t - sim.monde.pos_monde(sim.monde.cellule_de(t), Vector2i.ZERO)
	return t


func _draw() -> void:
	if sim == null:
		return
	var g := sim.grille
	var j := joueur()
	# Superpositions translucides sur les tuiles (atteignables, télégraphes, survol, forme visée).
	for t in atteignables.keys():
		_losange(t, Color(0.9, 0.9, 0.5, 0.28))
	for t in _zones_telegraphes().keys():
		_losange(t, Color(1.0, 0.2, 0.1, 0.5))
	if survol.x >= 0:
		_losange(survol, Color(1, 1, 1, 0.22))
	for b in sim.bombes:
		_losange(b.pos, Color(1.0, 0.4, 0.1, 0.7))
	if not j.is_empty():
		for t in sim.tresors_detectes(j):   # detection_tresors : les contenants à portée, même hors de vue
			_losange(t, Color(1.0, 0.85, 0.2, 0.55))
	if not j.is_empty() and not sim.territoire.get("raid", {}).is_empty():   # Défense et raids : une flèche vers l'assaillant le plus proche
		var plus_proche := Vector2i(-1, -1)
		var dmin := 9999
		for x in sim.vivants():
			if x.camp == "raid":
				var dd := Grille.distance(j.pos, x.pos)
				if dd < dmin:
					dmin = dd
					plus_proche = x.pos
		if dmin > 6 and plus_proche != Vector2i(-1, -1):
			var c0 := _ecran(j.pos, sim.grille.h(j.pos))
			var dir := (_ecran(plus_proche, sim.grille.h(j.pos)) - c0).normalized()
			var pointe := c0 + dir * 70.0
			var perp := Vector2(-dir.y, dir.x)
			draw_primitive(PackedVector2Array([pointe, pointe - dir * 14.0 + perp * 7.0, pointe - dir * 14.0 - perp * 7.0]), PackedColorArray([Color(0.95, 0.2, 0.2, 0.9), Color(0.95, 0.2, 0.2, 0.9), Color(0.95, 0.2, 0.2, 0.9)]), PackedVector2Array())
	for a in sim.affuts:   # les affûts de L'Engrenage
		_losange(a.pos, Color(0.25, 0.25, 0.3, 0.85))
	for pi in sim.portails.keys():   # les brèches du Passeur (clés en position monde)
		if sim.grille.dans(pi):
			_losange(pi, Color(0.6, 0.3, 0.9, 0.7))
	if not sim.donjon.is_empty() and sim.donjon.escalier != null:
		_losange(sim.donjon.escalier, Color(0.9, 0.7, 0.2, 0.6))
	if not sim.donjon.is_empty() and sim.donjon.has("entree"):
		_losange(sim.donjon.entree, Color(0.3, 0.9, 0.5, 0.5))   # la sortie / l'escalier montant
	for z in sim.zones:   # les zones au sol (Racine, Sol vif, Nappe, Brume, Balise) : un liseré à leur teinte
		if not g.dans(z.pos):
			continue
		if bool(z.get("cachee", false)):   # un piège : visible de son poseur et de ses alliés seulement
			var src: Dictionary = sim.entites.get(str(z.get("source", "")), {})
			if src.is_empty() or (src.id != joueur_id and sim.ennemis(j, src)):
				continue
		var cz := _ecran(z.pos, g.h(z.pos))
		_losange(z.pos, COULEUR_ZONE.get(str(z.type), Color(0.7, 0.7, 0.7, 0.35)))
	for gl in sim.glyphes:   # les glyphes : un losange cerclé à la teinte de leur élément
		var cg := _ecran(gl.pos, g.h(gl.pos))
		var teinte := sim.wuxing.teinte(sim.wuxing.dominante(gl.elements)) if not gl.elements.is_empty() else Color(0.8, 0.8, 0.9)
		draw_arc(cg, 7.0, 0.0, TAU, 12, teinte, 2.0)
	if visee < 0 and survol.x >= 0 and not j.is_empty() and not g.occupant(survol).is_empty() and g.occupant(survol) != joueur_id:
		var tir := sim.verifier_tir(j, sim.entites[g.occupant(survol)])
		if tir.has("bloqueur"):
			_losange(tir.bloqueur, Color(1, 0.2, 0.2, 0.45))
	if (hotbar_sel >= 0 or lourde_armee) and survol.x >= 0 and not j.is_empty() and survol != j.pos:   # la ligne de vue (hotbar)
		var vue_ok := g.ligne_de_vue(j.pos, survol)
		draw_line(_ecran(j.pos, g.h(j.pos)), _ecran(survol, g.h(survol)), Color(0.3, 1.0, 0.4, 0.8) if vue_ok else Color(1.0, 0.25, 0.2, 0.8), 2.0)
	if not visee_objet.is_empty() and survol.x >= 0 and not j.is_empty() and sim.items.has(visee_objet):   # le rayon d'une bombe visée
		var rb: int = int(sim.items[visee_objet].bombe.rayon)
		var ok_b: bool = Grille.distance(j.pos, survol) <= int(sim.regles.r.bombes.portee) and g.ligne_de_vue(j.pos, survol)
		for dy in range(-rb, rb + 1):
			for dx in range(-rb, rb + 1):
				var tb := survol + Vector2i(dx, dy)
				if g.dans(tb):
					_losange(tb, Color(1.0, 0.5, 0.1, 0.4) if ok_b else Color(0.5, 0.5, 0.5, 0.3))
	if visee >= 0 and survol.x >= 0 and not j.is_empty():
		var plan := sim.plan_capacite(j, visee)
		var ok := sim.capacite_visable(j, plan, survol)
		for t in sim.tuiles_du_plan(j, plan, survol):   # toutes les formes du plan (no limit), pas seulement la première
			_losange(t, Color(0.3, 0.6, 1.0, 0.45) if ok else Color(0.5, 0.5, 0.5, 0.35))
		if ok:   # l'atterrissage des poussées : une flèche de la case de départ à la case d'arrivée, un losange fantôme
			for mv in sim.prevoir_deplacement(j, plan, survol):
				var a := _ecran(mv.de, g.h(mv.de))
				var b := _ecran(mv.vers, g.h(mv.vers))
				_losange(mv.vers, Color(1.0, 0.85, 0.4, 0.35))
				draw_line(a, b, Color(1.0, 0.85, 0.4, 0.9), 2.0)
				var dv := (b - a).normalized()
				var nv := Vector2(-dv.y, dv.x)
				draw_colored_polygon(PackedVector2Array([b, b - dv * 10.0 + nv * 5.0, b - dv * 10.0 - nv * 5.0]), Color(1.0, 0.85, 0.4, 0.9))
		if bool(plan.get("ligne_de_vue", true)) and survol != j.pos:   # la ligne de vue, dessinée : verte jusqu'à l'obstacle, rouge après
			var obstacle := g.premier_obstacle_vue(j.pos, survol)
			var depart := _ecran(j.pos, g.h(j.pos))
			var arrivee := _ecran(survol, g.h(survol))
			if obstacle == Vector2i(-1, -1):
				draw_line(depart, arrivee, Color(0.4, 1.0, 0.5, 0.8), 2.0)
			else:
				var casse := _ecran(obstacle, g.h(obstacle))
				draw_line(depart, casse, Color(0.4, 1.0, 0.5, 0.8), 2.0)
				draw_line(casse, arrivee, Color(1.0, 0.3, 0.3, 0.7), 2.0)
				draw_line(casse + Vector2(-7, -7), casse + Vector2(7, 7), Color(1.0, 0.3, 0.3, 0.95), 2.0)
				draw_line(casse + Vector2(-7, 7), casse + Vector2(7, -7), Color(1.0, 0.3, 0.3, 0.95), 2.0)
	if not chemin_en_cours.is_empty() and not j.is_empty():
		var pts := PackedVector2Array([_ecran(j.pos, g.h(j.pos))])
		for c in chemin_en_cours:
			pts.append(_ecran(c, g.h(c)))
		draw_polyline(pts, Color(1, 1, 1, 0.55), 2.0)
	for t in atteignables.keys():
		if t == j.pos:
			continue
		var c := _ecran(t, g.h(t)) + Vector2(-6, 4)
		draw_string(ThemeDB.fallback_font, c, str(atteignables[t]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 0.8, 0.8))
	for f in xp_flottants:   # l'XP de l'action, qui monte et s'efface au-dessus du joueur (XP de combat)
		var base := _ecran(j.pos, g.h(j.pos)) + Vector2(-20.0, -52.0 - f.t * 22.0)
		var a: float = clampf(1.6 - f.t, 0.0, 1.0)
		for k in f.lignes.size():
			draw_string(ThemeDB.fallback_font, base + Vector2(0.0, -12.0 * (f.lignes.size() - 1 - k)), str(f.lignes[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.9, 0.5, a))


## Un polygone convexe dessiné en éventail de triangles par draw_primitive : draw_colored_polygon triangule en float32
## et juge dégénérés les polygones aux coordonnées monde (~1e6 px) — « Invalid polygon data » (brouillard, sol, blocs).
static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var cols := PackedColorArray([col, col, col])
	for i in range(1, pts.size() - 1):
		ci.draw_primitive(PackedVector2Array([pts[0], pts[i], pts[i + 1]]), cols, PackedVector2Array())


func _losange(t: Vector2i, col: Color) -> void:
	# draw_primitive (deux triangles, sans triangulation) : les coordonnées monde sont grandes (~1e6 px) et la
	# triangulation en float32 de draw_colored_polygon jugeait le losange dégénéré (« Invalid polygon data »).
	var c := _ecran(t, sim.grille.h(t))
	var pts := PackedVector2Array([c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0), c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)])
	draw_primitive(pts, PackedColorArray([col, col, col, col]), PackedVector2Array())


## La passe statique : toutes les tuiles, une seule fois (appelée par la couche Terrain).
func _dessiner_terrain(ci: CanvasItem) -> void:
	if sim == null or profil_sans_terrain:
		return
	var g := sim.grille
	var j := joueur()
	var c: Vector2i = j.pos if not j.is_empty() else g.origine + Vector2i(g.largeur / 2, g.hauteur_grille / 2)
	centre_terrain = c
	var x0 := maxi(g.origine.x, c.x - RAYON_VUE)
	var x1 := mini(g.origine.x + g.largeur - 1, c.x + RAYON_VUE)
	var y0 := maxi(g.origine.y, c.y - RAYON_VUE)
	var y1 := mini(g.origine.y + g.hauteur_grille - 1, c.y + RAYON_VUE)
	var garder := {}
	for s in range(x0 + y0, x1 + y1 + 1):     # tri de profondeur : diagonales x+y, dans la fenêtre
		for x in range(maxi(x0, s - y1), mini(x1, s - y0) + 1):
			var y := s - x
			var t := Vector2i(x, y)
			_dessine_tuile(ci, t)   # tous les murs de la fenêtre, en blocs pleins
			if "vegetation" in g.contenu_de(t).get("tags", []):
				garder[g.idx(t)] = true
				_assurer_vegetal(t)
	for idx in noeuds_vegetaux.keys().duplicate():   # hors de la fenêtre : on libère
		if not garder.has(idx):
			noeuds_vegetaux[idx].queue_free()
			noeuds_vegetaux.erase(idx)


## La profondeur d'un billboard (z relatif) : x + y, ramené à la fenêtre (les coordonnées monde dépassent CANVAS_ITEM_Z_MAX).
func _profondeur(t: Vector2i) -> int:
	var o: Vector2i = sim.grille.origine
	return clampi((t.x - o.x) + (t.y - o.y) + 1, 1, 4000)


## Un billboard pour le végétal d'une tuile (Direction artistique : les ressources récoltables sont des sprites).
func _assurer_vegetal(t: Vector2i) -> void:
	var g := sim.grille
	var idx := g.idx(t)
	if noeuds_vegetaux.has(idx):
		return
	var v := Vegetal.new()
	var mat_id := g.materiau_de(t)
	v.configurer(mat_id, GameData.catalogues.vegetaux.get(mat_id, {}), GameData.catalogues.materials.get(mat_id, {}), hash([t.x, t.y]))
	v.position = _ecran(t, g.h(t))
	v.z_index = _profondeur(t)
	var j := joueur()
	if not g.decouvert.has(idx):
		v.modulate = Color(0, 0, 0, 0)
	elif not j.is_empty() and not sim.voit(j, t):
		v.modulate = Color(0.45, 0.45, 0.5)
	add_child(v)
	noeuds_vegetaux[idx] = v


func _zones_telegraphes() -> Dictionary:
	var zones := {}
	for id in telegraphes.keys():
		var e: Dictionary = sim.entites[id]
		var a: Dictionary = telegraphes[id]
		if a.type == "creature":
			var action: Dictionary = sim.actions_creatures[a.action]
			var cible: Dictionary = sim.entites.get(a.cible, {})
			match str(action.forme):
				"ligne":
					for p in sim.grille.ligne(e.pos, cible.pos if not cible.is_empty() else e.pos + e.orientation, int(action.taille)):
						zones[p] = true
				"anneau", "soi":
					for p in sim.grille.anneau(e.pos, int(action.taille)):
						zones[p] = true
				_:
					if not cible.is_empty():
						zones[cible.pos] = true
		elif sim.entites.has(a.cible):
			zones[sim.entites[a.cible].pos] = true
	return zones


func _dessine_tuile(ci: CanvasItem, t: Vector2i) -> void:
	var g := sim.grille
	var h := g.h(t)
	var c := _ecran(t, h)
	var teinte := Color.WHITE   # le brouillard est une couche à part (_dessiner_brouillard)
	var tags_c: Array = g.contenu_de(t).get("tags", [])
	if "liquide" in tags_c:   # la mer : un losange d'eau à sa hauteur, les flancs de la rive sont ceux des tuiles voisines
		var col_eau := Color.html(str(g.contenu_de(t).get("couleur", "#2f5f9a")))
		if "ecoulement" in tags_c:   # un écoulement : plus le niveau est bas, plus l'eau est claire (Eau et liquides)
			col_eau = col_eau.lerp(Color(0.6, 0.8, 0.95), 1.0 - float(g.niveau_liquide(t)) / 8.0)
		if g.gel:   # Météo : la glace
			col_eau = col_eau.lerp(Color(0.85, 0.92, 1.0), 0.7)
		_poly(ci, PackedVector2Array([c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0), c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)]),
			col_eau * teinte)
		return
	if g.neige:   # Météo : le sol blanchit sous la neige
		teinte = teinte.lerp(Color(1.4, 1.4, 1.5), 0.5)
	if g.bloque_passage(t) and not ("vegetation" in tags_c):   # un mur : un bloc plein — le sol dessous est caché
		_dessine_bloc(ci, g, t, c, teinte)
		return
	var haut := PackedVector2Array([
		c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0),
		c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)])
	var k := clampf((h - 4) / 12.0, 0.0, 1.0)   # gradient : bas sombre, sommets clairs
	var col := Color(0.20, 0.34, 0.18).lerp(Color(0.62, 0.66, 0.42), k)
	var sol_id := g.materiau_sol(t)
	if not sol_id.is_empty():   # surface : la couleur du matériau de sol du biome, nuancée par la hauteur
		var ms: Dictionary = GameData.catalogues.materials.get(sol_id, {})
		if not ms.is_empty():
			col = Color.html(str(ms.color)).lerp(Color(0.35, 0.5, 0.25), 0.35 if sol_id.begins_with("terre") else 0.0).darkened(0.25 - k * 0.3)
	col *= teinte
	_poly(ci, haut, col)
	var flanc := col.darkened(0.35)
	var hs := g.h(t + Vector2i(0, 1)) if g.dans(t + Vector2i(0, 1)) else 0
	if hs < h:
		var d := (h - hs) * HSTEP
		_poly(ci, PackedVector2Array([
			c + Vector2(-TW * 0.5, 0), c + Vector2(0, TH * 0.5),
			c + Vector2(0, TH * 0.5 + d), c + Vector2(-TW * 0.5, d)]), flanc)
	var he := g.h(t + Vector2i(1, 0)) if g.dans(t + Vector2i(1, 0)) else 0
	if he < h:
		var d2 := (h - he) * HSTEP
		_poly(ci, PackedVector2Array([
			c + Vector2(0, TH * 0.5), c + Vector2(TW * 0.5, 0),
			c + Vector2(TW * 0.5, d2), c + Vector2(0, TH * 0.5 + d2)]), flanc.darkened(0.15))
	var contenu := g.contenu_de(t)
	if not contenu.is_empty() and not g.bloque_passage(t) and (contenu.has("couleur") or "meuble" in contenu.get("tags", [])):
		# contenu franchissable (porte, entrée du donjon, tapis) : un losange plat coloré
		var cf := Color.html(str(GameData.entree("meubles", str(g.meubles.get(g.idx(t), "tapis"))).couleur)) if "meuble" in contenu.get("tags", []) else Color.html(str(contenu.couleur))
		_poly(ci, PackedVector2Array([c + Vector2(0, -TH * 0.35), c + Vector2(TW * 0.35, 0), c + Vector2(0, TH * 0.35), c + Vector2(-TW * 0.35, 0)]), cf * teinte)
	if "contenant" in contenu.get("tags", []):   # coffre ou butin : une caisse
		var cc := (Color(0.55, 0.38, 0.18) if "coffre" in contenu.tags else Color(0.75, 0.65, 0.3)) * teinte
		ci.draw_rect(Rect2(c + Vector2(-6, -8), Vector2(12, 8)), cc)
		ci.draw_rect(Rect2(c + Vector2(-6, -8), Vector2(12, 8)), cc.darkened(0.5), false, 1.0)

## La passe du brouillard : sur la fenêtre du terrain, un voile opaque (couleur du fond) sur les tuiles
## jamais vues, un voile translucide sur les tuiles mémorisées hors du champ de vue. Chaque voile couvre
## le losange de la tuile et la hauteur de son bloc éventuel.
func _dessiner_brouillard(ci: CanvasItem) -> void:
	if sim == null or profil_sans_terrain:
		return
	var g := sim.grille
	var j := joueur()
	if j.is_empty():
		return
	centre_brouillard = j.pos
	vue_version = int(j.get("vue_version", 0))
	var fond := Color(0.3, 0.3, 0.3)   # la couleur de fond de la scène (clear color)
	var voile := Color(0.05, 0.05, 0.08, 0.55)
	var x0 := maxi(g.origine.x, j.pos.x - RAYON_VUE)
	var x1 := mini(g.origine.x + g.largeur - 1, j.pos.x + RAYON_VUE)
	var y0 := maxi(g.origine.y, j.pos.y - RAYON_VUE)
	var y1 := mini(g.origine.y + g.hauteur_grille - 1, j.pos.y + RAYON_VUE)
	for s in range(x0 + y0, x1 + y1 + 1):
		for x in range(maxi(x0, s - y1), mini(x1, s - y0) + 1):
			var t := Vector2i(x, s - x)
			var idx := g.idx(t)
			var vu := g.decouvert.has(idx)
			if vu and sim.voit(j, t):
				if noeuds_vegetaux.has(idx):
					noeuds_vegetaux[idx].modulate = Color.WHITE
				continue
			var c := _ecran(t, g.h(t))
			var ct := g.contenu_de(t)
			var hm := (int(ct.get("hauteur_vue", 0)) * HSTEP) if g.bloque_passage(t) else 0
			if "vegetation" in ct.get("tags", []):
				hm = 0   # un billboard : on le voile lui-même (modulate), pas un pavé par-dessus
				if noeuds_vegetaux.has(idx):
					noeuds_vegetaux[idx].modulate = Color(0.45, 0.45, 0.5) if vu else Color(0, 0, 0, 0)
			_poly(ci, PackedVector2Array([
				c + Vector2(-TW * 0.5, 0), c + Vector2(-TW * 0.5, -hm), c + Vector2(0, -TH * 0.5 - hm),
				c + Vector2(TW * 0.5, -hm), c + Vector2(TW * 0.5, 0), c + Vector2(0, TH * 0.5)]), voile if vu else fond)


## Un bloc de mur : le dessus et les deux faces avant (sud-ouest, sud-est) ; une face n'est
## dessinée que si la tuile devant n'est pas elle-même un mur (elle la cacherait entièrement).
func _dessine_bloc(ci: CanvasItem, g: Grille, t: Vector2i, c: Vector2, teinte: Color = Color.WHITE) -> void:
	var hm := int(g.contenu_de(t).get("hauteur_vue", 3)) * HSTEP
	var haut_bloc := Color(0.5, 0.47, 0.44)
	var contenu_t := g.contenu_de(t)
	var tags_t: Array = contenu_t.get("tags", [])
	var mat: Dictionary = GameData.catalogues.materials.get(g.materiau_de(t), {})
	if "meuble" in tags_t and g.meubles.has(g.idx(t)):
		haut_bloc = Color.html(str(GameData.entree("meubles", str(g.meubles[g.idx(t)])).couleur))
	elif contenu_t.has("couleur"):
		haut_bloc = Color.html(str(contenu_t.couleur))
	elif "arbre" in tags_t:
		haut_bloc = Color(0.22, 0.45, 0.18).lerp(Color.html(mat.color) if not mat.is_empty() else haut_bloc, 0.2)   # la cime
	elif not mat.is_empty():   # la couleur de la palette du matériau (filon ou mur du thème)
		haut_bloc = haut_bloc.lerp(Color.html(mat.color), 0.55 if g.materiaux.has(g.idx(t)) else 0.35)
	haut_bloc *= teinte
	var sud := t + Vector2i(0, 1)
	if not g.dans(sud) or not g.bloque_passage(sud):
		_poly(ci, PackedVector2Array([   # face sud-ouest (gauche)
			c + Vector2(-TW * 0.5, 0), c + Vector2(0, TH * 0.5),
			c + Vector2(0, TH * 0.5 - hm), c + Vector2(-TW * 0.5, -hm)]), haut_bloc.darkened(0.35))
	var est := t + Vector2i(1, 0)
	if not g.dans(est) or not g.bloque_passage(est):
		_poly(ci, PackedVector2Array([   # face sud-est (droite)
			c + Vector2(0, TH * 0.5), c + Vector2(TW * 0.5, 0),
			c + Vector2(TW * 0.5, -hm), c + Vector2(0, TH * 0.5 - hm)]), haut_bloc.darkened(0.5))
	_poly(ci, PackedVector2Array([   # dessus
		c + Vector2(-TW * 0.5, -hm), c + Vector2(0, -TH * 0.5 - hm),
		c + Vector2(TW * 0.5, -hm), c + Vector2(0, TH * 0.5 - hm)]), haut_bloc)


## La couche d'interface : barres, garde, télégraphe et jauge de chaîne de chaque être.
## Les états au-dessus des êtres en vue (Écrans d'interface, 2026-08-30) : une puce par statut, teintée, l'initiale
## dedans, les ticks restants dessous.
func _dessiner_etats(ci: CanvasItem) -> void:
	var j := joueur()
	if sim == null or j.is_empty() or titre_ouvert:
		return
	for e in sim.vivants():
		if e.id != j.id and not sim.voit(j, e.pos):
			continue
		var statuts: Array = e.get("statuts", [])
		if statuts.is_empty():
			continue
		var tick_e: int = sim.tick_de(e)
		var base := _ecran(e.pos, sim.grille.h(e.pos)) + Vector2(-7.0 * mini(4, statuts.size()), -62.0)   # au-dessus de la tête
		var n_s := 0
		for st in statuts:
			if n_s >= 4:
				break
			var d_s: Dictionary = sim.statuts_defs.get(str(st.id), {})
			var tags: Array = d_s.get("tags", [])
			var c_s := Color(0.75, 0.45, 0.95) if ("controle" in tags or bool(d_s.get("controle", false))) else (Color(0.9, 0.3, 0.3) if "negatif" in tags else Color(0.35, 0.8, 0.45))
			var p_s := base + Vector2(n_s * 14.0, 0.0)
			ci.draw_rect(Rect2(p_s, Vector2(11, 11)), Color(c_s.r * 0.3, c_s.g * 0.3, c_s.b * 0.3, 0.95))
			ci.draw_rect(Rect2(p_s, Vector2(11, 11)), c_s, false, 1.0)
			ci.draw_string(ThemeDB.fallback_font, p_s + Vector2(2.0, 9.0), tr(str(d_s.get("name_key", st.id))).left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c_s)
			var reste: int = maxi(0, int(st.get("fin", 0)) - tick_e)
			ci.draw_string(ThemeDB.fallback_font, p_s + Vector2(-1.0, 20.0), ("%dk" % (reste / 1000)) if reste >= 1000 else str(reste), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.8, 0.8, 0.75))
			n_s += 1


func _dessiner_hud(ci: CanvasItem) -> void:
	_dessiner_bulle(ci)
	_dessiner_etats(ci)
	if sim != null:
		for f in gros_flottants:   # CRITIQUE / RATÉ en gros, qui montent et s'effacent (Écrans d'interface)
			var pg := _ecran(f.pos, sim.grille.h(f.pos)) + Vector2(-36.0, -66.0 - f.t * 30.0)
			var ag: float = clampf(1.2 - f.t, 0.0, 1.0)
			var cg: Color = f.couleur
			ci.draw_string(ThemeDB.fallback_font, pg + Vector2(1, 1), str(f.texte), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, ag))
			ci.draw_string(ThemeDB.fallback_font, pg, str(f.texte), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(cg.r, cg.g, cg.b, ag))
	if sim == null:
		return
	var j := joueur()
	for e in sim.vivants():
		if j.is_empty() or sim.voit(j, e.pos):
			_dessine_hud_entite(ci, e)


func _dessine_hud_entite(ci: CanvasItem, e: Dictionary) -> void:
	var c := _ecran(e.pos, sim.grille.h(e.pos))
	if e.garde:   # la garde : un arc devant l'orientation
		var o := Vector2(e.orientation.x - e.orientation.y, (e.orientation.x + e.orientation.y) * 0.5).normalized()
		ci.draw_arc(c + Vector2(0, -10), 16.0, o.angle() - 0.9, o.angle() + 0.9, 8, Color(0.6, 0.85, 1.0), 2.0)
	if telegraphes.has(e.id):   # intention visible : le télégraphe est une information d'interface
		ci.draw_string(ThemeDB.fallback_font, c + Vector2(-4, -40), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.3, 0.2))
	var w := 22.0   # plus de barres de vie ni d'endurance au-dessus des personnages (designer, 2026-08-30) : la bulle au survol les dit
	if e.has("chaine"):   # la jauge de chaîne, toujours visible (pastilles colorées)
		var segs := _segments(e)
		var cap: int = e.chaine.capacite
		for k in cap:
			var p := c + Vector2(-w * 0.5 + 2 + k * (w - 2) / cap, 5)
			if k < segs.size():
				ci.draw_circle(p, 2.6, sim.wuxing.teinte(segs[k].element))
			else:
				ci.draw_circle(p, 2.2, Color(0, 0, 0, 0.5))


## Les segments effectifs d'une jauge à l'instant présent (décroissance calculée, sans la modifier).
func _segments(e: Dictionary) -> Array:
	var copie: Dictionary = e.chaine.duplicate(true)
	sim.wuxing.decroitre(copie, sim.horloge_de(e).ticks)
	return copie.segments


# ---------------------------------------------------------------- UI texte

func _maj_ui() -> void:
	var j := joueur()
	var g := sim.grille
	var titre: String = tr("ui.camp").format({"biome": tr(str(GameData.catalogues.biomes.get(str(sim.camp_sauve.get("biome", "plaine_temperee")), {}).get("name_key", "")))}) if sim.lieu == "camp" else (tr(GameData.entree("prototype_arenas", arenes[arene_courante]).name_key) if sim.donjon.is_empty() else tr("ui.donjon").format({"theme": tr(GameData.entree("dungeon_themes", sim.donjon.theme).name_key), "etage": sim.donjon.etage, "etages": sim.donjon.etages, "salles": sim.donjon.salles}))
	var lignes: Array[String] = [tr("ui.titre") + " · " + titre]
	var mode := tr("ui.mode.combat") if sim.en_combat(j) else tr("ui.mode.exploration").format({"tps": sim.regles.r.ticks_par_seconde_exploration})
	lignes.append(tr("ui.horloge").format({"horloge": sim.horloge_de(j).ticks, "mode": mode}))
	var proches := sim.vivants().filter(func(e: Dictionary) -> bool: return e.id == joueur_id or (Grille.distance(e.pos, j.pos) <= 12 and sim.voit(j, e.pos)))
	proches = proches.slice(0, 10)   # les êtres en vue seulement : l'écran n'est pas un registre
	for e in proches:
		lignes.append("  " + tr("ui.entite.ligne").format({"nom": tr(e.name_key) + ((" " + tr(e.epithete)) if e.get("rare", false) else ""), "pv": e.sante, "pv_max": e.sante_max,
			"end": e.endurance, "compteur": e.compteur, "h": g.h(e.pos)}) + (" · GARDE" if e.garde else "")
			+ (" · " + tr(sim.items[e.equipement.main_principale].name_key) if e.equipement.has("main_principale") else "")
			+ (" + " + tr(sim.items[e.equipement.main_secondaire].name_key) if e.equipement.has("main_secondaire") else "")
			+ (" · " + _texte_chaine(e) if e.has("chaine") else "")
			+ (tr("ui.segment_prefere").format({"element": tr("element." + str(e.segment_prefere))}) if e.has("segment_prefere") else "")
			+ (tr("ui.souffle").format({"n": int(e.get("souffle", 0)), "max": sim.souffle_max(e)}) if sim.dans_l_eau(e.pos) else "")
			+ (tr("ui.etat_grille_neige") if sim.grille.neige else "") + (tr("ui.etat_grille_gel") if sim.grille.gel else "")
			+ (tr("ui.sang").format({"n": int(e.get("sang", 0))}) if sim.a_talent(e, "jauge_de_sang") else "")
			+ (" · " + _texte_statuts(e) if not e.statuts.is_empty() else ""))
	if survol.x >= 0 and not j.is_empty():
		var cl := _coord_locale(survol)
		lignes.append("  " + tr("ui.case").format({"x": cl.x, "y": cl.y, "h": g.h(survol), "dh": g.h(survol) - g.h(j.pos)}))
		var occ := g.occupant(survol)
		if not occ.is_empty() and occ != joueur_id and j.vivant:
			lignes.append_array(_preview(j, sim.entites[occ]))
	if not j.is_empty():
		if sim.lieu == "camp" and sim.monde != null:
			var tr_: Dictionary = sim.temperature_ressentie(j)
			lignes.append("  " + tr("ui.heure").format({"heure": "%02d:%02d" % [int(sim.heure()), int(fmod(sim.heure(), 1.0) * 60.0)], "phase": tr("phase." + sim.phase()), "saison": tr("saison." + sim.saison()),
				"meteo": tr(GameData.entree("weather_states", str(tr_.meteo)).name_key), "temp": "%.0f" % float(tr_.temp),
				"confort": tr("ui.confort.froid") if float(tr_.ecart) < 0.0 else (tr("ui.confort.chaud") if float(tr_.ecart) > 0.0 else "")}))
			if not sim.territoire.get("raid", {}).is_empty():   # Défense et raids : le raid en cours se lit
				var raid: Dictionary = sim.territoire.raid
				var vivants_raid := 0
				var dmin := 9999
				for x in sim.vivants():
					if x.camp == "raid":
						vivants_raid += 1
						dmin = mini(dmin, Grille.distance(j.pos, x.pos))
				lignes.append("  " + tr("ui.raid").format({"n": vivants_raid, "dist": dmin if dmin < 9999 else 0, "ticks": maxi(0, int(raid.get("fin", 0)) - sim.horloge_monde.ticks)}))
			var vl := sim.vecteur_lieu(j.pos)   # le lieu (Wu Xing hors combat) : ses deux éléments dominants
			if not vl.is_empty():
				var cles: Array = vl.keys()
				cles.sort_custom(func(p: String, q: String) -> bool: return float(vl[p]) > float(vl[q]))
				lignes.append("  " + tr("ui.lieu").format({"a": tr("element." + str(cles[0])), "pa": roundi(float(vl[cles[0]]) * 100.0), "b": tr("element." + str(cles[1])), "pb": roundi(float(vl[cles[1]]) * 100.0)}))
		var pd: Dictionary = sim.poids_de(j)
		lignes.append("  " + tr("ui.entite.mana").format({"mana": j.mana, "mana_max": j.mana_max}) + " · " + tr("ui.munitions").format({"n": j.munitions}) + " · " + tr("ui.modules_connus").format({"n": j.modules_connus.size()})
			+ " · " + tr("ui.or").format({"n": int(j.get("or", 0))}) + " · " + tr("ui.faim").format({"faim": int(j.get("faim", 100))}) + " · " + tr("ui.poids").format({"poids": "%.0f" % pd.poids, "capacite": "%.0f" % pd.capacite, "surcharge": tr("ui.poids.surcharge").format({"facteur": "%.1f" % pd.facteur}) if pd.facteur > 1.0 else ""}))
		var nd := sim.progression.niveaux_derives(j)
		lignes.append("  " + tr("ui.niveaux").format({"combat": "%.1f" % nd.combat, "general": "%.1f" % nd.general}))
		var hb: Array[String] = []
		var ent := hotbar_entrees(j)
		for k in ent.size():
			var ch: String = str((k + 1) % 10)
			hb.append(tr("ui.hotbar.selection").format({"k": ch, "nom": ent[k].nom}) if k == hotbar_sel else "%s %s" % [ch, ent[k].nom])
		lignes.append("  " + tr("ui.hotbar").format({"liste": " · ".join(hb)}))
		if visee >= 0:
			var plan := sim.plan_capacite(j, visee)
			lignes.append("  " + tr("ui.capacite.visee").format({"nom": tr(plan.name_key)}))
			if survol.x >= 0 and sim.plan_par_tuile(plan) and sim.capacite_visable(j, plan, survol):   # le prix de cette visée-là
				var n_t: int = sim.tuiles_du_plan(j, plan, survol).size()
				var fc_v: Vector2i = sim.fourchette_cout(plan)
				lignes.append("  " + tr("ui.capacite.surface").format({"n": n_t, "min": fc_v.x * n_t, "max": fc_v.y * n_t, "monnaie": tr("monnaie." + str(plan.get("monnaie", "")))}))
			if survol.x >= 0 and not g.occupant(survol).is_empty():
				lignes.append("  " + _preview_capacite(j, plan, sim.entites[g.occupant(survol)]))
	ui.text = "\n".join(lignes)
	var bas: Array[String] = []
	if not j.is_empty() and not j.sac.is_empty():
		var objets: Array[String] = []
		for k in mini(9, j.sac.size()):
			var it_k: Dictionary = sim.items[j.sac[k]]
			var nom_k := nom_objet(sim.nom_objet(j.sac[k]))
			if it_k.get("type", "") == "materiau":
				nom_k = tr("forme." + str(it_k.get("forme", "brut"))).format({"materiau": nom_k}) + " ×%d" % int(it_k.quantite)
			objets.append(nom_k)
		bas.append(tr("ui.sac").format({"liste": " · ".join(objets)}))
	if not ecran_fin.is_empty():
		bas.append_array(ecran_fin)
		bas.append("")
	bas.append_array(journal)
	if not j.vivant:
		bas.append(tr("journal.defaite"))
	ui_bas.text = "\n".join(bas)
	ui_droite.text = ""   # la timeline est graphique (HudEcran._dessiner_timeline, Écrans d'interface)


## La bulle au survol, dessinée dans la couche HUD (au-dessus des blocs et des êtres) — rien ne la recouvre.
func _dessiner_bulle(ci: CanvasItem) -> void:
	var j := joueur()
	if sim == null or j.is_empty() or survol.x < 0 or ecrans.est_ouvert() or titre_ouvert:
		return
	var g := sim.grille
	var occ := g.occupant(survol)
	if occ.is_empty() or occ == joueur_id or not sim.entites.has(occ) or not sim.entites[occ].vivant or not sim.voit(j, survol):
		return
	var cible: Dictionary = sim.entites[occ]
	var lignes_b := _lignes_bulle(j, cible)
	var larg := 0.0
	for l in lignes_b:
		larg = minf(420.0, maxf(larg, ThemeDB.fallback_font.get_string_size(str(l), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0))   # 420 px au plus
	var haut := 14.0 * lignes_b.size() + 8.0
	var pb := _ecran(cible.pos, g.h(cible.pos)) + Vector2(-larg * 0.5 - 6.0, -70.0 - haut)
	ci.draw_rect(Rect2(pb, Vector2(larg + 12.0, haut)), Color(0.05, 0.05, 0.08, 0.9))
	ci.draw_rect(Rect2(pb, Vector2(larg + 12.0, haut)), Color(0.9, 0.3, 0.25) if sim.ennemis(j, cible) else Color(0.35, 0.8, 0.45), false, 1.0)
	for k in lignes_b.size():
		ci.draw_string(ThemeDB.fallback_font, pb + Vector2(6.0, 14.0 * (k + 1) - 2.0), str(lignes_b[k]), HORIZONTAL_ALIGNMENT_LEFT, larg + 2.0, 11, Color(0.95, 0.95, 0.9) if k > 0 else Color(1.0, 0.9, 0.6))   # bornée au cadre


## La bulle au survol d'une cible (Écrans d'interface, 2026-08-30) : PV, fourchette de l'arme, résistance Wu Xing, armure.
func _lignes_bulle(j: Dictionary, cible: Dictionary) -> Array[String]:
	var res: Array[String] = [tr("ui.bulle.pv").format({"nom": tr(cible.name_key), "pv": int(cible.sante), "max": int(cible.sante_max)})]
	var arme := Etres.arme(j, sim.items)
	if not arme.is_empty():
		var fonct: Dictionary = sim.fonctionnalites[arme.functionality]
		var zone: Dictionary = sim.regles.zone_de_coup(g_h(j.pos), g_h(cible.pos))
		var piece := Etres.piece_zone(cible, zone.zone, sim.items)
		var armure := sim.regles.armure_piece(piece, fonct.type_degats)
		var a_zero: bool = j.endurance <= 0
		var vecteur := sim.vecteur_arme(arme)
		var wx: Dictionary = sim._facteur_wuxing(j, cible, vecteur, sim.horloge_de(j).ticks)
		var f := sim.regles.fourchette_arme(j.stats_eff, arme, fonct, false, zone.mult, armure, a_zero, wx.total, j.competences_eff, vecteur)
		var fl := sim.regles.fourchette_arme(j.stats_eff, arme, fonct, true, zone.mult, armure, a_zero, wx.total, j.competences_eff, vecteur)
		res.append(tr("ui.bulle.arme").format({"min": f.x, "max": f.y, "lmin": fl.x, "lmax": fl.y}))
		if not vecteur.is_empty():
			var el_c: Dictionary = cible.get("elements", {}) if cible.get("elements") is Dictionary else {}
			res.append(tr("ui.bulle.wuxing").format({"element": tr("element." + sim.wuxing.dominante(vecteur)), "cible": tr("element." + sim.wuxing.dominante(el_c)) if not el_c.is_empty() else "—", "dom": "%.2f" % wx.dom}))
		res.append(tr("ui.bulle.armure").format({"zone": tr("zone." + str(zone.zone)), "armure": "%.1f" % armure, "mult": "%.2f" % zone.mult}))
	if visee >= 0:
		var plan := sim.plan_capacite(j, visee)
		if not plan.is_empty() and plan.erreurs.is_empty():
			res.append(_preview_capacite(j, plan, cible))
	return res


## Prévisualisation des dégâts avec le détail du calcul (la lisibilité est le but).
func _preview(j: Dictionary, cible: Dictionary) -> Array[String]:
	var res: Array[String] = []
	var arme := Etres.arme(j, sim.items)
	if arme.is_empty():
		return res
	var fonct: Dictionary = sim.fonctionnalites[arme.functionality]
	var zone: Dictionary = sim.regles.zone_de_coup(g_h(j.pos), g_h(cible.pos))
	var piece := Etres.piece_zone(cible, zone.zone, sim.items)
	var armure := sim.regles.armure_piece(piece, fonct.type_degats)
	var a_zero: bool = j.endurance <= 0
	var vecteur := sim.vecteur_arme(arme)
	var wx: Dictionary = sim._facteur_wuxing(j, cible, vecteur, sim.horloge_de(j).ticks)
	var f := sim.regles.fourchette_arme(j.stats_eff, arme, fonct, false, zone.mult, armure, a_zero, wx.total, j.competences_eff, vecteur)
	var stat := int(j.stats_eff.force) / int(sim.regles.r.degats.stat_div)
	res.append("  " + tr("ui.preview").format({"nom": tr(arme.name_key), "des": fonct.degats_des,
		"dur": "%.2f" % (float(arme.durete_base) / float(sim.regles.r.degats.durete_reference) * float(arme.qualite)),
		"stat": stat, "zone": zone.zone, "mult": zone.mult, "armure": "%.1f" % armure,
		"min": f.x, "max": f.y, "ticks": sim.regles.ticks_attaque(fonct, false, arme)}))
	var fl := sim.regles.fourchette_arme(j.stats_eff, arme, fonct, true, zone.mult, armure, a_zero, wx.total, j.competences_eff, vecteur)
	res.append("  " + tr("ui.preview.lourde").format({"lourde": "%d–%d" % [fl.x, fl.y], "ticks": sim.regles.ticks_attaque(fonct, true, arme)}))
	if not vecteur.is_empty():
		var contre: Array[String] = []
		for k in wx.contre.keys():
			contre.append("%s %d%%" % [tr("element." + k), roundi(float(wx.contre[k]) * 100.0)])
		var prev: Dictionary = wx.prevision
		res.append("  " + tr("ui.wuxing").format({"element": tr("element." + sim.wuxing.dominante(vecteur)),
			"contre": " ".join(contre) if not contre.is_empty() else "—", "dom": "%.2f" % wx.dom,
			"segments": _segments(j).size() if j.has("chaine") else 0, "capacite": j.chaine.capacite if j.has("chaine") else 0,
			"gain": "%.2f" % wx.gain, "position": prev.get("position", 0),
			"transition": "(+%.2f)" % prev.get("transition", 0.0), "chaine": ("RÉSOUT ×%.2f" % prev.multiplicateur) if prev.get("resout", false) else "%.2f" % wx.chaine}))
	if not sim.regles.a_portee(fonct, Grille.distance(j.pos, cible.pos)) or not sim.grille.ligne_de_vue(j.pos, cible.pos):
		res.append("  (hors de portée ou hors de vue)")
	return res


func g_h(p: Vector2i) -> int:
	return sim.grille.h(p)


## L'infobulle exhaustive d'une capacité : forme, portée, coûts, dés — calculés pour le porteur.
func _texte_capacite(j: Dictionary, k: int) -> String:
	var plan := sim.plan_capacite(j, k)
	var mods: Array[String] = []
	for m in plan.modules:
		mods.append(tr(sim.capacites.modules.get(m, {}).get("name_key", m)))
	return tr("ui.capacite").format({"touche": "F%d" % (k + 1), "nom": tr(plan.name_key), "modules": " + ".join(mods),
		"forme": plan.geometrie, "pmin": plan.portee.x, "pmax": plan.portee.y, "taille": plan.taille,
		"ticks": plan.ticks, "ressource": plan.ressource, "monnaie": plan.monnaie if not plan.monnaie.is_empty() else "—",
		"des": str(plan.des) if plan.des != null else "—", "bonus": (" +%d dé(s)" % plan.des_bonus) if plan.des_bonus > 0 else ""}) \
		+ ((" → " + tr(plan.charge_suivante.name_key) + " : " + tr(plan.charge_suivante.noyau.get("name_key", ""))) if not plan.charge_suivante.is_empty() else "")


func _preview_capacite(j: Dictionary, plan: Dictionary, cible: Dictionary) -> String:
	if not ("degats" in plan.effets):
		return ""
	var zone: Dictionary = sim.regles.zone_de_coup(g_h(j.pos), g_h(cible.pos))
	var dom: Dictionary = sim.multiplicateur_domination(plan.elements, cible, zone.zone)
	var piece := Etres.piece_zone(cible, zone.zone, sim.items)
	var arme_noyau: bool = plan.noyau.get("power_base") == "arme"
	var armure := 0.0
	if not plan.drapeaux.get("ignore_armure", false):
		armure = sim.regles.armure_piece(piece, str(plan.fonct.get("type_degats", "contondant")) if arme_noyau else "contondant")
		if not arme_noyau:
			armure *= float(sim.regles.r.armure.magie_facteur)
	var f := Des.fourchette(plan.des, int(plan.des_bonus))
	var k: float = float(dom.mult) * float(plan.mult)
	if j.has("chaine") and not plan.elements.is_empty():
		var prev: Dictionary = sim.wuxing.prevoir(j.chaine, sim.wuxing.dominante(plan.elements))
		k *= float(prev.gain) * float(prev.multiplicateur)
	return tr("ui.capacite.preview").format({"nom": tr(plan.name_key), "def": tr(cible.name_key), "des": str(plan.des),
		"bonus": (" +%d dé(s)" % plan.des_bonus) if plan.des_bonus > 0 else "", "dom": "%.2f" % dom.mult,
		"zone": zone.zone, "mult": zone.mult, "armure": "%.1f" % armure,
		"min": sim.regles.degats_finaux(f.x * k, zone.mult, armure, false), "max": sim.regles.degats_finaux(f.y * k, zone.mult, armure, false)})


func _texte_statuts(e: Dictionary) -> String:
	var noms: Array[String] = []
	var tick := sim.horloge_de(e).ticks
	for s in e.statuts:
		noms.append("%s (%d)" % [tr(sim.statuts_defs.get(s.id, {}).get("name_key", s.id)), int(s.fin) - tick])
	return tr("ui.statuts").format({"liste": ", ".join(noms)})


## Le jalon « ressortir » : l'écran d'expédition.
func _sur_fin_d_expedition(recap: Dictionary) -> void:
	ecran_fin = [tr("ui.expedition.titre").format({"theme": tr(GameData.entree("dungeon_themes", recap.theme).name_key)}),
		tr("ui.expedition.ligne").format({"etage_max": recap.etage_max, "tues": recap.tues, "objets": recap.objets, "sac": recap.sac,
			"boss": tr("ui.fin.victoire") if recap.boss_vaincu else "—", "combat": "%.1f" % recap.niveaux.combat, "general": "%.1f" % recap.niveaux.general}),
		tr("ui.fin.suite")]


## Écran de fin de combat : issue, durée en ticks, XP des trois pistes et de l'armure (XP de combat).
func _sur_fin_de_combat(_nom: String) -> void:
	telegraphes.clear()
	var j := joueur()
	var dc: Dictionary = sim.dernier_combat
	if j.is_empty() or dc.is_empty():
		return
	ecran_fin = [tr("ui.fin.titre").format({"issue": tr("ui.fin.victoire") if dc.victoire else tr("ui.fin.defaite"), "ticks": dc.ticks})]
	for piste in ["element", "competence", "type", "construction"]:
		var parts: Array[String] = []
		for k in j.xp[piste].keys():
			var nom: String = tr("element." + k) if piste == "element" else str(k)
			parts.append("%s %d" % [nom, j.xp[piste][k]])
		ecran_fin.append(tr("ui.fin.piste").format({"piste": piste, "detail": ", ".join(parts) if not parts.is_empty() else "—"}))
	var gagnes: Array[String] = []
	for g in dc.get("niveaux", []):
		if g.id == j.id:
			gagnes.append("%s %d" % [tr(sim._nom_competence(g.competence)), g.niveau])
	if not gagnes.is_empty():
		ecran_fin.append(tr("ui.fin.niveaux").format({"liste": ", ".join(gagnes)}))
	ecran_fin.append(tr("ui.fin.suite"))
	for piste in j.xp.keys():
		j.xp[piste] = {}   # non persistée : l'écran la montre, la partie ne la garde pas (prototype)


## Le nom d'un objet : « Épée de braise (une attaque sur 2 porte Feu) » — gabarit localisé,
## paramètres tirés (Loot — affixes : NOM ET PROVENANCE).
func nom_objet(n: Dictionary) -> String:
	var base := tr(str(n.base))
	if n.has("materiau"):   # craft : « Dague en fer », « Casque de plaque en cuivre », « Lame courte en fer »
		var mat := tr(str(n.materiau))
		var q := " (%s %.2f)" % [tr("qualite." + sim.regles.palier_qualite(float(n.qualite))), float(n.qualite)]
		if not str(n.construction).is_empty():
			return tr("nom.armure_en").format({"base": base, "construction": tr("construction.%s.nom" % n.construction), "materiau": mat}) + q
		return tr("nom.arme_en").format({"base": base, "materiau": mat}) + q
	if n.has("de_creature"):   # la statue 1:1 (Créatures)
		return tr("nom.de_creature").format({"base": base, "creature": tr(str(n.de_creature))})
	if n.has("taille"):
		var t: Dictionary = n.taille
		return "%s (%s %s)" % [base, tr("taille." + str(t.type)), ("%.2f" % float(t.valeur)) if t.type in ["affinite", "qualite"] else str(int(t.valeur))]
	if n.has("livre"):
		return "%s %s (difficulté %d, %d modules)" % [base, tr("domaine." + str(n.livre.domaine)), int(n.livre.difficulte), int(n.livre.n)]
	if str(n.get("affixe", "")).is_empty():
		return base
	var p: Dictionary = n.params.duplicate()
	for k in p.keys():
		if k == "element":
			p["epithete"] = tr("epithete." + str(p[k]))
			p[k] = tr("element." + str(p[k]))
	p["base"] = base
	return tr("affixe." + str(n.affixe) + ".nom").format(p) + " [" + tr("rarete." + str(n.get("rarete", "commun"))) + "]"


const COULEUR_ZONE := {"entrave": Color(0.35, 0.6, 0.25, 0.4), "blessure": Color(0.8, 0.2, 0.2, 0.4),
	"glissante": Color(0.4, 0.75, 0.95, 0.35), "brume": Color(0.75, 0.78, 0.85, 0.5), "balise": Color(0.95, 0.85, 0.3, 0.4)}


func _texte_chaine(e: Dictionary) -> String:
	var noms: Array[String] = []
	for s in _segments(e):
		noms.append(tr("element." + s.element))
	return tr("ui.chaine").format({"segments": " → ".join(noms) if not noms.is_empty() else "∅"})
