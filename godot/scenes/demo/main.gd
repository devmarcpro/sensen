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
const RAYON_VUE := 20            # tuiles dessinées autour du joueur (une cellule fait 128×128)
var centre_terrain := Vector2i(-99, -99)   # centre de la dernière passe statique du terrain
var vue_version := -1                      # version du champ de vue dessiné (brouillard de guerre)

var sim: Simulation
var arenes: Array[String] = []
var arene_courante := 0
var joueur_id := ""
var chemin_en_cours: Array[Vector2i] = []
var minuterie_pas := 0.0
var minuterie_ui := 0.0
var minuterie_clavier := 0.0        # cadence des pas au clavier (ZQSD maintenu)
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
var creation: Dictionary = {}      # l'écran de création, tant que le personnage n'existe pas
const STATS := ["force", "dexterite", "endurance", "volonte", "perception", "charisme"]
var zoom := 1.0

var terrain: Terrain              # couche statique : les tuiles, dessinées une fois (perf É0)
var hud: Hud                      # couche au-dessus des êtres : barres, garde, télégraphes, jauges
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
	hud = Hud.new()
	hud.proprio = self
	hud.z_as_relative = false
	hud.z_index = 200
	add_child(hud)
	EventBus.damage_dealt.connect(func(src: String, _c: String, _d: int, _det: Dictionary) -> void: if noeuds.has(src): noeuds[src].frapper())
	arenes.assign(GameData.catalogues.get("prototype_arenas", {}).keys())
	arenes.sort()
	EventBus.journal.connect(_sur_journal)
	EventBus.action_engaged.connect(func(id: String, a: Dictionary) -> void: telegraphes[id] = a)
	EventBus.action_resolved.connect(func(id: String, _a: Dictionary) -> void: telegraphes.erase(id))
	EventBus.combat_ended.connect(_sur_fin_de_combat)
	EventBus.expedition_terminee.connect(_sur_fin_d_expedition)
	EventBus.tile_changed.connect(func(_p: Vector2i) -> void: terrain.queue_redraw())
	GameData.donnees_rechargees.connect(_charger)
	creation = {"race": 0, "classe": 0, "stat": 0, "points": {}, "annee": 1000}
	ecrans = Ecrans.new()
	ecrans.main = self
	add_child(ecrans)
	var tutoriels := Tutoriels.new()
	tutoriels.afficher = func(texte: String) -> void: _log("💡 " + texte)
	add_child(tutoriels)
	if OS.get_cmdline_user_args().has("--sans-creation") or DisplayServer.get_name() == "headless":
		creation = {}
	_charger()


## L'écran de création : R race, C classe, ↑↓ stat, +/− points, ← → année de naissance, Entrée.
func _texte_creation() -> String:
	var races: Array = GameData.catalogues.races.keys()
	var classes: Array = GameData.catalogues.classes.keys()
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
		tr("ui.creation.classe").format({"classe": tr(cl.name_key), "talent": str(cl.get("talent", "—"))}),
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
	var classes: Array = GameData.catalogues.classes.keys()
	races.sort()
	classes.sort()
	var prog := Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	var fiche := Etres.creer_personnage("creature.aventurier.name", races[creation.race % races.size()], classes[creation.classe % classes.size()], creation.points, int(creation.annee), prog)
	fiche.capacites = GameData.entree("creatures", "aventurier").get("capacites", []).duplicate(true)
	creation = {}
	_charger(fiche)


func _charger(fiche: Dictionary = {}) -> void:
	if fiche.is_empty() and sim != null and not sim.fiche_joueur.is_empty():
		fiche = sim.fiche_joueur
	sim = Simulation.new(0x68EE)
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
	_log(tr("ui.aide"))
	var j := joueur()
	if not j.is_empty() and not j.ratelier.is_empty():
		var noms: Array[String] = []
		for k in j.ratelier.size():
			noms.append("%d=%s" % [k + 1, tr(sim.items[j.ratelier[k]].name_key)])
		_log(tr("ui.aide.armes").format({"liste": " · ".join(noms), "ticks": sim.regles.r.actions.changer_arme}))
	if not j.is_empty() and not j.get("capacites", []).is_empty():
		var caps: Array[String] = []
		for k in j.capacites.size():
			caps.append("F%d=%s" % [k + 1, tr(j.capacites[k].get("name_key", j.capacites[k].id))])
		_log(tr("ui.aide.capacites").format({"liste": " · ".join(caps)}))
	visee = -1
	_recentrer()


## La simulation a changé de grille (descente) : la vue statique et les nœuds repartent de zéro.
func _apres_changement_de_grille() -> void:
	terrain.queue_redraw()
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
	# Le joueur est centré à l'écran, la vue le suit (Écrans d'interface, décision du 2026-08-27).
	position = taille * 0.5 - _ecran(j.pos, sim.grille.h(j.pos)) * zoom


func joueur() -> Dictionary:
	return sim.entites.get(joueur_id, {})


func _sur_journal(cle: String, params: Dictionary) -> void:
	var p := {}
	for k in params.keys():
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

func _process(delta: float) -> void:
	if not creation.is_empty():
		ui.text = _texte_creation()
		ui_bas.text = ""
		ui_droite.text = ""
		return
	var j := joueur()
	if j.is_empty():
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
			minuterie_clavier = 0.15
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
	_maj_noeuds()
	if Grille.distance(j.pos, centre_terrain) > RAYON_VUE / 3 or int(j.get("vue_version", 0)) != vue_version:
		terrain.queue_redraw()   # le joueur s'éloigne du centre de la passe statique, ou son champ de vue a changé
	hud.queue_redraw()
	_maj_atteignables()
	minuterie_ui -= delta
	if minuterie_ui <= 0.0 and not profil_sans_ui:
		minuterie_ui = 0.05
		_maj_ui()
	queue_redraw()


## Un nœud creature.tscn par être vivant, configuré depuis sa fiche : position, profondeur, rig.
func _maj_noeuds() -> void:
	var vivants := {}
	var j := joueur()
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
		n.visible = true
		n.position = _ecran(e.pos, sim.grille.h(e.pos))
		n.z_index = e.pos.x + e.pos.y + 1
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
		if g.dans(t) and (g.h(t) > he or g.bloque_passage(t)):
			n.draw_set_transform(-base)
			_dessine_tuile(n, t)
			n.draw_set_transform(Vector2.ZERO)


func _maj_atteignables() -> void:
	var j := joueur()
	atteignables = {}
	if j.vivant and sim.attente.has(joueur_id) and sim.en_combat(j):
		atteignables = sim.grille.atteignables(j.pos, BUDGET_ATTEIGNABLE, Etres.est_volant(j))


# ---------------------------------------------------------------- entrées → intentions

func _unhandled_input(ev: InputEvent) -> void:
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
					var cl: Dictionary = GameData.entree("classes", GameData.catalogues.classes.keys()[creation.classe % GameData.catalogues.classes.size()])
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
		if ev is InputEventKey and ev.keycode == KEY_TAB:
			arene_courante = (arene_courante + 1) % (arenes.size() + 1)
			_charger()
		return
	if ev is InputEventMouseMotion:
		survol = _tuile_sous(get_local_mouse_position())
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = minf(2.0, zoom * 1.1)
			scale = Vector2.ONE * zoom
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxf(0.5, zoom / 1.1)
			scale = Vector2.ONE * zoom
		elif ev.button_index == MOUSE_BUTTON_LEFT and not j.is_empty() and j.vivant:
			_clic(_tuile_sous(get_local_mouse_position()), ev.shift_pressed)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ecrans.est_ouvert() and ecrans.touche(ev):
			return
		match ev.keycode:
			KEY_G:
				chemin_en_cours.clear()
				sim.intention(joueur_id, {"type": "garde"})
			KEY_SPACE:
				chemin_en_cours.clear()
				sim.intention(joueur_id, {"type": "attendre"})
			KEY_TAB:
				arene_courante = (arene_courante + 1) % (arenes.size() + 1)
				_charger()
			KEY_C:
				ecrans.basculer("feuille")
			KEY_F:
				ecrans.basculer("atelier")
			KEY_I:
				ecrans.basculer("inventaire")
			KEY_L:
				if sim.attente.has(joueur_id) and not j.is_empty():
					for uid in j.sac:
						if sim.items[uid].get("type", "") in ["grimoire", "manuel"]:
							sim.intention(joueur_id, {"type": "lire", "objet": uid})
							break
			KEY_T:
				if sim.attente.has(joueur_id) and not j.is_empty() and j.equipement.has("main_principale"):
					for uid in j.sac:
						if sim.items[uid].get("type", "") == "gemme":
							if not sim.intention(joueur_id, {"type": "sertir", "objet": j.equipement.main_principale, "gemme": uid}):
								_log(tr("journal.pas_de_sertissure"))
							break
			KEY_R:
				if sim.attente.has(joueur_id):
					if not sim.intention(joueur_id, {"type": "ramasser"}):
						_log(tr("journal.rien_a_ramasser"))
			KEY_E:
				if sim.attente.has(joueur_id):
					if sim.intention(joueur_id, {"type": "descendre"}) or sim.intention(joueur_id, {"type": "remonter"}):
						_apres_changement_de_grille()
					else:
						_log(tr("journal.pas_escalier"))
			KEY_F1, KEY_F2, KEY_F3:
				var k: int = ev.keycode - KEY_F1
				if not j.is_empty() and k < j.get("capacites", []).size():
					chemin_en_cours.clear()
					var plan := sim.plan_capacite(j, k)
					if plan.geometrie == "soi":
						sim.intention(joueur_id, {"type": "capacite", "index": k, "cible": j.pos})
						visee = -1
					else:
						visee = k
			KEY_ESCAPE:
				visee = -1
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var k: int = ev.keycode - KEY_1
				if ev.shift_pressed:
					if not j.is_empty() and k < j.sac.size() and sim.attente.has(joueur_id):
						sim.intention(joueur_id, {"type": "equiper", "objet": j.sac[k]})
				elif not j.is_empty() and k < j.ratelier.size():
					chemin_en_cours.clear()
					sim.intention(joueur_id, {"type": "changer_arme", "item": j.ratelier[k]})


func _clic(t: Vector2i, lourde: bool) -> void:
	if t.x < 0:
		return
	var j := joueur()
	if visee >= 0:
		if sim.attente.has(joueur_id):
			if not sim.intention(joueur_id, {"type": "capacite", "index": visee, "cible": t}):
				_log(tr("journal.inaccessible"))
			else:
				visee = -1
		return
	var occ := sim.grille.occupant(t)
	if not occ.is_empty() and occ != joueur_id:
		chemin_en_cours.clear()
		if not sim.attente.has(joueur_id):
			return
		if not sim.intention(joueur_id, {"type": "attaquer", "cible": occ, "lourde": lourde}):
			var tir := sim.verifier_tir(j, sim.entites[occ])
			if not tir.ok:
				_log(tr("journal.tir_refuse").format({"raison": tr("raison." + tir.raison)}))
			else:
				_log(tr("journal.inaccessible"))
		return
	if Grille.distance(j.pos, t) == 1:
		var tags: Array = sim.grille.contenu_de(t).get("tags", [])
		if sim.attente.has(joueur_id):
			if "meuble" in tags and sim.grille.meubles.has(sim.grille.idx(t)):
				var m: Dictionary = GameData.entree("meubles", str(sim.grille.meubles[sim.grille.idx(t)]))
				if bool(m.dormir):   # un lit : dormir
					sim.intention(joueur_id, {"type": "dormir", "vers": t})
					return
				if int(m.capacite_slots) > 0 and sim.contenants.get(sim.grille.idx(t), []).size() > 0:   # un coffre : tout prendre
					sim.intention(joueur_id, {"type": "prendre", "vers": t})
					return
			if "construit" in tags:   # ce qui a été posé se démonte au clic
				sim.intention(joueur_id, {"type": "demonter", "vers": t})
				return
			if "contenant" in tags and sim.contenants.get(sim.grille.idx(t), []).size() > 0:
				sim.intention(joueur_id, {"type": "prendre", "vers": t})
				return
		if sim.grille.bloque_passage(t):
			if sim.attente.has(joueur_id) and not sim.intention(joueur_id, {"type": "creuser", "vers": t}):
				_log(tr("journal.increusable"))
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
	for y in range(maxi(0, cj.y - RAYON_VUE), mini(g.hauteur_grille, cj.y + RAYON_VUE + 1)):
		for x in range(maxi(0, cj.x - RAYON_VUE), mini(g.largeur, cj.x + RAYON_VUE + 1)):
			var t := Vector2i(x, y)
			var c := _ecran(t, g.h(t))
			var d := c.distance_squared_to(p)
			if d < meilleure_d and d < float(TW * TW) * 0.3:
				meilleure_d = d
				meilleur = t
	return meilleur


# ---------------------------------------------------------------- rendu

func _ecran(t: Vector2i, h: int) -> Vector2:
	return Vector2((t.x - t.y) * TW * 0.5, (t.x + t.y) * TH * 0.5 - h * HSTEP)


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
	if not sim.donjon.is_empty() and sim.donjon.escalier != null:
		_losange(sim.donjon.escalier, Color(0.9, 0.7, 0.2, 0.6))
	if not sim.donjon.is_empty() and sim.donjon.has("entree"):
		_losange(sim.donjon.entree, Color(0.3, 0.9, 0.5, 0.5))   # la sortie / l'escalier montant
	for gl in sim.glyphes:   # les glyphes : un losange cerclé à la teinte de leur élément
		var cg := _ecran(gl.pos, g.h(gl.pos))
		var teinte := sim.wuxing.teinte(sim.wuxing.dominante(gl.elements)) if not gl.elements.is_empty() else Color(0.8, 0.8, 0.9)
		draw_arc(cg, 7.0, 0.0, TAU, 12, teinte, 2.0)
	if visee < 0 and survol.x >= 0 and not j.is_empty() and not g.occupant(survol).is_empty() and g.occupant(survol) != joueur_id:
		var tir := sim.verifier_tir(j, sim.entites[g.occupant(survol)])
		if tir.has("bloqueur"):
			_losange(tir.bloqueur, Color(1, 0.2, 0.2, 0.45))
	if visee >= 0 and survol.x >= 0 and not j.is_empty():
		var plan := sim.plan_capacite(j, visee)
		var ok := sim.capacite_visable(j, plan, survol)
		for t in Capacites.tuiles_de_forme(g, plan.geometrie, j.pos, survol, int(plan.taille)):
			_losange(t, Color(0.3, 0.6, 1.0, 0.45) if ok else Color(0.5, 0.5, 0.5, 0.35))
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


func _losange(t: Vector2i, col: Color) -> void:
	var c := _ecran(t, sim.grille.h(t))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0), c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)]), col)


## La passe statique : toutes les tuiles, une seule fois (appelée par la couche Terrain).
func _dessiner_terrain(ci: CanvasItem) -> void:
	if sim == null or profil_sans_terrain:
		return
	var g := sim.grille
	var j := joueur()
	var c: Vector2i = j.pos if not j.is_empty() else Vector2i(g.largeur / 2, g.hauteur_grille / 2)
	centre_terrain = c
	vue_version = int(j.get("vue_version", 0))
	var x0 := maxi(0, c.x - RAYON_VUE)
	var x1 := mini(g.largeur - 1, c.x + RAYON_VUE)
	var y0 := maxi(0, c.y - RAYON_VUE)
	var y1 := mini(g.hauteur_grille - 1, c.y + RAYON_VUE)
	for s in range(x0 + y0, x1 + y1 + 1):     # tri de profondeur : diagonales x+y, dans la fenêtre
		for x in range(maxi(x0, s - y1), mini(x1, s - y0) + 1):
			var y := s - x
			_dessine_tuile(ci, Vector2i(x, y))   # tous les murs de la fenêtre, en blocs pleins


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
	if not g.decouvert.has(g.idx(t)):   # brouillard de guerre : jamais vue → rien
		return
	var h := g.h(t)
	var c := _ecran(t, h)
	var j := joueur()
	var teinte := Color.WHITE if j.is_empty() or sim.voit(j, t) else Color(0.45, 0.45, 0.5)   # mémorisée : grisée
	if g.bloque_passage(t):   # un mur : un bloc plein sur la tuile — le sol dessous est caché
		_dessine_bloc(ci, g, t, c, teinte)
		return
	var haut := PackedVector2Array([
		c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0),
		c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)])
	var k := clampf((h - 4) / 12.0, 0.0, 1.0)   # gradient : bas sombre, sommets clairs
	var col := Color(0.20, 0.34, 0.18).lerp(Color(0.62, 0.66, 0.42), k) * teinte
	ci.draw_colored_polygon(haut, col)
	var flanc := col.darkened(0.35)
	var hs := g.h(t + Vector2i(0, 1)) if g.dans(t + Vector2i(0, 1)) else 0
	if hs < h:
		var d := (h - hs) * HSTEP
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-TW * 0.5, 0), c + Vector2(0, TH * 0.5),
			c + Vector2(0, TH * 0.5 + d), c + Vector2(-TW * 0.5, d)]), flanc)
	var he := g.h(t + Vector2i(1, 0)) if g.dans(t + Vector2i(1, 0)) else 0
	if he < h:
		var d2 := (h - he) * HSTEP
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, TH * 0.5), c + Vector2(TW * 0.5, 0),
			c + Vector2(TW * 0.5, d2), c + Vector2(0, TH * 0.5 + d2)]), flanc.darkened(0.15))
	var contenu := g.contenu_de(t)
	if not contenu.is_empty() and not g.bloque_passage(t) and (contenu.has("couleur") or "meuble" in contenu.get("tags", [])):
		# contenu franchissable (porte, entrée du donjon, tapis) : un losange plat coloré
		var cf := Color.html(str(GameData.entree("meubles", str(g.meubles.get(g.idx(t), "tapis"))).couleur)) if "meuble" in contenu.get("tags", []) else Color.html(str(contenu.couleur))
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -TH * 0.35), c + Vector2(TW * 0.35, 0), c + Vector2(0, TH * 0.35), c + Vector2(-TW * 0.35, 0)]), cf * teinte)
	if "contenant" in contenu.get("tags", []):   # coffre ou butin : une caisse
		var cc := (Color(0.55, 0.38, 0.18) if "coffre" in contenu.tags else Color(0.75, 0.65, 0.3)) * teinte
		ci.draw_rect(Rect2(c + Vector2(-6, -8), Vector2(12, 8)), cc)
		ci.draw_rect(Rect2(c + Vector2(-6, -8), Vector2(12, 8)), cc.darkened(0.5), false, 1.0)

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
		ci.draw_colored_polygon(PackedVector2Array([   # face sud-ouest (gauche)
			c + Vector2(-TW * 0.5, 0), c + Vector2(0, TH * 0.5),
			c + Vector2(0, TH * 0.5 - hm), c + Vector2(-TW * 0.5, -hm)]), haut_bloc.darkened(0.35))
	var est := t + Vector2i(1, 0)
	if not g.dans(est) or not g.bloque_passage(est):
		ci.draw_colored_polygon(PackedVector2Array([   # face sud-est (droite)
			c + Vector2(0, TH * 0.5), c + Vector2(TW * 0.5, 0),
			c + Vector2(TW * 0.5, -hm), c + Vector2(0, TH * 0.5 - hm)]), haut_bloc.darkened(0.5))
	ci.draw_colored_polygon(PackedVector2Array([   # dessus
		c + Vector2(-TW * 0.5, -hm), c + Vector2(0, -TH * 0.5 - hm),
		c + Vector2(TW * 0.5, -hm), c + Vector2(0, TH * 0.5 - hm)]), haut_bloc)


## La couche d'interface : barres, garde, télégraphe et jauge de chaîne de chaque être.
func _dessiner_hud(ci: CanvasItem) -> void:
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
	var w := 22.0
	ci.draw_rect(Rect2(c + Vector2(-w * 0.5, -42), Vector2(w, 3)), Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(c + Vector2(-w * 0.5, -42), Vector2(w * e.sante / e.sante_max, 3)), Color(0.3, 0.9, 0.3))
	ci.draw_rect(Rect2(c + Vector2(-w * 0.5, -38), Vector2(w * e.endurance / e.endurance_max, 2)), Color(0.9, 0.8, 0.3))
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
	var titre: String = tr("ui.camp") if sim.lieu == "camp" else (tr(GameData.entree("prototype_arenas", arenes[arene_courante]).name_key) if sim.donjon.is_empty() else tr("ui.donjon").format({"theme": tr(GameData.entree("dungeon_themes", sim.donjon.theme).name_key), "etage": sim.donjon.etage, "etages": sim.donjon.etages, "salles": sim.donjon.salles}))
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
			+ (" · " + _texte_statuts(e) if not e.statuts.is_empty() else ""))
	if survol.x >= 0 and not j.is_empty():
		lignes.append("  " + tr("ui.case").format({"x": survol.x, "y": survol.y, "h": g.h(survol), "dh": g.h(survol) - g.h(j.pos)}))
		var occ := g.occupant(survol)
		if not occ.is_empty() and occ != joueur_id and j.vivant:
			lignes.append_array(_preview(j, sim.entites[occ]))
	if not j.is_empty():
		lignes.append("  " + tr("ui.entite.mana").format({"mana": j.mana, "mana_max": j.mana_max}) + " · " + tr("ui.munitions").format({"n": j.munitions}) + " · " + tr("ui.modules_connus").format({"n": j.modules_connus.size()}))
		var nd := sim.progression.niveaux_derives(j)
		lignes.append("  " + tr("ui.niveaux").format({"combat": "%.1f" % nd.combat, "general": "%.1f" % nd.general}))
		for k in j.get("capacites", []).size():
			lignes.append("  " + _texte_capacite(j, k))
		if visee >= 0:
			var plan := sim.plan_capacite(j, visee)
			lignes.append("  " + tr("ui.capacite.visee").format({"nom": tr(plan.name_key)}))
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
			objets.append("⇧%d %s" % [k + 1, nom_k])
		bas.append(tr("ui.sac").format({"liste": " · ".join(objets)}))
	if not ecran_fin.is_empty():
		bas.append_array(ecran_fin)
		bas.append("")
	bas.append_array(journal)
	if not j.vivant:
		bas.append(tr("journal.defaite"))
	ui_bas.text = "\n".join(bas)
	# Timeline : les prochaines actions de l'horloge du joueur, par compteur croissant.
	var timeline: Array[String] = [tr("ui.timeline")]
	var acteurs := sim.vivants().filter(func(e: Dictionary) -> bool: return e.horloge == j.horloge and (e.id == joueur_id or (Grille.distance(e.pos, j.pos) <= 12 and sim.voit(j, e.pos))))
	acteurs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.compteur < b.compteur)
	for e in acteurs.slice(0, 12):
		var suffixe := ""
		if not e.action_en_cours.is_empty():
			suffixe = " ← " + tr(e.action_en_cours.name_key)
		timeline.append("  t=%d  %s%s" % [e.compteur, tr(e.name_key), suffixe])
	ui_droite.text = "\n".join(timeline)


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


func _texte_chaine(e: Dictionary) -> String:
	var noms: Array[String] = []
	for s in _segments(e):
		noms.append(tr("element." + s.element))
	return tr("ui.chaine").format({"segments": " → ".join(noms) if not noms.is_empty() else "∅"})
