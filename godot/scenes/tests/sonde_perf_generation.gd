extends Node
## Où passent les millisecondes d'une génération d'étage.
##
## Le budget É2 (« un étage en moins de 100 ms ») échoue une fois sur deux depuis toujours — vérifié
## dans un worktree sur le dépôt d'il y a trois heures : 132 et 239 ms, la même dispersion
## qu'aujourd'hui. Avant de demander au designer de desserrer un budget, il faut savoir CE QUI coûte.

func _ready() -> void:
	await get_tree().process_frame
	# on chauffe : la première génération paie le chargement des ressources et des scripts
	for c in 3:
		Simulation.new(60 + c).charger_donjon("ruine", 60 + c, 4, 1)
	var mesures: Array[float] = []
	for essai in 5:
		var s := Simulation.new(51)
		var t0 := Time.get_ticks_usec()
		s.charger_donjon("ruine", 51, 4, 1)
		mesures.append((Time.get_ticks_usec() - t0) / 1000.0)
	mesures.sort()
	print("etage complet : min %.0f · median %.0f · max %.0f ms" % [mesures[0], mesures[2], mesures[4]])

	# le contenu de l'étage, compté : c'est là qu'on saura si les coffres pèsent
	var s2 := Simulation.new(51)
	s2.charger_donjon("ruine", 51, 4, 1)
	print("etage : %d etres · %d objets" % [s2.vivants().size(), s2.items.size()])

	# un objet a affixes, seul, pour rapporter le total au detail
	var t1 := Time.get_ticks_usec()
	for k in 200:
		s2.generer_objet("proto_epee", 3)
	print("un objet genere : %.3f ms — 200 objets = %.0f ms" % [(Time.get_ticks_usec() - t1) / 1000.0 / 200.0, (Time.get_ticks_usec() - t1) / 1000.0])
	get_tree().quit()
