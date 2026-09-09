class_name Planches
extends RefCounted
## Les planches de sprites (Direction artistique, designer 2026-09-06, 20 h 50 : « séparer par dossiers, chaque sprite en
## 64 × 64, des sprites individuels, des spritesheets ou les deux ; réunir le contenu de chaque dossier en un seul
## spritesheet par dossier ; pour chaque membre et item ; s'il n'y a pas de sprite correspondant, fallback dessiné par code »).
## Un dossier sous `assets/` est une planche : chaque PNG y est une case de CASE × CASE, ou une planche de cases (lues de
## haut en bas puis de gauche à droite) ; les fichiers se lisent dans l'ordre de leurs noms, numérotés — l'index d'une
## variante ne bouge pas quand on en ajoute. Le jeu assemble le dossier LUI-MÊME, au premier usage, en une seule image
## (une colonne de cases) et une seule texture : pas de script au lancement, rien à tenir à jour, et l'export s'en sort.
## Une planche vide (dossier absent, aucune case valable) compte zéro variante : celui qui dessine garde son code.

## LE CALQUE DES POINTS (designer 2026-09-09) : `06_museau.png` porte le dessin, `06_museau.points.png` les points.
## L'artiste ne met donc rien dans son sprite — plus de pixel à ne pas recouvrir, plus de couleur à ne pas mélanger.
const SUFFIXE_POINTS := ".points.png"

static var _cache: Dictionary = {}   # dossier → {"n": int, "image": Image, "texture": Texture2D (à la demande), "fichiers": int, "marqueurs": Array}


## Préchauffer TOUTES les planches (2026-09-07) : assembler un dossier lit ses PNG sur le disque et les découpe en
## cases — trois à cinquante millisecondes. Fait au premier dessin, c'est une saccade en pleine partie, la première
## fois qu'un villageois montre son visage. Fait ici, pendant l'écran de chargement, c'est du temps qu'on avait déjà.
## Rend le nombre de dossiers assemblés (la sonde et les tests le lisent).
static func prechauffer() -> int:
	# La PREMIÈRE texture créée dans le processus paie l'initialisation du pipeline de rendu : 180 à 230 ms, mesurés
	# (2026-09-07). Sans ce réveil, c'est la carte de lumière qui la payait, en pleine partie, à la première image
	# éclairée. Quatre pixels suffisent à la provoquer ici, pendant qu'il n'y a rien à l'écran.
	var _reveil := ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_RGB8))
	var n := 0
	for racine: String in ["membres", "visage", "objets"]:
		var dir := DirAccess.open(chemin(racine))
		if dir == null:
			continue
		if variantes(racine) > 0:   # un dossier peut porter ses propres PNG en plus de ses sous-dossiers
			n += 1
		for sous in dir.get_directories():
			var d: String = racine + "/" + str(sous)
			if variantes(d) > 0:
				var _t := texture(d)   # la texture aussi : elle se crée au premier dessin, pas à l'assemblage
				n += 1
	return n


## La taille d'une case, en pixels (styles.json → planches.case).
static func case() -> int:
	return int(GameData.config("styles").get("planches", {}).get("case", 64))


## Le chemin d'un dossier de planche : relatif à `assets/`, ou absolu (res://, user://).
static func chemin(dossier: String) -> String:
	if dossier.begins_with("res://") or dossier.begins_with("user://"):
		return dossier.trim_suffix("/") + "/"
	return "res://assets/" + dossier.trim_suffix("/") + "/"


## Assemble le dossier (une fois) ; rend {"n": variantes, "image": la colonne des cases, "fichiers": PNG lus}.
static func charger(dossier: String) -> Dictionary:
	if _cache.has(dossier):
		return _cache[dossier]
	var c := case()
	var res := {"n": 0, "image": null, "texture": null, "fichiers": 0, "marqueurs": []}
	_cache[dossier] = res
	var dir := DirAccess.open(chemin(dossier))
	if dir == null:
		return res
	var noms: Array[String] = []
	var points: Dictionary = {}   # « 06_museau » → « 06_museau.points.png » : le calque des points, s'il existe
	for f in dir.get_files():
		var nom := str(f)
		if nom.ends_with(".png.import"):   # l'export ne garde que l'import : le nom du PNG est dedans
			nom = nom.trim_suffix(".import")
		if not nom.ends_with(".png"):
			continue
		# LE CALQUE DES POINTS N'EST PAS UNE CASE (designer 2026-09-09 : « le sprite et un autre fichier
		# correspondant qui est juste les points »). On l'écarte AVANT de numéroter : laissé dans la liste, il
		# décalerait d'un rang tout ce qui le suit — le défaut même qu'on vient de corriger sur les substitutions.
		if nom.ends_with(SUFFIXE_POINTS):
			points[nom.trim_suffix(SUFFIXE_POINTS)] = nom
		elif not (nom in noms):
			noms.append(nom)
	noms.sort()
	var cases: Array[Image] = []
	var calques: Array = []   # une entrée par case : l'image de points correspondante, ou null
	for nom in noms:
		var img := _image_de(chemin(dossier) + nom)
		if img == null:
			continue
		if img.get_width() % c != 0 or img.get_height() % c != 0 or img.get_width() == 0:
			push_warning("Planches : %s%s fait %d × %d, pas un multiple de %d — ignoré" % [chemin(dossier), nom, img.get_width(), img.get_height(), c])
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		# Le calque suit la MÊME grille que le dessin : une planche de trois cases a un calque de trois cases.
		var pts: Image = null
		if points.has(nom.trim_suffix(".png")):
			pts = _image_de(chemin(dossier) + str(points[nom.trim_suffix(".png")]))
			if pts != null:
				if pts.get_format() != Image.FORMAT_RGBA8:
					pts.convert(Image.FORMAT_RGBA8)
				if pts.get_width() != img.get_width() or pts.get_height() != img.get_height():
					push_warning("Planches : %s%s ne fait pas la taille de son dessin — ignoré" % [chemin(dossier), str(points[nom.trim_suffix(".png")])])
					pts = null
		res.fichiers += 1
		for cy in img.get_height() / c:
			for cx in img.get_width() / c:
				var cell := Image.create(c, c, false, Image.FORMAT_RGBA8)
				cell.blit_rect(img, Rect2i(cx * c, cy * c, c, c), Vector2i.ZERO)
				cases.append(cell)
				if pts == null:
					calques.append(null)
				else:
					var cp := Image.create(c, c, false, Image.FORMAT_RGBA8)
					cp.blit_rect(pts, Rect2i(cx * c, cy * c, c, c), Vector2i.ZERO)
					calques.append(cp)
	if cases.is_empty():
		return res
	res.marqueurs = _lire_marqueurs(dossier, cases, calques, c)
	var colonne := Image.create(c, c * cases.size(), false, Image.FORMAT_RGBA8)
	for k in cases.size():
		colonne.blit_rect(cases[k], Rect2i(0, 0, c, c), Vector2i(0, k * c))
	res.n = cases.size()
	res.image = colonne
	return res


## LES MARQUEURS DE VISAGE (designer 2026-09-09 : « avoir sur chaque forme de visage des marqueurs pour les autres
## éléments… une couleur par élément… le sprite de l'élément correspondant est centré sur le pixel »).
##
## **L'idée marche parce que les planches sont en nuances de gris** : une couleur franche ne peut être que
## volontaire. Un pixel rouge sur une tête dit « l'œil va ici », et une tête à museau descend sa bouche sans qu'aucune
## règle ne connaisse le mot « museau ».
##
## On ne les lit que sous `visage/` — un membre n'a rien à ancrer, et balayer ses pixels serait du temps perdu au
## chargement. **Le pixel est EFFACÉ** après lecture : il ne se voit jamais en jeu, et une planche marquée reste une
## planche ordinaire pour tout le reste du code.
static func _lire_marqueurs(dossier: String, cases: Array[Image], calques: Array, c: int) -> Array:
	var res: Array = []
	if not dossier.begins_with("visage"):
		return res
	var table: Dictionary = GameData.config("styles").get("planches", {}).get("marqueurs", {})
	if table.is_empty():
		return res
	var tol := float(GameData.config("styles").get("planches", {}).get("marqueur_tolerance", 0.06))
	var couleurs: Array = []   # [[Color, element], …] — l'ordre du catalogue, pour un résultat stable
	for element: String in table.keys():
		if not element.begins_with("_"):
			couleurs.append([Color.html(str(table[element])), element])
	for k in cases.size():
		var trouves := {}
		# LE CALQUE D'ABORD : s'il y en a un, c'est LUI qui porte les points, et le dessin n'est pas touché. Sinon on
		# lit le dessin lui-même et l'on y efface ce qu'on trouve — l'ancien chemin, qui reste valable.
		var calque: Image = calques[k] if k < calques.size() and calques[k] != null else null
		var img: Image = calque if calque != null else cases[k]
		for y in c:
			for x in c:
				var px := img.get_pixel(x, y)
				if px.a < 0.5:
					continue
				# Un marqueur est une couleur SATURÉE : le gris d'une planche ne peut pas s'en approcher, donc ce
				# test écarte d'emblée 99 % des pixels sans comparer douze couleurs pour chacun.
				if maxf(px.r, maxf(px.g, px.b)) - minf(px.r, minf(px.g, px.b)) < 0.35:
					continue
				for paire in couleurs:
					var col: Color = paire[0]
					if absf(px.r - col.r) <= tol and absf(px.g - col.g) <= tol and absf(px.b - col.b) <= tol:
						var nom := str(paire[1])
						if not trouves.has(nom):
							trouves[nom] = []
						trouves[nom].append(Vector2(float(x) + 0.5, float(y) + 0.5))
						if calque == null:
							cases[k].set_pixel(x, y, Color(0, 0, 0, 0))   # posé dans le dessin : on l'en retire
						break
		for nom_t: String in trouves.keys():   # gauche puis droite : deux yeux se placent toujours dans le même ordre
			(trouves[nom_t] as Array).sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x if not is_equal_approx(a.x, b.x) else a.y < b.y)
		res.append(trouves)
	return res


## Les marqueurs d'une case : élément → positions (en pixels de case). Vide si la planche n'en porte pas.
static func marqueurs(dossier: String, index: int) -> Dictionary:
	var p := charger(dossier)
	var m: Array = p.get("marqueurs", [])
	if m.is_empty() or int(p.n) <= 0:
		return {}
	return m[posmod(index, m.size())]


## LES ANCRES PAR DÉFAUT d'un élément, en pixels de case : là où le visage les a toujours portés. Elles sont écrites
## en RAYONS DE TÊTE dans `styles.planches.ancres`, si bien que changer `visage_boite` ne les fausse pas.
static func ancres_defaut(element: String) -> Array:
	var st: Dictionary = GameData.config("styles").get("planches", {})
	var liste: Array = st.get("ancres", {}).get(element, [])
	var c := float(case())
	var r := c / maxf(0.001, float(st.get("visage_boite", 2.6)))
	var res: Array = []
	for a in liste:
		res.append(Vector2(c * 0.5 + float(a[0]) * r, c * 0.5 + float(a[1]) * r))
	return res


## L'image d'un PNG : importée (res://, l'export la porte) ou lue du disque (user://, les tests).
static func _image_de(chemin_png: String) -> Image:
	if chemin_png.begins_with("res://") and ResourceLoader.exists(chemin_png):
		var tex := load(chemin_png) as Texture2D
		return tex.get_image() if tex != null else null
	if FileAccess.file_exists(chemin_png):
		var img := Image.new()
		if img.load(chemin_png) == OK:
			return img
	return null


## Le nombre de variantes d'une planche (0 : pas de planche, on dessine par code).
static func variantes(dossier: String) -> int:
	return int(charger(dossier).n)


## L'image assemblée (les tests la lisent sans passer par une texture).
static func image(dossier: String) -> Image:
	return charger(dossier).image


## La texture de la planche, créée au premier dessin.
static func texture(dossier: String) -> Texture2D:
	var p := charger(dossier)
	if p.texture == null and p.image != null:
		p.texture = ImageTexture.create_from_image(p.image)
	return p.texture


## Dessine la case `index` (modulo le nombre de variantes) dans `rect`, teintée, miroir horizontal à la demande.
static func dessiner(ci: CanvasItem, dossier: String, index: int, rect: Rect2, teinte: Color = Color.WHITE, miroir: bool = false) -> bool:
	var p := charger(dossier)
	if int(p.n) <= 0:
		return false
	var tex := texture(dossier)
	if tex == null:
		return false
	var c := case()
	var k := posmod(index, int(p.n))
	var r := rect
	if miroir:   # une largeur négative retourne l'image de gauche à droite (le dernier paramètre de draw_texture_rect_region est la transposition, pas le miroir)
		r = Rect2(rect.position.x + rect.size.x, rect.position.y, -rect.size.x, rect.size.y)
	ci.draw_texture_rect_region(tex, r, Rect2(0, k * c, c, c), teinte)
	return true


## L'index d'une valeur de locus d'apparence (l'ordre de `apparence.json`), pour choisir la variante ; −1 si inconnue.
static func index_locus(locus: String, valeur: String) -> int:
	for l in GameData.config("apparence").get("loci", []):
		if str(l.get("id", "")) == locus:
			return (l.get("valeurs", []) as Array).find(valeur)
	return -1


## Oublie tout (les tests, un rechargement des assets).
static func vider() -> void:
	_cache.clear()
