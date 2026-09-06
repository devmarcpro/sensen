class_name PassesGD
extends RefCounted
## Les passes de dessin du client en GDScript pur (Modules de la simulation et le C++, file 114, 2026-09-06) : le brouillard
## et les toits bâtis en TABLEAUX DE TRIANGLES (points, couleurs, UV, indices) à soumettre d'un coup, sans toucher au
## CanvasItem. Ce sont les originaux de référence : le noyau C++ (`SensenGrille.brouillard`, `SensenGrille.toits`) les
## transcrit ligne à ligne, `test_noyau_cpp` prouve l'égalité des tableaux, et le client prend le noyau s'il est là,
## ceci sinon. Aucune règle de jeu ici : ce que le client passait à ses fonctions (rayon de vue, taille des tuiles,
## blocs par niveau, soleil) arrive en paramètres.


## Une tuile est-elle vue : sa position dans `vue` (les index du champ de vue du joueur), ou — depuis un étage — l'air
## au-dessus d'elle (Simulation.voit, les couches Z). `tout_vu` : le joueur n'a pas de champ de vue (tout se voit).
static func voit(g: Grille, vue: Dictionary, tout_vu: bool, zj: int, vide_ci: int, t: Vector2i) -> bool:
	if tout_vu:
		return true
	if vue.has(g.idx(t)):
		return true
	if zj > 0 and Grille.z_de(t) == 0:
		var ta := Grille.en_couche(t, zj)
		return g.dans(ta) and vue.has(g.idx(ta)) and g.contenu[g.idx(ta)] == vide_ci
	return false


## Ce que le client montre de chaque être (main._maj_noeuds, _dessiner_hud, _dessiner_etats) : bit 1, à portée (distance au
## sol ≤ rayon) et dans le champ de vue ; bit 2, et pas sous le toit d'un autre bâtiment ni d'un autre étage du sien.
static func visibles(g: Grille, vue: Dictionary, tout_vu: bool, zj: int, vide_ci: int, jp: Vector2i, rayon: int, bat_j: int, positions: PackedVector2Array) -> PackedByteArray:
	var res := PackedByteArray()
	res.resize(positions.size())
	var jz := Grille.z_de(jp)
	for k in positions.size():
		var t := Vector2i(int(positions[k].x), int(positions[k].y))
		var f := 0
		if Grille.distance_plate(t, jp) <= rayon and g.dans(t) and voit(g, vue, tout_vu, zj, vide_ci, t):
			f = 1
			var b := int(g.bat_de[g.idx(t)])
			if not (b > 0 and (b != bat_j or Grille.z_de(t) != jz)):
				f |= 2
		res[k] = f
	return res


## La hauteur dessinée du bloc d'une tuile, en unités (main._hauteur_bloc) : celle de son contenu, ou celle du bâtiment ;
## le mur sud ou est du bâtiment du joueur (`bat_j`) est un muret de `mur_coupe_u`.
static func hauteur_bloc(g: Grille, t: Vector2i, bat_j: int, niveau_u: int, mur_coupe_u: int) -> int:
	if not g.dans(t):
		return 0
	var ct := g.contenu_de(t)
	if not bool(ct.get("bloque_passage", false)) and not ("porte" in ct.get("tags", [])):
		return 0
	var tags: Array = ct.get("tags", [])
	if "vegetation" in tags:
		return 0
	var idx_t := g.idx(t)
	var n: int = g.niveaux_bat[idx_t]
	if n > 0 and ("mur" in tags or "porte" in tags):
		if bat_j > 0 and int(g.bat_de[idx_t]) == bat_j and bat_j <= g.batiments_liste.size():
			var r: Rect2i = g.batiments_liste[bat_j - 1].rect
			if t.y == r.end.y - 1 or t.x == r.end.x - 1:
				return mur_coupe_u
		return n * niveau_u
	return int(ct.get("hauteur_vue", 3))


## L'écran d'une tuile au sol (main._ecran, sans la couche : le brouillard et les toits sont au sol).
static func ecran(t: Vector2i, h: int, origine_dessin: Vector2i, tw: float, th: float, hstep: float) -> Vector2:
	var l: Vector2i = t - origine_dessin
	return Vector2((l.x - l.y) * tw * 0.5, (l.x + l.y) * th * 0.5 - h * hstep)


## Un polygone convexe en éventail de triangles, comme LotTriangles.ajouter.
static func _poly(res: Dictionary, pts: PackedVector2Array, col: Color, uvs: PackedVector2Array) -> void:
	var avec_uv := uvs.size() == pts.size()
	for i in range(1, pts.size() - 1):
		res.points.append(pts[0])
		res.points.append(pts[i])
		res.points.append(pts[i + 1])
		res.couleurs.append(col)
		res.couleurs.append(col)
		res.couleurs.append(col)
		if avec_uv:
			res.uvs.append(uvs[0])
			res.uvs.append(uvs[i])
			res.uvs.append(uvs[i + 1])
		else:
			res.uvs.append(Vector2.ZERO)
			res.uvs.append(Vector2.ZERO)
			res.uvs.append(Vector2.ZERO)


static func _vide() -> Dictionary:
	return {"points": PackedVector2Array(), "couleurs": PackedColorArray(), "uvs": PackedVector2Array(), "indices": PackedInt32Array(),
		"veg_vus": PackedInt32Array(), "veg_voiles": PackedInt32Array(), "veg_noirs": PackedInt32Array()}


static func _indices(res: Dictionary) -> void:
	var idx := PackedInt32Array()
	idx.resize(res.points.size())
	for i in res.points.size():
		idx[i] = i
	res.indices = idx


## Le brouillard (main._dessiner_brouillard, designer 2026-09-06, 23 h : « ne pas voir le fond gris, tous les blocs rendus avec
## leurs textures ») : sur TOUTES les tuiles autour du joueur (`jp`, `rayon`) hors de vue — un voile sur le sol, un voile sur
## les trois faces d'un bloc (sa matière reste dessous) ; `voile` sur une tuile mémorisée, `voile_jamais` (plus sombre) sur
## une tuile jamais vue. `veg_vus`, `veg_voiles`, `veg_noirs` : les index des végétaux vus, voilés, jamais vus, pour que le
## client règle leurs billboards.
static func brouillard(g: Grille, vue: Dictionary, tout_vu: bool, zj: int, vide_ci: int, jp: Vector2i, rayon: int, origine_dessin: Vector2i,
		tw: float, th: float, hstep: float, niveau_u: int, bat_j: int, mur_coupe_u: int, voile: Color, voile_jamais: Color) -> Dictionary:
	var res := _vide()
	var x0 := maxi(g.origine.x, jp.x - rayon)
	var x1 := mini(g.origine.x + g.largeur - 1, jp.x + rayon)
	var y0 := maxi(g.origine.y, jp.y - rayon)
	var y1 := mini(g.origine.y + g.hauteur_grille - 1, jp.y + rayon)
	var tw2 := tw * 0.5
	var th2 := th * 0.5
	for s in range(x0 + y0, x1 + y1 + 1):
		for x in range(maxi(x0, s - y1), mini(x1, s - y0) + 1):
			var t := Vector2i(x, s - x)
			var idx := g.idx(t)
			var decouverte := g.decouvert.has(idx)
			var ct := g.contenu_de(t)
			var vegetal: bool = "vegetation" in ct.get("tags", [])
			if decouverte and voit(g, vue, tout_vu, zj, vide_ci, t):
				if vegetal:
					res.veg_vus.append(idx)
				continue
			var col := voile if decouverte else voile_jamais
			var c := ecran(t, g.h(t), origine_dessin, tw, th, hstep)
			if vegetal:
				if decouverte:
					res.veg_voiles.append(idx)
				else:
					res.veg_noirs.append(idx)
			elif g.bloque_passage(t) and not ("porte" in ct.get("tags", [])):
				var hm := hauteur_bloc(g, t, bat_j, niveau_u, mur_coupe_u) * hstep
				if hm > 0:   # le voile sur les trois faces du bloc : sa matière reste dessous
					_poly(res, PackedVector2Array([c + Vector2(-tw2, 0), c + Vector2(0, th2), c + Vector2(0, th2 - hm), c + Vector2(-tw2, -hm)]), col, PackedVector2Array())
					_poly(res, PackedVector2Array([c + Vector2(0, th2), c + Vector2(tw2, 0), c + Vector2(tw2, -hm), c + Vector2(0, th2 - hm)]), col, PackedVector2Array())
					_poly(res, PackedVector2Array([c + Vector2(-tw2, -hm), c + Vector2(0, -th2 - hm), c + Vector2(tw2, -hm), c + Vector2(0, th2 - hm)]), col, PackedVector2Array())
				continue
			_poly(res, PackedVector2Array([c + Vector2(-tw2, 0), c + Vector2(0, -th2), c + Vector2(tw2, 0), c + Vector2(0, th2)]), col, PackedVector2Array())
	_indices(res)
	return res


## Les toits (main._dessiner_toits) : sur chaque tuile découverte d'une emprise, hors du bâtiment du joueur, un quadrilatère
## dont les coins s'élèvent avec leur distance au bord (pente, plat, pente), à la couleur du toit (`bat_couleurs`, par
## bâtiment), sombre si aucune tuile du bâtiment n'est en vue, le versant éclairé par le soleil ; les UV sont ceux du dessus.
static func toits(g: Grille, vue: Dictionary, tout_vu: bool, zj: int, vide_ci: int, jp: Vector2i, rayon: int, origine_dessin: Vector2i,
		tw: float, th: float, hstep: float, niveau_u: int, bat_j: int, bat_couleurs: PackedColorArray, bat_styles: PackedFloat32Array,
		pente_t: float, haut_toit: float, ombre_min: float, soleil_h: Vector2, soleil_ok: bool, soleil_force: float, uv_haut: float, sombre_jamais: float = 0.75) -> Dictionary:
	var res := _vide()
	if g.batiments_liste.is_empty():
		_indices(res)
		return res
	var x0 := maxi(g.origine.x, jp.x - rayon)
	var x1 := mini(g.origine.x + g.largeur - 1, jp.x + rayon)
	var y0 := maxi(g.origine.y, jp.y - rayon)
	var y1 := mini(g.origine.y + g.hauteur_grille - 1, jp.y + rayon)
	var vus := {}
	for b in range(1, g.batiments_liste.size() + 1):
		var r: Rect2i = g.batiments_liste[b - 1].rect
		if r.position.x > x1 or r.end.x <= x0 or r.position.y > y1 or r.end.y <= y0:
			continue
		var vu := false
		for y in r.size.y:
			for x in r.size.x:
				if voit(g, vue, tout_vu, zj, vide_ci, r.position + Vector2i(x, y)):
					vu = true
					break
			if vu:
				break
		vus[b] = vu
	for s_d in range(x0 + y0, x1 + y1 + 1):
		for x in range(maxi(x0, s_d - y1), mini(x1, s_d - y0) + 1):
			var t := Vector2i(x, s_d - x)
			var idx := g.idx(t)
			var n: int = g.niveaux_bat[idx]
			if n == 0:
				continue
			var b: int = g.bat_de[idx]
			if b == bat_j or b <= 0 or b > bat_couleurs.size():
				continue
			var col: Color = bat_couleurs[b - 1]
			var st: float = bat_styles[b - 1] if b - 1 < bat_styles.size() else 0.0
			if not g.decouvert.has(idx):   # jamais vu : le toit, très sombre (plus de fond gris, 2026-09-06)
				col = col.darkened(sombre_jamais)
			elif not bool(vus.get(b, false)):
				col = col.darkened(0.55)
			var r: Rect2i = g.batiments_liste[b - 1].rect
			var base_px := float(g.h(t) * hstep + n * niveau_u * hstep)
			var coins := [Vector2i(t.x, t.y), Vector2i(t.x + 1, t.y), Vector2i(t.x + 1, t.y + 1), Vector2i(t.x, t.y + 1)]
			var pts := PackedVector2Array()
			var eleves: Array[float] = []
			for cn in coins:
				var d := mini(mini(cn.x - r.position.x, r.end.x - cn.x), mini(cn.y - r.position.y, r.end.y - cn.y))
				var eleve := minf(float(d), pente_t) / pente_t * haut_toit
				eleves.append(eleve)
				var l: Vector2i = cn - origine_dessin
				pts.append(Vector2((l.x - l.y) * tw * 0.5, (l.x + l.y) * th * 0.5 - th * 0.5 - base_px - eleve))
			var col_v := col
			if soleil_ok:
				var gx := (eleves[1] + eleves[2] - eleves[0] - eleves[3]) * 0.5
				var gy := (eleves[2] + eleves[3] - eleves[0] - eleves[1]) * 0.5
				if absf(gx) + absf(gy) > 0.01:
					var dehors := Vector2(-gx, -gy).normalized()
					var n_ecran := Vector2((dehors.x - dehors.y) / sqrt(2.0), (dehors.x + dehors.y) / sqrt(2.0))
					var lambert := clampf(n_ecran.dot(soleil_h), 0.0, 1.0)
					col_v = col * lerpf(1.0, lerpf(ombre_min, 1.0, lambert), soleil_force)
					col_v.a = col.a
			var l0: Vector2i = t - origine_dessin
			var uvs := PackedVector2Array([Vector2(st + l0.x, uv_haut + l0.y), Vector2(st + l0.x + 1, uv_haut + l0.y), Vector2(st + l0.x + 1, uv_haut + l0.y + 1), Vector2(st + l0.x, uv_haut + l0.y + 1)])
			_poly(res, pts, col_v, uvs)
	_indices(res)
	return res


# ---------------------------------------------------------------- les morceaux de terrain (main._dessiner_morceau, _dessine_tuile, _dessine_bloc, _dessiner_porte)

## Le mur sud ou est du bâtiment du joueur (main._mur_coupe).
static func mur_coupe(g: Grille, t: Vector2i, bat_j: int) -> bool:
	if bat_j <= 0 or bat_j > g.batiments_liste.size() or not g.dans(t):
		return false
	if int(g.bat_de[g.idx(t)]) != bat_j:
		return false
	var r: Rect2i = g.batiments_liste[bat_j - 1].rect
	return t.y == r.end.y - 1 or t.x == r.end.x - 1


static func _uv_haut(p: Dictionary, t: Vector2i, dx: float, dy: float, st: float) -> Vector2:
	var l: Vector2i = Grille.plat(t) - p.origine_dessin
	return Vector2(st + l.x + dx, float(p.uv_haut) + l.y + dy)


static func _uv_so(p: Dictionary, t: Vector2i, dx: float, hh: float, st: float) -> Vector2:
	var l: Vector2i = Grille.plat(t) - p.origine_dessin
	return Vector2(st + l.x + dx, float(p.uv_so) - (l.y * float(p.uv_pas_face) + hh))


static func _uv_se(p: Dictionary, t: Vector2i, dy: float, hh: float, st: float) -> Vector2:
	var l: Vector2i = Grille.plat(t) - p.origine_dessin
	return Vector2(st + l.y + dy, float(p.uv_se) - (l.x * float(p.uv_pas_face) + hh))


## Une coupure du lot : à `nb` points, la tuile `idx` a besoin d'une commande que les triangles ne portent pas
## (1 : la traverse et la poignée d'une porte ; 2 : un contenant ; 3 : le sprite d'un meuble ou d'une station).
static func _coupure(res: Dictionary, idx: int, genre: int) -> void:
	res.coupures.append(res.points.size())
	res.coupures.append(idx)
	res.coupures.append(genre)


## Un bloc de mur (main._dessine_bloc) : le dessus et les deux faces avant, par bandes de matériaux pour une façade.
static func _bloc(res: Dictionary, g: Grille, t: Vector2i, c: Vector2, teinte: Color, base_u: int, plafond_u: int, p: Dictionary) -> void:
	var hstep: float = p.hstep
	var contenu_t := g.contenu_de(t)
	var tags_t: Array = contenu_t.get("tags", [])
	var idx_t := g.idx(t)
	var n_bat: int = g.niveaux_bat[idx_t]
	var mur_bat := n_bat > 0 and ("mur" in tags_t or "porte" in tags_t)
	var hm := int((n_bat * int(p.niveau_u) if mur_bat else int(contenu_t.get("hauteur_vue", 3))) * hstep)
	if plafond_u > 0:
		hm = mini(hm, int(plafond_u * hstep))
	var haut_bloc := Color(0.5, 0.47, 0.44)
	var mat_id := g.materiau_de(t)
	var b_idx := int(g.bat_de[idx_t])
	if mur_bat and "porte" in tags_t:
		mat_id = str(p.bat_mur_id[b_idx - 1])
	var mat_col: Dictionary = p.mat_col
	var mat_st: Dictionary = p.mat_st
	var a_mat := mat_col.has(mat_id)
	var emprise := 1.0
	if "meuble" in tags_t and g.meubles.has(idx_t):
		var mid := str(g.meubles[idx_t])
		haut_bloc = p.meuble_col.get(mid, haut_bloc)
		emprise = float(p.meuble_emprise.get(mid, 0.6))
		hm = int(roundf(float(hm) * emprise))
	elif contenu_t.has("couleur") and not mur_bat:
		haut_bloc = p.contenu_col[g.contenu[idx_t]]
	elif "arbre" in tags_t:
		haut_bloc = Color(0.22, 0.45, 0.18).lerp(mat_col[mat_id] if a_mat else haut_bloc, 0.2)
	elif a_mat:
		haut_bloc = haut_bloc.lerp(mat_col[mat_id], 0.55 if g.materiaux.has(idx_t) or mur_bat else 0.35)
	haut_bloc *= teinte
	var mat_bloc := mat_id
	if mat_bloc.is_empty():
		mat_bloc = str(p.materiau_mur_defaut)
	var st_bloc := float(mat_st.get(mat_bloc, 0.0))
	var tw := float(p.tw) * 0.5 * emprise
	var th := float(p.th) * 0.5 * emprise
	var h0 := int(base_u * hstep)
	var sud := t + Vector2i(0, 1)
	var est := t + Vector2i(1, 0)
	var face_so := not (g.dans(sud) and hauteur_bloc(g, sud, int(p.bat_j), int(p.niveau_u), int(p.mur_coupe_u)) * hstep >= hm)
	var face_se := not (g.dans(est) and hauteur_bloc(g, est, int(p.bat_j), int(p.niveau_u), int(p.mur_coupe_u)) * hstep >= hm)
	var bande := int(int(p.bloc_u) * hstep) if mur_bat else hm
	var y := h0
	var col_haut := haut_bloc
	var st_haut := st_bloc
	while y < hm:
		var y1 := mini(hm, y + bande)
		var col_b := haut_bloc
		var st_b := st_bloc
		if mur_bat:
			@warning_ignore("integer_division")
			var bloc_k := y / int(int(p.bloc_u) * hstep)
			var bois := str(p.bat_bois_id[b_idx - 1])
			var mat_b := bois if (bloc_k > 0 and not bois.is_empty()) else str(p.bat_pierre_id[b_idx - 1])
			if mat_b.is_empty():
				mat_b = mat_id
			if mat_col.has(mat_b):
				col_b = Color(0.5, 0.47, 0.44).lerp(mat_col[mat_b], 0.65) * teinte
			st_b = float(mat_st.get(mat_b, 0.0))
		if face_so:
			_poly(res, PackedVector2Array([c + Vector2(-tw, -y), c + Vector2(0, th - y), c + Vector2(0, th - y1), c + Vector2(-tw, -y1)]), col_b.darkened(0.35),
				PackedVector2Array([_uv_so(p, t, 0, float(y) / hstep, st_b), _uv_so(p, t, 1, float(y) / hstep, st_b), _uv_so(p, t, 1, float(y1) / hstep, st_b), _uv_so(p, t, 0, float(y1) / hstep, st_b)]))
		if face_se:
			_poly(res, PackedVector2Array([c + Vector2(0, th - y), c + Vector2(tw, -y), c + Vector2(tw, -y1), c + Vector2(0, th - y1)]), col_b.darkened(0.5),
				PackedVector2Array([_uv_se(p, t, 0, float(y) / hstep, st_b), _uv_se(p, t, 1, float(y) / hstep, st_b), _uv_se(p, t, 1, float(y1) / hstep, st_b), _uv_se(p, t, 0, float(y1) / hstep, st_b)]))
		col_haut = col_b
		st_haut = st_b
		y = y1
	_poly(res, PackedVector2Array([c + Vector2(-tw, -hm), c + Vector2(0, -th - hm), c + Vector2(tw, -hm), c + Vector2(0, th - hm)]), col_haut,
		PackedVector2Array([_uv_haut(p, t, 0, 1, st_haut), _uv_haut(p, t, 0, 0, st_haut), _uv_haut(p, t, 1, 0, st_haut), _uv_haut(p, t, 1, 1, st_haut)]))


## Les montants et le battant d'une porte (main._dessiner_porte) ; la traverse et la poignée sont une coupure (genre 1).
static func _porte(res: Dictionary, g: Grille, t: Vector2i, c: Vector2, contenu: Dictionary, teinte: Color, p: Dictionary) -> void:
	var hstep: float = p.hstep
	var bois: Color = p.contenu_col[g.contenu[g.idx(t)]] * teinte
	var mur_x: bool = (g.dans(t + Vector2i(1, 0)) and g.bloque_passage(t + Vector2i(1, 0))) or (g.dans(t - Vector2i(1, 0)) and g.bloque_passage(t - Vector2i(1, 0)))
	var demi := Vector2(float(p.tw) * 0.25, float(p.th) * 0.25) if mur_x else Vector2(float(p.tw) * 0.25, -float(p.th) * 0.25)
	var a := c - demi
	var b := c + demi
	var haut := Vector2(0.0, -float(int(p.porte_u) if g.niveaux_bat[g.idx(t)] > 0 else int(contenu.get("hauteur_vue", 2))) * hstep)
	var uv_p := PackedVector2Array([_uv_haut(p, t, 0.5, 0.5, 0.0), _uv_haut(p, t, 0.5, 0.5, 0.0), _uv_haut(p, t, 0.5, 0.5, 0.0), _uv_haut(p, t, 0.5, 0.5, 0.0)])
	for m in [a, b]:
		_poly(res, PackedVector2Array([m + Vector2(-1.5, 0), m + Vector2(1.5, 0), m + Vector2(1.5, 0) + haut, m + Vector2(-1.5, 0) + haut]), bois.darkened(0.45), uv_p)
	var ferme: bool = "fermee" in contenu.get("tags", [])
	var p0 := a if ferme else a.lerp(b, 0.68)
	var p1 := b
	_poly(res, PackedVector2Array([p0, p1, p1 + haut, p0 + haut]), bois, uv_p)
	_poly(res, PackedVector2Array([p0, p1, p1 + haut * 0.08, p0 + haut * 0.08]), bois.darkened(0.3), uv_p)
	_coupure(res, g.idx(t), 1)


## Une tuile (main._dessine_tuile) : l'eau, un bloc, sinon le losange du sol et ses flancs, un contenu franchissable,
## une porte, un contenant.
static func _tuile(res: Dictionary, g: Grille, t: Vector2i, p: Dictionary) -> void:
	var h := g.h(t)
	var c := ecran(t, h, p.origine_dessin, float(p.tw), float(p.th), float(p.hstep))
	var teinte := Color.WHITE
	var idx_t := g.idx(t)
	var ci_t: int = g.contenu[idx_t]
	var contenu := g.contenu_de(t)
	var tags_c: Array = contenu.get("tags", [])
	var tw := float(p.tw)
	var th := float(p.th)
	var hstep: float = p.hstep
	if "liquide" in tags_c:
		var col_eau: Color = p.contenu_col[ci_t]
		if "ecoulement" in tags_c:
			col_eau = col_eau.lerp(Color(0.6, 0.8, 0.95), 1.0 - float(g.niveau_liquide(t)) / 8.0)
		if g.gel:
			col_eau = col_eau.lerp(Color(0.85, 0.92, 1.0), 0.7)
		var st_eau := float(p.mat_st.get("eau", 0.0))
		_poly(res, PackedVector2Array([c + Vector2(0, -th * 0.5), c + Vector2(tw * 0.5, 0), c + Vector2(0, th * 0.5), c + Vector2(-tw * 0.5, 0)]),
			col_eau * teinte, PackedVector2Array([_uv_haut(p, t, 0, 0, st_eau), _uv_haut(p, t, 1, 0, st_eau), _uv_haut(p, t, 1, 1, st_eau), _uv_haut(p, t, 0, 1, st_eau)]))
		return
	if g.neige:
		teinte = teinte.lerp(Color(1.4, 1.4, 1.5), 0.5)
	if g.bloque_passage(t) and not ("vegetation" in tags_c) and not ("porte" in tags_c):
		_bloc(res, g, t, c, teinte, 0, int(p.mur_coupe_u) if mur_coupe(g, t, int(p.bat_j)) else 0, p)
		if g.meubles.has(idx_t) or g.stations_fixes.has(idx_t):
			_coupure(res, idx_t, 3)
		return
	var k := clampf((h - 4) / 12.0, 0.0, 1.0)
	var col := Color(0.20, 0.34, 0.18).lerp(Color(0.62, 0.66, 0.42), k)
	var sol_id := g.materiau_sol(t)
	if not sol_id.is_empty() and p.mat_col.has(sol_id):
		col = (p.mat_col[sol_id] as Color).lerp(Color(0.35, 0.5, 0.25), 0.35 if sol_id.begins_with("terre") else 0.0).darkened(0.25 - k * 0.3)
	col *= teinte
	var st_sol := float(p.mat_st.get(sol_id, 0.0))
	_poly(res, PackedVector2Array([c + Vector2(0, -th * 0.5), c + Vector2(tw * 0.5, 0), c + Vector2(0, th * 0.5), c + Vector2(-tw * 0.5, 0)]), col,
		PackedVector2Array([_uv_haut(p, t, 0, 0, st_sol), _uv_haut(p, t, 1, 0, st_sol), _uv_haut(p, t, 1, 1, st_sol), _uv_haut(p, t, 0, 1, st_sol)]))
	var flanc := col.darkened(0.35)
	var hs := g.h(t + Vector2i(0, 1)) if g.dans(t + Vector2i(0, 1)) else 0
	if hs < h:
		var d := (h - hs) * hstep
		_poly(res, PackedVector2Array([c + Vector2(-tw * 0.5, 0), c + Vector2(0, th * 0.5), c + Vector2(0, th * 0.5 + d), c + Vector2(-tw * 0.5, d)]), flanc,
			PackedVector2Array([_uv_so(p, t, 0, h, st_sol), _uv_so(p, t, 1, h, st_sol), _uv_so(p, t, 1, hs, st_sol), _uv_so(p, t, 0, hs, st_sol)]))
	var he := g.h(t + Vector2i(1, 0)) if g.dans(t + Vector2i(1, 0)) else 0
	if he < h:
		var d2 := (h - he) * hstep
		_poly(res, PackedVector2Array([c + Vector2(0, th * 0.5), c + Vector2(tw * 0.5, 0), c + Vector2(tw * 0.5, d2), c + Vector2(0, th * 0.5 + d2)]), flanc.darkened(0.15),
			PackedVector2Array([_uv_se(p, t, 0, h, st_sol), _uv_se(p, t, 1, h, st_sol), _uv_se(p, t, 1, he, st_sol), _uv_se(p, t, 0, he, st_sol)]))
	if not contenu.is_empty() and not g.bloque_passage(t) and not ("porte" in tags_c) and (contenu.has("couleur") or "meuble" in tags_c):
		var cf: Color = p.meuble_col.get(str(g.meubles.get(idx_t, "tapis")), Color.WHITE) if "meuble" in tags_c else p.contenu_col[ci_t]
		_poly(res, PackedVector2Array([c + Vector2(0, -th * 0.35), c + Vector2(tw * 0.35, 0), c + Vector2(0, th * 0.35), c + Vector2(-tw * 0.35, 0)]), cf * teinte,
			PackedVector2Array([_uv_haut(p, t, 0.15, 0.15, 0.0), _uv_haut(p, t, 0.85, 0.15, 0.0), _uv_haut(p, t, 0.85, 0.85, 0.0), _uv_haut(p, t, 0.15, 0.85, 0.0)]))
		if g.meubles.has(idx_t) or g.stations_fixes.has(idx_t):
			_coupure(res, idx_t, 3)
	if "porte" in tags_c:
		if mur_coupe(g, t, int(p.bat_j)):
			var cs: Color = p.contenu_col[ci_t] * teinte
			_poly(res, PackedVector2Array([c + Vector2(0, -th * 0.35), c + Vector2(tw * 0.35, 0), c + Vector2(0, th * 0.35), c + Vector2(-tw * 0.35, 0)]), cs,
				PackedVector2Array([_uv_haut(p, t, 0.15, 0.15, 0.0), _uv_haut(p, t, 0.85, 0.15, 0.0), _uv_haut(p, t, 0.85, 0.85, 0.0), _uv_haut(p, t, 0.15, 0.85, 0.0)]))
		else:
			_porte(res, g, t, c, contenu, teinte, p)
			if g.niveaux_bat[idx_t] > 0:
				_bloc(res, g, t, c, teinte, int(p.porte_u), 0, p)
	if "contenant" in tags_c:
		_coupure(res, idx_t, 2)


## Un morceau de terrain (main._dessiner_morceau) : ses tuiles découvertes dans l'ordre des diagonales ; les triangles, les
## coupures (les commandes que les triangles ne portent pas, dans l'ordre), et les végétaux à dresser en billboards.
static func morceau(g: Grille, coin: Vector2i, taille_morceau: int, p: Dictionary) -> Dictionary:
	var res := _vide()
	res["coupures"] = PackedInt32Array()
	res["vegetaux"] = PackedInt32Array()
	var x0: int = g.origine.x + coin.x * taille_morceau
	var y0: int = g.origine.y + coin.y * taille_morceau
	var x1 := mini(g.origine.x + g.largeur - 1, x0 + taille_morceau - 1)
	var y1 := mini(g.origine.y + g.hauteur_grille - 1, y0 + taille_morceau - 1)
	for s in range(x0 + y0, x1 + y1 + 1):
		for x in range(maxi(x0, s - y1), mini(x1, s - y0) + 1):
			var t := Vector2i(x, s - x)
			var idx := g.idx(t)
			_tuile(res, g, t, p)   # toutes les tuiles, vues ou non (designer 2026-09-06, 23 h : plus de fond gris — le brouillard voile)
			if "vegetation" in g.contenu_de(t).get("tags", []):
				res.vegetaux.append(idx)
	_indices(res)
	return res
