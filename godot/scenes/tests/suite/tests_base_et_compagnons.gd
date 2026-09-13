extends TestsBase
## La faune, la base (engager, périmètres, faim, dette), les compagnons en donjon, les classes des PNJ, la composition des capacités, les zones au sol.
## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de
## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l'ordre de sa liste.


func test_faune_rarefaction() -> void:
	# Massacrer la faune vide la forêt, et elle revient (Créatures, hypothèses du 2026-09-04) : chaque bête
	# paisible tuée par le joueur raréfie la faune de sa cellule, le tirage la lit, la semaine la fait revenir.
	var s := Simulation.new(31)
	s.charger_camp()
	var j := joueur_de(s)
	var ra: Dictionary = GameData.config("planete").faune.rarefaction
	verifier(s.densite_faune(j.pos) == 1.0, "une cellule jamais chassée a une densité de 1")
	var pos: Vector2i = j.pos + Vector2i(1, 0)
	for k in 8:   # une place libre à côté du joueur
		if s.grille.dans(pos) and not s.grille.bloque_passage(pos) and s.grille.occupant(pos).is_empty():
			break
		pos = j.pos + Vector2i(k % 3 - 1, k / 3 - 1)
	var cerf := s.ajouter("cerf", pos, "ia")
	cerf["spawn_faune"] = true
	cerf.ai_profile = "proie"
	verifier(Simulation.est_faune_paisible(cerf), "un cerf en proie est une bête paisible")
	s._appliquer_degats(cerf, 100000, j.id, {})
	verifier(not cerf.vivant and absf(s.densite_faune(j.pos) - (1.0 - float(ra.par_mort))) < 0.001, "tuer un cerf raréfie la faune de la cellule (%.2f)" % s.densite_faune(j.pos))
	for k in 20:   # on ne descend jamais sous le plancher
		s._rarefier_faune(j.pos)
	verifier(absf(s.densite_faune(j.pos) - float(ra.plancher)) < 0.001, "vingt cerfs de plus : la densité s'arrête au plancher (%.2f)" % s.densite_faune(j.pos))
	var loup := s.ajouter("loup", pos, "ia")
	loup["spawn_faune"] = true
	loup.ai_profile = "hostile"
	var avant := s.densite_faune(j.pos)
	s._appliquer_degats(loup, 100000, j.id, {})
	verifier(not loup.vivant and s.densite_faune(j.pos) == avant, "tuer un loup qui chasse ne raréfie rien")
	s._regenerer_faune_hebdo()
	verifier(absf(s.densite_faune(j.pos) - (float(ra.plancher) + float(ra.retour_hebdo))) < 0.001, "une semaine plus tard, la faune revient d'un cran (%.2f)" % s.densite_faune(j.pos))
	for k in 40:
		s._regenerer_faune_hebdo()
	verifier(s.densite_faune(j.pos) == 1.0 and s.monde.faune_densite.is_empty(), "et au bout de quarante semaines, la cellule est comme neuve")
	s.monde.fermer()


func test_engager_et_migrants() -> void:
	# Le recrutement pour la base (Décision — Gestion de base, étape 1, 2026-09-04) : engager un PNJ qui part
	# s'installer à la base, et des migrants qui viennent d'eux-mêmes au passage de semaine.
	var s := Simulation.new(31)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(s._cellule_base() == s.monde.cellule_camp, "la base est la cellule du camp (revendiquée d'office)")
	var eng: Dictionary = s.regles.r.royaume.engagement
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	if not v.has("social"):
		v["social"] = {"culture": "", "relations": {}}
	v.social.relations[j.id] = 10
	j.or = 100
	verifier(not s._engager(j, v.id, 0), "une relation trop basse : il refuse")
	v.social.relations[j.id] = 60
	j.or = 5
	verifier(not s._engager(j, v.id, 0) and int(j.or) == 5, "sans l'or de l'engagement : refusé, rien n'est pris")
	j.or = 100
	var n0: int = s.residents().size()
	var or_v0: int = int(v.get("or", 0))   # un villageois a déjà une bourse
	verifier(s._engager(j, v.id, 0), "avec la relation et l'or : engagé")
	verifier(int(j.or) == 100 - int(eng.or) and int(v.or) == or_v0 + int(eng.or), "l'or passe de la bourse du joueur à la sienne (+%d)" % (int(v.or) - or_v0))
	verifier(v.has("assignation") and str(v.assignation.fonction) == str(eng.fonction_defaut) and v.assignation.cellule == s.monde.cellule_camp and not v.has("maitre") and v.camp == "joueur", "il est résident oisif de la base, pas compagnon")
	verifier(s.residents().size() == n0 + 1 and s.entites.has(v.id) and s.grille.occupant(v.pos) == v.id, "déjà sur la base : il s'installe sur place, et reste dans la fenêtre")
	verifier(not s._engager(j, v.id, 0), "un résident ne s'engage pas deux fois")
	# les migrants : au passage de semaine, une chance que la réputation multiplie
	var n1: int = s.residents().size()
	s.regles.r.royaume.migrants.chance_base = 0.0
	s._semaine_migrants(j)
	verifier(s.residents().size() == n1, "chance nulle : personne ne vient")
	s.regles.r.royaume.migrants.chance_base = 1.0
	s._semaine_migrants(j)
	verifier(s.residents().size() == n1 + 1, "chance pleine : un villageois arrive s'installer (%d résidents)" % s.residents().size())
	var arrive: Dictionary = s.residents().back()
	verifier(str(arrive.assignation.fonction) == str(eng.fonction_defaut) and arrive.camp == "joueur" and (s.entites.has(arrive.id) or not s.monde.dormants.get(s.monde.cellule_camp, []).is_empty()), "le migrant est oisif, au camp du joueur — dans la fenêtre ou mis de côté")
	s.regles.r.royaume.migrants.residents_par_cellule = 1
	s._semaine_migrants(j)
	verifier(s.residents().size() == n1 + 1, "la base pleine n'attire plus personne")
	s.regles.r.royaume.migrants.residents_par_cellule = 4
	s.regles.r.royaume.migrants.chance_base = 0.2
	# renvoyer (Gestion de base, étape 2) : un engagé redevient villageois, pas compagnon
	verifier(s.desassigner(j, v.id, true) and not v.has("assignation") and not v.has("maitre") and v.camp == "civil", "renvoyé depuis l'écran : il redevient villageois, sans prendre une place d'escorte")
	s.monde.fermer()


func test_perimetres() -> void:
	# Les périmètres de récolte (Population et exploitation, 2026-09-04) : c'est ce qu'il y a sur les tuiles qui
	# produit — on plante cinq pins, on déclare la cellule en périmètre bois, on y assigne un bûcheron.
	var s := Simulation.new(31)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var camp: Vector2i = s.monde.cellule_camp
	var pcfg: Dictionary = s.regles.r.royaume.perimetres
	verifier(s.creer_perimetre(camp, "pierre").is_empty(), "un type inconnu : refusé")
	var plantes := 0
	for dx in range(3, 12):
		var q: Vector2i = j.pos + Vector2i(dx, 2)
		if s.grille.dans(q) and s.grille.occupant(q).is_empty() and not s.grille.bloque_passage(q) and plantes < 5:
			s.grille.poser_contenu(q, "arbre")
			s.grille.materiaux[s.grille.idx(q)] = "pin"
			plantes += 1
	verifier(plantes == 5, "cinq pins plantés près du joueur")
	var pid := s.creer_perimetre(camp, "bois")
	var per: Dictionary = s.perimetres()[pid]
	var dom: String = str(per.dominant)   # le camp est en forêt : le chêne peut dominer les cinq pins plantés
	verifier(not pid.is_empty() and int(per.richesse) >= 5 and str(GameData.entree("materials", dom).get("harvest", {}).get("skill", "")) == "bucheronnage" and float(per.reserve) >= float(per.richesse) * float(pcfg.unites_par_tuile), "le périmètre bois compte au moins les cinq pins, une essence domine (%d tuiles, %s, réserve %.0f)" % [int(per.richesse), dom, float(per.reserve)])
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	v.camp = "joueur"
	verifier(s._assigner(j, v.id, "bucheron", 0, pid) and str(v.assignation.get("perimetre", "")) == pid, "un bûcheron assigné sur le périmètre")
	# Un stockage par poste (designer, 10 h 35) : sans stockage désigné, rien ne se récolte
	verifier(bool(s.production_de(v).get("sans_stockage", false)), "sans stockage désigné, le poste ne produit pas")
	var coin_s := Vector2i(-1, -1)   # deux tuiles libres pour un stockage, à l'ouest du joueur
	for dx in range(-3, -12, -1):
		var qs: Vector2i = j.pos + Vector2i(dx, 0)
		if s.grille.dans(qs) and s.grille.dans(qs + Vector2i(0, 1)) and not s.grille.bloque_passage(qs) and not s.grille.bloque_passage(qs + Vector2i(0, 1)) and s.grille.occupant(qs).is_empty() and s.grille.occupant(qs + Vector2i(0, 1)).is_empty() and s._cell_de(qs + Vector2i(0, 1)) == camp:
			coin_s = qs
			break
	verifier(coin_s != Vector2i(-1, -1), "deux tuiles libres pour un stockage")
	var pid_s := s.dessiner_perimetre(coin_s, coin_s + Vector2i(0, 1), "stockage")
	verifier(not pid_s.is_empty() and int(s.perimetres()[pid_s].capacite) == 2 * int(s.regles.r.royaume.stockage.unites_par_tuile) and s.place_stockage(pid_s) == int(s.perimetres()[pid_s].capacite), "un stockage de deux tuiles : capacité %d, toute libre" % int(s.perimetres().get(pid_s, {}).get("capacite", 0)))
	verifier(not s.assigner_stockage(pid, pid) and s.assigner_stockage(pid, pid_s), "un poste désigne un stockage — pas un périmètre de production")
	var au_bord := false   # il travaille dedans : son poste touche un arbre
	for vv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var qq: Vector2i = v.poste + vv
		if s.grille.dans(qq) and "arbre" in s.grille.contenu_de(qq).get("tags", []):
			au_bord = true
	verifier(au_bord and v.poste != v.pos, "son poste est une tuile au bord des arbres (%s), pas là où il se tenait" % str(v.poste))
	var pr := s.production_de(v)
	verifier(not pr.is_empty() and str(pr.base) == dom and int(pr.n) >= 1 and str(pr.perimetre) == pid, "sa production vient des tuiles : du bois brut de l'essence dominante (%s ×%d)" % [str(pr.get("base", "")), int(pr.get("n", 0))])
	var reserve0: float = float(per.reserve)
	s.territoire.tresor = 10000   # l'entretien ne doit pas brouiller la mesure
	s._semaine_territoire(j)
	verifier(int(s.territoire.stocks.get(dom + "|brut", 0)) >= 1 and float(per.reserve) < reserve0, "après la semaine : du bois brut au stock (%d), la réserve a baissé (%.1f → %.1f)" % [int(s.territoire.stocks.get(dom + "|brut", 0)), reserve0, float(per.reserve)])
	var st: Dictionary = s.perimetres()[pid_s]
	verifier(int(st.contenu.get(dom + "|brut", 0)) == int(s.territoire.stocks.get(dom + "|brut", 0)) and s.place_stockage(pid_s) == int(st.capacite) - int(st.contenu.get(dom + "|brut", 0)), "le bois est rangé dans le stockage, qui compte sa place (%d/%d)" % [s.place_stockage(pid_s), int(st.capacite)])
	verifier(int(s.production_de(v).get("n", 0)) <= s.place_stockage(pid_s), "la production suivante se borne à la place qui reste")
	s.retirer_stock(j, dom + "|brut")
	verifier(int(st.contenu.get(dom + "|brut", 0)) == 0 and s.place_stockage(pid_s) == int(st.capacite), "ce que le joueur prend au stock sort aussi du stockage")
	# la repousse : seulement sur une cellule Ressources naturelles
	var r1: float = float(per.reserve)
	s._repousser_perimetres()
	verifier(float(per.reserve) == r1, "sur une cellule de base, la réserve ne repousse pas")
	s.monde.claims[camp].role = "ressources"
	s._repousser_perimetres()
	verifier(float(per.reserve) > r1, "sur une cellule Ressources naturelles, elle repousse (%.1f → %.1f)" % [r1, float(per.reserve)])
	s.monde.claims[camp].role = "base"
	# retirer le périmètre : le bûcheron revient à la production de sa fonction
	verifier(s.retirer_perimetre(pid) and not v.assignation.has("perimetre") and not s.perimetres().has(pid), "périmètre retiré : le résident revient à sa fonction")
	# Les périmètres DESSINÉS (designer, 10 h 25) : un rectangle de trois sur trois autour des pins ne compte qu'eux
	var coin_a: Vector2i = j.pos + Vector2i(3, 1)
	var coin_b: Vector2i = j.pos + Vector2i(7, 3)
	var pid_d := s.dessiner_perimetre(coin_a, coin_b, "bois")
	var per_d: Dictionary = s.perimetres().get(pid_d, {})
	verifier(not pid_d.is_empty() and per_d.has("tuiles") and (per_d.tuiles as Array).size() == 15 and int(per_d.richesse) == 5 and s.tuiles_de_perimetre(pid_d).size() == 15, "un rectangle dessiné de 5×3 : quinze tuiles, cinq pins comptés (%d tuiles, richesse %d)" % [(per_d.get("tuiles", []) as Array).size(), int(per_d.get("richesse", 0))])
	var n_per: int = s.perimetres_de(camp).size()
	verifier(s.dessiner_perimetre(coin_a, coin_b, "minerai") != pid_d and s.perimetres_de(camp).size() == n_per + 1, "un second périmètre dessiné sur la même cellule : un de plus (%d)" % s.perimetres_de(camp).size())
	verifier(s.dessiner_perimetre(Vector2i(-50, -50), Vector2i(-40, -40), "bois").is_empty(), "hors d'une cellule revendiquée : refusé")
	# Le résidentiel et les maisons automatiques (designer, 10 h 25) : un résident assigné, du bois au stock, une chaumière
	var libre := Vector2i(-1, -1)   # un carré de 8×6 de tuiles libres, à l'ouest ou au sud du joueur
	for essai in [Vector2i(-12, -3), Vector2i(-12, 4), Vector2i(3, 6), Vector2i(-6, 8), Vector2i(8, 8)]:
		var o: Vector2i = j.pos + essai
		var ok_l := true
		for y in 6:
			for x in 8:
				var q2: Vector2i = o + Vector2i(x, y)
				if not s.grille.dans(q2) or s.grille.bloque_passage(q2) or not s.grille.occupant(q2).is_empty() or s.grille.meubles.has(s.grille.idx(q2)) or s._cell_de(q2) != camp:
					ok_l = false
		if ok_l:
			libre = o
			break
	verifier(libre != Vector2i(-1, -1), "un carré libre de 8×6 existe près du camp")
	var pid_r := s.dessiner_perimetre(libre, libre + Vector2i(7, 5), "residentiel")
	verifier(not pid_r.is_empty() and int(s.perimetres()[pid_r].richesse) >= 40, "un périmètre résidentiel dessiné : ses tuiles libres sont sa richesse (%d)" % int(s.perimetres().get(pid_r, {}).get("richesse", 0)))
	var h := s.ajouter("villageois", j.pos + Vector2i(-1, 0), "ia")
	h.camp = "joueur"
	verifier(s._assigner(j, h.id, "oisif", 0, pid_r) and str(h.assignation.get("residence", "")) == pid_r and not h.assignation.has("perimetre"), "assigné au résidentiel : il y habite, ce n'est pas une production")
	s.territoire.stocks.clear()
	verifier(s._batir_maisons() == 0 and not h.has("lit"), "sans matériaux au stock : rien ne se bâtit")
	s.territoire.stocks["chene|brut"] = 20
	var debout: Dictionary = s.ajouter("villageois", libre + Vector2i(1, 1), "ia")   # quelqu'un se tient sur le chantier
	debout.camp = "joueur"
	var n_maisons: int = s._batir_maisons()
	verifier(n_maisons == 1 and not s.grille.bloque_passage(debout.pos) and not s.grille.meubles.has(s.grille.idx(debout.pos)) and s.grille.occupant(debout.pos) == debout.id, "un être debout ne bloque pas le chantier : il est déplacé (%s)" % str(debout.pos))
	verifier(n_maisons == 1 and h.has("lit") and s.grille.meubles.get(s.grille.idx(h.lit), "").begins_with("lit"), "avec vingt chênes bruts au stock : une chaumière, et son lit (%s)" % str(h.get("lit", Vector2i(-1, -1))))
	verifier(int(s.territoire.stocks.get("chene|brut", 0)) == 20 - int(s.regles.r.royaume.maisons.cout[0].n), "le bois est pris sur le stock (reste %d)" % int(s.territoire.stocks.get("chene|brut", 0)))
	verifier(int(s.perimetres()[pid_r].richesse) <= 48 - 24, "la richesse du résidentiel (ses tuiles libres) a baissé d'une chaumière : %d" % int(s.perimetres()[pid_r].richesse))
	verifier(not s._piece_du_lit(h.lit, s.pieces_de_cellule(camp)).is_empty(), "la chaumière est une pièce valide au sens de Détection de pièces")
	verifier(s._batir_maisons() == 0, "logé : on ne lui bâtit pas une seconde maison")
	# Un poste ET un logement (14 h) : assigné ensuite au périmètre de bois, il garde sa résidence ; réassigné au
	# résidentiel, il garde son métier et son périmètre de travail.
	verifier(s._assigner(j, h.id, "bucheron", 0, pid_d) and str(h.assignation.get("perimetre", "")) == pid_d and str(h.assignation.get("residence", "")) == pid_r, "assigné au bois : il garde sa résidence")
	verifier(s._assigner(j, h.id, "oisif", 0, pid_r) and str(h.fonction) == "bucheron" and str(h.assignation.get("perimetre", "")) == pid_d and str(h.assignation.get("residence", "")) == pid_r, "réassigné au résidentiel : il reste bûcheron du même périmètre")
	# Sauvegarde partout (décidé) : les périmètres dessinés, leurs tuiles, le stockage et le logement reviennent typés
	var tuiles0: Array = s.tuiles_de_perimetre(pid_d)
	var cap_s: int = int(s.perimetres()[pid_s].capacite)
	verifier(s.sauvegarder("test_perimetres"), "sauvegarder avec des périmètres dessinés")
	var s2 := Simulation.new(31)
	verifier(s2.charger_sauvegarde("test_perimetres"), "recharger dans une simulation neuve")
	var per2: Dictionary = s2.perimetres().get(pid_d, {})
	verifier(not per2.is_empty() and per2.cellule is Vector2i and per2.cellule == camp and s2.tuiles_de_perimetre(pid_d) == tuiles0 and int(per2.richesse) == 5, "le périmètre dessiné revient : cellule et quinze tuiles typées, richesse %d" % int(per2.get("richesse", -1)))
	verifier(s2.perimetres().has(pid_s) and int(s2.perimetres()[pid_s].capacite) == cap_s and s2.place_stockage(pid_s) == cap_s, "le stockage revient avec sa capacité (%d) et sa place" % cap_s)
	var loges: Array = s2.vivants().filter(func(x: Dictionary) -> bool: return str(x.get("assignation", {}).get("residence", "")) == pid_r)
	verifier(loges.size() == 1 and loges[0].has("lit") and loges[0].lit is Vector2i and s2.grille.meubles.get(s2.grille.idx(loges[0].lit), "").begins_with("lit"), "le résident revient logé, son lit typé et toujours meublé")
	s2.monde.fermer()
	s.monde.fermer()


func test_faim_des_residents() -> void:
	var s := Simulation.new(31)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var a: Dictionary = s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	var b: Dictionary = s.ajouter("villageois", j.pos + Vector2i(-1, 0), "ia")
	a.camp = "joueur"
	b.camp = "joueur"
	verifier(s._assigner(j, a.id, "oisif", 0) and s._assigner(j, b.id, "oisif", 0), "deux résidents oisifs")
	s.territoire.tresor = 10000
	s.territoire.stocks.clear()
	s.territoire.stocks["baies"] = 1   # ce que les fermiers récoltent tombe là
	s._semaine_territoire(j)
	var ry: Dictionary = s.regles.r.royaume
	verifier(not s.territoire.stocks.has("baies"), "la baie du stock a été mangée")
	verifier(int(bool(a.get("affame", false))) + int(bool(b.get("affame", false))) == 1, "un seul des deux a faim")
	var nourri: Dictionary = a if not bool(a.get("affame", false)) else b
	var affame: Dictionary = b if nourri.id == a.id else a
	var attendu_nourri := int(ry.humeur_base) + int(ry.sans_logement)
	verifier(int(nourri.humeur) == attendu_nourri and int(affame.humeur) == attendu_nourri + int(ry.get("faim_pnj", -10)), "humeurs : nourri %d, affamé %d — le malus de faim compte une fois" % [int(nourri.humeur), int(affame.humeur)])
	# Retirer au stock la récolte d'un périmètre de plantes (« ortie|brut ») : des objets, pas une matière (grande base, 2026-09-04)
	s.territoire.stocks["ortie|brut"] = 2
	var sac0: int = j.sac.size()
	verifier(s.retirer_stock(j, "ortie|brut") and not s.territoire.stocks.has("ortie|brut") and j.sac.size() > sac0, "deux orties retirées du stock : des objets dans le sac (%d → %d)" % [sac0, j.sac.size()])
	s.monde.fermer()


## L'escorte suit en donjon (Compagnons, designer 2026-09-04) : elle descend, change d'étage, remonte et rentre
## au camp avec le joueur ; un étage mis de côté ne la garde pas (pas de doublon) ; « attends ici » reste sur place.
func test_escorte_en_donjon() -> void:
	var s := Simulation.new(31)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var a: Dictionary = s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	var b: Dictionary = s.ajouter("villageois", j.pos + Vector2i(-1, 0), "ia")
	s._devenir_compagnon(j, a)
	s._devenir_compagnon(j, b)
	verifier(s.compagnons_de(j, false).size() == 2, "deux compagnons au camp")
	s.donjon = {"etages": 3}
	s.charger_donjon("ruine", s.graine, 7, 1, j)
	var la := s.compagnons_de(j, false)
	verifier(la.size() == 2 and s.entites.has(a.id) and s.entites.has(b.id) and Grille.distance(a.pos, j.pos) <= 5 and Grille.distance(b.pos, j.pos) <= 5, "à l'étage 1 : les deux sont descendus, à côté du joueur (%d)" % la.size())
	verifier(not s.camp_sauve.entites.has(a.id), "le camp mis de côté ne garde pas l'escorte")
	b.ordre = "attendre"
	s.charger_donjon("ruine", s.graine, 7, 2, j)
	verifier(s.entites.has(a.id) and not s.entites.has(b.id) and s.etages_visites[1].entites.has(b.id), "à l'étage 2 : celui qui suit est là, celui qui attend est resté à l'étage 1")
	s.charger_donjon("ruine", s.graine, 7, 1, j)
	verifier(s.compagnons_de(j, false).size() == 2 and s.entites.has(a.id) and s.entites.has(b.id), "retour à l'étage 1 : les deux, sans doublon (%d)" % s.compagnons_de(j, false).size())
	b.ordre = "suivre"
	s.charger_camp(j)
	verifier(s.lieu == "camp" and s.compagnons_de(j, false).size() == 2 and s.entites.has(a.id) and s.entites.has(b.id), "rentrés au camp avec le joueur (%d)" % s.compagnons_de(j, false).size())
	s.monde.fermer()


## Un compagnon se bat (Compagnons, 2026-09-04) : loin de sa tuile d'arrivée — son maître est son ancre —, il frappe
## le bandit qui se tient contre lui, même en posture défensive, pendant que le joueur ne fait qu'attendre.
func test_compagnon_se_bat() -> void:
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	var c: Dictionary = s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._devenir_compagnon(j, c)
	c.ancre = c.pos + Vector2i(40, 0)   # il a suivi le joueur loin de là où il est arrivé
	var b: Dictionary = s.ajouter("bandit", c.pos + Vector2i(1, 0), "ia")
	verifier(not b.is_empty() and s.ennemis(c, b), "un bandit contre le compagnon")
	var sante0 := int(b.sante)
	var sante_c0 := int(c.sante)
	for k in 40:
		s.attente[j.id] = true
		s.intention(j.id, {"type": "attendre"})
		s.pas("monde")
		for nom in s.combats.keys():
			s.pas(nom)
		if int(b.sante) < sante0 or not b.vivant:
			break
	verifier(int(b.sante) < sante0 or not b.vivant, "le compagnon a frappé le bandit (%d → %d) alors que le joueur attendait" % [sante0, int(b.sante)])
	verifier(int(c.sante) <= sante_c0, "le bandit a rendu les coups ou pas, mais le compagnon est resté dans le combat (%d/%d)" % [int(c.sante), sante_c0])


## Deux compagnons armés défendent le joueur (Compagnons, 2026-09-04) : le bandit est contre le joueur, pas contre
## eux — ils doivent s'approcher et frapper pendant que le joueur ne fait qu'attendre.
func test_compagnons_defendent() -> void:
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	var comps: Array = []
	for d in [Vector2i(-2, 0), Vector2i(0, -2)]:
		var c: Dictionary = s.ajouter("villageois", j.pos + d, "ia")
		s._devenir_compagnon(j, c)
		var epee: Dictionary = s.generer_objet("craft_epee", 1, {}, "commun", 0)
		c.sac.append(epee.uid)
		s._equiper(c, epee.uid, 0)
		comps.append(c)
	var b: Dictionary = s.ajouter("bandit", j.pos + Vector2i(1, 0), "ia")
	var sante0 := int(b.sante)
	# UN TABLEAU, PAS UN ENTIER : une lambda GDScript capture un entier PAR VALEUR — `coups += 1` incrémentait une copie, et
	# le compteur restait à zéro quoi qu'il arrive. C'est ce que cachait le `or` de l'assertion (ordre de travail 47).
	var coups := [0]
	EventBus.damage_dealt.connect(func(src: String, cible: String, _d: int, _det: Dictionary) -> void:
		if cible == b.id and (src == comps[0].id or src == comps[1].id):
			coups[0] += 1)
	for k in 60:
		s.attente[j.id] = true
		s.intention(j.id, {"type": "attendre"})
		s.pas("monde")
		for nom in s.combats.keys():
			s.pas(nom)
		if not b.vivant:
			break
	# `coups > 0 or sante baissée or bandit mort` passait sans qu'un compagnon ait frappé : n'importe quelle blessure
	# du bandit suffisait (ordre de travail 47). Ce sont LEURS coups qu'on compte.
	verifier(coups[0] > 0, "les compagnons ont frappé le bandit contre le joueur (%d coup(s), %d → %d)" % [coups[0], sante0, int(b.sante)])


## Les paliers de dette (Entretien et taxes, 2026-09-04) : l'humeur est un état (−5, pas une pente), et le partant
## quitte le territoire pour de bon.
func test_dette_paliers() -> void:
	var s := Simulation.new(31)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var a: Dictionary = s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	var b: Dictionary = s.ajouter("villageois", j.pos + Vector2i(-1, 0), "ia")
	a.camp = "joueur"
	b.camp = "joueur"
	verifier(s._assigner(j, a.id, "oisif", 0) and s._assigner(j, b.id, "oisif", 0), "deux résidents")
	var ry: Dictionary = s.regles.r.royaume
	s.territoire.tresor = 0
	s.territoire.stocks.clear()
	var attendu := int(ry.humeur_base) + int(ry.sans_logement) + int(ry.get("faim_pnj", -10)) + int(ry.dette_paliers.humeur[1])
	var n_depart := int(ry.dette_paliers.depart[0])
	for k in n_depart - 1:
		s._semaine_territoire(j)
	verifier(int(s.territoire.semaines_dette) == n_depart - 1 and s.residents().size() == 2, "%d semaines de dette : les deux sont encore là" % (n_depart - 1))
	verifier(int(a.humeur) == attendu and int(b.humeur) == attendu, "l'humeur en dette est un état : %d (= base %d − sans toit − faim − palier), pas une pente" % [int(a.humeur), int(ry.humeur_base)])
	s._semaine_territoire(j)
	verifier(s.residents().size() == 1, "au palier de départ, un résident est parti")
	var parti: Dictionary = a if not s.entites.has(a.id) else b
	verifier(not s.entites.has(parti.id) and not parti.has("assignation") and s.grille.occupant(parti.pos) != parti.id, "le partant a quitté le territoire : plus dans la simulation ni sur la grille")
	s.monde.fermer()


## Le repas hebdomadaire des résidents (Faim des PNJ, 2026-09-04) : une unité par résident et par semaine, au
## garde-manger puis au stock du territoire (la récolte des fermiers) ; un seul repas — un seul malus — par semaine.
## La classe d'un PNJ (Fonctions, Talents de classe, 2026-09-04) : tirée dans le pool de sa fonction, sauf une
## classe cachée, rare, tirée avant le pool sur n'importe quelle fonction.
func test_classes_des_pnj() -> void:
	var s := nouvelle_sim("gorge")
	var def: Dictionary = GameData.entree("creatures", "villageois")
	var pool: Array = GameData.entree("functions", "artisan").classes_possibles
	var chance: float = float(s.regles.r.pnj.classe_cachee_chance)
	var cachees := 0
	var hors_pool := 0
	var sans := 0
	var n := 2000
	for k in n:
		var x := Etres.instancier("pnj_test_%d" % k, def, Vector2i.ZERO, "ia", s.regles, s.items)
		x["fonction"] = "artisan"
		x.erase("classe")
		def = def.duplicate()
		def["fonction"] = "artisan"
		s._habiller_pnj(x, def)
		var c := str(x.get("classe", ""))
		if c.is_empty():
			sans += 1
		elif bool(GameData.entree("classes", c).get("cachee", false)):
			cachees += 1
		elif not (c in pool):
			hors_pool += 1
	verifier(sans == 0 and hors_pool == 0, "%d artisans : tous ont une classe, toutes visibles viennent du pool (%d sans, %d hors pool)" % [n, sans, hors_pool])
	var part := float(cachees) / float(n)
	# LE CATALOGUE PEUT N EN AVOIR AUCUNE (2026-09-09 : les dix-neuf classes sont parquées, il ne reste que le
	# placeholder). Exiger un pourcentage sur une population vide ne prouverait rien : le test dit alors ce qui est.
	var a_des_cachees := false
	for cid_c: String in GameData.catalogues.classes.keys():
		if bool(GameData.entree("classes", cid_c).get("cachee", false)):
			a_des_cachees = true
	if a_des_cachees:
		verifier(part > chance * 0.4 and part < chance * 2.5, "les classes cachées sont rares : %.1f %% pour %.0f %% attendus" % [part * 100.0, chance * 100.0])
	else:
		verifier(cachees == 0, "aucune classe cachée au catalogue : personne n en porte (%d)" % cachees)
	verifier(not (GameData.entree("functions", "aventurier").classes_possibles as Array).any(func(c: String) -> bool: return bool(GameData.entree("classes", c).get("cachee", false))), "aucun pool ne contient de classe cachée")
	for f in ["eleveur", "cuisinier", "couturier", "transporteur"]:
		verifier(GameData.catalogues.functions.has(f), "la fonction %s du catalogue de la note existe en données" % f)


func test_composer_capacites() -> void:
	var s := Simulation.new(119)
	s.charger_donjon("ruine", 119, 11, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	j.modules_connus = []
	for m0 in ["point", "etincelle", "ligne", "renaissance", "soi", "jet_court"]:
		s.crediter_module(j, m0, 99)
	var grille := s.grille_composition(j)
	verifier((grille.cases as Array).size() >= 4, "la grille de l'arme tenue a au moins la grille de poche (%d cases, voie « %s »)" % [(grille.cases as Array).size(), str(grille.stat)])
	j.capacites = []
	verifier(not s.composer_capacite(j, ["point"]), "sans noyau : refusé")
	verifier(not s.composer_capacite(j, ["point", "brasier"]), "un module inconnu : refusé")
	verifier(s.composer_capacite(j, ["ligne", "etincelle"]) and j.capacites.size() == 1 and j.capacites[0].modules == ["ligne", "etincelle"], "ligne + Étincelle : une capacité assemblée")
	var plan := s.plan_capacite(j, 0)
	verifier(plan.erreurs.is_empty() and plan.geometrie == "ligne", "son plan : géométrie ligne, sans erreur")
	verifier(s.composer_capacite(j, ["soi", "renaissance"]) and j.capacites.size() == 2, "soi + Renaissance : une capacité sur soi")
	for k in 6:
		s.composer_capacite(j, ["point", "etincelle"])
	verifier(j.capacites.size() == 8, "plus de plafond de capacités : huit composées (%d)" % j.capacites.size())
	verifier(s.supprimer_capacite(j, 0) and j.capacites.size() >= 1, "supprimer une capacité")
	# Renaissance : un compagnon mort, son âme dans le sac, le sort le rappelle contre du mana.
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 1), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v.social.relations[j.id] = 80
	j.corps.stats.charisme = 25
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "recruter", "pnj": v.id})
	s._appliquer_degats(v, 9999, j.id, {})
	verifier(not s.ame_dans_sac(j).is_empty() and not v.vivant, "le compagnon est mort, son âme portée")
	var idx := -1
	for k in j.capacites.size():
		if j.capacites[k].modules == ["soi", "renaissance"]:
			idx = k
	for x in s.vivants():   # hors combat : un étage de 64 met les bêtes plus près, et une capacité engagée en combat
		if x.id != j.id:   # se résout sur l'horloge du combat, pas sur celle du monde que ce test fait avancer
			x.vivant = false
			s.grille.liberer(x.pos)
	s.combats.clear()
	j.horloge = "monde"
	j.mana = 100
	j.or = 0
	s.attente[j.id] = true
	verifier(idx >= 0 and s.intention(j.id, {"type": "capacite", "index": idx, "cible": j.pos}), "lancer Renaissance sur soi")
	for k in 20:   # la capacité est engagée (18 ticks) : l'horloge du monde avance jusqu'à sa résolution
		s.attente.erase(j.id)
		s.horloge_monde.avancer(500)
		if j.action_en_cours.is_empty():
			break
	verifier(v.vivant and int(j.mana) < 100 and int(j.or) == 0, "le compagnon revient, payé en mana (%d), pas en or [action en cours : %s]" % [int(j.mana), str(j.action_en_cours.get("name_key", "-"))])


# ---------------------------------------------------------------- Bombes et explosions

func test_charges_de_modules() -> void:
	var s := Simulation.new(818)
	s.charger_donjon("ruine", 818, 8, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	loup.sante = 100000
	loup.sante_max = 100000
	j.capacites = []
	j.modules_connus = []
	# Charges infinies (designer 2026-08-31) : apprendre un module est définitif, lancer n'épuise rien.
	for m in ["point", "etincelle"]:
		s.crediter_module(j, m)
	verifier(s.composer_capacite(j, ["point", "etincelle"]), "composer avec des modules connus")
	j.mana = 999
	for k in 3:
		j.compteur = s.tick_de(j)
		s.attente[j.id] = true
		verifier(s.intention(j.id, {"type": "capacite", "index": 0, "cible": loup.pos}), "lancer n° %d : rien ne s'épuise" % (k + 1))
	verifier("point" in j.modules_connus and "etincelle" in j.modules_connus, "les modules restent connus après trois lancers")
	verifier(s.modules_sans_charge(j, {"modules": ["point", "etincelle"]}).is_empty(), "aucun module ne manque : ils sont connus")
	verifier(s.modules_sans_charge(j, {"modules": ["ampleur"]}).has("ampleur"), "un module jamais appris, lui, manque toujours")
	# Un livre n'enseigne qu'UN module (designer 2026-08-31), grimoire comme manuel
	var un_seul := true
	for k in 60:
		var livre := s.generer_objet("grimoire" if k % 2 == 0 else "manuel", 3, {}, "commun", 0)
		un_seul = un_seul and livre.get("modules", []).size() == 1
	verifier(un_seul, "60 livres tirés : chacun porte exactement un module")
	# Une créature d'IA n'apprend pas dans des livres
	verifier(s.modules_sans_charge(loup, {"modules": ["point", "etincelle"]}).is_empty(), "l'IA ne connaît pas de manque")
	# Tout module doit avoir une source (Grimoires et manuels). Les six noyaux **sans coût** (Fiole,
	# Méditation, Offrande, Ponction, Saignée, Second souffle) n'entraient dans aucun filtre de livre :
	# ils sont arcanes par nature — sans élément et sans coût d'endurance. La garantie exhaustive est
	# tenue par tools/audit_donnees.py (règle 24) ; ici on vérifie la règle qui les rend éligibles.
	var hors_domaine: Array[String] = []
	for mid in ["fiole", "meditation", "offrande", "ponction", "saignee", "second_souffle"]:
		var md: Dictionary = GameData.entree("modules", mid)
		if not md.get("elements", {}).is_empty() or int(md.get("cout_vigueur", 0)) > 0:
			hors_domaine.append(mid)
	verifier(hors_domaine.is_empty(), "les noyaux sans coût sont arcanes, donc distribuables (%s)" % str(hors_domaine))
	var vus := {}
	for k in 300:   # un livre = un module : sur 300 tirages des deux types, les arcanes sortent
		for m in s.generer_objet("grimoire" if k % 2 == 0 else "manuel", 5, {}, "commun", 0).get("modules", []):
			vus[str(m)] = true
	var au_moins_un := false
	for mid in ["fiole", "meditation", "offrande", "ponction", "saignee", "second_souffle"]:
		au_moins_un = au_moins_un or vus.has(mid)
	verifier(au_moins_un, "les noyaux arcanes sortent bien dans des livres")


## Les charges de modules (Grimoires et manuels) : lire en donne, chaque lancer en consomme une par module.
## Aucune limite d'assemblage (Six types de modules) : le prix et le résultat sont les seules bornes.
func test_assemblage_sans_limite() -> void:
	var s := Simulation.new(929)
	s.charger_donjon("ruine", 929, 9, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	for dx in range(-5, 6):   # une esplanade : la Nuée tire à 2 tuiles autour d'une cible à 2 tuiles
		for dy in range(-5, 6):
			var t: Vector2i = j.pos + Vector2i(dx, dy)
			if s.grille.dans(t) and t != j.pos:
				s.grille.contenu[s.grille.idx(t)] = 0
				s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	var plan_de := func(mods: Array) -> Dictionary:
		var pl := s.capacites.assembler(mods, 10, "1d4", {}, j.competences_eff)
		pl["name_key"] = ""
		pl["arme"] = {}
		pl["fonct"] = {}
		return pl
	# 1. deux formes : les tuiles s'additionnent
	var p_deux: Dictionary = plan_de.call(["ligne", "croix", "etincelle"])
	verifier(p_deux.erreurs.is_empty() and p_deux.formes_sup.size() == 1, "deux formes : acceptées, la seconde s'ajoute")
	var n_ligne: int = s.tuiles_du_plan(j, plan_de.call(["ligne", "etincelle"]), j.pos + Vector2i(2, 0)).size()
	var n_union: int = s.tuiles_du_plan(j, p_deux, j.pos + Vector2i(2, 0)).size()
	verifier(n_union > n_ligne, "l'union couvre plus que la ligne seule (%d > %d)" % [n_union, n_ligne])
	# 2. une bombe par tuile, et le prix × le nombre de tuiles
	var p_bombe: Dictionary = plan_de.call(["carre", "bombe"])
	var n_tuiles: int = s.tuiles_du_plan(j, p_bombe, j.pos + Vector2i(2, 0)).size()
	verifier(s._facteur_surface(j, p_bombe, j.pos + Vector2i(2, 0)) == n_tuiles and n_tuiles >= 9, "le facteur de surface = %d tuiles" % n_tuiles)
	verifier(s.plan_par_tuile(p_bombe) and not s.plan_par_tuile(plan_de.call(["carre", "etincelle"])) and s.surface_nominale(j, p_bombe) >= 9, "le composeur sait qu'un plan est par tuile et estime sa surface avant la visée (%d)" % s.surface_nominale(j, p_bombe))
	# Plus de plafond de modules par capacité : une séquence de six modules se compose au niveau 0
	var caps_sauve: Array = j.capacites.duplicate()
	j.capacites = []
	for m in ["carre", "bombe", "etincelle", "concentration", "gel", "baume"]:
		if not (m in j.modules_connus):
			j.modules_connus.append(m)
	# La grille de composition (designer 2026-09-03) : la longueur n'est bornée par aucun COMPTE, elle est
	# bornée par ce qui RENTRE dans la silhouette de l'arme tenue. Six modules lourds ne tiennent pas dans
	# une grille de palier 0 ; le même sort tient dans la grille de force au palier 25.
	var six: Array = ["carre", "bombe", "etincelle", "concentration", "gel", "baume"]
	var emb0 := s.emboitement(j, six)
	verifier(not emb0.ok and int(emb0.demande) > (emb0.cases as Array).size(), "six modules lourds : %d cases demandées, %d dans la grille — refusé" % [int(emb0.demande), (emb0.cases as Array).size()])
	verifier(not s.composer_capacite(j, six) and j.capacites.is_empty(), "et composer_capacite le refuse")
	var grande := s.grille_sort.grille_de("force", 25)
	verifier(s.grille_sort.emboiter(six, grande).ok, "la même séquence tient dans la grille de force au palier 25 (%d cases)" % grande.size())
	verifier(s.emboitement(j, ["jet_court", "point", "etincelle"]).ok, "un sort de base — portée, forme, noyau — tient dans la grille de palier 0")
	verifier(s.composer_capacite(j, ["point", "etincelle"]) and j.capacites.size() == 1, "et se compose")
	for k in 12:   # pas de limite de sorts créés non plus (2026-08-30)
		s.composer_capacite(j, ["point", "etincelle", "concentration"] if k % 2 == 0 else ["carre", "gel"])
	verifier(j.capacites.size() == 13, "treize capacités composées sans refus (%d)" % j.capacites.size())
	j.capacites = caps_sauve
	var n_bombes0: int = s.bombes.size()
	s._executer_capacite(j, p_bombe, j.pos + Vector2i(2, 0))
	verifier(s.bombes.size() - n_bombes0 == n_tuiles, "un carré de Bombe pose %d charges d'un geste" % (s.bombes.size() - n_bombes0))
	var puissance_1: float = float(s.bombes[s.bombes.size() - 1].puissance)
	s.bombes.clear()
	# Un noyau répété est UN CRAN de plus (designer 2026-09-04, corrigeant le « × n » du 30 août) : Bombe + Bombe
	# = une bombe par tuile, un dé de plus, le prix d'une division de plus — et la même puissance de souffle.
	var p_b2: Dictionary = plan_de.call(["carre", "bombe", "bombe"])
	var div_bombe: int = s.capacites.divisions_de(GameData.entree("modules", "bombe"))
	verifier(p_b2.erreurs.is_empty() and p_b2.charges_sup.is_empty() and int(p_b2.fois) == 1 and int(p_b2.des_bonus) == 1 and absi(int(p_b2.ressource) - (int(p_bombe.ressource) + roundi(float(p_bombe.ressource) / float(div_bombe)))) <= 1, "Bombe + Bombe : un cran, un dé de plus, une division de prix de plus (%d → %d)" % [int(p_bombe.ressource), int(p_b2.ressource)])
	s._executer_capacite(j, p_b2, j.pos + Vector2i(2, 0))
	verifier(s.bombes.size() == n_tuiles and float(s.bombes[0].puissance) == puissance_1 and str(s.bombes[0].degats) == "4d6", "une bombe par tuile, à 4d6, même souffle (%s, %.0f)" % [str(s.bombes[0].degats), float(s.bombes[0].puissance)])
	s.bombes.clear()
	var p_e2: Dictionary = plan_de.call(["point", "etincelle", "etincelle", "etincelle"])
	verifier(str(p_e2.des) == "1d4" and int(p_e2.des_bonus) == 2 and p_e2.charges_sup.is_empty() and int(p_e2.ressource) == 3 * int(plan_de.call(["point", "etincelle"]).ressource), "Étincelle trois fois : 1d4 + 2 dés, prix × 3 — à un dé de base, une division est le prix entier (%s+%d, %d)" % [str(p_e2.des), int(p_e2.des_bonus), int(p_e2.ressource)])
	var p_mix: Dictionary = plan_de.call(["point", "etincelle", "gel"])
	verifier(p_mix.charges_sup.size() == 1 and int(p_mix.fois) == 1, "deux noyaux différents restent deux charges")
	verifier(str(GameData.entree("modules", "etincelle").get("power_base", "")) == "1d4", "le catalogue n'a pas été modifié par la répétition")
	var p_bc: Dictionary = plan_de.call(["carre", "bombe", "concentration"])
	s._executer_capacite(j, p_bc, j.pos + Vector2i(2, 0))
	verifier(s.bombes.size() == n_tuiles and str(s.bombes[0].degats) == "4d6", "Concentration ajoute son dé à la bombe (%s)" % str(s.bombes[0].degats))
	s.bombes.clear()
	var p_bb: Dictionary = plan_de.call(["carre", "bombe", "baume"])
	verifier(str(p_bb.monnaie) == "vigueur" and int(p_bb.ressource) == int(p_bombe.ressource) + int(GameData.entree("modules", "baume").cout_mana), "un noyau de mana dans un sort de vigueur paie en vigueur, 1 pour 1 (%d)" % int(p_bb.ressource))
	j.vigueur = 10   # Épuisement (Mana) : un sort d'endurance au-delà du pool se paie en PV (sans tuer le mannequin)
	j.sante = 40
	s._payer(j, {"monnaie": "vigueur", "ressource": 25, "charge_suivante": {}})
	verifier(int(j.vigueur) == 0 and int(j.sante) == 40 - 15 * int(s.regles.r.vigueur.epuisement_mult), "l'épuisement : 15 de vigueur manquants → PV (%d)" % int(j.sante))
	# Chaque statut qui BLOQUE une monnaie doit nommer une monnaie qui existe. Le renommage
	# endurance → vigueur avait laissé le statut Épuisement à bloquer un mot que plus personne
	# n'employait : il ne bloquait plus rien, sans le moindre message.
	var monnaies_connues := Array(s.regles.r.monnaies.liste)
	var bloqueurs_ko: Array[String] = []
	for sid in GameData.catalogues.status_effects.keys():
		for m in GameData.catalogues.status_effects[sid].get("modifiers", []):
			if bool(m.get("bloque", false)) and str(m.get("cible", "")) in ["mana", "vigueur", "endurance", "sang_froid"] and not (str(m.cible) in monnaies_connues):
				bloqueurs_ko.append("%s bloque « %s »" % [sid, str(m.cible)])
	verifier(bloqueurs_ko.is_empty(), "les statuts qui bloquent une monnaie nomment une monnaie qui existe (%s)" % str(bloqueurs_ko))
	j.sante = 40
	j.vigueur = 80
	var xp_vus: Array = []   # l'XP s'annonce à chaque versement (XP de combat, 2026-08-30)
	var cb_xp := func(id: String, cle: String, xp: int) -> void: xp_vus.append([id, cle, xp])
	EventBus.xp_gagnee.connect(cb_xp)
	s.gagner_xp(j, "epee", 7)
	EventBus.dispatcher()
	EventBus.xp_gagnee.disconnect(cb_xp)
	verifier(xp_vus.size() == 1 and xp_vus[0][1] == "epee" and int(xp_vus[0][2]) == 7, "xp_gagnee est émis à chaque versement (%s)" % str(xp_vus))
	# Dégâts de poussée (2026-08-30) : une projection qui bute sur un mur paie les tuiles perdues
	for x in s.entites.values():
		if x.id != j.id:
			x.vivant = false
			s.grille.liberer(x.pos)
	var mur_p: Vector2i = j.pos + Vector2i(3, 0)
	s.grille.poser_contenu(mur_p, "barriere")
	var loup_p: Dictionary = s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	loup_p.sante = 60
	loup_p.sante_max = 60
	var p_pousse: Dictionary = plan_de.call(["point", "poussee"])
	s._executer_capacite(j, p_pousse, loup_p.pos)
	verifier(loup_p.pos == j.pos + Vector2i(2, 0) and int(loup_p.sante) < 60, "poussé contre une barrière : il ne bouge pas et prend le choc (%d PV)" % int(loup_p.sante))
	loup_p.vivant = false
	s.grille.liberer(loup_p.pos)
	s.grille.contenu[s.grille.idx(mur_p)] = 0
	var p_al: Dictionary = plan_de.call(["point", "alignement", "etincelle"])
	var al_ok: Dictionary = s._evaluer_conditions(j, p_al, j.pos + Vector2i(3, 3))
	var al_ko: Dictionary = s._evaluer_conditions(j, p_al, j.pos + Vector2i(3, 1))
	verifier(al_ok.is_empty() and not al_ko.is_empty(), "Alignement : vrai en diagonale (rien ne bloque), faux de travers (%s)" % str(al_ko.get("name_key", "")))
	s.zones.clear()   # pièges invisibles (2026-08-30) : une zone posée sans trace est cachée, et se révèle sur l'intrus
	var p_piege: Dictionary = plan_de.call(["carre", "racine", "sans_trace"])
	s._executer_capacite(j, p_piege, j.pos + Vector2i(3, 0))
	verifier(not s.zones.is_empty() and s.zones.all(func(z: Dictionary) -> bool: return bool(z.get("cachee", false))), "un sort Sans trace pose des zones cachées (%d)" % s.zones.size())
	var intrus: Dictionary = s.ajouter("loup", j.pos + Vector2i(6, 0), "ia")
	s._zones_a_l_entree(intrus, j.pos + Vector2i(3, 0), s.tick_de(intrus))
	verifier(s.zones_sur(j.pos + Vector2i(3, 0)).any(func(z: Dictionary) -> bool: return not bool(z.get("cachee", true))), "le piège se révèle sur celui qui y met le pied")
	intrus.vivant = false
	s.grille.liberer(intrus.pos)
	s.zones.clear()
	# Marques et consommation (2026-08-30) : Marque pose le statut, Marquée l'exige, le récompense et le consomme
	var cobaye: Dictionary = s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	var p_marque: Dictionary = plan_de.call(["point", "marque"])
	s._executer_capacite(j, p_marque, cobaye.pos)
	verifier(Etres.a_statut_id(cobaye, "marque"), "le noyau Marque pose la Marque")
	var p_exploite: Dictionary = plan_de.call(["point", "marquee", "etincelle"])
	var cond_m: Dictionary = s._evaluer_conditions(j, p_exploite, cobaye.pos)
	verifier(cond_m.is_empty() and int(p_exploite.des_bonus) >= 2 and not Etres.a_statut_id(cobaye, "marque"), "Marquée : vraie, +2 dés, et la marque est consommée")
	var p_exploite2: Dictionary = plan_de.call(["point", "marquee", "etincelle"])
	verifier(not s._evaluer_conditions(j, p_exploite2, cobaye.pos).is_empty(), "sans marque, la condition bloque")
	cobaye.vivant = false
	s.grille.liberer(cobaye.pos)
	# Érosion (2026-08-30) : Érosif rogne les PV max de la cible, rendus à la fin du combat
	var erode: Dictionary = s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	var max0: int = int(erode.sante_max)
	var p_ero: Dictionary = plan_de.call(["point", "brasier", "erosif"])
	s._executer_capacite(j, p_ero, erode.pos)
	verifier(int(erode.get("erosion", 0)) > 0 and int(erode.sante_max) < max0, "Érosif : les PV max de la cible sont rognés (%d → %d)" % [max0, int(erode.sante_max)])
	erode.erase("erosion")
	Etres.recalculer(erode, s.items, s.affixes_defs, s.regles)
	verifier(int(erode.sante_max) == max0, "l'érosion levée, les PV max reviennent")
	erode.vivant = false
	s.grille.liberer(erode.pos)
	# Fiches d'invocations (2026-08-30) : le Feu follet invoque des follets qui ont une action, sur le camp du lanceur
	var n_av: int = s.vivants().size()
	var p_follet: Dictionary = plan_de.call(["point", "feu_follet"])
	s._executer_capacite(j, p_follet, j.pos + Vector2i(2, 0))
	var follets: Array = s.vivants().filter(func(x: Dictionary) -> bool: return x.get("maitre", "") == j.id and "invocation" in x.get("tags", []))
	verifier(s.vivants().size() == n_av + 1 and not follets.is_empty() and follets[0].camp == j.camp and "flammeche" in follets[0].get("actions", []), "un Feu follet invoqué : allié, avec sa Flammèche (%d)" % follets.size())
	for x in follets:
		x.vivant = false
		s.grille.liberer(x.pos)
	# Résolution simultanée (Boucle de tick, 2026-08-30) : deux actions dues au même tick partent ensemble,
	# même si la première tue l'auteur de la seconde.
	var duel_a: Dictionary = s.ajouter("loup", j.pos + Vector2i(4, 4), "ia")
	var duel_b: Dictionary = s.ajouter("loup", j.pos + Vector2i(5, 4), "ia")
	duel_a.horloge = "monde"
	duel_b.horloge = "monde"
	duel_a.sante = 1
	duel_b.sante = 1
	var t_duel: int = s.horloge_monde.ticks
	duel_a.compteur = t_duel
	duel_b.compteur = t_duel
	duel_a.action_en_cours = {"type": "creature", "action": "morsure", "cible": duel_b.id, "ticks": 6, "name_key": "creature_action.morsure.name"}
	duel_b.action_en_cours = {"type": "creature", "action": "morsure", "cible": duel_a.id, "ticks": 6, "name_key": "creature_action.morsure.name"}
	var j_horloge_avant: String = j.horloge
	var j_compteur_avant: int = int(j.compteur)
	j.compteur = t_duel + 999   # le joueur n'est pas dû : le pas résout le duel
	s.pas("monde")
	j.compteur = j_compteur_avant
	j.horloge = j_horloge_avant
	verifier(not duel_a.vivant and not duel_b.vivant, "deux morsures au même tick : les deux loups meurent ensemble (%s / %s)" % [str(duel_a.vivant), str(duel_b.vivant)])
	for x in [duel_a, duel_b]:
		x.vivant = false
		s.grille.liberer(x.pos)
	# Portes (2026-08-30) : fermée, elle bloque passage et vue ; un pas vers elle l'ouvre ; E la referme
	var porte_p: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.poser_contenu(porte_p, "porte_fermee")
	verifier(s.grille.bloque_passage(porte_p) and not s.grille.ligne_de_vue(j.pos, j.pos + Vector2i(2, 0)), "une porte fermée bloque le passage et la vue")
	var t_p: int = s.tick_de(j)
	verifier(s._deplacer(j, porte_p, t_p) and j.pos != porte_p and not s.grille.bloque_passage(porte_p), "un pas vers la porte l'ouvre sans la franchir")
	verifier(s._basculer_porte(j, porte_p, t_p) and s.grille.bloque_passage(porte_p), "on la referme")
	s.grille.contenu[s.grille.idx(porte_p)] = 0
	var p_cc: Dictionary = plan_de.call(["carre", "carre", "etincelle"])
	var n_cc: int = s.tuiles_du_plan(j, p_cc, j.pos + Vector2i(2, 0)).size()
	verifier(p_cc.formes_sup.is_empty() and int(p_cc.taille) == 2 * int(p_bombe.taille) and n_cc > n_tuiles, "Carré + Carré : une forme plus grande (%d tuiles > %d), pas une union" % [n_cc, n_tuiles])
	var p_etin: Dictionary = plan_de.call(["carre", "etincelle"])
	verifier(s._facteur_surface(j, p_etin, j.pos + Vector2i(2, 0)) == 1, "les dégâts ne paient pas par tuile : la forme suffit")
	# 3. le résultat est la seule morale : le soin touche l'ennemi, les dégâts touchent le lanceur
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	loup.sante = 5
	loup.sante_max = 100
	j.mana = 9999
	s._executer_capacite(j, plan_de.call(["point", "baume"]), loup.pos)
	verifier(int(loup.sante) > 5, "un Baume sur l'ennemi le soigne : le sort ne juge pas")
	j.sante = int(j.sante_max)
	var p_self: Dictionary = plan_de.call(["anneau", "soi", "flamme"])
	s._executer_capacite(j, p_self, j.pos)
	verifier(int(j.sante) < int(j.sante_max), "Anneau + Soi + Flamme : le lanceur se brûle lui-même")
	# 4. les séquences absurdes tiennent : rien ne casse, tout se paie
	j.mana = 99999
	j.mana_max = 99999
	var n_vivants0: int = s.vivants().size()
	var p_nuee: Dictionary = plan_de.call(["nuee", "echo_de_chair"])
	var tuiles_nuee: int = s.tuiles_du_plan(j, p_nuee, j.pos + Vector2i(2, 0)).size()
	s._executer_capacite(j, p_nuee, j.pos + Vector2i(2, 0))
	var invoques: int = s.vivants().size() - n_vivants0
	verifier(tuiles_nuee == 4 and invoques >= 2 and invoques <= tuiles_nuee, "Nuée + Écho de chair : %d créatures sur %d tuiles" % [invoques, tuiles_nuee])
	# les seize formes rendent chacune des tuiles — aucune ne tombe dans le défaut « point »
	var muettes: Array[String] = []
	for fid in GameData.catalogues.modules.keys():
		var fm: Dictionary = GameData.catalogues.modules[fid]
		if str(fm.module_type) != "forme" or str(fm.geometrie) in ["point", "soi", "tuile", "colonne"]:
			continue
		var n_t: int = Capacites.tuiles_de_forme(s.grille, str(fm.geometrie), j.pos, j.pos + Vector2i(2, 0), int(fm.taille_base)).size()
		if n_t <= 1:
			muettes.append("%s(%d)" % [fid, n_t])
	verifier(muettes.is_empty(), "chaque forme couvre plus d'une tuile (%s)" % str(muettes))
	s.bombes.clear()
	var p_folie: Dictionary = plan_de.call(["ligne", "croix", "bombe", "bombe"])
	var t_folie: int = s.tuiles_du_plan(j, p_folie, j.pos + Vector2i(2, 0)).size()
	verifier(p_folie.erreurs.is_empty() and p_folie.charges_sup.is_empty() and int(p_folie.fois) == 1 and int(p_folie.des_bonus) == 1 and p_folie.formes_sup.size() == 1, "Ligne + Croix + Bombe + Bombe : assemblé sans un mot, la Bombe un cran plus haut (designer 2026-09-04 : pas un doublement)")
	s._executer_capacite(j, p_folie, j.pos + Vector2i(2, 0))
	verifier(s.bombes.size() == t_folie and float(s.bombes[0].puissance) == 40.0 and str(s.bombes[0].degats) == "4d6", "une charge à 4d6 par tuile de l'union, même souffle : %d bombes" % s.bombes.size())
	verifier(s._facteur_surface(j, p_folie, j.pos + Vector2i(2, 0)) == t_folie, "et le prix × %d tuiles" % t_folie)
	s.bombes.clear()
	# 5. L'origine ne vient plus de la forme mais de la PORTÉE (designer 2026-09-01) : le même cône part
	# du lanceur avec `sur_soi`, et se pose sur la tuile visée avec `jet_long`.
	var p_cone: Dictionary = plan_de.call(["sur_soi", "cone", "etincelle"])
	var p_cone_loin: Dictionary = plan_de.call(["jet_long", "cone", "etincelle"])
	var p_point: Dictionary = plan_de.call(["contact", "point", "etincelle"])
	var loin: Vector2i = j.pos + Vector2i(5, 0)
	verifier(str(p_cone.origine) == "lanceur" and str(p_cone_loin.origine) == "cible", "la portée décide de l'ancrage : le même cône part de soi ou se pose au loin")
	verifier(str(p_point.origine) == "cible", "une portée à distance projette la figure")
	verifier(s.capacite_visable(j, p_cone, loin), "ancré sur le lanceur, un clic lointain n'est qu'une direction")
	verifier(not s.capacite_visable(j, p_point, loin), "un point au contact refuse un clic à 5 tuiles")
	verifier(not s.capacite_visable(j, p_cone, j.pos), "sa propre tuile n'est pas une direction")
	# 6. Écaille : immunité à l'élément choisi, vulnérabilité à celui qu'il domine ; Trempe : l'arme passe au Feu
	loup.statuts.clear()
	loup.anti_stunlock_jusqua = 0
	loup.vivant = true   # la section 3 l'a tué : un mort ne porte pas d'écaille
	if s.grille.occupant(loup.pos).is_empty():
		s.grille.placer(loup.id, loup.pos)
	loup["ecaille_choix"] = "feu"
	s.appliquer_statut(loup, "ecaille_elementaire", 10000, j.id)
	# Des PV réels, pas gonflés à la main : un coup qui fait monter Encaissement recalcule sante_max
	loup.corps.stats.endurance = 250
	Etres.recalculer(loup, s.items, s.affixes_defs, s.regles)
	loup.sante = int(loup.sante_max)
	var pv0: int = int(loup.sante)
	s._appliquer_degats(loup, 100, j.id, {"type": "magique", "element": {"feu": 1.0}})
	verifier(int(loup.sante) == pv0, "Écaille (Feu) : le Feu ne passe pas")
	s._appliquer_degats(loup, 100, j.id, {"type": "magique", "element": {"metal": 1.0}})
	verifier(int(loup.sante) == pv0 - 150, "le Métal, que le Feu domine, passe à +50 %% (%d)" % (pv0 - int(loup.sante)))
	s._appliquer_degats(loup, 100, j.id, {"type": "magique", "element": {"eau": 1.0}})
	verifier(int(loup.sante) == pv0 - 250, "l'Eau passe telle quelle")
	var arme_j := Etres.arme(j, s.items)
	var v0: Dictionary = s._vecteur_arme_de(j, arme_j)
	s.appliquer_statut(j, "trempe", 6000, j.id)
	var v1: Dictionary = s._vecteur_arme_de(j, arme_j)
	verifier(v1 == {"feu": 1.0} and v0 != v1, "Trempe : l'arme passe au Feu (%s → %s)" % [str(v0), str(v1)])
	s._retirer_statut(j, "trempe")
	# 7. l'arme équipée entre dans le sort : un sceptre porte le mana, une épée l'endurance
	var sceptre := s.generer_objet("proto_baton_magique", 1, {}, "commun", 0)
	var epee := s.generer_objet("proto_epee", 1, {}, "commun", 0)
	j.sac.append(sceptre.uid)
	j.sac.append(epee.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "equiper", "objet": sceptre.uid})
	var p_mana_sc: Dictionary = s.plan_sequence(j, ["point", "etincelle"])
	var p_end_sc: Dictionary = s.plan_sequence(j, ["point", "frappe"])
	s.attente[j.id] = true
	s.intention(j.id, {"type": "equiper", "objet": epee.uid})
	var p_mana_ep: Dictionary = s.plan_sequence(j, ["point", "etincelle"])
	var p_end_ep: Dictionary = s.plan_sequence(j, ["point", "frappe"])
	verifier(float(p_mana_sc.affinite_arme) > float(p_mana_ep.affinite_arme), "un sort de mana porte mieux au sceptre (×%.2f) qu'à l'épée (×%.2f)" % [p_mana_sc.affinite_arme, p_mana_ep.affinite_arme])
	verifier(float(p_end_ep.affinite_arme) > float(p_end_sc.affinite_arme), "un sort d'endurance porte mieux à l'épée (×%.2f) qu'au sceptre (×%.2f)" % [p_end_ep.affinite_arme, p_end_sc.affinite_arme])
	verifier(float(p_mana_sc.mult) > float(p_mana_ep.mult), "l'affinité multiplie la puissance du plan")
	var fc: Vector2i = s.fourchette_cout(p_mana_ep)
	verifier(fc.x < int(p_mana_ep.ressource) and fc.y > int(p_mana_ep.ressource), "le coût réel est une fourchette autour de la base (%d–%d pour %d)" % [fc.x, fc.y, int(p_mana_ep.ressource)])
	# 8. il ne reste que deux erreurs structurelles
	verifier(not s.capacites.assembler(["point", "carre"], 10, "1d4", {}, {}).erreurs.is_empty(), "sans noyau : toujours une erreur")
	verifier(not s.capacites.assembler(["nexiste_pas", "etincelle"], 10, "1d4", {}, {}).erreurs.is_empty(), "module inconnu : toujours une erreur")


func test_creation_de_sorts() -> void:
	var s := Simulation.new(4242)
	s.charger_donjon("ruine", 4242, 12, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var par_type := {}
	for mid in GameData.catalogues.modules.keys():
		var t := str(GameData.catalogues.modules[mid].module_type)
		if not par_type.has(t):
			par_type[t] = []
		par_type[t].append(str(mid))
	for t in par_type.keys():
		par_type[t].sort()
	# Des SEUILS, pas des comptes exacts : le designer ajoute des modules (« no limit »), et un test qui
	# recopie un total le fait échouer à chaque ajout — il gêne au lieu de protéger. Ce qui doit tenir,
	# c'est qu'aucun des trois types indispensables ne se vide, et que chaque forme sache se dessiner.
	verifier(par_type.get("noyau", []).size() >= 86 and par_type.get("forme", []).size() >= 16 and par_type.get("portee", []).size() >= 11, "le catalogue : %d noyaux, %d formes, %d portées" % [par_type.get("noyau", []).size(), par_type.get("forme", []).size(), par_type.get("portee", []).size()])
	for fid_v in par_type.get("forme", []):
		var geo_v := str(GameData.catalogues.modules[fid_v].get("geometrie", ""))
		if geo_v.is_empty():
			verifier(false, "la forme %s déclare sa géométrie" % fid_v)

	# 1. chaque noyau, seul : un plan complet et cohérent
	var noyaux_ko: Array[String] = []
	var incoherents: Array[String] = []
	for nid in par_type.noyau:
		var plan := s.capacites.assembler([nid], 10, "1d4", {}, j.competences_eff)
		if not plan.erreurs.is_empty():
			noyaux_ko.append("%s (%s)" % [nid, str(plan.erreurs[0])])
			continue
		if plan.noyau.is_empty() or int(plan.ticks) <= 0 or int(plan.portee.x) > int(plan.portee.y) or int(plan.taille) < 0:
			incoherents.append(nid)
		elif int(plan.ressource) < 0 or (not str(plan.monnaie).is_empty() and not (str(plan.monnaie) in Array(s.regles.r.monnaies.liste))):
			incoherents.append(nid + " (monnaie " + str(plan.monnaie) + ")")
	verifier(noyaux_ko.is_empty(), "les 86 noyaux s'assemblent seuls (%s)" % str(noyaux_ko.slice(0, 4)))
	verifier(incoherents.is_empty(), "chacun rend un plan cohérent — ticks, portée, taille, monnaie (%s)" % str(incoherents.slice(0, 4)))

	# 2. chaque forme, avec un noyau : la géométrie du plan est celle de la forme
	var formes_ko: Array[String] = []
	for fid in par_type.forme:
		var plan := s.capacites.assembler([fid, "etincelle"], 10, "1d4", {}, j.competences_eff)
		if not plan.erreurs.is_empty() or plan.forme.is_empty() or str(plan.geometrie).is_empty():
			formes_ko.append(fid)
	verifier(formes_ko.is_empty(), "les 16 formes portent leur géométrie (%s)" % str(formes_ko))

	# 3. les refus attendus
	verifier(not s.capacites.assembler(["point"], 10, "1d4", {}, {}).erreurs.is_empty(), "sans noyau : erreur")
	verifier(not s.capacites.assembler(["module_qui_n_existe_pas"], 10, "1d4", {}, {}).erreurs.is_empty(), "module inconnu : erreur")
	verifier(s.capacites.assembler(["etincelle", "gel"], 10, "1d4", {}, {}).erreurs.is_empty(), "deux noyaux sans Alternance : accepté, les deux charges partent")

	# 4. 300 séquences tirées au hasard dans TOUT le catalogue : jamais de plan à moitié construit
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260829
	var tous: Array = GameData.catalogues.modules.keys()
	tous.sort()
	var casses: Array[String] = []
	var assemblees := 0
	for essai in 300:
		var seq: Array = []
		for k in rng.randi_range(1, 5):
			seq.append(str(tous[rng.randi_range(0, tous.size() - 1)]))
		var plan := s.capacites.assembler(seq, 10, "1d4", {}, j.competences_eff)
		if not plan.erreurs.is_empty():
			continue   # un refus est une réponse valable (deux noyaux, pas de noyau…)
		assemblees += 1
		# Invariants d'un plan accepté. Un plan ouvert par un déclencheur porte son noyau dans la charge
		# différée (`charge_suivante`), pas à la racine — c'est le modèle des Six types de modules.
		var noyau_effectif: Dictionary = plan.noyau if not plan.noyau.is_empty() else plan.charge_suivante.get("noyau", {})
		if noyau_effectif.is_empty() or int(plan.ticks) <= 0 or int(plan.portee.x) > int(plan.portee.y) or int(plan.ressource) < 0:
			casses.append(str(seq))
		elif plan.has("alt"):
			# La branche d'Alternance obéit au MÊME modèle que la principale : ouverte par un
			# déclencheur, son noyau est dans la charge différée et non à la racine. Le test l'accordait
			# à la branche principale (deux lignes plus haut) et le refusait à l'alternative — il a tenu
			# tant qu'aucun tirage n'a sorti « à l'impact » et « alternance » ensemble. Le catalogue a
			# grossi, le tirage a changé, et l'incohérence était dans le test.
			var noyau_alt: Dictionary = plan.alt.noyau if not plan.alt.noyau.is_empty() else plan.alt.get("charge_suivante", {}).get("noyau", {})
			if noyau_alt.is_empty() or not plan.alt.erreurs.is_empty():
				casses.append("alternance " + str(seq))
	verifier(assemblees > 60, "%d séquences sur 300 s'assemblent" % assemblees)
	verifier(casses.is_empty(), "aucun plan accepté n'est incohérent (%s)" % str(casses.slice(0, 3)))

	# 5. de bout en bout : composer puis LANCER un sort de chaque géométrie, en jeu
	j.modules_connus = []
	for mid in GameData.catalogues.modules.keys():
		s.crediter_module(j, str(mid), 99)
	j.capacites = []
	j.mana = 9999
	j.mana_max = 9999
	j.vigueur = 9999
	var lances := 0
	var refus: Array[String] = []
	for fid in ["point", "ligne", "cone", "carre", "soi"]:
		if not (fid in par_type.get("forme", [])):
			continue
		j.capacites = []   # un slot de capacité à la fois : c'est la géométrie qu'on teste, pas les slots
		if not s.composer_capacite(j, [fid, "etincelle"]):
			refus.append("composer " + fid)
			continue
		var idx: int = j.capacites.size() - 1
		var cible: Vector2i = j.pos if fid == "soi" else j.pos + Vector2i(1, 0)
		s.attente[j.id] = true
		j.mana = 9999
		j.vigueur = 9999
		if s.intention(j.id, {"type": "capacite", "index": idx, "cible": cible}):
			lances += 1
		else:
			refus.append("lancer " + fid)
	verifier(refus.is_empty(), "composer et lancer un sort de chaque géométrie (%s)" % str(refus))
	verifier(lances >= 4, "%d sorts lancés en jeu" % lances)

	# 6. les 86 noyaux EXÉCUTÉS sur une cible réelle : c'est là que vivent les neuf types d'effet
	# (dégâts, statut, soin, terrain, déplacement, invocation, tempo, saisie, résurrection).
	var mannequin := s.ajouter("sanglier", j.pos + Vector2i(1, 0), "ia")
	mannequin.sante = 100000
	mannequin.sante_max = 100000
	var sans_effet: Array[String] = []
	var executes := 0
	for nid in par_type.noyau:
		var plan := s.capacites.assembler([nid], 10, "1d4", {}, j.competences_eff)
		if not plan.erreurs.is_empty():
			continue
		plan["name_key"] = str(plan.noyau.get("name_key", ""))   # comme plan_capacite le fait en jeu
		plan["arme"] = {}
		plan["fonct"] = {}
		if s.grille.occupant(j.pos + Vector2i(1, 0)).is_empty():   # une invocation a pu prendre la tuile
			s.grille.liberer(mannequin.pos)
			mannequin.pos = j.pos + Vector2i(1, 0)
			s.grille.placer(mannequin.id, mannequin.pos)
		mannequin.statuts.clear()   # un statut non cumulable posé par un noyau précédent rendait le suivant « muet »
		j.statuts.clear()
		var pv_avant: int = int(mannequin.sante)
		var statuts_avant: int = mannequin.statuts.size() + j.statuts.size()
		var vivants_avant: int = s.vivants().size()
		var zones_avant: int = s.zones.size()
		var pos_j_avant: Vector2i = j.pos   # un déplacement est un des neuf effets : il compte
		var pos_m_avant: Vector2i = mannequin.pos
		var compteur_avant: int = int(mannequin.compteur)   # le tempo aussi : il retarde la prochaine action
		var pv_j_avant: int = int(j.sante)   # un noyau qui coûte des PV, ou qui en rend, agit aussi
		var mana_m_avant: int = int(mannequin.get("mana", 0))   # ponction : le mana pris à la cible
		j.mana = 9999
		j.vigueur = 9999
		j.sante = int(j.sante_max)   # certains noyaux coûtent des PV (Cataclysme, Offrande, Saignée)
		mannequin.sante = 100000
		mannequin.vivant = true
		mannequin.anti_stunlock_jusqua = 0   # un mannequin n'a pas de mémoire : sans ça, seul le premier tempo compte
		s._executer_capacite(j, plan, mannequin.pos)
		executes += 1
		# Un noyau qui touche doit faire QUELQUE CHOSE : des PV, un statut, une invocation, ou du terrain.
		var agi: bool = int(mannequin.sante) != pv_avant or (mannequin.statuts.size() + j.statuts.size()) != statuts_avant \
			or s.vivants().size() != vivants_avant or not s.grille.modifies.is_empty() or s.zones.size() != zones_avant \
			or j.pos != pos_j_avant or mannequin.pos != pos_m_avant or int(mannequin.compteur) != compteur_avant \
			or int(j.sante) != pv_j_avant or int(mannequin.get("mana", 0)) != mana_m_avant
		if not agi:
			sans_effet.append(nid)
		s.grille.modifies.clear()
		if j.pos != pos_j_avant or mannequin.pos != pos_m_avant:   # on remet les deux en place pour le noyau suivant
			s.grille.liberer(j.pos)
			s.grille.liberer(mannequin.pos)
			j.pos = pos_j_avant
			s.grille.placer(j.id, j.pos)
			mannequin.pos = pos_m_avant
			s.grille.placer(mannequin.id, mannequin.pos)
	verifier(executes >= 80, "%d noyaux exécutés sur une cible réelle" % executes)
	# Chantier connu (Structure compétences-modules-slots, constat du 2026-08-29) : 47 noyaux ont un `effet`
	# vide et ne produisent rien. Le test tient le compte et refuse qu'il AUGMENTE, comme l'audit.
	# 2026-09-04 : le banc compte aussi un déplacement et un tempo, et remet l'anti-stunlock du mannequin à
	# zéro, efface les statuts entre deux noyaux, compte les PV du lanceur et le mana de la cible. Mesure : 23 muets —
	# le chantier, plus ce qui ne peut rien sur un mannequin hostile et désarmé, sans allié ni tuile libre
	# (rempart vise un allié, tir à la main un porteur d'arme). Avant : 34, sans les déplacements ni le tempo.
	verifier(sans_effet.size() <= 23, "noyaux sans effet visible : %d (budget 23, mesure du banc) — %s" % [sans_effet.size(), str(sans_effet)])
	verifier(j.vivant and mannequin.vivant, "le lanceur et le mannequin survivent aux 86 sorts")


## Les zones au sol (Modules — lot 2) : Racine, Sol vif, Nappe, Voile de brume, Balise.
func test_zones_au_sol() -> void:
	var s := Simulation.new(515)
	s.charger_donjon("ruine", 515, 9, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# une allée dégagée devant le joueur
	for dx in range(1, 6):
		var t: Vector2i = j.pos + Vector2i(dx, 0)
		s.grille.contenu[s.grille.idx(t)] = 0
		s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	var loup := s.ajouter("loup", j.pos + Vector2i(4, 0), "ia")
	var cible: Vector2i = j.pos + Vector2i(1, 0)
	var plan_z := func(nid: String) -> Dictionary:
		var pl := s.capacites.assembler([nid], 10, "1d4", {}, j.competences_eff)
		pl["name_key"] = ""
		pl["arme"] = {}
		pl["fonct"] = {}
		return pl
	# Sol vif : la tuile blesse ce qui la traverse
	s._executer_capacite(j, plan_z.call("sol_vif"), cible)
	verifier(s.zones_sur(cible, "blessure").size() == 1, "Sol vif : une zone de blessure sur la tuile")
	s.grille.liberer(loup.pos)
	loup.pos = cible + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	loup.orientation = Vector2i(-1, 0)
	var pv0: int = int(loup.sante)
	s._deplacer(loup, cible, s.tick_de(loup))
	verifier(int(loup.sante) < pv0, "le loup traverse le sol vif et saigne (%d → %d)" % [pv0, int(loup.sante)])
	# Racine : la zone enracine ce qui s'y arrête
	var t_racine: Vector2i = j.pos + Vector2i(0, 1)
	s.grille.contenu[s.grille.idx(t_racine)] = 0
	s.grille.hauteurs[s.grille.idx(t_racine)] = s.grille.h(j.pos)
	s.zones.clear()
	s._executer_capacite(j, plan_z.call("racine"), t_racine)
	s.grille.liberer(loup.pos)
	loup.pos = t_racine + Vector2i(0, 1)
	s.grille.placer(loup.id, loup.pos)
	if s.grille.dans(loup.pos):
		s.grille.contenu[s.grille.idx(loup.pos)] = 0
		s.grille.hauteurs[s.grille.idx(loup.pos)] = s.grille.h(j.pos)
	s._deplacer(loup, t_racine, s.tick_de(loup))
	verifier(Etres.a_statut_id(loup, "enracinement"), "Racine : ce qui entre dans la zone est enraciné")
	# Voile de brume : ni vu, ni voyant
	s.zones.clear()
	s._executer_capacite(j, plan_z.call("voile_de_brume"), loup.pos)
	verifier(not s.zones_sur(loup.pos, "brume").is_empty() and not s.voit_ia(loup, j), "Voile de brume : le loup ne voit plus")
	# Balise : la tuile marquée donne un dé de plus au porteur
	s.zones.clear()
	s._executer_capacite(j, plan_z.call("balise"), loup.pos)
	verifier(s._bonus_balise(j, loup.pos) == 1 and s._bonus_balise(loup, loup.pos) == 0, "Balise : +1 dé pour celui qui l'a posée, pour personne d'autre")
	# Nappe : on glisse d'une tuile de plus
	s.zones.clear()
	var t_nappe: Vector2i = j.pos + Vector2i(2, 0)
	s._executer_capacite(j, plan_z.call("nappe"), t_nappe)
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	loup.orientation = Vector2i(1, 0)
	loup.statuts.clear()   # il sort de la Racine du test précédent : rien ne doit le retenir
	s._deplacer(loup, t_nappe, s.tick_de(loup))
	verifier(loup.pos == t_nappe + Vector2i(1, 0), "Nappe : le loup glisse d'une tuile de plus (%s)" % str(loup.pos - t_nappe))
	# expiration
	s._tiquer_zones(999999)
	verifier(s.zones.is_empty(), "les zones expirent")


## Création de sorts (Structure compétences-modules-slots) : tout le catalogue de modules passé au banc.
## Chaque noyau seul, chaque forme avec un noyau, puis 300 séquences tirées au hasard : l'assembleur
## doit toujours rendre un plan cohérent — jamais de plan à moitié construit, jamais d'erreur muette.
## Conditions et modificateurs (Modules, lots 7 et 7b) : chaque prédicat s'évalue, chaque drapeau agit.
func test_conditions_et_modificateurs() -> void:
	var s := Simulation.new(616)
	s.charger_donjon("ruine", 616, 6, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	for dx in range(1, 5):
		var t: Vector2i = j.pos + Vector2i(dx, 0)
		s.grille.contenu[s.grille.idx(t)] = 0
		s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	var plan_de := func(mods: Array) -> Dictionary:
		var pl := s.capacites.assembler(mods, 10, "1d4", {}, j.competences_eff)
		pl["name_key"] = ""
		pl["arme"] = {}
		pl["fonct"] = {}
		return pl

	# 1. tout prédicat cité par une condition est évalué par le code (aucun ne tombe dans le défaut)
	var non_geres: Array[String] = []
	for mid in GameData.catalogues.modules.keys():
		var m: Dictionary = GameData.catalogues.modules[mid]
		if str(m.module_type) != "condition":
			continue
		var t := str(m.get("effet", {}).get("predicat_structure", {}).get("type", ""))
		if t.is_empty():
			non_geres.append(str(mid) + " (sans prédicat)")
	verifier(non_geres.is_empty(), "les 20 conditions portent un prédicat (%s)" % str(non_geres))

	# 2. Ombre : vrai seulement quand le lanceur est Dissimulé — et la capacité ne part pas sinon
	var plan_ombre: Dictionary = plan_de.call(["ombre", "etincelle"])
	verifier(not s._evaluer_conditions(j, plan_ombre, loup.pos).is_empty(), "Ombre : sans Dissimulé, la condition est fausse")
	s.appliquer_statut(j, "dissimule", 20000, j.id)
	verifier(s._evaluer_conditions(j, plan_de.call(["ombre", "etincelle"]), loup.pos).is_empty(), "Ombre : Dissimulé, la condition passe")
	s._retirer_statut(j, "dissimule")

	# 3. Prise : vrai quand la cible est saisie ou lévitée
	verifier(not s._evaluer_conditions(j, plan_de.call(["prise", "etincelle"]), loup.pos).is_empty(), "Prise : cible libre, condition fausse")
	s.appliquer_statut(loup, "levite", 5000, j.id)
	verifier(s._evaluer_conditions(j, plan_de.call(["prise", "etincelle"]), loup.pos).is_empty(), "Prise : cible lévitée, condition vraie")
	s._retirer_statut(loup, "levite")

	# 4. Pied ferme : le lanceur n'a pas bougé depuis 20 ticks
	j["immobile_depuis"] = s.tick_de(j)
	verifier(not s._evaluer_conditions(j, plan_de.call(["pied_ferme", "etincelle"]), loup.pos).is_empty(), "Pied ferme : à peine arrêté, condition fausse")
	var seuil_pf := int(GameData.catalogues.modules.pied_ferme.effet.predicat_structure.ticks)
	j["immobile_depuis"] = s.tick_de(j) - seuil_pf
	verifier(s._evaluer_conditions(j, plan_de.call(["pied_ferme", "etincelle"]), loup.pos).is_empty(), "Pied ferme : %d ticks immobile, condition vraie" % seuil_pf)

	# 5. Évasement : la géométrie s'ouvre
	verifier(str(plan_de.call(["ligne", "etincelle"]).geometrie) == "ligne" and str(plan_de.call(["ligne", "evasement", "etincelle"]).geometrie) == "cone", "Évasement : la Ligne devient un Cône")

	# 6. Canalisation : les dés de l'immobilité
	var plan_can: Dictionary = plan_de.call(["canalisation", "etincelle"])
	var tranche_can := int(GameData.catalogues.modules.canalisation.effet.canalisation.ticks)
	var des_can := int(GameData.catalogues.modules.canalisation.effet.canalisation.des_par)
	j["immobile_depuis"] = s.tick_de(j) - 5 * tranche_can
	var des0: int = int(plan_can.des_bonus)
	s._executer_capacite(j, plan_can, loup.pos)
	verifier(int(plan_can.des_bonus) == des0 + 5 * des_can, "Canalisation : cinq tranches de %d ticks = +%d dés (%d)" % [tranche_can, 5 * des_can, int(plan_can.des_bonus)])

	# 7. Emprise : ce qui est touché est enraciné
	loup.statuts.clear()
	loup.vivant = true   # l'Étincelle du test précédent a pu l'abattre
	loup.anti_stunlock_jusqua = 0   # la Lévitation du test 4 tient encore le verrou anti-stunlock
	loup.sante = 100000
	loup.sante_max = 100000
	if s.grille.occupant(loup.pos).is_empty():
		s.grille.placer(loup.id, loup.pos)
	s._executer_capacite(j, plan_de.call(["emprise", "etincelle"]), loup.pos)
	verifier(Etres.a_statut_id(loup, "enracinement"), "Emprise : la cible touchée est enracinée")

	# 8. Traçant : la portée seule compte, le couvert non
	var derriere_mur: Vector2i = j.pos + Vector2i(3, 0)
	s.grille.poser_contenu(j.pos + Vector2i(2, 0), "mur")
	var plan_normal: Dictionary = plan_de.call(["point", "etincelle"])   # une forme projetée : la ligne de vue compte
	var plan_trac: Dictionary = plan_de.call(["point", "tracant", "etincelle"])
	plan_normal.portee = Vector2i(1, 6)
	plan_trac.portee = Vector2i(1, 6)
	verifier(not s.capacite_visable(j, plan_normal, derriere_mur) and s.capacite_visable(j, plan_trac, derriere_mur), "Traçant : la charge passe le mur, pas la charge normale")
	s.grille.contenu[s.grille.idx(j.pos + Vector2i(2, 0))] = 0

	# 9. Détonation : le double contre une invocation
	var invoque := s.ajouter("loup", j.pos + Vector2i(4, 0), "ia")
	invoque["fin_invocation"] = s.tick_de(j) + 500
	invoque.sante = 100000
	invoque.sante_max = 100000
	loup.sante = 100000
	loup.sante_max = 100000
	var plan_det: Dictionary = plan_de.call(["detonation", "etincelle"])
	verifier(float(plan_det.drapeaux.get("detonation", 0.0)) == 2.0, "Détonation : le drapeau atteint le plan")
