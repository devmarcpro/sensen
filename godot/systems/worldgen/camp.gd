class_name Camp
extends RefCounted
## La cellule du camp de base (Ordre de construction, étape 7 : « une seule cellule, stations, coffres,
## repos »). Le monde de surface n'existe pas encore (étape 8) : le camp est une cellule plate de
## 128×128 revendiquée d'office, avec l'entrée du donjon, des arbres et des rochers de surface à
## récolter (Récolte : « des filons de surface, un outil adapté »), et un coffre de départ.
## Déterministe par graine. Même forme de résultat qu'un étage de donjon (Grille.depuis_etage).

const H_BASE := 10

var cfg: Dictionary
var rng := RandomNumberGenerator.new()


func _init(p_cfg: Dictionary) -> void:
	cfg = p_cfg


func generer(graine: int) -> Dictionary:
	rng.seed = hash([graine, "camp"])
	var taille: int = int(cfg.taille)
	var e := {"largeur": taille, "hauteur": taille, "hauteurs": PackedByteArray(), "sol": {}, "bord": {}, "filons": {},
		"arbres": {}, "rochers": {}, "entree": Vector2i(taille / 2, taille / 2), "entree_donjon": Vector2i(taille / 2 + 10, taille / 2),
		"coffre_depart": Vector2i(taille / 2 - 2, taille / 2), "pieces": [], "spawns": [], "coffres": [], "escalier": null, "boss": null, "etage": 0}
	e.hauteurs.resize(taille * taille)
	e.hauteurs.fill(H_BASE)
	for y in taille:
		for x in taille:
			var i := y * taille + x
			if x == 0 or y == 0 or x == taille - 1 or y == taille - 1:
				e.bord[i] = true
			else:
				e.sol[i] = true
	# Arbres et rochers : des nœuds visibles, jamais sur la zone d'arrivée.
	var reserve := Rect2i(e.entree - Vector2i(6, 6), Vector2i(20, 12))
	_semer(e, e.arbres, cfg.arbres.essences, int(cfg.arbres.nombre), int(cfg.arbres.bosquet), reserve)
	_semer(e, e.rochers, cfg.rochers.materiaux, int(cfg.rochers.nombre), int(cfg.rochers.amas), reserve)
	_semer(e, e.filons, cfg.filons.materiaux, int(cfg.filons.nombre), int(cfg.filons.amas), reserve)
	for d in [e.arbres, e.rochers, e.filons]:
		for i in d.keys():
			e.sol.erase(i)
	return e


## Sème `nombre` amas d'un des matériaux, chacun de `taille_amas` tuiles en marche au hasard.
func _semer(e: Dictionary, cible: Dictionary, pool: Array, nombre: int, taille_amas: int, reserve: Rect2i) -> void:
	var taille: int = e.largeur
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for k in nombre:
		var mat: String = str(pool[rng.randi_range(0, pool.size() - 1)])
		var p := Vector2i(rng.randi_range(3, taille - 4), rng.randi_range(3, taille - 4))
		var reste := rng.randi_range(1, taille_amas)
		for pas in taille_amas * 3:
			var i := p.y * taille + p.x
			if e.sol.has(i) and not reserve.has_point(p) and not cible.has(i) and not e.arbres.has(i) and not e.rochers.has(i) and not e.filons.has(i):
				cible[i] = mat
				reste -= 1
				if reste <= 0:
					break
			p += dirs[rng.randi_range(0, 3)]
			if p.x < 3 or p.y < 3 or p.x > taille - 4 or p.y > taille - 4:
				break
