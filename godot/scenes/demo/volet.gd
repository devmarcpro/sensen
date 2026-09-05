extends Control
class_name VoletLateral
## Le volet latéral (Écrans d'interface — designer 2026-09-04, 19 h 30 : « un volet à droite de l'écran avec infos du
## monde, stats, journal, inventaire etc »). Une colonne permanente sur le bord droit, sous la minimap, le compas et le
## pentagramme : Monde, Personnage, Compagnons, Journal, Inventaire. Dessiné par code, il ne calcule rien — il lit
## la simulation et le journal du client. Ses dimensions viennent de `styles.volet`.

var main: Node2D
var largeur := 300.0
var haut := 0.0   # sous la minimap, le compas et le pentagramme (calculé au dessin)
const MARGE := 10.0
const INTERLIGNE := 15.0
const TAILLE := 11
const COL_TITRE := Color(0.82, 0.74, 0.5)
const COL_TEXTE := Color(0.9, 0.88, 0.8)
const COL_SOMBRE := Color(0.62, 0.6, 0.55)
const COL_FOND := Color(0.04, 0.04, 0.06, 0.78)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # ce qui est sous le volet ne se clique pas au travers
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)


func _process(_delta: float) -> void:
	if main == null or main.sim == null:
		return
	var st: Dictionary = GameData.config("styles").get("volet", {})
	var taille := get_viewport_rect().size
	largeur = clampf(taille.x * float(st.get("part", 0.24)), float(st.get("largeur_min", 240.0)), float(st.get("largeur_max", 380.0)))
	haut = MARGE + float(Minimap.TAILLE) + 12.0 + HudEcran.RAYON_COMPAS * 2 + 30.0 + HudEcran.RAYON_PENTA * 2 + 24.0
	offset_left = -largeur
	offset_right = 0.0
	visible = main.volet_visible and not main.titre_ouvert
	queue_redraw()


func _draw() -> void:
	if main == null or main.sim == null or main.titre_ouvert:
		return
	var j: Dictionary = main.joueur()
	if j.is_empty():
		return
	var sim = main.sim
	var taille := get_viewport_rect().size
	draw_rect(Rect2(0, 0, largeur, taille.y), COL_FOND)
	draw_line(Vector2(0.5, 0), Vector2(0.5, taille.y), Color(0.6, 0.55, 0.4, 0.5), 1.0)
	var y := haut
	var st: Dictionary = GameData.config("styles").get("volet", {})
	var max_y := taille.y - MARGE
	# 1. Le monde
	y = _section(tr("volet.monde"), y)
	for l in _lignes_monde(sim, j):
		y = _ligne(l, y, max_y)
	# 2. Le personnage
	y = _section(tr("volet.personnage"), y + 6.0)
	for l in _lignes_personnage(sim, j):
		y = _ligne(l, y, max_y)
	# 3. Les compagnons
	var comps: Array = sim.compagnons_de(j, false)
	if not comps.is_empty():
		y = _section(tr("volet.compagnons"), y + 6.0)
		for c in comps:
			var etat: String = tr("ordre." + str(c.get("ordre", "suivre")))
			if not sim.entites.has(c.id):
				etat = tr("hud.compagnon_hors_vue")
			elif not bool(c.vivant):
				etat = tr("hud.compagnon_mort")
			y = _ligne("%s · %d/%d · %s" % [tr(c.name_key), int(c.sante), int(c.sante_max), etat], y, max_y)
	# 4. Le journal (les mêmes lignes que le bas de l'écran, qui ne les répète plus)
	y = _section(tr("volet.journal"), y + 6.0)
	var n_j := int(st.get("lignes_journal", 9))
	var journal: Array = main.journal
	for k in range(maxi(0, journal.size() - n_j), journal.size()):
		y = _ligne(str(journal[k]), y, max_y, COL_SOMBRE)
	# 5. L'inventaire
	y = _section(tr("volet.inventaire").format({"n": j.sac.size()}), y + 6.0)
	var n_i := int(st.get("lignes_inventaire", 12))
	for k in mini(n_i, j.sac.size()):
		var it: Dictionary = sim.items.get(j.sac[k], {})
		if it.is_empty():
			continue
		var nom: String = main.nom_objet(sim.nom_objet(j.sac[k]))
		if it.get("type", "") == "materiau":
			nom = tr("forme." + str(it.get("forme", "brut"))).format({"materiau": nom})
		if int(it.get("quantite", 1)) > 1:
			nom += " ×%d" % int(it.quantite)
		y = _ligne(nom, y, max_y)
	if j.sac.size() > n_i:
		y = _ligne("+%d" % (j.sac.size() - n_i), y, max_y, COL_SOMBRE)


func _section(titre: String, y: float) -> float:
	draw_string(ThemeDB.fallback_font, Vector2(MARGE, y + INTERLIGNE - 3.0), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE + 1, COL_TITRE)
	draw_line(Vector2(MARGE, y + INTERLIGNE + 1.0), Vector2(largeur - MARGE, y + INTERLIGNE + 1.0), Color(0.6, 0.55, 0.4, 0.5), 1.0)
	return y + INTERLIGNE + 5.0


## Une ligne coupée à la largeur du volet (« … » au bout), grise ou claire ; rien sous le bas de l'écran.
func _ligne(texte: String, y: float, max_y: float, col: Color = COL_TEXTE) -> float:
	if y + INTERLIGNE > max_y:
		return y
	var font := ThemeDB.fallback_font
	var dispo := largeur - 2.0 * MARGE
	var t := texte
	while t.length() > 4 and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE).x > dispo:
		t = t.substr(0, t.length() - 2).rstrip(" ") + "…"
	draw_string(font, Vector2(MARGE, y + INTERLIGNE - 3.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE, col)
	return y + INTERLIGNE


func _lignes_monde(sim, j: Dictionary) -> Array[String]:
	var l: Array[String] = []
	if sim.lieu == "camp" and sim.monde != null:
		var tr_: Dictionary = sim.temperature_ressentie(j)
		l.append(tr("volet.date").format({"date": Calendrier.texte(sim.date_courante())}))   # la date du calendrier (Un monde réel — A)
		l.append(tr("volet.heure").format({"heure": "%02d:%02d" % [int(sim.heure()), int(fmod(sim.heure(), 1.0) * 60.0)], "phase": tr("phase." + sim.phase()), "jour": sim.jour_courant()}))
		l.append(tr("volet.saison").format({"saison": tr("saison." + str(sim.saison())), "meteo": tr(GameData.entree("weather_states", str(tr_.meteo)).name_key), "temp": "%.0f" % float(tr_.temp)}))
		var cell: Vector2i = sim.monde.cellule_de(j.pos)
		var biome := str(sim.monde.cellule(cell).get("biome", ""))
		l.append(tr("volet.lieu_camp").format({"x": cell.x, "y": cell.y, "biome": tr(GameData.catalogues.biomes.get(biome, {}).get("name_key", biome))}))
		var roy_v: Dictionary = sim.monde.surface.royaume_de(cell)   # le pays où l'on se tient (D)
		if not roy_v.is_empty():
			var etat_v: Dictionary = sim.etat_royaume(str(roy_v.id))
			if not etat_v.is_empty():
				l.append(tr("volet.royaume").format({"nom": str(roy_v.nom), "gouv": tr(GameData.entree("governments", str(roy_v.government_type)).name_key), "dirigeant": str(etat_v.dirigeant), "an": sim.an_de_regne(etat_v), "ere": tr("ere.%s.name" % str(etat_v.ere))}))
		l.append(tr("volet.corruption").format({"n": roundi(sim.monde.corruption_de(cell))}))
		var vl: Dictionary = sim.vecteur_lieu(j.pos)
		if not vl.is_empty():
			var cles: Array = vl.keys()
			cles.sort_custom(func(p: String, q: String) -> bool: return float(vl[p]) > float(vl[q]))
			l.append(tr("ui.lieu").format({"a": tr("element." + str(cles[0])), "pa": roundi(float(vl[cles[0]]) * 100.0), "b": tr("element." + str(cles[1])), "pb": roundi(float(vl[cles[1]]) * 100.0)}).strip_edges())
	elif sim.lieu == "donjon":
		l.append(tr("volet.lieu_donjon").format({"theme": tr(GameData.entree("dungeon_themes", str(sim.donjon.get("theme", "ruine"))).name_key), "etage": int(sim.donjon.get("etage", 1)), "etages": int(sim.donjon.get("etages", 1))}))
		l.append(tr("volet.corruption").format({"n": roundi(float(sim.donjon.get("corruption_etage", 0.0)))}))
		l.append(tr("volet.horloge_donjon").format({"ticks": sim.horloge_de(j).ticks}))
	return l


func _lignes_personnage(sim, j: Dictionary) -> Array[String]:
	var l: Array[String] = []
	var stats: Array[String] = []
	for s in ["force", "dexterite", "endurance", "volonte", "perception", "charisme"]:
		stats.append("%s %d" % [tr("stat." + s).substr(0, 3), int(j.stats_eff.get(s, 0))])   # « For 5 · Dex 4 · End 6 » : le nom entier ne tient pas
	l.append(" · ".join(stats.slice(0, 3)))
	l.append(" · ".join(stats.slice(3, 6)))
	var nd: Dictionary = sim.progression.niveaux_derives(j)
	l.append(tr("ui.niveaux").format({"combat": "%.1f" % nd.combat, "general": "%.1f" % nd.general}).strip_edges())
	var pd: Dictionary = sim.poids_de(j)
	l.append(tr("ui.or").format({"n": int(j.get("or", 0))}) + " · " + tr("ui.poids").format({"poids": "%.0f" % float(pd.poids), "capacite": "%.0f" % float(pd.capacite), "surcharge": ""}))
	if j.equipement.has("main_principale") and sim.items.has(j.equipement.main_principale):
		l.append(tr("volet.arme").format({"arme": main.nom_objet(sim.nom_objet(j.equipement.main_principale))}))
	return l
