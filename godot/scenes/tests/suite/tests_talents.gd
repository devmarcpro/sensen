extends TestsBase
## Les routes, l'habitat, les talents et les formes : lumière, industriel, bétail, classes cachées, vampire, spectre, lycanthrope, incarnation, cataclysme.
## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de
## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l'ordre de sa liste.


func test_routes() -> void:
	var s := Simulation.new(107)
	s.charger_camp()
	var surf = s.monde.surface
	# Un royaume trouvé dans les secteurs voisins qui a au moins un village hors capitale : ses routes le relient.
	var trouve: Dictionary = {}
	for k in 60:
		var sect: Vector2i = surf.secteur_de(s.monde.cellule_camp) + Vector2i(k % 8 - 4, k / 8 - 4)
		for r in surf.royaumes_secteur(sect).values():
			if r.get("routes", []).size() >= 2 and trouve.is_empty():
				trouve = r
	if trouve.is_empty():
		verifier(true, "aucun royaume à routes dans les secteurs voisins (rien à mesurer)")
	else:
		var cap: Vector2i = trouve.capital_poi
		verifier(not surf.route_de(cap).is_empty(), "%s : la capitale est reliée (%d cellules de route)" % [trouve.nom, trouve.routes.size()])
		var relie := true
		for c in trouve.routes:
			relie = relie and not surf.route_de(c).is_empty() and surf.terre_a(c)
		verifier(relie, "chaque cellule de route a une voisine reliée, sur la terre")
		var e: Dictionary = surf.generer_cellule(cap.x, cap.y)
		verifier(e.get("route", {}).size() >= 20, "la capitale porte un chemin de sol (%d tuiles)" % e.get("route", {}).size())
	s.monde.fermer()


# ---------------------------------------------------------------- Le chatoyant

func test_habitat_pnj() -> void:
	var s := Simulation.new(109)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Une chambre 3×3 murée avec une porte, un lit et une table, dégagée près du joueur.
	var o: Vector2i = j.pos + Vector2i(3, 3)
	for y in range(-1, 4):
		for x in range(-1, 4):
			var q: Vector2i = o + Vector2i(x, y)
			s.grille.contenu[s.grille.idx(q)] = 0
			s.grille.meubles.erase(s.grille.idx(q))
			s.contenants.erase(s.grille.idx(q))
			if x == -1 or y == -1 or x == 3 or y == 3:
				s.grille.poser_contenu(q, "mur_construit")
	s.grille.poser_contenu(o + Vector2i(1, -1), "porte")
	s.grille.poser_contenu(o, "meuble")
	s.grille.meubles[s.grille.idx(o)] = "lit_de_paille"
	s.grille.poser_contenu(o + Vector2i(2, 2), "meuble")
	s.grille.meubles[s.grille.idx(o + Vector2i(2, 2))] = "table"
	var cell: Vector2i = s._cell_de(o)
	var pieces: Array = s.pieces_de_cellule(cell)
	verifier(pieces.size() == 1 and pieces[0].tuiles.size() == 9 and pieces[0].meubles.size() == 2, "une pièce close de 9 tuiles avec deux types de meubles (%d pièce(s))" % pieces.size())
	# Un résident logé dans cette pièce, un autre sans pièce ; un garde-manger vide puis plein.
	var a := s.ajouter("villageois", o + Vector2i(1, 1), "ia")
	s._habiller_pnj(a, GameData.entree("creatures", "villageois"))
	a["assignation"] = {"fonction": "fermier", "cellule": cell}
	a["lit"] = o
	a.camp = "joueur"
	var b := s.ajouter("villageois", j.pos + Vector2i(-2, 0), "ia")
	s._habiller_pnj(b, GameData.entree("creatures", "villageois"))
	b["assignation"] = {"fonction": "fermier", "cellule": cell}
	b.camp = "joueur"
	s._nourrir_residents()   # le repas est une étape à part depuis le 2026-09-04 (Faim des PNJ) : rien à manger ici
	s._recalculer_humeurs()
	verifier(int(a.humeur) == 60 + 2 - 10 and int(b.humeur) == 60 - 15 - 10, "logé : 60 +2 meubles −10 faim = %d ; sans pièce : 60 −15 −10 = %d" % [int(a.humeur), int(b.humeur)])
	var gm: Vector2i = j.pos + Vector2i(0, -2)
	s.grille.contenu[s.grille.idx(gm)] = 0
	s.grille.poser_contenu(gm, "meuble")
	s.grille.meubles[s.grille.idx(gm)] = "garde_manger"
	var pain := s.generer_objet("pain", 1, {}, "commun", 0)
	pain.quantite = 5
	s.contenants[s.grille.idx(gm)] = [pain.uid]
	s._nourrir_residents()
	s._recalculer_humeurs()
	verifier(int(a.humeur) == 62 and int(b.humeur) == 45 and int(pain.quantite) == 3, "garde-manger garni : plus de malus de faim, deux pains mangés")
	s.monde.fermer()


# ---------------------------------------------------------------- Routes

func test_artefacts() -> void:
	var s := Simulation.new(111)
	s.charger_donjon("ruine", 111, 7, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var art := s.generer_objet("proto_epee", 3, {}, "artefact")
	verifier(art.rarete == "artefact" and art.affixes.size() >= 2 and art.affixes.size() <= 3 and bool(art.get("fini", false)) and not art.has("sertissures"), "un artefact : %d affixes, fini, sans sertissure" % art.affixes.size())
	# Au-dessus des fourchettes : sur 40 tirages, au moins un paramètre dépasse sa borne haute déclarée.
	var depasse := false
	for k in 40:
		var a := s.generer_objet("proto_epee", 3, {}, "artefact")
		for ax in a.affixes:
			var def: Dictionary = GameData.entree("affixes", str(ax.id))
			for nom in ax.params.keys():
				var spec = def.parametres.get(nom)
				if spec is Array and spec.size() == 2 and not (spec[0] is String) and str(def.meilleur.get(nom, "")) == "haut" and int(ax.params[nom]) > int(spec[1]):
					depasse = true
	verifier(depasse, "des paramètres au-dessus de la fourchette normale")
	# Le boss d'un donjon majeur (7 étages) laisse un artefact garanti.
	s.donjon.etages = 5
	var boss := s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	boss["chain_gauge"] = true
	s._appliquer_degats(boss, 9999, j.id, {})
	var trouve := false
	for uid in s.contenants.get(s.grille.idx(boss.pos), []):
		trouve = trouve or str(s.items[uid].get("rarete", "")) == "artefact"
	verifier(trouve, "le boss d'un donjon majeur laisse un artefact")
	# Sertir un artefact est refusé.
	j.sac.append(art.uid)
	var gemme := s.generer_objet("gemme_brute", 1, {}, "commun", 0) if GameData.catalogues.items.has("gemme_brute") else {}
	if not gemme.is_empty():
		j.sac.append(gemme.uid)
		s.attente[j.id] = true
		verifier(not s.intention(j.id, {"type": "sertir", "objet": art.uid, "gemme": gemme.uid}), "un artefact ne se sertit pas")


# ---------------------------------------------------------------- Habitat et faim des PNJ

func test_talents() -> void:
	var s := Simulation.new(113)
	s.charger_donjon("ruine", 113, 8, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(GameData.catalogues.talents.size() >= 11, "onze talents en données (%d)" % GameData.catalogues.talents.size())
	# Le Sabre : un changement d'arme gratuit par chaîne.
	j.classe = "le_sabre"
	verifier(s.a_talent(j, "ratelier_vivant"), "Le Sabre porte Râtelier vivant")
	var autre := ""
	for uid in j.ratelier:
		if uid != j.equipement.get("main_principale", "") and s.items[uid].type == "arme":
			autre = uid
	if not autre.is_empty():
		var t0: int = int(j.compteur)
		s.attente[j.id] = true
		s.intention(j.id, {"type": "changer_arme", "item": autre})
		var gratuit: bool = int(j.compteur) == t0 or int(j.compteur) == s.horloge_monde.ticks or bool(j.get("swap_gratuit_pris", false))
		verifier(gratuit and bool(j.get("swap_gratuit_pris", false)), "premier changement d'arme : 0 tick, le suivant paiera")
	# La Balance : +1 place d'escorte.
	j.classe = "la_balance"
	var places_b := s.places_escorte(j)
	j.classe = "le_sabre"
	verifier(places_b == s.places_escorte(j) + 1, "Œil du prix : +1 place d'escorte")
	# L'Elfe : la surchauffe coûte de l'endurance, pas de santé.
	j.race = "elfe"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	var end0 := int(j.vigueur_max)
	verifier(s.a_talent(j, "chair_de_mana") and end0 == s.regles.vigueur_max(j.stats_eff) - 20, "Chair de mana : vigueur max −20 (%d)" % end0)
	j.mana = 0
	var sante0 := int(j.sante)
	j.vigueur = 50
	s._payer(j, {"monnaie": "mana", "ressource": 5, "charge_suivante": {}})
	verifier(int(j.sante) == sante0 and int(j.vigueur) == 50 - 10, "surchauffe de 5 : −10 d'endurance, santé intacte")
	# Le Nain : rien n'est irrécoltable.
	j.race = "nain"
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	verifier(s.a_talent(j, "oeil_de_la_pierre") and "detection_filons" in j.tags_acquis, "Œil de la pierre : sent les filons")
	# Le Vent apprend le talent d'un PNJ à relation ≥ 75.
	j.race = "humain"
	j.classe = "le_vent"
	var m := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(m, GameData.entree("creatures", "villageois"))
	m.classe = "la_paume"
	m.social.relations[j.id] = 50
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "apprendre_talent", "pnj": m.id}), "à 50 de relation : refus")
	m.social.relations[j.id] = 80
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "apprendre_talent", "pnj": m.id}) and s.a_talent(j, "souffle_rendu"), "à 80 : Le Vent apprend Souffle rendu")
	verifier(not m.get("classe", "").is_empty(), "les PNJ portent une classe (%s)" % str(m.classe))


# ---------------------------------------------------------------- Assemblage de capacités, Renaissance

func test_reforge_et_fiole() -> void:
	var s := Simulation.new(115)
	s.charger_donjon("ruine", 115, 9, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	j.classe = "la_braise"
	var etabli := s.generer_objet("station_etabli", 1, {}, "commun", 0)
	j.sac.append(etabli.uid)
	# Une épée assemblée (fer) avec un affixe, reforgée avec une lame de cuivre.
	var epee := s.generer_objet("craft_epee", 2, {}, "rare", 1)
	epee["composants"] = {"tete": {"composant": "lame_longue", "materiau": "fer", "qualite": 1.0}, "manche": {"composant": "poignee", "materiau": "chene", "qualite": 1.0}, "garde": {"composant": "garde", "materiau": "fer", "qualite": 1.0}}
	epee.materiau = "fer"
	j.sac.append(epee.uid)
	var n_aff: int = epee.affixes.size()
	var lame := s.generer_objet("composant", 1, {}, "commun", 0)
	lame.composant = "lame_longue"
	lame.materiau = "cuivre"
	lame.stats = GameData.entree("materials", "cuivre").stats.duplicate()
	lame.elements = {}
	lame.qualite = 1.4
	j.sac.append(lame.uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "reforger", "objet": epee.uid, "composant": lame.uid}), "reforger l'épée avec une lame de cuivre")
	verifier(epee.composants.tete.materiau == "cuivre" and epee.materiau == "cuivre" and epee.affixes.size() == n_aff and not (lame.uid in j.sac), "la lame remplacée, le matériau suit, les affixes tiennent (%d), le composant consommé" % epee.affixes.size())
	j.classe = "le_sabre"
	var lame2 := s.generer_objet("composant", 1, {}, "commun", 0)
	lame2.composant = "lame_longue"
	lame2.materiau = "fer"
	j.sac.append(lame2.uid)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "reforger", "objet": epee.uid, "composant": lame2.uid}), "sans Main du métal : refus")
	# Fiole vive : la potion touche l'allié adjacent ; la recette demande le double.
	j.classe = "le_creuset"
	var ami := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	ami.camp = j.camp
	var pot := s.generer_objet("potion_force", 1, {}, "commun", 0)
	j.sac.append(pot.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "manger", "objet": pot.uid})
	var touche := false
	for st in ami.statuts:
		touche = touche or str(st.id).begins_with("potion_force")
	verifier(touche, "Fiole vive : l'allié adjacent reçoit la potion")
	var plan := s._plan_recette(j, GameData.catalogues.recipes.distiller_partie)
	verifier(int(plan.entrees[0].besoin) == 2, "Fiole vive : la distillation demande le double (%d)" % int(plan.entrees[0].besoin))


# ---------------------------------------------------------------- Trésors et artefacts

func test_communion() -> void:
	var s := Simulation.new(121)
	s.charger_donjon("ruine", 121, 12, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	j.classe = "le_souffle"
	verifier(s.a_talent(j, "communion_des_cinq"), "Le Souffle porte Communion des cinq")
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	loup.sante = 999
	loup.sante_max = 999
	var arme := Etres.arme(j, s.items)
	var el0 := str(arme.get("element", ""))
	j.mana = 10
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "un coup d'arme")
	verifier(str(j.get("element_communion", "")) == str(s.wuxing.w.engendre.get(el0, "")) and int(j.mana) == 8, "l'élément tourne %s → %s, 2 de mana" % [el0, str(j.get("element_communion", "?"))])
	var v := s._vecteur_arme_de(j, arme)
	verifier(v.has(str(j.element_communion)), "le prochain coup porte l'élément tourné")
	j.mana = 0
	var avant := str(j.element_communion)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	verifier(str(j.element_communion) == avant, "sans mana, l'élément ne tourne plus")


# ---------------------------------------------------------------- Main du métal, Fiole vive

func test_lumiere() -> void:
	var s := Simulation.new(123)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var jour := int(s._cycle().ticks_par_jour)
	s.horloge_monde.ticks = 0   # minuit
	verifier(s.est_nuit(), "il fait nuit")
	var g := s.ajouter("villageois", j.pos + Vector2i(8, 0), "ia")
	s._habiller_pnj(g, GameData.entree("creatures", "villageois"))
	g.corps.stats.perception = 10
	for d in range(1, 9):
		var q: Vector2i = j.pos + Vector2i(d, 0)
		s.grille.contenu[s.grille.idx(q)] = 0
	verifier(not s.voit_ia(g, j), "dans le noir, à 8 tuiles : invisible (portée 10 × 0,6)")
	var torche := s.generer_objet("torche", 1, {}, "commun", 0)
	j.sac.append(torche.uid)
	j.equipement["main_secondaire"] = torche.uid
	verifier(s.lumiere_de(j) == 70 and s.lumiere_a(j.pos) == 70, "une torche en main : lumière 70")
	verifier(s.voit_ia(g, j), "avec la torche : vu de plus loin (portée × 1,35)")
	j.equipement.erase("main_secondaire")
	j["vue_sale"] = true
	s.maj_vision()
	var vue0: int = j.vue.size()
	j.equipement["main_secondaire"] = torche.uid
	j["vue_sale"] = true
	s.maj_vision()
	verifier(j.vue.size() > vue0, "la torche rend la vue la nuit (%d → %d tuiles)" % [vue0, j.vue.size()])
	s.horloge_monde.ticks = jour / 2
	verifier(not s.est_nuit() and s.voit_ia(g, j), "à midi, vu sans lumière")
	s.monde.fermer()


# ---------------------------------------------------------------- Communion des cinq

func test_palier_industriel() -> void:
	var s := Simulation.new(125)
	s.charger_donjon("ruine", 125, 13, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var forge := s.generer_objet("station_forge", 1, {}, "commun", 0)
	j.sac.append(forge.uid)
	s._donner_materiau(j, "verre", 4, "brut")
	s._donner_materiau(j, "houille", 2, "brut")
	var visibles: Array = []
	for pl in s.recettes_disponibles(j):
		visibles.append(str(pl.id))
	verifier(not ("tremper_verre" in visibles), "sans le plan, tremper le verre est invisible")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "fabriquer", "recette": "tremper_verre"}), "et refusée à la fabrication")
	var plan := s.generer_objet("plan_industriel", 4, {}, "commun", 0)
	verifier(bool(GameData.catalogues.recipes.get(str(plan.get("recette", "")), {}).get("industrielle", false)) and plan.modules.is_empty(), "un plan porte une recette industrielle (%s)" % str(plan.get("recette", "?")))
	plan.recette = "tremper_verre"
	j.sac.append(plan.uid)
	j.competences["lecture"] = 100
	Etres.recalculer(j, s.items, s.affixes_defs, s.regles)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "lire", "objet": plan.uid}) and ("tremper_verre" in j.get("recettes_connues", [])), "lire le plan : la recette est connue")
	visibles = []
	for pl in s.recettes_disponibles(j):
		visibles.append(str(pl.id))
	verifier("tremper_verre" in visibles, "elle apparaît à l'atelier")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "fabriquer", "recette": "tremper_verre"}) and not s._pile(j, "verre_trempe", "brut").is_empty(), "tremper le verre : du verre trempé")
	# Un plan tombe parfois dans les ruines profondes.
	var trouve := false
	for k in 80:
		var loup := s.ajouter("loup", j.pos + Vector2i(3 + (k % 5), 3), "ia")
		s.donjon.profondeur = 4
		s._appliquer_degats(loup, 9999, j.id, {})
		for uid in s.contenants.get(s.grille.idx(loup.pos), []):
			trouve = trouve or str(s.items[uid].base) == "plan_industriel"
		s.contenants.erase(s.grille.idx(loup.pos))
		s.grille.contenu[s.grille.idx(loup.pos)] = 0
	verifier(trouve, "un plan industriel est tombé en profondeur (80 morts, 8 %)")


# ---------------------------------------------------------------- Éclairage : lumière locale, vision, détection

func test_betail() -> void:
	var s := Simulation.new(127)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v["assignation"] = {"fonction": "fermier", "cellule": s._cell_de(v.pos)}
	v.camp = "joueur"
	v.social.relations[j.id] = 40
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "statut_habitat", "pnj": v.id, "statut": "betail"}) and v.statut_habitat == "betail" and int(v.social.relations[j.id]) == 10, "un PNJ traité en bétail : relation −30")
	s._recalculer_humeurs()
	verifier(int(v.humeur) == 60 - 15 - 20, "bétail sans abri, rétrogradé : 60 −15 −20 = %d (il ne mange pas au garde-manger)" % int(v.humeur))
	var enc: Vector2i = j.pos + Vector2i(0, 2)
	s.grille.contenu[s.grille.idx(enc)] = 0
	s.grille.poser_contenu(enc, "meuble")
	s.grille.meubles[s.grille.idx(enc)] = "enclos"
	s._recalculer_humeurs()
	verifier(int(v.humeur) == 60 - 20, "avec un enclos à portée : abrité (%d)" % int(v.humeur))
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "statut_habitat", "pnj": v.id, "statut": "normal"}) and v.statut_habitat == "normal", "redevenu résident")
	# Une bête apprivoisée est bétail sans malus.
	var b := s.ajouter("cerf", j.pos + Vector2i(-1, 0), "ia")
	b["maitre"] = j.id
	b.camp = "joueur"
	b["assignation"] = {"fonction": "oisif", "cellule": s._cell_de(b.pos)}
	if not b.has("social"):
		b["social"] = {"relations": {}}
	s.attente[j.id] = true
	s.intention(j.id, {"type": "statut_habitat", "pnj": b.id, "statut": "betail"})
	s._recalculer_humeurs()
	verifier(int(b.humeur) == 60, "une bête bétail abritée : 60, sans malus (%d)" % int(b.humeur))
	s.monde.fermer()


# ---------------------------------------------------------------- Palier industriel

func test_ombre_et_rieur() -> void:
	var s := Simulation.new(129)
	s.charger_donjon("ruine", 129, 14, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Le jet de coup : sur 200 attaques, des critiques et des ratés apparaissent.
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	loup.sante_max = 100000
	loup.sante = 100000
	for k in 200:
		loup.sante = loup.sante_max   # le loup encaisse 200 coups : on le soigne entre deux
		s.attente[j.id] = true
		s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	var crit: int = int(j.get("coups_critiques", 0))
	var rate: int = int(j.get("coups_rates", 0))
	verifier(crit >= 3 and rate >= 3, "200 coups : %d critiques, %d ratés (≈5 %% chacun)" % [crit, rate])
	# Le Rieur : la relance se réarme à l'engagement.
	j.classe = "le_rieur"
	verifier(s.a_talent(j, "deux_queues"), "Le Rieur porte Deux queues")
	j["relance_utilisee"] = true
	s._engager_combat(j, loup)
	verifier(not j.has("relance_utilisee"), "l'engagement réarme la relance")
	# L'Ombre : dissimulé après une mise à mort, invisible à distance, visible adjacent.
	j.classe = "l_ombre"
	var proie := s.ajouter("renard", j.pos + Vector2i(0, 1), "ia")
	proie.sante = 1
	s._appliquer_degats(proie, 10, j.id, {})
	verifier(Etres.a_statut_tag(j, "dissimule", s.statuts_defs), "après la mise à mort : Dissimulé")
	var guetteur := s.ajouter("bandit", j.pos + Vector2i(4, 0), "ia")
	for d in range(1, 4):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 0))] = 0
	guetteur.corps.stats.perception = 12
	verifier(not s.voit_ia(guetteur, j), "à 4 tuiles : le guetteur ne le voit pas")
	var proche := s.ajouter("bandit", j.pos + Vector2i(-1, 0), "ia")
	proche.corps.stats.perception = 12
	verifier(s.voit_ia(proche, j), "adjacent : vu")
	var frappe := false
	for k in 5:   # un coup raté ne lève pas la dissimulation : on frappe jusqu'à toucher
		loup.sante = loup.sante_max
		s.attente[j.id] = true
		frappe = frappe or s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
		if not Etres.a_statut_tag(j, "dissimule", s.statuts_defs):
			break
	verifier(frappe and not Etres.a_statut_tag(j, "dissimule", s.statuts_defs), "attaquer lève la dissimulation")


# ---------------------------------------------------------------- Statut bétail

func test_ecarlate_et_porteur() -> void:
	var s := Simulation.new(131)
	s.charger_donjon("ruine", 131, 15, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	j.classe = "l_ecarlate"
	verifier(s.a_talent(j, "jauge_de_sang"), "L'Écarlate porte la jauge de sang")
	j.sante = 40
	s._appliquer_degats(j, 30, "", {"type": "test"})
	verifier(int(j.get("sang", 0)) == 30, "30 de dégâts subis : sang 30")
	var fiole := s.generer_objet("fiole_de_soin", 1, {}, "commun", 0)
	j.sac.append(fiole.uid)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "manger", "objet": fiole.uid})
	verifier(int(j.get("sang", 0)) == 0, "boire une fiole de soin vide la jauge")
	# Le Porteur : saisir un loup adjacent, ne plus pouvoir attaquer, le lancer.
	j.classe = "le_porteur"
	var loup := s.ajouter("loup", j.pos + Vector2i(1, 0), "ia")
	for d in range(1, 5):
		var q: Vector2i = j.pos + Vector2i(d, 0)
		if d > 1:
			s.grille.contenu[s.grille.idx(q)] = 0
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "saisir", "cible": loup.id}) and str(j.porte) == loup.id and Etres.a_statut_tag(loup, "saisi", s.statuts_defs), "le loup est saisi")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "en portant : pas d'attaque")
	var sante0 := int(loup.sante)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "lancer_etre", "vers": j.pos + Vector2i(3, 0)}) and not j.has("porte"), "lancé")
	verifier(Grille.distance(j.pos, loup.pos) >= 2 and int(loup.sante) < sante0, "le loup atterrit à %d tuiles, blessé (%d → %d)" % [Grille.distance(j.pos, loup.pos), sante0, int(loup.sante)])


# ---------------------------------------------------------------- L'Ombre, Le Rieur, le jet de coup

func test_passeur_et_sablier() -> void:
	var s := Simulation.new(132)
	s.charger_donjon("ruine", 132, 15, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var mana0 := int(j.mana_max)
	j.classe = "le_passeur"
	s._contreparties(j)
	verifier(int(j.mana_max) == maxi(1, roundi(mana0 * 0.7)), "Le Passeur : mana max %d → %d" % [mana0, int(j.mana_max)])
	for d in range(1, 5):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 0))] = 0
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "poser_portail", "cible": j.pos + Vector2i(1, 0)}), "portail 1 posé")
	s.grille.contenu[s.grille.idx(j.pos + Vector2i(0, 1))] = 0
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "poser_portail", "cible": j.pos + Vector2i(0, 1)}) and s.portails.size() == 2, "portail 2 posé")
	s.grille.contenu[s.grille.idx(j.pos + Vector2i(-1, 0))] = 0
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "poser_portail", "cible": j.pos + Vector2i(-1, 0)}) and s.portails.size() == 2 and not s.portails.has(s.grille.idx(j.pos + Vector2i(1, 0))), "le troisième déplace le plus ancien")
	var depart: Vector2i = j.pos
	s.grille.liberer(j.pos)
	j.pos = depart + Vector2i(0, 1)
	s.grille.placer(j.id, j.pos)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "traverser"}) and j.pos == depart + Vector2i(-1, 0), "traversée vers le jumeau")
	# Le Sablier
	j.classe = "le_sablier"
	s._contreparties(j)
	verifier(int(j.mana_max) == mana0, "la contrepartie du Passeur est levée")
	var loup := s.ajouter("loup", depart + Vector2i(2, 0), "ia")
	var c0 := int(loup.compteur)
	var sante0 := int(j.sante)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "tempo", "cible": loup.id}) and int(loup.compteur) == c0 + 8 and int(j.sante) == sante0 - 5, "tempo volé : loup +8, −5 PV")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "tempo", "cible": loup.id}), "le verrou anti-stunlock refuse le second vol")


# ---------------------------------------------------------------- L'Écarlate et Le Porteur

func test_masque_et_sceau() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	j.classe = "le_masque"
	var force0 := int(j.stats_eff.force)
	s.attente[j.id] = true
	var c0 := int(j.compteur)
	verifier(s.intention(j.id, {"type": "masque", "masque": "masque_du_taureau"}) and int(j.stats_eff.force) == force0 + 3 and int(j.compteur) == c0, "Taureau : +3 Force, à 0 tick")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "masque", "masque": "masque_du_renard"})
	s.attente[j.id] = true
	s.intention(j.id, {"type": "masque", "masque": "masque_du_hibou"})
	var portes: Array = j.statuts.filter(func(s0: Dictionary) -> bool: return "masque" in s.statuts_defs[str(s0.id)].get("tags", []))
	verifier(portes.size() == 2 and str(portes[0].id) == "masque_du_renard" and int(j.stats_eff.force) == force0, "le troisième masque remplace le Taureau : Renard + Hibou")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "garde"}), "Le Masque ne prend pas la garde")
	s.attente[j.id] = true
	s.intention(j.id, {"type": "masque", "masque": "masque_du_hibou"})
	verifier(j.statuts.filter(func(s0: Dictionary) -> bool: return str(s0.id) == "masque_du_hibou").is_empty(), "reporter le même masque le retire")
	# Le Sceau : glyphe permanent à 2× mana, immobile, déclenché à distance
	j.classe = "le_sceau"
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(0, -4)
	s.grille.placer(loup.id, loup.pos)
	for id in ["loup_2", "loup_3", "loup_4"]:
		s.entites[id].compteur = 500
	s._engager_combat(j, loup)
	var h := s.horloge_de(j)
	j.mana = 300
	_capacite_test(s, j, "g", ["sceau", "tuile", "racine"])
	j.compteur = h.ticks
	s.pas(j.horloge)
	var glyphe_pos: Vector2i = j.pos + Vector2i(0, -2)
	var mana0 := int(j.mana)
	verifier(s.intention(j.id, {"type": "capacite", "index": j.capacites.size() - 1, "cible": glyphe_pos}), "poser le glyphe")
	s.pas(j.horloge)
	verifier(s.glyphes.size() == 1 and int(s.glyphes[0].fin) > h.ticks + 100000 and Etres.bloque_statuts(j, "deplacement", s.statuts_defs), "glyphe permanent, graveur immobile (mana %d → %d)" % [mana0, int(j.mana)])
	s.grille.liberer(loup.pos)
	loup.pos = glyphe_pos
	s.grille.placer(loup.id, glyphe_pos)
	j.compteur = h.ticks
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "declencher_glyphe", "cible": glyphe_pos}) and s.glyphes.is_empty() and Etres.bloque_statuts(loup, "deplacement", s.statuts_defs), "déclenché à distance : le loup est enraciné")


# ---------------------------------------------------------------- Le Passeur et Le Sablier

func test_fossoyeur_et_engrenage() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	j.classe = "le_fossoyeur"
	j["reputations"] = {"bourg": 20}
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(0, -2)
	s.grille.placer(loup.id, loup.pos)
	s._appliquer_degats(loup, 999, j.id, {"type": "test"})
	verifier(not loup.vivant, "le loup est mort")
	var n0 := s.vivants().size()
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "relever", "cible": loup.id}) and s.vivants().size() == n0 + 1 and int(j.reputations.bourg) == 10, "relevé : un loup de plus au camp du joueur, réputation 20 → 10")
	var releve: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.has("fin_invocation"))[0]
	verifier(releve.camp == j.camp and str(releve.maitre) == j.id and releve.pos == loup.pos, "il se lève sur la tuile du cadavre, au camp du joueur")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "relever", "cible": loup.id}), "un cadavre ne se relève qu'une fois")
	var h := s.horloge_de(j)
	h.avancer(61)
	s._tiquer_differes(j.horloge, h.ticks)
	verifier(not releve.vivant, "après 60 ticks, le relevé retourne à la terre")
	# L'Engrenage : un affût qui mange le carquois
	j.classe = "l_engrenage"
	var loup3: Dictionary = s.entites["loup_3"]
	s.grille.liberer(loup3.pos)
	loup3.pos = j.pos + Vector2i(3, 0)
	s.grille.placer(loup3.id, loup3.pos)
	for d in range(1, 4):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 0))] = 0
	var mun0 := int(j.munitions)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "affut", "cible": j.pos + Vector2i(1, 0)}) and s.affuts.size() == 1, "affût déployé")
	var pv0 := int(loup3.sante)
	s._tirs_d_affuts(j.horloge, h.ticks + 100)
	verifier(int(loup3.sante) < pv0 and int(j.munitions) == mun0 - 1, "il tire sur le loup (%d → %d) et consomme une flèche (%d → %d)" % [pv0, int(loup3.sante), mun0, int(j.munitions)])
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "affut", "cible": j.pos + Vector2i(0, 1)}) and s.affuts.size() == 1 and s.affuts[0].pos == j.pos + Vector2i(0, 1), "redéployer déplace l'affût")
	j.munitions = 0
	s._tirs_d_affuts(j.horloge, h.ticks + 200)
	verifier(s.affuts.is_empty(), "sans munition, l'affût se replie")


# ---------------------------------------------------------------- Le Masque et Le Sceau

func test_propagation_lumiere() -> void:
	var s := Simulation.new(133)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	for d in range(-2, 7):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 2))] = 0
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 3))] = 0
	var src: Vector2i = j.pos + Vector2i(0, 2)
	s.grille.poser_contenu(src, "meuble")
	s.grille.meubles[s.grille.idx(src)] = "torchere"
	s.lumiere_sale = true
	var n0 := s.niveau_lumiere(src)
	verifier(n0 >= 9 and s.niveau_lumiere(src + Vector2i(1, 0)) == n0 - 1 and s.niveau_lumiere(src + Vector2i(3, 0)) == n0 - 3, "torchère : niveau %d, −1 par tuile" % n0)
	verifier(s.lumiere_a(src + Vector2i(1, 0)) == roundi(float(n0 - 1) * 100.0 / 15.0), "lumiere_a = niveau × 100 / 15")
	# Un mur : éclairé, mais rien ne passe derrière (la lumière contourne par les côtés, plus faible)
	var mur: Vector2i = src + Vector2i(2, 0)
	s.grille.poser_contenu(mur, "mur")
	for dy in [-1, 1]:
		s.grille.poser_contenu(src + Vector2i(2, dy), "mur")
		s.grille.poser_contenu(src + Vector2i(2, 2 * dy), "mur")
	s.lumiere_sale = true
	var derriere := s.niveau_lumiere(src + Vector2i(3, 0))
	verifier(s.niveau_lumiere(mur) == n0 - 2 and derriere < n0 - 3, "le mur est éclairé (%d) mais derrière il reste %d (< %d)" % [s.niveau_lumiere(mur), derriere, n0 - 3])
	s.monde.fermer()


# ---------------------------------------------------------------- Le Fossoyeur et L'Engrenage

func test_aciers_allies() -> void:
	var inox: Dictionary = GameData.entree("materials", "acier_inox")
	var tung: Dictionary = GameData.entree("materials", "acier_tungstene")
	var caou: Dictionary = GameData.entree("materials", "caoutchouc")
	verifier(inox.category == "metal" and int(inox.stats.durete) > int(GameData.entree("materials", "acier_trempe").stats.durete) and tung.category == "metal" and caou.category == "synthetique", "inox et tungstène sont des métaux plus durs que l'acier trempé, le caoutchouc un synthétique")
	var r: Dictionary = GameData.entree("recipes", "allier_inox")
	verifier(bool(r.get("industrielle", false)) and r.station == "forge" and r.output.material == "acier_inox", "allier_inox : recette industrielle à la forge")
	var s := Simulation.new(134)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	s.grille.stations_fixes[s.grille.idx(j.pos)] = "forge"
	verifier(not ("allier_inox" in s.recettes_disponibles(j).map(func(x: Dictionary) -> String: return str(x.get("id", "")))), "inconnue : invisible à la forge")
	if not j.has("recettes_connues"):
		j["recettes_connues"] = []
	j.recettes_connues.append("allier_inox")
	verifier("allier_inox" in s.recettes_disponibles(j).map(func(x: Dictionary) -> String: return str(x.get("id", ""))), "apprise : visible à la forge")
	s.monde.fermer()


# ---------------------------------------------------------------- Éclairage : la propagation 0-15

func test_vampire() -> void:
	var s := Simulation.new(135)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var jour := int(s._cycle().ticks_par_jour)
	s.horloge_monde.ticks = 0   # minuit
	var v := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	j.race = "vampire"
	s._contreparties(j)
	verifier(s.a_talent(j, "soif_de_sang"), "le joueur est vampire")
	var force0 := int(j.stats_eff.force)
	s._tiquer_vampires(j.horloge, 0)
	verifier(int(j.stats_eff.force) == force0 + 3 and not Etres.a_statut_tag(j, "vampire", s.statuts_defs) == false, "la nuit : +3 Force (%d → %d)" % [force0, int(j.stats_eff.force)])
	var seg0: int = j.chaine.segments.size()
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "mordre", "cible": v.id}) and j.chaine.segments.size() >= int(j.chaine.capacite) - 1 and Etres.a_statut_tag(v, "morsure", s.statuts_defs), "mordre : jauge pleine (%d → %d), le villageois porte la Morsure" % [seg0, j.chaine.segments.size()])
	var plat := s.generer_objet("plat_ragout", 1, {}, "commun", 0) if GameData.catalogues.items.has("plat_ragout") else {}
	if plat.is_empty():
		var it := {"uid": "plat_test", "type": "consommable", "tags": ["plat"], "nutrition": 30, "name_key": "x"}
		s.items["plat_test"] = it
		plat = it
	j.sac.append(plat.uid)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "manger", "objet": plat.uid}), "un plat est refusé")
	s.horloge_monde.ticks = jour / 2   # midi
	j.sante = j.sante_max
	s._tiquer_vampires(j.horloge, jour / 2)
	verifier(int(j.stats_eff.force) == force0 and j.statuts.filter(func(s0: Dictionary) -> bool: return str(s0.id) == "soleil").size() == 1, "le jour : +3 retiré, le Soleil brûle")
	verifier(v.race == "vampire" and "vision_nocturne" in v.tags_acquis and s.a_talent(v, "soif_de_sang"), "le villageois mordu s'éveille vampire à l'aube")
	s.monde.fermer()


# ---------------------------------------------------------------- Aciers alliés et caoutchouc

func test_spectre() -> void:
	var s := Simulation.new(136)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	s.monde.delta[s._cell_de(j.pos)] = 100   # une cellule mortellement corrompue
	verifier(s.monde.corruption_de(s._cell_de(j.pos)) >= 70.0, "la cellule est corrompue à %.0f" % s.monde.corruption_de(s._cell_de(j.pos)))
	s._appliquer_degats(j, 9999, "", {"type": "test"})
	verifier(not j.vivant, "le joueur meurt")
	s._respawn(j)
	verifier(j.vivant and j.race == "spectre" and s.a_talent(j, "sans_chair"), "il se relève spectre")
	var pv := int(j.sante)
	s._appliquer_degats(j, 10, "", {"type": "tranchant", "element": {}})
	verifier(pv - int(j.sante) == 3, "10 tranchant → 3 subis (×0,3)")
	verifier(s.poids_de(j).capacite == 5.0, "capacité de poids 5")
	var casque := s.generer_objet("proto_casque_cuir", 1, {}, "commun", 0)
	j.sac.append(casque.uid)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "equiper", "objet": casque.uid}), "le casque est refusé")
	# Traverser un mur d'une tuile
	var mur: Vector2i = j.pos + Vector2i(1, 0)
	var derriere: Vector2i = j.pos + Vector2i(2, 0)
	s.grille.contenu[s.grille.idx(derriere)] = 0
	s.grille.poser_contenu(mur, "mur")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "traverser_mur", "cible": derriere}) and j.pos == derriere, "il passe à travers le mur")
	# Un civil qui le voit prend peur
	var v := s.ajouter("villageois", j.pos + Vector2i(0, 1), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v.camp = "civil"
	s._decider_ia(v, s.horloge_monde.ticks)
	verifier(Etres.a_statut_tag(v, "controle", s.statuts_defs), "le villageois est terrorisé")
	s.monde.fermer()


# ---------------------------------------------------------------- Le Vampire

func test_lycanthrope() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	j.race = "lycanthrope"
	s._contreparties(j)
	var force0 := int(j.stats_eff.force)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "transformer"}) and bool(j.forme_bestiale) and int(j.stats_eff.force) == maxi(1, roundi(force0 * 1.5)), "forme bestiale : Force %d → %d" % [force0, int(j.stats_eff.force)])
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	var pv0 := int(loup.sante)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "attaquer sous forme bestiale : une action de créature")
	var h := s.horloge_de(j)
	for k in 3:
		j.compteur = h.ticks
		s.pas(j.horloge)
	verifier(int(loup.sante) < pv0, "le loup est griffé (%d → %d)" % [pv0, int(loup.sante)])
	j.compteur = h.ticks
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "capacite", "index": 0, "cible": loup.pos}), "capacité refusée sous forme bestiale")
	j.compteur = h.ticks
	s.attente[j.id] = true
	var ok_tr := s.intention(j.id, {"type": "transformer"})
	verifier(ok_tr and not bool(j.forme_bestiale) and int(j.stats_eff.force) == force0, "forme humaine : Force %d" % int(j.stats_eff.force))
	# La nuit forcée : jour 30, minuit
	var jour := int(s._cycle().ticks_par_jour)
	s.horloge_monde.ticks = 30 * jour
	s._tiquer_vampires(j.horloge, s.horloge_monde.ticks)
	verifier(bool(j.forme_bestiale) and bool(j.forme_forcee), "nuit 30 : la bête s'impose")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "transformer"}), "impossible de la quitter cette nuit")
	# Transmission : un villageois mordu s'éveille lycanthrope
	var v := s.ajouter("villageois", j.pos + Vector2i(0, 1), "ia")
	s._habiller_pnj(v, GameData.entree("creatures", "villageois"))
	v.sante = 500
	v.sante_max = 500
	s._executer_action_creature(j, s.actions_creatures.morsure_puissante, v)
	verifier(Etres.a_statut_tag(v, "morsure_lune", s.statuts_defs), "le villageois porte la Morsure lunaire")
	s.horloge_monde.ticks = 30 * jour + jour / 2
	s._tiquer_vampires(j.horloge, s.horloge_monde.ticks)
	verifier(not bool(j.forme_bestiale) and v.race == "lycanthrope", "à l'aube : forme humaine rendue, le villageois s'éveille lycanthrope")


# ---------------------------------------------------------------- Le Spectre

func test_incarnation() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var cerf := s.ajouter("cerf", j.pos + Vector2i(0, 1), "ia")
	cerf["maitre"] = j.id
	cerf.camp = j.camp
	var ancien_id: String = j.id
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "incarner", "pnj": cerf.id}) and cerf.controle == "joueur" and j.controle == "ia" and str(j.maitre) == cerf.id, "le contrôle passe au cerf ; l'ancien corps devient compagnon")
	verifier(s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur").size() == 1, "un seul corps contrôlé")
	var casque := s.generer_objet("proto_casque_cuir", 1, {}, "commun", 0)
	cerf.sac.append(casque.uid)
	s.attente[cerf.id] = true
	verifier(not s.intention(cerf.id, {"type": "equiper", "objet": casque.uid}), "pas de mains : le casque est refusé")
	s.attente[cerf.id] = true
	verifier(not s.intention(cerf.id, {"type": "parler", "pnj": ancien_id}), "le monde ne parle pas à une bête")
	# Attaquer sans arme : les actions de créature du cerf
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = cerf.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	var pv0 := int(loup.sante)
	s.attente[cerf.id] = true
	verifier(s.intention(cerf.id, {"type": "attaquer", "cible": loup.id, "lourde": false}), "le cerf attaque avec ses actions de créature")
	var h := s.horloge_de(cerf)
	for k in 3:
		cerf.compteur = h.ticks
		s.pas(cerf.horloge)
	verifier(int(loup.sante) < pv0, "le loup encaisse (%d → %d)" % [pv0, int(loup.sante)])


# ---------------------------------------------------------------- Le Lycanthrope

func test_terrasser() -> void:
	var s := Simulation.new(137)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var t: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.contenu[s.grille.idx(t)] = 0
	var h0 := s.grille.h(t)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "terrasser", "vers": t, "sens": -1}) and s.grille.h(t) == h0 - 1, "abaisser à mains nues : %d → %d" % [h0, s.grille.h(t)])
	j.equipement.erase("main_principale")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "terrasser", "vers": t, "sens": 1}), "élever sans pioche : refusé")
	var pioche := s.generer_objet("proto_pioche", 1, {}, "commun", 0)
	if not pioche.is_empty():
		j.sac.append(pioche.uid)
		j.equipement["main_principale"] = pioche.uid
		s.attente[j.id] = true
		verifier(s.intention(j.id, {"type": "terrasser", "vers": t, "sens": 1}) and s.grille.h(t) == h0, "élever avec la pioche : %d" % s.grille.h(t))
		s.attente[j.id] = true
		s.intention(j.id, {"type": "terrasser", "vers": t, "sens": 1})
	verifier(s.modifs_terrain.has(t) and int(s.modifs_terrain[t].h) == h0, "l'état d'origine est mémorisé (h %d)" % h0)
	# Hors claim, la semaine rend la tuile ; sur un claim, elle persiste
	var cell := s._cell_de(t)
	s.monde.claims.erase(cell)
	s._regenerer_terrain_sauvage()
	verifier(s.grille.h(t) == h0 and not s.modifs_terrain.has(t), "hors claim : le monde rend la hauteur %d" % h0)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "terrasser", "vers": t, "sens": -1})
	s.monde.claims[cell] = {"proprietaire": j.id}
	s._regenerer_terrain_sauvage()
	verifier(s.grille.h(t) == h0 - 1, "sur un claim : la tranchée persiste")
	s.monde.fermer()


# ---------------------------------------------------------------- Incarnation : jouer une bête

func test_empoigne() -> void:
	var cap := Capacites.new(GameData.catalogues["modules"])
	var plan := cap.assembler(["point", "empoigne"], 5, "1d4", {})
	verifier(plan.erreurs.is_empty() and "saisie" in plan.noyau.effets, "[Point]+[Empoigne] : un plan de saisie")
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	for d in range(2, 5):
		s.grille.contenu[s.grille.idx(j.pos + Vector2i(d, 0))] = 0
	s._executer_capacite(j, plan, loup.pos, false)
	verifier(str(j.get("porte", "")) == loup.id and Etres.a_statut_tag(loup, "saisi", s.statuts_defs), "sans talent : le loup est saisi par la capacité")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "garde"}), "en portant : pas de garde")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "lancer_etre", "vers": j.pos + Vector2i(3, 0)}) and not j.has("porte") and Grille.distance(j.pos, loup.pos) >= 2, "lancé à %d tuiles" % Grille.distance(j.pos, loup.pos))


# ---------------------------------------------------------------- Terrasser et régénération

func test_armes_fantomes() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	j.mana = 30
	var arme0: String = j.equipement.get("main_principale", "")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "arme_fantome", "element": "feu"}) and str(j.equipement.main_principale) == "fantome_" + j.id and int(j.mana) == 20, "une lame de Feu en main, 10 de mana")
	verifier(s.vecteur_arme(Etres.arme(j, s.items)) == {"feu": 1.0} and (arme0.is_empty() or arme0 in j.sac), "vecteur pur {feu: 1}, l'ancienne arme au sac")
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.placer(loup.id, loup.pos)
	var pv0 := int(loup.sante)
	s.attente[j.id] = true
	s.intention(j.id, {"type": "attaquer", "cible": loup.id, "lourde": false})
	var h := s.horloge_de(j)
	for k in 3:
		j.compteur = h.ticks
		s.pas(j.horloge)
	verifier(int(loup.sante) < pv0, "la lame frappe (%d → %d)" % [pv0, int(loup.sante)])
	verifier(not s._sertir(j, "fantome_" + j.id, "", h.ticks), "ni sertissable ni enchantable")
	var mana1 := int(j.mana)
	s._tiquer_armes_fantomes(j.horloge, int(s.items["fantome_" + j.id].dernier_tick) + 100)
	verifier(int(j.mana) == mana1 - 10, "entretien : 100 ticks = −10 mana (%d → %d)" % [mana1, int(j.mana)])
	j.mana = 0
	s._tiquer_armes_fantomes(j.horloge, int(s.items["fantome_" + j.id].dernier_tick) + 10)
	verifier(not s.items.has("fantome_" + j.id) and not j.equipement.has("main_principale"), "à mana 0, la lame se dissipe")


# ---------------------------------------------------------------- Empoigne : l'effet saisie

func test_cataclysme() -> void:
	var cap := Capacites.new(GameData.catalogues["modules"])
	var plan := cap.assembler(["carre", "cataclysme", "ampleur", "ampleur"], 5, "1d4", {})
	verifier(plan.erreurs.is_empty() and int(plan.taille) == 3 and int(plan.ticks) >= 60, "[Carré]+[Cataclysme]+2×[Ampleur] : 7 × 7, %d ticks" % int(plan.ticks))
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var loup: Dictionary = s.entites["loup_2"]
	s.grille.liberer(loup.pos)
	loup.pos = j.pos + Vector2i(0, -4)
	s.grille.placer(loup.id, loup.pos)
	for id in ["loup_2", "loup_3", "loup_4"]:
		s.entites[id].compteur = 500
	s._engager_combat(j, loup)
	var h := s.horloge_de(j)
	j.mana = 99999   # un cataclysme 7 × 7 remodèle 49 tuiles : 49 × 40 = 1 960 mana — le prix suit la surface
	j.mana_max = 99999
	j.vigueur = j.vigueur_max
	_capacite_test(s, j, "k", ["carre", "cataclysme", "ampleur", "ampleur"])
	var centre: Vector2i = j.pos + Vector2i(0, -3)
	var h0 := s.grille.h(centre)
	j.compteur = h.ticks
	s.pas(j.horloge)
	verifier(s.intention(j.id, {"type": "capacite", "index": j.capacites.size() - 1, "cible": centre}), "le cataclysme est canalisé (télégraphié)")
	verifier(not j.action_en_cours.is_empty(), "la canalisation est visible : une action en cours")
	s.pas(j.horloge)
	verifier(s.grille.h(centre) == maxi(0, h0 - 4) and int(j.vigueur) == 0 and s.modifs_terrain.has(centre), "cratère : %d → %d, endurance vidée, terrain mémorisé" % [h0, s.grille.h(centre)])
	j.mana = 300
	j.compteur = h.ticks
	verifier(not s.intention(j.id, {"type": "capacite", "index": j.capacites.size() - 1, "cible": centre}), "un seul cataclysme par combat")


# ---------------------------------------------------------------- Armes fantomatiques

func test_vecteur_lieu() -> void:
	var s := Simulation.new(138)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var v := s.vecteur_lieu(j.pos)
	var total := 0.0
	for k in v.keys():
		total += float(v[k])
	verifier(v.size() == 5 and absf(total - 1.0) < 0.001, "le lieu porte un vecteur à cinq éléments normalisé (%s)" % str(v))
	var cap := Capacites.new(GameData.catalogues["modules"])
	var plan := cap.assembler(["point", "etincelle"], 5, "1d4", {})
	s.vecteur_lieu_force = {"feu": 1.0}
	verifier(is_equal_approx(s.mult_mana_lieu(j, plan), 0.85), "Étincelle (Feu) sur une terre de Feu : mana × 0,85")
	s.vecteur_lieu_force = {"eau": 1.0}
	verifier(is_equal_approx(s.mult_mana_lieu(j, plan), 1.15), "sur une terre d'Eau (qui domine le Feu) : × 1,15")
	s.vecteur_lieu_force = {"bois": 1.0}
	verifier(is_equal_approx(s.mult_mana_lieu(j, plan), 1.0), "sur une terre de Bois : × 1")
	var plan_c := cap.assembler(["point", "brasier"], 5, "1d4", {})
	j.mana = 100
	s.vecteur_lieu_force = {"feu": 1.0}
	s._payer(j, plan_c)
	var paye_feu := 100 - int(j.mana)
	j.mana = 100
	s.vecteur_lieu_force = {"eau": 1.0}
	s._payer(j, plan_c)
	var paye_eau := 100 - int(j.mana)
	verifier(paye_feu < paye_eau, "payé %d en terre de Feu, %d en terre d'Eau" % [paye_feu, paye_eau])
	# Terroir : la condition lit le lieu
	var plan_t := cap.assembler(["point", "etincelle", "terroir"], 5, "1d4", {})
	verifier(plan_t.erreurs.is_empty() and plan_t.conditions.size() == 1 and str(plan_t.conditions[0].predicat.type) == "vecteur_de_lieu", "Terroir : un prédicat structuré")
	s.vecteur_lieu_force = {"feu": 1.0}
	var ev := s._evaluer_conditions(j, plan_t, j.pos + Vector2i(1, 0))
	verifier(ev.is_empty() or not bool(ev.get("fausse", false)), "Terroir vrai sur une terre de Feu")
	s.monde.fermer()


# ---------------------------------------------------------------- Sorts cataclysmiques
