extends Node
## Vérification des dix-neuf classes (designer 2026-08-31, point 48) : pour chacune, on crée le
## personnage tel qu'il naît, on assemble ses trois capacités et on les joue sur un mannequin.
## Une classe est bonne si sa signature est là, si tous ses plans sont valides et si chaque sort
## fait quelque chose (dégâts ou soins) — sauf une signature utilitaire, signalée « util ».
##   Godot --headless --path godot res://scenes/tests/verif_classes.tscn


func _ready() -> void:
	var s := Simulation.new(4242)
	s.charger_donjon("ruine", 4242, 9, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	for dx in range(-8, 9):
		for dy in range(-8, 9):
			var t: Vector2i = j.pos + Vector2i(dx, dy)
			if s.grille.dans(t) and t != j.pos:
				s.grille.contenu[s.grille.idx(t)] = 0
				s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	for x in s.entites.values():
		if x.id != j.id:
			x.vivant = false
			s.grille.liberer(x.pos)
	var origine: Vector2i = j.pos
	var cible: Vector2i = j.pos + Vector2i(2, 0)
	var prog := Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	var ids: Array = GameData.catalogues.classes.keys()
	ids.sort()
	var soucis := 0
	for cid: String in ids:
		var cl: Dictionary = GameData.entree("classes", cid)
		var fiche := Etres.creer_personnage("creature.aventurier.name", "humain", cid, {}, 1000, prog)
		var lignes: Array[String] = []
		var sig := str(cl.get("signature", ""))
		var a_sig := false
		for cap in fiche.get("capacites", []):
			var seq: Array = Array(cap.modules)
			if sig != "" and sig in seq:
				a_sig = true
			# le personnage connaît ses modules : on les crédite au mannequin de test
			for m in seq:
				s.crediter_module(j, str(m))
			var pl := s.plan_sequence(j, seq)
			if not pl.erreurs.is_empty():
				lignes.append("%s: PLAN INVALIDE (%s)" % [str(cap.id), str(pl.erreurs)])
				soucis += 1
				continue
			var off := _essai(s, j, seq, origine, cible, false)
			var soin := _essai(s, j, seq, origine, cible, true)
			var delta: int = maxi(off, soin)
			var etiquette := "%d PV/%d ticks" % [delta, int(pl.ticks)]
			if delta <= 0:
				etiquette = "util"
				if sig == "" or not (sig in seq):
					soucis += 1
					etiquette = "INERTE"
			lignes.append("%s %s" % [str(seq[seq.size() - 1]), etiquette])
		if sig != "" and not a_sig:
			lignes.append("SIGNATURE ABSENTE (%s)" % sig)
			soucis += 1
		print("CLASSE %-14s | %s" % [cid, " · ".join(PackedStringArray(lignes))])
	# CLASSE ET SOUS-CLASSE (designer 2026-09-03) : chaque sous-classe releve d'une classe mere, et
	# chaque mere porte une stat. Une sous-classe orpheline serait injouable a la creation ; une mere
	# sans sous-classe serait un nom vide dans le menu.
	var meres: Dictionary = GameData.config("classes_meres")
	var rangees := {}
	for k in meres.keys():
		if str(k).begins_with("_"):
			continue
		var sc: Array = meres[k].get("sous_classes", [])
		if sc.is_empty():
			print("  la classe « %s » n'a aucune sous-classe" % str(k))
			soucis += 1
		for x in sc:
			rangees[str(x)] = str(k)
	for cid in GameData.catalogues.classes.keys():
		if not rangees.has(str(cid)):
			print("  la sous-classe « %s » ne releve d'aucune classe" % str(cid))
			soucis += 1
	var par_mere: Array[String] = []
	for k in meres.keys():
		if not str(k).begins_with("_"):
			par_mere.append("%s(%s) %d" % [str(k), str(meres[k].get("stat", "?")), (meres[k].get("sous_classes", []) as Array).size()])
	par_mere.sort()
	print("classes : %s" % ", ".join(par_mere))
	print("VERIF : %d classes, %d soucis" % [ids.size(), soucis])
	get_tree().quit()


## Un essai : le mannequin est recréé, le plan exécuté, le delta de PV mesuré.
func _essai(s: Simulation, j: Dictionary, seq: Array, origine: Vector2i, cible: Vector2i, allie: bool) -> int:
	for x in s.entites.values():
		if x.id != j.id:
			x.vivant = false
			s.grille.liberer(x.pos)
	s.bombes.clear()
	s.affuts.clear()
	s.zones.clear()
	s.grille.liberer(j.pos)
	j.pos = origine
	s.grille.placer(j.id, j.pos)
	j.vivant = true
	j.sante = 999
	j.sante_max = 999
	j.mana = 999
	j.endurance = 999
	j.orientation = Vector2i(1, 0)
	j.declencheurs_armes = []
	if not s.grille.occupant(cible).is_empty():
		s.grille.liberer(cible)
	var m: Dictionary = s.ajouter("loup", cible, "ia")
	m.declencheurs_armes = []
	m.sante_max = 200
	m.sante = 100 if allie else 200
	if allie:
		m.camp = j.camp
	var pl := s.plan_sequence(j, seq)
	if not pl.erreurs.is_empty():
		return 0
	pl["name_key"] = str(pl.get("noyau", {}).get("name_key", ""))
	var avant: int = int(m.sante)
	s._executer_capacite(j, pl, cible)
	if not m.vivant:
		return avant if not allie else 0
	return (avant - int(m.sante)) if not allie else (int(m.sante) - avant)
