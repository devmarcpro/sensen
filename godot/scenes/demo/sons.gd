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
var _fond: AudioStreamPlayer = null   # l'ambiance (48, lot 2) : une boucle de fond, choisie par le lieu, le temps et l'heure
var _piste := ""


static func _cfg() -> Dictionary:
	return GameData.config("sonore").get("client", {})


func _ready() -> void:
	_rng.seed = 48
	if AudioServer.get_bus_index(&"Effets") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, &"Effets")
	for nom in ["pas", "coup", "impact", "mort", "porte", "pioche", "effondrement", "explosion", "sifflet",
			"amb_vent", "amb_pluie", "amb_vagues", "amb_oiseaux", "amb_grillons", "amb_souterrain"]:
		var chemin := "res://assets/sons/%s.wav" % nom
		if ResourceLoader.exists(chemin):
			_flux[nom] = load(chemin)
	for k in int(_cfg().get("voix_max", 12)):
		var p := AudioStreamPlayer.new()
		p.bus = &"Effets"
		add_child(p)
		_voix.append(p)
	_fond = AudioStreamPlayer.new()
	_fond.bus = &"Effets"
	add_child(_fond)
	_fond.finished.connect(func() -> void: _fond.play())   # la boucle : on relance à la fin
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


## L'AMBIANCE QUE CE LIEU DEMANDE (48, lot 2 — 2026-09-18) : la première règle de `sonore.ambiance.regles` dont les
## conditions tiennent. Rien n'est écrit dans le code : le donjon gronde, la pluie couvre tout, la côte a ses vagues,
## la nuit ses grillons, la forêt ses oiseaux, et le reste du vent.
static func ambiance_pour(sim: Simulation, pos: Vector2i) -> String:
	var amb: Dictionary = GameData.config("sonore").get("ambiance", {})
	if amb.is_empty() or sim == null:
		return ""
	var cell := sim.monde.cellule_de(pos) if sim.monde != null else Vector2i.ZERO
	var tags_b: Array = GameData.catalogues.biomes.get(str(sim.monde.surface.resume_cellule(cell).biome), {}).get("tags", []) if sim.monde != null and sim.lieu == "camp" else []
	var tags_m: Array = GameData.catalogues.weather_states.get(str(SimTerrain.meteo(sim, cell)), {}).get("effects", []) if sim.monde != null and sim.lieu == "camp" else []
	var nuit := SimTerrain.est_nuit(sim)
	for r in amb.get("regles", []):
		var si: Dictionary = r.get("si", {})
		var ok := true
		if si.has("lieu") and str(si.lieu) != str(sim.lieu):
			ok = false
		if si.has("nuit") and bool(si.nuit) != nuit:
			ok = false
		if si.has("meteo_tags"):
			ok = ok and (si.meteo_tags as Array).any(func(t: String) -> bool: return t in tags_m)
		if si.has("biome_tags"):
			ok = ok and (si.biome_tags as Array).any(func(t: String) -> bool: return t in tags_b)
		if ok:
			return str(r.get("piste", ""))
	return ""


## La boucle de fond suit ce que demande le lieu. Appelée à chaque image : elle ne fait rien tant que la piste ne change pas.
func _process(_delta: float) -> void:
	if _fond == null or main == null or main.sim == null:
		return
	var j: Dictionary = main.joueur()
	if j.is_empty():
		return
	var voulue := ambiance_pour(main.sim, j.pos)
	var amb: Dictionary = GameData.config("sonore").get("ambiance", {})
	var vol := float(Reglages.options.get("volume_effets", 0.8))
	if voulue == _piste:
		_fond.volume_db = float(amb.get("volume_db", -20.0)) + linear_to_db(clampf(vol, 0.001, 1.0))
		return
	_piste = voulue
	if voulue.is_empty() or not _flux.has(voulue) or vol <= 0.0:
		_fond.stop()
		return
	_fond.stream = _flux[voulue]
	_fond.volume_db = float(amb.get("volume_db", -20.0)) + linear_to_db(clampf(vol, 0.001, 1.0))
	_fond.play()

