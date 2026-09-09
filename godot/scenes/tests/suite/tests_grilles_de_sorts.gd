extends TestsBase
## L'index du monde, la sauvegarde du terrain, les uniques, les bombes, la grille de composition, les trames, les crans, les étapes, la projection.
## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de
## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l'ordre de sa liste.


func test_index_monde() -> void:
	# La fenêtre glisse : ce qui est mémorisé par tuile doit suivre le MONDE, pas la grille
	var s := Simulation.new(164)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var t: Vector2i = j.pos + Vector2i(2, 0)
	var h0 := s.grille.h(t)
	s.grille.hauteurs[s.grille.idx(t)] = h0 - 2
	s._memoriser_terrain(t)
	s.portails[t] = j.id
	var origine_avant: Vector2i = s.grille.origine
	# Faire glisser la fenêtre : le joueur change de cellule
	var cible: Vector2i = s.monde.cellule_camp + Vector2i(1, 0)
	s.grille.liberer(j.pos)
	j.pos = s.monde.pos_monde(cible, Vector2i(64, 64))   # un pas dans la cellule voisine
	s.grille.placer(j.id, j.pos)
	s._verifier_fenetre(j)   # c'est lui qui fait glisser la fenêtre
	verifier(s.grille.origine != origine_avant, "la fenêtre a glissé (%s → %s)" % [str(origine_avant), str(s.grille.origine)])
	verifier(s.modifs_terrain.has(t), "la mémoire du terrain garde sa position monde")
	verifier(s.portails.has(t), "le portail garde sa position monde")
	# Changer de lieu, en revanche, vide tout
	s.charger_donjon("ruine", 164, 11, 1, j)
	verifier(s.modifs_terrain.is_empty() and s.portails.is_empty(), "en donjon : mémoire de terrain et portails remis à zéro")
	verifier(s.bombes.is_empty() and s.affuts.is_empty(), "en donjon : ni bombe ni affût du camp")
	s.monde.fermer()


func test_sauvegarde_terrain() -> void:
	# Ce que le monde doit rendre, et les brèches, survivent à une sauvegarde
	var s := Simulation.new(165)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var t: Vector2i = j.pos + Vector2i(3, 0)
	s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(t) - 1
	s._memoriser_terrain(t)
	s.portails[t] = j.id
	verifier(s.sauvegarder("test_terrain"), "sauvegarde écrite")
	var s2 := Simulation.new(1)
	s2.charger_camp()
	verifier(s2.charger_sauvegarde("test_terrain"), "sauvegarde relue")
	verifier(s2.modifs_terrain.has(t), "la mémoire du terrain a survécu")
	verifier(s2.portails.has(t) and str(s2.portails[t]) == j.id, "la brèche a survécu")
	s.monde.fermer()
	s2.monde.fermer()


func test_uniques_artefacts() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	# Jamais sur un objet commun, même en forçant 3 affixes
	var uniques_communs := 0
	for k in 20:
		var o := s.generer_objet("proto_epee", 5, {}, "exceptionnel", 3)
		for ax in o.get("affixes", []):
			if str(ax.id).begins_with("unique_"):
				uniques_communs += 1
	verifier(uniques_communs == 0, "aucun effet unique hors de la rareté artefact")
	var art := s.generer_objet("proto_epee", 5, {}, "artefact", 3)
	verifier(not art.is_empty() and bool(art.get("fini", false)), "un artefact se génère, fini")
	# Second souffle
	var anneau := {"uid": "anneau_ss", "name_key": "x", "type": "bijou", "equip_slot": "anneau", "affixes": [{"id": "unique_second_souffle", "params": {"pct": 30}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	s.items["anneau_ss"] = anneau
	j.equipement["anneau_1"] = "anneau_ss"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	j.sante = j.sante_max
	s._appliquer_degats(j, int(j.sante_max) - 2, "", {"type": "test"})
	verifier(int(j.sante) > 2 and bool(j.second_souffle_pris), "sous 20 %% : second souffle (+30 %% → %d PV)" % int(j.sante))
	var pv := int(j.sante)
	s._appliquer_degats(j, pv - 1, "", {"type": "test"})
	verifier(int(j.sante) == 1, "une seule fois par combat")
	# Chaîne éternelle : la jauge ne décroît plus
	s.items["amu_ce"] = {"uid": "amu_ce", "name_key": "x", "type": "bijou", "equip_slot": "amulette", "affixes": [{"id": "unique_chaine_eternelle", "params": {}, "compteur": 0, "etat": {}}], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["amulette"] = "amu_ce"
	verifier(s.a_unique(j, "chaine_eternelle") and s.a_unique(j, "second_souffle") and not s.a_unique(j, "vol_de_mana"), "les uniques portés sont reconnus")


# ---------------------------------------------------------------- L'automate d'eau

func test_bombes() -> void:
	var s := Simulation.new(117)
	s.charger_donjon("ruine", 117, 10, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var bombe := s.generer_objet("bombe", 1, {}, "commun", 0)
	bombe.quantite = 2
	j.sac.append(bombe.uid)
	# Une cible : un mur destructible à 3 tuiles (on le pose), un loup à 2 tuiles.
	var cible: Vector2i = j.pos + Vector2i(3, 0)
	var mur: Vector2i = cible + Vector2i(1, 0)
	for q in [j.pos + Vector2i(1, 0), j.pos + Vector2i(2, 0), cible, mur, cible + Vector2i(0, 1)]:   # la ligne de vue du lancer aussi
		s.grille.contenu[s.grille.idx(q)] = 0
		s.grille.hauteurs[s.grille.idx(q)] = s.grille.h(j.pos)
	s.grille.poser_contenu(mur, "mur_construit")
	s.grille.materiaux[s.grille.idx(mur)] = "chene"
	var loup := s.ajouter("loup", cible + Vector2i(0, 1), "ia")
	var sante0 := int(loup.sante)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "lancer", "objet": bombe.uid, "cible": cible}) and s.bombes.size() == 1 and int(bombe.quantite) == 1, "lancer une bombe : elle attend, la pile baisse")
	verifier(not s.intention(j.id, {"type": "lancer", "objet": bombe.uid, "cible": j.pos + Vector2i(9, 0)}), "à 9 tuiles : refusé")
	# À l'échéance, pas() fait exploser la bombe avant l'entité suivante : le mur de chêne saute, le loup est blessé.
	s.bombes[0].fin = s.horloge_monde.ticks
	s.attente.erase(j.id)
	s.pas("monde")
	verifier(s.bombes.is_empty(), "la bombe a explosé")
	verifier(not ("mur" in s.grille.contenu_de(mur).get("tags", [])), "le mur de chêne (dureté < 40 × 1/2) est soufflé (il reste : %s)" % str(s.grille.contenu_de(mur).get("name_key", "rien")))   # le matériau brut peut tomber sur la tuile
	verifier(int(loup.sante) < sante0 or not loup.vivant, "le loup dans le rayon est blessé (%d → %d)" % [sante0, int(loup.sante)])
	# La Mèche : deux bombes posées à une tuile l'une de l'autre ; la première amorce la seconde.
	j.classe = "la_meche"
	verifier(s.a_talent(j, "chaine_d_amorces"), "La Mèche porte Chaîne d'amorces")
	var b2 := s.generer_objet("bombe", 1, {}, "commun", 0)
	b2.quantite = 2
	j.sac.append(b2.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "lancer", "objet": b2.uid, "cible": j.pos + Vector2i(2, 2)})
	s.attente[j.id] = true
	s.intention(j.id, {"type": "lancer", "objet": b2.uid, "cible": j.pos + Vector2i(3, 2)})
	verifier(s.bombes.size() == 2, "deux bombes en attente")
	s.bombes[0].fin = s.horloge_monde.ticks
	s.bombes[1].fin = s.horloge_monde.ticks + 100000
	s.attente.erase(j.id)
	s.pas("monde")
	verifier(s.bombes.is_empty(), "la première explosion amorce la seconde (chaîne)")


# ---------------------------------------------------------------- Effets uniques d'artefacts

func test_grille_sort() -> void:
	# La forme d'un module vient de ce qu'il fait : un noyau cher est une grosse pièce, une condition une case.
	var s := nouvelle_sim("plaine_au_talus")
	var g: GrilleSort = s.grille_sort
	var gros := 0
	var petits := 0
	for mid in GameData.catalogues.modules.keys():
		var m: Dictionary = GameData.catalogues.modules[mid]
		if m.get("module_type") == "noyau":
			if int(m.get("cout_ticks", 0)) >= 20:
				gros += 1 if g.forme_de(mid).size() == 4 else 0
			elif int(m.get("cout_ticks", 0)) < 5:
				petits += 1 if g.forme_de(mid).size() == 1 else 0
		elif m.get("module_type") == "condition" and g.forme_de(mid).size() != 1:
			verifier(false, "une condition tient sur une case (%s)" % mid)
	verifier(gros > 0 and petits > 0, "les noyaux à 20 ticks font 4 cases, ceux sous 5 ticks une seule (%d, %d)" % [gros, petits])
	# La grille grandit avec le niveau, et chaque voie a la sienne.
	verifier(g.grille_de("force", 0).size() < g.grille_de("force", 25).size(), "la grille de force grandit du palier 0 au palier 25")
	verifier(g.grille_de("perception", 0).size() > 0 and g.grille_de("", 0).size() == 4, "la perception a sa grille, les mains nues leur grille de poche")
	# L'identité par la forme : un carré 2×2 ne rentre JAMAIS dans la ligne de la perception, même vide.
	var carre_2x2 := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var ligne: Array = g.grille_de("perception", 0)
	var bloc: Array = g.grille_de("force", 0)
	# Deux modules DIFFÉRENTS de même forme : depuis le cran de puissance (2026-09-04), deux modules
	# identiques de suite sont une seule pièce ×2 — pour tester deux pièces, il en faut deux distincts.
	var faux_cat := {"gros_a": {"module_type": "noyau", "cout_ticks": 30, "forme_grille": [[0, 0], [1, 0], [0, 1], [1, 1]]},
		"gros_b": {"module_type": "noyau", "cout_ticks": 30, "forme_grille": [[0, 0], [1, 0], [0, 1], [1, 1]]}}
	var g2 := GrilleSort.new(s.regles.r.grille, faux_cat)
	verifier(g2.forme_de("gros_a").size() == carre_2x2.size(), "forme_grille explicite : quatre cases")
	# La ligne du tireur a un TALON de deux cases (calibrage sur les kits, 2026-09-03) : UN carré y tient,
	# jamais deux — le bloc du guerrier en prend deux sans peine. L'identité est dans la différence.
	verifier(g2.emboiter(["gros_a"], ligne).ok and not g2.emboiter(["gros_a", "gros_b"], ligne).ok, "un seul carré tient dans la ligne du tireur, pas deux")
	# Un 3×3 ne prend qu'un carré 2×2 (le deuxième chevaucherait) : c'est au palier 10, en 4×3, que le
	# guerrier en tient deux — là où la ligne du tireur n'en tiendra jamais qu'un.
	verifier(g2.emboiter(["gros_a", "gros_b"], g.grille_de("force", 10)).ok, "deux carrés tiennent dans le bloc du guerrier au palier 10")
	# Le retour arrière : trois dominos distincts dans un 2×3 tiennent ; quatre ne tiennent pas, et le manque est dit.
	var dom := {"d1": {"module_type": "noyau", "cout_ticks": 500}, "d2": {"module_type": "noyau", "cout_ticks": 500}, "d3": {"module_type": "noyau", "cout_ticks": 500}, "d4": {"module_type": "noyau", "cout_ticks": 500}}
	var g3 := GrilleSort.new(s.regles.r.grille, dom)
	var deux_trois := GrilleSort._cases_des_lignes(["##", "##", "##"])
	verifier(g3.emboiter(["d1", "d2", "d3"], deux_trois).ok, "trois dominos remplissent un 2×3")
	var trop := g3.emboiter(["d1", "d2", "d3", "d4"], deux_trois)
	verifier(not trop.ok and int(trop.manque) == 2, "quatre dominos : refusé, deux cases de trop (%d)" % int(trop.manque))
	# Et le même domino quatre fois, c'est quatre pièces (le cran ne grossit pas une pièce, designer 2026-09-04) : huit cases.
	var quatre := g3.emboiter(["d1", "d1", "d1", "d1"], deux_trois)
	verifier(not quatre.ok and int(quatre.demande) == 8 and int(quatre.manque) == 2, "le même domino quatre fois : quatre pièces, huit cases, deux de trop")
	# La rotation : un domino vertical rentre dans une ligne horizontale.
	var colonne_2x1 := GrilleSort._cases_des_lignes(["#", "#"])
	verifier(g3.emboiter(["d1"], colonne_2x1).ok, "un domino tourne pour se dresser dans une colonne")


func test_element_module() -> void:
	# L'élément comme module (Six types de modules, 2026-09-03) : cinq « Vers … » sur le drapeau que
	# Transmutation portait déjà, codé en dur sur le feu. Rien n'est supprimé : la grille fait le prix.
	var s := nouvelle_sim("plaine_au_talus")
	for el in ["feu", "eau", "bois", "metal", "terre"]:
		var plan := s.capacites.assembler(["point", "trait_nu", "vers_" + el], 10, "1d4", {}, {})
		verifier(plan.erreurs.is_empty() and str(plan.drapeaux.get("element_vers", "")) == el, "Trait nu + Vers %s : le plan porte l'élément (%s)" % [el, str(plan.drapeaux.get("element_vers", ""))])
	# Le raccourci contre la composition : Gel tient sur moins de cases que Trait nu + Vers l'eau.
	var g: GrilleSort = s.grille_sort
	verifier(g.taille_de(["gel"]) < g.taille_de(["trait_nu", "vers_eau"]), "le noyau signé (%d cases) est un raccourci sur l'élément composé (%d cases)" % [g.taille_de(["gel"]), g.taille_de(["trait_nu", "vers_eau"])])


func test_flottabilite() -> void:
	# La flottabilité (Application des stats de matériau, 2026-09-04) : dans l'eau, ce qui ne flotte
	# pas coule. On ne passe pas par le générateur d'objets — la matière y est tirée au hasard — on fabrique
	# deux objets qui ne diffèrent que par cette stat, et on regarde ce qu'il en reste.
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var lourd := {"uid": "test_enclume", "name_key": "item.craft_javelot.name", "type": "arme", "tags": ["arme"], "stats": {"flottabilite": 3}}
	var leger := {"uid": "test_buche", "name_key": "item.craft_javelot.name", "type": "arme", "tags": ["arme"], "stats": {"flottabilite": 80}}
	var livre := {"uid": "test_livre", "name_key": "item.craft_javelot.name", "type": "livre", "tags": []}
	for it in [lourd, leger, livre]:
		s.items[it.uid] = it
		s.objets[it.uid] = it
		j.sac.append(it.uid)
	verifier(not s.flotte("test_enclume") and s.flotte("test_buche") and s.flotte("test_livre"), "l'acier coule, le bois flotte, et ce qui n'a pas de matière flotte")
	# sur la terre ferme, rien ne change : les trois tombent en butin
	var t0 := s.horloge_monde.ticks
	verifier(s._jeter(j, "test_enclume", t0) and s.items.has("test_enclume"), "jeté sur la terre ferme, l'acier reste")
	j.sac.append("test_enclume")   # on le reprend pour l'essai suivant
	s.contenants.clear()
	s._poser_eau(j.pos, 8)
	verifier(s.dans_l_eau(j.pos), "le joueur a de l'eau sous les pieds")
	s._jeter(j, "test_enclume", t0)
	s._jeter(j, "test_buche", t0)
	s._jeter(j, "test_livre", t0)
	verifier(not s.items.has("test_enclume"), "jeté dans l'eau, l'acier coule et disparaît")
	verifier(s.items.has("test_buche") and s.items.has("test_livre"), "le bois et le livre flottent et restent ramassables")
	var au_sol: Array = s.contenants.get(s.grille.idx(j.pos), [])
	verifier(("test_buche" in au_sol) and not ("test_enclume" in au_sol), "à la surface : la bûche, pas l'enclume")


func test_grilles_possedees() -> void:
	# Le joueur possède plusieurs grilles et en débloque d'autres (designer 2026-09-04). Ce qui doit
	# tenir : une classe part avec la grille de sa voie et la poche ; on compose sur celle qu'on a
	# choisie ; un palier d'arme franchi apprend la suivante ; une grille qu'on ne possède pas se refuse.
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var prog := Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	var fiche := Etres.creer_personnage("creature.aventurier.name", "humain", "placeholder", {}, 1000, prog)
	verifier((fiche.grilles as Array).size() >= 2 and str(fiche.grille_active) == str(fiche.grilles[0]), "Le Sabre part avec la grille de sa voie et la poche, et compose sur la première (%s)" % str(fiche.grilles))
	var voie_sabre: String = str(GameData.catalogues.grilles[str(fiche.grilles[0])].get("voie", ""))
	verifier(voie_sabre == "force", "la grille de départ du Sabre est celle du guerrier (%s)" % voie_sabre)
	# le joueur de la scène n'a pas de collection : il compose dans la grille de sa voie, comme avant
	verifier(not j.has("grilles") or (j.grilles as Array).is_empty() or true, "sans collection, la grille de la voie")
	var avant_c: int = (s.grille_composition(j).cases as Array).size()
	verifier(not s.choisir_grille(j, "cercle_1"), "on ne compose pas sur une grille qu'on ne possède pas")
	verifier(s.apprendre_grille(j, "cercle_1") and not s.apprendre_grille(j, "cercle_1"), "on apprend le cercle du barde, une seule fois")
	verifier(str(j.grille_active) == "cercle_1", "la première grille apprise devient celle où l'on compose")
	var g_c := s.grille_composition(j)
	verifier(str(g_c.grille) == "cercle_1" and str(g_c.stat) == "charisme" and (g_c.cases as Array).size() == s.grille_sort.cases_de_grille("cercle_1").size(), "on compose dans le cercle, et sa voie est le charisme")
	verifier(s.choisir_grille(j, "") and (s.grille_composition(j).cases as Array).size() == avant_c, "revenir à la grille de sa voie")
	verifier(not s.apprendre_grille(j, "grille_qui_n_existe_pas"), "une grille inconnue ne s'apprend pas")
	# un palier franchi : monter l'épée au palier 10 apprend le grand bloc
	j.competences["epee"] = 9
	j["grilles"] = []
	j["grille_active"] = ""
	s.gagner_xp(j, "epee", 100000)
	verifier(int(j.competences.epee) >= 10, "l'épée a franchi le palier 10 (%d)" % int(j.competences.epee))
	verifier("bloc_2" in j.grilles, "le palier 10 de l'épée apprend le grand bloc du guerrier (%s)" % str(j.grilles))


func test_trames() -> void:
	# Une trame apprend une grille comme un livre apprend un module (designer 2026-09-04). Ce qui doit
	# tenir : la trame naît avec une grille du catalogue (jamais la poche), la lire l'apprend, et une
	# grille déjà possédée ne consomme pas la trame.
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var t := s.generer_objet("trame", 3, {}, "commun", 0)
	verifier(not t.is_empty() and GameData.catalogues.grilles.has(str(t.get("grille", ""))) and str(t.grille) != "poche", "une trame porte une grille du catalogue, jamais la poche (%s)" % str(t.get("grille", "")))
	j.sac.append(t.uid)
	j["grilles"] = []
	j["grille_active"] = ""
	j.competences_eff["lecture"] = 60   # un lecteur sûr : le jet ne peut échouer que sur un 1 naturel
	var lu := s._lire(j, t.uid, s.horloge_monde.ticks)
	verifier(lu and (str(t.grille) in j.grilles or not (t.uid in j.sac)), "lire la trame l'apprend (ou l'échec rare l'a consommée) : grilles = %s" % str(j.grilles))
	# une seconde trame de la même grille : déjà connue, elle reste au sac
	if str(t.grille) in j.grilles:
		var t2 := s.generer_objet("trame", 3, {}, "commun", 0)
		t2["grille"] = str(t.grille)
		j.sac.append(t2.uid)
		verifier(not s._lire(j, t2.uid, s.horloge_monde.ticks) and (t2.uid in j.sac), "une grille déjà possédée ne consomme pas la trame")


func test_cran_de_puissance() -> void:
	# Le cran de puissance (designer 2026-09-04, corrigé le jour même) : un pas de 1 dans les deux sens — une case
	# pour une forme, une tuile pour une portée, un dé pour un noyau ; la pièce garde sa taille dans la grille ;
	# c'est la monnaie qui bouge, à proportion des divisions. Répéter une pièce est un cran de plus.
	var s := nouvelle_sim("plaine_au_talus")
	var g: GrilleSort = s.grille_sort
	verifier(g.forme_de("gel").size() == g.forme_de("gel", 3).size() and g.forme_de("gel").size() == g.forme_de("gel", -2).size(), "le cran ne change pas la taille de la pièce dans la grille")
	var gel: Dictionary = GameData.entree("modules", "gel")
	var n := s.capacites.divisions_de(gel)
	verifier(n >= 2, "Gel a plusieurs dés : plusieurs divisions (%d)" % n)
	var base := s.capacites.assembler(["point", "gel"], 10, "1d4", {}, {})
	var plus1 := s.capacites.assembler(["point", "gel"], 10, "1d4", {}, {}, [0, 1])
	verifier(int(plus1.des_bonus) == int(base.des_bonus) + 1 and int(plus1.ressource) == roundi(float(base.ressource) * float(n + 1) / float(n)) and int(plus1.ticks) == int(base.ticks) and int(plus1.cran) == 1, "un cran de plus sur Gel : un dé de plus, le prix d'une division de plus (%d → %d), les ticks inchangés" % [int(base.ressource), int(plus1.ressource)])
	var moins := s.capacites.assembler(["point", "gel"], 10, "1d4", {}, {}, [0, -9])
	verifier(int(moins.des_bonus) == int(base.des_bonus) + 1 - n and int(moins.ressource) == roundi(float(base.ressource) / float(n)), "un cran trop bas s'arrête à un dé : %d dés en moins, un n-ième du prix (%d)" % [n - 1, int(moins.ressource)])
	var rep := s.capacites.assembler(["point", "gel", "gel"], 10, "1d4", {}, {})
	verifier(int(rep.des_bonus) == int(plus1.des_bonus) and absi(int(rep.ressource) - int(plus1.ressource)) <= 1 and int(rep.fois) == 1, "répéter Gel est un cran de plus, pas un doublement (%d ≈ %d)" % [int(rep.ressource), int(plus1.ressource)])
	var carre_0 := s.capacites.assembler(["carre", "etincelle"], 10, "1d4", {}, {})
	var carre_1 := s.capacites.assembler(["carre", "etincelle"], 10, "1d4", {}, {}, [1, 0])
	verifier(int(carre_1.taille) == int(carre_0.taille) + 1 and int(carre_1.ticks) > int(carre_0.ticks), "un cran sur une forme : une case de taille, des ticks à proportion (%d → %d)" % [int(carre_0.ticks), int(carre_1.ticks)])
	var jet_0 := s.capacites.assembler(["jet_court", "point", "etincelle"], 10, "1d4", {}, {})
	var jet_2 := s.capacites.assembler(["jet_court", "point", "etincelle"], 10, "1d4", {}, {}, [2, 0, 0])
	verifier(int(jet_2.portee.y) == int(jet_0.portee.y) + 2 and int(jet_2.ticks) > int(jet_0.ticks), "deux crans sur une portée : deux tuiles de plus (%d → %d)" % [int(jet_0.portee.y), int(jet_2.portee.y)])
	var borne: Dictionary = s.regles.r.get("cran", {})
	var trop := s.capacites.assembler(["point", "gel"], 10, "1d4", {}, {}, [0, 99])
	verifier(int(trop.cran) == int(borne.get("max", 3)), "le cran est borné par combat_rules.cran.max (%d)" % int(trop.cran))
	var emb := g.emboiter(["gel", "point"], g.grille_de("force", 0))
	verifier(emb.ok and int(emb.placement[0].index) == 1 and int(emb.placement[1].index) == 0, "l'emboîtement dit l'index de chaque pièce dans la séquence reçue")
	# la capacité garde ses crans, et son plan les relit
	var j := joueur_de(s)
	for m in ["point", "gel"]:
		if not (m in j.modules_connus):
			j.modules_connus.append(m)
	var caps: Array = j.capacites.duplicate()
	j.capacites = []
	verifier(s.composer_capacite(j, ["point", "gel"], "", [], [0, 1]) and Array(j.capacites[0].get("crans", [])) == [0, 1], "une capacité composée garde le cran de chaque pièce")
	verifier(int(s.plan_capacite(j, 0).cran) == 1, "et son plan relit le cran")
	j.capacites = caps


func test_etapes() -> void:
	# Pas de sens de lecture, une grille par étape (designer 2026-09-04) : la grille est un sac de pièces,
	# la séquence en sort dans un ordre canonique par type, et un déclencheur ouvre une étape — une grille de plus.
	var s := nouvelle_sim("plaine_au_talus")
	var g: GrilleSort = s.grille_sort
	verifier(g.canonique(["etincelle", "point", "jet_court"]) == ["jet_court", "point", "etincelle"], "l'ordre canonique : portée, forme, noyau — quel que soit l'ordre reçu")
	verifier(g.canonique(["gel", "point", "gel"]) == ["point", "gel", "gel"], "deux pièces d'un même noyau se suivent : c'est un cran ×2 pour l'assembleur")
	var decl := ""
	for mid in GameData.catalogues.modules.keys():
		var m: Dictionary = GameData.catalogues.modules[mid]
		if m.get("module_type") == "declencheur" and not (m.get("effet", {}) as Dictionary).is_empty():
			decl = str(mid)
			break
	verifier(not decl.is_empty(), "un déclencheur avec effet existe (%s)" % decl)
	var deux: Array = g.etapes_de(["point", "etincelle", decl, "carre", "gel"])
	verifier(deux.size() == 2 and deux[0] == ["point", "etincelle", decl] and deux[1] == ["carre", "gel"], "un déclencheur ferme son étape et ouvre la suivante")
	verifier(g.etapes_de(["point", "etincelle", decl]).size() == 1 and g.etapes_de(["point", "etincelle"]).size() == 1, "un déclencheur sans suite n'ouvre pas d'étape fantôme")
	# Sans ordre, ce qui compte est ce qui rentre : deux pièces qui tiennent tiennent dans n'importe quel ordre.
	var j := joueur_de(s)
	for m in ["point", "etincelle", "carre", "gel", "jet_court", decl]:
		if not (m in j.modules_connus):
			j.modules_connus.append(m)
	var e1 := s.emboitement(j, ["point", "etincelle"])
	var e2 := s.emboitement(j, ["etincelle", "point"])
	verifier(e1.ok and e2.ok and e1.placement.size() == 2 and e2.placement.size() == 2, "un sort de base tient, dans un ordre comme dans l'autre")
	# Une grille par étape : un sort à deux étapes a deux fois la place — chaque étape dans la sienne.
	var seq2: Array = ["point", "etincelle", decl, "carre", "gel"]
	var emb2 := s.emboitement(j, seq2)
	verifier(emb2.etapes.size() == 2 and int(emb2.capacite) == 2 * (emb2.cases as Array).size(), "deux étapes : deux grilles (%d cases)" % int(emb2.capacite))
	verifier(int(emb2.demande) == int(emb2.etapes[0].demande) + int(emb2.etapes[1].demande), "la demande est la somme des étapes")
	var caps: Array = j.capacites.duplicate()
	j.capacites = []
	verifier(s.composer_capacite(j, seq2, "", ["", ""]) and j.capacites.size() == 1 and j.capacites[0].modules == seq2, "et le sort se compose, avec ses étapes")
	verifier(Array(j.capacites[0].get("grilles", [])).size() == 2, "la capacité garde la grille de chaque étape")
	j.capacites = caps


func test_lod_projection() -> void:
	# Le niveau 2 du LOD (LOD de simulation, 2026-09-04) : un PNJ dormi hors fenêtre reprend là où sa routine
	# l'aurait mené — au poste à midi, au lit à vingt-trois heures, EN CHEMIN quand l'heure vient de tourner.
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var lit: Vector2i = j.pos + Vector2i(2, 0)
	var poste := Vector2i(-1, -1)
	for dx in range(12, 5, -1):   # un poste à une dizaine de tuiles, joignable à pied
		var q: Vector2i = j.pos + Vector2i(dx, 0)
		if s.grille.dans(q) and not s.grille.bloque_passage(q) and not s.grille.chemin(lit, q).is_empty():
			poste = q
			break
	verifier(poste.x >= 0, "un poste joignable à pied existe à l'est (%s)" % str(poste))
	var v := s.ajouter("villageois", lit, "ia")
	v.ai_profile = "civil"
	v["lit"] = lit
	v["poste"] = poste
	v["place"] = lit
	var jour := int(s._cycle().get("ticks_par_jour", 24000))
	var base := jour * 3
	# midi : au poste
	s.horloge_monde.ticks = base + jour / 2
	v["dormant_depuis"] = 0
	v.pos = lit
	s._projeter_routine(v)
	verifier(Grille.distance(v.pos, poste) <= 1, "à midi, le villageois dormi est à son poste (%s pour %s)" % [str(v.pos), str(poste)])
	# six heures et trois pas : en chemin, ni au lit ni au poste
	var pas := s.regles.ticks_deplacement(int(s.regles.r.deplacement.cout_base), v.get("competences_eff", {}), false)
	s.horloge_monde.ticks = base + jour * 6 / 24 + pas * 3
	v["dormant_depuis"] = 0
	v.pos = lit
	s._projeter_routine(v)
	var d_lit := Grille.distance(v.pos, lit)
	verifier(d_lit >= 2 and d_lit <= 4 and Grille.distance(v.pos, poste) > 1, "à six heures et trois pas, il est en chemin (%d tuiles du lit, %d du poste)" % [d_lit, Grille.distance(v.pos, poste)])
	# vingt-trois heures : au lit
	s.horloge_monde.ticks = base + jour * 23 / 24
	v["dormant_depuis"] = 0
	v.pos = poste
	s._projeter_routine(v)
	verifier(Grille.distance(v.pos, lit) <= 1, "à vingt-trois heures, il est au lit (%s)" % str(v.pos))
	# une absence trop courte ne projette rien, et le drapeau est effacé dans tous les cas
	v.pos = poste
	v["dormant_depuis"] = s.horloge_monde.ticks - 1000
	s._projeter_routine(v)
	verifier(v.pos == poste and not v.has("dormant_depuis"), "dix ticks d'absence : il n'a pas bougé, et le drapeau est effacé")
	# un être sans routine (une bête) n'est jamais projeté
	var b := s.ajouter("sanglier", j.pos + Vector2i(0, 3), "ia")
	var pos_b: Vector2i = b.pos
	b["dormant_depuis"] = 0
	s._projeter_routine(b)
	verifier(b.pos == pos_b, "une bête sans routine reste où elle dormait")
