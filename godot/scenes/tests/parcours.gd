extends Node
## Le parcours de donjon (Vers la production, point 13 — « essayer en profondeur le dungeon crawling ») : un robot
## joue VRAIMENT le client (main.tscn, fenêtré) — il descend étage après étage en marchant, frappe ce qu'il voit,
## ramasse ce qu'il croise, ouvre les portes, et prend des captures aux moments clés. À la fin, un rapport chiffré.
##   Godot --path godot res://scenes/tests/parcours.tscn -- --etages 3 --frames 4000 --graine 7 --theme ruine --sortie C:/dossier
var scene: Node
var jid := ""
var frames := 0
var frames_max := 4000
var etages_voulus := 3
var sortie := "C:/Users/ciryl/AppData/Local/Temp/parcours"
var graine := 7
var theme := "ruine"
var classe := ""            # --classe id : la classe du personnage (30 : tester des classes variées)
var race := ""              # --race id
var equiper := 0            # --equiper N : N objets assemblés générés, les équipables portés
var invincible := false     # --invincible : PV rendus à chaque image, pour une collecte longue
var fichier_inventaire := ""  # --inventaire <chemin> : le sac complet écrit en JSON à la fin
var sorts := 0              # --sorts N : N sorts composés au hasard (forme + noyau [+ modificateur]), lancés en combat
var rng_bot := RandomNumberGenerator.new()
var sorts_lances := 0
var sorts_refuses := 0
# le rapport
var etage_depart := 0
var etages_atteints := 0
var combats := 0
var coups_portes := 0
var coups_recus := 0
var degats_recus := 0
var morts := 0
var kills := 0
var ramassages := 0
var portes_ouvertes := 0
var pas := 0
var attentes := 0
var soins := 0
var captures := 0
var derniere_capture_frame := -999
var derniere_capture_30s := 0
var cibles_ignorees := {}      # id → image d'expiration : un duel figé (cible inatteignable) se contourne
var echecs_cible := 0
var poursuite_cible := ""      # la cible poursuivie et la distance au tour d'avant :
var poursuite_d := 999         # si la distance ne baisse jamais (kiting mutuel), la poursuite est stérile
var poursuite_sterile := 0
var progres_marqueur := []     # garde-fou d'étage : si AUCUN compteur ne bouge longtemps, on purge les cibles puis on rend le rapport
var progres_frame := 0
var purge_faite := false
var etage_vu := -1             # l'étage courant vu par le robot : la descente est automatique (escaliers réels, point 36)
var capacites_a_sec := {}      # index → image de re-essai : un sort refusé (charges, portée) se met en retrait   # une capture d'écran toutes les 30 s réelles dans <sortie>/toutes_les_30s/ (designer, 2026-08-31)
var en_combat_avant := false
var sante_avant := -1
var journal_vu := 0
var evenements: Array[String] = []
var bloque_depuis := 0
var derniere_pos := Vector2i(-1, -1)


func _ready() -> void:
	Simulation.slot_autosave = "essai_parcours"   # l'autosave du retour d'expédition ne doit jamais écraser « monde » pendant un parcours robot
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--etages" and i + 1 < args.size():
			etages_voulus = int(args[i + 1])
		elif args[i] == "--frames" and i + 1 < args.size():
			frames_max = int(args[i + 1])
		elif args[i] == "--sortie" and i + 1 < args.size():
			sortie = args[i + 1]
		elif args[i] == "--graine" and i + 1 < args.size():
			graine = int(args[i + 1])
		elif args[i] == "--theme" and i + 1 < args.size():
			theme = args[i + 1]
		elif args[i] == "--classe" and i + 1 < args.size():
			classe = args[i + 1]
		elif args[i] == "--race" and i + 1 < args.size():
			race = args[i + 1]
		elif args[i] == "--equiper" and i + 1 < args.size():
			equiper = int(args[i + 1])
		elif args[i] == "--sorts" and i + 1 < args.size():
			sorts = int(args[i + 1])
		elif args[i] == "--invincible":   # le robot ne meurt pas : on veut mesurer ce qu'il RAMASSE, pas s'il survit
			invincible = true
		elif args[i] == "--inventaire" and i + 1 < args.size():
			fichier_inventaire = str(args[i + 1])
	DirAccess.make_dir_recursive_absolute(sortie)
	DirAccess.make_dir_recursive_absolute(sortie + "/toutes_les_30s")
	rng_bot.seed = graine
	scene = load("res://scenes/demo/main.tscn").instantiate()
	add_child(scene)
	# En headless, main.gd n'ouvre jamais l'écran titre (`titre_ouvert` reste faux) : ce bloc ne tournait
	# donc JAMAIS en robot, et --classe / --race étaient ignorés sans un mot — chaque « matrice de
	# classes » jouée par le robot jouait Le Sabre (trouvé le 2026-09-04, quand il a dit qui il était).
	if scene.titre_ouvert or not classe.is_empty() or not race.is_empty():
		scene._nouvelle_partie()
		if not classe.is_empty():   # la classe et la race demandées (30 : plein de classes)
			var classes: Array = scene._classes_visibles()
			scene.creation.classe = maxi(0, classes.find(classe))
		if not race.is_empty():
			var races: Array = GameData.catalogues.races.keys()
			races.sort()
			scene.creation.race = maxi(0, races.find(race))
		scene._creer_personnage()
		scene._commencer_monde()
		scene.fiche_en_attente = {}
		scene.carte.fermer()
		scene.ecrans.fermer()
	var j: Dictionary = scene.joueur()
	jid = j.id
	scene.sim.donjon = {"etages": etages_voulus + 1}   # un donjon assez profond pour le parcours demandé
	scene.sim.charger_donjon(theme, graine, 7, 1, j)
	scene.sim.maj_vision()
	scene._apres_changement_de_grille()
	etage_depart = int(scene.sim.donjon.etage)
	sante_avant = int(scene.joueur().sante)
	_equiper_et_composer()
	EventBus.damage_dealt.connect(func(src: String, cible: String, degats: int, _d: Dictionary) -> void:
		if cible == jid:
			coups_recus += 1
			degats_recus += degats
		elif src == jid:
			coups_portes += 1)
	EventBus.creature_killed.connect(func(_id: String, tueur: String) -> void:
		if tueur == jid:
			kills += 1)
	EventBus.combat_started.connect(func(_h: String, _p: Array) -> void: combats += 1)
	EventBus.journal.connect(func(cle: StringName, _args: Dictionary) -> void:
		if str(cle) == "journal.porte_ouverte":
			portes_ouvertes += 1)
	_note("étage %d : arrivée (%d salles, %s)" % [etage_depart, int(scene.sim.donjon.salles), str(scene.sim.donjon.theme)])


## L'équipement et les sorts du parcours (30) : des objets assemblés générés et portés, des sorts composés au hasard.
func _equiper_et_composer() -> void:
	var sim = scene.sim
	var j: Dictionary = sim.entites[jid]
	# Les trois derniers étaient des PROTOTYPES non assemblés — un « Anneau » sans matière ni qualité,
	# restés là depuis l'époque où les bijoux et les boucliers n'avaient pas de version assemblée. Le
	# robot mesurait donc un personnage moins bien équipé qu'un vrai joueur (2026-09-02).
	var bases: Array = ["craft_epee", "craft_dague", "craft_masse", "craft_lance", "craft_casque", "craft_cuirasse", "craft_jambieres", "craft_bouclier", "craft_anneau", "craft_amulette"]
	# Le robot n'ecrase JAMAIS le kit de sa classe (2026-09-04) : la matrice des six voies donnait a
	# chaque classe la meme lance generee par-dessus son arme de depart — L'Engrenage se battait a la
	# lance, pas a l'arc, et la matrice ne mesurait plus les voies. Un objet genere ne s'equipe que dans
	# un emplacement encore vide ; sinon il reste au sac, et on le dit.
	for slot_k in j.equipement.keys():
		_note("kit : %s en %s" % [scene.nom_objet(sim.nom_objet(str(j.equipement[slot_k]))), str(slot_k)])
	for k in equiper:
		var base: String = bases[rng_bot.randi() % bases.size()]
		var o: Dictionary = sim.generer_objet(base, 3, {}, "rare" if rng_bot.randf() < 0.5 else "commun")
		if o.is_empty():
			continue
		j.sac.append(o.uid)
		var slot_o := str(o.get("equip_slot", ""))
		var pris: bool = j.equipement.has(slot_o) or (slot_o == "anneau" and j.equipement.has("anneau_1") and j.equipement.has("anneau_2"))
		if pris:
			_note("au sac (le kit garde l'emplacement %s) : %s" % [slot_o, scene.nom_objet(sim.nom_objet(o.uid))])
			continue
		sim.attente[jid] = true
		if sim.intention(jid, {"type": "equiper", "objet": o.uid}):
			_note("équipé : %s" % scene.nom_objet(sim.nom_objet(o.uid)))
	if sorts > 0:
		var formes: Array[String] = []
		var noyaux: Array[String] = []
		var modifs: Array[String] = []
		var portees: Array[String] = []   # la portée est un module depuis le 2026-09-01 : sans elle, tout se lance au contact
		for id in j.get("modules_connus", []):
			match str(GameData.catalogues.modules.get(str(id), {}).get("module_type", "")):
				"forme": formes.append(str(id))
				"noyau": noyaux.append(str(id))
				"modificateur": modifs.append(str(id))
				"portee": portees.append(str(id))
		for k in sorts:
			if formes.is_empty() or noyaux.is_empty():
				break
			var seq: Array = [formes[rng_bot.randi() % formes.size()], noyaux[rng_bot.randi() % noyaux.size()]]
			if not portees.is_empty():
				seq.insert(1, portees[rng_bot.randi() % portees.size()])
			if not modifs.is_empty() and rng_bot.randf() < 0.5:
				seq.append(modifs[rng_bot.randi() % modifs.size()])
			if not sim.composer_capacite(j, seq, "bot_%d" % k):
				_note("composition refusée : %s" % str(seq))
	if equiper > 0 or sorts > 0:
		Etres.recalculer(j, sim.items, sim.affixes_defs, sim.regles)
		_note("kit : %d objets équipables générés · %d sorts composés · %d capacités" % [equiper, sorts, j.capacites.size()])
		_note("personnage : classe %s · race %s" % [str(j.get("classe", "")), str(j.get("race", ""))])   # le robot dit qui il est : sans ça, --classe pouvait être ignoré sans que rien ne le montre


func _note(t: String) -> void:
	evenements.append("[f%d] %s" % [frames, t])


func _capturer(nom: String) -> void:
	if frames - derniere_capture_frame < 20:
		return
	derniere_capture_frame = frames
	# En --headless il n'y a pas de rendu : `get_texture()` rend un objet dont la texture est nulle, et
	# chaque tentative de capture crachait trois lignes d'erreur moteur dans le rapport du parcours. On
	# ne capture donc que s'il y a une fenetre — le parcours reste utile sans images.
	if DisplayServer.get_name() == "headless":
		return
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img != null:
		img.save_png("%s/%02d_%s.png" % [sortie, captures, nom])
		captures += 1


func _process(_delta: float) -> void:
	frames += 1
	if Time.get_ticks_msec() - derniere_capture_30s >= 30000 and frames > 5 and DisplayServer.get_name() != "headless":   # le film du parcours : une image toutes les 30 s
		derniere_capture_30s = Time.get_ticks_msec()
		var img30 := get_viewport().get_texture().get_image()
		if img30 != null:
			img30.save_png("%s/toutes_les_30s/%03d.png" % [sortie, Time.get_ticks_msec() / 1000])
	if frames < 5:
		return
	if frames == 5:
		_capturer("etage_%d_arrivee" % etage_depart)   # après le premier rendu, sinon l'image est noire
	var sim = scene.sim
	if not sim.entites.has(jid):
		_fin("le joueur a disparu")
		return
	var j: Dictionary = sim.entites[jid]
	if invincible and j.vivant:   # on rend les PV et l'endurance à chaque image : la collecte n'est pas un test de survie
		j.sante = int(j.sante_max)
		j.vigueur = int(j.vigueur_max)
		j.mana = int(j.mana_max)
	if invincible and not j.vivant:   # un coup peut tuer entre deux images : on relève sans compter la mort
		j.vivant = true
		j.sante = int(j.sante_max)
		j.vigueur = int(j.vigueur_max)
		j.statuts.clear()
		return
	if not j.vivant:
		morts += 1
		_note("MORT à l'étage %d (%d coups reçus, %d dégâts)" % [int(sim.donjon.etage), coups_recus, degats_recus])
		_capturer("mort")
		if morts >= 3 or frames > frames_max:
			_fin("mort")
			return
		sim.intention(jid, {"type": "respawn"})
		scene._apres_changement_de_grille()
		return
	if sim.lieu != "donjon":
		_fin("sorti du donjon")
		return
	var en_combat: bool = sim.en_combat(j)
	if en_combat and not en_combat_avant:
		_note("combat engagé à l'étage %d (%d PV)" % [int(sim.donjon.etage), int(j.sante)])
		_capturer("combat_etage_%d" % int(sim.donjon.etage))
	en_combat_avant = en_combat
	if int(j.sante) < sante_avant and int(j.sante) * 3 < int(j.sante_max):
		_capturer("pv_bas_etage_%d" % int(sim.donjon.etage))
	sante_avant = int(j.sante)
	if frames > frames_max:
		_fin("budget d'images épuisé")
		return
	if not sim.attente.has(jid):
		return
	if int(sim.donjon.get("etage", -1)) != etage_vu:   # les escaliers se prennent en marchant : on constate la descente
		if etage_vu != -1 and int(sim.donjon.get("etage", 0)) > etage_vu:
			etages_atteints += 1
			scene._apres_changement_de_grille()
			_note("descente : étage %d → %d (%d salles) · PV %d/%d" % [etage_vu, int(sim.donjon.etage), int(sim.donjon.salles), int(j.sante), int(j.sante_max)])
			_capturer("etage_%d_arrivee" % int(sim.donjon.etage))
			if etages_atteints >= etages_voulus - 1:
				_fin("%d étages descendus" % etages_atteints)
				return
		etage_vu = int(sim.donjon.get("etage", -1))
	var marqueur := [etages_atteints, kills, coups_portes, ramassages, portes_ouvertes, morts]
	if marqueur != progres_marqueur:
		progres_marqueur = marqueur
		progres_frame = frames
		purge_faite = false
	elif frames - progres_frame > 9000:
		_fin("étage %d sans progrès (aucun compteur ne bouge depuis %d images)" % [int(sim.donjon.etage), frames - progres_frame])
		return
	elif frames - progres_frame > 4000 and not purge_faite:
		purge_faite = true
		for x in sim.vivants():   # rien ne bouge depuis longtemps : on purge les cibles en vue et on file à l'escalier
			if x.id != jid and sim.ennemis(sim.entites[jid], x):
				cibles_ignorees[x.id] = frames + 4000
		_note("étage %d enlisé (%d images sans progrès) : cibles purgées, cap sur l'escalier" % [int(sim.donjon.etage), frames - progres_frame])
	# Le robot décide : frapper ce qui est en vue, ramasser, descendre, sinon marcher vers l'escalier.
	var cible := _hostile_en_vue(j)
	if not cible.is_empty():
		scene.chemin_en_cours.clear()
		if sorts > 0 and rng_bot.randf() < 0.5 and j.capacites.size() > 0:   # un sort au hasard sur la cible (30)
			var k_s: int = rng_bot.randi() % j.capacites.size()
			# Le robot lançait sans regarder son mana. Lancer à sec n'est pas REFUSÉ par le jeu : c'est la
			# SURCHAUFFE, qui prend le déficit en points de vie, doublé. Le robot se tuait donc lui-même —
			# journal du 2026-09-03 : « SURCHAUFFE : 9 de mana manquant → 18 PV » puis « tombe », combat
			# déjà gagné. Trois morts à l'étage 1 imputées à la difficulté du donjon, alors qu'aucune
			# n'était due aux ennemis. Un robot qui joue comme aucun humain ne joue ne mesure rien.
			var plan_s: Dictionary = sim.plan_capacite(j, k_s)
			# Trois monnaies depuis le 2026-09-03, et dépenser à vide se paie en PV dans les trois (surchauffe,
			# épuisement, sang-froid rompu). Le robot ne regardait que le mana : un sort de vigueur ou de
			# sang-froid partait à sec et le robot se blessait lui-même — la même erreur que la surchauffe,
			# deux monnaies plus loin (2026-09-04). On regarde la réserve de LA monnaie du sort.
			var monnaie_s := str(plan_s.get("monnaie", ""))
			var reserve_s: int = int(j.get(monnaie_s, 0)) if monnaie_s in ["mana", "vigueur", "sang_froid"] else 999999
			var cout_s: int = int(plan_s.get("ressource", 0)) if monnaie_s in ["mana", "vigueur", "sang_froid"] else 0
			if cout_s > reserve_s:
				capacites_a_sec[k_s] = frames + 300   # à sec : on repassera quand le mana sera revenu
			elif int(capacites_a_sec.get(k_s, -1)) <= frames:
				if sim.intention(jid, {"type": "capacite", "index": k_s, "cible": cible.pos}):
					sorts_lances += 1
					return
				sorts_refuses += 1
				capacites_a_sec[k_s] = frames + 2000   # à sec ou hors géométrie : on n'insiste pas à chaque tour
		var arme_b: Dictionary = Etres.arme(j, sim.items)
		var fonct_b: Dictionary = sim.fonctionnalites.get(arme_b.get("functionality", ""), {})
		var pa: Vector2i = sim.regles.portee_de(fonct_b, j.get("stats_eff", {})) if not fonct_b.is_empty() else Vector2i(1, 1)   # la perception allonge le tir : le robot vise aussi loin que le jeu le laisse
		var d_c := Grille.distance(j.pos, cible.pos)
		if str(cible.id) == poursuite_cible and d_c >= poursuite_d:
			poursuite_sterile += 1
			if poursuite_sterile > 60:   # le Rôdeur kite à notre vitesse : la distance ne baisse jamais, on le laisse filer
				cibles_ignorees[cible.id] = frames + 3000
				_note("poursuite stérile abandonnée : %s (d=%d depuis 60 tours)" % [str(cible.id), d_c])
				poursuite_sterile = 0
				poursuite_cible = ""
				return
		elif str(cible.id) != poursuite_cible:
			poursuite_sterile = 0
			poursuite_d = 999   # nouvelle cible : la mesure repart
		poursuite_cible = str(cible.id)
		poursuite_d = mini(poursuite_d, d_c)
		if d_c >= pa.x and d_c <= pa.y:
			if sim.intention(jid, {"type": "attaquer", "cible": cible.id, "lourde": false}):
				echecs_cible = 0
				poursuite_sterile = 0
				return
			var ch_r: Array = sim.grille.chemin(j.pos, cible.pos, false, cible.id, sim.refuse_nage(j))
			if ch_r.size() >= 1 and sim.intention(jid, {"type": "deplacer", "vers": ch_r[0]}):
				pas += 1   # coup refusé (ligne de vue, relief) : on bouge au lieu de camper — l'attente figeait les duels
				echecs_cible = 0
				return
		elif d_c < pa.x:   # zone morte (lance, arc) : reculer d'un pas pour retrouver la portée
			for dd in Grille.DIRS:
				var q2: Vector2i = j.pos + dd
				if sim.grille.dans(q2) and sim.grille.cout_pas(j.pos, q2, false, sim.refuse_nage(j)) >= 0 and sim.grille.occupant(q2).is_empty() and Grille.distance(q2, cible.pos) > d_c:
					if sim.intention(jid, {"type": "deplacer", "vers": q2}):
						pas += 1
						echecs_cible = 0
						return
		else:
			var ch: Array = sim.grille.chemin(j.pos, cible.pos, false, cible.id, sim.refuse_nage(j))   # sans la case de départ : [0] est le premier pas
			if ch.size() >= 1:
				if sim.intention(jid, {"type": "deplacer", "vers": ch[0]}):
					pas += 1
					echecs_cible = 0
					return
		echecs_cible += 1
		if echecs_cible > 20:   # rien ne marche contre cette cible (relief, falaise, chemin vide) : on l'abandonne et on reprend la route
			cibles_ignorees[cible.id] = frames + 3000
			_note("cible abandonnée : %s (d=%d, portée %s, ldv=%s)" % [str(cible.id), d_c, str(pa), str(sim.grille.ligne_de_vue(j.pos, cible.pos))])
			echecs_cible = 0
			return
		if sim.intention(jid, {"type": "attendre"}):
			attentes += 1
		return
	if int(j.sante) * 10 < int(j.sante_max) * 6:   # blessé : le Baume si on l'a — la santé ne revient jamais toute seule, attendre ne guérit rien
		for k in j.capacites.size():
			if "baume" in j.capacites[k].get("modules", []) and sim.intention(jid, {"type": "capacite", "index": k, "cible": j.pos}):
				soins += 1
				return
	for d in Grille.DIRS:   # un contenant à côté : on prend
		var t: Vector2i = j.pos + d
		if sim.grille.dans(t) and "contenant" in sim.grille.contenu_de(t).get("tags", []):
			if sim.intention(jid, {"type": "prendre", "vers": t}):
				ramassages += 1
				_note("ramassage à l'étage %d" % int(sim.donjon.etage))
				return
	var but: Vector2i = sim.donjon.escalier if sim.donjon.escalier != null else sim.donjon.entree
	if sim.donjon.escalier == null:
		_fin("dernier étage atteint (boss) : pas d'escalier plus bas")
		return
	var chemin: Array = sim.grille.chemin(j.pos, but, false, "", sim.refuse_nage(j))   # sans la case de départ
	if chemin.size() >= 1:
		if sim.intention(jid, {"type": "deplacer", "vers": chemin[0]}):
			pas += 1
			if j.pos == derniere_pos:
				bloque_depuis += 1
			else:
				bloque_depuis = 0
			derniere_pos = j.pos
			return
	# Surchargé devant l'eau (Eau et liquides : « larguer des objets reste le geste ») : un chemin mouillé
	# existe mais la surcharge interdit la nage — on jette du lest jusqu'à pouvoir nager.
	if sim.refuse_nage(j) and not sim.grille.chemin(j.pos, but, false, "", false).is_empty():
		if not j.sac.is_empty():
			var uid_j: String = str(j.sac.back())
			if sim.intention(jid, {"type": "jeter", "objet": uid_j}):
				_note("délesté (surcharge devant l'eau) : un objet du sac jeté · facteur %.2f" % sim.poids_de(j).facteur)
				return
		for slot in j.equipement.keys():
			if sim.intention(jid, {"type": "desequiper", "slot": str(slot)}):
				_note("délesté : %s retiré (il sera jeté au tour suivant)" % str(slot))
				return
	# Pas de chemin (porte fermée, mur, éboulis) : on creuse vers l'escalier, ou on attend.
	var dir := Vector2i(signi(but.x - j.pos.x), signi(but.y - j.pos.y))
	if dir != Vector2i.ZERO and sim.intention(jid, {"type": "creuser", "vers": j.pos + dir}):
		_note("creuse vers l'escalier (pas de chemin)")
		return
	if sim.intention(jid, {"type": "attendre"}):
		attentes += 1
	bloque_depuis += 1
	if bloque_depuis > 200:
		_fin("bloqué sans chemin vers l'escalier")


func _hostile_en_vue(j: Dictionary) -> Dictionary:
	var sim = scene.sim
	var meilleur := {}
	var dmin := 99
	for x in sim.vivants():
		if x.id == j.id or not sim.ennemis(j, x):
			continue
		if int(cibles_ignorees.get(x.id, -1)) > frames:
			continue
		var d := Grille.distance(j.pos, x.pos)
		if d <= 8 and sim.voit(j, x.pos) and d < dmin:
			dmin = d
			meilleur = x
	return meilleur


func _fin(raison: String) -> void:
	set_process(false)
	var j: Dictionary = scene.sim.entites.get(jid, {})
	_capturer("fin")
	print("PARCOURS : %s — étages descendus %d (arrivé à l'étage %d) · combats %d · coups portés %d · coups reçus %d (%d dégâts) · kills %d · morts %d · ramassages %d · portes ouvertes %d · pas %d · soins %d · sorts %d (refusés %d) · attentes %d · images %d · captures %d · PV finaux %d/%d" % [
		raison, etages_atteints, int(scene.sim.donjon.get("etage", 0)), combats, coups_portes, coups_recus, degats_recus, kills, morts, ramassages, portes_ouvertes, pas, soins, sorts_lances, sorts_refuses, attentes, frames, captures, int(j.get("sante", 0)), int(j.get("sante_max", 0))])
	if not fichier_inventaire.is_empty():   # le sac complet, en JSON, pour être lu hors du jeu
		var sim2 = scene.sim
		var lignes: Array = []
		for uid in j.get("sac", []):
			var it: Dictionary = sim2.items.get(str(uid), {})
			if it.is_empty():
				continue
			var d := {"nom": scene.nom_objet(sim2.nom_objet(str(uid))), "base": str(it.get("base", "")), "type": str(it.get("type", "")),
				"materiau": str(it.get("materiau", "")), "espece": str(it.get("espece", "")), "qualite": float(it.get("qualite", 0.0)),
				"quantite": int(it.get("quantite", 1)), "rarete": str(it.get("rarete", "")), "poids": sim2.regles.poids_objet(it, sim2.fonctionnalites),
				"slot": str(it.get("equip_slot", "")), "tags": it.get("tags", []), "affixes": [], "composants": {}, "elements": sim2.vecteur_objet(it)}
			for ax in it.get("affixes", []):
				d.affixes.append(str(ax.get("id", "")))
			for sc in it.get("composants", {}).keys():
				d.composants[str(sc)] = {"materiau": str(it.composants[sc].get("materiau", "")), "qualite": float(it.composants[sc].get("qualite", 0.0))}
			lignes.append(d)
		var eq := {}
		for slot in j.get("equipement", {}).keys():
			eq[str(slot)] = scene.nom_objet(sim2.nom_objet(str(j.equipement[slot])))
		var f := FileAccess.open(fichier_inventaire, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"sac": lignes, "equipement": eq, "or": int(j.get("or", 0)), "ramassages": ramassages}, "  "))
			f.close()
		print("inventaire écrit : %s (%d objets)" % [fichier_inventaire, lignes.size()])
	for ev in evenements:
		print("  ", ev)
	for l in scene.journal:
		print("  journal : ", l)
	get_tree().quit()
