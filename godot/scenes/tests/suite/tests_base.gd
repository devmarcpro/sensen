class_name TestsBase
extends RefCounted
## La base des fichiers de la suite (découpée le 2026-09-06 : `test_combat.gd` reste le lanceur, chaque
## `suite/tests_<domaine>.gd` étend cette classe). Les aides communes vivent ici ; `verifier` compte au lanceur.

static var lanceur: Node = null   # test_combat.gd, qui compte les échecs et lit `--seul`


func verifier(cond: bool, nom: String) -> void:
	lanceur.verifier(cond, nom)


## Un test qui instancie une scène (le tutoriel) la pose sous le lanceur, un nœud de l'arbre.
func add_child(n: Node) -> void:
	lanceur.add_child(n)


func nouvelle_sim(arene: String) -> Simulation:
	var s := Simulation.new(42)
	s.charger_arene(arene)
	return s


func joueur_de(s: Simulation) -> Dictionary:
	for e in s.vivants():
		if e.controle == "joueur":
			return e
	return {}


# ---------------------------------------------------------------- Hauteur de terrain ±10

## Une capacité de test : les modules sont connus ET chargés (Grimoires et manuels : un lancer consomme
## une charge par module). Sans ça, tout sort composé à la main serait refusé faute de munitions.
func _capacite_test(s: Simulation, j: Dictionary, id: String, mods: Array) -> void:
	# La portée est un module depuis le 2026-09-01 : sans lui un sort ne porte qu'au contact. Les tests
	# d'effet ne parlent pas de distance — on leur donne un jet long, sauf s'ils choisissent leur portée.
	var a_portee := false
	for m0 in mods:
		if str(GameData.catalogues.modules.get(str(m0), {}).get("module_type", "")) == "portee":
			a_portee = true
	if not a_portee:
		mods = mods.duplicate()
		mods.insert(mini(1, mods.size()), "jet_court")   # juste apres la forme : la charge differee d'un declencheur garde sa propre portee
	for m in mods:
		s.crediter_module(j, str(m), 99)
	j.capacites.append({"id": id, "name_key": "capacite.etincelle.name", "modules": mods})


## Un monde de test stable (2026-09-01) : carré et centré, quelle que soit la forme du monde livré.
## Les tests de contenu vérifient des règles — villages, cultures, élevage — pas la géographie du jour.
static func _planete_test() -> Dictionary:
	var p := GameData.config("planete").duplicate(true)
	p["monde_ratio"] = 1.0            # carré, comme avant le point 49
	p["cellule_depart"] = [512, 512]  # et centré sur la cellule historique du camp
	p["tectonique"] = (p["tectonique"] as Dictionary).duplicate(true)
	p["tectonique"]["ocean_bord"] = 0.0   # sans la ceinture d'océan : la géographie du centre ne bouge plus
	return p


## Ce que verser() doit rendre : l'XP effective (× potentiel / 100) s'ajoute au reste, consomme les seuils de la courbe
## un à un, et chaque niveau retire potentiel_cout_base + niveau / potentiel_cout_div de potentiel (plancher : la base).
func _consommer_xp(prog: Progression, niveau: int, reste: float, xp: float, potentiel: int, base: int) -> Dictionary:
	var r: Dictionary = GameData.config("combat_rules").progression
	var pot := potentiel
	var n := niveau
	var x := reste + xp * float(potentiel) / 100.0
	while x >= float(prog.xp_next(n)):
		x -= float(prog.xp_next(n))
		n += 1
		pot = maxi(base, pot - (int(r.potentiel_cout_base) + n / int(r.potentiel_cout_div)))
	return {"niveau": n, "reste": x, "potentiel": pot if n > niveau else potentiel}


## La première cellule d'eau autour d'un point — le voyage doit continuer à la refuser.
func _cellule_eau(s, autour: Vector2i) -> Vector2i:
	for r in range(1, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c: Vector2i = autour + Vector2i(dx, dy)
				if not s.monde.surface.terre_a(c):
					return c
	return autour + Vector2i(1000, 1000)
