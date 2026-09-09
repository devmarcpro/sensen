extends Node
## Sonde des écrans : RIEN ne doit sortir du panneau, et le panneau ne doit pas sortir de la fenêtre
## (designer 2026-09-02 : « l'interface, fais en sorte que tout soit toujours visible à l'écran sans
## être coupé »). La capture montre le symptôme ; elle ne dit pas QUI déborde ni de combien. La sonde
## le dit : elle ouvre chaque écran à plusieurs tailles de fenêtre et nomme les Control dont le
## rectangle sort du cadre, avec leur excédent en pixels.
##   Godot --headless --path godot res://scenes/tests/sonde_ecrans.tscn
## Un écran fautif fait échouer la sonde : c'est la seule façon que la règle « rien n'est coupé »
## reste vraie après coup, au lieu d'être vérifiée une fois puis reperdue au premier ajout.

const TAILLES := [Vector2i(900, 560), Vector2i(1000, 620), Vector2i(1280, 720), Vector2i(1600, 900)]
const ECRANS := ["inventaire", "atelier", "feuille", "anatomie", "menu", "options", "capacites", "quetes", "gestion"]
const MARGE := 2.0   # l'arrondi de mise en page vaut bien deux pixels ; au-delà, c'est coupé

var fautes: Array = []


func _ready() -> void:
	var scene: Node = load("res://scenes/demo/main.tscn").instantiate()
	add_child(scene)
	for k in 6:
		await get_tree().process_frame
	var ec = scene.ecrans
	for t in TAILLES:
		DisplayServer.window_set_size(t)
		get_tree().root.size = t
		for k in 3:
			await get_tree().process_frame
		for nom in ECRANS:
			ec.ouvrir(nom)
			for k in 3:
				await get_tree().process_frame
			_verifier(ec, nom, t)
		ec.fermer()
	_verifier_pages_et_tri(scene, ec)
	await _verifier_objets(scene, ec)
	await _verifier_coffre(scene, ec)
	await _verifier_depouille(scene, ec)
	await _verifier_menu_contexte(scene, ec)
	await _verifier_pause(scene, ec)
	await _verifier_ecran_mort(scene, ec)
	_verifier_controles()
	await _verifier_aide(scene, ec)
	for f in fautes:
		print(f)
	if not fautes.is_empty():
		print("SONDE ECRANS : ECHEC — %d debordement(s)" % fautes.size())
		get_tree().quit(1)
		return
	print("sonde ecrans : rien ne sort du cadre, a %d tailles de fenetre" % TAILLES.size())
	get_tree().quit()


## Le panneau tient-il dans la fenêtre, et son contenu tient-il dans le panneau ?
func _verifier(ec: Node, nom: String, t: Vector2i) -> void:
	var p: Control = ec.panneau
	if p.size.x > float(t.x) + MARGE or p.size.y > float(t.y) + MARGE:
		fautes.append("  %-11s %dx%d : le PANNEAU deborde de la fenetre (%.0fx%.0f)" % [nom, t.x, t.y, p.size.x, p.size.y])
		# Dire QUI l'a poussé : sans ça on cherche le coupable a tatons dans un arbre de cinquante Control.
		for n in _controls(p):
			var mn: Vector2 = (n as Control).get_combined_minimum_size()
			if mn.x > 120.0 or mn.y > 120.0:
				fautes.append("      minimum %6.0fx%-6.0f %s" % [mn.x, mn.y, _chemin(n, p)])
	var cadre := Rect2(p.global_position, p.size)
	for n in _controls(p):
		if not n.is_visible_in_tree() or n.size == Vector2.ZERO:
			continue
		var r := Rect2(n.global_position, n.size)
		var dx: float = maxf(cadre.position.x - r.position.x, r.end.x - cadre.end.x)
		var dy: float = maxf(cadre.position.y - r.position.y, r.end.y - cadre.end.y)
		if dx > MARGE or dy > MARGE:
			fautes.append("  %-11s %dx%d : %s sort de %.0f px en x, %.0f px en y" % [nom, t.x, t.y, _chemin(n, p), maxf(dx, 0.0), maxf(dy, 0.0)])


## Les Control du panneau, sans descendre DANS ceux qui rognent : `clip_contents` est une promesse
## tenue — ce qui dépasse à l'intérieur est réellement coupé au bord, donc invisible, donc innocent.
func _controls(n: Node) -> Array:
	var r: Array = []
	for e in n.get_children():
		if e is Control:
			r.append(e)
			if not (e as Control).clip_contents:
				r.append_array(_controls(e))
	return r


func _chemin(n: Node, jusqu_a: Node) -> String:
	var parts: Array = []
	var c: Node = n
	while c != null and c != jusqu_a:
		parts.push_front("%s(%s)" % [c.name, c.get_class()])
		c = c.get_parent()
	return "/".join(parts)


## Les pages et le tri (designer 2026-09-06, 19 h 20 : « le tri affecte que la page, pas l'inventaire dans sa totalité ») :
## quarante matières dans le sac, le tri par nom, puis toutes les pages parcourues — la suite des noms doit être triée
## d'un bout à l'autre, et compter tout le sac.
## LA PAUSE (Ordre de travail, palier 3 — 2026-09-08). Le monde ne doit pas avancer pendant qu'un écran est ouvert.
## C'est la seule sonde qui puisse le prouver : elle monte `main.tscn` en entier, donc `_process_corps` tourne pour de
## vrai. La suite headless, elle, ne monte jamais le client — c'est pourquoi ce défaut a vécu si longtemps.
func _verifier_pause(scene: Node, ec) -> void:
	ec.fermer()
	for k in 4:
		await get_tree().process_frame
	# 1. écran fermé : le monde DOIT avancer, sinon la sonde ne prouverait rien.
	var avant: int = int(scene.sim.horloge_monde.ticks)
	for k in 20:
		await get_tree().process_frame
	var ouvert_avance: int = int(scene.sim.horloge_monde.ticks) - avant
	# 2. écran ouvert : le monde ne doit plus bouger d'un tick.
	ec.ouvrir("inventaire")
	for k in 4:
		await get_tree().process_frame
	var fige: int = int(scene.sim.horloge_monde.ticks)
	for k in 20:
		await get_tree().process_frame
	var pendant: int = int(scene.sim.horloge_monde.ticks) - fige
	ec.fermer()
	if ouvert_avance <= 0:
		fautes.append("  pause : le monde n'avance meme pas ecran ferme (%d ticks) — la sonde ne prouve rien" % ouvert_avance)
	if pendant != 0:
		fautes.append("  pause : le monde a avance de %d ticks avec un ecran ouvert (attendu 0)" % pendant)
	if ouvert_avance > 0 and pendant == 0:
		print("  pause : le monde avance de %d ticks ecran ferme, 0 ecran ouvert" % ouvert_avance)


## L'ÉCRAN DE MORT (Ordre de travail, palier 3 — 2026-09-08). Avant, la défaite était une ligne de journal et
## n'importe quelle touche relevait le joueur. On vérifie qu'un joueur mort ouvre l'écran, que le monde s'arrête
## derrière, et que « Se relever » — et lui seul — le remet debout.
func _verifier_ecran_mort(scene: Node, ec) -> void:
	ec.fermer()
	for k in 3:
		await get_tree().process_frame
	var j: Dictionary = scene.joueur()
	if j.is_empty():
		fautes.append("  mort : pas de joueur pour l'essai")
		return
	j.vivant = false   # on le tue à la main : la sonde juge l'écran, pas le combat
	var touche := InputEventKey.new()
	touche.keycode = KEY_W
	touche.pressed = true
	scene._unhandled_input(touche)
	for k in 3:
		await get_tree().process_frame
	if str(ec.courant) != "mort":
		fautes.append("  mort : une touche sur un joueur mort n'ouvre pas l'ecran (courant = %s)" % str(ec.courant))
		j.vivant = true
		ec.fermer()
		return
	if j.vivant:
		fautes.append("  mort : la touche a releve le joueur au lieu d'ouvrir l'ecran — c'est le defaut qu'on repare")
	var avant: int = int(scene.sim.horloge_monde.ticks)
	for k in 15:
		await get_tree().process_frame
	if int(scene.sim.horloge_monde.ticks) != avant:
		fautes.append("  mort : le monde avance (%d ticks) derriere l'ecran de mort" % (int(scene.sim.horloge_monde.ticks) - avant))
	var options := 0
	for en in ec.entrees:
		if str(en.get("kind", "")) == "mort":
			options += 1
	if options < 2:
		fautes.append("  mort : l'ecran n'offre que %d choix (attendu au moins « se relever » et « titre »)" % options)
	ec.fermer()
	scene._relever_le_joueur()
	for k in 3:
		await get_tree().process_frame
	if not scene.joueur().get("vivant", false):
		fautes.append("  mort : « se relever » n'a pas remis le joueur debout")
	else:
		print("  mort : l'ecran s'ouvre, le monde s'arrete derriere, %d choix, « se relever » fonctionne" % options)


## L'INPUTMAP (Ordre de travail, palier 3 — 2026-09-08). La section `[input]` de `project.godot` était LITTÉRALEMENT
## vide et les quatorze touches de `main.gd` étaient écrites en dur : le jeu n'était jouable qu'en AZERTY. On vérifie
## que chaque action déclarée existe avec une touche, que la marche passe bien par la POSITION physique (c'est elle qui
## rend ZQSD et WASD équivalents), et qu'un remappage tient puis se relit.
func _verifier_controles() -> void:
	var actions: Dictionary = Reglages.actions()
	if actions.is_empty():
		fautes.append("  controles : aucune action declaree")
		return
	for nom in actions.keys():
		if not InputMap.has_action(StringName(nom)):
			fautes.append("  controles : l'action %s n'est pas dans l'InputMap" % str(nom))
			continue
		var evs: Array = InputMap.action_get_events(StringName(nom))
		if evs.is_empty():
			fautes.append("  controles : l'action %s n'a aucune touche" % str(nom))
			continue
		var ev: InputEventKey = evs[0]
		var veut_physique: bool = bool(actions[nom].get("physique", true))
		var est_physique: bool = ev.physical_keycode != KEY_NONE
		if veut_physique != est_physique:
			fautes.append("  controles : %s devrait etre %s" % [str(nom), "physique" if veut_physique else "une lettre"])
		if str(Reglages.touche_de(str(nom))).is_empty() or Reglages.touche_de(str(nom)) == "?":
			fautes.append("  controles : %s n'a pas de nom de touche lisible" % str(nom))
	# Un remappage tient, et Echap refuse d'etre remappe. On compare au DEFAUT DES DONNEES et non a la valeur
	# courante : `remapper` ECRIT dans user://options.cfg, donc un essai precedent survit d'un lancement a l'autre —
	# ce qui prouve la persistance, mais rendait ce controle faux la seconde fois. On nettoie derriere soi.
	var defaut := str(actions["ramasser"].get("touche", ""))
	if not Reglages.remapper("ramasser", "K"):
		fautes.append("  controles : impossible de remapper une action pourtant remappable")
	elif Reglages.touche_de("ramasser") != "K":
		fautes.append("  controles : le remappage n'a pas pris (%s)" % Reglages.touche_de("ramasser"))
	Reglages.remappages.erase("ramasser")
	Reglages.construire_input_map()
	Reglages.enregistrer()   # sinon l'essai fuit dans les reglages du joueur et fausse le prochain lancement
	if Reglages.touche_de("ramasser") != defaut:
		fautes.append("  controles : le retour au defaut n'a pas marche (%s au lieu de %s)" % [Reglages.touche_de("ramasser"), defaut])
	if Reglages.remapper("annuler", "K"):
		fautes.append("  controles : Echap s'est laisse remapper alors qu'il est declare non remappable")
	if fautes.is_empty():
		print("  controles : %d actions dans l'InputMap, la marche par position, le remappage tient" % actions.size())


## LE RAPPEL DES TOUCHES (palier 3, 2026-09-08). Il n'y en avait aucun en jeu. Ce qui compte n'est pas qu'il existe,
## c'est qu'il LISE l'InputMap : on remappe une touche et on vérifie que l'écran le dit — s'il affichait une liste
## écrite à la main, il continuerait à montrer l'ancienne, comme le README et les chaînes `ui.aide` supprimées.
func _verifier_aide(_scene: Node, ec) -> void:
	ec.ouvrir("aide")
	await get_tree().process_frame
	var n_actions: int = Reglages.actions().size()
	var lignes: int = ec.entrees.size()
	if lignes < n_actions:
		fautes.append("  aide : %d lignes pour %d actions declarees" % [lignes, n_actions])
	# On lit l'ENTREE et pas le libelle affiche : la ligne est prefixee par sa lettre d'option, donc son texte ne
	# commence pas par la touche.
	var avait := false
	for en in ec.entrees:
		if str(en.get("id", "")) == "ramasser" and str(en.get("touche", "")) == Reglages.touche_de("ramasser"):
			avait = true
	if not avait:
		fautes.append("  aide : la touche de « ramasser » (%s) n'apparait pas" % Reglages.touche_de("ramasser"))
	# La preuve : on remappe, et l'ecran doit suivre.
	Reglages.remapper("ramasser", "K")
	ec.fermer()
	ec.ouvrir("aide")
	await get_tree().process_frame
	var suit := false
	for en in ec.entrees:
		if str(en.get("id", "")) == "ramasser" and str(en.get("touche", "")) == "K":
			suit = true
	Reglages.remappages.erase("ramasser")
	Reglages.construire_input_map()
	Reglages.enregistrer()
	ec.fermer()
	if not suit:
		fautes.append("  aide : l'ecran n'a pas suivi le remappage — il n'est donc pas branche sur l'InputMap")
	else:
		print("  aide : %d lignes, et l'ecran suit le remappage (il LIT l'InputMap)" % lignes)


## ÉQUIPER UN OBJET PAR L'ÉCRAN (designer 2026-09-09 : « impossible d'équiper d'interagir avec les items dans
## l'inventaire »). La suite complète était verte : elle ne teste que la simulation, jamais le chemin qu'un joueur
## emprunte — choisir un objet, voir ses options, en activer une. C'est ce chemin-là qu'on parcourt ici.
func _verifier_objets(scene: Node, ec: Node) -> void:
	var sim = scene.sim
	var j: Dictionary = scene.joueur()
	if sim == null or j.is_empty():
		fautes.append("  objets : pas de joueur")
		return
	var arme: Dictionary = sim.generer_objet("proto_pioche", 1, {}, "commun", 0)
	if arme.is_empty() or not arme.has("uid"):
		fautes.append("  objets : le prototype d'essai n'existe pas")
		return
	j.sac.append(str(arme.uid))
	ec.ouvrir("inventaire")
	await get_tree().process_frame
	# 1. CHOISIR l'objet : ses options doivent apparaître.
	var i_obj := -1
	for i in ec.entrees.size():
		if str(ec.entrees[i].get("kind", "")) == "objet" and str(ec.entrees[i].get("uid", "")) == arme.uid:
			i_obj = i
	if i_obj < 0:
		fautes.append("  objets : l'arme du sac n'apparaît pas dans l'écran")
		ec.fermer()
		return
	# LE CHEMIN DE LA SOURIS, pas celui du clavier : `selectionner` est exactement ce qu'un clic sur une ligne du
	# sac appelle. C'est la moitié que la sonde d'hier ne parcourait pas — et c'est celle qui était cassée.
	ec.inventaire_visuel.selectionner(i_obj)
	await get_tree().process_frame
	var options := 0
	var i_equiper := -1
	for i2 in ec.entrees.size():
		if str(ec.entrees[i2].get("kind", "")) == "action_objet":
			options += 1
			if str(ec.entrees[i2].get("action", "")) == "equiper":
				i_equiper = i2
	if options == 0 or i_equiper < 0:
		fautes.append("  objets : choisir l'arme n'offre AUCUNE option (%d)" % options)
		ec.fermer()
		return
	# 2. L'OPTION DOIT AVOIR UNE LIGNE À L'ÉCRAN. C'est le défaut du 2026-09-09 : elle était dans `ec.entrees` avec
	# sa lettre, mais le panneau visuel ne dessinait que les objets — choisir une arme effaçait les lettres des
	# lignes et ne mettait rien à la place. Au clavier tout marchait ; à la souris, l'écran était muet.
	var lignes_option: Array = []
	for ch in ec.inventaire_visuel.colonne.get_children():
		if ch is InventaireVisuel.LigneAction:
			lignes_option.append(ch)
	if lignes_option.is_empty():
		fautes.append("  objets : les %d options de l'arme n'ont AUCUNE ligne dans le panneau — rien à cliquer" % options)
		ec.fermer()
		return
	# 3. UN VRAI CLIC sur la ligne « équiper » : l'arme doit passer en main.
	var clic := InputEventMouseButton.new()
	clic.button_index = MOUSE_BUTTON_LEFT
	clic.pressed = true
	var trouvee := false
	for ch2 in lignes_option:
		if int(ch2.index) == i_equiper:
			ch2._gui_input(clic)
			trouvee = true
	if not trouvee:
		fautes.append("  objets : aucune ligne cliquable ne porte l'option « équiper »")
	sim.horloge_monde.avancer(3000)
	await get_tree().process_frame
	if not (arme.uid in j.equipement.values()):
		fautes.append("  objets : « équiper » ne met rien en main (options %d)" % options)
	else:
		print("  objets : l'arme du sac s'équipe AU CLIC, par la ligne de son option (%d options, %d lignes)" % [options, lignes_option.size()])
	ec.fermer()


## LA PETITE FENÊTRE DU CLIC DROIT (designer 2026-09-09 : « je veux que le menu qui s'affiche quand on fait clique
## droit n'importe où soit une petite fenêtre qui s'affiche là où on a cliqué avec les options, plusieurs pages si
## nécessaire »). On parcourt ce que la main parcourt : le clic droit, la fenêtre au point cliqué, la lettre qui
## joue une ligne, Échap qui ferme. Et deux choses qu'un écran plein cadre n'avait jamais à prouver — elle **tient
## dans l'écran** même ouverte au coin, et elle **pagine** quand une tuile offre plus d'options qu'une page.
func _verifier_menu_contexte(scene: Node, _ec: Node) -> void:
	var sim = scene.sim
	var j: Dictionary = scene.joueur()
	var menu = scene.menu_contexte
	if sim == null or j.is_empty() or menu == null:
		fautes.append("  menu : pas de joueur ou pas de fenêtre")
		return
	var t: Vector2i = sim._tuile_libre_autour(j.pos)
	if t.x < 0:
		fautes.append("  menu : aucune tuile libre")
		return
	sim.grille.poser_meuble(sim.grille.idx(t), "coffre")
	var ou := Vector2(240.0, 180.0)
	scene._contexte(t, ou)
	await get_tree().process_frame
	if not menu.visible or menu.options.is_empty():
		fautes.append("  menu : le clic droit sur un coffre n'ouvre aucune fenêtre")
		sim.grille.vider_meubles(sim.grille.idx(t))
		return
	if menu.position.distance_to(ou) > 2.0:
		fautes.append("  menu : la fenêtre ne s'ouvre pas au point cliqué (%s pour %s)" % [str(menu.position), str(ou)])
	# ELLE TIENT DANS L'ÉCRAN, même ouverte au coin : c'est ce qu'un panneau plein cadre n'avait jamais à prouver.
	var ecran: Vector2 = menu.get_viewport_rect().size
	scene._contexte(t, ecran - Vector2(4.0, 4.0))
	await get_tree().process_frame
	if menu.position.x + menu.size.x > ecran.x + 1.0 or menu.position.y + menu.size.y > ecran.y + 1.0:
		fautes.append("  menu : ouverte au coin, la fenêtre sort de l'écran (%s + %s > %s)" % [str(menu.position), str(menu.size), str(ecran)])
	# ELLE PAGINE : on lui donne plus d'options qu'une page, la dernière ligne doit être « z) ».
	var par_page: int = menu._lignes_par_page()
	var beaucoup: Array = []
	for k in par_page + 3:
		beaucoup.append({"id": "deplacer", "vers": t})
	menu.ouvrir(beaucoup, ou, "essai")
	await get_tree().process_frame
	var derniere: String = str(menu._boutons[menu._boutons.size() - 1].text) if menu._boutons.size() > 0 else ""
	if menu._boutons.size() != par_page + 1 or not derniere.begins_with("z)"):
		fautes.append("  menu : %d options sur %d par page ne donnent pas de page suivante (%d lignes, « %s »)" % [beaucoup.size(), par_page, menu._boutons.size(), derniere])
	else:
		menu._prendre(-1)   # z) : la page suivante montre les trois restantes, plus sa propre ligne de page
		if menu._boutons.size() != 4:
			fautes.append("  menu : la seconde page montre %d lignes au lieu de 3 + la ligne de page" % menu._boutons.size())
	# UNE LETTRE JOUE SA LIGNE, et la fenêtre se referme derrière.
	scene._contexte(t, ou)
	await get_tree().process_frame
	var n_opts: int = menu.options.size()
	menu._prendre(0)
	if menu.visible:
		fautes.append("  menu : prendre une option ne referme pas la fenêtre")
	else:
		print("  menu : la fenêtre s'ouvre au point cliqué, tient dans l'écran, pagine et se referme (%d options)" % n_opts)
	sim.grille.vider_meubles(sim.grille.idx(t))


## FOUILLER UNE DÉPOUILLE (ordre de travail 28 ter). Le chemin entier, celui que la main parcourt : l'option existe
## sur la tuile du mort, elle ouvre l'écran d'anatomie BRAQUÉ SUR LUI (et pas sur le joueur), et l'option « prélever »
## y est offerte sur une pièce encore là. C'est exactement ce qui manquait aux coffres avant-hier : une chose peut
## être entièrement codée et n'avoir aucun chemin depuis la tuile.
func _verifier_depouille(scene: Node, ec: Node) -> void:
	var sim = scene.sim
	var j: Dictionary = scene.joueur()
	if sim == null or j.is_empty():
		fautes.append("  dépouille : pas de joueur")
		return
	var mort: Dictionary = {}
	for x in sim.vivants():
		if x.id != j.id and not Etres.plan_corps(x).is_empty():
			mort = x
			break
	if mort.is_empty():
		fautes.append("  dépouille : personne à faire tomber")
		return
	var ou: Vector2i = sim._tuile_libre_autour(j.pos)
	if ou.x >= 0:
		sim.grille.liberer(mort.pos, mort.id)
		mort.pos = ou
		sim.grille.placer(mort.id, ou)
	sim._appliquer_degats(mort, int(mort.sante) + 500, j.id, {})
	# UNE LAME EN MAIN : sans elle on ne teste que le refus, et le refus est la moitie facile. On depece a la dague
	# comme a la hache — c'est le premier verbe du monde a accepter plusieurs outils (28 ter).
	var lame: Dictionary = sim.generer_objet("proto_dague", 1, {}, "commun", 0)
	if not lame.is_empty() and lame.has("uid"):
		j.sac.append(str(lame.uid))
		SimObjets._equiper(sim, j, str(lame.uid), sim.horloge_monde.ticks)
	var a_option := false
	for o in scene._options_tuile(mort.pos):
		if str((o as Dictionary).get("id", "")) == "depouille":
			a_option = true
	if not a_option:
		fautes.append("  dépouille : aucune option sur la tuile d'un mort — on ne peut donc jamais le fouiller")
		return
	ec.anatomie_id = str(mort.id)
	ec.ouvrir("anatomie")
	await get_tree().process_frame
	if not ec.anatomie_depouille() or str(ec.anatomie_sujet().get("id", "")) != str(mort.id):
		fautes.append("  dépouille : l'écran d'anatomie montre le joueur au lieu du mort")
		ec.fermer()
		return
	var prelevable := ""
	for i in ec.entrees.size():
		var en: Dictionary = ec.entrees[i]
		if str(en.get("kind", "")) == "partie" and SimCadavres.prelevable(sim, mort, str(en.get("id", ""))):
			prelevable = str(en.id)
			ec.selection = i
			break
	if prelevable.is_empty():
		fautes.append("  dépouille : l'écran ne liste aucune pièce prélevable")
	elif EcransListe._options_de(ec, ec.entrees[ec.selection]).is_empty():
		# Sans lame en main, l'absence d'option est NORMALE — mais elle doit alors être expliquée à droite.
		if not scene._outil_en_main(j, "depecer"):
			if "" == EcransFeuille.texte_partie(ec, prelevable):
				fautes.append("  dépouille : ni option ni explication sur la pièce %s" % prelevable)
			else:
				print("  dépouille : elle s'ouvre sur le mort, et dit pourquoi on ne peut pas prélever sans lame")
		else:
			fautes.append("  dépouille : une lame en main et pas d'option « prélever » sur %s" % prelevable)
	else:
		print("  dépouille : elle s'ouvre sur le mort, et « prélever » est offert sur %s" % prelevable)
	ec.fermer()


## OUVRIR UN COFFRE VIDE (designer 2026-09-09 : « l'interface de coffres ne s'ouvre même pas »). Le défaut était réel
## et ancien : l'option n'était offerte que si le coffre contenait DÉJÀ quelque chose — un coffre ne devenait donc
## utilisable qu'une fois rempli, ce qui était impossible. Et il se cherche dans la PILE depuis que les meubles
## s'empilent : un coffre sous une lanterne devenait introuvable.
func _verifier_coffre(scene: Node, ec: Node) -> void:
	var sim = scene.sim
	var j: Dictionary = scene.joueur()
	if sim == null or j.is_empty():
		fautes.append("  coffre : pas de joueur")
		return
	var t: Vector2i = sim._tuile_libre_autour(j.pos)
	if t.x < 0:
		fautes.append("  coffre : aucune tuile libre")
		return
	# On pose le coffre COMME LE JEU LE POSE : `poser_meuble` seul ne met pas à jour le contenu de la tuile, et
	# c'est ce contenu que le menu contextuel interroge. Une sonde qui triche sur la pose ne mesure rien.
	sim.grille.poser_meuble(sim.grille.idx(t), "coffre")
	SimCamp._maj_contenu_pile(sim, t)
	var opts: Array = scene._options_tuile(t)
	var a_prendre := false
	for o in opts:
		if str((o as Dictionary).get("id", "")) == "prendre":
			a_prendre = true
	if not a_prendre:
		fautes.append("  coffre : un coffre VIDE n'offre aucune option — on ne peut donc jamais rien y ranger")
	if SimCamp._coffre_a(sim, t).is_empty():
		fautes.append("  coffre : le coffre n'est pas trouvé sur sa tuile")
	# … et sous un autre meuble : depuis les piles, `meubles[i]` ne donne que le sommet.
	sim.grille.poser_meuble(sim.grille.idx(t), "torchere")
	SimCamp._maj_contenu_pile(sim, t)
	if SimCamp._coffre_a(sim, t).is_empty():
		fautes.append("  coffre : un coffre SOUS un autre meuble devient introuvable")
	if a_prendre and not SimCamp._coffre_a(sim, t).is_empty():
		print("  coffre : un coffre vide s'ouvre, et il se trouve même sous un autre meuble")
	sim.grille.vider_meubles(sim.grille.idx(t))


func _verifier_pages_et_tri(scene: Node, ec: Node) -> void:
	var sim = scene.sim
	var j: Dictionary = scene.joueur()
	if sim == null or j.is_empty():
		fautes.append("  pages : pas de joueur")
		return
	var mats: Array = GameData.catalogues.materials.keys()
	mats.sort()
	for k in 40:
		sim._donner_materiau(j, str(mats[k % mats.size()]), 1)
	ec.ouvrir("inventaire")
	ec.inventaire_visuel.tri = "nom"
	ec.inventaire_visuel.tri_inverse = false
	EcransListe.rafraichir(ec)
	# Les secteurs (designer 2026-09-06, 19 h 40) : l'équipement est surligné d'abord, ses cases lettrées, le sac sans lettre ;
	# Tab passe au sac, qui prend les lettres et se pagine.
	var lettres_sac := 0
	for i in ec.entrees.size():
		if ec.lettres.has(i) and str(ec.entrees[i].get("kind", "")) == "objet" and not bool(ec.entrees[i].get("equipe", false)):
			lettres_sac += 1
	if str(ec.secteurs[ec.secteur]) != "equipement" or lettres_sac > 0:
		fautes.append("  secteurs : l'inventaire s'ouvre sur %s, %d lettres dans le sac (attendu : equipement, 0)" % [str(ec.secteurs[ec.secteur]), lettres_sac])
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	ec.touche(tab)
	if str(ec.secteurs[ec.secteur]) != "sac":
		fautes.append("  secteurs : Tab n'a pas surligne le sac (%s)" % str(ec.secteurs[ec.secteur]))
	for i in ec.entrees.size():
		if ec.lettres.has(i) and bool(ec.entrees[i].get("equipe", false)):
			fautes.append("  secteurs : une case d'equipement garde une lettre quand le sac est surligne")
			break
	var noms: Array[String] = []
	var pages := 1
	while pages < 12:
		var avec_page := false
		for en in ec.entrees:
			if str(en.get("kind", "")) == "objet" and not bool(en.get("equipe", false)):
				noms.append(ec._nom_court(str(en.uid)).to_lower())
			elif str(en.get("kind", "")) == "page":
				avec_page = true
		if not avec_page:
			break
		var p0: int = ec.page
		EcransListe.page_suivante(ec)
		if ec.page <= p0:
			break
		pages += 1
	var attendu: Array[String] = noms.duplicate()
	attendu.sort()
	if noms.size() != j.sac.size():
		fautes.append("  pages : %d objets vus sur %d pages, le sac en a %d" % [noms.size(), pages, j.sac.size()])
	elif noms != attendu:
		fautes.append("  tri : les noms ne sont pas tries d'un bout a l'autre des %d pages (%s…)" % [pages, ", ".join(noms.slice(0, 6))])
	else:
		print("pages et tri : %d objets sur %d pages, tries par nom d'un bout a l'autre" % [noms.size(), pages])
	ec.fermer()
