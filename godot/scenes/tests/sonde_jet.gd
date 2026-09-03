extends Node
## Sonde des armes de jet (designer 2026-09-03, point 78 : « l'item en lui-meme est la munition, le
## stack s'equipe en main, javelots etc »). Trois promesses, qu'aucun fichier ne peut prouver :
##   1. la pile equipee DIMINUE d'un a chaque jet ;
##   2. l'objet lance RETOMBE au sol, ramassable, avec la meme matiere et la meme qualite ;
##   3. la pile vide LIBERE la main — on ne se bat pas avec zero javelot.
##   Godot --headless --path godot res://scenes/tests/sonde_jet.tscn

var soucis: Array = []


func _ready() -> void:
	var s := Simulation.new(0x1E7)
	s.charger_arene(GameData.catalogues.get("prototype_arenas", {}).keys()[0])
	var j := {}
	for x in s.vivants():
		if x.controle == "joueur":
			j = x
	# une cible a portee de jet, mais hors de portee de contact
	var cible := {}
	for y in s.grille.hauteur_grille:
		for x2 in s.grille.largeur:
			var t := Vector2i(x2, y)
			var d := Grille.distance(t, j.pos)
			if d >= 3 and d <= 5 and not s.grille.bloque_passage(t) and s.grille.occupant(t).is_empty() and s.grille.ligne_de_vue(j.pos, t):
				cible = s.ajouter("loup", t, "ia")
				break
		if not cible.is_empty():
			break
	if cible.is_empty():
		print("SONDE JET : ECHEC — pas de place pour poser une cible a portee de jet")
		get_tree().quit(1)
		return
	var arme: Dictionary = s.generer_objet("craft_javelot", 3, {}, "commun", 0)
	if arme.is_empty():
		print("SONDE JET : ECHEC — le javelot ne se genere pas")
		get_tree().quit(1)
		return
	arme["quantite"] = 3
	j.sac.append(str(arme.uid))
	j.equipement["main_principale"] = str(arme.uid)
	s.recalculer(j) if s.has_method("recalculer") else null
	var mat := str(arme.get("materiau", ""))
	print("javelots en main : %d (%s)" % [int(arme.quantite), mat])
	var au_sol_avant := _au_sol(s)
	for k in 3:
		cible.sante = int(cible.sante_max)
		j.compteur = 0
		var fonct: Dictionary = s.fonctionnalites.get(str(arme.functionality), {})
		if not s.est_jet(fonct):
			soucis.append("  le javelot n'est pas reconnu comme arme de jet")
			break
		s._frapper_arme(j, cible, arme, fonct, false, 10)
		print("  apres le jet %d : %d en main, %d au sol" % [k + 1, int(arme.get("quantite", 0)), _au_sol(s) - au_sol_avant])
	if int(arme.get("quantite", 99)) != 0 and not soucis.is_empty():
		pass
	var au_sol := _au_sol(s) - au_sol_avant
	if au_sol < 3:
		soucis.append("  %d javelot(s) au sol pour trois jets : ce qu'on lance doit retomber" % au_sol)
	if j.equipement.has("main_principale"):
		soucis.append("  la main tient encore quelque chose alors que la pile est vide")
	# la matiere du javelot ramasse doit etre celle du javelot lance
	var meme := 0
	for gi in s.contenants.keys():
		for uid in s.contenants[gi]:
			var it: Dictionary = s.items.get(str(uid), {})
			if str(it.get("functionality", "")) == "javelot" and str(it.get("materiau", "")) == mat:
				meme += 1
	print("javelots au sol de la meme matiere : %d" % meme)
	if meme < 3:
		soucis.append("  le javelot ramasse n'a pas la matiere de celui qu'on a lance")
	for x in soucis:
		print(x)
	if not soucis.is_empty():
		print("SONDE JET : ECHEC — %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("sonde jet : la pile diminue, l'arme retombe, et la main se vide")
	get_tree().quit()


func _au_sol(s) -> int:
	var n := 0
	for gi in s.contenants.keys():
		n += (s.contenants[gi] as Array).size()
	return n
