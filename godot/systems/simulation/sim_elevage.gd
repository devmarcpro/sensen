class_name SimElevage
extends RefCounted
## L'entraîneur, les commandes de collectionneurs ; l'élevage : génomes, hérédité, capture, spécimens, variétés, paliers, la semaine.
## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans
## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par
## `tools/fragmenter.py`, sans changement de comportement.


## L'âme d'un compagnon dans le sac, s'il y en a une (dialogue du prêtre).
static func ame_dans_sac(sim: Simulation, e: Dictionary) -> String:
	for uid in e.sac:
		if sim.items.get(uid, {}).has("compagnon"):
			return str(uid)
	return ""


static func cout_resurrection(sim: Simulation, e: Dictionary, uid_ame: String, chez_pretre: bool) -> int:
	var ame: Dictionary = sim.items.get(uid_ame, {})
	var x: Dictionary = sim.entites.get(str(ame.get("compagnon", "")), {})
	if x.is_empty():
		return 0
	var c: Dictionary = sim.regles.r.compagnons
	var niveau := maxi(1, int(round(sim.progression.niveaux_derives(x).combat)))
	return int(float(c.or_par_niveau) * niveau * (float(c.get("pretre_mult", 1.0)) if chez_pretre else float(c.autel_mult)))


static func cout_entrainement(sim: Simulation, e: Dictionary, competence: String) -> int:
	var en: Dictionary = sim.regles.r.progression.entraineur
	return maxi(int(en.or_min), int(en.or_par_niveau) * sim.regles.niveau(e.competences, competence))


static func peut_entrainer(sim: Simulation, pnj: Dictionary, competence: String) -> bool:
	if not ("entraineur" in pnj.get("tags", [])):
		return false
	if str(pnj.get("fonction", "")) == "maitre_de_guilde":
		return true
	return str(GameData.catalogues.competences.get(competence, {}).get("category", "combat")) != "general"


static func _entrainer(sim: Simulation, e: Dictionary, pnj_id: String, competence: String, tick: int) -> bool:
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	if pnj.is_empty() or Grille.distance(e.pos, pnj.pos) > 2 or not peut_entrainer(sim, pnj, competence) or not GameData.catalogues.competences.has(competence):
		return false
	var cout := cout_entrainement(sim, e, competence)
	if int(e.or) < cout:
		EventBus.emettre(&"journal", [&"journal.entraine_refuse", {}])
		return false
	var cap := int(sim.regles.r.progression.potentiel_max)
	var actuel := int(e.potentiels.get(competence, int(sim.regles.r.progression.potentiel_defaut)))
	if actuel >= cap:
		EventBus.emettre(&"journal", [&"journal.entraine_plafond", {}])
		return false
	e.or = int(e.or) - cout
	pnj.or = int(pnj.or) + cout
	e.potentiels[competence] = mini(cap, actuel + int(sim.regles.r.progression.entraineur.potentiel))
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.entraine", {"nom": pnj.name_key, "competence": sim._nom_competence(competence), "potentiel": int(e.potentiels[competence]), "cout": cout}])
	return true


## La commande hebdomadaire d'un collectionneur : une variété possédée, décalée d'un ou deux pas de couleur.
static func _tirer_commande(sim: Simulation) -> void:
	var reg: Dictionary = sim.territoire.get("registre", {})
	if reg.is_empty():
		return
	var cm: Dictionary = _elv(sim).commandes
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "commande", sim.monde.semaine_courante])
	var especes: Array = reg.keys()
	especes.sort()
	var esp_id: String = especes[rng.randi() % especes.size()]
	var esp: Dictionary = GameData.catalogues.species[esp_id]
	if not esp.loci.has("couleur"):
		return
	var cles: Array = reg[esp_id].keys()
	cles.sort()
	var parts: PackedStringArray = str(cles[rng.randi() % cles.size()]).split("|")
	var pas := rng.randi_range(1, int(cm.pas_max))
	var couleur := posmod(int(parts[0]) + pas * (1 if rng.randf() < 0.5 else -1), int(esp.loci.couleur.n))
	var pal_e := paliers_elevage(sim)
	var mult := float(pal_e.commande_mult) * (1.0 + float(pal_e.commande_pct) / 100.0)
	var ch: Dictionary = _elv(sim).get("chatoyant", {})
	var chatoyant := not ch.is_empty() and rng.randf() < float(ch.commande_chance)
	if chatoyant:
		mult *= float(ch.commande_mult)
	var or_ := int(round((float(cm.base) + float(cm.par_rarete) * float(esp.capture.get("rarete", 1)) + float(cm.par_pas) * float(pas)) * mult))
	sim.territoire["commande"] = {"espece": esp_id, "couleur": couleur, "motif": parts[1] if parts.size() > 1 else "", "or": or_, "semaine": sim.monde.semaine_courante, "chatoyant": chatoyant}
	EventBus.emettre(&"journal", [&"journal.commande", {"espece": esp.name_key, "couleur": couleur, "motif": sim.territoire.commande.motif, "or": or_, "chatoyant": "ui.gestion.commande_chatoyant" if chatoyant else ""}])


static func _total_varietes(sim: Simulation) -> int:
	var n := 0
	for esp in sim.territoire.get("registre", {}).keys():
		n += sim.territoire.registre[esp].size()
	return n


static func _livrer_commande(sim: Simulation, e: Dictionary, pnj_id: String, tick: int) -> bool:
	var cmd: Dictionary = sim.territoire.get("commande", {})
	var pnj: Dictionary = sim.entites.get(pnj_id, {})
	if cmd.is_empty() or pnj.is_empty() or Grille.distance(e.pos, pnj.pos) > 2 or not ("commerce_possible" in pnj.get("tags", [])):
		return false
	var uid := ""
	for u in e.sac:
		var it: Dictionary = sim.items.get(u, {})
		if str(it.get("espece", "")) == str(cmd.espece) and str(it.get("genome", {}).get("couleur", "")) == str(cmd.couleur) and str(it.get("genome", {}).get("motif", "")) == str(cmd.motif) and (not bool(cmd.get("chatoyant", false)) or bool(it.get("chatoyant", false))):
			uid = u
			break
	if uid.is_empty():
		EventBus.emettre(&"journal", [&"journal.commande_manque", {}])
		return false
	if int(pnj.or) < int(cmd.or):
		EventBus.emettre(&"journal", [&"journal.commande_bourse", {}])
		return false
	pnj.or = int(pnj.or) - int(cmd.or)
	e.or = int(e.or) + int(cmd.or)
	e.sac.erase(uid)
	sim.items.erase(uid)
	sim.territoire.erase("commande")
	e.compteur = tick + int(sim.regles.r.actions.objet)
	EventBus.emettre(&"journal", [&"journal.commande_livree", {"or": int(cmd.or)}])
	EventBus.emettre(&"item_sold", [uid, e.id, int(cmd.or)])
	return true


# ---------------------------------------------------------------- élevage (Annexe H) : capture, hérédité, couvées, registre

static func _elv(sim: Simulation) -> Dictionary:
	return sim.regles.r.elevage


## Un génome tiré au hasard selon les loci de l'espèce (aucune connaissance de l'espèce dans le code).
static func _genome_aleatoire(sim: Simulation, esp: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var g := {}
	for nom in esp.loci.keys():
		var L: Dictionary = esp.loci[nom]
		match str(L.type):
			"anneau":
				g[nom] = rng.randi() % int(L.n)
			"nombre":
				g[nom] = snappedf(rng.randf_range(float(L.get("min", 1)), float(L.get("min", 1)) * 3.0), 0.01)
			"recessif":
				g[nom] = [rng.randi() % 2, rng.randi() % 2]
			"sequence":
				var seq: Array = []
				for k in int(L.get("n", 4)):
					seq.append(rng.randi() % int(L.get("valeurs", 2)))
				g[nom] = seq
			"age":
				g[nom] = 0
			"colonie":
				g[nom] = 1
			"lie_au_sexe":   # deux allèles (femelle) ou un (mâle) : tranché à la naissance par _exprimer_loci, ici deux
				g[nom] = [rng.randi() % int(L.get("n", 2)), rng.randi() % int(L.get("n", 2))]
			"carte":
				var carte: Array = []
				for k in int(L.get("n", 4)) * int(L.get("n", 4)):
					carte.append(1 if rng.randf() < 0.5 else 0)
				g[nom] = carte
			_:
				g[nom] = null
	return g


## Les loci qui s'expriment après la conception (Loci — les dix types) : acquis du lieu, âge, colonie.
static func _exprimer_loci(sim: Simulation, sp: Dictionary, cell: Vector2i, naissance: bool) -> void:
	var esp: Dictionary = GameData.catalogues.species.get(str(sp.espece), {})
	for nom in esp.get("loci", {}).keys():
		var L: Dictionary = esp.loci[nom]
		match str(L.type):
			"acquis":
				if naissance and str(L.get("source", "")) == "corruption" and sim.monde != null:
					sp.genome[nom] = 1 if sim.monde.corruption_de(cell) / 100.0 >= float(L.get("seuil", 0.5)) else 0
			"age":
				sp.genome[nom] = mini(int(L.get("max", 999)), int(sp.get("age_semaines", 0)) * int(L.get("par_semaine", 1)))
			"colonie":
				if not naissance:
					sp.genome[nom] = mini(int(L.get("max", 10)), int(sp.genome.get(nom, 1)) + int(L.get("par_semaine", 1)))
			"lie_au_sexe":   # un mâle ne porte qu'un allèle
				if naissance and str(sp.get("sexe", "f")) == "m" and sp.genome.get(nom) is Array and sp.genome[nom].size() > 1:
					sp.genome[nom] = [sp.genome[nom][0]]
			"automate":   # jamais tiré : une règle sur les autres loci
				var autres: Array = []
				for k in esp.loci.keys():
					if k != nom and str(esp.loci[k].type) != "automate":
						autres.append(str(sp.genome.get(k)))
				sp.genome[nom] = posmod(hash("|".join(autres)), int(L.get("n", 8)))


## L'hérédité, locus par locus (Loci — les dix types) : une fonction par type, aucune ne connaît d'espèce.
static func _heriter(sim: Simulation, a: Variant, b: Variant, L: Dictionary, rng: RandomNumberGenerator) -> Variant:
	match str(L.type):
		"anneau":   # Règle d'anneau : 34 % A, 34 % B, 16 % une voisine de A, 16 % une voisine de B
			var pr: Array = _elv(sim).anneau
			var r := rng.randf()
			if r < float(pr[0]):
				return a
			if r < float(pr[0]) + float(pr[1]):
				return b
			var s: int = int(a) if rng.randf() < 0.5 else int(b)
			return posmod(s + (1 if rng.randf() < 0.5 else -1), int(L.n))
		"nombre":   # moyenne des parents × dérive gaussienne, sans plafond si max est null
			var v := (float(a) + float(b)) / 2.0 * (1.0 + rng.randfn(0.0, 1.0) * float(L.get("var", 0.05)))
			v = maxf(float(L.get("min", 0)), v)
			if L.get("max") != null:
				v = minf(float(L.max), v)
			return snappedf(v, 0.01)
		"recessif":
			return [a[rng.randi() % 2], b[rng.randi() % 2]]
		"sequence":
			var seq: Array = []
			for i in a.size():
				seq.append(a[i] if rng.randf() < 0.5 else b[i])
			return seq
		"carte":   # la carte d'un parent, déformée : une fraction mut de cases retournées
			if a == null or b == null:
				return a if b == null else b
			var src: Array = (a if rng.randf() < 0.5 else b).duplicate()
			for i in src.size():
				if rng.randf() < float(L.get("mut", 0.1)):
					src[i] = 1 - int(src[i])
			return src
		"lie_au_sexe":   # un allèle de la mère (a) toujours ; un du père (b) si l'enfant est femelle — tranché ensuite
			if a == null or b == null:
				return a if b == null else b
			return [a[rng.randi() % a.size()], b[rng.randi() % b.size()]]
		_:
			return null


## Les conditions de reproduction (Conditions de reproduction) : un seul évaluateur, qui dit pourquoi.
static func conditions_repro(sim: Simulation, a: Dictionary, b: Dictionary, ctx: Dictionary) -> Dictionary:
	var raisons: Array = []
	if str(a.espece) != str(b.espece):
		raisons.append({"cle": "raison.espece"})
	var esp: Dictionary = GameData.catalogues.species.get(str(a.espece), {})
	for c in esp.get("repro", {}).get("conditions", []):
		match str(c.c):
			"habitat":
				if str(ctx.get("habitat", "")) != str(c.v):
					raisons.append({"cle": "raison.habitat", "v": str(c.v)})
			"place":
				if int(ctx.get("libre", 0)) <= 0:
					raisons.append({"cle": "raison.place"})
			"temperature":
				var t := float(ctx.get("temp", 18.0))
				if t < float(c.min) or t > float(c.max):
					raisons.append({"cle": "raison.temperature", "temp": int(round(t)), "min": c.min, "max": c.max})
			"saison":
				if not (str(ctx.get("saison", "")) in c.v):
					raisons.append({"cle": "raison.saison"})
			"sexe":
				if str(a.sexe) == str(b.sexe):
					raisons.append({"cle": "raison.sexe"})
			"age":
				var min_age := maxi(1, roundi(float(c.min) * float(paliers_elevage(sim).eclosion)))   # palier 200 : éclosions plus rapides
				if mini(int(a.get("age_semaines", 0)), int(b.get("age_semaines", 0))) < min_age:
					raisons.append({"cle": "raison.age"})
			"stat":
				if minf(float(a.genome.get(str(c.k), 0)), float(b.genome.get(str(c.k), 0))) < float(c.min):
					raisons.append({"cle": "raison.stat", "k": str(c.k)})
			"colonie":   # Lucioles : elles ne s'accordent qu'en nombre (Catalogue des groupes d'élevage)
				if int(ctx.get("occupants", 0)) < int(c.min):
					raisons.append({"cle": "raison.colonie", "n": int(c.min)})
			"ressource":
				if int(sim.territoire.stocks.get(str(c.k), 0)) < int(c.n):
					raisons.append({"cle": "raison.ressource", "k": str(c.k), "n": int(c.n)})
	return {"ok": raisons.is_empty(), "raisons": raisons}


## Capturer au filet sur une tuile d'eau adjacente : jet 1d20 + Collecte contre le dd de l'espèce.
static func _capturer(sim: Simulation, e: Dictionary, tick: int) -> bool:
	if sim.monde == null or sim.lieu != "camp":
		return false
	var milieux: Dictionary = {"sol": true}
	for d in Grille.DIRS:
		var q: Vector2i = e.pos + d
		if not sim.grille.dans(q):
			continue
		var tags: Array = sim.grille.contenu_de(q).get("tags", [])
		for t in ["eau", "plante", "arbre"]:
			if t in tags:
				milieux[t] = true
	var ids: Array = GameData.catalogues.species.keys()
	ids.sort()
	var candidats: Array = []
	var refus := ""
	for sid in ids:
		var c: Dictionary = GameData.catalogues.species[sid].capture
		if not milieux.has(str(c.get("milieu", ""))):
			continue
		if bool(c.get("nuit", false)) and not SimTerrain.est_nuit(sim):
			refus = "journal.capture_nuit"
			continue
		if c.has("appat") and SimTerrain._pile_objet(sim, e, str(c.appat)).is_empty():
			refus = "journal.capture_appat"
			continue
		candidats.append(str(sid))
	if candidats.is_empty():
		if refus == "journal.capture_appat":
			EventBus.emettre(&"journal", [&"journal.capture_appat", {"appat": "item.viande_crue.name"}])
		elif not refus.is_empty():
			EventBus.emettre(&"journal", [StringName(refus), {}])
		else:
			EventBus.emettre(&"journal", [&"journal.capture_rien", {}])
		return false
	var rng0 := RandomNumberGenerator.new()
	rng0.seed = hash([sim.graine, "milieu", tick, e.id])
	var esp_id: String = candidats[rng0.randi() % candidats.size()]
	var esp: Dictionary = GameData.catalogues.species[esp_id]
	if esp.capture.has("appat"):
		SimCamp._consommer_pile(sim, e, SimTerrain._pile_objet(sim, e, str(esp.capture.appat)))
	e.compteur = tick + int(sim.regles.r.actions.objet) * 2
	var jet := sim.des.jet("1d20") + sim.regles.niveau(e.competences_eff, str(_elv(sim).competence_capture)) + int(paliers_elevage(sim).capture)
	var dd := int(esp.capture.get("dd", 10))
	sim.gagner_xp(e, str(_elv(sim).competence_capture), 5)
	if jet < dd:
		EventBus.emettre(&"journal", [&"journal.capture_ratee", {"jet": jet, "dd": dd}])
		return true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([sim.graine, "capture", tick, e.id])
	var sp := _nouveau_specimen(sim, esp_id, _genome_aleatoire(sim, esp, rng), "m" if rng.randf() < 0.5 else "f", _tirer_chatoyant(sim, rng, false))
	_exprimer_loci(sim, sp, SimCamp._cell_de(sim, e.pos), true)
	_enregistrer_variete(sim, sp)
	SimObjets.donner(sim, e, sp.uid)
	EventBus.emettre(&"journal", [&"journal.capture_reussie", {"nom": e.name_key, "espece": esp.name_key, "couleur": str(sp.genome.get("couleur", "-")), "motif": str(sp.genome.get("motif", "-"))}])
	return true


## Le tirage du chatoyant (Vivarium — loci et variétés) : 1,5 %, ×6 si un parent l'est, ×3 au palier 500.
static func _tirer_chatoyant(sim: Simulation, rng: RandomNumberGenerator, parent_chatoyant: bool) -> bool:
	var ch: Dictionary = _elv(sim).get("chatoyant", {})
	if ch.is_empty():
		return false
	var chance := float(ch.chance)
	if parent_chatoyant:
		chance *= float(ch.mult_parent)
	if _total_varietes(sim) >= int(ch.palier_varietes):
		chance *= float(ch.mult_palier)
	return rng.randf() < chance


static func _nouveau_specimen(sim: Simulation, esp_id: String, genome: Dictionary, sexe: String, chatoyant: bool = false) -> Dictionary:
	var sp: Dictionary = SimObjets.generer_objet(sim, "specimen", 1, {"espece": esp_id}, "commun", 0)
	sp["espece"] = esp_id
	sp["genome"] = genome
	sp["sexe"] = sexe
	sp["age_semaines"] = 0
	sp["chatoyant"] = chatoyant
	if chatoyant:
		if not sim.territoire.has("chatoyants"):
			sim.territoire["chatoyants"] = {}
		sim.territoire.chatoyants[esp_id] = int(sim.territoire.chatoyants.get(esp_id, 0)) + 1
		EventBus.emettre(&"journal", [&"journal.chatoyant", {"espece": GameData.catalogues.species[esp_id].name_key}])
	sp["nom"] = {"params": {"espece": GameData.catalogues.species[esp_id].name_key, "couleur": str(genome.get("couleur", "")), "motif": str(genome.get("motif", "")), "chatoyant": "ui.specimen.chatoyant" if chatoyant else ""}}
	sp.tags = sp.tags.duplicate()
	sp.tags.erase("empilable")
	_enregistrer_variete(sim, sp)
	return sp


static func _enregistrer_variete(sim: Simulation, sp: Dictionary) -> void:
	if not sim.territoire.has("registre"):
		sim.territoire["registre"] = {}
	_appliquer_paliers_potentiel(sim)
	var esp := str(sp.espece)
	if not sim.territoire.registre.has(esp):
		sim.territoire.registre[esp] = {}
	sim.territoire.registre[esp][cle_variete(sim, sp)] = true
	# Records des loci nombre et allèles vus (Vivarium — registre et paliers).
	if not sim.territoire.has("records"):
		sim.territoire["records"] = {}
	if not sim.territoire.records.has(esp):
		sim.territoire.records[esp] = {}
	var loci: Dictionary = GameData.catalogues.species.get(esp, {}).get("loci", {})
	for nom in loci.keys():
		var t := str(loci[nom].type)
		var v = sp.genome.get(nom)
		if t == "nombre" and v != null:
			sim.territoire.records[esp][nom] = maxf(float(sim.territoire.records[esp].get(nom, 0.0)), float(v))
		elif t in ["recessif", "lie_au_sexe"] and v is Array:
			var vus: Dictionary = sim.territoire.records[esp].get(nom, {})
			for al in v:
				vus[str(al)] = true
			sim.territoire.records[esp][nom] = vus


## Applique les planchers de potentiel au joueur et à ses compagnons (après une nouvelle variété, un chargement).
static func _appliquer_paliers_potentiel(sim: Simulation) -> void:
	for x in sim.entites.values():
		if x.controle == "joueur" or (x.has("maitre") and str(x.maitre) != ""):
			_paliers_potentiel(sim, x)


## Le plancher de potentiel donné par les paliers du registre (Vivarium — registre et paliers) : sur le joueur
## et ses compagnons seulement — le registre est celui du camp.
static func _paliers_potentiel(sim: Simulation, e: Dictionary) -> void:
	if not e.has("potentiels") or sim.territoire.get("registre", {}).is_empty():
		return
	var pal := paliers_elevage(sim)
	var n_elevage := int(pal.potentiel)
	var n_vie := int(pal.potentiel_vie)
	if n_elevage <= 0 and n_vie <= 0:
		return
	var defaut := int(sim.regles.r.progression.potentiel_defaut)
	var cap := int(sim.regles.r.progression.get("potentiel_max", 200))
	for cle in GameData.catalogues.competences.keys():
		var bonus := 0
		if str(cle) == "elevage":
			bonus = maxi(bonus, n_elevage)
		if str(GameData.catalogues.competences[cle].get("famille", "")) == "vie":
			bonus = maxi(bonus, n_vie)
		if bonus <= 0:
			continue
		var base := int(e.get("potentiels_base", {}).get(cle, defaut))   # un plancher sur le potentiel de base, pas un cumul
		e.potentiels[cle] = mini(cap, maxi(int(e.potentiels.get(cle, defaut)), base + bonus))


## Les paliers du registre (Vivarium — registre et paliers) : bonus de capture, couvées supplémentaires.
static func paliers_elevage(sim: Simulation) -> Dictionary:
	var res := {"capture": 0, "couvees": 0, "potentiel": 0, "potentiel_vie": 0, "eclosion": 1.0, "commande_mult": 1, "commande_pct": 0, "atteints": []}
	var pal: Dictionary = _elv(sim).get("paliers", {})
	var nv := 0
	for esp in sim.territoire.get("registre", {}).keys():
		nv += sim.territoire.registre[esp].size()
	var ne: int = sim.territoire.get("registre", {}).size()
	for s in pal.get("varietes", []) + pal.get("especes", []):
		var seuil := nv if (s in pal.get("varietes", [])) else ne
		if seuil < int(s[0]):
			continue
		var effet := str(s[1])
		if effet in ["eclosion", "commande_mult"]:   # des multiplicateurs, pas des sommes
			res[effet] = float(s[2]) if effet == "eclosion" else int(s[2])
		else:
			res[effet] = int(res.get(effet, 0)) + int(s[2])
		res.atteints.append("palier." + effet)
	if ne >= GameData.catalogues.species.size() and ne > 0:
		res.capture = int(res.capture) + int(pal.get("bestiaire_complet_capture", 0))
		res.atteints.append("palier.bestiaire")
	return res


## Les variétés possibles d'une espèce : le produit des anneaux couleur × motif, sinon des loci qualitatifs.
static func varietes_possibles(sim: Simulation, esp_id: String) -> int:
	var loci: Dictionary = GameData.catalogues.species.get(esp_id, {}).get("loci", {})
	var n := 1
	for nom in loci.keys():
		var L: Dictionary = loci[nom]
		match str(L.type):
			"anneau":
				n *= int(L.n)
			"sequence":
				n *= int(pow(float(L.get("valeurs", 2)), float(L.get("n", 4))))
			"automate", "acquis":
				n *= maxi(2, int(L.get("n", 2)))
	return n


## La clé d'une variété au registre (Vivarium) : les loci **qualitatifs** de l'espèce, dans l'ordre du
## catalogue — pas seulement couleur|motif, sinon une luciole (rythme) ou un coquillage (automate) ne
## collectionnerait rien. Les loci `nombre`, `age` et `colonie` en sont exclus : ils vont aux records.
static func cle_variete(sim: Simulation, sp: Dictionary) -> String:
	var loci: Dictionary = GameData.catalogues.species.get(str(sp.espece), {}).get("loci", {})
	var parts: Array[String] = []
	for nom in loci.keys():
		if str(loci[nom].type) in ["anneau", "sequence", "automate", "carte", "acquis"]:
			var v = sp.get("genome", {}).get(nom)
			parts.append(",".join(v.map(func(x: Variant) -> String: return str(x))) if v is Array else str(v))
	if parts.is_empty():
		parts.append(str(sp.get("genome", {}).get("couleur", "")))
	return "|".join(parts)


## Le passage hebdomadaire de l'élevage : dans chaque vivarium de la fenêtre, le premier couple valide donne une couvée.
static func _semaine_elevage(sim: Simulation) -> void:
	if sim.monde == null or sim.lieu != "camp":
		return
	_tirer_commande(sim)
	for gi in sim.grille.meubles.keys():
		var m: Dictionary = GameData.entree("meubles", str(sim.grille.meubles[gi]))
		var specimens: Array = []
		var pos := sim.grille.pos_de(int(gi))
		for uid in sim.contenants.get(gi, []):
			var it: Dictionary = sim.items.get(uid, {})
			if it.has("genome"):
				it.age_semaines = int(it.get("age_semaines", 0)) + 1
				_exprimer_loci(sim, it, SimCamp._cell_de(sim, pos), false)
				specimens.append(it)
				var prod: Dictionary = GameData.catalogues.species[str(it.espece)].get("production", {})
				if not prod.is_empty() and (not prod.has("saisons") or SimTerrain.saison(sim) in prod.saisons):
					var col := 1
					for nom in it.genome.keys():
						if str(GameData.catalogues.species[str(it.espece)].loci[nom].type) == "colonie":
							col = int(it.genome[nom])
					var n := int(floor(float(prod.par_colonie) * float(col)))
					if n > 0:
						sim.territoire.stocks[str(prod.item)] = int(sim.territoire.stocks.get(str(prod.item), 0)) + n
						EventBus.emettre(&"journal", [&"journal.production_colonie", {"espece": GameData.catalogues.species[str(it.espece)].name_key, "n": n, "item": "item.%s.name" % str(prod.item)}])
		if specimens.size() < 2:
			continue
		var ctx := {"habitat": str(m.type_meuble), "occupants": sim.contenants[gi].size(), "libre": int(m.capacite_slots) - sim.contenants[gi].size(), "temp": float(SimTerrain.temperature_ressentie(sim, {"pos": pos}).temp), "saison": SimTerrain.saison(sim)}
		var fait := false
		var couvees := 0
		var couvees_max: int = int(_elv(sim).couvees_par_semaine) + int(paliers_elevage(sim).couvees)
		var derniere: Array = []
		for i in specimens.size():
			for j in range(i + 1, specimens.size()):
				if couvees >= couvees_max:
					break
				var res := conditions_repro(sim, specimens[i], specimens[j], ctx)
				if not res.ok:
					derniere = res.raisons
					continue
				var esp: Dictionary = GameData.catalogues.species[str(specimens[i].espece)]
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([sim.graine, "couvee", gi, sim.monde.semaine_courante])
				var n := mini(rng.randi_range(int(esp.repro.portee[0]), int(esp.repro.portee[1])), int(ctx.libre))
				for cout in esp.repro.get("couts", []):   # coût par croisement (vers à soie : des feuilles du stock)
					if str(cout.c) == "ressource":
						sim.territoire.stocks[str(cout.k)] = int(sim.territoire.stocks.get(str(cout.k), 0)) - int(cout.n)
						if int(sim.territoire.stocks[str(cout.k)]) <= 0:
							sim.territoire.stocks.erase(str(cout.k))
				for k in n:
					var g := {}
					for nom in esp.loci.keys():
						g[nom] = _heriter(sim, specimens[i].genome.get(nom), specimens[j].genome.get(nom), esp.loci[nom], rng)
					var enfant := _nouveau_specimen(sim, str(specimens[i].espece), g, "m" if rng.randf() < 0.5 else "f", _tirer_chatoyant(sim, rng, bool(specimens[i].get("chatoyant", false)) or bool(specimens[j].get("chatoyant", false))))
					_exprimer_loci(sim, enfant, SimCamp._cell_de(sim, pos), true)
					_enregistrer_variete(sim, enfant)
					sim.contenants[gi].append(enfant.uid)
					ctx.libre = int(ctx.libre) - 1
					EventBus.emettre(&"journal", [&"journal.couvee", {"espece": esp.name_key, "n": n, "couleur": str(g.get("couleur", "-")), "motif": str(g.get("motif", "-"))}])
				fait = true
				couvees += 1
		if not fait and not derniere.is_empty():
			var r0: Dictionary = derniere[0]
			EventBus.emettre(&"journal", [&"journal.couvee_refusee", {"espece": GameData.catalogues.species[str(specimens[0].espece)].name_key, "raison": str(r0.cle)}])


# ---------------------------------------------------------------- conquête, succession, repeuplement (étape 10.5)
