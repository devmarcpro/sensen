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


# ---------------------------------------------------------------- lot 2 : l'eau qui change d'état (2026-09-13)

## LA TEMPÉRATURE DE L'AIR d'une cellule à une heure donnée — la même formule que `SimTerrain.temperature_cellule`, mais
## pour n'importe quel instant : c'est ce qui permet de RELIRE le froid passé au lieu de l'accumuler.
static func temperature_a(sim: Simulation, cell: Vector2i, tick: int) -> float:
	if sim.monde == null:
		return 18.0
	var m: Dictionary = GameData.config("planete").get("meteo", {})
	var tc: int = sim.monde.taille
	var temp: float = lerpf(float(m.temp_min), float(m.temp_max), sim.monde.surface.valeur("temperature", cell.x * tc + tc / 2, cell.y * tc + tc / 2)) + float(SimTerrain._saison_info(sim, tick).temp)
	temp += float(GameData.catalogues.weather_states.get(SimTerrain.meteo(sim, cell, tick), {}).get("temp_mod", 0))
	if SimTerrain.est_nuit(sim, tick):
		temp += float(m.get("mod_nuit", -8))
	return temp


## LA NEIGE AU SOL d'une cellule, 0-1 : ce qui est tombé ces derniers jours, moins ce qui a fondu. Relue, jamais tenue.
static func neige_sol(sim: Simulation, cell: Vector2i, tick: int = -1) -> float:
	if sim.monde == null:
		return 0.0
	var c: Dictionary = _cfg().get("neige", {})
	var t := sim.horloge_monde.ticks if tick < 0 else tick
	var jour := int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
	var pas := maxi(1, jour / 4)
	var t0 := t - posmod(t, pas)
	var cle := Vector3i(cell.x, cell.y, -1 - t0 / pas)   # négatif : la neige ne partage pas les clés de l'humidité
	if sim.climat_cache.has(cle):
		return float(sim.climat_cache[cle])
	var n := int(c.get("jours_memoire", 6)) * 4
	var h := 0.0
	var ajout: Dictionary = c.get("ajout", {})
	for k in range(n - 1, -1, -1):   # du plus ancien au plus récent : la fonte ne retire que ce qui est déjà tombé
		var tk := t0 - k * pas
		h += float(ajout.get(SimTerrain.meteo(sim, cell, tk), 0.0))
		var temp := temperature_a(sim, cell, tk)
		if temp > float(c.get("fonte_des", 1.0)):
			h -= (temp - float(c.fonte_des)) * float(c.get("fonte_par_degre", 0.012))
		h = clampf(h, 0.0, 1.0)
	sim.climat_cache[cle] = h
	return h


## LE FROID QUI DURE : la moyenne des dernières heures est-elle sous le seuil de gel ? Un soir froid ne gèle pas un lac.
static func froid_durable(sim: Simulation, cell: Vector2i, seuil: float, tick: int = -1) -> bool:
	if sim.monde == null:
		return false
	var t := sim.horloge_monde.ticks if tick < 0 else tick
	var jour := int(SimTerrain._cycle(sim).get("ticks_par_jour", 24000))
	var heures := int(_cfg().get("gel", {}).get("heures", 36))
	var pas := maxi(1, jour / 8)
	var n := maxi(1, heures / 3)
	var t0 := t - posmod(t, pas)
	var cle := Vector3i(cell.x, cell.y, -100000000 - t0 / pas)   # la moyenne se relit une fois par tranche
	if not sim.climat_cache.has(cle):
		var somme := 0.0
		for k in n:
			somme += temperature_a(sim, cell, t0 - k * pas)
		sim.climat_cache[cle] = somme / float(n)
	return float(sim.climat_cache[cle]) < seuil


## CE QUE LE SOL FAIT À UN PAS : la neige tassée et la boue du sol détrempé ralentissent qui marche à découvert.
static func mult_marche(sim: Simulation, e: Dictionary, t: Vector2i) -> float:
	if sim.lieu != "camp" or sim.monde == null or Etres.est_volant(e) or abrite(sim, t):
		return 1.0
	var cell := sim.monde.cellule_de(t)
	var mult := 1.0
	var nc: Dictionary = _cfg().get("neige", {})
	var neige := neige_sol(sim, cell)
	if neige > float(nc.get("ralentit_des", 0.2)):
		mult *= 1.0 + neige * float(nc.get("ralenti_max", 0.8))
	var bc: Dictionary = _cfg().get("boue", {})
	if detrempe(sim, cell) and float(GameData.catalogues.materials.get(sim.grille.materiau_sol(t), {}).get("stats", {}).get("fertilite", 0)) >= float(bc.get("fertilite_min", 30)):
		mult *= float(bc.get("mult", 1.35))
	return mult


## LES ÉTATS DU CLIMAT : au-delà de `ecart_malus` degrés hors du confort, l'hypothermie ou le coup de chaleur (des malus
## de stats) précèdent la perte de points de vie ; revenus au confort, ils passent d'eux-mêmes à la fin de leur durée.
static func etat_climat(sim: Simulation, e: Dictionary, ecart: float) -> void:
	var c: Dictionary = _cfg().get("etats", {})
	if absf(ecart) < float(c.get("ecart_malus", 5.0)):
		return
	var id := "hypothermie" if ecart < 0.0 else "coup_de_chaleur"
	if not Etres.a_statut_id(e, id):
		sim.appliquer_statut(e, id, int(c.get("duree_ticks", 120000)), "")


# ---------------------------------------------------------------- le vent qui pousse, la pluie qui lave, les murs qui boivent

## LE VENT DU PAS DE CHAMP : celui de la cellule au centre de la fenêtre, à ciel ouvert seulement. Rend {dir, force} ; une
## force nulle sous terre, où rien ne souffle.
static func vent_du_lieu(sim: Simulation) -> Dictionary:
	if sim.lieu != "camp" or sim.monde == null:
		return {"dir": Vector2.ZERO, "force": 0.0}
	var centre := sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	return vent(sim, sim.monde.cellule_de(centre))


## Le poids qu'un vent donne à une voisine dans la direction `d` : plus fort sous le vent, plus faible au vent. `k` est
## l'effet par champ (le gaz file plus que l'odeur). Jamais négatif.
static func biais(v: Dictionary, d: Vector2i, k: float) -> float:
	var f := float(v.get("force", 0.0))
	if f <= 0.0:
		return 1.0
	return maxf(0.1, 1.0 + f * (v.dir as Vector2).dot(Vector2(d).normalized()) * k)


## LA PLUIE LAVE LA PISTE : sous une pluie à découvert, l'odeur s'efface plus vite.
static func mult_lavage(sim: Simulation) -> float:
	if sim.lieu != "camp" or sim.monde == null:
		return 1.0
	var centre := sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	if SimTerrain.meteo(sim, sim.monde.cellule_de(centre)) in ["pluie", "orage", "tempete"]:
		return float(_cfg().get("lavage", {}).get("pluie_mult", 4.0))
	return 1.0


## L'HUMIDITÉ DU LIEU : celle du sol de la cellule au camp, celle de la cellule du donjon ou de la mine sous terre.
static func humidite_du_lieu(sim: Simulation, t: Vector2i) -> float:
	if sim.monde == null:
		return 0.5
	if sim.lieu == "camp":
		return humidite_sol(sim, sim.monde.cellule_de(t))
	var cell: Vector2i = sim.donjon.get("cellule_mine", Vector2i(-9999, -9999))
	if cell.x == -9999:
		cell = sim.donjon.get("cellule", Vector2i(-9999, -9999))
	return 0.5 if cell.x == -9999 else humidite_sol(sim, cell)


## LES MURS QUI BOIVENT : ce qu'une matière perméable garde de sa portance dans un sol humide.
static func mult_portance(sim: Simulation, t: Vector2i, stats: Dictionary) -> float:
	var exces := clampf((humidite_du_lieu(sim, t) - 0.5) / 0.5, 0.0, 1.0)
	if exces <= 0.0:
		return 1.0
	return 1.0 - float(_cfg().get("murs_boivent", {}).get("perte_max", 0.7)) * float(stats.get("permeabilite", 0)) / 100.0 * exces


## L'HEURE DU CLIMAT : quand le sol du lieu bascule en détrempe, ce qui a été creusé est remis en question — une galerie
## de terre tient par temps sec et s'effondre après l'orage.
static func tiquer(sim: Simulation, _tick: int) -> void:
	if sim.monde == null or sim.grille == null:
		return
	var centre := sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	var det := humidite_du_lieu(sim, centre) > float(_cfg().get("sol", {}).get("detrempe_seuil", 0.85))
	if det and not sim.climat_detrempe:
		for idx in sim.grille.modifies.keys():
			sim.support_a_verifier[int(idx)] = true
	sim.climat_detrempe = det
	if det and sim.lieu != "camp":
		suinter(sim, _tick)


## L'EAU QUI TRAVERSE (2026-09-14) : sous terre, un sol détrempé au-dessus fait suinter les parois perméables — des flaques
## naissent au pied d'une paroi de terre, jamais au pied du granit.
static func suinter(sim: Simulation, tick: int) -> int:
	var c: Dictionary = _cfg().get("suintement", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "suintement", tick])
	var n0 := sim.grille.largeur * sim.grille.hauteur_grille
	var poses := 0
	for essai in int(c.get("essais", 30)):
		var t := sim.grille.pos_de(rng.randi_range(0, n0 - 1))
		if not sim.grille.dans(t) or sim.grille.bloque_passage(t) or sim.grille.niveau_liquide(t) > 0 or not sim.grille.occupant(t).is_empty():
			continue
		var perm := 0.0
		for dd in Grille.DIRS:
			var q: Vector2i = t + dd
			if sim.grille.dans(q) and sim.grille.bloque_passage(q):
				var mid := str(sim.grille.materiau_de(q))
				if mid.is_empty():
					mid = str(sim.grille.materiau_defaut)
				perm = maxf(perm, float(GameData.catalogues.materials.get(mid, {}).get("stats", {}).get("permeabilite", 0)))
		if perm < float(c.get("permeabilite_min", 35)):
			continue
		if rng.randf() < perm / 100.0 * float(c.get("chance", 0.5)):
			SimTerrain._poser_eau(sim, t, 1)
			sim.eau_active.erase(sim.grille.idx(t))   # une flaque de suintement ne s'écoule pas
			poses += 1
	return poses


## LES PNJ S'ABRITENT (2026-09-14) : la routine d'un habitant tient compte du temps qu'il fait. Sous la pluie, la place se
## vide ; sous la tempête, les ateliers aussi — la garde tient. Le PNJ va « au lit », c'est-à-dire chez lui.
static func activite_selon_temps(sim: Simulation, e: Dictionary, activite: String, tick: int) -> String:
	if sim.lieu != "camp" or sim.monde == null or activite == "lit" or not e.has("lit"):
		return activite
	var c: Dictionary = _cfg().get("abri_pnj", {})
	if str(e.get("fonction", "")) in c.get("sauf_fonctions", []) or e.get("ai_profile", "") == "garde":
		return activite
	var etat := SimTerrain.meteo(sim, sim.monde.cellule_de(e.pos), tick)
	if activite == "social" and etat in c.get("fuit_social", []):
		return "lit"
	if activite == "poste" and etat in c.get("fuit_poste", []):
		return "lit"
	return activite


## LA DÉCOMPOSITION SUIT LA TEMPÉRATURE (lot 6 — 2026-09-14) : le multiplicateur d'âge de ce qui pourrit dans le lieu. On
## lit la température DE SAISON (le climat et la saison, sans la nuit ni l'averse) : un orage ne fait pas rajeunir une
## carcasse, un hiver la garde. Sous terre, la roche tempère — l'ambiante souterraine.
static func mult_decomposition(sim: Simulation) -> float:
	var dc: Dictionary = _cfg().get("decomposition", {})
	if dc.is_empty():
		return 1.0
	var t := temperature_saison(sim)
	if t < 0.0:
		return float(dc.get("gel_mult", 0.15))
	if t < float(dc.get("froid_sous", 8.0)):
		return float(dc.get("froid_mult", 0.6))
	if t > float(dc.get("chaud_des", 25.0)):
		return float(dc.get("chaud_mult", 1.6))
	return 1.0


## La température de saison du lieu : le climat de la cellule et la saison, sans nuit ni météo ; sous terre, l'ambiante.
static func temperature_saison(sim: Simulation) -> float:
	if sim.lieu != "camp" or sim.monde == null:
		return float(GameData.config("thermique").get("ambiante_souterraine", 12.0))
	var m: Dictionary = GameData.config("planete").get("meteo", {})
	var centre := sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	var t := lerpf(float(m.temp_min), float(m.temp_max), sim.monde.surface.valeur("temperature", centre.x, centre.y)) + float(SimTerrain._saison_info(sim).temp)
	if not sim.meteo_force.is_empty():   # une météo forcée (les essais) dit aussi sa température
		t += float(GameData.catalogues.weather_states.get(sim.meteo_force, {}).get("temp_mod", 0))
	return t


## L'ÂGE DÉCOMPOSÉ d'une chose qui pourrit : l'âge vrai, au rythme de la saison. Rien ne se cumule — une lecture, aucun tick.
static func age_decompose(sim: Simulation, x: Dictionary, cle_ne: String, tick: int) -> float:
	if not x.has(cle_ne):
		return 0.0
	return float(tick - int(x[cle_ne])) * mult_decomposition(sim)


# ---------------------------------------------------------------- lot 7 : la végétation vivante (2026-09-14)

static func _est_vegetal(contenu: Dictionary) -> bool:
	var tags: Array = contenu.get("tags", [])
	return "arbre" in tags or "plante_sauvage" in tags or "plante" in tags or "vegetation" in tags


## CE QUI REPOUSSE, À QUELLE VITESSE : une plante ou un arbre repousse vite sur un sol humide ou sur la cendre, lentement
## dans la sécheresse ou là où les bêtes broutent tout. Rien pour ce qui n'est pas végétal.
static func mult_repousse(sim: Simulation, t: Vector2i, o: Dictionary) -> float:
	if sim.monde == null or sim.lieu != "camp":
		return 1.0
	var defs: Dictionary = sim.grille.contenu_defs
	var id_c := str(sim.grille.contenu_ids[int(o.get("contenu", 0))]) if int(o.get("contenu", 0)) < sim.grille.contenu_ids.size() else ""
	if not _est_vegetal(defs.get(id_c, {})):
		return 1.0
	var v: Dictionary = _cfg().get("vegetation", {})
	var cell := sim.monde.cellule_de(t)
	var mult := 1.0
	var h := humidite_sol(sim, cell)
	if secheresse(sim, cell):
		mult *= float(v.get("sec_mult", 2.0))
	elif h > 0.6:
		mult *= float(v.get("humide_mult", 0.7))
	if str(sim.grille.materiau_sol(t)) == str(v.get("cendre", "cendre")):
		mult *= float(v.get("cendre_mult", 0.5))
	if SimEcologie.mult_recolte(sim, cell) < 1.0:
		mult *= float(v.get("broute_mult", 1.6))
	return mult


## LE FEU LAISSE LA CENDRE : là où brûlait une plante ou un arbre, le sol devient de la cendre — fertile.
static func cendrer(sim: Simulation, t: Vector2i, contenu: Dictionary) -> void:
	if not _est_vegetal(contenu):
		return
	var cendre := str(_cfg().get("vegetation", {}).get("cendre", "cendre"))
	if not GameData.catalogues.materials.has(cendre):
		return
	sim.grille.sols[sim.grille.idx(t)] = cendre
	sim.grille.recompiler_sols()


## LA SÉCHERESSE FLÉTRIT : une semaine sèche, les plantes sauvages de la fenêtre peuvent flétrir. Rend combien.
static func fletrir(sim: Simulation) -> int:
	if sim.monde == null or sim.lieu != "camp":
		return 0
	var chance := float(_cfg().get("vegetation", {}).get("fletrit_chance", 0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "fletrir", sim.monde.semaine_courante])
	var n := 0
	var n0 := sim.grille.largeur * sim.grille.hauteur_grille
	for i in n0:
		if sim.grille.contenu[i] == 0:
			continue
		var t := sim.grille.pos_de(i)
		if not ("plante_sauvage" in sim.grille.contenu_de(t).get("tags", [])):
			continue
		if not secheresse(sim, sim.monde.cellule_de(t)) or rng.randf() >= chance:
			continue
		SimTerrain._memoriser_terrain(sim, t)
		sim.grille.contenu[i] = 0
		sim.grille.marquer(t)
		EventBus.emettre(&"tile_changed", [t])
		n += 1
	if n > 0:
		EventBus.emettre(&"journal", [&"journal.secheresse_fletrit", {"n": n}])
	return n


# ---------------------------------------------------------------- lot 9 : l'inondation et l'assèchement (2026-09-14)

## LE RUISSELLEMENT : une heure de pluie sur un sol détrempé — la terre ne boit plus, les bas-fonds se remplissent et
## l'eau coule (elle reste active, le champ de l'eau la fait descendre). Rend le nombre de tuiles noyées.
static func inonder(sim: Simulation, tick: int) -> int:
	if sim.lieu != "camp" or sim.monde == null:
		return 0
	var c: Dictionary = _cfg().get("inondation", {})
	var centre := sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	var cell := sim.monde.cellule_de(centre)
	if not detrempe(sim, cell) or not (SimTerrain.meteo(sim, cell) in c.get("pluies", [])):
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "inondation", tick])
	var n0 := sim.grille.largeur * sim.grille.hauteur_grille
	var poses := 0
	for essai in int(c.get("essais", 400)):
		if poses >= int(c.get("tuiles", 40)):
			break
		var t := sim.grille.pos_de(rng.randi_range(0, n0 - 1))
		if not sim.grille.dans(t) or sim.grille.bloque_passage(t) or sim.grille.niveau_liquide(t) > 0 or abrite(sim, t) or not sim.grille.occupant(t).is_empty() or sim.grille.meubles.has(sim.grille.idx(t)):
			continue
		var bas := true
		for dd in Grille.DIRS:
			var q: Vector2i = t + dd
			if sim.grille.dans(q) and sim.grille.h(q) < sim.grille.h(t):
				bas = false
				break
		if not bas:
			continue
		SimTerrain._poser_eau(sim, t, 1)
		poses += 1
	if poses > 0:
		EventBus.emettre(&"journal", [&"journal.inondation_ruissellement", {"n": poses}])
	return poses


## L'ASSÈCHEMENT : une heure de sécheresse, les flaques s'évaporent (celles qu'aucune source n'alimente).
static func assecher(sim: Simulation) -> void:
	if sim.lieu != "camp" or sim.monde == null:
		return
	var centre := sim.grille.pos_de(sim.grille.largeur * sim.grille.hauteur_grille / 2)
	if secheresse(sim, sim.monde.cellule_de(centre)):
		SimTerrain._evaporation(sim)


## LES LIQUIDES GÈLENT (lot 12 — 2026-09-14) : par grand froid, une potion ou une boisson gèle dans le sac et ne se boit
## plus ; près d'un feu, elle dégèle. L'hiver se prépare : on ne compte pas sur une potion gelée au milieu d'un blizzard.
static func gele(sim: Simulation, e: Dictionary, it: Dictionary) -> bool:
	var c: Dictionary = _cfg().get("liquides", {})
	var liquide := false
	for tag in it.get("tags", []):
		if str(tag) in c.get("tags", []):
			liquide = true
			break
	if not liquide:
		return false
	if SimTerrain.ambiante_de(sim) >= float(c.get("gel_sous", -6.0)):
		return false
	return SimTerrain.chaleur_a(sim, e.pos) < float(c.get("degel_des", 5.0))
