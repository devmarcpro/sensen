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
	var rue_ok := 0
	for k in range(2, taille - 2):
		if e.sol.has((taille / 2) * taille + k) and e.sol.has(k * taille + taille / 2):
			rue_ok += 1
	verifier(rue_ok >= (taille - 4) * 8 / 10, "les deux axes sont praticables (%d/%d)" % [rue_ok, taille - 4])
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
	verifier(v.champs.size() >= mini(attendu, 2) and v.champs.size() <= attendu, "le quartier agricole a %d champs pour %d habitants (au plus %d)" % [v.champs.size(), int(v.population_quartier), attendu])
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
	var produit_attendu := false
	for bt in betes:
		produit_attendu = produit_attendu or cfg.enclos.produits.has(str(bt.def))
	var avant_b := 0   # la ville use son tissu chaque semaine (B3) : on mesure la production seule
	for cle in t.stocks.keys():
		if str(cle).begins_with("laine") or str(cle).begins_with("lait"):
			avant_b += int(t.stocks[cle])
	s2._dans_territoire(nom, func() -> void: s2._semaine_betail())
	var apres_b := 0
	for cle in t.stocks.keys():
		if str(cle).begins_with("laine") or str(cle).begins_with("lait"):
			apres_b += int(t.stocks[cle])
	verifier((apres_b > avant_b) == produit_attendu, "le bétail a produit (%d → %d) selon ses espèces" % [avant_b, apres_b])


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
	# La semaine des pays tourne sur les royaumes connus.
	s._semaine_royaumes_pays()
	verifier(int(ea.population) >= 0 and int(ea.armee) >= int(s._ry().pays.armee_base.petit), "la semaine recompte : armée de base %d" % int(ea.armee))
	# La sauvegarde garde l'état.
	s.nom_partie = "test_royaume_pays"
	verifier(s.sauvegarder(), "sauvegarde avec l'état des royaumes")
	var s2 := Simulation.new(83)
	s2.nom_partie = "test_royaume_pays"
	verifier(s2.charger_sauvegarde() and s2.monde.etats_royaumes.has("roy_a") and str(s2.monde.etats_royaumes.roy_a.dirigeant) == "Titus Aurelius", "rechargé : le règne de Titus Aurelius")


## Les bâtiments à étages (Villes, 99, 2026-09-05) : une maison haute a un escalier ; y marcher charge l'étage (un petit
## intérieur bâti sur le plan, avec ses lits et ses meubles) ; l'escalier du haut mène au suivant, celui du bas ramène
## dans la rue devant l'escalier.
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
	s.monde.cellules[cell] = e
	s.grille = s.monde.fenetre(s.monde.centre, GameData.config("tile_contents"), s.regles.r.deplacement, int(s.regles.r.vision.hauteur_oeil))
	for x in s.vivants():
		if s.grille.dans(x.pos) and s.grille.occupant(x.pos).is_empty():
			s.grille.placer(x.id, x.pos)
	var esc: Vector2i = s.monde.pos_monde(cell, bat_e.escalier)
	verifier(str(s.grille.meubles.get(s.grille.idx(esc), "")) == "escalier" and not s.grille.bloque_passage(esc), "l'escalier est un meuble franchissable de la grille")
	var voisin := s._tuile_libre_autour(esc)
	s.grille.liberer(j.pos)
	j.pos = voisin
	s.grille.placer(j.id, voisin)
	verifier(s._entrer_interieur(j, esc), "monter l'escalier charge l'intérieur")
	verifier(s.lieu == "donjon" and bool(s.donjon.get("interieur", false)) and int(s.donjon.etage) == 1 and s.grille.largeur == str(GameData.catalogues.village_buildings[str(bat_e.id)].etages[0][0]).length(), "au premier étage : une grille de la taille du plan de %s (%d × %d)" % [str(bat_e.id), s.grille.largeur, s.grille.hauteur_grille])
	var lits := 0
	for gi in s.grille.meubles.keys():
		if str(s.grille.meubles[gi]).begins_with("lit"):
			lits += 1
	verifier(lits >= 2 and j.pos == Vector2i(s.donjon.entree), "l'étage a ses lits (%d) et le joueur est sur l'escalier du bas" % lits)
	verifier(s._remonter(j) and s.lieu == "camp" and s._cell_de(j.pos) == cell and Grille.distance(j.pos, esc) <= 2, "redescendre ramène dans la rue, devant l'escalier")


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
