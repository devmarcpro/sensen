extends TestsBase
## L'alchimie, les villes et halls, l'élevage : saisons, familles, loci, harmonie, registre, entraîneur, guildes, anneau-mesure, chatoyant.
## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de
## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l'ordre de sa liste.


func test_alchimie() -> void:
	var s := Simulation.new(81)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Un loup meurt : sa dépouille porte une partie.
	var loup := s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	s._appliquer_degats(loup, 9999, j.id, {})
	var butin: Array = s.contenants.get(s.grille.idx(loup.pos), [])
	var partie := ""
	for uid in butin:
		if "partie" in s.items[uid].get("tags", []):
			partie = str(s.items[uid].base)
	verifier(not partie.is_empty(), "une partie de bête dans la dépouille (%s)" % partie)
	var puiss := 0.0
	var viande_pot: Dictionary = {}
	for uid in butin:
		if "partie" in s.items[uid].get("tags", []):
			puiss = float(s.items[uid].get("puissance", 0.0))
		if str(s.items[uid].base) == "viande_crue":
			viande_pot = s.items[uid].get("potentiel", {})
	verifier(puiss >= 0.5 and puiss <= 4.0, "la partie porte la puissance de la stat du loup (%.1f)" % puiss)
	verifier(not viande_pot.is_empty(), "la viande porte le potentiel de la stat dominante (%s)" % str(viande_pot))
	# Distiller : griffe + blé à l'Alambic → potion de force.
	var griffe := s.generer_objet("griffe", 1, {}, "commun", 0)
	var ble := s.generer_objet("ble", 1, {}, "commun", 0)
	var alambic := s.generer_objet("station_alambic", 1, {}, "commun", 0)
	for o in [griffe, ble, alambic]:
		j.sac.append(o.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "distiller_partie"}) and not s._pile_objet(j, "potion_force").is_empty(), "distiller une griffe et du blé : une potion de force (la sortie vient de l'ingrédient)")
	verifier(not (griffe.uid in j.sac) and not (ble.uid in j.sac), "les ingrédients sont consommés")
	var potion := s._pile_objet(j, "potion_force")
	potion.qualite = 1.5
	potion.statut = "potion_force_forte"
	potion["puissance"] = 2.0
	# On mesure la stat EFFECTIVE avant, pas la stat de base : depuis que l'armure portee donne un
	# bonus de construction, « base + 12 » n'est plus l'effective attendue. Ce qu'on verifie, c'est
	# l'ECART que la potion apporte — et lui n'a pas bouge.
	var force0 := int(j.stats_eff.force)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "manger", "objet": potion.uid}), "boire la potion")
	var actif := false
	var fin := 0
	for st in j.statuts:
		if st.id == "potion_force_forte":
			actif = true
			fin = int(st.fin)
	verifier(actif and fin - s.horloge_monde.ticks >= 4400, "statut fort actif, durée × qualité (%d ticks)" % (fin - s.horloge_monde.ticks))
	verifier(int(j.stats_eff.force) == force0 + 12, "+6 × puissance 2 de Force pendant l'effet (%d → %d)" % [force0, int(j.stats_eff.force)])
	j.statuts[0].fin = s.horloge_monde.ticks
	s._tiquer_statuts(j, s.horloge_monde.ticks)
	verifier(int(j.stats_eff.force) == force0, "à l'expiration la Force revient (%d)" % int(j.stats_eff.force))
	s.monde.fermer()


# ---------------------------------------------------------------- Villes, boutiques, halls

func test_villes_et_halls() -> void:
	var s := Simulation.new(83)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var surf = s.monde.surface
	var cell: Vector2i = s.monde.cellule_camp + Vector2i(1, 0)
	var r := {"id": "roy_ville", "nom": "Grandia", "government_type": "monarchie_hereditaire", "culture": "latine", "race": "humain", "taille": "grand", "capital_poi": cell, "territory_cells": [cell],
		"taxes": {"base_rate": 0.08, "tariff_default": 0.1}, "tariffs": {}, "laws": [], "diplomacy": {}, "rivals": [], "tags": []}
	surf.royaumes_cache[surf.secteur_de(cell)] = {"roy_ville": r}
	surf.royaume_par_cellule[cell] = "roy_ville"
	# La capitale d'un grand royaume est une cité (Villes B1) : sa fiche, puis son centre posé sur une cellule neuve.
	surf.fiches_agglo.erase(cell)
	var fiche: Dictionary = surf.fiche_agglomeration(cell)
	var agglo: Dictionary = fiche.duplicate()
	agglo["quartier"] = "centre"
	agglo["index"] = 0
	var e: Dictionary = surf.generer_cellule(cell.x, cell.y, {}, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	if e.village.is_empty():
		surf._poser_quartier(e, cell, rng, agglo)
	s.monde.cellules[cell] = e
	var v: Dictionary = e.village
	var boutiques: Dictionary = {}
	var halls: Dictionary = {}
	for b in v.batiments:
		if not str(b.get("boutique", "")).is_empty():
			boutiques[str(b.boutique)] = int(boutiques.get(str(b.boutique), 0)) + 1
		if not str(b.get("guilde", "")).is_empty():
			halls[str(b.guilde)] = int(halls.get(str(b.guilde), 0)) + 1
	verifier(str(v.palier) == "cite" and bool(v.capitale) and v.batiments.size() >= 6, "capitale d'un grand royaume : une cité de %d bâtiments au centre" % v.batiments.size())
	verifier(boutiques.size() >= 3 and halls.size() >= 1, "%d boutiques typées, %d halls" % [boutiques.size(), halls.size()])
	var doublon := false
	for n in boutiques.values():
		doublon = doublon or int(n) > 1
	for n in halls.values():
		doublon = doublon or int(n) > 1
	verifier(not doublon, "jamais deux boutiques ou deux halls du même type")
	# Les PNJ de la ville : un marchand au stock de son type, un maître qui n'offre que sa guilde.
	s.monde.peuplees.erase(cell)
	s._peupler_fenetre()
	var marchand: Dictionary = {}
	var maitre: Dictionary = {}
	for x in s.vivants():
		if x.has("boutique") and marchand.is_empty():
			marchand = x
		if x.has("guilde") and maitre.is_empty():
			maitre = x
	verifier(not marchand.is_empty() and not marchand.stock.is_empty(), "un marchand tient sa boutique (%s, %d objets)" % [str(marchand.get("boutique", "?")), marchand.get("stock", []).size()])
	if not maitre.is_empty():
		var qs: Array = s.quetes_offertes(maitre, j)
		var bonne := true
		for q in qs:
			bonne = bonne and str(q.guild) == str(maitre.guilde)
		verifier(bonne, "le maître de la guilde %s n'offre que ses quêtes (%d)" % [str(maitre.guilde), qs.size()])
	else:
		verifier(false, "un maître de guilde instancié")
	# Le hall du joueur : refusé sans rang, accepté au rang Adepte, un maître apparaît, structure spéciale.
	var hall := s.generer_objet("meuble_hall_de_guilde", 1, {}, "commun", 0)
	j.sac.append(hall.uid)
	var vers: Vector2i = j.pos + Vector2i(0, 1)
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var c: Vector2i = j.pos + d
		if s.grille.dans(c) and s.grille.occupant(c).is_empty():
			s.grille.contenu[s.grille.idx(c)] = 0
			s.grille.meubles.erase(s.grille.idx(c))
			s.contenants.erase(s.grille.idx(c))
			vers = c
			break
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "poser", "objet": hall.uid, "vers": vers}), "sans rang : pas de hall")
	j["guildes"] = {"guerriers": {"xp": 300, "rang": 3}}
	s.attente[j.id] = true
	var avant := s._structures_speciales()
	verifier(s.intention(j.id, {"type": "poser", "objet": hall.uid, "vers": vers}) and s.territoire.halls.size() == 1, "au rang Adepte le hall se pose")
	var maitre_j: Dictionary = {}
	for x in s.vivants():
		if x.get("hall", Vector2i(-1, -1)) == vers:
			maitre_j = x
	verifier(not maitre_j.is_empty() and str(maitre_j.guilde) == "guerriers" and s._structures_speciales() == avant + 1, "un maître des Guerriers s'installe, structure spéciale +1")
	s.monde.fermer()


# ---------------------------------------------------------------- Saisons et élevage

func test_saisons_et_elevage() -> void:
	var s := Simulation.new(85)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var jour := int(s._cycle().ticks_par_jour)
	verifier(s.saison(0) == "printemps" and s.saison(105 * jour) == "ete" and s.saison(165 * jour) == "fin_ete" and s.saison(210 * jour) == "automne" and s.saison(300 * jour) == "hiver" and s.saison(375 * jour) == "printemps", "cinq saisons sur 360 jours, puis l'année recommence")
	verifier(s._saison_info(300 * jour).temp == -10.0 and s._saison_info(105 * jour).temp == 8.0, "l'écart de température : hiver −10, été +8")
	# Capture : une tuile d'eau voisine, un jet forcé.
	var eau: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.poser_contenu(eau, "eau")
	j.competences["collecte"] = 40
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "capturer"}), "lancer le filet")
	var specimens: Array = []
	for uid in j.sac:
		if s.items[uid].has("genome"):
			specimens.append(s.items[uid])
	verifier(specimens.size() == 1 and specimens[0].genome.has("couleur"), "un spécimen d'eau capturé (%s), avec son génome" % str(specimens[0].espece if not specimens.is_empty() else "-"))
	# Un couple dans un vivarium : la couvée hebdomadaire hérite locus par locus.
	# Sur SA propre simulation (2026-09-01) : le camp de ce test a reçu un hall de guilde, des PNJ et
	# des meubles, et l'élevage ne doit pas dépendre de ce décor — seulement de ses règles.
	var s_vv := Simulation.new(87)
	s_vv.planete_options = _planete_test()
	s_vv.charger_camp()
	var j_vv: Dictionary = s_vv.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	s_vv.horloge_monde.ticks = 35 * jour + jour / 2   # un midi d'été : la couvée dépend de la température réelle
	s_vv.meteo_force = "canicule"
	var a := s_vv._nouveau_specimen("carpe", {"couleur": 3, "motif": 2, "taille": 2.0}, "m")
	var b := s_vv._nouveau_specimen("carpe", {"couleur": 5, "motif": 6, "taille": 4.0}, "f")
	var viv: Vector2i = j_vv.pos + Vector2i(0, 1)
	s_vv.grille.contenu[s_vv.grille.idx(viv)] = 0
	s_vv.grille.poser_contenu(viv, "meuble")
	s_vv.grille.meubles[s_vv.grille.idx(viv)] = "vivarium"
	s_vv.contenants[s_vv.grille.idx(viv)] = [a.uid, b.uid]
	var meme_sexe := s_vv.conditions_repro(a, s_vv._nouveau_specimen("carpe", {"couleur": 0, "motif": 0, "taille": 1.0}, "m"), {"habitat": "vivarium", "libre": 2, "temp": 18.0, "saison": "ete"})
	verifier(not meme_sexe.ok and str(meme_sexe.raisons[0].cle) == "raison.sexe", "deux mâles : l'évaluateur dit pourquoi")
	s_vv._semaine_elevage()
	s_vv.meteo_force = ""
	var enfants: Array = s_vv.contenants[s_vv.grille.idx(viv)].filter(func(u: String) -> bool: return u != a.uid and u != b.uid)
	verifier(enfants.size() >= 1, "une couvée dans le vivarium (%d)" % enfants.size())
	if not enfants.is_empty():
		var g: Dictionary = s_vv.items[enfants[0]].genome
		var c_ok: bool = int(g.couleur) in [2, 3, 4, 5, 6]
		var m_ok: bool = int(g.motif) in [1, 2, 3, 5, 6, 7]
		verifier(c_ok and m_ok and float(g.taille) > 2.0 and float(g.taille) < 4.5, "l'enfant : couleur %d, motif %d, taille %.2f — un parent ou une voisine, moyenne dérivée" % [int(g.couleur), int(g.motif), float(g.taille)])
	verifier(int(s_vv.territoire.registre.carpe.size()) >= 3, "le registre compte les variétés (%d)" % int(s_vv.territoire.registre.carpe.size()))
	s_vv.monde.fermer()
	s.monde.fermer()


# ---------------------------------------------------------------- Élevage : les six familles

func test_elevage_familles() -> void:
	var s := Simulation.new(87)
	s.planete_options = _planete_test()   # un lieu tempéré et stable : l'élevage dépend de la température
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(GameData.catalogues.species.size() >= 6, "six espèces en données (%d)" % GameData.catalogues.species.size())
	var jour := int(s._cycle().ticks_par_jour)
	s.horloge_monde.ticks = 35 * jour + jour / 2   # un midi d'été : les conditions de température passent
	# Un habitat de test posé à côté du joueur.
	var hab: Vector2i = j.pos + Vector2i(0, 1)
	for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0)]:
		var c: Vector2i = j.pos + d
		if s.grille.dans(c) and s.grille.occupant(c).is_empty():
			hab = c
			break
	var idx := s.grille.idx(hab)
	s.grille.contenu[idx] = 0
	s.grille.poser_contenu(hab, "meuble")
	# Serpent : le trait caché — deux porteurs [0,1] peuvent donner un [1,1].
	s.grille.meubles[idx] = "terrarium"
	var a := s._nouveau_specimen("serpent", {"couleur": 2, "ecailles": [0, 1], "taille": 2.0}, "m")
	var b := s._nouveau_specimen("serpent", {"couleur": 2, "ecailles": [1, 0], "taille": 2.0}, "f")
	a.age_semaines = 1
	b.age_semaines = 1
	s.contenants[idx] = [a.uid, b.uid]
	s.meteo_force = "canicule"   # la cellule de départ est froide à 64 × 64 : on force l'été réel
	s._semaine_elevage()
	s.meteo_force = ""
	var petits: Array = s.contenants[idx].filter(func(u: String) -> bool: return u != a.uid and u != b.uid)
	verifier(petits.size() >= 1 and s.items[petits[0]].genome.ecailles.size() == 2, "serpents : une couvée, écailles à deux allèles (%s)" % str(s.items[petits[0]].genome.ecailles if not petits.is_empty() else "-"))
	# Ver à soie : le coût par croisement consomme 4 choux du stock ; sans stock, refus motivé.
	s.grille.meubles[idx] = "clayette"
	var v1 := s._nouveau_specimen("ver_a_soie", {"finesse": 3.0, "couleur": 1}, "m")
	var v2 := s._nouveau_specimen("ver_a_soie", {"finesse": 5.0, "couleur": 2}, "f")
	s.contenants[idx] = [v1.uid, v2.uid]
	var sans := s.conditions_repro(v1, v2, {"habitat": "clayette", "libre": 4, "temp": 18.0, "saison": "ete"})
	verifier(not sans.ok and str(sans.raisons[0].cle) == "raison.ressource", "vers à soie sans choux : refus motivé")
	s.territoire.stocks["chou"] = 5
	s._semaine_elevage()
	verifier(int(s.territoire.stocks.get("chou", 0)) == 1 and s.contenants[idx].size() == 4, "avec 5 choux : une couvée de 2, il reste 1 chou")
	# Ruche : la colonie croît chaque semaine et produit du miel en été.
	s.grille.meubles[idx] = "rucher"
	var r := s._nouveau_specimen("ruche", {"miel": 0, "colonie": 7}, "f")
	s.contenants[idx] = [r.uid]
	s._semaine_elevage()
	verifier(int(r.genome.colonie) == 8 and int(s.territoire.stocks.get("miel", 0)) == 2, "ruche : colonie 7 → 8, 2 miels au stock (%d)" % int(s.territoire.stocks.get("miel", 0)))
	# Tortue : la dossière suit l'âge.
	var t := s._nouveau_specimen("tortue", {"couleur": 1, "dossiere": 0, "taille": 1.0}, "m")
	s.grille.meubles[idx] = "enclos"
	s.contenants[idx] = [t.uid]
	s._semaine_elevage()
	s._semaine_elevage()
	verifier(int(t.genome.dossiere) == 2 and int(t.age_semaines) == 2, "tortue : dossière 2 à 2 semaines")
	# Phalène : le mélanisme est acquis de la corruption du lieu.
	var ph := s._nouveau_specimen("phalene", {"couleur": 3, "motif": 1, "melanisme": null}, "f")
	s._exprimer_loci(ph, s.monde.cellule_camp, true)
	verifier(ph.genome.melanisme != null, "phalène : mélanisme fixé à la naissance (%s)" % str(ph.genome.melanisme))
	# Capture : sans appât ni milieu, refus ; une plante voisine → une tortue ou une ruche.
	s.attente[j.id] = true
	var viande := s.generer_objet("viande_crue", 1, {}, "commun", 0)
	j.sac.append(viande.uid)
	j.competences["collecte"] = 60
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	var ok := s.intention(j.id, {"type": "capturer"})
	var pris := 0
	for uid in j.sac:
		if s.items[uid].has("genome"):
			pris += 1
	verifier(ok and pris >= 1, "capturer : le milieu voisin (ou l'appât) décide de l'espèce, un spécimen pris")
	s.monde.fermer()


# ---------------------------------------------------------------- Élevage : les dix loci, la soie

func test_loci_et_soie() -> void:
	var s := Simulation.new(89)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 89
	# lie_au_sexe : un mâle ne porte qu'un allèle, une femelle deux.
	var chat: Dictionary = GameData.catalogues.species.chat
	var m := s._nouveau_specimen("chat", s._genome_aleatoire(chat, rng), "m")
	s._exprimer_loci(m, s.monde.cellule_camp, true)
	var f := s._nouveau_specimen("chat", s._genome_aleatoire(chat, rng), "f")
	s._exprimer_loci(f, s.monde.cellule_camp, true)
	verifier(m.genome.pelage.size() == 1 and f.genome.pelage.size() == 2, "pelage lié au sexe : 1 allèle chez le mâle, 2 chez la femelle")
	var enfant: Array = s._heriter(f.genome.pelage, m.genome.pelage, chat.loci.pelage, rng)
	verifier(enfant.size() == 2 and (int(enfant[0]) in f.genome.pelage) and int(enfant[1]) == int(m.genome.pelage[0]), "l'enfant reçoit un allèle de la mère et celui du père")
	# carte : la carte d'un parent, quelques cases retournées.
	var carpe: Dictionary = GameData.catalogues.species.carpe
	var ca: Array = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
	var cb: Array = ca.duplicate()
	var carte: Array = s._heriter(ca, cb, carpe.loci.taches, rng)
	var un := 0
	for v in carte:
		un += int(v)
	verifier(carte.size() == 16 and un >= 10 and un <= 16, "taches : 16 cases, %d gardées d'un parent tout blanc" % un)
	# automate : jamais tiré, déterminé par les autres loci.
	var coq: Dictionary = GameData.catalogues.species.coquillage
	var c1 := s._nouveau_specimen("coquillage", {"couleur": 3, "spirale": [0, 1], "motif_coquille": null}, "f")
	s._exprimer_loci(c1, s.monde.cellule_camp, true)
	var c2 := s._nouveau_specimen("coquillage", {"couleur": 3, "spirale": [0, 1], "motif_coquille": null}, "f")
	s._exprimer_loci(c2, s.monde.cellule_camp, true)
	var c3 := s._nouveau_specimen("coquillage", {"couleur": 7, "spirale": [1, 1], "motif_coquille": null}, "f")
	s._exprimer_loci(c3, s.monde.cellule_camp, true)
	verifier(c1.genome.motif_coquille != null and c1.genome.motif_coquille == c2.genome.motif_coquille and int(c1.genome.motif_coquille) < int(coq.loci.motif_coquille.n), "motif automate : mêmes loci → même motif (%s), borné" % str(c1.genome.motif_coquille))
	# Filer la soie : un ver de finesse 3 → 3 soie brute, le ver disparaît.
	var ver := s._nouveau_specimen("ver_a_soie", {"finesse": 3.0, "couleur": 1}, "f")
	j.sac.append(ver.uid)
	var atelier := s.generer_objet("station_atelier_tissage", 1, {}, "commun", 0)
	j.sac.append(atelier.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "filer_soie"}), "filer la soie à l'atelier de tissage")
	var soie := s._pile(j, "soie", "brut")
	verifier(not soie.is_empty() and int(soie.quantite) == 3 and not (ver.uid in j.sac), "3 soie brute (finesse 3), la chrysalide est morte")
	s.monde.fermer()


# ---------------------------------------------------------------- Harmonie Wu Xing des plats

func test_harmonie() -> void:
	var s := Simulation.new(91)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var cuisine := s.generer_objet("station_cuisine", 1, {}, "commun", 0)
	j.sac.append(cuisine.uid)
	# Un ragoût sans rien d'autre : viande (bois/eau) + cuisson (feu) → trois éléments, pas d'harmonie.
	var v := s.generer_objet("viande_crue", 1, {}, "commun", 0)
	v.quantite = 2
	j.sac.append(v.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "plat_ragout"}), "mijoter un ragoût nu")
	var r1 := s._pile_objet(j, "ragout")
	verifier(not r1.is_empty() and float(r1.get("harmonie", 1.0)) == 1.0 and r1.get("wuxing", {}).has("feu"), "ragoût nu : du feu de cuisson, pas d'harmonie (%s)" % str(r1.get("wuxing", {})))
	s.items.erase(r1.uid)
	j.sac.erase(r1.uid)
	# Viande + pomme de terre (terre) + oignon (feu) + sel gemme (métal) → cinq éléments.
	var v2 := s.generer_objet("viande_crue", 1, {}, "commun", 0)
	v2.quantite = 2
	j.sac.append(v2.uid)
	for base in ["pomme_de_terre", "oignon"]:
		var o := s.generer_objet(base, 1, {}, "commun", 0)
		j.sac.append(o.uid)
	s._donner_materiau(j, "sel_gemme", 1, "brut")
	s.attente[j.id] = true
	var cands: Array = s.candidats_optionnels(j, GameData.catalogues.recipes.plat_ragout)
	verifier(cands.size() == 3, "trois ingrédients optionnels candidats (%d)" % cands.size())
	var sel := s._pile(j, "sel_gemme", "brut")
	s.basculer_ingredient(j, "plat_ragout", sel.uid)
	var plan_sans := s._plan_recette(j, GameData.catalogues.recipes.plat_ragout)
	verifier(not bool(s.harmonie_prevue(plan_sans).harmonie), "le sel exclu : l'aperçu annonce quatre éléments (pas de Métal)")
	s.basculer_ingredient(j, "plat_ragout", sel.uid)
	verifier(bool(s.harmonie_prevue(s._plan_recette(j, GameData.catalogues.recipes.plat_ragout)).harmonie), "le sel repris : l'aperçu annonce l'harmonie")
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "plat_ragout"}), "mijoter un ragoût complet")
	var r2 := s._pile_objet(j, "ragout")
	verifier(not r2.is_empty() and float(r2.get("harmonie", 1.0)) == 1.2, "les cinq éléments : harmonie ×1,2 (%s)" % str(r2.get("wuxing", {})))
	verifier(s._pile(j, "sel_gemme", "brut").is_empty() and s._pile_objet(j, "oignon").is_empty(), "les ingrédients optionnels sont consommés")
	j.faim = 50
	s.attente[j.id] = true
	s.intention(j.id, {"type": "manger", "objet": r2.uid})
	var attendu: int = 50 + roundi(float(GameData.entree("items", "ragout").nutrition) * 1.2)
	verifier(int(j.faim) == mini(100, attendu), "manger l'assiette harmonieuse : nutrition ×1,2 (%d)" % int(j.faim))
	s.monde.fermer()


# ---------------------------------------------------------------- Registre d'élevage et paliers

func test_registre_elevage() -> void:
	var s := Simulation.new(93)
	s.charger_camp()
	verifier(s.varietes_possibles("carpe") == 128 and s.varietes_possibles("ver_a_soie") == 6, "variétés possibles : carpe 16 × 8, ver à soie 6")
	var a := s._nouveau_specimen("carpe", {"couleur": 1, "motif": 2, "taille": 3.5}, "m")
	var b := s._nouveau_specimen("carpe", {"couleur": 1, "motif": 2, "taille": 5.0}, "f")
	var c := s._nouveau_specimen("serpent", {"couleur": 0, "ecailles": [0, 1], "taille": 1.0}, "f")
	verifier(s.territoire.registre.carpe.size() == 1 and float(s.territoire.records.carpe.taille) == 5.0, "deux carpes de la même variété : 1 variété, record de taille 5")
	verifier(s.territoire.records.serpent.ecailles.has("0") and s.territoire.records.serpent.ecailles.has("1"), "serpent : allèles 0 et 1 vus")
	verifier(int(s.paliers_elevage().capture) == 0, "sans palier : pas de bonus de capture")
	for k in 80:
		s.territoire.registre.carpe["%d|%d" % [k % 16, k / 16]] = true
	verifier(int(s.paliers_elevage().capture) == 2, "75 variétés : captures +2")
	for esp in GameData.catalogues.species.keys():
		if not s.territoire.registre.has(esp):
			s.territoire.registre[esp] = {"0|0": true}
	var pal := s.paliers_elevage()
	verifier(int(pal.couvees) == 0 or GameData.catalogues.species.size() >= 10, "moins de 10 espèces : pas de couvée en plus (%d espèces)" % GameData.catalogues.species.size())
	verifier("palier.bestiaire" in pal.atteints and int(pal.capture) == 6, "bestiaire complet : captures +6 au total")
	s.monde.fermer()


# ---------------------------------------------------------------- Familles, héritier, maîtres de guilde, titres

func test_familles() -> void:
	var s := Simulation.new(95)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var camp: Vector2i = s.monde.cellule_camp
	var cell: Vector2i = camp + Vector2i(1, 0)
	var r := {"id": "roy_fam", "nom": "Famillia", "government_type": "monarchie_hereditaire", "culture": "latine", "race": "humain", "taille": "hameau", "capital_poi": cell, "territory_cells": [cell],
		"taxes": {"base_rate": 0.08, "tariff_default": 0.1}, "tariffs": {}, "laws": [], "diplomacy": {}, "rivals": [], "tags": []}
	s.monde.surface.royaumes_cache[s.monde.surface.secteur_de(cell)] = {"roy_fam": r}
	s.monde.surface.royaume_par_cellule[cell] = "roy_fam"
	# Une maison de trois : le roi (50 ans), sa reine (40), un enfant.
	var base: Vector2i = s.monde.pos_monde(cell, Vector2i(10, 64))
	var membres: Array = []
	for k in 3:
		var x := s.ajouter("villageois", base + Vector2i(k, 0), "ia")
		s._habiller_pnj(x, GameData.entree("creatures", "villageois"), "latine")
		x["village"] = "Bourg-Fam"
		x["royaume"] = "roy_fam"
		x["lit"] = base + Vector2i(k, 0)
		x.age = [50.0, 40.0, 30.0][k]
		x.genre = ["m", "f", "m"][k]
		membres.append(x)
	membres[0].fonction = "dirigeant"
	var v := {"nom": "Bourg-Fam", "batiments": [{"lits": [Vector2i(10, 64), Vector2i(11, 64), Vector2i(12, 64)]}]}
	s._former_familles(cell, v)
	verifier(membres[0].family.spouse == membres[1].id and membres[1].family.spouse == membres[0].id, "le roi et la reine sont conjoints")
	verifier(membres[2].family.child_of.has(membres[0].id) and membres[0].family.parent_of.has(membres[2].id) and float(membres[2].age) < 18.0, "le troisième est leur enfant (%d ans)" % int(membres[2].age))
	verifier(str(membres[0].titre) == "titre.latine.monarchie_hereditaire.m", "le roi porte le titre latin (%s)" % str(membres[0].titre))
	# Le roi meurt : l'héritier est mémorisé ; quatre semaines plus tard il monte sur le trône, titré.
	s._appliquer_degats(membres[0], 9999, j.id, {})
	verifier(s.monde.heritiers.get("roy_fam", "") == membres[2].id, "l'héritier désigné est l'enfant")
	s.monde.semaine_courante += 4
	s._semaine_royaumes_pnj()
	verifier(str(membres[2].fonction) == "dirigeant" and str(membres[2].titre) == "titre.latine.monarchie_hereditaire.m" and not s.monde.vacances.has("roy_fam"), "l'enfant règne, avec le titre")
	# Un maître de guilde meurt : deux semaines, puis un villageois reprend le hall.
	var maitre := s.ajouter("maitre_de_guilde", base + Vector2i(0, 2), "ia")
	s._habiller_pnj(maitre, GameData.entree("creatures", "maitre_de_guilde"), "latine")
	maitre["village"] = "Bourg-Fam"
	maitre["guilde"] = "chasseurs"
	var vill := s.ajouter("villageois", base + Vector2i(1, 2), "ia")
	s._habiller_pnj(vill, GameData.entree("creatures", "villageois"), "latine")
	vill["village"] = "Bourg-Fam"
	s._appliquer_degats(maitre, 9999, j.id, {})
	verifier(s.monde.vacances_guildes.has("chasseurs|Bourg-Fam"), "la mort du maître ouvre une vacance de guilde")
	s.monde.semaine_courante += 2
	s._semaine_royaumes_pnj()
	var repris := false
	for x in s.vivants():
		if str(x.get("guilde", "")) == "chasseurs" and str(x.fonction) == "maitre_de_guilde" and x.id != maitre.id:
			repris = true
	verifier(repris and not s.monde.vacances_guildes.has("chasseurs|Bourg-Fam"), "deux semaines plus tard, un villageois est maître des Chasseurs")
	s.monde.fermer()


# ---------------------------------------------------------------- Entraîneur et commandes

func test_entraineur_et_commandes() -> void:
	var s := Simulation.new(97)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var m := s.ajouter("maitre_de_guilde", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(m, GameData.entree("creatures", "maitre_de_guilde"))
	j.competences["epee"] = 5
	var pot0 := int(j.potentiels.get("epee", s.regles.r.progression.potentiel_defaut))
	verifier(s.cout_entrainement(j, "epee") == 100, "épée niveau 5 : 100 or")
	j.or = 50
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "entrainer", "pnj": m.id, "competence": "epee"}), "50 or : refusé")
	j.or = 150
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "entrainer", "pnj": m.id, "competence": "epee"}) and int(j.potentiels.epee) == pot0 + 10 and int(j.or) == 50, "150 or : +10 de potentiel, 100 or au maître")
	var g := s.ajouter("garde_village", j.pos + Vector2i(0, 1), "ia")
	s._habiller_pnj(g, GameData.entree("creatures", "garde_village"))
	verifier(s.peut_entrainer(g, "epee") and not s.peut_entrainer(g, "cuisine"), "un garde entraîne l'épée, pas la cuisine")
	# Une commande tirée du registre, livrée à un marchand contre son or.
	var a := s._nouveau_specimen("carpe", {"couleur": 4, "motif": 2, "taille": 2.0}, "m")
	s.items.erase(a.uid)
	s._tirer_commande()
	var cmd: Dictionary = s.territoire.get("commande", {})
	verifier(not cmd.is_empty() and cmd.espece == "carpe" and int(cmd.couleur) != 4 and absi(int(cmd.couleur) - 4) <= 2 and int(cmd.or) >= 195, "commande : une carpe à un ou deux pas (couleur %s, %d or)" % [str(cmd.get("couleur", "?")), int(cmd.get("or", 0))])
	m.tags.append("commerce_possible")
	m.or = 0
	var sp := s._nouveau_specimen("carpe", {"couleur": int(cmd.couleur), "motif": 2, "taille": 2.0}, "f", bool(cmd.get("chatoyant", false)))
	j.sac.append(sp.uid)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "livrer", "pnj": m.id}), "marchand sans or : refus")
	m.or = 1000
	var or0: int = int(j.or)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "livrer", "pnj": m.id}) and int(j.or) == or0 + int(cmd.or) and not s.territoire.has("commande"), "commande livrée : %d or" % int(cmd.or))
	s.monde.fermer()


# ---------------------------------------------------------------- Gabarits : livrer, construire, fabriquer, vendre, explorer

func test_gabarits_guildes() -> void:
	var s := Simulation.new(99)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var guildes_servies: Dictionary = {}
	for gid in GameData.catalogues.quest_templates.keys():
		guildes_servies[str(GameData.catalogues.quest_templates[gid].guild)] = true
	verifier(guildes_servies.size() >= 12, "les douze guildes ont au moins un gabarit (%d)" % guildes_servies.size())
	# Construire : trois structures sur le territoire.
	j["quetes"] = [{"uid": "q1", "pattern": "construire", "selector": {"tags_any": ["meuble", "station", "mur"]}, "count": 2, "fait": 0, "etat": "en_cours", "text_key": "quest.chantier.text", "or": 10, "xp": 5, "guild": "batisseurs", "donneur": "x"}]
	var lit := s.generer_objet("meuble_lit_de_paille", 1, {}, "commun", 0)
	j.sac.append(lit.uid)
	var vers: Vector2i = j.pos + Vector2i(0, 1)
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		var c: Vector2i = j.pos + d
		if s.grille.dans(c) and s.grille.occupant(c).is_empty():
			s.grille.contenu[s.grille.idx(c)] = 0
			s.grille.meubles.erase(s.grille.idx(c))
			s.contenants.erase(s.grille.idx(c))
			vers = c
			break
	s.attente[j.id] = true
	s.intention(j.id, {"type": "poser", "objet": lit.uid, "vers": vers})
	verifier(int(j.quetes[0].fait) == 1, "un meuble posé sur le territoire : 1/2")
	# Fabriquer un plat : la quête du banquet avance, pas celle des potions.
	j.quetes.append({"uid": "q2", "pattern": "fabriquer", "selector": {"kinds_any": ["plat"]}, "count": 1, "fait": 0, "etat": "en_cours", "text_key": "quest.banquet.text", "or": 10, "xp": 5, "guild": "cuisiniers", "donneur": "x"})
	j.quetes.append({"uid": "q3", "pattern": "fabriquer", "selector": {"kinds_any": ["potion"]}, "count": 1, "fait": 0, "etat": "en_cours", "text_key": "quest.elixirs.text", "or": 10, "xp": 5, "guild": "alchimistes", "donneur": "x"})
	var cuisine := s.generer_objet("station_cuisine", 1, {}, "commun", 0)
	j.sac.append(cuisine.uid)
	var v := s.generer_objet("viande_crue", 1, {}, "commun", 0)
	v.quantite = 2
	j.sac.append(v.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "fabriquer", "recette": "plat_ragout"})
	verifier(j.quetes[1].etat == "terminee" and int(j.quetes[2].fait) == 0, "un ragoût : le banquet est servi, les élixirs attendent")
	# Livrer : parler à un PNJ du village de destination avec l'objet.
	var pnj := s.ajouter("villageois", j.pos + Vector2i(1, 1), "ia")
	s._habiller_pnj(pnj, GameData.entree("creatures", "villageois"))
	pnj["village"] = "Port-Test"
	j.quetes.append({"uid": "q4", "pattern": "livrer", "selector": {}, "count": 1, "fait": 0, "etat": "en_cours", "text_key": "quest.livraison.text", "or": 40, "xp": 12, "guild": "transporteurs", "donneur": "x", "objet": "pain", "destination": "Port-Test"})
	var pain := s.generer_objet("pain", 1, {}, "commun", 0)
	j.sac.append(pain.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "parler", "pnj": pnj.id})
	verifier(j.quetes[3].etat == "terminee" and s._pile_objet(j, "pain").is_empty(), "le pain livré à Port-Test : quête terminée, pain remis")
	s.monde.fermer()


# ---------------------------------------------------------------- Prêtre et tourelle

func test_pretre_et_tourelle() -> void:
	var s := Simulation.new(101)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(GameData.catalogues.recipes.has("meuble_tourelle") and GameData.catalogues.village_buildings.has("chapelle") and GameData.catalogues.creatures.has("pretre"), "recette de tourelle, chapelle et prêtre en données")
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 1), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v.social.relations[j.id] = 80
	j.corps.stats.charisme = 25
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "recruter", "pnj": v.id})
	s._appliquer_degats(v, 9999, j.id, {})
	var ame: String = s.ame_dans_sac(j)
	verifier(not ame.is_empty(), "l'âme du compagnon est dans le sac")
	var pretre := s.ajouter("pretre", j.pos + Vector2i(-1, 0), "ia")
	s._habiller_pnj(pretre, GameData.entree("creatures", "pretre"))
	var cout := s.cout_resurrection(j, ame, true)
	verifier(cout == 20 * maxi(1, int(round(s.progression.niveaux_derives(v).combat))) and s.cout_resurrection(j, ame, false) == int(float(cout) * 1.5), "coût chez le prêtre %d or, ×1,5 à l'autel" % cout)
	j.or = cout
	pretre.or = int(pretre.or_max) - 5
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "ressusciter", "ame": ame, "pnj": pretre.id}) and v.vivant and int(j.or) == 0, "le prêtre rappelle le compagnon")
	verifier(int(pretre.or) == int(pretre.or_max), "sa bourse est finie : le surplus sort du jeu")
	verifier(float(v.get("affaibli_mult", 1.0)) < 1.0, "le ressuscité revient Affaibli")
	s.monde.fermer()


# ---------------------------------------------------------------- Talents de classe et de race

func test_regle_anneau_mesure() -> void:
	var s := Simulation.new(103)
	var L := {"type": "anneau", "n": 16}
	var rng := RandomNumberGenerator.new()
	rng.seed = 103
	var cible := 8   # l'opposé sur un anneau de 16, départ à 0
	var essais := 60
	var dirige := 0
	var hasard := 0
	for k in essais:
		# Dirigé : deux parents, on garde le couple le plus proche de la cible.
		var a := 0
		var b := 0
		var n := 0
		while n < 5000:
			n += 1
			var enfant: int = s._heriter(a, b, L, rng)
			if enfant == cible:
				break
			var da: int = mini(posmod(a - cible, 16), posmod(cible - a, 16))
			var db: int = mini(posmod(b - cible, 16), posmod(cible - b, 16))
			var de: int = mini(posmod(enfant - cible, 16), posmod(cible - enfant, 16))
			if de < maxi(da, db):
				if da >= db:
					a = enfant
				else:
					b = enfant
		dirige += n
		# Hasard : on remplace un parent au hasard, sans regarder.
		a = 0
		b = 0
		n = 0
		while n < 20000:
			n += 1
			var enfant2: int = s._heriter(a, b, L, rng)
			if enfant2 == cible:
				break
			if rng.randf() < 0.5:
				a = enfant2
			else:
				b = enfant2
		hasard += n
	var moy_d := float(dirige) / float(essais)
	var moy_h := float(hasard) / float(essais)
	print("  mesure Règle d'anneau : dirigé %.0f couvées, hasard %.0f couvées, facteur ×%.1f" % [moy_d, moy_h, moy_h / maxf(1.0, moy_d)])
	verifier(moy_d < moy_h and moy_h / maxf(1.0, moy_d) >= 4.0, "sélection dirigée contre hasard : facteur ×%.1f (attendu ≈ ×15, au moins ×4)" % (moy_h / maxf(1.0, moy_d)))


# ---------------------------------------------------------------- Étape 9.D : compagnons, apprivoisement, âge

func test_chatoyant() -> void:
	var s := Simulation.new(105)
	s.charger_camp()
	var rng := RandomNumberGenerator.new()
	rng.seed = 105
	var n0 := 0
	var n1 := 0
	for k in 4000:
		if s._tirer_chatoyant(rng, false):
			n0 += 1
		if s._tirer_chatoyant(rng, true):
			n1 += 1
	verifier(n0 >= 20 and n0 <= 120 and n1 >= 250 and n1 <= 480, "sur 4 000 tirages : %d chatoyants sans parent (≈60), %d avec (≈360)" % [n0, n1])
	var c := s._nouveau_specimen("carpe", {"couleur": 2, "motif": 3, "taille": 2.0}, "f", true)
	verifier(bool(c.chatoyant) and int(s.territoire.chatoyants.carpe) == 1 and str(c.nom.params.chatoyant) == "ui.specimen.chatoyant", "un spécimen chatoyant est compté et nommé")
	# Une commande chatoyante n'accepte qu'un chatoyant.
	s.territoire["commande"] = {"espece": "carpe", "couleur": 5, "motif": "3", "or": 600, "semaine": 0, "chatoyant": true}
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var m := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(m, GameData.entree("creatures", "villageois"))
	m.tags.append("commerce_possible")
	m.or = 1000
	var ordinaire := s._nouveau_specimen("carpe", {"couleur": 5, "motif": 3, "taille": 2.0}, "f", false)
	j.sac.append(ordinaire.uid)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "livrer", "pnj": m.id}), "un spécimen ordinaire ne satisfait pas une commande chatoyante")
	var brillant := s._nouveau_specimen("carpe", {"couleur": 5, "motif": 3, "taille": 2.0}, "f", true)
	j.sac.append(brillant.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "livrer", "pnj": m.id}), "le chatoyant est livré")
	s.monde.fermer()


# ---------------------------------------------------------------- Règle d'anneau : la mesure (sélection dirigée contre hasard)
