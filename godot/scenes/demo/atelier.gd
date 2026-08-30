class_name AtelierVisuel
extends VBoxContainer
## L'atelier visuel (Écrans d'interface — designer, 2026-08-30) : les recettes en **cartes** (icône de ce qui sort,
## nom, faisable ou non, station), les ingrédients optionnels d'un plat en cartes cochables. Comme l'inventaire,
## il ne décide rien : il lit `ecrans.entrees` / `ecrans.selection` et sélectionne ; Fabriquer reste le bouton de l'écran.

const CARTE := Vector2(72, 88)

var ecrans: Node
var grille: GridContainer
var defilement: ScrollContainer
var cartes: Array = []


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	defilement = ScrollContainer.new()
	defilement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(defilement)
	grille = GridContainer.new()
	grille.columns = 6
	grille.add_theme_constant_override("h_separation", 6)
	grille.add_theme_constant_override("v_separation", 6)
	grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	defilement.add_child(grille)
	resized.connect(_colonnes)


func _colonnes() -> void:
	if grille != null and defilement != null:
		grille.columns = maxi(2, int(defilement.size.x / (CARTE.x + 6.0)))


func reconstruire() -> void:
	for ch in grille.get_children():
		ch.queue_free()
	cartes.clear()
	var k := 0
	for en in ecrans.entrees:
		var kind := str(en.get("kind", ""))
		if kind in ["recette", "ingredient"]:
			var carte := CarteRecette.new()
			carte.atelier = self
			carte.entree = en
			carte.index = k
			grille.add_child(carte)
			cartes.append(carte)
		k += 1
	_colonnes()


func rafraichir_selection() -> void:
	for c in cartes:
		c.queue_redraw()


func selectionner(index: int) -> void:
	if index < 0 or index >= ecrans.entrees.size():
		return
	ecrans.selection = index
	if ecrans.liste.item_count > index:
		ecrans.liste.select(index)
	ecrans._montrer_detail()
	rafraichir_selection()


## Ce qu'une recette produit, sous la forme d'un objet à dessiner (icône et couleur).
static func objet_de_sortie(pl: Dictionary) -> Dictionary:
	match str(pl.get("kind", "")):
		"objet":
			return GameData.entree("items", str(pl.sortie.objet))
		"composant":
			var pile: Dictionary = pl.entrees[0].pile if not pl.entrees.is_empty() else {}
			return {"type": "composant", "materiau": str(pile.get("materiau", ""))}
		_:
			var r: Dictionary = pl.get("recette", {})
			var out: Dictionary = r.get("output", {})
			if out.has("item") and GameData.catalogues.items.has(str(out.item)):
				return GameData.entree("items", str(out.item))
			if out.has("material"):
				return {"type": "materiau", "materiau": str(out.material), "forme": str(out.get("forme", "brut"))}
			var so: Dictionary = pl.get("sortie", {})
			if so.has("objet") and GameData.catalogues.items.has(str(so.objet)):
				return GameData.entree("items", str(so.objet))
			return {"type": "materiau", "materiau": str(so.get("materiau", "")), "forme": str(so.get("forme", "brut"))}


## Une carte : l'icône de la sortie, le nom, ✓ / ✗, la station ; un ingrédient optionnel : l'objet et sa coche.
class CarteRecette extends Control:
	var atelier: AtelierVisuel
	var entree: Dictionary = {}
	var index := -1
	var survolee := false

	func _ready() -> void:
		custom_minimum_size = AtelierVisuel.CARTE
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void: survolee = true; queue_redraw())
		mouse_exited.connect(func() -> void: survolee = false; queue_redraw())
		if str(entree.get("kind", "")) == "recette":
			tooltip_text = atelier.ecrans._titre_plan(entree.plan)
		else:
			tooltip_text = atelier.ecrans.main.nom_objet(atelier.ecrans.main.sim.nom_objet(str(entree.uid)))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, AtelierVisuel.CARTE)
		var choisie: bool = atelier.ecrans.selection == index
		var ingredient: bool = str(entree.get("kind", "")) == "ingredient"
		var pl: Dictionary = entree.get("plan", {})
		var faisable: bool = bool(pl.get("faisable", false)) if not ingredient else true
		var it: Dictionary = atelier.ecrans.main.sim.items.get(str(entree.get("uid", "")), {}) if ingredient else AtelierVisuel.objet_de_sortie(pl)
		var cadre := Pictos.couleur_objet(it) if not it.is_empty() else Color(0.6, 0.55, 0.4)
		var alpha := 1.0 if faisable else 0.45
		draw_rect(r, Color(cadre.r * 0.16, cadre.g * 0.16, cadre.b * 0.16, 0.95))
		draw_rect(r, Color(1, 1, 1, 0.95) if choisie else (Color(1, 1, 1, 0.55) if survolee else Color(cadre.r, cadre.g, cadre.b, alpha)), false, 2.0 if choisie else 1.0)
		if ingredient:   # une carte plus discrète, décalée : c'est un ingrédient de la recette qui précède
			draw_rect(Rect2(Vector2(4, 4), AtelierVisuel.CARTE - Vector2(8, 8)), Color(1, 1, 1, 0.04))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		modulate = Color(1, 1, 1, alpha)
		Pictos.dessiner_objet(self, it, Rect2(Vector2(18, 8), Vector2(36, 36)))
		var nom: String = (atelier.ecrans._titre_plan(pl) if not ingredient else atelier.ecrans._nom_court(str(entree.uid)))
		if pl.get("kind", "") == "composant":
			nom = tr(GameData.entree("components", pl.recette.component).name_key)
		_texte(nom, Vector2(3, AtelierVisuel.CARTE.y - 30), 8, Color(0.92, 0.9, 0.82))
		if ingredient:
			var inclus := "☑" if "☑" in atelier.ecrans.liste.get_item_text(index) else "☐"
			draw_string(ThemeDB.fallback_font, Vector2(4, 14), inclus, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.95, 0.7))
		else:
			draw_string(ThemeDB.fallback_font, Vector2(4, 14), "✓" if faisable else "✗", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.95, 0.5) if faisable else Color(0.9, 0.4, 0.4))
			var station: String = tr(GameData.entree("stations", str(pl.get("station", ""))).get("name_key", "")).left(12)
			draw_string(ThemeDB.fallback_font, Vector2(3, AtelierVisuel.CARTE.y - 4), station, HORIZONTAL_ALIGNMENT_LEFT, AtelierVisuel.CARTE.x - 6, 7, Color(0.65, 0.62, 0.5))

	## Un nom sur deux lignes au plus, coupé à la largeur de la carte.
	func _texte(t: String, pos: Vector2, taille: int, c: Color) -> void:
		var f := ThemeDB.fallback_font
		var largeur := AtelierVisuel.CARTE.x - 6.0
		var mots := t.split(" ")
		var lignes: Array[String] = []
		var ligne := ""
		for m in mots:
			var essai := (ligne + " " + m).strip_edges()
			if f.get_string_size(essai, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x > largeur and not ligne.is_empty():
				lignes.append(ligne)
				ligne = m
			else:
				ligne = essai
			if lignes.size() >= 2:
				break
		if lignes.size() < 2 and not ligne.is_empty():
			lignes.append(ligne)
		for k in lignes.size():
			draw_string(f, pos + Vector2(0, k * 10.0), lignes[k], HORIZONTAL_ALIGNMENT_LEFT, largeur, taille, c)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			atelier.selectionner(index)
			if ev.double_click:
				atelier.ecrans._action_principale()
			accept_event()
