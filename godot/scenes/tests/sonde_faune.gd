extends Node
## Sonde de la faune (designer 2026-09-02 : « rajoute les animaux sauvages pacifiques dans la nature,
## rajoute des animaux, insectes etc »). Elle répond à deux questions qu'on ne peut pas lire dans les
## fichiers : est-ce qu'une espèce ajoutée s'INSTANCIE vraiment (actions, squelette, éléments), et
## qu'est-ce qu'un joueur RENCONTRE réellement dans un biome — c'est-à-dire la part de paisible dans
## le tirage pondéré de `_tiquer_faune`, pas dans la liste des fiches.
##   Godot --headless --path godot res://scenes/tests/sonde_faune.tscn

var soucis: Array = []


func _ready() -> void:
	var sim := Simulation.new(0x51E5)
	sim.charger_arene(GameData.catalogues.get("prototype_arenas", {}).keys()[0])
	# 1. chaque bête s'instancie : une action inconnue ou un squelette absent se voit ici, pas en jeu.
	var n := 0
	for cid in GameData.catalogues.creatures.keys():
		var d: Dictionary = GameData.catalogues.creatures[cid]
		if not ("bete" in d.get("tags", [])):
			continue
		n += 1
		for a in d.get("actions", []):
			if not GameData.catalogues.get("creature_actions", {}).has(str(a)):
				soucis.append("  %s : action inconnue « %s »" % [cid, a])
		if str(d.get("skeleton_template", "")).is_empty():
			soucis.append("  %s : pas de squelette" % cid)
		for p in (d.get("depouille", []) as Array) + (d.get("drops_chasse", []) as Array):
			if not GameData.catalogues.items.has(str(p)):
				soucis.append("  %s : dépouille inconnue « %s »" % [cid, p])
	print("%d bêtes au catalogue" % n)
	# 2. ce qu'on rencontre : la part PAISIBLE du tirage pondéré, biome par biome, jour et nuit.
	for bid in GameData.catalogues.biomes.keys():
		var b: Dictionary = GameData.catalogues.biomes[bid]
		if bid == "_template":
			continue
		for quand in ["faune", "faune_nuit"]:
			var pool: Array = b.get(quand, [])
			if quand == "faune_nuit":
				pool = (b.get("faune", []) as Array) + pool
			if pool.is_empty():
				continue
			var total := 0.0
			var paisible := 0.0
			for f in pool:
				var d: Dictionary = GameData.catalogues.creatures.get(str(f.id), {})
				total += float(f.density)
				if "paisible" in d.get("tags", []) or d.get("ai_profile", "") in ["proie", "fuyard"]:
					paisible += float(f.density)
			print("  %-19s %-11s %3d %% paisible sur %d espèces" % [bid, "jour" if quand == "faune" else "nuit", roundi(100.0 * paisible / maxf(0.001, total)), pool.size()])
			if paisible / maxf(0.001, total) < 0.15 and bid != "marecage_corrompu" and bid != "desert_de_cendres":
				soucis.append("  %s (%s) : %d %% de paisible — le biome est un couloir de combat" % [bid, quand, roundi(100.0 * paisible / maxf(0.001, total))])
	# 3. et sur pied : on fait tourner un vrai camp et on regarde CE QUI APPARAIT. Les pools sont une
	# intention ; le tirage a ses propres filtres (anneau hors de vue, terrain praticable, budget),
	# et une espece peut n'apparaitre jamais sans qu'aucun fichier ne soit fautif.
	var sim2 := Simulation.new(0x51E5)
	sim2.graine_monde = 4242
	sim2.charger_camp()
	var vus := {}
	for k in 4000:
		sim2._tiquer_faune(k * 3)
		for x in sim2.vivants():
			if x.get("spawn_faune", false):
				vus[str(x.def)] = int(vus.get(str(x.def), 0)) + 1
	var noms: Array = vus.keys()
	noms.sort()
	var paisibles := 0
	for cid in noms:
		if "paisible" in GameData.catalogues.creatures.get(cid, {}).get("tags", []):
			paisibles += 1
	print("sur pied, en 12000 ticks de camp : %d especes vues, dont %d paisibles" % [noms.size(), paisibles])
	print("  ", ", ".join(noms))
	if paisibles == 0:
		soucis.append("  aucune bete paisible n'apparait vraiment : les pools ne suffisent pas")
	for s in soucis:
		print(s)
	if not soucis.is_empty():
		print("SONDE FAUNE : ECHEC — %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("sonde faune : chaque bête tient debout, et aucun biome n'est un couloir de combat")
	get_tree().quit()
