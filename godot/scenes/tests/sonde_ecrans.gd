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
const ECRANS := ["inventaire", "atelier", "feuille", "menu", "options", "capacites", "quetes", "gestion"]
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
