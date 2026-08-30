extends Node
## Le parcours de donjon (Vers la production, point 13 — « essayer en profondeur le dungeon crawling ») : un robot
## joue VRAIMENT le client (main.tscn, fenêtré) — il descend étage après étage en marchant, frappe ce qu'il voit,
## ramasse ce qu'il croise, ouvre les portes, et prend des captures aux moments clés. À la fin, un rapport chiffré.
##   Godot --path godot res://scenes/tests/parcours.tscn -- --etages 3 --frames 4000 --sortie C:/dossier
var scene: Node
var jid := ""
var frames := 0
var frames_max := 4000
var etages_voulus := 3
var sortie := "C:/Users/ciryl/AppData/Local/Temp/parcours"
var graine := 7
# le rapport
var etage_depart := 0
var etages_atteints := 0
var combats := 0
var coups_portes := 0
var coups_recus := 0
var degats_recus := 0
var morts := 0
var kills := 0
var ramassages := 0
var portes_ouvertes := 0
var pas := 0
var attentes := 0
var captures := 0
var derniere_capture_frame := -999
var en_combat_avant := false
var sante_avant := -1
var journal_vu := 0
var evenements: Array[String] = []
var bloque_depuis := 0
var derniere_pos := Vector2i(-1, -1)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--etages" and i + 1 < args.size():
			etages_voulus = int(args[i + 1])
		elif args[i] == "--frames" and i + 1 < args.size():
			frames_max = int(args[i + 1])
		elif args[i] == "--sortie" and i + 1 < args.size():
			sortie = args[i + 1]
		elif args[i] == "--graine" and i + 1 < args.size():
			graine = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(sortie)
	scene = load("res://scenes/demo/main.tscn").instantiate()
	add_child(scene)
	if scene.titre_ouvert:
		scene._nouvelle_partie()
		scene._creer_personnage()
		scene._commencer_monde()
		scene.fiche_en_attente = {}
		scene.carte.fermer()
		scene.ecrans.fermer()
	var j: Dictionary = scene.joueur()
	jid = j.id
	scene.sim.donjon = {"etages": etages_voulus + 1}   # un donjon assez profond pour le parcours demandé
	scene.sim.charger_donjon("ruine", graine, 7, 1, j)
	scene.sim.maj_vision()
	scene._apres_changement_de_grille()
	etage_depart = int(scene.sim.donjon.etage)
	sante_avant = int(scene.joueur().sante)
	EventBus.damage_dealt.connect(func(src: String, cible: String, degats: int, _d: Dictionary) -> void:
		if cible == jid:
			coups_recus += 1
			degats_recus += degats
		elif src == jid:
			coups_portes += 1)
	EventBus.creature_killed.connect(func(_id: String, tueur: String) -> void:
		if tueur == jid:
			kills += 1)
	EventBus.combat_started.connect(func(_h: String, _p: Array) -> void: combats += 1)
	EventBus.journal.connect(func(cle: StringName, _args: Dictionary) -> void:
		if str(cle) == "journal.porte_ouverte":
			portes_ouvertes += 1)
	_note("étage %d : arrivée (%d salles, %s)" % [etage_depart, int(scene.sim.donjon.salles), str(scene.sim.donjon.theme)])


func _note(t: String) -> void:
	evenements.append("[f%d] %s" % [frames, t])


func _capturer(nom: String) -> void:
	if frames - derniere_capture_frame < 20:
		return
	derniere_capture_frame = frames
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%02d_%s.png" % [sortie, captures, nom])
		captures += 1


func _process(_delta: float) -> void:
	frames += 1
	if frames < 5:
		return
	if frames == 5:
		_capturer("etage_%d_arrivee" % etage_depart)   # après le premier rendu, sinon l'image est noire
	var sim = scene.sim
	if not sim.entites.has(jid):
		_fin("le joueur a disparu")
		return
	var j: Dictionary = sim.entites[jid]
	if not j.vivant:
		morts += 1
		_note("MORT à l'étage %d (%d coups reçus, %d dégâts)" % [int(sim.donjon.etage), coups_recus, degats_recus])
		_capturer("mort")
		if morts >= 3 or frames > frames_max:
			_fin("mort")
			return
		sim.intention(jid, {"type": "respawn"})
		scene._apres_changement_de_grille()
		return
	if sim.lieu != "donjon":
		_fin("sorti du donjon")
		return
	var en_combat: bool = sim.en_combat(j)
	if en_combat and not en_combat_avant:
		_note("combat engagé à l'étage %d (%d PV)" % [int(sim.donjon.etage), int(j.sante)])
		_capturer("combat_etage_%d" % int(sim.donjon.etage))
	en_combat_avant = en_combat
	if int(j.sante) < sante_avant and int(j.sante) * 3 < int(j.sante_max):
		_capturer("pv_bas_etage_%d" % int(sim.donjon.etage))
	sante_avant = int(j.sante)
	if frames > frames_max:
		_fin("budget d'images épuisé")
		return
	if not sim.attente.has(jid):
		return
	# Le robot décide : frapper ce qui est en vue, ramasser, descendre, sinon marcher vers l'escalier.
	var cible := _hostile_en_vue(j)
	if not cible.is_empty():
		scene.chemin_en_cours.clear()
		if Grille.distance(j.pos, cible.pos) <= 1:
			if sim.intention(jid, {"type": "attaquer", "cible": cible.id, "lourde": false}):
				return
		else:
			var ch: Array = sim.grille.chemin(j.pos, cible.pos, false, cible.id)   # sans la case de départ : [0] est le premier pas
			if ch.size() >= 1:
				if sim.intention(jid, {"type": "deplacer", "vers": ch[0]}):
					pas += 1
					return
		if sim.intention(jid, {"type": "attendre"}):
			attentes += 1
		return
	for d in Grille.DIRS:   # un contenant à côté : on prend
		var t: Vector2i = j.pos + d
		if sim.grille.dans(t) and "contenant" in sim.grille.contenu_de(t).get("tags", []):
			if sim.intention(jid, {"type": "prendre", "vers": t}):
				ramassages += 1
				_note("ramassage à l'étage %d" % int(sim.donjon.etage))
				return
	if sim.donjon.escalier != null and j.pos == sim.donjon.escalier:
		var etage_ici: int = int(sim.donjon.etage)
		if etages_atteints + 1 >= etages_voulus:
			_fin("%d étages descendus" % etages_atteints)
			return
		if sim.intention(jid, {"type": "descendre"}):
			scene._apres_changement_de_grille()
			etages_atteints += 1
			_note("descente : étage %d → %d (%d salles) · PV %d/%d" % [etage_ici, int(sim.donjon.etage), int(sim.donjon.salles), int(j.sante), int(j.sante_max)])
			_capturer("etage_%d_arrivee" % int(sim.donjon.etage))
			return
	var but: Vector2i = sim.donjon.escalier if sim.donjon.escalier != null else sim.donjon.entree
	if sim.donjon.escalier == null:
		_fin("dernier étage atteint (boss) : pas d'escalier plus bas")
		return
	var chemin: Array = sim.grille.chemin(j.pos, but, false, "")   # sans la case de départ
	if chemin.size() >= 1:
		if sim.intention(jid, {"type": "deplacer", "vers": chemin[0]}):
			pas += 1
			if j.pos == derniere_pos:
				bloque_depuis += 1
			else:
				bloque_depuis = 0
			derniere_pos = j.pos
			return
	# Pas de chemin (porte fermée, mur, éboulis) : on creuse vers l'escalier, ou on attend.
	var dir := Vector2i(signi(but.x - j.pos.x), signi(but.y - j.pos.y))
	if dir != Vector2i.ZERO and sim.intention(jid, {"type": "creuser", "vers": j.pos + dir}):
		_note("creuse vers l'escalier (pas de chemin)")
		return
	if sim.intention(jid, {"type": "attendre"}):
		attentes += 1
	bloque_depuis += 1
	if bloque_depuis > 200:
		_fin("bloqué sans chemin vers l'escalier")


func _hostile_en_vue(j: Dictionary) -> Dictionary:
	var sim = scene.sim
	var meilleur := {}
	var dmin := 99
	for x in sim.vivants():
		if x.id == j.id or not sim.ennemis(j, x):
			continue
		var d := Grille.distance(j.pos, x.pos)
		if d <= 8 and sim.voit(j, x.pos) and d < dmin:
			dmin = d
			meilleur = x
	return meilleur


func _fin(raison: String) -> void:
	set_process(false)
	var j: Dictionary = scene.sim.entites.get(jid, {})
	_capturer("fin")
	print("PARCOURS : %s — étages descendus %d (arrivé à l'étage %d) · combats %d · coups portés %d · coups reçus %d (%d dégâts) · kills %d · morts %d · ramassages %d · portes ouvertes %d · pas %d · attentes %d · images %d · captures %d · PV finaux %d/%d" % [
		raison, etages_atteints, int(scene.sim.donjon.get("etage", 0)), combats, coups_portes, coups_recus, degats_recus, kills, morts, ramassages, portes_ouvertes, pas, attentes, frames, captures, int(j.get("sante", 0)), int(j.get("sante_max", 0))])
	for ev in evenements:
		print("  ", ev)
	for l in scene.journal:
		print("  journal : ", l)
	get_tree().quit()
