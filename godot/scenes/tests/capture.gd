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
	if not scene.creation.is_empty():
		scene._creer_personnage()   # la capture saute l'écran de création
		scene.fiche_en_attente = {}
		scene.carte.fermer()
	for i3 in args.size():   # --heure H : l'heure du monde (cycle jour-nuit)
		if args[i3] == "--heure" and i3 + 1 < args.size() and scene.sim != null:
			scene.sim.horloge_monde.ticks = int(float(args[i3 + 1]) / 24.0 * 24000.0)
			scene.sim.maj_vision()
	if "--carte" in args:
		scene.carte.ouvrir("voyage")
	for i2 in args.size():   # --ecran inventaire|atelier|feuille : l'écran ouvert
		if args[i2] == "--ecran" and i2 + 1 < args.size():
			scene.ecrans.ouvrir(args[i2 + 1])
	if arene > 0:
		scene.arene_courante = arene
		scene._charger()
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
