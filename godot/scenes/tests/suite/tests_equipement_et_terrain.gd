extends TestsBase
## L'équipement, les recettes, les plantes, le bestiaire, les statuts et potions, la nage, la neige, l'eau, le feu, la lave, le courant.
## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de
## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l'ordre de sa liste.


## L'USURE D'UN OBJET (ordre de travail 30, la moitié qui restait — 2026-09-09). Le même `alteration`, appliqué au
## matériau d'une INSTANCE. **La précaution qui décide du dessin s'éprouve la première** : `qualite` n'est pas
## touchée — elle est lue par les dégâts, l'armure et les prix, et des dizaines de tests sont calibrés dessus.
func test_usure() -> void:
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	var us: Dictionary = s.regles.r.get("usure", {})
	verifier(not us.is_empty(), "l'usure a ses nombres en données")
	var arme := s.generer_objet("proto_epee_courte", 1, {}, "commun", 0)
	if arme.is_empty():
		return
	# 1. UN OBJET NEUF SE COMPORTE EXACTEMENT COMME AVANT. C'est ce qui protège les nombres déjà calibrés.
	verifier(is_equal_approx(s.regles.qualite_utile(arme), float(arme.get("qualite", 1.0))), "un objet qui n'a jamais servi ne perd rien (%.3f)" % s.regles.qualite_utile(arme))
	# 2. L'USAGE PREND, À LA VITESSE DE LA MATIÈRE. Une lame de fer s'émousse ; une lame d'or ne s'abîmerait pas.
	var fer := arme.duplicate(true)
	fer["materiau"] = "fer"
	var or_ := arme.duplicate(true)
	or_["materiau"] = "or"
	verifier(s.regles.usure_du_geste(fer, "par_coup") > s.regles.usure_du_geste(or_, "par_coup"), "le fer s'use plus vite que l'or (%.5f contre %.5f) — et c'est la même stat qui dit pourquoi l'or vaut cher" % [s.regles.usure_du_geste(fer, "par_coup"), s.regles.usure_du_geste(or_, "par_coup")])
	# 3. LE PLAFOND TIENT : un objet usé est mauvais, il n'est JAMAIS inutile.
	s.items[str(arme.uid)]["materiau"] = "fer"
	for k in 5000:
		s.user_objet(str(arme.uid), "par_coup")
	var plafond := float(us.get("usure_max", 0.5))
	verifier(is_equal_approx(float(s.items[str(arme.uid)].usure), plafond), "l'usure s'arrête au plafond (%.2f)" % float(s.items[str(arme.uid)].usure))
	verifier(s.regles.qualite_utile(s.items[str(arme.uid)]) > 0.0, "et l'objet vaut encore quelque chose : %.3f" % s.regles.qualite_utile(s.items[str(arme.uid)]))
	# 4. IL Y A UN CHEMIN DE RETOUR. Un mécanisme qui ne fait que dégrader est un impôt, pas une règle.
	j.sac.append(str(arme.uid))
	var avant := float(s.items[str(arme.uid)].usure)
	verifier(not SimObjets._reparer(s, j, str(arme.uid), 0), "sans la matière, on ne répare pas")
	SimTerrain._donner_materiau(s, j, "fer", 3)
	var ok_r := SimObjets._reparer(s, j, str(arme.uid), 0)
	verifier(ok_r and float(s.items[str(arme.uid)].usure) < avant, "avec du fer en sac, la lame se remet en état (%.2f → %.2f)" % [avant, float(s.items[str(arme.uid)].usure)])


## L'EAU QUI PÈSE — première moitié : **elle s'infiltre** (ordre de travail 32, 2026-09-09). Un creux était jusqu'ici
## un bassin PARFAIT quel que soit son fond : on tenait un étang sur du sable. La quinzième colonne, `permeabilite`,
## lui donne sa raison — et fait d'un bassin un ouvrage.
func test_infiltration() -> void:
	var ea: Dictionary = GameData.config("combat_rules").get("eau", {})
	verifier(ea.has("infiltration_seuil"), "l'infiltration a son seuil en données")
	# 1. LA COLONNE EXISTE PARTOUT, et elle range le monde dans le bon ordre.
	var sans := 0
	for mid: String in GameData.catalogues.materials.keys():
		if not (GameData.catalogues.materials[mid].get("stats", {}) as Dictionary).has("permeabilite"):
			sans += 1
	verifier(sans == 0, "chaque matière dit ce que l'eau traverse (%d muette(s))" % sans)
	var perm := func(m: String) -> int: return int(GameData.catalogues.materials.get(m, {}).get("stats", {}).get("permeabilite", -1))
	verifier(perm.call("argile") < perm.call("limon") and perm.call("limon") < perm.call("sable") and perm.call("sable") < perm.call("gravier"), "argile %d < limon %d < sable %d < gravier %d — l'ordre du monde réel" % [perm.call("argile"), perm.call("limon"), perm.call("sable"), perm.call("gravier")])
	verifier(perm.call("granit") < perm.call("gres") and perm.call("beton") < perm.call("brique"), "le granit et le béton arrêtent l'eau ; le grès et la brique la laissent un peu passer")
	# 2. LE FOND DÉCIDE. On demande à la règle, sur deux fonds opposés — c'est elle qu'on éprouve, pas l'automate.
	var s := nouvelle_sim("gorge")
	var t: Vector2i = joueur_de(s).pos + Vector2i(2, 0)
	if not s.grille.dans(t):
		return
	s.grille.sols[s.grille.idx(t)] = "argile"
	var sur_argile: int = SimTerrain.infiltration_de(s, t)
	s.grille.sols[s.grille.idx(t)] = "sable"
	var sur_sable: int = SimTerrain.infiltration_de(s, t)
	verifier(sur_argile == 0 and sur_sable > 0, "un creux d'argile tient l'eau (%d), un creux de sable la boit (%d)" % [sur_argile, sur_sable])


## LE TEMPS LONG (ordre de travail 30, 2026-09-09) : la repousse existait, mais elle était IMMÉDIATE et identique
## pour tout le monde — un mur de granit et un toit de chaume tombaient à la même seconde. La colonne `alteration`
## lui donne enfin un délai, et c'est ce délai qu'on éprouve : sa dépendance à la matière, et le fait qu'il ne se
## tique pas.
func test_temps_long() -> void:
	var tl: Dictionary = GameData.config("combat_rules").get("temps_long", {})
	verifier(not tl.is_empty(), "le temps long a ses nombres en données")
	# 1. LA COLONNE EXISTE SUR LES 247 MATIÈRES, et elle range le monde dans le bon ordre.
	var sans := 0
	for mid: String in GameData.catalogues.materials.keys():
		if not (GameData.catalogues.materials[mid].get("stats", {}) as Dictionary).has("alteration"):
			sans += 1
	verifier(sans == 0, "chaque matière dit à quelle vitesse elle se dégrade exposée (%d muette(s))" % sans)
	var alt := func(m: String) -> int: return int(GameData.catalogues.materials.get(m, {}).get("stats", {}).get("alteration", -1))
	verifier(alt.call("granit") < alt.call("chene") and alt.call("chene") < alt.call("paille"), "la pierre tient, le bois moins, la paille pas du tout (%d < %d < %d)" % [alt.call("granit"), alt.call("chene"), alt.call("paille")])
	verifier(alt.call("or") < alt.call("fer"), "l'or ne s'oxyde pas et le fer rouille — et c'est POUR CELA que l'or vaut cher (%d < %d)" % [alt.call("or"), alt.call("fer")])

	# 2. LE DÉLAI SUIT LA MATIÈRE. On le demande à la règle, sur deux tuiles de matières opposées.
	var s := nouvelle_sim("gorge")
	var t: Vector2i = s.vivants()[0].pos + Vector2i(2, 0)
	if not s.grille.dans(t):
		return
	var memo := {"h": 0, "contenu": 0, "tick": 0, "materiau": "granit"}
	var d_granit: int = SimTerrain.delai_ruine(s, t, memo)
	memo["materiau"] = "paille"
	var d_paille: int = SimTerrain.delai_ruine(s, t, memo)
	verifier(d_granit > d_paille * 3, "un passage creusé dans le granit reste ouvert bien plus longtemps qu'un sentier dans la paille (%d contre %d)" % [d_granit, d_paille])

	# 3. IL NE SE TIQUE PAS : la modification porte son heure, et la passe hebdomadaire compare. Tant que le délai
	# n'est pas échu, le monde ne rend rien — et une mémoire d'AVANT cette ligne, sans heure, est échue d'emblée.
	var s2 := nouvelle_sim("gorge")
	var j2 := joueur_de(s2)
	var q: Vector2i = j2.pos + Vector2i(1, 0)
	if not s2.grille.dans(q) or s2.monde != null:
		return   # l'arène n'a pas de monde : la passe hors claim ne s'y joue pas, on s'arrête ici
	SimTerrain._memoriser_terrain(s2, q)
	verifier(s2.modifs_terrain.has(q) and int(s2.modifs_terrain[q].get("tick", -1)) == s2.horloge_monde.ticks, "une modification retient l'heure où elle a été faite")
	verifier(s2.modifs_terrain[q].has("materiau"), "et la matière qu'il faudra remettre")


func test_effets_equipement() -> void:
	var s := Simulation.new(139)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var anneau := {"uid": "anneau_test", "name_key": "x", "type": "bijou", "equip_slot": "anneau", "affixes": [{"id": "passif_vitesse", "params": {"pct": 50}}, {"id": "passif_regen", "params": {"pct": 100}}, {"id": "passif_poids", "params": {"n": 40}}, {"id": "passif_tag", "params": {"tag": "immunite_poison"}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	s.items["anneau_test"] = anneau
	var cap0: float = s.poids_de(j).capacite
	j.equipement["anneau_1"] = "anneau_test"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(j.mecaniques.has("vitesse_deplacement") and j.mecaniques.has("regen_sante") and "immunite_poison" in j.tags_acquis, "les mécaniques et le tag sont collectés (%s)" % str(j.mecaniques.keys()))
	verifier(s.poids_de(j).capacite == cap0 + 40.0, "capacité de poids +40 (%.0f → %.0f)" % [cap0, s.poids_de(j).capacite])
	verifier(not s.appliquer_statut(j, "poison", 10000, ""), "immunisé au poison")
	j.sante = 10
	j.tick_vigueur = 0
	var per_rg := maxi(1, roundi(float(s.regles.r.effets_equipement.regen_base_ticks) * 100.0 / 100.0))   # pct 100 : une période pleine par PV
	s._regenerer(j, 5 * per_rg)
	verifier(int(j.sante) == 15, "régénération : +5 PV en %d ticks à +100 %% (%d)" % [5 * per_rg, int(j.sante)])
	var t: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.contenu[s.grille.idx(t)] = 0
	s.grille.contenu[s.grille.idx(t + Vector2i(1, 0))] = 0
	s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	s.grille.hauteurs[s.grille.idx(t + Vector2i(1, 0))] = s.grille.h(j.pos)
	s.attente[j.id] = true
	var c0 := int(j.compteur)
	s.intention(j.id, {"type": "deplacer", "vers": t})
	var ticks_avec: int = int(j.compteur) - c0
	var ticks_sans: int = ceili(float(s.regles.ticks_deplacement(int(s.regles.r.deplacement.cout_base), j.competences_eff, false)) * s.poids_de(j).facteur)
	j.equipement.erase("anneau_1")
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(ticks_avec > 0 and ticks_avec < ticks_sans, "vitesse +50 %% : %d ticks avec, %d sans" % [ticks_avec, ticks_sans])
	# Pas silencieux : détecté de moins loin
	var g := s.ajouter("villageois", j.pos + Vector2i(0, 8), "ia")
	s._habiller_pnj(g, GameData.entree("creatures", "villageois"))
	g.corps.stats.perception = 10
	for d in range(1, 9):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(0, d))] = 0
	s.horloge_monde.ticks = int(s._cycle().ticks_par_jour) / 2
	verifier(s.voit_ia(g, j), "à 8 tuiles, de jour : vu")
	j["tags_acquis_race"] = ["pas_silencieux"]
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(not s.voit_ia(g, j), "pas silencieux : portée 10 × 0,7 = 7 → invisible à 8 tuiles")
	s.monde.fermer()


# ---------------------------------------------------------------- Wu Xing hors combat : le lieu

func test_palette_etage() -> void:
	var s := Simulation.new(140)
	var theme := GameData.entree("dungeon_themes", "ruine")
	verifier(s.materiau_mur_etage(theme, 1) == "pierre" and s.materiau_mur_etage(theme, 2) == "pierre", "étages 1-2 : le thème (pierre)")
	# Le test nommait les roches une par une ; changer la palette le cassait alors que la RÈGLE tenait
	# toujours. Ce qu'on vérifie, c'est la PENTE : chaque bande annonce la roche que la palette dit, et
	# une bande plus profonde n'est jamais plus tendre que la précédente (sonde de la mine, 2026-09-03).
	var bandes: Array = GameData.config("minerais_par_etage").palette_mur.bandes
	var pente_ok := true
	var dur_prec := 0
	var dit_juste := true
	for b in bandes:
		var e_b := int(b.etages[0])
		if e_b < int(GameData.config("minerais_par_etage").palette_mur.get("etage_min", 3)):
			continue
		if s.materiau_mur_etage(theme, e_b) != str(b.materiau):
			dit_juste = false
		var dur := int(GameData.entree("materials", str(b.materiau)).stats.durete)
		if dur < dur_prec:
			pente_ok = false
		dur_prec = dur
	verifier(dit_juste, "chaque bande de la palette rend sa roche (%d bandes)" % bandes.size())
	verifier(pente_ok, "la dureté CROÎT de bande en bande : creuser ralentit avec l'étage")
	var bande_6 := ""
	for b2 in bandes:
		if 6 >= int(b2.etages[0]) and 6 <= int(b2.etages[1]):
			bande_6 = str(b2.materiau)
	s.charger_donjon("ruine", 140, 17, 6)
	verifier(s.grille.materiau_defaut == bande_6, "étage 6 chargé : les murs sont ce que la palette annonce (%s)" % bande_6)
	var comptes := {}
	for y in s.grille.hauteur_grille:
		for x in s.grille.largeur:
			var t := Vector2i(x, y)
			if "destructible" in s.grille.contenu_de(t).get("tags", []):
				var m := s.grille.materiau_de(t)
				comptes[m] = int(comptes.get(m, 0)) + 1
	# Pareil pour les poches : ce qui compte est que la roche de la bande DOMINE et que des taches de la
	# bande d'au-dessus et d'en dessous existent — pas le nom de ces trois roches.
	var saut := int(GameData.config("minerais_par_etage").palette_mur.poches.get("saut", 2))
	var m_dur := s.materiau_mur_etage(theme, 6 + saut)
	var m_tendre := s.materiau_mur_etage(theme, maxi(3, 6 - saut))
	verifier(int(comptes.get(bande_6, 0)) > int(comptes.get(m_dur, 0)) and int(comptes.get(m_dur, 0)) > 0 and int(comptes.get(m_tendre, 0)) > 0, "poches de strates : %s majoritaire, taches de %s et de %s (%s)" % [bande_6, m_dur, m_tendre, str(comptes)])


# ---------------------------------------------------------------- Effets d'équipement types

func test_arme_mixte() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var mixte := {"uid": "mixte_test", "name_key": "item.proto_epee.name", "type": "arme", "equip_slot": "main_principale", "hands": 1, "functionality": "epee", "durete_base": 20, "qualite": 1.0, "element": "feu", "elements": {"feu": 0.6, "metal": 0.4}, "tags": ["arme"], "materiau": "fer", "affixes": [], "sertissures": {"nombre": 0, "contenu": []}}
	s.items["mixte_test"] = mixte
	j.sac.append("mixte_test")
	j.equipement["main_principale"] = "mixte_test"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(s.vecteur_arme(mixte) == {"feu": 0.6, "metal": 0.4}, "le vecteur complet de l'arme assemblée est lu")
	verifier(s.segments_possibles(mixte) == ["feu", "metal"], "deux segments possibles : feu, metal")
	var pure := {"element": "feu"}
	verifier(s.segments_possibles(pure).is_empty(), "une arme pure n'a pas le choix")
	var h := s.horloge_de(j)
	j.chaine.segments.clear()
	s._poser_segment(j, s.vecteur_arme(mixte), h.ticks)
	verifier(j.chaine.segments.size() == 1 and str(j.chaine.segments[0].element) == "feu", "sans préférence : le dominant (feu)")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "segment_prefere", "element": "metal"}) and str(j.segment_prefere) == "metal", "préférer le métal (0 tick)")
	s._poser_segment(j, s.vecteur_arme(mixte), h.ticks + 100)
	verifier(str(j.chaine.segments[j.chaine.segments.size() - 1].element) == "metal", "avec préférence : le segment posé est métal")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "segment_prefere", "element": "eau"})
	s._poser_segment(j, s.vecteur_arme(mixte), h.ticks + 200)
	verifier(str(j.chaine.segments[j.chaine.segments.size() - 1].element) == "feu", "une préférence hors du vecteur est ignorée : dominant")


# ---------------------------------------------------------------- Stratification verticale : la palette de sol

func test_niveaux_recette() -> void:
	var s := Simulation.new(141)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	j["recettes_connues"] = ["tremper_verre"]
	verifier(s.niveau_recette(j, "tremper_verre") == 1, "niveau 1 par défaut")
	s._doublon_recette(j, "tremper_verre")
	verifier(s.niveau_recette(j, "tremper_verre") == 2, "1 doublon : niveau 2")
	s._doublon_recette(j, "tremper_verre")
	verifier(s.niveau_recette(j, "tremper_verre") == 2 and int(j.doublons_recettes.tremper_verre) == 1, "il en faut 2 pour le niveau 3 : encore 1")
	s._doublon_recette(j, "tremper_verre")
	verifier(s.niveau_recette(j, "tremper_verre") == 3, "2 doublons : niveau 3")
	for k in 7:
		s._doublon_recette(j, "tremper_verre")
	verifier(s.niveau_recette(j, "tremper_verre") == 5, "10 doublons en tout : niveau 5 (plafond)")
	s._doublon_recette(j, "tremper_verre")
	verifier(s.niveau_recette(j, "tremper_verre") == 5, "au plafond, un doublon ne fait plus rien")
	# Le jet : même moyenne, variance resserrée, jamais multipliée
	var rng := RandomNumberGenerator.new()
	var lo1 := 9.0
	var hi1 := 0.0
	var lo5 := 9.0
	var hi5 := 0.0
	for k in 300:
		rng.seed = k
		var q1 := s.regles.qualite_craft(25, rng, s.regles.resserrement_recette(1))
		rng.seed = k
		var q5 := s.regles.qualite_craft(25, rng, s.regles.resserrement_recette(5))
		lo1 = minf(lo1, q1)
		hi1 = maxf(hi1, q1)
		lo5 = minf(lo5, q5)
		hi5 = maxf(hi5, q5)
	verifier(hi5 - lo5 < hi1 - lo1 and hi5 <= hi1 + 0.001 and lo5 >= lo1 - 0.001, "niveau 5 : fourchette [%.2f ; %.2f] dans [%.2f ; %.2f]" % [lo5, hi5, lo1, hi1])
	s.monde.fermer()


# ---------------------------------------------------------------- Compensation de l'arme mixte

func test_plantes() -> void:
	verifier(GameData.catalogues.plants.size() >= 22, "au moins les 22 plantes d'origine au catalogue (%d — la refonte de l'agriculture en a ajouté, 2026-09-07)" % GameData.catalogues.plants.size())
	var cats := {}
	for pid in GameData.catalogues.plants.keys():
		var c := str(GameData.catalogues.plants[pid].categorie)
		cats[c] = int(cats.get(c, 0)) + 1
	verifier(int(cats.get("culture", 0)) >= 8 and int(cats.get("buisson", 0)) >= 4 and int(cats.get("herbe", 0)) == 6 and int(cats.get("champignon", 0)) >= 2 and int(cats.get("decorative", 0)) == 2, "%d cultures, %d buissons et %d champignons (au moins 8, 4 et 2), 6 herbes, 2 décoratives" % [int(cats.get("culture", 0)), int(cats.get("buisson", 0)), int(cats.get("champignon", 0))])
	var s := Simulation.new(142)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var am := s.generer_objet("amanite", 1, {}, "commun", 0)
	j.sac.append(am.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "manger", "objet": am.uid}) and Etres.a_statut_tag(j, "poison", s.statuts_defs), "manger une amanite empoisonne")
	j.statuts = []
	j.sante = 10
	var ps := s.generer_objet("potion_soin", 1, {}, "commun", 0)
	j.sac.append(ps.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "manger", "objet": ps.uid}) and int(j.sante) >= 12, "la potion de soin rend 2d6 (%d)" % int(j.sante))
	verifier(str(GameData.entree("items", "achillee").distillat) == "potion_soin" and GameData.catalogues.recipes.has("distiller_herbe"), "l'achillée se distille en potion de soin")
	s.monde.fermer()


# ---------------------------------------------------------------- Axe des niveaux de recette

func test_bestiaire() -> void:
	var betes: Array = []
	for cid in GameData.catalogues.creatures.keys():
		if "bete" in GameData.catalogues.creatures[cid].get("tags", []):
			betes.append(str(cid))
	verifier(betes.size() >= 19, "au moins 19 races animales au bestiaire (%d)" % betes.size())
	for cid in betes:
		for a in GameData.catalogues.creatures[cid].actions:
			verifier(GameData.catalogues.creature_actions.has(str(a)), "%s : action %s connue" % [cid, a])
	for b in ["toundra", "marecage", "montagne", "desert_aride"]:
		for f in GameData.entree("biomes", b).faune:
			verifier(GameData.catalogues.creatures.has(str(f.id)), "%s : faune %s existe" % [b, f.id])
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var ours := s.ajouter("ours_brun", j.pos + Vector2i(1, 0), "ia")
	verifier(ours.corps.stats.force == 18 and ours.corps.silhouette == "quadrupede" and not ours.actions.is_empty(), "un ours brun se pose : Force 18, quadrupède, %d actions" % ours.actions.size())
	var moustiques := s.ajouter("nuee_moustiques", j.pos + Vector2i(-1, 0), "ia")
	verifier(moustiques.corps.silhouette == "amorphe" and "nuee" in moustiques.tags, "une nuée de moustiques : amorphe, tag nuée")


# ---------------------------------------------------------------- Les 22 plantes

func test_statuts_complets() -> void:
	for sid in ["brulure", "ralentissement", "gel", "poison", "saignement", "etourdi", "confusion", "terreur", "infection", "affaibli", "regeneration", "peau_de_pierre", "hate", "beni", "dissimule", "saisi", "retarde"]:
		verifier(GameData.catalogues.status_effects.has(sid), "statut %s en données" % sid)
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var h := s.horloge_de(j)
	# Régénération
	j.sante = 10
	s.appliquer_statut(j, "regeneration", 5000, "")
	s._tiquer_statuts(j, h.ticks + 3000)
	verifier(int(j.sante) >= 13, "Régénération : +1d4 par période (%d PV après 3 périodes)" % int(j.sante))
	j.statuts = []
	# Gel : immobilisé, jet de Force pour se libérer
	j.stats_eff.force = 40
	s.appliquer_statut(j, "gel", 2000, "")
	verifier(Etres.bloque_statuts(j, "deplacement", s.statuts_defs), "gelé : ne bouge plus")
	s._tiquer_statuts(j, h.ticks + 1000)
	verifier(not Etres.a_statut_id(j, "gel"), "Force 40 : libéré au premier jet")
	# Béni : +1 dé
	s.appliquer_statut(j, "beni", 300000, "")
	verifier(int(Etres.add_statuts(j, "des", s.statuts_defs)) == 1, "Béni : +1 dé aux jets")
	# Peau de pierre : +5 d'armure dans la résolution
	s.appliquer_statut(j, "peau_de_pierre", 10000, "")
	verifier(int(Etres.add_statuts(j, "armure", s.statuts_defs)) == 5, "Peau de pierre : +5 d'armure")
	j.statuts = []
	# L'eau éteint la brûlure
	s.appliquer_statut(j, "brulure", 3000, "")
	var bord: Vector2i = j.pos + Vector2i(1, 0)
	var eau: Vector2i = j.pos + Vector2i(2, 0)
	s.grille.contenu[s.grille.idx(bord)] = 0
	s.grille.hauteurs[s.grille.idx(bord)] = s.grille.h(j.pos)
	s.grille.poser_contenu(eau, "eau")
	s.attente[j.id] = true
	var ok_dep := s.intention(j.id, {"type": "deplacer", "vers": bord})
	verifier(ok_dep and not Etres.a_statut_id(j, "brulure"), "arriver au bord de l'eau éteint la brûlure")


# ---------------------------------------------------------------- Le bestiaire : 19 races animales

func test_potions_completes() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	s.appliquer_statut(j, "vision_nocturne_potion", 300000, "")
	verifier("vision_nocturne" in j.tags_acquis, "la potion de vision nocturne accorde le tag")
	s.appliquer_statut(j, "antipoison", 150000, "")
	verifier(not s.appliquer_statut(j, "poison", 10000, ""), "antipoison : immunisé")
	j.statuts = []
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.appliquer_statut(j, "resistance_froid", 300000, "")
	verifier(int(Etres.add_statuts(j, "isolation", s.statuts_defs)) == 40, "résistance au froid : isolation +40")
	j.statuts = []
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	s.appliquer_statut(j, "lame_empoisonnee", 150000, "")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	var h := s.horloge_de(j)
	for k in 3:
		j.compteur = h.ticks
		s.pas(j.horloge)
	verifier(Etres.a_statut_tag(loup, "poison", s.statuts_defs), "poison de lame : le loup est empoisonné par le coup")
	verifier(str(GameData.entree("items", "amanite").distillat) == "poison_de_lame" and GameData.catalogues.items.has("poison_de_lame"), "l'amanite se distille en poison de lame")


# ---------------------------------------------------------------- Les 17 statuts

func test_poison_illegal() -> void:
	var s := Simulation.new(143)
	s.charger_camp()
	var n_lois := 0
	var n_roy := 0
	for k in 40:
		var sect: Vector2i = s.monde.surface.secteur_de(s.monde.cellule_camp) + Vector2i(k % 7 - 3, k / 7 - 3)
		var roys: Dictionary = s.monde.surface.royaumes_secteur(sect)
		if true:
			for rid in roys.keys():
				var r: Dictionary = roys[rid]
				if str(r.government_type) == "anarchie":
					continue
				n_roy += 1
				for l in r.laws:
					if str(l.target) == "poison_de_lame" and str(l.status) == "illegal":
						n_lois += 1
	verifier(n_roy > 0 and n_lois > 0 and float(n_lois) / float(n_roy) >= 0.5, "le poison de lame est illégal dans %d royaumes sur %d" % [n_lois, n_roy])
	s.monde.fermer()


# ---------------------------------------------------------------- Treize potions

func test_nage() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var h := s.horloge_de(j)
	var eau: Vector2i = j.pos + Vector2i(1, 0)
	var eau2: Vector2i = j.pos + Vector2i(2, 0)
	for t in [eau, eau2]:
		s.grille.poser_contenu(t, "eau")
		s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	verifier(not s.grille.bloque_passage(eau) and s.grille.cout_pas(j.pos, eau) == 600, "l'eau se traverse : coût de pas 600")
	s.attente[j.id] = true
	var c0 := int(j.compteur)
	verifier(s.intention(j.id, {"type": "deplacer", "vers": eau}) and j.pos == eau and int(j.compteur) - c0 >= 4, "nager : %d ticks" % (int(j.compteur) - c0))
	# Le butin de mort périme après un jour (Mort et pénalité, 2026-08-31)
	var t_per: Vector2i = j.pos + Vector2i(-2, 0)
	var o_per: Dictionary = s.generer_objet("proto_epee", 1, {}, "commun", 0)
	s._poser_contenant(t_per, [o_per.uid], "butin")
	s.objets[o_per.uid]["peremption_tick"] = 100
	s._perimer_butin(101)
	verifier(not s.contenants.has(s.grille.idx(t_per)) and s.grille.contenu_de(t_per).is_empty(), "le butin périmé rend sa tuile")
	var smax := s.souffle_max(j)
	s._tiquer_souffle(j.horloge, h.ticks)
	var pv0 := int(j.sante)
	s._tiquer_souffle(j.horloge, h.ticks + smax + 20)
	verifier(int(j.souffle) == 0 and int(j.sante) < pv0, "souffle épuisé après %d ticks : noyade (%d → %d)" % [smax, pv0, int(j.sante)])
	j["tags_acquis_race"] = ["respiration_aquatique"]
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	var pv1 := int(j.sante)
	s._tiquer_souffle(j.horloge, h.ticks + smax + 60)
	verifier(int(j.sante) == pv1, "respiration aquatique : plus de noyade")
	# Le Feu ne part pas sous l'eau
	var cap := Capacites.new(GameData.catalogues["modules"])
	verifier(s.wuxing.dominante(cap.assembler(["point", "etincelle"], 5, "1d4", {}).elements) == "feu", "Étincelle est du Feu")
	j.mana = 50
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "capacite", "index": 1, "cible": eau2}), "pas de Feu sous l'eau (Étincelle refusée)")
	# Surcharge : on ne peut pas entrer dans l'eau
	s.grille.liberer(j.pos)
	j.pos = eau - Vector2i(1, 0)
	s.grille.placer(j.id, j.pos)
	for k in 40:
		var o := s.generer_objet("proto_epee", 1, {}, "commun", 0)
		if not o.is_empty():
			j.sac.append(o.uid)
	verifier(s.poids_de(j).facteur > 1.0, "40 épées : surcharge (×%.2f)" % s.poids_de(j).facteur)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "deplacer", "vers": eau}), "trop chargé : refus d'entrer dans l'eau")
	# Le pathfinding sait ce que _deplacer refusera (Eau et liquides, 2026-08-31)
	verifier(s.refuse_nage(j), "refuse_nage : surchargé et non volant")
	verifier(s.grille.cout_pas(j.pos, eau, false, true) == -1, "eviter_nage : l'entrée terre → eau vaut −1")
	verifier(s.grille.cout_pas(eau, eau2, false, true) > 0, "eviter_nage : eau → eau reste libre")
	var ch_sec := s.grille.chemin(j.pos, eau2 + Vector2i(1, 0), false, "", true)
	var prev_n: Vector2i = j.pos
	var entre_dans_eau := false
	for pas_n in ch_sec:
		if s.dans_l_eau(pas_n) and not s.dans_l_eau(prev_n):
			entre_dans_eau = true
		prev_n = pas_n
	verifier(not ch_sec.is_empty() and not entre_dans_eau, "l'A* contourne l'eau au lieu de proposer un pas refusé")
	j.sac.clear()
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(not s.refuse_nage(j), "sac vidé : la nage redevient permise au chemin")


# ---------------------------------------------------------------- Le poison de lame est illégal

func test_neige_et_gel() -> void:
	var s := Simulation.new(144)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var eau: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.poser_contenu(eau, "eau")
	s.grille.hauteurs[s.grille.idx(eau)] = s.grille.h(j.pos)
	var plat: Vector2i = j.pos + Vector2i(0, 1)
	s.grille.contenu[s.grille.idx(plat)] = 0
	s.grille.hauteurs[s.grille.idx(plat)] = s.grille.h(j.pos)
	s.meteo_force = "clair"
	s.horloge_monde.ticks = int(s._cycle().ticks_par_jour) / 2
	s._maj_etats_meteo()
	var c_plat := s.grille.cout_pas(j.pos, plat)
	verifier(not s.grille.neige and s.grille.cout_pas(j.pos, eau) == 600, "ciel clair : pas de neige, l'eau se nage (600)")
	s.meteo_force = "blizzard"
	s._maj_etats_meteo()
	# Le coût est `round((base + surcout) / friction)` : le surcoût passe par la MÊME division que la base, et
	# avec des coûts à trois chiffres l'arrondi ne le cache plus (2026-09-08). On attend donc ce que la formule dit.
	var attendu_neige := roundi(float(int(s.regles.r.deplacement.cout_base) + int(s.regles.r.deplacement.neige_surcout)) * float(c_plat) / float(int(s.regles.r.deplacement.cout_base)))
	verifier(s.grille.neige and s.grille.cout_pas(j.pos, plat) == attendu_neige, "blizzard : la neige ralentit (%d → %d, attendu %d)" % [c_plat, s.grille.cout_pas(j.pos, plat), attendu_neige])
	verifier(s.temperature_cellule() < 0.0 and s.grille.gel and not s.dans_l_eau(eau) and s.grille.cout_pas(j.pos, eau) == attendu_neige, "−25 °C : la mer gèle, elle se marche (%.0f °C, coût %d)" % [s.temperature_cellule(), s.grille.cout_pas(j.pos, eau)])
	s.meteo_force = "canicule"
	s._maj_etats_meteo()
	verifier(not s.grille.gel and not s.grille.neige, "canicule : la glace fond")
	s.monde.fermer()


# ---------------------------------------------------------------- La nage et le souffle

func test_automate_eau() -> void:
	var s := Simulation.new(145)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Un lac (source) à 3 tuiles, une plaine plate entre les deux ; creuser une tranchée au bord : elle s'inonde.
	var base: Vector2i = j.pos + Vector2i(4, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(0, 8):
		for dy in range(-2, 3):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
	var lac: Vector2i = base + Vector2i(5, 0)
	var talus: Vector2i = lac + Vector2i(0, 1)
	s.grille.hauteurs[s.grille.idx(talus)] = h0 + 1   # un talus au bord du lac, posé avant que l'eau ne bouge
	s.grille.poser_contenu(lac, "eau")
	verifier(s.grille.niveau_liquide(lac) == 8 and s.eau_active.is_empty(), "une source au niveau 8, rien ne bouge tant qu'on n'y touche pas")
	var tranchee: Vector2i = lac + Vector2i(-1, 0)
	s._memoriser_terrain(tranchee)
	s.grille.hauteurs[s.grille.idx(tranchee)] = h0 - 1
	verifier(not s.eau_active.is_empty(), "creuser au bord réveille le lac")
	var tick := s.horloge_monde.ticks
	var per_eau := int(s.regles.r.eau.periode_ticks)   # l'automate ne tique qu'une fois par période (2026-09-08)
	for k in 10:
		s._tiquer_eau(tick + k * per_eau)
	verifier(s.grille.niveau_liquide(tranchee) == 7, "la tranchée (plus basse) s'inonde : niveau 7")
	var plat: Vector2i = lac + Vector2i(-2, 0)
	var loin: Vector2i = lac + Vector2i(-4, 0)
	verifier(s.grille.niveau_liquide(plat) > s.grille.niveau_liquide(loin) and s.grille.niveau_liquide(loin) > 0, "l'eau s'étale à plat en perdant un niveau par tuile (%d puis %d)" % [s.grille.niveau_liquide(plat), s.grille.niveau_liquide(loin)])
	verifier(s.grille.niveau_liquide(lac + Vector2i(-8, 0)) == 0, "et s'arrête au bout de sa portée")
	verifier(s.grille.niveau_liquide(talus) == 0, "le talus (plus haut) endigue")
	# La pluie remplit un creux d'un niveau
	var creux: Vector2i = j.pos + Vector2i(-3, 0)
	for dd in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		s.grille.contenu[s.grille.idx(creux + dd)] = 0
		s.grille.hauteurs[s.grille.idx(creux + dd)] = h0
	s.grille.hauteurs[s.grille.idx(creux)] = h0 - 2
	var avant := s.grille.niveau_liquide(creux)
	var g1 := s._pluie_sur(creux)
	var g2 := s._pluie_sur(creux)
	verifier(avant == 0 and g1 and not g2 and s.grille.niveau_liquide(creux) == 1, "la pluie remplit le creux d'un niveau, jamais plus (%d)" % s.grille.niveau_liquide(creux))
	verifier(not s._pluie_sur(creux + Vector2i(1, 0)), "une tuile qui n'est pas un creux ne prend pas la pluie")
	s.monde.fermer()


# ---------------------------------------------------------------- Neige et gel

func test_foudre() -> void:
	var s := Simulation.new(146)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var base: Vector2i = j.pos + Vector2i(6, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(-3, 12):
		for dy in range(-3, 4):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
	# Une mare d'eau douce : une ligne d'écoulement de 7 tuiles
	for dx in range(0, 7):
		s.grille.poser_contenu(base + Vector2i(dx, 0), "eau_ecoulement")
		s.grille.niveau_eau[s.grille.idx(base + Vector2i(dx, 0))] = 7 - dx
	var dans_eau := s.ajouter("loup", base + Vector2i(4, 0), "ia")
	var loin_eau := s.ajouter("loup", base + Vector2i(6, 0), "ia")   # à 6 : au-delà du rayon 5 de l'eau douce
	var terre := s.ajouter("loup", base + Vector2i(3, 2), "ia")   # sur la terre, à 2 : hors zone
	var voisin := s.ajouter("loup", base + Vector2i(-1, 1), "ia")   # voisin diagonal de l'impact : zone
	var pv := [int(dans_eau.sante), int(loin_eau.sante), int(terre.sante), int(voisin.sante)]
	s._frapper_foudre(base)
	verifier(int(dans_eau.sante) < pv[0], "la foudre court dans l'eau : le loup à 4 tuiles dans la mare est touché (%d → %d)" % [pv[0], int(dans_eau.sante)])
	verifier(int(loin_eau.sante) == pv[1], "à 6 tuiles, au-delà du rayon 5 de l'eau douce : rien")
	verifier(int(terre.sante) == pv[2], "sur la terre à 2 tuiles : rien")
	verifier(int(voisin.sante) < pv[3], "le voisin de l'impact prend la zone")
	# La glace ne conduit pas
	dans_eau.sante = dans_eau.sante_max
	s.grille.gel = true
	s._frapper_foudre(base)
	verifier(int(dans_eau.sante) == int(dans_eau.sante_max), "sur la glace, la foudre ne court pas")
	s.grille.gel = false
	# Une source (la mer) conduit à 8
	s.grille.poser_contenu(base, "eau")
	loin_eau.sante = loin_eau.sante_max
	s._frapper_foudre(base)
	verifier(int(loin_eau.sante) < int(loin_eau.sante_max), "depuis une source (eau salée) : rayon 8, le loup à 6 est touché")
	# Le paratonnerre émergent : la foudre vise le point haut
	var mat: Vector2i = base + Vector2i(2, -2)
	s.grille.hauteurs[s.grille.idx(mat)] = h0 + 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	s.regles.r.eau["foudre_portee_joueur"] = 1   # candidates dans le carré 3×3 autour du point haut
	var cible := s._cible_foudre(rng, mat)
	verifier(cible == mat, "la foudre vise le point haut (%s, h %d)" % [str(cible - mat), s.grille.h(cible)])
	s.monde.fermer()


func test_retrait_eau() -> void:
	var s := Simulation.new(147)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var base: Vector2i = j.pos + Vector2i(4, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(0, 8):
		for dy in range(-2, 3):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
	var lac: Vector2i = base + Vector2i(5, 0)
	s.grille.poser_contenu(lac, "eau")
	var tranchee: Vector2i = lac + Vector2i(-1, 0)
	s.grille.hauteurs[s.grille.idx(tranchee)] = h0 - 1
	s.eau_active[s.grille.idx(lac)] = true
	var per_eau2 := int(s.regles.r.eau.periode_ticks)
	var tick := 2 * per_eau2
	for k in 12:
		s._tiquer_eau(tick + k * per_eau2)
	var plat: Vector2i = lac + Vector2i(1, 0)
	verifier(s.grille.niveau_liquide(tranchee) == 7 and s.grille.niveau_liquide(plat) == 7, "la nappe est en place (tranchée 7, plat 7)")
	# Persistance du niveau avec la cellule
	s.monde.capturer(s.grille)
	var m: Dictionary = s.monde.modifications.get(s.monde.cellule_de(plat), {}).get(s.monde.idx_local(plat), {})
	verifier(int(m.get("eau", 0)) == 7, "le niveau d'un écoulement est mémorisé avec la cellule (%d)" % int(m.get("eau", 0)))
	# La source comblée : la nappe à plat se retire, la tranchée (un creux) garde son eau
	s._retirer_source(lac)
	for k in 400:   # la nappe se rétracte de proche en proche : lentement
		s._tiquer_eau(tick + (12 + k) * per_eau2)
	verifier(s.grille.niveau_liquide(lac) == 0, "la source comblée a disparu")
	verifier(s.grille.niveau_liquide(plat) == 0 and s.grille.niveau_liquide(lac + Vector2i(3, 0)) == 0, "la nappe à plat s'est retirée (%d, %d)" % [s.grille.niveau_liquide(plat), s.grille.niveau_liquide(lac + Vector2i(3, 0))])
	verifier(s.grille.niveau_liquide(tranchee) == 7, "la tranchée, un creux, garde son eau (%d)" % s.grille.niveau_liquide(tranchee))
	# La canicule évapore la flaque du creux, un niveau par heure
	s._evaporation()
	verifier(s.grille.niveau_liquide(tranchee) == 6, "la canicule évapore d'un niveau (%d)" % s.grille.niveau_liquide(tranchee))
	for k in 8:
		s._evaporation()
	verifier(s.grille.niveau_liquide(tranchee) == 0, "sept heures de canicule plus tard, la tranchée est sèche")
	# Élever une tuile d'écoulement la comble
	s.grille.poser_contenu(plat, "eau_ecoulement")
	s.grille.niveau_eau[s.grille.idx(plat)] = 3
	s.grille.hauteurs[s.grille.idx(plat)] = h0 + 1
	s._retirer_eau(plat, true)
	verifier(s.grille.niveau_liquide(plat) == 0 and not s.grille.niveau_eau.has(s.grille.idx(plat)), "une tuile d'écoulement élevée est comblée")
	s.monde.fermer()


func test_compagnons_postures() -> void:
	var s := Simulation.new(148)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var comp := s.ajouter("villageois", j.pos + Vector2i(0, 1), "ia")
	s._habiller_pnj(comp, GameData.entree("creatures", "villageois"))
	s._devenir_compagnon(j, comp)
	var loup := s.ajouter("loup", j.pos + Vector2i(4, 1), "ia")
	var profil: Dictionary = GameData.entree("ai_profiles", "compagnon")
	var tick := s.tick_de(comp)
	# Défensive par défaut : une cible proche du maître se poursuit
	var c := s._actions_candidates(comp, loup, profil, tick)
	verifier(c.has("poursuivre") and not c.get("attaquer", {}).has("posture_agressive"), "défensive : il poursuit une cible proche du maître, sans zèle")
	loup.pos = j.pos + Vector2i(9, 0)
	c = s._actions_candidates(comp, loup, profil, tick)
	verifier(not c.has("poursuivre"), "défensive : il ne poursuit pas une cible à 9 tuiles du maître")
	# Agressive
	verifier(s.ordonner(j, comp.id, "agressive") and str(comp.posture) == "agressive", "ordre : posture agressive, sans tick")
	c = s._actions_candidates(comp, loup, profil, tick)
	verifier(c.has("poursuivre") and float(c.poursuivre.get("posture_agressive", 0.0)) == 1.0, "agressive : il poursuit, considération posture_agressive")
	# Évite
	loup.pos = j.pos + Vector2i(3, 0)
	s.ordonner(j, comp.id, "eviter")
	c = s._actions_candidates(comp, loup, profil, tick)
	verifier(not c.has("attaquer") and not c.has("poursuivre") and float(c.get("fuir", {}).get("eviter", 0.0)) == 1.0, "évite : ni attaque ni poursuite, il fuit la menace à 3 tuiles")
	verifier(not s.ordonner(j, comp.id, "charger"), "un ordre inconnu est refusé")
	# Consignes de combat : désigner une cible, repli
	var loup2 := s.ajouter("loup", j.pos + Vector2i(-3, 0), "ia")
	s.ordonner(j, comp.id, "defensive")
	verifier(s.designer_cible(j, loup2.id) and str(comp.cible) == loup2.id and str(comp.cible_prioritaire) == loup2.id, "désigner un loup : le compagnon le prend pour cible")
	comp.cible = loup.id
	verifier(str(s._chercher_cible(comp, tick).get("id", "")) == loup2.id, "la cible désignée passe devant une autre")
	verifier(not s.designer_cible(j, comp.id), "on ne désigne pas un allié")
	verifier(s.ordonner(j, comp.id, "repli") and str(comp.ordre) == "suivre" and str(comp.posture) == "eviter" and comp.cible.is_empty() and not comp.has("cible_prioritaire"), "repli : suis-moi, évite, cible oubliée")
	# Retour à la base : l'ancre au centre de la cellule du camp
	verifier(s.ordonner(j, comp.id, "retour") and str(comp.ordre) == "attendre" and comp.ancre == s.grille.pos_de(s.grille.largeur * s.grille.hauteur_grille / 2), "retour à la base : attends ici, l'ancre au centre du camp")
	# Échange d'équipement : il s'équipe de ce qu'on lui donne, et le rend déséquipé
	var o := s.generer_objet("proto_epee", 1, {}, "commun", 0)
	if not s.items.has(str(o.get("uid", ""))):
		s.items[o.uid] = o
	if not (str(o.uid) in j.sac):
		j.sac.append(str(o.uid))
	var uid := str(o.uid)
	verifier(s.echanger(j, comp.id, uid, "donner") and not (uid in j.sac) and str(comp.equipement.get("main_principale", "")) == uid, "donner une épée : le compagnon s'en équipe")
	verifier(s.echanger(j, comp.id, uid, "reprendre") and (uid in j.sac) and not (uid in comp.sac) and str(comp.equipement.get("main_principale", "")) != uid, "reprendre : elle revient dans mon sac, déséquipée")
	verifier(not s.echanger(j, loup.id, uid, "donner"), "on n'échange qu'avec ses compagnons")
	s.monde.fermer()


func test_cueillette() -> void:
	# Les données : chaque plante de cueillette existe, et sa silhouette aussi
	var manque := 0
	for bid in GameData.catalogues.biomes.keys():
		for cu in GameData.catalogues.biomes[bid].get("cueillette", []):
			if not GameData.catalogues.plants.has(str(cu.id)) or not GameData.catalogues.vegetaux.has(str(cu.id)) or not GameData.catalogues.items.has(str(cu.id)):
				manque += 1
	verifier(manque == 0, "chaque plante de cueillette a sa fiche, sa silhouette et son consommable")
	var s := Simulation.new(149)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var t: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.contenu[s.grille.idx(t)] = 0
	s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	verifier(not s.intention(j.id, {"type": "cueillir", "vers": t}), "rien à cueillir sur du sol nu")
	s.grille.poser_contenu(t, "plante_sauvage")
	s.grille.materiaux[s.grille.idx(t)] = "framboisier"
	var avant: int = j.sac.size()
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "cueillir", "vers": t}), "cueillir un framboisier adjacent")
	var n: int = j.sac.size() - avant
	verifier(n >= 1 and n <= 2, "cueillette sauvage : 1d2 au niveau 0 de Collecte (%d)" % n)
	verifier(s.grille.contenu_de(t).is_empty() and s.modifs_terrain.has(t), "la tuile redevient du sol, mémorisée pour repousser")
	s.monde.fermer()


func test_affixes_reveilles() -> void:
	var s := Simulation.new(150)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(not s.affixes_defs.cond_nuit.inerte and not s.affixes_defs.cond_corruption.inerte and not s.affixes_defs.cond_mana.inerte and not s.affixes_defs.meca_capacite.inerte, "quatre affixes ne sont plus inertes")
	# Du porteur : +kg de capacité
	var cap0 := float(s.poids_de(j).capacite)
	s.items["anneau_p"] = {"uid": "anneau_p", "name_key": "x", "type": "bijou", "equip_slot": "anneau", "affixes": [{"id": "meca_capacite", "params": {"kg": 20}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["anneau_1"] = "anneau_p"
	s.items["amu_p"] = {"uid": "amu_p", "name_key": "x", "type": "bijou", "equip_slot": "amulette", "affixes": [{"id": "meca_capacite", "params": {"kg": 10}, "compteur": 0, "etat": {}}, {"id": "cond_mana", "params": {"pct": 20}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["amulette"] = "amu_p"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(float(s.poids_de(j).capacite) == cap0 + 30.0, "du porteur : +20 et +10 de capacité cumulés (%.0f → %.0f)" % [cap0, float(s.poids_de(j).capacite)])
	# Nocturne : la nuit, un pas coûte moins
	s.items["casque_n"] = {"uid": "casque_n", "name_key": "x", "type": "armure", "equip_slot": "casque", "affixes": [{"id": "cond_nuit", "params": {"pct": 20}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["casque"] = "casque_n"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.horloge_monde.ticks = int(s._cycle().ticks_par_jour) / 2
	verifier(not s.est_nuit() and s.cout_pas_affixes(j, 10) == 10, "le jour : un pas de 10 reste 10")
	s.horloge_monde.ticks = 0
	verifier(s.est_nuit() and s.cout_pas_affixes(j, 10) == 8, "la nuit : 10 → 8 (−20 %)")
	# Des sources : la densité de mana du lieu
	var dm := s.densite_mana(j.pos)
	var m := s.mult_mana_sources(j)
	verifier((dm >= 0.6 and is_equal_approx(m, 0.8)) or (dm < 0.6 and m == 1.0), "des sources : densité %.2f → coût ×%.2f" % [dm, m])
	# Du danger : la corruption du lieu
	var arme := {"uid": "epee_d", "name_key": "x", "type": "arme", "equip_slot": "main_principale", "functionality": "epee", "affixes": [{"id": "cond_corruption", "params": {"seuil": 40, "pct": 30}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	s.items["epee_d"] = arme
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	var corr := s.corruption_ici(j.pos)
	var r := s._affixes_offensifs(j, arme, loup)
	verifier((corr >= 40.0 and is_equal_approx(float(r.mult), 1.3)) or (corr < 40.0 and is_equal_approx(float(r.mult), 1.0)), "du danger : corruption %.0f → ×%.2f" % [corr, float(r.mult)])
	s.donjon = {"corruption": 90, "etage": 1}
	s.lieu = "donjon"
	r = s._affixes_offensifs(j, arme, loup)
	verifier(is_equal_approx(float(r.mult), 1.3), "en donjon corrompu (90) : ×1,30")
	s.lieu = "camp"
	s.donjon = {}
	s.monde.fermer()


## LE CHAMP D'ODEUR (l'autre moitié de « le bruit et l'odeur », que le designer met en tête de ses six).
## **Il est l'exact contraire du champ sonore** : le son dit où quelqu'un EST, l'odeur dit où quelqu'un est PASSÉ.
## **Ce test doit prouver le point de conception qui fait tout marcher** : une piste laissée au fil du temps décroît
## vers l'ancien, donc remonter la pente mène au dépôt le plus FRAIS — le pistage sans horodatage.
func test_odeur() -> void:
	var cfg: Dictionary = GameData.config("odeur")
	verifier(not cfg.is_empty() and float(cfg.trace_par_pas) > 0.0, "les réglages de l'odeur sont en données (trace %.0f, fondu %.2f)" % [float(cfg.trace_par_pas), float(cfg.fondu)])
	verifier(float(cfg.fondu) < float(GameData.config("sonore").fondu), "et une odeur s'efface BIEN moins vite qu'un bruit (%.2f contre %.2f) — l'une traîne, l'autre passe" % [float(cfg.fondu), float(GameData.config("sonore").fondu)])
	var s := Simulation.new(611)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var g := s.grille
	var c: Vector2i = Grille.plat(j.pos) + Vector2i(0, 20)

	# UNE PISTE : cinq dépôts successifs, un pas de champ entre chacun. Le plus ancien s'est effacé le plus.
	var chemin: Array[Vector2i] = []
	for k in 5:
		var t: Vector2i = c + Vector2i(k, 0)
		if not g.dans(t):
			continue
		chemin.append(t)
		SimTerrain.sentir(s, t, float(cfg.trace_par_pas))
		s.odeur_prochain_pas = 0
		s._tiquer_odeur(100 + k * 10)
	verifier(chemin.size() == 5, "cinq pas déposés")
	var croissante := true
	for k2 in range(1, chemin.size()):
		if s.odeur_a(chemin[k2]) <= s.odeur_a(chemin[k2 - 1]):
			croissante = false
	verifier(croissante, "LA PISTE DÉCROÎT VERS L'ANCIEN : %.1f → %.1f du premier pas au dernier — aucun horodatage n'a été nécessaire" % [s.odeur_a(chemin[0]), s.odeur_a(chemin[4])])

	# REMONTER LA PENTE MÈNE AU PLUS FRAIS, c'est-à-dire là où l'être vient d'aller. C'est tout le pistage.
	var depuis: Vector2i = chemin[1]
	var pas: Vector2i = SimTerrain.vers_l_odeur(s, depuis)
	verifier(pas.x > -9000 and pas.x > depuis.x, "remonter la pente va vers le dépôt le plus frais (%s → %s)" % [str(depuis), str(pas)])

	# UNE ODEUR TRAÎNE : après le même nombre de pas de champ qui efface complètement un bruit, elle est encore là.
	var reste0 := s.odeur_a(chemin[4])
	for k3 in 12:
		s.odeur_prochain_pas = 0
		s._tiquer_odeur(300 + k3 * 10)
	verifier(s.odeur_a(chemin[4]) > 0.0, "douze pas plus tard, la piste est encore là (%.1f → %.1f) là où un bruit s'était éteint" % [reste0, s.odeur_a(chemin[4])])

	# LA DISCRÉTION PÂLIT LA TRACE : se cacher n'est plus un facteur sur une portée, c'est une piste plus faible.
	var s2 := Simulation.new(612)
	s2.charger_camp()
	var j2: Dictionary = s2.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var t_a: Vector2i = Grille.plat(j2.pos) + Vector2i(0, 24)
	var t_b: Vector2i = Grille.plat(j2.pos) + Vector2i(4, 24)
	var bruyant := {"competences_eff": {}}
	var furtif := {"competences_eff": {"discretion": 8}}
	SimTerrain.tracer(s2, bruyant, t_a)
	SimTerrain.tracer(s2, furtif, t_b)
	s2.odeur_prochain_pas = 0
	s2._tiquer_odeur(100)
	verifier(s2.odeur_a(t_a) > s2.odeur_a(t_b) and s2.odeur_a(t_b) > 0.0, "un rôdeur discret laisse une piste plus pâle (%.1f contre %.1f)" % [s2.odeur_a(t_b), s2.odeur_a(t_a)])

	# QUI A UN NEZ EST EN DONNÉES, et une dépouille sent tant qu'elle est là.
	var fl: Dictionary = cfg.get("flair", {})
	verifier(not (fl.get("tags", []) as Array).is_empty(), "les tags qui ont un nez sont en données (%s)" % str(fl.tags))
	var mort := s2.vivants().filter(func(e: Dictionary) -> bool: return e.controle != "joueur")
	if not mort.is_empty():
		var m: Dictionary = mort[0]
		m.vivant = false
		s2.odeur_prochain_pas = 0
		s2._tiquer_odeur(200)
		var o_mort := s2.odeur_a(m.pos)
		for k4 in 10:
			s2.odeur_prochain_pas = 0
			s2._tiquer_odeur(300 + k4 * 10)
		verifier(o_mort > 0.0 and s2.odeur_a(m.pos) > 0.0, "une dépouille sent, et elle sent ENCORE dix pas plus tard : son odeur est réémise, elle ne s'éteint pas d'un coup (%.1f puis %.1f)" % [o_mort, s2.odeur_a(m.pos)])


## LE CHAMP SONORE (ordre de travail 26, 2026-09-09 ; le designer l'a nommé `sonore` le même jour). Le son ne se
## propage pas en ligne droite comme la vue : il suit le plus court chemin SONORE, contourne, et se fait manger par
## l'`absorption` de ce qu'il traverse.
## **Le contrôle négatif est particulièrement net ici** : on écoute à la MÊME distance de la MÊME source, des deux
## côtés d'un couloir de même géométrie, et l'on ne change QUE la matière du mur.
func test_sonore() -> void:
	var cfg: Dictionary = GameData.config("sonore")
	verifier(not cfg.is_empty() and float(cfg.pas_cout) > 0.0, "les réglages du champ sonore sont en données (%.0f par tuile, seuil %.0f)" % [float(cfg.pas_cout), float(cfg.seuil_audible)])
	var mats: Dictionary = GameData.catalogues.materials
	verifier(int(mats.granit.stats.absorption) > int(mats.verre.stats.absorption) * 2, "le granit étouffe bien plus que le verre (%d contre %d)" % [int(mats.granit.stats.absorption), int(mats.verre.stats.absorption)])
	verifier(int(mats.laine.stats.absorption) > int(mats.granit.stats.absorption) and int(mats.acier.stats.absorption) < int(mats.granit.stats.absorption), "et la laine étouffe mieux que la pierre, l'acier moins bien (%d, %d, %d) — ce que `durete` n'aurait jamais dit" % [int(mats.laine.stats.absorption), int(mats.granit.stats.absorption), int(mats.acier.stats.absorption)])
	var s := Simulation.new(610)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var g := s.grille
	var c: Vector2i = Grille.plat(j.pos) + Vector2i(0, 14)

	# Un couloir clos de 21 tuiles, la source au milieu, et un mur qui coupe le côté gauche à une tuile d'elle.
	var _batir := func(matiere: String) -> void:
		for dx in range(-11, 12):
			for dy in range(-1, 2):
				var t: Vector2i = c + Vector2i(dx, dy)
				if not g.dans(t):
					continue
				if dy == 0 and dx > -11 and dx < 11:
					g.contenu[g.idx(t)] = 0
					g.materiaux.erase(g.idx(t))
				else:
					g.poser_contenu(t, "mur")
					g.materiaux[g.idx(t)] = "granit"
		# LE MUR DE SÉPARATION, en la matière qu'on teste — DEUX tuiles d'épaisseur, et c'est une leçon de test :
		# avec une seule, le granit laissait passer exactement 5,0, c'est-à-dire PILE le seuil d'audibilité. La
		# physique était juste ; le test tenait en équilibre sur un fil, et un fil se rompt au premier réglage.
		for dy in range(-1, 2):
			for dx2 in [-1, -2]:
				var m: Vector2i = c + Vector2i(dx2, dy)
				if g.dans(m):
					g.poser_contenu(m, "mur")
					g.materiaux[g.idx(m)] = matiere
	var droite: Vector2i = c + Vector2i(10, 0)    # à dix tuiles, en terrain libre
	var gauche: Vector2i = c + Vector2i(-10, 0)   # à dix tuiles AUSSI, mais derrière le mur

	# 1. UN MUR DE GRANIT. On entend à droite, pas à gauche.
	_batir.call("granit")
	SimTerrain.sonner(s, c, float(cfg.volumes.pioche))
	s.sonore_prochain_pas = 0
	s._tiquer_sonore(100)
	var d1 := s.sonore_a(droite)
	var g1 := s.sonore_a(gauche)
	verifier(d1 > 0.0, "à dix tuiles en terrain libre, on entend le coup de pioche (%.1f)" % d1)
	verifier(g1 <= 0.0, "à dix tuiles DE L'AUTRE CÔTÉ, le mur de granit l'étouffe (%.1f)" % g1)

	# 2. LE MÊME MUR EN VERRE. Même géométrie, même distance, même source : on entend.
	s.carte_sonore.fill(0.0)
	s.sonore_actif.clear()
	s.sonore_sources.clear()
	_batir.call("verre")
	SimTerrain.sonner(s, c, float(cfg.volumes.pioche))
	s.sonore_prochain_pas = 0
	s._tiquer_sonore(200)
	var d2 := s.sonore_a(droite)
	var g2 := s.sonore_a(gauche)
	verifier(is_equal_approx(d2, d1), "à droite, rien n'a changé (%.1f)" % d2)
	verifier(g2 > 0.0, "MAIS DERRIÈRE LE VERRE, on entend — seule la matière du mur a changé (%.1f contre %.1f)" % [g2, g1])

	# 3. LA PENTE MÈNE À LA SOURCE. C'est tout ce qu'il faut à une bête : elle n'a pas à savoir ce qu'elle a entendu.
	var pas: Vector2i = SimTerrain.vers_le_bruit(s, droite)
	verifier(pas.x > -9000 and Grille.distance(pas, c) < Grille.distance(droite, c), "la pente du champ mène vers la source (%s → %s)" % [str(droite), str(pas)])

	# 4. LE SON CONTOURNE : on perce le mur de granit, et ce qui était inaudible s'entend par l'ouverture.
	s.carte_sonore.fill(0.0)
	s.sonore_actif.clear()
	s.sonore_sources.clear()
	_batir.call("granit")
	for dx3 in [-1, -2]:   # on perce les deux tuiles du mur
		var trou: Vector2i = c + Vector2i(dx3, 0)
		g.contenu[g.idx(trou)] = 0
		g.materiaux.erase(g.idx(trou))
	SimTerrain.sonner(s, c, float(cfg.volumes.pioche))
	s.sonore_prochain_pas = 0
	s._tiquer_sonore(300)
	verifier(s.sonore_a(gauche) > 0.0, "une ouverture dans le mur, et le son passe par elle : il contourne (%.1f)" % s.sonore_a(gauche))

	# 5. LE COMBAT SONNE (2026-09-09). Les volumes du coup, de la mort et de la porte étaient écrits dans les
	#    données et n'avaient AUCUN émetteur : une bataille était muette pour l'IA. On le vérifie là où ça compte —
	#    sur le passage obligé de tous les dégâts, quelle que soit leur source.
	s.carte_sonore.fill(0.0)
	s.sonore_actif.clear()
	s.sonore_sources.clear()
	var cible_c: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle != "joueur")[0]
	s._appliquer_degats(cible_c, 3, "", {"type": "contondant", "element": {}})
	s.sonore_prochain_pas = 0
	s._tiquer_sonore(500)
	var apres_coup := s.sonore_a(cible_c.pos)
	verifier(apres_coup > 0.0, "un coup s'entend là où il tombe (%.1f) — le volume était écrit et n'avait aucun émetteur" % apres_coup)
	s.carte_sonore.fill(0.0)
	s.sonore_actif.clear()
	s.sonore_sources.clear()
	s._appliquer_degats(cible_c, int(cible_c.sante) + 50, "", {"type": "contondant", "element": {}})
	s.sonore_prochain_pas = 0
	s._tiquer_sonore(600)
	verifier(not cible_c.vivant and s.sonore_a(cible_c.pos) > apres_coup, "et un cri porte plus loin qu'un coup (%.1f contre %.1f)" % [s.sonore_a(cible_c.pos), apres_coup])

	# 6. LE BRUIT S'EFFACE : un pas de champ sans source, et il ne reste plus rien d'audible. On repart d'une carte
	#    propre, puisque le combat vient d'y écrire.
	s.carte_sonore.fill(0.0)
	s.sonore_actif.clear()
	s.sonore_sources.clear()
	SimTerrain.sonner(s, c, float(cfg.volumes.pioche))
	s.sonore_prochain_pas = 0
	s._tiquer_sonore(700)
	var avant := s.sonore_a(droite)
	for k in 12:
		s.sonore_prochain_pas = 0
		s._tiquer_sonore(400 + k * 10)
	verifier(s.sonore_a(droite) <= 0.0, "un bruit ne dure pas : il s'efface (%.1f puis %.1f)" % [avant, s.sonore_a(droite)])


## LE CHAMP DE SUPPORT (ordre de travail 25, 2026-09-09) — l'effondrement, « la seule chose qui sépare une mine d'un
## gouffre ». Une tuile ouverte est couverte d'un plafond que la roche alentour tient ; la `portance` de cette roche
## dit jusqu'où il porte, et au-delà il tombe.
## **La preuve est un contrôle négatif**, comme pour la fusion : voir une galerie s'effondrer ne prouverait rien — une
## règle « toute galerie de rayon 3 tombe » le ferait aussi. Le test creuse donc DEUX FOIS la même galerie, au même
## endroit, à la même taille, et ne change QUE la matière de l'étage.
func test_support() -> void:
	var cfg: Dictionary = GameData.config("support")
	verifier(not cfg.is_empty() and float(cfg.portee_par_portance) > 0.0, "les réglages du support sont en données (portée %.1f + %.2f par point)" % [float(cfg.portee_base), float(cfg.portee_par_portance)])
	var mats: Dictionary = GameData.catalogues.materials
	verifier(int(mats.granit.stats.portance) > int(mats.terre.stats.portance) * 4, "le granit porte bien plus que la terre (%d contre %d)" % [int(mats.granit.stats.portance), int(mats.terre.stats.portance)])
	var s := Simulation.new(608)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	s.monde.claims[s.monde.cellule_de(j.pos)] = {"role": "base"}
	j.vigueur = int(j.vigueur_max)
	verifier(s.creuser_un_puits(j, 0), "le puits s'ouvre : on est dans une mine")
	verifier(bool(s.donjon.get("mine", false)), "l'étage est bien une mine — le champ ne s'applique nulle part ailleurs")

	# La galerie : un disque de rayon 3 autour d'un point, creusé À LA MAIN pour que la mesure soit exacte.
	var centre: Vector2i = j.pos + Vector2i(12, 0)
	var _ouvrir := func(rayon: int) -> void:
		for dy in range(-rayon, rayon + 1):
			for dx in range(-rayon, rayon + 1):
				var q: Vector2i = centre + Vector2i(dx, dy)
				if s.grille.dans(q) and maxi(absi(dx), absi(dy)) <= rayon:
					s.grille.contenu[s.grille.idx(q)] = 0
					s.grille.materiaux.erase(s.grille.idx(q))
	var _plein := func() -> void:
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				var q: Vector2i = centre + Vector2i(dx, dy)
				if s.grille.dans(q):
					s.grille.poser_contenu(q, "mur")
		s.support_a_verifier.clear()
	var _ouvert := func(t: Vector2i) -> bool:
		return not s.grille.contenu_de(t).get("bloque_passage", false)

	# 1. DANS LE GRANIT (portance 85, portée 6,1) : le centre est à 4 tuiles de la roche, la galerie tient.
	_plein.call()
	s.grille.materiau_defaut = "granit"
	_ouvrir.call(3)
	SimTerrain.support_reexaminer(s, centre)
	s.support_prochain_pas = 0
	s._tiquer_support(100)
	verifier(_ouvert.call(centre), "dans le granit, une galerie de rayon 3 tient (portée %.1f tuiles)" % (float(cfg.portee_base) + float(cfg.portee_par_portance) * float(mats.granit.stats.portance)))

	# 2. LA MÊME GALERIE DANS LA TERRE (portance 10, portée 1,6) : le plafond tombe. Seule la matière a changé.
	_plein.call()
	s.grille.materiau_defaut = "terre"
	_ouvrir.call(3)
	SimTerrain.support_reexaminer(s, centre)
	s.support_prochain_pas = 0
	s._tiquer_support(200)
	verifier(not _ouvert.call(centre), "LA MÊME galerie dans la terre s'effondre — la portée vient de la fiche, pas du code (portée %.1f)" % (float(cfg.portee_base) + float(cfg.portee_par_portance) * float(mats.terre.stats.portance)))
	verifier(s.grille.contenu_de(centre).get("tags", []).has("destructible"), "ce que l'éboulement pose se rouvre à la pioche : la galerie n'est pas perdue")

	# 3. UN ÉTAI, ET ELLE TIENT. Étayer est un geste : l'étai ne bloque pas le passage et porte le plafond.
	_plein.call()
	s.grille.materiau_defaut = "terre"
	_ouvrir.call(3)
	s.grille.poser_meuble(s.grille.idx(centre), "etai")
	SimTerrain.support_reexaminer(s, centre)
	s.support_prochain_pas = 0
	s._tiquer_support(300)
	var voisin: Vector2i = centre + Vector2i(1, 0)
	verifier(_ouvert.call(voisin), "un étai au milieu tient le plafond de sa voisine (%s)" % str(voisin))
	verifier(not GameData.entree("meubles", "etai").get("bloque_passage", true), "et l'étai ne ferme pas la galerie : on marche entre ses montants")


## LA TROISIÈME DIMENSION (designer 2026-09-09 : « fais le nécessaire alors »). Le modèle disait « et se propage à ce
## qu'elle portait » ; le champ ne connaissait qu'une couche. Ce test bâtit une maison de deux étages à la main, abat
## les murs du rez-de-chaussée, et regarde tomber ce qu'ils portaient.
func test_support_etages() -> void:
	var cfg: Dictionary = GameData.config("support")
	var s := Simulation.new(609)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var g := s.grille
	g.poser_couches(3)
	g.materiau_defaut = "granit"   # portée 6,1 : la pièce tient largement tant que ses murs sont debout
	verifier(g.couches >= 3, "la fenêtre porte trois couches : le sol et deux étages")

	# Une pièce de 5 × 5 : des murs sur son pourtour aux couches 1 ET 2, un plancher libre au milieu de chacune.
	var coin: Vector2i = Grille.plat(j.pos) + Vector2i(10, 10)
	var centre1: Vector2i = Grille.en_couche(coin + Vector2i(2, 2), 1)
	var centre2: Vector2i = Grille.en_couche(coin + Vector2i(2, 2), 2)
	for z in [1, 2]:
		for y in 5:
			for x in 5:
				var t: Vector2i = Grille.en_couche(coin + Vector2i(x, y), z)
				if not g.dans(t):
					continue
				var bord: bool = (x == 0 or y == 0 or x == 4 or y == 4)
				g.poser_contenu(t, "mur_construit" if bord else "vide")
				if bord:
					g.materiaux[g.idx(t)] = "granit"
				else:
					g.contenu[g.idx(t)] = 0   # le plancher : une tuile où l'on marche
	# Les murs du REZ-DE-CHAUSSÉE : ce sont eux qui portent l'étage 1. Et l'INTÉRIEUR du rez-de-chaussée est vidé
	# explicitement : le terrain du camp y met parfois un arbre ou un rocher, qui sont pleins — le plancher du
	# dessus se serait trouvé porté PAR EN DESSOUS, et la maison abattue serait restée debout pour une raison juste
	# mais étrangère à ce qu'on mesure. (C'est ce qui a fait rougir ce test au premier essai.)
	for y in 5:
		for x in 5:
			var t0: Vector2i = coin + Vector2i(x, y)
			if not g.dans(t0):
				continue
			if x == 0 or y == 0 or x == 4 or y == 4:
				g.poser_contenu(t0, "mur_construit")
				g.materiaux[g.idx(t0)] = "granit"
			else:
				g.contenu[g.idx(t0)] = 0
				g.materiaux.erase(g.idx(t0))

	# 1. LA MAISON DEBOUT : rien ne tombe. Le contrôle négatif est ici — c'est la même géométrie qu'au point 2.
	SimTerrain.support_reexaminer(s, Grille.en_couche(coin + Vector2i(2, 2), 0))
	s.support_prochain_pas = 0
	s._tiquer_support(100)
	var _ouvert := func(t: Vector2i) -> bool: return not g.contenu_de(t).get("bloque_passage", false)
	verifier(_ouvert.call(centre1) and _ouvert.call(centre2), "la maison debout : les deux planchers tiennent")

	# 2. ON ABAT LES MURS DU BAS. Les murs du haut ne reposent plus sur rien, les planchers non plus.
	for y in 5:
		for x in 5:
			var t0: Vector2i = coin + Vector2i(x, y)
			if g.dans(t0) and (x == 0 or y == 0 or x == 4 or y == 4):
				g.contenu[g.idx(t0)] = 0
				g.materiaux.erase(g.idx(t0))
				SimTerrain.support_reexaminer(s, t0)
	for k in 6:   # plusieurs pas : un pan qui tombe en met d'autres en question — c'est la propagation
		s.support_prochain_pas = 0
		s._tiquer_support(200 + k * 10)
	verifier(not _ouvert.call(centre1), "les murs du bas abattus, le plancher du premier étage cède")
	verifier(not _ouvert.call(centre2), "ET CELUI DU SECOND AVEC — l'effondrement se propage à ce que le pan portait")
	var murs_debout := 0
	for y in 5:
		for x in 5:
			var t2: Vector2i = Grille.en_couche(coin + Vector2i(x, y), 2)
			if g.dans(t2) and "solide" in g.contenu_de(t2).get("tags", []):
				murs_debout += 1
	verifier(murs_debout == 0, "et il ne reste pas un mur du second en l'air (%d debout)" % murs_debout)
	verifier(int(cfg.get("composante_max", 0)) > 0, "la borne du parcours de groupe est en données (%d tuiles)" % int(cfg.get("composante_max", 0)))


## LA FUSION (ordre de travail 23, 2026-09-09) — la chaleur ne sait plus seulement BRÛLER. Une matière change d'état
## quand la chaleur atteint SON point de fusion, lu sur sa fiche en degrés réels : le gypse rend du plâtre à 150 °C,
## le calcaire de la chaux à 825, la malachite son cuivre à 200, l'hématite tient jusqu'à 1565.
## **La preuve qui compte est un contrôle négatif.** Voir un sol de gypse cuire à 400 °C ne prouverait rien — un seuil
## écrit en dur à 100 le ferait passer aussi. Ce test pose donc deux sols côte à côte et les chauffe à LA MÊME
## température : l'un cuit, l'autre pas. La différence ne peut venir que de la fiche.
func test_fusion() -> void:
	var s := Simulation.new(607)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var mats: Dictionary = GameData.catalogues.materials
	var fu: Dictionary = GameData.config("thermique").get("fusion", {})
	verifier(not fu.is_empty() and fu.has("sols") and fu.has("filons"), "ce que la matière DEVIENT est en données (%d sols, %d filons)" % [int(fu.get("sols", {}).size()), int(fu.get("filons", {}).size())])
	verifier(int(mats.gypse.stats.fusion) == 150 and int(mats.calcaire.stats.fusion) == 825, "les deux sols du test ont bien des points de fusion éloignés (gypse %d °C, calcaire %d °C)" % [int(mats.gypse.stats.fusion), int(mats.calcaire.stats.fusion)])
	verifier(int(mats.chene.stats.fusion) == 9999, "ce qui ne fond pas porte 9999, pas 0 — zéro est le point de fusion de la glace (chêne %d, glace %d)" % [int(mats.chene.stats.fusion), int(mats.glace.stats.fusion)])

	# 1. DEUX SOLS, LA MÊME CHALEUR. 400 °C passe le gypse (150) et pas le calcaire (825).
	var t_g: Vector2i = s._tuile_libre_autour(j.pos)
	var t_c: Vector2i = s._tuile_libre_autour(t_g)
	s.grille.sols[s.grille.idx(t_g)] = "gypse"
	s.grille.sols[s.grille.idx(t_c)] = "calcaire"
	s.grille.recompiler_sols()
	s.chauffer(t_g, 400.0)
	s.chauffer(t_c, 400.0)
	s.chaleur_prochain_pas = 0
	s._tiquer_chaleur(100)
	verifier(s.grille.materiau_sol(t_g) == "platre", "à 400 °C le gypse a cuit en plâtre (%s)" % s.grille.materiau_sol(t_g))
	verifier(s.grille.materiau_sol(t_c) == "calcaire", "à LA MÊME température le calcaire n'a pas bougé — le seuil vient de la fiche, pas du code (%s)" % s.grille.materiau_sol(t_c))

	# 2. LE CALCAIRE CUIT QUAND ON L'AMÈNE À SON SEUIL À LUI — ici la température d'une coulée de lave (1150 °C).
	#    900 °C ne suffisait PAS, et c'est instructif : la diffusion tourne AVANT les consommateurs, si bien qu'une
	#    tuile posée à 900 au milieu de l'ambiante retombe à ~720 dans le même pas. Ce qui compte est la chaleur
	#    qu'une tuile GARDE, pas celle qu'on y verse.
	s.chauffer(t_c, 1150.0)
	s.chaleur_prochain_pas = 0
	s._tiquer_chaleur(200)
	verifier(s.grille.materiau_sol(t_c) == "chaux", "à la chaleur d'une coulée le calcaire devient de la chaux (%s, %.0f °C gardés)" % [s.grille.materiau_sol(t_c), s.chaleur_a(t_c)])

	# 3. DEUX FILONS, LA MÊME CHALEUR. La malachite (200) rend son cuivre, l'hématite (1565) tient.
	var t_m: Vector2i = s._tuile_libre_autour(t_c)
	var t_h: Vector2i = s._tuile_libre_autour(t_m)
	s.grille.materiaux[s.grille.idx(t_m)] = "malachite"
	s.grille.materiaux[s.grille.idx(t_h)] = "hematite"
	s.chauffer(t_m, 400.0)
	s.chauffer(t_h, 400.0)
	s.chaleur_prochain_pas = 0
	s._tiquer_chaleur(300)
	verifier(str(s.grille.materiaux[s.grille.idx(t_m)]) == "cuivre", "à 400 °C la malachite a rendu son cuivre (%s)" % str(s.grille.materiaux[s.grille.idx(t_m)]))
	verifier(str(s.grille.materiaux[s.grille.idx(t_h)]) == "hematite", "à LA MÊME température l'hématite tient (%s)" % str(s.grille.materiaux[s.grille.idx(t_h)]))

	# 4. LES 247 FICHES ONT LEUR POINT DE FUSION, et l'ordre du monde réel tient : l'étain coule avant le plomb, le
	#    plomb avant le cuivre, le cuivre avant le fer, le fer avant le tungstène. C'est ce que le joueur sait déjà.
	var sans := 0
	for mid in mats.keys():
		if not (mats[mid] as Dictionary).get("stats", {}).has("fusion"):
			sans += 1
	verifier(sans == 0, "les %d matières portent toutes `fusion` (%d sans)" % [mats.size(), sans])
	var ordre := ["etain", "plomb", "zinc", "argent", "or", "cuivre", "fer", "titane", "tungstene"]
	var monte := true
	for k in range(1, ordre.size()):
		if int(mats[ordre[k]].stats.fusion) <= int(mats[ordre[k - 1]].stats.fusion):
			monte = false
	verifier(monte, "l'ordre du monde réel tient : étain %d < plomb %d < … < fer %d < tungstène %d" % [int(mats.etain.stats.fusion), int(mats.plomb.stats.fusion), int(mats.fer.stats.fusion), int(mats.tungstene.stats.fusion)])


## Le CHAMP DE DANGER (Émergence — les champs partagés, 2026-09-08). Avant, `grille.dangers` était binaire et posé par
## trois choses seulement : le feu, la lave, un glyphe. **Les nuages de gaz n'y étaient pas** — l'IA marchait dans le
## poison et dans le grisou — et **la chaleur non plus** : une tuile à 300 °C, brûlante sans flamme, était invisible.
## Le champ gradue et absorbe ces deux sources ; le code de décision de l'IA n'a pas changé d'une ligne.
func test_champ_de_danger() -> void:
	var s := Simulation.new(606)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var cfg: Dictionary = GameData.config("thermique").get("danger", {})
	verifier(not cfg.is_empty() and int(cfg.chaleur_seuil) > 0, "les réglages du danger sont en données (seuil %d °C)" % int(cfg.chaleur_seuil))
	# 1. LE GAZ. Un nuage toxique posé à côté du joueur : avant, rien ne le disait à l'IA.
	var t_gaz: Vector2i = s._tuile_libre_autour(j.pos)
	verifier(s.grille.danger_de(t_gaz) == 0, "la tuile est sûre avant le nuage")
	s.zones.append({"pos": t_gaz, "type": "gaz", "gaz": "sulfure_d_hydrogene", "fin": 100000, "source": "", "params": {}})
	s._tiquer_danger(0)
	var d_gaz: int = s.grille.danger_de(t_gaz)
	verifier(d_gaz > 0, "un nuage de gaz toxique EST un danger pour l'IA (%d/100) — il ne l'était pas" % d_gaz)
	# Un gaz qui ne fait qu'étouffer les feux vaut moins qu'un gaz qui blesse : la fiche décide, rien n'est inventé.
	var t_inerte: Vector2i = s._tuile_libre_autour(t_gaz)
	s.zones.append({"pos": t_inerte, "type": "gaz", "gaz": "azote", "fin": 100000, "source": "", "params": {}})
	s.danger_prochain_pas = 0
	s._tiquer_danger(10)
	verifier(s.grille.danger_de(t_inerte) > 0 and s.grille.danger_de(t_inerte) < d_gaz, "un gaz qui asphyxie sans blesser vaut moins (%d contre %d)" % [s.grille.danger_de(t_inerte), d_gaz])
	# 2. LA CHALEUR. Une tuile brûlante SANS flamme est un danger.
	var t_chaud: Vector2i = s._tuile_libre_autour(t_inerte)
	s.chauffer(t_chaud, 350.0)
	verifier(not s.feux.has(s.grille.idx(t_chaud)), "la tuile chaude ne brûle pas : c'est bien la chaleur seule qu'on teste")
	s.danger_prochain_pas = 0
	s._tiquer_danger(20)
	verifier(s.grille.danger_de(t_chaud) > 0, "une tuile à 350 °C sans flamme EST un danger (%d/100)" % s.grille.danger_de(t_chaud))
	# 3. LE CHAMP SE RETIRE quand la source s'en va — et il ne retire QUE les siennes.
	s.zones.clear()
	s.carte_chaleur[s.grille.idx(t_chaud)] = 15.0
	s.chaleur_active.erase(s.grille.idx(t_chaud))
	s.danger_prochain_pas = 0
	s._tiquer_danger(30)
	verifier(s.grille.danger_de(t_gaz) == 0 and s.grille.danger_de(t_chaud) == 0, "le nuage dissipé et la tuile refroidie ne sont plus des dangers")
	# 4. LE FEU GARDE LE SIEN : le champ ne doit jamais effacer le danger d'un propriétaire.
	var t_feu: Vector2i = Vector2i(-9999, -9999)
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q: Vector2i = j.pos + Vector2i(dx, dy)
				if t_feu == Vector2i(-9999, -9999) and s.grille.dans(q) and s.flammabilite_de(q) > 0:
					if s._enflammer(q):
						t_feu = q
	if t_feu != Vector2i(-9999, -9999):
		verifier(s.grille.danger_de(t_feu) == 100, "une tuile en feu vaut le danger maximum (%d)" % s.grille.danger_de(t_feu))
		s.danger_prochain_pas = 0
		s._tiquer_danger(40)
		verifier(s.grille.danger_de(t_feu) == 100, "et le passage du champ ne le lui retire PAS — le feu tient le sien")


func test_feu() -> void:
	var s := Simulation.new(151)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var base: Vector2i = j.pos + Vector2i(3, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(0, 8):
		for dy in range(-2, 3):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
			s.grille.sols.erase(s.grille.idx(t))
	for dx in range(0, 6):   # une rangée de pins (flammabilité 70)
		s.grille.poser_contenu(base + Vector2i(dx, 0), "arbre")
		s.grille.materiaux[s.grille.idx(base + Vector2i(dx, 0))] = "pin"
	var pierre: Vector2i = base + Vector2i(0, 2)
	s.grille.poser_contenu(pierre, "mur")
	s.grille.materiaux[s.grille.idx(pierre)] = "granit"
	s.meteo_force = "clair"
	verifier(s.flammabilite_de(base) == 70 and s.flammabilite_de(pierre) == 0 and s.flammabilite_de(base + Vector2i(0, 1)) == 0, "un pin brûle (70), le granit et le sol nu non")
	verifier(s._enflammer(base) and not s._enflammer(base) and not s._enflammer(pierre), "le premier pin prend feu, une seule fois ; le granit jamais")
	var tick := 2000
	# La propagation passe désormais par le CHAMP DE CHALEUR (Émergence — les champs partagés) : le feu chauffe sa
	# tuile, la chaleur diffuse, et le pin voisin s'enflamme quand elle atteint le seuil de sa matière (70 → 215 °C).
	# Plus de tirage, donc plus de réglage à forcer : le test regarde la physique, pas un dé.
	var per_feu := maxi(int(s.regles.r.feu.periode_ticks), int(GameData.config("thermique").periode_ticks))   # les deux champs (2026-09-08)
	var t_f := tick
	var propage := false
	var monte := 0.0
	for k in 30:
		t_f = tick + k * per_feu
		s._tiquer_feux(t_f)
		s._tiquer_chaleur(t_f)
		if not propage:   # la temperature qui a DECLENCHE, pas celle du voisin une fois en flammes
			monte = maxf(monte, s.chaleur_a(base + Vector2i(1, 0)))
		if s.feux.size() > 1:
			propage = true
	verifier(propage, "le feu gagne les pins voisins par le champ de chaleur (le voisin est monté à %.0f °C)" % monte)
	verifier(s.grille.contenu_de(base).is_empty() and s.modifs_terrain.has(base), "le premier pin est consumé, terrain mémorisé")
	# Brûler : un loup posé sur une tuile en feu
	for idx in s.feux.keys().duplicate():
		s.feux.erase(idx)
	var herbe: Vector2i = base + Vector2i(2, -2)
	s.grille.poser_contenu(herbe, "plante_sauvage")
	s.grille.materiaux[s.grille.idx(herbe)] = "ortie"
	var loup := s.ajouter("loup", herbe, "ia")
	s._enflammer(herbe)
	var pv := int(loup.sante)
	t_f += per_feu
	s._tiquer_feux(t_f)
	verifier(int(loup.sante) < pv and Etres.a_statut_id(loup, "brulure"), "le loup sur la tuile en feu brûle (%d → %d) et prend Brûlure" % [pv, int(loup.sante)])
	# On contourne le feu : un chemin ne traverse pas une tuile en flammes, et l'IA en sort
	var sortie := s.grille.chemin(loup.pos + Vector2i(-2, 0), loup.pos + Vector2i(2, 0))
	verifier(not sortie.is_empty() and not (herbe in sortie), "le chemin contourne la tuile en feu")
	s._decider_ia(loup, t_f + 5)
	verifier(loup.pos != herbe, "le loup sort des flammes d'un pas")
	# La pluie éteint tout
	s.meteo_force = "pluie"
	t_f += per_feu
	s._tiquer_feux(t_f)
	verifier(s.feux.is_empty() and s.grille.dangers.is_empty(), "la pluie éteint les feux, plus rien à éviter")
	s.meteo_force = ""
	s.monde.fermer()


func test_lave() -> void:
	# Le générateur : pas de lave avant l'étage minimum, des mares après
	var s := Simulation.new(152)
	s.charger_donjon("ruine", 152, 3, 2)
	var lave_2 := 0
	for i in s.grille.contenu.size():
		if "lave" in s.grille.contenu_de(s.grille.pos_de(i)).get("tags", []):
			lave_2 += 1
	s.charger_donjon("ruine", 152, 3, 6)
	var laves: Array[Vector2i] = []
	for i in s.grille.contenu.size():
		var t := s.grille.pos_de(i)
		if "lave" in s.grille.contenu_de(t).get("tags", []):
			laves.append(t)
	verifier(lave_2 == 0 and laves.size() >= 6, "pas de lave à l'étage 2, des mares à l'étage 6 (%d tuiles)" % laves.size())
	verifier(s.grille.dangers.has(s.grille.idx(laves[0])), "la lave est un danger : l'IA la contourne")
	# Contact : un loup posé dans la lave brûle
	var t0: Vector2i = laves[0]
	var loup := s.ajouter("loup", t0, "ia")
	var pv := int(loup.sante)
	s.eau_prochain_pas = 0
	s._tiquer_lave(1000)
	verifier(int(loup.sante) < pv and Etres.a_statut_id(loup, "brulure"), "la lave brûle qui s'y tient (%d → %d)" % [pv, int(loup.sante)])
	# L'eau la fige : une source à côté → obsidienne
	var voisine: Vector2i = t0 + Vector2i(1, 0)
	if not s.grille.dans(voisine) or s.grille.bloque_passage(voisine):
		voisine = t0 + Vector2i(-1, 0)
	s.grille.poser_contenu(voisine, "eau")
	s.eau_prochain_pas = 0
	s._tiquer_lave(1010)
	verifier(not ("lave" in s.grille.contenu_de(t0).get("tags", [])) and str(s.grille.materiau_de(t0)) == "obsidienne", "au contact d'une source, la lave se fige en obsidienne")
	verifier(not s.grille.dangers.has(s.grille.idx(t0)), "figée, elle n'est plus un danger")


func test_courant() -> void:
	var s := Simulation.new(153)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var base: Vector2i = j.pos + Vector2i(4, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(0, 8):
		for dy in range(-2, 3):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
	# Une pente : une rivière qui descend vers l'est
	for dx in range(0, 6):
		var t: Vector2i = base + Vector2i(dx, 0)
		s.grille.hauteurs[s.grille.idx(t)] = h0 - dx
		s.grille.poser_contenu(t, "eau_ecoulement")
		s.grille.niveau_eau[s.grille.idx(t)] = 5
	verifier(s.courant_de(base) == Vector2i(1, 0), "le courant descend la pente (%s)" % str(s.courant_de(base)))
	s.grille.poser_contenu(base + Vector2i(2, 0), "eau")
	verifier(s.courant_de(base + Vector2i(2, 0)) == Vector2i.ZERO, "une source n'a pas de courant")
	s.grille.poser_contenu(base + Vector2i(2, 0), "eau_ecoulement")
	s.grille.niveau_eau[s.grille.idx(base + Vector2i(2, 0))] = 5
	# Un objet au sol part au fil de l'eau — s'il FLOTTE (flottabilité, 2026-09-04) : une bûche dérive,
	# une épée de fer attend au fond. Deux objets fabriqués qui ne diffèrent que par cette stat.
	var buche := {"uid": "test_buche_riv", "name_key": "item.craft_javelot.name", "type": "arme", "tags": ["arme"], "stats": {"flottabilite": 80}}
	var fer := {"uid": "test_fer_riv", "name_key": "item.craft_epee.name", "type": "arme", "tags": ["arme"], "stats": {"flottabilite": 3}}
	for it in [buche, fer]:
		s.items[it.uid] = it
		s.objets[it.uid] = it
	s._poser_contenant(base, ["test_buche_riv", "test_fer_riv"], "butin")
	var parti := false
	for k in 40:
		s._tiquer_courant(2000 + k)
		if not ("test_buche_riv" in s.contenants.get(s.grille.idx(base), [])):
			parti = true
			break
	verifier(parti, "la bûche tombée dans la rivière part au fil de l'eau")
	verifier("test_fer_riv" in s.contenants.get(s.grille.idx(base), []), "l'épée de fer, elle, reste au fond")
	verifier(s.items.has("test_buche_riv") and s.items.has("test_fer_riv"), "le courant ne détruit rien : il déplace ce qui flotte")
	# Un être léger dérive, un être surchargé tient
	var loup := s.ajouter("loup", base, "ia")
	var derive := false
	for k in 60:
		s._tiquer_courant(3000 + k)
		if loup.pos != base:
			derive = true
			break
	verifier(derive, "un loup dans le courant est emporté (%s)" % str(loup.pos - base))
	s.grille.liberer(loup.pos)
	loup.pos = base
	s.grille.placer(loup.id, base)
	for k in 60:   # alourdi au-delà du seuil : il tient debout
		s.items["encl_%d" % k] = {"uid": "encl_%d" % k, "name_key": "x", "type": "materiau", "poids": 30.0, "affixes": [], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
		loup.sac.append("encl_%d" % k)
	verifier(float(s.poids_de(loup).poids) / float(s.poids_de(loup).capacite) > 0.5, "le loup est chargé (%.2f de sa capacité)" % (float(s.poids_de(loup).poids) / float(s.poids_de(loup).capacite)))
	var bouge := false
	for k in 60:
		s._tiquer_courant(4000 + k)
		if loup.pos != base:
			bouge = true
			break
	verifier(not bouge, "trop lourd pour dériver : il tient debout")
	s.monde.fermer()
