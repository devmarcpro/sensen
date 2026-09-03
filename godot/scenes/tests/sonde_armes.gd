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
			# Les armes MAGIQUES se distinguent aussi par ce qu'elles font aux sorts : puissance canalisee,
			# element favorise, cout en mana. Sans ces trois axes, la sonde declarait un sceptre de jade
			# identique a un sceptre ordinaire — ils frappent pareil, mais l'un pousse le Bois de 40 %.
			var m_a := float(a.d.get("affinite_sorts", {}).get("mana", 1.0))
			var m_b := float(b.d.get("affinite_sorts", {}).get("mana", 1.0))
			var el_a := str((a.d.get("affinite_element", {}) as Dictionary).keys())
			var el_b := str((b.d.get("affinite_element", {}) as Dictionary).keys())
			var c_a := float(a.d.get("cout_mana_mult", 1.0))
			var c_b := float(b.d.get("cout_mana_mult", 1.0))
			var magie_identique: bool = absf(m_a - m_b) < 0.05 and el_a == el_b and absf(c_a - c_b) < 0.05
			if d_moy < 0.15 and d_vit < 0.15 and d_por < 1.0 and int(a.d.crit_range) == int(b.d.crit_range) and magie_identique:
				soucis.append("  %s et %s ne se distinguent sur aucun axe" % [a.id, b.id])
	for s in soucis:
		print(s)
	if not soucis.is_empty():
		print("SONDE ARMES : ECHEC — %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("sonde armes : %d armes, aucune n'en double une autre, chaque type de degats est porte" % armes.size())
	get_tree().quit()
