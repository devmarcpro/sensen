extends Node
## Sonde des stats de noyau (designer 2026-09-03 : « on va retravailler les modules pour que ça rentre
## dans notre nouveau système »). Deux questions, et la seconde est la seule qui compte :
##   1. chaque noyau declare-t-il une stat, et les six sont-elles servies ?
##   2. cette stat CHANGE-T-ELLE quelque chose ? Un champ qu'aucune formule ne lit est un ornement —
##      c'est exactement le piege des quatre stats de matiere decoratives trouve le meme jour.
##   Godot --headless --path godot res://scenes/tests/sonde_noyaux_stats.tscn

const STATS := ["force", "dexterite", "endurance", "volonte", "perception", "charisme"]

var soucis: Array = []


func _ready() -> void:
	var par := {}
	var sans: Array[String] = []
	for mid in GameData.catalogues.modules.keys():
		var m: Dictionary = GameData.catalogues.modules[mid]
		if str(m.get("module_type", "")) != "noyau":
			continue
		var st := str(m.get("stat", ""))
		if st.is_empty():
			sans.append(str(mid))
			continue
		par[st] = int(par.get(st, 0)) + 1
	var parts: Array[String] = []
	for st in STATS:
		parts.append("%s %d" % [st, int(par.get(st, 0))])
		if int(par.get(st, 0)) == 0:
			soucis.append("  aucun noyau ne monte sur « %s » : cette voie n'a pas de sorts" % st)
	print("noyaux par stat : %s" % ", ".join(parts))
	# Une voie qui n'a qu'un ou deux noyaux n'a pas de repertoire : on peut y investir sans jamais
	# avoir de quoi jouer. Le seuil est bas — trois — parce qu'il signale une voie VIDE, pas une voie
	# moins fournie qu'une autre : l'ecart entre les six est une question d'equilibrage, pas de sonde.
	for st in STATS:
		if int(par.get(st, 0)) > 0 and int(par.get(st, 0)) < 3:
			print("  voie maigre : « %s » n'a que %d noyau(x)" % [st, int(par.get(st, 0))])
	if not sans.is_empty():
		soucis.append("  %d noyaux sans stat declaree : %s" % [sans.size(), str(sans.slice(0, 6))])
	# LA question : la stat change-t-elle les degats ? On roule le meme noyau sur deux personnages
	# identiques sauf une stat, et on regarde si le resultat bouge.
	var s := Simulation.new(0x57A7)
	var regles = s.regles
	var des = s.des
	var haut := {"force": 40, "dexterite": 5, "endurance": 5, "volonte": 5, "perception": 5, "charisme": 5}
	var bas := {"force": 5, "dexterite": 5, "endurance": 5, "volonte": 5, "perception": 5, "charisme": 5}
	var d_force = regles.degats_sort(haut, {}, {}, {}, des, "1d1", 0, "force")
	var d_base = regles.degats_sort(bas, {}, {}, {}, des, "1d1", 0, "force")
	print("noyau de FORCE : force 40 -> %.1f degats · force 5 -> %.1f" % [float(d_force.bruts), float(d_base.bruts)])
	if float(d_force.bruts) <= float(d_base.bruts):
		soucis.append("  la stat du noyau ne change rien aux degats : le champ est decoratif")
	var d_vol = regles.degats_sort(haut, {}, {}, {}, des, "1d1", 0, "volonte")
	print("le MEME personnage, noyau de VOLONTE : %.1f (sa volonte vaut 5)" % float(d_vol.bruts))
	if float(d_vol.bruts) >= float(d_force.bruts):
		soucis.append("  un noyau de volonte profite autant de la force : les stats ne se distinguent pas")
	for x in soucis:
		print(x)
	if not soucis.is_empty():
		print("SONDE NOYAUX : ECHEC — %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("sonde noyaux : chaque voie a ses noyaux, et la stat du noyau porte vraiment le sort")
	get_tree().quit()
