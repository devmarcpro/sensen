extends Control
class_name VoletLateral
## LE VOLET LATÉRAL, À LA MANIÈRE DE CATACLYSM (designer 2026-09-04 : « un volet à droite de l\'écran avec infos du
## monde, stats, journal, inventaire etc » ; refait le 2026-09-10 : « plus comme celui de Cataclysm Dark Days
## Ahead »).
##
## **Ce qui fait le volet de Cataclysm n\'est pas son esthétique, c\'est sa méthode**, et c\'est elle qu\'on emprunte :
## 1. **Le corps par parties, en haut, avant tout le reste.** C\'est sa signature — et nous l\'avons depuis le
##    2026-09-09 : le plan de parties était dans les données et n\'apparaissait nulle part hors de l\'écran d\'anatomie.
## 2. **La couleur EST l\'état.** Un chiffre vert ne se lit pas, un chiffre rouge saute aux yeux : on ne *lit* pas un
##    volet de Cataclysm, on le **balaie**.
## 3. **On n\'affiche que ce qui compte.** *Hungry*, *Thirsty*, *Encumbered* n\'apparaissent QUE quand c\'est vrai. Une
##    ligne permanente « Faim 100/100 » ne dit rien ; une ligne qui apparaît quand on a faim dit tout.
## 4. **Des blocs courts, abrégés, denses** — deux stats par colonne, pas une ligne par stat.
##
## Il ne calcule rien : il lit la simulation et le journal du client. Ses dimensions et ses seuils sont dans
## `styles.volet`.

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
## LA COULEUR EST L\'ÉTAT (Cataclysm) : du plein au presque mort, quatre crans qu\'on distingue du coin de l\'œil.
const COL_PLEIN := Color(0.55, 0.85, 0.45)
const COL_ENTAME := Color(0.9, 0.85, 0.35)
const COL_BLESSE := Color(0.95, 0.6, 0.2)
const COL_GRAVE := Color(0.95, 0.3, 0.25)
const COL_PERDU := Color(0.45, 0.42, 0.4)


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


## LA COULEUR D\'UNE PART : c\'est elle qui permet de balayer le volet au lieu de le lire.
func _couleur(part: float) -> Color:
	if part >= 0.999:
		return COL_PLEIN
	if part >= 0.66:
		return COL_ENTAME
	if part >= 0.33:
		return COL_BLESSE
	return COL_GRAVE


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
	# 1. LE CORPS, EN HAUT ET AVANT TOUT LE RESTE — la signature de Cataclysm, et la nôtre depuis l\'anatomie.
	y = _section(tr("volet.corps"), y)
	y = _corps(j, y, max_y)
	# 2. Les jauges, deux par ligne, chiffrées et colorées.
	y = _jauges(j, y, max_y)
	# 3. Les stats, deux lignes de trois — abrégées, comme Cataclysm les serre.
	y = _stats(j, y, max_y)
	# 4. CE QUI NE VA PAS, ET RIEN D\'AUTRE. La ligne n\'existe que si elle a quelque chose à dire.
	var maux := _maux(sim, j)
	if not maux.is_empty():
		for m in maux:
			y = _ligne(str(m[0]), y, max_y, m[1])
	# 5. En main, et ce que coûte ce qu\'on s\'apprête à lancer.
	y = _section(tr("volet.en_main"), y + 6.0)
	for l in _lignes_main(sim, j):
		y = _ligne(l, y, max_y)
	# 6. Le monde
	y = _section(tr("volet.monde"), y + 6.0)
	for l in _lignes_monde(sim, j):
		y = _ligne(l, y, max_y)
	# 7. Les compagnons
	var comps: Array = sim.compagnons_de(j, false)
	if not comps.is_empty():
		y = _section(tr("volet.compagnons"), y + 6.0)
		for c in comps:
			var etat: String = tr("ordre." + str(c.get("ordre", "suivre")))
			if not sim.entites.has(c.id):
				etat = tr("hud.compagnon_hors_vue")
			elif not bool(c.vivant):
				etat = tr("hud.compagnon_mort")
			y = _ligne("%s · %d/%d · %s" % [tr(c.name_key), int(c.sante), int(c.sante_max), etat], y, max_y, _couleur(float(c.sante) / maxf(1.0, float(c.sante_max))))
	# 8. Le journal (les mêmes lignes que le bas de l\'écran, qui ne les répète plus)
	y = _section(tr("volet.journal"), y + 6.0)
	var n_j := int(st.get("lignes_journal", 9))
	var journal: Array = main.journal
	for k in range(maxi(0, journal.size() - n_j), journal.size()):
		y = _ligne(str(journal[k]), y, max_y, COL_TEXTE if k == journal.size() - 1 else COL_SOMBRE)
	# 9. L\'inventaire
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


## LE CORPS PAR PARTIES (Cataclysm) : les membres EXTERNES, deux par ligne, chacun avec sa réserve et sa couleur.
## Une partie perdue est barrée et grise — un membre absent doit se voir absent, pas être silencieusement omis.
## Les organes ne sont pas ici : ils tiennent dans l\'écran d\'anatomie, et un volet qui montre tout ne montre rien.
func _corps(j: Dictionary, y: float, max_y: float) -> float:
	var plan := Etres.plan_corps(j)
	if plan.is_empty():
		return _ligne(tr("volet.corps_sans_plan"), y, max_y, COL_SOMBRE)
	var externes: Array[String] = []
	for nom: String in (plan.parties as Dictionary).keys():
		if not bool((plan.parties[nom] as Dictionary).get("interne", false)):
			externes.append(nom)
	var font := ThemeDB.fallback_font
	var colonne := (largeur - 2.0 * MARGE) * 0.5
	var k := 0
	for nom in externes:
		if y + INTERLIGNE > max_y:
			break
		var x := MARGE + float(k % 2) * colonne
		var col := COL_PERDU
		var txt := tr("partie.court." + nom)
		if txt.begins_with("partie.court."):
			txt = tr("partie." + nom).substr(0, 8)
		if Etres.partie_intacte(j, nom):
			var pv := Etres.sante_partie(j, nom)
			var pmax := maxi(1, Etres.sante_partie_max(j, nom))
			col = _couleur(float(pv) / float(pmax))
			txt += " %d/%d" % [pv, pmax]
		else:
			txt += " —"
		draw_string(font, Vector2(x, y + INTERLIGNE - 3.0), txt, HORIZONTAL_ALIGNMENT_LEFT, colonne - 4.0, TAILLE, col)
		k += 1
		if k % 2 == 0:
			y += INTERLIGNE
	if k % 2 == 1:
		y += INTERLIGNE
	return y


## LES JAUGES, DEUX PAR LIGNE, chiffrées et colorées — on les balaie, on ne les lit pas.
func _jauges(j: Dictionary, y: float, max_y: float) -> float:
	var paires: Array = [
		[["volet.pv", int(j.sante), int(j.sante_max)], ["volet.vig", int(j.vigueur), int(j.vigueur_max)]],
		[["volet.mana", int(j.mana), int(j.mana_max)], ["volet.sf", int(j.get("sang_froid", 0)), int(j.get("sang_froid_max", 0))]],
	]
	var font := ThemeDB.fallback_font
	var colonne := (largeur - 2.0 * MARGE) * 0.5
	for rangee in paires:
		if y + INTERLIGNE > max_y:
			break
		for c in rangee.size():
			var e: Array = rangee[c]
			if int(e[2]) <= 0:
				continue
			var t := tr(str(e[0])).format({"n": int(e[1]), "max": int(e[2])})
			draw_string(font, Vector2(MARGE + float(c) * colonne, y + INTERLIGNE - 3.0), t, HORIZONTAL_ALIGNMENT_LEFT, colonne - 4.0, TAILLE, _couleur(float(e[1]) / maxf(1.0, float(e[2]))))
		y += INTERLIGNE
	return y


## LES SIX STATS EN DEUX LIGNES, abrégées à trois lettres — la densité de Cataclysm, pas six lignes.
func _stats(j: Dictionary, y: float, max_y: float) -> float:
	var noms: Array[String] = ["force", "dexterite", "endurance", "volonte", "perception", "charisme"]
	var bouts: Array[String] = []
	for s in noms:
		bouts.append("%s %d" % [tr("stat." + s).substr(0, 3), int(j.stats_eff.get(s, 0))])
	y = _ligne(" ".join(bouts.slice(0, 3)), y, max_y, COL_SOMBRE)
	return _ligne(" ".join(bouts.slice(3, 6)), y, max_y, COL_SOMBRE)


## CE QUI NE VA PAS, ET RIEN D\'AUTRE (la règle de Cataclysm). Une ligne permanente « Faim 100/100 » ne dit rien ;
## une ligne qui APPARAÎT quand on a faim dit tout. Les seuils sont ceux des règles, pas des nombres à part.
func _maux(sim, j: Dictionary) -> Array:
	var res: Array = []
	var r = sim.regles.r
	var faim := int(j.get("faim", 100))
	if faim < int(r.faim.get("tooltip_seuil", 60)):
		res.append([tr("volet.mal.faim").format({"n": faim}), COL_GRAVE if faim < int(r.faim.seuil_stats) else COL_BLESSE])
	var soif := int(j.get("soif", 100))
	var sc: Dictionary = r.get("soif", {})
	if not sc.is_empty() and soif < int(sc.get("seuil_conseil", 60)):
		res.append([tr("volet.mal.soif").format({"n": soif}), COL_GRAVE if soif < int(sc.get("seuil_stats", 25)) else COL_BLESSE])
	var p_som := int(j.get("fatigue_palier", 0))   # le sommeil (ordre de travail 31) : la ligne n'apparaît que fatigué
	if p_som > 0:
		res.append([tr("volet.mal.fatigue_%d" % p_som), COL_GRAVE if p_som >= 2 else COL_BLESSE])
	var pd: Dictionary = sim.poids_de(j)
	if float(pd.facteur) > 1.0:
		res.append([tr("volet.mal.charge").format({"poids": "%.0f" % float(pd.poids), "capacite": "%.0f" % float(pd.capacite)}), COL_BLESSE])
	for s in j.get("statuts", []):
		var sd: Dictionary = sim.statuts_defs.get(str((s as Dictionary).get("id", "")), {})
		if not sd.is_empty():
			res.append([tr(str(sd.get("name_key", ""))), COL_BLESSE])
	return res


## EN MAIN, ET CE QUE COÛTE CE QU\'ON S\'APPRÊTE À LANCER (ordre de travail 37) : l\'usure s\'y lit aussi, parce qu\'une
## lame émoussée est un fait de combat, pas une ligne d\'inventaire.
func _lignes_main(sim, j: Dictionary) -> Array[String]:
	var l: Array[String] = []
	var uid := str(j.get("equipement", {}).get("main_principale", ""))
	if sim.items.has(uid):
		var it: Dictionary = sim.items[uid]
		var t: String = main.nom_objet(sim.nom_objet(uid))
		if float(it.get("usure", 0.0)) > 0.0:
			t += tr("volet.usure").format({"n": int(round(float(it.usure) * 100.0))})
		l.append(t)
	var ent: Array = main.hotbar_entrees(j)
	if int(main.hotbar_sel) < ent.size() and str(ent[int(main.hotbar_sel)].get("type", "")) == "capacite":
		var plan: Dictionary = sim.plan_capacite(j, int(ent[int(main.hotbar_sel)].ref))
		var cout: String = main._texte_cout_capacite(j, plan)
		var nom_cap := str(plan.get("name_key", ""))
		if not nom_cap.is_empty():   # une ligne vide occuperait une place et ne dirait rien
			l.append("%s%s" % [tr(nom_cap), (" — " + cout) if not cout.is_empty() else ""])
	var rep: String = main._texte_reputation(j)
	if not rep.is_empty():
		l.append(rep)
	return l


func _section(titre: String, y: float) -> float:
	draw_string(ThemeDB.fallback_font, Vector2(MARGE, y + INTERLIGNE - 3.0), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, TAILLE + 1, COL_TITRE)
	draw_line(Vector2(MARGE, y + INTERLIGNE + 1.0), Vector2(largeur - MARGE, y + INTERLIGNE + 1.0), Color(0.6, 0.55, 0.4, 0.5), 1.0)
	return y + INTERLIGNE + 5.0


## Une ligne coupée à la largeur du volet (« … » au bout), grise ou claire ; rien sous le bas de l\'écran.
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
