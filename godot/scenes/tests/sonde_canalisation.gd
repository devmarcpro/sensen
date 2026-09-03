extends Node
## Sonde des armes magiques (designer 2026-09-03 : « la puissance du sort devrait etre affectee par
## l'arme a degat magique equipe, sceptre, baton magique etc »). Le reglage vit dans une fiche ; ce qui
## compte, c'est ce qu'un sort rend VRAIMENT selon ce qu'on tient. On lance le meme sort avec chaque
## arme et on lit la puissance du plan.
##   Godot --headless --path godot res://scenes/tests/sonde_canalisation.tscn

var soucis: Array = []


func _ready() -> void:
	var s := Simulation.new(0xCA11)
	s.charger_arene(GameData.catalogues.get("prototype_arenas", {}).keys()[0])
	var j := {}
	for x in s.vivants():
		if x.controle == "joueur":
			j = x
	# un sort de mana pur, sans contact : forme point, portee courte, noyau elementaire
	var seq: Array = ["point", "jet_court", "eclat"]
	# Un module doit etre CONNU pour entrer dans une capacite : le joueur d'arene ne connait que le kit
	# de sa classe. On les lui apprend, sinon la sonde mesure un refus au lieu d'une puissance.
	for m in seq:
		if not (str(m) in j.get("modules_connus", [])):
			j.modules_connus.append(str(m))
	if not s.composer_capacite(j, seq, "sonde"):
		print("SONDE CANALISATION : ECHEC — le sort d'essai ne se compose pas")
		get_tree().quit(1)
		return
	var idx: int = j.capacites.size() - 1
	var mesures: Array = []
	print("%-18s %8s %10s %s" % ["arme tenue", "mana", "puissance", "affinite"])
	var focus: Array[String] = []
	for fid in GameData.catalogues.functionalities.keys():
		var fd: Dictionary = GameData.catalogues.functionalities[fid]
		if str(fd.get("kind", "")) == "arme" and float(fd.get("affinite_sorts", {}).get("mana", 1.0)) > 1.0:
			focus.append(str(fid))
	focus.sort()
	for aid in ([""] + focus + ["epee", "masse"]):
		if not aid.is_empty():
			var it: Dictionary = s.generer_objet("craft_" + aid, 3, {}, "commun", 0)
			if it.is_empty():
				soucis.append("  %s ne se genere pas" % aid)
				continue
			j.sac.append(str(it.uid))
			j.equipement["main_principale"] = str(it.uid)
		else:
			j.equipement.erase("main_principale")
		var plan: Dictionary = s.plan_capacite(j, idx)
		var puissance := float(plan.get("mult", 1.0))
		var aff := float(plan.get("affinite_arme", 1.0))
		mesures.append({"arme": aid if not aid.is_empty() else "mains nues", "aff": aff, "mult": puissance})
		print("%-18s %8s %10.2f %.2f" % [aid if not aid.is_empty() else "mains nues", str(plan.get("monnaie", "?")), puissance, aff])
	# ce qui doit tenir : une arme magique canalise MIEUX que les mains nues, une arme lourde MOINS
	var par := {}
	for m in mesures:
		par[str(m.arme)] = float(m.aff)
	for magique in ["orbe", "sceptre", "baton_magique", "baguette"]:
		if par.has(magique) and par.has("mains nues") and float(par[magique]) <= float(par["mains nues"]):
			soucis.append("  %s ne canalise pas mieux que les mains nues (%.2f contre %.2f)" % [magique, float(par[magique]), float(par["mains nues"])])
	for lourde in ["epee", "masse"]:
		if par.has(lourde) and par.has("mains nues") and float(par[lourde]) >= float(par["mains nues"]):
			soucis.append("  %s canalise autant que les mains nues : l'arme physique doit coûter" % lourde)
	if par.has("orbe") and par.has("epee") and float(par.orbe) / maxf(0.01, float(par.epee)) < 1.5:
		soucis.append("  l'ecart orbe/epee est de %.2f : trop faible pour qu'on choisisse de canaliser" % (float(par.orbe) / maxf(0.01, float(par.epee))))
	# Chaque focus doit avoir UNE specificite que nul autre n'a (designer 2026-09-03). On compare les
	# trois axes qui les separent : la puissance brute, l'element favorise, et le cout en mana. Deux
	# focus identiques sur les trois sont le meme objet avec deux noms.
	print("")
	print("%-20s %6s %6s %5s %6s" % ["focus", "mana", "cout", "des", "mains"])
	var vus: Array[String] = []
	for fid in focus:
		var fd: Dictionary = GameData.catalogues.functionalities[fid]
		var sig := "%.2f|%.2f|%d|%s" % [float(fd.affinite_sorts.mana), float(fd.get("cout_mana_mult", 1.0)), int(fd.hands), str(fd.degats_des)]
		print("%-20s %6.2f %6.2f %5s %5d" % [fid, float(fd.affinite_sorts.mana), float(fd.get("cout_mana_mult", 1.0)), str(fd.degats_des), int(fd.hands)])
		if sig in vus:
			soucis.append("  %s ne se distingue d'aucun autre focus : meme puissance, meme cout, memes mains, memes des" % fid)
		vus.append(sig)
	if focus.size() < 4:
		soucis.append("  seulement %d focus : une famille d'une ou deux armes n'est pas une famille" % focus.size())
	# L'AUTRE MONNAIE. Les instruments (designer 2026-09-03 : « charisme ça pourrait être des
	# instruments ») sont aux sorts qui coutent de l'ENDURANCE — les cris, les charges, les
	# ralliements — ce que l'orbe et le sceptre sont aux sorts de mana. Dix-huit noyaux coutent de
	# l'endurance et n'avaient aucun focus : le mecanisme existait, il ne servait qu'a moitie.
	var seq_e: Array = ["point", "contact", "frappe"]
	for m in seq_e:
		if not (str(m) in j.get("modules_connus", [])):
			j.modules_connus.append(str(m))
	if s.composer_capacite(j, seq_e, "sonde_endurance"):
		var idx_e: int = j.capacites.size() - 1
		print("")
		print("%-20s %10s %10s" % ["arme tenue", "monnaie", "puissance"])
		var par_e := {}
		for aid in ["", "tambour", "luth", "cor", "epee", "orbe"]:
			if not aid.is_empty():
				var it2: Dictionary = s.generer_objet("craft_" + aid, 3, {}, "commun", 0)
				if it2.is_empty():
					continue
				j.sac.append(str(it2.uid))
				j.equipement["main_principale"] = str(it2.uid)
			else:
				j.equipement.erase("main_principale")
			var pe: Dictionary = s.plan_capacite(j, idx_e)
			var nom_e: String = aid if not aid.is_empty() else "mains nues"
			par_e[nom_e] = float(pe.get("affinite_arme", 1.0))
			print("%-20s %10s %10.2f" % [nom_e, str(pe.get("monnaie", "?")), float(pe.get("mult", 1.0))])
		for instr in ["tambour", "luth", "cor"]:
			if par_e.has(instr) and par_e.has("mains nues") and float(par_e[instr]) <= float(par_e["mains nues"]):
				soucis.append("  %s ne porte pas mieux un sort d'endurance que les mains nues" % instr)
		if par_e.has("tambour") and par_e.has("orbe") and float(par_e.tambour) <= float(par_e.orbe):
			soucis.append("  le tambour ne bat pas l'orbe sur un sort d'ENDURANCE : les deux familles ne se distinguent pas")
	for x in soucis:
		print(x)
	if not soucis.is_empty():
		print("SONDE CANALISATION : ECHEC — %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("sonde canalisation : ce qu'on tient change ce que le sort rend")
	get_tree().quit()
