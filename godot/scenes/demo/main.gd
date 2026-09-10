extends Node2D
## Prototype de combat — le CLIENT : rend l'état de la Simulation et lui envoie des intentions.
## Il ne décide de rien (Contraintes permanentes, règle 1) ; il rythme seulement l'avancement
## des horloges d'action pour que l'œil suive. Tout est dessiné en polygones — aucun asset.
## La lisibilité EST le game feel (Combat tactique sur grille) : timeline, coûts sur les tuiles
## atteignables, prévisualisation des dégâts, télégraphes, journal.

const TW := 40            # largeur d'une tuile à l'écran
const TH := 20            # hauteur du losange
const HSTEP := 8          # pixels par niveau de hauteur
const DELAI_PAS := 0.12   # secondes réelles entre deux pas d'une horloge de combat (lisibilité)
var _pile_hauteur := 22.0        # de combien un être monte à l'écran par étage de pile (styles.sprites.pile_hauteur)
var _pile_hauteur_meuble := 10.0 # de combien un meuble monte par étage de pile (styles.sprites.pile_hauteur_meuble)
var rayon_vue := 20              # tuiles dessinées autour du joueur : suit la fenêtre et le zoom (designer 2026-09-06, 23 h : « afficher plus à l'écran »), borné par styles.vue.rayon_max
var centre_terrain := Vector2i(-99, -99)   # la tuile du joueur à la dernière mise à jour des morceaux de terrain
var vue_version := -1                      # version du champ de vue dessiné (brouillard de guerre)
var centre_brouillard := Vector2i(-99, -99) # centre de la dernière passe du brouillard
var decouvert_dessine := -1                 # nombre de tuiles découvertes à la dernière mise à jour (une découverte = les morceaux du champ de vue)
const MORCEAU := 8                          # le terrain par morceaux de 8 × 8 tuiles (Budgets de performance, 2026-09-06)
const UV_HAUT := 4096.0                     # l'orientation d'une face, encodée dans UV.y pour le soleil (grain.gdshader, 2026-09-06) : le dessus
const UV_SO := -1000.0                      # la face sud-ouest (gauche)
const UV_SE := -2000.0                      # la face sud-est (droite)
const UV_PAS_FACE := 32.0                   # sur une face, la coordonnée de tuile × 32 plus la hauteur (moins de 32 unités)
const BLOC_UNITES := 2                      # un bloc de mur : deux unités de hauteur (hauteur_vue d'un mur), seize pixels
const NIVEAU_BLOCS := 3                     # un niveau de bâtiment : trois blocs (designer 2026-09-06, 15 h 30 : « change la hauteur de 1 étage de 2 blocs à 3 blocs »)
const PORTE_BLOCS := 2                      # une porte fait deux blocs (designer, 18 h)
const MUR_COUPE_UNITES := 1                 # la hauteur (en unités) d'un mur coupé : le mur sud ou est du bâtiment où l'on est (designer 2026-09-06, 16 h 30 : « quand on rentre dans un bâtiment, qu'on ne voie pas les murs sud et est »)
const MUR_TRANSLUCIDE := 0.45               # l'opacité d'un mur redessiné devant le joueur
var morceaux: Dictionary = {}               # Vector2i (colonne, ligne de morceau) → TerrainMorceau
var terrain_a_refaire := true               # une nouvelle grille, un changement de contrôle : tous les morceaux se refont
var _bat_joueur := 0                        # le bâtiment où se tient le joueur (0 : dehors) : ses murs sud et est sont coupés (designer 2026-09-06, 16 h 30)

var sim: Simulation
var arenes: Array[String] = []
var arene_courante := 0
## Le banc d'essai ouvert par le menu, s'il y en a un. Les bancs sont hors du cycle des arènes (Tab)
## depuis qu'un banc en tête de liste devenait l'arène de démarrage ; ils restaient donc INATTEIGNABLES
## (file d'attente du designer, point 74). On y va par le menu, nommément, et on en sort en rechargeant.
var arene_banc := ""
var joueur_id := ""
var chemin_en_cours: Array[Vector2i] = []
var minuterie_pas := 0.0
var minuterie_ui := 0.0
var minuterie_clavier := 0.0        # cadence des pas au clavier (ZQSD maintenu)
var hotbar_sel := -1                 # l'action sélectionnée dans la hotbar (1 → 0), −1 = aucune
var lourde_armee := false            # la prochaine attaque au clic est une lourde
var visee_objet := ""                # une bombe sélectionnée dans la hotbar, à lancer au clic
var visee_parchemin := ""            # un parchemin sélectionné : le clic lit le sort qu'il porte
var survol := Vector2i(-1, -1)
var mode_perimetre: Dictionary = {}   # un périmètre en cours de dessin : {type, coin} (Gestion de base, 2026-09-04)
var journal: Array[String] = []
var telegraphes: Dictionary = {}   # id → action engagée
var atteignables: Dictionary = {}
var camera_offset := Vector2.ZERO
var profil_sans_ui := false        # mesure de perf : saute la mise à jour du texte
var profil_sans_terrain := false   # mesure de perf : saute le dessin des tuiles
var visee := -1                    # capacité en cours de visée (index), -1 sinon
var ecran_fin: Array[String] = []  # récapitulatif du dernier combat (écran de fin), vide sinon
var ecran_fin_reste := 0.0         # il s'efface seul au bout de quelques secondes (designer, point 13)
var ecrans: Ecrans                 # inventaire, atelier, feuille (scenes/demo/ecrans.gd)
var minimap: Minimap               # coin haut-droit (Décision — Minimap en 2D)
var ambiance: CanvasModulate       # la lumière du cycle jour-nuit (un « uniform global »)
var lumieres: Node2D               # halos additifs des sources locales la nuit
var pluie: PluieVisuelle           # traits de pluie des états « arrose » (Météo, 2026-08-31)
var carte: Carte                   # la carte du monde (M), aussi le choix de la case de départ
var fiche_en_attente: Dictionary = {}   # la fiche créée, en attendant le choix de la case de départ
var minuterie_autosave := 300.0    # autosave toutes les 5 minutes réelles (Sauvegarde)
var creation: Dictionary = {}      # l'écran de création, tant que le personnage n'existe pas
var titre_ouvert := false          # l'écran principal (Écrans d'interface) : le monde derrière est un décor, l'entrée est bloquée
var xp_cumul: Dictionary = {}      # XP du joueur reçue dans la fenêtre en cours : clé → total (XP de combat)
var xp_fenetre := 0.0              # secondes restantes avant de « lâcher » le cumul en flottant + journal
var xp_flottants: Array = []       # [{lignes, t}] : les textes qui montent au-dessus du joueur
var gros_flottants: Array = []     # [{texte, pos, couleur, t}] : CRITIQUE / RATÉ en gros au-dessus d'un être
var graine_monde := -1             # la graine choisie à l'écran Monde, portée à la simulation
var monde_options: Dictionary = {}   # les réglages de génération choisis à l'écran Monde (designer, point 49)


## La config `planete` surchargée des réglages du joueur (designer 2026-08-31, point 49) :
## chaque option porte son chemin dans la config, aucune valeur n'est écrite en dur ici.
func planete_effective() -> Dictionary:
	var base: Dictionary = GameData.config("planete").duplicate(true)
	for opt in base.get("generation_options", []):
		var id_o := str(opt.id)
		if not monde_options.has(id_o):
			continue
		var valeur: Variant = monde_options[id_o]
		var parts: PackedStringArray = str(opt.chemin).split(".")
		var cible: Dictionary = base
		for k in parts.size() - 1:
			cible = cible[parts[k]]
		var cle := str(parts[parts.size() - 1])
		if bool(opt.get("paire", false)):   # un intervalle [min, max] : la valeur règle le haut, le bas suit
			cible[cle] = [maxi(0, int(valeur) - 6), int(valeur)]
		elif cible[cle] is float:
			cible[cle] = float(valeur)
		else:
			cible[cle] = int(valeur)
	return base


## La valeur courante d'une option, ou celle de la config si le joueur n'y a pas touché.
func option_monde(opt: Dictionary) -> float:
	if monde_options.has(str(opt.id)):
		return float(monde_options[str(opt.id)])
	var v: Variant = GameData.config("planete")
	for part in str(opt.chemin).split("."):
		v = (v as Dictionary)[part]
	if v is Array:
		var arr: Array = v
		return float(arr[arr.size() - 1])
	return float(v)
var fiche_monde: Dictionary = {}   # la fiche créée, en attente de l'écran Monde
var depart_donjon := false         # l'option de création « Départ : Donjon » (designer, point 34)
const STATS := ["force", "dexterite", "endurance", "volonte", "perception", "charisme"]
var zoom := 2.0   # le zoom de départ ; la valeur vraie vient de styles.vue.zoom.defaut au démarrage (2026-09-08)

var terrain: Terrain              # couche statique : les tuiles, dessinées une fois (perf É0)
var hud: Hud                      # couche au-dessus des êtres : barres, garde, télégraphes, jauges
var menu_contexte: MenuContexte   # le clic droit : une petite fenêtre au point cliqué (designer 2026-09-09)
var bandeau: BandeauJournal        # la dernière ligne du journal, en grand et par-dessus tout (ordre de travail 39)
var hud_ecran: HudEcran           # le HUD fixe à l'écran : compas-horloge, pentagramme, barres, hotbar (Écrans d'interface)
var chrono: Dictionary = {}        # étape de l'image → ms cumulées (la capture les lit : le lag en ville, designer 2026-09-05)
var tour_hud := 0


func _top_client(cle: String, t0: int) -> int:
	var dt := float(Time.get_ticks_usec() - t0) / 1000.0
	chrono[cle] = float(chrono.get(cle, 0.0)) + dt
	# Le PIRE de chaque étape, pas seulement son total (2026-09-07) : une saccade est une étape qui a coûté cher
	# UNE fois, et un cumul divisé par le nombre d'images la noie. C'est ce qui dit ce qu'il y a dans la pire image.
	if dt > float(chrono.get("max." + cle, 0.0)):
		chrono["max." + cle] = dt
	return Time.get_ticks_usec()
var volet: VoletLateral           # le volet latéral : monde, personnage, compagnons, journal, inventaire (designer 2026-09-04)
var volet_visible := true
var chargement_restant := 0.0     # écran de chargement entre cellules (Grille continue) : secondes restantes, 0 = fermé
var chargement_cellule := Vector2i.ZERO
var chargement: ColorRect         # le voile noir de l'écran de chargement, sur le CanvasLayer
var chargement_texte: Label
var brouillard: Brouillard        # couche du brouillard de guerre, au-dessus du terrain et des êtres
var toits: Toits                  # les toits des bâtiments, au-dessus des êtres (Villes, 2026-09-06)
var etage: Etage                  # l'étage du joueur, ses tuiles à leur hauteur (les couches Z, 2026-09-06)
var _soleil_dir := Vector3(0.0, 0.0, 1.0)   # la direction du soleil (espace écran) telle que _maj_soleil l'a réglée
var _soleil_force := 0.0
var _soleil_az_lumiere := -999.0            # l'azimut (degrés) pour lequel la lumière des tuiles a été calculée
## La lumière de chaque tuile (Éclairage, designer 2026-09-06 : « une échelle et une teinte ») : une texture RGB de la
## taille de la grille, calculée par le noyau (Grille.carte_lumiere : le ciel de l'heure, l'ombre portée, les torches),
## multipliée par le shader de grain sur chaque face, et donnée aux êtres et aux végétaux par leur modulate.
var _lumiere_img: Image = null
var _lumiere_tex: ImageTexture = null
var _lumiere_sale := true
var _lumiere_centre := Vector2i(-9999, -9999)   # la tuile du joueur au dernier calcul (l'ombre n'est calculée qu'autour de lui)
var _locale_derniere := PackedByteArray()       # la carte locale de la simulation au dernier calcul
var _ciel := Color.WHITE                        # le ciel de l'heure : niveau et teinte (cycle.lumiere)
var _ciel_derniere := Color(-1, -1, -1)
var _lumiere_dernier_ms := 0
const LUMIERE_PERIODE_MS := 500   # la carte locale de la simulation est relue au plus deux fois par seconde
var noeuds_vegetaux: Dictionary = {}   # index de tuile → Vegetal (billboards des arbres et plantes de la fenêtre)
var noeuds: Dictionary = {}       # id d'être → nœud creature.tscn (le paperdoll)
const SCENE_CREATURE := preload("res://scenes/entities/creature.tscn")

@onready var ui: Label = $CanvasLayer/Info
@onready var ui_droite: Label = $CanvasLayer/Droite
@onready var ui_bas: Label = $CanvasLayer/Bas   # journal + aide en bas : le centre de l'écran reste au joueur


## La couche statique du terrain : un conteneur de morceaux (Budgets de performance, 2026-09-06). Son propre
## `queue_redraw()` — l'ancien signal « tout redessiner » — refait tous les morceaux à l'image suivante.
class Terrain extends Node2D:
	var proprio: Node2D
	func _draw() -> void:
		proprio.terrain_a_refaire = true


## Un morceau de 16 × 16 tuiles : ses commandes de dessin persistent tant qu'aucune de ses tuiles ne change.
class TerrainMorceau extends Node2D:
	var proprio: Node2D
	var coin: Vector2i   # la colonne et la ligne du morceau, depuis l'origine de la grille
	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		proprio._dessiner_morceau(self, coin)
		proprio._top_client("draw.terrain", t0)
		proprio.chrono["n.terrain"] = float(proprio.chrono.get("n.terrain", 0.0)) + 1.0


## Le brouillard de guerre : une couche à part, redessinée seule quand le champ de vue change
## (le terrain, lui, reste statique) — opaque sur le jamais-vu, translucide sur le mémorisé.
class Brouillard extends Node2D:
	var proprio: Node2D
	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		proprio._dessiner_brouillard(self)
		proprio._top_client("draw.brouillard", t0)


## Les toits des bâtiments (Villes, 2026-09-06) : une couche AU-DESSUS des êtres — ce qui est sous un toit ne se voit
## pas — redessinée avec le brouillard ; le bâtiment où se tient le joueur n'y est pas dessiné.
class Toits extends Node2D:
	var proprio: Node2D
	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		proprio._dessiner_toits(self)
		proprio._top_client("draw.toits", t0)


## L'étage où se tient le joueur (les couches Z, 2026-09-06) : les tuiles de la couche z de son bâtiment, dessinées à
## leur hauteur au-dessus de la rue — le sol de l'étage, ses murs (nord et ouest entiers, sud et est en muret), ses meubles.
class Etage extends Node2D:
	var proprio: Node2D
	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		proprio._dessiner_etage(self)
		proprio._top_client("draw.etage", t0)




## La couche d'interface au-dessus des êtres (z fixe, toujours visible).
class Hud extends Node2D:
	var proprio: Node2D
	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		proprio._dessiner_hud(self)
		proprio._top_client("draw.hud", t0)


## Le grain procédural du décor (designer 2026-09-01, point 50) : un ShaderMaterial posé sur les
## calques du monde. Les chiffres viennent des données (styles.grain) — rien en dur, aucun asset.
func _materiau_grain() -> ShaderMaterial:
	var cfg: Dictionary = GameData.config("styles").get("grain", {})
	if not bool(cfg.get("actif", true)):
		return null
	var sh: Shader = load("res://shaders/grain.gdshader")
	if sh == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for cle in ["grains_par_tuile", "force_grain", "force_douce", "echelle_douce", "pas_style"]:   # pas_style manquait : le shader gardait sa valeur par défaut (2026-09-08)
		if cfg.has(cle):
			mat.set_shader_parameter(cle, float(cfg[cle]))
	var sol: Dictionary = GameData.config("planete").get("cycle", {}).get("soleil", {})
	mat.set_shader_parameter("ombre_min", float(sol.get("ombre_min", 0.72)))
	mat.set_shader_parameter("elevation_max", float(sol.get("elevation_max", 65.0)))
	_charger_atlas_matieres()   # les matières peintes (2026-09-08) : l'atlas et le seuil de style
	if _atlas_matieres != null:
		mat.set_shader_parameter("matieres_tex", _atlas_matieres)
		mat.set_shader_parameter("matieres_n", float(_lignes_matieres.size()))
		mat.set_shader_parameter("style_texture_base", float(cfg.get("style_texture_base", 100)))
		mat.set_shader_parameter("teinte_matiere", float(cfg.get("teinte_matiere_peinte", 1.0)))       # une tuile a sa texture ET la teinte de sa matière (2026-09-08)
		mat.set_shader_parameter("teinte_normalisee", 1.0 if bool(cfg.get("teinte_matiere_normalisee", true)) else 0.0)
	mat.set_shader_parameter("fondu_pixels", 1.0 if bool(cfg.get("fondu_pixels", true)) else 0.0)   # le fondu par pixels tirés (designer 2026-09-09)
	_materiaux_grain.append(mat)   # le soleil se règle sur tous (_maj_soleil)
	return mat


var _materiaux_grain: Array[ShaderMaterial] = []   # les matériaux de grain vivants : terrain, brouillard, toits, paperdolls
var _grain_paperdolls: ShaderMaterial = null       # un seul matériau pour tous les paperdolls (leurs occulteurs s'éclairent comme le terrain)


## La direction du soleil à cette heure (Éclairage, 2026-09-06) : il se lève à aube[0] à l'est (la droite de l'écran),
## culmine au sud (le bas) à elevation_max, se couche à crepuscule[1] à l'ouest ; la nuit, aucun ombrage (force 0).
func _maj_soleil(h: float, en_surface: bool) -> void:
	var c: Dictionary = GameData.config("planete").get("cycle", {})
	var sol: Dictionary = c.get("soleil", {})
	var direction := Vector3(0.0, 0.0, 1.0)
	var force := 0.0
	if en_surface and bool(sol.get("actif", true)) and c.has("aube") and c.has("crepuscule"):
		var lever := float(c.aube[0])
		var coucher := float(c.crepuscule[1])
		if h >= lever and h <= coucher and coucher > lever:
			var f := (h - lever) / (coucher - lever)   # 0 au lever, 1 au coucher
			var az := PI * f                            # 0 : l'est (droite), π/2 : le sud (bas), π : l'ouest (gauche)
			var el := deg_to_rad(float(sol.get("elevation_max", 65.0))) * sin(PI * f)
			direction = Vector3(cos(az) * cos(el), sin(az) * cos(el), sin(el))
			force = clampf(sin(PI * f) * 4.0, 0.0, 1.0)   # s'allume et s'éteint en douceur à l'horizon
	for m in _materiaux_grain:
		m.set_shader_parameter("soleil", direction)
		m.set_shader_parameter("soleil_force", force)
	_soleil_dir = direction
	_soleil_force = force
	# La lumière des tuiles se refait quand le soleil a tourné d'ombre_portee_pas_deg (ou qu'il s'éteint / s'allume).
	var az_deg := rad_to_deg(atan2(direction.y, direction.x)) if force > 0.0 else -999.0
	if absf(az_deg - _soleil_az_lumiere) >= float(sol.get("ombre_portee_pas_deg", 3)):
		_soleil_az_lumiere = az_deg
		_lumiere_sale = true




## Une couleur « #rrggbb » lue une fois : le dessin d'un morceau de terrain en analysait une par tuile (2026-09-06).
static var _couleurs_html: Dictionary = {}
static func _couleur_html(s: String) -> Color:
	var c = _couleurs_html.get(s)
	if c == null:
		c = Color.html(s)
		_couleurs_html[s] = c
	return c


## Le style de texture d'un matériau (designer 2026-09-01, point 58) : sa famille décide du motif
## (roche veinée, terre grumeleuse, bois fibré…), un matériau nommé peut le surcharger. Le style est
## encodé dans la partie haute de UV.x — la 2D n'offre pas d'autre canal par sommet.
static var _styles_grain: Dictionary = {}   # matériau → style : quatre lectures de configuration par tuile, sinon (2026-09-06)
## LES MATIÈRES PEINTES (designer 2026-09-08 : « j'ai rajouté une texture herbe, mets-la en jeu ») : un PNG de 64 × 64
## par matériau dans `assets/terrain/`, empilés en un atlas dans l'ordre de leurs noms. Le style d'un matériau peint
## vaut `style_texture_base + sa ligne` — le nombre voyage dans UV.x comme n'importe quel style, donc ni `PassesGD`,
## ni le noyau C++, ni le cache des morceaux n'ont une ligne à changer : seuls le client et le shader savent.
static var _atlas_matieres: ImageTexture = null
static var _lignes_matieres: Dictionary = {}   # matériau → sa ligne dans l'atlas
static var _atlas_matieres_charge := false

static func _charger_atlas_matieres() -> void:
	if _atlas_matieres_charge:
		return
	_atlas_matieres_charge = true
	var c := Planches.case()
	var dir := DirAccess.open("res://assets/terrain/")
	if dir == null:
		return
	var noms: Array[String] = []
	for f in dir.get_files():
		var nom := str(f)
		if nom.ends_with(".png.import"):   # l'export ne garde que l'import : le nom du PNG est dedans
			nom = nom.trim_suffix(".import")
		if nom.ends_with(".png") and not (nom in noms):
			noms.append(nom)
	noms.sort()   # l'ordre des noms fait l'ordre des lignes : ajouter une matière ne déplace que les suivantes
	var cases: Array[Image] = []
	for nom in noms:
		var chemin := "res://assets/terrain/" + nom
		var tex := load(chemin) as Texture2D
		var img: Image = tex.get_image() if tex != null else null
		if img == null or img.get_width() != c or img.get_height() != c:
			push_warning("Terrain : %s n'est pas une case de %d × %d — ignoré" % [chemin, c, c])
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		_lignes_matieres[nom.trim_suffix(".png")] = cases.size()
		cases.append(img)
	if cases.is_empty():
		return
	var colonne := Image.create(c, c * cases.size(), false, Image.FORMAT_RGBA8)
	for k in cases.size():
		colonne.blit_rect(cases[k], Rect2i(0, 0, c, c), Vector2i(0, k * c))
	_atlas_matieres = ImageTexture.create_from_image(colonne)


func _style_grain(materiau: String) -> float:
	if materiau.is_empty():
		return 0.0
	var memo = _styles_grain.get(materiau)
	if memo != null:
		return memo
	var cfg: Dictionary = GameData.config("styles").get("grain", {})
	_charger_atlas_matieres()
	var texture_nom := str(cfg.get("textures_par_materiau", {}).get(materiau, materiau))   # la matière peut pointer une texture qui ne porte pas son nom
	if _lignes_matieres.has(texture_nom):   # une matière peinte : son style DÉSIGNE sa ligne dans l'atlas
		var stp := (float(cfg.get("style_texture_base", 100)) + float(_lignes_matieres[texture_nom])) * float(cfg.get("pas_style", 512.0))
		_styles_grain[materiau] = stp
		return stp
	var nom := str(cfg.get("styles_par_materiau", {}).get(materiau, ""))
	if nom.is_empty():
		var m: Dictionary = GameData.catalogues.materials.get(materiau, {})
		nom = str(cfg.get("styles_par_categorie", {}).get(str(m.get("category", m.get("categorie", ""))), "uni"))
	var st := float(int(cfg.get("styles", {}).get(nom, 0))) * float(cfg.get("pas_style", 512.0))
	_styles_grain[materiau] = st
	return st


## Une couleur de styles.json ([r, g, b] ou [r, g, b, a]).
static func _couleur_liste(l: Variant) -> Color:
	if l is Array and (l as Array).size() >= 3:
		return Color(float(l[0]), float(l[1]), float(l[2]), float(l[3]) if (l as Array).size() > 3 else 1.0)
	return Color.WHITE


func _ready() -> void:
	# Les planches assemblées AVANT la première image (2026-09-07) : sinon le premier villageois qui montre son
	# visage fait charger et découper ses PNG en plein `_draw` — mesuré, c'est la saccade des premières secondes.
	var t_pl := Time.get_ticks_usec()
	var n_pl := Planches.prechauffer()
	chrono["planches.prechauffe"] = float(Time.get_ticks_usec() - t_pl) / 1000.0
	chrono["n.planches"] = float(n_pl)
	RenderingServer.set_default_clear_color(_couleur_liste(GameData.config("styles").get("brouillard", {}).get("fond", [0.02, 0.02, 0.04])))   # le fond de la scène : la nuit du jamais-vu, pas un gris (designer 2026-09-06)
	zoom = float(GameData.config("styles").get("vue", {}).get("zoom", {}).get("defaut", zoom))   # le zoom de départ, en données (2026-09-08)
	terrain = Terrain.new()
	terrain.proprio = self
	terrain.material = _materiau_grain()   # le décor prend son grain (point 50)
	terrain.z_index = -60   # couches du monde SOUS les êtres et les végétaux (z 1..4000) : brouillard, voile, halos (2026-08-30) — les morceaux (z relatif 0..46 = colonne + ligne, 2026-09-06) restent sous le brouillard (-2), les voiles (-4), les halos (-3)
	add_child(terrain)
	brouillard = Brouillard.new()
	brouillard.proprio = self
	brouillard.material = _materiau_grain()   # les murs mémorisés sont dessinés ici : ils prennent le grain aussi (point 58)
	brouillard.z_as_relative = false
	brouillard.z_index = -2
	add_child(brouillard)
	toits = Toits.new()
	toits.proprio = self
	toits.material = _materiau_grain()   # le chaume et la tuile prennent le grain comme les murs
	toits.z_as_relative = false
	toits.z_index = 4001   # au-dessus des êtres (1..4000), sous la pluie (4050) et le HUD (4090)
	add_child(toits)
	etage = Etage.new()
	etage.proprio = self
	etage.material = _materiau_grain()
	etage.z_as_relative = false
	etage.z_index = -1   # au-dessus du terrain et du brouillard, sous les êtres
	add_child(etage)
	hud = Hud.new()
	hud.proprio = self
	hud.z_as_relative = false
	hud.z_index = 4090   # au-dessus des êtres (états, flottants, barres)
	add_child(hud)
	pluie = PluieVisuelle.new()
	pluie.proprio = self
	pluie.top_level = true   # effet d'écran : la pluie ignore le déplacement caméra de la scène (main bouge, elle non)
	pluie.z_as_relative = false
	pluie.z_index = 4050   # la pluie tombe devant le monde et les êtres, sous le HUD (Météo, 2026-08-31)
	add_child(pluie)
	EventBus.damage_dealt.connect(func(src: String, cible_d: String, d: int, _det: Dictionary) -> void:
		if noeuds.has(src):
			noeuds[src].frapper()
		if d > 0 and noeuds.has(cible_d):   # le blessé tremble et clignote rouge (designer 2026-09-05, 13 h)
			noeuds[cible_d].encaisser())
	# Les arènes du prototype, SANS les bancs d'essai : le banc d'objets remplit vingt-quatre coffres au
	# chargement, et comme la liste est triée il passait en tête — donc en arène de démarrage. Le jeu
	# mettait des secondes à s'ouvrir sur une salle de démonstration (designer, 2026-09-02 : « la fenêtre
	# Sensen debug ne se lance pas »). On y va par le menu, pas par accident.
	arenes.assign(GameData.catalogues.get("prototype_arenas", {}).keys().filter(
		func(a: String) -> bool: return not ("banc" in GameData.entree("prototype_arenas", a).get("tags", []))))
	arenes.sort()
	EventBus.journal.connect(_sur_journal)
	EventBus.coup_critique.connect(func(_att: String, cible_id: String, mult: float) -> void:
		if sim != null and sim.entites.has(cible_id):
			gros_flottants.append({"texte": tr("ui.critique").format({"mult": "%.1f" % mult}), "pos": sim.entites[cible_id].pos, "couleur": Color(1.0, 0.85, 0.3), "t": 0.0}))
	EventBus.coup_rate.connect(func(att_id: String) -> void:
		if sim != null and sim.entites.has(att_id):
			gros_flottants.append({"texte": tr("ui.rate"), "pos": sim.entites[att_id].pos, "couleur": Color(0.75, 0.75, 0.75), "t": 0.0}))
	EventBus.xp_gagnee.connect(func(id: String, cle: String, xp: int) -> void:
		if id == joueur_id and xp > 0:
			xp_cumul[cle] = int(xp_cumul.get(cle, 0)) + xp
			xp_fenetre = 0.4)
	EventBus.fenetre_recentree.connect(func(o: Vector2i) -> void:
		_apres_recentrage(o))
	EventBus.action_engaged.connect(func(id: String, a: Dictionary) -> void: telegraphes[id] = a)
	EventBus.action_resolved.connect(func(id: String, _a: Dictionary) -> void: telegraphes.erase(id))
	EventBus.combat_ended.connect(_sur_fin_de_combat)
	EventBus.expedition_terminee.connect(_sur_fin_d_expedition)
	EventBus.controle_change.connect(func(id: String) -> void:
		joueur_id = id
		vue_version = -1
		terrain.queue_redraw()
		queue_redraw())
	EventBus.tile_changed.connect(func(p: Vector2i) -> void:
		_salir_tuile(p)   # seul le morceau de la tuile (et ceux de ses voisines de bord) se redessine
		_lumiere_sale = true
		if sim != null:
			sim.lumiere_sale = true
		lumieres.queue_redraw()
		toits.queue_redraw()
		etage.queue_redraw()
		var i := sim.grille.idx(p) if sim != null else -1
		if noeuds_vegetaux.has(i):
			noeuds_vegetaux[i].queue_free()
			noeuds_vegetaux.erase(i))
	GameData.donnees_rechargees.connect(_charger)
	ecrans = Ecrans.new()
	ecrans.main = self
	add_child(ecrans)
	hud_ecran = HudEcran.new()
	hud_ecran.main = self
	$CanvasLayer.add_child(hud_ecran)
	menu_contexte = MenuContexte.new()   # la petite fenêtre du clic droit (designer 2026-09-09)
	menu_contexte.main = self
	menu_contexte.sur_choix = func(opt: Dictionary) -> void: _executer_option(opt)
	$CanvasLayer.add_child(menu_contexte)
	volet = VoletLateral.new()
	volet.main = self
	$CanvasLayer.add_child(volet)
	bandeau = BandeauJournal.new()   # le refus visible (ordre de travail 39) : sa propre couche, au-dessus des écrans
	add_child(bandeau)
	chargement = ColorRect.new()   # l'écran de chargement : par-dessus tout, fermé par défaut
	chargement.color = Color(0.02, 0.02, 0.03, 1.0)
	chargement.set_anchors_preset(Control.PRESET_FULL_RECT)
	chargement.mouse_filter = Control.MOUSE_FILTER_STOP
	chargement.visible = false
	$CanvasLayer.add_child(chargement)
	chargement_texte = Label.new()
	chargement_texte.set_anchors_preset(Control.PRESET_CENTER)
	chargement_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chargement_texte.add_theme_font_size_override("font_size", 18)
	chargement.add_child(chargement_texte)
	ambiance = CanvasModulate.new()
	add_child(ambiance)
	lumieres = Node2D.new()
	lumieres.z_as_relative = false
	lumieres.z_index = -3
	var mat_add := CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lumieres.material = mat_add
	lumieres.draw.connect(_dessiner_lumieres)
	add_child(lumieres)
	minimap = Minimap.new()
	minimap.main = self
	$CanvasLayer.add_child(minimap)
	carte = Carte.new()
	carte.main = self
	add_child(carte)
	EventBus.chunk_explored.connect(func(_c: Vector2i) -> void: minimap.rafraichir(true))
	EventBus.sauvegarde_faite.connect(func(nom: String) -> void: _log(tr("journal.sauvegarde").format({"nom": nom})))
	var tutoriels := Tutoriels.new()
	tutoriels.afficher = func(texte: String) -> void: _log("💡 " + texte)
	add_child(tutoriels)
	_charger()
	if not (OS.get_cmdline_user_args().has("--sans-creation") or DisplayServer.get_name() == "headless"):
		_ouvrir_titre()   # le jeu s'ouvre sur l'écran principal (Écrans d'interface, 2026-08-30)


## L'écran principal : par-dessus l'arène de décor, monde en pause, entrée bloquée hors du panneau.
func _ouvrir_titre() -> void:
	titre_ouvert = true
	creation = {}
	fiche_en_attente = {}
	carte.fermer()
	minimap.visible = false
	hud_ecran.queue_redraw()
	ecrans.ouvrir("titre")


## Les parties enregistrées (un dossier par partie), la plus récente d'abord, avec leur résumé — assez
## pour peupler l'écran Charger sans charger un seul monde (designer 2026-09-02).
static func parties_presentes() -> Array:
	var parties: Array = []
	var d := DirAccess.open(Sauvegarde.RACINE)
	if d == null:
		return parties
	for nom in d.get_directories():
		if not Sauvegarde.existe(nom):
			continue
		var w: Variant = Sauvegarde.lire(nom, "world.json")
		var res: Dictionary = (w as Dictionary).get("resume", {}) if w is Dictionary else {}
		parties.append({"slot": nom, "resume": res})
	parties.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.resume.get("ecrit_le", "")) > str(b.resume.get("ecrit_le", "")))
	return parties


## L'emplacement d'une partie neuve : le nom du personnage, rendu sûr pour un dossier, plus un suffixe
## qui évite d'écraser une partie précédente jouée avec le même nom (designer 2026-09-02).
static func slot_neuf(nom_perso: String) -> String:
	var base := ""
	for c in nom_perso.to_lower():
		base += c if c in "abcdefghijklmnopqrstuvwxyz0123456789" else "_"
	base = base.strip_edges().trim_prefix("_").trim_suffix("_")
	if base.is_empty():
		base = "partie"
	var slot := base
	var n := 2
	while Sauvegarde.existe(slot):
		slot = "%s_%d" % [base, n]
		n += 1
	return slot


## Nouvelle partie : l'écran de création du personnage, puis l'écran Monde, puis la carte (case de départ).
func _nouvelle_partie() -> void:
	ecrans.fermer()
	titre_ouvert = false
	minimap.visible = true
	var cfg_c: Dictionary = GameData.config("creation")
	var des_c := Des.new(randi())   # les stats de base sont tirées aux dés (designer, point 48)
	var tirage_c := {}
	for st_c in STATS:
		tirage_c[st_c] = des_c.jet(str(cfg_c.get("stats_des", "1d6+2")))
	creation = {"race": 0, "classe": 0, "stat": 0, "points": {}, "annee": int(cfg_c.get("annee_defaut", 1000)), "nom": "", "apparence": {}, "tirage": tirage_c}
	titre_ouvert = true   # l'écran de création est un vrai écran (Écrans d'interface, 2026-08-30) : rien ne tourne derrière
	minimap.visible = false
	ui.text = ""
	ecrans.ouvrir("creation")


## Continuer / Charger : la sauvegarde `nom` ; sans elle, retour au titre.
func _charger_partie(nom: String = "") -> void:
	if nom.is_empty():   # « Continuer » : la partie touchée le plus récemment
		var toutes := parties_presentes()
		nom = str(toutes[0].slot) if not toutes.is_empty() else "monde"
	ecrans.fermer()
	titre_ouvert = false
	minimap.visible = true
	arene_courante = arenes.size()
	if sim.charger_sauvegarde(nom):
		joueur_id = ""
		for e in sim.vivants():
			if e.controle == "joueur":
				joueur_id = e.id
		_apres_changement_de_grille()
		_log(tr("journal.chargement"))
	else:
		_log(tr("journal.pas_de_sauvegarde"))
		_ouvrir_titre()


## Écran Monde validé : le monde est généré avec la graine choisie, puis la carte s'ouvre pour la case de départ.
func _commencer_monde() -> void:
	ecrans.fermer()
	titre_ouvert = false
	minimap.visible = true
	arene_courante = arenes.size()   # une partie commence au camp, sur le monde (Début de partie)
	arene_banc = ""   # une partie ne commence jamais sur un banc d'essai
	_charger(fiche_monde)
	sim.nom_partie = slot_neuf(tr(str(fiche_monde.get("name_key", "creature.aventurier.name"))))   # un dossier par partie
	_kit_de_test()
	fiche_en_attente = fiche_monde
	fiche_monde = {}
	carte.ouvrir("depart")


## L'écran de création : R race, C classe, ↑↓ stat, +/− points, ← → année de naissance, Entrée.
## Le nom et la description d'un talent (Talents de classe / de race) pour l'écran de création.
func _texte_talent(id: String) -> String:
	if id.is_empty():
		return tr("ui.creation.sans_talent")
	var t: Dictionary = GameData.catalogues.get("talents", {}).get(id, {})
	if t.is_empty():
		return id
	return "%s — %s" % [tr(t.name_key), tr(t.desc_key)]


func _texte_creation() -> String:
	var races: Array = GameData.catalogues.races.keys()
	var classes: Array = _classes_visibles()
	races.sort()
	classes.sort()
	var race: String = races[creation.race % races.size()]
	var classe: String = classes[creation.classe % classes.size()]
	var cl: Dictionary = GameData.entree("classes", classe)
	var total := 30 + int(cl.get("points_creation_bonus", 0))
	var utilises := 0
	for st in STATS:
		utilises += int(creation.points.get(st, 0))
	var prog: Progression = Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	var signe := prog.signe(int(creation.annee))
	var l: Array[String] = [tr("ui.creation.titre"), tr("ui.creation.race").format({"race": tr(GameData.entree("races", race).name_key)}),
		tr("ui.creation.classe").format({"classe": tr(cl.name_key), "talent": _texte_talent(str(cl.get("talent", "")))}),
		tr("ui.creation.talent_race").format({"talent": _texte_talent(str(GameData.entree("races", race).get("talent", "")))}),
		tr("ui.creation.points").format({"restants": total - utilises, "total": total})]
	for i in STATS.size():
		var st: String = STATS[i]
		var base := 5 + int(creation.points.get(st, 0)) + int(GameData.entree("races", race).bonus_stats.get(st, 0)) + int(cl.bonus_stats.get(st, 0))
		l.append(("▶ " if i == creation.stat else "   ") + "%s : %d" % [tr("stat." + st), base])
	l.append(tr("ui.creation.signe").format({"annee": creation.annee, "element": tr("element." + signe.element), "animal": tr("animal." + signe.animal)}))
	l.append(tr("ui.creation.aide"))
	return "\n".join(l)


func _creer_personnage() -> void:
	var races: Array = GameData.catalogues.races.keys()
	var classes: Array = _classes_visibles()
	races.sort()
	classes.sort()
	var prog := Progression.new(GameData.config("combat_rules").progression, GameData.catalogues.competences, GameData.config("astrologie"))
	var fiche := Etres.creer_personnage("creature.aventurier.name", races[creation.race % races.size()], classes[creation.classe % classes.size()], creation.points, int(creation.annee), prog, creation.get("tirage", {}))
	# Personnalisation (Écrans d'interface, 2026-08-30) : le nom choisi et la teinte du personnage.
	var nom_choisi := str(creation.get("nom", "")).strip_edges()
	if not nom_choisi.is_empty():
		GameData.enregistrer_nom("joueur.nom", nom_choisi)
		fiche.name_key = "joueur.nom"
	var peau_choisie := str(creation.get("apparence", {}).get("teinte_peau", fiche.get("apparence", {}).get("teinte_peau", "")))
	if peau_choisie.begins_with("#"):   # la roue écrit la couleur en clair (designer 2026-09-08)
		var cp := Color.html(peau_choisie)
		fiche.teinte = [cp.r, cp.g, cp.b]
	else:
		for t_peau in GameData.config("apparence").get("teintes_peau", []):   # le teint peint tout le corps (point 43)
			if str(t_peau.id) == peau_choisie:
				fiche.teinte = [float(t_peau.rgb[0]), float(t_peau.rgb[1]), float(t_peau.rgb[2])]
	if not fiche.has("modules_connus"):
		fiche["modules_connus"] = []
	for cap in fiche.capacites:   # les modules des capacités de départ sont connus : on peut les recombiner (Structure compétences-modules-slots)
		for m in cap.get("modules", []):
			if not (str(m) in fiche.modules_connus):
				fiche.modules_connus.append(str(m))
	fiche["poses"] = creation.get("poses", {}).duplicate(true)   # les poses articulées à la création (point 63)
	fiche["serments"] = (creation.get("serments", []) as Array).duplicate()   # les serments prononcés à la création
	for cle: String in creation.get("apparence", {}).keys():   # les loci réglés à la création (points 39 et 41)
		fiche.apparence[cle] = creation.apparence[cle]
	depart_donjon = int(creation.get("depart", 0)) == 1   # point 34 : capturée avant l'effacement
	creation = {}
	var interactif := DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--sans-creation")
	if interactif:
		# Début de partie : l'écran Monde (graine), puis la carte pour choisir sa case (Écrans d'interface).
		fiche_monde = fiche
		if graine_monde < 0:   # une graine imposée (outil de capture, tests) est respectée
			graine_monde = randi() % 1000000
		monde_options = {}
		titre_ouvert = true
		ecrans.ouvrir("monde")
		return
	_charger(fiche)
	_kit_de_test()


## Mode test (Grimoires et manuels, décision du 2026-08-30) : tous les modules du catalogue au joueur à la nouvelle partie.
func _kit_de_test() -> void:
	if not bool(GameData.config("combat_rules").get("modules", {}).get("tout_au_depart", false)):
		return
	var j := joueur()
	if not j.is_empty():
		sim.triche(j, "modules")


## Le joueur a cliqué sa case de départ (Début de partie) : le camp y est établi.
func _choisir_depart(cell: Vector2i) -> void:
	if fiche_en_attente.is_empty() or sim.monde == null or not sim.monde.surface.terre_a(cell):
		return
	sim.monde.fermer()
	sim = Simulation.new(0x68EE)
	sim.graine_monde = graine_monde
	sim.planete_options = planete_effective()
	sim.fiche_joueur = fiche_en_attente
	sim.charger_camp({}, cell)
	_kit_de_test()   # le joueur est recréé sur la case choisie : le kit de test aussi
	fiche_en_attente = {}
	joueur_id = ""
	for e in sim.vivants():
		if e.controle == "joueur":
			joueur_id = e.id
	_apres_changement_de_grille()
	carte.fermer()
	if depart_donjon:   # point 34 : le camp est posé, l'expédition part sur-le-champ
		depart_donjon = false
		if sim.commencer_en_donjon(joueur()):
			_apres_changement_de_grille()
	_log(tr("journal.depart_choisi").format({"x": cell.x, "y": cell.y, "biome": tr(GameData.catalogues.biomes.get(str(sim.camp_sauve.get("biome", "")), {}).get("name_key", ""))}))


## Voyage rapide depuis la carte — ou revendication d'une cellule contiguë au territoire (Expansion territoriale).
func _voyager(cell: Vector2i) -> void:
	if sim.monde != null and sim.monde.revendicable(cell, sim.horloge_monde.ticks):
		sim.revendiquer(joueur(), cell)
		carte.dessin.queue_redraw()
		return
	if sim.voyager(joueur(), cell):
		carte.fermer()
		_apres_changement_de_grille()


## Un pas sur la carte du monde (designer, 2026-09-05, point 98) : le joueur marche jusqu'à la cellule voisine —
## au coût de la marche — et la carte reste ouverte, recentrée sur lui ; arrivé sur un donjon, elle se ferme.
func _pas_sur_la_carte(pas: Vector2i) -> void:
	var j := joueur()
	if j.is_empty() or sim.monde == null or sim.lieu != "camp":
		return
	var cell: Vector2i = sim.monde.cellule_de(j.pos) + pas
	if not sim.voyager(j, cell):
		return
	_apres_changement_de_grille()
	if sim.lieu != "camp":   # un donjon sur la cellule : on y est entré, la carte n'a plus de sens
		carte.fermer()
		return
	carte.recentrer(cell)


func _charger(fiche: Dictionary = {}) -> void:
	if fiche.is_empty() and sim != null and not sim.fiche_joueur.is_empty():
		fiche = sim.fiche_joueur
	sim = Simulation.new(0x68EE)
	sim.graine_monde = graine_monde
	sim.fiche_joueur = fiche
	if not arene_banc.is_empty():
		sim.charger_arene(arene_banc)
	elif arene_courante >= arenes.size():
		sim.charger_camp()   # Tab après les arènes : le camp de base (E sur l'entrée : le donjon)
	else:
		sim.charger_arene(arenes[arene_courante])
	joueur_id = ""
	for e in sim.vivants():
		if e.controle == "joueur":
			joueur_id = e.id
	# LES DEUX ORIGINES (2026-09-08) : `_charger` refaisait tout ce que fait `_apres_changement_de_grille` SAUF poser
	# l'origine de dessin — elle restait à (0, 0) pendant que la grille était à (36416, 19072). Les coordonnées de
	# tuile écrites dans les UV devenaient donc des coordonnées MONDE, qui noyaient le style de la matière encodé
	# dans la partie haute de UV.x : le sol tirait un motif au hasard. Invisible jusqu'ici parce que le shader
	# n'atteignait même pas les morceaux (voir `use_parent_material`).
	origine_grille = sim.grille.origine if sim.grille != null else Vector2i(-99999, -99999)
	origine_dessin = sim.grille.origine if sim.grille != null else Vector2i.ZERO
	chemin_en_cours.clear()
	telegraphes.clear()
	journal.clear()
	sim.annoncer_jour()   # le journal vidé rouvre par la date et les fêtes du jour au premier tick (Calendrier)
	carte.preparer()   # la carte du monde se peint en arrière-plan dès maintenant (Carte du monde, 2026-09-06)
	terrain.queue_redraw()
	for n in noeuds.values():
		n.queue_free()
	noeuds.clear()
	for v in noeuds_vegetaux.values():
		v.queue_free()
	noeuds_vegetaux.clear()
	vue_version = -1
	centre_brouillard = Vector2i(-99, -99)
	brouillard.queue_redraw()
	toits.queue_redraw()
	etage.queue_redraw()
	# Les rappels de touches ne s'affichent plus à l'écran (demande du designer, 2026-08-28) : ils vivent dans le README.
	visee = -1
	_recentrer()


## La simulation a changé de grille (descente) : la vue statique et les nœuds repartent de zéro.
## L'écran de chargement (Grille continue) : ouvert quand la fenêtre se recentre au camp, jamais en donjon.
func _ouvrir_chargement() -> void:
	if sim == null or sim.lieu != "camp" or sim.monde == null or profil_sans_ui:
		return
	var j := joueur()
	if j.is_empty():
		return
	chargement_restant = float(GameData.config("planete").get("monde", {}).get("chargement_s", 0.6))
	chargement_cellule = sim.monde.cellule_de(j.pos)
	var biome: Dictionary = GameData.catalogues.biomes.get(str(sim.monde.surface.biome_a(j.pos.x, j.pos.y)), {})
	chargement_texte.text = tr("ui.chargement").format({"x": chargement_cellule.x, "y": chargement_cellule.y, "biome": tr(str(biome.get("name_key", "")))})
	chargement.visible = true
	sim.horloge_monde.active = false   # le monde n'avance pas pendant le chargement (c'est un temps mort, pas une ellipse)
	chemin_en_cours.clear()


func _fermer_chargement() -> void:
	chargement_restant = 0.0
	chargement.visible = false
	if sim != null and sim.horloge_monde != null:
		sim.horloge_monde.active = true


func _apres_changement_de_grille() -> void:
	origine_grille = sim.grille.origine if sim != null and sim.grille != null else Vector2i(-99999, -99999)
	origine_dessin = sim.grille.origine if sim != null and sim.grille != null else Vector2i.ZERO
	_lumiere_sale = true
	_lumiere_img = null
	terrain.queue_redraw()
	for v in noeuds_vegetaux.values():
		v.queue_free()
	noeuds_vegetaux.clear()
	vue_version = -1
	centre_brouillard = Vector2i(-99, -99)
	brouillard.queue_redraw()
	toits.queue_redraw()
	for n in noeuds.values():
		n.queue_free()
	noeuds.clear()
	chemin_en_cours.clear()
	telegraphes.clear()
	gros_flottants.clear()          # ils portaient des positions de l'ancienne grille (Grille.h hors bornes au retour au camp)
	survol = Vector2i(-1, -1)       # idem pour la tuile survolée, tant que la souris n'a pas bougé


## La fenêtre a glissé d'une cellule (2026-09-06, l'à-coup au passage d'une cellule) : le monde est le même, seules
## l'origine et les clés changent. Les morceaux de terrain, les végétaux et les paperdolls sont dessinés en coordonnées
## MONDE : on les garde et on les re-clé au lieu de tout refaire (36 morceaux, des centaines de végétaux et deux cents
## paperdolls à réinstancier, c'était le gel et le voile noir à chaque cellule franchie). Un saut qui n'est pas un
## glissement de cellules entières (un chargement) repasse par le chemin complet.
var origine_grille := Vector2i(-99999, -99999)   # l'origine de la grille telle que le client l'a vue
var origine_dessin := Vector2i.ZERO                # l'origine que _ecran soustrait : celle du dernier vrai changement de grille
const RECENTRAGE_MAX_CELLULES := 16                # au-delà, on rebase (les pixels ne doivent jamais approcher 1e6)
var recentrage_leger := true                       # false (capture --recentrage-complet) : l'ancien chemin, pour comparer
func _apres_recentrage(nouvelle_origine: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	var delta := nouvelle_origine - origine_grille
	var g := sim.grille if sim != null else null
	var trop_loin := g != null and (absi(nouvelle_origine.x - origine_dessin.x) > RECENTRAGE_MAX_CELLULES * g.largeur / 3 or absi(nouvelle_origine.y - origine_dessin.y) > RECENTRAGE_MAX_CELLULES * g.hauteur_grille / 3)
	if not recentrage_leger or g == null or origine_grille == Vector2i(-99999, -99999) or delta == Vector2i.ZERO or delta.x % MORCEAU != 0 or delta.y % MORCEAU != 0 or absi(delta.x) > g.largeur or absi(delta.y) > g.hauteur_grille or trop_loin:
		_apres_changement_de_grille()
		_ouvrir_chargement()
		return
	var dk := delta / MORCEAU
	var ancienne := origine_grille
	origine_grille = nouvelle_origine
	var nouveaux := {}
	for k in morceaux.keys():
		var nk: Vector2i = k - dk
		var n: TerrainMorceau = morceaux[k]
		if nk.x < 0 or nk.y < 0 or nk.x * MORCEAU >= g.largeur or nk.y * MORCEAU >= g.hauteur_grille:
			n.queue_free()
		else:
			n.coin = nk
			n.z_index = nk.x + nk.y
			nouveaux[nk] = n
	morceaux = nouveaux
	var nv := {}
	for idx in noeuds_vegetaux.keys():   # les végétaux : re-clés par leur position monde, leur profondeur refaite (elle est relative à l'origine)
		var p: Vector2i = ancienne + Vector2i(int(idx) % g.largeur, int(idx) / g.largeur)
		if g.dans(p):
			nv[g.idx(p)] = noeuds_vegetaux[idx]
			noeuds_vegetaux[idx].z_index = _profondeur(p)
		else:
			noeuds_vegetaux[idx].queue_free()
	noeuds_vegetaux = nv
	centre_terrain = Vector2i(-99, -99)   # _maj_morceaux crée ceux qui manquent au bord et libère les trop lointains
	vue_version = -1
	centre_brouillard = Vector2i(-99, -99)
	brouillard.queue_redraw()
	toits.queue_redraw()
	_lumiere_sale = true   # la grille a changé d'origine : la texture de lumière se refait sur la nouvelle
	_top_client("recentrage", t0)
	chrono["n.recentrage"] = float(chrono.get("n.recentrage", 0.0)) + 1.0


func _recentrer() -> void:
	scale = Vector2.ONE * zoom
	var j := joueur()
	if j.is_empty():
		return
	var taille := get_viewport_rect().size
	# Le joueur est centré à l'écran, la vue le suit (Écrans d'interface, décision du 2026-08-27) ;
	# elle suit le paperdoll qui glisse, pas la tuile, pour ne pas sauter.
	var p: Vector2 = noeuds[joueur_id].position if noeuds.has(joueur_id) else _ecran(j.pos, sim.grille.h(j.pos))
	position = taille * 0.5 - p * zoom
	if volet != null and volet.visible:   # le volet couvre le bord droit : le joueur reste au centre de ce qui se voit
		position.x -= volet.largeur * 0.5


func joueur() -> Dictionary:
	return sim.entites.get(joueur_id, {})


func _sur_journal(cle: String, params: Dictionary) -> void:
	if cle == "journal.attendre":   # les attentes des êtres hors de vue n'encombrent pas le journal (parcours du 2026-08-30)
		var j := joueur()
		var vu := false
		for e in sim.vivants():
			if str(e.name_key) == str(params.get("nom", "")) and (e.id == joueur_id or (not j.is_empty() and sim.voit(j, e.pos))):
				vu = true
				break
		if not vu:
			return
	var p := {}
	if params.has("x") and params.has("y") and (params.x is int) and (params.y is int):   # le journal parle en tuiles locales à la cellule
		var cl := _coord_locale(Vector2i(int(params.x), int(params.y)))
		p["x"] = cl.x
		p["y"] = cl.y
	for k in params.keys():
		if p.has(k):
			continue
		var v: Variant = params[k]
		if v is Dictionary and v.has("base"):
			p[k] = nom_objet(v)
		else:
			p[k] = tr(v) if (v is String and v.contains(".")) else v
	# Les lignes qui reviennent tique apres tique se cumulent dans la precedente (styles.journal) :
	# un seul poison ecrivait sept lignes d'affilee et noyait tout le reste du combat.
	var champ := str(GameData.config("styles").get("journal", {}).get("cumulables", {}).get(cle, ""))
	if not champ.is_empty() and p.has(champ):
		var identite := {}
		for k in p.keys():
			if k != champ:
				identite[k] = p[k]
		if cle == _cumul_cle and identite == _cumul_identite and not journal.is_empty():
			_cumul_total += float(p[champ])
			_cumul_fois += 1
			p[champ] = int(round(_cumul_total)) if _cumul_total == round(_cumul_total) else _cumul_total
			journal[-1] = tr(cle).format(p) + tr("journal.cumul").format({"n": _cumul_fois})
			return
		_cumul_cle = cle
		_cumul_identite = identite
		_cumul_total = float(p[champ])
		_cumul_fois = 1
	else:
		_cumul_cle = ""
	_log(tr(cle).format(p))


var _cumul_cle := ""              # la derniere ligne de journal cumulable, et de quoi savoir si la suivante la continue
var _cumul_identite: Dictionary = {}
var _cumul_total := 0.0
var _cumul_fois := 0


func _log(t: String) -> void:
	# ET ON LE MONTRE (ordre de travail 39, 2026-09-09). Le journal du bas est recouvert par le moindre panneau : un
	# refus s'y écrivait pour personne. Le bandeau passe par-dessus tout, y compris un écran ouvert — et c'est
	# précisément le cas où le joueur ne voyait rien. *Un message qu'on ne peut pas voir n'a pas été dit.*
	if bandeau != null:
		bandeau.montrer(t)
	journal.append(t)
	if journal.size() > 9:
		journal.pop_front()


# ---------------------------------------------------------------- rythme (client)

## La lumière ambiante du cycle (interpolée entre les phases) ; en donjon et en arène, il fait jour.
func _maj_ambiance() -> void:
	if sim == null or sim.lieu != "camp" or sim.monde == null:
		_ciel = Color.WHITE
		ambiance.color = Color.WHITE
		_maj_soleil(12.0, false)   # sous terre ou en arène : pas de soleil
		_maj_lumiere_si_besoin()
		lumieres.queue_redraw()
		return
	var c: Dictionary = GameData.config("planete").cycle
	var h := sim.heure()
	_maj_soleil(h, true)
	var l: Dictionary = c.lumiere
	var jour := Color(l.jour[0], l.jour[1], l.jour[2])
	var nuit := Color(l.nuit[0], l.nuit[1], l.nuit[2])
	var aube := Color(l.aube[0], l.aube[1], l.aube[2])
	var crep := Color(l.crepuscule[0], l.crepuscule[1], l.crepuscule[2])
	var col := nuit
	if h >= float(c.aube[0]) and h < float(c.aube[1]):
		col = nuit.lerp(aube, (h - float(c.aube[0])) / (float(c.aube[1]) - float(c.aube[0]))).lerp(jour, maxf(0.0, (h - float(c.aube[0])) / (float(c.aube[1]) - float(c.aube[0])) - 0.5) * 2.0)
	elif h >= float(c.jour[0]) and h < float(c.jour[1]):
		col = jour
	elif h >= float(c.crepuscule[0]) and h < float(c.crepuscule[1]):
		col = jour.lerp(crep, (h - float(c.crepuscule[0])) / (float(c.crepuscule[1]) - float(c.crepuscule[0])) * 0.5).lerp(nuit, maxf(0.0, (h - float(c.crepuscule[0])) / (float(c.crepuscule[1]) - float(c.crepuscule[0])) - 0.5) * 2.0)
	_ciel = col   # le ciel n'est plus un modulate global (designer 2026-09-06) : il entre dans la lumière de chaque tuile
	ambiance.color = Color.WHITE
	_maj_lumiere_si_besoin()
	lumieres.queue_redraw()


## Refait la lumière des tuiles quand quelque chose a changé : le ciel (l'heure), le soleil (son azimut), les sources
## locales (la carte de la simulation), la grille, ou le joueur qui s'est éloigné de la zone où l'ombre est calculée.
func _maj_lumiere_si_besoin() -> void:
	if sim == null or sim.grille == null:
		return
	var j := joueur()
	var besoin := _lumiere_sale or _lumiere_img == null
	if not besoin and (absf(_ciel.r - _ciel_derniere.r) > 0.01 or absf(_ciel.g - _ciel_derniere.g) > 0.01 or absf(_ciel.b - _ciel_derniere.b) > 0.01):
		besoin = true
	if not besoin and not j.is_empty() and (sim.lieu == "camp" or sim.lieu == "donjon"):
		var maintenant := Time.get_ticks_msec()
		if maintenant - _lumiere_dernier_ms >= LUMIERE_PERIODE_MS:   # les sources locales bougent lentement : on relit la carte deux fois par seconde
			_lumiere_dernier_ms = maintenant
			var t_s := Time.get_ticks_usec()
			sim.niveau_lumiere(j.pos)   # rafraîchit la carte locale si elle est sale
			_top_client("lumiere.sim", t_s)
			if sim.carte_lumiere != _locale_derniere:
				besoin = true
		if not besoin and Grille.distance_plate(j.pos, _lumiere_centre) > rayon_vue / 3:
			besoin = true
	if besoin:
		var t0 := Time.get_ticks_usec()
		_maj_lumiere()
		_top_client("lumiere", t0)


func _maj_lumiere() -> void:
	_lumiere_sale = false
	_ciel_derniere = _ciel
	var g := sim.grille
	var j := joueur()
	var n := g.largeur * g.hauteur_grille
	var actif := sim.lieu == "camp" or sim.lieu == "donjon"
	var data := PackedByteArray()
	if actif:
		var cy: Dictionary = GameData.config("planete").cycle
		var l: Dictionary = cy.lumiere
		var sol: Dictionary = cy.get("soleil", {})
		var ciel := _ciel if sim.lieu == "camp" else Color.BLACK   # sous terre, seule la lueur de l'étage et les torches
		var tt: Array = l.get("torche_teinte", [1.0, 0.85, 0.6]) if sim.lieu == "camp" else l.get("donjon_teinte", [0.85, 0.85, 0.95])
		var teinte := Color(float(tt[0]), float(tt[1]), float(tt[2]))
		var force := float(l.get("torche_force", 1.0))
		if not j.is_empty():
			sim.niveau_lumiere(j.pos)
		var locale: PackedByteArray = sim.carte_lumiere
		var dir := Vector2.ZERO
		var pente := 0.0
		var coin := Vector2i.ZERO
		var taille := Vector2i.ZERO
		var ombre_portee := 0.0
		if sim.lieu == "camp" and _soleil_force > 0.0 and not j.is_empty():
			var sx := _soleil_dir.x
			var sy := _soleil_dir.y
			var lh := sqrt(sx * sx + sy * sy)
			if lh > 0.001:
				sx /= lh
				sy /= lh
				dir = Vector2((sx + sy) / sqrt(2.0), (sy - sx) / sqrt(2.0))   # l'est de l'écran est (1, -1)/√2 dans la grille, le sud (1, 1)/√2
				pente = float(sol.get("tuile_en_unites", 3.5)) * _soleil_dir.z / lh
				var jp := Grille.plat(j.pos)
				var x0 := maxi(g.origine.x, jp.x - rayon_vue - 4)
				var y0 := maxi(g.origine.y, jp.y - rayon_vue - 4)
				var x1 := mini(g.origine.x + g.largeur - 1, jp.x + rayon_vue + 4)
				var y1 := mini(g.origine.y + g.hauteur_grille - 1, jp.y + rayon_vue + 4)
				coin = Vector2i(x0, y0)
				taille = Vector2i(x1 - x0 + 1, y1 - y0 + 1)
				ombre_portee = float(sol.get("ombre_portee", 0.28)) * _soleil_force
		var t_k := Time.get_ticks_usec()
		data = g.carte_lumiere(ciel, locale, teinte, force, dir, pente, int(sol.get("ombre_portee_max_tuiles", 8)), NIVEAU_BLOCS * BLOC_UNITES, ombre_portee, coin, taille)
		_top_client("lumiere.carte", t_k)
		chrono["n.lumiere"] = float(chrono.get("n.lumiere", 0.0)) + 1.0
		var t_dup := Time.get_ticks_usec()
		_locale_derniere = locale.duplicate()
		_top_client("lumiere.copie", t_dup)
		_lumiere_centre = j.pos if not j.is_empty() else Vector2i(-9999, -9999)
	if data.size() != n * 3:   # une arène, ou rien à éclairer : tout à 1
		_lumiere_img = null
		for m in _materiaux_grain:
			m.set_shader_parameter("lumiere_active", 0.0)
		for v in noeuds_vegetaux.values():
			v.modulate = v.get_meta("voile", Color.WHITE)
		return
	var t_im := Time.get_ticks_usec()
	var img := Image.create_from_data(g.largeur, g.hauteur_grille, false, Image.FORMAT_RGB8, data)
	t_im = _top_client("lumiere.image", t_im)
	if _lumiere_tex == null or _lumiere_img == null or _lumiere_img.get_size() != img.get_size():
		_lumiere_tex = ImageTexture.create_from_image(img)
	else:
		_lumiere_tex.update(img)
	_lumiere_img = img
	t_im = _top_client("lumiere.texture", t_im)
	var dec := Vector2(g.origine - origine_dessin)
	for m in _materiaux_grain:
		m.set_shader_parameter("lumiere_tex", _lumiere_tex)
		m.set_shader_parameter("lumiere_taille", Vector2(g.largeur, g.hauteur_grille))
		m.set_shader_parameter("lumiere_decalage", dec)
		m.set_shader_parameter("lumiere_active", 1.0)
	t_im = _top_client("lumiere.shader", t_im)
	for idx in noeuds_vegetaux.keys():
		var v: Node2D = noeuds_vegetaux[idx]
		v.modulate = _lumiere_tuile(g.pos_de(int(idx))) * v.get_meta("voile", Color.WHITE)
	chrono["n.vegetaux"] = float(noeuds_vegetaux.size())
	_top_client("lumiere.vegetaux", t_im)


## La lumière d'une tuile telle que la texture la porte (blanc sans texture ou hors de la grille).
func _lumiere_tuile(t: Vector2i) -> Color:
	if _lumiere_img == null or sim == null or not sim.grille.dans(t):
		return Color.WHITE
	var l: Vector2i = Grille.plat(t) - sim.grille.origine   # un étage prend la lumière de sa tuile au sol
	return _lumiere_img.get_pixel(l.x, l.y)


## Les flammes des feux (Météo). Plus de halo rond (designer 2026-09-06, 16 h 40 : « la lumière qui émane ne doit pas être
## un halo rond sur le personnage mais une luminosité qui se propage sur les cellules voisines ») : la lumière d'une torche
## ou d'un meuble est la propagation par tuile de la simulation (Éclairage), que le shader applique à chaque tuile.
func _dessiner_lumieres() -> void:
	if sim == null:
		return
	var g := sim.grille
	var j := joueur()
	if j.is_empty():
		return
	for fi in sim.feux.keys():   # Météo : les flammes (couche additive, visibles de jour comme de nuit)
		var ft := g.pos_de(int(fi))
		if Grille.distance(ft, j.pos) > rayon_vue or not g.decouvert.has(int(fi)):
			continue
		var fc := _ecran(ft, g.h(ft))
		var ph := float((Time.get_ticks_msec() / 90 + int(fi)) % 6) / 6.0
		lumieres.draw_colored_polygon(PackedVector2Array([fc + Vector2(-9, 2), fc + Vector2(0, -22 - 8.0 * ph), fc + Vector2(9, 2)]), Color(1.0, 0.45, 0.1, 0.85))
		lumieres.draw_colored_polygon(PackedVector2Array([fc + Vector2(-5, 2), fc + Vector2(0, -12 - 6.0 * ph), fc + Vector2(5, 2)]), Color(1.0, 0.85, 0.3, 0.9))


## À la fermeture : attendre la pré-génération en thread (elle lit GameData, qui va disparaître).
func _exit_tree() -> void:
	if sim != null and sim.monde != null:
		sim.monde.fermer()


func _process(delta: float) -> void:
	var t_proc := Time.get_ticks_usec()
	_top_client("image.process", t_proc)   # marque l'entrée : le total du process se lit à la sortie
	chrono["n.process"] = float(chrono.get("n.process", 0.0)) + 1.0
	_process_corps(delta)
	_top_client("image.process_total", t_proc)


func _process_corps(delta: float) -> void:
	if not creation.is_empty():   # l'écran de création : rien derrière
		ui.text = ""
		ui_bas.text = ""
		ui_droite.text = ""
		return
	var j := joueur()
	if j.is_empty():
		return
	if titre_ouvert:   # écran principal : rien n'avance derrière
		return
	if chargement_restant > 0.0:   # écran de chargement : le monde est en pause, le temps sert à pré-générer
		chargement_restant -= delta
		if sim.monde != null:
			sim.monde.pregenerer_voisins()
		if chargement_restant <= 0.0:
			_fermer_chargement()
		return
	# LA PAUSE (Ordre de travail, palier 3 — 2026-09-08). Un écran ouvert arrête le monde, et il faut les DEUX gestes,
	# parce que le monde avance par deux chemins différents :
	#   · au camp, l'horloge est en TEMPS_REEL et tourne d'elle-même — `active = false` l'arrête ;
	#   · en donjon, elle est en mode ACTION et le monde n'avance QUE par la boucle `while sim.pas("monde")` quarante
	#     lignes plus bas, que `active` n'arrête pas du tout. D'où le retour anticipé, exactement comme pour l'écran de
	#     chargement juste au-dessus.
	# Et c'est le même retour qui corrige ZQSD : les touches de marche sont SONDÉES ici (`Input.is_key_pressed`), pas
	# reçues en événement — aucune garde posée dans les écrans ne pouvait les arrêter, et comme le designer a décidé
	# « une option = une lettre », les quatre touches de marche SONT quatre lettres d'option. Taper « D » pour choisir
	# une option faisait marcher le personnage sous le panneau.
	if ecrans.est_ouvert() or (menu_contexte != null and menu_contexte.visible):
		sim.horloge_monde.active = false
		_maj_noeuds(delta)   # les nœuds finissent de se poser : on fige un monde au repos, pas un monde en plein pas
		return
	sim.horloge_monde.active = true
	_recentrer()
	# La marche (8 directions d'écran), par l'InputMap et par POSITION PHYSIQUE (palier 3, 2026-09-08). Avant, les
	# quatre touches étaient sondées en dur (`Input.is_key_pressed(KEY_Z)`) et le jeu n'était jouable qu'en AZERTY.
	# Déclarées par leur position, elles donnent ZQSD sur un clavier français et WASD sur un anglais, sans réglage.
	minuterie_clavier -= delta
	if sim.attente.has(joueur_id) and visee < 0 and minuterie_clavier <= 0.0:
		var dir := Vector2i.ZERO
		if Input.is_action_pressed(&"marcher_haut"):
			dir += Vector2i(-1, -1)
		if Input.is_action_pressed(&"marcher_bas"):
			dir += Vector2i(1, 1)
		if Input.is_action_pressed(&"marcher_droite"):
			dir += Vector2i(1, -1)
		if Input.is_action_pressed(&"marcher_gauche"):
			dir += Vector2i(-1, 1)
		dir = Vector2i(signi(dir.x), signi(dir.y))
		if dir != Vector2i.ZERO:
			chemin_en_cours.clear()
			minuterie_clavier = 0.05
			var vise: Vector2i = j.pos + dir
			var occ_v := sim.grille.occupant(vise)   # se diriger vers un ennemi adjacent l'attaque (designer, point 46)
			if not occ_v.is_empty() and occ_v != joueur_id and sim.ennemis(j, sim.entites[occ_v]):
				if not sim.intention(joueur_id, {"type": "attaquer", "cible": occ_v}):
					_log(tr("journal.inaccessible"))
			elif not sim.intention(joueur_id, {"type": "deplacer", "vers": vise}):
				_log(tr("journal.inaccessible"))
	# En attente d'intention : on consomme la file d'ordres du joueur (un pas par décision).
	if sim.attente.has(joueur_id) and not chemin_en_cours.is_empty():
		var cible: Vector2i = chemin_en_cours[0]
		if not sim.intention(joueur_id, {"type": "deplacer", "vers": cible}):
			chemin_en_cours.clear()
			_log(tr("journal.inaccessible"))
		else:
			chemin_en_cours.pop_front()
	# Les horloges de combat n'avancent qu'à l'action : le client les fait avancer pas à pas.
	var t0_c := Time.get_ticks_usec()
	minuterie_pas -= delta
	if minuterie_pas <= 0.0:
		minuterie_pas = DELAI_PAS
		for nom in sim.combats.keys():
			sim.pas(nom)
	if sim.horloge_monde.mode == Horloge.Mode.ACTION and j.get("horloge", "monde") == "monde":
		# En donjon, le monde n'avance qu'à l'action — mais SANS la cadence de lisibilité des combats : un pas
		# toutes les 0,12 s faisait payer au joueur 0,12 s réelle par « attend » de chaque PNJ de l'étage
		# (30 PNJ ≈ 4 s de gel après chaque action — le « lag » constaté le 2026-08-31). L'horloge du monde
		# se vide donc chaque image, jusqu'au joueur ou au garde-fou. QUAND LE JOUEUR EST EN COMBAT (sur une
		# horloge de combat), le monde ne se vide pas : sans lui pour la bloquer, l'horloge tournait sans fin
		# (128 pas × 60 images/s = le « dès qu'on rentre en combat ça lag énormément », 2026-08-31) —
		# temporalités parallèles : pendant un combat, le reste de l'étage attend.
		var tempo: Dictionary = sim.regles.r.get("tempo", {})
		var garde_pas := int(tempo.get("actions_max_par_image", 5))   # au plus 5 ACTIONS par image (designer, point 46) — des êtres qui agissent, pas des ticks
		var t_debut := Time.get_ticks_msec()
		var budget_ms := int(tempo.get("ms_max_par_image", 12))     # et jamais plus de 12 ms : plus de gel
		while garde_pas > 0 and sim.pas("monde"):
			garde_pas -= 1
			if Time.get_ticks_msec() - t_debut >= budget_ms:
				break
	t0_c = _top_client("pas", t0_c)
	if ecran_fin_reste > 0.0:   # l'écran de fin s'efface seul (point 13) : plus de surimpression jusqu'au clic
		ecran_fin_reste -= delta
		if ecran_fin_reste <= 0.0:
			ecran_fin.clear()
	_maj_rayon_vue()
	_maj_noeuds(delta)
	t0_c = _top_client("noeuds", t0_c)
	_maj_morceaux(j)   # les morceaux de terrain naissent et meurent avec la distance ; une découverte salit ceux du champ de vue
	if int(j.get("vue_version", 0)) != vue_version or Grille.distance_plate(j.pos, centre_brouillard) > rayon_vue / 3:
		brouillard.queue_redraw()   # son champ de vue a changé : seul le brouillard se redessine
		toits.queue_redraw()        # et les toits avec lui (ceux qu'il voit, celui qu'il a sur la tête)
	tour_hud += 1
	if tour_hud % 2 == 0:   # le HUD (bulle, états, télégraphes, gardes) se redessine une image sur deux : deux cents habitants en ville
		hud.queue_redraw()
	_maj_atteignables()
	minuterie_ui -= delta
	if minuterie_ui <= 0.0 and not profil_sans_ui:
		minuterie_ui = 0.15   # le texte, la minimap et l'ambiance : sept fois par seconde suffisent (le lag en ville, 2026-09-05)
		_maj_ui()
		t0_c = _top_client("ui.texte", t0_c)
		minimap.rafraichir()
		t0_c = _top_client("ui.minimap", t0_c)
		_maj_ambiance()
	t0_c = _top_client("ui.ambiance", t0_c)
	if xp_fenetre > 0.0:   # l'XP de l'action : cumulée, puis affichée d'un bloc
		xp_fenetre -= delta
		if xp_fenetre <= 0.0 and not xp_cumul.is_empty():
			var lignes: Array[String] = []
			var resume: Array[String] = []
			for cle in xp_cumul.keys():
				lignes.append("+%d %s" % [int(xp_cumul[cle]), _nom_xp(str(cle))])
				resume.append("%s +%d" % [_nom_xp(str(cle)), int(xp_cumul[cle])])
			xp_flottants.append({"lignes": lignes, "t": 0.0, "dec": 14.0 * xp_flottants.size()})   # les suivants montent au-dessus des précédents
			_log(tr("journal.xp").format({"liste": " · ".join(resume)}))
			xp_cumul = {}
	for f in xp_flottants:
		f.t += delta
	xp_flottants = xp_flottants.filter(func(f: Dictionary) -> bool: return f.t < 1.6)
	for f in gros_flottants:
		f.t += delta
	gros_flottants = gros_flottants.filter(func(f: Dictionary) -> bool: return f.t < 1.2)
	if not gros_flottants.is_empty():
		hud.queue_redraw()
	minuterie_autosave -= delta
	if minuterie_autosave <= 0.0:
		minuterie_autosave = 300.0
		sim.sauvegarder()
	queue_redraw()


## Un nœud creature.tscn par être vivant, configuré depuis sa fiche : position, profondeur, rig.
## Ce que le client montre de chaque être, calculé une fois par image pour tous (file 114, 2026-09-06) : `_vivants_image` et
## `_visibles_image` (bit 1 : à portée et en vue ; bit 2 : et pas sous un toit) — par le noyau C++, sinon PassesGD. Les
## trois passes par être (nœuds, HUD, états) les lisent au lieu de refaire distance, vue et toit chacune.
var _vivants_image: Array[Dictionary] = []
var _visibles_image := PackedByteArray()


func _calculer_visibles(j: Dictionary) -> void:
	# LES CADAVRES SE VOIENT (ordre de travail 28 ter, 2026-09-09). Un mort n'était NI DESSINÉ ni visé : il existait
	# dans la mémoire de la partie et nulle part ailleurs. Or il est déjà sauvegardé (l'écriture ne filtre pas les
	# morts) et le pantin connaît déjà la pose « mort » — il ne manquait que de le mettre dans la liste que le client
	# dessine. **Seule cette liste-là les prend** : `sim.vivants()` garde son sens partout ailleurs, et c'est ce qui
	# évite qu'un cadavre se mette à compter comme un assaillant ou à parler au journal.
	_vivants_image = sim.vivants()
	for m in sim.entites.values():
		if not m.get("vivant", true) and sim.grille.dans(m.get("pos", Vector2i(-9999, -9999))):
			_vivants_image.append(m)
	var positions := PackedVector2Array()
	positions.resize(_vivants_image.size())
	for k in _vivants_image.size():
		var p: Vector2i = _vivants_image[k].pos
		positions[k] = Vector2(p.x, p.y)
	if j.is_empty():
		_visibles_image.resize(positions.size())
		_visibles_image.fill(3)
		return
	var g := sim.grille
	var vue: Dictionary = j.get("vue", {})
	var tout_vu := not j.has("vue")
	var vide_ci := g.contenu_ids.find("vide")
	if g.noyau_actif and g._noyau_pret():
		_visibles_image = g._noyau.visibles(g, vue, tout_vu, Grille.z_de(j.pos), vide_ci, j.pos, rayon_vue, _batiment_de(j.pos), positions)
	else:
		_visibles_image = PassesGD.visibles(g, vue, tout_vu, Grille.z_de(j.pos), vide_ci, j.pos, rayon_vue, _batiment_de(j.pos), positions)


## Le rayon dessiné suit la fenêtre et le zoom : assez de tuiles pour couvrir l'écran (une tuile fait TW/2 px de large et TH/2 de
## haut par pas de diagonale) plus une marge pour les blocs hauts, jamais plus que styles.vue.rayon_max. S'il change, les
## morceaux se refont et le brouillard et les toits se redessinent.
func _maj_rayon_vue() -> void:
	var st: Dictionary = GameData.config("styles").get("vue", {})
	var taille := get_viewport_rect().size
	var z := maxf(0.1, zoom)
	var r := ceili((taille.x / (float(TW) * z) + taille.y / (float(TH) * z)) * 0.5) + int(st.get("marge", 4))
	r = clampi(r, 8, int(st.get("rayon_max", 56)))
	if r != rayon_vue:
		rayon_vue = r
		centre_terrain = Vector2i(-99, -99)   # les morceaux à portée se recalculent
		brouillard.queue_redraw()
		toits.queue_redraw()


func _maj_noeuds(delta: float = 0.0) -> void:
	var vivants := {}
	var j := joueur()
	var glissement_s := float(GameData.config("styles").get("tempo", {}).get("glissement_s", 0.22))   # la durée d'un pas quand l'horloge ne coule pas (donjon)
	var pas_px := Vector2(float(TW) * 0.5, float(TH) * 0.5).length()   # ce que fait un pas à l'écran : la phase de la marche s'y mesure
	var seuil_picto := int(sim.regles.r.get("tempo", {}).get("pictogramme_au_dela", 0))   # 0 : jamais de pictogramme
	_pile_hauteur = float(GameData.config("styles").get("sprites", {}).get("pile_hauteur", 22.0))
	_pile_hauteur_meuble = float(GameData.config("styles").get("sprites", {}).get("pile_hauteur_meuble", 10.0))
	_calculer_visibles(j)
	for ke in _vivants_image.size():
		var e: Dictionary = _vivants_image[ke]
		vivants[e.id] = true
		var n: Paperdoll = noeuds.get(e.id)
		# Hors de la fenêtre de vue : le nœud reste, mais n'est ni dessiné ni redessiné.
		if n != null and not j.is_empty() and (_visibles_image[ke] & 2) == 0:
			n.visible = false   # hors fenêtre, hors du champ de vue (brouillard de guerre), ou sous le toit d'un autre bâtiment (Villes, 2026-09-06)
			continue
		if n == null:
			n = SCENE_CREATURE.instantiate()
			var rig: Dictionary = GameData.entree("rigs", str(e.corps.silhouette))
			n.configurer(e, rig, sim.items, sim.fonctionnalites, GameData.config("palette_materiaux"))
			n.dessine_apres = _dessiner_occulteurs
			if _grain_paperdolls == null:
				_grain_paperdolls = _materiau_grain()
			n.material = _grain_paperdolls   # ses occulteurs (les tuiles redessinées par-dessus lui) prennent le grain et le soleil ; lui-même, sans UV, reste plat
			add_child(n)
			noeuds[e.id] = n
		n.e = e
		var loin: bool = seuil_picto > 0 and not j.is_empty() and e.id != j.id and Grille.distance_plate(e.pos, j.pos) > seuil_picto
		if loin != n.lointain:   # il franchit le seuil : silhouette ou paperdoll, une seule fois
			n.lointain = loin
			n.queue_redraw()
		var cible := _ecran(e.pos, sim.grille.h(e.pos))
		# UNE TUILE TIENT UNE PILE (26 ter) : celui qui est monté sur un autre se dessine plus haut, et devant lui.
		var etage_p := sim.grille.etage_pile(e.pos, e.id)
		if etage_p > 0:
			cible.y -= float(etage_p) * _pile_hauteur
			n.z_index = mini(4000, _profondeur(e.pos) + etage_p)
		var d_reste := n.position.distance_to(cible)
		if not n.visible or d_reste > TW * 3.0:
			n.position = cible   # apparition ou saut (changement de grille, respawn) : pas de glissement
			n.marcher(-1.0)
		elif d_reste <= 0.5:
			n.position = cible
			n.marcher(-1.0)   # arrivé : les jambes reviennent au repos
		else:
			# LE PAS NE FLOTTE PLUS (designer 2026-09-08 : « j'aimerais que les déplacements soient plus fluides »).
			# C'était un lerp exponentiel — une décélération asymptotique qui n'arrive JAMAIS tout à fait, et c'est
			# exactement ce qu'on lisait comme du flottement. Un être avance maintenant à VITESSE CONSTANTE et
			# arrive quand son action finit : la distance restante divisée par le temps restant. En temps à
			# l'action (donjon), l'horloge ne coule pas toute seule — on retombe sur une durée fixe, en données.
			var t_reste := glissement_s
			if sim.horloge_monde.mode == Horloge.Mode.TEMPS_REEL and sim.horloge_monde.ticks_par_seconde > 0.0:
				t_reste = maxf(delta, float(int(e.get("compteur", 0)) - sim.horloge_monde.ticks) / sim.horloge_monde.ticks_par_seconde)
			n.position = n.position.move_toward(cible, d_reste * minf(1.0, delta / maxf(0.001, t_reste)))
			n.marcher(clampf(1.0 - d_reste / pas_px, 0.0, 1.0))   # une oscillation complète par tuile franchie
		n.visible = true
		if n.occulteurs != null:
			n.occulteurs.position = cible - n.position   # les tuiles redessinées par-dessus lui restent à leur place pendant qu'il glisse
		n.modulate = _lumiere_tuile(e.pos)   # la lumière de sa tuile (niveau et teinte), comme le décor
		if not e.get("vivant", true):
			# L'ÂGE D'UNE DÉPOUILLE SE VOIT (28 ter) : elle se voile de la couleur de son stade, du teint frais aux
			# ossements blancs. C'est ce qui rend un champ de bataille lisible une heure après — on lit d'un coup
			# d'œil qui est tombé ce matin et qui pourrit là depuis une semaine.
			n.modulate *= SimCadavres.teinte(sim, e)
		n.z_index = _profondeur(e.pos)
		# Le paperdoll ne se redessine que si ce qu'il montre a changé : deux cents habitants redessinés à chaque image,
		# c'était le lag en ville (designer 2026-09-05). Le tremblement et l'animation ont leur propre redraw.
		var tour := int(n.get_meta("tour", 0)) + 1   # la signature se relit une image sur quatre, en quinconce
		n.set_meta("tour", tour)
		# Le JOUEUR est contrôlé à chaque image, les autres une sur quatre. Le décalage en quinconce protège du lag
		# à deux cents habitants, mais sur le joueur il laissait jusqu'à quatre images de bloc fantôme — et c'est
		# lui, justement, dont les occulteurs sont dessinés en transparence (2026-09-08).
		if (tour % 4 == 0 or e.id == joueur_id) and not n.lointain:   # un pictogramme ne dépend ni de l'orientation ni de l'équipement
			# LA POSITION FAIT PARTIE DE LA SIGNATURE (2026-09-08). Elle n'y était pas, et c'était le « bloc fantôme
			# qui reste avec le joueur et disparaît une fois arrivé sur l'autre case » : les OCCULTEURS — les tuiles
			# redessinées par-dessus l'être — sont calculés depuis `e.pos`, mais ils ne se redessinent qu'avec le
			# paperdoll. En marchant droit devant, l'orientation ne change pas, donc la signature non plus, donc les
			# occulteurs gardaient les blocs de l'ANCIENNE tuile — et comme leur nœud est recalé chaque image pour
			# compenser le glissement, ces blocs périmés semblaient VOYAGER avec le personnage. Ils disparaissaient à
			# l'arrivée, quand un autre changement finissait par déclencher le redessin.
			var sig := hash([e.pos, sim.grille.h(e.pos), e.get("orientation", Vector2i.ZERO), e.get("action_en_cours", {}).is_empty(), e.get("equipement", {}).hash(), bool(e.get("garde", false)), e.has("monture"), e.get("apparence", {}).hash(), e.get("blason", ""), e.get("teinte", []).hash(), e.vivant, e.get("forme_bestiale", false)])
			if int(n.get_meta("signature", -1)) != sig:
				n.set_meta("signature", sig)
				n.queue_redraw()
	for id in noeuds.keys().duplicate():
		if not vivants.has(id):
			noeuds[id].queue_free()
			noeuds.erase(id)


## Les tuiles plus hautes devant un être sont redessinées par-dessus lui, à sa profondeur :
## le relief l'occulte comme dans une passe unique (appelé par le paperdoll après son dessin).
func _dessiner_occulteurs(n: Paperdoll) -> void:
	var g := sim.grille
	var e: Dictionary = n.e
	if n.occulteurs == null or not g.dans(e.pos):   # un paperdoll libéré au changement de grille dessine encore une fois, avec une position de l'autre grille (GIF des compagnons, 2026-09-04)
		return
	var t0_o := Time.get_ticks_usec()
	_dessiner_occulteurs_de(n, g, e)
	_top_client("draw.occulteurs", t0_o)
	chrono["n.occulteurs"] = float(chrono.get("n.occulteurs", 0.0)) + 1.0


func _dessiner_occulteurs_de(n: Paperdoll, g: Grille, e: Dictionary) -> void:
	var he := g.h(e.pos)
	var base := _ecran(e.pos, he)
	# Jusqu'où regarder devant : deux tuiles, et plus loin si des façades de bâtiments sont hautes (Villes, 2026-09-06 :
	# un mur de n niveaux cache un être jusqu'à 2n + 1 tuiles derrière lui).
	var portee := 2
	for b in g.batiments_liste:   # un mur de n niveaux (n × NIVEAU_BLOCS × BLOC_UNITES × HSTEP px) cache jusqu'à sa hauteur / (TH/2) tuiles derrière lui
		portee = maxi(portee, ceili(float(int(b.get("niveaux", 1)) * NIVEAU_BLOCS * BLOC_UNITES * HSTEP) / (TH * 0.5)) + 1)
	var translucide := str(e.get("controle", "")) == "joueur"   # derrière un mur, le joueur se voit au travers (designer 2026-09-06, 15 h 30)
	for s in range(1, 2 * portee + 1):   # en ordre de profondeur : le plus proche d'abord, le plus devant par-dessus
		for dx in range(maxi(0, s - portee), mini(s, portee) + 1):
			var dy := s - dx
			# Au-delà de deux pas, seule la bande sous l'être (|dx − dy| ≤ 1 : à vingt pixels près) et seul un mur assez
			# haut pour monter jusqu'à lui (le pied d'un bloc à s tuiles devant est 10 s pixels plus bas) : sinon une
			# cité coûtait soixante tuiles redessinées par paperdoll.
			if s > 2 and absi(dx - dy) > 1:
				continue
			var t: Vector2i = e.pos + Vector2i(dx, dy)
			if not g.dans(t):
				continue
			var mur: bool = g.bloque_passage(t) and not ("vegetation" in g.contenu_de(t).get("tags", []))
			if s <= 2:
				if not (g.h(t) > he or mur):
					continue
			elif _hauteur_bloc(g, t) * HSTEP + maxi(0, g.h(t) - he) * HSTEP < s * TH / 2 - 4:
				continue
			n.occulteurs.draw_set_transform(-base)
			if translucide and mur:
				_dessine_bloc(n.occulteurs, g, t, _ecran(t, g.h(t)), Color(1, 1, 1, MUR_TRANSLUCIDE), 0, MUR_COUPE_UNITES if _mur_coupe(g, t) else 0)   # le mur devant le joueur, en transparence
			else:
				_dessine_tuile(n.occulteurs, t)
			n.occulteurs.draw_set_transform(Vector2.ZERO)




## Le voile jaune des tuiles atteignables est retiré (designer 2026-08-31, point 46) : plus de flood
## par image en combat non plus — le coût d'un pas reste lisible dans l'en-tête au survol.
func _maj_atteignables() -> void:
	atteignables = {}


# ---------------------------------------------------------------- entrées → intentions

## Les classes proposées à la création : sans les cachées (Talents de classe).
func _classes_visibles() -> Array:
	# Plus de limites à la création (designer, 2026-08-31) : toutes les classes, les cachées comprises.
	var res: Array = GameData.catalogues.classes.keys()
	res.sort()
	return res


## Le menu de triche est-il accessible ? En développement toujours ; dans un exécutable publié, seulement si on l'a
## demandé en ligne de commande (`Sensen.exe -- --triche`).
func _triche_permise() -> bool:
	return OS.is_debug_build() or ("--triche" in OS.get_cmdline_user_args())


## « Se relever » : l'intention que n'importe quelle touche déclenchait avant, désormais choisie. C'est ici que les
## pertes du sac et de l'or sont appliquées, par `SimObjets._respawn`.
func _relever_le_joueur() -> void:
	sim.intention(joueur_id, {"type": "respawn"})
	_apres_changement_de_grille()


## L'action que porte cet événement, ou "" (palier 3, 2026-09-08). Une seule boucle sur les actions déclarées :
## `event_is_action` sait comparer la position physique comme la lettre, selon ce que `Reglages` a posé dans l'InputMap.
func _action_de(ev: InputEvent) -> StringName:
	for nom in Reglages.actions().keys():
		if InputMap.has_action(StringName(nom)) and InputMap.event_is_action(ev, StringName(nom)):
			return StringName(nom)
	return &""


func _unhandled_input(ev: InputEvent) -> void:
	if titre_ouvert:   # écran principal : seules les touches du panneau passent
		if ev is InputEventKey and ev.pressed and not ev.echo and ecrans.est_ouvert():
			ecrans.touche(ev)
		return
	var j := joueur()
	if not j.is_empty() and not j.vivant:
		# La mort ouvre un ÉCRAN (palier 3, 2026-09-08). Avant, n'importe quelle touche relevait le joueur sur-le-champ
		# et la défaite n'était qu'une ligne de journal. L'écran étant un écran, il met aussi le monde en pause — c'est
		# la pause codée le même jour qui le permet.
		if not ecrans.est_ouvert():
			ecrans.ouvrir("mort")
		if ev is InputEventKey and ev.pressed and not ev.echo:
			ecrans.touche(ev)
		return
	if not ecran_fin.is_empty() and ((ev is InputEventMouseButton and ev.pressed) or (ev is InputEventKey and ev.pressed)):
		ecran_fin.clear()   # un clic l'efface tout de suite ; sinon il part de lui-même
		ecran_fin_reste = 0.0
		return
	if ev is InputEventMouseMotion:
		var t_survol := _tuile_sous(get_local_mouse_position())
		survol = t_survol if sim.grille.dans(t_survol) else Vector2i(-1, -1)   # hors de la grille : pas de survol (les h(survol) ne débordent jamais)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var haut: bool = ev.button_index == MOUSE_BUTTON_WHEEL_UP
			if ev.ctrl_pressed:   # Ctrl + molette : le zoom (contrôles, décision du 2026-08-30)
				# Les bornes sont en DONNÉES depuis le 2026-09-08 (designer : « pouvoir zoomer beaucoup plus ») :
				# elles étaient écrites ici, 0,5 à 2,0, et rien ne permettait de regarder un sprite de près.
				var zr: Dictionary = GameData.config("styles").get("vue", {}).get("zoom", {})
				var pas := maxf(1.01, float(zr.get("pas", 1.15)))
				zoom = clampf(zoom * (pas if haut else 1.0 / pas), float(zr.get("min", 0.4)), float(zr.get("max", 12.0)))
				scale = Vector2.ONE * zoom
				_maj_rayon_vue()   # moins de tuiles à dessiner en zoomant, plus en reculant : le rayon suit tout de suite
			elif not ecrans.est_ouvert():   # molette seule : la hotbar tourne, en boucle
				var j_m := joueur()
				var n := hotbar_entrees(j_m).size() if not j_m.is_empty() else 0
				if n > 0:
					_hotbar(posmod(hotbar_sel + (-1 if haut else 1), n))
			return
		elif ev.button_index == MOUSE_BUTTON_LEFT and not j.is_empty() and j.vivant:
			if menu_contexte.visible:   # un clic ailleurs ferme le menu, et ne fait que ça
				menu_contexte.fermer()
				return
			_clic(_tuile_sous(get_local_mouse_position()), lourde_armee)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and not j.is_empty() and j.vivant:
			# La fenêtre s'ouvre où pointe la souris, en coordonnées d'écran — pas de monde : elle est sur la couche
			# d'interface, qui ne bouge pas avec la caméra.
			_contexte(_tuile_sous(get_local_mouse_position()), get_viewport().get_mouse_position())
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ecrans.est_ouvert() and ecrans.courant == "composer" and ecrans.composeur.nom.has_focus():
			return   # on tape le nom du sort : les lettres vont au champ, pas au jeu
		if ecrans.est_ouvert() and ecrans.touche(ev):
			return
		if carte.ouverte:
			if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
				if carte.mode == "depart":
					fiche_en_attente = {}
					carte.fermer()
				return
			carte.touche(ev)
			return
		# Les chiffres changent d'arme : ce sont des RANGS de râtelier, pas des actions remappables.
		if ev.keycode >= KEY_0 and ev.keycode <= KEY_9:
			var n_touche: int = 9 if ev.keycode == KEY_0 else int(ev.keycode) - int(KEY_1)
			if ev.ctrl_pressed:   # Ctrl + chiffre : changer de page de hotbar (designer 2026-09-02)
				_changer_page_hotbar(n_touche)
			else:
				_hotbar(n_touche)
			return
		# Les touches globales passent par l'InputMap (palier 3, 2026-09-08) : elles sont donc REMAPPABLES, et le rappel
		# des touches en jeu pourra les LIRE au lieu d'être une troisième liste écrite à la main après le README et les
		# chaînes d'aide mortes. Les lettres d'option, elles, restent des lettres : « une option = une lettre ».
		match _action_de(ev):
			&"menu":
				ecrans.basculer("menu")
			&"triche":
				# Le menu de triche reste sur V — le designer l'a demandé et l'a écrit ([[Écrans d'interface]], 2026-08-29,
				# « la seule touche globale ajoutée depuis les contrôles tranchés — accord explicite »). Mais il n'a rien
				# à faire dans la version qu'on publie : la chaîne de publication exporte en `--export-release`, donc
				# `is_debug_build()` y est faux. Une porte de service reste ouverte pour le designer : lancer le jeu avec
				# `-- --triche`. (Ordre de travail, palier 3 — 2026-09-08.)
				if _triche_permise():
					ecrans.basculer("triche")   # menu de triche : tout obtenir, tout déclencher
			&"volet":
				volet_visible = not volet_visible   # le volet latéral (aussi au menu Tab)
			&"perimetre":
				if sim.lieu == "camp" and sim.monde != null:   # dessiner un périmètre de récolte (Décision — Gestion de base)
					ecrans.basculer("perimetre")
			&"interagir":
				_interagir()
			&"ramasser":
				if sim.attente.has(joueur_id):
					if not sim.intention(joueur_id, {"type": "ramasser"}):
						_log(tr("journal.rien_a_ramasser"))
			&"annuler":
				visee = -1
				hotbar_sel = -1
				mode_perimetre = {}   # un dessin de périmètre en cours s'annule
				lourde_armee = false
				visee_objet = ""


## La hotbar (Écrans d'interface, contrôles) : armes du râtelier, capacités, lourde, garde, attendre — dix cases.
func hotbar_entrees(j: Dictionary) -> Array:
	var res: Array = []
	# Les capacités d'abord (designer 2026-09-02) : elles sont l'identité du personnage et doivent rester
	# sous les mêmes touches. Une arme ramassée entre au râtelier, donc à la SUITE, sans rien déplacer.
	for k in j.get("capacites", []).size():
		res.append({"type": "capacite", "ref": k, "nom": tr(j.capacites[k].get("name_key", j.capacites[k].id))})
	for k in j.ratelier.size():
		res.append({"type": "arme", "ref": j.ratelier[k], "nom": tr(sim.items[j.ratelier[k]].name_key)})
	for uid in j.sac:   # les parchemins du sac (designer 2026-09-02) : un sort prêt, à viser comme une bombe
		var it_p: Dictionary = sim.items.get(uid, {})
		if str(it_p.get("type", "")) == "parchemin" and int(it_p.get("charges", 0)) > 0:
			res.append({"type": "parchemin", "ref": uid, "nom": tr("ui.hotbar.parchemin").format({"nom": nom_objet(sim.nom_objet(uid)), "n": int(it_p.charges)})})
	for uid in j.sac:   # les bombes du sac (Explosions)
		var it: Dictionary = sim.items.get(uid, {})
		if it.has("bombe"):
			res.append({"type": "objet", "ref": uid, "nom": tr("ui.hotbar.objet").format({"nom": tr(it.name_key), "n": int(it.get("quantite", 1))})})
	res.append({"type": "lourde", "ref": "", "nom": tr("ui.hotbar.lourde")})
	res.append({"type": "garde", "ref": "", "nom": tr("ui.hotbar.garde")})
	res.append({"type": "attendre", "ref": "", "nom": tr("ui.hotbar.attendre")})
	res = res.slice(0, 10)
	# Les affectations du joueur (designer 2026-08-31, point 35) recouvrent case par case la hotbar dérivée.
	if j.has("hotbar"):
		while res.size() < 10:
			res.append({"type": "", "ref": "", "nom": ""})
		for k in mini(10, j.hotbar.size()):
			var a: Variant = j.hotbar[k]
			if not (a is Dictionary) or a.is_empty():
				continue
			match str(a.get("type", "")):
				"capacite":
					if int(a.ref) < j.get("capacites", []).size():
						res[k] = {"type": "capacite", "ref": int(a.ref), "nom": tr(j.capacites[int(a.ref)].get("name_key", j.capacites[int(a.ref)].id))}
				"objet":
					if str(a.ref) in j.sac and sim.items.has(str(a.ref)):
						res[k] = {"type": "objet", "ref": str(a.ref), "nom": tr(sim.items[str(a.ref)].get("name_key", "?"))}
				"arme":
					if sim.items.has(str(a.ref)):
						res[k] = {"type": "arme", "ref": str(a.ref), "nom": tr(sim.items[str(a.ref)].name_key)}
				"lourde", "garde", "attendre":
					res[k] = {"type": str(a.type), "ref": "", "nom": tr("ui.hotbar." + str(a.type))}
	return res


## La touche 1 → 0 sélectionne une action : une arme s'équipe et arme le clic, une capacité se vise, la lourde s'arme.
func _hotbar(k: int) -> void:
	var j := joueur()
	if j.is_empty():
		return
	var entrees := hotbar_entrees(j)
	if k >= entrees.size():
		return
	var en: Dictionary = entrees[k]
	chemin_en_cours.clear()
	match str(en.type):
		"arme":
			if j.equipement.get("main_principale", "") != str(en.ref) and j.equipement.get("main_secondaire", "") != str(en.ref):
				sim.intention(joueur_id, {"type": "changer_arme", "item": str(en.ref)})
			hotbar_sel = k
			visee = -1
			lourde_armee = false
		"capacite":
			var plan := sim.plan_capacite(j, int(en.ref))
			if plan.geometrie == "soi":
				sim.intention(joueur_id, {"type": "capacite", "index": int(en.ref), "cible": j.pos})
				visee = -1
			else:
				visee = int(en.ref)
				hotbar_sel = k
			lourde_armee = false
		"parchemin":   # un parchemin visé : le clic lit son sort, gratuitement (2026-09-02)
			visee_parchemin = str(en.ref)
			visee_objet = ""
			visee = -1
			hotbar_sel = k
			lourde_armee = false
		"objet":
			visee_objet = str(en.ref)
			visee_parchemin = ""
			visee = -1
			hotbar_sel = k
			lourde_armee = false
		"lourde":
			lourde_armee = true
			hotbar_sel = k
			visee = -1
			visee_objet = ""
		"garde":
			sim.intention(joueur_id, {"type": "garde"})
		"attendre":
			sim.intention(joueur_id, {"type": "attendre"})


## Le verbe demande son outil en main (designer 2026-09-01, point 52) : creuser une pioche,
## terrasser une pelle, abattre une hache, cueillir une faucille, inonder un seau, brûler une torche.
## La table vit dans combat_rules.outils_verbes — aucun verbe n'est écrit en dur ici.
func _outil_en_main(j: Dictionary, verbe: String) -> bool:
	# UN VERBE PEUT ACCEPTER PLUSIEURS OUTILS (28 ter, 2026-09-09) : on dépèce à la dague comme à la hache. N'en
	# nommer qu'une aurait rendu l'option invisible pour la moitié des joueurs — la donnée est donc une chaîne OU
	# une liste, et les verbes d'avant n'ont pas bougé d'une lettre.
	var attendu: Variant = sim.regles.r.get("outils_verbes", {}).get(verbe, "")
	var liste: Array = (attendu as Array) if attendu is Array else ([str(attendu)] if not str(attendu).is_empty() else [])
	if liste.is_empty():
		return true
	for slot in ["main_principale", "main_secondaire"]:
		var it: Dictionary = sim.items.get(str(j.get("equipement", {}).get(slot, "")), {})
		if str(it.get("functionality", "")) in liste:
			return true
	return false


## Les options possibles sur une tuile (E et clic droit) : dans l'ordre de priorité de E.
func _options_tuile(t: Vector2i) -> Array:
	var res: Array = []
	var j := joueur()
	if j.is_empty() or t.x < 0 or not sim.grille.dans(t):
		return res
	var g := sim.grille
	var d := Grille.distance(j.pos, t)
	var occ := g.occupant(t)
	if not occ.is_empty() and occ != joueur_id:
		var x: Dictionary = sim.entites[occ]
		if ("civil" in x.get("tags", []) or x.has("maitre")) and d <= 2:
			res.append({"id": "parler", "cible": occ})
		if "bete" in x.get("tags", []) and not x.has("maitre") and d <= 1:
			res.append({"id": "apprivoiser", "cible": occ})
		res.append({"id": "attaquer", "cible": occ})
		if sim.ennemis(j, x) and not sim.compagnons_de(j).is_empty():   # Compagnons : cibler en priorité
			res.append({"id": "designer", "cible": occ})
		return res
	if t == j.pos:
		# Le puits se creuse SOUS SES PIEDS : sur sa terre au camp, ou n'importe où dans la mine. C'est
		# la promesse de Dwarf Fortress — on décide où descendre, on ne cherche pas un escalier que le
		# monde aurait posé (Mine sous une cellule).
		if sim.lieu == "camp" and sim.monde != null and sim.monde.claims.has(sim._cell_de(t)):
			res.append({"id": "puits", "vers": t})
		elif bool(sim.donjon.get("mine", false)):
			res.append({"id": "puits", "vers": t})
		if not sim.donjon.is_empty() and sim.donjon.get("escalier") != null and sim.donjon.escalier == t:
			res.append({"id": "descendre", "vers": t})
		if not sim.donjon.is_empty() and sim.donjon.has("entree") and sim.donjon.entree == t:
			res.append({"id": "remonter", "vers": t})
		if sim.lieu == "camp" and sim.monde != null and sim.monde.cellule(sim._cell_de(t)).get("a_donjon", false) and sim.monde.pos_monde(sim._cell_de(t), sim.monde.cellule(sim._cell_de(t)).entree_donjon) == t:
			res.append({"id": "descendre", "vers": t})
		return res
	if not str(j.get("porte", "")).is_empty() and d >= 1 and d <= 3:
		res.append({"id": "lancer_etre", "vers": t})
	if d == 0 and sim.portails.has(t):
		res.append({"id": "traverser"})
	if d == 0:
		for el in sim.segments_possibles(Etres.arme(j, sim.items)):   # l'arme mixte choisit son segment
			if str(el) != str(j.get("segment_prefere", "")):
				res.append({"id": "segment_prefere", "element": str(el), "nom": tr("element." + str(el))})
		if j.has("segment_prefere"):
			res.append({"id": "segment_dominant"})
	if d == 0 and sim.a_talent(j, "lune"):
		res.append({"id": "transformer", "forme_humaine": bool(j.get("forme_bestiale", false))})
	if d == 0 and sim.a_talent(j, "masques"):
		for sid in sim.statuts_defs.keys():
			if "masque" in sim.statuts_defs[sid].get("tags", []):
				res.append({"id": "masque", "masque": str(sid), "nom": tr(sim.statuts_defs[sid].name_key)})
	if sim.a_talent(j, "graveur") and d <= int(sim.regles.r.talents.graveur.portee_declenchement):
		for gl in sim.glyphes:
			if gl.pos == t and str(gl.source) == j.id:
				res.append({"id": "declencher_glyphe", "cible": t})
				break
	# UNE DÉPOUILLE SE FOUILLE (ordre de travail 28 ter) : elle libère sa tuile en mourant, donc on peut se tenir
	# DESSUS — l'option doit exister à zéro comme à une tuile, et c'est pour cela qu'elle est posée avant le retour.
	if d <= 1 and not SimCadavres.cadavre_a(sim, t).is_empty():
		res.append({"id": "depouille", "vers": t})
	if d != 1:
		return res
	var tags: Array = g.contenu_de(t).get("tags", [])
	var idx := g.idx(t)
	if "meuble" in tags and g.meubles.has(idx):
		var m: Dictionary = GameData.entree("meubles", str(g.meubles[idx]))
		if bool(m.dormir):
			res.append({"id": "dormir", "vers": t})
		if str(m.type_meuble) == "etal" and int(sim.territoire.caisse) > 0:
			res.append({"id": "caisse", "vers": t})
		# UN COFFRE VIDE S'OUVRE AUSSI (designer 2026-09-09 : « l'interface de coffres ne s'ouvre même pas »). La
		# condition portait « et il contient quelque chose » : elle venait du temps où « prendre » voulait dire
		# ramasser un butin. L'écran de coffre du 2026-09-08 en a fait « ouvrir le contenant », et la condition est
		# restée — un coffre ne devenait donc utilisable qu'une fois rempli, ce qui était impossible.
		# **On cherche dans la PILE** : depuis que les meubles s'empilent, un coffre peut être sous un autre meuble.
		for mid in g.meubles_de(idx):
			if int((GameData.entree("meubles", str(mid)) as Dictionary).capacite_slots) > 0:
				res.append({"id": "prendre", "vers": t})
				break
	if "contenant" in tags and sim.contenants.get(idx, []).size() > 0:
		res.append({"id": "prendre", "vers": t})
	if "parcelle" in tags:
		res.append({"id": "recolter" if "mure" in tags else "fertiliser", "vers": t})
		if not ("mure" in tags):   # arroser une parcelle qui pousse (Agriculture et élevage, 2026-09-07)
			res.append({"id": "arroser", "vers": t})
	elif sim.lieu == "camp" and g.contenu_de(t).is_empty() and not g.meubles.has(idx) and g.h(t) == g.h(j.pos) \
			and str(g.materiau_sol(t)) in sim.regles.r.royaume.agriculture.get("labour", {}).get("sols", []) \
			and not sim.territoire.get("laboure", {}).has(sim._pm(t)) and not sim.territoire.cultures.has(sim._pm(t)):
		res.append({"id": "labourer", "vers": t})   # préparer la terre : on pourra y semer, où que ce soit
	if sim.lieu == "camp" and sim.monde != null:
		var vil: Dictionary = sim.village_a(t)
		if not vil.is_empty() and sim.monde.pos_monde(sim._cell_de(t), vil.centre) == t and not sim.monde.claims.has(sim._cell_de(t)):
			res.append({"id": "conquerir", "vers": t})
		if "eau" in tags:
			res.append({"id": "capturer", "vers": t})
	var meuble_id := str(g.meubles.get(g.idx(t), ""))   # Talents de race : les deux meubles de donjon
	if d <= 1 and meuble_id == "source_maudite":
		res.append({"id": "boire_source", "vers": t})
	if d <= 1 and meuble_id == "autel_rituel":
		res.append({"id": "rituel", "vers": t})
	if "eau" in tags or "liquide" in tags:   # boire à même l'eau (ordre de travail 31)
		res.append({"id": "boire", "vers": t})
	if "plante_sauvage" in tags and _outil_en_main(j, "cueillir"):
		res.append({"id": "cueillir", "vers": t})
	if ("plante" in tags or "arbre" in tags) and _outil_en_main(j, "abattre"):
		res.append({"id": "creuser", "vers": t})   # abattre : la hache met l'arbre à terre
	if g.bloque_passage(t) and not ("meuble" in tags) and not ("plante" in tags) and not ("arbre" in tags) and not ("eau" in tags) and _outil_en_main(j, "creuser"):
		res.append({"id": "creuser", "vers": t})   # percer la roche : pioche en main (designer, point 52)
	if not g.bloque_passage(t) and g.occupant(t).is_empty() and not g.meubles.has(g.idx(t)) and not g.stations_fixes.has(g.idx(t)) and _outil_en_main(j, "terrasser"):
		res.append({"id": "abaisser", "vers": t})
		res.append({"id": "elever", "vers": t})
	if "construit" in tags:
		res.append({"id": "demonter", "vers": t})
	if "porte" in sim.grille.contenu_de(t).get("tags", []) and Grille.distance(j.pos, t) == 1:   # ouvrir / fermer une porte adjacente
		res.append({"id": "porte", "vers": t})
	return res


## Exécute une option (E, clic droit).
func _executer_option(opt: Dictionary) -> void:
	var j := joueur()
	if j.is_empty():
		return
	chemin_en_cours.clear()
	match str(opt.id):
		"parler":
			ecrans.ouvrir_dialogue(str(opt.cible))
			return
		"deplacer":
			_clic(opt.vers, false)
			return
	if not sim.attente.has(joueur_id):
		return
	match str(opt.id):
		"attaquer", "lourde":
			if not sim.intention(joueur_id, {"type": "attaquer", "cible": str(opt.cible), "lourde": str(opt.id) == "lourde"}):
				_log(tr("journal.inaccessible"))
		"apprivoiser":
			sim.intention(joueur_id, {"type": "apprivoiser", "cible": str(opt.cible)})
		"saisir":
			sim.intention(joueur_id, {"type": "saisir", "cible": str(opt.cible)})
		"tempo":
			sim.intention(joueur_id, {"type": "tempo", "cible": str(opt.cible)})
		"traverser":
			sim.intention(joueur_id, {"type": "traverser"})
		"porte":
			sim.intention(joueur_id, {"type": "porte", "vers": opt.vers})
		"masque":
			sim.intention(joueur_id, {"type": "masque", "masque": str(opt.masque)})
		"relever":
			sim.intention(joueur_id, {"type": "relever", "cible": str(opt.cible)})
		"mordre":
			sim.intention(joueur_id, {"type": "mordre", "cible": str(opt.cible)})
		"traverser_mur":
			sim.intention(joueur_id, {"type": "traverser_mur", "cible": opt.cible})
		"transformer":
			sim.intention(joueur_id, {"type": "transformer"})
		"arme_fantome":
			sim.intention(joueur_id, {"type": "arme_fantome", "element": str(opt.element)})
		"segment_prefere":
			sim.intention(joueur_id, {"type": "segment_prefere", "element": str(opt.element)})
		"segment_dominant":
			sim.intention(joueur_id, {"type": "segment_prefere", "element": ""})
		"affut":
			sim.intention(joueur_id, {"type": "affut", "cible": opt.cible})
		"declencher_glyphe":
			sim.intention(joueur_id, {"type": "declencher_glyphe", "cible": opt.cible})
		"poser_portail":
			sim.intention(joueur_id, {"type": "poser_portail", "cible": opt.cible})
		"lancer_etre":
			sim.intention(joueur_id, {"type": "lancer_etre", "vers": opt.vers})
		"puits":
			if sim.intention(joueur_id, {"type": "puits"}):
				_apres_changement_de_grille()
		"descendre", "remonter":
			if sim.intention(joueur_id, {"type": str(opt.id)}):
				_apres_changement_de_grille()
			else:
				_log(tr("journal.pas_escalier"))
		"dormir":
			sim.intention(joueur_id, {"type": "dormir", "vers": opt.vers})
		"depouille":   # la table de dissection : l'écran d'anatomie, braqué sur le mort (28 ter)
			var mort := SimCadavres.cadavre_a(sim, opt.vers)
			if mort.is_empty():
				return
			ecrans.anatomie_id = str(mort.id)
			ecrans.ouvrir("anatomie")
			return
		"prendre", "caisse", "recolter":
			# UN MEUBLE CONTENANT S'OUVRE (designer 2026-09-08) : deux volets, comme un échange. Un butin au sol,
			# lui, se ramasse toujours d'un seul geste — il n'a ni capacité ni nom, rien à y ranger.
			if str(opt.id) == "prendre" and not SimCamp._coffre_a(sim, opt.vers).is_empty():
				ecrans.contenant_pos = opt.vers
				ecrans.ouvrir("coffre")
				return
			sim.intention(joueur_id, {"type": "prendre", "vers": opt.vers})
		"labourer":
			sim.intention(joueur_id, {"type": "labourer", "vers": opt.vers})
		"arroser":
			sim.intention(joueur_id, {"type": "arroser", "vers": opt.vers})
		"fertiliser":
			if not sim.intention(joueur_id, {"type": "fertiliser", "vers": opt.vers}):
				_log(tr("journal.culture_pas_mure"))
		"conquerir":
			sim.intention(joueur_id, {"type": "conquerir", "vers": opt.vers})
		"capturer":
			sim.intention(joueur_id, {"type": "capturer"})
		"abaisser":
			sim.intention(joueur_id, {"type": "terrasser", "vers": opt.vers, "sens": -1})
		"elever":
			sim.intention(joueur_id, {"type": "terrasser", "vers": opt.vers, "sens": 1})
		"cueillir":
			sim.intention(joueur_id, {"type": "cueillir", "vers": opt.vers})
		"boire_source":
			sim.intention(joueur_id, {"type": "boire_source", "vers": opt.vers})
		"boire":
			if not sim.intention(joueur_id, {"type": "boire", "vers": opt.vers}):
				_log(tr("journal.rien_a_boire"))
		"rituel":
			sim.intention(joueur_id, {"type": "rituel", "vers": opt.vers})
		"designer":
			sim.designer_cible(j, str(opt.cible))
		"creuser":
			if not sim.intention(joueur_id, {"type": "creuser", "vers": opt.vers}):
				_log(tr("journal.increusable"))
		"demonter":
			sim.intention(joueur_id, {"type": "demonter", "vers": opt.vers})


## E : la première option de la tuile sous la souris si elle est adjacente, sinon la première autour du joueur.
func _interagir() -> void:
	var j := joueur()
	if j.is_empty():
		return
	var candidates: Array = []
	if survol.x >= 0 and Grille.distance(j.pos, survol) <= 2:
		candidates = _options_tuile(survol)
	if candidates.is_empty():
		candidates = _options_tuile(j.pos)
	if candidates.is_empty():
		for d in Grille.DIRS:
			candidates = _options_tuile(j.pos + d)
			if not candidates.is_empty():
				break
	if candidates.is_empty():
		_log(tr("journal.rien_a_interagir"))
		return
	_executer_option(candidates[0])


## CLIC DROIT : LES OPTIONS DE LA TUILE, DANS UNE PETITE FENÊTRE POSÉE AU POINT CLIQUÉ (designer 2026-09-09).
## C'était un écran plein cadre — panneau entier, colonne de détail, voile noir — pour trois options qui tiennent
## dans un timbre-poste, et qui couvrait justement la tuile qu'on venait de désigner.
func _contexte(t: Vector2i, ou: Vector2) -> void:
	var j := joueur()
	if j.is_empty() or t.x < 0:
		return
	var options: Array = _options_tuile(t)
	if Grille.distance(j.pos, t) >= 1 and sim.grille.occupant(t).is_empty():
		options.append({"id": "deplacer", "vers": t})
	if options.is_empty():
		menu_contexte.fermer()
		_log(tr("ui.contexte.aucune"))
		return
	menu_contexte.ouvrir(options, ou, tr("ui.ecran.contexte").format({"x": t.x, "y": t.y}))


## Le menu (Tab) : écrans et actions générales.
func _action_menu(id: String) -> void:
	var j := joueur()
	match id:
		"inventaire", "atelier", "feuille", "anatomie", "registre", "capacites":
			ecrans.anatomie_id = ""   # par le menu, c'est TOUJOURS son propre corps qu'on regarde (28 ter)
			ecrans.ouvrir(id)
		"gestion":
			if sim.lieu == "camp":
				ecrans.ouvrir("gestion")
		"aide", "options":
			ecrans.ouvrir(id)
		"quitter":   # quitter proprement : on sauvegarde d'abord, sinon on perd jusqu'à cinq minutes sans un mot
			ecrans.fermer()
			if sim.monde != null and not sim.sauvegarder():
				_log(tr("journal.sauvegarde_impossible"))
			get_tree().quit()
		"volet":
			volet_visible = not volet_visible
		"perimetre":   # la même chose que P — le menu ne cache aucun raccourci global (README, contrôles)
			if sim.lieu == "camp" and sim.monde != null:
				ecrans.ouvrir("perimetre")
		"carte":
			ecrans.fermer()
			if sim.lieu == "camp":
				carte.ouvrir("voyage")
		"sauvegarder":
			ecrans.fermer()
			if not sim.sauvegarder():
				_log(tr("journal.sauvegarde_impossible"))
		"minimap_zoom":
			minimap.cycler_zoom()
			minimap.rafraichir(true)
		"minimap_masquer":
			minimap.visible = not minimap.visible
			minimap.rafraichir(true)
		"arene":
			ecrans.fermer()
			arene_banc = ""
			arene_courante = (arene_courante + 1) % (arenes.size() + 1)
			_charger()
		"banc_objets":   # un coffre par catégorie de matériaux, un par type d'équipement (designer, point 74)
			ecrans.fermer()
			arene_banc = "banc_objets"
			_charger()
		"titre":
			_ouvrir_titre()
		"recharger":
			ecrans.fermer()
			GameData.charger()
			GameData.donnees_rechargees.emit()
			_charger()
		"fermer":
			ecrans.fermer()

func _clic(t: Vector2i, lourde: bool) -> void:
	if t.x < 0:
		return
	var j := joueur()
	if not mode_perimetre.is_empty():   # le dessin d'un périmètre : deux coins, puis le rectangle (Gestion de base, 2026-09-04)
		if not mode_perimetre.has("coin"):
			mode_perimetre["coin"] = t
			return
		var pid: String = sim.dessiner_perimetre(mode_perimetre.coin, t, str(mode_perimetre.type))
		if pid.is_empty():
			_log(tr("journal.perimetre_hors_claim"))
		mode_perimetre = {}
		queue_redraw()
		return
	if not visee_parchemin.is_empty():   # un parchemin visé : le clic lit son sort, gratuitement
		if sim.attente.has(joueur_id):
			if sim.intention(joueur_id, {"type": "parchemin", "objet": visee_parchemin, "cible": t}):
				visee_parchemin = ""
				hotbar_sel = -1
			else:
				_log(tr("journal.inaccessible"))
		return
	if not visee_objet.is_empty():   # une bombe visée : le clic la lance
		if sim.attente.has(joueur_id):
			if sim.intention(joueur_id, {"type": "lancer", "objet": visee_objet, "cible": t}):
				visee_objet = ""
				hotbar_sel = -1
		return
	if visee >= 0:
		if sim.attente.has(joueur_id):
			if not sim.intention(joueur_id, {"type": "capacite", "index": visee, "cible": t}):
				_log(tr("journal.inaccessible"))
			else:
				visee = -1
				hotbar_sel = -1
		return
	var occ := sim.grille.occupant(t)
	if not occ.is_empty() and occ != joueur_id:   # un être : l'attaque avec l'action sélectionnée (les PNJ : clic droit ou E)
		chemin_en_cours.clear()
		if not sim.attente.has(joueur_id):
			return
		var x: Dictionary = sim.entites[occ]
		if not lourde and ("civil" in x.get("tags", []) or x.has("maitre")):
			ecrans.ouvrir_dialogue(occ)
			return
		if not sim.intention(joueur_id, {"type": "attaquer", "cible": occ, "lourde": lourde}):
			var tir := sim.verifier_tir(j, x)
			if not tir.ok:
				_log(tr("journal.tir_refuse").format({"raison": tr("raison." + tir.raison)}))
			else:
				_log(tr("journal.inaccessible"))
		lourde_armee = false
		return
	if Grille.distance(j.pos, t) == 1:
		if sim.grille.bloque_passage(t):
			return
		chemin_en_cours = [t]   # un pas direct : autorise la chute volontaire
		return
	chemin_en_cours = sim.grille.chemin(j.pos, t, Etres.est_volant(j), "", sim.refuse_nage(j), 0, sim.bloque_pour(j))   # un ami ne ferme plus le couloir (26 nonies)
	if chemin_en_cours.is_empty() and t != j.pos:
		_log(tr("journal.inaccessible"))

func _tuile_sous(p: Vector2) -> Vector2i:
	var meilleur := Vector2i(-1, -1)
	var meilleure_d := 1e9
	var g := sim.grille
	var j := joueur()
	var cj: Vector2i = Grille.plat(j.pos) if not j.is_empty() else Vector2i.ZERO
	for y in range(maxi(g.origine.y, cj.y - rayon_vue), mini(g.origine.y + g.hauteur_grille, cj.y + rayon_vue + 1)):
		for x in range(maxi(g.origine.x, cj.x - rayon_vue), mini(g.origine.x + g.largeur, cj.x + rayon_vue + 1)):
			var t := Vector2i(x, y)
			var c := _ecran(t, g.h(t))
			var d := c.distance_squared_to(p)
			if d < meilleure_d and d < float(TW * TW) * 0.3:
				meilleure_d = d
				meilleur = t
	var zj := Grille.z_de(j.pos) if not j.is_empty() else 0
	if zj > 0 and _bat_joueur > 0 and _bat_joueur <= g.batiments_liste.size():   # à l'étage : ses tuiles, soulevées, passent devant la rue
		var r: Rect2i = g.batiments_liste[_bat_joueur - 1].rect
		for y in r.size.y:
			for x in r.size.x:
				var t := Grille.en_couche(r.position + Vector2i(x, y), zj)
				if not g.dans(t):
					continue
				var c := _ecran(t, g.h(t))
				var d := c.distance_squared_to(p)
				if d < float(TW * TW) * 0.3 and d <= meilleure_d + 1.0:
					meilleure_d = d
					meilleur = t
	return meilleur


# ---------------------------------------------------------------- rendu

## Tuile → écran, en coordonnées LOCALES à la fenêtre chargée : la simulation parle en coordonnées monde
## (cellule × 128 + tuile, jusqu'à ~65 000), mais le rendu ne doit jamais manipuler des pixels à 1e6 —
## précision float32, polygones dégénérés, jitter. L'origine de la fenêtre glissante est soustraite ici, une fois.
## Les UV d'une face (grain.gdshader) : la position dans le plan pour le grain, et la TUILE (coordonnées locales à
## l'origine de dessin) pour la lumière — le dessus porte (x, 4096 + y), la face sud-ouest (x, −1000 − (y × 32 + h)),
## la face sud-est (y, −2000 − (x × 32 + h)) ; le style de grain s'ajoute à u par pas de `pas_style`.
func _uv_haut(t: Vector2i, dx: float, dy: float, st: float) -> Vector2:
	var l: Vector2i = Grille.plat(t) - origine_dessin
	return Vector2(st + l.x + dx, UV_HAUT + l.y + dy)


func _uv_so(t: Vector2i, dx: float, hh: float, st: float) -> Vector2:
	var l: Vector2i = Grille.plat(t) - origine_dessin
	return Vector2(st + l.x + dx, UV_SO - (l.y * UV_PAS_FACE + hh))


func _uv_se(t: Vector2i, dy: float, hh: float, st: float) -> Vector2:
	var l: Vector2i = Grille.plat(t) - origine_dessin
	return Vector2(st + l.y + dy, UV_SE - (l.x * UV_PAS_FACE + hh))


## Depuis le 2026-09-06, l'origine soustraite est `origine_dessin`, celle du dernier VRAI changement de grille : un
## glissement de cellule ne la bouge pas, pour que les morceaux, végétaux et paperdolls gardés restent à leur place ;
## elle se rebase (chemin complet) quand la fenêtre s'en est éloignée de plus de RECENTRAGE_MAX_CELLULES.
func _ecran(t: Vector2i, h: int) -> Vector2:
	var z := Grille.z_de(t)   # une tuile d'étage (les couches Z) : à sa place au sol, soulevée d'un niveau de bâtiment par couche
	var l: Vector2i = Grille.plat(t) - origine_dessin
	return Vector2((l.x - l.y) * TW * 0.5, (l.x + l.y) * TH * 0.5 - h * HSTEP - z * NIVEAU_BLOCS * BLOC_UNITES * HSTEP)


## Le nom d'une piste d'XP (XP de combat) : l'élément, la compétence, le module, sinon la clé.
func _nom_xp(cle: String) -> String:
	if cle.begins_with("element_"):
		return tr("element." + cle.substr(8))
	if GameData.catalogues.competences.has(cle):
		return tr(str(GameData.catalogues.competences[cle].get("name_key", cle)))
	if GameData.catalogues.modules.has(cle):
		return tr(str(GameData.catalogues.modules[cle].get("name_key", cle)))
	var cle_tr := "xp." + cle
	var t := tr(cle_tr)
	return t if t != cle_tr else cle


## Une position affichée au joueur : locale à sa cellule (0-127), jamais la coordonnée monde.
func _coord_locale(t: Vector2i) -> Vector2i:
	if sim != null and sim.monde != null and sim.lieu == "camp":
		return t - sim.monde.pos_monde(sim.monde.cellule_de(t), Vector2i.ZERO)
	return t


func _draw() -> void:
	if sim == null:
		return
	var t0_d := Time.get_ticks_usec()
	_dessiner_superpositions()
	_top_client("draw.main", t0_d)


func _dessiner_superpositions() -> void:
	var g := sim.grille
	var j := joueur()
	# Superpositions translucides sur les tuiles (atteignables, télégraphes, survol, forme visée).
	if sim.lieu == "camp" and sim.monde != null:   # les périmètres de récolte, teintés par type (Gestion de base, 2026-09-04)
		var teintes: Dictionary = sim.regles.r.royaume.get("perimetres", {}).get("teintes", {})
		for pid in sim.perimetres().keys():
			var per: Dictionary = sim.perimetres()[pid]
			if not per.has("tuiles"):
				continue   # un périmètre « cellule entière » ne se dessine pas : il couvrirait tout
			var tc: Array = teintes.get(str(per.type), [0.8, 0.8, 0.8])
			for t in sim.tuiles_de_perimetre(str(pid)):
				if g.dans(t):
					_losange(t, Color(float(tc[0]), float(tc[1]), float(tc[2]), 0.28))
		if mode_perimetre.has("coin") and survol.x >= 0:   # le rectangle en cours
			var c0: Vector2i = mode_perimetre.coin
			for y in range(mini(c0.y, survol.y), maxi(c0.y, survol.y) + 1):
				for x in range(mini(c0.x, survol.x), maxi(c0.x, survol.x) + 1):
					_losange(Vector2i(x, y), Color(1, 1, 1, 0.3))
	if survol.x >= 0:
		_losange(survol, Color(1, 1, 1, 0.22))
	for b in sim.bombes:
		_losange(b.pos, Color(1.0, 0.4, 0.1, 0.7))
	if not j.is_empty():
		for t in sim.tresors_detectes(j):   # detection_tresors : les contenants à portée, même hors de vue
			_losange(t, Color(1.0, 0.85, 0.2, 0.55))
	if not j.is_empty() and not sim.territoire.get("raid", {}).is_empty():   # Défense et raids : une flèche vers l'assaillant le plus proche
		var plus_proche := Vector2i(-1, -1)
		var dmin := 9999
		for x in sim.vivants():
			if x.camp == "raid":
				var dd := Grille.distance(j.pos, x.pos)
				if dd < dmin:
					dmin = dd
					plus_proche = x.pos
		if dmin > 6 and plus_proche != Vector2i(-1, -1):
			var c0 := _ecran(j.pos, sim.grille.h(j.pos))
			var dir := (_ecran(plus_proche, sim.grille.h(j.pos)) - c0).normalized()
			var pointe := c0 + dir * 70.0
			var perp := Vector2(-dir.y, dir.x)
			draw_primitive(PackedVector2Array([pointe, pointe - dir * 14.0 + perp * 7.0, pointe - dir * 14.0 - perp * 7.0]), PackedColorArray([Color(0.95, 0.2, 0.2, 0.9), Color(0.95, 0.2, 0.2, 0.9), Color(0.95, 0.2, 0.2, 0.9)]), PackedVector2Array())
	for a in sim.affuts:   # les affûts de L'Engrenage
		_losange(a.pos, Color(0.25, 0.25, 0.3, 0.85))
	for pi in sim.portails.keys():   # les brèches du Passeur (clés en position monde)
		if sim.grille.dans(pi):
			_losange(pi, Color(0.6, 0.3, 0.9, 0.7))
	if not sim.donjon.is_empty() and sim.donjon.escalier != null:
		_dessiner_escalier(sim.donjon.escalier, Color(0.9, 0.7, 0.2, 0.9), true)
	if not sim.donjon.is_empty() and sim.donjon.has("entree"):
		_dessiner_escalier(sim.donjon.entree, Color(0.3, 0.9, 0.5, 0.9), false)   # la sortie / l'escalier montant
	for z in sim.zones:   # les zones au sol (Racine, Sol vif, Nappe, Brume, Balise) : un liseré à leur teinte
		if not g.dans(z.pos):
			continue
		if bool(z.get("cachee", false)):   # un piège : visible de son poseur et de ses alliés seulement
			var src: Dictionary = sim.entites.get(str(z.get("source", "")), {})
			if src.is_empty() or (src.id != joueur_id and sim.ennemis(j, src)):
				continue
		var cz := _ecran(z.pos, g.h(z.pos))
		var cz_col: Color = COULEUR_ZONE.get(str(z.type), Color(0.7, 0.7, 0.7, 0.35))
		if str(z.type) == "gaz":   # un nuage à la teinte de son gaz (Gaz dans le sol)
			cz_col = _couleur_liste(GameData.catalogues.gaz.get(str(z.get("gaz", "")), {}).get("teinte", [0.7, 0.7, 0.7, 0.35]))
		_losange(z.pos, cz_col)
	for gl in sim.glyphes:   # les glyphes : un losange cerclé à la teinte de leur élément
		var cg := _ecran(gl.pos, g.h(gl.pos))
		var teinte := sim.wuxing.teinte(sim.wuxing.dominante(gl.elements)) if not gl.elements.is_empty() else Color(0.8, 0.8, 0.9)
		draw_arc(cg, 7.0, 0.0, TAU, 12, teinte, 2.0)
	if visee < 0 and survol.x >= 0 and not j.is_empty() and not g.occupant(survol).is_empty() and g.occupant(survol) != joueur_id:
		var tir := sim.verifier_tir(j, sim.entites[g.occupant(survol)])
		if tir.has("bloqueur"):
			_losange(tir.bloqueur, Color(1, 0.2, 0.2, 0.45))
	if (hotbar_sel >= 0 or lourde_armee) and survol.x >= 0 and not j.is_empty() and survol != j.pos:   # la ligne de vue (hotbar)
		var vue_ok := g.ligne_de_vue(j.pos, survol)
		draw_line(_ecran(j.pos, g.h(j.pos)), _ecran(survol, g.h(survol)), Color(0.3, 1.0, 0.4, 0.8) if vue_ok else Color(1.0, 0.25, 0.2, 0.8), 2.0)
	if not visee_objet.is_empty() and survol.x >= 0 and not j.is_empty() and sim.items.has(visee_objet):   # le rayon d'une bombe visée
		var rb: int = int(sim.items[visee_objet].bombe.rayon)
		var ok_b: bool = Grille.distance(j.pos, survol) <= int(sim.regles.r.bombes.portee) and g.ligne_de_vue(j.pos, survol)
		for dy in range(-rb, rb + 1):
			for dx in range(-rb, rb + 1):
				var tb := survol + Vector2i(dx, dy)
				if g.dans(tb):
					_losange(tb, Color(1.0, 0.5, 0.1, 0.4) if ok_b else Color(0.5, 0.5, 0.5, 0.3))
	if visee >= 0 and not j.is_empty():
		# La zone de lancer (designer 2026-09-01) : toutes les tuiles où le sort peut être POSÉ, en vert.
		# Sans elle il fallait promener le curseur pour découvrir la portée réelle et la ligne de vue.
		var plan_z := sim.plan_capacite(j, visee)
		var pmax := int(Vector2i(plan_z.get("portee", Vector2i(0, 0))).y)
		for dz in range(-pmax, pmax + 1):
			for dx_z in range(-pmax, pmax + 1):
				var tz: Vector2i = j.pos + Vector2i(dx_z, dz)
				if g.dans(tz) and g.decouvert.has(g.idx(tz)) and sim.capacite_visable(j, plan_z, tz):
					_losange(tz, Color(0.35, 0.95, 0.45, 0.16))
	if visee >= 0 and survol.x >= 0 and not j.is_empty():
		var plan := sim.plan_capacite(j, visee)
		var ok := sim.capacite_visable(j, plan, survol)
		for t in sim.tuiles_du_plan(j, plan, survol):   # toutes les formes du plan (no limit), pas seulement la première
			_losange(t, Color(0.3, 0.6, 1.0, 0.45) if ok else Color(0.5, 0.5, 0.5, 0.35))
		if ok:   # l'atterrissage des poussées : une flèche de la case de départ à la case d'arrivée, un losange fantôme
			for mv in sim.prevoir_deplacement(j, plan, survol):
				var a := _ecran(mv.de, g.h(mv.de))
				var b := _ecran(mv.vers, g.h(mv.vers))
				_losange(mv.vers, Color(1.0, 0.85, 0.4, 0.35))
				draw_line(a, b, Color(1.0, 0.85, 0.4, 0.9), 2.0)
				var dv := (b - a).normalized()
				var nv := Vector2(-dv.y, dv.x)
				draw_colored_polygon(PackedVector2Array([b, b - dv * 10.0 + nv * 5.0, b - dv * 10.0 - nv * 5.0]), Color(1.0, 0.85, 0.4, 0.9))
		if bool(plan.get("ligne_de_vue", true)) and survol != j.pos:   # la ligne de vue, dessinée : verte jusqu'à l'obstacle, rouge après
			var obstacle := g.premier_obstacle_vue(j.pos, survol)
			var depart := _ecran(j.pos, g.h(j.pos))
			var arrivee := _ecran(survol, g.h(survol))
			if obstacle == Vector2i(-1, -1):
				draw_line(depart, arrivee, Color(0.4, 1.0, 0.5, 0.8), 2.0)
			else:
				var casse := _ecran(obstacle, g.h(obstacle))
				draw_line(depart, casse, Color(0.4, 1.0, 0.5, 0.8), 2.0)
				draw_line(casse, arrivee, Color(1.0, 0.3, 0.3, 0.7), 2.0)
				draw_line(casse + Vector2(-7, -7), casse + Vector2(7, 7), Color(1.0, 0.3, 0.3, 0.95), 2.0)
				draw_line(casse + Vector2(-7, 7), casse + Vector2(7, -7), Color(1.0, 0.3, 0.3, 0.95), 2.0)
	if not chemin_en_cours.is_empty() and not j.is_empty():
		var pts := PackedVector2Array([_ecran(j.pos, g.h(j.pos))])
		for c in chemin_en_cours:
			pts.append(_ecran(c, g.h(c)))
		draw_polyline(pts, Color(1, 1, 1, 0.55), 2.0)
	# Plus de chiffre de ticks sur les tuiles atteignables en combat (designer, 2026-08-31) : le voile jaune suffit,
	# le coût exact reste lisible dans l'en-tête au survol.
	for f in xp_flottants:   # l'XP de l'action, qui monte et s'efface au-dessus du joueur (XP de combat)
		var base := _ecran(j.pos, g.h(j.pos)) + Vector2(-20.0, -52.0 - f.t * 22.0 - float(f.get("dec", 0.0)))
		var a: float = clampf(1.6 - f.t, 0.0, 1.0)
		for k in f.lignes.size():
			draw_string(ThemeDB.fallback_font, base + Vector2(0.0, -12.0 * (f.lignes.size() - 1 - k)), str(f.lignes[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.9, 0.5, a))


## Le lot de triangles (2026-09-06, « réécriture C++ et optimisation ») : un morceau de terrain dessinait chaque
## triangle par une commande de canvas (draw_primitive) — quatre cents commandes par morceau, quatorze mille par
## image que le rendu de Godot payait une à une. Pendant qu'un lot est ouvert sur un CanvasItem, `_poly` y accumule
## ses triangles (points, couleurs, UV) et tout part en UNE commande (canvas_item_add_triangle_array) à la fermeture.
## Une commande qu'on ne regroupe pas (texture, rect, ligne) vide le lot avant elle : l'ordre de dessin ne change pas.
class LotTriangles:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()

	func ajouter(poly: PackedVector2Array, col: Color, uv: PackedVector2Array) -> void:
		var avec_uv := uv.size() == poly.size()
		for i in range(1, poly.size() - 1):
			pts.append(poly[0])
			pts.append(poly[i])
			pts.append(poly[i + 1])
			cols.append(col)
			cols.append(col)
			cols.append(col)
			if avec_uv:
				uvs.append(uv[0])
				uvs.append(uv[i])
				uvs.append(uv[i + 1])
			else:   # sans UV, draw_primitive donnait (0, 0) : la même chose
				uvs.append(Vector2.ZERO)
				uvs.append(Vector2.ZERO)
				uvs.append(Vector2.ZERO)

	func vider(ci: CanvasItem) -> void:
		if pts.is_empty():
			return
		var idx := PackedInt32Array()
		idx.resize(pts.size())
		for i in pts.size():
			idx[i] = i
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols, uvs)
		pts.clear()
		cols.clear()
		uvs.clear()


static var _lots: Dictionary = {}   # id d'instance du CanvasItem → LotTriangles ouvert
var lots_actifs := true             # false (capture --sans-lots) : chaque triangle part seul, comme avant — pour mesurer


func _lot_ouvrir(ci: CanvasItem) -> void:
	if lots_actifs:
		_lots[ci.get_instance_id()] = LotTriangles.new()


## Envoie les triangles en attente (avant une commande qu'on ne regroupe pas) ; le lot reste ouvert.
static func _lot_vider(ci: CanvasItem) -> void:
	var lot: LotTriangles = _lots.get(ci.get_instance_id())
	if lot != null:
		lot.vider(ci)


static func _lot_fermer(ci: CanvasItem) -> void:
	var lot: LotTriangles = _lots.get(ci.get_instance_id())
	if lot != null:
		lot.vider(ci)
		_lots.erase(ci.get_instance_id())


## Un polygone convexe dessiné en éventail de triangles par draw_primitive : draw_colored_polygon triangule en float32
## et juge dégénérés les polygones aux coordonnées monde (~1e6 px) — « Invalid polygon data » (brouillard, sol, blocs).
## Dans un lot ouvert (terrain, brouillard), les triangles s'accumulent au lieu de partir un par un.
static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, uvs: PackedVector2Array = PackedVector2Array()) -> void:
	# Les UV portent la position DANS LE PLAN de la face (designer 2026-09-01, point 50) : le grain du
	# shader suit alors l'inclinaison du sol et des parois au lieu d'être plaqué à plat sur l'écran.
	var lot: LotTriangles = _lots.get(ci.get_instance_id())
	if lot != null:
		lot.ajouter(pts, col, uvs)
		return
	var cols := PackedColorArray([col, col, col])
	var avec_uv := uvs.size() == pts.size()
	for i in range(1, pts.size() - 1):
		var tri := PackedVector2Array([pts[0], pts[i], pts[i + 1]])
		var uv := PackedVector2Array([uvs[0], uvs[i], uvs[i + 1]]) if avec_uv else PackedVector2Array()
		ci.draw_primitive(tri, cols, uv)


## De vraies marches (designer 2026-08-31, point 36) : quatre degrés qui rétrécissent vers le fond,
## dorés pour la descente, verts pour la montée — on les prend en marchant dessus.
func _dessiner_escalier(t: Vector2i, col: Color, descend: bool) -> void:
	if not sim.grille.dans(t):
		return
	var c := _ecran(t, sim.grille.h(t))
	for k in 4:
		var l := 26.0 - k * 5.0
		var y := (k - 1.5) * 5.0 * (1.0 if descend else -1.0)
		var teinte := col.darkened(k * 0.12) if descend else col.darkened((3 - k) * 0.12)
		draw_rect(Rect2(c + Vector2(-l * 0.5, y - 2.0), Vector2(l, 4.0)), teinte)
	draw_rect(Rect2(c + Vector2(-14.0, -10.0), Vector2(28.0, 20.0)), col, false, 1.0)


func _losange(t: Vector2i, col: Color) -> void:
	if not sim.grille.dans(t):   # une zone de télégraphe ou une visée peut déborder de la grille : hors de la grille, rien —
		return                   # sinon h() imprimait une erreur d'index PAR IMAGE et PAR TUILE (le « lag de ouf » du 2026-08-31)
	# draw_primitive (deux triangles, sans triangulation) : les coordonnées monde sont grandes (~1e6 px) et la
	# triangulation en float32 de draw_colored_polygon jugeait le losange dégénéré (« Invalid polygon data »).
	var c := _ecran(t, sim.grille.h(t))
	var pts := PackedVector2Array([c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0), c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)])
	draw_primitive(pts, PackedColorArray([col, col, col, col]), PackedVector2Array())


## La passe statique : toutes les tuiles, une seule fois (appelée par la couche Terrain).
## Le morceau d'une tuile (colonne, ligne depuis l'origine de la grille).
func _morceau_de(t: Vector2i) -> Vector2i:
	var o: Vector2i = sim.grille.origine
	var f := Grille.plat(t)
	return Vector2i((f.x - o.x) / MORCEAU, (f.y - o.y) / MORCEAU)


## Une tuile a changé : son morceau se redessine, et ceux de ses voisines si elle est au bord (les flancs et
## les blocs lisent les hauteurs voisines).
func _salir_tuile(p: Vector2i) -> void:
	if sim == null:
		return
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var m := _morceau_de(p + d)
		if morceaux.has(m):
			morceaux[m].queue_redraw()


## Chaque image : les morceaux à portée du joueur existent, les autres meurent ; une nouvelle grille les refait
## tous ; une découverte salit les morceaux du champ de vue (c'est là que les tuiles neuves sont).
func _maj_morceaux(j: Dictionary) -> void:
	if sim == null or profil_sans_terrain:
		return
	var g := sim.grille
	if terrain_a_refaire:
		for m in morceaux.values():
			m.queue_free()
		morceaux.clear()
		for v in noeuds_vegetaux.values():
			v.queue_free()
		noeuds_vegetaux.clear()
		terrain_a_refaire = false
		centre_terrain = Vector2i(-99, -99)
	var c: Vector2i = Grille.plat(j.pos) if not j.is_empty() else g.origine + Vector2i(g.largeur / 2, g.hauteur_grille / 2)
	if c != centre_terrain:
		centre_terrain = c
		var m0 := _morceau_de(Vector2i(maxi(g.origine.x, c.x - rayon_vue), maxi(g.origine.y, c.y - rayon_vue)))
		var m1 := _morceau_de(Vector2i(mini(g.origine.x + g.largeur - 1, c.x + rayon_vue), mini(g.origine.y + g.hauteur_grille - 1, c.y + rayon_vue)))
		var garder := {}
		for my in range(m0.y, m1.y + 1):
			for mx in range(m0.x, m1.x + 1):
				var k := Vector2i(mx, my)
				garder[k] = true
				if not morceaux.has(k):
					var n := TerrainMorceau.new()
					n.proprio = self
					n.coin = k
					n.use_parent_material = true   # LE GRAIN N'ATTEIGNAIT PAS LE SOL (2026-09-08) : un enfant de canevas
					# sans matériau n'hérite PAS de celui de son parent — il faut le lui dire. Le shader du décor était
					# posé sur `terrain`, mais tout est dessiné par ces morceaux : ni motif de matière, ni soleil, ni
					# matière peinte n'arrivaient jusqu'au sol. C'est ce que le designer voyait sans pouvoir le nommer.
					n.z_index = mx + my   # l'ordre de profondeur isométrique entre morceaux : deux morceaux de même z ne se recouvrent pas
					terrain.add_child(n)
					morceaux[k] = n
		for k in morceaux.keys().duplicate():
			if not garder.has(k):
				_liberer_morceau(k)
	_maj_batiment_joueur(j)
	g.decouvertes_recentes.clear()   # les morceaux dessinent toutes les tuiles, vues ou non (2026-09-06) : une découverte ne les touche plus, le brouillard seul change


func _liberer_morceau(k: Vector2i) -> void:
	var g := sim.grille
	var o: Vector2i = g.origine + k * MORCEAU
	for idx in noeuds_vegetaux.keys().duplicate():   # ses végétaux partent avec lui
		var t := g.pos_de(int(idx))
		if t.x >= o.x and t.x < o.x + MORCEAU and t.y >= o.y and t.y < o.y + MORCEAU:
			noeuds_vegetaux[idx].queue_free()
			noeuds_vegetaux.erase(idx)
	morceaux[k].queue_free()
	morceaux.erase(k)


## Un morceau : ses tuiles découvertes, dans l'ordre des diagonales x+y (la profondeur isométrique).
func _dessiner_morceau(ci: CanvasItem, coin: Vector2i) -> void:
	if sim == null or profil_sans_terrain:
		return
	var g := sim.grille
	# Le morceau en tableaux de triangles (file 114, 2026-09-06) : le noyau C++ (SensenGrille.morceau) ou PassesGD.morceau, les
	# mêmes ; les commandes que les triangles ne portent pas (la traverse d'une porte, un contenant, un sprite) sont des
	# COUPURES : on soumet les triangles jusqu'à la coupure, on dessine la commande, on reprend — l'ordre des diagonales tient.
	var p := _params_morceau(g)
	var t0 := Time.get_ticks_usec()
	var res: Dictionary
	if g.noyau_actif and g._noyau_pret():
		res = g._noyau.morceau(g, coin, MORCEAU, p)
	else:
		res = PassesGD.morceau(g, coin, MORCEAU, p)
	_top_client("morceau.tableaux", t0)
	var rid := ci.get_canvas_item()
	var pts: PackedVector2Array = res.points
	var cols: PackedColorArray = res.couleurs
	var uvs: PackedVector2Array = res.uvs
	var coupures: PackedInt32Array = res.coupures
	var debut := 0
	var teinte := Color.WHITE.lerp(Color(1.4, 1.4, 1.5), 0.5) if g.neige else Color.WHITE
	@warning_ignore("integer_division")
	for k in coupures.size() / 3:
		var fin: int = coupures[k * 3]
		var idx: int = coupures[k * 3 + 1]
		var genre: int = coupures[k * 3 + 2]
		if fin > debut:
			_soumettre_triangles(rid, pts, cols, uvs, debut, fin)
			debut = fin
		var t := g.pos_de(idx)
		var c := _ecran(t, g.h(t))
		match genre:
			1:   # la traverse et la poignée d'une porte
				_porte_details(ci, g, t, c, g.contenu_de(t), teinte)
			2:   # un contenant : une caisse
				var cc := (Color(0.55, 0.38, 0.18) if "coffre" in g.contenu_de(t).get("tags", []) else Color(0.75, 0.65, 0.3)) * teinte
				ci.draw_rect(Rect2(c + Vector2(-6, -8), Vector2(12, 8)), cc)
				ci.draw_rect(Rect2(c + Vector2(-6, -8), Vector2(12, 8)), cc.darkened(0.5), false, 1.0)
			3:   # le sprite d'un meuble ou d'une station
				_dessiner_sprite_tuile(ci, g, t, c, teinte)
	if pts.size() > debut:
		_soumettre_triangles(rid, pts, cols, uvs, debut, pts.size())
	_franges_matieres(rid, g, coin, p, teinte, coupures)
	for idx in res.vegetaux:
		_assurer_vegetal(g.pos_de(idx))


## LES TEXTURES DES TUILES SE FONDENT (designer 2026-09-08 : « rajouter de quoi fondre les textures des tuiles entre
## elles »). Le sol d'une tuile est un losange d'UNE matière : la limite entre l'herbe et la terre suivait donc
## exactement le losange, et le regard lisait la grille au lieu du terrain.
##
## Après le sol du morceau, on repose sur chaque tuile de bordure UN TRIANGLE par voisin de matière différente — du
## centre du losange vers l'arête partagée —, avec la matière DU VOISIN et une opacité qui va de zéro au centre à
## `fondu_tuiles_force` sur l'arête. Le voisin déborde donc sur nous, en fondu.
##
## Le coût est d'un triangle par arête qui change de matière : aucun sur les grandes plages uniformes, quatre au plus
## sur une tuile isolée. Et tous partent en UNE commande, parce que le style d'une matière voyage dans les UV et non
## dans un uniforme — un seul lot suffit pour toutes les matières du morceau.
func _franges_matieres(rid: RID, g: Grille, coin: Vector2i, p: Dictionary, teinte: Color, coupures: PackedInt32Array) -> void:
	var stg: Dictionary = GameData.config("styles").get("grain", {})
	if not bool(stg.get("fondu_tuiles", true)):
		return
	var force := float(stg.get("fondu_tuiles_force", 0.85))
	var tw2 := float(TW) * 0.5
	var th2 := float(TH) * 0.5
	var uvh := float(p.uv_haut)
	# Les quatre arêtes du losange, dans le repère du sol : N (0,0), E (1,0), S (1,1), O (0,1). Le voisin en +x est
	# en bas à droite (l'isométrie), donc l'arête partagée avec lui va de E à S ; et ainsi de suite.
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var aretes := [[Vector2(1, 0), Vector2(1, 1)], [Vector2(1, 1), Vector2(0, 1)], [Vector2(0, 1), Vector2(0, 0)], [Vector2(0, 0), Vector2(1, 0)]]
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	# Les tuiles qui ont produit une COUPURE portent un dessin propre (une porte, une caisse, un meuble) déjà posé :
	# la frange passerait par-dessus. On les saute — c'est la liste exacte, pas une devinette sur le contenu.
	var posees := {}
	@warning_ignore("integer_division")
	for kc in coupures.size() / 3:
		posees[coupures[kc * 3 + 1]] = true
	# `coin` est l'INDICE du morceau, pas une tuile : la tuile de départ est origine + coin × MORCEAU (PassesGD.morceau).
	var t0 := g.origine + coin * MORCEAU
	for dy in MORCEAU:
		for dx in MORCEAU:
			var t := t0 + Vector2i(dx, dy)
			if not g.dans(t) or g.bloque_passage(t):
				continue
			if posees.has(g.idx(t)):
				continue   # une tuile qui porte déjà son dessin : on ne repeint pas par-dessus
			var h_t := g.h(t)
			var st_t := float(p.mat_st.get(g.materiau_sol(t), 0.0))
			var c := _ecran(t, h_t)
			var l: Vector2i = Grille.plat(t) - origine_dessin
			for k in 4:
				var n: Vector2i = t + dirs[k]
				if not g.dans(n) or g.bloque_passage(n) or g.h(n) != h_t:
					continue   # une marche a déjà son flanc : le fondu ne vaut que pour un raccord à plat
				var sol_n := g.materiau_sol(n)
				var st_n := float(p.mat_st.get(sol_n, 0.0))
				if is_equal_approx(st_n, st_t):
					continue
				var col_n := _couleur_sol(sol_n, g.h(n), p) * teinte
				var a: Vector2 = aretes[k][0]
				var b: Vector2 = aretes[k][1]
				pts.append(c)
				pts.append(c + Vector2((a.x - a.y) * tw2, (a.x + a.y - 1.0) * th2))
				pts.append(c + Vector2((b.x - b.y) * tw2, (b.x + b.y - 1.0) * th2))
				cols.append(Color(col_n.r, col_n.g, col_n.b, 0.0))
				cols.append(Color(col_n.r, col_n.g, col_n.b, force))
				cols.append(Color(col_n.r, col_n.g, col_n.b, force))
				uvs.append(Vector2(st_n + float(l.x) + 0.5, uvh + float(l.y) + 0.5))
				uvs.append(Vector2(st_n + float(l.x) + a.x, uvh + float(l.y) + a.y))
				uvs.append(Vector2(st_n + float(l.x) + b.x, uvh + float(l.y) + b.y))
	if not pts.is_empty():
		_soumettre_triangles(rid, pts, cols, uvs, 0, pts.size())


## La couleur du sol d'une tuile — la MÊME formule que la passe du terrain, pour que la frange d'un voisin soit
## exactement de sa couleur (PassesGD._sol).
func _couleur_sol(sol_id: String, h: int, p: Dictionary) -> Color:
	var k := clampf((float(h) - 4.0) / 12.0, 0.0, 1.0)
	var col := Color(0.20, 0.34, 0.18).lerp(Color(0.62, 0.66, 0.42), k)
	if not sol_id.is_empty() and p.mat_col.has(sol_id):
		col = (p.mat_col[sol_id] as Color).lerp(Color(0.35, 0.5, 0.25), 0.35 if sol_id.begins_with("terre") else 0.0).darkened(0.25 - k * 0.3)
	return col


## Une tranche de tableaux de triangles, en une commande.
static func _soumettre_triangles(rid: RID, pts: PackedVector2Array, cols: PackedColorArray, uvs: PackedVector2Array, debut: int, fin: int) -> void:
	var n := fin - debut
	var idx := PackedInt32Array()
	idx.resize(n)
	for i in n:
		idx[i] = i
	RenderingServer.canvas_item_add_triangle_array(rid, idx, pts.slice(debut, fin), cols.slice(debut, fin), uvs.slice(debut, fin))


## La traverse et la poignée d'une porte (la fin de _dessiner_porte) : des commandes de ligne et de disque, hors lot.
func _porte_details(ci: CanvasItem, g: Grille, t: Vector2i, c: Vector2, contenu: Dictionary, teinte: Color) -> void:
	var bois := _couleur_html(str(contenu.get("couleur", "#6a4a22"))) * teinte
	var mur_x: bool = (g.dans(t + Vector2i(1, 0)) and g.bloque_passage(t + Vector2i(1, 0))) or (g.dans(t - Vector2i(1, 0)) and g.bloque_passage(t - Vector2i(1, 0)))
	var demi := Vector2(TW * 0.25, TH * 0.25) if mur_x else Vector2(TW * 0.25, -TH * 0.25)
	var a := c - demi
	var b := c + demi
	var haut := Vector2(0.0, -float((PORTE_BLOCS * BLOC_UNITES) if g.niveaux_bat[g.idx(t)] > 0 else int(contenu.get("hauteur_vue", 2))) * HSTEP)
	var ferme: bool = "fermee" in contenu.get("tags", [])
	var p0 := a if ferme else a.lerp(b, 0.68)
	var p1 := b
	var trav := (p0 + p1) * 0.5 + haut * 0.55
	ci.draw_line(p0 + haut * 0.5, p1 + haut * 0.5, bois.darkened(0.25), 1.0)
	ci.draw_circle(trav.lerp(p1 + haut * 0.55, 0.45), 1.6, Color(0.85, 0.75, 0.35) * teinte)


var _tables_morceau: Dictionary = {}   # les tables des passes (couleur et grain par matériau, par meuble), bâties une fois


## Les paramètres d'un morceau pour PassesGD / le noyau : les tables (une fois), les contenus et les bâtiments de la grille.
func _params_morceau(g: Grille) -> Dictionary:
	if _tables_morceau.is_empty():
		var mat_col := {}
		var mat_st := {}
		for mid in GameData.catalogues.materials.keys():
			var md: Dictionary = GameData.catalogues.materials[mid]
			if md.has("color"):
				mat_col[str(mid)] = _couleur_html(str(md.color))
			mat_st[str(mid)] = _style_grain(str(mid))
		mat_st["eau"] = _style_grain("eau")
		var defaut := str(GameData.config("styles").get("grain", {}).get("materiau_mur_defaut", "granit"))
		mat_st[defaut] = _style_grain(defaut)
		var meuble_col := {}
		var meuble_emprise := {}
		for mid in GameData.catalogues.meubles.keys():
			var mb: Dictionary = GameData.catalogues.meubles[mid]
			meuble_col[str(mid)] = _couleur_html(str(mb.get("couleur", "#7a6a4a")))
			meuble_emprise[str(mid)] = float(mb.get("emprise", 0.6))
		_tables_morceau = {"mat_col": mat_col, "mat_st": mat_st, "meuble_col": meuble_col, "meuble_emprise": meuble_emprise, "materiau_mur_defaut": defaut}
	var contenu_col := PackedColorArray()
	contenu_col.resize(g.contenu_ids.size())
	for k in g.contenu_ids.size():
		var def: Dictionary = g.contenu_defs.get(g.contenu_ids[k], {})
		contenu_col[k] = _couleur_html(str(def.couleur)) if def.has("couleur") else Color(1, 1, 1, 1)
	var bat_mur := PackedStringArray()
	var bat_pierre := PackedStringArray()
	var bat_bois := PackedStringArray()
	for info in g.batiments_liste:
		bat_mur.append(str(info.get("mur", "")))
		bat_pierre.append(str(info.get("pierre", "")))
		bat_bois.append(str(info.get("bois", "")))
	return {"origine_dessin": origine_dessin, "tw": float(TW), "th": float(TH), "hstep": float(HSTEP), "uv_haut": UV_HAUT, "uv_so": UV_SO, "uv_se": UV_SE,
		"uv_pas_face": UV_PAS_FACE, "niveau_u": NIVEAU_BLOCS * BLOC_UNITES, "bloc_u": BLOC_UNITES, "porte_u": PORTE_BLOCS * BLOC_UNITES, "mur_coupe_u": MUR_COUPE_UNITES,
		"bat_j": _bat_joueur, "mat_col": _tables_morceau.mat_col, "mat_st": _tables_morceau.mat_st, "meuble_col": _tables_morceau.meuble_col,
		"meuble_emprise": _tables_morceau.meuble_emprise, "materiau_mur_defaut": _tables_morceau.materiau_mur_defaut, "contenu_col": contenu_col,
		"bat_mur_id": bat_mur, "bat_pierre_id": bat_pierre, "bat_bois_id": bat_bois}


## La profondeur d'un billboard (z relatif) : x + y, ramené à la fenêtre (les coordonnées monde dépassent CANVAS_ITEM_Z_MAX).
func _profondeur(t: Vector2i) -> int:
	var o: Vector2i = sim.grille.origine
	var f := Grille.plat(t)
	return clampi((f.x - o.x) + (f.y - o.y) + 1, 1, 4000)


## Un billboard pour le végétal d'une tuile (Direction artistique : les ressources récoltables sont des sprites).
func _assurer_vegetal(t: Vector2i) -> void:
	var g := sim.grille
	var idx := g.idx(t)
	if noeuds_vegetaux.has(idx):
		return
	var v := Vegetal.new()
	var mat_id := g.materiau_de(t)
	v.configurer(mat_id, GameData.catalogues.vegetaux.get(mat_id, {}), GameData.catalogues.materials.get(mat_id, {}), hash([t.x, t.y]))
	v.position = _ecran(t, g.h(t))
	v.z_index = _profondeur(t)
	var j := joueur()
	var stb: Dictionary = GameData.config("styles").get("brouillard", {})
	var voile := Color.WHITE
	if not g.decouvert.has(idx):
		voile = _couleur_liste(stb.get("vegetal_jamais_vu", [0.18, 0.18, 0.22]))   # jamais vu : sombre, mais là (plus de fond gris)
	elif not j.is_empty() and not sim.voit(j, t):
		voile = _couleur_liste(stb.get("vegetal_memorise", [0.45, 0.45, 0.5]))
	v.set_meta("voile", voile)
	v.modulate = _lumiere_tuile(t) * voile
	add_child(v)
	noeuds_vegetaux[idx] = v


func _zones_telegraphes() -> Dictionary:
	var zones := {}
	for id in telegraphes.keys():
		var e: Dictionary = sim.entites[id]
		var a: Dictionary = telegraphes[id]
		if a.type == "creature":
			var action: Dictionary = sim.actions_creatures[a.action]
			var cible: Dictionary = sim.entites.get(a.cible, {})
			match str(action.forme):
				"ligne":
					for p in sim.grille.ligne(e.pos, cible.pos if not cible.is_empty() else e.pos + e.orientation, int(action.taille)):
						zones[p] = true
				"anneau", "soi":
					for p in sim.grille.anneau(e.pos, int(action.taille)):
						zones[p] = true
				_:
					if not cible.is_empty():
						zones[cible.pos] = true
		elif sim.entites.has(a.cible):
			zones[sim.entites[a.cible].pos] = true
	return zones


func _dessine_tuile(ci: CanvasItem, t: Vector2i) -> void:
	var g := sim.grille
	var h := g.h(t)
	var c := _ecran(t, h)
	var teinte := Color.WHITE   # le brouillard est une couche à part (_dessiner_brouillard)
	var tags_c: Array = g.contenu_de(t).get("tags", [])
	if "liquide" in tags_c:   # la mer : un losange d'eau à sa hauteur, les flancs de la rive sont ceux des tuiles voisines
		var col_eau := _couleur_html(str(g.contenu_de(t).get("couleur", "#2f5f9a")))
		if "ecoulement" in tags_c:   # un écoulement : plus le niveau est bas, plus l'eau est claire (Eau et liquides)
			col_eau = col_eau.lerp(Color(0.6, 0.8, 0.95), 1.0 - float(g.niveau_liquide(t)) / 8.0)
		if g.gel:   # Météo : la glace
			col_eau = col_eau.lerp(Color(0.85, 0.92, 1.0), 0.7)
		var st_eau := _style_grain("eau")
		_poly(ci, PackedVector2Array([c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0), c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)]),
			col_eau * teinte, PackedVector2Array([_uv_haut(t, 0, 0, st_eau), _uv_haut(t, 1, 0, st_eau), _uv_haut(t, 1, 1, st_eau), _uv_haut(t, 0, 1, st_eau)]))
		return
	if g.neige:   # Météo : le sol blanchit sous la neige
		teinte = teinte.lerp(Color(1.4, 1.4, 1.5), 0.5)
	if g.bloque_passage(t) and not ("vegetation" in tags_c) and not ("porte" in tags_c):   # un mur : un bloc plein — le sol dessous est caché
		_dessine_bloc(ci, g, t, c, teinte, 0, MUR_COUPE_UNITES if _mur_coupe(g, t) else 0)
		_dessiner_sprite_tuile(ci, g, t, c, teinte)
		return
	var haut := PackedVector2Array([
		c + Vector2(0, -TH * 0.5), c + Vector2(TW * 0.5, 0),
		c + Vector2(0, TH * 0.5), c + Vector2(-TW * 0.5, 0)])
	var k := clampf((h - 4) / 12.0, 0.0, 1.0)   # gradient : bas sombre, sommets clairs
	var col := Color(0.20, 0.34, 0.18).lerp(Color(0.62, 0.66, 0.42), k)
	var sol_id := g.materiau_sol(t)
	if not sol_id.is_empty():   # surface : la couleur du matériau de sol du biome, nuancée par la hauteur
		var ms: Dictionary = GameData.catalogues.materials.get(sol_id, {})
		if not ms.is_empty():
			col = _couleur_html(str(ms.color)).lerp(Color(0.35, 0.5, 0.25), 0.35 if sol_id.begins_with("terre") else 0.0).darkened(0.25 - k * 0.3)
	col *= teinte
	var st_sol := _style_grain(sol_id)   # le motif de la matière (point 58)
	var uv_sol := PackedVector2Array([   # le grain suit le plan du sol : les UV sont les coins de la tuile (un dessus : soleil et lumière)
		_uv_haut(t, 0, 0, st_sol), _uv_haut(t, 1, 0, st_sol), _uv_haut(t, 1, 1, st_sol), _uv_haut(t, 0, 1, st_sol)])
	_poly(ci, haut, col, uv_sol)
	var flanc := col.darkened(0.35)
	var hs := g.h(t + Vector2i(0, 1)) if g.dans(t + Vector2i(0, 1)) else 0
	if hs < h:
		var d := (h - hs) * HSTEP
		_poly(ci, PackedVector2Array([
			c + Vector2(-TW * 0.5, 0), c + Vector2(0, TH * 0.5),
			c + Vector2(0, TH * 0.5 + d), c + Vector2(-TW * 0.5, d)]), flanc,
			PackedVector2Array([_uv_so(t, 0, h, st_sol), _uv_so(t, 1, h, st_sol), _uv_so(t, 1, hs, st_sol), _uv_so(t, 0, hs, st_sol)]))
	var he := g.h(t + Vector2i(1, 0)) if g.dans(t + Vector2i(1, 0)) else 0
	if he < h:
		var d2 := (h - he) * HSTEP
		_poly(ci, PackedVector2Array([
			c + Vector2(0, TH * 0.5), c + Vector2(TW * 0.5, 0),
			c + Vector2(TW * 0.5, d2), c + Vector2(0, TH * 0.5 + d2)]), flanc.darkened(0.15),
			PackedVector2Array([_uv_se(t, 0, h, st_sol), _uv_se(t, 1, h, st_sol), _uv_se(t, 1, he, st_sol), _uv_se(t, 0, he, st_sol)]))
	var contenu := g.contenu_de(t)
	if not contenu.is_empty() and not g.bloque_passage(t) and not ("porte" in contenu.get("tags", [])) and (contenu.has("couleur") or "meuble" in contenu.get("tags", [])):
		# contenu franchissable (porte, entrée du donjon, tapis) : un losange plat coloré
		var cf := _couleur_html(str(GameData.entree("meubles", str(g.meubles.get(g.idx(t), "tapis"))).couleur)) if "meuble" in contenu.get("tags", []) else _couleur_html(str(contenu.couleur))
		_poly(ci, PackedVector2Array([c + Vector2(0, -TH * 0.35), c + Vector2(TW * 0.35, 0), c + Vector2(0, TH * 0.35), c + Vector2(-TW * 0.35, 0)]), cf * teinte,
			PackedVector2Array([_uv_haut(t, 0.15, 0.15, 0.0), _uv_haut(t, 0.85, 0.15, 0.0), _uv_haut(t, 0.85, 0.85, 0.0), _uv_haut(t, 0.15, 0.85, 0.0)]))
		_dessiner_sprite_tuile(ci, g, t, c, teinte)
	if "porte" in contenu.get("tags", []):   # une porte n'est pas un mur : un battant dans son encadrement
		if _mur_coupe(g, t):   # dans le mur coupé du bâtiment du joueur : le seuil seulement, à plat
			var cs := _couleur_html(str(contenu.get("couleur", "#6a4a22"))) * teinte
			_poly(ci, PackedVector2Array([c + Vector2(0, -TH * 0.35), c + Vector2(TW * 0.35, 0), c + Vector2(0, TH * 0.35), c + Vector2(-TW * 0.35, 0)]), cs,
				PackedVector2Array([_uv_haut(t, 0.15, 0.15, 0.0), _uv_haut(t, 0.85, 0.15, 0.0), _uv_haut(t, 0.85, 0.85, 0.0), _uv_haut(t, 0.15, 0.85, 0.0)]))
		else:
			_dessiner_porte(ci, g, t, c, contenu, teinte)
			if g.niveaux_bat[g.idx(t)] > 0:   # dans un bâtiment, le mur continue au-dessus de la porte (Villes, 2026-09-06)
				_dessine_bloc(ci, g, t, c, teinte, PORTE_BLOCS * BLOC_UNITES)
	if "contenant" in contenu.get("tags", []):   # coffre ou butin : une caisse
		var cc := (Color(0.55, 0.38, 0.18) if "coffre" in contenu.tags else Color(0.75, 0.65, 0.3)) * teinte
		_lot_vider(ci)
		ci.draw_rect(Rect2(c + Vector2(-6, -8), Vector2(12, 8)), cc)
		ci.draw_rect(Rect2(c + Vector2(-6, -8), Vector2(12, 8)), cc.darkened(0.5), false, 1.0)

## Le sprite d'un meuble ou d'une station posés (Direction artistique, 2026-09-05) : `meuble_<id>.png` ou
## `station_<id>.png` dans le dossier des sprites, dressé sur la tuile par-dessus le bloc de couleur — s'il existe.
func _dessiner_sprite_tuile(ci: CanvasItem, g: Grille, t: Vector2i, c: Vector2, teinte: Color) -> void:
	var gi := g.idx(t)
	var l := TW * 0.9
	# UNE TUILE PORTE UNE PILE DE MEUBLES (26 undecies) : on les dessine du bas vers le haut, chacun un peu plus
	# haut que celui qu'il couvre — le coffre posé sur la table se voit sur la table.
	var pile_m: Array = g.meubles_de(gi)
	if not pile_m.is_empty():
		_lot_vider(ci)   # les sprites se dessinent par-dessus les triangles déjà posés
		for k_m in pile_m.size():
			var tex_m := Pictos.texture_objet({"id": "meuble_" + str(pile_m[k_m]), "type": "meuble"})
			if tex_m == null:
				continue
			ci.draw_texture_rect(tex_m, Rect2(c + Vector2(-l * 0.5, TH * 0.4 - l - float(k_m) * _pile_hauteur_meuble), Vector2(l, l)), false, teinte)
		return
	if not g.stations_fixes.has(gi):
		return
	var tex := Pictos.texture_objet({"id": "station_" + str(g.stations_fixes[gi]), "type": "station"})
	if tex == null:
		return
	_lot_vider(ci)
	ci.draw_texture_rect(tex, Rect2(c + Vector2(-l * 0.5, TH * 0.4 - l), Vector2(l, l)), false, teinte)


## La passe du brouillard : sur la fenêtre du terrain, un voile opaque (couleur du fond) sur les tuiles
## jamais vues, un voile translucide sur les tuiles mémorisées hors du champ de vue. Chaque voile couvre
## le losange de la tuile et la hauteur de son bloc éventuel.
func _dessiner_brouillard(ci: CanvasItem) -> void:
	if sim == null or profil_sans_terrain:
		return
	var g := sim.grille
	var j := joueur()
	if j.is_empty():
		return
	centre_brouillard = j.pos
	vue_version = int(j.get("vue_version", 0))
	# Le brouillard en tableaux de triangles (file 114, 2026-09-06) : le noyau C++ les bâtit (SensenGrille.brouillard), PassesGD
	# sinon — les mêmes ; puis une seule commande de canvas. Le client garde ses réglages : le voile, la silhouette, le rayon.
	var stb: Dictionary = GameData.config("styles").get("brouillard", {})
	var voile := _couleur_liste(stb.get("voile", [0.05, 0.05, 0.08, 0.55]))   # le sol mémorisé, hors de vue
	var voile_jamais := _couleur_liste(stb.get("jamais_vu", [0.02, 0.02, 0.04, 0.85]))   # jamais vu : plus sombre, mais le terrain est là
	# Un MUR mémorisé n'est pas une vitre (designer 2026-09-08) : son voile est presque opaque, là où celui du sol
	# reste léger. Le même voile pour les deux laissait voir le pavé à travers un mur depuis que le décor a du grain.
	var voile_bloc := _couleur_liste(stb.get("voile_bloc", [0.05, 0.05, 0.08, 0.88]))
	var jamais_bloc := _couleur_liste(stb.get("jamais_vu_bloc", [0.02, 0.02, 0.04, 0.98]))
	var veg_memo := _couleur_liste(stb.get("vegetal_memorise", [0.45, 0.45, 0.5]))
	var veg_noir := _couleur_liste(stb.get("vegetal_jamais_vu", [0.18, 0.18, 0.22]))
	var jp := Grille.plat(j.pos)
	var vue: Dictionary = j.get("vue", {})
	var tout_vu := not j.has("vue")
	var zj := Grille.z_de(j.pos)
	var vide_ci := g.contenu_ids.find("vide")
	var res: Dictionary
	var t0 := Time.get_ticks_usec()
	if g.noyau_actif and g._noyau_pret():
		res = g._noyau.brouillard(g, vue, tout_vu, zj, vide_ci, jp, rayon_vue, origine_dessin, float(TW), float(TH), float(HSTEP), NIVEAU_BLOCS * BLOC_UNITES, _bat_joueur, MUR_COUPE_UNITES, voile, voile_jamais, voile_bloc, jamais_bloc)
	else:
		res = PassesGD.brouillard(g, vue, tout_vu, zj, vide_ci, jp, rayon_vue, origine_dessin, float(TW), float(TH), float(HSTEP), NIVEAU_BLOCS * BLOC_UNITES, _bat_joueur, MUR_COUPE_UNITES, voile, voile_jamais, voile_bloc, jamais_bloc)
	_top_client("brouillard.tableaux", t0)
	for idx in res.veg_vus:
		if noeuds_vegetaux.has(idx):
			noeuds_vegetaux[idx].set_meta("voile", Color.WHITE)
			noeuds_vegetaux[idx].modulate = _lumiere_tuile(g.pos_de(idx))
	for idx in res.veg_voiles:
		if noeuds_vegetaux.has(idx):
			noeuds_vegetaux[idx].set_meta("voile", veg_memo)   # un billboard : on le voile lui-même (modulate), sous sa lumière
			noeuds_vegetaux[idx].modulate = _lumiere_tuile(g.pos_de(idx)) * veg_memo
	for idx in res.veg_noirs:
		if noeuds_vegetaux.has(idx):
			noeuds_vegetaux[idx].set_meta("voile", veg_noir)
			noeuds_vegetaux[idx].modulate = _lumiere_tuile(g.pos_de(idx)) * veg_noir
	if res.points.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), res.indices, res.points, res.couleurs, res.uvs)


## Un bloc de mur : le dessus et les deux faces avant (sud-ouest, sud-est) ; une face n'est
## dessinée que si la tuile devant n'est pas elle-même un mur découvert (elle la cacherait entièrement ;
## un mur jamais vu n'est pas dessiné, donc ne cache rien — sinon le bloc paraît creux).
## La silhouette d'un bloc mémorisé hors de vue (le brouillard, 2026-09-06) : ses trois faces à plat, sombres et opaques,
## sans matériau ni bandes — le brouillard se redessine à chaque pas et une ville en compte des centaines par passe ;
## le bloc complet (`_dessine_bloc`) coûtait 73 µs, celle-ci le quart.
func _dessine_silhouette(ci: CanvasItem, g: Grille, t: Vector2i, c: Vector2) -> void:
	var hm := _hauteur_bloc(g, t) * HSTEP
	if hm <= 0:
		return
	var tw := TW * 0.5
	var th := TH * 0.5
	var col := Color(0.38, 0.38, 0.44)
	_poly(ci, PackedVector2Array([c + Vector2(-tw, 0), c + Vector2(0, th), c + Vector2(0, th - hm), c + Vector2(-tw, -hm)]), col.darkened(0.35))
	_poly(ci, PackedVector2Array([c + Vector2(0, th), c + Vector2(tw, 0), c + Vector2(tw, -hm), c + Vector2(0, th - hm)]), col.darkened(0.5))
	_poly(ci, PackedVector2Array([c + Vector2(-tw, -hm), c + Vector2(0, -th - hm), c + Vector2(tw, -hm), c + Vector2(0, th - hm)]), col)


## La hauteur dessinée du bloc d'une tuile, en unités : celle de son contenu, ou celle du bâtiment qui la couvre —
## un niveau de bâtiment fait NIVEAU_BLOCS blocs de BLOC_UNITES (Villes, 2026-09-06) ; 0 si rien ne s'y dresse.
func _hauteur_bloc(g: Grille, t: Vector2i) -> int:
	return PassesGD.hauteur_bloc(g, t, _bat_joueur, NIVEAU_BLOCS * BLOC_UNITES, MUR_COUPE_UNITES)   # la même règle que les passes (file 114)


## `base_u` : le bloc commence à cette hauteur (le mur au-dessus d'une porte) ; sinon au sol.
func _dessine_bloc(ci: CanvasItem, g: Grille, t: Vector2i, c: Vector2, teinte: Color = Color.WHITE, base_u: int = 0, plafond_u: int = 0) -> void:
	var t0_b := Time.get_ticks_usec()
	chrono["n.bloc"] = float(chrono.get("n.bloc", 0.0)) + 1.0
	var contenu_t := g.contenu_de(t)
	var tags_t: Array = contenu_t.get("tags", [])
	var idx_t := g.idx(t)
	var n_bat: int = g.niveaux_bat[idx_t]
	var mur_bat := n_bat > 0 and ("mur" in tags_t or "porte" in tags_t)   # une façade de bâtiment : des blocs empilés
	var hm := (n_bat * NIVEAU_BLOCS * BLOC_UNITES if mur_bat else int(contenu_t.get("hauteur_vue", 3))) * HSTEP
	if plafond_u > 0:   # un mur coupé (le mur sud ou est du bâtiment du joueur) : un muret, pour lire l'emprise sans cacher la pièce
		hm = mini(hm, plafond_u * HSTEP)
	var haut_bloc := Color(0.5, 0.47, 0.44)
	var mat_id := g.materiau_de(t)
	if mur_bat and "porte" in tags_t:   # au-dessus d'une porte : le mur du bâtiment, pas la couleur du battant
		mat_id = str(g.batiments_liste[int(g.bat_de[idx_t]) - 1].get("mur", mat_id))
	var mat: Dictionary = GameData.catalogues.materials.get(mat_id, {})
	var emprise := 1.0   # un meuble est un bloc plus petit que sa case (designer, point 46)
	if "meuble" in tags_t and g.meubles.has(idx_t):
		var mb: Dictionary = GameData.entree("meubles", str(g.meubles[idx_t]))
		haut_bloc = _couleur_html(str(mb.couleur))
		emprise = float(mb.get("emprise", 0.6))
		hm = int(roundf(float(hm) * emprise))
	elif contenu_t.has("couleur") and not mur_bat:
		haut_bloc = _couleur_html(str(contenu_t.couleur))
	elif "arbre" in tags_t:
		haut_bloc = Color(0.22, 0.45, 0.18).lerp(_couleur_html(str(mat.color)) if not mat.is_empty() else haut_bloc, 0.2)   # la cime
	elif not mat.is_empty():   # la couleur de la palette du matériau (filon ou mur du thème)
		haut_bloc = haut_bloc.lerp(_couleur_html(str(mat.color)), 0.55 if g.materiaux.has(idx_t) or mur_bat else 0.35)
	haut_bloc *= teinte
	var mat_bloc := mat_id   # murs et blocs texturés comme le sol (point 58)
	if mat_bloc.is_empty():
		mat_bloc = str(GameData.config("styles").get("grain", {}).get("materiau_mur_defaut", "granit"))   # un mur nu reste de la roche
	var st_bloc := _style_grain(mat_bloc)
	var tw := TW * 0.5 * emprise
	var th := TH * 0.5 * emprise
	var h0 := base_u * HSTEP   # le pied du bloc
	# Une face n'est dessinée que si ce qui est devant ne la cache pas entièrement : une tuile de mur découverte au
	# moins aussi haute (une façade de deux niveaux dépasse d'une maison basse).
	var sud := t + Vector2i(0, 1)
	var est := t + Vector2i(1, 0)
	var face_so := not (g.dans(sud) and g.decouvert.has(g.idx(sud)) and _hauteur_bloc(g, sud) * HSTEP >= hm)
	var face_se := not (g.dans(est) and g.decouvert.has(g.idx(est)) and _hauteur_bloc(g, est) * HSTEP >= hm)
	# Les blocs empilés d'une façade : une bande par bloc — le premier en PIERRE, les suivants en BOIS du village (designer
	# 2026-09-06, 13 h : « une maison est en une certaine pierre et un certain bois, la teinte et la texture en sont
	# dérivées ») ; chaque bande prend la couleur de son matériau et le grain de sa famille.
	var bande := BLOC_UNITES * HSTEP if mur_bat else hm
	var info_bat: Dictionary = g.batiments_liste[int(g.bat_de[idx_t]) - 1] if mur_bat else {}
	var y := h0
	var col_haut := haut_bloc
	var st_haut := st_bloc
	while y < hm:
		var y1 := mini(hm, y + bande)
		var col_b := haut_bloc
		var st_b := st_bloc
		if mur_bat:
			var bloc_k := y / (BLOC_UNITES * HSTEP)
			var mat_b := str(info_bat.get("bois", "")) if (bloc_k > 0 and not str(info_bat.get("bois", "")).is_empty()) else str(info_bat.get("pierre", ""))
			if mat_b.is_empty():
				mat_b = mat_id
			var mm: Dictionary = GameData.catalogues.materials.get(mat_b, {})
			if not mm.is_empty():
				col_b = Color(0.5, 0.47, 0.44).lerp(_couleur_html(str(mm.color)), 0.65) * teinte
			st_b = _style_grain(mat_b)
		if face_so:
			_poly(ci, PackedVector2Array([   # face sud-ouest (gauche)
				c + Vector2(-tw, -y), c + Vector2(0, th - y),
				c + Vector2(0, th - y1), c + Vector2(-tw, -y1)]), col_b.darkened(0.35),
				PackedVector2Array([_uv_so(t, 0, float(y) / HSTEP, st_b), _uv_so(t, 1, float(y) / HSTEP, st_b), _uv_so(t, 1, float(y1) / HSTEP, st_b), _uv_so(t, 0, float(y1) / HSTEP, st_b)]))
		if face_se:
			_poly(ci, PackedVector2Array([   # face sud-est (droite)
				c + Vector2(0, th - y), c + Vector2(tw, -y),
				c + Vector2(tw, -y1), c + Vector2(0, th - y1)]), col_b.darkened(0.5),
				PackedVector2Array([_uv_se(t, 0, float(y) / HSTEP, st_b), _uv_se(t, 1, float(y) / HSTEP, st_b), _uv_se(t, 1, float(y1) / HSTEP, st_b), _uv_se(t, 0, float(y1) / HSTEP, st_b)]))
		col_haut = col_b
		st_haut = st_b
		y = y1
	_poly(ci, PackedVector2Array([   # dessus
		c + Vector2(-tw, -hm), c + Vector2(0, -th - hm),
		c + Vector2(tw, -hm), c + Vector2(0, th - hm)]), col_haut,
		PackedVector2Array([_uv_haut(t, 0, 1, st_haut), _uv_haut(t, 0, 0, st_haut), _uv_haut(t, 1, 0, st_haut), _uv_haut(t, 1, 1, st_haut)]))
	_top_client("draw.bloc", t0_b)


## Le bâtiment qui couvre une tuile (1 + son index dans batiments_liste), 0 hors bâtiment.
func _batiment_de(t: Vector2i) -> int:
	if sim == null or not sim.grille.dans(t):
		return 0
	return int(sim.grille.bat_de[sim.grille.idx(t)])


## L'étage du joueur (les couches Z, 2026-09-06) : les tuiles de la couche z de son bâtiment, en ordre de profondeur,
## dessinées comme le terrain (`_dessine_tuile` : leur hauteur d'écran est soulevée par `_ecran`). Rien quand il est au sol.
func _dessiner_etage(ci: CanvasItem) -> void:
	if sim == null or profil_sans_terrain:
		return
	var j := joueur()
	if j.is_empty():
		return
	var zj := Grille.z_de(j.pos)
	var g := sim.grille
	if zj <= 0 or _bat_joueur <= 0 or _bat_joueur > g.batiments_liste.size():
		return
	var r: Rect2i = g.batiments_liste[_bat_joueur - 1].rect
	_lot_ouvrir(ci)
	for s_d in range(r.position.x + r.position.y, r.end.x + r.end.y - 1):
		for x in range(maxi(r.position.x, s_d - r.end.y + 1), mini(r.end.x - 1, s_d - r.position.y) + 1):
			var t := Grille.en_couche(Vector2i(x, s_d - x), zj)
			if not g.dans(t) or not g.decouvert.has(g.idx(t)):
				continue
			_dessine_tuile(ci, t)
	_lot_fermer(ci)


## Le mur sud ou est du bâtiment où se tient le joueur (designer 2026-09-06, 16 h 30 : « quand on rentre dans un bâtiment,
## fais en sorte qu'on ne voie pas les murs sud et est ») : ces deux murs sont devant la pièce, entre elle et l'œil ;
## ils se dessinent en muret (MUR_COUPE_UNITES), le toit est déjà ôté. Les murs nord et ouest, derrière, restent entiers.
func _mur_coupe(g: Grille, t: Vector2i) -> bool:
	if _bat_joueur <= 0 or not g.dans(t):
		return false
	var idx_t := g.idx(t)
	if int(g.bat_de[idx_t]) != _bat_joueur:
		return false
	var r: Rect2i = g.batiments_liste[_bat_joueur - 1].rect
	return t.y == r.end.y - 1 or t.x == r.end.x - 1


## Le joueur change de bâtiment (entre, sort) : les murs coupés changent, l'emprise de l'ancien et du nouveau se redessinent.
func _maj_batiment_joueur(j: Dictionary) -> void:
	var b := _batiment_de(j.pos) if not j.is_empty() else 0
	if b == _bat_joueur:
		return
	var g := sim.grille
	for k in [_bat_joueur, b]:
		if k > 0 and k <= g.batiments_liste.size():
			var r: Rect2i = g.batiments_liste[k - 1].rect
			for y in r.size.y:
				_salir_tuile(r.position + Vector2i(r.size.x - 1, y))
			for x in r.size.x:
				_salir_tuile(r.position + Vector2i(x, r.size.y - 1))
	_bat_joueur = b
	etage.queue_redraw()
	for n in noeuds.values():   # ses occulteurs redessinent le mur coupé
		if n.occulteurs != null:
			n.occulteurs.queue_redraw()


## Sous le toit d'un autre bâtiment que celui du joueur : ni dessiné, ni au HUD.
func _sous_toit_cache(t: Vector2i, j: Dictionary) -> bool:
	var b := _batiment_de(t)
	return b > 0 and (j.is_empty() or b != _batiment_de(j.pos) or Grille.z_de(t) != Grille.z_de(j.pos))   # un autre étage du même bâtiment : caché aussi


## Les toits (Villes, 2026-09-06) : sur chaque tuile découverte de l'emprise d'un bâtiment — murs compris, pour que
## rien ne dépasse —, un losange plat à la hauteur du haut des murs, à la couleur du matériau de toit ; le bâtiment
## du joueur reste à ciel ouvert ; hors du champ de vue, le toit mémorisé est sombre comme un mur mémorisé.
func _dessiner_toits(ci: CanvasItem) -> void:
	if sim == null or profil_sans_terrain:
		return
	var g := sim.grille
	if g.batiments_liste.is_empty():
		return
	var j := joueur()
	if j.is_empty():
		return
	# Les toits en tableaux de triangles (file 114) : le noyau C++ (SensenGrille.toits) ou PassesGD.toits, les mêmes ; le client
	# passe la couleur et le grain du toit de chaque bâtiment, le soleil, la pente (villes.json → toits).
	var bat_j := _batiment_de(j.pos)
	var couleurs := {}   # matériau de toit → [couleur, style de grain]
	var bat_couleurs := PackedColorArray()
	var bat_styles := PackedFloat32Array()
	for info in g.batiments_liste:
		var mat := str(info.get("toit", ""))
		if not couleurs.has(mat):
			couleurs[mat] = [Color.html(str(GameData.catalogues.materials.get(mat, {}).get("color", "#b89a55"))), _style_grain(mat)]
		bat_couleurs.append(couleurs[mat][0])
		bat_styles.append(couleurs[mat][1])
	var cfg_t: Dictionary = GameData.config("villes").get("toits", {})
	var pente_t := maxf(0.5, float(cfg_t.get("pente_tuiles", 1.0)))
	var haut_toit := float(cfg_t.get("hauteur_blocs", 1.0)) * BLOC_UNITES * HSTEP
	var ombre_min := float(GameData.config("planete").get("cycle", {}).get("soleil", {}).get("ombre_min", 0.72))
	var soleil_h := Vector2(_soleil_dir.x, _soleil_dir.y)
	var soleil_ok := _soleil_force > 0.0 and soleil_h.length() > 0.001
	if soleil_ok:
		soleil_h = soleil_h.normalized()
	var jp := Grille.plat(j.pos)
	var vue: Dictionary = j.get("vue", {})
	var tout_vu := not j.has("vue")
	var zj := Grille.z_de(j.pos)
	var vide_ci := g.contenu_ids.find("vide")
	var res: Dictionary
	var t0 := Time.get_ticks_usec()
	var st_br: Dictionary = GameData.config("styles").get("brouillard", {})
	var sombre_jamais := float(st_br.get("toit_jamais_vu", 0.75))
	var sombre_memorise := float(st_br.get("toit_memorise", 0.55))   # le toit vu jadis, hors de vue maintenant
	if g.noyau_actif and g._noyau_pret():
		res = g._noyau.toits(g, vue, tout_vu, zj, vide_ci, jp, rayon_vue, origine_dessin, float(TW), float(TH), float(HSTEP), NIVEAU_BLOCS * BLOC_UNITES, bat_j, bat_couleurs, bat_styles, pente_t, haut_toit, ombre_min, soleil_h, soleil_ok, _soleil_force, float(UV_HAUT), sombre_jamais, sombre_memorise)
	else:
		res = PassesGD.toits(g, vue, tout_vu, zj, vide_ci, jp, rayon_vue, origine_dessin, float(TW), float(TH), float(HSTEP), NIVEAU_BLOCS * BLOC_UNITES, bat_j, bat_couleurs, bat_styles, pente_t, haut_toit, ombre_min, soleil_h, soleil_ok, _soleil_force, float(UV_HAUT), sombre_jamais, sombre_memorise)
	_top_client("toits.tableaux", t0)
	if res.points.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), res.indices, res.points, res.couleurs, res.uvs)


## La couche d'interface : barres, garde, télégraphe et jauge de chaîne de chaque être.
## Les états au-dessus des êtres en vue (Écrans d'interface, 2026-08-30) : une puce par statut, teintée, l'initiale
## dedans, les ticks restants dessous.
func _dessiner_etats(ci: CanvasItem) -> void:
	var j := joueur()
	if sim == null or j.is_empty() or titre_ouvert:
		return
	if _vivants_image.size() != _visibles_image.size():
		_calculer_visibles(j)
	for ke in _vivants_image.size():
		var e: Dictionary = _vivants_image[ke]
		var statuts: Array = e.get("statuts", [])
		if statuts.is_empty():
			continue
		if e.id != j.id and (_visibles_image[ke] & 1) == 0:
			continue
		var tick_e: int = sim.tick_de(e)
		var base := _ecran(e.pos, sim.grille.h(e.pos)) + Vector2(-7.0 * mini(4, statuts.size()), -62.0)   # au-dessus de la tête
		var n_s := 0
		for st in statuts:
			if n_s >= 4:
				break
			var d_s: Dictionary = sim.statuts_defs.get(str(st.id), {})
			var tags: Array = d_s.get("tags", [])
			var c_s := Color(0.75, 0.45, 0.95) if ("controle" in tags or bool(d_s.get("controle", false))) else (Color(0.9, 0.3, 0.3) if "negatif" in tags else Color(0.35, 0.8, 0.45))
			var p_s := base + Vector2(n_s * 14.0, 0.0)
			ci.draw_rect(Rect2(p_s, Vector2(11, 11)), Color(c_s.r * 0.3, c_s.g * 0.3, c_s.b * 0.3, 0.95))
			ci.draw_rect(Rect2(p_s, Vector2(11, 11)), c_s, false, 1.0)
			ci.draw_string(ThemeDB.fallback_font, p_s + Vector2(2.0, 9.0), tr(str(d_s.get("name_key", st.id))).left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c_s)
			var reste: int = maxi(0, int(st.get("fin", 0)) - tick_e)
			ci.draw_string(ThemeDB.fallback_font, p_s + Vector2(-1.0, 20.0), ("%dk" % (reste / 1000)) if reste >= 1000 else str(reste), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.8, 0.8, 0.75))
			n_s += 1


func _dessiner_hud(ci: CanvasItem) -> void:
	_dessiner_bulle(ci)
	_dessiner_etats(ci)
	if sim != null:
		for f in gros_flottants:   # CRITIQUE / RATÉ en gros, qui montent et s'effacent (Écrans d'interface)
			if not sim.grille.dans(f.pos):
				continue
			var pg := _ecran(f.pos, sim.grille.h(f.pos)) + Vector2(-36.0, -66.0 - f.t * 30.0)
			var ag: float = clampf(1.2 - f.t, 0.0, 1.0)
			var cg: Color = f.couleur
			ci.draw_string(ThemeDB.fallback_font, pg + Vector2(1, 1), str(f.texte), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, ag))
			ci.draw_string(ThemeDB.fallback_font, pg, str(f.texte), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(cg.r, cg.g, cg.b, ag))
	if sim == null:
		return
	var j := joueur()
	if _vivants_image.size() != _visibles_image.size():
		_calculer_visibles(j)
	for ke in _vivants_image.size():   # seulement ce qui est à l'écran : une cité en compte deux cents (designer 2026-09-05, le lag)
		if j.is_empty() or (_visibles_image[ke] & 2) != 0:
			_dessine_hud_entite(ci, _vivants_image[ke])


func _dessine_hud_entite(ci: CanvasItem, e: Dictionary) -> void:
	var c := _ecran(e.pos, sim.grille.h(e.pos))
	if e.garde:   # la garde : un arc devant l'orientation
		var o := Vector2(e.orientation.x - e.orientation.y, (e.orientation.x + e.orientation.y) * 0.5).normalized()
		ci.draw_arc(c + Vector2(0, -10), 16.0, o.angle() - 0.9, o.angle() + 0.9, 8, Color(0.6, 0.85, 1.0), 2.0)
	if telegraphes.has(e.id):   # intention visible : le télégraphe est une information d'interface
		ci.draw_string(ThemeDB.fallback_font, c + Vector2(-4, -40), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.3, 0.2))
	# Plus de barres ni de jauge de chaîne sous les personnages (designer, 2026-08-30) : la bulle au survol et le pentagramme du HUD les disent.


## Les segments effectifs d'une jauge à l'instant présent (décroissance calculée, sans la modifier).
func _segments(e: Dictionary) -> Array:
	var copie: Dictionary = e.chaine.duplicate(true)
	sim.wuxing.decroitre(copie, sim.horloge_de(e).ticks)
	return copie.segments


# ---------------------------------------------------------------- UI texte

func _maj_ui() -> void:
	var j := joueur()
	var g := sim.grille
	var titre: String = tr("ui.camp").format({"biome": tr(str(GameData.catalogues.biomes.get(str(sim.camp_sauve.get("biome", "plaine_temperee")), {}).get("name_key", "")))}) if sim.lieu == "camp" else (tr(GameData.entree("prototype_arenas", arene_banc if not arene_banc.is_empty() else arenes[arene_courante]).name_key) if sim.donjon.is_empty() else (tr("ui.mine").format({"etage": sim.donjon.etage}) if bool(sim.donjon.get("mine", false)) else tr("ui.donjon").format({"theme": tr(GameData.entree("dungeon_themes", sim.donjon.theme).name_key), "etage": sim.donjon.etage, "etages": sim.donjon.etages, "salles": sim.donjon.salles})))
	var lignes: Array[String] = [tr("ui.titre") + " · " + titre]
	var mode := tr("ui.mode.combat") if sim.en_combat(j) else ((tr("ui.mode.mine") if bool(sim.donjon.get("mine", false)) else tr("ui.mode.donjon")) if sim.horloge_monde.mode == Horloge.Mode.ACTION else tr("ui.mode.exploration").format({"tps": sim.regles.r.ticks_par_seconde_exploration}))
	if sim.lieu == "donjon" and bool(sim.donjon.get("corrompu", false)):   # le donjon corrompu dit sa difficulté (point 61)
		mode += tr("ui.mode.donjon_corrompu").format({"n": int(sim.donjon.get("niveau", 1)), "corruption": roundi(float(sim.donjon.get("corruption", 0.0)))})
	lignes.append(tr("ui.horloge").format({"horloge": sim.horloge_de(j).ticks, "mode": mode}))
	var proches := sim.vivants().filter(func(e: Dictionary) -> bool: return e.id == joueur_id or (Grille.distance_plate(e.pos, j.pos) <= 12 and sim.voit(j, e.pos)))
	proches = proches.slice(0, 10)   # les êtres en vue seulement : l'écran n'est pas un registre
	for e in proches:
		lignes.append("  " + tr("ui.entite.ligne").format({"nom": tr(e.name_key) + ((" " + tr(e.epithete)) if e.get("rare", false) else ""), "pv": e.sante, "pv_max": e.sante_max,
			"end": e.vigueur, "compteur": e.compteur, "h": g.h(e.pos)}) + (" · GARDE" if e.garde else "")
			+ (" · " + tr(sim.items[e.equipement.main_principale].name_key) if e.equipement.has("main_principale") else "")
			+ (" + " + tr(sim.items[e.equipement.main_secondaire].name_key) if e.equipement.has("main_secondaire") else "")
			+ (" · " + _texte_chaine(e) if e.has("chaine") else "")
			+ (tr("ui.segment_prefere").format({"element": tr("element." + str(e.segment_prefere))}) if e.has("segment_prefere") else "")
			+ (tr("ui.souffle").format({"n": int(e.get("souffle", 0)), "max": sim.souffle_max(e)}) if sim.dans_l_eau(e.pos) else "")
			+ (tr("ui.etat_grille_neige") if sim.grille.neige else "") + (tr("ui.etat_grille_gel") if sim.grille.gel else "")
			+ (tr("ui.sang").format({"n": int(e.get("sang", 0))}) if sim.a_talent(e, "jauge_de_sang") else "")
			+ (" · " + _texte_statuts(e) if not e.statuts.is_empty() else ""))
	if survol.x >= 0 and g.dans(survol) and not j.is_empty():
		var cl := _coord_locale(survol)
		lignes.append("  " + tr("ui.case").format({"x": cl.x, "y": cl.y, "h": g.h(survol), "dh": g.h(survol) - g.h(j.pos)}))
		var occ := g.occupant(survol)
		if not occ.is_empty() and occ != joueur_id and j.vivant:
			lignes.append_array(_preview(j, sim.entites[occ]))
		# Une tombe nommée dit qui elle abrite (Villes — les repères, 2026-09-07) : la seule trace qu'un jeu garde
		# d'un habitant qu'on a croisé.
		if sim.lieu == "camp" and str(g.meubles.get(g.idx(survol), "")) == "tombe":
			var ep: Dictionary = SimVilles.epitaphe(sim, survol)
			if not ep.is_empty():
				lignes.append("  " + tr("ui.tombe").format({"nom": str(ep.nom), "metier": tr("function.%s.name" % str(ep.get("fonction", "oisif"))), "an": int(ep.get("an", 0))}))
	if not j.is_empty():
		if sim.lieu == "camp" and sim.monde != null:
			var tr_: Dictionary = sim.temperature_ressentie(j)
			lignes.append("  " + tr("ui.date").format({"date": Calendrier.texte(sim.date_courante())}))   # la date du calendrier (Un monde réel — A)
			lignes.append("  " + tr("ui.heure").format({"heure": "%02d:%02d" % [int(sim.heure()), int(fmod(sim.heure(), 1.0) * 60.0)], "phase": tr("phase." + sim.phase()), "saison": tr("saison." + sim.saison()),
				"meteo": tr(GameData.entree("weather_states", str(tr_.meteo)).name_key), "temp": "%.0f" % float(tr_.temp),
				"confort": tr("ui.confort.froid") if float(tr_.ecart) < 0.0 else (tr("ui.confort.chaud") if float(tr_.ecart) > 0.0 else "")}))
			if not sim.territoire.get("raid", {}).is_empty():   # Défense et raids : le raid en cours se lit
				var raid: Dictionary = sim.territoire.raid
				var vivants_raid := 0
				var dmin := 9999
				for x in sim.vivants():
					if x.camp == "raid":
						vivants_raid += 1
						dmin = mini(dmin, Grille.distance(j.pos, x.pos))
				lignes.append("  " + tr("ui.raid").format({"n": vivants_raid, "dist": dmin if dmin < 9999 else 0, "ticks": maxi(0, int(raid.get("fin", 0)) - sim.horloge_monde.ticks)}))
			var vl := sim.vecteur_lieu(j.pos)   # le lieu (Wu Xing hors combat) : ses deux éléments dominants
			if not vl.is_empty():
				var cles: Array = vl.keys()
				cles.sort_custom(func(p: String, q: String) -> bool: return float(vl[p]) > float(vl[q]))
				lignes.append("  " + tr("ui.lieu").format({"a": tr("element." + str(cles[0])), "pa": roundi(float(vl[cles[0]]) * 100.0), "b": tr("element." + str(cles[1])), "pb": roundi(float(vl[cles[1]]) * 100.0)}))
		var pd: Dictionary = sim.poids_de(j)
		lignes.append("  " + tr("ui.entite.mana").format({"mana": j.mana, "mana_max": j.mana_max}) + " · " + tr("ui.munitions").format({"n": j.munitions}) + " · " + tr("ui.modules_connus").format({"n": j.modules_connus.size()})
			+ " · " + tr("ui.or").format({"n": int(j.get("or", 0))}) + " · " + tr("ui.faim").format({"faim": int(j.get("faim", 100))}) + " · " + tr("ui.soif").format({"soif": int(j.get("soif", 100))}) + " · " + tr("ui.poids").format({"poids": "%.0f" % pd.poids, "capacite": "%.0f" % pd.capacite, "surcharge": tr("ui.poids.surcharge").format({"facteur": "%.1f" % pd.facteur}) if pd.facteur > 1.0 else ""}))
		var nd := sim.progression.niveaux_derives(j)
		lignes.append("  " + tr("ui.niveaux").format({"combat": "%.1f" % nd.combat, "general": "%.1f" % nd.general}))
		# LA RÉPUTATION À L'ÉCRAN (ordre de travail 38, 2026-09-09) : village, royaume, globale — et ce que les
		# FACTIONS en pensent, qui était jusqu'ici entièrement invisible, sauf par le ton d'un PNJ.
		var rep_txt := _texte_reputation(j)
		if not rep_txt.is_empty():
			lignes.append("  " + rep_txt)
		var hb: Array[String] = []
		var ent := hotbar_entrees(j)
		for k in ent.size():
			var ch: String = str((k + 1) % 10)
			hb.append(tr("ui.hotbar.selection").format({"k": ch, "nom": ent[k].nom}) if k == hotbar_sel else "%s %s" % [ch, ent[k].nom])
		lignes.append("  " + tr("ui.hotbar").format({"liste": " · ".join(hb)}))
		# LE COÛT DE CE QU'ON S'APPRÊTE À LANCER (ordre de travail 37, 2026-09-09). Le déficit se paie en points de
		# vie, et c'est écrit dans les règles depuis longtemps — mais le joueur ne l'apprenait qu'APRÈS, par une
		# ligne de journal, une fois les PV partis. *Un coût qu'on découvre en le payant n'est pas un coût, c'est
		# une punition.*
		if hotbar_sel < ent.size() and str(ent[hotbar_sel].get("type", "")) == "capacite":
			var cout_txt := _texte_cout_capacite(j, sim.plan_capacite(j, int(ent[hotbar_sel].ref)))
			if not cout_txt.is_empty():
				lignes.append("  " + cout_txt)
		if visee >= 0:
			var plan := sim.plan_capacite(j, visee)
			lignes.append("  " + tr("ui.capacite.visee").format({"nom": tr(plan.name_key)}))
			if survol.x >= 0 and sim.plan_par_tuile(plan) and sim.capacite_visable(j, plan, survol):   # le prix de cette visée-là
				var n_t: int = sim.tuiles_du_plan(j, plan, survol).size()
				var fc_v: Vector2i = sim.fourchette_cout(plan)
				lignes.append("  " + tr("ui.capacite.surface").format({"n": n_t, "min": fc_v.x * n_t, "max": fc_v.y * n_t, "monnaie": tr("monnaie." + str(plan.get("monnaie", "")))}))
			if survol.x >= 0 and not g.occupant(survol).is_empty():
				lignes.append("  " + _preview_capacite(j, plan, sim.entites[g.occupant(survol)]))
	ui.text = "\n".join(lignes)
	var bas: Array[String] = []
	if not j.is_empty() and not j.sac.is_empty() and (volet == null or not volet.visible):   # l'inventaire est dans le volet quand il est affiché
		var objets: Array[String] = []
		for k in mini(9, j.sac.size()):
			var it_k: Dictionary = sim.items[j.sac[k]]
			var nom_k := nom_objet(sim.nom_objet(j.sac[k]))
			if it_k.get("type", "") == "materiau":
				nom_k = tr("forme." + str(it_k.get("forme", "brut"))).format({"materiau": nom_k}) + " ×%d" % int(it_k.quantite)
			objets.append(nom_k)
		bas.append(tr("ui.sac").format({"liste": " · ".join(objets)}))
	if not ecran_fin.is_empty():
		bas.append_array(ecran_fin)
		bas.append("")
	if volet == null or not volet.visible:   # le journal est dans le volet quand il est affiché
		bas.append_array(journal)
	if not j.vivant:
		bas.append(tr("journal.defaite"))
	ui_bas.text = "\n".join(bas)
	ui_droite.text = ""   # la timeline est graphique (HudEcran._dessiner_timeline, Écrans d'interface)


## La bulle au survol, dessinée dans la couche HUD (au-dessus des blocs et des êtres) — rien ne la recouvre.
func _dessiner_bulle(ci: CanvasItem) -> void:
	var j := joueur()
	if sim == null or j.is_empty() or survol.x < 0 or ecrans.est_ouvert() or titre_ouvert:
		return
	var g := sim.grille
	var occ := g.occupant(survol)
	if occ.is_empty() or occ == joueur_id or not sim.entites.has(occ) or not sim.entites[occ].vivant or not sim.voit(j, survol):
		return
	var cible: Dictionary = sim.entites[occ]
	var lignes_b := _lignes_bulle(j, cible)
	var larg := 0.0
	for l in lignes_b:
		larg = minf(420.0, maxf(larg, ThemeDB.fallback_font.get_string_size(str(l), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0))   # 420 px au plus
	var haut := 14.0 * lignes_b.size() + 8.0
	# EN PIXELS D'ÉCRAN, PAS EN COORDONNÉES DU MONDE (designer 2026-09-08 : « les noms de PNJ ne s'affichent plus »).
	# La couche `Hud` est un enfant de la scène : elle hérite du zoom et du recentrage de la caméra. Le bornage posé
	# le 2026-09-05 comparait ces coordonnées-là à `get_viewport_rect()`, qui est en pixels d'écran — deux espaces
	# sans rapport. Sur une grille de ville, la bulle était rabattue vers l'origine de dessin, à des milliers de
	# pixels du joueur ; en arène, où l'origine est sous les pieds du joueur, l'erreur ne se voyait pas.
	# On passe donc dans l'espace de l'écran pour placer ET pour dessiner : la bulle ne grossit plus avec le zoom.
	var vers_ecran := ci.get_global_transform_with_canvas()
	var ancre := vers_ecran * _ecran(cible.pos, g.h(cible.pos))
	var pb := ancre + Vector2(-larg * 0.5 - 6.0, -70.0 - haut)
	# La bulle ne recouvre ni le bloc d'information du haut ni le volet, et ne sort pas de l'écran (Écrans d'interface,
	# 2026-09-05) : quand elle n'a pas la place au-dessus de l'être, elle passe dessous.
	var ecran_l := get_viewport_rect().size
	var bas_info := ui.position.y + ui.get_combined_minimum_size().y + 6.0
	if pb.y < bas_info and pb.x < ui.position.x + ui.size.x:
		pb.y = ancre.y + 24.0
	var droite := ecran_l.x - ((volet.largeur) if volet != null and volet.visible else 0.0)
	pb.x = clampf(pb.x, 6.0, maxf(6.0, droite - larg - 18.0))
	pb.y = clampf(pb.y, 6.0, maxf(6.0, ecran_l.y - haut - 6.0))
	ci.draw_set_transform_matrix(vers_ecran.affine_inverse())   # ce qui suit s'écrit en pixels d'écran
	ci.draw_rect(Rect2(pb, Vector2(larg + 12.0, haut)), Color(0.05, 0.05, 0.08, 0.9))
	ci.draw_rect(Rect2(pb, Vector2(larg + 12.0, haut)), Color(0.9, 0.3, 0.25) if sim.ennemis(j, cible) else Color(0.35, 0.8, 0.45), false, 1.0)
	for k in lignes_b.size():
		ci.draw_string(ThemeDB.fallback_font, pb + Vector2(6.0, 14.0 * (k + 1) - 2.0), str(lignes_b[k]), HORIZONTAL_ALIGNMENT_LEFT, larg + 2.0, 11, Color(0.95, 0.95, 0.9) if k > 0 else Color(1.0, 0.9, 0.6))   # bornée au cadre
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)   # la suite du HUD reste ancrée au monde


## La bulle au survol d'une cible (Écrans d'interface, 2026-08-30) : PV, fourchette de l'arme, résistance Wu Xing, armure.
func _lignes_bulle(j: Dictionary, cible: Dictionary) -> Array[String]:
	var res: Array[String] = [tr("ui.bulle.pv").format({"nom": tr(cible.name_key), "pv": int(cible.sante), "max": int(cible.sante_max)})]
	var arme := Etres.arme(j, sim.items)
	if not arme.is_empty():
		var fonct: Dictionary = sim.fonctionnalites[arme.functionality]
		var zone: Dictionary = sim.regles.zone_de_coup(g_h(j.pos), g_h(cible.pos))
		var piece := Etres.piece_zone(cible, zone.zone, sim.items)
		var armure := sim.regles.armure_piece(piece, fonct.type_degats)
		var a_zero: bool = j.vigueur <= 0
		var vecteur := sim.vecteur_arme(arme)
		var wx: Dictionary = sim._facteur_wuxing(j, cible, vecteur, sim.horloge_de(j).ticks)
		var f := sim.regles.fourchette_arme(j.stats_eff, arme, fonct, false, zone.mult, armure, a_zero, wx.total, j.competences_eff, vecteur)
		var fl := sim.regles.fourchette_arme(j.stats_eff, arme, fonct, true, zone.mult, armure, a_zero, wx.total, j.competences_eff, vecteur)
		res.append(tr("ui.bulle.arme").format({"min": f.x, "max": f.y, "lmin": fl.x, "lmax": fl.y}))
		if not vecteur.is_empty():
			var el_c: Dictionary = cible.get("elements", {}) if cible.get("elements") is Dictionary else {}
			res.append(tr("ui.bulle.wuxing").format({"element": tr("element." + sim.wuxing.dominante(vecteur)), "cible": tr("element." + sim.wuxing.dominante(el_c)) if not el_c.is_empty() else "—", "dom": "%.2f" % wx.dom}))
		res.append(tr("ui.bulle.armure").format({"zone": tr("zone." + str(zone.zone)), "armure": "%.1f" % armure, "mult": "%.2f" % zone.mult}))
	if visee >= 0:
		var plan := sim.plan_capacite(j, visee)
		if not plan.is_empty() and plan.erreurs.is_empty():
			res.append(_preview_capacite(j, plan, cible))
	return res


## Prévisualisation des dégâts avec le détail du calcul (la lisibilité est le but).
func _preview(j: Dictionary, cible: Dictionary) -> Array[String]:
	var res: Array[String] = []
	var arme := Etres.arme(j, sim.items)
	if arme.is_empty():
		return res
	var fonct: Dictionary = sim.fonctionnalites[arme.functionality]
	var zone: Dictionary = sim.regles.zone_de_coup(g_h(j.pos), g_h(cible.pos))
	var piece := Etres.piece_zone(cible, zone.zone, sim.items)
	var armure := sim.regles.armure_piece(piece, fonct.type_degats)
	var a_zero: bool = j.vigueur <= 0
	var vecteur := sim.vecteur_arme(arme)
	var wx: Dictionary = sim._facteur_wuxing(j, cible, vecteur, sim.horloge_de(j).ticks)
	var f := sim.regles.fourchette_arme(j.stats_eff, arme, fonct, false, zone.mult, armure, a_zero, wx.total, j.competences_eff, vecteur)
	var stat := int(j.stats_eff.force) / int(sim.regles.r.degats.stat_div)
	res.append("  " + tr("ui.preview").format({"nom": tr(arme.name_key), "des": fonct.degats_des,
		"dur": "%.2f" % (float(arme.durete_base) / float(sim.regles.r.degats.durete_reference) * float(arme.qualite)),
		"stat": stat, "zone": zone.zone, "mult": zone.mult, "armure": "%.1f" % armure,
		"min": f.x, "max": f.y, "ticks": sim.regles.ticks_attaque(fonct, false, arme)}))
	var fl := sim.regles.fourchette_arme(j.stats_eff, arme, fonct, true, zone.mult, armure, a_zero, wx.total, j.competences_eff, vecteur)
	res.append("  " + tr("ui.preview.lourde").format({"lourde": "%d–%d" % [fl.x, fl.y], "ticks": sim.regles.ticks_attaque(fonct, true, arme)}))
	if not vecteur.is_empty():
		var contre: Array[String] = []
		for k in wx.contre.keys():
			contre.append("%s %d%%" % [tr("element." + k), roundi(float(wx.contre[k]) * 100.0)])
		var prev: Dictionary = wx.prevision
		res.append("  " + tr("ui.wuxing").format({"element": tr("element." + sim.wuxing.dominante(vecteur)),
			"contre": " ".join(contre) if not contre.is_empty() else "—", "dom": "%.2f" % wx.dom,
			"segments": _segments(j).size() if j.has("chaine") else 0, "capacite": j.chaine.capacite if j.has("chaine") else 0,
			"gain": "%.2f" % wx.gain, "position": prev.get("position", 0),
			"transition": "(+%.2f)" % prev.get("transition", 0.0), "chaine": ("RÉSOUT ×%.2f" % prev.multiplicateur) if prev.get("resout", false) else "%.2f" % wx.chaine}))
	if not sim.regles.a_portee(fonct, Grille.distance(j.pos, cible.pos)) or not sim.grille.ligne_de_vue(j.pos, cible.pos):
		res.append("  (hors de portée ou hors de vue)")
	return res


func g_h(p: Vector2i) -> int:
	return sim.grille.h(p)


## CE QUE COÛTE LA CAPACITÉ CHOISIE, ET CE QU'ELLE COÛTERA EN PLUS (ordre de travail 37, 2026-09-09).
## Les règles disent depuis longtemps que le déficit se paie en points de vie — mana en surchauffe, endurance en
## épuisement, sang-froid rompu. Le joueur, lui, ne l'apprenait qu'après coup, par une ligne de journal que le
## panneau recouvre. **Il le lit maintenant avant de lancer**, et c'est toute la ligne.
func _texte_cout_capacite(j: Dictionary, plan: Dictionary) -> String:
	var monnaie := str(plan.get("monnaie", ""))
	var cout := int(plan.get("ressource", 0))
	if monnaie.is_empty() or cout <= 0:
		return ""
	var reserve := 0
	var mult := 0.0
	match monnaie:
		"mana":
			reserve = int(j.get("mana", 0))
			mult = float(sim.regles.r.mana.get("surchauffe_mult", 2))
		"vigueur":
			reserve = int(j.get("vigueur", 0))
			mult = float(sim.regles.r.vigueur.get("epuisement_mult", 1))
		"sang_froid":
			reserve = int(j.get("sang_froid", 0))
			mult = float(sim.regles.r.get("sang_froid", {}).get("epuisement_mult", 2))
		_:
			return ""
	var txt := tr("ui.cout.capacite").format({"n": cout, "monnaie": tr("monnaie." + monnaie), "reserve": reserve})
	var deficit := maxi(0, cout - reserve)
	if deficit > 0:
		txt += tr("ui.cout.deficit").format({"n": deficit, "pv": maxi(1, roundi(float(deficit) * mult))})
	return txt


## LA RÉPUTATION, EN UNE LIGNE (ordre de travail 38, 2026-09-09) : le village où l'on se tient, son royaume, la
## réputation globale — et **ce que les factions en pensent**, qui n'existait à l'écran nulle part. La rumeur du
## 2026-09-09 était audible par le ton d'un PNJ ; elle a maintenant son chiffre.
func _texte_reputation(j: Dictionary) -> String:
	var reps: Dictionary = j.get("reputations", {})
	var bouts: Array[String] = []
	var vil: Dictionary = sim.village_a(j.pos) if sim.lieu == "camp" and sim.monde != null else {}
	var nom_v := str(vil.get("nom", ""))
	if not nom_v.is_empty() and reps.has(nom_v):
		bouts.append(tr("ui.reputation.village").format({"nom": nom_v, "n": int(reps[nom_v])}))
	if sim.monde != null:
		var roy: Dictionary = sim.monde.surface.royaume_de(sim._cell_de(j.pos))
		if not roy.is_empty():
			var op := SimRumeur.opinion_royaume(sim, roy, j)
			bouts.append(tr("ui.reputation.royaume").format({"nom": str(roy.get("nom", roy.get("id", ""))), "n": int(reps.get(str(roy.get("id", "")), 0)) + op}))
	bouts.append(tr("ui.reputation.globale").format({"n": int(reps.get("_globale", 0))}))
	# CE QUE LES FACTIONS EN PENSENT : seules celles qui ont un avis se montrent, sans quoi la ligne serait un mur
	# de zéros. C'est la rumeur du soir qui devient lisible.
	if sim.monde != null and not (sim.monde.faits as Array).is_empty():
		var cell := sim._cell_de(j.pos)
		var av: Array[String] = []
		for fid: String in GameData.catalogues.get("factions", {}).keys():
			var v := SimRumeur.reputation(sim, fid, str(j.id), cell, sim.horloge_monde.ticks)
			if v != 0:
				av.append("%s %+d" % [tr(GameData.entree("factions", fid).get("name_key", fid)), v])
		if not av.is_empty():
			bouts.append(tr("ui.reputation.factions").format({"liste": " · ".join(av)}))
	return tr("ui.reputation").format({"liste": " · ".join(bouts)})


## L'infobulle exhaustive d'une capacité : forme, portée, coûts, dés — calculés pour le porteur.
func _texte_capacite(j: Dictionary, k: int) -> String:
	var plan := sim.plan_capacite(j, k)
	var mods: Array[String] = []
	for m in plan.modules:
		mods.append(tr(sim.capacites.modules.get(m, {}).get("name_key", m)))
	return tr("ui.capacite").format({"touche": "F%d" % (k + 1), "nom": tr(plan.name_key), "modules": " + ".join(mods),
		"forme": plan.geometrie, "pmin": plan.portee.x, "pmax": plan.portee.y, "taille": plan.taille,
		"ticks": plan.ticks, "ressource": plan.ressource, "monnaie": plan.monnaie if not plan.monnaie.is_empty() else "—",
		"des": str(plan.des) if plan.des != null else "—", "bonus": (" +%d dé(s)" % plan.des_bonus) if plan.des_bonus > 0 else ""}) \
		+ ((" → " + tr(plan.charge_suivante.name_key) + " : " + tr(plan.charge_suivante.noyau.get("name_key", ""))) if not plan.charge_suivante.is_empty() else "")


func _preview_capacite(j: Dictionary, plan: Dictionary, cible: Dictionary) -> String:
	if not ("degats" in plan.effets):
		return ""
	var zone: Dictionary = sim.regles.zone_de_coup(g_h(j.pos), g_h(cible.pos))
	var dom: Dictionary = sim.multiplicateur_domination(plan.elements, cible, zone.zone)
	var piece := Etres.piece_zone(cible, zone.zone, sim.items)
	var arme_noyau: bool = plan.noyau.get("power_base") == "arme"
	var armure := 0.0
	if not plan.drapeaux.get("ignore_armure", false):
		armure = sim.regles.armure_piece(piece, str(plan.fonct.get("type_degats", "contondant")) if arme_noyau else "contondant")
		if not arme_noyau:
			armure *= float(sim.regles.r.armure.magie_facteur)
	var f := Des.fourchette(plan.des, int(plan.des_bonus))
	var k: float = float(dom.mult) * float(plan.mult)
	if j.has("chaine") and not plan.elements.is_empty():
		var prev: Dictionary = sim.wuxing.prevoir(j.chaine, sim.wuxing.dominante(plan.elements))
		k *= float(prev.gain) * float(prev.multiplicateur)
	return tr("ui.capacite.preview").format({"nom": tr(plan.name_key), "def": tr(cible.name_key), "des": str(plan.des),
		"bonus": (" +%d dé(s)" % plan.des_bonus) if plan.des_bonus > 0 else "", "dom": "%.2f" % dom.mult,
		"zone": zone.zone, "mult": zone.mult, "armure": "%.1f" % armure,
		"min": sim.regles.degats_finaux(f.x * k, zone.mult, armure, false), "max": sim.regles.degats_finaux(f.y * k, zone.mult, armure, false)})


func _texte_statuts(e: Dictionary) -> String:
	var noms: Array[String] = []
	var tick := sim.horloge_de(e).ticks
	for s in e.statuts:
		noms.append("%s (%d)" % [tr(sim.statuts_defs.get(s.id, {}).get("name_key", s.id)), int(s.fin) - tick])
	return tr("ui.statuts").format({"liste": ", ".join(noms)})


## Le jalon « ressortir » : l'écran d'expédition.
func _sur_fin_d_expedition(recap: Dictionary) -> void:
	ecran_fin = [tr("ui.expedition.titre").format({"theme": tr(GameData.entree("dungeon_themes", recap.theme).name_key)}),
		tr("ui.expedition.ligne").format({"etage_max": recap.etage_max, "tues": recap.tues, "objets": recap.objets, "sac": recap.sac,
			"boss": tr("ui.fin.victoire") if recap.boss_vaincu else "—", "combat": "%.1f" % recap.niveaux.combat, "general": "%.1f" % recap.niveaux.general}),
		tr("ui.fin.suite")]


## Écran de fin de combat : issue, durée en ticks, XP des trois pistes et de l'armure (XP de combat).
func _sur_fin_de_combat(_nom: String) -> void:
	telegraphes.clear()
	var j := joueur()
	var dc: Dictionary = sim.dernier_combat
	if j.is_empty() or dc.is_empty():
		return
	# Un combat où le joueur n'a rien fait n'a pas de récapitulatif à montrer (designer, point 13) :
	# une bête qui engage puis se désengage pendant le sommeil affichait « victoire en 0 ticks », pistes vides.
	var vide := int(dc.get("ticks", 0)) <= int(GameData.config("combat_rules").get("fin_combat", {}).get("ticks_min", 1))
	for piste_v in j.xp.keys():
		if not j.xp[piste_v].is_empty():
			vide = false
	if vide and dc.get("niveaux", []).is_empty():
		return
	ecran_fin = [tr("ui.fin.titre").format({"issue": tr("ui.fin.victoire") if dc.victoire else tr("ui.fin.defaite"), "ticks": dc.ticks})]
	for piste in ["element", "competence", "type", "construction"]:
		if j.xp[piste].is_empty():
			continue   # une piste vide ne dit rien (elle affichait « — »)
		var parts: Array[String] = []
		for k in j.xp[piste].keys():
			var nom := str(k)   # les identifiants bruts (« plaque », « epee ») passent par leur clé (XP de combat, 2026-09-04)
			match piste:
				"element":
					nom = tr("element." + str(k))
				"competence", "type":
					nom = tr(sim._nom_competence(str(k)))
				"construction":
					var ck := "construction." + str(k) + ".nom"
					nom = tr(ck) if tr(ck) != ck else str(k)
			parts.append("%s %d" % [nom, j.xp[piste][k]])
		ecran_fin.append(tr("ui.fin.piste").format({"piste": tr("piste." + piste), "detail": ", ".join(parts)}))
	var gagnes: Array[String] = []
	for g in dc.get("niveaux", []):
		if g.id == j.id:
			gagnes.append("%s %d" % [tr(sim._nom_competence(g.competence)), g.niveau])
	if not gagnes.is_empty():
		ecran_fin.append(tr("ui.fin.niveaux").format({"liste": ", ".join(gagnes)}))
	ecran_fin.append(tr("ui.fin.suite"))
	ecran_fin_reste = float(GameData.config("combat_rules").get("fin_combat", {}).get("secondes", 6.0))   # il s'efface seul
	for piste in j.xp.keys():
		j.xp[piste] = {}   # non persistée : l'écran la montre, la partie ne la garde pas (prototype)


## Le nom d'un objet : « Épée de braise (une attaque sur 2 porte Feu) » — gabarit localisé,
## paramètres tirés (Loot — affixes : NOM ET PROVENANCE).
func nom_objet(n: Dictionary) -> String:
	var base := tr(str(n.base))
	# Un matériau VIDE ne doit pas produire « Torche en  » : un objet sans matière connue garde son seul
	# nom de base. Le défaut se voyait sur les objets dont aucune pièce n'était maîtresse, et sur les
	# fiches gabarit qui traînent dans le catalogue (le « Composant » générique).
	if n.has("materiau") and not str(n.materiau).is_empty():   # craft : « Dague en fer », « Casque de plaque en cuivre »
		var mat := tr(str(n.materiau))
		if n.has("espece"):   # la matière tirée d'une bête dit laquelle : « cuir d'ours des cavernes » (point 69)
			mat = tr("nom.matiere_espece").format({"materiau": mat, "creature": tr(str(n.espece))})
		var q := " (%s %.2f)" % [tr("qualite." + sim.regles.palier_qualite(float(n.qualite))), float(n.qualite)]
		if not str(n.construction).is_empty():
			return tr("nom.armure_en").format({"base": base, "construction": tr("construction.%s.nom" % n.construction), "materiau": mat}) + q
		return tr("nom.arme_en").format({"base": base, "materiau": mat}) + q
	if n.has("partie"):   # « Cœur de loup », « Bras humain » : une pièce prélevée sur une dépouille (28 ter)
		return tr("nom.partie_de").format({"partie": tr(str(n.partie)), "creature": tr(str(n.get("de_creature", "")))})
	if n.has("espece"):   # une pile de matière brute tirée d'une bête
		return tr("nom.matiere_espece").format({"materiau": base, "creature": tr(str(n.espece))})
	if n.has("parchemin"):
		return tr("nom.parchemin").format({"module": tr(str(n.parchemin.module)), "charges": int(n.parchemin.charges)})
	if n.has("de_creature"):   # la statue 1:1 (Créatures)
		return tr("nom.de_creature").format({"base": base, "creature": tr(str(n.de_creature))})
	if n.has("taille"):
		var t: Dictionary = n.taille
		return "%s (%s %s)" % [base, tr("taille." + str(t.type)), ("%.2f" % float(t.valeur)) if t.type in ["affinite", "qualite"] else str(int(t.valeur))]
	if n.has("module_livre"):   # un livre de module : le module au nom (Grimoires et manuels, 2026-08-31)
		return tr("nom.livre_module").format({"module": tr(str(n.module_livre)), "difficulte": int(n.livre.difficulte) if n.has("livre") else 0})
	if n.has("livre"):
		return tr("nom.livre").format({"base": base, "domaine": tr("domaine." + str(n.livre.domaine)), "difficulte": int(n.livre.difficulte), "n": int(n.livre.n)})
	if str(n.get("affixe", "")).is_empty():
		if n.has("params") and not (n.params as Dictionary).is_empty():   # « Fiole {apparence} », « Trame — {grille} » : les paramètres remplissent le nom, traduits
			var pa: Dictionary = n.params.duplicate()
			if pa.has("apparence"):
				var cle_a := "apparence." + str(pa.apparence)
				pa["apparence"] = tr(cle_a) if tr(cle_a) != cle_a else str(pa.apparence)
			if pa.has("grille"):
				pa["grille"] = tr(str(pa.grille))
			return base.format(pa)
		return base
	var p: Dictionary = n.params.duplicate()
	for k in p.keys():
		if k == "element":
			p["epithete"] = tr("epithete." + str(p[k]))
			p[k] = tr("element." + str(p[k]))
	p["base"] = base
	return tr("affixe." + str(n.affixe) + ".nom").format(p) + " [" + tr("rarete." + str(n.get("rarete", "commun"))) + "]"


const COULEUR_ZONE := {"entrave": Color(0.35, 0.6, 0.25, 0.4), "blessure": Color(0.8, 0.2, 0.2, 0.4),
	"glissante": Color(0.4, 0.75, 0.95, 0.35), "brume": Color(0.75, 0.78, 0.85, 0.5), "balise": Color(0.95, 0.85, 0.3, 0.4)}


func _texte_chaine(e: Dictionary) -> String:
	var noms: Array[String] = []
	for s in _segments(e):
		noms.append(tr("element." + s.element))
	return tr("ui.chaine").format({"segments": " → ".join(noms) if not noms.is_empty() else "∅"})

## Une porte : deux montants plantés dans l'encadrement et un battant. L'axe de l'ouverture se lit sur les
## voisins qui bloquent le passage ; fermé, le battant barre le seuil, ouvert il se range contre son montant.
func _dessiner_porte(ci: CanvasItem, g: Grille, t: Vector2i, c: Vector2, contenu: Dictionary, teinte: Color) -> void:
	var bois := _couleur_html(str(contenu.get("couleur", "#6a4a22"))) * teinte
	var mur_x: bool = (g.dans(t + Vector2i(1, 0)) and g.bloque_passage(t + Vector2i(1, 0))) or (g.dans(t - Vector2i(1, 0)) and g.bloque_passage(t - Vector2i(1, 0)))
	# le battant relie les deux montants : selon l'axe, l'un ou l'autre demi-diagonale de la tuile
	var demi := Vector2(TW * 0.25, TH * 0.25) if mur_x else Vector2(TW * 0.25, -TH * 0.25)
	var a := c - demi
	var b := c + demi
	var haut := Vector2(0.0, -float((PORTE_BLOCS * BLOC_UNITES) if g.niveaux_bat[g.idx(t)] > 0 else int(contenu.get("hauteur_vue", 2))) * HSTEP)   # deux blocs dans un bâtiment (designer, 18 h)
	var uv_p := PackedVector2Array([_uv_haut(t, 0.5, 0.5, 0.0), _uv_haut(t, 0.5, 0.5, 0.0), _uv_haut(t, 0.5, 0.5, 0.0), _uv_haut(t, 0.5, 0.5, 0.0)])   # la lumière de la tuile, sans grain
	for m in [a, b]:   # les montants
		_poly(ci, PackedVector2Array([m + Vector2(-1.5, 0), m + Vector2(1.5, 0), m + Vector2(1.5, 0) + haut, m + Vector2(-1.5, 0) + haut]), bois.darkened(0.45), uv_p)
	var ferme: bool = "fermee" in contenu.get("tags", [])
	var p0 := a if ferme else a.lerp(b, 0.68)   # ouvert : le battant est rangé contre le montant
	var p1 := b if ferme else b
	_poly(ci, PackedVector2Array([p0, p1, p1 + haut, p0 + haut]), bois, uv_p)
	_poly(ci, PackedVector2Array([p0, p1, p1 + haut * 0.08, p0 + haut * 0.08]), bois.darkened(0.3), uv_p)
	var trav := (p0 + p1) * 0.5 + haut * 0.55
	_lot_vider(ci)   # la traverse et la poignée par-dessus le battant
	ci.draw_line(p0 + haut * 0.5, p1 + haut * 0.5, bois.darkened(0.25), 1.0)   # la traverse
	ci.draw_circle(trav.lerp(p1 + haut * 0.55, 0.45), 1.6, Color(0.85, 0.75, 0.35) * teinte)   # la poignée

## Dix pages de hotbar (designer 2026-09-02) : `Ctrl` + chiffre. La page courante vit dans `j.hotbar`
## — tout le reste du code continue de la lire —, les autres attendent dans `j.hotbar_pages`.
func _changer_page_hotbar(page: int) -> void:
	var j := joueur()
	if j.is_empty() or page < 0 or page > 9:
		return
	if not j.has("hotbar_pages"):
		var pages: Array = []
		for i in 10:
			pages.append([])
		j["hotbar_pages"] = pages
		j["hotbar_page"] = 0
	j.hotbar_pages[int(j.get("hotbar_page", 0))] = j.get("hotbar", []).duplicate(true)   # on range la page qu'on quitte
	j["hotbar_page"] = page
	var suivante: Array = j.hotbar_pages[page]
	if suivante.is_empty():
		j.erase("hotbar")   # page jamais touchée : la hotbar dérivée reprend la main, elle n'est jamais vide
	else:
		j["hotbar"] = suivante.duplicate(true)
	hotbar_sel = -1
	_log(tr("journal.hotbar_page").format({"n": page + 1}))
	hud_ecran.queue_redraw()
