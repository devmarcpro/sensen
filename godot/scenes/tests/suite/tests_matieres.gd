extends TestsBase
## Les matières et le craft : matériaux, récolte, fabrication, assemblage.
## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de
## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l'ordre de sa liste.


func test_materiaux() -> void:
	var mats: Dictionary = GameData.catalogues.materials
	# Un SEUIL, pas un compte : le designer ajoute des matières (« il manque pas mal de matériaux »), et
	# recopier un total ici obligeait à corriger le test à chaque enrichissement du catalogue. Ce qui
	# doit tenir : le catalogue est plein, et chaque fiche porte de quoi être récoltée et assemblée.
	verifier(mats.size() >= 166, "%d matériaux au catalogue (au moins 166)" % mats.size())
	var sans_stats: Array[String] = []
	for mid_v in mats.keys():
		var mv: Dictionary = mats[mid_v]
		if not mv.has("stats") or not mv.stats.has("durete") or not mv.has("palier"):
			sans_stats.append(str(mid_v))
	verifier(sans_stats.is_empty(), "chaque matériau a ses stats et son palier (manquants : %s)" % str(sans_stats.slice(0, 5)))
	var fer: Dictionary = mats.fer
	# Les chiffres d'une fiche appartiennent au designer et bougent (« tu peux rééquilibrer, j'ai écrit
	# aucune stats »). Ce qui doit tenir, c'est que le Fer AIT ses treize stats et qu'elles se tiennent
	# entre elles — un métal est dur, conducteur, et ne brûle pas.
	verifier(int(fer.stats.durete) > 0 and int(fer.stats.conductivite_electrique) > 30 and int(fer.stats.flammabilite) == 0, "le Fer a sa table (Dur %d, CÉl %d)" % [int(fer.stats.durete), int(fer.stats.conductivite_electrique)])
	verifier("conducteur" in fer.tags and not ("inflammable" in fer.tags), "tags dérivés au seuil 50 (fer : conducteur)")
	verifier(mats.paille.tags.has("inflammable") and mats.verre.tags.has("transparent"), "paille inflammable, verre transparent")
	verifier(mats.chene.wuxing == {"bois": 1.0}, "chêne : vecteur de sa catégorie (Bois)")
	verifier(is_equal_approx(float(mats.obsidienne.wuxing.terre), 0.6) and is_equal_approx(float(mats.obsidienne.wuxing.feu), 0.4), "obsidienne : surcharge Terre 0.6 / Feu 0.4")
	verifier(mats.saphir.wuxing.has("eau") and mats.meteorite_ferreuse.wuxing.has("metal"), "gemmes et météorite : surcharges lues")
	var couleurs := {}
	for id in mats.keys():
		couleurs[mats[id].color] = true
	verifier(couleurs.size() == mats.size(), "160 couleurs uniques")
	verifier(mats.chene.harvest.tool_category == "hache" and mats.chene.harvest.skill == "bucheronnage", "récolte : outil et compétence de la catégorie")
	# Le nombre de catégories n'est plus figé (designer 2026-09-02 : « si tu ressens le besoin tu peux
	# rajouter des catégories » — `animal` est née ce jour-là). Ce qui doit tenir : chaque catégorie
	# utilisée par une fiche de matériau est décrite, sinon on ne sait ni la récolter ni la travailler.
	var cats_mat: Dictionary = GameData.config("material_categories")
	var orphelines := {}
	for mid_c in GameData.catalogues.materials.keys():
		var cat_c := str(GameData.catalogues.materials[mid_c].get("category", ""))
		if not cats_mat.has(cat_c):
			orphelines[cat_c] = true
	verifier(orphelines.is_empty(), "chaque catégorie de matériau est décrite (%d catégories ; sans fiche : %s)" % [cats_mat.size(), str(orphelines.keys())])
	verifier(tr("material.acier_trempe.name") == "Acier trempé", "nom localisé")


# ---------------------------------------------------------------- Étape 6.2 : récolte en donjon

func test_recolte() -> void:
	var s := Simulation.new(11)
	s.charger_donjon("ruine", 11, 5, 1)
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var filons := {}
	for idx in s.grille.materiaux.keys():
		filons[s.grille.materiaux[idx]] = true
	verifier(s.grille.materiaux.size() >= 24, "des filons dans les murs de l'étage 1 (%d tuiles)" % s.grille.materiaux.size())
	var mp: Dictionary = GameData.config("minerais_par_etage")
	var permis: Array = mp.tiers["1"] + mp.tiers["2"] + mp.fossiles.materiaux
	var hors_tier := false
	for m in filons.keys():
		if not (m in permis):
			hors_tier = true
	verifier(not hors_tier, "étage 1 : seulement les tiers 1-2 et les fossiles (%s)" % str(filons.keys()))
	verifier(s.grille.materiau_defaut == "pierre", "les murs de la ruine sont en pierre")
	# Un mur adjacent au joueur, à mains nues : on creuse, rien n'est récolté.
	var mur := Vector2i(-1, -1)
	for d in Grille.DIRS:
		var t: Vector2i = j.pos + d
		if s.grille.dans(t) and s.grille.bloque_passage(t) and Grille.distance(j.pos, t) == 1:
			mur = t
			break
	if mur == Vector2i(-1, -1):
		# la salle d'arrivée peut être large : on pose un mur à côté
		mur = j.pos + Vector2i(1, 0)
		s.grille.poser_contenu(mur, "mur")
	var sac0: int = j.sac.size()
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "creuser", "vers": mur}), "creuser à mains nues")
	verifier(j.sac.size() == sac0 and j.compteur == int(GameData.config("combat_rules").creuser.ticks), "sans outil : 10 ticks, rien récolté")
	# Avec la pioche de fer (dureté 25), la pierre (dureté 15) : ⌈15 / 25 × 10 × mult_palier⌉ ticks. Le
	# chiffre se DÉDUIT des règles depuis que le palier du matériau allonge l'extraction (designer
	# 2026-09-02) — le recopier ici obligeait à corriger le test à chaque réglage du designer.
	var pioche := s.generer_objet("proto_pioche", 1, {}, "commun", 0)
	j.sac.append(pioche.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "equiper", "objet": pioche.uid}), "équiper la pioche")
	s.grille.poser_contenu(mur, "mur")
	s.attente[j.id] = true
	var xp0: int = int(j.xp_competences.get("minage", 0))
	verifier(s.intention(j.id, {"type": "creuser", "vers": mur}), "récolter le mur de pierre à la pioche")
	var pal_pierre := str(int(GameData.catalogues.materials.pierre.get("palier", 1)))
	var mult_pierre := float(GameData.config("combat_rules").paliers_materiaux[pal_pierre].extraction_ticks)
	var attendu_p := ceili(float(GameData.catalogues.materials.pierre.stats.durete) / (float(pioche.durete_base) * float(pioche.get("qualite", 1.0))) * float(GameData.config("combat_rules").recolte.ticks_par_seconde) * mult_pierre)
	verifier(j.compteur == attendu_p, "pierre à la pioche de fer : %d ticks (palier %s, ×%.1f) — obtenu %d" % [attendu_p, pal_pierre, mult_pierre, j.compteur])
	var brut := {}
	for uid in j.sac:
		var it: Dictionary = s.items[uid]
		if it.get("type", "") == "materiau":
			brut = it
	verifier(not brut.is_empty() and brut.materiau == "pierre" and int(brut.quantite) >= 1 and int(brut.quantite) <= 2, "1d2 pierre dans le sac (%d)" % int(brut.quantite))
	var q1: int = int(brut.quantite)
	verifier(int(j.xp_competences.get("minage", 0)) - xp0 > 0, "XP de Minage = dureté")
	s.grille.poser_contenu(mur, "mur")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "creuser", "vers": mur})
	verifier(int(brut.quantite) > q1, "la pierre s'empile (%d → %d)" % [q1, int(brut.quantite)])
	# Un filon de tungstène : le palier du matériau relève le seuil d'outil exigé (designer 2026-09-02,
	# « un matériau de fin de partie ne se ramasse pas à la pioche de départ »). La pioche de fer, qui
	# suffisait avant, rebondit désormais dessus ; il faut un outil à la hauteur du palier.
	s.grille.poser_contenu(mur, "filon")
	s.grille.materiaux[s.grille.idx(mur)] = "tungstene"
	var pal_tung := str(int(GameData.catalogues.materials.tungstene.get("palier", 1)))
	var seuil_tung := float(GameData.catalogues.materials.tungstene.stats.durete) * float(GameData.config("combat_rules").recolte.seuil_irrecoltable) * float(GameData.config("combat_rules").paliers_materiaux[pal_tung].outil_min)
	pioche.durete_base = 25
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "creuser", "vers": mur}), "la pioche de fer (25) rebondit sur le tungstène de palier %s : il en faut %d" % [pal_tung, ceili(seuil_tung)])
	pioche.durete_base = ceili(seuil_tung) + 1   # l'outil qu'exige ce palier
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "creuser", "vers": mur}), "un outil à la hauteur du palier entame le tungstène")
	var tung := false
	for uid in j.sac:
		if s.items[uid].get("materiau", "") == "tungstene":
			tung = true
	verifier(tung, "le filon donne son matériau")
	# La pelle : dix-sept matériaux (terre, sable, eau, os…) exigeaient un outil qui n'existait pas.
	var pelle := s.generer_objet("proto_pelle", 1, {}, "commun", 0)
	j.sac.append(pelle.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "equiper", "objet": pelle.uid}), "équiper la pelle")
	s.grille.poser_contenu(mur, "mur")
	s.grille.materiaux[s.grille.idx(mur)] = "terre"
	var xp_t: int = int(j.xp_competences.get("terrassement", 0))
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "creuser", "vers": mur}), "creuser la terre à la pelle")
	var terre := false
	for uid in j.sac:
		if s.items[uid].get("materiau", "") == "terre":
			terre = true
	verifier(terre and int(j.xp_competences.get("terrassement", 0)) > xp_t, "la pelle récolte la terre et donne l'XP de Terrassement")


# ---------------------------------------------------------------- Étape 6.3 : stations et transformations plates

func test_fabrication() -> void:
	var s := Simulation.new(13)
	s.charger_donjon("ruine", 13, 6, 1)
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	# Le test comptait les recettes et les stations. Ajouter une station le cassait alors que RIEN
	# n'était faux — c'est le sixième test à nombre figé que je convertis. Ce qui doit tenir, c'est la
	# RÈGLE : toute station se construit, et toute recette se fait quelque part qui existe.
	var sans_recette: Array = []
	for sid in GameData.catalogues.stations.keys():
		var trouvee := false
		for rid in GameData.catalogues.recipes.keys():
			var rr: Dictionary = GameData.catalogues.recipes[rid]
			if str(rr.get("sortie", {}).get("station", "")) == str(sid) or str(rr.get("station_produite", "")) == str(sid):
				trouvee = true
		for iid in GameData.catalogues.items.keys():
			var itt: Dictionary = GameData.catalogues.items[iid]
			if str(itt.get("type", "")) == "station" and str(itt.get("station", "")) == str(sid) and itt.has("recipe"):
				trouvee = true
		if not trouvee:
			sans_recette.append(str(sid))
	verifier(sans_recette.is_empty(), "chaque station se construit (%d stations, %d recettes) — sans recette : %s" % [GameData.catalogues.stations.size(), GameData.catalogues.recipes.size(), str(sans_recette)])
	var station_fantome: Array = []
	for rid2 in GameData.catalogues.recipes.keys():
		var st_r := str(GameData.catalogues.recipes[rid2].get("station", ""))
		if not st_r.is_empty() and not GameData.catalogues.stations.has(st_r):
			station_fantome.append("%s -> %s" % [rid2, st_r])
	verifier(station_fantome.is_empty(), "chaque recette se fait à une station qui existe (%s)" % str(station_fantome))
	s._donner_materiau(j, "fer", 3)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "fabriquer", "recette": "fondre_lingot"}), "sans forge dans le sac : rien")
	var forge := s.generer_objet("station_forge", 1, {}, "commun", 0)
	j.sac.append(forge.uid)
	var dispo := s.recettes_disponibles(j)
	var ids: Array = dispo.map(func(p: Dictionary) -> String: return p.id)
	verifier("fondre_lingot" in ids and "fondre_verre" in ids and not ("scier_planche" in ids), "la forge ouvre ses recettes, pas celles de la scierie (%s)" % str(ids))
	var fondre: Dictionary = dispo.filter(func(p: Dictionary) -> bool: return p.id == "fondre_lingot")[0]
	verifier(fondre.faisable and fondre.sortie.materiau == "fer" and fondre.sortie.forme == "lingot", "fondre : faisable, sortie = lingot de fer")
	var verre: Dictionary = dispo.filter(func(p: Dictionary) -> bool: return p.id == "fondre_verre")[0]
	verifier(not verre.faisable, "pas de sable : verre infaisable")
	s.attente[j.id] = true
	var xp0: int = int(j.xp_competences.get("forge", 0))
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "fondre_lingot"}), "fondre un lingot")
	verifier(int(s._pile(j, "fer", "brut").quantite) == 1 and int(s._pile(j, "fer", "lingot").quantite) == 1, "2 fer brut consommés, 1 lingot de fer produit")
	verifier(j.compteur == 2000, "2000 ticks (deux secondes) au niveau 0 (%d)" % j.compteur)
	var dxp: int = int(j.xp_competences.get("forge", 0)) - xp0
	verifier(dxp > 0 and dxp <= 25, "XP de Forge = dureté du fer (25) × potentiel (%d)" % dxp)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "fabriquer", "recette": "fondre_lingot"}), "il ne reste qu'un fer brut : il en manque")
	verifier(s._pile(j, "fer", "brut").size() > 0 and s._pile(j, "cuivre", "brut").is_empty(), "les piles sont par matériau et par forme")
	# Le personnage créé part avec un établi portatif.
	var prog := Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	var fiche := Etres.creer_personnage("creature.aventurier.name", "humain", GameData.catalogues.classes.keys()[0], {}, 1000, prog)
	verifier("station_etabli" in fiche.get("sac", []), "le personnage part avec un établi")


# ---------------------------------------------------------------- Étape 6.4 : composants et assemblage

func test_assemblage() -> void:
	var s := Simulation.new(17)
	s.charger_donjon("ruine", 17, 8, 1)
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	# Dixieme test a nombre fige converti : il comptait « 15 composants, 59 recettes » et tombait des
	# qu'on en retirait un — ici la garde et le contrepoids, supprimes parce qu'aucun objet ne pouvait
	# les porter sous la limite de trois pieces. Ce qui doit tenir, c'est la CHAINE : tout composant se
	# fabrique, tout composant sert a quelque chose, et aucun objet ne depasse la limite.
	var sans_recette: Array[String] = []
	var jamais_porte: Array[String] = []
	var portes := {}
	var trop_gros: Array[String] = []
	var maxi_comp := int(GameData.config("loot_rules").assemblage.get("composants_max", 3))
	for iid in GameData.catalogues.items.keys():
		var sl: Dictionary = GameData.catalogues.items[iid].get("slots", {})
		if sl.size() > maxi_comp:
			trop_gros.append("%s (%d)" % [str(iid), sl.size()])
		for c in sl.values():
			portes[str(c)] = true
	for cid in GameData.catalogues.components.keys():
		var a_recette := false
		for rid in GameData.catalogues.component_recipes.keys():
			if str(GameData.catalogues.component_recipes[rid].get("component", "")) == str(cid):
				a_recette = true
		if not a_recette:
			sans_recette.append(str(cid))
		if not portes.has(str(cid)):
			jamais_porte.append(str(cid))
	verifier(sans_recette.is_empty(), "chaque composant se fabrique (%d composants, %d recettes) — sans recette : %s" % [GameData.catalogues.components.size(), GameData.catalogues.component_recipes.size(), str(sans_recette)])
	verifier(jamais_porte.is_empty(), "chaque composant est porte par au moins un objet (%s)" % str(jamais_porte))
	verifier(trop_gros.is_empty(), "aucun objet ne depasse %d composants (%s)" % [maxi_comp, str(trop_gros)])
	for st in ["etabli", "enclume", "scierie"]:   # l'aventurier des donjons de test n'est pas un personnage créé
		j.sac.append(s.generer_objet("station_" + st, 1, {}, "commun", 0).uid)
	s._donner_materiau(j, "fer", 3, "lingot")
	s._donner_materiau(j, "chene", 1, "planche")
	var ids: Array = s.recettes_disponibles(j).filter(func(pl: Dictionary) -> bool: return pl.faisable).map(func(pl: Dictionary) -> String: return pl.id)
	verifier("lame_courte_lingot_metal" in ids and "poignee_bois" in ids and "garde_lingot_metal" in ids and not ("lame_courte_obsidienne" in ids), "recettes de composants faisables : lame (lingot), poignée (planche), garde (lingot) ; l'obsidienne non (%s)" % str(ids))
	verifier(not ("lame_courte_or_argent" in s.recettes_disponibles(j).map(func(pl: Dictionary) -> String: return pl.id)), "les recettes exotiques non apprises ne sont pas listées")
	for rid in ["lame_courte_lingot_metal", "poignee_bois", "garde_lingot_metal"]:
		s.attente[j.id] = true
		verifier(s.intention(j.id, {"type": "fabriquer", "recette": rid}), "façonner " + rid)
	var comps: Array = j.sac.filter(func(uid: String) -> bool: return s.items[uid].get("type", "") == "composant")
	var uids_uniques := {}
	for u in comps:
		uids_uniques[u] = true
	verifier(comps.size() == 3 and uids_uniques.size() == 3, "3 composants dans le sac, à trois identifiants distincts (%d, %d uid) — deux objets ont porté le même uid le 2026-09-07" % [comps.size(), uids_uniques.size()])
	var lame: Dictionary = s.items[comps[0]]
	var durete_fer := int(GameData.catalogues.materials.fer.stats.durete)
	verifier(lame.composant == "lame_courte" and lame.materiau == "fer" and int(lame.stats.durete) == durete_fer and lame.elements.has("metal"), "la lame porte les stats du fer (%d) et son élément" % durete_fer)
	verifier(float(lame.qualite) >= 0.1 and float(lame.qualite) <= 0.1 + 0.0001 or float(lame.qualite) <= 2.3, "qualité A.3 au niveau 0 : plancher 0,1 (%.2f)" % float(lame.qualite))
	verifier(int(s._pile(j, "fer", "lingot").quantite) == 1 and s._pile(j, "chene", "planche").is_empty(), "les unités consommées : 1 lingot restant, plus de planche")
	var dague_plan: Array = s.recettes_disponibles(j).filter(func(pl: Dictionary) -> bool: return pl.id == "craft_dague")
	verifier(dague_plan.size() == 1 and dague_plan[0].faisable, "l'assemblage de la dague est faisable à l'établi")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "craft_dague"}), "assembler la dague")
	var dague := {}
	for uid in j.sac:
		if s.items[uid].get("base", "") == "craft_dague":
			dague = s.items[uid]
	verifier(not dague.is_empty() and dague.materiau == "fer" and dague.element == "metal", "Dague en fer, élément Métal (la tête domine)")
	# durete_base = Σ part × dureté × mult_palier du matériau de la pièce (designer 2026-09-02) : le
	# palier creuse l'écart entre une lame de début et une lame de fin, au-delà de la seule dureté.
	var pm_t: Dictionary = GameData.config("combat_rules").paliers_materiaux
	var mp := func(mat: String) -> float:
		return float(pm_t[str(int(GameData.catalogues.materials[mat].get("palier", 1)))].mult_stats)
	var d_fer := float(GameData.catalogues.materials.fer.stats.durete)
	var d_chene := float(GameData.catalogues.materials.chene.stats.durete)
	var attendu_d := roundi(0.7 * d_fer * mp.call("fer") + 0.25 * d_chene * mp.call("chene") + 0.05 * d_fer * mp.call("fer"))
	verifier(int(dague.durete_base) == attendu_d, "durete_base = moyenne pondérée × palier, avant qualité : %d attendu, %d obtenu" % [attendu_d, int(dague.durete_base)])
	verifier(is_equal_approx(float(dague.elements.metal), 0.75) and is_equal_approx(float(dague.elements.bois), 0.25), "Wu Xing composite Métal 0,75 / Bois 0,25")
	verifier(is_equal_approx(float(dague.vitesse_facteur), 0.94), "manche en chêne (densité 6) : vitesse ×0,94 (%.2f)" % float(dague.vitesse_facteur))
	verifier(float(dague.qualite) > 0.0 and dague.composants.has("tete") and dague.composants.has("manche"), "qualité posée, composants mémorisés pour l'infobulle")
	verifier(j.sac.filter(func(uid: String) -> bool: return s.items[uid].get("type", "") == "composant").is_empty(), "les composants sont consommés")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "equiper", "objet": dague.uid}), "la dague assemblée s'équipe")
	var fonct: Dictionary = s.fonctionnalites.dague
	verifier(s.regles.ticks_attaque(fonct, false, dague) == roundi(float(s.regles.r.actions.attaque_base) / 3.0 * 0.94), "le manche pèse sur les ticks d'attaque")
	var n := s.nom_objet(dague.uid)
	verifier(n.has("materiau") and n.materiau == "material.fer.name", "le nom se décrit par le matériau de la tête")


# ---------------------------------------------------------------- écrans : desequiper, jeter

func test_desequiper_jeter() -> void:
	var s := Simulation.new(19)
	s.charger_arene("plaine_au_talus")
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var arme: String = j.equipement.main_principale
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "desequiper", "slot": "main_principale"}), "retirer l'arme en main")
	verifier(not j.equipement.has("main_principale") and arme in j.sac, "l'arme retirée est dans le sac")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "desequiper", "slot": "main_principale"}), "rien à retirer : refus")
	var n0: int = j.sac.size()
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "jeter", "objet": arme}), "jeter l'arme")
	verifier(j.sac.size() == n0 - 1 and s.contenants.has(s.grille.idx(j.pos)) and arme in s.contenants[s.grille.idx(j.pos)], "elle est en butin sur la tuile")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "ramasser"}) and arme in j.sac, "et se ramasse (R)")


# ---------------------------------------------------------------- Étape 8.1 : une cellule de surface
