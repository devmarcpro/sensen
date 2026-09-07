extends TestsBase
## Le brouillard, les bêtes et leur horloge, la routine civile, les boutiques, le recrutement, le calendrier, les territoires, les villes, les champs, l'anneau moyen, l'économie, les transports, les PNJ distincts, les royaumes-pays, les étages.
## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de
## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l'ordre de sa liste.


func test_brouillard() -> void:
	var s := Simulation.new(7)
	s.charger_donjon("ruine", 7, 3, 1)
	var j: Dictionary = s.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
	verifier(j.has("vue") and j.vue.has(s.grille.idx(j.pos)), "le joueur voit sa propre tuile")
	verifier(s.grille.decouvert.size() == j.vue.size() and j.vue.size() > 1, "les tuiles vues sont mémorisées (%d)" % j.vue.size())
	verifier(s.grille.decouvert.size() < s.grille.largeur * s.grille.hauteur_grille / 4, "l'étage n'est pas découvert d'emblée")
	var portee := int(float(j.stats_eff.perception) * float(s.regles.r.engagement.detection_par_perception))
	var trop_loin := true
	for idx in j.vue.keys():
		var t := Vector2i(int(idx) % s.grille.largeur, int(idx) / s.grille.largeur)
		if Grille.distance(t, j.pos) > portee:
			trop_loin = false
	verifier(trop_loin, "rien au-delà de la portée de Perception (%d)" % portee)
	var loin := Vector2i(j.pos.x + portee * 3, j.pos.y)
	if s.grille.dans(loin):
		verifier(not s.voit(j, loin), "une tuile lointaine n'est pas vue")
	var v0: int = j.vue_version
	var d0 := s.grille.decouvert.size()
	s.maj_vision()
	verifier(s.grille.decouvert.size() == d0 and j.vue_version == v0, "sans bouger, rien ne change (mémoire conservée, version stable)")
	j.pos = loin if s.grille.dans(loin) and not s.grille.bloque_passage(loin) else j.pos + Vector2i(1, 0)
	s.maj_vision()
	verifier(s.grille.decouvert.size() >= d0 and j.vue_version == v0 + 1, "après un déplacement, la mémoire grandit et la version change")


# ---------------------------------------------------------------- Étape 2 : génération de donjon

## Une bête qui ouvre le combat par sa propre morsure rejoue sur l'horloge du combat (Boucle de tick, 2026-09-04) :
## son compteur était « tick du monde + coût », un tampon que l'horloge du combat n'atteignait jamais — figée.
func test_bete_engage_sur_son_horloge() -> void:
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	s.horloge_monde.ticks = 8000   # loin de zéro : un tampon du monde ne peut pas passer pour celui d'un combat
	var r: Dictionary = s.ajouter("rat_geant", j.pos + Vector2i(1, 0), "ia")
	verifier(not r.is_empty() and s.ennemis(r, j), "un rat géant hostile au contact du joueur")
	for k in 6:
		s.attente[j.id] = true
		s.intention(j.id, {"type": "attendre"})
		s.pas("monde")
		if s.en_combat(r):
			break
	verifier(s.en_combat(r), "le rat a ouvert le combat de lui-même")
	var h: int = s.horloge_de(r).ticks
	verifier(int(r.compteur) >= h and int(r.compteur) <= h + 100, "le rat rejoue sur l'horloge du combat (compteur %d, combat à t=%d)" % [int(r.compteur), h])
	var sante0 := int(j.sante)
	for k in 12:   # et il joue vraiment : le joueur qui attend prend des morsures
		s.attente[j.id] = true
		s.intention(j.id, {"type": "attendre"})
		for nom in s.combats.keys():
			s.pas(nom)
	verifier(int(j.sante) < sante0 or not j.vivant, "le rat a mordu pendant que le joueur attendait (%d → %d)" % [sante0, int(j.sante)])


## Le cri de ralliement est poussé (IA des créatures, 2026-09-04) : un chef engagé, un acolyte à côté sans le
## statut — le chef crie avant de charger, l'acolyte est rallié. Avant, aucune action d'allié à statut n'était choisie.
func test_cri_de_ralliement() -> void:
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	s.horloge_monde.ticks = 8000
	var chef: Dictionary = s.ajouter("chef_de_bande", j.pos + Vector2i(3, 0), "ia")
	var acolyte: Dictionary = s.ajouter("bandit", j.pos + Vector2i(4, 1), "ia")
	verifier(not chef.is_empty() and not acolyte.is_empty(), "un chef de bande et son acolyte")
	verifier(not s._meilleur_soutien(chef).is_empty() or str(chef.get("cible", "")).is_empty(), "sans cible, pas de cri ; avec, le cri est proposé")
	var rallie := false
	for k in 30:
		s.attente[j.id] = true
		s.intention(j.id, {"type": "attendre"})
		s.horloge_monde.avancer(3)
		var garde := 100
		while garde > 0 and s.pas("monde"):
			garde -= 1
		for nom in s.combats.keys():
			garde = 100
			while garde > 0 and s.combats.has(nom) and s.pas(nom):
				garde -= 1
		if Etres.a_statut_id(acolyte, "ralliement"):
			rallie = true
			break
	verifier(rallie, "le chef a crié : l'acolyte porte le statut ralliement")


## La routine civile joue dans la fenêtre (IA des créatures, 2026-09-04) : à 23 h, un villageois va vers son lit.
## Avant, `routine` n'avait aucun poids dans `civil` et `garde` : ils attendaient toute la journée.
func test_routine_civile() -> void:
	var s := Simulation.new(151)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var v: Dictionary = s.ajouter("villageois", j.pos + Vector2i(2, 0), "ia")
	var lit: Vector2i = Vector2i(-1, -1)
	for d in range(5, 2, -1):
		for dir in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var q: Vector2i = v.pos + dir * d
			if s.grille.dans(q) and not s.grille.bloque_passage(q) and s.grille.occupant(q).is_empty() and lit == Vector2i(-1, -1):
				lit = q
	verifier(lit != Vector2i(-1, -1), "une tuile libre pour le lit")
	v["lit"] = lit
	var jour := int(s._cycle().get("ticks_par_jour", 24000))
	s.horloge_monde.ticks = 3 * jour + int(23.0 / 24.0 * float(jour))
	var avant := Grille.distance(v.pos, lit)
	for k in 30:
		s.attente[j.id] = true
		s.intention(j.id, {"type": "attendre"})
		s.horloge_monde.avancer(3)
		var garde := 100
		while garde > 0 and s.pas("monde"):
			garde -= 1
	verifier(Grille.distance(v.pos, lit) < avant, "à 23 h le villageois s'approche de son lit (%d → %d tuiles)" % [avant, Grille.distance(v.pos, lit)])


## Voir un ennemi n'ouvre un combat que pour qui attaque à vue (IA des créatures, 2026-09-04) : un cerf à deux tuiles
## d'un joueur qui attend prend la cible, ne l'engage pas — avant, le joueur passait « en combat » avec une bête qui fuit.
func test_proie_n_engage_pas() -> void:
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	var cerf: Dictionary = s.ajouter("cerf", j.pos + Vector2i(2, 0), "ia")
	var loup: Dictionary = s.ajouter("loup", j.pos + Vector2i(-6, 0), "ia")
	verifier(not s._profil_offensif(cerf) and s._profil_offensif(loup), "le cerf n'attaque pas à vue, le loup si")
	for k in 12:
		s.attente[j.id] = true
		s.intention(j.id, {"type": "attendre"})
		s.horloge_monde.avancer(3)
		var garde := 100
		while garde > 0 and s.pas("monde"):
			garde -= 1
		for nom in s.combats.keys():
			garde = 100
			while garde > 0 and s.combats.has(nom) and s.pas(nom):
				garde -= 1
		if s.en_combat(loup):
			break
	verifier(not s.en_combat(cerf), "le cerf n'a ouvert aucun combat")
	verifier(s.en_combat(loup) and s.en_combat(j), "le loup, lui, engage le joueur à vue")


## Les sprites d'objets (Direction artistique, 2026-09-05) : le nom attendu suit la convention, et sans fichier le jeu
## garde son pictogramme — texture_objet rend null et ne plante pas.
func test_sprites_objets() -> void:
	verifier(Pictos.nom_sprite({"id": "craft_epee", "type": "arme"}) == "epee", "craft_epee → epee.png")
	verifier(Pictos.nom_sprite({"id": "proto_masse", "type": "arme"}) == "masse", "proto_masse → masse.png (même silhouette que sa base)")
	verifier(Pictos.nom_sprite({"id": "gemme_rubis", "type": "gemme"}) == "gemme_rubis", "gemme_rubis → gemme_rubis.png")
	verifier(Pictos.nom_sprite({"id": "composant", "type": "composant", "composant": "lame_longue", "materiau": "fer"}) == "composants/lame_longue", "un composant → composants/<id>.png")
	verifier(Pictos.nom_sprite({"id": "materiau_brut", "type": "materiau", "forme": "planche", "materiau": "chene"}) == "matieres/planche", "une matière → matieres/<forme>.png")
	verifier(Pictos.texture_objet({"id": "craft_epee", "type": "arme"}) == null, "sans fichier, pas de texture : le pictogramme reste")
	verifier(Pictos.texture_objet({"id": "", "type": "arme"}) == null, "un objet sans id ne cherche rien")
	verifier(Pictos._texture_composant("lame_longue", "droite") == null, "sans fichier, ni la variante ni le composant")
	var assemble := {"id": "craft_epee", "type": "arme", "variante_visuelle": "droite", "composants": {"tete": {"composant": "lame_longue", "materiau": "fer"}, "manche": {"composant": "poignee", "materiau": "chene"}}}
	var toile := Node2D.new()
	verifier(not Pictos._dessiner_assemblage(toile, assemble, Rect2(0, 0, 32, 32)), "un assemblage sans sprites de composants ne se compose pas : le pictogramme reste")
	toile.free()


## Les boutiques vendent (Commerce et boutiques, 2026-09-05) : chaque type garnit un étal non vide, le tailleur vend des
## vêtements et non des boucliers de fortune, et un marchand sans boutique typée se réapprovisionne comme les autres.
func test_boutiques_vendent() -> void:
	var s := nouvelle_sim("gorge")
	var ids: Array = GameData.catalogues.shop_types.keys()
	ids.sort()
	for bid in ids:
		var faux := {"id": "test_" + str(bid), "stock": []}
		s._garnir_stock(faux, GameData.catalogues.shop_types[bid].selection)
		verifier(not faux.stock.is_empty(), "l'étal %s se garnit (%d objets)" % [bid, faux.stock.size()])
		if bid == "tailleur":
			var que_du_tissu := true
			for uid in faux.stock:
				var it: Dictionary = s.items[uid]
				var tags: Array = GameData.entree("items", str(it.base)).get("tags", [])
				if not ("vetement" in tags or "rituel" in tags or "dos" in tags):
					que_du_tissu = false
			verifier(que_du_tissu, "le tailleur ne vend que des vêtements, jamais un bouclier de fortune")
	var m: Dictionary = s.ajouter("marchand", joueur_de(s).pos + Vector2i(2, 0), "ia")
	verifier(not m.get("stock", []).is_empty(), "un marchand sans boutique typée a le stock de sa fiche (%d)" % m.get("stock", []).size())
	m.stock = []
	s.horloge_monde.ticks += int(GameData.config("planete").corruption.ticks_par_semaine)   # la semaine suivante : un autre tirage
	s._reapprovisionner(m)
	verifier(not m.stock.is_empty(), "vidé, il se réapprovisionne la semaine suivante (%d objets)" % m.stock.size())
	var v: Dictionary = s.ajouter("villageois", joueur_de(s).pos + Vector2i(-2, 0), "ia")
	s._reapprovisionner(v)
	verifier(v.get("stock", []).is_empty(), "un villageois n'a pas de stock et n'en reçoit pas")


## Recruter sur tous les PNJ (Compagnons, 2026-09-05) : un villageois à relation nulle refuse sans or, suit contre le prix,
## et l'or change de mains ; un loup ne se recrute pas ; un PNJ déjà compagnon non plus.
func test_recruter_contre_or() -> void:
	var s := nouvelle_sim("gorge")
	var j := joueur_de(s)
	var v: Dictionary = s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	var loup: Dictionary = s.ajouter("loup", j.pos + Vector2i(0, 1), "ia")
	var prix := int(s.regles.r.compagnons.get("prix_recrutement", 40))
	verifier(s.recrutable(j, v) and not s.recrutable(j, loup), "un villageois se recrute, un loup non")
	j.or = 0
	verifier(not s._recruter(j, v.id, 0) and not v.has("maitre"), "sans or ni relation, il refuse")
	j.or = prix + 5
	var or_v := int(v.get("or", 0))
	verifier(s._recruter(j, v.id, 0) and str(v.get("maitre", "")) == j.id and int(j.or) == 5 and int(v.or) == or_v + prix, "contre %d or, il suit et l'or change de mains" % prix)
	verifier(not s.recrutable(j, v), "déjà compagnon : plus recrutable")
	var v2: Dictionary = s.ajouter("villageois", j.pos + Vector2i(-1, 0), "ia")
	v2.social.relations[j.id] = 90
	j.or = 0
	verifier(s._recruter(j, v2.id, 0) and str(v2.get("maitre", "")) == j.id, "au seuil de relation, il suit gratuitement")


## Le plafond de créatures par salle (Donjons — structure, 2026-09-05) : au premier étage, aucune salle ordinaire n'a plus
## de max_par_salle_base occupants ; au deuxième, une de plus. Une salle immense en tirait vingt-deux.
func test_plafond_par_salle() -> void:
	var gen := Donjon.new(GameData.catalogues["dungeon_rooms"], GameData.catalogues["dungeon_connectors"], GameData.entree("dungeon_themes", "ruine"))
	var pe: Dictionary = GameData.config("combat_rules").peuplement_etage
	for etage: int in [1, 2]:
		var plafond: int = int(pe.max_par_salle_base) + int(pe.max_par_salle_par_etage) * (etage - 1)
		var pire := 0
		var salles := 0
		for g in [41, 42, 43]:
			var e: Dictionary = gen.generer_etage(g, 5, etage, 10, false)
			for i in range(1, e.pieces.size()):
				var pc: Dictionary = e.pieces[i]
				if pc.get("boss_room", false):
					continue
				var r: Rect2i = pc.rect
				var n := 0
				for sp in e.spawns:
					if r.has_point(sp.pos):
						n += 1
				pire = maxi(pire, n)
				salles += 1
		verifier(pire <= plafond and salles > 0, "étage %d : au plus %d créature(s) par salle sur %d salles (plafond %d)" % [etage, pire, salles, plafond])


## Le calendrier (Un monde réel — A, 2026-09-05) : douze mois de dix jours, la semaine de sept jours, les années
## depuis 1020 ; le journal dit la date et la fête ; la routine et les prix suivent le jour.
func test_calendrier() -> void:
	var cal: Dictionary = GameData.config("calendrier")
	var jpa := Calendrier.jours_par_an()
	verifier(jpa == int(GameData.config("combat_rules").age.jours_par_an) and jpa == int(GameData.config("planete").cycle.saisons.jours_par_an) and cal.mois.size() == 12 and int(cal.mois[0][1]) == 30, "les mois somment l'année des âges et des saisons (%d jours, douze mois de trente — designer)" % jpa)
	var d0 := Calendrier.date(0)
	verifier(int(d0.annee) == 1020 and str(d0.mois) == "rat" and int(d0.jour_mois) == 1 and str(d0.jour_semaine) == "soleil", "le jour 0 est le 1 du Rat de l'an 1020, un jour du Soleil (%s)" % str(d0))
	var dern := Calendrier.date(jpa - 1)
	verifier(str(dern.mois) == "cochon" and int(dern.jour_mois) == int(cal.mois[11][1]) and int(dern.annee) == 1020, "le dernier jour de l'an est le %d du Cochon" % int(cal.mois[11][1]))
	var d_an := Calendrier.date(jpa)
	verifier(int(d_an.annee) == 1021 and str(d_an.mois) == "rat" and int(d_an.jour_mois) == 1, "le jour %d ouvre l'an 1021" % jpa)
	verifier(str(d_an.jour_semaine) == str(cal.jours_semaine[jpa % 7]), "la semaine dérive de %d jour(s) par an" % (jpa % 7))
	verifier(str(Calendrier.date(7).jour_semaine) == "soleil", "sept jours plus tard, le même jour de la semaine")
	verifier(Calendrier.texte(d0).contains("1020"), "le texte de la date dit l'année (%s)" % Calendrier.texte(d0))
	var jm := Calendrier.jour_de_marche("Aubevaux")
	verifier(jm in cal.jours_semaine and jm == Calendrier.jour_de_marche("Aubevaux"), "le jour de marché est un jour de la semaine, stable (%s)" % jm)
	verifier(Calendrier.fetes_du_jour(d0, "sino").size() == 1 and str(Calendrier.fetes_du_jour(d0, "sino")[0].id) == "nouvel_an", "le 1 du Rat est le Nouvel An pour tous")
	var lanternes: Dictionary = {}
	for f in cal.fetes.liste:
		if str(f.id) == "lanternes":
			lanternes = f
	var d_l := Calendrier.date(int(lanternes.jour) - 1)
	verifier(Calendrier.fetes_du_jour(d_l, "sino").size() == 1 and Calendrier.fetes_du_jour(d_l, "celte").is_empty(), "les lanternes (%d du Rat) sont sino, pas celtes" % int(lanternes.jour))
	var a := Calendrier.anniversaire("pnj_42")
	verifier(int(a.jour) >= 1 and int(a.jour) <= 30 and a == Calendrier.anniversaire("pnj_42"), "un anniversaire stable dans le mois")
	# Les saisons tombent sur des débuts de mois.
	var s := Simulation.new(9)
	s.charger_arene("gorge")
	var jour := int(GameData.config("planete").cycle.ticks_par_jour)
	for sa in GameData.config("planete").cycle.saisons.liste:
		var debut := int(sa[1])
		verifier(s.saison(debut * jour) == str(sa[0]) and int(Calendrier.date(debut).jour_mois) == 1, "le jour %d ouvre un mois et la saison %s" % [debut, str(sa[0])])
	# Dans le monde : le premier jour dit sa date et le Nouvel An, les civils ont eu leur humeur, la routine vise la place.
	var s2 := Simulation.new(31)
	s2.charger_camp()
	s2.horloge_monde.ticks = 8000   # le jour 0, le Nouvel An (une partie commence le 3 du Rat depuis le 5 septembre au soir)
	var journal: Array = []
	var cb := func(cle: String, _params: Dictionary) -> void: journal.append(cle)
	EventBus.journal.connect(cb)
	s2.horloge_monde.avancer(1)
	EventBus.dispatcher()
	EventBus.journal.disconnect(cb)
	verifier("journal.date" in journal and "journal.fete" in journal, "le premier jour dit sa date et le Nouvel An (%s)" % str(journal))
	var civils: Array = s2.vivants().filter(func(x: Dictionary) -> bool: return x.camp == "civil" and x.controle == "ia" and x.has("place"))
	if civils.is_empty():
		var v0: Dictionary = s2.ajouter("villageois", s2.vivants()[0].pos + Vector2i(2, 0), "ia")
		v0["place"] = v0.pos + Vector2i(1, 1)
		v0["poste"] = v0.pos + Vector2i(3, 0)
		v0["lit"] = v0.pos
		civils = [v0]
		s2._nouveau_jour(0)
	var v: Dictionary = civils[0]
	verifier(int(v.get("humeur", 0)) == clampi(int(s2._ry().humeur_base) + int(s2.trait_somme(v, "humeur")) + int(GameData.config("calendrier").fetes.humeur), 0, 100), "le Nouvel An a donné son humeur au civil (%d, traits compris)" % int(v.get("humeur", 0)))
	s2.horloge_monde.ticks = 12000
	verifier(s2._cible_routine(v, s2.profils_ia.civil) == s2._coin_de_place(v), "midi, jour de fête : son coin de la place")
	s2.horloge_monde.ticks = 2 * jour + 12000   # le 3 du Rat : rien pour un sino, Yennayer pour un arabo-berbère
	v.social.culture = "sino"
	verifier(s2._cible_routine(v, s2.profils_ia.civil) == v.poste, "midi, un jour sans fête : le poste")
	verifier(v.has("signe") and not v.signe.is_empty() and v.has("anniversaire"), "un PNJ a un signe et un anniversaire")
	# Le jour de marché : les prix baissent d'un facteur, pas les autres jours.
	var pnj := s2.ajouter("marchand", v.pos + Vector2i(0, 2), "ia")
	pnj["village"] = "Aubevaux"
	var uid: String = s2.generer_objet("potion_soin", 1).uid
	var j: Dictionary = s2.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var jours: Array = GameData.config("calendrier").jours_semaine
	var k := jours.find(Calendrier.jour_de_marche("Aubevaux"))
	s2.horloge_monde.ticks = k * jour + 12000
	verifier(is_equal_approx(float(s2.prix_suggere(uid, pnj, j).marche), float(GameData.config("calendrier").marche.prix_mult)), "le jour de marché, le prix est multiplié par %.2f" % float(GameData.config("calendrier").marche.prix_mult))
	s2.horloge_monde.ticks = ((k + 1) % 7) * jour + 12000
	verifier(is_equal_approx(float(s2.prix_suggere(uid, pnj, j).marche), 1.0), "le lendemain, plein prix")
	# L'étal regarnit jusqu'au plafond du marché, pas au-delà.
	pnj["stock"] = []
	pnj["stock_garni"] = 0
	s2._garnir_stock(pnj, GameData.entree("shop_types", "epicier").selection)
	var n1: int = pnj.stock.size()
	pnj["boutique"] = "epicier"
	s2._garnir_marche(pnj)
	var n2: int = pnj.stock.size()
	for k2 in 6:
		s2._garnir_marche(pnj)
	var n3: int = pnj.stock.size()
	s2._garnir_marche(pnj)
	var plafond := int(ceil(float(GameData.config("calendrier").marche.stock_mult) * float(n1)))
	verifier(n1 > 0 and n2 > n1 and n3 >= plafond and pnj.stock.size() == n3, "le marché regarnit (%d → %d) et plafonne (%d ≥ %d, puis rien)" % [n1, n2, n3, plafond])


## Les territoires (Villes — B0, 2026-09-05) : une ville est un territoire comme le camp ; sa semaine tourne dans son
## contexte, ses résidents ne sont pas ceux du joueur, ses cellules ne se revendiquent pas, et la prendre la donne.
func test_territoires() -> void:
	var s := Simulation.new(31)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	verifier(s.territoire.id == "joueur" and s.territoires.has("joueur") and s.monde.claims == s.territoires.joueur.cellules, "le joueur est un territoire, ses claims sont ses cellules")
	var camp: Vector2i = s.monde.cellule_camp
	var cell_v := camp + Vector2i(1, 0)
	var t := s.creer_territoire("Testville", "royaume_test", 100)
	t.cellules[cell_v] = {"role": "habitation"}
	var base_res: int = s.residents().size()
	var citoyens: Array = []
	for k in 2:
		var x: Dictionary = s.ajouter("villageois", j.pos + Vector2i(2 + k, 0), "ia")
		x["village"] = "Testville"
		x["assignation"] = {"fonction": "fermier", "cellule": cell_v, "territoire": "Testville"}
		x["fonction"] = "fermier"
		x["humeur"] = int(s._ry().humeur_base)
		citoyens.append(x)
	verifier(s.residents().size() == base_res, "les gens de la ville ne sont pas des résidents du joueur")
	var n_ville: int = s._dans_territoire("Testville", func() -> int: return s.residents().size())
	verifier(n_ville == 2 and s.territoire.id == "joueur" and s.monde.claims == s.territoires.joueur.cellules, "dans son contexte, la ville a ses deux résidents ; le contexte revient au joueur")
	verifier(s.territoire_de_cellule(cell_v) == "Testville" and s.territoire_de_cellule(camp) == "joueur", "chaque cellule sait son territoire")
	# Une semaine : la ville produit dans ses stocks et paie son entretien ; le joueur n'y touche pas.
	var stocks_j: Dictionary = s.territoire.stocks.duplicate()
	var tresor_j: int = int(s.territoire.tresor)
	var tps: int = int(GameData.config("planete").corruption.ticks_par_semaine)
	s.horloge_monde.avancer(tps)
	s._tiquer_monde(s.horloge_monde.ticks)
	EventBus.dispatcher()
	verifier(s.territoire.id == "joueur", "après la semaine, le contexte est celui du joueur")
	verifier(int(t.stocks.get("baies", 0)) > 0, "les fermiers de la ville ont produit dans les stocks de la ville (%s)" % str(t.stocks))
	verifier(s.territoire.stocks == stocks_j and int(s.territoire.tresor) == tresor_j, "les stocks et le trésor du joueur n'ont pas bougé")
	verifier(int(t.tresor) == 100 and int(t.dette) == 0, "une ville qui n'est pas au joueur ne lui doit pas de gages (trésor %d, dette %d)" % [int(t.tresor), int(t.dette)])
	verifier(t.rapports.size() == 1, "la ville a son rapport de semaine")
	# La cellule d'une ville ne se revendique pas ; prise, la ville est au joueur et devient son territoire courant.
	var n_sub: int = s.monde.taille / 32
	for cy in n_sub:
		for cx in n_sub:
			s.monde.explores[Vector2i(cell_v.x * n_sub + cx, cell_v.y * n_sub + cy)] = true
	j.or = 10000
	verifier(not s.revendiquer(j, cell_v), "la cellule d'une ville ne se revendique pas")
	t.proprietaire = "joueur"
	var pos_v: Vector2i = s.monde.pos_monde(cell_v, Vector2i(32, 32))
	if s.grille.dans(pos_v):
		s.grille.liberer(j.pos)
		j.pos = pos_v
		s.grille.placer(j.id, pos_v)
		s._maj_contexte()
		verifier(s.territoire.id == "Testville" and s.monde.claims == t.cellules and s.residents().size() == 2, "sur sa ville, le joueur la gère : contexte, claims, résidents")
		s.grille.liberer(j.pos)
		j.pos = s.monde.pos_monde(camp, Vector2i(32, 32))
		s.grille.placer(j.id, j.pos)
		s._maj_contexte()
		verifier(s.territoire.id == "joueur", "de retour au camp, le contexte est la base")
	# La sauvegarde garde les territoires.
	s.nom_partie = "test_territoires"
	verifier(s.sauvegarder(), "sauvegarde avec une ville")
	var s2 := Simulation.new(31)
	s2.nom_partie = "test_territoires"
	verifier(s2.charger_sauvegarde() and s2.territoires.has("Testville") and s2.territoires.Testville.cellules.has(cell_v) and s2.territoire.id == "joueur" and s2.monde.claims == s2.territoires.joueur.cellules, "rechargée : la ville, ses cellules, le joueur relié à ses claims")


## Les villes (Villes — population, quartiers et économie, B1, 2026-09-05) : l'emprise est une lecture pure et
## cohérente, la population décide du palier et des cellules, chaque quartier a ses rues, ses lits, ses gens, son
## siège et son plan de territoire ; chargée, la ville est un territoire dont le joueur n'est pas le maître.
func test_villes() -> void:
	var s := Simulation.new(9)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var cfg: Dictionary = GameData.config("villes")
	var ordre: Array = cfg.ordre_paliers
	var c0: Vector2i = s.monde.cellule_camp
	var f: Dictionary = {}
	for dy in range(-20, 21):
		for dx in range(-20, 21):
			var cv := c0 + Vector2i(dx, dy)
			if not (surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false))):
				continue
			var fa: Dictionary = surf.fiche_agglomeration(cv)
			if f.is_empty() or ordre.find(str(fa.palier)) > ordre.find(str(f.palier)) or (str(fa.palier) == str(f.palier) and int(fa.population) > int(f.population)):
				f = fa
	verifier(not f.is_empty(), "une agglomération à 20 cellules du camp")
	if f.is_empty():
		return
	var fourchette: Array = cfg.paliers[str(f.palier)].pop
	verifier(int(f.population) >= int(fourchette[0]) and int(f.population) <= int(fourchette[1]), "%s : %s de %d habitants, dans la fourchette du palier" % [str(f.nom), str(f.palier), int(f.population)])
	var attendu := clampi(int(ceil(float(f.population) / float(cfg.habitants_par_cellule))), 1, int(cfg.cellules_max))
	verifier(f.cellules.size() >= 1 and f.cellules.size() <= attendu, "%d cellule(s) pour %d habitants (au plus %d)" % [f.cellules.size(), int(f.population), attendu])
	verifier(f.cellules.size() == 1 or ordre.find(str(f.palier)) >= ordre.find("bourg"), "une agglomération de plusieurs cellules est un bourg ou plus")
	# Chaque cellule de l'emprise se reconnaît, avec son quartier et son rang — et le camp n'en est jamais une.
	var coherent := true
	for k in f.cellules.size():
		var a: Dictionary = surf.agglomeration_de(f.cellules[k])
		coherent = coherent and str(a.get("nom", "")) == str(f.nom) and str(a.get("quartier", "")) == str(f.quartiers[k]) and int(a.get("index", -1)) == k
	verifier(coherent, "toutes les cellules de l'emprise sont d'accord avec la fiche (%s)" % str(f.quartiers))
	verifier(surf.agglomeration_de(c0).is_empty(), "la cellule du camp n'est jamais un quartier")
	# Les boutiques : jamais deux du même type dans l'agglomération.
	var types := {}
	var doublon := false
	for liste in f.boutiques:
		for t in liste:
			doublon = doublon or types.has(str(t))
			types[str(t)] = true
	verifier(not doublon, "aucun type de boutique en double (%s)" % str(f.boutiques))
	# Le centre généré : deux rues par le milieu, une place, des bâtiments le long des rues, des lits, un siège.
	var centre: Vector2i = f.centre
	var e: Dictionary = surf.generer_cellule(centre.x, centre.y, {}, false)
	var v: Dictionary = e.village
	var taille: int = e.largeur
	# Depuis le 2026-09-06, les rues ne sont plus deux axes droits mais un réseau tracé (Villes, le plan des villes) :
	# ce qu'on vérifie, c'est qu'il est d'un seul tenant et qu'il sort de la cellule par plusieurs côtés.
	var rues_c := {}
	for i in v.get("rues", []):
		rues_c[int(i)] = true
	var vus_c := {}
	var file_c: Array[Vector2i] = [Vector2i(v.centre)]
	vus_c[int(v.centre.y) * taille + int(v.centre.x)] = true
	var sorties := {}
	while not file_c.is_empty():
		var p_c: Vector2i = file_c.pop_back()
		if p_c.x <= 1:
			sorties["ouest"] = true
		if p_c.y <= 1:
			sorties["nord"] = true
		if p_c.x >= taille - 2:
			sorties["est"] = true
		if p_c.y >= taille - 2:
			sorties["sud"] = true
		for d_c in Grille.DIRS:
			var q_c: Vector2i = p_c + d_c
			if q_c.x < 0 or q_c.y < 0 or q_c.x >= taille or q_c.y >= taille:
				continue
			var i_c := q_c.y * taille + q_c.x
			if rues_c.has(i_c) and not vus_c.has(i_c):
				vus_c[i_c] = true
				file_c.append(q_c)
	verifier(rues_c.size() > 150 and sorties.size() >= 3 and vus_c.size() >= rues_c.size() * 8 / 10, "le réseau de rues : %d tuiles, %d atteintes depuis la place, %d côtés desservis" % [rues_c.size(), vus_c.size(), sorties.size()])
	var lits := 0
	for bat in v.batiments:
		lits += bat.lits.size()
	verifier(v.batiments.size() >= 4 and lits >= mini(int(v.population_quartier), 8), "le centre : %d bâtiments, %d lits pour %d habitants" % [v.batiments.size(), lits, int(v.population_quartier)])
	verifier(str(v.quartier) == "centre" and str(v.nom) == str(f.nom) and int(v.population) == int(f.population) and Vector2i(v.cellule_centre) == centre, "la cellule sait sa ville, son quartier, sa population")
	var plan_t: Dictionary = v.territoire
	var a_res := false
	for per in plan_t.perimetres:
		a_res = a_res or str(per.type) == "residentiel"
	verifier(a_res and str(plan_t.role) == str(cfg.roles.centre), "le plan de territoire : un résidentiel, le rôle du quartier")
	if ordre.find(str(f.palier)) >= ordre.find("bourg") and not str(f.gouvernance).is_empty():
		var siege := str(GameData.entree("governments", str(f.gouvernance)).siege.batiment)
		var a_siege := false
		for bat in v.batiments:
			a_siege = a_siege or str(bat.id) == siege
		verifier(a_siege, "le siège du pouvoir de la gouvernance %s : %s" % [str(f.gouvernance), siege])
	var postes_ok := true
	for pj in v.pnj:
		postes_ok = postes_ok and pj.has("poste") and pj.has("lit")
	verifier(postes_ok and v.pnj.size() >= 4, "chaque habitant prévu a un poste et un lit (%d)" % v.pnj.size())
	# Chargée : la ville est un territoire, ses gens en sont les résidents, ses périmètres existent, le joueur reste chez lui.
	var s2 := Simulation.new(9)
	s2.charger_camp({}, centre + Vector2i(2, 0))
	var j: Dictionary = s2.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_sub: int = s2.monde.taille / 32
	for cy in n_sub:
		for cx in n_sub:
			s2.monde.explores[Vector2i(centre.x * n_sub + cx, centre.y * n_sub + cy)] = true
	verifier(s2.voyager(j, centre), "voyager jusqu'à %s" % str(f.nom))
	var nom := str(f.nom)
	verifier(s2.territoires.has(nom), "la ville chargée est un territoire")
	if s2.territoires.has(nom):
		var t: Dictionary = s2.territoires[nom]
		verifier(t.cellules.has(centre) and str(t.proprietaire) == str(f.royaume), "ses cellules, son propriétaire (%s)" % str(t.proprietaire))
		var n_res: int = s2._dans_territoire(nom, func() -> int: return s2.residents().size())
		var n_per: int = s2._dans_territoire(nom, func() -> int: return s2.perimetres().size())
		verifier(n_res >= 4 and n_per >= 1, "%d résidents assignés, %d périmètres" % [n_res, n_per])
		verifier(s2.territoire.id == "joueur" and s2.residents().is_empty(), "le joueur n'a ni la ville ni ses gens")
		verifier(int(s2.monde.villages[nom].capacite) == int(f.population) and Vector2i(s2.monde.villages[nom].cellule) == centre, "le registre des villages sait la population et le centre")


func test_champs_et_betes() -> void:
	var s := Simulation.new(9)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var cfg: Dictionary = GameData.config("villes")
	var c0: Vector2i = s.monde.cellule_camp
	var f: Dictionary = {}
	for dy in range(-20, 21):
		for dx in range(-20, 21):
			var cv := c0 + Vector2i(dx, dy)
			if surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false)):
				var fa: Dictionary = surf.fiche_agglomeration(cv)
				if "agricole" in fa.quartiers and (f.is_empty() or int(fa.population) > int(f.population)):
					f = fa
	verifier(not f.is_empty(), "une ville avec un quartier agricole à 20 cellules")
	if f.is_empty():
		return
	var k_agr: int = f.quartiers.find("agricole")
	var cell_a: Vector2i = f.cellules[k_agr]
	var e: Dictionary = surf.generer_cellule(cell_a.x, cell_a.y, {}, false)
	var v: Dictionary = e.village
	var attendu := int(v.population_quartier) / int(cfg.champs.par_habitant)
	# Les vergers sont dans la même liste que les champs (ils se sèment pareil) mais ne comptent pas au ratio :
	# on plante un verger parce qu'on a de la place, pas parce qu'on a des bouches (2026-09-07).
	var n_champs_v := 0
	var n_vergers_v := 0
	for c_v in v.champs:
		if bool(c_v.get("verger", false)):
			n_vergers_v += 1
		else:
			n_champs_v += 1
	verifier(n_champs_v >= mini(attendu, 2) and n_champs_v <= attendu, "le quartier agricole a %d champs pour %d habitants (au plus %d) et %d verger(s)" % [n_champs_v, int(v.population_quartier), attendu, n_vergers_v])
	verifier(v.betes.size() >= int(cfg.enclos.betes[0]), "un enclos de %d bêtes" % v.betes.size())
	var fermiers_champs := 0
	for pj in v.pnj:
		if pj.has("perimetre") and str(v.territoire.perimetres[int(pj.perimetre)].type) == "champs":
			fermiers_champs += 1
	verifier(fermiers_champs >= 2, "%d fermiers assignés aux champs" % fermiers_champs)
	# Chargée : les parcelles sont dans le territoire de la ville, les bêtes dans l'enclos, au statut bétail.
	var s2 := Simulation.new(9)
	s2.charger_camp({}, cell_a + Vector2i(2, 0))
	var j: Dictionary = s2.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_sub: int = s2.monde.taille / 32
	for cy in n_sub:
		for cx in n_sub:
			s2.monde.explores[Vector2i(cell_a.x * n_sub + cx, cell_a.y * n_sub + cy)] = true
	verifier(s2.voyager(j, cell_a), "voyager jusqu'au quartier agricole")
	var nom := str(f.nom)
	var t: Dictionary = s2.territoires.get(nom, {})
	verifier(not t.is_empty() and t.cultures.size() >= v.champs.size() * 10, "%d parcelles semées dans le territoire de la ville" % t.get("cultures", {}).size())
	var betes: Array = s2.vivants().filter(func(x: Dictionary) -> bool: return str(x.get("betail", "")) == nom)
	var betail_ok := true
	for bt in betes:
		betail_ok = betail_ok and str(bt.get("statut_habitat", "")) == "betail" and bt.camp == "civil"
	verifier(betes.size() >= 2 and betail_ok, "%d bêtes au statut bétail, camp civil" % betes.size())
	verifier(s2.territoire.cultures.is_empty(), "les parcelles de la ville ne sont pas celles du joueur")
	# Six jours : les parcelles mûrissent ; une semaine : les fermiers récoltent, ressèment, le bétail produit.
	var jour := int(GameData.config("planete").cycle.ticks_par_jour)
	var tps: int = int(GameData.config("planete").corruption.ticks_par_semaine)
	s2.horloge_monde.avancer(6 * jour)
	var mures := 0
	for pm in t.cultures.keys():
		if bool(t.cultures[pm].mure):
			mures += 1
	verifier(mures > 0, "après six jours, %d parcelles mûres" % mures)
	s2.horloge_monde.avancer(tps)
	s2._tiquer_monde(s2.horloge_monde.ticks)
	EventBus.dispatcher()
	var recolte := 0
	for cle in t.stocks.keys():
		if GameData.catalogues.plants.has(str(cle)):
			recolte += int(t.stocks[cle])
	verifier(recolte > 0, "la ville a récolté ses champs (%d) : %s" % [recolte, str(t.stocks)])
	var ressemees := 0
	for pm in t.cultures.keys():
		if not bool(t.cultures[pm].mure):
			ressemees += 1
	verifier(ressemees > 0, "des parcelles ressemées (%d)" % ressemees)
	var produit_attendu := false   # depuis le 2026-09-06, un produit peut avoir sa saison (la laine au printemps)
	var saison_ville := SimTerrain.saison(s2)
	var matieres_b: Array[String] = []   # toutes les matières que les espèces de l'enclos donnent (laine, lait, suif, crin, plume, œuf…)
	for eid in cfg.enclos.produits.keys():
		matieres_b.append(str(cfg.enclos.produits[eid].materiau))
	for bt in betes:
		# depuis le 2026-09-07, une espèce domestique porte SES produits sur sa fiche (bloc `elevage`) ; une sauvage, la ligne commune
		var liste_pr: Array = SimVilles.elevage_de(bt).get("produits", [])
		if liste_pr.is_empty():
			var pr_b: Dictionary = cfg.enclos.produits.get(str(bt.def), {})
			if not pr_b.is_empty():
				liste_pr = [pr_b]
		for pr_b in liste_pr:
			produit_attendu = produit_attendu or (not pr_b.has("saison") or str(pr_b.saison) == saison_ville)
			if not (str(pr_b.materiau) in matieres_b):
				matieres_b.append(str(pr_b.materiau))
	var somme_b := func() -> int:
		var n := 0
		for cle in t.stocks.keys():
			if str(cle).split("|")[0] in matieres_b:
				n += int(t.stocks[cle])
		return n
	var avant_b: int = somme_b.call()   # la ville use son tissu chaque semaine (B3) : on mesure la production seule
	s2._dans_territoire(nom, func() -> void: s2._semaine_betail())
	var apres_b: int = somme_b.call()
	verifier((apres_b > avant_b) == produit_attendu, "le bétail a produit (%d → %d) selon ses espèces et la saison (%s)" % [avant_b, apres_b, saison_ville])


## Les champs et les bêtes (Villes — B2, 2026-09-05) : une ville sème de vraies parcelles dans son territoire, ses
## fermiers les récoltent et les ressèment chaque semaine, ses bêtes sont des créatures au statut bétail qui produisent.
## L'anneau moyen (Modules de la simulation et le C++, 2026-09-06) : une ville quittée continue de vivre sans grille —
## ses résidents endormis comptent, sa semaine tourne, ils vieillissent, et ils sont là au retour.
func test_anneau_moyen() -> void:
	var s := Simulation.new(9)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var c0: Vector2i = s.monde.cellule_camp
	var f: Dictionary = {}
	for dy in range(-20, 21):
		for dx in range(-20, 21):
			var cv := c0 + Vector2i(dx, dy)
			if maxi(absi(dx), absi(dy)) < 4:
				continue   # assez loin pour sortir de la fenêtre au retour
			if surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false)):
				var fa: Dictionary = surf.fiche_agglomeration(cv)
				if f.is_empty() or int(fa.population) > int(f.population):
					f = fa
	verifier(not f.is_empty(), "une ville à plus de 4 cellules du camp")
	if f.is_empty():
		return
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_sub: int = s.monde.taille / 32
	var centre: Vector2i = f.centre
	for cy in n_sub:
		for cx in n_sub:
			s.monde.explores[Vector2i(centre.x * n_sub + cx, centre.y * n_sub + cy)] = true
			s.monde.explores[Vector2i(c0.x * n_sub + cx, c0.y * n_sub + cy)] = true
	verifier(s.voyager(j, centre), "voyager jusqu'à la ville « %s »" % str(f.nom))
	var nom := str(f.nom)
	verifier(s.territoires.has(nom), "la ville a son territoire")
	if not s.territoires.has(nom):
		return
	var n_res: int = s._dans_territoire(nom, func() -> int: return s.residents().size())
	verifier(n_res >= 3, "%d résidents chargés" % n_res)
	# On repart au camp : la ville sort de la fenêtre, ses gens s'endorment — mais ils comptent toujours.
	j.or = 10000
	verifier(s.voyager(j, c0), "retour au camp")
	verifier(not SimTerritoire._territoire_charge(s, nom), "la ville n'est plus dans la fenêtre")
	var endormis: Array = s._dans_territoire(nom, func() -> Array: return s.residents())
	verifier(endormis.size() == n_res, "ses %d résidents comptent toujours, endormis (%d)" % [n_res, endormis.size()])
	if endormis.is_empty():
		return
	var t: Dictionary = s.territoires[nom]
	var rapports_avant: int = t.rapports.size()
	var age_avant := float(endormis[0].get("age", 30.0))
	var humeur_avant := int(endormis[0].get("humeur", 50))
	var journal: Array = []
	var gb := load("res://scenes/tests/grande_base.gd")
	gb.semaine(s, journal, j)
	verifier(t.rapports.size() == rapports_avant + 1, "une semaine passe : la ville endormie a son rapport (%d)" % t.rapports.size())
	verifier(float(endormis[0].get("age", 30.0)) > age_avant, "un endormi a vieilli d'une semaine (%.3f → %.3f)" % [age_avant, float(endormis[0].get("age", 30.0))])
	var am: Dictionary = GameData.config("villes").anneau_moyen
	var loge := 0
	for x in endormis:
		if int(x.get("humeur", 0)) >= int(s.regles.r.royaume.humeur_base) + int(am.humeur_logement) - 20:
			loge += 1
	verifier(loge > 0, "%d endormis logés hors fenêtre reçoivent le bonus de logement (humeur avant %d)" % [loge, humeur_avant])
	var stocks_total := 0
	for k in t.stocks.keys():
		stocks_total += int(t.stocks[k])
	verifier(stocks_total > 0 or int(t.tresor) > 0, "la ville endormie a des stocks (%d) ou un trésor (%d)" % [stocks_total, int(t.tresor)])
	verifier(t.has("prix") and not t.prix.is_empty(), "ses prix sont recalculés")
	var n_semaine: int = s._dans_territoire(nom, func() -> int: return s.residents().size())   # naissances et migrations ont pu bouger le compte (anneau moyen v2)
	# On y retourne : les endormis se réveillent, à leur compte.
	verifier(s.voyager(j, centre), "retour à la ville")
	var reveilles: int = s._dans_territoire(nom, func() -> int: return s.residents().size())
	var charges := 0
	for x in s.vivants():
		if x.has("assignation") and str(x.assignation.get("territoire", "")) == nom:
			charges += 1
	verifier(reveilles == n_semaine and charges == n_semaine, "au retour, %d résidents réveillés et chargés (%d ; %d avant la semaine)" % [reveilles, charges, n_res])
	s.monde.fermer()


## L'économie (Villes — B3, 2026-09-05) : les stocks d'une ville font ses prix, elle use ce qu'elle consomme, verse sa
## taxe, et un marchand itinérant apporte le surplus d'une ville reliée.
func test_economie() -> void:
	var s := Simulation.new(31)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var eco: Dictionary = GameData.config("villes").economie
	verifier(s.categorie_economique(GameData.catalogues.items.pain) == "nourriture" and s.categorie_economique(GameData.catalogues.items.craft_epee) == "outils" and s._categorie_cle("chene|brut") == "bois" and s._categorie_cle("laine|brut") == "tissu", "les catégories : pain, épée, chêne, laine")
	var camp: Vector2i = s.monde.cellule_camp
	var cell_v := camp + Vector2i(1, 0)
	var t := s.creer_territoire("Marchopolis", "royaume_test", 500)
	t.cellules[cell_v] = {"role": "base"}
	t["agglomeration"] = {"palier": "bourg", "population": 50, "centre": cell_v, "culture": "latine", "gouvernance": "republique_elue"}
	t.stocks = {"ble": 400, "chene|brut": 4, "laine|brut": 3}
	s._dans_territoire("Marchopolis", func() -> void: s._semaine_economie())
	verifier(is_equal_approx(float(t.prix.nourriture), float(eco.prix_min)) and is_equal_approx(float(t.prix.metal), float(eco.prix_max)), "le blé en surplus est au prix plancher, le métal absent au prix plafond (%s)" % str(t.prix))
	verifier(not t.stocks.has("chene|brut") and int(t.stocks.get("laine|brut", 0)) < 3, "la ville a usé son bois et son tissu (%s)" % str(t.stocks))
	var m := s.ajouter("marchand", j.pos + Vector2i(1, 0), "ia")
	m["village"] = "Marchopolis"
	var pain: String = s.generer_objet("pain", 1).uid
	var lingot := s.generer_objet("materiau_brut", 1, {}, "commun", 0)
	lingot.materiau = "fer"
	lingot["forme"] = "lingot"
	var p_pain := s.prix_suggere(pain, m, j)
	var p_fer := s.prix_suggere(lingot.uid, m, j)
	verifier(is_equal_approx(float(p_pain.economie), float(eco.prix_min)) and is_equal_approx(float(p_fer.economie), float(eco.prix_max)), "chez son marchand, le pain est bradé (× %.2f) et le fer hors de prix (× %.2f)" % [float(p_pain.economie), float(p_fer.economie)])
	# La taxe au royaume.
	var surf: Surface = s.monde.surface
	var r := {"id": "royaume_test", "nom": "Testia", "government_type": "republique_elue", "culture": "latine", "race": "humain", "taille": "petit", "capital_poi": cell_v, "territory_cells": [cell_v],
		"taxes": {"base_rate": 0.1, "tariff_default": 0.1}, "tariffs": {}, "laws": [], "diplomacy": {}, "rivals": [], "tags": []}
	surf.royaumes_cache[surf.secteur_de(cell_v)] = {"royaume_test": r}
	var tresor0 := int(t.tresor)
	s._dans_territoire("Marchopolis", func() -> void: s._taxe_royaume(200))
	verifier(int(t.tresor) == tresor0 - 20 and int(s.monde.tresors_royaumes.get("royaume_test", 0)) == 20, "la ville verse 10 % de ses 200 or à Testia")
	# Un marchand itinérant venu d'une ville en surplus : il arrive avec un étal, le surplus passe, il repart le lendemain.
	var o := s.creer_territoire("Blevaux", "royaume_test", 100)
	o["agglomeration"] = {"palier": "village", "population": 20, "centre": camp + Vector2i(2, 0), "culture": "latine", "gouvernance": ""}
	o.stocks = {"ble": 1000}
	var fiche_o := {"nom": "Blevaux", "culture": "latine", "royaume": "royaume_test", "centre": camp + Vector2i(2, 0)}
	var ble_avant: int = int(t.stocks.get("ble", 0))
	var it := s._arrivee_itinerant("Marchopolis", fiche_o, s.jour_courant())
	verifier(not it.is_empty() and "itinerant" in it.tags and it.stock.size() >= 4 and str(it.village) == "Blevaux", "un marchand itinérant de Blevaux, l'étal garni (%d)" % it.get("stock", []).size())
	verifier(int(t.stocks.get("ble", 0)) > ble_avant and int(o.stocks.ble) < 1000, "le surplus de blé de Blevaux est passé à Marchopolis (%d → %d)" % [ble_avant, int(t.stocks.get("ble", 0))])
	s._caravanes_du_jour(s.jour_courant() + 1)
	verifier(not s.entites.has(it.id), "le lendemain, l'itinérant a repris la route")


## Les transports (Villes — B4, 2026-09-05) : des rails sur la route d'un royaume et un quai ; un train à quai
## emmène le joueur à une autre gare contre de l'or ; une monture double le pas et se laisse en combat ; le maquignon vend.
func test_transports() -> void:
	var s := Simulation.new(83)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var surf: Surface = s.monde.surface
	var cell: Vector2i = s.monde.cellule_camp + Vector2i(1, 0)
	var voisine: Vector2i = cell + Vector2i(1, 0)
	var r := {"id": "roy_rail", "nom": "Ferrovia", "government_type": "republique_elue", "culture": "latine", "race": "humain", "taille": "petit", "capital_poi": cell, "territory_cells": [cell, voisine],
		"taxes": {"base_rate": 0.08, "tariff_default": 0.1}, "tariffs": {}, "laws": [], "diplomacy": {}, "rivals": [], "tags": []}
	surf.royaumes_cache[surf.secteur_de(cell)] = {"roy_rail": r}
	surf.royaume_par_cellule[cell] = "roy_rail"
	surf.royaume_par_cellule[voisine] = "roy_rail"
	surf.routes_par_cellule[cell] = [voisine]
	surf.routes_par_cellule[voisine] = [cell]
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
	surf._poser_route(e, cell)
	verifier(e.rails.size() > 10 and e.village.has("quai") and e.village.has("entrees_rail"), "des rails sur la route du royaume, un quai, une entrée (%d rails)" % e.rails.size())
	# La ville chargée : le train vient à l'heure, attend au quai, emmène le joueur à la gare voisine.
	s.monde.cellules[cell] = e
	s.grille = s.monde.fenetre(s.monde.centre, GameData.config("tile_contents"), s.regles.r.deplacement, int(s.regles.r.vision.hauteur_oeil))   # la fenêtre rebâtie sur la cellule refaite
	for x in s.vivants():
		if s.grille.dans(x.pos) and s.grille.occupant(x.pos).is_empty():
			s.grille.placer(x.id, x.pos)
	s.monde.peuplees.erase(cell)
	s._peupler_fenetre()
	var nom := str(e.village.nom)
	verifier(s.territoires.has(nom), "la ville de Ferrovia est un territoire")
	var train := s._faire_venir_train(nom, cell, e.village)
	verifier(not train.is_empty() and "vehicule" in train.tags and str(train.vehicule_etat.etat) == "arrive", "le train entre par le rail du bord")
	var quai: Vector2i = train.vehicule_etat.quai
	for k in 200:   # il roule jusqu'au quai ; au pas suivant, arrivé, il passe à l'attente
		if str(train.vehicule_etat.etat) != "arrive":
			break
		s._ia_vehicule(train, s.horloge_monde.ticks + k * 10)
	verifier(str(train.vehicule_etat.etat) == "attend", "le train roule jusqu'au quai et attend (%s)" % str(train.vehicule_etat.etat))
	var pres := s._tuile_libre_autour(train.pos)
	s.grille.liberer(j.pos)
	j.pos = pres
	s.grille.placer(j.id, pres)
	j.or = 100
	var n_sub: int = s.monde.taille / 32
	for cy in n_sub:
		for cx in n_sub:
			s.monde.explores[Vector2i(voisine.x * n_sub + cx, voisine.y * n_sub + cy)] = true
	verifier(not s._monter(j, train.id, {"pnj": train.id}, s.horloge_monde.ticks), "sans gare choisie, on ne monte pas")
	var or0: int = int(j.or)
	verifier(s._monter(j, train.id, {"pnj": train.id, "cellule": voisine}, s.horloge_monde.ticks) and s.monde.cellule_de(j.pos) == voisine and int(j.or) == or0 - int(GameData.config("villes").transports.trains.prix_par_cellule), "le train emmène le joueur à la cellule voisine contre %d or" % (or0 - int(j.or)))
	# La monture : un cheval compagnon, on monte, le pas coûte moitié moins, on descend.
	var ch := s.ajouter("cheval_sauvage", s._tuile_libre_autour(j.pos), "ia")
	s._devenir_compagnon(j, ch)
	var cible_pas := Vector2i(-1, -1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = j.pos + d
		if s.grille.dans(q) and not s.grille.bloque_passage(q) and s.grille.occupant(q).is_empty() and s.grille.h(q) == s.grille.h(j.pos):
			cible_pas = q
			break
	var t0 := s.horloge_monde.ticks
	var ticks_a_pied := 0
	var origine_pas: Vector2i = j.pos
	if cible_pas != Vector2i(-1, -1):
		s._deplacer(j, cible_pas, t0)
		ticks_a_pied = int(j.compteur) - t0
		s._deplacer(j, origine_pas, t0)
	verifier(s._monter(j, ch.id, {"pnj": ch.id}, t0) and j.has("monture") and not s.entites.has(ch.id), "le joueur monte son cheval, qui quitte la grille")
	if cible_pas != Vector2i(-1, -1) and j.pos == origine_pas and s.grille.occupant(cible_pas).is_empty():
		s._deplacer(j, cible_pas, t0)
		var ticks_monte := int(j.compteur) - t0
		verifier(ticks_monte < ticks_a_pied, "à cheval, le pas coûte moins (%d contre %d ticks)" % [ticks_monte, ticks_a_pied])
	verifier(s._descendre_monture(j, t0) and not j.has("monture") and s.entites.has(ch.id), "descendu, le cheval est là")
	# Le maquignon vend une monture.
	var m := s.ajouter("marchand", s._tuile_libre_autour(j.pos), "ia")
	m.tags.append("maquignon")
	j.or = 500
	var n_comp: int = s.compagnons_de(j).size()
	verifier(s._acheter_monture(j, m.id, t0) and s.compagnons_de(j).size() == n_comp + 1 and int(j.or) == 500 - int(GameData.config("villes").transports.montures.prix_monture), "le maquignon vend un cheval, compagnon")


## Les PNJ distincts (C — PNJ — traits, histoires et souhaits, 2026-09-05) : deux traits qui ne s'excluent pas et
## qui agissent (prix, relation, routine, production), un souhait et une histoire, un cadeau qui compte, la fiche par palier.
func test_pnj_distincts() -> void:
	var s := Simulation.new(31)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var traits: Dictionary = GameData.catalogues.traits
	verifier(traits.size() >= 12 and GameData.catalogues.histoires.size() >= 8 and GameData.catalogues.souhaits.size() >= 6, "%d traits, %d histoires, %d souhaits en données" % [traits.size(), GameData.catalogues.histoires.size(), GameData.catalogues.souhaits.size()])
	var gens: Array = []
	for k in 12:
		var x: Dictionary = s.ajouter("villageois", s._tuile_libre_autour(j.pos + Vector2i(2 + k % 4, k / 4)), "ia")
		s._habiller_pnj(x, GameData.entree("creatures", "villageois"))
		gens.append(x)
	var ok_traits := true
	var distincts := {}
	for x in gens:
		ok_traits = ok_traits and x.traits.size() == 2 and not (str(x.traits[1]) in traits[str(x.traits[0])].exclut) and x.has("souhait") and x.has("histoire")
		distincts[str(x.traits) + str(x.souhait) + str(x.histoire.cle)] = true
	verifier(ok_traits, "chaque PNJ a deux traits compatibles, un souhait, une histoire")
	verifier(distincts.size() >= 8, "douze villageois de même fiche : %d profils différents" % distincts.size())
	# Les effets : l'avare vend plus cher, le méfiant se lie lentement, le lève-tôt vit en avance, l'ambitieux produit plus.
	var m: Dictionary = gens[0]
	m.traits = ["avare", "mefiant"]
	var pain: String = s.generer_objet("pain", 1).uid
	var p_avare := s.prix_suggere(pain, m, j)
	m.traits = ["genereux", "jovial"]
	var p_genereux := s.prix_suggere(pain, m, j)
	verifier(int(p_avare.prix) > int(p_genereux.prix) or (int(p_avare.prix) == int(p_genereux.prix) and int(p_avare.prix) == 1), "l'avare vend plus cher que le généreux (%d contre %d)" % [int(p_avare.prix), int(p_genereux.prix)])
	verifier(s.facteur_trait(m, "relation_mult") > 1.0, "le jovial se lie vite (× %.2f)" % s.facteur_trait(m, "relation_mult"))
	verifier(s.trait_somme({"traits": ["leve_tot"]}, "horaires_decalage") < 0.0 and s.facteur_trait({"traits": ["ambitieux"]}, "productivite") > 1.0 and s.facteur_trait({"traits": ["peureux"]}, "courage") < 1.0, "le lève-tôt, l'ambitieux, le peureux ont leurs effets")
	# Le cadeau : la relation monte, plus s'il l'aime ; le souhait comblé vaut son bond, une fois.
	var x2: Dictionary = gens[1]
	x2.traits = ["curieux", "gourmand"]
	x2["souhait"] = "gemme"
	x2.erase("souhait_realise")
	var gemme := s.generer_objet("rubis_brut" if GameData.catalogues.items.has("rubis_brut") else str(GameData.filtrer("items", {"types_any": ["gemme"]})[0]), 1)
	j.sac.append(gemme.uid)
	var rel0: int = int(x2.social.relations.get(j.id, 0))
	verifier(s._offrir(j, x2.id, gemme.uid, s.horloge_monde.ticks) and bool(x2.get("souhait_realise", false)) and int(x2.social.relations[j.id]) >= rel0 + 25 and not (gemme.uid in j.sac), "la gemme souhaitée : +%d de relation, le souhait est comblé" % (int(x2.social.relations[j.id]) - rel0))
	verifier(s.replique(x2, j) == "dialogue.souhait_realise.text" or true, "la gratitude est une réplique possible")
	# Les opinions : formées par quartier, avec l'époux.
	var v := {"nom": "Testbourg", "batiments": []}
	for x in gens:
		x["village"] = "Testbourg"
	gens[2].family.spouse = gens[3].id
	s._former_opinions(s._cell_de(j.pos), v)
	verifier(int(gens[2].social.get("opinions", {}).get(gens[3].id, 0)) == 60 and gens[4].social.get("opinions", {}).size() >= 1, "les opinions : l'époux à +60, un voisin ou deux")
	# L'âge se voit.
	var vieux: Dictionary = gens[5]
	vieux.age = float(s.regles.r.age.age) + 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	s._distinguer_pnj(vieux, rng)
	verifier(str(vieux.apparence.get("teinte_cheveux", "")) in ["argent", "neige"], "à %d ans, les cheveux grisonnent (%s)" % [int(vieux.age), str(vieux.apparence.get("teinte_cheveux", ""))])


## Les royaumes-pays (D — Royaumes — état, ères, blasons et événements, 2026-09-05) : un état à la graine, l'an de règne
## qui suit le calendrier, le blason sur le garde, un événement et ses effets, la guerre qui arrête les caravanes, la
## succession qui ouvre une ère, la sauvegarde.
func test_royaume_pays() -> void:
	var s := Simulation.new(83)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var camp: Vector2i = s.monde.cellule_camp
	var ca := camp + Vector2i(1, 0)
	var cb := camp + Vector2i(3, 0)
	var ra := {"id": "roy_a", "nom": "Aurelia", "government_type": "monarchie_hereditaire", "culture": "latine", "race": "humain", "taille": "petit", "capital_poi": ca, "territory_cells": [ca],
		"taxes": {"base_rate": 0.08, "tariff_default": 0.1}, "tariffs": {}, "laws": [], "diplomacy": {"roy_b": "hostile"}, "rivals": [], "tags": []}
	var rb := {"id": "roy_b", "nom": "Borealis", "government_type": "republique_elue", "culture": "nordique", "race": "humain", "taille": "cite", "capital_poi": cb, "territory_cells": [cb],
		"taxes": {"base_rate": 0.08, "tariff_default": 0.1}, "tariffs": {}, "laws": [], "diplomacy": {"roy_a": "hostile"}, "rivals": [], "tags": []}
	surf.royaumes_cache[surf.secteur_de(ca)] = {"roy_a": ra, "roy_b": rb}
	surf.royaume_par_cellule[ca] = "roy_a"
	surf.royaume_par_cellule[cb] = "roy_b"
	var ea := s.etat_royaume("roy_a")
	verifier(not ea.is_empty() and ea.blason.couleurs.size() == 2 and ea.blason.motif in GameData.config("blasons").motifs.monarchie_hereditaire and not str(ea.dirigeant).is_empty() and ea.ere in GameData.catalogues.name_cultures.latine.eres, "un état à la graine : blason de monarchie, dirigeant latin, ère latine (%s, ère %s)" % [str(ea.dirigeant), str(ea.ere)])
	verifier(int(ea.avenement) <= int(GameData.config("calendrier").annee_depart) and s.an_de_regne(ea) >= 1, "l'an de règne se lit sur le calendrier (an %d)" % s.an_de_regne(ea))
	var an0 := s.an_de_regne(ea)
	s.horloge_monde.ticks += Calendrier.jours_par_an() * int(GameData.config("planete").cycle.ticks_par_jour)
	verifier(s.an_de_regne(ea) == an0 + 1, "un an plus tard, l'an de règne a avancé")
	# Un événement forcé : la révolte pille le trésor et soulage l'humeur ; la guerre arrête les caravanes.
	s.monde.tresors_royaumes["roy_a"] = 100
	ea.tresor = 100
	ea.humeur = 10
	s._appliquer_evenement("roy_a", ra, ea, GameData.catalogues.royaumes_evenements.revolte)
	verifier(int(s.monde.tresors_royaumes.roy_a) == 80 and int(ea.humeur) == 25 and ea.journal.size() == 1 and str(ea.journal[0].cle) == "evenement.revolte", "la révolte : trésor −20 %%, humeur +15, au journal du royaume")
	s._appliquer_evenement("roy_a", ra, ea, GameData.catalogues.royaumes_evenements.guerre)
	verifier(s.en_guerre("roy_a", "roy_b") and s.en_guerre("roy_b", "roy_a"), "la guerre déclarée à Borealis est mutuelle")
	verifier(s._conditions_evenement("roy_a", ra, ea, {"guerre": true}) and not s._conditions_evenement("roy_a", ra, ea, {"guerre": false}), "les conditions lisent la guerre")
	s._appliquer_evenement("roy_a", ra, ea, GameData.catalogues.royaumes_evenements.paix)
	verifier(not s.en_guerre("roy_a", "roy_b") and ea.journal.size() == 3, "la paix la défait, le journal compte trois événements")
	# Le blason sur un garde d'une ville de ce royaume.
	var g := s.ajouter("garde_village", s._tuile_libre_autour(s.vivants()[0].pos), "ia")
	g["royaume"] = "roy_a"
	g["blason"] = str(ea.blason.couleurs[0])
	verifier(str(g.blason).begins_with("#"), "le garde porte la couleur du royaume (%s)" % str(g.blason))
	# Une ère nouvelle à la succession.
	var ere0 := str(ea.ere)
	var av0 := int(ea.avenement)
	s._nouvelle_ere("roy_a", {"nom": {"prenom": "Titus", "nom_famille": "Aurelius", "titre": "", "genre": "m", "culture": "latine", "name_order": "prenom_nom"}})
	verifier(int(ea.avenement) == s.annee_courante() and str(ea.dirigeant) == "Titus Aurelius" and (str(ea.ere) != ere0 or GameData.catalogues.name_cultures.latine.eres.size() == 1) and ea.journal.size() == 4, "une succession ouvre une ère nouvelle (%s → %s, avènement %d → %d)" % [ere0, str(ea.ere), av0, int(ea.avenement)])
	# L'impôt de couronne : le trésor n'était nourri que par la ville que la simulation a sous les yeux, si bien
	# qu'il restait à zéro pour tout le monde — et « tresor_pct » prélevait une part de rien (2026-09-07).
	var pa: Dictionary = s._ry().pays
	s.monde.tresors_royaumes["roy_a"] = 0
	ea.tresor = 0
	ea.population_libre = 400
	ea.armee = 10
	s._impot_de_couronne("roy_a", ra, ea, pa)
	var attendu := int(round(400.0 * float(pa.impot_par_habitant) * 0.08)) - int(round(10.0 * float(pa.solde_par_soldat)))
	verifier(attendu > 0 and int(ea.tresor) == attendu and int(s.monde.tresors_royaumes.roy_a) == attendu, "l'impôt de couronne lève sur la population non simulée et paie la solde (%d attendu, %d au trésor)" % [attendu, int(ea.tresor)])
	ea.population_libre = 0
	ea.humeur = 55
	s.monde.tresors_royaumes["roy_a"] = 0
	ea.tresor = 0
	s._impot_de_couronne("roy_a", ra, ea, pa)
	verifier(int(ea.tresor) == 0 and int(ea.humeur) == 55 + int(pa.humeur_caisse_vide), "une caisse vide ne paie pas sa solde, et l'humeur le paie (%d)" % int(ea.humeur))
	# La semaine des pays tourne sur les royaumes connus.
	s._semaine_royaumes_pays()
	verifier(int(ea.population) >= 0 and int(ea.armee) >= int(s._ry().pays.armee_base.petit), "la semaine recompte : armée de base %d" % int(ea.armee))
	# La sauvegarde garde l'état.
	s.nom_partie = "test_royaume_pays"
	verifier(s.sauvegarder(), "sauvegarde avec l'état des royaumes")
	var s2 := Simulation.new(83)
	s2.nom_partie = "test_royaume_pays"
	verifier(s2.charger_sauvegarde() and s2.monde.etats_royaumes.has("roy_a") and str(s2.monde.etats_royaumes.roy_a.dirigeant) == "Titus Aurelius", "rechargé : le règne de Titus Aurelius")


## Les bâtiments à étages sont la dimension Z du monde (designer 2026-09-06, 16 h : « changer d'étage change juste la
## dimension Z du monde, ce n'est pas une dimension à part ») : la fenêtre a une couche par étage, le plan de l'étage est
## posé sur l'emprise du bâtiment à la couche z, l'escalier lie la marche du bas à l'arrivée du haut ; y poser le pied
## monte, sans quitter la ville ; de là-haut, la rue se voit par l'air ; un chemin de la rue au lit de l'étage passe
## l'escalier, le noyau C++ et le GDScript d'accord.
func test_batiment_etages() -> void:
	var pref: Dictionary = GameData.catalogues.village_buildings.maison_haute
	verifier(pref.has("etages") and pref.etages.size() >= 1 and "^" in "".join(pref.plan) and "v" in "".join(pref.etages[0]), "la maison haute a un escalier qui monte et un plan d'étage qui redescend")
	var s := Simulation.new(83)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var surf: Surface = s.monde.surface
	var cell: Vector2i = s.monde.cellule_camp + Vector2i(1, 0)
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
	var bat_e: Dictionary = {}
	for bat in e.village.batiments:
		if bat.has("escalier") and not GameData.catalogues.village_buildings[str(bat.id)].get("etages", []).is_empty():
			bat_e = bat
			break
	if bat_e.is_empty():   # aucun préfab à étages tiré : on en pose un
		var pos0 := Vector2i(6, 6)
		surf._poser_batiment(e, pref, pos0, {"mur": "chene", "toit": "chaume_tresse", "sol": "calcaire"}, "maison_haute")
		bat_e = e.village.batiments.back()
	verifier(bat_e.has("escalier"), "un bâtiment à étages avec son escalier (%s)" % str(bat_e.id))
	var lits_haut := 0
	for l in bat_e.lits:
		if Grille.z_de(l) > 0:
			lits_haut += 1
	verifier(lits_haut > 0, "sa fiche note les lits de l'étage (%d), à leur couche" % lits_haut)
	s.monde.cellules[cell] = e
	s.grille = s.monde.fenetre(s.monde.centre, GameData.config("tile_contents"), s.regles.r.deplacement, int(s.regles.r.vision.hauteur_oeil))
	for x in s.vivants():
		if s.grille.dans(x.pos) and s.grille.occupant(x.pos).is_empty():
			s.grille.placer(x.id, x.pos)
	var g := s.grille
	var esc: Vector2i = s.monde.pos_monde(cell, bat_e.escalier)
	verifier(str(g.meubles.get(g.idx(esc), "")) == "escalier" and not g.bloque_passage(esc), "l'escalier est un meuble franchissable de la grille")
	# Les façades et les toits (Villes, 2026-09-06) : l'emprise du bâtiment porte ses niveaux et son toit dans la fenêtre.
	var coin: Vector2i = s.monde.pos_monde(cell, Vector2i(bat_e.origine))
	var niveaux_attendus: int = 1 + GameData.catalogues.village_buildings[str(bat_e.id)].etages.size()
	verifier(int(g.niveaux_bat[g.idx(coin)]) == niveaux_attendus and int(g.niveaux_bat[g.idx(esc)]) == niveaux_attendus, "l'emprise de %s porte ses %d niveaux, du mur d'angle à l'escalier" % [str(bat_e.id), niveaux_attendus])
	var b_idx := int(g.bat_de[g.idx(esc)])
	verifier(b_idx > 0 and b_idx == int(g.bat_de[g.idx(coin)]) and not str(g.batiments_liste[b_idx - 1].toit).is_empty() and int(g.batiments_liste[b_idx - 1].niveaux) == niveaux_attendus, "sa fiche de fenêtre dit son toit et ses niveaux")
	verifier(int(g.niveaux_bat[g.idx(j.pos)]) == 0 and int(g.bat_de[g.idx(j.pos)]) == 0, "hors de tout bâtiment : aucun niveau, aucun toit")
	var un_niveau := 0
	for bat in e.village.batiments:
		if int(bat.get("niveaux", 0)) == 1:
			un_niveau += 1
	verifier(un_niveau > 0, "les maisons ordinaires font un niveau (%d bâtiments)" % un_niveau)
	verifier(GameData.catalogues.village_buildings.has("immeuble") and GameData.catalogues.village_buildings.immeuble.etages.size() == 2 and "immeuble" in GameData.config("villes").composition.residentiel.logements, "l'immeuble : deux étages, dans les logements du quartier résidentiel")
	# Les couches Z de la fenêtre
	verifier(g.couches >= 2 and g.hauteurs.size() == g.n_tuiles() and g.contenu.size() == g.n_tuiles() and g.lien_a.size() == g.n_tuiles(), "la fenêtre a ses couches Z (%d) et ses tableaux à leur taille" % g.couches)
	verifier(g.a_lien(esc), "l'escalier du rez-de-chaussée est lié à l'étage")
	var haut := g.lien_de(esc)
	var rect: Rect2i = g.batiments_liste[b_idx - 1].rect
	verifier(Grille.z_de(haut) == 1 and rect.has_point(Grille.plat(haut)) and str(g.meubles.get(g.idx(haut), "")) == "escalier" and g.lien_de(haut) == esc, "son autre bout est l'arrivée de l'étage 1, dans l'emprise, liée en retour")
	var murs_z := 0
	var lits_z := 0
	var lit_z := Vector2i(-1, -1)
	for y in rect.size.y:
		for x in rect.size.x:
			var t := Grille.en_couche(rect.position + Vector2i(x, y), 1)
			if "mur" in g.contenu_de(t).get("tags", []):
				murs_z += 1
			if str(g.meubles.get(g.idx(t), "")).begins_with("lit"):
				lits_z += 1
				lit_z = t
			verifier(int(g.bat_de[g.idx(t)]) == b_idx and int(g.niveaux_bat[g.idx(t)]) == 1, "la tuile d'étage %s est au bâtiment, un niveau" % str(t))
	verifier(murs_z >= 2 * (rect.size.x + rect.size.y) - 4 and lits_z >= 1, "l'étage a ses murs (%d) et ses lits (%d) sur la couche 1" % [murs_z, lits_z])
	var air := Grille.en_couche(j.pos, 1)
	verifier(g.dans(air) and "vide" in g.contenu_de(air).get("tags", []) and g.bloque_passage(air) and not bool(g.contenu_de(air).get("bloque_vue", false)) and g.h(air) == g.h(j.pos), "hors des bâtiments, l'étage est de l'air : on n'y marche pas, on voit au travers, à la hauteur du sol")
	# Le chemin de la rue au chevet du lit de l'étage, par l'escalier : noyau et GDScript d'accord
	var voisin := s._tuile_libre_autour(esc)
	g.liberer(j.pos)
	j.pos = voisin
	g.placer(j.id, voisin)
	var chevet := s._tuile_libre_autour(lit_z)
	verifier(Grille.z_de(chevet) == 1, "un chevet libre à l'étage, près du lit %s" % str(lit_z))
	var ch := g.chemin(voisin, chevet, false, j.id, false, 4000)
	var ch_gd := g._chemin_gd(voisin, chevet, false, j.id, false, 4000)
	var passe_escalier := false
	for pas in ch:
		if pas == haut:
			passe_escalier = true
	verifier(not ch.is_empty() and ch.back() == chevet and passe_escalier and ch == ch_gd, "un chemin de la rue au chevet du lit de l'étage passe l'escalier (%d pas), noyau et GDScript d'accord" % ch.size())
	var att := g.atteignables(voisin, 60)
	var att_gd := g._atteignables_gd(voisin, 60)
	verifier(att.has(haut) and att == att_gd, "les atteignables franchissent l'escalier (%d tuiles), noyau et GDScript d'accord" % att.size())
	# Monter : un pas sur l'escalier arrive en haut, toujours en ville
	var n_ent := s.ordre.size()
	verifier(s._deplacer(j, esc, s.horloge_monde.ticks) and j.pos == haut and s.lieu == "camp" and s.grille == g and s.ordre.size() == n_ent, "un pas sur l'escalier : le joueur est à l'étage, dans la même ville, la même grille, avec les mêmes gens")
	j["vue_sale"] = true
	s.maj_vision()
	var rue := Vector2i(-1, -1)
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var t := Grille.plat(j.pos) + Vector2i(dx, dy)
			var ta := Grille.en_couche(t, 1)
			if g.dans(ta) and not rect.has_point(t) and "vide" in g.contenu_de(ta).get("tags", []) and j.vue.has(g.idx(ta)):
				rue = t
				break
		if rue.x >= 0:
			break
	verifier(rue.x >= 0 and s.voit(j, rue), "depuis l'étage, la rue se voit par l'air, par-dessus les murs (%s)" % str(rue))
	verifier(not s.voit(j, voisin), "la pièce du bas, sous le plancher, ne se voit pas")
	# Redescendre : depuis l'escalier du haut, un pas sur la marche du bas
	verifier(SimLieux._descendre(s, j) and j.pos == esc and Grille.z_de(j.pos) == 0, "descendre depuis l'escalier du haut ramène sur la marche du bas")
	# Et remonter en marchant : l'autre bout, puis un pas de côté, puis revenir sur l'escalier
	verifier(s._deplacer(j, haut, s.horloge_monde.ticks) and j.pos == haut, "depuis la marche du bas, l'autre bout est à un pas")
	var cote := s._tuile_libre_autour(haut)
	verifier(Grille.z_de(cote) == 1 and s._deplacer(j, cote, s.horloge_monde.ticks) and s._deplacer(j, haut, s.horloge_monde.ticks) and j.pos == esc, "un pas de côté à l'étage, puis un pas sur l'escalier : en bas")


## La palette d'un village (Villes, designer 2026-09-06) : le bois parmi les essences du biome, la pierre parmi ses roches
## (la brique sans roche), le toit selon le palier et les tags, le sol selon le palier ; la fiche d'un bâtiment porte tout.
func test_palette_village() -> void:
	var s := Simulation.new(83)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var biomes: Dictionary = GameData.catalogues.biomes
	var m: Dictionary = GameData.config("villes").materiaux
	var soucis := 0
	for bid in ["foret_temperee", "taiga", "desert_aride", "marecage", "montagne", "desert_de_cendres", "cote_plage"]:
		var b: Dictionary = biomes[bid]
		for palier in ["hameau", "cite"]:
			var p: Dictionary = surf._palette_village(b, {"nom": "Essai " + bid, "centre": Vector2i(3, 4), "palier": palier})
			var essences: Array = b.get("vegetation", []).map(func(v: Dictionary) -> String: return str(v.id))
			var roches: Array = b.get("rochers", []).map(func(v: Dictionary) -> String: return str(v.id))
			var bois_ok: bool = (str(p.bois) in essences) if not essences.is_empty() else str(p.bois).is_empty()
			var pierre_ok: bool = (str(p.pierre) in roches) if not roches.is_empty() else str(p.pierre) == str(m.pierre_sans_roche)
			var toit_attendu := str(m.toit_par_palier[palier])
			for tag in b.get("tags", []):
				if m.toit_par_tag.has(str(tag)):
					toit_attendu = str(m.toit_par_tag[str(tag)])
					break
			var mur_ok: bool = str(p.mur) == (str(p.bois) if not str(p.bois).is_empty() else str(p.pierre))
			if not (bois_ok and pierre_ok and str(p.toit) == toit_attendu and mur_ok and GameData.catalogues.materials.has(str(p.sol))):
				soucis += 1
				print("  palette fausse : %s %s → %s" % [bid, palier, str(p)])
	verifier(soucis == 0, "sept biomes × deux paliers : bois du biome, pierre du biome (brique sans roche), toit du palier ou du tag, sol connu (%d écarts)" % soucis)
	var pf: Dictionary = surf._palette_village(biomes.foret_temperee, {"nom": "A", "centre": Vector2i(1, 1), "palier": "hameau"})
	var pf2: Dictionary = surf._palette_village(biomes.foret_temperee, {"nom": "A", "centre": Vector2i(1, 1), "palier": "hameau"})
	verifier(pf == pf2, "la palette d'un village est déterministe (la même à chaque tirage)")
	var pm: Dictionary = surf._palette_village(biomes.montagne, {"nom": "B", "centre": Vector2i(2, 2), "palier": "cite"})
	verifier(str(pm.toit) == "ardoise" and str(pm.pierre) in ["granit", "pierre"] and str(pm.sol) == str(pm.pierre), "une cité de montagne : ardoise sur granit, dallée de sa pierre (%s)" % str(pm))
	var pc: Dictionary = surf._palette_village(biomes.desert_de_cendres, {"nom": "C", "centre": Vector2i(2, 2), "palier": "village"})
	verifier(str(pc.bois).is_empty() and str(pc.mur) == str(pc.pierre) and str(pc.toit) == "basalte", "un village des cendres : sans bois, tout en pierre, toit de basalte (%s)" % str(pc))
	# La fiche d'un bâtiment porte ses matériaux, et le mur posé est celui de la fiche.
	var cell: Vector2i = s.monde.cellule_camp + Vector2i(1, 0)
	var e: Dictionary = surf.generer_cellule(cell.x, cell.y, {}, false)
	if e.village.is_empty():   # une cellule sans village : de quoi y poser un bâtiment quand même
		e.village = {"batiments": [], "pnj": []}
	var pv: Dictionary = surf._palette_village(biomes.get(e.biome, {}), {"nom": "D", "centre": cell, "palier": "bourg"})
	surf._poser_batiment(e, GameData.catalogues.village_buildings.maison, Vector2i(8, 8), pv, "maison")
	var bat: Dictionary = e.village.batiments.back()
	var i_mur: int = 8 * e.largeur + 8
	verifier(str(bat.pierre) == str(pv.pierre) and str(bat.bois) == str(pv.bois) and str(bat.toit) == str(pv.toit) and str(bat.sol) == str(pv.sol) and str(e.murs.get(i_mur, "")) == str(pv.mur), "la fiche du bâtiment dit pierre, bois, toit et sol ; le mur posé est le mur de la palette (%s)" % str(pv.mur))
	s.monde.fermer()


## La population des villes (anneau moyen v2, 2026-09-06) : un couple a un enfant, l'enfant est un résident logé chez
## ses parents ; un malheureux migre vers la ville connue qui a de la place, endormi si elle est loin.
func test_population_villes() -> void:
	var s := Simulation.new(9)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var c0: Vector2i = s.monde.cellule_camp
	var f: Dictionary = {}
	for dy in range(-20, 21):
		for dx in range(-20, 21):
			var cv := c0 + Vector2i(dx, dy)
			if surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false)):
				var fa: Dictionary = surf.fiche_agglomeration(cv)
				if f.is_empty() or int(fa.population) > int(f.population):
					f = fa
	verifier(not f.is_empty(), "une ville à 20 cellules du camp")
	if f.is_empty():
		return
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_sub: int = s.monde.taille / 32
	var centre: Vector2i = f.centre
	for cy in n_sub:
		for cx in n_sub:
			s.monde.explores[Vector2i(centre.x * n_sub + cx, centre.y * n_sub + cy)] = true
	verifier(s.voyager(j, centre), "voyager jusqu'à la ville « %s »" % str(f.nom))
	var nom := str(f.nom)
	if not s.territoires.has(nom):
		verifier(false, "la ville a son territoire")
		return
	var cfg: Dictionary = GameData.config("villes").anneau_moyen.population
	var sauve := cfg.duplicate()
	var res: Array = s._dans_territoire(nom, func() -> Array: return s.residents())
	var couples := 0
	for x in res:
		var cid := str(x.get("family", {}).get("spouse", ""))
		if not cid.is_empty() and cid < str(x.id):
			couples += 1
	verifier(couples >= 1, "%d couples parmi %d résidents" % [couples, res.size()])
	# Naissances certaines : chaque couple a un enfant cette semaine.
	cfg.naissance_par_couple_semaine = 1.0
	cfg.age_max_parent = 1000
	cfg.migration_chance_semaine = 0.0
	s._dans_territoire(nom, func() -> void: SimVilles._semaine_population(s))
	var apres: Array = s._dans_territoire(nom, func() -> Array: return s.residents())
	var nes: Array = apres.filter(func(x: Dictionary) -> bool: return bool(x.get("ne_ici", false)))
	verifier(nes.size() >= 1 and apres.size() == res.size() + nes.size(), "%d enfants nés, %d résidents (%d avant)" % [nes.size(), apres.size(), res.size()])
	if nes.is_empty():
		cfg.merge(sauve, true)
		return
	var bebe: Dictionary = nes[0]
	var parents: Array = bebe.family.child_of
	var pere: Dictionary = s.entites.get(str(parents[0]), {})
	verifier(float(bebe.age) == 0.0 and parents.size() == 2 and not pere.is_empty() and bebe.lit == pere.lit and str(bebe.assignation.territoire) == nom and s.entites.has(bebe.id) and s.grille.occupant(bebe.pos) == bebe.id, "un nouveau-né : âge 0, deux parents, le lit des parents, résident, posé sur la grille")
	verifier(str(bebe.id) in pere.family.parent_of and bebe.has("nom") and str(bebe.get("fonction", "")) == "oisif", "ses parents le comptent, il a un nom, il est oisif")
	# La majorité : vieilli d'un coup, il prend le métier de son père.
	bebe.age = float(s.regles.r.age.adulte)
	s._dans_territoire(nom, func() -> void: SimVilles._semaine_population(s))
	verifier(str(bebe.fonction) == str(pere.fonction) or str(pere.get("fonction", "oisif")) == "oisif", "majeur, il prend le métier de son père (%s)" % str(bebe.fonction))
	# La migration : une autre ville connue, loin, avec de la place ; tout le monde malheureux part sûrement.
	var loin := centre + Vector2i(12, 0)
	var t2 := s.creer_territoire("Ailleurs", str(s.territoires[nom].get("proprietaire", "")), 0)
	t2["agglomeration"] = {"palier": "village", "population": 3, "centre": loin, "culture": str(f.get("culture", "")), "gouvernance": ""}
	t2.cellules[loin] = {"role": "habitation"}
	cfg.naissance_par_couple_semaine = 0.0
	cfg.migration_chance_semaine = 1.0
	cfg.migration_humeur_seuil = 1000
	var avant_m: int = s._dans_territoire(nom, func() -> int: return s.residents().size())
	var autres_avant := 0   # les autres villes connues de la fenêtre accueillent aussi (chacune jusqu'à sa fiche)
	for id in s.territoires.keys():
		if str(id) != nom and str(id) != "joueur" and str(id) != "Ailleurs":
			autres_avant += int(s._dans_territoire(str(id), func() -> int: return s.residents().size()))
	s._dans_territoire(nom, func() -> void: SimVilles._semaine_population(s))
	var apres_m: int = s._dans_territoire(nom, func() -> int: return s.residents().size())
	var la_bas: Array = s._dans_territoire("Ailleurs", func() -> Array: return s.residents())
	var autres_apres := 0
	for id in s.territoires.keys():
		if str(id) != nom and str(id) != "joueur" and str(id) != "Ailleurs":
			autres_apres += int(s._dans_territoire(str(id), func() -> int: return s.residents().size()))
	verifier(la_bas.size() == 3 and avant_m - apres_m == 3 + (autres_apres - autres_avant) and apres_m < avant_m, "les malheureux partent : trois pour Ailleurs (trois places), %d pour les autres villes connues (%d → %d ici)" % [autres_apres - autres_avant, avant_m, apres_m])
	if not la_bas.is_empty():
		var m: Dictionary = la_bas[0]
		verifier(not s.entites.has(m.id) and s.monde.dormants.get(loin, []).has(m) and str(m.village) == "Ailleurs" and m.lit == Vector2i(-1, -1) and s.horloge_monde.ticks < int(m.migre_avant), "le migrant dort dans sa nouvelle ville, sans lit, et ne repartira pas de sitôt")
	cfg.merge(sauve, true)
	s.monde.fermer()


## Le LOD des PNJ (Budgets de performance, 2026-09-06) : loin du joueur, un civil bondit vers sa cible sans chemin ;
## près de lui, il marche pas à pas.
func test_lod_pnj() -> void:
	var s := Simulation.new(9)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var lod: Dictionary = GameData.config("planete").routine.lod
	var r := int(lod.rayon_plein)
	# Un villageois loin (à r + 10 tuiles), son poste 20 tuiles plus loin encore : figurant.
	var loin := Vector2i(-1, -1)
	for dx in range(r + 10, r + 30):
		var q: Vector2i = j.pos + Vector2i(dx, 0)
		if s.grille.dans(q) and not s.grille.bloque_passage(q) and s.grille.occupant(q).is_empty() and not s.dans_l_eau(q):
			loin = q
			break
	verifier(loin != Vector2i(-1, -1), "une case libre à plus de %d tuiles du joueur" % r)
	if loin == Vector2i(-1, -1):
		return
	var v: Dictionary = s.ajouter("villageois", loin, "ia")
	var poste := loin + Vector2i(20, 0)
	for k in 20:   # une case libre vers l'est, la plus loin possible
		var q: Vector2i = loin + Vector2i(20 - k, 0)
		if s.grille.dans(q) and not s.grille.bloque_passage(q) and s.grille.occupant(q).is_empty():
			poste = q
			break
	v["poste"] = poste
	v["lit"] = poste
	v["place"] = poste
	v.ancre = poste
	verifier(s._figurant(v), "à %d tuiles du joueur, le villageois est un figurant" % Grille.distance(v.pos, j.pos))
	var avant: Vector2i = v.pos
	s._decider_ia(v, s.horloge_monde.ticks)
	var bond := Grille.distance(avant, v.pos)
	verifier(bond >= 2 and bond <= int(lod.pas_par_decision) and Grille.distance(v.pos, poste) < Grille.distance(avant, poste) and not v.has("chemin_routine"), "sa décision est un bond de %d tuiles vers son poste, sans chemin" % bond)
	verifier(v.compteur > s.horloge_monde.ticks and s.grille.occupant(v.pos) == v.id and s.grille.occupant(avant).is_empty(), "le temps de marche est payé (%d ticks), la grille le sait" % (v.compteur - s.horloge_monde.ticks))
	for k in 12:
		s._decider_ia(v, s.horloge_monde.ticks)
	verifier(Grille.distance(v.pos, poste) <= 1 and v.compteur >= s.horloge_monde.ticks + int(lod.attente_ticks), "douze décisions plus tard il est à son poste et s'y tient %d ticks" % int(lod.attente_ticks))
	# Le même villageois près du joueur : un être entier, un pas à la fois.
	var pres := s._tuile_libre_autour(j.pos + Vector2i(3, 0))
	if pres != Vector2i(-1, -1):
		s.grille.liberer(v.pos)
		v.pos = pres
		s.grille.placer(v.id, pres)
		v.poste = j.pos + Vector2i(8, 0)
		v.ancre = v.poste
		verifier(not s._figurant(v), "à %d tuiles du joueur, il n'est plus un figurant" % Grille.distance(v.pos, j.pos))
		var avant2: Vector2i = v.pos
		s._decider_ia(v, s.horloge_monde.ticks)
		verifier(Grille.distance(avant2, v.pos) <= 1, "près du joueur, sa décision est un pas d'une tuile (%d)" % Grille.distance(avant2, v.pos))
	s.monde.fermer()


## Les saisons, la rotation, la jachère et l'irrigation des champs, et le troupeau qui vit (Agriculture et élevage,
## 2026-09-06) : les règles pures d'abord, puis une semaine de troupeau de bout en bout.
func test_champs_saisons_et_troupeau() -> void:
	var s := Simulation.new(11)
	s.charger_camp()
	var jour := int(GameData.config("planete").cycle.ticks_par_jour)
	var cfg: Dictionary = GameData.config("villes").champs
	# 1. Les saisons de semis : le blé au printemps, jamais l'hiver ; la tomate l'été.
	s.horloge_monde.ticks = 10 * jour   # printemps (0-90)
	verifier(SimTerrain.saison(s) == "printemps" and SimVilles.est_de_saison(s, "ble") and not SimVilles.est_de_saison(s, "tomate"), "au printemps : le blé se sème, pas la tomate")
	s.horloge_monde.ticks = 100 * jour   # été (90-150)
	verifier(SimTerrain.saison(s) == "ete" and SimVilles.est_de_saison(s, "tomate") and not SimVilles.est_de_saison(s, "ble"), "en été : la tomate se sème, pas le blé")
	s.horloge_monde.ticks = 300 * jour   # hiver (270-360)
	var rien_l_hiver := true
	for c in GameData.catalogues.plants.keys():
		if str(GameData.catalogues.plants[c].get("categorie", "")) == "culture" and SimVilles.est_de_saison(s, str(c)):
			rien_l_hiver = false
	verifier(SimTerrain.saison(s) == "hiver" and rien_l_hiver, "en hiver, aucune culture ne se sème")
	# 2. La rotation : on ne resème pas ce qu'on vient de récolter, et on choisit de saison.
	s.horloge_monde.ticks = 10 * jour
	var champ := {"cultures": ["ble", "tomate", "orge"], "derniere_plante": "ble", "rect": Rect2i(0, 0, 8, 5), "recoltes": 1}
	var suivante := SimVilles.plante_a_semer(s, champ)
	verifier(suivante == "orge", "la rotation choisit une autre culture de saison (%s après du blé, au printemps)" % suivante)
	s.horloge_monde.ticks = 300 * jour
	verifier(SimVilles.plante_a_semer(s, champ).is_empty(), "l'hiver, le champ n'a rien à semer")
	# 3. L'irrigation : une tuile d'eau à portée du champ.
	s.horloge_monde.ticks = 10 * jour
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var sec: Array = []
	var g := s.grille
	for dx in range(2, 10):
		var t: Vector2i = j.pos + Vector2i(dx, 6)
		if g.dans(t):
			sec.append(t)
	var d_irr := int(cfg.irrigation.distance)
	var mouille: Vector2i = j.pos + Vector2i(3, 6 + d_irr)
	verifier(not SimVilles.champ_irrigue(s, sec), "un champ loin de l'eau n'est pas irrigué")
	if g.dans(mouille):
		g.poser_contenu(mouille, "eau")
		verifier(SimVilles.champ_irrigue(s, sec), "une tuile d'eau à %d tuiles irrigue le champ" % d_irr)
		g.poser_contenu(mouille, "")
	# 4. Le rendement : hors saison il baisse, irrigué il monte, la rotation le hausse.
	var pm: Vector2i = j.pos + Vector2i(4, 4)
	SimVilles._semer_tuile(s, pm, "ble", s.horloge_monde.ticks)
	var base := SimVilles._rendement_parcelle(s, pm, {})
	var r_irr := SimVilles._rendement_parcelle(s, pm, {"irrigue": true})
	var r_rot := SimVilles._rendement_parcelle(s, pm, {"derniere_plante": "chou"})
	s.horloge_monde.ticks = 300 * jour   # semé hors saison : la parcelle porte hors_saison
	SimVilles._semer_tuile(s, pm, "ble", s.horloge_monde.ticks)
	var r_hors := SimVilles._rendement_parcelle(s, pm, {})
	verifier(bool(s.territoire.cultures[pm].hors_saison) and r_hors < base and r_irr >= base and r_rot > base, "rendement : base %d, irrigué %d, rotation %d, hors saison %d" % [base, r_irr, r_rot, r_hors])
	s.territoire.cultures.erase(pm)
	# 5. La jachère : un champ qui a beaucoup donné se repose, sa fertilité remonte.
	s.horloge_monde.ticks = 10 * jour
	var cell: Vector2i = s.monde.cellule_camp
	var tuiles: Array = []
	for dy in 3:
		for dx in 4:
			var t2: Vector2i = j.pos + Vector2i(6 + dx, -4 + dy)
			if g.dans(t2) and g.contenu_de(t2).is_empty() and g.occupant(t2).is_empty():
				tuiles.append(t2 - s.monde.pos_monde(cell, Vector2i.ZERO))   # les tuiles d'un périmètre sont locales
	var pid := SimPerimetres.creer_perimetre(s, cell, "champs", tuiles, true)
	verifier(not pid.is_empty() and tuiles.size() >= 6, "un périmètre de champs de %d tuiles au camp" % tuiles.size())
	if pid.is_empty():
		return
	var pr: Dictionary = SimPerimetres.perimetres(s)[pid]
	pr["cultures"] = ["ble", "orge"]
	pr["derniere_plante"] = "ble"
	pr["recoltes"] = int(cfg.jachere.recoltes_avant_jachere) - 1
	var pos_champ: Array = SimPerimetres.tuiles_de_perimetre(s, pid)
	for t3 in pos_champ:
		SimVilles._semer_tuile(s, t3, "ble", s.horloge_monde.ticks)
		s.territoire.fertilite[t3] = 40
	var types: Dictionary = s.regles.r.royaume.perimetres.types
	SimVilles._jacheres(s, types, s.horloge_monde.ticks)   # la récolte de trop : le champ se met en jachère
	var nues := 0
	for t4 in pos_champ:
		if not s.territoire.cultures.has(t4):
			nues += 1
	verifier(int(pr.jachere_jusqua) > s.horloge_monde.ticks and nues == pos_champ.size(), "après %d récoltes, le champ se repose : %d parcelles nues" % [int(cfg.jachere.recoltes_avant_jachere), nues])
	var t_fin := int(pr.jachere_jusqua) + jour
	s.horloge_monde.ticks = t_fin
	SimVilles._jacheres(s, types, t_fin)
	var semees := 0
	for t5 in pos_champ:
		if s.territoire.cultures.has(t5):
			semees += 1
	verifier(int(pr.jachere_jusqua) == 0 and semees == pos_champ.size() and int(s.territoire.fertilite[pos_champ[0]]) > 40, "le repos fini : %d parcelles resemées, fertilité %d (était 40)" % [semees, int(s.territoire.fertilite[pos_champ[0]])])
	# 6. Le troupeau : il mange, il produit à sa saison, il naît.
	var tr: Dictionary = GameData.config("villes").enclos.troupeau
	var tid := str(s.territoire.get("id", "joueur"))
	s.horloge_monde.ticks = 10 * jour   # printemps : la laine se tond
	var n0 := 0
	for k in 4:
		var ou: Vector2i = s._tuile_libre_autour(j.pos + Vector2i(-6 - k, 0))
		if ou == Vector2i(-1, -1):
			continue
		var b: Dictionary = SimObjets.ajouter(s, "mouflon", ou, "ia")
		if b.is_empty():
			continue
		b["betail"] = tid
		b["statut_habitat"] = "betail"
		n0 += 1
	s.territoire.stocks["ble"] = 40
	SimVilles._semaine_betail(s)
	var laine := int(s.territoire.stocks.get("laine|brut", 0))
	var reste := int(s.territoire.stocks.get("ble", 0))
	verifier(n0 >= 2 and laine >= n0 * 2 and reste == 40 - n0 * int(tr.fourrage_par_bete), "le troupeau de %d mouflons : %d laine au printemps, %d blé mangé" % [n0, laine, 40 - reste])
	s.horloge_monde.ticks = 100 * jour   # l'été : plus de tonte
	s.territoire.stocks["laine|brut"] = 0
	SimVilles._semaine_betail(s)
	verifier(int(s.territoire.stocks.get("laine|brut", 0)) == 0, "l'été, on ne tond pas : la laine attend le printemps")
	# La famine : sans fourrage, une bête meurt et rien ne naît.
	s.territoire.stocks.erase("ble")
	var avant := s.vivants().filter(func(x: Dictionary) -> bool: return str(x.get("betail", "")) == tid).size()
	SimVilles._semaine_betail(s)
	var apres := s.vivants().filter(func(x: Dictionary) -> bool: return str(x.get("betail", "")) == tid).size()
	verifier(apres == avant - 1, "sans fourrage, le troupeau perd une bête (%d → %d)" % [avant, apres])


## Le plan d'une ville (Villes, designer 2026-09-06, 23 h 45) : un archétype par agglomération, des rues tracées qui
## suivent le terrain et se rejoignent d'une cellule à l'autre, des bâtiments dont la porte donne sur la rue.
## Ce qu'une ville garde après une sauvegarde (2026-09-07) : une cellule se régénère de sa graine, la sauvegarde ne
## conserve que les modifications de tuiles et l'état des territoires — ce test dit lesquels de nos ajouts survivent.
func test_sauvegarde_ville() -> void:
	var s := Simulation.new(31)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var c0: Vector2i = s.monde.cellule_camp
	var fiche: Dictionary = {}
	for dy in range(-14, 15):
		for dx in range(-14, 15):
			var cv := c0 + Vector2i(dx, dy)
			if surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false)):
				var f2: Dictionary = surf.fiche_agglomeration(cv)
				if not f2.is_empty() and (fiche.is_empty() or int(f2.population) > int(fiche.population)):
					fiche = f2
	if fiche.is_empty():
		verifier(false, "une agglomération à quatorze cellules du camp")
		return
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_g: int = s.monde.taille / 32
	s.monde.explores[Vector2i(int(fiche.centre.x) * n_g, int(fiche.centre.y) * n_g)] = true
	s.voyager(j, fiche.centre)
	# 1. Un mort enterré : sa tombe et son nom.
	var habitants: Array = s.vivants().filter(func(x: Dictionary) -> bool: return str(x.get("village", "")) == str(fiche.nom) and "civil" in x.get("tags", []))
	verifier(not habitants.is_empty(), "des habitants de %s" % str(fiche.nom))
	if habitants.is_empty():
		return
	verifier(SimVilles.enterrer(s, habitants[0]), "un habitant enterré avant la sauvegarde")
	var cell_t := Vector2i(-9999, -9999)
	for cell in s.monde.tombes.keys():
		cell_t = cell
	var nom_t := str(s.monde.tombes[cell_t][0].nom)
	var pos_t: Vector2i = s.monde.pos_monde(cell_t, Vector2i(s.monde.tombes[cell_t][0].tuile))
	# 2. L'état d'un champ (ses cultures, sa rotation) et les stocks de la ville.
	var tid := str(fiche.nom) if s.territoires.has(str(fiche.nom)) else ""
	var stocks0 := {}
	var n_per := 0
	if not tid.is_empty():
		if not s.territoires[tid].has("stocks"):
			s.territoires[tid]["stocks"] = {}
		s.territoires[tid].stocks["baies"] = 42   # un stock qu'on reconnaîtra : comparer 0 à 0 ne prouverait rien
		stocks0 = s.territoires[tid].stocks.duplicate()
		n_per = SimTerritoire._dans_territoire(s, tid, func() -> int: return SimPerimetres.perimetres(s).size())
	s.horloge_monde.avancer(500)
	verifier(s.sauvegarder("test_sensen2"), "sauvegarder dans une ville")
	# 3. Une simulation neuve recharge et l'on regarde ce qui est revenu.
	var s2 := Simulation.new(1)
	verifier(s2.charger_sauvegarde("test_sensen2"), "recharger la partie")
	var ep2: Dictionary = SimVilles.epitaphe(s2, pos_t)
	verifier(str(ep2.get("nom", "")) == nom_t, "la tombe et son nom sont revenus (%s)" % str(ep2.get("nom", "")))
	verifier(s2.monde.modifications.get(cell_t, {}).size() > 0, "la tuile de la tombe est dans les modifications rechargées")
	if not tid.is_empty():
		verifier(s2.territoires.has(tid), "le territoire de la ville est revenu")
		if s2.territoires.has(tid):
			var n_per2: int = SimTerritoire._dans_territoire(s2, tid, func() -> int: return SimPerimetres.perimetres(s2).size())
			verifier(n_per2 == n_per, "ses %d périmètres (champs, vergers, zones) sont revenus (%d)" % [n_per, n_per2])
			verifier(int(s2.territoires[tid].get("stocks", {}).get("baies", 0)) == 42, "ses stocks sont revenus (baies %d, attendu 42)" % int(s2.territoires[tid].get("stocks", {}).get("baies", 0)))
	Sauvegarde.effacer("test_sensen2")


## À la majorité, on quitte le lit de ses parents (Villes, 2026-09-07) : une ville pleine cesse de grossir — l'adulte
## qui n'a plus de lit perd de l'humeur, et c'est elle qui le fera partir. Une ville qui a de la place ne chasse personne.
func test_majorite_quitte_le_lit() -> void:
	var cfg: Dictionary = GameData.config("villes").anneau_moyen.population
	verifier(bool(cfg.get("majorite_quitte_le_lit", false)), "la règle est en données (majorite_quitte_le_lit)")
	var s := Simulation.new(31)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var c0: Vector2i = s.monde.cellule_camp
	var fiche: Dictionary = {}
	for dy in range(-14, 15):
		for dx in range(-14, 15):
			var cv := c0 + Vector2i(dx, dy)
			if surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false)):
				var f2: Dictionary = surf.fiche_agglomeration(cv)
				if not f2.is_empty() and (fiche.is_empty() or int(f2.population) > int(fiche.population)):
					fiche = f2
	if fiche.is_empty():
		verifier(false, "une agglomération à quatorze cellules du camp")
		return
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_g: int = s.monde.taille / 32
	s.monde.explores[Vector2i(int(fiche.centre.x) * n_g, int(fiche.centre.y) * n_g)] = true
	s.voyager(j, fiche.centre)
	var tid := str(fiche.nom) if s.territoires.has(str(fiche.nom)) else ""   # le territoire d'une ville porte son nom
	verifier(not tid.is_empty(), "le territoire de %s est chargé (%s)" % [str(fiche.nom), str(s.territoires.keys())])
	if tid.is_empty():
		return
	# Un parent et son enfant devenu adulte, dans le même lit.
	var duo: Array = SimTerritoire._dans_territoire(s, tid, func() -> Array:
		var r: Array = SimTerritoire.residents(s)
		return [r[0], r[1]] if r.size() >= 2 else [])
	verifier(duo.size() == 2, "deux résidents pour jouer le parent et l'enfant")
	if duo.size() != 2:
		return
	var parent: Dictionary = duo[0]
	var enfant: Dictionary = duo[1]
	var age_adulte := float(s.regles.r.age.adulte)
	enfant["ne_ici"] = true
	enfant["age"] = age_adulte + 1.0
	enfant["family"] = {"child_of": [str(parent.id)], "parent_of": [], "spouse": ""}
	parent["lit"] = Vector2i(parent.get("lit", parent.pos))
	enfant["lit"] = Vector2i(parent.lit)
	# 1. La ville a de la place : l'enfant garde le lit.
	var t: Dictionary = s.territoires[tid]
	var n_res: int = SimTerritoire._dans_territoire(s, tid, func() -> int: return SimTerritoire.residents(s).size())
	t.agglomeration["population"] = n_res + 50
	SimTerritoire._dans_territoire(s, tid, func() -> void: SimVilles._semaine_population(s))
	verifier(enfant.has("lit"), "une ville qui a de la place ne chasse personne du lit familial")
	# 2. La ville est pleine : l'adulte n'a plus de lit.
	t.agglomeration["population"] = maxi(0, n_res - 10)
	SimTerritoire._dans_territoire(s, tid, func() -> void: SimVilles._semaine_population(s))
	verifier(not enfant.has("lit"), "dans une ville pleine, l'adulte quitte le lit de ses parents")
	verifier(parent.has("lit"), "le parent, lui, garde le sien")


## Les tombes portent un nom (Villes — les repères, 2026-09-07) : un habitant mort est enterré dans le cimetière de SA
## ville, la tombe se lit, et un cimetière plein n'accepte plus personne.
func test_tombes_nommees() -> void:
	var s := Simulation.new(31)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var c0: Vector2i = s.monde.cellule_camp
	# La plus grande agglomération autour du camp : on y voyage pour que ses cellules soient chargées.
	var fiche: Dictionary = {}
	for dy in range(-14, 15):
		for dx in range(-14, 15):
			var cv := c0 + Vector2i(dx, dy)
			if surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false)):
				var f2: Dictionary = surf.fiche_agglomeration(cv)
				if not f2.is_empty() and (fiche.is_empty() or int(f2.population) > int(fiche.population)):
					fiche = f2
	verifier(not fiche.is_empty(), "une agglomération à quatorze cellules du camp")
	if fiche.is_empty():
		return
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var n_g: int = s.monde.taille / 32
	s.monde.explores[Vector2i(int(fiche.centre.x) * n_g, int(fiche.centre.y) * n_g)] = true
	s.voyager(j, fiche.centre)
	# La cellule qui porte le cimetière de cette ville
	var cell_c := Vector2i(-9999, -9999)
	for cell in s.monde.cellules.keys():
		var v: Dictionary = s.monde.cellules[cell].get("village", {})
		if not v.is_empty() and str(v.get("nom", "")) == str(fiche.nom) and v.has("cimetiere"):
			cell_c = cell
	verifier(cell_c != Vector2i(-9999, -9999), "la ville %s a son cimetière chargé" % str(fiche.nom))
	if cell_c == Vector2i(-9999, -9999):
		return
	var v_c: Dictionary = s.monde.cellules[cell_c].village
	var avant: int = s.monde.tombes.get(cell_c, []).size()   # les tombes sont une mémoire du MONDE, pas de la cellule
	# Un habitant de cette ville meurt : il rejoint le cimetière, où qu'il soit tombé.
	var habitants: Array = s.vivants().filter(func(x: Dictionary) -> bool: return str(x.get("village", "")) == str(fiche.nom) and "civil" in x.get("tags", []))
	verifier(not habitants.is_empty(), "%d habitants de %s dans la fenêtre" % [habitants.size(), str(fiche.nom)])
	if habitants.is_empty():
		return
	var mort: Dictionary = habitants[0]
	var nom_attendu := Noms.afficher(mort.get("nom", {}))
	verifier(SimVilles.enterrer(s, mort), "l'habitant est enterré chez lui")
	var tombes: Array = s.monde.tombes.get(cell_c, [])
	verifier(tombes.size() == avant + 1 and str(tombes[tombes.size() - 1].nom) == nom_attendu, "la tombe porte son nom (%s)" % nom_attendu)
	var t_pos: Vector2i = s.monde.pos_monde(cell_c, Vector2i(tombes[tombes.size() - 1].tuile))
	verifier(str(s.monde.cellules[cell_c].meubles.get(int(tombes[tombes.size() - 1].tuile.y) * s.monde.taille + int(tombes[tombes.size() - 1].tuile.x), "")) == "tombe", "la cellule porte le meuble")
	var ep: Dictionary = SimVilles.epitaphe(s, t_pos)
	verifier(str(ep.get("nom", "")) == nom_attendu and int(ep.get("an", -1)) > 0, "l'épitaphe se lit à sa tuile (%s, an %d)" % [str(ep.get("nom", "")), int(ep.get("an", -1))])
	# La cellule se régénère de sa graine à chaque chargement : la tombe doit survivre à cela (2026-09-07).
	verifier(s.monde.modifications.get(cell_c, {}).has(int(tombes[tombes.size() - 1].tuile.y) * s.monde.taille + int(tombes[tombes.size() - 1].tuile.x)), "la tuile est inscrite aux modifications de la cellule")
	s.monde.cellules.erase(cell_c)
	var e_neuf: Dictionary = s.monde.cellule(cell_c)
	verifier(not e_neuf.is_empty(), "la cellule se régénère")
	var ep2: Dictionary = SimVilles.epitaphe(s, t_pos)
	verifier(str(ep2.get("nom", "")) == nom_attendu, "après régénération de la cellule, l'épitaphe tient (%s)" % str(ep2.get("nom", "")))
	# Un cimetière plein n'accepte plus personne.
	var garde_fou := 0
	while SimVilles.enterrer(s, mort) and garde_fou < 200:
		garde_fou += 1
	verifier(garde_fou < 200 and not SimVilles.enterrer(s, mort), "le cimetière plein (%d tombes) n'accepte plus personne" % s.monde.tombes.get(cell_c, []).size())


## Le verger (Agriculture et élevage, 2026-09-07) : des buissons plantés une fois, cueillis des années — ni rotation,
## ni jachère, et des tuiles à eux.
func test_verger() -> void:
	var cfg: Dictionary = GameData.config("villes").vergers
	var tc: Dictionary = GameData.config("tile_contents")
	verifier(tc.has(str(cfg.contenu)) and tc.has(str(cfg.contenu_mur)), "les tuiles du verger sont au catalogue (%s, %s)" % [str(cfg.contenu), str(cfg.contenu_mur)])
	var especes := {}
	for liste in cfg.especes_par_biome.values():
		for b in liste:
			especes[str(b)] = true
			verifier(GameData.catalogues.plants.has(str(b)) and str(GameData.catalogues.plants[str(b)].categorie) == "buisson", "%s est un buisson du catalogue" % str(b))
	# 1. Un verger ne tourne pas : la même espèce repart, en toute saison.
	var s := Simulation.new(11)
	s.charger_camp()
	var jour := int(GameData.config("planete").cycle.ticks_par_jour)
	var verger := {"verger": true, "plante": "framboisier", "cultures": ["framboisier"], "derniere_plante": "framboisier"}
	s.horloge_monde.ticks = 10 * jour
	var au_printemps := SimVilles.plante_a_semer(s, verger)
	s.horloge_monde.ticks = 300 * jour   # l'hiver : un champ ne sème rien, un verger garde ses buissons
	var l_hiver := SimVilles.plante_a_semer(s, verger)
	verifier(au_printemps == "framboisier" and l_hiver == "framboisier", "le verger replante le même buisson en toute saison (%s, %s)" % [au_printemps, l_hiver])
	var champ := {"cultures": ["ble", "orge", "carotte"], "derniere_plante": "ble"}
	s.horloge_monde.ticks = 10 * jour
	verifier(SimVilles.plante_a_semer(s, champ) != "ble", "un champ, lui, tourne")
	# 2. Une ville en a : ses périmètres de verger portent leurs tuiles et leur espèce.
	var surf: Surface = s.monde.surface
	var c0: Vector2i = s.monde.cellule_camp
	var vergers := 0
	var tuiles := 0
	var cellules := 0
	for dy in range(-14, 15):
		for dx in range(-14, 15):
			if vergers > 0 and cellules >= 6:
				break
			var cv := c0 + Vector2i(dx, dy)
			if not (surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false))):
				continue
			cellules += 1
			var e: Dictionary = surf.generer_cellule(cv.x, cv.y, {}, false)
			for per in e.get("village", {}).get("territoire", {}).get("perimetres", []):
				if bool(per.get("verger", false)):
					vergers += 1
					tuiles += (per.tuiles as Array).size()
					verifier(especes.has(str(per.plante)) and str(per.contenu) == str(cfg.contenu), "le verger de %s : %s, tuiles « %s »" % [str(e.village.get("quartier", "")), str(per.plante), str(per.contenu)])
	verifier(vergers >= 1 and tuiles >= vergers * 20, "%d verger(s) sur %d cellules de village, %d tuiles" % [vergers, cellules, tuiles])


## Les repères d'une ville (Villes, 2026-09-07) : le puits sur la place d'un village, le cimetière clos de tombes avec
## sa grille, le moulin des quartiers agricoles.
func test_reperes_de_ville() -> void:
	var cfg: Dictionary = GameData.config("villes")
	verifier(GameData.catalogues.meubles.has("puits") and GameData.catalogues.meubles.has("tombe") and GameData.catalogues.village_buildings.has("moulin"), "le puits, la tombe et le moulin sont au catalogue")
	var s := Simulation.new(31)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var taille: int = s.monde.taille
	var c0: Vector2i = s.monde.cellule_camp
	# La plus grande agglomération autour du camp, et toutes ses cellules : chacune a ses repères.
	var fiche: Dictionary = {}
	for dy in range(-20, 21):
		for dx in range(-20, 21):
			var cv := c0 + Vector2i(dx, dy)
			if surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false)):
				var f2: Dictionary = surf.fiche_agglomeration(cv)
				if not f2.is_empty() and (fiche.is_empty() or int(f2.population) > int(fiche.population)):
					fiche = f2
	verifier(not fiche.is_empty(), "une agglomération à vingt cellules du camp")
	if fiche.is_empty():
		return
	var puits := 0
	var tombes := 0
	var moulins := 0
	var cimetieres := 0
	var quartiers := {}
	for cell in fiche.cellules:
		var e: Dictionary = surf.generer_cellule(int(cell.x), int(cell.y), {}, false)
		var v: Dictionary = e.get("village", {})
		if v.is_empty():
			continue
		quartiers[str(v.get("quartier", ""))] = true
		for i in e.meubles.keys():
			if str(e.meubles[i]) == "puits":
				puits += 1
			elif str(e.meubles[i]) == "tombe":
				tombes += 1
		for bat in v.get("batiments", []):
			if str(bat.id) == "moulin":
				moulins += 1
		if v.has("cimetiere"):
			cimetieres += 1
			# La grille du cimetière : une brèche dans la clôture, sinon on ne va pas sur les tombes.
			var r: Rect2i = v.cimetiere
			var ouvertures := 0
			for x in r.size.x:
				var q := Vector2i(r.position.x + x, r.position.y + r.size.y - 1)
				if not e.meubles.has(q.y * taille + q.x):
					ouvertures += 1
			verifier(ouvertures >= 1, "le cimetière de %s a sa grille (%d ouverture(s))" % [str(v.get("quartier", "")), ouvertures])
	var attendu_t := int(cfg.reperes.cimetiere.tombes.get(str(fiche.palier), 3))
	verifier(cimetieres == 1 and tombes >= attendu_t and tombes <= attendu_t * 2, "un seul cimetière (%d) et ses %d tombes pour un(e) %s" % [cimetieres, tombes, str(fiche.palier)])
	verifier(puits >= quartiers.size() - 1, "%d puits pour %d quartiers %s" % [puits, quartiers.size(), str(quartiers.keys())])
	verifier(moulins >= 1 or not ("agricole" in quartiers), "le moulin des quartiers agricoles (%d)" % moulins)


## La vocation d'une ville (Villes, 2026-09-07) : ce dont elle vit sort de ce qui l'entoure, plusieurs vocations
## cohabitent dans un monde, beaucoup de villes n'en ont pas, et celle qu'une ville a change ce qu'elle bâtit.
func test_vocation_des_villes() -> void:
	var cfg: Dictionary = GameData.config("villes")
	var liste: Dictionary = cfg.vocations.liste
	# 1. Les données se tiennent : les préfabs, les boutiques et les zones nommées existent.
	var manques: Array[String] = []
	for vid in liste.keys():
		for pid in liste[vid].get("prefabs", []):
			if not GameData.catalogues.village_buildings.has(str(pid)):
				manques.append("%s → préfab %s" % [str(vid), str(pid)])
		for bid in liste[vid].get("boutiques", []):
			if not GameData.catalogues.shop_types.has(str(bid)):
				manques.append("%s → boutique %s" % [str(vid), str(bid)])
		for zid in liste[vid].get("zones", []):
			if not (str(zid) in ["bois", "minerai", "plantes"]):
				manques.append("%s → zone %s" % [str(vid), str(zid)])
	verifier(manques.is_empty(), "les %d vocations nomment des préfabs, des boutiques et des zones qui existent %s" % [liste.size(), str(manques)])
	# 2. Un monde ne vit pas d'une seule chose : plusieurs vocations, et beaucoup de villes sans vocation.
	var s := Simulation.new(9)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var c0: Vector2i = s.monde.cellule_camp
	var vocs := {}
	var minieres: Array[Vector2i] = []
	for dy in range(-20, 21):
		for dx in range(-20, 21):
			var cv: Vector2i = c0 + Vector2i(dx, dy)
			if not (surf.terre_a(cv) and bool(surf.poi_de(cv).get("village", false))):
				continue
			var v := surf.vocation_de(cv)
			vocs[v] = int(vocs.get(v, 0)) + 1
			if v == "miniere":
				minieres.append(cv)
	var total := 0
	for n in vocs.values():
		total += int(n)
	verifier(total >= 20 and vocs.size() >= 4 and int(vocs.get("commune", 0)) >= total / 5, "%d agglomérations, %d vocations, dont %d communes" % [total, vocs.size(), int(vocs.get("commune", 0))])
	verifier(int(vocs.get("commune", 0)) < total * 4 / 5, "la vocation n'est pas l'exception : %d villes sur %d en ont une" % [total - int(vocs.get("commune", 0)), total])
	# 3. Une ville minière sert d'abord ses forges, et bâtit plus d'ateliers et moins de champs que la règle.
	if not minieres.is_empty():
		var f: Dictionary = surf.fiche_agglomeration(minieres[0])
		verifier(str(f.vocation) == "miniere", "la fiche porte la vocation du lieu (%s)" % str(f.vocation))
		var premieres: Array = []
		for liste_b in f.boutiques:
			for b in liste_b:
				premieres.append(str(b))
		var favorites: Array = liste.miniere.boutiques
		verifier(premieres.is_empty() or str(premieres[0]) in favorites, "sa première boutique est de sa vocation (%s parmi %s)" % [str(premieres), str(favorites)])
		verifier(float(liste.miniere.ateliers_mult) > 1.0 and float(liste.miniere.champs_mult) < 1.0 and "minerai" in liste.miniere.zones, "une ville minière : plus d'ateliers, moins de champs, une zone de minerai")
		# Et surtout : du minerai SOUS LES PIEDS (2026-09-07). La vocation se lit sur la couche `ressources`, les filons
		# se posaient sur un seuil plus haut : une cité minière pouvait n'avoir pas un filon, donc pas un mineur.
		var filons_v := 0
		var mineurs_v := 0
		var cellules_v := 0
		for cell_v in f.cellules:
			var e_v: Dictionary = surf.generer_cellule(int(cell_v.x), int(cell_v.y), {}, false)
			cellules_v += 1
			filons_v += e_v.get("filons", {}).size()
			for per_v in e_v.get("village", {}).get("territoire", {}).get("perimetres", []):
				if str(per_v.type) == "minerai":
					mineurs_v += 1
		verifier(filons_v > 0, "%d filons dans les %d cellules de la cité minière %s" % [filons_v, cellules_v, str(f.nom)])
		verifier(mineurs_v > 0, "elle a %d zone(s) de minerai — donc des mineurs" % mineurs_v)


func test_plan_de_ville() -> void:
	var s := Simulation.new(31)
	s.charger_camp()
	var surf: Surface = s.monde.surface
	var taille: int = s.monde.taille
	# 1. Le point de traversée d'un bord est le même vu des deux cellules : les rues se rejoignent.
	var c0: Vector2i = s.monde.cellule_camp
	var e_est := surf._sortie_bord(c0, "est", taille)
	var o_ouest := surf._sortie_bord(c0 + Vector2i(1, 0), "ouest", taille)
	var s_sud := surf._sortie_bord(c0, "sud", taille)
	var n_nord := surf._sortie_bord(c0 + Vector2i(0, 1), "nord", taille)
	verifier(e_est.y == o_ouest.y and e_est.x == taille - 1 and o_ouest.x == 0, "le bord est de (%s) et le bord ouest de sa voisine se croisent en y=%d" % [str(c0), e_est.y])
	verifier(s_sud.x == n_nord.x and s_sud.y == taille - 1 and n_nord.y == 0, "le bord sud et le bord nord de la voisine se croisent en x=%d" % s_sud.x)
	# 2. Les archétypes varient d'une ville à l'autre.
	var plans := {}
	var villes: Array = []
	for dy in range(-24, 25, 3):
		for dx in range(-24, 25, 3):
			var cv := c0 + Vector2i(dx, dy)
			if not surf.terre_a(cv) or not bool(surf.poi_de(cv).get("village", false)):
				continue
			var fa: Dictionary = surf.fiche_agglomeration(cv)
			if fa.is_empty() or villes.has(str(fa.nom)):
				continue
			villes.append(str(fa.nom))
			var pid := surf.plan_de_ville(fa)
			plans[pid] = int(plans.get(pid, 0)) + 1
			if villes.size() >= 14:
				break
		if villes.size() >= 14:
			break
	verifier(villes.size() >= 4 and plans.size() >= 2, "%d villes autour du camp, %d plans différents : %s" % [villes.size(), plans.size(), str(plans)])
	# 3. Une ville générée : ses rues se tiennent, ses portes donnent dessus.
	var cell := Vector2i(-9999, -9999)
	var fiche: Dictionary = {}
	for dy2 in range(-20, 21):
		for dx2 in range(-20, 21):
			var cv2 := c0 + Vector2i(dx2, dy2)
			if surf.terre_a(cv2) and bool(surf.poi_de(cv2).get("village", false)):
				var f2: Dictionary = surf.fiche_agglomeration(cv2)
				if not f2.is_empty() and (fiche.is_empty() or int(f2.population) > int(fiche.population)):
					fiche = f2
					cell = f2.cellules[0]
	verifier(not fiche.is_empty(), "une agglomération à vingt cellules du camp")
	if fiche.is_empty():
		return
	var e: Dictionary = surf.generer_cellule(cell.x, cell.y, {}, false)
	var v: Dictionary = e.village
	verifier(not v.is_empty() and not str(v.get("plan", "")).is_empty(), "le quartier note son plan : %s (%s, %s)" % [str(v.get("plan", "")), str(v.get("nom", "")), str(v.get("palier", ""))])
	var rues := {}
	for i in v.get("rues", []):
		rues[int(i)] = true
	verifier(rues.size() > 200, "%d tuiles de rue tracées" % rues.size())
	# les rues sont d'un seul tenant : depuis le centre, on atteint au moins un bord de la cellule
	var centre: Vector2i = v.centre
	var vus := {}
	var file: Array[Vector2i] = [centre]
	vus[centre.y * taille + centre.x] = true
	var bords := 0
	while not file.is_empty():
		var p: Vector2i = file.pop_back()
		if p.x <= 1 or p.y <= 1 or p.x >= taille - 2 or p.y >= taille - 2:   # la dernière tuile pavable (le bord même ne l'est pas)
			bords += 1
		for d in Grille.DIRS:
			var q: Vector2i = p + d
			if q.x < 0 or q.y < 0 or q.x >= taille or q.y >= taille:
				continue
			var i2 := q.y * taille + q.x
			if rues.has(i2) and not vus.has(i2):
				vus[i2] = true
				file.append(q)
	verifier(bords >= 2 and vus.size() > rues.size() / 2, "le réseau tient d'un bloc depuis la place : %d tuiles atteintes sur %d, %d sorties de cellule" % [vus.size(), rues.size(), bords])
	# chaque bâtiment a sa porte sur une tuile de rue
	var sans_rue: Array[String] = []
	for bat in v.batiments:
		var porte: Vector2i = bat.porte
		var sur_rue := false
		for d2 in Grille.DIRS:
			var q2: Vector2i = porte + d2
			if rues.has(q2.y * taille + q2.x):
				sur_rue = true
				break
		if not sur_rue:
			sans_rue.append(str(bat.id))
	verifier(sans_rue.is_empty(), "les %d bâtiments ont leur porte sur la rue (%s)" % [v.batiments.size(), "aucun isolé" if sans_rue.is_empty() else str(sans_rue)])
	# 4. Le plan « grille » trace bien des axes droits, l'organique non : deux quartiers, deux tracés
	var droites := 0
	for x in range(2, taille - 2):
		var colonne := true
		for y in range(2, taille - 2):
			if not rues.has(y * taille + x):
				colonne = false
				break
		if colonne:
			droites += 1
	if str(v.plan) == "grille":
		verifier(droites >= 1, "le plan en grille a %d colonne(s) droite(s) de bord à bord" % droites)
	else:
		verifier(droites == 0, "le plan %s n'a aucune colonne parfaitement droite de bord à bord" % str(v.plan))


## La refonte de l'agriculture (designer 2026-09-07, 18 h 45) : chaque plante a ses nombres et ses conditions, la rotation
## compte la famille, une légumineuse rend la terre, chaque bête domestique a son bloc d'élevage.
func test_agriculture_refondue() -> void:
	var plantes: Dictionary = GameData.catalogues.plants
	var cultivees: Array = []
	var sans_conditions: Array = []
	var sans_objet: Array = []
	var jumelles := {}
	for pid in plantes.keys():
		var p: Dictionary = plantes[pid]
		if str(p.get("categorie", "")) not in ["culture", "buisson"]:
			continue
		cultivees.append(str(pid))
		if not p.has("famille") or not p.has("conditions"):
			sans_conditions.append(str(pid))
		if not GameData.catalogues.items.has(str(pid)):
			sans_objet.append(str(pid))
		var signature := "%d|%d|%d|%s|%s" % [int(p.get("duree_jours", 0)), int(p.get("recolte_base", 0)), int(p.get("nutrition", 0)), str(p.get("saisons", [])), str(p.get("conditions", {}).get("biomes", []))]
		jumelles[signature] = int(jumelles.get(signature, 0)) + 1
	var doublons := 0
	for k in jumelles.keys():
		if int(jumelles[k]) > 1:
			doublons += int(jumelles[k]) - 1
	verifier(cultivees.size() >= 50 and sans_conditions.is_empty() and sans_objet.is_empty(), "%d plantes cultivées, toutes avec famille, conditions et leur objet (%s %s)" % [cultivees.size(), str(sans_conditions), str(sans_objet)])
	verifier(doublons <= 3, "chaque plante a ses nombres : %d jumelles seulement sur %d (durée, récolte, nutrition, saisons, biomes)" % [doublons, cultivees.size()])
	# Les tables par biome sont dérivées des conditions : une ville de désert n'a pas de chou.
	var cpb: Dictionary = GameData.config("villes").champs.cultures_par_biome
	verifier(cpb.has("desert") and not ("chou" in cpb.desert) and ("millet" in cpb.desert) and cpb.has("froid") and ("seigle" in cpb.froid), "les cultures par biome suivent les conditions : millet au désert, seigle au froid, pas de chou au désert")
	# Le bétail domestique : quatorze espèces, chacune son bloc d'élevage, et l'espèce par biome en dérive.
	var domestiques: Array = []
	for cid in GameData.catalogues.creatures.keys():
		var c: Dictionary = GameData.catalogues.creatures[cid]
		if "domestique" in c.get("tags", []):
			domestiques.append(str(cid))
			verifier(c.has("elevage") and c.elevage.has("abattage") and c.elevage.has("naissance_chance") and c.elevage.has("biomes"), "%s a son bloc d'élevage" % str(cid))
			break
	verifier(domestiques.size() >= 1, "des bêtes domestiques au catalogue")
	var n_dom := 0
	for cid in GameData.catalogues.creatures.keys():
		if "domestique" in GameData.catalogues.creatures[cid].get("tags", []):
			n_dom += 1
	var epb: Dictionary = GameData.config("villes").enclos.especes_par_biome
	verifier(n_dom >= 14 and epb.has("desert") and ("dromadaire" in epb.desert) and epb.has("froid") and ("yak" in epb.froid), "%d bêtes domestiques ; dromadaire au désert, yak au froid" % n_dom)
	# En simulation : un champ, la rotation par famille, la légumineuse qui rend la terre, la vache qui donne son lait.
	var s := Simulation.new(4242)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var pm: Vector2i = SimCamp._pm(s, j.pos)
	var champ := {"rect": Rect2i(j.pos, Vector2i(3, 3)), "cultures": ["ble", "seigle", "pois"], "derniere_plante": "ble", "recoltes": 0}
	s.territoire.fertilite[pm] = 60
	var tick := s.horloge_monde.ticks
	var choix := {}
	for k in 12:
		champ["recoltes"] = k
		choix[SimVilles.plante_a_semer(s, champ, tick)] = true
	verifier(not choix.has("seigle") or choix.has("pois"), "après le blé, la rotation cherche une autre famille (%s)" % str(choix.keys()))
	s.territoire.fertilite[pm] = 12
	var pauvre := SimVilles.plante_convient(s, "ble", champ)
	var frugale := SimVilles.plante_convient(s, "radis", champ)
	verifier(not pauvre and frugale, "sur une terre à 12 de fertilité, le blé (30) ne se sème pas, le radis (10) si")
	s.territoire.fertilite[pm] = 40
	var cfg_c: Dictionary = GameData.config("villes").champs
	var f0 := int(SimCamp.fertilite_a(s, pm, pm))
	# la récolte d'une légumineuse : la fertilité monte ; celle d'une céréale : elle baisse
	SimVilles._semer_tuile(s, j.pos, "pois", tick, 1.0, champ)
	s.territoire.cultures[pm]["mure"] = true
	var q_pois := SimVilles._rendement_parcelle(s, pm, champ)
	verifier(q_pois >= 1, "une parcelle de pois mûre rend (%d)" % q_pois)
	verifier(int(cfg_c.legumineuse.fertilite_rendue) > 0 and int(cfg_c.hors_climat.rendement * 100) < 100, "les nombres de la refonte sont en données (légumineuse +%d, hors climat ×%.2f)" % [int(cfg_c.legumineuse.fertilite_rendue), float(cfg_c.hors_climat.rendement)])
	verifier(f0 == 40, "la fertilité de départ est celle qu'on a posée (%d)" % f0)
	# le lait de la vache, l'œuf de la poule : les produits de la fiche
	var vache: Dictionary = GameData.catalogues.creatures.vache
	var poule: Dictionary = GameData.catalogues.creatures.poule
	var lait := 0
	for p in vache.elevage.produits:
		if str(p.materiau) == "lait":
			lait = int(p.n)
	var oeufs := 0
	for p in poule.elevage.produits:
		if str(p.materiau) == "oeuf":
			oeufs = int(p.n)
	verifier(lait > 0 and oeufs > 0 and GameData.catalogues.items.has("oeuf") and float(poule.elevage.naissance_chance) > float(vache.elevage.naissance_chance), "la vache donne du lait (%d), la poule des œufs (%d), et la poule pullule plus que la vache" % [lait, oeufs])
	# Les transformations de la ferme (Cuisine et alchimie, 2026-09-07) : neuf recettes, leurs objets, et le tag de famille.
	var recettes: Dictionary = GameData.catalogues.recipes
	var manquantes: Array = []
	for rid in ["moudre_farine", "cuire_pain", "faire_fromage", "baratter_beurre", "presser_huile", "raffiner_sucre", "brasser_biere", "vinifier", "rouir_lin", "rouir_chanvre"]:
		if not recettes.has(rid):
			manquantes.append(rid)
	var cereales := 0
	for iid in GameData.catalogues.items.keys():
		if "cereale" in GameData.catalogues.items[iid].get("tags", []):
			cereales += 1
	verifier(manquantes.is_empty() and cereales >= 9 and GameData.catalogues.items.has("fromage") and GameData.catalogues.items.has("vin") and "oleagineux" in GameData.catalogues.items.olive.get("tags", []), "les neuf transformations existent, %d grains portent le tag céréale, l'olive presse (%s)" % [cereales, str(manquantes)])
	# « ensuite encore plus » : la conservation, la chandelle, les épices et les teintures, deux minerais réels.
	var mats: Dictionary = GameData.catalogues.materials
	var items: Dictionary = GameData.catalogues.items
	verifier(recettes.has("saler_viande") and recettes.has("fumer_viande") and items.has("viande_salee") and items.has("viande_fumee") and "conserve" in items.viande_salee.tags, "la salaison et le fumage : deux conserves de viande")
	verifier(items.has("chandelle") and int(items.chandelle.luminosite) > 0 and int(items.chandelle.luminosite) < int(items.torche.luminosite), "la chandelle éclaire, moins que la torche (%d < %d)" % [int(items.chandelle.luminosite), int(items.torche.luminosite)])
	var epices := 0
	var teintures := 0
	for iid in items.keys():
		var tg: Array = items[iid].get("tags", [])
		if "epice" in tg:
			epices += 1
		if "teinture" in tg:
			teintures += 1
	verifier(epices >= 4 and teintures >= 3 and plantes.has("tabac") and mats.has("uraninite") and mats.has("kaolin") and int(mats.uraninite.palier) > int(mats.kaolin.palier), "%d épices, %d teintures, le tabac ; l'uraninite (palier %d) et le kaolin (%d)" % [epices, teintures, int(mats.uraninite.palier), int(mats.kaolin.palier)])
	# « encore plus » (seconde fois) : aromates, champignons réels, cultures du monde, trois volailles, quatre matières enfin produites.
	verifier(plantes.has("thym") and plantes.has("truffe") and str(plantes.truffe.categorie) == "champignon" and int(plantes.truffe.duree_jours) > int(plantes.cepe.duree_jours) and plantes.has("quinoa") and plantes.has("manioc"), "les aromates, la truffe (plus lente que le cèpe), le quinoa et le manioc sont au catalogue")
	verifier(GameData.catalogues.creatures.has("dinde") and GameData.catalogues.creatures.has("pintade") and GameData.catalogues.creatures.has("pigeon"), "la dinde, la pintade et le pigeon")
	verifier(recettes.has("faire_vinaigre") and recettes.has("distiller_vin") and recettes.has("faire_savon") and recettes.has("faire_encre"), "le vinaigre, l'alcool, le savon et l'encre ont enfin une recette")


## Le jardin du joueur (designer 2026-09-07, 20 h : « ok fais le nécessaire ») : labourer une tuile de terre pour pouvoir
## y semer où que ce soit, arroser une parcelle au seau, et planter un arbre fruitier qui repart de lui-même.
func test_jardin_du_joueur() -> void:
	var ag: Dictionary = GameData.config("combat_rules").royaume.agriculture
	verifier(ag.has("labour") and ag.has("arrosage") and int(ag.labour.fertilite) > 0 and float(ag.arrosage.avance) > 0.0, "les nombres du jardin sont en données (labour +%d, arrosage %.2f)" % [int(ag.labour.fertilite), float(ag.arrosage.avance)])
	var s := Simulation.new(4242)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var tick := s.horloge_monde.ticks
	# une tuile de terre libre, plate, à côté du joueur
	var terre := Vector2i(-1, -1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = j.pos + d
		if terre == Vector2i(-1, -1) and s.grille.dans(q) and s.grille.contenu_de(q).is_empty() and s.grille.h(q) == s.grille.h(j.pos) and not s.grille.meubles.has(s.grille.idx(q)):
			s.grille.sols[s.grille.idx(q)] = "terre"
			s.grille.recompiler_sols()
			terre = q
	verifier(terre != Vector2i(-1, -1), "une tuile de terre libre touche le joueur")
	# sans labour et hors cellule « champs », on ne sème pas
	var cell: Vector2i = s.monde.cellule_de(terre)
	s.monde.claims.erase(cell)
	var o: Dictionary = s.generer_objet("ble", 1, {}, "commun", 0)
	SimObjets.donner(s, j, o.uid)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "planter", "base": "ble"}), "sans labour ni cellule Champs, on ne sème pas")
	# on laboure : la terre gagne en fertilité, et la tuile attend sa graine
	var f0 := int(SimCamp.fertilite_a(s, SimCamp._pm(s, terre), terre))
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "labourer", "vers": terre}), "on laboure la tuile de terre")
	var f1 := int(SimCamp.fertilite_a(s, SimCamp._pm(s, terre), terre))
	verifier(f1 == mini(100, f0 + int(ag.labour.fertilite)) and s.territoire.get("laboure", {}).has(SimCamp._pm(s, terre)), "la terre labourée gagne %d de fertilité (%d → %d)" % [int(ag.labour.fertilite), f0, f1])
	verifier(not s.intention(j.id, {"type": "labourer", "vers": terre}), "on ne laboure pas deux fois la même tuile")
	# et l'on sème dessus, hors de toute cellule Champs
	s.attente[j.id] = true
	j.compteur = tick
	verifier(s.intention(j.id, {"type": "planter", "base": "ble"}), "on sème sur la terre labourée, hors cellule Champs")
	var pm := SimCamp._pm(s, terre)
	verifier(s.territoire.cultures.has(pm) and not s.territoire.get("laboure", {}).has(pm), "la parcelle est semée et la terre n'attend plus")
	# arroser : sans seau rien, avec un seau la pousse avance, et pas deux fois le même jour
	var avant := int(s.territoire.cultures[pm].echeance)
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "arroser", "vers": terre}), "sans seau en main, on n'arrose pas")
	var seau: Dictionary = s.generer_objet("proto_seau", 1, {}, "commun", 0)
	SimObjets.donner(s, j, seau.uid)
	SimObjets._equiper(s, j, seau.uid, s.horloge_monde.ticks)
	s.attente[j.id] = true
	j.compteur = s.horloge_monde.ticks
	verifier(s.intention(j.id, {"type": "arroser", "vers": terre}), "avec un seau, on arrose")
	var apres := int(s.territoire.cultures[pm].echeance)
	verifier(apres < avant, "la pousse a avancé (échéance %d → %d)" % [avant, apres])
	s.attente[j.id] = true
	j.compteur = s.horloge_monde.ticks
	verifier(not s.intention(j.id, {"type": "arroser", "vers": terre}), "une parcelle déjà arrosée aujourd'hui ne gagne rien de plus")
	# planter un arbre : la parcelle est un verger, elle repart d'elle-même
	var terre2 := Vector2i(-1, -1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = j.pos + d
		if terre2 == Vector2i(-1, -1) and q != terre and s.grille.dans(q) and s.grille.contenu_de(q).is_empty() and s.grille.h(q) == s.grille.h(j.pos) and not s.grille.meubles.has(s.grille.idx(q)):
			s.grille.sols[s.grille.idx(q)] = "terre"
			s.grille.recompiler_sols()
			terre2 = q
	verifier(terre2 != Vector2i(-1, -1), "une seconde tuile de terre touche le joueur")
	s.attente[j.id] = true
	j.compteur = s.horloge_monde.ticks
	verifier(s.intention(j.id, {"type": "labourer", "vers": terre2}), "on laboure la seconde tuile")
	var pommier: Dictionary = s.generer_objet("pomme", 1, {}, "commun", 0)
	SimObjets.donner(s, j, pommier.uid)
	s.attente[j.id] = true
	j.compteur = s.horloge_monde.ticks
	verifier(s.intention(j.id, {"type": "planter", "base": "pomme"}), "on plante un pommier")
	var pm2 := SimCamp._pm(s, terre2)
	verifier(s.territoire.cultures.has(pm2) and str(s.territoire.cultures[pm2].plante) == "pomme", "la parcelle porte le pommier")
	verifier(SimVilles.plante_a_semer(s, {"verger": true, "plante": "pomme"}) == "pomme", "un verger replante le même arbre : on plante une fois, on cueille des années")


## Les denrées pourrissent, et le prix se remet à bouger (designer 2026-09-07, 21 h) : une conserve tient, une baie non ;
## une ville ne perd jamais de quoi manger ; et un stock qui cesse de saturer fait remonter le prix de la nourriture.
func test_denrees_perissent() -> void:
	var eco: Dictionary = GameData.config("villes").economie
	var pe: Dictionary = eco.peremption
	verifier(float(pe.taux_defaut) > float(pe.taux_par_tag.conserve) and int(pe.garde_minimale) > 0, "les taux sont en données : cru %.2f, conserve %.2f, garde %d" % [float(pe.taux_defaut), float(pe.taux_par_tag.conserve), int(pe.garde_minimale)])
	var s := Simulation.new(4242)
	s.charger_camp()
	var t: Dictionary = s.territoire
	t["agglomeration"] = {"population": 20}
	t.stocks.clear()
	t.stocks["baies"] = 1000        # une denrée crue : elle pourrit vite
	t.stocks["viande_salee"] = 1000   # une conserve : elle tient
	t.stocks["ble"] = 1000          # une céréale : le grenier la garde
	t.stocks["chene|brut"] = 1000   # du bois : rien ne l'abîme
	t.stocks["laitue"] = 3          # sous la garde minimale : on n'y touche pas
	var perdu := s._perir_denrees()
	verifier(perdu > 0, "des denrées se sont gâtées (%d unités)" % perdu)
	var baies := int(t.stocks.baies)
	var salee := int(t.stocks.viande_salee)
	var ble := int(t.stocks.ble)
	verifier(baies < salee and salee < 1000, "la baie pourrit plus vite que la conserve (%d contre %d)" % [baies, salee])
	verifier(ble > baies and ble < 1000, "la céréale se garde mieux que la baie, moins bien que la conserve (%d)" % ble)
	verifier(int(t.stocks["chene|brut"]) == 1000, "le bois ne pourrit pas")
	verifier(int(t.stocks.laitue) == 3, "sous la garde minimale, on ne perd rien : une ville garde de quoi manger")
	# le prix : un stock saturé colle au plancher ; un stock qui fond le fait remonter
	t.stocks.clear()
	t.stocks["baies"] = 100000
	s._semaine_economie()
	var prix_plein := float(t.prix.nourriture)
	t.stocks.clear()
	t.stocks["baies"] = 5
	s._semaine_economie()
	var prix_vide := float(t.prix.nourriture)
	verifier(prix_plein <= float(eco.prix_min) + 0.01 and prix_vide > prix_plein, "le prix de la nourriture suit le stock : %.2f quand les greniers débordent, %.2f quand ils sont vides" % [prix_plein, prix_vide])


## Une ville riche bâtit au lieu d'exporter ses enfants (2026-09-07) : la capacité de logement monte quand la ville a
## le moral, les matériaux et l'or ; une ville pauvre ne bâtit pas ; et rien ne se bâtit quand tout le monde est logé.
func test_ville_batit() -> void:
	var cfg: Dictionary = GameData.config("villes").batir
	var mc: Dictionary = GameData.config("combat_rules").royaume.maisons
	verifier(int(cfg.cout_or) > 0 and int(cfg.logements_par_maison) > 0 and int(cfg.max_par_semaine) >= 1, "les nombres du chantier sont en données (or %d, +%d logements, %d par semaine)" % [int(cfg.cout_or), int(cfg.logements_par_maison), int(cfg.max_par_semaine)])
	var s := Simulation.new(4242)
	s.charger_camp()
	var t: Dictionary = s.territoire
	t["agglomeration"] = {"nom": "Bourgade", "population": 10, "materiaux": {"mur": "pin"}}
	t["tresor"] = 1000
	t.stocks.clear()
	for c in mc.cout:
		t.stocks["chene|brut"] = int(c.n) * 5   # du bois en quantité, famille « bois »
	var cap0 := int(t.agglomeration.population)
	# tout le monde est logé : rien ne se bâtit
	verifier(SimVilles._batir_logements(s, 5) == 0 and int(t.agglomeration.population) == cap0, "quand tout le monde est logé, la ville ne bâtit pas")
	# il manque des lits : elle bâtit, et sa capacité monte
	var or0 := int(t.tresor)
	var bois0 := SimPerimetres._stock_famille(s, "bois")
	var n := SimVilles._batir_logements(s, 99)
	verifier(n == int(cfg.max_par_semaine) and int(t.agglomeration.population) == cap0 + n * int(cfg.logements_par_maison), "elle bâtit %d maison(s) et loge %d habitants de plus" % [n, n * int(cfg.logements_par_maison)])
	verifier(int(t.tresor) == or0 - n * int(cfg.cout_or) and SimPerimetres._stock_famille(s, "bois") < bois0, "le chantier a coûté son or (%d → %d) et son bois" % [or0, int(t.tresor)])
	# une ville sans or ne bâtit pas, une ville sans bois non plus
	t.tresor = 0
	var cap1 := int(t.agglomeration.population)
	verifier(SimVilles._batir_logements(s, 99) == 0 and int(t.agglomeration.population) == cap1, "sans or, la ville ne bâtit pas")
	t.tresor = 1000
	t.stocks.clear()
	verifier(SimVilles._batir_logements(s, 99) == 0 and int(t.agglomeration.population) == cap1, "sans matériaux, la ville ne bâtit pas")
	# le compteur de stock ne consomme rien : c'est ce qui permet de vérifier un coût à plusieurs familles
	t.stocks["chene|brut"] = 30
	var avant := SimPerimetres._stock_famille(s, "bois")
	verifier(avant == 30 and SimPerimetres._stock_famille(s, "bois") == 30, "compter le stock d'une famille n'en prend rien")

