class_name AnatomieVisuelle
extends Control
## L'ANATOMIE EN VUE DE PANTIN (designer 2026-09-09 : « je veux une vue du pantin avec zoom sur les membres et
## organes avec toutes les infos à droite »).
##
## À gauche, le corps tel qu'on le voit en jeu — le MÊME paperdoll, la même matière, le même équipement peint —, mais
## en grand et **cadré sur la partie choisie** : choisir une main y amène la vue, choisir un organe y amène la vue à
## travers le membre qui le loge. Les organes n'ont pas de segment à dessiner : ils se posent en **pastilles** dans
## leur contenant, à la place que leur donne le plan.
##
## **Il ne décide rien**, comme l'inventaire visuel : il lit `ecrans.entrees` et `ecrans.selection`. La liste au
## milieu navigue, la colonne de droite dit tout — ce panneau ne fait que MONTRER.
##
## Une partie perdue n'est pas dessinée (le paperdoll le sait déjà) : elle apparaît ici comme une **croix** à sa
## place, parce qu'un membre absent doit se voir absent, pas être silencieusement omis.

const MARGE := 18.0

var ecrans: Node
var cadre: Control
var avatar: Paperdoll
var marques: Control                 # les pastilles d'organes et le surlignage, par-dessus le pantin
var _partie := ""                    # la partie pointée, lue de la sélection
var _zoom := 1.0
var _centre := Vector2.ZERO


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(240, 0)
	clip_contents = true
	cadre = Control.new()
	cadre.set_anchors_preset(Control.PRESET_FULL_RECT)
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cadre)
	avatar = Paperdoll.new()
	cadre.add_child(avatar)
	marques = Control.new()
	marques.set_anchors_preset(Control.PRESET_FULL_RECT)
	marques.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marques.draw.connect(_dessiner_marques)
	add_child(marques)


## Ce que la sélection pointe : l'id de la partie, ou "" si la ligne n'en est pas une.
func _partie_pointee() -> String:
	if ecrans == null or ecrans.selection < 0 or ecrans.selection >= ecrans.entrees.size():
		return ""
	var en: Dictionary = ecrans.entrees[ecrans.selection]
	return str(en.get("id", "")) if str(en.get("kind", "")) == "partie" else ""


func rafraichir() -> void:
	# LE PANNEAU EXISTE AVANT TOUTE PARTIE : l'écran-titre monte l'interface entière, et `main.sim` est alors nul.
	# Demander le joueur à ce moment-là lit `entites` sur rien — `verif_scripts` l'a levé à la seconde même.
	if ecrans == null or ecrans.main == null or ecrans.main.sim == null:
		return
	var j: Dictionary = ecrans.main.joueur()
	if j.is_empty():
		return
	var sim = ecrans.main.sim
	var rig: Dictionary = GameData.entree("rigs", str(j.get("skeleton_template", "humanoide")))
	avatar.configurer(j, rig, sim.items, sim.fonctionnalites, GameData.config("palette_materiaux"))
	_partie = _partie_pointee()
	_cadrer(j, rig)
	avatar.queue_redraw()
	marques.queue_redraw()


## LE CADRAGE — c'est lui le « zoom ». On part de la vue d'ensemble, et l'on se rapproche à mesure que la partie
## choisie est petite : le torse se regarde en entier, une main se regarde de près. La position de la partie sur le
## pantin vient du rig lui-même (le segment qui la dessine), donc le cadrage suit le corps et non une table de
## coordonnées écrite à côté — un rig retouché déplace la vue tout seul.
func _cadrer(j: Dictionary, rig: Dictionary) -> void:
	var haut := float(rig.get("hauteur_pieds", 40.0)) + 20.0
	var vise := _ancre_partie(j, rig, _partie)
	var petite := 1.0
	if not _partie.is_empty():
		var seg := _segment_de(rig, _partie)
		if not seg.is_empty():
			petite = clampf(float(seg.get("longueur", 8.0)) / 12.0, 0.35, 1.0)
		# UN ORGANE SE REGARDE DE PRÈS. Il n'a pas de segment à lui : sans ce rapprochement, choisir un poumon
		# donnait la même vue que choisir le torse, et le « zoom sur les organes » n'existait que de nom.
		if bool((Etres.plan_corps(j).get("parties", {}).get(_partie, {}) as Dictionary).get("interne", false)):
			petite *= 0.45
	# Le plafond est haut EXPRÈS : à 9 le calcul butait dessus pour toute partie, et « zoom » ne voulait rien dire —
	# la vue d'un œil était celle du corps entier. Le corps déborde du cadre quand on serre sur un organe, et c'est
	# le but : on regarde un œil, pas une silhouette.
	_zoom = clampf((size.y - MARGE * 2.0) / maxf(20.0, haut) * (1.0 / maxf(0.15, petite)) * 0.55, 1.5, 26.0)
	if _partie.is_empty():
		_zoom = clampf((size.y - MARGE * 2.0) / maxf(20.0, haut) * 0.9, 1.5, 6.0)
	_centre = vise
	avatar.scale = Vector2(_zoom, _zoom)
	avatar.position = size * 0.5 - vise * _zoom


## Où se tient une partie sur le pantin, en coordonnées du paperdoll. Un membre : le milieu de son segment. Un
## organe : le milieu de son contenant, décalé de ce que le plan lui donne comme rang — deux poumons ne se posent
## pas au même endroit, et l'ordre du plan suffit à les ranger.
func _ancre_partie(j: Dictionary, rig: Dictionary, partie: String) -> Vector2:
	var haut := float(rig.get("hauteur_pieds", 40.0))
	if partie.is_empty():
		return Vector2(0.0, -haut * 0.5)
	var plan: Dictionary = Etres.plan_corps(j)
	var p: Dictionary = plan.get("parties", {}).get(partie, {})
	var cible := partie
	var decal := Vector2.ZERO
	if bool(p.get("interne", false)):
		cible = str(p.get("contenant", ""))
		var freres: Array[String] = []
		for nom: String in (plan.get("parties", {}) as Dictionary).keys():
			var q: Dictionary = plan.parties[nom]
			if bool(q.get("interne", false)) and str(q.get("contenant", "")) == cible:
				freres.append(nom)
		var rang := maxi(0, freres.find(partie))
		decal = Vector2(float(rang % 3 - 1) * 3.0, float(rang / 3) * 3.5 - 3.0)
	# ON DEMANDE AU DESSIN, on ne le devine pas. Le pantin vient de poser ses segments : il sait où est la tête, à
	# la pose et au lacet près. Une table de proportions écrite ici aurait vieilli au premier rig retouché — et la
	# première version de cet écran mettait les yeux à la ceinture, faute de le demander.
	var nom_seg := _nom_segment(rig, cible)
	if nom_seg.is_empty():
		return Vector2(0.0, -haut * 0.5) + decal
	var pos := avatar.position_segment(nom_seg)
	if pos == Vector2.ZERO:
		return Vector2(0.0, -haut * 0.5) + decal
	return pos + decal


## Le segment du rig qui dessine une partie, et sa hauteur relative — le rig ne porte pas de position absolue, on
## l'approche par la ZONE, qui suffit largement pour cadrer : la tête en haut, les pieds en bas.
func _segment_de(rig: Dictionary, partie: String) -> Dictionary:
	var nom := _nom_segment(rig, partie)
	return rig.segments[nom] if not nom.is_empty() else {}


## Le nom du segment qui dessine une partie — le premier, quand plusieurs la dessinent (un bras en a deux).
func _nom_segment(rig: Dictionary, partie: String) -> String:
	for nom: String in (rig.get("segments", {}) as Dictionary).keys():
		if str((rig.segments[nom] as Dictionary).get("partie", "")) == partie:
			return nom
	return ""


## Les pastilles d'organes et le surlignage de la partie choisie. Un organe n'a pas de segment : il se pose dans son
## contenant, et sa couleur dit ce qu'il lui reste. Une partie PERDUE porte une croix à sa place.
func _dessiner_marques() -> void:
	if ecrans == null or ecrans.main == null or ecrans.main.sim == null:
		return   # même garde qu'au rafraîchissement : un panneau se dessine avant qu'une partie existe
	var j: Dictionary = ecrans.main.joueur()
	if j.is_empty():
		return
	var plan: Dictionary = Etres.plan_corps(j)
	if plan.is_empty():
		return
	var rig: Dictionary = GameData.entree("rigs", str(j.get("skeleton_template", "humanoide")))
	var st: Dictionary = GameData.config("styles").get("sprites", {})
	var coul_bl := Color.html(str(st.get("blessure_couleur", "#8e2020")))
	for nom: String in (plan.parties as Dictionary).keys():
		var p: Dictionary = plan.parties[nom]
		var interne := bool(p.get("interne", false))
		var intacte := Etres.partie_intacte(j, nom)
		if not interne and intacte and nom != _partie:
			continue   # un membre entier se voit déjà : le pantin l'a dessiné
		var pos := marques.get_global_transform().affine_inverse() * (avatar.get_global_transform() * _ancre_partie(j, rig, nom))
		if not intacte:
			var r := 4.0
			marques.draw_line(pos + Vector2(-r, -r), pos + Vector2(r, r), coul_bl, 2.0)
			marques.draw_line(pos + Vector2(r, -r), pos + Vector2(-r, r), coul_bl, 2.0)
			continue
		if interne:
			var pmax := Etres.sante_partie_max(j, nom)
			var reste := clampf(float(Etres.sante_partie(j, nom)) / float(maxi(1, pmax)), 0.0, 1.0)
			var c := Color(0.75, 0.35, 0.35).lerp(coul_bl, 1.0 - reste)
			marques.draw_circle(pos, 3.5 if nom == _partie else 2.5, c)
			if bool(p.get("vital", false)):
				marques.draw_arc(pos, 5.0, 0.0, TAU, 12, Color(0.9, 0.8, 0.4, 0.8), 1.0)
		if nom == _partie:
			marques.draw_arc(pos, 9.0, 0.0, TAU, 20, Color(1.0, 0.95, 0.7, 0.9), 1.5)
