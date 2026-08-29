extends Node
## Fuzz headless (Vers la production — chasse aux bugs) : des intentions au hasard sur le joueur, au camp puis en donjon,
## en avançant les horloges. Aucun assert : on lit les SCRIPT ERROR de la sortie.
##   & Godot --headless --path godot res://scenes/tests/fuzz.tscn -- --pas 3000 --graine 7

var pas_total := 2000
var graine := 7


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--pas" and i + 1 < args.size():
			pas_total = int(args[i + 1])
		elif args[i] == "--graine" and i + 1 < args.size():
			graine = int(args[i + 1])
	var ia := "--ia" in args   # --ia : vingt bêtes de tous biomes autour du joueur, qui attend — les IA se débrouillent entre elles
	var bete := "--bete" in args   # --bete : le joueur incarne un cerf dès le départ (Changer de personnage : un corps sans mains)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var s := Simulation.new(graine)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var jid: String = j.id
	var intentions := 0
	var ok := 0
	# Territoire et compagnons (Défense et raids, Compagnons) : un claim rôle champs, un compagnon, un résident assigné.
	j["or"] = 500
	var cell_camp: Vector2i = s.monde.cellule_camp
	s.changer_role(cell_camp, "champs")
	var comp := s.ajouter("villageois", j.pos + Vector2i(0, 1), "ia")
	s._habiller_pnj(comp, GameData.entree("creatures", "villageois"))
	comp["maitre"] = jid
	comp.camp = j.camp
	if bete:
		var cerf := s.ajouter("cerf", j.pos + Vector2i(1, 1), "ia")
		cerf["maitre"] = jid
		cerf.camp = j.camp
		s.attente[jid] = true
		var incarne := s.intention(jid, {"type": "incarner", "pnj": cerf.id})
		print("FUZZ bete : incarnation %s" % str(incarne))
	var res := s.ajouter("villageois", j.pos + Vector2i(0, -1), "ia")
	s._habiller_pnj(res, GameData.entree("creatures", "villageois"))
	res.social.relations[jid] = 80
	if ia:
		var especes := ["loup", "sanglier", "lynx", "serpent_venimeux", "ours_brun", "bouquetin", "vautour", "crocodile", "nuee_moustiques", "essaim_abeilles", "cerf", "renne", "chameau", "morse", "loup_blanc", "ours_polaire", "scorpion", "aigle", "renard", "villageois"]
		for k2 in 20:
			var q: Vector2i = j.pos + Vector2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8))
			if s.grille.dans(q) and not s.grille.bloque_passage(q) and s.grille.occupant(q).is_empty():
				var b := s.ajouter(especes[k2 % especes.size()], q, "ia")
				if especes[k2 % especes.size()] == "villageois":
					s._habiller_pnj(b, GameData.entree("creatures", "villageois"))
	for k in pas_total:
		if k == pas_total / 4 and s.lieu == "camp":   # un raid réel au quart
			s._lancer_raid_reel(12.0, s.horloge_monde.ticks)
		if k % 700 == 650 and s.lieu == "camp":   # sauvegarder puis recharger (Sauvegarde) : le cycle le plus sensible aux états orphelins
			if s.sauvegarder():
				s.charger_sauvegarde()
		if k % 500 == 400 and s.lieu == "camp":   # un voyage vers une cellule voisine explorée d'office (Carte du monde), puis retour
			var ici: Vector2i = s.monde.cellule_de(s.entites[jid].pos)
			var vers: Vector2i = ici + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			if vers != ici and s.monde.surface.terre_a(vers):
				var nch: int = s.monde.taille / 32
				for cy in nch:
					for cx in nch:
						s.monde.explores[Vector2i(vers.x * nch + cx, vers.y * nch + cy)] = true
				s.voyager(s.entites[jid], vers)
		if k % 300 == 150 and s.lieu == "camp":   # la semaine du territoire
			s._semaine_territoire(s.entites[jid])
			s._recalculer_humeurs()
		if k == pas_total / 2:   # à mi-course : le donjon
			s.charger_donjon("ruine", graine, 3, 1 + rng.randi_range(0, 4), s.entites[jid])
		for x in s.entites.values():   # après une incarnation, le joueur est un autre corps
			if x.controle == "joueur" and x.vivant:
				jid = x.id
		if not s.entites.has(jid):
			break
		j = s.entites[jid]
		if not j.vivant:
			s.intention(jid, {"type": "respawn"})
			j = s.entites[jid]
		if rng.randf() < 0.03:   # une bête à côté, de temps en temps
			var q: Vector2i = j.pos + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			if s.grille.dans(q) and not s.grille.bloque_passage(q) and s.grille.occupant(q).is_empty():
				s.ajouter(["loup", "sanglier", "lynx", "serpent_venimeux"][rng.randi_range(0, 3)], q, "ia")
		s.attente[jid] = true
		var i := _intention(s, j, rng) if not ia else {"type": "attendre"}
		intentions += 1
		if s.intention(jid, i):
			ok += 1
		s.pas(j.horloge)
		if k % 25 == 0:
			s.horloge_monde.avancer(rng.randi_range(10, 400))
		if k % 200 == 0:
			s._tiquer_differes("monde", s.horloge_monde.ticks)
			print("FUZZ pas %d tick %d lieu %s vivants %d" % [k, s.horloge_monde.ticks, s.lieu, s.vivants().size()])
	var joueur_vivant := s.entites.has(jid) and bool(s.entites[jid].vivant)
	print("FUZZ : %d intentions, %d acceptées, tick %d, vivants %d, joueur %s, lieu %s" % [intentions, ok, s.horloge_monde.ticks, s.vivants().size(), "vivant" if joueur_vivant else "MORT", s.lieu])
	Monde.fermer_tous()
	get_tree().quit(0)


## Les ordres de compagnon ne passent pas par `intention` : on les appelle directement (Compagnons).
func s_ordres(s: Simulation, j: Dictionary, cid: String, rng: RandomNumberGenerator) -> void:
	var ordres := ["suivre", "attendre", "agressive", "defensive", "eviter", "retour", "repli"]
	s.ordonner(j, cid, ordres[rng.randi_range(0, ordres.size() - 1)])
	if rng.randf() < 0.3:
		s.designer_cible(j, cid)
	if rng.randf() < 0.3:
		s.suiveur_local(j, cid, rng.randf() < 0.5)
	if rng.randf() < 0.3 and not j.sac.is_empty():
		s.echanger(j, cid, str(j.sac[rng.randi_range(0, j.sac.size() - 1)]), "donner" if rng.randf() < 0.5 else "reprendre")


func _intention(s: Simulation, j: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
	var d: Vector2i = dirs[rng.randi_range(0, dirs.size() - 1)]
	var t: Vector2i = j.pos + d
	var ennemi := ""
	var dmin := 99
	for x in s.vivants():
		if x.camp != j.camp and x.camp != "civil":
			var dd := Grille.distance(j.pos, x.pos)
			if dd < dmin:
				dmin = dd
				ennemi = x.id
	var pnj := ""
	for x in s.vivants():
		if x.camp == "civil" and Grille.distance(j.pos, x.pos) <= 2:
			pnj = x.id
			break
	var compagnon := ""
	for x in s.vivants():
		if str(x.get("maitre", "")) == j.id and Grille.distance(j.pos, x.pos) <= 2:
			compagnon = x.id
			break
	match rng.randi_range(0, 33):
		28:
			return {"type": "cueillir", "vers": t}
		29:   # les systèmes de 2026-08-29 : rituels de donjon, portails, ordres de compagnon
			return {"type": "boire_source", "vers": t}
		30:
			return {"type": "rituel", "vers": t}
		31:
			return {"type": "poser_portail", "vers": t} if rng.randf() < 0.5 else {"type": "traverser"}
		32:   # les ordres et consignes de compagnon (gratuits, mais ils touchent l'état)
			if compagnon.is_empty():
				return {"type": "attendre"}
			s_ordres(s, j, compagnon, rng)
			return {"type": "attendre"}
		33:
			return {"type": "capacite", "index": rng.randi_range(0, maxi(0, j.get("capacites", []).size() - 1)), "cible": t}
		22:
			return {"type": "assigner", "pnj": pnj, "fonction": ["fermier", "garde", "mineur", "bucheron"][rng.randi_range(0, 3)]} if not pnj.is_empty() else {"type": "attendre"}
		23:
			return {"type": "incarner", "pnj": compagnon} if not compagnon.is_empty() else {"type": "attendre"}
		24:
			return {"type": "planter", "base": ["ble", "carotte", "sauge"][rng.randi_range(0, 2)]}
		25:
			return {"type": "entrainer", "pnj": pnj, "competence": "epee"} if not pnj.is_empty() else {"type": "attendre"}
		26:
			return {"type": "statut_habitat", "pnj": compagnon, "statut": "betail"} if not compagnon.is_empty() else {"type": "attendre"}
		27:
			return {"type": "conquerir", "vers": t}
		14:
			return {"type": "parler", "pnj": pnj} if not pnj.is_empty() else {"type": "attendre"}
		15:
			return {"type": "descendre"} if rng.randf() < 0.5 else {"type": "remonter"}
		16:
			return {"type": "fabriquer", "recette": ["fondre_lingot", "plat_ragout", "meuble_chaise", "distiller_dent"][rng.randi_range(0, 3)]}
		17:
			return {"type": "poser", "objet": str(j.sac[rng.randi_range(0, j.sac.size() - 1)]) if not j.sac.is_empty() else "", "vers": t}
		18:
			return {"type": "equiper", "objet": str(j.sac[rng.randi_range(0, j.sac.size() - 1)]) if not j.sac.is_empty() else ""}
		19:
			return {"type": "recruter", "pnj": pnj} if not pnj.is_empty() else {"type": "attendre"}
		20:
			return {"type": "acheter", "pnj": pnj, "objet": ""} if not pnj.is_empty() else {"type": "attendre"}
		21:
			return {"type": "lire", "objet": str(j.sac[rng.randi_range(0, j.sac.size() - 1)]) if not j.sac.is_empty() else ""}
		0, 1, 2:
			return {"type": "deplacer", "vers": t}
		3:
			return {"type": "attaquer", "cible": ennemi, "lourde": rng.randf() < 0.3} if not ennemi.is_empty() else {"type": "attendre"}
		4:
			return {"type": "garde"}
		5:
			return {"type": "capacite", "index": rng.randi_range(0, maxi(0, j.get("capacites", []).size() - 1)), "cible": j.pos + d * rng.randi_range(1, 3)}
		6:
			for uid in j.sac:
				if s.items.get(uid, {}).get("type", "") == "consommable":
					return {"type": "manger", "objet": uid}
			return {"type": "attendre"}
		7:
			return {"type": "creuser", "vers": t}
		8:
			return {"type": "terrasser", "vers": t, "sens": -1 if rng.randf() < 0.5 else 1}
		9:
			return {"type": "ramasser"}
		10:
			return {"type": "changer_arme", "item": str(j.ratelier[0]) if not j.ratelier.is_empty() else ""}
		11:
			return {"type": "arme_fantome", "element": ["feu", "eau", "bois", "metal", "terre"][rng.randi_range(0, 4)]}
		12:
			return {"type": "segment_prefere", "element": ["feu", "metal", ""][rng.randi_range(0, 2)]}
		_:
			return {"type": "attendre"}
