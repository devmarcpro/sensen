class_name SimClimat
extends RefCounted
## LE CLIMAT VIVANT (2026-09-13 ; designer : « t'as codé tout ce qui est lié à la température, l'humidité etc ? N'oublie pas
## qu'on veut simuler le plus possible »). La météo existait — un état par cellule, une température, un ressenti qui ne
## lisait que l'équipement — mais rien ne MOUILLAIT, rien ne SÉCHAIT, le vent n'avait ni direction ni force, un feu de camp
## ne réchauffait personne et la pluie de la veille n'avait laissé aucune trace dans le sol.
##
## **Ce qui peut se déduire ne se balaie pas** : le vent et l'humidité du sol se RELISENT de la graine et de l'heure — la
## pluie des cinq derniers jours se retrouve en interrogeant la météo passée, pas en l'accumulant tick après tick. Seul
## l'être mouillé porte un état, parce qu'il dépend de ce que l'être a fait (s'abriter, nager, se chauffer).

static func _cfg() -> Dictionary:
	return GameData.config("climat")


## LE VENT d'une cellule : {dir: Vector2 (unitaire), force: 0-1}. Un bruit qui défile avec le temps pour la direction et
## la force de fond, plus ce qu'ajoute l'état météo (une tempête souffle).
static func vent(sim: Simulation, cell: Vector2i, tick: int = -1) -> Dictionary:
	if sim.monde == null:
		return {"dir": Vector2.RIGHT, "force": 0.0}
	var c: Dictionary = _cfg().get("vent", {})
	var t := sim.horloge_monde.ticks if tick < 0 else tick
	var n: FastNoiseLite = sim.monde.surface.bruits.get("vent")
	if n == null:
		n = FastNoiseLite.new()
		n.seed = sim.monde.surface.graine + 911
		n.frequency = float(c.get("frequence_spatiale", 0.0004))
		n.fractal_octaves = 2
		sim.monde.surface.bruits["vent"] = n
	var tc: int = sim.monde.taille
	var phase := float(t) / float(c.get("ticks_par_tour", 1800000)) * 1000.0
	var x := float(cell.x * tc)
	var y := float(cell.y * tc)
	var angle := (n.get_noise_2d(x + phase, y) + 1.0) * PI
	var force := clampf((n.get_noise_2d(y - phase * 0.7, x + 5000.0) + 1.0) * 0.5 - 0.2, 0.0, 1.0)
	force = clampf(force + float((c.get("bonus_meteo", {}) as Dictionary).get(SimTerrain.meteo(sim, cell, t), 0.0)), 0.0, 1.0)
	return {"dir": Vector2(cos(angle), sin(angle)), "force": force}


## L'HUMIDITÉ DU SOL d'une cellule, 0-1 : la base du climat (couche `humidite`) plus la pluie tombée ces derniers jours,
## pondérée par son ancienneté, moins ce que la chaleur a séché. Relue de la météo passée : rien ne s'accumule.
static func humidite_sol(sim: Simulation, cell: Vector2i, tick: int = -1) -> float:
	if sim.monde == null:
		return 0.5
	var c: Dictionary = _cfg().get("sol", {})
	var t := sim.horloge_monde.ticks if tick < 0 else tick
	var jour := int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
	var pas := maxi(1, jour * int(c.get("pas_heures", 6)) / 24)
	var t0 := t - posmod(t, pas)   # aligné sur le pas : deux lectures dans la même tranche rendent le même nombre
	var cle := Vector3i(cell.x, cell.y, t0 / pas)
	if sim.climat_cache.has(cle):
		return float(sim.climat_cache[cle])
	var tc: int = sim.monde.taille
	var h := float(sim.monde.surface.valeur("humidite", cell.x * tc + tc / 2, cell.y * tc + tc / 2))
	var n := int(c.get("jours_memoire", 5)) * 24 / maxi(1, int(c.get("pas_heures", 6)))
	var poids: Dictionary = c.get("pluie_poids", {})
	for k in n:
		var tk := t0 - k * pas
		var anciennete := 1.0 - float(k) / float(n)
		var etat := SimTerrain.meteo(sim, cell, tk)
		h += float(poids.get(etat, 0.0)) * anciennete
		if etat in ["clair", "canicule", "vent_fort"]:
			h -= float(c.get("sechage_chaud", 0.02)) * anciennete * (2.0 if etat == "canicule" else 1.0)
	var res := clampf(h, 0.0, 1.0)
	if sim.climat_cache.size() > 4096:
		sim.climat_cache.clear()
	sim.climat_cache[cle] = res
	return res


static func secheresse(sim: Simulation, cell: Vector2i) -> bool:
	return humidite_sol(sim, cell) < float(_cfg().get("sol", {}).get("secheresse_seuil", 0.22))


static func detrempe(sim: Simulation, cell: Vector2i) -> bool:
	return humidite_sol(sim, cell) > float(_cfg().get("sol", {}).get("detrempe_seuil", 0.85))


## UN ABRI : sous un toit (une tuile couverte par un bâtiment), à l'étage, ou sous terre. La pluie n'y tombe pas, le vent
## n'y souffle pas.
static func abrite(sim: Simulation, t: Vector2i) -> bool:
	if sim.lieu != "camp":
		return true
	if not sim.grille.dans(t):
		return false
	var n0 := sim.grille.largeur * sim.grille.hauteur_grille
	var ig := sim.grille.idx(t) % n0
	return ig < sim.grille.niveaux_bat.size() and int(sim.grille.niveaux_bat[ig]) > 0


## L'ÊTRE MOUILLÉ, 0-100 : il se mouille sous la pluie s'il n'est pas abrité, il est trempé dans l'eau, et il sèche —
## plus vite au chaud, au vent, et près d'un feu (la chaleur locale du champ, au-dessus de l'ambiante).
static func maj_mouille(sim: Simulation, e: Dictionary, tick: int) -> void:
	var c: Dictionary = _cfg().get("etre", {})
	if not e.has("mouille_tick"):
		e["mouille_tick"] = tick
		e["mouille"] = int(e.get("mouille", 0))
	var heures := float(tick - int(e.mouille_tick)) / maxf(1.0, float(SimTerrain._cycle(sim).get("ticks_par_jour", 24000)) / 24.0)
	if heures <= 0.0:
		return
	e.mouille_tick = tick
	var m := float(e.get("mouille", 0))
	if SimTerrain.dans_l_eau(sim, e.pos):
		e.mouille = 100
		return
	var cell := sim.monde.cellule_de(e.pos) if sim.monde != null else Vector2i.ZERO
	var etat := SimTerrain.meteo(sim, cell) if sim.lieu == "camp" and sim.monde != null else "clair"
	if not abrite(sim, e.pos):
		m += float((c.get("mouille_par_heure", {}) as Dictionary).get(etat, 0.0)) * heures
	var temp := SimTerrain.ambiante_de(sim)
	var sechage := float(c.get("sechage_base", 10)) + maxf(0.0, temp) * float(c.get("sechage_par_degre", 0.6))
	if not abrite(sim, e.pos) and sim.lieu == "camp":
		sechage += float(vent(sim, cell).force) * float(c.get("sechage_vent", 15))
	if SimTerrain.chaleur_a(sim, e.pos) > temp + float(c.get("feu_ecart", 10.0)):
		sechage += float(c.get("sechage_feu", 40))
	m -= sechage * heures
	e.mouille = clampi(roundi(m), 0, 100)


## Ce que le climat fait au RESSENTI d'une température brute : le feu proche, l'abri, le vent, le mouillé, l'air lourd.
## Rend {temp, iso_mult} — `iso_mult` est ce que le mouillé laisse de l'isolation de l'équipement.
static func corriger_ressenti(sim: Simulation, e: Dictionary, temp: float, temp_mod_meteo: float) -> Dictionary:
	var r: Dictionary = _cfg().get("ressenti", {})
	var t := temp
	var iso_mult := 1.0
	var sous_toit := abrite(sim, e.pos)
	if sous_toit and sim.lieu == "camp":
		t -= minf(0.0, temp_mod_meteo)   # la pluie et la neige ne rafraîchissent plus sous un toit
		t += float(r.get("abri_bonus", 3.0))
	elif sim.lieu == "camp" and sim.monde != null:
		var v := vent(sim, sim.monde.cellule_de(e.pos))
		if t < float(r.get("vent_froid_sous", 15.0)):
			t -= float(v.force) * float(r.get("vent_froid", 8.0))
	var local := SimTerrain.chaleur_a(sim, e.pos)
	if local > t:
		t = local   # un feu de camp, une forge, une coulée : la chaleur du champ l'emporte sur l'air
	t += SimMatiere.ecart_thermique(sim, e, t)   # le métal chauffe au soleil et glace au gel (22 ter)
	var m := float(e.get("mouille", 0)) / 100.0
	if m > 0.0:
		t -= m * float(r.get("mouille_froid", 7.0))
		iso_mult = 1.0 - m * float(r.get("mouille_isolation", 0.6))
	if t > float(r.get("lourdeur_des", 25.0)) and sim.lieu == "camp" and sim.monde != null:
		var hum := float(sim.monde.surface.valeur("humidite", e.pos.x, e.pos.y))
		t += maxf(0.0, hum - 0.5) * float(r.get("lourdeur", 8.0))
	return {"temp": t, "iso_mult": iso_mult}


## La soif suit la chaleur : au-dessus du seuil, chaque degré ressenti fait boire un peu plus vite.
static func soif_chaleur(temp: float) -> float:
	var s: Dictionary = _cfg().get("soif", {})
	return 1.0 + maxf(0.0, temp - float(s.get("seuil", 25.0))) * float(s.get("par_degre", 0.06))


## Ce que l'humidité du sol fait à la flammabilité : un sol sec brûle mieux, un sol détrempé à peine.
static func mult_feu(sim: Simulation, t: Vector2i) -> float:
	if sim.lieu != "camp" or sim.monde == null:
		return 1.0
	var f: Dictionary = _cfg().get("feu", {})
	return lerpf(float(f.get("sec_mult", 1.5)), float(f.get("detrempe_mult", 0.4)), humidite_sol(sim, sim.monde.cellule_de(t)))


## Ce que l'eau du sol fait à une récolte : la sécheresse et le sol détrempé rendent moins.
static func mult_recolte(sim: Simulation, cell: Vector2i, irrigue: bool = false) -> float:
	var rc: Dictionary = _cfg().get("recoltes", {})
	if detrempe(sim, cell):
		return float(rc.get("detrempe_mult", 0.8))
	if secheresse(sim, cell) and not irrigue:
		return float(rc.get("secheresse_mult", 0.55))
	return 1.0
