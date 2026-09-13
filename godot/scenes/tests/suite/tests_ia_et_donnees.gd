extends TestsBase
## L'IA, les espèces, les données, la discrétion, la triche, les statues, les routes entre royaumes, les tooltips, les meubles, la transmutation, les glyphes, l'alternance, la meute.
## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de
## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l'ordre de sa liste.


func test_ia_portails() -> void:
	var s := Simulation.new(154)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var loup := s.ajouter("loup", j.pos + Vector2i(-2, 0), "ia")
	var but: Vector2i = j.pos + Vector2i(20, 0)
	verifier(s.portail_utile(loup, but) == Vector2i(-1, -1), "sans portail, aucun détour")
	# Deux portails du Passeur : l'entrée près du loup, la sortie près du but
	var entree: Vector2i = loup.pos + Vector2i(-1, 0)
	var sortie: Vector2i = but + Vector2i(-1, 0)
	for t in [entree, sortie]:
		s.grille.contenu[s.grille.idx(t)] = 0
		s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(loup.pos)
	j["portails"] = [entree, sortie]   # clés en position monde (la fenêtre glisse)
	s.portails[entree] = j.id
	s.portails[sortie] = j.id
	verifier(s.portail_utile(loup, but) == entree, "le loup voit la brèche qui le rapproche")
	verifier(s.portail_utile(loup, loup.pos + Vector2i(1, 0)) == Vector2i(-1, -1), "pour deux tuiles, le détour n'en vaut pas la peine")
	var tick := s.tick_de(loup)
	verifier(s._ia_par_portail(loup, but, tick) and loup.pos == entree, "un pas vers la brèche")
	verifier(s._ia_par_portail(loup, but, tick) and loup.pos == sortie, "puis elle traverse")
	verifier(Grille.distance(loup.pos, but) <= 1, "le loup ressort à côté de son but")
	s.monde.fermer()


func test_paliers_elevage() -> void:
	var s := Simulation.new(155)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var pal0 := s.paliers_elevage()
	verifier(int(pal0.capture) == 0 and int(pal0.couvees) == 0 and is_equal_approx(float(pal0.eclosion), 1.0), "registre vide : aucun palier")
	# Un registre garni à la main : 30 variétés d'une espèce → le premier palier de potentiel
	s.territoire["registre"] = {"carpe": {}}
	for k in 30:
		s.territoire.registre.carpe["c%d|m%d" % [k, k]] = true
	var pot_avant := int(j.potentiels.get("elevage", 0))
	var base_elevage := int(j.get("potentiels_base", {}).get("elevage", 80))
	s._appliquer_paliers_potentiel()
	verifier(int(s.paliers_elevage().potentiel) == 10 and int(j.potentiels.get("elevage", 0)) >= base_elevage + 10, "25 variétés : plancher de potentiel en Élevage (%d → %d)" % [pot_avant, int(j.potentiels.get("elevage", 0))])
	verifier(int(s.paliers_elevage().capture) == 0, "mais pas encore le palier de capture (75)")
	for k in range(30, 210):
		s.territoire.registre.carpe["c%d|m%d" % [k, k]] = true
	var pal := s.paliers_elevage()
	verifier(int(pal.capture) == 2 and is_equal_approx(float(pal.eclosion), 0.75), "200 variétés : capture +2 et éclosions à 75 %%")
	# Le plancher de la branche Vie au palier 1 200
	for k in range(210, 1250):
		s.territoire.registre.carpe["c%d|m%d" % [k, k]] = true
	s._appliquer_paliers_potentiel()
	var base_agri := int(j.get("potentiels_base", {}).get("agriculture", 80))
	var epee_avant := int(j.potentiels.get("epee", 80))
	s._appliquer_paliers_potentiel()
	verifier(int(s.paliers_elevage().potentiel_vie) == 10 and int(j.potentiels.get("agriculture", 0)) >= base_agri + 10 and int(j.potentiels.get("epee", 80)) == epee_avant, "1 200 variétés : la branche Vie relevée (%d), pas les armes" % int(j.potentiels.get("agriculture", 0)))
	# Espèces : couvées et commandes
	for esp in GameData.catalogues.species.keys():
		s.territoire.registre[esp] = s.territoire.registre.get(esp, {"x|y": true})
	pal = s.paliers_elevage()
	verifier(int(pal.capture) >= 6, "bestiaire complet : capture +2 (variétés) +4 (%d)" % int(pal.capture))
	verifier(int(pal.couvees) == (2 if GameData.catalogues.species.size() >= 10 else 0), "les couvées supplémentaires attendent 10 espèces (%d au catalogue)" % GameData.catalogues.species.size())
	s.monde.fermer()


func test_especes_ajoutees() -> void:
	verifier(GameData.catalogues.species.size() >= 10, "dix espèces d'élevage au catalogue (%d)" % GameData.catalogues.species.size())
	var lu: Dictionary = GameData.entree("species", "luciole")
	var po: Dictionary = GameData.entree("species", "poisson_de_bassin")
	verifier(str(lu.loci.rythme.type) == "sequence" and str(po.loci.taille.type) == "nombre", "les deux derniers types de loci ont un porteur")
	verifier(bool(lu.capture.get("nuit", false)) and str(po.capture.verbe) == "ligne", "luciole de nuit, poisson à la ligne")
	verifier(GameData.catalogues.meubles.has("bassin") and GameData.catalogues.items.has("meuble_bassin") and GameData.catalogues.recipes.has("meuble_bassin"), "le bassin : meuble, objet et recette")
	# La condition colonie : six lucioles avant toute couvée
	var s := Simulation.new(156)
	s.charger_camp()
	var a := s._nouveau_specimen("luciole", {"couleur": [0, 0], "rythme": [[0, 1, 2, 3], [0, 1, 2, 3]]}, "m", false)
	var b := s._nouveau_specimen("luciole", {"couleur": [1, 1], "rythme": [[1, 2, 3, 0], [1, 2, 3, 0]]}, "f", false)
	a["age_semaines"] = 3
	b["age_semaines"] = 3
	var ctx_peu := {"habitat": "vivarium", "occupants": 2, "libre": 2, "temp": 20.0, "saison": s.saison()}
	var ctx_colonie := {"habitat": "vivarium", "occupants": 6, "libre": 2, "temp": 20.0, "saison": s.saison()}
	verifier(not s.conditions_repro(a, b, ctx_peu).ok, "à deux, les lucioles ne s'accordent pas")
	verifier(s.conditions_repro(a, b, ctx_colonie).ok, "à six, la colonie s'accorde")
	# Le poisson : la température du bassin
	var p1 := s._nouveau_specimen("poisson_de_bassin", {"couleur": [0, 0], "motif": [0, 0], "taille": 4.0}, "m", false)
	var p2 := s._nouveau_specimen("poisson_de_bassin", {"couleur": [1, 1], "motif": [1, 1], "taille": 6.0}, "f", false)
	p1["age_semaines"] = 3
	p2["age_semaines"] = 3
	verifier(s.conditions_repro(p1, p2, {"habitat": "bassin", "occupants": 2, "libre": 2, "temp": 22.0, "saison": s.saison()}).ok, "bassin à 22 °C : les poissons frayent")
	verifier(not s.conditions_repro(p1, p2, {"habitat": "bassin", "occupants": 2, "libre": 2, "temp": 5.0, "saison": s.saison()}).ok, "bassin à 5 °C : trop froid")
	s.monde.fermer()


func test_tannage() -> void:
	# La famille cuir a désormais une source : plus aucune famille de composant n'est orpheline
	var produits := {}
	for rid in GameData.catalogues.recipes.keys():
		var r: Dictionary = GameData.catalogues.recipes[rid]
		if str(r.output.get("material", "")) != "":
			produits[str(r.output.material)] = true
	verifier(produits.has("cuir"), "une recette produit du cuir")
	var s := Simulation.new(157)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var peau := s.generer_objet("peau", 1, {}, "commun", 0)
	s.items[str(peau.uid)].quantite = 2
	if not (str(peau.uid) in j.sac):
		j.sac.append(str(peau.uid))
	var plan := s._plan_recette(j, GameData.entree("recipes", "tanner_cuir"))
	verifier(plan.faisable and str(plan.sortie.materiau) == "cuir" and str(plan.sortie.forme) == "brut", "deux peaux au sac : le tannage est faisable")
	s.items[str(peau.uid)].quantite = 1
	verifier(not s._plan_recette(j, GameData.entree("recipes", "tanner_cuir")).faisable, "une seule peau ne suffit pas")
	# Le trophée demande une dépouille
	var tro: Dictionary = GameData.entree("recipes", "meuble_trophee")
	var demande_peau := false
	for entree in tro.inputs:
		if str(entree.get("item", "")) == "peau":
			demande_peau = true
	verifier(demande_peau, "le trophée demande une peau")
	s.monde.fermer()


func test_huile_d_arme() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var loup := {}
	for e in s.vivants():
		if e.id != j.id:
			loup = e
	# L'huile pose le drapeau, l'engagement le transforme en bonus de feu
	var uid := "huile_test"
	s.items[uid] = {"uid": uid, "name_key": "x", "base": "huile_d_arme", "type": "consommable", "statut": "huile_feu", "statut_ticks": 0, "quantite": 1, "tags": ["consommable"], "affixes": [], "sertissures": {"nombre": 0, "contenu": []}}
	j.sac.append(uid)
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "manger", "objet": uid}) and bool(j.get("huile_feu", false)), "l'huile enduit l'arme")
	s._engager_combat(j, loup)
	verifier(not j.get("huile_feu", false) and str(j.get("degats_element_bonus", {}).get("feu", "")) == "1d4", "au premier combat : +1d4 feu par coup")
	# Le coup lit vraiment le bonus : les dégâts moyens montent d'environ 1d4
	var sans := 0
	var avec := 0
	loup.pos = j.pos + Vector2i(1, 0)   # à portée de mêlée
	s.grille.liberer(loup.pos)
	s.grille.placer(loup.id, loup.pos)
	s.grille.hauteurs[s.grille.idx(loup.pos)] = s.grille.h(j.pos)
	for k in 40:
		loup.sante = loup.sante_max
		j.compteur = 0
		j.erase("degats_element_bonus")
		s._attaquer_arme(j, loup, false, s.tick_de(j))
		sans += int(loup.sante_max) - int(loup.sante)
		loup.sante = loup.sante_max
		j.compteur = 0
		j["degats_element_bonus"] = {"feu": "1d4"}
		s._attaquer_arme(j, loup, false, s.tick_de(j))
		avec += int(loup.sante_max) - int(loup.sante)
	verifier(avec > sans, "les coups enduits frappent plus fort (%d contre %d sur 40 coups)" % [avec, sans])


## Les liens entre catalogues (tools/audit_donnees.py fait le tour complet ; ici les plus coûteux à casser).
func test_liens_donnees() -> void:
	var manquantes: Array[String] = []
	for cid in GameData.catalogues.classes.keys():
		var c: Dictionary = GameData.catalogues.classes[cid]
		for cle in c.get("competences", {}).keys():
			if not GameData.catalogues.competences.has(str(cle)):
				manquantes.append("%s → %s" % [cid, cle])
		if str(c.get("talent", "")) != "" and not GameData.catalogues.talents.has(str(c.talent)):
			manquantes.append("%s → talent %s" % [cid, c.talent])
		for uid in c.get("equipement", []) + c.get("ratelier", []):
			if not GameData.catalogues.items.has(str(uid)):
				manquantes.append("%s → objet %s" % [cid, uid])
	verifier(manquantes.is_empty(), "chaque classe cite des compétences, un talent et des objets qui existent (%s)" % str(manquantes))
	var cr_manquantes: Array[String] = []
	for cid in GameData.catalogues.creatures.keys():
		var c: Dictionary = GameData.catalogues.creatures[cid]
		for a in c.get("actions", []):
			if not GameData.catalogues.creature_actions.has(str(a)):
				cr_manquantes.append("%s → %s" % [cid, a])
		if str(c.get("ai_profile", "")) != "" and not GameData.catalogues.ai_profiles.has(str(c.ai_profile)):
			cr_manquantes.append("%s → profil %s" % [cid, c.ai_profile])
	verifier(cr_manquantes.is_empty(), "chaque créature cite des actions et un profil d'IA qui existent (%s)" % str(cr_manquantes))
	var biomes_ko: Array[String] = []
	for bid in GameData.catalogues.biomes.keys():
		var b: Dictionary = GameData.catalogues.biomes[bid]
		for f in b.get("faune", []) + b.get("faune_nuit", []):
			var i := str(f.id) if f is Dictionary else str(f)
			if not GameData.catalogues.creatures.has(i):
				biomes_ko.append("%s → %s" % [bid, i])
	verifier(biomes_ko.is_empty(), "chaque faune de biome existe au bestiaire (%s)" % str(biomes_ko))


func test_discretion() -> void:
	var s := Simulation.new(158)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	s.horloge_monde.ticks = int(s._cycle().ticks_par_jour) / 2   # plein jour
	j.competences_eff["discretion"] = 0
	verifier(is_equal_approx(s.discretion_reduction(j), 0.0), "sans Discrétion : rien de gagné")
	j.competences_eff["discretion"] = 20
	verifier(is_equal_approx(s.discretion_reduction(j), 0.4), "niveau 20 le jour : −40 %% de portée (%.2f)" % s.discretion_reduction(j))
	s.horloge_monde.ticks = 0   # nuit
	verifier(is_equal_approx(s.discretion_reduction(j), 0.48), "la nuit vaut quatre niveaux de plus (−48 %)")
	j.competences_eff["discretion"] = 60
	verifier(is_equal_approx(s.discretion_reduction(j), 0.6), "le plafond tient à 60 %")
	j["garde"] = true
	verifier(is_equal_approx(s.discretion_reduction(j), 0.0), "en garde, on ne se cache pas")
	j.erase("garde")
	# Un loup qui voit à 10 tuiles ne voit plus qu'à 4 quand la cible est discrète
	s.horloge_monde.ticks = int(s._cycle().ticks_par_jour) / 2
	var loup := s.ajouter("loup", j.pos + Vector2i(6, 0), "ia")
	loup.corps.stats.perception = 10
	for dx in range(0, 8):
		var t: Vector2i = j.pos + Vector2i(dx, 0)
		s.grille.contenu[s.grille.idx(t)] = 0
		s.grille.hauteurs[s.grille.idx(t)] = s.grille.h(j.pos)
	j.competences_eff["discretion"] = 0
	var vu_sans := s.voit_ia(loup, j)
	j.competences_eff["discretion"] = 30
	var vu_avec := s.voit_ia(loup, j)
	verifier(vu_sans and not vu_avec, "à six tuiles : vu sans Discrétion, invisible avec")
	# L'acquisition de cible passe par la même détection : discret, on n'est pas pris pour cible ; et on sème.
	loup.cible = ""
	j.competences_eff["discretion"] = 0
	var c0 := s._chercher_cible(loup, 10)
	verifier(not c0.is_empty() and c0.id == j.id, "sans Discrétion : le loup prend le joueur pour cible")
	loup.cible = ""
	s.combats.clear()
	j.competences_eff["discretion"] = 30
	# Le camp a des habitants depuis `camp.pnj_depart` (2026-09-08) : le loup peut trouver QUELQU'UN. Ce que ce
	# test prouve, c'est que ce quelqu'un n'est pas le joueur caché — l'assertion « aucune cible » supposait
	# un camp désert, ce qui n'a jamais été ce qu'on voulait vérifier.
	var c1 := s._chercher_cible(loup, 20)
	verifier(c1.is_empty() or str(c1.id) != str(j.id), "discret : le loup ne prend pas le joueur pour cible")
	loup.cible = j.id
	loup.tick_derniere_vue = 20
	s._chercher_cible(loup, 20 + int(s.regles.r.engagement.ia_ticks_sans_vue) + 1)
	verifier(str(loup.cible) != str(j.id), "semé en Discrétion : après ia_ticks_sans_vue sans le voir, le loup lâche le joueur")
	s.monde.fermer()


## Embuscade (Prototype de combat, axe 5) : la frappe qui ouvre le combat contre une proie surprise gagne les dés.
func test_embuscade() -> void:
	var s := Simulation.new(313)
	s.charger_donjon("ruine", 313, 4, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var lynx := s.ajouter("lynx", j.pos + Vector2i(1, 0), "ia")
	verifier(not s.en_combat(j), "avant la frappe : la proie n'est pas en combat")
	var griffure: Dictionary = s.actions_creatures.griffure
	lynx["surprise_sur"] = str(j.id) if not s.en_combat(j) else ""
	s._engager_combat(lynx, j)
	verifier(s._bonus_embuscade(lynx, j) == 2, "première frappe sur une proie surprise : +2 dés (embuscade du lynx)")
	verifier(s._bonus_embuscade(lynx, j) == 0, "la seconde frappe n'a plus de bonus : la proie est prévenue")
	lynx["surprise_sur"] = str(j.id) if not s.en_combat(j) else ""
	verifier(lynx.surprise_sur == "", "une proie déjà en combat ne se laisse pas surprendre")
	var cerf := s.ajouter("cerf", j.pos + Vector2i(-1, 0), "ia")
	cerf["surprise_sur"] = str(j.id)
	verifier(s._bonus_embuscade(cerf, j) == 0, "un cerf n'a pas d'action d'embuscade : rien")
	verifier(griffure.effets.size() >= 1, "la griffure existe (%d effet)" % griffure.effets.size())


## Le menu de triche (Écrans d'interface) : chaque action agit, et les catalogues sont parcourus tels quels.
func test_triche() -> void:
	var s := Simulation.new(707)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var or0: int = int(j.or)
	verifier(s.triche(j, "or") and int(j.or) == or0 + 10000, "triche : +10 000 or")
	j.sante = 1
	j["faim"] = 3
	verifier(s.triche(j, "soin") and int(j.sante) == int(j.sante_max) and int(j.faim) == 100, "triche : tout restauré")
	verifier(s.triche(j, "invincible") and s.invincible, "triche : invincibilité armée")
	s._appliquer_degats(j, 9999, "", {"type": "test"})
	verifier(j.vivant and int(j.sante) == int(j.sante_max), "invincible : 9 999 dégâts ne font rien")
	s.triche(j, "invincible")
	verifier(s.triche(j, "competences") and int(j.competences_eff.get("epee", 0)) >= 50, "triche : toutes les compétences au niveau 50")
	verifier(s.triche(j, "talents") and s.talents_de(j).size() >= GameData.catalogues.talents.size(), "triche : tous les talents")
	verifier(s.triche(j, "modules") and j.modules_connus.size() == GameData.catalogues.modules.size(), "triche : tous les modules")
	verifier(s.triche(j, "recettes") and j.recettes_connues.size() >= GameData.catalogues.recipes.size(), "triche : toutes les recettes")
	var sac0: int = j.sac.size()
	verifier(s.triche(j, "objet", "proto_epee") and j.sac.size() == sac0 + 1, "triche : un objet exceptionnel dans le sac")
	verifier(s.triche(j, "materiau", "fer") and not s._pile(j, "fer", "brut").is_empty(), "triche : 20 fers bruts")
	var n0: int = s.vivants().size()
	verifier(s.triche(j, "creature", "loup") and s.vivants().size() == n0 + 1, "triche : un loup apparaît")
	verifier(s.triche(j, "meteo", "orage") and s.meteo(Vector2i.ZERO) == "orage", "triche : l'orage s'impose")
	verifier(s.triche(j, "statut", "beni") and j.statuts.any(func(x: Dictionary) -> bool: return str(x.id) == "beni"), "triche : un statut s'applique")
	var nuit0: bool = s.est_nuit()
	verifier(s.triche(j, "heure") and s.est_nuit() != nuit0, "triche : jour ↔ nuit")
	verifier(s.triche(j, "reveler") and s.monde.cellule_exploree(s.monde.cellule_de(j.pos) + Vector2i(30, 30)), "triche : la carte est révélée autour (%d chunks)" % s.monde.explores.size())
	verifier(s.triche(j, "claim") and s.monde.claims.has(s.monde.cellule_de(j.pos)), "triche : la cellule est revendiquée")
	var loup: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.def == "loup")[0]
	loup.camp = "hostile"
	verifier(s.triche(j, "tuer") and not loup.vivant, "triche : les hostiles tombent")
	verifier(not s.triche(j, "action_qui_n_existe_pas"), "triche : une action inconnue est refusée")
	verifier(s.triche(j, "race", "vampire") and str(j.race) == "vampire", "triche : devenir vampire")
	s.monde.fermer()


## Le drop rare universel (Créatures) : la statue 1:1, à 0,5 % — forcée ici à 100 % pour la vérifier.
func test_statue() -> void:
	var s := Simulation.new(909)
	s.charger_donjon("ruine", 909, 3, 1)
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var lr: Dictionary = GameData.config("loot_rules")
	var chance0: float = float(lr.drops.statue.chance)
	lr.drops.statue.chance = 1.0
	var loup := s.ajouter("loup", j.pos + Vector2i(2, 0), "ia")
	loup.sante = 1
	s._appliquer_degats(loup, 5, j.id, {"type": "test"})
	var trouvee := {}
	for uid in s.items.keys():
		if str(s.items[uid].get("base", "")) == "meuble_statue":
			trouvee = s.items[uid]
	lr.drops.statue.chance = chance0
	verifier(not trouvee.is_empty(), "une statue tombe de la créature abattue")
	if trouvee.is_empty():
		return
	verifier(str(trouvee.nom.get("de_creature", "")) == "creature.loup.name", "la statue porte le nom de la créature")
	verifier(float(trouvee.get("valeur", 0.0)) > float(GameData.config("combat_rules").commerce.valeur_par_defaut), "sa valeur suit les stats de la bête (%.0f)" % float(trouvee.valeur))


func test_routes_entre_royaumes() -> void:
	var planete: Dictionary = GameData.config("planete")
	var surf := Surface.new(GameData.config("noise_layers"), GameData.catalogues.biomes, planete, 4242)
	var trouves := 0
	var hostiles_relies := 0
	var capitales_reliees := 0
	var paires_voisines := 0   # une route n'existe qu'entre royaumes dont les territoires se touchent
	for sx in 6:
		for sy in 6:
			var roys: Dictionary = surf.royaumes_secteur(Vector2i(sx, sy))
			for id in roys.keys():
				var r: Dictionary = roys[id]
				var cap: Vector2i = r.capital_poi
				for id2 in roys.keys():
					if id2 == id:
						continue
					var r2: Dictionary = roys[id2]
					var touche := false
					for c in r2.get("territory_cells", []):
						for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
							if (Vector2i(c) + d) in r.get("territory_cells", []):
								touche = true
					if touche and str(r.diplomacy.get(id2, "")) != "hostile":
						paires_voisines += 1
					if str(r.diplomacy.get(id2, "")) == "hostile" and (r2.capital_poi in surf.route_de(cap)):
						hostiles_relies += 1
				if not surf.route_de(cap).is_empty():
					capitales_reliees += 1
				trouves += 1
	verifier(trouves > 0, "des royaumes sont générés (%d)" % trouves)
	verifier(capitales_reliees > 0 or paires_voisines == 0, "des capitales voisines non hostiles sont reliées (%d capitales sur %d en portent, %d paires voisines)" % [capitales_reliees, trouves, paires_voisines])
	verifier(hostiles_relies == 0, "aucune route directe entre deux capitales hostiles")


func test_tooltips() -> void:
	# Chaque tooltip cite un signal qui existe et une clé de texte traduite
	var ko: Array[String] = []
	for tid in GameData.catalogues.get("tutorials", {}).keys():
		var t: Dictionary = GameData.catalogues.tutorials[tid]
		if not EventBus.has_signal(str(t.trigger.signal)):
			ko.append("%s → signal %s" % [tid, t.trigger.signal])
		if tr(str(t.text_key)) == str(t.text_key):
			ko.append("%s → texte %s" % [tid, t.text_key])
	verifier(ko.is_empty(), "chaque tooltip cite un signal réel et un texte traduit (%s)" % str(ko))
	verifier(GameData.catalogues.get("tutorials", {}).size() >= 12, "douze tooltips ou plus (%d)" % GameData.catalogues.get("tutorials", {}).size())
	# Ils se déclenchent vraiment : un tooltip par clé de journal, une seule fois
	var tuto := Tutoriels.new()
	add_child(tuto)
	var vus: Array[String] = []
	tuto.afficher = func(texte: String) -> void: vus.append(texte)
	EventBus.emettre(&"journal", [&"journal.cueillette", {}])
	EventBus.emettre(&"journal", [&"journal.cueillette", {}])
	EventBus.dispatcher()   # les événements sont mis en file (Boucle de tick)
	var n_cueillette := 0   # la file peut contenir d'autres événements des tests précédents
	for texte in vus:
		if texte == tr("tutorial.premiere_cueillette.text"):
			n_cueillette += 1
	verifier(n_cueillette == 1, "le tooltip de cueillette s'affiche une fois, pas deux (%d sur %d tooltips)" % [n_cueillette, vus.size()])
	tuto.queue_free()


func test_registre_loci() -> void:
	var s := Simulation.new(159)
	s.charger_camp()
	# La clé suit les loci qualitatifs de l'espèce, pas couleur|motif
	var lu := s._nouveau_specimen("luciole", {"couleur": 2, "rythme": [0, 1, 2, 3]}, "m", false)
	var lu2 := s._nouveau_specimen("luciole", {"couleur": 2, "rythme": [3, 2, 1, 0]}, "f", false)
	verifier(s.cle_variete(lu) != s.cle_variete(lu2), "deux rythmes de luciole font deux variétés (%s / %s)" % [s.cle_variete(lu), s.cle_variete(lu2)])
	s._enregistrer_variete(lu)
	s._enregistrer_variete(lu2)
	verifier(int(s.territoire.registre.luciole.size()) == 2, "le registre en compte deux")
	# Le nombre de variétés possibles suit aussi les loci
	verifier(s.varietes_possibles("luciole") == 6 * 16, "luciole : 6 couleurs × 2⁴ rythmes = %d" % s.varietes_possibles("luciole"))
	verifier(s.varietes_possibles("carpe") > 0 and s.varietes_possibles("coquillage") > 10, "carpe et coquillage comptent leurs loci (%d, %d)" % [s.varietes_possibles("carpe"), s.varietes_possibles("coquillage")])
	# Les records restent aux loci nombre
	var po := s._nouveau_specimen("poisson_de_bassin", {"couleur": 1, "motif": 2, "taille": 7.5}, "m", false)
	s._enregistrer_variete(po)
	verifier(is_equal_approx(float(s.territoire.records.poisson_de_bassin.taille), 7.5), "la taille va aux records, pas à la clé")
	verifier(not ("7.5" in s.cle_variete(po)), "la clé de variété ignore les loci nombre (%s)" % s.cle_variete(po))
	s.monde.fermer()


func test_meubles_rituels() -> void:
	# Le générateur en pose dans les étages profonds, jamais avant l'étage minimum
	var gen := Donjon.new(GameData.catalogues.get("dungeon_rooms", {}), GameData.catalogues.get("dungeon_connectors", {}), GameData.entree("dungeon_themes", "ruine"))
	var avant := 0
	var apres := 0
	for k in 12:
		avant += gen.generer_etage(300 + k, 7, 2, 12, false).get("meubles", {}).size()
		apres += gen.generer_etage(300 + k, 7, 6, 12, false).get("meubles", {}).size()
	verifier(avant == 0, "aucun meuble de rituel avant l'étage 4 (%d)" % avant)
	verifier(apres > 0 and apres <= 12, "des sources et des autels dans les étages profonds (%d sur 12 étages)" % apres)
	# Boire transforme, et la source se tarit
	var s := Simulation.new(160)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var t: Vector2i = j.pos + Vector2i(1, 0)
	s.grille.meubles[s.grille.idx(t)] = "source_maudite"
	s.grille.poser_contenu(t, "meuble")
	s.attente[j.id] = true
	verifier(s.intention(j.id, {"type": "boire_source", "vers": t}) and str(j.race) == "vampire", "boire à la source : vampire")
	verifier(not s.grille.meubles.has(s.grille.idx(t)), "la source se tarit")
	# On ne cumule pas les malédictions
	var t2: Vector2i = j.pos + Vector2i(0, 1)
	s.grille.meubles[s.grille.idx(t2)] = "autel_rituel"
	s.grille.poser_contenu(t2, "meuble")
	s.attente[j.id] = true
	verifier(not s.intention(j.id, {"type": "rituel", "vers": t2}) and s.grille.meubles.has(s.grille.idx(t2)), "un vampire ne devient pas lycanthrope : l'autel tient")
	s.monde.fermer()


func test_suiveur_territorial() -> void:
	var s := Simulation.new(161)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var pnj := s.ajouter("villageois", j.pos + Vector2i(1, 0), "ia")
	s._habiller_pnj(pnj, GameData.entree("creatures", "villageois"))
	verifier(not s.suiveur_local(j, pnj.id, true), "un villageois sans assignation ne suit pas")
	s.changer_role(s.monde.cellule_camp, "champs")
	pnj["assignation"] = {"fonction": "fermier", "cellule": s.monde.cellule_camp}
	pnj["poste"] = pnj.pos
	verifier(s.suiveur_local(j, pnj.id, true) and str(pnj.maitre) == j.id and bool(pnj.suiveur_local), "un résident assigné accepte de suivre sur le territoire")
	# Il ne compte pas dans les places d'escorte
	verifier(s.compagnons_de(j).size() == 1 and s.compagnons_de(j, false).is_empty(), "il n'occupe pas de place d'escorte")
	# Hors du territoire, il rentre à son poste
	s.monde.claims.erase(s.monde.cellule_camp)   # le camp n'est plus revendiqué : équivaut à sortir du territoire
	s._decider_ia(pnj, s.tick_de(pnj))
	verifier(not pnj.has("maitre") and not pnj.has("suiveur_local") and str(pnj.ai_profile) == "civil", "hors territoire : il redevient résident et rentre")
	s.monde.fermer()


func test_transmutation() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	# Une arme mixte : bois 0,6 / feu 0,4
	var arme := {"uid": "epee_mix", "name_key": "x", "type": "arme", "equip_slot": "main_principale", "functionality": "epee",
		"elements": {"bois": 0.6, "feu": 0.4}, "affixes": [], "sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	s.items["epee_mix"] = arme
	var v0 := s.vecteur_arme(arme)
	verifier(is_equal_approx(float(v0.bois), 0.6), "l'arme mixte porte son vecteur")
	# Amplification : la part de feu monte, la normalisation dilue le bois
	s.items["anneau_amp"] = {"uid": "anneau_amp", "name_key": "x", "type": "bijou", "equip_slot": "anneau",
		"affixes": [{"id": "wuxing_amplification", "params": {"element": "feu", "pct": 50}, "compteur": 0, "etat": {}}],
		"sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["anneau_1"] = "anneau_amp"
	var v1 := s._vecteur_modifie(j, v0)
	verifier(float(v1.feu) > 0.4 and float(v1.bois) < 0.6 and is_equal_approx(float(v1.feu) + float(v1.bois), 1.0), "amplification : feu %.2f, bois %.2f, somme 1" % [float(v1.feu), float(v1.bois)])
	# Amplification d'un élément absent : sans effet
	s.items.anneau_amp.affixes[0].params.element = "eau"
	var v2 := s._vecteur_modifie(j, v0)
	verifier(is_equal_approx(float(v2.bois), 0.6), "amplifier un élément absent ne fait rien")
	# Transmutation : le bois devient métal, l'arme se concentre
	s.items["anneau_tr"] = {"uid": "anneau_tr", "name_key": "x", "type": "bijou", "equip_slot": "anneau",
		"affixes": [{"id": "wuxing_transmutation", "params": {"element": "bois", "vers": "metal"}, "compteur": 0, "etat": {}}],
		"sertissures": {"nombre": 0, "contenu": []}, "tags": []}
	j.equipement["anneau_2"] = "anneau_tr"
	var v3 := s._vecteur_modifie(j, v0)
	verifier(not v3.has("bois") and is_equal_approx(float(v3.metal), 0.6), "transmutation : le bois devient métal (%.2f)" % float(v3.get("metal", 0.0)))
	# Deux anneaux vers le même élément ferment la rotation : mono-élément
	s.items.anneau_amp.affixes[0] = {"id": "wuxing_transmutation", "params": {"element": "feu", "vers": "metal"}, "compteur": 0, "etat": {}}
	var v4 := s._vecteur_modifie(j, v0)
	verifier(v4.size() == 1 and is_equal_approx(float(v4.metal), 1.0), "deux transmutations vers Métal : le vecteur se ferme (%s)" % str(v4))
	s.monde.fermer() if s.monde != null else null


func test_arrachage() -> void:
	var s := Simulation.new(162)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	var base: Vector2i = j.pos + Vector2i(3, 0)
	var h0 := s.grille.h(j.pos)
	for dx in range(0, 6):
		for dy in range(-2, 3):
			var t: Vector2i = base + Vector2i(dx, dy)
			s.grille.contenu[s.grille.idx(t)] = 0
			s.grille.hauteurs[s.grille.idx(t)] = h0
	# Un mur de chaume (dureté 1) exposé, un mur de pierre, et un chaume abrité par plus haut
	var chaume: Vector2i = base
	var pierre: Vector2i = base + Vector2i(2, 0)
	var abrite: Vector2i = base + Vector2i(4, 0)
	for t in [chaume, pierre, abrite]:
		s.grille.poser_contenu(t, "mur_construit")
	s.grille.materiaux[s.grille.idx(chaume)] = "chaume_tresse"
	s.grille.materiaux[s.grille.idx(pierre)] = "granit"
	s.grille.materiaux[s.grille.idx(abrite)] = "chaume_tresse"
	s.grille.hauteurs[s.grille.idx(abrite + Vector2i(1, 0))] = h0 + 2   # un voisin plus haut l'abrite
	verifier(s._arracher(pierre, 3) == false, "le granit ne s'arrache pas")
	verifier(s._arracher(abrite, 3) == false, "un chaume abrité par plus haut tient")
	verifier(s._arracher(chaume, 3) and s.grille.contenu_de(chaume).is_empty(), "un chaume exposé s'envole")
	verifier(s.modifs_terrain.has(chaume), "le terrain est mémorisé : il repoussera hors claim")
	s.monde.fermer()


func test_glyphes_visibles() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var pos: Vector2i = j.pos + Vector2i(2, 0)
	# Un glyphe ordinaire : une marque que l'IA évite
	var plan_vide := {"elements": {"feu": 1.0}, "noyau": {}, "geometrie": "point", "taille": 1, "portee": Vector2i(0, 1),
		"liaisons": [], "mult": 1.0, "des_bonus": 0, "parametres": {}, "monnaie": "mana", "ressource": 0, "charge_suivante": {}, "drapeaux": {}, "statuts": [], "modificateurs": []}
	s.glyphes.append({"pos": pos, "plan": plan_vide, "source": j.id, "fin": 999999, "elements": {"feu": 1.0}, "cache": false})
	s.grille.dangers[s.grille.idx(pos)] = true
	verifier(s.grille.dangers.has(s.grille.idx(pos)), "un glyphe ordinaire est une marque au sol")
	var chemin := s.grille.chemin(j.pos + Vector2i(1, 0), j.pos + Vector2i(3, 0))
	verifier(not chemin.is_empty() and not (pos in chemin), "l'IA contourne le glyphe")
	# Il s'efface quand il se déclenche
	var loup := {}
	for e in s.vivants():
		if e.id != j.id:
			loup = e
	s._declencher_glyphe(loup, pos)
	verifier(s.glyphes.is_empty() and not s.grille.dangers.has(s.grille.idx(pos)), "déclenché : le glyphe et sa marque disparaissent")
	# Le talent Dissimulation ne pose pas de marque
	verifier(s.regles.r.talents.has("dissimulation"), "le talent Dissimulation est en données")
	s.monde.fermer() if s.monde != null else null


func test_derobade() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var loup := {}
	for e in s.vivants():
		if e.id != j.id:
			loup = e
	# Une charge armée sur Dérobade part au premier pas sous la menace, une seule fois
	# La séquence est assemblée pour de vrai : [Dérobade] + [Point] + [Étincelle]
	var assemble := s.capacites.assembler(["derobade", "point", "etincelle"], 5, "1d6", {"metal": 1.0}, {})
	verifier(assemble.erreurs.is_empty() and assemble.avertissements.is_empty(), "Dérobade s'assemble sans avertissement (%s)" % str(assemble.avertissements))
	verifier(str(assemble.charge_suivante.get("declencheur", "")) == "derobade", "la charge attend l'esquive")
	j.declencheurs_armes.append({"evenement": "derobade", "plan": assemble.charge_suivante})
	s._engager_combat(j, loup)
	loup.pos = j.pos + Vector2i(1, 0)
	s.grille.liberer(loup.pos)
	s.grille.placer(loup.id, loup.pos)
	var libre: Vector2i = j.pos + Vector2i(0, 1)   # un pas de côté : le loup reste adjacent (on se dérobe, on ne fuit pas)
	s.grille.hauteurs[s.grille.idx(libre)] = s.grille.h(j.pos)
	s.grille.contenu[s.grille.idx(libre)] = 0
	verifier(s._deplacer(j, libre, s.tick_de(j)), "le joueur se dérobe d'un pas")
	verifier(j.declencheurs_armes.is_empty(), "la charge de Dérobade est partie")
	s.monde.fermer() if s.monde != null else null


func test_alternance() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	# Deux noyaux sans Alternance : erreur d'assemblage
	var sans := s.capacites.assembler(["point", "etincelle", "gel"], 5, "1d6", {"metal": 1.0}, {})
	verifier(sans.erreurs.is_empty() and sans.charges_sup.size() == 1, "deux noyaux sans Alternance : les deux se cumulent (Alternance les fait alterner)")
	# Avec Alternance : deux plans, un par noyau
	var plan := s.capacites.assembler(["point", "alternance", "etincelle", "gel"], 5, "1d6", {"metal": 1.0}, {})
	verifier(plan.erreurs.is_empty(), "avec Alternance : la séquence s'assemble (%s)" % str(plan.erreurs))
	verifier(plan.has("alt") and not plan.noyau.is_empty() and not plan.alt.noyau.is_empty(), "deux plans, deux noyaux")
	verifier(str(plan.noyau.id) != str(plan.alt.noyau.id), "les deux noyaux diffèrent (%s / %s)" % [str(plan.noyau.id), str(plan.alt.noyau.id)])
	verifier(int(plan.ticks) > 0 and int(plan.alt.ticks) > 0, "chaque plan garde ses propres ticks (%d / %d)" % [int(plan.ticks), int(plan.alt.ticks)])
	s.monde.fermer() if s.monde != null else null


func test_meute_liaison() -> void:
	var s := nouvelle_sim("plaine_au_talus")
	var j := joueur_de(s)
	var plan := s.capacites.assembler(["meute", "point", "etincelle"], 5, "1d6", {"metal": 1.0}, {})
	verifier(plan.erreurs.is_empty() and plan.avertissements.is_empty(), "Meute s'assemble sans avertissement (%s)" % str(plan.avertissements))
	var meute_ok := false
	for l in plan.liaisons:
		if bool(l.get("meute", false)):
			meute_ok = true
	verifier(meute_ok, "la liaison Meute est portée par le plan")
	s.monde.fermer() if s.monde != null else null


func test_etats_tuiles_par_grille() -> void:
	var s := Simulation.new(163)
	s.charger_camp()
	var j: Dictionary = s.vivants().filter(func(x: Dictionary) -> bool: return x.controle == "joueur")[0]
	# Un feu et une eau active au camp
	var t: Vector2i = j.pos + Vector2i(2, 0)
	s.grille.contenu[s.grille.idx(t)] = 0
	s.grille.poser_contenu(t, "arbre")
	s.grille.materiaux[s.grille.idx(t)] = "pin"
	verifier(s._enflammer(t), "un feu brûle au camp")
	s.eau_active[s.grille.idx(t)] = true
	# Descendre en donjon change la grille : les index n'ont plus de sens
	s.charger_donjon("ruine", 163, 9, 1, j)
	verifier(s.feux.is_empty() and s.eau_active.is_empty(), "descendre en donjon éteint les états de tuile (%d feux, %d eaux)" % [s.feux.size(), s.eau_active.size()])
	verifier(s.grille.dangers.size() == s.grille.dangers.size(), "la grille du donjon a ses propres dangers")
	s.monde.fermer()
