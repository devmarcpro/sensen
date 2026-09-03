extends Node
## Sonde du butin par NIVEAU DE DONJON (designer 2026-09-02 : « la rareté du loot ne se fait pas par
## étage mais par niveau du donjon »). Elle tire beaucoup d'objets à plusieurs niveaux et dit, pour
## chacun : quels paliers de matériau sortent, et ce que valent les objets assemblés. C'est la mesure
## qui permet de juger les chiffres de `paliers_materiaux` — sans elle on ne règle qu'à l'intuition.
##   Godot --headless --path godot res://scenes/tests/sonde_butin.tscn -- --tirages 400


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var tirages := 400
	var lister := 0
	for i in args.size():
		if args[i] == "--tirages" and i + 1 < args.size():
			tirages = int(args[i + 1])
		elif args[i] == "--lister" and i + 1 < args.size():
			lister = int(args[i + 1])
	var s := Simulation.new(4242)
	s.charger_camp()
	var niveaux: Array[int] = [1, 3, 6, 10, 15, 25]
	print("butin par niveau de donjon — %d tirages par niveau" % tirages)
	for niv in niveaux:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([4242, niv, "sonde"])
		var paliers := {}
		var pieces_hors := 0
		var pieces_tot := 0
		var objets_hors := 0
		var duretes: Array[float] = []
		var valeurs: Array[float] = []
		var assembles := 0
		for k in tirages:
			var base := str(s.loot._base_pour(rng, niv))
			var o := s.generer_objet(base, niv, {"sonde": true})
			if o.is_empty():
				continue
			var a_du_hors := false
			for slot in o.get("composants", {}).keys():
				var m := str(o.composants[slot].materiau)
				var pal := int(GameData.catalogues.materials.get(m, {}).get("palier", 1))
				paliers[pal] = int(paliers.get(pal, 0)) + 1
				pieces_tot += 1
				if bool(o.composants[slot].get("hors_attente", false)):
					pieces_hors += 1
					a_du_hors = true
			if a_du_hors:
				objets_hors += 1
			if not o.get("composants", {}).is_empty():
				assembles += 1
				duretes.append(float(o.get("stats", {}).get("durete", 0.0)))
				valeurs.append(float(o.get("stats", {}).get("valeur_base", 0.0)))
		var total := 0
		for p in paliers.values():
			total += int(p)
		var parts: Array[String] = []
		for p in [1, 2, 3, 4, 5]:
			parts.append("P%d %2d %%" % [p, roundi(100.0 * float(paliers.get(p, 0)) / maxf(1.0, float(total)))])
		print("  niveau %2d · %3d objets assemblés · %s · dureté moyenne %5.1f · valeur moyenne %5.1f · %2d %% des pieces hors de l'attendu, %2d %% des objets en portent une"
			% [niv, assembles, " ".join(parts), _moyenne(duretes), _moyenne(valeurs),
			roundi(100.0 * float(pieces_hors) / maxf(1.0, float(pieces_tot))), roundi(100.0 * float(objets_hors) / maxf(1.0, float(assembles)))])
	if lister > 0:
		_lister(s, niveaux, lister)
	s.monde.fermer()
	get_tree().quit()


## `--lister N` : N objets TIRES POUR DE VRAI a chaque niveau, avec leur nom, leur rarete, leur
## qualite et le detail de leur composition (designer 2026-09-03 : « genere une liste de butin »).
## Les moyennes disent si les chiffres sont bons ; une liste dit si le butin a du SENS — un plastron
## en eau de mer et une dague en craie se voient a l'oeil, pas dans un pourcentage.
func _lister(s, niveaux: Array[int], combien: int) -> void:
	for niv in niveaux:
		print("")
		print("=== niveau de donjon %d " % niv + "=".repeat(46))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([4242, niv, "liste"])
		var vus := 0
		var essais := 0
		while vus < combien and essais < combien * 40:
			essais += 1
			var base := str(s.loot._base_pour(rng, niv))
			var o: Dictionary = s.generer_objet(base, niv, {"sonde": true})
			if o.is_empty():
				continue
			vus += 1
			print("  %s" % _nom(s, o))
			var comps: Dictionary = o.get("composants", {})
			if not comps.is_empty():
				var det: Array[String] = []
				for slot in comps.keys():
					var c: Dictionary = comps[slot]
					var m: Dictionary = GameData.catalogues.materials.get(str(c.materiau), {})
					det.append("%s : %s en %s (P%d%s, q %.2f)%s" % [tr("slotc." + str(slot)), tr(GameData.entree("components", str(c.composant)).name_key),
						tr(m.get("name_key", str(c.materiau))), int(m.get("palier", 1)),
						"/" + str(m.get("sous_categorie", m.get("category", ""))), float(c.qualite),
						" <- HORS ATTENDU" if bool(c.get("hors_attente", false)) else ""])
				print("      %s" % " · ".join(det))
			var st: Dictionary = o.get("stats", {})
			if not st.is_empty():
				print("      durete %.0f · densite %.0f · valeur %.0f · element %s" % [float(st.get("durete", 0)), float(st.get("densite", 0)), float(st.get("valeur_base", 0)), tr("element." + str(o.get("element", "")))])


## Le nom lisible d'un objet, tel qu'un joueur le verrait. La composition du nom vit dans la scene de
## jeu (`main.nom_objet`), que le mode --headless ne charge pas : on la refait ici, en plus court.
func _nom(s, o: Dictionary) -> String:
	var n: Dictionary = s.nom_objet(str(o.uid))
	# Un objet NON IDENTIFIE n'a pas de nom mais une apparence — « Gemme trouble », « Fiole poisseuse » —
	# et le gabarit la reclame en parametre. Sans lui, la liste affichait « Gemme {apparence} ».
	var nom := tr(str(n.base)).format(n.get("params", {}))
	if n.has("materiau") and not str(n.materiau).is_empty():
		nom += " en " + tr(str(n.materiau))
		if n.has("espece") and not str(n.espece).is_empty():
			nom += " de " + tr(str(n.espece))
	if not str(n.get("affixe", "")).is_empty():
		# Le nom d'affixe porte des parametres — « {base} de {competence} (+{n}) » — que le jeu remplit
		# dans `main.nom_objet`. Sans eux, la liste affichait les accolades nues et donnait l'impression
		# d'un defaut de traduction qui n'existait pas. On refait ici ce que la scene de jeu fait.
		var pa: Dictionary = (n.get("params", {}) as Dictionary).duplicate()
		for k in pa.keys():
			if k == "element":
				pa["epithete"] = tr("epithete." + str(pa[k]))
				pa[k] = tr("element." + str(pa[k]))
		pa["base"] = nom
		nom = tr("affixe." + str(n.affixe) + ".nom").format(pa)
	var r := str(n.get("rarete", "commun"))
	nom += "  [%s" % tr("rarete." + r)
	if o.has("qualite"):
		nom += " · q %.2f" % float(o.qualite)
	return nom + "]"


func _moyenne(v: Array[float]) -> float:
	if v.is_empty():
		return 0.0
	var t := 0.0
	for x in v:
		t += x
	return t / float(v.size())
