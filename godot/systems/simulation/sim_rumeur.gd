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
static func rapporter(sim: Simulation, auteur: Dictionary, acte: String, pos: Vector2i, tags_extra: Array = []) -> void:
	var cfg := _cfg()
	if cfg.is_empty() or auteur.is_empty() or sim.monde == null:
		return
	var tags: Array = (sim.regles.r.get("faits", {}).get("actes", {}) as Dictionary).get(acte, []).duplicate()
	if tags.is_empty() and tags_extra.is_empty():
		return
	tags.append_array(tags_extra)
	var faits: Array = sim.monde.faits
	faits.append({
		"auteur": str(auteur.id), "acte": acte, "tags": tags,
		"cellule": sim.monde.cellule_de(pos), "tick": sim.horloge_monde.ticks,
		"gravite": float((cfg.get("gravite", {}) as Dictionary).get(acte, 0.5)),
	})
	# LE SEUL OUBLI QUI SOIT UN CHOIX : au-delà du plafond, le plus ancien tombe. Tout le reste s'efface par la
	# fraîcheur, sans qu'une ligne l'efface.
	var plafond := int(cfg.get("faits_max", 240))
	while faits.size() > plafond:
		faits.remove_at(0)


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
	# UNE ESPÈCE EST UNE FACTION. Une bête appartient à celle de son espèce, qui n'existe dans aucun fichier : elle
	# est déduite de son `def`, et ne value que le tag que les actes contre cette espèce posent.
	var def := str(e.get("def", ""))
	if not def.is_empty() and not ("civil" in tags) and e.get("controle", "") != "joueur":
		res.append("espece:" + def)
	return res


## Ce que vaut un tag pour une faction — nommée ou implicite. Une faction d'espèce ne connaît qu'un seul tag : le
## sien. C'est ce qui fait qu'on peut fâcher les loups sans fâcher les cerfs.
static func valeur_de(fid: String, tag: String) -> float:
	if fid.begins_with("espece:"):
		return -6.0 if tag == "espece:" + fid.trim_prefix("espece:") else 0.0
	return float((GameData.entree("factions", fid).get("valeurs", {}) as Dictionary).get(tag, 0.0))


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
