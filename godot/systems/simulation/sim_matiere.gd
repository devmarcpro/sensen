class_name SimMatiere
extends RefCounted
## LA MATIÈRE AUX CROISEMENTS (ordre de travail 22 ter, lot 3 — 2026-09-13 ; designer : « regarde les matériaux, je veux une
## simulation profonde avec gameplay émergent »). Les dix-huit stats d'une matière étaient toutes lues, mais chacune par
## UN système : la friction par la marche, la conductivité par la foudre sur le terrain, la densité par le poids. L'émergent
## naît aux croisements — une armure de plaques est lourde, ET bruyante, ET conductrice, ET chaude au soleil, ET elle coule.
## Aucune matière n'est nommée ici : ce sont ses stats qui décident.

static func _cfg() -> Dictionary:
	return GameData.config("matiere")


## Les stats de matière d'un objet : celles de son matériau, sinon de sa pièce maîtresse.
static func stats_objet(it: Dictionary) -> Dictionary:
	var mat := str(it.get("materiau", ""))
	if mat.is_empty():
		for sc in (it.get("composants", {}) as Dictionary).keys():
			mat = str((it.composants[sc] as Dictionary).get("materiau", ""))
			if not mat.is_empty():
				break
	return GameData.catalogues.materials.get(mat, {}).get("stats", {})


## Les pièces d'ARMURE portées (pas l'arme), avec leurs stats de matière.
static func armure(sim: Simulation, e: Dictionary) -> Array:
	var res: Array = []
	for slot in e.get("equipement", {}).keys():
		var it: Dictionary = sim.items.get(str(e.equipement[slot]), {})
		if str(it.get("type", "")) != "armure":
			continue
		var st := stats_objet(it)
		if not st.is_empty():
			res.append(st)
	return res


## LE PAS QUI SONNE : chaque pas émet selon la densité et la dureté de l'armure. Un pas nu reste sous le seuil
## d'audibilité — c'est l'armure qui s'entend, pas l'être.
static func volume_pas(sim: Simulation, e: Dictionary) -> float:
	var c: Dictionary = _cfg().get("pas", {})
	var v := float(c.get("base", 3.0))
	for st in armure(sim, e):
		v += minf(float(c.get("piece_max", 4.0)), float(st.get("densite", 0)) * float(st.get("durete", 0)) / maxf(1.0, float(c.get("div", 60.0))))
	return v


static func sonner_pas(sim: Simulation, e: Dictionary, t: Vector2i) -> void:
	var v := volume_pas(sim, e)
	var cfg_s: Dictionary = GameData.config("sonore")
	if not e.is_empty():
		v -= float(sim.regles.niveau(e.get("competences_eff", {}), "discretion")) * float(cfg_s.get("discretion_par_niveau", 0.0))
	if v >= float(cfg_s.get("seuil_audible", 5.0)):
		SimTerrain.sonner(sim, t, v)
		EventBus.emettre(&"son", [t, "pas", v])


## LA CONDUCTIVITÉ PORTÉE : la moyenne de la conductivité électrique de l'armure, pondérée par le nombre de pièces (une
## seule pièce de fer ne fait pas un paratonnerre, une armure complète oui).
static func conduction(sim: Simulation, e: Dictionary) -> float:
	var total := 0.0
	for st in armure(sim, e):
		total += float(st.get("conductivite_electrique", 0))
	return total / 5.0


## LE LEST DANS L'EAU : une armure dense et peu flottante tire vers le fond. 0 pour qui nage nu.
static func lest(sim: Simulation, e: Dictionary) -> float:
	var pieces := armure(sim, e)
	if pieces.is_empty():
		return 0.0
	var total := 0.0
	for st in pieces:
		total += maxf(0.0, float(st.get("densite", 0)) * 10.0 - float(st.get("flottabilite", 50)))
	return total / float(pieces.size()) / maxf(1.0, float(_cfg().get("nage", {}).get("lest_div", 60.0))) * minf(1.0, float(pieces.size()) / 3.0)


## LE MÉTAL AU SOLEIL ET AU GEL : ce que l'armure ajoute au ressenti. Conductrice et peu isolante, elle chauffe au soleil
## et glace au froid ; isolante, elle ne transmet rien.
static func ecart_thermique(sim: Simulation, e: Dictionary, temp: float) -> float:
	var c: Dictionary = _cfg().get("thermique", {})
	var pieces := armure(sim, e)
	if pieces.is_empty():
		return 0.0
	var k := 0.0
	for st in pieces:
		k += float(st.get("conductivite_electrique", 0)) / 100.0 * (1.0 - float(st.get("isolation", 0)) / 100.0)
	k = k / 5.0
	var ecart_max := float(c.get("ecart_max", 7.0))
	if temp > float(c.get("chaud_des", 28.0)):
		return minf(ecart_max, (temp - float(c.chaud_des)) * k * 1.5 + k * 3.0)
	if temp < float(c.get("froid_sous", 5.0)):
		return -minf(ecart_max, (float(c.froid_sous) - temp) * k * 1.5 + k * 3.0)
	return 0.0


## L'USURE PAR LE MOUILLÉ : une heure trempée use ce qu'on porte et ce qu'on transporte, selon l'altération de la matière —
## le fer rouille, le bois gonfle, la pierre ne bouge pas.
static func user_mouille(sim: Simulation, e: Dictionary, heures: float) -> void:
	var m := float(e.get("mouille", 0)) / 100.0
	if m <= 0.0 or heures <= 0.0:
		return
	var base := float(_cfg().get("usure_mouille", 0.0004)) * heures * m
	var plafond := float(sim.regles.r.get("usure", {}).get("usure_max", 0.5))
	var uids: Array = []
	for slot in e.get("equipement", {}).keys():
		uids.append(str(e.equipement[slot]))
	for uid in e.get("sac", []):
		uids.append(str(uid))
	for uid in uids:
		var it: Dictionary = sim.items.get(uid, {})
		var st := stats_objet(it)
		if st.is_empty():
			continue
		var avant := float(it.get("usure", 0.0))
		it["usure"] = minf(plafond, avant + base * float(st.get("alteration", 50)) / 50.0)
		if avant < plafond and float(it.usure) >= plafond:
			EventBus.emettre(&"journal", [&"journal.objet_rouille", {"objet": SimObjets.nom_objet(sim, uid)}])


## LA FRICTION D'UN PAS : celle du sol, baissée par la pluie à découvert et par le gel.
static func friction_pas(sim: Simulation, t: Vector2i) -> float:
	var c: Dictionary = _cfg().get("glissade", {})
	var f := float(GameData.catalogues.materials.get(sim.grille.materiau_sol(t), {}).get("stats", {}).get("friction", 50))
	if sim.grille.gel:
		f *= float(c.get("gel_mult", 0.3))
	elif sim.lieu == "camp" and sim.monde != null and not SimClimat.abrite(sim, t) and SimTerrain.meteo(sim, sim.monde.cellule_de(t)) in ["pluie", "orage", "tempete"]:
		f *= float(c.get("mouille_mult", 0.55))
	return f


## LA GLISSADE : sous le seuil, un pas peut faire glisser — on perd du temps, et le journal le dit au joueur.
static func glisser(sim: Simulation, e: Dictionary, t: Vector2i, tick: int) -> bool:
	if Etres.est_volant(e) or SimTerrain.dans_l_eau(sim, t):
		return false
	var c: Dictionary = _cfg().get("glissade", {})
	var f := friction_pas(sim, t)
	var seuil := float(c.get("seuil", 22.0))
	if f >= seuil:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "glissade", str(e.id), tick])
	if rng.randf() * 100.0 >= seuil - f:
		return false
	e.compteur = int(e.compteur) + int(c.get("ticks", 600))
	if e.controle == "joueur":
		EventBus.emettre(&"journal", [&"journal.glissade", {"nom": e.name_key}])
	return true


## LE MANA DANS L'ARMURE (lot 4 — 2026-09-14) : ce que l'armure fait au coût d'un sort. Le fer conduit mal le mana et le
## renchérit ; l'argent le conduit et l'allège. Un mage en plaques paie sa protection en mana — personne ne l'interdit.
static func mult_mana_armure(sim: Simulation, e: Dictionary) -> float:
	var c: Dictionary = _cfg().get("mana_armure", {})
	var pieces := armure(sim, e)
	if pieces.is_empty():
		return 1.0
	var total := 0.0
	for st in pieces:
		total += float(st.get("conductivite_mana", c.get("reference", 30.0)))
	var moy := total / float(pieces.size())
	var ecart := (float(c.get("reference", 30.0)) - moy) / maxf(1.0, float(c.get("div", 110.0))) * float(pieces.size())
	return clampf(1.0 + ecart, float(c.get("min", 0.8)), float(c.get("max", 1.4)))


## LA FUMÉE (lot 4) : ce qu'un feu rejette dans le champ des gaz à chaque pas.
static func fumer(sim: Simulation, t: Vector2i, flammabilite: float) -> void:
	var c: Dictionary = _cfg().get("fumee", {})
	var gaz := str(c.get("gaz", ""))
	if gaz.is_empty() or not GameData.catalogues.gaz.has(gaz):
		return
	SimTerrain.ajouter_gaz(sim, t, gaz, float(c.get("charge", 0.05)) * clampf(flammabilite / 100.0, 0.2, 1.0))
