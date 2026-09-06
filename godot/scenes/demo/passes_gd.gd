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
		"veg_vus": PackedInt32Array(), "veg_voiles": PackedInt32Array()}


static func _indices(res: Dictionary) -> void:
	var idx := PackedInt32Array()
	idx.resize(res.points.size())
	for i in res.points.size():
		idx[i] = i
	res.indices = idx


## Le brouillard (main._dessiner_brouillard) : sur les tuiles découvertes autour du joueur (`jp`, `rayon`), hors de vue —
## un voile sur le sol, la silhouette sombre d'un bloc (trois faces à plat) sur un mur. `veg_vus` et `veg_voiles` : les
## index des végétaux vus et voilés, pour que le client règle leurs billboards.
static func brouillard(g: Grille, vue: Dictionary, tout_vu: bool, zj: int, vide_ci: int, jp: Vector2i, rayon: int, origine_dessin: Vector2i,
		tw: float, th: float, hstep: float, niveau_u: int, bat_j: int, mur_coupe_u: int, voile: Color, col_sil: Color) -> Dictionary:
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
			if not g.decouvert.has(idx):
				continue
			var ct := g.contenu_de(t)
			var vegetal: bool = "vegetation" in ct.get("tags", [])
			if voit(g, vue, tout_vu, zj, vide_ci, t):
				if vegetal:
					res.veg_vus.append(idx)
				continue
			var c := ecran(t, g.h(t), origine_dessin, tw, th, hstep)
			if vegetal:
				res.veg_voiles.append(idx)
			elif g.bloque_passage(t) and not ("porte" in ct.get("tags", [])):
				var hm := hauteur_bloc(g, t, bat_j, niveau_u, mur_coupe_u) * hstep
				if hm > 0:
					_poly(res, PackedVector2Array([c + Vector2(-tw2, 0), c + Vector2(0, th2), c + Vector2(0, th2 - hm), c + Vector2(-tw2, -hm)]), col_sil.darkened(0.35), PackedVector2Array())
					_poly(res, PackedVector2Array([c + Vector2(0, th2), c + Vector2(tw2, 0), c + Vector2(tw2, -hm), c + Vector2(0, th2 - hm)]), col_sil.darkened(0.5), PackedVector2Array())
					_poly(res, PackedVector2Array([c + Vector2(-tw2, -hm), c + Vector2(0, -th2 - hm), c + Vector2(tw2, -hm), c + Vector2(0, th2 - hm)]), col_sil, PackedVector2Array())
				continue
			_poly(res, PackedVector2Array([c + Vector2(-tw2, 0), c + Vector2(0, -th2), c + Vector2(tw2, 0), c + Vector2(0, th2)]), voile, PackedVector2Array())
	_indices(res)
	return res


## Les toits (main._dessiner_toits) : sur chaque tuile découverte d'une emprise, hors du bâtiment du joueur, un quadrilatère
## dont les coins s'élèvent avec leur distance au bord (pente, plat, pente), à la couleur du toit (`bat_couleurs`, par
## bâtiment), sombre si aucune tuile du bâtiment n'est en vue, le versant éclairé par le soleil ; les UV sont ceux du dessus.
static func toits(g: Grille, vue: Dictionary, tout_vu: bool, zj: int, vide_ci: int, jp: Vector2i, rayon: int, origine_dessin: Vector2i,
		tw: float, th: float, hstep: float, niveau_u: int, bat_j: int, bat_couleurs: PackedColorArray, bat_styles: PackedFloat32Array,
		pente_t: float, haut_toit: float, ombre_min: float, soleil_h: Vector2, soleil_ok: bool, soleil_force: float, uv_haut: float) -> Dictionary:
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
			if n == 0 or not g.decouvert.has(idx):
				continue
			var b: int = g.bat_de[idx]
			if b == bat_j or b <= 0 or b > bat_couleurs.size():
				continue
			var col: Color = bat_couleurs[b - 1]
			var st: float = bat_styles[b - 1] if b - 1 < bat_styles.size() else 0.0
			if not bool(vus.get(b, false)):
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
