extends Node
## Capture d'écran automatique de la scène principale (fenêtrée, pas headless) :
##   & Godot --path godot res://scenes/tests/capture.tscn -- --sortie C:/chemin/capture.png [--arene N] [--frames 60]
## Sert à vérifier le rendu sans œil humain disponible ; ne remplace pas le jugement de game feel.

var gif_images := 0      # --gif N : N images espacées, pour un GIF monté hors du jeu
var gif_pas := 8         # --gif-pas P : images de rendu entre deux prises
var gif_ticks := 6       # --gif-ticks T : ticks de simulation avancés entre deux prises
var gif_marche := 0      # --gif-marcher N : N pas du joueur entre deux prises — sans mouvement, un GIF est une image fixe
var gif_prises := 0
var scene: Node = null      # la scène du jeu, gardée pour faire vivre le monde entre deux prises de GIF
var frames := 0
var cible := 60
var sortie := "user://capture.png"
var arene := 0
var arene_nom := ""   # --arene accepte aussi un NOM : l'index laissait l'arène 0 inatteignable
var temps_max := 0.0
var temps_total := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--gif" and i + 1 < args.size():
			gif_images = int(args[i + 1])
		elif args[i] == "--gif-pas" and i + 1 < args.size():
			gif_pas = int(args[i + 1])
		elif args[i] == "--gif-ticks" and i + 1 < args.size():
			gif_ticks = int(args[i + 1])
		elif args[i] == "--gif-marcher" and i + 1 < args.size():
			gif_marche = int(args[i + 1])
		if args[i] == "--sortie" and i + 1 < args.size():
			sortie = args[i + 1]
		elif args[i] == "--frames" and i + 1 < args.size():
			cible = int(args[i + 1])
		elif args[i] == "--arene" and i + 1 < args.size():
			# Un nom plutôt qu'un index : la liste est triée, donc l'arène qui vient en tête portait
			# l'index 0 — et `if arene > 0` la rendait inatteignable (trouvé le 2026-09-02 en voulant
			# capturer le banc d'objets, qui commence par un b).
			if str(args[i + 1]).is_valid_int():
				arene = int(args[i + 1])
			else:
				arene_nom = str(args[i + 1])
	for il in args.size():   # --langue fr|en : force la locale AVANT la scène — vérifier le rendu anglais à l'écran
		if args[il] == "--langue" and il + 1 < args.size():
			TranslationServer.set_locale(str(args[il + 1]))
	if "--plein-ecran" in args:   # --plein-ecran : la fenêtre passe en plein écran AVANT la capture (README, designer 2026-08-31)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	for it in args.size():   # --fenetre L H : une fenêtre de taille CHOISIE, pour vérifier qu'aucun écran
		if args[it] == "--fenetre" and it + 2 < args.size():
			# n'est coupé quand elle rétrécit (file d'attente du designer, point 67).
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(int(args[it + 1]), int(args[it + 2])))
	scene = load("res://scenes/demo/main.tscn").instantiate()
	add_child(scene)
	for ig in args.size():   # --graine N : un monde CONNU pour les captures (sinon chaque prise tombe ailleurs)
		if args[ig] == "--graine" and ig + 1 < args.size():
			scene.graine_monde = int(args[ig + 1])
	scene.profil_sans_ui = "--sans-ui" in args
	scene.profil_sans_terrain = "--sans-terrain" in args
	if scene.titre_ouvert and "--monde" in args:   # --monde : l'écran de création du monde (designer, point 49)
		scene._nouvelle_partie()
		scene._creer_personnage()
	elif scene.titre_ouvert and "--creation" in args:   # --creation : l'écran de création du personnage
		scene._nouvelle_partie()
		for ir in args.size():   # --race id : la race sélectionnée à la création (apparence par race, point 41)
			if args[ir] == "--race" and ir + 1 < args.size():
				var races_c: Array = GameData.catalogues.races.keys()
				races_c.sort()
				scene.creation.race = maxi(0, races_c.find(str(args[ir + 1])))
				scene.ecrans.ouvrir("creation")
		for iv in args.size():   # --volet N : le volet de la création (0 personnage, 1 apparence, 2 pose)
			if args[iv] == "--volet" and iv + 1 < args.size():
				scene.creation.volet = int(args[iv + 1])
				scene.ecrans.ouvrir("creation")
		for isa in args.size():   # --saisir <segment> : clique VRAIMENT sur ce membre du pantin et le tourne (point 68)
			if args[isa] != "--saisir" or isa + 1 >= args.size():
				continue
			var ec = scene.ecrans
			ec.pose_edition = "repos"
			ec.rafraichir()
			await scene.get_tree().process_frame
			var vise := str(args[isa + 1])
			var corps: PackedVector2Array = ec.apercu_perso.corps_de(vise)
			if corps.size() < 2:
				print("SAISIE : segment inconnu ", vise)
				continue
			var milieu: Vector2 = ec.apercu_perso.position + (corps[0] + corps[1]) * 0.5 * ec.apercu_perso.scale.x
			var clic := InputEventMouseButton.new()
			clic.button_index = MOUSE_BUTTON_LEFT
			clic.pressed = true
			clic.position = milieu
			ec._pantin_entree(clic)
			print("SAISIE : visé ", vise, " → saisi ", ec.pose_segment)
			var glisse := InputEventMouseMotion.new()
			glisse.button_mask = MOUSE_BUTTON_MASK_LEFT
			glisse.position = milieu + Vector2(40, -40)
			ec._pantin_entree(glisse)
			ec.rafraichir()
	elif scene.titre_ouvert and "--charger" in args:   # --charger : le chemin Continuer de l'écran principal, à froid (Sauvegarde)
		scene._charger_partie("essai_capture")   # l'emplacement de la sonde — jamais « monde », qui peut être une vraie partie
		if scene.sim != null:
			print("charge : lieu=", scene.sim.lieu, " expedition=", str(scene.sim.expedition),
				" carte retenue=", scene.sim.monde.carte_cache.size() if scene.sim.monde != null else 0)
			Sauvegarde.effacer("essai_capture")   # la paire --sauvegarder / --charger est à usage unique : l'écran Charger reste net
	elif scene.titre_ouvert and "--parties" in args:   # --parties : l'ecran Charger, sa liste et son portrait (designer 2026-09-02)
		scene.ecrans.ouvrir("charger")
	elif scene.titre_ouvert and not ("--titre" in args):   # la capture saute l'écran principal, la création et l'écran Monde
		scene._nouvelle_partie()
		scene._creer_personnage()
		scene._commencer_monde()
		scene.fiche_en_attente = {}
		scene.carte.fermer()
	if "--village" in args and scene.sim != null:   # --village : le village le plus proche du camp, le joueur sur sa place
		var sv = scene.sim
		var c0: Vector2i = sv.monde.cellule_camp
		var cible := Vector2i(-9999, -9999)
		for r in range(1, 70):   # le monde est rectangulaire : le premier village peut être loin (2026-09-01)
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if absi(dx) != r and absi(dy) != r:
						continue
					var cv := c0 + Vector2i(dx, dy)
					if not (sv.monde.surface.terre_a(cv) and bool(sv.monde.surface.poi_de(cv).get("village", false))):
						continue
					var vv: Dictionary = sv.monde.surface.generer_cellule(cv.x, cv.y, {}, false).get("village", {})
					if vv.get("pnj", []).size() >= 4:   # un village habité, pas un lieu-dit : la capture doit montrer du monde
						cible = cv
						break
				if cible.x != -9999:
					break
			if cible.x != -9999:
				break
		if cible.x != -9999:
			sv.charger_camp({}, cible + Vector2i(1, 0))   # la cellule-camp elle-même n'a jamais de village : le camp à côté
			var ev: Dictionary = sv.monde.cellule(cible)
			var jv: Dictionary = sv.vivants().filter(func(e: Dictionary) -> bool: return e.controle == "joueur")[0]
			scene.joueur_id = jv.id
			var centre_v: Vector2i = cible * int(GameData.config("planete").taille_cellule) + Vector2i(ev.village.centre)
			if not sv.grille.occupant(centre_v).is_empty():
				centre_v = sv._tuile_libre_autour(centre_v)   # la place peut être occupée par un PNJ
			sv.grille.liberer(jv.pos)
			jv.pos = centre_v
			sv.grille.placer(jv.id, centre_v)
			sv.maj_vision()
			scene._apres_changement_de_grille()
			print("village : ", str(ev.village.get("nom", "?")), " en ", cible)
	if "--dialogue" in args and scene.sim != null:   # --dialogue : ouvre le dialogue avec le PNJ civil le plus proche (options, commerce, quêtes)
		var jq: Dictionary = scene.joueur()
		var proche_id := ""
		var proche_d := 999999
		for passe_m in [true, false]:   # un marchand d'abord (commerce visible), sinon le civil le plus proche
			for xq in scene.sim.vivants():
				if passe_m and str(xq.get("fonction", "")) != "commercant":   # l'id de fonction du marchand
					continue
				if xq.id != jq.id and str(xq.get("camp", "")) == "civil" and Grille.distance(xq.pos, jq.pos) < proche_d:
					proche_d = Grille.distance(xq.pos, jq.pos)
					proche_id = str(xq.id)
			if not proche_id.is_empty():
				break
		if not proche_id.is_empty():
			for ir in args.size():   # --relation N : la relation du PNJ avec le joueur, pour voir Recruter / Engager (2026-09-04)
				if args[ir] == "--relation" and ir + 1 < args.size():
					var xr: Dictionary = scene.sim.entites[proche_id]
					if not xr.has("social"):
						xr["social"] = {"culture": "", "relations": {}}
					xr.social.relations[jq.id] = int(args[ir + 1])
			scene.ecrans.ouvrir_dialogue(proche_id)
			print("dialogue : ", scene.sim.entites[proche_id].name_key)
			if "--commerce" in args:   # --commerce : enchaîne sur l'écran de commerce du PNJ (stock, prix, or)
				scene.ecrans.ouvrir("commerce")
	if not arene_nom.is_empty():
		var idx: int = scene.arenes.find(arene_nom)
		if idx < 0 and GameData.catalogues.get("prototype_arenas", {}).has(arene_nom):
			# Les bancs d'essai sont hors du cycle des arènes (ils passeraient en arène de démarrage) :
			# on les nomme donc directement, comme le menu le fait (point 74).
			scene.arene_banc = arene_nom
			scene._charger()
		elif idx < 0:
			print("ARENE inconnue : ", arene_nom, " — connues : ", scene.arenes)
		else:
			scene.arene_courante = idx
			scene._charger()
	elif arene > 0:
		scene.arene_courante = arene
		scene._charger()
	for im in args.size():   # --mine N : la mine sous sa terre, a l'etage N (Mine sous une cellule)
		if args[im] != "--mine" or scene.sim == null:
			continue
		var jm: Dictionary = scene.joueur()
		var cellm: Vector2i = scene.sim.monde.cellule_de(jm.pos)
		scene.sim.monde.claims[cellm] = {"role": "base"}   # on ne creuse que sur sa terre : on la lui donne
		jm.vigueur = int(jm.vigueur_max)
		scene.sim.creuser_un_puits(jm, 0)
		var vise: int = int(args[im + 1]) if im + 1 < args.size() else 1
		while int(scene.sim.donjon.get("etage", 1)) < vise:
			var jm2: Dictionary = scene.joueur()
			jm2.vigueur = int(jm2.vigueur_max)
			if not scene.sim.creuser_un_puits(jm2, 0):
				break
		scene._apres_changement_de_grille()
	if "--donjon" in args and scene.sim != null:   # --donjon : descendre dans une ruine depuis le camp (voile, brèches…)
		var jd: Dictionary = scene.joueur()
		scene.sim.charger_donjon("ruine", 7, 7, 1, jd)
		scene._apres_changement_de_grille()
	for i10 in args.size():   # --objet a,b,c : des objets générés (profondeur 3, donc assemblés et composés) dans le sac du joueur
		if args[i10] == "--objet" and i10 + 1 < args.size() and scene.sim != null:
			var jo: Dictionary = scene.joueur()
			for id_o in str(args[i10 + 1]).split(","):
				var o: Dictionary = scene.sim.generer_objet(id_o.strip_edges(), 3)
				if not o.is_empty():
					jo.sac.append(o.uid)
	for i9 in args.size():   # --explorer N : le joueur marche N pas vers l'escalier avant la capture (un étage exploré, designer 2026-08-30)
		if args[i9] == "--explorer" and i9 + 1 < args.size() and scene.sim != null:
			var se = scene.sim
			var je: Dictionary = scene.joueur()
			var but: Vector2i = se.donjon.escalier if (not se.donjon.is_empty() and se.donjon.escalier != null) else je.pos
			for pas_k in int(args[i9 + 1]):
				var garde := 200
				while garde > 0 and not se.attente.has(je.id) and je.vivant:
					se.pas("monde")
					for nom_c in se.combats.keys():
						se.pas(nom_c)
					garde -= 1
				if not je.vivant:
					break
				var chemin: Array = se.grille.chemin(je.pos, but, false, "")
				if chemin.is_empty() or not se.intention(je.id, {"type": "deplacer", "vers": chemin[0]}):
					if not se.intention(je.id, {"type": "attendre"}):
						break
			scene._apres_changement_de_grille()
			scene.journal.clear()   # la capture montre l'étage exploré, pas le récit de l'exploration
			scene.ecran_fin.clear()
			scene.xp_cumul = {}
			scene.xp_flottants = []
			scene.xp_fenetre = 0.0
	if "--porte" in args and scene.sim != null:   # --porte : le joueur devant la porte la plus proche (Génération de donjon)
		var sp = scene.sim
		var jp: Dictionary = scene.joueur()
		var meilleure := Vector2i(-1, -1)
		var dmin := 1 << 30
		for dy in range(-25, 26):
			for dx in range(-25, 26):
				var pos: Vector2i = jp.pos + Vector2i(dx, dy)
				if not sp.grille.dans(pos) or not ("porte" in sp.grille.contenu_de(pos).get("tags", [])):
					continue
				var dp: int = absi(dx) + absi(dy)
				if dp < dmin:
					dmin = dp
					meilleure = pos
		if meilleure != Vector2i(-1, -1):
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var libre: Vector2i = meilleure + dv
				if sp.grille.dans(libre) and not sp.grille.bloque_passage(libre) and sp.grille.occupant(libre).is_empty():
					sp.grille.liberer(jp.pos)
					jp["pos"] = libre
					sp.grille.placer(jp.id, libre)
					break
			scene._apres_changement_de_grille()
	for i3 in args.size():   # --heure H : l'heure du monde (cycle jour-nuit) — après le chargement, qui remet l'horloge
		if args[i3] == "--heure" and i3 + 1 < args.size() and scene.sim != null:
			scene.sim.horloge_monde.ticks = int(float(args[i3 + 1]) / 24.0 * 24000.0)
			scene.sim.maj_vision()
			scene._maj_ambiance()
	for im in args.size():   # --meteo id : force la météo (triche) — pluie, orage, neige, brouillard…
		if args[im] == "--meteo" and im + 1 < args.size() and scene.sim != null:
			scene.sim.triche(scene.joueur(), "meteo", str(args[im + 1]))
			scene.sim._maj_etats_meteo()   # les drapeaux neige / gel suivent tout de suite (sinon : au prochain pas d'horloge)
			scene._apres_changement_de_grille()   # le terrain reteinte (sol blanchi, glace pâle)
	if "--feu" in args and scene.sim != null:   # --feu : enflamme les tuiles inflammables autour du joueur (flammes, halo, dangers)
		var jf: Dictionary = scene.joueur()
		var n_feux := 0
		for r_f in range(1, 16):
			for dy_f in range(-r_f, r_f + 1):
				for dx_f in range(-r_f, r_f + 1):
					if absi(dx_f) != r_f and absi(dy_f) != r_f:
						continue
					var t_f: Vector2i = jf.pos + Vector2i(dx_f, dy_f)
					if scene.sim.grille.dans(t_f) and n_feux < 5 and scene.sim._enflammer(t_f):
						n_feux += 1
			if n_feux >= 5:
				break
		print("feux allumés : ", n_feux)
	if "--dormir" in args and scene.sim != null:   # --dormir : pose un lit devant le joueur et y dort (saut de sommeil, Reposé)
		var jd: Dictionary = scene.joueur()
		var lit_d: Dictionary = scene.sim.generer_objet("meuble_lit_de_paille", 1)
		scene.sim.donner(jd, lit_d.uid)
		var devant_d: Vector2i = jd.pos   # une tuile libre adjacente pour le lit — la case fixe peut être bloquée
		for d_l in Grille.DIRS:
			var c_l: Vector2i = jd.pos + d_l
			if scene.sim.grille.dans(c_l) and not scene.sim.grille.bloque_passage(c_l) and scene.sim.grille.occupant(c_l).is_empty():
				devant_d = c_l
				break
		scene.sim.attente[jd.id] = true
		print("poser lit : ", scene.sim.intention(jd.id, {"type": "poser", "objet": lit_d.uid, "vers": devant_d}))
		scene.sim.attente[jd.id] = true
		print("dormir : ", scene.sim.intention(jd.id, {"type": "dormir", "vers": devant_d}), " · heure ", "%.1f" % scene.sim.heure())
		scene._apres_changement_de_grille()
	if "--torche" in args and scene.sim != null:   # --torche : une torche en main (Éclairage, la nuit)
		var jt0: Dictionary = scene.joueur()
		var torche: Dictionary = scene.sim.generer_objet("torche", 1, {}, "commun", 0)
		if not torche.is_empty():
			jt0.sac.append(torche.uid)
			jt0.equipement["main_secondaire"] = torche.uid
			jt0["vue_sale"] = true
			scene.sim.maj_vision()
			scene._maj_ambiance()
	if "--raid" in args and scene.sim != null:   # --raid : un raid réel en cours (Défense et raids)
		scene.sim._lancer_raid_reel(12.0, scene.sim.horloge_monde.ticks)
		for k in 6:
			scene.sim.pas("monde")
		scene._apres_changement_de_grille()
	if "--talents" in args and scene.sim != null:   # --talents : brèches, affût, lame fantôme, trésor détecté, masque — pour voir les couches récentes
		var sim = scene.sim
		var jt: Dictionary = scene.joueur()
		var t0: int = sim.horloge_monde.ticks
		for d in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(-1, 0), Vector2i(-2, 0), Vector2i(0, -1), Vector2i(3, 0), Vector2i(-3, 0)]:
			var q: Vector2i = jt.pos + d
			if sim.grille.dans(q) and sim.grille.occupant(q).is_empty():
				sim.grille.contenu[sim.grille.idx(q)] = 0
				sim.grille.hauteurs[sim.grille.idx(q)] = sim.grille.h(jt.pos)
		jt["talents_appris"] = ["breche", "affut", "masques"]
		jt["tags_acquis_race"] = ["detection_tresors"]
		sim._contreparties(jt)
		sim._poser_portail(jt, jt.pos + Vector2i(1, 0), t0)
		sim._poser_portail(jt, jt.pos + Vector2i(0, 2), t0)
		sim._deployer_affut(jt, jt.pos + Vector2i(-1, 0), t0)
		sim._porter_masque(jt, "masque_du_taureau", t0)
		jt.mana = 60
		sim._invoquer_arme_fantome(jt, "feu", t0)
		sim.contenants[sim.grille.idx(jt.pos + Vector2i(3, 0))] = ["capture_tresor"]
		sim.grille.poser_contenu(jt.pos + Vector2i(3, 0), "coffre")
		jt["vue_sale"] = true
		sim.maj_vision()
		scene._apres_changement_de_grille()
	for il2 in args.size():   # --loot N : N objets assemblés au hasard dans le sac, les meilleurs équipés
		if args[il2] == "--loot" and il2 + 1 < args.size() and scene.sim != null:
			var jl: Dictionary = scene.joueur()
			var rngl := RandomNumberGenerator.new()
			rngl.seed = 20260901
			for k in int(args[il2 + 1]):
				var base_l := str(scene.sim.loot._base_pour(rngl))
				var ol: Dictionary = scene.sim.generer_objet(base_l, 6, {}, ["commun", "rare", "exceptionnel"][k % 3], k % 3)
				if ol.is_empty():
					continue
				scene.sim.donner(jl, ol.uid)
				if not str(ol.get("equip_slot", "")).is_empty():
					scene.sim.intention(jl.id, {"type": "equiper", "objet": ol.uid})
					scene.sim.attente[jl.id] = true
			scene.sim.maj_vision()
	for im2 in args.size():   # --marcher N : N pas au hasard, pour révéler les alentours avant la capture
		if args[im2] == "--marcher" and im2 + 1 < args.size() and scene.sim != null:
			var jm: Dictionary = scene.joueur()
			for k in int(args[im2 + 1]):
				var dirs: Array = Grille.DIRS.duplicate()
				dirs.shuffle()
				for d in dirs:
					scene.sim.attente[jm.id] = true
					if scene.sim.intention(jm.id, {"type": "deplacer", "vers": jm.pos + d}):
						break
			scene.sim.maj_vision()
			scene._apres_changement_de_grille()
	for i6 in args.size():   # --creature id[,id…] : des créatures posées autour du joueur (triche) — timeline, états, bulles
		if args[i6] == "--creature" and i6 + 1 < args.size():
			var jc2: Dictionary = scene.joueur()
			for cid in args[i6 + 1].split(","):
				scene.sim.triche(jc2, "creature", str(cid))
			scene.sim.maj_vision()
			var vivants_c: Array = scene.sim.vivants()
			if not vivants_c.is_empty():
				scene.survol = vivants_c.back().pos   # la dernière posée est sous la souris : bulle, prévisualisation
	for i9 in args.size():   # --capacite a,b,c : compose cette capacité au joueur et la met en visée (poussées, formes)
		if args[i9] == "--capacite" and i9 + 1 < args.size():
			var jc3: Dictionary = scene.joueur()
			for m in args[i9 + 1].split(","):
				scene.sim.crediter_module(jc3, str(m), 9)
			if scene.sim.composer_capacite(jc3, Array(args[i9 + 1].split(","))):
				scene.visee = jc3.capacites.size() - 1
	for i8 in args.size():   # --visee N : la capacité N du joueur en cours de visée (ligne de vue, forme, bulle)
		if args[i8] == "--visee" and i8 + 1 < args.size():
			scene.visee = int(args[i8 + 1])
	if "--modules" in args and scene.sim != null:   # --modules : tout le catalogue appris, pour montrer le composeur plein
		scene.sim.triche(scene.joueur(), "modules")
	for isort in args.size():   # --sorts a,b|c,d : des capacités composées, pour garnir la hotbar et l'écran des capacités
		if args[isort] == "--sorts" and isort + 1 < args.size() and scene.sim != null:
			var js: Dictionary = scene.joueur()
			for seq_s in args[isort + 1].split("|"):
				var mods_s: Array = Array(seq_s.split(","))
				for m_s in mods_s:
					scene.sim.crediter_module(js, str(m_s))
				scene.sim.composer_capacite(js, mods_s)
	for ip in args.size():   # --pose seg:angle[,seg:angle…] : une pose de repos, pour juger l'articulation
		if args[ip] == "--pose" and ip + 1 < args.size() and scene.sim != null:
			var jp: Dictionary = scene.joueur()
			var po := {}
			for paire in args[ip + 1].split(","):
				var kv: PackedStringArray = paire.split(":")
				if kv.size() == 2:
					po[str(kv[0])] = float(kv[1])
			jp["poses"] = {"repos": po}
			scene._apres_changement_de_grille()
	for ich in args.size():   # --chaine el[,el…] : des segments posés dans la jauge (le clignotement, point 60)
		if args[ich] == "--chaine" and ich + 1 < args.size() and scene.sim != null:
			var jch: Dictionary = scene.joueur()
			for el in args[ich + 1].split(","):
				scene.sim.wuxing.poser(jch.chaine, str(el), scene.sim.horloge_de(jch).ticks)
	for i7 in args.size():   # --statut id[,id…] : des statuts sur le joueur (triche) — les puces de la timeline
		if args[i7] == "--statut" and i7 + 1 < args.size():
			for sid in args[i7 + 1].split(","):
				scene.sim.triche(scene.joueur(), "statut", str(sid))
	for i4 in args.size():   # --sequence a,b,c : une séquence pré-remplie dans le composeur (et ses charges)
		if args[i4] == "--sequence" and i4 + 1 < args.size():
			var seq: Array = Array(args[i4 + 1].split(","))
			var jc: Dictionary = scene.joueur()
			for m in seq:
				scene.sim.crediter_module(jc, str(m), 9)
			scene.ecrans.sequence_composee = seq
	for i4b in args.size():   # --crans a,b,c : le cran de chaque pièce de --sequence (designer 2026-09-04)
		if args[i4b] == "--crans" and i4b + 1 < args.size():
			var crans_c: Array = []
			for c in args[i4b + 1].split(","):
				crans_c.append(int(c))
			scene.ecrans.crans_composes = crans_c
	if "--planche-combinaisons" in args and scene.sim != null:
		# Toutes les combinaisons portée × forme, en une planche par portée (designer 2026-09-01) : on
		# recompose la séquence, on laisse une image se dessiner, et on découpe l'aperçu dans la fenêtre.
		cible = 1 << 30   # la capture ordinaire ne doit pas quitter pendant que la planche se construit
		var jp2: Dictionary = scene.joueur()
		var portees: Array = []
		var formes: Array = []
		for mid: String in GameData.catalogues.modules.keys():
			var md: Dictionary = GameData.catalogues.modules[mid]
			if str(md.get("module_type", "")) == "portee":
				portees.append(mid)
			elif str(md.get("module_type", "")) == "forme":
				formes.append(mid)
		portees.sort()
		formes.sort()
		for m2 in portees + formes + ["etincelle"]:
			scene.sim.crediter_module(jp2, str(m2), 9)
		scene.ecrans.ouvrir("composer")
		var titre_r := Rect2i(40, 48, 470, 22)     # « COMPOSER — Portée → Forme → Noyau »
		var ap_r := Rect2i(700, 745, 235, 262)     # la grille d'aperçu et sa légende
		var tuile := Vector2i(maxi(titre_r.size.x, ap_r.size.x), titre_r.size.y + ap_r.size.y + 6)
		for ip in portees.size():
			var cols := 4
			var lignes := int(ceil(float(formes.size()) / float(cols)))
			var planche := Image.create(tuile.x * cols, tuile.y * lignes, false, Image.FORMAT_RGBA8)
			planche.fill(Color(0.05, 0.05, 0.06))
			for iff in formes.size():
				scene.ecrans.sequence_composee = [portees[ip], formes[iff], "etincelle"]
				scene.ecrans.rafraichir()
				await scene.get_tree().process_frame
				await scene.get_tree().process_frame
				var vue := scene.get_viewport().get_texture().get_image()
				vue.convert(Image.FORMAT_RGBA8)   # la fenetre rend en RGB8 : blit_rect exige le meme format
				var ou := Vector2i((iff % cols) * tuile.x, (iff / cols) * tuile.y)
				planche.blit_rect(vue, titre_r, ou)
				planche.blit_rect(vue, ap_r, ou + Vector2i(0, titre_r.size.y + 6))
			planche.save_png("%s/portee_%s.png" % [sortie.get_base_dir(), str(portees[ip])])
			print("planche : ", portees[ip])
		get_tree().quit()
		return
	for ipr in args.size():   # --perimetre bois|minerai|plantes : un périmètre de récolte sur la cellule du camp (Gestion de base, 2026-09-04)
		if args[ipr] == "--perimetre" and ipr + 1 < args.size() and scene.sim != null and scene.sim.monde != null:
			var jp: Dictionary = scene.joueur()   # dessiné : un rectangle de 6×4 à l'est du joueur, pour voir la teinte sur la carte
			scene.sim.dessiner_perimetre(jp.pos + Vector2i(2, -1), jp.pos + Vector2i(7, 2), str(args[ipr + 1]))
	for i2 in args.size():   # --ecran inventaire|atelier|feuille|menu : l'écran ouvert — après le chargement
		if args[i2] == "--ecran" and i2 + 1 < args.size():
			scene.ecrans.ouvrir(args[i2 + 1])
	for i11 in args.size():   # --tri colonne : trie la liste de l'inventaire (nom, type, qualite, poids, quantite)
		if args[i11] == "--tri" and i11 + 1 < args.size() and scene.ecrans.est_ouvert():
			scene.ecrans.inventaire_visuel.trier(str(args[i11 + 1]))
	for i5 in args.size():   # --selection N : la ligne sélectionnée dans l'écran ouvert (son détail s'affiche)
		if args[i5] == "--selection" and i5 + 1 < args.size() and scene.ecrans.est_ouvert():
			if scene.ecrans.courant == "composer":
				scene.ecrans.composeur.selectionner(int(args[i5 + 1]))
			else:
				scene.ecrans.selection = int(args[i5 + 1])
				scene.ecrans.liste.select(scene.ecrans.selection)
				scene.ecrans._montrer_detail()
	# Un survol simulé sur une créature, pour voir la prévisualisation.
	var j: Dictionary = scene.joueur()
	var plus_proche := 999999
	for e in scene.sim.vivants():   # la créature la plus proche du joueur est sous la souris (bulle, prévisualisation)
		if e.id != j.id and Grille.distance(e.pos, j.pos) < plus_proche:
			plus_proche = Grille.distance(e.pos, j.pos)
			scene.survol = e.pos
	for ir in args.size():   # --revele N : marque explorées les cellules à N cases autour du camp, pour
		if args[ir] == "--revele" and ir + 1 < args.size() and scene.sim != null and scene.sim.monde != null:
			# que la carte montre ce qu'un joueur finirait par voir (gouffres, donjons, royaumes).
			var m_r = scene.sim.monde
			var n_r: int = m_r.taille / 32
			for dy_r in range(-int(args[ir + 1]), int(args[ir + 1]) + 1):
				for dx_r in range(-int(args[ir + 1]), int(args[ir + 1]) + 1):
					var c_r: Vector2i = m_r.cellule_camp + Vector2i(dx_r, dy_r)
					m_r.explores[Vector2i(c_r.x * n_r, c_r.y * n_r)] = true
	if "--carte" in args:   # la carte s'ouvre après l'exploration : elle montre ce que le joueur a vu
		scene.carte.ouvrir("voyage")
		scene.carte.dessin.queue_redraw()
		await scene.get_tree().process_frame
		await scene.get_tree().process_frame
		print("carte : %d cellules retenues" % scene.sim.monde.carte_cache.size())
	# « Après la mise en place », c'est bien après TOUT : la sauvegarde était écrite avant l'ouverture des
	# écrans, donc elle ne contenait jamais ce qu'ils avaient produit — le souvenir de la carte, entre
	# autres, ressortait vide et je l'ai cru cassé (2026-09-02).
	if "--sauvegarder" in args and scene.sim != null:
		print("sauvegarde : ", scene.sim.sauvegarder("essai_capture"))   # jamais « monde », qui peut être une vraie partie
	if "--debug-survol" in args:
		print("survol=", scene.survol, " occ=", scene.sim.grille.occupant(scene.survol), " voit=", scene.sim.voit(j, scene.survol), " ecran=", scene.ecrans.est_ouvert(), " j=", j.pos)


func _process(delta: float) -> void:
	frames += 1
	if frames > 5:   # les premières images chargent ; on mesure ensuite (critère É0 : 60 fps)
		temps_max = maxf(temps_max, delta)
		temps_total += delta
	if gif_images > 0 and frames >= 5 and (frames - 5) % maxi(1, gif_pas) == 0 and gif_prises < gif_images:
		var img_g := get_viewport().get_texture().get_image()
		if img_g != null and not img_g.is_empty():
			img_g.save_png("%s_%02d.png" % [sortie.get_basename(), gif_prises])
		gif_prises += 1
		if scene.sim != null and gif_marche > 0:   # le joueur marche entre deux prises : c'est ça qui fait le film
			var jg: Dictionary = scene.joueur()
			var rng_g := RandomNumberGenerator.new()
			rng_g.seed = hash([gif_prises, "gif"])
			for _p in gif_marche:
				var garde_g := 60
				while garde_g > 0 and not scene.sim.attente.has(jg.id) and jg.vivant:
					scene.sim.pas("monde")
					for nom_g in scene.sim.combats.keys():
						scene.sim.pas(nom_g)
					garde_g -= 1
				var dirs: Array = Grille.DIRS.duplicate()
				dirs.shuffle()
				for d_g in dirs:
					if scene.sim.intention(jg.id, {"type": "deplacer", "vers": jg.pos + d_g}):
						break
		if scene.sim != null and gif_ticks > 0:   # le monde vit entre deux prises : sans ça le GIF est fixe
			for _t in gif_ticks:
				scene.sim.pas("monde")
				for nom_c in scene.sim.combats.keys():
					scene.sim.pas(nom_c)
			scene._apres_changement_de_grille()
		if gif_prises >= gif_images:
			print("gif : %d images -> %s_XX.png" % [gif_prises, sortie.get_basename()])
			get_tree().quit()
			return
		return
	if frames == cible:
		var img := get_viewport().get_texture().get_image()
		if img == null or img.is_empty():   # headless : pas d'image — on quitte quand même (sinon le processus reste)
			print("capture impossible (headless ?) — sortie")
			get_tree().quit()
			return
		img.save_png(sortie)
		print("capture : ", sortie)
		print("image : moyenne %.1f ms, pire %.1f ms sur %d images" % [temps_total / float(frames - 5) * 1000.0, temps_max * 1000.0, frames - 5])
		get_tree().quit()
