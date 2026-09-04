extends RefCounted
## Une grande base bâtie par le code du jeu, pour la sonde et la capture (designer, 2026-09-04, 14 h :
## « simule une grande base sur plusieurs cases avec une vingtaine de résidents, des zones de récolte »).
## Plusieurs cellules revendiquées d'affilée, des zones de récolte dessinées sur les tuiles les plus
## riches de chaque cellule, deux stockages, un résidentiel, une vingtaine d'engagés répartis sur les
## postes — puis des semaines qui passent par `_tiquer_monde`, comme dans une partie. Les tailles de
## zones ci-dessous sont des choix de la sonde ; tout ce qui est du jeu (types, coûts, cadences) vient
## de `combat_rules.royaume`.

const TAILLE_ZONE := {"bois": Vector2i(12, 8), "minerai": Vector2i(10, 6), "plantes": Vector2i(10, 6)}
const SEUIL_ZONE := {"bois": 12, "minerai": 4, "plantes": 8}
const MAX_ZONES := {"bois": 3, "minerai": 2, "plantes": 2}
const RESIDENTIEL := Vector2i(24, 12)
const STOCKAGE := Vector2i(4, 4)
const N_STOCKAGES := 2
const PAR_ZONE := 2   # récoltants par zone de récolte
const AUTRES_POSTES: Array[String] = ["commercant", "commercant", "artisan", "artisan", "fermier", "fermier", "garde"]


## Bâtit la base autour du camp. `n_residents` engagés ; `tresor` versé au territoire. Retourne le compte-rendu.
static func batir(s: Simulation, j: Dictionary, n_residents: int, tresor: int) -> Dictionary:
	var ry: Dictionary = s.regles.r.royaume
	var types: Dictionary = ry.perimetres.types
	var camp: Vector2i = s.monde.cellule_camp
	var rapport := {"cellules": [], "zones": [], "stockages": [], "residentiel": {}, "postes": {}, "refus": []}
	# 1. Les cellules : le camp, puis les voisines une à une (revendiquer demande l'exploration, la contiguïté et l'or).
	var cellules: Array[Vector2i] = [camp]
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		if cellules.size() >= 5:
			break
		var c: Vector2i = camp + d
		var n_sub: int = s.monde.taille / 32
		for cy in n_sub:
			for cx in n_sub:
				s.monde.explores[Vector2i(c.x * n_sub + cx, c.y * n_sub + cy)] = true
		j.or = int(j.or) + int(ry.claim_cout_par_cellule) * s.monde.claims.size()
		if s.revendiquer(j, c):
			cellules.append(c)
		else:
			rapport.refus.append("cellule (%d,%d) refusée (eau ou non contiguë)" % [c.x, c.y])
	# 2. Les zones de récolte : par cellule, le rectangle le plus riche de chaque type, sur des tuiles encore libres.
	var compte := {"bois": 0, "minerai": 0, "plantes": 0}
	var pris := {}   # tuile monde → true, pour que les zones ne se chevauchent pas
	for c in cellules:
		for type in ["bois", "minerai", "plantes"]:
			if compte[type] >= int(MAX_ZONES[type]):
				continue
			var tag := str(types[type].tag)
			var meilleur := _meilleur_rectangle(s, c, TAILLE_ZONE[type], pris, func(p: Vector2i) -> int: return 1 if tag in s.grille.contenu_de(p).get("tags", []) else 0, -1)
			if meilleur.is_empty() or int(meilleur.somme) < int(SEUIL_ZONE[type]):
				continue
			var pid := s.dessiner_perimetre(meilleur.a, meilleur.b, type)
			if pid.is_empty():
				continue
			_marquer(pris, meilleur.a, meilleur.b)
			compte[type] += 1
			var per: Dictionary = s.perimetres()[pid]
			rapport.zones.append({"pid": pid, "type": type, "cellule": c, "richesse": int(per.richesse), "reserve": float(per.reserve), "dominant": str(per.dominant)})
		if c != camp and (compte.bois > 0 or compte.minerai > 0):
			s.changer_role(c, "ressources")   # la réserve y repousse chaque semaine (Rôles de cases)
	# 3. Le résidentiel et les stockages, sur le sol libre du camp, au plus près du joueur.
	var libre := func(p: Vector2i) -> int:
		if s.grille.bloque_passage(p) or not s.grille.occupant(p).is_empty() or s.grille.meubles.has(s.grille.idx(p)):
			return 0
		var tags: Array = s.grille.contenu_de(p).get("tags", [])
		return 0 if ("liquide" in tags or "construit" in tags or "arbre" in tags) else 1
	var res := _meilleur_rectangle(s, camp, RESIDENTIEL, pris, libre, RESIDENTIEL.x * RESIDENTIEL.y * 8 / 10, j.pos)
	var pid_res := ""
	if not res.is_empty():
		pid_res = s.dessiner_perimetre(res.a, res.b, "residentiel")
		_marquer(pris, res.a, res.b)
		rapport.residentiel = {"pid": pid_res, "tuiles_libres": int(s.perimetres()[pid_res].richesse), "a": res.a, "b": res.b}
	var stockages: Array[String] = []
	for k in N_STOCKAGES:
		var st := _meilleur_rectangle(s, camp, STOCKAGE, pris, libre, STOCKAGE.x * STOCKAGE.y, j.pos)
		if st.is_empty():
			break
		var pid_s := s.dessiner_perimetre(st.a, st.b, "stockage")
		if pid_s.is_empty():
			break
		_marquer(pris, st.a, st.b)
		stockages.append(pid_s)
		rapport.stockages.append({"pid": pid_s, "capacite": int(s.perimetres()[pid_s].capacite), "a": st.a})
	for z in rapport.zones:   # un stockage par poste : les zones se partagent les stockages
		if not stockages.is_empty():
			s.assigner_stockage(str(z.pid), stockages[rapport.zones.find(z) % stockages.size()])
	# 4. Les engagés : des villageois qui passent par `_engager` (or, installation à la base), puis leurs postes.
	var tick: int = s.horloge_monde.ticks
	var engages: Array = []
	for k in n_residents:
		var q := _libre_pres(s, j.pos)
		if q == Vector2i(-1, -1):
			rapport.refus.append("plus de tuile libre près du joueur pour engager")
			break
		var x: Dictionary = s.ajouter("villageois", q, "ia")
		if x.is_empty():
			break
		x["recrutable_hors_condition"] = true
		j.or = int(j.or) + int(ry.engagement.or)
		if s._engager(j, x.id, tick):
			engages.append(x)
		else:
			rapport.refus.append("engagement refusé pour %s" % str(x.id))
	var i := 0
	for z in rapport.zones:
		var fonction := str(types[str(z.type)].fonction)
		for k in PAR_ZONE:
			if i < engages.size():
				s._assigner(j, engages[i].id, fonction, tick, str(z.pid))
				i += 1
	for f in AUTRES_POSTES:
		if i < engages.size():
			s._assigner(j, engages[i].id, f, tick)
			i += 1
	for x in engages:   # tous logés au résidentiel : une maison s'y bâtira, sans changer leur métier
		if not pid_res.is_empty():
			s._assigner(j, x.id, "oisif", tick, pid_res)
		var f := str(x.fonction)
		rapport.postes[f] = int(rapport.postes.get(f, 0)) + 1
	s.territoire.tresor = tresor
	s.invincible = true   # le joueur n'est pas ce qu'on simule : une semaine d'un coup l'affamerait, et le raid le tuerait
	for c in cellules:
		rapport.cellules.append({"cellule": c, "biome": str(s.monde.cellule(c).get("biome", "?")), "role": str(s.monde.claims[c].role)})
	return rapport


## Une semaine passe comme dans une partie : l'horloge avance, `_tiquer_monde` fait tout le reste.
## Retourne l'état après la semaine, et les lignes de journal de la semaine par clé.
static func semaine(s: Simulation, journal: Array, j: Dictionary = {}) -> Dictionary:
	var tps: int = int(GameData.config("planete").corruption.ticks_par_semaine)
	journal.clear()
	if not j.is_empty():   # le joueur mange : une semaine entière sans manger le tuerait (c'est lui qu'on ne simule pas)
		j.faim = int(j.get("faim_max", 100))
	var t0 := Time.get_ticks_usec()
	s.horloge_monde.avancer(tps)
	s._tiquer_monde(s.horloge_monde.ticks)
	var dt := (Time.get_ticks_usec() - t0) / 1000.0
	if not j.is_empty():
		j.faim = int(j.get("faim_max", 100))
	var cles := {}
	for l in journal:
		cles[str(l.cle)] = int(cles.get(str(l.cle), 0)) + 1
	return {"ms": dt, "journal": cles, "etat": etat(s)}


## L'état lisible de la base : résidents, logés, stocks par catégorie, trésor, dette, zones, stockages.
static func etat(s: Simulation) -> Dictionary:
	var res: Array = s.residents()
	var loges := 0
	var camp: Vector2i = s.monde.cellule_camp
	var pieces: Array = s.pieces_de_cellule(camp)
	for x in res:
		if x.has("lit") and not s._piece_du_lit(x.lit, pieces).is_empty():
			loges += 1
	var stocks := {}
	for cle in s.territoire.stocks.keys():
		var mat: Dictionary = GameData.catalogues.materials.get(str(cle).split("|")[0], {})
		var cat := str(mat.get("category", str(cle).split("|")[0]))
		stocks[cat] = int(stocks.get(cat, 0)) + int(s.territoire.stocks[cle])
	var zones := []
	var stockages := []
	for pid in s.perimetres().keys():
		var per: Dictionary = s.perimetres()[pid]
		var tp: Dictionary = s.regles.r.royaume.perimetres.types.get(str(per.type), {})
		if bool(tp.get("stockage", false)):
			stockages.append("%s %d/%d" % [str(pid), int(per.capacite) - s.place_stockage(str(pid)), int(per.capacite)])
		elif not bool(tp.get("residentiel", false)):
			zones.append("%s %s r%d/%.0f" % [str(pid), str(per.type), int(per.richesse), float(per.reserve)])
	var maisons := 0
	for gi in s.grille.meubles.keys():
		if str(s.grille.meubles[gi]).begins_with("lit") and s._cell_de(s.grille.pos_de(int(gi))) == camp:
			maisons += 1
	return {"residents": res.size(), "loges": loges, "lits": maisons, "stocks": stocks, "tresor": int(s.territoire.tresor), "dette": int(s.territoire.dette),
		"zones": zones, "stockages": stockages, "humeur": _humeur_moyenne(res)}


static func _humeur_moyenne(res: Array) -> int:
	if res.is_empty():
		return 0
	var t := 0
	for x in res:
		t += int(x.get("humeur", 0))
	return t / res.size()


## Le rectangle w×h de la cellule `c` dont la somme de `valeur(tuile)` est la plus grande, sans tuile déjà prise.
## `minimum` : refuse en dessous (−1 : n'importe quelle somme > 0). `pres_de` : à somme égale, le plus proche.
static func _meilleur_rectangle(s: Simulation, c: Vector2i, taille: Vector2i, pris: Dictionary, valeur: Callable, minimum: int, pres_de: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var n: int = s.monde.taille
	var v := PackedInt32Array()   # valeurs et « libre » en sommes préfixes (n+1)×(n+1)
	var l := PackedInt32Array()
	v.resize((n + 1) * (n + 1))
	l.resize((n + 1) * (n + 1))
	for y in n:
		for x in n:
			var p: Vector2i = s.monde.pos_monde(c, Vector2i(x, y))
			var dedans: bool = s.grille.dans(p)
			var val: int = int(valeur.call(p)) if dedans else 0
			var lib: int = 1 if (dedans and not pris.has(p)) else 0
			var i := (y + 1) * (n + 1) + (x + 1)
			v[i] = val + v[i - 1] + v[i - (n + 1)] - v[i - (n + 1) - 1]
			l[i] = lib + l[i - 1] + l[i - (n + 1)] - l[i - (n + 1) - 1]
	var meilleur := {}
	var meilleure_somme := 0
	var meilleure_dist := 1 << 30
	for y in range(0, n - taille.y + 1):
		for x in range(0, n - taille.x + 1):
			var x2 := x + taille.x
			var y2 := y + taille.y
			var libres: int = l[y2 * (n + 1) + x2] - l[y * (n + 1) + x2] - l[y2 * (n + 1) + x] + l[y * (n + 1) + x]
			if libres < taille.x * taille.y:
				continue
			var somme: int = v[y2 * (n + 1) + x2] - v[y * (n + 1) + x2] - v[y2 * (n + 1) + x] + v[y * (n + 1) + x]
			if somme <= 0 or (minimum >= 0 and somme < minimum):
				continue
			var a: Vector2i = s.monde.pos_monde(c, Vector2i(x, y))
			var dist: int = (absi(a.x + taille.x / 2 - pres_de.x) + absi(a.y + taille.y / 2 - pres_de.y)) if pres_de != Vector2i(-1, -1) else 0
			if somme > meilleure_somme or (somme == meilleure_somme and dist < meilleure_dist):
				meilleure_somme = somme
				meilleure_dist = dist
				meilleur = {"a": a, "b": a + taille - Vector2i.ONE, "somme": somme}
	return meilleur


static func _marquer(pris: Dictionary, a: Vector2i, b: Vector2i) -> void:
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			pris[Vector2i(x, y)] = true


static func _libre_pres(s: Simulation, p: Vector2i) -> Vector2i:
	for r in range(1, 3):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := p + Vector2i(dx, dy)
				if s.grille.dans(q) and not s.grille.bloque_passage(q) and s.grille.occupant(q).is_empty():
					return q
	return Vector2i(-1, -1)
