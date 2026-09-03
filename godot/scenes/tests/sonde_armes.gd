extends Node
## Sonde des armes (designer 2026-09-03, point 79 : « rajoute des types d'armes mais fais en sorte que
## toutes se differencie — type de degat, vitesse d'attaque, jet, etc »). Elle tabule le catalogue et
## cherche les DOUBLONS : deux armes qui se ressemblent sur tous les axes a la fois ne sont pas deux
## armes, c'est la meme avec deux noms. Elle dit aussi la couverture par type de degats, parce qu'un
## type qui n'est porte que par une arme rend la matrice d'armure decorative.
##   Godot --headless --path godot res://scenes/tests/sonde_armes.tscn

const AXES := ["degats_moyens", "vitesse_base", "portee", "type_degats", "hands", "crit_range"]

var soucis: Array = []


func _ready() -> void:
	var armes: Array = []
	for fid in GameData.catalogues.functionalities.keys():
		var d: Dictionary = GameData.catalogues.functionalities[fid]
		if str(d.get("kind", "")) != "arme" or str(fid) == "_template":
			continue
		armes.append({"id": str(fid), "d": d, "moy": float(Des.fourchette(str(d.get("degats_des", "1d1"))).x + Des.fourchette(str(d.get("degats_des", "1d1"))).y) * 0.5})
	# `vitesse_base` DIVISE le cout en ticks (ticks = actions.attaque_base / vitesse), elle ne le
	# multiplie pas. J'avais ecrit `moyenne x vitesse` et appele ca « degats par tick » : le classement
	# entre armes restait juste, mais la VALEUR etait dix fois trop grande, et je m'en suis servi pour
	# comparer les armes aux sorts. La comparaison etait fausse dans le mauvais sens (2026-09-03).
	var base_t := float(GameData.config("combat_rules").actions.attaque_base)
	armes.sort_custom(func(a, b): return float(a.moy) / maxf(1.0, roundi(base_t / float(a.d.vitesse_base))) > float(b.moy) / maxf(1.0, roundi(base_t / float(b.d.vitesse_base))))
	print("%-18s %-6s %5s %5s %6s %7s %-11s %s %s" % ["arme", "des", "moy", "vit", "PV/tick", "portee", "type", "m", "crit"])
	var par_type := {}
	for a in armes:
		var d: Dictionary = a.d
		var ticks := maxf(1.0, roundi(base_t / float(d.vitesse_base)))
		var dt := float(a.moy) / ticks
		par_type[str(d.type_degats)] = int(par_type.get(str(d.type_degats), 0)) + 1
		print("%-18s %-6s %5.1f %5.2f %6.2f %7s %-11s %d %d" % [a.id, str(d.degats_des), float(a.moy), float(d.vitesse_base), dt,
			"%.0f/%d" % [float(d.portee), int(d.portee_min)], str(d.type_degats), int(d.hands), int(d.crit_range)])
	print("couverture par type de degats : %s" % str(par_type))
	for t in ["tranchant", "perforant", "contondant"]:
		if int(par_type.get(t, 0)) < 2:
			soucis.append("  le type « %s » n'est porte que par %d arme(s) : la matrice d'armure devient decorative" % [t, int(par_type.get(t, 0))])
	# Deux armes qui se ressemblent sur TOUS les axes sont la meme arme avec deux noms.
	for i in armes.size():
		for k in range(i + 1, armes.size()):
			var a: Dictionary = armes[i]
			var b: Dictionary = armes[k]
			if str(a.d.type_degats) != str(b.d.type_degats) or int(a.d.hands) != int(b.d.hands):
				continue
			var d_moy: float = absf(float(a.moy) - float(b.moy)) / maxf(1.0, float(a.moy))
			var d_vit: float = absf(float(a.d.vitesse_base) - float(b.d.vitesse_base)) / maxf(0.1, float(a.d.vitesse_base))
			var d_por: float = absf(float(a.d.portee) - float(b.d.portee))
			# Les armes MAGIQUES se distinguent aussi par ce qu'elles font aux sorts : puissance canalisee
			# et cout en mana. Sans ces axes, deux focus qui frappent pareil passeraient pour identiques.
			var m_a := float(a.d.get("affinite_sorts", {}).get("mana", 1.0))
			var m_b := float(b.d.get("affinite_sorts", {}).get("mana", 1.0))
			var c_a := float(a.d.get("cout_mana_mult", 1.0))
			var c_b := float(b.d.get("cout_mana_mult", 1.0))
			var magie_identique: bool = absf(m_a - m_b) < 0.05 and absf(c_a - c_b) < 0.05
			if d_moy < 0.15 and d_vit < 0.15 and d_por < 1.0 and int(a.d.crit_range) == int(b.d.crit_range) and magie_identique:
				soucis.append("  %s et %s ne se distinguent sur aucun axe" % [a.id, b.id])
	# Une arme ne doit pas etre la meilleure CONTRE TOUT. La matrice d'armure est faite pour qu'un type
	# de degats brille ici et souffre la ; une arme qui domine les cinq constructions annule la matrice
	# et rend le choix d'arme inutile. C'etait le cas de la masse jusqu'au 2026-09-03 : 60 a 80 %
	# au-dessus de tout le reste contre mailles, ecailles et plaque, sans aucune faiblesse.
	var matrice: Dictionary = GameData.config("combat_rules").armure.matrice
	var constructions: Array = matrice.keys()
	var podium := {}
	for c in constructions:
		var classement: Array = []
		for a2 in armes:
			var d2: Dictionary = a2.d
			var t2 := maxf(1.0, roundi(base_t / float(d2.vitesse_base)))
			var f2 := float((matrice[c] as Dictionary).get(str(d2.type_degats), 1.0))
			classement.append({"id": str(a2.id), "v": float(a2.moy) / t2 / f2})
		classement.sort_custom(func(x, y): return float(x.v) > float(y.v))
		for r in mini(2, classement.size()):
			podium[str(classement[r].id)] = int(podium.get(str(classement[r].id), 0)) + 1
	for aid in podium.keys():
		# Le seuil est a QUATRE constructions sur cinq, pas cinq : la masse d'avant le 2026-09-03 etait
		# premiere ou deuxieme contre quatre des cinq — seul le matelasse lui echappait — et c'etait deja
		# une arme sans contrepartie. Verifie en remettant ses 3d8 : la sonde la nomme.
		if int(podium[aid]) >= constructions.size() - 1:
			soucis.append("  %s est dans les deux meilleures contre %d des %d constructions d'armure : la matrice ne sert plus a rien" % [aid, int(podium[aid]), constructions.size()])
	var tete: Array = []
	for aid in podium.keys():
		tete.append("%s %d/%d" % [aid, int(podium[aid]), constructions.size()])
	tete.sort()
	print("armes sur le podium par construction d'armure : %s" % ", ".join(tete))
	for s in soucis:
		print(s)
	if not soucis.is_empty():
		print("SONDE ARMES : ECHEC — %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("sonde armes : %d armes, aucune n'en double une autre, chaque type de degats est porte" % armes.size())
	get_tree().quit()
