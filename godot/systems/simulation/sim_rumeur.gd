class_name SimRumeur
extends RefCounted
## LA RUMEUR QUI CIRCULE, ET LES FACTIONS QUI L'ÉCOUTENT (ordre de travail 29 et 29 bis ; designer 2026-09-08 :
## « réputation par factions, une faction par espèce »).
##
## **Les deux lignes sont un seul système**, et la file le disait : *elle transporte le fait, la faction décide qui
## s'en offusque*. Écrire l'une sans l'autre, c'est un champ qui ne mène nulle part, ou des valeurs que rien
## n'alimente.
##
## **LE DESSIN TIENT EN UNE PHRASE** : un acte laisse un **fait tagué** ; le fait **met du temps** à parcourir la
## carte ; la réputation d'une faction envers quelqu'un est la **somme de ce que ses valeurs pensent des faits
## qu'elle connaît**.
##
## **RIEN NE SE PROPAGE, ET C'EST CE QUI REND LE SYSTÈME GRATUIT.** Un observateur à `d` cellules du fait le sait à
## partir de `fait.tick + d × ticks_par_cellule` : on le **déduit**, exactement comme le stade d'une dépouille se
## déduit de l'heure de la mort. Aucune boucle ne colporte, aucun état ne s'accumule, et **la réputation n'est jamais
## comptée deux fois** — elle est une *fonction* des faits connus, pas un compteur qu'on incrémente. Elle s'efface
## donc toute seule quand les faits vieillissent, ce qui est exactement ce qu'on attend d'une rancune.
##
## **UNE ESPÈCE EST UNE FACTION, sans un fichier de plus** : tout acte contre une bête porte le tag `espece:<id>`, et
## la faction implicite de cette espèce ne value que ce tag-là. Chasser les cerfs jusqu'au dernier fâche donc les
## cerfs — et personne d'autre, sauf ceux dont les valeurs disent que le sang versé compte.
##
## Ce qu'il ne fait PAS : changer une relation ENTRE royaumes (`Surface._lier_royaumes` reste une fonction pure de la
## graine). C'est la suite naturelle, et elle demande que les royaumes portent des valeurs comme les factions.


static func _cfg() -> Dictionary:
	return GameData.config("rumeur")


## UN ACTE LAISSE UN FAIT. `tags_extra` porte ce que le code seul sait — l'espèce de la bête, par exemple.
## Rien n'est jugé ici : on note ce qui s'est passé, et les valeurs des factions décideront.
## Rend l'id du témoin (« public » pour un acte que le monde apprend de toute façon), ou "" si personne n'a rien vu.
## `temoin_impose` : un témoin déjà cherché pour le même acte (« » s'il n'y en avait pas) — on ne relance pas les dés.
static func rapporter(sim: Simulation, auteur: Dictionary, acte: String, pos: Vector2i, tags_extra: Array = [], temoin_impose: String = "?") -> String:
	var cfg := _cfg()
	if cfg.is_empty() or auteur.is_empty() or sim.monde == null:
		return ""
	var tags: Array = (sim.regles.r.get("faits", {}).get("actes", {}) as Dictionary).get(acte, []).duplicate()
	if tags.is_empty() and tags_extra.is_empty():
		return ""
	# LE TÉMOIN (ordre de travail 29 quinquies) : sans quelqu'un qui a vu, il n'y a pas de fait — seulement un acte.
	var tc: Dictionary = cfg.get("temoin", {})
	var temoin_id := ""
	if bool(tc.get("requis", false)) and not (acte in tc.get("actes_publics", [])):
		if temoin_impose != "?":
			if temoin_impose.is_empty():
				return ""
			temoin_id = temoin_impose
		else:
			var t := temoin_de(sim, auteur, pos, int(tc.get("portee", 12)))
			if t.is_empty():
				return ""
			temoin_id = str(t.id)
	tags.append_array(tags_extra)
	var faits: Array = sim.monde.faits
	faits.append({
		"auteur": str(auteur.id), "acte": acte, "tags": tags,
		"cellule": sim.monde.cellule_de(pos), "tick": sim.horloge_monde.ticks,
		"gravite": float((cfg.get("gravite", {}) as Dictionary).get(acte, 0.5)),
		"temoin": temoin_id,
	})
	# LE SEUL OUBLI QUI SOIT UN CHOIX : au-delà du plafond, le plus ancien tombe. Tout le reste s'efface par la
	# fraîcheur, sans qu'une ligne l'efface.
	var plafond := int(cfg.get("faits_max", 240))
	while faits.size() > plafond:
		faits.remove_at(0)
	return temoin_id if not temoin_id.is_empty() else "public"


## L'ABSENCE QUI SE REMARQUE ET LE CORPS QUI SENT (ordre de travail 29 quinquies). Une passe par heure du monde sur les
## habitants morts sans témoin : trouvé (vu ou senti), le corps est enterré et la ville porte le deuil — sans savoir qui ;
## pas encore trouvé, son absence pèse sur ses proches au bout d'un jour, sur sa ville au bout d'une semaine. Tout se lit
## sur `mort_tick` : un corps caché ne coûte rien à la simulation.
static func _tiquer_disparitions(sim: Simulation, tick: int) -> void:
	var dc: Dictionary = _cfg().get("disparition", {})
	if dc.is_empty():
		return
	var jour := maxi(1, int(SimTerrain._cycle(sim).get("ticks_par_jour", 2400000)))
	var vivants := sim.vivants()
	for id_m: String in sim.entites.keys().duplicate():
		var m: Dictionary = sim.entites[id_m]
		if m.get("vivant", true) or not bool(m.get("mort_cachee", false)):
			continue
		# 1. QUELQU'UN LE TROUVE : il le voit de près, ou il le sent.
		var trouveur: Dictionary = {}
		for x in vivants:
			if x.camp != "civil":
				continue
			var d := Grille.distance(x.pos, m.pos)
			if d <= int(dc.get("vue_corps", 6)) and Etres.sens_actif(x, "vue") and sim.grille.ligne_de_vue(x.pos, m.pos):
				trouveur = x
				break
			if Etres.sens_actif(x, "odorat") and SimTerrain.odeur_a(sim, x.pos) >= float(dc.get("odeur_seuil", 10.0)) and d <= 24:
				trouveur = x
				break
		if not trouveur.is_empty():
			m.erase("mort_cachee")
			EventBus.emettre(&"journal", [&"journal.corps_trouve", {"nom": m.name_key, "trouveur": trouveur.name_key}])
			SimVilles.enterrer(sim, m, "")   # enterré, pleuré — et le tueur reste inconnu : personne ne l'a vu
			continue
		# 2. PERSONNE NE L'A TROUVÉ : son absence se remarque, d'abord chez les siens.
		var age := tick - int(m.get("mort_tick", tick))
		var village := str(m.get("village", ""))
		if village.is_empty():
			continue
		if age >= int(dc.get("jours_proches", 1)) * jour and not bool(m.get("absence_proches", false)):
			m["absence_proches"] = true
			var proches := {}
			var fam: Dictionary = m.get("family", {})
			for cle in ["child_of", "children", "parent_of", "spouse"]:
				var v: Variant = fam.get(cle, [])
				for pid in (v if v is Array else [v]):
					if not str(pid).is_empty():
						proches[str(pid)] = true
			var n_p := 0
			for x in vivants:
				if proches.has(str(x.id)) or int(x.get("social", {}).get("relations", {}).get(id_m, 0)) >= int(dc.get("relation_proche", 20)):
					x["humeur"] = clampi(int(x.get("humeur", 60)) + int(dc.get("humeur_proches", -8)), 0, 100)
					n_p += 1
			if n_p > 0:
				EventBus.emettre(&"journal", [&"journal.absence_proches", {"nom": m.name_key, "n": n_p}])
		if age >= int(dc.get("jours_ville", 7)) * jour and not bool(m.get("absence_ville", false)):
			m["absence_ville"] = true
			var n_v := 0
			for x in vivants:
				if str(x.get("village", "")) == village:
					x["humeur"] = clampi(int(x.get("humeur", 60)) + int(dc.get("humeur_ville", -3)), 0, 100)
					n_v += 1
			if n_v > 0:
				EventBus.emettre(&"journal", [&"journal.absence_ville", {"nom": m.name_key, "village": village}])


## QUI A VU ? Le civil le plus proche (à `portee` tuiles au plus) dont le champ de vue atteint l'auteur, s'il remporte
## Perception contre Discrétion — la nuit aide celui qui se cache. Rend {} si personne n'a rien vu. Le même témoin sert
## aux lois (`SimRoyaumes._infraction`) et à la rumeur : un seul regard dans le monde, pas deux.
static func temoin_de(sim: Simulation, auteur: Dictionary, pos: Vector2i, portee: int) -> Dictionary:
	var temoin: Dictionary = {}
	for x in sim.vivants():
		if x.id == auteur.id or int(x.get("sante", 1)) <= 0 or x.camp != "civil" or Grille.distance(x.pos, pos) > portee or not sim.voit_ia(x, auteur):   # la victime qui tombe ne témoigne pas
			continue
		if temoin.is_empty() or Grille.distance(x.pos, pos) < Grille.distance(temoin.pos, pos):
			temoin = x
	if temoin.is_empty():
		return {}
	var jet_temoin := sim.des.jet("1d20") + int(temoin.corps.stats.perception) / 2
	var jet_auteur := sim.des.jet("1d20") + sim.regles.niveau(auteur.get("competences_eff", auteur.get("competences", {})), "discretion") + (int(SimTerrain._cycle(sim).get("discretion_nuit", 4)) if SimTerrain.est_nuit(sim) else 0)
	if jet_auteur >= jet_temoin:
		return {}
	return temoin


## CE QU UN FAIT PÈSE POUR QUI SE TIENT ICI, MAINTENANT : zéro tant que la nouvelle n'est pas arrivée, un à son
## arrivée, puis décroissant jusqu'à l'oubli. C'est la rumeur entière, en quatre lignes et sans état.
static func fraicheur(cfg: Dictionary, fait: Dictionary, cellule: Vector2i, tick: int) -> float:
	var d: Vector2i = (fait.cellule as Vector2i) - cellule
	var cases := maxi(absi(d.x), absi(d.y))
	if cases > int(cfg.get("portee_max_cellules", 24)):
		return 0.0   # trop loin : la nouvelle se perd en route, elle n'arrive jamais
	var arrivee := int(fait.tick) + cases * int(cfg.get("ticks_par_cellule", 120000))
	if tick < arrivee:
		return 0.0   # elle n'est pas encore là : un village lointain n'a rien entendu
	var duree := float(cfg.get("duree_memoire", 24000000))
	return clampf(1.0 - float(tick - arrivee) / maxf(1.0, duree), 0.0, 1.0)


## Les factions auxquelles un être appartient : par sa race, par sa fonction de village, par ses tags. Un être peut
## en avoir plusieurs — un garde nain est à la fois gens d'armes et compagnie de métier, et sa relation les additionne.
static func factions_de(e: Dictionary) -> Array[String]:
	var res: Array[String] = []
	var race := str(e.get("race", ""))
	var fonction := str(e.get("fonction", ""))
	var tags: Array = e.get("tags", [])
	for fid: String in GameData.catalogues.get("factions", {}).keys():
		var m: Dictionary = GameData.entree("factions", fid).get("membres", {})
		var dedans: bool = race in m.get("races", []) or fonction in m.get("fonctions", [])
		if not dedans:
			for t in m.get("tags", []):
				if str(t) in tags:
					dedans = true
					break
		if dedans:
			res.append(fid)
	# UNE RACE EST UNE FACTION, ET UNE SOUS-RACE EN HÉRITE (ordre de travail 29 ter, 2026-09-13) : un homme-chat est de
	# `race:homme_chat` ET de `race:homme_bete`. La somme des appartenances sait déjà additionner — rien d'autre à écrire.
	for rid in lignee_de_race(race):
		res.append("race:" + rid)
	# UNE ESPÈCE EST UNE FACTION. Une bête appartient à celle de son espèce, qui n'existe dans aucun fichier : elle
	# est déduite de son `def`, et ne value que le tag que les actes contre cette espèce posent.
	var def := str(e.get("def", ""))
	if not def.is_empty() and not ("civil" in tags) and e.get("controle", "") != "joueur":
		res.append("espece:" + def)
	return res


## LA LIGNÉE D'UNE RACE : elle-même, puis son `parent`, puis le parent de celui-ci (ordre de travail 29 ter). Une boucle
## dans les données s'arrête au premier retour plutôt que de geler le jeu.
static func lignee_de_race(race: String) -> Array[String]:
	var res: Array[String] = []
	var r := race
	while not r.is_empty() and GameData.catalogues.get("races", {}).has(r) and not (r in res):
		res.append(r)
		r = str(GameData.catalogues.races[r].get("parent", ""))
	return res


## Les tags qu'un acte contre cet être pose au nom de son peuple : `race:<id>` pour lui et chacun de ses ancêtres.
static func tags_de_peuple(e: Dictionary) -> Array:
	var res: Array = []
	for rid in lignee_de_race(str(e.get("race", ""))):
		res.append("race:" + rid)
	return res


## Ce que vaut un tag pour une faction — nommée ou implicite. Une faction d'espèce ne connaît qu'un seul tag : le
## sien. C'est ce qui fait qu'on peut fâcher les loups sans fâcher les cerfs.
static func valeur_de(fid: String, tag: String) -> float:
	if fid.begins_with("espece:"):
		return -6.0 if tag == "espece:" + fid.trim_prefix("espece:") else 0.0
	if fid.begins_with("race:"):   # un peuple ne connaît que ce qu'on fait aux siens (29 ter)
		return -6.0 if tag == fid else 0.0
	# UN ROYAUME JUGE PAR SA GOUVERNANCE (ordre de travail 29 bis, 2026-09-09). Il n'a pas de table à lui : une
	# dictature militaire ne pardonne pas le désordre où qu'elle règne, et c'est bien ce qu'on veut dire par
	# « gouvernance ». Le royaume est un observateur de plus, et `SimRumeur` savait déjà tout faire pour lui.
	if fid.begins_with("gouvernance:"):
		return float((GameData.entree("governments", fid.trim_prefix("gouvernance:")).get("valeurs", {}) as Dictionary).get(tag, 0.0))
	return float((GameData.entree("factions", fid).get("valeurs", {}) as Dictionary).get(tag, 0.0))


## CE QU'UN ROYAUME PENSE DE QUELQU'UN, vu de sa capitale (ordre de travail 29 bis). La même somme que pour une
## faction, le même oubli par la fraîcheur — et la même économie : rien ne s'accumule, tout se déduit des faits
## qui ont eu le temps d'arriver jusqu'au trône.
static func opinion_royaume(sim: Simulation, roy: Dictionary, e: Dictionary) -> int:
	if roy.is_empty() or sim.monde == null or (sim.monde.faits as Array).is_empty():
		return 0
	var cap: Vector2i = roy.get("capital_poi", Vector2i.ZERO)
	return reputation(sim, "gouvernance:" + str(roy.get("government_type", "")), str(e.id), sim.monde.cellule_de(cap), sim.horloge_monde.ticks)


## LA RÉPUTATION D'UNE FACTION ENVERS QUELQU'UN, VUE D'ICI. Une somme, pas un compteur : elle se recalcule des faits
## que cette place-là connaît, si bien qu'elle n'est jamais comptée deux fois et qu'elle s'efface toute seule.
## Bornée comme toutes les réputations du jeu, entre −100 et 100.
static func reputation(sim: Simulation, fid: String, id_auteur: String, cellule: Vector2i, tick: int) -> int:
	var cfg := _cfg()
	if cfg.is_empty() or sim.monde == null:
		return 0
	var total := 0.0
	for f in sim.monde.faits:
		var fait: Dictionary = f
		if str(fait.auteur) != id_auteur:
			continue
		var fr := fraicheur(cfg, fait, cellule, tick)
		if fr <= 0.0:
			continue
		var v := 0.0
		for tag in fait.tags:
			v += valeur_de(fid, str(tag))
		total += v * float(fait.gravite) * fr
	return clampi(roundi(total), -100, 100)


## CE QUE LES FACTIONS D'UN ÊTRE PENSENT D'UN AUTRE, additionné. C'est ce que la relation d'un PNJ ajoute à ce qu'il
## sait de lui-même : un garde qui n'a jamais vu le joueur le regarde quand même de travers si la nouvelle du
## meurtre est arrivée jusqu'à son village.
static func opinion(sim: Simulation, pnj: Dictionary, e: Dictionary) -> int:
	if sim.monde == null or (sim.monde.faits as Array).is_empty():
		return 0
	# ON NE REFAIT PAS LA SOMME À CHAQUE REGARD. `relation_de` est appelé par l'IA pour chaque paire d'êtres et à
	# chaque pas ; parcourir deux cent quarante faits par appel serait le lag en ville, et le dépôt en a déjà payé
	# un (la carte de lumière refaite à chaque tick, 2026-09-08). La somme se garde par paire, et se refait quand un
	# fait NOUVEAU arrive (le compteur de version) ou quand assez de temps a passé pour que la fraîcheur ait bougé.
	var cle := "%s|%s" % [str(pnj.id), str(e.id)]
	var memo: Dictionary = sim.opinions_memo.get(cle, {})
	var tick := sim.horloge_monde.ticks
	if not memo.is_empty() and int(memo.version) == int(sim.monde.faits.size()) and absi(tick - int(memo.tick)) < int(_cfg().get("memo_ticks", 60000)):
		return int(memo.v)
	var cellule: Vector2i = sim.monde.cellule_de(pnj.get("pos", Vector2i.ZERO))
	var total := 0
	for fid in factions_de(pnj):
		total += reputation(sim, fid, str(e.id), cellule, tick)
	total = clampi(total, -100, 100)
	sim.opinions_memo[cle] = {"v": total, "tick": tick, "version": int(sim.monde.faits.size())}
	return total


## Les faits qu'on connaît ici, du plus frais au plus vieux — ce que l'écran et le dialogue liront le jour venu.
static func connus(sim: Simulation, cellule: Vector2i, tick: int) -> Array:
	var cfg := _cfg()
	var res: Array = []
	if cfg.is_empty() or sim.monde == null:
		return res
	for f in sim.monde.faits:
		var fr := fraicheur(cfg, f, cellule, tick)
		if fr > 0.0:
			res.append({"fait": f, "fraicheur": fr})
	res.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.fraicheur) > float(b.fraicheur))
	return res


# ---------------------------------------------------------------- le monde se dit (22 ter, lot 8 — 2026-09-14)

## LES NOUVELLES DU MONDE qu'un PNJ connaît : ce que la simulation fait autour de lui, lu dans l'état — jamais écrit à la
## main. Rend [{cle, params}], de la plus urgente à la plus banale.
static func nouvelles_du_monde(sim: Simulation, pnj: Dictionary) -> Array:
	var res: Array = []
	if sim.monde == null or sim.lieu != "camp":
		return res
	var pos: Vector2i = pnj.get("pos", Vector2i.ZERO)
	var cell := sim.monde.cellule_de(pos)
	if SimVoyage.en_guerre(sim, cell):
		res.append({"cle": "nouvelle.guerre", "params": {}})
	# UNE RAZZIA FRAÎCHE DANS LES PARAGES (question 25, 2026-09-14) : on en parle, et on dit qui.
	var nr: Dictionary = _cfg().get("nouvelles_razzia", {})
	for f in sim.monde.faits:
		if str(f.get("acte", "")) != "razzia" or sim.horloge_monde.ticks - int(f.get("tick", 0)) > int(nr.get("age_max_ticks", 336000)):
			continue
		if Grille.distance(Vector2i(f.cellule), cell) <= int(nr.get("portee_cellules", 6)):
			res.append({"cle": "nouvelle.razzia", "params": {"royaume": str(SimRoyaumes.royaume_par_id(sim, str(f.royaume_auteur)).get("nom", f.royaume_auteur))}})
			break
	for id in (GameData.config("maladies").get("liste", {}) as Dictionary).keys():
		if SimMaladies.charge(sim, pos, str(id)) > 0.0:
			res.append({"cle": "nouvelle.maladie", "params": {"maladie": str(GameData.config("maladies").liste[id].get("name_key", id))}})
			break
	if SimEcologie.affamee(sim, cell):
		res.append({"cle": "nouvelle.loups_affames", "params": {}})
	elif SimEcologie.mult_recolte(sim, cell) < 1.0:
		res.append({"cle": "nouvelle.cerfs_pullulent", "params": {}})
	if SimClimat.secheresse(sim, cell):
		res.append({"cle": "nouvelle.secheresse", "params": {}})
	elif SimClimat.detrempe(sim, cell):
		res.append({"cle": "nouvelle.detrempe", "params": {}})
	if SimClimat.neige_sol(sim, cell) > 0.4:
		res.append({"cle": "nouvelle.neige", "params": {}})
	var lieu := lieu_des_environs(sim, pos)
	if not lieu.is_empty():
		var tc := int(sim.monde.taille)
		var d: Vector2i = lieu.centre - pos
		res.append({"cle": "nouvelle.lieu", "params": {"lieu": "lieu.sous_type." + str(lieu.sous_type), "direction": "direction." + _direction(d), "lieu_id": str(lieu.id),
			"cellules": maxi(1, roundi(float(maxi(absi(d.x), absi(d.y))) / float(tc)))}})
	return res


## Le lieu des environs dont on parle : le plus proche que le joueur ne connaît pas encore, sinon le plus proche.
static func lieu_des_environs(sim: Simulation, pos: Vector2i) -> Dictionary:
	var tc := int(sim.monde.taille)
	var s0 := Lieux.secteur_de_tuile(pos, tc)
	var inconnu := {}
	var d_inc := 999999
	var connu := {}
	var d_con := 999999
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for l in sim.monde.surface.lieux().secteur(s0 + Vector2i(dx, dy)):
				var dl: int = Grille.distance(pos, l.centre)
				if sim.monde.lieux_connus.has(str(l.id)):
					if dl < d_con:
						d_con = dl
						connu = l
				elif dl < d_inc:
					d_inc = dl
					inconnu = l
	return inconnu if not inconnu.is_empty() else connu


static func _direction(d: Vector2i) -> String:
	if d == Vector2i.ZERO:
		return "ici"
	var a := fposmod(rad_to_deg(atan2(float(d.y), float(d.x))), 360.0)
	var noms := ["est", "sud_est", "sud", "sud_ouest", "ouest", "nord_ouest", "nord", "nord_est"]
	return str(noms[int(round(a / 45.0)) % 8])


## ÉCOUTER UNE NOUVELLE : le PNJ choisit la plus urgente qu'on ne lui a pas déjà entendue dire ; un lieu raconté devient
## connu du joueur — on apprend la carte en parlant aux gens.
static func raconter_nouvelle(sim: Simulation, pnj: Dictionary) -> Dictionary:
	var dites: Array = pnj.get("nouvelles_dites", [])
	var choisie := {}
	for n in nouvelles_du_monde(sim, pnj):
		var cle := str(n.cle) + ":" + str(n.params.get("lieu_id", ""))
		if not (cle in dites):
			choisie = n
			dites.append(cle)
			break
	if choisie.is_empty():
		return {}
	while dites.size() > 6:
		dites.pop_front()
	pnj["nouvelles_dites"] = dites
	pnj["derniere_nouvelle"] = choisie
	if choisie.params.has("lieu_id"):
		sim.monde.lieux_connus[str(choisie.params.lieu_id)] = true
	return choisie
