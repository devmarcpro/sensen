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
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var s := Simulation.new(graine)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var jid: String = j.id
	var intentions := 0
	var ok := 0
	for k in pas_total:
		if k == pas_total / 2:   # à mi-course : le donjon
			s.charger_donjon("ruine", graine, 3, 1 + rng.randi_range(0, 4), s.entites[jid])
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
		var i := _intention(s, j, rng)
		intentions += 1
		if s.intention(jid, i):
			ok += 1
		s.pas(j.horloge)
		if k % 25 == 0:
			s.horloge_monde.avancer(rng.randi_range(10, 400))
		if k % 200 == 0:
			s._tiquer_differes("monde", s.horloge_monde.ticks)
	print("FUZZ : %d intentions, %d acceptées, tick %d, vivants %d" % [intentions, ok, s.horloge_monde.ticks, s.vivants().size()])
	if s.monde != null:
		s.monde.fermer()
	get_tree().quit(0)


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
	match rng.randi_range(0, 13):
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
