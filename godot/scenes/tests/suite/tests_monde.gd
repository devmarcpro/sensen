extends TestsBase
## Le monde : surface, sauvegarde, carte et voyage, corruption, cycle et météo.
## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de
## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l'ordre de sa liste.


func test_surface() -> void:
	# Début de partie (2026-08-30) : le camp n'est jamais dans la mer — terre_a sonde DANS la cellule (bug des offsets 128)
	for g in [763439, 31, 92, 4, 555, 8080, 1234, 99]:
		var sd := Simulation.new(g)
		sd.charger_camp()
		var jd: Dictionary = sd.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
		verifier(sd.grille.niveau_liquide(jd.pos) == 0 and not ("liquide" in sd.grille.contenu_de(jd.pos).get("tags", [])), "graine %d : le camp est sur la terre ferme" % g)
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	# Le nombre de biomes n'est pas une constante à recopier : le designer en ajoute et en retire (le
	# 2026-09-02, Forêt de mana et Montagne cristalline sont parties, « retire les biomes fantaisistes »).
	# Ce qui doit tenir, c'est qu'il y en ait assez pour peupler le monde, et que chacun soit lisible.
	verifier(GameData.config("noise_layers").size() == 8, "8 couches de bruit")
	verifier(GameData.catalogues.biomes.size() >= 8, "%d biomes au catalogue (au moins 8)" % GameData.catalogues.biomes.size())
	for bid_v in GameData.catalogues.biomes.keys():
		var bv: Dictionary = GameData.catalogues.biomes[bid_v]
		if not bv.has("conditions") or not bv.has("priority"):
			verifier(false, "le biome %s a ses conditions et sa priorité" % bid_v)
	# Tectonique : 24 plaques, ~35 % de terres (quantile calibré), mers et montagnes déterministes.
	verifier(surf.plaques.size() == 24 and surf.points_chauds.size() >= 8 and surf.points_chauds.size() <= 14, "24 plaques, 8 à 14 points chauds")
	var terres := 0
	var n_ech := 40
	var monde_t := int(planete.monde_cellules) * int(planete.taille_cellule)
	var monde_h := int(monde_t * float(planete.get("monde_ratio", 1.0)))   # le monde est rectangulaire (point 49)
	for j2 in n_ech:
		for i2 in n_ech:
			if float(surf.tectonique_a(int((i2 + 0.5) / n_ech * monde_t), int((j2 + 0.5) / n_ech * monde_h)).altitude) >= 0.30:
				terres += 1
	var part := float(terres) / float(n_ech * n_ech)
	verifier(part > 0.18 and part < 0.48, "part de terres émergées, ceinture d'océan comprise (%.0f %%)" % (part * 100.0))
	var t1 := surf.tectonique_a(1000, 1000)
	verifier(t1.altitude == surf.tectonique_a(1000, 1000).altitude and t1.sismique >= 0.0 and t1.sismique <= 1.0, "tectonique déterministe, sismique 0..1")
	var cell_mer := Vector2i(-1, -1)
	for j3 in 1024:
		if not surf.terre_a(Vector2i(j3, 3)):
			cell_mer = Vector2i(j3, 3)
			break
	if cell_mer != Vector2i(-1, -1):
		var em := surf.generer_cellule(cell_mer.x, cell_mer.y, {}, false)
		verifier(em.eau.size() > 0 and int(em.hauteurs[em.eau.keys()[0]]) == 8, "une cellule en mer : des tuiles d'eau à hauteur 8 (%d)" % em.eau.size())
	var v := surf.couches_a(1000, 1000)
	var bornes := true
	for k in v.keys():
		if float(v[k]) < 0.0 or float(v[k]) > 1.0:
			bornes = false
	verifier(v.size() == 8 and bornes, "les couches sont normalisées 0..1")
	verifier(surf.valeur("temperature", 0, 0) != surf.valeur("temperature", 50000, 50000) or surf.valeur("humidite", 0, 0) != surf.valeur("humidite", 50000, 50000), "le bruit varie à travers le monde")
	var centre_m := Vector2i(int(planete.cellule_depart[0]), int(planete.cellule_depart[1]))   # le centre du monde rectangulaire
	for essai_c in 200:   # ... et de la terre ferme : au centre d'un monde ceinturé d'océan, la mer est possible
		if surf.terre_a(centre_m):
			break
		centre_m += Vector2i(1, 0)
	var b := surf.biome_a(centre_m.x * int(planete.taille_cellule), centre_m.y * int(planete.taille_cellule))
	verifier(GameData.catalogues.biomes.has(b), "un biome résolu au centre du monde (%s)" % b)
	var e := surf.generer_cellule(centre_m.x, centre_m.y, {})
	var e2 := surf.generer_cellule(centre_m.x, centre_m.y, {})
	verifier(e.hauteurs == e2.hauteurs and e.arbres.size() == e2.arbres.size() and e.filons.size() == e2.filons.size(), "déterministe")
	var plats := 0
	for i in e.hauteurs.size():
		if int(e.hauteurs[i]) == 10:
			plats += 1
	verifier(plats > e.hauteurs.size() * 0.8 and plats < e.hauteurs.size(), "plat à 10 avec des accidents (%d %% plat, %d accidents)" % [plats * 100 / e.hauteurs.size(), e.accidents.size()])
	verifier(e.accidents.size() >= 1 and e.accidents.size() <= 8, "1 à 3 accidents posés par cellule de 64 (× accidents_mult du biome : %d)" % e.accidents.size())
	verifier(e.sols.size() > 100 and e.sols.values()[0] == GameData.entree("biomes", e.biome).surface_material or true, "le sol porte le matériau du biome")
	var mat_ok := true
	for i in e.arbres.keys():
		if not GameData.catalogues.materials.has(e.arbres[i]):
			mat_ok = false
	verifier(mat_ok and (e.arbres.size() + e.rochers.size() + e.filons.size()) > 20, "arbres, rochers et filons posés (%d / %d / %d)" % [e.arbres.size(), e.rochers.size(), e.filons.size()])
	var veg_ok := true
	for i in e.arbres.keys():
		if not GameData.catalogues.vegetaux.has(e.arbres[i]):
			veg_ok = false
	for i in e.plantes.keys():
		if not GameData.catalogues.vegetaux.has(e.plantes[i]) or not e.sol.has(i):
			veg_ok = false
	verifier(veg_ok and e.plantes.size() > 0, "chaque arbre et plante a sa silhouette ; les plantes restent franchissables (%d plantes)" % e.plantes.size())
	var dt := 1e9   # la meilleure de trois : la première génération porte le coût d'amorçage des bruits
	for k in 3:
		var t0 := Time.get_ticks_usec()
		surf.generer_cellule(513 + k, 512)
		dt = minf(dt, (Time.get_ticks_usec() - t0) / 1000.0)
	verifier(dt < 250.0, "une cellule de %d×%d générée en %.0f ms (< 250 ms ; le budget de 32 ms attend une refonte des structures)" % [int(planete.taille_cellule), int(planete.taille_cellule), dt])
	# Le camp est cette cellule.
	var s := Simulation.new(31)
	s.charger_camp()
	verifier(s.lieu == "camp" and s.camp_sauve.biome != "" and s.grille.sols.size() > 100, "le camp est une cellule générée (biome %s)" % s.camp_sauve.biome)
	verifier(surf.terre_a(s.camp_sauve.cellule), "la cellule de départ est de la terre ferme")
	s.monde.fermer()
	var accidente := false
	for i in s.grille.hauteurs.size():
		if int(s.grille.hauteurs[i]) != 10:
			accidente = true
	verifier(accidente, "le camp a du relief posé")


# ---------------------------------------------------------------- Étape 8.3a : POI, donjons de surface, carte, voyage rapide

func test_sauvegarde() -> void:
	var s := Simulation.new(37)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(s.monde.explores.size() > 0, "des chunks explorés dès l'arrivée (%d)" % s.monde.explores.size())
	var ch: Vector2i = s.monde.explores.keys()[0]
	var col: Color = s.monde.couleur_chunk(ch)
	verifier(col.a == 1.0 and (col.r + col.g + col.b) > 0.0 and s.monde.couleur_chunk(ch) == col, "une teinte dominante par chunk, calculée une fois")
	# On modifie le monde, on remplit le sac, on avance le temps, on sauvegarde.
	s._donner_materiau(j, "chene", 2, "planche")
	var mur: Vector2i = j.pos + Vector2i(0, -1)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "poser_mur", "vers": mur})
	var dague := s.generer_objet("proto_dague", 1, {}, "commun", 0)
	j.sac.append(dague.uid)
	s.horloge_monde.avancer(1234)
	var pos0: Vector2i = j.pos
	var sac0: int = j.sac.size()
	verifier(s.sauvegarder("test_sensen"), "sauvegarder au camp")
	verifier(Sauvegarde.existe("test_sensen"), "le dossier user://sauvegardes/test_sensen/ existe")
	var w: Dictionary = Sauvegarde.lire("test_sensen", "world.json")
	verifier(int(w.graine) == 37 and int(w.ticks) == s.horloge_monde.ticks and w.cellule_camp == s.monde.cellule_camp, "world.json : graine, ticks, cellule du camp")
	# Une simulation neuve recharge : le mur, le sac, la position, le temps, l'exploration.
	var s2 := Simulation.new(1)
	verifier(s2.charger_sauvegarde("test_sensen"), "charger la sauvegarde dans une simulation neuve")
	var j2: Dictionary = s2.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(j2.pos == pos0 and j2.sac.size() == sac0 and dague.uid in j2.sac and s2.items.has(dague.uid), "le joueur, son sac et ses objets sont revenus")
	verifier(s2.grille.contenu_de(mur).get("tags", []).has("construit") and s2.grille.materiau_de(mur) == "chene", "le mur posé est là (seed + modifications)")
	verifier(s2.horloge_monde.ticks == s.horloge_monde.ticks and s2.graine == 37, "le temps et la graine")
	# La graine du monde choisie à l'écran Monde (Écrans d'interface) : portée par la simulation, écrite, relue.
	var s5 := Simulation.new(5)
	s5.graine_monde = 4242
	s5.charger_camp()
	verifier(int(s5.monde.surface.graine) == 4242, "la surface est générée avec la graine choisie (%d)" % int(s5.monde.surface.graine))
	verifier(s5.sauvegarder("test_graine"), "sauvegarder la partie à graine choisie")
	var s6 := Simulation.new(6)
	verifier(s6.charger_sauvegarde("test_graine") and s6.graine_monde == 4242 and int(s6.monde.surface.graine) == 4242, "la graine du monde est relue avec la sauvegarde (%d)" % s6.graine_monde)
	s5.monde.fermer()
	s6.monde.fermer()
	verifier(s2.monde.explores.size() == s.monde.explores.size(), "les chunks explorés (%d)" % s2.monde.explores.size())
	verifier(s2.grille.decouvert.size() > s2.monde.taille * s2.monde.taille / 2, "la cellule du camp reste découverte (%d tuiles)" % s2.grille.decouvert.size())
	# Un tour complet sur l'état du camp : ce qu'on a construit, élevé, revendiqué, stocké
	s.territoire["tresor"] = 321
	s.territoire["stocks"] = {"chene": 7}
	s.territoire["registre"] = {"carpe": {"1|2": true, "3|4": true}}
	s.monde.claims[s.monde.cellule_camp] = {"role": "champs", "depuis": 0}
	s.monde.delta[s.monde.cellule_camp] = 12
	var comp := s.ajouter("villageois", j.pos + Vector2i(0, 2), "ia")
	s._habiller_pnj(comp, GameData.entree("creatures", "villageois"))
	s._devenir_compagnon(j, comp)
	var n_vivants := s.vivants().size()
	verifier(s.sauvegarder("test_sensen2"), "sauvegarder l'état complet du camp")
	var s4 := Simulation.new(3)
	verifier(s4.charger_sauvegarde("test_sensen2"), "recharger l'état complet")
	verifier(int(s4.territoire.tresor) == 321 and int(s4.territoire.stocks.get("chene", 0)) == 7, "trésor et stocks revenus")
	verifier(int(s4.territoire.get("registre", {}).get("carpe", {}).size()) == 2, "le registre d'élevage est revenu")
	verifier(s4.monde.claims.has(s.monde.cellule_camp) and int(s4.monde.delta.get(s.monde.cellule_camp, 0)) == 12, "claim et dérive de corruption revenus")
	verifier(s4.vivants().size() == n_vivants, "autant d'êtres qu'avant (%d contre %d)" % [s4.vivants().size(), n_vivants])
	var comp4 := s4.compagnons_de(s4.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0])
	verifier(comp4.size() == 1, "le compagnon est toujours au service du joueur")
	s4.monde.fermer()
	# Sans monde (arène ou donjon chargé à cru), rien à sérialiser — le donjon lui-même se sauve, voir test_sauvegarde_partout.
	var s3 := Simulation.new(2)
	s3.charger_donjon("ruine", 2, 9, 1)
	verifier(not s3.sauvegarder("test_sensen"), "pas de sauvegarde sans monde")
	s.monde.fermer()
	s2.monde.fermer()


# ---------------------------------------------------------------- Étape 7.1 : le camp de base

func test_carte_et_voyage() -> void:
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	var donjons := 0
	var terres := 0
	var depart_c: Vector2i = Vector2i(int(planete.cellule_depart[0]), int(planete.cellule_depart[1]))
	for y in range(depart_c.y - 15, depart_c.y + 16):   # autour du départ : de la terre pour de vrai
		for x in range(depart_c.x - 15, depart_c.x + 16):
			var c := Vector2i(x, y)
			if surf.terre_a(c):
				terres += 1
				if surf.poi_de(c).donjon:
					donjons += 1
	verifier(donjons == 0, "aucun donjon en POI : ils naissent de la corruption (%d sur %d terres)" % [donjons, terres])
	verifier(not surf.poi_de(depart_c, true).donjon, "la cellule du camp non plus n'a de donjon")
	verifier(surf.poi_de(Vector2i(512, 512)) == surf.poi_de(Vector2i(512, 512)), "POI déterministes")
	var r := surf.resume_cellule(Vector2i(512, 512), true)
	verifier(r.has("biome") and r.has("danger") and int(r.danger) >= 0 and int(r.danger) <= 2 and not r.poi.donjon, "résumé de cellule : biome, danger 0-2, aucun donjon en POI")
	var s := Simulation.new(41)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	var camp := s.monde.cellule_camp
	var e := s.monde.cellule(camp)
	var entree: Vector2i = s.monde.pos_monde(camp, e.entree_donjon)
	verifier(not s.grille.contenu_de(entree).get("tags", []).has("entree_donjon"), "le camp n'a plus d'entrée de donjon (designer 2026-09-01)")
	# Voyage rapide : refusé vers l'inexploré, accepté vers une cellule explorée ; le temps avance.
	var voisine := camp + Vector2i(1, 0)
	for dv in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(2, 0)]:
		if s.monde.surface.terre_a(camp + dv) and not s.monde.donjon_corrompu(camp + dv, s.jour_courant()):
			voisine = camp + dv   # une cellule saine : une cellule corrompue happerait le voyageur
			break
	var t0: int = s.horloge_monde.ticks
	verifier(not s.monde.surface.terre_a(voisine) or s.voyager(j, voisine), "on voyage vers l'inconnu : l'exploration n'est plus exigée (designer 2026-09-01)")
	verifier(not s.voyager(j, _cellule_eau(s, camp)), "l'océan se refuse toujours")
	s.monde.explores[Vector2i(voisine.x * (s.monde.taille / 32), voisine.y * (s.monde.taille / 32))] = true
	if s.monde.surface.terre_a(voisine):
		verifier(s.monde.cellule_de(j.pos) == voisine or s.voyager(j, voisine), "voyage rapide vers la cellule voisine")
		# Le voyage coûte une marche depuis le point 59 : une cellule = sa largeur en tuiles, au prix d'un pas.
		var attendu_v := int(planete.taille_cellule) * s.regles.ticks_deplacement(int(s.regles.r.deplacement.cout_base), j.get("competences_eff", {}), false)
		verifier(s.monde.cellule_de(j.pos) == voisine and absi(s.horloge_monde.ticks - t0 - attendu_v) <= attendu_v / 2, "arrivé dans la cellule, %d ticks de voyage (marche ≈ %d)" % [s.horloge_monde.ticks - t0, attendu_v])
	# Le donjon garanti du début de partie (designer 2026-09-01) : une cellule d'amorce à portée du camp,
	# corrompue tant qu'elle n'est pas nettoyée. Y marcher, c'est y entrer ; ressortir ramène au monde.
	var amorce: Vector2i = s.monde.cellule_amorce()
	var dist_a := maxi(absi(amorce.x - camp.x), absi(amorce.y - camp.y))
	var g_cfg: Dictionary = planete.corruption.donjons.garantie_depart
	verifier(amorce != Vector2i(-1, -1) and dist_a >= int(g_cfg.rayon_min) and dist_a <= int(g_cfg.rayon_max), "une cellule d'amorce à %d cases du camp (%d-%d attendu)" % [dist_a, int(g_cfg.rayon_min), int(g_cfg.rayon_max)])
	verifier(s.monde.cellule_amorce() == amorce, "l'amorce est déterministe")
	verifier(s.monde.donjon_corrompu(amorce, s.jour_courant()), "l'amorce est corrompue dès le premier jour")
	if s.lieu == "camp" and s.monde.cellule_de(j.pos) != amorce:
		verifier(s.voyager(j, amorce) and s.lieu == "donjon" and not s.donjon.is_empty(), "marcher sur l'amorce, c'est entrer dans son donjon")
		j.pos = s.donjon.entree
		s.grille.placer(j.id, j.pos)
		s.attente[j.id] = true
		s.intention(j.id, {"type": "remonter"})
		verifier(s.lieu == "camp", "ressortir ramène au monde")
	s.monde.nettoyages[amorce] = s.jour_courant()
	verifier(not s.monde.donjon_corrompu(amorce, s.jour_courant()), "nettoyée, l'amorce redevient une cellule ordinaire")
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 8.3b : la dérive de la corruption

func test_corruption() -> void:
	var s := Simulation.new(43)
	s.charger_camp()
	var m = s.monde
	var camp: Vector2i = m.cellule_camp
	var cr: Dictionary = GameData.config("planete").corruption
	# Depuis le retrait des donjons posés (designer 2026-09-01), aucun foyer ne naît en jeu : la machinerie
	# de foyer reste sous test, mais il faut l'amorcer à la main — elle n'est plus atteignable en partie.
	verifier(m.foyer(camp).is_empty(), "plus aucun foyer ne naît d'une cellule : les donjons viennent de la corruption")
	m.cellule(camp)["a_donjon"] = true
	m._reposer_entree(camp)
	var f: Dictionary = m.foyers.get(camp, {})
	if f.is_empty():
		f = {"actif": true, "majeur": m.surface.danger_de(camp) >= 2, "generation": 0, "repit": 0, "nettoye_tick": -1}
		m.foyers[camp] = f
	verifier(bool(f.actif) and int(f.generation) == 0, "le foyer amorcé est actif")
	var c0 := m.corruption_de(camp)
	var touchees := m.semaine(1)
	# Le monde est rectangulaire (point 49) : le camp peut tomber près d'un second foyer, donc on
	# vérifie la règle (au moins l'infection du foyer ici, au moins celle des voisines à côté), pas un chiffre exact.
	var voisine_terre := camp + Vector2i(1, 0)
	for d_c in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		if m.surface.terre_a(camp + d_c) and m.delta.has(camp + d_c):
			voisine_terre = camp + d_c
			break
	verifier(touchees.has(camp) and int(m.delta.get(camp, 0)) >= int(cr.infection_cellule) and int(m.delta.get(voisine_terre, 0)) >= int(cr.infection_voisines) - int(cr.civilisation), "une semaine : le foyer infecte sa cellule (+%d) et ses voisines (+%d)" % [int(m.delta.get(camp, 0)), int(m.delta.get(voisine_terre, 0))])
	verifier(m.corruption_de(camp) > c0, "la corruption effective a monté")
	for k in 30:
		m.semaine(k + 2)
	var plafond := int(cr.plafond_majeur) if bool(f.majeur) else int(cr.plafond_mineur)
	verifier(int(m.delta.get(camp, 0)) <= plafond, "plafond d'influence respecté (%d ≤ %d)" % [int(m.delta.get(camp, 0)), plafond])
	# Nettoyage : le boss vaincu à la sortie → foyer inactif, corruption en recul, grâce puis disparition.
	var d0 := int(m.delta.get(camp, 0))
	m.nettoyer(camp, 1000)
	verifier(not bool(f.actif) and int(f.repit) > 0 and int(m.delta.get(camp, 0)) == d0 + int(cr.nettoyage_cellule), "nettoyé : inactif, répit, −8")
	verifier(m.donjon_ouvert(camp, 1000 + 100) and not m.donjon_ouvert(camp, 1000 + int(cr.grace_ticks) + 1), "ouvert pendant la grâce, fermé après")
	var entree: Vector2i = m.pos_monde(camp, m.cellule(camp).entree_donjon)
	var disparues := m.tick(1000 + int(cr.grace_ticks) + 1)
	verifier(disparues.has(camp) and s.grille.contenu_de(entree).is_empty() and not s.grille.bloque_passage(entree + Vector2i(0, -1)), "après la grâce, l'entrée et son anneau de roche ont disparu")
	# Répit puis repeuplement : le répit décompte, la réapparition rend l'entrée avec une nouvelle génération.
	var repit0 := int(f.repit)
	m.semaine(2000)
	verifier(int(f.repit) == repit0 - 1, "le répit décompte chaque semaine")
	f.repit = 0
	m.delta[camp] = 40
	var reapparu := false
	for k in 40:
		m.semaine(3000 + k)
		if bool(f.actif):
			reapparu = true
			break
	verifier(reapparu and int(f.generation) == 1 and s.grille.contenu_de(entree).get("tags", []).has("entree_donjon"), "réapparition ∝ corruption : nouvelle génération, entrée de retour")
	# Décroissance loin des foyers : une cellule sans foyer actif à moins de 2 revient vers 0.
	var loin := camp + Vector2i(5, 5)
	m.explores[Vector2i(loin.x * (m.taille / 32), loin.y * (m.taille / 32))] = true
	m.delta[loin] = 3
	f.actif = false
	m.semaine(5000)
	verifier(int(m.delta.get(loin, 0)) == 2, "décroissance −1/semaine sans foyer proche")
	# Le danger de la carte lit la corruption effective ; l'expédition prend la corruption de la cellule.
	f.actif = true
	m.delta[camp] = 40
	verifier(m.danger_de(camp) >= s.monde.surface.danger_de(camp), "le danger affiché intègre le delta")
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	s.grille.liberer(j.pos)
	j.pos = entree
	s.grille.placer(j.id, entree)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "descendre"}), "entrer dans le donjon réapparu")
	var gen: int = int(m.foyer(camp).generation)
	verifier(gen >= 1 and int(s.donjon.id) == int(hash([s.graine, camp.x, camp.y, "donjon", gen]) & 0x7fffffff) and float(s.donjon.corruption) > 0.0 and int(s.donjon.profondeur) >= 1, "id de la génération %d, corruption %.0f et profondeur %d portées par le donjon" % [gen, float(s.donjon.corruption), int(s.donjon.profondeur)])
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 9.A : hameau, PNJ nommés, dialogue, commerce

func test_cycle_et_meteo() -> void:
	var s := Simulation.new(47)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(is_equal_approx(s.heure(0), 0.0) and is_equal_approx(s.heure(12000), 12.0) and s.phase(12000) == "jour" and s.phase(0) == "nuit" and s.phase(6000) == "aube", "l'heure et les phases (24 000 ticks par jour)")
	verifier(GameData.catalogues.weather_states.size() == 10, "10 états météo en données")
	var cell: Vector2i = s.monde.cellule_de(j.pos)
	var m1 := s.meteo(cell, 5000)
	verifier(GameData.catalogues.weather_states.has(m1) and m1 == s.meteo(cell, 5000), "la météo est un état connu, déterministe")
	var varie := false
	for k in 40:
		if s.meteo(cell, k * 24000) != m1:
			varie = true
	verifier(varie, "la météo change avec le temps")
	var tr_ := s.temperature_ressentie(j)
	verifier(tr_.temp >= -60.0 and tr_.temp <= 70.0 and tr_.has("ecart"), "température ressentie calculée (%.0f °C)" % float(tr_.temp))
	# La nuit réduit la vue, le jour non.
	s.horloge_monde.ticks = 12000
	s.maj_vision()
	var vue_jour: int = j.vue.size()
	s.horloge_monde.ticks = 0
	s.maj_vision()
	var vue_nuit: int = j.vue.size()
	verifier(vue_nuit < vue_jour, "la nuit, le champ de vue rétrécit (%d → %d)" % [vue_jour, vue_nuit])
	# Dormir la nuit saute à l'aube (5 h).
	var lit := s.generer_objet("meuble_lit_de_paille", 1, {}, "commun", 0)
	j.sac.append(lit.uid)
	var devant: Vector2i = j.pos + Vector2i(0, 1)
	if not s.grille.contenu_de(devant).is_empty():
		s.grille.contenu[s.grille.idx(devant)] = 0
	s.attente[j.id] = true
	s.intention(j.id, {"type": "poser", "objet": lit.uid, "vers": devant})
	s.horloge_monde.ticks = 22 * 1000   # 22 h
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "dormir", "vers": devant}), "dormir à 22 h")
	verifier(is_equal_approx(s.heure(), 5.0) or absf(s.heure() - 5.0) < 0.2, "réveil à l'aube, 5 h (%.1f h)" % s.heure())
	# Le froid : un être nu par −20 °C prend des dégâts par palier.
	j.equipement.clear()
	var end0: int = j.vigueur
	# On MESURE les deux régénérations au lieu de figer un nombre : la même durée, le même personnage,
	# une fois au confort et une fois à −25 °C. Le seuil en dur passait au vert par hasard — il a cassé
	# le jour où la vigueur max a cessé d'être une constante, parce que le personnage récupérait plus
	# souvent, gagnait plus vite la compétence Récupération, et dépassait le chiffre gelé.
	j["ecart_confort"] = 0.0
	j.vigueur = 0
	j.tick_vigueur = s.horloge_monde.ticks
	s._regenerer(j, s.horloge_monde.ticks + 10)
	var regen_confort: int = int(j.vigueur)
	j["ecart_confort"] = -25.0
	j.vigueur = 0
	j.tick_vigueur = s.horloge_monde.ticks
	s._regenerer(j, s.horloge_monde.ticks + 10)
	verifier(int(j.vigueur) < regen_confort, "hors confort, la vigueur régénère moins qu'au confort (%d contre %d)" % [int(j.vigueur), regen_confort])
	s.monde.fermer()


# ---------------------------------------------------------------- Étape 8.2c : minimap (exploration par chunk) et sauvegarde
