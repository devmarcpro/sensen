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


## LES MARQUEURS D'ATTACHE (designer 2026-09-09 : « avoir sur chaque forme de visage des marqueurs pour les autres
## éléments… une couleur par élément… le sprite de l'élément correspondant est centré sur le pixel » ; puis
## 2026-09-10 : « pour le visage ET les éléments, de 2×2 … et aussi pour les membres pour les points de connexions
## entre membres … l'attache de base d'une teinte et des attaches annexes d'une teinte différente, pour prévoir les
## mutations »).
##
## **L'idée marche parce que les planches sont en nuances de gris** : une couleur franche ne peut être que
## volontaire. Un pixel rouge sur une tête dit « l'œil va ici », et une tête à museau descend sa bouche sans qu'aucune
## règle ne connaisse le mot « museau ».
##
## **La règle est la même pour le visage et pour les membres**, et c'est ce qui la rend apprenable : un CONTENANT
## porte les ancres de ses enfants (une tête porte `yeux`, un torse porte `bras`), une PIÈCE porte son propre point
## (un œil porte `yeux`, un bras porte `attache` et `bout`).
##
## **On REGROUPE les pixels voisins.** Un marqueur d'un seul pixel est invisible dans un logiciel de dessin — on le
## perd, on le décale sans le voir. Le designer en veut de 2 × 2 ; plutôt que d'exiger cette taille-là, on réunit
## tout amas de pixels contigus de même couleur en **un** marqueur posé sur son centre. Un 1 × 1 d'hier, un 2 × 2 de
## demain et la tache de trois pixels d'une main qui a dérapé donnent tous un point, et un seul.
##
## **Le rang 0 est la base**, ce que tout le monde a ; les rangs suivants sont des attaches ANNEXES, dessinées
## d'avance et qui ne coûtent rien tant qu'aucun être ne les réclame. C'est là tout leur intérêt : le designer place
## les possibilités une fois, dans le sprite, et une mutation n'a plus qu'à dire combien elle en prend.
##
## **Le pixel est EFFACÉ** après lecture s'il était posé dans le dessin ; sur un calque `<nom>.points.png`, le dessin
## n'est jamais touché. Une planche marquée reste une planche ordinaire pour tout le reste du code.
##
## Rend, par case : `{élément → [[Vector2…] du rang 0, [Vector2…] du rang 1, …]}`.
static func _lire_marqueurs(dossier: String, cases: Array[Image], calques: Array, c: int) -> Array:
	var res: Array = []
	var st: Dictionary = GameData.config("styles").get("planches", {})
	var mq: Dictionary = st.get("marqueurs", {})
	var table: Dictionary = mq.get("couleurs", {})
	if table.is_empty():
		return res
	# ON NE BALAIE QUE LES DOSSIERS QUI ONT UNE RAISON D'EN PORTER : lire les pixels d'une planche coûte au
	# chargement, et un dossier absent de la liste se charge comme un dessin ordinaire.
	var ou: Array = mq.get("dossiers", ["visage"])
	var concerne := false
	for prefixe in ou:
		if dossier.begins_with(str(prefixe)):
			concerne = true
			break
	if not concerne:
		return res
	var n_rangs: int = maxi(1, (mq.get("rangs", ["base"]) as Array).size())
	var tol := float(st.get("marqueur_tolerance", 0.10))
	# [[Color, élément, rang], …] — l'ordre du catalogue, pour un résultat stable d'une exécution à l'autre.
	var couleurs: Array = []
	for element: String in table.keys():
		if element.begins_with("_"):
			continue
		var liste: Array = table[element] if table[element] is Array else [table[element]]
		for r in liste.size():
			couleurs.append([Color.html(str(liste[r])), element, r])
	for k in cases.size():
		# LE CALQUE D'ABORD : s'il y en a un, c'est LUI qui porte les points, et le dessin n'est pas touché. Sinon on
		# lit le dessin lui-même et l'on y efface ce qu'on trouve — l'ancien chemin, qui reste valable.
		var calque: Image = calques[k] if k < calques.size() and calques[k] != null else null
		var img: Image = calque if calque != null else cases[k]
		# 1. CHAQUE PIXEL REÇOIT SON ÉTIQUETTE, ou -1. On reconnaît par LE PLUS PROCHE, jamais par une boîte de
		#    tolérance : avec soixante-neuf teintes, deux boîtes finissent par se toucher et un pixel répondrait à
		#    deux éléments — le premier du catalogue gagnerait, en silence. `tol` ne dit donc plus qui gagne, mais
		#    seulement à partir de quand un pixel coloré n'est le marqueur de personne.
		var etiq := PackedInt32Array()
		etiq.resize(c * c)
		var vide := true
		for y in c:
			for x in c:
				etiq[y * c + x] = -1
				var px := img.get_pixel(x, y)
				if px.a < 0.5:
					continue
				# Un marqueur est une couleur SATURÉE : le gris d'une planche ne peut pas s'en approcher, donc ce
				# test écarte d'emblée 99 % des pixels sans en comparer aucun aux soixante-neuf couleurs.
				if maxf(px.r, maxf(px.g, px.b)) - minf(px.r, minf(px.g, px.b)) < 0.35:
					continue
				var meilleur := -1
				var mieux := tol
				for i in couleurs.size():
					var col: Color = couleurs[i][0]
					var dist := maxf(absf(px.r - col.r), maxf(absf(px.g - col.g), absf(px.b - col.b)))
					if dist < mieux:
						mieux = dist
						meilleur = i
				etiq[y * c + x] = meilleur
				if meilleur >= 0:
					vide = false
					if calque == null:
						cases[k].set_pixel(x, y, Color(0, 0, 0, 0))   # posé dans le dessin : on l'en retire
		if vide:
			res.append({})
			continue
		# 2. LES PIXELS VOISINS DE MÊME ÉTIQUETTE FONT UN SEUL MARQUEUR, posé sur leur centre. C'est ce qui accepte
		#    le 2 × 2 demandé sans interdire le 1 × 1 d'avant ni punir un amas de travers.
		var trouves := {}
		var vus := {}
		for y0 in c:
			for x0 in c:
				var e0: int = etiq[y0 * c + x0]
				if e0 < 0 or vus.has(y0 * c + x0):
					continue
				var file: Array[Vector2i] = [Vector2i(x0, y0)]
				vus[y0 * c + x0] = true
				var somme := Vector2.ZERO
				var n := 0
				while not file.is_empty():
					var q: Vector2i = file.pop_back()
					somme += Vector2(float(q.x) + 0.5, float(q.y) + 0.5)
					n += 1
					for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var v: Vector2i = q + dv
						if v.x < 0 or v.y < 0 or v.x >= c or v.y >= c:
							continue
						var cle := v.y * c + v.x
						if vus.has(cle) or etiq[cle] != e0:
							continue
						vus[cle] = true
						file.append(v)
				var nom := str(couleurs[e0][1])
				var rang: int = int(couleurs[e0][2])
				if not trouves.has(nom):
					var par_rang: Array = []
					for _r in n_rangs:
						par_rang.append([])
					trouves[nom] = par_rang
				((trouves[nom] as Array)[mini(rang, n_rangs - 1)] as Array).append(somme / float(n))
		# gauche puis droite : deux yeux, deux bras se placent toujours dans le même ordre
		for nom_t: String in trouves.keys():
			for r2 in (trouves[nom_t] as Array).size():
				((trouves[nom_t] as Array)[r2] as Array).sort_custom(
					func(a: Vector2, b: Vector2) -> bool: return a.x < b.x if not is_equal_approx(a.x, b.x) else a.y < b.y)
		res.append(trouves)
	return res


## Les marqueurs de BASE d'une case : élément → positions (en pixels de case). Vide si la planche n'en porte pas.
## C'est le rang 0, celui que tout le monde a — les annexes se demandent par `marqueurs_rang`.
static func marqueurs(dossier: String, index: int) -> Dictionary:
	return marqueurs_rang(dossier, index, 0)


## Les marqueurs d'UN RANG : 0 la base, 1 et suivants les attaches annexes (les mutations). Un rang qu'aucune case
## ne porte rend un dictionnaire vide — *ce qui n'est pas dessiné ne se réclame pas*.
static func marqueurs_rang(dossier: String, index: int, rang: int) -> Dictionary:
	var p := charger(dossier)
	var m: Array = p.get("marqueurs", [])
	if m.is_empty() or int(p.n) <= 0:
		return {}
	var par_element: Dictionary = m[posmod(index, m.size())]
	var res := {}
	for element: String in par_element.keys():
		var rangs: Array = par_element[element]
		if rang >= 0 and rang < rangs.size() and not (rangs[rang] as Array).is_empty():
			res[element] = rangs[rang]
	return res


## Le nombre de rangs qu'une planche porte pour un élément : 1 s'il n'a que sa base, 0 s'il n'y est pas du tout.
## Ce que le pantin interroge avant de réclamer une annexe qui n'existe peut-être pas.
static func rangs_marques(dossier: String, index: int, element: String) -> int:
	var p := charger(dossier)
	var m: Array = p.get("marqueurs", [])
	if m.is_empty() or int(p.n) <= 0:
		return 0
	var rangs: Array = (m[posmod(index, m.size())] as Dictionary).get(element, [])
	var n := 0
	for r in rangs.size():
		if not (rangs[r] as Array).is_empty():
			n = r + 1
	return n


## LES ANCRES PAR DÉFAUT d'un élément, en pixels de case : là où le visage les a toujours portés. Elles sont écrites
## en RAYONS DE TÊTE dans `styles.planches.ancres`, si bien que changer `visage_boite` ne les fausse pas.
static func ancres_defaut(element: String, membre := false) -> Array:
	var st: Dictionary = GameData.config("styles").get("planches", {})
	var liste: Array = st.get("ancres", {}).get(element, [])
	var c := float(case())
	# DEUX UNITÉS, PARCE QUE DEUX CASES. La case d'un trait du visage est la TÊTE, mesurée en rayons de tête : c'est
	# ce qui fait que changer `visage_boite` ne fausse aucune ancre. La case d'un membre est le membre lui-même :
	# ses ancres se disent donc en fractions de case, le bas sur l'articulation et le haut sur le bout.
	var r := c if membre else c / maxf(0.001, float(st.get("visage_boite", 2.6)))
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
