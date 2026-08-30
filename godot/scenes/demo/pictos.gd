class_name Pictos
## Les pictogrammes des modules (Écrans d'interface, décision du designer du 2026-08-30) : chaque module a un
## dessin qui **représente son effet**, tracé par code (aucun asset) dans un carré. Le nom du pictogramme vient
## du champ `icone` de la fiche s'il existe, sinon il est **dérivé des données** du module : la géométrie d'une
## forme, l'effet et l'élément d'un noyau, la famille des autres types. `tools/audit_donnees.py` refuse un
## `icone` que cette liste ne connaît pas.

const NOMS: Array[String] = [
	"point", "soi", "ligne", "cone", "croix", "diagonale", "carre", "anneau", "tuile", "vague", "mur", "sillage", "chemin", "colonne", "horizon", "nuee",
	"flamme", "goutte", "roche", "eclat", "epine", "etoile", "soin", "chaine", "sablier", "bouclier",
	"fleche_droite", "fleche_gauche", "fleche_haut", "fleche_saut", "fleche_double", "fleche_retour", "tourbillon", "porte",
	"monticule", "fosse", "bombe", "tourelle", "patte", "crane", "barriere",
	"lune", "coeur", "sang", "balai", "oeil", "epee_brisee", "main", "soleil", "segment",
	"plus", "portee", "expansion", "horloge", "etincelle", "oeil_barre", "forme",
	"cible", "monde", "porteur", "position", "evenement", "minuterie", "liens", "boucle", "livre",
]

## Le pictogramme d'un module, depuis sa fiche.
static func icone_de(md: Dictionary) -> String:
	var ic := str(md.get("icone", ""))
	if not ic.is_empty() and ic in NOMS:
		return ic
	var t := str(md.get("module_type", ""))
	var fam := str(md.get("famille", "")).to_lower()
	match t:
		"forme":
			var g := str(md.get("geometrie", "point"))
			return g if g in NOMS else "point"
		"noyau":
			var effets: Array = md.get("effets", [])
			var ef: Dictionary = md.get("effet", {})
			if "invocation" in effets:
				var mode := str(ef.get("invocation", {}).get("mode", ""))
				match mode:
					"bombe": return "bombe"
					"tourelle": return "tourelle"
					"creature": return "patte"
					"releve": return "crane"
				return "barriere"
			if "resurrection" in effets:
				return "soleil"
			if "saisie" in effets:
				return "main"
			if "deplacement" in effets:
				match str(ef.get("deplacement", {}).get("mode", "")):
					"attraction": return "fleche_gauche"
					"projection", "recul": return "fleche_droite"
					"saut": return "fleche_saut"
					"permutation": return "fleche_double"
					"retour_ancre": return "fleche_retour"
					"levitation": return "fleche_haut"
					"fauchage": return "tourbillon"
					"lancer_porte": return "porte"
					"traversee": return "porte"
					"convocation": return "fleche_gauche"
				return "fleche_droite"
			if "ressource" in effets:
				var r: Dictionary = ef.get("ressource", {})
				if r.has("purge"): return "balai"
				if r.has("estime"): return "oeil"
				if r.has("desarme"): return "epee_brisee"
				if r.has("segment_de_la_cible"): return "segment"
				if r.has("sang"): return "sang"
				if r.has("releve_allie_pct") or r.has("transfert_pv"): return "coeur"
				if r.has("mana") or r.has("vol_mana"): return "lune"
				if r.has("endurance"): return "coeur"
				return "lune"
			if "terrain" in effets:
				var delta := float(ef.get("terrain", {}).get("delta", 0))
				return "fosse" if delta < 0.0 else "monticule"
			if "soin" in effets:
				return "soin"
			if "tempo" in effets:
				return "sablier"
			if "degats" in effets:
				return _degats_element(md)
			if "statut" in effets:
				if fam.begins_with("défense") or fam.begins_with("defense"):
					return "bouclier"
				return "chaine"
			return "etoile"
		"modificateur":
			for cle in ["puissance", "portee", "taille", "element", "tempo", "effet", "discretion", "forme"]:
				if fam.find(cle) >= 0 or fam.find(cle.replace("e", "é")) >= 0:
					return {"puissance": "plus", "portee": "portee", "taille": "expansion", "element": "etoile", "tempo": "horloge", "effet": "etincelle", "discretion": "oeil_barre", "forme": "forme"}[cle]
			return "plus"
		"condition":
			for cle in ["cible", "monde", "porteur", "position"]:
				if fam.find(cle) >= 0:
					return cle
			return "cible"
		"declencheur":
			return "minuterie" if fam.find("minut") >= 0 else "evenement"
		"liaison":
			return "boucle" if fam.find("rejeu") >= 0 else "liens"
	return "livre"


static func _degats_element(md: Dictionary) -> String:
	var els: Dictionary = md.get("elements", {})
	var meilleur := ""
	var poids := 0.0
	for el in els.keys():
		if float(els[el]) > poids:
			poids = float(els[el])
			meilleur = str(el)
	match meilleur:
		"feu": return "flamme"
		"eau": return "goutte"
		"terre": return "roche"
		"metal": return "eclat"
		"bois": return "epine"
	return "eclat" if md.get("power_base") == "arme" else "etoile"


# ---------------------------------------------------------------- le tracé

## Dessine le pictogramme `nom` dans `r`, couleur `c`. Tout est tracé en primitives : lignes, polygones, arcs.
static func dessiner(ci: CanvasItem, nom: String, r: Rect2, c: Color) -> void:
	var o := r.position
	var s := r.size.x
	var u := s / 10.0   # l'unité : le carré fait 10 × 10
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x * u, y * u)
	var fin := Color(c.r, c.g, c.b, c.a * 0.55)
	match nom:
		# --- les formes : des tuiles sur une grille 5 × 5 (le lanceur en bas, la cible au centre)
		"point", "soi", "ligne", "cone", "croix", "diagonale", "carre", "anneau", "tuile", "vague", "mur", "sillage", "chemin", "colonne", "horizon", "nuee":
			_forme(ci, nom, r, c)
		"flamme":
			ci.draw_colored_polygon(PackedVector2Array([p.call(5, 1), p.call(7.5, 4.5), p.call(6.5, 5.5), p.call(8, 7.5), p.call(5, 9.5), p.call(2, 7.5), p.call(3.5, 5.5), p.call(2.5, 4.5)]), c)
			ci.draw_colored_polygon(PackedVector2Array([p.call(5, 5), p.call(6.3, 7.3), p.call(5, 9), p.call(3.7, 7.3)]), Color(1, 1, 0.8, c.a))
		"goutte":
			ci.draw_colored_polygon(PackedVector2Array([p.call(5, 1), p.call(7.6, 5.5), p.call(7.2, 8), p.call(5, 9.3), p.call(2.8, 8), p.call(2.4, 5.5)]), c)
			ci.draw_arc(p.call(4.2, 6.8), u * 1.1, PI * 0.9, PI * 1.6, 8, Color(1, 1, 1, c.a * 0.7), 1.0)
		"roche":
			ci.draw_colored_polygon(PackedVector2Array([p.call(2, 8.5), p.call(1.5, 5), p.call(3.5, 2.5), p.call(6.5, 1.8), p.call(8.6, 4.5), p.call(8.2, 8.5)]), c)
			ci.draw_line(p.call(3.5, 2.5), p.call(4.8, 8.5), fin, 1.0)
			ci.draw_line(p.call(6.5, 1.8), p.call(5.2, 5.2), fin, 1.0)
		"eclat":
			ci.draw_colored_polygon(PackedVector2Array([p.call(5, 0.8), p.call(6.2, 4.2), p.call(9.2, 5), p.call(6.2, 5.8), p.call(5, 9.2), p.call(3.8, 5.8), p.call(0.8, 5), p.call(3.8, 4.2)]), c)
		"epine":
			ci.draw_line(p.call(5, 9.5), p.call(5, 1.5), c, 1.6)
			for k in 3:
				var y := 2.5 + k * 2.2
				ci.draw_line(p.call(5, y + 1.2), p.call(2.6, y), c, 1.4)
				ci.draw_line(p.call(5, y + 1.2), p.call(7.4, y), c, 1.4)
		"etoile":
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI / 2 + TAU * k / 10.0
				var rr := 4.2 if k % 2 == 0 else 1.8
				pts.append(p.call(5 + cos(a) * rr, 5 + sin(a) * rr))
			ci.draw_colored_polygon(pts, c)
		"soin":
			ci.draw_rect(Rect2(p.call(3.8, 1.5), Vector2(2.4 * u, 7 * u)), c)
			ci.draw_rect(Rect2(p.call(1.5, 3.8), Vector2(7 * u, 2.4 * u)), c)
		"chaine":
			ci.draw_arc(p.call(3.3, 5), u * 1.8, 0, TAU, 16, c, 1.6)
			ci.draw_arc(p.call(6.7, 5), u * 1.8, 0, TAU, 16, c, 1.6)
		"sablier":
			ci.draw_polyline(PackedVector2Array([p.call(2.5, 1.5), p.call(7.5, 1.5), p.call(3.5, 5), p.call(7.5, 8.5), p.call(2.5, 8.5), p.call(6.5, 5), p.call(2.5, 1.5)]), c, 1.4)
			ci.draw_colored_polygon(PackedVector2Array([p.call(3.6, 8.2), p.call(6.4, 8.2), p.call(5, 6.2)]), c)
		"bouclier":
			ci.draw_colored_polygon(PackedVector2Array([p.call(5, 1.2), p.call(8.5, 2.5), p.call(8, 6), p.call(5, 9.2), p.call(2, 6), p.call(1.5, 2.5)]), c)
			ci.draw_line(p.call(5, 2.2), p.call(5, 8), Color(0.05, 0.05, 0.08, c.a), 1.2)
		"fleche_droite":
			_fleche(ci, p.call(1.5, 5), p.call(8.5, 5), c)
		"fleche_gauche":
			_fleche(ci, p.call(8.5, 5), p.call(1.5, 5), c)
		"fleche_haut":
			_fleche(ci, p.call(5, 8.5), p.call(5, 1.5), c)
		"fleche_saut":
			ci.draw_arc(p.call(5, 7), u * 4.0, PI, TAU, 12, c, 1.6)
			_fleche(ci, p.call(8.6, 6.4), p.call(9, 7.6), c)
		"fleche_double":
			_fleche(ci, p.call(2, 3.5), p.call(8.5, 3.5), c)
			_fleche(ci, p.call(8, 6.5), p.call(1.5, 6.5), c)
		"fleche_retour":
			ci.draw_arc(p.call(5, 5), u * 3.5, -PI * 0.6, PI * 0.9, 14, c, 1.6)
			_fleche(ci, p.call(3.6, 8.2), p.call(2.2, 7.4), c)
			ci.draw_circle(p.call(5, 5), u * 1.0, c)
		"tourbillon":
			for k in 3:
				var a0 := TAU * k / 3.0
				ci.draw_arc(p.call(5, 5), u * 3.6, a0, a0 + 1.6, 8, c, 1.6)
				var fin_a := a0 + 1.6
				_fleche(ci, p.call(5 + cos(fin_a - 0.2) * 3.6, 5 + sin(fin_a - 0.2) * 3.6), p.call(5 + cos(fin_a) * 3.6, 5 + sin(fin_a) * 3.6), c)
		"porte":
			ci.draw_rect(Rect2(p.call(2.5, 1.5), Vector2(5 * u, 7.5 * u)), c, false, 1.6)
			ci.draw_arc(p.call(5, 4.2), u * 2.5, PI, TAU, 10, c, 1.6)
			ci.draw_circle(p.call(6.3, 5.5), u * 0.5, c)
		"monticule":
			ci.draw_colored_polygon(PackedVector2Array([p.call(1, 8.5), p.call(3.5, 3.5), p.call(5.5, 5), p.call(7, 2.5), p.call(9, 8.5)]), c)
		"fosse":
			ci.draw_rect(Rect2(p.call(1, 3), Vector2(8 * u, 1.2 * u)), c)
			ci.draw_colored_polygon(PackedVector2Array([p.call(2.5, 4.2), p.call(7.5, 4.2), p.call(6.5, 8.5), p.call(3.5, 8.5)]), fin)
		"bombe":
			ci.draw_circle(p.call(4.6, 6.2), u * 3.0, c)
			ci.draw_line(p.call(6.4, 3.8), p.call(8, 1.8), c, 1.4)
			ci.draw_circle(p.call(8.2, 1.6), u * 0.7, Color(1, 0.8, 0.3, c.a))
		"tourelle":
			ci.draw_rect(Rect2(p.call(2.5, 6), Vector2(5 * u, 3 * u)), c)
			ci.draw_rect(Rect2(p.call(3.5, 3.5), Vector2(3 * u, 2.8 * u)), c)
			ci.draw_line(p.call(5, 4.5), p.call(9, 2), c, 1.6)
		"patte":
			ci.draw_circle(p.call(5, 6.5), u * 2.0, c)
			for k in 4:
				ci.draw_circle(p.call(2.3 + k * 1.8, 3.2 - (0.6 if k in [1, 2] else 0.0)), u * 0.8, c)
		"crane":
			ci.draw_circle(p.call(5, 4.2), u * 3.0, c)
			ci.draw_rect(Rect2(p.call(3.5, 6.5), Vector2(3 * u, 2 * u)), c)
			ci.draw_circle(p.call(3.9, 4.0), u * 0.8, Color(0.05, 0.05, 0.08, c.a))
			ci.draw_circle(p.call(6.1, 4.0), u * 0.8, Color(0.05, 0.05, 0.08, c.a))
		"barriere":
			for k in 3:
				ci.draw_rect(Rect2(p.call(1.5 + (k % 2) * 1.2, 2 + k * 2.4), Vector2(6 * u, 2 * u)), c, false, 1.4)
		"lune":
			ci.draw_circle(p.call(5, 5), u * 3.8, c)
			ci.draw_circle(p.call(6.6, 4.2), u * 3.2, Color(0.05, 0.05, 0.08, c.a))
		"coeur":
			ci.draw_circle(p.call(3.5, 3.8), u * 2.0, c)
			ci.draw_circle(p.call(6.5, 3.8), u * 2.0, c)
			ci.draw_colored_polygon(PackedVector2Array([p.call(1.6, 4.6), p.call(8.4, 4.6), p.call(5, 9)]), c)
		"sang":
			ci.draw_colored_polygon(PackedVector2Array([p.call(5, 1), p.call(7.6, 5.5), p.call(7.2, 8), p.call(5, 9.3), p.call(2.8, 8), p.call(2.4, 5.5)]), Color(0.75, 0.1, 0.1, c.a))
		"balai":
			ci.draw_line(p.call(2, 8), p.call(7.5, 2.5), c, 1.6)
			ci.draw_colored_polygon(PackedVector2Array([p.call(1.2, 6.8), p.call(3.2, 8.8), p.call(1.6, 9.2)]), c)
		"oeil":
			ci.draw_arc(p.call(5, 5), u * 3.8, PI * 1.2, PI * 1.8, 10, c, 1.4)
			ci.draw_arc(p.call(5, 5), u * 3.8, PI * 0.2, PI * 0.8, 10, c, 1.4)
			ci.draw_circle(p.call(5, 5), u * 1.5, c)
		"oeil_barre":
			ci.draw_arc(p.call(5, 5), u * 3.8, PI * 1.2, PI * 1.8, 10, c, 1.4)
			ci.draw_arc(p.call(5, 5), u * 3.8, PI * 0.2, PI * 0.8, 10, c, 1.4)
			ci.draw_circle(p.call(5, 5), u * 1.5, c)
			ci.draw_line(p.call(1.5, 8.5), p.call(8.5, 1.5), Color(1, 0.3, 0.3, c.a), 1.8)
		"epee_brisee":
			ci.draw_line(p.call(2, 8), p.call(5, 5), c, 1.8)
			ci.draw_line(p.call(6, 4), p.call(8.5, 1.5), c, 1.8)
			ci.draw_line(p.call(1.5, 6.5), p.call(3.5, 8.5), c, 1.6)
		"main":
			ci.draw_rect(Rect2(p.call(3, 4.5), Vector2(4.5 * u, 4.5 * u)), c)
			for k in 4:
				ci.draw_rect(Rect2(p.call(3 + k * 1.15, 1.5 + (0.8 if k == 3 else 0.0)), Vector2(0.9 * u, 3.5 * u)), c)
		"soleil":
			ci.draw_circle(p.call(5, 5), u * 2.2, c)
			for k in 8:
				var a := TAU * k / 8.0
				ci.draw_line(p.call(5 + cos(a) * 3.0, 5 + sin(a) * 3.0), p.call(5 + cos(a) * 4.5, 5 + sin(a) * 4.5), c, 1.4)
		"segment":
			ci.draw_rect(Rect2(p.call(1.5, 3.5), Vector2(7 * u, 3 * u)), c, false, 1.4)
			ci.draw_rect(Rect2(p.call(1.5, 3.5), Vector2(2.3 * u, 3 * u)), c)
		"plus":
			ci.draw_line(p.call(5, 1.5), p.call(5, 8.5), c, 2.0)
			ci.draw_line(p.call(1.5, 5), p.call(8.5, 5), c, 2.0)
		"portee":
			_fleche(ci, p.call(1, 8.5), p.call(9, 1.5), c)
			ci.draw_arc(p.call(1, 8.5), u * 4.0, -PI * 0.5, 0.0, 8, fin, 1.0)
		"expansion":
			_fleche(ci, p.call(5, 5), p.call(1.5, 1.5), c)
			_fleche(ci, p.call(5, 5), p.call(8.5, 1.5), c)
			_fleche(ci, p.call(5, 5), p.call(1.5, 8.5), c)
			_fleche(ci, p.call(5, 5), p.call(8.5, 8.5), c)
		"horloge":
			ci.draw_arc(p.call(5, 5), u * 3.8, 0, TAU, 20, c, 1.4)
			ci.draw_line(p.call(5, 5), p.call(5, 2.2), c, 1.4)
			ci.draw_line(p.call(5, 5), p.call(7.2, 5.8), c, 1.4)
		"etincelle":
			for k in 4:
				var a := PI / 4 + TAU * k / 4.0
				ci.draw_line(p.call(5, 5), p.call(5 + cos(a) * 3.8, 5 + sin(a) * 3.8), c, 1.4)
			ci.draw_line(p.call(5, 1), p.call(5, 9), c, 1.8)
			ci.draw_line(p.call(1, 5), p.call(9, 5), c, 1.8)
		"forme":
			ci.draw_rect(Rect2(p.call(1.5, 1.5), Vector2(4 * u, 4 * u)), c, false, 1.4)
			ci.draw_circle(p.call(6.8, 6.8), u * 2.2, c)
		"cible":
			ci.draw_arc(p.call(5, 5), u * 3.8, 0, TAU, 20, c, 1.4)
			ci.draw_arc(p.call(5, 5), u * 1.8, 0, TAU, 12, c, 1.4)
			ci.draw_line(p.call(5, 0.8), p.call(5, 3), c, 1.2)
			ci.draw_line(p.call(5, 7), p.call(5, 9.2), c, 1.2)
			ci.draw_line(p.call(0.8, 5), p.call(3, 5), c, 1.2)
			ci.draw_line(p.call(7, 5), p.call(9.2, 5), c, 1.2)
		"monde":
			ci.draw_arc(p.call(5, 5), u * 3.8, 0, TAU, 20, c, 1.4)
			ci.draw_arc(p.call(5, 5), u * 3.8, PI * 0.5, PI * 1.5, 12, c, 1.0)
			ci.draw_line(p.call(1.2, 5), p.call(8.8, 5), c, 1.0)
			ci.draw_arc(p.call(5, 5), u * 3.8, -PI * 0.5, PI * 0.5, 12, fin, 1.0)
		"porteur":
			ci.draw_circle(p.call(5, 2.8), u * 1.6, c)
			ci.draw_colored_polygon(PackedVector2Array([p.call(2, 9), p.call(3, 5), p.call(7, 5), p.call(8, 9)]), c)
		"position":
			ci.draw_circle(p.call(5, 4), u * 2.8, c)
			ci.draw_colored_polygon(PackedVector2Array([p.call(2.6, 5.2), p.call(7.4, 5.2), p.call(5, 9.4)]), c)
			ci.draw_circle(p.call(5, 4), u * 1.1, Color(0.05, 0.05, 0.08, c.a))
		"evenement":
			ci.draw_colored_polygon(PackedVector2Array([p.call(6, 0.8), p.call(2.5, 5.5), p.call(4.8, 5.5), p.call(3.8, 9.2), p.call(7.5, 4.2), p.call(5.3, 4.2)]), c)
		"minuterie":
			ci.draw_polyline(PackedVector2Array([p.call(2.5, 1.5), p.call(7.5, 1.5), p.call(3.5, 5), p.call(7.5, 8.5), p.call(2.5, 8.5), p.call(6.5, 5), p.call(2.5, 1.5)]), c, 1.4)
		"liens":
			ci.draw_circle(p.call(2.2, 5), u * 1.2, c)
			ci.draw_circle(p.call(7.8, 3), u * 1.2, c)
			ci.draw_circle(p.call(7.8, 7), u * 1.2, c)
			ci.draw_line(p.call(2.2, 5), p.call(7.8, 3), c, 1.2)
			ci.draw_line(p.call(2.2, 5), p.call(7.8, 7), c, 1.2)
		"boucle":
			ci.draw_arc(p.call(5, 5), u * 3.5, 0.3, TAU - 0.6, 16, c, 1.6)
			_fleche(ci, p.call(5 + cos(0.6) * 3.5, 5 + sin(0.6) * 3.5), p.call(5 + cos(0.3) * 3.5, 5 + sin(0.3) * 3.5), c)
		_:
			ci.draw_rect(Rect2(p.call(2, 1.5), Vector2(6 * u, 7 * u)), c, false, 1.4)
			ci.draw_line(p.call(5, 1.5), p.call(5, 8.5), c, 1.0)


static func _fleche(ci: CanvasItem, a: Vector2, b: Vector2, c: Color) -> void:
	ci.draw_line(a, b, c, 1.6)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var l := (b - a).length() * 0.35
	ci.draw_colored_polygon(PackedVector2Array([b, b - d * l + n * l * 0.6, b - d * l - n * l * 0.6]), c)


## Une forme : ses tuiles sur une grille 5 × 5, le lanceur (bleu) en bas au centre, la cible au centre.
static func _forme(ci: CanvasItem, nom: String, r: Rect2, c: Color) -> void:
	var cell := r.size.x / 5.0
	var tuiles: Array = []
	var lanceur := Vector2i(2, 4)
	var cible := Vector2i(2, 2)
	match nom:
		"point": tuiles = [cible]
		"soi": tuiles = [lanceur]
		"tuile": tuiles = [cible]
		"ligne": tuiles = [Vector2i(2, 3), Vector2i(2, 2), Vector2i(2, 1), Vector2i(2, 0)]
		"cone": tuiles = [Vector2i(2, 3), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
		"croix": tuiles = [cible, Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)]
		"diagonale": tuiles = [cible, Vector2i(1, 1), Vector2i(3, 3), Vector2i(3, 1), Vector2i(1, 3)]
		"carre": tuiles = [cible, Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(3, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]
		"anneau": tuiles = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(3, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]
		"vague": tuiles = [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
		"mur": tuiles = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
		"sillage": tuiles = [Vector2i(2, 3), Vector2i(2, 2), Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1)]
		"chemin": tuiles = [Vector2i(2, 3), Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 1), Vector2i(4, 1)]
		"colonne": tuiles = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)]
		"horizon": tuiles = [Vector2i(0, 0), Vector2i(4, 0), Vector2i(1, 1), Vector2i(3, 2), Vector2i(0, 3), Vector2i(4, 3), Vector2i(2, 1)]
		"nuee": tuiles = [Vector2i(1, 1), Vector2i(3, 1), Vector2i(2, 2), Vector2i(1, 3), Vector2i(3, 3), Vector2i(4, 2)]
	for t in tuiles:
		ci.draw_rect(Rect2(r.position + Vector2(t.x * cell + 1.0, t.y * cell + 1.0), Vector2(cell - 2.0, cell - 2.0)), c)
	if nom != "soi":
		ci.draw_rect(Rect2(r.position + Vector2(lanceur.x * cell + 2.0, lanceur.y * cell + 2.0), Vector2(cell - 4.0, cell - 4.0)), Color(0.35, 0.6, 1.0, c.a))
