class_name SimCorps
extends RefCounted
## LES CORPS EN MOUVEMENT (ordre de travail 27 bis, lot 1 — 2026-09-14). Un projectile était une ligne de Bresenham
## résolue d'un coup : rien ne voyageait, rien n'avait de masse. Un corps lancé a maintenant une MASSE et une VITESSE ;
## il avance d'une tuile à la fois, au fil des ticks, et ce qu'il rencontre le reçoit selon `masse × vitesse`.
##
## **Un corps en vol est une entrée de `sim.bombes`** (`corps: true`) : il se range sur l'horloge de son lanceur et passe
## par la même file que les explosions, en temps réel comme au tour par tour — sans une seconde machinerie d'échéances.
## Chaque pas le repousse à la tuile suivante.
##
## Les décisions du 2026-09-14 : une tuile à la fois (`ticks_par_tuile`) ; le recul se transmet sur deux maillons ; le
## joueur est un corps pour les chocs, jamais pour la marche.

static func _cfg() -> Dictionary:
	return GameData.config("corps")


## Combien de ticks pour franchir une tuile à cette vitesse (tuiles par seconde). Jamais moins d'un.
static func ticks_par_tuile(sim: Simulation, vitesse: float) -> int:
	return maxi(1, roundi(float(sim.regles.r.get("ticks_par_seconde_exploration", 1000)) / maxf(0.01, vitesse)))


## La masse d'un être : sa fiche si elle la dit, sinon ses tags, sinon la valeur par défaut.
static func masse_etre(x: Dictionary) -> float:
	var def: Dictionary = GameData.catalogues.creatures.get(str(x.get("def", "")), {})
	if def.has("masse"):
		return float(def.masse)
	var m: Dictionary = _cfg().get("masse_etres", {})
	for tag in ["insecte", "volant", "robot", "bete"]:
		if tag in x.get("tags", def.get("tags", [])):
			return float(m.get(tag, 70.0))
	return float(m.get("defaut", 70.0))


## LANCER UN CORPS de `depart` vers `cible`. `uid` : l'objet qui vole (il retombera), vide pour un corps sans objet.
static func lancer(sim: Simulation, source: Dictionary, depart: Vector2i, cible: Vector2i, masse: float, vitesse: float, uid: String = "", portee: int = 999) -> Dictionary:
	if depart == cible or masse <= 0.0 or vitesse <= 0.0:
		return {}
	var trajet: Array = sim.grille.trajectoire(depart, cible)
	trajet.append(cible)
	if trajet.size() > portee:
		trajet = trajet.slice(0, portee)
	var horloge := str(source.get("horloge", "monde"))
	var h: Horloge = sim.horloge_monde if horloge == "monde" or not sim.combats.has(horloge) else sim.combats[horloge].horloge
	var corps := {"corps": true, "pos": depart, "trajet": trajet, "i": 0, "masse": masse, "vitesse": vitesse, "uid": uid,
		"source": str(source.get("id", "")), "horloge": horloge, "fin": h.ticks + ticks_par_tuile(sim, vitesse)}
	sim.bombes.append(corps)
	return corps


## LE PAS D'UN CORPS : une tuile. Un mur l'arrête, un être le reçoit ; sinon il continue, ou retombe au bout de sa course.
static func pas(sim: Simulation, b: Dictionary) -> void:
	var trajet: Array = b.trajet
	if int(b.i) >= trajet.size():
		_retomber(sim, b, b.pos)
		return
	var t: Vector2i = trajet[int(b.i)]
	var dir := Vector2i(signi(t.x - b.pos.x), signi(t.y - b.pos.y))
	if not sim.grille.dans(t) or sim.grille.bloque_passage(t):
		_sonner(sim, b.pos, float(b.masse) * float(b.vitesse))
		EventBus.emettre(&"journal", [&"journal.corps_mur", {}])
		_retomber(sim, b, b.pos)
		return
	var occ := sim.grille.occupant(t)
	if not occ.is_empty() and occ != str(b.source) and sim.entites.has(occ) and sim.entites[occ].vivant:
		frapper(sim, sim.entites[occ], dir, float(b.masse) * float(b.vitesse), str(b.source))
		_retomber(sim, b, t)
		return
	b.pos = t
	b.i = int(b.i) + 1
	if int(b.i) >= trajet.size():
		_retomber(sim, b, t)
		return
	b.fin = int(b.fin) + ticks_par_tuile(sim, float(b.vitesse))
	sim.bombes.append(b)


## LE CHOC : `p` = masse × vitesse. Des dégâts contondants, le son, et le recul.
static func frapper(sim: Simulation, x: Dictionary, dir: Vector2i, p: float, source: String) -> void:
	var c := _cfg()
	var deg := maxi(1, roundi(p * float(c.get("degats_par_quantite", 0.35))))
	EventBus.emettre(&"journal", [&"journal.corps_impact", {"nom": x.name_key, "degats": deg}])
	_sonner(sim, x.pos, p)
	sim._appliquer_degats(x, deg, source, {"type": "contondant", "element": {}, "impact": true})
	pousser(sim, x, dir, p, source, 0)


## LE RECUL : `recul_par_quantite × p / masse` tuiles. Ce qu'il heurte en reculant recule à son tour, avec la moitié de p,
## sur deux maillons ; un mur fait le choc de poussée ordinaire (un dé par tuile perdue).
static func pousser(sim: Simulation, x: Dictionary, dir: Vector2i, p: float, source: String, maillon: int) -> int:
	var c := _cfg()
	if dir == Vector2i.ZERO or not x.vivant or maillon > int(c.get("maillons_max", 2)) or Etres.bloque_statuts(x, "projection", sim.statuts_defs):
		return 0
	var n := floori(p * float(c.get("recul_par_quantite", 0.02)) / maxf(0.1, masse_etre(x)))
	var faits := 0
	for k in n:
		var q: Vector2i = x.pos + dir
		if not sim.grille.dans(q) or sim.grille.bloque_passage(q):
			sim._choc_de_poussee(x, q, n - k, source)
			return faits
		var occ := sim.grille.occupant(q)
		if not occ.is_empty() and occ != str(x.id):
			var autre: Dictionary = sim.entites.get(occ, {})
			if autre.is_empty() or not autre.vivant:
				return faits
			if maillon < int(c.get("maillons_max", 2)):
				pousser(sim, autre, dir, p * float(c.get("part_transmise", 0.5)), source, maillon + 1)
			if not sim.grille.occupant(q).is_empty():
				sim._choc_de_poussee(x, q, n - k, source)
				return faits
		sim.grille.liberer(x.pos, x.id)
		x.pos = q
		sim.grille.placer(x.id, q)
		faits += 1
	return faits


static func _sonner(sim: Simulation, t: Vector2i, p: float) -> void:
	var c := _cfg()
	SimTerrain.sonner(sim, t, minf(float(c.get("son_max", 70.0)), p * float(c.get("son_par_quantite", 0.25))))


static func _retomber(sim: Simulation, b: Dictionary, t: Vector2i) -> void:
	var uid := str(b.get("uid", ""))
	if uid.is_empty() or not sim.items.has(uid):
		return
	var sol := t
	if not sim.grille.dans(sol) or sim.grille.bloque_passage(sol):
		sol = b.pos
	SimTerrain._poser_ou_couler(sim, sol, [uid], "butin")


## LANCER UN OBJET DU SAC (le geste du joueur) : une unité de la pile part, à la vitesse que donnent la Force et la masse.
static func lancer_objet(sim: Simulation, e: Dictionary, uid: String, cible: Vector2i, tick: int) -> bool:
	var it: Dictionary = sim.items.get(uid, {})
	if it.is_empty() or not (uid in e.sac or uid in e.equipement.values()) or not sim.grille.dans(cible) or cible == e.pos:
		return false
	var l: Dictionary = _cfg().get("lancer", {})
	var un: Dictionary = it.duplicate(true)
	un["quantite"] = 1
	var masse := maxf(0.05, sim.regles.poids_objet(un, sim.fonctionnalites))
	var force := float(e.get("corps", {}).get("stats", {}).get("force", 10))
	if masse > float(l.get("masse_max_par_force", 2.5)) * force:
		EventBus.emettre(&"journal", [&"journal.corps_trop_lourd", {"nom": it.get("name_key", "")}])
		return false
	var vitesse := float(l.get("vitesse_base", 6.0)) + float(l.get("vitesse_par_force", 0.5)) * force
	if masse > float(l.get("masse_legere", 1.0)):
		vitesse /= masse / float(l.get("masse_legere", 1.0))
	vitesse = clampf(vitesse, float(l.get("vitesse_min", 2.0)), float(l.get("vitesse_max", 25.0)))
	var portee := mini(int(l.get("portee_max", 12)), maxi(1, roundi(vitesse * float(l.get("portee_par_vitesse", 0.6)))))
	var vol := uid
	if int(it.get("quantite", 1)) > 1:
		un["uid"] = "%s_lance_%d" % [uid, sim.objets.size()]
		sim.items[str(un.uid)] = un
		sim.objets[str(un.uid)] = un
		it.quantite = int(it.quantite) - 1
		vol = str(un.uid)
	else:
		e.sac.erase(uid)
		for slot in e.equipement.keys():
			if str(e.equipement[slot]) == uid:
				e.equipement.erase(slot)
				break
	if lancer(sim, e, e.pos, cible, masse, vitesse, vol, portee).is_empty():
		return false
	sim._quitter_garde(e)
	e.compteur = tick + sim._ticks_avec_statuts(e, int(l.get("ticks_action", 600)))
	EventBus.emettre(&"journal", [&"journal.corps_lance", {"nom": e.name_key, "objet": it.get("name_key", "")}])
	return true
