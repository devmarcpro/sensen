extends Node
## Capture d'écran automatique de la scène principale (fenêtrée, pas headless) :
##   & Godot --path godot res://scenes/tests/capture.tscn -- --sortie C:/chemin/capture.png [--arene N] [--frames 60]
## Sert à vérifier le rendu sans œil humain disponible ; ne remplace pas le jugement de game feel.

var frames := 0
var cible := 60
var sortie := "user://capture.png"
var arene := 0


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
	if arene > 0:
		scene.arene_courante = arene
		scene._charger()
	# Un survol simulé sur une créature, pour voir la prévisualisation.
	var j: Dictionary = scene.joueur()
	for e in scene.sim.vivants():
		if e.id != j.id:
			scene.survol = e.pos
			break


func _process(_delta: float) -> void:
	frames += 1
	if frames == cible:
		var img := get_viewport().get_texture().get_image()
		img.save_png(sortie)
		print("capture : ", sortie)
		get_tree().quit()
