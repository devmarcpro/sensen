extends Node
class_name Sons
## LE JEU N'EST PLUS MUET (ordre de travail 48 — décision du 2026-09-14). La simulation émet `son` pour tout ce qui entre
## dans le champ sonore ; ce nœud joue le son synthétisé de cette source (`assets/sons/<source>.wav`, écrit par
## tools/gen_sons.py), atténué par la distance au joueur. Le client ne décide rien : ce qui ne s'entendrait pas dans le
## champ ne se joue pas ici non plus.

var main: Node2D
var _voix: Array[AudioStreamPlayer] = []
var _flux: Dictionary = {}          # source → AudioStream
var _dernier: Dictionary = {}       # source → ms du dernier jeu
var _rng := RandomNumberGenerator.new()


static func _cfg() -> Dictionary:
	return GameData.config("sonore").get("client", {})


func _ready() -> void:
	_rng.seed = 48
	if AudioServer.get_bus_index(&"Effets") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, &"Effets")
	for nom in ["pas", "coup", "impact", "mort", "porte", "pioche", "effondrement", "explosion"]:
		var chemin := "res://assets/sons/%s.wav" % nom
		if ResourceLoader.exists(chemin):
			_flux[nom] = load(chemin)
	for k in int(_cfg().get("voix_max", 12)):
		var p := AudioStreamPlayer.new()
		p.bus = &"Effets"
		add_child(p)
		_voix.append(p)
	EventBus.son.connect(_entendre)
	EventBus.explosion.connect(func(pos: Vector2i, _rayon: int, _source: String) -> void: _entendre(pos, "explosion", 90.0))


## Ce que le joueur entend de cette source : le volume moins la distance. Rien sous le seuil.
func volume_percu(pos: Vector2i, volume: float) -> float:
	if main == null or main.sim == null:
		return 0.0
	var j: Dictionary = main.joueur()
	if j.is_empty():
		return 0.0
	return volume - float(Grille.distance_plate(j.pos, pos)) * float(_cfg().get("attenuation_par_tuile", 3.0))


func _entendre(pos: Vector2i, source: String, volume: float) -> void:
	if not _flux.has(source) or float(Reglages.options.get("volume_effets", 0.8)) <= 0.0:
		return
	var v := volume_percu(pos, volume)
	if v < float(_cfg().get("seuil", 4.0)):
		return
	var maintenant := Time.get_ticks_msec()
	if maintenant - int(_dernier.get(source, -100000)) < int(_cfg().get("intervalle_ms", 60)):
		return
	_dernier[source] = maintenant
	for p in _voix:
		if not p.playing:
			p.stream = _flux[source]
			p.volume_db = linear_to_db(clampf(v / 100.0, 0.001, 1.0)) + float(_cfg().get("volume_db", -4.0)) + linear_to_db(clampf(float(Reglages.options.get("volume_effets", 0.8)), 0.001, 1.0))
			var var_h := float(_cfg().get("variation_hauteur", 0.08))
			p.pitch_scale = 1.0 + _rng.randf_range(-var_h, var_h)
			p.play()
			return
