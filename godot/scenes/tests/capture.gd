extends Node
## Capture d'écran automatique de la scène principale (fenêtrée, pas headless) :
##   & Godot --path godot res://scenes/tests/capture.tscn -- --sortie C:/chemin/capture.png [--arene N] [--frames 60]
## Sert à vérifier le rendu sans œil humain disponible ; ne remplace pas le jugement de game feel.

var frames := 0
var cible := 60
var sortie := "user://capture.png"
var arene := 0
var temps_max := 0.0
var temps_total := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--sortie" and i + 1 < args.size():
			sortie = args[i + 1]
		elif args[i] == "--frames" and i + 1 < args.size():
			cible = int(args[i + 1])
		elif args[i] == "--arene" and i + 1 < args.size():
			arene = int(args[i + 1])
	var scene: Node = load("res://scenes/demo/main.tscn").instantiate()
	add_child(scene)
	scene.profil_sans_ui = "--sans-ui" in args
	scene.profil_sans_terrain = "--sans-terrain" in args
	if scene.titre_ouvert and not ("--titre" in args):   # la capture saute l'écran principal, la création et l'écran Monde
		scene._nouvelle_partie()
		scene._creer_personnage()
		scene._commencer_monde()
		scene.fiche_en_attente = {}
		scene.carte.fermer()
	if "--carte" in args:
		scene.carte.ouvrir("voyage")
	if arene > 0:
		scene.arene_courante = arene
		scene._charger()
	if "--donjon" in args and scene.sim != null:   # --donjon : descendre dans une ruine depuis le camp (voile, brèches…)
		var jd: Dictionary = scene.joueur()
		scene.sim.charger_donjon("ruine", 7, 7, 1, jd)
		scene._apres_changement_de_grille()
	for i3 in args.size():   # --heure H : l'heure du monde (cycle jour-nuit) — après le chargement, qui remet l'horloge
		if args[i3] == "--heure" and i3 + 1 < args.size() and scene.sim != null:
			scene.sim.horloge_monde.ticks = int(float(args[i3 + 1]) / 24.0 * 24000.0)
			scene.sim.maj_vision()
			scene._maj_ambiance()
	if "--torche" in args and scene.sim != null:   # --torche : une torche en main (Éclairage, la nuit)
		var jt0: Dictionary = scene.joueur()
		var torche: Dictionary = scene.sim.generer_objet("torche", 1, {}, "commun", 0)
		if not torche.is_empty():
			jt0.sac.append(torche.uid)
			jt0.equipement["main_secondaire"] = torche.uid
			jt0["vue_sale"] = true
			scene.sim.maj_vision()
			scene._maj_ambiance()
	if "--raid" in args and scene.sim != null:   # --raid : un raid réel en cours (Défense et raids)
		scene.sim._lancer_raid_reel(12.0, scene.sim.horloge_monde.ticks)
		for k in 6:
			scene.sim.pas("monde")
		scene._apres_changement_de_grille()
	if "--talents" in args and scene.sim != null:   # --talents : brèches, affût, lame fantôme, trésor détecté, masque — pour voir les couches récentes
		var sim = scene.sim
		var jt: Dictionary = scene.joueur()
		var t0: int = sim.horloge_monde.ticks
		for d in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(-1, 0), Vector2i(-2, 0), Vector2i(0, -1), Vector2i(3, 0), Vector2i(-3, 0)]:
			var q: Vector2i = jt.pos + d
			if sim.grille.dans(q) and sim.grille.occupant(q).is_empty():
				sim.grille.contenu[sim.grille.idx(q)] = 0
				sim.grille.hauteurs[sim.grille.idx(q)] = sim.grille.h(jt.pos)
		jt["talents_appris"] = ["breche", "affut", "masques"]
		jt["tags_acquis_race"] = ["detection_tresors"]
		sim._contreparties(jt)
		sim._poser_portail(jt, jt.pos + Vector2i(1, 0), t0)
		sim._poser_portail(jt, jt.pos + Vector2i(0, 2), t0)
		sim._deployer_affut(jt, jt.pos + Vector2i(-1, 0), t0)
		sim._porter_masque(jt, "masque_du_taureau", t0)
		jt.mana = 60
		sim._invoquer_arme_fantome(jt, "feu", t0)
		sim.contenants[sim.grille.idx(jt.pos + Vector2i(3, 0))] = ["capture_tresor"]
		sim.grille.poser_contenu(jt.pos + Vector2i(3, 0), "coffre")
		jt["vue_sale"] = true
		sim.maj_vision()
		scene._apres_changement_de_grille()
	for i4 in args.size():   # --sequence a,b,c : une séquence pré-remplie dans le composeur (et ses charges)
		if args[i4] == "--sequence" and i4 + 1 < args.size():
			var seq: Array = Array(args[i4 + 1].split(","))
			var jc: Dictionary = scene.joueur()
			for m in seq:
				scene.sim.crediter_module(jc, str(m), 9)
			scene.ecrans.sequence_composee = seq
	for i2 in args.size():   # --ecran inventaire|atelier|feuille|menu : l'écran ouvert — après le chargement
		if args[i2] == "--ecran" and i2 + 1 < args.size():
			scene.ecrans.ouvrir(args[i2 + 1])
	# Un survol simulé sur une créature, pour voir la prévisualisation.
	var j: Dictionary = scene.joueur()
	for e in scene.sim.vivants():
		if e.id != j.id:
			scene.survol = e.pos
			break


func _process(delta: float) -> void:
	frames += 1
	if frames > 5:   # les premières images chargent ; on mesure ensuite (critère É0 : 60 fps)
		temps_max = maxf(temps_max, delta)
		temps_total += delta
	if frames == cible:
		var img := get_viewport().get_texture().get_image()
		img.save_png(sortie)
		print("capture : ", sortie)
		print("image : moyenne %.1f ms, pire %.1f ms sur %d images" % [temps_total / float(frames - 5) * 1000.0, temps_max * 1000.0, frames - 5])
		get_tree().quit()
