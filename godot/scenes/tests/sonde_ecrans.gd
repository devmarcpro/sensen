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
