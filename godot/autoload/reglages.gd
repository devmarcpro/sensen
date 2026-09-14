extends Node
## Les réglages du joueur, et l'InputMap qu'ils commandent (Ordre de travail, palier 3 — 2026-09-08).
##
## Deux manques que ce fichier comble d'un coup, parce que c'est le même : le projet n'avait **aucun InputMap** (la
## section `[input]` de `project.godot` est vide et les touches étaient écrites en dur dans `main.gd`, donc le jeu
## n'était jouable qu'en AZERTY et rien ne se reconfigurait), et **les options n'étaient jamais enregistrées** (ni
## `ConfigFile` ni fichier de réglages dans tout le dépôt : la langue et le plein écran se perdaient à la fermeture).
##
## Le choix qui compte : les touches de MARCHE sont déclarées par leur **position physique**. Sur un clavier AZERTY, la
## touche Z occupe la place du W de QWERTY — déclarer la position donne donc ZQSD à l'un et WASD à l'autre sans rien
## demander. Les **lettres d'option** ne passent pas par ici : le designer a décidé « une option = une lettre », et la
## lettre qu'on affiche doit être celle qu'on tape.

const FICHIER := "user://options.cfg"
## Les tailles de fenêtre proposées, et les facteurs de taille du texte (palier 3, 2026-09-13). Le texte agrandit la
## police PAR DÉFAUT du thème de la fenêtre : ce qui porte une taille écrite à la main (une vingtaine d'étiquettes)
## garde la sienne — c'est dit, pas caché.
const RESOLUTIONS := ["1280x800", "1600x900", "1920x1080", "2560x1440"]
const TAILLES_TEXTE := [1.0, 1.15, 1.3, 0.85]
const VOLUMES := [0.8, 1.0, 0.0, 0.2, 0.4, 0.6]   # le volume des effets (48, 2026-09-14) : 0 coupe le son
const POLICE_DE_BASE := 16

var options := {}
var remappages := {}   # action → nom de touche choisi par le joueur


func _ready() -> void:
	charger()
	construire_input_map()
	appliquer()


## Le catalogue des actions, tel que `data/controles.json` le déclare.
func actions() -> Dictionary:
	return GameData.config("controles").get("actions", {})


## (Re)construit l'InputMap depuis les données et les remappages du joueur. Rejouable : on efface avant d'écrire, si
## bien qu'un remappage ou un rechargement de données ne laisse jamais deux touches sur une même action.
func construire_input_map() -> void:
	for nom in actions().keys():
		var a: Dictionary = actions()[nom]
		if InputMap.has_action(nom):
			InputMap.action_erase_events(nom)
		else:
			InputMap.add_action(nom)
		var touche := str(remappages.get(nom, a.get("touche", "")))
		var code := OS.find_keycode_from_string(touche)
		if code == KEY_NONE:
			push_warning("Réglages : touche inconnue « %s » pour l'action %s" % [touche, nom])
			continue
		var ev := InputEventKey.new()
		if bool(a.get("physique", true)):
			ev.physical_keycode = code   # la POSITION : ZQSD en AZERTY = WASD en QWERTY
		else:
			ev.keycode = code            # la LETTRE : c'est elle qui est affichée
		InputMap.action_add_event(nom, ev)


## Le nom lisible de la touche d'une action, pour l'écran d'aide et l'écran des options — c'est la SEULE source, il n'y
## a plus de liste écrite à la main (le README et les anciennes chaînes d'aide en décrivaient trois différentes).
func touche_de(nom: String) -> String:
	var evs: Array = InputMap.action_get_events(nom) if InputMap.has_action(nom) else []
	for ev in evs:
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
			if ev.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
				# Ce que le joueur a SOUS LE DOIGT : sur AZERTY, la position du W s'appelle Z. Le serveur d'affichage
				# headless n'a pas de disposition de clavier et pousse une erreur — en test, on rend la position brute.
				var label := DisplayServer.keyboard_get_label_from_physical(code)
				if label != KEY_NONE:
					code = label
			return OS.get_keycode_string(code)
	return "?"


## Remappe une action et réécrit l'InputMap. Rend faux si l'action ne se remappe pas (Échap, Entrée).
func remapper(nom: String, touche: String) -> bool:
	var a: Dictionary = actions().get(nom, {})
	if a.is_empty() or not bool(a.get("rebindable", true)):
		return false
	remappages[nom] = touche
	construire_input_map()
	enregistrer()
	return true


func regler(cle: String, valeur: Variant) -> void:
	options[cle] = valeur
	enregistrer()
	appliquer()


## Ce que les réglages commandent hors des touches. Appelé au démarrage et à chaque changement.
func appliquer() -> void:
	if options.has("langue"):
		TranslationServer.set_locale(str(options.langue))
	if bool(options.get("plein_ecran", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if DisplayServer.get_name() == "headless":
		return   # sans fenêtre, ni taille ni thème à poser
	if options.has("resolution") and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		var r := str(options.resolution).split("x")
		if r.size() == 2:
			var taille := Vector2i(int(r[0]), int(r[1]))
			var ecran := DisplayServer.screen_get_usable_rect()
			taille = Vector2i(mini(taille.x, ecran.size.x), mini(taille.y, ecran.size.y))   # jamais plus grand que l'écran
			DisplayServer.window_set_size(taille)
			DisplayServer.window_set_position(ecran.position + (ecran.size - taille) / 2)
	var fenetre := get_tree().root if is_inside_tree() else null
	if fenetre != null:
		var f := float(options.get("taille_texte", 1.0))
		if is_equal_approx(f, 1.0):
			fenetre.theme = null
		else:
			var th := Theme.new()
			th.default_font_size = roundi(float(POLICE_DE_BASE) * f)
			fenetre.theme = th


## La valeur suivante d'une liste de choix, en boucle — la ligne d'option joue ce pas à chaque Entrée.
static func suivant(liste: Array, actuel: Variant) -> Variant:
	var i := liste.find(actuel)
	return liste[(i + 1) % liste.size()] if i >= 0 else liste[0]


func charger() -> void:
	var c := ConfigFile.new()
	if c.load(FICHIER) != OK:
		return
	for cle in c.get_section_keys("options") if c.has_section("options") else []:
		options[cle] = c.get_value("options", cle)
	for cle in c.get_section_keys("touches") if c.has_section("touches") else []:
		remappages[cle] = str(c.get_value("touches", cle))


func enregistrer() -> void:
	var c := ConfigFile.new()
	for cle in options.keys():
		c.set_value("options", str(cle), options[cle])
	for cle in remappages.keys():
		c.set_value("touches", str(cle), remappages[cle])
	c.save(FICHIER)
