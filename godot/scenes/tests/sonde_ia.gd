extends Node
## Sonde de l'IA (designer 2026-09-03, point 77 : « rajoute du roam de l'aggro etc »). Elle mesure les
## trois promesses qu'on ne peut pas lire dans les fichiers :
##   1. le ROAM mene quelque part — un etre qui erre s'eloigne vraiment de son point de depart ;
##   2. l'AGGRO designe qui a frappe, meme si un autre ennemi est plus proche ;
##   3. l'ALERTE reveille les voisins, et le temps fait tout retomber.
##   Godot --headless --path godot res://scenes/tests/sonde_ia.tscn

var soucis: Array = []


func _ready() -> void:
	_roam()
	_aggro()
	for s in soucis:
		print(s)
	if not soucis.is_empty():
		print("SONDE IA : ECHEC — %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("sonde ia : on erre vers un but, on vise qui frappe, et la meute se reveille")
	get_tree().quit()


## Cent tours de decision d'errance : de combien de tuiles un etre s'eloigne-t-il de son ancre ?
## Une marche au hasard donne ~10 en moyenne (racine de 100) ; aller vers un but doit faire beaucoup mieux.
func _roam() -> void:
	var s := Simulation.new(0x1A1A)
	s.charger_arene(GameData.catalogues.get("prototype_arenas", {}).keys()[0])
	# On pose nos propres betes plutot que de compter sur le contenu de l'arene : la premiere par ordre
	# alphabetique peut n'en contenir aucune, et la sonde echouait alors pour la mauvaise raison.
	var betes: Array = []
	for y in s.grille.hauteur_grille:
		for x2 in s.grille.largeur:
			if betes.size() >= 8:
				break
			var t := Vector2i(x2, y)
			if not s.grille.bloque_passage(t) and s.grille.occupant(t).is_empty():
				betes.append(s.ajouter("cerf" if GameData.catalogues.creatures.has("cerf") else "loup", t, "ia"))
	if betes.is_empty():
		soucis.append("  aucune place libre dans l'arene : le roam n'est pas mesurable")
		return
	var loins: Array[float] = []
	for b in betes:
		b["aggro"] = {}
		b.cible = ""
		var depart: Vector2i = b.pos
		b.ancre = depart
		for k in 100:
			s._ia_errer(b, k * 10)
		loins.append(float(Grille.distance(b.pos, depart)))
	var moy := 0.0
	var maxi_l := 0.0
	for v in loins:
		moy += v
		maxi_l = maxf(maxi_l, v)
	moy /= float(loins.size())
	print("roam : %d etres, 100 tours d'errance — eloignement moyen %.1f tuiles, le plus loin %.0f" % [loins.size(), moy, maxi_l])
	if moy < 4.0:
		soucis.append("  le roam ne mene nulle part : %.1f tuiles en moyenne apres cent tours" % moy)


## Deux ennemis : l'un colle a la bete, l'autre la frappe de loin. Qui vise-t-elle ?
func _aggro() -> void:
	var s := Simulation.new(0x1A2B)
	s.charger_arene(GameData.catalogues.get("prototype_arenas", {}).keys()[0])
	var j := {}
	for x in s.vivants():
		if x.controle == "joueur":
			j = x
	var libres: Array[Vector2i] = []
	for y in s.grille.hauteur_grille:
		for x2 in s.grille.largeur:
			var t := Vector2i(x2, y)
			if not s.grille.bloque_passage(t) and s.grille.occupant(t).is_empty() and Grille.distance(t, j.pos) > 2:
				libres.append(t)
	if libres.size() < 3:
		soucis.append("  pas assez de place dans l'arene pour poser la scene d'aggro")
		return
	var loup: Dictionary = s.ajouter("loup", libres[0], "ia")
	var proche: Dictionary = s.ajouter("loup", libres[1], "ia")
	proche.camp = "joueur"          # un ennemi du loup, tout pres
	j.pos = libres[2]
	s.grille.placer(j.id, j.pos)
	# le joueur frappe le loup depuis le loin : c'est LUI que le loup doit vouloir
	s._monter_aggro(loup, str(j.id), 40.0, true)
	var vise: Dictionary = s._cible_par_aggro(loup)
	print("aggro : le loup vise %s (frappe par le joueur, un autre ennemi a %d tuiles)" % [str(vise.get("id", "personne")), Grille.distance(loup.pos, proche.pos)])
	if str(vise.get("id", "")) != str(j.id):
		soucis.append("  le loup ne vise pas celui qui l'a frappe")
	# l'alerte : un voisin du meme camp a-t-il appris le nom du coupable ?
	var voisin: Dictionary = s.ajouter("loup", libres[1] + Vector2i(1, 0) if s.grille.occupant(libres[1] + Vector2i(1, 0)).is_empty() else libres[0] + Vector2i(0, 1), "ia")
	s._monter_aggro(loup, str(j.id), 20.0, true)
	var su := float((voisin.get("aggro", {}) as Dictionary).get(str(j.id), 0.0))
	print("alerte : un loup voisin a %.0f d'aggro sur le joueur sans avoir ete touche" % su)
	if su <= 0.0:
		soucis.append("  l'alerte ne reveille personne : la meute regarde son camarade se faire tuer")
	# et le temps efface
	var avant := float((loup.get("aggro", {}) as Dictionary).get(str(j.id), 0.0))
	for k in 2000:
		s._decroitre_aggro(loup)
	var apres := float((loup.get("aggro", {}) as Dictionary).get(str(j.id), 0.0))
	print("oubli : %.0f d'aggro, puis %.0f apres deux mille tours" % [avant, apres])
	if apres >= avant:
		soucis.append("  l'aggro ne retombe jamais : la poursuite est eternelle")
