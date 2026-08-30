extends Node
var refus: Array[String] = []
var n := 0
## « Essaye tout » (demande du designer, 2026-08-30) : chaque forme avec chaque noyau, puis chaque autre module
## ajouté à un sort de base — assemblé ET exécuté sur une esplanade, sans limite. Le verdict : le nombre de
## plans refusés (erreurs d'assemblage) et le nombre d'erreurs de script imprimées par Godot (à compter dehors).
##   Godot --headless --path godot res://scenes/tests/test_modules.tscn

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
	var par_type := {}
	for mid in GameData.catalogues.modules.keys():
		var t := str(GameData.catalogues.modules[mid].module_type)
		if not par_type.has(t):
			par_type[t] = []
		par_type[t].append(str(mid))
	for t in par_type.keys():
		par_type[t].sort()
	var cible: Vector2i = j.pos + Vector2i(2, 0)
	var executer := func(mods: Array) -> void:   # les compteurs sont des membres : une lambda capture par valeur
		n += 1
		var pl := s.plan_sequence(j, mods)   # comme en jeu : l'arme tenue, la fonctionnalité, le nom
		pl["name_key"] = str(pl.get("noyau", {}).get("name_key", ""))
		if not pl.erreurs.is_empty():
			refus.append("%s → %s" % [str(mods), str(pl.erreurs)])
			return
		j.sante = 999
		j.mana = 999
		j.endurance = 999
		j.vivant = true
		s._executer_capacite(j, pl, cible)
		s.bombes.clear()
		for x in s.vivants():   # les invocations et relevés ne s'accumulent pas d'un essai à l'autre
			if x.id != j.id and x.has("maitre"):
				x.vivant = false
				s.grille.liberer(x.pos)
	for f in par_type.get("forme", []):
		for c in par_type.get("noyau", []):
			executer.call([f, c])
	for t in ["modificateur", "condition", "liaison"]:
		for m in par_type.get(t, []):
			for c in par_type.get("noyau", []):
				executer.call(["carre", c, m])
	for d in par_type.get("declencheur", []):
		for c in par_type.get("noyau", []):
			executer.call(["point", "etincelle", d, "carre", c])
	for c in par_type.get("noyau", []):   # le noyau répété et deux noyaux différents
		executer.call(["carre", c, c])
		executer.call(["point", c, "etincelle"])
	# 2. « vérifie que tout fonctionne » : chaque noyau, lancé seul sur un mannequin hostile, doit changer QUELQUE CHOSE
	# d'observable — les PV, le mana, l'endurance, la position, les statuts, le compteur du mannequin ou du lanceur,
	# une bombe, un affût, une zone, une entité de plus, une tuile (hauteur, contenu), une saisie.
	var muets: Array[String] = []
	var origine_j: Vector2i = j.pos
	for c in par_type.get("noyau", []):
		var md: Dictionary = GameData.catalogues.modules[c]
		var ef_c: Dictionary = md.get("effet", {})
		var effets_c: Array = md.get("effets", [])
		# Le mannequin qui convient au noyau : un allié blessé et affaibli pour les soins, purges et statuts d'allié ;
		# personne sur la tuile pour les invocations et convocations ; soi-même pour les déplacements « soi ».
		var vise_allie: bool = str(ef_c.get("cible", "")) == "allie" or "soin" in effets_c or "resurrection" in effets_c 			or str(ef_c.get("ressource", {}).get("cible", "")) == "allie" or ef_c.get("ressource", {}).has("releve_allie_pct") or ef_c.get("ressource", {}).has("transfert_pv") 			or ef_c.get("ressource", {}).has("segment_de_la_cible")
		var au_contact: bool = "saisie" in effets_c or str(ef_c.get("deplacement", {}).get("mode", "")) == "recul"   # ça se joue au corps à corps
		var journal_seulement: bool = ef_c.get("ressource", {}).has("estime")   # l'Estimation n'écrit que dans le journal
		var sur_soi: bool = str(ef_c.get("deplacement", {}).get("cible", "")) == "soi" or str(ef_c.get("cible", "")) == "soi"
		var sans_mannequin: bool = "invocation" in effets_c
		var loin: bool = str(ef_c.get("deplacement", {}).get("mode", "")) == "convocation"   # un allié à ramener de loin
		var forme_c := "soi" if sur_soi else "point"
		var pl := s.plan_sequence(j, [forme_c, c])
		pl["name_key"] = str(pl.get("noyau", {}).get("name_key", ""))
		if not pl.erreurs.is_empty():
			continue
		j.declencheurs_armes = []   # les déclencheurs armés par la première passe ne doivent pas partir ici
		for x in s.entites.values():   # tout le monde dehors, morts compris (un cadavre bloque une projection)
			if x.id != j.id:
				x.vivant = false
				s.grille.liberer(x.pos)
		s.grille.liberer(j.pos)   # le lanceur revient à sa place : un élan ou une permutation l'ont déplacé
		j.pos = origine_j
		s.grille.placer(j.id, j.pos)
		j.vivant = true
		s.bombes.clear()
		s.affuts.clear()
		s.zones.clear()
		j.orientation = Vector2i(1, 0)   # un recul a besoin d'un « derrière »
		if str(ef_c.get("deplacement", {}).get("mode", "")) == "retour_ancre":   # un retour a besoin d'une ancre posée, sur une tuile libre
			var pa: Vector2i = origine_j + Vector2i(0, -3)
			s.grille.contenu[s.grille.idx(pa)] = 0   # une tuile nue pour y revenir
			s.grille.hauteurs[s.grille.idx(pa)] = s.grille.h(origine_j)
			s.zones.append({"pos": pa, "type": "ancre", "fin": 999999, "source": j.id, "params": {}})
		if str(ef_c.get("deplacement", {}).get("mode", "")) == "traversee":   # une traversée a besoin d'un mur à traverser
			forme_c = "ligne"
			s.grille.poser_contenu(j.pos + Vector2i(1, 0), "mur_pierre") if s.grille.has_method("poser_contenu") else null
		for dx in range(-2, 3):   # la tuile visée et ses voisines redeviennent nues (une tourelle, une barrière y sont restées)
			for dy in range(-2, 3):
				var tn: Vector2i = cible + Vector2i(dx, dy)
				if s.grille.dans(tn) and tn != j.pos:
					s.grille.contenu[s.grille.idx(tn)] = 0
					s.grille.hauteurs[s.grille.idx(tn)] = s.grille.h(j.pos)
		var pos_m: Vector2i = cible + Vector2i(3, 3) if (sans_mannequin or loin) else (origine_j + Vector2i(1, 0) if au_contact else cible)
		var m: Dictionary = s.ajouter("loup", pos_m, "ia")
		m.declencheurs_armes = []
		if loin:
			m.camp = j.camp
		if ef_c.get("ressource", {}).has("desarme"):   # un désarmement veut une arme en main
			var dague := s.generer_objet("proto_dague", 1, {}, "commun", 0)
			m.sac.append(dague.uid)
			m.equipement["main_principale"] = dague.uid
			Etres.recalculer(m, s.items, s.affixes_defs, s.regles)
			m.stats_eff.force = 0   # le jet opposé (1d20 + Force) doit passer : le banc ne juge pas la chance
			j.stats_eff.force = 40
		m.sante_max = 60
		m.sante = 30 if vise_allie else 60   # blessé : un soin se voit
		if vise_allie:
			m.camp = j.camp
			s.appliquer_statut(m, "au_sol", 30, j.id)   # une purge a quelque chose à purger
		j.sante = 30
		j.sante_max = 40
		j.mana = 40
		j.endurance = 40
		j.compteur = 50
		m.compteur = 50   # un compteur à entamer : la célérité et le tempo se voient
		if "resurrection" in effets_c or ef_c.get("ressource", {}).has("releve_allie_pct") or str(ef_c.get("invocation", {}).get("mode", "")) == "releve":
			m.vivant = false   # un mort à relever
			s.grille.liberer(m.pos)
		var cible_e: Vector2i = m.pos if (loin or au_contact) else cible   # une convocation se vise sur l'allié, une saisie sur le voisin
		var avant := _photo(s, j, m, cible)
		s._executer_capacite(j, pl, cible_e)
		var apres := _photo(s, j, m, cible)
		if avant == apres and not journal_seulement:
			muets.append(c)
			var voisines := ""
			for q in [j.pos + Vector2i(-1, 0), cible + Vector2i(1, 0), cible + Vector2i(2, 0)]:
				voisines += " %s:occ=%s bloque=%s h=%d contenu=%d" % [str(q), str(s.grille.occupant(q)), str(s.grille.bloque_passage(q)), s.grille.h(q), s.grille.contenu[s.grille.idx(q)]]
			print("  détail ", c, " forme=", forme_c, " m=", m.pos, " vivant=", m.vivant, " camp=", m.camp, "/", j.camp, " j=", j.pos, " h_j=", s.grille.h(j.pos), " statuts_m=", m.get("statuts", []).size(), voisines)
	# 3. Les autres types : ajouté à un sort de base, chaque module doit changer le PLAN (ticks, prix, dés, portée, taille,
	# éléments, drapeaux, paramètres, conditions, liaisons, charge différée…). Un module qui n'y change rien est inerte.
	var inertes: Array[String] = []
	var base_plan := _empreinte(s.plan_sequence(j, ["carre", "etincelle"]))
	var base_forme := _empreinte(s.plan_sequence(j, ["point", "etincelle"]))
	for t in ["modificateur", "condition", "liaison", "declencheur", "forme"]:
		for m in par_type.get(t, []):
			var seq: Array = ["carre", "etincelle", m] if t != "forme" else [m, "etincelle"]
			if t == "declencheur":
				seq = ["point", "etincelle", m, "carre", "gel"]
			var e_m := _empreinte(s.plan_sequence(j, seq))
			if e_m == (base_plan if t != "forme" else base_forme) and not (t == "forme" and m == "point"):
				inertes.append(m)
	print("ESSAIS : %d plans assemblés et exécutés, %d refusés ; noyaux sans effet observable sur un mannequin : %d ; autres modules inertes dans le plan : %d" % [n, refus.size(), muets.size(), inertes.size()])
	for m in inertes:
		print("  inerte ", m)
	for c in muets:
		print("  muet ", c, " ", str(GameData.catalogues.modules[c].get("effets", [])), " ", str(GameData.catalogues.modules[c].get("effet", {})))
	for r in refus.slice(0, 40):
		print("  refus ", r)
	get_tree().quit()


## L'empreinte d'un plan : tout ce qu'un module peut y changer.
func _empreinte(pl: Dictionary) -> String:
	var cles := ["ticks", "ressource", "monnaie", "des", "des_bonus", "mult", "portee", "taille", "geometrie", "origine", "elements", "effets", "drapeaux", "parametres", "conditions", "liaisons", "charge_suivante", "charges_sup", "formes_sup", "fois", "ligne_de_vue", "avertissements"]
	var parts: Array[String] = []
	for k in cles:
		parts.append("%s=%s" % [k, str(pl.get(k, null))])
	return " ".join(parts)


## Tout ce qui peut changer quand un noyau agit, en une photo comparable.
func _photo(s: Simulation, j: Dictionary, m: Dictionary, cible: Vector2i) -> Array:
	var entites := 0
	for x in s.vivants():
		entites += 1
	var statuts_m: Array = m.get("statuts", []).map(func(st: Dictionary) -> String: return str(st.get("id", "")))
	var statuts_j: Array = j.get("statuts", []).map(func(st: Dictionary) -> String: return str(st.get("id", "")))
	return [int(m.sante), int(j.sante), int(j.mana), int(j.endurance), int(m.get("mana", 0)), int(m.get("endurance", 0)), m.pos, j.pos, statuts_m, statuts_j,
		int(m.compteur), int(j.compteur), s.bombes.size(), s.affuts.size(), s.zones.size(), entites, s.grille.h(cible), s.grille.contenu[s.grille.idx(cible)],
		str(j.get("saisie", "")), bool(m.vivant), int(j.get("sang", 0)), str(m.get("equipement", {}).get("main_principale", "")), int(j.get("or", 0)), s.grille.h(j.pos), str(j.get("chaine", {}))]
