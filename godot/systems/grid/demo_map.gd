class_name DemoMap
extends RefCounted
## Carte de démo 24x24 — hauteurs 0-20 (référence 10), coûts de pente du design.
## Règles : docs/02 - Monde/Hauteur de terrain ±10.md · docs/03 - Combat/Boucle de tick.md

const TAILLE := 24
const H_REF := 10

var hauteur: PackedInt32Array = PackedInt32Array()


func _init(graine: int = 0x68EE) -> void:
	hauteur.resize(TAILLE * TAILLE)
	var bruit := FastNoiseLite.new()
	bruit.seed = graine
	bruit.frequency = 0.09
	bruit.fractal_octaves = 3
	var crete := FastNoiseLite.new()
	crete.seed = graine + 1
	crete.frequency = 0.05
	crete.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	for y in TAILLE:
		for x in TAILLE:
			# continentalité douce + une crête ridged : le relief doit se voir.
			var v := bruit.get_noise_2d(x, y) * 3.0 + maxf(0.0, crete.get_noise_2d(x, y)) * 6.0
			hauteur[y * TAILLE + x] = clampi(H_REF + roundi(v), 0, 20)


func h(x: int, y: int) -> int:
	return hauteur[y * TAILLE + x]


func dans_carte(x: int, y: int) -> bool:
	return x >= 0 and x < TAILLE and y >= 0 and y < TAILLE


## Coût en ticks pour passer d'une tuile à sa voisine. -1 = infranchissable.
## 0: 3 t · +1: 5 t · +2: 8 t · >=+3: falaise · -1/-2: 2 t · <=-3: chute (évitée ici)
func cout_pas(de: Vector2i, vers: Vector2i) -> int:
	if not dans_carte(vers.x, vers.y):
		return -1
	var dh := h(vers.x, vers.y) - h(de.x, de.y)
	if dh >= 3 or dh <= -3:
		return -1
	if dh == 2:
		return 8
	if dh == 1:
		return 5
	if dh < 0:
		return 2
	return 3


## A* 4-directions sur les coûts de pente. Retourne les étapes SANS la case de départ.
func chemin(depart: Vector2i, arrivee: Vector2i) -> Array[Vector2i]:
	var vide: Array[Vector2i] = []
	if depart == arrivee or not dans_carte(arrivee.x, arrivee.y):
		return vide
	var ouverts: Array[Vector3i] = [Vector3i(depart.x, depart.y, 0)]  # (x, y, f)
	var g := {depart: 0}
	var vient_de := {}
	while not ouverts.is_empty():
		var idx := 0
		for i in ouverts.size():
			if ouverts[i].z < ouverts[idx].z:
				idx = i
		var courant3 := ouverts[idx]
		ouverts.remove_at(idx)
		var courant := Vector2i(courant3.x, courant3.y)
		if courant == arrivee:
			var pas: Array[Vector2i] = []
			var c := courant
			while c != depart:
				pas.push_front(c)
				c = vient_de[c]
			return pas
		for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var voisin := courant + dir
			var cout := cout_pas(courant, voisin)
			if cout < 0:
				continue
			var ng: int = g[courant] + cout
			if ng < int(g.get(voisin, 1 << 30)):
				g[voisin] = ng
				vient_de[voisin] = courant
				var f := ng + 3 * (absi(arrivee.x - voisin.x) + absi(arrivee.y - voisin.y))
				ouverts.append(Vector3i(voisin.x, voisin.y, f))
	return vide
