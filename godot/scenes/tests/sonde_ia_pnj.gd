extends Node
## Sonde des IA de PNJ — ennemis et alliés (designer 2026-09-04, 21 h 20 : « vérifie que les IA des PNJ
## fonctionnent correctement, que ce soit ennemis ou alliés »). Elle joue des scènes courtes en arène, au camp
## et en donjon, et dit ce que chaque être a FAIT — pas ce que sa fiche promet :
##   1. chaque créature hostile du catalogue, posée à trois tuiles du joueur : elle engage, approche, frappe —
##      et n'est jamais figée sur une horloge qui n'est pas la sienne (le rat de la capture, le même soir) ;
##   2. chaque créature paisible, au camp : elle fuit sans mordre (proies, fuyards), ou reste calme ;
##   3. les types d'ennemis : le tireur recule, le soigneur soigne, l'invocateur appelle, l'embusqueur guette,
##      la brute ne fuit pas, le blessé fuit ;
##   4. les compagnons : ils suivent, attendent sur ordre, entrent dans le combat du maître, évitent sur ordre,
##      et l'agressif poursuit là où le défensif reste ;
##   5. au camp : le civil fuit le loup, le garde l'intercepte, la routine mène au poste, à la place, au lit ;
##   6. en donjon : un hostile à huit tuiles vient au joueur sur l'horloge à l'action.
##   godot --headless --path godot res://scenes/tests/sonde_ia_pnj.tscn
##   Sortie 1 s'il y a des soucis. Les chiffres sont des mesures : ce qu'ils valent est au designer.

var soucis: Array[String] = []
var degats_joueur := 0   # ce que le joueur a perdu depuis le dernier `_remettre` : chaque ronde le remet à neuf (on mesure les coups, pas sa survie)
const RONDES := 60
const AGRESSIFS := ["hostile", "elite", "tank", "tireur", "invocateur", "soigneur", "embusqueur"]
const PAISIBLES := ["proie", "fuyard", "bete_sauvage", "civil"]


var seulement: Array = []   # --seulement a,b : ne jouer que ces sections (hostiles, paisibles, types, compagnons, camp, donjon)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seulement" and i + 1 < args.size():
			seulement = str(args[i + 1]).split(",")
	if _joue("hostiles"):
		_catalogue_hostiles()
	if _joue("paisibles"):
		_catalogue_paisibles()
	if _joue("types"):
		_types_d_ennemis()
	if _joue("compagnons"):
		_compagnons()
	if _joue("camp"):
		_camp()
	if _joue("donjon"):
		_donjon()
	for s in soucis:
		print("  souci : " + s)
	if not soucis.is_empty():
		print("SONDE IA PNJ : %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("SONDE IA PNJ : rien à signaler")
	get_tree().quit()


# ---------------------------------------------------------------- aides

func _joue(section: String) -> bool:
	return seulement.is_empty() or section in seulement


func _arene(graine: int, nom: String = "gorge") -> Simulation:
	var s := Simulation.new(graine)
	s.charger_arene(nom)
	_midi(s)
	return s


func _camp_sim(graine: int) -> Simulation:
	var s := Simulation.new(graine)
	s.charger_camp()
	_midi(s)
	return s


## Midi du troisième jour : de jour, et loin de zéro — un tampon du monde ne se confond pas avec celui d'un combat.
func _midi(s: Simulation) -> void:
	_heure(s, 12.0)


func _heure(s: Simulation, h: float) -> void:
	var jour := int(s._cycle().get("ticks_par_jour", 24000))
	s.horloge_monde.ticks = 3 * jour + int(h / 24.0 * float(jour))


func _joueur(s: Simulation) -> Dictionary:
	degats_joueur = 0
	for e in s.vivants():
		if e.controle == "joueur":
			return e
	return {}


## Les dégâts pris depuis le dernier appel, et le joueur remis à neuf (une sante_max gonflée était reclampée par Etres.recalculer).
func _remettre(j: Dictionary) -> int:
	var d := degats_joueur
	degats_joueur = 0
	j.sante = j.sante_max
	j.vivant = true
	return d


## Une tuile libre à `d` tuiles du centre, praticable, en ligne de vue, à la même hauteur (pas de l'autre côté d'une falaise).
func _libre_a(s: Simulation, centre: Vector2i, d: int, meme_hauteur: bool = true) -> Vector2i:
	for dy in range(-d, d + 1):
		for dx in range(-d, d + 1):
			if maxi(absi(dx), absi(dy)) != d:
				continue
			var q := centre + Vector2i(dx, dy)
			if not s.grille.dans(q) or s.grille.bloque_passage(q) or not s.grille.occupant(q).is_empty():
				continue
			if not s.grille.ligne_de_vue(centre, q):
				continue
			if meme_hauteur and s.grille.h(q) != s.grille.h(centre):
				continue
			return q
	return Vector2i(-1, -1)


## Une ronde : le joueur joue `action` (attendre par défaut), le monde avance et vide ses dus, chaque combat joue
## jusqu'au joueur. En donjon (monde à l'action), le monde ne se vide que si le joueur est dessus — comme le client.
func _ronde(s: Simulation, j: Dictionary, action: Dictionary = {"type": "attendre"}) -> void:
	var sante_avant := int(j.sante)
	s.attente[j.id] = true
	s.intention(j.id, action)
	var garde := 300
	if s.horloge_monde.mode == Horloge.Mode.TEMPS_REEL:
		s.horloge_monde.avancer(3)
		while garde > 0 and s.pas("monde"):
			garde -= 1
	elif str(j.get("horloge", "monde")) == "monde":
		while garde > 0 and s.pas("monde"):
			garde -= 1
	for nom in s.combats.keys():
		garde = 300
		while garde > 0 and s.combats.has(nom) and s.pas(nom):
			garde -= 1
	EventBus.dispatcher()
	degats_joueur += maxi(0, sante_avant - int(j.sante))
	j.sante = j.sante_max   # remis à neuf : la sonde mesure les coups, pas la survie
	j.vivant = true


## Un être en combat dont le compteur est loin devant l'horloge de son combat ne rejouera jamais.
func _fige(s: Simulation, e: Dictionary) -> bool:
	return s.en_combat(e) and int(e.compteur) - s.horloge_de(e).ticks > 300


func _pas_du_joueur(s: Simulation, j: Dictionary, vers: Vector2i) -> void:
	var d := Vector2i(signi(vers.x - j.pos.x), signi(vers.y - j.pos.y))
	var essais: Array[Vector2i] = [d, Vector2i(d.x, 0), Vector2i(0, d.y)]
	for dd in essais:
		if dd == Vector2i.ZERO:
			continue
		var q: Vector2i = j.pos + dd
		if s.grille.dans(q) and not s.grille.bloque_passage(q) and s.grille.occupant(q).is_empty() and s.grille.cout_pas(j.pos, q) >= 0:
			_ronde(s, j, {"type": "deplacer", "vers": q})
			return
	_ronde(s, j)


func _recruter(s: Simulation, j: Dictionary, arme: bool = true, def_id: String = "villageois") -> Dictionary:
	for d in Grille.DIRS:
		var q: Vector2i = j.pos + d
		if s.grille.dans(q) and not s.grille.bloque_passage(q) and s.grille.occupant(q).is_empty():
			var c: Dictionary = s.ajouter(def_id, q, "ia")
			if c.is_empty():
				return {}
			s._devenir_compagnon(j, c)
			if arme:
				var epee: Dictionary = s.generer_objet("craft_epee", 1, {}, "commun", 0)
				if not epee.is_empty():
					c.sac.append(epee.uid)
					s._equiper(c, epee.uid, 0)
			return c
	return {}


# ---------------------------------------------------------------- 1. les hostiles du catalogue

func _catalogue_hostiles() -> void:
	var ids: Array = GameData.catalogues.creatures.keys()
	ids.sort()
	var n := 0
	var engagent := 0
	var approchent := 0
	var frappent := 0
	var figes := 0
	var sans_coup: Array[String] = []
	var k := 0
	for id in ids:
		var def: Dictionary = GameData.catalogues.creatures[id]
		if not (str(def.get("ai_profile", "")) in AGRESSIFS):
			continue
		k += 1
		var s := _arene(0x2A00 + k)
		var j := _joueur(s)
		var q := _libre_a(s, j.pos, 3)
		if q == Vector2i(-1, -1):
			soucis.append("%s : pas de tuile libre à trois tuiles du joueur" % id)
			continue
		var e: Dictionary = s.ajouter(str(id), q, "ia")
		if e.is_empty():
			soucis.append("%s : ne s'instancie pas" % id)
			continue
		n += 1
		var d0 := Grille.distance(e.pos, j.pos)
		var dmin := d0
		var fige := false
		var engage := false
		for r in RONDES:
			_ronde(s, j)
			dmin = mini(dmin, Grille.distance(e.pos, j.pos))
			engage = engage or s.en_combat(e)
			fige = fige or _fige(s, e)
			if not e.vivant:
				break
		var degats := _remettre(j)
		if engage:
			engagent += 1
		if dmin < d0:
			approchent += 1
		if degats > 0:
			frappent += 1
		elif engage:
			sans_coup.append(str(id))
		if fige:
			figes += 1
			soucis.append("%s : figé — compteur %d sur une horloge à t=%d" % [id, int(e.compteur), s.horloge_de(e).ticks])
		if not engage and degats == 0 and dmin >= d0:
			soucis.append("%s (%s) : à trois tuiles du joueur pendant %d rondes — ni engagé, ni approché, ni frappé" % [id, def.ai_profile, RONDES])
	print("hostiles : %d créatures posées à trois tuiles du joueur, %d rondes — %d engagent, %d approchent, %d frappent, %d figées" % [n, RONDES, engagent, approchent, frappent, figes])
	if not sans_coup.is_empty():
		print("  engagent sans blesser le joueur : " + ", ".join(sans_coup))


# ---------------------------------------------------------------- 2. les paisibles, au camp

func _catalogue_paisibles() -> void:
	var ids: Array = GameData.catalogues.creatures.keys()
	ids.sort()
	var n := 0
	var fuient := 0
	var mordent := 0
	var immobiles: Array[String] = []
	var k := 0
	for id in ids:
		var def: Dictionary = GameData.catalogues.creatures[id]
		var profil := str(def.get("ai_profile", ""))
		if not (profil in PAISIBLES) or profil == "civil":
			continue
		k += 1
		var s := _camp_sim(0x2B00 + k)
		var j := _joueur(s)
		if j.is_empty():
			soucis.append("camp : pas de joueur")
			return
		var q := _libre_a(s, j.pos, 3, false)
		if q == Vector2i(-1, -1):
			soucis.append("%s : pas de tuile libre à trois tuiles du joueur au camp" % id)
			continue
		var e: Dictionary = s.ajouter(str(id), q, "ia")
		if e.is_empty():
			soucis.append("%s : ne s'instancie pas" % id)
			continue
		n += 1
		var d0 := Grille.distance(e.pos, j.pos)
		var dmax := d0
		var bouge := false
		var attaque := false
		for r in 40:
			_ronde(s, j)
			dmax = maxi(dmax, Grille.distance(e.pos, j.pos))
			bouge = bouge or e.pos != q
			attaque = attaque or s.en_combat(e)   # le joueur ne fait qu'attendre : un combat, c'est elle qui l'a ouvert
			if not e.vivant:
				break
		var degats := _remettre(j)   # la faim du camp en prend aussi : on ne juge pas là-dessus
		if dmax > d0 + 1:
			fuient += 1
		elif not bouge:
			immobiles.append(str(id))
		if attaque:
			mordent += 1
			if profil != "bete_sauvage":
				soucis.append("%s (%s) : a attaqué le joueur qui ne faisait qu'attendre (%d dégâts)" % [id, profil, degats])
	print("paisibles : %d bêtes posées à trois tuiles du joueur au camp, 40 rondes — %d s'éloignent, %d attaquent" % [n, fuient, mordent])
	if not immobiles.is_empty():
		print("  n'ont pas bougé : " + ", ".join(immobiles))


# ---------------------------------------------------------------- 3. les types d'ennemis

func _types_d_ennemis() -> void:
	# Le tireur, au contact : il recule et tire.
	var s := _arene(0x2C01)
	var j := _joueur(s)
	var q := _libre_a(s, j.pos, 1)
	var archer: Dictionary = s.ajouter("bandit_archer", q, "ia")
	var dmax := 1
	for r in 40:
		_ronde(s, j)
		dmax = maxi(dmax, Grille.distance(archer.pos, j.pos))
	var dg := _remettre(j)
	print("tireur : l'archer posé au contact s'est éloigné jusqu'à %d tuile(s), %d dégâts au joueur" % [dmax, dg])
	if dmax < 2:
		soucis.append("tireur : l'archer ne recule jamais du contact")
	if dg == 0:
		soucis.append("tireur : l'archer n'a pas touché le joueur en 40 rondes")
	# Le soigneur : un bandit blessé à côté, il le soigne.
	s = _arene(0x2C02)
	j = _joueur(s)
	var blesse: Dictionary = s.ajouter("bandit", _libre_a(s, j.pos, 2), "ia")
	var soigneur: Dictionary = s.ajouter("guerisseur_bandit", _libre_a(s, j.pos, 3), "ia")
	blesse.sante = maxi(1, int(blesse.sante_max) / 3)
	var pv0 := int(blesse.sante)
	var pv_max := pv0
	for r in 40:
		_ronde(s, j)
		pv_max = maxi(pv_max, int(blesse.sante))
		if not blesse.vivant:
			break
	print("soigneur : le bandit blessé (%d/%d) est remonté à %d au mieux" % [pv0, int(blesse.sante_max), pv_max])
	if pv_max <= pv0:
		soucis.append("soigneur : le guérisseur n'a pas soigné le bandit blessé à une tuile de lui")
	if soigneur.is_empty():
		soucis.append("soigneur : ne s'instancie pas")
	# L'invocateur : il appelle des follets.
	s = _arene(0x2C03)
	j = _joueur(s)
	var chaman: Dictionary = s.ajouter("chaman_bandit", _libre_a(s, j.pos, 3), "ia")
	var n0 := s.vivants().size()
	var n_max := n0
	for r in 40:
		_ronde(s, j)
		n_max = maxi(n_max, s.vivants().size())
		if not chaman.vivant:
			break
	print("invocateur : %d vivants au départ, %d au plus (le chaman appelle)" % [n0, n_max])
	if n_max <= n0:
		soucis.append("invocateur : le chaman n'a rien appelé en 40 rondes")
	# L'embusqueur : à six tuiles il guette ; quand on vient, il frappe.
	s = _arene(0x2C04)
	j = _joueur(s)
	var rodeur: Dictionary = s.ajouter("rodeur", _libre_a(s, j.pos, 6), "ia")
	var depart: Vector2i = rodeur.pos
	var bouge := false
	for r in 20:
		_ronde(s, j)
		bouge = bouge or rodeur.pos != depart
	var guette := not bouge and not s.en_combat(rodeur)
	for r in 30:
		if Grille.distance(j.pos, rodeur.pos) > 1:
			_pas_du_joueur(s, j, rodeur.pos)
		else:
			_ronde(s, j)
	dg = _remettre(j)
	print("embusqueur : à six tuiles il %s ; quand le joueur vient à lui, %d dégâts" % ["guette" if guette else "vient", dg])
	if dg == 0:
		soucis.append("embusqueur : le rôdeur n'a pas frappé le joueur venu à son contact")
	# La brute blessée ne fuit pas.
	s = _arene(0x2C05)
	j = _joueur(s)
	var brute: Dictionary = s.ajouter("brute", _libre_a(s, j.pos, 2), "ia")
	brute.sante = maxi(1, int(brute.sante_max) / 10)
	dmax = 2
	for r in 30:
		_ronde(s, j)
		dmax = maxi(dmax, Grille.distance(brute.pos, j.pos))
	dg = _remettre(j)
	print("tank : la brute à 10 %% de vie s'est éloignée au plus à %d tuile(s), %d dégâts au joueur" % [dmax, dg])
	if dmax > 3:
		soucis.append("tank : la brute blessée a fui")
	# Le hostile blessé fuit (sauf au contact, où son profil préfère encore frapper).
	s = _arene(0x2C06)
	j = _joueur(s)
	var bandit: Dictionary = s.ajouter("bandit", _libre_a(s, j.pos, 3), "ia")
	bandit.sante = maxi(1, int(bandit.sante_max) / 10)
	dmax = 3
	for r in 30:
		_ronde(s, j)
		dmax = maxi(dmax, Grille.distance(bandit.pos, j.pos))
	print("blessé : le bandit à 10 %% de vie posé à trois tuiles s'est éloigné au plus à %d tuiles" % dmax)
	if dmax <= 3:
		soucis.append("blessé : le bandit à 10 % de vie n'a pas fui")
	# Le fuyard blessé, au contact.
	s = _arene(0x2C07)
	j = _joueur(s)
	var rat: Dictionary = s.ajouter("rat_geant", _libre_a(s, j.pos, 1), "ia")
	rat.sante = maxi(1, int(rat.sante_max) / 10)
	dmax = 1
	for r in 30:
		_ronde(s, j)
		dmax = maxi(dmax, Grille.distance(rat.pos, j.pos))
	print("fuyard : le rat à 10 %% de vie posé au contact s'est éloigné au plus à %d tuiles" % dmax)
	if dmax <= 1:
		soucis.append("fuyard : le rat blessé au contact n'a pas fui")
	# L'élite et son cri : un bandit à cinq tuiles, sans avoir vu le joueur, prend de l'aggro sur lui.
	s = _arene(0x2C08)
	j = _joueur(s)
	var chef: Dictionary = s.ajouter("chef_de_bande", _libre_a(s, j.pos, 3), "ia")
	var acolyte: Dictionary = s.ajouter("bandit", _libre_a(s, chef.pos, 2), "ia")   # à deux tuiles du chef : dans l'anneau de son cri
	var rallie := false
	for r in 30:
		_ronde(s, j)
		rallie = rallie or Etres.a_statut_id(acolyte, "ralliement")
	print("élite : le chef engagé, l'acolyte à deux tuiles de lui %s" % ["a été rallié par son cri" if rallie else "n'a jamais reçu le cri"])
	if chef.is_empty():
		soucis.append("élite : le chef ne s'instancie pas")
	if not rallie:
		soucis.append("élite : le chef n'a pas rallié l'acolyte à portée de son cri")


# ---------------------------------------------------------------- 4. les compagnons

func _compagnons() -> void:
	var dist_suivi := int(GameData.config("combat_rules").compagnons.distance_suivi)
	var s := _arene(0x2D01)
	var j := _joueur(s)
	var c1 := _recruter(s, j)
	var c2 := _recruter(s, j)
	if c1.is_empty() or c2.is_empty():
		soucis.append("compagnons : impossible d'en recruter deux à côté du joueur")
		return
	# a. Ils suivent : dix pas vers l'est, puis dix rondes.
	var but: Vector2i = j.pos + Vector2i(10, 0)
	for r in 12:
		_pas_du_joueur(s, j, but)
	for r in 10:
		_ronde(s, j)
	var d1 := Grille.distance(c1.pos, j.pos)
	var d2 := Grille.distance(c2.pos, j.pos)
	print("compagnons : après douze pas du joueur, ils sont à %d et %d tuiles (suivi à %d)" % [d1, d2, dist_suivi])
	if maxi(d1, d2) > dist_suivi + 2:
		soucis.append("compagnons : l'un d'eux ne suit pas (%d tuiles)" % maxi(d1, d2))
	# b. « Attends ici » : le premier reste, le second suit.
	s.ordonner(j, c1.id, "attendre")
	var poste: Vector2i = c1.pos
	but = j.pos + Vector2i(-8, 0)
	for r in 10:
		_pas_du_joueur(s, j, but)
	for r in 6:
		_ronde(s, j)
	var reste := Grille.distance(c1.pos, poste)
	d2 = Grille.distance(c2.pos, j.pos)
	print("compagnons : « attends ici » — le premier a bougé de %d tuile(s), le second est à %d du joueur" % [reste, d2])
	if reste > 1:
		soucis.append("compagnons : « attends ici » n'est pas respecté (%d tuiles)" % reste)
	if d2 > dist_suivi + 2:
		soucis.append("compagnons : le second ne suit plus (%d tuiles)" % d2)
	s.ordonner(j, c1.id, "suivre")
	for r in 20:
		_ronde(s, j)
	d1 = Grille.distance(c1.pos, j.pos)
	print("compagnons : « suis-moi » de nouveau — le premier revient à %d tuile(s)" % d1)
	if d1 > dist_suivi + 3:
		soucis.append("compagnons : après « suis-moi », le premier ne revient pas (%d tuiles)" % d1)
	# c. Le combat du maître : un bandit à deux tuiles, le joueur attend, eux frappent.
	s = _arene(0x2D02)
	j = _joueur(s)
	c1 = _recruter(s, j)
	c2 = _recruter(s, j)
	var bandit: Dictionary = s.ajouter("bandit", _libre_a(s, j.pos, 2), "ia")
	var pv0 := int(bandit.sante)
	var entres := 0
	var fige := false
	for r in 50:
		_ronde(s, j)
		entres = maxi(entres, int(s.en_combat(c1)) + int(s.en_combat(c2)))
		fige = fige or _fige(s, c1) or _fige(s, c2)
		if not bandit.vivant:
			break
	var coups := pv0 - int(bandit.sante)
	print("compagnons : contre un bandit, %d sur 2 entrent dans le combat, %d dégâts au bandit (%s), %s" % [entres, coups, "mort" if not bandit.vivant else "vivant", "l'un figé" if fige else "aucun figé"])
	if entres == 0:
		soucis.append("compagnons : aucun n'entre dans le combat du maître")
	if coups == 0:
		soucis.append("compagnons : aucun coup porté au bandit en 50 rondes")
	if fige:
		soucis.append("compagnons : un compagnon figé sur une horloge qui n'est pas la sienne")
	# d. « Évite » : un compagnon désarmé face à un bandit — il ne frappe pas, il s'écarte.
	s = _arene(0x2D03)
	j = _joueur(s)
	c1 = _recruter(s, j, false)
	s.ordonner(j, c1.id, "eviter")
	bandit = s.ajouter("bandit", _libre_a(s, j.pos, 3), "ia")
	pv0 = int(bandit.sante)
	var dmax := Grille.distance(c1.pos, bandit.pos)
	var d0 := dmax
	for r in 30:
		_ronde(s, j)
		dmax = maxi(dmax, Grille.distance(c1.pos, bandit.pos))
		if not c1.vivant:
			break
	print("compagnons : « évite » — il s'est écarté jusqu'à %d tuiles du bandit (parti de %d), %d dégâts portés" % [dmax, d0, pv0 - int(bandit.sante)])
	if pv0 - int(bandit.sante) > 0:
		soucis.append("compagnons : en posture « évite », il a frappé le bandit")
	if dmax <= d0 and c1.vivant:
		soucis.append("compagnons : en posture « évite », il ne s'écarte pas")
	# e. Agressif contre défensif : une cible à huit tuiles du maître, qui ne bouge pas (un cerf en arène). Le
	# compagnon est un aventurier (perception 10) : un villageois (6) ne la verrait pas, et ce n'est pas une IA en faute.
	for posture in ["defensive", "agressive"]:
		s = _arene(0x2D04, "plaine_au_talus")   # une plaine : dans la gorge, la cible en vue était de l'autre côté du ravin, sans chemin
		j = _joueur(s)
		c1 = _recruter(s, j, true, "aventurier")
		s.ordonner(j, c1.id, posture)
		var qc := Vector2i(-1, -1)   # en vue du compagnon ET atteignable ; à 8, sinon 7 (au-delà des 6 tuiles du défensif)
		for essai in [[8, true], [7, true], [8, false], [7, false]]:
			if qc == Vector2i(-1, -1):
				var cand := _libre_a(s, c1.pos, int(essai[0]), bool(essai[1]))
				if cand != Vector2i(-1, -1) and not s.grille.chemin(c1.pos, cand).is_empty():
					qc = cand
		if qc == Vector2i(-1, -1):
			soucis.append("compagnons : pas de tuile en vue à 7-8 tuiles pour la cible des postures")
			return
		var cerf: Dictionary = s.ajouter("cerf", qc, "ia")
		var vu := s.voit_ia(c1, cerf)
		var dc := Grille.distance(c1.pos, cerf.pos)
		if not vu:
			print("  (le compagnon ne voit pas le cerf à %d : ligne de vue %s, nuit %s, perception %d)" % [dc, str(s.grille.ligne_de_vue(c1.pos, cerf.pos)), str(s.est_nuit()), int(c1.corps.stats.perception)])
		var loin := 0
		for r in 25:
			_ronde(s, j)
			loin = maxi(loin, Grille.distance(c1.pos, j.pos))
			if not cerf.vivant:
				break
		print("compagnons : posture %s — il s'est éloigné du maître jusqu'à %d tuiles pour une cible à %d (%s, %s ; cible « %s », %s)" % [posture, loin, dc, "abattue" if not cerf.vivant else "vivante", "vue au départ" if vu else "PAS vue au départ", str(c1.get("cible", "")), "en combat" if s.en_combat(c1) else "hors combat"])
		if posture == "defensive" and loin > 3 * dist_suivi:
			soucis.append("compagnons : défensif, il s'éloigne pourtant à %d tuiles du maître" % loin)
		if posture == "agressive" and loin <= dist_suivi:
			soucis.append("compagnons : agressif, il n'a pas quitté le maître pour la cible")


# ---------------------------------------------------------------- 5. au camp : civils, garde, routine

func _camp() -> void:
	# a. Le civil fuit le loup.
	var s := _camp_sim(0x2E01)
	var j := _joueur(s)
	if j.is_empty():
		soucis.append("camp : pas de joueur")
		return
	var qv := _libre_a(s, j.pos, 4, false)
	var civil: Dictionary = s.ajouter("villageois", qv, "ia")
	var ql := _libre_a(s, civil.pos, 3, false)
	var loup: Dictionary = s.ajouter("loup", ql, "ia")
	if civil.is_empty() or loup.is_empty():
		soucis.append("camp : le villageois ou le loup ne s'instancie pas")
		return
	var d0 := Grille.distance(civil.pos, loup.pos)
	var dmax := d0
	var bouge := false
	for r in 30:
		_ronde(s, j)
		dmax = maxi(dmax, Grille.distance(civil.pos, loup.pos))
		bouge = bouge or civil.pos != qv
		if not civil.vivant:
			break
	print("camp : un loup à %d tuiles du villageois — il s'est éloigné jusqu'à %d (%s)" % [d0, dmax, "tué" if not civil.vivant else "vivant"])
	if not bouge:
		soucis.append("camp : le villageois n'a pas bougé devant le loup")
	# b. Le garde intercepte, puis rentre.
	s = _camp_sim(0x2E02)
	j = _joueur(s)
	var garde: Dictionary = s.ajouter("garde_village", _libre_a(s, j.pos, 4, false), "ia")
	loup = s.ajouter("loup", _libre_a(s, garde.pos, 5, false), "ia")
	if garde.is_empty() or loup.is_empty():
		soucis.append("camp : le garde ou le loup ne s'instancie pas")
		return
	d0 = Grille.distance(garde.pos, loup.pos)
	var dmin := d0
	var engage := false
	for r in 40:
		_ronde(s, j)
		dmin = mini(dmin, Grille.distance(garde.pos, loup.pos))
		engage = engage or s.en_combat(garde)
		if not loup.vivant:
			break
	print("camp : le garde et un loup à %d tuiles — il %s, au plus près à %d (loup %s)" % [d0, "engage" if engage else "n'engage pas", dmin, "mort" if not loup.vivant else "vivant"])
	if not engage and dmin >= d0:
		soucis.append("camp : le garde n'intercepte pas le loup")
	if loup.vivant:
		loup.vivant = false
		loup.sante = 0
		s.grille.liberer(loup.pos)
	var ancre: Vector2i = garde.ancre
	var d_ancre0 := Grille.distance(garde.pos, ancre)
	for r in 30:
		_ronde(s, j)
	var rayon := int(GameData.config("planete").routine.rayon_patrouille)
	print("camp : le loup mort, le garde était à %d de son poste, il est à %d (patrouille à %d)" % [d_ancre0, Grille.distance(garde.pos, ancre), rayon])
	if Grille.distance(garde.pos, ancre) > rayon + 2 and Grille.distance(garde.pos, ancre) >= d_ancre0:
		soucis.append("camp : le garde ne rentre pas à son poste")
	# c. La routine : poste à midi, place à 21 h, lit à 23 h.
	s = _camp_sim(0x2E03)
	j = _joueur(s)
	var v: Dictionary = s.ajouter("villageois", _libre_a(s, j.pos, 3, false), "ia")
	if v.is_empty():
		soucis.append("camp : le villageois de la routine ne s'instancie pas")
		return
	v["poste"] = _libre_a(s, v.pos + Vector2i(5, 0), 0, false) if _libre_a(s, v.pos + Vector2i(5, 0), 0, false) != Vector2i(-1, -1) else _libre_a(s, v.pos, 5, false)
	v["place"] = _libre_a(s, v.pos + Vector2i(0, 5), 0, false) if _libre_a(s, v.pos + Vector2i(0, 5), 0, false) != Vector2i(-1, -1) else _libre_a(s, v.pos, 6, false)
	v["lit"] = _libre_a(s, v.pos + Vector2i(-5, 0), 0, false) if _libre_a(s, v.pos + Vector2i(-5, 0), 0, false) != Vector2i(-1, -1) else _libre_a(s, v.pos, 4, false)
	for plage in [[12.0, "poste"], [21.0, "place"], [23.0, "lit"]]:
		_heure(s, float(plage[0]))
		var cible: Vector2i = v[str(plage[1])]
		var avant := Grille.distance(v.pos, cible)
		for r in 30:
			_ronde(s, j)
		var apres := Grille.distance(v.pos, cible)
		print("camp : à %d h, le villageois va vers %s — de %d à %d tuiles" % [int(plage[0]), str(plage[1]), avant, apres])
		if apres >= avant and avant > 1:
			soucis.append("camp : à %d h, le villageois ne va pas vers %s (%d → %d tuiles)" % [int(plage[0]), str(plage[1]), avant, apres])


# ---------------------------------------------------------------- 6. en donjon

func _donjon() -> void:
	var s := Simulation.new(0x2F01)
	s.charger_donjon("ruine", 11, 5, 1)
	var j := _joueur(s)
	if j.is_empty():
		soucis.append("donjon : pas de joueur")
		return
	var q := Vector2i(-1, -1)
	var d := 8
	while q == Vector2i(-1, -1) and d >= 4:
		q = _libre_a(s, j.pos, d, false)
		if q == Vector2i(-1, -1):
			d -= 1
	if q == Vector2i(-1, -1):
		soucis.append("donjon : aucune tuile libre en vue du joueur entre 4 et 8 tuiles")
		return
	var bandit: Dictionary = s.ajouter("bandit", q, "ia")
	var d0 := Grille.distance(bandit.pos, j.pos)
	var dmin := d0
	var engage := false
	var fige := false
	for r in 80:
		_ronde(s, j)
		dmin = mini(dmin, Grille.distance(bandit.pos, j.pos))
		engage = engage or s.en_combat(bandit)
		fige = fige or _fige(s, bandit)
	var dg := _remettre(j)
	print("donjon : un bandit à %d tuiles, le joueur attend 80 rondes — il %s, au plus près à %d, %d dégâts au joueur (monde à t=%d)" % [d0, "engage" if engage else "n'engage pas", dmin, dg, s.horloge_monde.ticks])
	if not engage and dmin >= d0:
		soucis.append("donjon : le bandit ne vient pas au joueur")
	if fige:
		soucis.append("donjon : le bandit figé — compteur %d sur une horloge à t=%d" % [int(bandit.compteur), s.horloge_de(bandit).ticks])
